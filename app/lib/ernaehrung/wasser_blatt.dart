// Das Blatt „Wasser heute" (#360): die Gläser des offenen Tages ändern,
// löschen und frei eintragen.
//
// Aufbau nach `docs/screens/screens/wasser.js` (Zustände `liste`,
// `wischen`, `aendern`, `menge`, `leer`), von Tim am 05.11.2026
// freigegeben. Begründungen in
// `docs/superpowers/specs/2026-11-03-ernaehrung-design.md`, Abschnitt
// „Gläser ändern und löschen (#360)".
//
// Zustände und Übergänge sind durch `app/test/ernaehrung/wasser_blatt_test.dart`
// vorgegeben — diese Datei darf die Tests ausführen, aber nicht verändern
// (`CLAUDE.md`).
//
// **Ein Blatt, kein Schirm** (`showCupertinoModalPopup`, wie
// `gewicht_eintragen.dart`). „Glas ändern" ist kein zweites Blatt, sondern
// ein Zustand **dieses** Blattes: Die Glaszeilen tragen keinen Winkel, weil
// sie keinen Schirm öffnen.
//
// **Kein `Messwert`.** Gläser sind Tims eigene Daten; leer heißt leer. Das
// Blatt schreibt über denselben `WasserNotifier`, den die Wasserzeile auf
// dem Tag-Schirm beobachtet — die Summe dort folgt ohne Zutun.
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../health/health_types.dart' show datumAusTag;

import '../data/wasser_repository.dart';
import '../design/formatierung.dart';
import '../design/inset_card.dart';
import '../design/palette.dart';
import '../design/zahlen.dart';
import 'ernaehrung_provider.dart';
import 'wasser_bausteine.dart';
import 'wasser_provider.dart';

/// Öffnet das Blatt für den Tag [tagesSchluessel] — den **offenen** Tag
/// des Schirms, nicht stur heute.
Future<void> zeigeWasserBlatt(
  BuildContext context, {
  required String tagesSchluessel,
}) => showCupertinoModalPopup<void>(
  context: context,
  builder: (_) => WasserBlatt(
    key: const Key('wasser-blatt'),
    tagesSchluessel: tagesSchluessel,
  ),
);

/// Eine gültige Menge in Millilitern, oder `null`.
///
/// Ganze Milliliter von 1 bis 5000 — die Grenze hat der Bauende gesetzt,
/// nicht Tim (Spec). Sie hält einen Tippfehler wie `33000` draußen, ohne
/// eine echte Flasche abzulehnen.
double? gueltigeMenge(String text) {
  final zahl = int.tryParse(text.trim());
  if (zahl == null || zahl < 1 || zahl > 5000) return null;
  return zahl.toDouble();
}

class WasserBlatt extends ConsumerStatefulWidget {
  const WasserBlatt({super.key, required this.tagesSchluessel});

  final String tagesSchluessel;

  @override
  ConsumerState<WasserBlatt> createState() => _WasserBlattZustand();
}

class _WasserBlattZustand extends ConsumerState<WasserBlatt> {
  /// Das Glas, das gerade geändert wird — `null` heißt „Liste".
  WasserEintrag? _inArbeit;

  /// Die Kennungen weggewischter Gläser. **Sie verschwinden sofort**, nicht
  /// erst nach dem Schreiben: Ein `Dismissible`, der nach dem Wegwischen
  /// noch im Baum steht, bricht beim nächsten Neubau (wie `mahlzeit_view`).
  final Set<int> _weggewischt = {};

  final TextEditingController _freieMenge = TextEditingController();
  final TextEditingController _neueMenge = TextEditingController();

  /// Läuft gerade ein Schreibzugriff aus „Glas ändern".
  bool _laeuft = false;

  @override
  void initState() {
    super.initState();
    // Die Knöpfe hängen am Inhalt der Felder, nicht an einem Abschicken.
    _freieMenge.addListener(() => setState(() {}));
    _neueMenge.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _freieMenge.dispose();
    _neueMenge.dispose();
    super.dispose();
  }

  WasserNotifier get _notifier =>
      ref.read(wasserProvider(widget.tagesSchluessel).notifier);

  @override
  Widget build(BuildContext context) {
    final bg = CupertinoDynamicColor.resolve(Palette.bg, context);
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final glaeser = ref.watch(wasserProvider(widget.tagesSchluessel)).value;
    final tag = ref.watch(ernaehrungsTagProvider(widget.tagesSchluessel));

    // Unten durchzeichnen statt abschneiden (`CLAUDE.md`, flutter#179482).
    final tastatur = MediaQuery.of(context).viewInsets.bottom;
    final inArbeit = _inArbeit;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
      ),
      // **Feste Höhe** — das erste Glas, das „Noch kein Glas" ablöst, lässt
      // das Blatt nicht wachsen.
      height: MediaQuery.of(context).size.height * 0.62,
      child: DefaultTextStyle(
        style: TextStyle(color: ink, fontSize: 15),
        child: inArbeit == null
            ? _liste(context, glaeser, tag, tastatur)
            : _aendern(context, inArbeit, tastatur),
      ),
    );
  }

  // ── Liste ──────────────────────────────────────────────────────────────

  Widget _liste(
    BuildContext context,
    List<WasserEintrag>? glaeser,
    ErnaehrungsTag tag,
    double tastatur,
  ) {
    final sichtbar = glaeser
        ?.where((g) => !_weggewischt.contains(g.id))
        .toList();
    final ausEssen = gegessenWerte(tag)?.wasserMl;
    final menge = gueltigeMenge(_freieMenge.text);

    return Column(
      children: [
        BlattKopf(
          // Nur der heutige Tag heißt „heute"; auf einem geblätterten Tag
          // wäre das eine falsche Auskunft über gestrige Gläser.
          titel: tag.istHeute ? 'Wasser heute' : 'Wasser',
          rechts: blattKopfKnopf(
            key: const Key('wasser-blatt-fertig'),
            titel: 'Fertig',
            fett: true,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 24 + tastatur),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BlattKapitel(
                  'Gläser · ${Format.wochentagUndDatum(kalendertag(datumAusTag(widget.tagesSchluessel)))}',
                ),
                InsetCard(child: _glaeserKarte(context, sichtbar)),
                const BlattFuss(
                  'Nach links wischen löscht ein Glas, Tippen ändert die '
                  'Menge. Die Kopie in Apple Health geht mit.',
                ),
                const BlattKapitel('Außerdem'),
                InsetCard(
                  child: AusEssenZeile(
                    key: const Key('wasser-aus-essen'),
                    ml: ausEssen == null || ausEssen <= 0 ? null : ausEssen,
                  ),
                ),
                const BlattFuss(
                  'Wasser in gebuchten Lebensmitteln zählt mit. Ändern lässt '
                  'es sich nur am Eintrag in der Mahlzeit.',
                ),
                const BlattKapitel('Eintragen'),
                InsetCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      MengenFeld(
                        feldKey: const Key('wasser-menge-feld'),
                        beschriftung: 'Menge …',
                        controller: _freieMenge,
                        platzhalter: 'in ml',
                      ),
                      const Trennlinie(),
                      aktionsZeile(
                        context,
                        key: const Key('wasser-menge-eintragen'),
                        titel: 'Eintragen',
                        // Grau, nicht weg — die Zeile behält ihre Form.
                        onPressed: menge == null
                            ? null
                            : () => _trageFreieMengeEin(menge),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(
                    children: [
                      WasserKnopf(
                        key: const Key('wasser-blatt-plus-250'),
                        titel: '+ 250 ml',
                        onPressed: () => _trageEin(250),
                      ),
                      const SizedBox(width: 8),
                      WasserKnopf(
                        key: const Key('wasser-blatt-plus-500'),
                        titel: '+ 500 ml',
                        onPressed: () => _trageEin(500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _glaeserKarte(BuildContext context, List<WasserEintrag>? glaeser) {
    // Noch nie gelesen: dieselbe Form in Grau, **ohne** „Noch kein Glas" —
    // das wäre eine Behauptung über eine Datenlage, die noch niemand kennt.
    if (glaeser == null) return const GlasZeile.laedt();
    if (glaeser.isEmpty) {
      return const GlasZeile.keinGlas(key: Key('wasser-kein-glas'));
    }

    final zeilen = <Widget>[];
    for (final glas in glaeser) {
      if (zeilen.isNotEmpty) zeilen.add(const Trennlinie());
      zeilen.add(
        Dismissible(
          key: Key('wasser-glas-${glas.id}'),
          direction: DismissDirection.endToStart,
          // Ohne Nachschrumpfen: Die Zeile verschwindet, weil das Blatt sie
          // beim nächsten Bauen weglässt (wie `mahlzeit_view`).
          resizeDuration: null,
          background: const SizedBox.shrink(),
          secondaryBackground: const Loeschfeld(),
          onDismissed: (_) => _wischeWeg(glas),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _oeffne(glas),
            child: GlasZeile(
              uhrzeit: wanduhr(glas.zeitpunkt),
              menge: '${formatNumber(glas.mengeMl)} ml',
            ),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: zeilen,
    );
  }

  Future<void> _trageEin(double mengeMl) =>
      trageWasserEin(context, ref, widget.tagesSchluessel, mengeMl);

  Future<void> _trageFreieMengeEin(double mengeMl) async {
    _freieMenge.clear();
    await _trageEin(mengeMl);
  }

  Future<void> _wischeWeg(WasserEintrag glas) async {
    final id = glas.id;
    if (id == null) return;
    final notifier = _notifier;
    setState(() => _weggewischt.add(id));
    await notifier.loesche(glas);
  }

  void _oeffne(WasserEintrag glas) {
    _neueMenge.text = formatNumber(glas.mengeMl);
    setState(() => _inArbeit = glas);
  }

  // ── Glas ändern ───────────────────────────────────────────────────────

  Widget _aendern(BuildContext context, WasserEintrag glas, double tastatur) {
    final menge = gueltigeMenge(_neueMenge.text);
    final warn = CupertinoDynamicColor.resolve(Palette.warn, context);

    return Column(
      key: const Key('wasser-aendern'),
      children: [
        BlattKopf(
          titel: 'Glas ändern',
          links: blattKopfKnopf(
            key: const Key('wasser-aendern-abbrechen'),
            titel: 'Abbrechen',
            onPressed: _laeuft ? null : _zurueck,
          ),
          rechts: blattKopfKnopf(
            key: const Key('wasser-aendern-sichern'),
            titel: 'Sichern',
            fett: true,
            onPressed: _laeuft || menge == null
                ? null
                : () => _sichere(glas, menge),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 24 + tastatur),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const BlattKapitel('Menge'),
                InsetCard(
                  child: MengenFeld(
                    feldKey: const Key('wasser-aendern-feld'),
                    beschriftung: 'Milliliter',
                    controller: _neueMenge,
                    autofocus: true,
                  ),
                ),
                BlattFuss(
                  'Bisher ${formatNumber(glas.mengeMl)} ml. Dasselbe Glas, '
                  'kein zweites — die Kopie in Apple Health wird ersetzt.',
                ),
                const BlattKapitel('Getrunken'),
                InsetCard(
                  child: AngabeZeile(
                    key: const Key('wasser-aendern-uhrzeit'),
                    beschriftung: 'Uhrzeit',
                    wert: wanduhr(glas.zeitpunkt),
                  ),
                ),
                const BlattFuss(
                  'Die Uhrzeit bleibt, wie sie eingetragen wurde.',
                ),
                const SizedBox(height: 14),
                InsetCard(
                  child: aktionsZeile(
                    context,
                    key: const Key('wasser-aendern-loeschen'),
                    titel: 'Glas löschen',
                    farbe: warn,
                    onPressed: _laeuft ? null : () => _loesche(glas),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _zurueck() => setState(() => _inArbeit = null);

  Future<void> _sichere(WasserEintrag glas, double mengeMl) async {
    final notifier = _notifier;
    setState(() => _laeuft = true);
    try {
      await notifier.aendere(glas, mengeMl);
    } finally {
      if (mounted) {
        setState(() {
          _laeuft = false;
          _inArbeit = null;
        });
      }
    }
  }

  Future<void> _loesche(WasserEintrag glas) async {
    final id = glas.id;
    if (id == null) return;
    final notifier = _notifier;
    setState(() {
      _weggewischt.add(id);
      _inArbeit = null;
    });
    await notifier.loesche(glas);
  }
}
