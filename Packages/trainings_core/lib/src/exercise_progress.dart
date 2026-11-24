import 'berlin_calendar.dart';
import 'exercise.dart';
import 'one_rep_max.dart';
import 'progression.dart';

/// Ein Training, in dem eine Übung vorkam: wann, und welche Sätze.
///
/// Werttyp mit [==] und [hashCode] (`CLAUDE.md`, Fehler `03`): Die Trainings
/// einer Übung sind die Abhängigkeit, aus der ein Provider die Punkte
/// ableitet. Ohne inhaltlichen Vergleich liefe jede Ableitung bei jedem
/// Neubau neu.
final class ExerciseSession {
  const ExerciseSession({required this.date, required this.sets});

  /// Der Zeitpunkt des Trainings — wie überall im Paket ein UTC-Zeitpunkt.
  /// Welcher Berliner Tag daraus wird, entscheidet [BerlinCalendar].
  final DateTime date;

  /// Die Sätze dieser Übung in diesem Training, in Satzreihenfolge.
  final List<CompletedSet> sets;

  @override
  bool operator ==(Object other) {
    if (other is! ExerciseSession ||
        other.date != date ||
        other.sets.length != sets.length) {
      return false;
    }
    for (var i = 0; i < sets.length; i++) {
      if (other.sets[i] != sets[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(date, Object.hashAll(sets));

  @override
  String toString() => 'ExerciseSession($date, $sets)';
}

/// Ein Punkt der Verlaufslinien: ein Berliner Tag, an dem trainiert wurde.
///
/// Werttyp, aus demselben Grund wie [ExerciseSession].
final class ProgressPoint {
  const ProgressPoint({required this.day, required this.top, this.oneRepMax});

  /// Der Berliner Tagesbeginn ([BerlinCalendar.startOfDay]).
  final DateTime day;

  /// Das Höchstgewicht in kg. Bei Unterstützung negativ, und dann ist der
  /// Wert näher an null der schwerere. Bei Zeitübungen ([Exercise.isTimed])
  /// die längste Zeit in Sekunden.
  final double top;

  /// Das geschätzte Einwiederholungsmaximum ([OneRepMax.best]). `null`, wo
  /// keines zu schätzen ist — **nicht 0**: Eine 0 behauptete, das geschätzte
  /// Maximum sei null.
  final double? oneRepMax;

  @override
  bool operator ==(Object other) =>
      other is ProgressPoint &&
      other.day == day &&
      other.top == top &&
      other.oneRepMax == oneRepMax;

  @override
  int get hashCode => Object.hash(day, top, oneRepMax);

  @override
  String toString() =>
      'ProgressPoint(day: $day, top: $top, oneRepMax: $oneRepMax)';
}

/// Der Verlauf **einer Übung** über die Trainings: die Punkte für
/// Höchstgewicht und geschätztes 1RM (`docs/SPEC.md` 4.4).
///
/// Eine allgemeine Rechengröße für den Verlauf, keine Trainingsvorgabe.
abstract final class ExerciseProgress {
  /// Ein Punkt je Berliner Tag mit mindestens einem zählenden Satz,
  /// aufsteigend nach Tag. Die übergebene Liste wird nicht verändert.
  ///
  /// - **Zählen** tun nur Sätze mit positiver Wiederholungszahl, wie in
  ///   `Progression.suggest`. Ein Tag, an dem nichts zählt, ist kein Punkt.
  /// - [ProgressPoint.top] ist das **Maximum** der Sätze, nie ein Mittel.
  /// - [ProgressPoint.oneRepMax] ist [OneRepMax.best] — nicht das 1RM des
  ///   schwersten Satzes. Zwei Trainings am selben Tag tragen je Wert ihr
  ///   eigenes Maximum.
  /// - **Zeitübungen** tragen in `top` die längste Zeit und kein 1RM; das
  ///   Gewichtsfeld geht nicht ein. Epley auf Sekunden wäre Unsinn, ein
  ///   „Höchstgewicht 0 kg" eine Falschauskunft.
  /// - **Körpergewicht (`0.0`)** ist ein erfasster Wert: Der Punkt steht da,
  ///   ein 1RM gibt es nicht.
  static List<ProgressPoint> points({
    required Exercise exercise,
    required List<ExerciseSession> sessions,
  }) {
    // Der Tag ist der Berliner: In der Schlüsselform vergleicht sich der
    // Kalendertag lexikografisch richtig und übersteht jede Zeitumstellung.
    final tops = <DateTime, double>{};
    final estimates = <DateTime, double>{};

    for (final session in sessions) {
      final counted = [
        for (final set in session.sets)
          if (set.reps > 0) set,
      ];
      if (counted.isEmpty) continue;

      final day = BerlinCalendar.startOfDay(session.date);

      final double top;
      double? estimate;
      if (exercise.isTimed) {
        top = counted.map((s) => s.reps.toDouble()).reduce(_larger);
      } else {
        top = counted.map((s) => s.weight).reduce(_larger);
        estimate = OneRepMax.best(counted);
      }

      final known = tops[day];
      if (known == null || top > known) tops[day] = top;
      if (estimate != null) {
        final knownEstimate = estimates[day];
        if (knownEstimate == null || estimate > knownEstimate) {
          estimates[day] = estimate;
        }
      }
    }

    final days = tops.keys.toList()..sort();
    return [
      for (final day in days)
        ProgressPoint(day: day, top: tops[day]!, oneRepMax: estimates[day]),
    ];
  }

  static double _larger(double a, double b) => a >= b ? a : b;
}
