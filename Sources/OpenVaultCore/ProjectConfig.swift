import Foundation

public enum ProjectConfigError: LocalizedError, Equatable {
    case empty(path: String)
    case unknownKey(String, path: String)
    case invalidPattern(String, path: String)

    public var errorDescription: String? {
        switch self {
        case .empty(let path):
            String(localized: "“\(path)” doesn’t select anything. Add a line like: project-name=my-project")
        case .unknownKey(let key, let path):
            String(localized: "“\(path)” has an unknown key “\(key)”. Use project-name, secret-name or folder-name.")
        case .invalidPattern(let pattern, let path):
            String(localized: "“\(path)” has an invalid pattern “\(pattern)”.")
        }
    }
}

/// The file committed in a repo that says what it loads from the vault. It only names things — never secrets.
/// `.ovaultrc` is a list of `project-name=…`, `secret-name=…` and `folder-name=…` lines (any number of each).
/// The legacy `.openvault` (JSON with a single project) is still read.
public struct ProjectConfig: Sendable, Equatable {
    public enum Key: String, Sendable, CaseIterable {
        case project = "project-name", secret = "secret-name", folder = "folder-name"
    }

    /// One line. `pattern` matches a name exactly, or as a whole-string regex where `{1..12}` is a numeric range.
    public struct Rule: Sendable, Equatable {
        public var key: Key
        public var pattern: String
        public init(_ key: Key, _ pattern: String) { self.key = key; self.pattern = pattern }
    }

    public static let fileName = ".ovaultrc"
    public static let legacyFileName = ".openvault"
    public var rules: [Rule]

    public init(rules: [Rule]) { self.rules = rules }
    public init(project: String) { rules = [Rule(.project, project)] }

    /// Project that commands writing to the vault (`set`, `import`) use: the first `project-name` line.
    public var project: String? { rules.first { $0.key == .project }?.pattern }

    /// Parses `.ovaultrc` text. Same leniency as a `.env`: spaces around `=`, `#` comments, blank lines and quotes.
    public static func parse(_ text: String, path: String = fileName) throws -> ProjectConfig {
        let rules = try DotEnv.parse(text).filter { !$0.value.isEmpty }.map { line in
            guard let key = Key(rawValue: line.key) else { throw ProjectConfigError.unknownKey(line.key, path: path) }
            guard (try? regex(line.value)) != nil else { throw ProjectConfigError.invalidPattern(line.value, path: path) }
            return Rule(key, line.value)
        }
        guard !rules.isEmpty else { throw ProjectConfigError.empty(path: path) }
        return ProjectConfig(rules: rules)
    }

    /// Walks up from `directory` until it finds a `.ovaultrc` or `.openvault` file.
    /// Throws if the nearest `.ovaultrc` is invalid, rather than silently using another one.
    public static func find(from directory: URL) throws -> ProjectConfig? {
        var dir = directory.standardizedFileURL
        while true {
            let rc = dir.appending(path: fileName)
            if let data = FileManager.default.contents(atPath: rc.path) {
                return try parse(String(decoding: data, as: UTF8.self), path: rc.path)
            }
            let legacy = dir.appending(path: legacyFileName)
            if let data = FileManager.default.contents(atPath: legacy.path),
               let json = try? JSONDecoder().decode([String: String].self, from: data), let project = json["project"] {
                return ProjectConfig(project: project)
            }
            let parent = dir.deletingLastPathComponent()
            if parent.path == dir.path { return nil }
            dir = parent
        }
    }

    public func write(to directory: URL) throws {
        let text = rules.map { "\($0.key.rawValue)=\($0.pattern)\n" }.joined()
        try Data(text.utf8).write(to: directory.appending(path: Self.fileName))
    }

    /// Items selected by any rule, in vault order: by project, by item name, or by folder.
    public func items(in vault: Vault) -> [Item] {
        let matchers = rules.map { Self.matcher($0) }
        return vault.items.filter { item in matchers.contains { $0(item) } }
    }

    /// Rules that select nothing in `vault` (usually a typo).
    public func unmatched(in vault: Vault) -> [Rule] {
        rules.filter { rule in !vault.items.contains(where: Self.matcher(rule)) }
    }

    private static func matcher(_ rule: Rule) -> (Item) -> Bool {
        let regex = try? regex(rule.pattern) // validated by parse; a bad one from `init` matches exactly only
        return { item in
            let value = switch rule.key {
            case .project: item.project
            case .secret: Optional(item.name)
            case .folder: item.folder
            }
            guard let value else { return false }
            return value == rule.pattern || (regex.map { (try? $0.wholeMatch(in: value)) != nil } ?? false)
        }
    }

    /// `pattern` as a regex, with every `{a..b}` replaced by an alternation of the numbers in that range.
    /// A zero-padded start (`{01..12}`) pads every number to its width.
    static func regex(_ pattern: String) throws -> Regex<AnyRegexOutput> {
        let expanded = pattern.replacing(/\{(\d+)\.\.(\d+)\}/) { match in
            let (from, to) = (String(match.1), String(match.2))
            guard let a = Int(from), let b = Int(to) else { return String(match.0) }
            let width = from.hasPrefix("0") ? from.count : 0
            // ponytail: plain alternation, fine for ranges of a few thousand; a huge range makes a huge regex.
            let numbers = stride(from: a, through: b, by: a <= b ? 1 : -1).map { n in
                String(repeating: "0", count: max(0, width - String(n).count)) + String(n)
            }
            return "(?:" + numbers.joined(separator: "|") + ")"
        }
        return try Regex(expanded)
    }
}
