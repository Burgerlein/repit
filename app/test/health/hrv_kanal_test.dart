import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repit/health/health_channel.dart';
import 'package:repit/health/health_mock.dart';
import 'package:repit/health/health_types.dart';

/// Tests für Stufe 2 von #193 — die HRV als **einzelne Messreihe** über den
/// Platform-Channel (`docs/superpowers/specs/2026-11-02-193-nachtwerte.md`,
/// Abschnitt „Stufe 2 — HRV über den Kanal").
///
/// **Worum es geht.** `VitalKind` kannte bisher nur `heartRate` und
/// `respiratoryRate`; HRV kam ausschließlich als Tagesmittel über
/// `DailyMetrics.hrvMs`. Die Nachtwerte-Rechnung aus Stufe 1 braucht aber die
/// Einzelproben im Schlaffenster, und die gibt es nur über
/// `quantitySamples`.
///
/// **Der Vertrag, der hier geprüft wird**, ist der an der Kanalgrenze:
/// `HealthChannel.quantitySamples` schickt `kind.name` als Zeichenkette
/// (siehe `health_channel.dart`), und die Swift-Seite erkennt genau diese
/// Zeichenkette wieder (`HealthChannel.vitalKind`, geprüft in
/// `app/ios/RunnerTests/HealthVitalKindTests.swift`). Beide Hälften prüfen
/// unabhängig gegen dieselbe Zeichenkette `heartRateVariability` — stimmen
/// sie überein, ist der Übergang bewiesen, ohne dass hier ein Gerät nötig
/// wäre. Dasselbe Verfahren wie in `channel_codec_test.dart`.
///
/// **Die Einheit wird hier bewusst nicht geprüft.** SDNN ist eine Zeit
/// (Millisekunden), Puls und Atmung sind Zählungen je Minute; welche
/// `HKUnit` je Art gilt, entscheidet sich vollständig auf der Swift-Seite und
/// ist dort geprüft. Die Dart-Seite sieht nur noch Zahlen und kann einen
/// Einheitenfehler prinzipiell nicht bemerken — ein Test, der hier einen
/// Wertebereich festnagelt, behauptete eine Prüfung, die er nicht leistet.
///
/// **Was hier absichtlich nicht geprüft wird:**
/// - Der tatsächliche Transport zum echten HealthKit-Adapter (braucht ein
///   Gerät, siehe CLAUDE.md „Prüfen im Simulator").
/// - Die genaue Kurvenform der Mock-Reihe. Wie viele Proben der Mock je Nacht
///   erfindet und mit welchem Verlauf, ist eine gestalterische Entscheidung
///   des Mocks und kein Vertrag — genauso wie bei `hourlySteps`, siehe
///   `mock_test.dart`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VitalKind kennt die HRV als eigene Messreihe', () {
    test('der Name ist buchstabengleich zur Swift-Zeichenkette', () {
      expect(
        VitalKind.heartRateVariability.name,
        'heartRateVariability',
        reason:
            'health_channel.dart schickt kind.name; HealthChannel.vitalKind '
            'auf der Swift-Seite vergleicht gegen genau diese Zeichenkette',
      );
    });

    test('es gibt genau drei Arten', () {
      expect(
        VitalKind.values.map((art) => art.name).toList(),
        ['heartRate', 'respiratoryRate', 'heartRateVariability'],
        reason:
            'kommt eine vierte Art dazu, muss sie auch in vitalKind und in '
            'der Einheitenzuordnung auf der Swift-Seite auftauchen',
      );
    });
  });

  group('Der Kanal schickt die Art und liest die Antwort als QuantitySample', () {
    const kanalName = 'de.rosenbach.repit/health';
    const kanal = MethodChannel(kanalName);

    late List<MethodCall> aufrufe;
    late List<Object?> antwort;

    void haengeAn(Future<Object?> Function(MethodCall) handler) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(kanal, handler);
    }

    setUp(() {
      aufrufe = [];
      antwort = const <Object?>[];
      haengeAn((aufruf) async {
        aufrufe.add(aufruf);
        return antwort;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(kanal, null);
    });

    test('kind ist "heartRateVariability", der Zeitraum geht in Millisekunden mit', () async {
      final von = DateTime.utc(2026, 10, 12, 21);
      final bis = DateTime.utc(2026, 10, 13, 6);

      await HealthChannel(channel: kanal).quantitySamples(
        VitalKind.heartRateVariability,
        von,
        bis,
      );

      expect(aufrufe, hasLength(1));
      expect(aufrufe.single.method, 'quantitySamples');
      final argumente = aufrufe.single.arguments as Map<Object?, Object?>;
      expect(argumente['kind'], 'heartRateVariability');
      expect(argumente['from'], von.millisecondsSinceEpoch);
      expect(argumente['through'], bis.millisecondsSinceEpoch);
    });

    test('die Antwort kommt als QuantitySample zurück', () async {
      antwort = const <Object?>[
        {'date': 1792262700000, 'value': 48.5},
        {'date': 1792273500000, 'value': 61.0},
      ];

      final proben = await HealthChannel(channel: kanal).quantitySamples(
        VitalKind.heartRateVariability,
        DateTime.utc(2026, 10, 12, 21),
        DateTime.utc(2026, 10, 13, 6),
      );

      expect(proben, hasLength(2));
      expect(proben.first, isA<QuantitySample>());
      expect(proben.first.date,
          DateTime.fromMillisecondsSinceEpoch(1792262700000));
      expect(proben.first.value, 48.5);
      expect(proben.last.value, 61.0);
    });

    test('eine Nacht ohne HRV-Probe ergibt eine leere Liste, keine Null', () async {
      antwort = const <Object?>[];

      final proben = await HealthChannel(channel: kanal).quantitySamples(
        VitalKind.heartRateVariability,
        DateTime.utc(2026, 10, 12, 21),
        DateTime.utc(2026, 10, 13, 6),
      );

      expect(proben, isEmpty);
    });

    test('die beiden bisherigen Arten schicken weiter ihre eigenen Namen', () async {
      final kanalObjekt = HealthChannel(channel: kanal);
      final von = DateTime.utc(2026, 10, 12, 21);
      final bis = DateTime.utc(2026, 10, 13, 6);

      await kanalObjekt.quantitySamples(VitalKind.heartRate, von, bis);
      await kanalObjekt.quantitySamples(VitalKind.respiratoryRate, von, bis);

      final arten = aufrufe
          .map((a) => (a.arguments as Map<Object?, Object?>)['kind'])
          .toList();
      expect(arten, ['heartRate', 'respiratoryRate']);
    });
  });

  group('Der Mock liefert eine eigene HRV-Reihe', () {
    // Fenster im festen Zeitraum des Demo-Datensatzes (10.09.–27.10.2026),
    // nie relativ zu `DateTime.now()` — siehe Dateikopf von `mock_test.dart`.
    final von = DateTime.utc(2026, 9, 10);
    final bis = DateTime.utc(2026, 9, 20);

    test('die Reihe ist nicht leer und trägt positive Werte', () async {
      final proben = await MockHealthReading()
          .quantitySamples(VitalKind.heartRateVariability, von, bis);

      expect(proben, isNotEmpty,
          reason: 'sonst bliebe der Nachtwert im Simulator dauerhaft leer');
      expect(proben.every((p) => p.value > 0), isTrue);
    });

    test('die Proben stehen aufsteigend und liegen im angefragten Fenster', () async {
      final proben = await MockHealthReading()
          .quantitySamples(VitalKind.heartRateVariability, von, bis);

      for (var i = 1; i < proben.length; i++) {
        expect(proben[i - 1].date.isAfter(proben[i].date), isFalse);
      }
      expect(proben.first.date.isBefore(von), isFalse);
    });

    test('es ist nicht dieselbe Reihe wie der Puls', () async {
      final mock = MockHealthReading();
      final hrv =
          await mock.quantitySamples(VitalKind.heartRateVariability, von, bis);
      final puls = await mock.quantitySamples(VitalKind.heartRate, von, bis);

      expect(
        hrv.map((p) => p.value).toList(),
        isNot(equals(puls.map((p) => p.value).toList())),
        reason:
            'eine HRV, die den Puls wiederholt, sähe im Simulator richtig aus '
            'und wäre es nicht',
      );
    });
  });
}
