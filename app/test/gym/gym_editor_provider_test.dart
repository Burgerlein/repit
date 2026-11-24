import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/gym/gym_editor_provider.dart';

import 'gym_editor_support.dart';

/// Tests für den **Zustand des Editors**: `GymEditorQuelle`, `GymEditorStand`
/// und `GymEditorNotifier` je Fall — neu, Kopie eines Templates, Bearbeiten
/// eines Eigenen, frei stehender Entwurf (#534 unter #531, Task 3.3 des Plans
/// `docs/superpowers/plans/2026-11-19-eigene-trainings-plan.md`). Ohne
/// Widgets. Was **in die Datenbank** geschrieben wird (Selbstsicherung,
/// Verwerfen, Speichern, Sperre, Invalidierung), steht in
/// `app/test/data/gym_training_entwurf_test.dart`.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden. Hält der
/// Implementierende eine Erwartung für falsch, wird das **gemeldet, nicht
/// korrigiert**.
///
/// ## Was die Anforderung bewacht
///
/// - **Fehler `01`:** Solange der Editor liest (`laedt`), steht kein Grund da:
///   `probleme` ist leer, der Stand ist nicht „leeres Training". Eingaben in
///   dieser Zeit werden nicht angenommen.
/// - **Fehler `32`:** Der Stand liegt im Notifier, nicht im Widget; er
///   überlebt, solange der Editor offen ist, und ist `autoDispose` —
///   **nichts überlebt das Schließen, außer einem Entwurf in der Datenbank**
///   (Spec 9.2).
/// - **Fehler `03`:** Die Schätzung steht als Feld im Stand, **bei jeder
///   Änderung einmal gerechnet**, nicht im `build` (Spec 9.2). Werttypen mit
///   `==` und `hashCode`, Listen inhaltlich.
/// - **`geaendert` ist inhaltlich** (Spec 9.2): Ändern und Zurückändern
///   heißt nichts geändert; bei `neu` und `kopie` ist der Ausgang der
///   **unberührte** Stand.
///
/// ## Wer hat was entschieden
///
/// - **Entscheidungen von Tim:** Leer nicht speicherbar (19.11.2026); die
///   Dauer wird geschätzt und lässt sich überschreiben und zurücksetzen
///   (19.11.2026); die Kopie eines Templates ist ein Neues unter „Eigene",
///   das Template bleibt unverändert (18.11.2026); Selbstsicherung
///   (19.11.2026, Spec 22 Nr. 3); Templates sind nicht löschbar (Spec 26
///   Nr. 1).
/// - **Vorschläge der Spec, hier vorausgesetzt:** Name ist Pflicht (17 Nr. 7);
///   die Kopie entsteht erst beim Speichern (17 Nr. 5); die Grenzen aus 5.2.
/// - **Folgerungen:** `probleme` ist `WorkoutRules.check` über den Stand als
///   **fertiges** Training; eine Übung steht nur einmal im Training (4.1).
/// - **Festlegungen des Test-Agenten** (Namen und Verhalten der Methoden,
///   die die Spec offen lässt): im Kopf von `gym_editor_support.dart`. Tim
///   hat sie nicht gesehen.
///
/// **Alle Namen, Zahlen und Zeitpunkte sind erfunden.**
void main() {
  WorkoutExercise bank({int sets = 4, int low = 6, int high = 10}) =>
      WorkoutExercise(
        exerciseId: 'benchPress',
        sets: sets,
        repLow: low,
        repHigh: high,
      );
  final seitheben = WorkoutExercise(
    exerciseId: 'lateralRaise',
    sets: 4,
    repLow: 12,
    repHigh: 20,
  );
  final dips = WorkoutExercise(
    exerciseId: 'dips',
    sets: 3,
    repLow: 6,
    repHigh: 12,
  );

  group('Werttypen (Fehler `03`)', () {
    test('`GymEditorQuelle`: gleiche Fälle mit gleicher Kennung sind gleich', () {
      expect(const GymEditorQuelle.neu(), const GymEditorQuelle.neu());
      expect(
        const GymEditorQuelle.bearbeite('E-1'),
        const GymEditorQuelle.bearbeite('E-1'),
      );
      expect(
        const GymEditorQuelle.kopie('Push'),
        const GymEditorQuelle.kopie('Push'),
      );
      expect(
        const GymEditorQuelle.entwurf('D-1'),
        const GymEditorQuelle.entwurf('D-1'),
      );
      expect(
        const GymEditorQuelle.bearbeite('E-1').hashCode,
        const GymEditorQuelle.bearbeite('E-1').hashCode,
      );
      expect(
        const GymEditorQuelle.neu().hashCode,
        const GymEditorQuelle.neu().hashCode,
      );
    });

    test('verschiedene Fälle oder Kennungen sind ungleich — auch bei '
        'gleicher Kennung', () {
      expect(
        const GymEditorQuelle.bearbeite('E-1'),
        isNot(const GymEditorQuelle.bearbeite('E-2')),
      );
      expect(
        const GymEditorQuelle.bearbeite('X'),
        isNot(const GymEditorQuelle.kopie('X')),
      );
      expect(
        const GymEditorQuelle.bearbeite('X'),
        isNot(const GymEditorQuelle.entwurf('X')),
      );
      expect(
        const GymEditorQuelle.kopie('X'),
        isNot(const GymEditorQuelle.entwurf('X')),
      );
      expect(
        const GymEditorQuelle.neu(),
        isNot(const GymEditorQuelle.bearbeite('X')),
      );
    });

    GymEditorStand stand({
      bool laedt = false,
      String name = 'Zuhause kurz',
      List<String>? tags,
      int? dauerEingetragen = 45,
      int? schaetzung = 20,
      List<WorkoutExercise>? uebungen,
      bool geaendert = true,
      List<WorkoutProblem>? probleme,
      String? kopieVon = 'Push — Brust, Schultern, Trizeps',
    }) => GymEditorStand(
      laedt: laedt,
      name: name,
      tags: tags ?? ['Home', 'Kurz'],
      dauerEingetragen: dauerEingetragen,
      schaetzung: schaetzung,
      uebungen: uebungen ?? [bank(), seitheben],
      geaendert: geaendert,
      probleme: probleme ?? [const NameTooLong()],
      kopieVon: kopieVon,
    );

    test('zwei Stände mit gleichen Feldern sind gleich — auch wenn die '
        'Listen verschiedene Objekte sind', () {
      final a = stand();
      final b = stand();

      expect(identical(a.tags, b.tags), isFalse);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('jedes einzelne Feld macht den Unterschied', () {
      final grund = stand();
      final abweichungen = <String, GymEditorStand>{
        'laedt': stand(laedt: true),
        'name': stand(name: 'Anders'),
        'tags (Inhalt)': stand(tags: ['Home']),
        'tags (Reihenfolge)': stand(tags: ['Kurz', 'Home']),
        'dauerEingetragen': stand(dauerEingetragen: 50),
        'dauerEingetragen null': stand(dauerEingetragen: null),
        'schaetzung': stand(schaetzung: 25),
        'schaetzung null': stand(schaetzung: null),
        'uebungen (Inhalt)': stand(uebungen: [bank()]),
        'uebungen (Reihenfolge)': stand(uebungen: [seitheben, bank()]),
        'uebungen (Satzzahl)': stand(uebungen: [bank(sets: 3), seitheben]),
        'geaendert': stand(geaendert: false),
        'probleme': stand(probleme: [const NameEmpty()]),
        'kopieVon': stand(kopieVon: null),
      };

      for (final eintrag in abweichungen.entries) {
        expect(
          eintrag.value,
          isNot(grund),
          reason: '${eintrag.key} wird nicht verglichen',
        );
      }
    });
  });

  group('Quelle `neu` (Spec 9.2, 9.6)', () {
    editorTest('der unberührte Stand: leer, nichts geändert — und der Grund '
        'nennt Name und Übung', (tester) async {
      final basis = editorBasis();
      final editor = await oeffneEditor(
        basis.container,
        const GymEditorQuelle.neu(),
      );

      final s = editor.stand;
      expect(s.laedt, isFalse);
      expect(s.name, '');
      expect(s.tags, isEmpty);
      expect(s.dauerEingetragen, isNull);
      expect(
        s.schaetzung,
        isNull,
        reason: 'keine Übung — keine Schätzung, nicht 0 (Fehler `01`)',
      );
      expect(s.uebungen, isEmpty);
      expect(s.geaendert, isFalse);
      expect(s.kopieVon, isNull);
      expect(
        s.probleme,
        unorderedEquals(<WorkoutProblem>[const NameEmpty(), const NoExercises()]),
        reason: 'WorkoutRules.check über das fertige Training (9.2)',
      );
    });

    editorTest('der Name wird so gehalten, wie er getippt ist, und ist eine '
        'Änderung', (tester) async {
      final basis = editorBasis();
      final editor = await oeffneEditor(
        basis.container,
        const GymEditorQuelle.neu(),
      );

      editor.notifier.setzeName('  Zuhause kurz ');

      expect(editor.stand.name, '  Zuhause kurz ');
      expect(editor.stand.geaendert, isTrue);
      expect(editor.stand.probleme, [const NoExercises()]);
    });

    editorTest('eine Übung kommt aus dem Katalog vorbelegt — am Ende — und '
        'die Schätzung rechnet mit', (tester) async {
      final basis = editorBasis();
      final editor = await oeffneEditor(
        basis.container,
        const GymEditorQuelle.neu(),
      );

      editor.notifier.fuegeUebungHinzu('benchPress');
      expect(editor.stand.uebungen, [bank()]);
      expect(editor.stand.schaetzung, 10);
      expect(editor.stand.probleme, [const NameEmpty()]);

      editor.notifier.fuegeUebungHinzu('lateralRaise');
      expect(editor.stand.uebungen, [bank(), seitheben]);
      expect(editor.stand.schaetzung, 20);
    });

    editorTest('eine Übung steht nur einmal im Training: ein zweites '
        'Hinzufügen ändert nichts', (tester) async {
      final basis = editorBasis();
      final editor = await oeffneEditor(
        basis.container,
        const GymEditorQuelle.neu(),
      );
      editor.notifier.fuegeUebungHinzu('benchPress');
      final vorher = editor.stand;

      editor.notifier.fuegeUebungHinzu('benchPress');

      expect(editor.stand.uebungen, [bank()]);
      expect(editor.stand, vorher);
      expect(
        editor.stand.probleme.whereType<DuplicateExercise>(),
        isEmpty,
        reason: 'Der Editor erzeugt keinen Regelverstoß, den er vermeiden kann',
      );
    });

    editorTest('Entfernen nimmt die Übung heraus und die Schätzung rechnet '
        'neu; eine Kennung, die nicht drin ist, tut nichts', (tester) async {
      final basis = editorBasis();
      final editor = await oeffneEditor(
        basis.container,
        const GymEditorQuelle.neu(),
      );
      editor.notifier
        ..fuegeUebungHinzu('benchPress')
        ..fuegeUebungHinzu('lateralRaise');

      editor.notifier.entferneUebung('benchPress');
      expect(editor.stand.uebungen, [seitheben]);
      expect(editor.stand.schaetzung, 10);

      final vorher = editor.stand;
      editor.notifier.entferneUebung('dips');
      expect(editor.stand, vorher);
    });

    editorTest('Verschieben: der Zielindex gilt in der Liste danach, und '
        'zurückschieben stellt den Stand wieder her', (tester) async {
      final basis = editorBasis();
      final editor = await oeffneEditor(
        basis.container,
        const GymEditorQuelle.neu(),
      );
      editor.notifier
        ..fuegeUebungHinzu('benchPress')
        ..fuegeUebungHinzu('lateralRaise')
        ..fuegeUebungHinzu('dips');

      editor.notifier.verschiebeUebung(0, 2);
      expect(editor.stand.uebungen, [seitheben, dips, bank()]);

      editor.notifier.verschiebeUebung(2, 0);
      expect(editor.stand.uebungen, [bank(), seitheben, dips]);

      editor.notifier.verschiebeUebung(1, 0);
      expect(editor.stand.uebungen, [seitheben, bank(), dips]);

      final vorher = editor.stand;
      editor.notifier.verschiebeUebung(1, 1);
      expect(
        editor.stand,
        vorher,
        reason: 'An dieselbe Stelle schieben ist keine Änderung',
      );
    });

    editorTest('Sätze und Wiederholungsbereich: der Stand trägt sie, und die '
        'Schätzung rechnet neu', (tester) async {
      final basis = editorBasis();
      final editor = await oeffneEditor(
        basis.container,
        const GymEditorQuelle.neu(),
      );
      editor.notifier.fuegeUebungHinzu('benchPress');

      editor.notifier.setzeUmfang('benchPress', saetze: 10);
      expect(editor.stand.uebungen, [bank(sets: 10)]);
      expect(editor.stand.schaetzung, 30);

      editor.notifier.setzeUmfang('benchPress', saetze: 3, wdhVon: 5, wdhBis: 7);
      expect(editor.stand.uebungen, [bank(sets: 3, low: 5, high: 7)]);
      expect(editor.stand.schaetzung, 10);

      editor.notifier.setzeUmfang('benchPress', wdhBis: 9);
      expect(
        editor.stand.uebungen,
        [bank(sets: 3, low: 5, high: 9)],
        reason: 'Was nicht genannt ist, bleibt',
      );
    });

    editorTest('`geaendert` vergleicht den Inhalt: ändern und zurückändern '
        'heißt nichts geändert', (tester) async {
      final basis = editorBasis();
      final editor = await oeffneEditor(
        basis.container,
        const GymEditorQuelle.neu(),
      );

      editor.notifier.setzeName('A');
      expect(editor.stand.geaendert, isTrue);
      editor.notifier.setzeName('');
      expect(editor.stand.geaendert, isFalse, reason: 'Name zurück');

      editor.notifier.fuegeUebungHinzu('dips');
      expect(editor.stand.geaendert, isTrue);
      editor.notifier.entferneUebung('dips');
      expect(editor.stand.geaendert, isFalse, reason: 'Übung zurück');

      editor.notifier.fuegeTagHinzu('Home');
      expect(editor.stand.geaendert, isTrue);
      editor.notifier.entferneTag('Home');
      expect(editor.stand.geaendert, isFalse, reason: 'Tag zurück');

      editor.notifier.setzeDauer(55);
      expect(editor.stand.geaendert, isTrue);
      editor.notifier.dauerZuruecksetzen();
      expect(editor.stand.geaendert, isFalse, reason: 'Dauer zurück');
    });
  });

  group('Tags (Spec 9.3, 5.6)', () {
    editorTest('ein Tag wird normalisiert, doppelte — ohne Beachtung der '
        'Schreibweise — bleiben draußen', (tester) async {
      final basis = editorBasis();
      final editor = await oeffneEditor(
        basis.container,
        const GymEditorQuelle.neu(),
      );

      editor.notifier.fuegeTagHinzu('  Home   zuhause ');
      expect(editor.stand.tags, ['Home zuhause']);

      editor.notifier.fuegeTagHinzu('HOME ZUHAUSE');
      expect(editor.stand.tags, ['Home zuhause']);

      editor.notifier.fuegeTagHinzu('   ');
      expect(editor.stand.tags, ['Home zuhause'], reason: 'leer ist kein Tag');
    });

    editorTest('Obergrenzen: höchstens fünf Tags, je höchstens 20 Zeichen', (
      tester,
    ) async {
      final basis = editorBasis();
      final editor = await oeffneEditor(
        basis.container,
        const GymEditorQuelle.neu(),
      );

      for (final tag in ['Eins', 'Zwei', 'Drei', 'Vier', 'Fünf', 'Sechs']) {
        editor.notifier.fuegeTagHinzu(tag);
      }
      expect(editor.stand.tags, ['Eins', 'Zwei', 'Drei', 'Vier', 'Fünf']);

      editor.notifier.entferneTag('Zwei');
      editor.notifier.fuegeTagHinzu('ein Tag mit einundzwanzig Zeichen');
      expect(
        editor.stand.tags,
        ['Eins', 'Drei', 'Vier', 'Fünf'],
        reason: 'Ein zu langer Tag wird nicht angenommen',
      );
      expect(editor.stand.probleme.whereType<TagInvalid>(), isEmpty);
      expect(editor.stand.probleme.whereType<TooManyTags>(), isEmpty);
    });

    editorTest('Entfernen findet den Tag ohne Beachtung der Schreibweise', (
      tester,
    ) async {
      final basis = editorBasis();
      final editor = await oeffneEditor(
        basis.container,
        const GymEditorQuelle.neu(),
      );
      editor.notifier
        ..fuegeTagHinzu('Home')
        ..fuegeTagHinzu('Gym');

      editor.notifier.entferneTag('HOME');

      expect(editor.stand.tags, ['Gym']);
    });
  });

  group('Dauer (Spec 9.3, Tim 19.11.2026)', () {
    editorTest('geschätzt, überschreibbar, zurücksetzbar — die Schätzung '
        'rechnet daneben weiter', (tester) async {
      final basis = editorBasis();
      final editor = await oeffneEditor(
        basis.container,
        const GymEditorQuelle.neu(),
      );
      editor.notifier
        ..fuegeUebungHinzu('benchPress')
        ..fuegeUebungHinzu('lateralRaise');
      expect(editor.stand.dauerEingetragen, isNull);
      expect(editor.stand.schaetzung, 20);

      editor.notifier.setzeDauer(55);
      expect(editor.stand.dauerEingetragen, 55);
      expect(editor.stand.schaetzung, 20, reason: 'die Schätzung bleibt daneben');

      editor.notifier.fuegeUebungHinzu('dips');
      expect(
        editor.stand.dauerEingetragen,
        55,
        reason: 'Eine eingetragene Dauer wird nicht nachgerechnet (9.3)',
      );
      expect(editor.stand.schaetzung, 25);

      editor.notifier.dauerZuruecksetzen();
      expect(editor.stand.dauerEingetragen, isNull);
      expect(editor.stand.schaetzung, 25);
    });

    editorTest('ohne Übung gibt es keine Schätzung — `null`, nie 0', (
      tester,
    ) async {
      final basis = editorBasis();
      final editor = await oeffneEditor(
        basis.container,
        const GymEditorQuelle.neu(),
      );

      expect(editor.stand.schaetzung, isNull);
      editor.notifier.fuegeUebungHinzu('benchPress');
      expect(editor.stand.schaetzung, 10);
      editor.notifier.entferneUebung('benchPress');
      expect(editor.stand.schaetzung, isNull);
    });

    editorTest('eingetragene Minuten außerhalb von 1 bis 600 nennt '
        '`probleme`', (tester) async {
      final basis = editorBasis();
      final editor = await oeffneEditor(
        basis.container,
        const GymEditorQuelle.neu(),
      );
      editor.notifier
        ..setzeName('Zuhause')
        ..fuegeUebungHinzu('benchPress');
      expect(editor.stand.probleme, isEmpty);

      editor.notifier.setzeDauer(601);

      expect(editor.stand.probleme, [const MinutesOutOfRange()]);
    });
  });

  group('Namen und Regeln (Spec 5.2, 9.6)', () {
    editorTest('ein Name über 60 Zeichen nennt `NameTooLong`', (tester) async {
      final basis = editorBasis();
      final editor = await oeffneEditor(
        basis.container,
        const GymEditorQuelle.neu(),
      );
      editor.notifier.fuegeUebungHinzu('benchPress');

      editor.notifier.setzeName('x' * 61);
      expect(editor.stand.probleme, [const NameTooLong()]);

      editor.notifier.setzeName('x' * 60);
      expect(editor.stand.probleme, isEmpty);
    });

    editorTest('ein Name aus Leerzeichen ist kein Name', (tester) async {
      final basis = editorBasis();
      final editor = await oeffneEditor(
        basis.container,
        const GymEditorQuelle.neu(),
      );
      editor.notifier.fuegeUebungHinzu('benchPress');

      editor.notifier.setzeName('    ');

      expect(editor.stand.probleme, [const NameEmpty()]);
    });

    editorTest('Name und eine Übung genügen: `probleme` ist leer', (
      tester,
    ) async {
      final basis = editorBasis();
      final editor = await oeffneEditor(
        basis.container,
        const GymEditorQuelle.neu(),
      );

      editor.notifier
        ..setzeName('Zuhause kurz')
        ..fuegeUebungHinzu('benchPress');

      expect(editor.stand.probleme, isEmpty);
    });
  });

  group('Quelle `kopie` (Spec 4.5, 9.1)', () {
    const templateName = 'Push — Brust, Schultern, Trizeps';

    editorTest('der unberührte Stand ist die Kopie: Name „… (Kopie)", '
        'Tags, Übungen, eingetragene Dauer des Templates', (tester) async {
      final basis = editorBasis();
      final editor = await oeffneEditor(
        basis.container,
        const GymEditorQuelle.kopie('Push'),
      );

      final push = WorkoutTemplates.byId('Push')!;
      final s = editor.stand;
      expect(s.laedt, isFalse);
      expect(s.name, 'Push (Kopie)');
      expect(s.tags, ['Gym']);
      expect(s.uebungen, push.exercises);
      expect(s.uebungen, hasLength(7));
      expect(s.dauerEingetragen, 70);
      expect(
        s.schaetzung,
        55,
        reason: 'die Schätzung der Formel liegt bei 55 (Plan, Kopf)',
      );
      expect(s.kopieVon, templateName);
      expect(s.geaendert, isFalse, reason: 'der Ausgang ist die Kopie');
      expect(s.probleme, isEmpty);
    });

    editorTest('eine Änderung und ihre Rücknahme: wieder nichts geändert', (
      tester,
    ) async {
      final basis = editorBasis();
      final editor = await oeffneEditor(
        basis.container,
        const GymEditorQuelle.kopie('Push'),
      );

      editor.notifier.setzeName('Push — meine Fassung');
      expect(editor.stand.geaendert, isTrue);
      editor.notifier.setzeName('Push (Kopie)');
      expect(editor.stand.geaendert, isFalse);

      editor.notifier.entferneUebung('lateralRaise');
      expect(editor.stand.uebungen, hasLength(6));
      expect(editor.stand.geaendert, isTrue);
      expect(editor.stand.dauerEingetragen, 70);
    });

    editorTest('die Kopie legt beim Öffnen nichts an und fasst das Template '
        'nicht an', (tester) async {
      final basis = editorBasis();
      final vorher = await abbild(basis.db, 'Push');
      final trainingenVorher = await anzahl(basis.db, 'gym_trainings');

      final editor = await oeffneEditor(
        basis.container,
        const GymEditorQuelle.kopie('Push'),
      );
      editor.notifier.setzeName('Push — meine Fassung');
      await tester.pump(const Duration(milliseconds: 100));

      expect(await anzahl(basis.db, 'gym_trainings'), trainingenVorher);
      expect(await abbild(basis.db, 'Push'), vorher);
    });
  });

  group('Quelle `bearbeite` (Spec 9.2, 22 Nr. 3)', () {
    Future<EditorBasis> mitEigenem({int? minuten = 45}) async {
      final basis = editorBasis();
      await basis.repo.speichere(
        eigenes(
          'E-1',
          name: 'Kurzhantel zuhause',
          tags: ['Home'],
          enteredMinutes: minuten,
        ),
      );
      return basis;
    }

    editorTest('der Ausgang ist das gespeicherte Training', (tester) async {
      final basis = await mitEigenem();
      final editor = await oeffneEditor(
        basis.container,
        const GymEditorQuelle.bearbeite('E-1'),
      );

      final s = editor.stand;
      expect(s.laedt, isFalse);
      expect(s.name, 'Kurzhantel zuhause');
      expect(s.tags, ['Home']);
      expect(s.uebungen, [bank(), seitheben]);
      expect(s.dauerEingetragen, 45);
      expect(s.schaetzung, 20);
      expect(s.kopieVon, isNull);
      expect(s.geaendert, isFalse);
      expect(s.probleme, isEmpty);
    });

    editorTest('ohne eingetragene Dauer steht sie als `null`, die '
        'Schätzung daneben', (tester) async {
      final basis = await mitEigenem(minuten: null);
      final editor = await oeffneEditor(
        basis.container,
        const GymEditorQuelle.bearbeite('E-1'),
      );

      expect(editor.stand.dauerEingetragen, isNull);
      expect(editor.stand.schaetzung, 20);
    });

    editorTest('ein vorhandener Zwischenstand wird wieder aufgenommen — und '
        'ist eine Änderung gegen das Training', (tester) async {
      final basis = await mitEigenem();
      await basis.repo.speichereZwischenstand(
        eigenes(
          'ZW-ALT',
          name: 'Halb geändert',
          tags: ['Home', 'Kurz'],
          exercises: [bank(), seitheben, dips],
          enteredMinutes: 45,
          isDraft: true,
        ),
        von: 'E-1',
      );

      final editor = await oeffneEditor(
        basis.container,
        const GymEditorQuelle.bearbeite('E-1'),
      );

      expect(editor.stand.name, 'Halb geändert');
      expect(editor.stand.tags, ['Home', 'Kurz']);
      expect(editor.stand.uebungen, [bank(), seitheben, dips]);
      expect(
        editor.stand.geaendert,
        isTrue,
        reason: 'Der Ausgang ist das Training, nicht der Zwischenstand',
      );
    });

    editorTest('Ändern und Zurückändern heißt nichts geändert', (tester) async {
      final basis = await mitEigenem();
      final editor = await oeffneEditor(
        basis.container,
        const GymEditorQuelle.bearbeite('E-1'),
      );

      editor.notifier.setzeName('Anders');
      editor.notifier.entferneUebung('lateralRaise');
      editor.notifier.fuegeTagHinzu('Kurz');
      expect(editor.stand.geaendert, isTrue);

      editor.notifier.setzeName('Kurzhantel zuhause');
      editor.notifier.fuegeUebungHinzu('lateralRaise');
      editor.notifier.entferneTag('Kurz');

      expect(editor.stand.uebungen, [bank(), seitheben]);
      expect(editor.stand.geaendert, isFalse);
    });

    editorTest('Verschieben und Zurückverschieben heißt nichts geändert', (
      tester,
    ) async {
      final basis = await mitEigenem();
      final editor = await oeffneEditor(
        basis.container,
        const GymEditorQuelle.bearbeite('E-1'),
      );

      editor.notifier.verschiebeUebung(0, 1);
      expect(editor.stand.uebungen, [seitheben, bank()]);
      expect(editor.stand.geaendert, isTrue);

      editor.notifier.verschiebeUebung(1, 0);
      expect(editor.stand.uebungen, [bank(), seitheben]);
      expect(editor.stand.geaendert, isFalse);
    });

    editorTest('eingetragene Dauer ändern und zurückändern: nichts '
        'geändert', (tester) async {
      final basis = await mitEigenem();
      final editor = await oeffneEditor(
        basis.container,
        const GymEditorQuelle.bearbeite('E-1'),
      );

      editor.notifier.setzeDauer(60);
      expect(editor.stand.geaendert, isTrue);
      editor.notifier.setzeDauer(45);
      expect(editor.stand.geaendert, isFalse);

      editor.notifier.dauerZuruecksetzen();
      expect(editor.stand.dauerEingetragen, isNull);
      expect(
        editor.stand.geaendert,
        isTrue,
        reason: 'Der Ausgang trägt 45 Minuten; „keine eigene Dauer" ist anders',
      );
    });
  });

  group('Quelle `entwurf` (Spec 9.2, 9.6)', () {
    editorTest('ein unfertiger Entwurf wird so gelesen, wie er liegt — und '
        'der Grund nennt, was fehlt', (tester) async {
      final basis = editorBasis();
      await basis.repo.speichere(
        eigenes('D-1', name: '', tags: [], exercises: [], isDraft: true),
      );

      final editor = await oeffneEditor(
        basis.container,
        const GymEditorQuelle.entwurf('D-1'),
      );

      expect(editor.stand.name, '');
      expect(editor.stand.uebungen, isEmpty);
      expect(editor.stand.geaendert, isFalse);
      expect(
        editor.stand.probleme,
        unorderedEquals(<WorkoutProblem>[const NameEmpty(), const NoExercises()]),
      );
    });

    editorTest('ein vollständiger Entwurf ist speicherbar: `probleme` ist '
        'leer', (tester) async {
      final basis = editorBasis();
      await basis.repo.speichere(
        eigenes(
          'D-1',
          name: 'Oberkörper kurz',
          tags: ['Home'],
          exercises: [bank(), seitheben],
          isDraft: true,
        ),
      );

      final editor = await oeffneEditor(
        basis.container,
        const GymEditorQuelle.entwurf('D-1'),
      );

      expect(editor.stand.name, 'Oberkörper kurz');
      expect(editor.stand.tags, ['Home']);
      expect(editor.stand.uebungen, [bank(), seitheben]);
      expect(editor.stand.probleme, isEmpty);
      expect(editor.stand.geaendert, isFalse);
    });
  });

  group('Lädt (Fehler `01`)', () {
    Future<EditorBasis> mitAllem() async {
      final basis = editorBasis();
      await basis.repo.speichere(
        eigenes('E-1', name: 'Kurzhantel zuhause', tags: ['Home']),
      );
      await basis.repo.speichere(
        eigenes(
          'D-1',
          name: 'Oberkörper kurz',
          tags: ['Home'],
          exercises: [bank()],
          isDraft: true,
        ),
      );
      return basis;
    }

    final fall = <String, GymEditorQuelle>{
      'kopie': const GymEditorQuelle.kopie('Push'),
      'bearbeite': const GymEditorQuelle.bearbeite('E-1'),
      'entwurf': const GymEditorQuelle.entwurf('D-1'),
    };

    for (final eintrag in fall.entries) {
      editorTest('${eintrag.key}: solange gelesen wird, steht kein Grund da '
          'und der Stand ist nicht „leeres Training"', (tester) async {
        final basis = await mitAllem();
        final tor = halteLesen(basis.repo);
        final editor = EditorHandle(basis.container, eintrag.value);

        final s = editor.stand;
        expect(s.laedt, isTrue);
        expect(
          s.probleme,
          isEmpty,
          reason:
              'Aus nichts Gelesenem folgt kein Grund: „keine Übung" wäre '
              'gelogen (Fehler `01`)',
        );
        expect(s.geaendert, isFalse);

        tor.complete();
        await editor.notifier.bereit;

        expect(editor.stand.laedt, isFalse);
        expect(editor.stand.name, isNotEmpty);
      });

      editorTest('${eintrag.key}: Eingaben während des Lesens werden nicht '
          'angenommen — sie würden überschrieben', (tester) async {
        final basis = await mitAllem();
        final tor = halteLesen(basis.repo);
        final editor = EditorHandle(basis.container, eintrag.value);
        expect(editor.stand.laedt, isTrue);

        editor.notifier
          ..setzeName('Zu früh getippt')
          ..fuegeTagHinzu('Zufrüh')
          ..fuegeUebungHinzu('dips');
        tor.complete();
        await editor.notifier.bereit;

        expect(editor.stand.name, isNot('Zu früh getippt'));
        expect(editor.stand.tags, isNot(contains('Zufrüh')));
        expect(editor.stand.uebungen.map((u) => u.exerciseId),
            isNot(contains('dips')));
        expect(editor.stand.geaendert, isFalse);
      });
    }
  });

  group('`autoDispose`: nichts überlebt das Schließen (Spec 9.2)', () {
    editorTest('ein neu geöffneter Editor beginnt leer, auch nach einem '
        'geänderten', (tester) async {
      final basis = editorBasis();
      final erster = await oeffneEditor(
        basis.container,
        const GymEditorQuelle.neu(),
      );
      erster.notifier
        ..setzeName('Verloren')
        ..fuegeUebungHinzu('dips');
      erster.schliesse();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final zweiter = await oeffneEditor(
        basis.container,
        const GymEditorQuelle.neu(),
      );

      expect(zweiter.stand.name, '');
      expect(zweiter.stand.uebungen, isEmpty);
      expect(zweiter.stand.geaendert, isFalse);
    });

    editorTest('solange der Editor offen ist, überlebt der Stand: Lesen von '
        'außen ändert ihn nicht', (tester) async {
      final basis = editorBasis();
      final editor = await oeffneEditor(
        basis.container,
        const GymEditorQuelle.neu(),
      );
      editor.notifier.setzeName('Bleibt');

      await tester.pump(const Duration(milliseconds: 200));
      final zweiterLeser = basis.container.read(
        gymEditorProvider(const GymEditorQuelle.neu()),
      );

      expect(zweiterLeser.name, 'Bleibt');
    });
  });

  group('Gescheiterte Ablage (Spec 6.1)', () {
    editorTest('scheitert das Speichern, bleibt der Stand — nichts geht '
        'verloren', (tester) async {
      final basis = editorBasis();
      final editor = await oeffneEditor(
        basis.container,
        const GymEditorQuelle.neu(),
      );
      editor.notifier
        ..setzeName('Zuhause kurz')
        ..fuegeUebungHinzu('benchPress');
      basis.repo.speichereScheitert = true;
      final vorher = editor.stand;

      final ergebnis = await editor.notifier.speichere();

      expect(ergebnis, GymEditorErgebnis.fehlgeschlagen);
      expect(editor.stand, vorher);
      expect(editor.stand.geaendert, isTrue);
    });
  });

  group('Nicht speicherbar (Spec 9.6)', () {
    editorTest('`speichere` bei nicht leerem `probleme` schreibt nichts '
        'Fertiges und meldet es', (tester) async {
      final basis = editorBasis();
      final editor = await oeffneEditor(
        basis.container,
        const GymEditorQuelle.neu(),
      );
      editor.notifier.setzeName('Nur ein Name');

      final ergebnis = await editor.notifier.speichere();

      expect(ergebnis, GymEditorErgebnis.nichtSpeicherbar);
      expect(
        await anzahl(basis.db, 'gym_trainings', 'ist_entwurf = 0 AND '
            "kategorie = 'eigene'"),
        0,
      );
      expect(editor.stand.name, 'Nur ein Name');
    });

    editorTest('ein ganz leerer Editor: nicht speicherbar', (tester) async {
      final basis = editorBasis();
      final editor = await oeffneEditor(
        basis.container,
        const GymEditorQuelle.neu(),
      );

      expect(
        await editor.notifier.speichere(),
        GymEditorErgebnis.nichtSpeicherbar,
      );
      expect(await eigeneZeilen(basis.db), isEmpty);
    });
  });
}
