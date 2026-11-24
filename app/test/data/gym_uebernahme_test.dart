// `drift` exportiert eigene `isNull` und `isNotNull` — dieselbe Begründung
// wie in `test/data/gym_ablage_test.dart`.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/data/gym_repository.dart';

/// Tests für `GymRepository.uebernimm` — das **Schreiben einer Übernahme aus
/// der alten App** (#59 Teil 1, mit #482).
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden. Geschrieben aus
/// `docs/superpowers/specs/2026-11-11-gym-uebernahme-design.md`, Abschnitte
/// 3 bis 5, **ohne** den späteren Code gesehen zu haben.
///
/// ## Worum es geht — #482
///
/// `GymRepository.legeAb` ersetzt eine Sitzung, wenn Tag und Workout gleich
/// sind, und fragt nicht, woher die vorhandene stammt. Eine Übernahme, die
/// darüber schreibt, **löscht still ein Training, das Tim im Neubau selbst
/// eingetragen hat** — samt Sätzen, Satz-Uhrzeiten und Aufwärmen, die die
/// alte App gar nicht kennt. Das iPhone ist seine einzige Kopie; der Fehler
/// ist nicht reparabel.
///
/// ## Die Entscheidung (Test-Agent, nicht Tim)
///
/// `uebernimm` **schreibt nur dazu und löscht nie**. Was entscheidet, ob eine
/// Sitzung geschrieben wird, entscheidet der Kern (`GymSessionImport.plan`,
/// getestet in `gym_session_import_test.dart`); die Ablage führt aus, in
/// **einer Transaktion**, und kann keine vorhandene Zeile ersetzen.
///
/// ## Festgelegte API — Entscheidung des Test-Agenten, nicht von Tim
///
/// ```dart
/// class GymRepository {
///   /// Schreibt, was der Planer erlaubt — und sonst nichts. Liest, plant
///   /// und schreibt in einer Transaktion. Löscht und ersetzt nie.
///   /// Wirft [ArgumentError] und schreibt nichts, wenn eine zu schreibende
///   /// Sitzung die Regeln von `legeAb` verletzt (Übung ohne Satz, Satz ohne
///   /// positive Wiederholungen, Übung doppelt).
///   Future<GymUebernahme> uebernimm(List<ImportedSession> sitzungen);
/// }
///
/// final class GymUebernahme {
///   final List<ImportedSession> geschrieben;    // in der Reihenfolge der Eingabe
///   final List<GymImportSkip> uebersprungen;    // aus dem Kern
/// }
/// ```
///
/// ## Was hier nie vorkommen darf
///
/// Eine Satz-Uhrzeit, ein Aufwärmen, eine Health-Kennung oder ein
/// Zeitstempel, den die Datei nicht trug. Die Spalten bleiben `NULL`.
///
/// Alle Zeitpunkte sind UTC und erfunden, im Jahr 2099. Im Januar gilt
/// Berliner Winterzeit (UTC+1); von Hand ausgerechnet.
void main() {
  late AppCache db;
  late GymRepository ablage;

  setUp(() {
    db = AppCache(NativeDatabase.memory());
    ablage = GymRepository(db);
  });
  tearDown(() => db.close());

  /* ---- Fixturen ------------------------------------------------------ */

  /// 14.01.2099, [stunde] UTC.
  DateTime tag14([int stunde = 9, int minute = 0]) =>
      DateTime.utc(2099, 1, 14, stunde, minute);

  ImportedSession sitzung(
    String id,
    DateTime wann, {
    Workout? workout = Workout.a,
    int? minuten,
    String? notiz,
    List<ImportedExercise>? uebungen,
  }) => ImportedSession(
    id: id,
    date: wann,
    workout: workout,
    minutes: minuten,
    note: notiz,
    exercises:
        uebungen ??
        [
          ImportedExercise(
            exerciseId: 'benchPress',
            sets: [CompletedSet(weight: 60, reps: 10)],
          ),
        ],
  );

  /// Tims **eigenes** Training aus dem Neubau — alles, was die alte App
  /// nicht kennt: Satz-Uhrzeiten, Aufwärmen, Dauer, Notiz.
  ImportedSession eigeneSitzung() => ImportedSession(
    id: 'EIGEN',
    date: tag14(9, 40),
    workout: Workout.a,
    minutes: 61,
    note: 'Erfundene Notiz',
    warmUp: const WarmUpDone(kind: WarmUpKind.bike, minutes: 8, km: 2.5),
    exercises: [
      ImportedExercise(
        exerciseId: 'benchPress',
        sets: [
          CompletedSet(weight: 60, reps: 10, recordedAt: tag14(9, 12)),
          CompletedSet(weight: 62.5, reps: 8, recordedAt: tag14(9, 15)),
        ],
      ),
      ImportedExercise(
        exerciseId: 'dips',
        sets: [CompletedSet(weight: 0, reps: 12, recordedAt: tag14(9, 30))],
      ),
    ],
  );

  /// Die eigene Sitzung samt Health-Kennungen — auch die darf die Übernahme
  /// nicht anfassen (`legeAb` rettet sie beim Ersetzen, die Übernahme ersetzt
  /// gar nicht erst).
  Future<void> legeEigeneAb() async {
    await ablage.legeAb(eigeneSitzung());
    await db.customStatement(
      "UPDATE gym_sitzungen SET health_uuid = 'H-WORKOUT', "
      "aufwaermen_health_uuid = 'H-WARMUP' WHERE id = 'EIGEN';",
    );
  }

  /// Jede Zeile beider Tabellen, geordnet — so, wie sie in der Datei stehen.
  Future<List<Map<String, Object?>>> zeilen(
    String tabelle, {
    String? sitzungId,
  }) async {
    final spalte = tabelle == 'gym_sitzungen' ? 'id' : 'sitzung_id';
    final ordnung = tabelle == 'gym_sitzungen'
        ? 'id'
        : 'sitzung_id, uebung_pos, satz_nr';
    final rows = await db
        .customSelect(
          'SELECT * FROM $tabelle '
          '${sitzungId == null ? '' : "WHERE $spalte = '$sitzungId'"} '
          'ORDER BY $ordnung;',
        )
        .get();
    return [for (final r in rows) Map<String, Object?>.from(r.data)];
  }

  Future<List<Map<String, Object?>>> alleZeilen() async => [
    ...await zeilen('gym_sitzungen'),
    ...await zeilen('gym_saetze'),
  ];

  List<String> ids(Iterable<ImportedSession> s) => [for (final x in s) x.id];

  group('#482 — eine Übernahme überschreibt kein eigenes Training', () {
    test('gleicher Tag, gleiches Workout, andere Kennung: Das Eigene bleibt '
        'Byte für Byte stehen', () async {
      await legeEigeneAb();
      final eigenVorher = await zeilen('gym_sitzungen', sitzungId: 'EIGEN');
      final saetzeVorher = await zeilen('gym_saetze', sitzungId: 'EIGEN');
      expect(saetzeVorher.length, 3, reason: 'Voraussetzung des Tests');

      // Derselbe Berliner Tag und dasselbe Workout — der Tagesbeginn, wie
      // die alte App ihn schreibt. Mit `legeAb` wäre „EIGEN" jetzt weg.
      final alt = sitzung(
        'ALT',
        DateTime.utc(2099, 1, 13, 23),
        uebungen: [
          ImportedExercise(
            exerciseId: 'benchPress',
            sets: [CompletedSet(weight: 20, reps: 20)],
          ),
        ],
      );
      // Beweis, dass die Übernahme gelaufen ist und nicht stumm nichts tat.
      final anderer = sitzung('ANDERER', DateTime.utc(2099, 1, 15, 9));

      final ergebnis = await ablage.uebernimm([alt, anderer]);

      expect(ids(ergebnis.geschrieben), ['ANDERER']);
      expect(ergebnis.uebersprungen.map((s) => s.session.id), ['ALT']);
      expect(
        ergebnis.uebersprungen.single.reason,
        GymImportSkipReason.dayAndWorkoutTaken,
      );

      expect(
        await zeilen('gym_sitzungen', sitzungId: 'EIGEN'),
        eigenVorher,
        reason: 'Die Sitzungszeile ist unverändert — samt Health-Kennungen',
      );
      expect(
        await zeilen('gym_saetze', sitzungId: 'EIGEN'),
        saetzeVorher,
        reason: 'Alle drei Sätze mit ihren Satz-Uhrzeiten sind noch da',
      );
      expect(await ablage.sitzung('EIGEN'), eigeneSitzung());
      expect(
        await ablage.sitzung('ALT'),
        isNull,
        reason: 'Die übersprungene Sitzung steht nirgends',
      );
      expect(await zeilen('gym_saetze', sitzungId: 'ALT'), isEmpty);
    });

    test('Das Aufwärmen und die Satz-Uhrzeiten überleben', () async {
      await legeEigeneAb();

      await ablage.uebernimm([sitzung('ALT', DateTime.utc(2099, 1, 13, 23))]);

      final danach = (await ablage.sitzung('EIGEN'))!;
      expect(
        danach.warmUp,
        const WarmUpDone(kind: WarmUpKind.bike, minutes: 8, km: 2.5),
      );
      expect(danach.exercises[0].sets[0].recordedAt, tag14(9, 12));
      expect(danach.exercises[0].sets[1].recordedAt, tag14(9, 15));
      expect(danach.exercises[1].sets.single.recordedAt, tag14(9, 30));
      expect(danach.minutes, 61);
      expect(danach.note, 'Erfundene Notiz');
    });

    test('dieselbe Kennung wie das Eigene, anderer Tag: übersprungen '
        '(`alreadyPresent`), nichts verändert', () async {
      await legeEigeneAb();
      final vorher = await alleZeilen();

      final ergebnis = await ablage.uebernimm([
        sitzung('EIGEN', DateTime.utc(2099, 1, 20, 9), workout: Workout.b),
      ]);

      expect(ergebnis.geschrieben, isEmpty);
      expect(
        ergebnis.uebersprungen.single.reason,
        GymImportSkipReason.alreadyPresent,
      );
      expect(await alleZeilen(), vorher);
    });

    test('anderes Workout am selben Tag: beide stehen nebeneinander', () async {
      await legeEigeneAb();

      final ergebnis = await ablage.uebernimm([
        sitzung('B-ALT', tag14(), workout: Workout.b),
        sitzung('OHNE-ALT', tag14(), workout: null),
      ]);

      expect(ids(ergebnis.geschrieben), ['B-ALT', 'OHNE-ALT']);
      expect((await ablage.sitzungen()).length, 3);
      expect(await ablage.sitzung('EIGEN'), eigeneSitzung());
    });

    test('„kein Workout" gegen „kein Workout" am selben Tag: übersprungen — '
        'die Tabelle trägt das nicht über `UNIQUE`', () async {
      final eigen = sitzung('EIGEN-OHNE', tag14(), workout: null);
      await ablage.legeAb(eigen);

      final ergebnis = await ablage.uebernimm([
        sitzung('ALT-OHNE', tag14(18), workout: null),
      ]);

      expect(ergebnis.geschrieben, isEmpty);
      expect(
        ergebnis.uebersprungen.single.reason,
        GymImportSkipReason.dayAndWorkoutTaken,
      );
      expect(await ablage.sitzung('EIGEN-OHNE'), eigen);
      expect((await ablage.sitzungen()).length, 1);
    });

    test('der Berliner Tag zählt: 23:30 UTC liegt schon am Folgetag', () async {
      // Eigen: 14.01. 23:30 UTC = 15.01. 00:30 Berliner Zeit (`tag` 15.01.).
      final eigen = sitzung('EIGEN', tag14(23, 30));
      await ablage.legeAb(eigen);

      final ergebnis = await ablage.uebernimm([
        // Tagesbeginn des 15.01. — derselbe Berliner Tag: übersprungen.
        sitzung('GLEICHER-TAG', DateTime.utc(2099, 1, 14, 23)),
        // 14.01. 22:30 UTC = 23:30 Berliner Zeit am 14.01.: ein anderer Tag.
        sitzung('VORTAG', tag14(22, 30)),
      ]);

      expect(ids(ergebnis.geschrieben), ['VORTAG']);
      expect(ergebnis.uebersprungen.map((s) => s.session.id), [
        'GLEICHER-TAG',
      ]);
      final tage = await db
          .customSelect('SELECT id, tag FROM gym_sitzungen ORDER BY id;')
          .get();
      expect({for (final t in tage) t.read<String>('id'): t.read<String>('tag')},
          {'EIGEN': '2099-01-15', 'VORTAG': '2099-01-14'});
    });

    test('Eine Übernahme löscht nie: Alles, was vorher da war, ist nachher '
        'noch da', () async {
      final vorhanden = [
        sitzung('V1', tag14()),
        sitzung('V2', DateTime.utc(2099, 1, 15, 9), workout: Workout.b),
        sitzung('V3', DateTime.utc(2099, 1, 16, 9), workout: null),
      ];
      for (final v in vorhanden) {
        await ablage.legeAb(v);
      }
      final vorher = await alleZeilen();

      await ablage.uebernimm([
        sitzung('V1', tag14()), // schon da
        sitzung('X1', tag14(18)), // Tag belegt
        sitzung('X2', DateTime.utc(2099, 1, 16, 18), workout: null), // belegt
        sitzung('N1', DateTime.utc(2099, 2, 1, 9)), // neu
      ]);

      final nachher = await alleZeilen();
      for (final zeile in vorher) {
        expect(
          nachher,
          anyElement(equals(zeile)),
          reason: 'Eine Zeile, die vorher stand, fehlt oder wurde verändert',
        );
      }
      expect(nachher.length, greaterThan(vorher.length));
      for (final v in vorhanden) {
        expect(await ablage.sitzung(v.id), v);
      }
    });

    test('Ein eigenes Training darf ein Übernommenes weiterhin ersetzen — '
        'die Regel der Ablage bleibt, wie sie ist', () async {
      await ablage.uebernimm([sitzung('UEBERNOMMEN', tag14())]);

      await ablage.legeAb(eigeneSitzung());

      expect(await ablage.sitzung('UEBERNOMMEN'), isNull);
      expect(await ablage.sitzung('EIGEN'), eigeneSitzung());
    });
  });

  group('zweimal übernehmen verdoppelt nicht', () {
    List<ImportedSession> datei() => [
      sitzung('A', tag14()),
      sitzung('B', DateTime.utc(2099, 1, 15, 9), workout: Workout.b),
      sitzung('C', DateTime.utc(2099, 1, 16, 9), workout: null),
      sitzung('D', DateTime.utc(2099, 1, 17, 9), workout: Workout.push),
      sitzung('E', DateTime.utc(2099, 1, 18, 9), workout: Workout.legs),
    ];

    test('der zweite Lauf schreibt nichts: derselbe Stand, alles '
        '`alreadyPresent`', () async {
      final erster = await ablage.uebernimm(datei());
      final standNachErstem = await alleZeilen();

      final zweiter = await ablage.uebernimm(datei());

      expect(ids(erster.geschrieben), ['A', 'B', 'C', 'D', 'E']);
      expect(erster.uebersprungen, isEmpty);
      expect(zweiter.geschrieben, isEmpty);
      expect(zweiter.uebersprungen.length, 5);
      expect(
        zweiter.uebersprungen.map((s) => s.reason).toSet(),
        {GymImportSkipReason.alreadyPresent},
      );
      expect(await alleZeilen(), standNachErstem);
      expect((await ablage.sitzungen()).length, 5);
    });

    test('eine Datei, die um neue Sitzungen gewachsen ist, schreibt nur das '
        'Neue', () async {
      await ablage.uebernimm(datei());
      final vorher = await alleZeilen();

      final spaeter = [
        ...datei(),
        sitzung('F', DateTime.utc(2099, 1, 19, 9), workout: Workout.pull),
      ];
      final ergebnis = await ablage.uebernimm(spaeter);

      expect(ids(ergebnis.geschrieben), ['F']);
      expect(ergebnis.uebersprungen.length, 5);
      final nachher = await alleZeilen();
      for (final z in vorher) {
        expect(nachher, anyElement(equals(z)));
      }
      expect((await ablage.sitzungen()).length, 6);
    });

    test('die Reihenfolge der Datei ändert den Stand nicht — auch mit einer '
        'Dublette darin', () async {
      List<ImportedSession> mitDublette() => [
        ...datei(),
        // Zwei Sitzungen desselben Tages und Workouts in der Datei.
        sitzung('D1', DateTime.utc(2099, 1, 20, 9), workout: Workout.c),
        sitzung('D2', DateTime.utc(2099, 1, 20, 18), workout: Workout.c),
      ];

      await ablage.uebernimm(mitDublette());
      final vorwaerts = await ablage.sitzungen();
      final tabellenVorwaerts = await alleZeilen();

      await db.close();
      db = AppCache(NativeDatabase.memory());
      ablage = GymRepository(db);
      await ablage.uebernimm(mitDublette().reversed.toList());
      final rueckwaerts = await ablage.sitzungen();

      expect(rueckwaerts, vorwaerts);
      expect(await alleZeilen(), tabellenVorwaerts);
      expect(
        ids(vorwaerts),
        contains('D2'),
        reason: 'der spätere Zeitpunkt gewinnt',
      );
      expect(ids(vorwaerts), isNot(contains('D1')));
    });
  });

  group('alles oder nichts', () {
    ImportedSession ohneSatz(String id) => sitzung(
      id,
      DateTime.utc(2099, 1, 21, 9),
      workout: Workout.b,
      uebungen: [ImportedExercise(exerciseId: 'dips', sets: const [])],
    );

    test('Eine Sitzung, die die Ablage nicht nehmen kann, kippt den ganzen '
        'Lauf: `ArgumentError`, nichts geschrieben', () async {
      final eigen = eigeneSitzung();
      await ablage.legeAb(eigen);
      final vorher = await alleZeilen();

      await expectLater(
        ablage.uebernimm([
          sitzung('GUT-1', DateTime.utc(2099, 1, 18, 9), workout: Workout.b),
          ohneSatz('KAPUTT'),
          sitzung('GUT-2', DateTime.utc(2099, 1, 19, 9), workout: Workout.c),
        ]),
        throwsArgumentError,
      );

      expect(
        await alleZeilen(),
        vorher,
        reason:
            'Ein halber Import — zwei von drei Sitzungen — wäre schlimmer '
            'als keiner: Niemand wüsste, welche fehlen',
      );
      expect(await ablage.sitzung('GUT-1'), isNull);
      expect(await ablage.sitzung('GUT-2'), isNull);
      expect(await ablage.sitzung('EIGEN'), eigen);
    });

    test('Wiederholungen null: ebenfalls `ArgumentError`, nichts '
        'geschrieben', () async {
      await expectLater(
        ablage.uebernimm([
          sitzung('GUT', tag14()),
          sitzung(
            'NULL-WDH',
            DateTime.utc(2099, 1, 21, 9),
            workout: Workout.b,
            uebungen: [
              ImportedExercise(
                exerciseId: 'dips',
                sets: [CompletedSet(weight: 0, reps: 0)],
              ),
            ],
          ),
        ]),
        throwsArgumentError,
      );

      expect(await alleZeilen(), isEmpty);
    });

    test('Dieselbe Übung zweimal in einer Sitzung: `ArgumentError`, nichts '
        'geschrieben', () async {
      await expectLater(
        ablage.uebernimm([
          sitzung(
            'DOPPELT',
            tag14(),
            uebungen: [
              ImportedExercise(
                exerciseId: 'dips',
                sets: [CompletedSet(weight: 0, reps: 5)],
              ),
              ImportedExercise(
                exerciseId: 'dips',
                sets: [CompletedSet(weight: 0, reps: 6)],
              ),
            ],
          ),
        ]),
        throwsArgumentError,
      );

      expect(await alleZeilen(), isEmpty);
    });

    test('Eine **übersprungene** Sitzung wird nicht geprüft: Was nicht '
        'geschrieben wird, darf nicht den Lauf kippen', () async {
      // Sie ist kaputt, aber ihre Kennung ist schon da — es wird ohnehin
      // nichts von ihr geschrieben.
      await ablage.legeAb(sitzung('S1', tag14()));

      final ergebnis = await ablage.uebernimm([
        ImportedSession(
          id: 'S1',
          date: tag14(),
          workout: Workout.a,
          minutes: null,
          note: null,
          exercises: [ImportedExercise(exerciseId: 'dips', sets: const [])],
        ),
      ]);

      expect(ergebnis.geschrieben, isEmpty);
      expect(
        ergebnis.uebersprungen.single.reason,
        GymImportSkipReason.alreadyPresent,
      );
    });
  });

  group('nichts wird erfunden', () {
    test('Was die alte App nicht kennt, bleibt `NULL` — in jeder Spalte', () async {
      await ablage.uebernimm([
        sitzung('ALT', tag14(), workout: null),
        sitzung('ALT-B', DateTime.utc(2099, 1, 15, 9), workout: Workout.b),
      ]);

      final zeilen = await db.customSelect('SELECT * FROM gym_sitzungen;').get();
      expect(zeilen.length, 2);
      for (final z in zeilen) {
        final id = z.read<String>('id');
        expect(z.data['minuten'], isNull, reason: '$id: Dauer „nicht erfasst"');
        expect(z.data['notiz'], isNull, reason: '$id');
        expect(z.data['health_uuid'], isNull, reason: '$id');
        expect(z.data['aufwaermen_art'], isNull, reason: '$id');
        expect(z.data['aufwaermen_minuten'], isNull, reason: '$id');
        expect(z.data['aufwaermen_km'], isNull, reason: '$id');
        expect(z.data['aufwaermen_health_uuid'], isNull, reason: '$id');
        expect(
          z.data['aufwaermen_uebersprungen'],
          0,
          reason:
              '$id: „nichts eingetragen" — nicht „übersprungen", das wäre '
              'eine Antwort, die niemand gegeben hat',
        );
      }
      expect(
        zeilen.firstWhere((z) => z.read<String>('id') == 'ALT').data['workout'],
        isNull,
        reason: '„kein Workout" steht als NULL da, nicht als Platzhalter',
      );
    });

    test('Keine Satz-Uhrzeit: `zeitpunkt` jedes Satzes ist `NULL`', () async {
      await ablage.uebernimm([
        sitzung(
          'ALT',
          tag14(),
          uebungen: [
            ImportedExercise(
              exerciseId: 'benchPress',
              sets: [
                CompletedSet(weight: 60, reps: 10),
                CompletedSet(weight: 62.5, reps: 8),
              ],
            ),
            ImportedExercise(
              exerciseId: 'dips',
              sets: [CompletedSet(weight: 0, reps: 12)],
            ),
          ],
        ),
      ]);

      final saetze = await db.customSelect('SELECT * FROM gym_saetze;').get();
      expect(saetze.length, 3);
      for (final s in saetze) {
        expect(
          s.data['zeitpunkt'],
          isNull,
          reason: 'Ein Wert behauptete, der Satz sei zu dieser Minute '
              'entstanden',
        );
      }
    });

    test('Die Auswertung des Aufwärmens liest „nichts eingetragen", nicht '
        '„übersprungen"', () async {
      await ablage.uebernimm([sitzung('ALT', tag14())]);

      final zeilen = await ablage.aufwaermenImZeitraum(
        vonTag: '2099-01-01',
        bisTag: '2099-12-31',
      );

      expect(zeilen.single.aufwaermen, isNull);
    });

    test('Die Muskelkarte bekommt für übernommene Sätze den Zeitpunkt der '
        'Sitzung, ohne dass er in die Spalte zurückgeschrieben wird', () async {
      await ablage.uebernimm([sitzung('ALT', tag14())]);

      final saetze = await ablage.trainierteSaetze(
        vonTag: '2099-01-01',
        bisTag: '2099-12-31',
      );

      expect(saetze.single.date, tag14());
      final roh = await db.customSelect('SELECT zeitpunkt FROM gym_saetze;').get();
      expect(roh.single.data['zeitpunkt'], isNull);
    });
  });

  group('der Rundweg: was hereinkommt, kommt genauso heraus', () {
    test('Sitzungen mit Unterstützung, Körpergewicht, mehreren Übungen und '
        'einer Übung, die der Katalog nicht kennt', () async {
      final alt = sitzung(
        'ALT',
        tag14(),
        minuten: 52,
        notiz: 'Erfundener Eintrag',
        uebungen: [
          ImportedExercise(
            exerciseId: 'dips',
            sets: [
              CompletedSet(weight: 0, reps: 12),
              CompletedSet(weight: 0, reps: 10),
            ],
          ),
          ImportedExercise(
            exerciseId: 'assistedPullUp',
            sets: [CompletedSet(weight: -27, reps: 6)],
          ),
          ImportedExercise(
            exerciseId: 'ghostLift',
            sets: [CompletedSet(weight: 12.5, reps: 8)],
          ),
          ImportedExercise(
            exerciseId: 'benchPress',
            sets: [
              CompletedSet(weight: 62.5, reps: 8),
              CompletedSet(weight: 60, reps: 10),
            ],
          ),
        ],
      );

      await ablage.uebernimm([alt]);

      final zurueck = (await ablage.sitzung('ALT'))!;
      expect(zurueck, alt);
      expect(zurueck.exercises.map((e) => e.exerciseId), [
        'dips',
        'assistedPullUp',
        'ghostLift',
        'benchPress',
      ], reason: 'die Reihenfolge der Datei, nicht die des Katalogs');
      expect(zurueck.exercises[1].sets.single.weight, -27.0);
    });

    test('Position der Übung und Nummer des Satzes zählen ab 1, in der '
        'Reihenfolge der Datei', () async {
      await ablage.uebernimm([
        sitzung(
          'ALT',
          tag14(),
          uebungen: [
            ImportedExercise(
              exerciseId: 'dips',
              sets: [
                CompletedSet(weight: 0, reps: 12),
                CompletedSet(weight: 0, reps: 10),
              ],
            ),
            ImportedExercise(
              exerciseId: 'benchPress',
              sets: [CompletedSet(weight: 60, reps: 10)],
            ),
          ],
        ),
      ]);

      final rows = await db
          .customSelect(
            'SELECT uebung_id, uebung_pos, satz_nr FROM gym_saetze '
            'ORDER BY uebung_pos, satz_nr;',
          )
          .get();
      expect(
        [
          for (final r in rows)
            (
              r.read<String>('uebung_id'),
              r.read<int>('uebung_pos'),
              r.read<int>('satz_nr'),
            ),
        ],
        [('dips', 1, 1), ('dips', 1, 2), ('benchPress', 2, 1)],
      );
    });

    test('Der Zeitpunkt der Sitzung bleibt der Zeitpunkt, als UTC', () async {
      final alt = sitzung('ALT', DateTime.utc(2099, 1, 14, 23, 30));

      await ablage.uebernimm([alt]);

      final zurueck = (await ablage.sitzung('ALT'))!;
      expect(zurueck.date, alt.date);
      expect(zurueck.date.isUtc, isTrue);
      final tag = await db.customSelect("SELECT tag FROM gym_sitzungen;").get();
      expect(
        tag.single.read<String>('tag'),
        '2099-01-15',
        reason: '23:30 UTC ist 00:30 Berliner Zeit am Folgetag',
      );
    });

    test('Eine Übernahme ohne Sitzung tut nichts und wirft nicht', () async {
      final ergebnis = await ablage.uebernimm(const []);

      expect(ergebnis.geschrieben, isEmpty);
      expect(ergebnis.uebersprungen, isEmpty);
      expect(await alleZeilen(), isEmpty);
    });

    test('Der Bericht nennt die Geschriebenen in der Reihenfolge der Eingabe '
        'und gibt die Objekte unverändert zurück', () async {
      final z = sitzung('Z', DateTime.utc(2099, 1, 25, 9), workout: Workout.b);
      final a = sitzung('A', tag14());
      final m = sitzung('M', DateTime.utc(2099, 1, 20, 9), workout: Workout.c);

      final ergebnis = await ablage.uebernimm([z, a, m]);

      expect(ergebnis.geschrieben, [z, a, m]);
    });
  });

  group('was die Übernahme nicht anfasst', () {
    test('Der angefangene Entwurf bleibt stehen', () async {
      final entwurf = GymEntwurf(
        workout: Workout.c,
        sitzungId: 'ENTWURF-1',
        zeitpunkt: tag14(),
        dauer: '35',
        notiz: 'halb fertig',
        gespeichertAm: tag14(9, 20),
        felder: '{"benchPress":[{"w":"60","r":"10","done":true}]}',
      );
      await ablage.speichereEntwurf(entwurf);

      await ablage.uebernimm([sitzung('ALT', tag14(), workout: Workout.c)]);

      expect(
        await ablage.entwurf(),
        entwurf,
        reason: 'Ein laufendes Training ist keine abgeschlossene Sitzung — '
            'die Übernahme darf es weder löschen noch abschließen',
      );
    });
  });

  group('Hunderte Sitzungen', () {
    test('300 Sitzungen kommen an, ohne dass etwas fehlt', () async {
      final datei = [
        for (var i = 0; i < 300; i++)
          sitzung(
            'S-$i',
            DateTime.utc(2099, 1, 1, 9).add(Duration(days: i)),
            workout: Workout.values[i % Workout.values.length],
            uebungen: [
              for (final u in ['benchPress', 'dips', 'lateralRaise'])
                ImportedExercise(
                  exerciseId: u,
                  sets: [
                    CompletedSet(weight: 20.0 + i % 7, reps: 10),
                    CompletedSet(weight: 20.0 + i % 7, reps: 9),
                    CompletedSet(weight: 20.0 + i % 7, reps: 8),
                  ],
                ),
            ],
          ),
      ];

      final ergebnis = await ablage.uebernimm(datei);

      expect(ergebnis.geschrieben.length, 300);
      expect(ergebnis.uebersprungen, isEmpty);
      expect((await ablage.sitzungen()).length, 300);
      final saetze = await db
          .customSelect('SELECT COUNT(*) AS n FROM gym_saetze;')
          .getSingle();
      expect(saetze.read<int>('n'), 2700);
    });
  });
}
