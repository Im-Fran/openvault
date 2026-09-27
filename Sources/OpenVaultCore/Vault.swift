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

    /// Environment for a project: `.env` items first, then individual secrets on top (secrets win).
    public func mergedEnv(project: String?) -> [String: String] {
        let scoped = items(in: project)
        var env: [String: String] = [:]
        for item in scoped where item.kind == .env {
            for (k, v) in DotEnv.parse(item.content) { env[k] = v }
        }
        for item in scoped where item.kind == .secret {
            env[item.name] = item.content
        }
        return env
    }
}

public struct Item: Codable, Sendable, Identifiable, Hashable {
    public enum Kind: String, Codable, Sendable, CaseIterable {
        case env, secret, sshKey, gpgKey, other
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

    public init(name: String, kind: Kind, project: String? = nil, content: String,
                passphrase: String? = nil, notes: String = "") {
        self.name = name
        self.kind = kind
        self.project = project
        self.content = content
        self.passphrase = passphrase
        self.notes = notes
    }
}
