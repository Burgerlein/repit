// Die Übersicht oben auf dem Ernährungs-Tag (#406) — nach Tims YAZIO-Bild
// vom 07.11.2026, das als freigegebener Entwurf gilt. Gezeichnet in
// `docs/screens/screens/ernaehrung.js`, `UEBERSICHT`; Zustände `tag`,
// `leer`, `laedt`, `kein-ziel`, `ueber`.
//
// Sie **ersetzt die drei Ringe** vom 04.11.2026. Verhalten und API sind
// durch `test/ernaehrung/ernaehrung_uebersicht_test.dart` festgelegt.
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:trainings_core/trainings_core.dart';

import '../core/messwert.dart';
import '../design/inset_card.dart';
import '../design/palette.dart';
import '../design/platzhalter.dart';
import '../design/typografie.dart';
import '../design/zahlen.dart';
import 'ernaehrung_provider.dart';

/// Was die Übersicht zeigt — **einmal** aus dem Tag gerechnet, nicht in
/// jedem Baustein für sich. Reine Rechnung, ohne Widget.
///
/// **„Übrig" = Ziel − gegessen + verbrannt.** Verbrannt ist allein der
/// Trainingszuschlag (#389/#390, Vorgabe des Koordinators); den gibt es
/// noch nicht. Solange er fehlt, rechnet „Übrig" ohne ihn — er wird nicht
/// als `0` erfunden, er kommt nur nicht dazu. Angezeigt wird er als
/// [ohneWert].
@immutable
class UebersichtWerte {
  const UebersichtWerte._({
    required this.gegessenLaedt,
    required this.uebrigLaedt,
    required this.gegessenKcal,
    required this.verbranntKcal,
    required this.restKcal,
    required this.anteil,
  });

  factory UebersichtWerte.aus(ErnaehrungsTag tag, {double? verbranntKcal}) {
    final gegessenLaedt = tag.gegessen is NochNie<Naehrwerte>;
    final gegessen = gegessenWerte(tag)?.kcal;
    final ziel = tag.zielKcal;
    // Der Rest hängt an beiden: Solange eines davon noch gelesen wird, ist
    // nichts entschieden (Fehler `01`) — auch nicht „kein Ziel".
    final uebrigLaedt = gegessenLaedt || (ziel == null && tag.zielLaedt);
    final rest = ziel == null || gegessen == null
        ? null
        : ziel - gegessen + (verbranntKcal ?? 0);
    final anteil = rest == null || ziel == null || ziel <= 0
        ? null
        : rest < 0
        ? 1.0
        : (1 - rest / ziel).clamp(0.0, 1.0);
    return UebersichtWerte._(
      gegessenLaedt: gegessenLaedt,
      uebrigLaedt: uebrigLaedt,
      gegessenKcal: gegessen,
      verbranntKcal: verbranntKcal,
      restKcal: uebrigLaedt ? null : rest,
      anteil: uebrigLaedt ? null : anteil,
    );
  }

  final bool gegessenLaedt;
  final bool uebrigLaedt;
  final double? gegessenKcal;
  final double? verbranntKcal;

  /// Negativ heißt über dem Ziel. `null`: kein Ziel, nichts bekannt oder
  /// noch nicht gelesen.
  final double? restKcal;

  /// Gefüllter Anteil des Bogens, 0 bis 1, über dem Ziel gedeckelt.
  final double? anteil;

  bool get ueber => (restKcal ?? 0) < 0;
}

/// Die Karte „Übersicht": Kopf mit „Details", in der Mitte der Bogen mit
/// „Übrig", links „Gegessen", rechts „Verbrannt", darunter drei Balken.
///
/// **Eine Form in jedem Zustand** (`CLAUDE.md`): Werte da, ohne Ziel, über
/// Ziel und lädt haben dieselbe Höhe — jede Zahl steht in einer Zeile
/// fester Höhe, der Platzhalter ist dieselbe Form in Grau. **Der Grund für
/// ein fehlendes Ziel steht nicht hier**, sondern einmal in der Zeile
/// darunter (`ErnaehrungZielFehlt`).
class ErnaehrungUebersicht extends StatelessWidget {
  const ErnaehrungUebersicht({
    super.key,
    required this.tag,
    required this.onDetails,
    this.verbranntKcal,
  });

  final ErnaehrungsTag tag;

  /// Führt zu „Woher das Ziel kommt".
  final VoidCallback onDetails;

  /// Der Trainingszuschlag des Tages (#389/#390) — bis Plan und Gym im
  /// Neubau sind, gibt es ihn nicht, und der Schirm übergibt `null`.
  final double? verbranntKcal;

  @override
  Widget build(BuildContext context) {
    final werte = UebersichtWerte.aus(tag, verbranntKcal: verbranntKcal);
    final naehrwerte = gegessenWerte(tag);
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final river = CupertinoDynamicColor.resolve(Palette.river, context);
    final makrosLaden = werte.gegessenLaedt;

    return Padding(
      key: const Key('ernaehrung-uebersicht'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: InsetCard(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Übersicht',
                      style: Typografie.numeric(
                        TypografieGroesse.title3,
                        gewicht: FontWeight.w700,
                      ).copyWith(color: ink),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: 'Details: Woher das Ziel kommt',
                    excludeSemantics: true,
                    child: GestureDetector(
                      key: const Key('ernaehrung-uebersicht-details'),
                      behavior: HitTestBehavior.opaque,
                      onTap: onDetails,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          'Details ›',
                          style: TextStyle(fontSize: 15, color: river),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: _Seite(
                      key: const Key('ernaehrung-uebersicht-gegessen'),
                      name: 'Gegessen',
                      laedt: werte.gegessenLaedt,
                      wert: werte.gegessenKcal,
                    ),
                  ),
                  SizedBox(
                    width: UebersichtBogen.breite,
                    height: UebersichtBogen.hoehe,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: UebersichtBogen(
                            key: const Key('ernaehrung-uebersicht-bogen'),
                            anteil: werte.anteil,
                            ueber: werte.ueber,
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 40,
                          child: _Uebrig(werte: werte),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _Seite(
                      key: const Key('ernaehrung-uebersicht-verbrannt'),
                      name: 'Verbrannt',
                      // Der Zuschlag hängt nicht an Apple Health und am
                      // Ladezustand des Tages nicht; geladen wird er
                      // dennoch mit, damit die Karte in einem Zug grau ist.
                      laedt: werte.gegessenLaedt,
                      wert: werte.verbranntKcal,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _saeule(
                      schluessel: 'kohlenhydrate',
                      label: 'Kohlenhydrate',
                      wert: naehrwerte?.kohlenhydrateG,
                      ziel: tag.makroziele.kohlenhydrateZielG,
                      farbe: Palette.river,
                      laedt: makrosLaden,
                      beispiel: '150 / 260 g',
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _saeule(
                      schluessel: 'eiweiss',
                      label: 'Eiweiß',
                      wert: naehrwerte?.eiweissG,
                      ziel: tag.makroziele.eiweissMinG,
                      farbe: Palette.iron,
                      laedt: makrosLaden,
                      beispiel: '150 / 220 g',
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _saeule(
                      schluessel: 'fett',
                      label: 'Fett',
                      wert: naehrwerte?.fettG,
                      ziel: tag.makroziele.fettMinG,
                      farbe: Palette.ok,
                      laedt: makrosLaden,
                      beispiel: '90 / 62 g',
                    ),
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

/// Ein Balken gegen sein Ziel. **Ohne Ziel trägt er keinen Wert** — ein
/// Balken gegen nichts wäre keiner, und `0` behauptete „nichts gegessen".
MakroSaeule _saeule({
  required String schluessel,
  required String label,
  required double? wert,
  required double? ziel,
  required Color farbe,
  required bool laedt,
  required String beispiel,
}) => MakroSaeule(
  key: Key('ernaehrung-uebersicht-$schluessel'),
  label: label,
  wert: laedt || ziel == null ? null : wert,
  ziel: laedt ? null : ziel,
  farbe: farbe,
  platzhalter: laedt ? beispiel : null,
);

/// Zahl und Wort im Bogen. Der Vorlesetext nennt den Zustand, nicht das
/// Zeichen — `–/–` läse VoiceOver als „Strich Schrägstrich Strich".
class _Uebrig extends StatelessWidget {
  const _Uebrig({required this.werte});

  final UebersichtWerte werte;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final warn = CupertinoDynamicColor.resolve(Palette.warn, context);
    final rest = werte.restKcal;
    final ueber = werte.ueber;

    final stil = Typografie.tabularNumbers(
      Typografie.numeric(TypografieGroesse.title, gewicht: FontWeight.w700),
    ).copyWith(height: 1.1);
    final farbe = rest == null ? muted : (ueber ? warn : ink);

    final String vorlesetext;
    if (werte.uebrigLaedt) {
      vorlesetext = 'Übrig, wird geladen';
    } else if (rest == null) {
      vorlesetext = 'Übrig, keine Werte';
    } else if (ueber) {
      vorlesetext = '${formatNumber(-rest)} Kilokalorien über dem Ziel';
    } else {
      vorlesetext = 'Noch ${formatNumber(rest)} Kilokalorien übrig';
    }

    return Semantics(
      key: const Key('ernaehrung-uebersicht-uebrig'),
      label: vorlesetext,
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: textMass(context, '540', stil).height,
            child: Center(
              child: werte.uebrigLaedt
                  ? Platzhalter(beispiel: '1.540', stil: stil)
                  : Text(
                      rest == null ? ohneWert : formatNumber(rest.abs()),
                      maxLines: 1,
                      style: stil.copyWith(color: farbe),
                    ),
            ),
          ),
          Text(
            ueber ? 'über Ziel' : 'Übrig',
            maxLines: 1,
            style: TextStyle(fontSize: 13, color: muted),
          ),
        ],
      ),
    );
  }
}

/// Links „Gegessen", rechts „Verbrannt": Zahl über Wort.
class _Seite extends StatelessWidget {
  const _Seite({
    super.key,
    required this.name,
    required this.laedt,
    required this.wert,
  });

  final String name;
  final bool laedt;
  final double? wert;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final stil = Typografie.tabularNumbers(
      Typografie.numeric(TypografieGroesse.title3, gewicht: FontWeight.w700),
    ).copyWith(height: 1.1);
    final wert = this.wert;

    final vorlesetext = laedt
        ? '$name, wird geladen'
        : wert == null
        ? '$name, keine Werte'
        : '$name ${formatNumber(wert)} Kilokalorien';

    return Semantics(
      label: vorlesetext,
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: textMass(context, '1.260', stil).height,
            child: Center(
              child: laedt
                  ? Platzhalter(beispiel: '1.260', stil: stil)
                  : Text(
                      wert == null ? ohneWert : formatNumber(wert),
                      maxLines: 1,
                      style: stil.copyWith(color: wert == null ? muted : ink),
                    ),
            ),
          ),
          Text(name, maxLines: 1, style: TextStyle(fontSize: 13, color: muted)),
        ],
      ),
    );
  }
}

/// Der Bogen über 270°, die Öffnung nach unten — gefüllt von links unten
/// im Uhrzeigersinn mit dem Teil des Budgets, der verbraucht ist.
class UebersichtBogen extends StatelessWidget {
  const UebersichtBogen({super.key, required this.anteil, this.ueber = false});

  static const double breite = 148;
  static const double hoehe = 128;

  /// 0 bis 1. `null` heißt ungefüllt — kein Ziel oder noch nicht gelesen.
  /// Nie eine erfundene `0`.
  final double? anteil;

  /// Über dem Ziel: voll und in [Palette.warn].
  final bool ueber;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    return CustomPaint(
      painter: _BogenPainter(
        anteil: anteil,
        spur: ink.withValues(alpha: 0.07),
        farbe: CupertinoDynamicColor.resolve(
          ueber ? Palette.warn : Palette.river,
          context,
        ),
      ),
    );
  }
}

class _BogenPainter extends CustomPainter {
  _BogenPainter({
    required this.anteil,
    required this.spur,
    required this.farbe,
  });

  final double? anteil;
  final Color spur;
  final Color farbe;

  static const double _strich = 11;

  /// 135° — links unten; der Bogen läuft im Uhrzeigersinn über 270°.
  static const double _anfang = 3 * math.pi / 4;
  static const double _umfang = 3 * math.pi / 2;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = math.min(size.width / 2, size.height * 0.56) - _strich / 2;
    if (radius <= 0) return;
    final mitte = Offset(size.width / 2, radius + _strich / 2);
    final kreis = Rect.fromCircle(center: mitte, radius: radius);
    final stift = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strich
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(kreis, _anfang, _umfang, false, stift..color = spur);
    final a = anteil;
    // Erst über 2 % wird gefüllt — ein Strichlein kürzer als die runde
    // Kappe sähe aus wie ein Punkt, nicht wie „fast nichts".
    if (a != null && a > 0.02) {
      canvas.drawArc(
        kreis,
        _anfang,
        _umfang * a.clamp(0.0, 1.0),
        false,
        stift..color = farbe,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BogenPainter alt) =>
      alt.anteil != anteil || alt.spur != spur || alt.farbe != farbe;
}

/// Ein Makrobalken der Übersicht: Name, Balken, „gegessen / Ziel g" —
/// schmal, damit drei nebeneinander passen wie im Bild.
///
/// **Drei Fassungen, eine Form**: Wert gegen Ziel; ohne Ziel [ohneWert]
/// und der Balken leer; beim Laden eine graue Form in der Breite von
/// [platzhalter]. Über dem Ziel läuft der Balken nicht weiter, er färbt
/// sich um.
class MakroSaeule extends StatelessWidget {
  const MakroSaeule({
    super.key,
    required this.label,
    required this.wert,
    required this.ziel,
    required this.farbe,
    this.platzhalter,
  });

  final String label;

  /// `null`, wenn es kein Ziel gibt oder noch gelesen wird — nie `0`.
  final double? wert;
  final double? ziel;
  final Color farbe;

  /// Beispieltext der grauen Form; gesetzt allein beim Laden.
  final String? platzhalter;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final wert = this.wert;
    final ziel = this.ziel;
    final hatWert = wert != null && ziel != null && ziel > 0;
    final ueber = hatWert && wert > ziel;
    final anteil = hatWert ? (wert / ziel).clamp(0.0, 1.0) : 0.0;
    final zahlStil = Typografie.tabularNumbers(
      TextStyle(fontSize: 13, color: muted),
    );
    final beispiel = platzhalter;

    final vorlesetext = beispiel != null
        ? '$label, wird geladen'
        : hatWert
        ? '$label ${formatNumber(wert)} von ${formatNumber(ziel)} Gramm'
        : '$label, keine Werte';

    return Semantics(
      label: vorlesetext,
      excludeSemantics: true,
      child: Column(
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: ink,
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Container(
              height: 6,
              color: ink.withValues(alpha: 0.06),
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: anteil,
                child: Container(
                  color: CupertinoDynamicColor.resolve(
                    ueber ? Palette.warn : farbe,
                    context,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 5),
          SizedBox(
            height: textMass(context, '0 / 0 g', zahlStil).height,
            child: Center(
              child: beispiel != null
                  ? Platzhalter(beispiel: beispiel, stil: zahlStil)
                  : Text(
                      hatWert
                          ? '${formatNumber(wert)} / ${formatNumber(ziel)} g'
                          : ohneWert,
                      maxLines: 1,
                      style: zahlStil,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
