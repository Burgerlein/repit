import 'package:flutter/cupertino.dart';

import 'palette.dart';
import 'typografie.dart';

/// Die Energiebilanz als ruhige Zeile unter den Ringen — Dart-Entsprechung
/// von `balanceLine({wert, note})` in `docs/screens/components.js`
/// (`.balanceline`). Keine eigene Logik: zwei Strings, einer schon fertig
/// formatiert (`wert`), der andere eine Einordnung des Schirms (`hinweis`).
///
/// **Ersetzt `Bilanzkarte`.** Die ursprüngliche Karte — mit
/// aufgenommen/verbraucht/Differenz, Vorzeichen-Logik und Farbumschlag bei
/// Überschuss/Defizit — ist aus dem Entwurf verschwunden: Sie stand als
/// größte Zahl über allem, war aber die Differenz zweier Schätzungen und
/// 16 Stunden am Tag irreführend (siehe Kommentarkopf in `heute-kombi.js`).
/// Ob und wann diese Zeile überhaupt steht, ist Zustandslogik des Schirms,
/// nicht Sache dieses Bausteins.
class Bilanzzeile extends StatelessWidget {
  const Bilanzzeile({super.key, required this.wert, required this.hinweis});

  final String wert;
  final String hinweis;

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Energiebilanz heute', style: TextStyle(fontSize: 13, color: muted)),
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    hinweis,
                    style: TextStyle(fontSize: 11, color: muted),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            wert,
            style: Typografie.tabularNumbers(
              Typografie.numeric(TypografieGroesse.subheadline, gewicht: FontWeight.w400),
            ),
          ),
        ],
      ),
    );
  }
}
