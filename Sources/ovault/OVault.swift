import ArgumentParser
import Foundation
import OpenVaultCore

@main
struct OVault: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ovault",
        abstract: "Use OpenVault secrets in your projects.",
        version: ovaultVersion,
        subcommands: [Init.self, SetCommand.self, Import.self, Get.self, Export.self, Run.self, Load.self, Hook.self, List.self]
    )
}

// MARK: - Shared

struct ProjectOption: ParsableArguments {
    @Option(name: .shortAndLong, help: "Project (defaults to the one in the nearest .ovault or .openvault file).")
    var project: String?

    func resolve(required: Bool = true) throws -> String? {
        try Self.resolve(project, required: required)
    }

    static func resolve(_ explicit: String?, required: Bool = true) throws -> String? {
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        if let name = try explicit ?? ProjectConfig.find(from: cwd)?.project { return name }
        if required {
            throw CLIError("No project: pass one, or create a .ovault file with `project-name=my-project` (or run `ovault init`).")
        }
        return nil
    }
}

/// An error shown as a single line, without the usage text ArgumentParser adds to validation errors.
struct CLIError: LocalizedError {
    let errorDescription: String?
    init(_ message: String) { errorDescription = message }
}

func warn(_ message: String) {
    FileHandle.standardError.write(Data((message + "\n").utf8))
}

func unlock(prompt: Bool = true) throws -> (VaultFile, Vault, VaultKey) {
    let file = VaultFile()
    guard file.exists else { throw VaultError.notFound }
    let password: String
    if let env = ProcessInfo.processInfo.environment["OPENVAULT_PASSWORD"] {
        password = env
    } else if !prompt {
        throw CLIError("Vault is locked; nothing was loaded. Run  eval \"$(ovault load)\"  to unlock it and load the project.")
    } else {
        var buf = [CChar](repeating: 0, count: 1024)
        guard let p = readpassphrase("Master password: ", &buf, buf.count, RPP_REQUIRE_TTY) else {
            throw ValidationError("Couldn't read the password (no TTY). Set OPENVAULT_PASSWORD.")
        }
        password = String(cString: p)
        buf.withUnsafeMutableBufferPointer { _ = memset($0.baseAddress, 0, $0.count) }
    }
    let (vault, key) = try file.unlock(password: password)
    return (file, vault, key)
}

func readStdin() -> String {
    let data = FileHandle.standardInput.readDataToEndOfFile()
    return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .newlines)
}

// MARK: - Commands

struct Init: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Link the current directory to a project (creates .openvault).")

    @Option(name: .shortAndLong, help: "Project name (defaults to the directory name).")
    var project: String?

    func run() throws {
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let name = project ?? cwd.lastPathComponent
        try ProjectConfig(project: name).write(to: cwd)
        print("✓ Created .openvault for project “\(name)”. It contains no secrets, so it's safe to commit.")
    }
}

struct SetCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "set", abstract: "Save a single secret. Reads it from stdin if VALUE is omitted.")

    @Argument var key: String
    @Argument var value: String?
    @OptionGroup var project: ProjectOption

    func run() throws {
        let value = value ?? readStdin()
        let projectName = try project.resolve()
        let (file, _, key) = try unlock()
        try file.update(key: key) { vault in
            if let i = vault.items.firstIndex(where: { $0.kind == .secret && $0.name == self.key && $0.project == projectName }) {
                vault.items[i].content = value
                vault.items[i].updatedAt = Date()
            } else {
                vault.items.append(Item(name: self.key, kind: .secret, project: projectName, content: value))
            }
        }
        print("✓ Saved \(self.key) to “\(projectName!)”.")
    }
}

struct Import: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Import a .env file into the project.")

    @Argument(help: "Path to the .env file.") var path: String
    @Option(help: "Item name (defaults to the file name).") var name: String?
    @OptionGroup var project: ProjectOption

    func run() throws {
        let url = URL(fileURLWithPath: path)
        let content = try String(contentsOf: url, encoding: .utf8)
        let projectName = try project.resolve()
        let itemName = name ?? url.lastPathComponent
        let (file, _, key) = try unlock()
        try file.update(key: key) { vault in
            if let i = vault.items.firstIndex(where: { $0.kind == .env && $0.name == itemName && $0.project == projectName }) {
                vault.items[i].content = content
                vault.items[i].updatedAt = Date()
            } else {
                vault.items.append(Item(name: itemName, kind: .env, project: projectName, content: content))
            }
        }
        print("✓ Imported \(DotEnv.parse(content).count) variables as “\(itemName)” into “\(projectName!)”.")
    }
}

struct Get: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Print a value: a project variable, or an item's content by name.")

    @Argument var name: String
    @Flag(help: "Print the item's passphrase instead of its content.") var passphrase = false
    @OptionGroup var project: ProjectOption

    func run() throws {
        let projectName = try project.resolve(required: false)
        let (_, vault, _) = try unlock()
        if !passphrase, let value = vault.mergedEnv(project: projectName)[name] {
            print(value)
            return
        }
        let candidates = vault.items.filter { $0.name == name }
        guard let item = candidates.first(where: { $0.project == projectName }) ?? candidates.first else {
            throw ValidationError("“\(name)” not found.")
        }
        if passphrase {
            guard let p = item.passphrase else { throw ValidationError("“\(name)” has no passphrase.") }
            print(p)
        } else if item.kind == .file {
            FileHandle.standardOutput.write(item.data ?? Data()) // raw bytes: `ovault get cert.p12 > cert.p12`
        } else {
            print(item.content)
        }
    }
}

struct Export: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Export the project's merged environment.")

    enum Format: String, ExpressibleByArgument { case env, json }
    @Option var format: Format = .env
    @OptionGroup var project: ProjectOption

    func run() throws {
        let projectName = try project.resolve()
        let (_, vault, _) = try unlock()
        let env = vault.mergedEnv(project: projectName)
        switch format {
        case .env:
            print(DotEnv.serialize(env), terminator: "")
        case .json:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            print(String(decoding: try encoder.encode(env), as: UTF8.self))
        }
    }
}

struct Run: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Run a command with the project's secrets as environment variables.")

    @OptionGroup var project: ProjectOption
    @Argument(parsing: .postTerminator) var command: [String]

    func run() throws {
        guard !command.isEmpty else { throw ValidationError("Usage: ovault run -- <command> [args…]") }
        let projectName = try project.resolve()
        let (_, vault, _) = try unlock()
        for (k, v) in vault.mergedEnv(project: projectName) { setenv(k, v, 1) }
        unsetenv("OPENVAULT_PASSWORD")
        let argv = command.map { strdup($0) } + [nil]
        execvp(command[0], argv)
        throw ValidationError("Couldn't run “\(command[0])”: \(String(cString: strerror(errno)))")
    }
}

struct Load: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Load the project's environment into your shell, or run a command with it.",
        discussion: """
        With a command, runs it with the project's environment and returns its exit code:

            ovault load my-project -- npm run dev

        Without a command, prints `export` lines for your shell to evaluate (a child process \
        can't change the environment of the shell that launched it):

            eval "$(ovault load my-project)"

        Without a project name, the one in the nearest .ovault file is used (in the current \
        directory or any of its parents). It's a text file with a single \
        `project-name=my-project` line; it allows # comments and contains no secrets:

            ovault load -- npm run dev
            eval "$(ovault load)"

        What gets loaded:
          · .env files and secrets: their variables as-is (on conflict, the secret wins).
          · Passwords: NAME=password and NAME_USERNAME=username. If the item name isn't a \
        valid variable name, it's uppercased and everything else becomes _ \
        (“Postgres prod” → POSTGRES_PROD).
          · Files: written to a private temporary directory (0700, files 0600), and the \
        variable, named with the same rule (“AuthKey_AB12.p8” → AUTHKEY_AB12_P8), holds \
        the path. With a command they're removed when it exits; with eval they stay until \
        the next `ovault load` in that shell.
          · SSH keys, GPG keys and “other” items aren't loaded: they don't map cleanly to variables.

        Variables whose name isn't a valid identifier are skipped with a warning.
        """)

    @Argument(help: "Project (defaults to the one in the nearest .ovault or .openvault file).") var project: String?
    @Argument(parsing: .postTerminator, help: "Command to run, after `--`.") var command: [String] = []
    @Flag(help: "Fail instead of prompting for the master password when OPENVAULT_PASSWORD is unset (used by the hook).")
    var noPrompt = false

    func run() throws {
        guard let name = try ProjectOption.resolve(project) else { return }
        if command.isEmpty, isatty(STDOUT_FILENO) != 0 {
            // Printing exports to a terminal would only put the secrets on screen.
            throw CLIError("To load the variables into this shell, use:  eval \"$(ovault load \(name))\"")
        }
        let (_, vault, _) = try unlock(prompt: !noPrompt)
        guard vault.projects.contains(name) else { throw CLIError("Project “\(name)” doesn't exist in the vault.") }

        var env = vault.mergedEnv(project: name)
        let invalid = env.keys.filter { !Shell.isValidName($0) }.sorted()
        for key in invalid { env[key] = nil }
        if !invalid.isEmpty {
            warn("ovault: skipping variables with invalid names: \(invalid.joined(separator: ", "))")
        }
        let files = vault.fileEnv(project: name).filter { env[$0.key] == nil }
        let tmp = try materialize(files, into: &env)

        if command.isEmpty {
            // Drop the files of a previous load in this shell, then export.
            var script = "[ -n \"${_OVAULT_TMP-}\" ] && rm -rf -- \"$_OVAULT_TMP\"\n" + Shell.exports(env)
            // What the shell hook unsets when you leave the project.
            script += "_OVAULT_VARS=\(Shell.quote(env.keys.sorted().joined(separator: " ")))\n"
            script += tmp.map { "_OVAULT_TMP=\(Shell.quote($0.path))\n" } ?? "unset _OVAULT_TMP\n"
            print(script, terminator: "")
            warn("ovault: loaded “\(name)” (\(env.count) variables).")
        } else {
            defer { if let tmp { try? FileManager.default.removeItem(at: tmp) } }
            var full = ProcessInfo.processInfo.environment.merging(env) { $1 }
            full["OPENVAULT_PASSWORD"] = nil
            throw ExitCode(try spawnAndWait(command, environment: full))
        }
    }
}

struct Hook: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Print a shell hook that loads the project when you enter its directory and unloads it when you leave.",
        discussion: """
        Add it to your ~/.zshrc or ~/.bashrc:

            eval "$(ovault hook zsh)"

        When you enter a directory with a .ovault (or .openvault) file, or one of its \
        subdirectories, the hook runs `ovault load` and exports the project's variables; \
        when you leave, it unsets them and removes the temporary files.

        The hook never prompts for the master password or bypasses unlocking: it only loads \
        if OPENVAULT_PASSWORD is set in the shell. Otherwise it warns once when you enter the \
        project and moves on; to load, run  eval "$(ovault load)"  yourself (it asks for the \
        password once) and the hook takes care of unloading when you leave.

        The .ovault file only names a project; even so, entering someone else's repository \
        that names one of your projects exposes that environment to whatever you run there. \
        The hook warns every time it loads something.
        """)

    enum ShellKind: String, ExpressibleByArgument, CaseIterable { case zsh, bash }
    @Argument(help: "zsh or bash.") var shell: ShellKind

    func run() {
        print(Self.script)
        switch shell {
        case .zsh: print("autoload -Uz add-zsh-hook && add-zsh-hook chpwd _ovault_hook\n_ovault_hook")
        case .bash: print(#"case ";${PROMPT_COMMAND-};" in *";_ovault_hook;"*) ;; *) PROMPT_COMMAND="_ovault_hook${PROMPT_COMMAND:+;$PROMPT_COMMAND}" ;; esac"#)
        }
    }

    // Only acts when the project root changes, so a locked vault costs one line per project, not per `cd`.
    // ponytail: unloading unsets the variables; it does not restore a value they had before loading.
    static let script = #"""
    _ovault_hook() {
      local dir="$PWD" root="" out
      while [ -n "$dir" ]; do
        if [ -f "$dir/.ovault" ] || [ -f "$dir/.openvault" ]; then root="$dir"; break; fi
        dir="${dir%/*}"
      done
      [ "$root" = "${_OVAULT_ROOT-}" ] && return 0
      if [ -n "${_OVAULT_VARS-}" ]; then eval "unset $_OVAULT_VARS"; fi
      if [ -n "${_OVAULT_TMP-}" ]; then rm -rf -- "$_OVAULT_TMP"; fi
      unset _OVAULT_VARS _OVAULT_TMP
      _OVAULT_ROOT="$root"
      [ -z "$root" ] && return 0
      if out="$(command ovault load --no-prompt)"; then eval "$out"; fi
      return 0
    }
    """#
}

/// Writes file items under a fresh private directory (0700, files 0600) and adds their paths to `env`.
func materialize(_ files: [String: Item], into env: inout [String: String]) throws -> URL? {
    guard !files.isEmpty else { return nil }
    var template = Array((NSTemporaryDirectory() as NSString).appendingPathComponent("ovault-XXXXXX").utf8CString)
    guard mkdtemp(&template) != nil else { throw POSIXError(.init(rawValue: errno) ?? .EIO) }
    let dir = URL(fileURLWithPath: String(decoding: template.dropLast().map { UInt8(bitPattern: $0) }, as: UTF8.self))
    do {
        for (name, item) in files {
            // One directory per variable so every file keeps its original name without clashing.
            let sub = dir.appending(path: name)
            try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: false,
                                                    attributes: [.posixPermissions: 0o700])
            var fileName = ((item.fileName ?? item.name) as NSString).lastPathComponent
            if ["", ".", "..", "/"].contains(fileName) { fileName = "file" }
            let path = sub.appending(path: fileName).path
            guard FileManager.default.createFile(atPath: path, contents: item.data ?? Data(),
                                                 attributes: [.posixPermissions: 0o600]) else {
                throw CocoaError(.fileWriteUnknown)
            }
            env[name] = path
        }
    } catch {
        try? FileManager.default.removeItem(at: dir)
        throw error
    }
    return dir
}

nonisolated(unsafe) private var childPID: pid_t = 0

/// Runs `command` as a child sharing our terminal and waits for it, so temporary files can be removed afterwards.
/// Returns its exit code (128 + signal if it was killed).
func spawnAndWait(_ command: [String], environment: [String: String]) throws -> Int32 {
    // Ctrl-C / Ctrl-\ reach the child directly (same foreground process group): we only need to outlive it.
    // ponytail: a SIGINT sent to ovault's pid alone is not forwarded; forwarding would deliver Ctrl-C twice.
    for sig in [SIGINT, SIGQUIT] { signal(sig) { _ in } }
    for sig in [SIGTERM, SIGHUP] { signal(sig) { if childPID > 0 { kill(childPID, $0) } } }
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env") // looks the command up in PATH, then execs it
    process.arguments = ["--"] + command
    process.environment = environment
    try process.run() // stdin, stdout and stderr are inherited
    childPID = process.processIdentifier
    process.waitUntilExit()
    return process.terminationReason == .exit ? process.terminationStatus : 128 + process.terminationStatus
}

struct List: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "List the project's items (without values).")

    @Flag(name: .shortAndLong, help: "All projects.") var all = false
    @OptionGroup var project: ProjectOption

    func run() throws {
        let projectName = all ? nil : try project.resolve(required: false)
        let (_, vault, _) = try unlock()
        for item in vault.items(in: projectName).sorted(by: { $0.name < $1.name }) {
            let kind = item.kind.rawValue.padding(toLength: 7, withPad: " ", startingAt: 0)
            print("\(kind)  \(item.name)\(item.project.map { "  [\($0)]" } ?? "")")
        }
    }
}
