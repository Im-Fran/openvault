import CryptoKit
import Foundation

/// The single encrypted vault file shared by the app and the CLI.
/// With iCloud sync on, it lives in the app's iCloud container; every access is file-coordinated
/// so the iCloud daemon never uploads a half-written file.
public struct VaultFile: Sendable {
    public let url: URL

    public static let appID = "cl.franciscosolis.openvault"
    public static let fileName = "vault.ovault"

    public static var localURL: URL {
        URL.applicationSupportDirectory.appending(path: "OpenVault/\(fileName)")
    }

    /// The app's preferences. The CLI reads them too, so it follows the app's iCloud setting.
    public static var settings: UserDefaults {
        Bundle.main.bundleIdentifier == appID ? .standard : UserDefaults(suiteName: appID) ?? .standard
    }

    /// iCloud copy, as last resolved by the app (`iCloudVaultPath`). Nil until the app has seen iCloud.
    public static var iCloudURL: URL? {
        settings.string(forKey: "iCloudVaultPath").map { URL(fileURLWithPath: $0) }
    }

    public static var defaultURL: URL {
        if let override = ProcessInfo.processInfo.environment["OPENVAULT_FILE"] {
            return URL(fileURLWithPath: override)
        }
        if settings.bool(forKey: "iCloudSync"), let cloud = iCloudURL { return cloud }
        return localURL
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
        let data = try coordinatedRead()
        let env = try VaultCrypto.envelope(data)
        let key = try VaultKey.derive(password: password, salt: env.salt, iterations: env.iterations)
        return (try VaultCrypto.open(data, key: key), key)
    }

    /// Rebuilds a key from raw key bytes (e.g. from the Keychain) using the file's KDF params.
    public func key(fromRaw raw: Data) throws -> VaultKey {
        let env = try VaultCrypto.envelope(coordinatedRead())
        return VaultKey(raw: .init(data: raw), salt: env.salt, iterations: env.iterations)
    }

    public func load(key: VaultKey) throws -> Vault {
        try VaultCrypto.open(coordinatedRead(), key: key)
    }

    /// Read-modify-write under an exclusive lock, so app and CLI never clobber each other.
    @discardableResult
    public func update(key: VaultKey, _ mutate: (inout Vault) throws -> Void) throws -> Vault {
        try withLock {
            var vault = try VaultCrypto.open(read(), key: key)
            try mutate(&vault)
            try write(vault, key: key)
            return vault
        }
    }

    /// Writes `vault` with `key`, replacing whatever is there (e.g. copying the vault to or from iCloud).
    public func save(_ vault: Vault, key: VaultKey) throws {
        try withLock { try write(vault, key: key) }
    }

    /// Re-encrypts everything with a new password and salt.
    public func changePassword(key: VaultKey, to newPassword: String) throws -> VaultKey {
        let newKey = try VaultKey.new(password: newPassword)
        try withLock {
            let vault = try VaultCrypto.open(read(), key: key)
            try write(vault, key: newKey)
        }
        return newKey
    }

    /// Merges the versions iCloud kept when two devices saved at once into the current file.
    /// Returns the merged vault, or nil if there was nothing to merge.
    /// ponytail: a version encrypted with another key (password changed on the other device) can't be
    /// merged and is left for later; an item deleted on one side comes back if the other side edited it.
    public func resolveConflicts(key: VaultKey) throws -> Vault? {
        guard let conflicts = NSFileVersion.unresolvedConflictVersionsOfItem(at: url), !conflicts.isEmpty else { return nil }
        return try withLock {
            var vault = try VaultCrypto.open(read(), key: key)
            for version in conflicts {
                guard let data = FileManager.default.contents(atPath: version.url.path),
                      let other = try? VaultCrypto.open(data, key: key) else { continue }
                vault = vault.merged(with: other)
                version.isResolved = true
            }
            try write(vault, key: key)
            return vault
        }
    }

    // MARK: - Private

    private func coordinatedRead() throws -> Data {
        var data: Data?
        var coordinationError: NSError?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { url in
            data = FileManager.default.contents(atPath: url.path)
        }
        if let coordinationError { throw coordinationError }
        guard let data else { throw VaultError.notFound }
        return data
    }

    /// Only inside `withLock`, which already coordinates.
    private func read() throws -> Data {
        guard let data = FileManager.default.contents(atPath: url.path) else { throw VaultError.notFound }
        return data
    }

    private func write(_ vault: Vault, key: VaultKey) throws {
        let dir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        try VaultCrypto.seal(vault, key: key).write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    /// `flock` between processes on this device, plus a coordinated write so iCloud waits for us.
    /// The lock file lives in the temp dir (the same one for the app and the CLI) so it never syncs.
    private func withLock<T>(_ body: () throws -> T) throws -> T {
        let hash = SHA256.hash(data: Data(url.standardizedFileURL.path.utf8)).prefix(8).map { String(format: "%02x", $0) }.joined()
        let lockPath = FileManager.default.temporaryDirectory.appending(path: "openvault-\(hash).lock").path
        let fd = open(lockPath, O_CREAT | O_RDWR, 0o600)
        guard fd >= 0 else { throw POSIXError(.init(rawValue: errno) ?? .EIO) }
        defer { close(fd) }
        flock(fd, LOCK_EX)
        defer { flock(fd, LOCK_UN) }

        var result: Result<T, Error>?
        var coordinationError: NSError?
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forMerging, error: &coordinationError) { _ in
            result = Result { try body() }
        }
        if let coordinationError { throw coordinationError }
        return try result!.get()
    }
}
