// Die Muskelfigur (#533, Task 2.1 des Plans `docs/superpowers/plans/2026-11-19-
// eigene-trainings-plan.md`; Spec 7.2, 7.5, 8.1).
//
// **Ein Baustein, mehrere Aufrufer:** die drehbare Kachel-Figur der
// Übersicht (eine Seite), das Detail (beide Seiten) und später die
// Muskelkarte der Auswertung (#96, #525). Er nimmt eine **Farbzuordnung, die
// der Aufrufer wählt** — Kachel und Detail wählen eine Farbe („trifft diese
// Muskeln", nicht „wie viel"). Eine zweite Farblogik auf derselben Figur wäre
// „eine falsche Auskunft" (Spec 8.1); der Baustein kennt deshalb keine
// Statusfarben.
//
// Gezeichnet wird mit `CustomPaint` — kein Glas, kein Shader. Die Pfade
// stehen in `muskel_figur_daten.dart` und sind **erzeugt**, nicht abgetippt
// (`scripts/figure-data-to-dart.mjs` aus `docs/screens/figure-data.js`).
//
// **Der Painter ist wertgleich** (Spec 13, Fehler `03`): `==` über die
// gefärbte Menge samt Farben und die Seite, damit er beim Neuaufbau mit
// gleichem Inhalt nicht neu zeichnet.
//
// Nachgebaut ist `muscleThumb`/`muscleFigure` in `docs/screens/components.js`:
// Gezeichnet wird **eine** Körperhälfte, die andere entsteht durch Spiegelung
// an x = 200; der Arm steht um 6 Grad abgespreizt, gedreht um die Schulter
// bei (58, 76).
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:trainings_core/trainings_core.dart';

import 'muskel_figur_daten.dart';
import 'palette.dart';

/// Welche Hälfte der Figur gezeigt wird.
///
/// Zwei Fälle, kein dritter: Die Kachel dreht die Figur zwischen Vorder- und
/// Rückseite (Tim, 19.11.2026, Spec 7.5). Das Detail zeigt beide Seiten
/// nebeneinander und braucht keine Auswahl ([MuskelFigur.seite] ist dort
/// `null`).
enum MuskelSeite { vorne, hinten }

/// Der Schlüssel der Zeichenfläche der Vorderseite.
const kMuskelFigurVorne = Key('muskel-figur-vorne');

/// Der Schlüssel der Zeichenfläche der Rückseite.
const kMuskelFigurHinten = Key('muskel-figur-hinten');

/// Die Haut — Kopf. Wie im Entwurf (`SKIN`) und in der Swift-Figur.
const Color _haut = Color(0xFFD6D1CC);

/// Die Haut ohne Muskelzuordnung — Umriss, Arm, Bein (`SKIN_DARK`).
const Color _hautDunkel = Color(0xFFC2BDB8);

/// Das Entwurfsgitter einer Seite: 200 breit je Hälfte, 10 Rand links und
/// rechts, 430 hoch (`viewBox="0 0 220 430"` in `muscleThumb`).
const double _gitterBreite = 220;
const double _gitterHoehe = 430;

/// Was die Beschriftung unter einer Hälfte an Höhe braucht — nur zum Rechnen,
/// wenn die Höhe begrenzt ist.
const double _beschriftungHoehe = 24;

/// Die Figur — eine Seite oder beide nebeneinander.
///
/// [seite] `null` zeigt **beide** Hälften, vorne links, mit den
/// Beschriftungen „VORNE" und „HINTEN"; sonst nur die gewählte, ohne
/// Beschriftung.
///
/// [semantik] ist der Vorlesetext, **vom Aufrufer gerechnet**: Welche Muskeln
/// er nennt, hängt von seiner Menge und seiner Seite ab. Der Baustein trägt
/// ihn als **einen** Knoten und schließt seine Kinder aus — die
/// Beschriftungen lesen sich nicht einzeln vor.
///
/// **Die Figur behält ihre Größe**, auch ohne gefärbten Muskel: Ohne Menge
/// steht sie ungefärbt da, sie verschwindet nicht (`CLAUDE.md`, „Eine
/// Anzeige, die es gibt, hat genau eine Form").
class MuskelFigur extends StatelessWidget {
  const MuskelFigur({
    super.key,
    required this.gefaerbt,
    this.seite,
    required this.semantik,
  });

  /// Welcher Muskel in welcher Farbe. **Fehlt ein Muskel, steht er im
  /// Linienton** ([Palette.line]); Haut ohne Zuordnung bleibt Haut.
  final Map<Muscle, Color> gefaerbt;

  /// `null` = beide Hälften.
  final MuskelSeite? seite;

  final String semantik;

  @override
  Widget build(BuildContext context) {
    final linie = CupertinoDynamicColor.resolve(Palette.line, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);

    Widget flaeche(MuskelSeite s) => AspectRatio(
      aspectRatio: _gitterBreite / _gitterHoehe,
      // Eine eigene Ebene je Figur: Beim Scrollen der Übersicht wird die
      // Zeichnung wiederverwendet, statt je Bild neu aufgenommen (Spec 13).
      child: RepaintBoundary(
        child: CustomPaint(
          key: s == MuskelSeite.vorne ? kMuskelFigurVorne : kMuskelFigurHinten,
          painter: MuskelFigurPainter(
            gefaerbt: gefaerbt,
            seite: s,
            linie: linie,
          ),
        ),
      ),
    );

    final einzelne = seite;
    final inhalt = einzelne != null
        ? flaeche(einzelne)
        : LayoutBuilder(
            builder: (context, c) {
              // Je Hälfte die halbe Breite — außer die Höhe ist begrenzt und
              // reicht dafür nicht: Eine Spalte gäbe ihren Kindern sonst
              // unbegrenzte Höhe und liefe über.
              var breite = c.maxWidth / 2;
              if (c.hasBoundedHeight) {
                breite = math.min(
                  breite,
                  (c.maxHeight - _beschriftungHoehe) *
                      _gitterBreite /
                      _gitterHoehe,
                );
              }
              return Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final s in MuskelSeite.values)
                    SizedBox(
                      width: breite,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          flaeche(s),
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              s == MuskelSeite.vorne ? 'VORNE' : 'HINTEN',
                              // Eine Zeile, nie zwei: Bei begrenzter Höhe
                              // rechnet [_beschriftungHoehe] mit einer. Ein
                              // Umbruch in einer schmalen Hälfte (#554,
                              // Editor) liefe sonst über den Rahmen.
                              maxLines: 1,
                              softWrap: false,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1,
                                color: muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          );

    // Kein `container`: Der Aufrufer darf den Knoten mit eigenen Angaben (die
    // Aktion „Figur umdrehen") zusammenführen, statt zwei Knoten zu lesen.
    return Semantics(label: semantik, excludeSemantics: true, child: inhalt);
  }
}

/// Ein Pfad der Figur samt dem Muskel, zu dem er gehört (`null` = Haut).
class _Teil {
  _Teil(this.muskel, this.pfad);

  final Muscle? muskel;
  final Path pfad;
}

/// Die Zeichnung einer Seite — einmal aus den erzeugten Daten gebaut.
class _Seitenform {
  _Seitenform(List<FigurTeil> rumpf, List<FigurTeil> arm)
    : rumpf = [for (final t in rumpf) _teil(t)],
      arm = [for (final t in arm) _teil(t)];

  final List<_Teil> rumpf;
  final List<_Teil> arm;

  static _Teil _teil(FigurTeil teil) {
    final name = teil.muskel;
    return _Teil(name == null ? null : _muskel(name), _pfad(teil.pfad));
  }

  /// Der Muskel zu einem Namen aus den Figurdaten. Ein Name, den es nicht
  /// gibt, ist ein Fehler in den Daten, kein Fall für „einfach Haut".
  static Muscle _muskel(String name) =>
      Muscle.values.singleWhere((m) => m.german == name);
}

/// Baut einen [Path] aus einer Befehlsliste der erzeugten Daten.
Path _pfad(List<double> befehle) {
  final pfad = Path();
  var i = 0;
  while (i < befehle.length) {
    switch (befehle[i].toInt()) {
      case 0:
        pfad.moveTo(befehle[i + 1], befehle[i + 2]);
        i += 3;
      case 1:
        pfad.lineTo(befehle[i + 1], befehle[i + 2]);
        i += 3;
      case 2:
        pfad.cubicTo(
          befehle[i + 1],
          befehle[i + 2],
          befehle[i + 3],
          befehle[i + 4],
          befehle[i + 5],
          befehle[i + 6],
        );
        i += 7;
      case 3:
        pfad.close();
        i += 1;
      default:
        throw StateError('Unbekannter Pfadbefehl ${befehle[i]}');
    }
  }
  return pfad;
}

List<Path> _pfade(List<List<double>> liste) => [
  for (final befehle in liste) _pfad(befehle),
];

/// Zeichnet **eine** Seite der Figur.
///
/// Trägt die gefärbte Menge und die Seite als Eigenschaften — der Test liest
/// sie, vergleicht keine Pixel (Spec 8.1).
class MuskelFigurPainter extends CustomPainter {
  MuskelFigurPainter({
    required this.gefaerbt,
    required this.seite,
    this.linie = const Color(0xFFCBD5D3),
  });

  /// Welcher Muskel in welcher Farbe. Die Aufteilung auf die Seite rechnet
  /// der Painter: Was hier nicht liegt, bleibt unberührt.
  final Map<Muscle, Color> gefaerbt;

  final MuskelSeite seite;

  /// Der Linienton für alles, was nicht gefärbt ist — vom Baustein aufgelöst,
  /// damit er im Dunkelmodus stimmt. Gehört zur Gleichheit: Wer den Modus
  /// wechselt, will das neue Bild sehen.
  final Color linie;

  // --- Die Daten, einmal gebaut ---------------------------------------------

  static final List<Path> _umriss = _pfade(kFigurUmriss);
  static final List<Path> _bein = _pfade(kFigurBein);
  static final List<Path> _armHaut = _pfade(kFigurArm);
  static final _Seitenform _vorne = _Seitenform(
    kFigurRumpfVorne,
    kFigurArmVorne,
  );
  static final _Seitenform _hinten = _Seitenform(
    kFigurRumpfHinten,
    kFigurArmHinten,
  );
  static final Map<MuskelSeite, Map<Muscle, int>> _zaehlung = {
    for (final s in MuskelSeite.values) s: _zaehle(_form(s)),
  };

  static _Seitenform _form(MuskelSeite seite) =>
      seite == MuskelSeite.vorne ? _vorne : _hinten;

  static Map<Muscle, int> _zaehle(_Seitenform form) {
    final ergebnis = <Muscle, int>{};
    for (final teil in [...form.rumpf, ...form.arm]) {
      final muskel = teil.muskel;
      if (muskel != null) ergebnis[muskel] = (ergebnis[muskel] ?? 0) + 1;
    }
    return Map.unmodifiable(ergebnis);
  }

  /// Je Muskel die Zahl seiner Pfade auf [seite] — **eine Körperhälfte**, die
  /// Spiegelung zählt nicht doppelt; Haut (ohne Zuordnung) steht nicht darin.
  /// Ein Muskel ohne Pfad auf dieser Seite fehlt in der Map.
  static Map<Muscle, int> pfadeJeMuskel(MuskelSeite seite) => _zaehlung[seite]!;

  /// Die Muskeln, die dieser Painter wirklich färbt: [gefaerbt] geschnitten
  /// mit den Muskeln, die auf [seite] einen Pfad haben.
  Set<Muscle> get gefaerbteMuskeln => {
    for (final muskel in gefaerbt.keys)
      if (pfadeJeMuskel(seite).containsKey(muskel)) muskel,
  };

  /// Wie viele Pfade (eine Körperhälfte) dieser Painter färbt — die Summe von
  /// [pfadeJeMuskel] über [gefaerbteMuskeln].
  int get gefaerbtePfade {
    final je = pfadeJeMuskel(seite);
    return gefaerbteMuskeln.fold<int>(0, (summe, m) => summe + je[m]!);
  }

  // --- Zeichnen -------------------------------------------------------------

  @override
  void paint(Canvas canvas, Size size) {
    // Gleichmäßig einpassen und mittig setzen — wie eine SVG-`viewBox`.
    final massstab = math.min(
      size.width / _gitterBreite,
      size.height / _gitterHoehe,
    );
    canvas
      ..save()
      ..translate(
        (size.width - _gitterBreite * massstab) / 2,
        (size.height - _gitterHoehe * massstab) / 2,
      )
      ..scale(massstab)
      // 10 Punkt Rand links; die Hälfte ist 200 breit.
      ..translate(10, 0);

    final haut = Paint()..color = _haut;
    final hautDunkel = Paint()..color = _hautDunkel;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(kFigurKopf[0], kFigurKopf[1]),
        width: 2 * kFigurKopf[2],
        height: 2 * kFigurKopf[3],
      ),
      haut,
    );
    for (final pfad in _umriss) {
      canvas.drawPath(pfad, hautDunkel);
    }

    final form = _form(seite);
    _haelfte(canvas, form, hautDunkel);
    // Die andere Hälfte: an x = 200 gespiegelt.
    canvas
      ..save()
      ..translate(200, 0)
      ..scale(-1, 1);
    _haelfte(canvas, form, hautDunkel);
    canvas
      ..restore()
      ..restore();
  }

  void _haelfte(Canvas canvas, _Seitenform form, Paint hautDunkel) {
    // Der Arm steht um 6 Grad abgespreizt, gedreht um die Schulter.
    canvas
      ..save()
      ..translate(58, 76)
      ..rotate(6 * math.pi / 180)
      ..translate(-58, -76);
    for (final pfad in _armHaut) {
      canvas.drawPath(pfad, hautDunkel);
    }
    _zeichne(canvas, form.arm, hautDunkel);
    canvas.restore();

    for (final pfad in _bein) {
      canvas.drawPath(pfad, hautDunkel);
    }
    _zeichne(canvas, form.rumpf, hautDunkel);
  }

  void _zeichne(Canvas canvas, List<_Teil> teile, Paint hautDunkel) {
    for (final teil in teile) {
      final muskel = teil.muskel;
      canvas.drawPath(
        teil.pfad,
        muskel == null
            ? hautDunkel
            : (Paint()..color = gefaerbt[muskel] ?? linie),
      );
    }
  }

  @override
  bool shouldRepaint(MuskelFigurPainter oldDelegate) => oldDelegate != this;

  @override
  bool operator ==(Object other) =>
      other is MuskelFigurPainter &&
      other.seite == seite &&
      other.linie == linie &&
      _gleicheMenge(other.gefaerbt, gefaerbt);

  @override
  int get hashCode => Object.hash(
    seite,
    linie,
    Object.hashAllUnordered([
      for (final e in gefaerbt.entries) Object.hash(e.key, e.value),
    ]),
  );
}

/// Inhaltlicher Vergleich zweier Farbzuordnungen — ohne Rücksicht darauf, in
/// welcher Reihenfolge sie gebaut wurden. Darts `==` auf `Map` ist Identität.
bool _gleicheMenge(Map<Muscle, Color> a, Map<Muscle, Color> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (final e in a.entries) {
    if (b[e.key] != e.value) return false;
  }
  return true;
}
