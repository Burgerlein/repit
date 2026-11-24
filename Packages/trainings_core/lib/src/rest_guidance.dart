// Pausenempfehlung, portiert aus
// `Packages/TrainingsCore/Sources/TrainingsCore/Gym/RestGuidance.swift` (#91).

import 'exercise.dart';

/// Empfohlene Pause zwischen zwei Sätzen.
///
/// **Die Zahlen stehen nicht in `docs/SPEC.md`.** Die Spec nennt keine
/// Pausenzeiten; statt eine Tabelle zu erfinden, ist die Empfehlung aus dem
/// Wiederholungsbereich **abgeleitet**, der ohnehin im Katalog steht:
/// wenige Wiederholungen heißt schwer heißt lange Pause. Wer sie später
/// ändern will, ändert eine Ableitung und keine Vorgabe.
///
/// Es ist eine **allgemeine Empfehlung**, keine ärztliche Vorgabe.
abstract final class RestGuidance {
  /// Die empfohlene Pause in Sekunden. Vier Stufen, keine fünfte.
  static int seconds(Exercise exercise) {
    // Die Reihenfolge ist Teil der Regel. Der Seitstütz hat `repHigh` 45
    // und fiele sonst in die Stufe für hohe Wiederholungszahlen, obwohl
    // dort Sekunden stehen und keine Wiederholungen.
    if (exercise.isTimed) return 45;
    if (exercise.repHigh <= 10) return 150;
    if (exercise.repHigh <= 15) return 90;
    return 60;
  }
}
