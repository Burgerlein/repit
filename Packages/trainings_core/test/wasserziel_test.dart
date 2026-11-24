import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für das **Wasserziel** in
/// `Packages/trainings_core/lib/src/makroziele.dart` — Issue #408.
///
/// **Beobachtung (Tim, 07.11.2026):** 1,5 l seien zu wenig („soll man nicht
/// min. 2 trinken?").
///
/// **Vorgabe des Koordinators** (die Rückfrage an Tim wurde weggeklickt,
/// entschieden hat er es nicht):
///
/// ```
/// wasserMinMl = 35 ml · gewichtKg      bei brauchbarem Gewicht
/// wasserMinMl = 2000 ml                ohne brauchbares Gewicht
/// ```
///
/// Eine allgemeine Faustregel, keine Diagnose. Die Ansicht kennzeichnet das
/// Ziel als Schätzung (Fußtext in `app/lib/ernaehrung/ernaehrung_view.dart`);
/// der Kern rechnet nur.
///
/// Bisher war `wasserMinMl` ein festes Ziel von 1500 ml (SPEC 4.8). Die
/// Fälle dazu in `makroziele_test.dart`, `makroziele_kohlenhydrate_test.dart`
/// und `app/test/ernaehrung/ernaehrung_tag_test.dart` sind im selben Zug
/// umgestellt.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf **ausgeführt, nie verändert** werden.
///
/// ## API, die diese Tests verbindlich vorgeben
///
/// ```dart
/// class Makroziele {
///   /// In Millilitern. Bei brauchbarem Gewicht 35 ml je kg, sonst 2000.
///   final double wasserMinMl;
///   // … die übrigen Felder unverändert.
/// }
///
/// /// `const Makroziele()` trägt den Fall „kein Gewicht": 2000 ml.
/// const Makroziele();
///
/// Makroziele makrozieleFuer({
///   required double gewichtKg,
///   double? kalorienzielKcal,
/// });
/// ```
///
/// Keine neue Funktion, kein neues Feld: Das Wasserziel bleibt, wo es ist,
/// und hängt jetzt am Gewicht wie Eiweiß und Fett.
///
/// ## Entscheidungen des Test-Agenten, wo die Vorgabe Spielraum lässt
///
/// 1. **„Brauchbares Gewicht" heißt dasselbe wie bei Eiweiß und Fett:
///    `> 0`.** Ein Gewicht von 0 oder darunter ergibt 2000 ml, nicht 0 ml
///    — ein Ziel von 0 stünde sofort auf „erfüllt". Eine zweite, eigene
///    Grenze nur fürs Wasser hieße zwei Antworten auf die Frage „gibt es
///    ein Gewicht?".
/// 2. **Kein Mindestwert.** Die Vorgabe nennt 2 l nur für den Fall ohne
///    Gewicht. 50 kg ergeben deshalb 1750 ml, also **weniger** als der
///    Ersatzwert. Ob darunter eine Untergrenze gehört, ist nicht
///    entschieden; dieser Fall hält die Vorgabe wörtlich fest, damit eine
///    Untergrenze eine bewusste Änderung ist und keine stille.
/// 3. **Ungerundet.** Wie die übrigen Ziele: gerundet wird in der Ansicht
///    (`liter` in `wasser_bausteine.dart`, auf ganze 10 ml). 82,5 kg ergeben
///    2887,5 ml, nicht 2888 oder 2890.
/// 4. **Das Kalorienziel ändert das Wasserziel nicht.** Es hängt allein am
///    Gewicht.
///
/// ## Alle Zahlen hier sind erfunden
///
/// 50, 57, 70, 71 und 82,5 kg sind glatte Rechenwerte, nicht Tims Gewicht.
void main() {
  group('mit Gewicht: 35 ml je kg', () {
    test('70 kg ergeben 2450 ml', () {
      expect(makrozieleFuer(gewichtKg: 70).wasserMinMl, closeTo(2450, 1e-9));
    });

    test('82,5 kg ergeben 2887,5 ml, ungerundet', () {
      expect(
        makrozieleFuer(gewichtKg: 82.5).wasserMinMl,
        closeTo(2887.5, 1e-9),
      );
    });

    test('kein Mindestwert: 50 kg ergeben 1750 ml, nicht 2000', () {
      expect(makrozieleFuer(gewichtKg: 50).wasserMinMl, closeTo(1750, 1e-9));
    });

    test('ein kleines, aber positives Gewicht rechnet noch', () {
      expect(makrozieleFuer(gewichtKg: 0.5).wasserMinMl, closeTo(17.5, 1e-9));
    });

    test('ein anderes Gewicht ergibt ein anderes Wasserziel', () {
      expect(
        makrozieleFuer(gewichtKg: 70).wasserMinMl,
        isNot(makrozieleFuer(gewichtKg: 71).wasserMinMl),
      );
      expect(makrozieleFuer(gewichtKg: 71).wasserMinMl, closeTo(2485, 1e-9));
    });

    test('das Kalorienziel ändert es nicht', () {
      final ohne = makrozieleFuer(gewichtKg: 57);
      final mit = makrozieleFuer(gewichtKg: 57, kalorienzielKcal: 2600);

      expect(ohne.wasserMinMl, closeTo(1995, 1e-9));
      expect(mit.wasserMinMl, closeTo(1995, 1e-9));
    });
  });

  group('ohne brauchbares Gewicht: 2000 ml', () {
    test('0 und negative Gewichte ergeben 2000 ml, nie 0', () {
      for (final gewicht in <double>[0, -1, -70]) {
        expect(
          makrozieleFuer(gewichtKg: gewicht).wasserMinMl,
          closeTo(2000, 1e-9),
          reason: '$gewicht kg',
        );
      }
    });

    test('auch mit Kalorienziel', () {
      expect(
        makrozieleFuer(gewichtKg: 0, kalorienzielKcal: 2400).wasserMinMl,
        closeTo(2000, 1e-9),
      );
    });

    test('const Makroziele() trägt denselben Ersatzwert', () {
      expect(const Makroziele().wasserMinMl, closeTo(2000, 1e-9));
    });
  });

  test('das Wasserziel geht in die Wertgleichheit ein', () {
    // Zwei Ziele, die sich nur im Wasser unterscheiden, sind ungleich —
    // sonst rechnete ein Provider nicht neu, wenn sich nur das Wasserziel
    // ändert.
    const a = Makroziele(wasserMinMl: 2000);
    const b = Makroziele(wasserMinMl: 2450);

    expect(a, isNot(b));
    expect(a, const Makroziele(wasserMinMl: 2000));
    expect(a.hashCode, const Makroziele(wasserMinMl: 2000).hashCode);
  });
}
