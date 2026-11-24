// Der Kopf des Mahlzeit-Detail (#442, Schnitt 3 von #385): das 2×2-Raster,
// der Balken gegen das Ziel dieser Mahlzeit mit dem Satz darunter und
// „Alle Nährwerte". Eigene Datei, weil `mahlzeit_view.dart` schon über
// 1.000 Zeilen hatte.
//
// Aufbau, Beschriftung und Reihenfolge nach `docs/screens/screens/mahlzeit.js`
// (`MAHLZEITZIEL`, `makroRaster`, `WEITERE`; Zustände `vorschlag-raster`,
// `vorschlag-raster-leer`, `vorschlag-raster-ohne-ziel`). Spec
// `docs/superpowers/specs/2026-11-10-mahlzeiten-aufteilung-design.md`,
// „Mahlzeit-Detail (Schnitt 3)", V4 und V17–V19.
//
// Verbindlich vorgegeben durch `app/test/mahlzeit/mahlzeit_raster_test.dart`
// und `app/test/mahlzeit/mahlzeit_view_test.dart` (siehe deren Dateiköpfe) —
// diese Datei darf die Tests ausführen, aber nicht verändern.
//
// **Eine Anzeige, die es gibt, hat genau eine Form** (`CLAUDE.md`): Raster,
// Balken und Satz stehen in Werte, leer, ohne Ziel und Laden in derselben
// Größe. Jede Zahl und jeder Satz ist einzeilig; der Platzhalter misst sich
// am Beispieltext in derselben Schrift.
//
// **Keine Makro-Ziele je Mahlzeit** (Entscheidung 11): Die Makros stehen als
// Zahlen im Raster. Ein Balken gibt es nur für die Kalorien, gegen den
// eingestellten Anteil am Tagesziel — ein Eiweißziel fürs Frühstück hat
// niemand eingestellt, und die App erfindet keins.
import 'package:flutter/cupertino.dart';
import 'package:trainings_core/trainings_core.dart';

import '../design/inset_card.dart';
import '../design/makro_balken.dart';
import '../design/palette.dart';
import '../design/platzhalter.dart';
import '../design/typografie.dart';
import '../design/zahlen.dart';
import 'mahlzeit_provider.dart';

/// Raster, Balken und „Alle Nährwerte" — alles zwischen der Überschrift
/// und „Eingetragen".
///
/// Ohne eigenen Zustand: Ob „Alle Nährwerte" offen ist, hält der Schirm,
/// damit es jedes Neurechnen des Providers überlebt (Fehler `32`).
class MahlzeitKopf extends StatelessWidget {
  const MahlzeitKopf({
    super.key,
    required this.inhalt,
    required this.offen,
    required this.onKlappen,
    required this.onAufteilung,
  });

  final MahlzeitInhalt inhalt;

  /// „Alle Nährwerte" ist aufgeklappt.
  final bool offen;
  final VoidCallback onKlappen;

  /// Der Weg „Aufteilung des Tagesziels festlegen ›" (V19).
  final VoidCallback onAufteilung;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _Raster(summe: inhalt.summe, laedt: inhalt.laedt),
        const SizedBox(height: 10),
        _Ziel(inhalt: inhalt, onAufteilung: onAufteilung),
        _AlleNaehrwerte(
          summe: inhalt.summe,
          laedt: inhalt.laedt,
          offen: offen,
          onKlappen: onKlappen,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Das Raster
// ─────────────────────────────────────────────────────────────────────────

/// `makroRaster` aus `docs/screens/components.js`: kcal, Kohlenhydrate,
/// Eiweiß, Fett — je große Zahl mit Beschriftung darunter.
///
/// **Fehlt ein Wert, steht `–/–`, nie `0`** (#232, Entscheidung 7): Was
/// niemand deklariert hat, hat keine 0 g. Beim Laden graue Formen in
/// derselben Größe.
class _Raster extends StatelessWidget {
  const _Raster({required this.summe, required this.laedt});

  final Naehrwerte? summe;
  final bool laedt;

  @override
  Widget build(BuildContext context) {
    final werte = summe;
    Widget feld(
      String schluessel,
      String name,
      String vorlesename,
      double? wert, {
      required bool gramm,
    }) => Expanded(
      child: _Feld(
        schluessel: Key('mahlzeit-raster-$schluessel'),
        name: name,
        vorlesename: vorlesename,
        wert: wert,
        gramm: gramm,
        laedt: laedt,
      ),
    );

    return Padding(
      key: const Key('mahlzeit-raster'),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              feld('kcal', 'kcal', 'Kalorien', werte?.kcal, gramm: false),
              const SizedBox(width: 8),
              feld(
                'kohlenhydrate',
                'Kohlenhydrate',
                'Kohlenhydrate',
                werte?.kohlenhydrateG,
                gramm: true,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              feld('eiweiss', 'Eiweiß', 'Eiweiß', werte?.eiweissG, gramm: true),
              const SizedBox(width: 8),
              feld('fett', 'Fett', 'Fett', werte?.fettG, gramm: true),
            ],
          ),
        ],
      ),
    );
  }
}

/// Ein Feld des Rasters.
///
/// **Der Vorlesetext nennt den Zustand, nicht das Zeichen**: VoiceOver läse
/// `–/–` als „Strich Schrägstrich Strich" vor. Das Label steht deshalb am
/// `Semantics`, und die Texte darunter sind stumm.
class _Feld extends StatelessWidget {
  const _Feld({
    required this.schluessel,
    required this.name,
    required this.vorlesename,
    required this.wert,
    required this.gramm,
    required this.laedt,
  });

  final Key schluessel;
  final String name;
  final String vorlesename;
  final double? wert;

  /// Gramm mit einer Nachkommastelle und Einheit („69,4 g"), sonst kcal
  /// ganz („426") — wie die Nährwertzeilen und der Entwurf.
  final bool gramm;
  final bool laedt;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final surface = CupertinoDynamicColor.resolve(Palette.surface, context);
    final dunkel = CupertinoTheme.maybeBrightnessOf(context) == Brightness.dark;

    // `.raster b`: 700 1.55rem/1.1 Barlow Condensed, tabellarisch.
    final zahlStil = Typografie.tabularNumbers(
      Typografie.numeric(
        TypografieGroesse.title2,
        gewicht: FontWeight.w700,
      ).copyWith(fontSize: 25, height: 1.1),
    );

    return Semantics(
      container: true,
      label: _vorlesetext(),
      excludeSemantics: true,
      child: Container(
        key: schluessel,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        // `.raster > div`: surface, `--r-card` (18), `--shadow-card`.
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: dunkel ? const Color(0x99000000) : const Color(0x0F15242A),
              offset: const Offset(0, 2),
              blurRadius: 8,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (laedt)
              Platzhalter(beispiel: gramm ? '69,4 g' : '426', stil: zahlStil)
            else
              Text(
                _text(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: zahlStil.copyWith(color: ink),
              ),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: muted),
            ),
          ],
        ),
      ),
    );
  }

  String _text() {
    final wert = this.wert;
    if (wert == null) return ohneWert;
    return gramm
        ? '${formatNumber(wert, nachkommastellen: 1)} g'
        : formatNumber(wert);
  }

  String _vorlesetext() {
    final wert = this.wert;
    if (laedt) return '$vorlesename, wird geladen';
    if (wert == null) return '$vorlesename, keine Werte';
    return gramm
        ? '$vorlesename, ${formatNumber(wert, nachkommastellen: 1)} Gramm'
        : '$vorlesename, ${formatNumber(wert)} Kilokalorien';
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Der Balken gegen das Ziel dieser Mahlzeit
// ─────────────────────────────────────────────────────────────────────────

/// `MAHLZEITZIEL` aus `mahlzeit.js`: **ein** Balken, kcal gegen den
/// eingestellten Anteil am Tagesziel, darunter einmal, woher das Ziel kommt.
///
/// - Werte da: „426 / 450 kcal". Über dem Ziel voll und **nicht rot**
///   (V18) — über dem eigenen Anteil zu liegen ist bei einer Mahlzeit kein
///   Fehler.
/// - Kein Eintrag: „– / 180 kcal", der Balken leer (Entscheidung 7).
/// - Kein Ziel (ohne Aufteilung, ohne Tagesziel, bei 0 %): leer, `–/–`.
/// - Laden ([MahlzeitInhalt.zielLaedt]): graue Formen — weder `–/–` noch
///   „festlegen" (Fehler `01`).
class _Ziel extends StatelessWidget {
  const _Ziel({required this.inhalt, required this.onAufteilung});

  final MahlzeitInhalt inhalt;
  final VoidCallback onAufteilung;

  static const _label = 'Ziel dieser Mahlzeit';

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const Key('mahlzeit-ziel'),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: InsetCard(
        child: Padding(
          // `.card.soft`: 15px oben und unten, `--pad-card` seitlich. Der
          // Balken bringt selbst 9 pt oben und unten mit (`.macro`).
          padding: const EdgeInsets.fromLTRB(17, 6, 17, 15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _balken(),
              _Satz(inhalt: inhalt, onAufteilung: onAufteilung),
            ],
          ),
        ),
      ),
    );
  }

  MakroBalken _balken() {
    if (inhalt.zielLaedt) {
      return const MakroBalken.laedt(
        label: _label,
        einheit: 'kcal',
        farbe: Palette.river,
        platzhalter: '426 / 450 kcal',
      );
    }
    final ziel = inhalt.zielKcal;
    if (ziel == null) {
      return const MakroBalken.ohneWert(
        label: _label,
        einheit: 'kcal',
        farbe: Palette.river,
      );
    }
    final kcal = inhalt.summe?.kcal;
    if (kcal == null) {
      return MakroBalken.nurZiel(
        label: _label,
        ziel: ziel.round(),
        einheit: 'kcal',
        farbe: Palette.river,
      );
    }
    return MakroBalken(
      label: _label,
      wert: kcal.round(),
      ziel: ziel.round(),
      einheit: 'kcal',
      farbe: Palette.river,
      ueberZielUmfaerben: false,
    );
  }
}

/// Der Satz unter dem Balken (V19, V4) — **immer genau eine Zeile**, auch
/// beim Laden (dann eine graue Form in derselben Höhe).
///
/// - „25 % deines Tagesziels von 1.800 kcal — so eingestellt"
/// - ohne Tagesziel „25 % deines Tagesziels — es gibt noch kein
///   Kalorienziel"
/// - bei 0 % „0 % deines Tagesziels — so eingestellt" (V4)
/// - ohne Aufteilung der Weg „Aufteilung des Tagesziels festlegen ›"
class _Satz extends StatelessWidget {
  const _Satz({required this.inhalt, required this.onAufteilung});

  final MahlzeitInhalt inhalt;
  final VoidCallback onAufteilung;

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final river = CupertinoDynamicColor.resolve(Palette.river, context);
    const stil = TextStyle(fontSize: 13);
    const schluessel = Key('mahlzeit-ziel-satz');

    if (inhalt.zielLaedt) {
      return const Align(
        key: schluessel,
        alignment: Alignment.centerLeft,
        child: Platzhalter(
          beispiel: '25 % deines Tagesziels von 1.800 kcal',
          stil: stil,
        ),
      );
    }

    final prozent = inhalt.prozent;
    if (!inhalt.aufteilungGesichert || prozent == null) {
      return Semantics(
        button: true,
        label: 'Aufteilung des Tagesziels festlegen',
        excludeSemantics: true,
        child: GestureDetector(
          key: schluessel,
          behavior: HitTestBehavior.opaque,
          onTap: onAufteilung,
          child: Text(
            'Aufteilung des Tagesziels festlegen ›',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: stil.copyWith(color: river),
          ),
        ),
      );
    }

    // Der Schlüssel sitzt eine Ebene über dem Text, nicht an ihm: So
    // findet man den Satz unter `mahlzeit-ziel-satz` wie in den beiden
    // anderen Fassungen.
    return SizedBox(
      key: schluessel,
      child: Text(
        _satz(prozent, inhalt.tageszielKcal),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: stil.copyWith(color: muted),
      ),
    );
  }

  static String _satz(int prozent, double? tagesziel) {
    if (tagesziel == null) {
      return '$prozent % deines Tagesziels — es gibt noch kein Kalorienziel';
    }
    // V4: Bei 0 % gibt es kein Ziel, also auch keine Zahl, aus der es käme.
    if (prozent == 0) return '0 % deines Tagesziels — so eingestellt';
    return '$prozent % deines Tagesziels von ${formatNumber(tagesziel)} kcal '
        '— so eingestellt';
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Alle Nährwerte
// ─────────────────────────────────────────────────────────────────────────

/// `sectionCard({ title: 'Alle Nährwerte', hint: 'sechs Werte' })`:
/// zugeklappt, aufgeklappt die bisherigen sechs Zeilen samt Schlüsseln
/// (V17). Die bisherige Kalorienzeile entfällt — die kcal stehen im
/// Raster; zwei Stellen für dieselbe Summe liefen irgendwann auseinander.
class _AlleNaehrwerte extends StatelessWidget {
  const _AlleNaehrwerte({
    required this.summe,
    required this.laedt,
    required this.offen,
    required this.onKlappen,
  });

  final Naehrwerte? summe;
  final bool laedt;
  final bool offen;
  final VoidCallback onKlappen;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final line = CupertinoDynamicColor.resolve(Palette.line, context);

    return Padding(
      key: const Key('mahlzeit-werte'),
      padding: const EdgeInsets.fromLTRB(16, 9, 16, 0),
      child: InsetCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              button: true,
              label: offen
                  ? 'Alle Nährwerte, aufgeklappt'
                  : 'Alle Nährwerte, sechs Werte, zugeklappt',
              onTap: onKlappen,
              excludeSemantics: true,
              child: GestureDetector(
                key: const Key('mahlzeit-werte-kopf'),
                behavior: HitTestBehavior.opaque,
                onTap: onKlappen,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 11,
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Alle Nährwerte',
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: ink,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'sechs Werte',
                          maxLines: 1,
                          textAlign: TextAlign.right,
                          overflow: TextOverflow.ellipsis,
                          style: Typografie.tabularNumbers(
                            TextStyle(fontSize: 13, color: muted),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(
                        offen
                            ? CupertinoIcons.chevron_down
                            : CupertinoIcons.chevron_right,
                        size: 13,
                        color: muted.withValues(alpha: 0.7),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (offen) ...[
              Container(height: 1, color: line),
              Padding(
                key: const Key('mahlzeit-werte-tabelle'),
                padding: const EdgeInsets.fromLTRB(13, 8, 13, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final zeile in _naehrwertZeilen(summe))
                      _Naehrwertzeile(
                        schluessel: zeile.schluessel,
                        name: zeile.name,
                        wert: zeile.wert,
                        laedt: laedt,
                        eingerueckt: zeile.eingerueckt,
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Die sechs Zeilen in der Reihenfolge des Entwurfs (`mahlzeit.js`,
/// `ZEILEN`). Die Reihenfolge ist keine Beschriftung, sondern die
/// Zuordnung Zeile → Nährwert.
List<({Key schluessel, String name, double? wert, bool eingerueckt})>
_naehrwertZeilen(Naehrwerte? werte) => [
  (
    schluessel: const Key('mahlzeit-wert-eiweiss'),
    name: 'Eiweiß',
    wert: werte?.eiweissG,
    eingerueckt: false,
  ),
  (
    schluessel: const Key('mahlzeit-wert-kohlenhydrate'),
    name: 'Kohlenhydrate',
    wert: werte?.kohlenhydrateG,
    eingerueckt: false,
  ),
  (
    schluessel: const Key('mahlzeit-wert-zucker'),
    name: 'davon Zucker',
    wert: werte?.zuckerG,
    eingerueckt: true,
  ),
  (
    schluessel: const Key('mahlzeit-wert-fett'),
    name: 'Fett',
    wert: werte?.fettG,
    eingerueckt: false,
  ),
  (
    schluessel: const Key('mahlzeit-wert-gesaettigt'),
    name: 'davon gesättigt',
    wert: werte?.gesaettigtG,
    eingerueckt: true,
  ),
  (
    schluessel: const Key('mahlzeit-wert-ballaststoffe'),
    name: 'Ballaststoffe',
    wert: werte?.ballaststoffeG,
    eingerueckt: false,
  ),
];

/// Eine der sechs Nährwertzeilen — Name links, Wert rechts.
///
/// **Was niemand deklariert hat, ist kein `0`** (#232): Zwei Lebensmittel
/// ohne Ballaststoffangabe haben keine 0 g, sie haben keine Angabe. Darum
/// `–/–`.
class _Naehrwertzeile extends StatelessWidget {
  const _Naehrwertzeile({
    required this.schluessel,
    required this.name,
    required this.wert,
    required this.laedt,
    required this.eingerueckt,
  });

  final Key schluessel;
  final String name;
  final double? wert;
  final bool laedt;
  final bool eingerueckt;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);

    final wertStil = Typografie.tabularNumbers(
      TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ink),
    );

    return Semantics(
      label: _vorlesetext(),
      excludeSemantics: true,
      child: Padding(
        key: schluessel,
        padding: EdgeInsets.only(left: eingerueckt ? 12 : 0, top: 3, bottom: 3),
        child: Row(
          children: [
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: eingerueckt ? muted : ink,
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (laedt)
              Platzhalter(beispiel: '34,2 g', stil: wertStil)
            else
              Text(
                wert == null
                    ? ohneWert
                    : '${formatNumber(wert!, nachkommastellen: 1)} g',
                maxLines: 1,
                style: wertStil,
              ),
          ],
        ),
      ),
    );
  }

  String _vorlesetext() {
    if (laedt) return '$name, wird geladen';
    if (wert == null) return '$name, keine Werte';
    return '$name, ${formatNumber(wert!, nachkommastellen: 1)} Gramm';
  }
}
