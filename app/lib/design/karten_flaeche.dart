import 'package:flutter/cupertino.dart';

import 'palette.dart';

/// Der Eckenradius jeder Karte in der App.
///
/// **Tims Entscheidung vom 05.11.2026 (#384):** Alle Karten sehen aus wie
/// auf Home — Grundfarbe `surface`, Radius 17, kein Rand, kein Schatten.
/// Vorher trug `InsetCard` Radius 10 und 1 pt Rand in `line`, die Kacheln
/// und die Home-Karten (#376) Radius 17 ohne Rand; zwei Formen für
/// dasselbe Ding.
///
/// **Die eine Stelle für die Form.** `InsetCard`, `KachelKarte` und
/// `kachelFlaeche` lesen beide Werte von hier; wer eine Karte von Hand
/// baut, statt einen der drei zu benutzen, legt eine zweite Fassung an,
/// die beim nächsten Umbau stehen bleibt. Gegenstück im Entwurfsboard ist
/// `--r-karte` in `docs/screens/tokens.css`.
const double kartenRadius = 17.0;

/// Die Fläche einer Karte: [Palette.surface] mit [kartenRadius], **ohne
/// Rand und ohne Schatten**.
///
/// Im Dunkelmodus trennt sich die Karte allein über ihre Fläche: `surface`
/// `#090D10` gegen den schwarzen Grund, CIE-Helligkeit L* 3. Das ist die
/// schwächste Trennung der fünf Fassungen, die am 29.10.2026 zur Wahl
/// standen, und Tim hat sie bewusst genommen (#167, dort „A3"). Wem die
/// Karte zu sehr verschwindet, der braucht eine Kante — das ist eine
/// Änderung hier, keine in `palette.dart`.
///
/// **Beschnitten wird mit der Karte, nicht im Inhalt:** Wer die Fläche um
/// Zeilen mit eigener Hintergrundfläche oder eine farbige Kante legt,
/// schneidet außen mit einem `ClipRRect` über [kartenRadius] — so wie
/// `InsetCard` und `KachelKarte` es tun (`CLAUDE.md`, Abschnitt Code).
BoxDecoration kartenFlaeche(BuildContext context) => BoxDecoration(
  color: CupertinoDynamicColor.resolve(Palette.surface, context),
  borderRadius: BorderRadius.circular(kartenRadius),
);
