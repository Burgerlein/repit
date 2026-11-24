// Das Muskelvolumen, portiert aus
// `Packages/TrainingsCore/Sources/TrainingsCore/Body/MuscleVolume.swift`
// (#91).

import 'berlin_calendar.dart';
import 'exercise_library.dart';
import 'muscle.dart';

/// Ein einzelner absolvierter Satz, reduziert auf das, was die Muskelkarte
/// braucht.
///
/// Bewusst nicht `ImportedSession`: Die Sätze kommen später aus dem
/// drift-Cache, und diese Rechnung soll davon nichts merken.
final class TrainedSet {
  const TrainedSet({required this.date, required this.exerciseId});

  /// Zeitpunkt des Satzes, mit Uhrzeit. Welcher Berliner Kalendertag das
  /// ist, rechnet [BerlinCalendar] aus — hier steht nichts Gerundetes.
  final DateTime date;

  /// Die `Exercise.id` aus dem Katalog. Eine ID, die der Katalog nicht
  /// führt, wird übergangen statt geraten.
  final String exerciseId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrainedSet &&
          other.date == date &&
          other.exerciseId == exerciseId;

  @override
  int get hashCode => Object.hash(date, exerciseId);

  @override
  String toString() => 'TrainedSet($exerciseId, $date)';
}

/// Wie ein Muskel zu seinem Zielbereich steht. Farben wählt die Ansicht.
///
/// Die Zielbereiche in [Muscle.target] sind **allgemeine Richtwerte** für
/// Muskelaufbau, keine ärztliche Vorgabe — der Zustand hier ist also eine
/// Einordnung, keine Diagnose.
///
/// **Die Reihenfolge der Fälle ist die Deklarationsreihenfolge, nicht die
/// Dringlichkeitsreihenfolge** aus [MuscleVolume.sortedByNeed] (`priority`,
/// `low`, `high`, `ok`). Ein Dart-Enum ist über seinen `index`
/// persistierbar; wer die Fälle „passend zur Sortierung" umstellt,
/// verschiebt gespeicherte Werte.
enum MuscleStatus {
  /// Unter der halben Untergrenze.
  priority,

  /// Unter dem Ziel, aber über dessen Hälfte.
  low,

  /// Im Zielbereich, beide Grenzen eingeschlossen.
  ok,

  /// Über dem Ziel.
  high,
}

/// Harte Sätze pro Woche je Muskel, aus den einzelnen Sätzen gerechnet.
abstract final class MuscleVolume {
  /// Anfang des Fensters: der Berliner Tagesbeginn des Tages, der [days] − 1
  /// Tage zurückliegt. Bei sieben Tagen zählt der Satz von vor sechs Tagen
  /// also noch mit, der von vor sieben nicht mehr. Ohne Fenster
  /// (`days <= 0`) gibt es keine Grenze und damit nichts zu zählen — die
  /// Rückgabe ist dann `null`.
  ///
  /// **Über [BerlinCalendar.addDays], nicht über eine Dauer.** Sechs
  /// Kalendertage sind über eine Zeitumstellung hinweg nicht 144 Stunden,
  /// sondern 143 oder 145; mit `Duration` gerechnet kippt die Grenze um
  /// einen Tag, und es zählen Sätze mit oder fehlen, die es nicht sollten.
  ///
  /// **Öffentlich, anders als in Swift** (dort modulintern): `muscleSources`
  /// rechnet mit derselben Grenze, und das lässt sich nur prüfen, wenn man
  /// sie fragen kann. Liefen die beiden auseinander, erklärte die
  /// Aufschlüsselung eine Zahl, die auf der Karte nirgends steht.
  static DateTime? windowStart({required int days, required DateTime now}) =>
      days > 0 ? BerlinCalendar.addDays(now, -(days - 1)) : null;

  /// Harte Sätze pro Woche je Muskel, gemittelt über das Fenster.
  ///
  /// Die Gewichtung steht **im Übungskatalog**, nicht hier: Hauptmuskel 1,0,
  /// Nebenbelastung 0,5. Eine Nebenbelastung trägt also einen halben Satz
  /// bei, keinen ganzen — wer daraus „trainiert ja/nein" macht, zerstört die
  /// Rechnung der Muskelkarte.
  ///
  /// Gemittelt wird auf die Woche, geteilt durch `days / 7`. Im
  /// Sieben-Tage-Fenster ist der Faktor 1.
  ///
  /// Das Ergebnis enthält **immer alle 16 Muskeln**, auch die mit 0, und
  /// auch bei `days <= 0` — eine Karte mit fehlendem Muskel zeigt ein Loch
  /// statt einer Null.
  ///
  /// Sätze mit einem Datum in der Zukunft zählen mit: Das Fenster ist nach
  /// oben nicht begrenzt. Trainings trägt man nach, nicht vor.
  static Map<Muscle, double> weeklySets(
    List<TrainedSet> sets, {
    required int days,
    required DateTime now,
  }) {
    final total = {for (final muscle in Muscle.values) muscle: 0.0};
    final cutoff = windowStart(days: days, now: now);
    if (cutoff == null) return total;

    for (final set in sets) {
      if (BerlinCalendar.startOfDay(set.date).isBefore(cutoff)) continue;
      // Eine Übung, die die Bibliothek nicht kennt, hat keine
      // Muskelzuordnung. Raten hieße, eine Zahl zu erfinden.
      final exercise = ExerciseLibrary.byId(set.exerciseId);
      if (exercise == null) continue;
      for (final entry in exercise.muscles.entries) {
        total[entry.key] = (total[entry.key] ?? 0) + entry.value;
      }
    }

    final weeks = days / 7;
    return {for (final entry in total.entries) entry.key: entry.value / weeks};
  }

  /// Wie der Muskel zu seinem Zielbereich steht.
  ///
  /// Beide Grenzen des Ziels gehören noch zu [MuscleStatus.ok]; unter der
  /// halben Untergrenze beginnt [MuscleStatus.priority].
  static MuscleStatus status(Muscle muscle, double sets) {
    final target = muscle.target;
    if (sets > target.high) return MuscleStatus.high;
    if (sets >= target.low) return MuscleStatus.ok;
    return sets >= target.low / 2 ? MuscleStatus.low : MuscleStatus.priority;
  }

  /// Dringendste zuerst: `priority`, `low`, `high`, `ok`.
  ///
  /// „Über dem Ziel" steht vor „im Ziel", weil es eher einen Hinweis
  /// verdient. Innerhalb einer Gruppe entscheidet der Abstand zur
  /// Untergrenze, bei Gleichstand der [Muscle.code] — ohne diese letzte
  /// Stufe hinge die Reihenfolge an der Laune der Map und spränge bei jedem
  /// Aufruf.
  ///
  /// Das Ergebnis enthält **immer alle 16 Muskeln**. Ein Muskel, der in
  /// [volume] fehlt, gilt als 0 und ist damit dringend — nicht als fehlend.
  static List<Muscle> sortedByNeed(Map<Muscle, double> volume) {
    int rank(MuscleStatus status) => switch (status) {
      MuscleStatus.priority => 0,
      MuscleStatus.low => 1,
      MuscleStatus.high => 2,
      MuscleStatus.ok => 3,
    };

    return Muscle.values.toList()..sort((a, b) {
      final va = volume[a] ?? 0, vb = volume[b] ?? 0;
      final ra = rank(status(a, va)), rb = rank(status(b, vb));
      if (ra != rb) return ra.compareTo(rb);
      final qa = va / a.target.low, qb = vb / b.target.low;
      if (qa != qb) return qa.compareTo(qb);
      return a.code.compareTo(b.code);
    });
  }
}
