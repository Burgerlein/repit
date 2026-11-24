// Welche Muskeln ein Training trifft und wie stark (#532, Spec 5.5).

import 'exercise_library.dart';
import 'muscle.dart';
import 'workout_definition.dart';

abstract final class WorkoutMuscles {
  /// Je Muskel die Summe über alle Übungen von `Sätze × Gewicht`, mit den
  /// Gewichten aus `Exercise.muscles` (1,0 Hauptmuskel, 0,5 Nebenmuskel).
  ///
  /// Dieselbe Gewichtung wie `MuscleVolume.weeklySets`, aber auf die
  /// **geplanten** Sätze des Trainings, ohne Zeitfenster. Ein Muskel, den
  /// keine Übung trifft, steht nicht in der Map. Unbekannte Übungs-IDs tragen
  /// nichts bei.
  static Map<Muscle, double> weightedSets(List<WorkoutExercise> exercises) {
    final result = <Muscle, double>{};
    for (final planned in exercises) {
      final exercise = ExerciseLibrary.byId(planned.exerciseId);
      if (exercise == null) continue;
      for (final entry in exercise.muscles.entries) {
        result[entry.key] =
            (result[entry.key] ?? 0) + planned.sets * entry.value;
      }
    }
    return result;
  }

  /// Jeder Muskel mit gewichteten Sätzen über null — Haupt- **und**
  /// Nebenmuskeln.
  ///
  /// Gefärbt wird einfarbig („trifft diese Muskeln", nicht „wie viel"); die
  /// Satzzahl spielt dafür keine Rolle. Ob Nebenmuskeln mitfärben, ist ein
  /// Vorschlag der Spec. Ein leeres Training färbt nichts.
  static Set<Muscle> trained(List<WorkoutExercise> exercises) => {
    for (final entry in weightedSets(exercises).entries)
      if (entry.value > 0) entry.key,
  };
}
