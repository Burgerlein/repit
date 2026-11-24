import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für **`WorkoutDuration`** — die geschätzte Dauer eines Trainings
/// (#532). Spec `docs/superpowers/specs/2026-11-19-eigene-trainings-design.md`,
/// Abschnitt 5.3 und 21.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, nie verändert werden. Hält der
/// Implementierende eine Erwartung für falsch, wird das **gemeldet, nicht
/// korrigiert**.
///
/// ## Wer hat was entschieden
///
/// - **Entscheidung von Tim:** Die Dauer wird aus Übungen und Sätzen
///   **geschätzt** und lässt sich überschreiben, jederzeit zurück auf die
///   Schätzung (18./19.11.2026). **Nur das.**
/// - **Vorschlag der Spec, hier vorausgesetzt (17.8):** die Formel und ihre
///   Zahlen — 90 s Rüstzeit je Übung, 45 s Arbeit je Satz (bei Zeitübungen
///   der Mittelwert des Bereichs in Sekunden), `RestGuidance`-Pause nach
///   jedem Satz außer dem letzten, durch 60, auf 5 Minuten gerundet, bei
///   genau halber Distanz nach oben, Mindestwert 5. **Die Formel liegt 5–20
///   Minuten unter Tims „~70" der SPEC; ob sie nachkalibriert wird, ist
///   offen.** Wird sie geändert, brechen die Kontrollwerte unten — das ist
///   gewollt, sie stehen als Zahlen da.
/// - **Festlegung des Test-Agenten:** die Rundungsfälle (sie rechnen die
///   Spec-Formel von Hand durch) und die Entscheidung, dass die Konstanten
///   als Zahlen festgenagelt werden.
///
/// ## Wie hier gerechnet wird
///
/// Jeder Erwartungswert ist **von Hand aus dem Katalog gerechnet** und steht
/// als Zahl da, nie als nachgebaute Formel. Kontrollrechnung, beispielhaft
/// für Push (Katalogwerte, Pause nach `RestGuidance`: `repHigh ≤ 10` 150 s,
/// `≤ 15` 90 s, sonst 60 s, Zeitübung 45 s):
///
/// ```
/// Übung                  Sätze  Bereich  Pause   (Sätze−1)×Pause
/// benchPress               4    6–10     150     450
/// inclineDumbbellPress     3    8–12      90     180
/// shoulderPressMachine     3    8–12      90     180
/// cableFly                 3    12–15     90     180
/// lateralRaise             4    12–20     60     180
/// tricepsPushdown          3    10–15     90     180
/// overheadTriceps          3    10–15     90     180
/// Rüstzeit      7 × 90                     =  630
/// Arbeit       23 × 45                     = 1035
/// Pausen                                   = 1530
/// Summe 3195 s = 53,25 min → auf 5 gerundet 55
/// ```
///
/// Pull: Pausen 1560, Sätze 23 → 3225 s = 53,75 min → 55.
/// Legs: Pausen 1680, Sätze 25 (Wadenheben 6) → 3435 s = 57,25 min → 55.
///
/// ## API, die diese Tests verbindlich vorgeben
///
/// Neue Datei `lib/src/workout_duration.dart`, dazu die Export-Zeile in
/// `lib/trainings_core.dart`.
///
/// ```dart
/// abstract final class WorkoutDuration {
///   static const int workSecondsPerSet;        // 45
///   static const int setupSecondsPerExercise;  // 90
///   static const int roundToMinutes;           // 5
///   static int? estimate(List<WorkoutExercise> exercises);
///   static int? effective({int? entered, required List<WorkoutExercise> exercises});
/// }
/// ```
///
/// Die Konstanten sind **öffentlich** (Spec 5.3), damit ein Test gegen sie
/// prüfen kann; ihre Werte stehen hier trotzdem als Literal — eine
/// Konstante, die sich unbemerkt ändert, würde sonst Test und Rechnung
/// gemeinsam verschieben.
///
/// ## Was hier **nicht** getestet wird
///
/// - **Eine Liste nur aus unbekannten Übungen.** Die Spec sagt „unbekannte
///   ID trägt nichts bei" und „keine Übung → `null`, nicht 0"; ob eine Liste,
///   die nur Unbekanntes enthält, `null` oder den Mindestwert 5 ergibt, sagt
///   sie nicht. Gemeldet, nicht entschieden.
/// - **`effective` mit eingetragener 0** — `0 ?? x` ist 0; die Grenze 1–600
///   prüft `WorkoutRules`.

WorkoutExercise uebung(
  String id, {
  required int sets,
  required int repLow,
  required int repHigh,
}) => WorkoutExercise(
  exerciseId: id,
  sets: sets,
  repLow: repLow,
  repHigh: repHigh,
  increment: null,
);

/// Die Katalogübungen eines Workouts als Übungsliste eines Trainings.
List<WorkoutExercise> ausKatalog(Workout workout) => [
  for (final exercise in ExerciseCatalog.exercisesFor(workout))
    WorkoutExercise.fromCatalog(exercise),
];

void main() {
  // -------------------------------------------------------------------------
  group('Die Konstanten der Formel', () {
    test('Rüstzeit 90 s, Arbeitszeit 45 s, Rundung auf 5 Minuten', () {
      expect(WorkoutDuration.setupSecondsPerExercise, 90);
      expect(WorkoutDuration.workSecondsPerSet, 45);
      expect(WorkoutDuration.roundToMinutes, 5);
    });
  });

  // -------------------------------------------------------------------------
  group('Kontrollwerte der ausgelieferten Templates (Spec 5.3)', () {
    test('Push: 3195 s = 53,25 min, gerundet 55', () {
      expect(WorkoutDuration.estimate(ausKatalog(Workout.push)), 55);
    });

    test('Pull: 3225 s = 53,75 min, gerundet 55', () {
      expect(WorkoutDuration.estimate(ausKatalog(Workout.pull)), 55);
    });

    test('Legs: 3435 s = 57,25 min, gerundet 55', () {
      // Hier zeigt sich, dass nach unten gerundet wird, wo es näher liegt:
      // 57,25 liegt 2,25 über 55 und 2,75 unter 60.
      expect(WorkoutDuration.estimate(ausKatalog(Workout.legs)), 55);
    });
  });

  group('Kontrollwerte der enum-abgeleiteten Definitionen (Spec 5.3)', () {
    // Gym A–D sind keine Templates mehr (Spec 23), bleiben aber als
    // Enum-Fälle — `WorkoutTemplates.fromEnum` trägt ihre Erfassung. Ihre
    // Kontrollwerte bleiben, weil sie dieselbe Formel gegen vier weitere
    // Übungslisten prüfen, darunter die einzige mit einer Zeitübung.

    test('Gym A: 3195 s = 53,25 min, gerundet 55', () {
      expect(WorkoutDuration.estimate(ausKatalog(Workout.a)), 55);
    });

    test('Gym B: 3532,5 s = 58,875 min, gerundet 60', () {
      // Enthält den Seitstütz: 3 Sätze × (30 + 45) / 2 = 112,5 s Arbeit.
      expect(WorkoutDuration.estimate(ausKatalog(Workout.b)), 60);
    });

    test('Gym C: 3090 s = 51,5 min, gerundet 50', () {
      expect(WorkoutDuration.estimate(ausKatalog(Workout.c)), 50);
    });

    test('Gym D: 3000 s = 50 min, genau 50', () {
      expect(WorkoutDuration.estimate(ausKatalog(Workout.d)), 50);
    });
  });

  // -------------------------------------------------------------------------
  group('Einzelne Übungen, von Hand gerechnet', () {
    test('Bankdrücken 4 × 6–10: 90 + 4×45 + 3×150 = 720 s = 12 min → 10', () {
      expect(
        WorkoutDuration.estimate([
          uebung('benchPress', sets: 4, repLow: 6, repHigh: 10),
        ]),
        10,
      );
    });

    test(
      'Ein Satz hat keine Pause: 90 + 45 = 135 s = 2,25 min → Mindestwert 5',
      () {
        expect(
          WorkoutDuration.estimate([
            uebung('lateralRaise', sets: 1, repLow: 12, repHigh: 20),
          ]),
          5,
        );
      },
    );

    test('Die Pause hängt am Bereich des Trainings, nicht des Katalogs', () {
      // Bankdrücken mit 6 Sätzen. Katalog (6–10, Pause 150 s):
      //   90 + 6×45 + 5×150 = 1110 s = 18,5 min → 20.
      // Training 8–15 (Pause 90 s):
      //   90 + 6×45 + 5×90 = 810 s = 13,5 min → 15.
      // Die beiden Ergebnisse unterscheiden sich — nur so beweist der Fall,
      // welcher Bereich benutzt wurde.
      expect(
        WorkoutDuration.estimate([
          uebung('benchPress', sets: 6, repLow: 8, repHigh: 15),
        ]),
        15,
      );
    });

    test('Ein Bereich bis 20 Wiederholungen hat nur 60 s Pause', () {
      // 90 + 6×45 + 5×60 = 660 s = 11 min → 10.
      expect(
        WorkoutDuration.estimate([
          uebung('benchPress', sets: 6, repLow: 8, repHigh: 20),
        ]),
        10,
      );
    });

    test('Eine Zeitübung arbeitet so lange, wie ihr Bereich sagt', () {
      // Seitstütz 6 × 60–120 s: Mittelwert 90 s, Pause 45 s.
      //   90 + 6×90 + 5×45 = 855 s = 14,25 min → 15.
      // Mit 45 s Arbeit je Satz wären es 585 s = 9,75 min → 10 — der Fall
      // trennt die beiden Lesarten.
      expect(
        WorkoutDuration.estimate([
          uebung('sidePlank', sets: 6, repLow: 60, repHigh: 120),
        ]),
        15,
      );
    });

    test(
      'Die Zeitübung des Katalogs: 3 × 30–45 s → 292,5 s = 4,875 min → 5',
      () {
        // 90 + 3×37,5 + 2×45 = 292,5 s.
        expect(
          WorkoutDuration.estimate([
            uebung('sidePlank', sets: 3, repLow: 30, repHigh: 45),
          ]),
          5,
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  group('Die Rundung auf volle 5 Minuten', () {
    test('Genau auf einem Vielfachen von 5 bleibt es dort', () {
      // Gym D: 3000 s = 50,0 min.
      expect(WorkoutDuration.estimate(ausKatalog(Workout.d)), 50);
    });

    test('Bei genau halber Distanz wird aufgerundet', () {
      // Seitheben 4 × 12–20 (Pause 60 s):
      //   90 + 4×45 + 3×60 = 450 s = 7,5 min.
      // 7,5 liegt genau zwischen 5 und 10 → 10, nicht 5.
      expect(
        WorkoutDuration.estimate([
          uebung('lateralRaise', sets: 4, repLow: 12, repHigh: 20),
        ]),
        10,
      );
    });

    test('Bei genau halber Distanz zwischen anderen Vielfachen ebenso', () {
      // Bankdrücken 3 × 6–10: 90 + 3×45 + 2×150 = 525 s,
      // dazu Seitstütz 2 × 30–60 (Mittelwert 45 s, Pause 45 s):
      //   90 + 2×45 + 1×45 = 225 s.
      // Zusammen 750 s = 12,5 min — genau zwischen 10 und 15 → 15.
      expect(
        WorkoutDuration.estimate([
          uebung('benchPress', sets: 3, repLow: 6, repHigh: 10),
          uebung('sidePlank', sets: 2, repLow: 30, repHigh: 60),
        ]),
        15,
      );
    });

    test('Unter der halben Distanz wird abgerundet', () {
      // Kabel-Flys 3 × 12–15 (Pause 90 s): 90 + 3×45 + 2×90 = 405 s =
      // 6,75 min. 1,75 über 5 → 5.
      expect(
        WorkoutDuration.estimate([
          uebung('cableFly', sets: 3, repLow: 12, repHigh: 15),
        ]),
        5,
      );
    });

    test('Über der halben Distanz wird aufgerundet', () {
      // Kabel-Flys 4 × 12–15: 90 + 4×45 + 3×90 = 540 s = 9 min → 10.
      expect(
        WorkoutDuration.estimate([
          uebung('cableFly', sets: 4, repLow: 12, repHigh: 15),
        ]),
        10,
      );
    });

    test('Die Schätzung ist immer ein Vielfaches von 5', () {
      for (final workout in Workout.values) {
        final minuten = WorkoutDuration.estimate(ausKatalog(workout))!;
        expect(minuten % 5, 0, reason: workout.code);
      }
    });

    test('Der Mindestwert ist 5, nie weniger und nie 0', () {
      final minuten = WorkoutDuration.estimate([
        uebung('lateralRaise', sets: 1, repLow: 12, repHigh: 20),
      ]);
      expect(minuten, isNotNull);
      expect(minuten, greaterThanOrEqualTo(5));
    });
  });

  // -------------------------------------------------------------------------
  group('Keine Übung heißt null, nicht 0', () {
    // Fehler `01`: Die Dauer-Zeile des leeren Editors zeigt „–".
    test('Ein Training ohne Übung hat keine Schätzung', () {
      expect(WorkoutDuration.estimate([]), isNull);
    });

    test('Die Schätzung eines leeren Trainings ist nicht 0', () {
      expect(WorkoutDuration.estimate([]), isNot(0));
    });
  });

  // -------------------------------------------------------------------------
  group('Unbekannte Übungs-IDs tragen nichts bei', () {
    test('Eine unbekannte Übung neben einer bekannten ändert nichts', () {
      final nurBekannte = WorkoutDuration.estimate([
        uebung('benchPress', sets: 4, repLow: 6, repHigh: 10),
      ]);
      final mitUnbekannter = WorkoutDuration.estimate([
        uebung('benchPress', sets: 4, repLow: 6, repHigh: 10),
        uebung('gibtEsNicht', sets: 5, repLow: 8, repHigh: 12),
      ]);
      expect(nurBekannte, 10);
      expect(mitUnbekannter, 10);
    });

    test('Auch eine unbekannte Übung vor der bekannten ändert nichts', () {
      expect(
        WorkoutDuration.estimate([
          uebung('gibtEsNicht', sets: 9, repLow: 8, repHigh: 12),
          uebung('benchPress', sets: 4, repLow: 6, repHigh: 10),
        ]),
        10,
      );
    });

    test('Eine unbekannte Übung trägt nicht einmal Rüstzeit bei', () {
      // Würde sie ihre 90 s Rüstzeit beisteuern, kämen zu den 720 s des
      // Bankdrückens 810 s dazu: 12,75 min → 15 statt 10.
      expect(
        WorkoutDuration.estimate([
          uebung('benchPress', sets: 4, repLow: 6, repHigh: 10),
          uebung('gibtEsNicht', sets: 1, repLow: 8, repHigh: 12),
        ]),
        10,
      );
    });
  });

  // -------------------------------------------------------------------------
  group(
    'effective: Eingetragenes überschreibt, die Schätzung rechnet weiter',
    () {
      // Tim, 19.11.2026: Wer die eigene Zahl zurückgibt, bekommt die Schätzung
      // wieder — es geht nichts verloren, weil nichts überschrieben wurde.

      test('Ohne eingetragene Dauer gilt die Schätzung', () {
        expect(
          WorkoutDuration.effective(
            entered: null,
            exercises: ausKatalog(Workout.push),
          ),
          55,
        );
      });

      test('Eine eingetragene Dauer geht vor der Schätzung', () {
        expect(
          WorkoutDuration.effective(
            entered: 70,
            exercises: ausKatalog(Workout.push),
          ),
          70,
        );
      });

      test('Die eingetragene Dauer gilt auch, wenn sie unter der Schätzung '
          'liegt', () {
        expect(
          WorkoutDuration.effective(
            entered: 20,
            exercises: ausKatalog(Workout.push),
          ),
          20,
        );
      });

      test('Eine eingetragene Dauer gilt auch ohne Übung', () {
        expect(WorkoutDuration.effective(entered: 45, exercises: []), 45);
      });

      test('Weder eingetragen noch schätzbar ist null, nicht 0', () {
        expect(WorkoutDuration.effective(entered: null, exercises: []), isNull);
      });

      test('`entered` darf ganz fehlen und bedeutet dann „geschätzt"', () {
        // Legs: 3435 s = 57,25 min → 55.
        expect(
          WorkoutDuration.effective(exercises: ausKatalog(Workout.legs)),
          55,
        );
      });
    },
  );
}
