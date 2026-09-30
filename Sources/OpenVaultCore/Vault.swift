import Foundation

public struct Vault: Codable, Sendable, Equatable {
    public var version = 1
    public var items: [Item] = []

    public init(items: [Item] = []) { self.items = items }

    public var projects: [String] {
        Array(Set(items.compactMap(\.project))).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    public func items(in project: String?) -> [Item] {
        guard let project else { return items }
        return items.filter { $0.project == project }
    }

    /// Environment for a project: `.env` items first, then passwords, then individual secrets on top (secrets win).
    /// A password is exposed as `Shell.envName(name)`, plus `<NAME>_USERNAME` when it has a user name.
    /// Files are not here (see `fileEnv`); SSH keys, GPG keys and "other" items have no env mapping.
    public func mergedEnv(project: String?) -> [String: String] {
        let scoped = items(in: project)
        var env: [String: String] = [:]
        for item in scoped where item.kind == .env {
            for (k, v) in DotEnv.parse(item.content) { env[k] = v }
        }
        for item in scoped where item.kind == .password {
            let name = Shell.envName(item.name)
            env[name] = item.content
            if let username = item.username { env[name + "_USERNAME"] = username }
        }
        for item in scoped where item.kind == .secret {
            env[item.name] = item.content
        }
        return env
    }

    /// File items of a project keyed by the variable that should hold the path they get written to.
    public func fileEnv(project: String?) -> [String: Item] {
        Dictionary(items(in: project).filter { $0.kind == .file }.map { (Shell.envName($0.name), $0) },
                   uniquingKeysWith: { $1 })
    }
}

public struct Item: Codable, Sendable, Identifiable, Hashable {
    public enum Kind: String, Codable, Sendable, CaseIterable {
        case env, secret, password, sshKey, gpgKey, file, other
    }

    public var id = UUID()
    public var name: String
    public var kind: Kind
    public var project: String?
    public var content: String
    public var passphrase: String?
    public var notes = ""
    public var createdAt = Date()
    public var updatedAt = Date()
    // Added after v1 shipped. Optional on purpose: vaults written before they existed still decode.
    /// `.password`: login user name (the password itself is `content`).
    public var username: String?
    /// `.password`: site or service URL.
    public var url: String?
    /// `.file`: original file name.
    public var fileName: String?
    /// `.file`: raw bytes (any binary). Encrypted with the rest of the vault.
    public var data: Data?

    public init(name: String, kind: Kind, project: String? = nil, content: String,
                passphrase: String? = nil, notes: String = "", username: String? = nil,
                url: String? = nil, fileName: String? = nil, data: Data? = nil) {
        self.name = name
        self.kind = kind
        self.project = project
        self.content = content
        self.passphrase = passphrase
        self.notes = notes
        self.username = username
        self.url = url
        self.fileName = fileName
        self.data = data
    }
}

extension [Item] {
    /// Items whose name or project contains `query` (case-insensitive; empty matches all), sorted by name.
    public func searched(_ query: String) -> [Item] {
        filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) || ($0.project ?? "").localizedCaseInsensitiveContains(query) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
