import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// **Eine Zeile, eine Menge Tage** (#266).
///
/// Die Verlaufszeile stellt zwei Zahlen nebeneinander: „9 Tage · Median
/// 60 ms". Bis heute zählte `trend.count` den gewählten Tag **mit**, der
/// Median schloss ihn **aus** — zwei verschieden große Mengen in derselben
/// Zeile, und niemand sah es der Zeile an.
///
/// ## Warum der Trend nachgibt und nicht der Median
///
/// Der Median lässt den Tag aus gutem Grund heraus: Ein Wert, der mit einem
/// Median verglichen wird, der ihn enthält, zieht seinen eigenen
/// Vergleichswert zu sich. Bei dreißig Tagen ist das fast egal, bei fünf
/// nicht. Also zählt die Zahl daneben künftig dieselben Tage wie er — die
/// **vor** dem gewählten.
///
/// Die Zeile liest sich damit als eine Auskunft: *So viele Tage tragen den
/// Vergleichswert, und so steht dein Tag dazu.* Der Wert des gewählten
/// Tages steht weiterhin rechts, und er ist nicht Teil seiner eigenen
/// Grundlage.
///
/// ## Was nicht mitwandert
///
/// - **Die Wochenlast** endet weiter **einschließlich** des gewählten Tages.
///   Sie ist eine Summe über die Woche, kein Vergleichswert.
/// - **Die Alkohol-Zeile** zählt weiter bis **einschließlich** des gewählten
///   Tages. Neben ihr steht kein Median, mit dem sie sich widersprechen
///   könnte; sie beantwortet „wie oft im Zeitraum", und ein Tag, an dem
///   gerade etwas erfasst wurde, gehört in diese Antwort.
/// - **Die Ampelschwellen** (SPEC 176) bleiben unberührt. Diese Datei
///   ändert, was gezählt wird, nicht wie bewertet wird.
///
/// Alle Zahlen sind erfunden und bewusst rund.
void main() {
  /// Mittwoch, 17.06.2026. `versatz` zählt Tage rückwärts.
  DateTime tag(int versatz) =>
      BerlinCalendar.startOfDay(DateTime.utc(2026, 6, 17 + versatz));

  final heute = tag(0);

  final zielBett = EveningClock.minutesSinceEveningOfClock(
    hour: 22,
    minute: 30,
  );

  RecoverySnapshot bauen({
    List<RecoveryDay> days = const [],
    List<RecoveryNight> nights = const [],
    DateTime? selectedDay,
    List<DateTime> alcoholDays = const [],
    DataWindow? window,
  }) => RecoverySnapshot.make(
    days: days,
    nights: nights,
    today: heute,
    selectedDay: selectedDay,
    sleepGoalHours: 8,
    bedtimeGoalMinutes: zielBett,
    alcoholDays: alcoholDays,
    window: window,
  );

  RecoveryTrend zeile(RecoverySnapshot s, RecoveryTrendKind art) =>
      s.trends.firstWhere((t) => t.kind == art);

  group('Der gewählte Tag zählt in seiner eigenen Zeile nicht mit', () {
    List<RecoveryDay> fuenfTage() => [
      for (var i = 4; i >= 1; i--)
        RecoveryDay(
          date: tag(-i),
          hrv: 60,
          restingHeartRate: 50,
          respiratoryRate: 14,
        ),
      RecoveryDay(
        date: heute,
        hrv: 100,
        restingHeartRate: 90,
        respiratoryRate: 20,
      ),
    ];

    test('die HRV-Zeile zählt vier Tage, nicht fünf', () {
      final s = bauen(days: fuenfTage());

      expect(zeile(s, RecoveryTrendKind.hrv).count, 4);
      expect(
        zeile(s, RecoveryTrendKind.hrv).average,
        60.0,
        reason: 'die 100 von heute gehört nicht in ihren eigenen Vergleich',
      );
    });

    test('Ruhepuls und Atemfrequenz genauso', () {
      final s = bauen(days: fuenfTage());

      expect(zeile(s, RecoveryTrendKind.restingHeartRate).count, 4);
      expect(zeile(s, RecoveryTrendKind.restingHeartRate).average, 50.0);
      expect(zeile(s, RecoveryTrendKind.respiratoryRate).count, 4);
      expect(zeile(s, RecoveryTrendKind.respiratoryRate).average, 14.0);
    });

    test('die Schlaf-Zeile zählt die Nächte davor, nicht die eigene', () {
      final s = bauen(
        nights: [
          for (var i = 3; i >= 1; i--)
            RecoveryNight(date: tag(-i), asleepMinutes: 360),
          RecoveryNight(date: heute, asleepMinutes: 600),
        ],
      );

      expect(zeile(s, RecoveryTrendKind.sleep).count, 3);
      expect(zeile(s, RecoveryTrendKind.sleep).average, 6.0);
    });

    test('auf einem früheren Tag gilt dasselbe, einen Tag weiter hinten', () {
      final s = bauen(days: fuenfTage(), selectedDay: tag(-1));

      expect(
        zeile(s, RecoveryTrendKind.hrv).count,
        3,
        reason: 'tag(-4) bis tag(-2) — tag(-1) ist der gewählte',
      );
    });
  });

  group('Beide Zahlen der Zeile meinen dieselben Tage', () {
    test('die Zahl ist die Zahl der Werte, aus denen der Median entsteht', () {
      // Sechs Tage davor, einer davon ohne HRV: fünf Werte tragen den
      // Median, und fünf muss die Zeile nennen.
      final s = bauen(
        days: [
          for (var i = 6; i >= 1; i--)
            RecoveryDay(date: tag(-i), hrv: i == 3 ? null : 60),
          RecoveryDay(date: heute, hrv: 100),
        ],
      );

      expect(zeile(s, RecoveryTrendKind.hrv).count, 5);
      expect(
        s.baseline.hrv,
        60.0,
        reason: 'fünf Werte sind genug für einen Median',
      );
    });

    test('ohne Tag davor steht keine Zahl und kein Median', () {
      final s = bauen(days: [RecoveryDay(date: heute, hrv: 60)]);

      expect(zeile(s, RecoveryTrendKind.hrv).count, 0);
      expect(zeile(s, RecoveryTrendKind.hrv).average, isNull);
      expect(
        s.baseline.hrv,
        isNull,
        reason: 'beide Hälften der Zeile sagen dasselbe: es gibt nichts',
      );
      expect(
        s.reading.hrv,
        60.0,
        reason: 'der Wert des Tages steht trotzdem da — er fehlt nicht',
      );
    });

    test('der Betrachtungszeitraum kürzt beide gleich', () {
      final s = bauen(
        days: [
          for (var i = 10; i >= 1; i--) RecoveryDay(date: tag(-i), hrv: 60),
          RecoveryDay(date: heute, hrv: 100),
        ],
        window: DataWindow(start: tag(-5)),
      );

      expect(zeile(s, RecoveryTrendKind.hrv).count, 5);
      expect(s.baseline.hrv, 60.0);
    });
  });

  group('Was nicht mitwandert', () {
    test('die Wochenlast endet einschließlich des gewählten Tages', () {
      // Montag 15.06. bis Mittwoch 17.06., je 30 Minuten.
      final s = bauen(
        days: [
          for (var i = 2; i >= 0; i--)
            RecoveryDay(date: tag(-i), exerciseMinutes: 30),
        ],
      );

      expect(
        s.weekMinutes,
        90.0,
        reason:
            'eine Summe über die Woche, kein Vergleichswert — der heutige '
            'Lauf zählt mit',
      );
    });

    test('die Alkohol-Zeile zählt den gewählten Tag weiter mit', () {
      final s = bauen(alcoholDays: [tag(-2), heute]);

      expect(
        zeile(s, RecoveryTrendKind.alcoholDays).count,
        2,
        reason:
            'neben ihr steht kein Median, mit dem sie sich widersprechen '
            'könnte',
      );
    });

    test('ein Tag nach dem gewählten zählt weiterhin nirgends', () {
      final s = bauen(
        days: [
          RecoveryDay(date: tag(-2), hrv: 60),
          RecoveryDay(date: tag(-1), hrv: 70),
          RecoveryDay(date: heute, hrv: 80),
        ],
        selectedDay: tag(-1),
      );

      expect(zeile(s, RecoveryTrendKind.hrv).count, 1);
      expect(zeile(s, RecoveryTrendKind.hrv).average, 60.0);
    });
  });
}
