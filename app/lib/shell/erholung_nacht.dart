// Die Nachtkarte und die Tagschlaf-Kachel des Erholung-Schirms (#115) —
// Abschnitt 5 und 5b. Eigene Datei, weil `erholung_abschnitte.dart` mit
// ihnen über ein paar hundert Zeilen wuchs (`CLAUDE.md`, „Views bleiben
// klein").
import 'package:flutter/cupertino.dart';
import 'package:trainings_core/trainings_core.dart';

import '../data/schlaf_eintrag.dart';
import '../design/formatierung.dart';
import '../design/hypnogramm.dart';
import '../design/icon_row.dart';
import '../design/inset_card.dart';
import '../design/palette.dart';
import '../design/section_header.dart';
import '../health/health_types.dart';
import 'erholung_abschnitte.dart';

// ─────────────────────────────────────────────────────────────────────────
// Abschnitt 5 + 5b — Nachtkarte und Tagschlaf
// ─────────────────────────────────────────────────────────────────────────

/// Die Nachtkarte — Entwurf `nightCard` in `docs/screens/components.js`.
///
/// Gruppenkopf „Schlaf" ohne Zusatz, links Schlafdauer, rechts der Score
/// **gegen seine erreichbare Punktzahl** („82 / 100", „48 / 70") und
/// darunter Datum vor den Uhrzeiten („Mo 11.10. · 23:10–06:15").
///
/// **Die Karte ist keine Tür** (#259; Tim am 03.11.2026: „auf die
/// Schlaf-Seite nur noch über den Ring oben auf der Erholungsseite
/// kommen"). Bis dahin führte ihr Kopf dorthin — derselbe Schirm, den
/// auch der Schlaf-Ring öffnet. Dauer, Zeitfenster und Score bleiben
/// stehen, sie tragen Auskunft; weg fällt die Tippfläche **und mit ihr
/// der Winkel** hinter dem Zeitfenster: Ein „›" ohne Ziel sieht drückbar
/// aus und führt nirgendwohin.
class ErholungNachtkarte extends StatelessWidget {
  const ErholungNachtkarte({
    super.key,
    required this.nacht,
    required this.kern,
    required this.score,
    required this.laeuft,
  });

  /// Die Nacht mit ihren Abschnitten — `null`, wenn für heute keine
  /// vorliegt.
  final SleepNight? nacht;

  /// Dieselbe Nacht als Kernwert; `null` auch dann, wenn [nacht] nur aus
  /// Wachabschnitten besteht.
  final RecoveryNight? kern;

  final SleepScore? score;

  /// `true`, solange der Schlaf-Lauf noch unterwegs ist. Dann steht **kein**
  /// Grund da — der gehört zu einem fertigen Lauf ohne Treffer
  /// (`docs/todo/01`).
  final bool laeuft;

  /// Die beiden Höhenbänder, in denen Kennzeile und Wert sitzen — links wie
  /// rechts dieselben. Nur so fangen „SCHLAFDAUER" und der Score auf
  /// gleicher Höhe an und beide Spalten sind gleich hoch; eine Ausrichtung
  /// an den Grundlinien richtete nur die **ersten** Zeilen aneinander aus,
  /// und weil die Dauer links groß und das Fenster rechts klein gesetzt
  /// ist, stünde die rechte zweite Zeile danach weit über der linken.
  static const double _bandOben = 20;
  static const double _bandUnten = 30;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final nacht = this.nacht;
    final kern = this.kern;
    final score = this.score;

    final dauer = kern == null ? 'keine Daten' : dauerText(kern.asleepMinutes);
    final String fenster;
    if (nacht != null) {
      fenster = _fensterText(nacht);
    } else if (laeuft) {
      fenster = 'wird geladen';
    } else {
      fenster = beideMoeglichkeiten;
    }

    return Column(
      key: const Key('erholung-nachtkarte'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Schlaf'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: InsetCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  key: const Key('erholung-nacht-kopf'),
                  padding: const EdgeInsets.fromLTRB(13, 13, 13, 0),
                  child: Row(
                    // `start` statt `stretch`: Bricht rechts ein langer
                    // Grund um („nicht aufgezeichnet oder nicht
                    // freigegeben"), wächst **nur** die rechte Spalte
                    // nach unten. Die linke springt nicht mit, obwohl
                    // sich an ihr nichts geändert hat.
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 5 zu 4: Die linke Spalte trägt die große Zahl
                      // („5 Std. 28 Min." bei 22 Punkt), die rechte eine
                      // Zeile bei 12 Punkt. Zwei gleiche Hälften
                      // brächten links auf schmalen Geräten einen
                      // Umbruch mitten in der Dauer.
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _band(
                              hoehe: _bandOben,
                              ausrichtung: Alignment.centerLeft,
                              kind: Text(
                                'SCHLAFDAUER',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.6,
                                  color: muted,
                                ),
                              ),
                            ),
                            _band(
                              hoehe: _bandUnten,
                              ausrichtung: Alignment.centerLeft,
                              kind: Text(
                                dauer,
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                  color: ink,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _band(
                              hoehe: _bandOben,
                              ausrichtung: Alignment.centerRight,
                              kind: Text(
                                _scoreText(score),
                                textAlign: TextAlign.right,
                                style: TextStyle(fontSize: 15, color: ink),
                              ),
                            ),
                            _band(
                              hoehe: _bandUnten,
                              ausrichtung: Alignment.centerRight,
                              kind: Text(
                                fenster,
                                textAlign: TextAlign.right,
                                style: TextStyle(fontSize: 12, color: muted),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (nacht != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(13, 10, 13, 13),
                    child: Hypnogramm(session: nacht.session),
                  )
                else
                  const SizedBox(height: 13),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Ein Höhenband mit mittig sitzendem Inhalt. `ConstrainedBox` statt
  /// `SizedBox`, damit ein umbrechender Text weiter wachsen darf.
  static Widget _band({
    required double hoehe,
    required Alignment ausrichtung,
    required Widget kind,
  }) {
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: hoehe),
      child: Align(alignment: ausrichtung, heightFactor: 1, child: kind),
    );
  }

  /// „82 / 100" bzw. „48 / 70" — der Score gegen das, was in dieser Nacht
  /// überhaupt erreichbar war. Ohne Einschlafzeit bleibt die Teilnote
  /// Zubettgehzeit weg, dann sind es 70 Punkte, und das soll man sehen
  /// statt es auszurechnen.
  static String _scoreText(SleepScore? score) =>
      score == null ? keinWert : '${score.total} / ${score.maxTotal}';

  /// „Mo 11.10. · 23:10–06:15".
  ///
  /// **Das Datum nennt den Abend, an dem die Nacht begann** — auch wenn das
  /// Einschlafen schon nach Mitternacht lag. Gemeint ist dieselbe Nacht,
  /// die der Schirm als die von heute führt, und zwei verschiedene Daten
  /// für dieselbe Nacht auf einem Schirm wären schlimmer als gar keins.
  ///
  /// Gerechnet wird über [BerlinCalendar], nicht über
  /// `date.subtract(Duration(days: 1))`: `SleepNight.date` ist ein
  /// UTC-Zeitpunkt auf Berliner Mitternacht, und minus 24 Stunden landet
  /// über eine Zeitumstellung hinweg einen Tag zu früh.
  static String _fensterText(SleepNight nacht) {
    final geometrie = HypnogrammGeometrie(nacht.session);
    final von = geometrie.von, bis = geometrie.bis;
    if (von == null || bis == null) return beideMoeglichkeiten;

    final abend = kalendertag(BerlinCalendar.addDays(nacht.date, -1));
    return '${Format.wochentagKurz(abend)} ${Format.tagMonat(abend)} \u00B7 '
        '${Format.uhrzeit(von)}\u2013${Format.uhrzeit(bis)}';
  }
}

/// Die Tagschlaf-Kachel — nur an Tagen mit Tagschlaf, und sie führt nach
/// `tagschlaf`, **nicht** nach `schlaf`.
///
/// **Sie fällt weg, wenn es nichts zu zeigen gibt**, und das ist kein
/// Verstoß gegen „Eine Anzeige, die es gibt, hat genau eine Form": Null
/// Nickerchen ist kein fehlender Wert, sondern kein Ereignis. Der Entwurf
/// sagt es wörtlich (`docs/screens/screens/erholung.js`): „Eine fehlende
/// Statuskarte wäre mehrdeutig, ein fehlender Tagschlaf-Kasten nicht: Wer
/// nicht geschlafen hat, hat nicht geschlafen."
class ErholungTagschlaf extends StatelessWidget {
  const ErholungTagschlaf({
    super.key,
    required this.naps,
    this.napEintraege = const [],
    required this.onTagschlaf,
  });

  /// Die gemessenen Nickerchen des Tages.
  final List<SleepSession> naps;

  /// Die von Hand eingetragenen desselben Tages (#209) — **zusätzlich** zu
  /// [naps], nicht statt ihrer. Dieselbe Regel wie auf dem Schlaf-Schirm:
  /// Ein Nickerchen gibt es mehrfach, ein eingetragenes ersetzt keines.
  final List<SchlafEintrag> napEintraege;

  final VoidCallback onTagschlaf;

  @override
  Widget build(BuildContext context) {
    var minuten = 0.0;
    for (final nap in naps) {
      for (final abschnitt in nap.segments) {
        if (abschnitt.stage == SleepStage.awake) continue;
        minuten +=
            abschnitt.end.difference(abschnitt.start).inMicroseconds /
            Duration.microsecondsPerMinute;
      }
    }
    // **Die eingetragene Dauer, nicht das Fenster.** Der Entwurf lässt die
    // gerechnete Dauer überschreiben, „falls du wach dazwischen lagst" —
    // und in der Fassung „nur Dauer" gibt es gar kein Fenster.
    for (final eintrag in napEintraege) {
      minuten += eintrag.schlafMinuten;
    }
    final anzahl = naps.length + napEintraege.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: InsetCard(
        child: IconRow(
          key: const Key('erholung-tagschlaf'),
          title: 'Tagschlaf',
          // **Ohne Tagesbezug** (#213). Bis zum 03.11.2026 stand hier
          // „ein Nickerchen heute"; das Wort war fest eingebaut, während
          // die Kachel ihren Tag gar nicht kennt — sie bekommt eine
          // Liste von Sitzungen und sonst nichts. Solange der Schirm nur
          // heute zeigte, stimmte es zufällig; seit er sich blättern
          // lässt (#261), wäre es eine falsche Auskunft. Den Tag
          // hereinzureichen wäre die andere Antwort, aber eine
          // Erweiterung — hier fällt die Behauptung weg.
          subtitle: anzahl == 1 ? 'ein Nickerchen' : '$anzahl Nickerchen',
          value: dauerText(minuten),
          symbol: 'bed.double',
          accent: CupertinoDynamicColor.resolve(Palette.river2, context),
          onTap: onTagschlaf,
        ),
      ),
    );
  }
}
