/// Die Fensterbuchhaltung des Diagramm-Bauteils: das Fenster um n Plätze
/// verschieben, der Platz eines Punktes im Fenster, der Ausschnitt während
/// eines laufenden Zuges, Kalendertage und -monate zwischen zwei Grenzen.
///
/// **Warum eine eigene Datei.** `zeitdiagramm.dart` war auf 647 Zeilen
/// gewachsen, und `CLAUDE.md` sagt: „Views bleiben klein." Das Zeichnen liegt
/// schon getrennt in `zeitdiagramm_zeichnung.dart`; dick machte die Datei
/// diese Rechnung. Der Schnitt ist **die Entscheidung des Koordinators von
/// #130**, nicht Tims — er hat sie nie gesehen.
///
/// **Warum nicht in den Kern** (`Packages/trainings_core/`): Das hier ist
/// Viewport-Arithmetik — wie viele Plätze ein Fenster hat, welcher Balken
/// unter dem Finger liegt, welche Beschriftung unter der x-Achse steht. Keine
/// Formel aus `docs/SPEC.md`. Im Kern wäre sie eine Rechnung ohne Fachgehalt.
///
/// **Warum nicht in `../shell/diagramm_zeitraum.dart`**: Dessen API ist
/// committet, von #94 benutzt und durch eine eigene Testdatei festgenagelt.
/// Sie aufzublähen hieße, einen fremden Vertrag zu verbreitern.
///
/// **Keine Kalendergrenze wird hier selbst gerechnet.** Jede Grenze kommt aus
/// `startFenster`, `rastgrenze` oder `BerlinCalendar`; hier wird nur
/// abgezählt und eingeordnet.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:trainings_core/trainings_core.dart';

import '../shell/diagramm_zeitraum.dart';
import 'formatierung.dart';
import 'zeitdiagramm_stapel.dart';

/// Der Anteil der Achsenspanne, der über einer Ziellinie frei bleibt, die
/// über allen Messwerten liegt — und unter einer, die darunter liegt.
///
/// **Woher die Zahl kommt.** Die Zeichenfläche ist 120 Punkt hoch (Bildhöhe
/// 148 aus `docs/screens/components.css`, minus 8 Punkt Luft oben und 20
/// für die Achse). Eine Beschriftung in 9 Punkt beginnt zwölf Punkt über
/// ihrer Linie, also braucht sie **ein Zehntel** der Achse, um unter der
/// obersten Rasterlinie zu bleiben. 0,15 sind 18 Punkt und lassen sechs
/// davon übrig; gemessen hat das Entwurfsboard dasselbe von der anderen
/// Seite: `lineChart` in `docs/screens/components.js` rechnet
/// `rand = 0,18 · Messspanne`, weil bei 0,12 der Hof der Beschriftung noch
/// über die oberste Rasterlinie schob — an seinem Beispiel sind das 14,1
/// statt 9,8 Punkt.
///
/// **Bezug ist die Achsenspanne, nicht die Messspanne.** Darin weicht diese
/// Rechnung vom Board ab (und von `spannenAchsenGrenzen` in
/// `../shell/schlaf_spannen_achse.dart`, das es mit 0,14 wie das Board
/// macht). Ein Anteil der Messspanne hält sein Versprechen nur, solange die
/// Linie dicht über den Werten liegt: Bei sieben Balken à 41 und einem
/// Wochenziel von 250 wären 0,18 · 41 = 7,4 von 257 — drei Punkte im Bild,
/// und die Beschriftung ist wieder abgeschnitten. Auf dem Beispiel, an dem
/// das Board gemessen hat, fallen beide Rechnungen praktisch zusammen
/// (Obergrenze 8,41 statt 8,31); sie gehen erst dort auseinander, wo die
/// Board-Rechnung still versagt. **Dass das Board damit etwas anderes
/// rechnet als die App, ist gemeldet und nicht hier entschieden** — es
/// gehört zur offenen Frage, wie eine Ziellinie beschriftet wird (#162).
const double _ziellinienLuft = 0.15;

/// Ob die Plätze eines Fensters Kalendertage sind (`W`, `M`) oder
/// Kalendermonate (`6M`, `J`).
///
/// Das ist zugleich die **Rastweite**: Ein Zug blättert in Plätzen, also bei
/// `W` und `M` in Kalendertagen und ab `6M` in Kalendermonaten.
bool nachTagen(DiagrammStufe stufe) =>
    stufe == DiagrammStufe.woche || stufe == DiagrammStufe.monat;

/// Kalendertage zwischen zwei Berliner Tagesgrenzen.
///
/// Gezählt wird über `BerlinCalendar.dayKey` und nicht über die verstrichene
/// Zeit: Die Woche ab dem 19.10.2026 hat 169 Stunden, und `inDays` schnitte
/// sie auf sechs Tage herunter. Das ist keine zweite Tagesgrenzenrechnung —
/// die Grenzen kommen aus `BerlinCalendar`, hier wird nur abgezählt.
int tageZwischen(DateTime von, DateTime bis) =>
    kalendertag(bis).difference(kalendertag(von)).inDays;

/// Kalendermonate zwischen zwei Berliner Monatsersten.
int monateZwischen(DateTime von, DateTime bis) {
  final v = kalendertag(von), b = kalendertag(bis);
  return (b.year - v.year) * 12 + (b.month - v.month);
}

/// Das Fenster, um `schritte` **Plätze** zurückgeschoben — bei `W` und `M`
/// Kalendertage, ab `6M` Kalendermonate.
///
/// **Ein Platz, kein Fenster** (geändert am 28.10.2026, #145). Bis dahin war
/// ein Schritt ein ganzes Fenster: bei `W` sieben Tage, bei `6M` sechs
/// Monate. Tim auf dem Gerät: „das wischen reagiert komisch ich muss sehr
/// weit wischen und es fühlt sich nicht flüssig an". Ein Fenster darf
/// seither mitten in der Woche beginnen — genau das, was die Entwurfs-Spec
/// unter „Einrasten" als „langsam gezogen bleibt stehen" ohnehin vorsah.
///
/// Gezählt wird in Kalenderschritten, nie in Sekunden: Die Woche ab dem
/// 19.10.2026 hat 169 Stunden, der März 2026 743.
(DateTime, DateTime) _verschobenesFenster(
  DateTime von0,
  DateTime bis0,
  DiagrammStufe stufe,
  int schritte,
) => nachTagen(stufe)
    ? (
        BerlinCalendar.addDays(von0, -schritte),
        BerlinCalendar.addDays(bis0, -schritte),
      )
    : (
        BerlinCalendar.addMonths(von0, -schritte),
        BerlinCalendar.addMonths(bis0, -schritte),
      );

/// Alles, was aus Reihe, Stufe und Verschiebung folgt — in **einem** Stück
/// gerechnet und gehalten.
///
/// `CLAUDE.md`, Regel 2: Was eine Ansicht anbietet, wird gehalten, nicht bei
/// jedem Zugriff gerechnet. `diagrammPunkte` läuft über die ganze Reihe —
/// während eines Wisches liefe das sonst je Bild, und das wäre `docs/todo/03`
/// wortgleich im neuen Code.
@immutable
class Fensterstand {
  const Fensterstand({
    required this.stufe,
    required this.von,
    required this.bis,
    required this.plaetze,
    required this.gezeichnet,
    required this.balken,
    required this.gewichte,
    required this.schnitt,
    required this.verschiebung,
    required this.maxVerschiebung,
    this.zweite = const [],
    this.stapel = const [],
    this.verdichtung = ChartAggregation.mean,
  });

  /// Der Stand ohne einen einzigen Messwert: kein Fenster, kein Platz, kein
  /// Durchschnitt. Eine 0 stünde hier für eine Messung, die es nicht gab
  /// (`docs/todo/01`) — deshalb `null`.
  const Fensterstand.leer(this.stufe)
    : von = null,
      bis = null,
      plaetze = 0,
      gezeichnet = 0,
      balken = const [],
      gewichte = const [],
      schnitt = null,
      verschiebung = 0,
      maxVerschiebung = 0,
      zweite = const [],
      stapel = const [],
      verdichtung = ChartAggregation.mean;

  factory Fensterstand.aus({
    required List<({DateTime tag, double wert})> reihe,
    required DiagrammStufe stufe,
    required int verschiebung,
    List<({DateTime tag, double wert})> zweiteReihe = const [],
    List<({DateTime tag, List<double> teile})> stapelReihe = const [],
    ChartAggregation verdichtung = ChartAggregation.mean,
  }) {
    final punkte = diagrammPunkte(
      werte: reihe,
      stufe: stufe,
      verdichtung: verdichtung,
    );
    if (punkte.isEmpty) return Fensterstand.leer(stufe);

    final (von0, bis0) = startFenster(
      stufe: stufe,
      juengster: punkte.last.beginn,
    );

    // Der linke Anschlag: „Der Wertebereich beginnt am Balken der ersten
    // Messung" (Spec). Weiter zurück stünde der Schirm auf leerer Fläche.
    //
    // Gezählt in **Plätzen**, in derselben Einheit wie die Verschiebung:
    // Zwei Wochen vor dem Startfenster sind vierzehn Tagesschritte, nicht
    // zwei Wochenschritte (#145).
    final anschlag = rastgrenze(punkte.first.beginn, stufe);
    final maxVerschiebung = math.max(
      0,
      nachTagen(stufe)
          ? tageZwischen(anschlag, von0)
          : monateZwischen(anschlag, von0),
    );
    final geklemmt = verschiebung.clamp(0, maxVerschiebung);

    final (von, bis) = _verschobenesFenster(von0, bis0, stufe, geklemmt);

    // `M` zeigt 31 Balken, damit auch der längste Monat ganz hineinpasst; in
    // kürzeren Monaten bleibt rechts Luft (Spec). Nur `plaetze` davon liegen
    // wirklich im Fenster — dort hinein wird gewählt.
    final plaetze = nachTagen(stufe)
        ? tageZwischen(von, bis)
        : monateZwischen(von, bis);
    final gezeichnet = stufe == DiagrammStufe.monat ? 31 : plaetze;

    // Auch die Nachbarn links und rechts: Während eines Wisches wandert das
    // Bild mit, und am Rand soll nicht plötzlich nichts stehen.
    final balken = <({int platz, double wert})>[];
    final gewichte = <({int platz, double wert, int tage})>[];
    for (final punkt in punkte) {
      final platz = nachTagen(stufe)
          ? tageZwischen(von, punkt.beginn)
          : monateZwischen(von, punkt.beginn);
      if (platz > -2 * gezeichnet && platz < 3 * gezeichnet) {
        balken.add((platz: platz, wert: punkt.wert));
        gewichte.add((platz: platz, wert: punkt.wert, tage: punkt.tage));
      }
    }

    // Die zweite Reihe wird **ebenso verdichtet** und auf dieselben Plätze
    // gelegt wie die erste — dieselbe Funktion, dieselbe Art. Ein Tag ohne
    // zweiten Wert fehlt hier, er steht nicht mit 0 da.
    final zweite = <({int platz, double wert})>[];
    if (zweiteReihe.isNotEmpty) {
      for (final punkt in diagrammPunkte(
        werte: zweiteReihe,
        stufe: stufe,
        verdichtung: verdichtung,
      )) {
        final platz = nachTagen(stufe)
            ? tageZwischen(von, punkt.beginn)
            : monateZwischen(von, punkt.beginn);
        if (platz > -2 * gezeichnet && platz < 3 * gezeichnet) {
          zweite.add((platz: platz, wert: punkt.wert));
        }
      }
    }

    // Die Teile eines gestapelten Balkens (#504). Sie laufen **nicht**
    // durch `diagrammPunkte`: Dort würde ab `6M` gemittelt, und ein
    // Mittel über Anteile wöge jeden Tag gleich schwer, auch den mit der
    // kurzen Nacht. Hier werden die Teile auf ihren Platz **summiert**,
    // in der Einheit, in der sie hereinkommen; der Anteil fällt erst im
    // Maler beim Normieren ab.
    final rohStapel = <({int platz, List<double> teile})>[];
    for (final eintrag in stapelReihe) {
      final platz = nachTagen(stufe)
          ? tageZwischen(von, eintrag.tag)
          : monateZwischen(von, eintrag.tag);
      if (platz > -2 * gezeichnet && platz < 3 * gezeichnet) {
        rohStapel.add((platz: platz, teile: eintrag.teile));
      }
    }

    return Fensterstand(
      stufe: stufe,
      von: von,
      bis: bis,
      plaetze: plaetze,
      gezeichnet: gezeichnet,
      balken: balken,
      gewichte: gewichte,
      zweite: zweite,
      stapel: stapelSummen(rohStapel),
      verdichtung: verdichtung,
      // Dieselbe Rechnung wie für jeden anderen Ausschnitt — das Fenster ist
      // nur der Ausschnitt ohne Zug. Zwei Rechnungen könnten auseinander-
      // laufen, und die Kopfzeile zeigte dann im Ruhezustand etwas anderes
      // als eine Haaresbreite nach dem Loslassen.
      schnitt: _kennwert(gewichte, 0, plaetze, verdichtung),
      verschiebung: geklemmt,
      maxVerschiebung: maxVerschiebung,
    );
  }

  final DiagrammStufe stufe;

  /// Die halboffenen Fenstergrenzen `[von, bis)`, `null` ohne Messwert.
  final DateTime? von;
  final DateTime? bis;

  /// Wie viele Plätze im Fenster liegen — dort hinein wird gewählt.
  final int plaetze;

  /// Wie viele Plätze gezeichnet werden. Bei `M` sind es 31, auch im Februar.
  final int gezeichnet;

  /// Die Balken des Fensters **und seiner Nachbarn**, als Platz im Fenster.
  /// Negative Plätze liegen links davon.
  final List<({int platz, double wert})> balken;

  /// Dieselben Balken, zusätzlich mit den **gemessenen Tagen** hinter jedem.
  /// Daraus rechnet [ueberblick] den Durchschnitt je Tag.
  ///
  /// **Zwei Listen statt einer**, obwohl Platz und Wert doppelt dastehen:
  /// [balken] ist das, was der Maler zeichnet, und `tage` zeichnet er nicht.
  /// Ein Feld, das ein `CustomPainter` entgegennimmt und ignoriert, wandert
  /// durch `shouldRepaint` und durch jede spätere Lesart der Zeichenschicht.
  /// Beide Listen entstehen in **einer** Schleife, Zeile an Zeile.
  final List<({int platz, double wert, int tage})> gewichte;

  /// Der Durchschnitt **je gemessenem Tag** im Fenster, `null`, wenn im
  /// Fenster nichts gemessen wurde.
  ///
  /// **Bei [verdichtung] `max` ist es der Höchstwert** der gezeigten
  /// Punkte, nicht ihr Mittel: Das Mittel von Monatsmaxima wäre genau die
  /// Zahl, die `docs/SPEC.md` 4.4 ablehnt (ein Gewicht, das nie auf der
  /// Stange lag). Der Name bleibt, damit kein Aufrufer sich ändert.
  ///
  /// Das ist `ueberblick().schnitt`; während eines Zuges zeigt die Kopfzeile
  /// den des gezeigten Ausschnitts, nicht diesen hier.
  final double? schnitt;

  /// Die zweite Reihe, verdichtet wie die erste, als Platz im Fenster —
  /// leer ohne zweite Reihe. **Lücken fehlen hier**, es stehen keine Nullen
  /// darin. Das Fenster und die Achse hängen allein an der ersten Reihe.
  final List<({int platz, double wert})> zweite;

  /// Je Platz die **Teile**, nach denen sein Balken in sich geteilt wird —
  /// leer ohne gestapelte Reihe (#504).
  ///
  /// In derselben Einheit wie [balken], nicht in Prozent: Über einen
  /// Kalendermonat lassen sich Minuten aufsummieren, Anteile nicht. Der
  /// Anteil entsteht erst im Maler, über `stapelGrenzen`.
  ///
  /// **Ein Platz ohne Eintrag steht einfarbig da.** Ältere Uhren melden
  /// Schlaf ohne Phasenangabe; eine erfundene Verteilung wäre schlimmer
  /// als keine (`CLAUDE.md`, Fehler `01`).
  final List<({int platz, List<double> teile})> stapel;

  /// Mit welcher Art die Reihen verdichtet wurden.
  final ChartAggregation verdichtung;

  /// Wie viele **Plätze** das Fenster hinter dem Startfenster liegt — schon
  /// auf den linken Anschlag geklemmt. Bei `W` und `M` sind das
  /// Kalendertage, ab `6M` Kalendermonate.
  final int verschiebung;
  final int maxVerschiebung;

  /// Der Ausschnitt, der bei einem Zug um `versatzPlaetze` Plätze im Bild
  /// steht — halboffen, in Plätzen dieses Fensters.
  ///
  /// Ohne Zug ist es genau `[0, plaetze)`, also das Fenster selbst; der
  /// Ruhezustand ändert sich durch diese Rechnung nicht.
  ///
  /// **Wozu das gut ist** (#147): Während eines Zuges zeichnet der Maler die
  /// Nachbarplätze mit, damit am Rand nicht plötzlich nichts steht. y-Skala
  /// und Achsenbeschriftung gehörten bis zum 28.10.2026 trotzdem weiter zum
  /// Fenster vor dem Zug — die Linie schoss oben und unten aus dem Bild, und
  /// von der Achse blieb ein einzelner Wochentag stehen.
  ///
  /// Angeschnittene Plätze zählen mit: Sie sind zu sehen, also muss die
  /// Achse sie tragen. Deshalb `floor` und `ceil` und nicht `round`.
  (int, int) sichtbar(double versatzPlaetze) =>
      ((-versatzPlaetze).floor(), (plaetze - versatzPlaetze).ceil());

  /// Der Beginn eines Platzes, `null` ohne Fenster.
  DateTime? platzBeginn(int platz) {
    final von = this.von;
    if (von == null) return null;
    return nachTagen(stufe)
        ? BerlinCalendar.addDays(von, platz)
        : BerlinCalendar.addMonths(von, platz);
  }

  /// Der gehaltene Balken: sein Tag und sein Wert, `null` ohne Auswahl. Ein
  /// Tag ohne Messung gibt den Tag mit `wert == null` zurück — daraus wird
  /// „keine Messung", nie der Nachbarwert.
  ({DateTime beginn, double? wert})? abgelesen(int? platz) {
    if (platz == null) return null;
    final beginn = platzBeginn(platz);
    if (beginn == null) return null;
    for (final eintrag in balken) {
      if (eintrag.platz == platz) {
        return (beginn: beginn, wert: eintrag.wert);
      }
    }
    return (beginn: beginn, wert: null);
  }

  /// Unter- und Obergrenze der y-Achse. Balken wachsen aus der Null, eine
  /// Linie füllt die Spanne ihrer Werte (`lineChart` im Entwurfsboard). Die
  /// Ziellinien zählen mit — eine Ziellinie außerhalb der Achse wäre
  /// unsichtbar und damit wertlos.
  ///
  /// **Über einer Ziellinie, die das Ende der Achse bestimmt, bleibt Luft**
  /// ([_ziellinienLuft]) — und unter einer, die das andere Ende bestimmt.
  /// Ohne sie fiele die Linie mit der äußersten Rasterlinie zusammen und
  /// ihre Beschriftung stieße aus der Zeichenfläche (#162). Der Fall ist
  /// nicht selten, sondern der Normalfall eines **nicht erreichten** Ziels.
  ///
  /// `ausschnitt` ist der gezeigte Bereich aus [sichtbar]; ohne Angabe gilt
  /// das Fenster selbst. Was im Bild steht, gehört auf die Achse — sonst
  /// schießt es beim Ziehen heraus (#147).
  (double, double) grenzen({
    required List<double> linien,
    required bool alsBalken,
    (int, int)? ausschnitt,
  }) {
    final (vonPlatz, bisPlatz) = ausschnitt ?? (0, plaetze);
    final messwerte = <double>[
      for (final eintrag in balken)
        if (eintrag.platz >= vonPlatz && eintrag.platz < bisPlatz) eintrag.wert,
      // Die zweite Reihe liegt auf derselben Skala — sonst schösse sie aus
      // dem Bild.
      for (final eintrag in zweite)
        if (eintrag.platz >= vonPlatz && eintrag.platz < bisPlatz) eintrag.wert,
    ];
    final werte = <double>[...messwerte, ...linien];
    if (werte.isEmpty) return (0, 1);
    var unten = werte.reduce(math.min);
    var oben = werte.reduce(math.max);
    if (alsBalken) unten = math.min(0, unten);

    // Wo das Ende der Achse von einer Ziellinie kommt und nicht von einer
    // Messung, bekommt es Luft. Die Null zählt dabei als gezeichneter Wert,
    // solange Balken aus ihr wachsen — sonst schwebten sie.
    final messOben = messwerte.isEmpty ? null : messwerte.reduce(math.max);
    final messUnten = alsBalken
        ? math.min(0.0, messwerte.isEmpty ? 0.0 : messwerte.reduce(math.min))
        : (messwerte.isEmpty ? null : messwerte.reduce(math.min));
    final obenIstZiel = messOben == null || oben > messOben;
    final untenIstZiel = messUnten == null || unten < messUnten;

    // Der Anteil gilt für die **fertige** Achse: Mit `oben - unten` als
    // Bezug schrumpfte die Luft, je weiter die Ziellinie von den Werten
    // weg liegt, und bei einem Wochenziel über einer schwachen Woche wäre
    // sie wieder weg. Eine Spanne von 0 bleibt eine Spanne von 0; den Fall
    // fängt `oben <= unten` darunter.
    final spanne =
        (oben - unten) /
        (1 -
            (obenIstZiel ? _ziellinienLuft : 0) -
            (untenIstZiel ? _ziellinienLuft : 0));
    if (obenIstZiel) oben += _ziellinienLuft * spanne;
    if (untenIstZiel) unten -= _ziellinienLuft * spanne;

    if (oben <= unten) oben = unten + 1;
    return (unten, oben);
  }

  /// Was die Kopfzeile über den gezeigten Ausschnitt sagt: seine halboffenen
  /// Grenzen `[von, bis)` und sein Durchschnitt **je gemessenem Tag**.
  ///
  /// `ausschnitt` ist der gezeigte Bereich aus [sichtbar]; ohne Angabe gilt
  /// das Fenster selbst — genau wie bei [grenzen] und [achse].
  ///
  /// **Wozu das gut ist** (#150): Seit #147 zeigen Achse und y-Skala
  /// während eines Zuges den verschobenen Ausschnitt. Die Kopfzeile blieb
  /// stehen — über einer Achse, die längst den 21.10. nannte, stand weiter
  /// „Durchschnitt 333 · 05.10. – 11.10.". Tim hat das am 28.10.2026 auf
  /// dem Gerät gesehen.
  ///
  /// **Eine Antwort für beides, nicht zwei.** Zeitraum und Durchschnitt
  /// sind dieselbe Frage an denselben Ausschnitt und müssen zusammenpassen:
  /// Ein Durchschnitt über acht Tage neben einem Zeitraum über sieben wäre
  /// eine falsche Auskunft. Eine Methode lässt sich nicht halb aufrufen.
  ///
  /// **Beim Ablesen gilt weiter der Balken**, nicht der Ausschnitt — dafür
  /// ist [abgelesen] da.
  ({DateTime? von, DateTime? bis, double? schnitt}) ueberblick([
    (int, int)? ausschnitt,
  ]) {
    if (ausschnitt == null) {
      return (von: von, bis: bis, schnitt: schnitt);
    }
    final (vonPlatz, bisPlatz) = ausschnitt;
    return (
      von: platzBeginn(vonPlatz),
      bis: platzBeginn(bisPlatz),
      schnitt: _kennwert(gewichte, vonPlatz, bisPlatz, verdichtung),
    );
  }

  /// Die Beschriftung unter dem Graphen. Bei `W` jeder Tag, bei `M` jeder
  /// siebte, sonst jeder Monat.
  ///
  /// `ausschnitt` ist der gezeigte Bereich aus [sichtbar]; ohne Angabe gilt
  /// das Fenster selbst. Beschriftet wird, was im Bild steht — blieb die
  /// Achse beim alten Fenster, stand von ihr während eines Zuges nur noch
  /// ein einzelner Wochentag da (#147).
  ///
  /// **Der Raster hängt am Fensterbeginn, nicht am Bildrand.** Bei `M` wird
  /// jeder siebte Platz beschriftet, gezählt ab Platz 0 — auch rückwärts,
  /// denn Darts `%` gibt für negative Zahlen einen nichtnegativen Rest.
  /// Hinge er am Bildrand, wanderten die Beschriftungen beim Ziehen zwischen
  /// den Balken hin und her.
  List<({int platz, String text})> achse([(int, int)? ausschnitt]) {
    if (von == null || plaetze <= 0) return const [];
    final schritt = stufe == DiagrammStufe.monat ? 7 : 1;
    final (vonPlatz, bisPlatz) = ausschnitt ?? (0, plaetze);
    return [
      for (
        var platz = vonPlatz + (schritt - vonPlatz % schritt) % schritt;
        platz < bisPlatz;
        platz += schritt
      )
        (
          platz: platz,
          // Über `Format`, nie über `DateFormat`: Auf einem englisch
          // eingestellten Gerät stünde sonst „Tue" im deutschen Text.
          // Und durch `kalendertag`, nie direkt: `platzBeginn` gibt den
          // UTC-Zeitpunkt der Berliner Mitternacht, der in UTC den Vortag
          // trägt — bei einem Monatsersten also den **Vormonat**.
          text: switch (stufe) {
            DiagrammStufe.woche => Format.wochentagKurz(
              kalendertag(platzBeginn(platz)!),
            ),
            DiagrammStufe.monat => Format.tagMonat(
              kalendertag(platzBeginn(platz)!),
            ),
            // Ab `6M` ist ein Platz ein ganzer Monat, und der trägt seinen
            // Namen. Mit `tagMonat` stand bei `J` zwölfmal „01." da und
            // sagte nichts — Tims Entscheidung vom 28.10.2026 (#149).
            DiagrammStufe.halbjahr || DiagrammStufe.jahr => Format.monatKurz(
              kalendertag(platzBeginn(platz)!),
            ),
          },
        ),
    ];
  }
}

/// Der Durchschnitt **je gemessenem Tag** über die Plätze in
/// `[vonPlatz, bisPlatz)`, `null`, wenn dort nichts gemessen wurde.
///
/// Gewichtet mit den gemessenen Tagen: Die Kopfzeile nennt den Durchschnitt
/// je Tag, und ab `6M` steckt hinter einem Balken ein ganzer Monat (Spec,
/// „Verdichtung ab 6M"). Ein Monat mit einer einzigen Messung darf nicht so
/// schwer wiegen wie ein voller.
///
/// `null` und nicht `0`: Eine 0 stünde für eine Messung, die es nicht gab —
/// der Fehler `01`.
///
/// **Mit `max` der Höchstwert** der Punkte dort: Der Kennwert einer Reihe,
/// die über das Maximum verdichtet ist, ist ihr Maximum und nicht das Mittel
/// ihrer Maxima.
double? _kennwert(
  List<({int platz, double wert, int tage})> gewichte,
  int vonPlatz,
  int bisPlatz,
  ChartAggregation verdichtung,
) {
  if (verdichtung == ChartAggregation.max) {
    double? hoechst;
    for (final eintrag in gewichte) {
      if (eintrag.platz < vonPlatz || eintrag.platz >= bisPlatz) continue;
      if (hoechst == null || eintrag.wert > hoechst) hoechst = eintrag.wert;
    }
    return hoechst;
  }
  var summe = 0.0;
  var tage = 0;
  for (final eintrag in gewichte) {
    if (eintrag.platz < vonPlatz || eintrag.platz >= bisPlatz) continue;
    summe += eintrag.wert * eintrag.tage;
    tage += eintrag.tage;
  }
  return tage == 0 ? null : summe / tage;
}
