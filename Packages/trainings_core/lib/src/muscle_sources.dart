// Die Aufschlüsselung des Muskelvolumens nach Übung, portiert aus
// `Packages/TrainingsCore/Sources/TrainingsCore/Body/MuscleSources.swift`
// (#91).

import 'berlin_calendar.dart';
import 'exercise_library.dart';
import 'muscle.dart';
import 'muscle_volume.dart';

/// Woher die Sätze eines Muskels kommen: eine Übung, ihr Beitrag und wann
/// sie zuletzt dran war.
///
/// Die Karte zeigt eine Zahl je Muskel — das hier ist dieselbe Zahl, nur
/// nach Übung aufgeschlüsselt.
final class MuscleSource {
  const MuscleSource({
    required this.exerciseId,
    required this.weeklySets,
    required this.setCount,
    required this.lastDate,
  });

  /// Die `Exercise.id` aus dem Katalog.
  final String exerciseId;

  /// Gewichteter Beitrag dieser Übung, gemittelt auf die Woche — dieselbe
  /// Rechnung wie in [MuscleVolume.weeklySets].
  final double weeklySets;

  /// Ungewichtet: drei Sätze sind drei, auch wenn der Muskel nur mithilft.
  /// Dass diese Zahl und [weeklySets] auseinandergehen, ist Absicht.
  final int setCount;

  /// Der jüngste Satz dieser Übung im Fenster, **mit der Uhrzeit des
  /// Satzes** und nicht auf den Tagesbeginn gerundet: Der Schirm zeigt
  /// „zuletzt am …", und ein gerundeter Wert behauptete eine Uhrzeit, die es
  /// nicht gab.
  final DateTime lastDate;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MuscleSource &&
          other.exerciseId == exerciseId &&
          other.weeklySets == weeklySets &&
          other.setCount == setCount &&
          other.lastDate == lastDate;

  @override
  int get hashCode => Object.hash(exerciseId, weeklySets, setCount, lastDate);

  @override
  String toString() =>
      'MuscleSource($exerciseId, $weeklySets/Woche, $setCount Sätze)';
}

/// Die Übungen, die [muscle] im Fenster getroffen haben, mit dem größten
/// Beitrag oben.
///
/// Fenstergrenze, Gewichtung und Mittelung sind dieselben wie in
/// [MuscleVolume.weeklySets] — es ist dieselbe Rechnung, nur nicht auf den
/// Muskel zusammengefasst. Unbekannte Übungs-IDs werden hier genauso
/// übergangen wie dort: Ein Satz, dessen Gewichte niemand kennt, zählt
/// nirgends mit.
///
/// Die Summe über alle Quellen eines Muskels ist sein Wert aus
/// [MuscleVolume.weeklySets], **bis auf Fließkommarundung**: Dort wird die
/// Muskelsumme einmal geteilt, hier je Übung geteilt und danach addiert, und
/// `(a + b) / w` ist nicht bitgleich mit `a / w + b / w`. „Genau" wäre eine
/// Zusage, die der Code nicht einlöst.
///
/// Bei gleichem Beitrag steht das jüngere Training oben, bei gleichem Datum
/// die kleinere Übungs-ID: Sonst hinge die Reihenfolge an der Laune der Map
/// und spränge bei jedem Aufruf.
///
/// Ohne Fenster (`days <= 0`) gibt es nichts zu zählen — die Rückgabe ist
/// dann eine leere Liste.
///
/// Swift hängt das als Extension an `MuscleVolume`; Dart kennt keine
/// statischen Extensions, deshalb eine Funktion auf Bibliotheksebene.
List<MuscleSource> muscleSources({
  required Muscle muscle,
  required List<TrainedSet> sets,
  required int days,
  required DateTime now,
}) {
  final cutoff = MuscleVolume.windowStart(days: days, now: now);
  if (cutoff == null) return const [];

  final weighted = <String, double>{};
  final counts = <String, int>{};
  final lastDates = <String, DateTime>{};

  for (final set in sets) {
    if (BerlinCalendar.startOfDay(set.date).isBefore(cutoff)) continue;
    final exercise = ExerciseLibrary.byId(set.exerciseId);
    final weight = exercise?.muscles[muscle];
    if (weight == null) continue;

    weighted[set.exerciseId] = (weighted[set.exerciseId] ?? 0) + weight;
    counts[set.exerciseId] = (counts[set.exerciseId] ?? 0) + 1;
    final bisher = lastDates[set.exerciseId];
    if (bisher == null || set.date.isAfter(bisher)) {
      lastDates[set.exerciseId] = set.date;
    }
  }

  final weeks = days / 7;
  return weighted.entries
      .map(
        (entry) => MuscleSource(
          exerciseId: entry.key,
          weeklySets: entry.value / weeks,
          setCount: counts[entry.key] ?? 0,
          lastDate: lastDates[entry.key]!,
        ),
      )
      .toList()
    ..sort((a, b) {
      if (a.weeklySets != b.weeklySets) {
        return b.weeklySets.compareTo(a.weeklySets);
      }
      if (a.lastDate != b.lastDate) return b.lastDate.compareTo(a.lastDate);
      return a.exerciseId.compareTo(b.exerciseId);
    });
}
