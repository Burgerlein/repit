/// Die Anzeigen des Heute-Schirms, aus den Tageswerten gebaut — getrennt
/// von `heute_view.dart`, damit der Schirm selbst nur noch den Aufbau
/// zeigt.
///
/// **Jede Anzeige entsteht immer**, auch ohne Wert: Ein fehlender Wert ist
/// `null` und wird zu [ohneWert], nie zu `0` und nie zu einer fehlenden
/// Anzeige (Spec
/// `docs/superpowers/specs/2026-10-28-leerzustaende-design.md`, Ticket
/// #137). Solange noch gar nichts gelesen wurde (`laedt`), steht an der
/// Stelle des Werts eine graue Fläche in der Breite eines Beispieltexts.
///
/// **Die Erholungskarte steht nicht hier, sondern in `heute_view.dart`.**
/// Diese Datei trug sie, solange es keinen Erholung-Schirm gab und die
/// Werte aus `DailyMetrics` kommen mussten. Seit dem Zusammenführen des
/// Erholung-Zweigs liest die Karte `erholungProvider` — denselben Zustand
/// wie der Erholung-Schirm, mit Verdikt, Normalwerten und Schlaf — und ist
/// zugleich die Tür dorthin (#115). Zwei Quellen für dieselbe Auskunft
/// wären zwei Wahrheiten.
library;

import 'package:flutter/cupertino.dart';
import 'package:trainings_core/trainings_core.dart';

import '../core/messwert.dart';
import '../data/cache_repository.dart';
import '../design/kacheln.dart';
import '../design/palette.dart';
import '../design/platzhalter.dart';
import '../design/ringe.dart';
import '../design/zahlen.dart';
import '../ernaehrung/ernaehrung_provider.dart';
import '../health/health_types.dart';
import 'messung_detail_view.dart';
import 'router.dart';

/// Apple-Watch-Standardwert für den Trainierenring, SPEC Abschnitt 3
/// ("Trainieren 30 min") — keine personenbezogene Kennzahl, deshalb als
/// Konstante statt aus den Health-Daten gelesen.
const _trainingszielMinuten = 30.0;

/// Beide Möglichkeiten, die Apple nicht unterscheidet (CLAUDE.md,
/// Abschnitt HealthKit), in der Kürze, die in eine Kachelzeile passt.
/// Beide Möglichkeiten, die Apple nicht unterscheidet, in der Kürze, die
/// in eine halbbreite Kachel passt — mit dem Verweis auf die
/// Health-Einstellungen, den `CLAUDE.md` ausdrücklich verlangt. Im Fall
/// „Teils Werte" steht er nirgends sonst.
const _ohneTrefferKurz = 'Kein Zugriff? Health-Einstellungen';

/// Kalorien- und Eiweißring (#358) — die beiden äußeren der drei Ringe
/// aus `RINGE` in `heute-kombi.js`. Beide entstehen immer, auch ohne Wert.
///
/// **Gerechnet wird hier nichts.** Gegessenes, Kalorienziel und
/// Eiweißziel liest der Ring aus dem gehaltenen [ErnaehrungsTag] — demselben,
/// den der Ernährungs-Tab zeigt. Zwei Rechnungen an zwei Stellen gäben zwei
/// verschiedene Kalorienziele. Der Eiweißring läuft gegen
/// `makroziele.eiweissMinG`, wie auf dem Ernährungs-Tab.
///
/// Drei Zustände, eine Form:
/// - **Ziel und Wert da:** Die Beschriftung nennt den Rest („noch 540
///   kcal", erfundenes Beispiel), über dem Ziel, wie weit darüber. Der Ring
///   läuft dann eine zweite Runde ([RingZiel.zweiteRunde]).
/// - **Kein Ziel:** `wert` ist `null` und die Legende sagt [ohneWert] —
///   auch wenn gegessen wurde. Ein Ring gegen kein Ziel ist ein Ring gegen
///   nichts, und einer auf 0 behauptete „nichts gegessen". Den Grund nennt
///   der Schirm einmal, nicht hier je Ring.
/// - **Wird geladen:** Solange das Gegessene `NochNie` ist oder das Ziel
///   noch nicht nachgesehen wurde ([ErnaehrungsTag.zielLaedt]), steht ein
///   Platzhalter statt `–/–`. Ein bekannter Wert verdrängt ihn — beim
///   Nachladen bleibt er stehen.
///
/// **Ohne Einträge ist der Wert `0`, nicht `null`:** Für Tims eigene Daten
/// gibt es keinen Lauf, der leer ausgehen kann (`CLAUDE.md`), und
/// `ernaehrungsTagAus` liefert dafür ausdrücklich acht Nullen.
List<RingZiel> ernaehrungsRinge(BuildContext context, ErnaehrungsTag tag) {
  final werte = gegessenWerte(tag);
  final laedt = tag.gegessen is NochNie<Naehrwerte> || tag.zielLaedt;

  RingZiel ring({
    required String label,
    required double? wert,
    required double? ziel,
    required String einheit,
    required CupertinoDynamicColor farbe,
    required String beispiel,
  }) {
    final zeigbar = ziel == null ? null : wert;
    return RingZiel(
      label: label,
      wert: zeigbar,
      // Ohne Ziel trägt der Ring keinen Wert; die `1` gibt dem Anteil nur
      // einen Nenner, sie wird nie gezeichnet.
      ziel: ziel ?? 1,
      text: ziel == null || zeigbar == null
          ? ohneWert
          : _restText(zeigbar, ziel, einheit),
      farbe: CupertinoDynamicColor.resolve(farbe, context),
      platzhalter: laedt ? beispiel : null,
    );
  }

  return [
    ring(
      label: 'Kalorien',
      wert: werte?.kcal,
      ziel: tag.zielKcal,
      einheit: 'kcal',
      farbe: Palette.bib,
      beispiel: 'noch 0.000 kcal',
    ),
    ring(
      label: 'Eiweiß',
      wert: werte?.eiweissG,
      ziel: tag.makroziele.eiweissMinG,
      einheit: 'g',
      farbe: Palette.iron,
      beispiel: 'noch 000 g',
    ),
  ];
}

/// Der Trainingsring — er entsteht immer, auch ohne Wert. Fehlt
/// `exerciseMinutes`, ist `wert` `null`: Der Ring zeichnet dann nur seine
/// Spur und die Legende sagt `–/–`. Eine `0` wäre Fehler `01` aus
/// `CLAUDE.md`, nur hübscher verpackt.
List<RingZiel> trainingsring(
  BuildContext context,
  DailyMetrics? heute, {
  required bool laedt,
}) {
  final trainingsMinuten = heute?.exerciseMinutes;
  return [
    RingZiel(
      label: 'Training',
      wert: trainingsMinuten,
      ziel: _trainingszielMinuten,
      text: trainingsMinuten == null
          ? ohneWert
          : _restText(trainingsMinuten, _trainingszielMinuten, 'min'),
      farbe: CupertinoDynamicColor.resolve(Palette.river, context),
      platzhalter: laedt ? 'noch 00 min' : null,
    ),
  ];
}

/// Schritte und Gewicht. Beide Kacheln entstehen immer — fiele eine weg,
/// verdoppelte die andere ihre Breite (`Kacheln` legt seine Kinder als
/// gleich breite `Expanded` ab).
///
/// **Das Gewicht greift auf den jüngsten Wert im Fenster zurück.** Tim
/// wiegt sich nicht täglich; stünde dort an den meisten Tagen `–/–`, sähe
/// die Kachel nach einem Fehler aus. Die Einordnung darunter sagt, wie alt
/// der Wert ist — das macht nebenbei die Beschriftung „zuletzt gemessen"
/// wahr. **Für Schritte gilt das ausdrücklich nicht:** Ein Schrittwert von
/// gestern ist keine Auskunft über heute.
///
/// [heuteTag] ist der Tagesschlüssel des **tatsächlichen** Kalendertags,
/// nicht der des letzten Cache-Eintrags (#196). Nur daran lässt sich sagen,
/// wie alt der Waage-Wert ist: Beim ersten Kaltstart eines neuen Tages endet
/// das Fenster bei gestern, und gegen dessen eigenen Tag gerechnet kam
/// „heute gemessen" heraus — eine positive Behauptung über eine Messung, die
/// es heute nicht gab.
///
/// **Die Gewichtskachel ist eine Tür** auf den Verlauf des Gewichts (#239)
/// — derselbe Schirm, den auch die Kopfkarte auf `koerper` öffnet. Tim
/// liest die Zahl auf Home und will von dort weiter, ohne den Umweg über
/// *Mehr › Körper*.
///
/// **Die Schritte-Kachel bleibt ohne Tür.** Ihr Schirm ist #84 und nicht
/// gebaut; eine Tür auf einen Platzhalter verspricht mehr als sie hält.
///
/// [router] `null` heißt „keine Tür" — dieselbe Regel wie bei der
/// Erholungskarte in `heute_view.dart`: Ohne Router gibt es kein Ziel, und
/// ein Schlüssel auf einer Fläche, die beim Tippen schweigt, ist schlimmer
/// als keiner.
List<KachelWert> zahlenKacheln(
  BuildContext context,
  DailyMetrics? heute,
  List<DailyMetrics> fenster, {
  required String heuteTag,
  required bool laedt,
  AppRouter? router,
}) {
  final steps = heute?.steps;

  DailyMetrics? letzteWaage;
  for (final tag in fenster) {
    if (tag.weightKg != null) letzteWaage = tag;
  }
  final gewicht = letzteWaage?.weightKg;

  return [
    KachelWert(
      label: 'Schritte',
      wert: steps == null ? null : formatNumber(steps.toDouble()),
      zusatz: laedt ? '' : (steps == null ? _ohneTrefferKurz : 'heute gezählt'),
      farbe: CupertinoDynamicColor.resolve(Palette.ok, context),
      platzhalter: laedt ? '00.000' : null,
      verlauf: _verlauf(fenster, heuteTag, (tag) => tag.steps?.toDouble()),
    ),
    KachelWert(
      label: 'Gewicht',
      wert: gewicht == null ? null : formatNumber(gewicht, nachkommastellen: 1),
      einheit: gewicht == null ? null : 'kg',
      verlauf: _verlauf(fenster, heuteTag, (tag) => tag.weightKg),
      zusatz: laedt
          ? ''
          : (gewicht == null
                ? _ohneTrefferKurz
                : _waageZusatz(_tageSeitDerWaage(letzteWaage, heuteTag))),
      farbe: CupertinoDynamicColor.resolve(Palette.bib, context),
      platzhalter: laedt ? '00,0' : null,
      schluessel: router == null ? null : const Key('heute-kachel-gewicht'),
      onTap: router == null
          ? null
          : () => oeffneMessungDetail(router, MessArt.gewicht),
    ),
  ];
}

/// Wie weit die Verlaufslinie zurückschaut, in Kalendertagen — heute
/// eingeschlossen, also die letzte Woche.
///
/// Tim, 16.11.2026 (#510): „nur eine Woche zurück zeigen, dann sind die
/// besser zu lesen." Das Rechenfenster bleibt bei 30 Tagen
/// (`rechenfensterTage`) — es trägt auch „vor N Tagen gemessen" und den
/// Gewichtswert selbst —, nur die Linie nimmt davon das jüngste Stück.
const _verlaufTage = 7;

/// Die Verlaufslinie einer Kachel: die Werte der **letzten Woche** des
/// Fensters (#510), **Lücken übersprungen** (#501, Punkt 4).
///
/// Begrenzt wird am [heuteTag] entlang `BerlinCalendar.daysBetween`, nicht
/// an der Listenposition: Das Fenster darf Löcher haben, und bei lückigem
/// Gewicht wären „die letzten 7 Einträge" sonst ein Monat — genau die
/// Kleinteiligkeit, die weg soll. Ein Tag, dessen Schlüssel sich nicht mit
/// [heuteTag] vergleichen lässt, fällt aus der Linie: Von ihm ist nicht zu
/// sagen, dass er in der Woche liegt.
///
/// Eine Lücke ist keine Null. Ein Tag ohne Waage-Wert als `0` in die
/// Reihe zu schreiben zöge die Linie auf den Boden und behauptete einen
/// Einbruch, den es nicht gab — Fehler `01`, nur als Kurve. Weil die
/// Linie nur die Richtung zeigt und keine Achse hat, ist das Überspringen
/// die ehrliche Form: Sie verbindet die Messungen, die es gibt.
///
/// **Unter zwei Punkten gibt es keine Linie**, und dann auch keine
/// leere: `null` statt einer einelementigen Liste — [Kacheln] zeichnet
/// den Streifen dann gar nicht erst. Die Kachel behält dabei Breite und
/// Beschriftung; was ihr fehlt, ist eine Linie, die es nie gab.
///
/// **`fenster` kommt aufsteigend herein, und hier wird nicht umsortiert.**
/// Beide Quellen liefern es so: der Cache über seine `ORDER BY`-Abfrage,
/// der Kanal, weil die Swift-Seite das Fenster über
/// `BerlinCalendar.days(from:through:)` aufbaut. Eine zweite Sortierung
/// an dieser Stelle wäre eine zweite Wahrheit über dieselbe Folge — und
/// diese Linie ist der erste Leser überhaupt, der sich auf die
/// Reihenfolge verlässt. Dreht eine der beiden Quellen sie um, läuft die
/// Kurve rückwärts, und **auffallen würde das nur am Gerät**.
List<double>? _verlauf(
  List<DailyMetrics> fenster,
  String heuteTag,
  double? Function(DailyMetrics) wert,
) {
  final werte = <double>[
    for (final tag in fenster)
      if (BerlinCalendar.daysBetween(from: tag.tag, to: heuteTag)
              case final int abstand
          when abstand >= 0 && abstand < _verlaufTage)
        if (wert(tag) case final double zahl) zahl,
  ];
  return werte.length < 2 ? null : werte;
}

/// Wie viele Tage der jüngste Waage-Wert zurückliegt.
///
/// Die Rechnung liegt im Kern (`BerlinCalendar.daysBetween`), nicht hier:
/// Ein Tagesabstand ist eine Formel, und sie von Hand zu rechnen ging
/// schon einmal schief — `DateTime.parse` liest einen Tagesschlüssel als
/// Ortszeit, und über eine Zeitumstellung hinweg schnitt `inDays` einen
/// Tag weg.
int? _tageSeitDerWaage(DailyMetrics? waage, String heuteTag) {
  if (waage == null) return null;
  return BerlinCalendar.daysBetween(from: waage.tag, to: heuteTag);
}

/// Wie alt der jüngste Waage-Wert ist, in Worten. `null` heißt: Die beiden
/// Tagesschlüssel ließen sich nicht vergleichen — dann bleibt es bei der
/// unbestimmten Beschriftung. Lässt sich der Abstand ausrechnen, steht er
/// auch da: „gestern gemessen" statt „zuletzt gemessen" (#196).
String _waageZusatz(int? tage) => switch (tage) {
  0 => 'heute gemessen',
  1 => 'gestern gemessen',
  final int t when t > 1 => 'vor $t Tagen gemessen',
  _ => 'zuletzt gemessen',
};

/// Die Ring-Beschriftung nennt den Rest, nicht den Stand (Entwurfskopf
/// `heute-kombi.js`): „noch 12 min" statt „18 von 30 min".
String _restText(double wert, double ziel, String einheit) {
  final rest = ziel - wert;
  if (rest > 0) return 'noch ${formatNumber(rest)} $einheit';
  if (rest == 0) return 'Ziel erreicht';
  return '${formatNumber(-rest)} $einheit darüber';
}
