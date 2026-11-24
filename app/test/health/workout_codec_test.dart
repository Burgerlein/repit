import 'package:flutter_test/flutter_test.dart';

import 'package:repit/health/health_types.dart';

/// Tests für `WorkoutSample.ausMap` (Task 12) — die Dart-Hälfte des
/// nil-Vertrags für die Kanal-Methode `workouts`, das Gegenstück zu
/// `HealthChannelExtendedCodecTests.swift` auf der Swift-Seite.
///
/// **Warum nur `WorkoutSample` und nicht alle sechs neuen Methoden —**
/// dieselbe Begründung wie dort (siehe Dateikopf von
/// `HealthChannelExtendedCodecTests.swift`): Nur `WorkoutSample` hat
/// optionale numerische Felder (`km`, `avgHR`, `maxHR`), bei denen „fehlt"
/// und „ist 0" verschiedene Aussagen sind. `QuantitySample` (gemeinsamer
/// Rückgabetyp von `quantitySamples` **und** `hourlySteps`) hat nur
/// `date`/`value`, beide nicht optional; `NutritionEntry` hat keine
/// optionalen Felder; `SleepSegment`/`SleepSession`/`SleepNight` auch nicht.
/// Eine Kopie dieser Prüfung auf einem dieser Typen würde nichts Neues
/// belegen, exakt wie `channel_codec_test.dart` das für den
/// Typfehler-Fall bei `DailyMetrics.ausMap` begründet.
///
/// **Vertrag, identisch zu `HealthChannel.alsMap(_: WorkoutSample)`:**
/// `id` als UUID-String, `start` als Millisekunden seit 1970 (`int`, wie die
/// `from`/`through`-Argumente des Kanals), `kind` als `WorkoutKind`-Name
/// (`running`, `walking`, `cycling`, `strength`, `swimming`, `soccer`,
/// `other`), `minutes` als `double`, `km`/`avgHR`/`maxHR` **fehlen in der
/// Map**, wenn `null` — kein `?? 0`/`?? 0.0` an irgendeiner Stelle —,
/// `wasUserEntered` als `bool`, immer vorhanden (nicht optional in
/// `HealthTypes.swift`).
///
/// **Was hier absichtlich nicht geprüft wird:** der tatsächliche
/// `MethodChannel`-Transport — wie bei `channel_codec_test.dart` (Task 7)
/// bildet die letzte Gruppe den Rundlauf nur simuliert nach: dieselbe Map,
/// die `HealthChannelExtendedCodecTests.rundlaufTeilSwift` als Ausgabe von
/// `alsMap` festnagelt, wird hier von Hand nachgebaut und in `ausMap`
/// gegeben.
void main() {
  group('fehlende Felder fehlen in der Map und werden nie null-zu-0', () {
    test('km/avgHR/maxHR fehlen -> alle drei bleiben null, kein Absturz', () {
      final w = WorkoutSample.ausMap({
        'id': '5F2B9A41-0C7E-4D3A-9B18-7E6C2A4D8F03',
        'start': 1_792_195_200_000,
        'kind': 'walking',
        'minutes': 54.0,
        'wasUserEntered': false,
      });
      expect(w.km, isNull);
      expect(w.avgHR, isNull);
      expect(w.maxHR, isNull);
      expect(w.minutes, 54.0);
    });
  });

  group('eine echte 0 bleibt 0, wird nicht zu null', () {
    test('avgHR/maxHR mit echtem 0 bleiben 0', () {
      final w = WorkoutSample.ausMap({
        'id': '5F2B9A41-0C7E-4D3A-9B18-7E6C2A4D8F03',
        'start': 1_792_195_200_000,
        'kind': 'strength',
        'minutes': 12.0,
        'avgHR': 0,
        'maxHR': 0,
        'wasUserEntered': false,
      });
      expect(w.avgHR, 0, reason: 'eine echte 0 ist ein Messwert, kein fehlender');
      expect(w.maxHR, 0);
    });
  });

  group('gesetzte Felder kommen mit Wert und richtigem Typ an', () {
    test('kind wird auf die passende WorkoutKind abgebildet', () {
      final w = WorkoutSample.ausMap({
        'id': '5F2B9A41-0C7E-4D3A-9B18-7E6C2A4D8F03',
        'start': 1_792_195_200_000,
        'kind': 'running',
        'minutes': 32.5,
        'km': 5.1,
        'avgHR': 142,
        'maxHR': 168,
        'wasUserEntered': true,
      });
      expect(w.kind, WorkoutKind.running);
      expect(w.km, 5.1);
      expect(w.avgHR, 142);
      expect(w.maxHR, 168);
      expect(w.wasUserEntered, isTrue);
      expect(w.start.millisecondsSinceEpoch, 1_792_195_200_000);
      expect(w.id, '5F2B9A41-0C7E-4D3A-9B18-7E6C2A4D8F03');
    });
  });

  group(
    'Rundlauf (simuliert, ohne Geraet) — Teil Dart: dieselbe Map, die '
    'HealthChannelExtendedCodecTests.rundlaufTeilSwift als Ausgabe von '
    'HealthChannel.alsMap festnagelt, wird hier von Hand nachgebaut und in '
    'WorkoutSample.ausMap gegeben.',
    () {
      test('das Krafttraining ohne km (gymWorkout) kommt unveraendert an', () {
        final w = WorkoutSample.ausMap({
          'id': '5F2B9A41-0C7E-4D3A-9B18-7E6C2A4D8F03',
          'start': 1_792_195_200_000,
          'kind': 'strength',
          'minutes': 64.0,
          'avgHR': 112,
          'maxHR': 158,
          'wasUserEntered': false,
          // 'km' fehlt absichtlich — dieselbe Map wie auf der Swift-Seite.
        });
        expect(w.km, isNull, reason: 'kein GPS bei einem Krafttraining — km fehlt, ist nicht 0');
        expect(w.avgHR, 112);
        expect(w.maxHR, 158);
        expect(w.minutes, 64.0);
        expect(w.wasUserEntered, isFalse);
      });
    },
  );
}
