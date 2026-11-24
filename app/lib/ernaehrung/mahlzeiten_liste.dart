// Die Mahlzeitenliste des Ernährungs-Tags (#434 unter #374), nach Tims
// YAZIO-Bild (#385): je Mahlzeit das Symbol im Ring, „gegessen / Ziel kcal"
// und ein rundes „+" in die Kamera.
//
// Gebaut nach `docs/screens/screens/ernaehrung.js` (`MAHLZEITEN`,
// Zustände `tag`, `leer`, `laedt`, `kein-ziel`, `ohne-aufteilung`; bis
// Task 8 hießen sie `vorschlag-mahlzeiten*`) und `mahlzeitZeile` in
// `docs/screens/components.js`. Spec
// `docs/superpowers/specs/2026-11-10-mahlzeiten-aufteilung-design.md`,
// Abschnitt „Die Mahlzeitenliste", Vorgaben V8–V12.
//
// Geprüft von `test/ernaehrung/mahlzeiten_liste_test.dart`,
// `mahlzeiten_liste_form_test.dart` und `mahlzeiten_liste_aufteilung_test
// .dart` — diese Datei darf die Tests ausführen, aber nicht verändern
// (`CLAUDE.md`).
//
// **Ziel und Anteil kommen aus `MahlzeitZeile`** und werden hier nicht
// gerechnet (Regel 2): `ernaehrungsTagAus` rechnet sie einmal je Tag.
import 'package:flutter/cupertino.dart';
import 'package:trainings_core/trainings_core.dart' hide MahlzeitRing;

import '../design/icon_row.dart';
import '../design/inset_card.dart';
import '../design/mahlzeit_ring.dart';
import '../design/palette.dart';
import '../design/platzhalter.dart';
import '../design/section_header.dart';
import '../design/typografie.dart';
import '../design/zahlen.dart';
import 'ernaehrung_abschnitte.dart' show mahlzeitName, mahlzeitSymbol;
import 'ernaehrung_provider.dart';

/// Die Reihenfolge der Liste (Entscheidung 8, V8): **Snacks zuletzt**, wie
/// in der Live-Aktivität und bei YAZIO. Das Enum `Mahlzeit` und
/// `ErnaehrungsTag.mahlzeiten` bleiben, wie sie sind.
const mahlzeitenInListe = [
  Mahlzeit.fruehstueck,
  Mahlzeit.mittag,
  Mahlzeit.abend,
  Mahlzeit.snack,
];

/// Abschnitt „Mahlzeiten": vier Zeilen, immer alle vier, in einer Karte.
///
/// **Eine Form in jedem Zustand.** Mit Ziel, ohne Ziel, ohne Eintrag und
/// beim Laden sind die Zeilen gleich hoch; nur die Füllung wechselt.
///
/// **Unter der Karte steht in jedem Zustand eine Zeile derselben Höhe**
/// (#434), drei Füllungen:
///
/// - **Aufteilung gesichert:** „Aufteilung 25 · 35 · 30 · 10 ›" mit den
///   geltenden Prozenten, Frühstück · Mittag · Abend · Snack, in die
///   Aufteilung. Tims Entscheidung vom 10.11.2026; geprüft von
///   `test/ernaehrung/mahlzeiten_liste_aufteilung_test.dart`. Sie steht,
///   sobald die Aufteilung bekannt ist — auch während die Einträge laden
///   und auch ohne Kalorienziel.
/// - **Fertig gelesen, keine Aufteilung:** „Ziel je Mahlzeit festlegen"
///   (V9), einmal.
/// - **Aufteilung noch unbekannt, es lädt:** die graue Form der
///   Festlegen-Zeile, ohne Text (`01`). Festlegung des Koordinators nach
///   der Hausregel „Eine Anzeige, die es gibt, hat genau eine Form", nicht
///   Tims Entscheidung; geprüft von
///   `test/ernaehrung/mahlzeiten_liste_form_test.dart`.
class MahlzeitenListe extends StatelessWidget {
  const MahlzeitenListe({
    super.key,
    required this.tag,
    required this.onMahlzeit,
    required this.onPlus,
    required this.onAufteilung,
  });

  final ErnaehrungsTag tag;

  /// Die Zeile öffnet die Mahlzeit …
  final void Function(Mahlzeit) onMahlzeit;

  /// … das „+" die Kamera für diese Mahlzeit (V12). Zwei Ziele, zwei
  /// Flächen.
  final void Function(Mahlzeit) onPlus;

  /// „Ziel je Mahlzeit festlegen" und „Aufteilung …" öffnen `aufteilung`.
  final VoidCallback onAufteilung;

  @override
  Widget build(BuildContext context) {
    final line = CupertinoDynamicColor.resolve(Palette.line, context);
    final zeilen = {for (final z in tag.mahlzeiten) z.mahlzeit: z};
    final aufteilung = tag.aufteilung;
    final river = CupertinoDynamicColor.resolve(Palette.river, context);
    // Die Stelle unter der Karte: mit Aufteilung ihre Prozente, ohne die
    // Festlegen-Zeile, beim Laden deren Form. Eine bekannte Aufteilung
    // steht auch, während die Einträge noch laden — sie ist Tims eigene
    // Einstellung und hängt an keinem Lauf.
    final Widget stelle = aufteilung != null
        ? _AufteilungZeile(
            key: const Key('ernaehrung-aufteilung-zeile'),
            aufteilung: aufteilung,
            accent: river,
            onTap: onAufteilung,
          )
        : tag.mahlzeitenLaedt
        ? const _FestlegenPlatzhalter(
            key: Key('ernaehrung-aufteilung-festlegen-laedt'),
          )
        : KeyedSubtree(
            key: const Key('ernaehrung-aufteilung-festlegen'),
            child: IconRow(
              title: _festlegenTitel,
              subtitle: _festlegenUntertitel,
              symbol: 'target',
              accent: river,
              onTap: onAufteilung,
            ),
          );

    // `ernaehrung-mahlzeiten` umfasst Kopf und Karte, **nicht** die Zeile
    // darunter.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Column(
          key: const Key('ernaehrung-mahlzeiten'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SectionHeader('Mahlzeiten'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: InsetCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final m in mahlzeitenInListe) ...[
                      if (m != mahlzeitenInListe.first)
                        Container(height: 0.5, color: line),
                      _MahlzeitZeile(
                        mahlzeit: m,
                        zeile: zeilen[m],
                        laedt: tag.mahlzeitenLaedt,
                        onTap: () => onMahlzeit(m),
                        onPlus: () => onPlus(m),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: InsetCard(child: stelle),
        ),
      ],
    );
  }
}

const _festlegenTitel = 'Ziel je Mahlzeit festlegen';
const _festlegenUntertitel =
    'Wie dein Tagesziel sich auf die Mahlzeiten verteilt';

/// „Aufteilung 25 · 35 · 30 · 10 ›" (Tim, 10.11.2026): die geltenden
/// Prozente in der Reihenfolge der Liste, Snack als Rest.
///
/// **Genauso hoch wie „Ziel je Mahlzeit festlegen"**, obwohl sie keinen
/// Untertitel hat: Die Höhe gibt die unsichtbare Form der Festlegen-Zeile
/// vor ([_FestlegenPlatzhalter], in derselben Breite gemessen), die Zeile
/// liegt darüber. Bricht der Untertitel dort auf einem schmalen Gerät um,
/// wächst diese Zeile mit — der Abschnitt darunter springt in keinem Fall.
class _AufteilungZeile extends StatelessWidget {
  const _AufteilungZeile({
    super.key,
    required this.aufteilung,
    required this.accent,
    required this.onTap,
  });

  final MahlzeitAufteilung aufteilung;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final prozente = [for (final m in mahlzeitenInListe) aufteilung.prozent(m)];
    final vorlesetext = [
      for (final m in mahlzeitenInListe)
        '${mahlzeitName(m)} ${aufteilung.prozent(m)} Prozent',
    ].join(', ');

    return Semantics(
      label: 'Aufteilung: $vorlesetext',
      button: true,
      onTap: onTap,
      excludeSemantics: true,
      child: Stack(
        children: [
          const Visibility(
            visible: false,
            maintainSize: true,
            maintainAnimation: true,
            maintainState: true,
            child: _FestlegenPlatzhalter(),
          ),
          Positioned.fill(
            child: IconRow(
              title: 'Aufteilung',
              value: prozente.join(' · '),
              symbol: 'target',
              accent: accent,
              onTap: onTap,
            ),
          ),
        ],
      ),
    );
  }
}

/// Die Form der Zeile „Ziel je Mahlzeit festlegen" beim Laden: dieselbe
/// Geometrie wie `IconRow` (Polster 14/11, Kachel 30, Abstand 13, Winkel
/// 13), Kachel und beide Texte als graue Form, **kein Text** (`01`).
///
/// Die Texte werden nur gemessen, nie gezeichnet (wie [Platzhalter]) —
/// und zwar in der Breite der Spalte: Bricht der Untertitel auf einem
/// schmalen Gerät um, ist die Form genauso zweizeilig wie die Zeile, die
/// sie ablöst.
class _FestlegenPlatzhalter extends StatelessWidget {
  const _FestlegenPlatzhalter({super.key});

  @override
  Widget build(BuildContext context) {
    final spur = CupertinoDynamicColor.resolve(
      Palette.line,
      context,
    ).withValues(alpha: 0.55);

    return ExcludeSemantics(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 46),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: spur,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Form(
                      beispiel: _festlegenTitel,
                      stil: const TextStyle(fontWeight: FontWeight.w600),
                      farbe: spur,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: _Form(
                        beispiel: _festlegenUntertitel,
                        stil: const TextStyle(fontSize: 12),
                        farbe: spur,
                      ),
                    ),
                  ],
                ),
              ),
              // Platz des Winkels, damit der Untertitel an derselben Stelle
              // umbricht wie in der Zeile.
              const SizedBox(width: 8 + 13),
            ],
          ),
        ),
      ),
    );
  }
}

/// Eine graue Form in der Größe von [beispiel] in [stil], umbrochen auf
/// die verfügbare Breite.
class _Form extends StatelessWidget {
  const _Form({
    required this.beispiel,
    required this.stil,
    required this.farbe,
  });

  final String beispiel;
  final TextStyle stil;
  final Color farbe;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mass = textMass(
          context,
          beispiel,
          stil,
          maxWidth: constraints.maxWidth,
        );
        return SizedBox(
          width: mass.width,
          height: mass.height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: farbe,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      },
    );
  }
}

/// Eine Zeile: Ring, Name mit Winkel, darunter der Stand (V10), rechts „+".
class _MahlzeitZeile extends StatelessWidget {
  const _MahlzeitZeile({
    required this.mahlzeit,
    required this.zeile,
    required this.laedt,
    required this.onTap,
    required this.onPlus,
  });

  final Mahlzeit mahlzeit;

  /// `null` nur, wenn der Tag die Mahlzeit nicht trägt — er trägt immer
  /// alle vier; dann steht die Zeile wie ohne Eintrag.
  final MahlzeitZeile? zeile;
  final bool laedt;
  final VoidCallback onTap;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final stil = Typografie.tabularNumbers(
      Typografie.numeric(
        TypografieGroesse.subheadline,
        gewicht: FontWeight.w400,
      ).copyWith(color: muted),
    );

    final name = mahlzeitName(mahlzeit);
    final eintrag = !(zeile?.leer ?? true);
    final kcal = eintrag ? zeile!.summe.kcal : null;
    final ziel = zeile?.zielKcal;

    return GestureDetector(
      key: Key('ernaehrung-mahlzeit-${mahlzeit.name}'),
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                label: _vorlesetext(name, laedt, eintrag, kcal, ziel),
                button: true,
                onTap: onTap,
                excludeSemantics: true,
                child: Row(
                  children: [
                    MahlzeitRing(
                      key: Key('ernaehrung-mahlzeit-ring-${mahlzeit.name}'),
                      symbol: mahlzeitSymbol(mahlzeit),
                      anteil: zeile?.anteil,
                      eintrag: eintrag,
                      laedt: laedt,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w600,
                                    color: ink,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 3),
                              Icon(
                                CupertinoIcons.chevron_right,
                                size: 13,
                                color: muted,
                              ),
                            ],
                          ),
                          const SizedBox(height: 1),
                          laedt
                              ? Platzhalter(
                                  beispiel: '426 / 450 kcal',
                                  stil: stil,
                                )
                              : Text(
                                  _stand(eintrag, kcal, ziel),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: stil,
                                ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            _Plus(
              key: Key('ernaehrung-mahlzeit-plus-${mahlzeit.name}'),
              vorlesetext: 'Zum $name hinzufügen',
              onTap: onPlus,
            ),
          ],
        ),
      ),
    );
  }
}

/// Ganze kcal (V5: gerechnet wird ungerundet, angezeigt ganz).
String _kcal(double wert) => formatNumber(wert);

/// Der Text unter dem Namen (V10). **Ohne Eintrag „–", nie „0"**
/// (Entscheidung 7); ohne Ziel nur die Summe.
String _stand(bool eintrag, double? kcal, double? ziel) {
  if (ziel != null) {
    final gegessen = !eintrag
        ? '–'
        : kcal == null
        ? ohneWert
        : _kcal(kcal);
    return '$gegessen / ${_kcal(ziel)} kcal';
  }
  if (!eintrag) return 'noch nichts eingetragen';
  return kcal == null ? '$ohneWert kcal' : '${_kcal(kcal)} kcal';
}

/// Der Vorlesetext der Zeile (V11) — er nennt den Zustand, nicht das
/// Zeichen.
String _vorlesetext(
  String name,
  bool laedt,
  bool eintrag,
  double? kcal,
  double? ziel,
) {
  if (laedt) return '$name, wird geladen';
  final zielText = ziel == null ? null : '${_kcal(ziel)} Kilokalorien';
  if (!eintrag) {
    return zielText == null
        ? '$name, nichts eingetragen'
        : '$name, nichts eingetragen, Ziel $zielText';
  }
  if (kcal == null) {
    return zielText == null
        ? '$name, ohne Kalorienangabe'
        : '$name, ohne Kalorienangabe, Ziel $zielText';
  }
  return zielText == null
      ? '$name, ${_kcal(kcal)} Kilokalorien'
      : '$name, ${_kcal(kcal)} von $zielText';
}

/// Das runde „+", 34 pt — groß genug für den Daumen.
class _Plus extends StatelessWidget {
  const _Plus({super.key, required this.vorlesetext, required this.onTap});

  final String vorlesetext;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final surface = CupertinoDynamicColor.resolve(Palette.surface, context);
    final river = CupertinoDynamicColor.resolve(Palette.river, context);
    final line = CupertinoDynamicColor.resolve(Palette.line, context);

    return Semantics(
      label: vorlesetext,
      button: true,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: surface,
            shape: BoxShape.circle,
            border: Border.all(color: line, width: 0.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x24000000),
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Text(
            '+',
            style: TextStyle(
              fontSize: 21,
              height: 1,
              fontWeight: FontWeight.w500,
              color: river,
            ),
          ),
        ),
      ),
    );
  }
}
