import ActivityKit
import Foundation

/// Eine laufende Live-Aktivität der App, so weit die Steuerung sie kennen
/// muss (#366).
struct RunningActivity: Equatable {
    let id: String
    /// Die Fassung, die die Aktivität zeigt — heute nur `"essen"`.
    let fassung: String
    /// `activityState == .active`. Eine veraltete (`.stale`) ist es nicht.
    let istAktiv: Bool
}

/// Die ActivityKit-Aufrufe hinter einem Protokoll, damit die Schritte von
/// `LiveActivityController.zeige` gegen eine Attrappe prüfbar sind
/// (`LiveActivityControllerTests.swift`). Die echte Fassung ist
/// `ActivityKitHost`.
protocol LiveActivityHost {
    /// `ActivityAuthorizationInfo().areActivitiesEnabled`.
    var enabled: Bool { get }
    func running() -> [RunningActivity]
    func requestEssen(_ state: EssenAttributes.ContentState, staleDate: Date) throws
    func updateEssen(id: String, _ state: EssenAttributes.ContentState, staleDate: Date) async
    /// Beendet sofort (`.immediate`).
    func end(id: String) async
}

/// Stellt sicher, dass nach `zeige` **genau eine** Aktivität der App
/// existiert, und zwar die verlangte (Spec, „Was die Swift-Seite tut").
///
/// Sie entscheidet keine Fassung — das tut `waehleFassung` im Kern. Sie
/// räumt nur auf: andere Fassungen, Dubletten nach einem Absturz (#134),
/// veraltete Karten.
///
/// Zwei Aufrufe dürfen sich nicht überlappen, sonst sähen beide „keine
/// läuft" und starteten je eine. Das Hintereinander besorgt `LiveChannel`.
@MainActor
final class LiveActivityController {

    enum Ergebnis: String {
        case gestartet, aktualisiert, abgeschaltet
    }

    /// Die einzige Fassung, für die es einen Request gibt.
    nonisolated static let essen = "essen"

    private let host: LiveActivityHost

    init(host: LiveActivityHost) {
        self.host = host
    }

    /// Schritte 1–5 der Spec. Ein Fehler des Requests kommt unverändert
    /// heraus; was vorher beendet wurde, bleibt beendet.
    func zeige(
        fassung: String,
        frisch: Bool,
        state: EssenAttributes.ContentState,
        staleDate: Date
    ) async throws -> Ergebnis {
        guard fassung == Self.essen else {
            throw LiveArgumentError("unbekannte Fassung \(fassung)")
        }

        // 1. Abgeschaltet: nichts anfassen.
        guard host.enabled else { return .abgeschaltet }

        let laufende = host.running()

        // 2. Jede andere Fassung muss weg.
        for fremde in laufende where fremde.fassung != fassung {
            await host.end(id: fremde.id)
        }

        let eigene = laufende.filter { $0.fassung == fassung }

        // 4. Genau eine, aktiv, kein Neustart verlangt → Update.
        if !frisch, eigene.count == 1, let einzige = eigene.first, einzige.istAktiv {
            await host.updateEssen(id: einzige.id, state, staleDate: staleDate)
            return .aktualisiert
        }

        // 3. und 5. Dubletten, veraltete oder ein verlangter Neustart:
        // alles dieser Fassung beenden, dann eine neue.
        for alte in eigene {
            await host.end(id: alte.id)
        }
        try host.requestEssen(state, staleDate: staleDate)
        return .gestartet
    }

    /// Beendet jede Aktivität der App, gleich welcher Fassung und welchen
    /// Zustands. Kommt, wenn `waehleFassung` keine Fassung liefert.
    func beendeAlle() async {
        for aktivitaet in host.running() {
            await host.end(id: aktivitaet.id)
        }
    }
}

/// Die echte Fassung über `Activity<EssenAttributes>`. Dünn und ungetestet;
/// alles, was entscheidet, steht in `LiveActivityController`.
///
/// Kein Push (`pushType: nil`), keine App Group (`CLAUDE.md`).
final class ActivityKitHost: LiveActivityHost {

    var enabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    func running() -> [RunningActivity] {
        Activity<EssenAttributes>.activities.map { aktivitaet in
            RunningActivity(
                id: aktivitaet.id,
                fassung: LiveActivityController.essen,
                istAktiv: aktivitaet.activityState == .active
            )
        }
    }

    func requestEssen(_ state: EssenAttributes.ContentState, staleDate: Date) throws {
        _ = try Activity<EssenAttributes>.request(
            attributes: EssenAttributes(),
            content: ActivityContent(state: state, staleDate: staleDate),
            pushType: nil
        )
    }

    func updateEssen(id: String, _ state: EssenAttributes.ContentState, staleDate: Date) async {
        guard let aktivitaet = Self.essen(id: id) else { return }
        await aktivitaet.update(ActivityContent(state: state, staleDate: staleDate))
    }

    func end(id: String) async {
        guard let aktivitaet = Self.essen(id: id) else { return }
        await aktivitaet.end(nil, dismissalPolicy: .immediate)
    }

    private static func essen(id: String) -> Activity<EssenAttributes>? {
        Activity<EssenAttributes>.activities.first { $0.id == id }
    }
}
