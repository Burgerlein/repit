/// Das gemeinsame Diagramm-Bauteil: Zeitraumleiste, Kopfzeile, Graph,
/// Fußzeile — Dart-Entsprechung von `chartCard` in
/// `docs/screens/components.js` und der Entwurfs-Spec
/// `docs/superpowers/specs/2026-10-13-graphen-zeitraum-und-ablesen-design.md`.
///
/// **Die Rechnung liegt nicht hier.** Stufen, Verdichtung, Rastgrenze und
/// Startfenster kommen aus `../shell/diagramm_zeitraum.dart` und darunter aus
/// `ChartBuckets`/`BerlinCalendar`; die Fensterbuchhaltung darüber —
/// Rastschritte, Plätze, Achsenbeschriftung — liegt in
/// `zeitdiagramm_fenster.dart`, das Zeichnen in
/// `zeitdiagramm_zeichnung.dart`. Diese Datei hält den Zustand, baut die
/// Kopfzeile und nimmt Gesten entgegen; sie bestimmt keine Kalendergrenze
/// selbst.
///
/// ## Die zwei Gesten
///
/// 1. **Ziehen blättert** — der Inhalt läuft **mit dem Finger** mit, Platz
///    für Platz, und rastet beim Loslassen auf einen ganzen Platz ein. Ein
///    Platz ist bei `W` und `M` ein Kalendertag, ab `6M` ein Kalendermonat;
///    so weit, wie ein Balken breit ist, so weit blättert ein Zug.
///
///    **Das war bis zum 28.10.2026 anders**: Ein Wisch über die volle Breite
///    war genau ein Fenster, kürzere Wische runden auf ganze Rastschritte —
///    bei `W` also auf ganze Wochen. Tim hat die App im Release-Build auf
///    dem iPhone geprüft: „das wischen reagiert komisch ich muss sehr weit
///    wischen und es fühlt sich nicht flüssig an" (#145). Die alte Regel war
///    kein Versehen, sondern mit „Ein Fenster, das mitten in der Woche
///    beginnt, lässt sich nicht mit dem Nachbarfenster vergleichen" (Spec)
///    begründet — eine Entscheidung ohne Gerät. Dieselbe Spec sieht eine
///    Zeile weiter „langsam gezogen bleibt stehen" vor.
///
///    **Das Einrasten selbst bleibt.** Ein Zug unter einem halben Platz
///    federt zurück; zwischen zwei Tagen bleibt das Fenster nie stehen.
/// 2. **Halten wählt aus** — die Kopfzeile zeigt dann Datum und Wert des
///    Balkens und springt beim Loslassen zurück. Über einer Lücke steht
///    „keine Messung", nie der Nachbarwert.
///
/// Beide liegen in **einem** `GestureDetector`, also in einer Gestenarena:
/// Bewegt sich der Finger, gewinnt das Schieben; bleibt er liegen, gewinnt
/// nach einer halben Sekunde das Halten. In SwiftUI hat `.chartGesture` die
/// eingebauten Gesten einschließlich des Scrollens ersetzt, und der Graph
/// ließ sich nicht mehr schieben (Spec, „Der Rahmen") — deshalb steht das
/// hier ausdrücklich.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:intl/intl.dart' show NumberFormat;
import 'package:trainings_core/trainings_core.dart';

import '../shell/diagramm_zeitraum.dart';
import 'diagramm_auswahl.dart';
import 'formatierung.dart';
import 'palette.dart';
import 'zeitdiagramm_fenster.dart';
import 'zeitdiagramm_geruest.dart';
import 'zeitdiagramm_leiste.dart';

// Die festgelegte API ist `import '…/design/zeitdiagramm.dart'` — die
// Leiste und die Ziellinie kommen von dort, auch wenn sie nebenan wohnen.
export 'zeitdiagramm_leiste.dart';
import 'zeitdiagramm_zeichnung.dart';

/// Leiste, Kopfzeile, Graph und Fußzeile in einem.
///
/// Die Kopfzeile steht unter `Key('diagramm-kopfzeile')`, die Fußzeile unter
/// `Key('diagramm-fussnote')`. **Dazwischen liegt der Graph ohne Luft** — die
/// Abstände tragen Kopf- und Fußzeile selbst, damit das Band zwischen beiden
/// genau die Fläche ist, auf der die Gesten liegen.
class Zeitdiagramm extends StatefulWidget {
  const Zeitdiagramm({
    super.key,
    required this.reihe,
    required this.stufen,
    required this.fussnote,
    this.fussnoteZeilen,
    this.alsBalken = true,
    this.linien = const [],
    this.einheit = '',
    this.einheitAbgelesen,
    this.kopfzahl,
    this.verdichtung = ChartAggregation.mean,
    this.zweiteReihe = const [],
    this.zweiteFarbe = Palette.iron,
    this.stapelReihe = const [],
    this.stapelFarben = const [],
    this.balkenZiel,
    this.balkenZielFarbe = Palette.ok,
    this.anfangsStufe,
    this.onStufe,
  });

  /// Tageswerte, unsortiert erlaubt. Lücken bleiben Lücken: Ein Tag ohne
  /// Messung fehlt in der Liste, er steht nicht mit 0 darin.
  final List<({DateTime tag, double wert})> reihe;

  /// Welche Stufen der Schirm anbietet; die **kleinste** ist die Startstufe
  /// (`startStufe`).
  final List<DiagrammStufe> stufen;

  /// Den Wortlaut der Fußzeile liefert der Schirm — das Bauteil kennt die
  /// Herkunft der Zahlen nicht. Gefragt wird mit der **gerade gewählten**
  /// Stufe.
  final String Function(DiagrammStufe stufe) fussnote;

  /// Feste Zeilenzahl der Fußzeile — durchgereicht an
  /// [ZeitdiagrammGeruest.fussnoteZeilen], dort begründet. `null` heißt:
  /// natürliche Höhe, wie bisher.
  final int? fussnoteZeilen;

  /// Balken (Schritte, Trainingsminuten) oder Linie (Gewicht, Umfänge).
  final bool alsBalken;

  final List<Ziellinie> linien;

  /// Die Einheit neben der Zahl in der Kopfzeile — `min / Tag`, `kg`, `ms`.
  /// Leer heißt: keine.
  ///
  /// **Wo keine Zahl steht, steht auch keine Einheit.** Über einer Lücke und
  /// bei leerer Reihe fällt sie weg; eine Einheit ohne Zahl behauptet eine
  /// Messung, die es nicht gab (`docs/todo/01`).
  final String einheit;

  /// Die Einheit, die beim Ablesen eines einzelnen Balkens an ihre Stelle
  /// tritt. `null` heißt: dieselbe wie [einheit].
  ///
  /// Zwei Felder, weil „9.096 Schritte **/ Tag**" über einem einzelnen Balken
  /// falsch wäre — das ist der Wert *dieses* Tages, kein Durchschnitt je Tag.
  /// Das zweite ist trotzdem optional: Bei `kg`, `ms` und `bpm` ist die
  /// Einheit in beiden Zuständen dieselbe, und ein Literal zweimal
  /// hinschreiben zu müssen ist genau die Stelle, an der eines veraltet.
  final String? einheitAbgelesen;

  /// Wie die Zahl in der Kopfzeile geschrieben wird. `null` heißt: deutsch
  /// gruppiert, ohne Nachkommastelle, sobald sie keine trägt.
  ///
  /// **Wozu der Haken** (#151): Beim Schlaf stand dort „6,7", richtig wäre
  /// „6:40" — Stunden und Minuten. Tims Entscheidung vom 28.10.2026, und
  /// ausdrücklich gegen die billigere Lösung (`einheit: 'h Schlaf /
  /// Nacht'`): „6,7 h" ist eben nicht „6:40".
  ///
  /// Er bekommt die **Zahl**, nicht den fertigen Text — aus „6,7" ließe sich
  /// „6:40" nicht mehr zurückrechnen.
  ///
  /// Er gilt für den Durchschnitt wie für den abgelesenen Balken: Zwei
  /// Formate in derselben Zeile wären keine. Was sich zwischen beiden
  /// Zuständen unterscheidet, ist die Einheit — dafür gibt es [einheit] und
  /// [einheitAbgelesen].
  ///
  /// **Wo keine Zahl steht, wird er nicht gefragt.** Über einer Lücke steht
  /// „keine Messung", bei leerer Reihe „—"; eine erfundene 0 ergäbe beim
  /// Schlaf „0:00" und behauptete eine Messung, die es nicht gab — der
  /// Fehler `01`, eine Ebene tiefer als dort, wo `Messwert<T>` ihn sieht.
  final String Function(double wert)? kopfzahl;

  /// Wie die Messwerte eines Monats ab `6M` zu einem Punkt werden. Vorgabe
  /// ist das Mittel — das Verhalten aller bisherigen Aufrufer.
  ///
  /// **Mit `max` bekommt auch die Kopfzeile den Höchstwert statt des
  /// Durchschnitts** der gezeigten Punkte: Das Mittel von Monatsmaxima wäre
  /// ein Gewicht, das nie auf der Stange lag (`docs/SPEC.md` 4.4, Board-Nr.
  /// 18). Die Art geht an `diagrammPunkte` und von dort an `ChartBuckets`;
  /// das Bauteil rechnet nichts nach.
  final ChartAggregation verdichtung;

  /// Eine zweite Reihe in derselben Form wie [reihe], **gestrichelt** auf
  /// derselben y-Skala und ebenso verdichtet (#93: das geschätzte 1RM neben
  /// dem Höchstgewicht). Leer heißt: keine.
  ///
  /// **Lücken bleiben Lücken:** Wo ein Tag keinen zweiten Wert hat, fehlt
  /// der Punkt, und über ihn hinweg wird nicht verbunden. **Die Kopfzeile
  /// gehört zur ersten Reihe** — die zweite hat auf dem Schirm ihre
  /// eigene Kachel.
  final List<({DateTime tag, double wert})> zweiteReihe;

  /// Die Farbe der gestrichelten Linie.
  final CupertinoDynamicColor zweiteFarbe;

  /// Je Tag die **Teile**, nach denen sein Balken in sich geteilt wird
  /// (#504) — in derselben Einheit wie [reihe], nicht in Prozent. Leer
  /// heißt: keine Teilung, jeder Balken steht einfarbig da.
  ///
  /// **Das ist keine zweite Spur.** [zweiteReihe] läuft *neben* der
  /// ersten auf derselben y-Skala; ein Stapel liegt *in* seinem Balken.
  /// Der Schlaf-Verlauf braucht das zweite: Die Höhe eines Balkens bleibt
  /// die Schlafdauer, und die Phasen teilen diese Höhe anteilig
  /// (Tim am 13.11.2026 — „nur die Balken so einfärben wie die Phasen,
  /// damit man sieht, wie die prozentual drin waren").
  ///
  /// **In der Einheit der Reihe, nicht in Prozent**, weil sich ab `6M`
  /// Minuten über einen Kalendermonat aufsummieren lassen und Anteile
  /// nicht: Ein Mittel über Nachtanteile wöge die kurze Nacht so schwer
  /// wie die lange. Normiert wird ganz am Ende, in `stapelGrenzen`.
  ///
  /// **Ein Tag, der hier fehlt, bekommt keinen Stapel** — sein Balken
  /// steht einfarbig da. Eine erfundene Verteilung wäre schlimmer als
  /// keine (`CLAUDE.md`, Fehler `01`).
  ///
  /// Gilt nur bei [alsBalken]: Eine Linie hat keine Fläche, die sich
  /// teilen ließe.
  ///
  /// **Nur für Reihen, die nicht unter die Null gehen.** Ein Stapel wird
  /// von der Nulllinie aus nach außen gefüllt; bei einem negativen
  /// Messwert liegt Teil 0 am abgewandten Ende, der Stapel stünde also
  /// spiegelverkehrt zum positiven Nachbarn. Kein Aufrufer tut das —
  /// Schlafstunden sind positiv, und `schlafTagewerte` lässt eine Nacht
  /// ohne Schlaf ganz weg —, aber es ist eine Voraussetzung und keine
  /// Eigenschaft, die der Code erzwingt.
  final List<({DateTime tag, List<double> teile})> stapelReihe;

  /// Die Farbe je Teil, in derselben Reihenfolge wie die Teile in
  /// [stapelReihe].
  final List<CupertinoDynamicColor> stapelFarben;

  /// Färbt Balken um, deren Wert dieses Ziel erreicht (#84: „Grün, sobald
  /// der Tag das Ziel erreicht", `StepsView.barColor` in der
  /// Swift-Vorlage). `null` heißt: keine Einfärbung — richtig überall
  /// dort, wo ein Balken keine Tagessumme (oder kein Tagesdurchschnitt)
  /// ist: Ein Tagesziel gegen eine kleinere Einheit zu messen hieße, jede
  /// für gescheitert zu erklären.
  ///
  /// Ein Wert und keine Funktion, aus demselben Grund wie
  /// [Ziellinie.wertText]: Eine Closure wäre nie gleich der des vorigen
  /// Baus, und jedes Bild zeichnete neu (`docs/todo/03`).
  final double? balkenZiel;

  /// Die Farbe der Balken, die [balkenZiel] erreichen.
  final CupertinoDynamicColor balkenZielFarbe;

  /// Die Stufe, mit der das Bauteil aufschlägt. `null` heißt: die kleinste
  /// angebotene ([startStufe]).
  ///
  /// Der Schirm gibt sie vor, wenn er mehr über den Verlauf weiß als das
  /// Bauteil — beim Fortschritt richtet sich die Startstufe nach der Länge
  /// des Verlaufs (`docs/SPEC.md` 4.4). Gilt nur beim Aufbau des Zustands;
  /// eine spätere Änderung wirft die Wahl des Nutzers nicht um. Nicht
  /// angebotene Stufen fallen auf die Vorgabe zurück.
  final DiagrammStufe? anfangsStufe;

  /// Wird gerufen, wenn der Nutzer eine **andere** Stufe wählt — damit ein
  /// Schirm, dessen Kacheln dasselbe Ende nennen sollen wie die Linie,
  /// dieselbe Stufe kennt. Die Startstufe meldet es nicht.
  final ValueChanged<DiagrammStufe>? onStufe;

  @override
  State<Zeitdiagramm> createState() => _ZeitdiagrammState();
}

class _ZeitdiagrammState extends State<Zeitdiagramm> {
  /// Die gewählte Stufe lebt hier, nicht in der Leiste.
  late DiagrammStufe _stufe;

  /// Wie viele **Plätze** das Fenster hinter dem Startfenster liegt — bei
  /// `W` und `M` Kalendertage, ab `6M` Kalendermonate. 0 ist das jüngste
  /// Fenster, größer heißt weiter in der Vergangenheit.
  int _verschiebung = 0;

  /// Der laufende Zug in Punkten; erst beim Loslassen wird daraus ein ganzer
  /// Platz. Solange er läuft, wandert das Bild mit dem Finger.
  double _zieh = 0;

  /// Der gehaltene Platz im Fenster, `null` ohne Auswahl.
  int? _auswahl;

  final GlobalKey _graphKey = GlobalKey();

  /// Alles Abgeleitete in einem Stück — gehalten, nicht je Bild gerechnet
  /// (`CLAUDE.md`, Regel 2). Die Rechnung steht in `zeitdiagramm_fenster.dart`.
  late Fensterstand _stand;

  /// Der Ausschnitt, der gerade im Bild steht, und was daraus folgt.
  ///
  /// **Gehalten, nicht je Bild gerechnet** (`CLAUDE.md`, Regel 2). Während
  /// eines Zuges ändert sich der Versatz mit jedem Bild, der *ganzzahlige*
  /// Ausschnitt aber nur, wenn ein Platz über den Rand wandert — bei `W`
  /// also höchstens siebenmal je Wochenzug statt 120-mal je Sekunde.
  /// `achse()` baut je Platz eine Beschriftung über `Format`, und das ist
  /// die teuerste Zeile auf diesem Weg.
  (int, int) _ausschnitt = (0, 0);
  late (double, double) _grenzen;
  late List<({int platz, String text})> _achse;

  /// Durchschnitt und Zeitraum des gezeigten Ausschnitts — was die Kopfzeile
  /// ohne Auswahl nennt.
  ///
  /// Hängt an **derselben** Stelle wie `_grenzen` und `_achse` und wird mit
  /// ihnen zusammen nachgezogen: Rechnete die Kopfzeile je Bild, wäre das
  /// `docs/todo/03`; rechnete sie an einer anderen Stelle, könnte sie einen
  /// anderen Ausschnitt meinen als die Achse darunter (#150).
  late ({DateTime? von, DateTime? bis, double? schnitt}) _ueberblick;

  @override
  void initState() {
    super.initState();
    final vorgabe = widget.anfangsStufe;
    _stufe = vorgabe != null && widget.stufen.contains(vorgabe)
        ? vorgabe
        : startStufe(widget.stufen);
    _neuRechnen();
  }

  @override
  void didUpdateWidget(covariant Zeitdiagramm alt) {
    super.didUpdateWidget(alt);
    if (!listEquals(alt.stufen, widget.stufen) &&
        !widget.stufen.contains(_stufe)) {
      _stufe = startStufe(widget.stufen);
      _verschiebung = 0;
      _auswahl = null;
    }
    if (!listEquals(alt.reihe, widget.reihe) ||
        !listEquals(alt.zweiteReihe, widget.zweiteReihe) ||
        !listEquals(alt.stapelReihe, widget.stapelReihe) ||
        alt.verdichtung != widget.verdichtung ||
        !listEquals(alt.stufen, widget.stufen)) {
      _neuRechnen();
    } else if (!listEquals(alt.linien, widget.linien) ||
        alt.alsBalken != widget.alsBalken) {
      // Die Ziellinien spannen die y-Achse mit auf; ändern sie sich, ohne
      // dass das Fenster sich ändert, muss der gehaltene Wert trotzdem neu.
      _zeichenstandNeu();
    }
  }

  /// Den Stand neu rechnen lassen. Die Verschiebung kommt geklemmt zurück —
  /// hinter dem linken Anschlag stünde der Schirm auf leerer Fläche.
  void _neuRechnen() {
    _stand = Fensterstand.aus(
      reihe: widget.reihe,
      stufe: _stufe,
      verschiebung: _verschiebung,
      zweiteReihe: widget.zweiteReihe,
      stapelReihe: widget.stapelReihe,
      verdichtung: widget.verdichtung,
    );
    _verschiebung = _stand.verschiebung;
    if (_stand.von == null) _auswahl = null;
    _ausschnitt = _stand.sichtbar(_versatzPlaetze);
    _zeichenstandNeu();
  }

  /// y-Grenzen, Achsenbeschriftung und Kopfzeile für den gerade gezeigten
  /// Ausschnitt — **alle drei aus demselben `_ausschnitt`**.
  void _zeichenstandNeu() {
    _grenzen = _stand.grenzen(
      linien: [for (final linie in widget.linien) linie.wert],
      alsBalken: widget.alsBalken,
      ausschnitt: _ausschnitt,
    );
    _achse = _stand.achse(_ausschnitt);
    _ueberblick = _stand.ueberblick(_ausschnitt);
  }

  /// Nachziehen, sobald der Zug einen ganzen Platz über den Rand geschoben
  /// hat. Je Bild aufgerufen, rechnet aber nur dann etwas.
  void _ausschnittPruefen() {
    final neu = _stand.sichtbar(_versatzPlaetze);
    if (neu == _ausschnitt) return;
    _ausschnitt = neu;
    _zeichenstandNeu();
  }

  // ── Gesten ──────────────────────────────────────────────────────────────

  double? get _breite {
    final box = _graphKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || box.size.width <= 0) return null;
    return box.size.width;
  }

  /// Wie breit ein Platz gezeichnet wird — dieselbe Rechnung wie im Maler
  /// (`size.width / plaetze`, und `plaetze` ist dort `_stand.gezeichnet`).
  ///
  /// Daran hängt die Übersetzung von Fingerweg in Kalenderschritte: **ein
  /// Balken weit gezogen ist ein Platz weiter**. Genau das macht den Zug so
  /// kurz, wie Tim ihn erwartet (#145), und es ist zugleich die einzige
  /// Übersetzung, bei der der Inhalt dem Finger wirklich folgt.
  double? get _proPlatz {
    final breite = _breite;
    if (breite == null || _stand.gezeichnet <= 0) return null;
    return breite / _stand.gezeichnet;
  }

  /// Der laufende Zug in Plätzen statt in Punkten.
  double get _versatzPlaetze {
    final proPlatz = _proPlatz;
    return proPlatz == null ? 0 : _zieh / proPlatz;
  }

  void _waehle(double dx) {
    final breite = _breite;
    if (breite == null) return;
    final platz = platzUnterFinger(
      dx: dx,
      breite: breite,
      gezeichnet: _stand.gezeichnet,
      plaetze: _stand.plaetze,
    );
    if (platz == null || platz == _auswahl) return;
    setState(() => _auswahl = platz);
  }

  void _loslassen() {
    if (_auswahl == null) return;
    setState(() => _auswahl = null);
  }

  void _ziehEnde() {
    // Immer rasten — nur eben auf einen **Platz**, nicht auf ein Fenster.
    // Ein Zug unter einem halben Platz ergibt null Schritte und federt
    // zurück; zwischen zwei Tagen bleibt das Fenster nie stehen.
    final schritte = _versatzPlaetze.round();
    final neu = (_verschiebung + schritte).clamp(0, _stand.maxVerschiebung);
    setState(() {
      _zieh = 0;
      if (neu != _verschiebung) {
        _verschiebung = neu;
        _auswahl = null;
        _neuRechnen();
      } else {
        // Nichts geblättert — dann bleibt `diagrammPunkte` auch ungerechnet
        // (`CLAUDE.md`, Regel 2). Nur der Ausschnitt federt aufs Fenster
        // zurück, und auch das nur, wenn er überhaupt abgewichen war.
        _ausschnittPruefen();
      }
    });
  }

  void _stufeWechseln(DiagrammStufe stufe) {
    if (stufe == _stufe) return;
    setState(() {
      _stufe = stufe;
      _verschiebung = 0;
      _zieh = 0;
      // Ein Balken aus der Wochenansicht hat im Halbjahr keine Entsprechung.
      _auswahl = null;
      _neuRechnen();
    });
    widget.onStufe?.call(stufe);
  }

  // ── Kopfzeile ───────────────────────────────────────────────────────────

  /// Die Zahl in der Kopfzeile, wie der Schirm sie geschrieben haben will —
  /// sonst wie bisher (#151).
  ///
  /// **Nur aufgerufen, wo eine Zahl steht.** „keine Messung" und „—" gehen
  /// nicht hier durch; ein Haken, der mit einer erfundenen 0 gefragt würde,
  /// schriebe beim Schlaf „0:00".
  String _kopfzahl(double wert) => widget.kopfzahl?.call(wert) ?? _zahl(wert);

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final river = CupertinoDynamicColor.resolve(Palette.river, context);
    final abgelesen = _stand.abgelesen(_auswahl);

    final String kicker;
    final String wert;
    final String zeitraum;
    // Wo keine Zahl steht, steht auch keine Einheit: Über einer Lücke und bei
    // leerer Reihe behauptete sie eine Messung, die es nicht gab.
    final String einheit;
    if (abgelesen != null) {
      // „Bei Auswahl nennt der Kopf den Tag statt ‚Durchschnitt', und der
      // Wert steht in Flussblau" (`chartCard` im Entwurfsboard).
      kicker = nachTagen(_stufe)
          ? Format.wochentagUndDatum(kalendertag(abgelesen.beginn))
          : Format.datumAusgeschrieben(kalendertag(abgelesen.beginn));
      wert = abgelesen.wert == null
          ? 'keine Messung'
          : _kopfzahl(abgelesen.wert!);
      einheit = abgelesen.wert == null
          ? ''
          : (widget.einheitAbgelesen ?? widget.einheit);
      zeitraum = '';
    } else {
      // **Der gezeigte Ausschnitt, nicht das Fenster** (#150): Achse und
      // y-Skala laufen seit #147 beim Ziehen mit, die Kopfzeile blieb
      // stehen. Alle drei kommen jetzt aus `_ausschnitt`.
      final schnitt = _ueberblick.schnitt;
      // Über Monatsmaxima ist der Durchschnitt das Mittel der Höchstwerte —
      // genau die Zahl, die `docs/SPEC.md` 4.4 ablehnt.
      kicker = widget.verdichtung == ChartAggregation.max
          ? 'Höchstwert'
          : 'Durchschnitt';
      wert = schnitt == null ? '—' : _kopfzahl(schnitt);
      einheit = schnitt == null ? '' : widget.einheit;
      final von = _ueberblick.von, bis = _ueberblick.bis;
      zeitraum = von == null || bis == null
          ? ''
          : '${Format.tagMonat(kalendertag(von))} – '
                '${Format.tagMonat(kalendertag(BerlinCalendar.addDays(bis, -1)))}';
    }

    return ZeitdiagrammGeruest(
      leiste: Zeitraumleiste(
        stufen: widget.stufen,
        gewaehlt: _stufe,
        onWaehle: _stufeWechseln,
      ),
      kopf: DiagrammKopf(
        ueberschrift: kicker,
        wert: wert,
        einheit: einheit,
        unterzeile: zeitraum,
        abgelesen: abgelesen != null,
      ),
      graphKey: _graphKey,
      // **Unter der Fußzeile steht nichts.** Hier stand bis zum 28.10.2026
      // „Halten zeigt den Einzelwert" — eine Zeile, die beim Ablesen
      // verschwand und alles darunter springen ließ. Tim: „bitte entfern
      // ihn komplett" (#146). Ersatzlos, nicht als reservierter Platz: Dann
      // ist das Springen unausdrückbar statt abgemildert.
      fussnote: widget.fussnote(_stufe),
      fussnoteZeilen: widget.fussnoteZeilen,
      graph: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // `down` statt `start`: Das Bild folgt dem Finger ab dem ersten
        // Punkt, und ein Wisch über die volle Breite ist dann auch ein
        // volles Fenster — mit `start` fehlten die verschluckten Punkte
        // bis zur Annahme der Geste.
        dragStartBehavior: DragStartBehavior.down,
        onHorizontalDragStart: (_) => setState(() {
          _zieh = 0;
          _auswahl = null;
          _ausschnittPruefen();
        }),
        onHorizontalDragUpdate: (einzelheiten) => setState(() {
          _zieh += einzelheiten.delta.dx;
          _ausschnittPruefen();
        }),
        onHorizontalDragEnd: (_) => _ziehEnde(),
        onHorizontalDragCancel: _ziehEnde,
        onLongPressStart: (einzelheiten) =>
            _waehle(einzelheiten.localPosition.dx),
        onLongPressMoveUpdate: (einzelheiten) =>
            _waehle(einzelheiten.localPosition.dx),
        onLongPressEnd: (_) => _loslassen(),
        onLongPressCancel: _loslassen,
        child: CustomPaint(
          size: Size.infinite,
          painter: ZeitdiagrammPainter(
            balken: _stand.balken,
            zweite: _stand.zweite,
            zweiteFarbe: CupertinoDynamicColor.resolve(
              widget.zweiteFarbe,
              context,
            ),
            stapel: _stand.stapel,
            // Aufgelöst, wie jede Farbe, die der Maler bekommt: eine
            // `CupertinoDynamicColor` bliebe dort im Dunkelmodus auf ihrer
            // hellen Variante stehen.
            stapelFarben: [
              for (final farbe in widget.stapelFarben)
                CupertinoDynamicColor.resolve(farbe, context),
            ],
            plaetze: _stand.gezeichnet,
            versatz: _zieh,
            auswahl: _auswahl,
            alsBalken: widget.alsBalken,
            zielWert: widget.balkenZiel,
            zielFarbe: CupertinoDynamicColor.resolve(
              widget.balkenZielFarbe,
              context,
            ),
            // Beide gehören zum **gezeigten** Ausschnitt, nicht zum
            // Fenster vor dem Zug (#147) — und beide sind gehalten,
            // nicht je Bild gerechnet.
            grenzen: _grenzen,
            achse: _achse,
            linien: [
              for (final linie in widget.linien)
                (
                  beschriftung: linie.beschriftung,
                  wert: linie.wert,
                  farbe: CupertinoDynamicColor.resolve(linie.farbe, context),
                ),
            ],
            farbe: river,
            rasterFarbe: CupertinoDynamicColor.resolve(Palette.line, context),
            textFarbe: muted,
            flaeche: CupertinoDynamicColor.resolve(Palette.surface, context),
          ),
        ),
      ),
    );
  }
}

/// Eine Zahl, wie die Kopfzeile sie zeigt: deutsch gruppiert, ohne
/// Nachkommastelle, sobald sie keine trägt.
///
/// Fest auf `de_DE`, aus demselben Grund wie [Format]: Ohne feste Sprache
/// stünde auf einem englisch eingestellten Gerät „1,234.5" im deutschen Text.
String _zahl(double wert) {
  final nachkomma = (wert - wert.roundToDouble()).abs() < 0.05 ? 0 : 1;
  return (NumberFormat.decimalPattern('de_DE')
        ..minimumFractionDigits = nachkomma
        ..maximumFractionDigits = nachkomma)
      .format(wert);
}
