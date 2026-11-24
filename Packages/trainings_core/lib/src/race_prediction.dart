/// HM-Prognose über die Daniels-VDOT-Tabelle aus SPEC 4.7.
///
/// Dart-Gegenstück zu
/// `Packages/TrainingsCore/Sources/TrainingsCore/Endurance/RacePrediction.swift`
/// — die Doppelung Swift/Dart ist Absicht (`CLAUDE.md`, „Die Doppelung ist
/// Absicht").
abstract final class RacePrediction {
  /// VDOT auf Halbmarathon-Minuten nach Jack Daniels, SPEC 4.7.
  static const List<(double vdot, double minutes)> _table = [
    (30, 141.1),
    (32, 133.8),
    (34, 127.3),
    (36, 121.3),
    (38, 115.9),
    (40, 111.0),
    (42, 106.5),
    (44, 102.3),
    (46, 98.5),
    (48, 94.9),
    (50, 91.6),
    (52, 88.6),
    (54, 85.8),
    (56, 83.2),
    (58, 80.7),
    (60, 78.4),
  ];

  /// Die Laufökonomie macht bei Einsteigern einen großen Unterschied — die
  /// zweite, ehrlichere Zahl neben dem Potenzial.
  static const double beginnerFactor = 1.12;

  /// Theoretisches Potenzial in Minuten. Zwischen den Stützstellen der
  /// Tabelle wird linear interpoliert; **außerhalb gelten die Randwerte**:
  /// Eine fortgesetzte Gerade ergäbe irgendwann negative Laufzeiten, und
  /// belegt ist die Tabelle dort ohnehin nicht.
  static double halfMarathonMinutes({required double vdot}) {
    final first = _table.first;
    final last = _table.last;
    if (vdot <= first.$1) return first.$2;
    if (vdot >= last.$1) return last.$2;

    for (var i = 1; i < _table.length; i++) {
      final low = _table[i - 1];
      final high = _table[i];
      if (vdot <= high.$1) {
        final share = (vdot - low.$1) / (high.$1 - low.$1);
        return low.$2 + share * (high.$2 - low.$2);
      }
    }
    return last.$2;
  }

  /// Potenzial × [beginnerFactor].
  static double realisticMinutes({required double vdot}) =>
      halfMarathonMinutes(vdot: vdot) * beginnerFactor;
}
