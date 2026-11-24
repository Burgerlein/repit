import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/data/gym_training_repository.dart';
import 'package:repit/gym/gym_entwurf_provider.dart'
    show gymAblageVerfuegbarProvider;
import 'package:repit/gym/gym_trainings_provider.dart';
import 'package:repit/health/health_provider.dart'
    show appCacheProvider;

import '../data/gym_training_support.dart';

/// Tests für die **Provider der Trainings-Übersicht** und der gespeicherten
/// Rotation: `gymTrainingsProvider`, Filter, `gymTrainingProvider`,
/// `gymRotationProvider` und ihre Werttypen (#532, unter #531; Spec 6.3).
/// Task 1.8 des Plans `docs/superpowers/plans/2026-11-19-eigene-trainings-
/// plan.md`. Die Seite der Figur (`gymTrainingsSeiteProvider`) steht in
/// `gym_trainings_seite_provider_test.dart` — sie hängt am Typ `MuskelSeite`
/// aus Task 2.1.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden. Hält der
/// Implementierende eine Erwartung für falsch, wird das **gemeldet, nicht
/// korrigiert**.
///
/// ## Was die Anforderung bewacht
///
/// - **Fehler `01`** (Schritte stehen auf 0, obwohl Daten da sind): Während
///   des Ladens steht nie ein „keine Daten"-Grund. `laedt` ist `true`,
///   **solange nichts gelesen wurde — und nur dann**. Ein gescheitertes
///   Lesen nimmt keinen vorhandenen Stand weg. Für die Rotation: nie
///   „Ruhetag" beim Laden.
/// - **Fehler `32`** (ein Wert, der dastand, steht nach dem
///   Zurücknavigieren wieder da): Der Filter überlebt das Schließen der
///   Ansicht; ein Stand bleibt stehen, auch während neu gelesen wird.
/// - **Fehler `03`** (es ruckelt): Werttypen mit `==` über alle Felder,
///   Listen und `Set<Muscle>` inhaltlich; Dauer, Muskeln und Zählungen sind
///   **einmal gerechnet** und werden gehalten.
/// - **Spec 24 Nr. 4:** Eine Rotationskennung ohne bekanntes Training lässt
///   den Provider **werfen**, statt sie still zu verwerfen.
/// - **Spec 23/25:** Ohne Repository im Baum liefert `gymRotationProvider`
///   die **Startbefüllung** Push, Pull, Legs — nicht `Workout.rotation`
///   (das wären A–D).
///
/// ## Wer hat was entschieden
///
/// - **Entscheidung von Tim:** Push/Pull/Legs als Start-Templates und
///   Start-Rotation (19.11.2026, Spec 23); Entwürfe sind weder startbar noch
///   einplanbar (19.11.2026).
/// - **Hausregeln aus `CLAUDE.md`:** kein `AsyncValue` in der
///   Widget-Schicht; was ein Provider anbietet, wird gehalten, nicht je
///   Zugriff gerechnet; Werttypen mit `==`.
/// - **Folgerung aus Spec 6.3:** alles, was dort in Form vorgegeben ist —
///   die Felder von `TrainingKachel` und `GymTrainingsStand`, `readyCount`
///   (lebende, nicht-Entwurf: Templates + Eigene), `allTags` in der
///   Reihenfolge von `WorkoutTags.suggestions`, Filtern case-insensitiv,
///   Fallback auf „Alle".
///
/// ## API, die diese Tests verbindlich vorgeben
///
/// Spec 6.3 legt die Form vor, **die Namen sind frei**. **Festlegung des
/// Test-Agenten — Tim hat diese Namen nicht gesehen:**
///
/// ```dart
/// // Die Quellen: `FutureProvider`, Ziel von `ref.invalidate` (6.3,
/// // „Invalidierung") — die Spec nennt sie nicht, ohne Namen ließe sich
/// // „nach speichere/loesche neu lesen" nicht prüfen.
/// final gymTrainingsQuelleProvider = FutureProvider<List<WorkoutDefinition>>(…);
/// final gymRotationQuelleProvider  = FutureProvider<List<String>>(…);
///
/// final gymTrainingsProvider         = Provider<GymTrainingsStand>(…);
/// final gymTrainingsFilterProvider   = NotifierProvider<…, String?>(…);
///     // Notifier: `void setze(String? tag)`; null = „Alle"
/// final gymTrainingsGefiltertProvider = Provider<GymTrainingsStand>(…);
/// final gymTrainingProvider = FutureProvider.family<WorkoutDefinition?, String>(…);
///
/// @immutable class GymRotationStand {   // ==, hashCode
///   const GymRotationStand({required List<Workout> workouts, required bool laedt});
/// }
/// final gymRotationProvider = Provider<GymRotationStand>(…);
/// ```
///
/// Dazu `TrainingKachel` und `GymTrainingsStand` mit den Feldern aus Spec
/// 6.3 (benannte Parameter). `GymRotationStand.workouts` trägt die
/// Rotation als `Workout` — der Planer rechnet über `Workout` (Plan 18);
/// die Kennung ist `workout.id`.
///
/// **Die Quellen werden in den Tests über ein Repository mit Haken
/// versorgt** (`ZaehlendesRepo` unten, ein Unterklasse von
/// `GymTrainingRepository` über einer echten In-Memory-Datenbank): Es zählt
/// Aufrufe, hält das Lesen an und lässt es scheitern.
///
/// ## Was hier **nicht** getestet wird, weil die Spec es nicht sagt
///
/// - **Der Stand von `gymRotationProvider`, wenn das allererste Lesen
///   scheitert.** Spec 6.3/Plan 1.8 sagen nur, dass ein Scheitern keinen
///   vorhandenen Stand wegnimmt.
/// - **Der Inhalt von `GymRotationStand.workouts`, solange `laedt` gilt.**
/// - **Ob die Satzzahl einer Kachel Übungen mit unbekannter ID einrechnet**
///   (5.4 sagt es nur für die Übungszahl).
/// - **Reihenfolge von `allTags`, wenn nur ein Tag benutzt wird** — trivial.
/// - **Die Seite der Figur** — eigene Datei.
///
/// **Alle Namen, Zahlen und Zeitpunkte sind erfunden** (Jahr 2099).

/// Ein Repository über einer echten In-Memory-Datenbank, mit Haken für das,
/// was eine echte Platte nicht auf Befehl liefert.
class ZaehlendesRepo extends GymTrainingRepository {
  ZaehlendesRepo(AppCache db) : datenbank = db, super(db);

  /// Dieselbe Datenbank, die das Repository trägt — der Baum bekommt sie
  /// ebenfalls, damit `gymAblageVerfuegbarProvider` (der über
  /// `appCacheProvider` prüft) und ein eigener Check über das Repository
  /// zum selben Ergebnis kommen.
  final AppCache datenbank;

  int alleAufrufe = 0;
  int rotationAufrufe = 0;

  /// Hält `alle()` an, bis der Test es erfüllt.
  Completer<void>? tor;

  /// Hält `rotation()` an, bis der Test es erfüllt.
  Completer<void>? rotationTor;

  bool scheitert = false;
  bool rotationScheitert = false;

  /// Ersetzt die Antwort von `rotation()`, wo ein Test einen Stand braucht,
  /// den die Ablage nicht erzeugen kann.
  List<String>? rotationErsatz;

  @override
  Future<List<WorkoutDefinition>> alle({bool mitEntwuerfen = true}) async {
    alleAufrufe++;
    await tor?.future;
    if (scheitert) throw StateError('Die Platte ist voll (vom Test erzwungen)');
    return super.alle(mitEntwuerfen: mitEntwuerfen);
  }

  @override
  Future<List<String>> rotation() async {
    rotationAufrufe++;
    await rotationTor?.future;
    if (rotationScheitert) {
      throw StateError('Die Platte ist voll (vom Test erzwungen)');
    }
    return rotationErsatz ?? super.rotation();
  }
}

ProviderContainer huelle(ZaehlendesRepo repo) {
  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      appCacheProvider.overrideWithValue(repo.datenbank),
      gymTrainingRepositoryProvider.overrideWithValue(repo),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// Wartet, bis die Quelle geantwortet hat — mit Wert oder mit Fehler. Ein
/// fester Wert für `pumpEventQueue` reichte nicht: Die Ablage beantwortet
/// eine Anfrage in mehreren Schritten, und ihre Zahl wächst mit den Zeilen.
Future<void> abwarten(Future<Object?> quelle) async {
  try {
    await quelle;
  } on Object {
    // Ein gescheitertes Lesen ist ein Ergebnis wie jedes andere.
  }
  await pumpEventQueue();
}

/// Liest einmal an und wartet, bis die Quellen geantwortet haben.
Future<ProviderContainer> geladen(ZaehlendesRepo repo) async {
  final container = huelle(repo);
  container.read(gymTrainingsProvider);
  container.read(gymRotationProvider);
  await abwarten(container.read(gymTrainingsQuelleProvider.future));
  await abwarten(container.read(gymRotationQuelleProvider.future));
  return container;
}

/// Liest die Trainings-Quelle neu und wartet auf die Antwort.
Future<void> neuLesen(ProviderContainer container) {
  container.invalidate(gymTrainingsQuelleProvider);
  return abwarten(container.read(gymTrainingsQuelleProvider.future));
}

/// Liest die Rotations-Quelle neu und wartet auf die Antwort.
Future<void> neuLesenRotation(ProviderContainer container) {
  container.invalidate(gymRotationQuelleProvider);
  return abwarten(container.read(gymRotationQuelleProvider.future));
}

TrainingKachel kachel({
  String id = 'E-1',
  String name = 'Oberkörper zuhause',
  WorkoutCategory category = WorkoutCategory.own,
  bool isDraft = false,
  int? minutes = 45,
  bool minutesEntered = true,
  int exerciseCount = 2,
  int setCount = 8,
  List<String>? tags,
  Set<Muscle>? muscles,
  int unknownExerciseCount = 0,
}) => TrainingKachel(
  id: id,
  name: name,
  category: category,
  isDraft: isDraft,
  minutes: minutes,
  minutesEntered: minutesEntered,
  exerciseCount: exerciseCount,
  setCount: setCount,
  tags: tags ?? ['Gym', 'Home'],
  muscles: muscles ?? {Muscle.chest, Muscle.sideDelt},
  unknownExerciseCount: unknownExerciseCount,
);

List<String> ids(List<TrainingKachel> kacheln) => [
  for (final k in kacheln) k.id,
];

void main() {
  group('Werttypen mit `==` (Fehler `03`)', () {
    test('zwei Kacheln mit allen gleichen Feldern sind gleich, auch wenn '
        'Listen und Mengen verschiedene Instanzen sind', () {
      final a = kachel();
      final b = kachel();

      expect(identical(a.tags, b.tags), isFalse, reason: 'Vorbedingung');
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('jedes einzelne Feld der Kachel macht den Unterschied', () {
      final basis = kachel();
      final abweichungen = {
        'id': kachel(id: 'E-2'),
        'name': kachel(name: 'Anders'),
        'category': kachel(category: WorkoutCategory.template),
        'isDraft': kachel(isDraft: true),
        'minutes': kachel(minutes: 50),
        'minutes null': kachel(minutes: null),
        'minutesEntered': kachel(minutesEntered: false),
        'exerciseCount': kachel(exerciseCount: 3),
        'setCount': kachel(setCount: 9),
        'tags Inhalt': kachel(tags: ['Gym', 'Draußen']),
        'tags Reihenfolge': kachel(tags: ['Home', 'Gym']),
        'tags Länge': kachel(tags: ['Gym']),
        'muscles Inhalt': kachel(muscles: {Muscle.chest, Muscle.lats}),
        'muscles Größe': kachel(muscles: {Muscle.chest}),
        'unknownExerciseCount': kachel(unknownExerciseCount: 1),
      };

      for (final MapEntry(key: feld, value: andere) in abweichungen.entries) {
        expect(basis == andere, isFalse, reason: '$feld muss in == eingehen');
        expect(andere == basis, isFalse, reason: '$feld, andersherum');
      }
    });

    test('die Reihenfolge der Muskelmenge ist gleichgültig, die der Tags nicht',
        () {
      expect(
        kachel(muscles: {Muscle.chest, Muscle.sideDelt}),
        kachel(muscles: {Muscle.sideDelt, Muscle.chest}),
      );
      expect(kachel(tags: ['A', 'B']) == kachel(tags: ['B', 'A']), isFalse);
    });

    GymTrainingsStand stand({
      List<TrainingKachel>? templates,
      List<TrainingKachel>? own,
      List<String>? allTags,
      bool laedt = false,
    }) => GymTrainingsStand(
      templates:
          templates ??
          [kachel(id: 'Push', category: WorkoutCategory.template)],
      own: own ?? [kachel(), kachel(id: 'E-2', isDraft: true)],
      allTags: allTags ?? ['Gym', 'Home'],
      laedt: laedt,
    );

    test('zwei Stände mit gleichen Feldern sind gleich', () {
      expect(stand(), equals(stand()));
      expect(stand().hashCode, stand().hashCode);
    });

    test('jedes einzelne Feld des Stands macht den Unterschied', () {
      final basis = stand();
      final abweichungen = {
        'templates': stand(templates: []),
        'templates Inhalt': stand(
          templates: [kachel(id: 'Pull', category: WorkoutCategory.template)],
        ),
        'own': stand(own: []),
        'own Reihenfolge': stand(
          own: [kachel(id: 'E-2', isDraft: true), kachel()],
        ),
        'allTags': stand(allTags: ['Gym']),
        'allTags Reihenfolge': stand(allTags: ['Home', 'Gym']),
        'laedt': stand(laedt: true),
      };

      for (final MapEntry(key: feld, value: anderer) in abweichungen.entries) {
        expect(basis == anderer, isFalse, reason: '$feld muss in == eingehen');
      }
    });

    test('`readyCount` zählt lebende, nicht-Entwürfe: Templates und Eigene',
        () {
      final s = stand(
        templates: [
          kachel(id: 'Push', category: WorkoutCategory.template),
          kachel(id: 'Pull', category: WorkoutCategory.template),
        ],
        own: [
          kachel(id: 'E-1'),
          kachel(id: 'E-2', isDraft: true),
          kachel(id: 'E-3'),
          kachel(id: 'E-4', isDraft: true),
        ],
      );

      expect(s.readyCount, 4);
      expect(stand(templates: [], own: []).readyCount, 0);
    });

    test('`GymRotationStand` vergleicht die Plätze in ihrer Reihenfolge und '
        '`laedt`', () {
      GymRotationStand r(List<Workout> w, {bool laedt = false}) =>
          GymRotationStand(workouts: w, laedt: laedt);

      expect(
        r([Workout.push, Workout.pull]),
        equals(r([Workout.push, Workout.pull])),
      );
      expect(
        r([Workout.push, Workout.pull]).hashCode,
        r([Workout.push, Workout.pull]).hashCode,
      );
      expect(
        r([Workout.push, Workout.pull]) == r([Workout.pull, Workout.push]),
        isFalse,
      );
      expect(r([Workout.push]) == r([Workout.push, Workout.pull]), isFalse);
      expect(r([Workout.push]) == r([Workout.push], laedt: true), isFalse);
    });
  });

  group('gymTrainingsProvider: Lesen und Laden (Fehler `01`)', () {
    test('`laedt` ist `true`, solange nichts gelesen wurde — und nur dann',
        () async {
      final repo = ZaehlendesRepo(neueDb())..tor = Completer<void>();
      final container = huelle(repo);

      final vorher = container.read(gymTrainingsProvider);

      expect(vorher.laedt, isTrue);
      expect(
        vorher.readyCount,
        0,
        reason: 'beim Laden steht nichts, was eine Aussage über Daten wäre',
      );

      repo.tor!.complete();
      await abwarten(container.read(gymTrainingsQuelleProvider.future));
      final nachher = container.read(gymTrainingsProvider);

      expect(nachher.laedt, isFalse);
      expect(ids(nachher.templates), ['Push', 'Pull', 'Legs']);
      expect(nachher.own, isEmpty);
      expect(nachher.readyCount, 3);
    });

    test('ein gescheitertes erstes Lesen ist „nichts da": kein Wurf, keine '
        'ewige Ladeform, nichts Erfundenes (wie `gymTagProvider`)', () async {
      final repo = ZaehlendesRepo(neueDb())..scheitert = true;
      final container = huelle(repo);

      container.read(gymTrainingsProvider);
      await abwarten(container.read(gymTrainingsQuelleProvider.future));
      final stand = container.read(gymTrainingsProvider);

      expect(stand.laedt, isFalse);
      expect(stand.templates, isEmpty);
      expect(stand.own, isEmpty);
    });

    test('ein gescheitertes Nachlesen nimmt keinen vorhandenen Stand weg',
        () async {
      final repo = ZaehlendesRepo(neueDb());
      await repo.speichere(eigenes('E-1'));
      final container = await geladen(repo);
      final vorher = container.read(gymTrainingsProvider);
      expect(vorher.readyCount, 4, reason: 'Vorbedingung');

      repo.scheitert = true;
      await neuLesen(container);

      final nachher = container.read(gymTrainingsProvider);
      expect(nachher, vorher);
      expect(nachher.laedt, isFalse);
      expect(ids(nachher.own), ['E-1']);
    });

    test('während neu gelesen wird, bleibt der Stand stehen, und `laedt` '
        'bleibt `false` — der Platzhalter gehört allein dem ersten Lesen',
        () async {
      final repo = ZaehlendesRepo(neueDb());
      final container = await geladen(repo);
      final vorher = container.read(gymTrainingsProvider);

      repo.tor = Completer<void>();
      container.invalidate(gymTrainingsQuelleProvider);
      await pumpEventQueue();

      final waehrend = container.read(gymTrainingsProvider);
      expect(waehrend.laedt, isFalse);
      expect(waehrend, vorher);

      repo.tor!.complete();
      await abwarten(container.read(gymTrainingsQuelleProvider.future));
      expect(container.read(gymTrainingsProvider), vorher);
    });

    test('ohne Repository im Baum: ein leerer Stand mit `laedt == false` '
        '(Tests ohne Datenbank)', () {
      final container = ProviderContainer(retry: (_, _) => null);
      addTearDown(container.dispose);

      final stand = container.read(gymTrainingsProvider);

      expect(container.read(gymAblageVerfuegbarProvider), isFalse);
      expect(stand.laedt, isFalse);
      expect(stand.templates, isEmpty);
      expect(stand.own, isEmpty);
      expect(stand.allTags, isEmpty);
      expect(stand.readyCount, 0);
    });
  });

  group('gymTrainingsProvider: die fertigen Kacheln (Spec 6.3)', () {
    test('die Kachel eines Templates trägt, was der Kern rechnet', () async {
      final container = await geladen(ZaehlendesRepo(neueDb()));

      final stand = container.read(gymTrainingsProvider);

      final push = stand.templates.first;
      expect(push.id, 'Push');
      expect(push.name, 'Push — Brust, Schultern, Trizeps');
      expect(push.category, WorkoutCategory.template);
      expect(push.isDraft, isFalse);
      expect(push.minutes, 70);
      expect(push.minutesEntered, isTrue);
      expect(push.exerciseCount, 7);
      expect(push.setCount, 23);
      expect(push.tags, ['Gym']);
      expect(
        push.muscles,
        WorkoutMuscles.trained(WorkoutTemplates.all[0].exercises),
      );
      expect(push.unknownExerciseCount, 0);
      expect(ids(stand.templates), ['Push', 'Pull', 'Legs']);
      expect([for (final k in stand.templates) k.setCount], [23, 23, 25]);
    });

    test('Eigene: eingetragene Dauer steht da, geschätzte kommt aus dem Kern '
        'und ist als solche gekennzeichnet', () async {
      final repo = ZaehlendesRepo(neueDb());
      await repo.speichere(eigenes('E-1', enteredMinutes: 45));
      await repo.speichere(eigenes('E-2', enteredMinutes: null));
      final container = await geladen(repo);

      final eigene = container.read(gymTrainingsProvider).own;

      expect(ids(eigene), ['E-1', 'E-2']);
      expect(eigene[0].minutes, 45);
      expect(eigene[0].minutesEntered, isTrue);
      expect(
        eigene[1].minutes,
        WorkoutDuration.estimate(zweiUebungen()),
        reason: 'WorkoutDuration.effective: entered ?? estimate',
      );
      expect(eigene[1].minutes, isNotNull);
      expect(eigene[1].minutesEntered, isFalse);
      expect(eigene[0].exerciseCount, 2);
      expect(eigene[0].setCount, 8);
      expect(eigene[0].tags, ['Home']);
      expect(eigene[0].category, WorkoutCategory.own);
      expect(
        eigene[0].muscles,
        {
          Muscle.chest,
          Muscle.frontDelt,
          Muscle.triceps,
          Muscle.sideDelt,
        },
        reason: 'Haupt- und Nebenmuskeln von Bankdrücken und Seitheben',
      );
    });

    test('ein Entwurf ohne Übung hat keine Dauer — `null`, nie 0 (Fehler '
        '`01`) —, keine Muskeln und die Kapsel', () async {
      final repo = ZaehlendesRepo(neueDb());
      await repo.speichere(
        eigenes('D-1', name: '', tags: [], exercises: [], isDraft: true),
      );
      final container = await geladen(repo);

      final entwurf = container.read(gymTrainingsProvider).own.single;

      expect(entwurf.isDraft, isTrue);
      expect(entwurf.minutes, isNull);
      expect(entwurf.minutesEntered, isFalse);
      expect(entwurf.exerciseCount, 0);
      expect(entwurf.setCount, 0);
      expect(entwurf.muscles, isEmpty);
      expect(entwurf.tags, isEmpty);
    });

    test('eine Übung, die der Katalog nicht kennt, zählt als Eintrag und als '
        'unbekannt, aber nicht in Dauer und Muskeln (Spec 5.4, 6.2)', () async {
      final db = neueDb();
      final repo = ZaehlendesRepo(db);
      await db.customStatement(
        'INSERT INTO gym_trainings (id, name, kategorie, reihenfolge) '
        "VALUES ('E-1', 'Mit Altlast', 'eigene', 1);",
      );
      await db.customStatement(
        'INSERT INTO gym_training_uebungen '
        '(training_id, pos, uebung_id, saetze, wdh_von, wdh_bis) '
        "VALUES ('E-1', 1, 'benchPress', 4, 6, 10), "
        "('E-1', 2, 'gibtEsNichtMehr', 3, 8, 12);",
      );
      final container = await geladen(repo);

      final k = container.read(gymTrainingsProvider).own.single;

      expect(k.exerciseCount, 2, reason: 'Einträge, nicht bekannte Übungen');
      expect(k.unknownExerciseCount, 1);
      expect(k.muscles, {Muscle.chest, Muscle.frontDelt, Muscle.triceps});
      expect(
        k.minutes,
        WorkoutDuration.estimate([uebung('benchPress', sets: 4, repLow: 6, repHigh: 10)]),
        reason: 'die unbekannte Übung trägt nichts bei',
      );
    });

    test('`allTags`: benutzte Tags nach Häufigkeit, bei Gleichstand '
        'alphabetisch; Entwürfe zählen, Tombstones nicht', () async {
      final db = neueDb();
      final repo = ZaehlendesRepo(db);
      await repo.speichere(eigenes('E-1', tags: ['Gym', 'Home']));
      await repo.speichere(eigenes('E-2', tags: ['Home']));
      await repo.speichere(eigenes('E-3', tags: ['Zuhause']));
      await repo.speichere(eigenes('D-1', tags: ['Draußen'], isDraft: true));
      final container = await geladen(repo);

      expect(
        container.read(gymTrainingsProvider).allTags,
        ['Gym', 'Home', 'Draußen', 'Zuhause'],
        reason: 'Gym 4 (drei Templates + E-1), Home 2, Draußen und Zuhause je 1',
      );

      // Tombstones per SQL: Templates sind nicht löschbar (Spec 26 Nr. 1),
      // die Spalte und ihre Wirkung auf die Tags bleiben.
      await db.customStatement(
        "UPDATE gym_trainings SET geloescht = 1 "
        "WHERE id IN ('Push', 'Pull', 'Legs');",
      );
      await neuLesen(container);
      expect(
        container.read(gymTrainingsProvider).allTags,
        ['Home', 'Draußen', 'Gym', 'Zuhause'],
        reason:
            'Home 2, dann je 1 — Draußen, Gym, Zuhause alphabetisch: „Gym" '
            'trägt nur noch E-1, die drei Templates zählen nicht mehr',
      );
    });
  });

  group('Einmal gerechnet, gehalten (Hausregel 2, Fehler `03`)', () {
    test('mehrfaches Lesen liest die Ablage einmal und liefert dieselbe '
        'Instanz', () async {
      final repo = ZaehlendesRepo(neueDb());
      await repo.speichere(eigenes('E-1'));
      final container = await geladen(repo);

      final a = container.read(gymTrainingsProvider);
      final b = container.read(gymTrainingsProvider);
      final g1 = container.read(gymTrainingsGefiltertProvider);
      final g2 = container.read(gymTrainingsGefiltertProvider);

      expect(repo.alleAufrufe, 1, reason: 'ein Lesen, nicht eins je Zugriff');
      expect(identical(a, b), isTrue);
      expect(identical(a.templates.first, b.templates.first), isTrue);
      expect(
        identical(a.own.first.muscles, b.own.first.muscles),
        isTrue,
        reason: 'Muskeln und Dauer sind gerechnet, nicht je Lesen neu',
      );
      expect(identical(g1, g2), isTrue);
    });

    test('der Filter rechnet das Ergebnis einmal und liest die Ablage nicht '
        'neu', () async {
      final repo = ZaehlendesRepo(neueDb());
      await repo.speichere(eigenes('E-1', tags: ['Home']));
      final container = await geladen(repo);

      container.read(gymTrainingsFilterProvider.notifier).setze('Home');
      final g1 = container.read(gymTrainingsGefiltertProvider);
      final g2 = container.read(gymTrainingsGefiltertProvider);

      expect(identical(g1, g2), isTrue);
      expect(repo.alleAufrufe, 1);
    });

    test('ein erneutes Lesen mit gleichem Inhalt benachrichtigt niemanden: '
        '`==` ersetzt das Neurechnen der Abhängigen', () async {
      final repo = ZaehlendesRepo(neueDb());
      await repo.speichere(eigenes('E-1'));
      final container = await geladen(repo);
      var benachrichtigt = 0;
      final abo = container.listen(
        gymTrainingsProvider,
        (_, _) => benachrichtigt++,
      );
      addTearDown(abo.close);

      await neuLesen(container);
      await neuLesen(container);

      expect(repo.alleAufrufe, 3, reason: 'Vorbedingung: wirklich neu gelesen');
      expect(
        benachrichtigt,
        0,
        reason:
            'derselbe Inhalt in neuen Instanzen ist **gleich** — sonst liefe '
            'jeder abgeleitete Wert bei jedem Lesen neu (Fehler 03)',
      );
    });

    test('`gymRotationProvider` hält seinen Stand ebenso: ein erneutes '
        'Lesen mit gleichem Inhalt benachrichtigt niemanden', () async {
      final repo = ZaehlendesRepo(neueDb());
      final container = await geladen(repo);
      var benachrichtigt = 0;
      final abo = container.listen(
        gymRotationProvider,
        (_, _) => benachrichtigt++,
      );
      addTearDown(abo.close);

      await neuLesenRotation(container);

      expect(repo.rotationAufrufe, 2, reason: 'Vorbedingung');
      expect(benachrichtigt, 0);
    });
  });

  group('Invalidierung (Spec 6.3)', () {
    test('nach `speichere` und `loesche` liest die Quelle neu, und der Stand '
        'folgt', () async {
      final repo = ZaehlendesRepo(neueDb());
      final container = await geladen(repo);
      expect(container.read(gymTrainingsProvider).own, isEmpty);

      await repo.speichere(eigenes('E-1'));
      await neuLesen(container);
      expect(ids(container.read(gymTrainingsProvider).own), ['E-1']);
      expect(container.read(gymTrainingsProvider).readyCount, 4);

      await repo.loesche('E-1');
      await neuLesen(container);
      final danach = container.read(gymTrainingsProvider);
      expect(danach.own, isEmpty);
      expect(ids(danach.templates), ['Push', 'Pull', 'Legs']);
      expect(danach.readyCount, 3);

      await expectLater(repo.loesche('Pull'), throwsStateError);
      await neuLesen(container);
      expect(
        ids(container.read(gymTrainingsProvider).templates),
        ['Push', 'Pull', 'Legs'],
        reason: 'ein Template ist nicht löschbar (Spec 26 Nr. 1)',
      );
    });

    test('`gymTrainingProvider`: das Detail je Kennung, `null` für ein '
        'Training, das es nicht (mehr) gibt', () async {
      final db = neueDb();
      final repo = ZaehlendesRepo(db);
      await repo.speichere(eigenes('E-1', name: 'Alter Name'));
      final container = huelle(repo);

      expect(
        await container.read(gymTrainingProvider('Push').future),
        WorkoutTemplates.all[0],
      );
      expect(
        (await container.read(gymTrainingProvider('E-1').future))!.name,
        'Alter Name',
      );
      expect(
        await container.read(gymTrainingProvider('GIBT-ES-NICHT').future),
        isNull,
      );

      await repo.speichere(eigenes('E-1', name: 'Neuer Name'));
      await db.customStatement(
        "UPDATE gym_trainings SET geloescht = 1 WHERE id = 'Push';",
      ); // Tombstone per SQL (Spec 26 Nr. 1)
      container.invalidate(gymTrainingProvider('E-1'));
      container.invalidate(gymTrainingProvider('Push'));

      expect(
        (await container.read(gymTrainingProvider('E-1').future))!.name,
        'Neuer Name',
      );
      expect(
        await container.read(gymTrainingProvider('Push').future),
        isNull,
        reason: 'ein Tombstone ist „nicht (mehr) da"',
      );
    });
  });

  group('Filter (Spec 6.3, Fehler `32`)', () {
    Future<(ZaehlendesRepo, ProviderContainer)> mitTags() async {
      final repo = ZaehlendesRepo(neueDb());
      await repo.speichere(eigenes('E-1', tags: ['Home']));
      await repo.speichere(eigenes('E-2', tags: ['Draußen']));
      await repo.speichere(eigenes('D-1', tags: ['Home'], isDraft: true));
      return (repo, await geladen(repo));
    }

    test('ohne Filter steht alles da; „Alle" ist `null`', () async {
      final (_, container) = await mitTags();

      expect(container.read(gymTrainingsFilterProvider), isNull);
      expect(
        container.read(gymTrainingsGefiltertProvider),
        container.read(gymTrainingsProvider),
      );
    });

    test('der Filter trifft über den Tag, case-insensitiv, und Entwürfe mit '
        'passendem Tag zählen mit', () async {
      final (_, container) = await mitTags();

      container.read(gymTrainingsFilterProvider.notifier).setze('home');
      final gefiltert = container.read(gymTrainingsGefiltertProvider);

      expect(ids(gefiltert.templates), isEmpty, reason: 'die tragen „Gym"');
      expect(ids(gefiltert.own), ['E-1', 'D-1']);
      expect(gefiltert.own.last.isDraft, isTrue);
      expect(gefiltert.laedt, isFalse);
    });

    test('Entwürfe zählen im Filter, aber nicht in `readyCount`', () async {
      final (_, container) = await mitTags();

      expect(
        container.read(gymTrainingsProvider).readyCount,
        5,
        reason: 'drei Templates und E-1, E-2 — der Entwurf nicht',
      );

      container.read(gymTrainingsFilterProvider.notifier).setze('Home');

      expect(
        container.read(gymTrainingsProvider).readyCount,
        5,
        reason: 'die Zahl der Gym-Tab-Zeile hängt nicht am Filter',
      );
      expect(
        container
            .read(gymTrainingsGefiltertProvider)
            .own
            .where((k) => !k.isDraft),
        hasLength(1),
      );
    });

    test('der Filter überlebt das Schließen der Ansicht (Fehler `32`)',
        () async {
      final (_, container) = await mitTags();
      final abo = container.listen(gymTrainingsFilterProvider, (_, _) {});
      container.read(gymTrainingsFilterProvider.notifier).setze('Draußen');

      abo.close(); // die Ansicht verlässt den Baum
      await pumpEventQueue();

      expect(container.read(gymTrainingsFilterProvider), 'Draußen');
      expect(
        ids(container.read(gymTrainingsGefiltertProvider).own),
        ['E-2'],
      );
    });

    test('`setze(null)` führt auf „Alle" zurück', () async {
      final (_, container) = await mitTags();
      final notifier = container.read(gymTrainingsFilterProvider.notifier)
        ..setze('Home');

      notifier.setze(null);

      expect(container.read(gymTrainingsFilterProvider), isNull);
      expect(
        container.read(gymTrainingsGefiltertProvider),
        container.read(gymTrainingsProvider),
      );
    });

    test('ein Filter, dessen Tag nicht mehr benutzt wird, fällt auf „Alle" '
        'zurück — der Zustand wird zurückgesetzt, nicht nur ignoriert',
        () async {
      final (repo, container) = await mitTags();
      container.read(gymTrainingsFilterProvider.notifier).setze('Draußen');
      expect(
        ids(container.read(gymTrainingsGefiltertProvider).own),
        ['E-2'],
        reason: 'Vorbedingung',
      );

      await repo.loesche('E-2'); // das letzte Training mit diesem Tag
      await neuLesen(container);

      expect(
        container.read(gymTrainingsFilterProvider),
        isNull,
        reason: 'zurückgesetzt: Der Zustand selbst ist wieder „Alle"',
      );
      final gefiltert = container.read(gymTrainingsGefiltertProvider);
      expect(ids(gefiltert.templates), ['Push', 'Pull', 'Legs']);
      expect(ids(gefiltert.own), ['E-1', 'D-1']);
    });

    test('ein Filter, dessen Tag noch benutzt wird, bleibt', () async {
      final (repo, container) = await mitTags();
      container.read(gymTrainingsFilterProvider.notifier).setze('Home');

      await repo.loesche('E-2');
      await neuLesen(container);

      expect(container.read(gymTrainingsFilterProvider), 'Home');
    });
  });

  group('gymRotationProvider (Spec 23, 24 Nr. 4, Plan 18)', () {
    test('`laedt` gilt, bis gelesen wurde — der Platzhalter steht nur dort, '
        'nie ein „Ruhetag" beim Laden (Fehler `01`)', () async {
      final repo = ZaehlendesRepo(neueDb())..rotationTor = Completer<void>();
      final container = huelle(repo);

      expect(container.read(gymRotationProvider).laedt, isTrue);

      repo.rotationTor!.complete();
      await abwarten(container.read(gymRotationQuelleProvider.future));
      final danach = container.read(gymRotationProvider);

      expect(danach.laedt, isFalse);
      expect(danach.workouts, [Workout.push, Workout.pull, Workout.legs]);
    });

    test('die Rotation kommt aus der Ablage: nach einer Änderung der '
        'Rotationszeilen und neuem Lesen sind es zwei Plätze', () async {
      final db = neueDb();
      final repo = ZaehlendesRepo(db);
      final container = await geladen(repo);
      expect(container.read(gymRotationProvider).workouts, hasLength(3));

      await setzeRotation(db, ['Push', 'Legs']);
      await neuLesenRotation(container);

      expect(container.read(gymRotationProvider).workouts, [
        Workout.push,
        Workout.legs,
      ]);
    });

    test('eine leere Rotation ist nach dem Lesen leer — mit `laedt == false`',
        () async {
      final repo = ZaehlendesRepo(neueDb())..rotationErsatz = [];
      final container = await geladen(repo);

      final stand = container.read(gymRotationProvider);

      expect(stand.workouts, isEmpty);
      expect(stand.laedt, isFalse);
    });

    test('ein gescheitertes Nachlesen nimmt keinen Stand weg', () async {
      final repo = ZaehlendesRepo(neueDb());
      final container = await geladen(repo);
      final vorher = container.read(gymRotationProvider);
      expect(vorher.workouts, hasLength(3), reason: 'Vorbedingung');

      repo.rotationScheitert = true;
      await neuLesenRotation(container);

      final nachher = container.read(gymRotationProvider);
      expect(nachher, vorher);
      expect(nachher.laedt, isFalse);
    });

    test('während neu gelesen wird, bleibt der Stand stehen', () async {
      final repo = ZaehlendesRepo(neueDb());
      final container = await geladen(repo);
      final vorher = container.read(gymRotationProvider);

      repo.rotationTor = Completer<void>();
      container.invalidate(gymRotationQuelleProvider);
      await pumpEventQueue();

      expect(container.read(gymRotationProvider), vorher);
      expect(container.read(gymRotationProvider).laedt, isFalse);
    });

    test('ohne Repository im Baum: die Startbefüllung Push, Pull, Legs — '
        'nicht `Workout.rotation`', () {
      final container = ProviderContainer(retry: (_, _) => null);
      addTearDown(container.dispose);

      final stand = container.read(gymRotationProvider);

      expect(stand.laedt, isFalse);
      expect(stand.workouts, [Workout.push, Workout.pull, Workout.legs]);
      expect(
        stand.workouts,
        isNot(Workout.rotation),
        reason: 'das wären Gym A bis D (Spec 23)',
      );
    });

    test('eine Kennung ohne Enum-Fall und ohne Training lässt den Provider '
        'werfen — kein stilles Verwerfen', () async {
      final repo = ZaehlendesRepo(neueDb())
        ..rotationErsatz = ['Push', 'ZZ-UNBEKANNT', 'Legs'];
      final container = huelle(repo);

      container.read(gymRotationProvider);
      await abwarten(container.read(gymRotationQuelleProvider.future));

      expect(
        () => container.read(gymRotationProvider),
        throwsA(anything),
        reason:
            'in dieser Stufe schreibt nur die Einspielung die Rotation — '
            'eine unbekannte Kennung ist ein Programmierfehler, keine '
            'Datenlage (Spec 24 Nr. 4)',
      );
    });

    test('eine bekannte Rotation wirft nicht', () async {
      final container = await geladen(ZaehlendesRepo(neueDb()));

      expect(() => container.read(gymRotationProvider), returnsNormally);
    });
  });
}
