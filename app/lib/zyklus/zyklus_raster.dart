// Das Monatsraster des Zyklus-Schirms (#571).
//
// Aufbau nach `docs/screens/screens/zyklus.js` und den Bausteinen
// `zyklusZelle` / `zyklusMonat` in `docs/screens/components.js`.
//
// Die visuelle Grammatik stammt aus Tims Referenzbildern vom
// 23.11.2026 und steht ausgeschrieben im Entwurf
// (`docs/superpowers/specs/2026-11-18-zykluskalender-design.md`):
//
//   · gefüllt heißt eingetragen, gepunktet heißt geschätzt
//   · kräftig heißt sicher, hell heißt unsicher
//   · Rosa ist Blutung, Türkis ist Fruchtbarkeit
//   · Zustände liegen IM Tag, Einträge hängen DARUNTER
//
// **Jede Zelle ist gleich groß und immer vorhanden, auch leer.** Sonst
// springt das Raster, sobald der erste Wert eintrifft — dieselbe Regel
// wie bei der Kalenderkachel des Schlaf-Schirms.
import 'package:flutter/cupertino.dart';

import '../design/palette.dart';

Color _farbe(BuildContext context, Color farbe) =>
    CupertinoDynamicColor.resolve(farbe, context);

/// Was ein Tag im Raster zeigt. **Genau einer** — ein Tag ist entweder
/// Blutung oder fruchtbar, nie beides; wäre er beides, wäre die
/// Vorhersage kaputt und müsste das sagen, statt es zu malen.
enum ZyklusTagZustand {
  /// Blutung eingetragen: volle Fläche.
  eingetragen,

  /// Blutung vorhergesagt: helle Fläche.
  vorhergesagt,

  /// Unsicherheitsrand der Vorhersage: gepunkteter Rand, keine Fläche.
  rand,

  /// Geschätzter Eisprung: türkis gepunktet. **Nie gefüllt** — gefüllt
  /// hieße gemessen, und gemessen wird hier nichts.
  eisprung,

  /// Fruchtbares Fenster: nur die Ziffer, kein Rand.
  fruchtbar,
}

/// Was an einem Tag eingetragen wurde — hängt **unter** dem Tag.
enum ZyklusMarke {
  /// Sex: ein Herz.
  sex,

  /// Schmerzen oder Symptome: ein Punkt.
  notiz,
}

/// Ein Tag im Raster.
@immutable
class ZyklusTag {
  const ZyklusTag({
    required this.tag,
    required this.nummer,
    this.zyklustag,
    this.zustand,
    this.marken = const [],
    this.test = false,
    this.heute = false,
  });

  /// Der ISO-Tagesstring — die Tür, die dieser Tag öffnet.
  final String tag;

  /// Die Zahl im Kreis, also der Tag im Monat.
  final int nummer;

  /// Die kleine Zahl oben links. `null` vor der ersten bekannten
  /// Periode.
  final int? zyklustag;

  final ZyklusTagZustand? zustand;
  final List<ZyklusMarke> marken;

  /// Ob an diesem Tag ein Schwangerschaftstest eingetragen ist — egal ob
  /// positiv oder negativ (Tim, 24.11.2026, #598).
  ///
  /// **Ein eigenes Feld und kein sechster [ZyklusTagZustand]:** Ein Tag
  /// kann Blutung **und** Test tragen, ein Enum-Fall könnte das nicht.
  /// Und der Test ist kein Zustand im Sinne der Rechnung — er ist ein
  /// Eintrag, der nichts verschiebt; nur zeigt er sich im Tag statt
  /// darunter, weil Tim ihn dort haben wollte („so grau machen, wie
  /// wenn man seine tage hat in rot").
  final bool test;

  final bool heute;

  @override
  bool operator ==(Object other) =>
      other is ZyklusTag &&
      other.tag == tag &&
      other.nummer == nummer &&
      other.zyklustag == zyklustag &&
      other.zustand == zustand &&
      other.test == test &&
      other.heute == heute &&
      _gleicheMarken(other.marken, marken);

  @override
  int get hashCode => Object.hash(
    tag,
    nummer,
    zyklustag,
    zustand,
    test,
    heute,
    Object.hashAll(marken),
  );

  static bool _gleicheMarken(List<ZyklusMarke> a, List<ZyklusMarke> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Wie kräftig die Fruchtbarkeitszeichen stehen.
enum ZyklusBlaesse {
  /// Natürlicher Zyklus — volle Farben.
  voll,

  /// Unter hormoneller Verhütung: die Fruchtbarkeit wird
  /// zurückgenommen, **die Blutung nicht** — sie ist unter Pille sogar
  /// regelmäßiger, weil sie dem Einnahmeschema folgt.
  fruchtbarkeitBlass,
}

const double _zelleHoehe = 53;
const double _scheibe = 30;

/// Der Ring um den heutigen Tag — **außen herum**, nicht auf der
/// Scheibe (#598). Auf der Scheibe läge er auf dem Rand, den `rand` und
/// `eisprung` dort schon tragen, und genau die beiden sind an einem
/// beliebigen Tag am wahrscheinlichsten.
const double _heuteRing = 36;
const double _heuteUeberstand = (_heuteRing - _scheibe) / 2;

/// Eine Tageszelle.
class ZyklusZelle extends StatelessWidget {
  const ZyklusZelle({
    super.key,
    required this.tag,
    required this.blaesse,
    this.aufTipp,
  });

  final ZyklusTag tag;
  final ZyklusBlaesse blaesse;
  final ValueChanged<String>? aufTipp;

  bool get _fruchtbarkeit =>
      tag.zustand == ZyklusTagZustand.eisprung ||
      tag.zustand == ZyklusTagZustand.fruchtbar;

  double get _deckkraft =>
      blaesse == ZyklusBlaesse.fruchtbarkeitBlass && _fruchtbarkeit
      ? (tag.zustand == ZyklusTagZustand.eisprung ? 0.42 : 0.5)
      : 1;

  @override
  Widget build(BuildContext context) {
    final blut = _farbe(context, Palette.blut);
    final blut2 = _farbe(context, Palette.blut2);
    final river = _farbe(context, Palette.river);
    final flaeche = _farbe(context, Palette.surface);

    Color? fuellung;
    Color ziffer = _farbe(context, Palette.ink);
    Color? randfarbe;

    switch (tag.zustand) {
      case ZyklusTagZustand.eingetragen:
        fuellung = blut;
        ziffer = flaeche;
      case ZyklusTagZustand.vorhergesagt:
        fuellung = blut2;
        ziffer = blut;
      case ZyklusTagZustand.rand:
        randfarbe = blut;
        ziffer = blut;
      case ZyklusTagZustand.eisprung:
        randfarbe = river;
        ziffer = river;
      case ZyklusTagZustand.fruchtbar:
        ziffer = river;
      case null:
        break;
    }

    // **Ein eingetragener Test füllt den Tag grau** (#598, Tim am
    // 24.11.2026: „wenn man nen test hinterlegt kann man das ja so grau
    // machen, wie wenn man seine tage hat in rot — aber sonst ist es
    // ein leerer tag ja, da ist ja sonst nix"). Die neutrale Fläche war
    // bis dahin die Markierung für heute; heute trägt seither einen
    // Ring, siehe unten. Zwei Auskünfte, zwei Formen.
    //
    // **Nur, wenn der Tag keine eigene Füllung hat.** Rosa sagt mehr
    // als Grau, und ein Tag, der ohnehin gefüllt ist, sieht nicht leer
    // aus — der Grund für die Markierung entfällt dort. Der
    // Vorlesetext nennt den Test trotzdem.
    if (tag.test && fuellung == null) {
      fuellung = _farbe(context, Palette.line);
    }

    final scheibe = Opacity(
      opacity: _deckkraft,
      child: Container(
        width: _scheibe,
        height: _scheibe,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: fuellung,
          border: randfarbe == null
              ? null
              // Ein gepunkteter Rand ginge nur über einen CustomPainter;
              // ein dünner durchgezogener Ring in derselben Farbe trägt
              // dieselbe Bedeutung und bleibt bei 30 Punkt lesbar.
              // Unterschieden wird ohnehin über die Füllung: gefüllt
              // heißt eingetragen, ungefüllt heißt geschätzt.
              : Border.all(color: randfarbe, width: 1.6),
        ),
        child: Text(
          '${tag.nummer}',
          style: TextStyle(
            fontSize: 13,
            fontWeight: tag.heute ? FontWeight.w700 : FontWeight.w400,
            color: ziffer,
          ),
        ),
      ),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: aufTipp == null ? null : () => aufTipp!(tag.tag),
      child: Semantics(
        button: aufTipp != null,
        label: _vorlesetext(),
        excludeSemantics: true,
        child: SizedBox(
          height: _zelleHoehe,
          child: Column(
            children: [
              const SizedBox(height: 5),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  // **Heute ist ein Ring um den Tag** (#601, Form seit
                  // #598). Bis zum 24.11.2026 war es eine neutrale
                  // Fläche; die braucht seither der eingetragene Test.
                  //
                  // Der Ring liegt **außerhalb** der Scheibe und nicht
                  // auf ihr: Auf ihr träfe er den Rand, den `rand` und
                  // `eisprung` dort tragen, und der heutige Tag ist
                  // überdurchschnittlich oft einer von beiden. Er ist
                  // `Positioned`, bestimmt also die Größe des `Stack`
                  // nicht mit — die Zelle behält ihre feste Höhe.
                  //
                  // `Palette.muted` statt `Palette.line`: Rosa heißt
                  // Blutung, Türkis Fruchtbarkeit, `line` ist seit #598
                  // der Test. `muted` ist das dunklere Grau und steht
                  // sich gegen beide Akzente durch, ohne laut zu sein.
                  if (tag.heute)
                    Positioned(
                      top: -_heuteUeberstand,
                      left: -_heuteUeberstand,
                      child: Container(
                        width: _heuteRing,
                        height: _heuteRing,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _farbe(context, Palette.muted),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  scheibe,
                  if (tag.zyklustag != null)
                    Positioned(
                      top: -5,
                      left: -6,
                      child: _Plakette(
                        zahl: tag.zyklustag!,
                        fuellung: tag.zustand == ZyklusTagZustand.eingetragen
                            ? blut
                            : tag.zustand == ZyklusTagZustand.eisprung
                            ? river
                            : null,
                        schrift:
                            tag.zustand == ZyklusTagZustand.eingetragen ||
                                tag.zustand == ZyklusTagZustand.eisprung
                            ? flaeche
                            : _farbe(context, Palette.muted),
                        deckkraft: _deckkraft,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              SizedBox(
                height: 12,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final marke in tag.marken)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1.5),
                        child: marke == ZyklusMarke.sex
                            ? Icon(
                                CupertinoIcons.heart_fill,
                                size: 9,
                                color: blut,
                              )
                            : Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _farbe(context, Palette.muted),
                                ),
                              ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// **Der Vorlesetext nennt den Zustand, nicht das Zeichen**
  /// (`CLAUDE.md`): „geschätzter Eisprung", nicht „türkiser Kreis".
  String _vorlesetext() {
    final teile = <String>['${tag.nummer}.'];
    if (tag.heute) teile.add('heute');
    switch (tag.zustand) {
      case ZyklusTagZustand.eingetragen:
        teile.add('Blutung eingetragen');
      case ZyklusTagZustand.vorhergesagt:
        teile.add('Blutung vorhergesagt');
      case ZyklusTagZustand.rand:
        teile.add('Blutung möglich');
      case ZyklusTagZustand.eisprung:
        teile.add('geschätzter Eisprung');
      case ZyklusTagZustand.fruchtbar:
        teile.add('geschätzt fruchtbar');
      case null:
        break;
    }
    if (blaesse == ZyklusBlaesse.fruchtbarkeitBlass && _fruchtbarkeit) {
      teile.add('unsicher wegen hormoneller Verhütung');
    }
    if (tag.zyklustag != null) teile.add('Zyklustag ${tag.zyklustag}');
    if (tag.marken.contains(ZyklusMarke.sex)) teile.add('Sex eingetragen');
    if (tag.marken.contains(ZyklusMarke.notiz)) {
      teile.add('Beschwerden eingetragen');
    }
    // **Ohne Ergebnis** (#598): Dass getestet wurde, steht im Raster;
    // was dabei herauskam, steht in der Lagezeile. Ein Vorlesetext, der
    // „positiv" sagt, sagt es laut und in einem vollen Bus.
    if (tag.test) teile.add('Test eingetragen');
    return teile.join(', ');
  }
}

class _Plakette extends StatelessWidget {
  const _Plakette({
    required this.zahl,
    required this.schrift,
    required this.deckkraft,
    this.fuellung,
  });

  final int zahl;
  final Color schrift;
  final double deckkraft;
  final Color? fuellung;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: deckkraft,
    child: Container(
      constraints: const BoxConstraints(minWidth: 14),
      height: 14,
      padding: const EdgeInsets.symmetric(horizontal: 3),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fuellung,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        '$zahl',
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w500,
          color: schrift,
        ),
      ),
    ),
  );
}

/// Ein Monat: Kopf mit Pfeilen, Wochentage, Raster.
class ZyklusMonat extends StatelessWidget {
  const ZyklusMonat({
    super.key,
    required this.monat,
    required this.vorlauf,
    required this.tage,
    this.blaesse = ZyklusBlaesse.voll,
    this.aufTipp,
    this.aufFrueher,
    this.aufSpaeter,
  });

  /// Die Überschrift, etwa „November".
  final String monat;

  /// Leere Felder vor dem Monatsersten.
  final int vorlauf;

  final List<ZyklusTag> tage;
  final ZyklusBlaesse blaesse;
  final ValueChanged<String>? aufTipp;
  final VoidCallback? aufFrueher;
  final VoidCallback? aufSpaeter;

  static const _wochentage = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

  @override
  Widget build(BuildContext context) {
    final gedaempft = _farbe(context, Palette.muted);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _Pfeil(
                vor: false,
                aktiv: aufFrueher != null,
                aufTipp: aufFrueher,
              ),
              Expanded(
                child: Text(
                  monat,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    color: _farbe(context, Palette.ink),
                  ),
                ),
              ),
              _Pfeil(vor: true, aktiv: aufSpaeter != null, aufTipp: aufSpaeter),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (final kuerzel in _wochentage)
                Expanded(
                  child: Text(
                    kuerzel,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: gedaempft),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 3),
          // **`mainAxisExtent`, nicht `childAspectRatio`** (#601): Das
          // Seitenverhältnis koppelt die Zeilenhöhe an die
          // Spaltenbreite, und die Spalte ist ein Siebtel des Schirms.
          // Je breiter das Gerät, desto höher die Zeile — Weißraum, der
          // mit der Gerätebreite wächst, und alles darunter rutscht
          // nach unten. Die Zelle hat eine feste Höhe, also bekommt die
          // Zeile dieselbe; dann bleibt bei sechs Zeilen auch kein Rest.
          GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            // **`padding: EdgeInsets.zero`, und das ist kein Schönheits-
            // wunsch** (#601, zweiter Anlauf): Ein `ScrollView` ohne
            // eigenes `padding` übernimmt die `MediaQuery`-SafeArea als
            // Innenabstand — oben die Navigationsleiste, unten den
            // Home-Indikator. Gemessen auf dem iPhone 17 Pro: Der
            // Rasteranfang lag bei 100, die erste Zelle erst bei 144.
            // Der Leerraum sitzt also **im** Raster, nicht zwischen den
            // Zeilen, und er wächst mit der Gerätekante. Dass der
            // Schirm schon ein `GlasAbstand`-Padding trägt, macht es
            // doppelt.
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisExtent: _zelleHoehe,
            ),
            children: [
              for (var i = 0; i < vorlauf; i++)
                const SizedBox(height: _zelleHoehe),
              for (final tag in tage)
                ZyklusZelle(tag: tag, blaesse: blaesse, aufTipp: aufTipp),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pfeil extends StatelessWidget {
  const _Pfeil({required this.vor, required this.aktiv, this.aufTipp});

  final bool vor;
  final bool aktiv;
  final VoidCallback? aufTipp;

  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: EdgeInsets.zero,
    minimumSize: const Size(44, 36),
    onPressed: aktiv ? aufTipp : null,
    child: Icon(
      vor ? CupertinoIcons.chevron_right : CupertinoIcons.chevron_left,
      size: 17,
      color: _farbe(context, aktiv ? Palette.river : Palette.line),
      semanticLabel: vor ? 'Nächster Monat' : 'Voriger Monat',
    ),
  );
}

/// Die Legende unter dem Raster. Erklärt die **Formen**, nicht die
/// Farben — dass gepunktet „geschätzt" heißt, ist das, was man einmal
/// lesen muss; dass Rosa die Blutung ist, sieht man.
///
/// Sie ist die eine Erklärung, die **nicht** hinter das Fragezeichen
/// wandert (Tim, 23.11.2026: „lass die da, dann sieht es besser aus").
class ZyklusLegende extends StatelessWidget {
  const ZyklusLegende({super.key});

  @override
  Widget build(BuildContext context) {
    final blut = _farbe(context, Palette.blut);
    final blut2 = _farbe(context, Palette.blut2);
    final river = _farbe(context, Palette.river);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
      child: Wrap(
        spacing: 16,
        runSpacing: 9,
        children: [
          _Probe(fuellung: blut, text: 'eingetragen'),
          _Probe(fuellung: blut2, text: 'vorhergesagt'),
          _Probe(rand: blut, text: 'kann auch hier sein'),
          _Probe(rand: river, text: 'geschätzter Eisprung'),
        ],
      ),
    );
  }
}

class _Probe extends StatelessWidget {
  const _Probe({required this.text, this.fuellung, this.rand});

  final String text;
  final Color? fuellung;
  final Color? rand;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 15,
        height: 15,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: fuellung,
          border: rand == null ? null : Border.all(color: rand!, width: 1.6),
        ),
      ),
      const SizedBox(width: 6),
      Text(
        text,
        style: TextStyle(fontSize: 12.5, color: _farbe(context, Palette.muted)),
      ),
    ],
  );
}
