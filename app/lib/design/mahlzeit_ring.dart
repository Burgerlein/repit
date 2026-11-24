// Der Ring um das Symbol einer Mahlzeit (#434 unter #374) — `mzRing` in
// `docs/screens/components.js`, gebaut nach Tims YAZIO-Bild (#385).
//
// Spec `docs/superpowers/specs/2026-11-10-mahlzeiten-aufteilung-design.md`,
// Abschnitt „Die Mahlzeitenliste". Geprüft von
// `test/ernaehrung/mahlzeiten_liste_test.dart`.
//
// **Heißt wie der Ring der Live-Aktivität im Kern** (`MahlzeitRing` in
// `trainings_core`, ein Werttyp). Wer beides braucht, blendet den Kern-Typ
// beim Import aus (`hide MahlzeitRing`).
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:trainings_core/trainings_core.dart' show anteilRunden;

import 'palette.dart';
import 'ringe.dart' show ringRundenFarbe;

/// Ein Mahlzeitsymbol in seinem Fortschrittsring.
///
/// - **Mit [anteil]** (gegessen durch Ziel der Mahlzeit, aus
///   `MahlzeitZeile.anteil`): die Runden aus `anteilRunden` im Kern, jede
///   weitere heller ([ringRundenFarbe], #386). Über 1 dreht er weiter und
///   wird **nie rot** (Entscheidung 4): Mittags mehr und abends weniger ist
///   eine andere Verteilung, kein Fehler.
/// - **Ohne [anteil]** (kein Ziel je Mahlzeit): V2 der Live-Spec, voll mit
///   Eintrag, nur die Spur ohne.
/// - **[laedt]:** nur die Spur, ohne Symbol.
///
/// **Mindestausschlag** (Tim, 10.11.2026): Hat die Mahlzeit einen Eintrag
/// und rundet der Anteil auf fast nichts (2 von 450 kcal ist `0`), zeigt
/// der Ring trotzdem ein kurzes Stück ([mindestausschlag]). Sonst sähe
/// „gegessen" aus wie „nichts eingetragen". Das ist Darstellung: Der
/// Anteil selbst bleibt, wie der Kern ihn rechnet.
class MahlzeitRing extends StatelessWidget {
  const MahlzeitRing({
    super.key,
    required this.symbol,
    required this.anteil,
    required this.eintrag,
    this.laedt = false,
    this.durchmesser = 46,
    this.strichstaerke = 4.5,
  });

  /// Das Symbol der Mahlzeit, `mahlzeitSymbol` (☕️ 🍜 🥗 🍎).
  final String symbol;

  /// Gegessen durch Ziel, `null` ohne Ziel. Ohne Eintrag `0`.
  final double? anteil;

  /// Ob die Mahlzeit mindestens einen Eintrag hat.
  final bool eintrag;

  final bool laedt;
  final double durchmesser;
  final double strichstaerke;

  /// Das kleinste Stück, das ein Ring mit Eintrag zeigt — als Anteil eines
  /// Umlaufs. Mit den runden Enden des Strichs reicht das für einen
  /// sichtbaren Ansatz, ohne einen Wert zu behaupten.
  static const mindestausschlag = 0.03;

  /// Die Runden, die dieser Ring zeichnet — je eine Zahl von 0 bis 1.
  List<double> get runden {
    if (laedt || !eintrag) return const [];
    final a = anteil;
    if (a == null) return const [1];
    final r = anteilRunden(a);
    if (r.isEmpty) return const [mindestausschlag];
    if (r.length == 1 && r.single < mindestausschlag) {
      return const [mindestausschlag];
    }
    return r;
  }

  @override
  Widget build(BuildContext context) {
    final basis = CupertinoDynamicColor.resolve(Palette.river, context);
    final spur = CupertinoDynamicColor.resolve(Palette.line, context);

    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: durchmesser,
        child: CustomPaint(
          painter: _MahlzeitRingPainter(
            runden: runden,
            basis: basis,
            spur: spur.withValues(alpha: 0.55),
            strichstaerke: strichstaerke,
          ),
          child: laedt
              ? null
              : Center(
                  child: Text(
                    symbol,
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(fontSize: durchmesser * 0.46),
                  ),
                ),
        ),
      ),
    );
  }
}

class _MahlzeitRingPainter extends CustomPainter {
  _MahlzeitRingPainter({
    required this.runden,
    required this.basis,
    required this.spur,
    required this.strichstaerke,
  });

  final List<double> runden;
  final Color basis;
  final Color spur;
  final double strichstaerke;

  /// Oben, wie bei den großen Ringen.
  static const _start = -math.pi / 2;

  @override
  void paint(Canvas canvas, Size size) {
    final mitte = size.center(Offset.zero);
    final radius = (size.shortestSide - strichstaerke) / 2;
    if (radius <= 0) return;

    // Die Spur ist ein Kreis, jede Runde ein Bogen.
    canvas.drawCircle(
      mitte,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strichstaerke
        ..color = spur,
    );

    final rect = Rect.fromCircle(center: mitte, radius: radius);
    final stift = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strichstaerke
      ..strokeCap = StrokeCap.round;
    for (var k = 0; k < runden.length; k++) {
      stift.color = ringRundenFarbe(basis, k);
      canvas.drawArc(rect, _start, 2 * math.pi * runden[k], false, stift);
    }
  }

  @override
  bool shouldRepaint(covariant _MahlzeitRingPainter alt) =>
      !listEquals(alt.runden, runden) ||
      alt.basis != basis ||
      alt.spur != spur ||
      alt.strichstaerke != strichstaerke;
}
