import Foundation

/// Was in einem der dreizehn Zahlenfelder stehen darf.
public enum CircumferenceInput {

    public enum Validation: Equatable, Sendable {
        case empty                 // wird nicht gespeichert
        case value(Double)
        case notANumber
        case outOfRange(Double)    // gelesen, aber außerhalb von `plausible`
    }

    /// Unter 10 cm misst niemand einen Körperteil, über 200 cm auch nicht.
    public static let plausible: ClosedRange<Double> = 10...200

    public static func validate(_ text: String) -> Validation {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Die Einheit steht schon neben dem Feld; wer sie mittippt, meint
        // dieselbe Zahl.
        if cleaned.lowercased().hasSuffix("cm") {
            cleaned = String(cleaned.dropLast(2))
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard !cleaned.isEmpty else { return .empty }

        // Die deutsche Tastatur liefert ein Komma, `Double("27,0")` ergibt nil.
        // Zwei Trennzeichen bleiben ungültig: `Double` lehnt „27.0.1" ab.
        guard let number = Double(cleaned.replacingOccurrences(of: ",", with: ".")),
              number.isFinite
        else { return .notANumber }

        // Die gelesene Zahl kommt mit, damit die rote Zeile sagen kann, was
        // dasteht.
        guard plausible.contains(number) else { return .outOfRange(number) }
        return .value(number)
    }
}
