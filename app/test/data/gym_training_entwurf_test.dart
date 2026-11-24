import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show sqlite3;
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/gym/gym_editor_provider.dart';
import 'package:repit/gym/gym_trainings_provider.dart';

import '../gym/gym_editor_support.dart';

/// Tests für die **Entwurfsmechanik des Editors**: Er sichert seinen Stand
/// automatisch als Entwurf, sobald etwas geändert wurde; „Verwerfen" löscht
/// auch das Gesicherte; beim Bearbeiten hängt der Zwischenstand am Training
/// und ersetzt es erst beim Speichern; ein App-Abbruch kostet nichts (#534
/// unter #531, Task 3.3 des Plans `docs/superpowers/plans/2026-11-19-
/// eigene-trainings-plan.md`). Der **Zustand** des Editors — `probleme`,
/// `geaendert`, Dauer, Tags, Verschieben — steht in
/// `app/test/gym/gym_editor_provider_test.dart`; die **Ablage** darunter
/// (`speichereZwischenstand`, `uebernimmZwischenstand` …) in
/// `gym_training_zwischenstand_test.dart` und
/// `gym_training_repository_test.dart` — hier steht nur, **wann der Editor
/// sie ruft**.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden. Hält der
/// Implementierende eine Erwartung für falsch, wird das **gemeldet, nicht
/// korrigiert**.
///
/// ## Was die Nachträge bewachen
///
/// - **Spec 22 Nr. 3 [Tim, 19.11.2026]** (schlägt 9.6, 17.14, 17.15): Der
///   Editor schreibt seinen Stand fortlaufend als Entwurf, **sobald etwas
///   geändert wurde** — ein nur geöffneter Editor hinterlässt nichts, sonst
///   erzeugte jeder Fehltipp eine Geisterkachel. Nach einem App-Abbruch
///   liegt der Stand als Entwurfs-Kachel unter „Eigene" da. „Verwerfen"
///   löscht auch den gesicherten Stand, „Als Entwurf behalten" benennt nur
///   noch, was ohnehin gesichert ist. Beim Bearbeiten hängt der Entwurf am
///   Training und ersetzt es erst beim Speichern.
/// - **Spec 25 und Plan 4/5** (Folgerungen): Takt **1,5 Sekunden** nach der
///   letzten Änderung, plus sofortiges Schreiben beim Schließen; sobald der
///   Stand dem Ausgang wieder gleicht, wird die Zeile gelöscht (sonst die
///   Geisterkachel).
/// - **Spec 4.7:** Die Erfassung sperrt das Speichern und das Löschen für
///   ihr Training; der Editor meldet es, statt zu speichern. Der
///   Zwischenstand ändert das Training nicht und ist **nicht** gesperrt.
/// - **Spec 9.6:** Ein Entwurf darf unfertig sein und einen schon
///   vergebenen Namen tragen; er ist weder startbar noch einplanbar.
/// - **Spec 6.3:** Der Übersichts-Stand ist nach jedem Schreiben aktuell
///   (`ref.invalidate` beim Schreiber, keine drift-Streams).
/// - **Spec 6.1, Plan 17.5:** Die Kopie eines Templates entsteht **erst
///   beim Speichern**; das Template bleibt in jedem Fall unverändert.
///
/// ## Wer hat was entschieden
///
/// - **Entscheidungen von Tim:** Selbstsicherung, Verwerfen, Zwischenstand
///   am bestehenden Training (19.11.2026); Entwurf weder startbar noch
///   einplanbar (19.11.2026); die Kopie ist ein Neues, das Template bleibt
///   (18.11.2026).
/// - **Vorschläge, hier vorausgesetzt:** 1,5 Sekunden und das sofortige
///   Schreiben (Plan 5); Zeile löschen bei Gleichstand (Plan 4); Name ist
///   Pflicht (17 Nr. 7).
/// - **Spec 27 Nr. 3 (Folgerung, Koordinator):** Bei der Quelle `entwurf`
///   löscht Zurückändern die Zeile **nicht** — der Ausgang ist dort der
///   gespeicherte Entwurf selbst, und ihn zu löschen, weil man etwas an- und
///   wieder ausgeschaltet hat, wäre Datenverlust. Die Zeile trägt danach den
///   gespeicherten Stand, nicht den Zwischenstand davor.
/// - **Spec 27 Nr. 2 (Folgerung, Koordinator):** Die Übersicht zeigt als
///   Entwurfs-Kacheln nur **freie** Entwürfe; ein Zwischenstand an einem
///   Training ist keine eigene Kachel.
///
/// **Alle Namen, Zahlen und Zeitpunkte sind erfunden.**
void main() {
  final bank = ausKatalog('benchPress');
  final seitheben = ausKatalog('lateralRaise');
  final dips = ausKatalog('dips');

  Future<EditorHandle> neuerEditor(EditorBasis basis) =>
      oeffneEditor(basis.container, const GymEditorQuelle.neu());

  Future<EditorBasis> mitEigenem({
    String name = 'Kurzhantel zuhause',
    int? minuten = 45,
  }) async {
    final basis = editorBasis();
    await basis.repo.speichere(
      eigenes('E-1', name: name, tags: ['Home'], enteredMinutes: minuten),
    );
    return basis;
  }

  group('Ein nur geöffneter Editor hinterlässt nichts (Spec 22 Nr. 3)', () {
    editorTest('neu: öffnen und warten', (tester) async {
      final basis = editorBasis();
      await neuerEditor(basis);

      await tester.pump(const Duration(seconds: 5));

      expect(await eigeneZeilen(basis.db), isEmpty);
      expect(basis.repo.schreibungen, 0);
    });

    editorTest('neu: „Schließen" und „Als Entwurf behalten" ohne Änderung '
        'schreiben nichts', (tester) async {
      final basis = editorBasis();
      final editor = await neuerEditor(basis);

      await editor.notifier.schreibeSofort();
      await editor.notifier.behalteAlsEntwurf();
      await tester.pump(const Duration(seconds: 5));

      expect(await eigeneZeilen(basis.db), isEmpty);
      expect(basis.repo.schreibungen, 0);
    });

    editorTest('neu: ändern und zurückändern bis zum leeren Stand — ein ganz '
        'leerer Editor wird nie zum Entwurf', (tester) async {
      final basis = editorBasis();
      final editor = await neuerEditor(basis);

      editor.notifier.setzeName('Versehen');
      editor.notifier.fuegeUebungHinzu('dips');
      editor.notifier.entferneUebung('dips');
      editor.notifier.setzeName('');
      await tester.pump(const Duration(seconds: 5));
      await editor.notifier.schreibeSofort();

      expect(editor.stand.geaendert, isFalse);
      expect(await eigeneZeilen(basis.db), isEmpty);
    });

    editorTest('kopie: öffnen, nichts tun — nichts angelegt, das Template '
        'unverändert', (tester) async {
      final basis = editorBasis();
      final vorher = await abbild(basis.db, 'Push');
      final editor = await oeffneEditor(
        basis.container,
        const GymEditorQuelle.kopie('Push'),
      );

      await editor.notifier.schreibeSofort();
      await editor.notifier.behalteAlsEntwurf();
      await tester.pump(const Duration(seconds: 5));

      expect(await eigeneZeilen(basis.db), isEmpty);
      expect(await abbild(basis.db, 'Push'), vorher);
    });

    editorTest('bearbeite: öffnen, nichts tun — kein Zwischenstand', (
      tester,
    ) async {
      final basis = await mitEigenem();
      final vorher = await abbild(basis.db, 'E-1');
      final editor = await oeffneEditor(
        basis.container,
        const GymEditorQuelle.bearbeite('E-1'),
      );

      await editor.notifier.schreibeSofort();
      await editor.notifier.behalteAlsEntwurf();
      await tester.pump(const Duration(seconds: 5));

      expect(await zwischenstaendeAn(basis.db, 'E-1'), 0);
      expect(await eigeneZeilen(basis.db), hasLength(1));
      expect(await abbild(basis.db, 'E-1'), vorher);
    });

    editorTest('entwurf: öffnen, nichts tun — die Zeile bleibt, wie sie '
        'ist', (tester) async {
      final basis = editorBasis();
      await basis.repo.speichere(
        eigenes(
          'D-1',
          name: 'Oberkörper kurz',
          tags: ['Home'],
          exercises: [bank],
          isDraft: true,
        ),
      );
      final vorher = await abbild(basis.db, 'D-1');
      final editor = await oeffneEditor(
        basis.container,
        const GymEditorQuelle.entwurf('D-1'),
      );

      await editor.notifier.schreibeSofort();
      await editor.notifier.behalteAlsEntwurf();
      await tester.pump(const Duration(seconds: 5));

      expect(await abbild(basis.db, 'D-1'), vorher);
      expect(await eigeneZeilen(basis.db), hasLength(1));
    });
  });

  group('Selbstsicherung: ab der ersten Änderung, fortlaufend (Plan 5)', () {
    editorTest('1,5 Sekunden nach der Änderung — nicht früher', (tester) async {
      final basis = editorBasis();
      final editor = await neuerEditor(basis);

      editor.notifier.setzeName('Zuhause kurz');

      await tester.pump(const Duration(milliseconds: 1400));
      expect(
        await eigeneZeilen(basis.db),
        isEmpty,
        reason: 'nach 1,4 s ist noch nichts geschrieben',
      );

      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();
      final zeilen = await eigeneZeilen(basis.db);
      expect(zeilen, hasLength(1), reason: 'nach 1,6 s steht der Entwurf da');
      expect(zeilen.single['id'], neueKennung);
      expect(zeilen.single['ist_entwurf'], 1);
      expect(zeilen.single['entwurf_von'], isNull);
      expect(zeilen.single['name'], 'Zuhause kurz');
    });

    editorTest('der Entwurf trägt den ganzen Stand: Name, Tags, Übungen in '
        'der Reihenfolge, eingetragene Dauer', (tester) async {
      final basis = editorBasis();
      final editor = await neuerEditor(basis);

      editor.notifier
        ..setzeName('Zuhause kurz')
        ..fuegeTagHinzu('Home')
        ..fuegeUebungHinzu('benchPress')
        ..fuegeUebungHinzu('lateralRaise')
        ..verschiebeUebung(1, 0)
        ..setzeDauer(55);
      await sicherungsTakt(tester);

      expect(
        await basis.repo.training(neueKennung),
        WorkoutDefinition(
          id: neueKennung,
          name: 'Zuhause kurz',
          category: WorkoutCategory.own,
          tags: ['Home'],
          exercises: [seitheben, bank],
          enteredMinutes: 55,
          isDraft: true,
        ),
      );
    });

    editorTest('nicht bei jeder Änderung: zwei Änderungen im Abstand von '
        '0,5 s ergeben einen Schreibvorgang', (tester) async {
      final basis = editorBasis();
      final editor = await neuerEditor(basis);

      editor.notifier.setzeName('Eins');
      await tester.pump(const Duration(milliseconds: 500));
      editor.notifier.setzeName('Zwei');

      await tester.pump(const Duration(milliseconds: 1400));
      expect(
        await eigeneZeilen(basis.db),
        isEmpty,
        reason: 'Die Wartezeit hat bei der zweiten Änderung von vorn begonnen',
      );

      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();
      expect(basis.repo.schreibungen, 1);
      expect((await eigeneZeilen(basis.db)).single['name'], 'Zwei');
    });

    editorTest('fortlaufend: jede spätere Änderung ersetzt den Entwurf — eine '
        'Zeile, keine Reste', (tester) async {
      final basis = editorBasis();
      final editor = await neuerEditor(basis);
      editor.notifier
        ..setzeName('Eins')
        ..fuegeUebungHinzu('benchPress');
      await sicherungsTakt(tester);
      expect((await eigeneZeilen(basis.db)).single['name'], 'Eins');

      editor.notifier
        ..setzeName('Zwei')
        ..fuegeUebungHinzu('dips');
      await tester.pump(const Duration(milliseconds: 1400));
      expect(
        (await eigeneZeilen(basis.db)).single['name'],
        'Eins',
        reason: 'noch nicht erneut geschrieben',
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();

      expect((await eigeneZeilen(basis.db)).single['name'], 'Zwei');
      expect(await uebungenInDatei(basis.db, neueKennung), [
        'benchPress',
        'dips',
      ]);
      expect(basis.repo.schreibungen, 2);
    });

    editorTest('„Schließen" schreibt einen geänderten Stand sofort', (
      tester,
    ) async {
      final basis = editorBasis();
      final editor = await neuerEditor(basis);
      editor.notifier
        ..setzeName('Zuhause kurz')
        ..fuegeUebungHinzu('benchPress');

      await editor.notifier.schreibeSofort();

      final training = await basis.repo.training(neueKennung);
      expect(training, isNotNull, reason: 'ohne die 1,5 s abzuwarten');
      expect(training!.name, 'Zuhause kurz');
      expect(training.isDraft, isTrue);
    });

    editorTest('ein Entwurf darf unfertig sein: nur ein Name', (tester) async {
      final basis = editorBasis();
      final editor = await neuerEditor(basis);

      editor.notifier.setzeName('Nur ein Name');
      await sicherungsTakt(tester);

      final definition = await basis.repo.training(neueKennung);
      expect(definition!.name, 'Nur ein Name');
      expect(definition.exercises, isEmpty);
      expect(definition.isDraft, isTrue);
    });

    editorTest('ein Entwurf darf unfertig sein: nur eine Übung, ohne Namen', (
      tester,
    ) async {
      final basis = editorBasis();
      final editor = await neuerEditor(basis);

      editor.notifier.fuegeUebungHinzu('benchPress');
      await sicherungsTakt(tester);

      final definition = await basis.repo.training(neueKennung);
      expect(definition!.name, '');
      expect(definition.exercises, [bank]);
      expect(definition.isDraft, isTrue);
    });

    editorTest('ein Entwurf darf einen schon vergebenen Namen tragen — Namen '
        'sind kein Schlüssel (Spec 9.6)', (tester) async {
      final basis = editorBasis();
      final editor = await neuerEditor(basis);

      editor.notifier
        ..setzeName('Push — Brust, Schultern, Trizeps')
        ..fuegeUebungHinzu('benchPress');
      await sicherungsTakt(tester);

      final training = await basis.repo.training(neueKennung);
      expect(training, isNotNull);
      expect(training!.name, 'Push — Brust, Schultern, Trizeps');
      expect(await editor.notifier.speichere(), GymEditorErgebnis.gespeichert);
    });

    editorTest('zurückändern löscht die Zeile (Plan 4) — bei `neu`', (
      tester,
    ) async {
      final basis = editorBasis();
      final editor = await neuerEditor(basis);
      editor.notifier
        ..setzeName('Zuhause kurz')
        ..fuegeUebungHinzu('benchPress');
      await sicherungsTakt(tester);
      expect(await eigeneZeilen(basis.db), hasLength(1));

      editor.notifier
        ..setzeName('')
        ..entferneUebung('benchPress');
      await sicherungsTakt(tester);

      expect(editor.stand.geaendert, isFalse);
      expect(await eigeneZeilen(basis.db), isEmpty);
      expect(await zeilenVon(basis.db, neueKennung), (0, 0, 0));
    });

    editorTest('zurückändern löscht die Zeile (Plan 4) — bei `kopie`, und '
        'das Template bleibt', (tester) async {
      final basis = editorBasis();
      final vorher = await abbild(basis.db, 'Push');
      final editor = await oeffneEditor(
        basis.container,
        const GymEditorQuelle.kopie('Push'),
      );
      editor.notifier.entferneUebung('lateralRaise');
      await sicherungsTakt(tester);
      expect(await eigeneZeilen(basis.db), hasLength(1));

      editor.notifier.fuegeUebungHinzu('lateralRaise');
      editor.notifier.verschiebeUebung(6, 4);
      await sicherungsTakt(tester);

      expect(
        editor.stand.uebungen,
        WorkoutTemplates.byId('Push')!.exercises,
        reason: 'Vorbedingung: lateralRaise steht wieder an Platz 5',
      );
      expect(editor.stand.geaendert, isFalse);
      expect(await eigeneZeilen(basis.db), isEmpty);
      expect(await abbild(basis.db, 'Push'), vorher);
    });

    editorTest('zurückändern löscht den Zwischenstand (Plan 4) — bei '
        '`bearbeite`, und das Training bleibt', (tester) async {
      final basis = await mitEigenem();
      final vorher = await abbild(basis.db, 'E-1');
      final editor = await oeffneEditor(
        basis.container,
        const GymEditorQuelle.bearbeite('E-1'),
      );
      editor.notifier.setzeName('Anders');
      await sicherungsTakt(tester);
      expect(await zwischenstaendeAn(basis.db, 'E-1'), 1);

      editor.notifier.setzeName('Kurzhantel zuhause');
      await sicherungsTakt(tester);

      expect(editor.stand.geaendert, isFalse);
      expect(await zwischenstaendeAn(basis.db, 'E-1'), 0);
      expect(await eigeneZeilen(basis.db), hasLength(1));
      expect(await abbild(basis.db, 'E-1'), vorher);
    });

    editorTest('ein Entwurf, der geöffnet und geändert wird, bleibt '
        'dieselbe Zeile — kein zweiter', (tester) async {
      final basis = editorBasis();
      await basis.repo.speichere(
        eigenes(
          'D-1',
          name: 'Oberkörper kurz',
          tags: ['Home'],
          exercises: [bank],
          isDraft: true,
        ),
      );
      final editor = await oeffneEditor(
        basis.container,
        const GymEditorQuelle.entwurf('D-1'),
      );

      editor.notifier.setzeName('Oberkörper lang');
      await sicherungsTakt(tester);

      final zeilen = await eigeneZeilen(basis.db);
      expect(zeilen, hasLength(1));
      expect(zeilen.single['id'], 'D-1');
      expect(zeilen.single['name'], 'Oberkörper lang');
      expect(zeilen.single['ist_entwurf'], 1);
    });

    editorTest('der Entwurf ist weder startbar noch einplanbar: nicht in der '
        'Rotation, nicht in `readyCount` (Tim, 19.11.2026)', (tester) async {
      final basis = editorBasis();
      final vorher = await uebersicht(basis.container);
      expect(vorher.readyCount, 3);
      final editor = await neuerEditor(basis);

      editor.notifier
        ..setzeName('Zuhause kurz')
        ..fuegeUebungHinzu('benchPress');
      await sicherungsTakt(tester);

      expect(await basis.repo.rotation(), ['Push', 'Pull', 'Legs']);
      expect(await rotationInDatei(basis.db), [
        (1, 'Push'),
        (2, 'Pull'),
        (3, 'Legs'),
      ]);
      expect(await basis.repo.alle(mitEntwuerfen: false), hasLength(3));
      final stand = await uebersicht(basis.container);
      expect(stand.readyCount, 3);
      expect(
        stand.own.single.isDraft,
        isTrue,
        reason: 'er steht als Entwurfs-Kachel unter „Eigene" da',
      );
    });
  });

  group('Zurückändern bei `entwurf` löscht die Zeile nie (Spec 27 Nr. 3)', () {
    editorTest('ändern, sichern, zurückändern, sichern: die Zeile steht da und '
        'trägt den gespeicherten Stand', (tester) async {
      final basis = editorBasis();
      await basis.repo.speichere(
        eigenes(
          'D-1',
          name: 'Oberkörper kurz',
          tags: ['Home'],
          exercises: [bank],
          isDraft: true,
        ),
      );
      final vorher = await abbild(basis.db, 'D-1');
      final editor = await oeffneEditor(
        basis.container,
        const GymEditorQuelle.entwurf('D-1'),
      );

      editor.notifier.setzeName('Oberkörper lang');
      await sicherungsTakt(tester);
      expect((await basis.repo.training('D-1'))!.name, 'Oberkörper lang');

      editor.notifier.setzeName('Oberkörper kurz');
      await sicherungsTakt(tester);
      await editor.notifier.schreibeSofort();

      expect(editor.stand.geaendert, isFalse);
      expect(await eigeneZeilen(basis.db), hasLength(1));
      expect(
        await abbild(basis.db, 'D-1'),
        vorher,
        reason:
            'Die Zeile bleibt — und sie trägt den gespeicherten Stand, nicht '
            'den Zwischenstand davor',
      );
    });

    editorTest('dasselbe mit einer Übung: hinzufügen, sichern, entfernen, '
        'sichern', (tester) async {
      final basis = editorBasis();
      await basis.repo.speichere(
        eigenes(
          'D-1',
          name: 'Oberkörper kurz',
          tags: ['Home'],
          exercises: [bank],
          isDraft: true,
        ),
      );
      final vorher = await abbild(basis.db, 'D-1');
      final editor = await oeffneEditor(
        basis.container,
        const GymEditorQuelle.entwurf('D-1'),
      );

      editor.notifier.fuegeUebungHinzu('dips');
      await sicherungsTakt(tester);
      editor.notifier.entferneUebung('dips');
      await sicherungsTakt(tester);

      expect(editor.stand.geaendert, isFalse);
      expect(await abbild(basis.db, 'D-1'), vorher);
    });
  });

  group('Ein Zwischenstand ist keine eigene Kachel (Spec 27 Nr. 2)', () {
    editorTest('ein Zwischenstand an E-1: die Übersicht hat genau eine Kachel '
        'für E-1 — und keine zweite', (tester) async {
      final basis = await mitEigenem();
      await basis.repo.speichereZwischenstand(
        eigenes(
          'ZW-1',
          name: 'Ungespeicherte Änderung',
          tags: ['Home'],
          exercises: [bank],
          isDraft: true,
        ),
        von: 'E-1',
      );

      final stand = await uebersicht(basis.container);

      expect(stand.own.map((k) => k.id), ['E-1']);
      expect(stand.own.single.name, 'Kurzhantel zuhause');
      expect(stand.own.single.isDraft, isFalse);
      expect(stand.readyCount, 4);
    });

    editorTest('auch der Zwischenstand, den der Editor sichert: keine zweite '
        'Kachel, das Training bleibt, wie es ist', (tester) async {
      final basis = await mitEigenem();
      await uebersicht(basis.container);
      final editor = await oeffneEditor(
        basis.container,
        const GymEditorQuelle.bearbeite('E-1'),
      );

      editor.notifier.setzeName('Kurzhantel kurz');
      await sicherungsTakt(tester);
      expect(await zwischenstaendeAn(basis.db, 'E-1'), 1);

      final stand = await uebersicht(basis.container);
      expect(stand.own.map((k) => k.id), ['E-1']);
      expect(stand.own.single.name, 'Kurzhantel zuhause');
      expect(stand.readyCount, 4);
    });

    editorTest('ein freier Entwurf daneben bleibt eine Kachel — nur der '
        'Zwischenstand fällt weg', (tester) async {
      final basis = await mitEigenem();
      await basis.repo.speichere(
        eigenes(
          'D-1',
          name: 'Oberkörper kurz',
          tags: ['Home'],
          exercises: [bank],
          isDraft: true,
        ),
      );
      await basis.repo.speichereZwischenstand(
        eigenes(
          'ZW-1',
          name: 'Ungespeicherte Änderung',
          tags: ['Home'],
          exercises: [bank],
          isDraft: true,
        ),
        von: 'E-1',
      );

      final stand = await uebersicht(basis.container);

      expect(stand.own.map((k) => k.id), ['E-1', 'D-1']);
      expect(stand.own.last.isDraft, isTrue);
      expect(stand.readyCount, 4);
    });
  });

  group('Bearbeite: der Zwischenstand hängt am Training (Spec 22 Nr. 3)', () {
    editorTest('die erste Änderung legt ihn an — das Training bleibt, wie es '
        'ist', (tester) async {
      final basis = await mitEigenem();
      final vorher = await abbild(basis.db, 'E-1');
      final editor = await oeffneEditor(
        basis.container,
        const GymEditorQuelle.bearbeite('E-1'),
      );

      editor.notifier
        ..setzeName('Kurzhantel kurz')
        ..fuegeUebungHinzu('dips');
      await sicherungsTakt(tester);

      final zwischenstand = await basis.repo.zwischenstandVon('E-1');
      expect(zwischenstand, isNotNull);
      expect(zwischenstand!.name, 'Kurzhantel kurz');
      expect(zwischenstand.exercises, [bank, seitheben, dips]);
      expect(zwischenstand.isDraft, isTrue);
      expect(await abbild(basis.db, 'E-1'), vorher);
      expect(await zwischenstaendeAn(basis.db, 'E-1'), 1);
    });

    editorTest('je Training höchstens einer: weitere Änderungen ersetzen ihn', (
      tester,
    ) async {
      final basis = await mitEigenem();
      final editor = await oeffneEditor(
        basis.container,
        const GymEditorQuelle.bearbeite('E-1'),
      );

      editor.notifier.setzeName('Eins');
      await sicherungsTakt(tester);
      editor.notifier.setzeName('Zwei');
      await sicherungsTakt(tester);

      expect(await zwischenstaendeAn(basis.db, 'E-1'), 1);
      expect((await basis.repo.zwischenstandVon('E-1'))!.name, 'Zwei');
      expect(
        await eigeneZeilen(basis.db),
        hasLength(2),
        reason: 'das Training und sein Zwischenstand — sonst nichts',
      );
    });

    editorTest('ein zweiter Editor für dasselbe Training nimmt den '
        'Zwischenstand auf, statt einen zweiten anzulegen', (tester) async {
      final basis = await mitEigenem();
      final erster = await oeffneEditor(
        basis.container,
        const GymEditorQuelle.bearbeite('E-1'),
      );
      erster.notifier.setzeName('Aus der ersten Sitzung');
      await sicherungsTakt(tester);
      erster.schliesse();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final zweiter = await oeffneEditor(
        basis.container,
        const GymEditorQuelle.bearbeite('E-1'),
      );
      expect(zweiter.stand.name, 'Aus der ersten Sitzung');
      zweiter.notifier.setzeName('Aus der zweiten Sitzung');
      await sicherungsTakt(tester);

      expect(await zwischenstaendeAn(basis.db, 'E-1'), 1);
      expect(
        (await basis.repo.zwischenstandVon('E-1'))!.name,
        'Aus der zweiten Sitzung',
      );
    });

    editorTest('der Zwischenstand ist nicht gesperrt, solange die Erfassung '
        'läuft — er ändert das Training nicht (Spec 4.7)', (tester) async {
      final basis = await mitEigenem();
      await laufendesTraining(basis.db, 'E-1');
      final editor = await oeffneEditor(
        basis.container,
        const GymEditorQuelle.bearbeite('E-1'),
      );

      editor.notifier.setzeName('Während des Trainings getippt');
      await sicherungsTakt(tester);

      expect(
        (await basis.repo.zwischenstandVon('E-1'))!.name,
        'Während des Trainings getippt',
      );
    });
  });

  group('Verwerfen löscht auch das Gesicherte (Spec 22 Nr. 3)', () {
    editorTest('neu: der gesicherte Entwurf ist weg, und es kommt nichts '
        'nach', (tester) async {
      final basis = editorBasis();
      final editor = await neuerEditor(basis);
      editor.notifier
        ..setzeName('Zuhause kurz')
        ..fuegeUebungHinzu('benchPress');
      await sicherungsTakt(tester);
      expect(await eigeneZeilen(basis.db), hasLength(1));

      await editor.notifier.verwirf();
      await tester.pump(const Duration(seconds: 3));

      expect(await eigeneZeilen(basis.db), isEmpty);
      expect(await zeilenVon(basis.db, neueKennung), (0, 0, 0));
    });

    editorTest('neu: verwerfen **vor** dem Takt — die Wartezeit schreibt '
        'danach nichts mehr', (tester) async {
      final basis = editorBasis();
      final editor = await neuerEditor(basis);
      editor.notifier
        ..setzeName('Zuhause kurz')
        ..fuegeUebungHinzu('benchPress');

      await editor.notifier.verwirf();
      await tester.pump(const Duration(seconds: 3));

      expect(await eigeneZeilen(basis.db), isEmpty);
      expect(
        basis.repo.schreibungen,
        0,
        reason: 'Ein Schreibauftrag aus der Zeit davor tut nichts mehr',
      );
    });

    editorTest('kopie: verwerfen löscht die Kopie und lässt das Template '
        'unverändert', (tester) async {
      final basis = editorBasis();
      final vorher = await abbild(basis.db, 'Push');
      final editor = await oeffneEditor(
        basis.container,
        const GymEditorQuelle.kopie('Push'),
      );
      editor.notifier.setzeName('Push — meine Fassung');
      await sicherungsTakt(tester);
      expect(await eigeneZeilen(basis.db), hasLength(1));

      await editor.notifier.verwirf();
      await tester.pump(const Duration(seconds: 3));

      expect(await eigeneZeilen(basis.db), isEmpty);
      expect(await abbild(basis.db, 'Push'), vorher);
    });

    editorTest('bearbeite: der Zwischenstand ist weg, das Training bleibt', (
      tester,
    ) async {
      final basis = await mitEigenem();
      final vorher = await abbild(basis.db, 'E-1');
      final editor = await oeffneEditor(
        basis.container,
        const GymEditorQuelle.bearbeite('E-1'),
      );
      editor.notifier.setzeName('Anders');
      await sicherungsTakt(tester);
      expect(await zwischenstaendeAn(basis.db, 'E-1'), 1);

      await editor.notifier.verwirf();
      await tester.pump(const Duration(seconds: 3));

      expect(await zwischenstaendeAn(basis.db, 'E-1'), 0);
      expect(await abbild(basis.db, 'E-1'), vorher);
      expect(await eigeneZeilen(basis.db), hasLength(1));
    });

    editorTest('entwurf: der Entwurf ist samt Übungen und Tags weg', (
      tester,
    ) async {
      final basis = editorBasis();
      await basis.repo.speichere(
        eigenes(
          'D-1',
          name: 'Oberkörper kurz',
          tags: ['Home', 'Kurz'],
          exercises: [bank, seitheben],
          isDraft: true,
        ),
      );
      final editor = await oeffneEditor(
        basis.container,
        const GymEditorQuelle.entwurf('D-1'),
      );

      await editor.notifier.verwirf();

      expect(await zeilenVon(basis.db, 'D-1'), (0, 0, 0));
    });

    editorTest('entwurf: nach einer Änderung verwerfen löscht den '
        'gespeicherten Entwurf ebenso — nicht nur die Änderung', (tester) async {
      final basis = editorBasis();
      await basis.repo.speichere(
        eigenes(
          'D-1',
          name: 'Oberkörper kurz',
          tags: ['Home'],
          exercises: [bank],
          isDraft: true,
        ),
      );
      final editor = await oeffneEditor(
        basis.container,
        const GymEditorQuelle.entwurf('D-1'),
      );
      editor.notifier.setzeName('Oberkörper lang');
      await sicherungsTakt(tester);

      await editor.notifier.verwirf();
      await tester.pump(const Duration(seconds: 3));

      expect(await zeilenVon(basis.db, 'D-1'), (0, 0, 0));
    });
  });

  group('„Als Entwurf behalten" benennt nur noch (Spec 22 Nr. 3)', () {
    editorTest('neu: sichert den geänderten Stand sofort', (tester) async {
      final basis = editorBasis();
      final editor = await neuerEditor(basis);
      editor.notifier
        ..setzeName('Zuhause kurz')
        ..fuegeUebungHinzu('benchPress');

      await editor.notifier.behalteAlsEntwurf();

      final training = await basis.repo.training(neueKennung);
      expect(training!.name, 'Zuhause kurz');
      expect(training.isDraft, isTrue);
    });

    editorTest('wo schon gesichert ist, ändert es nichts mehr', (tester) async {
      final basis = editorBasis();
      final editor = await neuerEditor(basis);
      editor.notifier
        ..setzeName('Zuhause kurz')
        ..fuegeUebungHinzu('benchPress');
      await sicherungsTakt(tester);
      final vorher = await abbild(basis.db, neueKennung);

      await editor.notifier.behalteAlsEntwurf();

      expect(await abbild(basis.db, neueKennung), vorher);
      expect(await eigeneZeilen(basis.db), hasLength(1));
    });

    editorTest('bearbeite: es gibt den Zwischenstand auch dort', (
      tester,
    ) async {
      final basis = await mitEigenem();
      final editor = await oeffneEditor(
        basis.container,
        const GymEditorQuelle.bearbeite('E-1'),
      );
      editor.notifier.setzeName('Ungespeicherte Änderung');

      await editor.notifier.behalteAlsEntwurf();

      expect(
        (await basis.repo.zwischenstandVon('E-1'))!.name,
        'Ungespeicherte Änderung',
      );
      expect((await basis.repo.training('E-1'))!.name, 'Kurzhantel zuhause');
    });

    editorTest('kopie: legt die Kopie als Entwurf ab', (tester) async {
      final basis = editorBasis();
      final editor = await oeffneEditor(
        basis.container,
        const GymEditorQuelle.kopie('Push'),
      );
      editor.notifier.setzeName('Push — meine Fassung');

      await editor.notifier.behalteAlsEntwurf();

      final training = await basis.repo.training(neueKennung);
      expect(training!.name, 'Push — meine Fassung');
      expect(training.isDraft, isTrue);
      expect(training.category, WorkoutCategory.own);
    });
  });

  group('App-Abbruch: die Datenbank bleibt (Spec 22 Nr. 3)', () {
    editorTest('neu: beim nächsten Start liegt der Stand als Entwurfs-Kachel '
        'da und öffnet sich wieder', (tester) async {
      final roh = sqlite3.openInMemory();
      addTearDown(roh.close);
      final db1 = await oeffne(roh);
      final erste = editorBasis(db: db1);
      final editor = await neuerEditor(erste);
      editor.notifier
        ..setzeName('Zuhause kurz')
        ..fuegeTagHinzu('Home')
        ..fuegeUebungHinzu('benchPress')
        ..fuegeUebungHinzu('lateralRaise')
        ..setzeDauer(55);
      await sicherungsTakt(tester);

      // Die App wird beendet: Der Baum und der Container sind weg, die
      // Datei bleibt.
      editor.schliesse();
      erste.container.dispose();
      await db1.close();

      final db2 = await oeffne(roh);
      addTearDown(db2.close);
      final zweite = editorBasis(db: db2);
      final stand = await uebersicht(zweite.container);
      final kachel = stand.own.single;
      expect(kachel.id, neueKennung);
      expect(kachel.name, 'Zuhause kurz');
      expect(kachel.isDraft, isTrue);
      expect(kachel.exerciseCount, 2);
      expect(stand.readyCount, 3);

      final wieder = await oeffneEditor(
        zweite.container,
        const GymEditorQuelle.entwurf(neueKennung),
      );
      expect(wieder.stand.name, 'Zuhause kurz');
      expect(wieder.stand.tags, ['Home']);
      expect(wieder.stand.uebungen, [bank, seitheben]);
      expect(wieder.stand.dauerEingetragen, 55);
      expect(wieder.stand.geaendert, isFalse);
    });

    editorTest('bearbeite: der Zwischenstand liegt da, das Training ist '
        'unverändert, und ein neuer Editor nimmt ihn auf', (tester) async {
      final roh = sqlite3.openInMemory();
      addTearDown(roh.close);
      final db1 = await oeffne(roh);
      final erste = editorBasis(db: db1);
      await erste.repo.speichere(
        eigenes('E-1', name: 'Kurzhantel zuhause', tags: ['Home']),
      );
      final vorher = await abbild(db1, 'E-1');
      final editor = await oeffneEditor(
        erste.container,
        const GymEditorQuelle.bearbeite('E-1'),
      );
      editor.notifier
        ..setzeName('Ungespeicherte Änderung')
        ..fuegeUebungHinzu('dips');
      await sicherungsTakt(tester);

      editor.schliesse();
      erste.container.dispose();
      await db1.close();

      final db2 = await oeffne(roh);
      addTearDown(db2.close);
      final zweite = editorBasis(db: db2);
      expect(await abbild(db2, 'E-1'), vorher);
      expect(await zwischenstaendeAn(db2, 'E-1'), 1);

      final wieder = await oeffneEditor(
        zweite.container,
        const GymEditorQuelle.bearbeite('E-1'),
      );
      expect(wieder.stand.name, 'Ungespeicherte Änderung');
      expect(wieder.stand.uebungen, [bank, seitheben, dips]);
      expect(wieder.stand.geaendert, isTrue);
    });
  });

  group('Speichern (Spec 9.6)', () {
    editorTest('neu: ein fertiges Eigenes, der Entwurf ist weg — und die '
        'Wartezeit schreibt nichts mehr nach', (tester) async {
      final basis = editorBasis();
      final editor = await neuerEditor(basis);
      editor.notifier
        ..setzeName('  Zuhause kurz  ')
        ..fuegeTagHinzu('Home')
        ..fuegeUebungHinzu('benchPress');

      final ergebnis = await editor.notifier.speichere();
      await tester.pump(const Duration(seconds: 3));

      expect(ergebnis, GymEditorErgebnis.gespeichert);
      final training = await basis.repo.training(neueKennung);
      expect(
        training,
        WorkoutDefinition(
          id: neueKennung,
          name: 'Zuhause kurz',
          category: WorkoutCategory.own,
          tags: ['Home'],
          exercises: [bank],
        ),
        reason: 'getrimmt, fertig (`isDraft` false), Kategorie „eigene"',
      );
      expect(
        await anzahl(basis.db, 'gym_trainings', 'ist_entwurf = 1'),
        0,
        reason: 'Kein Entwurf übrig, auch nicht nach der Wartezeit',
      );
      expect(await basis.repo.alle(), hasLength(4));
    });

    editorTest('neu: ein Eigenes ohne Rotationsplatz und mit der nächsten '
        '`reihenfolge`', (tester) async {
      final basis = await mitEigenem();
      final editor = await neuerEditor(basis);
      editor.notifier
        ..setzeName('Zweites')
        ..fuegeUebungHinzu('dips');

      await editor.notifier.speichere();

      final eigene = await eigeneZeilen(basis.db);
      expect(eigene.map((z) => z['id']), ['E-1', neueKennung]);
      expect(eigene[0]['reihenfolge'], 1);
      expect(eigene[1]['reihenfolge'], 2);
      expect(await rotationInDatei(basis.db), [
        (1, 'Push'),
        (2, 'Pull'),
        (3, 'Legs'),
      ]);
    });

    editorTest('die Positionen liegen lückenlos, in der Reihenfolge des '
        'Editors', (tester) async {
      final basis = editorBasis();
      final editor = await neuerEditor(basis);
      editor.notifier
        ..setzeName('Drei')
        ..fuegeUebungHinzu('benchPress')
        ..fuegeUebungHinzu('lateralRaise')
        ..fuegeUebungHinzu('dips')
        ..verschiebeUebung(2, 0)
        ..entferneUebung('lateralRaise');

      await editor.notifier.speichere();

      final zeilenDerUebungen = await zeilen(
        basis.db,
        'gym_training_uebungen',
        ordnung: 'pos',
        wo: "training_id = '$neueKennung'",
      );
      expect(
        [for (final z in zeilenDerUebungen) (z['pos'], z['uebung_id'])],
        [(1, 'dips'), (2, 'benchPress')],
      );
    });

    editorTest('eingetragene Dauer wird gespeichert', (tester) async {
      final basis = editorBasis();
      final editor = await neuerEditor(basis);
      editor.notifier
        ..setzeName('Mit Dauer')
        ..fuegeUebungHinzu('benchPress')
        ..setzeDauer(55);

      await editor.notifier.speichere();

      expect((await basis.repo.training(neueKennung))!.enteredMinutes, 55);
    });

    editorTest('zurück zur Schätzung heißt: keine eingetragene Dauer', (
      tester,
    ) async {
      final basis = editorBasis();
      final editor = await neuerEditor(basis);
      editor.notifier
        ..setzeName('Ohne Dauer')
        ..fuegeUebungHinzu('benchPress')
        ..setzeDauer(55)
        ..dauerZuruecksetzen();

      await editor.notifier.speichere();

      expect((await basis.repo.training(neueKennung))!.enteredMinutes, isNull);
    });

    editorTest('kopie: erst jetzt entsteht das Eigene — das Template und die '
        'Rotation bleiben unverändert', (tester) async {
      final basis = editorBasis();
      final vorher = await abbild(basis.db, 'Push');
      final editor = await oeffneEditor(
        basis.container,
        const GymEditorQuelle.kopie('Push'),
      );
      editor.notifier
        ..setzeName('Push — meine Fassung')
        ..entferneUebung('overheadTriceps');
      expect(await basis.repo.alle(mitEntwuerfen: false), hasLength(3));

      final ergebnis = await editor.notifier.speichere();
      await tester.pump(const Duration(seconds: 3));

      expect(ergebnis, GymEditorErgebnis.gespeichert);
      final kopie = await basis.repo.training(neueKennung);
      expect(kopie!.name, 'Push — meine Fassung');
      expect(kopie.category, WorkoutCategory.own);
      expect(kopie.isDraft, isFalse);
      expect(kopie.tags, ['Gym']);
      expect(kopie.exercises, hasLength(6));
      expect(kopie.enteredMinutes, 70);
      expect(await abbild(basis.db, 'Push'), vorher);
      expect(await basis.repo.alle(mitEntwuerfen: false), hasLength(4));
      expect(await basis.repo.alle(), hasLength(4));
      expect(await rotationInDatei(basis.db), [
        (1, 'Push'),
        (2, 'Pull'),
        (3, 'Legs'),
      ]);
    });

    editorTest('kopie, ohne Änderung gespeichert: genau die Kopie nach Spec '
        '4.5 — Name „… (Kopie)", Tags, Übungen, eingetragene Dauer', (
      tester,
    ) async {
      final basis = editorBasis();
      final editor = await oeffneEditor(
        basis.container,
        const GymEditorQuelle.kopie('Push'),
      );

      expect(await editor.notifier.speichere(), GymEditorErgebnis.gespeichert);

      final push = WorkoutTemplates.byId('Push')!;
      expect(
        await basis.repo.training(neueKennung),
        WorkoutDefinition(
          id: neueKennung,
          name: 'Push (Kopie)',
          category: WorkoutCategory.own,
          tags: push.tags,
          exercises: push.exercises,
          enteredMinutes: 70,
        ),
      );
    });

    editorTest('bearbeite: ersetzt vollständig — Kennung, Reihenfolge und '
        'Rotationsplatz bleiben, der Zwischenstand ist weg', (tester) async {
      final basis = await mitEigenem();
      await setzeRotation(basis.db, ['Push', 'E-1', 'Legs']);
      final zeileVorher = (await zeileVon(basis.db, 'E-1'))!;
      final editor = await oeffneEditor(
        basis.container,
        const GymEditorQuelle.bearbeite('E-1'),
      );
      editor.notifier
        ..setzeName('Kurzhantel neu')
        ..fuegeTagHinzu('Kurz')
        ..entferneTag('Home')
        ..entferneUebung('benchPress')
        ..fuegeUebungHinzu('dips')
        ..setzeDauer(50);
      await sicherungsTakt(tester);
      expect(await zwischenstaendeAn(basis.db, 'E-1'), 1);

      final ergebnis = await editor.notifier.speichere();
      await tester.pump(const Duration(seconds: 3));

      expect(ergebnis, GymEditorErgebnis.gespeichert);
      expect(
        await basis.repo.training('E-1'),
        WorkoutDefinition(
          id: 'E-1',
          name: 'Kurzhantel neu',
          category: WorkoutCategory.own,
          tags: ['Kurz'],
          exercises: [seitheben, dips],
          enteredMinutes: 50,
        ),
      );
      expect((await zeileVon(basis.db, 'E-1'))!['reihenfolge'],
          zeileVorher['reihenfolge']);
      expect(await rotationInDatei(basis.db), [
        (1, 'Push'),
        (2, 'E-1'),
        (3, 'Legs'),
      ]);
      expect(await zwischenstaendeAn(basis.db, 'E-1'), 0);
      expect(await eigeneZeilen(basis.db), hasLength(1));
      expect(
        await uebungenInDatei(basis.db, 'E-1'),
        ['lateralRaise', 'dips'],
        reason: 'keine doppelte `pos`, keine Reste',
      );
    });

    editorTest('bearbeite, sofort nach der Änderung gespeichert — ohne dass '
        'der Takt lief', (tester) async {
      final basis = await mitEigenem();
      final editor = await oeffneEditor(
        basis.container,
        const GymEditorQuelle.bearbeite('E-1'),
      );
      editor.notifier.setzeName('Sofort');

      expect(await editor.notifier.speichere(), GymEditorErgebnis.gespeichert);

      expect((await basis.repo.training('E-1'))!.name, 'Sofort');
      expect(await zwischenstaendeAn(basis.db, 'E-1'), 0);
    });

    editorTest('entwurf: wird fertig unter derselben Kennung', (tester) async {
      final basis = editorBasis();
      await basis.repo.speichere(
        eigenes(
          'D-1',
          name: 'Oberkörper kurz',
          tags: ['Home'],
          exercises: [bank, seitheben],
          isDraft: true,
        ),
      );
      final editor = await oeffneEditor(
        basis.container,
        const GymEditorQuelle.entwurf('D-1'),
      );

      expect(await editor.notifier.speichere(), GymEditorErgebnis.gespeichert);

      final training = await basis.repo.training('D-1');
      expect(training!.isDraft, isFalse);
      expect(training.name, 'Oberkörper kurz');
      expect(await basis.repo.alle(mitEntwuerfen: false), hasLength(4));
      expect(await eigeneZeilen(basis.db), hasLength(1));
    });

    editorTest('entwurf ohne Namen: nicht speicherbar, der Entwurf bleibt', (
      tester,
    ) async {
      final basis = editorBasis();
      await basis.repo.speichere(
        eigenes('D-1', name: '', tags: [], exercises: [bank], isDraft: true),
      );
      final editor = await oeffneEditor(
        basis.container,
        const GymEditorQuelle.entwurf('D-1'),
      );

      expect(
        await editor.notifier.speichere(),
        GymEditorErgebnis.nichtSpeicherbar,
      );

      expect((await basis.repo.training('D-1'))!.isDraft, isTrue);
    });
  });

  group('Sperre bei laufender Erfassung (Spec 4.7, Plan 17.6)', () {
    editorTest('Speichern wird verweigert — das Training und der eingetippte '
        'Stand bleiben', (tester) async {
      final basis = await mitEigenem();
      await laufendesTraining(basis.db, 'E-1');
      final vorher = await abbild(basis.db, 'E-1');
      final editor = await oeffneEditor(
        basis.container,
        const GymEditorQuelle.bearbeite('E-1'),
      );
      editor.notifier
        ..setzeName('Gesperrt')
        ..entferneUebung('benchPress');

      final ergebnis = await editor.notifier.speichere();

      expect(ergebnis, GymEditorErgebnis.gesperrt);
      expect(editor.stand.name, 'Gesperrt');
      expect(editor.stand.uebungen, [seitheben]);
      expect(editor.stand.geaendert, isTrue);
      expect(await abbild(basis.db, 'E-1'), vorher);
    });

    editorTest('Löschen wird verweigert — das Training steht noch da', (
      tester,
    ) async {
      final basis = await mitEigenem();
      await laufendesTraining(basis.db, 'E-1');
      final editor = await oeffneEditor(
        basis.container,
        const GymEditorQuelle.bearbeite('E-1'),
      );

      final ergebnis = await editor.notifier.loesche();

      expect(ergebnis, GymLoeschErgebnis.laeuft);
      expect(await basis.repo.training('E-1'), isNotNull);
    });

    editorTest('nach dem Abschluss der Erfassung geht Speichern wieder', (
      tester,
    ) async {
      final basis = await mitEigenem();
      await laufendesTraining(basis.db, 'E-1');
      final editor = await oeffneEditor(
        basis.container,
        const GymEditorQuelle.bearbeite('E-1'),
      );
      editor.notifier.setzeName('Erst gesperrt');
      expect(await editor.notifier.speichere(), GymEditorErgebnis.gesperrt);

      await basis.db.customStatement('DELETE FROM gym_entwuerfe;');

      expect(await editor.notifier.speichere(), GymEditorErgebnis.gespeichert);
      expect((await basis.repo.training('E-1'))!.name, 'Erst gesperrt');
    });
  });

  group('Löschen aus dem Editor (Spec 9.6, 26 Nr. 1)', () {
    editorTest('ein Eigenes ist weg, samt Zwischenstand und Rotationsplatz — '
        'ohne Lücke', (tester) async {
      final basis = await mitEigenem();
      await setzeRotation(basis.db, ['Push', 'E-1', 'Legs']);
      final editor = await oeffneEditor(
        basis.container,
        const GymEditorQuelle.bearbeite('E-1'),
      );
      editor.notifier.setzeName('Wird gelöscht');
      await sicherungsTakt(tester);
      expect(await zwischenstaendeAn(basis.db, 'E-1'), 1);

      final ergebnis = await editor.notifier.loesche();
      await tester.pump(const Duration(seconds: 3));

      expect(ergebnis, GymLoeschErgebnis.geloescht);
      expect(await basis.repo.training('E-1'), isNull);
      expect(await zeilenVon(basis.db, 'E-1'), (0, 0, 0));
      expect(await eigeneZeilen(basis.db), isEmpty);
      expect(await rotationInDatei(basis.db), [(1, 'Push'), (2, 'Legs')]);
    });
  });

  group('Der Übersichts-Stand ist nach jedem Schreiben aktuell (Spec 6.3)', () {
    editorTest('Speichern: das neue Training steht sofort in der Übersicht', (
      tester,
    ) async {
      final basis = editorBasis();
      final vorher = await uebersicht(basis.container);
      expect(vorher.own, isEmpty);
      final editor = await neuerEditor(basis);
      editor.notifier
        ..setzeName('Zuhause kurz')
        ..fuegeUebungHinzu('benchPress');

      await editor.notifier.speichere();

      final nachher = await uebersicht(basis.container);
      expect(nachher.own.map((k) => k.name), ['Zuhause kurz']);
      expect(nachher.own.single.isDraft, isFalse);
      expect(nachher.readyCount, 4);
    });

    editorTest('Selbstsicherung: der Entwurf steht als Kachel da, ohne dass '
        'jemand neu liest', (tester) async {
      final basis = editorBasis();
      await uebersicht(basis.container);
      final editor = await neuerEditor(basis);
      editor.notifier.setzeName('Halb fertig');

      await sicherungsTakt(tester);

      final stand = await uebersicht(basis.container);
      expect(stand.own.single.name, 'Halb fertig');
      expect(stand.own.single.isDraft, isTrue);
      expect(stand.readyCount, 3);
    });

    editorTest('Als Entwurf behalten und Verwerfen: die Kachel kommt und '
        'geht', (tester) async {
      final basis = editorBasis();
      await uebersicht(basis.container);
      final editor = await neuerEditor(basis);
      editor.notifier.setzeName('Halb fertig');

      await editor.notifier.behalteAlsEntwurf();
      expect((await uebersicht(basis.container)).own, hasLength(1));

      await editor.notifier.verwirf();
      expect((await uebersicht(basis.container)).own, isEmpty);
    });

    editorTest('Speichern beim Bearbeiten: das Detail und die Übersicht '
        'lesen den neuen Namen', (tester) async {
      final basis = await mitEigenem();
      await basis.container.read(gymTrainingProvider('E-1').future);
      await uebersicht(basis.container);
      final editor = await oeffneEditor(
        basis.container,
        const GymEditorQuelle.bearbeite('E-1'),
      );
      editor.notifier.setzeName('Kurzhantel neu');

      await editor.notifier.speichere();

      final detail = await basis.container.read(gymTrainingProvider('E-1').future);
      expect(detail!.name, 'Kurzhantel neu');
      expect(
        (await uebersicht(basis.container)).own.single.name,
        'Kurzhantel neu',
      );
    });

    editorTest('Löschen: das Training verschwindet aus Detail und Übersicht', (
      tester,
    ) async {
      final basis = await mitEigenem();
      await basis.container.read(gymTrainingProvider('E-1').future);
      expect((await uebersicht(basis.container)).own, hasLength(1));
      final editor = await oeffneEditor(
        basis.container,
        const GymEditorQuelle.bearbeite('E-1'),
      );

      await editor.notifier.loesche();

      expect(await basis.container.read(gymTrainingProvider('E-1').future), isNull);
      expect((await uebersicht(basis.container)).own, isEmpty);
    });
  });
}
