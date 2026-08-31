import Foundation
import Security

/// The mobile credential lives here and nowhere else.
///
/// Not UserDefaults: that is a plist in the app container, readable from a file-system backup and
/// from any process that can reach the container. A bearer token for an account that submits job
/// applications under the user's real name is not a preference.
///
/// `ThisDeviceOnly` keeps it out of iCloud Keychain and encrypted backups, so restoring a backup
/// onto another device does not carry a live session with it.
struct KeychainTokenStore {
    static let shared = KeychainTokenStore()

    private let service = "com.resumemaster.ios.auth"
    private let account = "mobile-token"

    private var baseQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    func save(_ token: String) {
        // Delete-then-add rather than SecItemUpdate: an update against a missing item fails, and
        // the two-call form is the same number of syscalls without the branch.
        SecItemDelete(baseQuery as CFDictionary)
        var query = baseQuery
        query[kSecValueData as String] = Data(token.utf8)
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(query as CFDictionary, nil)
    }

    func read() -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func clear() {
        SecItemDelete(baseQuery as CFDictionary)
    }
}
