import Flutter
import Foundation
import Testing
@testable import Runner

/// Der Anteil je Mahlzeit auf der Swift-Seite des Live-Kanals (#436, #374).
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, nie verändert werden. Hält der
/// Implementierende eine Erwartung hier für falsch, wird das **gemeldet**,
/// nicht korrigiert.
///
/// Swift Testing, nicht XCTest. Jeder `@Test`-Name ist ein echtes Literal.
///
/// Grundlage: `docs/superpowers/specs/2026-11-10-mahlzeiten-aufteilung-design.md`
/// (V15, Abschnitt „Live-Aktivität: Ringe als Anteil, ersetzt V2") und
/// `docs/superpowers/plans/2026-11-10-mahlzeiten-aufteilung.md` (Task 7,
/// Step 1). Die Dart-Seite schickt `anteil` als `double`, nur bei einer
/// Mahlzeit mit Eintrag und Ziel (`app/lib/live/live_types.dart`).
///
/// ## Erwartete API (aus dem Plan, Task 7, „Interfaces")
///
/// ```swift
/// struct EssenAttributes.ContentState.Mahlzeit {
///     let anteil: Double?
/// }
/// ```
///
/// Die Fälle prüfen das Feld über `state.mahlzeiten[i].anteil`, nicht über
/// einen bestimmten Initialisierer. Wie die Implementierung die Aufrufe
/// mit drei Argumenten in `LiveChannelTests.swift` gültig hält, bleibt ihr
/// überlassen; die Datei bleibt unberührt.
///
/// ## Eigene Festlegungen dieses Test-Agenten — nicht von Tim freigegeben
///
/// Plan und Spec nennen sie nicht ausdrücklich. Jede ist zum Gegenlesen
/// offen.
///
/// 1. **Ein Anteil von genau `0` bei Eintrag bleibt `0`**, wird nicht
///    `nil`. Die Dart-Seite schickt ihn so (`live_types.dart`: „Ein Anteil
///    von genau `0` bei Eintrag geht als `0` mit"), und `nil` hieße auf der
///    Karte V2, also ein voller Ring.
/// 2. **Ein Wahrheitswert ist kein Anteil**, wie bei `kcal`: `true` wirft.
/// 3. **Der Anteil übersteht das JSON-Kodieren** von `ContentState`, so wie
///    ActivityKit den Zustand ablegt.
///
/// ## Absichtlich offen gelassen
///
/// - Ob ein ganzzahliges `NSNumber` (`1` statt `1.0`) angenommen wird. Die
///   Dart-Seite schickt immer `double`, der Standard-Codec liefert dafür
///   ein Float64-`NSNumber`.
/// - Ob `anteil` als `NSNull` wirft oder `nil` wird — wie bei `kcal`.
/// - Ob ein Anteil über `3,0` oder unter `0` wirft. Die Deckelung steht im
///   Kern (V6).
///
/// ## Erfundene Zahlen
///
/// Jede Zahl hier ist ausgedacht (`CLAUDE.md`). `1.14` ist das Beispiel der
/// Spec, Abschnitt „Die Nutzlast (V15)". Die übrigen Werte stammen aus
/// `LiveTestDaten` in `LiveChannelTests.swift`.
@MainActor
@Suite("Live-Kanal: Anteil je Mahlzeit")
struct LiveAnteilTests {

    @Test("anteil 1.14 in der Map → ContentState trägt 1.14")
    func anteilWirdUebernommen() throws {
        let map = LiveTestDaten.essenMap(mahlzeit: 0) { $0["anteil"] = NSNumber(value: 1.14) }

        let state = try EssenAttributes.ContentState(kanal: map)

        #expect(state.mahlzeiten[0].mahlzeit == "fruehstueck")
        #expect(state.mahlzeiten[0].anteil == 1.14)
        #expect(state.mahlzeiten[0].kcal == 686)
        #expect(state.mahlzeiten[0].eintrag == true)
    }

    @Test("anteil nur bei einer Mahlzeit → die übrigen bleiben nil")
    func anteilNurBeiEinerMahlzeit() throws {
        let map = LiveTestDaten.essenMap(mahlzeit: 1) { $0["anteil"] = NSNumber(value: 0.62) }

        let state = try EssenAttributes.ContentState(kanal: map)

        #expect(state.mahlzeiten[0].anteil == nil)
        #expect(state.mahlzeiten[1].anteil == 0.62)
        #expect(state.mahlzeiten[2].anteil == nil)
        #expect(state.mahlzeiten[3].anteil == nil)
    }

    @Test("Map ohne anteil → nil, nie 0")
    func ohneAnteilIstNil() throws {
        let state = try EssenAttributes.ContentState(kanal: LiveTestDaten.essenMap())

        for mahlzeit in state.mahlzeiten {
            #expect(mahlzeit.anteil == nil)
            #expect(mahlzeit.anteil != 0)
        }
    }

    @Test("Map ohne anteil → derselbe ContentState wie vor #374")
    func ohneAnteilWieBisher() throws {
        let state = try EssenAttributes.ContentState(kanal: LiveTestDaten.essenMap())
        #expect(state == LiveTestDaten.erwarteterState)
    }

    @Test("anteil 0 bei Eintrag → 0, nicht nil (eigene Festlegung 1)")
    func anteilNullBleibtNull() throws {
        let map = LiveTestDaten.essenMap(mahlzeit: 0) { $0["anteil"] = NSNumber(value: 0.0) }

        let state = try EssenAttributes.ContentState(kanal: map)

        #expect(state.mahlzeiten[0].anteil == 0)
        #expect(state.mahlzeiten[0].anteil != nil)
    }

    @Test("anteil als Text → wirft")
    func anteilAlsTextWirft() {
        let map = LiveTestDaten.essenMap(mahlzeit: 0) { $0["anteil"] = "1.14" }
        #expect(throws: LiveArgumentError.self) {
            try EssenAttributes.ContentState(kanal: map)
        }
    }

    @Test("anteil als Wahrheitswert → wirft (eigene Festlegung 2)")
    func anteilAlsWahrheitswertWirft() {
        let map = LiveTestDaten.essenMap(mahlzeit: 0) { $0["anteil"] = NSNumber(value: true) }
        #expect(throws: LiveArgumentError.self) {
            try EssenAttributes.ContentState(kanal: map)
        }
    }

    @Test("zeige mit anteil als Text → FlutterError argumente, Host unberührt")
    func zeigeAnteilAlsTextIstArgumentFehler() async {
        var args = LiveTestDaten.zeigeArgumente()
        args["essen"] = LiveTestDaten.essenMap(mahlzeit: 0) { $0["anteil"] = "1.14" }

        await LiveTestDaten.erwarteArgumentFehler(args)
    }

    @Test("zeige mit anteil 1.14 → der Host bekommt den Anteil")
    func zeigeReichtAnteilDurch() async throws {
        var args = LiveTestDaten.zeigeArgumente()
        args["essen"] = LiveTestDaten.essenMap(mahlzeit: 0) { $0["anteil"] = NSNumber(value: 1.14) }
        let host = AttrappeHost()

        let answer = await LiveChannel.respond(
            to: FlutterMethodCall(methodName: "zeige", arguments: args),
            controller: LiveActivityController(host: host),
            links: LiveLinkBuffer()
        )

        #expect(answer as? String == "gestartet")
        let aufruf = try #require(host.aufrufe.first)
        guard case let .request(state, _) = aufruf else {
            Issue.record("Erwartet war ein Request, gekommen ist \(aufruf)")
            return
        }
        #expect(state.mahlzeiten[0].anteil == 1.14)
        #expect(state.mahlzeiten[1].anteil == nil)
    }
}

@Suite("Live-Kanal: gespeicherter Zustand mit und ohne Anteil")
struct LiveAnteilKodierungTests {

    /// Ein `ContentState`, wie ihn ActivityKit vor #374 abgelegt hat: ohne
    /// den Schlüssel `anteil`. Erfundene Zahlen, dieselben wie
    /// `LiveTestDaten.erwarteterState`.
    static let jsonVor374 = """
    {
      "mahlzeiten": [
        { "mahlzeit": "fruehstueck", "eintrag": true, "kcal": 686 },
        { "mahlzeit": "mittag", "eintrag": true, "kcal": 813 },
        { "mahlzeit": "snack", "eintrag": false },
        { "mahlzeit": "abend", "eintrag": false }
      ],
      "ersteOffene": "abend",
      "serie": 10,
      "serieAbMorgen": 0
    }
    """

    @Test("Ein ContentState ohne anteil (Stand vor #374) dekodiert")
    func alterZustandDekodiert() throws {
        let daten = try #require(Self.jsonVor374.data(using: .utf8))

        let state = try JSONDecoder().decode(EssenAttributes.ContentState.self, from: daten)

        #expect(state.mahlzeiten.count == 4)
        for mahlzeit in state.mahlzeiten {
            #expect(mahlzeit.anteil == nil)
        }
        #expect(state.mahlzeiten[0].kcal == 686)
        #expect(state.ersteOffene == "abend")
        #expect(state.serie == 10)
        #expect(state.serieAbMorgen == 0)
    }

    @Test("Ein ContentState ohne anteil dekodiert gleich dem aus der Kanal-Map")
    @MainActor
    func alterZustandGleichKanal() throws {
        let daten = try #require(Self.jsonVor374.data(using: .utf8))

        let state = try JSONDecoder().decode(EssenAttributes.ContentState.self, from: daten)

        #expect(state == LiveTestDaten.erwarteterState)
    }

    @Test("anteil übersteht Kodieren und Dekodieren (eigene Festlegung 3)")
    @MainActor
    func anteilUeberstehtJSON() throws {
        let map = LiveTestDaten.essenMap(mahlzeit: 0) { $0["anteil"] = NSNumber(value: 1.14) }
        let state = try EssenAttributes.ContentState(kanal: map)

        let daten = try JSONEncoder().encode(state)
        let zurueck = try JSONDecoder().decode(EssenAttributes.ContentState.self, from: daten)

        #expect(zurueck == state)
        #expect(zurueck.mahlzeiten[0].anteil == 1.14)
        #expect(zurueck.mahlzeiten[1].anteil == nil)
    }
}
