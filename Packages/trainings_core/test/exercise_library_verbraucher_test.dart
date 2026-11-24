import 'dart:convert';

import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für die **sieben Kern-Stellen**, die eine Übung nach ID auflösen
/// und deshalb auf `ExerciseLibrary` umgestellt werden müssen (Spec 4.1 und
/// 8.1, Plan Task 2.1/2.2). Jede wird hier mit einer Übung der Bibliothek
/// geprüft, **die kein Anker ist** — sonst bliebe eine vergessene Umstellung
/// unbemerkt, weil die 33 Anker auch im alten Katalog stehen.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden. Geschrieben aus
/// der Spec und dem Plan, ohne `exercise_library.dart` gesehen zu haben.
///
/// ## Die sieben Stellen
///
/// Gefunden mit `grep -rn "ExerciseCatalog\." Packages/trainings_core/lib`
/// (der Plan korrigiert die Spec: es sind sieben, nicht fünf):
///
/// 1. `workout_muscles.dart` — `WorkoutMuscles.weightedSets` und `trained`
/// 2. `muscle_volume.dart` — `MuscleVolume.weeklySets`
/// 3. `muscle_sources.dart` — `muscleSources`
/// 4. `workout_definition.dart` — `WorkoutExercise.resolve()` (und über sie
///    `WorkoutDuration.estimate`)
/// 5. `workout_rules.dart` — `WorkoutRules.check` (`UnknownExercise`)
/// 6. `gym_session_builder.dart` — `GymSessionBuilder.session`
/// 7. `trainings_export.dart` — `TrainingsExport.read` (`unknownExerciseIds`)
///
/// **Nicht umgestellt** (bleiben beim Katalog der 33): `workout_templates.dart`
/// und `gym_session_order.dart` (beide `ExerciseCatalog.exercisesFor`) sowie
/// `ExerciseCatalog.heavyLegIds`. Die letzte Gruppe hält das fest.
///
/// ## Wer was entschieden hat
///
/// - **Vorschlag der Spec, vorausgesetzt:** Die erzeugten Übungen tragen die
///   Muskeln und Vorgaben der Regeltabelle (Spec 5.3, 6); die Tests lesen sie
///   hier als Literale — `squat` ist Gesäß 1, Oberschenkel vorne 1, Unterer
///   Rücken 0,5, Oberschenkel hinten 0,5 (Spec 12.1).
/// - **Festlegung des Test-Agenten:** `plank` als Zeitübung (3 × 30–45 s) und
///   `assisted-dips` als Übung mit Unterstützung dienen als zweite und dritte
///   Probe; `fremdeUebung` und die weggelassene Übung `butterfly-stretch` (ohne
///   Hauptmuskel in unseren 16 Gruppen) als IDs, die
///   weder Katalog noch Bibliothek kennen (Vorgänger-Spec 6.2: bleibt
///   „Unbekannte Übung“).
///
/// Alle Zahlen sind erfunden; die Zeitpunkte sind UTC-Werte, die Berliner
/// Tage bezeichnen — so rechnet das ganze Paket.
void main() {
  // Mittwoch, 12.05.2027, 22:00 Berliner Zeit.
  final jetzt = DateTime.utc(2027, 5, 12, 20);
  DateTime tag(int tageZurueck) => DateTime.utc(2027, 5, 12 - tageZurueck, 10);

  WorkoutExercise geplant(
    String id, {
    int sets = 3,
    int low = 6,
    int high = 10,
    double? increment,
  }) => WorkoutExercise(
    exerciseId: id,
    sets: sets,
    repLow: low,
    repHigh: high,
    increment: increment,
  );

  WorkoutDefinition training(List<WorkoutExercise> uebungen) =>
      WorkoutDefinition(
        id: 'eigen-1',
        name: 'Mein Training',
        category: WorkoutCategory.own,
        tags: const [],
        exercises: uebungen,
      );

  group('Vorbedingung: die Proben sind keine Anker', () {
    test('`squat`, `plank`, `assisted-dips` und die Cardio-Übung `running` '
        'stehen in der Bibliothek, nicht im Katalog', () {
      for (final id in ['squat', 'plank', 'assisted-dips', 'running']) {
        expect(ExerciseLibrary.byId(id), isNotNull, reason: id);
        expect(ExerciseCatalog.all[id], isNull, reason: '$id wäre ein Anker');
      }
    });

    test('Die fremden IDs kennt keiner: `fremdeUebung` und die weggelassene '
        '`butterfly-stretch`', () {
      for (final id in ['fremdeUebung', 'butterfly-stretch']) {
        expect(ExerciseLibrary.byId(id), isNull, reason: id);
        expect(ExerciseCatalog.all[id], isNull, reason: id);
      }
    });
  });

  group('1. WorkoutMuscles', () {
    test('`weightedSets` rechnet Sätze × Gewicht aus der Bibliothek', () {
      expect(WorkoutMuscles.weightedSets([geplant('squat', sets: 4)]), {
        Muscle.glutes: 4.0,
        Muscle.quads: 4.0,
        Muscle.lowerBack: 2.0,
        Muscle.hamstrings: 2.0,
      });
    });

    test('`trained` färbt Haupt- und Nebenmuskeln einer erzeugten Übung', () {
      expect(WorkoutMuscles.trained([geplant('squat')]), {
        Muscle.glutes,
        Muscle.quads,
        Muscle.lowerBack,
        Muscle.hamstrings,
      });
    });

    test('Anker und Erzeugte rechnen zusammen: Bankdrücken (Anker) und '
        'Kniebeuge (erzeugt)', () {
      expect(
        WorkoutMuscles.weightedSets([
          geplant('benchPress', sets: 4),
          geplant('squat', sets: 2),
        ]),
        {
          Muscle.chest: 4.0,
          Muscle.frontDelt: 2.0,
          Muscle.triceps: 2.0,
          Muscle.glutes: 2.0,
          Muscle.quads: 2.0,
          Muscle.lowerBack: 1.0,
          Muscle.hamstrings: 1.0,
        },
      );
    });

    test('Eine unbekannte ID trägt nichts bei', () {
      expect(WorkoutMuscles.weightedSets([geplant('fremdeUebung')]), isEmpty);
      expect(WorkoutMuscles.trained([geplant('butterfly-stretch')]), isEmpty);
    });
  });

  group('2. MuscleVolume.weeklySets', () {
    test('Sätze einer erzeugten Übung zählen mit ihren Gewichten', () {
      final sets = [
        for (var i = 0; i < 3; i++)
          TrainedSet(date: tag(i + 1), exerciseId: 'squat'),
      ];
      final wochenSaetze = MuscleVolume.weeklySets(sets, days: 7, now: jetzt);
      expect(wochenSaetze, hasLength(16));
      expect(wochenSaetze[Muscle.glutes], 3.0);
      expect(wochenSaetze[Muscle.quads], 3.0);
      expect(wochenSaetze[Muscle.lowerBack], 1.5);
      expect(wochenSaetze[Muscle.hamstrings], 1.5);
      expect(wochenSaetze[Muscle.chest], 0.0);
    });

    test('Ein Satz einer unbekannten Übung zählt nirgends', () {
      final wochenSaetze = MuscleVolume.weeklySets(
        [
          TrainedSet(date: tag(1), exerciseId: 'fremdeUebung'),
          TrainedSet(date: tag(1), exerciseId: 'butterfly-stretch'),
        ],
        days: 7,
        now: jetzt,
      );
      expect(wochenSaetze.values.every((v) => v == 0.0), isTrue);
    });
  });

  group('3. muscleSources', () {
    test('Eine erzeugte Übung erscheint als Quelle ihres Muskels', () {
      final quellen = muscleSources(
        muscle: Muscle.glutes,
        sets: [
          TrainedSet(date: tag(3), exerciseId: 'squat'),
          TrainedSet(date: tag(1), exerciseId: 'squat'),
          TrainedSet(date: tag(2), exerciseId: 'benchPress'),
        ],
        days: 7,
        now: jetzt,
      );
      expect(quellen, hasLength(1));
      expect(quellen.single.exerciseId, 'squat');
      expect(quellen.single.weeklySets, 2.0);
      expect(quellen.single.setCount, 2);
      expect(quellen.single.lastDate, tag(1));
    });

    test('Eine Nebenbelastung zählt mit dem halben Gewicht', () {
      final quellen = muscleSources(
        muscle: Muscle.hamstrings,
        sets: [
          TrainedSet(date: tag(1), exerciseId: 'squat'),
          TrainedSet(date: tag(2), exerciseId: 'squat'),
        ],
        days: 7,
        now: jetzt,
      );
      expect(quellen.single.weeklySets, 1.0);
      expect(quellen.single.setCount, 2);
    });

    test('Eine unbekannte Übung ist nirgends eine Quelle', () {
      final quellen = muscleSources(
        muscle: Muscle.glutes,
        sets: [TrainedSet(date: tag(1), exerciseId: 'fremdeUebung')],
        days: 7,
        now: jetzt,
      );
      expect(quellen, isEmpty);
    });
  });

  group('4. WorkoutExercise.resolve und WorkoutDuration', () {
    test(
      '`resolve` liefert die erzeugte Übung mit den Zahlen des Trainings',
      () {
        final bibliothek = ExerciseLibrary.byId('squat')!;
        final aufgeloest = geplant(
          'squat',
          sets: 5,
          low: 3,
          high: 6,
          increment: 2.5,
        ).resolve();
        expect(aufgeloest, isNotNull);
        expect(aufgeloest!.id, 'squat');
        expect(aufgeloest.name, bibliothek.name);
        expect(aufgeloest.sets, 5);
        expect(aufgeloest.repLow, 3);
        expect(aufgeloest.repHigh, 6);
        expect(aufgeloest.increment, 2.5);
        expect(aufgeloest.howTo, bibliothek.howTo);
        expect(aufgeloest.tips, bibliothek.tips);
        expect(aufgeloest.commonMistake, isNull);
        expect(aufgeloest.muscles, bibliothek.muscles);
      },
    );

    test('Ohne eigene Steigerung gilt die der Bibliothek (`squat`: 5)', () {
      expect(geplant('squat').resolve()!.increment, 5);
    });

    test('Eine unbekannte ID bleibt `null`', () {
      expect(geplant('fremdeUebung').resolve(), isNull);
      expect(geplant('butterfly-stretch').resolve(), isNull);
    });

    test('`WorkoutDuration.estimate` kennt die erzeugte Übung: 3 × 6–10 '
        'ergibt 10 Minuten (90 s Rüstzeit, 3 × 45 s, 2 × 150 s Pause)', () {
      expect(WorkoutDuration.estimate([geplant('squat')]), 10);
    });

    test('… und weiß, dass `plank` eine Zeitübung ist: 10 × 120 s '
        'rechnet als Arbeitszeit, nicht als 45 s je Satz', () {
      // Zeitübung: 90 + 10 × 120 + 9 × 45 = 1695 s → 30 Minuten.
      // Als Wiederholungsübung gerechnet wären es 90 + 450 + 9 × 60 = 1080 s,
      // also 20 Minuten.
      expect(
        WorkoutDuration.estimate([
          geplant('plank', sets: 10, low: 120, high: 120),
        ]),
        30,
      );
    });

    test('Cardio ist eine Zeitübung (Spec Nachtrag 19): `running` mit '
        '1 × 300–600 s ergibt 10 Minuten (90 s Rüstzeit + 450 s Arbeit)', () {
      // Als Wiederholungsübung gerechnet wären es 90 + 45 = 135 s, also 5
      // Minuten.
      expect(
        WorkoutDuration.estimate([
          geplant('running', sets: 1, low: 300, high: 600),
        ]),
        10,
      );
    });

    test('Eine unbekannte Übung trägt nichts bei: allein ergibt sie `null`, '
        'neben einer bekannten ändert sie nichts', () {
      expect(WorkoutDuration.estimate([geplant('fremdeUebung')]), isNull);
      expect(
        WorkoutDuration.estimate([geplant('fremdeUebung'), geplant('squat')]),
        WorkoutDuration.estimate([geplant('squat')]),
      );
    });
  });

  group('5. WorkoutRules.check', () {
    test('Eine erzeugte Übung ist bekannt: kein `UnknownExercise`', () {
      final funde = WorkoutRules.check(
        training([geplant('squat'), geplant('plank', low: 30, high: 45)]),
      );
      expect(funde, isEmpty);
    });

    test('Eine unbekannte ID bleibt `UnknownExercise`', () {
      final funde = WorkoutRules.check(
        training([geplant('squat'), geplant('fremdeUebung')]),
      );
      expect(funde, [const UnknownExercise('fremdeUebung')]);
    });

    test('Die weggelassene Übung, die nicht in der Bibliothek steht, ist '
        'unbekannt', () {
      expect(WorkoutRules.check(training([geplant('butterfly-stretch')])), [
        const UnknownExercise('butterfly-stretch'),
      ]);
    });

    test(
      'Die Grenze für Wiederholungen oder Sekunden folgt `isTimed` der '
      'erzeugten Übung: 300 sind bei `plank` Sekunden, bei `squat` zu viel',
      () {
        expect(
          WorkoutRules.check(training([geplant('plank', low: 30, high: 300)])),
          isEmpty,
        );
        expect(
          WorkoutRules.check(training([geplant('squat', low: 30, high: 300)])),
          [const RepsInvalid('squat')],
        );
      },
    );

    test('Eine erzeugte Übung zweimal im Training ist `DuplicateExercise`', () {
      final funde = WorkoutRules.check(
        training([geplant('squat'), geplant('squat')]),
      );
      expect(funde, contains(const DuplicateExercise('squat')));
      expect(funde.whereType<UnknownExercise>(), isEmpty);
    });

    test('Cardio ist bekannt und eine Zeitübung: 1 × 300–600 s besteht die '
        'Prüfung, 600 ist die Obergrenze für Sekunden', () {
      expect(
        WorkoutRules.check(
          training([geplant('running', sets: 1, low: 300, high: 600)]),
        ),
        isEmpty,
      );
      expect(
        WorkoutRules.check(
          training([geplant('running', sets: 1, low: 300, high: 601)]),
        ),
        [const RepsInvalid('running')],
      );
    });

    test('Die Satzgrenze gilt auch für erzeugte Übungen', () {
      expect(WorkoutRules.check(training([geplant('squat', sets: 11)])), [
        const SetsOutOfRange('squat'),
      ]);
    });
  });

  group('6. GymSessionBuilder.session', () {
    final datum = DateTime.utc(2027, 5, 12, 16, 30);

    test('Eine erzeugte Übung kommt in die Sitzung', () {
      final sitzung = GymSessionBuilder.session(
        id: 's1',
        date: datum,
        workout: null,
        entries: {
          'squat': [const RawSet(weight: '100', reps: '5')],
        },
      );
      expect(sitzung, isNotNull);
      expect(sitzung!.exercises, hasLength(1));
      expect(sitzung.exercises.single.exerciseId, 'squat');
      expect(sitzung.exercises.single.sets, [
        const CompletedSet(weight: 100, reps: 5),
      ]);
    });

    test('Eine unbekannte ID wird übergangen; allein ergibt sie keine '
        'Sitzung', () {
      final nurFremd = GymSessionBuilder.session(
        id: 's2',
        date: datum,
        workout: null,
        entries: {
          'fremdeUebung': [const RawSet(weight: '50', reps: '8')],
          'butterfly-stretch': [const RawSet(weight: '', reps: '30')],
        },
      );
      expect(nurFremd, isNull);

      final gemischt = GymSessionBuilder.session(
        id: 's3',
        date: datum,
        workout: null,
        entries: {
          'fremdeUebung': [const RawSet(weight: '50', reps: '8')],
          'squat': [const RawSet(weight: '100', reps: '5')],
        },
      );
      expect(gemischt!.exercises.map((e) => e.exerciseId), ['squat']);
    });

    test('Die Reihenfolge bleibt die des Workouts, Erzeugte stehen dahinter '
        'alphabetisch — der Katalog der Workouts ist unverändert', () {
      final sitzung = GymSessionBuilder.session(
        id: 's4',
        date: datum,
        workout: Workout.a,
        entries: {
          'squat': [const RawSet(weight: '100', reps: '5')],
          'plank': [const RawSet(weight: '', reps: '40')],
          'benchPress': [const RawSet(weight: '60', reps: '8')],
        },
      );
      expect(sitzung!.exercises.map((e) => e.exerciseId), [
        'benchPress',
        'plank',
        'squat',
      ]);
    });

    test('Eine erzeugte Übung mit Unterstützung speichert das Gewicht '
        'negativ', () {
      final sitzung = GymSessionBuilder.session(
        id: 's5',
        date: datum,
        workout: null,
        entries: {
          'assisted-dips': [const RawSet(weight: '27', reps: '8')],
        },
        assist: const {'assisted-dips': true},
      );
      expect(sitzung!.exercises.single.sets.single.weight, -27);
    });
  });

  group('7. TrainingsExport.read', () {
    Map<String, Object?> rohUebung(String id) => {
      'exerciseID': id,
      'sets': [
        {'weight': 60, 'reps': 8},
      ],
    };

    ExportRead lies(List<String> uebungen) {
      final datei = {
        'format': 'trainingsexport',
        'version': 2,
        'generated': '2099-02-01T08:30:00Z',
        'timezone': 'Europe/Berlin',
        'app': {
          'sessions': [
            {
              'id': 'S1',
              'date': '2099-01-14T09:00:00Z',
              'exercises': [for (final id in uebungen) rohUebung(id)],
            },
          ],
          'circumferences': <Object?>[],
          'swaps': <Object?>[],
          'drafts': <Object?>[],
          'dataWindow': <Object?>[],
          'dashboardImport': <Object?>[],
        },
      };
      final gelesen = TrainingsExport.read(jsonDecode(jsonEncode(datei)));
      expect(gelesen, isA<ExportRead>());
      return gelesen as ExportRead;
    }

    test('Eine erzeugte Übung gilt als bekannt: nichts in '
        '`unknownExerciseIds`', () {
      final gelesen = lies(['squat', 'benchPress', 'plank']);
      expect(gelesen.unknownExerciseIds, isEmpty);
      expect(gelesen.sessions.single.exercises.map((e) => e.exerciseId), [
        'squat',
        'benchPress',
        'plank',
      ]);
    });

    test('Eine fremde ID wird weiter genannt — und bleibt in der Sitzung', () {
      final gelesen = lies(['squat', 'fremdeUebung']);
      expect(gelesen.unknownExerciseIds, ['fremdeUebung']);
      expect(gelesen.sessions.single.exercises.map((e) => e.exerciseId), [
        'squat',
        'fremdeUebung',
      ]);
    });

    test('Die weggelassene Übung, die die Bibliothek nicht führt, wird als '
        'unbekannt genannt', () {
      expect(lies(['butterfly-stretch']).unknownExerciseIds, [
        'butterfly-stretch',
      ]);
    });
  });

  group('Was beim Katalog der 33 bleibt', () {
    test('Jedes Workout führt nur Anker: `exercisesFor` kennt keine '
        'erzeugte Übung', () {
      for (final workout in Workout.values) {
        for (final e in ExerciseCatalog.exercisesFor(workout)) {
          expect(
            ExerciseLibrary.isCatalog(e.id),
            isTrue,
            reason: '${workout.code}/${e.id}',
          );
          expect(ExerciseLibrary.byId(e.id), same(e), reason: e.id);
        }
      }
    });

    test('`heavyLegIds` nennt weiter nur Anker', () {
      expect(ExerciseCatalog.heavyLegIds, {'splitSquat', 'romanianDeadlift'});
      for (final id in ExerciseCatalog.heavyLegIds) {
        expect(ExerciseLibrary.isCatalog(id), isTrue, reason: id);
      }
    });

    test('Die Vorlagen der Workouts ändern sich nicht: `Workout.a` hat '
        'weiter sieben Übungen', () {
      expect(ExerciseCatalog.exercisesFor(Workout.a), hasLength(7));
      expect(
        ExerciseCatalog.exercisesFor(Workout.a).map((e) => e.id),
        contains('benchPress'),
      );
    });
  });
}
