// Wie eine Veränderung am Maßband geschrieben und gefärbt wird — **eine
// Stelle für beide Umfänge-Schirme** (#478, #479).
//
// Die Übersicht hängt „seit 30.08." an, der Verlaufsschirm setzt das Datum
// als Kennzeichen daneben; die Zahl und ihre Farbe sind in beiden Fällen
// dieselben. Zweimal geschrieben liefen sie auseinander — und die Farbe ist
// genau die Stelle, an der das teuer wird.
//
// **Hier wird nicht gerechnet.** Betrag, Richtung und „ist das
// Fortschritt?" stehen fertig in [UmfangsVeraenderung] aus dem Kern; diese
// Datei schreibt sie nur auf (`CLAUDE.md`, „Deutsch in der Oberfläche").
import 'package:flutter/cupertino.dart';
import 'package:trainings_core/trainings_core.dart';

import '../design/palette.dart';
import '../design/zahlen.dart';

/// „+0,6 cm", „−0,4 cm" — oder „unverändert" innerhalb der Totzone.
///
/// **Keine Null als Trend:** „±0,0" behauptete eine Messgenauigkeit, die
/// das Maßband nicht hat; was im Rauschen liegt, heißt „unverändert"
/// (`UmfangsFortschritt.totzone`). Das echte Minuszeichen statt des
/// Bindestrichs.
String umfangsVeraenderungText(UmfangsVeraenderung veraenderung) {
  if (veraenderung.richtung == UmfangsRichtung.unveraendert) {
    return 'unverändert';
  }
  final zeichen = veraenderung.delta > 0 ? '+' : '−';
  return '$zeichen${umfangsZahl(veraenderung.delta.abs())} cm';
}

/// „38,6" — eine Nachkommastelle, so wie das Maßband misst.
String umfangsZahl(double wert) => formatNumber(wert, nachkommastellen: 1);

/// „38,6 cm".
String umfangsWert(double wert) => '${umfangsZahl(wert)} cm';

/// **Ein Vorzeichen allein färbt nichts ein.** Ob eine Bewegung in die
/// gewollte Richtung geht, steckt als [Umfang.wenigerIstBesser] im Maß und
/// kommt als `istFortschritt` aus dem Kern — wer nach `delta > 0` färbte,
/// malte eine fallende Taille rot an und die wachsende Hüfte gleich mit.
///
/// Was in der Totzone liegt, bleibt grau: Ein Zehntel ist kein Erfolg.
Color umfangsTrendFarbe(
  BuildContext context,
  UmfangsVeraenderung? veraenderung,
  Color muted,
) {
  if (veraenderung == null ||
      veraenderung.richtung == UmfangsRichtung.unveraendert) {
    return muted;
  }
  return CupertinoDynamicColor.resolve(
    veraenderung.istFortschritt ? Palette.ok : Palette.warn,
    context,
  );
}
