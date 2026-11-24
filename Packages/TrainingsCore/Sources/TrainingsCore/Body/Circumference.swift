import Foundation

/// Die dreizehn Maße aus SPEC 4.6. Die deutschen Namen stehen hier und nicht in
/// der Ansicht: Maß, Messstelle und Richtung gehören zusammen, genau wie beim
/// Übungskatalog.
///
/// Die Reihenfolge von `allCases` ist die Reihenfolge im Formular und in der
/// Tabelle: Arme, Rumpf, Beine.
public enum Circumference: String, CaseIterable, Sendable, Hashable {
    case upperArmRightRelaxed, upperArmRightFlexed
    case upperArmLeftRelaxed, upperArmLeftFlexed
    case chest, shoulders, waist, neck, hips
    // Die Rohwerte `thigh` und `calf` bleiben bei den rechten Maßen: Bereits
    // abgelegte und exportierte Dateien kennen nur diese beiden Schlüssel.
    // Würden sie nach links wandern, läsen sich alte Messungen als die falsche
    // Seite — und als Rohwert der Linken als gar nichts.
    case thighRight = "thigh", thighLeft
    case calfRight = "calf", calfLeft

    public var german: String {
        switch self {
        case .upperArmRightRelaxed: "Oberarm rechts, locker"
        case .upperArmRightFlexed: "Oberarm rechts, angespannt"
        case .upperArmLeftRelaxed: "Oberarm links, locker"
        case .upperArmLeftFlexed: "Oberarm links, angespannt"
        case .chest: "Brust"
        case .shoulders: "Schultern"
        case .waist: "Taille (Nabel)"
        case .neck: "Hals"
        case .hips: "Hüfte"
        case .thighRight: "Oberschenkel rechts"
        case .thighLeft: "Oberschenkel links"
        case .calfRight: "Wade rechts"
        case .calfLeft: "Wade links"
        }
    }

    /// Für das Ziel „Oberarm und Brust wachsen, Taille bleibt" ist bei der
    /// Taille eine kleinere Zahl der Fortschritt.
    public var lessIsBetter: Bool { self == .waist }

    /// Das Gegenstück: dieselbe Messart auf der anderen Seite. Locker und
    /// angespannt desselben Arms sind **kein** Paar — gemeint ist die
    /// Seitendifferenz, nicht der Anspannungszuwachs, und Oberschenkel wie Wade
    /// kennen ohnehin nur die Seiten. Brust, Schultern, Taille, Hals und Hüfte
    /// gibt es nur einmal am Körper.
    public var partner: Circumference? {
        switch self {
        case .upperArmRightRelaxed: .upperArmLeftRelaxed
        case .upperArmLeftRelaxed: .upperArmRightRelaxed
        case .upperArmRightFlexed: .upperArmLeftFlexed
        case .upperArmLeftFlexed: .upperArmRightFlexed
        case .thighRight: .thighLeft
        case .thighLeft: .thighRight
        case .calfRight: .calfLeft
        case .calfLeft: .calfRight
        case .chest, .shoulders, .waist, .neck, .hips: nil
        }
    }

    /// Wo und wie gemessen wird — ein Satz je Maß, im Detailschirm. Je Maß ein
    /// eigener: Ein Sammelsatz, dreizehnmal wiederholt, hilft beim Messen
    /// nicht.
    public var howTo: String {
        switch self {
        case .upperArmRightRelaxed:
            "Rechter Arm hängt locker herab, Maßband an der dicksten Stelle zwischen Schulter und Ellenbogen."
        case .upperArmRightFlexed:
            "Rechter Arm im rechten Winkel, Bizeps angespannt, Maßband um die höchste Wölbung."
        case .upperArmLeftRelaxed:
            "Linker Arm hängt locker herab, Maßband an der dicksten Stelle zwischen Schulter und Ellenbogen."
        case .upperArmLeftFlexed:
            "Linker Arm im rechten Winkel, Bizeps angespannt, Maßband um die höchste Wölbung."
        case .chest:
            "Maßband waagerecht auf Höhe der Brustwarzen, am Ende einer normalen Ausatmung."
        case .shoulders:
            "Maßband waagerecht um die breiteste Stelle der Schultern, Arme hängen entspannt."
        case .waist:
            "Maßband auf Nabelhöhe, locker stehen und den Bauch nicht einziehen."
        case .neck:
            "Maßband unterhalb des Kehlkopfs um den Hals, leicht schräg nach hinten, nicht einschnüren."
        case .hips:
            "Maßband um die stärkste Stelle des Gesäßes, Füße geschlossen."
        case .thighRight:
            "Rechtes Bein belastet, Maßband eine Handbreit unter dem Schritt um die dickste Stelle."
        case .thighLeft:
            "Linkes Bein belastet, Maßband eine Handbreit unter dem Schritt um die dickste Stelle."
        case .calfRight:
            "Rechte Wade an der dicksten Stelle, Gewicht gleichmäßig auf beiden Füßen."
        case .calfLeft:
            "Linke Wade an der dicksten Stelle, Gewicht gleichmäßig auf beiden Füßen."
        }
    }

    public var group: CircumferenceGroup {
        switch self {
        case .upperArmRightRelaxed, .upperArmRightFlexed,
             .upperArmLeftRelaxed, .upperArmLeftFlexed: .arms
        case .chest, .shoulders, .waist, .neck, .hips: .torso
        case .thighRight, .thighLeft, .calfRight, .calfLeft: .legs
        }
    }
}

/// Die drei Karten des Eingabeschirms. Dreizehn Zahlenfelder in einer Liste
/// scrollen sich schlecht.
public enum CircumferenceGroup: String, CaseIterable, Sendable {
    case arms, torso, legs

    public var german: String {
        switch self {
        case .arms: "Arme"
        case .torso: "Rumpf"
        case .legs: "Beine"
        }
    }
}

/// Eine Messung. Leere Felder werden nicht gespeichert, deshalb ein Wörterbuch
/// und keine dreizehn Optionale.
public struct CircumferenceEntry: Equatable, Sendable {
    public let date: Date
    public let values: [Circumference: Double]

    public init(date: Date, values: [Circumference: Double]) {
        self.date = date
        self.values = values
    }
}
