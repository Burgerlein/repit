import 'package:flutter_test/flutter_test.dart';

import 'package:repit/health/health_types.dart';

/// Tests für `DailyMetrics.ausMap` (Task 7) — die Dart-Hälfte des
/// Platform-Channel-Durchstichs zu HealthKit.
///
/// **Worum es geht, nicht mehr und nicht weniger:** #55 („Das
/// Schritte-Detail hängt") meldet „0 statt kein Wert" als Fehler.
/// Spec 8.2 in `docs/superpowers/specs/2026-10-23-flutter-rebuild-design.md`
/// erklärt, wo dieser Fehler entstehen *könnte*, wenn man ihn nicht bewusst
/// vermeidet: unterhalb von `Messwert<T>` aus Task 5, in genau dem Codec, der
/// die rohe `Map` vom Platform-Channel in `DailyMetrics` übersetzt. `Messwert`
/// kann nur trennen, was ihm getrennt übergeben wird — kommt ein fehlender
/// HealthKit-Wert hier schon als `0` an, sieht `Messwert` nachher nur noch
/// eine ganz normale `Bekannt(0)` und hat keine Chance mehr, das zu merken.
///
/// Der Vertrag laut Spec 8.2: **fehlende Felder fehlen in der `Map`**, sie
/// stehen nicht mit `0`, `0.0` oder `NSNull` drin. `ausMap` liest nur
/// vorhandene Schlüssel — kein `?? 0` an irgendeiner Stelle, egal ob der
/// Rückgabetyp `int` oder `double` ist.
///
/// **Die 14 Felder** (13 nullbare + `tag`) entsprechen eins zu eins
/// `Packages/TrainingsCore/Sources/TrainingsCore/Health/HealthTypes.swift:
/// 3-22` (`DailyMetrics`). Sechs sind `int`-Felder (`steps`, `activeKcal`,
/// `basalKcal`, `restingHR`, `standHours`, `recoveryHRDrop`), sieben sind
/// `double`-Felder (`hrvMs`, `respRate`, `vo2max`, `weightKg`, `bodyFatPct`,
/// `leanKg`, `exerciseMinutes`). Das Datum kommt als ISO-Tagesschlüssel unter
/// dem Schlüssel `tag` (derselbe String wie überall sonst in dieser
/// Dart-Codebasis, siehe `tag`-Spalte in `lib/data/tables.dart` und
/// `BerlinCalendar.dayKey` in `Packages/trainings_core`) — dieser Schlüssel
/// wird hier nur mitgeliefert, damit `ausMap` überhaupt eine gültige Map
/// bekommt; wie `tag` selbst intern abgelegt wird, ist nicht Gegenstand
/// dieses Tasks und wird hier nicht geprüft.
///
/// **Entscheidung — Verhalten bei falschem Typ (nicht mit Tim abgestimmt,
/// eine Entscheidung des Testautors, siehe Begründung in der Testgruppe
/// unten):** `ausMap` **wirft**, wenn ein Feld einen Wert hat, der nicht zum
/// erwarteten Typ passt, statt ihn still zu `null` oder `0` zu machen. Ein
/// falscher Typ kann auf dem echten Kanal nur durch einen Fehler in
/// `HealthChannel.alsMap` (Swift-Seite) entstehen — also einen Vertragsbruch,
/// keinen normalen Betriebszustand wie „kein Messwert". Ein Codec, der das
/// still schluckt, würde genau die Art von verstecktem Fehler neu einbauen,
/// die dieser ganze Task verhindern soll: aus Sicht der Dart-Seite sähe ein
/// kaputter Kanal dann genauso aus wie „HealthKit hatte diesen Tag keinen
/// Wert", und niemand würde es merken.
///
/// **Was hier absichtlich nicht geprüft wird:**
/// - Das genaue Format von `tag` (ISO-String? welches Datumsformat genau?)
///   — das ist eine Entscheidung der Implementierung, kein Teil des
///   Null-vs-Null-Vertrags, um den es in diesem Task geht.
/// - Der tatsächliche Transport über den `MethodChannel` (Serialisierung
///   durch Flutters Standard-Codec, `AppDelegate`-Registrierung, ein
///   echter Aufruf von `HealthChannel` im Simulator). Das läuft laut
///   Aufgabenstellung „ohne Gerät" — die letzte Gruppe unten bildet den
///   Rundlauf nur **simuliert** nach: dieselbe Map, die
///   `HealthChannelTests.swift` als Ausgabe von `alsMap` festnagelt, wird
///   hier von Hand nachgebaut und in `ausMap` gegeben. Stimmen beide Seiten
///   unabhängig überein, ist der Vertrag an der Kanalgrenze bewiesen — der
///   eigentliche Methodenaufruf über den Kanal (inklusive
///   `AppDelegate`-Registrierung) bleibt ungeprüft und braucht entweder
///   einen Simulator-Lauf oder einen späteren Integrationstest.
void main() {
  group('Pflichtfälle aus task-7-brief.md', () {
    test('ein fehlendes Feld fehlt in der Map und wird nie 0', () {
      final m = DailyMetrics.ausMap({'tag': '2026-10-23', 'steps': 9500});
      expect(m.steps, 9500);
      expect(m.restingHR, isNull, reason: 'nicht 0');
      expect(m.vo2max, isNull, reason: 'nicht 0.0');
    });

    test('ein echtes 0 bleibt 0 und wird nicht zu null', () {
      final m = DailyMetrics.ausMap({'tag': '2026-10-23', 'steps': 0});
      expect(
        m.steps,
        0,
        reason: 'null Schritte an einem Tag sind eine Aussage, kein Fehlen',
      );
    });
  });

  group('Eine Map ohne jegliches Feld außer "tag" — alle 13 nullbaren Felder '
      'bleiben null, kein Absturz', () {
    test('alle 13 Felder sind null, nichts wird 0 oder 0.0', () {
      final m = DailyMetrics.ausMap({'tag': '2026-10-23'});
      expect(m.steps, isNull);
      expect(m.activeKcal, isNull);
      expect(m.basalKcal, isNull);
      expect(m.restingHR, isNull);
      expect(m.hrvMs, isNull);
      expect(m.respRate, isNull);
      expect(m.vo2max, isNull);
      expect(m.weightKg, isNull);
      expect(m.bodyFatPct, isNull);
      expect(m.leanKg, isNull);
      expect(m.exerciseMinutes, isNull);
      expect(m.standHours, isNull);
      expect(m.recoveryHRDrop, isNull);
    });
  });

  group(
    'Echte 0 bleibt 0 — int- und double-Felder getrennt geprüft, weil ein '
    '"?? 0" bei beiden Typen unterschiedlich zuschlägt (int-0 vs. double-0.0)',
    () {
      test('alle sechs int-Felder mit echtem 0 bleiben 0, nicht null', () {
        final m = DailyMetrics.ausMap({
          'tag': '2026-10-23',
          'steps': 0,
          'activeKcal': 0,
          'basalKcal': 0,
          'restingHR': 0,
          'standHours': 0,
          'recoveryHRDrop': 0,
        });
        expect(m.steps, 0);
        expect(m.activeKcal, 0);
        expect(m.basalKcal, 0);
        expect(m.restingHR, 0);
        expect(m.standHours, 0);
        expect(m.recoveryHRDrop, 0);
      });

      test(
        'alle sieben double-Felder mit echtem 0.0 bleiben 0.0, nicht null',
        () {
          final m = DailyMetrics.ausMap({
            'tag': '2026-10-23',
            'hrvMs': 0.0,
            'respRate': 0.0,
            'vo2max': 0.0,
            'weightKg': 0.0,
            'bodyFatPct': 0.0,
            'leanKg': 0.0,
            'exerciseMinutes': 0.0,
          });
          expect(m.hrvMs, 0.0);
          expect(m.respRate, 0.0);
          expect(m.vo2max, 0.0);
          expect(m.weightKg, 0.0);
          expect(m.bodyFatPct, 0.0);
          expect(m.leanKg, 0.0);
          expect(m.exerciseMinutes, 0.0);
        },
      );
    },
  );

  group('Falscher Typ — Entscheidung des Testautors (siehe Dateikopf): ausMap '
      'wirft, statt den Wert still zu null oder 0 zu machen', () {
    // Nur zwei Fälle, stellvertretend für int- und double-Felder — eine
    // dritte, vierte Kopie derselben Prüfung auf einem weiteren Feld
    // belegt nichts Neues, das Verhalten ist pro Typ identisch.
    test('ein String, wo ein int erwartet wird (steps), wirft statt null '
        'oder 0 zu liefern', () {
      expect(
        () => DailyMetrics.ausMap({'tag': '2026-10-23', 'steps': 'neun'}),
        throwsA(anything),
        reason:
            'ein falscher Typ ist ein Vertragsbruch des Kanals (ein '
            'Fehler in HealthChannel.alsMap), kein normaler '
            '"kein Messwert"-Zustand — er soll laut werden, nicht wie '
            'ein harmloses Fehlen aussehen',
      );
    });

    test('ein bool, wo ein double erwartet wird (hrvMs), wirft statt null '
        'oder 0.0 zu liefern', () {
      expect(
        () => DailyMetrics.ausMap({'tag': '2026-10-23', 'hrvMs': true}),
        throwsA(anything),
      );
    });
  });

  group('Rundlauf (simuliert, ohne Gerät) — Teil Dart: dieselbe Map, die '
      'HealthChannelTests.swift (Gruppe "Rundlauf ... Teil Swift") als '
      'Ausgabe von HealthChannel.alsMap festnagelt, wird hier von Hand '
      'nachgebaut und in ausMap gegeben. Beide Seiten unabhängig geprüft, '
      'aber mit identischen Werten — der tatsächliche Kanalaufruf bleibt '
      'ungeprüft, siehe Dateikopf.', () {
    test('gemischte Felder: gesetzte Werte, fehlende Werte und eine echte 0 '
        'kommen alle korrekt an', () {
      final m = DailyMetrics.ausMap({
        'tag': '2026-10-23',
        'steps': 0, // echte 0 — die Gegenprobe
        'restingHR': 48,
        'hrvMs': 42.5,
        // activeKcal, basalKcal, respRate, vo2max, weightKg, bodyFatPct,
        // leanKg, exerciseMinutes, standHours, recoveryHRDrop fehlen
        // absichtlich in der Map — dieselben Felder, die in
        // HealthChannelTests.swift bei diesem DailyMetrics nil sind.
      });
      expect(m.steps, 0, reason: 'echte 0, nicht fehlend');
      expect(m.restingHR, 48);
      expect(m.hrvMs, 42.5);
      expect(m.activeKcal, isNull);
      expect(m.basalKcal, isNull);
      expect(m.respRate, isNull);
      expect(m.vo2max, isNull);
      expect(m.weightKg, isNull);
      expect(m.bodyFatPct, isNull);
      expect(m.leanKg, isNull);
      expect(m.exerciseMinutes, isNull);
      expect(m.standHours, isNull);
      expect(m.recoveryHRDrop, isNull);
    });
  });
}
