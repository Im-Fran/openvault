import SwiftUI

struct SettingsView: View {
    @Environment(VaultStore.self) private var store
    @AppStorage("autoLockMinutes") private var autoLockMinutes = 5
    @AppStorage("clipboardSeconds") private var clipboardSeconds = 30
    @State private var touchID = true
    @State private var changingPassword = false

    private let installCommand = "make install-cli"

    var body: some View {
        Form {
            Section("Seguridad") {
                Picker("Bloquear tras inactividad", selection: $autoLockMinutes) {
                    Text("1 minuto").tag(1)
                    Text("5 minutos").tag(5)
                    Text("15 minutos").tag(15)
                    Text("1 hora").tag(60)
                    Text("Nunca").tag(0)
                }
                Picker("Limpiar portapapeles tras", selection: $clipboardSeconds) {
                    ForEach([15, 30, 60, 90], id: \.self) { Text("\($0) segundos").tag($0) }
                }
                if Biometrics.isAvailable {
                    Toggle("Desbloquear con Touch ID", isOn: $touchID)
                        .disabled(store.state != .unlocked)
                        .onChange(of: touchID) { _, on in store.setTouchID(on) }
                }
                Button("Cambiar contraseña maestra…") { changingPassword = true }
                    .disabled(store.state != .unlocked)
            }

            Section {
                LabeledContent("Vault") {
                    Text(store.file.url.path(percentEncoded: false))
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                LabeledContent("Instalar") {
                    HStack {
                        Text(installCommand).font(.callout.monospaced())
                        CopyButton(value: installCommand, label: "Copiar comando")
                    }
                }
            } header: {
                Text("CLI")
            } footer: {
                Text("Desde la carpeta del repositorio de OpenVault. Luego, en tu proyecto: `ovault init` y `ovault run -- <comando>`.")
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
            Text("Cambiar contraseña maestra").font(.headline)
            SecureField("Contraseña actual", text: $current)
            SecureField("Nueva contraseña (mín. 8)", text: $new)
            SecureField("Confirmar nueva contraseña", text: $confirmation)
            if let error { Text(error).font(.caption).foregroundStyle(.red) }
            HStack {
                Spacer()
                Button("Cancelar", role: .cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Cambiar") { change() }
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
