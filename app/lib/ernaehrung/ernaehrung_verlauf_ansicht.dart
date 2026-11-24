// Der aufgeklappte Verlauf (#312): Diagramm über vierzehn Tage und die
// Siebentagezeile, nach `docs/screens/screens/ernaehrung.js`
// (`VERLAUF_DIAGRAMM`). Daten aus `ernaehrung_verlauf.dart`.
//
// **Ein eigenes, kleines Diagramm statt `Zeitdiagramm`.** Das gemeinsame
// Bauteil trägt eine Reihe und waagerechte Linien; hier sind es drei Spuren
// über dieselben Tage — Balken (gegessen), Linie (Verbrauch) und ein Ziel,
// das von Tag zu Tag ein anderes sein kann. Ohne Zeitraumwahl und ohne
// Blättern: Der Verlauf hat genau ein Fenster, das der offene Tag beendet.
//
// **Das Halten dagegen ist dasselbe** (#378): Langes Drücken wählt einen
// Tag, der Kopf zeigt dann Datum, gegessen, Verbrauch und Ziel, und das
// Bild markiert den Tag wie im `Zeitdiagramm` — Kopf, Platzrechnung und
// Markierung kommen aus `design/diagramm_auswahl.dart`. Vorher ließ sich
// hier gar nichts ablesen.
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/diagramm_auswahl.dart';
import '../design/formatierung.dart';
import '../design/palette.dart';
import '../design/platzhalter.dart';
import '../design/typografie.dart';
import '../design/zahlen.dart';
import '../health/health_types.dart';
import 'ernaehrung_verlauf.dart';

/// Höhe der Zeichenfläche — `.chart { height: 148px }` wie im Bauteil.
const double _graphHoehe = 148;

/// Der Hinweis in der Kopfzeile des eingeklappten Abschnitts: „Ø 1.845
/// kcal · 14 Tage", ohne Mittel nur „14 Tage".
String verlaufHinweis(ErnaehrungsVerlauf verlauf) {
  final schnitt = verlauf.durchschnittKcal;
  return schnitt == null
      ? '$verlaufTage Tage'
      : 'Ø ${formatNumber(schnitt)} kcal · $verlaufTage Tage';
}

/// Der Inhalt von „Verlauf" — gebaut erst beim Aufklappen.
class ErnaehrungVerlaufInhalt extends ConsumerWidget {
  const ErnaehrungVerlaufInhalt({super.key, required this.bis});

  /// Der letzte Tag des Fensters — der offene Tag des Schirms.
  final String bis;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final verlauf = ref.watch(ernaehrungsVerlaufProvider(bis));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _Diagramm(
          key: const Key('ernaehrung-verlauf-diagramm'),
          verlauf: verlauf,
        ),
        const SizedBox(height: 12),
        _SiebenTageZeile(
          key: const Key('ernaehrung-verlauf-sieben-tage'),
          verlauf: verlauf,
        ),
      ],
    );
  }
}

/// Kopf, Zeichenfläche, Achse, Legende, Fußnote — **in jedem Zustand
/// dieselbe Höhe**: Jede Zeile ist einzeilig, und die Zeichenfläche ist
/// fest. Ohne Werte steht dieselbe Fläche mit Raster da, nicht nichts —
/// und beim Halten tritt der Tag an die Stelle des Durchschnitts.
class _Diagramm extends StatefulWidget {
  const _Diagramm({super.key, required this.verlauf});

  final ErnaehrungsVerlauf verlauf;

  @override
  State<_Diagramm> createState() => _DiagrammState();
}

class _DiagrammState extends State<_Diagramm> {
  /// Der gehaltene Tag als Index in `verlauf.tage`, `null` ohne Auswahl.
  int? _auswahl;

  final GlobalKey _graphKey = GlobalKey();

  void _waehle(double dx) {
    final box = _graphKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final tage = widget.verlauf.tage.length;
    final platz = platzUnterFinger(
      dx: dx,
      breite: box.size.width,
      gezeichnet: tage,
      plaetze: tage,
    );
    if (platz == null || platz == _auswahl) return;
    setState(() => _auswahl = platz);
  }

  void _loslassen() {
    if (_auswahl == null) return;
    setState(() => _auswahl = null);
  }

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final line = CupertinoDynamicColor.resolve(Palette.line, context);
    final bib = CupertinoDynamicColor.resolve(Palette.bib, context);
    final iron = CupertinoDynamicColor.resolve(Palette.iron, context);
    final ok = CupertinoDynamicColor.resolve(Palette.ok, context);
    final river = CupertinoDynamicColor.resolve(Palette.river, context);
    final surface = CupertinoDynamicColor.resolve(Palette.surface, context);

    final verlauf = widget.verlauf;
    final tage = verlauf.tage;
    final schnitt = verlauf.durchschnittKcal;
    final auswahl = _auswahl;
    final gehalten = auswahl == null || auswahl >= tage.length
        ? null
        : tage[auswahl];

    final vorlesen = StringBuffer('Verlauf über $verlaufTage Tage, ')
      ..write(
        schnitt == null
            ? (verlauf.laedt ? 'wird gelesen' : 'keine Einträge')
            : 'im Durchschnitt ${formatNumber(schnitt)} Kilokalorien '
                  'gegessen',
      );

    final DiagrammKopf kopf;
    if (gehalten == null) {
      kopf = DiagrammKopf(
        ueberschrift: 'Durchschnitt',
        wert: schnitt == null ? ohneWert : formatNumber(schnitt),
        // Wo keine Zahl steht, steht auch keine Einheit.
        einheit: schnitt == null ? '' : 'kcal',
        unterzeile:
            '${Format.tagMonat(_kalendertag(tage.first.tag))}–'
            '${Format.tagMonat(_kalendertag(tage.last.tag))}',
        abgelesen: false,
      );
    } else {
      final gegessen = gehalten.gegessenKcal;
      kopf = DiagrammKopf(
        ueberschrift: Format.wochentagUndDatum(_kalendertag(gehalten.tag)),
        // Ein Tag ohne Eintrag ist `–/–`, keine 0 — „nichts eingetragen"
        // ist keine Aussage über das Essen.
        wert: gegessen == null ? ohneWert : formatNumber(gegessen),
        einheit: gegessen == null ? '' : 'kcal',
        unterzeile:
            'Verbraucht ${_kcal(gehalten.verbrauchKcal)} · '
            'Ziel ${_kcal(gehalten.zielKcal)}',
        abgelesen: true,
      );
    }

    return Semantics(
      container: true,
      label: vorlesen.toString(),
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            key: const Key('ernaehrung-verlauf-kopfzeile'),
            // Der Abstand zum Graphen gehört in den Kopf, wie im
            // `Zeitdiagramm`: Luft dazwischen wäre eine Fläche, auf der das
            // Halten ins Leere griffe.
            padding: const EdgeInsets.only(bottom: 10),
            child: kopf,
          ),
          SizedBox(
            key: _graphKey,
            height: _graphHoehe,
            child: GestureDetector(
              key: const Key('ernaehrung-verlauf-graph'),
              behavior: HitTestBehavior.opaque,
              onLongPressStart: (einzelheiten) =>
                  _waehle(einzelheiten.localPosition.dx),
              onLongPressMoveUpdate: (einzelheiten) =>
                  _waehle(einzelheiten.localPosition.dx),
              onLongPressEnd: (_) => _loslassen(),
              onLongPressCancel: _loslassen,
              child: CustomPaint(
                painter: _VerlaufZeichnung(
                  tage: tage,
                  auswahl: gehalten == null ? null : auswahl,
                  raster: line,
                  balken: bib,
                  linie: iron,
                  ziel: ok,
                  markierung: river,
                  flaeche: surface,
                ),
                size: Size.infinite,
              ),
            ),
          ),
          const SizedBox(height: 4),
          _Achse(
            tage: tage,
            auswahl: gehalten == null ? null : auswahl,
            farbe: muted,
            markierung: river,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _Legende(farbe: bib, text: 'Gegessen', form: _Form.balken),
              const SizedBox(width: 14),
              _Legende(farbe: iron, text: 'Verbraucht', form: _Form.linie),
              const SizedBox(width: 14),
              _Legende(farbe: ok, text: 'Ziel', form: _Form.strich),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Verbrauch aus Apple Health, gegessen aus deinen Einträgen.',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: muted),
          ),
        ],
      ),
    );
  }
}

/// „2.080 kcal" oder `–/–` — nie eine 0 für einen Wert, den es nicht gibt.
String _kcal(double? wert) =>
    wert == null ? ohneWert : '${formatNumber(wert)} kcal';

/// „Letzte 7 Tage: Ziel an X von Y Tagen getroffen, Ø ±Z kcal".
///
/// **Ohne beurteilbaren Tag gibt es keine Quote** — „0 von 0" behauptete
/// eine. Dann steht `–/–` und einmal der Grund; während die Summen noch
/// gelesen werden, kein Grund.
class _SiebenTageZeile extends StatelessWidget {
  const _SiebenTageZeile({super.key, required this.verlauf});

  final ErnaehrungsVerlauf verlauf;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final sieben = verlauf.siebenTage;
    final abweichung = sieben.mittlereAbweichungKcal;

    final String? wert;
    final String hinweis;
    if (sieben.tageMitWerten == 0) {
      wert = null;
      hinweis = verlauf.laedt ? '' : 'noch kein Tag mit Einträgen';
    } else {
      wert =
          'Ziel an ${sieben.getroffen} von ${sieben.tageMitWerten} Tagen '
          'getroffen';
      hinweis = abweichung == null ? '' : 'Ø ${_mitVorzeichen(abweichung)}';
    }

    final vorlesen = [
      'Letzte 7 Tage',
      ?wert,
      if (hinweis.isNotEmpty)
        hinweis.replaceFirst('Ø', 'im Mittel')
      else if (wert == null)
        'kein Wert',
    ].join(', ');

    // **Zwei Zeilen, in jedem Zustand:** Oben die Überschrift, darunter
    // Quote und Mittel. In einer Zeile neben „Letzte 7 Tage" lief die
    // Quote auf dem Telefon in eine Auslassung („Ziel an 4 von 7 Tagen
    // get…").
    return Semantics(
      container: true,
      label: vorlesen,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Letzte 7 Tage', style: TextStyle(fontSize: 13, color: muted)),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  wert ?? ohneWert,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Typografie.tabularNumbers(
                    TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: ink,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(hinweis, style: TextStyle(fontSize: 12, color: muted)),
            ],
          ),
        ],
      ),
    );
  }
}

/// „+210 kcal", „−85 kcal", „±0 kcal" — das Vorzeichen sagt, ob
/// systematisch darüber oder darunter gegessen wurde.
String _mitVorzeichen(double kcal) {
  final gerundet = kcal.round();
  final zeichen = gerundet > 0 ? '+' : (gerundet < 0 ? '−' : '±');
  return '$zeichen${formatNumber(gerundet.abs().toDouble())} kcal';
}

/// Die Tagesbeschriftung: jeder vierte Tag, vom ältesten aus, wie im
/// Entwurf.
///
/// Die Beschriftung des gehaltenen Tages steht in Flussblau, wie im
/// `Zeitdiagramm` — trägt er keine, bleibt es beim Lot.
class _Achse extends StatelessWidget {
  const _Achse({
    required this.tage,
    required this.auswahl,
    required this.farbe,
    required this.markierung,
  });

  final List<VerlaufTag> tage;
  final int? auswahl;
  final Color farbe;
  final Color markierung;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < tage.length; i++)
          Expanded(
            child: Text(
              i % 4 == 0 ? Format.tagMonat(_kalendertag(tage[i].tag)) : '',
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
              style: TextStyle(
                fontSize: 10.5,
                color: i == auswahl ? markierung : farbe,
              ),
            ),
          ),
      ],
    );
  }
}

enum _Form { balken, linie, strich }

class _Legende extends StatelessWidget {
  const _Legende({required this.farbe, required this.text, required this.form});

  final Color farbe;
  final String text;
  final _Form form;

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final zeichen = switch (form) {
      _Form.balken => Container(
        width: 8,
        height: 10,
        decoration: BoxDecoration(
          color: farbe,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      _Form.linie => Container(width: 12, height: 2, color: farbe),
      _Form.strich => Container(width: 10, height: 3, color: farbe),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        zeichen,
        const SizedBox(width: 5),
        Text(text, style: TextStyle(fontSize: 12, color: muted)),
      ],
    );
  }
}

/// Balken für das Gegessene, eine Linie für den Verbrauch und je Tag ein
/// Strich auf Zielhöhe. **Die Null liegt immer unten** — die Länge eines
/// Balkens ist seine Aussage. Ein Tag ohne Wert bleibt leer; die Linie
/// reißt dort ab, statt eine Messung zu erfinden.
///
/// Der gehaltene Tag ([auswahl]) wird markiert wie im `Zeitdiagramm`: Lot
/// in Flussblau, sein Balken voll, die übrigen bei 85 %, sein Punkt auf
/// der Verbrauchslinie groß mit Ring.
class _VerlaufZeichnung extends CustomPainter {
  _VerlaufZeichnung({
    required this.tage,
    required this.auswahl,
    required this.raster,
    required this.balken,
    required this.linie,
    required this.ziel,
    required this.markierung,
    required this.flaeche,
  });

  final List<VerlaufTag> tage;
  final int? auswahl;
  final Color raster;
  final Color balken;
  final Color linie;
  final Color ziel;
  final Color markierung;
  final Color flaeche;

  @override
  void paint(Canvas canvas, Size size) {
    final werte = [
      for (final t in tage) ...[t.gegessenKcal, t.verbrauchKcal, t.zielKcal],
    ].whereType<double>();
    final hoechster = werte.isEmpty ? 0.0 : werte.reduce(math.max);
    // Ohne Werte trotzdem ein Raster in derselben Lage.
    final oben = hoechster <= 0 ? 1.0 : hoechster * 1.1;

    double y(double wert) => size.height - wert / oben * size.height;

    final rasterStift = Paint()
      ..color = raster
      ..strokeWidth = 1;
    for (final anteil in const [0.0, 0.5, 1.0]) {
      final hoehe = size.height * anteil;
      canvas.drawLine(Offset(0, hoehe), Offset(size.width, hoehe), rasterStift);
    }

    final platz = size.width / tage.length;
    final zielStift = Paint()
      ..color = ziel
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final linienStift = Paint()
      ..color = linie
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    final punktStift = Paint()..color = linie;

    Path? pfad;
    Offset? einzeln;
    void schliesse() {
      if (pfad != null) canvas.drawPath(pfad!, linienStift);
      if (einzeln != null) canvas.drawCircle(einzeln!, 2.5, punktStift);
      pfad = null;
      einzeln = null;
    }

    for (var i = 0; i < tage.length; i++) {
      final t = tage[i];
      final mitte = platz * i + platz / 2;

      final gegessen = t.gegessenKcal;
      if (gegessen != null && gegessen > 0) {
        final breite = platz * 0.58;
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTRB(
              mitte - breite / 2,
              y(gegessen),
              mitte + breite / 2,
              size.height,
            ),
            topLeft: const Radius.circular(2.5),
            topRight: const Radius.circular(2.5),
          ),
          Paint()..color = balkenFarbe(balken, gehalten: i == auswahl),
        );
      }

      final zielKcal = t.zielKcal;
      if (zielKcal != null) {
        final halb = platz * 0.4;
        canvas.drawLine(
          Offset(mitte - halb, y(zielKcal)),
          Offset(mitte + halb, y(zielKcal)),
          zielStift,
        );
      }

      final verbrauch = t.verbrauchKcal;
      if (verbrauch == null) {
        schliesse();
      } else {
        final punkt = Offset(mitte, y(verbrauch));
        if (pfad == null && einzeln == null) {
          einzeln = punkt;
        } else if (pfad == null) {
          pfad = Path()
            ..moveTo(einzeln!.dx, einzeln!.dy)
            ..lineTo(punkt.dx, punkt.dy);
          einzeln = null;
        } else {
          pfad!.lineTo(punkt.dx, punkt.dy);
        }
      }
    }
    schliesse();

    final gewaehlt = auswahl;
    if (gewaehlt != null && gewaehlt < tage.length) {
      final mitte = platz * gewaehlt + platz / 2;
      zeichneAuswahlLot(
        canvas,
        x: mitte,
        oben: 0,
        unten: size.height,
        farbe: markierung,
      );
      final verbrauch = tage[gewaehlt].verbrauchKcal;
      if (verbrauch != null) {
        zeichneAuswahlPunkt(
          canvas,
          Offset(mitte, y(verbrauch)),
          farbe: linie,
          flaeche: flaeche,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_VerlaufZeichnung alt) =>
      alt.tage != tage ||
      alt.auswahl != auswahl ||
      alt.markierung != markierung ||
      alt.flaeche != flaeche ||
      alt.raster != raster ||
      alt.balken != balken ||
      alt.linie != linie ||
      alt.ziel != ziel;
}

/// Der Tagesschlüssel als Kalenderdatum zum **Anzeigen** — über
/// [kalendertag], damit „17.10." auf jedem Gerät 17.10. bleibt.
DateTime _kalendertag(String tag) => kalendertag(datumAusTag(tag));
