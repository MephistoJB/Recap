import Foundation
import Security

public enum Keychain {
    private static let service = "org.owl.local.mac"
    public static func read(_ account: String) throws -> String? {
        var result: CFTypeRef?
        let status = SecItemCopyMatching([kSecClass: kSecClassGenericPassword, kSecAttrService: service,
            kSecAttrAccount: account, kSecReturnData: true, kSecMatchLimit: kSecMatchLimitOne] as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw OwlError.invalid("Schlüsselbund ist nicht verfügbar (\(status)).")
        }
        return String(data: data, encoding: .utf8)
    }
    public static func write(_ value: String, account: String) throws {
        let query: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecAttrAccount: account]
        let data = Data(value.utf8)
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData: data] as CFDictionary)
        if status == errSecItemNotFound {
            var item = query; item[kSecValueData] = data; item[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let added = SecItemAdd(item as CFDictionary, nil)
            guard added == errSecSuccess else { throw OwlError.invalid("Token konnte nicht im Schlüsselbund gespeichert werden (\(added)).") }
        } else if status != errSecSuccess { throw OwlError.invalid("Token konnte nicht gespeichert werden (\(status)).") }
    }
    public static func makeToken() throws -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else { throw OwlError.invalid("Token konnte nicht erzeugt werden.") }
        return bytes.map { String(format: "%02x", $0) }.joined()
    }
}
