import Foundation
import Testing
@testable import OpenVaultCore

private func tempDir() throws -> URL {
    let dir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
}

@Test func encryptionRoundTripAndWrongPassword() throws {
    let file = VaultFile(url: try tempDir().appending(path: "vault.ovault"))
    let key = try file.create(password: "correct horse")
    try file.update(key: key) { $0.items.append(Item(name: "API_KEY", kind: .secret, content: "s3cr3t")) }

    let (vault, _) = try file.unlock(password: "correct horse")
    #expect(vault.items.map(\.content) == ["s3cr3t"])
    #expect(throws: VaultError.wrongPassword) { try file.unlock(password: "nope") }

    let raw = try String(contentsOf: file.url, encoding: .utf8)
    #expect(!raw.contains("s3cr3t"))
    let perms = try FileManager.default.attributesOfItem(atPath: file.url.path)[.posixPermissions] as? Int
    #expect(perms == 0o600)
}

@Test func changePasswordInvalidatesOldKey() throws {
    let file = VaultFile(url: try tempDir().appending(path: "vault.ovault"))
    let old = try file.create(password: "one")
    let new = try file.changePassword(key: old, to: "two")
    #expect(throws: VaultError.wrongPassword) { try file.load(key: old) }
    #expect(try file.load(key: new).items.isEmpty)
    #expect(throws: VaultError.wrongPassword) { try file.unlock(password: "one") }
}

@Test func dotEnvParsing() {
    let text = """
    # comment
    export A=1
    B = "two words" # trailing
    C='literal \\n'
    D="line\\nbreak"
    E=plain # comment
    NOEQUALS
    """
    let env = Dictionary(DotEnv.parse(text).map { ($0.key, $0.value) }, uniquingKeysWith: { $1 })
    #expect(env == ["A": "1", "B": "two words", "C": "literal \\n", "D": "line\nbreak", "E": "plain"])
    let round = Dictionary(DotEnv.parse(DotEnv.serialize(env)).map { ($0.key, $0.value) }, uniquingKeysWith: { $1 })
    #expect(round == env)
}

@Test func mergedEnvSecretsWin() {
    let vault = Vault(items: [
        Item(name: ".env", kind: .env, project: "app", content: "A=1\nB=2"),
        Item(name: "B", kind: .secret, project: "app", content: "override"),
        Item(name: "C", kind: .secret, project: "other", content: "x"),
    ])
    #expect(vault.mergedEnv(project: "app") == ["A": "1", "B": "override"])
}

@Test func projectConfigWalksUp() throws {
    let root = try tempDir()
    let nested = root.appending(path: "a/b/c")
    try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
    try ProjectConfig(project: "demo").write(to: root)
    #expect(ProjectConfig.find(from: nested)?.project == "demo")
}
