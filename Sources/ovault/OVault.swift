import ArgumentParser
import Foundation
import OpenVaultCore

@main
struct OVault: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ovault",
        abstract: "Usa los secretos de OpenVault en tus proyectos.",
        version: ovaultVersion,
        subcommands: [Init.self, SetCommand.self, Import.self, Get.self, Export.self, Run.self, Load.self, Hook.self, List.self]
    )
}

// MARK: - Shared

struct ProjectOption: ParsableArguments {
    @Option(name: .shortAndLong, help: "Proyecto (por defecto, el del archivo .ovault o .openvault más cercano).")
    var project: String?

    func resolve(required: Bool = true) throws -> String? {
        try Self.resolve(project, required: required)
    }

    static func resolve(_ explicit: String?, required: Bool = true) throws -> String? {
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        if let name = try explicit ?? ProjectConfig.find(from: cwd)?.project { return name }
        if required {
            throw CLIError("No hay proyecto: indícalo, o crea un archivo .ovault con `project-name=mi-proyecto` (o ejecuta `ovault init`).")
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
        throw CLIError("Vault bloqueado, no se cargó nada. Ejecuta  eval \"$(ovault load)\"  para desbloquearlo y cargar el proyecto.")
    } else {
        var buf = [CChar](repeating: 0, count: 1024)
        guard let p = readpassphrase("Contraseña maestra: ", &buf, buf.count, RPP_REQUIRE_TTY) else {
            throw ValidationError("No se pudo leer la contraseña (sin TTY). Define OPENVAULT_PASSWORD.")
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
    static let configuration = CommandConfiguration(abstract: "Vincula el directorio actual a un proyecto (crea .openvault).")

    @Option(name: .shortAndLong, help: "Nombre del proyecto (por defecto, el nombre del directorio).")
    var project: String?

    func run() throws {
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let name = project ?? cwd.lastPathComponent
        try ProjectConfig(project: name).write(to: cwd)
        print("✓ .openvault creado para el proyecto «\(name)». No contiene secretos; puedes commitearlo.")
    }
}

struct SetCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "set", abstract: "Guarda un secreto individual. Sin VALUE, lo lee de stdin.")

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
        print("✓ \(self.key) guardado en «\(projectName!)».")
    }
}

struct Import: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Importa un archivo .env al proyecto.")

    @Argument(help: "Ruta al archivo .env.") var path: String
    @Option(help: "Nombre del item (por defecto, el nombre del archivo).") var name: String?
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
        print("✓ \(DotEnv.parse(content).count) variables importadas como «\(itemName)» en «\(projectName!)».")
    }
}

struct Get: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Imprime un valor: variable del proyecto, o el contenido de un item por nombre.")

    @Argument var name: String
    @Flag(help: "Imprime la passphrase del item en vez de su contenido.") var passphrase = false
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
            throw ValidationError("No se encontró «\(name)».")
        }
        if passphrase {
            guard let p = item.passphrase else { throw ValidationError("«\(name)» no tiene passphrase.") }
            print(p)
        } else if item.kind == .file {
            FileHandle.standardOutput.write(item.data ?? Data()) // raw bytes: `ovault get cert.p12 > cert.p12`
        } else {
            print(item.content)
        }
    }
}

struct Export: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Exporta el entorno combinado del proyecto.")

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
    static let configuration = CommandConfiguration(abstract: "Ejecuta un comando con los secretos del proyecto como variables de entorno.")

    @OptionGroup var project: ProjectOption
    @Argument(parsing: .postTerminator) var command: [String]

    func run() throws {
        guard !command.isEmpty else { throw ValidationError("Uso: ovault run -- <comando> [args…]") }
        let projectName = try project.resolve()
        let (_, vault, _) = try unlock()
        for (k, v) in vault.mergedEnv(project: projectName) { setenv(k, v, 1) }
        unsetenv("OPENVAULT_PASSWORD")
        let argv = command.map { strdup($0) } + [nil]
        execvp(command[0], argv)
        throw ValidationError("No se pudo ejecutar «\(command[0])»: \(String(cString: strerror(errno)))")
    }
}

struct Load: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Carga el entorno del proyecto en tu shell, o ejecuta un comando con él.",
        discussion: """
        Con comando, lo ejecuta con el entorno del proyecto y devuelve su código de salida:

            ovault load mi-proyecto -- npm run dev

        Sin comando, imprime líneas `export` para que las evalúe tu shell (un proceso hijo \
        no puede modificar el entorno del shell que lo lanzó):

            eval "$(ovault load mi-proyecto)"

        Sin nombre de proyecto se usa el del archivo .ovault más cercano (en el directorio \
        actual o en alguno de sus padres). Es un archivo de texto con una línea \
        `project-name=mi-proyecto`; admite comentarios con # y no contiene secretos:

            ovault load -- npm run dev
            eval "$(ovault load)"

        Qué se carga:
          · Archivos .env y secretos: sus variables tal cual (si chocan, gana el secreto).
          · Contraseñas: NOMBRE=contraseña y NOMBRE_USERNAME=usuario. Si el nombre del item \
        no es un nombre de variable válido se pasa a mayúsculas y lo demás se cambia por _ \
        («Postgres prod» → POSTGRES_PROD).
          · Archivos: se escriben en un directorio temporal privado (0700, archivo 0600) y la \
        variable, nombrada con la misma regla («AuthKey_AB12.p8» → AUTHKEY_AB12_P8), contiene \
        la ruta. Con comando se borran al terminar; con eval quedan hasta el siguiente \
        `ovault load` en ese shell.
          · Claves SSH, claves GPG y «otros» no se cargan: no tienen un mapeo claro a variables.

        Las variables cuyo nombre no es un identificador válido se omiten con un aviso.
        """)

    @Argument(help: "Proyecto (por defecto, el del archivo .ovault o .openvault más cercano).") var project: String?
    @Argument(parsing: .postTerminator, help: "Comando a ejecutar, después de `--`.") var command: [String] = []
    @Flag(help: "Falla en vez de pedir la contraseña maestra si no hay OPENVAULT_PASSWORD (lo usa el hook).")
    var noPrompt = false

    func run() throws {
        guard let name = try ProjectOption.resolve(project) else { return }
        if command.isEmpty, isatty(STDOUT_FILENO) != 0 {
            // Printing exports to a terminal would only put the secrets on screen.
            throw CLIError("Para cargar las variables en este shell usa:  eval \"$(ovault load \(name))\"")
        }
        let (_, vault, _) = try unlock(prompt: !noPrompt)
        guard vault.projects.contains(name) else { throw CLIError("El proyecto «\(name)» no existe en el vault.") }

        var env = vault.mergedEnv(project: name)
        let invalid = env.keys.filter { !Shell.isValidName($0) }.sorted()
        for key in invalid { env[key] = nil }
        if !invalid.isEmpty {
            warn("ovault: se omiten variables con nombre no válido: \(invalid.joined(separator: ", "))")
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
            warn("ovault: «\(name)» cargado (\(env.count) variables).")
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
        abstract: "Imprime un hook de shell que carga el proyecto al entrar a su directorio y lo descarga al salir.",
        discussion: """
        Agrégalo a tu ~/.zshrc o ~/.bashrc:

            eval "$(ovault hook zsh)"

        Al entrar a un directorio con un archivo .ovault (o .openvault), o a uno de sus \
        subdirectorios, el hook ejecuta `ovault load` y exporta las variables del proyecto; \
        al salir las quita y borra los archivos temporales.

        El hook nunca pide la contraseña maestra ni se salta el desbloqueo: solo carga si \
        OPENVAULT_PASSWORD está definida en el shell. Si no, avisa una vez al entrar al \
        proyecto y sigue; para cargar, ejecuta tú  eval "$(ovault load)"  (pide la contraseña \
        una vez) y el hook se encarga de descargar al salir.

        El archivo .ovault solo nombra un proyecto; aun así, entrar a un repositorio ajeno que \
        nombre uno de tus proyectos expone ese entorno a lo que ejecutes ahí. El hook avisa \
        cada vez que carga algo.
        """)

    enum ShellKind: String, ExpressibleByArgument, CaseIterable { case zsh, bash }
    @Argument(help: "zsh o bash.") var shell: ShellKind

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
    static let configuration = CommandConfiguration(abstract: "Lista los items del proyecto (sin valores).")

    @Flag(name: .shortAndLong, help: "Todos los proyectos.") var all = false
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
