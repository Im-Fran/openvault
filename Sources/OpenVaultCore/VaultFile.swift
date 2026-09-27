import Foundation

/// The single encrypted vault file shared by the app and the CLI.
public struct VaultFile: Sendable {
    public let url: URL

    public static var defaultURL: URL {
        if let override = ProcessInfo.processInfo.environment["OPENVAULT_FILE"] {
            return URL(fileURLWithPath: override)
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library/Application Support/OpenVault/vault.ovault")
    }

    public init(url: URL = VaultFile.defaultURL) { self.url = url }

    public var exists: Bool { FileManager.default.fileExists(atPath: url.path) }

    /// Creates a brand-new empty vault. Refuses to overwrite an existing one.
    public func create(password: String) throws -> VaultKey {
        let key = try VaultKey.new(password: password)
        try withLock {
            guard !exists else { throw CocoaError(.fileWriteFileExists) }
            try write(Vault(), key: key)
        }
        return key
    }

    /// Derives the key from the password and decrypts. Throws `.wrongPassword` on mismatch.
    public func unlock(password: String) throws -> (Vault, VaultKey) {
        guard let data = FileManager.default.contents(atPath: url.path) else { throw VaultError.notFound }
        let env = try VaultCrypto.envelope(data)
        let key = try VaultKey.derive(password: password, salt: env.salt, iterations: env.iterations)
        return (try VaultCrypto.open(data, key: key), key)
    }

    /// Rebuilds a key from raw key bytes (e.g. from the Keychain) using the file's KDF params.
    public func key(fromRaw raw: Data) throws -> VaultKey {
        guard let data = FileManager.default.contents(atPath: url.path) else { throw VaultError.notFound }
        let env = try VaultCrypto.envelope(data)
        return VaultKey(raw: .init(data: raw), salt: env.salt, iterations: env.iterations)
    }

    public func load(key: VaultKey) throws -> Vault {
        guard let data = FileManager.default.contents(atPath: url.path) else { throw VaultError.notFound }
        return try VaultCrypto.open(data, key: key)
    }

    /// Read-modify-write under an exclusive lock, so app and CLI never clobber each other.
    @discardableResult
    public func update(key: VaultKey, _ mutate: (inout Vault) throws -> Void) throws -> Vault {
        try withLock {
            var vault = try load(key: key)
            try mutate(&vault)
            try write(vault, key: key)
            return vault
        }
    }

    /// Re-encrypts everything with a new password and salt.
    public func changePassword(key: VaultKey, to newPassword: String) throws -> VaultKey {
        let newKey = try VaultKey.new(password: newPassword)
        try withLock {
            let vault = try load(key: key)
            try write(vault, key: newKey)
        }
        return newKey
    }

    // MARK: - Private

    private func write(_ vault: Vault, key: VaultKey) throws {
        let dir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        try VaultCrypto.seal(vault, key: key).write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    private func withLock<T>(_ body: () throws -> T) throws -> T {
        let dir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        let fd = open(url.path + ".lock", O_CREAT | O_RDWR, 0o600)
        guard fd >= 0 else { throw POSIXError(.init(rawValue: errno) ?? .EIO) }
        defer { close(fd) }
        flock(fd, LOCK_EX)
        defer { flock(fd, LOCK_UN) }
        return try body()
    }
}
