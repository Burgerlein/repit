import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für `ChartBuckets` — Ticket #130, Spec
/// `docs/superpowers/specs/2026-10-13-graphen-zeitraum-und-ablesen-design.md`,
/// Abschnitt „`TrainingsCore` — die Rechnerei" samt der sechs nachgetragenen
/// Klärungen. Vorlage ist
/// `Packages/TrainingsCore/Sources/TrainingsCore/Health/ChartBuckets.swift`.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, nie verändert werden. Hält der
/// Implementierende eine Erwartung für falsch, wird das gemeldet, nicht
/// korrigiert.
///
/// ## API, die diese Tests verbindlich vorgeben
///
/// Neue Datei `lib/src/chart_buckets.dart`, dazu die Export-Zeile in
/// `lib/trainings_core.dart` — diese Datei importiert das Barrel, also ist
/// der Export Teil des Vertrags.
///
/// ```dart
/// /// Die Stufen der Zeitraumleiste (`T W M 6M J`).
/// enum ChartRange { day, week, month, halfYear, year }
///
/// enum SnapDirection { nearest, forward, backward }
///
/// /// Ein Messwert: Zeitpunkt und Zahl. Werttyp.
/// class ChartSample {
///   const ChartSample({required DateTime date, required double value});
///   final DateTime date;
///   final double value;
/// }
///
/// /// Ein gezeichneter Punkt. Werttyp.
/// class ChartPoint {
///   const ChartPoint({
///     required DateTime start,
///     required double value,
///     /// Wie viele **gemessene** Kalendertage hinter dem Punkt stecken.
///     required int dayCount,
///   });
/// }
///
/// abstract final class ChartBuckets {
///   static List<ChartPoint> points({
///     required List<ChartSample> samples,
///     required ChartRange range,
///   });
///
///   static DateTime snap({
///     required DateTime date,
///     required ChartRange range,
///     required SnapDirection direction,
///   });
/// }
/// ```
///
/// ## Vier Entscheidungen dieses Test-Agenten, mit Begründung
///
/// Keine davon ist mit Tim abgestimmt; sie stehen hier, damit der
/// Implementierende weiß, woran er sich hält, und damit sie jemand findet,
/// der sie umstoßen will.
///
/// ### 1 · Die Monatsarithmetik gehört in `BerlinCalendar`, nicht hierher
///
/// `BerlinCalendar` kennt heute `startOfDay`, `endOfDay`, `dayBounds`,
/// `days`, `dayKey`, `addDays`, `weekday`, `wallClock` — **keine**
/// Monatsgrenzen. `ChartBuckets` braucht sie für das Monatsmittel und für
/// `snap`. Sie wandern deshalb als `startOfMonth` und `addMonths` in
/// `BerlinCalendar`: Eine Monatsgrenze ist eine Kalenderfrage, und
/// `BerlinCalendar` ist die **einzige** Stelle im Paket, die die
/// EU-Sommerzeitregel kennt (`_versatz`). Privat in `chart_buckets.dart`
/// gäbe es eine zweite Stelle, die eine Kalendergrenze berechnet — und die
/// Doppelung wäre diesmal keine Absicht, sondern eine Kopie.
///
/// Die Fälle dafür stehen **additiv** in `berlin_calendar_test.dart`, Gruppe
/// „Monatsgrenzen". Vertrag dort:
///
/// ```dart
/// /// Der Berliner Monatserste 00:00 des Monats, der den Zeitpunkt
/// /// enthält — als UTC-Instant, wie alles aus dieser Klasse.
/// static DateTime startOfMonth(DateTime zeitpunkt);
///
/// /// Der Berliner Monatserste, der `monate` Kalendermonate nach dem
/// /// **Monat** des Zeitpunkts liegt; negative Werte gehen zurück.
/// /// Die Auflösung ist der Monat, nicht der Tag — damit stellt sich die
/// /// Frage nach dem 31. in einem 30-Tage-Monat gar nicht erst.
/// /// `addMonths(x, 0) == startOfMonth(x)`.
/// static DateTime addMonths(DateTime zeitpunkt, int monate);
/// ```
///
/// `startOfYear` gibt es bewusst **nicht**: Nach Entscheidung 2 rastet auch
/// `year` auf den Monatsersten, also braucht keine Rechnung dieses Pakets
/// eine Jahresgrenze. Etwas anzulegen, das niemand ruft, hieße eine
/// ungeprüfte Behauptung zu hinterlassen.
///
/// ### 2 · `year` rastet auf den **Monats**ersten — die Spec widerspricht sich
///
/// Die Spec sagt zweierlei:
///
/// - Tabelle „Rastgrenzen je Stufe": `J` rastet auf „Jahresanfang".
/// - Abschnitt „Das Einrasten", Falle 2: „**`J` rastet auf den Monats-, nicht
///   den Jahresanfang.** Jahresgrenzen sind zu grob: Im geladenen Jahr gibt es
///   genau eine, rückwärts liegt die nächste außerhalb der Daten — und dann
///   rastet gar nichts."
///
/// Hier gilt die zweite Stelle. Sie ist die jüngere, sie nennt einen Grund,
/// und sie beschreibt einen Fehler, der teuer bezahlt wurde. Dazu kommt, dass
/// die Flutter-Seite sich bereits festgelegt hat:
/// `app/test/shell/diagramm_zeitraum_test.dart` prüft „M, 6M und J rasten
/// alle drei auf den Monatsersten". Zwei verschiedene Antworten auf dieselbe
/// Frage in einer App wären schlimmer als eine abweichende.
///
/// **Die Swift-Fassung tut hier etwas anderes** (`component(for:)` gibt für
/// `.year` die Jahreseinheit zurück, und `ChartBucketsTests.swift` nagelt den
/// 1. Januar fest). Wer von dort portiert, portiert an dieser einen Stelle
/// den Fehler mit.
///
/// ### 3 · `window` und `windows` werden **nicht** portiert
///
/// Die Swift-Fassung kann mehr als die Spec beschreibt: `window(containing:)`
/// und `windows(from:to:)`. Beides bleibt drüben, aus zwei Gründen:
///
/// - **Kein Abnehmer.** Das Startfenster der Flutter-Seite
///   (`startFenster` in `lib/shell/diagramm_zeitraum.dart`) ist ein
///   **rollendes** Fenster: Es endet an der Monatsgrenze nach dem jüngsten
///   Wert und reicht sechs bzw. zwölf Monate zurück. Es ist kein
///   Kalenderabschnitt.
/// - **Der Halbjahres-Abschnitt wäre ein Widerspruch.** Swifts
///   `window(containing:, for: .halfYear)` liefert das **Kalender**halbjahr
///   (Januar–Juni bzw. Juli–Dezember). Dieselbe Stufe hieße dann im Kern
///   „Januar bis Juni" und in der Shell „die letzten sechs Monate". Wer das
///   verwechselt, baut `07` nach („Schirm schlägt auf leerer Fläche auf").
///
/// Braucht ein Blätter-Mechanismus das später, ist die Swift-Fassung samt
/// ihrer Tests die Vorlage — dann aber mit einer Entscheidung darüber, was
/// `halfYear` bedeuten soll.
///
/// ### 4 · `visibleLength` wird nicht portiert
///
/// Es ist eine SwiftUI-Größe für `.chartXVisibleDomain(length:)` — eine
/// **angenäherte** Fensterbreite in Sekunden (31 bzw. 183 bzw. 366 Tage). Die
/// Flutter-Seite rechnet mit echten Kalendergrenzen; eine Näherung, die
/// niemand benutzt, wäre eine Zusicherung ohne Deckung.
///
/// ## Was `points` beim Durchreichen **nicht** tut
///
/// Bei `day`, `week` und `month` bleibt `ChartSample.date` **unverändert**
/// stehen — es wird nicht auf den Tagesbeginn gezogen. Die Spec: „gibt die
/// Messwerte unverändert zurück", und `ChartSample.date` ist laut Spec
/// bereits „Stunden- oder Tagesbeginn". Dass die Shell-Funktion
/// `diagrammPunkte` einen Zeitpunkt mitten am Tag sehr wohl auf den
/// Tagesbeginn zieht, ist kein Widerspruch: Die nimmt Tageswerte entgegen
/// (`({DateTime tag, double wert})`) und ist der Aufrufer, der diese Pflicht
/// trägt. Der Kern rechnet, die Shell bereitet vor.
void main() {
  // Alle Grenzen als Berliner Tagesbeginn, zurückgegeben als UTC-Zeitpunkt —
  // genau wie `BerlinCalendar` es tut. Ein UTC-Zeitpunkt wird nie mit einem
  // lokalen verglichen: Dart vergleicht `DateTime` unter Berücksichtigung
  // von `isUtc`.
  DateTime tag(int jahr, int monat, int tagImMonat) =>
      BerlinCalendar.startOfDay(DateTime.utc(jahr, monat, tagImMonat));

  // Verstrichene Zeit nach dem Berliner Tagesbeginn. Nur an Tagen ohne
  // Umstellung ist das die Wanduhrzeit — für die beiden Umstellungstage
  // stehen die UTC-Instants unten ausgerechnet im Klartext da.
  DateTime uhr(DateTime tagesbeginn, int stunden, [int minuten = 0]) =>
      tagesbeginn.add(Duration(hours: stunden, minutes: minuten));

  ChartSample messwert(DateTime zeitpunkt, double wert) =>
      ChartSample(date: zeitpunkt, value: wert);

  List<DateTime> starts(List<ChartPoint> punkte) =>
      punkte.map((p) => p.start).toList();
  List<double> werte(List<ChartPoint> punkte) =>
      punkte.map((p) => p.value).toList();
  List<int> tageZahlen(List<ChartPoint> punkte) =>
      punkte.map((p) => p.dayCount).toList();

  group('Der Vertrag der Aufzählungen', () {
    test(
      'ChartRange hat genau die fünf Stufen T W M 6M J, in dieser Folge',
      () {
        expect(ChartRange.values, [
          ChartRange.day,
          ChartRange.week,
          ChartRange.month,
          ChartRange.halfYear,
          ChartRange.year,
        ]);
      },
    );

    test('die Stufe `day` bleibt, auch ohne Abnehmer', () {
      expect(
        ChartRange.values,
        contains(ChartRange.day),
        reason:
            'Heute bietet kein Schirm sie an — BodyStore liefert Tagessummen, '
            'keine Stundenwerte. Die Spec hält sie ausdrücklich frei '
            '(nachgetragene Klärung 5: „`.day` verdichtet nicht"), damit sie '
            'da ist, sobald HealthKit stündlich gelesen wird',
      );
    });

    test('SnapDirection kennt genau drei Richtungen', () {
      expect(SnapDirection.values.toSet(), {
        SnapDirection.nearest,
        SnapDirection.forward,
        SnapDirection.backward,
      });
    });
  });

  group('Leere Eingabe', () {
    test('ohne Messwerte gibt es keine Punkte, auf keiner Stufe', () {
      for (final stufe in ChartRange.values) {
        expect(
          ChartBuckets.points(samples: const [], range: stufe),
          isEmpty,
          reason: '$stufe',
        );
      }
    });
  });

  group('Tag, Woche und Monat reichen durch', () {
    test('unsortiert hinein, aufsteigend heraus — Werte unverändert', () {
      final eingabe = [
        messwert(tag(2026, 10, 3), 9000),
        messwert(tag(2026, 10, 1), 7000),
        messwert(tag(2026, 10, 2), 8000),
      ];

      for (final stufe in const [
        ChartRange.day,
        ChartRange.week,
        ChartRange.month,
      ]) {
        final punkte = ChartBuckets.points(samples: eingabe, range: stufe);
        expect(punkte, hasLength(3), reason: '$stufe');
        expect(starts(punkte), [
          tag(2026, 10, 1),
          tag(2026, 10, 2),
          tag(2026, 10, 3),
        ], reason: '$stufe');
        expect(werte(punkte), [7000, 8000, 9000], reason: '$stufe');
        expect(tageZahlen(punkte), [1, 1, 1], reason: '$stufe');
      }
    });

    test('ein Zeitpunkt mitten am Tag behält seinen Zeitpunkt', () {
      // 12.10.2026, 14:30 Berliner Zeit. `ChartSample.date` ist laut Spec
      // bereits Stunden- oder Tagesbeginn; der Kern zieht nichts zurecht.
      // Das Ziehen auf den Tagesbeginn ist Sache des Aufrufers (Shell).
      final zeitpunkt = uhr(tag(2026, 10, 12), 14, 30);
      final punkte = ChartBuckets.points(
        samples: [messwert(zeitpunkt, 7)],
        range: ChartRange.week,
      );
      expect(punkte.single.start, zeitpunkt);
      expect(punkte.single.dayCount, 1);
    });

    test('mehrere Messwerte am selben Tag werden nicht zusammengefasst', () {
      // Stundenwerte derselben Stunde gibt es nicht, deshalb unterscheiden
      // sich die Zeitpunkte — bei exakt gleichem Zeitpunkt wäre die
      // Reihenfolge nach dem Sortieren nicht festgelegt, und darauf soll
      // sich niemand verlassen.
      final punkte = ChartBuckets.points(
        samples: [
          messwert(uhr(tag(2026, 10, 1), 12), 4000),
          messwert(uhr(tag(2026, 10, 1), 6), 2000),
        ],
        range: ChartRange.day,
      );
      expect(punkte, hasLength(2));
      expect(starts(punkte), [
        uhr(tag(2026, 10, 1), 6),
        uhr(tag(2026, 10, 1), 12),
      ]);
      expect(werte(punkte), [2000, 4000]);
      expect(tageZahlen(punkte), [1, 1]);
    });

    test('eine gemessene Null bleibt ein Punkt', () {
      final punkte = ChartBuckets.points(
        samples: [messwert(tag(2026, 10, 11), 0)],
        range: ChartRange.month,
      );
      expect(
        punkte,
        hasLength(1),
        reason:
            'Eine gemessene Null ist ein Messwert. Sie wegzulassen hieße zu '
            'behaupten, an dem Tag sei nicht gemessen worden',
      );
      expect(punkte.single.value, 0);
    });

    test('Lücken bleiben Lücken — es wird nichts aufgefüllt', () {
      final punkte = ChartBuckets.points(
        samples: [
          messwert(tag(2026, 10, 10), 10),
          messwert(tag(2026, 10, 14), 20),
        ],
        range: ChartRange.month,
      );
      expect(
        punkte,
        hasLength(2),
        reason:
            'Kein Interpolieren über Tage, an denen die Uhr im Schrank lag '
            '(Spec, „Lücken bleiben Lücken")',
      );
    });

    test('die übergebene Liste wird nicht umsortiert', () {
      // `samples.sort()` sortiert in Dart **an Ort und Stelle**. Hält ein
      // Provider die Reihe, hätte der Aufruf eine sichtbare Nebenwirkung —
      // und ein zweiter Aufruf bekäme eine andere Liste als der erste.
      final eingabe = [
        messwert(tag(2026, 10, 3), 9000),
        messwert(tag(2026, 10, 1), 7000),
      ];
      final vorher = List<ChartSample>.of(eingabe);

      ChartBuckets.points(samples: eingabe, range: ChartRange.week);
      ChartBuckets.points(samples: eingabe, range: ChartRange.halfYear);

      expect(eingabe, vorher);
    });
  });

  group('Halbes Jahr und Jahr bilden Monatsmittel', () {
    test('ein Punkt je Kalendermonat, auf dem Monatsersten', () {
      final punkte = ChartBuckets.points(
        samples: [
          messwert(tag(2026, 9, 3), 10),
          messwert(tag(2026, 9, 25), 20),
          messwert(tag(2026, 10, 2), 60),
        ],
        range: ChartRange.halfYear,
      );
      expect(starts(punkte), [tag(2026, 9, 1), tag(2026, 10, 1)]);
      expect(werte(punkte), [15, 60]);
      expect(tageZahlen(punkte), [2, 1]);
    });

    test(
      'der Teiler ist die Zahl der gemessenen Tage, nicht die Länge des Monats',
      () {
        // Februar 2026 hat 28 Tage, gemessen wurde an dreien.
        final punkte = ChartBuckets.points(
          samples: [
            messwert(tag(2026, 2, 3), 1000),
            messwert(tag(2026, 2, 17), 2000),
            messwert(tag(2026, 2, 28), 6000),
          ],
          range: ChartRange.halfYear,
        );
        expect(punkte, hasLength(1));
        expect(punkte.single.start, tag(2026, 2, 1));
        expect(
          punkte.single.value,
          3000,
          reason:
              'Durch 28 geteilt kämen 321,43 heraus — ein Monat mit wenigen '
              'Messungen sähe aus wie ein fauler Monat, und die 8.000er-'
              'Ziellinie wäre nicht mehr vergleichbar',
        );
        expect(punkte.single.dayCount, 3);
      },
    );

    test('das Jahr rechnet dasselbe Monatsmittel wie das halbe Jahr', () {
      final eingabe = [
        messwert(tag(2026, 2, 3), 1000),
        messwert(tag(2026, 2, 17), 2000),
        messwert(tag(2026, 2, 28), 6000),
      ];
      expect(
        ChartBuckets.points(samples: eingabe, range: ChartRange.year),
        ChartBuckets.points(samples: eingabe, range: ChartRange.halfYear),
      );
    });

    test('ein Monat ohne jede Messung fehlt im Ergebnis', () {
      final punkte = ChartBuckets.points(
        samples: [
          messwert(tag(2026, 1, 15), 9000),
          messwert(tag(2026, 3, 15), 11000),
        ],
        range: ChartRange.halfYear,
      );
      expect(starts(punkte), [
        tag(2026, 1, 1),
        tag(2026, 3, 1),
      ], reason: 'Der Februar kommt nicht vor — eine Lücke ist eine Lücke');
      expect(werte(punkte), [9000, 11000]);
      expect(tageZahlen(punkte), [1, 1]);
    });

    test('unsortiert hinein, Monate aufsteigend heraus — über die '
        'Sommerzeitgrenze', () {
      final punkte = ChartBuckets.points(
        samples: [
          messwert(tag(2026, 4, 10), 5000),
          messwert(tag(2026, 1, 5), 8000),
          messwert(tag(2026, 3, 2), 4000),
          messwert(tag(2026, 3, 30), 6000),
          messwert(tag(2026, 1, 20), 12000),
        ],
        range: ChartRange.year,
      );
      expect(starts(punkte), [
        tag(2026, 1, 1),
        tag(2026, 3, 1),
        tag(2026, 4, 1),
      ]);
      expect(werte(punkte), [10000, 5000, 5000]);
      expect(tageZahlen(punkte), [2, 2, 1]);
    });

    test(
      'der Monatserste ist ein Berliner Tagesbeginn, kein UTC-Monatsanfang',
      () {
        final punkte = ChartBuckets.points(
          samples: [
            messwert(tag(2026, 3, 15), 100),
            messwert(tag(2026, 4, 15), 200),
          ],
          range: ChartRange.year,
        );
        expect(
          starts(punkte),
          [
            // 01.03.2026 00:00 Berlin = 28.02. 23:00 UTC (Winterzeit, +1).
            DateTime.utc(2026, 2, 28, 23),
            // 01.04.2026 00:00 Berlin = 31.03. 22:00 UTC (Sommerzeit, +2).
            DateTime.utc(2026, 3, 31, 22),
          ],
          reason:
              'Wer `DateTime.utc(jahr, monat, 1)` zurückgibt, liefert den '
              'UTC-Monatsanfang — eine bzw. zwei Stunden zu spät, und auf der '
              'falschen Seite der Umstellung',
        );
      },
    );

    test('Monate kommen aufsteigend, auch über den Jahreswechsel', () {
      final punkte = ChartBuckets.points(
        samples: [
          messwert(tag(2026, 1, 5), 1),
          messwert(tag(2025, 12, 5), 2),
          messwert(tag(2025, 11, 5), 3),
        ],
        range: ChartRange.year,
      );
      expect(starts(punkte), [
        tag(2025, 11, 1),
        tag(2025, 12, 1),
        tag(2026, 1, 1),
      ]);
      expect(werte(punkte), [3, 2, 1]);
    });

    test('mehrere Messwerte am selben Tag: das Mittel läuft über die '
        'Messwerte, `dayCount` über die Kalendertage', () {
      final punkte = ChartBuckets.points(
        samples: [
          messwert(uhr(tag(2026, 9, 3), 6), 10),
          messwert(uhr(tag(2026, 9, 3), 18), 20),
          messwert(tag(2026, 9, 10), 60),
        ],
        range: ChartRange.halfYear,
      );
      expect(punkte, hasLength(1));
      expect(
        punkte.single.value,
        closeTo(30, 1e-9),
        reason:
            'Drei Messwerte, Summe 90, geteilt durch 3. Durch 2 (die Zahl der '
            'Tage) geteilt wären es 45 — nachgetragene Klärung 1 sagt: das '
            'Mittel läuft über die Messwerte',
      );
      expect(
        punkte.single.dayCount,
        2,
        reason:
            'Nachgetragene Klärung 1: `dayCount` zählt die verschiedenen '
            'Kalendertage. Für die heutigen Abnehmer ist das dasselbe — sie '
            'liefern Tageswerte. Die Annahme steht hier, damit sie jemand '
            'findet, wenn eine Reihe das einmal nicht tut',
      );
    });

    test('die Monatsgrenze läuft über den Berliner Kalender, nicht über UTC', () {
      // 31.10.2026 23:30 UTC — die Sommerzeit endete am 25.10., also +1:
      // lokal ist das der 01.11.2026 um 00:30. Nach UTC-Datum noch Oktober.
      final punkte = ChartBuckets.points(
        samples: [messwert(DateTime.utc(2026, 10, 31, 23, 30), 5)],
        range: ChartRange.halfYear,
      );
      expect(
        punkte.single.start,
        tag(2026, 11, 1),
        reason:
            'Der Messwert fiel am 1. November um 00:30 Berliner Zeit an. Wer '
            '`DateTime.month` auf dem UTC-Zeitpunkt liest, schiebt ihn in den '
            'Oktober',
      );
    });

    test('`dayCount` zählt Berliner Kalendertage, keine UTC-Daten', () {
      // Beide Messwerte liegen am 25.10.2026 Berliner Zeit — dem Tag mit 25
      // Stunden. Nach UTC-Datum sind es zwei verschiedene Tage (24. und 25.),
      // nach Berliner Kalender einer.
      final tagesbeginn = tag(2026, 10, 25); // = 24.10. 22:00 UTC
      final spaet = tagesbeginn.add(
        const Duration(hours: 24),
      ); // 25.10. 22:00 UTC
      final punkte = ChartBuckets.points(
        samples: [messwert(tagesbeginn, 100), messwert(spaet, 300)],
        range: ChartRange.year,
      );
      expect(punkte, hasLength(1));
      expect(punkte.single.start, tag(2026, 10, 1));
      expect(punkte.single.value, 200);
      expect(
        punkte.single.dayCount,
        1,
        reason:
            'Verstrichene 24 Stunden sind am 25.10.2026 noch derselbe '
            'Kalendertag — er hat 25. Wer `DateTime.day` auf dem '
            'UTC-Zeitpunkt zählt, kommt auf zwei',
      );
    });
  });

  group('snap: die Rastgrenzen je Stufe', () {
    test('der Tag rastet auf den Tagesbeginn', () {
      final d = uhr(tag(2026, 5, 16), 17, 20);
      expect(
        ChartBuckets.snap(
          date: d,
          range: ChartRange.day,
          direction: SnapDirection.backward,
        ),
        tag(2026, 5, 16),
      );
      expect(
        ChartBuckets.snap(
          date: d,
          range: ChartRange.day,
          direction: SnapDirection.forward,
        ),
        tag(2026, 5, 17),
      );
      expect(
        ChartBuckets.snap(
          date: d,
          range: ChartRange.day,
          direction: SnapDirection.nearest,
        ),
        tag(2026, 5, 17),
        reason: '6 h 40 bis zur nächsten Mitternacht, 17 h 20 zurück',
      );
    });

    test('die Woche rastet auf den Montag', () {
      // Der 13.05.2026 ist ein Mittwoch, der 11.05. der Montag davor.
      expect(BerlinCalendar.weekday(tag(2026, 5, 11)), DateTime.monday);
      final d = uhr(tag(2026, 5, 13), 10);
      expect(
        ChartBuckets.snap(
          date: d,
          range: ChartRange.week,
          direction: SnapDirection.backward,
        ),
        tag(2026, 5, 11),
      );
      expect(
        ChartBuckets.snap(
          date: d,
          range: ChartRange.week,
          direction: SnapDirection.forward,
        ),
        tag(2026, 5, 18),
      );
      expect(
        ChartBuckets.snap(
          date: d,
          range: ChartRange.week,
          direction: SnapDirection.nearest,
        ),
        tag(2026, 5, 11),
        reason: '58 h seit Montag, 110 h bis zum nächsten',
      );
    });

    test(
      'Monat, halbes Jahr und Jahr rasten alle drei auf den Monatsersten',
      () {
        final d = uhr(tag(2026, 5, 16), 17, 20);
        for (final stufe in const [
          ChartRange.month,
          ChartRange.halfYear,
          ChartRange.year,
        ]) {
          expect(
            ChartBuckets.snap(
              date: d,
              range: stufe,
              direction: SnapDirection.backward,
            ),
            tag(2026, 5, 1),
            reason: '$stufe rückwärts',
          );
          expect(
            ChartBuckets.snap(
              date: d,
              range: stufe,
              direction: SnapDirection.forward,
            ),
            tag(2026, 6, 1),
            reason: '$stufe vorwärts',
          );
        }
      },
    );

    test('`halfYear` rastet auf den Monatsersten, nicht auf den '
        'Halbjahresanfang', () {
      // Nachgetragene Klärung 6: „Sechs Monate sind das Fenster, der Monat
      // die Grenze." Ein Halbjahresanfang wäre hier der 01.07.2026.
      final d = uhr(tag(2026, 9, 15), 8);
      expect(
        ChartBuckets.snap(
          date: d,
          range: ChartRange.halfYear,
          direction: SnapDirection.backward,
        ),
        tag(2026, 9, 1),
      );
      expect(
        ChartBuckets.snap(
          date: d,
          range: ChartRange.halfYear,
          direction: SnapDirection.forward,
        ),
        tag(2026, 10, 1),
      );
    });

    test('`year` rastet auf den Monatsersten, nicht auf den 1. Januar', () {
      // **Hier weicht die Dart-Fassung bewusst von der Swift-Fassung ab.**
      // Siehe Entscheidung 2 im Dateikopf: Die Spec sagt es an zwei Stellen
      // verschieden; es gilt „Jahresgrenzen sind zu grob: Im geladenen Jahr
      // gibt es genau eine, rückwärts liegt die nächste außerhalb der Daten —
      // und dann rastet gar nichts." `app/test/shell/diagramm_zeitraum_test`
      // hat sich auf dieselbe Antwort festgelegt.
      final d = uhr(tag(2026, 5, 16), 17, 20);
      expect(
        ChartBuckets.snap(
          date: d,
          range: ChartRange.year,
          direction: SnapDirection.backward,
        ),
        tag(2026, 5, 1),
        reason:
            'Nicht tag(2026, 1, 1) — die Swift-Vorlage und `ChartBucketsTests'
            '.swift` sagen dort den 1. Januar; das ist genau die Stelle, an '
            'der eine wörtliche Portierung schiefgeht',
      );
      expect(
        ChartBuckets.snap(
          date: d,
          range: ChartRange.year,
          direction: SnapDirection.nearest,
        ),
        tag(2026, 6, 1),
        reason:
            'Vom 16.05. 17:20 sind es 15 Tage zurück und gut 15 vorwärts — '
            'bei Monatsgrenzen gewinnt der 1. Juni. Mit Jahresgrenzen käme '
            'hier der 01.01.2026 heraus',
      );
    });
  });

  group('snap: ein Zeitpunkt auf einer Grenze bleibt stehen', () {
    test('vorwärts und rückwärts lassen ihn stehen', () {
      final faelle = <(DateTime, ChartRange)>[
        (tag(2026, 5, 16), ChartRange.day),
        (tag(2026, 5, 11), ChartRange.week),
        (tag(2026, 5, 1), ChartRange.month),
        (tag(2026, 5, 1), ChartRange.halfYear),
        (tag(2026, 5, 1), ChartRange.year),
      ];
      for (final (d, stufe) in faelle) {
        expect(
          ChartBuckets.snap(
            date: d,
            range: stufe,
            direction: SnapDirection.backward,
          ),
          d,
          reason: '$stufe rückwärts',
        );
        expect(
          ChartBuckets.snap(
            date: d,
            range: stufe,
            direction: SnapDirection.forward,
          ),
          d,
          reason: '$stufe vorwärts',
        );
      }
    });

    test('`nearest` auf einer Grenze gibt den Zeitpunkt selbst zurück', () {
      // Nachgetragene Klärung 2. Folgt aus der Abstandsregel, steht aber
      // ausdrücklich da.
      final faelle = <(DateTime, ChartRange)>[
        (tag(2026, 5, 16), ChartRange.day),
        (tag(2026, 5, 11), ChartRange.week),
        (tag(2026, 5, 1), ChartRange.month),
        (tag(2026, 5, 1), ChartRange.halfYear),
        (tag(2026, 5, 1), ChartRange.year),
      ];
      for (final (d, stufe) in faelle) {
        expect(
          ChartBuckets.snap(
            date: d,
            range: stufe,
            direction: SnapDirection.nearest,
          ),
          d,
          reason: '$stufe',
        );
      }
    });

    test('auch eine Grenze hinter der Sommerzeitumstellung bleibt stehen', () {
      // Montag, 30.03.2026, 00:00 Berlin — der Tag davor hatte 23 Stunden.
      final montag = tag(2026, 3, 30);
      expect(BerlinCalendar.weekday(montag), DateTime.monday);
      for (final stufe in const [ChartRange.day, ChartRange.week]) {
        expect(
          ChartBuckets.snap(
            date: montag,
            range: stufe,
            direction: SnapDirection.backward,
          ),
          montag,
          reason: '$stufe rückwärts',
        );
        expect(
          ChartBuckets.snap(
            date: montag,
            range: stufe,
            direction: SnapDirection.forward,
          ),
          montag,
          reason: '$stufe vorwärts',
        );
      }
    });
  });

  group('snap: bei gleichem Abstand gewinnt die frühere Grenze', () {
    test('Tagesmitte: zwölf Stunden in beide Richtungen', () {
      expect(
        ChartBuckets.snap(
          date: uhr(tag(2026, 5, 16), 12),
          range: ChartRange.day,
          direction: SnapDirection.nearest,
        ),
        tag(2026, 5, 16),
      );
    });

    test('Wochenmitte: Donnerstag 12:00, je 84 Stunden', () {
      // Der 14.05.2026 ist ein Donnerstag; keine Umstellung in dieser Woche.
      expect(BerlinCalendar.weekday(tag(2026, 5, 14)), DateTime.thursday);
      expect(
        ChartBuckets.snap(
          date: uhr(tag(2026, 5, 14), 12),
          range: ChartRange.week,
          direction: SnapDirection.nearest,
        ),
        tag(2026, 5, 11),
      );
    });
  });

  group('snap über die Sommerzeitgrenze', () {
    test('die Umstellung auf Sommerzeit verschiebt keine Rastgrenze', () {
      // Sonntag, 29.03.2026, 13:45 Berliner Zeit. Die Umstellung lag um
      // 01:00 UTC, danach gilt +2: 13:45 − 2 h = 11:45 UTC.
      final sonntag = DateTime.utc(2026, 3, 29, 11, 45);

      DateTime rast(ChartRange stufe, SnapDirection richtung) =>
          ChartBuckets.snap(date: sonntag, range: stufe, direction: richtung);

      expect(rast(ChartRange.day, SnapDirection.backward), tag(2026, 3, 29));
      expect(rast(ChartRange.day, SnapDirection.forward), tag(2026, 3, 30));
      expect(rast(ChartRange.week, SnapDirection.backward), tag(2026, 3, 23));
      expect(rast(ChartRange.week, SnapDirection.forward), tag(2026, 3, 30));
      expect(rast(ChartRange.month, SnapDirection.backward), tag(2026, 3, 1));
      expect(rast(ChartRange.month, SnapDirection.forward), tag(2026, 4, 1));
    });

    test('eine halbe Stunde nach dem Montagsbeginn fällt nicht in die '
        'Vorwoche', () {
      // 30.03.2026 00:30 Berliner Zeit (+2) = 29.03. 22:30 UTC. Wer die
      // verlorene Stunde nicht kennt, rechnet die Grenze auf 01:00 lokal und
      // wirft diesen Zeitpunkt noch in die Vorwoche.
      final frueherMontag = DateTime.utc(2026, 3, 29, 22, 30);
      expect(
        ChartBuckets.snap(
          date: frueherMontag,
          range: ChartRange.week,
          direction: SnapDirection.backward,
        ),
        tag(2026, 3, 30),
      );
      expect(
        ChartBuckets.snap(
          date: frueherMontag,
          range: ChartRange.day,
          direction: SnapDirection.backward,
        ),
        tag(2026, 3, 30),
      );
    });

    test('die Umstellung auf Winterzeit verschiebt keine Rastgrenze', () {
      // Sonntag, 25.10.2026, 13:45 Berliner Zeit. Nach der Umstellung gilt
      // +1: 13:45 − 1 h = 12:45 UTC.
      final sonntag = DateTime.utc(2026, 10, 25, 12, 45);

      DateTime rast(ChartRange stufe, SnapDirection richtung) =>
          ChartBuckets.snap(date: sonntag, range: stufe, direction: richtung);

      expect(rast(ChartRange.day, SnapDirection.backward), tag(2026, 10, 25));
      expect(rast(ChartRange.day, SnapDirection.forward), tag(2026, 10, 26));
      expect(rast(ChartRange.week, SnapDirection.backward), tag(2026, 10, 19));
      expect(rast(ChartRange.week, SnapDirection.forward), tag(2026, 10, 26));
    });

    test('die doppelte Stunde am 25.10.2026 rastet beide Male gleich', () {
      // 02:30 gibt es zweimal: einmal mit +2 (00:30 UTC), einmal mit +1
      // (01:30 UTC). Zwei verschiedene Zeitpunkte, derselbe Kalendertag und
      // dieselbe Woche.
      final ersterDurchgang = DateTime.utc(2026, 10, 25, 0, 30);
      final zweiterDurchgang = DateTime.utc(2026, 10, 25, 1, 30);
      expect(ersterDurchgang, isNot(zweiterDurchgang));

      for (final d in [ersterDurchgang, zweiterDurchgang]) {
        expect(
          ChartBuckets.snap(
            date: d,
            range: ChartRange.day,
            direction: SnapDirection.backward,
          ),
          tag(2026, 10, 25),
        );
        expect(
          ChartBuckets.snap(
            date: d,
            range: ChartRange.week,
            direction: SnapDirection.backward,
          ),
          tag(2026, 10, 19),
        );
      }
    });

    test('die Umstellungswochen sind 167 und 169 Stunden lang, nicht 168', () {
      // Der Beweis, dass nicht mit `+ 7 * 86400` gerechnet wird.
      final imFruehjahr = uhr(tag(2026, 3, 25), 12);
      final fruehjahrVon = ChartBuckets.snap(
        date: imFruehjahr,
        range: ChartRange.week,
        direction: SnapDirection.backward,
      );
      final fruehjahrBis = ChartBuckets.snap(
        date: imFruehjahr,
        range: ChartRange.week,
        direction: SnapDirection.forward,
      );
      expect(fruehjahrVon, tag(2026, 3, 23));
      expect(fruehjahrBis, tag(2026, 3, 30));
      expect(fruehjahrBis.difference(fruehjahrVon), const Duration(hours: 167));

      final imHerbst = uhr(tag(2026, 10, 21), 12);
      final herbstVon = ChartBuckets.snap(
        date: imHerbst,
        range: ChartRange.week,
        direction: SnapDirection.backward,
      );
      final herbstBis = ChartBuckets.snap(
        date: imHerbst,
        range: ChartRange.week,
        direction: SnapDirection.forward,
      );
      expect(herbstVon, tag(2026, 10, 19));
      expect(herbstBis, tag(2026, 10, 26));
      expect(herbstBis.difference(herbstVon), const Duration(hours: 169));
    });

    test('der Monat März 2026 ist 743 Stunden lang, der Oktober 745', () {
      DateTime grenze(DateTime d, SnapDirection richtung) => ChartBuckets.snap(
        date: d,
        range: ChartRange.month,
        direction: richtung,
      );

      final imMaerz = uhr(tag(2026, 3, 15), 12);
      expect(
        grenze(
          imMaerz,
          SnapDirection.forward,
        ).difference(grenze(imMaerz, SnapDirection.backward)),
        const Duration(hours: 743),
        reason: '31 Tage, einer davon mit 23 Stunden',
      );

      final imOktober = uhr(tag(2026, 10, 15), 12);
      expect(
        grenze(
          imOktober,
          SnapDirection.forward,
        ).difference(grenze(imOktober, SnapDirection.backward)),
        const Duration(hours: 745),
        reason: '31 Tage, einer davon mit 25 Stunden',
      );
    });
  });

  group('ChartPoint ist ein Werttyp', () {
    // Bewusst **nicht** `const`: Dart kanonisiert konstante Ausdrücke, ein
    // Set aus vier gleich geschriebenen `const`-Punkten hätte auch ohne
    // überschriebenes `==`/`hashCode` die erwartete Größe — der Test wäre
    // tautologisch. Genau das ist am 27.10.2026 in
    // `recovery_snapshot_test.dart` passiert.
    ChartPoint punkt(DateTime start, double wert, int tage) =>
        ChartPoint(start: start, value: wert, dayCount: tage);

    test('gleiche Felder sind gleich — sonst rechnet jedes Bild neu', () {
      final a = punkt(tag(2026, 10, 12), 42, 1);
      final b = punkt(tag(2026, 10, 12), 42, 1);
      expect(
        b,
        isNot(same(a)),
        reason:
            'Testvoraussetzung: wirklich zwei Objekte, sonst beweist der '
            'Vergleich nichts',
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('jedes abweichende Feld macht ungleich', () {
      final a = punkt(tag(2026, 10, 12), 42, 1);
      expect(a, isNot(punkt(tag(2026, 10, 13), 42, 1)));
      expect(a, isNot(punkt(tag(2026, 10, 12), 43, 1)));
      expect(a, isNot(punkt(tag(2026, 10, 12), 42, 2)));
    });

    test('`hashCode` trennt die Varianten — vier verschiedene Punkte', () {
      final punkte = [
        punkt(tag(2026, 10, 12), 42, 1),
        punkt(tag(2026, 10, 12), 42, 1),
        punkt(tag(2026, 10, 13), 42, 1),
        punkt(tag(2026, 10, 12), 43, 1),
        punkt(tag(2026, 10, 12), 42, 2),
      ];
      expect(punkte[1], isNot(same(punkte[0])));
      expect(
        punkte.toSet(),
        hasLength(4),
        reason:
            'Ein `Set` geht über `hashCode` **und** `==`. Fehlt `hashCode`, '
            'bleiben fünf Einträge stehen',
      );
    });
  });

  group('ChartSample ist ein Werttyp', () {
    // Gilt aus demselben Grund wie bei `ChartPoint`: Die Reihe ist die
    // Abhängigkeit, aus der ein Provider die Punkte ableitet. Ohne `==` auf
    // den Elementen ist jede neu gebaute Liste ungleich der vorigen, und
    // alles Abgeleitete läuft neu — das wäre `03`, wortgleich, im neuen Code.
    ChartSample probe(DateTime zeitpunkt, double wert) =>
        ChartSample(date: zeitpunkt, value: wert);

    test('gleiche Felder sind gleich', () {
      final a = probe(tag(2026, 10, 12), 42);
      final b = probe(tag(2026, 10, 12), 42);
      expect(b, isNot(same(a)));
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('jedes abweichende Feld macht ungleich', () {
      final a = probe(tag(2026, 10, 12), 42);
      expect(a, isNot(probe(tag(2026, 10, 13), 42)));
      expect(a, isNot(probe(tag(2026, 10, 12), 43)));
    });

    test('`hashCode` trennt die Varianten', () {
      final proben = [
        probe(tag(2026, 10, 12), 42),
        probe(tag(2026, 10, 12), 42),
        probe(tag(2026, 10, 13), 42),
        probe(tag(2026, 10, 12), 43),
      ];
      expect(proben[1], isNot(same(proben[0])));
      expect(proben.toSet(), hasLength(3));
    });
  });
}
