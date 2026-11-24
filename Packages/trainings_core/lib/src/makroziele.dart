/// Die Makro-Tagesziele aus `docs/SPEC.md` 4.8: „Eiweiß 1,6–2,0 g/kg, Fett
/// ≥ 0,8 g/kg, Ballaststoffe ≥ 30 g, Zucker ≤ 50 g, gesättigte Fette
/// ≤ 25 g." Wasser seit #408 (Tim, 07.11.2026): 35 ml je kg Körpergewicht,
/// ohne Gewicht 2 l — eine allgemeine Faustregel, keine Empfehlung.
///
/// Vier Ziele hängen am Körpergewicht (Eiweiß, Fett, Kohlenhydrate über das
/// Budget, Wasser), drei nicht. **Eiweiß ist ein
/// Bereich, keine Zahl** — eine gemittelte 1,8 stünde in keiner Spec, und
/// der Schirm zeigt einen Bereich.
///
/// Für **Kohlenhydrate nennt die Spec kein Ziel**; [kohlenhydrateZielG] wird
/// deshalb aus dem Kalorienziel gerechnet (Issue #310).
///
/// Die Werte sind ungerundete `double`. Gerundet wird in der Ansicht; zwei
/// Rundungen an zwei Stellen gäben später zwei verschiedene Eiweißziele.
///
/// Werttyp mit [==] und [hashCode], weil er Abhängigkeit eines Providers
/// ist (`CLAUDE.md`, Fehler `03`).
class Makroziele {
  const Makroziele({
    this.eiweissMinG,
    this.eiweissMaxG,
    this.fettMinG,
    this.kohlenhydrateZielG,
    this.ballaststoffeMinG = 30,
    this.zuckerMaxG = 50,
    this.gesaettigtMaxG = 25,
    this.wasserMinMl = _wasserOhneGewichtMl,
  });

  /// Untergrenze des Eiweißziels. `null`, wenn kein brauchbares Gewicht
  /// vorliegt — **nie** `0`: Ein Ziel von 0 g stünde sofort auf „erfüllt".
  final double? eiweissMinG;

  /// Obergrenze des Eiweißziels. `null` wie [eiweissMinG].
  final double? eiweissMaxG;

  /// Mindest-Fettzufuhr. `null` wie [eiweissMinG].
  final double? fettMinG;

  /// Das aus dem Kalorienziel gerechnete Kohlenhydratziel, siehe
  /// [makrozieleFuer]. `null`, wenn es nicht gebildet werden kann — nie `0`
  /// und nie negativ, aus demselben Grund wie [eiweissMinG].
  final double? kohlenhydrateZielG;

  final double ballaststoffeMinG;
  final double zuckerMaxG;
  final double gesaettigtMaxG;

  /// In Millilitern, wie überall sonst im Kanal: „2 l" sind 2000.
  final double wasserMinMl;

  @override
  bool operator ==(Object other) =>
      other is Makroziele &&
      other.eiweissMinG == eiweissMinG &&
      other.eiweissMaxG == eiweissMaxG &&
      other.fettMinG == fettMinG &&
      other.kohlenhydrateZielG == kohlenhydrateZielG &&
      other.ballaststoffeMinG == ballaststoffeMinG &&
      other.zuckerMaxG == zuckerMaxG &&
      other.gesaettigtMaxG == gesaettigtMaxG &&
      other.wasserMinMl == wasserMinMl;

  @override
  int get hashCode => Object.hash(
    eiweissMinG,
    eiweissMaxG,
    fettMinG,
    kohlenhydrateZielG,
    ballaststoffeMinG,
    zuckerMaxG,
    gesaettigtMaxG,
    wasserMinMl,
  );

  @override
  String toString() =>
      'Makroziele(eiweissMinG: $eiweissMinG, eiweissMaxG: $eiweissMaxG, '
      'fettMinG: $fettMinG, kohlenhydrateZielG: $kohlenhydrateZielG, '
      'ballaststoffeMinG: $ballaststoffeMinG, '
      'zuckerMaxG: $zuckerMaxG, gesaettigtMaxG: $gesaettigtMaxG, '
      'wasserMinMl: $wasserMinMl)';
}

/// Gramm Eiweiß je Kilogramm Körpergewicht, untere Grenze. **Dieselbe Zahl
/// benutzt `ProteinTarget.grams` in `body_trend.dart`** (Ticket #202) — ein
/// eigener Faktor hier hieße zwei Eiweißziele in einer App. Dass beide
/// übereinstimmen, prüft `test/makroziele_test.dart`; der Compiler erzwingt
/// es nicht.
const double _eiweissJeKgMin = 1.6;

/// Obere Grenze, siehe [_eiweissJeKgMin].
const double _eiweissJeKgMax = 2.0;

/// Mindest-Fett je Kilogramm Körpergewicht.
const double _fettJeKgMin = 0.8;

/// Wasserziel je Kilogramm Körpergewicht (#408).
const double _wasserJeKgMl = 35;

/// Wasserziel, solange kein brauchbares Gewicht vorliegt (#408).
const double _wasserOhneGewichtMl = 2000;

/// Brennwerte je Gramm, die Atwater-Faktoren.
const double _kcalJeGrammEiweiss = 4;
const double _kcalJeGrammFett = 9;
const double _kcalJeGrammKohlenhydrat = 4;

/// Die Tagesziele zu einem Körpergewicht.
///
/// Ist [gewichtKg] nicht positiv, fehlen die drei abhängigen Ziele
/// (`null`); die festen stehen weiter, Wasser fällt auf 2 l zurück. Die Grenze ist `<= 0`, nicht
/// „unplausibel klein" — wie bei `ProteinTarget.grams`: Ob ein Gewicht als
/// Körpergewicht taugt, entscheidet nicht der Kern, er rechnet.
///
/// Liegt ein [kalorienzielKcal] vor, bleibt das Kohlenhydratziel als Rest
/// des Budgets, nachdem die **Mindestmengen** Eiweiß und Fett abgezogen
/// sind:
///
/// ```
/// kohlenhydrateZielG = (kalorienzielKcal − eiweissMinG · 4 − fettMinG · 9) / 4
/// ```
///
/// Ohne Kalorienziel, ohne brauchbares Gewicht und wenn die beiden
/// Mindestmengen mehr binden als das Budget hergibt, fehlt es (`null`) —
/// eine negative Grammzahl ist keine Auskunft.
Makroziele makrozieleFuer({
  required double gewichtKg,
  double? kalorienzielKcal,
}) {
  if (gewichtKg <= 0) return const Makroziele();

  final eiweissMinG = gewichtKg * _eiweissJeKgMin;
  final fettMinG = gewichtKg * _fettJeKgMin;

  double? kohlenhydrateZielG;
  if (kalorienzielKcal != null) {
    final rest =
        (kalorienzielKcal -
            eiweissMinG * _kcalJeGrammEiweiss -
            fettMinG * _kcalJeGrammFett) /
        _kcalJeGrammKohlenhydrat;
    if (rest > 0) kohlenhydrateZielG = rest;
  }

  return Makroziele(
    eiweissMinG: eiweissMinG,
    eiweissMaxG: gewichtKg * _eiweissJeKgMax,
    fettMinG: fettMinG,
    kohlenhydrateZielG: kohlenhydrateZielG,
    wasserMinMl: gewichtKg * _wasserJeKgMl,
  );
}
