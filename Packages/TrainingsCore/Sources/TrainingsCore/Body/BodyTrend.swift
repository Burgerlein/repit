import Foundation

public struct MeasurementPoint: Equatable, Sendable {
    public let date: Date
    public let value: Double

    public init(date: Date, value: Double) {
        self.date = date
        self.value = value
    }
}

/// Einordnung des Gewichtstrends für den Muskelaufbau. SPEC 4.6 nennt
/// +0,1 bis +0,25 kg pro Woche als guten Bereich.
public enum TrendRating: Equatable, Sendable {
    case losing   // es geht abwärts
    case slow     // zu langsam für Aufbau
    case good
    case fast     // schneller als nötig, der Überschuss wird eher Fett
}

public enum BodyTrend {

    /// Steigung in Einheiten pro Woche, kleinste Quadrate über das Fenster.
    ///
    /// Gibt `nil` zurück, wenn weniger als zwei Messungen im Fenster liegen
    /// oder alle am selben Tag sind. Eine Gerade durch einen Punkt hat keine
    /// Steigung, und „0,0 pro Woche" wäre eine Zahl, die niemand gerechnet hat.
    public static func perWeek(_ points: [MeasurementPoint], weeks: Int = 6,
                               now: Date) -> Double? {
        guard let cutoff = BerlinCalendar.calendar.date(
            byAdding: .day, value: -weeks * 7, to: BerlinCalendar.startOfDay(now))
        else { return nil }

        let inside = points.filter { $0.date >= cutoff }
        guard inside.count >= 2 else { return nil }

        let week = 7.0 * 24 * 3600
        let xs = inside.map { $0.date.timeIntervalSince1970 / week }
        let ys = inside.map(\.value)
        let n = Double(xs.count)
        let meanX = xs.reduce(0, +) / n
        let meanY = ys.reduce(0, +) / n

        var top = 0.0, bottom = 0.0
        for (x, y) in zip(xs, ys) {
            top += (x - meanX) * (y - meanY)
            bottom += (x - meanX) * (x - meanX)
        }
        // Alle Messungen am selben Tag: senkrechte Punktwolke, keine Steigung.
        guard bottom > 0 else { return nil }
        return top / bottom
    }

    public static func rating(_ perWeek: Double) -> TrendRating {
        if perWeek < 0 { return .losing }
        if perWeek < 0.1 { return .slow }
        if perWeek <= 0.25 { return .good }
        return .fast
    }
}

public enum ProteinTarget {

    /// 1,6 bis 2,0 Gramm je Kilogramm Körpergewicht, auf ganze Gramm gerundet.
    public static func grams(weightKg: Double) -> ClosedRange<Int>? {
        guard weightKg > 0 else { return nil }
        let low = Int((weightKg * 1.6).rounded())
        let high = Int((weightKg * 2.0).rounded())
        return low...high
    }
}
