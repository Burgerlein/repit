import 'package:flutter/widgets.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// Wie kräftig die Glasoptik von [Glas] ausfällt.
///
/// Nur zwei Stufen, mit Absicht: Mehr Abstufung bräuchte kein Schirm aus dem
/// Entwurf (Tab-Leiste, Nav-Leiste, Fokus-Karten), und jede weitere Stufe
/// wäre eine weitere Stelle, die beim Umstieg auf `cupertino_ui` (siehe
/// unten) mitgepflegt werden müsste.
enum GlasStaerke {
  /// Die Vorgabe. Entwurf Abschnitt 6.2: Glas nur dort, wo es trägt — nicht
  /// in Listen und scrollenden Inhalten, die Shader-Last ist real.
  schwach,

  /// Für die wenigen Stellen, die mehr Tiefe vertragen (z. B. eine
  /// freistehende Fokus-Karte).
  stark,
}

/// Die Glasoptik hinter einer einzigen, schmalen Widget-Schicht.
///
/// **Kein direkter Import von `liquid_glass_widgets` außerhalb dieser
/// Datei.** Begründung (Entwurf Abschnitt 6.2): Der Flutter-PR, der Liquid
/// Glass nach `cupertino_ui` bringt (flutter/packages#13163), zieht
/// `liquid_glass_widgets` wörtlich ein. Der spätere Umstieg auf die
/// offiziellen Widgets betrifft dann **diese eine Datei**, nicht jeden
/// Schirm, der heute schon `Glas` verwendet.
///
/// `useOwnLayer: true`, bewusst: Die grundierte Variante
/// (`LiquidGlass.grouped`) verlangt einen umgebenden `LiquidGlassLayer`
/// (z. B. über `GlassScaffold`), den es für einzelne Bausteine wie diesen
/// nicht automatisch gibt. Mit einer eigenen Schicht funktioniert `Glas`
/// überall, ohne dass jeder Aufrufer zusätzlich eine Glas-Infrastruktur um
/// sich herum aufbauen muss — zum Preis einer etwas höheren, aber für die
/// vorgesehenen Stellen (Leisten, einzelne Karten) unerheblichen Shader-Last.
class Glas extends StatelessWidget {
  const Glas({super.key, required this.child, this.staerke = GlasStaerke.schwach});

  final Widget child;
  final GlasStaerke staerke;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      useOwnLayer: true,
      settings: _einstellungen(staerke),
      child: child,
    );
  }

  static LiquidGlassSettings _einstellungen(GlasStaerke staerke) {
    return switch (staerke) {
      GlasStaerke.schwach => const LiquidGlassSettings(thickness: 10, blur: 4),
      GlasStaerke.stark => const LiquidGlassSettings(thickness: 28, blur: 12),
    };
  }
}
