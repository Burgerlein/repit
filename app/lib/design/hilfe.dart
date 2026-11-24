// Das Fragezeichen-Muster — Fassung C zu #356.
//
// Tim hat am 23.11.2026 aus drei Fassungen gewählt und zugleich
// festgelegt: **ab sofort auf jedem Schirm, den wir anfassen**
// (`CLAUDE.md`, „Erklärtexte stehen hinter einem Fragezeichen").
// Die drei Fassungen stehen weiter in
// `docs/screens/screens/hinweise-vorschlag.js`.
//
// Was erklärt, geht hinter das `?`; sichtbar bleibt nur, was zur Zahl
// gehört. Die Grenze läuft nach Art, nicht nach Länge:
//
//   · Erklärung                       → ins Blatt
//   · Fehler („Nicht gesichert")      → bleibt, als rote Zeile der Karte
//   · Vorbehalt („Schätzung")         → bleibt, als Marke am Kopf
//   · fehlende Health-Daten           → bleibt als kurze Zeile
//
// Ein Fehler hinter einem Fragezeichen wäre ein verschwiegener Fehler.
import 'package:flutter/cupertino.dart';

import 'inset_card.dart';
import 'palette.dart';

Color _farbe(BuildContext context, Color farbe) =>
    CupertinoDynamicColor.resolve(farbe, context);

/// Abschnittskopf mit `?` rechts — `hilfeKopf` aus `components.js`.
///
/// `marke` ist das eine Wort, das zur Zahl gehört und deshalb sichtbar
/// bleibt (etwa „Schätzung", „nichts gewählt").
class HilfeKopf extends StatelessWidget {
  const HilfeKopf({
    super.key,
    required this.titel,
    this.marke,
    this.aufHilfe,
  });

  final String titel;
  final String? marke;
  final VoidCallback? aufHilfe;

  @override
  Widget build(BuildContext context) {
    final gedaempft = _farbe(context, Palette.muted);
    return Padding(
      padding: const EdgeInsets.fromLTRB(23, 18, 16, 7),
      child: Row(
        children: [
          Text(
            titel.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 0.5,
              fontWeight: FontWeight.w600,
              color: gedaempft,
            ),
          ),
          if (marke != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: _farbe(context, Palette.line).withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                marke!.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 0.4,
                  fontWeight: FontWeight.w600,
                  color: gedaempft,
                ),
              ),
            ),
          ],
          const Spacer(),
          if (aufHilfe != null)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: aufHilfe,
              child: Semantics(
                button: true,
                label: 'Hilfe zu $titel',
                child: Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _farbe(context, Palette.river),
                      width: 1.3,
                    ),
                  ),
                  child: Text(
                    '?',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _farbe(context, Palette.river),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Die Art einer sichtbar bleibenden Zeile.
enum HinweisArt {
  /// Neutral, gedämpft.
  info,

  /// Ein Fehler oder etwas, das jetzt zu tun ist — rot.
  warnung,
}

/// Die Zeile, die **in** der Karte bleibt — `pflichtZeile`.
///
/// Als letzte Zeile einer [InsetCard] gedacht, abgetrennt durch
/// dieselbe Haarlinie wie zwischen zwei Zeilen.
class PflichtZeile extends StatelessWidget {
  const PflichtZeile({
    super.key,
    required this.text,
    this.art = HinweisArt.info,
  });

  final String text;
  final HinweisArt art;

  @override
  Widget build(BuildContext context) {
    final ton = _farbe(
      context,
      art == HinweisArt.warnung ? Palette.warn : Palette.muted,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1.5),
            child: Icon(
              art == HinweisArt.warnung
                  ? CupertinoIcons.exclamationmark_triangle
                  : CupertinoIcons.info_circle,
              size: 14,
              color: ton,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13.5, height: 1.35, color: ton),
            ),
          ),
        ],
      ),
    );
  }
}

/// Die Lagezeile — in welchem Zustand der Schirm gerade ist.
///
/// Für Schirme, die keinen Kartenfuß anbieten: Ein Kalender besteht aus
/// einem Raster. `unten: true` trennt nach oben statt nach unten — auf
/// dem Zyklus-Schirm steht die Zeile unter Raster und Legende, weil sie
/// sich oben vor das Bild drängte (Tim, 23.11.2026).
class LageZeile extends StatelessWidget {
  const LageZeile({
    super.key,
    required this.text,
    this.leitwort,
    this.art = HinweisArt.info,
    this.unten = false,
  });

  final String text;
  final String? leitwort;
  final HinweisArt art;
  final bool unten;

  @override
  Widget build(BuildContext context) {
    final ton = _farbe(
      context,
      art == HinweisArt.warnung ? Palette.warn : Palette.muted,
    );
    final linie = BorderSide(color: _farbe(context, Palette.line), width: 0.5);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        border: Border(
          top: unten ? linie : BorderSide.none,
          bottom: unten ? BorderSide.none : linie,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1.5),
            child: Icon(
              art == HinweisArt.warnung
                  ? CupertinoIcons.exclamationmark_triangle
                  : CupertinoIcons.info_circle,
              size: 15,
              color: ton,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  if (leitwort != null)
                    TextSpan(
                      text: '$leitwort ',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: art == HinweisArt.warnung
                            ? ton
                            : _farbe(context, Palette.ink),
                      ),
                    ),
                  TextSpan(text: text),
                ],
              ),
              style: TextStyle(fontSize: 13.5, height: 1.4, color: ton),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ein Absatz im Hilfe-Blatt: farbiger Strich, Titel, Text.
@immutable
class HilfeBlock {
  const HilfeBlock({
    required this.titel,
    required this.text,
    required this.ton,
  });

  final String titel;
  final String text;

  /// Die Farbe dessen, was der Block erklärt — so findet man den Absatz
  /// zur Form, die man gerade nicht versteht, ohne zu lesen.
  final Color ton;
}

/// Zeigt das Hilfe-Blatt hinter dem `?`.
///
/// `pflicht` ist der eine Satz, der sonst unter jeder Zahl stünde — hier
/// steht er **einmal**, oben (Tim, 23.11.2026: „wir wissen das. Muss
/// nicht überall stehen").
Future<void> zeigeHilfeBlatt(
  BuildContext context, {
  required String titel,
  required List<HilfeBlock> bloecke,
  String? pflicht,
}) => showCupertinoModalPopup<void>(
  context: context,
  builder: (_) =>
      _HilfeBlatt(titel: titel, bloecke: bloecke, pflicht: pflicht),
);

class _HilfeBlatt extends StatelessWidget {
  const _HilfeBlatt({
    required this.titel,
    required this.bloecke,
    this.pflicht,
  });

  final String titel;
  final List<HilfeBlock> bloecke;
  final String? pflicht;

  @override
  Widget build(BuildContext context) {
    final medien = MediaQuery.of(context);
    final linie = _farbe(context, Palette.line);
    return Container(
      height: medien.size.height * 0.68,
      decoration: BoxDecoration(
        color: _farbe(context, Palette.bg),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 36,
            height: 5,
            decoration: BoxDecoration(
              color: linie,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    titel,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: _farbe(context, Palette.ink),
                    ),
                  ),
                ),
                CupertinoButton(
                  key: const Key('hilfe-fertig'),
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(44, 36),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Fertig'),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (pflicht != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        pflicht!,
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.4,
                          color: _farbe(context, Palette.muted),
                        ),
                      ),
                    ),
                  for (var i = 0; i < bloecke.length; i++) ...[
                    if (i > 0) Container(height: 0.5, color: linie),
                    _Block(block: bloecke[i]),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.block});

  final HilfeBlock block;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 13, bottom: 3),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 4,
              height: 15,
              decoration: BoxDecoration(
                color: CupertinoDynamicColor.resolve(block.ton, context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                block.titel,
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w600,
                  color: _farbe(context, Palette.ink),
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 13, top: 5),
          child: Text(
            block.text,
            style: TextStyle(
              fontSize: 13.8,
              height: 1.45,
              color: _farbe(context, Palette.muted),
            ),
          ),
        ),
      ],
    ),
  );
}
