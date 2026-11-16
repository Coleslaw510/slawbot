import Foundation
import Security

enum KeychainStore {
    private static let service = Bundle.main.bundleIdentifier ?? "com.coleslaw510.slawbot"
    private static let account = "openhands-access-token"

    static func readAccessToken() -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else { return "" }
        return value
    }

    @discardableResult
    static func saveAccessToken(_ value: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            let status = SecItemDelete(query as CFDictionary)
            return status == errSecSuccess || status == errSecItemNotFound
        }

        guard let data = trimmed.data(using: .utf8) else { return false }
        let update: [String: Any] = [
            kSecValueData as String: data
        ]
        let updateStatus = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if updateStatus == errSecSuccess { return true }
        guard updateStatus == errSecItemNotFound else { return false }

        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let addStatus = SecItemAdd(add as CFDictionary, nil)
        return addStatus == errSecSuccess
    }
}
