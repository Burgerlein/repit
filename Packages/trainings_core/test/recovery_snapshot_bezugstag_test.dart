import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für **Stufe 1 von #261** — der Bezugstag wird Parameter. Spec:
/// `docs/superpowers/specs/2026-11-03-erholung-tageswechsel.md`, Abschnitt
/// „Stufe 1 — Der Bezugstag wird Parameter".
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Zum Zeitpunkt dieser Datei gibt es `selectedDay`, `night` und `rated`
/// nicht; der Lauf ist rot, und das ist der erwartete Zustand. Diese Datei
/// darf ausgeführt, nie verändert werden.
///
/// ## Worum es geht
///
/// Der Erholungs-Schirm soll durch die Tage blättern. Dafür rechnet
/// `RecoverySnapshot.make` nicht mehr fest für heute, sondern für einen
/// gewählten Tag. `today` behält dabei seine Bedeutung — Ende des Fensters,
/// Grenze nach vorn, Bezug für „was ist heute" — und wird **nicht**
/// umgedeutet.
///
/// **Die stille Katastrophe, gegen die diese Datei gebaut ist:** eine
/// gemischte Paarung. Der Wert von damals gegen den Median von heute (oder
/// umgekehrt) ergibt zwei plausible Zahlen und eine falsche Ampel. Niemand
/// sieht sie dem Schirm an — es steht eine Ampel da, sie ist nur die
/// falsche. Die Spec nennt dafür zwei Invarianten, und beide stehen unten
/// als Test:
///
/// - **Invariante A.** `make(…, selectedDay: d).evaluation.signals.length`
///   ist gleich dem `signalHistory`-Eintrag für `d`. Das Band rechnet seit
///   jeher je Tag gegen `baselineBefore(day.date)` (Regel 2 im Kopf von
///   `recovery_snapshot.dart`) — es ist die zweite, unabhängig entstandene
///   Rechnung derselben Sache.
/// - **Invariante B.** Nichts aus der Zukunft des gewählten Tages darf in
///   eine Zahl eingehen, die der Schirm zeigt. Tage und Nächte **nach** `d`
///   aus der Eingabe entfernen ändert nichts.
///
/// ## API, die diese Tests verbindlich vorgeben
///
/// ```dart
/// static RecoverySnapshot make({
///   required List<RecoveryDay> days,
///   required List<RecoveryNight> nights,
///   required DateTime today,
///   DateTime? selectedDay,        // neu; null heißt „heute"
///   required double sleepGoalHours,
///   required double bedtimeGoalMinutes,
///   List<DateTime> alcoholDays = const [],
///   bool isPostOperative = false,
///   DataWindow? window,
///   int windowDays = 30,
/// });
///
/// final DateTime today;        // unverändert: Berliner Tagesbeginn von heute
/// final DateTime selectedDay;  // neu: geklemmter Berliner Tagesbeginn
/// final RecoveryNight? night;  // vorher `lastNight`
/// ```
///
/// `RecoveryEvaluation` bekommt `rated` — die Metriken, über die die Ampel
/// überhaupt eine Aussage gemacht hat. Die Fälle dazu stehen in
/// `recovery_traffic_light_rated_test.dart`; hier wird `rated` nur dort
/// geprüft, wo der Bezugstag ihn ändert.
///
/// ## Entscheidungen dieser Testdatei
///
/// - **Der Rückfall wird gegen den ausdrücklichen heutigen Tag geprüft**
///   (`selectedDay: null` gegen `selectedDay: heute`) **und** zusätzlich
///   gegen von Hand gerechnete Zahlen. Die Gleichheit allein wäre auch dann
///   erfüllt, wenn beide Wege gemeinsam falsch rechnen.
/// - **Die Alkohol-Zeile wird als day-relativ geprüft** (sie ist Teil von
///   `trends`, und `trends` wandert mit). Das Datum daneben —
///   `lastAlcoholDay`, „zuletzt am …" — gibt es seit #268 nicht mehr: Es
///   wanderte **nicht** mit und konnte auf einem früheren Tag ein Datum
///   nach dem gewählten zeigen. An seiner Stelle steht `alcoholEve`, die
///   Auskunft über den Vortag; sie wandert zwangsläufig mit, und ihre
///   Fälle stehen in `alcohol_eve_test.dart`.
///
/// **Alle Zahlen hier sind erfunden** und bewusst rund. Keine echten
/// Gesundheitswerte, keine echten Termine.
void main() {
  /// Mittwoch, 17.06.2026 (01.06.2026 ist ein Montag). `versatz` zählt Tage
  /// rückwärts: `tag(0)` ist heute, `tag(-1)` gestern.
  DateTime tag(int versatz) =>
      BerlinCalendar.startOfDay(DateTime.utc(2026, 6, 17 + versatz));

  DateTime datum(int monat, int tagImMonat) =>
      BerlinCalendar.startOfDay(DateTime.utc(2026, monat, tagImMonat));

  final heute = tag(0);

  // 22:30 als Schlafenszeitziel, wie in `recovery_snapshot_test.dart`.
  final zielBett = EveningClock.minutesSinceEveningOfClock(
    hour: 22,
    minute: 30,
  );

  RecoverySnapshot bauen({
    List<RecoveryDay> days = const [],
    List<RecoveryNight> nights = const [],
    DateTime? today,
    DateTime? selectedDay,
    List<DateTime> alcoholDays = const [],
    bool isPostOperative = false,
    DataWindow? window,
    int windowDays = 30,
  }) => RecoverySnapshot.make(
    days: days,
    nights: nights,
    today: today ?? heute,
    selectedDay: selectedDay,
    sleepGoalHours: 8,
    bedtimeGoalMinutes: zielBett,
    alcoholDays: alcoholDays,
    isPostOperative: isPostOperative,
    window: window,
    windowDays: windowDays,
  );

  // ---------------------------------------------------------------------
  // Die große Fixture: sechsundzwanzig Tage, deren HRV zweimal springt.
  //
  //   Alter 25 .. 16 (zehn Tage)  HRV 100
  //   Alter 15      (ein Tag)     HRV  70   <- der interessante Tag
  //   Alter 14 ..  0 (15 Tage)    HRV  50
  //
  // Ruhepuls (52), Atemfrequenz (14) und Schlaf (450 min = 7,5 h) sind
  // überall gleich, damit genau ein Signal entstehen kann.
  //
  // Gerechnet von Hand:
  //   Median vor Alter 15  = Median von zehnmal 100            = 100
  //     -> Schwelle 100 * 0,8 = 80, Wert 70 <= 80  -> Signal HRV
  //   Median vor heute     = Median von 14x50, 1x70, 10x100    =  50
  //     -> Schwelle  50 * 0,8 = 40, Wert 50 >  40  -> kein Signal
  //
  // Das ist die gemischte Paarung in einer Zeile: Derselbe Wert 70 ist
  // gegen den Median von damals ein Warnsignal und gegen den von heute
  // keines.
  // ---------------------------------------------------------------------

  double hrvVon(int alter) {
    if (alter >= 16) return 100;
    if (alter == 15) return 70;
    return 50;
  }

  List<RecoveryDay> sechsundzwanzigTage() => [
    for (var alter = 25; alter >= 0; alter--)
      RecoveryDay(
        date: tag(-alter),
        restingHeartRate: 52,
        hrv: hrvVon(alter),
        respiratoryRate: 14,
        exerciseMinutes: 20,
      ),
  ];

  List<RecoveryNight> sechsundzwanzigNaechte() => [
    for (var alter = 25; alter >= 0; alter--)
      RecoveryNight(date: tag(-alter), asleepMinutes: 450),
  ];

  group('Der Rückfall auf heute ist wirklich ein Rückfall', () {
    test('ohne selectedDay rechnet alles wie mit dem heutigen Tag', () {
      final ohne = bauen(
        days: sechsundzwanzigTage(),
        nights: sechsundzwanzigNaechte(),
      );
      final mitHeute = bauen(
        days: sechsundzwanzigTage(),
        nights: sechsundzwanzigNaechte(),
        selectedDay: heute,
      );

      expect(ohne.selectedDay, heute);
      expect(mitHeute.selectedDay, heute);
      expect(ohne.today, heute);

      expect(ohne.reading, mitHeute.reading);
      expect(ohne.baseline, mitHeute.baseline);
      expect(ohne.night, mitHeute.night);
      expect(ohne.score, mitHeute.score);
      expect(ohne.days, mitHeute.days);
      expect(ohne.nights, mitHeute.nights);
      expect(ohne.trends, mitHeute.trends);
      expect(ohne.signalHistory, mitHeute.signalHistory);
      expect(ohne.weekMinutes, mitHeute.weekMinutes);
      expect(ohne.lastSeen, mitHeute.lastSeen);
      expect(ohne.alcoholEve, mitHeute.alcoholEve);
      expect(ohne.evaluation, mitHeute.evaluation);
    });

    test('und liefert dieselben Zahlen wie vor dieser Stufe', () {
      // Von Hand gerechnet, damit die Gleichheit oben nicht auch dann
      // erfüllt wäre, wenn beide Wege gemeinsam falsch rechnen.
      final schnappschuss = bauen(
        days: sechsundzwanzigTage(),
        nights: sechsundzwanzigNaechte(),
      );

      expect(schnappschuss.reading.hrv, 50.0);
      expect(schnappschuss.reading.restingHeartRate, 52.0);
      expect(schnappschuss.reading.respiratoryRate, 14.0);
      expect(schnappschuss.reading.sleepHours, 7.5);

      expect(schnappschuss.baseline.hrv, 50.0);
      expect(schnappschuss.baseline.restingHeartRate, 52.0);
      expect(schnappschuss.baseline.respiratoryRate, 14.0);
      expect(schnappschuss.baseline.sleepHours, 7.5);

      expect(schnappschuss.night?.date, heute);
      expect(schnappschuss.evaluation.signals, isEmpty);
      expect(schnappschuss.evaluation.verdict, RecoveryVerdict.calm);
      expect(schnappschuss.lastSeen, isNull);
    });
  });

  group('Invariante A: Ampel und Signalband sagen dasselbe', () {
    test('für jeden Tag des Fensters stimmt die Zahl der Signale überein', () {
      final tage = sechsundzwanzigTage();
      final naechte = sechsundzwanzigNaechte();
      final ganzes = bauen(days: tage, nights: naechte);

      expect(ganzes.signalHistory, hasLength(26));

      for (final eintrag in ganzes.signalHistory) {
        final fuerDiesenTag = bauen(
          days: tage,
          nights: naechte,
          selectedDay: eintrag.date,
        );

        expect(
          fuerDiesenTag.evaluation.signals.length,
          eintrag.count,
          reason:
              'Ampel und Band müssen für ${BerlinCalendar.dayKey(eintrag.date)} '
              'dieselbe Zahl nennen — das Band rechnet gegen den Median der '
              'Tage davor, die Ampel muss es auch tun.',
        );
        expect(
          fuerDiesenTag.evaluation.measuredCount > 0,
          eintrag.measured,
          reason:
              '„null Signale" und „nicht gemessen" dürfen nicht dasselbe '
              'heißen.',
        );
      }
    });

    test('die Fixture trägt wirklich verschiedene Verdikte', () {
      // Sonst bewiese die Gleichheit oben nichts: Wenn jeder Tag null
      // Signale hat, stimmen auch zwei falsche Rechnungen überein.
      final ganzes = bauen(
        days: sechsundzwanzigTage(),
        nights: sechsundzwanzigNaechte(),
      );

      final heutigerEintrag = ganzes.signalHistory.last;
      expect(heutigerEintrag.date, heute);
      expect(heutigerEintrag.count, 0);
      expect(ganzes.signalHistory.any((eintrag) => eintrag.count > 0), isTrue);
    });
  });

  group('Die gemischte Paarung', () {
    test('ein früherer Tag wird gegen den Median vor jenem Tag gemessen', () {
      final frueher = bauen(
        days: sechsundzwanzigTage(),
        nights: sechsundzwanzigNaechte(),
        selectedDay: tag(-15),
      );

      expect(frueher.selectedDay, tag(-15));
      expect(frueher.reading.hrv, 70.0);
      // Zehn Tage à 100 vor diesem Tag.
      expect(frueher.baseline.hrv, 100.0);
      // 70 <= 100 * 0,8 -> Warnsignal.
      expect(frueher.evaluation.signals, [RecoveryMetric.hrv]);
      expect(frueher.evaluation.verdict, RecoveryVerdict.watch);
    });

    test('der Median von heute würde hier das falsche Verdikt ergeben', () {
      // Die falsche Rechnung, benannt damit sie niemand versehentlich
      // einbaut: Wert 70 von tag(-15) gegen den **heutigen** Median 50
      // ergäbe die Schwelle 40, also kein Signal und `calm` — eine ruhige
      // Ampel über einem Tag, an dem die HRV um 30 % eingebrochen war.
      final heutiges = bauen(
        days: sechsundzwanzigTage(),
        nights: sechsundzwanzigNaechte(),
      );

      expect(heutiges.baseline.hrv, 50.0);
      expect(heutiges.evaluation.verdict, RecoveryVerdict.calm);

      final frueher = bauen(
        days: sechsundzwanzigTage(),
        nights: sechsundzwanzigNaechte(),
        selectedDay: tag(-15),
      );

      expect(frueher.evaluation.verdict, isNot(heutiges.evaluation.verdict));
    });
  });

  group('Invariante B: nichts aus der Zukunft des gewählten Tages', () {
    test(
      'Tage und Nächte nach dem gewählten Tag zu entfernen ändert nichts',
      () {
        final gewaehlt = tag(-15);
        final alkohol = [tag(-20), tag(-16), tag(-3)];

        final voll = bauen(
          days: sechsundzwanzigTage(),
          nights: sechsundzwanzigNaechte(),
          alcoholDays: alkohol,
          selectedDay: gewaehlt,
        );
        final beschnitten = bauen(
          days: [
            for (final day in sechsundzwanzigTage())
              if (!day.date.isAfter(gewaehlt)) day,
          ],
          nights: [
            for (final night in sechsundzwanzigNaechte())
              if (!night.date.isAfter(gewaehlt)) night,
          ],
          alcoholDays: alkohol,
          selectedDay: gewaehlt,
        );

        expect(beschnitten.selectedDay, voll.selectedDay);
        expect(beschnitten.reading, voll.reading);
        expect(beschnitten.baseline, voll.baseline);
        expect(beschnitten.night, voll.night);
        expect(beschnitten.score, voll.score);
        expect(beschnitten.trends, voll.trends);
        expect(beschnitten.weekMinutes, voll.weekMinutes);
        expect(beschnitten.evaluation, voll.evaluation);
      },
    );

    test(
      'days, nights und signalHistory bleiben trotzdem das ganze Fenster',
      () {
        // Sie beschreiben das Fenster, nicht den Tag — der Werte-Schirm
        // zeichnet daraus seine Diagramme, und das Band ist der Gegenbeweis
        // für Invariante A. Beides muss unabhängig bleiben.
        final heutiges = bauen(
          days: sechsundzwanzigTage(),
          nights: sechsundzwanzigNaechte(),
        );
        final frueher = bauen(
          days: sechsundzwanzigTage(),
          nights: sechsundzwanzigNaechte(),
          selectedDay: tag(-15),
        );

        expect(frueher.today, heute);
        expect(frueher.days, heutiges.days);
        expect(frueher.nights, heutiges.nights);
        expect(frueher.signalHistory, heutiges.signalHistory);
        expect(frueher.days, hasLength(26));
      },
    );
  });

  group('Der gewählte Tag wird geklemmt, nicht geworfen', () {
    test('ein Tag vor dem Fensterbeginn landet auf dem Fensterbeginn', () {
      // Zehn Tage Fenster ab heute (17.06.) -> Beginn 08.06.
      final schnappschuss = bauen(
        days: sechsundzwanzigTage(),
        selectedDay: datum(6, 1),
        windowDays: 10,
      );

      expect(BerlinCalendar.dayKey(schnappschuss.selectedDay), '2026-06-08');
    });

    test('ein Tag nach heute landet auf heute', () {
      final schnappschuss = bauen(
        days: sechsundzwanzigTage(),
        selectedDay: tag(5),
      );

      expect(schnappschuss.selectedDay, heute);
      expect(schnappschuss.today, heute);
    });

    test('der eingestellte Betrachtungszeitraum verschiebt die untere '
        'Grenze mit', () {
      final schnappschuss = bauen(
        days: sechsundzwanzigTage(),
        selectedDay: datum(6, 9),
        window: DataWindow(start: datum(6, 12)),
      );

      expect(BerlinCalendar.dayKey(schnappschuss.selectedDay), '2026-06-12');
    });

    test('ein Zeitpunkt mitten am Tag ist derselbe Tag', () {
      // Beliebiger Zeitpunkt desselben Berliner Kalendertags — normalisiert
      // wird über `BerlinCalendar`, nicht über die Uhrzeit.
      final mittags = tag(-2).add(const Duration(hours: 13));
      final schnappschuss = bauen(
        days: sechsundzwanzigTage(),
        selectedDay: mittags,
      );

      expect(schnappschuss.selectedDay, tag(-2));
    });
  });

  group('Nacht und Score gehören dem gewählten Tag', () {
    final naechte = [
      RecoveryNight(
        date: tag(-3),
        asleepMinutes: 480,
        // 13.06. 20:30 UTC = 22:30 Berlin, genau das Ziel.
        bedtime: DateTime.utc(2026, 6, 13, 20, 30),
      ),
      RecoveryNight(date: tag(0), asleepMinutes: 240),
    ];

    test('die Nacht des gewählten Tages, nicht die von heute', () {
      final schnappschuss = bauen(nights: naechte, selectedDay: tag(-3));

      expect(schnappschuss.night?.date, tag(-3));
      expect(schnappschuss.reading.sleepHours, 8.0);
      expect(schnappschuss.score?.duration, 50);
      expect(schnappschuss.score?.bedtime, 30);
    });

    test('ein Tag ohne Nacht hat keine Nacht und keinen Score', () {
      final schnappschuss = bauen(nights: naechte, selectedDay: tag(-2));

      expect(schnappschuss.night, isNull);
      expect(schnappschuss.score, isNull);
      // `null`, nicht `0`: Ein Ring auf 0 behauptet „nicht geschlafen".
      expect(schnappschuss.reading.sleepHours, isNull);
      expect(schnappschuss.reading.sleepHours, isNot(0));
    });

    test('eine Nacht ohne Schlafminuten zählt auch rückwärts nicht', () {
      final schnappschuss = bauen(
        nights: [
          RecoveryNight(date: tag(-4), asleepMinutes: 0, awakeMinutes: 150),
        ],
        selectedDay: tag(-4),
      );

      expect(schnappschuss.night, isNull);
      expect(schnappschuss.reading.sleepHours, isNull);
    });
  });

  group('Die Verläufe enden am gewählten Tag', () {
    List<RecoveryDay> vierTage() => [
      RecoveryDay(date: tag(-3), hrv: 50),
      RecoveryDay(date: tag(-2), hrv: 60),
      RecoveryDay(date: tag(-1), hrv: 70),
      RecoveryDay(date: tag(0), hrv: 500),
    ];

    List<RecoveryNight> vierNaechte() => [
      RecoveryNight(date: tag(-3), asleepMinutes: 360),
      RecoveryNight(date: tag(-2), asleepMinutes: 420),
      RecoveryNight(date: tag(-1), asleepMinutes: 480),
      RecoveryNight(date: tag(0), asleepMinutes: 600),
    ];

    RecoveryTrend zeile(RecoverySnapshot s, RecoveryTrendKind kind) =>
        s.trends.firstWhere((trend) => trend.kind == kind);

    test('ein Tag nach dem gewählten zählt weder in count noch in average', () {
      final frueher = bauen(
        days: vierTage(),
        nights: vierNaechte(),
        selectedDay: tag(-1),
      );

      // Der gewählte Tag selbst zählt seit #266 ebenfalls nicht mit: Die
      // Zahl der Zeile meint dieselben Tage wie der Median daneben.
      final hrv = zeile(frueher, RecoveryTrendKind.hrv);
      expect(hrv.count, 2);
      expect(hrv.average, 55.0); // (50 + 60) / 2

      final schlaf = zeile(frueher, RecoveryTrendKind.sleep);
      expect(schlaf.count, 2);
      expect(schlaf.average, 6.5); // (6 + 7) / 2
    });

    test('auf heute zählen die drei Tage davor', () {
      final heutiges = bauen(days: vierTage(), nights: vierNaechte());

      expect(zeile(heutiges, RecoveryTrendKind.hrv).count, 3);
      expect(zeile(heutiges, RecoveryTrendKind.hrv).average, 60.0);
      expect(zeile(heutiges, RecoveryTrendKind.sleep).count, 3);
      expect(zeile(heutiges, RecoveryTrendKind.sleep).average, 7.0);
    });

    test('eine Zeile ohne Werte trägt null, nicht 0', () {
      final frueher = bauen(
        days: vierTage(),
        nights: vierNaechte(),
        selectedDay: tag(-1),
      );

      final puls = zeile(frueher, RecoveryTrendKind.restingHeartRate);
      expect(puls.count, 0);
      expect(puls.average, isNull);
    });

    test('die Alkohol-Zeile zählt nur bis zum gewählten Tag', () {
      final alkohol = [tag(-2), tag(0)];

      final frueher = bauen(
        days: vierTage(),
        nights: vierNaechte(),
        alcoholDays: alkohol,
        selectedDay: tag(-1),
      );
      final heutiges = bauen(
        days: vierTage(),
        nights: vierNaechte(),
        alcoholDays: alkohol,
      );

      expect(zeile(frueher, RecoveryTrendKind.alcoholDays).count, 1);
      expect(zeile(heutiges, RecoveryTrendKind.alcoholDays).count, 2);
      expect(zeile(frueher, RecoveryTrendKind.alcoholDays).average, isNull);
    });

    test('der Vortag wandert mit dem gewählten Tag', () {
      // Was „zuletzt am …" nicht konnte: Auf einem früheren Tag stand dort
      // der jüngste Alkohol-Tag des Fensters — ein Datum, das nach dem
      // gewählten liegen konnte. Der Vortag kann das nicht (#268).
      final frueher = bauen(
        days: vierTage(),
        alcoholDays: [tag(-2), tag(0)],
        selectedDay: tag(-1),
      );
      final heutiges = bauen(
        days: vierTage(),
        alcoholDays: [tag(-2), tag(0)],
      );

      expect(frueher.alcoholEve, AlcoholEve.drinks);
      expect(heutiges.alcoholEve, AlcoholEve.unknown);
    });
  });

  group('Die Wochenlast endet am gewählten Tag', () {
    // Montag 15.06. bis Sonntag 21.06.2026, davor eine volle Vorwoche.
    final sonntag = datum(6, 21);

    List<RecoveryDay> zweiWochen({double? dienstag}) => [
      for (var t = 8; t <= 14; t++)
        RecoveryDay(date: datum(6, t), exerciseMinutes: 100),
      RecoveryDay(date: datum(6, 15), exerciseMinutes: 10),
      RecoveryDay(date: datum(6, 16), exerciseMinutes: dienstag),
      RecoveryDay(date: datum(6, 17), exerciseMinutes: 30),
      RecoveryDay(date: datum(6, 18), exerciseMinutes: 40),
      RecoveryDay(date: datum(6, 19), exerciseMinutes: 50),
      RecoveryDay(date: datum(6, 20), exerciseMinutes: 60),
      RecoveryDay(date: datum(6, 21), exerciseMinutes: 70),
    ];

    test('ein gewählter Mittwoch zählt Montag bis Mittwoch', () {
      final schnappschuss = bauen(
        days: zweiWochen(dienstag: 20),
        today: sonntag,
        selectedDay: datum(6, 17),
      );

      expect(schnappschuss.weekMinutes, 60.0); // 10 + 20 + 30
    });

    test('die Vorwoche zählt nicht mit', () {
      // Sieben Tage à 100 Minuten liegen davor; käme auch nur einer davon
      // mit, stünde hier eine dreistellige Zahl.
      final schnappschuss = bauen(
        days: zweiWochen(dienstag: 20),
        today: sonntag,
        selectedDay: datum(6, 15),
      );

      expect(schnappschuss.weekMinutes, 10.0);
    });

    test('ein Tag ohne exerciseMinutes trägt nichts bei', () {
      final ohneWert = bauen(
        days: zweiWochen(),
        today: sonntag,
        selectedDay: datum(6, 17),
      );
      final ganzOhneTag = bauen(
        days: [
          for (final day in zweiWochen())
            if (day.date != datum(6, 16)) day,
        ],
        today: sonntag,
        selectedDay: datum(6, 17),
      );

      expect(ohneWert.weekMinutes, 40.0); // 10 + 30
      expect(ohneWert.weekMinutes, ganzOhneTag.weekMinutes);
    });

    test('auf heute bleibt die Wochenlast die ganze Woche bis heute', () {
      final schnappschuss = bauen(
        days: zweiWochen(dienstag: 20),
        today: sonntag,
      );

      expect(schnappschuss.weekMinutes, 280.0);
    });
  });

  group('„Zuletzt gesehen" sucht vor dem gewählten Tag', () {
    test('ein Wert nach dem gewählten Tag zählt nicht als der letzte', () {
      final schnappschuss = bauen(
        days: [
          RecoveryDay(date: tag(-5), hrv: 60),
          RecoveryDay(date: tag(-2)), // alles leer
          RecoveryDay(date: tag(-1), hrv: 70),
          RecoveryDay(date: tag(0), hrv: 80),
        ],
        nights: [RecoveryNight(date: tag(-1), asleepMinutes: 420)],
        selectedDay: tag(-2),
      );

      expect(schnappschuss.reading, const RecoveryReading());
      expect(schnappschuss.lastSeen, tag(-5));
    });

    test('liegt am gewählten Tag ein Wert, bleibt lastSeen leer', () {
      final schnappschuss = bauen(
        days: [
          RecoveryDay(date: tag(-5), hrv: 60),
          RecoveryDay(date: tag(-2), hrv: 65),
        ],
        selectedDay: tag(-2),
      );

      expect(schnappschuss.lastSeen, isNull);
    });
  });

  group('Vier grüne Viertel ohne Grundlage', () {
    // Der wichtigste Fund der Spec: `HealthMedian` bildet unter fünf Werten
    // keinen Median. Für die fünf ältesten Tage des Fensters gibt es deshalb
    // gar keinen — kein Median, kein Vergleich, kein Signal, Verdikt `calm`.
    // Ohne `rated` malte der Ring dort vier grüne Viertel: „alles im
    // Normalbereich", eine Aussage, die niemand gemacht hat.

    test('der fünftälteste Tag hat keine Mediane und darum nur den Schlaf '
        'in rated', () {
      // Vor tag(-21) liegen vier Tage — einer zu wenig.
      final schnappschuss = bauen(
        days: sechsundzwanzigTage(),
        nights: sechsundzwanzigNaechte(),
        selectedDay: tag(-21),
      );

      expect(schnappschuss.baseline.restingHeartRate, isNull);
      expect(schnappschuss.baseline.hrv, isNull);
      expect(schnappschuss.baseline.respiratoryRate, isNull);

      // Werte liegen alle vier vor.
      expect(schnappschuss.evaluation.measuredCount, 4);
      // Beurteilt wurde trotzdem nur der Schlaf.
      expect(schnappschuss.evaluation.rated, [RecoveryMetric.sleep]);
      expect(schnappschuss.evaluation.signals, isEmpty);
      // Der Punkt der ganzen Stufe: null Signale heißt hier **nicht**
      // „alles im Normalbereich". Drei der vier Viertel haben keine
      // Grundlage.
      expect(schnappschuss.evaluation.rated, isNot(hasLength(4)));
    });

    test('ein Tag mit genug Vortagen trägt alle vier in rated', () {
      // Vor tag(-20) liegen fünf Tage — genau genug.
      final schnappschuss = bauen(
        days: sechsundzwanzigTage(),
        nights: sechsundzwanzigNaechte(),
        selectedDay: tag(-20),
      );

      expect(schnappschuss.evaluation.rated, [
        RecoveryMetric.sleep,
        RecoveryMetric.restingHeartRate,
        RecoveryMetric.hrv,
        RecoveryMetric.respiratoryRate,
      ]);
    });

    test('ohne Nacht ist auch der Schlaf nicht beurteilt', () {
      final schnappschuss = bauen(
        days: sechsundzwanzigTage(),
        selectedDay: tag(-21),
      );

      expect(schnappschuss.reading.sleepHours, isNull);
      expect(schnappschuss.evaluation.rated, isEmpty);
    });

    test('signals ist über das ganze Fenster eine Teilmenge von rated', () {
      final tage = sechsundzwanzigTage();
      final naechte = sechsundzwanzigNaechte();

      for (final eintrag in bauen(days: tage, nights: naechte).signalHistory) {
        final auswertung = bauen(
          days: tage,
          nights: naechte,
          selectedDay: eintrag.date,
        ).evaluation;

        for (final signal in auswertung.signals) {
          expect(
            auswertung.rated,
            contains(signal),
            reason:
                'Ein Warnsignal ohne Grundlage gibt es nicht — '
                '${BerlinCalendar.dayKey(eintrag.date)}.',
          );
        }
      }
    });
  });

  group('Eine Zeitumstellung im Fenster', () {
    // Die Sommerzeit endet am letzten Sonntag im Oktober, 01:00 UTC — 2026
    // also am 25.10. Davor ist Berlin UTC+2, danach UTC+1.
    final novemberHeute = datum(11, 5);

    List<RecoveryDay> umstellungsTage() => [
      RecoveryDay(date: datum(10, 24), hrv: 61),
      RecoveryDay(date: datum(10, 25), hrv: 62),
      RecoveryDay(date: datum(10, 26), hrv: 63),
    ];

    test('ein Zeitpunkt vor der Umstellung trifft seinen Berliner Tag', () {
      final schnappschuss = bauen(
        days: umstellungsTage(),
        today: novemberHeute,
        // 14:00 Berliner Sommerzeit am 24.10.
        selectedDay: DateTime.utc(2026, 10, 24, 12),
      );

      expect(BerlinCalendar.dayKey(schnappschuss.selectedDay), '2026-10-24');
      expect(schnappschuss.reading.hrv, 61.0);
    });

    test('22:30 UTC ist im Oktober in Berlin schon der Folgetag', () {
      // Genau der Zahlendreher aus den `DataWindow`-Tests: Wer von Hand
      // paart statt über `BerlinCalendar` zu gehen, landet einen Tag daneben.
      final schnappschuss = bauen(
        days: umstellungsTage(),
        today: novemberHeute,
        selectedDay: DateTime.utc(2026, 10, 24, 22, 30),
      );

      expect(BerlinCalendar.dayKey(schnappschuss.selectedDay), '2026-10-25');
      expect(schnappschuss.reading.hrv, 62.0);
    });

    test('nach der Umstellung verschiebt sich die Grenze um eine Stunde', () {
      // 23:30 UTC ist am 25.10. bereits Winterzeit -> 00:30 Berlin am 26.10.
      final schnappschuss = bauen(
        days: umstellungsTage(),
        today: novemberHeute,
        selectedDay: DateTime.utc(2026, 10, 25, 23, 30),
      );

      expect(BerlinCalendar.dayKey(schnappschuss.selectedDay), '2026-10-26');
      expect(schnappschuss.reading.hrv, 63.0);
    });

    test('der Tagesschlüssel bleibt der ISO-Tagesstring', () {
      final schnappschuss = bauen(
        days: umstellungsTage(),
        today: novemberHeute,
        selectedDay: datum(10, 25),
      );

      expect(
        schnappschuss.days
            .map((day) => BerlinCalendar.dayKey(day.date))
            .toList(),
        ['2026-10-24', '2026-10-25', '2026-10-26'],
      );
      expect(schnappschuss.selectedDay, datum(10, 25));
    });
  });

  group('today wird nicht umgedeutet', () {
    test('ein früherer gewählter Tag lässt Fenster und heute, wo sie sind', () {
      final schnappschuss = bauen(
        days: sechsundzwanzigTage(),
        nights: sechsundzwanzigNaechte(),
        selectedDay: tag(-20),
      );

      expect(schnappschuss.today, heute);
      // Das Fenster reicht weiter als der gewählte Tag — es hängt an heute.
      expect(schnappschuss.days.first.date, tag(-25));
      expect(schnappschuss.days.last.date, heute);
      expect(schnappschuss.isPostOperative, isFalse);
    });

    test('nach der OP ruht die Ampel auch auf einem früheren Tag', () {
      final schnappschuss = bauen(
        days: sechsundzwanzigTage(),
        nights: sechsundzwanzigNaechte(),
        isPostOperative: true,
        selectedDay: tag(-15),
      );

      expect(schnappschuss.evaluation.verdict, RecoveryVerdict.postOperative);
      expect(schnappschuss.evaluation.signals, isEmpty);
      // Das Band bleibt davon unberührt — es zeigt, was gemessen wurde.
      final eintrag = schnappschuss.signalHistory.firstWhere(
        (e) => e.date == tag(-15),
      );
      expect(eintrag.count, 1);
    });
  });
}
