import CommonCrypto
import CryptoKit
import Foundation

public enum VaultError: LocalizedError, Equatable {
    case wrongPassword
    case notFound
    case corrupted
    case keyDerivationFailed

    public var errorDescription: String? {
        switch self {
        case .wrongPassword: "Contraseña maestra incorrecta."
        case .notFound: "No existe un vault. Créalo desde la app OpenVault."
        case .corrupted: "El archivo del vault está dañado."
        case .keyDerivationFailed: "No se pudo derivar la clave."
        }
    }
}

/// On-disk envelope: everything except the KDF parameters is encrypted.
struct Envelope: Codable {
    var v = 1
    var salt: Data
    var iterations: Int
    var box: Data // AES-GCM combined: nonce + ciphertext + tag
}

public struct VaultKey: Sendable {
    public let raw: SymmetricKey
    let salt: Data
    let iterations: Int

    public static let defaultIterations = 600_000

    /// Derives a key with PBKDF2-HMAC-SHA256.
    public static func derive(password: String, salt: Data, iterations: Int = defaultIterations) throws -> VaultKey {
        var derived = [UInt8](repeating: 0, count: 32)
        let pw = Array(password.utf8)
        let status = salt.withUnsafeBytes { saltBytes in
            pw.withUnsafeBufferPointer { pwBytes in
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    pwBytes.baseAddress.map { UnsafeRawPointer($0).assumingMemoryBound(to: CChar.self) }, pw.count,
                    saltBytes.bindMemory(to: UInt8.self).baseAddress, salt.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), UInt32(iterations),
                    &derived, derived.count)
            }
        }
        guard status == kCCSuccess else { throw VaultError.keyDerivationFailed }
        return VaultKey(raw: SymmetricKey(data: derived), salt: salt, iterations: iterations)
    }

    /// Fresh key with a random salt (new vault or password change).
    public static func new(password: String, iterations: Int = defaultIterations) throws -> VaultKey {
        try derive(password: password, salt: Data(SymmetricKey(size: .init(bitCount: 128)).withUnsafeBytes { Data($0) }),
                   iterations: iterations)
    }

    /// Rebuilds a key from raw bytes stored in the Keychain plus the file's KDF params.
    public init(raw: SymmetricKey, salt: Data, iterations: Int) {
        self.raw = raw
        self.salt = salt
        self.iterations = iterations
    }

    public var rawData: Data { raw.withUnsafeBytes { Data($0) } }
}

enum VaultCrypto {
    static func seal(_ vault: Vault, key: VaultKey) throws -> Data {
        let plain = try JSONEncoder.vault.encode(vault)
        let box = try AES.GCM.seal(plain, using: key.raw).combined!
        return try JSONEncoder.vault.encode(Envelope(salt: key.salt, iterations: key.iterations, box: box))
    }

    static func envelope(_ data: Data) throws -> Envelope {
        do { return try JSONDecoder.vault.decode(Envelope.self, from: data) } catch { throw VaultError.corrupted }
    }

    static func open(_ data: Data, key: VaultKey) throws -> Vault {
        let env = try envelope(data)
        guard env.salt == key.salt else { throw VaultError.wrongPassword }
        let plain: Data
        do { plain = try AES.GCM.open(AES.GCM.SealedBox(combined: env.box), using: key.raw) } catch {
            throw VaultError.wrongPassword
        }
        do { return try JSONDecoder.vault.decode(Vault.self, from: plain) } catch { throw VaultError.corrupted }
    }
}

extension JSONEncoder {
    static var vault: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = .sortedKeys
        return e
    }
}

extension JSONDecoder {
    static var vault: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}
