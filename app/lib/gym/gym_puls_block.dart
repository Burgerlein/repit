// Der Pulsblock in der offenen Karte des Verlaufs (#512) — `heartRate` im
// Entwurfsboard (`docs/screens/components.js`), Variante „Entwurf — Puls mit
// Übungen" in `docs/screens/screens/gym-history.js`. Spec
// `docs/superpowers/specs/2026-11-16-gym-puls-design.md`, Abschnitte 5 bis 7.
//
// **Eine Anzeige, die es gibt, hat genau eine Form** (`CLAUDE.md`): Der Block
// steht in jeder offenen Karte und in jedem der vier Zustände, in derselben
// Höhe, derselben Breite, an derselben Stelle. Nur die Füllung wechselt:
//
// | Teil          | Bekannt        | LeerNachLauf | Fehlgeschlagen | NochNie |
// |---------------|----------------|--------------|----------------|---------|
// | Ø-Platz       | „Ø 123 bpm"    | `–/–`        | `–/–`          | grau    |
// | Bereich       | „90–200 bpm"   | leer         | leer           | grau    |
// | Fläche        | die Spannen    | der Grund    | der Hinweis    | grau    |
// | Bandplatz     | Band oder Satz | reserviert   | reserviert     | reserviert |
//
// Jede Höhe hier ist **gemessen** oder fest, nie geraten: Die Kopfzeile misst
// die Zahl, die Fläche ist eine Konstante, der Bandplatz fasst das Band
// **oder** drei Zeilen Erklärung — was größer ist.
//
// **Der Platzhalter gehört allein in `NochNie`.** Liegt ein Stand vor, auch
// ein `LeerNachLauf`, bleibt er stehen, auch während neu gelesen wird.
//
// **Spanne statt Linie:** „Eine Linie behauptet einen durchgehenden Wert;
// tatsächlich schwankt er innerhalb jeder Minute." Deshalb die Spanne als
// durchgehende Fläche, darüber der Mittelwert als Linie (#515, Spec 18).
// Ein Abschnitt ohne Stichprobe bleibt als **Lücke** stehen: Die Fläche
// setzt aus, die Linie bricht ab. Keine Zonen, keine Farben nach
// Höhe — Ø und Spannen sind Messungen, kein Urteil.
//
// **Das Band** steht nur im Zustand `Bekannt` und nur, wo Satz-Uhrzeiten
// einen Abschnitt ergeben haben. Pausen bleiben Lücken: Zwischen zwei
// Segmenten liegt nichts.
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:trainings_core/trainings_core.dart' show ValueSpan;

import '../core/messwert.dart';
import '../design/palette.dart';
import '../design/platzhalter.dart';
import '../design/typografie.dart';
import 'gym_puls_provider.dart';
import 'gym_puls_texte.dart';
import 'gym_verlauf_schluessel.dart';

/// Die Höhe der Fläche — fest, damit sie in allen Zuständen gleich ist. Die
/// Höhe des Entwurfs (`.hrblock svg`, 70).
const double gymPulsFlaechenHoehe = 70;

/// Die Höhe des Bands und der Abstand, den die Achse darunter braucht.
const double _bandHoehe = 15;

const double _abstandFlaeche = 4;
const double _abstandBand = 6;

/// Der Block der Sitzung [sitzungId].
class GymPulsBlock extends StatelessWidget {
  const GymPulsBlock({super.key, required this.sitzungId, required this.puls});

  final String sitzungId;
  final Messwert<GymPuls> puls;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final wertStil = Typografie.tabularNumbers(
      Typografie.numeric(
        TypografieGroesse.headline,
        gewicht: FontWeight.w400,
      ).copyWith(fontSize: 16.6, color: ink),
    );
    final bereichStil = TextStyle(fontSize: 13, color: muted);
    final satzStil = TextStyle(fontSize: 12, color: muted, height: 1.3);
    final titelStil = TextStyle(fontSize: 13, color: muted);

    // Gemessen, nicht geraten: Die Kopfzeile ist so hoch wie die Zahl.
    final kopfHoehe = math.max(
      textMass(context, '0', wertStil).height,
      textMass(context, '0', bereichStil).height,
    );

    final wert = _wert(puls, wertStil);
    final bereich = _bereich(puls, bereichStil);

    return Semantics(
      key: kGymPuls(sitzungId),
      container: true,
      // Der Vorlesetext nennt den Zustand, nicht das Zeichen.
      label: gymPulsVorlesetext(puls),
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: kopfHoehe,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Titel und Ø stehen zusammen links, der Bereich rechts.
                  // **Flexibel und verkleinernd:** Eine schmale Zeile oder
                  // eine große Schrift schneidet nichts ab und läuft nicht
                  // über den Rand — die Zahl wird kleiner, nicht gekürzt.
                  Flexible(
                    flex: 3,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            gymPulsTitel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: titelStil,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: SizedBox(
                            key: kGymPulsWert(sitzungId),
                            height: kopfHoehe,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: wert,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    flex: 2,
                    child: SizedBox(
                      key: kGymPulsBereich(sitzungId),
                      height: kopfHoehe,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: bereich,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: _abstandFlaeche),
            SizedBox(
              key: kGymPulsFlaeche(sitzungId),
              height: gymPulsFlaechenHoehe,
              child: _flaeche(context, satzStil),
            ),
            const SizedBox(height: _abstandBand),
            SizedBox(
              height: _bandplatzHoehe(context, satzStil),
              child: _bandplatz(context, satzStil),
            ),
          ],
        ),
      ),
    );
  }

  Widget _wert(Messwert<GymPuls> puls, TextStyle stil) => switch (puls) {
    NochNie() => Platzhalter(beispiel: gymPulsWertBeispiel, stil: stil),
    Bekannt(:final wert) => Text(
      gymPulsWertText(wert.zusammenfassung.avg),
      style: stil,
    ),
    // `–/–`: Lauf fertig, kein Wert. Nie `0`.
    LeerNachLauf() || Fehlgeschlagen() => Text(ohneWert, style: stil),
  };

  Widget _bereich(Messwert<GymPuls> puls, TextStyle stil) => switch (puls) {
    NochNie() => Platzhalter(beispiel: gymPulsBereichBeispiel, stil: stil),
    Bekannt(:final wert) => Text(
      gymPulsBereichText(wert.zusammenfassung.min, wert.zusammenfassung.max),
      style: stil,
    ),
    LeerNachLauf() || Fehlgeschlagen() => const SizedBox.shrink(),
  };

  Widget _flaeche(BuildContext context, TextStyle satzStil) {
    switch (puls) {
      case NochNie():
        return DecoratedBox(
          decoration: BoxDecoration(
            color: CupertinoDynamicColor.resolve(
              Palette.line,
              context,
            ).withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      case Bekannt(:final wert):
        return CustomPaint(
          painter: _SpannenMaler(
            spannen: wert.spannen,
            mittelwerte: wert.mittelwerte,
            farbe: CupertinoDynamicColor.resolve(Palette.wach, context),
            trennerFarbe: CupertinoDynamicColor.resolve(Palette.line, context),
            // Senkrechte Linien an den Anfängen der Übungen: Sie ordnen den
            // Ausschlag zu, ohne die Spannen zu überdecken.
            trenner: _trenner(wert),
          ),
          size: Size.infinite,
        );
      case LeerNachLauf():
        return Align(
          alignment: Alignment.topLeft,
          child: Text(
            gymPulsGrund,
            key: kGymPulsGrund(sitzungId),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: satzStil,
          ),
        );
      case Fehlgeschlagen():
        return Align(
          alignment: Alignment.topLeft,
          child: Text(
            gymPulsFehler,
            key: kGymPulsFehler(sitzungId),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: satzStil,
          ),
        );
    }
  }

  /// Der Platz unter der Fläche: so hoch wie das, was dort **am höchsten**
  /// wird — das Band samt Achse oder drei Zeilen Erklärung. In allen
  /// Zuständen derselbe.
  double _bandplatzHoehe(BuildContext context, TextStyle satzStil) {
    final dreiZeilen = textMass(context, 'X\nX\nX', satzStil).height;
    final achse = textMass(context, '0', _achsenStil(context)).height;
    return math.max(dreiZeilen, _bandHoehe + 3 + achse);
  }

  Widget _bandplatz(BuildContext context, TextStyle satzStil) {
    final stand = puls;
    if (stand is! Bekannt<GymPuls>) return const SizedBox.shrink();
    final wert = stand.wert;
    if (wert.abschnitte.isEmpty) {
      // Keine leere Fläche, keine erfundene Aufteilung: ein Satz, warum.
      return Align(
        alignment: Alignment.topLeft,
        child: Text(
          gymPulsBandGrund,
          key: kGymVerlaufBandGrund(sitzungId),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: satzStil,
        ),
      );
    }
    return Align(
      alignment: Alignment.topCenter,
      child: _Band(sitzungId: sitzungId, puls: wert),
    );
  }

  List<double> _trenner(GymPuls wert) {
    final gesamt = wert.bis.difference(wert.von).inMicroseconds;
    if (gesamt <= 0) return const [];
    return [
      for (final a in wert.abschnitte)
        a.abschnitt.start.difference(wert.von).inMicroseconds / gesamt,
    ];
  }
}

TextStyle _achsenStil(BuildContext context) => TextStyle(
  fontSize: 9.5,
  color: CupertinoDynamicColor.resolve(Palette.muted, context),
);

/// Das Band: ein Segment je Übung mit Abschnitt, **proportional zur Zeit**.
///
/// Das Feld ([kGymVerlaufBand]) ist so breit wie die **ganze
/// Trainingsdauer**; ein Segment beginnt bei `(start − von) / dauer` seiner
/// Breite und ist `(ende − start) / dauer` breit. Zwischen zwei Segmenten
/// liegt nichts — keine Verbindungslinie, keine Füllung: Die Pause ist keine
/// Übung und soll nicht wie eine aussehen.
///
/// Die Ziffer im Segment ist die **Position** der Übung in der Sitzung
/// (Spec 4.3, Punkt 4) — dieselbe wie vor der Übungszeile.
class _Band extends StatelessWidget {
  const _Band({required this.sitzungId, required this.puls});

  final String sitzungId;
  final GymPuls puls;

  @override
  Widget build(BuildContext context) {
    final iron = CupertinoDynamicColor.resolve(Palette.iron, context);
    final gesamt = puls.bis.difference(puls.von).inMicroseconds;
    final minuten = (gesamt / 60000000).round();
    final achse = _achsenStil(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          key: kGymVerlaufBand(sitzungId),
          height: _bandHoehe,
          child: LayoutBuilder(
            builder: (context, platz) => Stack(
              children: [
                for (final a in puls.abschnitte)
                  Positioned(
                    left:
                        platz.maxWidth *
                        a.abschnitt.start.difference(puls.von).inMicroseconds /
                        gesamt,
                    width:
                        platz.maxWidth *
                        a.abschnitt.end
                            .difference(a.abschnitt.start)
                            .inMicroseconds /
                        gesamt,
                    top: 0,
                    height: _bandHoehe,
                    child: Container(
                      key: kGymVerlaufBandAbschnitt(
                        sitzungId,
                        a.abschnitt.position,
                      ),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: iron.withValues(alpha: 0.26),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${a.abschnitt.position}',
                        softWrap: false,
                        overflow: TextOverflow.clip,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: iron,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 3),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(gymPulsAchseText(0), style: achse),
            Text(gymPulsAchseText((minuten / 2).round()), style: achse),
            Text(gymPulsAchseText(minuten, mitEinheit: true), style: achse),
          ],
        ),
      ],
    );
  }
}

/// Malt den Verlauf: die Spanne als durchgehende Fläche von Min bis Max,
/// darüber der Mittelwert als Linie (#515, Spec 18) — `heartRate` im
/// Entwurfsboard.
///
/// **Eine Linie allein wäre falsch** (Spec 4): Sie behauptete einen
/// durchgehenden Wert, den es nicht gab. Darum bleibt die Spanne als Fläche
/// stehen, und die Linie läuft darin.
///
/// **Lücken werden nicht überbrückt.** Ein Abschnitt ohne Stichprobe
/// ([ValueSpan.isEmpty], Mittel `null`) beendet das laufende Stück: Die
/// Fläche setzt aus, die Linie bricht ab — dieselbe Regel wie für die
/// Pausen im Band darunter. Gezeichnet wird je Stück aufeinanderfolgender
/// Abschnitte mit Messung, nie eine Kapsel oder ein Punkt bei 0 bpm. Die
/// Skala ist die der Spannen selbst; es gibt keine Zonen und keine Farbe
/// nach Höhe.
///
/// **Ein Stück aus einem einzigen Abschnitt** hat keine Fläche: Ein Polygon
/// aus einem Punkt oben und einem unten hat keine Breite und bliebe
/// unsichtbar — und dieser Abschnitt hat gemessen, er darf nicht
/// verschwinden. Er wird deshalb als schmale, abgerundete Kapsel von Min bis
/// Max gezeichnet (die Spanne, so breit wie ein Abschnitt, ohne Nachbarn zum
/// Verbinden) mit einem Punkt auf dem Mittel. Ein Strich zum Nachbarn
/// entstünde nur aus einer Messung, die es nicht gab.
class _SpannenMaler extends CustomPainter {
  _SpannenMaler({
    required this.spannen,
    required this.mittelwerte,
    required this.farbe,
    required this.trennerFarbe,
    required this.trenner,
  });

  final List<ValueSpan> spannen;
  final List<double?> mittelwerte;
  final Color farbe;
  final Color trennerFarbe;

  /// Anteile an der Breite, 0 bis 1.
  final List<double> trenner;

  static const double _luft = 4;
  static const double _flaechenAlpha = 0.22;
  static const double _linienBreite = 2;

  @override
  void paint(Canvas canvas, Size size) {
    if (spannen.isEmpty) return;

    final linie = Paint()
      ..color = trennerFarbe
      ..strokeWidth = 1;
    for (final anteil in trenner) {
      final x = anteil * size.width;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linie);
    }

    double? tiefster, hoechster;
    for (final s in spannen) {
      final min = s.min, max = s.max;
      if (min == null || max == null) continue;
      if (tiefster == null || min < tiefster) tiefster = min;
      if (hoechster == null || max > hoechster) hoechster = max;
    }
    if (tiefster == null || hoechster == null) return;

    // Keine Schwankung: trotzdem eine Höhe, sonst würde durch null geteilt.
    final bereich = (hoechster - tiefster) == 0 ? 1.0 : hoechster - tiefster;
    double y(double wert) =>
        _luft + (1 - (wert - tiefster!) / bereich) * (size.height - 2 * _luft);

    final schritt = size.width / spannen.length;
    double x(int i) => i * schritt + schritt / 2;

    // Die Mittel gehören zu den Spannen, Index für Index. Sollten die
    // Längen je auseinanderlaufen, fehlt dort das Mittel — es wird nicht
    // geraten.
    double? mittel(int i) => i < mittelwerte.length ? mittelwerte[i] : null;
    bool gemessen(int i) =>
        spannen[i].min != null && spannen[i].max != null && mittel(i) != null;

    final flaechenFarbe = Paint()
      ..color = farbe.withValues(alpha: _flaechenAlpha)
      ..style = PaintingStyle.fill;
    final linienFarbe = Paint()
      ..color = farbe
      ..style = PaintingStyle.stroke
      ..strokeWidth = _linienBreite
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final punkt = Paint()..color = farbe;
    final kapsel = Paint()
      ..color = farbe.withValues(alpha: _flaechenAlpha)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(schritt * 0.55, 3);

    void zeichneStueck(int von, int bis) {
      if (von == bis) {
        // Einzelner Abschnitt: Kapsel von Min bis Max, Punkt auf dem Mittel.
        canvas.drawLine(
          Offset(x(von), y(spannen[von].max!)),
          Offset(x(von), y(spannen[von].min!)),
          kapsel,
        );
        canvas.drawCircle(
          Offset(x(von), y(mittel(von)!)),
          _linienBreite,
          punkt,
        );
        return;
      }
      final flaeche = Path()..moveTo(x(von), y(spannen[von].max!));
      for (var i = von + 1; i <= bis; i++) {
        flaeche.lineTo(x(i), y(spannen[i].max!));
      }
      for (var i = bis; i >= von; i--) {
        flaeche.lineTo(x(i), y(spannen[i].min!));
      }
      flaeche.close();
      canvas.drawPath(flaeche, flaechenFarbe);

      final verlauf = Path()..moveTo(x(von), y(mittel(von)!));
      for (var i = von + 1; i <= bis; i++) {
        verlauf.lineTo(x(i), y(mittel(i)!));
      }
      canvas.drawPath(verlauf, linienFarbe);
    }

    // Stücke: maximale Folgen von Abschnitten mit Messung. Eine Lücke
    // beendet das Stück — nichts wird über sie hinweg verbunden.
    int? stueckBeginn;
    for (var i = 0; i < spannen.length; i++) {
      if (gemessen(i)) {
        stueckBeginn ??= i;
        continue;
      }
      if (stueckBeginn != null) zeichneStueck(stueckBeginn, i - 1);
      stueckBeginn = null;
    }
    if (stueckBeginn != null) zeichneStueck(stueckBeginn, spannen.length - 1);
  }

  @override
  bool shouldRepaint(_SpannenMaler alt) =>
      !identical(alt.spannen, spannen) && !_gleich(alt.spannen, spannen) ||
      !identical(alt.mittelwerte, mittelwerte) &&
          !_gleichMittel(alt.mittelwerte, mittelwerte) ||
      alt.farbe != farbe ||
      alt.trennerFarbe != trennerFarbe ||
      !_gleichZahlen(alt.trenner, trenner);

  static bool _gleich(List<ValueSpan> a, List<ValueSpan> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _gleichMittel(List<double?> a, List<double?> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _gleichZahlen(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
