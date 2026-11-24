// Das Monatsraster hinter einem Kalenderknopf — **der Baustein**, den das
// Schlaf-Kalenderblatt (#92, #177, #241, #258) und der Ernährungs-Kalender
// (#409) teilen. Was ein Tag bedeutet und welchen Ring er trägt, sagt der
// Schirm ([MonatsblattTag]); Raster, Monatskopf, Wischen, die Marken für
// heute und den gewählten Tag und der Tipp gehören hierher.
//
// Entwurf: `kalenderblatt` und `kalenderZelle` in
// `docs/screens/components.js`. Die Begründungen der Einzelheiten stehen
// weiter am Schlaf-Kalender (`schlaf_kalenderblatt.dart`), wo sie
// entstanden sind; hier steht nur, was beide teilen.
//
// **Das Raster hat immer sechs Zeilen** (#258) — wie viele ein Monat
// braucht, hängt am Wochentag des Ersten; gezeichnet werden immer sechs,
// damit das Blatt beim Blättern nicht springt. Die leere Zelle holt ihre
// Maße aus derselben Stelle wie die volle ([monatsblattRing],
// [_zellenAbstand]).
import 'package:flutter/cupertino.dart';
import 'package:trainings_core/trainings_core.dart';

import '../design/formatierung.dart';
import '../design/palette.dart';
import 'schlaf_abschnitte.dart';

/// Der Ring einer Tageszelle: breit wie hoch. **Die eine Stelle**, an der
/// die Höhe einer Rasterzeile entsteht.
const double monatsblattRing = 30;

/// Der Abstand über und unter dem Ring, für volle und leere Zellen.
const EdgeInsets _zellenAbstand = EdgeInsets.symmetric(vertical: 4);

/// Sechs Zeilen zu sieben Tagen (#258).
const int _rasterZeilen = 6;

/// Was ein Schirm über einen Tag sagt.
@immutable
class MonatsblattTag {
  const MonatsblattTag({required this.ring, required this.tippbar});

  /// Der Ring um die Ziffer — `null` heißt **gar kein Ring**. Bekommt die
  /// Ziffer und legt sie in seine Mitte.
  final Widget Function(Widget ziffer)? ring;

  /// Stumm heißt: blasse Ziffer, kein Tipp.
  final bool tippbar;
}

/// Der Monatserste als **reines Datum** (UTC-Mitternacht des
/// Kalendertags). Nicht `BerlinCalendar.startOfDay`: Das ist im Sommer
/// 22:00 des Vortags, und dessen `.month` wäre am Ersten der Vormonat.
DateTime monatsErster(DateTime tag) {
  final kalender = kalendertag(tag);
  return DateTime.utc(kalender.year, kalender.month, 1);
}

/// `DateTime.utc` normalisiert Monat 0 oder 13 über die Jahresgrenze.
DateTime monatVerschoben(DateTime monat, int um) =>
    DateTime.utc(monat.year, monat.month + um, 1);

/// Das Blatt: Monatskopf, Wochentage, sechs Zeilen, Satz darunter.
///
/// **Ohne eigenen Zustand.** Welcher Monat gezeigt wird, hält der Schirm —
/// er braucht ihn ohnehin, um die Daten dieses Monats zu lesen. Pfeil und
/// Wischgeste hängen an **denselben** zwei Rückrufen; `null` heißt „am
/// Rand", dann ist der Pfeil aus und der Wisch stößt an (#241).
class Monatsblatt extends StatelessWidget {
  const Monatsblatt({
    super.key,
    required this.schluessel,
    required this.monat,
    required this.heute,
    required this.gewaehlt,
    required this.tag,
    required this.aufTag,
    required this.aufFrueher,
    required this.aufSpaeter,
    required this.fuss,
  });

  /// Vorsilbe der Schlüssel: `<schluessel>-tag-<ISO-Tag>`,
  /// `<schluessel>-monat-frueher` und `-spaeter`.
  final String schluessel;

  /// Der gezeigte Monat als sein Erster, als reines Datum ([monatsErster]).
  final DateTime monat;

  /// Berliner Tagesbeginn von heute und vom gewählten Tag.
  final DateTime heute;
  final DateTime? gewaehlt;

  /// Was der Schirm über einen Tag sagt; bekommt den Berliner Tagesbeginn.
  final MonatsblattTag Function(DateTime tag) tag;

  /// Ein Tipp auf einen tippbaren Tag. Das Blatt schließt sich danach.
  final void Function(DateTime tag) aufTag;

  final VoidCallback? aufFrueher;
  final VoidCallback? aufSpaeter;

  /// Der Satz unter dem Raster — Sache des Schirms: Er erklärt, was die
  /// Formen dort bedeuten.
  final String fuss;

  @override
  Widget build(BuildContext context) {
    final jahr = monat.year;
    final monatsnummer = monat.month;
    final tageImMonat = DateTime.utc(jahr, monatsnummer + 1, 0).day;

    final surface = CupertinoDynamicColor.resolve(Palette.surface, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);

    final erster = BerlinCalendar.startOfDay(
      DateTime.utc(jahr, monatsnummer, 1),
    );
    // `DateTime.monday` ist 1 — die erste Spalte ist Montag.
    final versatz = BerlinCalendar.weekday(erster) - 1;

    final zellen = <Widget>[
      for (var i = 0; i < versatz; i++) const Expanded(child: _LeereZelle()),
      for (var n = 1; n <= tageImMonat; n++)
        Expanded(
          child: _Kalendertag(
            schluessel: schluessel,
            tag: BerlinCalendar.startOfDay(DateTime.utc(jahr, monatsnummer, n)),
            sagt: tag,
            heute: heute,
            gewaehlt: gewaehlt,
            aufTag: aufTag,
          ),
        ),
    ];
    while (zellen.length < _rasterZeilen * 7) {
      zellen.add(const Expanded(child: _LeereZelle()));
    }

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 0),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Monatskopf(
              schluessel: schluessel,
              monat: monat,
              aufFrueher: aufFrueher,
              aufSpaeter: aufSpaeter,
            ),
            const SizedBox(height: 10),
            // Gewischt wird über dem **Raster**, nicht über dem Kopf und
            // nicht über dem Satz darunter.
            SchlafWischen(
              aufFrueher: aufFrueher,
              aufSpaeter: aufSpaeter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      for (final kuerzel in const [
                        'Mo',
                        'Di',
                        'Mi',
                        'Do',
                        'Fr',
                        'Sa',
                        'So',
                      ])
                        Expanded(
                          child: Text(
                            kuerzel,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 11, color: muted),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  for (var zeile = 0; zeile < _rasterZeilen; zeile++)
                    Row(children: zellen.sublist(zeile * 7, zeile * 7 + 7)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 10),
              child: Text(
                fuss,
                style: TextStyle(fontSize: 11, height: 1.35, color: muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Monat und Jahr mit zwei Pfeilen.
class _Monatskopf extends StatelessWidget {
  const _Monatskopf({
    required this.schluessel,
    required this.monat,
    required this.aufFrueher,
    required this.aufSpaeter,
  });

  final String schluessel;
  final DateTime monat;
  final VoidCallback? aufFrueher;
  final VoidCallback? aufSpaeter;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);

    return Row(
      children: [
        CupertinoButton(
          key: Key('$schluessel-monat-frueher'),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          minimumSize: const Size(44, 36),
          onPressed: aufFrueher,
          child: const Icon(CupertinoIcons.chevron_back, size: 18),
        ),
        Expanded(
          child: Text(
            Format.monatUndJahr(monat),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: ink,
            ),
          ),
        ),
        CupertinoButton(
          key: Key('$schluessel-monat-spaeter'),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          minimumSize: const Size(44, 36),
          onPressed: aufSpaeter,
          child: const Icon(CupertinoIcons.chevron_forward, size: 18),
        ),
      ],
    );
  }
}

/// Ein Feld ohne Tag — genau so hoch wie eine volle Zelle (#258).
class _LeereZelle extends StatelessWidget {
  const _LeereZelle();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: _zellenAbstand,
    child: SizedBox(width: monatsblattRing, height: monatsblattRing),
  );
}

class _Kalendertag extends StatelessWidget {
  const _Kalendertag({
    required this.schluessel,
    required this.tag,
    required this.sagt,
    required this.heute,
    required this.gewaehlt,
    required this.aufTag,
  });

  final String schluessel;
  final DateTime tag;
  final MonatsblattTag Function(DateTime tag) sagt;
  final DateTime heute;
  final DateTime? gewaehlt;
  final void Function(DateTime tag) aufTag;

  @override
  Widget build(BuildContext context) {
    final aussage = sagt(tag);

    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final river = CupertinoDynamicColor.resolve(Palette.river, context);
    final scheibe = CupertinoDynamicColor.resolve(Palette.river2, context);

    final istHeute = tag == heute;
    final istGewaehlt = gewaehlt != null && tag == gewaehlt;

    // Die Ziffer trägt die Tür: blass heißt stumm, heute in Flussblau.
    final ziffer = !aussage.tippbar ? muted : (istHeute ? river : ink);

    final zifferntext = Text(
      '${int.parse(BerlinCalendar.dayKey(tag).split('-')[2])}',
      style: TextStyle(
        fontSize: 12,
        fontWeight: istHeute || istGewaehlt ? FontWeight.w600 : FontWeight.w400,
        color: ziffer,
      ),
    );

    // **Gar kein Ring heißt gar kein Ring** — die Ziffer steht trotzdem
    // auf denselben Punkten; das ist die Zellenhöhe (#258).
    final ring = aussage.ring;
    final mitte = ring == null
        ? SizedBox(
            width: monatsblattRing,
            height: monatsblattRing,
            child: Center(child: zifferntext),
          )
        : ring(zifferntext);

    final inhalt = Padding(
      padding: _zellenAbstand,
      child: Column(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: istGewaehlt ? scheibe : null,
            ),
            child: mitte,
          ),
        ],
      ),
    );

    final key = Key('$schluessel-tag-${BerlinCalendar.dayKey(tag)}');

    if (!aussage.tippbar) return KeyedSubtree(key: key, child: inhalt);

    return GestureDetector(
      key: key,
      behavior: HitTestBehavior.opaque,
      onTap: () {
        aufTag(tag);
        Navigator.of(context).pop();
      },
      child: inhalt,
    );
  }
}
