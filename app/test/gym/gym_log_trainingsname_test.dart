import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/gym_repository.dart';
import 'package:repit/gym/gym_log_provider.dart';
import 'package:repit/gym/gym_log_stand.dart' show GymAbschluss;
import 'package:repit/health/health_provider.dart'
    show appCacheProvider, clockProvider;

import '../data/gym_training_support.dart';

/// Tests dafür, dass **`GymLogNotifier` beim Abschließen den Trainingsnamen
/// schreibt** — für Sitzungen über den **bestehenden Enum-Weg** —, und dass
/// er danach eingefroren ist (#532, unter #531). Task 1.7 des Plans
/// `docs/superpowers/plans/2026-11-19-eigene-trainings-plan.md` verlangt
/// das („auch für Sitzungen über den bestehenden Enum-Weg"); dies ist sein
/// Test, geschrieben als Teil von Task 1.6/1.8.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden. Hält der
/// Implementierende eine Erwartung für falsch, wird das **gemeldet, nicht
/// korrigiert**.
///
/// ## Woher die Anforderung kommt
///
/// Spec `docs/superpowers/specs/2026-11-19-eigene-trainings-design.md`,
/// Abschnitt 4.6 („Sie wird beim Abschließen geschrieben (`GymLogNotifier`,
/// beim Aufruf des Builders) mit dem Namen **zu diesem Zeitpunkt**. Sie wird
/// nie nachträglich aktualisiert.") und 15.2 („Beim Abschließen gehen
/// `trainingId` (nur ohne Enum-Fall) und `trainingName` in den Builder").
///
/// ## Wer hat was entschieden
///
/// - **Entscheidung von Tim [18.11.2026]:** Der Verlauf friert ein; die
///   Sitzung speichert den Namen zum Zeitpunkt der Sitzung; Umbenennen und
///   Löschen schreiben den Verlauf nicht um.
/// - **Folgerung (Spec 4.6, Plan 1.7):** Der Name kommt aus der
///   Trainings-Zeile (Push/Pull/Legs); wo es keine Zeile gibt — Gym A bis
///   D —, aus `WorkoutTemplates.fromEnum`, **nie aus dem Zufall**. Er ist
///   `'${label} — ${title}'`, die Zeichenkette, die die Schirme heute
///   zusammensetzen. `workout` in der Sitzung bleibt der Enum-Code.
/// - **Die Rangfolge „Zeile vor Enum"** (der Name kommt bei Push aus der
///   Zeile, auch wenn sie anders heißt als das Enum) steht im Plan 1.7, nicht
///   in der Spec; sie ist hier als **Folgerung aus dem Plan** geführt.
///
/// ## API, die diese Tests verbindlich vorgeben
///
/// Keine neue: `gymLogProvider(Workout)`, `GymLogNotifier.setzeSatz`,
/// `schliesseAb` — bestehende Signaturen bleiben (Spec 3.1). Neu ist nur,
/// was in `gym_sitzungen.trainings_name` und in `ImportedSession.trainingName`
/// ankommt.
///
/// ## Was hier **nicht** getestet wird
///
/// - **`gymLogProvider(CustomTrainingKey(…))`** — Task 3.1/3.2 (#534); in
///   Scheibe 1 gibt es den Enum-Weg.
/// - **Der Name eines gelöschten Templates beim Abschließen** (Tombstone
///   ohne lebende Zeile): Plan 3.1 sagt „fällt nicht still auf die
///   Enum-Definition zurück — Task 0 klärt"; offen.
///
/// **Alle Namen, Zahlen und Zeitpunkte sind erfunden** (Jahr 2099).
void main() {
  final jetzt = DateTime.utc(2099, 3, 9, 9);

  ProviderContainer huelle() {
    final db = neueDb();
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        appCacheProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => jetzt),
        gymIdProvider.overrideWithValue(() => 'PRUEF-S1'),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Ein Training eintragen und abschließen — ein Satz Bankdrücken.
  Future<GymAbschluss> trageEinUndSchliesseAb(
    ProviderContainer container,
    Workout workout, {
    String uebung = 'benchPress',
  }) async {
    final notifier = container.read(gymLogProvider(workout).notifier);
    await notifier.bereit;
    notifier.setzeSatz(uebung, 0, gewicht: '60', wdh: '8');
    return notifier.schliesseAb();
  }

  /// Liest über eine **eigene** Ablage, die kein Provider kennt.
  Future<ImportedSession?> leseSitzung(ProviderContainer container, String id) =>
      GymRepository(container.read(appCacheProvider)).sitzung(id);

  test('Push: der Name zum Zeitpunkt des Abschlusses steht in der Sitzung, '
      '`workout` bleibt der Code', () async {
    final container = huelle();

    final ergebnis = await trageEinUndSchliesseAb(container, Workout.push);

    expect(ergebnis, GymAbschluss.abgelegt);
    final sitzung = (await leseSitzung(container, 'PRUEF-S1'))!;
    expect(sitzung.trainingName, 'Push — Brust, Schultern, Trizeps');
    expect(sitzung.workout, Workout.push);
    expect(sitzung.trainingId, isNull, reason: 'nur ohne Enum-Fall gesetzt');
    final zeile = (await zeilen(container.read(appCacheProvider), 'gym_sitzungen'))
        .single;
    expect(zeile['workout'], 'Push');
    expect(zeile['trainings_name'], 'Push — Brust, Schultern, Trizeps');
  });

  test('Pull und Legs: jeweils ihr eigener Name', () async {
    final pull = huelle();
    await trageEinUndSchliesseAb(pull, Workout.pull, uebung: 'pullUp');
    final legs = huelle();
    await trageEinUndSchliesseAb(legs, Workout.legs, uebung: 'legPress');

    expect(
      (await leseSitzung(pull, 'PRUEF-S1'))!.trainingName,
      'Pull — Rücken, hintere Schulter, Bizeps',
    );
    expect(
      (await leseSitzung(legs, 'PRUEF-S1'))!.trainingName,
      'Legs — Beine komplett',
    );
  });

  test('Gym A (keine Zeile in `gym_trainings`): der Name kommt aus dem Enum, '
      '`workout` bleibt `A`', () async {
    final container = huelle();
    expect(
      await anzahl(container.read(appCacheProvider), 'gym_trainings', "id = 'A'"),
      0,
      reason: 'Vorbedingung: es gibt keine Zeile für Gym A (Spec 23)',
    );

    final ergebnis = await trageEinUndSchliesseAb(container, Workout.a);

    expect(ergebnis, GymAbschluss.abgelegt);
    final sitzung = (await leseSitzung(container, 'PRUEF-S1'))!;
    expect(sitzung.trainingName, 'Gym A — Oberkörper Push + Arme');
    expect(sitzung.workout, Workout.a);
    expect(
      (await zeilen(container.read(appCacheProvider), 'gym_sitzungen'))
          .single['workout'],
      'A',
    );
  });

  test('der Name kommt aus der Trainings-Zeile, nicht aus dem Enum, wo es '
      'eine Zeile gibt (Plan 1.7)', () async {
    final container = huelle();
    await container.read(appCacheProvider).customStatement(
      "UPDATE gym_trainings SET name = 'Prüfname Push' WHERE id = 'Push';",
    );

    await trageEinUndSchliesseAb(container, Workout.push);

    expect(
      (await leseSitzung(container, 'PRUEF-S1'))!.trainingName,
      'Prüfname Push',
    );
  });

  test('der Name friert ein: ein Tombstone am Template nach dem Abschluss '
      'ändert die Sitzung nicht (per SQL, Templates sind nicht löschbar, '
      'Spec 26 Nr. 1)', () async {
    final container = huelle();
    await trageEinUndSchliesseAb(container, Workout.push);

    await container.read(appCacheProvider).customStatement(
      "UPDATE gym_trainings SET geloescht = 1 WHERE id = 'Push';",
    );

    final sitzung = (await leseSitzung(container, 'PRUEF-S1'))!;
    expect(sitzung.trainingName, 'Push — Brust, Schultern, Trizeps');
    expect(sitzung.workout, Workout.push);
  });

  test('eine ältere Sitzung ohne Namen bleibt `NULL`, wenn ein neues '
      'Training abgeschlossen wird', () async {
    final container = huelle();
    final db = container.read(appCacheProvider);
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

    await trageEinUndSchliesseAb(container, Workout.push);

    final alt = (await leseSitzung(container, 'PRUEF-ALT'))!;
    expect(alt.trainingName, isNull, reason: 'kein erfundener Name');
    expect(alt.workout, Workout.a);
    expect(
      (await leseSitzung(container, 'PRUEF-S1'))!.trainingName,
      'Push — Brust, Schultern, Trizeps',
    );
  });
}
