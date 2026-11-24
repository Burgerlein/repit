import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für **`NavyKoerperfett`** (#88, Task 1.5) — die
/// Körperfettschätzung aus Maßband-Werten, Formel für Männer nach
/// `docs/SPEC.md` 4.6:
///
/// ```
/// 495 / (1,0324 − 0,19077·log10(Taille − Hals) + 0,15456·log10(Größe)) − 450
/// ```
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, nie verändert werden — sie legt fest, was
/// `Packages/trainings_core/lib/src/navy_koerperfett.dart` zu leisten hat.
///
/// **Das ist eine Schätzung, keine Diagnose** (`CLAUDE.md`, und die Global
/// Constraints des Plans). Sie hat dieselbe Art Fehler wie der Waagenwert,
/// nur andere; wichtiger als die Zahl ist der Verlauf. Benannt wird das in
/// der Ansicht — der Kern trägt keine Nutzertexte.
///
/// ## Festgelegte öffentliche API
///
/// Neu in `Packages/trainings_core/lib/src/navy_koerperfett.dart`,
/// exportiert über `lib/trainings_core.dart`:
///
/// ```dart
/// abstract final class NavyKoerperfett {
///   /// Der geschätzte Körperfettanteil in Prozent, auf eine
///   /// Nachkommastelle gerundet — oder `null`, wenn sich aus den Maßen
///   /// keine sinnvolle Zahl ergibt.
///   static double? prozent({
///     required double tailleCm,
///     required double halsCm,
///     required double groesseCm,
///   });
/// }
/// ```
///
/// Eine Klasse mit statischer Methode und keine freie Funktion — wie
/// `WeightInput`, `BerlinCalendar` und die übrigen Rechnungen des Kerns.
/// Benannte Parameter, weil drei Maße in Zentimetern sonst in jeder
/// Aufrufstelle vertauschbar wären.
///
/// **`null` und nicht `0`** (`CLAUDE.md`: „`0` ist keine Antwort auf ‚kein
/// Wert'"). Ein Ring auf 0 behauptete „kein Körperfett".
///
/// ## Erfundene Zahlen
///
/// Jeder Wert in dieser Datei ist ausgedacht. Echte Gesundheitswerte
/// stehen nie im Quelltext (`CLAUDE.md`).
void main() {
  double? prozent(double taille, double hals, double groesse) =>
      NavyKoerperfett.prozent(
        tailleCm: taille,
        halsCm: hals,
        groesseCm: groesse,
      );

  group('Die Formel aus SPEC 4.6', () {
    test('Taille 79,0 · Hals 37,5 · Größe 182 ergibt 11,3 Prozent', () {
      // 495 / (1,0324 − 0,19077·log10(41,5) + 0,15456·log10(182)) − 450
      // = 495 / 1,073037 − 450 = 11,3055…
      //
      // Der Prototyp schreibt an dieser Stelle 15,6 %. Diese Zahl folgt
      // nicht aus der Formel — sie ist dort von Hand eingetragen.
      // Maßgeblich ist die Formel aus SPEC 4.6, nicht die Beschriftung im
      // Entwurf.
      expect(prozent(79.0, 37.5, 182), closeTo(11.3, 0.05));
    });

    test('ein zweiter Satz Maße ergibt 19,8 Prozent', () {
      // Nachgerechnet aus derselben Formel — ein zweiter Stützpunkt, damit
      // ein vertauschter Summand nicht zufällig durchkommt.
      expect(prozent(90.0, 37.5, 182), closeTo(19.8, 0.05));
    });

    test('eine dickere Taille ergibt mehr Fett', () {
      final schmal = prozent(75, 37.5, 182)!;
      final breit = prozent(90, 37.5, 182)!;
      expect(breit, greaterThan(schmal));
    });

    test('ein dickerer Hals ergibt weniger Fett', () {
      // Der Hals steht für die fettfreie Masse; die Formel liest ihn als
      // Gegengewicht zur Taille.
      final duenn = prozent(85, 36.0, 182)!;
      final dick = prozent(85, 40.0, 182)!;
      expect(dick, lessThan(duenn));
    });
  });

  group('Was keine Zahl ergibt', () {
    test('Taille gleich Hals', () {
      // log10(0) ist −unendlich. Ohne diese Abfrage stünde „NaN %" auf dem
      // Schirm.
      expect(prozent(37.5, 37.5, 182), isNull);
    });

    test('Taille kleiner als Hals', () {
      // log10 einer negativen Zahl ist NaN. Ein Zahlendreher beim
      // Eintragen reicht dafür aus.
      expect(prozent(30, 37.5, 182), isNull);
    });

    test('Größe null', () {
      expect(prozent(79, 37.5, 0), isNull);
    });

    test('Größe negativ', () {
      expect(prozent(79, 37.5, -182), isNull);
    });

    test('ein Ergebnis unter 2 Prozent gilt als Unsinn', () {
      // Taille nur 0,1 cm über dem Hals: log10(0,1) ist −1, der Teiler
      // wächst auf rund 1,573, und heraus kommen etwa −135 Prozent. Die
      // Formel rechnet weiter, das Ergebnis ist trotzdem Unsinn — und eine
      // erfundene Zahl wäre schlimmer als keine.
      expect(prozent(37.6, 37.5, 182), isNull);
    });

    test('ein Ergebnis über 50 Prozent gilt als Unsinn', () {
      // 200 cm Taille, 30 cm Hals, 100 cm Größe: rechnerisch rund 90
      // Prozent. Jede der drei Zahlen liegt für sich im erlaubten Bereich
      // des Eingabefelds — abgefangen wird hier das Ergebnis, nicht die
      // Eingabe.
      expect(prozent(200, 30, 100), isNull);
    });
  });

  group('Die Form des Ergebnisses', () {
    test('auf eine Nachkommastelle gerundet', () {
      final wert = prozent(79.0, 37.5, 182)!;
      expect(wert, (wert * 10).round() / 10);
    });

    test('genau eine Nachkommastelle, nicht abgeschnitten', () {
      // 11,3055… wird zu 11,3 gerundet und nicht auf 11,3 abgeschnitten —
      // bei diesem Wert dasselbe, bei 11,36 nicht. Der Fall hält fest,
      // dass gerundet wird.
      expect(prozent(79.0, 37.5, 182), 11.3);
    });

    test('derselbe Satz Maße ergibt immer dieselbe Zahl', () {
      expect(prozent(82.4, 39.1, 182), prozent(82.4, 39.1, 182));
    });
  });
}
