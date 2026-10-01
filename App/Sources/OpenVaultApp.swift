import AppKit
import OpenVaultCore
import SwiftUI

@main
struct OpenVaultApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
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
                Button("New Item") {
                    store.editorDraft = EditorDraft(item: Item(name: "", kind: .secret, content: ""), isNew: true)
                }
                .keyboardShortcut("n")
                .disabled(store.state != .unlocked)
            }
            CommandMenu("Vault") {
                Button("Lock") { store.lock() }
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
        .alert("The Action Couldn’t Be Completed",
               isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
            Button("OK") { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }
}

/// Background mode: with the menu bar icon on, closing the last window hides the app from the
/// Dock and ⌘Tab; it stays reachable from the menu bar. Any regular window brings the Dock back.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(windowWillClose), name: NSWindow.willCloseNotification, object: nil)
        center.addObserver(self, selector: #selector(windowDidBecomeKey), name: NSWindow.didBecomeKeyNotification, object: nil)
    }

    /// Dock/Finder/Launchpad click while hidden: SwiftUI reopens the main window (we return true).
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        Self.showInDock()
        return true
    }

    static func showInDock() {
        guard NSApp.activationPolicy() != .regular else { return }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
    }

    /// Main and Settings windows count; the menu bar window, panels and sheets don't.
    private static func isRegular(_ window: NSWindow) -> Bool {
        window.level == .normal && window.styleMask.contains(.titled) && !(window is NSPanel) && !window.isSheet
    }

    @objc private func windowWillClose(_ note: Notification) {
        guard let closing = note.object as? NSWindow, Self.isRegular(closing),
              UserDefaults.standard.bool(forKey: "menuBarIcon") else { return }
        // Minimized windows live in the Dock, so they keep it.
        let others = NSApp.windows.contains { $0 !== closing && Self.isRegular($0) && ($0.isVisible || $0.isMiniaturized) }
        if !others { NSApp.setActivationPolicy(.accessory) }
    }

    @objc private func windowDidBecomeKey(_ note: Notification) {
        if let window = note.object as? NSWindow, Self.isRegular(window) { Self.showInDock() }
    }
}
