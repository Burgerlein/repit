import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für **`UmfangsEingabe`** (#88, Task 1.2) — die reine Funktion
/// hinter einem der fünfzehn Zahlenfelder des Formulars „Maße eintragen":
/// **Eingabetext → Zentimeter oder Grund.**
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, nie verändert werden — sie legt fest, was
/// `Packages/trainings_core/lib/src/umfangs_eingabe.dart` zu leisten hat.
///
/// ## Woher die Festlegungen kommen
///
/// `docs/SPEC.md` 4.6 („leere Felder werden nicht gespeichert, unplausible
/// (außerhalb 10–200 cm) abgewiesen"), der Umsetzungsplan
/// `docs/superpowers/plans/2026-11-11-umfaenge.md` (Task 1.2) und die
/// Swift-Vorlage `CircumferenceInput.swift` samt
/// `CircumferenceInputTests.swift`.
///
/// ## Festgelegte öffentliche API
///
/// Neu in `Packages/trainings_core/lib/src/umfangs_eingabe.dart`,
/// exportiert über `lib/trainings_core.dart`:
///
/// ```dart
/// sealed class UmfangsEingabeErgebnis {
///   const UmfangsEingabeErgebnis();
/// }
///
/// /// Ein gültiger Wert in Zentimetern.
/// final class UmfangOk extends UmfangsEingabeErgebnis {
///   const UmfangOk(this.zentimeter);
///   final double zentimeter;
/// }
///
/// /// Das Feld ist leer — der Anfangszustand, kein Fehler.
/// final class UmfangLeer extends UmfangsEingabeErgebnis {
///   const UmfangLeer();
/// }
///
/// /// Da steht etwas, aber keine Zahl.
/// final class UmfangKeineZahl extends UmfangsEingabeErgebnis {
///   const UmfangKeineZahl();
/// }
///
/// /// Eine Zahl außerhalb von 10 bis 200 cm — sie kommt mit.
/// final class UmfangAusserhalb extends UmfangsEingabeErgebnis {
///   const UmfangAusserhalb(this.gelesen);
///   final double gelesen;
/// }
///
/// abstract final class UmfangsEingabe {
///   static const double minCm = 10.0;
///   static const double maxCm = 200.0;
///   static UmfangsEingabeErgebnis parse(String text);
/// }
/// ```
///
/// **Vier Fälle als vier Klassen, nicht als Grund-Enum.** `weight_input.dart`
/// ist das Vorbild für Stil und sealed-Ergebnis, weicht hier aber in einem
/// Punkt bewusst ab: Bei „außerhalb" kommt die **gelesene Zahl** mit, damit
/// die rote Zeile sagen kann, was dasteht. Als `(grund, double? gelesen)`
/// hätte der Typ wieder unsinnige Fälle (leer *mit* gelesener Zahl) — genau
/// das, wogegen `WeightInputResult` argumentiert. Also trägt der Fall, der
/// eine Zahl hat, sie selbst.
///
/// **Leer ist von „keine Zahl" getrennt**, wie beim Gewicht: Ein leeres Feld
/// ist der Anfangszustand von fünfzehn Feldern und bekommt keinen roten
/// Hinweis; ein Vertipper schon. Leere Felder werden nicht gespeichert.
///
/// **`parse` wirft nie** — ein halb getippter Wert ist hier der Normalfall.
///
/// ## Zwei Entscheidungen des Testautors
///
/// Beide sind gemeldet und können von Tim überstimmt werden:
///
/// 1. **Ein Minus ergibt „außerhalb", nicht „keine Zahl".** `WeightInput`
///    entscheidet das umgekehrt (`-58` → `notANumber`), die Swift-Vorlage
///    dieses Felds entscheidet es so (`validate("-5") == .outOfRange(-5)`).
///    Maßgeblich ist hier die Vorlage dieses Felds; der gelesene Wert in
///    der roten Zeile („−5 cm?") sagt mehr als „keine Zahl".
/// 2. **Zwei Nachkommastellen sind erlaubt.** `WeightInput` kennt dafür
///    einen eigenen Grund, `CircumferenceInput` nicht, und der Plan nennt
///    nur vier Fälle. Ein Maßband, von dem jemand 33,45 abliest, soll nicht
///    an der Form scheitern — die Anzeige rundet.
///
/// ## Erfundene Zahlen
///
/// Jeder Zentimeterwert in dieser Datei ist ausgedacht. Echte
/// Gesundheitswerte stehen nie im Quelltext (`CLAUDE.md`).
void main() {
  /// Kurzschreibweise für die beiden Fragen, die jeder Fall stellt.
  double? cmVon(String text) {
    final ergebnis = UmfangsEingabe.parse(text);
    return ergebnis is UmfangOk ? ergebnis.zentimeter : null;
  }

  void erwarteWert(String text, double cm) {
    final ergebnis = UmfangsEingabe.parse(text);
    expect(
      ergebnis,
      isA<UmfangOk>(),
      reason: '„$text" muss einen Wert ergeben, ergab aber $ergebnis',
    );
    expect(cmVon(text), closeTo(cm, 1e-9), reason: '„$text"');
  }

  void erwarteAusserhalb(String text, double gelesen) {
    final ergebnis = UmfangsEingabe.parse(text);
    expect(
      ergebnis,
      isA<UmfangAusserhalb>(),
      reason: '„$text" darf keinen Wert ergeben, ergab aber $ergebnis',
    );
    expect(
      (ergebnis as UmfangAusserhalb).gelesen,
      closeTo(gelesen, 1e-9),
      reason:
          'Die gelesene Zahl kommt mit, damit die rote Zeile sagen kann, '
          'was dasteht',
    );
  }

  group('Die Grenzen stehen als Konstanten da', () {
    test('10 und 200 Zentimeter, wie in der Spec', () {
      // Damit das Formular „10 bis 200 cm" schreiben kann, ohne die Zahlen
      // ein zweites Mal zu führen.
      expect(UmfangsEingabe.minCm, 10.0);
      expect(UmfangsEingabe.maxCm, 200.0);
    });
  });

  group('Komma und Punkt', () {
    test('das Komma ist die deutsche Schreibweise', () {
      erwarteWert('27,0', 27.0);
    });

    test('der Punkt kommt von der Zahlentastatur und zählt genauso', () {
      erwarteWert('27.0', 27.0);
    });

    test('beide ergeben denselben Wert', () {
      expect(
        cmVon('33,8'),
        cmVon('33.8'),
        reason:
            'Welche Taste die Tastatur gerade anbietet, darf am Maß nichts '
            'ändern',
      );
    });

    test('ohne Nachkommastelle geht auch', () {
      erwarteWert('27', 27.0);
    });

    test('eine Nachkommastelle ist der Normalfall am Maßband', () {
      erwarteWert('38,2', 38.2);
    });
  });

  group('Ein leeres Feld', () {
    test('der leere Text', () {
      expect(UmfangsEingabe.parse(''), isA<UmfangLeer>());
    });

    test('nur Leerzeichen ist genauso leer', () {
      expect(UmfangsEingabe.parse('   '), isA<UmfangLeer>());
    });

    test('leer ist nicht dasselbe wie Müll', () {
      // Fünfzehn Felder sind beim Öffnen leer. Wären sie damit fehlerhaft,
      // stünde der Schirm von Anfang an voller roter Zeilen.
      expect(
        UmfangsEingabe.parse(''),
        isNot(isA<UmfangKeineZahl>()),
        reason: 'Der Anfangszustand ist kein Vertipper',
      );
    });

    test('nur die Einheit ohne Zahl ist auch leer', () {
      // Wer „cm" stehen lässt und die Zahl löscht, hat nichts eingetragen.
      expect(UmfangsEingabe.parse('cm'), isA<UmfangLeer>());
      expect(UmfangsEingabe.parse(' cm '), isA<UmfangLeer>());
    });
  });

  group('Die Einheit und das Drumherum werden abgeschnitten', () {
    test('ein angehängtes cm', () {
      // Die Einheit steht schon neben dem Feld; wer sie mittippt, meint
      // dieselbe Zahl.
      erwarteWert('27 cm', 27.0);
    });

    test('auch ohne Leerzeichen davor', () {
      erwarteWert('27cm', 27.0);
    });

    test('auch in Großbuchstaben', () {
      erwarteWert('27 CM', 27.0);
    });

    test('Leerzeichen vorn und hinten', () {
      erwarteWert('  38,2  ', 38.2);
    });

    test('Leerzeichen und Einheit zusammen', () {
      erwarteWert(' 27 cm ', 27.0);
    });

    test('erst abschneiden, dann prüfen', () {
      // Sonst hinge der Grund daran, ob die Tastatur ein Leerzeichen
      // mitgeschickt hat.
      erwarteAusserhalb('  205 cm  ', 205.0);
    });
  });

  group('Was keine Zahl ist', () {
    test('Buchstaben', () {
      expect(UmfangsEingabe.parse('abc'), isA<UmfangKeineZahl>());
    });

    test('zwei Trennzeichen', () {
      // Ein Tippfehler, keine Zahl. Als 27,01 geraten stünde ein Wert im
      // Verlauf, den niemand gemessen hat.
      expect(UmfangsEingabe.parse('27.0.1'), isA<UmfangKeineZahl>());
      expect(UmfangsEingabe.parse('27,0,1'), isA<UmfangKeineZahl>());
    });

    test('ein Leerzeichen mitten in der Zahl', () {
      expect(UmfangsEingabe.parse('2 7'), isA<UmfangKeineZahl>());
    });

    test('ein Trennzeichen allein', () {
      expect(UmfangsEingabe.parse(','), isA<UmfangKeineZahl>());
    });

    test('eine Zahl mit einer fremden Einheit', () {
      expect(UmfangsEingabe.parse('27 Zoll'), isA<UmfangKeineZahl>());
    });
  });

  group('Die Grenzen schließen ein', () {
    test('10 cm ist erlaubt', () {
      erwarteWert('10', 10.0);
    });

    test('200 cm ist erlaubt', () {
      erwarteWert('200', 200.0);
    });

    test('9,9 liegt darunter', () {
      erwarteAusserhalb('9,9', 9.9);
    });

    test('200,1 liegt darüber', () {
      erwarteAusserhalb('200,1', 200.1);
    });

    test('0 ist kein Umfang', () {
      erwarteAusserhalb('0', 0.0);
    });

    test('ein vertipptes 382 statt 38,2 fällt durch', () {
      erwarteAusserhalb('382', 382.0);
    });

    test('ein Minus ergibt außerhalb, mit der gelesenen Zahl', () {
      // Entscheidung des Testautors, der Swift-Vorlage folgend — siehe
      // Dateikopf. `WeightInput` entscheidet das umgekehrt.
      erwarteAusserhalb('-5', -5.0);
    });
  });

  group('Mehr als eine Nachkommastelle', () {
    test('zwei Stellen werden angenommen', () {
      // Entscheidung des Testautors — siehe Dateikopf. Der Ergebnistyp
      // kennt keinen Grund „zu genau"; die Anzeige rundet.
      erwarteWert('33,45', 33.45);
    });
  });

  group('Der Ergebnistyp', () {
    test('`UmfangOk` trägt die Zahl und sonst nichts', () {
      final ergebnis = UmfangsEingabe.parse('38,2');
      expect(ergebnis, isA<UmfangOk>());
      expect((ergebnis as UmfangOk).zentimeter, closeTo(38.2, 1e-9));
    });

    test('`UmfangAusserhalb` trägt die gelesene Zahl', () {
      final ergebnis = UmfangsEingabe.parse('205');
      expect(ergebnis, isA<UmfangAusserhalb>());
      expect((ergebnis as UmfangAusserhalb).gelesen, closeTo(205.0, 1e-9));
    });

    // Ein `switch` über den sealed-Typ muss vollständig sein — käme ein
    // fünfter Fall dazu, zeigte der Analyzer auf jede Stelle, die ihn nicht
    // behandelt (`CLAUDE.md`, zu `Messwert<T>`). Dieser Fall hält fest,
    // dass es genau vier sind.
    test('vier Fälle, vollständig per `switch` erreichbar', () {
      String benenne(UmfangsEingabeErgebnis ergebnis) => switch (ergebnis) {
        UmfangOk(:final zentimeter) => 'ok $zentimeter',
        UmfangLeer() => 'leer',
        UmfangKeineZahl() => 'keine Zahl',
        UmfangAusserhalb(:final gelesen) => 'außerhalb $gelesen',
      };

      expect(benenne(UmfangsEingabe.parse('38,2')), 'ok 38.2');
      expect(benenne(UmfangsEingabe.parse('')), 'leer');
      expect(benenne(UmfangsEingabe.parse('abc')), 'keine Zahl');
      expect(benenne(UmfangsEingabe.parse('205')), 'außerhalb 205.0');
    });
  });
}
