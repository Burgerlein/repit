import Flutter
import Foundation

/// Der Kanal `de.rosenbach.repit/keychain` (#336): `lies`,
/// `schreibe`, `loesche`, Argumente `{konto, wert}`.
///
/// **Der Wert erscheint nie in einer Meldung.** Weder im Log noch in einem
/// `FlutterError` — Keychain-Fehler tragen nur den `OSStatus`,
/// Argumentfehler nur den Namen des fehlenden Arguments.
final class KeychainChannel {
    static let channelName = "de.rosenbach.repit/keychain"
    static let service = "de.rosenbach.repit.ki"

    private let channel: FlutterMethodChannel

    private init(store: KeychainStore, messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
        channel.setMethodCallHandler { call, result in
            result(Self.respond(to: call, store: store))
        }
    }

    static func register(with messenger: FlutterBinaryMessenger) -> KeychainChannel {
        KeychainChannel(store: KeychainStore(service: service), messenger: messenger)
    }

    /// Was `result(...)` bekommt: der gelesene `String`, `nil`, ein
    /// `FlutterError` oder `FlutterMethodNotImplemented`. Synchron, weil
    /// die Keychain-Aufrufe es sind.
    static func respond(to call: FlutterMethodCall, store: KeychainStore) -> Any? {
        let arguments = call.arguments as? [String: Any]

        switch call.method {
        case "lies", "schreibe", "loesche":
            break
        default:
            return FlutterMethodNotImplemented
        }

        guard let account = arguments?["konto"] as? String else {
            return argumentError("konto fehlt oder ist kein Text")
        }

        do {
            switch call.method {
            case "lies":
                return try store.read(account: account)
            case "schreibe":
                guard let value = arguments?["wert"] as? String else {
                    return argumentError("wert fehlt oder ist kein Text")
                }
                try store.write(value, account: account)
                return nil
            default:
                try store.delete(account: account)
                return nil
            }
        } catch let error as KeychainError {
            return FlutterError(code: "keychain", message: "\(error.status)", details: nil)
        } catch {
            // `KeychainStore` wirft nur `KeychainError`; alles andere wird
            // ohne Beschreibung gemeldet, damit kein Wert hineingeraten kann.
            return FlutterError(code: "keychain", message: nil, details: nil)
        }
    }

    private static func argumentError(_ message: String) -> FlutterError {
        FlutterError(code: "argumente", message: message, details: nil)
    }
}
