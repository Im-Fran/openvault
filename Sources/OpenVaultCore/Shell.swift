import Foundation

/// Helpers to hand the vault's environment to a POSIX shell safely.
public enum Shell {
    /// A name every POSIX shell accepts in `export NAME=…`.
    public static func isValidName(_ name: String) -> Bool {
        name.wholeMatch(of: /[A-Za-z_][A-Za-z0-9_]*/) != nil
    }

    /// Single-quoted literal: nothing inside is expanded (`$`, backticks, newlines and `"` stay as they are).
    public static func quote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    /// Variable name for an item that isn't named like one (passwords, files).
    /// Valid names are kept as they are; otherwise upper-cased with every other character turned into `_`:
    /// "Postgres prod" → `POSTGRES_PROD`, "AuthKey_AB12.p8" → `AUTHKEY_AB12_P8`.
    public static func envName(_ name: String) -> String {
        if isValidName(name) { return name }
        let mapped = String(name.uppercased().map { $0.isASCII && ($0.isLetter || $0.isNumber) ? $0 : "_" })
        return mapped.first.map { $0.isNumber } ?? true ? "_" + mapped : mapped
    }

    /// `export NAME='value'` lines, sorted, for `eval`. Names that aren't valid identifiers are left out.
    public static func exports(_ env: [String: String]) -> String {
        env.keys.filter(isValidName).sorted().map { "export \($0)=\(quote(env[$0]!))\n" }.joined()
    }
}
