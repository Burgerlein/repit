// Die Rechnungen hinter dem Pulsverlauf und dem Übungsband im Gym-Verlauf
// (#512). Vertrag und Begründungen: Spec
// `docs/superpowers/specs/2026-11-16-gym-puls-design.md`, Abschnitt 4, und die
// Tests in `test/gym_pulse_test.dart`.
//
// **Alle Zeitvergleiche laufen über Zeitpunkte** (`isBefore`, `isAfter`),
// nie über `==` auf `DateTime`: Der Kanal liefert Ortszeit, `recordedAt` ist
// UTC, und `==` unterscheidet beide, obwohl sie denselben Augenblick meinen.
import 'chart_buckets.dart';
import 'gym_session.dart';

/// Ø, Tiefst- und Höchstwert einer Herzfrequenz über ein Zeitfenster.
///
/// Werttyp mit `==` und `hashCode` über alle Felder: Er ist Teil dessen, was
/// ein Provider hält, und ohne Gleichheit liefe jede Ableitung neu (`03`).
final class PulseSummary {
  const PulseSummary({required this.avg, required this.min, required this.max});

  final double avg;
  final double min;
  final double max;

  @override
  bool operator ==(Object other) =>
      other is PulseSummary &&
      other.avg == avg &&
      other.min == min &&
      other.max == max;

  @override
  int get hashCode => Object.hash(avg, min, max);

  @override
  String toString() => 'PulseSummary(avg: $avg, min: $min, max: $max)';
}

/// Der Abschnitt einer Übung im Training: von ihrer frühesten bis zu ihrer
/// spätesten erfassten Satz-Uhrzeit.
///
/// Werttyp mit `==` und `hashCode` über alle Felder. [start] und [end] sind
/// die erfassten Zeitpunkte, unverändert (UTC, wie `recordedAt`).
final class GymExerciseSection {
  const GymExerciseSection({
    required this.position,
    required this.exerciseId,
    required this.start,
    required this.end,
  });

  /// Die Position der Übung in `ImportedSession.exercises`, **ab 1** — nie
  /// ein Zähler über die Übungen mit Abschnitt.
  final int position;

  final String exerciseId;
  final DateTime start;
  final DateTime end;

  @override
  bool operator ==(Object other) =>
      other is GymExerciseSection &&
      other.position == position &&
      other.exerciseId == exerciseId &&
      other.start == start &&
      other.end == end;

  @override
  int get hashCode => Object.hash(position, exerciseId, start, end);

  @override
  String toString() =>
      'GymExerciseSection($position, $exerciseId, $start – $end)';
}

abstract final class GymPulse {
  /// Wie viele Spannen der Pulsverlauf einer Dauer von [minutes] bekommt: ein
  /// Abschnitt je zwei Minuten, nach unten gerundet, auf 12 bis 36 begrenzt —
  /// wörtlich die Regel von `GymHeartRateStore.bucketCount` der Swift-App.
  ///
  /// Null, negative und sehr kleine Werte ergeben 12, keine Ausnahme.
  static int bucketCount({required double minutes}) {
    if (minutes.isNaN) return _minBuckets;
    final raw = (minutes / 2).floor();
    if (raw < _minBuckets) return _minBuckets;
    if (raw > _maxBuckets) return _maxBuckets;
    return raw;
  }

  static const int _minBuckets = 12;
  static const int _maxBuckets = 36;

  /// Ø, Min und Max der [samples] im Fenster `[from, to]`, **beide Grenzen
  /// einschließlich**.
  ///
  /// `null`, wenn keine Stichprobe im Fenster liegt (leere Liste, `to` vor
  /// `from`, alles außerhalb) — nie `0`. Das Ø ist das einfache Mittel der
  /// Stichproben, **nicht zeitgewichtet**. Die Eingabe muss nicht sortiert
  /// sein und bleibt unverändert.
  static PulseSummary? summary({
    required List<ChartSample> samples,
    required DateTime from,
    required DateTime to,
  }) {
    var count = 0;
    var sum = 0.0;
    double? lowest;
    double? highest;
    for (final sample in samples) {
      if (sample.date.isBefore(from) || sample.date.isAfter(to)) continue;
      count++;
      sum += sample.value;
      if (lowest == null || sample.value < lowest) lowest = sample.value;
      if (highest == null || sample.value > highest) highest = sample.value;
    }
    if (count == 0) return null;
    return PulseSummary(avg: sum / count, min: lowest!, max: highest!);
  }

  /// Die Abschnitte je Übung aus den erfassten Satz-Uhrzeiten, in Reihenfolge
  /// der Sitzung. [from] und [to] sind das Fenster des zugeordneten
  /// Apple-Trainings.
  ///
  /// Ein Abschnitt entsteht nur aus mindestens zwei Uhrzeiten **mit Breite**
  /// (die erste ist das Ende des ersten Satzes, wo er begann, steht nirgends)
  /// und nur, wenn er **ganz** im Fenster liegt — alles oder nichts, beide
  /// Grenzen einschließlich; beschnitten wird nichts. Nichts wird verteilt,
  /// geschätzt oder verlängert: Was zwischen zwei Abschnitten liegt, ist die
  /// Lücke.
  ///
  /// Überlappende Abschnitte (Supersätze) bleiben, wie sie sind.
  static List<GymExerciseSection> sections({
    required ImportedSession session,
    required DateTime from,
    required DateTime to,
  }) {
    if (!to.isAfter(from)) return const [];
    final result = <GymExerciseSection>[];
    for (var i = 0; i < session.exercises.length; i++) {
      final exercise = session.exercises[i];
      DateTime? start;
      DateTime? end;
      var times = 0;
      for (final set in exercise.sets) {
        final at = set.recordedAt;
        if (at == null) continue;
        times++;
        if (start == null || at.isBefore(start)) start = at;
        if (end == null || at.isAfter(end)) end = at;
      }
      if (times < 2 || start == null || end == null) continue;
      if (!end.isAfter(start)) continue;
      if (start.isBefore(from) || end.isAfter(to)) continue;
      result.add(
        GymExerciseSection(
          position: i + 1,
          exerciseId: exercise.exerciseId,
          start: start,
          end: end,
        ),
      );
    }
    return result;
  }
}
