import 'package:flutter/cupertino.dart';

import '../design/palette.dart';
import 'gym_log_texte.dart';

/// Wie lange nur ein Bild steht, bevor es zum anderen überblendet.
const Duration kBildHalten = Duration(milliseconds: 1200);

/// Wie lange die Überblendung zwischen Start- und Endbild dauert.
const Duration kBildUeberblendung = Duration(milliseconds: 400);

/// Ein voller Durchlauf: Start halten, zum Ende überblenden, Ende halten,
/// zurück überblenden — 3,2 s.
///
/// Als Literal, weil `Duration` in `const` nicht rechnet; der Test
/// `uebungsbild_animation_test.dart` hält es bei 2 · (halten + überblenden).
const Duration kBildZyklus = Duration(milliseconds: 3200);

/// Das große Übungsbild: Start- und Endbild übereinandergelegt, das Endbild
/// blendet in einer Endlosschleife ein und aus (#38).
///
/// Die Quelle sind **zwei Standbilder**, keine GIFs; die Bewegung entsteht
/// erst hier. Ein Zyklus (siehe [kBildZyklus]): [kBildHalten] nur Start,
/// [kBildUeberblendung] zum Ende, [kBildHalten] nur Ende, [kBildUeberblendung]
/// zurück.
///
/// - **Nur ein Bild** ([ende] ist `null`): statisch, kein Controller läuft.
/// - **Beide Bilder werden vorab geladen**, und die Schleife beginnt erst,
///   wenn beide da sind — sonst flackert die erste Überblendung. Scheitert
///   eines, bleibt das Startbild statisch stehen; es gibt keine Ausnahme.
/// - **Reduzierte Bewegung** (`MediaQuery.disableAnimations`): keine
///   Schleife. Das Endbild steht, ein Tippen wechselt zwischen Start und
///   Ende. Ändert sich die Einstellung zur Laufzeit, folgt das Widget.
/// - **Nur Sichtbares animiert.** Der Controller hängt am `TickerMode`
///   (Navigator und Tab-Leiste schalten ihn für verdeckte Seiten ab) und
///   steht still, sobald das Widget aus dem Sichtfeld seines `Scrollable`
///   gescrollt ist. Mehrere offene Karten kosten so nur das, was man sieht.
/// - **Wechselt die Übung** (andere Pfade), wird neu vorgeladen und der
///   Ablauf beginnt von vorn.
///
/// Platz: quadratisch, Ecken 20, vom ersten Bild an gleich groß — der Text
/// darunter verschiebt sich nie. Kein Glas.
class UebungsbildAnimation extends StatefulWidget {
  const UebungsbildAnimation({
    super.key,
    required this.start,
    this.ende,
    this.frameKey,
    this.endeKey,
    this.semantik,
  });

  /// Asset-Pfad des Startbildes.
  final String start;

  /// Asset-Pfad des Endbildes; `null` bei Einzelbild.
  final String? ende;

  /// Schlüssel der quadratischen Fläche (für Tests und Messungen).
  final Key? frameKey;

  /// Schlüssel der oberen Lage (Endbild samt Überblendung) — nur da, wenn es
  /// ein Endbild gibt und die Bewegung nicht reduziert ist.
  final Key? endeKey;

  /// Vorlesetext des Bildes; `null`: das Bild ist für den Screenreader
  /// Beiwerk.
  final String? semantik;

  static const double eckenradius = 20;

  @override
  State<UebungsbildAnimation> createState() => _UebungsbildAnimationState();
}

class _UebungsbildAnimationState extends State<UebungsbildAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _endeDeckkraft;

  ScrollPosition? _position;

  /// Beide Bilder sind dekodiert und im Cache.
  bool _bereit = false;
  bool _sichtbar = true;
  bool _reduziert = false;

  /// Bei reduzierter Bewegung: das Endbild steht zuerst.
  bool _zeigtEnde = true;

  /// Für welche Pfade zuletzt vorgeladen wurde.
  (String, String?)? _geladenFuer;

  /// Zählt Vorladeläufe; ein später eintreffender, überholter Lauf wird
  /// verworfen.
  int _lauf = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: kBildZyklus);
    _endeDeckkraft = TweenSequence<double>([
      TweenSequenceItem(
        tween: ConstantTween<double>(0),
        weight: kBildHalten.inMilliseconds.toDouble(),
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0,
          end: 1,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: kBildUeberblendung.inMilliseconds.toDouble(),
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1),
        weight: kBildHalten.inMilliseconds.toDouble(),
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1,
          end: 0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: kBildUeberblendung.inMilliseconds.toDouble(),
      ),
    ]).animate(_controller);
    WidgetsBinding.instance.addPostFrameCallback((_) => _pruefeSichtbarkeit());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduziert = MediaQuery.disableAnimationsOf(context);

    final position = Scrollable.maybeOf(context)?.position;
    if (position != _position) {
      _position?.removeListener(_pruefeSichtbarkeit);
      _position = position?..addListener(_pruefeSichtbarkeit);
    }

    if (_geladenFuer != (widget.start, widget.ende)) _vorladen();
    _anpassen();
  }

  @override
  void didUpdateWidget(UebungsbildAnimation alt) {
    super.didUpdateWidget(alt);
    if (alt.start != widget.start || alt.ende != widget.ende) {
      _zeigtEnde = true;
      _vorladen();
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _pruefeSichtbarkeit(),
      );
    }
    _anpassen();
  }

  @override
  void dispose() {
    _lauf++;
    _position?.removeListener(_pruefeSichtbarkeit);
    _controller.dispose();
    super.dispose();
  }

  /// Lädt beide Bilder in den Bildcache. Ein Fehler ist hier kein Fehler: Die
  /// Schleife läuft dann nicht, und das `Image` zeigt seinen Platzhalter.
  void _vorladen() {
    final lauf = ++_lauf;
    final start = widget.start;
    final ende = widget.ende;
    _geladenFuer = (start, ende);
    _bereit = false;
    _controller.value = 0;

    Future.wait([_laden(start), if (ende != null) _laden(ende)])
        .then((ergebnisse) {
          if (!mounted || lauf != _lauf) return;
          setState(() => _bereit = ergebnisse.every((ok) => ok));
          _anpassen();
        });
  }

  Future<bool> _laden(String pfad) async {
    var ok = true;
    try {
      await precacheImage(
        AssetImage(pfad),
        context,
        onError: (_, _) => ok = false,
      );
    } catch (_) {
      ok = false;
    }
    return ok;
  }

  /// Ist das Widget im Sichtfeld seines nächsten `Scrollable`? Ohne
  /// `Scrollable` zählt es als sichtbar — dann entscheidet `TickerMode`.
  void _pruefeSichtbarkeit() {
    if (!mounted) return;
    var sichtbar = true;
    final box = context.findRenderObject();
    final scrollable = Scrollable.maybeOf(context);
    final sicht = scrollable?.context.findRenderObject();
    if (box is RenderBox &&
        box.attached &&
        box.hasSize &&
        sicht is RenderBox &&
        sicht.attached &&
        sicht.hasSize) {
      final bild = box.localToGlobal(Offset.zero) & box.size;
      final fenster = sicht.localToGlobal(Offset.zero) & sicht.size;
      sichtbar = bild.overlaps(fenster);
    }
    if (sichtbar != _sichtbar) {
      _sichtbar = sichtbar;
      _anpassen();
    }
  }

  /// Der Controller läuft genau dann, wenn es etwas zu überblenden gibt, beide
  /// Bilder da sind, die Bewegung nicht reduziert ist und das Widget im Bild
  /// steht. Sonst steht er.
  void _anpassen() {
    final laufen = widget.ende != null && _bereit && _sichtbar && !_reduziert;
    if (laufen) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      if (_controller.isAnimating) _controller.stop();
      if (_reduziert) _controller.value = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final flaeche = CupertinoDynamicColor.resolve(Palette.bg, context);
    final ende = widget.ende;

    final Widget inhalt;
    if (ende == null) {
      inhalt = _Bild(pfad: widget.start);
    } else if (_reduziert) {
      final pfad = _zeigtEnde ? ende : widget.start;
      inhalt = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _zeigtEnde = !_zeigtEnde),
        child: _Bild(key: ValueKey(pfad), pfad: pfad),
      );
    } else {
      inhalt = Stack(
        fit: StackFit.expand,
        children: [
          _Bild(pfad: widget.start),
          FadeTransition(
            key: widget.endeKey,
            opacity: _endeDeckkraft,
            child: _Bild(pfad: ende, platzhalter: false),
          ),
        ],
      );
    }

    final flaecheBild = AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(UebungsbildAnimation.eckenradius),
        child: DecoratedBox(
          key: widget.frameKey,
          decoration: BoxDecoration(color: flaeche),
          child: inhalt,
        ),
      ),
    );

    final semantik = widget.semantik;
    if (semantik == null) return ExcludeSemantics(child: flaecheBild);
    return Semantics(
      label: semantik,
      image: true,
      onTap: ende != null && _reduziert
          ? () => setState(() => _zeigtEnde = !_zeigtEnde)
          : null,
      onTapHint: ende != null && _reduziert ? gymBildWechselnHinweis : null,
      child: ExcludeSemantics(child: flaecheBild),
    );
  }
}

/// Ein Bild in der Fläche. Blendet ein, sobald das erste Bild da ist.
/// Mit [platzhalter]: Lässt sich die Datei nicht lesen, steht es da; ohne
/// bleibt die Fläche leer (die obere Lage der Überblendung).
class _Bild extends StatelessWidget {
  const _Bild({super.key, required this.pfad, this.platzhalter = true});

  final String pfad;
  final bool platzhalter;

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    return Image(
      image: AssetImage(pfad),
      fit: BoxFit.contain,
      gaplessPlayback: true,
      excludeFromSemantics: true,
      frameBuilder: (context, child, frame, sofort) => sofort
          ? child
          : AnimatedOpacity(
              opacity: frame == null ? 0 : 1,
              duration: const Duration(milliseconds: 150),
              child: child,
            ),
      errorBuilder: (context, fehler, stapel) => platzhalter
          ? Center(
              child: Text(
                gymBildNichtLesbar,
                style: TextStyle(fontSize: 12, color: muted),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
