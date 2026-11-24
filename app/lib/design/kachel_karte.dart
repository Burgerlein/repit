import 'package:flutter/cupertino.dart';

import 'karten_flaeche.dart';

/// Die Karte auf Home — Ringblock, offene und erledigte Mahlzeiten, der
/// Grund „kein Kalorienziel" und die Erholungskarte (#376).
///
/// **Tims Entscheidung vom 05.11.2026:** „Alle Karten auf Home bekommen die
/// Ränder wie die Erholung-Karte" — und am selben Tag für die ganze App
/// (#384). Form und Farbe stehen deshalb nicht hier, sondern in
/// [kartenFlaeche]; `InsetCard` trägt dieselbe Fläche.
///
/// **Beschnitten wird mit der Karte**, nicht im Inhalt: Zeilen mit eigener
/// Hintergrundfläche (Tippfläche einer `IconRow`) liefen sonst über die
/// runde Ecke hinaus (`CLAUDE.md`, Abschnitt Code).
class KachelKarte extends StatelessWidget {
  const KachelKarte({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(kartenRadius),
      child: DecoratedBox(decoration: kartenFlaeche(context), child: child),
    );
  }
}
