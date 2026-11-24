import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für die **Zonenverteilung** aus Ticket #95 — `docs/SPEC.md` 4.7
/// („Verteilung der Laufzeit nach Zonen (Ziel ≥ 80 % in Zone 1–2)").
///
/// Fachliche Vorlage ist
/// `Packages/TrainingsCore/Sources/TrainingsCore/Endurance/ZoneDistribution.swift`
/// samt `Tests/TrainingsCoreTests/ZoneDistributionTests.swift` — die
/// Doppelung Swift/Dart ist Absicht (`CLAUDE.md`, „Die Doppelung ist
/// Absicht").
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, nie verändert werden.
///
/// ## API, die diese Tests verbindlich vorgeben
///
/// ```dart
/// /// Die Workout-Arten, die der Kanal unterscheidet — dieselben sieben
/// /// Fälle wie `WorkoutKind` in Swifts `HealthTypes.swift`, damit die
/// /// beiden Fassungen deckungsgleich bleiben.
/// enum WorkoutKind { running, walking, cycling, strength, swimming,
///   soccer, other }
///
/// /// Ein Workout mit genau den Feldern, die diese Rechnung braucht —
/// /// schlank wie `RecoveryDay` (`recovery_input.dart`): Der Kern bekommt
/// /// eigene Typen, die App bildet ihre Kanal-Typen darauf ab.
/// /// `avgHeartRate == null` heißt „kein Puls gemessen", nie Null.
/// class WorkoutSample {
///   const WorkoutSample({
///     required WorkoutKind kind,
///     required double minutes,
///     int? avgHeartRate,
///   });
///   final WorkoutKind kind;
///   final double minutes;
///   final int? avgHeartRate;
///   // == und hashCode nach Wert.
/// }
///
/// /// `zone == 0` bedeutet „unter Zone 1".
/// class ZoneShare {
///   const ZoneShare({required int zone, required double minutes});
///   final int zone;
///   final double minutes;
///   // == und hashCode nach Wert.
/// }
///
/// abstract final class ZoneDistribution {
///   /// Immer sechs Einträge, Zone 0 bis 5, auch leere. Gezählt wird die
///   /// Laufzeit nach dem Ø-Puls jedes Laufs — eine Näherung, die die
///   /// Beschriftung benennen muss. Läufe ohne Ø-Puls zählen **nicht** mit;
///   /// als 0 bpm geführt sähe die Verteilung umso lockerer aus, je
///   /// weniger gemessen wurde. Ein Puls auf einer Zonen-Untergrenze
///   /// gehört zu dieser Zone.
///   static List<ZoneShare> shares(
///     List<WorkoutSample> workouts, {
///     required HeartRateZoning zoning,
///   });
///
///   /// Anteil der Laufzeit in Zone 1 und 2 zusammen (Ziel ≥ 80 %),
///   /// `null` ohne gezählte Laufzeit.
///   static double? easyShare(List<ZoneShare> shares);
/// }
/// ```
///
/// **Alle Zahlen sind erfunden.** HFmax 205 / Ruhepuls 62 sind die
/// Beispielwerte aus SPEC 4.7; nach Karvonen ergibt das Zone 1 = 134–148,
/// Zone 2 = 148–162, Zone 3 = 162–176, Zone 4 = 176–191, Zone 5 = 191–205.
/// Die Pulswerte unten sind an diesen Grenzen gewählt.
void main() {
  final zoning = HeartRateZones.zoning(hrMax: 205, hrRest: 62);

  WorkoutSample run(
    double minutes, {
    int? avgHeartRate,
    WorkoutKind kind = WorkoutKind.running,
  }) =>
      WorkoutSample(kind: kind, minutes: minutes, avgHeartRate: avgHeartRate);

  double total(List<ZoneShare> shares) =>
      shares.fold(0, (sum, s) => sum + s.minutes);

  group('Jeder Lauf landet mit seiner vollen Zeit in einer Zone', () {
    test('ein Lauf mit Ø 180 liegt komplett in Zone 4', () {
      final shares =
          ZoneDistribution.shares([run(60, avgHeartRate: 180)], zoning: zoning);
      expect(total(shares), 60);
      expect(shares.where((s) => s.minutes > 0), hasLength(1));
      expect(shares.firstWhere((s) => s.zone == 4).minutes, 60);
    });

    test('ein lockerer und ein harter Lauf verteilen sich auf zwei Zonen', () {
      // 155 liegt in Zone 2, 185 in Zone 4.
      final shares = ZoneDistribution.shares(
        [run(40, avgHeartRate: 155), run(20, avgHeartRate: 185)],
        zoning: zoning,
      );
      expect(total(shares), 60);
      expect(shares.where((s) => s.minutes > 0), hasLength(2));
      expect(shares.firstWhere((s) => s.zone == 2).minutes, 40);
      expect(shares.firstWhere((s) => s.zone == 4).minutes, 20);
    });
  });

  group('Die Zonengrenzen', () {
    test('ein Puls unter Zone 1 landet in Zone null', () {
      // Zone 1 beginnt bei 134.
      final shares =
          ZoneDistribution.shares([run(30, avgHeartRate: 90)], zoning: zoning);
      expect(shares.firstWhere((s) => s.zone == 0).minutes, 30);
    });

    test('ein Puls genau auf der Untergrenze gehört in diese Zone', () {
      // 148 ist zugleich Obergrenze von Zone 1 und Untergrenze von Zone 2 —
      // gewinnen muss Zone 2, wie in der Swift-Vorlage (höchste Zone, deren
      // Untergrenze erreicht ist).
      final shares =
          ZoneDistribution.shares([run(10, avgHeartRate: 148)], zoning: zoning);
      expect(shares.firstWhere((s) => s.zone == 2).minutes, 10);
    });

    test('ein Puls genau am Zonenanfang 134 ist Zone 1', () {
      final shares =
          ZoneDistribution.shares([run(10, avgHeartRate: 134)], zoning: zoning);
      expect(shares.firstWhere((s) => s.zone == 1).minutes, 10);
    });

    test('ein Puls über der HFmax bleibt Zone 5', () {
      final shares =
          ZoneDistribution.shares([run(5, avgHeartRate: 240)], zoning: zoning);
      expect(shares.firstWhere((s) => s.zone == 5).minutes, 5);
    });
  });

  group('Was nicht zählt', () {
    test('ein Lauf ohne Puls zählt gar nicht mit', () {
      // Als 0 bpm geführt sähe die Verteilung umso lockerer aus, je weniger
      // gemessen wurde (Swift-Vorlage, Review Focus 5).
      final shares = ZoneDistribution.shares(
        [run(30), run(30, avgHeartRate: 155)],
        zoning: zoning,
      );
      expect(total(shares), 30);
      expect(shares.firstWhere((s) => s.zone == 0).minutes, 0);
    });

    test('nur Läufe zählen, kein Krafttraining', () {
      final shares = ZoneDistribution.shares(
        [
          run(60, avgHeartRate: 120, kind: WorkoutKind.strength),
          run(30, avgHeartRate: 155),
        ],
        zoning: zoning,
      );
      expect(total(shares), 30);
    });

    test('auch Gehen und Radfahren zählen nicht', () {
      final shares = ZoneDistribution.shares(
        [
          run(45, avgHeartRate: 110, kind: WorkoutKind.walking),
          run(50, avgHeartRate: 140, kind: WorkoutKind.cycling),
        ],
        zoning: zoning,
      );
      expect(total(shares), 0);
    });
  });

  group('Die Form der Antwort', () {
    test('es gibt immer sechs Einträge, auch leere', () {
      final shares = ZoneDistribution.shares([], zoning: zoning);
      expect(shares, hasLength(6));
      expect(shares.map((s) => s.zone), [0, 1, 2, 3, 4, 5]);
      expect(total(shares), 0);
    });
  });

  group('Der lockere Anteil', () {
    test('sind Zone 1 und 2 zusammen', () {
      // 80 Minuten in Zone 2 (155), 20 Minuten in Zone 4 (190) → 0,8.
      final shares = ZoneDistribution.shares(
        [run(80, avgHeartRate: 155), run(20, avgHeartRate: 190)],
        zoning: zoning,
      );
      final easy = ZoneDistribution.easyShare(shares);
      expect(easy, isNotNull);
      expect(easy!, closeTo(0.8, 0.001));
    });

    test('ohne Läufe gibt es keinen Anteil — null, nicht 0', () {
      final shares = ZoneDistribution.shares([], zoning: zoning);
      expect(ZoneDistribution.easyShare(shares), isNull);
    });

    test('nur Zeit unter Zone 1 ergibt einen Anteil von 0', () {
      // Es wurde gelaufen, nur eben nicht in Zone 1–2: Das ist eine echte
      // Null, kein fehlender Wert.
      final shares =
          ZoneDistribution.shares([run(30, avgHeartRate: 90)], zoning: zoning);
      expect(ZoneDistribution.easyShare(shares), 0);
    });
  });

  group('Werttypen vergleichen nach Wert', () {
    test('zwei gleich gebaute ZoneShares sind gleich', () {
      const a = ZoneShare(zone: 2, minutes: 40);
      final b = ZoneShare(zone: 2, minutes: 40);
      expect(a == b, isTrue);
      expect(a.hashCode, b.hashCode);
      expect(a == ZoneShare(zone: 3, minutes: 40), isFalse);
    });

    test('zwei gleich gebaute WorkoutSamples sind gleich', () {
      const a = WorkoutSample(
        kind: WorkoutKind.running,
        minutes: 30,
        avgHeartRate: 150,
      );
      final b = WorkoutSample(
        kind: WorkoutKind.running,
        minutes: 30,
        avgHeartRate: 150,
      );
      expect(a == b, isTrue);
      expect(a.hashCode, b.hashCode);
      expect(
        a == WorkoutSample(kind: WorkoutKind.running, minutes: 30),
        isFalse,
      );
    });
  });
}
