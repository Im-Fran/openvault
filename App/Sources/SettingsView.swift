import OpenVaultCore
import SwiftUI

struct SettingsView: View {
    @Environment(VaultStore.self) private var store
    @AppStorage("autoLockMinutes") private var autoLockMinutes = 5
    @AppStorage("clipboardSeconds") private var clipboardSeconds = 30
    @AppStorage("menuBarIcon") private var menuBarIcon = false
    @State private var touchID = true
    @State private var changingPassword = false
    @State private var cliInstalled = CLIInstaller.isInstalled
    @State private var cliError: String?
    @State private var confirmReplace = false

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
                LabeledContent("Command-Line Tool") {
                    if cliInstalled {
                        Label {
                            Text("Installed")
                        } icon: {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        }
                    } else {
                        Button("Install…") {
                            if CLIInstaller.hasConflict { confirmReplace = true } else { installCLI() }
                        }
                    }
                }
                if let cliError {
                    Label {
                        Text(cliError)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
                    }
                    .font(.callout)
                }
            } header: {
                Text("CLI")
            } footer: {
                Text("Links `ovault` into \(CLIInstaller.linkPath), asking for an administrator password if needed. It updates with the app. Then, in your project: `ovault init` and `ovault run -- <command>`.")
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            touchID = store.touchIDEnabled
            cliInstalled = CLIInstaller.isInstalled
        }
        .sheet(isPresented: $changingPassword) { ChangePasswordView() }
        .confirmationDialog("Replace the Existing “ovault”?", isPresented: $confirmReplace) {
            Button("Replace", role: .destructive) { installCLI() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\(CLIInstaller.linkPath) already exists and isn’t OpenVault’s. Replacing it removes it.")
        }
    }

    private func installCLI() {
        do {
            try CLIInstaller.install()
            cliError = nil
        } catch {
            cliError = error.localizedDescription
            AccessibilityNotification.Announcement(error.localizedDescription).post()
        }
        cliInstalled = CLIInstaller.isInstalled
    }
}

/// Links /usr/local/bin/ovault to the CLI inside the app bundle, so app updates update it too.
enum CLIInstaller {
    static let linkPath = "/usr/local/bin/ovault"
    static var bundled: URL? { Bundle.main.url(forAuxiliaryExecutable: "ovault") }

    static var isInstalled: Bool {
        guard let bundled else { return false }
        let target = try? FileManager.default.destinationOfSymbolicLink(atPath: linkPath)
        return target == bundled.path
    }

    /// Something else is already at `linkPath` (e.g. a Homebrew or hand-built ovault): installing would remove it.
    static var hasConflict: Bool {
        (try? FileManager.default.attributesOfItem(atPath: linkPath)) != nil && !isInstalled
    }

    static func install() throws {
        guard let bundled else { throw CLIError(String(localized: "This build of OpenVault doesn’t include the CLI.")) }
        // A link into a disk image or a translocated copy breaks as soon as it's ejected or the app moves.
        if bundled.path.hasPrefix("/Volumes/") || bundled.path.contains("/AppTranslocation/") {
            throw CLIError(String(localized: "Move OpenVault to the Applications folder first, then open it from there."))
        }
        let fm = FileManager.default
        do {
            try fm.createDirectory(atPath: (linkPath as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
            if (try? fm.destinationOfSymbolicLink(atPath: linkPath)) != nil || fm.fileExists(atPath: linkPath) {
                try fm.removeItem(atPath: linkPath)
            }
            try fm.createSymbolicLink(atPath: linkPath, withDestinationPath: bundled.path)
        } catch {
            // /usr/local/bin is usually root's: ask for an administrator password.
            let command = "mkdir -p /usr/local/bin && ln -sfn \(Shell.quote(bundled.path)) \(linkPath)"
            let literal = command.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
            var info: NSDictionary?
            NSAppleScript(source: "do shell script \"\(literal)\" with administrator privileges")?.executeAndReturnError(&info)
            if let info, info[NSAppleScript.errorNumber] as? Int != -128 { // -128: the user cancelled
                throw CLIError(String(localized: "Couldn’t link the CLI into \(linkPath). In Terminal, run: sudo ln -sfn \(Shell.quote(bundled.path)) \(linkPath)"))
            }
        }
    }

    struct CLIError: LocalizedError {
        let errorDescription: String?
        init(_ message: String) { errorDescription = message }
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
