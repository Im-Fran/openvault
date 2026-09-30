import AppKit
import OpenVaultCore
import SwiftUI

extension Item.Kind {
    var title: String {
        switch self {
        case .env: "Archivos .env"
        case .secret: "Secretos"
        case .password: "Contraseñas"
        case .sshKey: "Claves SSH"
        case .gpgKey: "Claves GPG"
        case .file: "Archivos"
        case .other: "Otros"
        }
    }

    var singular: String {
        switch self {
        case .env: "Archivo .env"
        case .secret: "Secreto"
        case .password: "Contraseña"
        case .sshKey: "Clave SSH"
        case .gpgKey: "Clave GPG"
        case .file: "Archivo"
        case .other: "Otro"
        }
    }

    var symbol: String {
        switch self {
        case .env: "doc.plaintext"
        case .secret: "key"
        case .password: "person.badge.key"
        case .sshKey: "terminal"
        case .gpgKey: "signature"
        case .file: "doc"
        case .other: "lock.doc"
        }
    }

    var tint: Color {
        switch self {
        case .env: .green
        case .secret: .orange
        case .password: .red
        case .sshKey: .blue
        case .gpgKey: .purple
        case .file: .teal
        case .other: .gray
        }
    }

    /// Guess the kind from file name and contents (drag & drop).
    static func detect(fileName: String, content: String) -> Item.Kind {
        if content.contains("BEGIN PGP") { return .gpgKey }
        if content.contains("PRIVATE KEY-----") || fileName.hasPrefix("id_") { return .sshKey }
        if fileName.hasPrefix(".env") || fileName.hasSuffix(".env") { return .env }
        let lines = content.split(whereSeparator: \.isNewline).filter { !$0.hasPrefix("#") && !$0.isEmpty }
        if !lines.isEmpty, DotEnv.parse(content).count == lines.count { return .env }
        return .other
    }
}

extension Item {
    // ponytail: the whole vault is re-encrypted on every save, so keep files small. Raise it or
    // store blobs outside the JSON if someone needs bigger ones.
    static let maxFileBytes = 10 * 1024 * 1024

    /// A `.file` item from a file on disk, or nil if unreadable or too big.
    static func file(at url: URL) -> Item? {
        guard let data = try? Data(contentsOf: url), data.count <= maxFileBytes else { return nil }
        return Item(name: url.lastPathComponent, kind: .file, content: "", fileName: url.lastPathComponent, data: data)
    }
}

extension EnvironmentValues {
    /// Held ⌥ reveals every masked value in the detail view.
    @Entry var revealAll = false
}

/// Brand gradient (160°), from assets/brand/BRAND.md. Only for the icon, lock screen and hero pieces.
enum Brand {
    static let gradient = LinearGradient(colors: [Color(.brandStart), Color(.brandEnd)],
                                         startPoint: .init(x: 0.33, y: 0.03), endPoint: .init(x: 0.67, y: 0.97))
}

enum Motion {
    /// Critically damped: the house default for anything that isn't driven by momentum.
    static let standard = Animation.spring(duration: 0.35, bounce: 0)
}

enum Clipboard {
    /// Copies and marks the value as concealed (clipboard managers skip it), then clears it
    /// after the configured delay — only if nothing else was copied meanwhile.
    static func copy(_ string: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(string, forType: .string)
        pb.setString("", forType: .init("org.nspasteboard.ConcealedType"))
        let change = pb.changeCount
        let seconds = UserDefaults.standard.object(forKey: "clipboardSeconds") as? Int ?? 30
        Task {
            try? await Task.sleep(for: .seconds(seconds))
            if pb.changeCount == change { pb.clearContents() }
        }
    }
}

/// Runs a developer tool (ssh-keygen, gpg). GUI apps don't inherit the shell PATH, so look in the usual places.
enum Tool {
    static func run(_ name: String, _ args: [String], input: String? = nil) async -> String? {
        let dirs = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin"]
        guard let path = dirs.map({ "\($0)/\(name)" }).first(where: FileManager.default.isExecutableFile) else { return nil }
        return await Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = args
            let out = Pipe(), inPipe = Pipe()
            process.standardOutput = out
            process.standardError = Pipe()
            process.standardInput = inPipe
            do { try process.run() } catch { return nil }
            if let input { inPipe.fileHandleForWriting.write(Data(input.utf8)) }
            try? inPipe.fileHandleForWriting.close()
            let data = out.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return process.terminationStatus == 0 ? String(decoding: data, as: UTF8.self) : nil
        }.value
    }

    /// A private scratch dir (0700) that is always removed.
    static func withTempDir<T>(_ body: (URL) async throws -> T) async rethrows -> T {
        let dir = FileManager.default.temporaryDirectory.appending(path: "openvault-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        defer { try? FileManager.default.removeItem(at: dir) }
        return try await body(dir)
    }
}

enum KeyInfo {
    /// Public key + fingerprint of an OpenSSH private key.
    static func ssh(privateKey: String, passphrase: String?) async -> (publicKey: String, fingerprint: String)? {
        await Tool.withTempDir { dir in
            let file = dir.appending(path: "key")
            guard FileManager.default.createFile(atPath: file.path, contents: Data((privateKey.trimmingCharacters(in: .whitespacesAndNewlines) + "\n").utf8),
                                                 attributes: [.posixPermissions: 0o600]),
                  let pub = await Tool.run("ssh-keygen", ["-y", "-P", passphrase ?? "", "-f", file.path]),
                  let fp = await Tool.run("ssh-keygen", ["-l", "-f", "-"], input: pub)
            else { return nil }
            return (pub.trimmingCharacters(in: .whitespacesAndNewlines), fp.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    /// Fingerprint and first user id of an armored GPG key, without importing it.
    static func gpg(armored: String) async -> (fingerprint: String, uid: String)? {
        guard let out = await Tool.run("gpg", ["--show-keys", "--with-colons"], input: armored) else { return nil }
        let rows = out.split(separator: "\n").map { $0.split(separator: ":", omittingEmptySubsequences: false) }
        guard let fpr = rows.first(where: { $0.first == "fpr" && $0.count > 9 })?[9] else { return nil }
        let uid = rows.first(where: { $0.first == "uid" && $0.count > 9 })?[9] ?? ""
        return (String(fpr), String(uid))
    }

    /// New ed25519 key pair via ssh-keygen.
    static func generateSSH(comment: String, passphrase: String) async -> String? {
        await Tool.withTempDir { dir in
            let file = dir.appending(path: "id_ed25519")
            guard await Tool.run("ssh-keygen", ["-t", "ed25519", "-q", "-N", passphrase, "-C", comment, "-f", file.path]) != nil
            else { return nil }
            return try? String(contentsOf: file, encoding: .utf8)
        }
    }
}
