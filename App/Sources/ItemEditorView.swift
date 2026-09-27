import OpenVaultCore
import SwiftUI

struct ItemEditorView: View {
    let draft: EditorDraft
    let onSave: (Item) -> Void

    @Environment(VaultStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var item: Item
    @State private var project: String
    @State private var passphrase: String
    @State private var showPassphrase = false
    @State private var generating = false
    @State private var confirmDiscard = false
    @State private var generateFailed = false

    init(draft: EditorDraft, onSave: @escaping (Item) -> Void) {
        self.draft = draft
        self.onSave = onSave
        _item = State(initialValue: draft.item)
        _project = State(initialValue: draft.item.project ?? "")
        _passphrase = State(initialValue: draft.item.passphrase ?? "")
    }

    private var nameError: String? {
        let name = item.name.trimmingCharacters(in: .whitespaces)
        if name.isEmpty { return nil } // required, but don't nag before typing
        if item.kind == .secret, name.wholeMatch(of: /[A-Za-z_][A-Za-z0-9_]*/) == nil {
            return "Usa un nombre de variable válido: letras, números y _ (p. ej. API_KEY)."
        }
        return nil
    }

    private var isDirty: Bool {
        item != draft.item || project != (draft.item.project ?? "") || passphrase != (draft.item.passphrase ?? "")
            || (draft.isNew && !draft.item.content.isEmpty)
    }

    private var canSave: Bool {
        !item.name.trimmingCharacters(in: .whitespaces).isEmpty && nameError == nil && !item.content.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    Picker("Tipo", selection: $item.kind.animation(Motion.standard)) {
                        ForEach(Item.Kind.allCases, id: \.self) { kind in
                            Label(kind.singular, systemImage: kind.symbol).tag(kind)
                        }
                    }
                    TextField("Nombre", text: $item.name, prompt: Text(namePrompt))
                    if let nameError {
                        Text(nameError).font(.caption).foregroundStyle(.red)
                    }
                    TextField("Proyecto", text: $project, prompt: Text("Opcional"))
                        .textInputSuggestions {
                            ForEach(store.vault.projects.filter { project.isEmpty || $0.localizedCaseInsensitiveContains(project) }, id: \.self) {
                                Text($0).textInputCompletion($0)
                            }
                        }
                }

                Section {
                    if item.kind == .secret {
                        TextField("Valor", text: $item.content, axis: .vertical)
                            .font(.body.monospaced())
                            .lineLimit(1...6)
                    } else {
                        TextEditor(text: $item.content)
                            .font(.body.monospaced())
                            .frame(minHeight: 160)
                            .scrollContentBackground(.hidden)
                            .accessibilityLabel("Contenido")
                    }
                } header: {
                    HStack {
                        Text(contentTitle)
                        Spacer()
                        if item.kind == .sshKey, item.content.isEmpty {
                            Button(generating ? "Generando…" : "Generar ed25519", systemImage: "wand.and.stars") { generate() }
                                .buttonStyle(.borderless)
                                .disabled(generating)
                        }
                    }
                }

                if item.kind != .secret, item.kind != .env {
                    Section {
                        HStack {
                            Group {
                                if showPassphrase { TextField("Passphrase", text: $passphrase) }
                                else { SecureField("Passphrase", text: $passphrase) }
                            }
                            .font(.body.monospaced())
                            Button {
                                showPassphrase.toggle()
                            } label: {
                                Image(systemName: showPassphrase ? "eye.slash" : "eye")
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel(showPassphrase ? "Ocultar passphrase" : "Mostrar passphrase")
                        }
                    } footer: {
                        Text("Contraseña para descifrar la clave, si tiene.")
                    }
                }

                Section("Notas") {
                    TextField("Notas", text: $item.notes, prompt: Text("Opcional"), axis: .vertical)
                        .lineLimit(2...5)
                        .labelsHidden()
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("Cancelar", role: .cancel) { if isDirty { confirmDiscard = true } else { dismiss() } }
                    .keyboardShortcut(.cancelAction)
                Button(draft.isNew ? "Crear" : "Guardar") { save() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSave)
            }
            .padding(16)
        }
        .frame(width: 520, height: 600)
        .interactiveDismissDisabled(isDirty)
        .confirmationDialog("¿Descartar los cambios?", isPresented: $confirmDiscard) {
            Button("Descartar cambios", role: .destructive) { dismiss() }
            Button("Seguir editando", role: .cancel) {}
        }
        .alert("No se pudo ejecutar ssh-keygen", isPresented: $generateFailed) {}
    }

    private var namePrompt: String {
        switch item.kind {
        case .env: ".env.production"
        case .secret: "API_KEY"
        case .sshKey: "id_ed25519_github"
        case .gpgKey: "Firma de commits"
        case .other: "Nombre"
        }
    }

    private var contentTitle: String {
        switch item.kind {
        case .env: "Contenido .env"
        case .secret: "Valor"
        case .sshKey: "Clave privada (OpenSSH)"
        case .gpgKey: "Clave armada (ASCII)"
        case .other: "Contenido"
        }
    }

    private func generate() {
        generating = true
        Task {
            let comment = item.name.isEmpty ? "openvault" : item.name
            if let key = await KeyInfo.generateSSH(comment: comment, passphrase: passphrase) {
                item.content = key
            } else {
                generateFailed = true
            }
            generating = false
        }
    }

    private func save() {
        var result = item
        result.name = result.name.trimmingCharacters(in: .whitespaces)
        let trimmedProject = project.trimmingCharacters(in: .whitespaces)
        result.project = trimmedProject.isEmpty ? nil : trimmedProject
        result.passphrase = passphrase.isEmpty ? nil : passphrase
        onSave(result)
        dismiss()
    }
}
