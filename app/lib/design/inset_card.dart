import 'package:flutter/cupertino.dart';

import 'karten_flaeche.dart';

/// Die Karte, auf der Listenzeilen sitzen — Dart-Entsprechung von
/// `InsetCard` in `Sources/DesignSystem/InsetList.swift`.
///
/// **Seit #384 dieselbe Fläche wie jede andere Karte** ([kartenFlaeche]:
/// `surface`, Radius 17, kein Rand, kein Schatten — Tims Entscheidung vom
/// 05.11.2026, „Karten app-weit wie auf Home"). Vorher Radius 10 und 1 pt
/// Rand in `line` nach `.panel` aus `docs/prototype/index.html`.
///
/// **Beschnitten wird außen**, mit einem `ClipRRect` über die ganze Karte:
/// Eine farbige Kante links (`Border(left: …)` im Kind) läuft so nicht über
/// die runde Ecke hinaus (`CLAUDE.md`, Abschnitt Code).
///
/// Reiner Container mit einem `child` — anders als die Swift-Vorlage setzt
/// diese Fassung keine Trennlinien zwischen Zeilen selbst; das bleibt, wie
/// schon in `InsetList.swift` (`RowSeparator`), Sache des Aufrufers.
class InsetCard extends StatelessWidget {
  const InsetCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(kartenRadius),
      child: DecoratedBox(decoration: kartenFlaeche(context), child: child),
    );
  }
}
