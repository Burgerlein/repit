import 'package:flutter/cupertino.dart';

import 'palette.dart';
import 'typografie.dart';

/// Das große Datum über einem Schirm, darunter optional eine Einordnung —
/// Dart-Entsprechung von `large(title, lede)` in `docs/screens/components.js`
/// (`.t-large`/`.t-lede`). Keine eigene Swift-Komponente vorhanden.
///
/// Konstruktor positional für den Titel, `einordnung` benannt und optional —
/// spiegelt `large(title, lede)`, bei dem `lede` ebenfalls weggelassen
/// werden kann.
class GrosseUeberschrift extends StatelessWidget {
  const GrosseUeberschrift(this.titel, {super.key, this.einordnung});

  final String titel;
  final String? einordnung;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final einordnung = this.einordnung;

    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: einordnung == null ? 0 : 3),
            child: Text(
              titel,
              style: Typografie.numeric(TypografieGroesse.title2).copyWith(
                color: ink,
              ),
            ),
          ),
          if (einordnung != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                einordnung,
                style: TextStyle(fontSize: 15, color: muted),
              ),
            ),
        ],
      ),
    );
  }
}
