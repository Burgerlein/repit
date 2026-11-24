import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import '../design/palette.dart';
import '../design/symbole.dart';

/// Ein Eintrag im Bogenmenü des (+) — Dart-Entsprechung von `tabMenu()`s
/// `items`-Parameter in `docs/screens/components.js` (dort ein Tupel
/// `[label, hint, icon, aus]`).
///
/// `verfuegbar: false` lässt den Eintrag ausgegraut stehen, statt ihn
/// wegzulassen — `tabMenu()`s Kommentarkopf: „Sonst wandern die übrigen auf
/// dem Bogen je nach Zustand, und man greift ins Leere, wo gestern noch
/// etwas war."
@immutable
class BogenEintrag {
  const BogenEintrag({
    required this.titel,
    this.hinweis,
    required this.symbol,
    this.verfuegbar = true,
    this.onTap,
  });

  final String titel;

  /// Untertitel unter dem Titel, z. B. „Datenbank und zuletzt". Optional —
  /// diese Datei prüft ihn nirgends gezielt (CLAUDE.md: keine
  /// Beschriftungsprüfung in Widget-Tests).
  final String? hinweis;

  /// Name aus `Symbole.tabelle`.
  final String symbol;

  /// `false`: der Eintrag bleibt sichtbar, ausgegraut, und ein Tipp löst
  /// weder [onTap] aus noch lässt er den Eintrag verschwinden.
  final bool verfuegbar;

  final VoidCallback? onTap;
}

/// Der (+)/(×)-Knopf der Tableiste samt Bogenmenü — Dart-Entsprechung von
/// `tabbar()`s `.fab` und `tabMenu()` in `docs/screens/components.js:158ff`,
/// Maße aus `components.css` ab Zeile 77 (Radius 92, Mitte 73 über der
/// Unterkante, Winkel 160°–20°, höchstens vier Einträge).
///
/// **Ausgelagert aus `root_view.dart`** (CLAUDE.md: „Views bleiben klein"),
/// isoliert geprüft in `erfassen_knopf_test.dart`; `root_view_test.dart`
/// prüft nur, dass `RootView` diesen Baustein mit den drei M1-Einträgen
/// verwendet.
///
/// **Zwei Gesten, ein Knopf:** Tippen (geschlossen) ruft [onErfassen] auf.
/// Langdrücken (geschlossen) fährt den Bogen auf, ohne [onErfassen]
/// aufzurufen. Tippen (offen) schließt ihn wieder — **derselbe** Knopf, kein
/// zweiter: `tabMenu()`s Kommentarkopf sagt das wörtlich („Im Entwurf ist
/// das ein zweiter Knopf an derselben Stelle — in der App dreht sich einer
/// um eine Achtel Umdrehung"). Die Drehung läuft hier über
/// `AnimatedRotation` auf ein und demselben `plus.circle.plain`-Icon: ein um
/// 45° gedrehtes Pluszeichen sieht wie ein Kreuz aus, ohne dass ein zweites
/// Icon gebraucht wird — genau der Trick aus `.tmclose { transform: ...
/// rotate(45deg) }` im CSS-Vorbild.
///
/// Höchstens vier Einträge ([eintraege] wird auf vier gekappt) — weitere
/// würden laut `tabMenu()`-Kommentarkopf so eng rücken, dass man
/// danebentippt.
class ErfassenKnopf extends StatefulWidget {
  const ErfassenKnopf({
    super.key,
    required this.eintraege,
    required this.onErfassen,
  });

  final List<BogenEintrag> eintraege;
  final VoidCallback onErfassen;

  /// Durchmesser des sichtbaren (+)/(×)-Knopfs selbst — components.css ab
  /// Zeile 77. **Öffentlich**, weil `root_view.dart` daraus errechnen muss,
  /// wie weit der Knopf über die Tableiste hinausragt (task-layout-fixes:
  /// die vorige Formel dort benutzte stattdessen die Höhe dieses ganzen
  /// Bausteins samt Bogenfläche und setzte den Knopf dadurch 34 Punkt zu
  /// hoch — mitten in den Inhalt des Schirms statt 12 Punkt über die
  /// Leiste).
  static const knopfDurchmesser = 58.0;

  @override
  State<ErfassenKnopf> createState() => _ErfassenKnopfState();
}

class _ErfassenKnopfState extends State<ErfassenKnopf> {
  bool _offen = false;

  // Maße aus components.css ab Zeile 77.
  static const _radius = 92.0;
  static const _vonGrad = 160.0;
  static const _bisGrad = 20.0;
  static const _punktGroesse = 52.0;

  // Feste, großzügig bemessene Fläche für den ganzen Baustein (Knopf plus
  // Bogen). **Bewusst keine Kombination aus `Positioned` (ohne Breite/Höhe)
  // und `FractionalTranslation`** — diese Paarung lässt Flutter die Größe
  // jedes Bogeneintrags aus seinem Inhalt (Text, Icon) selbst ermitteln, und
  // `tester.tap(find.text(...))` zielt dann auf einen errechneten Mittelpunkt,
  // der nicht zuverlässig mit dem tatsächlich hit-testbaren Bereich
  // übereinstimmt (siehe Bericht: ein Tipp auf einen verfügbaren Eintrag
  // verfehlte sein Ziel in genau diesem Aufbau). Mit einer festen Breite/
  // Höhe je Eintrag ([_eintragBreite]/[_eintragHoehe]) ist die Position
  // dagegen eine einfache Subtraktion ohne Zwischenschritt über die
  // Render-Pipeline.
  static const _breite = 320.0;
  static const _hoehe = 260.0;
  static const _eintragBreite = 104.0;
  // Großzügig bemessen: Icon (52) + Abstand (6) + Titel + ein bis zwei
  // Zeilen Hinweistext (z. B. „Datenbank und zuletzt" bricht bei 104 Punkt
  // Breite um) müssen ohne `RenderFlex`-Überlauf hineinpassen.
  static const _eintragHoehe = 140.0;

  void _knopfGetippt() {
    if (_offen) {
      setState(() => _offen = false);
      return;
    }
    widget.onErfassen();
  }

  void _knopfLangGedrueckt() {
    if (_offen) return;
    setState(() => _offen = true);
  }

  void _eintragGetippt(BogenEintrag eintrag) {
    if (!eintrag.verfuegbar) return;
    eintrag.onTap?.call();
    setState(() => _offen = false);
  }

  @override
  Widget build(BuildContext context) {
    final eintraege = widget.eintraege.take(4).toList(growable: false);

    // Knopfmitte, horizontal: Boxmitte. Vertikal: eine Knopfbreite über der
    // Unterkante der Box (der Knopf selbst sitzt mit seiner Unterkante auf
    // der Unterkante der Box, siehe `Positioned` unten) — der Bezugspunkt,
    // von dem aus `_bogenPunkt` den Radius abträgt.
    const knopfZentrumX = _breite / 2;
    const knopfZentrumYVonUnten = ErfassenKnopf.knopfDurchmesser / 2;

    return SizedBox(
      width: _breite,
      height: _hoehe,
      child: Stack(
        // Der Bogen liegt laut Board absolut über der ganzen Leiste, nicht
        // im Fluss (components.css: „ohne diese Regeln rutscht alles in den
        // Fluss"). `Clip.none`, weil einzelne Einträge bei extremen Winkeln
        // auch außerhalb der schon großzügig bemessenen Box liegen könnten.
        clipBehavior: Clip.none,
        children: [
          if (_offen)
            for (var i = 0; i < eintraege.length; i++)
              _bogenPunkt(
                context,
                eintraege[i],
                i,
                eintraege.length,
                knopfZentrumX,
                knopfZentrumYVonUnten,
              ),
          Positioned(
            left: knopfZentrumX - ErfassenKnopf.knopfDurchmesser / 2,
            bottom: 0,
            child: _knopf(context),
          ),
        ],
      ),
    );
  }

  Widget _knopf(BuildContext context) {
    // Derselbe Dreh wie im CSS-Vorbild: hell ein dunkler Kreis mit heller
    // Glyphe, dunkel umgekehrt — ohne eine zweite Akzentfarbe zu brauchen
    // (components.css, Kommentar bei `.tabbar`).
    final aktionsflaeche = CupertinoDynamicColor.resolve(Palette.deep, context);
    final aufAktionsflaeche = CupertinoDynamicColor.resolve(
      Palette.surface,
      context,
    );

    return GestureDetector(
      key: const Key('erfassen-knopf'),
      behavior: HitTestBehavior.opaque,
      onTap: _knopfGetippt,
      onLongPress: _knopfLangGedrueckt,
      child: AnimatedRotation(
        turns: _offen ? 0.125 : 0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: Container(
          width: ErfassenKnopf.knopfDurchmesser,
          height: ErfassenKnopf.knopfDurchmesser,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: aktionsflaeche,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Symbole.aufloesen('plus'),
            size: 28,
            color: aufAktionsflaeche,
          ),
        ),
      ),
    );
  }

  Widget _bogenPunkt(
    BuildContext context,
    BogenEintrag eintrag,
    int index,
    int gesamt,
    double knopfZentrumX,
    double knopfZentrumYVonUnten,
  ) {
    // Staffelung von links nach rechts, wörtlich wie `tabMenu()` in
    // components.js.
    final grad = gesamt == 1
        ? 90.0
        : _vonGrad - (_vonGrad - _bisGrad) * (index / (gesamt - 1));
    final rad = grad * math.pi / 180;
    final dx = math.cos(rad) * _radius;
    // sin(160°..20°) ist positiv, `dy` hebt den Punkt also über die
    // Knopfmitte an — der Bogen liegt über dem Knopf, nicht darunter.
    final dy = math.sin(rad) * _radius;

    final punktZentrumX = knopfZentrumX + dx;
    final punktZentrumYVonUnten = knopfZentrumYVonUnten + dy;

    final surface = CupertinoDynamicColor.resolve(Palette.surface, context);
    final river = CupertinoDynamicColor.resolve(Palette.river, context);
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);

    final hinweis = eintrag.hinweis;

    return Positioned(
      // Feste Breite/Höhe (siehe Klassenkommentar bei `_breite`), deshalb
      // hier eine einfache Subtraktion statt `FractionalTranslation` — der
      // errechnete Punkt ist die Mitte des Eintrags, nicht seine Ecke,
      // genau wie `transform: translate(-50%, 50%)` im CSS-Vorbild, nur
      // ohne eine zweite Render-Transformation dafür zu brauchen.
      left: punktZentrumX - _eintragBreite / 2,
      bottom: punktZentrumYVonUnten - _eintragHoehe / 2,
      width: _eintragBreite,
      height: _eintragHoehe,
      child: Opacity(
        opacity: eintrag.verfuegbar ? 1.0 : 0.38,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _eintragGetippt(eintrag),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: _punktGroesse,
                height: _punktGroesse,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: surface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: CupertinoDynamicColor.resolve(
                      Palette.line,
                      context,
                    ),
                    width: 0.5,
                  ),
                ),
                child: Icon(
                  Symbole.aufloesen(eintrag.symbol),
                  size: 23,
                  color: river,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                eintrag.titel,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: ink,
                ),
              ),
              if (hinweis != null)
                Text(
                  hinweis,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: muted),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
