import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

import 'palette.dart';
import 'typografie.dart';

/// Ein Abschnitt des Kreises — Dart-Entsprechung von `RingSegment` in
/// `Sources/Features/Recovery/RecoveryRings.swift`.
///
/// [farbe] bleibt **unaufgelöst** (ein Eintrag aus [Palette]); aufgelöst
/// wird erst beim Zeichnen, wo der `BuildContext` bekannt ist. So lässt
/// sich ein Abschnitt als `const` anlegen und trotzdem im Dunkelmodus
/// richtig einfärben.
///
/// [hatGrundlage] unterscheidet „gemessen und null Punkte" von „nicht
/// gemessen". Beides sieht blass aus, nur das zweite wird **gestrichelt**
/// gezeichnet: Ein durchgehender blasser Bogen behauptet ein schlechtes
/// Ergebnis, das niemand gemessen hat.
class RingAbschnitt {
  const RingAbschnitt({
    required this.anteil,
    required this.fuellung,
    required this.farbe,
    this.hatGrundlage = true,
  });

  /// Anteil am ganzen Kreis; alle Abschnitte eines Rings zusammen ergeben 1.
  final double anteil;

  /// Wie viel vom **eigenen** Anteil erfüllt ist, 0 bis 1 — nicht vom
  /// ganzen Kreis.
  final double fuellung;

  final Color farbe;

  /// `false` → gestrichelt und ohne Füllung.
  final bool hatGrundlage;
}

/// Die Geometrie eines Segmentrings als reine Rechnung — die vier Regeln
/// aus `RingGauge` (`RecoveryRings.swift`, Z. 20–70), unverändert
/// übernommen.
///
/// Alle Rückgaben zählen in **Umdrehungen** (0 bis 1), nicht in Bogenmaß;
/// der Painter rechnet um:
/// `winkel = RingGeometrie.drehung + 2π · start(i)`, Bogenlänge
/// `2π · laenge(i)` bzw. `2π · fuellLaenge(i)`.
///
/// Eigene Klasse statt privater Rechnung im Painter, damit Startwinkel,
/// Lücke, 2-%-Schwelle und die Entscheidung „gestrichelt" ohne
/// Pixelvergleich prüfbar sind. Der Painter in dieser Datei benutzt sie und
/// rechnet nichts davon ein zweites Mal.
class RingGeometrie {
  const RingGeometrie(this.abschnitte, {this.luecke = standardLuecke});

  final List<RingAbschnitt> abschnitte;

  /// Lücke zwischen zwei Abschnitten, in Umdrehungen. Bei einem einzigen
  /// Abschnitt bleibt sie aus — ein Kreis mit einem Schlitz wäre ein
  /// Zeichen, das nichts bedeutet.
  static const double standardLuecke = 0.014;

  /// **Ein Maß des Bildes, keines der Daten** — deshalb überhaupt
  /// einstellbar (#243). Auf 92 Punkten sind 0,014 Umdrehungen ein Bogen
  /// von 3,7 Punkten, auf den 30 einer Kalenderzelle noch 1,2; eine runde
  /// Kappe trägt an jedem Ende eine halbe Strichstärke auf und fräße sie
  /// dort ganz weg. Wer kleiner zeichnet, braucht eine größere Lücke,
  /// damit dasselbe zu sehen ist.
  final double luecke;

  /// Erst **über** 2 % wird gefüllt (`segment.fill > 0.02` in Swift). Ein
  /// Strichlein, das kürzer als die runde Kappe ist, sähe aus wie ein Punkt
  /// und nicht wie „fast nichts".
  static const double fuellSchwelle = 0.02;

  /// Eine Vierteldrehung nach links, damit oben angefangen wird
  /// (`rotationEffect(.degrees(-90))`).
  static const double drehung = -math.pi / 2;

  double get _luecke => abschnitte.length > 1 ? luecke : 0;

  /// Ein einzelner Abschnitt über den ganzen Kreis — der Fall „keine
  /// Nacht". Er ist selbst die Spur, es liegt kein gefüllter Bogen darauf.
  bool get einzeln => abschnitte.length < 2;

  /// Der Anfang des Abschnitts: die Summe der Anteile aller Abschnitte
  /// davor.
  double start(int index) {
    var summe = 0.0;
    for (var i = 0; i < index && i < abschnitte.length; i++) {
      summe += abschnitte[i].anteil;
    }
    return summe;
  }

  /// Die Länge der blassen Spur: der Anteil minus der Lücke, nie negativ —
  /// ein Abschnitt, der kleiner als die Lücke ist, verschwindet, statt sich
  /// rückwärts zu zeichnen.
  double laenge(int index) {
    final laenge = abschnitte[index].anteil - _luecke;
    return laenge > 0 ? laenge : 0;
  }

  /// Die Länge des gefüllten Teils. Ohne Datengrundlage null, bis
  /// einschließlich [fuellSchwelle] null, bei 100 % gedeckelt — keine
  /// zweite Runde wie bei den Tagesringen in `ringe.dart`.
  double fuellLaenge(int index) {
    final abschnitt = abschnitte[index];
    if (!abschnitt.hatGrundlage) return 0;
    if (!(abschnitt.fuellung > fuellSchwelle)) return 0;
    final anteil = abschnitt.fuellung > 1 ? 1.0 : abschnitt.fuellung;
    return laenge(index) * anteil;
  }

  /// Gestrichelt genau dann, wenn es für den Abschnitt keine Daten gibt.
  bool gestrichelt(int index) => !abschnitte[index].hatGrundlage;
}

/// Ein Kreis, in Segmente geteilt, mit Zahl und Beschriftung in der Mitte —
/// Dart-Entsprechung von `RingGauge` in `RecoveryRings.swift`.
///
/// **Ein Baustein neben `ringe.dart`, kein Umbau davon.** `Ringe` zeichnet
/// *konzentrische* Ringe mit zweiter Runde bei Übererfüllung; hier geht es
/// um **einen** Kreis, in Segmente geteilt, ohne zweite Runde.
class SegmentRing extends StatelessWidget {
  const SegmentRing({
    super.key,
    required this.abschnitte,
    required this.mitte,
    required this.caption,
    this.durchmesser = 92,
  });

  final List<RingAbschnitt> abschnitte;

  /// Die große Zahl in der Mitte — „76" oder „—".
  final String mitte;

  /// Die kleine Zeile darunter — „Score", „von 70", „Signale", „min".
  final String caption;

  final double durchmesser;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    // Jede Farbe hier aufgelöst, nicht im Painter: Dort gibt es keinen
    // `BuildContext`, und eine unaufgelöste `CupertinoDynamicColor` bliebe
    // im Dunkelmodus auf ihrer hellen Variante stehen.
    final farben = [
      for (final abschnitt in abschnitte)
        CupertinoDynamicColor.resolve(abschnitt.farbe, context),
    ];

    return SizedBox(
      width: durchmesser,
      height: durchmesser,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(durchmesser),
            painter: _SegmentRingPainter(
              geometrie: RingGeometrie(abschnitte),
              farben: farben,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                mitte,
                style: Typografie.tabularNumbers(
                  Typografie.numeric(
                    TypografieGroesse.title2,
                    gewicht: FontWeight.w700,
                  ),
                ).copyWith(color: ink, height: 1),
              ),
              Text(caption, style: TextStyle(fontSize: 11, color: muted)),
            ],
          ),
        ],
      ),
    );
  }
}

/// **Derselbe Ring ohne Mitte, für kleine Durchmesser** — der Ring einer
/// Kalenderzelle (#243, Tim: „es soll den Ring von Schlaf nachstellen, den
/// wir da oben benutzen").
///
/// Die Abschnitte kommen von außen und sind dieselben wie oben; gerechnet
/// wird über [RingGeometrie], also über genau eine Rechnung. Verschieden
/// sind nur die Maße, und beide Unterschiede folgen aus dem Durchmesser:
///
/// - **Eine breitere Lücke** ([luecke]) — auf 30 Punkten wären die 0,014
///   Umdrehungen des großen Rings ein Bogen von 1,2 Punkten.
/// - **Stumpfe Enden statt runder.** Eine runde Kappe trägt an jedem Ende
///   eine halbe Strichstärke auf und schlösse die Lücke wieder; drei
///   Abschnitte sähen aus wie ein Kreis, der zweimal die Farbe wechselt.
///
/// [child] liegt in der Mitte — im Kalender die Ziffer des Tages. Ohne
/// Zahl und ohne Beschriftung: Auf diesem Durchmesser wäre beides nicht zu
/// lesen, und die Ziffer steht schon da.
class SegmentRingKlein extends StatelessWidget {
  const SegmentRingKlein({
    super.key,
    required this.abschnitte,
    required this.durchmesser,
    this.child,
  });

  /// Lücke zwischen zwei Abschnitten, in Umdrehungen — knapp eine
  /// Strichstärke auf 30 Punkten. Siehe [RingGeometrie.luecke].
  static const double luecke = 0.035;

  /// Strichstärke als Anteil des Durchmessers. Etwas kräftiger als die
  /// 0,095 des großen Rings: Drei Farben auf 30 Punkten brauchen Fläche.
  static const double strichAnteil = 0.1;

  /// Strich und Lücke der gestrichelten Spur, in Strichstärken — vierzehn
  /// Striche auf dem ganzen Kreis, **dieselbe Strichelung wie der Ring
  /// eines Tages ohne Nacht**. Die Maße des großen Rings (halbe und
  /// dreiviertel Strichstärke) ergäben hier Punkte statt Striche.
  static const double strichLaenge = 1.1;
  static const double strichLuecke = 0.9;

  /// Leer heißt **gar kein Ring** — ein Tag, an dem niemand nachgesehen
  /// hat, behauptet nichts.
  final List<RingAbschnitt> abschnitte;

  final double durchmesser;

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    // Aufgelöst hier, nicht im Painter: Dort gibt es keinen
    // `BuildContext`, und eine unaufgelöste `CupertinoDynamicColor` bliebe
    // im Dunkelmodus auf ihrer hellen Variante stehen.
    final farben = [
      for (final abschnitt in abschnitte)
        CupertinoDynamicColor.resolve(abschnitt.farbe, context),
    ];

    return SizedBox(
      width: durchmesser,
      height: durchmesser,
      child: CustomPaint(
        painter: _KleinerRingPainter(
          geometrie: RingGeometrie(abschnitte, luecke: luecke),
          farben: farben,
        ),
        child: child == null ? null : Center(child: child),
      ),
    );
  }
}

class _KleinerRingPainter extends CustomPainter {
  _KleinerRingPainter({required this.geometrie, required this.farben});

  final RingGeometrie geometrie;
  final List<Color> farben;

  @override
  void paint(Canvas canvas, Size size) {
    final seite = math.min(size.width, size.height);
    final strichstaerke = seite * SegmentRingKlein.strichAnteil;
    final einzug = strichstaerke / 2;
    final kreis = Rect.fromLTWH(
      einzug,
      einzug,
      seite - einzug * 2,
      seite - einzug * 2,
    );
    if (kreis.width <= 0 || kreis.height <= 0) return;

    for (var i = 0; i < geometrie.abschnitte.length; i++) {
      final laenge = geometrie.laenge(i) * 2 * math.pi;
      if (laenge <= 0) continue;
      final anfang = RingGeometrie.drehung + geometrie.start(i) * 2 * math.pi;
      final farbe = farben[i];
      final gestrichelt = geometrie.gestrichelt(i);

      // **Ein einzelner Abschnitt über den ganzen Kreis ist selbst die
      // Spur** — es liegt kein gefüllter Bogen darauf, von dem er sich
      // abheben müsste, und blass wäre er in einer 30-Punkt-Zelle kaum zu
      // sehen. Bei drei Abschnitten dieselben Werte wie oben.
      final deckung = geometrie.einzeln
          ? 1.0
          : gestrichelt
          ? 0.45
          : 0.32;
      final spur = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strichstaerke
        ..strokeCap = StrokeCap.butt
        ..color = farbe.withValues(alpha: deckung);
      if (gestrichelt) {
        _striche(
          canvas,
          kreis,
          anfang,
          laenge,
          spur,
          strich: strichstaerke * SegmentRingKlein.strichLaenge,
          luecke: strichstaerke * SegmentRingKlein.strichLuecke,
        );
      } else {
        canvas.drawArc(kreis, anfang, laenge, false, spur);
      }

      final fuellung = geometrie.fuellLaenge(i) * 2 * math.pi;
      if (fuellung > 0) {
        final stift = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strichstaerke
          ..strokeCap = StrokeCap.butt
          ..color = farbe;
        canvas.drawArc(kreis, anfang, fuellung, false, stift);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _KleinerRingPainter alt) {
    final alte = alt.geometrie.abschnitte;
    final neue = geometrie.abschnitte;
    if (alte.length != neue.length) return true;
    for (var i = 0; i < neue.length; i++) {
      if (alte[i].anteil != neue[i].anteil ||
          alte[i].fuellung != neue[i].fuellung ||
          alte[i].hatGrundlage != neue[i].hatGrundlage) {
        return true;
      }
    }
    return !listEquals(alt.farben, farben);
  }
}

/// Der gestrichelte Bogen — Flutter kennt kein `dash` am `Paint`, also
/// wird er aus einzelnen kurzen Bögen gesetzt. Von beiden Ringen benutzt;
/// die Maße gibt der Aufrufer, weil sie am Durchmesser hängen.
void _striche(
  Canvas canvas,
  Rect kreis,
  double anfang,
  double laenge,
  Paint stift, {
  required double strich,
  required double luecke,
}) {
  final radius = kreis.width / 2;
  if (radius <= 0 || strich <= 0) return;
  // Von der Strecke am Kreisbogen auf den Winkel: Bogen = Radius · Winkel.
  final strichWinkel = strich / radius;
  final schritt = (strich + luecke) / radius;
  final ende = anfang + laenge;
  for (var winkel = anfang; winkel < ende; winkel += schritt) {
    final rest = ende - winkel;
    canvas.drawArc(
      kreis,
      winkel,
      rest < strichWinkel ? rest : strichWinkel,
      false,
      stift,
    );
  }
}

class _SegmentRingPainter extends CustomPainter {
  _SegmentRingPainter({required this.geometrie, required this.farben});

  final RingGeometrie geometrie;

  /// Bereits aufgelöste Farben, in derselben Reihenfolge wie die
  /// Abschnitte.
  final List<Color> farben;

  @override
  void paint(Canvas canvas, Size size) {
    final seite = math.min(size.width, size.height);
    // `lineWidth = size * 0.095` aus `RingGauge`.
    final strichstaerke = seite * 0.095;
    final einzug = strichstaerke / 2;
    final kreis = Rect.fromLTWH(
      einzug,
      einzug,
      seite - einzug * 2,
      seite - einzug * 2,
    );
    if (kreis.width <= 0 || kreis.height <= 0) return;

    for (var i = 0; i < geometrie.abschnitte.length; i++) {
      final laenge = geometrie.laenge(i) * 2 * math.pi;
      if (laenge <= 0) continue;
      final anfang = RingGeometrie.drehung + geometrie.start(i) * 2 * math.pi;
      final farbe = farben[i];

      // Die blasse Spur. Ohne Datengrundlage gestrichelt und etwas
      // kräftiger, damit sie sich von einem leeren, aber gemessenen
      // Abschnitt unterscheidet.
      final gestrichelt = geometrie.gestrichelt(i);
      final spur = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strichstaerke
        ..strokeCap = gestrichelt ? StrokeCap.butt : StrokeCap.round
        ..color = farbe.withValues(alpha: gestrichelt ? 0.45 : 0.32);
      if (gestrichelt) {
        // Maße wie in Swift: `dash: [lineWidth * 0.5, lineWidth * 0.75]`.
        _striche(
          canvas,
          kreis,
          anfang,
          laenge,
          spur,
          strich: strichstaerke * 0.5,
          luecke: strichstaerke * 0.75,
        );
      } else {
        canvas.drawArc(kreis, anfang, laenge, false, spur);
      }

      final fuellung = geometrie.fuellLaenge(i) * 2 * math.pi;
      if (fuellung > 0) {
        final stift = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strichstaerke
          ..strokeCap = StrokeCap.round
          ..color = farbe;
        canvas.drawArc(kreis, anfang, fuellung, false, stift);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SegmentRingPainter oldDelegate) {
    return oldDelegate.geometrie.abschnitte != geometrie.abschnitte ||
        !listEquals(oldDelegate.farben, farben);
  }
}
