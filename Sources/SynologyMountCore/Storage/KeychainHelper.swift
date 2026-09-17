import Foundation
#if canImport(Security)
import Security
#endif

public final class KeychainHelper: @unchecked Sendable {
    public static let shared = KeychainHelper()
    
    private let service: String
    
    public init(service: String = AppConfig.keychainService) {
        self.service = service
    }
    
    public func savePassword(_ password: String, for account: String) -> Bool {
        #if canImport(Security)
        guard let data = password.data(using: .utf8) else { return false }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        SecItemDelete(query as CFDictionary)
        
        var newQuery = query
        newQuery[kSecValueData as String] = data
        let status = SecItemAdd(newQuery as CFDictionary, nil)
        return status == errSecSuccess
        #else
        // Mock fallback für Linux-Umgebung (Tests/CLI)
        return true
        #endif
    }
    
    public func getPassword(for account: String) -> String? {
        #if canImport(Security)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
        #else
        return nil
        #endif
    }
    
    public func deletePassword(for account: String) -> Bool {
        #if canImport(Security)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
        #else
        return true
        #endif
    }
}
