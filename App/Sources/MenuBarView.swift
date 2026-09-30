import AppKit
import OpenVaultCore
import SwiftUI

enum MainWindow {
    static let id = "main"

    /// Brings the main window forward, opening it if it was closed.
    static func show(_ openWindow: OpenWindowAction) {
        // ponytail: SwiftUI names WindowGroup windows "<id>-AppWindow-N"; reuse it instead of stacking a second one.
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue.hasPrefix(id) == true }) {
            window.deminiaturize(nil)
            window.makeKeyAndOrderFront(nil)
        } else {
            openWindow(id: id)
        }
        NSApp.activate()
    }
}

/// The menu bar window: search, pick an item, reveal or copy. Never shows data while locked.
struct MenuBarView: View {
    @Environment(VaultStore.self) private var store
    @Environment(\.openWindow) private var openWindow
    @State private var search = ""
    @State private var highlighted: Item.ID?
    @State private var opened: Item.ID?
    @FocusState private var searchFocused: Bool

    private var results: [Item] { store.vault.items.searched(search) }

    var body: some View {
        VStack(spacing: 0) {
            if store.state != .unlocked {
                MenuBarLockView()
            } else if let item = store.vault.items.first(where: { $0.id == opened }) {
                detail(item)
            } else {
                list
            }
            Divider()
            footer
        }
        .frame(width: 360, height: 460)
        // Closing the window forgets the query and any revealed value.
        .onDisappear {
            search = ""
            opened = nil
            highlighted = nil
        }
    }

    private var list: some View {
        VStack(spacing: 0) {
            TextField("Buscar", text: $search)
                .textFieldStyle(.roundedBorder)
                .controlSize(.large)
                .focused($searchFocused)
                .onSubmit { opened = highlighted ?? results.first?.id }
                .onKeyPress(.downArrow) { moveHighlight(1) }
                .onKeyPress(.upArrow) { moveHighlight(-1) }
                .accessibilityLabel("Buscar credenciales y secretos")
                .padding(10)

            List(results, selection: $highlighted) { item in
                Button { opened = item.id } label: {
                    ItemRow(item: item)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Muestra el detalle")
            }
            .overlay {
                if results.isEmpty {
                    if search.isEmpty {
                        ContentUnavailableView("Sin items", systemImage: "tray",
                                               description: Text("Crea uno desde la ventana principal."))
                    } else {
                        ContentUnavailableView.search(text: search)
                    }
                }
            }
        }
        .onAppear { searchFocused = true }
        .onChange(of: search) { highlighted = results.first?.id }
    }

    private func detail(_ item: Item) -> some View {
        VStack(spacing: 0) {
            HStack {
                Button("Volver", systemImage: "chevron.left") { opened = nil }
                    .buttonStyle(.borderless)
                    .keyboardShortcut(.cancelAction)
                    .help("Volver (esc)")
                Spacer()
            }
            .padding(10)
            ItemDetailView(item: item)
                .id(item.id)
        }
    }

    private var footer: some View {
        HStack {
            Button("Abrir OpenVault", systemImage: "macwindow") { MainWindow.show(openWindow) }
                .keyboardShortcut("o")
                .help("Abrir OpenVault (⌘O)")
            Spacer()
            if store.state == .unlocked {
                Button("Bloquear", systemImage: "lock") { store.lock() }
                    .labelStyle(.iconOnly)
                    .keyboardShortcut("l")
                    .help("Bloquear (⌘L)")
            }
            Button("Salir", systemImage: "power") { NSApp.terminate(nil) }
                .labelStyle(.iconOnly)
                .keyboardShortcut("q")
                .help("Salir de OpenVault (⌘Q)")
        }
        .buttonStyle(.borderless)
        .padding(10)
    }

    private func moveHighlight(_ delta: Int) -> KeyPress.Result {
        let ids = results.map(\.id)
        guard !ids.isEmpty else { return .ignored }
        let current = ids.firstIndex { $0 == highlighted } ?? (delta > 0 ? -1 : ids.count)
        highlighted = ids[min(max(current + delta, 0), ids.count - 1)]
        return .handled
    }
}

/// Compact unlock. Setup (choosing a master password) stays in the main window.
private struct MenuBarLockView: View {
    @Environment(VaultStore.self) private var store
    @Environment(\.openWindow) private var openWindow
    @State private var password = ""
    @State private var showError = false
    @State private var working = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "lock.fill")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            if store.state == .setup {
                Text("Aún no tienes un vault").font(.headline)
                Button("Crear vault…") { MainWindow.show(openWindow) }
                    .buttonStyle(.borderedProminent)
            } else {
                Text("OpenVault está bloqueado").font(.headline)
                SecureField("Contraseña maestra", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .focused($focused)
                    .onSubmit(submit)
                if showError {
                    Text("Contraseña incorrecta").font(.callout).foregroundStyle(.red)
                }
                HStack(spacing: 10) {
                    if store.biometricsEnrolled {
                        Button {
                            Task { await store.unlockWithBiometrics() }
                        } label: {
                            Image(systemName: "touchid")
                        }
                        .help("Desbloquear con Touch ID")
                        .accessibilityLabel("Desbloquear con Touch ID")
                    }
                    Button(action: submit) {
                        Text("Desbloquear").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(password.isEmpty || working)
                }
            }
        }
        .controlSize(.large)
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { focused = true }
        .onDisappear { password = "" }
        .onChange(of: password) { if !password.isEmpty { showError = false } }
    }

    private func submit() {
        guard !password.isEmpty, !working else { return }
        working = true
        Task {
            defer { working = false }
            if await !store.unlock(password: password) {
                // ponytail: non-password errors land in store.errorMessage, shown by the main window's alert.
                showError = store.errorMessage == nil
                if showError { AccessibilityNotification.Announcement("Contraseña incorrecta").post() }
                password = ""
                focused = true
            }
        }
    }
}
