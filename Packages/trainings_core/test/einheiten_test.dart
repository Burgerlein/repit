import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für `Packages/trainings_core/lib/src/einheiten.dart` — Task 2 des
/// Umsetzungsplans `docs/superpowers/plans/2026-11-03-ernaehrung.md`, Spec
/// `docs/SPEC.md` 4.8 („g/ml auf 5 bzw. 1 runden, Stück/EL/TL auf 0,5") und
/// `docs/superpowers/specs/2026-11-03-ernaehrung-design.md`, Abschnitt
/// „Einheiten und Gramm".
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf **ausgeführt, nie verändert** werden.
///
/// ## API, die diese Tests verbindlich vorgeben
///
/// ```dart
/// const Map<String, double> haushaltsmasse = {
///   'EL': 15, 'TL': 5, 'Prise': 0.5, 'Tasse': 240, 'Glas': 200,
/// };
///
/// /// Wie viel Gramm [menge] in [einheit] sind. `null`, wenn es dafür
/// /// keinen Faktor gibt.
/// double? inGramm(double menge, String einheit, Map<String, double> portionen);
///
/// /// Eine Portionsgröße auf ein anzeigbares Maß runden.
/// double rundePortion(double wert, String einheit);
/// ```
///
/// ## Woher ein Faktor kommt — und wann es keinen gibt
///
/// * **`g` und `ml` sind der Maßstab selbst.** Jede Rechnung geht über
///   Gramm; ein Milliliter zählt dabei 1:1 als Gramm. Das ist für Wasser
///   richtig und für Öl falsch — aber es ist die Annahme, die jede
///   Nährwerttabelle trifft, und sie steht hier an genau einer Stelle,
///   statt in jedem Rezept neu.
/// * **Haushaltsmaße liegen global.** EL, TL, Prise, Tasse und Glas sind vom
///   Lebensmittel unabhängig.
/// * **„Stück" liegt am Lebensmittel**, in [portionen]. „Eine Zwiebel ist
///   kein Ei; ein globaler Faktor wäre hier frei erfunden." Ohne Eintrag
///   gibt es deshalb `null` — **nicht** einen geratenen Wert und **nicht**
///   `0`. `0` hieße „wiegt nichts" und zöge sich durch jede Nährwertsumme.
/// * **Die Tabelle des Lebensmittels sticht die globale.** Ein gestrichener
///   Esslöffel Erdnussmus wiegt nicht 15 g; wer das am Lebensmittel
///   hinterlegt, meint es so. *(Entscheidung des Test-Agenten — die Spec
///   lässt den Fall offen.)*
/// * **Eine Zutat ohne Gramm-Äquivalent ist erlaubt.** `null` ist ein
///   gültiges Ergebnis, kein Fehler: Die Zutat wird angelegt, ihre
///   Nährwerte bleiben unbekannt.
///
/// ## Die Rundung
///
/// `g` auf 5, `ml` auf 1, alles andere auf 0,5. Dass **alles andere** auf
/// 0,5 fällt, ist eine Entscheidung des Test-Agenten: Die Spec nennt
/// „Stück/EL/TL", und Prise, Tasse, Glas sowie jede selbst eingetippte
/// Einheit („Bund") verhalten sich genauso — halbe Schritte sind das
/// gröbste Maß, das bei kleinen Zahlen noch etwas aussagt.
///
/// Gerundet wird **kaufmännisch von der Null weg** (Dart `num.round()`):
/// 2,5 ⁠g → 5 g, nicht 0 g. Und es gibt **keinen Boden**: 2 g runden auf
/// 0 g. Das ist die Rundung der Anzeige, nicht die Menge, mit der gerechnet
/// wird — ein Boden würde eine Zahl behaupten, die niemand eingegeben hat.
///
/// ## Alle Zahlen hier sind erfunden
void main() {
  group('haushaltsmasse', () {
    test('die fünf Maße aus dem Entwurf, und nur diese', () {
      expect(haushaltsmasse, {
        'EL': 15.0,
        'TL': 5.0,
        'Prise': 0.5,
        'Tasse': 240.0,
        'Glas': 200.0,
      });
    });

    test('„Stück" steht nicht darin', () {
      expect(haushaltsmasse.containsKey('Stück'), isFalse);
    });
  });

  group('inGramm', () {
    test('Gramm sind Gramm', () {
      expect(inGramm(180, 'g', {}), closeTo(180, 1e-9));
      expect(inGramm(0, 'g', {}), closeTo(0, 1e-9));
    });

    test('Milliliter zählen 1:1 als Gramm', () {
      expect(inGramm(200, 'ml', {}), closeTo(200, 1e-9));
    });

    test('die Haushaltsmaße gelten ohne Zutun des Lebensmittels', () {
      expect(inGramm(2, 'EL', {}), closeTo(30, 1e-9));
      expect(inGramm(3, 'TL', {}), closeTo(15, 1e-9));
      expect(inGramm(3, 'Prise', {}), closeTo(1.5, 1e-9));
      expect(inGramm(1.5, 'Tasse', {}), closeTo(360, 1e-9));
      expect(inGramm(2, 'Glas', {}), closeTo(400, 1e-9));
    });

    test('„Stück" ohne Angabe am Lebensmittel hat keinen Faktor', () {
      expect(inGramm(2, 'Stück', {}), isNull);
    });

    test('„Stück" mit Angabe am Lebensmittel rechnet', () {
      expect(inGramm(2, 'Stück', {'Stück': 60}), closeTo(120, 1e-9));
    });

    test('eine unbekannte Einheit hat keinen Faktor — und ist nicht null', () {
      expect(inGramm(2, 'Bund', {}), isNull);
      expect(inGramm(1, 'Dose', {'Stück': 60}), isNull);
    });

    test('die Tabelle des Lebensmittels sticht die globale', () {
      expect(inGramm(1, 'EL', {'EL': 20}), closeTo(20, 1e-9));
    });

    test('eine fremde Portionsangabe stört die globale Tabelle nicht', () {
      expect(inGramm(2, 'EL', {'Stück': 60}), closeTo(30, 1e-9));
    });
  });

  group('rundePortion', () {
    test('Gramm runden auf 5', () {
      expect(rundePortion(123.0, 'g'), closeTo(125, 1e-9));
      expect(rundePortion(122.0, 'g'), closeTo(120, 1e-9));
      expect(rundePortion(0, 'g'), closeTo(0, 1e-9));
    });

    test('Milliliter runden auf 1', () {
      expect(rundePortion(123.4, 'ml'), closeTo(123, 1e-9));
      expect(rundePortion(249.6, 'ml'), closeTo(250, 1e-9));
    });

    test('Stück, EL und TL runden auf 0,5', () {
      expect(rundePortion(1.3, 'EL'), closeTo(1.5, 1e-9));
      expect(rundePortion(1.1, 'TL'), closeTo(1, 1e-9));
      expect(rundePortion(2.8, 'Stück'), closeTo(3, 1e-9));
    });

    test('jede andere Einheit rundet ebenfalls auf 0,5', () {
      expect(rundePortion(0.7, 'Prise'), closeTo(0.5, 1e-9));
      expect(rundePortion(1.3, 'Bund'), closeTo(1.5, 1e-9));
      expect(rundePortion(2.2, 'Tasse'), closeTo(2, 1e-9));
    });

    test('die halbe Stufe geht von der Null weg', () {
      expect(rundePortion(2.5, 'g'), closeTo(5, 1e-9));
      expect(rundePortion(1.25, 'EL'), closeTo(1.5, 1e-9));
      expect(rundePortion(0.5, 'ml'), closeTo(1, 1e-9));
    });

    test('kleine Grammzahlen runden auf 0 — es gibt keinen Boden', () {
      expect(rundePortion(2.0, 'g'), closeTo(0, 1e-9));
      expect(rundePortion(3.0, 'g'), closeTo(5, 1e-9));
    });

    test('eine bereits runde Zahl bleibt, wie sie ist', () {
      expect(rundePortion(125.0, 'g'), closeTo(125, 1e-9));
      expect(rundePortion(2.0, 'EL'), closeTo(2, 1e-9));
      expect(rundePortion(250.0, 'ml'), closeTo(250, 1e-9));
    });
  });
}
