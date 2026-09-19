import Foundation

#if os(macOS)
import Security

public final class KeychainHelper: @unchecked Sendable {
    public static let shared = KeychainHelper()
    
    private let service: String
    private let accountPrefix: String
    
    public init(service: String = AppConfig.keychainService) {
        self.service = service
        self.accountPrefix = AppConfig.bundleIdentifier
    }
    
    /// Speichert ein Passwort atomar im macOS Schlüsselbund
    public func savePassword(_ password: String, for account: String) -> Bool {
        guard let data = password.data(using: .utf8) else { return false }
        let fullAccount = "\(accountPrefix).\(account)"
        
        // Zuerst bestehenden Eintrag löschen um Prompt-Kaskaden zu verhindern
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: fullAccount
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        
        // Neu anlegen mit kSecAttrAccessibleAfterFirstUnlock
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: fullAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    /// Liest ein Passwort aus dem macOS Schlüsselbund aus
    public func getPassword(for account: String) -> String? {
        let fullAccount = "\(accountPrefix).\(account)"
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: fullAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status == errSecSuccess,
              let data = item as? Data,
              let pw = String(data: data, encoding: .utf8) else {
            return nil
        }
        return pw
    }
    
    /// Löscht ein Passwort aus dem Schlüsselbund
    public func deletePassword(for account: String) -> Bool {
        let fullAccount = "\(accountPrefix).\(account)"
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: fullAccount
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
#else
// Linux / Non-macOS Fallback (in-memory)
public final class KeychainHelper: @unchecked Sendable {
    public static let shared = KeychainHelper()
    private var memoryStore: [String: String] = [:]
    private let lock = NSLock()
    
    public init(service: String = AppConfig.keychainService) {}
    
    public func savePassword(_ password: String, for account: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        memoryStore[account] = password
        return true
    }
    
    public func getPassword(for account: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return memoryStore[account]
    }
    
    public func deletePassword(for account: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        memoryStore.removeValue(forKey: account)
        return true
    }
}
#endif
