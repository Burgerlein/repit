import 'dart:convert' show jsonEncode;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show sqlite3;
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/data/gym_repository.dart';
import 'package:repit/data/gym_training_repository.dart';
import 'package:repit/gym/gym_log_provider.dart';
import 'package:repit/gym/gym_log_stand.dart' show GymAbschluss;
import 'package:repit/gym/gym_log_schluessel.dart';
import 'package:repit/health/health_provider.dart'
    show appCacheProvider, clockProvider;

import 'gym_editor_support.dart';
import 'log_support.dart' show verlaufSitzung;
import 'support.dart' show kKarte;

/// Tests für die **Erfassung über `TrainingKey`**: `gymLogProvider` ist eine
/// Familie über den Schlüssel eines Trainings, `Workout` ist einer (#534
/// unter #531, Task 3.1 des Plans `docs/superpowers/plans/2026-11-19-eigene-
/// trainings-plan.md`; Spec 15). Der **Kern-Anteil** (`GymSessionBuilder`,
/// `ImportedSession.trainingId`, `trainingOrder`, `WorkoutTemplates.fromEnum`)
/// ist in `Packages/trainings_core/test/` getestet, die Ablage
/// (`gym_entwuerfe.workout` trägt die Kennung, der Name beim Abschließen)
/// in `app/test/data/gym_trainingsname_test.dart` und
/// `gym_log_trainingsname_test.dart` — **hier steht nur der App-Anteil: die
/// Kette `gymLogProvider` → Ablage → Sitzung**. Die Ablage des Entwurfs mit
/// `trainingId` steht in `app/test/data/gym_entwurf_training_test.dart`.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden. Hält der
/// Implementierende eine Erwartung für falsch, wird das **gemeldet, nicht
/// korrigiert**. Bestehende Tests, die `gymLogProvider(Workout.x)` benutzen,
/// bleiben gültig — das ist die Regel aus Spec 3.1 und hier der erste Fall.
///
/// ## Was die Anforderung bewacht
///
/// - **Spec 3.1/15.1:** `gymLogProvider(Workout.a)` bleibt gültig und liefert
///   **dasselbe wie heute** — auch für `a` bis `d`, obwohl es dafür keine
///   Zeile gibt (Definition aus `WorkoutTemplates.fromEnum`). Für
///   `Workout.push` löst der Schlüssel die **Zeile** auf (Plan 3.1).
/// - **Spec 15.2:** Übungsliste und Reihenfolge, Zeilenzahl je Übung und der
///   Wiederholungsbereich kommen aus der **Definition des Trainings**, nicht
///   aus dem Katalog; die Dauer-Vorbelegung ist `WorkoutDuration.effective`
///   (Templates: die eingetragenen 70/65/70/60 wie heute); die Progression
///   rechnet mit dem **Bereich des Trainings** auf dem **übungsweiten**
///   Verlauf (Spec 17 Nr. 20).
/// - **Spec 4.6/4.7:** Beim Abschließen steht `workout` = die Kennung
///   (die UUID bei einem Training ohne Enum-Fall); der Entwurf der Erfassung
///   trägt dieselbe Kennung, überlebt den Neustart, und **ein Entwurf wird
///   nie unsichtbar** (Tims Gerät ist die einzige Kopie).
/// - **„Ein Entwurf, nicht sieben"** (Tim, 10.11.2026): Die Ablage kennt
///   genau einen Entwurf; läuft ein **eigenes** Training, ist das für jedes
///   andere ein „anderes Training läuft" — nicht „nicht gelesen".
/// - **Spec 27 Nr. 4:** Die Fokus-Karte zeigt einen laufenden Entwurf eines
///   eigenen Trainings **mit dessen Namen** — ein laufendes eigenes Training
///   darf nicht unsichtbar sein, nur weil es keinen Enum-Fall hat.
/// - **Spec 8.3, Plan 3.8:** „Training starten" im Detail ist für ein Eigenes
///   **wirksam**.
///
/// ## Wer hat was entschieden
///
/// - **Entscheidungen von Tim:** Der Verlauf friert ein (18.11.2026); ein
///   Entwurf der Erfassung, nicht sieben (10.11.2026); Push/Pull/Legs als
///   Templates, Gym A–D bleiben Enum-Fälle (19.11.2026, Spec 23).
/// - **Folgerungen aus Spec 15:** alles unter „Was die Anforderung
///   bewacht", außer den Vorschlägen.
/// - **Vorschläge der Spec, hier vorausgesetzt:** Progression mit dem Bereich
///   des Trainings (17 Nr. 20); die Dauer-Vorbelegung als Text der
///   wirksamen Dauer (15.2).
/// - **Festlegungen des Test-Agenten, Tim hat sie nicht gesehen:**
///   - Die Tests erreichen die Erfassung eines eigenen Trainings über den
///     **Schlüssel** `gymLogProvider(CustomTrainingKey(id))` und über „Training
///     starten" im Detail — **nie** über einen Konstruktor von `GymLogView`.
///   - **Gelesen wird nur, was auch bisher öffentlich war:**
///     `GymLogStand.entwurf.uebungen` (`id`, `saetze`), `.dauer`,
///     `.laufendes`, `.hinweis`, `.gespeichertAm` — keine neuen Felder.
///   - **Ein Entwurf der Erfassung für ein eigenes Training zählt als „anderes
///     Training läuft"** gegenüber jedem anderen Schlüssel (und umgekehrt):
///     `GymLogStand.laufendes` ist dann gesetzt, und es wird nichts
///     geschrieben. Wie `GymLaufendes` das Training nennt, ist offen und
///     wird nicht geprüft.
///
/// ## Was hier **nicht** getestet wird, weil die Spec es nicht sagt
///
/// - **`gymLogProvider(CustomTrainingKey(id))` für einen Entwurf des Editors**
///   (`isDraft`) oder für eine Kennung, die es nicht gibt: Die Spec nennt
///   weder einen Fehler noch einen Zustand. Plan 3.1 sagt nur „weder startbar
///   noch einplanbar"; die Schicht ist offen.
/// - **Ein „gelöschtes Push-Template ohne Zeile fällt nicht still auf die
///   Enum-Definition zurück"** (Plan 3.1): Spec 26 Nr. 1 hat das Löschen von
///   Templates abgeschafft; der Fall entsteht nicht mehr.
/// - **Wie die Fokus-Karte ein laufendes eigenes Training zeigt**, außer
///   dem Namen: Aufbau, Knöpfe und Zustand sind Sache der Implementierung
///   (Spec 27 Nr. 4 nennt nur den Namen; `GymDraft`/`GymLaufendes` werden dort
///   additiv um Kennung und Namen erweitert, die Form ist offen).
///
/// **Alle Namen, Zahlen und Zeitpunkte sind erfunden** (Jahr 2099).
void main() {
  final jetzt2099 = DateTime.utc(2099, 3, 9, 9);

  ProviderContainer huelle(AppCache db, {String sitzungsId = 'PRUEF-S1'}) {
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        appCacheProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => jetzt2099),
        gymIdProvider.overrideWithValue(() => sitzungsId),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<GymLogNotifier> oeffneLog(
    ProviderContainer container,
    TrainingKey schluessel,
  ) async {
    // Ein Hörer hält den Stand am Leben, wie der Schirm es täte.
    container.listen(gymLogProvider(schluessel), (_, _) {});
    final notifier = container.read(gymLogProvider(schluessel).notifier);
    await notifier.bereit;
    return notifier;
  }

  List<String> ids(ProviderContainer c, TrainingKey k) => [
    for (final u in c.read(gymLogProvider(k)).entwurf.uebungen) u.id,
  ];

  int satzzeilen(ProviderContainer c, TrainingKey k, String uebung) => c
      .read(gymLogProvider(k))
      .entwurf
      .uebung(uebung)!
      .saetze
      .length;

  // Ein eigenes Training: Reihenfolge Seitheben, Bankdrücken, Dips — weder
  // die des Katalogs noch alphabetisch; Sätze und Bereiche nicht die des
  // Katalogs.
  WorkoutDefinition eigenesTraining({int? minuten}) => WorkoutDefinition(
    id: 'E-1',
    name: 'Zuhause kurz',
    category: WorkoutCategory.own,
    tags: ['Home'],
    exercises: [
      WorkoutExercise(
        exerciseId: 'lateralRaise',
        sets: 2,
        repLow: 12,
        repHigh: 15,
      ),
      WorkoutExercise(
        exerciseId: 'benchPress',
        sets: 3,
        repLow: 5,
        repHigh: 7,
      ),
      WorkoutExercise(exerciseId: 'dips', sets: 5, repLow: 6, repHigh: 12),
    ],
    enteredMinutes: minuten,
  );

  const eigener = CustomTrainingKey('E-1');

  Future<AppCache> dbMitEigenem({int? minuten}) async {
    final db = neueDb();
    await GymTrainingRepository(db).speichere(
      eigenesTraining(minuten: minuten),
    );
    return db;
  }

  group('`Workout` bleibt ein gültiger Schlüssel (Spec 3.1)', () {
    test('Gym A — ohne Zeile in `gym_trainings`: Übungen, Zeilenzahl und '
        'Dauer wie heute', () async {
      final db = neueDb();
      final container = huelle(db);
      expect(await anzahl(db, 'gym_trainings', "id = 'A'"), 0);

      await oeffneLog(container, Workout.a);

      expect(ids(container, Workout.a), [
        'benchPress',
        'inclineDumbbellPress',
        'shoulderPressDumbbell',
        'dips',
        'lateralRaise',
        'overheadTriceps',
        'bicepsCurl',
      ]);
      expect(
        [
          for (final id in ids(container, Workout.a))
            satzzeilen(container, Workout.a, id),
        ],
        [4, 3, 3, 3, 4, 3, 3],
      );
      expect(container.read(gymLogProvider(Workout.a)).entwurf.dauer, '70');
    });

    test('Gym B, C und D: die eingetragene Dauer wie heute — 65, 70, 60', () async {
      final db = neueDb();
      final container = huelle(db);

      for (final (workout, dauer) in [
        (Workout.b, '65'),
        (Workout.c, '70'),
        (Workout.d, '60'),
      ]) {
        await oeffneLog(container, workout);
        expect(
          container.read(gymLogProvider(workout)).entwurf.dauer,
          dauer,
          reason: workout.code,
        );
      }
    });

    test('Push — mit Zeile: der Schlüssel löst die **Zeile** auf, nicht die '
        'Enum-Definition', () async {
      final db = neueDb();
      final container = huelle(db);
      await db.customStatement(
        "DELETE FROM gym_training_uebungen WHERE training_id = 'Push' "
        "AND uebung_id = 'cableFly';",
      );
      await db.customStatement(
        'UPDATE gym_training_uebungen SET saetze = 2 '
        "WHERE training_id = 'Push' AND uebung_id = 'benchPress';",
      );
      await db.customStatement(
        'UPDATE gym_trainings SET dauer_eingetragen_min = 45 '
        "WHERE id = 'Push';",
      );

      await oeffneLog(container, Workout.push);

      expect(ids(container, Workout.push), [
        'benchPress',
        'inclineDumbbellPress',
        'shoulderPressMachine',
        'lateralRaise',
        'tricepsPushdown',
        'overheadTriceps',
      ]);
      expect(satzzeilen(container, Workout.push, 'benchPress'), 2);
      expect(satzzeilen(container, Workout.push, 'lateralRaise'), 4);
      expect(container.read(gymLogProvider(Workout.push)).entwurf.dauer, '45');
    });

    test('derselbe Schlüssel ergibt einen Provider: `Workout.a` und '
        '`TrainingKey.fromId("A")`', () async {
      final db = neueDb();
      final container = huelle(db);

      final a = container.read(gymLogProvider(Workout.a).notifier);
      final ueberKennung = container.read(
        gymLogProvider(TrainingKey.fromId('A')).notifier,
      );

      expect(identical(a, ueberKennung), isTrue);
    });

    test('der Entwurf eines Enum-Trainings steht weiter unter dem Code', () async {
      final db = neueDb();
      final container = huelle(db);
      final notifier = await oeffneLog(container, Workout.a);

      notifier.setzeSatz('benchPress', 0, gewicht: '60', wdh: '8');
      await notifier.schreibeSofort();

      final gespeichert = (await GymRepository(db).entwurf())!;
      expect(gespeichert.workout, Workout.a);
      expect(gespeichert.trainingId, isNull);
      expect(gespeichert.kennung, 'A');
      expect(
        (await zeilen(db, 'gym_entwuerfe')).single['workout'],
        'A',
      );
    });
  });

  group('Ein eigenes Training startet über `CustomTrainingKey` (Spec 15)', () {
    test('derselbe Schlüssel ergibt einen Provider: `CustomTrainingKey` und '
        '`TrainingKey.fromId`', () async {
      final db = await dbMitEigenem();
      final container = huelle(db);

      final a = container.read(gymLogProvider(eigener).notifier);
      final b = container.read(
        gymLogProvider(TrainingKey.fromId('E-1')).notifier,
      );

      expect(identical(a, b), isTrue);
    });

    test('die Übungen stehen in der Reihenfolge des Trainings — nicht des '
        'Katalogs, nicht alphabetisch', () async {
      final db = await dbMitEigenem();
      final container = huelle(db);

      await oeffneLog(container, eigener);

      expect(ids(container, eigener), ['lateralRaise', 'benchPress', 'dips']);
    });

    test('Zeilenzahl je Übung: die Sätze des Trainings, nicht die des '
        'Katalogs', () async {
      final db = await dbMitEigenem();
      final container = huelle(db);

      await oeffneLog(container, eigener);

      expect(satzzeilen(container, eigener, 'lateralRaise'), 2);
      expect(satzzeilen(container, eigener, 'benchPress'), 3);
      expect(satzzeilen(container, eigener, 'dips'), 5);
      expect(container.read(gymLogProvider(eigener)).laedt, isFalse);
    });

    test('die Dauer ist vorbelegt mit der wirksamen Dauer: die geschätzte, '
        'wenn keine eingetragen ist', () async {
      final db = await dbMitEigenem();
      final container = huelle(db);

      await oeffneLog(container, eigener);

      expect(
        container.read(gymLogProvider(eigener)).entwurf.dauer,
        '25',
        reason: 'WorkoutDuration.effective ohne eingetragene Minuten',
      );
    });

    test('die Dauer ist vorbelegt mit der eingetragenen, wenn es eine gibt', () async {
      final db = await dbMitEigenem(minuten: 55);
      final container = huelle(db);

      await oeffneLog(container, eigener);

      expect(container.read(gymLogProvider(eigener)).entwurf.dauer, '55');
    });

    test('das Training lädt: bis die Ablage geantwortet hat, steht `laedt` '
        'und keine Eingabe wird angenommen', () async {
      final db = await dbMitEigenem();
      final container = huelle(db);
      container.listen(gymLogProvider(eigener), (_, _) {});

      final notifier = container.read(gymLogProvider(eigener).notifier);
      expect(container.read(gymLogProvider(eigener)).laedt, isTrue);
      notifier.setzeSatz('benchPress', 0, gewicht: '60', wdh: '5');
      await notifier.bereit;

      expect(container.read(gymLogProvider(eigener)).laedt, isFalse);
      expect(
        container
            .read(gymLogProvider(eigener))
            .entwurf
            .uebung('benchPress')!
            .saetze
            .first
            .reps,
        '',
        reason: 'Eingaben während des Lesens werden nicht angenommen',
      );
    });
  });

  group('Der Entwurf der Erfassung trägt die Kennung (Spec 4.7)', () {
    testWidgets('nach 1,5 Sekunden steht er unter der UUID, ohne Enum-Fall', (
      tester,
    ) async {
      final db = await dbMitEigenem();
      final container = huelle(db);
      final notifier = await oeffneLog(container, eigener);

      notifier.setzeSatz('benchPress', 0, gewicht: '60', wdh: '5');
      await tester.pump(const Duration(milliseconds: 1400));
      expect(await GymRepository(db).entwurf(), isNull);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();

      final gespeichert = (await GymRepository(db).entwurf())!;
      expect(gespeichert.workout, isNull);
      expect(gespeichert.trainingId, 'E-1');
      expect(gespeichert.kennung, 'E-1');
      expect(gespeichert.sitzungId, 'PRUEF-S1');
      expect(
        (await zeilen(db, 'gym_entwuerfe')).single['workout'],
        'E-1',
        reason: 'die Spalte trägt die Kennung (Spec 4.6)',
      );
      container.dispose();
    });

    testWidgets('der Entwurf überlebt den Neustart: dieselben Zeilen, '
        'dieselben Eingaben', (tester) async {
      final roh = sqlite3.openInMemory();
      addTearDown(roh.close);
      final db1 = await oeffne(roh);
      await GymTrainingRepository(db1).speichere(eigenesTraining());
      final erste = huelle(db1);
      final notifier = await oeffneLog(erste, eigener);
      notifier.setzeSatz('lateralRaise', 0, gewicht: '10', wdh: '12');
      notifier.setzeSatz('benchPress', 1, gewicht: '60', wdh: '6');
      notifier.setzeSatz('dips', 4, gewicht: '20', wdh: '8');
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pump();
      expect(await GymRepository(db1).entwurf(), isNotNull);

      // Die App wird beendet: Der Container ist weg, die Datei bleibt.
      erste.dispose();
      await db1.close();

      final db2 = await oeffne(roh);
      addTearDown(db2.close);
      final zweite = huelle(db2, sitzungsId: 'PRUEF-ANDERE');
      await oeffneLog(zweite, eigener);

      final stand = zweite.read(gymLogProvider(eigener));
      expect(stand.laedt, isFalse);
      expect(stand.hinweis, isNull);
      expect(stand.laufendes, isNull);
      expect(stand.gespeichertAm, isNotNull);
      expect(stand.entwurf.sitzungId, 'PRUEF-S1');
      expect(
        [for (final u in stand.entwurf.uebungen) u.id],
        ['lateralRaise', 'benchPress', 'dips'],
      );
      expect(
        stand.entwurf.uebung('lateralRaise')!.saetze.first.reps,
        '12',
      );
      expect(stand.entwurf.uebung('benchPress')!.saetze[1].weight, '60');
      expect(stand.entwurf.uebung('dips')!.saetze.length, 5);
      expect(stand.entwurf.uebung('dips')!.saetze[4].reps, '8');
      zweite.dispose();
    });

    test('Entwürfe sind einer: läuft ein eigenes Training, ist das für jedes '
        'andere ein „anderes Training läuft" — und es wird nichts '
        'geschrieben', () async {
      final db = await dbMitEigenem();
      final erste = huelle(db);
      final lauf = await oeffneLog(erste, eigener);
      lauf.setzeSatz('benchPress', 0, gewicht: '60', wdh: '5');
      await lauf.schreibeSofort();
      final vorher = await zeilen(db, 'gym_entwuerfe');
      expect(vorher.single['workout'], 'E-1');

      final zweite = huelle(db, sitzungsId: 'PRUEF-S2');
      final push = await oeffneLog(zweite, Workout.push);

      final stand = zweite.read(gymLogProvider(Workout.push));
      expect(stand.laufendes, isNotNull);
      expect(
        stand.hinweis,
        isNull,
        reason: 'Das ist eine Rückfrage, kein „nicht gelesen"',
      );
      push.setzeSatz('benchPress', 0, gewicht: '70', wdh: '8');
      await push.schreibeSofort();
      expect(
        await zeilen(db, 'gym_entwuerfe'),
        vorher,
        reason: 'Das fremde Training schreibt nichts, bis die Rückfrage '
            'beantwortet ist',
      );
    });

    test('und umgekehrt: läuft Push, ist ein eigenes Training „ein anderes"', () async {
      final db = await dbMitEigenem();
      final erste = huelle(db);
      final push = await oeffneLog(erste, Workout.push);
      push.setzeSatz('benchPress', 0, gewicht: '70', wdh: '8');
      await push.schreibeSofort();
      final vorher = await zeilen(db, 'gym_entwuerfe');

      final zweite = huelle(db, sitzungsId: 'PRUEF-S2');
      final lauf = await oeffneLog(zweite, eigener);

      expect(zweite.read(gymLogProvider(eigener)).laufendes, isNotNull);
      lauf.setzeSatz('benchPress', 0, gewicht: '60', wdh: '5');
      await lauf.schreibeSofort();
      expect(await zeilen(db, 'gym_entwuerfe'), vorher);
    });

    test('ein Entwurf für ein Training, das es nicht mehr gibt, wird nicht '
        'verworfen — Tims Gerät ist die einzige Kopie (Spec 4.7)', () async {
      final db = neueDb();
      await laufendesTraining(db, 'UUID-GELOESCHT');
      final container = huelle(db);

      try {
        await oeffneLog(container, const CustomTrainingKey('UUID-GELOESCHT'));
      } on Object {
        // Wie die Erfassung es meldet, ist offen (siehe Kopf) — nur nicht
        // unsichtbar.
      }
      try {
        await oeffneLog(container, Workout.a);
      } on Object {
        // dito
      }

      expect(
        await anzahl(db, 'gym_entwuerfe'),
        1,
        reason: 'Die Zeile bleibt: Verwerfen wäre Datenverlust ohne Rückfrage',
      );
    });
  });

  group('Beim Abschließen (Spec 4.6, 15.2)', () {
    test('`workout` ist die Kennung, die Übungen stehen in der Reihenfolge '
        'des Trainings, der Entwurf ist weg', () async {
      final db = await dbMitEigenem();
      final container = huelle(db);
      final notifier = await oeffneLog(container, eigener);
      notifier.setzeSatz('lateralRaise', 0, gewicht: '10', wdh: '12');
      notifier.setzeSatz('benchPress', 0, gewicht: '60', wdh: '6');
      notifier.setzeSatz('dips', 0, gewicht: '20', wdh: '8');

      final ergebnis = await notifier.schliesseAb();

      expect(ergebnis, GymAbschluss.abgelegt);
      final sitzung = (await GymRepository(db).sitzung('PRUEF-S1'))!;
      expect(sitzung.workout, isNull);
      expect(sitzung.trainingId, 'E-1');
      expect(
        [for (final e in sitzung.exercises) e.exerciseId],
        ['lateralRaise', 'benchPress', 'dips'],
        reason: 'Reihenfolge des Trainings (`trainingOrder`, Spec 25 Nr. 1), '
            'nicht alphabetisch',
      );
      final zeile = (await zeilen(db, 'gym_sitzungen')).single;
      expect(zeile['workout'], 'E-1');
      expect(await GymRepository(db).entwurf(), isNull);
    });

    test('nach dem Abschluss steht in der Erfassung wieder ein frisches '
        'Training — mit denselben Zeilen', () async {
      final db = await dbMitEigenem();
      final container = huelle(db);
      final notifier = await oeffneLog(container, eigener);
      notifier.setzeSatz('benchPress', 0, gewicht: '60', wdh: '6');
      await notifier.schliesseAb();

      final stand = container.read(gymLogProvider(eigener));

      expect(stand.entwurf.hatEintraege, isFalse);
      expect(ids(container, eigener), ['lateralRaise', 'benchPress', 'dips']);
      expect(satzzeilen(container, eigener, 'dips'), 5);
    });

    test('zwei verschiedene eigene Trainings am selben Tag: beide stehen im '
        'Verlauf (Sitzungsschlüssel, Plan M3 Punkt 6)', () async {
      final db = await dbMitEigenem();
      await GymTrainingRepository(db).speichere(
        WorkoutDefinition(
          id: 'E-2',
          name: 'Zuhause lang',
          category: WorkoutCategory.own,
          tags: const [],
          exercises: [
            WorkoutExercise(
              exerciseId: 'benchPress',
              sets: 4,
              repLow: 6,
              repHigh: 10,
            ),
          ],
        ),
      );
      final erste = huelle(db, sitzungsId: 'PRUEF-S1');
      final a = await oeffneLog(erste, eigener);
      a.setzeSatz('benchPress', 0, gewicht: '60', wdh: '6');
      expect(await a.schliesseAb(), GymAbschluss.abgelegt);

      final zweite = huelle(db, sitzungsId: 'PRUEF-S2');
      final b = await oeffneLog(zweite, const CustomTrainingKey('E-2'));
      b.setzeSatz('benchPress', 0, gewicht: '62,5', wdh: '8');
      expect(await b.schliesseAb(), GymAbschluss.abgelegt);

      final sitzungen = await GymRepository(db).sitzungen();
      expect(sitzungen, hasLength(2));
      expect(
        {for (final s in sitzungen) s.trainingId},
        {'E-1', 'E-2'},
      );
    });
  });

  group('Die Fokus-Karte zeigt ein laufendes eigenes Training (Spec 27 Nr. 4)', () {
    editorTest('der Entwurf der Erfassung für ein eigenes Training steht mit '
        'dessen Namen auf der Karte', (tester) async {
      final h = trainingsHuelle(repo: HakenRepo(neueDb()), echterTag: true);
      await legeEigenes(
        h.repo,
        'E-1',
        name: 'Zuhause kurz',
        tags: ['Home'],
        exercises: eigenesTraining().exercises,
      );
      // Seitheben steht (beide Zeilen), der Rest ist leer: eine von drei
      // Übungen ist erledigt.
      await GymRepository(h.db).speichereEntwurf(
        GymEntwurf(
          trainingId: 'E-1',
          sitzungId: 'PRUEF-S1',
          zeitpunkt: DateTime.utc(2026, 3, 9, 8),
          dauer: '25',
          gespeichertAm: DateTime.utc(2026, 3, 9, 8, 20),
          felder: jsonEncode({
            'version': 1,
            'uebungen': [
              {
                'id': 'lateralRaise',
                'unterstuetzt': false,
                'saetze': [
                  {'g': '10', 'w': '12', 't': '2026-03-09T08:10:00.000Z'},
                  {'g': '10', 'w': '13', 't': '2026-03-09T08:12:00.000Z'},
                ],
              },
            ],
            'aufwaermen': {
              'art': null,
              'min': '',
              'km': '',
              'uebersprungen': false,
            },
          }),
        ),
      );

      await zeigeGym(tester, h);

      expect(find.byKey(kKarte), findsOneWidget);
      expect(
        textUnter(tester, kKarte),
        contains('Zuhause kurz'),
        reason: 'Ein laufendes eigenes Training darf nicht unsichtbar sein',
      );
    });
  });

  group('Die Erfassung zeigt das Training (Spec 15.2, Widget)', () {
    Future<TrainingsHuelle> startHuelle(
      WidgetTester tester, {
      ImportedSession? verlauf,
    }) async {
      final repo = EditorRepo(neueDb());
      final h = editorHuelle(repo: repo);
      await legeEigenes(
        h.repo,
        'E-1',
        name: 'Zuhause kurz',
        tags: ['Home'],
        exercises: eigenesTraining().exercises,
      );
      if (verlauf != null) await GymRepository(h.db).schliesseAb(verlauf);
      await oeffneDetailVon(tester, h, 'E-1');
      await tippe(
        tester,
        find.byKey(kGymTrainingDetailStarten),
        warte: false,
      );
      expect(
        find.byKey(kGymUebung('benchPress')),
        findsOneWidget,
        reason: '„Training starten" führt in die Erfassung dieses Trainings',
      );
      return h;
    }

    editorTest('Reihenfolge und Zeilenzahl sind die des Trainings', (
      tester,
    ) async {
      await startHuelle(tester);

      double oben(String uid) =>
          tester.getTopLeft(find.byKey(kGymUebung(uid))).dy;
      expect(oben('lateralRaise'), lessThan(oben('benchPress')));
      expect(oben('benchPress'), lessThan(oben('dips')));
      for (final (uid, n) in [('lateralRaise', 2), ('benchPress', 3), ('dips', 5)]) {
        for (var i = 1; i <= n; i++) {
          expect(
            find.byKey(kGymFeldWdh(uid, i)),
            findsOneWidget,
            reason: '$uid Zeile $i',
          );
        }
        expect(
          find.byKey(kGymFeldWdh(uid, n + 1)),
          findsNothing,
          reason: '$uid hat genau $n Zeilen',
        );
      }
    });

    editorTest('ohne Verlauf nennt der Vorschlag den Bereich des Trainings: '
        '„5 bis 7", nicht den des Katalogs', (tester) async {
      await startHuelle(tester);

      final vorschlag = textUnter(tester, kGymVorschlag('benchPress'));

      expect(vorschlag, contains('5 bis 7'));
      expect(vorschlag, isNot(contains('6 bis 10')));
    });

    editorTest('Progression: der Bereich des Trainings auf dem übungsweiten '
        'Verlauf — ein Satz aus einem anderen Training zählt', (tester) async {
      // Gym A, drei Sätze Bankdrücken mit 10 Wiederholungen. Im Katalog
      // (6–10) wäre das die Obergrenze: „Ziel 6". Im Training (5–7) liegt
      // es darüber: „Ziel 5". Der Verlauf kommt aus **einem anderen**
      // Training — er ist übungsweit (Spec 17 Nr. 20).
      await startHuelle(
        tester,
        verlauf: verlaufSitzung(
          saetze: {
            'benchPress': [(60, 10), (60, 10), (60, 10)],
          },
        ),
      );

      final vorschlag = textUnter(tester, kGymVorschlag('benchPress'));

      expect(vorschlag, contains('62,5'));
      expect(
        vorschlag,
        contains('Ziel 5'),
        reason: 'Der Bereich des Trainings (5–7), nicht des Katalogs (6–10)',
      );
    });
  });
}
