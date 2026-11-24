import Foundation

/// Ab wann die App hinsieht.
///
/// Zwei Aufgaben in einem Wert: Er sagt, ab wann **abgefragt** wird, und er
/// beschneidet, was **gerechnet und gezeichnet** wird. Beides muss dieselbe
/// Grenze sein, sonst zeigt ein Diagramm Tage, die keine Rechnung kennt.
///
/// Die Grenze ist tagesgenau, nicht sekundengenau. Ein vom Nutzer gewähltes
/// Datum meint den ganzen Tag — ein Messwert von 06:40 darf nicht
/// herausfallen, nur weil die Einstellung um 23:30 gesetzt wurde. Jede
/// Tagesgrenze läuft deshalb über `BerlinCalendar`, nie über eine Rechnung
/// mit 86400: Am 29.03.2026 hat der Tag 23 Stunden, am 25.10.2026 25.
public struct DataWindow: Equatable, Sendable {

    /// `nil` heißt: keine Grenze.
    public let start: Date?

    public static let unlimited = DataWindow(start: nil)

    /// Normalisiert sofort auf den Tagesbeginn. Danach kann keine Stelle mehr
    /// versehentlich mit der Uhrzeit vergleichen, die der Nutzer nie gemeint
    /// hat — und zwei Grenzen desselben Tages sind gleich.
    public init(start: Date?) {
        self.start = start.map(BerlinCalendar.startOfDay)
    }

    /// Liegt der Tag dieses Zeitpunkts innerhalb? Verglichen werden
    /// Tagesbeginne, nicht Zeitpunkte.
    public func contains(_ date: Date) -> Bool {
        guard let start else { return true }
        return BerlinCalendar.startOfDay(date) >= start
    }

    /// Beschneidet jede Reihe, die ein Datum trägt — `DailyMetrics`,
    /// `SleepNight`, `WorkoutSample`, `MeasurementPoint`,
    /// `CircumferenceEntry`. Der KeyPath bleibt offen, weil das Datumsfeld in
    /// diesen Typen unterschiedlich heißt.
    ///
    /// Das ist die **eine** Stelle, die die Grenze durchsetzt: angewandt
    /// direkt nach dem Holen, vor allem Abgeleiteten. Danach muss keine
    /// Formel von der Grenze wissen, und kein Schirm kann sie vergessen.
    public func clip<T>(_ items: [T], by keyPath: KeyPath<T, Date>) -> [T] {
        guard start != nil else { return items }
        return items.filter { contains($0[keyPath: keyPath]) }
    }

    /// Ab wann gefragt wird. `floor` ist das Älteste, was die Quelle hergibt;
    /// weiter zurück zu fragen bringt nichts.
    public func queryStart(floor: Date) -> Date {
        guard let start else { return floor }
        return max(start, floor)
    }

    /// Wie viele Tage die Grenze umfasst, Grenztag und Endtag eingeschlossen.
    /// `nil` ohne Grenze — dann gibt es keine Zahl, die stimmt.
    public func dayCount(through end: Date = Date()) -> Int? {
        guard let start else { return nil }
        // Eine Grenze hinter dem Endtag ist kein Fehler, sondern der Fall
        // „gespeichertes Datum liegt in der Zukunft". Null Tage, kein Absturz.
        guard start <= end else { return 0 }
        return BerlinCalendar.days(from: start, through: end).count
    }
}
