// Der Zustand des Schirms `erholung-werte` (#117) — alles, was der Schirm
// entscheidet, einmal gerechnet und ohne Widget prüfbar. Die Oberfläche
// liegt in `erholung_werte_view.dart`, ihre Bausteine in
// `erholung_werte_abschnitte.dart`.
//
// API und Vertrag sind durch `app/test/shell/erholung_werte_zustand_test.dart`
// verbindlich vorgegeben (siehe dessen Dateikopf) — diese Datei darf die
// Tests ausführen, aber nicht verändern (`CLAUDE.md`, „Wer Tests schreibt,
// schreibt nicht die Implementierung").
//
// **Die Schwellen stehen hier nirgends als Zahl.** Jede Grenze, jede Regel
// und jeder ausgerechnete Wert rechnet mit [RecoveryTrafficLight]: In Swift
// stehen 5, 0,8 und 1,5 dreifach im Quelltext (einmal als Wahrheit, zweimal
// als Beschriftung), und kein Test bindet sie aneinander.
//
// **Alle Sätze sind Nutzertexte und bleiben deshalb hier bzw. in der View**,
// nie in `trainings_core` (`CLAUDE.md`).
import 'package:flutter/cupertino.dart';
import 'package:trainings_core/trainings_core.dart';

import '../core/messwert.dart';
import '../design/formatierung.dart';
import '../design/palette.dart';
import 'erholung_abschnitte.dart';
import 'erholung_zustand.dart';
import 'vital_texte.dart';

// ─────────────────────────────────────────────────────────────────────────
// Der Balken hinter einem Wert
// ─────────────────────────────────────────────────────────────────────────

/// Der Balken hinter einem Wert — **ein** Feld statt vier, die zueinander
/// passen müssen.
///
/// „Fehlt der Median, fällt der Balken ganz weg" ist damit unausdrückbar
/// falsch: Ohne Median entsteht gar kein [Normalbalken], nicht einer mit
/// `median: null`.
@immutable
class Normalbalken {
  const Normalbalken({
    required this.skala,
    required this.normalbereich,
    required this.median,
    required this.marke,
  });

  /// Die feste Anzeigeskala der Metrik (Ticket Abschnitt 2) — nicht aus den
  /// Daten abgeleitet: Eine Skala, die mit dem Wert wandert, zeigt jeden
  /// Tag dieselbe Lage.
  final ({double von, double bis}) skala;

  /// Der Bereich ohne Warnsignal, in Einheiten der Metrik.
  final ({double von, double bis}) normalbereich;

  final double median;

  /// Der Wert von heute Nacht, **ungeklemmt** — geklemmt wird erst in
  /// [markeAnteil]. Wer die Zahl selbst beschriftet, soll die gemessene
  /// sehen, nicht die ins Feld gerückte.
  final double marke;

  /// Lage auf der Skala, 0…1, geklemmt.
  double get markeAnteil => _anteil(marke);

  double get medianAnteil => _anteil(median);

  ({double von, double bis}) get normalbereichAnteil =>
      (von: _anteil(normalbereich.von), bis: _anteil(normalbereich.bis));

  double _anteil(double wert) {
    final spanne = skala.bis - skala.von;
    if (spanne <= 0) return 0;
    final anteil = (wert - skala.von) / spanne;
    if (anteil < 0) return 0;
    if (anteil > 1) return 1;
    return anteil;
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Ein Wert der Ampelkarte
// ─────────────────────────────────────────────────────────────────────────

/// Ein Wert der Ampelkarte, fertig beschriftet.
@immutable
class Vitalwert {
  const Vitalwert({
    required this.metrik,
    required this.name,
    required this.wert,
    required this.bildunterschrift,
    required this.ton,
    this.balken,
  });

  final RecoveryMetric metrik;
  final String name;

  /// „7:00 h", „68 bpm" — oder [keinWert], nie „0".
  final String wert;

  /// „Normal 6:29 h · Signal unter 6:00 h".
  final String bildunterschrift;

  /// Unaufgelöst — aufgelöst wird beim Zeichnen, sonst bliebe die Farbe im
  /// Dunkelmodus auf ihrer hellen Variante stehen.
  final CupertinoDynamicColor ton;

  /// `null` heißt „kein Normalbereich".
  final Normalbalken? balken;

  /// Nur der Normalwert, ohne die Schwelle dahinter — kappt am ersten
  /// „ · ".
  ///
  /// Kein Versehen, sondern ein bewusster Zweittext: Im Erholung-Tab steht
  /// jeder Wert über die volle Breite, da passt „Normal 6:29 h · Signal
  /// unter 6:00 h". Auf Heute liegen vier Werte nebeneinander, und dort
  /// brach derselbe Satz nach „· Si…" ab — eine abgeschnittene Schwelle ist
  /// keine Auskunft.
  String get kurzeBildunterschrift => bildunterschrift.split(' · ').first;
}

// ─────────────────────────────────────────────────────────────────────────
// Die Statuskarte
// ─────────────────────────────────────────────────────────────────────────

/// Die Statuskarte als Wert.
///
/// **Sie verschwindet in keinem Zustand** — der Rückgabetyp von
/// [werteStatus] ist deshalb nicht nullbar. Eine fehlende Karte hieße
/// gleichzeitig „alles gut", „die Uhr hat nichts aufgezeichnet" und „die App
/// darf nicht lesen"; den Unterschied verrät HealthKit nicht, also muss die
/// Oberfläche ihn aussprechen.
@immutable
class WerteStatus {
  const WerteStatus({
    required this.ueberschrift,
    required this.unterzeile,
    required this.absaetze,
    required this.kante,
    required this.zeigtHealthEinstellungen,
    required this.werte,
  });

  final String ueberschrift;
  final String unterzeile;

  /// Der Rat darunter. **Darf leer sein** — die Karte nicht.
  final List<String> absaetze;

  final CupertinoDynamicColor kante;
  final bool zeigtHealthEinstellungen;

  /// Immer genau vier, je eine Metrik, in der Reihenfolge von
  /// [RecoveryMetric] — Schlaf zuerst (Tims Entscheidung vom 27.10.2026).
  /// Dieselbe Reihenfolge trägt die Aufteilung des Erholungsrings; Ring,
  /// Liste und Schwellen sagen damit dasselbe.
  final List<Vitalwert> werte;
}

/// Die Statuskarte zu jedem der vier Zustände von [Messwert].
///
/// **Rat, Kantenfarbe und der Weg in die Health-Einstellungen kommen aus
/// [erholungHinweis]**, nicht aus eigenen Sätzen: Dieselbe Lage steht auf
/// dem Erholung-Schirm im Hinweiskasten, und zwei Stellen, die denselben Rat
/// getrennt formulieren, driften auseinander. In Swift tun sie das bereits.
WerteStatus werteStatus(Messwert<ErholungDaten> daten) {
  switch (daten) {
    case Bekannt<ErholungDaten>(:final wert):
      return _ausSchnappschuss(wert.schnappschuss);

    // `docs/todo/01`: Im Ladezweig steht die Karte — und gerade deshalb darf
    // sie hier nicht behaupten, es gebe nichts.
    case NochNie<ErholungDaten>():
      return _ohneSchnappschuss(
        ueberschrift: 'Werte werden geladen',
        unterzeile: 'Die Werte von heute Nacht werden gerade gelesen.',
        bildunterschrift: 'wird geladen',
      );

    // Der eine Zustand, der einen „keine Daten"-Grund nennen darf.
    case LeerNachLauf<ErholungDaten>():
      final hinweis = erholungHinweis(
        bewertung: const RecoveryEvaluation(
          verdict: RecoveryVerdict.noData,
          signals: [],
          measuredCount: 0,
        ),
        messwerte: const RecoveryReading(),
        baseline: const RecoveryBaseline(),
      )!;
      return _ohneSchnappschuss(
        ueberschrift: _ueberschrift(RecoveryVerdict.noData),
        unterzeile: _ohneVorgeschichte,
        bildunterschrift: 'kein Wert',
        absaetze: hinweis.absaetze,
        kante: hinweis.kante,
        zeigtHealthEinstellungen: hinweis.zeigtHealthEinstellungen,
      );

    // Ein gescheiterter Lauf ist keine Aussage über die Datenlage: kein
    // Grund, kein Weg in die Health-Einstellungen.
    case Fehlgeschlagen<ErholungDaten>():
      return _ohneSchnappschuss(
        ueberschrift: 'Werte nicht geladen',
        unterzeile:
            'Der letzte Versuch hat nicht geklappt. Das sagt nichts über '
            'deine Werte.',
        bildunterschrift: 'nicht geladen',
      );
  }
}

/// Die Karte ohne Schnappschuss: vier Striche, kein Balken, kein erfundenes
/// Datum.
WerteStatus _ohneSchnappschuss({
  required String ueberschrift,
  required String unterzeile,
  required String bildunterschrift,
  List<String> absaetze = const [],
  CupertinoDynamicColor kante = Palette.rest,
  bool zeigtHealthEinstellungen = false,
}) {
  return WerteStatus(
    ueberschrift: ueberschrift,
    unterzeile: unterzeile,
    absaetze: absaetze,
    kante: kante,
    zeigtHealthEinstellungen: zeigtHealthEinstellungen,
    werte: [
      for (final metrik in RecoveryMetric.values)
        Vitalwert(
          metrik: metrik,
          name: vitalName(metrik),
          wert: keinWert,
          bildunterschrift: bildunterschrift,
          ton: Palette.muted,
        ),
    ],
  );
}

WerteStatus _ausSchnappschuss(RecoverySnapshot schnappschuss) {
  final bewertung = schnappschuss.evaluation;
  final hinweis = erholungHinweis(
    bewertung: bewertung,
    messwerte: schnappschuss.reading,
    baseline: schnappschuss.baseline,
  );

  return WerteStatus(
    ueberschrift: _ueberschrift(bewertung.verdict),
    unterzeile: _unterzeile(schnappschuss),
    // Bei `calm` gibt es nichts zu raten — der Absatz fällt weg, die Karte
    // bleibt.
    absaetze: hinweis?.absaetze ?? const [],
    kante: hinweis?.kante ?? Palette.ok,
    zeigtHealthEinstellungen: hinweis?.zeigtHealthEinstellungen ?? false,
    werte: [
      for (final metrik in RecoveryMetric.values)
        _vitalwert(metrik, schnappschuss),
    ],
  );
}

/// Der Wortlaut der Swift-Vorlage (`RecoveryWording.headline`).
///
/// **Abweichung, gemeldet:** `heute_view.dart` schreibt bei `calm` „Gut
/// erholt"; `heute_erholungskarte_test.dart` hält das fest. Beide Schirme
/// sollten dasselbe sagen — das anzugleichen ändert eine fremde Testdatei
/// und ist deshalb eine eigene Entscheidung, keine Nebenwirkung dieses
/// Schirms.
String _ueberschrift(RecoveryVerdict verdikt) => switch (verdikt) {
  RecoveryVerdict.calm => 'Sieht gut aus',
  RecoveryVerdict.watch => 'Achte auf dich',
  RecoveryVerdict.stressed => 'Achte auf dich',
  RecoveryVerdict.noData => 'Keine Werte von der Uhr',
  RecoveryVerdict.postOperative => 'Erholung nach der OP',
};

String _unterzeile(RecoverySnapshot schnappschuss) {
  final bewertung = schnappschuss.evaluation;
  switch (bewertung.verdict) {
    case RecoveryVerdict.calm:
      return bewertung.measuredCount == RecoveryMetric.values.length
          ? 'Alle vier Werte in deinem Normalbereich'
          : '${bewertung.measuredCount} gemessene Werte, alle im '
                'Normalbereich';

    case RecoveryVerdict.watch:
    case RecoveryVerdict.stressed:
      return '${bewertung.signals.length} von ${bewertung.measuredCount} '
          'Werten außerhalb deines Normalbereichs';

    case RecoveryVerdict.noData:
      final zuletzt = schnappschuss.lastSeen;
      if (zuletzt == null) return _ohneVorgeschichte;
      return 'Zuletzt am ${Format.tagMonat(kalendertag(zuletzt))}';

    // Ohne Ereignis-Objekte (#41) gibt es keinen OP-Tag, und ein Datum aus
    // dem Quelltext wäre eine Behauptung (`CLAUDE.md`).
    case RecoveryVerdict.postOperative:
      return 'Die Ampel pausiert bis zur ärztlichen Freigabe';
  }
}

const _ohneVorgeschichte = 'Seit mehreren Tagen kein Wert';

Vitalwert _vitalwert(RecoveryMetric metrik, RecoverySnapshot schnappschuss) {
  final wert = vitalMesswert(metrik, schnappschuss.reading);
  final median = vitalMedian(metrik, schnappschuss.baseline);

  // Kein Wert, kein Balken — auch wenn ein Median vorliegt. Ein Balken ohne
  // Marke wäre dieselbe leere Behauptung wie einer ohne Normalbereich.
  if (wert == null) {
    final zuletzt = schnappschuss.lastSeen;
    return Vitalwert(
      metrik: metrik,
      name: vitalName(metrik),
      wert: keinWert,
      bildunterschrift: zuletzt == null
          ? 'kein Wert'
          : 'kein Wert seit ${Format.tagMonat(kalendertag(zuletzt))}',
      ton: Palette.muted,
    );
  }

  final nachOp = schnappschuss.isPostOperative;
  final istSignal = schnappschuss.evaluation.signals.contains(metrik);

  return Vitalwert(
    metrik: metrik,
    name: vitalName(metrik),
    wert: vitalWertText(metrik, wert),
    bildunterschrift: _bildunterschrift(metrik, median: median, nachOp: nachOp),
    // Grau heißt auf diesem Schirm „kein Wert". Ein gemessener Wert, der
    // schlechter als sein Median, aber noch kein Signal ist, trägt deshalb
    // [Palette.ink] — er darf nicht aussehen wie ein fehlender.
    ton: nachOp
        ? Palette.muted
        : istSignal
        ? Palette.warn
        : _besserAlsMedian(metrik, wert: wert, median: median)
        ? Palette.ok
        : Palette.ink,
    // Nach der OP bewertet die Ampel nicht — dann auch kein Normalband.
    balken: median == null || nachOp
        ? null
        : Normalbalken(
            skala: _skala(metrik),
            normalbereich: _ohneWarnsignal(metrik, median: median),
            median: median,
            marke: wert,
          ),
  );
}

// Name, Messwert, Median und die Schreibweise mit Einheit standen bis
// zum 16.11.2026 hier — und auf Home noch einmal, in einer anderen
// Fassung (#501). Jetzt stehen sie **einmal**, in `vital_texte.dart`;
// dieser Schirm und Home lesen dieselbe Tabelle. Was hier bleibt, ist
// die lange Bildunterschrift mit der Schwelle: Die gibt es nur auf
// diesem Schirm, wo jeder Wert eine eigene Zeile über die volle Breite
// hat.

String _bildunterschrift(
  RecoveryMetric metrik, {
  required double? median,
  required bool nachOp,
}) {
  if (median == null) return 'kein Normalbereich — zu wenige Messwerte';

  final normal = vitalNormalText(metrik, median);
  if (nachOp) return '$normal · nach einer OP erwartbar';

  return switch (metrik) {
    RecoveryMetric.sleep =>
      '$normal · Signal unter '
          '${stundenText(RecoveryTrafficLight.minimumSleepHours)}',
    RecoveryMetric.restingHeartRate =>
      '$normal · Signal ab '
          '${(median + RecoveryTrafficLight.restingHeartRateMargin).round()} '
          'bpm',
    RecoveryMetric.hrv =>
      '$normal · Signal ab '
          '${(median * RecoveryTrafficLight.hrvFactor).round()} ms abwärts',
    RecoveryMetric.respiratoryRate =>
      '$normal · Signal ab '
          '${kommazahl(median + RecoveryTrafficLight.respiratoryRateMargin)}'
          '/min',
  };
}

/// Die festen Anzeigeskalen des Tickets.
({double von, double bis}) _skala(RecoveryMetric metrik) => switch (metrik) {
  RecoveryMetric.sleep => (von: 3, bis: 10),
  RecoveryMetric.restingHeartRate => (von: 50, bis: 80),
  RecoveryMetric.hrv => (von: 25, bis: 75),
  RecoveryMetric.respiratoryRate => (von: 8, bis: 16),
};

/// Der Bereich ohne Warnsignal — jede Grenze aus [RecoveryTrafficLight].
///
/// **Er endet nie außerhalb der Skala:** Ein Median am oberen Rand schöbe
/// die Schwelle sonst aus dem Feld hinaus, und der grüne Balken liefe über
/// die Karte.
({double von, double bis}) _ohneWarnsignal(
  RecoveryMetric metrik, {
  required double median,
}) {
  final skala = _skala(metrik);
  double hoechstens(double wert) => wert < skala.bis ? wert : skala.bis;
  double mindestens(double wert) => wert > skala.von ? wert : skala.von;

  return switch (metrik) {
    // Feste Grenze, unabhängig vom Median und vom Schlafziel.
    RecoveryMetric.sleep => (
      von: mindestens(RecoveryTrafficLight.minimumSleepHours),
      bis: skala.bis,
    ),
    RecoveryMetric.restingHeartRate => (
      von: skala.von,
      bis: hoechstens(median + RecoveryTrafficLight.restingHeartRateMargin),
    ),
    RecoveryMetric.hrv => (
      von: mindestens(median * RecoveryTrafficLight.hrvFactor),
      bis: skala.bis,
    ),
    RecoveryMetric.respiratoryRate => (
      von: skala.von,
      bis: hoechstens(median + RecoveryTrafficLight.respiratoryRateMargin),
    ),
  };
}

/// Bei HRV und Schlaf ist mehr besser, bei Ruhepuls und Atemfrequenz
/// weniger. Ohne Median gibt es nichts zu vergleichen.
bool _besserAlsMedian(
  RecoveryMetric metrik, {
  required double wert,
  required double? median,
}) {
  if (median == null) return false;
  return switch (metrik) {
    RecoveryMetric.sleep || RecoveryMetric.hrv => wert >= median,
    RecoveryMetric.restingHeartRate ||
    RecoveryMetric.respiratoryRate => wert <= median,
  };
}

// ─────────────────────────────────────────────────────────────────────────
// Die Schwellen
// ─────────────────────────────────────────────────────────────────────────

/// Eine Zeile von „Die Schwellen": Regel **und** ausgerechneter Wert.
///
/// Der Entwurf lässt die Regel weg und zeigt nur „ab 71 bpm". Eine Zahl
/// ohne ihre Regel lässt sich nicht nachrechnen — und beim nächsten Median
/// ist sie eine andere.
@immutable
class SchwellenZeile {
  const SchwellenZeile({
    required this.metrik,
    required this.titel,
    required this.regel,
    required this.wert,
  });

  final RecoveryMetric metrik;
  final String titel;

  /// „5 bpm über dem Median" — die Zahl aus [RecoveryTrafficLight].
  final String regel;

  /// „ab 59 bpm" — oder [_keinMedian].
  final String wert;
}

const _keinMedian = 'kein Median';

/// Vier Zeilen, je Metrik eine, in der Reihenfolge von [RecoveryMetric].
///
/// **Nimmt keine `Ziele` entgegen:** Die Schlafschwelle hängt nicht am
/// Schlafziel, und was eine Funktion nicht bekommt, kann sie nicht
/// einrechnen.
List<SchwellenZeile> schwellenZeilen(RecoveryBaseline baseline) {
  return [
    for (final metrik in RecoveryMetric.values)
      SchwellenZeile(
        metrik: metrik,
        titel: vitalName(metrik),
        regel: _regel(metrik),
        wert: _schwellenwert(metrik, vitalMedian(metrik, baseline)),
      ),
  ];
}

String _regel(RecoveryMetric metrik) => switch (metrik) {
  RecoveryMetric.sleep => 'feste Grenze, unabhängig vom Ziel',
  RecoveryMetric.restingHeartRate =>
    '${RecoveryTrafficLight.restingHeartRateMargin.round()} bpm über dem '
        'Median',
  // Die Prozentzahl ist `1 − hrvFactor`, keine zweite Zahl daneben.
  RecoveryMetric.hrv =>
    '${((1 - RecoveryTrafficLight.hrvFactor) * 100).round()} % unter dem '
        'Median',
  RecoveryMetric.respiratoryRate =>
    '${kommazahl(RecoveryTrafficLight.respiratoryRateMargin)} über dem Median',
};

String _schwellenwert(RecoveryMetric metrik, double? median) => switch (metrik) {
  // Nur der Schlaf hat eine feste Schwelle — er braucht keinen Median und
  // hängt **nicht** am Schlafziel.
  RecoveryMetric.sleep =>
    'unter ${stundenText(RecoveryTrafficLight.minimumSleepHours)}',
  RecoveryMetric.restingHeartRate => median == null
      ? _keinMedian
      : 'ab '
            '${(median + RecoveryTrafficLight.restingHeartRateMargin).round()}'
            ' bpm',
  RecoveryMetric.hrv => median == null
      ? _keinMedian
      : 'ab ${(median * RecoveryTrafficLight.hrvFactor).round()} ms',
  RecoveryMetric.respiratoryRate => median == null
      ? _keinMedian
      : 'ab '
            '${kommazahl(median + RecoveryTrafficLight.respiratoryRateMargin)}'
            '/min',
};

// ─────────────────────────────────────────────────────────────────────────
// Das Signalband
// ─────────────────────────────────────────────────────────────────────────

/// Die drei Zähler unter dem Signalband.
@immutable
class BandLegende {
  const BandLegende({
    required this.ohneSignal,
    required this.einSignal,
    required this.zweiUndMehr,
  });

  final int ohneSignal;
  final int einSignal;
  final int zweiUndMehr;
}

/// **Nicht gemessene Tage zählen in keinem der drei Zähler** — sie sind
/// weder ruhig noch auffällig, sondern leer.
BandLegende bandLegende(List<DaySignals> tage) {
  var ohne = 0;
  var eins = 0;
  var mehr = 0;
  for (final tag in tage) {
    if (!tag.measured) continue;
    if (tag.count >= 2) {
      mehr += 1;
    } else if (tag.count == 1) {
      eins += 1;
    } else {
      ohne += 1;
    }
  }
  return BandLegende(ohneSignal: ohne, einSignal: eins, zweiUndMehr: mehr);
}

/// Gemessen → `30 + Signale · 14`, nicht gemessen → 10.
///
/// Ein grauer Stummel ist etwas anderes als ein grüner Balken: „kein
/// Signal" und „nicht gemessen" zeigen dieselbe Null und bedeuten das
/// Gegenteil voneinander.
double bandHoehe(DaySignals tag) =>
    tag.measured ? _grundhoehe + tag.count * _jeSignal : _stummel;

const double _grundhoehe = 30;
const int _jeSignal = 14;

const double _stummel = 10;

/// Unaufgelöst — aufgelöst wird beim Zeichnen.
CupertinoDynamicColor bandFarbe(DaySignals tag) {
  if (!tag.measured) return Palette.rest;
  if (tag.count >= 2) return Palette.warn;
  if (tag.count == 1) return Palette.bib;
  return Palette.ok;
}
