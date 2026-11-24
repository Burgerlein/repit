import 'package:flutter/cupertino.dart';

import '../design/palette.dart';

/// Das Vorschaubild einer Übung für Listen und Suche (#38): nur das
/// Startbild, statisch, Ecken 8, Standardgröße 48.
///
/// **Dekodiert in der Größe, in der es steht** — [groesse] mal Pixeldichte,
/// nicht die 512 Pixel der Quelle. Eine Liste mit vielen Zeilen hält sonst
/// jedes Bild in voller Auflösung im Speicher. Lässt sich die Datei nicht
/// lesen, steht eine neutrale graue Fläche da, ohne Ausnahme.
///
/// Dekorativ: Der Name der Übung steht in der Zeile daneben, das Bild bekommt
/// keinen eigenen Vorlesetext.
class UebungsbildMiniatur extends StatelessWidget {
  const UebungsbildMiniatur({
    super.key,
    required this.start,
    this.groesse = 48,
  });

  /// Asset-Pfad des Startbildes.
  final String start;

  final double groesse;

  static const double eckenradius = 8;

  @override
  Widget build(BuildContext context) {
    final flaeche = CupertinoDynamicColor.resolve(Palette.bg, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final dichte = MediaQuery.devicePixelRatioOf(context);
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: groesse,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(eckenradius),
          child: ColoredBox(
            color: flaeche,
            child: Image.asset(
              start,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              cacheWidth: (groesse * dichte).round(),
              excludeFromSemantics: true,
              errorBuilder: (context, fehler, stapel) => Center(
                child: Icon(
                  CupertinoIcons.photo,
                  size: groesse * 0.4,
                  color: muted,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
