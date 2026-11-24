// Die eine Prüfung eines Trainings, die Editor, Repository und Import
// gemeinsam benutzen (#532, Spec 5.2).

import 'exercise_library.dart';
import 'workout_definition.dart';
import 'workout_tags.dart';

/// Prüft ein Training gegen die Regeln aus Spec 5.2.
///
/// **Die Zahlen sind ein Vorschlag der Spec, keine Entscheidung des
/// Nutzers**; entschieden ist nur, dass ein leeres Training sich nicht
/// speichern lässt und ein Zwischenstand unfertig sein darf.
abstract final class WorkoutRules {
  /// Höchstlänge des getrimmten Namens.
  static const int maxNameLength = 60;

  /// Sätze je Übung: 1 bis [maxSets].
  static const int maxSets = 10;

  /// Wiederholungen je Satz höchstens so viele …
  static const int maxReps = 100;

  /// … bei einer Zeitübung ([Exercise.isTimed]) Sekunden höchstens so viele.
  static const int maxSeconds = 600;

  /// Die eingetragene Dauer: `null` oder 1 bis [maxMinutes].
  static const int maxMinutes = 600;

  /// Alle Funde, in der Reihenfolge Name, Tags, Dauer, Übungen. **Leer heißt
  /// in Ordnung.** Wirft nie; meldet alle Funde statt nur den ersten, damit
  /// der Editor jeden Grund zeigen kann.
  ///
  /// Ein Entwurf ([WorkoutDefinition.isDraft]) wird nur auf seine **Gestalt**
  /// geprüft: Grenzen und Dubletten ja, [NameEmpty] und [NoExercises] nein.
  ///
  /// Eine Übung, die der Katalog nicht kennt, wird als [UnknownExercise]
  /// gemeldet und im Übrigen wie jede andere geprüft (Sätze, Bereich) — dabei
  /// gilt die Grenze für Wiederholungen, denn ob sie eine Zeitübung wäre,
  /// weiß niemand.
  static List<WorkoutProblem> check(WorkoutDefinition definition) {
    final problems = <WorkoutProblem>[];
    final isDraft = definition.isDraft;

    final name = definition.name.trim();
    if (name.isEmpty) {
      if (!isDraft) problems.add(const NameEmpty());
    } else if (name.length > maxNameLength) {
      problems.add(const NameTooLong());
    }

    if (definition.tags.length > WorkoutTags.maxCount) {
      problems.add(const TooManyTags());
    }
    for (final tag in definition.tags) {
      if (tag.length > WorkoutTags.maxLength) problems.add(TagInvalid(tag));
    }

    final minutes = definition.enteredMinutes;
    if (minutes != null && (minutes < 1 || minutes > maxMinutes)) {
      problems.add(const MinutesOutOfRange());
    }

    if (definition.exercises.isEmpty && !isDraft) {
      problems.add(const NoExercises());
    }

    final seen = <String>{};
    for (final exercise in definition.exercises) {
      final id = exercise.exerciseId;
      final known = ExerciseLibrary.byId(id);
      if (known == null) problems.add(UnknownExercise(id));
      // Jede Wiederholung einer ID ist ein Fund, nicht erst die zweite
      // Zeile: Der Editor nennt die Übung bei jeder überzähligen Zeile.
      if (!seen.add(id)) problems.add(DuplicateExercise(id));

      if (exercise.sets < 1 || exercise.sets > maxSets) {
        problems.add(SetsOutOfRange(id));
      }
      final limit = (known?.isTimed ?? false) ? maxSeconds : maxReps;
      if (exercise.repLow < 1 ||
          exercise.repHigh < exercise.repLow ||
          exercise.repHigh > limit) {
        problems.add(RepsInvalid(id));
      }
    }

    return problems;
  }
}

/// Ein Fund der Prüfung. Sealed, damit ein `switch` über alle Fälle
/// vollständig sein muss, wenn jemand einen weiteren ergänzt.
///
/// Jeder Fall ist ein Werttyp mit [==] und [hashCode]; zwei verschiedene Fälle
/// sind nie gleich, auch wenn beide nichts tragen.
sealed class WorkoutProblem {
  const WorkoutProblem();
}

/// Der getrimmte Name ist leer (nur bei einem fertigen Training).
final class NameEmpty extends WorkoutProblem {
  const NameEmpty();

  @override
  bool operator ==(Object other) => other is NameEmpty;

  @override
  int get hashCode => (NameEmpty).hashCode;

  @override
  String toString() => 'NameEmpty()';
}

/// Der getrimmte Name hat mehr als [WorkoutRules.maxNameLength] Zeichen.
final class NameTooLong extends WorkoutProblem {
  const NameTooLong();

  @override
  bool operator ==(Object other) => other is NameTooLong;

  @override
  int get hashCode => (NameTooLong).hashCode;

  @override
  String toString() => 'NameTooLong()';
}

/// Ein fertiges Training ohne eine einzige Übung.
final class NoExercises extends WorkoutProblem {
  const NoExercises();

  @override
  bool operator ==(Object other) => other is NoExercises;

  @override
  int get hashCode => (NoExercises).hashCode;

  @override
  String toString() => 'NoExercises()';
}

/// Die Übung steht nicht im Katalog.
final class UnknownExercise extends WorkoutProblem {
  const UnknownExercise(this.exerciseId);

  final String exerciseId;

  @override
  bool operator ==(Object other) =>
      other is UnknownExercise && other.exerciseId == exerciseId;

  @override
  int get hashCode => Object.hash(UnknownExercise, exerciseId);

  @override
  String toString() => 'UnknownExercise($exerciseId)';
}

/// Die Übung steht mehr als einmal im Training.
final class DuplicateExercise extends WorkoutProblem {
  const DuplicateExercise(this.exerciseId);

  final String exerciseId;

  @override
  bool operator ==(Object other) =>
      other is DuplicateExercise && other.exerciseId == exerciseId;

  @override
  int get hashCode => Object.hash(DuplicateExercise, exerciseId);

  @override
  String toString() => 'DuplicateExercise($exerciseId)';
}

/// Die Satzzahl der Übung liegt nicht in 1 bis [WorkoutRules.maxSets].
final class SetsOutOfRange extends WorkoutProblem {
  const SetsOutOfRange(this.exerciseId);

  final String exerciseId;

  @override
  bool operator ==(Object other) =>
      other is SetsOutOfRange && other.exerciseId == exerciseId;

  @override
  int get hashCode => Object.hash(SetsOutOfRange, exerciseId);

  @override
  String toString() => 'SetsOutOfRange($exerciseId)';
}

/// Der Wiederholungsbereich der Übung ist ungültig: unter 1, verkehrt herum
/// oder über der Grenze ([WorkoutRules.maxReps], bei Zeitübungen
/// [WorkoutRules.maxSeconds]).
final class RepsInvalid extends WorkoutProblem {
  const RepsInvalid(this.exerciseId);

  final String exerciseId;

  @override
  bool operator ==(Object other) =>
      other is RepsInvalid && other.exerciseId == exerciseId;

  @override
  int get hashCode => Object.hash(RepsInvalid, exerciseId);

  @override
  String toString() => 'RepsInvalid($exerciseId)';
}

/// Mehr als [WorkoutTags.maxCount] Tags.
final class TooManyTags extends WorkoutProblem {
  const TooManyTags();

  @override
  bool operator ==(Object other) => other is TooManyTags;

  @override
  int get hashCode => (TooManyTags).hashCode;

  @override
  String toString() => 'TooManyTags()';
}

/// Der Tag ist länger als [WorkoutTags.maxLength] Zeichen.
final class TagInvalid extends WorkoutProblem {
  const TagInvalid(this.tag);

  final String tag;

  @override
  bool operator ==(Object other) => other is TagInvalid && other.tag == tag;

  @override
  int get hashCode => Object.hash(TagInvalid, tag);

  @override
  String toString() => 'TagInvalid($tag)';
}

/// Die eingetragene Dauer liegt nicht in 1 bis [WorkoutRules.maxMinutes].
final class MinutesOutOfRange extends WorkoutProblem {
  const MinutesOutOfRange();

  @override
  bool operator ==(Object other) => other is MinutesOutOfRange;

  @override
  int get hashCode => (MinutesOutOfRange).hashCode;

  @override
  String toString() => 'MinutesOutOfRange()';
}
