import Foundation

public struct HeartRateZone: Equatable, Sendable {
    public let number: Int
    public let lower: Int
    public let upper: Int

    public init(number: Int, lower: Int, upper: Int) {
        self.number = number
        self.lower = lower
        self.upper = upper
    }
}

public struct HeartRateZoning: Equatable, Sendable {
    public let zones: [HeartRateZone]
    /// true, wenn der Ruhepuls zu nah an der HFmax lag und geklemmt werden
    /// musste. Die Oberfläche muss das benennen, sonst sehen unbrauchbare
    /// Zonen völlig plausibel aus.
    public let clamped: Bool
}

/// Zonen über die Herzfrequenzreserve (Karvonen). Schätzung, kein Labortest.
public enum HeartRateZones {

    /// Mindestabstand zwischen Ruhepuls und HFmax, damit die Zonen bei
    /// Fehleingaben nicht invertieren.
    public static let minimumReserve = 20

    public static func zoning(hrMax: Int, hrRest: Int) -> HeartRateZoning {
        let safeRest = min(hrRest, hrMax - minimumReserve)
        let reserve = Double(hrMax - safeRest)

        func bound(_ fraction: Double) -> Int {
            Int((Double(safeRest) + reserve * fraction).rounded())
        }

        let zones = (1...5).map { number in
            HeartRateZone(
                number: number,
                lower: bound(Double(number + 4) / 10),
                upper: bound(Double(number + 5) / 10)
            )
        }
        return HeartRateZoning(zones: zones, clamped: safeRest != hrRest)
    }
}
