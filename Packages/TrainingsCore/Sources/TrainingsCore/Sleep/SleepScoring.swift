import Foundation

public enum SleepRating: Equatable, Sendable { case veryGood, good, okay, low }

public struct SleepScore: Equatable, Sendable {
    public let duration: Int
    /// `nil`, wenn es für die Regelmäßigkeit keine Datengrundlage gab. Null
    /// Punkte behaupteten sonst ein schlechtes Ergebnis, das niemand gemessen
    /// hat.
    public let regularity: Int?
    public let interruptions: Int

    public init(duration: Int, regularity: Int?, interruptions: Int) {
        self.duration = duration
        self.regularity = regularity
        self.interruptions = interruptions
    }

    public var total: Int { duration + (regularity ?? 0) + interruptions }

    /// Erreichbare Punkte dieser Nacht — ohne Regelmäßigkeit nur 70.
    public var maxTotal: Int { regularity == nil ? 70 : 100 }

    public var rating: SleepRating {
        // Verglichen wird der Anteil selbst, nicht auf ganze Prozent gerundet:
        // Bei 70 erreichbaren Punkten liegen zwei Schwellen zwischen zwei
        // ganzen Punkten (59,5 und 38,5), und Runden kippte die Grenzfälle.
        let share = Double(total) / Double(maxTotal)
        switch share {
        case 0.85...: return .veryGood
        case 0.70...: return .good
        case 0.55...: return .okay
        default: return .low
        }
    }
}

/// Eigener Schlaf-Score nach `docs/SPEC.md` 4.6. Er weicht vom Wert der
/// Apple-App ab, weil beide anders rechnen.
public enum SleepScoring {

    public static let regularityWindow = 14

    public static func score(asleepHours: Double, goalHours: Double,
                             bedtimeMinutes: Double?, recentBedtimeMinutes: [Double],
                             awakeMinutes: Double, wakeCount: Int) -> SleepScore {
        let duration = goalHours > 0 ? clamp(50 * asleepHours / goalHours, 0, 50) : 0

        // Eine übliche Zeit wird nicht angenommen: Ohne Einschlafzeit oder ohne
        // eine einzige frühere Nacht entfällt der Teil ganz.
        let recent = Array(recentBedtimeMinutes.suffix(regularityWindow))
        let regularity: Int?
        if let bedtime = bedtimeMinutes, !recent.isEmpty {
            let reference = recent.reduce(0, +) / Double(recent.count)
            regularity = Int(clamp(30 - abs(bedtime - reference) / 3, 0, 30).rounded())
        } else {
            regularity = nil
        }

        // Zehn straffreie Wachphasen und ein Punkt je weitere, nicht vier und
        // anderthalb: Ein Health-Export über 117 eigene Nächte zeigte einen
        // Median von sieben Abschnitten à eineinhalb Minuten. Die alten Werte
        // gaben einem Fünftel aller Nächte null Punkte für Aufwacher, die
        // niemand bemerkt hat. Herleitung in `docs/SPEC.md` 4.6.
        let interruptions = clamp(20
                                  - 0.5 * max(0, awakeMinutes - 10)
                                  - 1.0 * max(0, Double(wakeCount) - 10), 0, 20)

        return SleepScore(duration: Int(duration.rounded()),
                          regularity: regularity,
                          interruptions: Int(interruptions.rounded()))
    }

    private static func clamp(_ value: Double, _ low: Double, _ high: Double) -> Double {
        min(max(value, low), high)
    }
}

/// Uhrzeiten einer Nacht als eine durchlaufende Zahl: Minuten seit 18:00.
/// Ohne das läge 00:30 vor 23:23, und jede Mittelwertbildung über
/// Einschlafzeiten wäre falsch.
public enum EveningClock {
    public static func minutesSinceEvening(_ date: Date) -> Double {
        let parts = BerlinCalendar.calendar.dateComponents([.hour, .minute], from: date)
        let hour = Double(parts.hour ?? 0), minute = Double(parts.minute ?? 0)
        return hour >= 18 ? (hour - 18) * 60 + minute : (hour + 6) * 60 + minute
    }
}

public extension SleepScoring {

    /// Score je Nacht in **einem** Durchlauf, für ein Kalenderblatt mit einem
    /// Ring pro Tag. Einzeln gerechnet wäre für jeden der dreißig Tage die
    /// Historie neu zu übergeben.
    ///
    /// Die Regelmäßigkeit einer Nacht bezieht sich auf die Einschlafzeiten der
    /// Nächte **davor**, nicht auf die eigene. Gezählt werden dabei
    /// Einschlafzeiten und nicht Kalendernächte: Eine Nacht ohne Aufzeichnung
    /// belegt keinen Platz im Fenster und setzt es auch nicht zurück — sonst
    /// verschöbe eine einzige Lücke den Bezug um einen Tag.
    ///
    /// Nächte ohne eine einzige Schlafminute fehlen im Ergebnis. Das Kriterium
    /// ist `asleepMinutes`, nicht `isEmpty`: Eine Nacht aus lauter
    /// `awake`-Abschnitten ist nicht leer, aber auch kein Schlaf.
    static func series(of nights: [SleepNight],
                       goalHours: Double) -> [Date: SleepScore] {
        let ordered = nights
            .filter { $0.session.asleepMinutes > 0 }
            .sorted { $0.date < $1.date }

        var bedtimes: [Double] = []
        var scores: [Date: SleepScore] = [:]
        for night in ordered {
            let session = night.session
            let bedtime = session.start.map(EveningClock.minutesSinceEvening)
            scores[night.date] = score(asleepHours: session.asleepHours,
                                       goalHours: goalHours,
                                       bedtimeMinutes: bedtime,
                                       recentBedtimeMinutes: bedtimes,
                                       awakeMinutes: session.awakeMinutes,
                                       wakeCount: session.wakeCount)
            // Erst danach anhängen — die eigene Nacht ist nicht ihr Vergleich.
            // Das Zuschneiden auf `regularityWindow` macht `score` selbst.
            if let bedtime { bedtimes.append(bedtime) }
        }
        return scores
    }
}
