/// Die Rechnung hinter dem Hypnogramm: Phasen, Fenster, Einträge und die
/// Lage eines Eintrags in Punkten — die erste von drei Dateien neben
/// `hypnogramm_zeichnung.dart` (Striche) und `hypnogramm.dart` (Zustand,
/// Kopfzeile, Geste).
///
/// Getrennt, weil die drei zusammen über sechshundert Zeilen ergäben:
/// „Wächst eine Datei über ein paar hundert Zeilen, macht sie zu viel"
/// (`CLAUDE.md`) — derselbe Schnitt wie bei `zeitdiagramm*.dart`. Hier
/// liegt kein Widget und kein Strich, nur Zahlen; **die öffentliche
/// Adresse bleibt `design/hypnogramm.dart`**, das beide Hälften
/// wiederausgibt.
library;

import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import '../health/health_types.dart';
import 'palette.dart';

/// Ab welchem Abstand zwischen zwei gemessenen Abschnitten eine
/// **Messlücke** beginnt (#156).
///
/// **Fünf Minuten, und die Entscheidung ist meine — Tim hat sie nicht
/// gesehen.** Der Entwurf trägt die Lücke als eigenen Eintrag in der
/// Phasenliste; in der App gibt es sie nicht als Eintrag, sondern nur als
/// Abwesenheit, also muss eine Schwelle her. Drei Gründe für genau diese:
///
/// 1. Aufeinanderfolgende Abschnitte aus Apple Health stoßen fast immer
///    aneinander. Was dazwischen übrig bleibt, sind Sekunden bis wenige
///    Minuten an Abtastgrenzen — **nicht** eine Strecke, auf der niemand
///    gemessen hat. Jeden solchen Abstand zu rahmen hieße, aus einer
///    Rundung eine Aussage zu machen.
/// 2. Unterhalb davon wäre der Rahmen schmaler als der Hinweis, den er
///    geben soll: Eine Nacht von 7:30 h auf 320 Punkten gibt einer Minute
///    0,7 Punkt, fünf Minuten 3,6 Punkte. Ein gestrichelter Rahmen von
///    zwei Punkten Breite ist kein Hinweis, sondern ein Fleck.
/// 3. Fünf Minuten ändern keine Zahl, die der Schirm ausschreibt — die
///    Dauern stehen dort in Minuten, und eine Lücke zählt in keine
///    Phasensumme. Wer die Schwelle höher setzt, verschweigt eine echte
///    Lücke; wer sie tiefer setzt, erfindet welche.
const Duration kleinsteMessluecke = Duration(minutes: 5);

/// Der schmalste Block, den das Bild zeichnet — `SCHMAL` in
/// `docs/screens/components.js`.
///
/// Eine Minute von 450 ist 0,7 Punkt breit und damit unsichtbar. Das Bild
/// rundet hier **nach oben**: Lieber ein Strich, der ein bisschen zu breit
/// ist, als sieben Wachphasen, die es laut Bild nicht gibt. Die Minuten
/// stehen daneben ausgeschrieben und bleiben die Wahrheit.
const double kleinsteBlockbreite = 2.4;

/// Namen, Farben und Spuren der Schlafphasen — Dart-Entsprechung von
/// `SleepStage.display`/`.name`/`.color` auf der Swift-Seite und von
/// `STAGE`/`STAGE_ORDER` in `docs/screens/components.js`.
abstract final class SchlafPhasen {
  /// Die vier Spuren in der Lesart von Apple Health: wach oben,
  /// Tiefschlaf unten.
  static const List<SleepStage> reihenfolge = [
    SleepStage.awake,
    SleepStage.rem,
    SleepStage.core,
    SleepStage.deep,
  ];

  static String name(SleepStage phase) => switch (phase) {
    SleepStage.awake => 'Wach',
    SleepStage.rem => 'REM',
    SleepStage.core => 'Kern',
    SleepStage.deep => 'Tief',
    SleepStage.unspecified => 'Schlaf',
  };

  /// **„Tief" ist dunkler als „Kern" — in beiden Modi.** Deshalb steht dort
  /// `riverDark` und nicht `deep`: `--deep` ist im Dunkelmodus das hellste
  /// Blau der Palette (`#9FE4FF`, heller als `--river`), und eine
  /// Tiefenlesart, die sich beim Umschalten umdreht, ist keine. Im
  /// Hellmodus ändert sich dadurch nichts — `--deep` und `--river-dark`
  /// tragen dort denselben Wert (`#173F54`).
  ///
  /// `Palette.deep` bleibt unangetastet und gilt weiter für Ringe und
  /// Flächen.
  static CupertinoDynamicColor farbe(SleepStage phase) => switch (phase) {
    SleepStage.awake => Palette.wach,
    SleepStage.rem => Palette.iron,
    SleepStage.core => Palette.river,
    SleepStage.deep => Palette.riverDark,
    SleepStage.unspecified => Palette.river2,
  };

  /// Die Spur, auf der die Phase liegt. **Unspezifizierter Schlaf liegt auf
  /// der Kern-Spur**: Ältere Uhren und das iPhone melden Schlaf ohne
  /// Phasenangabe, und eine eigene fünfte Spur dafür wäre eine Phase, die
  /// Apple nicht meldet.
  static int spurIndex(SleepStage phase) {
    final index = reihenfolge.indexOf(phase);
    return index >= 0 ? index : reihenfolge.indexOf(SleepStage.core);
  }
}

/// Ein Eintrag im Bild: ein gemessener Abschnitt **oder** eine Messlücke.
///
/// Die Lücke ist kein fünfter Schlafzustand — sie trägt keine Phase, keinen
/// Block und zählt in keine Phasensumme. Niemand weiß, was in ihr war. Sie
/// steht trotzdem in dieser Liste, weil sie ihren Platz auf der Zeitachse
/// belegt: Ohne ihn rückte alles dahinter nach vorn und die Uhrzeiten unter
/// dem Bild lögen (#156).
class Hypnogrammeintrag {
  const Hypnogrammeintrag({this.phase, required this.von, required this.bis});

  /// `null` heißt: Messlücke.
  final SleepStage? phase;

  final DateTime von;
  final DateTime bis;

  bool get istLuecke => phase == null;

  Duration get dauer => bis.difference(von);
}

/// Das Schlaffenster einer Nacht, seine Einträge und die Lage eines
/// Zeitpunkts darin — reine Rechnung, damit sie ohne Pixelvergleich prüfbar
/// ist.
///
/// **Das Fenster geht über *alle* Abschnitte, auch die wachen** — anders
/// als `SleepSession.start`/`.end` in Swift, die nur die Schlafabschnitte
/// zählen. Für die **Dauer** ist das richtig (Wachliegen am Rand ist kein
/// Schlaf), für das **Bild** nicht: Eine Nacht, in der die Uhr nur
/// Wachliegen aufgezeichnet hat, hätte sonst gar kein Fenster und bliebe
/// ungezeichnet.
///
/// **Alles Abgeleitete steht in `late final`-Feldern, nicht in Gettern**
/// (`CLAUDE.md`, Regel 2). Beim Halten läuft [trefferBei] je Fingerbewegung
/// einmal über alle Einträge; liefe darin jedes Mal die ganze Nacht neu
/// durch, wäre das `03` im neuen Code.
class HypnogrammGeometrie {
  HypnogrammGeometrie(SleepSession session) : _abschnitte = session.segments;

  final List<SleepSegment> _abschnitte;

  /// Der früheste Abschnittsbeginn, `null` ohne Abschnitte.
  late final DateTime? von = _abschnitte.isEmpty
      ? null
      : _abschnitte
            .map((abschnitt) => abschnitt.start)
            .reduce((a, b) => a.isBefore(b) ? a : b);

  /// Das späteste Abschnittsende, `null` ohne Abschnitte.
  late final DateTime? bis = _abschnitte.isEmpty
      ? null
      : _abschnitte
            .map((abschnitt) => abschnitt.end)
            .reduce((a, b) => a.isAfter(b) ? a : b);

  /// Die Dauer des Fensters; ohne Abschnitte [Duration.zero].
  late final Duration fenster = () {
    final anfang = von, ende = bis;
    if (anfang == null || ende == null) return Duration.zero;
    final dauer = ende.difference(anfang);
    return dauer.isNegative ? Duration.zero : dauer;
  }();

  /// Keine Abschnitte oder ein Fenster ohne Dauer — in beiden Fällen gibt
  /// es nichts zu zeichnen, und in beiden Fällen würde [anteil] sonst
  /// durch null teilen.
  late final bool leer = _abschnitte.isEmpty || fenster.inMicroseconds <= 0;

  /// Abschnitte und Messlücken in zeitlicher Folge.
  ///
  /// Eine Lücke erkennt man am Abstand zwischen dem Ende des bisher
  /// abgedeckten Bereichs und dem Beginn des nächsten Abschnitts; ab
  /// [kleinsteMessluecke] wird sie zum Eintrag. **Der bisher abgedeckte
  /// Bereich, nicht das Ende des Vorgängers** — zwei überlappende
  /// Abschnitte dürfen hinter sich keine Lücke erzeugen, die es nie gab.
  late final List<Hypnogrammeintrag> eintraege = _eintraege();

  List<Hypnogrammeintrag> _eintraege() {
    final sortiert = [..._abschnitte]
      ..sort((a, b) => a.start.compareTo(b.start));
    final raus = <Hypnogrammeintrag>[];
    DateTime? abgedeckt;
    for (final abschnitt in sortiert) {
      if (abgedeckt != null &&
          abschnitt.start.difference(abgedeckt) >= kleinsteMessluecke) {
        raus.add(Hypnogrammeintrag(von: abgedeckt, bis: abschnitt.start));
      }
      raus.add(
        Hypnogrammeintrag(
          phase: abschnitt.stage,
          von: abschnitt.start,
          bis: abschnitt.end,
        ),
      );
      if (abgedeckt == null || abschnitt.end.isAfter(abgedeckt)) {
        abgedeckt = abschnitt.end;
      }
    }
    return List.unmodifiable(raus);
  }

  /// Die zusammenhängenden Strecken **mit** Messung — die grauen Spuren.
  ///
  /// Sie brechen an jeder Messlücke ab. Eine durchlaufende Spur behauptete,
  /// es sei gemessen und nur nichts gewesen (#156).
  late final List<({DateTime von, DateTime bis})> gemesseneStrecken = () {
    if (leer) return const <({DateTime von, DateTime bis})>[];
    final raus = <({DateTime von, DateTime bis})>[];
    var anfang = von!;
    for (final eintrag in eintraege) {
      if (!eintrag.istLuecke) continue;
      if (eintrag.von.isAfter(anfang)) {
        raus.add((von: anfang, bis: eintrag.von));
      }
      anfang = eintrag.bis;
    }
    if (bis!.isAfter(anfang)) raus.add((von: anfang, bis: bis!));
    return List<({DateTime von, DateTime bis})>.unmodifiable(raus);
  }();

  /// Jede volle Stunde im Fenster — die Rasterlinien der Uhrzeitachse.
  ///
  /// Gezählt wird in **absoluten** Stunden ab der angebrochenen ersten:
  /// Die Zeitumstellung verschiebt die Stundenzahl, nicht die Minute, und
  /// genau so soll eine Wanduhrachse laufen — in der Nacht der Rückstellung
  /// steht 02:00 zweimal da, weil es zweimal 02:00 war.
  late final List<DateTime> volleStunden = () {
    final anfang = von, ende = bis;
    if (anfang == null || ende == null || leer) return const <DateTime>[];
    final raus = <DateTime>[];
    var zeiger = DateTime(
      anfang.year,
      anfang.month,
      anfang.day,
      anfang.hour,
    ).add(const Duration(hours: 1));
    while (!zeiger.isAfter(ende)) {
      raus.add(zeiger);
      zeiger = zeiger.add(const Duration(hours: 1));
    }
    return List<DateTime>.unmodifiable(raus);
  }();

  /// Der Platz eines Zeitpunkts im Fenster, 0 bis 1. Außerhalb wird
  /// geklemmt, statt über den Rand hinauszuzeichnen.
  double anteil(DateTime zeitpunkt) {
    if (leer) return 0;
    final ganz = fenster.inMicroseconds;
    final seit = zeitpunkt.difference(von!).inMicroseconds;
    if (seit <= 0) return 0;
    if (seit >= ganz) return 1;
    return seit / ganz;
  }

  /// Linke Kante und Breite eines Eintrags in Punkten.
  ///
  /// **Dieselbe Rechnung im Maler und beim Ablesen**, und deshalb steht sie
  /// an einer Stelle: Wer ein gezeichnetes Rechteck anfasst, muss es auch
  /// treffen — siehe [trefferBei].
  ({double links, double breite}) lage(
    Hypnogrammeintrag eintrag,
    double gesamtbreite,
  ) {
    final links = gesamtbreite * anteil(eintrag.von);
    final roh = gesamtbreite * anteil(eintrag.bis) - links;
    return (
      links: links,
      breite: roh.clamp(
        math.min(kleinsteBlockbreite, gesamtbreite),
        gesamtbreite,
      ),
    );
  }

  /// Der Eintrag, den eine Berührung bei [x] meint — `null` ohne Einträge.
  ///
  /// **Gemessen wird am gezeichneten Rechteck, nicht an der Uhrzeit unter
  /// dem Finger.** Ein Block von einer Minute belegt 0,7 Punkt Zeit, wird
  /// aber [kleinsteBlockbreite] breit gezeichnet; wer mitten auf seinen
  /// sichtbaren Strich drückt, landet zeitlich längst im Nachbarblock. Das
  /// Lot stünde dann auf dem einen und die Kopfzeile nennte den anderen —
  /// und genau der Fall, für den das Ablesen gebaut ist, wäre unablesbar
  /// (#141).
  ///
  /// Überlappen mehrere verbreiterte Rechtecke, gewinnt das, dessen
  /// **Mitte** dem Finger am nächsten liegt: Das ist das schmale, das man
  /// gemeint hat, nicht der lange Nachbar, der zufällig auch dort anfängt.
  int? trefferBei(double x, double gesamtbreite) {
    if (leer || gesamtbreite <= 0 || eintraege.isEmpty) return null;
    int? bester;
    var besteNaehe = double.infinity;
    var besteMitte = 0.0;
    for (var i = 0; i < eintraege.length; i++) {
      final (:links, :breite) = lage(eintraege[i], gesamtbreite);
      final rechts = links + breite;
      final naehe = x < links
          ? links - x
          : x > rechts
          ? x - rechts
          : 0.0;
      final mitte = (links + rechts) / 2;
      final naeher = naehe < besteNaehe - 1e-9;
      final gleichNahUndMittiger =
          naehe <= besteNaehe + 1e-9 &&
          (x - mitte).abs() < (x - besteMitte).abs();
      if (bester == null || naeher || gleichNahUndMittiger) {
        bester = i;
        besteNaehe = naehe;
        besteMitte = mitte;
      }
    }
    return bester;
  }
}
