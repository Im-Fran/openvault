import LocalAuthentication
import OpenVaultCore
import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

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

    private(set) var file: VaultFile
    /// Where the vault goes in iCloud Drive; nil while iCloud is unavailable (signed out, or not resolved yet).
    private(set) var iCloudURL: URL?
    private(set) var iCloudSync = VaultFile.settings.bool(forKey: "iCloudSync")
    private var key: VaultKey?
    private var watcher: DispatchSourceFileSystemObject?
    private var lastActivity = Date()
    private var observers: [Any] = []
    private var query: NSMetadataQuery?
    private var iCloudHasVault = false

    init() {
        let file = VaultFile()
        self.file = file
        state = file.exists ? .locked : .setup
        observeActivityAndLockTriggers()
        Task { await connectICloud() }
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

    func unlockWithBiometrics(context: LAContext = LAContext()) async {
        guard let raw = await Biometrics.load(reason: String(localized: "unlock OpenVault"), context: context) else {
            biometricsEnrolled = Biometrics.isEnrolled // the key may have been invalidated (new fingerprint)
            return
        }
        do {
            let key = try file.key(fromRaw: raw)
            didUnlock(vault: try file.load(key: key), key: key)
        } catch VaultError.wrongPassword {
            // The master password was changed (maybe on another device): the stored key is stale.
            Biometrics.delete()
            biometricsEnrolled = false
        } catch {
            errorMessage = error.localizedDescription
        }
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

    // MARK: - iCloud

    enum ICloudError: LocalizedError {
        case unavailable, notDownloaded, needsPassword

        var errorDescription: String? {
            switch self {
            case .unavailable: String(localized: "iCloud isn’t available. Sign in to iCloud and turn on iCloud Drive.")
            case .notDownloaded: String(localized: "The iCloud vault is still downloading. Try again in a moment.")
            case .needsPassword: String(localized: "Enter the master password of the vault in iCloud.")
            }
        }
    }

    /// On: copies this vault to iCloud, or merges it into the vault another device already put there
    /// (which may have another master password: pass it as `iCloudPassword`, `.needsPassword` asks for it).
    /// Off: copies the vault back to this device; iCloud keeps its copy for the other devices.
    func setICloudSync(_ on: Bool, iCloudPassword: String? = nil) async throws {
        guard let key, on != iCloudSync else { return }
        let target: VaultFile
        if on {
            guard let iCloudURL else { throw ICloudError.unavailable }
            target = VaultFile(url: iCloudURL)
            if iCloudHasVault || target.exists {
                guard target.exists else {
                    try? FileManager.default.startDownloadingUbiquitousItem(at: iCloudURL)
                    throw ICloudError.notDownloaded
                }
                var cloudKey = key
                do {
                    _ = try target.load(key: key)
                } catch VaultError.wrongPassword {
                    guard let iCloudPassword else { throw ICloudError.needsPassword }
                    cloudKey = try await Task.detached { try target.unlock(password: iCloudPassword).1 }.value
                }
                let mine = vault
                vault = try target.update(key: cloudKey) { $0 = $0.merged(with: mine) }
                if cloudKey.rawData != key.rawData {
                    self.key = cloudKey
                    if biometricsEnrolled { biometricsEnrolled = Biometrics.store(cloudKey.rawData) }
                }
            } else {
                try target.save(vault, key: key)
            }
        } else {
            target = VaultFile(url: VaultFile.localURL)
            try target.save(vault, key: key)
        }
        iCloudSync = on
        VaultFile.settings.set(on, forKey: "iCloudSync")
        use(target)
    }

    private func use(_ newFile: VaultFile) {
        file = newFile
        if state == .unlocked { watchFile() }
    }

    private func connectICloud() async {
        guard ProcessInfo.processInfo.environment["OPENVAULT_FILE"] == nil else { return } // pinned to a file
        // Can block the first time (it sets the container up), so off the main thread.
        guard let container = await Task.detached(operation: { FileManager.default.url(forUbiquityContainerIdentifier: nil) }).value
        else { return }
        let url = container.appending(path: "Documents/\(VaultFile.fileName)")
        iCloudURL = url
        VaultFile.settings.set(url.path, forKey: "iCloudVaultPath") // the CLI follows it
        if iCloudSync, file.url != url { use(VaultFile(url: url)) }

        // Downloads the vault when another device changes it, and finds the one in iCloud on a new device.
        let query = NSMetadataQuery()
        query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        query.predicate = NSPredicate(format: "%K == %@", NSMetadataItemFSNameKey, VaultFile.fileName)
        for name in [Notification.Name.NSMetadataQueryDidFinishGathering, .NSMetadataQueryDidUpdate] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: query, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.iCloudChanged() }
            })
        }
        query.start()
        self.query = query
    }

    private func iCloudChanged() {
        guard let query, let iCloudURL else { return }
        query.disableUpdates()
        defer { query.enableUpdates() }
        guard let item = query.results.first as? NSMetadataItem else { return }
        iCloudHasVault = true
        if item.value(forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey) as? String != NSMetadataUbiquitousItemDownloadingStatusCurrent {
            try? FileManager.default.startDownloadingUbiquitousItem(at: iCloudURL)
        }
        switch state {
        case .setup:
            // A new device: no vault here, but there's one in iCloud. Use it.
            iCloudSync = true
            VaultFile.settings.set(true, forKey: "iCloudSync")
            use(VaultFile(url: iCloudURL))
            if file.exists { state = .locked }
        case .unlocked where iCloudSync:
            if item.value(forAttribute: NSMetadataUbiquitousItemHasUnresolvedConflictsKey) as? Bool == true, let key {
                do {
                    if let merged = try file.resolveConflicts(key: key) { vault = merged }
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
            reload()
        default:
            break
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
        source.setEventHandler { [weak self] in self?.reload() }
        source.setCancelHandler { close(fd) }
        source.resume()
        watcher?.cancel()
        watcher = source
    }

    private func reload() {
        guard state == .unlocked, let key else { return }
        do {
            let fresh = try file.load(key: key)
            guard fresh != vault else { return }
            withAnimation(Motion.standard) { vault = fresh }
        } catch VaultError.wrongPassword {
            lock() // the master password was changed elsewhere: unlock with the new one
        } catch {
            // Mid-download or briefly missing: the next change event reloads it.
        }
    }

    #if os(macOS)
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
    #else
    private var backgroundedAt: Date? = nil

    private func observeActivityAndLockTriggers() {
        // Locking the iPhone locks the vault.
        observers.append(NotificationCenter.default.addObserver(
            forName: UIApplication.protectedDataWillBecomeUnavailableNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.lock() }
        })
    }

    /// iOS has no idle timer to hook into: "inactivity" is the time spent in the background.
    /// ponytail: a vault left open in the foreground stays open until the device locks.
    func scenePhaseChanged(_ phase: ScenePhase) {
        switch phase {
        case .background:
            backgroundedAt = backgroundedAt ?? Date()
        case .active:
            defer { backgroundedAt = nil }
            let minutes = UserDefaults.standard.object(forKey: "autoLockMinutes") as? Int ?? 5
            if minutes > 0, let since = backgroundedAt, Date().timeIntervalSince(since) > Double(minutes * 60) { lock() }
        default:
            break
        }
    }
    #endif
}
