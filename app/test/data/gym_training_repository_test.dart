import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/data/gym_repository.dart';
import 'package:repit/data/gym_training_repository.dart';

import 'gym_training_support.dart';

/// Tests für **`GymTrainingRepository`** — Lesen, Speichern, Kopie,
/// Löschen (nur Eigene), Sperre, Tags und Startbefüllung (#532, unter #531).
/// Task 1.6 des Plans `docs/superpowers/plans/2026-11-19-eigene-trainings-
/// plan.md`.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden. Hält der
/// Implementierende eine Erwartung für falsch, wird das **gemeldet, nicht
/// korrigiert**.
///
/// Die **Rotation** (`rotation()`, Herausnehmen beim Löschen, Neustarts)
/// steht in `gym_training_rotation_test.dart`, die **Entwurfsmechanik** in
/// `gym_training_zwischenstand_test.dart`, **Trainingsname und Sitzungen**
/// in `gym_trainingsname_test.dart`. Hilfen: `gym_training_support.dart`.
///
/// ## Woher die Anforderung kommt
///
/// Spec `docs/superpowers/specs/2026-11-19-eigene-trainings-design.md`,
/// Abschnitt 4.4 bis 4.7 (Löschen, Kopie, Verlauf, Sperre), 6.1/6.2
/// (Repository), **und die Nachträge 22 bis 25, die ältere Abschnitte
/// schlagen:**
///
/// - **Abschnitt 23 [Tim, 19.11.2026]:** Die Startbefüllung sind **Push,
///   Pull und Legs**, nicht A–D. Es gibt keine Zeile `A`–`D`.
/// - **Abschnitt 22 Nr. 3 [Tim, 19.11.2026]:** Der Editor sichert
///   automatisch als Entwurf — dort steht auch, was ein Entwurf ist; hier
///   nur, dass `alle()` ihn mit- und ohne ihn liefert.
/// - **Abschnitt 24 Nr. 1:** Löschen nimmt ein Training aus der Rotation
///   (`gym_training_rotation_test.dart`).
/// - **Abschnitt 26 Nr. 1 [Tim, 19.11.2026]:** Templates sind **nicht
///   löschbar**. `loesche` auf eine Template-Kennung wirft `StateError`, wie
///   `speichere`, und ändert nichts. Die Tombstone-Spalte bleibt im Schema;
///   die Wächter „Tombstone kommt nie zurück" bleiben, erzeugen ihren
///   Tombstone aber per SQL — es gibt über das Repository keinen Weg mehr.
///
/// ## Wer hat was entschieden
///
/// - **Entscheidung von Tim:** Ein Template öffnet den Editor nie direkt,
///   Bearbeiten legt eine Kopie unter „Eigene" an und das Template bleibt
///   unverändert (18.11.2026); ein Eigenes wird wirklich gelöscht, ein
///   Tombstone kommt nie zurück (18.11.2026); der Verlauf friert ein
///   (18.11.2026). Template löschen als Tombstone (18.11.) ist durch
///   Abschnitt 26 ersetzt: Templates sind nicht löschbar.
/// - **Folgerung aus Spec und Code:** Gefiltert wird in SQL; `speichere`
///   ersetzt Übungen und Tags vollständig; die Übungen werden in
///   `pos`-Reihenfolge gelesen, nie nach Zeilenfolge; `reihenfolge` eines
///   neuen Eigenen ist die größte vorhandene Zahl der **Eigenen** plus 1;
///   `speichere` auf ein Template wirft `StateError`, Regelverstoß wirft
///   `ArgumentError` (Spec 6.1).
/// - **Vorschlag der Spec, hier vorausgesetzt:** 17.5 (die Kopie entsteht
///   erst beim Speichern — `copyAsOwn` selbst legt nichts ab), 17.6 (Sperre
///   4.7), 17.8 (die Kopie nimmt die eingetragene Dauer mit), Plan 12
///   (Tag „Gym", Dauern 70/70/60 der Templates). **Tim hat diese Fragen
///   nicht beantwortet.**
///
/// ## API, die diese Tests verbindlich vorgeben
///
/// Spec 6.1, **ergänzt um zwei Festlegungen des Test-Agenten**, die die Spec
/// nicht trifft und die Tim nicht gesehen hat:
///
/// ```dart
/// class GymTrainingRepository {
///   GymTrainingRepository(AppCache db);
///   Future<List<WorkoutDefinition>> alle({bool mitEntwuerfen = true});
///   Future<WorkoutDefinition?> training(String id);
///   Future<WorkoutDefinition?> trainingAuchGeloescht(String id);
///   Future<void> speichere(WorkoutDefinition definition);
///   Future<WorkoutDefinition> kopiereAlsEigenes(String vonId,
///       {required String neueId});
///   Future<void> loesche(String id);
///   Future<Map<String, int>> benutzteTags();
///   Future<void> spieleTemplatesEin();
/// }
/// ```
///
/// - **`alle()` liefert dieselben Werte wie `WorkoutTemplates.all`**, wo
///   ein Template unverändert in der Datei steht — also mit den Tags und
///   den eingetragenen Dauern, die der Kern (und die Migrationstests)
///   vorgeben. Die Tests vergleichen mit `==` des Kerns.
/// - **`loesche` eines Eigenen nimmt auch den Zwischenstand mit, der an ihm
///   hängt** (`entwurf_von`). Die Spec sagt dazu nichts; ohne das bliebe
///   eine Geisterkachel „Änderung an X" für ein X, das es nicht mehr gibt.
///   **Festlegung des Test-Agenten.**
///
/// ## Was hier **nicht** getestet wird, weil die Spec es nicht sagt
///
/// - **`speichere` mit einer Übung, die der Katalog nicht kennt.** 6.2 sagt:
///   Die ID bleibt in der Datenbank und in `exercises`. `WorkoutRules.check`
///   meldet dafür `UnknownExercise`, und `speichere` wirft bei Regelverstoß
///   `ArgumentError` — ein Training mit unbekannter Übung ließe sich also
///   lesen, aber nicht erneut speichern. **Gemeldet, nicht entschieden.**
///   Hier wird nur das **Lesen** geprüft.
/// - **Was `speichere` mit `increment != null` schreibt.** Spec 4.1: „Diese
///   Stufe schreibt nie etwas anderes als NULL" — ob sie ein gesetztes
///   `increment` verwirft oder wirft, steht nirgends.
/// - **`kopiereAlsEigenes` mit unbekannter Kennung** und **`speichere`/
///   `loesche` mit leerer Kennung.**
///
/// **Alle Namen, Zahlen und Zeitpunkte sind erfunden** (Jahr 2099).
void main() {
  group('Lesen — die Startbefüllung (Spec 23, 4.3)', () {
    test('`alle()` liefert genau Push, Pull, Legs — die Templates des Kerns, '
        'in dieser Reihenfolge', () async {
      final repo = GymTrainingRepository(neueDb());

      final alle = await repo.alle();

      expect(alle.map((d) => d.id).toList(), ['Push', 'Pull', 'Legs']);
      expect(
        alle,
        WorkoutTemplates.all,
        reason:
            'Name, Tags, Übungen, eingetragene Dauer: Werte der Templates, '
            'als Werte kopiert (Spec 4.3)',
      );
      expect(
        alle.every((d) => d.category == WorkoutCategory.template),
        isTrue,
      );
    });

    test('es gibt kein Gym A bis D', () async {
      final repo = GymTrainingRepository(neueDb());

      for (final code in ['A', 'B', 'C', 'D']) {
        expect(await repo.training(code), isNull, reason: code);
        expect(await repo.trainingAuchGeloescht(code), isNull, reason: code);
      }
    });

    test('`training` liefert das Template, eine unbekannte Kennung null',
        () async {
      final repo = GymTrainingRepository(neueDb());

      expect(await repo.training('Push'), WorkoutTemplates.all[0]);
      expect(await repo.training('Legs'), WorkoutTemplates.all[2]);
      expect(await repo.training('GIBT-ES-NICHT'), isNull);
    });

    test('Templates zuerst, Eigene nach `reihenfolge`, bei Gleichstand nach '
        '`id`', () async {
      final db = neueDb();
      final repo = GymTrainingRepository(db);
      await repo.speichere(eigenes('ZZ-1'));
      await repo.speichere(eigenes('AA-1'));

      expect((await repo.alle()).map((d) => d.id).toList(), [
        'Push',
        'Pull',
        'Legs',
        'ZZ-1',
        'AA-1',
      ], reason: 'erst gespeichert, erst angezeigt');

      await db.customStatement(
        'UPDATE gym_trainings SET reihenfolge = 7 '
        "WHERE id IN ('ZZ-1', 'AA-1');",
      );
      expect((await repo.alle()).map((d) => d.id).toList(), [
        'Push',
        'Pull',
        'Legs',
        'AA-1',
        'ZZ-1',
      ], reason: 'bei gleicher reihenfolge entscheidet die id');
    });

    test('Übungen und Tags werden in `pos`-Reihenfolge gelesen, nie nach '
        'Zeilenfolge', () async {
      final db = neueDb();
      final repo = GymTrainingRepository(db);
      await db.customStatement(
        'INSERT INTO gym_trainings (id, name, kategorie, reihenfolge) '
        "VALUES ('E-1', 'Prüftraining', 'eigene', 1);",
      );
      // Gegen die Zeilenfolge eingefügt: 3, 1, 2.
      for (final (pos, id) in [(3, 'dips'), (1, 'benchPress'), (2, 'pullUp')]) {
        await db.customStatement(
          'INSERT INTO gym_training_uebungen '
          '(training_id, pos, uebung_id, saetze, wdh_von, wdh_bis) '
          "VALUES ('E-1', $pos, '$id', 3, 8, 12);",
        );
      }
      for (final (pos, tag) in [(2, 'Zweiter'), (1, 'Erster')]) {
        await db.customStatement(
          'INSERT INTO gym_training_tags (training_id, pos, tag) '
          "VALUES ('E-1', $pos, '$tag');",
        );
      }

      final gelesen = (await repo.training('E-1'))!;

      expect(gelesen.exercises.map((e) => e.exerciseId).toList(), [
        'benchPress',
        'pullUp',
        'dips',
      ]);
      expect(gelesen.tags, ['Erster', 'Zweiter']);
    });

    test('eine Übung, die der Katalog nicht kennt, bleibt in der Datenbank '
        'und in `exercises` (Spec 6.2)', () async {
      final db = neueDb();
      final repo = GymTrainingRepository(db);
      await db.customStatement(
        'INSERT INTO gym_trainings (id, name, kategorie, reihenfolge) '
        "VALUES ('E-1', 'Prüftraining', 'eigene', 1);",
      );
      await db.customStatement(
        'INSERT INTO gym_training_uebungen '
        '(training_id, pos, uebung_id, saetze, wdh_von, wdh_bis) '
        "VALUES ('E-1', 1, 'benchPress', 3, 8, 12), "
        "('E-1', 2, 'gibtEsNichtMehr', 3, 8, 12);",
      );

      final gelesen = (await repo.training('E-1'))!;

      expect(gelesen.exercises, hasLength(2));
      expect(gelesen.exercises[1].exerciseId, 'gibtEsNichtMehr');
      expect(
        gelesen.exercises[1].resolve(),
        isNull,
        reason: 'erkannt als unbekannt, nicht geraten',
      );
      expect(
        await anzahl(
          db,
          'gym_training_uebungen',
          "uebung_id = 'gibtEsNichtMehr'",
        ),
        1,
        reason: 'Lesen löscht nichts',
      );
    });

    test('`alle(mitEntwuerfen: false)` lässt Entwürfe weg, `alle()` nicht',
        () async {
      final repo = GymTrainingRepository(neueDb());
      await repo.speichere(eigenes('E-1'));
      await repo.speichere(eigenes('E-2', name: 'Halber Stand', isDraft: true));

      expect((await repo.alle()).map((d) => d.id).toList(), [
        'Push',
        'Pull',
        'Legs',
        'E-1',
        'E-2',
      ]);
      expect(
        (await repo.alle(mitEntwuerfen: false)).map((d) => d.id).toList(),
        ['Push', 'Pull', 'Legs', 'E-1'],
      );
    });
  });

  group('speichere (Spec 6.1)', () {
    test('legt ein neues Eigenes an, und Lesen gibt es gleich zurück',
        () async {
      final db = neueDb();
      final repo = GymTrainingRepository(db);
      final training = eigenes(
        'E-1',
        tags: ['Home', 'Zuhause'],
        enteredMinutes: 45,
      );

      await repo.speichere(training);

      expect(await repo.training('E-1'), training);
      final zeile = (await zeilen(db, 'gym_trainings', wo: "id = 'E-1'")).single;
      expect(zeile['kategorie'], 'eigene');
      expect(zeile['ist_entwurf'], 0);
      expect(zeile['geloescht'], 0);
      expect(zeile['dauer_eingetragen_min'], 45);
      expect(zeile['entwurf_von'], isNull);
    });

    test('eine geschätzte Dauer bleibt `NULL`, wird nie 0 (Fehler `01`)',
        () async {
      final db = neueDb();
      final repo = GymTrainingRepository(db);

      await repo.speichere(eigenes('E-1', enteredMinutes: null));

      final zeile = (await zeilen(db, 'gym_trainings', wo: "id = 'E-1'")).single;
      expect(zeile['dauer_eingetragen_min'], isNull);
      expect((await repo.training('E-1'))!.enteredMinutes, isNull);
    });

    test('die Spalte `steigerung` bleibt `NULL` (Platz für #537)', () async {
      final db = neueDb();
      final repo = GymTrainingRepository(db);

      await repo.speichere(eigenes('E-1'));

      final zeilenDerUebungen = await zeilen(
        db,
        'gym_training_uebungen',
        wo: "training_id = 'E-1'",
      );
      expect(zeilenDerUebungen, hasLength(2));
      expect(zeilenDerUebungen.every((z) => z['steigerung'] == null), isTrue);
    });

    test('Speichern derselben Kennung ersetzt Übungen und Tags vollständig',
        () async {
      final db = neueDb();
      final repo = GymTrainingRepository(db);
      await repo.speichere(
        eigenes(
          'E-1',
          name: 'Erster Stand',
          tags: ['Alt', 'Home'],
          exercises: [
            uebung('benchPress'),
            uebung('lateralRaise'),
            uebung('dips'),
          ],
          enteredMinutes: 50,
        ),
      );
      final zweiter = eigenes(
        'E-1',
        name: 'Zweiter Stand',
        tags: ['Home'],
        exercises: [uebung('dips', sets: 5, repLow: 5, repHigh: 8)],
        enteredMinutes: null,
      );

      await repo.speichere(zweiter);

      expect(await repo.training('E-1'), zweiter);
      expect(await zeilenVon(db, 'E-1'), (1, 1, 1));
      expect(
        (await repo.training('E-1'))!.enteredMinutes,
        isNull,
        reason: 'die eigene Zahl zurückgeben heißt: wieder geschätzt',
      );
    });

    test('Positionen tauschen scheitert nicht an `UNIQUE (training_id, pos)` '
        '— es gibt keinen Zwischenzustand mit doppelter Position', () async {
      final db = neueDb();
      final repo = GymTrainingRepository(db);
      await repo.speichere(
        eigenes(
          'E-1',
          tags: ['Eins', 'Zwei'],
          exercises: [uebung('benchPress'), uebung('pullUp')],
        ),
      );
      final getauscht = eigenes(
        'E-1',
        tags: ['Zwei', 'Eins'],
        exercises: [uebung('pullUp'), uebung('benchPress')],
      );

      await repo.speichere(getauscht);

      expect(await repo.training('E-1'), getauscht);
      expect(await uebungenInDatei(db, 'E-1'), ['pullUp', 'benchPress']);
    });

    test('`reihenfolge` eines neuen Eigenen ist die größte Zahl der Eigenen '
        'plus 1 — nicht die Zahl der Templates, nicht die Anzahl', () async {
      final db = neueDb();
      final repo = GymTrainingRepository(db);
      Future<int> reihenfolge(String id) async =>
          (await zeilen(db, 'gym_trainings', wo: "id = '$id'")).single['reihenfolge']!
              as int;

      await repo.speichere(eigenes('E-1'));
      await repo.speichere(eigenes('E-2'));
      await repo.speichere(eigenes('E-3'));

      expect(await reihenfolge('E-1'), 1, reason: 'Templates zählen nicht mit');
      expect(await reihenfolge('E-2'), 2);
      expect(await reihenfolge('E-3'), 3);

      await repo.loesche('E-1');
      await repo.speichere(eigenes('E-4'));
      expect(
        await reihenfolge('E-4'),
        4,
        reason: 'max + 1, nicht Anzahl + 1 (das wären 3, schon vergeben)',
      );
    });

    test('ein bestehendes Eigenes behält seine `reihenfolge` beim erneuten '
        'Speichern', () async {
      final db = neueDb();
      final repo = GymTrainingRepository(db);
      await repo.speichere(eigenes('E-1'));
      await repo.speichere(eigenes('E-2'));

      await repo.speichere(eigenes('E-1', name: 'Umbenannt'));

      final zeile = (await zeilen(db, 'gym_trainings', wo: "id = 'E-1'")).single;
      expect(zeile['reihenfolge'], 1);
      expect((await repo.alle()).map((d) => d.id).toList(), [
        'Push',
        'Pull',
        'Legs',
        'E-1',
        'E-2',
      ]);
    });

    test('`speichere` auf ein Template wirft `StateError` — auch wenn es sich '
        'nur im Namen unterscheidet', () async {
      final db = neueDb();
      final repo = GymTrainingRepository(db);
      final vorher = await abbild(db, 'Push');
      final push = WorkoutTemplates.all[0];

      await expectLater(repo.speichere(push), throwsStateError);
      await expectLater(
        repo.speichere(
          WorkoutDefinition(
            id: push.id,
            name: 'Anders benannt',
            category: WorkoutCategory.template,
            tags: push.tags,
            exercises: push.exercises,
            enteredMinutes: push.enteredMinutes,
          ),
        ),
        throwsStateError,
      );
      await expectLater(
        repo.speichere(
          WorkoutDefinition(
            id: 'NEUES-TEMPLATE',
            name: 'Ein neues Template',
            category: WorkoutCategory.template,
            tags: const [],
            exercises: zweiUebungen(),
          ),
        ),
        throwsStateError,
        reason: 'auch ein neues Template schreibt hier niemand',
      );

      expect(await abbild(db, 'Push'), vorher);
      expect(await repo.training('Push'), push);
      expect(await zeilenVon(db, 'NEUES-TEMPLATE'), (0, 0, 0));
    });

    test('ein Regelverstoß wirft `ArgumentError` und schreibt nichts',
        () async {
      final db = neueDb();
      final repo = GymTrainingRepository(db);
      final vorher = await anzahl(db, 'gym_trainings');
      final faelle = {
        'leerer Name': eigenes('E-1', name: ''),
        'keine Übung': eigenes('E-1', exercises: []),
        'dieselbe Übung zweimal': eigenes(
          'E-1',
          exercises: [uebung('benchPress'), uebung('benchPress', sets: 4)],
        ),
        'sechs Tags': eigenes(
          'E-1',
          tags: ['Eins', 'Zwei', 'Drei', 'Vier', 'Fünf', 'Sechs'],
        ),
        'null Sätze': eigenes('E-1', exercises: [uebung('benchPress', sets: 0)]),
        'Dauer 0': eigenes('E-1', enteredMinutes: 0),
      };

      for (final MapEntry(key: warum, value: training) in faelle.entries) {
        await expectLater(
          repo.speichere(training),
          throwsArgumentError,
          reason: warum,
        );
      }

      expect(await anzahl(db, 'gym_trainings'), vorher);
      expect(await zeilenVon(db, 'E-1'), (0, 0, 0));
    });

    test('ein gescheitertes erneutes Speichern lässt den alten Stand stehen',
        () async {
      final db = neueDb();
      final repo = GymTrainingRepository(db);
      final alt = eigenes('E-1', name: 'Gültiger Stand', tags: ['Home']);
      await repo.speichere(alt);
      final vorher = await abbild(db, 'E-1');

      await expectLater(
        repo.speichere(eigenes('E-1', name: 'Neuer Stand', exercises: [])),
        throwsArgumentError,
      );

      expect(await abbild(db, 'E-1'), vorher);
      expect(await repo.training('E-1'), alt);
    });
  });

  group('Kopie bei Bearbeitung (Spec 4.5)', () {
    test('`kopiereAlsEigenes` legt ein neues Eigenes an und gibt es zurück',
        () async {
      final db = neueDb();
      final repo = GymTrainingRepository(db);

      final kopie = await repo.kopiereAlsEigenes('Push', neueId: 'KOPIE-1');

      expect(kopie.id, 'KOPIE-1');
      expect(kopie.category, WorkoutCategory.own);
      expect(kopie.isDraft, isFalse);
      expect(kopie.name, 'Push (Kopie)');
      expect(kopie.tags, WorkoutTemplates.all[0].tags);
      expect(kopie.exercises, WorkoutTemplates.all[0].exercises);
      expect(
        kopie.enteredMinutes,
        70,
        reason: 'die Kopie nimmt die eingetragene Dauer mit (Vorschlag 17.8)',
      );
      expect(await repo.training('KOPIE-1'), kopie);
      expect(
        (await zeilen(db, 'gym_trainings', wo: "id = 'KOPIE-1'")).single['reihenfolge'],
        1,
        reason: 'das erste Eigene',
      );
    });

    test('das Original bleibt nach der Kopie unverändert', () async {
      final db = neueDb();
      final repo = GymTrainingRepository(db);
      final vorher = await abbild(db, 'Push');

      await repo.kopiereAlsEigenes('Push', neueId: 'KOPIE-1');

      expect(await abbild(db, 'Push'), vorher);
      expect(await repo.training('Push'), WorkoutTemplates.all[0]);
    });

    test('Template bearbeiten heißt: Kopie speichern — das Template ändert '
        'sich nicht, die Kopie trägt die Änderung', () async {
      // Der Weg des Editors (Plan 6): `speichere(copyAsOwn(...))`, erst beim
      // Speichern, nicht beim Öffnen (Vorschlag 17.5).
      final db = neueDb();
      final repo = GymTrainingRepository(db);
      final push = WorkoutTemplates.all[0];
      final vorher = await abbild(db, 'Push');

      final kopie = push.copyAsOwn(id: 'KOPIE-1');
      expect(
        await repo.training('KOPIE-1'),
        isNull,
        reason: 'copyAsOwn allein legt nichts ab — wer das Template öffnet und '
            'ohne Änderung abbricht, hat nichts angelegt',
      );
      final bearbeitet = WorkoutDefinition(
        id: kopie.id,
        name: 'Mein Push',
        category: kopie.category,
        tags: [...kopie.tags, 'Home'],
        exercises: kopie.exercises.sublist(0, 3),
        enteredMinutes: null,
      );
      await repo.speichere(bearbeitet);

      expect(await abbild(db, 'Push'), vorher, reason: 'Original unverändert');
      expect(await repo.training('Push'), push);
      expect(await repo.training('KOPIE-1'), bearbeitet);
      expect((await repo.training('KOPIE-1'))!.exercises, hasLength(3));
      expect(push.exercises, hasLength(7));
    });

    test('Kopieren und Bearbeiten ändern auch ein gelöschtes Template nicht',
        () async {
      final db = neueDb();
      final repo = GymTrainingRepository(db);
      await repo.kopiereAlsEigenes('Pull', neueId: 'KOPIE-1');
      await repo.speichere(eigenes('KOPIE-1', name: 'Mein Pull'));
      await tombstone(db, 'Pull');

      expect(
        await repo.training('KOPIE-1'),
        isNotNull,
        reason: 'die Kopie hängt nicht am Template',
      );
      expect((await repo.training('KOPIE-1'))!.name, 'Mein Pull');
    });
  });

  group('loesche (Spec 4.4)', () {
    test('ein Template ist nicht löschbar: `StateError`, und nichts ändert '
        'sich — weder Zeile noch Übungen noch Tags (Spec 26 Nr. 1)', () async {
      final db = neueDb();
      final repo = GymTrainingRepository(db);
      final vorher = [
        for (final id in ['Push', 'Pull', 'Legs']) await abbild(db, id),
      ];

      for (final id in ['Push', 'Pull', 'Legs']) {
        await expectLater(repo.loesche(id), throwsStateError, reason: id);
      }

      expect([
        for (final id in ['Push', 'Pull', 'Legs']) await abbild(db, id),
      ], vorher);
      expect(
        await anzahl(db, 'gym_trainings', 'geloescht = 1'),
        0,
        reason: 'es entsteht kein Tombstone',
      );
      expect((await repo.alle()).map((d) => d.id).toList(), [
        'Push',
        'Pull',
        'Legs',
      ]);
      expect(await repo.training('Push'), WorkoutTemplates.all[0]);
    });

    test('der Fehler eines Template-Löschens fasst auch die Rotation und die '
        'anderen Trainings nicht an (Spec 26 Nr. 1)', () async {
      final db = neueDb();
      final repo = GymTrainingRepository(db);
      await repo.speichere(eigenes('E-1'));
      final rotationVorher = await rotationInDatei(db);
      final rotationListe = await repo.rotation();
      final eigenesVorher = await abbild(db, 'E-1');

      await expectLater(repo.loesche('Pull'), throwsStateError);

      expect(await rotationInDatei(db), rotationVorher);
      expect(await repo.rotation(), rotationListe);
      expect(rotationListe, ['Push', 'Pull', 'Legs']);
      expect(await abbild(db, 'E-1'), eigenesVorher);
    });

    test('ein Eigenes wird wirklich gelöscht — Zeile, Übungen, Tags', () async {
      final db = neueDb();
      final repo = GymTrainingRepository(db);
      await repo.speichere(eigenes('E-1', tags: ['Home', 'Zuhause']));
      await repo.speichere(eigenes('E-2'));
      final anderes = await abbild(db, 'E-2');

      await repo.loesche('E-1');

      expect(await zeilenVon(db, 'E-1'), (0, 0, 0));
      expect(await repo.training('E-1'), isNull);
      expect(await repo.trainingAuchGeloescht('E-1'), isNull);
      expect((await repo.alle()).map((d) => d.id).toList(), [
        'Push',
        'Pull',
        'Legs',
        'E-2',
      ]);
      expect(await abbild(db, 'E-2'), anderes);
    });

    test('mit dem Eigenen geht auch der Zwischenstand, der an ihm hängt '
        '(Festlegung des Test-Agenten)', () async {
      // Sonst bliebe eine Geisterkachel „Änderung an X" für ein X, das es
      // nicht mehr gibt. Die Spec sagt dazu nichts.
      final db = neueDb();
      final repo = GymTrainingRepository(db);
      await repo.speichere(eigenes('E-1'));
      await db.customStatement(
        'INSERT INTO gym_trainings '
        '(id, name, kategorie, ist_entwurf, reihenfolge, entwurf_von) '
        "VALUES ('ZW-1', 'Änderung', 'eigene', 1, 2, 'E-1');",
      );
      await db.customStatement(
        'INSERT INTO gym_training_uebungen '
        '(training_id, pos, uebung_id, saetze, wdh_von, wdh_bis) '
        "VALUES ('ZW-1', 1, 'dips', 3, 8, 12);",
      );
      await db.customStatement(
        'INSERT INTO gym_training_tags (training_id, pos, tag) '
        "VALUES ('ZW-1', 1, 'Home');",
      );

      await repo.loesche('E-1');

      expect(await zeilenVon(db, 'E-1'), (0, 0, 0));
      expect(await zeilenVon(db, 'ZW-1'), (0, 0, 0));
    });

    test('eine unbekannte Kennung ist kein Fehler und ändert nichts',
        () async {
      final db = neueDb();
      final repo = GymTrainingRepository(db);
      await repo.speichere(eigenes('E-1'));
      final vorher = [
        await anzahl(db, 'gym_trainings'),
        await anzahl(db, 'gym_training_uebungen'),
        await anzahl(db, 'gym_training_tags'),
      ];

      await repo.loesche('GIBT-ES-NICHT');

      expect([
        await anzahl(db, 'gym_trainings'),
        await anzahl(db, 'gym_training_uebungen'),
        await anzahl(db, 'gym_training_tags'),
      ], vorher);
    });

    test('ein Tombstone kommt nie zurück: `spieleTemplatesEin` lässt ihn '
        'liegen (Wächter; der Tombstone entsteht per SQL, Spec 26 Nr. 1)',
        () async {
      final db = neueDb();
      final repo = GymTrainingRepository(db);
      await tombstone(db, 'Pull');
      final vorher = await abbild(db, 'Pull');

      await repo.spieleTemplatesEin();
      await repo.spieleTemplatesEin();

      expect(await abbild(db, 'Pull'), vorher);
      expect(await anzahl(db, 'gym_trainings'), 3, reason: 'nichts doppelt');
      expect((await repo.alle()).map((d) => d.id).toList(), ['Push', 'Legs']);
    });

    test('`benutzteTags` zählt keine Tombstones (per SQL erzeugt, Spec 26 '
        'Nr. 1)', () async {
      final db = neueDb();
      final repo = GymTrainingRepository(db);
      expect(await repo.benutzteTags(), {'Gym': 3});

      await tombstone(db, 'Push');
      expect(await repo.benutzteTags(), {'Gym': 2});

      await tombstone(db, 'Pull');
      await tombstone(db, 'Legs');
      expect(await repo.benutzteTags(), isEmpty);
    });
  });

  group('Sperre bei laufender Erfassung (Spec 4.7)', () {
    test('`speichere` und `loesche` werfen `StateError`, solange die '
        'Erfassung dieses Eigene trägt — und ändern nichts', () async {
      final db = neueDb();
      final repo = GymTrainingRepository(db);
      await repo.speichere(eigenes('E-1', name: 'Läuft gerade'));
      final vorher = await abbild(db, 'E-1');
      await laufendesTraining(db, 'E-1');

      await expectLater(
        repo.speichere(eigenes('E-1', name: 'Anders', exercises: [uebung('dips')])),
        throwsStateError,
      );
      await expectLater(repo.loesche('E-1'), throwsStateError);

      expect(await abbild(db, 'E-1'), vorher);
    });

    test('ein anderes Training ist nicht gesperrt', () async {
      final db = neueDb();
      final repo = GymTrainingRepository(db);
      await repo.speichere(eigenes('E-1'));
      await repo.speichere(eigenes('E-2'));
      await laufendesTraining(db, 'E-1');

      await repo.speichere(eigenes('E-2', name: 'Frei'));
      await repo.loesche('E-2');

      expect(await repo.training('E-2'), isNull);
    });

    test('mit dem Verwerfen der Erfassung ist die Sperre weg', () async {
      final db = neueDb();
      final repo = GymTrainingRepository(db);
      await repo.speichere(eigenes('E-1'));
      await laufendesTraining(db, 'E-1');
      await expectLater(repo.loesche('E-1'), throwsStateError);

      await GymRepository(db).verwirfEntwurf();
      await repo.speichere(eigenes('E-1', name: 'Jetzt frei'));
      await repo.loesche('E-1');

      expect(await repo.training('E-1'), isNull);
    });
  });

  group('benutzteTags (Spec 6.1)', () {
    test('zählt die Tags lebender Trainings und Entwürfe, nicht die '
        'Tombstones', () async {
      final db = neueDb();
      final repo = GymTrainingRepository(db);
      await repo.speichere(eigenes('E-1', tags: ['Gym', 'Home']));
      await repo.speichere(eigenes('E-2', tags: ['Home']));
      await repo.speichere(
        eigenes('E-3', tags: ['Home', 'Draußen'], isDraft: true),
      );

      expect(await repo.benutzteTags(), {'Gym': 4, 'Home': 3, 'Draußen': 1});

      await tombstone(db, 'Push');
      expect((await repo.benutzteTags())['Gym'], 3);
    });

    test('ein gelöschtes Eigenes zählt nicht mehr', () async {
      final repo = GymTrainingRepository(neueDb());
      await repo.speichere(eigenes('E-1', tags: ['Einzelgänger']));
      expect((await repo.benutzteTags())['Einzelgänger'], 1);

      await repo.loesche('E-1');

      expect(await repo.benutzteTags(), {'Gym': 3});
    });
  });

  group('spieleTemplatesEin (Spec 4.3)', () {
    test('zweimal gerufen ist dasselbe wie einmal', () async {
      final db = neueDb();
      final repo = GymTrainingRepository(db);
      final vorher = [
        for (final id in ['Push', 'Pull', 'Legs']) await abbild(db, id),
      ];

      await repo.spieleTemplatesEin();
      await repo.spieleTemplatesEin();

      expect([
        for (final id in ['Push', 'Pull', 'Legs']) await abbild(db, id),
      ], vorher);
      expect(await anzahl(db, 'gym_trainings'), 3);
    });

    test('fasst eine vorhandene Zeile nie an — nicht Name, nicht Dauer, nicht '
        'Übungen', () async {
      final db = neueDb();
      final repo = GymTrainingRepository(db);
      await db.customStatement(
        'UPDATE gym_trainings SET name = \'Prüfname Push\', '
        "dauer_eingetragen_min = NULL WHERE id = 'Push';",
      );
      await db.customStatement(
        "DELETE FROM gym_training_uebungen WHERE training_id = 'Push' "
        'AND pos > 2;',
      );
      final vorher = await abbild(db, 'Push');

      await repo.spieleTemplatesEin();

      expect(await abbild(db, 'Push'), vorher);
      expect(await zeilenVon(db, 'Push'), (1, 2, 1));
    });

    test('ein eigenes Training bleibt unberührt, und ein fehlendes Template '
        'kommt wieder — samt Übungen und Tags', () async {
      final db = neueDb();
      final repo = GymTrainingRepository(db);
      await repo.speichere(eigenes('E-1'));
      final eigenesVorher = await abbild(db, 'E-1');
      for (final tabelle in [
        'gym_trainings WHERE id',
        'gym_training_uebungen WHERE training_id',
        'gym_training_tags WHERE training_id',
      ]) {
        await db.customStatement("DELETE FROM $tabelle = 'Legs';");
      }
      expect(await zeilenVon(db, 'Legs'), (0, 0, 0), reason: 'Vorbedingung');

      await repo.spieleTemplatesEin();

      expect(await repo.training('Legs'), WorkoutTemplates.all[2]);
      expect(await abbild(db, 'E-1'), eigenesVorher);
      expect(await anzahl(db, 'gym_trainings'), 4);
    });

    test('eine Zeile `A` bis `D` entsteht nie', () async {
      final db = neueDb();
      final repo = GymTrainingRepository(db);

      await repo.spieleTemplatesEin();

      expect(
        await anzahl(db, 'gym_trainings', "id IN ('A', 'B', 'C', 'D')"),
        0,
      );
    });
  });
}

/// Ein Template-Tombstone, von Hand erzeugt: Seit Spec 26 Nr. 1 gibt es über
/// das Repository keinen Weg mehr, einen anzulegen — die Spalte und die
/// Wächter gegen sein Wiederkommen bleiben.
Future<void> tombstone(AppCache db, String id) => db.customStatement(
  "UPDATE gym_trainings SET geloescht = 1 WHERE id = '$id';",
);
