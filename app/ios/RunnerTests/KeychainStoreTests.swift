import Flutter
import Foundation
import Security
import Testing
@testable import Runner

/// Die Swift-Seite des Keychain-Kanals (#336) — der Speicher für den
/// Gemini-Schlüssel.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, nie verändert werden. Hält der
/// Implementierende eine Erwartung hier für falsch, wird das **gemeldet**,
/// nicht korrigiert.
///
/// Swift Testing, nicht XCTest — wie jede Testdatei dieses Projekts außer
/// dem unveränderten `flutter create`-Gerüst `RunnerTests.swift`.
///
/// Grundlage: `docs/superpowers/specs/2026-11-04-ki-zugang-design.md`
/// (Abschnitt „Der Schlüssel") und `docs/superpowers/plans/2026-11-04-ki-zugang.md`
/// (Task 5).
///
/// ## Kein echter Schlüssel, nirgends
///
/// Jeder Wert in dieser Datei ist erfunden und trägt **nicht** das Präfix
/// `AIza` (Plan, „Global Constraints"). Alle Tests laufen gegen einen
/// eigenen Testdienst, nie gegen `de.rosenbach.repit.ki` — ein
/// Testlauf auf einem Gerät darf Tims hinterlegten Schlüssel weder lesen
/// noch überschreiben noch löschen. Jedes Konto ist je Test eindeutig
/// (Swift Testing läuft parallel), und jeder Test räumt hinterher **direkt
/// über `SecItemDelete`** auf, nicht über den Code, den er prüft: Ein
/// kaputtes `delete` soll einen Test rot machen, nicht Reste hinterlassen.
///
/// ## Erwartete API
///
/// Aus dem Plan (Task 5, „Interfaces") übernommen:
///
/// ```swift
/// struct KeychainStore {
///     init(service: String)
///     func read(account: String) throws -> String?
///     func write(_ value: String, account: String) throws
///     func delete(account: String) throws
/// }
/// ```
///
/// `kSecClassGenericPassword`, Zugriff
/// `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`.
///
/// **Eigene Festlegung dieses Test-Agenten, nicht von Tim freigegeben:**
/// Der Plan nennt Kanalname, Dienst, Methoden, Argumente und den Fehlercode,
/// aber keine prüfbare Form des Kanals. Damit die Zusage „nie mit dem Wert
/// in der Meldung" einen Test bekommt, ohne einen `FlutterBinaryMessenger`
/// nachzubauen, verlangt diese Datei eine reine, synchrone Antwortfunktion
/// — die Keychain-Aufrufe sind ohnehin synchron:
///
/// ```swift
/// enum/final class KeychainChannel {
///     static let channelName = "de.rosenbach.repit/keychain"
///     static let service = "de.rosenbach.repit.ki"
///
///     /// Was `result(...)` bekommt: der gelesene `String`, `nil`, ein
///     /// `FlutterError` oder `FlutterMethodNotImplemented`. Der eigentliche
///     /// Handler ruft nur noch `result(respond(to: call, store: store))`.
///     static func respond(to call: FlutterMethodCall, store: KeychainStore) -> Any?
/// }
/// ```
///
/// Ebenfalls eigene Festlegung: `schreibe` und `loesche` antworten mit
/// `nil` — insbesondere gibt `schreibe` den Wert **nicht** zurück. Ein
/// Argumentfehler (fehlendes `konto`, `wert` kein `String`) ist ein
/// `FlutterError`; welchen `code` er trägt, legt diese Datei nicht fest,
/// nur dass weder `message` noch `details` den Wert enthalten.
@Suite("KeychainStore")
struct KeychainStoreTests {

    /// Eigener Testdienst (Plan: „gegen einen eigenen Testdienst (`…ki.tests`)").
    static let testService = "de.rosenbach.repit.ki.tests"
    /// Ein zweiter Testdienst, nur für den Trennungsfall.
    static let otherTestService = "de.rosenbach.repit.ki.tests.anderer"

    /// Erfunden, ohne `AIza`.
    static let fakeValue = "erfunden-kein-schluessel-0001"
    static let otherFakeValue = "erfunden-kein-schluessel-0002"

    // MARK: - Pflichtfälle aus dem Plan

    @Test("schreiben, dann lesen ergibt denselben Wert")
    func writeThenRead() throws {
        let account = KeychainTestSupport.uniqueAccount()
        defer { KeychainTestSupport.rawDelete(service: Self.testService, account: account) }
        let store = KeychainStore(service: Self.testService)

        try store.write(Self.fakeValue, account: account)

        #expect(try store.read(account: account) == Self.fakeValue)
    }

    @Test("zweimal schreiben überschreibt, statt mit errSecDuplicateItem zu scheitern")
    func writeTwiceOverwrites() throws {
        let account = KeychainTestSupport.uniqueAccount()
        defer { KeychainTestSupport.rawDelete(service: Self.testService, account: account) }
        let store = KeychainStore(service: Self.testService)

        try store.write(Self.fakeValue, account: account)
        #expect(throws: Never.self) {
            try store.write(Self.otherFakeValue, account: account)
        }

        #expect(try store.read(account: account) == Self.otherFakeValue)
        #expect(KeychainTestSupport.rawCount(service: Self.testService, account: account) == 1)
    }

    @Test("nach dem Löschen liest der Speicher nil")
    func deleteThenReadIsNil() throws {
        let account = KeychainTestSupport.uniqueAccount()
        defer { KeychainTestSupport.rawDelete(service: Self.testService, account: account) }
        let store = KeychainStore(service: Self.testService)

        try store.write(Self.fakeValue, account: account)
        try store.delete(account: account)

        #expect(try store.read(account: account) == nil)
        #expect(KeychainTestSupport.rawCount(service: Self.testService, account: account) == 0)
    }

    @Test("ein Konto löschen, das es nie gab, wirft nicht")
    func deleteMissingDoesNotThrow() {
        let account = KeychainTestSupport.uniqueAccount()
        defer { KeychainTestSupport.rawDelete(service: Self.testService, account: account) }
        let store = KeychainStore(service: Self.testService)

        #expect(throws: Never.self) {
            try store.delete(account: account)
        }
    }

    @Test("der Eintrag trägt kSecAttrAccessibleWhenUnlockedThisDeviceOnly — nicht im Backup, nicht auf einem neuen Gerät")
    func accessibilityIsWhenUnlockedThisDeviceOnly() throws {
        let account = KeychainTestSupport.uniqueAccount()
        defer { KeychainTestSupport.rawDelete(service: Self.testService, account: account) }
        let store = KeychainStore(service: Self.testService)

        try store.write(Self.fakeValue, account: account)
        let attributes = try #require(
            KeychainTestSupport.rawAttributes(service: Self.testService, account: account)
        )
        #expect(attributes[kSecAttrAccessible as String] as? String
            == kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String)

        // Auch nach dem Überschreiben — ein Update-Pfad, der die
        // Zugriffsklasse neu setzt oder verliert, fiele sonst nicht auf.
        try store.write(Self.otherFakeValue, account: account)
        let afterOverwrite = try #require(
            KeychainTestSupport.rawAttributes(service: Self.testService, account: account)
        )
        #expect(afterOverwrite[kSecAttrAccessible as String] as? String
            == kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String)
    }

    // MARK: - Trennung

    @Test("lesen ohne Eintrag ergibt nil und wirft nicht")
    func readMissingIsNil() throws {
        let account = KeychainTestSupport.uniqueAccount()
        let store = KeychainStore(service: Self.testService)

        #expect(try store.read(account: account) == nil)
    }

    @Test("ein anderer Dienst sieht den Eintrag nicht — die Tests berühren den echten Dienst nie")
    func servicesAreSeparate() throws {
        let account = KeychainTestSupport.uniqueAccount()
        defer {
            KeychainTestSupport.rawDelete(service: Self.testService, account: account)
            KeychainTestSupport.rawDelete(service: Self.otherTestService, account: account)
        }

        try KeychainStore(service: Self.testService).write(Self.fakeValue, account: account)

        #expect(try KeychainStore(service: Self.otherTestService).read(account: account) == nil)
        #expect(KeychainTestSupport.rawCount(service: Self.testService, account: account) == 1)
    }

    @Test("Konten im selben Dienst sind getrennt — löschen trifft nur das eine")
    func accountsAreSeparate() throws {
        let first = KeychainTestSupport.uniqueAccount()
        let second = KeychainTestSupport.uniqueAccount()
        defer {
            KeychainTestSupport.rawDelete(service: Self.testService, account: first)
            KeychainTestSupport.rawDelete(service: Self.testService, account: second)
        }
        let store = KeychainStore(service: Self.testService)

        try store.write(Self.fakeValue, account: first)
        try store.write(Self.otherFakeValue, account: second)
        try store.delete(account: first)

        #expect(try store.read(account: first) == nil)
        #expect(try store.read(account: second) == Self.otherFakeValue)
    }
}

@Suite("KeychainChannel")
struct KeychainChannelTests {

    static let testService = KeychainStoreTests.testService
    static let fakeValue = "erfunden-kein-schluessel-0003"

    // MARK: - Vertrag mit der Dart-Seite

    @Test("Kanalname und Dienst stehen buchstabengleich wie in Spec und Plan")
    func namesMatchSpec() {
        #expect(KeychainChannel.channelName == "de.rosenbach.repit/keychain")
        #expect(KeychainChannel.service == "de.rosenbach.repit.ki")
    }

    // MARK: - Die drei Methoden

    @Test("schreibe, dann lies über den Kanal ergibt den Wert; schreibe selbst antwortet nil")
    func writeThenReadThroughChannel() throws {
        let account = KeychainTestSupport.uniqueAccount()
        defer { KeychainTestSupport.rawDelete(service: Self.testService, account: account) }
        let store = KeychainStore(service: Self.testService)

        let writeAnswer = KeychainChannel.respond(
            to: FlutterMethodCall(methodName: "schreibe",
                                  arguments: ["konto": account, "wert": Self.fakeValue]),
            store: store
        )
        #expect(writeAnswer == nil, "schreibe gibt den Wert nicht zurück")

        let readAnswer = KeychainChannel.respond(
            to: FlutterMethodCall(methodName: "lies", arguments: ["konto": account]),
            store: store
        )
        #expect(readAnswer as? String == Self.fakeValue)
    }

    @Test("lies ohne Eintrag antwortet nil — nicht NSNull, nicht leerer Text")
    func readMissingThroughChannelIsNil() {
        let account = KeychainTestSupport.uniqueAccount()
        let store = KeychainStore(service: Self.testService)

        let answer = KeychainChannel.respond(
            to: FlutterMethodCall(methodName: "lies", arguments: ["konto": account]),
            store: store
        )
        #expect(answer == nil)
    }

    @Test("loesche entfernt den Eintrag und antwortet nil")
    func deleteThroughChannel() throws {
        let account = KeychainTestSupport.uniqueAccount()
        defer { KeychainTestSupport.rawDelete(service: Self.testService, account: account) }
        let store = KeychainStore(service: Self.testService)
        try store.write(Self.fakeValue, account: account)

        let answer = KeychainChannel.respond(
            to: FlutterMethodCall(methodName: "loesche", arguments: ["konto": account]),
            store: store
        )

        #expect(answer == nil)
        #expect(try store.read(account: account) == nil)
    }

    @Test("loesche ohne Eintrag antwortet nil, nicht mit einem Fehler")
    func deleteMissingThroughChannelIsNil() {
        let account = KeychainTestSupport.uniqueAccount()
        let store = KeychainStore(service: Self.testService)

        let answer = KeychainChannel.respond(
            to: FlutterMethodCall(methodName: "loesche", arguments: ["konto": account]),
            store: store
        )
        #expect(answer == nil)
    }

    @Test("eine unbekannte Methode antwortet FlutterMethodNotImplemented")
    func unknownMethod() {
        let store = KeychainStore(service: Self.testService)

        let answer = KeychainChannel.respond(
            to: FlutterMethodCall(methodName: "gibtEsNicht", arguments: nil),
            store: store
        )
        #expect((answer as? NSObject) === FlutterMethodNotImplemented)
    }

    // MARK: - Der Wert steht in keiner Fehlermeldung

    @Test("schreibe ohne konto ist ein FlutterError, und der Wert steht weder in message noch in details")
    func writeWithoutAccountDoesNotLeakValue() throws {
        let store = KeychainStore(service: Self.testService)

        let answer = KeychainChannel.respond(
            to: FlutterMethodCall(methodName: "schreibe", arguments: ["wert": Self.fakeValue]),
            store: store
        )

        let error = try #require(answer as? FlutterError)
        #expect(!KeychainTestSupport.text(of: error).contains(Self.fakeValue))
    }

    @Test("schreibe mit wert, der kein Text ist, ist ein FlutterError und speichert nichts")
    func writeWithNonStringValueIsError() throws {
        let account = KeychainTestSupport.uniqueAccount()
        defer { KeychainTestSupport.rawDelete(service: Self.testService, account: account) }
        let store = KeychainStore(service: Self.testService)

        let answer = KeychainChannel.respond(
            to: FlutterMethodCall(methodName: "schreibe",
                                  arguments: ["konto": account, "wert": NSNumber(value: 1234)]),
            store: store
        )

        #expect(answer is FlutterError)
        #expect(KeychainTestSupport.rawCount(service: Self.testService, account: account) == 0)
    }

    @Test("lies ohne konto ist ein FlutterError, kein stilles nil")
    func readWithoutAccountIsError() {
        let store = KeychainStore(service: Self.testService)

        let answer = KeychainChannel.respond(
            to: FlutterMethodCall(methodName: "lies", arguments: nil),
            store: store
        )
        #expect(answer is FlutterError)
    }

    @Test("loesche ohne konto ist ein FlutterError")
    func deleteWithoutAccountIsError() {
        let store = KeychainStore(service: Self.testService)

        let answer = KeychainChannel.respond(
            to: FlutterMethodCall(methodName: "loesche", arguments: [String: Any]()),
            store: store
        )
        #expect(answer is FlutterError)
    }
}

/// Direkter Zugriff auf die Keychain, **unabhängig vom geprüften Code** —
/// zum Aufräumen und um Attribute zu lesen, die `KeychainStore` nicht
/// herausgibt.
enum KeychainTestSupport {

    static func uniqueAccount() -> String {
        "test-konto-\(UUID().uuidString)"
    }

    static func rawDelete(service: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }

    static func rawAttributes(service: String, account: String) -> [String: Any]? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else {
            return nil
        }
        return result as? [String: Any]
    }

    static func rawCount(service: String, account: String) -> Int {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll,
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return 0 }
        return (result as? [[String: Any]])?.count ?? 0
    }

    /// Alles, was die Dart-Seite von einem Fehler zu sehen bekommt.
    static func text(of error: FlutterError) -> String {
        [error.code, error.message ?? "", error.details.map { String(describing: $0) } ?? ""]
            .joined(separator: " | ")
    }
}
