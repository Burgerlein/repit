import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/health/health_channel.dart';
import 'package:repit/health/health_types.dart';

/// Die Dart-Hälfte des Ernährungs-Kanals (#283, mit #232) — was über den
/// Kanal geht und was zurückkommt.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung**
/// (`CLAUDE.md`). Diese Datei darf ausgeführt, aber nicht verändert
/// werden.
///
/// ## Woher die Regeln kommen
///
/// - `CLAUDE.md`, Datenschicht: „`nil` darf auf dem Weg durch den Kanal
///   niemals zu `0` werden. Fehlende Felder fehlen in der Map, sie stehen
///   nicht mit Nullwert drin. … Ein falscher Typ wirft, statt still null zu
///   werden."
/// - #232: `NutritionEntry` machte aus fehlenden Nährwerten `0`
///   (`health_types.dart`, Ursache `.reduce(0, +)` auf der Swift-Seite).
/// - Plan `2026-11-03-ernaehrung.md`, Task 5, „Interfaces".
///
/// Die Swift-Gegenstücke prüft `app/ios/RunnerTests/
/// HealthNutritionWritingTests.swift` gegen **dieselben Wörter** — die
/// Kanalgrenze ist bewiesen, wenn beide Seiten unabhängig übereinstimmen.
///
/// ## Was diese Tests verbindlich vorgeben
///
/// `HealthChannel` (`lib/health/health_channel.dart`) bekommt die drei
/// Methoden aus `HealthReading`:
///
/// | Methode | Kanalaufruf | Argumente |
/// |---|---|---|
/// | `requestNutritionWriteAuthorization()` | `requestNutritionWriteAuthorization` | keine; Antwort ist einer der drei Namen von `WriteAuthorization`, ein anderer wirft |
/// | `writeMeal(werte:, name:, at:)` | `writeMeal` | `name`, `at` (ms seit 1970), dazu je **vorhandenem** Nährwert sein Schlüssel |
/// | `deleteMeal(id)` | `deleteMeal` | `id` |
///
/// Die Nährwertschlüssel, buchstabengleich zur Swift-Seite:
///
/// | `Naehrwerte` | Schlüssel |
/// |---|---|
/// | `kcal` | `kcal` |
/// | `eiweissG` | `proteinG` |
/// | `kohlenhydrateG` | `carbsG` |
/// | `fettG` | `fatG` |
/// | `gesaettigtG` | `saturatedFatG` |
/// | `zuckerG` | `sugarG` |
/// | `ballaststoffeG` | `fiberG` |
/// | `wasserMl` | `waterMl` |
///
/// `Naehrwerte.extra` geht **nicht** mit: Mikronährstoffe stehen nicht im
/// Schreibkatalog (Spec, „Der Schreibkatalog — er wird nicht gespiegelt").
///
/// Ein `PlatformException` mit Code `write_rejected` wird zu
/// `HealthWriteRejected` (siehe `health_schreiben_test.dart`); jeder andere
/// Fehler bleibt, was er ist.
///
/// `NutritionEntry` (`lib/health/health_types.dart`) trägt die acht
/// Nährwerte als `double?` unter den Namen der Schlüssel oben: `kcal`,
/// `proteinG`, `carbsG`, `fatG`, `saturatedFatG`, `sugarG`, `fiberG`,
/// `waterMl`. `time` und `name` bleiben Pflicht.
///
/// ## Festlegung dieser Datei — nicht von Tim freigegeben
///
/// `kcal` wird `double?` statt `int`: `Naehrwerte.kcal` ist ein `double?`,
/// und die Swift-Seite schickt, was HealthKit liefert. Ein `int` hier
/// zwänge zu einer Rundung an der Kanalgrenze, die niemand beschlossen hat.
///
/// Zahlen, Namen und Kennungen in dieser Datei sind erfunden.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const kanal = MethodChannel('de.rosenbach.repit/health');
  final gegessen = DateTime.utc(2026, 7, 14, 6, 30);

  late List<MethodCall> aufrufe;
  late Future<Object?> Function(MethodCall) antwort;

  setUp(() {
    aufrufe = [];
    antwort = (_) async => null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(kanal, (aufruf) {
          aufrufe.add(aufruf);
          return antwort(aufruf);
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(kanal, null);
  });

  HealthChannel quelle() => HealthChannel(channel: kanal);

  Map<Object?, Object?> argumente() =>
      aufrufe.single.arguments as Map<Object?, Object?>;

  group('requestNutritionWriteAuthorization', () {
    test('ruft die eigene Kanalmethode, nicht die des Gewichts', () async {
      antwort = (_) async => 'granted';

      await quelle().requestNutritionWriteAuthorization();

      expect(aufrufe.single.method, 'requestNutritionWriteAuthorization');
    });

    test('die drei Namen werden zu den drei Werten', () async {
      for (final wert in WriteAuthorization.values) {
        antwort = (_) async => wert.name;
        expect(await quelle().requestNutritionWriteAuthorization(), wert);
      }
    });

    test('ein unbekannter Name wirft, statt still denied zu werden', () async {
      antwort = (_) async => 'vielleicht';

      await expectLater(
        quelle().requestNutritionWriteAuthorization(),
        throwsA(anything),
      );
    });
  });

  group('writeMeal', () {
    test('Name und Zeitpunkt in Millisekunden gehen mit, die Kennung kommt '
        'zurück', () async {
      antwort = (_) async => 'C0FFEE00-0000-0000-0000-000000000001';

      final id = await quelle().writeMeal(
        werte: const Naehrwerte(kcal: 300),
        name: 'Testbrei',
        at: gegessen,
      );

      expect(id, 'C0FFEE00-0000-0000-0000-000000000001');
      expect(aufrufe.single.method, 'writeMeal');
      expect(argumente()['name'], 'Testbrei');
      expect(argumente()['at'], gegessen.millisecondsSinceEpoch);
    });

    test('alle acht Nährwerte unter ihren Schlüsseln', () async {
      antwort = (_) async => 'C0FFEE00-0000-0000-0000-000000000001';

      await quelle().writeMeal(
        werte: const Naehrwerte(
          kcal: 420,
          eiweissG: 21,
          kohlenhydrateG: 55,
          fettG: 12,
          gesaettigtG: 4,
          zuckerG: 9,
          ballaststoffeG: 7,
          wasserMl: 250,
        ),
        name: 'Testteller',
        at: gegessen,
      );

      final args = argumente();
      expect(args['kcal'], 420);
      expect(args['proteinG'], 21);
      expect(args['carbsG'], 55);
      expect(args['fatG'], 12);
      expect(args['saturatedFatG'], 4);
      expect(args['sugarG'], 9);
      expect(args['fiberG'], 7);
      expect(args['waterMl'], 250);
    });

    test('ein fehlender Nährwert fehlt in der Map — kein 0, kein null-Wert',
        () async {
      antwort = (_) async => 'C0FFEE00-0000-0000-0000-000000000001';

      await quelle().writeMeal(
        werte: const Naehrwerte(kcal: 300, eiweissG: 10),
        name: 'Testbrei',
        at: gegessen,
      );

      expect(argumente().keys.toSet(), {'name', 'at', 'kcal', 'proteinG'});
    });

    test('eine echte 0 geht als 0 mit', () async {
      antwort = (_) async => 'C0FFEE00-0000-0000-0000-000000000001';

      await quelle().writeMeal(
        werte: const Naehrwerte(kcal: 0, zuckerG: 0, wasserMl: 500),
        name: 'Testwasser',
        at: gegessen,
      );

      expect(argumente()['kcal'], 0);
      expect(argumente()['sugarG'], 0);
      expect(argumente()['waterMl'], 500);
    });

    test('Mikronährstoffe aus extra gehen nicht mit', () async {
      antwort = (_) async => 'C0FFEE00-0000-0000-0000-000000000001';

      await quelle().writeMeal(
        werte: const Naehrwerte(
          kcal: 300,
          extra: {'natriumMg': 120, 'vitaminCMg': null},
        ),
        name: 'Testbrei',
        at: gegessen,
      );

      expect(argumente().keys.toSet(), {'name', 'at', 'kcal'});
    });

    test('write_rejected wird HealthWriteRejected', () async {
      antwort = (_) async => throw PlatformException(code: 'write_rejected');

      await expectLater(
        quelle().writeMeal(
          werte: const Naehrwerte(kcal: 300),
          name: 'Testbrei',
          at: gegessen,
        ),
        throwsA(isA<HealthWriteRejected>()),
      );
    });

    test('ein anderer Kanalfehler wird nicht zu HealthWriteRejected', () async {
      // Sonst würde ein vorübergehender Fehler — gesperrtes Gerät, fehlende
      // Freigabe — den Eintrag für immer auf nicht_moeglich setzen.
      antwort = (_) async => throw PlatformException(code: 'health_error');

      await expectLater(
        quelle().writeMeal(
          werte: const Naehrwerte(kcal: 300),
          name: 'Testbrei',
          at: gegessen,
        ),
        throwsA(
          allOf(isA<Object>(), isNot(isA<HealthWriteRejected>())),
        ),
      );
    });
  });

  group('deleteMeal', () {
    test('schickt die Kennung unter id', () async {
      await quelle().deleteMeal('C0FFEE00-0000-0000-0000-000000000001');

      expect(aufrufe.single.method, 'deleteMeal');
      expect(argumente(), {'id': 'C0FFEE00-0000-0000-0000-000000000001'});
    });
  });

  group('NutritionEntry: ein fehlender Nährwert bleibt null (#232)', () {
    Map<Object?, Object?> karte(Map<String, Object?> naehrwerte) => {
      'time': gegessen.millisecondsSinceEpoch,
      'name': 'Fremdgericht',
      ...naehrwerte,
    };

    test('nur Eiweiß: alle anderen sieben sind null, nicht 0', () {
      final eintrag = NutritionEntry.ausMap(karte({'proteinG': 25.0}));

      expect(eintrag.proteinG, 25);
      expect(eintrag.kcal, isNull);
      expect(eintrag.carbsG, isNull);
      expect(eintrag.fatG, isNull);
      expect(eintrag.saturatedFatG, isNull);
      expect(eintrag.sugarG, isNull);
      expect(
        eintrag.fiberG,
        isNull,
        reason: 'Review Focus 2: ohne Ballaststoffangabe bleibt die Summe null',
      );
      expect(eintrag.waterMl, isNull);
    });

    test('alle acht kommen unter ihren Namen an', () {
      final eintrag = NutritionEntry.ausMap(
        karte({
          'kcal': 420.0,
          'proteinG': 21.0,
          'carbsG': 55.0,
          'fatG': 12.0,
          'saturatedFatG': 4.0,
          'sugarG': 9.0,
          'fiberG': 7.0,
          'waterMl': 250.0,
        }),
      );

      expect(eintrag.kcal, 420);
      expect(eintrag.proteinG, 21);
      expect(eintrag.carbsG, 55);
      expect(eintrag.fatG, 12);
      expect(eintrag.saturatedFatG, 4);
      expect(eintrag.sugarG, 9);
      expect(eintrag.fiberG, 7);
      expect(eintrag.waterMl, 250);
    });

    test('Zeit und Name kommen an', () {
      final eintrag = NutritionEntry.ausMap(karte({'kcal': 300.0}));

      expect(eintrag.time.isAtSameMomentAs(gegessen), isTrue);
      expect(eintrag.name, 'Fremdgericht');
    });

    test('eine echte 0 bleibt 0', () {
      final eintrag = NutritionEntry.ausMap(karte({'kcal': 0.0, 'sugarG': 0}));

      expect(eintrag.kcal, 0);
      expect(eintrag.sugarG, 0);
      expect(eintrag.proteinG, isNull);
    });

    test('kcal mit Nachkommastelle bleibt erhalten, eine ganze Zahl wird '
        'double', () {
      expect(NutritionEntry.ausMap(karte({'kcal': 512.5})).kcal, 512.5);
      expect(NutritionEntry.ausMap(karte({'kcal': 512})).kcal, 512.0);
    });

    test('ein falscher Typ wirft, statt still null zu werden', () {
      expect(
        () => NutritionEntry.ausMap(karte({'fiberG': 'viel'})),
        throwsA(anything),
      );
      expect(
        () => NutritionEntry.ausMap(karte({'kcal': true})),
        throwsA(anything),
      );
    });

    test('ohne Zeit oder Name wirft es — das ist ein Vertragsbruch', () {
      expect(
        () => NutritionEntry.ausMap({'name': 'Fremdgericht', 'kcal': 300.0}),
        throwsA(anything),
      );
      expect(
        () => NutritionEntry.ausMap({
          'time': gegessen.millisecondsSinceEpoch,
          'kcal': 300.0,
        }),
        throwsA(anything),
      );
    });
  });
}
