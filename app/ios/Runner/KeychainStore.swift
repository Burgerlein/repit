import Foundation
import Security

/// Ein Fehler der Keychain — trägt **nur** den `OSStatus`, nie den Wert,
/// der gelesen oder geschrieben werden sollte (#336).
struct KeychainError: Error, CustomStringConvertible {
    let status: OSStatus

    var description: String { "OSStatus \(status)" }
}

/// Generische Passwörter in der Keychain, ein Dienst je Instanz (#336).
///
/// Zugriff `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`: Der Eintrag
/// wandert weder ins Gerätebackup noch auf ein neues Gerät
/// (`docs/superpowers/specs/2026-11-04-ki-zugang-design.md`, „Der Schlüssel").
struct KeychainStore {
    let service: String

    init(service: String) {
        self.service = service
    }

    /// Der gespeicherte Text, oder `nil`, wenn es keinen Eintrag gibt.
    func read(account: String) throws -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data, let text = String(data: data, encoding: .utf8) else {
                throw KeychainError(status: errSecDecode)
            }
            return text
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError(status: status)
        }
    }

    /// Legt den Eintrag an oder überschreibt ihn. Die Zugriffsklasse wird
    /// auch beim Überschreiben gesetzt, damit ein älterer Eintrag sie nicht
    /// behält.
    func write(_ value: String, account: String) throws {
        let data = Data(value.utf8)

        var addQuery = baseQuery(account: account)
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        switch addStatus {
        case errSecSuccess:
            return
        case errSecDuplicateItem:
            let changes: [String: Any] = [
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            ]
            let updateStatus = SecItemUpdate(baseQuery(account: account) as CFDictionary,
                                             changes as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw KeychainError(status: updateStatus)
            }
        default:
            throw KeychainError(status: addStatus)
        }
    }

    /// Entfernt den Eintrag. Gibt es keinen, ist das kein Fehler.
    func delete(account: String) throws {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError(status: status)
        }
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
