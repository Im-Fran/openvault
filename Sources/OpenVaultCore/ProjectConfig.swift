import Foundation

public enum ProjectConfigError: LocalizedError, Equatable {
    case missingProjectName(path: String)

    public var errorDescription: String? {
        switch self {
        case .missingProjectName(let path):
            String(localized: "“\(path)” doesn’t name a project. Add a line like: project-name=my-project")
        }
    }
}

/// The file committed in a repo that links it to a project. It only names the project — never secrets.
/// Two spellings: `.ovault` (`project-name=…`, easy to write by hand) and `.openvault` (JSON, from `ovault init`).
public struct ProjectConfig: Codable, Sendable, Equatable {
    public static let fileName = ".openvault"
    public static let shortFileName = ".ovault"
    public var project: String

    public init(project: String) { self.project = project }

    /// Project named by the text of a `.ovault` file, or nil if it has no `project-name`.
    /// Same leniency as a `.env`: spaces around `=`, `#` comments, blank lines and quotes are fine.
    public static func parse(_ text: String) -> String? {
        DotEnv.parse(text).last { $0.key == "project-name" && !$0.value.isEmpty }?.value
    }

    /// Walks up from `directory` until it finds a `.ovault` or `.openvault` file.
    /// Throws if the nearest `.ovault` doesn't name a project, rather than silently using another one.
    public static func find(from directory: URL) throws -> ProjectConfig? {
        var dir = directory.standardizedFileURL
        while true {
            let short = dir.appending(path: shortFileName)
            if let data = FileManager.default.contents(atPath: short.path) {
                guard let project = parse(String(decoding: data, as: UTF8.self)) else {
                    throw ProjectConfigError.missingProjectName(path: short.path)
                }
                return ProjectConfig(project: project)
            }
            let candidate = dir.appending(path: fileName)
            if let data = FileManager.default.contents(atPath: candidate.path),
               let config = try? JSONDecoder().decode(ProjectConfig.self, from: data) {
                return config
            }
            let parent = dir.deletingLastPathComponent()
            if parent.path == dir.path { return nil }
            dir = parent
        }
    }

    public func write(to directory: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try (encoder.encode(self) + Data("\n".utf8)).write(to: directory.appending(path: Self.fileName))
    }
}
