/// Ablesen durch Halten — was alle Diagramme der App dabei gemeinsam haben:
/// welcher Platz unter dem Finger liegt, wie der Kopf das Abgelesene zeigt
/// und wie der gehaltene Platz im Bild markiert wird.
///
/// Herausgezogen aus `zeitdiagramm.dart` (#378), als der 14-Tage-Verlauf
/// der Ernährung dieselbe Geste bekam. Der Verlauf trägt drei Spuren über
/// dieselben Tage und ist deshalb ein eigener Maler (#312); ein
/// nachgebautes Halten hätte dort nach kurzer Zeit anders ausgesehen als im
/// `Zeitdiagramm`. Hier steht es einmal.
///
/// **Die Geste selbst steht nicht hier.** Im `Zeitdiagramm` teilt sich das
/// Halten einen `GestureDetector` mit dem Blättern, damit beide in einer
/// Gestenarena liegen (Kopf von `zeitdiagramm.dart`); ein Diagramm ohne
/// Blättern legt nur die vier `onLongPress…`-Rückrufe an und fragt
/// [platzUnterFinger].
library;

import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import 'palette.dart';
import 'typografie.dart';

/// Der Platz unter dem Finger bei [dx] — **gezählt über [gezeichnet]**,
/// geklemmt auf die [plaetze], die tatsächlich wählbar sind. Beide sind
/// meist gleich; beim `Zeitdiagramm` zeichnet ein angebrochener Monat mehr
/// Plätze, als er Werte hat (`Fensterstand.gezeichnet`).
///
/// `null`, solange es keine Fläche oder keinen Platz gibt — vor dem ersten
/// Layout ist die Breite unbekannt.
int? platzUnterFinger({
  required double dx,
  required double breite,
  required int gezeichnet,
  required int plaetze,
}) {
  if (breite <= 0 || gezeichnet <= 0 || plaetze <= 0) return null;
  return (dx / breite * gezeichnet).floor().clamp(0, plaetze - 1);
}

/// Der Kopf über einem Diagramm: Überschrift, Zahl mit Einheit, eine Zeile
/// darunter — `.charthead` aus `chartCard` im Entwurfsboard.
///
/// **Beim Ablesen tritt der Tag an die Stelle des Durchschnitts**, in
/// derselben Fläche: Überschrift wird das Datum, die Zahl steht in
/// Flussblau. Eine eigene Zeile für das Abgelesene ließe beim Halten alles
/// darunter springen (#146).
///
/// **In jedem Zustand gleich hoch.** Jede der drei Zeilen steht immer da;
/// eine leere Unterzeile ist eine leere Zeile, keine fehlende.
class DiagrammKopf extends StatelessWidget {
  const DiagrammKopf({
    super.key,
    required this.ueberschrift,
    required this.wert,
    required this.einheit,
    required this.unterzeile,
    required this.abgelesen,
  });

  /// „Durchschnitt" oder das Datum des gehaltenen Platzes; wird in
  /// Großbuchstaben gesetzt.
  final String ueberschrift;

  /// Die fertige Zahl — oder, wo keine steht, der Platzhalter des
  /// Diagramms. Nie eine erfundene 0.
  final String wert;

  /// Leer heißt: keine. **Wo keine Zahl steht, steht auch keine Einheit**;
  /// das entscheidet der Aufrufer, der weiß, ob [wert] eine Zahl ist.
  final String einheit;

  /// Zeitraum ohne Auswahl; beim Ablesen leer oder, wo ein Diagramm mehr
  /// als eine Spur trägt, deren übrige Werte.
  final String unterzeile;

  /// Ob gerade ein Platz gehalten wird — dann steht [wert] in Flussblau.
  final bool abgelesen;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final river = CupertinoDynamicColor.resolve(Palette.river, context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          ueberschrift.toUpperCase(),
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.1,
            color: muted,
          ),
        ),
        // `.charthead .v` im Entwurfsboard: Zahl und Einheit in einer
        // Zeile, an der Grundlinie ausgerichtet, 4 Punkt Abstand.
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            // `Flexible`, damit „keine Messung" umbricht statt über den
            // Rand zu laufen: Eine `Row` gibt ihren starren Kindern
            // unbegrenzte Breite.
            Flexible(
              child: Text(
                wert,
                style: Typografie.tabularNumbers(
                  Typografie.numeric(
                    TypografieGroesse.largeTitle,
                    gewicht: FontWeight.w500,
                  ),
                ).copyWith(color: abgelesen ? river : ink),
              ),
            ),
            if (einheit.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(
                einheit,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: muted,
                ),
              ),
            ],
          ],
        ),
        Text(
          unterzeile,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 14, color: muted),
        ),
      ],
    );
  }
}

/// Eine gestrichelte Linie, vier Punkt Strich, drei Punkt Lücke — für
/// Ziellinien und das Lot unter dem gehaltenen Platz.
void zeichneGestrichelt(Canvas canvas, Offset von, Offset bis, Paint stift) {
  const strich = 4.0, luecke = 3.0;
  final gesamt = (bis - von).distance;
  if (gesamt <= 0) return;
  final richtung = (bis - von) / gesamt;
  var gelaufen = 0.0;
  while (gelaufen < gesamt) {
    final ende = math.min(gelaufen + strich, gesamt);
    canvas.drawLine(von + richtung * gelaufen, von + richtung * ende, stift);
    gelaufen = ende + luecke;
  }
}

/// Das Lot durch den gehaltenen Platz: gestrichelt, in [farbe] (Flussblau),
/// von [oben] bis [unten] bei [x].
void zeichneAuswahlLot(
  Canvas canvas, {
  required double x,
  required double oben,
  required double unten,
  required Color farbe,
}) {
  zeichneGestrichelt(
    canvas,
    Offset(x, oben),
    Offset(x, unten),
    Paint()
      ..color = farbe.withValues(alpha: 0.8)
      ..strokeWidth = 1,
  );
}

/// Der gehaltene Punkt einer Linie: voll in [farbe], mit einem Ring in der
/// Kartenfläche [flaeche], damit er sich von der Linie abhebt.
void zeichneAuswahlPunkt(
  Canvas canvas,
  Offset mitte, {
  required Color farbe,
  required Color flaeche,
}) {
  canvas.drawCircle(mitte, 5.5, Paint()..color = farbe);
  canvas.drawCircle(
    mitte,
    5.5,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = flaeche,
  );
}

/// Die Deckkraft eines Balkens: der gehaltene voll, alle übrigen bei 85 %.
Color balkenFarbe(Color farbe, {required bool gehalten}) =>
    gehalten ? farbe : farbe.withValues(alpha: 0.85);
