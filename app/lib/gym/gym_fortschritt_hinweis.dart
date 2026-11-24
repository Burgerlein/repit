// Der Hinweiskasten des Schirms „Fortschritt pro Übung" (#93) — `noteBox`
// im Entwurfsboard. **In jeder Lage genau einer** (Spec 3.4):
//
//   lädt              graue Balken
//   gescheitert       ein Satz und der Knopf „Erneut lesen"
//   kein Training     der Satz „Erstes Mal" aus dem Vorschlag
//   Plateau erkannt   der Plateau-Satz **statt** des Vorschlags
//   sonst             der Vorschlag
//
// **Dieselbe Höhe in allen Lagen** („Eine Anzeige hat genau eine Form"). Der
// Text schwankt zwischen einer Zeile und fünf; reserviert wird deshalb die
// Höhe des **längsten möglichen Satzes** — gemessen bei der Breite, die der
// Kasten gerade hat, nicht geraten. Eine feste Zeilenzahl mit
// `maxLines`/Ellipse schnitte den Plateau-Satz ab; hier wird nie etwas
// abgeschnitten.
//
// **Farbe allein trägt die Aussage nicht:** Vorschlag und Plateau tragen ein
// Zeichen (`vorschlagSymbol`, [gymFortschrittPlateauSymbol]), nicht nur den
// Ton der Kante.
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import '../design/inset_card.dart';
import '../design/palette.dart';
import '../design/platzhalter.dart';
import 'gym_fortschritt_provider.dart';
import 'gym_fortschritt_schluessel.dart';
import 'gym_fortschritt_texte.dart';
import 'gym_vorschlag_texte.dart';

/// Breite der Zeichenspalte links im Kasten und ihr Abstand zum Text.
const double _zeichenBreite = 14;
const double _zeichenAbstand = 8;

class GymFortschrittHinweis extends StatelessWidget {
  const GymFortschrittHinweis({
    super.key,
    required this.stand,
    required this.onErneut,
  });

  final GymFortschritt stand;

  /// „Erneut lesen" — liest den Verlauf neu, wo er gescheitert ist. Weil der
  /// Provider hält, bliebe ein Fehler sonst bis zum Neustart der App stehen.
  final VoidCallback onErneut;

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final stil = TextStyle(fontSize: 13, height: 1.4, color: muted);

    final vorschlag = stand.vorschlag;
    // Welche Lage — und was in ihr steht.
    final String? zeichen;
    final Color ton;
    final Widget Function(TextStyle stil) inhalt;
    if (stand.laedt) {
      zeichen = null;
      ton = Palette.bib;
      inhalt = (stil) => _Balken(stil: stil);
    } else if (stand.fehlgeschlagen) {
      zeichen = null;
      ton = Palette.warn;
      inhalt = (stil) => _Fehler(stil: stil, onErneut: onErneut);
    } else if (stand.plateau) {
      zeichen = gymFortschrittPlateauSymbol;
      ton = Palette.warn;
      inhalt = (stil) => Text(
        gymFortschrittPlateauText,
        key: kGymFortschrittPlateau,
        style: stil,
      );
    } else {
      // `vorschlag` ist hier nie `null`: bekannt heißt gelesen.
      final v = vorschlag!;
      final hatVerlauf = stand.reihe.isNotEmpty;
      zeichen = vorschlagSymbol(v, hatVerlauf: hatVerlauf);
      ton = vorschlagTon(v, hatVerlauf: hatVerlauf) ?? Palette.bib;
      inhalt = (stil) => Text(
        vorschlagKurzText(v, stand.uebung, hatVerlauf: hatVerlauf),
        style: stil,
      );
    }

    final kante = CupertinoDynamicColor.resolve(ton, context);

    return Padding(
      key: kGymFortschrittHinweis,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: InsetCard(
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: kante, width: 4)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: LayoutBuilder(
              builder: (context, box) {
                final textBreite = math.max(
                  0.0,
                  box.maxWidth - _zeichenBreite - _zeichenAbstand,
                );
                return SizedBox(
                  height: _reservierteHoehe(context, stil, textBreite),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: _zeichenBreite,
                        child: zeichen == null
                            ? null
                            : Text(zeichen, style: stil.copyWith(color: kante)),
                      ),
                      const SizedBox(width: _zeichenAbstand),
                      Expanded(
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: inhalt(stil),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Die Höhe, die in **jeder** Lage reserviert wird: die des längsten Satzes
/// bei [breite], mindestens aber die der drei grauen Balken und des Satzes
/// samt Knopf im Fehlerfall.
double _reservierteHoehe(BuildContext context, TextStyle stil, double breite) {
  final maler = TextPainter(
    text: TextSpan(text: gymFortschrittPlateauText, style: stil),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
  )..layout(maxWidth: breite);
  final plateau = maler.height;
  maler.dispose();

  final zeile = textMass(context, 'X', stil).height;
  final balken = 3 * zeile + 2 * _balkenAbstand;
  final fehler = zeile + _fehlerAbstand + _knopfHoehe;
  return [plateau, balken, fehler].reduce(math.max);
}

const double _balkenAbstand = 4;
const double _fehlerAbstand = 6;
const double _knopfHoehe = 24;

/// Die graue Form beim Lesen: drei Balken, **feste Zeilenzahl** (Spec 3.4).
class _Balken extends StatelessWidget {
  const _Balken({required this.stil});

  final TextStyle stil;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Platzhalter(beispiel: 'Nächstes Mal, Ziel Wiederholungen', stil: stil),
        const SizedBox(height: _balkenAbstand),
        Platzhalter(beispiel: 'Ein Satz über den nächsten Schritt', stil: stil),
        const SizedBox(height: _balkenAbstand),
        Platzhalter(beispiel: 'kurz gehalten', stil: stil),
      ],
    );
  }
}

/// „Verlauf konnte nicht gelesen werden" und der Knopf, der ihn neu holt.
class _Fehler extends StatelessWidget {
  const _Fehler({required this.stil, required this.onErneut});

  final TextStyle stil;
  final VoidCallback onErneut;

  @override
  Widget build(BuildContext context) {
    final river = CupertinoDynamicColor.resolve(Palette.river, context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(gymFortschrittFehlerText, key: kGymFortschrittFehler, style: stil),
        const SizedBox(height: _fehlerAbstand),
        SizedBox(
          height: _knopfHoehe,
          child: CupertinoButton(
            key: kGymFortschrittErneut,
            padding: EdgeInsets.zero,
            minimumSize: const Size(44, _knopfHoehe),
            onPressed: onErneut,
            child: Text(
              gymFortschrittErneut,
              style: stil.copyWith(color: river, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}
