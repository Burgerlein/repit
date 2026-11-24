import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show sqlite3;
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/gym_repository.dart';
import 'package:repit/data/gym_training_repository.dart';

import 'gym_training_support.dart';

/// Tests für den **Entwurf der Erfassung mit einer Kennung** (`GymEntwurf`
/// und `GymRepository.speichereEntwurf`/`entwurf`, #534 unter #531, Task 3.1
/// des Plans `docs/superpowers/plans/2026-11-19-eigene-trainings-plan.md`):
/// `trainingId` als Rundweg, `kennung`, die Gleichheit, und was der Entwurf
/// mit der Sperre aus Spec 4.7 zu tun hat. Der **Lesepfad** über eine
/// Kennung, die es gibt oder nicht gibt, steht schon in
/// `gym_trainingsname_test.dart` (Gruppe „Der Entwurf der Erfassung trägt
/// eine Kennung"); hier steht, was **geschrieben** wird — dort ist der Entwurf
/// von Hand eingefügt (`laufendesTraining`).
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden. Hält der
/// Implementierende eine Erwartung für falsch, wird das **gemeldet, nicht
/// korrigiert**.
///
/// ## Woher die Anforderung kommt
///
/// Spec `docs/superpowers/specs/2026-11-19-eigene-trainings-design.md`,
/// Abschnitt 4.7 („Die Spalte `gym_entwuerfe.workout` … trägt **die Kennung
/// des Trainings** (Code oder UUID)"; „Solange `gym_entwuerfe` die Kennung
/// eines Trainings trägt, lehnt das Repository `speichere(...)` und
/// `loesche(...)` für dieses Training ab"), 4.6 und 15.2.
///
/// ## Wer hat was entschieden
///
/// - **Entscheidung von Tim:** Die Ablage kennt genau **einen** Entwurf
///   (10.11.2026) — das gilt, **gleich welches Training** ihn trägt.
/// - **Folgerung (Spec 4.7):** `GymEntwurf.workout` ist `null` für ein
///   Training ohne Enum-Fall, dessen Kennung dann in `trainingId` steht; wo
///   es einen Fall gibt, steht er in `workout` und `trainingId` ist `null`
///   (wie bei `ImportedSession`). `kennung` ist `trainingId ?? workout!.code`.
///   Der Konstruktor verlangt eines von beiden.
/// - **Festlegung des Test-Agenten, Tim hat sie nicht gesehen:** Der Entwurf
///   eines **Templates mit Enum-Fall** (`Push`) trägt den Code als Kennung —
///   `GymEntwurf(workout: Workout.push)` —, nicht eine zweite
///   `trainingId`-Fassung desselben Trainings.
///
/// **Alle Namen, Zahlen und Zeitpunkte sind erfunden** (Jahr 2099).
void main() {
  GymEntwurf entwurf({
    Workout? workout,
    String? trainingId,
    String sitzungId = 'PRUEF-S1',
    String? dauer = '55',
    String? notiz,
    String felder = '{"version":1,"uebungen":[]}',
  }) => GymEntwurf(
    workout: workout,
    trainingId: trainingId,
    sitzungId: sitzungId,
    zeitpunkt: DateTime.utc(2099, 3, 2, 16, 30),
    dauer: dauer,
    notiz: notiz,
    gespeichertAm: DateTime.utc(2099, 3, 2, 16, 41, 12),
    felder: felder,
  );

  group('Die Kennung des Entwurfs', () {
    test('ein Entwurf mit Enum-Fall: `kennung` ist der Code, `trainingId` '
        'bleibt `null`', () {
      final e = entwurf(workout: Workout.push);

      expect(e.kennung, 'Push');
      expect(e.workout, Workout.push);
      expect(e.trainingId, isNull);
    });

    test('ein Entwurf ohne Enum-Fall: `kennung` ist die UUID, `workout` ist '
        '`null`', () {
      final e = entwurf(trainingId: 'UUID-EIGENES-1');

      expect(e.kennung, 'UUID-EIGENES-1');
      expect(e.workout, isNull);
      expect(e.trainingId, 'UUID-EIGENES-1');
    });

    test('ohne Enum-Fall **und** ohne Kennung gibt es keinen Entwurf', () {
      expect(
        () => entwurf(),
        throwsA(isA<AssertionError>()),
        reason: 'Ein Entwurf gehört zu einem Training (Spec 4.7)',
      );
    });

    test('Gleichheit: `trainingId` geht ein, auch bei sonst gleichen Feldern', () {
      expect(
        entwurf(trainingId: 'UUID-1'),
        entwurf(trainingId: 'UUID-1'),
      );
      expect(
        entwurf(trainingId: 'UUID-1').hashCode,
        entwurf(trainingId: 'UUID-1').hashCode,
      );
      expect(
        entwurf(trainingId: 'UUID-1'),
        isNot(entwurf(trainingId: 'UUID-2')),
      );
      expect(
        entwurf(trainingId: 'UUID-1'),
        isNot(entwurf(workout: Workout.push)),
      );
    });
  });

  group('Hin und zurück über die Ablage', () {
    test('ein Entwurf für ein eigenes Training kommt gleich zurück — mit '
        'Kennung, ohne Enum-Fall', () async {
      final db = neueDb();
      await GymTrainingRepository(db).speichere(eigenes('UUID-EIGENES-1'));
      final e = entwurf(
        trainingId: 'UUID-EIGENES-1',
        notiz: 'Schulter zwickt',
        felder: '{"version":1,"uebungen":[{"id":"benchPress"}]}',
      );

      await GymRepository(db).speichereEntwurf(e);

      final gelesen = (await GymRepository(db).entwurf())!;
      expect(gelesen, e);
      expect(gelesen.workout, isNull);
      expect(gelesen.trainingId, 'UUID-EIGENES-1');
      expect(gelesen.kennung, 'UUID-EIGENES-1');
      expect(gelesen.dauer, '55');
      expect(gelesen.notiz, 'Schulter zwickt');
    });

    test('die Spalte `workout` trägt die UUID — beim Enum-Fall den Code', () async {
      final db = neueDb();
      await GymTrainingRepository(db).speichere(eigenes('UUID-EIGENES-1'));
      final repo = GymRepository(db);

      await repo.speichereEntwurf(entwurf(trainingId: 'UUID-EIGENES-1'));
      expect(
        (await zeilen(db, 'gym_entwuerfe')).single['workout'],
        'UUID-EIGENES-1',
      );

      await repo.verwirfEntwurf();
      await repo.speichereEntwurf(entwurf(workout: Workout.push));
      expect((await zeilen(db, 'gym_entwuerfe')).single['workout'], 'Push');
    });

    test('ein Entwurf für ein Enum-Training liest sich wie bisher — auch '
        'nach dem Rundweg', () async {
      final db = neueDb();
      final e = entwurf(workout: Workout.a);

      await GymRepository(db).speichereEntwurf(e);

      final gelesen = (await GymRepository(db).entwurf())!;
      expect(gelesen, e);
      expect(gelesen.workout, Workout.a);
      expect(gelesen.trainingId, isNull);
    });

    test('derselbe Entwurf **ersetzt** sich: Zwischenstände desselben '
        'Trainings bleiben einer', () async {
      final db = neueDb();
      await GymTrainingRepository(db).speichere(eigenes('UUID-EIGENES-1'));
      final repo = GymRepository(db);

      await repo.speichereEntwurf(
        entwurf(trainingId: 'UUID-EIGENES-1', dauer: '50'),
      );
      await repo.speichereEntwurf(
        entwurf(trainingId: 'UUID-EIGENES-1', dauer: '60'),
      );

      expect(await anzahl(db, 'gym_entwuerfe'), 1);
      expect((await repo.entwurf())!.dauer, '60');
    });

    test('Verwerfen löscht ihn, auch den eines eigenen Trainings', () async {
      final db = neueDb();
      await GymTrainingRepository(db).speichere(eigenes('UUID-EIGENES-1'));
      final repo = GymRepository(db);
      await repo.speichereEntwurf(entwurf(trainingId: 'UUID-EIGENES-1'));

      await repo.verwirfEntwurf();

      expect(await repo.entwurf(), isNull);
      expect(await anzahl(db, 'gym_entwuerfe'), 0);
    });

    test('der Entwurf überlebt das Schließen und Öffnen derselben Datei', () async {
      final roh = sqlite3.openInMemory();
      addTearDown(roh.close);
      final erste = await oeffne(roh);
      await GymTrainingRepository(erste).speichere(eigenes('UUID-EIGENES-1'));
      final e = entwurf(trainingId: 'UUID-EIGENES-1');
      await GymRepository(erste).speichereEntwurf(e);
      await erste.close();

      final zweite = await oeffne(roh);
      addTearDown(zweite.close);

      expect(await GymRepository(zweite).entwurf(), e);
    });
  });

  group('Ein Entwurf, nicht sieben — gleich welches Training (Tim, 10.11.2026)', () {
    test('läuft ein eigenes Training, wird kein Enum-Training darübergelegt', () async {
      final db = neueDb();
      await GymTrainingRepository(db).speichere(eigenes('UUID-EIGENES-1'));
      final repo = GymRepository(db);
      await repo.speichereEntwurf(entwurf(trainingId: 'UUID-EIGENES-1'));

      await expectLater(
        repo.speichereEntwurf(entwurf(workout: Workout.push)),
        throwsStateError,
      );

      expect((await repo.entwurf())!.kennung, 'UUID-EIGENES-1');
    });

    test('läuft ein Enum-Training, wird kein eigenes darübergelegt', () async {
      final db = neueDb();
      await GymTrainingRepository(db).speichere(eigenes('UUID-EIGENES-1'));
      final repo = GymRepository(db);
      await repo.speichereEntwurf(entwurf(workout: Workout.push));

      await expectLater(
        repo.speichereEntwurf(entwurf(trainingId: 'UUID-EIGENES-1')),
        throwsStateError,
      );

      expect((await repo.entwurf())!.kennung, 'Push');
    });

    test('zwei verschiedene eigene Trainings sind zwei Kennungen: das zweite '
        'wird abgewiesen', () async {
      final db = neueDb();
      final trainings = GymTrainingRepository(db);
      await trainings.speichere(eigenes('UUID-EIGENES-1'));
      await trainings.speichere(eigenes('UUID-EIGENES-2', name: 'Zweites'));
      final repo = GymRepository(db);
      await repo.speichereEntwurf(entwurf(trainingId: 'UUID-EIGENES-1'));

      await expectLater(
        repo.speichereEntwurf(entwurf(trainingId: 'UUID-EIGENES-2')),
        throwsStateError,
      );
    });
  });

  group('Der geschriebene Entwurf sperrt sein Training (Spec 4.7)', () {
    test('Speichern und Löschen werden abgelehnt, solange der Entwurf '
        'steht — und gehen danach wieder', () async {
      final db = neueDb();
      final trainings = GymTrainingRepository(db);
      await trainings.speichere(eigenes('UUID-EIGENES-1'));
      final repo = GymRepository(db);
      await repo.speichereEntwurf(entwurf(trainingId: 'UUID-EIGENES-1'));
      final vorher = await abbild(db, 'UUID-EIGENES-1');

      await expectLater(
        trainings.speichere(eigenes('UUID-EIGENES-1', name: 'Anders')),
        throwsStateError,
      );
      await expectLater(trainings.loesche('UUID-EIGENES-1'), throwsStateError);
      expect(await abbild(db, 'UUID-EIGENES-1'), vorher);

      await repo.verwirfEntwurf();

      await trainings.speichere(eigenes('UUID-EIGENES-1', name: 'Anders'));
      expect((await trainings.training('UUID-EIGENES-1'))!.name, 'Anders');
    });

    test('Abschließen gibt das Training frei: Die Sitzung steht da, der '
        'Entwurf ist weg, und das Training lässt sich wieder ändern', () async {
      final db = neueDb();
      final trainings = GymTrainingRepository(db);
      await trainings.speichere(eigenes('UUID-EIGENES-1'));
      final repo = GymRepository(db);
      await repo.speichereEntwurf(entwurf(trainingId: 'UUID-EIGENES-1'));

      await repo.schliesseAb(
        ImportedSession(
          id: 'PRUEF-S1',
          date: DateTime.utc(2099, 3, 2, 16, 30),
          workout: null,
          trainingId: 'UUID-EIGENES-1',
          trainingName: 'Oberkörper zuhause',
          minutes: 55,
          note: null,
          exercises: [
            ImportedExercise(
              exerciseId: 'benchPress',
              sets: [CompletedSet(weight: 60, reps: 8)],
            ),
          ],
        ),
      );

      expect(await repo.entwurf(), isNull);
      await trainings.speichere(eigenes('UUID-EIGENES-1', name: 'Anders'));
    });
  });
}
