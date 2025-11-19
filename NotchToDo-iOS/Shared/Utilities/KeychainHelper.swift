import Foundation
import Security

enum KeychainHelper {
    static func setString(_ value: String?, for key: String) {
        let service = Bundle.main.bundleIdentifier ?? "com.notchtodo.app"
        let account = key

        if let value {
            let data = Data(value.utf8)
            let attributes: [CFString: Any] = [
                kSecClass: kSecClassGenericPassword,
                kSecAttrService: service,
                kSecAttrAccount: account,
            ]

            let status = SecItemCopyMatching(attributes as CFDictionary, nil)
            switch status {
            case errSecSuccess:
                let update: [CFString: Any] = [kSecValueData: data]
                SecItemUpdate(attributes as CFDictionary, update as CFDictionary)
            case errSecItemNotFound:
                var query = attributes
                query[kSecValueData] = data
                SecItemAdd(query as CFDictionary, nil)
            default:
                SecItemDelete(attributes as CFDictionary)
                var query = attributes
                query[kSecValueData] = data
                SecItemAdd(query as CFDictionary, nil)
            }
        } else {
            let attributes: [CFString: Any] = [
                kSecClass: kSecClassGenericPassword,
                kSecAttrService: service,
                kSecAttrAccount: account,
            ]
            SecItemDelete(attributes as CFDictionary)
        }
    }

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
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }
}
