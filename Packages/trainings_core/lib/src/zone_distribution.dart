/// Verteilung der Laufzeit nach Herzfrequenz-Zonen, SPEC 4.7
/// („Ziel ≥ 80 % in Zone 1–2").
///
/// Dart-Gegenstück zu
/// `Packages/TrainingsCore/Sources/TrainingsCore/Endurance/ZoneDistribution.swift`
/// — die Doppelung Swift/Dart ist Absicht (`CLAUDE.md`, „Die Doppelung ist
/// Absicht").
library;

import 'heart_rate_zones.dart';

/// Die Workout-Arten, die der Kanal unterscheidet — dieselben sieben Fälle
/// wie `WorkoutKind` in Swifts `HealthTypes.swift`, damit die beiden
/// Fassungen deckungsgleich bleiben.
enum WorkoutKind { running, walking, cycling, strength, swimming, soccer, other }

/// Ein Workout mit genau den Feldern, die diese Rechnung braucht — schlank
/// wie `RecoveryDay` (`recovery_input.dart`): Der Kern bekommt eigene Typen,
/// die App bildet ihre Kanal-Typen darauf ab.
///
/// `avgHeartRate == null` heißt „kein Puls gemessen", nie Null.
class WorkoutSample {
  const WorkoutSample({
    required this.kind,
    required this.minutes,
    this.avgHeartRate,
  });

  final WorkoutKind kind;
  final double minutes;
  final int? avgHeartRate;

  // == und hashCode nach Wert.
  @override
  bool operator ==(Object other) =>
      other is WorkoutSample &&
      other.kind == kind &&
      other.minutes == minutes &&
      other.avgHeartRate == avgHeartRate;

  @override
  int get hashCode => Object.hash(kind, minutes, avgHeartRate);

  @override
  String toString() =>
      'WorkoutSample(kind: $kind, minutes: $minutes, '
      'avgHeartRate: $avgHeartRate)';
}

/// Die Laufzeit einer Zone. `zone == 0` bedeutet „unter Zone 1".
class ZoneShare {
  const ZoneShare({required this.zone, required this.minutes});

  final int zone;
  final double minutes;

  // == und hashCode nach Wert.
  @override
  bool operator ==(Object other) =>
      other is ZoneShare && other.zone == zone && other.minutes == minutes;

  @override
  int get hashCode => Object.hash(zone, minutes);

  @override
  String toString() => 'ZoneShare(zone: $zone, minutes: $minutes)';
}

abstract final class ZoneDistribution {
  /// Immer sechs Einträge, Zone 0 bis 5, auch leere.
  ///
  /// Gezählt wird die Laufzeit nach dem Ø-Puls jedes Laufs. Das ist eine
  /// Näherung — ein Intervalltraining mit Ø 150 lag nie durchgehend bei 150;
  /// die Beschriftung muss das sagen.
  ///
  /// Läufe ohne Ø-Puls zählen **nicht** mit. Sie als 0 bpm zu führen hieße,
  /// sie in „unter Zone 1" zu stecken: Die Verteilung sähe umso lockerer
  /// aus, je weniger gemessen wurde. Ein Puls auf einer Zonen-Untergrenze
  /// gehört zu dieser Zone.
  static List<ZoneShare> shares(
    List<WorkoutSample> workouts, {
    required HeartRateZoning zoning,
  }) {
    final minutes = <int, double>{};
    for (final workout in workouts) {
      if (workout.kind != WorkoutKind.running) continue;
      final heartRate = workout.avgHeartRate;
      if (heartRate == null) continue;
      final zone = _zoneOf(heartRate, zoning);
      minutes[zone] = (minutes[zone] ?? 0) + workout.minutes;
    }
    return [
      for (var zone = 0; zone <= 5; zone++)
        ZoneShare(zone: zone, minutes: minutes[zone] ?? 0),
    ];
  }

  /// Die höchste Zone, deren Untergrenze erreicht ist — 0 unter Zone 1.
  static int _zoneOf(int heartRate, HeartRateZoning zoning) {
    for (final zone in zoning.zones.reversed) {
      if (heartRate >= zone.lower) return zone.number;
    }
    return 0;
  }

  /// Anteil der Laufzeit in Zone 1 und 2 zusammen (Ziel ≥ 80 %),
  /// `null` ohne gezählte Laufzeit.
  static double? easyShare(List<ZoneShare> shares) {
    var total = 0.0;
    var easy = 0.0;
    for (final share in shares) {
      total += share.minutes;
      if (share.zone == 1 || share.zone == 2) easy += share.minutes;
    }
    if (total <= 0) return null;
    return easy / total;
  }
}
