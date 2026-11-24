import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für den **Schnappschuss** aus Ticket #112 — Spec
/// `2026-10-26-erholung-flutter-design.md` Abschnitte 6 und 8.
///
/// In Swift liegt diese Rechnung als `Sources/Features/Recovery/RecoverySnapshot.swift`
/// (245 Zeilen) **im App-Target und ist vollständig ungetestet** — zusammen
/// mit den beiden Regeln, die der Schirm am leichtesten falsch macht. In
/// Dart gehört sie nach `trainings_core` und bekommt Tests. Das ist der
/// stärkste Einzelgewinn der Portierung, und die beiden Regeln sind der
/// Grund für dieses Ticket:
///
/// 1. **Der heutige Wert gehört nicht in seinen eigenen Median.** Sonst
///    zieht ein Ausreißer seine eigene Schwelle mit sich.
/// 2. **Jeder Tag des Bands wird gegen den Median der Tage davor
///    gerechnet** — sonst zeigt das Band von gestern etwas anderes als die
///    Ampel von gestern.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, nie verändert werden.
///
/// ## API, die diese Tests verbindlich vorgeben
///
/// ```dart
/// /// Reihenfolge der Verlaufszeilen. **Nicht** dieselbe wie
/// /// `RecoveryMetric` (Schlaf · Ruhepuls · HRV · Atemfrequenz) — die hängt
/// /// an den vier Vierteln des Erholungsrings, diese an der Reihenfolge der
/// /// Zeilen auf `erholung-werte`. Zwei Verträge, zwei Enums.
/// enum RecoveryTrendKind {
///   sleep, hrv, restingHeartRate, respiratoryRate, alcoholDays,
/// }
///
/// class RecoveryTrend {
///   const RecoveryTrend({
///     required RecoveryTrendKind kind,
///     required double? average,  // null = keine Werte, nie 0
///     required int count,        // Tage/Nächte, die den Schnitt tragen
///   });
///   // Wertgleichheit.
/// }
///
/// class DaySignals {
///   const DaySignals({
///     required DateTime date,
///     required int count,     // Zahl der Warnsignale dieses Tages
///     required bool measured, // ob überhaupt gemessen wurde
///   });
///   // Wertgleichheit.
/// }
///
/// class RecoverySnapshot {
///   static RecoverySnapshot make({
///     required List<RecoveryDay> days,
///     required List<RecoveryNight> nights,
///     required DateTime today,
///     required double sleepGoalHours,
///     required double bedtimeGoalMinutes,
///     List<DateTime> alcoholDays = const [],
///     bool isPostOperative = false,
///     DataWindow? window,       // null = unbegrenzt
///     int windowDays = 30,
///   });
///
///   final DateTime today;               // Berliner Tagesbeginn
///   final RecoveryReading reading;
///   final RecoveryBaseline baseline;
///   final bool isPostOperative;
///   final RecoveryNight? night;         // die Nacht des Bezugstages
///   final SleepScore? score;            // ihr Score
///   final List<RecoveryDay> days;       // im Fenster, älteste zuerst
///   final List<RecoveryNight> nights;   // im Fenster, mit Schlafminuten
///   final List<RecoveryTrend> trends;   // feste Reihenfolge, immer fünf
///   final List<DaySignals> signalHistory; // je Tag in `days`, älteste zuerst
///   final double weekMinutes;
///   final DateTime? lastSeen;           // nur wenn gar nichts vorliegt
///   RecoveryEvaluation get evaluation;
///   // Wertgleichheit ist hier **nicht** verlangt.
/// }
/// ```
///
/// ### Keine Nutzertexte
///
/// Swift gibt `dateLine`, `Night.duration`, `Trend.title` und
/// `"Zuletzt am Donnerstag, 08.10."` als fertig beschriftete Zeichenketten
/// zurück. Das geht in `trainings_core` nicht (`CLAUDE.md`, Spec Abschnitt
/// 6): Der Kern liefert Zahlen, Daten und Enums, die Views beschriften. Aus
/// `lastSeen: String?` wird deshalb `DateTime?`, aus `Trend.title` ein
/// `RecoveryTrendKind`, und `dateLine` entfällt zugunsten von `today`.
///
/// ### Entscheidungen dieser Testdatei, die weder Ticket noch Spec treffen
///
/// - **Alkohol-Tage kommen als Liste von Tagen herein** (`alcoholDays`).
///   Ticket #112 zählt sie zu den Verläufen, abgelegt werden sie erst in
///   #119. Die Zeile trägt deshalb `average: null` (ein Durchschnitt über
///   Ja/Nein ist keine Zahl, die jemand lesen will) und `count` = Zahl der
///   Alkohol-Tage **im Fenster**. Bis #119 reicht die App eine leere Liste
///   herein, und die Zeile sagt ehrlich „null".
/// - **Das Signalband ignoriert `isPostOperative`.** Es zeigt, was gemessen
///   wurde, nicht wie die Ampel heute steht. Swift macht es genauso.
/// - **`weekMinutes` rechnet über die geklippten Tage.** Wer den
///   Betrachtungszeitraum auf drei Tage stellt, sieht auch nur drei Tage
///   Wochenlast — eine Zahl, die Tage mitzählt, die der Nutzer ausgeblendet
///   hat, wäre eine andere Zahl als jede andere auf dem Schirm.
/// - **`lastSeen` sucht nur im Fenster und nur vor heute.** Mehr Daten
///   stehen nicht zur Verfügung; „seit mindestens 30 Tagen kein Wert" ist
///   dann der Satz der View für `null`.
/// - **Tage nach `today` fallen heraus.** Ein Zeitstempel aus der Zukunft
///   ist kein Fehler, sondern ein Gerät mit verstellter Uhr.
///
/// **Alle Zahlen hier sind erfunden** und bewusst rund.
void main() {
  /// Mittwoch, 17.06.2026 (01.06.2026 ist ein Montag). `versatz` zählt Tage
  /// rückwärts: `tag(0)` ist heute, `tag(-1)` gestern.
  DateTime tag(int versatz) =>
      BerlinCalendar.startOfDay(DateTime.utc(2026, 6, 17 + versatz));

  final heute = tag(0);

  // 22:30 als Schlafenszeitziel (#111 legt es mit dieser Vorbelegung ab).
  final zielBett = EveningClock.minutesSinceEveningOfClock(
    hour: 22,
    minute: 30,
  );

  RecoverySnapshot bauen({
    List<RecoveryDay> days = const [],
    List<RecoveryNight> nights = const [],
    DateTime? today,
    List<DateTime> alcoholDays = const [],
    bool isPostOperative = false,
    DataWindow? window,
    int windowDays = 30,
  }) => RecoverySnapshot.make(
    days: days,
    nights: nights,
    today: today ?? heute,
    sleepGoalHours: 8,
    bedtimeGoalMinutes: zielBett,
    alcoholDays: alcoholDays,
    isPostOperative: isPostOperative,
    window: window,
    windowDays: windowDays,
  );

  group('Die heutige Nacht', () {
    test('wird am Datum von heute erkannt', () {
      final schnappschuss = bauen(
        nights: [
          RecoveryNight(date: tag(-1), asleepMinutes: 300),
          RecoveryNight(
            date: heute,
            asleepMinutes: 480,
            bedtime: DateTime.utc(2026, 6, 16, 20, 30), // 22:30 Berlin
          ),
        ],
      );

      expect(schnappschuss.night?.date, heute);
      expect(schnappschuss.reading.sleepHours, 8.0);
      expect(schnappschuss.score?.duration, 50);
      expect(schnappschuss.score?.bedtime, 30);
    });

    test('eine Nacht ohne Schlafminuten zählt nicht als heutige Nacht', () {
      // Das Kriterium sind die Schlafminuten, nicht „keine Abschnitte": Eine
      // Nacht aus lauter Wachabschnitten ist nicht leer, aber auch kein
      // Schlaf.
      final schnappschuss = bauen(
        nights: [
          RecoveryNight(date: heute, asleepMinutes: 0, awakeMinutes: 150),
        ],
      );

      expect(schnappschuss.night, isNull);
      expect(schnappschuss.score, isNull);
      expect(schnappschuss.reading.sleepHours, isNull);
    });

    test('die Nacht von gestern ist nicht die heutige Nacht', () {
      final schnappschuss = bauen(
        nights: [RecoveryNight(date: tag(-1), asleepMinutes: 480)],
      );

      expect(schnappschuss.night, isNull);
      expect(schnappschuss.reading.sleepHours, isNull);
      // In der Liste für Diagramm und Verlauf steht sie trotzdem.
      expect(schnappschuss.nights, hasLength(1));
    });

    test('Nächte ohne Schlafminuten fehlen auch in der Liste', () {
      final schnappschuss = bauen(
        nights: [
          RecoveryNight(date: tag(-2), asleepMinutes: 0),
          RecoveryNight(date: tag(-1), asleepMinutes: 480),
        ],
      );

      expect(schnappschuss.nights.map((n) => n.date), [tag(-1)]);
    });
  });

  group('Regel 1: der heutige Wert gehört nicht in seinen eigenen Median',
      () {
    test('ein Ausreißer von heute zieht seine Schwelle nicht mit', () {
      // Fünf frühere Tage mit 10, 20, 30, 40, 50 -> Median (obere Mitte) 30.
      // Rechnete der heutige Wert 1000 mit, wären es sechs Werte und der
      // Median läge bei 40 — die Schwelle wanderte dem Ausreißer hinterher.
      final schnappschuss = bauen(
        days: [
          for (var i = 5; i >= 1; i--)
            RecoveryDay(date: tag(-i), hrv: (60 - i * 10).toDouble()),
          RecoveryDay(date: heute, hrv: 1000),
        ],
      );

      expect(schnappschuss.baseline.hrv, 30.0);
      expect(schnappschuss.reading.hrv, 1000.0);
    });

    test('vier frühere Tage reichen nicht für einen Median, auch nicht '
        'zusammen mit heute', () {
      final schnappschuss = bauen(
        days: [
          for (var i = 4; i >= 1; i--)
            RecoveryDay(date: tag(-i), hrv: (60 - i * 10).toDouble()),
          RecoveryDay(date: heute, hrv: 55),
        ],
      );

      expect(schnappschuss.baseline.hrv, isNull);
      expect(schnappschuss.reading.hrv, 55.0);
    });

    test('auch die heutige Nacht fehlt in ihrem eigenen Schlaf-Median', () {
      final schnappschuss = bauen(
        nights: [
          for (var i = 5; i >= 1; i--)
            RecoveryNight(date: tag(-i), asleepMinutes: (600 - i * 60).toDouble()),
          RecoveryNight(date: heute, asleepMinutes: 60),
        ],
      );

      // Frühere Nächte: 540, 480, 420, 360, 300 Minuten = 9, 8, 7, 6, 5 h,
      // obere Mitte ist 7.
      expect(schnappschuss.baseline.sleepHours, 7.0);
      expect(schnappschuss.reading.sleepHours, 1.0);
    });
  });

  group('Regel 2: jeder Tag des Bands gegen den Median der Tage davor', () {
    /// Zwölf Tage, alle unauffällig — bis auf `tag(-6)`, dessen HRV
    /// einbricht. Ruhepuls und Atmung bleiben konstant, damit genau ein
    /// Signal entstehen kann.
    List<RecoveryDay> zwoelfTage() => [
      for (var i = 11; i >= 0; i--)
        RecoveryDay(
          date: tag(-i),
          restingHeartRate: 50,
          hrv: i == 6 ? 10.0 : 100.0,
          respiratoryRate: 14,
        ),
    ];

    test('ein Tag des Bands ändert sich nicht, wenn spätere Tage '
        'dazukommen', () {
      final kurz = bauen(days: zwoelfTage(), today: tag(-6));
      final lang = bauen(days: zwoelfTage(), today: heute);

      DaySignals eintrag(RecoverySnapshot s) =>
          s.signalHistory.firstWhere((e) => e.date == tag(-6));

      expect(eintrag(lang), eintrag(kurz));
      expect(eintrag(lang).count, 1);
      expect(eintrag(lang).measured, isTrue);
    });

    test('das Band ist nach Datum geordnet, älteste zuerst', () {
      final schnappschuss = bauen(days: zwoelfTage().reversed.toList());

      expect(
        schnappschuss.signalHistory.map((e) => e.date).toList(),
        [for (var i = 11; i >= 0; i--) tag(-i)],
      );
    });

    test('der erste Tag hat keine Vortage und damit keine Mediane', () {
      final schnappschuss = bauen(days: zwoelfTage());
      final erster = schnappschuss.signalHistory.first;

      expect(erster.date, tag(-11));
      // Gemessen wurde an diesem Tag — nur vergleichen lässt er sich mit
      // nichts.
      expect(erster.measured, isTrue);
      expect(erster.count, 0);
    });

    test('nicht gemessen ist etwas anderes als null Signale', () {
      final schnappschuss = bauen(
        days: [
          for (var i = 5; i >= 1; i--)
            RecoveryDay(
              date: tag(-i),
              restingHeartRate: 50,
              hrv: 100,
              respiratoryRate: 14,
            ),
          // Heute: alles leer. Das ist keine ruhige Nacht, das ist gar keine.
          RecoveryDay(date: heute),
        ],
      );

      final gestern = schnappschuss.signalHistory
          .firstWhere((e) => e.date == tag(-1));
      final heuteImBand =
          schnappschuss.signalHistory.firstWhere((e) => e.date == heute);

      expect(gestern.measured, isTrue);
      expect(gestern.count, 0);
      expect(heuteImBand.measured, isFalse);
      expect(heuteImBand.count, 0);
      // Beide zeigen „0 Signale" — und bedeuten das Gegenteil voneinander.
      expect(heuteImBand, isNot(gestern));
    });

    test('nach der OP bleibt das Band, wie es gemessen wurde', () {
      // Entscheidung dieser Testdatei: Das Band zeigt die Vergangenheit,
      // nicht den heutigen Zustand der Ampel. Die Ampel ruht, das Band
      // nicht.
      final schnappschuss = bauen(
        days: zwoelfTage(),
        isPostOperative: true,
      );

      expect(
        schnappschuss.evaluation.verdict,
        RecoveryVerdict.postOperative,
      );
      expect(
        schnappschuss.signalHistory.firstWhere((e) => e.date == tag(-6)).count,
        1,
      );
    });
  });

  group('Das Fenster', () {
    test('reicht 30 Tage zurück, einschließlich heute', () {
      final schnappschuss = bauen(
        days: [
          RecoveryDay(date: tag(-30), hrv: 1),
          RecoveryDay(date: tag(-29), hrv: 2),
          RecoveryDay(date: heute, hrv: 3),
        ],
      );

      expect(
        schnappschuss.days.map((d) => d.date).toList(),
        [tag(-29), heute],
      );
    });

    test('ein Tag aus der fernen Vergangenheit fällt heraus', () {
      final schnappschuss = bauen(
        days: [RecoveryDay(date: tag(-40), hrv: 1), RecoveryDay(date: heute)],
      );

      expect(schnappschuss.days.map((d) => d.date), [heute]);
    });

    test('ein Tag aus der Zukunft fällt heraus', () {
      final schnappschuss = bauen(
        days: [RecoveryDay(date: heute), RecoveryDay(date: tag(1), hrv: 99)],
      );

      expect(schnappschuss.days.map((d) => d.date), [heute]);
    });

    test('der Betrachtungszeitraum kürzt das Fenster', () {
      final schnappschuss = bauen(
        days: [
          for (var i = 10; i >= 0; i--) RecoveryDay(date: tag(-i), hrv: 50),
        ],
        window: DataWindow(start: tag(-3)),
      );

      expect(
        schnappschuss.days.map((d) => d.date).toList(),
        [tag(-3), tag(-2), tag(-1), heute],
      );
    });

    test('der Betrachtungszeitraum verlängert das Fenster nie', () {
      final schnappschuss = bauen(
        days: [
          RecoveryDay(date: tag(-45), hrv: 1),
          RecoveryDay(date: tag(-29), hrv: 2),
          RecoveryDay(date: heute, hrv: 3),
        ],
        window: DataWindow(start: tag(-60)),
      );

      expect(
        schnappschuss.days.map((d) => d.date).toList(),
        [tag(-29), heute],
      );
    });

    test('windowDays ist überschreibbar', () {
      final schnappschuss = bauen(
        days: [
          for (var i = 10; i >= 0; i--) RecoveryDay(date: tag(-i), hrv: 50),
        ],
        windowDays: 3,
      );

      expect(
        schnappschuss.days.map((d) => d.date).toList(),
        [tag(-2), tag(-1), heute],
      );
    });

    test('das Fenster greift auch für die Nächte', () {
      final schnappschuss = bauen(
        nights: [
          RecoveryNight(date: tag(-40), asleepMinutes: 480),
          RecoveryNight(date: tag(-2), asleepMinutes: 480),
        ],
      );

      expect(schnappschuss.nights.map((n) => n.date), [tag(-2)]);
    });

    test('die Eingabe darf unsortiert sein', () {
      final schnappschuss = bauen(
        days: [
          RecoveryDay(date: tag(-1), hrv: 1),
          RecoveryDay(date: tag(-5), hrv: 2),
          RecoveryDay(date: heute, hrv: 3),
        ],
      );

      expect(
        schnappschuss.days.map((d) => d.date).toList(),
        [tag(-5), tag(-1), heute],
      );
    });
  });

  group('Die Verläufe', () {
    test('kommen in fester Reihenfolge und sind immer fünf', () {
      // **Nicht** die Reihenfolge der Ring-Viertel (`RecoveryMetric`):
      // Die Zeilen auf `erholung-werte` stehen Schlaf, HRV, Ruhepuls,
      // Atemfrequenz, Alkohol-Tage. Zwei Verträge, zwei Enums.
      final schnappschuss = bauen();

      expect(schnappschuss.trends.map((t) => t.kind).toList(), [
        RecoveryTrendKind.sleep,
        RecoveryTrendKind.hrv,
        RecoveryTrendKind.restingHeartRate,
        RecoveryTrendKind.respiratoryRate,
        RecoveryTrendKind.alcoholDays,
      ]);
      expect(RecoveryTrendKind.values, schnappschuss.trends.map((t) => t.kind));
    });

    RecoveryTrend verlauf(RecoverySnapshot s, RecoveryTrendKind art) =>
        s.trends.firstWhere((t) => t.kind == art);

    test('tragen Durchschnitt und die Zahl der Tage **davor**', () {
      // Seit #266 zählen beide denselben Satz Tage wie der Median: die
      // **vor** dem gewählten. Der heutige Wert gehört nicht in seinen
      // eigenen Vergleich, und „9 Tage · Median 60 ms" nannte bis dahin
      // zwei verschieden große Mengen in einer Zeile.
      final schnappschuss = bauen(
        days: [
          RecoveryDay(date: tag(-2), hrv: 10, respiratoryRate: 12),
          RecoveryDay(date: tag(-1), hrv: 20),
          RecoveryDay(date: heute, hrv: 30, respiratoryRate: 14),
        ],
        nights: [
          RecoveryNight(date: tag(-1), asleepMinutes: 360), // 6 h
          RecoveryNight(date: heute, asleepMinutes: 480), // 8 h
        ],
      );

      expect(verlauf(schnappschuss, RecoveryTrendKind.hrv).average, 15.0);
      expect(verlauf(schnappschuss, RecoveryTrendKind.hrv).count, 2);

      expect(
        verlauf(schnappschuss, RecoveryTrendKind.respiratoryRate).average,
        12.0,
      );
      expect(
        verlauf(schnappschuss, RecoveryTrendKind.respiratoryRate).count,
        1,
      );

      expect(verlauf(schnappschuss, RecoveryTrendKind.sleep).average, 6.0);
      expect(verlauf(schnappschuss, RecoveryTrendKind.sleep).count, 1);
    });

    test('ohne Werte bleibt der Durchschnitt null und zählt nicht als 0', () {
      final schnappschuss = bauen(
        days: [RecoveryDay(date: heute, hrv: 50)],
      );
      final puls = verlauf(schnappschuss, RecoveryTrendKind.restingHeartRate);

      expect(puls.average, isNull);
      expect(puls.count, 0);
    });

    test('Nächte ohne Schlafminuten tragen den Schlaf-Schnitt nicht', () {
      // Beide Nächte liegen **vor** heute, damit der Fall von der
      // Aussortierung handelt und nicht vom Fenster (#266).
      final schnappschuss = bauen(
        nights: [
          RecoveryNight(date: tag(-2), asleepMinutes: 0, awakeMinutes: 90),
          RecoveryNight(date: tag(-1), asleepMinutes: 480),
        ],
      );
      final schlaf = verlauf(schnappschuss, RecoveryTrendKind.sleep);

      expect(schlaf.average, 8.0);
      expect(schlaf.count, 1);
    });

    test('Alkohol-Tage zählen nur im Fenster und tragen keinen Schnitt', () {
      final schnappschuss = bauen(
        alcoholDays: [tag(-1), tag(-3), tag(-45)],
      );
      final alkohol = verlauf(schnappschuss, RecoveryTrendKind.alcoholDays);

      expect(alkohol.average, isNull);
      expect(alkohol.count, 2);
    });

    test('der Betrachtungszeitraum kürzt auch die Verläufe', () {
      final schnappschuss = bauen(
        days: [
          RecoveryDay(date: tag(-5), hrv: 0),
          RecoveryDay(date: tag(-2), hrv: 10),
          RecoveryDay(date: tag(-1), hrv: 30),
          RecoveryDay(date: heute, hrv: 999),
        ],
        window: DataWindow(start: tag(-2)),
      );

      // Der 5. Tag liegt vor dem Fenster, der heutige zählt seit #266 in
      // seiner eigenen Zeile nicht mit. Bleiben 10 und 30.
      expect(verlauf(schnappschuss, RecoveryTrendKind.hrv).average, 20.0);
      expect(verlauf(schnappschuss, RecoveryTrendKind.hrv).count, 2);
    });
  });

  group('Die Wochenminuten', () {
    test('summieren die laufende Woche, Montag bis Sonntag', () {
      // Heute ist Mittwoch, der 17.06.2026. Die Woche beginnt am Montag,
      // dem 15.06. — der Sonntag davor zählt nicht mehr mit.
      final schnappschuss = bauen(
        days: [
          RecoveryDay(date: tag(-3), exerciseMinutes: 1000), // So, 14.06.
          RecoveryDay(date: tag(-2), exerciseMinutes: 30), // Mo, 15.06.
          RecoveryDay(date: tag(-1), exerciseMinutes: 20),
          RecoveryDay(date: heute, exerciseMinutes: 10),
        ],
      );

      expect(schnappschuss.weekMinutes, 60.0);
    });

    test('ohne Werte sind es 0 Minuten', () {
      expect(bauen().weekMinutes, 0.0);
    });

    test('der Betrachtungszeitraum kürzt auch die Wochenlast', () {
      final schnappschuss = bauen(
        days: [
          RecoveryDay(date: tag(-2), exerciseMinutes: 30),
          RecoveryDay(date: tag(-1), exerciseMinutes: 20),
          RecoveryDay(date: heute, exerciseMinutes: 10),
        ],
        window: DataWindow(start: tag(-1)),
      );

      expect(schnappschuss.weekMinutes, 30.0);
    });
  });

  group('Zuletzt gesehen', () {
    test('wird aus den Daten gerechnet, nicht hartcodiert', () {
      // Bis zum 13.10. stand hier ein festes Datum im Quelltext.
      final schnappschuss = bauen(
        days: [
          RecoveryDay(date: tag(-5), restingHeartRate: 50),
          RecoveryDay(date: tag(-3), hrv: 60),
          RecoveryDay(date: tag(-1)), // leer, zählt nicht
          RecoveryDay(date: heute),
        ],
      );

      expect(schnappschuss.lastSeen, tag(-3));
    });

    test('eine Nacht zählt genauso wie ein Tageswert', () {
      final schnappschuss = bauen(
        days: [RecoveryDay(date: tag(-5), hrv: 60), RecoveryDay(date: heute)],
        nights: [RecoveryNight(date: tag(-2), asleepMinutes: 480)],
      );

      expect(schnappschuss.lastSeen, tag(-2));
    });

    test('eine Nacht ohne Schlafminuten zählt nicht', () {
      final schnappschuss = bauen(
        days: [RecoveryDay(date: tag(-5), hrv: 60), RecoveryDay(date: heute)],
        nights: [RecoveryNight(date: tag(-2), asleepMinutes: 0)],
      );

      expect(schnappschuss.lastSeen, tag(-5));
    });

    test('bleibt leer, solange heute überhaupt etwas vorliegt', () {
      final schnappschuss = bauen(
        days: [
          RecoveryDay(date: tag(-3), hrv: 60),
          RecoveryDay(date: heute, hrv: 55),
        ],
      );

      expect(schnappschuss.lastSeen, isNull);
    });

    test('bleibt leer, wenn es nie einen Wert gab', () {
      expect(bauen().lastSeen, isNull);
      expect(bauen(days: [RecoveryDay(date: heute)]).lastSeen, isNull);
    });
  });

  group('Leere Eingabe und Lücken', () {
    test('ohne jede Eingabe steht alles ehrlich leer', () {
      final schnappschuss = bauen();

      expect(schnappschuss.today, heute);
      expect(schnappschuss.reading, const RecoveryReading());
      expect(schnappschuss.baseline, const RecoveryBaseline());
      expect(schnappschuss.night, isNull);
      expect(schnappschuss.score, isNull);
      expect(schnappschuss.days, isEmpty);
      expect(schnappschuss.nights, isEmpty);
      expect(schnappschuss.signalHistory, isEmpty);
      expect(schnappschuss.weekMinutes, 0.0);
      expect(schnappschuss.lastSeen, isNull);
      expect(schnappschuss.evaluation.verdict, RecoveryVerdict.noData);
      expect(schnappschuss.trends, hasLength(5));
      expect(
        schnappschuss.trends.every((t) => t.average == null && t.count == 0),
        isTrue,
      );
    });

    test('Lücken mitten im Fenster räumen den Median nicht weg', () {
      // Sechs gemessene Tage, zwischen ihnen und bis heute lauter Lücken.
      // Wer die Lücken als Nullen mitzählt oder das Fenster vor dem
      // Aussortieren schneidet, verliert den Median.
      final schnappschuss = bauen(
        days: [
          for (var i = 20; i >= 0; i--)
            RecoveryDay(
              date: tag(-i),
              hrv: i.isEven && i >= 10 ? (i * 10).toDouble() : null,
            ),
        ],
      );

      // Gemessen: i = 20, 18, 16, 14, 12, 10 -> 200, 180, 160, 140, 120, 100.
      // In Listenreihenfolge (älteste zuerst) sortiert: 100..200, obere
      // Mitte von sechs Werten ist 160.
      expect(schnappschuss.baseline.hrv, 160.0);
    });

    test('eine Lücke lässt den Tag im Band als nicht gemessen stehen', () {
      final schnappschuss = bauen(
        days: [
          for (var i = 10; i >= 0; i--)
            RecoveryDay(date: tag(-i), hrv: i == 4 ? null : 100.0),
        ],
      );

      final luecke =
          schnappschuss.signalHistory.firstWhere((e) => e.date == tag(-4));
      expect(luecke.measured, isFalse);
      expect(luecke.count, 0);
      // Der Tag daneben ist gemessen — die Lücke steckt nicht an.
      expect(
        schnappschuss.signalHistory
            .firstWhere((e) => e.date == tag(-3))
            .measured,
        isTrue,
      );
    });
  });

  group('Die Ampel des Schnappschusses', () {
    test('liest reading, baseline und den OP-Zustand', () {
      final schnappschuss = bauen(
        days: [
          for (var i = 5; i >= 1; i--) RecoveryDay(date: tag(-i), hrv: 100),
          RecoveryDay(date: heute, hrv: 10),
        ],
      );

      expect(schnappschuss.evaluation.signals, [RecoveryMetric.hrv]);
      expect(schnappschuss.evaluation.verdict, RecoveryVerdict.watch);
      expect(schnappschuss.evaluation.measuredCount, 1);
    });

    test('nach der OP ruht sie', () {
      final schnappschuss = bauen(
        days: [RecoveryDay(date: heute, hrv: 10)],
        isPostOperative: true,
      );

      expect(schnappschuss.isPostOperative, isTrue);
      expect(
        schnappschuss.evaluation.verdict,
        RecoveryVerdict.postOperative,
      );
    });
  });
}
