// Die sieben Nächte des Schlaf-Schirms (#92): ein Balken je Nacht auf einer
// gemeinsamen Nachtuhr, dazu Raster, Achse, Legende und der Painter.
//
// Eigene Datei, und die größte der vier — hier hängt alles an **einer**
// Skala. Raster, Beschriftung und Balken müssen auf derselben Rechnung
// sitzen ([schlafNaechteAnteil]); zwei Rechnungen liefen schon einmal
// auseinander. Was zusammen stimmen muss, steht zusammen.
//
// **`schlaf_abschnitte.dart` exportiert diese Datei weiter.** Die
// festgelegte API bleibt `import '…/shell/schlaf_abschnitte.dart'`.
//
// Herausgelöst am 28.10.2026 für #153. Tim hat „aufteilen" verlangt; wo
// der Schnitt liegt, hat der umsetzende Agent entschieden.
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show mapEquals;
import 'package:trainings_core/trainings_core.dart';

import '../design/formatierung.dart';
import '../design/hypnogramm.dart';
import '../design/palette.dart';
import '../health/health_types.dart';
import 'schlaf_texte.dart';
import 'schlaf_zustand.dart';

/// Die Schlafminuten **einer** Nacht dieses Abschnitts: alles außer Wach.
///
/// Die eine Stelle, an der das gerechnet wird — rechts neben jedem Balken
/// steht diese Zahl. Herausgelöst für die zugeklappte Zeile aus #253; die
/// gibt es seit #257 nicht mehr, die Rechnung bleibt. Zwei Rechnungen
/// dafür liefen schon auseinander, wie es der Dateikopf für Raster und
/// Balken beschreibt.
double schlafNachtMinuten(SchlafNachtLage lage) => lage.minutenJePhase.entries
    .where((eintrag) => eintrag.key != SleepStage.awake)
    .fold<double>(0, (summe, eintrag) => summe + eintrag.value);

/// Lage **und** Länge, nicht nur die Summe — die Regelmäßigkeit steckt in
/// der Lage.
///
/// **Und jede Nacht trägt ihre Phasen** (#140): Bis dahin bekam der Painter
/// genau eine Farbe, die von „Kern", und der Balken sagte nur, wann und wie
/// lange geschlafen wurde. Der Entwurf färbt jede Nacht nach Phasen
/// (`nightsChart` in `docs/screens/components.js`) und setzt die Legende
/// darunter.
///
/// Farben und Spurreihenfolge kommen aus [SchlafPhasen] — **dieselbe
/// Zuordnung wie im Hypnogramm**. Eine zweite hier drehte „Tief ist dunkler
/// als Kern" im Dunkelmodus wieder um.
///
/// **Die Achse läuft 21:00 bis 10:00** (#154). Bis zum 28.10.2026 lief sie
/// 18:00 bis 18:00, also über volle 24 Stunden — eine Sieben-Stunden-Nacht
/// belegte darauf weniger als ein Drittel, und alle Nächte saßen als kurze
/// Klötzchen in der Mitte. Siehe [schlafNaechteAnteil].
class SchlafNaechteDiagramm extends StatelessWidget {
  const SchlafNaechteDiagramm({super.key, required this.lagen});

  final List<SchlafNachtLage> lagen;

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    if (lagen.isEmpty) {
      return Text(
        schlafOhneDaten,
        style: TextStyle(fontSize: 12, color: muted),
      );
    }

    // **Alle Phasen, nicht nur die vier Spuren.** `unspecified` kommt von
    // älteren Uhren und muss eine Farbe haben, sonst fiele ihre Nacht aus
    // dem Bild.
    final farben = {
      for (final phase in SleepStage.values)
        phase: CupertinoDynamicColor.resolve(
          SchlafPhasen.farbe(phase),
          context,
        ),
    };
    final spur = CupertinoDynamicColor.resolve(Palette.line, context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          children: [
            // Das Raster liegt **hinter** den Balken, wie im Entwurf: Dort
            // stehen die Rasterlinien vor den Rechtecken im Markup. Es
            // steht zuerst im Stapel und deshalb zuunterst.
            Positioned(
              left: _nachtNamensspalte,
              right: _nachtDauerspalte + _nachtDauerabstand,
              top: 0,
              bottom: 0,
              child: const _Nachtraster(),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final lage in lagen)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        SizedBox(
                          width: _nachtNamensspalte,
                          child: Text(
                            Format.wochentagKurz(kalendertag(lage.datum)),
                            style: TextStyle(fontSize: 11, color: muted),
                          ),
                        ),
                        Expanded(
                          child: SizedBox(
                            height: 14,
                            child: CustomPaint(
                              painter: _NachtBalkenPainter(
                                lage: lage,
                                farben: farben,
                                spur: spur,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: _nachtDauerabstand),
                        SizedBox(
                          width: _nachtDauerspalte,
                          child: Text(
                            schlafDauerText(schlafNachtMinuten(lage)),
                            textAlign: TextAlign.right,
                            style: TextStyle(fontSize: 11, color: muted),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(
            left: _nachtNamensspalte,
            right: _nachtDauerspalte + _nachtDauerabstand,
          ),
          child: const _Nachtachse(),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: _Phasenlegende(),
        ),
        const SizedBox(height: 6),
        // **Der zweite Satz beantwortet, was der Wochentag meint** (#212).
        // In 34 Punkten steht „Mo.", und das ließ offen, ob die Nacht *auf*
        // Montag oder die von Montagabend gemeint ist — Tims Beobachtung
        // vom 02.11.2026 an der Leiste oben, hier wortgleich. Die Spalte
        // ist zu schmal für „So. → Mo." (die Spaltenbreiten tragen Raster
        // und Achse, sie dürfen nicht mit dem Inhalt wachsen), also steht
        // die Auskunft einmal unter dem Bild statt siebenmal darin.
        Text(
          'Die Achse läuft von 21:00 bis 10:00 des Folgetags. Der Wochentag '
          'ist der Morgen, an dem die Nacht endete.',
          style: TextStyle(fontSize: 12, color: muted),
        ),
      ],
    );
  }
}

/// Die Spaltenbreiten der Nachtzeile. Das Raster und die Achse darunter
/// müssen genau über der Balkenspalte liegen, also dürfen beide Ränder
/// nicht mit dem Inhalt wachsen — deshalb hat auch die Dauer eine feste
/// Breite.
const double _nachtNamensspalte = 34;
const double _nachtDauerspalte = 46;
const double _nachtDauerabstand = 8;

/// Der Beginn der Nachtuhr als Abendminuten: 21:00 (`nightsChart`, `FROM`).
const double schlafNaechteAchseVon = 3.0 * Duration.minutesPerHour;

/// Das Ende der Nachtuhr als Abendminuten: 10:00 des Folgetags
/// (`nightsChart`, `TO` — dort 34 Uhr).
const double schlafNaechteAchseBis = 16.0 * Duration.minutesPerHour;

/// Die Rasterstunden des Entwurfs auf der Wanduhr — 21, 24, 27, 30, 33 Uhr
/// in `nightsChart`, also 21:00, 00:00, 03:00, 06:00 und 09:00.
const List<int> schlafNaechteRasterstunden = [21, 0, 3, 6, 9];

/// Wo ein Zeitpunkt auf der Achse der sieben Nächte liegt — 0 bei 21:00,
/// 1 bei 10:00 des Folgetags.
///
/// **Nicht mehr 18:00 bis 18:00** (#154): Auf einer 24-Stunden-Achse belegt
/// eine Sieben-Stunden-Nacht weniger als ein Drittel, und genau deshalb
/// saßen bei Tim alle Nächte als kurze Klötzchen in der Mitte. Dreizehn
/// Stunden reichen für jede Nacht und zeigen die Lage, auf die es ankommt.
///
/// Gerechnet wird über die **Berliner Wanduhr** ([EveningClock]), nicht
/// über verstrichene Zeit: Eine Zubettgehzeit ist eine Uhrzeit. Was vor
/// 21:00 oder nach 10:00 liegt, wird an den Rand geklemmt — ein Balken, der
/// über die Fläche hinausliefe, zeichnete über die Nachbarspalte.
double schlafNaechteAnteil(DateTime zeitpunkt) =>
    _nachtAnteilAusAbendminuten(EveningClock.minutesSinceEvening(zeitpunkt));

double _nachtAnteilAusAbendminuten(double abendminuten) =>
    ((abendminuten - schlafNaechteAchseVon) /
            (schlafNaechteAchseBis - schlafNaechteAchseVon))
        .clamp(0.0, 1.0);

double _nachtAnteilDerStunde(int stunde) => _nachtAnteilAusAbendminuten(
  EveningClock.minutesSinceEveningOfClock(hour: stunde, minute: 0),
);

/// Die senkrechten Rasterlinien hinter den Nachtbalken.
///
/// Absichtlich **kein** [CustomPaint]: Die Farbprüfungen in
/// `schlaf_naechte_farben_test.dart` greifen den Painter einer Nachtzeile
/// über die Reihenfolge der [CustomPaint]-Nachfahren ab, und ein weiterer
/// davor verschöbe sie alle.
class _Nachtraster extends StatelessWidget {
  const _Nachtraster();

  @override
  Widget build(BuildContext context) {
    final spur = CupertinoDynamicColor.resolve(Palette.line, context);

    return LayoutBuilder(
      builder: (context, grenzen) => Stack(
        children: [
          for (final stunde in schlafNaechteRasterstunden)
            Positioned(
              left: grenzen.maxWidth * _nachtAnteilDerStunde(stunde),
              top: 0,
              bottom: 0,
              width: 1,
              child: ColoredBox(color: spur),
            ),
        ],
      ),
    );
  }
}

/// Die Uhrzeiten unter dem Raster — dieselben Stunden, dieselben Stellen.
class _Nachtachse extends StatelessWidget {
  const _Nachtachse();

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);

    return SizedBox(
      height: 14,
      child: LayoutBuilder(
        builder: (context, grenzen) => Stack(
          // Die erste Beschriftung steht am linken Rand und ragt um ihre
          // halbe Breite in die Namensspalte — so wie im Entwurf, wo sie
          // mit `text-anchor="middle"` über `LABEL` sitzt.
          clipBehavior: Clip.none,
          children: [
            for (final stunde in schlafNaechteRasterstunden)
              Positioned(
                left:
                    grenzen.maxWidth * _nachtAnteilDerStunde(stunde) -
                    _nachtAchseBreite / 2,
                top: 1,
                width: _nachtAchseBreite,
                child: Text(
                  stunde.toString().padLeft(2, '0'),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: TextStyle(fontSize: 10, color: muted),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

const double _nachtAchseBreite = 24;

/// Die Legende der Schlafphasen — `stageLegend()` im Entwurf.
///
/// Namen, Farben und Reihenfolge kommen aus [SchlafPhasen]; die Legende
/// führt keine eigene Liste.
class _Phasenlegende extends StatelessWidget {
  const _Phasenlegende();

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);

    return Wrap(
      spacing: 14,
      runSpacing: 4,
      children: [
        for (final phase in SchlafPhasen.reihenfolge)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: CupertinoDynamicColor.resolve(
                    SchlafPhasen.farbe(phase),
                    context,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 5),
              Text(
                SchlafPhasen.name(phase),
                style: TextStyle(fontSize: 11, color: muted),
              ),
            ],
          ),
      ],
    );
  }
}

/// Eine Nacht als Balken auf der Nachtuhr, in Phasenfarben gestapelt.
///
/// **Die Abschnitte sind Summen je Phase, keine zeitliche Folge** — so wie
/// `nightsChart` im Entwurf. Die zeitliche Folge zeigt das Hypnogramm
/// darüber; hier geht es um Lage, Länge und Zusammensetzung.
class _NachtBalkenPainter extends CustomPainter {
  _NachtBalkenPainter({
    required this.lage,
    required this.farben,
    required this.spur,
  });

  final SchlafNachtLage lage;

  /// Die **aufgelöste** Farbe je Phase, aus `SchlafPhasen.farbe`.
  final Map<SleepStage, Color> farben;

  final Color spur;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0) return;
    final radius = Radius.circular(size.height / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, radius),
      Paint()..color = spur,
    );

    // Die Achse ist die Nachtuhr: 0 ist 21:00, 1 ist 10:00 des Folgetags
    // ([schlafNaechteAnteil]). Dieselbe Skala, auf der das Raster und die
    // Uhrzeiten darunter sitzen — zwei Rechnungen liefen auseinander.
    final links = size.width * schlafNaechteAnteil(lage.von);
    final rechts = size.width * schlafNaechteAnteil(lage.bis);
    if (rechts <= links) return;

    // Gezeichnet wird in der Spurreihenfolge von `SchlafPhasen`: wach,
    // REM, Kern, Tief — dieselbe, in der die Legende darunter steht.
    // Unspezifizierter Schlaf liegt bei Kern, weil seine Spur die Kernspur
    // ist; die zweite Stelle des Schlüssels hält die Reihenfolge fest,
    // wenn beide in derselben Nacht vorkommen.
    final abschnitte =
        [
          for (final eintrag in lage.minutenJePhase.entries)
            if (eintrag.value > 0) eintrag,
        ]..sort((a, b) {
          final spurA = SchlafPhasen.spurIndex(a.key);
          final spurB = SchlafPhasen.spurIndex(b.key);
          return spurA != spurB
              ? spurA.compareTo(spurB)
              : a.key.index.compareTo(b.key.index);
        });

    var gesamt = 0.0;
    for (final abschnitt in abschnitte) {
      gesamt += abschnitt.value;
    }
    // Keine gemessene Minute: Der Balken bliebe eine Behauptung ohne
    // Inhalt, also bleibt die blasse Spur allein stehen.
    if (gesamt <= 0) return;

    // Beschnitten wird die ganze Kapsel, nicht jeder Abschnitt gerundet —
    // gerundete Abschnitte ließen zwischen zwei Phasen helle Kerben
    // stehen (`CLAUDE.md`, „Farbige Kanten … mit der Karte beschnitten").
    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(links, 0, rechts, size.height),
        radius,
      ),
    );
    var x = links;
    for (final abschnitt in abschnitte) {
      final breite = (rechts - links) * (abschnitt.value / gesamt);
      canvas.drawRect(
        Rect.fromLTRB(x, 0, x + breite, size.height),
        Paint()..color = farben[abschnitt.key] ?? spur,
      );
      x += breite;
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_NachtBalkenPainter alt) =>
      alt.lage != lage || !mapEquals(alt.farben, farben) || alt.spur != spur;
}
