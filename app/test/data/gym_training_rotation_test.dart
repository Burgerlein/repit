import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show sqlite3;

import 'package:repit/data/gym_training_repository.dart';

import 'gym_training_support.dart';

/// Tests für die **gespeicherte Rotation** im Repository: `rotation()`, das
/// Herausnehmen beim Löschen und die Neustarts (Merker, Tombstones) — der
/// vorgezogene Datenteil von #536 (#532, unter #531). Task 1.6 des Plans
/// `docs/superpowers/plans/2026-11-19-eigene-trainings-plan.md`.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden. Hält der
/// Implementierende eine Erwartung für falsch, wird das **gemeldet, nicht
/// korrigiert**.
///
/// ## Was die Nachträge bewachen
///
/// - **Abschnitt 23 [Tim, 19.11.2026]:** Die Rotation ist startbefüllt mit
///   Push, Pull, Legs, in dieser Reihenfolge, ohne Wochentage.
/// - **Abschnitt 24 Nr. 1:** Löschen eines Trainings **nimmt es aus der
///   Rotation**, in derselben Transaktion; die Plätze rücken ohne Lücke
///   nach; ein nicht eingeplantes Training lässt die Rotation unberührt.
///   Gruppe „Löschen nimmt aus der Rotation".
/// - **Abschnitt 24 Nr. 3:** Eingespielt wird **mit Merker**, nicht „wenn
///   leer" — Löschen kann die Rotation leeren, und die Einspielung darf sie
///   nicht wiederbeleben. Gruppe „Neustart: der Merker".
/// - **Abschnitt 25 Nr. 3 (Festlegungen aus der Testphase):** **Die
///   Einspielung ergänzt nichts** — trifft sie auf eine vorhandene Rotation
///   ohne Merker, setzt sie nur den Merker. **Und ein Template mit
///   Tombstone kommt nie in die Rotation**, auf keinem Weg. Gruppe
///   „Einspielung ergänzt nichts, Tombstones nie".
/// - **Abschnitt 14.1:** Entwürfe und Tombstones sind nicht einplanbar;
///   `rotation()` lässt sie weg.
/// - **Abschnitt 26 Nr. 1 [Tim, 19.11.2026]:** Templates sind nicht
///   löschbar, die Rotation fällt über das Repository nie unter die drei
///   Start-Plätze, solange kein Eigenes darin steht. Wo ein Fall eine
///   kleinere Rotation braucht, baut er sie **von Hand** (`setzeRotation`,
///   SQL) oder löscht ein **Eigenes**, das er zuvor per SQL einplant.
///   Tombstones entstehen nur noch per SQL.
///
/// ## Wer hat was entschieden
///
/// - **Entscheidung von Tim:** Push/Pull/Legs als Start-Templates und als
///   Start-Rotation (19.11.2026, Spec 23); ein Template-Tombstone kommt nie
///   zurück (18.11.2026).
/// - **Folgerung (Spec 24, 25):** alles Übrige oben — Folgerungen des
///   Koordinators, **keine** neuen Entscheidungen von Tim.
/// - **Festlegung des Test-Agenten:** `Future<List<String>> rotation()`
///   liefert die Kennungen in der Reihenfolge der Plätze.
///
/// ## API, die diese Tests verbindlich vorgeben
///
/// ```dart
/// class GymTrainingRepository {
///   /// Die Kennungen der Rotation nach Platz; ohne Entwürfe, ohne
///   /// Tombstones (Spec 14.1).
///   Future<List<String>> rotation();
/// }
/// ```
///
/// **Die Datei der Rotation ist `gym_rotation (pos, training_id)`**, wie
/// `schema_v25_test.dart` sie fixiert. Wo der Merker liegt, legt diese Datei
/// nicht fest (die Migrationstests nehmen keine fünfte Tabelle an); sie
/// prüft nur sein **Verhalten** über Neustarts.
///
/// ## Was hier **nicht** getestet wird, weil die Spec es nicht sagt
///
/// - **Eine Rotationskennung ohne jede Zeile in `gym_trainings`:** ob
///   `rotation()` sie durchreicht (damit der Provider sie sehen und nach
///   24 Nr. 4 werfen kann) oder selbst wirft, steht nicht fest.
/// - **Eine vorhandene Rotation ohne Merker, wenn die Tabelle leer ist.**
///   25 Nr. 3 sagt „vorhandene Rotation"; ob eine leere Tabelle ohne Merker
///   eine ist, bleibt offen.
/// - **Das Einplanen** (kein Schreiber außer der Einspielung, Spec 24 Nr. 1).
///
/// **Alle Namen, Zahlen und Zeitpunkte sind erfunden** (Jahr 2099).
void main() {
  group('rotation() (Spec 14.1, 23)', () {
    test('eine frische Installation: Push, Pull, Legs, in dieser Reihenfolge',
        () async {
      final db = neueDb();

      expect(await GymTrainingRepository(db).rotation(), [
        'Push',
        'Pull',
        'Legs',
      ]);
      expect(await rotationInDatei(db), [(1, 'Push'), (2, 'Pull'), (3, 'Legs')]);
    });

    test('die Reihenfolge ist die der Plätze, nie die der Zeilen', () async {
      final db = neueDb();
      await db.customStatement('DELETE FROM gym_rotation;');
      await db.customStatement(
        'INSERT INTO gym_rotation (pos, training_id) '
        "VALUES (3, 'Legs'), (1, 'Push'), (2, 'Pull');",
      );

      expect(await GymTrainingRepository(db).rotation(), [
        'Push',
        'Pull',
        'Legs',
      ]);
    });

    test('ein Entwurf ist nie in der Rotation, auch wenn sein Platz belegt '
        'ist', () async {
      final db = neueDb();
      final repo = GymTrainingRepository(db);
      await repo.speichere(eigenes('ENTWURF-1', isDraft: true));
      await setzeRotation(db, ['Push', 'ENTWURF-1', 'Pull', 'Legs']);

      expect(await repo.rotation(), ['Push', 'Pull', 'Legs']);
    });

    test('ein Tombstone ist nie in der Rotation, auch wenn sein Platz belegt '
        'ist', () async {
      final db = neueDb();
      final repo = GymTrainingRepository(db);
      await db.customStatement(
        "UPDATE gym_trainings SET geloescht = 1 WHERE id = 'Pull';",
      );

      expect(await repo.rotation(), ['Push', 'Legs']);
    });

    test('Speichern legt nichts in die Rotation — es gibt keinen Schreiber '
        'außer der Einspielung', () async {
      final db = neueDb();
      final repo = GymTrainingRepository(db);

      await repo.speichere(eigenes('E-1'));
      await repo.speichere(eigenes('ENTWURF-1', isDraft: true));
      await repo.kopiereAlsEigenes('Push', neueId: 'KOPIE-1');

      expect(await repo.rotation(), ['Push', 'Pull', 'Legs']);
      expect(await rotationInDatei(db), [(1, 'Push'), (2, 'Pull'), (3, 'Legs')]);
    });
  });

  group('Löschen nimmt aus der Rotation (Spec 24 Nr. 1, Plan 17)', () {
    test('ein eingeplantes Eigenes verschwindet, und die anderen bleiben',
        () async {
      final db = neueDb();
      final repo = GymTrainingRepository(db);
      await repo.speichere(eigenes('E-1'));
      await setzeRotation(db, ['Push', 'Pull', 'Legs', 'E-1']);

      await repo.loesche('E-1');

      expect(await repo.rotation(), ['Push', 'Pull', 'Legs']);
      expect(await rotationInDatei(db), [(1, 'Push'), (2, 'Pull'), (3, 'Legs')]);
      expect(await zeilenVon(db, 'E-1'), (0, 0, 0));
    });

    test('ein Template ist nicht löschbar: `StateError`, und die Rotation '
        'bleibt, wie sie war (Spec 26 Nr. 1)', () async {
      final db = neueDb();
      final repo = GymTrainingRepository(db);

      await expectLater(repo.loesche('Pull'), throwsStateError);

      expect(await repo.rotation(), ['Push', 'Pull', 'Legs']);
      expect(
        await rotationInDatei(db),
        [(1, 'Push'), (2, 'Pull'), (3, 'Legs')],
        reason: 'Plätze 1 bis 3, nichts herausgenommen',
      );
      expect(
        (await zeilen(db, 'gym_trainings', wo: "id = 'Pull'")).single['geloescht'],
        0,
        reason: 'kein Tombstone',
      );
    });

    test('das erste Eigene in der Rotation: der Rest rückt nach vorn',
        () async {
      final db = neueDb();
      final repo = GymTrainingRepository(db);
      await repo.speichere(eigenes('E-1'));
      await setzeRotation(db, ['E-1', 'Push', 'Pull', 'Legs']);

      await repo.loesche('E-1');

      expect(await rotationInDatei(db), [(1, 'Push'), (2, 'Pull'), (3, 'Legs')]);
    });

    test('das letzte Eigene in der Rotation: die Plätze davor bleiben, wie '
        'sie waren', () async {
      final db = neueDb();
      final repo = GymTrainingRepository(db);
      await repo.speichere(eigenes('E-1'));
      await setzeRotation(db, ['Push', 'Pull', 'Legs', 'E-1']);

      await repo.loesche('E-1');

      expect(await rotationInDatei(db), [(1, 'Push'), (2, 'Pull'), (3, 'Legs')]);
    });

    test('ein Eigenes in der Mitte: Plätze davor bleiben, dahinter rücken '
        'nach, ohne Lücke', () async {
      final db = neueDb();
      final repo = GymTrainingRepository(db);
      await repo.speichere(eigenes('E-1'));
      await setzeRotation(db, ['Push', 'E-1', 'Pull', 'Legs']);

      await repo.loesche('E-1');

      expect(await rotationInDatei(db), [(1, 'Push'), (2, 'Pull'), (3, 'Legs')]);
    });

    test('mehrere Eigene nacheinander: am Ende ist die Rotation leer, ohne '
        'dass etwas wirft', () async {
      final db = neueDb();
      final repo = GymTrainingRepository(db);
      for (final id in ['E-1', 'E-2', 'E-3']) {
        await repo.speichere(eigenes(id));
      }
      await setzeRotation(db, ['E-2', 'E-1', 'E-3']);

      await repo.loesche('E-1');
      await repo.loesche('E-3');
      await repo.loesche('E-2');

      expect(await repo.rotation(), isEmpty);
      expect(await rotationInDatei(db), isEmpty);
      expect(
        (await repo.alle()).map((d) => d.id).toList(),
        ['Push', 'Pull', 'Legs'],
        reason: 'die Templates leben, nur die Rotation ist leer',
      );
    });

    test('ein Training, das nicht eingeplant ist, lässt die Rotation '
        'unberührt', () async {
      final db = neueDb();
      final repo = GymTrainingRepository(db);
      await repo.speichere(eigenes('E-1'));
      await repo.speichere(eigenes('E-2'));
      await setzeRotation(db, ['Pull', 'E-2', 'Push']);
      final vorher = await rotationInDatei(db);

      await repo.loesche('E-1');

      expect(await rotationInDatei(db), vorher, reason: 'Plätze und Kennungen');
    });

    test('ein Entwurf wird nie aus der Rotation gelöscht, weil er nie darin '
        'steht: Verwerfen der Zeile lässt sie unberührt', () async {
      final db = neueDb();
      final repo = GymTrainingRepository(db);
      await repo.speichere(eigenes('ENTWURF-1', isDraft: true));
      final vorher = await rotationInDatei(db);

      await repo.loesche('ENTWURF-1');

      expect(await rotationInDatei(db), vorher);
      expect(await zeilenVon(db, 'ENTWURF-1'), (0, 0, 0));
    });

    test('scheitert das Löschen an der Sperre, bleibt auch die Rotation, '
        'wie sie war — es gibt keinen halben Zustand', () async {
      final db = neueDb();
      final repo = GymTrainingRepository(db);
      await repo.speichere(eigenes('E-1'));
      await setzeRotation(db, ['Push', 'E-1', 'Pull', 'Legs']);
      await laufendesTraining(db, 'E-1');
      final vorher = await rotationInDatei(db);

      await expectLater(repo.loesche('E-1'), throwsStateError);

      expect(await rotationInDatei(db), vorher);
      expect(await zeilenVon(db, 'E-1'), (1, 2, 1));
    });
  });

  group('Neustart: der Merker (Spec 24 Nr. 3)', () {
    test('eine durch Löschen geleerte Rotation wird beim nächsten Start nicht '
        'wieder befüllt', () async {
      final roh = sqlite3.openInMemory();
      addTearDown(roh.close);

      final erstes = await oeffne(roh);
      final repo = GymTrainingRepository(erstes);
      await repo.speichere(eigenes('E-1'));
      await setzeRotation(erstes, ['E-1']);
      await repo.loesche('E-1');
      expect(await repo.rotation(), isEmpty, reason: 'Vorbedingung');
      await erstes.close();

      final zweites = await oeffne(roh);
      addTearDown(zweites.close);
      final danach = GymTrainingRepository(zweites);

      expect(
        await danach.rotation(),
        isEmpty,
        reason:
            'Löschen kann die Rotation leeren. „Füllen, wenn leer" erweckte '
            'Gelöschtes beim nächsten Start wieder — Spec 24 Nr. 3',
      );
      expect(
        (await danach.alle()).map((d) => d.id).toList(),
        ['Push', 'Pull', 'Legs'],
        reason: 'die Templates leben, nur die Rotation ist leer',
      );
      expect(await anzahl(zweites, 'gym_trainings'), 3);
    });

    test('eine geleerte Rotation, bei der alle Templates leben, wird nicht '
        'wieder befüllt — nur der Merker verhindert es', () async {
      // Der Einplan-Schirm (#536) leert die Rotation, ohne ein Training zu
      // löschen — hier von Hand nachgestellt, wie `schema_v25_test.dart`.
      // Der Fall davor zeigt dasselbe über das Löschen eines Eigenen.
      final roh = sqlite3.openInMemory();
      addTearDown(roh.close);
      final erstes = await oeffne(roh);
      await erstes.customStatement('DELETE FROM gym_rotation;');
      await erstes.close();

      final zweites = await oeffne(roh);
      addTearDown(zweites.close);

      expect(await GymTrainingRepository(zweites).rotation(), isEmpty);
      expect(await rotationInDatei(zweites), isEmpty);
      expect(
        await anzahl(zweites, 'gym_trainings', 'geloescht = 0'),
        3,
        reason: 'die Templates leben — es fehlt allein der Merker-Grund',
      );
    });

    test('ein Template mit Tombstone bleibt nach dem Neustart draußen — in der '
        'Liste und in der Rotation (Wächter; Tombstone per SQL, Spec 26 Nr. 1)',
        () async {
      final roh = sqlite3.openInMemory();
      addTearDown(roh.close);

      final erstes = await oeffne(roh);
      await erstes.customStatement(
        "UPDATE gym_trainings SET geloescht = 1 WHERE id = 'Pull';",
      );
      await setzeRotation(erstes, ['Push', 'Legs']);
      await erstes.close();
      final zweites = await oeffne(roh);
      await zweites.close();
      final drittes = await oeffne(roh);
      addTearDown(drittes.close);
      final repo = GymTrainingRepository(drittes);

      expect(await repo.rotation(), ['Push', 'Legs']);
      expect((await repo.alle()).map((d) => d.id).toList(), ['Push', 'Legs']);
      expect(await repo.trainingAuchGeloescht('Pull'), isNotNull);
      expect(await anzahl(drittes, 'gym_trainings'), 3);
      expect(await rotationInDatei(drittes), [(1, 'Push'), (2, 'Legs')]);
    });

    test('eine verkleinerte Rotation wird nicht wieder ergänzt, auch nach '
        'mehreren Starts', () async {
      final roh = sqlite3.openInMemory();
      addTearDown(roh.close);

      final erstes = await oeffne(roh);
      await setzeRotation(erstes, ['Pull', 'Legs']);
      await erstes.close();
      for (var i = 0; i < 3; i++) {
        final db = await oeffne(roh);
        await db.close();
      }
      final letztes = await oeffne(roh);
      addTearDown(letztes.close);

      expect(await GymTrainingRepository(letztes).rotation(), ['Pull', 'Legs']);
    });

    test('ein Eigenes, das jemand hineingelegt hat, bleibt über den Neustart',
        () async {
      final roh = sqlite3.openInMemory();
      addTearDown(roh.close);
      final erstes = await oeffne(roh);
      await GymTrainingRepository(erstes).speichere(eigenes('E-1'));
      await setzeRotation(erstes, ['E-1', 'Push', 'Pull', 'Legs']);
      await erstes.close();

      final zweites = await oeffne(roh);
      addTearDown(zweites.close);

      expect(await GymTrainingRepository(zweites).rotation(), [
        'E-1',
        'Push',
        'Pull',
        'Legs',
      ]);
    });
  });

  group('Einspielung ergänzt nichts, Tombstones nie (Spec 25 Nr. 3)', () {
    test('ein Gerät mit einer Rotation, aber ohne Merker: die Einspielung '
        'ergänzt nichts und fasst die Zeile nicht an', () async {
      // Die vier Tabellen stehen schon (ein anderer Zweig hat sie angelegt),
      // die Rotation trägt nur `Legs`, und Pull ist ein Tombstone. Ein
      // `user_version` unter 25 lässt die Stufe laufen; fehlende Tabellen der
      // Altdatei legt der Abgleich an (siehe `schema_v25_test.dart`,
      // „eine Datei auf 24, der `gym_sitzungen` ganz fehlt").
      final roh = sqlite3.openInMemory()
        ..execute(ddlSitzungenV24)
        ..execute(ddlTrainings)
        ..execute(ddlRotation)
        ..execute('''
          INSERT INTO gym_trainings
            (id, name, kategorie, dauer_eingetragen_min, ist_entwurf,
             geloescht, reihenfolge)
            VALUES ('Push', 'Prüfname Push', 'template', 70, 0, 0, 1);
          INSERT INTO gym_trainings
            (id, name, kategorie, dauer_eingetragen_min, ist_entwurf,
             geloescht, reihenfolge)
            VALUES ('Pull', 'Prüfname Pull', 'template', 70, 0, 1, 2);
          INSERT INTO gym_trainings
            (id, name, kategorie, dauer_eingetragen_min, ist_entwurf,
             geloescht, reihenfolge)
            VALUES ('Legs', 'Prüfname Legs', 'template', 60, 0, 0, 3);
          INSERT INTO gym_rotation (pos, training_id) VALUES (1, 'Legs');
          PRAGMA user_version = 24;
        ''');
      addTearDown(roh.close);

      final db = await oeffne(roh);
      addTearDown(db.close);

      expect(
        await rotationInDatei(db),
        [(1, 'Legs')],
        reason:
            'die Einspielung ergänzt nichts: weder Push noch den Tombstone '
            'Pull; sie setzt nur den Merker (25 Nr. 3)',
      );
      expect(await GymTrainingRepository(db).rotation(), ['Legs']);
    });

    test('ohne vorhandene Rotation: ein Template mit Tombstone kommt nie '
        'hinein', () async {
      // Pull trägt einen Tombstone, Push und Legs fehlen ganz und kommen
      // über `spieleTemplatesEin`. Die Rotationstabelle fehlt (legt der
      // Abgleich an) — die Einspielung füllt sie, **ohne** den Tombstone.
      final roh = sqlite3.openInMemory()
        ..execute(ddlSitzungenV24)
        ..execute(ddlTrainings)
        ..execute('''
          INSERT INTO gym_trainings
            (id, name, kategorie, dauer_eingetragen_min, ist_entwurf,
             geloescht, reihenfolge)
            VALUES ('Pull', 'Prüfname Pull', 'template', 70, 0, 1, 2);
          PRAGMA user_version = 24;
        ''');
      addTearDown(roh.close);

      final db = await oeffne(roh);
      addTearDown(db.close);
      final repo = GymTrainingRepository(db);

      expect(
        await repo.rotation(),
        ['Push', 'Legs'],
        reason:
            'Gelöschtes wird nicht wiederbelebt, auf keinem Weg (25 Nr. 3); '
            'die Reihenfolge der Startbefüllung bleibt',
      );
      expect(
        await rotationInDatei(db),
        [(1, 'Push'), (2, 'Legs')],
        reason: 'ohne Lücke',
      );
      expect(
        (await zeilen(db, 'gym_trainings', wo: "id = 'Pull'")).single['geloescht'],
        1,
        reason: 'der Tombstone bleibt, wie er war',
      );
      expect((await repo.alle()).map((d) => d.id).toList(), ['Push', 'Legs']);
    });

    test('derselbe Fall, zweimal geöffnet: nichts ändert sich mehr', () async {
      final roh = sqlite3.openInMemory()
        ..execute(ddlSitzungenV24)
        ..execute(ddlTrainings)
        ..execute('''
          INSERT INTO gym_trainings
            (id, name, kategorie, dauer_eingetragen_min, ist_entwurf,
             geloescht, reihenfolge)
            VALUES ('Pull', 'Prüfname Pull', 'template', 70, 0, 1, 2);
          PRAGMA user_version = 24;
        ''');
      addTearDown(roh.close);
      await (await oeffne(roh)).close();

      final db = await oeffne(roh);
      addTearDown(db.close);

      expect(await rotationInDatei(db), [(1, 'Push'), (2, 'Legs')]);
      expect(await anzahl(db, 'gym_trainings'), 3);
    });
  });
}
