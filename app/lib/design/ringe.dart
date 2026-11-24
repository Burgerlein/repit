import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:trainings_core/trainings_core.dart'
    show anteilRunden, rundenHoechstens;

import 'palette.dart';
import 'platzhalter.dart';
import 'typografie.dart';

/// Ein Ring: wie weit ein Tagesziel erfüllt ist — Dart-Entsprechung von
/// `RingGoal` in `Sources/DesignSystem/ActivityRings.swift` und der
/// Entwurfsfunktion `rings`/`ringLegend` in `docs/screens/components.js`.
///
/// **Übererfüllung dreht weitere Runden** (#386, Tim am 05.11.2026: wie
/// die Apple-Aktivitätsringe). Die Swift-Quelle deckelt bei 100 %
/// (`fraction` bleibt bei 1 stehen); hier bleibt die erste Runde voll, und
/// was über das Ziel geht, läuft ab 12 Uhr noch einmal herum — in
/// derselben Farbe, etwas heller ([ringRundenFarbe]), und die Spitze der
/// obersten Runde wirft einen weichen Schatten auf die Runde darunter
/// ([ringSpitze]). So liest man „Ziel erreicht" **und** „zählt weiter".
/// Die Rechnung steht in [ringRunden]; [ersteRunde] und [zweiteRunde]
/// sind Ausschnitte davon.
///
/// **Höchstens drei Runden** ([ringRundenHoechstens]), danach gedeckelt —
/// von Tim am 10.11.2026 in Entscheidung 4 der Aufteilungs-Spec
/// (`2026-11-10-mahlzeiten-aufteilung-design.md`) freigegeben.
///
/// `text` ist ein vom Schirm durchgereichter String, keine von hier
/// berechnete Darstellung — er nennt den **Rest**, nicht den Stand
/// (erfundenes Beispiel: „noch 180 kcal" statt „1.620 / 1.800"), über dem
/// Ziel, wie weit darüber. Die Runden ändern daran nichts.
class RingZiel {
  const RingZiel({
    required this.label,
    required this.wert,
    required this.ziel,
    required this.text,
    required this.farbe,
    this.platzhalter,
  });

  final String label;

  /// `null` heißt „gelesen, kein Wert" — und **nicht** `0`. Ein Ring auf 0
  /// behauptet „heute nichts getan", obwohl in Wahrheit nur nichts gelesen
  /// wurde; das ist Fehler `01` aus `CLAUDE.md` in neuer Verpackung
  /// (Spec `2026-10-28-leerzustaende-design.md`). Ohne Wert zeichnet
  /// [Ringe] allein die Spur, und der Ring bleibt stehen, statt zu
  /// verschwinden.
  final double? wert;
  final double ziel;

  /// Z. B. „noch 180 kcal" (erfundenes Beispiel) — der Rest, nicht der
  /// Stand.
  final String text;

  /// Darf eine `CupertinoDynamicColor` sein — [Ringe] und [RingLegende]
  /// lösen sie selbst gegen ihren `BuildContext` auf (#387). Ein `Paint`
  /// oder eine `BoxDecoration` nähme sonst stumm den hellen Standardwert,
  /// und im Dunkelmodus stünden die Ringe in den Farben des Hellmodus.
  final Color farbe;

  /// Ein Beispieltext in der Schrift der Beschriftung. Ist er gesetzt und
  /// fehlt [wert], zeichnet [RingLegende] eine graue Fläche seiner Breite
  /// statt [text] — der Ladeplatzhalter aus #24. Er gehört ausschließlich
  /// in den Zustand `NochNie`: Beim Nachladen bleibt der alte Wert stehen.
  final String? platzhalter;

  /// Ob der Ring gerade auf seinen ersten Wert wartet.
  bool get _laedt => wert == null && platzhalter != null;

  /// Die Runden dieses Rings, siehe [ringRunden].
  List<double> get runden => ringRunden(wert, ziel);

  /// Die erste Runde: 0 bis 1, nie mehr — wer über das Ziel hinausgeht,
  /// füllt stattdessen [zweiteRunde].
  double get ersteRunde {
    final r = runden;
    return r.isEmpty ? 0 : r[0];
  }

  /// Die zweite Runde für 100–200 %. Genau bei 100 % noch 0 — erst das
  /// Überschreiten füllt sie, nicht das Erreichen.
  double get zweiteRunde {
    final r = runden;
    return r.length < 2 ? 0 : r[1];
  }
}

/// Wie viele Runden ein Ring höchstens dreht — der Wert des Kerns,
/// `rundenHoechstens` in `trainings_core` (V7 der Aufteilungs-Spec). Bei
/// 300 % ist Schluss; darüber steht, wie weit es ist, in der Beschriftung,
/// nicht im Ring.
const ringRundenHoechstens = rundenHoechstens;

/// Die Runden eines Rings für [wert] gegen [ziel] — je Runde ein Anteil von
/// 0 bis 1, von der ersten an. Alle bis auf die letzte sind voll; die
/// letzte trägt den Überhang. Erfundene Beispiele: 50 % → `[0.5]`, 100 % →
/// `[1]`, 130 % → `[1, 0.3]`, 250 % → `[1, 1, 0.5]`, alles ab 300 % →
/// `[1, 1, 1]`.
///
/// Ohne Wert, ohne Ziel oder bei nichts Erreichtem ist die Liste leer:
/// Dann zeichnet [Ringe] allein die Spur.
///
/// Hier wird nur umgerechnet; die Runden selbst rechnet `anteilRunden` im
/// Kern (V7 der Aufteilungs-Spec), dieselbe Rechnung wie für die
/// Mahlzeitenringe.
List<double> ringRunden(double? wert, double ziel) {
  if (wert == null || ziel <= 0 || !(wert > 0)) return const [];
  return anteilRunden(wert / ziel);
}

/// Wo die Spitze der obersten Runde sitzt, als Anteil eines Umlaufs ab 12
/// Uhr — dort wirft sie ihren Schatten auf die Runde darunter. `null`,
/// solange nichts über der ersten Runde liegt: bis einschließlich 100 %.
double? ringSpitze(List<double> runden) =>
    runden.length > 1 ? runden.last : null;

/// Die Farbe der Runde [runde] (ab 0): Die erste trägt [basis] unverändert,
/// jede weitere ist ein Stück heller, im selben Farbton und voll deckend —
/// so hebt sich die neue Runde von der vollen darunter ab, ohne dass die
/// untere durchscheint. Zum Weiß hin gemischt, weil das den Farbton
/// erhält; ein Aufhellen über HSL-Helligkeit verschöbe ihn beim Runden.
Color ringRundenFarbe(Color basis, int runde) {
  if (runde <= 0) return basis;
  final anteil = runde == 1 ? 0.28 : 0.5;
  return Color.lerp(
    basis,
    const Color(0xFFFFFFFF),
    anteil,
  )!.withValues(alpha: 1);
}

/// Die ineinanderliegenden Ringe — Dart-Entsprechung von `ActivityRings` in
/// `Sources/DesignSystem/ActivityRings.swift` und `rings(goals, size, w)`
/// in `docs/screens/components.js`.
///
/// `durchmesser`/`strichstaerke` nehmen von außen abweichende Werte entgegen
/// (Vorbild: `rings(goals, 122, 13)` im Entwurf, verkleinert im Live-Banner
/// auf `rings(goals, 44, 5)`), damit derselbe Baustein beide Fälle zeichnet,
/// statt zwei Code-Pfade zu brauchen.
class Ringe extends StatelessWidget {
  const Ringe(
    this.ziele, {
    super.key,
    this.durchmesser = 122,
    this.strichstaerke = 13,
  });

  final List<RingZiel> ziele;
  final double durchmesser;
  final double strichstaerke;

  @override
  Widget build(BuildContext context) {
    final spur = CupertinoDynamicColor.resolve(Palette.line, context);

    return Semantics(
      label: ziele.map(_vorlesetext).join(', '),
      child: CustomPaint(
        size: Size.square(durchmesser),
        painter: _RingePainter(
          ziele: ziele,
          farben: _aufgeloest(ziele, context),
          strichstaerke: strichstaerke,
          spur: spur.withValues(alpha: 0.55),
        ),
      ),
    );
  }
}

/// Der Vorlesetext eines Rings — er nennt den **Zustand**, nicht das
/// Zeichen. Mit `–/–` im Resttext läse VoiceOver „Training Strich
/// Schrägstrich Strich" vor; das ist schlechter als das frühere Weglassen
/// und ein ausdrückliches Anti-Ziel der Spec. Und während des Laufs gibt
/// es gar keine Aussage zu treffen — dann heißt es „wird geladen" statt
/// „keine Werte" (CLAUDE.md: während des Ladens steht nie ein
/// „keine Daten"-Grund).
String _vorlesetext(RingZiel ziel) {
  if (ziel._laedt) return '${ziel.label}, wird geladen';
  if (ziel.wert == null) return '${ziel.label}, keine Werte';
  return '${ziel.label} ${ziel.text}';
}

/// Die Farben der [ziele], aufgelöst gegen [context] (#387). An dieser
/// einen Stelle, damit keine Aufrufstelle es vergessen kann: Der
/// Ernährungs-Tab reichte `Palette.iron` & Co. unaufgelöst durch und
/// malte im Dunkelmodus hell, Home löste selbst auf. Eine schon
/// aufgelöste Farbe kommt unverändert zurück.
List<Color> _aufgeloest(List<RingZiel> ziele, BuildContext context) => [
  for (final ziel in ziele) CupertinoDynamicColor.resolve(ziel.farbe, context),
];

class _RingePainter extends CustomPainter {
  _RingePainter({
    required this.ziele,
    required this.farben,
    required this.strichstaerke,
    required this.spur,
  });

  final List<RingZiel> ziele;

  /// Je Ziel die aufgelöste Farbe, in derselben Reihenfolge — gemalt wird
  /// nur mit diesen, nie mit [RingZiel.farbe] selbst.
  final List<Color> farben;
  final double strichstaerke;
  final Color spur;

  /// Oben, wie in der Swift-Vorlage (`rotationEffect(.degrees(-90))`).
  static const _start = -math.pi / 2;

  /// Der Schatten unter der Spitze — einmal je Painter angelegt, nicht je
  /// Bild. Die Unschärfe wächst mit der Strichstärke, damit die kleine
  /// Fassung im Live-Banner (5 pt) nicht verschmiert.
  late final Paint _schattenStift = Paint()
    ..color = const Color(0x73000000)
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, strichstaerke * 0.22);

  /// Der Radius, den der innerste Ring mindestens behält — gemessen an
  /// seiner Mittellinie, die Strichstärke liegt je zur Hälfte darüber und
  /// darunter. Bei `strichstaerke` 13 bleibt damit innen ein Loch von
  /// rund 29 Punkt; weniger, und der Ring liest sich als Scheibe.
  static const _innersterRadius = 21.0;

  @override
  void paint(Canvas canvas, Size size) {
    final gap = strichstaerke * 0.16;

    final spurStift = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strichstaerke
      ..color = spur;
    final wertStift = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strichstaerke
      ..strokeCap = StrokeCap.round;

    // Abstand zwischen den Ringen: `i * (w + gap + w * 0.84)` aus
    // `rings()` in `docs/screens/components.js` — **nicht** die engere
    // Formel aus `ActivityRings.swift` (`index * (lineWidth + gap)`, ohne
    // den Zuschlag `w * 0.84`). Nach CLAUDE.md ist der Entwurf verbindlich,
    // die Swift-App nur Vergleichsmaßstab: Ohne den Zuschlag lägen die
    // Ringe spürbar enger beieinander als im Entwurfsboard.
    //
    // **Gedeckelt, damit der innerste Ring ein Ring bleibt** (#166, Tim am
    // 04.11.2026: „der innere Ring ist ein Punkt, das soll ein richtiger
    // Ring sein"). Mit drei Zielen, `durchmesser` 122 und `strichstaerke`
    // 13 ergibt die ungedeckelte Formel für den dritten einen Radius von
    // 2,5 — eine gefüllte Scheibe, kein Ring. Der Deckel verteilt die
    // Ringe stattdessen gleichmäßig zwischen dem äußeren Radius und
    // `_innersterRadius`.
    //
    // **Bei zwei Ringen ändert sich nichts**: Dort ist der ungedeckelte
    // Schritt der kleinere, und `min` lässt ihn stehen. Heute, Erholung
    // und Körper sehen aus wie vorher.
    final aussen = (size.shortestSide - strichstaerke) / 2;
    final weit = strichstaerke + gap + strichstaerke * 0.84;
    final schritt = ziele.length > 1
        ? math.min(weit, (aussen - _innersterRadius) / (ziele.length - 1))
        : weit;

    for (var i = 0; i < ziele.length; i++) {
      final ziel = ziele[i];
      final farbe = farben[i];
      final inset = strichstaerke / 2 + i * schritt;
      final rect = Rect.fromLTWH(
        inset,
        inset,
        size.width - inset * 2,
        size.height - inset * 2,
      );
      if (rect.width <= 0 || rect.height <= 0) continue;

      canvas.drawArc(rect, 0, 2 * math.pi, false, spurStift);

      // Die Runden liegen übereinander, jede ab 12 Uhr, jede etwas heller
      // als die darunter (#386). Gerechnet wird hier, im Painter, und nur
      // aus Wert und Ziel — keine Rechnung je Bild außerhalb davon.
      final runden = ziel.runden;
      for (var k = 0; k < runden.length; k++) {
        wertStift.color = ringRundenFarbe(farbe, k);
        canvas.drawArc(rect, _start, 2 * math.pi * runden[k], false, wertStift);
      }

      final spitze = ringSpitze(runden);
      if (spitze != null) {
        _zeichneSpitze(
          canvas,
          rect,
          spitze,
          ringRundenFarbe(farbe, runden.length - 1),
          wertStift,
        );
      }
    }
  }

  /// Die abgehobene Spitze der obersten Runde: ein weicher Schatten knapp
  /// vor ihr, auf die Runde darunter und nur innerhalb des eigenen Bands, und darüber das letzte Stück der
  /// Runde noch einmal, damit der Schatten nicht auf ihr selbst liegt.
  /// Dasselbe Verfahren wie `rings()` in `docs/screens/components.js`.
  void _zeichneSpitze(
    Canvas canvas,
    Rect rect,
    double spitze,
    Color farbe,
    Paint wertStift,
  ) {
    final radius = rect.width / 2;
    final winkel = _start + 2 * math.pi * spitze;
    final richtung = Offset(-math.sin(winkel), math.cos(winkel));
    final mitte =
        rect.center +
        Offset(math.cos(winkel), math.sin(winkel)) * radius +
        richtung * (strichstaerke * 0.3);
    // Der Schatten fällt nur auf das eigene Band, nicht auf den
    // Nachbarring daneben.
    final band = Path()
      ..fillType = PathFillType.evenOdd
      ..addOval(rect.inflate(strichstaerke / 2))
      ..addOval(rect.deflate(strichstaerke / 2));
    canvas
      ..save()
      ..clipPath(band)
      ..drawCircle(mitte, strichstaerke / 2, _schattenStift)
      ..restore();

    final stueck = math.min(strichstaerke / radius, 2 * math.pi * spitze);
    wertStift.color = farbe;
    canvas.drawArc(rect, winkel - stueck, stueck, false, wertStift);
  }

  @override
  bool shouldRepaint(covariant _RingePainter oldDelegate) {
    return oldDelegate.ziele != ziele ||
        !listEquals(oldDelegate.farben, farben) ||
        oldDelegate.strichstaerke != strichstaerke ||
        oldDelegate.spur != spur;
  }
}

/// Die Beschriftung neben den großen Ringen — Dart-Entsprechung von
/// `RingLegend` in `Sources/DesignSystem/ActivityRings.swift` und
/// `ringLegend(goals)` in `docs/screens/components.js`.
class RingLegende extends StatelessWidget {
  const RingLegende(this.ziele, {super.key});

  final List<RingZiel> ziele;

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final farben = _aufgeloest(ziele, context);

    return Semantics(
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (i, ziel) in ziele.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: farben[i],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ziel.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: muted),
                    ),
                  ),
                  // `Flexible` + `scaleDown`: Der Resttext ist der längste
                  // Teil der Zeile und lief auf Gerätebreite über den Rand
                  // (gelb-schwarzer Balken). Passt er, wird nichts
                  // skaliert; passt er nicht, schrumpft er, statt
                  // abgeschnitten zu werden — eine halbe Zahl wäre eine
                  // falsche Auskunft.
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: _Restwert(ziel: ziel),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Der Resttext rechts in der Legende — oder, solange noch kein Wert
/// gelesen wurde, eine graue Fläche in der Breite des Beispieltexts.
class _Restwert extends StatelessWidget {
  const _Restwert({required this.ziel});

  final RingZiel ziel;

  @override
  Widget build(BuildContext context) {
    final stil = Typografie.tabularNumbers(
      Typografie.numeric(TypografieGroesse.title3),
    );
    final beispiel = ziel.platzhalter;
    if (ziel._laedt && beispiel != null) {
      return Platzhalter(beispiel: beispiel, stil: stil);
    }
    return Text(ziel.text, style: stil);
  }
}
