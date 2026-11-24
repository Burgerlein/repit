// Die Reihenfolge der Übungen innerhalb einer Sitzung, portiert aus dem
// paketinternen `GymSessionOrder` in
// `Packages/TrainingsCore/Sources/TrainingsCore/Gym/GymSessionBuilder.swift`
// (#91).

import 'exercise.dart';
import 'exercise_catalog.dart';

/// Die Reihenfolge der Übungen innerhalb einer Sitzung.
///
/// Dieselbe Regel für übernommene und eigene Trainings — sonst stünde
/// dieselbe Sitzung je nach Herkunft anders da. Eine Map hat keine
/// verlässliche Fachreihenfolge, und eine Ansicht, die bei jedem Start
/// anders aussieht, ist kaputt.
///
/// **Eigene Datei, anders als in Swift**, wo das paketintern im Builder
/// liegt: Der Dashboard-Parser aus #59 braucht dieselbe Regel. Versteckt im
/// Builder müsste er sie später herausziehen oder doppeln.
abstract final class GymSessionOrder {
  /// Übungs-IDs in der Reihenfolge des Trainings; was dort nicht steht,
  /// hängt alphabetisch nach ID dahinter.
  ///
  /// Die Reihenfolge kommt aus [trainingOrder], wenn sie gegeben ist — das
  /// ist die Übungsliste eines eigenen Trainings, und sie gilt **statt** der
  /// des Katalogs für [workout]. Ohne sie gilt `ExerciseCatalog.exercisesFor`.
  /// IDs, die nur in der Reihenfolge stehen und nicht in [exerciseIds],
  /// kommen nicht vor.
  ///
  /// Mehrfach genannte IDs kommen einmal heraus. Bei `workout == null` und
  /// ohne [trainingOrder] steht alles alphabetisch.
  static List<String> ordered(
    Iterable<String> exerciseIds,
    Workout? workout, {
    List<String>? trainingOrder,
  }) {
    final vorhanden = exerciseIds.toSet();

    final Iterable<String> reihenfolge =
        trainingOrder ??
        [
          if (workout != null)
            for (final exercise in ExerciseCatalog.exercisesFor(workout))
              exercise.id,
        ];

    final geplant = <String>[];
    final geplanteIds = <String>{};
    for (final id in reihenfolge) {
      if (vorhanden.contains(id) && geplanteIds.add(id)) geplant.add(id);
    }

    final rest = vorhanden.where((id) => !geplanteIds.contains(id)).toList()
      ..sort();

    return [...geplant, ...rest];
  }
}
