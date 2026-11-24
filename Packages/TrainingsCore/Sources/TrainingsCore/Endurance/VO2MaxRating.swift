import Foundation

/// Einordnung für Männer 20–29 nach SPEC 4.7. Die Zahl der Watch ist eine
/// Schätzung mit mehreren Punkten Spielraum; aussagekräftig ist der Trend.
public enum VO2MaxRating: Equatable, Sendable {
    case belowAverage, average, good, veryGood, excellent

    public static func rating(_ vo2max: Double) -> VO2MaxRating {
        switch vo2max {
        case ..<36: .belowAverage
        case ..<42: .average
        case ..<48: .good
        case ..<53: .veryGood
        default: .excellent
        }
    }
}
