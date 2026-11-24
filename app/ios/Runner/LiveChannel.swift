import Flutter
import Foundation

/// Ein Argument des Live-Kanals fehlt oder hat den falschen Typ. Auf dem
/// Kanal wird daraus `FlutterError(code: "argumente")`.
///
/// Ein falscher Typ wirft, statt still `nil` zu werden: Das wäre ein
/// Programmierfehler im Kanal, keine Datenlage (`CLAUDE.md`).
struct LiveArgumentError: Error, Equatable, LocalizedError {
    let meldung: String

    init(_ meldung: String) {
        self.meldung = meldung
    }

    var errorDescription: String? { meldung }
}

extension EssenAttributes.ContentState {

    /// Die Namen der vier Mahlzeiten (`Mahlzeit.values` im Kern).
    static let mahlzeitNamen: Set<String> = ["fruehstueck", "mittag", "snack", "abend"]

    /// Kodiert die Teil-Map unter `"essen"` aus den Argumenten von `zeige`.
    ///
    /// **Fehlt ein Wert, fehlt der Schlüssel** (Spec, „Dart → Swift"): Ein
    /// fehlendes `kcal` wird `nil`, nie `0`; ein fehlendes `ersteOffene`
    /// heißt, keine Mahlzeit ist offen. Alles andere ist Pflicht.
    init(kanal: [String: Any]) throws {
        guard let liste = kanal["mahlzeiten"] else {
            throw LiveArgumentError("mahlzeiten fehlt")
        }
        guard let eintraege = liste as? [Any] else {
            throw LiveArgumentError("mahlzeiten ist keine Liste")
        }
        guard eintraege.count == 4 else {
            throw LiveArgumentError("mahlzeiten hat \(eintraege.count) statt vier Einträge")
        }
        let mahlzeiten = try eintraege.map { eintrag -> Mahlzeit in
            guard let map = eintrag as? [String: Any] else {
                throw LiveArgumentError("eine Mahlzeit ist keine Map")
            }
            return try Mahlzeit(kanal: map)
        }

        let ersteOffene: String?
        if let wert = kanal["ersteOffene"], !(wert is NSNull) {
            guard let name = wert as? String, Self.mahlzeitNamen.contains(name) else {
                throw LiveArgumentError("ersteOffene ist kein Mahlzeitname")
            }
            ersteOffene = name
        } else {
            ersteOffene = nil
        }

        self.init(
            mahlzeiten: mahlzeiten,
            ersteOffene: ersteOffene,
            serie: try LiveKanalWert.ganzzahl(kanal["serie"], "serie"),
            serieAbMorgen: try LiveKanalWert.ganzzahl(kanal["serieAbMorgen"], "serieAbMorgen")
        )
    }
}

extension EssenAttributes.ContentState.Mahlzeit {

    init(kanal: [String: Any]) throws {
        guard let name = kanal["mahlzeit"] as? String,
              EssenAttributes.ContentState.mahlzeitNamen.contains(name)
        else {
            throw LiveArgumentError("mahlzeit fehlt oder ist unbekannt")
        }
        let kcal: Int?
        if let wert = kanal["kcal"] {
            kcal = try LiveKanalWert.ganzzahl(wert, "kcal")
        } else {
            kcal = nil
        }
        // Wie `kcal`: Fehlt der Schlüssel, gibt es kein Ziel (V15). Ein
        // Wahrheitswert oder Text ist ein Fehler im Kanal und wirft.
        let anteil: Double?
        if let wert = kanal["anteil"] {
            anteil = try LiveKanalWert.zahl(wert, "anteil")
        } else {
            anteil = nil
        }
        self.init(
            mahlzeit: name,
            eintrag: try LiveKanalWert.wahrheitswert(kanal["eintrag"], "eintrag"),
            kcal: kcal,
            anteil: anteil
        )
    }
}

/// Strenges Lesen der Zahlen und Wahrheitswerte, wie der Standard-Codec sie
/// liefert (`NSNumber`). Ein `true` ist keine Zahl, ein Text keine Zahl.
enum LiveKanalWert {

    static func ganzzahl(_ wert: Any?, _ name: String) throws -> Int {
        guard let zahl = wert as? NSNumber, !istWahrheitswert(zahl) else {
            throw LiveArgumentError("\(name) fehlt oder ist keine Zahl")
        }
        guard let ganz = Int(exactly: zahl.doubleValue) else {
            throw LiveArgumentError("\(name) ist keine ganze Zahl")
        }
        return ganz
    }

    /// Eine Kommazahl. Der Standard-Codec liefert ein Dart-`double` als
    /// `NSNumber`. Ein nicht endlicher Wert ist ein Fehler im Kanal und wirft.
    static func zahl(_ wert: Any?, _ name: String) throws -> Double {
        guard let zahl = wert as? NSNumber, !istWahrheitswert(zahl) else {
            throw LiveArgumentError("\(name) fehlt oder ist keine Zahl")
        }
        let double = zahl.doubleValue
        guard double.isFinite else {
            throw LiveArgumentError("\(name) ist keine endliche Zahl")
        }
        return double
    }

    static func wahrheitswert(_ wert: Any?, _ name: String) throws -> Bool {
        guard let zahl = wert as? NSNumber, istWahrheitswert(zahl) else {
            throw LiveArgumentError("\(name) fehlt oder ist kein Wahrheitswert")
        }
        return zahl.boolValue
    }

    private static func istWahrheitswert(_ zahl: NSNumber) -> Bool {
        CFGetTypeID(zahl) == CFBooleanGetTypeID()
    }
}

/// Der Kanal `de.rosenbach.repit/live` (#366, Spec „Der Kanal"):
/// `zeige`, `beendeAlle`, `nimmLink` von Dart, `linkDa` nach Dart.
///
/// Die Aufrufe laufen **hintereinander**: Ein `zeige`, das noch auf
/// ActivityKit wartet, ist fertig, bevor das nächste die laufenden
/// Aktivitäten liest. Sonst sähen zwei schnelle Aufrufe beide „keine
/// läuft" und starteten je eine — genau die Dublette, die `zeige` abräumen
/// soll.
@MainActor
final class LiveChannel {
    static let channelName = "de.rosenbach.repit/live"

    private let channel: FlutterMethodChannel
    private let controller: LiveActivityController
    private let links: LiveLinkBuffer
    private var letzterAufruf: Task<Void, Never>?

    private init(
        controller: LiveActivityController,
        links: LiveLinkBuffer,
        messenger: FlutterBinaryMessenger
    ) {
        self.controller = controller
        self.links = links
        let channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
        self.channel = channel

        channel.setMethodCallHandler { [weak self] call, result in
            Task { @MainActor in
                guard let self else {
                    result(FlutterMethodNotImplemented)
                    return
                }
                self.reiheEin(call, result)
            }
        }
        links.beiAnkunft = { [weak channel] in
            channel?.invokeMethod("linkDa", arguments: nil)
        }
    }

    static func register(with messenger: FlutterBinaryMessenger) -> LiveChannel {
        LiveChannel(
            controller: LiveActivityController(host: ActivityKitHost()),
            links: .shared,
            messenger: messenger
        )
    }

    private func reiheEin(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        let vorheriger = letzterAufruf
        let controller = controller
        let links = links
        letzterAufruf = Task { @MainActor in
            await vorheriger?.value
            result(await Self.respond(to: call, controller: controller, links: links))
        }
    }

    /// Was `result(...)` bekommt: `"gestartet"`, `"aktualisiert"`,
    /// `"abgeschaltet"`, den Host-Teil eines Links, `nil`, einen
    /// `FlutterError` oder `FlutterMethodNotImplemented`.
    ///
    /// Erst werden alle Argumente gelesen, dann wird der Controller gerufen:
    /// Ein Argumentfehler fasst keine laufende Aktivität an.
    static func respond(
        to call: FlutterMethodCall,
        controller: LiveActivityController,
        links: LiveLinkBuffer
    ) async -> Any? {
        switch call.method {
        case "zeige":
            return await zeige(call.arguments, controller: controller)
        case "beendeAlle":
            await controller.beendeAlle()
            return nil
        case "nimmLink":
            return links.nimm()
        default:
            return FlutterMethodNotImplemented
        }
    }

    private static func zeige(_ arguments: Any?, controller: LiveActivityController) async -> Any? {
        let fassung: String
        let frisch: Bool
        let staleDate: Date
        let state: EssenAttributes.ContentState
        do {
            guard let args = arguments as? [String: Any] else {
                throw LiveArgumentError("Argumente fehlen")
            }
            guard let wert = args["fassung"] as? String, wert == LiveActivityController.essen else {
                throw LiveArgumentError("fassung fehlt oder ist nicht essen")
            }
            fassung = wert
            frisch = try LiveKanalWert.wahrheitswert(args["frisch"], "frisch")
            let millis = try LiveKanalWert.ganzzahl(args["verfaelltUm"], "verfaelltUm")
            staleDate = Date(timeIntervalSince1970: Double(millis) / 1000)
            guard let essen = args["essen"] as? [String: Any] else {
                throw LiveArgumentError("essen fehlt oder ist keine Map")
            }
            state = try EssenAttributes.ContentState(kanal: essen)
        } catch {
            return FlutterError(code: "argumente", message: error.localizedDescription, details: nil)
        }

        do {
            let ergebnis = try await controller.zeige(
                fassung: fassung, frisch: frisch, state: state, staleDate: staleDate
            )
            return ergebnis.rawValue
        } catch let fehler as LiveArgumentError {
            return FlutterError(code: "argumente", message: fehler.meldung, details: nil)
        } catch {
            return FlutterError(code: "live", message: error.localizedDescription, details: nil)
        }
    }
}
