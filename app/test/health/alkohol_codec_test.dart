import 'package:flutter_test/flutter_test.dart';
import 'package:repit/health/health_mock.dart';
import 'package:repit/health/health_types.dart';

/// Alkohol auf der Dart-Hälfte des Kanals (#125) — und im Mock.
///
/// Die Swift-Hälfte steht in `app/ios/RunnerTests/HealthChannelAlcoholTests
/// .swift`; dort wird geprüft, dass `alsMap` einen fehlenden Wert **nicht**
/// in die Map schreibt. Hier die Gegenseite: dass ein fehlender Schlüssel
/// als `null` ankommt und nicht als `0`.
///
/// **Warum das bei Alkohol schwerer wiegt als bei Schritten.** „Keine Daten"
/// und „nicht freigegeben" sind bei Apple Health nicht unterscheidbar
/// (`CLAUDE.md`). Eine `0`, die aus einem fehlenden Schlüssel entsteht, wäre
/// deshalb nicht nur ein falscher Messwert, sondern eine Behauptung über das
/// Verhalten des Nutzers — und die wäre an genau der Stelle entstanden, an
/// der `Messwert<T>` sie nicht mehr sehen kann, nämlich unterhalb von ihm.
///
/// **Getränke, keine Gramm.** Einen Nährwert `dietaryAlcohol` gibt es in
/// HealthKit nicht; gelesen wird `NumberOfAlcoholicBeverages`, Einheit
/// `count`. Deshalb heißt das Feld `alcoholicDrinks` und ist ein `double` —
/// ein Tagebuch darf ein halbes Getränk eintragen.
///
/// Alle Zahlen erfunden, auch die im Demo-Datensatz.
void main() {
  group('DailyMetrics.ausMap — ein fehlender Alkoholwert bleibt null', () {
    test('ohne Schlüssel ist alcoholicDrinks null, nicht 0', () {
      final m = DailyMetrics.ausMap({'tag': '2026-10-23'});

      expect(
        m.alcoholicDrinks,
        isNull,
        reason:
            '0 statt kein Wert hiesse „an diesem Tag nichts getrunken" — '
            'das kann auch eine fehlende Freigabe sein',
      );
    });

    test('eine echte 0 bleibt 0', () {
      final m = DailyMetrics.ausMap({
        'tag': '2026-10-23',
        'alcoholicDrinks': 0.0,
      });

      expect(m.alcoholicDrinks, 0.0);
    });

    test('ein gesetzter Wert kommt unverändert an', () {
      final m = DailyMetrics.ausMap({
        'tag': '2026-10-23',
        'alcoholicDrinks': 2.0,
      });

      expect(m.alcoholicDrinks, 2.0);
    });

    test('ein halbes Getränk bleibt ein halbes', () {
      final m = DailyMetrics.ausMap({
        'tag': '2026-10-23',
        'alcoholicDrinks': 0.5,
      });

      expect(m.alcoholicDrinks, 0.5);
    });

    test('Alkohol nimmt den übrigen Feldern nichts weg', () {
      final m = DailyMetrics.ausMap({
        'tag': '2026-10-23',
        'steps': 0,
        'hrvMs': 42.5,
        'alcoholicDrinks': 1.0,
      });

      expect(m.steps, 0);
      expect(m.hrvMs, 42.5);
      expect(m.alcoholicDrinks, 1.0);
      expect(m.restingHR, isNull);
    });
  });

  group('MockHealthReading reicht die Getränke des Demo-Datensatzes durch', () {
    /// Der Datensatz deckt den 10.09. bis 27.10.2026 ab; außerhalb liefert
    /// der Mock leere Listen (siehe `mock_test.dart`).
    Future<Map<String, double?>> tage() async {
      final werte = await MockHealthReading().dailyMetrics(
        DateTime.utc(2026, 10, 1),
        DateTime.utc(2026, 10, 27),
      );
      return {for (final tag in werte) tag.tag: tag.alcoholicDrinks};
    }

    test('ein Tag mit Eintrag trägt seine Zahl', () async {
      expect((await tage())['2026-10-10'], 3);
    });

    test('ein Tag mit einer gemessenen 0 trägt 0, nicht null', () async {
      expect(
        (await tage())['2026-10-20'],
        0,
        reason: 'gemessen und nichts ist etwas anderes als nicht gemessen',
      );
    });

    test('ein Tag ohne Eintrag bleibt null', () async {
      expect(
        (await tage())['2026-10-11'],
        isNull,
        reason:
            'der Mock erfindet nichts dazu — ein Tag ohne Schlüssel im '
            'Datensatz hat keinen Wert',
      );
    });

    test('es gibt überhaupt Alkohol-Tage im Datensatz', () async {
      final mitWert = (await tage()).values.where(
        (wert) => wert != null && wert > 0,
      );

      expect(
        mitWert,
        isNotEmpty,
        reason:
            'ohne sie wäre die Zeile im Simulator unsichtbar und niemand '
            'prüfte sie',
      );
    });
  });
}
