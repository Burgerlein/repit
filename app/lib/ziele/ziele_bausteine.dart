// Bausteine des Ziele-Schirms und des Auszeit-Blatts (#448) — die
// Dart-Entsprechungen von `planHead`, `noteBox`, `formHead`, `formFoot`
// und `formCard` aus `docs/screens/components.js`.
//
// Mechanik, kein Fachinhalt — deshalb hier und nicht im Schirm, damit
// Schirm und Blatt dieselbe Form benutzen.
import 'package:flutter/cupertino.dart';

import '../design/inset_card.dart';
import '../design/palette.dart';

Color _farbe(BuildContext context, Color farbe) =>
    CupertinoDynamicColor.resolve(farbe, context);

/// `planHead` — die Überschrift eines Abschnitts, nicht versal.
class ZieleAbschnittKopf extends StatelessWidget {
  const ZieleAbschnittKopf(this.titel, {super.key});

  final String titel;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(17, 18, 17, 8),
    child: Text(
      titel,
      style: TextStyle(
        fontSize: 16.5,
        fontWeight: FontWeight.w600,
        color: _farbe(context, Palette.ink),
      ),
    ),
  );
}

/// Der Ton eines Hinweises — `NoteKind` aus `components.js`.
enum ZieleTon {
  /// Gelb (`bib`).
  neutral,

  /// Rot (`warn`).
  warnung,
}

/// `noteBox` — Fläche mit farbiger Kante links. Die Kante liegt **in** der
/// beschnittenen Form; ein gerundeter Balken liefe über die Ecke
/// (`CLAUDE.md`).
class ZieleNotiz extends StatelessWidget {
  const ZieleNotiz({
    super.key,
    required this.ton,
    required this.text,
    this.rand = const EdgeInsets.fromLTRB(14, 10, 14, 0),
  });

  final ZieleTon ton;
  final String text;
  final EdgeInsets rand;

  @override
  Widget build(BuildContext context) {
    final farbe = _farbe(
      context,
      ton == ZieleTon.warnung ? Palette.warn : Palette.bib,
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

/// `formHead` — versal, klein, gedämpft.
class ZieleFormKopf extends StatelessWidget {
  const ZieleFormKopf(this.text, {super.key});

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

/// `formFoot` — der gedämpfte Satz unter einer Formulargruppe.
class ZieleFormFuss extends StatelessWidget {
  const ZieleFormFuss(this.text, {super.key});

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

/// `formCard` — die Kartenfläche ([InsetCard]), die Zeilen mit
/// Trennlinien. `InsetCard` beschneidet die ganze Karte, nicht die Zeile.
class ZieleFormKarte extends StatelessWidget {
  const ZieleFormKarte({super.key, required this.zeilen});

  final List<Widget> zeilen;

  @override
  Widget build(BuildContext context) {
    final linie = _farbe(context, Palette.line);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
