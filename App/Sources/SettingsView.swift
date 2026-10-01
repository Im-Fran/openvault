import SwiftUI

struct SettingsView: View {
    @Environment(VaultStore.self) private var store
    @AppStorage("autoLockMinutes") private var autoLockMinutes = 5
    @AppStorage("clipboardSeconds") private var clipboardSeconds = 30
    @AppStorage("menuBarIcon") private var menuBarIcon = false
    @State private var touchID = true
    @State private var changingPassword = false

    private let installCommand = "make install-cli"

    var body: some View {
        Form {
            Section("Security") {
                Picker("Lock After Inactivity", selection: $autoLockMinutes) {
                    Text("1 minute").tag(1)
                    Text("5 minutes").tag(5)
                    Text("15 minutes").tag(15)
                    Text("1 hour").tag(60)
                    Text("Never").tag(0)
                }
                Picker("Clear Clipboard After", selection: $clipboardSeconds) {
                    ForEach([15, 30, 60, 90], id: \.self) { Text("\($0) seconds").tag($0) }
                }
                if Biometrics.isAvailable {
                    Toggle("Unlock with Touch ID", isOn: $touchID)
                        .disabled(store.state != .unlocked)
                        .onChange(of: touchID) { _, on in store.setTouchID(on) }
                }
                Button("Change Master Password…") { changingPassword = true }
                    .disabled(store.state != .unlocked)
            }

            Section {
                Toggle("Show in Menu Bar", isOn: $menuBarIcon)
            } header: {
                Text("Menu Bar")
            } footer: {
                Text("Search and copy your secrets from the menu bar icon. When you close the window, OpenVault leaves the Dock and stays available from that icon.")
            }

            Section {
                LabeledContent("Vault") {
                    Text(store.file.url.path(percentEncoded: false))
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                LabeledContent("Install") {
                    HStack {
                        Text(installCommand).font(.callout.monospaced())
                        CopyButton(value: installCommand, label: String(localized: "Copy Command"))
                    }
                }
            } header: {
                Text("CLI")
            } footer: {
                Text("Run from the OpenVault repository folder. Then, in your project: `ovault init` and `ovault run -- <command>`.")
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear { touchID = store.touchIDEnabled }
        .sheet(isPresented: $changingPassword) { ChangePasswordView() }
    }
}

private struct ChangePasswordView: View {
    @Environment(VaultStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var current = ""
    @State private var new = ""
    @State private var confirmation = ""
    @State private var error: String?
    @State private var working = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Change Master Password").font(.headline)
            SecureField("Current Password", text: $current)
            SecureField("New Password (min. 8 characters)", text: $new)
            SecureField("Confirm New Password", text: $confirmation)
            if let error { Text(error).font(.caption).foregroundStyle(.red) }
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Change") { change() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(working || current.isEmpty || new.count < 8 || new != confirmation)
            }
        }
        .textFieldStyle(.roundedBorder)
        .padding(20)
        .frame(width: 360)
    }

    private func change() {
        working = true
        Task {
            defer { working = false }
            do {
                try await store.changePassword(current: current, new: new)
                dismiss()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}
