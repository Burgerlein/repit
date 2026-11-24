import 'package:flutter_test/flutter_test.dart';

import 'package:repit/health/health_types.dart';

/// Der Transporttyp der Gewichtsproben (#270) — `WeightSample` und
/// `WeightSample.ausMap` in `lib/health/health_types.dart`.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung**
/// (`CLAUDE.md`). Diese Datei darf ausgeführt, nie verändert werden.
///
/// ## Warum es den Typ überhaupt gibt
///
/// `docs/superpowers/specs/2026-11-03-gewicht-eintragen-design.md`,
/// Abschnitt „Das Kennzeichen „manuell"": Die Gewichtsabfrage wechselt von
/// `HKStatisticsCollectionQuery` auf eine Probenabfrage, „eine Statistik
/// trägt weder Metadaten noch die Uhrzeit noch die UUID — alle drei braucht
/// ‚Letzte Messungen'" (Kennzeichen, Sortierung innerhalb eines Tages,
/// Löschen). `DailyMetrics.weightKg` bleibt daneben unverändert.
///
/// **Er liegt in `app/`, nicht im Kern.** Er ist die Nutzlast des Kanals und
/// trägt keine Rechnung (`CLAUDE.md`, „Transporttypen gehören nicht in den
/// Kern") — dieselbe Begründung wie bei `DailyMetrics` und `QuantitySample`
/// nebenan.
///
/// ## Festgelegte öffentliche API (`lib/health/health_types.dart`)
///
/// ```dart
/// class WeightSample {
///   // Nicht `const`-fähig, und das liegt an [DateTime] — dieselbe Grenze
///   // wie bei `MeasurementPoint` im Kern.
///   WeightSample({
///     required String id,
///     required DateTime date,
///     required double kg,
///     required bool wasUserEntered,
///   });
///
///   /// Die HealthKit-UUID. Roher `String` wie `WorkoutSample.id` — der
///   /// Kanal schickt ohnehin nur eine Zeichenkette. Sie ist das, was
///   /// `deleteWeight` später braucht.
///   final String id;
///
///   /// Der Zeitpunkt der Wägung. `start == end` bei einer Probe, es
///   /// kommt also nur einer über den Kanal.
///   final DateTime date;
///
///   final double kg;
///
///   /// `HKMetadataKeyWasUserEntered` — **nicht** unsere Buchhaltung.
///   final bool wasUserEntered;
///
///   factory WeightSample.ausMap(Map<Object?, Object?> map);
/// }
/// ```
///
/// Mit `==` und `hashCode`: Eine Liste davon ist Abhängigkeit eines
/// Providers, und ohne Wertgleichheit wäre jede neu gelesene Liste ungleich
/// der vorigen und jeder abgeleitete Wert liefe neu — Fehler `03`,
/// wortgleich im neuen Code (`CLAUDE.md`). Dieselbe Begründung wie bei
/// `MeasurementPoint` im Kern.
///
/// ## Der Vertrag an der Kanalgrenze
///
/// Dieselbe Regel wie in `channel_codec_test.dart` und
/// `workout_codec_test.dart`: **Ein fehlendes Feld fehlt in der Map**, es
/// steht nicht mit Nullwert drin, und ein falscher Typ **wirft**, statt
/// still `null` zu werden. Bei diesem Typ ist allerdings **kein** Feld
/// optional — alle vier liegen an jeder `HKQuantitySample` vor. Ein
/// fehlendes Feld ist hier deshalb immer ein Vertragsbruch der Swift-Seite,
/// nie eine Datenlage, und genau so wird es behandelt.
///
/// **Besonders `wasUserEntered`.** Ein `?? false` dort wäre nicht
/// harmlos: Die Zeile verlöre still ihre Tür, und „von Hand eingetragen"
/// sähe aus wie „von der Waage" — der Nutzer käme an seinen eigenen Wert
/// nicht mehr heran und sähe nicht, warum.
///
/// ## Was hier **nicht** geprüft wird
///
/// - **Ob `date` als UTC- oder Ortszeit-`DateTime` herauskommt.**
///   `QuantitySample.ausMap` nebenan legt sich darauf nicht fest; geprüft
///   wird der Zeitpunkt, nicht seine Schreibweise.
/// - **Der tatsächliche Transport über den `MethodChannel`.** Die Swift-Seite
///   bekommt eigene Tests; sie brauchen ein Gerät und kommen getrennt.
///
/// ## Erfundene Zahlen
///
/// Jedes Gewicht und jede UUID hier ist ausgedacht (`CLAUDE.md`).
void main() {
  // Ein Zeitpunkt mit Uhrzeit — genau das, was eine Statistik nicht hätte.
  final gemessen = DateTime.utc(2026, 10, 18, 5, 20);

  Map<Object?, Object?> volleMap({
    String id = 'A1B2C3D4-0000-0000-0000-000000000001',
    int? datum,
    Object kg = 58.6,
    bool wasUserEntered = true,
  }) => <Object?, Object?>{
    'id': id,
    'date': datum ?? gemessen.millisecondsSinceEpoch,
    'kg': kg,
    'wasUserEntered': wasUserEntered,
  };

  group('Die vier Felder kommen durch', () {
    test('vollständige Map', () {
      final probe = WeightSample.ausMap(volleMap());

      expect(probe.id, 'A1B2C3D4-0000-0000-0000-000000000001');
      expect(
        probe.date.millisecondsSinceEpoch,
        gemessen.millisecondsSinceEpoch,
      );
      expect(probe.kg, closeTo(58.6, 1e-9));
      expect(probe.wasUserEntered, isTrue);
    });

    test('die Uhrzeit bleibt erhalten, nicht nur der Tag', () {
      final probe = WeightSample.ausMap(volleMap());

      expect(
        probe.date.toUtc().hour * 60 + probe.date.toUtc().minute,
        gemessen.hour * 60 + gemessen.minute,
        reason:
            'Die Uhrzeit entscheidet mit, welcher Wert für den Tag gilt — '
            'genau deshalb reicht eine Statistik nicht (Spec)',
      );
    });

    test('eine ganze Zahl vom Kanal wird zum `double`', () {
      // `NSNumber` kommt für 58,0 als `int` herüber — dieselbe Stelle wie
      // `WorkoutSample.minutes` (`as num).toDouble()`).
      final probe = WeightSample.ausMap(volleMap(kg: 58));

      expect(probe.kg, closeTo(58.0, 1e-9));
    });

    test('eine Probe von der Waage trägt `false`, und das bleibt so', () {
      final probe = WeightSample.ausMap(volleMap(wasUserEntered: false));

      expect(probe.wasUserEntered, isFalse);
    });
  });

  group('Ein fehlendes Feld ist ein Vertragsbruch, keine Datenlage', () {
    test('ohne `wasUserEntered` wirft es, statt still `false` zu werden', () {
      final map = volleMap()..remove('wasUserEntered');

      expect(
        () => WeightSample.ausMap(map),
        throwsA(anything),
        reason:
            'Ein `?? false` nähme der Zeile ihre Tür, ohne dass es jemand '
            'sähe — „von Hand" sähe aus wie „von der Waage"',
      );
    });

    test('ohne `id` wirft es', () {
      final map = volleMap()..remove('id');

      expect(
        () => WeightSample.ausMap(map),
        throwsA(anything),
        reason: 'Ohne UUID ließe sich die Probe nie wieder löschen',
      );
    });

    test('ohne `kg` wirft es, statt eine 0 zu erfinden', () {
      final map = volleMap()..remove('kg');

      expect(
        () => WeightSample.ausMap(map),
        throwsA(anything),
        reason: '`nil` darf auf dem Weg durch den Kanal nie zu `0` werden',
      );
    });

    test('ohne `date` wirft es', () {
      final map = volleMap()..remove('date');

      expect(() => WeightSample.ausMap(map), throwsA(anything));
    });
  });

  group('Ein falscher Typ wirft', () {
    test('`kg` als Text', () {
      expect(
        () => WeightSample.ausMap(volleMap(kg: 'achtundfünfzig')),
        throwsA(anything),
        reason:
            'Das ist ein Programmierfehler im Kanal, keine Datenlage '
            '(`CLAUDE.md`)',
      );
    });

    test('`wasUserEntered` als Zahl', () {
      final map = volleMap();
      map['wasUserEntered'] = 1;

      expect(() => WeightSample.ausMap(map), throwsA(anything));
    });
  });

  group('Wertgleichheit — sonst läuft jeder abgeleitete Wert neu', () {
    test('zwei gleich gelesene Proben sind gleich', () {
      expect(WeightSample.ausMap(volleMap()), WeightSample.ausMap(volleMap()));
      expect(
        WeightSample.ausMap(volleMap()).hashCode,
        WeightSample.ausMap(volleMap()).hashCode,
      );
    });

    test('eine andere UUID macht sie ungleich', () {
      expect(
        WeightSample.ausMap(volleMap()),
        isNot(WeightSample.ausMap(volleMap(id: 'eine-andere'))),
      );
    });

    test('ein anderes Gewicht macht sie ungleich', () {
      expect(
        WeightSample.ausMap(volleMap()),
        isNot(WeightSample.ausMap(volleMap(kg: 58.7))),
      );
    });

    test('ein anderes Kennzeichen macht sie ungleich', () {
      expect(
        WeightSample.ausMap(volleMap()),
        isNot(WeightSample.ausMap(volleMap(wasUserEntered: false))),
      );
    });

    test('eine andere Uhrzeit macht sie ungleich', () {
      expect(
        WeightSample.ausMap(volleMap()),
        isNot(
          WeightSample.ausMap(
            volleMap(
              datum: gemessen
                  .add(const Duration(minutes: 1))
                  .millisecondsSinceEpoch,
            ),
          ),
        ),
      );
    });

    test('eine Liste von Proben lässt sich vergleichen', () {
      // Genau das macht Riverpod mit einer Provider-Abhängigkeit.
      expect(
        [WeightSample.ausMap(volleMap())],
        [WeightSample.ausMap(volleMap())],
      );
    });
  });

  group('Der Konstruktor steht offen', () {
    test('eine Probe lässt sich auch ohne Map bauen', () {
      // Tests und Mock bauen Proben direkt; ohne öffentlichen Konstruktor
      // ginge das nur über eine nachgebaute Kanal-Map.
      final probe = WeightSample(
        id: 'eine-probe',
        date: gemessen,
        kg: 58.4,
        wasUserEntered: true,
      );

      expect(probe.id, 'eine-probe');
      expect(probe.date, gemessen);
      expect(probe.kg, closeTo(58.4, 1e-9));
      expect(probe.wasUserEntered, isTrue);
    });
  });
}
