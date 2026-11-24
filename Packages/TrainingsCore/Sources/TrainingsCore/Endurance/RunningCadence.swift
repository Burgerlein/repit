import Foundation

/// Schritte pro Minute beim Laufen.
///
/// HealthKit kennt keinen Kadenz-Typ. Sie wird entweder aus Schrittzahl und
/// Dauer im Workout-Zeitraum gerechnet oder aus Geschwindigkeit und
/// Schrittlänge, die die Watch bei Outdoor-Läufen aufzeichnet.
///
/// Warum das zählt: Zu lange Schritte bei zu niedriger Kadenz belasten Waden
/// und Schienbein stärker. Zielkorridor laut SPEC 4.9: 165 bis 175.
public enum RunningCadence {

    public static let targetRange: ClosedRange<Double> = 165...175

    public enum Rating: Equatable, Sendable {
        case tooLow
        case inRange
        case aboveRange
    }

    public static func stepsPerMinute(steps: Int, minutes: Double) -> Double? {
        guard steps > 0, minutes > 0 else { return nil }
        return (Double(steps) / minutes * 10).rounded() / 10
    }

    public static func stepsPerMinute(speedMetersPerSecond: Double,
                                      strideLengthMeters: Double) -> Double? {
        guard speedMetersPerSecond > 0, strideLengthMeters > 0 else { return nil }
        return (speedMetersPerSecond / strideLengthMeters * 60 * 10).rounded() / 10
    }

    public static func rating(_ cadence: Double) -> Rating {
        if cadence < targetRange.lowerBound { return .tooLow }
        if cadence > targetRange.upperBound { return .aboveRange }
        return .inRange
    }
}
