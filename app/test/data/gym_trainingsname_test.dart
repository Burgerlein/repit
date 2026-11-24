import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/gym_repository.dart';
import 'package:repit/data/gym_training_repository.dart';

import 'gym_training_support.dart';

/// Tests für **`gym_sitzungen.trainings_name` und die Kennung des
/// Trainings in der Sitzung** — Schreiben, Lesen, Einfrieren — und für
/// `GymRepository.entwurf()` mit der Kennung eines eigenen Trainings
/// (#532, unter #531). Task 1.6 des Plans
/// `docs/superpowers/plans/2026-11-19-eigene-trainings-plan.md`.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden. Hält der
/// Implementierende eine Erwartung für falsch, wird das **gemeldet, nicht
/// korrigiert**.
///
/// ## Woher die Anforderung kommt
///
/// Spec `docs/superpowers/specs/2026-11-19-eigene-trainings-design.md`,
/// Abschnitt 4.6 (Der Verlauf friert ein), 4.7 (Der Entwurf der Erfassung)
/// und 15.2/15.3; die Kern-Seite (`ImportedSession.trainingId`/
/// `trainingName`, `GymSessionMerge.sessionKey`) steht in
/// `Packages/trainings_core/test/gym_session_training_test.dart`.
///
/// ## Wer hat was entschieden
///
/// - **Entscheidung von Tim [18.11.2026]:** Die Sitzung speichert den
///   Trainings**namen** zum Zeitpunkt der Sitzung; **Umbenennen und Löschen
///   schreiben den Verlauf nicht um.** Gruppe „Der Name friert ein".
/// - **Entscheidung von Tim [18.11.2026/19.11.2026]:** Mehrere Trainings am
///   Tag sind möglich — zwei verschiedene eigene Trainings am selben Tag
///   bestehen nebeneinander. Gruppe „Zwei Trainings am selben Tag".
/// - **Folgerung (Spec 4.6):** `gym_sitzungen.workout` trägt die **Kennung**
///   des Trainings — für Enum-Fälle der `Workout.code`, sonst die UUID; der
///   Leser macht daraus `workout: <Fall>`, `trainingId: null` **exakt wie
///   heute** (damit jede alte Sitzung gleich `==` ist) oder `workout: null`,
///   `trainingId: <Wert>`. Eine alte Zeile bekommt keinen erfundenen Namen:
///   `NULL` bleibt `NULL`.
/// - **Folgerung (Spec 4.7):** `GymRepository.entwurf()` löst eine UUID
///   gegen `gym_trainings` auf und wirft erst, wenn auch dort nichts steht —
///   der Entwurf wird nie unsichtbar.
/// - **Vorschlag der Spec, hier vorausgesetzt:** `trainingId` ist nur für
///   Trainings ohne Enum-Fall gesetzt (4.6, „[Vorschlag zur Form]").
///
/// ## API, die diese Tests verbindlich vorgeben
///
/// Keine neuen Methoden: `GymRepository.legeAb`, `sitzung`, `sitzungen`,
/// `letzteSitzungJeWorkout`, `trainierteSaetze`, `entwurf` — mit den neuen
/// Feldern von `ImportedSession` (Kern). `legeAb` schreibt `trainingId ??
/// workout?.code` in `workout` und `trainingName` in `trainings_name`.
///
/// ## Was hier **nicht** getestet wird, weil die Spec es nicht sagt
///
/// - **Was `entwurf()` für eine UUID als `GymEntwurf.workout` liefert.**
///   `GymEntwurf.workout` ist heute nicht nullbar; Task 3.1 führt
///   `trainingId` ein. Geprüft wird hier nur, **dass** `entwurf()` nicht
///   wirft, solange das Training existiert, und welche Kennung der
///   Sitzung gehört.
/// - **Eine Sitzung, die `workout` und `trainingId` zugleich trägt** (4.6:
///   „nur für Trainings ohne Enum-Fall").
/// - **Der Name beim Abschließen** über `GymLogNotifier` —
///   `app/test/gym/gym_log_trainingsname_test.dart`.
///
/// **Alle Namen, Zahlen und Zeitpunkte sind erfunden** (Jahr 2099).
void main() {
  CompletedSet satz(double kg, int wdh) => CompletedSet(weight: kg, reps: wdh);

  ImportedSession sitzung(
    String id,
    DateTime datum, {
    Workout? workout,
    String? trainingId,
    String? trainingName,
    List<ImportedExercise>? exercises,
  }) => ImportedSession(
    id: id,
    date: datum,
    workout: workout,
    minutes: 60,
    note: null,
    exercises:
        exercises ??
        [
          ImportedExercise(exerciseId: 'benchPress', sets: [satz(60, 8)]),
        ],
    trainingId: trainingId,
    trainingName: trainingName,
  );

  /// Mittag UTC: auf jeder Berliner Tagesgrenze derselbe Tag.
  final tag1 = DateTime.utc(2099, 3, 2, 12);
  final tag2 = DateTime.utc(2099, 3, 3, 12);

  group('Schreiben und Lesen (Spec 4.6)', () {
    test('eine Sitzung mit Enum-Fall und Namen: `workout` bleibt der Code, '
        'der Name steht in der Spalte, der Rundweg ist gleich `==`', () async {
      final db = neueDb();
      final repo = GymRepository(db);
      final original = sitzung(
        'PRUEF-S1',
        tag1,
        workout: Workout.push,
        trainingName: 'Push — Brust, Schultern, Trizeps',
      );

      await repo.legeAb(original);

      final zeile = (await zeilen(db, 'gym_sitzungen')).single;
      expect(zeile['workout'], 'Push');
      expect(zeile['trainings_name'], 'Push — Brust, Schultern, Trizeps');
      final gelesen = await repo.sitzung('PRUEF-S1');
      expect(gelesen, original);
      expect(gelesen!.workout, Workout.push);
      expect(gelesen.trainingId, isNull, reason: 'nur ohne Enum-Fall gesetzt');
      expect(gelesen.trainingName, 'Push — Brust, Schultern, Trizeps');
    });

    test('eine Sitzung ohne Namen schreibt `NULL`, nie einen erfundenen Namen',
        () async {
      final db = neueDb();
      final repo = GymRepository(db);

      await repo.legeAb(sitzung('PRUEF-S1', tag1, workout: Workout.a));

      expect((await zeilen(db, 'gym_sitzungen')).single['trainings_name'], isNull);
      expect((await repo.sitzung('PRUEF-S1'))!.trainingName, isNull);
    });

    test('eine alte Zeile (`trainings_name` ist `NULL`) liest sich gleich `==` '
        'wie vor der Änderung', () async {
      final db = neueDb();
      final repo = GymRepository(db);
      await db.customStatement(
        'INSERT INTO gym_sitzungen (id, tag, zeitpunkt, workout, minuten) '
        "VALUES ('PRUEF-ALT', '2099-03-02', '2099-03-02T12:00:00.000Z', "
        "'A', 60);",
      );
      await db.customStatement(
        'INSERT INTO gym_saetze '
        '(sitzung_id, uebung_id, uebung_pos, satz_nr, gewicht_kg, wdh) '
        "VALUES ('PRUEF-ALT', 'benchPress', 1, 1, 60.0, 8);",
      );

      final gelesen = await repo.sitzung('PRUEF-ALT');

      expect(
        gelesen,
        sitzung('PRUEF-ALT', tag1, workout: Workout.a),
        reason:
            'jede bestehende Sitzung bleibt gleich: workout A, keine '
            'Kennung, kein Name (Spec 4.6)',
      );
      expect(gelesen!.trainingId, isNull);
      expect(gelesen.trainingName, isNull);
    });

    test('ein eigenes Training: `workout` trägt die UUID, gelesen wird '
        '`workout: null` und `trainingId`', () async {
      final db = neueDb();
      final repo = GymRepository(db);
      final original = sitzung(
        'PRUEF-S1',
        tag1,
        trainingId: 'UUID-EIGENES-1',
        trainingName: 'Kurzhantel zuhause',
      );

      await repo.legeAb(original);

      final zeile = (await zeilen(db, 'gym_sitzungen')).single;
      expect(zeile['workout'], 'UUID-EIGENES-1');
      expect(zeile['trainings_name'], 'Kurzhantel zuhause');
      final gelesen = await repo.sitzung('PRUEF-S1');
      expect(gelesen, original);
      expect(gelesen!.workout, isNull);
      expect(gelesen.trainingId, 'UUID-EIGENES-1');
      expect(gelesen.trainingName, 'Kurzhantel zuhause');
    });

    test('Sätze eines eigenen Trainings stehen in der Auswertung, und die '
        'Abfrage nach dem letzten Mal je Workout wirft nicht an der UUID',
        () async {
      final db = neueDb();
      final repo = GymRepository(db);
      await repo.legeAb(
        sitzung(
          'PRUEF-S1',
          tag1,
          trainingId: 'UUID-EIGENES-1',
          trainingName: 'Kurzhantel zuhause',
          exercises: [
            ImportedExercise(
              exerciseId: 'benchPress',
              sets: [satz(60, 8), satz(62.5, 6)],
            ),
          ],
        ),
      );
      await repo.legeAb(sitzung('PRUEF-S2', tag2, workout: Workout.push));

      final saetze = await repo.trainierteSaetze(
        vonTag: '2099-03-01',
        bisTag: '2099-03-31',
      );
      final letzte = await repo.letzteSitzungJeWorkout();

      expect(saetze, hasLength(3), reason: 'zwei Sätze vom eigenen, einer von Push');
      expect(
        letzte.keys.toList(),
        [Workout.push],
        reason:
            'ein eigenes Training hat keinen Enum-Fall — übergangen statt '
            'geraten, und kein Fehler (Spec 4.6)',
      );
    });
  });

  group('Der Name friert ein (Tim, 18.11.2026)', () {
    test('Umbenennen des Trainings ändert die alte Sitzung nicht', () async {
      final db = neueDb();
      final trainings = GymTrainingRepository(db);
      final sitzungen = GymRepository(db);
      await trainings.speichere(eigenes('UUID-EIGENES-1', name: 'Oberkörper'));
      final alt = sitzung(
        'PRUEF-S1',
        tag1,
        trainingId: 'UUID-EIGENES-1',
        trainingName: 'Oberkörper',
      );
      await sitzungen.legeAb(alt);

      await trainings.speichere(
        eigenes('UUID-EIGENES-1', name: 'Oberkörper Neu und Anders'),
      );

      expect((await trainings.training('UUID-EIGENES-1'))!.name, 'Oberkörper Neu und Anders');
      expect(await sitzungen.sitzung('PRUEF-S1'), alt);
      expect((await sitzungen.sitzung('PRUEF-S1'))!.trainingName, 'Oberkörper');
      expect(
        (await zeilen(db, 'gym_sitzungen')).single['trainings_name'],
        'Oberkörper',
        reason: 'die Spalte wird nie nachträglich aktualisiert',
      );
    });

    test('Löschen des eigenen Trainings lässt die Sitzung unverändert',
        () async {
      final db = neueDb();
      final trainings = GymTrainingRepository(db);
      final sitzungen = GymRepository(db);
      await trainings.speichere(eigenes('UUID-EIGENES-1', name: 'Oberkörper'));
      final alt = sitzung(
        'PRUEF-S1',
        tag1,
        trainingId: 'UUID-EIGENES-1',
        trainingName: 'Oberkörper',
      );
      await sitzungen.legeAb(alt);

      await trainings.loesche('UUID-EIGENES-1');

      expect(await trainings.training('UUID-EIGENES-1'), isNull);
      expect(await sitzungen.sitzung('PRUEF-S1'), alt);
      expect(await sitzungen.sitzungen(), [alt]);
    });

    test('ein Tombstone am Template (per SQL, Templates sind nicht löschbar, '
        'Spec 26 Nr. 1) lässt die Sitzung mit Namen unverändert', () async {
      final db = neueDb();
      final sitzungen = GymRepository(db);
      final alt = sitzung(
        'PRUEF-S1',
        tag1,
        workout: Workout.push,
        trainingName: 'Push — Brust, Schultern, Trizeps',
      );
      await sitzungen.legeAb(alt);

      await db.customStatement(
        "UPDATE gym_trainings SET geloescht = 1 WHERE id = 'Push';",
      );

      expect(await sitzungen.sitzung('PRUEF-S1'), alt);
    });

    test('ein später abgeschlossenes Training schreibt eine ältere Sitzung '
        'nicht um', () async {
      final db = neueDb();
      final sitzungen = GymRepository(db);
      final erste = sitzung(
        'PRUEF-S1',
        tag1,
        trainingId: 'UUID-EIGENES-1',
        trainingName: 'Alter Name',
      );
      await sitzungen.legeAb(erste);

      await sitzungen.legeAb(
        sitzung(
          'PRUEF-S2',
          tag2,
          trainingId: 'UUID-EIGENES-1',
          trainingName: 'Neuer Name',
        ),
      );

      expect((await sitzungen.sitzung('PRUEF-S1'))!.trainingName, 'Alter Name');
      expect((await sitzungen.sitzung('PRUEF-S2'))!.trainingName, 'Neuer Name');
    });
  });

  group('Zwei Trainings am selben Tag (Spec 4.6, `sessionKey`)', () {
    test('zwei verschiedene eigene Trainings bestehen nebeneinander',
        () async {
      final db = neueDb();
      final repo = GymRepository(db);
      final erste = sitzung(
        'PRUEF-S1',
        tag1,
        trainingId: 'UUID-EIGENES-1',
        trainingName: 'Oberkörper',
      );
      final zweite = sitzung(
        'PRUEF-S2',
        tag1.add(const Duration(hours: 3)),
        trainingId: 'UUID-EIGENES-2',
        trainingName: 'Beine zuhause',
      );

      await repo.legeAb(erste);
      await repo.legeAb(zweite);

      final alle = await repo.sitzungen();
      expect(alle, hasLength(2), reason: 'die zweite ersetzt die erste nicht');
      expect(alle, containsAll([erste, zweite]));
      expect(await repo.sitzung('PRUEF-S1'), erste);
      expect(await repo.sitzung('PRUEF-S2'), zweite);
    });

    test('dasselbe eigene Training am selben Tag zweimal ersetzt die erste '
        'Sitzung', () async {
      final db = neueDb();
      final repo = GymRepository(db);
      await repo.legeAb(
        sitzung(
          'PRUEF-S1',
          tag1,
          trainingId: 'UUID-EIGENES-1',
          trainingName: 'Oberkörper',
        ),
      );
      final zweite = sitzung(
        'PRUEF-S2',
        tag1.add(const Duration(hours: 3)),
        trainingId: 'UUID-EIGENES-1',
        trainingName: 'Oberkörper',
      );

      await repo.legeAb(zweite);

      expect(await repo.sitzungen(), [zweite]);
      expect(await anzahl(db, 'gym_sitzungen'), 1);
      expect(await anzahl(db, 'gym_saetze'), 1, reason: 'samt ihren Sätzen');
    });

    test('ein eigenes Training und ein Enum-Training am selben Tag bestehen '
        'nebeneinander', () async {
      final db = neueDb();
      final repo = GymRepository(db);
      final eigene = sitzung(
        'PRUEF-S1',
        tag1,
        trainingId: 'UUID-EIGENES-1',
        trainingName: 'Oberkörper',
      );
      final push = sitzung(
        'PRUEF-S2',
        tag1.add(const Duration(hours: 3)),
        workout: Workout.push,
        trainingName: 'Push — Brust, Schultern, Trizeps',
      );
      final gymA = sitzung(
        'PRUEF-S3',
        tag1.add(const Duration(hours: 4)),
        workout: Workout.a,
      );

      await repo.legeAb(eigene);
      await repo.legeAb(push);
      await repo.legeAb(gymA);

      expect(await anzahl(db, 'gym_sitzungen'), 3);
      expect(await repo.sitzungen(), containsAll([eigene, push, gymA]));
    });

    test('ein eigenes Training ohne Namen ist kein „kein Workout": zwei '
        'verschiedene kollidieren auch dann nicht', () async {
      final db = neueDb();
      final repo = GymRepository(db);

      await repo.legeAb(
        sitzung('PRUEF-S1', tag1, trainingId: 'UUID-EIGENES-1'),
      );
      await repo.legeAb(
        sitzung('PRUEF-S2', tag1, trainingId: 'UUID-EIGENES-2'),
      );

      expect(await anzahl(db, 'gym_sitzungen'), 2);
    });
  });

  group('Der Entwurf der Erfassung trägt eine Kennung (Spec 4.7)', () {
    test('ein Entwurf für ein eigenes Training, das es gibt, wird gelesen '
        'und nie unsichtbar', () async {
      final db = neueDb();
      await GymTrainingRepository(db).speichere(eigenes('UUID-EIGENES-1'));
      await laufendesTraining(db, 'UUID-EIGENES-1');

      final entwurf = await GymRepository(db).entwurf();

      expect(entwurf, isNotNull);
      expect(entwurf!.sitzungId, 'PRUEF-SITZUNG');
    });

    test('ein Entwurf für ein Training, das es nicht (mehr) gibt, wirft '
        '`StateError`', () async {
      final db = neueDb();
      await laufendesTraining(db, 'UUID-GELOESCHT');

      await expectLater(GymRepository(db).entwurf(), throwsStateError);
    });

    test('ein Entwurf mit einer Kennung, die weder ein Workout noch ein '
        'Training ist, wirft weiter `StateError`', () async {
      final db = neueDb();
      await GymTrainingRepository(db).speichere(eigenes('UUID-EIGENES-1'));
      await laufendesTraining(db, 'ZZ-IRGENDWAS');

      await expectLater(GymRepository(db).entwurf(), throwsStateError);
    });

    test('der Entwurf für einen Enum-Fall liest sich wie bisher', () async {
      final db = neueDb();
      await laufendesTraining(db, 'Push');

      final entwurf = await GymRepository(db).entwurf();

      expect(entwurf!.workout, Workout.push);
      expect(entwurf.sitzungId, 'PRUEF-SITZUNG');
    });

    test('auch der Entwurf für Gym A (keine Zeile, nur der Enum-Fall) bleibt '
        'sichtbar — Tims laufendes Training darf nicht verschwinden',
        () async {
      final db = neueDb();
      await laufendesTraining(db, 'A');

      final entwurf = await GymRepository(db).entwurf();

      expect(entwurf!.workout, Workout.a);
    });
  });
}
