import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show sqlite3;
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/gym_training_repository.dart';

import 'gym_training_support.dart';

/// Tests für die **Entwurfsmechanik der Ablage**: der Editor sichert seinen
/// Stand automatisch als Entwurf, auch an einem bestehenden Training
/// (`entwurf_von`), und der Zwischenstand ersetzt das Training erst beim
/// Speichern (#532, unter #531; Editor selbst: #534). Task 1.6 des Plans
/// `docs/superpowers/plans/2026-11-19-eigene-trainings-plan.md`.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden. Hält der
/// Implementierende eine Erwartung für falsch, wird das **gemeldet, nicht
/// korrigiert**.
///
/// ## Was die Nachträge bewachen
///
/// - **Abschnitt 22 Nr. 3 [Tim, 19.11.2026]:** Der Editor sichert
///   automatisch als Entwurf; „Abbrechen → Verwerfen" löscht **auch** den
///   gesicherten Stand; **bei einem bestehenden Training hängt der
///   Zwischenstand am Training und ersetzt es erst beim Speichern**;
///   ein Entwurf darf unfertig sein und einen vergebenen Namen tragen.
///   Das schlägt 9.6, 17.14 und 17.15 der Spec. Gruppen „Frei stehender
///   Entwurf" und „Zwischenstand an bestehendem Training".
/// - **Plan 1 (Vorschlag, nicht entschieden — die Spaltenform hat der
///   Migrations-Test-Agent in `schema_v25_test.dart` festgelegt):**
///   `gym_trainings.entwurf_von TEXT NULL`, `UNIQUE (entwurf_von)` — je
///   Training höchstens ein Zwischenstand.
/// - **Plan 4:** Ein Zwischenstand, der wieder dem Ausgang gleicht, wird vom
///   Editor gelöscht — das ist Sache des Editors (Task 3.3), nicht dieser
///   Datei; hier steht nur, dass sich ein Zwischenstand verwerfen lässt.
///
/// ## Wer hat was entschieden
///
/// - **Entscheidung von Tim:** Selbstsicherung, Verwerfen löscht auch den
///   gesicherten Stand, der Zwischenstand ersetzt das Training erst beim
///   Speichern (19.11.2026, Spec 22 Nr. 3); ein leerer Editor wird nie zum
///   Entwurf (Editor-Sache); ein Entwurf ist weder startbar noch einplanbar
///   (19.11.2026).
/// - **Folgerung:** Ein Entwurf ist eine Zeile mit `ist_entwurf = 1`,
///   `kategorie = 'eigene'` (CHECK in der Datei); `alle()` liefert ihn,
///   `alle(mitEntwuerfen: false)` nicht; `benutzteTags` zählt ihn.
/// - **Festlegung des Test-Agenten — die Spec legt für den Zwischenstand
///   keine Methoden fest, der Plan (Task 3.4) nur „Zwischenstand je
///   Training, Verwerfen, Übernehmen beim Speichern" ohne Namen. Tim hat
///   diese Namen nicht gesehen:**
///
/// ```dart
/// class GymTrainingRepository {
///   /// Sichert [stand] als Zwischenstand an dem bestehenden Training
///   /// [von]: Zeile mit ist_entwurf = 1, entwurf_von = [von]. [stand.id]
///   /// ist die Kennung der Entwurfszeile, **nicht** [von]. Das Training
///   /// [von] ändert sich nicht. Ein zweiter Zwischenstand für dasselbe
///   /// [von] **ersetzt** den ersten samt dessen Übungen und Tags.
///   Future<void> speichereZwischenstand(WorkoutDefinition stand,
///       {required String von});
///
///   /// Der Zwischenstand, der an [trainingId] hängt, oder null.
///   Future<WorkoutDefinition?> zwischenstandVon(String trainingId);
///
///   /// Verwirft einen Entwurf oder Zwischenstand: Zeile, Übungen, Tags.
///   /// Unbekannt: nichts. Ein fertiges Training oder Template wird nie
///   /// gelöscht (wirft oder tut nichts — beides erlaubt).
///   Future<void> verwirfEntwurf(String id);
///
///   /// „Speichern" bei `bearbeite`: Der Inhalt des Zwischenstands
///   /// [entwurfId] ersetzt das Training, an dem er hängt, **vollständig**
///   /// (Name, Tags, Übungen, eingetragene Dauer); das Training behält
///   /// Kennung und `reihenfolge` und ist danach fertig (kein Entwurf); die
///   /// Entwurfszeile samt Übungen und Tags ist weg — alles in einer
///   /// Transaktion. Wirft ArgumentError bei Regelverstoß des **fertigen**
///   /// Standes (nichts ändert sich), StateError bei Sperre (4.7).
///   Future<void> uebernimmZwischenstand(String entwurfId);
/// }
/// ```
///
/// **Ein frei stehender Entwurf** (Quelle `neu`, `kopie`, `entwurf`) braucht
/// keine neue Methode: `speichere` mit `isDraft: true`. Die Prüfung gilt
/// dort nur der Gestalt (`WorkoutRules`: kein `NameEmpty`, kein
/// `NoExercises`).
///
/// ## Was hier **nicht** getestet wird, weil die Spec es nicht sagt
///
/// - **`speichereZwischenstand` mit einem Template oder einer unbekannten
///   Kennung als `von`.** Spec 4.5: Ein Template öffnet den Editor nie
///   direkt; ob das Repository es verweigert, steht nirgends.
/// - **`uebernimmZwischenstand` eines frei stehenden Entwurfs** — das ist
///   `speichere` ohne `isDraft` (Gruppe „Frei stehender Entwurf").
/// - **Was die Übersicht anzeigt** (Plan 3: eigene Entwurfs-Kachel) und das
///   **Löschen bei Gleichstand** (Plan 4) — Provider und Editor.
///
/// **Alle Namen, Zahlen und Zeitpunkte sind erfunden** (Jahr 2099).
void main() {
  group('Frei stehender Entwurf (Spec 22 Nr. 3)', () {
    test('ein unfertiger Entwurf darf gesichert werden: kein Name, keine '
        'Übung', () async {
      final db = neueDb();
      final repo = GymTrainingRepository(db);
      final leer = eigenes(
        'D-1',
        name: '',
        tags: [],
        exercises: [],
        isDraft: true,
      );

      await repo.speichere(leer);

      expect(await repo.training('D-1'), leer);
      final zeile = (await zeilen(db, 'gym_trainings', wo: "id = 'D-1'")).single;
      expect(zeile['ist_entwurf'], 1);
      expect(zeile['kategorie'], 'eigene');
      expect(zeile['entwurf_von'], isNull);
      expect(zeile['geloescht'], 0);
    });

    test('`alle()` liefert ihn, `alle(mitEntwuerfen: false)` nicht, und er '
        'zählt in den benutzten Tags', () async {
      final repo = GymTrainingRepository(neueDb());
      await repo.speichere(eigenes('E-1', tags: ['Home']));
      await repo.speichere(
        eigenes('D-1', name: 'Halb fertig', tags: ['Entwurfstag'], isDraft: true),
      );

      expect((await repo.alle()).map((d) => d.id), contains('D-1'));
      expect(
        (await repo.alle(mitEntwuerfen: false)).map((d) => d.id),
        isNot(contains('D-1')),
      );
      expect((await repo.alle()).firstWhere((d) => d.id == 'D-1').isDraft, isTrue);
      expect((await repo.benutzteTags())['Entwurfstag'], 1);
    });

    test('wiederholtes Sichern derselben Kennung ersetzt den Stand — eine '
        'Zeile, keine Reste', () async {
      final db = neueDb();
      final repo = GymTrainingRepository(db);
      await repo.speichere(
        eigenes(
          'D-1',
          name: 'Anfang',
          tags: ['Eins', 'Zwei'],
          exercises: [uebung('benchPress'), uebung('pullUp'), uebung('dips')],
          isDraft: true,
        ),
      );
      final spaeter = eigenes(
        'D-1',
        name: 'Später',
        tags: ['Zwei'],
        exercises: [uebung('pullUp')],
        isDraft: true,
      );

      await repo.speichere(spaeter);

      expect(await repo.training('D-1'), spaeter);
      expect(await zeilenVon(db, 'D-1'), (1, 1, 1));
    });

    test('ein Entwurf darf einen Namen tragen, der schon vergeben ist',
        () async {
      final repo = GymTrainingRepository(neueDb());
      await repo.speichere(eigenes('E-1', name: 'Oberkörper zuhause'));

      await repo.speichere(
        eigenes('D-1', name: 'Oberkörper zuhause', isDraft: true),
      );

      expect(
        (await repo.alle()).where((d) => d.name == 'Oberkörper zuhause'),
        hasLength(2),
      );
    });

    test('Verwerfen löscht Zeile, Übungen und Tags des gesicherten Stands, '
        'und sonst nichts', () async {
      final db = neueDb();
      final repo = GymTrainingRepository(db);
      await repo.speichere(eigenes('E-1'));
      await repo.speichere(
        eigenes('D-1', tags: ['Eins', 'Zwei'], isDraft: true),
      );
      final anderes = await abbild(db, 'E-1');
      final rotationVorher = await rotationInDatei(db);

      await repo.verwirfEntwurf('D-1');

      expect(await zeilenVon(db, 'D-1'), (0, 0, 0));
      expect(await repo.training('D-1'), isNull);
      expect((await repo.alle()).map((d) => d.id), isNot(contains('D-1')));
      expect(await abbild(db, 'E-1'), anderes);
      expect(await rotationInDatei(db), rotationVorher);
    });

    test('Verwerfen einer unbekannten Kennung ändert nichts', () async {
      final db = neueDb();
      final repo = GymTrainingRepository(db);
      await repo.speichere(eigenes('E-1'));
      final vorher = [
        await anzahl(db, 'gym_trainings'),
        await anzahl(db, 'gym_training_uebungen'),
        await anzahl(db, 'gym_training_tags'),
      ];

      await repo.verwirfEntwurf('GIBT-ES-NICHT');

      expect([
        await anzahl(db, 'gym_trainings'),
        await anzahl(db, 'gym_training_uebungen'),
        await anzahl(db, 'gym_training_tags'),
      ], vorher);
    });

    test('Verwerfen löscht nie ein fertiges Training und nie ein Template',
        () async {
      final db = neueDb();
      final repo = GymTrainingRepository(db);
      await repo.speichere(eigenes('E-1'));
      final fertig = await abbild(db, 'E-1');
      final template = await abbild(db, 'Push');

      for (final id in ['E-1', 'Push']) {
        try {
          await repo.verwirfEntwurf(id);
        } on Object {
          // Verweigern ist erlaubt (siehe Dateikopf); Löschen nicht.
        }
      }

      expect(await abbild(db, 'E-1'), fertig);
      expect(await abbild(db, 'Push'), template);
      expect((await repo.alle()).map((d) => d.id), containsAll(['Push', 'E-1']));
    });

    test('Speichern eines Entwurfs ohne `isDraft` macht ihn zum fertigen '
        'Eigenen: dieselbe Kennung, die Kapsel fällt weg', () async {
      final db = neueDb();
      final repo = GymTrainingRepository(db);
      await repo.speichere(eigenes('E-1'));
      await repo.speichere(
        eigenes('D-1', name: 'Halb', exercises: [uebung('dips')], isDraft: true),
      );
      final reihenfolge = (await zeilen(
        db,
        'gym_trainings',
        wo: "id = 'D-1'",
      )).single['reihenfolge'];
      final fertig = eigenes(
        'D-1',
        name: 'Fertig',
        exercises: [uebung('dips'), uebung('pullUp')],
      );

      await repo.speichere(fertig);

      expect(await repo.training('D-1'), fertig);
      final zeile = (await zeilen(db, 'gym_trainings', wo: "id = 'D-1'")).single;
      expect(zeile['ist_entwurf'], 0);
      expect(zeile['reihenfolge'], reihenfolge, reason: 'der Platz bleibt');
      expect(await anzahl(db, 'gym_trainings', "id = 'D-1'"), 1);
    });

    test('ein unfertiger Stand lässt sich **nicht** als fertiges Training '
        'speichern — er bleibt Entwurf', () async {
      final db = neueDb();
      final repo = GymTrainingRepository(db);
      final entwurf = eigenes('D-1', name: 'Halb', exercises: [], isDraft: true);
      await repo.speichere(entwurf);

      await expectLater(
        repo.speichere(eigenes('D-1', name: 'Halb', exercises: [])),
        throwsArgumentError,
        reason: 'ohne Übung: kein fertiges Training (Tim, 19.11.2026)',
      );

      expect(await repo.training('D-1'), entwurf);
      expect(
        (await zeilen(db, 'gym_trainings', wo: "id = 'D-1'")).single['ist_entwurf'],
        1,
      );
    });

    test('ein Entwurf ist nie in der Rotation', () async {
      final db = neueDb();
      final repo = GymTrainingRepository(db);

      await repo.speichere(eigenes('D-1', isDraft: true));

      expect(await repo.rotation(), ['Push', 'Pull', 'Legs']);
    });
  });

  group('Zwischenstand an bestehendem Training (Spec 22 Nr. 3, Plan 1)', () {
    WorkoutDefinition original() => eigenes(
      'E-1',
      name: 'Oberkörper zuhause',
      tags: ['Home', 'Alt'],
      exercises: [
        uebung('benchPress', sets: 4, repLow: 6, repHigh: 10),
        uebung('lateralRaise', sets: 4, repLow: 12, repHigh: 20),
        uebung('dips', sets: 3, repLow: 6, repHigh: 12),
      ],
      enteredMinutes: 45,
    );

    WorkoutDefinition stand(String id) => eigenes(
      id,
      name: 'Neuer Name',
      tags: ['Home'],
      exercises: [
        uebung('dips', sets: 5, repLow: 5, repHigh: 8),
        uebung('benchPress', sets: 3, repLow: 6, repHigh: 10),
      ],
      enteredMinutes: null,
      isDraft: true,
    );

    test('der Zwischenstand hängt am Training, und das Training bleibt, wie '
        'es war', () async {
      final db = neueDb();
      final repo = GymTrainingRepository(db);
      await repo.speichere(original());
      final vorher = await abbild(db, 'E-1');

      await repo.speichereZwischenstand(stand('ZW-1'), von: 'E-1');

      expect(await abbild(db, 'E-1'), vorher, reason: 'erst beim Speichern');
      expect(await repo.training('E-1'), original());
      expect(await repo.zwischenstandVon('E-1'), stand('ZW-1'));
      final zeile = (await zeilen(db, 'gym_trainings', wo: "id = 'ZW-1'")).single;
      expect(zeile['entwurf_von'], 'E-1');
      expect(zeile['ist_entwurf'], 1);
      expect(zeile['kategorie'], 'eigene');
      expect((await repo.alle()).map((d) => d.id), containsAll(['E-1', 'ZW-1']));
      expect(
        (await repo.alle(mitEntwuerfen: false)).map((d) => d.id),
        isNot(contains('ZW-1')),
      );
    });

    test('ein Training ohne Zwischenstand und eine unbekannte Kennung '
        'liefern null', () async {
      final repo = GymTrainingRepository(neueDb());
      await repo.speichere(original());

      expect(await repo.zwischenstandVon('E-1'), isNull);
      expect(await repo.zwischenstandVon('GIBT-ES-NICHT'), isNull);
    });

    test('je Training höchstens ein Zwischenstand: der zweite ersetzt den '
        'ersten samt Übungen und Tags', () async {
      final db = neueDb();
      final repo = GymTrainingRepository(db);
      await repo.speichere(original());
      await repo.speichereZwischenstand(stand('ZW-1'), von: 'E-1');

      await repo.speichereZwischenstand(
        eigenes(
          'ZW-2',
          name: 'Noch anders',
          tags: [],
          exercises: [uebung('pullUp')],
          isDraft: true,
        ),
        von: 'E-1',
      );

      expect(await anzahl(db, 'gym_trainings', "entwurf_von = 'E-1'"), 1);
      expect(await zeilenVon(db, 'ZW-1'), (0, 0, 0), reason: 'keine Reste');
      expect((await repo.zwischenstandVon('E-1'))!.id, 'ZW-2');
      expect((await repo.zwischenstandVon('E-1'))!.name, 'Noch anders');
    });

    test('dieselbe Kennung des Zwischenstands erneut gesichert: aktualisiert, '
        'nicht verdoppelt', () async {
      final db = neueDb();
      final repo = GymTrainingRepository(db);
      await repo.speichere(original());
      await repo.speichereZwischenstand(stand('ZW-1'), von: 'E-1');
      final spaeter = eigenes(
        'ZW-1',
        name: 'Später',
        tags: ['Home', 'Neu'],
        exercises: [uebung('pullUp')],
        isDraft: true,
      );

      await repo.speichereZwischenstand(spaeter, von: 'E-1');

      expect(await repo.zwischenstandVon('E-1'), spaeter);
      expect(await anzahl(db, 'gym_trainings', "entwurf_von = 'E-1'"), 1);
      expect(await zeilenVon(db, 'ZW-1'), (1, 1, 2));
    });

    test('mehrere Zwischenstände gleichzeitig: je Training einer', () async {
      final db = neueDb();
      final repo = GymTrainingRepository(db);
      await repo.speichere(original());
      await repo.speichere(eigenes('E-2', name: 'Zweites'));

      await repo.speichereZwischenstand(stand('ZW-1'), von: 'E-1');
      await repo.speichereZwischenstand(
        eigenes('ZW-2', name: 'Anderes', isDraft: true),
        von: 'E-2',
      );

      expect((await repo.zwischenstandVon('E-1'))!.id, 'ZW-1');
      expect((await repo.zwischenstandVon('E-2'))!.id, 'ZW-2');
      expect(await anzahl(db, 'gym_trainings', 'entwurf_von IS NOT NULL'), 2);
    });

    test('ein Zwischenstand darf unfertig sein und einen vergebenen Namen '
        'tragen', () async {
      final repo = GymTrainingRepository(neueDb());
      await repo.speichere(original());
      final unfertig = eigenes(
        'ZW-1',
        name: 'Oberkörper zuhause',
        tags: [],
        exercises: [],
        isDraft: true,
      );

      await repo.speichereZwischenstand(unfertig, von: 'E-1');

      expect(await repo.zwischenstandVon('E-1'), unfertig);
    });

    test('Zwischenstand und Training sind zwei Zeilen — `rotation()` kennt '
        'nur das Training', () async {
      final db = neueDb();
      final repo = GymTrainingRepository(db);
      await repo.speichere(original());
      await setzeRotation(db, ['Push', 'E-1', 'Pull', 'Legs']);

      await repo.speichereZwischenstand(stand('ZW-1'), von: 'E-1');

      expect(await repo.rotation(), ['Push', 'E-1', 'Pull', 'Legs']);
    });

    test('Verwerfen löscht den Zwischenstand und lässt das Training stehen',
        () async {
      final db = neueDb();
      final repo = GymTrainingRepository(db);
      await repo.speichere(original());
      await repo.speichereZwischenstand(stand('ZW-1'), von: 'E-1');
      final vorher = await abbild(db, 'E-1');

      await repo.verwirfEntwurf('ZW-1');

      expect(await zeilenVon(db, 'ZW-1'), (0, 0, 0));
      expect(await repo.zwischenstandVon('E-1'), isNull);
      expect(await abbild(db, 'E-1'), vorher);
      expect(await repo.training('E-1'), original());
    });

    test('Speichern ersetzt das Training **vollständig** durch den '
        'Zwischenstand und räumt ihn weg', () async {
      final db = neueDb();
      final repo = GymTrainingRepository(db);
      await repo.speichere(original());
      await repo.speichere(eigenes('E-2', name: 'Zweites'));
      await setzeRotation(db, ['Push', 'Pull', 'Legs', 'E-1']);
      await repo.speichereZwischenstand(stand('ZW-1'), von: 'E-1');
      final anderes = await abbild(db, 'E-2');

      await repo.uebernimmZwischenstand('ZW-1');

      expect(
        await repo.training('E-1'),
        eigenes(
          'E-1',
          name: 'Neuer Name',
          tags: ['Home'],
          exercises: [
            uebung('dips', sets: 5, repLow: 5, repHigh: 8),
            uebung('benchPress', sets: 3, repLow: 6, repHigh: 10),
          ],
          enteredMinutes: null,
        ),
        reason:
            'Name, Tags, Übungen in neuer Reihenfolge, die eingetragene '
            'Dauer wieder „geschätzt" — nichts vom alten Stand bleibt',
      );
      expect(
        await zeilenVon(db, 'E-1'),
        (1, 2, 1),
        reason: 'drei alte Übungen und zwei Tags sind weg, kein Rest',
      );
      expect(await uebungenInDatei(db, 'E-1'), ['dips', 'benchPress']);
      expect(await zeilenVon(db, 'ZW-1'), (0, 0, 0), reason: 'Entwurf weg');
      expect(await repo.zwischenstandVon('E-1'), isNull);
      final zeile = (await zeilen(db, 'gym_trainings', wo: "id = 'E-1'")).single;
      expect(zeile['ist_entwurf'], 0);
      expect(zeile['entwurf_von'], isNull);
      expect(zeile['reihenfolge'], 1, reason: 'der Platz bleibt');
      expect(
        await repo.rotation(),
        ['Push', 'Pull', 'Legs', 'E-1'],
        reason: 'das Training behält seine Kennung — und seinen Platz',
      );
      expect(await abbild(db, 'E-2'), anderes);
      expect((await repo.alle()).where((d) => d.isDraft), isEmpty);
    });

    test('ein unfertiger Zwischenstand lässt sich nicht übernehmen, und '
        'nichts ändert sich', () async {
      final db = neueDb();
      final repo = GymTrainingRepository(db);
      await repo.speichere(original());
      final unfertig = eigenes(
        'ZW-1',
        name: 'Ohne Übungen',
        exercises: [],
        isDraft: true,
      );
      await repo.speichereZwischenstand(unfertig, von: 'E-1');
      final vorher = await abbild(db, 'E-1');

      await expectLater(repo.uebernimmZwischenstand('ZW-1'), throwsArgumentError);

      expect(await abbild(db, 'E-1'), vorher);
      expect(await repo.zwischenstandVon('E-1'), unfertig);
    });

    test('Übernehmen ist gesperrt, solange die Erfassung das Training trägt',
        () async {
      final db = neueDb();
      final repo = GymTrainingRepository(db);
      await repo.speichere(original());
      await repo.speichereZwischenstand(stand('ZW-1'), von: 'E-1');
      await laufendesTraining(db, 'E-1');
      final vorher = await abbild(db, 'E-1');

      await expectLater(repo.uebernimmZwischenstand('ZW-1'), throwsStateError);

      expect(await abbild(db, 'E-1'), vorher);
      expect(await repo.zwischenstandVon('E-1'), stand('ZW-1'));
    });
  });

  group('App-Abbruch: die Datenbank bleibt (Spec 22 Nr. 3)', () {
    test('beim nächsten Start liegen Entwurf und Zwischenstand da, und das '
        'Training ist unverändert', () async {
      final roh = sqlite3.openInMemory();
      addTearDown(roh.close);
      final ausgang = eigenes(
        'E-1',
        tags: ['Home', 'Alt'],
        exercises: [uebung('benchPress'), uebung('dips')],
        enteredMinutes: 45,
      );
      final frei = eigenes(
        'D-1',
        name: '',
        tags: ['Entwurfstag'],
        exercises: [uebung('pullUp')],
        isDraft: true,
      );
      final zwischenstand = eigenes(
        'ZW-1',
        name: 'Ungespeicherte Änderung',
        tags: ['Home'],
        exercises: [uebung('dips', sets: 5, repLow: 5, repHigh: 8)],
        isDraft: true,
      );
      final erstes = await oeffne(roh);
      final repo = GymTrainingRepository(erstes);
      await repo.speichere(ausgang);
      await repo.speichere(frei);
      await repo.speichereZwischenstand(zwischenstand, von: 'E-1');
      await erstes.close(); // der Container ist weg, die Datei bleibt

      final zweites = await oeffne(roh);
      addTearDown(zweites.close);
      final danach = GymTrainingRepository(zweites);

      expect(await danach.training('E-1'), ausgang);
      expect(await danach.training('D-1'), frei);
      expect(await danach.zwischenstandVon('E-1'), zwischenstand);
      expect(
        (await danach.alle()).map((d) => d.id).toSet(),
        {'Push', 'Pull', 'Legs', 'E-1', 'D-1', 'ZW-1'},
        reason: 'beide stehen als Entwurfs-Kacheln unter „Eigene"',
      );
      expect(await danach.rotation(), ['Push', 'Pull', 'Legs']);
    });
  });
}
