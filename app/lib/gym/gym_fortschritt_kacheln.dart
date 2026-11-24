// Die beiden Kennzahlen des Schirms „Fortschritt pro Übung" (#93) —
// `statTiles` im Entwurfsboard: zwei Kacheln nebeneinander, gleich breit,
// Beschriftung versal, darunter die Zahl.
//
// **Eine Anzeige hat genau eine Form:** Reihe, Kacheln und **Wertplatz**
// stehen in jeder Datenlage da, in Maß und Ort gleich. Nur die Füllung
// wechselt — die Zahl, eine graue Form (nur beim Lesen) oder `–/–` (gelesen,
// kein Wert). Der Wertplatz hat eine **feste Höhe**, gemessen an der Schrift
// der Zahl, und die Zahl schrumpft bei Bedarf, statt umzubrechen: „24,5 kg
// Unterstützung" ist länger als eine halbe Kartenbreite in 21 Punkt.
//
// **Warum nicht `Kacheln`/`KachelWert`:** Die Kachel dort trägt drei fest
// reservierte Zeilen Erläuterung. Der Grund steht hier **einmal** im
// Hinweiskasten bzw. im Satz zur Übung, nicht je Kachel (`CLAUDE.md`: „Der
// Grund steht einmal, nicht je Feld"). Der Aufbau ist `gym_verlauf_kennzahlen`
// nachgebaut.
import 'package:flutter/cupertino.dart';

import '../design/karten_flaeche.dart';
import '../design/palette.dart';
import '../design/platzhalter.dart';
import '../design/typografie.dart';
import 'gym_fortschritt_schluessel.dart';
import 'gym_fortschritt_texte.dart';

/// Die Kachelreihe. Steht in jeder Datenlage.
class GymFortschrittKacheln extends StatelessWidget {
  const GymFortschrittKacheln({
    super.key,
    required this.hoechstLabel,
    required this.hoechst,
    required this.einRm,
    required this.laedt,
    required this.fehlgeschlagen,
  });

  /// „Höchstgewicht" oder bei einer Zeitübung „Beste Zeit".
  final String hoechstLabel;

  /// Der fertige Text, `null`, wo es keinen Wert gibt — **nie `0` als
  /// Ersatz**.
  final String? hoechst;
  final String? einRm;

  /// Noch nicht gelesen: graue Form statt `–/–`.
  final bool laedt;

  /// Das Lesen ist gescheitert. Die Kachel sagt `–/–`, sie sagt nicht „keine
  /// Trainings" — der Grund steht im Hinweiskasten.
  final bool fehlgeschlagen;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _Kachel(
              schluessel: kGymFortschrittKachelHoechst,
              wertSchluessel: kGymFortschrittWertHoechst,
              label: hoechstLabel,
              wert: hoechst,
              laedt: laedt,
              fehlgeschlagen: fehlgeschlagen,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _Kachel(
              schluessel: kGymFortschrittKachel1rm,
              wertSchluessel: kGymFortschrittWert1rm,
              label: gymFortschrittKachel1rm,
              wert: einRm,
              laedt: laedt,
              fehlgeschlagen: fehlgeschlagen,
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
    required this.laedt,
    required this.fehlgeschlagen,
  });

  final Key schluessel;
  final Key wertSchluessel;
  final String label;
  final String? wert;
  final bool laedt;
  final bool fehlgeschlagen;

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

    // Die graue Form **nur**, solange nichts bekannt ist und gelesen wird;
    // `–/–` heißt „gelesen, kein Wert" und steht nie beim Laden (Fehler `01`).
    final Widget fuellung = wert != null
        ? Text(wert, style: wertStil, maxLines: 1)
        : laedt
        ? Platzhalter(beispiel: gymFortschrittKachelBeispiel, stil: wertStil)
        : Text(ohneWert, style: wertStil.copyWith(color: muted), maxLines: 1);

    return Semantics(
      // Der Vorlesetext nennt den Zustand, nicht das Zeichen.
      label: gymFortschrittKachelVorlesetext(
        label: label,
        wert: wert,
        laedt: laedt,
        fehlgeschlagen: fehlgeschlagen,
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
              // **Feste Höhe**, gemessen an der Zahl: gefüllte, graue und
              // leere Kachel sind gleich hoch. Eine zu lange Zahl schrumpft.
              child: SizedBox(
                key: wertSchluessel,
                height: textMass(context, '0', wertStil).height,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: fuellung,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
