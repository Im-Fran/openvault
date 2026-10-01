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
    @State private var pickingFile = false
    @State private var fileError: String?

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
            return String(localized: "Use a valid variable name: letters, numbers, and _ (e.g. API_KEY).")
        }
        return nil
    }

    private var isDirty: Bool {
        item != draft.item || project != (draft.item.project ?? "") || passphrase != (draft.item.passphrase ?? "")
            || (draft.isNew && !draft.item.content.isEmpty)
    }

    private var canSave: Bool {
        !item.name.trimmingCharacters(in: .whitespaces).isEmpty && nameError == nil
            && (item.kind == .file ? item.data != nil : !item.content.isEmpty)
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    Picker("Kind", selection: $item.kind.animation(Motion.standard)) {
                        ForEach(Item.Kind.allCases, id: \.self) { kind in
                            Label(kind.singular, systemImage: kind.symbol).tag(kind)
                        }
                    }
                    TextField("Name", text: $item.name, prompt: Text(namePrompt))
                    if let nameError {
                        Text(nameError).font(.caption).foregroundStyle(.red)
                    }
                    TextField("Project", text: $project, prompt: Text("Optional"))
                        .textInputSuggestions {
                            ForEach(store.vault.projects.filter { project.isEmpty || $0.localizedCaseInsensitiveContains(project) }, id: \.self) {
                                Text($0).textInputCompletion($0)
                            }
                        }
                }

                Section {
                    if item.kind == .secret {
                        TextField("Value", text: $item.content, axis: .vertical)
                            .font(.body.monospaced())
                            .lineLimit(1...6)
                    } else if item.kind == .password {
                        TextField("Username", text: optional(\.username), prompt: Text("Optional"))
                        HStack {
                            Group {
                                if showPassphrase { TextField("Password", text: $item.content) }
                                else { SecureField("Password", text: $item.content) }
                            }
                            .font(.body.monospaced())
                            revealButton(show: "Show Password", hide: "Hide Password")
                        }
                        TextField("URL", text: optional(\.url), prompt: Text("Optional"))
                    } else if item.kind == .file {
                        if let data = item.data {
                            LabeledContent(item.fileName ?? String(localized: "File"), value: Int64(data.count).formatted(.byteCount(style: .file)))
                        }
                        Button(item.data == nil ? "Choose File…" : "Replace File…", systemImage: "doc.badge.plus") { pickingFile = true }
                        if let fileError {
                            Text(fileError).font(.caption).foregroundStyle(.red)
                        }
                    } else {
                        TextEditor(text: $item.content)
                            .font(.body.monospaced())
                            .frame(minHeight: 160)
                            .scrollContentBackground(.hidden)
                            .accessibilityLabel("Content")
                    }
                } header: {
                    HStack {
                        Text(contentTitle)
                        Spacer()
                        if item.kind == .sshKey, item.content.isEmpty {
                            Button(generating ? "Generating…" : "Generate ed25519", systemImage: "wand.and.stars") { generate() }
                                .buttonStyle(.borderless)
                                .disabled(generating)
                        }
                    }
                }

                if item.kind != .secret, item.kind != .env, item.kind != .password {
                    Section {
                        HStack {
                            Group {
                                if showPassphrase { TextField("Passphrase", text: $passphrase) }
                                else { SecureField("Passphrase", text: $passphrase) }
                            }
                            .font(.body.monospaced())
                            revealButton(show: "Show Passphrase", hide: "Hide Passphrase")
                        }
                    } footer: {
                        Text(item.kind == .file ? "Password for the file, if it has one (e.g. a .p12)." : "Password to decrypt the key, if it has one.")
                    }
                }

                Section("Notes") {
                    TextField("Notes", text: $item.notes, prompt: Text("Optional"), axis: .vertical)
                        .lineLimit(2...5)
                        .labelsHidden()
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { if isDirty { confirmDiscard = true } else { dismiss() } }
                    .keyboardShortcut(.cancelAction)
                Button(draft.isNew ? "Create" : "Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSave)
            }
            .padding(16)
        }
        .frame(width: 520, height: 600)
        .interactiveDismissDisabled(isDirty)
        .confirmationDialog("Discard Changes?", isPresented: $confirmDiscard) {
            Button("Discard Changes", role: .destructive) { dismiss() }
            Button("Keep Editing", role: .cancel) {}
        }
        .alert("Couldn’t Run ssh-keygen", isPresented: $generateFailed) {}
        .fileImporter(isPresented: $pickingFile, allowedContentTypes: [.data]) { result in
            guard let url = try? result.get() else { return }
            guard let file = Item.file(at: url) else {
                let limit = Int64(Item.maxFileBytes).formatted(.byteCount(style: .file))
                fileError = String(localized: "Couldn’t read the file, or it’s larger than \(limit).")
                return
            }
            fileError = nil
            item.data = file.data
            item.fileName = file.fileName
            if item.name.isEmpty { item.name = file.name }
        }
    }

    /// Text binding over an optional field: empty text is stored as nil.
    private func optional(_ field: WritableKeyPath<Item, String?>) -> Binding<String> {
        Binding(get: { item[keyPath: field] ?? "" }, set: { item[keyPath: field] = $0.isEmpty ? nil : $0 })
    }

    private func revealButton(show: LocalizedStringKey, hide: LocalizedStringKey) -> some View {
        Button {
            showPassphrase.toggle()
        } label: {
            Image(systemName: showPassphrase ? "eye.slash" : "eye")
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(showPassphrase ? hide : show)
    }

    private var namePrompt: String {
        switch item.kind {
        case .env: ".env.production"
        case .secret: "API_KEY"
        case .password: "GitHub"
        case .sshKey: "id_ed25519_github"
        case .gpgKey: String(localized: "Commit signing")
        case .file: "AuthKey_ABC123.p8"
        case .other: String(localized: "Name")
        }
    }

    private var contentTitle: LocalizedStringKey {
        switch item.kind {
        case .env: ".env Contents"
        case .secret: "Value"
        case .password: "Credentials"
        case .file: "File"
        case .sshKey: "Private Key (OpenSSH)"
        case .gpgKey: "ASCII-Armored Key"
        case .other: "Content"
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
        // Drop fields that belong to another kind (the kind may have been switched mid-edit).
        if result.kind != .password { result.username = nil; result.url = nil }
        if result.kind == .file { result.content = "" } else { result.fileName = nil; result.data = nil }
        if result.kind == .password { result.passphrase = nil }
        onSave(result)
        dismiss()
    }
}
