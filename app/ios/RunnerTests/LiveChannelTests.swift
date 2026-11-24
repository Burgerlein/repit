import Flutter
import Foundation
import Testing
@testable import Runner

/// Die Swift-Seite des Live-Kanals (#366, #276): Kodierung der Kanal-Map
/// in `EssenAttributes.ContentState`, der Link-Puffer und die
/// Antwortfunktion des Kanals.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, nie verändert werden. Hält der
/// Implementierende eine Erwartung hier für falsch, wird das **gemeldet**,
/// nicht korrigiert.
///
/// Swift Testing, nicht XCTest — wie jede Testdatei dieses Projekts außer
/// dem unveränderten `flutter create`-Gerüst `RunnerTests.swift`.
///
/// Grundlage: `docs/superpowers/specs/2026-11-05-live-aktivitaet-design.md`
/// (Abschnitte „Der Kanal", „Was die Swift-Seite tut", „Der Link") und
/// `docs/superpowers/plans/2026-11-05-live-aktivitaet.md` (Task 4). Die
/// Steuerung (`LiveActivityController`) und die Attrappe des Hosts stehen in
/// `LiveActivityControllerTests.swift`.
///
/// ## Erwartete API (aus dem Plan, Task 4, „Interfaces")
///
/// ```swift
/// extension EssenAttributes.ContentState {
///     init(kanal: [String: Any]) throws   // wirft LiveArgumentError
/// }
/// final class LiveLinkBuffer {
///     static let shared: LiveLinkBuffer
///     func nimmAn(_ url: URL)
///     func nimm() -> String?
///     var beiAnkunft: (() -> Void)?
/// }
/// final class LiveChannel {
///     static let channelName = "de.rosenbach.repit/live"
/// }
/// ```
///
/// ## Eigene Festlegungen dieses Test-Agenten — nicht von Tim freigegeben
///
/// Plan und Spec lassen diese Punkte offen; ohne Festlegung ließe sich kein
/// Test schreiben. Jede ist zum Gegenlesen offen.
///
/// 1. **`init(kanal:)` bekommt die Teil-Map unter `"essen"`**, nicht die
///    ganzen Argumente von `zeige`. Die Felder von `ContentState`
///    (`mahlzeiten`, `ersteOffene`, `serie`, `serieAbMorgen`) stehen genau
///    dort; `fassung`, `frisch` und `verfaelltUm` gehören zum Aufruf, nicht
///    zur Karte.
/// 2. **Die prüfbare Form des Kanals** ist eine statische, asynchrone
///    Antwortfunktion nach dem Muster von `KeychainChannel.respond`:
///    ```swift
///    static func respond(to call: FlutterMethodCall,
///                        controller: LiveActivityController,
///                        links: LiveLinkBuffer) async -> Any?
///    ```
///    Sie liefert, was `result(...)` bekommt: `"gestartet"`,
///    `"aktualisiert"`, `"abgeschaltet"`, den Host-Teil eines Links,
///    `nil`, einen `FlutterError` oder `FlutterMethodNotImplemented`.
/// 3. **`LiveLinkBuffer` hat einen erreichbaren `init()`.** Die Tests legen
///    je Fall einen eigenen Puffer an, statt `shared` zu teilen — Swift
///    Testing läuft parallel, und ein geteilter Puffer machte die Fälle
///    voneinander abhängig.
/// 4. **`beendeAlle` antwortet `nil`.** Die Spec nennt keine Antwort.
/// 5. **Auch `frisch`, `verfaelltUm` und `essen` sind Pflicht.** Fehlt
///    einer, ist das ein `FlutterError` mit Code `argumente`, und der Host
///    wird nicht berührt. Ebenso `serieAbMorgen` und `mahlzeiten` in der
///    Karte, und ein `ersteOffene`, das da ist, aber kein Text, wirft: ein
///    falscher Typ wird nicht still zu `nil`.
/// 6. **Fünf Mahlzeiten werfen** wie drei — „immer vier".
/// 7. **Ein ignorierter Link verdrängt keinen wartenden.**
/// 8. Die Suiten laufen `@MainActor`. Der echte Kanal antwortet auf dem
///    Haupt-Thread, und so bleibt offen, ob die Implementierung den
///    Controller an den Haupt-Akteur bindet.
///
/// ## Absichtlich offen gelassen
///
/// - Ob doppelte Mahlzeiten oder eine andere Reihenfolge werfen. Das
///   garantiert der Kern (`essenKarte` wirft `ArgumentError`); hier zählt
///   nur „vier, bekannte Namen".
/// - Ob `kcal` als `NSNull` wirft oder `nil` wird. Die Dart-Seite schickt
///   ihn nie so („Fehlt ein Wert, fehlt der Schlüssel").
/// - Ob eine native Swift-`Int` statt `NSNumber` angenommen wird. Aus dem
///   Kanal kommt sie nie; die Argumente unten sind deshalb `NSNumber`, wie
///   der Standard-Codec sie liefert (`HealthChannelWeightTests.swift`).
///
/// ## Erfundene Zahlen
///
/// Jede Kalorienzahl, jede Serie und jeder Zeitpunkt hier ist ausgedacht
/// (`CLAUDE.md`: keine echten Gesundheitswerte im Quelltext). Die Karte ist
/// das Beispiel aus der Spec, Abschnitt „Dart → Swift".
@MainActor
@Suite("Live-Kanal: Kodierung der Karte")
struct LiveKodierungTests {

    @Test("Die vollständige Map aus der Spec wird zum erwarteten ContentState")
    func vollstaendigeMap() throws {
        let state = try EssenAttributes.ContentState(kanal: LiveTestDaten.essenMap())
        #expect(state == LiveTestDaten.erwarteterState)
    }

    @Test("kcal fehlt → nil, nie 0 (Review Focus 2)")
    func kcalFehltIstNil() throws {
        let state = try EssenAttributes.ContentState(kanal: LiveTestDaten.essenMap())

        let snack = try #require(state.mahlzeiten.first { $0.mahlzeit == "snack" })
        #expect(snack.kcal == nil)
        #expect(snack.kcal != 0)
        let abend = try #require(state.mahlzeiten.first { $0.mahlzeit == "abend" })
        #expect(abend.kcal == nil)
    }

    @Test("kcal fehlt bei einer Mahlzeit mit Eintrag → trotzdem nil, nicht 0")
    func kcalFehltAuchMitEintrag() throws {
        let map = LiveTestDaten.essenMap(mahlzeit: 0) { $0.removeValue(forKey: "kcal") }

        let state = try EssenAttributes.ContentState(kanal: map)

        #expect(state.mahlzeiten[0].mahlzeit == "fruehstueck")
        #expect(state.mahlzeiten[0].eintrag == true)
        #expect(state.mahlzeiten[0].kcal == nil)
    }

    @Test("kcal als Text → wirft")
    func kcalAlsTextWirft() {
        let map = LiveTestDaten.essenMap(mahlzeit: 0) { $0["kcal"] = "686" }
        #expect(throws: LiveArgumentError.self) {
            try EssenAttributes.ContentState(kanal: map)
        }
    }

    @Test("eintrag fehlt → wirft")
    func eintragFehltWirft() {
        let map = LiveTestDaten.essenMap(mahlzeit: 2) { $0.removeValue(forKey: "eintrag") }
        #expect(throws: LiveArgumentError.self) {
            try EssenAttributes.ContentState(kanal: map)
        }
    }

    @Test("drei statt vier Mahlzeiten → wirft")
    func dreiMahlzeitenWirft() {
        var map = LiveTestDaten.essenMap()
        map["mahlzeiten"] = Array(LiveTestDaten.mahlzeitenListe().prefix(3))
        #expect(throws: LiveArgumentError.self) {
            try EssenAttributes.ContentState(kanal: map)
        }
    }

    @Test("fünf statt vier Mahlzeiten → wirft (eigene Festlegung 6)")
    func fuenfMahlzeitenWirft() {
        var map = LiveTestDaten.essenMap()
        let liste = LiveTestDaten.mahlzeitenListe()
        map["mahlzeiten"] = liste + [liste[2]]
        #expect(throws: LiveArgumentError.self) {
            try EssenAttributes.ContentState(kanal: map)
        }
    }

    @Test("unbekannter mahlzeit-Name → wirft")
    func unbekannteMahlzeitWirft() {
        let map = LiveTestDaten.essenMap(mahlzeit: 2) { $0["mahlzeit"] = "mitternachtssnack" }
        #expect(throws: LiveArgumentError.self) {
            try EssenAttributes.ContentState(kanal: map)
        }
    }

    @Test("ersteOffene fehlt → nil, wenn keine Mahlzeit offen ist")
    func ersteOffeneFehltIstNil() throws {
        var map = LiveTestDaten.essenMap()
        map.removeValue(forKey: "ersteOffene")

        let state = try EssenAttributes.ContentState(kanal: map)

        #expect(state.ersteOffene == nil)
    }

    @Test("ersteOffene da, aber kein Text → wirft, wird nicht still nil (eigene Festlegung 5)")
    func ersteOffeneFalscherTypWirft() {
        var map = LiveTestDaten.essenMap()
        map["ersteOffene"] = NSNumber(value: 3)
        #expect(throws: LiveArgumentError.self) {
            try EssenAttributes.ContentState(kanal: map)
        }
    }

    @Test("serie fehlt → wirft")
    func serieFehltWirft() {
        var map = LiveTestDaten.essenMap()
        map.removeValue(forKey: "serie")
        #expect(throws: LiveArgumentError.self) {
            try EssenAttributes.ContentState(kanal: map)
        }
    }

    @Test("serieAbMorgen fehlt → wirft (eigene Festlegung 5)")
    func serieAbMorgenFehltWirft() {
        var map = LiveTestDaten.essenMap()
        map.removeValue(forKey: "serieAbMorgen")
        #expect(throws: LiveArgumentError.self) {
            try EssenAttributes.ContentState(kanal: map)
        }
    }

    @Test("mahlzeiten fehlt → wirft (eigene Festlegung 5)")
    func mahlzeitenFehltWirft() {
        var map = LiveTestDaten.essenMap()
        map.removeValue(forKey: "mahlzeiten")
        #expect(throws: LiveArgumentError.self) {
            try EssenAttributes.ContentState(kanal: map)
        }
    }

    @Test("Eine Serie von 0 bleibt 0 und ist kein Fehler")
    func serieNullIstGueltig() throws {
        var map = LiveTestDaten.essenMap()
        map["serie"] = NSNumber(value: 0)

        let state = try EssenAttributes.ContentState(kanal: map)

        #expect(state.serie == 0)
        #expect(state.serieAbMorgen == 0)
    }
}

@MainActor
@Suite("Live-Kanal: Link-Puffer")
struct LiveLinkBufferTests {

    @Test("repit://mahlzeit-eintragen → nimm() gibt den Host, ein zweites nimm() nil")
    func linkWirdEinmalAbgegeben() throws {
        let puffer = LiveLinkBuffer()

        puffer.nimmAn(try #require(URL(string: "repit://mahlzeit-eintragen")))

        #expect(puffer.nimm() == "mahlzeit-eintragen")
        #expect(puffer.nimm() == nil)
    }

    @Test("Ein leerer Puffer gibt nil")
    func leererPuffer() {
        #expect(LiveLinkBuffer().nimm() == nil)
    }

    @Test("https://… wird ignoriert")
    func fremdesSchemaWirdIgnoriert() throws {
        let puffer = LiveLinkBuffer()

        puffer.nimmAn(try #require(URL(string: "https://example.com/mahlzeit-eintragen")))

        #expect(puffer.nimm() == nil)
    }

    @Test("Ein ignorierter Link verdrängt keinen wartenden (eigene Festlegung 7)")
    func ignorierterLinkVerdraengtNicht() throws {
        let puffer = LiveLinkBuffer()

        puffer.nimmAn(try #require(URL(string: "repit://mahlzeit-eintragen")))
        puffer.nimmAn(try #require(URL(string: "https://example.com/anderes")))

        #expect(puffer.nimm() == "mahlzeit-eintragen")
    }

    @Test("Zwei Links vor dem Abholen → der spätere")
    func spaetererLinkGewinnt() throws {
        let puffer = LiveLinkBuffer()

        puffer.nimmAn(try #require(URL(string: "repit://erster-link")))
        puffer.nimmAn(try #require(URL(string: "repit://mahlzeit-eintragen")))

        #expect(puffer.nimm() == "mahlzeit-eintragen")
        #expect(puffer.nimm() == nil)
    }

    @Test("beiAnkunft wird je angenommenem Link einmal gerufen, für einen ignorierten nicht")
    func beiAnkunftJeAngenommenemLink() throws {
        let puffer = LiveLinkBuffer()
        var aufrufe = 0
        puffer.beiAnkunft = { aufrufe += 1 }

        puffer.nimmAn(try #require(URL(string: "repit://mahlzeit-eintragen")))
        #expect(aufrufe == 1)

        puffer.nimmAn(try #require(URL(string: "https://example.com/mahlzeit-eintragen")))
        #expect(aufrufe == 1)

        puffer.nimmAn(try #require(URL(string: "repit://mahlzeit-eintragen")))
        #expect(aufrufe == 2)
    }

    @Test("Abholen ruft beiAnkunft nicht")
    func abholenRuftNicht() throws {
        let puffer = LiveLinkBuffer()
        var aufrufe = 0
        puffer.nimmAn(try #require(URL(string: "repit://mahlzeit-eintragen")))
        puffer.beiAnkunft = { aufrufe += 1 }

        _ = puffer.nimm()

        #expect(aufrufe == 0)
    }
}

@MainActor
@Suite("Live-Kanal: Antwortfunktion")
struct LiveChannelRespondTests {

    @Test("Der Kanalname steht buchstabengleich wie in Spec und Plan")
    func kanalname() {
        #expect(LiveChannel.channelName == "de.rosenbach.repit/live")
    }

    @Test("Eine unbekannte Methode antwortet FlutterMethodNotImplemented")
    func unbekannteMethode() async {
        let host = AttrappeHost()
        let answer = await LiveChannel.respond(
            to: FlutterMethodCall(methodName: "gibtEsNicht", arguments: nil),
            controller: LiveActivityController(host: host),
            links: LiveLinkBuffer()
        )
        #expect((answer as? NSObject) === FlutterMethodNotImplemented)
        #expect(host.aufrufe.isEmpty)
    }

    @Test("zeige ohne fassung → FlutterError argumente, der Host bleibt unberührt")
    func zeigeOhneFassung() async {
        var args = LiveTestDaten.zeigeArgumente()
        args.removeValue(forKey: "fassung")
        await LiveTestDaten.erwarteArgumentFehler(args)
    }

    @Test("zeige mit einer anderen Fassung als essen → FlutterError argumente")
    func zeigeAndereFassung() async {
        var args = LiveTestDaten.zeigeArgumente()
        args["fassung"] = "kochen"
        await LiveTestDaten.erwarteArgumentFehler(args)
    }

    @Test("zeige ohne Argumente → FlutterError argumente")
    func zeigeOhneArgumente() async {
        let host = AttrappeHost()
        let answer = await LiveChannel.respond(
            to: FlutterMethodCall(methodName: "zeige", arguments: nil),
            controller: LiveActivityController(host: host),
            links: LiveLinkBuffer()
        )
        #expect((answer as? FlutterError)?.code == "argumente")
        #expect(host.aufrufe.isEmpty)
    }

    @Test("zeige ohne frisch → FlutterError argumente (eigene Festlegung 5)")
    func zeigeOhneFrisch() async {
        var args = LiveTestDaten.zeigeArgumente()
        args.removeValue(forKey: "frisch")
        await LiveTestDaten.erwarteArgumentFehler(args)
    }

    @Test("zeige ohne verfaelltUm → FlutterError argumente (eigene Festlegung 5)")
    func zeigeOhneVerfaelltUm() async {
        var args = LiveTestDaten.zeigeArgumente()
        args.removeValue(forKey: "verfaelltUm")
        await LiveTestDaten.erwarteArgumentFehler(args)
    }

    @Test("zeige ohne essen → FlutterError argumente (eigene Festlegung 5)")
    func zeigeOhneEssen() async {
        var args = LiveTestDaten.zeigeArgumente()
        args.removeValue(forKey: "essen")
        await LiveTestDaten.erwarteArgumentFehler(args)
    }

    @Test("zeige mit kcal als Text → FlutterError argumente, nicht still nil")
    func zeigeKcalAlsText() async {
        var args = LiveTestDaten.zeigeArgumente()
        args["essen"] = LiveTestDaten.essenMap(mahlzeit: 1) { $0["kcal"] = "813" }
        await LiveTestDaten.erwarteArgumentFehler(args)
    }

    @Test("zeige mit gültiger Map → \"gestartet\", der Host bekommt die kodierte Karte und verfaelltUm")
    func zeigeGueltig() async throws {
        let host = AttrappeHost()
        let answer = await LiveChannel.respond(
            to: FlutterMethodCall(methodName: "zeige", arguments: LiveTestDaten.zeigeArgumente()),
            controller: LiveActivityController(host: host),
            links: LiveLinkBuffer()
        )

        #expect(answer as? String == "gestartet")
        #expect(host.aufrufe == [
            .request(LiveTestDaten.erwarteterState, staleDate: LiveTestDaten.verfaelltUm),
        ])
    }

    @Test("Auf dem Weg durch den Kanal wird ein fehlender kcal-Wert nicht 0 (Review Focus 2)")
    func kcalBleibtFehlendBisZumHost() async throws {
        let host = AttrappeHost()
        _ = await LiveChannel.respond(
            to: FlutterMethodCall(methodName: "zeige", arguments: LiveTestDaten.zeigeArgumente()),
            controller: LiveActivityController(host: host),
            links: LiveLinkBuffer()
        )

        let erster: AttrappeHost.Aufruf = try #require(host.aufrufe.first)
        guard case let .request(state, staleDate: _) = erster else {
            Issue.record("erwartet war ein Request, nicht \(String(describing: host.aufrufe))")
            return
        }
        #expect(state.mahlzeiten[2].kcal == nil)
        #expect(state.mahlzeiten[3].kcal == nil)
    }

    @Test("zeige mit laufender aktiver Essen-Karte, frisch: false → \"aktualisiert\"")
    func zeigeAktualisiert() async {
        let host = AttrappeHost(laufende: [
            RunningActivity(id: "essen-1", fassung: "essen", istAktiv: true),
        ])
        var args = LiveTestDaten.zeigeArgumente()
        args["frisch"] = NSNumber(value: false)

        let answer = await LiveChannel.respond(
            to: FlutterMethodCall(methodName: "zeige", arguments: args),
            controller: LiveActivityController(host: host),
            links: LiveLinkBuffer()
        )

        #expect(answer as? String == "aktualisiert")
    }

    @Test("zeige bei abgeschalteten Live-Aktivitäten → \"abgeschaltet\" (V7)")
    func zeigeAbgeschaltet() async {
        let host = AttrappeHost(enabled: false)
        let answer = await LiveChannel.respond(
            to: FlutterMethodCall(methodName: "zeige", arguments: LiveTestDaten.zeigeArgumente()),
            controller: LiveActivityController(host: host),
            links: LiveLinkBuffer()
        )
        #expect(answer as? String == "abgeschaltet")
        #expect(host.aufrufe.isEmpty)
    }

    @Test("ActivityKit-Fehler → FlutterError mit Code live und der localizedDescription als message")
    func activityKitFehler() async throws {
        let host = AttrappeHost()
        host.requestFehler = ErfundenerActivityKitFehler()

        let answer = await LiveChannel.respond(
            to: FlutterMethodCall(methodName: "zeige", arguments: LiveTestDaten.zeigeArgumente()),
            controller: LiveActivityController(host: host),
            links: LiveLinkBuffer()
        )

        let error = try #require(answer as? FlutterError)
        #expect(error.code == "live")
        #expect(error.message == ErfundenerActivityKitFehler().localizedDescription)
    }

    @Test("nimmLink → der Host-Teil, danach nil")
    func nimmLinkGibtHostEinmal() async throws {
        let links = LiveLinkBuffer()
        let controller = LiveActivityController(host: AttrappeHost())
        links.nimmAn(try #require(URL(string: "repit://mahlzeit-eintragen")))

        let erste = await LiveChannel.respond(
            to: FlutterMethodCall(methodName: "nimmLink", arguments: nil),
            controller: controller, links: links
        )
        let zweite = await LiveChannel.respond(
            to: FlutterMethodCall(methodName: "nimmLink", arguments: nil),
            controller: controller, links: links
        )

        #expect(erste as? String == "mahlzeit-eintragen")
        #expect(zweite == nil)
    }

    @Test("nimmLink ohne wartenden Link → nil, kein Fehler")
    func nimmLinkLeer() async {
        let answer = await LiveChannel.respond(
            to: FlutterMethodCall(methodName: "nimmLink", arguments: nil),
            controller: LiveActivityController(host: AttrappeHost()),
            links: LiveLinkBuffer()
        )
        #expect(answer == nil)
    }

    @Test("beendeAlle beendet jede Aktivität und antwortet nil (eigene Festlegung 4)")
    func beendeAlleUeberDenKanal() async {
        let host = AttrappeHost(laufende: [
            RunningActivity(id: "essen-1", fassung: "essen", istAktiv: true),
            RunningActivity(id: "kochen-1", fassung: "kochen", istAktiv: true),
        ])

        let answer = await LiveChannel.respond(
            to: FlutterMethodCall(methodName: "beendeAlle", arguments: nil),
            controller: LiveActivityController(host: host),
            links: LiveLinkBuffer()
        )

        #expect(answer == nil)
        #expect(Set(host.beendet) == ["essen-1", "kochen-1"])
        #expect(host.laufende.isEmpty)
    }
}

/// Erfundene Kanaldaten — das Beispiel aus der Spec, Abschnitt „Dart → Swift".
/// Zahlen als `NSNumber`, wie der Standard-Codec von Flutter sie liefert.
enum LiveTestDaten {

    /// Millisekunden seit 1970, UTC — das erfundene `verfaelltUm` der Spec.
    static let verfaelltUmMillis: Int64 = 1_700_000_000_000
    static let verfaelltUm = Date(timeIntervalSince1970: 1_700_000_000)

    static func mahlzeitenListe() -> [[String: Any]] {
        [
            ["mahlzeit": "fruehstueck", "eintrag": NSNumber(value: true), "kcal": NSNumber(value: 686)],
            ["mahlzeit": "mittag", "eintrag": NSNumber(value: true), "kcal": NSNumber(value: 813)],
            ["mahlzeit": "snack", "eintrag": NSNumber(value: false)],
            ["mahlzeit": "abend", "eintrag": NSNumber(value: false)],
        ]
    }

    /// Die Teil-Map unter `"essen"`. Mit `mahlzeit:` und `aendern:` lässt
    /// sich genau ein Eintrag der Liste verändern.
    static func essenMap(
        mahlzeit index: Int? = nil,
        aendern: (inout [String: Any]) -> Void = { _ in }
    ) -> [String: Any] {
        var liste = mahlzeitenListe()
        if let index { aendern(&liste[index]) }
        return [
            "mahlzeiten": liste,
            "ersteOffene": "abend",
            "serie": NSNumber(value: 10),
            "serieAbMorgen": NSNumber(value: 0),
        ]
    }

    static func zeigeArgumente() -> [String: Any] {
        [
            "fassung": "essen",
            "frisch": NSNumber(value: true),
            "verfaelltUm": NSNumber(value: verfaelltUmMillis),
            "essen": essenMap(),
        ]
    }

    static let erwarteterState = EssenAttributes.ContentState(
        mahlzeiten: [
            .init(mahlzeit: "fruehstueck", eintrag: true, kcal: 686),
            .init(mahlzeit: "mittag", eintrag: true, kcal: 813),
            .init(mahlzeit: "snack", eintrag: false, kcal: nil),
            .init(mahlzeit: "abend", eintrag: false, kcal: nil),
        ],
        ersteOffene: "abend",
        serie: 10,
        serieAbMorgen: 0
    )

    /// `zeige` mit diesen Argumenten antwortet `FlutterError(code: "argumente")`
    /// und ruft den Host nicht — weder Request noch Update noch End.
    @MainActor
    static func erwarteArgumentFehler(
        _ args: [String: Any],
        sourceLocation: SourceLocation = #_sourceLocation
    ) async {
        let host = AttrappeHost(laufende: [
            RunningActivity(id: "essen-1", fassung: "essen", istAktiv: true),
        ])
        let answer = await LiveChannel.respond(
            to: FlutterMethodCall(methodName: "zeige", arguments: args),
            controller: LiveActivityController(host: host),
            links: LiveLinkBuffer()
        )
        #expect((answer as? FlutterError)?.code == "argumente", sourceLocation: sourceLocation)
        #expect(host.aufrufe.isEmpty, sourceLocation: sourceLocation)
    }
}
