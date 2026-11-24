/// Die Prüfung hinter einem der fünfzehn Zahlenfelder des Formulars „Maße
/// eintragen" (#88, #475): Eingabetext rein, Zentimeter oder Grund raus.
///
/// Verbindlich festgelegt durch
/// `Packages/trainings_core/test/umfangs_eingabe_test.dart` (siehe dessen
/// Dateikopf) — diese Datei darf die Tests ausführen, aber nicht verändern
/// (`CLAUDE.md`, „Wer Tests schreibt, schreibt nicht die Implementierung").
///
/// Gebaut wie `weight_input.dart`: eine Rechnung, keine Oberfläche. Was der
/// Nutzer von einem Grund zu lesen bekommt, entscheidet der Schirm — der Kern
/// trägt keine Nutzertexte.
///
/// Dart-Gegenstück zu
/// `Packages/TrainingsCore/Sources/TrainingsCore/Body/CircumferenceInput.swift`.
library;

/// Das Ergebnis der Prüfung — ein Wert oder ein Grund.
///
/// Vier Klassen und kein `(grund, double? gelesen)`: Als Paar hätte der Typ
/// unsinnige Fälle (leer *mit* gelesener Zahl). Also trägt der eine Fall, der
/// eine Zahl hat, sie selbst — dasselbe Argument wie bei `WeightInputResult`
/// und `Messwert<T>`.
sealed class UmfangsEingabeErgebnis {
  const UmfangsEingabeErgebnis();
}

/// Ein gültiger Wert in Zentimetern.
final class UmfangOk extends UmfangsEingabeErgebnis {
  const UmfangOk(this.zentimeter);

  final double zentimeter;
}

/// Das Feld ist leer — der Anfangszustand von fünfzehn Feldern, kein Fehler.
///
/// Von [UmfangKeineZahl] getrennt, weil der Schirm sonst beim Öffnen voller
/// roter Zeilen stünde. Leere Felder werden nicht gespeichert.
final class UmfangLeer extends UmfangsEingabeErgebnis {
  const UmfangLeer();
}

/// Da steht etwas, aber keine Zahl.
final class UmfangKeineZahl extends UmfangsEingabeErgebnis {
  const UmfangKeineZahl();
}

/// Eine Zahl außerhalb von [UmfangsEingabe.minCm] bis
/// [UmfangsEingabe.maxCm].
///
/// Die gelesene Zahl kommt mit, damit die rote Zeile sagen kann, was dasteht.
final class UmfangAusserhalb extends UmfangsEingabeErgebnis {
  const UmfangAusserhalb(this.gelesen);

  final double gelesen;
}

abstract final class UmfangsEingabe {
  /// Die untere Grenze, **einschließlich**. Unter 10 cm misst niemand einen
  /// Körperteil.
  static const double minCm = 10.0;

  /// Die obere Grenze, ebenfalls einschließlich.
  static const double maxCm = 200.0;

  /// Liest einen Umfang in Zentimetern aus [text].
  ///
  /// Wirft nie: Ein halb getippter Wert ist hier der Normalfall und keine
  /// Ausnahme.
  static UmfangsEingabeErgebnis parse(String text) {
    // Erst abschneiden, dann prüfen. Sonst hinge der Grund daran, ob die
    // Tastatur ein Leerzeichen mitgeschickt hat.
    var gekuerzt = text.trim();

    // Die Einheit steht schon neben dem Feld; wer sie mittippt, meint
    // dieselbe Zahl. Wer nur sie stehen lässt, hat nichts eingetragen.
    if (gekuerzt.toLowerCase().endsWith('cm')) {
      gekuerzt = gekuerzt.substring(0, gekuerzt.length - 2).trim();
    }
    if (gekuerzt.isEmpty) return const UmfangLeer();

    // Die deutsche Tastatur liefert ein Komma, `double.tryParse('27,0')`
    // ergibt null. Zwei Trennzeichen bleiben ungültig: „27.0.1" lässt sich
    // nicht lesen, und als 27,01 geraten stünde ein Wert im Verlauf, den
    // niemand gemessen hat.
    final zahl = double.tryParse(gekuerzt.replaceAll(',', '.'));
    // `isFinite` fängt „Infinity" und „NaN" ab — `double.tryParse` liest
    // beide klaglos, ein Umfang ist keins von beidem.
    if (zahl == null || !zahl.isFinite) return const UmfangKeineZahl();

    if (zahl < minCm || zahl > maxCm) return UmfangAusserhalb(zahl);
    return UmfangOk(zahl);
  }
}
