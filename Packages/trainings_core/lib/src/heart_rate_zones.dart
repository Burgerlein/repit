/// Herzfrequenz-Zonen über die Herzfrequenzreserve (Karvonen), SPEC 4.7.
/// Schätzung, kein Labortest.
///
/// Dart-Gegenstück zu
/// `Packages/TrainingsCore/Sources/TrainingsCore/Plan/HeartRateZones.swift`
/// — die Doppelung Swift/Dart ist Absicht (`CLAUDE.md`, „Die Doppelung ist
/// Absicht").
library;

/// Eine Zone, Grenzen in bpm, kaufmännisch gerundet.
class HeartRateZone {
  const HeartRateZone({
    required this.number,
    required this.lower,
    required this.upper,
  });

  final int number;
  final int lower;
  final int upper;

  // == und hashCode nach Wert — Werttypen, die Provider-Abhängigkeit werden,
  // brauchen beides (`CLAUDE.md`, Datenschicht).
  @override
  bool operator ==(Object other) =>
      other is HeartRateZone &&
      other.number == number &&
      other.lower == lower &&
      other.upper == upper;

  @override
  int get hashCode => Object.hash(number, lower, upper);

  @override
  String toString() =>
      'HeartRateZone(number: $number, lower: $lower, upper: $upper)';
}

/// Das Ergebnis der Zonenrechnung: fünf Zonen und die Auskunft, ob geklemmt
/// werden musste.
class HeartRateZoning {
  const HeartRateZoning({required this.zones, required this.clamped});

  final List<HeartRateZone> zones;

  /// true, wenn der Ruhepuls zu nah an der HFmax lag und geklemmt werden
  /// musste. Die Oberfläche muss das benennen, sonst sehen unbrauchbare
  /// Zonen völlig plausibel aus.
  final bool clamped;

  // == und hashCode nach Wert, die Zonenliste elementweise.
  @override
  bool operator ==(Object other) {
    if (other is! HeartRateZoning) return false;
    if (other.clamped != clamped) return false;
    if (other.zones.length != zones.length) return false;
    for (var i = 0; i < zones.length; i++) {
      if (other.zones[i] != zones[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(clamped, Object.hashAll(zones));

  @override
  String toString() => 'HeartRateZoning(zones: $zones, clamped: $clamped)';
}

/// Zonen nach Karvonen: Grenze = Ruhepuls + Reserve · Anteil, Zone *n* von
/// (n+4)/10 bis (n+5)/10.
abstract final class HeartRateZones {
  /// Mindestabstand zwischen Ruhepuls und HFmax, damit die Zonen bei
  /// Fehleingaben nicht invertieren.
  static const int minimumReserve = 20;

  static HeartRateZoning zoning({required int hrMax, required int hrRest}) {
    final safeRest = hrRest < hrMax - minimumReserve
        ? hrRest
        : hrMax - minimumReserve;
    final reserve = (hrMax - safeRest).toDouble();

    int bound(double fraction) => (safeRest + reserve * fraction).round();

    final zones = [
      for (var number = 1; number <= 5; number++)
        HeartRateZone(
          number: number,
          lower: bound((number + 4) / 10),
          upper: bound((number + 5) / 10),
        ),
    ];
    return HeartRateZoning(zones: zones, clamped: safeRest != hrRest);
  }
}
