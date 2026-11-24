// Bausteine des Schirms „KI-Zugang" (#339) und seiner Blätter — die
// Dart-Entsprechungen der Bausteine aus `docs/screens/components.js`, die
// `docs/screens/screens/ki-zugang.js` benutzt: `groupHead`, `card`,
// `statRow`, `noteBox`, `disclaimer`, `sheet`, `formHead`, `formFoot`,
// `formCard`, `btn` und die beiden Zeilen `tuerZeile`/`anzeigeZeile`.
//
// Mechanik, kein Fachinhalt — deshalb hier und nicht im Schirm, damit
// Schirm und Blätter dieselbe Form benutzen.
import 'package:flutter/cupertino.dart';

import '../design/inset_card.dart';
import '../design/palette.dart';
import '../design/platzhalter.dart';

Color _farbe(BuildContext context, Color farbe) =>
    CupertinoDynamicColor.resolve(farbe, context);

/// `groupHead` — versal, klein, gedämpft.
class KiGruppenKopf extends StatelessWidget {
  const KiGruppenKopf(this.titel, {super.key});

  final String titel;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(23, 20, 23, 9),
    child: Text(
      titel.toUpperCase(),
      style: TextStyle(
        fontSize: 11.5,
        height: 1,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.1,
        color: _farbe(context, Palette.muted),
      ),
    ),
  );
}

/// `card` — die Kartenfläche der App ([InsetCard], #384), die Zeilen mit
/// Trennlinien.
class KiKarte extends StatelessWidget {
  const KiKarte({super.key, required this.zeilen, this.abstandOben = 0});

  final List<Widget> zeilen;
  final double abstandOben;

  @override
  Widget build(BuildContext context) {
    final linie = _farbe(context, Palette.line);
    return Padding(
      padding: EdgeInsets.fromLTRB(14, abstandOben, 14, 0),
      // `InsetCard` beschneidet die ganze Karte, nicht die Zeile
      // (`CLAUDE.md`).
      child: InsetCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < zeilen.length; i++) ...[
              if (i > 0) Container(height: 0.5, color: linie),
              zeilen[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// `tuerZeile`/`anzeigeZeile` — Beschriftung links, Wert rechts, bei einer
/// Tür der Winkel dahinter.
///
/// **Der Winkel steht auch, wenn die Tür gerade nicht aufgeht** (ohne
/// Schlüssel gibt es kein Modell zu wählen): Die Zeile behält ihre Form,
/// nur die Wirkung fällt weg.
class KiZeile extends StatelessWidget {
  const KiZeile({
    super.key,
    required this.titel,
    required this.wert,
    this.farbe,
    this.tuer = false,
    this.onTap,
    this.semantik,
    this.unterWert,
  });

  final String titel;

  /// Der Wert — `null` heißt „lädt", dann steht die graue Form da.
  final String? wert;

  /// Farbe des Werts; ohne Angabe `river`.
  final Color? farbe;

  /// Zeichnet den Winkel.
  final bool tuer;

  final VoidCallback? onTap;

  /// Vorlesetext des Werts, wenn er vom Zeichen abweicht (`–/–`).
  final String? semantik;

  /// Eine kleine zweite Zeile unter dem Wert, in derselben Farbe —
  /// „Voreinstellung" unter dem Modell. Als eigene Zeile, weil „Modell ·
  /// Voreinstellung" in einer Zeile auf dem iPhone 17 Pro abgeschnitten
  /// wurde.
  final String? unterWert;

  @override
  Widget build(BuildContext context) {
    final stil = TextStyle(
      fontSize: 15,
      color: _farbe(context, farbe ?? Palette.river),
    );
    final wert = this.wert;
    final zeile = Padding(
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      child: Row(
        children: [
          Text(titel, style: const TextStyle(fontSize: 15)),
          const SizedBox(width: 10),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: wert == null
                  ? Platzhalter(beispiel: 'gemini-3.6-flash', stil: stil)
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          wert,
                          style: stil,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          semanticsLabel: semantik,
                        ),
                        if (unterWert case final unter?)
                          Text(
                            unter,
                            style: stil.copyWith(fontSize: 12),
                            maxLines: 1,
                            textAlign: TextAlign.end,
                          ),
                      ],
                    ),
            ),
          ),
          if (tuer) ...[
            const SizedBox(width: 10),
            Icon(
              CupertinoIcons.chevron_right,
              size: 12,
              color: _farbe(context, Palette.muted),
            ),
          ],
        ],
      ),
    );
    if (onTap == null) return zeile;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: zeile,
    );
  }
}

/// `statRow` — Beschriftung links, Zahl rechts.
class KiStatZeile extends StatelessWidget {
  const KiStatZeile({
    super.key,
    required this.titel,
    required this.wert,
    this.wertSchluessel,
  });

  final String titel;

  /// `null` heißt „lädt".
  final String? wert;

  final Key? wertSchluessel;

  @override
  Widget build(BuildContext context) {
    final stil = TextStyle(
      fontSize: 15,
      color: _farbe(context, Palette.ink),
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final wert = this.wert;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(
        children: [
          Text(titel, style: const TextStyle(fontSize: 14.5)),
          const SizedBox(width: 10),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: KeyedSubtree(
                key: wertSchluessel,
                child: wert == null
                    ? Platzhalter(beispiel: '0,00 \$ von 10,00 \$', stil: stil)
                    : Text(
                        wert,
                        style: stil,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Der Ton eines Hinweises — `NoteKind` aus `components.js`.
enum KiTon {
  /// Gelb (`bib`).
  neutral,

  /// Rot (`warn`).
  warnung,
}

/// `noteBox` — Fläche mit farbiger Kante links. Die Kante liegt **in** der
/// beschnittenen Form; ein gerundeter Balken liefe über die Ecke.
class KiNotiz extends StatelessWidget {
  const KiNotiz({
    super.key,
    required this.ton,
    required this.text,
    this.rand = const EdgeInsets.fromLTRB(14, 10, 14, 0),
  });

  final KiTon ton;
  final String text;
  final EdgeInsets rand;

  @override
  Widget build(BuildContext context) {
    final farbe = _farbe(
      context,
      ton == KiTon.warnung ? Palette.warn : Palette.bib,
    );
    final flaeche = Color.alphaBlend(
      farbe.withValues(alpha: 0.07),
      _farbe(context, Palette.surface),
    );
    return Padding(
      padding: rand,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: flaeche,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: farbe.withValues(alpha: 0.22),
              width: 0.5,
            ),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: farbe),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 13, 11),
                    child: Text(
                      text,
                      style: TextStyle(
                        fontSize: 14.5,
                        height: 1.42,
                        color: _farbe(context, Palette.ink),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// `disclaimer` — der kleine gedämpfte Satz unter einer Gruppe.
class KiFussnote extends StatelessWidget {
  const KiFussnote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(21, 14, 21, 0),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12,
        height: 1.4,
        color: _farbe(context, Palette.muted),
      ),
    ),
  );
}

/// `btn` — `fill` (voll) oder `tint` (getönt), über die volle Breite.
class KiKnopf extends StatelessWidget {
  const KiKnopf({
    super.key,
    required this.titel,
    required this.farbe,
    required this.voll,
    required this.onPressed,
  });

  /// `null` heißt „lädt" — dieselbe Form, grau.
  final String? titel;
  final Color farbe;
  final bool voll;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final ton = _farbe(context, farbe);
    final flaeche = _farbe(context, Palette.surface);
    final titel = this.titel;
    final stil = TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: voll ? flaeche : ton,
    );
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 15),
      color: voll ? ton : ton.withValues(alpha: 0.13),
      disabledColor: voll
          ? ton.withValues(alpha: 0.45)
          : ton.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(10),
      onPressed: onPressed,
      child: titel == null
          ? Platzhalter(beispiel: 'Schlüssel hinterlegen', stil: stil)
          : Text(titel, style: stil),
    );
  }
}

// ---------------------------------------------------------------------------
// Blätter

/// `sheet` — das halbhohe Blatt: Griff, Leiste mit zwei Plätzen, Inhalt.
///
/// **Feste Höhe**: Ein Blatt, das mit seinem Inhalt wächst, spränge beim
/// Prüfen. Unten wird durchgezeichnet, nicht abgeschnitten — die
/// halbtransparente Tastatur legt sich darüber (flutter#179482).
class KiBlatt extends StatelessWidget {
  const KiBlatt({
    super.key,
    required this.titel,
    required this.abbrechen,
    required this.inhalt,
    this.rechts,
  });

  final String titel;

  /// Der linke Platz, „Abbrechen".
  final Widget abbrechen;

  /// Der rechte Platz; ohne Angabe bleibt er leer, aber breit.
  final Widget? rechts;

  final List<Widget> inhalt;

  @override
  Widget build(BuildContext context) {
    final medien = MediaQuery.of(context);
    final tastatur = medien.viewInsets.bottom;
    return Container(
      height: medien.size.height * 0.64,
      decoration: BoxDecoration(
        color: _farbe(context, Palette.bg),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
      ),
      child: DefaultTextStyle(
        style: TextStyle(fontSize: 15, color: _farbe(context, Palette.ink)),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: _farbe(context, Palette.line),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 2, 8, 0),
              child: Row(
                children: [
                  SizedBox(
                    width: 96,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: abbrechen,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      titel,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 96,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: rechts ?? const SizedBox.shrink(),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(bottom: 18 + tastatur),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: inhalt,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ein Platz in der Leiste eines Blatts — „Abbrechen", „Sichern".
class KiLeistenKnopf extends StatelessWidget {
  const KiLeistenKnopf({
    super.key,
    required this.titel,
    required this.onPressed,
  });

  final String titel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    minimumSize: const Size(44, 36),
    onPressed: onPressed,
    child: Text(titel, style: const TextStyle(fontSize: 15)),
  );
}

/// `formHead`.
class KiFormKopf extends StatelessWidget {
  const KiFormKopf(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(32, 14, 32, 6),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        color: _farbe(context, Palette.muted),
      ),
    ),
  );
}

/// `formFoot`.
class KiFormFuss extends StatelessWidget {
  const KiFormFuss(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(32, 7, 32, 0),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12.5,
        height: 1.4,
        color: _farbe(context, Palette.muted),
      ),
    ),
  );
}

/// `formCard` — wie [KiKarte], mit dem Randabstand eines Formulars.
class KiFormKarte extends StatelessWidget {
  const KiFormKarte({super.key, required this.zeilen});

  final List<Widget> zeilen;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 2),
    child: KiKarte(zeilen: zeilen),
  );
}
