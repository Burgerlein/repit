import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/data/gym_repository.dart';
import 'package:repit/data/gym_training_repository.dart';
import 'package:repit/gym/gym_editor_provider.dart';
import 'package:repit/gym/gym_fortschritt_provider.dart';
import 'package:repit/gym/gym_log_schluessel.dart';
import 'package:repit/gym/gym_log_view.dart';
import 'package:repit/gym/gym_verlauf_schluessel.dart';
import 'package:repit/gym/uebungsbilder.dart';
import 'package:repit/gym/uebungsbilder_provider.dart';
import 'package:repit/health/health_provider.dart'
    show appCacheProvider, clockProvider;
import 'package:repit/uebernahme/trainingsexport_uebernahme.dart';

import 'gym_editor_support.dart';
import 'verlauf_support.dart'
    show verlaufTest, zeigeVerlauf, verstreiche, verlaufJetzt;

/// Eine Exportdatei als Bytes, wie `uebernimmTrainingsexport` sie liest.
Uint8List utf8BytesVon(Map<String, Object?> inhalt) =>
    Uint8List.fromList(utf8.encode(jsonEncode(inhalt)));

/// Eine **Bibliotheksübung** in Editor, Erfassung, Verlauf und Fortschritt
/// (#551, Spec 8.2, 8.3, 12.3; Plan Task 3.2): Jede Stelle der App, die eine
/// Übung nach ID auflöst, löst über `ExerciseLibrary` auf — nicht mehr über
/// den Katalog der 33. Der Kern tut es schon (Scheibe 2); hier steht, was die
/// **App** daraus machen muss.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden. Hält der
/// Implementierende eine Erwartung für falsch, wird das gemeldet, nicht
/// korrigiert.
///
/// Die Beispiel-Übung ist `squat` (erzeugt, Hauptmuskeln Gesäß und
/// Oberschenkel vorne) — ihre Werte kommen aus `ExerciseLibrary`, nicht als
/// Literal abgetippt: Geprüft wird, dass die App die Bibliothek benutzt,
/// nicht welche Zahl der Generator vergeben hat. Alle Daten sind erfunden.
void main() {
  const idSquat = 'squat';
  final squat = ExerciseLibrary.byId(idSquat)!;

  group('Der Editor (Spec 8.2: `fuegeUebungHinzu` ist der Weg hinein)', () {
    editorTest('`fuegeUebungHinzu` fügt eine Bibliotheksübung ein, vorbelegt '
        'aus der Bibliothek — heute tut der Aufruf nichts', (tester) async {
      final basis = editorBasis();
      final editor = await oeffneEditor(
        basis.container,
        const GymEditorQuelle.neu(),
      );

      editor.notifier.fuegeUebungHinzu(idSquat);

      expect(
        editor.stand.uebungen.map((e) => e.exerciseId),
        [idSquat],
        reason:
            'Die Auswahl bietet die Bibliothek an — eine gewählte Übung, '
            'die nicht ankommt, wäre ein stilles Nichts (Spec 8.2)',
      );
      final e = editor.stand.uebungen.single;
      expect(e.sets, squat.sets, reason: 'vorbelegt aus der Bibliothek');
      expect(e.repLow, squat.repLow);
      expect(e.repHigh, squat.repHigh);
    });

    editorTest('eine ID, die auch die Bibliothek nicht kennt, bleibt '
        'wirkungslos', (tester) async {
      final basis = editorBasis();
      final editor = await oeffneEditor(
        basis.container,
        const GymEditorQuelle.neu(),
      );

      editor.notifier.fuegeUebungHinzu('gibt-es-nicht');

      expect(editor.stand.uebungen, isEmpty);
    });

    editorTest('die Dauer rechnet die Bibliotheksübung mit', (tester) async {
      final basis = editorBasis();
      final editor = await oeffneEditor(
        basis.container,
        const GymEditorQuelle.neu(),
      );

      editor.notifier.fuegeUebungHinzu(idSquat);

      expect(
        editor.stand.schaetzung,
        isNotNull,
        reason:
            'Eine Übung, die die Schätzung nicht kennt, trüge nichts bei — '
            'die Bibliothek kennt sie (Spec 8.1, `WorkoutDuration`)',
      );
      expect(editor.stand.schaetzung, greaterThan(0));
    });

    editorTest('die Muskelfigur-Quelle färbt: `WorkoutMuscles.trained` kennt '
        'die Bibliotheksübung', (tester) async {
      final basis = editorBasis();
      const quelle = GymEditorQuelle.neu();
      final editor = await oeffneEditor(basis.container, quelle);
      final abo = basis.container.listen(
        gymEditorMuskelnProvider(quelle),
        (_, _) {},
      );
      addTearDown(abo.close);

      editor.notifier.fuegeUebungHinzu(idSquat);

      expect(
        basis.container.read(gymEditorMuskelnProvider(quelle)),
        containsAll([Muscle.glutes, Muscle.quads]),
        reason:
            'Spec 8.1: „hier würde eine neue Übung die Muskelkarte nicht '
            'färben" — genau das darf nicht passieren',
      );
    });

    editorTest('ein Training mit einer Bibliotheksübung ist speicherbar', (
      tester,
    ) async {
      final basis = editorBasis();
      final editor = await oeffneEditor(
        basis.container,
        const GymEditorQuelle.neu(),
      );

      editor.notifier
        ..setzeName('Beine kurz')
        ..fuegeUebungHinzu(idSquat);

      expect(
        editor.stand.probleme,
        isEmpty,
        reason: '`WorkoutRules.check` kennt die Bibliothek (Spec 8.1)',
      );
      expect(await editor.notifier.speichere(), GymEditorErgebnis.gespeichert);
      expect(await zeileVon(basis.db, neueKennung), isNotNull);
      expect(await uebungenInDatei(basis.db, neueKennung), contains(idSquat));
    });
  });

  group('Export und Import (Spec 8.1: `trainings_export`)', () {
    test('eine Sitzung mit einer Bibliotheksübung läuft durch — sie ist '
        'keine „unbekannte Übung"', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      // Eine Exportdatei im echten Format, alle Werte erfunden.
      final bytes = utf8BytesVon({
        'format': TrainingsExport.formatName,
        'version': TrainingsExport.currentVersion,
        'generated': '2026-03-02T10:00:00Z',
        'timezone': 'Europe/Berlin',
        'app': {
          'sessions': [
            {
              'id': 'EXPORT-S1',
              'date': '2026-03-02T09:00:00Z',
              'minutes': 40,
              'exercises': [
                {
                  'exerciseID': idSquat,
                  'sets': [
                    {'weight': 60, 'reps': 8},
                  ],
                },
              ],
            },
          ],
        },
      });

      final ergebnis = await uebernimmTrainingsexport(GymRepository(db), bytes);

      expect(ergebnis, isA<TrainingsexportUebernommen>());
      final uebernommen = ergebnis as TrainingsexportUebernommen;
      expect(
        uebernommen.unbekannteUebungen,
        isEmpty,
        reason:
            'Spec 8.1: „eine ID der Bibliothek wäre sonst unbekannt" — '
            'genau diese Stelle',
      );
      expect(uebernommen.geschrieben, hasLength(1));

      final gelesen = await GymRepository(db).sitzungen();
      expect(gelesen.single.exercises.single.exerciseId, idSquat);
    });

    test('eine wirklich unbekannte ID bleibt, was sie war: benannt, nicht '
        'verworfen (Spec 8.4)', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      final bytes = utf8BytesVon({
        'format': TrainingsExport.formatName,
        'version': TrainingsExport.currentVersion,
        'generated': '2026-03-02T10:00:00Z',
        'timezone': 'Europe/Berlin',
        'app': {
          'sessions': [
            {
              'id': 'EXPORT-S2',
              'date': '2026-03-03T09:00:00Z',
              'exercises': [
                {
                  'exerciseID': 'gibt-es-nicht',
                  'sets': [
                    {'weight': 10, 'reps': 8},
                  ],
                },
              ],
            },
          ],
        },
      });

      final ergebnis = await uebernimmTrainingsexport(GymRepository(db), bytes);

      expect(ergebnis, isA<TrainingsexportUebernommen>());
      expect(
        (ergebnis as TrainingsexportUebernommen).unbekannteUebungen,
        ['gibt-es-nicht'],
      );
    });
  });

  group('Die Erfassung öffnet ein Training mit einer Bibliotheksübung '
      '(Spec 8.2, 12.3)', () {
    final jetzt = DateTime.utc(2026, 3, 9, 9);

    /// Ein eigenes Training mit [uebungen] in der Ablage, und die Erfassung
    /// darüber als App. Keine „Unbekannte Übung", nirgends.
    Future<(ProviderContainer, Widget)> erfassung(
      List<WorkoutExercise> uebungen,
    ) async {
      final db = neueDb();
      await GymTrainingRepository(db).speichere(
        WorkoutDefinition(
          id: 'E-1',
          name: 'Beine kurz',
          category: WorkoutCategory.own,
          tags: const ['Home'],
          exercises: uebungen,
        ),
      );
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          appCacheProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(() => jetzt),
          uebungsbilderProvider.overrideWithValue(Uebungsbilder.leer),
        ],
      );
      addTearDown(container.dispose);
      final app = UncontrolledProviderScope(
        container: container,
        child: CupertinoApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(padding: const EdgeInsets.only(top: 47, bottom: 34)),
            child: child!,
          ),
          home: const GymLogView(workout: CustomTrainingKey('E-1')),
        ),
      );
      return (container, app);
    }

    Future<void> zeige(WidgetTester tester, Widget app) async {
      tester.view.physicalSize = const Size(402, 8000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(app);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    /// Wie `editorTest`: Offene Zeitgeber (der 1,5-s-Zwischenstand) laufen
    /// im `finally` ab, sonst endet jeder Fall mit „A Timer is still
    /// pending".
    void erfassungsTest(
      String name,
      Future<void> Function(WidgetTester tester) body,
    ) => testWidgets(name, (tester) async {
      try {
        await body(tester);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 2));
        await tester.pump();
      }
    });

    String alleTexte(WidgetTester tester) => tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
        .join(' ');

    erfassungsTest('die Karte steht da — Name aus der Bibliothek, '
        'Satzzeilen nach Vorgabe, keine „Unbekannte Übung"', (tester) async {
      final (_, app) = await erfassung([
        WorkoutExercise.fromCatalog(squat),
      ]);
      await zeige(tester, app);

      expect(
        find.byKey(kGymUebung(idSquat)),
        findsOneWidget,
        reason:
            'Heute filtert die Erfassung die Übung still heraus — eine '
            'eingetragene Übung, die nicht erscheint, ist verlorene Arbeit',
      );
      expect(
        find.descendant(
          of: find.byKey(kGymUebung(idSquat)),
          matching: find.text(squat.name),
        ),
        findsWidgets,
        reason: 'der Name aus der Bibliothek, nicht die rohe ID',
      );
      for (var n = 1; n <= squat.sets; n++) {
        expect(
          find.byKey(kGymFeldWdh(idSquat, n)),
          findsOneWidget,
          reason: 'Satzzeile $n',
        );
      }
      expect(alleTexte(tester), isNot(contains('Unbekannte Übung')));
    });

    erfassungsTest('der Kopf zählt die Bibliotheksübung mit', (tester) async {
      final (_, app) = await erfassung([
        WorkoutExercise.fromCatalog(ExerciseCatalog.all['benchPress']!),
        WorkoutExercise.fromCatalog(squat),
      ]);
      await zeige(tester, app);

      expect(
        find.textContaining('2 Übungen'),
        findsWidgets,
        reason:
            'Der Kopf zählt über die Bibliothek — heute zählt er nur die '
            'Katalogübung und sagt „1 Übungen"',
      );
    });

    erfassungsTest('das Vollbild zeigt sie — mit Namen', (tester) async {
      final (_, app) = await erfassung([
        WorkoutExercise.fromCatalog(squat),
      ]);
      await zeige(tester, app);

      await tester.tap(find.byKey(kGymLogVollbildOeffnen));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Ein frisches Training öffnet auf der Aufwärm-Seite (Spec #40,
      // bewacht von gym_log_vollbild_aufwaermen_test) — erst weiterblättern,
      // dann steht die Übungsseite im Baum.
      await tester.tap(find.byKey(kGymVollbildWeiter));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byKey(kGymVollbild), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(kGymVollbild),
          matching: find.text(squat.name),
        ),
        findsWidgets,
      );
      expect(alleTexte(tester), isNot(contains('Unbekannte Übung')));
    });
  });

  group('Die Verlauf-Karte (Spec 8.2: `gym_verlauf_karte`)', () {
    verlaufTest('nennt den Namen aus der Bibliothek, nicht die rohe ID', (
      tester,
      h,
    ) async {
      await h.fuelle([
        ImportedSession(
          id: 'S1',
          date: verlaufJetzt.subtract(const Duration(days: 1)),
          workout: Workout.a,
          minutes: 40,
          note: null,
          exercises: [
            ImportedExercise(
              exerciseId: idSquat,
              sets: const [CompletedSet(weight: 60, reps: 8)],
            ),
          ],
        ),
      ]);
      await zeigeVerlauf(tester, h);

      if (find.byKey(kGymVerlaufInhalt('S1')).evaluate().isEmpty) {
        await tester.tap(find.byKey(kGymVerlaufKopf('S1')));
        await verstreiche(tester);
      }
      expect(find.byKey(kGymVerlaufUebung('S1', idSquat)), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(kGymVerlaufUebung('S1', idSquat)),
          matching: find.text(squat.name),
        ),
        findsWidgets,
        reason:
            'Heute fällt der Name auf die rohe ID zurück '
            '(`gym_verlauf_karte.dart`, Katalog-Lookup)',
      );
      expect(
        find.descendant(
          of: find.byKey(kGymVerlaufUebung('S1', idSquat)),
          matching: find.text(idSquat),
        ),
        findsNothing,
        reason: 'Die rohe ID ist keine Anzeige',
      );
    });
  });

  group('Fortschritt (Spec 8.3: `gymFortschrittProvider` löst über die '
      'Bibliothek auf)', () {
    late AppCache db;
    late ProviderContainer container;

    setUp(() {
      db = AppCache(NativeDatabase.memory());
      container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          appCacheProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(() => DateTime.utc(2026, 3, 9, 9)),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('eine Bibliotheks-ID wirft nicht — der Zustand trägt die Übung', () {
      final abo = container.listen(gymFortschrittProvider(idSquat), (_, _) {});
      addTearDown(abo.close);

      final stand = abo.read();
      expect(stand.uebung.id, idSquat);
      expect(stand.uebung.name, squat.name);
    });

    test('eine ID, die auch die Bibliothek nicht kennt, wirft weiter — '
        'ein Programmierfehler bleibt einer (Spec 8.3)', () {
      expect(
        () => container.read(gymFortschrittProvider('gibt-es-nicht')),
        throwsA(anything),
      );
    });
  });
}
