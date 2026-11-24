import Foundation
import Testing
@testable import Runner

/// Die Steuerung der Live-Aktivität auf der Swift-Seite (#366, #276):
/// `LiveActivityController.zeige` und `beendeAlle` gegen eine Attrappe von
/// `LiveActivityHost`.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, nie verändert werden. Hält der
/// Implementierende eine Erwartung hier für falsch, wird das **gemeldet**,
/// nicht korrigiert.
///
/// Swift Testing, nicht XCTest.
///
/// Grundlage: `docs/superpowers/specs/2026-11-05-live-aktivitaet-design.md`,
/// Abschnitt „Was die Swift-Seite tut" (Schritte 1–5), und
/// `docs/superpowers/plans/2026-11-05-live-aktivitaet.md`, Task 4.
///
/// Die Swift-Seite **entscheidet keine Fassung**. Sie stellt sicher, dass
/// nach `zeige` genau eine Aktivität der App existiert, und zwar die
/// verlangte:
///
/// 1. Live-Aktivitäten abgeschaltet → `.abgeschaltet`, sonst nichts.
/// 2. Jede Aktivität einer anderen Fassung wird beendet.
/// 3. Mehr als eine dieser Fassung → alle beendet (Absturzreste, #134).
/// 4. `frisch == false` und genau eine dieser Fassung aktiv → Update,
///    `.aktualisiert`.
/// 5. Sonst: beenden, was von dieser Fassung steht, dann Request,
///    `.gestartet`.
///
/// ## Erwartete API (aus dem Plan, Task 4, „Interfaces")
///
/// ```swift
/// struct RunningActivity: Equatable {
///     let id: String
///     let fassung: String
///     let istAktiv: Bool
/// }
/// protocol LiveActivityHost {
///     var enabled: Bool { get }
///     func running() -> [RunningActivity]
///     func requestEssen(_ state: EssenAttributes.ContentState, staleDate: Date) throws
///     func updateEssen(id: String, _ state: EssenAttributes.ContentState, staleDate: Date) async
///     func end(id: String) async
/// }
/// final class LiveActivityController {
///     init(host: LiveActivityHost)
///     enum Ergebnis: String { case gestartet, aktualisiert, abgeschaltet }
///     func zeige(fassung: String, frisch: Bool,
///                state: EssenAttributes.ContentState, staleDate: Date) async throws -> Ergebnis
///     func beendeAlle() async
/// }
/// ```
///
/// `RunningActivity` wird über seinen memberweisen Initialisierer gebaut
/// (`RunningActivity(id:fassung:istAktiv:)`).
///
/// ## Eigene Festlegungen dieses Test-Agenten — nicht von Tim freigegeben
///
/// 1. **Ein Fehler des Requests kommt unverändert aus `zeige` heraus.** Die
///    Spec verlangt auf dem Kanal `FlutterError(code: "live", message:
///    <localizedDescription>)`; das trägt nur, wenn `zeige` den Fehler des
///    Hosts nicht einwickelt.
/// 2. **Die Reihenfolge der Beendigungen untereinander ist frei.** Geprüft
///    wird nur, dass jede vor dem Request liegt.
/// 3. **Eine andere Fassung neben genau einer aktiven Essen-Karte,
///    `frisch: false`:** Die andere wird beendet, die Essen-Karte
///    aktualisiert, nicht neu gestartet. Das folgt aus den Schritten 2 und
///    4 der Spec; der Plan nennt den Fall nicht eigens.
/// 4. Die Suite läuft `@MainActor`, aus demselben Grund wie in
///    `LiveChannelTests.swift`.
///
/// ## Erfundene Zahlen
///
/// Karte und Zeitpunkt sind ausgedacht (`LiveTestDaten` in
/// `LiveChannelTests.swift`).
@MainActor
@Suite("Live-Steuerung: zeige und beendeAlle")
struct LiveActivityControllerTests {

    private let state = LiveTestDaten.erwarteterState
    private let stale = Date(timeIntervalSince1970: 1_700_000_000)

    private static func aktiv(_ id: String, _ fassung: String = "essen") -> RunningActivity {
        RunningActivity(id: id, fassung: fassung, istAktiv: true)
    }

    // MARK: - Schritt 1: abgeschaltet

    @Test("enabled == false → .abgeschaltet, kein Request, kein Update, kein End")
    func abgeschaltet() async throws {
        let host = AttrappeHost(enabled: false, laufende: [
            Self.aktiv("essen-1"),
            Self.aktiv("kochen-1", "kochen"),
        ])
        let controller = LiveActivityController(host: host)

        let ergebnis = try await controller.zeige(fassung: "essen", frisch: false,
                                                  state: state, staleDate: stale)

        #expect(ergebnis == .abgeschaltet)
        #expect(host.aufrufe.isEmpty)
        #expect(host.laufende.count == 2)
    }

    // MARK: - Schritt 5: Start

    @Test("Keine laufende, frisch: false → ein Request mit Karte und staleDate, .gestartet")
    func keineLaufendeStartet() async throws {
        let host = AttrappeHost()
        let controller = LiveActivityController(host: host)

        let ergebnis = try await controller.zeige(fassung: "essen", frisch: false,
                                                  state: state, staleDate: stale)

        #expect(ergebnis == .gestartet)
        #expect(host.aufrufe == [.request(state, staleDate: stale)])
        #expect(host.laufende.count == 1)
    }

    @Test("Keine laufende, frisch: true → ebenso ein Request, .gestartet")
    func keineLaufendeFrischStartet() async throws {
        let host = AttrappeHost()
        let controller = LiveActivityController(host: host)

        let ergebnis = try await controller.zeige(fassung: "essen", frisch: true,
                                                  state: state, staleDate: stale)

        #expect(ergebnis == .gestartet)
        #expect(host.aufrufe == [.request(state, staleDate: stale)])
    }

    // MARK: - Schritt 4: Update

    @Test("Eine aktive Essen-Aktivität, frisch: false → ein Update, kein Request, .aktualisiert")
    func eineAktiveWirdAktualisiert() async throws {
        let host = AttrappeHost(laufende: [Self.aktiv("essen-1")])
        let controller = LiveActivityController(host: host)

        let ergebnis = try await controller.zeige(fassung: "essen", frisch: false,
                                                  state: state, staleDate: stale)

        #expect(ergebnis == .aktualisiert)
        #expect(host.aufrufe == [.update(id: "essen-1", state, staleDate: stale)])
        #expect(host.laufende == [Self.aktiv("essen-1")])
    }

    // MARK: - Neustart

    @Test("Eine aktive Essen-Aktivität, frisch: true → End, dann Request, .gestartet")
    func frischStartetNeu() async throws {
        let host = AttrappeHost(laufende: [Self.aktiv("essen-1")])
        let controller = LiveActivityController(host: host)

        let ergebnis = try await controller.zeige(fassung: "essen", frisch: true,
                                                  state: state, staleDate: stale)

        #expect(ergebnis == .gestartet)
        #expect(host.aufrufe == [
            .end(id: "essen-1"),
            .request(state, staleDate: stale),
        ])
        #expect(host.laufende.count == 1)
        #expect(host.laufende.first?.id != "essen-1")
    }

    @Test("Eine veraltete Essen-Aktivität (istAktiv: false), frisch: false → End, dann Request")
    func veralteteWirdNeuGestartet() async throws {
        let host = AttrappeHost(laufende: [
            RunningActivity(id: "essen-alt", fassung: "essen", istAktiv: false),
        ])
        let controller = LiveActivityController(host: host)

        let ergebnis = try await controller.zeige(fassung: "essen", frisch: false,
                                                  state: state, staleDate: stale)

        #expect(ergebnis == .gestartet)
        #expect(host.aufrufe == [
            .end(id: "essen-alt"),
            .request(state, staleDate: stale),
        ])
    }

    // MARK: - Schritt 3: Dubletten (Review Focus 3)

    @Test("Zwei Essen-Aktivitäten → beide beendet, eine neue gestartet, danach genau eine")
    func zweiEssenWerdenZuEiner() async throws {
        let host = AttrappeHost(laufende: [Self.aktiv("essen-1"), Self.aktiv("essen-2")])
        let controller = LiveActivityController(host: host)

        let ergebnis = try await controller.zeige(fassung: "essen", frisch: false,
                                                  state: state, staleDate: stale)

        #expect(ergebnis == .gestartet)
        #expect(host.updates.isEmpty, "zwei derselben Fassung werden nicht aktualisiert")
        #expect(Set(host.beendet) == ["essen-1", "essen-2"])
        #expect(host.beendet.count == 2)
        #expect(host.aufrufe.last == .request(state, staleDate: stale))
        #expect(host.requests == 1)
        #expect(host.endenVorDemRequest)

        #expect(host.running().count == 1)
        #expect(host.running().first?.fassung == "essen")
        #expect(!["essen-1", "essen-2"].contains(host.running().first?.id ?? ""))
    }

    // MARK: - Schritt 2: andere Fassung

    @Test("Eine Aktivität der Fassung kochen → beendet, bevor die Essen-Aktivität kommt")
    func andereFassungWirdBeendet() async throws {
        let host = AttrappeHost(laufende: [Self.aktiv("kochen-1", "kochen")])
        let controller = LiveActivityController(host: host)

        let ergebnis = try await controller.zeige(fassung: "essen", frisch: false,
                                                  state: state, staleDate: stale)

        #expect(ergebnis == .gestartet)
        #expect(host.aufrufe == [
            .end(id: "kochen-1"),
            .request(state, staleDate: stale),
        ])
        #expect(host.running().map(\.fassung) == ["essen"])
    }

    @Test("kochen neben einer aktiven Essen-Karte, frisch: false → kochen beendet, Essen aktualisiert (eigene Festlegung 3)")
    func andereFassungNebenAktiverEssenKarte() async throws {
        let host = AttrappeHost(laufende: [
            Self.aktiv("kochen-1", "kochen"),
            Self.aktiv("essen-1"),
        ])
        let controller = LiveActivityController(host: host)

        let ergebnis = try await controller.zeige(fassung: "essen", frisch: false,
                                                  state: state, staleDate: stale)

        #expect(ergebnis == .aktualisiert)
        #expect(host.aufrufe == [
            .end(id: "kochen-1"),
            .update(id: "essen-1", state, staleDate: stale),
        ])
        #expect(host.running() == [Self.aktiv("essen-1")])
    }

    // MARK: - Fehler

    @Test("Der Request wirft → zeige wirft, und beendet ist trotzdem, was beendet werden sollte")
    func requestWirft() async {
        let host = AttrappeHost(laufende: [
            Self.aktiv("kochen-1", "kochen"),
            Self.aktiv("essen-1"),
        ])
        host.requestFehler = ErfundenerActivityKitFehler()
        let controller = LiveActivityController(host: host)

        await #expect(throws: ErfundenerActivityKitFehler.self) {
            _ = try await controller.zeige(fassung: "essen", frisch: true,
                                           state: state, staleDate: stale)
        }

        #expect(Set(host.beendet) == ["kochen-1", "essen-1"])
        #expect(host.running().isEmpty)
        #expect(host.updates.isEmpty)
    }

    // MARK: - beendeAlle

    @Test("beendeAlle beendet jede Aktivität, gleich welcher Fassung und welchen Zustands")
    func beendeAlleBeendetJede() async {
        let host = AttrappeHost(laufende: [
            Self.aktiv("essen-1"),
            RunningActivity(id: "essen-alt", fassung: "essen", istAktiv: false),
            Self.aktiv("kochen-1", "kochen"),
        ])
        let controller = LiveActivityController(host: host)

        await controller.beendeAlle()

        #expect(Set(host.beendet) == ["essen-1", "essen-alt", "kochen-1"])
        #expect(host.beendet.count == 3)
        #expect(host.requests == 0)
        #expect(host.updates.isEmpty)
        #expect(host.running().isEmpty)
    }

    @Test("beendeAlle ohne laufende Aktivität ruft nichts")
    func beendeAlleOhneLaufende() async {
        let host = AttrappeHost()
        let controller = LiveActivityController(host: host)

        await controller.beendeAlle()

        #expect(host.aufrufe.isEmpty)
    }
}

/// Ein erfundener Fehler an Stelle dessen, was `Activity.request` wirft.
struct ErfundenerActivityKitFehler: LocalizedError, Equatable {
    var errorDescription: String? { "Erfundener ActivityKit-Fehler für den Test" }
}

/// Attrappe für `LiveActivityHost`. Protokolliert jeden Aufruf in
/// Reihenfolge und führt die Liste der laufenden Aktivitäten so nach, wie
/// ActivityKit es täte: `end` nimmt eine heraus, ein erfolgreicher Request
/// legt eine neue, aktive Essen-Aktivität dazu.
final class AttrappeHost: LiveActivityHost {

    enum Aufruf: Equatable {
        case request(EssenAttributes.ContentState, staleDate: Date)
        case update(id: String, EssenAttributes.ContentState, staleDate: Date)
        case end(id: String)
    }

    var enabled: Bool
    var laufende: [RunningActivity]
    var requestFehler: Error?
    private(set) var aufrufe: [Aufruf] = []
    private var naechsteNummer = 0

    init(enabled: Bool = true, laufende: [RunningActivity] = []) {
        self.enabled = enabled
        self.laufende = laufende
    }

    func running() -> [RunningActivity] { laufende }

    func requestEssen(_ state: EssenAttributes.ContentState, staleDate: Date) throws {
        aufrufe.append(.request(state, staleDate: staleDate))
        if let requestFehler { throw requestFehler }
        naechsteNummer += 1
        laufende.append(RunningActivity(id: "neu-\(naechsteNummer)", fassung: "essen",
                                        istAktiv: true))
    }

    func updateEssen(id: String, _ state: EssenAttributes.ContentState, staleDate: Date) async {
        aufrufe.append(.update(id: id, state, staleDate: staleDate))
    }

    func end(id: String) async {
        aufrufe.append(.end(id: id))
        laufende.removeAll { $0.id == id }
    }

    // MARK: - Auswertung

    var beendet: [String] {
        aufrufe.compactMap { aufruf -> String? in
            guard case let .end(id) = aufruf else { return nil }
            return id
        }
    }

    var updates: [String] {
        aufrufe.compactMap { aufruf -> String? in
            guard case let .update(id, _, _) = aufruf else { return nil }
            return id
        }
    }

    private static func istRequest(_ aufruf: Aufruf) -> Bool {
        guard case .request = aufruf else { return false }
        return true
    }

    var requests: Int {
        aufrufe.filter(Self.istRequest).count
    }

    /// Jedes `end` liegt vor dem ersten `request`.
    var endenVorDemRequest: Bool {
        guard let ersterRequest = aufrufe.firstIndex(where: Self.istRequest) else { return true }
        return !aufrufe[ersterRequest...].contains { aufruf in
            guard case .end = aufruf else { return false }
            return true
        }
    }
}
