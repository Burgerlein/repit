import 'package:flutter/cupertino.dart';

import 'palette.dart';
import 'platzhalter.dart';
import 'symbole.dart';
import 'typografie.dart';

/// Zeile mit farbiger Symbolkachel links, Titel/Untertitel in der Mitte,
/// Chevron rechts — Dart-Entsprechung von `IconRow` in
/// `Sources/DesignSystem/InsetList.swift`.
///
/// `symbol` ist ein Name aus [Symbole.tabelle], kein `IconData` direkt —
/// parallel zu den Swift-Aufrufstellen (`MoreView.swift`), die ebenfalls nur
/// einen String durchreichen und ihn erst beim Zeichnen auflösen. Die
/// Auflösung läuft über [Symbole.aufloesen], nicht über `tabelle[symbol]`
/// direkt — ein unbekannter Name soll sichtbar auffallen (Warnzeichen,
/// in der Entwicklung zusätzlich ein `assert`), nicht kommentarlos
/// verschwinden.
///
/// Kachel 30×30 mit Radius 8, Trenner-Einzug 56 pt (Padding 14 + Kachel 30 +
/// Abstand 12) — Werte aus `docs/prototype/index.html` (`.lrow .ic`), nicht
/// aus `InsetList.swift` (dort 29×29/59 pt): Der Prototyp ist laut
/// `CLAUDE.md` die verbindliche Entwurfsreferenz.
///
/// **Erweiterung (Baukasten „Heute, kombiniert", Task H1):** `value` und
/// `big`, nach `row({symbol, tint, title, subtitle, value, big, opens,
/// dead})` in `docs/screens/components.js`. `value` ist der Wert rechts
/// (erfundenes Beispiel: „20 %", oder „Starten"), `big` vergrößert die
/// Symbolkachel (`.ic.lg` im CSS, vgl. die Übungszeile „Drücken — Brust,
/// Schulter, Trizeps" mit `big: true`). Beides ändert nichts an der
/// Chevron-Regel aus Task 11:
/// Der Pfeil erscheint weiterhin nur, wenn `onTap` gesetzt ist.
class IconRow extends StatelessWidget {
  const IconRow({
    super.key,
    required this.title,
    this.subtitle,
    required this.symbol,
    required this.accent,
    this.onTap,
    this.value,
    this.platzhalter,
    this.platzhalterSichtbar = true,
    this.big = false,
    this.symbolFarbe,
    this.laedt = false,
    this.titelZeilen,
    this.untertitelZeilen,
  });

  final String title;
  final String? subtitle;

  /// Name aus [Symbole.tabelle], z. B. `"calendar"`.
  final String symbol;

  final Color accent;
  final VoidCallback? onTap;

  /// Die Farbe des Symbols auf der Kachel — **Weiß, wenn nichts anderes
  /// gesagt ist.**
  ///
  /// Entsprechung von `iconTint` in `row({symbol, tint, iconTint, …})`
  /// (`docs/screens/components.js`). Gebraucht wird sie dort, wo die
  /// Kachel selbst hell ist: Die Zeile „Trainings" auf dem Gym-Schirm
  /// trägt `tint: 'rest'` — ein sehr helles Grau —, und ein weißes Symbol
  /// darauf wäre unsichtbar (`docs/screens/screens/gym.js`). Dasselbe
  /// gilt für die hellen Kacheln `rest` und `bib` — etwa „Operation" auf
  /// dem Auszeit-Schirm (`auszeit.js`).
  final Color? symbolFarbe;

  /// Der Wert rechts in der Zeile (erfundenes Beispiel: „20 %" oder
  /// „Starten").
  final String? value;

  /// Ein Beispieltext, aus dem eine graue Form entsteht, solange [value]
  /// fehlt — der Ladeplatzhalter aus #182.
  ///
  /// **Das Beispiel wird nie gezeichnet**, nur gemessen (siehe
  /// [Platzhalter]). Es gehört zum Feld, nicht zum Baustein: Schritte
  /// sind fünfstellig, ein Gewicht hat eine Nachkommastelle, und eine
  /// Form, die kürzer ist als das, was sie ablöst, lässt die Spalte beim
  /// Eintreffen springen.
  ///
  /// **[value] schlägt [platzhalter].** Stünden beide da, behauptete die
  /// Zeile gleichzeitig, der Wert sei bekannt und er werde noch geladen.
  /// So kann ein Aufrufer den Platzhalter unbesehen durchreichen und
  /// muss nicht an jeder Stelle entscheiden, ob er ihn gerade weglassen
  /// soll.
  final String? platzhalter;

  /// Ob an der Stelle von [platzhalter] die graue Form **steht** — oder
  /// nur ihr Platz freigehalten wird (#77).
  ///
  /// „Der Platzhalter gehört allein in den Ladezustand" (`CLAUDE.md`):
  /// Eine Zeile, deren Wert es noch gar nicht zu holen gibt, zeigt keine
  /// graue Form, denn da kommt nichts mehr. Ihre Wertspalte darf trotzdem
  /// nicht verschwinden — sonst bekommt der Untertitel daneben mehr Platz,
  /// bricht eine Zeile weniger um, und die Karte springt zwischen „lädt"
  /// und „fertig". Genau der Sprung, den „Eine Anzeige, die es gibt, hat
  /// genau eine Form" verhindern soll.
  ///
  /// Reserviert wird die **gemessene** Breite von [platzhalter], nicht
  /// eine getippte Zahl — dieselbe Messung, die [Platzhalter] selbst
  /// anstellt.
  final bool platzhalterSichtbar;

  /// Vergrößert die Symbolkachel — `.ic.lg` im Entwurf, etwa für die
  /// Übungszeile „Drücken — Brust, Schulter, Trizeps".
  final bool big;

  /// Setzt **Titel und Untertitel** als graue Form statt als Text (#501).
  ///
  /// Gebraucht von „Heute Training" auf Home: Die Zeile hat keine
  /// Wertspalte, die grau werden könnte, und ihr Titel ist im Ruhetag
  /// eine Aussage über die Datenlage („Ruhetag"). Die darf erst stehen,
  /// wenn nachgesehen wurde — sonst ist es Fehler `01` in neuer
  /// Verpackung.
  ///
  /// Die Form misst sich am Text selbst, der sie ablöst; sie ist also so
  /// hoch und so breit wie er, und beim Eintreffen springt nichts
  /// (`Platzhalter`). Auf dem Board entspricht dem `skel(…)` in `title`
  /// und `subtitle` von `row(…)` (`docs/screens/components.js`).
  final bool laedt;

  /// Feste Zeilenzahl für Titel und Untertitel — `null` heißt „so viele
  /// Zeilen, wie der Text braucht" und ist die Vorgabe (#501).
  ///
  /// Gebraucht wird das dort, wo **dieselbe** Zeile je nach Datenlage
  /// einen längeren oder kürzeren Satz trägt: „Heute Training" auf Home
  /// wechselt zwischen „Heute · 7 Übungen · ca. 70 min" und „Heute kein
  /// Gym · Spaziergang und Mobility". Ohne reservierte Höhe wüchse die
  /// Karte am Ruhetag und alles darunter rutschte (`CLAUDE.md`, „Eine
  /// Anzeige, die es gibt, hat genau eine Form").
  ///
  /// Reserviert wird die Höhe, gekappt wird bei derselben Zahl — beides
  /// zusammen, sonst ist der Sprung nur verschoben.
  final int? titelZeilen;
  final int? untertitelZeilen;

  /// Der Text — oder, solange [laedt], seine Form. Mit [zeilen] in
  /// reservierter Höhe und auf dieselbe Zahl gekappt.
  Widget _textOderForm(String text, TextStyle stil, int? zeilen) {
    final inhalt = laedt
        ? Platzhalter(beispiel: text, stil: stil)
        : Text(
            text,
            style: stil,
            maxLines: zeilen,
            overflow: zeilen == null ? null : TextOverflow.ellipsis,
          );
    if (zeilen == null) return inhalt;
    return FesteZeilen(zeilen: zeilen, stil: stil, child: inhalt);
  }

  static const _kachelGroesse = 30.0;
  static const _kachelGroesseGross = 35.0;
  static const _kachelRadius = 8.0;
  static const _kachelRadiusGross = 10.0;
  static const _symbolGroesse = 15.0;
  static const _symbolGroesseGross = 18.0;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final kachelGroesse = big ? _kachelGroesseGross : _kachelGroesse;
    final kachelRadius = big ? _kachelRadiusGross : _kachelRadius;
    final symbolGroesse = big ? _symbolGroesseGross : _symbolGroesse;
    final value = this.value;
    // Einmal gebaut, zweimal gebraucht: Der Platzhalter misst sich an
    // genau der Schrift, die ihn später ablöst — sonst hat die graue Form
    // eine andere Höhe als die Zahl, und die Zeile springt doch.
    final wertStil = Typografie.tabularNumbers(
      Typografie.numeric(
        TypografieGroesse.callout,
        gewicht: FontWeight.w600,
      ).copyWith(color: ink),
    );

    final zeile = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 46),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Container(
              width: kachelGroesse,
              height: kachelGroesse,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(kachelRadius),
              ),
              child: Icon(
                Symbole.aufloesen(symbol),
                size: symbolGroesse,
                color: symbolFarbe == null
                    ? CupertinoColors.white
                    : CupertinoDynamicColor.resolve(symbolFarbe!, context),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _textOderForm(
                    title,
                    TextStyle(fontWeight: FontWeight.w600, color: ink),
                    titelZeilen,
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: _textOderForm(
                        subtitle!,
                        TextStyle(fontSize: 12, color: muted),
                        untertitelZeilen,
                      ),
                    ),
                ],
              ),
            ),
            if (value != null) ...[
              const SizedBox(width: 8),
              Text(value, style: wertStil),
            ] else if (platzhalter != null) ...[
              const SizedBox(width: 8),
              if (platzhalterSichtbar)
                Platzhalter(beispiel: platzhalter!, stil: wertStil)
              else
                SizedBox.fromSize(
                  size: textMass(context, platzhalter!, wertStil),
                ),
            ],
            // Der Chevron ist eine Aussage ("das führt irgendwohin"), keine
            // Verzierung — er erscheint deshalb nur, wenn die Zeile auch
            // wirklich antippbar ist (`onTap` gesetzt). Ohne diese Bedingung
            // trüge eine abgeblendete, nicht tippbare Zeile (Mehr-Menü,
            // Task 11) trotzdem einen Pfeil und sagte damit optisch das
            // Gegenteil ihres eigenen Untertitels — genau das Muster, gegen
            // das sich `docs/screens/pruefen.mjs` am Entwurfsboard richtet.
            if (this.onTap != null) ...[
              const SizedBox(width: 8),
              Icon(
                CupertinoIcons.chevron_right,
                size: 13,
                color: muted.withValues(alpha: 0.7),
              ),
            ],
          ],
        ),
      ),
    );

    final onTap = this.onTap;
    if (onTap == null) return zeile;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: zeile,
    );
  }
}
