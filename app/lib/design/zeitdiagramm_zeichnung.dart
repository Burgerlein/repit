/// Das Zeichnen des gemeinsamen Diagramm-Bauteils — die zweite Hälfte von
/// `zeitdiagramm.dart`.
///
/// Getrennt, weil die Datei sonst über tausend Zeilen ginge: „Wächst eine
/// Datei über ein paar hundert Zeilen, macht sie zu viel — dann trenn das
/// Zeichnen (`CustomPainter`) von der Gestensteuerung" (`CLAUDE.md`). Hier
/// liegt kein Zustand und keine Geste, nur Striche.
library;

import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

import 'diagramm_auswahl.dart';
import 'zeitdiagramm_stapel.dart';

/// Luft über dem höchsten Balken und Platz für die Achsenbeschriftung
/// darunter, beides innerhalb der Graphfläche (`lineChart`: `T = 8`,
/// `B = 20`).
const double _luftOben = 8;
const double _luftUnten = 20;

/// Der Platz, den eine Beschriftung in 9 Punkt über ihrer Ziellinie
/// braucht: zwölf Punkt, davon knapp elf Schrift.
const double _beschriftungHoehe = 12;

/// Und ihr Abstand, wenn sie unter der Linie steht — genug, um den 1,5
/// Punkt breiten Strich nicht zu berühren.
const double _beschriftungUnterLinie = 3;

/// Wo die Beschriftung einer Ziellinie anfängt, die bei [linienY] liegt.
///
/// Normalerweise [_beschriftungHoehe] darüber. **Reicht der Platz dort
/// nicht bis unter die oberste Rasterlinie, fällt sie unter die Linie**:
/// Oben schnitte das `clipRect` sie weg, und eine Beschriftung, die unten
/// steht, ist besser als eine, die gar nicht da ist (#162).
///
/// Dass sie überhaupt so weit oben liegen kann, ist nach der Luft aus
/// `Fensterstand.grenzen` kein Fall mehr für eine Ziellinie, die die Achse
/// bestimmt — wohl aber für eine, die **dicht unter dem höchsten Messwert**
/// liegt. Die bekommt keine Luft, weil sie das Ende der Achse nicht
/// bestimmt, und steht trotzdem ganz oben.
///
/// Herausgezogen am 29.10.2026 (#162), damit die Lage ohne Pixelvergleich
/// prüfbar ist; sie stand bis dahin als `hoeheHier - 12` im Malvorgang.
double ziellinienBeschriftungY(double linienY) =>
    linienY - _beschriftungHoehe >= _luftOben
    ? linienY - _beschriftungHoehe
    : linienY + _beschriftungUnterLinie;

/// Wo die Beschriftungen **mehrerer** Ziellinien anfangen — in derselben
/// Reihenfolge wie [linienY], eine Lage je Linie.
///
/// Für eine einzelne Linie ist das wortgleich [ziellinienBeschriftungY].
/// Für mehrere kommt eine Bedingung dazu: **Keine Beschriftung legt sich
/// auf eine andere.** Die eine weicht dann unter ihre Linie aus, mit
/// demselben Griff, den #162 für den oberen Rand eingeführt hat.
///
/// **Warum das nötig ist** (#178). Auf dem Schlaf-Verlauf steht „Normal"
/// auf dem eigenen 30-Tage-Median und „Warnsignal" auf der festen Grenze
/// von sechs Stunden. Beide sind richtig gerechnet — sie liegen nur dicht
/// beieinander. Gemessen an einer Woche mit 5,7 bis 7,4 h, Median 6,683 h
/// und Grenze 6,0 h (Balken, Achse also 0 bis 7,4):
///
/// - Die Linien liegen bei y = 19,6 und y = 30,7 — `11,1` Punkt
///   auseinander auf der 120 Punkt hohen Zeichenfläche.
/// - **Vorher:** Über „Normal" sind nur 11,6 Punkt bis zur obersten
///   Rasterlinie, zwölf wären nötig — ihre Beschriftung fiel nach #162
///   schon unter die Linie, auf y = 22,6. „Warnsignal" stand über ihrer
///   Linie, auf y = 18,7. Die beiden überlappten sich um **15,9 Punkt**,
///   standen also fast genau übereinander.
/// - **Jetzt:** „Normal" bleibt auf 22,6, „Warnsignal" weicht unter ihre
///   Linie und stapelt sich auf y = 34,6 — bündig darunter, zwölf Punkt
///   Abstand, so viel wie eine Beschriftung belegt.
///
/// **Gelegt wird von oben nach unten**, nicht in der übergebenen
/// Reihenfolge: Sonst hinge es daran, wie der Schirm seine Linien sortiert
/// hat, und dieselben zwei Linien sprängen, wenn er sie einmal andersherum
/// übergibt. Die obere behält ihren gewohnten Platz; ausweichen muss die
/// darunter.
///
/// **Die Breite der Schrift zählt nicht mit.** Alle Beschriftungen beginnen
/// am selben linken Rand, also überlappen sie sich waagerecht ohnehin; die
/// ganze Frage ist senkrecht. Das ist der zweite Grund für den linken Rand
/// (der erste steht im Malvorgang).
List<double> ziellinienBeschriftungenY(List<double> linienY) {
  final lagen = List<double>.filled(linienY.length, 0);
  final belegt = <(double, double)>[];

  final reihenfolge = [for (var i = 0; i < linienY.length; i++) i]
    ..sort((a, b) => linienY[a].compareTo(linienY[b]));

  for (final i in reihenfolge) {
    final gewohnt = ziellinienBeschriftungY(linienY[i]);
    // Der zweite Platz ist der jeweils andere: Steht sie normalerweise
    // über der Linie, weicht sie darunter aus — und umgekehrt.
    final ausweich = gewohnt < linienY[i]
        ? linienY[i] + _beschriftungUnterLinie
        : linienY[i] - _beschriftungHoehe;

    // Und der dritte, falls auch der besetzt ist: bündig unter allem, was
    // schon liegt — aber nie über die eigene Linie hinauf, sonst stünde
    // die Schrift auf ihrem eigenen gestrichelten Strich. Das ist kein
    // Randfall: Genau hier landet „Warnsignal" im Beispiel oben, weil
    // drei Punkt unter der eigenen Linie noch in „Normal" hineinragen.
    final gestapelt = math.max(
      linienY[i] + _beschriftungUnterLinie,
      belegt.fold(0.0, (tiefste, anderer) => math.max(tiefste, anderer.$2)),
    );

    var gewaehlt = gestapelt;
    for (final kandidat in [gewohnt, ausweich, gestapelt]) {
      final frei =
          kandidat >= 0 &&
          !belegt.any(
            (anderer) =>
                kandidat < anderer.$2 &&
                anderer.$1 < kandidat + _beschriftungHoehe,
          );
      if (frei) {
        gewaehlt = kandidat;
        break;
      }
    }

    lagen[i] = gewaehlt;
    belegt.add((gewaehlt, gewaehlt + _beschriftungHoehe));
  }
  return lagen;
}

/// Zeichnet Raster, Balken oder Linie, Ziellinien, Auswahl und Achse.
///
/// **Öffentlich und mit bereits aufgelösten Farben**, wie
/// `HypnogrammPainter` in `hypnogramm.dart`: Eine unaufgelöste
/// `CupertinoDynamicColor` bliebe im Dunkelmodus auf ihrer hellen Variante
/// stehen, und das ist ohne Pixelvergleich nur zu prüfen, wenn die Farben
/// von außen hineingehen.
class ZeitdiagrammPainter extends CustomPainter {
  ZeitdiagrammPainter({
    required this.balken,
    required this.plaetze,
    required this.versatz,
    required this.auswahl,
    required this.alsBalken,
    required this.grenzen,
    required this.achse,
    required this.linien,
    required this.farbe,
    required this.rasterFarbe,
    required this.textFarbe,
    required this.flaeche,
    this.zweite = const [],
    this.zweiteFarbe,
    this.stapel = const [],
    this.stapelFarben = const [],
    this.zielWert,
    this.zielFarbe,
  });

  /// Balken des Fensters **und seiner Nachbarn** — `platz` darf negativ oder
  /// größer als [plaetze] sein; was herausragt, wird beschnitten.
  final List<({int platz, double wert})> balken;

  /// Wie viele Plätze die Breite füllen.
  final int plaetze;

  /// Der laufende Wisch in Punkten.
  final double versatz;

  final int? auswahl;
  final bool alsBalken;
  final (double unten, double oben) grenzen;
  final List<({int platz, String text})> achse;

  /// Die waagerechten Linien, jede mit ihrer **fertigen** Beschriftung.
  ///
  /// `beschriftung` und nicht `name`: Was dasteht, setzt der Schirm
  /// zusammen (`Ziellinie.beschriftung`) — der Maler weiß nicht, ob die
  /// Zahl Stunden, Minuten oder Schläge sind (#178).
  final List<({String beschriftung, double wert, Color farbe})> linien;

  /// Die zweite Reihe, **gestrichelt** auf derselben Skala. Leer: keine.
  ///
  /// **Eine Lücke bleibt eine Lücke.** Zwischen zwei Punkten der zweiten
  /// Reihe wird nur dann verbunden, wenn dazwischen kein Platz der ersten
  /// liegt — liegt einer dazwischen, gab es dort einen Wert der ersten
  /// Reihe, aber keinen der zweiten, und eine Linie darüber hinweg
  /// behauptete einen. Es wird auch nie eine 0 gezeichnet.
  final List<({int platz, double wert})> zweite;

  /// Die Farbe der zweiten Reihe; ohne Angabe [farbe].
  final Color? zweiteFarbe;

  /// Je Platz die **Teile**, nach denen sein Balken in sich geteilt wird
  /// (#504) — in derselben Einheit wie [balken], nicht in Prozent. Leer:
  /// kein Stapel, jeder Balken steht einfarbig da.
  ///
  /// **Der Balken behält seine Höhe**, die Teile teilen sie anteilig; die
  /// Rechnung dafür ist `stapelGrenzen`. Höhe = Anteil verlöre die Dauer,
  /// und beim Schlaf ist die Dauer die Aussage.
  ///
  /// **Eine zweite Spur ist das nicht.** [zweite] läuft auf derselben
  /// y-Skala *neben* der ersten; ein Stapel liegt *in* seinem Balken.
  ///
  /// Gilt nur bei [alsBalken]: Eine Linie hat keine Fläche, die sich
  /// teilen ließe.
  ///
  /// **Und nur für Werte über der Null.** Gefüllt wird von `bottom` nach
  /// oben; bei einem negativen Balken ist `bottom` das von der Achse
  /// abgewandte Ende, der Stapel liefe also andersherum als beim
  /// positiven Nachbarn. Kein Aufrufer tut das — es steht hier, weil der
  /// Code es nicht erzwingt.
  final List<({int platz, List<double> teile})> stapel;

  /// Die Farbe je Teil, in derselben Reihenfolge wie die Teile eines
  /// Eintrags in [stapel] — **fertig aufgelöst**, wie alle Farben hier.
  ///
  /// Mehr Teile als Farben kommen nicht vor; käme es dazu, fiele der
  /// überzählige Teil auf [farbe] zurück, statt den Balken zu verschlucken.
  final List<Color> stapelFarben;

  /// Balken mit mindestens diesem Wert tragen [zielFarbe] statt [farbe]
  /// (#84: „Grün, sobald der Tag das Ziel erreicht"). `null`: keine
  /// Einfärbung. Gilt nur für ungestapelte Balken — ein Stapel trägt seine
  /// Farben selbst, und eine Linie hat keine Fläche.
  final double? zielWert;

  /// Die Farbe der Balken ab [zielWert] — **fertig aufgelöst**, wie alle
  /// Farben hier; ohne Angabe [farbe].
  final Color? zielFarbe;

  final Color farbe;
  final Color rasterFarbe;
  final Color textFarbe;
  final Color flaeche;

  @override
  void paint(Canvas canvas, Size size) {
    final hoehe = size.height - _luftOben - _luftUnten;
    if (hoehe <= 0 || size.width <= 0 || plaetze <= 0) return;

    final spanne = grenzen.$2 - grenzen.$1;
    double y(double wert) =>
        _luftOben + (1 - (wert - grenzen.$1) / spanne) * hoehe;
    final proPlatz = size.width / plaetze;
    double x(double platz) => platz * proPlatz + versatz;

    canvas.save();
    canvas.clipRect(Offset.zero & size);

    final raster = Paint()
      ..color = rasterFarbe.withValues(alpha: 0.7)
      ..strokeWidth = 0.5;
    for (final anteil in const [0.0, 0.5, 1.0]) {
      final hoeheHier = _luftOben + anteil * hoehe;
      canvas.drawLine(
        Offset(0, hoeheHier),
        Offset(size.width, hoeheHier),
        raster,
      );
    }

    // Erst alle Lagen, dann zeichnen: Wohin eine Beschriftung gehört,
    // hängt davon ab, wo die anderen liegen (#178).
    final linienY = [for (final linie in linien) y(linie.wert)];
    final beschriftungenY = ziellinienBeschriftungenY(linienY);
    for (final (i, linie) in linien.indexed) {
      zeichneGestrichelt(
        canvas,
        Offset(0, linienY[i]),
        Offset(size.width, linienY[i]),
        Paint()
          ..color = linie.farbe
          ..strokeWidth = 1.5,
      );
      // **Links, wie im Entwurfsboard** (`lineChart`: `x = L + 2`). Die
      // App schrieb bis zum 29.10.2026 rechtsbündig; mit der Zahl im Namen
      // wächst die Beschriftung und wuchs damit über die **jüngsten**
      // Balken — die, auf die man schaut und die man anhält. Nach links
      // wächst sie über die ältesten. Dass alle am selben Rand beginnen,
      // macht zwei Beschriftungen außerdem zu einer Spalte statt zu zwei
      // ausgefransten Enden (#178).
      _text(
        canvas,
        linie.beschriftung,
        Offset(2, beschriftungenY[i]),
        linie.farbe,
      );
    }

    if (alsBalken) {
      _zeichneBalken(canvas, size, proPlatz, x, y);
    } else {
      _zeichneLinie(canvas, proPlatz, x, y);
    }

    if (zweite.isNotEmpty) _zeichneZweite(canvas, x, y);

    final gewaehlt = auswahl;
    if (gewaehlt != null) {
      zeichneAuswahlLot(
        canvas,
        x: x(gewaehlt + 0.5),
        oben: _luftOben,
        unten: _luftOben + hoehe,
        farbe: farbe,
      );
    }

    for (final eintrag in achse) {
      _text(
        canvas,
        eintrag.text,
        Offset(x(eintrag.platz + 0.5), size.height - _luftUnten + 5),
        eintrag.platz == auswahl ? farbe : textFarbe,
        mittig: true,
      );
    }

    canvas.restore();
  }

  void _zeichneBalken(
    Canvas canvas,
    Size size,
    double proPlatz,
    double Function(double) x,
    double Function(double) y,
  ) {
    final basis = y(math.max(grenzen.$1, math.min(0, grenzen.$2)));
    final breite = math.max(proPlatz * 0.62, 1.5);
    final radius = Radius.circular(math.min(breite / 2, 3));
    // Welcher Platz welche Teile trägt — einmal, nicht je Balken erneut
    // durch die Liste gelaufen.
    final teileJePlatz = {
      for (final eintrag in stapel) eintrag.platz: eintrag.teile,
    };
    for (final einzeln in balken) {
      final links = x(einzeln.platz + 0.5) - breite / 2;
      final oben = y(einzeln.wert);
      final rechteck = Rect.fromLTRB(
        links,
        math.min(oben, basis),
        links + breite,
        math.max(oben, basis),
      );
      final gerundet = RRect.fromRectAndCorners(
        // Ein Balken ohne Höhe bliebe unsichtbar; eine Messung von 0 ist
        // aber eine Messung.
        Rect.fromLTRB(
          rechteck.left,
          rechteck.top,
          rechteck.right,
          math.max(rechteck.bottom, rechteck.top + 1),
        ),
        topLeft: radius,
        topRight: radius,
      );
      final gehalten = einzeln.platz == auswahl;
      final teile = teileJePlatz[einzeln.platz];
      final grenzenImBalken = teile == null
          ? const <double>[]
          : stapelGrenzen(teile);

      if (grenzenImBalken.isEmpty) {
        final ziel = zielWert;
        final grundFarbe = ziel != null && einzeln.wert >= ziel
            ? (zielFarbe ?? farbe)
            : farbe;
        canvas.drawRRect(
          gerundet,
          Paint()..color = balkenFarbe(grundFarbe, gehalten: gehalten),
        );
        continue;
      }
      _zeichneStapel(canvas, gerundet, grenzenImBalken, gehalten: gehalten);
    }
  }

  /// Einen Balken in seine Teile zerlegen — von unten nach oben, in den
  /// Farben aus [stapelFarben].
  ///
  /// **Beschnitten wird die ganze Form, nicht jeder Teil gerundet**
  /// (`CLAUDE.md`): Ein Teil mit eigenem Eckenradius liefe über die Ecke
  /// hinaus oder ließe unter der Rundung eine Lücke. Der oberste Teil
  /// bekommt die Rundung damit geschenkt, und zwar genau die des Balkens.
  ///
  /// **Die Grenzen sind Oberkanten auf der Höhe 1** und werden hier auf
  /// die gezeichnete Höhe gestreckt; die Normierung steckt in
  /// `stapelGrenzen` und nicht hier.
  void _zeichneStapel(
    Canvas canvas,
    RRect form,
    List<double> grenzenImBalken, {
    required bool gehalten,
  }) {
    canvas.save();
    canvas.clipRRect(form);
    final hoehe = form.bottom - form.top;
    var untenBisher = form.bottom;
    for (var i = 0; i < grenzenImBalken.length; i++) {
      final obenHier = form.bottom - grenzenImBalken[i] * hoehe;
      // Ein Teil ohne Minuten bekommt keine Höhe — und wird nicht
      // trotzdem einen Punkt hoch gezeichnet: Er war nicht da.
      if (obenHier >= untenBisher) continue;
      final teilFarbe = i < stapelFarben.length ? stapelFarben[i] : farbe;
      canvas.drawRect(
        Rect.fromLTRB(form.left, obenHier, form.right, untenBisher),
        Paint()..color = balkenFarbe(teilFarbe, gehalten: gehalten),
      );
      untenBisher = obenHier;
    }
    canvas.restore();
  }

  void _zeichneLinie(
    Canvas canvas,
    double proPlatz,
    double Function(double) x,
    double Function(double) y,
  ) {
    final sortiert = [...balken]..sort((a, b) => a.platz.compareTo(b.platz));
    if (sortiert.isEmpty) return;

    final pfad = Path();
    for (var i = 0; i < sortiert.length; i++) {
      final punkt = Offset(x(sortiert[i].platz + 0.5), y(sortiert[i].wert));
      if (i == 0) {
        pfad.moveTo(punkt.dx, punkt.dy);
      } else {
        pfad.lineTo(punkt.dx, punkt.dy);
      }
    }
    canvas.drawPath(
      pfad,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = farbe,
    );

    // Punkte auf der Linie: Ohne sie sieht man nicht, dass es Einzelwerte
    // gibt (`lineChart` im Entwurfsboard).
    for (final einzeln in sortiert) {
      final mitte = Offset(x(einzeln.platz + 0.5), y(einzeln.wert));
      final gewaehlt = einzeln.platz == auswahl;
      if (gewaehlt) {
        zeichneAuswahlPunkt(canvas, mitte, farbe: farbe, flaeche: flaeche);
      } else {
        canvas.drawCircle(
          mitte,
          2.6,
          Paint()..color = farbe.withValues(alpha: 0.85),
        );
      }
    }
  }

  void _zeichneZweite(
    Canvas canvas,
    double Function(double) x,
    double Function(double) y,
  ) {
    final sortiert = [...zweite]..sort((a, b) => a.platz.compareTo(b.platz));
    final ersteOrte = {for (final eintrag in balken) eintrag.platz};
    final farbeZwei = zweiteFarbe ?? farbe;
    final stift = Paint()
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = farbeZwei;

    for (var i = 1; i < sortiert.length; i++) {
      final a = sortiert[i - 1], b = sortiert[i];
      // Dazwischen ein Platz der ersten Reihe: Dort fehlt der zweite Wert.
      var luecke = false;
      for (var platz = a.platz + 1; platz < b.platz && !luecke; platz++) {
        luecke = ersteOrte.contains(platz);
      }
      if (luecke) continue;
      zeichneGestrichelt(
        canvas,
        Offset(x(a.platz + 0.5), y(a.wert)),
        Offset(x(b.platz + 0.5), y(b.wert)),
        stift,
      );
    }
    // Punkte: ohne sie wäre ein einzelner Wert nach einer Lücke unsichtbar.
    for (final einzeln in sortiert) {
      canvas.drawCircle(
        Offset(x(einzeln.platz + 0.5), y(einzeln.wert)),
        2.2,
        Paint()..color = farbeZwei.withValues(alpha: 0.85),
      );
    }
  }

  void _text(
    Canvas canvas,
    String text,
    Offset bei,
    Color farbe, {
    bool mittig = false,
  }) {
    final maler = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: 9, color: farbe),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final versatzX = mittig ? maler.width / 2 : 0.0;
    maler.paint(canvas, Offset(bei.dx - versatzX, bei.dy));
    maler.dispose();
  }

  @override
  bool shouldRepaint(covariant ZeitdiagrammPainter alt) =>
      alt.versatz != versatz ||
      alt.auswahl != auswahl ||
      alt.plaetze != plaetze ||
      alt.alsBalken != alsBalken ||
      alt.grenzen != grenzen ||
      alt.farbe != farbe ||
      alt.rasterFarbe != rasterFarbe ||
      alt.textFarbe != textFarbe ||
      alt.flaeche != flaeche ||
      alt.zielWert != zielWert ||
      alt.zielFarbe != zielFarbe ||
      alt.zweiteFarbe != zweiteFarbe ||
      !listEquals(alt.stapelFarben, stapelFarben) ||
      // Ein Record mit `List`-Feld vergleicht die Liste über ihre
      // Identität. Der Stapel kommt als Ganzes aus dem gehaltenen
      // `Fensterstand`, also ist das genau die Frage „ist es noch
      // derselbe Stand?" — und bei einem neu gerechneten Stand
      // zuverlässig „nein", auch wenn die Zahlen darin gleich wären.
      !listEquals(alt.stapel, stapel) ||
      !listEquals(alt.zweite, zweite) ||
      !listEquals(alt.balken, balken) ||
      !listEquals(alt.achse, achse) ||
      !listEquals(alt.linien, linien);
}
