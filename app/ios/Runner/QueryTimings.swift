import Foundation
import TrainingsCore

/// Wie lange eine HealthKit-Abfrage gedauert hat und wie viel sie brachte.
///
/// Ausdrücklich **ohne** Messwerte: Der Debug-Schirm ist kein Ort für
/// Gesundheitsdaten. Gespeichert werden nur der Name der Abfrage, die Dauer,
/// die Anzahl der Treffer und der abgefragte Zeitraum in Tagen — daraus lässt
/// sich nichts über den Nutzer ablesen, aber alles über die Wartezeit.
///
/// Portiert aus `Sources/Health/QueryTimings.swift` (Spec 8.3, Task 12),
/// unverändert bis auf den Ort: Die Messstelle wandert in den Swift-Kanal,
/// nicht auf die Dart-Seite — sonst misst sie Kanal-Overhead mit und die
/// Zahlen wären nicht mehr mit der Altapp vergleichbar.
struct QueryTiming: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let seconds: Double
    let count: Int
    /// Wie viele Tage die Abfrage umspannte. Ohne diese Zahl ist die Dauer
    /// nicht einzuordnen: 2 Sekunden für 30 Tage sind ein Problem, 2 Sekunden
    /// für zehn Jahre nicht.
    let days: Int
    let at: Date
}

/// Sammelt die Dauern der letzten Abfragen für den HealthKit-Testschirm.
///
/// Der Grund steht in
/// `docs/superpowers/specs/2026-10-15-betrachtungszeitraum-design.md`: Die
/// Wartezeit war aus dem Quelltext geschlossen, nicht gemessen. Ohne eine
/// Zahl lässt sich weder die Ursache finden noch eine Verbesserung belegen.
@MainActor
@Observable
final class QueryTimings {

    static let shared = QueryTimings()

    /// Neueste zuerst. Mehr als diese Zahl hilft beim Suchen nicht und
    /// lässt den Schirm nur wachsen.
    private static let maximumEntries = 40

    private(set) var entries: [QueryTiming] = []

    func record(_ name: String, seconds: Double, count: Int, days: Int) {
        entries.insert(QueryTiming(name: name, seconds: seconds, count: count,
                                   days: days, at: Date()), at: 0)
        if entries.count > Self.maximumEntries {
            entries.removeLast(entries.count - Self.maximumEntries)
        }
    }

    func clear() { entries.removeAll() }

    /// Die längste einzelne Abfrage — **nicht** die Summe.
    ///
    /// Eine Summe wäre hier zweifach falsch: `RecoveryStore` startet
    /// Tageswerte und Schlaf mit `async let` gleichzeitig, erlebt wird also
    /// das Maximum und nicht beides hintereinander. Und die Liste hält bis zu
    /// 40 Einträge aus mehreren Ladeläufen — nach drei Durchgängen stünde dort
    /// die dreifache Wartezeit. Da an dieser Zahl die Entscheidung über den
    /// verworfenen lokalen Spiegel hängt (#69), darf sie nicht
    /// übertreiben.
    var longestSeconds: Double { entries.map(\.seconds).max() ?? 0 }
}
