// Die geschätzte Dauer eines Trainings (#532, Spec 5.3).

import 'rest_guidance.dart';
import 'workout_definition.dart';

/// Schätzt die Dauer eines Trainings aus Übungen und Sätzen.
///
/// **Die Formel und ihre Zahlen sind ein Vorschlag der Spec, keine
/// Entscheidung des Nutzers.** Entschieden ist nur, dass die Dauer geschätzt
/// wird und sich überschreiben lässt. Die Schätzung liegt bei den
/// ausgelieferten Templates 5 bis 15 Minuten unter den „ca. 70 min" der SPEC,
/// deshalb tragen die Templates eingetragene Dauern. Es ist eine allgemeine
/// Schätzung, keine Messung.
///
/// ```
/// je Übung:  Rüstzeit + Sätze × Arbeitszeit + (Sätze − 1) × Pause
/// Summe in Sekunden, durch 60, auf volle 5 Minuten gerundet
/// ```
abstract final class WorkoutDuration {
  /// Arbeitszeit je Satz in Sekunden. Bei einer Zeitübung stattdessen der
  /// Mittelwert ihres Bereichs.
  static const int workSecondsPerSet = 45;

  /// Rüstzeit je Übung in Sekunden: Gerät herrichten, Gewicht einstellen.
  static const int setupSecondsPerExercise = 90;

  /// Auf wie viele Minuten die Schätzung gerundet wird; zugleich ihr
  /// Mindestwert.
  static const int roundToMinutes = 5;

  /// Die geschätzte Dauer in Minuten, ein Vielfaches von [roundToMinutes],
  /// mindestens [roundToMinutes].
  ///
  /// **`null`, wenn keine einzige bekannte Übung etwas beiträgt** — nicht 0
  /// (Fehler `01`): Die Dauer-Zeile des leeren Editors zeigt „–". Eine
  /// Übung, die der Katalog nicht kennt, trägt nichts bei, nicht einmal
  /// Rüstzeit. Die Pause kommt aus dem Bereich des **Trainings**, nicht des
  /// Katalogs (`WorkoutExercise.resolve`), nach jedem Satz außer dem letzten.
  /// Das Aufwärmen ist nicht enthalten.
  ///
  /// Gerechnet wird in halben Sekunden, damit der Mittelwert eines
  /// Zeitbereichs ohne Gleitkomma auskommt; gerundet wird bei genau halber
  /// Distanz nach oben.
  static int? estimate(List<WorkoutExercise> exercises) {
    var halfSeconds = 0;
    var counted = 0;
    for (final planned in exercises) {
      final exercise = planned.resolve();
      if (exercise == null) continue;
      counted++;
      // Eine Satzzahl unter 1 lehnt `WorkoutRules` ab; hier darf sie die
      // Summe trotzdem nicht ins Negative ziehen.
      final sets = planned.sets < 0 ? 0 : planned.sets;
      // Bei Zeitübungen sind die „Wiederholungen" Sekunden: der Mittelwert
      // des Bereichs, in halben Sekunden also die Summe.
      final workHalf = exercise.isTimed
          ? planned.repLow + planned.repHigh
          : workSecondsPerSet * 2;
      final restHalf = RestGuidance.seconds(exercise) * 2;
      halfSeconds +=
          setupSecondsPerExercise * 2 +
          sets * workHalf +
          (sets > 0 ? sets - 1 : 0) * restHalf;
    }
    if (counted == 0) return null;

    final unit = roundToMinutes * 120;
    final rounded = ((halfSeconds + unit ~/ 2) ~/ unit) * roundToMinutes;
    return rounded < roundToMinutes ? roundToMinutes : rounded;
  }

  /// Die eingetragene Dauer, sonst die Schätzung.
  ///
  /// Eingetragenes überschreibt, die Schätzung rechnet weiter mit: Wer seine
  /// Zahl zurückgibt (`entered == null`), bekommt die Schätzung wieder.
  /// `null`, wenn weder eingetragen noch schätzbar.
  static int? effective({
    int? entered,
    required List<WorkoutExercise> exercises,
  }) => entered ?? estimate(exercises);
}
