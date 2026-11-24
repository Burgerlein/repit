// Die Skala der Puls- und Atemspannen (#157, neu entworfen in #168) — die
// Rechnungen der Fläche und der Maler, der Kapseln, Marken, Messlücken,
// Lot und Zeitachse auf sie bringt.
//
// Eigene Datei neben `schlaf_spannen.dart`, nach demselben Schnitt wie
// `zeitdiagramm_zeichnung.dart` neben `zeitdiagramm.dart`: Der Maler und
// seine Rechnungen sind ohne Widget prüfbar, das Bauteil daneben trägt
// Zustand und Gesten. Zusammen in einer Datei waren es 664 Zeilen, und
// `CLAUDE.md` verlangt kleine Views.
//
// **Der Dateiname sagt „Achse", und eine Werteachse gibt es nicht mehr.**
// Was geblieben ist, ist die Skala dahinter — Grenzen, Kapselbreite, der
// Maler. Umbenannt wird sie nicht: Der Test daneben heißt genauso, und
// zwei Umbenennungen in einem Ticket, das von der Darstellung handelt,
// verdecken den eigentlichen Unterschied.
//
// **`schlaf_spannen.dart` exportiert diese Datei weiter.** Die festgelegte
// API bleibt `import '…/shell/schlaf_abschnitte.dart'`.
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:trainings_core/trainings_core.dart';

/// Die Höhe des Bildes und die Luft über und unter der Zeichenfläche.
///
/// **Seit #168 ist sie größer** (104 → 118): `MAX.` und sein Wert stehen
/// zweizeilig über der höchsten Kapsel, `MIN.` und seiner unter der
/// tiefsten. Die Zeichenfläche selbst ist mit 66 Punkt gleich geblieben;
/// gewachsen ist nur der Platz für die beiden Marken.
const double spannenBildhoehe = 118;
const double spannenLuftOben = 26;
const double spannenLuftUnten = 26;

/// Der Abstand der Zeitachse vom unteren Rand des Bildes.
///
/// Zwei Punkt, damit die punktierte Linie nicht auf der Kante liegt und
/// halb wegfällt.
const double spannenZeitachsenAbstand = 2;

// ───────────────────────────────────────────────────────────────────────
// Die Rechnungen der Fläche
// ───────────────────────────────────────────────────────────────────────

/// Die Grenzen der Zeichenfläche — **mit Rand**.
///
/// Ohne ihn klebte die höchste Kapsel am oberen Rand und sähe
/// abgeschnitten aus, und die beiden Kreise mit ihren Beschriftungen
/// hätten keinen Platz.
///
/// **Der Bezugswert ist am 29.10.2026 weggefallen** (#168). Bis dahin
/// konnte eine Bezugslinie außerhalb der Nacht die Achse mitziehen; seit
/// „genau so wie Apple" gibt es keine Bezugslinie mehr, und damit zieht
/// nichts mehr einseitig an der Skala — die Nacht steht mittig.
({double von, double bis}) spannenAchsenGrenzen({
  required double tiefster,
  required double hoechster,
}) {
  // `|| 1`: Eine Nacht ohne Schwankung bekommt trotzdem eine Höhe — sonst
  // würde beim Zeichnen durch null geteilt.
  final rand = (hoechster - tiefster == 0 ? 1 : hoechster - tiefster) * 0.14;
  return (von: tiefster - rand, bis: hoechster + rand);
}

/// Die Breite einer Kapsel — **ein Zehntel des Abschnitts**.
///
/// Gebaut war sie bis zum 28.10.2026 gut ein Fünftel breit (0,22). Apple
/// zeichnet deutlich schmaler, und Tim hat am 29.10.2026 „genau so"
/// verlangt (#168). Nie dünner als drei Punkt, sonst verschwindet sie; nie
/// breiter als fünf, sonst sieht sie wieder wie eine Säule aus und
/// behauptet eine Fläche statt einer Spanne.
double spannenKapselBreite(double abschnittsbreite) =>
    (abschnittsbreite * 0.10).clamp(3.0, 5.0);

/// Der Halbmesser der Marken `MIN.` und `MAX.` — **breiter als die
/// Kapsel**, auf der sie sitzen.
///
/// Säße die Marke genau auf der Kapselbreite, verschwände sie in ihr und
/// markierte nichts. Ein Punkt mehr als der Halbmesser der Kapsel reicht:
/// Der Kreis ragt dann sichtbar heraus, ohne den Balken zu verdecken.
double spannenMarkenRadius(double kapselbreite) => kapselbreite / 2 + 1.1;

/// Der gestrichelte Rahmen eines Abschnitts ohne Messung — **nur über den
/// Messwerten**, nicht über der ganzen Bildhöhe.
///
/// Mit Rasterlinien ging ein Rahmen von oben bis unten durch; seit sie weg
/// sind (#168), wäre er der stärkste Strich im Bild — und er behauptete
/// eine Höhe, über die niemand etwas weiß. [oben] und [unten] sind die
/// y-Werte des höchsten und des tiefsten gemessenen Werts der Nacht.
Rect spannenLueckenRahmen({
  required int index,
  required double abschnittsbreite,
  required double oben,
  required double unten,
}) => Rect.fromLTRB(
  index * abschnittsbreite + 4,
  oben,
  (index + 1) * abschnittsbreite - 4,
  unten,
);

/// Ganzzahlig oder mit Nachkommastellen — und dann mit **Komma**, nicht mit
/// Punkt. Dieselbe Schreibweise wie `kommazahl` im Erholung-Schirm.
String spannenZahl(double wert, int nachkommastellen) => nachkommastellen == 0
    ? wert.round().toString()
    : wert.toStringAsFixed(nachkommastellen).replaceAll('.', ',');

/// Der Abschnitt mit dem höchsten und der mit dem tiefsten Messwert.
///
/// **Bei gleichem Wert gewinnt der frühere Abschnitt** (`<` statt `<=`):
/// Einer muss es sein, und der frühere ist der, den man zuerst liest. Ein
/// Abschnitt ohne Messung kann keinen tragen.
///
/// `null` heißt „keine einzige Messung" — dann gibt es nichts zu
/// markieren.
({int tiefster, int hoechster})? spannenSpitzen(List<ValueSpan> spannen) {
  int? tief, hoch;
  double? tiefWert, hochWert;
  for (var i = 0; i < spannen.length; i++) {
    final min = spannen[i].min, max = spannen[i].max;
    if (min == null || max == null) continue;
    if (tiefWert == null || min < tiefWert) {
      tiefWert = min;
      tief = i;
    }
    if (hochWert == null || max > hochWert) {
      hochWert = max;
      hoch = i;
    }
  }
  return tief == null || hoch == null
      ? null
      : (tiefster: tief, hoechster: hoch);
}

// ───────────────────────────────────────────────────────────────────────
// Der Maler
// ───────────────────────────────────────────────────────────────────────

/// Kapseln, Marken, Messlücken, Lot und Zeitachse.
///
/// **Was er seit #168 nicht mehr malt:** Rasterlinien und die gestrichelte
/// Bezugslinie. Beides war Tims Entscheidung vom 28.10.2026 und ist am
/// 29.10. von „Bau das so wie Apple bitte genau so!" aufgehoben worden —
/// eine Umkehr, keine vergessene Zeile.
class SpannenPainter extends CustomPainter {
  SpannenPainter({
    required this.spannen,
    required this.farbe,
    required this.flaechenFarbe,
    required this.achsenFarbe,
    required this.lotFarbe,
    required this.muedeFarbe,
    required this.von,
    required this.bis,
    required this.auswahl,
  });

  final List<ValueSpan> spannen;
  final Color farbe;

  /// Die Füllung des **offenen** oberen Kreises — die Farbe der Karte.
  final Color flaechenFarbe;

  /// Die punktierte Zeitachse und ihre feinen Striche.
  final Color achsenFarbe;
  final Color lotFarbe;

  /// Die Farbe der Messlücken-Rahmen.
  final Color muedeFarbe;
  final double von;
  final double bis;
  final int? auswahl;

  @override
  void paint(Canvas canvas, Size size) {
    if (spannen.isEmpty || size.width <= 0) return;
    final hoehe = size.height - spannenLuftOben - spannenLuftUnten;
    final breite = size.width / spannen.length;
    final kapsel = spannenKapselBreite(breite);

    double y(double wert) =>
        spannenLuftOben + (1 - (wert - von) / (bis - von)) * hoehe;
    double mitte(int i) => (i + 0.5) * breite;

    final spitzen = spannenSpitzen(spannen);

    // ---- Die Messlücken -------------------------------------------------
    // **Ein Rahmen, keine Füllung** (#156): Eine graue Fläche sähe aus wie
    // ein Messwert, den es nicht gibt. Seit #168 reicht er nur über die
    // Messwerte — siehe `spannenLueckenRahmen`.
    final lueckenStift = Paint()
      ..color = muedeFarbe.withValues(alpha: 0.55)
      ..strokeWidth = 0.8;
    final oben = spitzen == null ? 0.0 : y(spannen[spitzen.hoechster].max!);
    final unten = spitzen == null ? 0.0 : y(spannen[spitzen.tiefster].min!);
    for (var i = 0; i < spannen.length; i++) {
      if (spannen[i].min != null && spannen[i].max != null) continue;
      if (spitzen == null) continue;
      final rahmen = spannenLueckenRahmen(
        index: i,
        abschnittsbreite: breite,
        oben: oben,
        unten: unten,
      );
      for (final kante in [
        (rahmen.topLeft, rahmen.topRight),
        (rahmen.bottomLeft, rahmen.bottomRight),
        (rahmen.topLeft, rahmen.bottomLeft),
        (rahmen.topRight, rahmen.bottomRight),
      ]) {
        _gestrichelt(
          canvas,
          kante.$1,
          kante.$2,
          lueckenStift,
          strich: 2,
          luecke: 3,
        );
      }
    }

    // Das Lot liegt **unter** den Kapseln: Eine blaue Strichellinie quer
    // durch eine rote Kapsel sähe aus, als gehörte sie dazu.
    final gewaehlt = auswahl;
    if (gewaehlt != null) {
      _gestrichelt(
        canvas,
        Offset(mitte(gewaehlt), spannenLuftOben),
        Offset(mitte(gewaehlt), spannenLuftOben + hoehe),
        Paint()
          ..color = lotFarbe.withValues(alpha: 0.85)
          ..strokeWidth = 1,
        strich: 3,
        luecke: 3,
      );
    }

    // ---- Die Kapseln ----------------------------------------------------
    for (var i = 0; i < spannen.length; i++) {
      // Der leere Abschnitt bleibt im Raster, bekommt aber keine Kapsel.
      final tief = spannen[i].min;
      final hoch = spannen[i].max;
      if (tief == null || hoch == null) continue;

      final kopf = y(hoch);
      final fuss = y(tief);
      final rechteck = Rect.fromLTRB(
        mitte(i) - kapsel / 2,
        kopf,
        mitte(i) + kapsel / 2,
        // Eine Spanne ohne Höhe bliebe unsichtbar — zwei Punkt sind das
        // Mindeste, damit „gemessen, aber konstant" etwas anderes aussieht
        // als „nicht gemessen".
        fuss - kopf < 2 ? kopf + 2 : fuss,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rechteck, Radius.circular(kapsel / 2)),
        Paint()..color = farbe.withValues(alpha: i == gewaehlt ? 1 : 0.75),
      );
    }

    // ---- Die beiden Kreise ----------------------------------------------
    // **Oben offen, unten gefüllt** — so steht es in Tims Bildschirmfotos
    // aus Apple Health, bei Atemfrequenz wie bei Herzfrequenz. Der obere
    // Kreis sitzt am oberen Ende der höchsten Kapsel, die von unten in ihn
    // hineinläuft; offen setzt er sich dagegen ab. Der untere hat nichts,
    // wogegen er sich absetzen müsste.
    //
    // **Abgelesen aus einem Bildschirmfoto, nicht aus einer Spezifikation**
    // — die Marken sind darin sehr klein. Wer es auf dem Gerät anders
    // sieht, hat recht und nicht dieser Kommentar.
    if (spitzen != null) {
      final radius = spannenMarkenRadius(kapsel);
      canvas.drawCircle(
        Offset(mitte(spitzen.hoechster), oben),
        radius,
        Paint()..color = flaechenFarbe,
      );
      canvas.drawCircle(
        Offset(mitte(spitzen.hoechster), oben),
        radius,
        Paint()
          ..color = farbe
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3,
      );
      canvas.drawCircle(
        Offset(mitte(spitzen.tiefster), unten),
        radius,
        Paint()..color = farbe,
      );
    }

    // ---- Die Zeitachse ---------------------------------------------------
    // Punktiert, mit einem feinen Strich an jeder Abschnittsgrenze. Die
    // Striche tragen, was die weggefallenen Beschriftungen getragen haben:
    // dass hier acht Abschnitte stehen und nicht durchgemessen wurde.
    final achse = size.height - spannenZeitachsenAbstand;
    final achsenStift = Paint()
      ..color = achsenFarbe
      ..strokeWidth = 0.8
      ..strokeCap = StrokeCap.round;
    _gestrichelt(
      canvas,
      Offset(0, achse),
      Offset(size.width, achse),
      achsenStift,
      strich: 0.5,
      luecke: 2.5,
    );
    for (var i = 0; i <= spannen.length; i++) {
      final x = (i * breite).clamp(0.0, size.width);
      canvas.drawLine(
        Offset(x, achse - 3),
        Offset(x, achse),
        Paint()
          ..color = achsenFarbe
          ..strokeWidth = 0.8,
      );
    }
  }

  /// Flutter kennt kein `dash` am `Paint` — also Stück für Stück.
  void _gestrichelt(
    Canvas canvas,
    Offset anfang,
    Offset ende,
    Paint stift, {
    required double strich,
    required double luecke,
  }) {
    final gesamt = (ende - anfang).distance;
    if (gesamt <= 0) return;
    final richtung = (ende - anfang) / gesamt;
    var gelaufen = 0.0;
    while (gelaufen < gesamt) {
      final stueck = math.min(gelaufen + strich, gesamt);
      canvas.drawLine(
        anfang + richtung * gelaufen,
        anfang + richtung * stueck,
        stift,
      );
      gelaufen = stueck + luecke;
    }
  }

  @override
  bool shouldRepaint(SpannenPainter alt) =>
      alt.spannen != spannen ||
      alt.farbe != farbe ||
      alt.flaechenFarbe != flaechenFarbe ||
      alt.achsenFarbe != achsenFarbe ||
      alt.lotFarbe != lotFarbe ||
      alt.muedeFarbe != muedeFarbe ||
      alt.von != von ||
      alt.bis != bis ||
      alt.auswahl != auswahl;
}
