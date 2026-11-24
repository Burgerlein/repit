import Foundation

public enum RacePrediction {

    /// VDOT auf Halbmarathon-Minuten nach Jack Daniels, SPEC 4.7.
    private static let table: [(vdot: Double, minutes: Double)] = [
        (30, 141.1), (32, 133.8), (34, 127.3), (36, 121.3), (38, 115.9),
        (40, 111.0), (42, 106.5), (44, 102.3), (46, 98.5), (48, 94.9),
        (50, 91.6), (52, 88.6), (54, 85.8), (56, 83.2), (58, 80.7), (60, 78.4)
    ]

    /// Theoretisches Potenzial. Außerhalb der Tabelle gelten die Randwerte:
    /// Eine fortgesetzte Gerade ergäbe irgendwann negative Laufzeiten, und
    /// belegt ist die Tabelle dort ohnehin nicht.
    public static func halfMarathonMinutes(vdot: Double) -> Double {
        guard let first = table.first, let last = table.last else { return 0 }
        if vdot <= first.vdot { return first.minutes }
        if vdot >= last.vdot { return last.minutes }

        for (low, high) in zip(table, table.dropFirst()) where vdot <= high.vdot {
            let share = (vdot - low.vdot) / (high.vdot - low.vdot)
            return low.minutes + share * (high.minutes - low.minutes)
        }
        return last.minutes
    }

    /// Die Laufökonomie macht bei Einsteigern einen großen Unterschied — die
    /// zweite, ehrlichere Zahl neben dem Potenzial.
    public static let beginnerFactor = 1.12

    public static func realisticMinutes(vdot: Double) -> Double {
        halfMarathonMinutes(vdot: vdot) * beginnerFactor
    }
}
