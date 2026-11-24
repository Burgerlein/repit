import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Die reine Funktion hinter dem Feld „Kilogramm" im Blatt „Gewicht
/// eintragen" (#270): **Eingabetext → Gewicht in kg oder Fehlergrund.**
///
/// Grundlage ist
/// `docs/superpowers/specs/2026-11-03-gewicht-eintragen-design.md`,
/// Abschnitt „Das Blatt": „30,0 bis 300,0; Komma **und** Punkt werden
/// angenommen; höchstens eine Nachkommastelle" — und der Entwurf
/// `docs/screens/screens/gewicht-eintragen.js` („30 bis 300 kg, mit Komma
/// oder Punkt").
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung**
/// (`CLAUDE.md`). Diese Datei darf ausgeführt, nie verändert werden.
///
/// ## Warum im Kern und nicht im Blatt
///
/// Es ist eine Rechnung: Text rein, Zahl oder Grund raus, ohne Mock, ohne
/// Flutter, ohne Kanal. `CLAUDE.md`: „Jede Formel aus `docs/SPEC.md`
/// bekommt einen Test, und zwar **im Kern**." Die Spec listet sie
/// ausdrücklich unter `Packages/trainings_core` auf („Hier liegen ihre
/// Tests"). Daraus folgt auch, dass hier **keine Nutzertexte** entstehen:
/// Der Kern liefert einen Grund als Enum-Fall, den Satz dazu schreibt das
/// Blatt.
///
/// ## Festgelegte öffentliche API
///
/// Neu in `Packages/trainings_core/lib/src/weight_input.dart`, exportiert
/// über `lib/trainings_core.dart`:
///
/// ```dart
/// /// Warum ein Eingabetext kein Gewicht ergibt.
/// enum WeightInputError { empty, notANumber, tooManyDecimals, outOfRange }
///
/// /// Das Ergebnis der Prüfung — entweder ein Gewicht oder ein Grund.
/// sealed class WeightInputResult {
///   const WeightInputResult();
/// }
///
/// final class WeightOk extends WeightInputResult {
///   const WeightOk(double kg);
///   final double kg;
/// }
///
/// final class WeightRejected extends WeightInputResult {
///   const WeightRejected(WeightInputError reason);
///   final WeightInputError reason;
/// }
///
/// abstract final class WeightInput {
///   /// Die untere Grenze, **einschließlich** (Spec: „30,0 bis 300,0").
///   static const double minKg = 30.0;
///
///   /// Die obere Grenze, ebenfalls einschließlich.
///   static const double maxKg = 300.0;
///
///   static WeightInputResult parse(String text);
/// }
/// ```
///
/// **Ein sealed-Typ, kein nullbares Paar.** Ein `(double?, Fehler?)` hat
/// zwei unsinnige Fälle (beides gesetzt, beides leer); der sealed-Typ hat
/// sie nicht, und ein `switch` darüber ist vollständig prüfbar — dasselbe
/// Argument wie bei `Messwert<T>` (`CLAUDE.md`).
///
/// **Die Grenzen stehen als Konstanten da**, damit das Blatt „30 bis 300
/// kg" schreiben kann, ohne die Zahlen ein zweites Mal zu führen. Zwei
/// Stellen, die dieselbe Grenze behaupten, laufen irgendwann auseinander.
///
/// **`parse` wirft nie.** Der Name folgt der Lesart „aus Text lesen", nicht
/// Darts `int.parse`-Vertrag: Ein abgelehnter Text ist hier der Normalfall
/// (jeder halb getippte Wert ist einer) und keine Ausnahme. Der Rückgabetyp
/// sagt das Nötige.
///
/// ## Was hier **nicht** entschieden wird
///
/// - **Das Datumsfeld.** „nicht in der Zukunft; nicht vor
///   `earliestPermittedDate`" prüft das Blatt gegen Uhr und Quelle — beides
///   kennt der Kern nicht.
/// - **Wann „Sichern" aktiv ist.** Das ist eine Aussage über den Knopf und
///   steht in `app/test/shell/gewicht_eintragen_test.dart`. Hier steht nur,
///   welcher Text welches Ergebnis hat.
///
/// ## Erfundene Zahlen
///
/// Jedes Gewicht in dieser Datei ist ausgedacht. Echte Gesundheitswerte
/// stehen nie im Quelltext (`CLAUDE.md`).
void main() {
  /// Kurzschreibweise für die beiden Fragen, die jeder Fall stellt.
  double? kgVon(String text) {
    final ergebnis = WeightInput.parse(text);
    return ergebnis is WeightOk ? ergebnis.kg : null;
  }

  WeightInputError? grundVon(String text) {
    final ergebnis = WeightInput.parse(text);
    return ergebnis is WeightRejected ? ergebnis.reason : null;
  }

  void erwarteGewicht(String text, double kg) {
    expect(
      kgVon(text),
      isNotNull,
      reason: '„$text" muss ein Gewicht ergeben, kein ${grundVon(text)}',
    );
    expect(kgVon(text), closeTo(kg, 1e-9), reason: '„$text"');
  }

  void erwarteGrund(String text, WeightInputError grund) {
    expect(
      grundVon(text),
      isNotNull,
      reason: '„$text" darf kein Gewicht ergeben, ergab aber ${kgVon(text)}',
    );
    expect(grundVon(text), grund, reason: '„$text"');
  }

  group('Die Grenzen stehen als Konstanten da', () {
    test('30,0 und 300,0, wie in der Spec', () {
      expect(WeightInput.minKg, 30.0);
      expect(WeightInput.maxKg, 300.0);
    });
  });

  group('Komma und Punkt', () {
    test('das Komma ist die deutsche Schreibweise', () {
      erwarteGewicht('58,4', 58.4);
    });

    test('der Punkt kommt von der Zahlentastatur und zählt genauso', () {
      erwarteGewicht('58.4', 58.4);
    });

    test('ohne Nachkommastelle geht auch', () {
      erwarteGewicht('58', 58.0);
    });

    test('beide ergeben denselben Wert', () {
      expect(
        kgVon('58,4'),
        kgVon('58.4'),
        reason:
            'Welche Taste die Tastatur gerade anbietet, darf am Gewicht '
            'nichts ändern',
      );
    });
  });

  group('Die Grenzen schließen ein', () {
    test('30,0 ist erlaubt', () {
      erwarteGewicht('30,0', 30.0);
    });

    test('30 ohne Nachkommastelle ebenso', () {
      erwarteGewicht('30', 30.0);
    });

    test('300,0 ist erlaubt', () {
      erwarteGewicht('300,0', 300.0);
    });

    test('300 ohne Nachkommastelle ebenso', () {
      erwarteGewicht('300', 300.0);
    });

    test('29,9 liegt darunter', () {
      erwarteGrund('29,9', WeightInputError.outOfRange);
    });

    test('300,1 liegt darüber', () {
      erwarteGrund('300,1', WeightInputError.outOfRange);
    });

    test('0 ist kein Gewicht', () {
      erwarteGrund('0', WeightInputError.outOfRange);
    });

    // Der Entwurf nennt genau diesen Fall als Grund für den Platzhalter:
    // „ein vertipptes 584 fällt damit sofort auf".
    test('ein vertipptes 584 fällt durch', () {
      erwarteGrund('584', WeightInputError.outOfRange);
    });
  });

  group('Höchstens eine Nachkommastelle', () {
    test('zwei sind zu viele, mit Komma', () {
      erwarteGrund('58,45', WeightInputError.tooManyDecimals);
    });

    test('zwei sind zu viele, mit Punkt', () {
      erwarteGrund('58.45', WeightInputError.tooManyDecimals);
    });

    test('drei erst recht', () {
      erwarteGrund('58,456', WeightInputError.tooManyDecimals);
    });

    // Die Stelle hinter dem Komma zählt, auch wenn sie 0 ist: „58,45" ist
    // nicht dasselbe wie „58,4" plus Rundung, und eine Waage, die zwei
    // Stellen zeigt, soll nicht stillschweigend gekürzt werden. Der Grund
    // sagt, was zu tun ist; er wirft den Wert nicht weg.
    test('die zweite Stelle wird nicht stillschweigend gerundet', () {
      expect(
        kgVon('58,45'),
        isNull,
        reason:
            'Ein gerundeter Wert wäre eine Zahl, die der Nutzer nicht '
            'eingetippt hat — und niemand sähe es',
      );
    });

    test('eine Nachkommastelle 0 ist in Ordnung', () {
      erwarteGewicht('58,0', 58.0);
    });
  });

  group('Leer', () {
    test('der leere Text', () {
      erwarteGrund('', WeightInputError.empty);
    });

    test('nur Leerzeichen ist genauso leer', () {
      erwarteGrund('   ', WeightInputError.empty);
    });

    // Der Unterschied trägt: „leer" ist der Anfangszustand des Feldes und
    // bekommt keinen Hinweis, „keine Zahl" ist ein Vertipper und darf
    // einen bekommen. Ein gemeinsamer Grund für beides zwänge das Blatt,
    // den Anfangszustand als Fehler zu behandeln.
    test('leer ist nicht dasselbe wie Müll', () {
      expect(grundVon(''), isNot(grundVon('xyz')));
    });
  });

  group('Müll', () {
    test('Buchstaben', () {
      erwarteGrund('abc', WeightInputError.notANumber);
    });

    test('Zahl mit Einheit — die Einheit steht im Feldnamen', () {
      erwarteGrund('58,4 kg', WeightInputError.notANumber);
    });

    test('ein Leerzeichen mitten in der Zahl', () {
      erwarteGrund('5 8', WeightInputError.notANumber);
    });

    test('zwei Trennzeichen', () {
      erwarteGrund('58,4,5', WeightInputError.notANumber);
    });

    test('ein Trennzeichen ohne Ziffer davor', () {
      erwarteGrund(',4', WeightInputError.notANumber);
    });

    test('nur ein Trennzeichen', () {
      erwarteGrund(',', WeightInputError.notANumber);
    });
  });

  group('Führende und folgende Leerzeichen', () {
    test('vorn', () {
      erwarteGewicht('  58,4', 58.4);
    });

    test('hinten', () {
      erwarteGewicht('58,4  ', 58.4);
    });

    test('beidseitig', () {
      erwarteGewicht('  58,4  ', 58.4);
    });

    test('auch um einen Wert außerhalb der Grenzen herum', () {
      expect(
        grundVon('  584  '),
        WeightInputError.outOfRange,
        reason:
            'Erst abschneiden, dann prüfen — sonst hinge der Grund daran, '
            'ob die Tastatur ein Leerzeichen mitgeschickt hat',
      );
    });
  });

  group('Minus', () {
    // **Entscheidung des Testautors, nicht aus der Spec** (die schweigt
    // dazu): Ein Minus macht den Text zu **keiner Zahl**, nicht zu einer
    // Zahl außerhalb der Grenzen. Ein Gewicht hat kein Vorzeichen — „−58"
    // ist kein zu leichter Mensch, sondern ein Vertipper. Und die
    // Unterscheidung trägt im Blatt: „außerhalb der Grenzen" lädt dazu
    // ein, „30 bis 300 kg" danebenzuschreiben, was hier keine Hilfe wäre.
    test('ein Minus ist kein Vorzeichen, sondern ein Vertipper', () {
      erwarteGrund('-58,4', WeightInputError.notANumber);
    });

    test('auch vor einem Wert, der ohne Minus gültig wäre', () {
      erwarteGrund('-58', WeightInputError.notANumber);
    });

    test('ein Minus allein', () {
      erwarteGrund('-', WeightInputError.notANumber);
    });
  });

  group('Der Ergebnistyp', () {
    test('`WeightOk` trägt die Zahl und sonst nichts', () {
      final ergebnis = WeightInput.parse('58,4');
      expect(ergebnis, isA<WeightOk>());
      expect((ergebnis as WeightOk).kg, closeTo(58.4, 1e-9));
    });

    test('`WeightRejected` trägt den Grund', () {
      final ergebnis = WeightInput.parse('abc');
      expect(ergebnis, isA<WeightRejected>());
      expect((ergebnis as WeightRejected).reason, WeightInputError.notANumber);
    });

    // Ein `switch` über den sealed-Typ muss vollständig sein — käme ein
    // dritter Fall dazu, zeigte der Analyzer auf jede Stelle, die ihn
    // nicht behandelt (`CLAUDE.md`, zu `Messwert<T>`). Dieser Fall hält
    // fest, dass es genau zwei sind.
    test('zwei Fälle, vollständig per `switch` erreichbar', () {
      String benenne(WeightInputResult ergebnis) => switch (ergebnis) {
        WeightOk(:final kg) => 'ok $kg',
        WeightRejected(:final reason) => 'nein $reason',
      };

      expect(benenne(WeightInput.parse('58,4')), startsWith('ok '));
      expect(benenne(WeightInput.parse('')), startsWith('nein '));
    });
  });
}
