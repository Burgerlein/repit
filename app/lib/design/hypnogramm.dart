/// Die Nacht als vier Spuren — Zustand, Kopfzeile und Geste.
///
/// Die dritte von drei Dateien: Die Rechnung steht in
/// `hypnogramm_lage.dart`, die Striche in `hypnogramm_zeichnung.dart`,
/// beide werden von hier wiederausgegeben. **Die festgelegte Adresse ist
/// `import '…/design/hypnogramm.dart'`** — wer das Bauteil benutzt, muss
/// nicht wissen, wie es innen geschnitten ist.
///
/// Dart-Entsprechung von `HypnogramChart` in
/// `Sources/Features/Recovery/NightCharts.swift` und von `hypnogram()` in
/// `docs/screens/components.js`.
///
/// ## Dreimal gebraucht, und nur einmal ablesbar
///
/// | Ort | `kompakt` | `ablesbar` |
/// |---|---|---|
/// | Nachtkarte auf *Erholung* | ja | nein |
/// | Tagschlaf-Schirm | nein | nein |
/// | Schlaf-Schirm | nein | **ja** |
///
/// Kompakt bleiben die vier Spurnamen weg, die dort nur Platz kosten
/// (27.10.2026). Uhrzeitachse, Kopfzeile und Ablesen gibt es **nur** auf
/// dem Schlaf-Schirm: Auf dem Tagschlaf-Schirm führt die Karte darüber
/// schon „1× wach, 4 min", und zwei Stellen mit derselben Zahl laufen
/// auseinander. Das ist eine Entscheidung des Entwurfsagenten vom
/// 28.10.2026, keine dieses Bauteils.
library;

import 'package:flutter/cupertino.dart';

import '../health/health_types.dart';
import 'formatierung.dart';
import 'hypnogramm_lage.dart';
import 'hypnogramm_zeichnung.dart';
import 'palette.dart';

export 'hypnogramm_lage.dart';
export 'hypnogramm_zeichnung.dart';

/// Breite der Spurnamen in voller Fassung — `labelWidth` aus
/// `NightCharts.swift`.
const double _namenBreite = 44;

/// Höhe der Uhrzeitachse unter dem Bild — `AXIS` im Entwurf.
const double _achsenhoehe = 17;

/// Die Nacht als vier Spuren.
class Hypnogramm extends StatefulWidget {
  const Hypnogramm({
    super.key,
    required this.session,
    this.kompakt = true,
    this.ablesbar = false,
  });

  final SleepSession session;

  /// Ohne Spurnamen, halbe Höhe — die Fassung für die Nachtkarte.
  final bool kompakt;

  /// Uhrzeitachse, Kopfzeile und Ablesen durch Halten.
  ///
  /// **Die drei gehören zusammen.** Ohne Achse lässt sich nichts ablesen,
  /// also braucht es auch keinen festen Platz für das Abgelesene; und eine
  /// Kopfzeile, die beim Halten erst erscheint, ließe alles darunter
  /// springen (#146) — deshalb steht sie in beiden Zuständen da und
  /// wechselt nur ihren Inhalt.
  final bool ablesbar;

  @override
  State<Hypnogramm> createState() => _HypnogrammState();
}

class _HypnogrammState extends State<Hypnogramm> {
  /// Fenster, Einträge und Lücken — **gehalten, nicht je Bild gerechnet**
  /// (`CLAUDE.md`, Regel 2). Beim Halten läuft je Fingerbewegung ein
  /// Treffertest über alle Einträge; liefe darin die ganze Nacht neu
  /// durch, wäre das `03` im neuen Code.
  late HypnogrammGeometrie _geometrie;

  /// Der abgelesene Eintrag, `null` in Ruhe.
  int? _auswahl;

  final GlobalKey _bildKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _geometrie = HypnogrammGeometrie(widget.session);
  }

  @override
  void didUpdateWidget(covariant Hypnogramm alt) {
    super.didUpdateWidget(alt);
    // `SleepSession` trägt kein `==`; eine neue Nacht ist eine neue
    // Instanz. Ein abgelesener Abschnitt der alten Nacht hat in der neuen
    // keine Entsprechung und fällt deshalb weg.
    if (!identical(alt.session, widget.session)) {
      _geometrie = HypnogrammGeometrie(widget.session);
      _auswahl = null;
    }
  }

  double get _spurhoehe => widget.kompakt ? 26 : 40;

  // ── Geste ───────────────────────────────────────────────────────────────

  void _waehle(double dx) {
    final kasten = _bildKey.currentContext?.findRenderObject() as RenderBox?;
    if (kasten == null || !kasten.hasSize || kasten.size.width <= 0) return;
    final treffer = _geometrie.trefferBei(dx, kasten.size.width);
    if (treffer == _auswahl) return;
    setState(() => _auswahl = treffer);
  }

  void _loslassen() {
    if (_auswahl == null) return;
    setState(() => _auswahl = null);
  }

  // ── Kopfzeile ───────────────────────────────────────────────────────────

  /// Was über dem Bild steht: in Ruhe die Wachphasen der Nacht, beim
  /// Ablesen Zeitspanne, Phase und Dauer des gehaltenen Abschnitts.
  ///
  /// **Über einer Messlücke steht „keine Messung", nie der Nachbarwert** —
  /// dieselbe Regel, die `Zeitdiagramm` schon trägt.
  ({String links, String rechts, bool abgelesen}) _kopf() {
    final gewaehlt = _auswahl;
    if (gewaehlt != null && gewaehlt < _geometrie.eintraege.length) {
      final eintrag = _geometrie.eintraege[gewaehlt];
      final phase = eintrag.phase;
      return (
        links:
            '${Format.uhrzeit(eintrag.von)} – ${Format.uhrzeit(eintrag.bis)}',
        rechts: phase == null
            ? 'keine Messung'
            : '${SchlafPhasen.name(phase)} · ${_dauerText(eintrag.dauer)}',
        abgelesen: true,
      );
    }
    final wach = _geometrie.eintraege
        .where((eintrag) => eintrag.phase == SleepStage.awake)
        .toList();
    final dauer = wach.fold(
      Duration.zero,
      (summe, eintrag) => summe + eintrag.dauer,
    );
    return (
      links: 'WACH',
      rechts: '${wach.length}× · ${_dauerText(dauer)}',
      abgelesen: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);

    // Apple verrät den Lesestatus nicht: „nichts aufgezeichnet" und „nicht
    // freigegeben" sind von außen nicht zu unterscheiden. Beides wird
    // benannt — und zwar statt eines leeren Rahmens, der wie eine
    // schlaflose Nacht aussähe (`CLAUDE.md`).
    if (_geometrie.leer) {
      return Text(
        'Nicht aufgezeichnet oder nicht freigegeben — '
        'in den Health-Einstellungen prüfen.',
        style: TextStyle(fontSize: 12, color: muted),
      );
    }

    final beschriftung = TextStyle(fontSize: 11, color: muted);
    final einzug = widget.kompakt ? 0.0 : _namenBreite;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.ablesbar)
          Padding(
            padding: EdgeInsets.only(left: einzug, bottom: 5),
            child: _Kopfzeile(kopf: _kopf()),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!widget.kompakt)
              _Spurnamen(hoehe: _spurhoehe, stil: beschriftung),
            Expanded(
              child: SizedBox(
                key: const Key('hypnogramm-bild'),
                height: _spurhoehe * SchlafPhasen.reihenfolge.length,
                child: _bild(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Padding(
          padding: EdgeInsets.only(left: einzug),
          child: widget.ablesbar
              ? _Uhrzeitachse(geometrie: _geometrie, stil: beschriftung)
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Über `Format`, nicht über `DateFormat`: sonst steht
                    // auf einem englisch eingestellten Gerät die falsche
                    // Sprache mitten im deutschen Text (`CLAUDE.md`).
                    Text(Format.uhrzeit(_geometrie.von!), style: beschriftung),
                    Text(Format.uhrzeit(_geometrie.bis!), style: beschriftung),
                  ],
                ),
        ),
      ],
    );
  }

  /// Die Zeichenfläche, auf dem Schlaf-Schirm unter einer Geste.
  ///
  /// **Ohne [Hypnogramm.ablesbar] liegt dort kein `GestureDetector`.** Auf
  /// dem Erholung-Schirm führt die Zeile über dem Bild auf den
  /// Schlaf-Schirm, und das Bild selbst nimmt dort bewusst keine Tipper an
  /// (27.10.2026); ein durchsichtiger Fänger darüber nähme sie ihr weg.
  Widget _bild(BuildContext context) {
    final maler = CustomPaint(
      size: Size.infinite,
      painter: HypnogrammPainter(
        abschnitte: widget.session.segments,
        farben: {
          for (final phase in SleepStage.values)
            phase: CupertinoDynamicColor.resolve(
              SchlafPhasen.farbe(phase),
              context,
            ),
        },
        fensterFarbe: CupertinoDynamicColor.resolve(
          Palette.ink,
          context,
        ).withValues(alpha: 0.05),
        kompakt: widget.kompakt,
        auswahl: _auswahl,
        achse: widget.ablesbar
            ? [
                for (final stunde in _geometrie.volleStunden)
                  _geometrie.anteil(stunde),
              ]
            : const [],
        rasterFarbe: widget.ablesbar
            ? CupertinoDynamicColor.resolve(Palette.line, context)
            : null,
        // Eine Messlücke wird in **jeder** Fassung gerahmt: Dass nichts
        // gemessen wurde, ist keine Lesehilfe, sondern die Datenlage.
        lueckenFarbe: CupertinoDynamicColor.resolve(Palette.muted, context),
        lotFarbe: widget.ablesbar
            ? CupertinoDynamicColor.resolve(Palette.river, context)
            : null,
      ),
    );
    if (!widget.ablesbar) return maler;
    return GestureDetector(
      // Der Griff, an dem [_waehle] die Breite der Zeichenfläche holt: Der
      // Fänger füllt sie ganz aus, also ist seine Breite ihre.
      key: _bildKey,
      behavior: HitTestBehavior.opaque,
      onLongPressStart: (einzelheiten) =>
          _waehle(einzelheiten.localPosition.dx),
      onLongPressMoveUpdate: (einzelheiten) =>
          _waehle(einzelheiten.localPosition.dx),
      onLongPressEnd: (_) => _loslassen(),
      onLongPressCancel: _loslassen,
      child: maler,
    );
  }
}

/// Die vier Spurnamen links neben dem Bild.
class _Spurnamen extends StatelessWidget {
  const _Spurnamen({required this.hoehe, required this.stil});

  final double hoehe;
  final TextStyle stil;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _namenBreite,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final phase in SchlafPhasen.reihenfolge)
            SizedBox(
              height: hoehe,
              child: Padding(
                padding: const EdgeInsets.only(right: 7, top: 4),
                child: Align(
                  alignment: Alignment.topRight,
                  child: Text(SchlafPhasen.name(phase), style: stil),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Die Kopfzeile über dem Bild — `miniHead` im Entwurf.
///
/// Sie steht in beiden Zuständen da und wechselt beim Ablesen nur ihren
/// Inhalt; rechts wird er flussblau. Der Platz bleibt derselbe, also
/// springt nichts (#146).
class _Kopfzeile extends StatelessWidget {
  const _Kopfzeile({required this.kopf});

  final ({String links, String rechts, bool abgelesen}) kopf;

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final river = CupertinoDynamicColor.resolve(Palette.river, context);
    return Row(
      key: const Key('hypnogramm-kopf'),
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(
          child: Text(
            kopf.links,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.33,
              color: muted,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          kopf.rechts,
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            color: kopf.abgelesen ? river : ink,
          ),
        ),
      ],
    );
  }
}

/// Die Uhrzeitachse unter dem Bild: beschriftet wird **alle zwei Stunden**,
/// nicht jede — sonst stünden die Zahlen aneinander.
///
/// Die Linien je voller Stunde zeichnet der Maler; hier stehen nur die
/// Zahlen, und zwar als Text über [Format]. Auf einem englisch
/// eingestellten Gerät stünde sonst die falsche Sprache im deutschen Text.
class _Uhrzeitachse extends StatelessWidget {
  const _Uhrzeitachse({required this.geometrie, required this.stil});

  final HypnogrammGeometrie geometrie;
  final TextStyle stil;

  /// Halbe Breite des Kästchens, in dem eine Uhrzeit mittig sitzt.
  static const double _halb = 20;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _achsenhoehe,
      child: LayoutBuilder(
        builder: (context, masse) => Stack(
          children: [
            for (final stunde in geometrie.volleStunden)
              if (stunde.hour.isEven)
                Positioned(
                  left: masse.maxWidth * geometrie.anteil(stunde) - _halb,
                  width: _halb * 2,
                  top: 0,
                  child: Center(
                    child: Text(
                      Format.uhrzeit(stunde),
                      style: stil.copyWith(fontSize: 9.5),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

/// „45 min" unter einer Stunde, sonst „3:14" — `dauerText` im Entwurf.
///
/// Eigen statt `schlafDauerText` aus `shell/schlaf_texte.dart`: Das drehte
/// die Richtung um (`shell` hängt von `design` ab, nie umgekehrt), und es
/// schriebe „0:01 h", wo hier „1 min" stehen muss.
String _dauerText(Duration dauer) {
  final minuten = (dauer.inSeconds / Duration.secondsPerMinute).round();
  if (minuten < Duration.minutesPerHour) return '$minuten min';
  final stunden = minuten ~/ Duration.minutesPerHour;
  final rest = minuten % Duration.minutesPerHour;
  return '$stunden:${rest.toString().padLeft(2, '0')}';
}
