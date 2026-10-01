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

@Test func shellQuotingSurvivesARealShell() throws {
    let env = [
        "PLAIN": "abc",
        "QUOTES": "it's \"quoted\" and 'single'",
        "DOLLAR": "$HOME `id` $(id) \\ !",
        "MULTI": "line1\nline2\n",
        "EMPTY": "",
        "bad name; rm -rf /": "never exported",
    ]
    let script = Shell.exports(env)
    #expect(!script.contains("never exported"))

    // Let /bin/sh eval the script and print each variable back, NUL-terminated.
    let process = Process(), out = Pipe()
    process.executableURL = URL(fileURLWithPath: "/bin/sh")
    process.arguments = ["-c", script + #"printf '%s\0' "$PLAIN" "$QUOTES" "$DOLLAR" "$MULTI" "$EMPTY""#]
    process.standardOutput = out
    try process.run()
    let printed = String(decoding: out.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    process.waitUntilExit()
    #expect(printed.split(separator: "\0", omittingEmptySubsequences: false).dropLast().map(String.init)
        == [env["PLAIN"]!, env["QUOTES"]!, env["DOLLAR"]!, env["MULTI"]!, ""])
}

@Test func envNamesForPasswordsAndFiles() {
    #expect(Shell.envName("DB_PASSWORD") == "DB_PASSWORD")
    #expect(Shell.envName("Postgres prod") == "POSTGRES_PROD")
    #expect(Shell.envName("AuthKey_AB12.p8") == "AUTHKEY_AB12_P8")
    #expect(Shell.envName("1password") == "_1PASSWORD")
    #expect(Shell.isValidName(Shell.envName("ñandú; $(x)")))

    let vault = Vault(items: [
        Item(name: "GitHub", kind: .password, project: "app", content: "pw", username: "fran"),
        Item(name: "cert.p12", kind: .file, project: "app", content: "", fileName: "cert.p12", data: Data([0, 1])),
        Item(name: "deploy", kind: .sshKey, project: "app", content: "key"),
    ])
    #expect(vault.mergedEnv(project: "app") == ["GitHub": "pw", "GitHub_USERNAME": "fran"])
    #expect(vault.fileEnv(project: "app").keys.sorted() == ["CERT_P12"])
}

@Test func projectConfigWalksUp() throws {
    let root = try tempDir()
    let nested = root.appending(path: "a/b/c")
    try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
    try ProjectConfig(project: "demo").write(to: root)
    #expect(try String(contentsOf: root.appending(path: ".ovaultrc"), encoding: .utf8) == "project-name=demo\n")
    #expect(try ProjectConfig.find(from: nested)?.project == "demo")
}

@Test func ovaultrcParsingAndLookup() throws {
    #expect(try ProjectConfig.parse("project-name=demo").project == "demo")
    let config = try ProjectConfig.parse("""
    # what this repo loads

      project-name =  "my app"   # trailing comment
    secret-name=STRIPE_KEY
    folder-name=CI
    project-name=
    """)
    #expect(config.rules == [.init(.project, "my app"), .init(.secret, "STRIPE_KEY"), .init(.folder, "CI")])
    #expect(throws: ProjectConfigError.empty(path: ".ovaultrc")) { try ProjectConfig.parse("# nothing\nproject-name=\n") }
    #expect(throws: ProjectConfigError.unknownKey("name", path: ".ovaultrc")) { try ProjectConfig.parse("name=demo") }
    #expect(throws: ProjectConfigError.invalidPattern("KEY_(", path: ".ovaultrc")) { try ProjectConfig.parse("secret-name=KEY_(") }

    let root = try tempDir()
    let nested = root.appending(path: "a/b")
    try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
    try Data(#"{"project":"from-json"}"#.utf8).write(to: root.appending(path: ".openvault")) // legacy, further up
    try Data("project-name = nearer\n".utf8).write(to: root.appending(path: "a/.ovaultrc"))
    #expect(try ProjectConfig.find(from: nested)?.project == "nearer")
    #expect(try ProjectConfig.find(from: root)?.project == "from-json")

    try Data("# no key\n".utf8).write(to: root.appending(path: "a/.ovaultrc"))
    #expect(throws: ProjectConfigError.empty(path: root.appending(path: "a/.ovaultrc").standardizedFileURL.path)) {
        try ProjectConfig.find(from: nested)
    }
}

@Test func ovaultrcSelectsByProjectNameAndFolderWithPatterns() throws {
    let vault = Vault(items: [
        Item(name: ".env", kind: .env, project: "api", content: "A=1"),
        Item(name: "WORKER_2_TOKEN", kind: .secret, project: "other", content: "w2"),
        Item(name: "WORKER_12_TOKEN", kind: .secret, content: "w12"),
        Item(name: "WORKER_13_TOKEN", kind: .secret, content: "w13"),
        Item(name: "NODE_07", kind: .secret, content: "n7"),
        Item(name: "DEPLOY", kind: .secret, content: "d", folder: "CI"),
        Item(name: "AWS_ID", kind: .secret, project: "other", content: "id"),
        Item(name: "AWS_SECRET", kind: .secret, project: "other", content: "s"),
        Item(name: "x.y", kind: .secret, project: "api.v2", content: "literal"),
    ])
    func env(_ text: String) throws -> [String: String] { Vault.env(of: try ProjectConfig.parse(text).items(in: vault)) }

    #expect(try env("project-name=api") == ["A": "1"])
    #expect(try env("folder-name=CI\nsecret-name=AWS_.*") == ["DEPLOY": "d", "AWS_ID": "id", "AWS_SECRET": "s"])
    #expect(try env("secret-name=WORKER_{1..12}_TOKEN") == ["WORKER_2_TOKEN": "w2", "WORKER_12_TOKEN": "w12"])
    #expect(try env("secret-name=NODE_{01..09}") == ["NODE_07": "n7"])
    #expect(try env("project-name=api.v2") == ["x.y": "literal"])
    #expect(try env("project-name=ap") == [:]) // whole-name match, not substring

    let config = try ProjectConfig.parse("project-name=api\nfolder-name=Nope")
    #expect(config.unmatched(in: vault) == [.init(.folder, "Nope")])
}

@Test func legacyVaultWithoutNewFieldsStillDecodes() throws {
    // Exactly what a vault written before password/file items looked like.
    let legacy = """
    {"items":[{"content":"s3cr3t","createdAt":"2026-01-01T00:00:00Z","id":"5F0C1A52-5A36-4E0B-9B55-0B0B7C1D2E3F",\
    "kind":"sshKey","name":"id_ed25519","notes":"","passphrase":"pp","project":"app","updatedAt":"2026-01-01T00:00:00Z"}],"version":1}
    """
    let vault = try JSONDecoder.vault.decode(Vault.self, from: Data(legacy.utf8))
    let item = try #require(vault.items.first)
    #expect(item.kind == .sshKey && item.content == "s3cr3t" && item.passphrase == "pp" && item.project == "app")
    #expect(item.username == nil && item.url == nil && item.fileName == nil && item.data == nil)
}

@Test func fileItemBinaryRoundTrip() throws {
    let bytes = Data((0...255).map { UInt8($0) } + [0xFF, 0xFE, 0x00, 0xC3, 0x28]) // not valid UTF-8
    let file = VaultFile(url: try tempDir().appending(path: "vault.ovault"))
    let key = try file.create(password: "pw")
    try file.update(key: key) {
        $0.items.append(Item(name: "cert", kind: .file, content: "", fileName: "cert.p12", data: bytes))
        $0.items.append(Item(name: "GitHub", kind: .password, content: "hunter2", username: "fran", url: "https://github.com"))
    }
    let (vault, _) = try file.unlock(password: "pw")
    #expect(vault.items[0].data == bytes && vault.items[0].fileName == "cert.p12")
    #expect(vault.items[1].username == "fran" && vault.items[1].content == "hunter2")
}

@Test func searchMatchesNameProjectOrFolderSortedByName() {
    let items = [
        Item(name: "stripe_key", kind: .secret, project: "shop", content: "a"),
        Item(name: "AWS_TOKEN", kind: .secret, content: "b", folder: "Cloud"),
        Item(name: "id_ed25519", kind: .sshKey, project: "Shop", content: "c"),
    ]
    #expect(items.searched("").map(\.name) == ["AWS_TOKEN", "id_ed25519", "stripe_key"])
    #expect(items.searched("aws").map(\.name) == ["AWS_TOKEN"])
    #expect(items.searched("cloud").map(\.name) == ["AWS_TOKEN"])
    #expect(items.searched("SHOP").map(\.name) == ["id_ed25519", "stripe_key"])
    #expect(items.searched("secret").isEmpty) // never matches on content
}
