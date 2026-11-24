// Die Abschnitte des Schirms `erholung-werte` (#117) als eigene, kleine
// Bausteine — `erholung_werte_view.dart` setzt sie zusammen. Getrennt aus
// demselben Grund wie `erholung_abschnitte.dart`: Ein Schirm mit Statuskarte,
// Signalband und Schwellenliste in einer Datei wächst über ein paar hundert
// Zeilen und macht dann zu viel (`CLAUDE.md`, „Views bleiben klein").
//
// In Swift liegen Wording, Balken und Karte zusammen in
// `RecoveryStatusCard.swift` (362 Zeilen). Hier ist das getrennt: die
// Entscheidungen in `erholung_werte_zustand.dart`, das Zeichnen hier.
//
// Die Schlüssel (`erholung-werte-karte`, `-zeile-<metrik>`,
// `-balken-<metrik>`, `-band`, `-band-tag-<i>`, `-schwellen`) sind durch
// `app/test/shell/erholung_werte_view_test.dart` verbindlich vorgegeben.
import 'package:flutter/cupertino.dart';
import 'package:trainings_core/trainings_core.dart';

import '../design/inset_card.dart';
import '../design/palette.dart';
import '../design/typografie.dart';
import 'erholung_werte_zustand.dart';

// ─────────────────────────────────────────────────────────────────────────
// Die Statuskarte
// ─────────────────────────────────────────────────────────────────────────

/// Die Karte, die in keinem Zustand verschwindet. Platz, Form und Position
/// bleiben, nur Inhalt und Kantenfarbe wechseln.
///
/// **Erst die farbige Kante, dann der Schnitt auf der ganzen Karte**
/// (`CLAUDE.md`): [InsetCard] legt außen ein `ClipRRect`, der 4 Punkt breite
/// Balken läuft deshalb nicht über die Ecke hinaus.
class WerteStatusKarte extends StatelessWidget {
  const WerteStatusKarte({
    super.key,
    required this.status,
    required this.onHealthEinstellungen,
  });

  final WerteStatus status;
  final VoidCallback onHealthEinstellungen;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final line = CupertinoDynamicColor.resolve(Palette.line, context);
    final kante = CupertinoDynamicColor.resolve(status.kante, context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: InsetCard(
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: kante, width: 4)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(13, 13, 15, 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Ampel heute',
                  style: TextStyle(fontSize: 12, color: muted),
                ),
                Text(
                  status.ueberschrift,
                  style: Typografie.numeric(
                    TypografieGroesse.title2,
                  ).copyWith(color: ink),
                ),
                Text(
                  status.unterzeile,
                  style: TextStyle(fontSize: 15, height: 1.3, color: muted),
                ),
                const SizedBox(height: 8),
                for (final wert in status.werte) ...[
                  if (wert != status.werte.first)
                    Container(height: 1, color: line),
                  _Wertzeile(wert),
                ],
                for (final absatz in status.absaetze)
                  Padding(
                    padding: const EdgeInsets.only(top: 11),
                    child: Text(
                      absatz,
                      style: TextStyle(fontSize: 15, height: 1.35, color: ink),
                    ),
                  ),
                if (status.zeigtHealthEinstellungen)
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: CupertinoButton(
                      key: const Key('erholung-werte-health-einstellungen'),
                      padding: EdgeInsets.zero,
                      onPressed: onHealthEinstellungen,
                      alignment: Alignment.centerLeft,
                      child: const Text(
                        'Health-Einstellungen öffnen',
                        style: TextStyle(fontSize: 15),
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

/// Eine der vier Wertzeilen: Name und Wert, darunter der Balken (wenn es
/// einen gibt) und die Bildunterschrift.
class _Wertzeile extends StatelessWidget {
  const _Wertzeile(this.wert);

  final Vitalwert wert;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final balken = wert.balken;

    return Padding(
      key: Key('erholung-werte-zeile-${wert.metrik.name}'),
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  wert.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: ink,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                wert.wert,
                style: Typografie.tabularNumbers(
                  Typografie.numeric(TypografieGroesse.title3),
                ).copyWith(
                  color: CupertinoDynamicColor.resolve(wert.ton, context),
                ),
              ),
            ],
          ),
          if (balken != null)
            _Normalband(
              key: Key('erholung-werte-balken-${wert.metrik.name}'),
              balken: balken,
              ton: wert.ton,
            ),
          Padding(
            padding: EdgeInsets.only(top: balken == null ? 1 : 0),
            child: Text(
              wert.bildunterschrift,
              style: TextStyle(fontSize: 12, color: muted),
            ),
          ),
        ],
      ),
    );
  }
}

/// Der Balken hinter einem Wert: grüner Bereich ohne Warnsignal, Strich für
/// den eigenen Median, Marke für heute Nacht.
///
/// Den gibt es nur mit Median — ohne ihn baut [_Wertzeile] ihn gar nicht
/// erst, statt ein leeres Feld zu zeichnen.
class _Normalband extends StatelessWidget {
  const _Normalband({super.key, required this.balken, required this.ton});

  final Normalbalken balken;
  final CupertinoDynamicColor ton;

  static const _hoehe = 14.0;
  static const _spur = 7.0;
  static const _marke = 4.0;
  static const _strich = 11.0;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final ok = CupertinoDynamicColor.resolve(Palette.ok, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final markenfarbe = CupertinoDynamicColor.resolve(ton, context);
    final bereich = balken.normalbereichAnteil;

    return Padding(
      padding: const EdgeInsets.only(top: 5, bottom: 7),
      child: SizedBox(
        height: _hoehe,
        child: LayoutBuilder(
          builder: (context, grenzen) {
            final breite = grenzen.maxWidth;
            final von = bereich.von * breite;
            final bis = bereich.bis * breite;
            final platz = breite - _marke;
            var markeLinks = balken.markeAnteil * breite - _marke / 2;
            if (markeLinks < 0) markeLinks = 0;
            if (markeLinks > platz) markeLinks = platz < 0 ? 0 : platz;

            return Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: (_hoehe - _spur) / 2,
                  height: _spur,
                  child: _Spur(farbe: ink.withValues(alpha: 0.07)),
                ),
                Positioned(
                  left: von,
                  width: bis > von ? bis - von : 0,
                  top: (_hoehe - _spur) / 2,
                  height: _spur,
                  child: _Spur(farbe: ok.withValues(alpha: 0.3)),
                ),
                Positioned(
                  left: balken.medianAnteil * breite - 0.75,
                  width: 1.5,
                  top: (_hoehe - _strich) / 2,
                  height: _strich,
                  child: ColoredBox(color: muted.withValues(alpha: 0.65)),
                ),
                Positioned(
                  left: markeLinks,
                  width: _marke,
                  top: 0,
                  height: _hoehe,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: markenfarbe,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Spur extends StatelessWidget {
  const _Spur({required this.farbe});

  final Color farbe;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: farbe,
      borderRadius: BorderRadius.circular(_Normalband._spur / 2),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────
// Das Signalband
// ─────────────────────────────────────────────────────────────────────────

/// „Letzte 30 Tage" — je ein Balken pro Tag der Signalhistorie, ältester
/// zuerst.
///
/// **Der Schlüssel sitzt auf dem Balken selbst**, nicht auf einer Hülle:
/// Seine gerenderte Höhe trägt die Regel „gemessen → 30 + Signale · 14,
/// nicht gemessen → 10", und ein grauer Stummel ist etwas anderes als ein
/// grüner Balken.
class WerteSignalband extends StatelessWidget {
  const WerteSignalband({super.key, required this.tage});

  final List<DaySignals> tage;

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final legende = bandLegende(tage);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: InsetCard(
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Ausrutscher oder Serie? Die Höhe ist die Zahl der Signale '
                'am Tag.',
                style: TextStyle(fontSize: 12, color: muted),
              ),
              const SizedBox(height: 8),
              // Ohne feste Höhe: Der höchste Balken gibt die Zeile vor,
              // statt dass vier Signale an einem Tag aus einem Rahmen von
              // 60 herauslaufen.
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < tage.length; i++) ...[
                    if (i > 0) const SizedBox(width: 2),
                    Expanded(
                      child: SizedBox(
                        key: Key('erholung-werte-band-tag-$i'),
                        height: bandHoehe(tage[i]),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: CupertinoDynamicColor.resolve(
                              bandFarbe(tage[i]),
                              context,
                            ),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              // `Wrap`, nicht `Row`: Drei Zähler nebeneinander passen auf
              // einem schmalen Gerät nicht immer in eine Zeile, und eine
              // abgeschnittene Legende erklärt nichts.
              Wrap(
                spacing: 14,
                runSpacing: 5,
                children: [
                  _Legende(Palette.ok, 'ohne Signal · ${legende.ohneSignal}'),
                  _Legende(Palette.bib, 'ein Signal · ${legende.einSignal}'),
                  _Legende(
                    Palette.warn,
                    'zwei und mehr · ${legende.zweiUndMehr}',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Legende extends StatelessWidget {
  const _Legende(this.farbe, this.text);

  final CupertinoDynamicColor farbe;
  final String text;

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: CupertinoDynamicColor.resolve(farbe, context),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 5),
        Text(text, style: TextStyle(fontSize: 11, color: muted)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Die Schwellen
// ─────────────────────────────────────────────────────────────────────────

/// „Die Schwellen" — vier Zeilen mit Regel **und** ausgerechnetem Wert.
class WerteSchwellen extends StatelessWidget {
  const WerteSchwellen({super.key, required this.zeilen});

  final List<SchwellenZeile> zeilen;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final line = CupertinoDynamicColor.resolve(Palette.line, context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: InsetCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final zeile in zeilen) ...[
              if (zeile != zeilen.first)
                Padding(
                  padding: const EdgeInsets.only(left: 13),
                  child: Container(height: 1, color: line),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 9,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            zeile.titel,
                            style: Typografie.numeric(
                              TypografieGroesse.body,
                            ).copyWith(color: ink),
                          ),
                          Text(
                            zeile.regel,
                            style: TextStyle(fontSize: 12, color: muted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      zeile.wert,
                      style: Typografie.numeric(
                        TypografieGroesse.body,
                      ).copyWith(color: muted),
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
