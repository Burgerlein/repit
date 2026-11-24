// Der Kasten mit farbiger Kante der beiden Umfänge-Schirme — `noteBox` aus
// `docs/screens/components.js`.
//
// **Eine Stelle für zwei Schirme** (#479): Die Übersicht und der Verlauf je
// Maß zeigen denselben Kasten — „noch nie gemessen", „erste Messung", „nicht
// lesbar", die Messanleitung. Zweimal gebaut liefen sie beim nächsten Umbau
// auseinander, und dann sähe derselbe Zustand auf zwei Schirmen verschieden
// aus.
//
// Nicht [Notizflaeche] aus `shell/mess_abschnitte.dart`: Die trägt eine 4
// Punkt breite Kante in einer [InsetCard] und gehört den drei
// Messwert-Schirmen. Dieser Kasten ist der der Umfänge-Entwürfe — 3 Punkt
// Kante, eingefärbter Grund, nur rechts abgerundet.
import 'package:flutter/cupertino.dart';

import '../design/palette.dart';

/// Welche Kante der Kasten trägt — `noteBox(tone, …)` im Entwurf.
enum UmfangsNotizTon { neutral, warnung }

/// Der Kasten mit farbiger Kante.
///
/// **Die Kante wird mit der Karte beschnitten, nicht selbst abgerundet**
/// (`CLAUDE.md`): Ein 3 Punkt breiter Balken mit Eckenradius liefe über die
/// Ecke hinaus. Deshalb ist nur die rechte Seite rund.
class UmfangsNotiz extends StatelessWidget {
  const UmfangsNotiz({super.key, required this.ton, required this.text});

  final UmfangsNotizTon ton;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final kante = CupertinoDynamicColor.resolve(switch (ton) {
      UmfangsNotizTon.neutral => Palette.muted,
      UmfangsNotizTon.warnung => Palette.warn,
    }, context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: kante.withValues(alpha: 0.12),
          border: Border(left: BorderSide(color: kante, width: 3)),
          borderRadius: const BorderRadius.horizontal(
            right: Radius.circular(8),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(fontSize: 13, height: 1.35, color: ink),
        ),
      ),
    );
  }
}
