import Foundation

public enum HealthMedian {
    /// Median der letzten `window` Werte. Bei gerader Anzahl der obere der
    /// beiden mittleren — dieselbe Regel wie in `RestingHeartRate`, damit
    /// zwei Stellen der App nicht verschieden runden.
    public static func value(of samples: [Double], window: Int = 30,
                             minimumSamples: Int = 5) -> Double? {
        let recent = Array(samples.suffix(window))
        guard recent.count >= minimumSamples else { return nil }
        let sorted = recent.sorted()
        return sorted[sorted.count / 2]
    }
}

public extension RecoveryBaseline {
    /// Der eigene Normalbereich aus den Tageswerten. Fehlende Messwerte
    /// fallen zuerst heraus, erst danach greift das Fenster — sonst würde
    /// eine Lücke von zehn Tagen das Fenster leer räumen.
    static func from(days: [DailyMetrics], sleepHours: [Double],
                     window: Int = 30, minimumSamples: Int = 5) -> RecoveryBaseline {
        func median(_ values: [Double]) -> Double? {
            HealthMedian.value(of: values, window: window, minimumSamples: minimumSamples)
        }
        return RecoveryBaseline(
            sleepHours: median(sleepHours),
            restingHeartRate: median(days.compactMap { $0.restingHR.map(Double.init) }),
            hrv: median(days.compactMap(\.hrvMs)),
            respiratoryRate: median(days.compactMap(\.respRate)))
    }
}
