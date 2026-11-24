import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für den **Median** aus Ticket #109 — Spec
/// `2026-10-26-erholung-flutter-design.md` Abschnitt 6, Vorlage
/// `Packages/TrainingsCore/Sources/TrainingsCore/Body/RecoveryBaseline+Median.swift`.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, nie verändert werden.
///
/// ## API, die diese Tests verbindlich vorgeben
///
/// ```dart
/// abstract final class HealthMedian {
///   static const int defaultWindow = 30;
///   static const int defaultMinimumSamples = 5;
///   static double? value(
///     List<double> samples, {
///     int window = defaultWindow,
///     int minimumSamples = defaultMinimumSamples,
///   });
/// }
/// ```
///
/// Dazu der **Eingabetyp des ganzen Erholungs-Pakets**, der hier zum ersten
/// Mal gebraucht wird und auch #109 (`TrainingLoad`) und #112
/// (`RecoverySnapshot`) trägt:
///
/// ```dart
/// /// Ein Kalendertag mit genau den Werten, die die Erholung rechnet.
/// class RecoveryDay {
///   const RecoveryDay({
///     required DateTime date,        // Berliner Tagesbeginn, als UTC-Instant
///     double? restingHeartRate,
///     double? hrv,
///     double? respiratoryRate,
///     double? exerciseMinutes,
///   });
///   final DateTime date;
///   final double? restingHeartRate, hrv, respiratoryRate, exerciseMinutes;
///   // Wertgleichheit.
/// }
/// ```
///
/// ### Warum ein eigener, schlanker Typ und nicht `DailyMetrics`
///
/// Die App hat bereits ein `DailyMetrics` in
/// `app/lib/health/health_types.dart` — mit dreizehn Feldern aus HealthKit,
/// `tag` als ISO-Zeichenkette statt als Datum und `restingHR` als `int?`.
/// Diese Datei **darf nicht** in `trainings_core` wandern und auch nicht
/// dort nachgebaut werden: `health_types.dart` importiert
/// `package:trainings_core/trainings_core.dart`, ein gleichnamiger Export
/// aus dem Barrel wäre ein Namenskonflikt und bräche die App-Datei beim
/// Übersetzen. `RecoveryDay` trägt deshalb vier Werte plus Datum, und die
/// App bildet ihr `DailyMetrics` darauf ab. Der Kern rechnet mit `double`,
/// weil jede Schwelle ein `double` ist.
///
/// **Alle Zahlen hier sind erfunden.** Ganzzahlige Folgen wie 1..30 tragen
/// keine Gesundheitsbedeutung und sind genau deshalb gewählt: Ein Median
/// über 1..30 lässt sich im Kopf nachrechnen.
void main() {
  /// Erfundene Tageswerte, um `RecoveryBaseline.from` zu füttern. Der Tag
  /// selbst spielt für den Median keine Rolle — gezählt wird die Reihenfolge
  /// der Liste, nicht der Abstand der Tage.
  List<RecoveryDay> tage(List<double?> hrvWerte) => [
    for (var i = 0; i < hrvWerte.length; i++)
      RecoveryDay(
        date: BerlinCalendar.startOfDay(DateTime.utc(2026, 6, 1 + i)),
        hrv: hrvWerte[i],
      ),
  ];

  group('Mindestzahl der Werte', () {
    test('vier Werte ergeben null', () {
      expect(HealthMedian.value(const [1, 2, 3, 4]), isNull);
    });

    test('fünf Werte ergeben einen Median', () {
      expect(HealthMedian.value(const [1, 2, 3, 4, 5]), 3.0);
    });

    test('eine leere Liste ergibt null', () {
      expect(HealthMedian.value(const []), isNull);
    });

    test('die Mindestzahl ist überschreibbar', () {
      expect(HealthMedian.value(const [7], minimumSamples: 1), 7.0);
    });

    test('die Vorgaben stehen als Konstanten bereit', () {
      expect(HealthMedian.defaultWindow, 30);
      expect(HealthMedian.defaultMinimumSamples, 5);
    });
  });

  group('Bei gerader Anzahl gewinnt der obere der beiden mittleren', () {
    test('sechs Werte', () {
      // Sortiert 1,2,3,4,5,6 — die beiden mittleren sind 3 und 4, genommen
      // wird 4. Dieselbe Regel wie in `RestingHeartRate`, damit zwei Stellen
      // der App nicht verschieden runden.
      expect(HealthMedian.value(const [1, 2, 3, 4, 5, 6]), 4.0);
    });

    test('acht Werte, unsortiert eingegeben', () {
      // Sortiert 1,2,3,4,5,6,7,8 — die beiden mittleren sind 4 und 5.
      expect(HealthMedian.value(const [8, 3, 1, 6, 2, 7, 4, 5]), 5.0);
    });

    test('fünf Werte, unsortiert eingegeben', () {
      expect(HealthMedian.value(const [5, 1, 3, 2, 4]), 3.0);
    });
  });

  group('Das Fenster schneidet die ältesten Werte ab', () {
    test('über 30 Werte zählen nur die letzten 30', () {
      // Fünf absurd hohe Werte am Anfang, danach 1..30. Mit Fenster bleiben
      // 1..30 übrig: sortiert ist der 16. Wert (obere Mitte von 30) die 16.
      // Ohne Fenster wären es 35 Werte, und der Median läge bei 18.
      final werte = <double>[
        ...List<double>.filled(5, 999),
        ...List<double>.generate(30, (i) => (i + 1).toDouble()),
      ];
      expect(HealthMedian.value(werte), 16.0);
    });

    test('das Fenster ist überschreibbar', () {
      // Nur die letzten vier Werte: 7,8,9,10 — obere Mitte ist 9.
      final werte = List<double>.generate(10, (i) => (i + 1).toDouble());
      expect(
        HealthMedian.value(werte, window: 4, minimumSamples: 4),
        9.0,
      );
    });

    test('das Fenster schneidet hinten, nicht vorne', () {
      // Die jüngsten Werte stehen am Ende der Liste. Wer vorne schneidet,
      // bekommt hier 2 statt 9.
      final werte = <double>[
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        9,
        9,
        9,
        9,
        9,
      ];
      expect(HealthMedian.value(werte, window: 5), 9.0);
    });
  });

  group('RecoveryBaseline.from: erst die Lücken heraus, dann das Fenster', () {
    test('eine lange Lücke am Ende räumt das Fenster nicht leer', () {
      // Zehn gemessene Tage, danach dreißig Tage ohne HRV. Wer zuerst das
      // Fenster über die letzten 30 **Tage** legt und erst danach die
      // Lücken herausnimmt, behält null Werte und liefert `null`. Richtig
      // ist: erst die zehn Werte einsammeln, dann das Fenster darauf legen.
      final basis = RecoveryBaseline.from(
        days: tage([
          ...List<double?>.generate(10, (i) => (i + 1).toDouble()),
          ...List<double?>.filled(30, null),
        ]),
        sleepHours: const [],
      );

      // Zehn Werte 1..10, obere Mitte ist 6.
      expect(basis.hrv, 6.0);
    });

    test('Lücken mitten im Fenster verschieben den Median nicht', () {
      // Fünf Werte, dazwischen Lücken. Die Lücken zählen nicht als Nullen —
      // sonst stürzte jeder Median ab, sobald die Uhr eine Nacht aussetzt.
      final basis = RecoveryBaseline.from(
        days: tage([10, null, 20, null, 30, null, 40, null, 50]),
        sleepHours: const [],
      );
      expect(basis.hrv, 30.0);
    });

    test('weniger als fünf gemessene Tage ergeben null', () {
      final basis = RecoveryBaseline.from(
        days: tage([10, null, 20, null, 30, null, 40]),
        sleepHours: const [],
      );
      expect(basis.hrv, isNull);
    });

    test('jede der vier Metriken bekommt ihren eigenen Median', () {
      // Ruhepuls und Atmung sind überall gemessen, die HRV nur dreimal.
      // Dann fehlt genau der HRV-Median und sonst keiner — das ist die
      // Regel „ein fehlender Median schaltet nur seine eigene Metrik ab".
      final tageMitLuecke = [
        for (var i = 0; i < 6; i++)
          RecoveryDay(
            date: BerlinCalendar.startOfDay(DateTime.utc(2026, 6, 1 + i)),
            restingHeartRate: (40 + i).toDouble(),
            hrv: i < 3 ? (100 + i).toDouble() : null,
            respiratoryRate: (10 + i).toDouble(),
          ),
      ];

      final basis = RecoveryBaseline.from(
        days: tageMitLuecke,
        sleepHours: const [6, 7, 8, 9, 10, 11],
      );

      // Ruhepuls 40..45, obere Mitte ist 43.
      expect(basis.restingHeartRate, 43.0);
      expect(basis.hrv, isNull);
      // Atmung 10..15, obere Mitte ist 13.
      expect(basis.respiratoryRate, 13.0);
      // Schlaf 6..11, obere Mitte ist 9.
      expect(basis.sleepHours, 9.0);
    });

    test('ohne jeden Wert bleibt jede Metrik null', () {
      final basis = RecoveryBaseline.from(
        days: const [],
        sleepHours: const [],
      );
      expect(basis, const RecoveryBaseline());
    });

    test('Fenster und Mindestzahl sind durchgereicht', () {
      final basis = RecoveryBaseline.from(
        days: tage([1, 2, 3]),
        sleepHours: const [],
        window: 2,
        minimumSamples: 2,
      );
      // Letzte zwei Werte 2 und 3, obere Mitte ist 3.
      expect(basis.hrv, 3.0);
    });
  });
}
