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

    static func store(_ key: Data) -> Bool {
        delete()
        guard let access = SecAccessControlCreateWithFlags(
            nil, kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly, .biometryCurrentSet, nil) else { return false }
        var query = base
        query[kSecValueData as String] = key
        query[kSecAttrAccessControl as String] = access
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    static func load(reason: String) async -> Data? {
        await Task.detached {
            let context = LAContext()
            context.localizedReason = reason
            var query = base
            query[kSecReturnData as String] = true
            query[kSecUseAuthenticationContext as String] = context
            var result: CFTypeRef?
            guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
            return result as? Data
        }.value
    }

    static func delete() {
        SecItemDelete(base as CFDictionary)
    }
}
