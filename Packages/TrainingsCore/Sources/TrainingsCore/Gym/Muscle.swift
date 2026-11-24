import Foundation

/// Die 16 Muskelgruppen der Muskelkarte mit ihren Zielbereichen in harten
/// Sätzen pro Woche. Werte aus SPEC 4.4 — allgemeine Richtwerte für
/// Muskelaufbau mit Fokus auf Oberkörper und Armen. Beine haben niedrigere
/// Ziele, weil sie zusätzlich durchs Laufen belastet werden.
public enum Muscle: String, CaseIterable, Sendable, Hashable {
    case chest, frontDelt, sideDelt, rearDelt
    case biceps, triceps, forearms
    case upperBack, lats, lowerBack, core
    case glutes, quads, hamstrings, calves, tibialis

    public var german: String {
        switch self {
        case .chest: "Brust"
        case .frontDelt: "Vordere Schulter"
        case .sideDelt: "Seitliche Schulter"
        case .rearDelt: "Hintere Schulter"
        case .biceps: "Bizeps"
        case .triceps: "Trizeps"
        case .forearms: "Unterarme"
        case .upperBack: "Oberer Rücken"
        case .lats: "Latissimus"
        case .lowerBack: "Unterer Rücken"
        case .core: "Rumpf"
        case .glutes: "Gesäß"
        case .quads: "Oberschenkel vorne"
        case .hamstrings: "Oberschenkel hinten"
        case .calves: "Waden"
        case .tibialis: "Schienbein"
        }
    }

    public var target: ClosedRange<Double> {
        switch self {
        case .chest, .sideDelt, .biceps, .triceps, .lats: 10...20
        case .upperBack: 8...16
        case .rearDelt: 6...14
        case .frontDelt: 4...12
        case .forearms, .core, .tibialis: 4...10
        case .glutes, .quads, .hamstrings: 6...12
        case .calves: 6...14
        case .lowerBack: 2...8
        }
    }
}
