// Die Start-Templates Push, Pull und Legs, der Tombstone als reine Funktion
// und die Definition der Enum-Workouts (#532, Spec 4.3, 5.7, 23, 25).

import 'exercise.dart';
import 'exercise_catalog.dart';
import 'workout_definition.dart';
import 'workout_naming.dart';

/// Die Trainings, die die App selbst mitbringt.
///
/// Sie sind aus [Workout] und [ExerciseCatalog] **abgeleitet**, nicht ein
/// zweites Mal von Hand getippt — sonst liefen die zwei Listen lautlos
/// auseinander.
abstract final class WorkoutTemplates {
  /// Welche Enum-Fälle als Template ausgeliefert werden, in dieser
  /// Reihenfolge. Zum Start Push, Pull und Legs (Tim, 19.11.2026); Gym A–D
  /// bleiben Enum-Fälle und Codes, sind aber keine Templates.
  static const List<Workout> _shipped = [
    Workout.push,
    Workout.pull,
    Workout.legs,
  ];

  /// Der Tag, den die ausgelieferten Templates tragen.
  ///
  /// Ein Vorschlag, den niemand entschieden hat: Er gibt dem Filter der
  /// Übersicht von Anfang an etwas zu filtern.
  static const String _tag = 'Gym';

  static final List<WorkoutDefinition> _all = List.unmodifiable([
    for (final workout in _shipped) _build(workout, tags: const [_tag]),
  ]);

  /// Push, Pull, Legs in dieser Reihenfolge.
  ///
  /// Übungen, Sätze und Wiederholungsbereich sind die Katalogwerte, als Werte
  /// kopiert; `increment` bleibt `null`. Der Name ist
  /// `'${label} — ${title}'` ([WorkoutNaming.workoutName]), die eingetragene
  /// Dauer [Workout.minutes] — ein Vorschlag: Mit `null` stünde dort die
  /// Schätzung statt „ca. 70 min".
  ///
  /// Dieselbe Liste bei jedem Zugriff, nicht nur eine gleiche.
  static List<WorkoutDefinition> get all => _all;

  /// Die Templates, deren `id` nicht in [knownIds] steht.
  ///
  /// [knownIds] enthält lebende **und** gelöschte — das ist der Tombstone als
  /// reine Funktion: Ein gelöschtes Template kommt nicht wieder. Der Vergleich
  /// unterscheidet die Schreibweise.
  static List<WorkoutDefinition> missing(Set<String> knownIds) => [
    for (final template in _all)
      if (!knownIds.contains(template.id)) template,
  ];

  /// Das Template zu einer Kennung, `null` bei unbekannter — auch für `A`
  /// bis `D`, die keine Templates sind.
  static WorkoutDefinition? byId(String id) {
    for (final template in _all) {
      if (template.id == id) return template;
    }
    return null;
  }

  /// Die Definition eines Enum-Workouts, auch für Gym A–D.
  ///
  /// **Das Netz, keine Tür:** Sie trägt die Erfassung der Enum-Workouts, damit
  /// ein laufender Entwurf mit Code `A`–`D` nicht unsichtbar wird. Sie wird nie
  /// eingespielt und taucht weder in [all] noch in [missing] noch in [byId]
  /// auf — kein Tombstone-Pfad für A–D.
  ///
  /// Name wie bei den Templates; die eingetragene Dauer ist [Workout.minutes]
  /// (sonst fiele die Vorbelegung eines laufenden Entwurfs still auf die
  /// Schätzung), die Tags sind leer, die Kategorie ist `template` — folgenlos,
  /// weil die Definition nirgends abgelegt wird.
  static WorkoutDefinition fromEnum(Workout workout) =>
      _build(workout, tags: const []);

  /// Die Kennungen der gespeicherten Rotation zum Start: die Kennungen von
  /// [all], in deren Reihenfolge, ohne Wochentage.
  static List<String> get initialRotation => [
    for (final template in _all) template.id,
  ];

  static WorkoutDefinition _build(
    Workout workout, {
    required List<String> tags,
  }) => WorkoutDefinition(
    id: workout.code,
    name: WorkoutNaming.workoutName(workout),
    category: WorkoutCategory.template,
    tags: tags,
    exercises: List.unmodifiable([
      for (final exercise in ExerciseCatalog.exercisesFor(workout))
        WorkoutExercise.fromCatalog(exercise),
    ]),
    enteredMinutes: workout.minutes,
  );
}
