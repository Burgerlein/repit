/// Körperfettschätzung aus Maßband-Werten, Formel für Männer nach
/// `docs/SPEC.md` 4.6 (#88, #475).
///
/// Verbindlich festgelegt durch
/// `Packages/trainings_core/test/navy_koerperfett_test.dart` (siehe dessen
/// Dateikopf) — diese Datei darf die Tests ausführen, aber nicht verändern
/// (`CLAUDE.md`, „Wer Tests schreibt, schreibt nicht die Implementierung").
///
/// **Das ist eine Schätzung, keine Diagnose.** Sie hat dieselbe Art Fehler
/// wie der Waagenwert, nur andere; wichtiger als die Zahl ist der Verlauf.
/// Benannt wird das in der Ansicht — der Kern trägt keine Nutzertexte.
///
/// Dart-Gegenstück zu
/// `Packages/TrainingsCore/Sources/TrainingsCore/Body/NavyBodyFat.swift`.
library;

import 'dart:math';

abstract final class NavyKoerperfett {
  /// Der geschätzte Körperfettanteil in Prozent, auf eine Nachkommastelle
  /// gerundet — oder `null`, wenn sich aus den Maßen keine sinnvolle Zahl
  /// ergibt.
  ///
  /// `null` und nicht `0` (`CLAUDE.md`: „`0` ist keine Antwort auf ‚kein
  /// Wert'"). Ein Ring auf 0 behauptete „kein Körperfett".
  ///
  /// Benannte Parameter, weil drei Maße in Zentimetern sonst in jeder
  /// Aufrufstelle vertauschbar wären.
  static double? prozent({
    required double tailleCm,
    required double halsCm,
    required double groesseCm,
  }) {
    // log10 von null ist −unendlich, von einer negativen Zahl NaN. Ein
    // Zahlendreher beim Eintragen reicht dafür aus, und auf dem Schirm stünde
    // „NaN %".
    if (tailleCm <= halsCm || groesseCm <= 0) return null;

    final teiler =
        1.0324 -
        0.19077 * _log10(tailleCm - halsCm) +
        0.15456 * _log10(groesseCm);
    if (teiler == 0) return null;

    final wert = 495 / teiler - 450;
    // Grenzen wie im Dashboard: über 2 und unter 50 Prozent. Außerhalb hat
    // sich jemand vermessen — abgefangen wird das Ergebnis, nicht die
    // Eingabe, denn jede der drei Zahlen kann für sich im erlaubten Bereich
    // des Felds liegen. Eine erfundene Zahl wäre schlimmer als keine.
    if (!wert.isFinite || wert <= 2 || wert >= 50) return null;

    return (wert * 10).round() / 10;
  }

  /// `dart:math` kennt nur den natürlichen Logarithmus; die Formel ist auf
  /// den Zehnerlogarithmus geschrieben.
  static double _log10(double x) => log(x) / ln10;
}
