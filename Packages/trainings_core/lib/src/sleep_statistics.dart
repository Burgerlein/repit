import 'dart:math';

/// Was mehrere Nächte über ihre Uhrzeiten sagen — die eine Rechnung daran,
/// die eine Rechnung ist.
///
/// **Warum nur das Mittel hier liegt und nicht die ganze Statistik.**
/// Ø Schlafdauer, Ø Einschlafzeit, Ø Aufwachzeit und die Phasenanteile
/// brauchen `SleepSegment`, und das ist ein Transporttyp des Kanals, der
/// nach `CLAUDE.md` ausdrücklich nicht in den Kern gehört. Die
/// Zusammensetzung steht deshalb in `app/lib/shell/schlaf_zustand.dart`;
/// hierher gehört nur die Formel aus `docs/SPEC.md` 4.6 (Z. 236–246), und
/// die braucht nichts als `dart:math`.
///
/// Die Swift-Vorlage `TrainingsCore/Sleep/SleepStatistics.swift` kann beides
/// zusammenlegen, weil `SleepSession` dort im selben Paket liegt. In Dart
/// tut es das nicht.
abstract final class SleepStatistics {
  /// Eine volle Umdrehung in Minuten.
  static const double fullTurn = 1440;

  /// Ab dieser Länge der Vektorsumme gilt ein Mittel als bestimmt.
  ///
  /// Klein, aber nicht null: Drei gleichmäßig über den Kreis verteilte
  /// Zeiten ergeben in `double` nicht exakt 0, sondern eine Restlänge in
  /// der Größenordnung von 1e-16. Zu groß gewählt verschluckte die
  /// Schwelle echte Mittel — zwei Zeiten knapp neben „genau gegenüber"
  /// haben eines.
  static const double resultantFloor = 1e-9;

  /// Das zirkuläre Mittel von Uhrzeiten, in Minuten auf derselben Skala wie
  /// die Eingabe. `null`, wenn es keines gibt.
  ///
  /// Jede Zeit wird als Winkel auf dem 24-Stunden-Kreis gelesen, die
  /// Einheitsvektoren werden addiert und das Ergebnis zurückgerechnet. Ein
  /// gewöhnlicher Durchschnitt reicht nicht: 23:00 und 01:00 mitteln sich
  /// so auf Mitternacht und nicht auf den Mittag.
  ///
  /// **Die Skala darf ins Negative gehen** — `EveningClock` liefert für
  /// 17:50 den Wert −10, und auf dem Kreis ist das dieselbe Richtung wie
  /// 1430. Werte jenseits einer vollen Umdrehung zählen wie ihr Rest.
  ///
  /// **Das Ergebnis liegt immer in `[0, fullTurn)`**, damit nicht jeder
  /// Aufrufer dieselbe Normalisierung noch einmal schreiben muss.
  ///
  /// `null` heißt „es gibt keines", nicht „null Uhr": Liegen die Zeiten
  /// gleichmäßig über den Kreis verteilt oder genau gegenüber, zeigt die
  /// Vektorsumme ins Nichts. In der Ansicht steht dann ein Gedankenstrich
  /// und keine erfundene Uhrzeit (`docs/SPEC.md` 4.6).
  static double? circularMeanMinutes(List<double> values) {
    if (values.isEmpty) return null;

    var x = 0.0;
    var y = 0.0;
    for (final value in values) {
      final winkel = value / fullTurn * 2 * pi;
      x += cos(winkel);
      y += sin(winkel);
    }
    x /= values.length;
    y /= values.length;

    if (sqrt(x * x + y * y) < resultantFloor) return null;

    final minuten = atan2(y, x) / (2 * pi) * fullTurn;
    var imKreis = minuten % fullTurn;
    if (imKreis < 0) imKreis += fullTurn;
    // `(-1e-20) % 1440` rundet auf glatte 1440 auf — eine volle Umdrehung
    // ist aber dieselbe Richtung wie null und gehört nicht ins Ergebnis.
    if (imKreis >= fullTurn) imKreis -= fullTurn;
    return imKreis;
  }
}
