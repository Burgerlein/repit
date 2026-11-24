// Die Werttypen hinter „Eigene Trainings": Kategorie, Übungszeile und die
// Definition eines Trainings (#532, Spec 4.5, 5.1).

import 'exercise.dart';
import 'exercise_library.dart';
import 'workout_naming.dart';

/// Ob ein Training mit der App kam oder vom Nutzer stammt.
///
/// Die Codes stehen in der Datenbank (`CHECK kategorie IN ('template',
/// 'eigene')`), deshalb ausgeschrieben und nicht aus `name` abgeleitet:
/// `own` ist der Name des Dart-Falls, `'eigene'` der gespeicherte Wert.
enum WorkoutCategory {
  template('template'),
  own('eigene');

  const WorkoutCategory(this.code);

  final String code;

  /// Die Kategorie zu einem gespeicherten [code], `null` bei unbekanntem.
  ///
  /// Unterscheidet Groß- und Kleinschreibung. Geraten wird nicht: Eine
  /// stillschweigende Zuordnung machte aus einer fremden Zeile ein Template
  /// oder ein Eigenes.
  static WorkoutCategory? fromCode(String code) {
    for (final kategorie in values) {
      if (kategorie.code == code) return kategorie;
    }
    return null;
  }
}

/// Eine Übung innerhalb eines Trainings: welche, wie viele Sätze, welcher
/// Wiederholungsbereich.
///
/// Werttyp mit [==] und [hashCode] über **alle** Felder (`CLAUDE.md`, Fehler
/// `03`).
final class WorkoutExercise {
  const WorkoutExercise({
    required this.exerciseId,
    required this.sets,
    required this.repLow,
    required this.repHigh,
    this.increment,
  });

  /// Übernimmt Sätze und Wiederholungsbereich der Katalogübung.
  ///
  /// [increment] bleibt `null` und heißt damit „die des Katalogs"; eine
  /// eigene Steigerung je Übung gibt es in dieser Stufe nicht (#537).
  factory WorkoutExercise.fromCatalog(Exercise exercise) => WorkoutExercise(
    exerciseId: exercise.id,
    sets: exercise.sets,
    repLow: exercise.repLow,
    repHigh: exercise.repHigh,
  );

  /// Die [Exercise.id] aus dem Katalog.
  final String exerciseId;

  final int sets;

  /// Bei Zeitübungen ([Exercise.isTimed]) in Sekunden.
  final int repLow;
  final int repHigh;

  /// Schrittweite in kg, `null` = die der Bibliothek.
  final double? increment;

  /// Die Bibliotheksübung mit den Sätzen, dem Bereich und der Steigerung
  /// **dieses Trainings**, `null` bei einer ID, die die Bibliothek nicht
  /// kennt.
  ///
  /// Auf diesem Weg benutzen die Erfassung und `Progression.suggest` den
  /// Bereich des Trainings und nicht den der Bibliothek. Alle übrigen Felder
  /// bleiben unverändert.
  Exercise? resolve() {
    final bibliothek = ExerciseLibrary.byId(exerciseId);
    if (bibliothek == null) return null;
    return bibliothek.withPlan(
      sets: sets,
      repLow: repLow,
      repHigh: repHigh,
      increment: increment ?? bibliothek.increment,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is WorkoutExercise &&
      other.exerciseId == exerciseId &&
      other.sets == sets &&
      other.repLow == repLow &&
      other.repHigh == repHigh &&
      other.increment == increment;

  @override
  int get hashCode => Object.hash(exerciseId, sets, repLow, repHigh, increment);

  @override
  String toString() => 'WorkoutExercise($exerciseId, $sets × $repLow–$repHigh)';
}

/// Ein Training: Name, Tags, Übungen in ihrer Reihenfolge, eine eingetragene
/// Dauer.
///
/// Werttyp mit [==] und [hashCode] über **alle** Felder; die Listen werden
/// **inhaltlich und in ihrer Reihenfolge** verglichen — Darts `==` auf `List`
/// ist Identität (Fehler `03`).
///
/// **Keine berechneten Eigenschaften, die ein Schirm je Bild liest** (Hausregel
/// 2): Dauer, Muskeln und Zählungen rechnet der Provider einmal.
final class WorkoutDefinition {
  const WorkoutDefinition({
    required this.id,
    required this.name,
    required this.category,
    required this.tags,
    required this.exercises,
    this.enteredMinutes,
    this.isDraft = false,
  });

  /// Bei Templates der `Workout.code`, bei Eigenen eine UUID.
  final String id;

  final String name;
  final WorkoutCategory category;

  /// Die Tags in der Reihenfolge, in der sie angezeigt werden.
  final List<String> tags;

  /// Die Übungen in der Reihenfolge des Trainings.
  final List<WorkoutExercise> exercises;

  /// Die vom Nutzer eingetragene Dauer in Minuten. `null` heißt „geschätzt"
  /// (`WorkoutDuration`) und ist nicht 0.
  final int? enteredMinutes;

  /// Ein Zwischenstand des Editors, noch kein fertiges Training.
  final bool isDraft;

  /// Die Kopie für „Bearbeiten" an einem Template (Spec 4.5): ein neues
  /// Eigenes unter [id], Name `'${shortName} (Kopie)'`, kein Entwurf.
  ///
  /// Tags, Übungen und eingetragene Dauer wandern mit; eine geschätzte Dauer
  /// bleibt `null`. Die Methode legt nichts ab — sie rechnet nur.
  WorkoutDefinition copyAsOwn({required String id}) => WorkoutDefinition(
    id: id,
    name: '${WorkoutNaming.shortName(name)} (Kopie)',
    category: WorkoutCategory.own,
    tags: tags,
    exercises: exercises,
    enteredMinutes: enteredMinutes,
    isDraft: false,
  );

  @override
  bool operator ==(Object other) =>
      other is WorkoutDefinition &&
      other.id == id &&
      other.name == name &&
      other.category == category &&
      other.enteredMinutes == enteredMinutes &&
      other.isDraft == isDraft &&
      _sameList(other.tags, tags) &&
      _sameList(other.exercises, exercises);

  @override
  int get hashCode => Object.hash(
    id,
    name,
    category,
    Object.hashAll(tags),
    Object.hashAll(exercises),
    enteredMinutes,
    isDraft,
  );

  @override
  String toString() => 'WorkoutDefinition($id, $name, ${category.code})';
}

/// Inhaltlicher Vergleich zweier Listen — die Reihenfolge zählt.
///
/// Von Hand geschrieben statt über `package:collection`: Der Kern importiert
/// nur `dart:core` und `dart:math` (`test/import_boundary_test.dart`).
bool _sameList<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
