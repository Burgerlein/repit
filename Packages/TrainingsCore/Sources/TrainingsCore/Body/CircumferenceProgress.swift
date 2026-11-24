import Foundation

/// Richtung, Verlauf und Kennzahlen je Maß für den Umfänge-Schirm.
///
/// Alle Funktionen sammeln zuerst die Werte **dieses einen Maßes** über alle
/// Einträge. Ein Tag, an dem nur die Taille nachgemessen wurde, ist für den
/// Oberarm keine Messung — sonst verglichen die Zeilen untereinander
/// verschiedene Zeiträume, ohne dass man es sähe.
public enum CircumferenceProgress {

    public enum Direction: Equatable, Sendable { case up, down, flat }

    /// Maßband, Zugspannung und Messstelle streuen zu stark, als dass ein
    /// Zehntel eine Aussage wäre. Die Grenze selbst gehört zur Bewegung.
    public static let deadband: Double = 0.2

    /// Ein mittlerer Monat. Auf den Tag genau zu rechnen hieße, dem Maßband
    /// eine Genauigkeit zu unterstellen, die es nicht hat.
    private static let daysPerMonth = 30.44

    /// Richtung und Betrag gegen die vorige Messung **dieses Maßes**.
    /// `delta` ist vorzeichenbehaftet; den Betrag bildet die Ansicht.
    public static func change(_ measure: Circumference,
                              in entries: [CircumferenceEntry])
        -> (delta: Double, direction: Direction, isProgress: Bool)? {
        let values = series(measure, in: entries).map(\.value)
        guard values.count >= 2 else { return nil }

        let delta = values[values.count - 1] - values[values.count - 2]
        // Ungerundet vergleichen: 0,19 würde sonst zu 0,2 und bekäme einen
        // Pfeil, den die Messgenauigkeit nicht trägt.
        //
        // Das Epsilon ist kein Schönheitsfehler, sondern nötig: Umfänge haben
        // eine Nachkommastelle, und 33,8 − 33,6 ergibt in Double
        // 0,19999999999999957. Ohne die Toleranz bekäme dieselbe Differenz von
        // zwei Zehnteln einmal einen Pfeil und einmal einen Strich, je nachdem,
        // welche Zahlen sie bilden.
        let direction: Direction
        if abs(delta) < deadband - 1e-9 {
            direction = .flat
        } else {
            direction = delta > 0 ? .up : .down
        }

        // Was im Rauschen liegt, ist kein Erfolg — auch nicht bei der Taille.
        let isProgress: Bool
        switch direction {
        case .flat: isProgress = false
        case .up: isProgress = !measure.lessIsBetter
        case .down: isProgress = measure.lessIsBetter
        }

        return (delta, direction, isProgress)
    }

    /// Veränderung gegenüber der ersten Messung dieses Maßes; nil, solange die
    /// erste die aktuelle ist. Ohne Totzone: Die Spalte „seit Start" nennt die
    /// Zahl, der Strich gilt nur dem Pfeil daneben.
    public static func sinceStart(_ measure: Circumference,
                                  in entries: [CircumferenceEntry]) -> Double? {
        let values = series(measure, in: entries).map(\.value)
        guard let first = values.first, let last = values.last,
              values.count >= 2 else { return nil }
        return last - first
    }

    /// cm pro Monat zwischen erster und letzter Messung dieses Maßes.
    public static func perMonth(_ measure: Circumference,
                                in entries: [CircumferenceEntry]) -> Double? {
        let points = series(measure, in: entries)
        guard let first = points.first, let last = points.last,
              points.count >= 2 else { return nil }

        // Tage statt Sekunden, und kein Nenner null: Zwei Messungen desselben
        // Tages ergäben sonst „inf cm pro Monat".
        let days = BerlinCalendar.calendar.dateComponents(
            [.day],
            from: BerlinCalendar.startOfDay(first.date),
            to: BerlinCalendar.startOfDay(last.date)).day ?? 0
        guard days > 0 else { return nil }

        return (last.value - first.value) / Double(days) * daysPerMonth
    }

    /// Kleinster und größter Wert über alle Messungen — nicht nur Anfang und
    /// Ende. Eine einzelne Messung ist ihr eigener kleinster und größter Wert.
    public static func span(_ measure: Circumference,
                            in entries: [CircumferenceEntry])
        -> (lowest: Double, highest: Double)? {
        let values = series(measure, in: entries).map(\.value)
        guard let lowest = values.min(), let highest = values.max() else { return nil }
        return (lowest, highest)
    }

    /// Wann die nächste Messung sinnvoll ist: jüngste Messung + 14 Tage, auf
    /// den Tagesbeginn. Tage, keine 86400 Sekunden — sonst landet die Rechnung
    /// über den Wechsel der Sommerzeit hinweg am Vortag.
    public static func nextDue(after entries: [CircumferenceEntry]) -> Date? {
        guard let latest = entries.map(\.date).max() else { return nil }
        return BerlinCalendar.calendar.date(
            byAdding: .day, value: 14, to: BerlinCalendar.startOfDay(latest))
    }

    /// Die Werte dieses Maßes, aufsteigend nach Datum. Einträge ohne das Maß
    /// fallen weg, ihre Lücke wird nicht gefüllt.
    private static func series(_ measure: Circumference,
                               in entries: [CircumferenceEntry]) -> [MeasurementPoint] {
        entries
            .sorted { $0.date < $1.date }
            .compactMap { entry in
                entry.values[measure].map { MeasurementPoint(date: entry.date, value: $0) }
            }
    }
}
