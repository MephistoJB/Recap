import Foundation
import Security
import Combine

enum ConnectionSettings {
    static let changed = Notification.Name("recap.connectionChanged")
    static let addressKey = "recap.serverAddress"
    private static let service = "org.bechara.recap.connection"
    static var address: String { UserDefaults.standard.string(forKey: addressKey) ?? "" }
    static var token: String {
        var query = keyQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }
    private static var keyQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service, kSecAttrAccount as String: "uploadToken"]
    }
    static func serverURL(_ text: String) -> URL? {
        guard let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme),
              let host = url.host, !host.isEmpty, url.user == nil, url.password == nil,
              url.query == nil, url.fragment == nil else { return nil }
        return url
    }
    static var isConfigured: Bool { serverURL(address) != nil && !token.isEmpty }
    static func endpoint(_ path: String) -> URL? {
        guard let base = serverURL(address), !token.isEmpty else { return nil }
        return base.appendingPathComponent(path)
    }
    static func save(address: String, token: String) throws {
        guard let url = serverURL(address), !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SettingsError.invalid
        }
        let value = Data(token.trimmingCharacters(in: .whitespacesAndNewlines).utf8)
        let status = SecItemUpdate(keyQuery as CFDictionary, [kSecValueData as String: value] as CFDictionary)
        if status == errSecItemNotFound {
            var item = keyQuery
            item[kSecValueData as String] = value
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else { throw SettingsError.keychain }
        } else if status != errSecSuccess { throw SettingsError.keychain }
        UserDefaults.standard.set(url.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/")), forKey: addressKey)
        DispatchQueue.main.async { NotificationCenter.default.post(name: changed, object: nil) }
    }
    enum SettingsError: LocalizedError {
        case invalid, keychain
        var errorDescription: String? {
            switch self {
            case .invalid: return "Bitte eine vollständige HTTP(S)-Adresse und den Zugriffstoken des Mac eingeben."
            case .keychain: return "Der Zugriffstoken konnte nicht im Schlüsselbund gespeichert werden. Bitte das Gerät entsperren und erneut versuchen."
            }
        }
    }
}

@MainActor
final class UploadStatus: ObservableObject {
    static let shared = UploadStatus()
    @Published var message = "Verbindung noch nicht eingerichtet"
    @Published var pendingChunks = 0
}
