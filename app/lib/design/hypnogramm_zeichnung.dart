/// Das Zeichnen des Hypnogramms — die zweite von drei Dateien neben
/// `hypnogramm_lage.dart` (Rechnung) und `hypnogramm.dart` (Zustand,
/// Kopfzeile, Geste).
///
/// Hier liegt kein Zustand und keine Geste, nur Striche — derselbe Schnitt
/// wie bei `zeitdiagramm_zeichnung.dart`.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

import '../health/health_types.dart';
import 'hypnogramm_lage.dart';

/// Der Eckenradius der Spuren und Blöcke — `ECKE` in
/// `docs/screens/components.js`.
///
/// **Fest, nicht die halbe Balkenhöhe.** Am 27.10.2026 hatte Tim das
/// Gegenteil entschieden: rundum abgerundete Blöcke, also `rx` gleich der
/// halben Balkenhöhe. Bestätigt wurde das gegen eine geschönte Nacht mit
/// 17 Abschnitten, deren kürzester acht Minuten dauerte. Eine echte Nacht
/// hat rund 25 Abschnitte, darunter mehrere Wachphasen von **einer**
/// Minute — und bei `rx = Balkenhöhe / 2` wird jeder Abschnitt, der
/// schmaler ist als hoch, zur Kapsel. Tim am Gerät am 28.10.2026: „sieht
/// echt kacke aus." Die Blöcke bleiben abgerundet, nur eben nicht
/// pillenförmig; die Umkehr gehört Tim, nicht diesem Bauteil (#141).
const double hypnogrammEcke = 2;

/// Zeichnet die vier Spuren, die Blöcke, die Uhrzeitachse, den Rahmen einer
/// Messlücke und das Lot beim Ablesen.
///
/// **Öffentlich und mit bereits aufgelösten Farben**: Eine unaufgelöste
/// `CupertinoDynamicColor` bliebe im Dunkelmodus auf ihrer hellen Variante
/// stehen, und das ist ohne Pixelvergleich nur zu prüfen, wenn die Farben
/// von außen hineingehen.
///
/// **Keine Verbindungslinie zwischen den Blöcken** (Tim, 28.10.2026). Der
/// Entwurf kennt dafür eine Option (`verbinder`, wahlweise als
/// durchgehende Treppenlinie); gerufen wird sie nicht. Bei 17 Abschnitten
/// ordnete sie, bei 25 ist sie ein Gitter.
class HypnogrammPainter extends CustomPainter {
  HypnogrammPainter({
    required this.abschnitte,
    required this.farben,
    required this.fensterFarbe,
    required this.kompakt,
    this.achse = const [],
    this.auswahl,
    this.rasterFarbe,
    this.lueckenFarbe,
    this.lotFarbe,
  });

  final List<SleepSegment> abschnitte;

  /// Aufgelöst, je Phase eine Farbe.
  final Map<SleepStage, Color> farben;

  /// Aufgelöst — die Säule, auf der die Phasen liegen.
  final Color fensterFarbe;

  final bool kompakt;

  /// Die vollen Stunden als Anteile des Fensters, 0 bis 1 — die
  /// Rasterlinien der Uhrzeitachse. Leer heißt: keine Achse.
  final List<double> achse;

  /// Der abgelesene Eintrag, als Platz in `HypnogrammGeometrie.eintraege`.
  /// `null` heißt: nichts gewählt, alle Blöcke voll gedeckt.
  final int? auswahl;

  /// Die drei Farben der Zutaten. **`null` heißt: diese Zutat wird nicht
  /// gezeichnet** — der kompakten Fassung fehlen Achse und Lot, und ein
  /// bloß aufgestellter Maler braucht keine davon.
  final Color? rasterFarbe;
  final Color? lueckenFarbe;
  final Color? lotFarbe;

  /// Wie blass ein Block wird, während ein anderer abgelesen wird —
  /// `opacity=".28"` im Entwurf.
  static const double _blass = 0.28;

  @override
  void paint(Canvas canvas, Size size) {
    final geometrie = HypnogrammGeometrie(SleepSession(segments: abschnitte));
    if (geometrie.leer || size.width <= 0) return;

    final spuren = SchlafPhasen.reihenfolge.length;
    final spurhoehe = size.height / spuren;
    final balkenhoehe = kompakt ? 13.0 : 21.0;

    // Die Unterkante der untersten Spur. Achse, Lückenrahmen und Lot enden
    // dort und nicht am unteren Rand der Fläche — sonst stünden sie unter
    // dem Bild in der Luft.
    final unterkante = spurhoehe * (spuren - 1) + balkenhoehe;
    const radius = Radius.circular(hypnogrammEcke);

    double oben(SleepStage phase) => SchlafPhasen.spurIndex(phase) * spurhoehe;
    double x(DateTime zeitpunkt) => size.width * geometrie.anteil(zeitpunkt);

    // ── Die Spuren, je Messlücke unterbrochen ────────────────────────────
    //
    // Erst je Spur der graue Grund, dann die Blöcke darauf — `hypnogram()`
    // in `docs/screens/components.js`. Der Grund macht sichtbar, wie viel
    // einer Stufe **fehlt**: Ohne ihn stünde ein kurzer Tiefschlafblock
    // allein im Leeren und sähe aus wie ein voller Balken.
    final grund = Paint()..color = fensterFarbe;
    for (final phase in SchlafPhasen.reihenfolge) {
      for (final strecke in geometrie.gemesseneStrecken) {
        final links = x(strecke.von);
        final breite = x(strecke.bis) - links;
        if (breite <= 0) continue;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(links, oben(phase), breite, balkenhoehe),
            radius,
          ),
          grund,
        );
      }
    }

    // ── Die Uhrzeitachse ─────────────────────────────────────────────────
    //
    // Ohne sie ist das Bild eine Form ohne Bezug — Tims zweiter Punkt in
    // #141. Die Beschriftung trägt die Widget-Fassung als Text, damit sie
    // über `Format` läuft und im Test lesbar bleibt.
    final raster = rasterFarbe;
    if (raster != null) {
      final stift = Paint()
        ..color = raster
        ..strokeWidth = 0.5;
      for (final anteil in achse) {
        final xx = size.width * anteil;
        canvas.drawLine(Offset(xx, 0), Offset(xx, unterkante), stift);
      }
    }

    // ── Die Blöcke ───────────────────────────────────────────────────────
    final eintraege = geometrie.eintraege;
    for (var i = 0; i < eintraege.length; i++) {
      final eintrag = eintraege[i];
      final phase = eintrag.phase;
      if (phase == null) continue; // Eine Messlücke trägt keinen Block.
      final (:links, :breite) = geometrie.lage(eintrag, size.width);
      final farbe = farben[phase] ?? fensterFarbe;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(links, oben(phase), breite, balkenhoehe),
          radius,
        ),
        Paint()
          ..color = auswahl == null || auswahl == i
              ? farbe
              : farbe.withValues(alpha: farbe.a * _blass),
      );
    }

    // ── Der Rahmen einer Messlücke ───────────────────────────────────────
    //
    // Ein Rahmen, keine Füllung: Eine graue Fläche sähe aus wie eine Phase,
    // die es nicht gibt (#156).
    final lueckeFarbe = lueckenFarbe;
    if (lueckeFarbe != null) {
      final stift = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = lueckeFarbe.withValues(alpha: lueckeFarbe.a * 0.55);
      for (final eintrag in eintraege) {
        if (!eintrag.istLuecke) continue;
        final (:links, :breite) = geometrie.lage(eintrag, size.width);
        _gestrichelt(
          canvas,
          Path()..addRect(Rect.fromLTWH(links, 0, breite, unterkante)),
          stift,
          strich: 2,
          luecke: 3,
        );
      }
    }

    // ── Das Lot beim Ablesen ─────────────────────────────────────────────
    final lot = lotFarbe;
    final gewaehlt = auswahl;
    if (lot != null && gewaehlt != null && gewaehlt < eintraege.length) {
      // An der **linken** Kante des Abschnitts, wie im Entwurf.
      final links = geometrie.lage(eintraege[gewaehlt], size.width).links;
      _gestrichelt(
        canvas,
        Path()
          ..moveTo(links, 0)
          ..lineTo(links, unterkante),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = lot.withValues(alpha: lot.a * 0.85),
        strich: 3,
        luecke: 3,
      );
    }
  }

  /// Zeichnet [pfad] gestrichelt. Flutter kennt kein `stroke-dasharray`;
  /// der Pfad wird deshalb abgeschritten und stückweise gezeichnet.
  static void _gestrichelt(
    Canvas canvas,
    Path pfad,
    Paint stift, {
    required double strich,
    required double luecke,
  }) {
    for (final mass in pfad.computeMetrics()) {
      var gelaufen = 0.0;
      while (gelaufen < mass.length) {
        final bis = gelaufen + strich < mass.length
            ? gelaufen + strich
            : mass.length;
        canvas.drawPath(mass.extractPath(gelaufen, bis), stift);
        gelaufen = bis + luecke;
      }
    }
  }

  @override
  bool shouldRepaint(covariant HypnogrammPainter oldDelegate) {
    return oldDelegate.abschnitte != abschnitte ||
        oldDelegate.fensterFarbe != fensterFarbe ||
        oldDelegate.kompakt != kompakt ||
        oldDelegate.auswahl != auswahl ||
        oldDelegate.rasterFarbe != rasterFarbe ||
        oldDelegate.lueckenFarbe != lueckenFarbe ||
        oldDelegate.lotFarbe != lotFarbe ||
        !listEquals(oldDelegate.achse, achse) ||
        !mapEquals(oldDelegate.farben, farben);
  }
}
