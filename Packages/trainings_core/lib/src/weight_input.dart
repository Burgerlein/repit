/// Die Prüfung hinter dem Feld „Kilogramm" im Blatt „Gewicht eintragen"
/// (#270): Eingabetext rein, Gewicht oder Grund raus.
///
/// Verbindlich festgelegt durch
/// `Packages/trainings_core/test/weight_input_test.dart` (siehe dessen
/// Dateikopf) — diese Datei darf die Tests ausführen, aber nicht verändern
/// (`CLAUDE.md`, „Wer Tests schreibt, schreibt nicht die Implementierung").
///
/// Sie liegt im Kern, weil sie eine Rechnung ist und keine Oberfläche: kein
/// Flutter, kein Kanal, keine Uhr. Was der Nutzer von einem Grund zu lesen
/// bekommt, entscheidet das Blatt — der Kern trägt keine Nutzertexte.
library;

/// Warum ein Eingabetext kein Gewicht ergibt.
///
/// [empty] ist bewusst von [notANumber] getrennt: Ein leeres Feld ist der
/// Anfangszustand und kein Vertipper, und das Blatt soll den Unterschied
/// aussprechen können. „Zu klein" und „zu groß" sind umgekehrt bewusst
/// **ein** Grund — der Entwurf hat dafür einen Hinweissatz, nicht zwei.
enum WeightInputError { empty, notANumber, tooManyDecimals, outOfRange }

/// Das Ergebnis der Prüfung — entweder ein Gewicht oder ein Grund.
///
/// Ein sealed-Typ und kein nullbares Paar: `(double?, WeightInputError?)`
/// hätte zwei unsinnige Fälle (beides gesetzt, beides leer), dieser hat sie
/// nicht, und ein `switch` darüber ist vollständig prüfbar — dasselbe
/// Argument wie bei `Messwert<T>`.
sealed class WeightInputResult {
  const WeightInputResult();
}

final class WeightOk extends WeightInputResult {
  const WeightOk(this.kg);

  final double kg;
}

final class WeightRejected extends WeightInputResult {
  const WeightRejected(this.reason);

  final WeightInputError reason;
}

abstract final class WeightInput {
  /// Die untere Grenze, **einschließlich**.
  static const double minKg = 30.0;

  /// Die obere Grenze, ebenfalls einschließlich.
  static const double maxKg = 300.0;

  /// Ziffern, höchstens ein Trennzeichen, mindestens eine Ziffer davor.
  ///
  /// Kein Vorzeichen: Ein Gewicht hat keins, und ein führendes Minus ist
  /// deshalb ein Vertipper — [WeightInputError.notANumber], nicht
  /// [WeightInputError.outOfRange].
  static final RegExp _zahl = RegExp(r'^\d+([.,]\d+)?$');

  /// Liest ein Gewicht in Kilogramm aus [text].
  ///
  /// Wirft nie. Der Name folgt der Lesart „aus Text lesen", nicht Darts
  /// `int.parse`-Vertrag: Ein abgelehnter Text ist hier der Normalfall —
  /// jeder halb getippte Wert ist einer — und keine Ausnahme.
  static WeightInputResult parse(String text) {
    // Erst abschneiden, dann prüfen. Sonst hinge der Grund daran, ob die
    // Tastatur ein Leerzeichen mitgeschickt hat.
    final gekuerzt = text.trim();
    if (gekuerzt.isEmpty) {
      return const WeightRejected(WeightInputError.empty);
    }
    if (!_zahl.hasMatch(gekuerzt)) {
      return const WeightRejected(WeightInputError.notANumber);
    }

    // Die Reihenfolge trägt: Erst die Form der Zahl, dann ihr Wert. „58,45"
    // ist zu genau, nicht zu groß, und der Hinweis dazu lautet anders.
    final trennstelle = gekuerzt.indexOf(RegExp(r'[.,]'));
    if (trennstelle >= 0 && gekuerzt.length - trennstelle - 1 > 1) {
      return const WeightRejected(WeightInputError.tooManyDecimals);
    }

    final kg = double.parse(gekuerzt.replaceFirst(',', '.'));
    if (kg < minKg || kg > maxKg) {
      return const WeightRejected(WeightInputError.outOfRange);
    }
    return WeightOk(kg);
  }
}
