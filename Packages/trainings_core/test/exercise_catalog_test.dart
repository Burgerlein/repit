import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für `ExerciseCatalog`, portiert aus
/// `Packages/TrainingsCore/Tests/TrainingsCoreTests/ExerciseCatalogTests.swift`
/// und `…/ExerciseCatalogValuesTests.swift`.
/// Vorgegebene API: `docs/superpowers/specs/2026-11-10-gym-kern-dart-api.md`,
/// Abschnitt „Block A“, `lib/src/exercise_catalog.dart`.
///
/// Die Datei hat drei Teile, und die Aufteilung ist Absicht:
///
/// 1. **Plausibilität** — Invarianten, die über jede Übung laufen. Sie finden
///    Unsinn, aber keinen Zahlendreher.
/// 2. **Zahl für Zahl** — eine zweite, unabhängig aus `docs/SPEC.md` 4.4
///    abgeschriebene Tabelle. Ein vertauschtes 12–15 statt 15–20 oder ein
///    vergessener Nebenmuskel bliebe sonst unbemerkt, weil Code und
///    Plausibilitätstest aus derselben Quelle stammen. Zwei Abschriften gehen
///    nur bei identischem Fehler gemeinsam daneben.
/// 3. **Texte wortgleich** — Name, Technik-Hinweis, die drei Schritte, der
///    häufigste Fehler und der Suchbegriff einer Auswahl von Übungen. Genau
///    das fängt den Tippfehler beim Portieren, den keine Zahl verrät.
///
/// Der Fachinhalt ist deutsch; das ist die ausdrückliche Ausnahme aus
/// `CLAUDE.md` für den Übungskatalog. Die API selbst bleibt englisch.
///
/// Diese Datei darf **ausgeführt, nie verändert** werden (`CLAUDE.md`).
void main() {
  // Die beiden Übungen, die in keinem Workout mehr stehen. Der gespeicherte
  // Verlauf zeigt auf ihre IDs — wer sie löscht, macht alte Sätze namenlos,
  // und die Muskelkarte zählt sie nicht mehr mit.
  const ausgemustert = {'hipThrust', 'calfRaiseSeated'};

  Set<String> idsInWorkouts() => {
    for (final workout in Workout.values)
      for (final e in ExerciseCatalog.exercisesFor(workout)) e.id,
  };

  group('Der Katalog trägt jedes Workout', () {
    test('Jedes Workout hat die in der Spec genannte Anzahl Übungen', () {
      expect(ExerciseCatalog.exercisesFor(Workout.a), hasLength(7));
      expect(ExerciseCatalog.exercisesFor(Workout.b), hasLength(8));
      expect(ExerciseCatalog.exercisesFor(Workout.c), hasLength(7));
      expect(ExerciseCatalog.exercisesFor(Workout.d), hasLength(7));
      expect(ExerciseCatalog.exercisesFor(Workout.push), hasLength(7));
      expect(ExerciseCatalog.exercisesFor(Workout.pull), hasLength(7));
      expect(ExerciseCatalog.exercisesFor(Workout.legs), hasLength(7));
    });

    test('Jedes Workout führt Übungen, und jede steht im Katalog', () {
      for (final workout in Workout.values) {
        final exercises = ExerciseCatalog.exercisesFor(workout);
        expect(
          exercises,
          isNotEmpty,
          reason: '${workout.code}: kein einziger Eintrag',
        );
        for (final e in exercises) {
          expect(
            ExerciseCatalog.all[e.id],
            isNotNull,
            reason: '${workout.code}/${e.id}: nicht im Katalog',
          );
        }
      }
    });

    test('Kein Workout nennt dieselbe Übung zweimal', () {
      for (final workout in Workout.values) {
        final ids = ExerciseCatalog.exercisesFor(workout).map((e) => e.id);
        expect(
          ids.toSet(),
          hasLength(ids.length),
          reason: '${workout.code}: doppelt in ${ids.toList()}',
        );
      }
    });

    /// `Exercise.sets` hängt an der Übung, nicht am Workout. Geteilte
    /// Übungen — Wadenheben stehend in B und Legs, Kabel-Flys in B und Push
    /// — tragen deshalb überall dieselben Zahlen. Hätte die Spec an zwei
    /// Stellen verschiedene, fände der Katalog das nicht, sondern entschiede
    /// still.
    test('Eine Übung trägt in jedem Workout dieselben Sätze und Bereiche', () {
      for (final workout in Workout.values) {
        for (final e in ExerciseCatalog.exercisesFor(workout)) {
          final katalogEintrag = ExerciseCatalog.all[e.id];
          expect(
            katalogEintrag,
            isNotNull,
            reason: '${workout.code}/${e.id}: nicht im Katalog',
          );
          expect(
            e,
            katalogEintrag,
            reason: '${workout.code}/${e.id}: weicht vom Katalog ab',
          );
        }
      }
    });

    test('Ausgemusterte Übungen bleiben im Katalog, stehen aber in keinem '
        'Workout', () {
      for (final id in ausgemustert) {
        expect(
          ExerciseCatalog.all[id],
          isNotNull,
          reason: '$id fehlt im Katalog',
        );
      }
      final inWorkouts = idsInWorkouts();
      for (final id in ausgemustert) {
        expect(
          inWorkouts.contains(id),
          isFalse,
          reason: '$id steht noch in einem Workout',
        );
      }
    });

    test('Außer den ausgemusterten kommt jede Übung in mindestens einem '
        'Workout vor', () {
      final ungenutzt = ExerciseCatalog.all.keys.toSet().difference(
        idsInWorkouts(),
      );
      expect(
        ungenutzt,
        ausgemustert,
        reason: 'Ohne Workout: ${(ungenutzt.toList()..sort())}',
      );
    });
  });

  group('Was über jede einzelne Übung gilt', () {
    test(
      'Jede Übung hat drei Schritte, einen Fehler und einen Suchbegriff',
      () {
        for (final e in ExerciseCatalog.all.values) {
          expect(
            e.howTo,
            hasLength(3),
            reason: '${e.id}: ${e.howTo.length} Schritte statt 3',
          );
          for (final schritt in e.howTo) {
            expect(
              schritt.trim(),
              isNotEmpty,
              reason: '${e.id}: leerer Schritt in der Anleitung',
            );
          }
          expect(
            e.commonMistake,
            isNotEmpty,
            reason: '${e.id}: kein häufiger Fehler',
          );
          expect(
            e.youTubeQuery,
            isNotEmpty,
            reason: '${e.id}: kein Suchbegriff',
          );
          expect(e.cue, isNotEmpty, reason: '${e.id}: kein Technik-Hinweis');
          expect(e.name, isNotEmpty, reason: '${e.id}: kein Name');
        }
      },
    );

    test(
      'Jede Übung trifft mindestens einen Muskel, und zwar mit 1 oder 0,5',
      () {
        // 1,0 ist der Hauptmuskel, 0,5 eine Nebenbelastung. Ein dritter Wert
        // wäre eine fachliche Entscheidung und keine Portierung.
        for (final e in ExerciseCatalog.all.values) {
          expect(
            e.muscles,
            isNotEmpty,
            reason: '${e.id}: keine Muskelzuordnung',
          );
          e.muscles.forEach((muscle, faktor) {
            expect(
              faktor == 1.0 || faktor == 0.5,
              isTrue,
              reason:
                  '${e.id}/${muscle.code}: Faktor $faktor, '
                  'erlaubt sind 1 und 0,5',
            );
          });
          expect(
            e.muscles.values.contains(1.0),
            isTrue,
            reason: '${e.id}: kein Hauptmuskel',
          );
        }
      },
    );

    test('Wiederholungsbereiche sind aufsteigend und Steigerungen positiv', () {
      for (final e in ExerciseCatalog.all.values) {
        expect(
          e.repLow,
          lessThan(e.repHigh),
          reason: '${e.id}: ${e.repLow}–${e.repHigh}',
        );
        expect(e.repLow, greaterThan(0), reason: '${e.id}: ${e.repLow}');
        expect(
          e.increment,
          greaterThan(0),
          reason: '${e.id}: Steigerung ${e.increment}',
        );
        expect(
          e.sets,
          greaterThanOrEqualTo(1),
          reason: '${e.id}: ${e.sets} Sätze',
        );
      }
    });

    test('Der Schlüssel im Katalog ist die ID der Übung', () {
      // Eine Übung, die unter einem fremden Schlüssel liegt, findet der
      // Verlauf nie wieder — und keiner der anderen Tests bemerkt es.
      ExerciseCatalog.all.forEach((schluessel, e) {
        expect(
          e.id,
          schluessel,
          reason: 'Schlüssel $schluessel trägt die Übung ${e.id}',
        );
      });
    });

    test('Zwei Übungen heißen nie gleich', () {
      final namen = ExerciseCatalog.all.values.map((e) => e.name).toList();
      expect(
        namen.toSet(),
        hasLength(namen.length),
        reason: 'doppelter Name im Katalog',
      );
    });

    test('Dips und Klimmzüge erlauben Unterstützung, sonst niemand', () {
      final mitHilfe =
          ExerciseCatalog.all.values
              .where((e) => e.allowsAssist)
              .map((e) => e.id)
              .toList()
            ..sort();
      expect(mitHilfe, ['dips', 'pullUp']);
    });

    test('Der Seitstütz ist die einzige Zeitübung', () {
      final nachZeit = ExerciseCatalog.all.values
          .where((e) => e.isTimed)
          .map((e) => e.id)
          .toList();
      expect(nachZeit, ['sidePlank']);
    });

    test('Die schweren Beinübungen sind die beiden aus der Spec', () {
      // Hip Thrust steht in keinem Workout mehr und kann deshalb auch in
      // keiner „leicht“-Variante entfallen.
      expect(ExerciseCatalog.heavyLegIds, {'splitSquat', 'romanianDeadlift'});
    });

    test('Jede schwere Beinübung steht auch im Katalog', () {
      for (final id in ExerciseCatalog.heavyLegIds) {
        expect(
          ExerciseCatalog.all[id],
          isNotNull,
          reason: '$id ist schwer, aber unbekannt',
        );
      }
    });

    test('exercisesFor gibt bei jedem Aufruf dasselbe zurück', () {
      // Der Katalog ist konstant. Zwei Aufrufe, die ungleiche Listen
      // liefern, ließen jeden abgeleiteten Riverpod-Wert bei jedem Neubau
      // neu rechnen — das wäre Fehler `03` im neuen Code.
      for (final workout in Workout.values) {
        expect(
          ExerciseCatalog.exercisesFor(workout),
          ExerciseCatalog.exercisesFor(workout),
          reason: '${workout.code}: zwei Aufrufe, zwei Ergebnisse',
        );
      }
    });
  });

  group('Übungskatalog gegen die Spec, Zahl für Zahl', () {
    // Zweite, unabhängig abgeschriebene Tabelle. Die Reihenfolge folgt den
    // Workouts; jede Übung steht genau einmal, auch wenn sie in mehreren
    // Workouts vorkommt.
    const erwartet =
        <
          ({
            String id,
            int sets,
            int lo,
            int hi,
            double inc,
            Map<Muscle, double> muscles,
          })
        >[
          // Gym A — Oberkörper Push + Arme
          (
            id: 'benchPress',
            sets: 4,
            lo: 6,
            hi: 10,
            inc: 2.5,
            muscles: {
              Muscle.chest: 1.0,
              Muscle.frontDelt: 0.5,
              Muscle.triceps: 0.5,
            },
          ),
          (
            id: 'inclineDumbbellPress',
            sets: 3,
            lo: 8,
            hi: 12,
            inc: 2,
            muscles: {
              Muscle.chest: 1.0,
              Muscle.frontDelt: 0.5,
              Muscle.triceps: 0.5,
            },
          ),
          (
            id: 'shoulderPressDumbbell',
            sets: 3,
            lo: 8,
            hi: 12,
            inc: 2,
            muscles: {
              Muscle.frontDelt: 1.0,
              Muscle.sideDelt: 0.5,
              Muscle.triceps: 0.5,
            },
          ),
          (
            id: 'dips',
            sets: 3,
            lo: 6,
            hi: 12,
            inc: 2.5,
            muscles: {
              Muscle.triceps: 1.0,
              Muscle.chest: 0.5,
              Muscle.frontDelt: 0.5,
            },
          ),
          (
            id: 'lateralRaise',
            sets: 4,
            lo: 12,
            hi: 20,
            inc: 1,
            muscles: {Muscle.sideDelt: 1.0},
          ),
          (
            id: 'overheadTriceps',
            sets: 3,
            lo: 10,
            hi: 15,
            inc: 2.5,
            muscles: {Muscle.triceps: 1.0},
          ),
          (
            id: 'bicepsCurl',
            sets: 3,
            lo: 8,
            hi: 12,
            inc: 1,
            muscles: {Muscle.biceps: 1.0, Muscle.forearms: 0.5},
          ),
          // Gym B — Läufer-Kraft + Brust
          (
            id: 'splitSquat',
            sets: 3,
            lo: 8,
            hi: 12,
            inc: 2,
            muscles: {Muscle.quads: 1.0, Muscle.glutes: 1.0},
          ),
          (
            id: 'romanianDeadlift',
            sets: 3,
            lo: 8,
            hi: 10,
            inc: 2.5,
            muscles: {
              Muscle.hamstrings: 1.0,
              Muscle.glutes: 0.5,
              Muscle.lowerBack: 0.5,
            },
          ),
          (
            id: 'legCurl',
            sets: 3,
            lo: 10,
            hi: 15,
            inc: 2.5,
            muscles: {Muscle.hamstrings: 1.0},
          ),
          (
            id: 'hipAbduction',
            sets: 3,
            lo: 12,
            hi: 20,
            inc: 5,
            muscles: {Muscle.glutes: 1.0},
          ),
          (
            id: 'calfRaiseStanding',
            sets: 6,
            lo: 12,
            hi: 15,
            inc: 2,
            muscles: {Muscle.calves: 1.0},
          ),
          (
            id: 'tibialisRaise',
            sets: 3,
            lo: 15,
            hi: 25,
            inc: 1,
            muscles: {Muscle.tibialis: 1.0},
          ),
          (
            id: 'cableFly',
            sets: 3,
            lo: 12,
            hi: 15,
            inc: 2.5,
            muscles: {Muscle.chest: 1.0},
          ),
          // Der Seitstütz zählt Sekunden, keine Wiederholungen: 30 bis 45 sind
          // hier eine Zeit, und die Steigerung von 5 sind fünf Sekunden.
          (
            id: 'sidePlank',
            sets: 3,
            lo: 30,
            hi: 45,
            inc: 5,
            muscles: {Muscle.core: 1.0},
          ),
          // Gym C — Oberkörper Pull + Arme
          (
            id: 'pullUp',
            sets: 4,
            lo: 6,
            hi: 10,
            inc: 2.5,
            muscles: {
              Muscle.lats: 1.0,
              Muscle.biceps: 0.5,
              Muscle.rearDelt: 0.5,
            },
          ),
          (
            id: 'oneArmRow',
            sets: 3,
            lo: 8,
            hi: 12,
            inc: 2,
            muscles: {
              Muscle.lats: 1.0,
              Muscle.upperBack: 0.5,
              Muscle.biceps: 0.5,
              Muscle.rearDelt: 0.5,
            },
          ),
          (
            id: 'cableRowClose',
            sets: 3,
            lo: 10,
            hi: 12,
            inc: 2.5,
            muscles: {
              Muscle.upperBack: 1.0,
              Muscle.lats: 0.5,
              Muscle.biceps: 0.5,
            },
          ),
          (
            id: 'facePull',
            sets: 3,
            lo: 12,
            hi: 20,
            inc: 2.5,
            muscles: {Muscle.rearDelt: 1.0, Muscle.upperBack: 0.5},
          ),
          (
            id: 'ezCurl',
            sets: 3,
            lo: 8,
            hi: 12,
            inc: 2.5,
            muscles: {Muscle.biceps: 1.0, Muscle.forearms: 0.5},
          ),
          (
            id: 'hammerCurl',
            sets: 3,
            lo: 10,
            hi: 12,
            inc: 1,
            muscles: {Muscle.biceps: 1.0, Muscle.forearms: 1.0},
          ),
          (
            id: 'tricepsPushdown',
            sets: 3,
            lo: 10,
            hi: 15,
            inc: 2.5,
            muscles: {Muscle.triceps: 1.0},
          ),
          // Gym D — Arme + Schultern
          (
            id: 'closeGripBench',
            sets: 3,
            lo: 6,
            hi: 10,
            inc: 2.5,
            muscles: {Muscle.triceps: 1.0, Muscle.chest: 0.5},
          ),
          (
            id: 'shoulderPressMachine',
            sets: 3,
            lo: 8,
            hi: 12,
            inc: 2.5,
            muscles: {
              Muscle.frontDelt: 1.0,
              Muscle.sideDelt: 0.5,
              Muscle.triceps: 0.5,
            },
          ),
          (
            id: 'reverseFly',
            sets: 3,
            lo: 12,
            hi: 15,
            inc: 1,
            muscles: {Muscle.rearDelt: 1.0, Muscle.upperBack: 0.5},
          ),
          (
            id: 'inclineCurl',
            sets: 3,
            lo: 10,
            hi: 12,
            inc: 1,
            muscles: {Muscle.biceps: 1.0},
          ),
          // Pull — Rücken, hintere Schulter, Bizeps. Nur die Übungen, die in
          // A–D nicht vorkommen; der Rest steht schon oben.
          (
            id: 'barbellRow',
            sets: 4,
            lo: 8,
            hi: 12,
            inc: 2.5,
            muscles: {
              Muscle.upperBack: 1.0,
              Muscle.lats: 0.5,
              Muscle.biceps: 0.5,
              Muscle.lowerBack: 0.5,
            },
          ),
          (
            id: 'straightArmPulldown',
            sets: 3,
            lo: 12,
            hi: 15,
            inc: 2.5,
            muscles: {Muscle.lats: 1.0},
          ),
          (
            id: 'backExtension',
            sets: 3,
            lo: 12,
            hi: 15,
            inc: 2.5,
            muscles: {
              Muscle.lowerBack: 1.0,
              Muscle.glutes: 0.5,
              Muscle.hamstrings: 0.5,
            },
          ),
          // Legs — Beine komplett
          (
            id: 'legPress',
            sets: 4,
            lo: 8,
            hi: 12,
            inc: 5,
            muscles: {Muscle.quads: 1.0, Muscle.glutes: 0.5},
          ),
          (
            id: 'legExtension',
            sets: 3,
            lo: 12,
            hi: 15,
            inc: 2.5,
            muscles: {Muscle.quads: 1.0},
          ),
          // Ausgemustert: steht in keinem Workout mehr, bleibt aber im Katalog,
          // damit der gespeicherte Verlauf die Übung weiter auflösen kann.
          (
            id: 'hipThrust',
            sets: 3,
            lo: 8,
            hi: 12,
            inc: 5,
            muscles: {Muscle.glutes: 1.0, Muscle.hamstrings: 0.5},
          ),
          (
            id: 'calfRaiseSeated',
            sets: 3,
            lo: 15,
            hi: 20,
            inc: 5,
            muscles: {Muscle.calves: 1.0},
          ),
        ];

    test('Sätze, Bereiche, Steigerungen und Muskeln stimmen mit SPEC 4.4', () {
      for (final zeile in erwartet) {
        final e = ExerciseCatalog.all[zeile.id];
        expect(e, isNotNull, reason: '${zeile.id} fehlt im Katalog');
        expect(
          e!.sets,
          zeile.sets,
          reason: '${zeile.id}: ${e.sets} Sätze statt ${zeile.sets}',
        );
        expect(
          e.repLow,
          zeile.lo,
          reason: '${zeile.id}: untere Grenze ${e.repLow} statt ${zeile.lo}',
        );
        expect(
          e.repHigh,
          zeile.hi,
          reason: '${zeile.id}: obere Grenze ${e.repHigh} statt ${zeile.hi}',
        );
        expect(
          e.increment,
          zeile.inc,
          reason:
              '${zeile.id}: Steigerung ${e.increment} statt '
              '${zeile.inc}',
        );
        expect(
          e.muscles,
          zeile.muscles,
          reason: '${zeile.id}: Muskelzuordnung weicht ab',
        );
      }
    });

    test('Die Tabelle deckt jede Übung des Katalogs ab', () {
      final abgedeckt = erwartet.map((z) => z.id).toSet();
      final alle = ExerciseCatalog.all.keys.toSet();
      expect(
        alle.difference(abgedeckt),
        isEmpty,
        reason:
            'Nicht geprüft: ${(alle.difference(abgedeckt).toList()..sort())}',
      );
    });

    test('Die Tabelle nennt keine Übung, die es nicht gibt', () {
      // Die Gegenrichtung: Eine Zeile ohne Katalogeintrag wäre eine
      // Behauptung über eine Übung, die niemand sieht.
      final abgedeckt = erwartet.map((z) => z.id).toSet();
      expect(
        abgedeckt.length,
        erwartet.length,
        reason: 'eine ID steht zweimal in der Tabelle',
      );
      expect(abgedeckt.difference(ExerciseCatalog.all.keys.toSet()), isEmpty);
    });

    test('Der Katalog führt genau diese 33 Übungen', () {
      expect(ExerciseCatalog.all, hasLength(33));
    });

    test('Die Reihenfolge je Workout stimmt mit der Spec', () {
      expect(
        ExerciseCatalog.exercisesFor(Workout.a).map((e) => e.id).toList(),
        [
          'benchPress',
          'inclineDumbbellPress',
          'shoulderPressDumbbell',
          'dips',
          'lateralRaise',
          'overheadTriceps',
          'bicepsCurl',
        ],
      );
      expect(
        ExerciseCatalog.exercisesFor(Workout.b).map((e) => e.id).toList(),
        [
          'splitSquat',
          'romanianDeadlift',
          'legCurl',
          'hipAbduction',
          'calfRaiseStanding',
          'tibialisRaise',
          'cableFly',
          'sidePlank',
        ],
      );
      expect(
        ExerciseCatalog.exercisesFor(Workout.c).map((e) => e.id).toList(),
        [
          'pullUp',
          'oneArmRow',
          'cableRowClose',
          'facePull',
          'ezCurl',
          'hammerCurl',
          'tricepsPushdown',
        ],
      );
      expect(
        ExerciseCatalog.exercisesFor(Workout.d).map((e) => e.id).toList(),
        [
          'closeGripBench',
          'shoulderPressMachine',
          'lateralRaise',
          'reverseFly',
          'overheadTriceps',
          'ezCurl',
          'inclineCurl',
        ],
      );
    });

    test('Die Reihenfolge der frei wählbaren Workouts stimmt mit der Spec', () {
      expect(
        ExerciseCatalog.exercisesFor(Workout.push).map((e) => e.id).toList(),
        [
          'benchPress',
          'inclineDumbbellPress',
          'shoulderPressMachine',
          'cableFly',
          'lateralRaise',
          'tricepsPushdown',
          'overheadTriceps',
        ],
      );
      expect(
        ExerciseCatalog.exercisesFor(Workout.pull).map((e) => e.id).toList(),
        [
          'pullUp',
          'barbellRow',
          'cableRowClose',
          'straightArmPulldown',
          'facePull',
          'backExtension',
          'hammerCurl',
        ],
      );
      expect(
        ExerciseCatalog.exercisesFor(Workout.legs).map((e) => e.id).toList(),
        [
          'legPress',
          'romanianDeadlift',
          'splitSquat',
          'legCurl',
          'hipAbduction',
          'calfRaiseStanding',
          'legExtension',
        ],
      );
    });

    /// `Exercise.sets` ist eine Zahl pro Übung, nicht pro Workout.
    /// Wadenheben stehend steht in B und in Legs — stünde in der Spec an
    /// einer Stelle 6 und an der anderen 4, ließe sich das gar nicht
    /// abbilden, und der Katalog entschiede still für eine der beiden Zahlen.
    test(
      'Wadenheben stehend hat in Gym B und in Legs dieselben sechs Sätze',
      () {
        final inB = ExerciseCatalog.exercisesFor(Workout.b)
            .where((e) => e.id == 'calfRaiseStanding')
            .toList();
        final inLegs = ExerciseCatalog.exercisesFor(Workout.legs)
            .where((e) => e.id == 'calfRaiseStanding')
            .toList();
        expect(inB, hasLength(1));
        expect(inLegs, hasLength(1));
        expect(inB.single.sets, 6);
        expect(inB.single, inLegs.single);
      },
    );

    test(
      'Die umbenannte Übung heißt Zehenheben an der Wand und behält ihre ID',
      () {
        // Die ID steht im gespeicherten Verlauf. Wer sie mit dem Namen ändert,
        // verliert jeden alten Satz dieser Übung. Der deutsche Name und der
        // Suchbegriff sind das, was man findet — „Tibialis Raises“ findet man
        // nicht.
        final e = ExerciseCatalog.all['tibialisRaise'];
        expect(e, isNotNull);
        expect(e!.name, 'Zehenheben an der Wand');
        expect(e.muscles, {Muscle.tibialis: 1.0});
        expect(e.youTubeQuery, isNot('Tibialis Raises'));
      },
    );

    test('Bankdrücken steht mit den Werten aus der Spec im Katalog', () {
      final e = ExerciseCatalog.all['benchPress'];
      expect(e, isNotNull);
      expect(e!.name, 'Bankdrücken Langhantel');
      expect(e.sets, 4);
      expect(e.repLow, 6);
      expect(e.repHigh, 10);
      expect(e.increment, 2.5);
      expect(e.allowsAssist, isFalse);
      expect(e.muscles[Muscle.chest], 1.0);
      expect(e.muscles[Muscle.frontDelt], 0.5);
      expect(e.muscles[Muscle.triceps], 0.5);
    });

    test('Jede Übung trägt den Namen aus der Spec', () {
      // Der Name steht auf dem Bildschirm. Ein Tippfehler hier fällt
      // niemandem auf, der nur Zahlen prüft.
      const namen = {
        'benchPress': 'Bankdrücken Langhantel',
        'inclineDumbbellPress': 'Schrägbankdrücken Kurzhantel',
        'shoulderPressDumbbell': 'Schulterdrücken Kurzhantel sitzend',
        'dips': 'Dips',
        'lateralRaise': 'Seitheben',
        'overheadTriceps': 'Trizeps über Kopf am Kabel',
        'bicepsCurl': 'Bizeps-Curls Kurzhantel',
        'splitSquat': 'Bulgarian Split Squat',
        'romanianDeadlift': 'Rumänisches Kreuzheben',
        'hipThrust': 'Hip Thrust',
        'calfRaiseStanding': 'Wadenheben stehend einbeinig',
        'calfRaiseSeated': 'Wadenheben sitzend',
        'tibialisRaise': 'Zehenheben an der Wand',
        'cableFly': 'Kabel-Flys',
        'sidePlank': 'Seitstütz',
        'pullUp': 'Klimmzüge oder Latziehen',
        'oneArmRow': 'Rudern einarmig Kurzhantel',
        'cableRowClose': 'Kabelrudern eng',
        'facePull': 'Face Pulls',
        'ezCurl': 'SZ-Curls',
        'hammerCurl': 'Hammer Curls',
        'tricepsPushdown': 'Trizepsdrücken am Kabel',
        'closeGripBench': 'Enges Bankdrücken',
        'shoulderPressMachine': 'Schulterdrücken Maschine',
        'reverseFly': 'Reverse Flys',
        'inclineCurl': 'Schrägbank-Curls',
        'barbellRow': 'Langhantelrudern vorgebeugt',
        'straightArmPulldown': 'Überzüge am Kabel mit gestreckten Armen',
        'backExtension': 'Rückenstrecken',
        'legPress': 'Beinpresse',
        'legCurl': 'Beinbeuger-Maschine liegend',
        'hipAbduction': 'Abduktoren-Maschine',
        'legExtension': 'Beinstrecker-Maschine',
      };
      expect(
        namen,
        hasLength(33),
        reason: 'die Namenstabelle ist unvollständig',
      );
      namen.forEach((id, name) {
        final e = ExerciseCatalog.all[id];
        expect(e, isNotNull, reason: '$id fehlt im Katalog');
        expect(e!.name, name, reason: '$id: ${e.name} statt $name');
      });
    });
  });

  group('Die Texte wandern wortgleich mit', () {
    // Eine Auswahl, nicht alle: die Übung mit der längsten Geschichte
    // (Bankdrücken), die einzige Zeitübung, die umbenannte, eine mit
    // Unterstützung und die beiden mit den meisten Umlauten. Alle 33 Texte
    // abzuschreiben wäre eine zweite Kopie des Katalogs, keine Prüfung.

    test('Bankdrücken Langhantel', () {
      final e = ExerciseCatalog.all['benchPress']!;
      expect(
        e.cue,
        'Schulterblätter zusammen, Füße fest am Boden, Stange zur unteren '
        'Brust.',
      );
      expect(e.howTo, [
        'Auf der Bank liegen, Augen unter der Stange, Schulterblätter '
            'zusammenziehen.',
        'Stange kontrolliert zur unteren Brust senken, Ellenbogen etwa '
            '45 Grad.',
        'Kraftvoll nach oben drücken, ohne das Gesäß zu heben.',
      ]);
      expect(
        e.commonMistake,
        'Ellenbogen zu weit außen, das belastet die Schulter.',
      );
      expect(e.youTubeQuery, 'Bankdrücken Technik Anleitung');
    });

    test('Dips — die Übung mit Unterstützung', () {
      final e = ExerciseCatalog.all['dips']!;
      expect(e.allowsAssist, isTrue);
      expect(
        e.cue,
        'Schultern tief weg von den Ohren, Oberkörper leicht nach vorn.',
      );
      expect(e.howTo, [
        'An den Holmen aufstützen, Schultern tief weg von den Ohren.',
        'Oberkörper leicht nach vorn, bis der Oberarm waagerecht ist '
            'absenken.',
        'Nach oben drücken, ohne die Ellenbogen ganz durchzustrecken.',
      ]);
      expect(
        e.commonMistake,
        'Zu tief gehen, das reizt die Schultervorderseite.',
      );
      expect(e.youTubeQuery, 'Dips Technik Anleitung');
    });

    test('Seitstütz — die einzige Zeitübung', () {
      final e = ExerciseCatalog.all['sidePlank']!;
      expect(e.isTimed, isTrue);
      expect(e.name, 'Seitstütz');
      expect(e.cue, 'Körper in einer Linie, Hüfte oben halten.');
      expect(e.howTo, [
        'Auf die Seite legen, Unterarm unter der Schulter.',
        'Hüfte anheben, bis Schulter, Hüfte und Fuß eine Linie bilden.',
        'Ruhig atmen und die Zeit halten, dann Seite wechseln.',
      ]);
      expect(
        e.commonMistake,
        'Die Hüfte sinkt ab, sobald es anstrengend wird.',
      );
      expect(e.youTubeQuery, 'Seitstütz Side Plank Technik');
    });

    test('Zehenheben an der Wand — die umbenannte Übung', () {
      final e = ExerciseCatalog.all['tibialisRaise']!;
      expect(e.cue, 'Gegenspieler der Wade — hilft gegen Schienbeinschmerzen.');
      expect(e.howTo, [
        'Mit dem Rücken an der Wand stehen, Fersen etwa 30 cm davor.',
        'Fußspitzen so weit wie möglich anheben, Fersen bleiben am Boden.',
        'Langsam absenken, ohne die Zehen aufzusetzen.',
      ]);
      expect(e.commonMistake, 'Zu schnell und ohne volle Bewegung.');
      expect(e.youTubeQuery, 'Zehenheben Schienbein Übung Läufer');
    });

    test('Überzüge am Kabel mit gestreckten Armen', () {
      final e = ExerciseCatalog.all['straightArmPulldown']!;
      expect(
        e.cue,
        'Arme bleiben gestreckt — die Bewegung kommt allein aus der '
        'Schulter.',
      );
      expect(e.howTo, [
        'Stange am hohen Kabelzug greifen, einen Schritt zurücktreten.',
        'Leicht vorbeugen, Arme gestreckt lassen, Ellenbogen nur minimal '
            'gebeugt.',
        'Stange im Bogen zu den Oberschenkeln ziehen, unten kurz halten.',
      ]);
      expect(
        e.commonMistake,
        'Die Ellenbogen beugen, dann wird daraus Trizepsdrücken.',
      );
      expect(e.youTubeQuery, 'Überzüge am Kabel gestreckte Arme Latissimus');
    });

    test('Wadenheben stehend einbeinig — die mit den sechs Sätzen', () {
      final e = ExerciseCatalog.all['calfRaiseStanding']!;
      expect(e.cue, 'Volle Dehnung unten, oben kurz halten.');
      expect(e.howTo, [
        'Auf einer Stufe stehen, nur der Ballen hat Kontakt.',
        'Ferse langsam so weit wie möglich absenken.',
        'Auf den Ballen hochdrücken und oben eine Sekunde halten.',
      ]);
      expect(
        e.commonMistake,
        'Zu schnell wippen, dann arbeitet die Sehne statt des Muskels.',
      );
      expect(e.youTubeQuery, 'Wadenheben stehend einbeinig Technik');
    });

    test('Die neuen Übungen tragen die Namen aus der Spec', () {
      const erwartet = {
        'barbellRow': 'Langhantelrudern vorgebeugt',
        'straightArmPulldown': 'Überzüge am Kabel mit gestreckten Armen',
        'backExtension': 'Rückenstrecken',
        'legPress': 'Beinpresse',
        'legCurl': 'Beinbeuger-Maschine liegend',
        'hipAbduction': 'Abduktoren-Maschine',
        'legExtension': 'Beinstrecker-Maschine',
      };
      erwartet.forEach((id, name) {
        final e = ExerciseCatalog.all[id];
        expect(e, isNotNull, reason: '$id fehlt im Katalog');
        expect(e!.name, name, reason: '$id: ${e.name} statt $name');
      });
    });
  });

  group('Der Katalog und die Muskelkarte passen zusammen', () {
    test('Jeder Muskel der Spec wird von mindestens einer Übung getroffen', () {
      // Ein Muskel ohne Übung stünde auf der Karte dauerhaft bei 0, ohne
      // dass man etwas dagegen tun könnte. Das wäre ein Zielbereich, den die
      // App selbst unerreichbar macht.
      final getroffen = <Muscle>{
        for (final e in ExerciseCatalog.all.values) ...e.muscles.keys,
      };
      final ohne = Muscle.values.toSet().difference(getroffen);
      expect(
        ohne,
        isEmpty,
        reason: 'ohne Übung: ${ohne.map((m) => m.code).toList()}',
      );
    });

    test('Jeder Muskel ist bei mindestens einer Übung der Hauptmuskel', () {
      final haupt = <Muscle>{
        for (final e in ExerciseCatalog.all.values)
          for (final eintrag in e.muscles.entries)
            if (eintrag.value == 1.0) eintrag.key,
      };
      final ohne = Muscle.values.toSet().difference(haupt);
      expect(
        ohne,
        isEmpty,
        reason: 'nur als Nebenmuskel: ${ohne.map((m) => m.code).toList()}',
      );
    });

    test('Der Katalog benutzt genau zwei Gewichte', () {
      final gewichte = <double>{
        for (final e in ExerciseCatalog.all.values) ...e.muscles.values,
      };
      expect(gewichte, {1.0, 0.5});
    });
  });
}
