import AppKit
import OpenVaultCore
import SwiftUI

struct ItemDetailView: View {
    let item: Item
    @Environment(VaultStore.self) private var store
    @State private var revealAll = false
    @State private var ssh: (publicKey: String, fingerprint: String)?
    @State private var gpg: (fingerprint: String, uid: String)?

    var body: some View {
        Form {
            Section {
                header
            }

            switch item.kind {
            case .env:
                envSection
            case .secret:
                Section { SecretRow(label: item.name, value: item.content) }
            case .sshKey:
                Section("Public Key") {
                    if let ssh {
                        SecretRow(label: String(localized: "Public Key"), value: ssh.publicKey, masked: false)
                        LabeledContent("Fingerprint") { Text(ssh.fingerprint).font(.callout.monospaced()).textSelection(.enabled) }
                    } else {
                        Text("Couldn’t read the public key. The passphrase may be wrong or the key may not be in OpenSSH format.")
                            .foregroundStyle(.secondary)
                    }
                }
                Section("Private Key") {
                    SecretRow(label: String(localized: "Private Key"), value: item.content, multiline: true)
                    passphraseRow
                    Button("Export to File…", systemImage: "square.and.arrow.up") { exportSSH() }
                }
            case .gpgKey:
                if let gpg {
                    Section("Identity") {
                        LabeledContent("User ID", value: gpg.uid)
                        LabeledContent("Fingerprint") { Text(gpg.fingerprint).font(.callout.monospaced()).textSelection(.enabled) }
                    }
                }
                Section("Key") {
                    SecretRow(label: String(localized: "Armored Key"), value: item.content, multiline: true)
                    passphraseRow
                }
            case .password:
                Section {
                    if let username = item.username { SecretRow(label: String(localized: "Username"), value: username, masked: false) }
                    SecretRow(label: String(localized: "Password"), value: item.content)
                    if let url = item.url { SecretRow(label: "URL", value: url, masked: false) }
                }
            case .file:
                Section {
                    LabeledContent("File", value: item.fileName ?? item.name)
                    LabeledContent("Size", value: Int64(item.data?.count ?? 0).formatted(.byteCount(style: .file)))
                    passphraseRow
                    Button("Save to Disk…", systemImage: "square.and.arrow.down") { exportFile() }
                }
            case .other:
                Section {
                    SecretRow(label: String(localized: "Contents"), value: item.content, multiline: true)
                    passphraseRow
                }
            }

            if !item.notes.isEmpty {
                Section("Notes") { Text(item.notes).textSelection(.enabled) }
            }

            Section {
                LabeledContent("Created", value: item.createdAt.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("Modified", value: item.updatedAt.formatted(date: .abbreviated, time: .shortened))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .environment(\.revealAll, revealAll)
        .onModifierKeysChanged(mask: .option) { _, keys in
            withAnimation(Motion.standard) { revealAll = keys.contains(.option) }
        }
        .toolbar {
            ToolbarItem {
                Button("Edit", systemImage: "pencil") {
                    store.editorDraft = EditorDraft(item: item, isNew: false)
                }
                .help("Edit")
            }
        }
        .task(id: item.content + (item.passphrase ?? "")) {
            switch item.kind {
            case .sshKey: ssh = await KeyInfo.ssh(privateKey: item.content, passphrase: item.passphrase)
            case .gpgKey: gpg = await KeyInfo.gpg(armored: item.content)
            default: break
            }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: item.kind.symbol)
                .font(.title2)
                .foregroundStyle(item.kind.tint)
                .frame(width: 48, height: 48)
                .background(item.kind.tint.opacity(0.14), in: .rect(cornerRadius: 12))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name).font(.title2.weight(.semibold)).textSelection(.enabled)
                HStack(spacing: 6) {
                    Text(item.kind.singular)
                    if let project = item.project {
                        Text(project)
                            .padding(.horizontal, 7).padding(.vertical, 1)
                            .background(.quaternary, in: .capsule)
                    }
                    if let folder = item.folder {
                        Label(folder, systemImage: "folder")
                            .padding(.horizontal, 7).padding(.vertical, 1)
                            .background(.quaternary, in: .capsule)
                    }
                }
                .font(.callout)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Text("Hold ⌥ to Reveal All")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var envSection: some View {
        let pairs = DotEnv.parse(item.content)
        Section {
            ForEach(Array(pairs.enumerated()), id: \.offset) { _, pair in
                SecretRow(label: pair.key, value: pair.value)
            }
        } header: {
            HStack {
                Text("\(pairs.count) variables")
                Spacer()
                CopyButton(value: item.content, label: String(localized: "Copy .env"))
            }
        }
    }

    @ViewBuilder private var passphraseRow: some View {
        if let passphrase = item.passphrase, !passphrase.isEmpty {
            SecretRow(label: String(localized: "Passphrase"), value: passphrase)
        }
    }

    private func exportFile() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = item.fileName ?? item.name
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        // Remove first: createFile would keep the looser permissions of a file being replaced.
        try? FileManager.default.removeItem(at: url)
        if !FileManager.default.createFile(atPath: url.path, contents: item.data ?? Data(), attributes: [.posixPermissions: 0o600]) {
            store.errorMessage = String(localized: "Couldn’t save “\(url.lastPathComponent)”.")
        }
    }

    private func exportSSH() {
        let panel = NSSavePanel()
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".ssh")
        panel.nameFieldStringValue = item.name.hasPrefix("id_") ? item.name : "id_ed25519"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let key = item.content.trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
        FileManager.default.createFile(atPath: url.path, contents: Data(key.utf8), attributes: [.posixPermissions: 0o600])
        if let pub = ssh?.publicKey {
            try? (pub + "\n").write(toFile: url.path + ".pub", atomically: true, encoding: .utf8)
        }
    }
}

/// A masked value with reveal and copy. Masked unless the eye is toggled or ⌥ is held.
struct SecretRow: View {
    let label: String
    let value: String
    var masked = true
    var multiline = false

    @State private var revealed = false
    @Environment(\.revealAll) private var revealAll

    private var visible: Bool { !masked || revealed || revealAll }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(label).font(.caption).foregroundStyle(.secondary)
                Text(visible ? value : String(repeating: "•", count: min(max(value.count, 8), 24)))
                    .font(.body.monospaced())
                    .lineLimit(visible && multiline ? nil : 1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                    .contentTransition(.opacity)
                    .accessibilityLabel(visible ? value : String(localized: "Hidden"))
            }
            Spacer(minLength: 8)
            if masked {
                Button {
                    withAnimation(Motion.standard) { revealed.toggle() }
                } label: {
                    Image(systemName: visible ? "eye.slash" : "eye")
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.borderless)
                .help(visible ? String(localized: "Hide") : String(localized: "Show"))
                .accessibilityLabel(visible ? String(localized: "Hide \(label)") : String(localized: "Show \(label)"))
            }
            CopyButton(value: value, label: String(localized: "Copy \(label)"))
        }
        .padding(.vertical, 2)
    }
}

struct CopyButton: View {
    let value: String
    let label: String
    @State private var copied = false

    var body: some View {
        Button {
            Clipboard.copy(value)
            copied = true
            AccessibilityNotification.Announcement(String(localized: "Copied")).post()
            Task {
                try? await Task.sleep(for: .seconds(1.5))
                copied = false
            }
        } label: {
            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                .foregroundStyle(copied ? AnyShapeStyle(.green) : AnyShapeStyle(.tint))
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.borderless)
        .help(copied ? String(localized: "Copied — it will be cleared from the clipboard") : label)
        .accessibilityLabel(label)
    }
}
