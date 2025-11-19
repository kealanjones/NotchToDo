import Foundation
import Security

/// Secure Keychain helper with enhanced error handling and audit logging
/// Used for storing sensitive data like authentication tokens
enum KeychainHelper {

    // MARK: - Errors

    enum KeychainError: LocalizedError {
        case unexpectedDataFormat
        case operationFailed(OSStatus)
        case itemNotFound
        case duplicateItem
        case accessDenied

        var errorDescription: String? {
            switch self {
            case .unexpectedDataFormat:
                return "Keychain data format is invalid"
            case .operationFailed(let status):
                return "Keychain operation failed with status: \(status)"
            case .itemNotFound:
                return "Item not found in Keychain"
            case .duplicateItem:
                return "Item already exists in Keychain"
            case .accessDenied:
                return "Access to Keychain denied"
            }
        }
    }

    // MARK: - Public Methods

    /// Securely stores a string value in the Keychain
    /// - Parameters:
    ///   - value: The string to store (nil to delete)
    ///   - key: The unique key identifier
    /// - Returns: True if successful, false otherwise
    @discardableResult
    static func setString(_ value: String?, for key: String) -> Bool {
        let service = Bundle.main.bundleIdentifier ?? "com.notchtodo.app"
        let account = key

        // Log security event (without logging the actual value)
        if value != nil {
            DebugLog.log("🔐 Keychain: Storing value for key '\(key)'", category: .sync)
        } else {
            DebugLog.log("🔐 Keychain: Deleting value for key '\(key)'", category: .sync)
        }

        if let value {
            let data = Data(value.utf8)
            let attributes: [CFString: Any] = [
                kSecClass: kSecClassGenericPassword,
                kSecAttrService: service,
                kSecAttrAccount: account,
                kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock, // Secure access policy
            ]

            let status = SecItemCopyMatching(attributes as CFDictionary, nil)
            let result: OSStatus

            switch status {
            case errSecSuccess:
                // Update existing item
                let update: [CFString: Any] = [kSecValueData: data]
                result = SecItemUpdate(attributes as CFDictionary, update as CFDictionary)
                if result == errSecSuccess {
                    DebugLog.log("🔐 Keychain: Updated existing item for '\(key)'", category: .sync)
                } else {
                    DebugLog.log("⚠️ Keychain: Update failed for '\(key)' with status \(result)", category: .sync)
                }

            case errSecItemNotFound:
                // Add new item
                var query = attributes
                query[kSecValueData] = data
                result = SecItemAdd(query as CFDictionary, nil)
                if result == errSecSuccess {
                    DebugLog.log("🔐 Keychain: Added new item for '\(key)'", category: .sync)
                } else {
                    DebugLog.log("⚠️ Keychain: Add failed for '\(key)' with status \(result)", category: .sync)
                }

            default:
                // Unexpected status, delete and retry
                DebugLog.log("⚠️ Keychain: Unexpected status \(status) for '\(key)', deleting and retrying", category: .sync)
                SecItemDelete(attributes as CFDictionary)
                var query = attributes
                query[kSecValueData] = data
                result = SecItemAdd(query as CFDictionary, nil)
                if result == errSecSuccess {
                    DebugLog.log("🔐 Keychain: Added item after delete for '\(key)'", category: .sync)
                } else {
                    DebugLog.log("❌ Keychain: Retry failed for '\(key)' with status \(result)", category: .sync)
                }
            }

            return result == errSecSuccess
        } else {
            // Delete item
            let attributes: [CFString: Any] = [
                kSecClass: kSecClassGenericPassword,
                kSecAttrService: service,
                kSecAttrAccount: account,
            ]
            let status = SecItemDelete(attributes as CFDictionary)

            // errSecItemNotFound is OK (item already deleted)
            if status == errSecSuccess || status == errSecItemNotFound {
                DebugLog.log("🔐 Keychain: Deleted item for '\(key)'", category: .sync)
                return true
            } else {
                DebugLog.log("⚠️ Keychain: Delete failed for '\(key)' with status \(status)", category: .sync)
                return false
            }
        }
    }

    /// Retrieves a string value from the Keychain
    /// - Parameter key: The unique key identifier
    /// - Returns: The stored string value, or nil if not found
    static func string(for key: String) -> String? {
        let service = Bundle.main.bundleIdentifier ?? "com.notchtodo.app"
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecReturnData: kCFBooleanTrue ?? true,
            kSecMatchLimit: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data else {
                DebugLog.log("⚠️ Keychain: Retrieved data for '\(key)' but format is invalid", category: .sync)
                return nil
            }
            guard let string = String(data: data, encoding: .utf8) else {
                DebugLog.log("⚠️ Keychain: Could not decode UTF-8 string for '\(key)'", category: .sync)
                return nil
            }
            DebugLog.log("🔐 Keychain: Retrieved value for '\(key)'", category: .sync)
            return string

        case errSecItemNotFound:
            DebugLog.log("🔐 Keychain: No value found for '\(key)'", category: .sync)
            return nil

        default:
            DebugLog.log("⚠️ Keychain: Retrieval failed for '\(key)' with status \(status)", category: .sync)
            return nil
        }
    }

    /// Checks if a value exists for the given key
    /// - Parameter key: The unique key identifier
    /// - Returns: True if the key exists in Keychain
    static func exists(for key: String) -> Bool {
        let service = Bundle.main.bundleIdentifier ?? "com.notchtodo.app"
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecReturnData: false
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Removes all Keychain items for this app (use with caution!)
    /// - Returns: True if successful
    @discardableResult
    static func clearAll() -> Bool {
        let service = Bundle.main.bundleIdentifier ?? "com.notchtodo.app"
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service
        ]

        let status = SecItemDelete(query as CFDictionary)

        if status == errSecSuccess || status == errSecItemNotFound {
            DebugLog.log("🔐 Keychain: Cleared all items for app", category: .sync)
            return true
        } else {
            DebugLog.log("⚠️ Keychain: Clear all failed with status \(status)", category: .sync)
            return false
        }
    }
}
