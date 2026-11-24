// Die Abschnitte des Körper-Schirms (#82) — Gewichts-Kopfkarte, „Auf einen
// Blick" und „Bereiche". Der Schirm selbst steht in `koerper_view.dart`,
// die Bausteine, die sich drei Schirme teilen, in `mess_abschnitte.dart`
// (Vorbild für den Schnitt: `erholung_abschnitte.dart`).
//
// Aufbau und Beschriftung nach `docs/screens/screens/koerper.js` und
// `docs/superpowers/specs/2026-11-02-koerper-und-messungen-design.md`,
// Teil D.
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../data/cache_repository.dart';
import '../design/formatierung.dart';
import '../design/icon_row.dart';
import '../design/inset_card.dart';
import '../design/kacheln.dart';
import '../design/palette.dart';
import '../design/platzhalter.dart';
import '../design/section_header.dart';
import '../design/typografie.dart';
import '../design/zahlen.dart';
import '../koerper/schritte_view.dart';
import '../koerper/umfaenge_provider.dart';
import '../koerper/umfaenge_view.dart';
import 'koerper_zustand.dart';
import 'mess_abschnitte.dart';
import 'messung_detail_view.dart';
import 'messungen_view.dart';
import 'router.dart';
import 'ziele.dart';

// ─────────────────────────────────────────────────────────────────────────
// Die Gewichts-Kopfkarte
// ─────────────────────────────────────────────────────────────────────────

/// `scorecard` aus dem Entwurf: Wert, Trendsatz, Verlauf — und **eine
/// Tür** auf den Verlauf des Gewichts.
///
/// Sie bleibt eine Tür, auch wenn der Wert fehlt: Eine fehlende Tür sieht
/// aus wie eine Funktion, die es nicht gibt, und der Detailschirm hat seine
/// eigene Leeransicht.
class KoerperKopfkarte extends StatelessWidget {
  const KoerperKopfkarte({
    super.key,
    required this.lage,
    required this.werte,
    required this.onTap,
  });

  final MessLage lage;
  final KoerperWerte? werte;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final stand = werte?.gewicht;
    final wert = stand?.wert;
    final reihe = [
      for (final punkt in stand?.reihe ?? const <MeasurementPoint>[])
        punkt.value,
    ];
    final hinweisStil = TextStyle(fontSize: 12.5, color: muted);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: GestureDetector(
        key: const Key('koerper-kopfkarte'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Semantics(
          label: wert == null
              ? 'Gewicht, ${lage == MessLage.laedt ? 'wird geladen' : 'keine Werte'}'
              : 'Gewicht, ${messWert(MessArt.gewicht, wert)}',
          button: true,
          excludeSemantics: true,
          // Dieselbe Fläche wie die Kacheln darunter, aus derselben Quelle
          // (#239): kein Rand, Radius aus `kachelFlaeche`. Vorher eine
          // `InsetCard` (damals Radius 10, 1 pt Rand) — sie stand damit
          // sichtbar anders da als „Körperfett" und „Muskelmasse", obwohl sie
          // dasselbe tut.
          child: Container(
            decoration: kachelFlaeche(context),
            child: Padding(
              padding: const EdgeInsets.all(13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // **Kein Winkel** (#239). Der Winkel folgt der Tür bei
                  // *Zeilen* (`IconRow`), nicht bei Flächen: Die Kacheln
                  // „Körperfett" und „Muskelmasse" darunter sind ebenfalls
                  // Türen und tragen keinen. Ohne ihn braucht es auch die
                  // Row samt `Expanded` nicht mehr.
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'GEWICHT',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                          color: muted,
                        ),
                      ),
                      Padding(
                        key: const Key('koerper-kopfkarte-wert'),
                        padding: const EdgeInsets.only(top: 2),
                        child: _GrosserWert(lage: lage, wert: wert),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: FesteZeilen(
                          zeilen: 1,
                          stil: hinweisStil,
                          child: Text(
                            _trendsatz(lage, werte),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: hinweisStil,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 9),
                    child: SizedBox(
                      height: 28,
                      child: reihe.length < 2
                          ? DecoratedBox(
                              decoration: BoxDecoration(
                                color: ink.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            )
                          : Verlaufslinie(
                              werte: reihe,
                              farbe: CupertinoDynamicColor.resolve(
                                Palette.bib,
                                context,
                              ),
                            ),
                    ),
                  ),
                  // An der Stelle, an der der Entwurf Balken und
                  // Zielabstand zeigt. **Ohne Zahl:** Ein Zielgewicht im
                  // Quelltext wäre ein hartcodiertes Ereignis, auch als
                  // Vorbelegung (#41 bringt die Ziele).
                  Padding(
                    key: const Key('koerper-kein-ziel'),
                    padding: const EdgeInsets.only(top: 9),
                    child: Text(
                      'Kein Körperziel festgelegt',
                      style: hinweisStil,
                    ),
                  ),
                  // Der Grund steht **einmal** hier unter der Kopfkarte,
                  // nicht je Kachel: Ein Hinweis in einer schmalen Spalte
                  // läuft über mehrere Zeilen und macht die Karte höher,
                  // sobald Werte fehlen.
                  if (wert == null &&
                      (lage == MessLage.werte || lage == MessLage.leer))
                    Padding(
                      key: const Key('koerper-grund'),
                      padding: const EdgeInsets.only(top: 9),
                      child: Text(
                        'Ohne Gewicht fehlen auch Körperfett-Trend und '
                        'Eiweißziel. Prüf, ob die Waage mit Apple Health '
                        'verbunden ist und die App lesen darf.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: muted,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Die große Zahl samt Einheit — im Ladezustand die graue Fläche, ohne Wert
/// [ohneWert], **nie `0`**.
class _GrosserWert extends StatelessWidget {
  const _GrosserWert({required this.lage, required this.wert});

  final MessLage lage;
  final double? wert;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final stil = Typografie.tabularNumbers(
      Typografie.numeric(
        TypografieGroesse.largeTitle,
        gewicht: FontWeight.w700,
      ).copyWith(color: ink),
    );
    final zahl = wert;

    if (zahl == null && lage == MessLage.laedt) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Platzhalter(beispiel: '00,0', stil: stil),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          zahl == null ? ohneWert : messZahl(MessArt.gewicht, zahl),
          style: stil,
        ),
        const SizedBox(width: 4),
        Text('kg', style: TextStyle(fontSize: 15, color: muted)),
      ],
    );
  }
}

/// Der Satz unter der großen Zahl — die Steigung pro Woche samt Urteil,
/// wörtlich nach `BodyOverviewView.swift:75–87`.
String _trendsatz(MessLage lage, KoerperWerte? werte) {
  if (lage == MessLage.laedt || lage == MessLage.fehler) return '';
  if (werte?.gewicht.wert == null) return keineWaagenwerte;

  final proWoche = werte!.gewichtsTrendProWoche;
  final einordnung = werte.trendEinordnung;
  if (proWoche == null || einordnung == null) {
    return 'Für einen Trend fehlen Messungen';
  }
  final urteil = switch (einordnung) {
    TrendRating.losing => 'es geht abwärts',
    TrendRating.slow => 'langsamer als das Ziel',
    TrendRating.good => 'im Zielbereich',
    TrendRating.fast => 'schneller als nötig',
  };
  return '${gewichtsTrendText(proWoche)} · $urteil';
}

// ─────────────────────────────────────────────────────────────────────────
// „Auf einen Blick" — vier Kacheln
// ─────────────────────────────────────────────────────────────────────────

/// Vier Kacheln in zwei Reihen (`tileGrid`, zwei Spalten).
///
/// **Keine verschwindet, weil ihr Wert fehlt:** `Kacheln` legt seine Kinder
/// als gleich breite `Expanded` ab — fiele eine weg, teilten sich die
/// übrigen ihren Platz, und dann spränge sogar die Breite.
///
/// Zwei von ihnen sind Türen auf `messung-detail`, eine auf die
/// Umfänge-Übersicht (#477), und „Schritte" führt seit #84 auf den
/// Schritte-Schirm. Der Schlüssel sitzt
/// deshalb auf der ganzen Kachelfläche ([KachelWert.schluessel]) — eine
/// Tür, die nur in der Mitte aufgeht, ist keine.
class KoerperKacheln extends ConsumerWidget {
  const KoerperKacheln({
    super.key,
    required this.lage,
    required this.werte,
    required this.router,
  });

  final MessLage lage;
  final KoerperWerte? werte;
  final AppRouter router;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Die Umfänge-Kachel zeigt das Datum der jüngsten Messung. Sie besorgt
    // es sich selbst (#477) — die übrigen drei Zahlen kommen aus Apple
    // Health, diese eine aus Tims eigener Tabelle.
    final letzterMesstag = ref.watch(umfaengeLetzterMesstagProvider);
    final kacheln = _werte(context, letzterMesstag);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Auf einen Blick'),
        // 15 statt 20: Die Kacheln tragen selbst 5 Punkt Rand, damit
        // stehen ihre Außenkanten bündig unter der Kopfkarte.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: Kacheln(kacheln.sublist(0, 2)),
        ),
        const SizedBox(height: 9),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: Kacheln(kacheln.sublist(2)),
        ),
      ],
    );
  }

  List<KachelWert> _werte(
    BuildContext context,
    AsyncValue<String?> letzterMesstag,
  ) {
    final laedt = lage == MessLage.laedt;
    final schnitt = werte?.schritteSchnitt7;

    return [
      _messKachel(
        context,
        art: MessArt.koerperfett,
        label: 'Körperfett',
        farbe: Palette.river,
        schluessel: const Key('koerper-kachel-koerperfett'),
      ),
      _messKachel(
        context,
        art: MessArt.fettfreieMasse,
        label: 'Muskelmasse',
        farbe: Palette.iron,
        schluessel: const Key('koerper-kachel-muskelmasse'),
      ),
      KachelWert(
        label: 'Schritte Ø 7 Tage',
        wert: schnitt == null ? null : formatNumber(schnitt.toDouble()),
        zusatz: schnitt == null
            ? ohneWertZusatz(lage, grund: 'Keine Schritte in Apple Health')
            : 'Mittel der sieben Tage vor heute',
        farbe: CupertinoDynamicColor.resolve(Palette.ok, context),
        platzhalter: laedt ? '00.000' : null,
        schluessel: const Key('koerper-kachel-schritte'),
        // Seit #84 die Tür auf den echten Schirm, nicht mehr auf den
        // Platzhalter.
        onTap: () => oeffneSchritte(router),
      ),
      // **Das Datum der jüngsten Messung, kein Zählerstand** (#477): „15
      // Maße" wäre eine Zahl über den Katalog und nicht über Tims Daten.
      // Liegt keine Messung vor, bleibt die Kachel ungefüllt und sagt das;
      // sie verschwindet nicht.
      _umfaengeKachel(context, letzterMesstag),
    ];
  }

  /// Eine Kachel über einen Messwert aus Apple Health — mit Kurve, mit Tür
  /// auf den Verlauf dieses Werts.
  KachelWert _messKachel(
    BuildContext context, {
    required MessArt art,
    required String label,
    required CupertinoDynamicColor farbe,
    required Key schluessel,
  }) {
    final stand = werte?.stand(art);
    final wert = stand?.wert;
    final verlauf = [
      for (final punkt in stand?.reihe ?? const <MeasurementPoint>[])
        punkt.value,
    ];

    return KachelWert(
      label: label,
      wert: wert == null ? null : messZahl(art, wert),
      einheit: wert == null ? null : messEinheit(art),
      zusatz: wert == null
          ? ohneWertZusatz(lage, grund: keineWaagenwerte)
          : _gemessenAm(stand!.tag, stand.veraenderung6Wochen, art),
      farbe: CupertinoDynamicColor.resolve(farbe, context),
      verlauf: verlauf,
      platzhalter: lage == MessLage.laedt ? messBeispiel(art) : null,
      schluessel: schluessel,
      onTap: () => oeffneMessungDetail(router, art),
    );
  }

  /// Die Umfänge-Kachel. Der Tag der jüngsten Messung über den
  /// gemeinsamen Formatierer — `DateTime.formatted` nähme die Sprache des
  /// Geräts (`CLAUDE.md`).
  ///
  /// Solange gelesen wird, steht dort die graue Form und **kein** Grund:
  /// Der Ladezustand ist kein Leerstand (`01`).
  KachelWert _umfaengeKachel(
    BuildContext context,
    AsyncValue<String?> letzterMesstag,
  ) {
    final laedt = letzterMesstag.isLoading;
    final tag = letzterMesstag.hasValue ? letzterMesstag.value : null;

    return KachelWert(
      label: 'Umfänge',
      wert: tag == null ? null : Format.tagMonat(datumZumAnzeigen(tag)),
      zusatz: tag == null
          ? (laedt ? '' : 'noch keine Messung eingetragen')
          : 'zuletzt mit dem Maßband gemessen',
      farbe: CupertinoDynamicColor.resolve(Palette.deep, context),
      platzhalter: laedt ? '00.00.' : null,
      schluessel: const Key('koerper-kachel-umfaenge'),
      onTap: () => oeffneUmfaenge(router),
    );
  }

  /// „Waage · zuletzt 11.10." bzw. „+0,7 kg in 6 Wochen" — der Entwurf
  /// zeigt bei Körperfett die Herkunft, bei der Muskelmasse die
  /// Veränderung. Steht keine Veränderung zur Verfügung, bleibt das Datum.
  String _gemessenAm(String? tag, double? veraenderung, MessArt art) {
    if (veraenderung != null) return veraenderungText(art, veraenderung);
    if (tag == null) return 'Waage';
    return 'Waage · zuletzt ${Format.tagMonat(datumZumAnzeigen(tag))}';
  }

}

// ─────────────────────────────────────────────────────────────────────────
// „Bereiche" — vier Zeilen
// ─────────────────────────────────────────────────────────────────────────

/// Die vier Zeilen aus dem Entwurf. **Keine bleibt stumm:** „Umfänge"
/// führt seit #477 auf die Übersicht, „Schritte" seit #84 auf den
/// Schritte-Schirm; nur die Muskelkarte führt noch auf einen Platzhalter,
/// bis ihr Ticket dran ist (#96) — eine Zeile, die aussieht wie ein Knopf
/// und beim Tippen schweigt, ist genau der Fehler, den
/// `docs/screens/pruefen.mjs` für die Web-Entwürfe eigens sucht.
class KoerperBereiche extends StatelessWidget {
  const KoerperBereiche({super.key, required this.router, required this.werte});

  final AppRouter router;
  final KoerperWerte? werte;

  @override
  Widget build(BuildContext context) {
    final line = CupertinoDynamicColor.resolve(Palette.line, context);
    final schnitt = werte?.schritteSchnitt7;
    final gewogen = werte?.gewicht.tag;

    final zeilen = <Widget>[
      IconRow(
        key: const Key('koerper-bereich-muskelkarte'),
        title: 'Muskelkarte',
        subtitle: 'Harte Sätze pro Woche, Figur vorne und hinten',
        symbol: 'figure.arms.open',
        accent: CupertinoDynamicColor.resolve(Palette.iron, context),
        onTap: () => _platzhalter(
          'Muskelkarte',
          'Die Muskelkarte mit harten Sätzen pro Woche ist noch nicht '
              'gebaut.',
        ),
      ),
      IconRow(
        key: const Key('koerper-bereich-schritte'),
        title: 'Schritte',
        subtitle: 'Woche bis Jahr, Ziel und Durchschnitt',
        symbol: 'figure.run',
        accent: CupertinoDynamicColor.resolve(Palette.ok, context),
        value: schnitt == null ? ohneWert : formatNumber(schnitt.toDouble()),
        // Seit #84 die Tür auf den echten Schirm, nicht mehr auf den
        // Platzhalter.
        onTap: () => oeffneSchritte(router),
      ),
      IconRow(
        key: const Key('koerper-bereich-messungen'),
        title: 'Messungen',
        subtitle: 'Gewicht, Körperfett, Muskelmasse, Ruhepuls',
        symbol: 'scale',
        accent: CupertinoDynamicColor.resolve(Palette.river, context),
        value: gewogen == null
            ? ohneWert
            : Format.tagMonat(datumZumAnzeigen(gewogen)),
        onTap: () => oeffneMessungen(router),
      ),
      // Führt auf die **Übersicht**, nicht aufs Formular (#477, Plan Task
      // 2.4): Wer auf Körper nachsieht, will wissen, wie es steht.
      IconRow(
        key: const Key('koerper-bereich-umfaenge'),
        title: 'Umfänge',
        subtitle: 'Maße mit dem Maßband, Körperfett nach Navy, Verlauf',
        symbol: 'ruler',
        accent: CupertinoDynamicColor.resolve(Palette.deep, context),
        onTap: () => oeffneUmfaenge(router),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: InsetCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < zeilen.length; i++) ...[
              if (i > 0)
                Padding(
                  padding: const EdgeInsets.only(left: 56),
                  child: Container(height: 1, color: line),
                ),
              zeilen[i],
            ],
          ],
        ),
      ),
    );
  }

  void _platzhalter(String titel, String text) {
    router.open(
      AppTarget.aktuell(
        (context) => _BereichPlatzhalter(titel: titel, text: text),
      ),
    );
  }
}

/// Ein ehrlicher Hinweis statt eines leeren Schirms — parallel zu
/// `_PlanPlatzhalter` in `mehr_view.dart`. Eigenes
/// `CupertinoPageScaffold`, aber **kein** eigener `Navigator`.
class _BereichPlatzhalter extends StatelessWidget {
  const _BereichPlatzhalter({required this.titel, required this.text});

  final String titel;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);

    return CupertinoPageScaffold(
      backgroundColor: CupertinoDynamicColor.resolve(Palette.bg, context),
      navigationBar: CupertinoNavigationBar(middle: Text(titel)),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                titel,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: ink,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, height: 1.35, color: muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
