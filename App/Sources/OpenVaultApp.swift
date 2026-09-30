import OpenVaultCore
import SwiftUI

@main
struct OpenVaultApp: App {
    @State private var store = VaultStore()
    @AppStorage("menuBarIcon") private var menuBarIcon = false

    var body: some Scene {
        WindowGroup(id: MainWindow.id) {
            RootView()
                .environment(store)
                .frame(minWidth: 860, minHeight: 540)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Nuevo item") {
                    store.editorDraft = EditorDraft(item: Item(name: "", kind: .secret, content: ""), isNew: true)
                }
                .keyboardShortcut("n")
                .disabled(store.state != .unlocked)
            }
            CommandMenu("Vault") {
                Button("Bloquear") { store.lock() }
                    .keyboardShortcut("l")
                    .disabled(store.state != .unlocked)
            }
        }

        Settings {
            SettingsView().environment(store)
        }

        // Template SF Symbol: adapts to the menu bar and shows the lock state at a glance.
        MenuBarExtra("OpenVault", systemImage: store.state == .unlocked ? "lock.open" : "lock", isInserted: $menuBarIcon) {
            MenuBarView().environment(store)
        }
        .menuBarExtraStyle(.window)
    }
}

private struct RootView: View {
    @Environment(VaultStore.self) private var store

    var body: some View {
        ZStack {
            if store.state == .unlocked {
                ContentView()
                    .transition(.opacity)
            } else {
                LockView()
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .animation(Motion.standard, value: store.state)
        .alert("No se pudo completar la acción",
               isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
            Button("OK") { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }
}
