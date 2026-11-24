import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für **`WorkoutMuscles`** — welche Muskeln ein Training trifft und
/// wie stark (#532). Spec
/// `docs/superpowers/specs/2026-11-19-eigene-trainings-design.md`,
/// Abschnitt 5.5 und 21.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, nie verändert werden. Hält der
/// Implementierende eine Erwartung für falsch, wird das **gemeldet, nicht
/// korrigiert**.
///
/// ## Wer hat was entschieden
///
/// - **Entscheidung von Tim:** Die Kachel färbt „die Muskeln dieses
///   Trainings" **einfarbig** (19.11.2026, Kopf von `gym-trainings.js`: „trifft
///   diese Muskeln, nicht wie viel"). Das Gewicht dient nicht der Farbstärke.
/// - **Folgerung aus dem Code:** Die Gewichte 1,0 und 0,5 sind
///   `Exercise.muscles`; `weightedSets` rechnet wie `MuscleVolume.weeklySets`,
///   nur auf **geplante** Sätze und ohne Zeitfenster.
/// - **Vorschlag der Spec, hier vorausgesetzt (17.9):** **Haupt- und
///   Nebenmuskeln** färben, keine Satzschwelle. Ob Nebenmuskeln mitfärben,
///   hat Tim nicht gesagt.
///
/// ## Woher die Kontrollwerte kommen
///
/// **Nicht** aus den Beispielen der Entwürfe (erfunden) und **nicht** aus dem
/// alten Gym-A-Beispiel der Spec 5.5, sondern von Hand aus `Exercise.muscles`
/// und den Sätzen des Katalogs gerechnet. Jede Zeile gilt Sätze × Gewicht:
///
/// ```
/// PUSH
/// benchPress 4          chest 1 · frontDelt .5 · triceps .5   → 4 · 2 · 2
/// inclineDumbbellPress 3 chest 1 · frontDelt .5 · triceps .5   → 3 · 1,5 · 1,5
/// shoulderPressMachine 3 frontDelt 1 · sideDelt .5 · triceps .5 → 3 · 1,5 · 1,5
/// cableFly 3            chest 1                                → 3
/// lateralRaise 4        sideDelt 1                             → 4
/// tricepsPushdown 3     triceps 1                              → 3
/// overheadTriceps 3     triceps 1                              → 3
/// ⇒ chest 10 · frontDelt 6,5 · sideDelt 5,5 · triceps 11
///
/// PULL
/// pullUp 4              lats 1 · biceps .5 · rearDelt .5       → 4 · 2 · 2
/// barbellRow 4          upperBack 1 · lats .5 · biceps .5 · lowerBack .5
///                                                              → 4 · 2 · 2 · 2
/// cableRowClose 3       upperBack 1 · lats .5 · biceps .5      → 3 · 1,5 · 1,5
/// straightArmPulldown 3 lats 1                                 → 3
/// facePull 3            rearDelt 1 · upperBack .5              → 3 · 1,5
/// backExtension 3       lowerBack 1 · glutes .5 · hamstrings .5 → 3 · 1,5 · 1,5
/// hammerCurl 3          biceps 1 · forearms 1                  → 3 · 3
/// ⇒ lats 10,5 · biceps 8,5 · rearDelt 5 · upperBack 8,5 · lowerBack 5
///   · glutes 1,5 · hamstrings 1,5 · forearms 3
///
/// LEGS
/// legPress 4            quads 1 · glutes .5                    → 4 · 2
/// romanianDeadlift 3    hamstrings 1 · glutes .5 · lowerBack .5 → 3 · 1,5 · 1,5
/// splitSquat 3          quads 1 · glutes 1                     → 3 · 3
/// legCurl 3             hamstrings 1                           → 3
/// hipAbduction 3        glutes 1                               → 3
/// calfRaiseStanding 6   calves 1                               → 6
/// legExtension 3        quads 1                                → 3
/// ⇒ quads 10 · glutes 9,5 · hamstrings 6 · lowerBack 1,5 · calves 6
/// ```
///
/// ## API, die diese Tests verbindlich vorgeben
///
/// Neue Datei `lib/src/workout_muscles.dart`, dazu die Export-Zeile in
/// `lib/trainings_core.dart`.
///
/// ```dart
/// abstract final class WorkoutMuscles {
///   static Map<Muscle, double> weightedSets(List<WorkoutExercise> exercises);
///   static Set<Muscle> trained(List<WorkoutExercise> exercises);
/// }
/// ```
///
/// ## Was hier **nicht** getestet wird
///
/// - **Ob `weightedSets` Muskeln mit 0 als Eintrag führt.** Die Spec sagt
///   „je Muskel die Summe", nicht, ob ein unberührter Muskel fehlt oder auf
///   0 steht. Die Tests lesen deshalb jeden der 16 Muskeln mit `?? 0`;
///   `trained` ist über `> 0` festgelegt und bleibt davon unberührt.

WorkoutExercise uebung(String id, {required int sets}) => WorkoutExercise(
  exerciseId: id,
  sets: sets,
  repLow: 8,
  repHigh: 12,
  increment: null,
);

List<WorkoutExercise> ausKatalog(Workout workout) => [
  for (final exercise in ExerciseCatalog.exercisesFor(workout))
    WorkoutExercise.fromCatalog(exercise),
];

/// Prüft **alle 16** Muskeln gegen die Erwartung; was nicht genannt ist,
/// muss 0 sein.
void erwarteGewichte(Map<Muscle, double> ist, Map<Muscle, double> erwartet) {
  for (final muskel in Muscle.values) {
    expect(
      ist[muskel] ?? 0,
      erwartet[muskel] ?? 0,
      reason: 'Muskel ${muskel.code}',
    );
  }
}

void main() {
  // -------------------------------------------------------------------------
  group('Push — Kontrollwerte aus dem Katalog', () {
    test('Gewichtete Sätze je Muskel', () {
      erwarteGewichte(WorkoutMuscles.weightedSets(ausKatalog(Workout.push)), {
        Muscle.chest: 10,
        Muscle.frontDelt: 6.5,
        Muscle.sideDelt: 5.5,
        Muscle.triceps: 11,
      });
    });

    test('Trainiert sind Haupt- und Nebenmuskeln', () {
      expect(WorkoutMuscles.trained(ausKatalog(Workout.push)), {
        Muscle.chest,
        Muscle.frontDelt,
        Muscle.sideDelt,
        Muscle.triceps,
      });
    });
  });

  group('Pull — Kontrollwerte aus dem Katalog', () {
    test('Gewichtete Sätze je Muskel', () {
      erwarteGewichte(WorkoutMuscles.weightedSets(ausKatalog(Workout.pull)), {
        Muscle.lats: 10.5,
        Muscle.biceps: 8.5,
        Muscle.rearDelt: 5,
        Muscle.upperBack: 8.5,
        Muscle.lowerBack: 5,
        Muscle.glutes: 1.5,
        Muscle.hamstrings: 1.5,
        Muscle.forearms: 3,
      });
    });

    test('Trainiert sind Haupt- und Nebenmuskeln', () {
      expect(WorkoutMuscles.trained(ausKatalog(Workout.pull)), {
        Muscle.lats,
        Muscle.biceps,
        Muscle.rearDelt,
        Muscle.upperBack,
        Muscle.lowerBack,
        Muscle.glutes,
        Muscle.hamstrings,
        Muscle.forearms,
      });
    });
  });

  group('Legs — Kontrollwerte aus dem Katalog', () {
    test('Gewichtete Sätze je Muskel', () {
      erwarteGewichte(WorkoutMuscles.weightedSets(ausKatalog(Workout.legs)), {
        Muscle.quads: 10,
        Muscle.glutes: 9.5,
        Muscle.hamstrings: 6,
        Muscle.lowerBack: 1.5,
        Muscle.calves: 6,
      });
    });

    test('Trainiert sind Haupt- und Nebenmuskeln', () {
      expect(WorkoutMuscles.trained(ausKatalog(Workout.legs)), {
        Muscle.quads,
        Muscle.glutes,
        Muscle.hamstrings,
        Muscle.lowerBack,
        Muscle.calves,
      });
    });
  });

  // -------------------------------------------------------------------------
  group('Die Gewichtung', () {
    test('Hauptmuskel 1,0, Nebenmuskel 0,5 je geplantem Satz', () {
      // Bankdrücken: Brust 1, vordere Schulter 0,5, Trizeps 0,5. Mit zwei
      // Sätzen: 2 · 1 · 1.
      erwarteGewichte(
        WorkoutMuscles.weightedSets([uebung('benchPress', sets: 2)]),
        {Muscle.chest: 2, Muscle.frontDelt: 1, Muscle.triceps: 1},
      );
    });

    test('Es zählen die Sätze des Trainings, nicht die des Katalogs', () {
      // Der Katalog sagt 4 Sätze Bankdrücken; das Training 7.
      erwarteGewichte(
        WorkoutMuscles.weightedSets([uebung('benchPress', sets: 7)]),
        {Muscle.chest: 7, Muscle.frontDelt: 3.5, Muscle.triceps: 3.5},
      );
    });

    test('Derselbe Muskel aus mehreren Übungen addiert sich', () {
      // Trizeps: Bankdrücken 3 × 0,5 + Trizepsdrücken 4 × 1 = 5,5.
      erwarteGewichte(
        WorkoutMuscles.weightedSets([
          uebung('benchPress', sets: 3),
          uebung('tricepsPushdown', sets: 4),
        ]),
        {Muscle.chest: 3, Muscle.frontDelt: 1.5, Muscle.triceps: 5.5},
      );
    });

    test('Ein Muskel, den keine Übung trifft, hat kein Gewicht', () {
      final gewichte = WorkoutMuscles.weightedSets([
        uebung('lateralRaise', sets: 4),
      ]);
      expect(gewichte[Muscle.sideDelt], 4);
      expect(gewichte[Muscle.chest] ?? 0, 0);
      expect(gewichte[Muscle.calves] ?? 0, 0);
    });
  });

  // -------------------------------------------------------------------------
  group('Trainiert: jeder Muskel mit Gewicht über null', () {
    test('Hauptmuskel und Nebenmuskel färben beide', () {
      // Bankdrücken: Brust (1,0) **und** vordere Schulter und Trizeps (0,5).
      expect(WorkoutMuscles.trained([uebung('benchPress', sets: 3)]), {
        Muscle.chest,
        Muscle.frontDelt,
        Muscle.triceps,
      });
    });

    test('Eine Übung mit nur einem Muskel färbt nur ihn', () {
      expect(WorkoutMuscles.trained([uebung('lateralRaise', sets: 4)]), {
        Muscle.sideDelt,
      });
    });

    test('Die Menge kennt jeden Muskel einmal, egal wie oft er vorkommt', () {
      expect(
        WorkoutMuscles.trained([
          uebung('lateralRaise', sets: 4),
          uebung('lateralRaise', sets: 2),
        ]),
        {Muscle.sideDelt},
      );
    });

    test('Die Färbung richtet sich nicht nach der Satzzahl', () {
      // Einfarbig: ein einzelner Satz färbt genauso wie zehn (Tim,
      // 19.11.2026 — „trifft diese Muskeln, nicht wie viel").
      expect(
        WorkoutMuscles.trained([uebung('tricepsPushdown', sets: 1)]),
        WorkoutMuscles.trained([uebung('tricepsPushdown', sets: 10)]),
      );
    });

    test('Die Färbung stimmt mit den gewichteten Sätzen überein', () {
      for (final workout in [Workout.push, Workout.pull, Workout.legs]) {
        final uebungen = ausKatalog(workout);
        final gewichte = WorkoutMuscles.weightedSets(uebungen);
        final gefaerbt = WorkoutMuscles.trained(uebungen);
        for (final muskel in Muscle.values) {
          expect(
            gefaerbt.contains(muskel),
            (gewichte[muskel] ?? 0) > 0,
            reason: '${workout.code}: ${muskel.code}',
          );
        }
      }
    });
  });

  // -------------------------------------------------------------------------
  group('Ein leeres Training färbt nichts', () {
    test('Keine Übung, keine Gewichte', () {
      erwarteGewichte(WorkoutMuscles.weightedSets([]), {});
    });

    test('Keine Übung, keine Muskeln — keine Ausnahme', () {
      expect(WorkoutMuscles.trained([]), isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  group('Unbekannte Übungs-IDs tragen nichts bei', () {
    test('Eine unbekannte Übung ändert die Gewichte nicht', () {
      erwarteGewichte(
        WorkoutMuscles.weightedSets([
          uebung('lateralRaise', sets: 4),
          uebung('gibtEsNicht', sets: 9),
        ]),
        {Muscle.sideDelt: 4},
      );
    });

    test('Eine unbekannte Übung färbt nichts', () {
      expect(WorkoutMuscles.trained([uebung('gibtEsNicht', sets: 3)]), isEmpty);
      expect(
        WorkoutMuscles.trained([
          uebung('lateralRaise', sets: 3),
          uebung('gibtEsNicht', sets: 3),
        ]),
        {Muscle.sideDelt},
      );
    });

    test('Nur Unbekanntes ergibt keine Gewichte', () {
      erwarteGewichte(
        WorkoutMuscles.weightedSets([uebung('gibtEsNicht', sets: 3)]),
        {},
      );
    });
  });
}
