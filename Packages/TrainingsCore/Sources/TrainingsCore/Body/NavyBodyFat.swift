import Foundation

/// Körperfettschätzung aus Maßband-Werten, Formel für Männer nach SPEC 4.6.
///
/// Das ist eine Schätzung wie der Waagenwert auch, mit anderen Fehlern.
/// Wichtiger als die Zahl ist der Verlauf.
public enum NavyBodyFat {

    public static func percent(waistCm: Double, neckCm: Double,
                               heightCm: Double) -> Double? {
        // log10 von null oder negativ gibt NaN beziehungsweise -inf. Ein
        // Zahlendreher beim Eintragen reicht, damit das passiert.
        guard waistCm > neckCm, heightCm > 0 else { return nil }

        let divisor = 1.0324
            - 0.19077 * log10(waistCm - neckCm)
            + 0.15456 * log10(heightCm)
        guard divisor != 0 else { return nil }

        let value = 495 / divisor - 450
        // Grenzen wie im Dashboard (`navyBF`, dashboard-reference.html Zeile
        // 2002): über 2 und unter 50 Prozent. Außerhalb hat sich jemand
        // vermessen, und eine erfundene Zahl wäre schlimmer als keine.
        guard value.isFinite, value > 2, value < 50 else { return nil }
        return (value * 10).rounded() / 10
    }
}
