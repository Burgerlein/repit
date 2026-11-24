import 'package:flutter/cupertino.dart';

import 'palette.dart';

/// Das Zeichen für „gelesen, kein Wert" — `OHNE_WERT` aus
/// `docs/screens/components.js`, seit dem 28.10.2026 auch in `CLAUDE.md`
/// festgeschrieben.
///
/// Ein **einzelner** Strich wäre von einem Minuszeichen nicht zu
/// unterscheiden; `–/–` ist als Aussage lesbar. Und es ist ausdrücklich
/// nicht `0`: Eine Null behauptet, es sei etwas gelesen worden (Fehler
/// `01` aus `CLAUDE.md`).
const ohneWert = '–/–';

/// Eine graue Fläche an der Stelle, an der ein Wert stehen wird — der
/// Ladeplatzhalter aus #24, ohne Pulsation (die ist ausdrückliches
/// Nicht-Ziel von `docs/superpowers/specs/2026-10-28-leerzustaende-design.md`).
///
/// Die Größe kommt aus [beispiel], einem Beispieltext in **derselben
/// Schrift** — nicht aus einer festen Zahl. #24 begründet das: Eine feste
/// Höhe passt bei einer Schriftgröße und bei keiner anderen. Der
/// Beispieltext gehört deshalb zum Feld und wird von außen übergeben
/// (Schritte sind fünfstellig, ein Gewicht hat eine Nachkommastelle).
///
/// Gemessen wird mit einem `TextPainter`, **nicht** mit einem unsichtbaren
/// `Text` im Baum: Ein solcher trüge Ziffern, die niemand sieht, aber jeder
/// Widget-Test findet.
class Platzhalter extends StatelessWidget {
  const Platzhalter({super.key, required this.beispiel, this.stil});

  /// Der Beispieltext, aus dem Breite und Höhe entstehen. Er wird nie
  /// gezeichnet.
  final String beispiel;

  /// Der Stil, in dem der echte Wert später steht — wird wie bei `Text`
  /// über den `DefaultTextStyle` gelegt, sonst misst der Platzhalter eine
  /// andere Schrift als die, die ihn ablöst.
  final TextStyle? stil;

  @override
  Widget build(BuildContext context) {
    final mass = textMass(context, beispiel, stil);
    final spur = CupertinoDynamicColor.resolve(Palette.line, context);

    return SizedBox(
      width: mass.width,
      height: mass.height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: spur.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}

/// Reserviert die Höhe von [zeilen] Zeilen in [stil] und legt [child]
/// hinein — die „feste Zeilenzahl" aus #24.
///
/// Der eigentliche Höhensprung auf Home kommt nicht von den Zahlen,
/// sondern von den Texten darunter: Sie schwanken zwischen einer und drei
/// Zeilen, und zwar genau dann nach oben, wenn Werte fehlen und ein Grund
/// dasteht. Mit reservierter Höhe steht die Karte still.
class FesteZeilen extends StatelessWidget {
  const FesteZeilen({
    super.key,
    required this.zeilen,
    required this.stil,
    required this.child,
  });

  final int zeilen;
  final TextStyle? stil;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final probe = List<String>.filled(zeilen, 'X').join('\n');
    return SizedBox(
      height: textMass(context, probe, stil).height,
      child: Align(alignment: Alignment.topLeft, child: child),
    );
  }
}

/// Die Größe, die [probe] in [stil] einnähme — ohne das Widget zu bauen.
///
/// `stil` wird über den `DefaultTextStyle` gelegt und die Textskalierung
/// aus der Umgebung übernommen, damit das Maß dem entspricht, was ein
/// `Text` an derselben Stelle ergäbe. [maxWidth] bricht um wie ein `Text`
/// in einer Spalte dieser Breite — für Beispiele, die mehrzeilig werden
/// können.
Size textMass(
  BuildContext context,
  String probe,
  TextStyle? stil, {
  double maxWidth = double.infinity,
}) {
  final basis = DefaultTextStyle.of(context).style.merge(stil);
  final maler = TextPainter(
    text: TextSpan(text: probe, style: basis),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
  )..layout(maxWidth: maxWidth);
  return maler.size;
}
