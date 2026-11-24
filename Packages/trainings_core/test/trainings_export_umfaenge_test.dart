import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für den **Umfänge-Teil** von `TrainingsExport.read` (#498, unter
/// #59 und #88): Die Exportdatei der eingefrorenen Swift-App trägt neben den
/// Gym-Trainings auch Körpermaße, und dieser Schritt liest sie.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden. Geschrieben aus
/// dem Ticket #498 und aus
/// `docs/superpowers/specs/2026-11-11-gym-uebernahme-design.md` (Abschnitte
/// 2, 6 und 15 — der Umfänge-Teil ist ein **Anbau** an diese Spec, keine
/// zweite daneben), dazu `AppExport.swift` und `Circumference.swift` —
/// **ohne** den späteren Code gesehen zu haben.
///
/// Die Gym-Seite des Lesers steht in `trainings_export_test.dart` und wird
/// hier nicht wiederholt.
///
/// ## Was hier festgenagelt wird
///
/// - **`thigh` ist der rechte Oberschenkel, `calf` die rechte Wade.** Das
///   ist die Stelle, an der Tims echte Datei als *falsche Seite* gelesen
///   würde: Beide Zahlen sind plausibel, niemand sähe den Fehler. Die
///   Schlüssel sind die aus [Umfang.schluessel], nicht die Dart-Namen.
/// - **Ein unbekannter Schlüssel kippt die Datei nicht.** Er wird gezählt
///   und benannt, wie `unknownExerciseIds` es für Übungen tut. Die Altapp
///   kennt dreizehn Maße, der Neubau fünfzehn; umgekehrt kann eine spätere
///   Fassung Schlüssel tragen, die es hier nicht gibt.
/// - **Nichts wird geraten.** Ein Wert, der keine Zahl ist, wird nicht
///   gelesen, sondern übersprungen und benannt; dasselbe gilt für eine Zahl
///   außerhalb von [UmfangsEingabe.minCm] bis [UmfangsEingabe.maxCm]. Die
///   Datei bleibt gültig.
/// - **Der Leser wirft nie** — auch nicht für einen kaputten Umfangsblock.
/// - **`circumferences` fällt aus `unread` heraus**: Ein Bericht, der etwas
///   als ungelesen meldet, das gelesen wurde, ist falsch.
///
/// ## Festgelegte API — Entscheidungen des Test-Agenten, **nicht von Tim**
///
/// ```dart
/// // in ExportRead, zusätzlich zu den bisherigen Feldern:
/// final List<Umfangsmessung> circumferences;      // gelesene Messungen
/// final List<ExportMeasureSkip> skippedMeasures;  // was nicht gelesen wurde
/// final List<String> unknownMeasureKeys;          // sortiert, ohne Dubletten
///
/// enum ExportMeasureSkipReason {
///   malformed,     // der Eintrag taugt nicht; `detail` nennt das Feld
///   notANumber,    // der Wert ist keine Zahl
///   implausible,   // die Zahl liegt außerhalb 10–200 cm
/// }
///
/// final class ExportMeasureSkip {
///   final String source;  // 'app.circumferences' | 'dashboardImport.circumferences'
///   final int index;      // Position in der Liste dieser Quelle, ab 0
///   final String? measure;// der Rohschlüssel; null, wenn der ganze Eintrag nicht taugt
///   final ExportMeasureSkipReason reason;
///   final String detail;  // was dastand bzw. welches Feld fehlt, nie leer
/// }
/// ```
///
/// **[Umfangsmessung] und kein neuer Typ:** Es ist der Werttyp, den
/// `UmfangsMerge` und die Ablage ohnehin sprechen, mit `==` über den Inhalt.
/// Ein zweiter Typ daneben müsste an jeder Stelle wieder umgerechnet werden.
/// Der `zeitpunkt` ist der **Zeitpunkt der Datei**, roh und in UTC — den
/// Berliner Tag rechnet erst der Planer (`UmfangsImport.plan`), genauso wie
/// bei den Trainings.
///
/// **Die Reihenfolge:** erst `dashboardImport[].circumferences`, dann
/// `app.circumferences`. Beim tagweisen Falten gewinnt der spätere Eintrag
/// (so faltet `UmfangsMerge`), und gewinnen muss das in der Altapp selbst
/// Erfasste — `CircumferenceMerge.swift` entscheidet dort genauso. Stünde
/// der Dashboard-Import hinten, überschriebe er still die eigene Messung
/// desselben Tages.
///
/// Alle Zahlen, Schlüssel und Zeitpunkte sind **erfunden** und liegen im
/// Jahr 2099 — keine echten Gesundheitsdaten (`CLAUDE.md`).
void main() {
  /* ---- Fixturen ------------------------------------------------------ */

  /// Ein Umfangs-Eintrag, so wie Swift ihn schreibt.
  Map<String, Object?> rohMessung({
    Object? datum = '2099-01-14T09:00:00Z',
    Object? werte = const {'waist': 81.0},
    bool ohneDatum = false,
    bool ohneWerte = false,
  }) => {
    if (!ohneDatum) 'date': datum,
    if (!ohneWerte) 'values': werte,
  };

  Map<String, Object?> rohSitzung({String id = 'S1'}) => {
    'id': id,
    'date': '2099-01-14T09:00:00Z',
    'exercises': [
      {
        'exerciseID': 'benchPress',
        'sets': [
          {'weight': 60, 'reps': 10},
        ],
      },
    ],
  };

  /// Die ganze Hülle. [umfaenge] füllt `app.circumferences`,
  /// [dashboardUmfaenge] den gleichnamigen Block in der einen
  /// Dashboard-Übernahme; [app] ersetzt den Block im Ganzen.
  Map<String, Object?> datei({
    List<Object?> sitzungen = const [],
    Object? umfaenge = const <Object?>[],
    List<Object?>? dashboardUmfaenge,
    Map<String, Object?>? app,
  }) => {
    'format': 'trainingsexport',
    'version': 2,
    'generated': '2099-02-01T08:30:00Z',
    'timezone': 'Europe/Berlin',
    'app':
        app ??
        {
          'sessions': sitzungen,
          'circumferences': umfaenge,
          'swaps': <Object?>[],
          'drafts': <Object?>[],
          'dataWindow': <Object?>[],
          'dashboardImport': dashboardUmfaenge == null
              ? <Object?>[]
              : [
                  {
                    'importedAt': '2099-01-02T10:00:00Z',
                    'sessions': <Object?>[],
                    'scales': <Object?>[],
                    'circumferences': dashboardUmfaenge,
                  },
                ],
        },
  };

  ExportRead gelesen(Object? roh) {
    final ergebnis = TrainingsExport.read(roh);
    expect(ergebnis, isA<ExportRead>(), reason: '$ergebnis');
    return ergebnis as ExportRead;
  }

  const appQuelle = 'app.circumferences';
  const dashboardQuelle = 'dashboardImport.circumferences';

  /* ---- Gelesen wird `app.circumferences` ----------------------------- */

  group('app.circumferences wird gelesen', () {
    test('Eine Messung mit mehreren Maßen kommt mit Zeitpunkt und Werten an', () {
      final r = gelesen(
        datei(
          umfaenge: [
            rohMessung(
              datum: '2099-01-14T07:20:00Z',
              werte: {'chest': 102.4, 'waist': 81.0, 'neck': 39.5},
            ),
          ],
        ),
      );

      expect(r.circumferences, [
        Umfangsmessung(
          zeitpunkt: DateTime.utc(2099, 1, 14, 7, 20),
          werte: {
            Umfang.brust: 102.4,
            Umfang.taille: 81.0,
            Umfang.hals: 39.5,
          },
        ),
      ]);
      expect(r.skippedMeasures, isEmpty);
      expect(r.unknownMeasureKeys, isEmpty);
    });

    test('Der Zeitpunkt bleibt roh und in UTC — den Berliner Tag rechnet '
        'erst der Planer', () {
      final r = gelesen(
        datei(umfaenge: [rohMessung(datum: '2099-01-14T23:30:00Z')]),
      );

      final zeitpunkt = r.circumferences.single.zeitpunkt;
      expect(zeitpunkt, DateTime.utc(2099, 1, 14, 23, 30));
      expect(zeitpunkt.isUtc, isTrue);
    });

    test('Ein Zeitpunkt mit Versatz wird nach UTC gerechnet', () {
      final r = gelesen(
        datei(umfaenge: [rohMessung(datum: '2099-01-14T10:00:00+01:00')]),
      );

      expect(r.circumferences.single.zeitpunkt, DateTime.utc(2099, 1, 14, 9));
    });

    test('Mehrere Messungen stehen in der Reihenfolge der Datei', () {
      final r = gelesen(
        datei(
          umfaenge: [
            rohMessung(datum: '2099-01-20T09:00:00Z', werte: {'waist': 80.0}),
            rohMessung(datum: '2099-01-14T09:00:00Z', werte: {'waist': 81.0}),
            rohMessung(datum: '2099-01-27T09:00:00Z', werte: {'waist': 79.5}),
          ],
        ),
      );

      expect(
        r.circumferences.map((m) => m.zeitpunkt.day).toList(),
        [20, 14, 27],
        reason: 'Der Leser sortiert nicht; das tut der Planer',
      );
    });

    test('Ganze Zahlen und Kommazahlen werden beide gelesen', () {
      final r = gelesen(
        datei(
          umfaenge: [
            rohMessung(werte: {'waist': 81, 'chest': 102.4}),
          ],
        ),
      );

      expect(r.circumferences.single.werte, {
        Umfang.taille: 81.0,
        Umfang.brust: 102.4,
      });
    });

    test('Jeder Schlüssel aus `Umfang.schluessel` wird gelesen', () {
      final werte = <String, Object?>{};
      final erwartet = <Umfang, double>{};
      for (var i = 0; i < Umfang.values.length; i++) {
        final mass = Umfang.values[i];
        final wert = 20.0 + i * 2;
        werte[mass.schluessel] = wert;
        erwartet[mass] = wert;
      }

      final r = gelesen(datei(umfaenge: [rohMessung(werte: werte)]));

      expect(r.circumferences.single.werte, erwartet);
      expect(r.unknownMeasureKeys, isEmpty);
    });
  });

  /* ---- Die Seite, an der nichts schiefgehen darf --------------------- */

  group('`thigh` und `calf` sind die RECHTEN Maße', () {
    test('`thigh` ist der rechte Oberschenkel, `thighLeft` der linke', () {
      final r = gelesen(
        datei(
          umfaenge: [
            rohMessung(werte: {'thigh': 61.0, 'thighLeft': 60.2}),
          ],
        ),
      );

      expect(r.circumferences.single.werte, {
        Umfang.oberschenkelRechts: 61.0,
        Umfang.oberschenkelLinks: 60.2,
      });
    });

    test('`calf` ist die rechte Wade, `calfLeft` die linke', () {
      final r = gelesen(
        datei(
          umfaenge: [
            rohMessung(werte: {'calf': 39.0, 'calfLeft': 38.6}),
          ],
        ),
      );

      expect(r.circumferences.single.werte, {
        Umfang.wadeRechts: 39.0,
        Umfang.wadeLinks: 38.6,
      });
    });

    test('`thighRight` und `calfRight` sind KEINE Schlüssel der Datei', () {
      final r = gelesen(
        datei(
          umfaenge: [
            rohMessung(werte: {'thighRight': 61.0, 'calfRight': 39.0}),
          ],
        ),
      );

      expect(
        r.circumferences,
        isEmpty,
        reason: 'Die abgelegten Dateien kennen nur `thigh` und `calf`; die '
            'Dart-Namen sind keine Schlüssel',
      );
      expect(r.unknownMeasureKeys, ['calfRight', 'thighRight']);
    });
  });

  /* ---- Unbekannte Schlüssel ------------------------------------------ */

  group('Ein unbekannter Schlüssel kippt die Datei nicht', () {
    test('Er wird gezählt und benannt, die übrigen Werte bleiben', () {
      final r = gelesen(
        datei(
          sitzungen: [rohSitzung()],
          umfaenge: [
            rohMessung(werte: {'waist': 81.0, 'ellbogen': 29.0}),
          ],
        ),
      );

      expect(r.circumferences.single.werte, {Umfang.taille: 81.0});
      expect(r.unknownMeasureKeys, ['ellbogen']);
      expect(r.sessions.single.id, 'S1', reason: 'Die Datei bleibt gültig');
    });

    test('Unbekannte Schlüssel stehen sortiert und ohne Dubletten da', () {
      final r = gelesen(
        datei(
          umfaenge: [
            rohMessung(
              datum: '2099-01-14T09:00:00Z',
              werte: {'zehe': 22.0, 'ellbogen': 29.0},
            ),
            rohMessung(
              datum: '2099-01-21T09:00:00Z',
              werte: {'ellbogen': 29.5, 'waist': 80.0},
            ),
          ],
        ),
      );

      expect(r.unknownMeasureKeys, ['ellbogen', 'zehe']);
    });

    test('Ein unbekannter Schlüssel steht nicht in `skippedMeasures` — er '
        'wird gezählt, nicht als Lesefehler gemeldet', () {
      final r = gelesen(
        datei(
          umfaenge: [
            rohMessung(werte: {'ellbogen': 29.0}),
          ],
        ),
      );

      expect(r.unknownMeasureKeys, ['ellbogen']);
      expect(r.skippedMeasures, isEmpty);
    });

    test('Eine Messung, von der nur Unbekanntes übrig bleibt, erzeugt keine '
        'leere Messung', () {
      final r = gelesen(
        datei(
          umfaenge: [
            rohMessung(werte: {'ellbogen': 29.0, 'zehe': 22.0}),
          ],
        ),
      );

      expect(r.circumferences, isEmpty);
    });
  });

  /* ---- Werte, die nicht taugen --------------------------------------- */

  group('Ein Wert, der keine Zahl ist, wird übersprungen und benannt', () {
    test('Eine Zeichenkette wird nicht umgerechnet', () {
      final r = gelesen(
        datei(
          umfaenge: [
            rohMessung(werte: {'waist': '81,0', 'chest': 102.0}),
          ],
        ),
      );

      expect(r.circumferences.single.werte, {Umfang.brust: 102.0});
      expect(r.skippedMeasures, hasLength(1));
      final skip = r.skippedMeasures.single;
      expect(skip.source, appQuelle);
      expect(skip.index, 0);
      expect(skip.measure, 'waist');
      expect(skip.reason, ExportMeasureSkipReason.notANumber);
      expect(skip.detail, isNotEmpty);
    });

    test('`null` und `true` sind keine Zahlen', () {
      final r = gelesen(
        datei(
          umfaenge: [
            rohMessung(werte: {'waist': null, 'neck': true, 'chest': 102.0}),
          ],
        ),
      );

      expect(r.circumferences.single.werte, {Umfang.brust: 102.0});
      expect(
        r.skippedMeasures.map((s) => s.measure).toSet(),
        {'waist', 'neck'},
      );
      expect(
        r.skippedMeasures.every(
          (s) => s.reason == ExportMeasureSkipReason.notANumber,
        ),
        isTrue,
      );
    });

    test('Die Datei bleibt gültig, die Trainings werden gelesen', () {
      final r = gelesen(
        datei(
          sitzungen: [rohSitzung()],
          umfaenge: [
            rohMessung(werte: {'waist': 'achtzig'}),
          ],
        ),
      );

      expect(r.sessions, hasLength(1));
      expect(r.circumferences, isEmpty);
      expect(r.skippedMeasures, hasLength(1));
    });
  });

  group('Ein unplausibler Wert wird übersprungen, nicht geraten', () {
    test('Unter der unteren Grenze: übersprungen mit Grund', () {
      final r = gelesen(
        datei(
          umfaenge: [
            rohMessung(
              werte: {'waist': UmfangsEingabe.minCm - 0.1, 'chest': 102.0},
            ),
          ],
        ),
      );

      expect(r.circumferences.single.werte, {Umfang.brust: 102.0});
      expect(r.skippedMeasures.single.measure, 'waist');
      expect(
        r.skippedMeasures.single.reason,
        ExportMeasureSkipReason.implausible,
      );
      expect(r.skippedMeasures.single.detail, isNotEmpty);
    });

    test('Über der oberen Grenze: übersprungen mit Grund', () {
      final r = gelesen(
        datei(
          umfaenge: [
            rohMessung(werte: {'waist': UmfangsEingabe.maxCm + 0.1}),
          ],
        ),
      );

      expect(
        r.skippedMeasures.single.reason,
        ExportMeasureSkipReason.implausible,
      );
      expect(r.circumferences, isEmpty);
    });

    test('Null und negative Zahlen sind unplausibel — eine `0` ist kein '
        'gemessener Umfang', () {
      final r = gelesen(
        datei(
          umfaenge: [
            rohMessung(werte: {'waist': 0, 'neck': -39.5}),
          ],
        ),
      );

      expect(r.circumferences, isEmpty);
      expect(r.skippedMeasures, hasLength(2));
      expect(
        r.skippedMeasures.every(
          (s) => s.reason == ExportMeasureSkipReason.implausible,
        ),
        isTrue,
      );
    });

    test('Die Grenzen selbst gelten noch', () {
      final r = gelesen(
        datei(
          umfaenge: [
            rohMessung(
              werte: {
                'neck': UmfangsEingabe.minCm,
                'hips': UmfangsEingabe.maxCm,
              },
            ),
          ],
        ),
      );

      expect(r.circumferences.single.werte, {
        Umfang.hals: UmfangsEingabe.minCm,
        Umfang.huefte: UmfangsEingabe.maxCm,
      });
      expect(r.skippedMeasures, isEmpty);
    });
  });

  /* ---- Einträge, die nicht taugen ------------------------------------ */

  group('Ein kaputter Eintrag kippt die Datei nicht', () {
    test('Ohne `date`: übersprungen mit dem Feldnamen, die übrigen bleiben', () {
      final r = gelesen(
        datei(
          umfaenge: [
            rohMessung(ohneDatum: true),
            rohMessung(datum: '2099-01-21T09:00:00Z', werte: {'waist': 80.0}),
          ],
        ),
      );

      expect(r.circumferences, hasLength(1));
      expect(r.circumferences.single.zeitpunkt.day, 21);
      final skip = r.skippedMeasures.single;
      expect(skip.index, 0);
      expect(skip.measure, isNull, reason: 'Der ganze Eintrag taugt nicht');
      expect(skip.reason, ExportMeasureSkipReason.malformed);
      expect(skip.detail, 'date');
    });

    test('Ein Zeitpunkt ohne Zone wird nicht geraten', () {
      final r = gelesen(
        datei(umfaenge: [rohMessung(datum: '2099-01-14T09:00:00')]),
      );

      expect(r.circumferences, isEmpty);
      expect(r.skippedMeasures.single.reason, ExportMeasureSkipReason.malformed);
      expect(r.skippedMeasures.single.detail, 'date');
    });

    test('Ein reiner Tag ohne Uhrzeit wird nicht geraten', () {
      final r = gelesen(datei(umfaenge: [rohMessung(datum: '2099-01-14')]));

      expect(r.circumferences, isEmpty);
      expect(r.skippedMeasures.single.detail, 'date');
    });

    test('Ohne `values`: übersprungen mit dem Feldnamen', () {
      final r = gelesen(datei(umfaenge: [rohMessung(ohneWerte: true)]));

      expect(r.circumferences, isEmpty);
      expect(r.skippedMeasures.single.reason, ExportMeasureSkipReason.malformed);
      expect(r.skippedMeasures.single.detail, 'values');
    });

    test('`values` ist keine Abbildung: übersprungen', () {
      final r = gelesen(datei(umfaenge: [rohMessung(werte: [81.0])]));

      expect(r.circumferences, isEmpty);
      expect(r.skippedMeasures.single.detail, 'values');
    });

    test('Ein Eintrag, der kein Objekt ist: übersprungen', () {
      final r = gelesen(
        datei(
          umfaenge: [
            'kaputt',
            rohMessung(datum: '2099-01-21T09:00:00Z', werte: {'waist': 80.0}),
          ],
        ),
      );

      expect(r.circumferences, hasLength(1));
      expect(r.skippedMeasures.single.index, 0);
      expect(r.skippedMeasures.single.measure, isNull);
      expect(r.skippedMeasures.single.reason, ExportMeasureSkipReason.malformed);
      expect(r.skippedMeasures.single.detail, isNotEmpty);
    });

    test('Leere `values` sind kein Fehler und keine Messung', () {
      final r = gelesen(
        datei(
          umfaenge: [
            rohMessung(werte: const <String, Object?>{}),
          ],
        ),
      );

      expect(r.circumferences, isEmpty);
      expect(r.skippedMeasures, isEmpty);
    });

    test('Die Position zählt in der Liste der Quelle, ab 0', () {
      final r = gelesen(
        datei(
          umfaenge: [
            rohMessung(datum: '2099-01-07T09:00:00Z', werte: {'waist': 82.0}),
            rohMessung(datum: '2099-01-14T09:00:00Z', werte: {'waist': 'x'}),
            rohMessung(ohneDatum: true),
          ],
        ),
      );

      expect(r.skippedMeasures.map((s) => s.index).toList(), [1, 2]);
    });
  });

  /* ---- Der Block selbst ---------------------------------------------- */

  group('Der Block `circumferences` darf fehlen oder leer sein', () {
    test('Ein leerer Block ist kein Fehler', () {
      final r = gelesen(datei());

      expect(r.circumferences, isEmpty);
      expect(r.skippedMeasures, isEmpty);
      expect(r.unknownMeasureKeys, isEmpty);
    });

    test('Ein fehlender Block ist kein Fehler — anders als `app.sessions`', () {
      final r = gelesen(
        datei(
          app: {
            'sessions': [rohSitzung()],
          },
        ),
      );

      expect(r.sessions, hasLength(1));
      expect(r.circumferences, isEmpty);
    });

    test('Ein falsch geformter Block kippt die Datei nicht', () {
      final r = gelesen(
        datei(
          app: {
            'sessions': [rohSitzung()],
            'circumferences': 'kaputt',
          },
        ),
      );

      expect(r.sessions, hasLength(1));
      expect(r.circumferences, isEmpty);
      expect(r.skippedMeasures, isEmpty);
    });

    test('Eine Datei, die nur Umfänge trägt, wird gelesen', () {
      final r = gelesen(
        datei(
          umfaenge: [
            rohMessung(werte: {'waist': 81.0}),
          ],
        ),
      );

      expect(r.sessions, isEmpty);
      expect(r.circumferences, hasLength(1));
    });
  });

  /* ---- Der Dashboard-Import ------------------------------------------ */

  group('dashboardImport[].circumferences wird mitgelesen', () {
    test('Die Messungen des Dashboards kommen an', () {
      final r = gelesen(
        datei(
          dashboardUmfaenge: [
            rohMessung(datum: '2099-01-03T08:00:00Z', werte: {'waist': 83.0}),
          ],
        ),
      );

      expect(r.circumferences, [
        Umfangsmessung(
          zeitpunkt: DateTime.utc(2099, 1, 3, 8),
          werte: {Umfang.taille: 83.0},
        ),
      ]);
    });

    test('Der Dashboard-Import steht VOR `app.circumferences` — das in der '
        'Altapp selbst Erfasste gewinnt beim Falten', () {
      final r = gelesen(
        datei(
          umfaenge: [
            rohMessung(datum: '2099-01-14T09:00:00Z', werte: {'waist': 81.0}),
          ],
          dashboardUmfaenge: [
            rohMessung(datum: '2099-01-14T06:00:00Z', werte: {'waist': 83.0}),
          ],
        ),
      );

      expect(
        r.circumferences.map((m) => m.werte[Umfang.taille]).toList(),
        [83.0, 81.0],
      );
    });

    test('Ein kaputter Wert des Dashboards nennt seine Quelle', () {
      final r = gelesen(
        datei(
          dashboardUmfaenge: [
            rohMessung(werte: {'waist': 'x'}),
          ],
        ),
      );

      expect(r.skippedMeasures.single.source, dashboardQuelle);
      expect(r.skippedMeasures.single.index, 0);
    });

    test('Ein falsch geformter Dashboard-Block kippt die Datei nicht', () {
      final r = gelesen(
        datei(
          app: {
            'sessions': [rohSitzung()],
            'dashboardImport': [
              {'sessions': <Object?>[], 'circumferences': 7},
            ],
          },
        ),
      );

      expect(r.sessions, hasLength(1));
      expect(r.circumferences, isEmpty);
    });

    test('Unbekannte Schlüssel beider Quellen stehen in einer Liste', () {
      final r = gelesen(
        datei(
          umfaenge: [
            rohMessung(werte: {'zehe': 22.0}),
          ],
          dashboardUmfaenge: [
            rohMessung(werte: {'ellbogen': 29.0, 'zehe': 22.5}),
          ],
        ),
      );

      expect(r.unknownMeasureKeys, ['ellbogen', 'zehe']);
    });
  });

  /* ---- `unread` ------------------------------------------------------ */

  group('Was gelesen wird, steht nicht mehr unter `unread`', () {
    test('`circumferences` fällt aus `unread` heraus, auch wenn der Block '
        'gefüllt ist', () {
      final r = gelesen(
        datei(
          umfaenge: [
            rohMessung(datum: '2099-01-14T09:00:00Z', werte: {'waist': 81.0}),
            rohMessung(datum: '2099-01-21T09:00:00Z', werte: {'waist': 80.5}),
          ],
        ),
      );

      expect(r.circumferences, hasLength(2));
      expect(
        r.unread.containsKey('circumferences'),
        isFalse,
        reason: 'Ein Bericht, der Gelesenes als ungelesen meldet, ist falsch',
      );
    });

    test('Die übrigen Stände bleiben in `unread`', () {
      final r = gelesen(
        datei(
          app: {
            'sessions': <Object?>[],
            'circumferences': [
              rohMessung(werte: {'waist': 81.0}),
            ],
            'swaps': [
              {'week': 3, 'first': 'Di', 'second': 'Do'},
            ],
            'drafts': [
              {'workout': 'A'},
            ],
            'dataWindow': [
              {'key': 'app.firstLaunch', 'date': '2099-01-01T09:00:00Z'},
            ],
            'dashboardImport': [
              {
                'sessions': [rohSitzung(id: 'D1'), rohSitzung(id: 'D2')],
                'scales': <Object?>[],
                'circumferences': <Object?>[],
              },
            ],
          },
        ),
      );

      expect(r.unread, {
        'swaps': 1,
        'drafts': 1,
        'dataWindow': 1,
        'dashboardImport.sessions': 2,
      });
    });

    test('Auch ein Umfangsblock, von dem nichts lesbar war, steht nicht in '
        '`unread`', () {
      final r = gelesen(
        datei(
          umfaenge: [
            rohMessung(werte: {'waist': 'x'}),
          ],
        ),
      );

      expect(r.circumferences, isEmpty);
      expect(r.skippedMeasures, hasLength(1));
      expect(r.unread.containsKey('circumferences'), isFalse);
    });
  });

  /* ---- Der Leser wirft nie ------------------------------------------- */

  group('Der Leser wirft nie', () {
    test('Ein tief verschachtelter Unsinn im Umfangsblock wirft nicht', () {
      final unsinn = [
        datei(umfaenge: 42),
        datei(
          umfaenge: [
            {'date': 7, 'values': 'nein'},
          ],
        ),
        datei(
          umfaenge: [
            {
              'date': '2099-01-14T09:00:00Z',
              'values': {
                'waist': {'tief': 1},
              },
            },
          ],
        ),
        datei(umfaenge: [null]),
      ];

      for (final roh in unsinn) {
        expect(() => TrainingsExport.read(roh), returnsNormally);
        expect(TrainingsExport.read(roh), isA<ExportRead>());
      }
    });

    test('Eine abgelehnte Datei trägt keine Umfänge mit sich', () {
      final ergebnis = TrainingsExport.read({
        'format': 'trainingsexport',
        'version': 1,
        'generated': '2099-02-01T08:30:00Z',
        'timezone': 'Europe/Berlin',
        'app': {
          'sessions': <Object?>[],
          'circumferences': [
            {
              'date': '2099-01-14T09:00:00Z',
              'values': {'waist': 81.0},
            },
          ],
        },
      });

      expect(ergebnis, isA<ExportRejected>());
    });
  });
}
