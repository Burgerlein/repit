// Die beiden Kennzahlen über vierzehn Tage (#79) — `statTiles` im
// Entwurfsboard (`docs/screens/components.js`, `.stats`): zwei Kacheln
// nebeneinander, gleich breit, Beschriftung versal, darunter die Zahl.
//
// **Warum nicht `Kacheln`/`KachelWert`.** Die Kachel dort trägt drei fest
// reservierte Zeilen Erläuterung und zeichnet bei fehlendem Wert `–/–`. Das
// ist hier beides nicht gewollt: `–/–` heißt „gelesen, kein Wert" und gehört
// zu einem Lauf, der leer ausging; die Trainings sind Tims eigene Daten, es
// gibt keinen. Der Grund steht **einmal** im Hinweis darunter, nicht je
// Kachel (`CLAUDE.md`: „Der Grund steht einmal, nicht je Feld"). Die Kachel
// umzubauen hätte den Kachelstreifen von Home berührt; sie hier lokal
// nachzubauen kostet 80 Zeilen.
//
// **Eine Anzeige hat genau eine Form:** Reihe, Kacheln und **Wertplatz**
// stehen in jeder Datenlage da, in Maß und Ort gleich. Nur die Füllung
// wechselt — die Zahl, eine graue Form (nur beim Lesen) oder nichts. Der
// Wertplatz hat eine **feste Höhe**, gemessen an der Schrift der Zahl, damit
// auch die leere Kachel genauso hoch ist wie die gefüllte.
import 'package:flutter/cupertino.dart';

import '../design/karten_flaeche.dart';
import '../design/palette.dart';
import '../design/platzhalter.dart';
import '../design/typografie.dart';
import 'gym_letzte_trainings_provider.dart';
import 'gym_verlauf_schluessel.dart';
import 'gym_verlauf_texte.dart';

/// Die Kachelreihe. Steht in jeder Datenlage.
class GymVerlaufKennzahlen extends StatelessWidget {
  const GymVerlaufKennzahlen({super.key, required this.stand});

  final GymLetzteTrainings stand;

  @override
  Widget build(BuildContext context) {
    final anzahl = stand.anzahl14Tage;
    final volumen = stand.volumen14TageKg;
    return Padding(
      key: kGymVerlaufKennzahlen,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _Kachel(
              schluessel: kGymVerlaufKachelTrainings,
              wertSchluessel: kGymVerlaufWertTrainings,
              label: gymVerlaufTrainingsLabel,
              wert: anzahl == null ? null : gymVerlaufTrainingsText(anzahl),
              beispiel: gymVerlaufTrainingsBeispiel,
              keinWert: gymVerlaufKeineTrainings,
              stand: stand,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _Kachel(
              schluessel: kGymVerlaufKachelVolumen,
              wertSchluessel: kGymVerlaufWertVolumen,
              label: gymVerlaufVolumenLabel,
              wert: volumen == null ? null : gymVerlaufVolumenText(volumen),
              beispiel: gymVerlaufVolumenBeispiel,
              keinWert: gymVerlaufKeinVolumen,
              stand: stand,
            ),
          ),
        ],
      ),
    );
  }
}

class _Kachel extends StatelessWidget {
  const _Kachel({
    required this.schluessel,
    required this.wertSchluessel,
    required this.label,
    required this.wert,
    required this.beispiel,
    required this.keinWert,
    required this.stand,
  });

  final Key schluessel;
  final Key wertSchluessel;
  final String label;

  /// `null`, wo es keinen gibt — **nie `0` als Ersatz**.
  final String? wert;
  final String beispiel;
  final String keinWert;
  final GymLetzteTrainings stand;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final wertStil = Typografie.tabularNumbers(
      Typografie.numeric(
        TypografieGroesse.title2,
        gewicht: FontWeight.w400,
      ).copyWith(fontSize: 21, color: ink),
    );
    final wert = this.wert;

    // Die Graue Form nur, solange nichts bekannt ist — und gelesen wird.
    final Widget fuellung = wert != null
        ? Text(wert, style: wertStil)
        : stand.laedt
        ? Platzhalter(beispiel: beispiel, stil: wertStil)
        : const SizedBox.shrink();

    return Semantics(
      // Der Vorlesetext nennt den Zustand, nicht das Zeichen.
      label: gymVerlaufKachelVorlesetext(
        label: label,
        wert: wert,
        laedt: stand.laedt,
        fehlgeschlagen: stand.fehlgeschlagen,
        keinWert: keinWert,
      ),
      excludeSemantics: true,
      child: Container(
        key: schluessel,
        padding: const EdgeInsets.all(11),
        decoration: kartenFlaeche(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: muted,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              // **Feste Höhe**, gemessen an der Zahl: Die gefüllte, die
              // graue und die leere Kachel sind gleich hoch.
              child: SizedBox(
                key: wertSchluessel,
                height: textMass(context, '0', wertStil).height,
                child: Align(alignment: Alignment.centerLeft, child: fuellung),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
