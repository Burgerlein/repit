// Die Puls- und Atemspannen einer Nacht (#148, #157, #168) — das
// Min-Max-Diagramm des Schlaf-Schirms (#92): schmale Kapseln, zwei
// beschriftete Marken am Balken, eine punktierte Zeitachse und die Spanne
// als Satz darüber. Die Skala und ihr Maler liegen in
// `schlaf_spannen_achse.dart` und werden von hier weiterexportiert.
//
// Eigene Datei, weil das Bauteil für sich steht: Es bekommt eine Liste
// [ValueSpan], eine Farbe und zwei Wörter, kennt weder Nacht noch Score
// und wird vom Schirm zweimal gesetzt — einmal für den Puls, einmal für
// die Atmung.
//
// **`schlaf_abschnitte.dart` exportiert diese Datei weiter.** Die
// festgelegte API bleibt `import '…/shell/schlaf_abschnitte.dart'`.
//
// Herausgelöst am 28.10.2026 für #153. Tim hat „aufteilen" verlangt; wo
// der Schnitt liegt, hat der umsetzende Agent entschieden.
import 'package:flutter/cupertino.dart';
import 'package:trainings_core/trainings_core.dart';

import '../design/palette.dart';
import 'schlaf_spannen_achse.dart';
import 'schlaf_texte.dart';

export 'schlaf_spannen_achse.dart';

/// Min-Max-Spannen über die Zeitabschnitte einer Nacht — **keine Linie**
/// (`docs/SPEC.md` 4.6), verdichtet auf acht Abschnitte (#148).
///
/// Gebaut wurde bis zum 28.10.2026 **jede Einzelmessung** als eigene
/// Kapsel — rund achtzehn nebeneinander, teils zwei Punkt breit. Tim am
/// Gerät: „die sind nicht lesbar. da fehlen auch die Spitzenwerte aus dem
/// Design." Die Verdichtung rechnet seitdem `SpanBuckets` im Kern; hier
/// wird nur gezeichnet.
///
/// **Und seit #168 sieht es aus wie Apple Health.** Tim am 29.10.2026, mit
/// zwei Bildschirmfotos: „Bau das so wie Apple bitte genau so!" Das heißt
/// im Einzelnen:
///
/// - **Keine Werteachse, keine Rasterlinien.** Eine Achse sagt „das Bild
///   reicht von 60 bis 75". Apple sagt „der tiefste Wert war 58, und zwar
///   hier" — und beim Schlafpuls ist genau das die Aussage.
/// - **Genau zwei beschriftete Marken**, am Balken, an dem sie auftreten.
/// - **Die Spanne als Satz** über dem Diagramm statt als Kopfzeile mit
///   Kicker und Zahl.
/// - **Eine Uhrzeit nur an den beiden Enden der Zeitachse.**
///
/// **Die gestrichelte Bezugslinie ist damit weg, und das ist eine
/// Umkehr:** Tim hatte sie am 28.10.2026 ausdrücklich gewollt (#157,
/// „Ruhepuls 68" bzw. „Normal 14,0"); „genau so wie Apple" hebt sie einen
/// Tag später auf. Wer die Git-History liest, findet beides und soll
/// wissen, dass das zweite das erste kennt. Der Vergleich zum eigenen
/// Normalwert steht weiter auf der Erholungsseite in der Zeile „Ruhepuls".
///
/// **Ein Abschnitt ohne Messung bleibt leer** — Tims Entscheidung vom
/// 28.10.2026. Er behält seinen Platz im Raster, damit die Zeitachse nicht
/// verrutscht, bekommt aber keine Kapsel: Ein blasser Strich auf der
/// Grundlinie sähe aus wie ein sehr niedriger Messwert, und eine Lücke
/// soll wie eine Lücke aussehen.
class SchlafSpannenDiagramm extends StatefulWidget {
  const SchlafSpannenDiagramm({
    super.key,
    required this.spannen,
    required this.farbe,
    required this.groesse,
    required this.einheit,
    this.nachkommastellen = 0,
  });

  final List<ValueSpan> spannen;
  final CupertinoDynamicColor farbe;

  /// Die Messgröße im Satz: „dein Puls", „deine Atemfrequenz".
  ///
  /// Im Entwurf heißt der Parameter `was` (`minMaxChart` in
  /// `docs/screens/components.js`). Der Satz entsteht **hier** und nicht
  /// beim Aufrufer, weil nur das Bauteil Tiefst- und Höchstwert kennt —
  /// der Aufrufer gibt die Wörter dazu.
  final String groesse;

  /// Die Einheit **in Worten**: „Schlägen pro Minute", „Atemzügen pro
  /// Minute".
  ///
  /// Nicht „bpm": Der Satz ist ein Satz, und Apple schreibt ihn aus. Die
  /// Kurzform gab es, solange die Spanne als Kicker mit Zahl in einer
  /// Kopfzeile stand; die ist mit #168 weggefallen.
  final String einheit;

  /// Nachkommastellen der **Messwerte**: beim Puls 0, bei der Atemfrequenz 1.
  ///
  /// Die Atemfrequenz schwankt um gut eine Einheit; gerundet verschwindet
  /// genau das Signal, auf das die Ampel schaut (Tims Entscheidung vom
  /// 28.10.2026).
  final int nachkommastellen;

  @override
  State<SchlafSpannenDiagramm> createState() => _SchlafSpannenDiagrammState();
}

class _SchlafSpannenDiagrammState extends State<SchlafSpannenDiagramm> {
  /// Der Abschnitt unter dem Finger — `null`, solange niemand hält.
  int? _auswahl;

  void _waehle(double dx, double abschnittsbreite) {
    if (abschnittsbreite <= 0) return;
    final index = (dx / abschnittsbreite).floor().clamp(
      0,
      widget.spannen.length - 1,
    );
    if (index != _auswahl) setState(() => _auswahl = index);
  }

  void _loslassen() {
    if (_auswahl != null) setState(() => _auswahl = null);
  }

  String _zahl(double wert) => spannenZahl(wert, widget.nachkommastellen);

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);

    // Eine Reihe ganz ohne Messung gibt es nicht als Raster: `SpanBuckets`
    // liefert dann eine leere Liste, und ein vollständiges leeres Raster
    // behauptete eine Nacht mit Abschnitten, die zufällig alle fehlen.
    final spitzen = spannenSpitzen(widget.spannen);
    if (spitzen == null) {
      return Text(
        schlafOhneDaten,
        style: TextStyle(fontSize: 12, color: muted),
      );
    }

    final tiefster = widget.spannen[spitzen.tiefster].min!;
    final hoechster = widget.spannen[spitzen.hoechster].max!;
    final grenzen = spannenAchsenGrenzen(
      tiefster: tiefster,
      hoechster: hoechster,
    );

    double y(double wert) =>
        spannenLuftOben +
        (1 - (wert - grenzen.von) / (grenzen.bis - grenzen.von)) *
            (spannenBildhoehe - spannenLuftOben - spannenLuftUnten);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Satz(text: _satz(tiefster, hoechster), abgelesen: _auswahl != null),
        SizedBox(
          key: const Key('schlaf-spannen-bild'),
          height: spannenBildhoehe,
          child: LayoutBuilder(
            builder: (context, platz) {
              final breite = platz.maxWidth / widget.spannen.length;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onLongPressStart: (einzelheiten) =>
                    _waehle(einzelheiten.localPosition.dx, breite),
                onLongPressMoveUpdate: (einzelheiten) =>
                    _waehle(einzelheiten.localPosition.dx, breite),
                onLongPressEnd: (_) => _loslassen(),
                onLongPressCancel: _loslassen,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: SpannenPainter(
                          spannen: widget.spannen,
                          farbe: CupertinoDynamicColor.resolve(
                            widget.farbe,
                            context,
                          ),
                          flaechenFarbe: CupertinoDynamicColor.resolve(
                            Palette.surface,
                            context,
                          ),
                          achsenFarbe: CupertinoDynamicColor.resolve(
                            Palette.line,
                            context,
                          ),
                          lotFarbe: CupertinoDynamicColor.resolve(
                            Palette.river,
                            context,
                          ),
                          muedeFarbe: muted,
                          von: grenzen.von,
                          bis: grenzen.bis,
                          auswahl: _auswahl,
                        ),
                      ),
                    ),
                    _Marke(
                      schluessel: const Key('schlaf-spannen-max'),
                      wort: 'MAX.',
                      wert: _zahl(hoechster),
                      farbe: widget.farbe,
                      mitte: (spitzen.hoechster + 0.5) * breite,
                      platz: platz.maxWidth,
                      // Über dem Kreis: Die Unterkante des Blocks liegt
                      // vier Punkt über dem höchsten Messwert.
                      oberkante: y(hoechster) - 4 - _Marke.hoehe,
                    ),
                    _Marke(
                      schluessel: const Key('schlaf-spannen-min'),
                      wort: 'MIN.',
                      wert: _zahl(tiefster),
                      farbe: widget.farbe,
                      mitte: (spitzen.tiefster + 0.5) * breite,
                      platz: platz.maxWidth,
                      oberkante: y(tiefster) + 4,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        _Zeitachse(spannen: widget.spannen),
        const SizedBox(height: 6),
        Text(
          key: const Key('schlaf-spannen-fuss'),
          _fusstext(),
          style: TextStyle(fontSize: 12, color: muted),
        ),
      ],
    );
  }

  /// Der Satz über dem Diagramm.
  ///
  /// Ohne Berührung spricht er von der ganzen Nacht, beim Halten vom
  /// gehaltenen Abschnitt — und über einer Lücke sagt er, dass keine
  /// Messung vorliegt, nie den Nachbarwert.
  String _satz(double tiefster, double hoechster) {
    final index = _auswahl;
    if (index == null) {
      return 'Während du geschlafen hast, lag ${widget.groesse} bei '
          '${_zahl(tiefster)} bis ${_zahl(hoechster)} ${widget.einheit}.';
    }
    final abschnitt = widget.spannen[index];
    // Das Ende des Abschnitts steht im Abschnitt selbst — hinter dem
    // letzten gibt es keinen nächsten, aus dem man es nehmen könnte.
    final von = schlafZeitText(abschnitt.start);
    final bis = schlafZeitText(abschnitt.end);
    final tief = abschnitt.min, hoch = abschnitt.max;
    if (tief == null || hoch == null) {
      return 'Von $von bis $bis liegt keine Messung vor.';
    }
    return 'Von $von bis $bis lag ${widget.groesse} bei ${_zahl(tief)} bis '
        '${_zahl(hoch)} ${widget.einheit}.';
  }

  /// „Je Abschnitt 56 min".
  ///
  /// Ohne sie liest man acht Kapseln als acht Messungen; tatsächlich steckt
  /// in jeder knapp eine Stunde. **Anfang und Ende der Nacht stehen seit
  /// #168 nicht mehr hier**, sondern an den Enden der Zeitachse — zweimal
  /// dieselbe Uhrzeit ist das nächste Paar, das auseinanderläuft.
  String _fusstext() {
    final von = widget.spannen.first.start;
    final bis = widget.spannen.last.end;
    final jeAbschnitt =
        bis.difference(von).inSeconds / widget.spannen.length / 60;
    return 'Je Abschnitt ${jeAbschnitt.round()} min';
  }
}

// ───────────────────────────────────────────────────────────────────────
// Satz, Marken, Zeitachse
// ───────────────────────────────────────────────────────────────────────

/// Der Satz über dem Diagramm — bei Apple die ganze Legende.
///
/// **Sein Platz ist auf zwei Zeilen festgelegt.** Beim Ablesen wechselt
/// nur sein Inhalt und seine Farbe; der Satz über einer Lücke ist kürzer
/// als der über der Nacht, und ohne festen Platz zöge er sich auf eine
/// Zeile zusammen und ließe alles darunter springen. Genau die Zeile, die
/// beim Halten erscheint und wieder verschwindet, hat Tim am 28.10.2026
/// streichen lassen (#146).
class _Satz extends StatelessWidget {
  const _Satz({required this.text, required this.abgelesen});

  final String text;
  final bool abgelesen;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final river = CupertinoDynamicColor.resolve(Palette.river, context);
    final stil = TextStyle(
      fontSize: 14,
      height: 1.35,
      color: abgelesen ? river : ink,
    );

    // **Die zwei Zeilen werden gemessen, nicht gerechnet.** `fontSize *
    // height * 2` liegt je nach Schrift um Bruchteile daneben — im Test
    // 37,8 gegen tatsächliche 38,0 —, und dann sprünge der Satz doch. Um
    // zwei Zehntel, aber er sprünge. Gemessen wird mit derselben
    // Maschine, die ihn gleich setzt, also stimmt es auf jedem Gerät und
    // bei jeder Schriftgröße.
    final zweiZeilen = (TextPainter(
      text: TextSpan(text: '\n', style: stil),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout()).height;

    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      // **Kein `Align` dazwischen.** Mit ihm schrumpfte der Satz auf seinen
      // Inhalt, und der Platz wäre nur noch im Kasten darum reserviert —
      // im Entwurf ist `.mmsatz` ein Block über die ganze Breite mit
      // `min-height`, und genau das ist hier die weite Breite plus die
      // Mindesthöhe.
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: zweiZeilen),
        child: Text(key: const Key('schlaf-spannen-satz'), text, style: stil),
      ),
    );
  }
}

/// `MAX.` oder `MIN.` mit dem Wert darunter — zweizeilig gestapelt, in der
/// Farbe der Reihe.
///
/// So steht es in Tims Bildschirmfotos: oben das Wort, klein und gesperrt,
/// darunter der deutlich größere Wert. Gelesen wird die Zahl; das Wort
/// sagt nur, welche es ist.
///
/// **Der Kasten ist fest breit und wird am Rand hereingeschoben.** Die
/// Schrift darf wandern, der Kreis darunter bleibt stehen — er ist die
/// genaue Stelle. Ohne das Hereinschieben stieße die Beschriftung eines
/// Randabschnitts aus dem Bild.
class _Marke extends StatelessWidget {
  const _Marke({
    required this.schluessel,
    required this.wort,
    required this.wert,
    required this.farbe,
    required this.mitte,
    required this.platz,
    required this.oberkante,
  });

  final Key schluessel;
  final String wort;
  final String wert;
  final CupertinoDynamicColor farbe;

  /// Die Mitte des Abschnitts, auf dem die Marke sitzt.
  final double mitte;

  /// Die Breite der Zeichenfläche — die Grenze, an der geschoben wird.
  final double platz;
  final double oberkante;

  /// Breit genug für „15,2" in der Zahlenschrift, schmal genug, dass die
  /// Marke eines Randabschnitts nur um wenige Punkt wandert.
  static const double breite = 44;

  /// Eine Zeile Wort (8 Punkt) und eine Zeile Wert (12 Punkt), beide mit
  /// etwas Durchschuss.
  static const double hoehe = 25;

  @override
  Widget build(BuildContext context) {
    final ton = CupertinoDynamicColor.resolve(farbe, context);
    return Positioned(
      key: schluessel,
      left: (mitte - breite / 2).clamp(0.0, (platz - breite).clamp(0.0, platz)),
      top: oberkante,
      width: breite,
      height: hoehe,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            wort,
            softWrap: false,
            overflow: TextOverflow.visible,
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: ton,
            ),
          ),
          Text(
            wert,
            softWrap: false,
            overflow: TextOverflow.visible,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: ton,
            ),
          ),
        ],
      ),
    );
  }
}

/// Die Zeitachse unter den Kapseln — **nur die beiden Enden** tragen eine
/// Uhrzeit (#168).
///
/// Links der Beginn des ersten Abschnitts, rechts das Ende der Nacht. Bis
/// zum 28.10.2026 trug jeder zweite Abschnitt seine Uhrzeit; Apple setzt
/// nur die Enden, und die feinen Striche an den Abschnittsgrenzen (im
/// Maler) tragen, was die Beschriftungen getragen haben: dass hier acht
/// Abschnitte stehen.
///
/// Beschriftet wird die Berliner Wanduhr — krumm, wenn die Nacht krumm
/// beginnt: Eine Nacht fängt nicht auf der halben Stunde an, und eine
/// gerundete Uhrzeit zeigte auf einen Zeitpunkt, der keine
/// Abschnittsgrenze ist.
class _Zeitachse extends StatelessWidget {
  const _Zeitachse({required this.spannen});

  final List<ValueSpan> spannen;

  @override
  Widget build(BuildContext context) {
    final stil = TextStyle(
      fontSize: 10,
      color: CupertinoDynamicColor.resolve(Palette.muted, context),
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(schlafZeitText(spannen.first.start), style: stil),
        Text(schlafZeitText(spannen.last.end), style: stil),
      ],
    );
  }
}
