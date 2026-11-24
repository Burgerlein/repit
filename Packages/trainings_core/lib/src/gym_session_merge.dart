// Eigene und übernommene Trainings zusammenführen, portiert aus
// `Packages/TrainingsCore/Sources/TrainingsCore/Gym/GymSessionMerge.swift`
// (#91).

import 'berlin_calendar.dart';
import 'gym_session.dart';
import 'progression.dart';

abstract final class GymSessionMerge {
  /// Eigene Trainings und übernommene zusammenführen, neueste zuerst.
  ///
  /// Treffen beide auf denselben **Berliner Tag** und dasselbe Workout,
  /// gewinnt das eigene: Es ist der neuere Stand. Das ist genau der Fall,
  /// der beim Nachtragen eines Trainings entsteht, das schon im Dashboard
  /// stand — ohne diese Regel stünde es zweimal da, mit verschiedenen
  /// Zahlen.
  ///
  /// „Kein Workout" ist ein eigener Schlüssel und nicht dasselbe wie Gym A.
  /// Der Dashboard-Import erzeugt solche Sitzungen, und sie einem Workout
  /// zuzuschlagen hieße raten.
  ///
  /// Bei gleichem Zeitstempel entscheidet der Workout-Code. Ohne dieses
  /// zweite Kriterium hinge die Reihenfolge an der Laufreihenfolge einer
  /// Map, und die Liste sähe bei jedem Start anders aus.
  static List<ImportedSession> merge({
    required List<ImportedSession> logged,
    required List<ImportedSession> imported,
  }) {
    final byKey = <String, ImportedSession>{};
    for (final session in imported) {
      byKey[sessionKey(session)] = session;
    }
    for (final session in logged) {
      byKey[sessionKey(session)] = session;
    }

    return byKey.values.toList()..sort((eine, andere) {
      if (eine.date != andere.date) return andere.date.compareTo(eine.date);
      return (eine.workout?.code ?? '').compareTo(andere.workout?.code ?? '');
    });
  }

  /// Übungs-ID → Satzlisten, **neueste Sitzung zuerst** — die Form, die
  /// `Progression.suggest` erwartet.
  ///
  /// Sortiert selbst und verlässt sich nicht auf die Eingabereihenfolge:
  /// Eine falsch sortierte Historie liefert lautlos falsche Vorschläge, weil
  /// der Vorschlag sich dann auf die ältere Last bezöge.
  static Map<String, List<List<CompletedSet>>> history(
    List<ImportedSession> sessions,
  ) {
    final out = <String, List<List<CompletedSet>>>{};
    final nachDatum = [...sessions]
      ..sort((eine, andere) => andere.date.compareTo(eine.date));

    for (final session in nachDatum) {
      for (final exercise in session.exercises) {
        (out[exercise.exerciseId] ??= <List<CompletedSet>>[]).add(
          exercise.sets,
        );
      }
    }
    return out;
  }

  /// Der Schlüssel, unter dem zwei Sitzungen dieselbe sind — auch für
  /// `GymSessionImport.plan`, damit die Übernahme dieselbe Regel anlegt wie
  /// das Zusammenführen und es nur eine gibt.
  ///
  /// Der Tag kommt aus [BerlinCalendar.dayKey], nicht aus den Feldern des
  /// [DateTime]: Der Berliner Tagesbeginn liegt als UTC-Zeitpunkt um 22:00
  /// oder 23:00 des Vortags, zwei Zeitpunkte desselben Berliner Tages können
  /// also auf verschiedenen UTC-Kalendertagen liegen — und umgekehrt.
  ///
  /// Hinter dem Tag steht die [ImportedSession.trainingId], wo es sie gibt,
  /// sonst der Code des Workouts, sonst `?`. Für jede Sitzung mit einem
  /// Workout und ohne Kennung ist der Schlüssel damit **unverändert**; zwei
  /// verschiedene eigene Trainings am selben Tag fielen sonst beide auf `?`
  /// und die zweite ersetzte die erste.
  static String sessionKey(ImportedSession session) =>
      '${BerlinCalendar.dayKey(session.date)}-'
      '${session.trainingId ?? session.workout?.code ?? '?'}';
}
