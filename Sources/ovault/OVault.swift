import ArgumentParser
import Foundation
import OpenVaultCore

@main
struct OVault: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ovault",
        abstract: "Usa los secretos de OpenVault en tus proyectos.",
        subcommands: [Init.self, SetCommand.self, Import.self, Get.self, Export.self, Run.self, List.self]
    )
}

// MARK: - Shared

struct ProjectOption: ParsableArguments {
    @Option(name: .shortAndLong, help: "Proyecto (por defecto, el del archivo .openvault más cercano).")
    var project: String?

    func resolve(required: Bool = true) throws -> String? {
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        if let name = project ?? ProjectConfig.find(from: cwd)?.project { return name }
        if required { throw ValidationError("No hay proyecto: usa --project o ejecuta `ovault init`.") }
        return nil
    }
}

func unlock() throws -> (VaultFile, Vault, VaultKey) {
    let file = VaultFile()
    guard file.exists else { throw VaultError.notFound }
    let password: String
    if let env = ProcessInfo.processInfo.environment["OPENVAULT_PASSWORD"] {
        password = env
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
