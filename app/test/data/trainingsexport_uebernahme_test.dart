import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/data/gym_repository.dart';
import 'package:repit/uebernahme/trainingsexport_uebernahme.dart';

import '../uebernahme/export_fixtur.dart';

/// Tests für `uebernimmTrainingsexport` — **Datei rein, Bericht raus**: Die
/// Funktion, die Bytes einer Exportdatei liest (`jsonDecode`,
/// `TrainingsExport.read`), die Ablage schreiben lässt und Tim sagt, was
/// passiert ist (#59 Teil 1, mit #482).
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden. Geschrieben aus
/// `docs/superpowers/specs/2026-11-11-gym-uebernahme-design.md`, Abschnitte
/// 6, 9 und 10, **ohne** den späteren Code gesehen zu haben.
///
/// ## Festgelegte API — Entscheidung des Test-Agenten, nicht von Tim
///
/// ```dart
/// Future<TrainingsexportErgebnis> uebernimmTrainingsexport(
///     GymRepository ablage, Uint8List bytes);
///
/// sealed class TrainingsexportErgebnis {}
///
/// final class TrainingsexportAbgelehnt extends TrainingsexportErgebnis {
///   final ExportRejection grund;     // aus dem Kern; NotJson baut diese Funktion
/// }
///
/// final class TrainingsexportUebernommen extends TrainingsexportErgebnis {
///   final DateTime erzeugtAm;                 // `generated` der Datei, UTC
///   final String zeitzone;                    // `timezone` der Datei
///   final List<ImportedSession> geschrieben;  // neu in der Ablage
///   final List<GymImportSkip> uebersprungen;  // vom Planer, mit Grund
///   final List<ExportSessionSkip> nichtLesbar;// vom Leser, mit Position
///   final List<String> unbekannteUebungen;    // aus der Datei, sortiert
///   final List<String> unbekannteWorkouts;    // aus der Datei, sortiert
///   final Map<String, int> ungelesen;         // `ExportRead.unread`
///
///   int get inDatei;            // geschrieben + uebersprungen + nichtLesbar
///   int get neu;                // geschrieben.length
///   int get schonDa;            // uebersprungen mit alreadyPresent
///   int get nichtUebernommen;   // uebersprungen mit allem anderen
///   int get saetze;             // Sätze der geschriebenen Sitzungen
///   String? get ersterTag;      // ISO-Berliner Tag der ältesten geschriebenen
///   String? get letzterTag;     // … der jüngsten; beide null, wenn keine
/// }
/// ```
///
/// **Die Zahlen gehen auf:** `inDatei == neu + schonDa + nichtUebernommen +
/// nichtLesbar`. Eine Zahl ohne Erklärung ist keine Antwort (Auftrag); eine
/// Summe, die nicht aufgeht, ist keine Erklärung.
///
/// Die Funktion wirft für **Dateien** nie — eine kaputte, fremde oder zu
/// alte Datei ist ein Ergebnis, kein Absturz. Wirft die **Ablage**
/// (Platte voll), kommt der Fehler heraus; den fängt der Schirm.
///
/// Alle Daten erfunden, Jahr 2099 (Berliner Winterzeit, UTC+1).
void main() {
  late AppCache db;
  late GymRepository ablage;

  setUp(() {
    db = AppCache(NativeDatabase.memory());
    ablage = GymRepository(db);
  });
  tearDown(() => db.close());

  TrainingsexportUebernommen uebernommen(TrainingsexportErgebnis e) {
    expect(e, isA<TrainingsexportUebernommen>(), reason: '$e');
    return e as TrainingsexportUebernommen;
  }

  TrainingsexportAbgelehnt abgelehnt(TrainingsexportErgebnis e) {
    expect(e, isA<TrainingsexportAbgelehnt>(), reason: '$e');
    return e as TrainingsexportAbgelehnt;
  }

  Future<int> anzahlSitzungen() async =>
      (await db.customSelect('SELECT COUNT(*) AS n FROM gym_sitzungen;').getSingle())
          .read<int>('n');

  Future<int> anzahlSaetze() async =>
      (await db.customSelect('SELECT COUNT(*) AS n FROM gym_saetze;').getSingle())
          .read<int>('n');

  Future<List<Map<String, Object?>>> alles() async => [
    for (final t in ['gym_sitzungen', 'gym_saetze'])
      ...[
        for (final r in await db.customSelect('SELECT * FROM $t ORDER BY 1, 2, 3;').get())
          Map<String, Object?>.from(r.data),
      ],
  ];

  /// Drei Sitzungen: Gym A am 10.01., Gym B am 12.01., „kein Workout" am
  /// 14.01. mit einer unbekannten Übung.
  List<Object?> dreiSitzungen() => [
    rohSitzung(id: 'S-A', datum: zeit(10), workout: 'A', minuten: 55),
    rohSitzung(id: 'S-B', datum: zeit(12), workout: 'B', notiz: 'Erfunden'),
    rohSitzung(
      id: 'S-X',
      datum: zeit(14),
      uebungen: [
        rohUebung('ghostLift', [rohSatz(10, 10)]),
        rohBank(),
      ],
    ),
  ];

  group('eine gute Datei', () {
    test('Der Bericht nennt, was ankam — und die Summe geht auf', () async {
      final e = uebernommen(
        await uebernimmTrainingsexport(
          ablage,
          alsBytes(exportDatei(sitzungen: dreiSitzungen())),
        ),
      );

      expect(e.inDatei, 3);
      expect(e.neu, 3);
      expect(e.schonDa, 0);
      expect(e.nichtUebernommen, 0);
      expect(e.nichtLesbar, isEmpty);
      expect(
        e.inDatei,
        e.neu + e.schonDa + e.nichtUebernommen + e.nichtLesbar.length,
      );
      expect(await anzahlSitzungen(), 3);
    });

    test('Sätze, Zeitraum, Zeitzone und Erzeugungszeitpunkt', () async {
      final e = uebernommen(
        await uebernimmTrainingsexport(
          ablage,
          alsBytes(
            exportDatei(
              sitzungen: dreiSitzungen(),
              erzeugt: '2099-02-01T08:30:00Z',
            ),
          ),
        ),
      );

      expect(e.saetze, 7, reason: '2 + 2 + (1 + 2) Sätze');
      expect(e.ersterTag, '2099-01-10');
      expect(e.letzterTag, '2099-01-14');
      expect(e.zeitzone, 'Europe/Berlin');
      expect(e.erzeugtAm, DateTime.utc(2099, 2, 1, 8, 30));
      expect(await anzahlSaetze(), 7);
    });

    test('Der Zeitraum ist der der **geschriebenen** Sitzungen: Berliner Tag, '
        'nicht UTC-Tag', () async {
      // 23:30 UTC am 14.01. ist 00:30 Berliner Zeit am 15.01.
      final e = uebernommen(
        await uebernimmTrainingsexport(
          ablage,
          alsBytes(
            exportDatei(
              sitzungen: [
                rohSitzung(id: 'NACHT', datum: zeit(14, 23, 30), workout: 'A'),
              ],
            ),
          ),
        ),
      );

      expect(e.ersterTag, '2099-01-15');
      expect(e.letzterTag, '2099-01-15');
    });

    test('Unbekannte Übungen und Workouts werden genannt, nicht verschluckt',
        () async {
      final e = uebernommen(
        await uebernimmTrainingsexport(
          ablage,
          alsBytes(
            exportDatei(
              sitzungen: [
                ...dreiSitzungen(),
                rohSitzung(id: 'S-G', datum: zeit(15), workout: 'gymA'),
              ],
            ),
          ),
        ),
      );

      expect(e.unbekannteUebungen, ['ghostLift']);
      expect(e.unbekannteWorkouts, ['gymA']);
      expect(
        await anzahlSitzungen(),
        4,
        reason: 'Die Sitzung mit dem unbekannten Workout kommt an — ohne '
            'Workout, aber sie kommt an',
      );
    });

    test('Was dieser Schritt nicht liest, steht in `ungelesen`', () async {
      final e = uebernommen(
        await uebernimmTrainingsexport(
          ablage,
          alsBytes(
            exportDatei(
              sitzungen: dreiSitzungen(),
              uebrige: {
                'swaps': [
                  {'week': 3, 'first': 'Di', 'second': 'Do'},
                  {'week': 4, 'first': 'Mo', 'second': 'Mi'},
                ],
                'dashboardImport': [
                  {
                    'sessions': [
                      rohSitzung(id: 'D1', datum: zeit(2)),
                      rohSitzung(id: 'D2', datum: zeit(3)),
                    ],
                    'scales': <Object?>[],
                    'circumferences': <Object?>[],
                  },
                ],
              },
            ),
          ),
        ),
      );

      expect(e.ungelesen, {'swaps': 2, 'dashboardImport.sessions': 2});
      expect(
        await anzahlSitzungen(),
        3,
        reason: 'Die Dashboard-Sitzungen werden in diesem Schritt nicht '
            'geschrieben',
      );
    });

    test('Eine Datei ohne ein Training ist gültig: nichts zu übernehmen, '
        'nichts abgelehnt', () async {
      final e = uebernommen(
        await uebernimmTrainingsexport(ablage, alsBytes(exportDatei())),
      );

      expect(e.inDatei, 0);
      expect(e.neu, 0);
      expect(e.saetze, 0);
      expect(e.ersterTag, isNull);
      expect(e.letzterTag, isNull);
      expect(await anzahlSitzungen(), 0);
    });
  });

  group('die Zahlen gehen auf — jede Sitzung der Datei hat ein Schicksal', () {
    test('neu, schon da, Tag belegt, Dublette, nicht lesbar', () async {
      // Schon in der Ablage: eine übernommene (gleiche Kennung) und ein
      // Training, das Tim selbst eingetragen hat (anderer Tag und Workout
      // als alles in der Datei, bis auf eine Sitzung).
      await ablage.legeAb(
        ImportedSession(
          id: 'S-PRESENT',
          date: DateTime.utc(2099, 1, 5, 9),
          workout: Workout.c,
          minutes: null,
          note: null,
          exercises: [
            ImportedExercise(
              exerciseId: 'dips',
              sets: [CompletedSet(weight: 0, reps: 10)],
            ),
          ],
        ),
      );
      await ablage.legeAb(
        ImportedSession(
          id: 'EIGEN',
          date: DateTime.utc(2099, 1, 7, 9, 30),
          workout: Workout.d,
          minutes: 40,
          note: null,
          warmUp: const WarmUpSkipped(),
          exercises: [
            ImportedExercise(
              exerciseId: 'dips',
              sets: [
                CompletedSet(
                  weight: 0,
                  reps: 10,
                  recordedAt: DateTime.utc(2099, 1, 7, 9, 10),
                ),
              ],
            ),
          ],
        ),
      );

      final e = uebernommen(
        await uebernimmTrainingsexport(
          ablage,
          alsBytes(
            exportDatei(
              sitzungen: [
                rohSitzung(id: 'S-NEU', datum: zeit(10), workout: 'A'),
                rohSitzung(id: 'S-PRESENT', datum: zeit(5), workout: 'C'),
                rohSitzung(id: 'S-BELEGT', datum: zeit(7, 0), workout: 'D'),
                rohSitzung(id: 'S-D1', datum: zeit(12, 8), workout: 'B'),
                rohSitzung(id: 'S-D2', datum: zeit(12, 18), workout: 'B'),
                rohSitzung(id: 'S-KAPUTT', datum: 'nie', workout: 'A'),
              ],
            ),
          ),
        ),
      );

      expect(e.inDatei, 6);
      expect(e.neu, 2, reason: 'S-NEU und S-D2 (die spätere der Dubletten)');
      expect(e.schonDa, 1);
      expect(e.nichtUebernommen, 2, reason: 'S-BELEGT und S-D1');
      expect(e.nichtLesbar.length, 1);
      expect(
        e.inDatei,
        e.neu + e.schonDa + e.nichtUebernommen + e.nichtLesbar.length,
      );

      expect(e.geschrieben.map((s) => s.id).toSet(), {'S-NEU', 'S-D2'});
      expect(
        {for (final s in e.uebersprungen) s.session.id: s.reason},
        {
          'S-PRESENT': GymImportSkipReason.alreadyPresent,
          'S-BELEGT': GymImportSkipReason.dayAndWorkoutTaken,
          'S-D1': GymImportSkipReason.duplicateInFile,
        },
      );
      expect(e.nichtLesbar.single.id, 'S-KAPUTT');
      expect(e.nichtLesbar.single.index, 5);
      expect(e.nichtLesbar.single.reason, ExportSkipReason.malformed);

      // Das selbst Eingetragene steht noch da, samt Uhrzeit und Aufwärmen.
      final eigen = (await ablage.sitzung('EIGEN'))!;
      expect(eigen.warmUp, const WarmUpSkipped());
      expect(eigen.minutes, 40);
      expect(eigen.exercises.single.sets.single.recordedAt,
          DateTime.utc(2099, 1, 7, 9, 10));
    });

    test('eine einzelne kaputte Sitzung hält die übrigen nicht auf — und kippt '
        'den Lauf nicht zurück', () async {
      // Wiederholungen 0: Die Ablage würde werfen. Der Leser filtert vorher,
      // damit ein Fehler in einer Sitzung nicht alle anderen mitnimmt.
      final e = uebernommen(
        await uebernimmTrainingsexport(
          ablage,
          alsBytes(
            exportDatei(
              sitzungen: [
                rohSitzung(id: 'GUT-1', datum: zeit(10), workout: 'A'),
                rohSitzung(
                  id: 'NULL-WDH',
                  datum: zeit(11),
                  workout: 'B',
                  uebungen: [
                    rohUebung('dips', [rohSatz(0, 0)]),
                  ],
                ),
                rohSitzung(
                  id: 'DOPPELT',
                  datum: zeit(12),
                  workout: 'C',
                  uebungen: [
                    rohUebung('dips', [rohSatz(0, 5)]),
                    rohUebung('dips', [rohSatz(0, 6)]),
                  ],
                ),
                rohSitzung(id: 'GUT-2', datum: zeit(13), workout: 'D'),
              ],
            ),
          ),
        ),
      );

      expect(e.geschrieben.map((s) => s.id), ['GUT-1', 'GUT-2']);
      expect(e.nichtLesbar.map((s) => s.id), ['NULL-WDH', 'DOPPELT']);
      expect(e.nichtLesbar.map((s) => s.reason), [
        ExportSkipReason.repsNotPositive,
        ExportSkipReason.duplicateExercise,
      ]);
      expect(await anzahlSitzungen(), 2);
    });
  });

  group('zweimal dieselbe Datei', () {
    test('der zweite Lauf schreibt nichts: alles „schon da", derselbe '
        'Stand', () async {
      final bytes = alsBytes(exportDatei(sitzungen: dreiSitzungen()));

      final erster = uebernommen(await uebernimmTrainingsexport(ablage, bytes));
      final stand = await alles();
      final zweiter = uebernommen(
        await uebernimmTrainingsexport(ablage, bytes),
      );

      expect(erster.neu, 3);
      expect(zweiter.neu, 0);
      expect(zweiter.schonDa, 3);
      expect(zweiter.nichtUebernommen, 0);
      expect(zweiter.nichtLesbar, isEmpty);
      expect(zweiter.inDatei, 3);
      expect(zweiter.saetze, 0);
      expect(zweiter.ersterTag, isNull);
      expect(await alles(), stand);
    });

    test('eine spätere Datei mit einer neuen Sitzung bringt genau die eine',
        () async {
      await uebernimmTrainingsexport(
        ablage,
        alsBytes(exportDatei(sitzungen: dreiSitzungen())),
      );

      final zweiter = uebernommen(
        await uebernimmTrainingsexport(
          ablage,
          alsBytes(
            exportDatei(
              sitzungen: [
                ...dreiSitzungen(),
                rohSitzung(id: 'S-NEU', datum: zeit(20), workout: 'C'),
              ],
            ),
          ),
        ),
      );

      expect(zweiter.geschrieben.map((s) => s.id), ['S-NEU']);
      expect(zweiter.schonDa, 3);
      expect(await anzahlSitzungen(), 4);
    });
  });

  group('#482 — ein selbst eingetragenes Training bleibt', () {
    test('Die Sitzung der Datei am selben Tag mit demselben Workout wird '
        'übersprungen, und der Bericht nennt sie', () async {
      final eigen = ImportedSession(
        id: 'EIGEN',
        date: DateTime.utc(2099, 1, 14, 9, 40),
        workout: Workout.a,
        minutes: 61,
        note: 'Erfundene Notiz',
        warmUp: const WarmUpDone(kind: WarmUpKind.rowing, minutes: 6),
        exercises: [
          ImportedExercise(
            exerciseId: 'benchPress',
            sets: [
              CompletedSet(
                weight: 65,
                reps: 6,
                recordedAt: DateTime.utc(2099, 1, 14, 9, 12),
              ),
            ],
          ),
        ],
      );
      await ablage.legeAb(eigen);
      final vorher = await alles();

      final e = uebernommen(
        await uebernimmTrainingsexport(
          ablage,
          alsBytes(
            exportDatei(
              sitzungen: [
                rohSitzung(
                  id: 'ALT',
                  datum: '2099-01-13T23:00:00Z',
                  workout: 'A',
                  uebungen: [
                    rohUebung('benchPress', [rohSatz(20, 20)]),
                  ],
                ),
                rohSitzung(id: 'ANDERER-TAG', datum: zeit(16), workout: 'A'),
              ],
            ),
          ),
        ),
      );

      expect(e.nichtUebernommen, 1);
      expect(e.uebersprungen.single.session.id, 'ALT');
      expect(
        e.uebersprungen.single.reason,
        GymImportSkipReason.dayAndWorkoutTaken,
      );
      expect(e.geschrieben.map((s) => s.id), ['ANDERER-TAG']);
      expect(await ablage.sitzung('EIGEN'), eigen);
      expect(await ablage.sitzung('ALT'), isNull);
      final nachher = await alles();
      for (final z in vorher) {
        expect(nachher, anyElement(equals(z)));
      }
    });
  });

  group('eine Datei, die nicht gelesen wird: benannt, und nichts geschrieben',
      () {
    Future<void> nichtsGeschrieben() async {
      expect(await anzahlSitzungen(), 0);
      expect(await anzahlSaetze(), 0);
    }

    test('Kein JSON: `NotJson` mit einer Angabe, wo es hakt', () async {
      final bytes = Uint8List.fromList('{ "format": "trainingsexport", '.codeUnits);

      final a = abgelehnt(await uebernimmTrainingsexport(ablage, bytes));

      expect(a.grund, isA<NotJson>());
      expect((a.grund as NotJson).detail, isNotEmpty);
      await nichtsGeschrieben();
    });

    test('Eine abgeschnittene Datei ist **kein halber Import**: Auch wenn die '
        'ersten Sitzungen vollständig dastehen, wird nichts geschrieben',
        () async {
      final voll = alsBytes(exportDatei(sitzungen: dreiSitzungen()));
      final abgeschnitten = Uint8List.sublistView(voll, 0, voll.length ~/ 2);

      final a = abgelehnt(
        await uebernimmTrainingsexport(ablage, abgeschnitten),
      );

      expect(a.grund, isA<NotJson>());
      await nichtsGeschrieben();
    });

    test('Leere Datei: `NotJson`', () async {
      final a = abgelehnt(
        await uebernimmTrainingsexport(ablage, Uint8List(0)),
      );

      expect(a.grund, isA<NotJson>());
      await nichtsGeschrieben();
    });

    test('Keine Zeichen, sondern Bytes (ungültiges UTF-8): `NotJson`, kein '
        'Absturz', () async {
      final a = abgelehnt(
        await uebernimmTrainingsexport(
          ablage,
          Uint8List.fromList([0xff, 0xfe, 0x00, 0xc3, 0x28]),
        ),
      );

      expect(a.grund, isA<NotJson>());
      expect((a.grund as NotJson).detail, isNotEmpty);
      await nichtsGeschrieben();
    });

    test('JSON, aber kein Objekt: `NotAnObject`', () async {
      final a = abgelehnt(
        await uebernimmTrainingsexport(ablage, alsBytes(<Object?>[])),
      );

      expect(a.grund, isA<NotAnObject>());
      await nichtsGeschrieben();
    });

    test('Fremdes Format: Das Format des Web-Dashboards wird benannt', () async {
      final a = abgelehnt(
        await uebernimmTrainingsexport(
          ablage,
          alsBytes(
            exportDatei(
              format: 'dashboard-manual-export',
              sitzungen: dreiSitzungen(),
            ),
          ),
        ),
      );

      expect(
        a.grund,
        isA<WrongFormat>().having(
          (g) => g.found,
          'found',
          'dashboard-manual-export',
        ),
      );
      await nichtsGeschrieben();
    });

    test('Fassung 1: abgelehnt mit der gefundenen Nummer', () async {
      final a = abgelehnt(
        await uebernimmTrainingsexport(ablage, alsBytes(fassungEins())),
      );

      expect(
        a.grund,
        isA<UnsupportedVersion>().having((g) => g.found, 'found', 1),
      );
      await nichtsGeschrieben();
    });

    test('Fassung 1 mit Sitzungen im Block `app` wird nicht als Fassung 2 '
        'gelesen', () async {
      final a = abgelehnt(
        await uebernimmTrainingsexport(
          ablage,
          alsBytes(exportDatei(version: 1, sitzungen: dreiSitzungen())),
        ),
      );

      expect(a.grund, isA<UnsupportedVersion>());
      await nichtsGeschrieben();
    });

    test('Ohne `app.sessions`: `MalformedField`, nicht „nie trainiert"',
        () async {
      final a = abgelehnt(
        await uebernimmTrainingsexport(
          ablage,
          alsBytes(
            exportDatei(
              stand: {
                'circumferences': <Object?>[],
                'swaps': <Object?>[],
                'drafts': <Object?>[],
                'dataWindow': <Object?>[],
                'dashboardImport': <Object?>[],
              },
            ),
          ),
        ),
      );

      expect(
        a.grund,
        isA<MalformedField>().having((g) => g.field, 'field', 'app.sessions'),
      );
      await nichtsGeschrieben();
    });

    test('Eine abgelehnte Datei lässt Vorhandenes unberührt', () async {
      await ablage.legeAb(
        ImportedSession(
          id: 'EIGEN',
          date: DateTime.utc(2099, 1, 14, 9, 40),
          workout: Workout.a,
          minutes: 61,
          note: null,
          exercises: [
            ImportedExercise(
              exerciseId: 'dips',
              sets: [CompletedSet(weight: 0, reps: 10)],
            ),
          ],
        ),
      );
      final vorher = await alles();

      await uebernimmTrainingsexport(ablage, alsBytes(fassungEins()));
      await uebernimmTrainingsexport(ablage, Uint8List(0));

      expect(await alles(), vorher);
    });
  });
}
