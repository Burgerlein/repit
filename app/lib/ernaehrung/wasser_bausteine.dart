// Bausteine des Wasserblatts (#360) und der Wasserzeile (#311) — eigene
// Datei, weil Views klein bleiben (`CLAUDE.md`). Das Blatt selbst steht in
// `wasser_blatt.dart`, die Zeile auf dem Tag-Schirm in
// `ernaehrung_abschnitte.dart`.
//
// Die Formen folgen `components.js`: `sheet` (Kopf mit zwei Plätzen),
// `formHead`, `formFoot`, `formCard`, `statRow` und `btn(…, 'tint',
// 'river')`.
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../design/palette.dart';
import '../design/platzhalter.dart';
import '../design/typografie.dart';
import '../design/zahlen.dart';
import 'buchungs_blatt.dart' show zeigeHealthSchreibHinweis;
import 'erfassen_provider.dart' show healthSchreibHinweisProvider;
import 'wasser_provider.dart';

/// Trägt [mengeMl] auf den Tag [tagesSchluessel] ein und zeigt danach,
/// falls nötig, den Hinweis „Nicht in Apple Health" — einmal je App-Lauf,
/// derselbe wie beim Essen (#283). Der **eine** Weg für die Knöpfe auf dem
/// Schirm und im Blatt und für „Menge …".
Future<void> trageWasserEin(
  BuildContext context,
  WidgetRef ref,
  String tagesSchluessel,
  double mengeMl,
) async {
  await ref.read(wasserProvider(tagesSchluessel).notifier).trageEin(mengeMl);
  if (!context.mounted) return;
  if (ref.read(healthSchreibHinweisProvider)) {
    await zeigeHealthSchreibHinweis(context);
    ref.read(healthSchreibHinweisProvider.notifier).gesehen();
  }
}

/// Die Berliner Wanduhrzeit eines Zeitpunkts, „13:40" — über den Kern,
/// nicht über die Zeitzone des Geräts.
String wanduhr(DateTime zeitpunkt) {
  final (stunde, minute) = BerlinCalendar.wallClock(zeitpunkt);
  return '${stunde.toString().padLeft(2, '0')}:'
      '${minute.toString().padLeft(2, '0')}';
}

/// Milliliter als Liter mit bis zu zwei Nachkommastellen, ohne
/// nachgehängte Null: „0,25", „1,5", „2" (#408 — 250 ml standen vorher
/// als „0,3").
///
/// Gerundet wird auf ganze 10 ml, bevor durch 1000 geteilt wird: `2.345`
/// ist als `double` knapp kleiner als 2,345, und `toStringAsFixed(2)`
/// machte daraus „2,34". `234.5` dagegen ist exakt und rundet auf.
String liter(double milliliter) {
  final hundertstel = (milliliter / 10).round();
  return formatNumber(
    hundertstel / 100,
    nachkommastellen: 2,
  ).replaceFirst(RegExp(r',?0+$'), '');
}

/// `btn(…, 'tint', 'river')` aus dem Entwurf: getönte Fläche, Schrift in
/// Flussblau.
class WasserKnopf extends StatelessWidget {
  const WasserKnopf({super.key, required this.titel, required this.onPressed});

  final String titel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final river = CupertinoDynamicColor.resolve(Palette.river, context);
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size(44, 36),
      onPressed: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
        decoration: BoxDecoration(
          color: river.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          titel,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: river,
          ),
        ),
      ),
    );
  }
}

// ── Kopf, Kapitel, Fuß ──────────────────────────────────────────────────

/// Die Kopfzeile des Blattes: links · Titel · rechts. Ein leerer Platz
/// bleibt gleich breit, damit der Titel mittig steht.
class BlattKopf extends StatelessWidget {
  const BlattKopf({super.key, required this.titel, this.links, this.rechts});

  final String titel;
  final Widget? links;
  final Widget? rechts;

  static const _platz = 96.0;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          SizedBox(
            width: _platz,
            child: Align(alignment: Alignment.centerLeft, child: links),
          ),
          Expanded(
            child: Text(
              titel,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: ink,
              ),
            ),
          ),
          SizedBox(
            width: _platz,
            child: Align(alignment: Alignment.centerRight, child: rechts),
          ),
        ],
      ),
    );
  }
}

/// Ein Knopf im Kopf. „Inaktiv" heißt `onPressed == null`. Eine Funktion
/// und kein eigenes Widget, damit [key] auf dem `CupertinoButton` selbst
/// liegt.
Widget blattKopfKnopf({
  Key? key,
  required String titel,
  required VoidCallback? onPressed,
  bool fett = false,
}) => CupertinoButton(
  key: key,
  padding: const EdgeInsets.symmetric(horizontal: 8),
  minimumSize: const Size(44, 36),
  onPressed: onPressed,
  child: Text(
    titel,
    style: TextStyle(fontWeight: fett ? FontWeight.w600 : FontWeight.w400),
  ),
);

/// `formHead` — die Überschrift über einer Karte.
class BlattKapitel extends StatelessWidget {
  const BlattKapitel(this.titel, {super.key});

  final String titel;

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 7, left: 4),
      child: Text(
        titel.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: muted,
        ),
      ),
    );
  }
}

/// `formFoot` — der erklärende Satz unter einer Karte. **Feste
/// Zeilenzahl** (`CLAUDE.md`, „Mehrzeilige Erläuterungen bekommen eine
/// feste Zeilenzahl").
class BlattFuss extends StatelessWidget {
  const BlattFuss(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 7, 4, 0),
      child: SizedBox(
        height: 32,
        child: Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, height: 1.33, color: muted),
        ),
      ),
    );
  }
}

/// Die Haarlinie zwischen zwei Zeilen einer Karte.
class Trennlinie extends StatelessWidget {
  const Trennlinie({super.key});

  @override
  Widget build(BuildContext context) => Container(
    height: 1,
    color: CupertinoDynamicColor.resolve(Palette.line, context),
  );
}

// ── Zeilen ──────────────────────────────────────────────────────────────

/// Eine Zeile der Gläserkarte — **eine Höhe für alle drei Fälle**: ein
/// Glas, „Noch kein Glas" und die graue Ladeform. So tritt das erste Glas
/// an die Stelle des Leerzustands, ohne dass etwas springt.
class GlasZeile extends StatelessWidget {
  const GlasZeile({super.key, required this.uhrzeit, required this.menge})
    : _fall = _Fall.glas;

  const GlasZeile.keinGlas({super.key})
    : uhrzeit = 'Noch kein Glas',
      menge = ohneWert,
      _fall = _Fall.keinGlas;

  const GlasZeile.laedt({super.key})
    : uhrzeit = '',
      menge = '',
      _fall = _Fall.laedt;

  final String uhrzeit;
  final String menge;
  final _Fall _fall;

  static const hoehe = 46.0;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final wertStil = Typografie.tabularNumbers(
      Typografie.numeric(TypografieGroesse.callout)
          .copyWith(color: _fall == _Fall.glas ? ink : muted),
    );

    final Widget links = switch (_fall) {
      _Fall.laedt => Platzhalter(beispiel: '00:00', stil: wertStil),
      _Fall.glas => Text(uhrzeit, style: wertStil),
      _Fall.keinGlas => Text(uhrzeit, style: TextStyle(color: muted)),
    };
    final Widget rechts = _fall == _Fall.laedt
        ? Platzhalter(beispiel: '250 ml', stil: wertStil)
        : Text(menge, style: wertStil);

    return Semantics(
      label: switch (_fall) {
        _Fall.glas => 'Glas, $uhrzeit, $menge',
        // Der Zustand, nicht das Zeichen (`CLAUDE.md`).
        _Fall.keinGlas => 'Noch kein Glas',
        _Fall.laedt => 'Gläser werden gelesen',
      },
      excludeSemantics: true,
      child: SizedBox(
        height: hoehe,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(children: [links, const Spacer(), rechts]),
        ),
      ),
    );
  }
}

enum _Fall { glas, keinGlas, laedt }

/// „Aus Lebensmitteln" — `statRow(…, 'gebucht')`. Keine Tür: Ändern
/// lässt sich der Anteil nur am Eintrag in der Mahlzeit. [ml] `null`
/// heißt „kein Wasser aus Lebensmitteln" und steht als `–/–` da.
class AusEssenZeile extends StatelessWidget {
  const AusEssenZeile({super.key, required this.ml});

  final double? ml;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final ml = this.ml;
    final wert = ml == null ? ohneWert : '${liter(ml)} l';

    return Semantics(
      label: ml == null
          ? 'Aus Lebensmitteln, keine Werte'
          : 'Aus Lebensmitteln, $wert, gebucht',
      excludeSemantics: true,
      child: SizedBox(
        height: GlasZeile.hoehe,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              const Text('Aus Lebensmitteln'),
              if (ml != null) ...[
                const SizedBox(width: 8),
                Text(
                  'GEBUCHT',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                    color: muted,
                  ),
                ),
              ],
              const Spacer(),
              Text(
                wert,
                style: Typografie.tabularNumbers(
                  Typografie.numeric(TypografieGroesse.callout)
                      .copyWith(color: ml == null ? muted : ink),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Beschriftung links, Wert rechts, keine Tür — `statRow` ohne `opens`.
class AngabeZeile extends StatelessWidget {
  const AngabeZeile({
    super.key,
    required this.beschriftung,
    required this.wert,
  });

  final String beschriftung;
  final String wert;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    return SizedBox(
      height: GlasZeile.hoehe,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            Text(beschriftung),
            const Spacer(),
            Text(
              wert,
              style: Typografie.tabularNumbers(
                Typografie.numeric(TypografieGroesse.callout)
                    .copyWith(color: ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ein Zahlenfeld in einer Formularzeile: Beschriftung links, Eingabe
/// rechts in Flussblau. [feldKey] liegt auf dem Feld selbst.
class MengenFeld extends StatelessWidget {
  const MengenFeld({
    super.key,
    required this.feldKey,
    required this.beschriftung,
    required this.controller,
    this.platzhalter,
    this.autofocus = false,
  });

  final Key feldKey;
  final String beschriftung;
  final TextEditingController controller;
  final String? platzhalter;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final river = CupertinoDynamicColor.resolve(Palette.river, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    return SizedBox(
      height: GlasZeile.hoehe,
      child: Padding(
        padding: const EdgeInsets.only(left: 14, right: 6),
        child: Row(
          children: [
            Text(beschriftung),
            Expanded(
              child: CupertinoTextField(
                key: feldKey,
                controller: controller,
                placeholder: platzhalter,
                placeholderStyle: TextStyle(color: muted),
                decoration: null,
                textAlign: TextAlign.right,
                keyboardType: TextInputType.number,
                autofocus: autofocus,
                style: TextStyle(color: river),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Eine mittige Aktionszeile — `formRow(…, 'action')`. Inaktiv heißt grau,
/// nicht weg. Eine Funktion, damit [key] auf dem `CupertinoButton` liegt.
Widget aktionsZeile(
  BuildContext context, {
  Key? key,
  required String titel,
  required VoidCallback? onPressed,
  Color? farbe,
}) {
  final river = CupertinoDynamicColor.resolve(Palette.river, context);
  return CupertinoButton(
    key: key,
    padding: EdgeInsets.zero,
    minimumSize: const Size.fromHeight(GlasZeile.hoehe),
    onPressed: onPressed,
    child: Text(titel, style: TextStyle(fontSize: 15, color: farbe ?? river)),
  );
}

/// Was hinter einer nach links gezogenen Glaszeile erscheint — dieselbe
/// Form wie in „Mahlzeit".
class Loeschfeld extends StatelessWidget {
  const Loeschfeld({super.key});

  @override
  Widget build(BuildContext context) {
    final warn = CupertinoDynamicColor.resolve(Palette.warn, context);
    return ColoredBox(
      color: warn,
      child: const Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 18),
          child: Text(
            'Löschen',
            style: TextStyle(
              color: CupertinoColors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
