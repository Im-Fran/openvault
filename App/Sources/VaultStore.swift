import AppKit
import OpenVaultCore
import SwiftUI

struct EditorDraft: Identifiable {
    let id = UUID()
    var item: Item
    var isNew: Bool
}

@Observable
final class VaultStore {
    enum State { case setup, locked, unlocked }

    private(set) var state: State
    private(set) var vault = Vault()
    private(set) var biometricsEnrolled = Biometrics.isEnrolled
    var editorDraft: EditorDraft?
    var errorMessage: String?

    let file = VaultFile()
    private var key: VaultKey?
    private var watcher: DispatchSourceFileSystemObject?
    private var lastActivity = Date()
    private var observers: [Any] = []

    init() {
        state = file.exists ? .locked : .setup
        observeActivityAndLockTriggers()
    }

    // MARK: - Lock / unlock

    func create(password: String) async throws {
        let file = file
        let key = try await Task.detached { try file.create(password: password) }.value
        didUnlock(vault: Vault(), key: key)
    }

    /// Returns false on a wrong password so the UI can shake.
    func unlock(password: String) async -> Bool {
        let file = file
        do {
            let (vault, key) = try await Task.detached { try file.unlock(password: password) }.value
            didUnlock(vault: vault, key: key)
            return true
        } catch VaultError.wrongPassword {
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func unlockWithBiometrics() async {
        guard let raw = await Biometrics.load(reason: "desbloquear OpenVault"),
              let key = try? file.key(fromRaw: raw),
              let vault = try? file.load(key: key)
        else {
            biometricsEnrolled = Biometrics.isEnrolled // the key may have been invalidated (new fingerprint)
            return
        }
        didUnlock(vault: vault, key: key)
    }

    func lock() {
        guard state == .unlocked else { return }
        key = nil
        vault = Vault()
        editorDraft = nil
        watcher?.cancel()
        watcher = nil
        state = .locked
    }

    private func didUnlock(vault: Vault, key: VaultKey) {
        self.vault = vault
        self.key = key
        lastActivity = Date()
        if touchIDEnabled, Biometrics.isAvailable, !Biometrics.isEnrolled {
            biometricsEnrolled = Biometrics.store(key.rawData)
        }
        state = .unlocked
        watchFile()
    }

    // MARK: - Mutations (always read-modify-write, the CLI may have written meanwhile)

    func save(_ item: Item) {
        var item = item
        item.updatedAt = Date()
        mutate { vault in
            if let i = vault.items.firstIndex(where: { $0.id == item.id }) {
                vault.items[i] = item
            } else {
                vault.items.append(item)
            }
        }
    }

    func delete(_ item: Item) {
        mutate { $0.items.removeAll { $0.id == item.id } }
    }

    func changePassword(current: String, new: String) async throws {
        let file = file
        let (_, currentKey) = try await Task.detached { try file.unlock(password: current) }.value
        let newKey = try await Task.detached { try file.changePassword(key: currentKey, to: new) }.value
        key = newKey
        Biometrics.delete()
        biometricsEnrolled = touchIDEnabled && Biometrics.store(newKey.rawData)
    }

    func setTouchID(_ enabled: Bool) {
        touchIDEnabled = enabled
        if enabled, let key {
            biometricsEnrolled = Biometrics.store(key.rawData)
        } else {
            Biometrics.delete()
            biometricsEnrolled = false
        }
    }

    private func mutate(_ body: (inout Vault) -> Void) {
        guard let key else { return }
        do {
            vault = try file.update(key: key, body)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Settings

    var touchIDEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "touchID") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "touchID") }
    }

    // MARK: - External changes & auto-lock

    /// Watches the vault's folder: atomic writes replace the file, so watching the file itself would go stale.
    private func watchFile() {
        let dir = file.url.deletingLastPathComponent().path
        let fd = open(dir, O_EVTONLY)
        guard fd >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: .write, queue: .main)
        source.setEventHandler { [weak self] in
            guard let self, let key = self.key, let fresh = try? self.file.load(key: key), fresh != self.vault else { return }
            withAnimation(.spring(duration: 0.35, bounce: 0)) { self.vault = fresh }
        }
        source.setCancelHandler { close(fd) }
        source.resume()
        watcher = source
    }

    private func observeActivityAndLockTriggers() {
        NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseDown, .scrollWheel]) { [weak self] event in
            self?.lastActivity = Date()
            return event
        }
        let ws = NSWorkspace.shared.notificationCenter
        observers.append(ws.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.lock() }
        })
        observers.append(DistributedNotificationCenter.default().addObserver(
            forName: .init("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.lock() }
        })
        Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.state == .unlocked else { return }
                let minutes = UserDefaults.standard.object(forKey: "autoLockMinutes") as? Int ?? 5
                if minutes > 0, Date().timeIntervalSince(self.lastActivity) > Double(minutes * 60) { self.lock() }
            }
        }
    }
}
