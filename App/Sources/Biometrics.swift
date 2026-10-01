import Foundation
import LocalAuthentication
import Security

/// Keeps the derived vault key in the data-protection Keychain, readable only after Touch ID.
/// Requires the app to be signed with a Team; without it `store` just returns false and Touch ID stays hidden.
nonisolated enum Biometrics {
    private static var base: [String: Any] { [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "cl.franciscosolis.openvault.masterkey",
        kSecAttrAccount as String: "vault",
        kSecUseDataProtectionKeychain as String: true,
    ] }

    static var isAvailable: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    /// True when an item exists, checked without prompting.
    static var isEnrolled: Bool {
        let context = LAContext()
        context.interactionNotAllowed = true
        var query = base
        query[kSecUseAuthenticationContext as String] = context
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess || status == errSecInteractionNotAllowed
    }

    private static var accessControl: SecAccessControl? {
        SecAccessControlCreateWithFlags(nil, kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly, .biometryCurrentSet, nil)
    }

    static func store(_ key: Data) -> Bool {
        delete()
        guard let access = accessControl else { return false }
        var query = base
        query[kSecValueData as String] = key
        query[kSecAttrAccessControl as String] = access
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    /// Authenticates first, then reads with the same context so the Keychain doesn't prompt again.
    /// A context attached to an `LAAuthenticationView` authenticates inline instead of in a system dialog.
    @MainActor static func load(reason: String, context: LAContext = LAContext()) async -> Data? {
        guard let access = accessControl,
              (try? await context.evaluateAccessControl(access, operation: .useItem, localizedReason: reason)) == true
        else { return nil }
        context.interactionNotAllowed = true
        var query = base
        query[kSecReturnData as String] = true
        query[kSecUseAuthenticationContext as String] = context
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    static func delete() {
        SecItemDelete(base as CFDictionary)
    }
}
