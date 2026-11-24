// Formularzeilen — die Dart-Entsprechungen von `formRow` und `toggleRow`
// aus `docs/screens/components.js`.
//
// Es gab sie bisher nur als private Teile des Auszeit-Blatts
// (`_DatumsZeile`) und gar nicht als Schalter; der Zykluskalender
// braucht beide auf vier Schirmen. Deshalb hier, neben `InsetCard` und
// `ZieleFormKarte`, und nicht noch einmal privat.
//
// Mechanik, kein Fachinhalt. Nutzertexte gehören in die Schirme.
import 'package:flutter/cupertino.dart';

import 'palette.dart';

Color _farbe(BuildContext context, Color farbe) =>
    CupertinoDynamicColor.resolve(farbe, context);

/// Eine Zeile aus Beschriftung links und Wert rechts — `formRow`.
///
/// `platzhalter: true` setzt den Wert in `muted` statt in `river`: Das
/// ist der Unterschied zwischen „nichts gewählt" und einer Antwort.
/// **Der Winkel steht nur, wenn die Zeile etwas aufklappt** — eine Zeile
/// ohne `aufTipp` ist eine Anzeige und keine Tür.
class FormZeile extends StatelessWidget {
  const FormZeile({
    super.key,
    required this.beschriftung,
    this.wert,
    this.platzhalter = false,
    this.aufTipp,
    this.unterzeile,
  });

  final String beschriftung;
  final String? wert;
  final bool platzhalter;
  final VoidCallback? aufTipp;

  /// Der kleine Satz unter der Beschriftung — `<small>` in `formRow`.
  final String? unterzeile;

  @override
  Widget build(BuildContext context) {
    final zeile = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                beschriftung,
                style: TextStyle(
                  fontSize: 15.5,
                  color: _farbe(context, Palette.ink),
                ),
              ),
              if (unterzeile != null)
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(
                    unterzeile!,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: _farbe(context, Palette.muted),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              wert ?? '',
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15.5,
                color: _farbe(
                  context,
                  platzhalter ? Palette.muted : Palette.river,
                ),
              ),
            ),
          ),
          if (aufTipp != null) ...[
            const SizedBox(width: 6),
            Icon(
              CupertinoIcons.chevron_down,
              size: 12,
              color: _farbe(context, Palette.muted),
            ),
          ],
        ],
      ),
    );
    if (aufTipp == null) return zeile;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: aufTipp,
      child: zeile,
    );
  }
}

/// Eine Zeile mit Schieber — `toggleRow`.
///
/// `detail` ist der Satz unter der Beschriftung. Er sagt, **was der
/// Schalter bewirkt**, nicht was er bedeutet: „Kalender unter Mehr,
/// Blutung, Symptome" statt „schaltet den Zyklus ein".
class SchalterZeile extends StatelessWidget {
  const SchalterZeile({
    super.key,
    required this.beschriftung,
    required this.an,
    this.aufAenderung,
    this.detail,
  });

  final String beschriftung;
  final bool an;
  final ValueChanged<bool>? aufAenderung;
  final String? detail;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 9, 12, 9),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                beschriftung,
                style: TextStyle(
                  fontSize: 15.5,
                  color: _farbe(context, Palette.ink),
                ),
              ),
              if (detail != null)
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(
                    detail!,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.25,
                      color: _farbe(context, Palette.muted),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        CupertinoSwitch(value: an, onChanged: aufAenderung),
      ],
    ),
  );
}
