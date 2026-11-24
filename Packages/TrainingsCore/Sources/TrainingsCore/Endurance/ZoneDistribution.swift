import Foundation

public struct ZoneShare: Equatable, Sendable {
    /// 0 bedeutet unter Zone 1.
    public let zone: Int
    public let minutes: Double

    public init(zone: Int, minutes: Double) {
        self.zone = zone
        self.minutes = minutes
    }
}

public enum ZoneDistribution {

    /// Gezählt wird die Laufzeit nach dem Ø-Puls jedes Laufs. Das ist eine
    /// Näherung — ein Intervalltraining mit Ø 150 lag nie durchgehend bei 150.
    /// Die Beschriftung muss das sagen.
    ///
    /// Läufe ohne Ø-Puls zählen **nicht** mit. Sie als 0 bpm zu führen hieße,
    /// sie in „unter Zone 1" zu stecken: Die Verteilung sähe umso lockerer
    /// aus, je weniger gemessen wurde.
    public static func shares(_ workouts: [WorkoutSample],
                              zoning: HeartRateZoning) -> [ZoneShare] {
        var minutes = [Int: Double]()
        for workout in workouts where workout.kind == .running {
            guard let heartRate = workout.avgHR else { continue }
            minutes[zone(of: heartRate, in: zoning), default: 0] += workout.minutes
        }
        return (0...5).map { ZoneShare(zone: $0, minutes: minutes[$0] ?? 0) }
    }

    private static func zone(of heartRate: Int, in zoning: HeartRateZoning) -> Int {
        for zone in zoning.zones.reversed() where heartRate >= zone.lower {
            return zone.number
        }
        return 0
    }

    /// Anteil der Laufzeit in Zone 1 und 2 zusammen. Ziel sind mindestens 80 %.
    public static func easyShare(_ shares: [ZoneShare]) -> Double? {
        let total = shares.reduce(0) { $0 + $1.minutes }
        guard total > 0 else { return nil }
        let easy = shares.filter { $0.zone == 1 || $0.zone == 2 }
            .reduce(0) { $0 + $1.minutes }
        return easy / total
    }
}
