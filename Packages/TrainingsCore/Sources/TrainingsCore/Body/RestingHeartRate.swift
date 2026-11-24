import Foundation

/// Ruhepuls als Grundlage der Zonenberechnung.
public enum RestingHeartRate {

    public enum Source: Equatable, Sendable {
        case manual
        case median(Int)
        case estimate
    }

    /// Greift, solange zu wenige Messwerte vorliegen.
    public static let fallbackBpm = 64

    private static let minimumSamples = 5
    private static let window = 30

    public static func value(manual: Int?, recent: [Int]) -> (bpm: Int, source: Source) {
        if let manual, manual > 0 {
            return (manual, .manual)
        }
        let samples = Array(recent.suffix(window))
        guard samples.count >= minimumSamples else {
            return (fallbackBpm, .estimate)
        }
        let sorted = samples.sorted()
        return (sorted[sorted.count / 2], .median(sorted.count))
    }
}
