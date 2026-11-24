import Foundation

/// Empfohlene Pause zwischen zwei Sätzen.
///
/// `docs/SPEC.md` nennt keine Pausenzeiten. Statt eine Tabelle zu erfinden,
/// leitet sich die Empfehlung aus dem Wiederholungsbereich ab, der ohnehin im
/// Katalog steht: wenige Wiederholungen heißt schwer heißt lange Pause.
public enum RestGuidance {

    public static func seconds(for exercise: Exercise) -> Int {
        // Die Reihenfolge ist Teil der Regel. Der Seitstütz hat `repHigh` 45
        // und fiele sonst in die Stufe für hohe Wiederholungszahlen, obwohl
        // dort Sekunden stehen und keine Wiederholungen.
        if exercise.isTimed { return 45 }
        if exercise.repHigh <= 10 { return 150 }
        if exercise.repHigh <= 15 { return 90 }
        return 60
    }
}
