// Die Kachelreihe der Wege und der Kopf mit Zähler (#439, Schnitt 2 von
// #385) — `docs/screens/screens/erfassen.js`, `KACHELN` und
// `MAHLZEIT_KOPF`, Zustände `vorschlag-suche` und `vorschlag-kamera`;
// Bausteine `wege` in `docs/screens/components.js`, `.wege` und
// `.zaehler` in `components.css`. Spec
// `docs/superpowers/specs/2026-11-10-mahlzeiten-aufteilung-design.md`,
// Entscheidung 9, V20–V22.
//
// **Ein Element trägt alle Wege** (Entscheidung 9): Barcode, KI-Foto,
// Suchen, Nur kcal. Im Sucher steht es unten, wo der Umschalter stand
// (Daumen); in der Suche oben, weil unten die Tastatur liegt. Wer welche
// Seite öffnet, entscheiden `KameraSeite` und `SucheSeite` — hier wird nur
// gezeichnet und gemeldet.
//
// Verhalten und Schlüssel gibt `app/test/ernaehrung/erfassen_kacheln_test
// .dart` vor.
import 'package:flutter/cupertino.dart';

import '../design/karten_flaeche.dart';
import '../design/palette.dart';
import '../design/symbole.dart';
import '../design/typografie.dart';
import 'kamera_bausteine.dart';

/// Die Wege ins Erfassen, in der Reihenfolge der Reihe.
enum ErfassenWeg { barcode, ki, suchen, nurKcal }

/// Die Kachelreihe. [aktiv] ist umrandet; ein Tipp darauf tut nichts
/// (V21). „Nur kcal" ist abgeblendet und meldet nie etwas (V20) — einen
/// Schnelleintrag „nur Kalorien" gibt es in der App nicht.
///
/// [dunkel] setzt die Reihe auf den schwarzen Sucher (`.wege.dunkel`).
class ErfassenKacheln extends StatelessWidget {
  const ErfassenKacheln({
    super.key,
    required this.aktiv,
    required this.dunkel,
    required this.aufWeg,
  });

  final ErfassenWeg aktiv;
  final bool dunkel;
  final void Function(ErfassenWeg) aufWeg;

  /// Die Schlüssel der Kacheln — in Sucher und Suche dieselben. Die drei
  /// ersten trugen bis #439 der Umschalter und das „Suchen" oben rechts
  /// (V21).
  static Key schluessel(ErfassenWeg weg) => switch (weg) {
    ErfassenWeg.barcode => const Key('kamera-modus-barcode'),
    ErfassenWeg.ki => const Key('kamera-modus-ki'),
    ErfassenWeg.suchen => const Key('kamera-suchen'),
    ErfassenWeg.nurKcal => const Key('kamera-nur-kcal'),
  };

  static String _label(ErfassenWeg weg) => switch (weg) {
    ErfassenWeg.barcode => 'Barcode',
    ErfassenWeg.ki => 'KI-Foto',
    ErfassenWeg.suchen => 'Suchen',
    ErfassenWeg.nurKcal => 'Nur kcal',
  };

  static String _symbol(ErfassenWeg weg) => switch (weg) {
    ErfassenWeg.barcode => 'barcode',
    ErfassenWeg.ki => 'sparkles',
    ErfassenWeg.suchen => 'magnifyingglass',
    ErfassenWeg.nurKcal => 'bolt.fill',
  };

  @override
  Widget build(BuildContext context) {
    final reihe = Row(
      children: [
        for (final weg in ErfassenWeg.values) ...[
          if (weg != ErfassenWeg.barcode) const SizedBox(width: 8),
          Expanded(
            child: _Kachel(
              key: schluessel(weg),
              label: _label(weg),
              symbol: _symbol(weg),
              an: weg == aktiv,
              tot: weg == ErfassenWeg.nurKcal,
              dunkel: dunkel,
              aufTippen: weg == aktiv || weg == ErfassenWeg.nurKcal
                  ? null
                  : () => aufWeg(weg),
            ),
          ),
        ],
      ],
    );

    if (!dunkel) return reihe;
    // `.wege.dunkel { padding: 12px 12px 0 }` — auf dem Sucher, nicht auf
    // einer Karte.
    return ColoredBox(
      color: kameraSchwarz,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: reihe,
      ),
    );
  }
}

class _Kachel extends StatelessWidget {
  const _Kachel({
    super.key,
    required this.label,
    required this.symbol,
    required this.an,
    required this.tot,
    required this.dunkel,
    required this.aufTippen,
  });

  final String label;
  final String symbol;
  final bool an;

  /// „Nur kcal": steht da, abgeblendet, ohne Tür.
  final bool tot;
  final bool dunkel;
  final VoidCallback? aufTippen;

  @override
  Widget build(BuildContext context) {
    final river = CupertinoDynamicColor.resolve(Palette.river, context);
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final surface = CupertinoDynamicColor.resolve(Palette.surface, context);

    // `components.css`, `.wege` und `.wege.dunkel`.
    final Color flaeche;
    final Color symbolFarbe;
    final Color textFarbe;
    if (dunkel) {
      flaeche = an ? const Color(0xFFFFFFFF) : const Color(0x1AFFFFFF);
      symbolFarbe = an ? kameraSchwarz : const Color(0xFFFFFFFF);
      textFarbe = an ? kameraSchwarz : const Color(0xBFFFFFFF);
    } else {
      flaeche = an
          ? Color.alphaBlend(river.withValues(alpha: 0.10), surface)
          : CupertinoDynamicColor.resolve(_fill, context);
      symbolFarbe = river;
      textFarbe = ink;
    }

    final kachel = Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
      decoration: BoxDecoration(
        color: flaeche,
        borderRadius: BorderRadius.circular(kartenRadius),
        // Der Weg, auf dem man ist, umrandet — im Hellen. Im Dunkeln trägt
        // die weiße Fläche den Unterschied.
        border: an && !dunkel ? Border.all(color: river, width: 2) : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Symbole.aufloesen(symbol), size: 22, color: symbolFarbe),
          const SizedBox(height: 5),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textFarbe,
            ),
          ),
        ],
      ),
    );

    return Semantics(
      button: true,
      selected: an,
      enabled: !tot,
      label: tot ? '$label, noch nicht verfügbar' : label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: aufTippen,
        child: Opacity(opacity: tot ? 0.4 : 1, child: kachel),
      ),
    );
  }
}

/// `--fill` aus `docs/screens/tokens.css` — eine Deckkraftvariante, darum
/// hier und nicht in `Palette` (siehe deren Kopf).
const _fill = CupertinoDynamicColor.withBrightness(
  color: Color(0x0F15242A),
  darkColor: Color(0x12F2F6F7),
);

/// Der Kopf von Sucher und Suche (V22): links der Zähler, in der Mitte die
/// Mahlzeit, rechts „Abbrechen".
///
/// [gebucht] ist die Zahl der in dieser Sitzung gebuchten Einträge; der
/// Kreis steht auch bei 0 da. [titel] ist die Mahlzeit, auf die gebucht
/// wird — vorgewählt oder die, die das Buchungsblatt aus der Uhr wählen
/// würde (`vorgewaehlteMahlzeit`).
///
/// [abbrechenSchluessel]: Im Sucher behält „Abbrechen" `kamera-abbrechen`
/// (Spec, „Erfassen").
class ErfassenKopf extends StatelessWidget {
  const ErfassenKopf({
    super.key,
    required this.gebucht,
    required this.titel,
    required this.aufAbbrechen,
    required this.dunkel,
    this.abbrechenSchluessel = const Key('erfassen-abbrechen'),
  });

  final int gebucht;
  final String titel;
  final VoidCallback aufAbbrechen;
  final bool dunkel;
  final Key abbrechenSchluessel;

  @override
  Widget build(BuildContext context) {
    final river = CupertinoDynamicColor.resolve(Palette.river, context);
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final schrift = dunkel ? const Color(0xFFFFFFFF) : ink;

    // `.snav`: Titel absolut in der Mitte, die beiden Seiten je mindestens
    // 68 breit. Der Titel liegt über der ganzen Breite, damit er mittig
    // steht, egal wie breit Zähler und „Abbrechen" sind.
    return SizedBox(
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            left: 84,
            right: 84,
            child: Center(
              child: Text(
                titel,
                key: const Key('erfassen-titel'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: schrift,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            child: _Zaehler(gebucht: gebucht, dunkel: dunkel),
          ),
          Positioned(
            right: 8,
            child: CupertinoButton(
              key: abbrechenSchluessel,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(44, 36),
              onPressed: aufAbbrechen,
              child: Text(
                'Abbrechen',
                style: TextStyle(color: dunkel ? schrift : river),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Der Kreis mit der Zahl (`.zaehler`) — vorgelesen „3 gebucht".
class _Zaehler extends StatelessWidget {
  const _Zaehler({required this.gebucht, required this.dunkel});

  final int gebucht;
  final bool dunkel;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);

    return Semantics(
      label: '$gebucht gebucht',
      excludeSemantics: true,
      child: Container(
        key: const Key('erfassen-zaehler'),
        constraints: const BoxConstraints(minWidth: 26),
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 7),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: dunkel
              ? const Color(0x29FFFFFF)
              : CupertinoDynamicColor.resolve(_fill, context),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '$gebucht',
          style: Typografie.tabularNumbers(
            Typografie.numeric(TypografieGroesse.subheadline),
          ).copyWith(color: dunkel ? const Color(0xFFFFFFFF) : ink),
        ),
      ),
    );
  }
}
