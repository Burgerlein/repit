import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für `Packages/trainings_core/lib/src/makroziele.dart` — Task 2 des
/// Umsetzungsplans `docs/superpowers/plans/2026-11-03-ernaehrung.md`, Spec
/// `docs/SPEC.md` 4.8: „Makros mit Zielen: Eiweiß 1,6–2,0 g/kg, Fett
/// ≥ 0,8 g/kg, Ballaststoffe ≥ 30 g, Zucker ≤ 50 g, gesättigte Fette
/// ≤ 25 g, Wasser ≥ 1,5 l."
///
/// **Seit #408 hängt das Wasserziel am Gewicht** (35 ml je kg, ohne Gewicht
/// 2000 ml; Tims Meldung vom 07.11.2026, Vorgabe des Koordinators). Die
/// Fälle dazu stehen in `test/wasserziel_test.dart`; hier sind nur die
/// Stellen umgestellt, die 1500 festschrieben.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf **ausgeführt, nie verändert** werden.
///
/// ## API, die diese Tests verbindlich vorgeben
///
/// ```dart
/// class Makroziele {
///   /// Die drei gewichtsabhängigen Ziele. `null`, wenn kein brauchbares
///   /// Gewicht vorliegt — nie `0`.
///   final double? eiweissMinG;
///   final double? eiweissMaxG;
///   final double? fettMinG;
///
///   /// Die vier festen Ziele aus `docs/SPEC.md` 4.8.
///   final double ballaststoffeMinG; // 30
///   final double zuckerMaxG;        // 50
///   final double gesaettigtMaxG;    // 25
///   final double wasserMinMl;       // seit #408: 35 ml/kg, sonst 2000
///
///   // Wertgleichheit: == und hashCode.
/// }
///
/// Makroziele makrozieleFuer({required double gewichtKg});
/// ```
///
/// ## Entscheidungen des Test-Agenten, wo die Spec Spielraum lässt
///
/// 1. **Eiweiß ist ein Bereich, keine Zahl.** „1,6–2,0 g/kg" wird als
///    `eiweissMinG`/`eiweissMaxG` abgebildet, nicht als ein gemittelter
///    Zielwert. Eine Mitte (1,8) wäre eine Zahl, die in der Spec nicht
///    steht, und der Schirm zeigt einen Bereich.
/// 2. **Die Werte sind ungerundete `double`.** Gerundet wird in der
///    Ansicht. Der Kern rechnet; zwei Rundungen an zwei Stellen gäben
///    später zwei verschiedene Eiweißziele.
/// 3. **Kein brauchbares Gewicht → `null` für die drei abhängigen Ziele**,
///    die vier festen stehen weiter. Die Grenze ist `<= 0`, wie bei
///    [ProteinTarget.grams] — „Ob ein Gewicht als Körpergewicht taugt,
///    entscheidet nicht der Kern — er rechnet." `0.0 g Eiweiß` wäre ein
///    Ziel, das niemand gesetzt hat, und der Ring stünde auf „erfüllt".
/// 4. **Wasser steht in Millilitern**, wie überall sonst im Kanal; „1,5 l"
///    sind 1500.
///
/// ## Verhältnis zu [ProteinTarget]
///
/// `ProteinTarget.grams` gibt es im Kern schon (`body_trend.dart`, Ticket
/// #202) — auf **ganze Gramm gerundet**, für die Körper-Ansicht. Beide
/// müssen dieselben Faktoren benutzen; ein eigener Faktor hier hieße zwei
/// Eiweißziele in einer App. Der letzte Fall unten nagelt das fest.
///
/// ## Alle Zahlen hier sind erfunden
///
/// 70,0 kg und 82,5 kg sind glatte Rechenwerte, nicht Tims Gewicht.
void main() {
  group('gewichtsabhängige Ziele', () {
    test('70 kg: Eiweiß 112 bis 140 g, Fett mindestens 56 g', () {
      final ziele = makrozieleFuer(gewichtKg: 70);

      expect(ziele.eiweissMinG, closeTo(112, 1e-9));
      expect(ziele.eiweissMaxG, closeTo(140, 1e-9));
      expect(ziele.fettMinG, closeTo(56, 1e-9));
    });

    test('82,5 kg: Eiweiß 132 bis 165 g, Fett mindestens 66 g', () {
      final ziele = makrozieleFuer(gewichtKg: 82.5);

      expect(ziele.eiweissMinG, closeTo(132, 1e-9));
      expect(ziele.eiweissMaxG, closeTo(165, 1e-9));
      expect(ziele.fettMinG, closeTo(66, 1e-9));
    });

    test('die Obergrenze liegt über der Untergrenze', () {
      final ziele = makrozieleFuer(gewichtKg: 70);

      expect(ziele.eiweissMaxG!, greaterThan(ziele.eiweissMinG!));
    });
  });

  group('feste Ziele', () {
    test('Ballaststoffe, Zucker, gesättigte Fette, Wasser', () {
      final ziele = makrozieleFuer(gewichtKg: 70);

      expect(ziele.ballaststoffeMinG, closeTo(30, 1e-9));
      expect(ziele.zuckerMaxG, closeTo(50, 1e-9));
      expect(ziele.gesaettigtMaxG, closeTo(25, 1e-9));
      // #408: 35 ml je kg — Wasser ist kein festes Ziel mehr.
      expect(ziele.wasserMinMl, closeTo(2450, 1e-9));
    });

    test('sie hängen nicht am Gewicht', () {
      final leicht = makrozieleFuer(gewichtKg: 55);
      final schwer = makrozieleFuer(gewichtKg: 95);

      expect(leicht.ballaststoffeMinG, schwer.ballaststoffeMinG);
      expect(leicht.zuckerMaxG, schwer.zuckerMaxG);
      expect(leicht.gesaettigtMaxG, schwer.gesaettigtMaxG);
      // Wasser hängt seit #408 am Gewicht, siehe `wasserziel_test.dart`.
    });
  });

  group('ohne brauchbares Gewicht', () {
    test('die abhängigen Ziele fehlen, statt 0 zu sein', () {
      for (final gewicht in <double>[0, -1, -70]) {
        final ziele = makrozieleFuer(gewichtKg: gewicht);

        expect(ziele.eiweissMinG, isNull, reason: '$gewicht kg');
        expect(ziele.eiweissMaxG, isNull, reason: '$gewicht kg');
        expect(ziele.fettMinG, isNull, reason: '$gewicht kg');
      }
    });

    test('die festen Ziele stehen trotzdem', () {
      final ziele = makrozieleFuer(gewichtKg: 0);

      expect(ziele.ballaststoffeMinG, closeTo(30, 1e-9));
      expect(ziele.zuckerMaxG, closeTo(50, 1e-9));
      expect(ziele.gesaettigtMaxG, closeTo(25, 1e-9));
      // #408: ohne Gewicht 2 l.
      expect(ziele.wasserMinMl, closeTo(2000, 1e-9));
    });
  });

  group('Wertgleichheit', () {
    test('gleiches Gewicht ergibt gleiche Ziele mit gleichem hashCode', () {
      final a = makrozieleFuer(gewichtKg: 70);
      final b = makrozieleFuer(gewichtKg: 70);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('ein anderes Gewicht ergibt andere Ziele', () {
      expect(makrozieleFuer(gewichtKg: 70), isNot(makrozieleFuer(gewichtKg: 71)));
    });
  });

  test('das Eiweißziel deckt sich mit ProteinTarget aus body_trend.dart', () {
    // 70,3 kg, weil dort beide Grenzen einzeln gerundet werden müssen:
    // 112,48 → 112 und 140,6 → 141. Wer einmal rundet und die zweite Zahl
    // ableitet, trifft eine der beiden nicht (siehe ProteinTarget).
    final ziele = makrozieleFuer(gewichtKg: 70.3);
    final (low, high) = ProteinTarget.grams(70.3)!;

    expect(ziele.eiweissMinG!.round(), low);
    expect(ziele.eiweissMaxG!.round(), high);
  });
}
