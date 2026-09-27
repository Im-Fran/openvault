import Foundation

/// The `.openvault` file committed in a repo. It only names the project — never secrets.
public struct ProjectConfig: Codable, Sendable, Equatable {
    public static let fileName = ".openvault"
    public var project: String

    public init(project: String) { self.project = project }

    /// Walks up from `directory` until it finds a `.openvault` file.
    public static func find(from directory: URL) -> ProjectConfig? {
        var dir = directory.standardizedFileURL
        while true {
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
