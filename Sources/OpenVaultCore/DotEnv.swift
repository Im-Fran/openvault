import Foundation

public enum DotEnv {
    /// Parses `.env` text. Keeps order; later duplicates win when turned into a dictionary.
    /// Supports `export KEY=`, `#` comments, single quotes (literal) and double quotes (`\n`, `\"` escapes).
    public static func parse(_ text: String) -> [(key: String, value: String)] {
        var result: [(String, String)] = []
        for rawLine in text.split(whereSeparator: \.isNewline) {
            var line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            if line.hasPrefix("export ") { line = String(line.dropFirst(7)).trimmingCharacters(in: .whitespaces) }
            guard let eq = line.firstIndex(of: "=") else { continue }
            let key = line[..<eq].trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty else { continue }
            var value = line[line.index(after: eq)...].trimmingCharacters(in: .whitespaces)

            if value.hasPrefix("\""), let end = value.dropFirst().lastIndex(of: "\"") {
                value = unescape(value[value.index(after: value.startIndex)..<end])
            } else if value.hasPrefix("'"), let end = value.dropFirst().lastIndex(of: "'") {
                value = String(value[value.index(after: value.startIndex)..<end])
            } else if let hash = value.range(of: " #") {
                value = value[..<hash.lowerBound].trimmingCharacters(in: .whitespaces)
            }
            result.append((key, value))
        }
        return result
    }

    public static func serialize(_ env: [String: String]) -> String {
        env.keys.sorted().map { key in
            let value = env[key]!
            let needsQuotes = value.contains(where: { " #\"'\n=$".contains($0) }) || value.isEmpty
            guard needsQuotes else { return "\(key)=\(value)" }
            let escaped = value.replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "\n", with: "\\n")
            return "\(key)=\"\(escaped)\""
        }.joined(separator: "\n") + "\n"
    }

    private static func unescape(_ s: Substring) -> String {
        var out = ""
        var escaping = false
        for c in s {
            if escaping {
                out.append(c == "n" ? "\n" : c)
                escaping = false
            } else if c == "\\" {
                escaping = true
            } else {
                out.append(c)
            }
        }
        return out
    }
}
