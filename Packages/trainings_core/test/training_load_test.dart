import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für die **Wochenlast** aus Ticket #109 — Spec
/// `2026-10-26-erholung-flutter-design.md` Abschnitt 6, Vorlage
/// `Packages/TrainingsCore/Sources/TrainingsCore/Body/TrainingLoad.swift`.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, nie verändert werden.
///
/// ## API, die diese Tests verbindlich vorgeben
///
/// ```dart
/// abstract final class TrainingLoad {
///   /// Montag 00:00 bis zum darauffolgenden Montag 00:00, beides Berliner
///   /// Zeit, zurückgegeben als UTC-Instants wie bei `BerlinCalendar`.
///   static (DateTime start, DateTime end) weekBounds({
///     required DateTime containing,
///   });
///
///   /// Summe der Trainingsminuten im halboffenen Fenster
///   /// `date >= start && date < end`. Tage ohne `exerciseMinutes` zählen
///   /// nicht mit — nicht als Null.
///   static double weekMinutes({
///     required List<RecoveryDay> days,
///     required DateTime containing,
///   });
/// }
/// ```
///
/// `RecoveryDay` ist in `health_median_test.dart` festgeschrieben.
///
/// ### Warum die Grenzen über `BerlinCalendar` laufen müssen
///
/// Die Spec sagt es in einem Halbsatz — „nie `+86400`" —, und die beiden
/// Umstellungswochen unten lösen ihn ein: Die Woche vom 23.03.2026 hat
/// **167** Stunden, die vom 19.10.2026 hat **169**. Wer sieben Mal 24
/// Stunden addiert, trifft in beiden Fällen die falsche Mitternacht, und in
/// der Oktoberwoche fällt der Montagvormittag in die Vorwoche.
///
/// Die Wochentage sind von Hand hergeleitet, mit derselben Kette wie in
/// `berlin_calendar_test.dart` (01.01.2026 = Donnerstag):
///
///   01.03.2026 = Sonntag  -> Montage 2., 9., 16., 23., 30. März
///                         -> letzter Sonntag im März = 29.03. (Umstellung)
///   01.06.2026 = Montag   -> Montage 1., 8., 15., 22., 29. Juni
///   01.10.2026 = Donnerstag -> Montage 5., 12., 19., 26. Oktober
///                         -> letzter Sonntag im Oktober = 25.10. (Umstellung)
///
/// **Alle Minutenzahlen sind erfunden.**
void main() {
  /// Berliner Tagesbeginn des genannten Datums — die Form, in der ein
  /// `RecoveryDay` sein Datum trägt.
  DateTime tag(int jahr, int monat, int tagImMonat) =>
      BerlinCalendar.startOfDay(DateTime.utc(jahr, monat, tagImMonat));

  RecoveryDay werte(DateTime datum, double? minuten) =>
      RecoveryDay(date: datum, exerciseMinutes: minuten);

  group('weekBounds: Montag 00:00 bis Montag 00:00', () {
    test('ein Mittwoch landet auf dem Montag davor', () {
      // 17.06.2026 ist ein Mittwoch (01.06. = Montag).
      final (start, end) = TrainingLoad.weekBounds(
        containing: tag(2026, 6, 17),
      );
      expect(start, tag(2026, 6, 15));
      expect(end, tag(2026, 6, 22));
    });

    test('ein Montag ist sein eigener Wochenanfang', () {
      final (start, end) = TrainingLoad.weekBounds(
        containing: tag(2026, 6, 15),
      );
      expect(start, tag(2026, 6, 15));
      expect(end, tag(2026, 6, 22));
    });

    test('ein Sonntag gehört zur Woche davor, nicht zur kommenden', () {
      // 21.06.2026 ist ein Sonntag. Die Woche läuft Montag bis Sonntag, der
      // Sonntag ist ihr letzter Tag — nicht der erste der nächsten.
      final (start, end) = TrainingLoad.weekBounds(
        containing: tag(2026, 6, 21),
      );
      expect(start, tag(2026, 6, 15));
      expect(end, tag(2026, 6, 22));
    });

    test('ein Zeitpunkt mitten am Tag ändert die Grenzen nicht', () {
      // Nicht nur Tagesbeginne kommen herein: `RecoverySnapshot` reicht
      // „heute" weiter, und das kann jeder Zeitpunkt sein.
      final (start, end) = TrainingLoad.weekBounds(
        containing: DateTime.utc(2026, 6, 17, 21, 45),
      );
      expect(start, tag(2026, 6, 15));
      expect(end, tag(2026, 6, 22));
    });

    test('die Woche über den Jahreswechsel bleibt zusammen', () {
      // 01.01.2027 ist ein Freitag (01.01.2026 = Donnerstag, 2026 kein
      // Schaltjahr). Die Woche beginnt also am Montag, 28.12.2026.
      final (start, end) = TrainingLoad.weekBounds(
        containing: tag(2027, 1, 1),
      );
      expect(start, tag(2026, 12, 28));
      expect(end, tag(2027, 1, 4));
    });
  });

  group('weekBounds über die Zeitumstellungen', () {
    test('die Woche mit dem Beginn der Sommerzeit hat 167 Stunden', () {
      // Umstellung am Sonntag, 29.03.2026: die Uhren springen von 02:00 auf
      // 03:00, der Tag hat 23 Stunden.
      final (start, end) = TrainingLoad.weekBounds(
        containing: tag(2026, 3, 25),
      );
      expect(start, tag(2026, 3, 23));
      expect(end, tag(2026, 3, 30));
      expect(end.difference(start), const Duration(hours: 167));
    });

    test('die Woche mit dem Ende der Sommerzeit hat 169 Stunden', () {
      // Umstellung am Sonntag, 25.10.2026: die Uhren springen von 03:00 auf
      // 02:00 zurück, der Tag hat 25 Stunden — und 02:30 gibt es zweimal.
      final (start, end) = TrainingLoad.weekBounds(
        containing: tag(2026, 10, 21),
      );
      expect(start, tag(2026, 10, 19));
      expect(end, tag(2026, 10, 26));
      expect(end.difference(start), const Duration(hours: 169));
    });

    test('der Umstellungssonntag selbst liegt in seiner Woche', () {
      final (start, end) = TrainingLoad.weekBounds(
        containing: tag(2026, 10, 25),
      );
      expect(start, tag(2026, 10, 19));
      expect(end, tag(2026, 10, 26));
    });

    test('beide Instants der doppelten Stunde liegen in derselben Woche', () {
      // Am 25.10.2026 fällt die lokale Uhrzeit 02:30 auf zwei verschiedene
      // Zeitpunkte: 00:30 UTC (noch Sommerzeit, UTC+2) und 01:30 UTC (schon
      // Winterzeit, UTC+1). Beide gehören zur Woche ab Montag, 19.10.
      final erstesMal = TrainingLoad.weekBounds(
        containing: DateTime.utc(2026, 10, 25, 0, 30),
      );
      final zweitesMal = TrainingLoad.weekBounds(
        containing: DateTime.utc(2026, 10, 25, 1, 30),
      );
      expect(erstesMal.$1, tag(2026, 10, 19));
      expect(zweitesMal.$1, tag(2026, 10, 19));
      expect(erstesMal.$2, zweitesMal.$2);
    });

    test('der Montag nach der Rückstellung gehört zur neuen Woche', () {
      // Der Fehler, den `+86400` macht: Sieben Mal 24 Stunden ab Montag,
      // 19.10. 00:00 Berlin landen am 25.10. um 23:00 Berlin — der
      // Montagvormittag des 26.10. fiele dann in die Vorwoche.
      final (start, _) = TrainingLoad.weekBounds(
        containing: tag(2026, 10, 26),
      );
      expect(start, tag(2026, 10, 26));
    });
  });

  group('weekMinutes summiert im halboffenen Fenster', () {
    test('Montag zählt, der folgende Montag nicht', () {
      final minuten = TrainingLoad.weekMinutes(
        days: [
          werte(tag(2026, 6, 15), 10), // Wochenanfang, zählt
          werte(tag(2026, 6, 17), 20),
          werte(tag(2026, 6, 21), 30), // Sonntag, letzter Tag der Woche
          werte(tag(2026, 6, 22), 1000), // Wochenende der Grenze: zählt nicht
        ],
        containing: tag(2026, 6, 17),
      );
      expect(minuten, 60.0);
    });

    test('Tage vor dem Wochenanfang zählen nicht', () {
      final minuten = TrainingLoad.weekMinutes(
        days: [
          werte(tag(2026, 6, 14), 1000), // Sonntag davor
          werte(tag(2026, 6, 15), 45),
        ],
        containing: tag(2026, 6, 17),
      );
      expect(minuten, 45.0);
    });

    test('Tage ohne Trainingsminuten zählen nicht als Null mit', () {
      // Der Unterschied ist nicht in der Summe sichtbar, sondern darin, dass
      // sie nicht abstürzt und dass ein Tag ohne Wert keine Null behauptet.
      final minuten = TrainingLoad.weekMinutes(
        days: [
          werte(tag(2026, 6, 15), null),
          werte(tag(2026, 6, 16), 25),
          werte(tag(2026, 6, 17), null),
        ],
        containing: tag(2026, 6, 17),
      );
      expect(minuten, 25.0);
    });

    test('eine leere Liste ergibt 0', () {
      expect(
        TrainingLoad.weekMinutes(days: const [], containing: tag(2026, 6, 17)),
        0.0,
      );
    });

    test('eine Woche ganz ohne Werte ergibt 0', () {
      expect(
        TrainingLoad.weekMinutes(
          days: [werte(tag(2026, 6, 1), 300)],
          containing: tag(2026, 6, 17),
        ),
        0.0,
      );
    });

    test('die Reihenfolge der Tage in der Liste ist egal', () {
      final minuten = TrainingLoad.weekMinutes(
        days: [
          werte(tag(2026, 6, 21), 30),
          werte(tag(2026, 6, 15), 10),
          werte(tag(2026, 6, 18), 20),
        ],
        containing: tag(2026, 6, 17),
      );
      expect(minuten, 60.0);
    });

    test('über die Umstellungswoche im Oktober wird vollständig summiert', () {
      // Auch der 25.10. — der Tag mit 25 Stunden — gehört dazu, und der
      // 26.10. nicht mehr.
      final minuten = TrainingLoad.weekMinutes(
        days: [
          werte(tag(2026, 10, 19), 5),
          werte(tag(2026, 10, 25), 15),
          werte(tag(2026, 10, 26), 1000),
        ],
        containing: tag(2026, 10, 21),
      );
      expect(minuten, 20.0);
    });

    test('über die Umstellungswoche im März wird vollständig summiert', () {
      final minuten = TrainingLoad.weekMinutes(
        days: [
          werte(tag(2026, 3, 23), 5),
          werte(tag(2026, 3, 29), 15), // Tag mit 23 Stunden
          werte(tag(2026, 3, 30), 1000),
        ],
        containing: tag(2026, 3, 25),
      );
      expect(minuten, 20.0);
    });
  });
}
