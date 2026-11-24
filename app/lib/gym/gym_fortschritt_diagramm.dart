// Die Diagrammkarte des Schirms „Fortschritt pro Übung" (#93).
//
// **Dieselbe Karte in jeder Lage** („Eine Anzeige, die es gibt, hat genau
// eine Form"): Mit zwei Trainingstagen steht ein [Zeitdiagramm] da, sonst die
// **ungefüllte** Karte — dasselbe Gerüst ([ZeitdiagrammGeruest]: Leiste,
// Kopfzeile, Graphfläche, Fußzeile), nur ohne Linie. Beide bauen dieselbe
// Stelle, also haben sie dieselbe Höhe; nur der Satz in der Graphfläche
// unterscheidet sich, und der steht allein dort, wo bekannt ist, dass es
// weniger als zwei Tage gibt — nicht beim Laden, nicht nach einem Fehler
// (beides wären Gründe, die es noch nicht gibt, Fehler `01`).
//
// **Die Linien:** Höchstgewicht durchgezogen, das geschätzte 1RM gestrichelt,
// beide auf einer Skala. Das Diagramm bekommt die **rohen Tageswerte** und
// verdichtet selbst — über das Maximum (`docs/SPEC.md` 4.4, Board-Nr. 18); der
// Schirm verdichtet nicht zusätzlich.
import 'package:flutter/cupertino.dart';
import 'package:trainings_core/trainings_core.dart';

import '../design/diagramm_auswahl.dart' show DiagrammKopf;
import '../design/palette.dart';
import '../design/zeitdiagramm.dart';
import '../design/zeitdiagramm_geruest.dart';
import '../shell/diagramm_zeitraum.dart';
import 'gym_fortschritt_kennwerte.dart';
import 'gym_fortschritt_provider.dart';
import 'gym_fortschritt_schluessel.dart';
import 'gym_fortschritt_texte.dart';

/// Die Karte samt Legende. [onStufe] meldet jede **vom Nutzer** gewählte
/// Stufe, damit die Kacheln dasselbe Ende nennen wie die Linie.
class GymFortschrittDiagramm extends StatelessWidget {
  const GymFortschrittDiagramm({
    super.key,
    required this.stand,
    required this.onStufe,
  });

  final GymFortschritt stand;
  final ValueChanged<DiagrammStufe> onStufe;

  /// Ab wie vielen Trainingstagen eine Linie steht: zwei (Spec 10). Ein
  /// Training ist eine Zahl, keine Entwicklung.
  static const int mindestTage = 2;

  @override
  Widget build(BuildContext context) {
    final uebung = stand.uebung;
    final hatLinie = stand.bekannt && stand.reihe.length >= mindestTage;

    return Padding(
      key: kGymFortschrittDiagramm,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hatLinie)
            Zeitdiagramm(
              // Je Übung ein eigener Zustand: Stufe und Blätterstand der
              // einen gelten nicht für die andere.
              key: ValueKey('gym-fortschritt-diagramm-${uebung.id}'),
              reihe: hoechstReihe(stand.reihe),
              zweiteReihe: einRmReihe(stand.reihe),
              verdichtung: ChartAggregation.max,
              stufen: gymFortschrittStufen,
              anfangsStufe: gymFortschrittStartStufe(stand.reihe),
              onStufe: onStufe,
              alsBalken: false,
              einheit: uebung.isTimed ? 's' : 'kg',
              fussnote: gymFortschrittDiagrammFuss,
            )
          else
            // Der Satz nur, wo gelesen ist und es weniger als zwei Tage gibt.
            _UngefuellteKarte(mitSatz: stand.bekannt, gelesen: !stand.laedt),
          _Legende(besteZeit: uebung.isTimed),
        ],
      ),
    );
  }
}

/// Die Karte **ohne Linie**: dasselbe Gerüst wie das [Zeitdiagramm], die
/// Leiste auf der Startstufe `M` und gesperrt — es gibt nichts zu wählen.
class _UngefuellteKarte extends StatelessWidget {
  const _UngefuellteKarte({required this.mitSatz, required this.gelesen});

  /// Steht der Satz „Noch zu wenige Trainings" in der Graphfläche?
  final bool mitSatz;

  /// `—` in der Kopfzeile (gelesen, nichts zu zeigen) statt eines leeren
  /// Platzes (noch nicht gelesen).
  final bool gelesen;

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final raster = CupertinoDynamicColor.resolve(Palette.line, context);

    return ZeitdiagrammGeruest(
      leiste: IgnorePointer(
        child: Zeitraumleiste(
          stufen: gymFortschrittStufen,
          gewaehlt: DiagrammStufe.monat,
          onWaehle: (_) {},
        ),
      ),
      kopf: DiagrammKopf(
        ueberschrift: 'Höchstwert',
        // Eine geschützte Leerstelle statt eines Zeichens, solange nichts
        // gelesen ist: `—` hieße „gelesen, nichts da", und die Leerstelle
        // hält die Zeilenhöhe der Zahl.
        wert: gelesen ? '—' : ' ',
        einheit: '',
        unterzeile: '',
        abgelesen: false,
      ),
      fussnote: gymFortschrittDiagrammFuss(DiagrammStufe.monat),
      graph: CustomPaint(
        painter: _Raster(raster.withValues(alpha: 0.7)),
        child: mitSatz
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    gymFortschrittDiagrammLeer,
                    key: kGymFortschrittDiagrammLeer,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, height: 1.4, color: muted),
                  ),
                ),
              )
            : null,
      ),
    );
  }
}

/// Die drei Rasterlinien einer Graphfläche — wie im [Zeitdiagramm], nur ohne
/// Linie darauf. Sie sagen „hier kommt ein Diagramm", ohne eines zu
/// behaupten.
class _Raster extends CustomPainter {
  _Raster(this.farbe);

  final Color farbe;

  /// Luft oben und Platz für die Achse unten, wie im Maler des Diagramms.
  static const double _oben = 8, _unten = 20;

  @override
  void paint(Canvas canvas, Size size) {
    final hoehe = size.height - _oben - _unten;
    if (hoehe <= 0) return;
    final stift = Paint()
      ..color = farbe
      ..strokeWidth = 0.5;
    for (final anteil in const [0.0, 0.5, 1.0]) {
      final y = _oben + anteil * hoehe;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), stift);
    }
  }

  @override
  bool shouldRepaint(_Raster alt) => alt.farbe != farbe;
}

/// Die Legende: „Höchstgewicht" durchgezogen, „1RM, geschätzt" gestrichelt.
/// **Das Wort „geschätzt" ist dort die Kennzeichnung**, nicht der Name der
/// Formel (Spec 7). Bei einer Zeitübung gibt es kein 1RM, und die Legende
/// nennt nur die Zeit.
class _Legende extends StatelessWidget {
  const _Legende({required this.besteZeit});

  final bool besteZeit;

  @override
  Widget build(BuildContext context) {
    final river = CupertinoDynamicColor.resolve(Palette.river, context);
    final iron = CupertinoDynamicColor.resolve(Palette.iron, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final stil = TextStyle(fontSize: 12, height: 1.4, color: muted);

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          _Strich(farbe: river, gestrichelt: false),
          const SizedBox(width: 6),
          // `Flexible`: Bei großer Schrift darf ein Eintrag kürzen, statt
          // über den Rand zu laufen.
          Flexible(
            child: Text(
              besteZeit
                  ? gymFortschrittKachelBesteZeit
                  : gymFortschrittKachelHoechst,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: stil,
            ),
          ),
          if (!besteZeit) ...[
            const SizedBox(width: 16),
            _Strich(farbe: iron, gestrichelt: true),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                gymFortschrittLegende1rm,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: stil,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Das Linienstück vor einem Legendeneintrag.
class _Strich extends StatelessWidget {
  const _Strich({required this.farbe, required this.gestrichelt});

  final Color farbe;
  final bool gestrichelt;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 2,
      child: gestrichelt
          ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 0; i < 3; i++)
                  Container(width: 4, height: 2, color: farbe),
              ],
            )
          : ColoredBox(color: farbe),
    );
  }
}
