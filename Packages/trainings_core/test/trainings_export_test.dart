import 'dart:convert';

import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für `TrainingsExport.read` — den Leser der Datei, die die
/// eingefrorene Swift-App herausgibt (`AppExport`, Format `trainingsexport`
/// Fassung 2), soweit sie **Gym-Trainings** trägt (#59 Teil 1).
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden. Geschrieben aus
/// `docs/superpowers/specs/2026-11-11-gym-uebernahme-design.md`, Abschnitte
/// 2 und 6, und aus `AppExport.swift` samt `AppExportTests.swift` — **ohne**
/// den späteren Code gesehen zu haben.
///
/// ## Was der Leser ist
///
/// Eine reine Funktion über bereits **dekodiertes** JSON (`Object?`). Der
/// Kern importiert nur `dart:core` und `dart:math` und kennt `dart:convert`
/// deshalb nicht; `jsonDecode` ruft die App. Der Leser wirft **nie**: Alles,
/// was an der Datei nicht stimmt, kommt als Wert zurück — als
/// [ExportRejected] (die ganze Datei taugt nicht) oder als
/// [ExportSessionSkip] (eine Sitzung taugt nicht, die übrigen werden
/// gelesen).
///
/// ## Die Regeln, die hier festgenagelt werden
///
/// - **Stillschweigend verwerfen ist der Fehler** (#59). Jede Datei, die
///   nicht gelesen wird, wird mit dem benannt, was stattdessen dastand.
/// - **Fehlend ist nicht leer.** `app.sessions` fehlt → die Datei ist
///   kaputt; `app.sessions: []` → Tim hat nie trainiert. Eine Datei der
///   Fassung 1 darf nicht als „leere Fassung 2" durchlaufen
///   (`AppExport.swift`: „ohne Anfangswert, damit das Feld wirklich gelesen
///   wird").
/// - **Swift schreibt `nil` als fehlenden Schlüssel**, nicht als `null`
///   (`Codable` lässt Optionale weg). Beides muss dasselbe heißen.
/// - **Nichts wird erfunden**: keine Satz-Uhrzeit, kein Aufwärmen. Ein
///   unbekanntes Workout wird `null` — und **genannt**.
/// - **Eine kaputte Sitzung vergiftet die übrigen nicht**, und sie
///   verschwindet nicht: Sie steht mit Position und Grund in `skipped`.
///
/// Alle Namen, Zahlen und Zeitpunkte sind erfunden (Jahr 2099).
///
/// ## Nachtrag vom 11.11.2026 (#498) — `TEST_AENDERN=1`
///
/// Ein Fall dieser Datei wurde geändert: `circumferences` steht seit #498
/// **nicht mehr** in `unread`, weil die Umfänge jetzt gelesen werden. Ein
/// Bericht, der Gelesenes als ungelesen meldet, wäre falsch. Geändert wurde
/// nur die Erwartung an `unread` im Fall „… Stände erscheinen mit ihrer
/// Anzahl in `unread`"; alles andere steht unverändert. Was die Umfänge
/// angeht, prüft `trainings_export_umfaenge_test.dart`.
///
/// **Tim hat diese Änderung nicht gesehen.** Sie stammt vom Test-Agenten
/// zu #498, nicht von ihm — und sie ist unvermeidlich: Ohne sie wäre der
/// Fall nach der Umsetzung rot, und niemand dürfte ihn dann noch anfassen.
void main() {
  /* ---- Fixturen ------------------------------------------------------ */

  /// Ein Satz so, wie er in der Datei steht.
  Map<String, Object?> rohSatz(Object? weight, Object? reps) => {
    'weight': weight,
    'reps': reps,
  };

  Map<String, Object?> rohUebung(String id, List<Object?> saetze) => {
    'exerciseID': id,
    'sets': saetze,
  };

  /// Eine Sitzung. **Felder, die `null` sind, fehlen** — so schreibt Swift
  /// sie; [mitNull] schreibt sie stattdessen ausdrücklich als `null`.
  Map<String, Object?> rohSitzung({
    String id = 'S1',
    Object? date = '2099-01-14T09:00:00Z',
    Object? workout,
    Object? minutes,
    Object? note,
    Object? exercises,
    bool mitNull = false,
  }) {
    final m = <String, Object?>{
      'id': id,
      'date': date,
      'exercises':
          exercises ??
          [
            rohUebung('benchPress', [rohSatz(60, 10), rohSatz(62.5, 8)]),
          ],
    };
    void setze(String k, Object? v) {
      if (v != null || mitNull) m[k] = v;
    }

    setze('workout', workout);
    setze('minutes', minutes);
    setze('note', note);
    return m;
  }

  /// Die ganze Hülle. [app] ersetzt den Block, [sitzungen] füllt nur
  /// `app.sessions`.
  Map<String, Object?> datei({
    Object? format = 'trainingsexport',
    Object? version = 2,
    Object? generated = '2099-02-01T08:30:00Z',
    Object? timezone = 'Europe/Berlin',
    List<Object?> sitzungen = const [],
    Map<String, Object?>? app,
  }) {
    final m = <String, Object?>{
      'format': format,
      'version': version,
      'generated': generated,
      'timezone': timezone,
      'app':
          app ??
          {
            'sessions': sitzungen,
            'circumferences': <Object?>[],
            'swaps': <Object?>[],
            'drafts': <Object?>[],
            'dataWindow': <Object?>[],
            'dashboardImport': <Object?>[],
          },
    };
    return m;
  }

  /// Schickt die Struktur durch echtes JSON, damit Zahlen die Typen haben,
  /// die `jsonDecode` ihnen gibt (`60` ist `int`, `62.5` ist `double`).
  Object? ueberJson(Object? wert) => jsonDecode(jsonEncode(wert));

  ExportReading lies(Object? wert) => TrainingsExport.read(ueberJson(wert));

  ExportRead gelesen(Object? wert) {
    final r = lies(wert);
    expect(r, isA<ExportRead>(), reason: 'erwartet: Datei wird gelesen');
    return r as ExportRead;
  }

  ExportRejection abgelehnt(Object? wert) {
    final r = lies(wert);
    expect(r, isA<ExportRejected>(), reason: 'erwartet: Datei wird abgelehnt');
    return (r as ExportRejected).reason;
  }

  group('Konstanten', () {
    test('Formatname und Fassung stehen wörtlich wie in AppExport.swift', () {
      expect(TrainingsExport.formatName, 'trainingsexport');
      expect(TrainingsExport.currentVersion, 2);
    });
  });

  group('Ablehnung: die ganze Datei taugt nicht — und sagt warum', () {
    test('Kein Objekt (Liste, Zeichenkette, Zahl, null): `NotAnObject`', () {
      for (final wert in <Object?>[
        <Object?>[],
        [datei()],
        'trainingsexport',
        42,
        null,
        true,
      ]) {
        expect(
          TrainingsExport.read(wert),
          isA<ExportRejected>().having(
            (r) => r.reason,
            'reason',
            isA<NotAnObject>(),
          ),
          reason: '$wert',
        );
      }
    });

    test('Ohne `format`: `WrongFormat(null)`', () {
      final m = datei();
      m.remove('format');

      expect(
        abgelehnt(m),
        isA<WrongFormat>().having((r) => r.found, 'found', isNull),
      );
    });

    test('Fremdes Format wird **benannt**: das Format des Web-Dashboards ist '
        'nicht diese Datei', () {
      expect(
        abgelehnt(datei(format: 'dashboard-manual-export')),
        isA<WrongFormat>().having(
          (r) => r.found,
          'found',
          'dashboard-manual-export',
        ),
      );
    });

    test('Groß- und Kleinschreibung gilt: „Trainingsexport" wird nicht '
        'erraten', () {
      expect(
        abgelehnt(datei(format: 'Trainingsexport')),
        isA<WrongFormat>().having((r) => r.found, 'found', 'Trainingsexport'),
      );
    });

    test('`format` ist keine Zeichenkette: `WrongFormat`', () {
      expect(abgelehnt(datei(format: 7)), isA<WrongFormat>());
    });

    test('Fassung 1 wird **abgelehnt und benannt** — sie läuft nicht als '
        'leere Fassung 2 durch', () {
      // Die Gestalt der Fassung 1 steht in `AppExportTests.swift`: kein
      // Block `app`, dafür `days`, `meals`, `workouts`, `sleep`.
      final fassungEins = <String, Object?>{
        'format': 'trainingsexport',
        'version': 1,
        'generated': '2099-03-01T09:15:00Z',
        'timezone': 'Europe/Berlin',
        'from': '2099-02-28',
        'to': '2099-03-01',
        'days': <Object?>[],
        'meals': <Object?>[],
        'workouts': <Object?>[],
        'sleep': <Object?>[],
      };

      final grund = abgelehnt(fassungEins);

      expect(
        grund,
        isA<UnsupportedVersion>().having((r) => r.found, 'found', 1),
        reason:
            'Der Grund ist die Fassung, nicht „der Block `app` fehlt" — '
            'sonst suchte der Nutzer den Fehler am falschen Ende',
      );
    });

    test('Fassung 1 mit einem Block `app` wird **nicht** als Fassung 2 '
        'gelesen', () {
      // Die Nummer wird gelesen, nicht gesetzt (`AppExportTests.swift`:
      // „Die Fassungsnummer wird gelesen").
      expect(
        lies(datei(version: 1, sitzungen: [rohSitzung()])),
        isA<ExportRejected>().having(
          (r) => r.reason,
          'reason',
          isA<UnsupportedVersion>(),
        ),
      );
    });

    test('Eine neuere Fassung wird ebenfalls abgelehnt: Was in Fassung 3 '
        'steht, weiß niemand', () {
      expect(
        abgelehnt(datei(version: 3)),
        isA<UnsupportedVersion>().having((r) => r.found, 'found', 3),
      );
    });

    test('Ohne `version`, mit Zeichenkette oder Bruchzahl: '
        '`UnsupportedVersion`, mit dem Gefundenen', () {
      final ohne = datei();
      ohne.remove('version');
      expect(
        abgelehnt(ohne),
        isA<UnsupportedVersion>().having((r) => r.found, 'found', isNull),
      );
      expect(
        abgelehnt(datei(version: '2')),
        isA<UnsupportedVersion>().having((r) => r.found, 'found', '2'),
        reason: 'Eine Zeichenkette „2" ist keine Fassung 2',
      );
      expect(abgelehnt(datei(version: 2.5)), isA<UnsupportedVersion>());
    });

    test('Reihenfolge der Prüfung: erst das Format, dann die Fassung', () {
      expect(
        abgelehnt(datei(format: 'etwas anderes', version: 1)),
        isA<WrongFormat>(),
      );
    });

    test('Reihenfolge der Prüfung: erst die Fassung, dann der Inhalt', () {
      final m = datei(version: 1);
      m.remove('app');
      m.remove('generated');

      expect(abgelehnt(m), isA<UnsupportedVersion>());
    });

    test('Kein Block `app`: `MalformedField("app")`', () {
      final m = datei();
      m.remove('app');

      expect(
        abgelehnt(m),
        isA<MalformedField>().having((r) => r.field, 'field', 'app'),
      );
    });

    test('`app` ist kein Objekt, oder ein leeres: `MalformedField`', () {
      expect(
        abgelehnt(datei(app: <String, Object?>{})),
        isA<MalformedField>().having((r) => r.field, 'field', 'app.sessions'),
        reason: 'ein leeres Objekt trägt keine `sessions`',
      );
      final m = datei();
      m['app'] = <Object?>[];
      expect(
        abgelehnt(m),
        isA<MalformedField>().having((r) => r.field, 'field', 'app'),
      );
    });

    test('`app.sessions` **fehlt**: Die Datei ist kaputt, nicht leer', () {
      final grund = abgelehnt(
        datei(
          app: {
            'circumferences': <Object?>[],
            'swaps': <Object?>[],
            'drafts': <Object?>[],
            'dataWindow': <Object?>[],
            'dashboardImport': <Object?>[],
          },
        ),
      );

      expect(
        grund,
        isA<MalformedField>().having((r) => r.field, 'field', 'app.sessions'),
        reason:
            '„Fehlend" und „leer" dürfen nicht dasselbe heißen — sonst sähe '
            'eine kaputte Datei aus wie „nie trainiert"',
      );
    });

    test('`app.sessions` ist keine Liste: `MalformedField`', () {
      for (final wert in <Object?>[
        {'a': 1},
        'x',
        3,
        null,
      ]) {
        expect(
          abgelehnt(
            datei(
              app: {
                'sessions': wert,
                'circumferences': <Object?>[],
                'swaps': <Object?>[],
                'drafts': <Object?>[],
                'dataWindow': <Object?>[],
                'dashboardImport': <Object?>[],
              },
            ),
          ),
          isA<MalformedField>().having(
            (r) => r.field,
            'field',
            'app.sessions',
          ),
          reason: '$wert',
        );
      }
    });

    test('`generated` fehlt, ist keine Zeichenkette, ist kein Zeitpunkt oder '
        'trägt keine Zone: `MalformedField("generated")`', () {
      final ohne = datei();
      ohne.remove('generated');
      for (final m in <Map<String, Object?>>[
        ohne,
        datei(generated: 5),
        datei(generated: 'gestern'),
        datei(generated: '2099-02-01T08:30:00'),
        datei(generated: '2099-02-01'),
      ]) {
        expect(
          abgelehnt(m),
          isA<MalformedField>().having((r) => r.field, 'field', 'generated'),
          reason: '${m['generated']}',
        );
      }
    });

    test('`timezone` fehlt oder ist keine Zeichenkette: '
        '`MalformedField("timezone")`', () {
      final ohne = datei();
      ohne.remove('timezone');
      for (final m in <Map<String, Object?>>[ohne, datei(timezone: 1)]) {
        expect(
          abgelehnt(m),
          isA<MalformedField>().having((r) => r.field, 'field', 'timezone'),
        );
      }
    });

    test('Der Leser wirft nie — auch nicht bei wilden Eingaben', () {
      final wilde = <Object?>[
        <String, Object?>{},
        {'format': null},
        {'format': 'trainingsexport', 'version': 2},
        {'format': 'trainingsexport', 'version': 2, 'app': null},
        {
          'format': 'trainingsexport',
          'version': 2,
          'generated': '2099-02-01T08:30:00Z',
          'timezone': 'Europe/Berlin',
          'app': {
            'sessions': [null, <Object?>[], 'x', 3, {}],
          },
        },
        {
          'format': 'trainingsexport',
          'version': 2,
          'generated': '2099-02-01T08:30:00Z',
          'timezone': 'Europe/Berlin',
          'app': {
            'sessions': <Object?>[],
            'dashboardImport': 'kaputt',
            'swaps': {'a': 1},
            'drafts': 7,
          },
        },
      ];
      for (final w in wilde) {
        expect(() => TrainingsExport.read(w), returnsNormally, reason: '$w');
      }
    });
  });

  group('Lesen: eine gültige Datei', () {
    test('Ohne ein Training ist gültig: leere Liste, nichts übersprungen', () {
      final r = gelesen(datei());

      expect(r.sessions, isEmpty);
      expect(r.skipped, isEmpty);
      expect(r.entryCount, 0);
      expect(r.unknownExerciseIds, isEmpty);
      expect(r.unknownWorkoutCodes, isEmpty);
      expect(r.unread, isEmpty);
    });

    test('Kopf: Erzeugungszeitpunkt (UTC) und Zeitzone werden übernommen', () {
      final r = gelesen(datei(generated: '2099-02-01T08:30:00Z'));

      expect(r.generated, DateTime.utc(2099, 2, 1, 8, 30));
      expect(r.generated.isUtc, isTrue);
      expect(r.timezone, 'Europe/Berlin');
    });

    test('Eine andere Zeitzone lehnt die Datei **nicht** ab, sie wird '
        'mitgegeben', () {
      // Die Zeitpunkte sind Zeitpunkte; der Berliner Tag wird aus ihnen
      // gerechnet. Ob das für ein Gerät in einer anderen Zone stimmt, sagt
      // der Schirm — er muss es dafür wissen.
      final r = gelesen(datei(timezone: 'America/New_York'));

      expect(r.timezone, 'America/New_York');
    });

    test('Eine Datei, **wie Swift sie schreibt**: sortierte Schlüssel, '
        '`nil` als fehlender Schlüssel, ganze Zahlen ohne Nachkomma', () {
      // So sieht `JSONEncoder` mit `.prettyPrinted`, `.sortedKeys` und
      // `.iso8601` die Hülle: Optionale ohne Wert fehlen, `60.0` steht als
      // `60`, Zeitpunkte als `…Z` ohne Sekundenbruchteil.
      const swift = r'''
{
  "app" : {
    "circumferences" : [ ],
    "dashboardImport" : [ ],
    "dataWindow" : [ ],
    "drafts" : [ ],
    "sessions" : [
      {
        "date" : "2099-01-14T09:00:00Z",
        "exercises" : [
          {
            "exerciseID" : "benchPress",
            "sets" : [
              {
                "reps" : 10,
                "weight" : 60
              },
              {
                "reps" : 8,
                "weight" : 62.5
              }
            ]
          },
          {
            "exerciseID" : "assistedPullUp",
            "sets" : [
              {
                "reps" : 6,
                "weight" : -27
              }
            ]
          }
        ],
        "id" : "SWIFT-1",
        "workout" : "A"
      },
      {
        "date" : "2099-01-16T23:00:00Z",
        "exercises" : [ ],
        "id" : "SWIFT-2",
        "minutes" : 45,
        "note" : "Erfundene Notiz"
      }
    ],
    "swaps" : [ ]
  },
  "format" : "trainingsexport",
  "generated" : "2099-02-01T08:30:00Z",
  "timezone" : "Europe/Berlin",
  "version" : 2
}
''';

      final r = TrainingsExport.read(jsonDecode(swift));

      expect(r, isA<ExportRead>());
      final gelesen = r as ExportRead;
      expect(gelesen.skipped, isEmpty);
      expect(gelesen.sessions.map((s) => s.id), ['SWIFT-1', 'SWIFT-2']);

      final eins = gelesen.sessions[0];
      expect(eins.date, DateTime.utc(2099, 1, 14, 9));
      expect(eins.workout, Workout.a);
      expect(eins.minutes, isNull, reason: 'fehlender Schlüssel ist `null`');
      expect(eins.note, isNull);
      expect(eins.exercises.map((e) => e.exerciseId), [
        'benchPress',
        'assistedPullUp',
      ]);
      expect(eins.exercises[0].sets.map((s) => (s.weight, s.reps)), [
        (60.0, 10),
        (62.5, 8),
      ]);
      expect(eins.exercises[1].sets.single.weight, -27.0);

      final zwei = gelesen.sessions[1];
      expect(zwei.workout, isNull, reason: 'fehlender Schlüssel');
      expect(zwei.minutes, 45);
      expect(zwei.note, 'Erfundene Notiz');
      expect(zwei.exercises, isEmpty);
    });

    test('Eine vollständige Sitzung: jedes Feld kommt an', () {
      final r = gelesen(
        datei(
          sitzungen: [
            rohSitzung(
              id: 'VOLL',
              date: '2099-01-14T09:00:00Z',
              workout: 'Push',
              minutes: 62,
              note: 'Erfundene Notiz',
              exercises: [
                rohUebung('benchPress', [rohSatz(60.0, 10), rohSatz(62.5, 8)]),
                rohUebung('dips', [rohSatz(0, 12)]),
              ],
            ),
          ],
        ),
      );

      final s = r.sessions.single;
      expect(s.id, 'VOLL');
      expect(s.date, DateTime.utc(2099, 1, 14, 9));
      expect(s.workout, Workout.push);
      expect(s.minutes, 62);
      expect(s.note, 'Erfundene Notiz');
      expect(s.exercises.length, 2);
      expect(s.setCount, 3);
    });

    test('Dateireihenfolge bleibt: Sitzungen, Übungen und Sätze', () {
      final r = gelesen(
        datei(
          sitzungen: [
            rohSitzung(
              id: 'Z',
              date: '2099-01-20T09:00:00Z',
              exercises: [
                rohUebung('dips', [rohSatz(5, 3), rohSatz(7, 2), rohSatz(6, 1)]),
                rohUebung('benchPress', [rohSatz(60, 10)]),
              ],
            ),
            rohSitzung(id: 'A', date: '2099-01-10T09:00:00Z'),
          ],
        ),
      );

      expect(r.sessions.map((s) => s.id), ['Z', 'A']);
      expect(r.sessions[0].exercises.map((e) => e.exerciseId), [
        'dips',
        'benchPress',
      ]);
      expect(r.sessions[0].exercises[0].sets.map((s) => s.reps), [3, 2, 1]);
    });

    test('Der Parser dedupliziert nicht: zweimal dieselbe Kennung kommen '
        'beide an — das entscheidet der Planer', () {
      final r = gelesen(
        datei(sitzungen: [rohSitzung(id: 'DUP'), rohSitzung(id: 'DUP')]),
      );

      expect(r.sessions.length, 2);
    });

    test('Zweimal gelesen ist gleich gelesen', () {
      final eingabe = datei(
        sitzungen: [
          rohSitzung(id: 'A', workout: 'B', minutes: 50, note: 'x'),
          rohSitzung(id: 'B', date: '2099-01-15T09:00:00Z'),
        ],
      );

      final a = gelesen(eingabe);
      final b = gelesen(eingabe);

      expect(a.sessions, equals(b.sessions));
      expect(a.generated, b.generated);
    });
  });

  group('Zeitpunkte', () {
    test('Der Zeitpunkt kommt als UTC an', () {
      final s = gelesen(datei(sitzungen: [rohSitzung()])).sessions.single;

      expect(s.date, DateTime.utc(2099, 1, 14, 9));
      expect(s.date.isUtc, isTrue);
    });

    test('Eine Zone mit Versatz meint denselben Zeitpunkt: 10:00 +01:00 ist '
        '09:00 UTC', () {
      final s = gelesen(
        datei(sitzungen: [rohSitzung(date: '2099-01-14T10:00:00+01:00')]),
      ).sessions.single;

      expect(s.date, DateTime.utc(2099, 1, 14, 9));
      expect(s.date.isUtc, isTrue);
    });

    test('Sekundenbruchteile sind erlaubt', () {
      final s = gelesen(
        datei(sitzungen: [rohSitzung(date: '2099-01-14T09:00:00.250Z')]),
      ).sessions.single;

      expect(s.date, DateTime.utc(2099, 1, 14, 9, 0, 0, 250));
    });

    test('Ein Zeitpunkt **ohne Zone** wird nicht geraten: Die Sitzung wird '
        'übersprungen und das Feld genannt', () {
      // `DateTime.parse` läse ihn als Ortszeit des Geräts — der Tag hinge
      // dann an der Einstellung des Telefons.
      final r = gelesen(
        datei(
          sitzungen: [
            rohSitzung(id: 'OHNE-ZONE', date: '2099-01-14T09:00:00'),
            rohSitzung(id: 'NUR-TAG', date: '2099-01-14'),
          ],
        ),
      );

      expect(r.sessions, isEmpty);
      expect(r.skipped.length, 2);
      for (final skip in r.skipped) {
        expect(skip.reason, ExportSkipReason.malformed);
        expect(skip.detail, contains('date'));
      }
    });

    test('Ein Zeitpunkt, der keiner ist, oder eine Zahl: übersprungen, '
        '`date` genannt', () {
      final r = gelesen(
        datei(
          sitzungen: [
            rohSitzung(id: 'A', date: 'gestern'),
            rohSitzung(id: 'B', date: 1700000000),
          ],
        ),
      );

      expect(r.sessions, isEmpty);
      expect(r.skipped.map((s) => s.reason).toSet(), {
        ExportSkipReason.malformed,
      });
      expect(r.skipped.every((s) => s.detail.contains('date')), isTrue);
    });
  });

  group('Felder: nichts wird erfunden, nichts wird geraten', () {
    test('Keine Satz-Uhrzeit und kein Aufwärmen: beides bleibt `null`', () {
      // Die alte App kennt keines von beiden. Ein Wert hier behauptete, der
      // Satz sei zu dieser Minute entstanden bzw. es sei aufgewärmt worden.
      final r = gelesen(
        datei(
          sitzungen: [
            rohSitzung(id: 'A', workout: 'A'),
            rohSitzung(id: 'B', date: '2099-01-15T09:00:00Z'),
          ],
        ),
      );

      for (final s in r.sessions) {
        expect(s.warmUp, isNull, reason: '${s.id}: nichts eingetragen');
        for (final u in s.exercises) {
          for (final satz in u.sets) {
            expect(
              satz.recordedAt,
              isNull,
              reason: '${s.id}: „nicht erfasst", kein erfundener Zeitstempel',
            );
          }
        }
      }
    });

    test('Workout: bekannter Code kommt an, fehlend und `null` heißen '
        '„kein Workout"', () {
      final r = gelesen(
        datei(
          sitzungen: [
            rohSitzung(id: 'A', workout: 'A'),
            rohSitzung(id: 'P', workout: 'Push'),
            rohSitzung(id: 'L', workout: 'Legs'),
            rohSitzung(id: 'FEHLT'),
            rohSitzung(id: 'NULL', mitNull: true),
          ],
        ),
      );

      expect(r.sessions.map((s) => s.workout), [
        Workout.a,
        Workout.push,
        Workout.legs,
        null,
        null,
      ]);
      expect(r.unknownWorkoutCodes, isEmpty, reason: 'null ist kein Code');
    });

    test('Unbekannter Workout-Code: die Sitzung wird gelesen, das Workout ist '
        '`null` — und der Code wird **genannt**', () {
      final r = gelesen(
        datei(
          sitzungen: [
            rohSitzung(id: 'X1', workout: 'gymA'),
            rohSitzung(id: 'X2', date: '2099-01-15T09:00:00Z', workout: 'gymA'),
            rohSitzung(id: 'X3', date: '2099-01-16T09:00:00Z', workout: 'Zirkel'),
          ],
        ),
      );

      expect(r.sessions.length, 3, reason: 'keine Sitzung geht verloren');
      expect(r.sessions.every((s) => s.workout == null), isTrue);
      expect(
        r.unknownWorkoutCodes,
        ['Zirkel', 'gymA'],
        reason: 'sortiert und ohne Dubletten — gemeldet statt verschluckt',
      );
    });

    test('Der Workout-Code unterscheidet Groß- und Kleinschreibung: „a" ist '
        'nicht „A"', () {
      final r = gelesen(datei(sitzungen: [rohSitzung(workout: 'a')]));

      expect(r.sessions.single.workout, isNull);
      expect(r.unknownWorkoutCodes, ['a']);
    });

    test('Dauer: fehlend und `null` bleiben `null`, nicht `0`', () {
      final r = gelesen(
        datei(
          sitzungen: [
            rohSitzung(id: 'A'),
            rohSitzung(id: 'B', mitNull: true),
            rohSitzung(id: 'C', minutes: 52),
          ],
        ),
      );

      expect(r.sessions.map((s) => s.minutes), [null, null, 52]);
    });

    test('Notiz: eine leere Zeichenkette gibt es nicht — sie wird `null`', () {
      final r = gelesen(
        datei(
          sitzungen: [
            rohSitzung(id: 'A', note: ''),
            rohSitzung(id: 'B'),
            rohSitzung(id: 'C', note: 'Erfundener Text'),
          ],
        ),
      );

      expect(r.sessions.map((s) => s.note), [null, null, 'Erfundener Text']);
    });

    test('Gewicht: ganze Zahlen werden Kommazahlen, das Vorzeichen bleibt, '
        'null Kilo bleibt null Kilo', () {
      final r = gelesen(
        datei(
          sitzungen: [
            rohSitzung(
              exercises: [
                rohUebung('assistedPullUp', [rohSatz(-27, 6)]),
                rohUebung('dips', [rohSatz(0, 12)]),
                rohUebung('benchPress', [rohSatz(42, 5), rohSatz(42.5, 5)]),
              ],
            ),
          ],
        ),
      );

      final u = r.sessions.single.exercises;
      expect(u[0].sets.single.weight, -27.0);
      expect(
        u[1].sets.single.weight,
        0.0,
        reason: 'Eigenes Körpergewicht ist ein Wert, keine Lücke',
      );
      expect(u[2].sets.map((s) => s.weight), [42.0, 42.5]);
    });

    test('Eine Übung ohne Sätze wird weggelassen, die Sitzung bleibt', () {
      // `legeAb` kennt keine Übung ohne Satz (sie würfe). Eine leere Hülle
      // wegzulassen nimmt nichts weg, was je trainiert wurde.
      final r = gelesen(
        datei(
          sitzungen: [
            rohSitzung(
              exercises: [
                rohUebung('dips', <Object?>[]),
                rohUebung('benchPress', [rohSatz(60, 10)]),
              ],
            ),
          ],
        ),
      );

      expect(r.skipped, isEmpty);
      expect(r.sessions.single.exercises.map((e) => e.exerciseId), [
        'benchPress',
      ]);
    });

    test('Eine Sitzung ohne jede Übung wird gelesen', () {
      final r = gelesen(
        datei(sitzungen: [rohSitzung(minutes: 30, exercises: <Object?>[])]),
      );

      expect(r.skipped, isEmpty);
      expect(r.sessions.single.exercises, isEmpty);
      expect(r.sessions.single.minutes, 30);
    });

    test('Unbekannte Übungs-IDs bleiben **in der Sitzung** und werden '
        'genannt', () {
      // Die Auswertungen übergehen eine Übung, die der Katalog nicht kennt
      // (Muskelkarte, Fortschritt); löschen darf der Import sie nicht — das
      // Gerät ist die einzige Kopie.
      final r = gelesen(
        datei(
          sitzungen: [
            rohSitzung(
              id: 'A',
              exercises: [
                rohUebung('ghostLift', [rohSatz(10, 10)]),
                rohUebung('benchPress', [rohSatz(60, 10)]),
              ],
            ),
            rohSitzung(
              id: 'B',
              date: '2099-01-15T09:00:00Z',
              exercises: [
                rohUebung('ghostLift', [rohSatz(12, 8)]),
                rohUebung('phantomPress', [rohSatz(5, 5)]),
              ],
            ),
          ],
        ),
      );

      expect(r.sessions.first.exercises.map((e) => e.exerciseId), [
        'ghostLift',
        'benchPress',
      ]);
      expect(r.unknownExerciseIds, ['ghostLift', 'phantomPress']);
    });

    test('Bekannte Katalog-IDs stehen nicht in `unknownExerciseIds`', () {
      final r = gelesen(
        datei(
          sitzungen: [
            rohSitzung(
              exercises: [
                rohUebung('benchPress', [rohSatz(60, 10)]),
                rohUebung('dips', [rohSatz(0, 12)]),
              ],
            ),
          ],
        ),
      );

      expect(r.unknownExerciseIds, isEmpty);
    });
  });

  group('Eine Sitzung taugt nicht: übersprungen, benannt, die übrigen '
      'bleiben', () {
    test('Wiederholungen null oder negativ: `repsNotPositive`, mit der '
        'Übung', () {
      // `legeAb` wirft darauf. Der Leser liefert nichts, woran die Ablage
      // scheitern würde — sonst würde eine einzige Sitzung die ganze
      // Übernahme zurückrollen.
      for (final reps in [0, -3]) {
        final r = gelesen(
          datei(
            sitzungen: [
              rohSitzung(
                id: 'KAPUTT',
                exercises: [
                  rohUebung('dips', [rohSatz(0, 12)]),
                  rohUebung('benchPress', [rohSatz(60, reps)]),
                ],
              ),
            ],
          ),
        );

        expect(r.sessions, isEmpty, reason: 'reps $reps');
        final skip = r.skipped.single;
        expect(skip.reason, ExportSkipReason.repsNotPositive);
        expect(skip.detail, 'benchPress');
        expect(skip.id, 'KAPUTT');
        expect(skip.index, 0);
      }
    });

    test('Dieselbe Übung zweimal in einer Sitzung: `duplicateExercise`', () {
      final r = gelesen(
        datei(
          sitzungen: [
            rohSitzung(
              id: 'DOPPELT',
              exercises: [
                rohUebung('dips', [rohSatz(0, 12)]),
                rohUebung('dips', [rohSatz(0, 10)]),
              ],
            ),
          ],
        ),
      );

      expect(r.sessions, isEmpty);
      final skip = r.skipped.single;
      expect(skip.reason, ExportSkipReason.duplicateExercise);
      expect(skip.detail, 'dips');
      expect(skip.id, 'DOPPELT');
    });

    final kaputt = <String, Object?>{
      'Eintrag ist kein Objekt': 5,
      'Eintrag ist `null`': null,
      'ohne id': rohSitzung()..remove('id'),
      'leere id': rohSitzung(id: ''),
      'id ist eine Zahl': rohSitzung()..['id'] = 7,
      'ohne date': rohSitzung()..remove('date'),
      'ohne exercises': rohSitzung()..remove('exercises'),
      'exercises ist keine Liste': rohSitzung(exercises: 'x'),
      'Übung ist kein Objekt': rohSitzung(exercises: [3]),
      'Übung ohne exerciseID': rohSitzung(
        exercises: [
          {
            'sets': [rohSatz(1, 1)],
          },
        ],
      ),
      'sets ist keine Liste': rohSitzung(
        exercises: [
          {'exerciseID': 'dips', 'sets': 'x'},
        ],
      ),
      'Übung ohne sets': rohSitzung(
        exercises: [
          {'exerciseID': 'dips'},
        ],
      ),
      'Satz ist kein Objekt': rohSitzung(
        exercises: [
          rohUebung('dips', [7]),
        ],
      ),
      'Satz ohne weight': rohSitzung(
        exercises: [
          rohUebung('dips', [
            {'reps': 5},
          ]),
        ],
      ),
      'weight ist eine Zeichenkette': rohSitzung(
        exercises: [
          rohUebung('dips', [rohSatz('60', 5)]),
        ],
      ),
      'Satz ohne reps': rohSitzung(
        exercises: [
          rohUebung('dips', [
            {'weight': 5},
          ]),
        ],
      ),
      'reps ist eine Zeichenkette': rohSitzung(
        exercises: [
          rohUebung('dips', [rohSatz(5, '5')]),
        ],
      ),
      'reps ist eine Bruchzahl': rohSitzung(
        exercises: [
          rohUebung('dips', [rohSatz(5, 10.5)]),
        ],
      ),
      'minutes ist eine Zeichenkette': rohSitzung(minutes: '45'),
      'note ist eine Zahl': rohSitzung(note: 12),
      'workout ist eine Zahl': rohSitzung(workout: 3),
    };

    for (final eintrag in kaputt.entries) {
      test('${eintrag.key}: `malformed`, die Nachbarn werden gelesen', () {
        final r = gelesen(
          datei(
            sitzungen: [
              rohSitzung(id: 'VOR'),
              eintrag.value,
              rohSitzung(id: 'NACH', date: '2099-01-15T09:00:00Z'),
            ],
          ),
        );

        expect(r.sessions.map((s) => s.id), ['VOR', 'NACH']);
        final skip = r.skipped.single;
        expect(skip.reason, ExportSkipReason.malformed);
        expect(skip.index, 1, reason: 'Position in `app.sessions`, ab 0');
        expect(skip.detail, isNotEmpty, reason: 'das Feld wird genannt');
        expect(r.entryCount, 3);
      });
    }

    test('Die Position zählt in der Datei, nicht unter den Gelesenen', () {
      final r = gelesen(
        datei(
          sitzungen: [
            rohSitzung(id: 'A'),
            5,
            rohSitzung(id: 'B', date: '2099-01-15T09:00:00Z'),
            null,
          ],
        ),
      );

      expect(r.skipped.map((s) => s.index), [1, 3]);
    });

    test('Kennung ist bekannt, wo es sie gibt: `id` der übersprungenen '
        'Sitzung', () {
      final r = gelesen(
        datei(sitzungen: [rohSitzung(id: 'BEKANNT', date: 'nie')]),
      );

      expect(r.skipped.single.id, 'BEKANNT');
    });

    test('Fehlt die Kennung, ist `id` `null` — die Position bleibt', () {
      final r = gelesen(datei(sitzungen: [rohSitzung()..remove('id')]));

      expect(r.skipped.single.id, isNull);
      expect(r.skipped.single.index, 0);
    });

    test('`entryCount` ist gelesen plus übersprungen: jede Sitzung der Datei '
        'zählt genau einmal', () {
      final r = gelesen(
        datei(
          sitzungen: [
            rohSitzung(id: 'A'),
            rohSitzung(id: 'B', date: 'kaputt'),
            rohSitzung(id: 'C', date: '2099-01-17T09:00:00Z'),
            7,
          ],
        ),
      );

      expect(r.sessions.length, 2);
      expect(r.skipped.length, 2);
      expect(r.entryCount, 4);
    });
  });

  group('Was dieser Schritt nicht liest, wird gezählt statt verschwiegen', () {
    test('Die anderen Stände erscheinen mit ihrer Anzahl in `unread`', () {
      final r = gelesen(
        datei(
          app: {
            'sessions': <Object?>[],
            'circumferences': [
              {
                'date': '2099-01-10T09:00:00Z',
                'values': {'waist': 80.0},
              },
              {
                'date': '2099-01-11T09:00:00Z',
                'values': {'waist': 79.5},
              },
            ],
            'swaps': [
              {'week': 3, 'first': 'Di', 'second': 'Do'},
            ],
            'drafts': [
              {'workout': 'A'},
              {'workout': 'B'},
              {'workout': 'C'},
            ],
            'dataWindow': [
              {'key': 'app.firstLaunch', 'date': '2099-01-01T09:00:00Z'},
            ],
            'dashboardImport': [
              {
                'sessions': [
                  rohSitzung(id: 'D1'),
                  rohSitzung(id: 'D2'),
                  rohSitzung(id: 'D3'),
                ],
                'scales': <Object?>[],
                'circumferences': <Object?>[],
              },
            ],
          },
        ),
      );

      expect(
        r.unread,
        {
          'swaps': 1,
          'drafts': 3,
          'dataWindow': 1,
          'dashboardImport.sessions': 3,
        },
        reason:
            '`circumferences` steht seit #498 nicht mehr darin — die '
            'Umfänge werden gelesen, und was gelesen wird, darf der '
            'Bericht nicht als ungelesen melden '
            '(`trainings_export_umfaenge_test.dart`)',
      );
      expect(
        r.sessions,
        isEmpty,
        reason:
            'Die Sitzungen aus `dashboardImport` werden in diesem Schritt '
            'nicht gelesen (Spec, offene Entscheidung 2) — aber genannt',
      );
    });

    test('Leere Stände stehen nicht in `unread`', () {
      final r = gelesen(
        datei(
          app: {
            'sessions': <Object?>[],
            'circumferences': <Object?>[],
            'swaps': [
              {'week': 1, 'first': 'Mo', 'second': 'Mi'},
            ],
            'drafts': <Object?>[],
            'dataWindow': <Object?>[],
            'dashboardImport': <Object?>[],
          },
        ),
      );

      expect(r.unread, {'swaps': 1});
    });

    test('Ein Stand, den dieser Schritt nicht liest, darf falsch geformt '
        'sein, ohne die Datei zu kippen', () {
      final r = gelesen(
        datei(
          app: {
            'sessions': [rohSitzung(id: 'A')],
            'circumferences': 'kaputt',
            'swaps': {'a': 1},
            'dashboardImport': 7,
          },
        ),
      );

      expect(r.sessions.single.id, 'A');
      expect(r.unread, isEmpty);
    });
  });
}
