// Was die ganze Reihe der Nächte sagt (#92) — die Reihe in Zeitfolge, die
// Statistiken über die beiden festen Zeiträume, die Tageswerte des
// Verlaufsdiagramms und Lage und Länge der letzten sieben Nächte, dazu die
// beiden Provider, die Verlauf und Lagen **halten** statt sie je Bild zu
// rechnen (Hausregel 2).
//
// **Gemeinsam ist allen der Stichtag:** Sie hängen an `heute` und an der
// geladenen Reihe, nicht an der gezeigten Nacht — beim Blättern ändert
// sich hier nichts. Genau deshalb stehen sie zusammen und nicht an
// `SchlafDaten`. Den Zeitraum schneidet eine private Hilfe, die Statistik
// und Nachtlagen teilen; ein Schnitt zwischen den beiden hätte sie
// öffentlich gemacht, ohne dass jemand sie von außen braucht.
//
// Herausgelöst aus `schlaf_zustand.dart` (#158, 29.10.2026, 1002 Zeilen
// waren es vorher). **Die festgelegte API bleibt
// `import '…/shell/schlaf_zustand.dart'`** — die Fassade exportiert diese
// Datei weiter. Tim hat „aufteilen" verlangt; wo der Schnitt liegt, hat
// der umsetzende Agent entschieden.
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../core/messwert.dart';
import '../health/health_provider.dart';
import '../health/health_types.dart';
import 'erholung_zustand.dart' show alsRecoveryNacht;
import 'schlaf_minuten.dart';

/// Die geladene Reihe in Zeitfolge — eine Kopie, die Eingabe bleibt, wie
/// sie war.
///
/// Öffentlich seit #158: Auswahl, Zeiträume, Verlauf und der Zustand
/// brauchen dieselbe Sortierung, und sie liegen nun in vier Dateien.
List<SleepNight> schlafChronologisch(List<SleepNight> naechte) =>
    [...naechte]..sort((a, b) => a.date.compareTo(b.date));

/// Der Zeitpunkt des Aufwachens: das Ende des **letzten Schlafabschnitts**,
/// nicht das Ende des Fensters. Dösen nach dem Aufwachen ist kein Schlaf.
DateTime? _aufwachen(SleepSession phase) {
  DateTime? letzter;
  for (final abschnitt in phase.segments) {
    if (abschnitt.stage == SleepStage.awake) continue;
    if (letzter == null || abschnitt.end.isAfter(letzter)) {
      letzter = abschnitt.end;
    }
  }
  return letzter;
}

/// Die beiden festen Zeiträume aus `docs/SPEC.md` 4.6.
const int schlafStatistikKurz = 7;

/// Siehe [schlafStatistikKurz].
const int schlafStatistikLang = 30;

/// Was mehrere Nächte zusammen sagen.
@immutable
class SchlafStatistik {
  const SchlafStatistik({
    required this.naechte,
    required this.schlafMinuten,
    required this.einschlafMinuten,
    required this.aufwachMinuten,
    required this.anteile,
  });

  /// Nächte **mit Schlaf** im Zeitraum.
  final int naechte;

  /// Ø Schlafdauer je Nacht, in Minuten.
  final double schlafMinuten;

  /// Ø Einschlafzeit, zirkulär gemittelt auf der Skala von [EveningClock].
  /// `null` heißt „es gibt kein Mittel" — in der Ansicht ein
  /// Gedankenstrich, keine erfundene Uhrzeit.
  final double? einschlafMinuten;

  /// Ø Aufwachzeit, ebenso.
  final double? aufwachMinuten;

  /// Die Phasenanteile, **gepoolt** über alle Nächte mit Phasendaten.
  final Map<SleepStage, double> anteile;
}

/// Die Nächte der [tage] Kalendertage **bis einschließlich** dem Tag von
/// [bis], chronologisch.
List<SleepNight> _imZeitraum({
  required List<SleepNight> naechte,
  required DateTime bis,
  required int tage,
}) {
  final letzter = BerlinCalendar.startOfDay(bis);
  final erster = BerlinCalendar.addDays(letzter, -(tage - 1));
  return [
    for (final nacht in schlafChronologisch(naechte))
      if (!nacht.date.isBefore(erster) && !nacht.date.isAfter(letzter)) nacht,
  ];
}

/// Über die [tage] Nächte **bis einschließlich** [bis]. `null`, wenn keine
/// davon Schlaf enthält.
///
/// **Feste Zeiträume, nicht das sichtbare Fenster** (`docs/SPEC.md` 4.6):
/// Sonst ändern sich beim Blättern Zahlen, die niemand gesucht hat. Der
/// Stichtag kommt deshalb als Parameter herein und ist `heute`, nie die
/// gewählte Nacht.
SchlafStatistik? schlafStatistik({
  required List<SleepNight> naechte,
  required DateTime bis,
  required int tage,
}) {
  final imZeitraum = _imZeitraum(naechte: naechte, bis: bis, tage: tage);
  // Das Kriterium sind die Schlafminuten, nicht „keine Abschnitte": Eine
  // Nacht aus lauter Wachabschnitten ist nicht leer, aber auch kein Schlaf.
  final mitSchlaf = [
    for (final nacht in imZeitraum)
      if (schlafMinutenVon(nacht.session) > 0) nacht,
  ];
  if (mitSchlaf.isEmpty) return null;

  var summeSchlaf = 0.0;
  final einschlafen = <double>[];
  final aufwachen = <double>[];
  final pool = <SleepStage, double>{};
  var poolSumme = 0.0;

  for (final nacht in mitSchlaf) {
    // Tagschlaf zählt nicht mit — sonst wäre ein Nickerchen ein Weg, den
    // eigenen Schnitt zu schönen.
    summeSchlaf += schlafMinutenVon(nacht.session);

    final kern = alsRecoveryNacht(nacht);
    final bettzeit = kern.bedtime;
    if (bettzeit != null) {
      einschlafen.add(EveningClock.minutesSinceEvening(bettzeit));
    }
    final auf = _aufwachen(nacht.session);
    if (auf != null) {
      aufwachen.add(EveningClock.minutesSinceEvening(auf));
    }

    // Die Anteile rechnen **nur über Nächte mit Phasendaten**: Eine ältere
    // Uhr liefert nur `unspecified`, und daraus ist kein Tiefschlafanteil
    // zu gewinnen. Zählte ihr Wachanteil trotzdem mit, verschöbe sie die
    // Anteile der anderen.
    if (!_hatPhasendaten(nacht.session)) continue;
    for (final abschnitt in nacht.session.segments) {
      final minuten = schlafMinutenZwischen(abschnitt.start, abschnitt.end);
      pool[abschnitt.stage] = (pool[abschnitt.stage] ?? 0) + minuten;
      poolSumme += minuten;
    }
  }

  return SchlafStatistik(
    naechte: mitSchlaf.length,
    schlafMinuten: summeSchlaf / mitSchlaf.length,
    einschlafMinuten: SleepStatistics.circularMeanMinutes(einschlafen),
    aufwachMinuten: SleepStatistics.circularMeanMinutes(aufwachen),
    anteile: poolSumme <= 0
        ? const {}
        : {
            for (final eintrag in pool.entries)
              eintrag.key: eintrag.value / poolSumme,
          },
  );
}

bool _hatPhasendaten(SleepSession phase) => phase.segments.any(
  (abschnitt) =>
      abschnitt.stage == SleepStage.rem ||
      abschnitt.stage == SleepStage.core ||
      abschnitt.stage == SleepStage.deep,
);

/// Die Schlafdauer je Nacht in **Stunden**, als Eingabe für
/// `diagrammPunkte` aus `lib/shell/diagramm_zeitraum.dart` (#94).
///
/// Eine Nacht ohne Schlafminuten **fehlt**: Sie ist keine gemessene Null,
/// und `diagrammPunkte` würde eine Null als Messwert zeichnen. Die
/// Verdichtung auf Monatsmittel macht `diagrammPunkte`, nicht diese
/// Funktion — hier steht ein Wert je Nacht, auch für `6M` und `J`.
List<({DateTime tag, double wert})> schlafTagewerte(List<SleepNight> naechte) {
  final ergebnis = <({DateTime tag, double wert})>[];
  for (final nacht in schlafChronologisch(naechte)) {
    final minuten = schlafMinutenVon(nacht.session);
    if (minuten <= 0) continue;
    ergebnis.add((tag: nacht.date, wert: minuten / Duration.minutesPerHour));
  }
  return ergebnis;
}

/// Die Phasen, nach denen der Verlauf seine Balken teilt — **von unten
/// nach oben** im Balken (#504).
///
/// **„Wach" ist nicht dabei**, und das ist eine Entscheidung, keine
/// Lücke: Die Höhe eines Balkens ist die Zeit *im Schlaf*
/// ([schlafMinutenVon] lässt `awake` aus). Ein Wach-Anteil in einem
/// Balken, dessen Höhe Wach gar nicht enthält, widerspräche sich — er
/// müsste entweder über den Balken hinausragen oder die Schlafphasen
/// kleiner rechnen, als sie waren.
///
/// **Der Verlauf und die Statistikblöcke nennen deshalb verschiedene
/// Prozente, und das ist kein Fehler in einem von beiden.** Sie
/// beantworten zwei Fragen über zwei Mengen:
///
/// | | [SchlafStatistik.anteile] | hier |
/// |---|---|---|
/// | Bezug | das Fenster **im Bett** | die Zeit **im Schlaf** |
/// | `awake` | zählt mit (sonst immer 0 %) | zählt nicht mit |
/// | Nacht ohne Phasendaten | fällt ganz heraus | steht als „ohne Angabe" da |
///
/// Beide **poolen** über die Nächte, statt Nachtanteile zu mitteln — nur
/// eben über verschiedene Nächte. Ein Monat, in dem ein Drittel der
/// Nächte ohne Phasen kam, zeigt im Balken darum kleinere Tief-, Kern-
/// und REM-Anteile als die Karte darüber. Wer das für einen Widerspruch
/// hält, hat recht in dem Sinn, dass es zwei Antworten sind; falsch ist
/// keine davon.
///
/// **Tief unten.** Dieselbe Lesart wie im Hypnogramm, wo die Spuren von
/// „Wach" oben bis „Tief" unten laufen (`SchlafPhasen.reihenfolge`) —
/// derselbe Schlaf soll in beiden Bildern dasselbe Oben und Unten haben.
///
/// **`unspecified` hat einen eigenen Platz** und wird nicht auf die
/// Kern-Spur geschlagen wie im Hypnogramm. Dort trägt ein Block seine
/// Farbe und ist einzeln ablesbar; hier verschwände er in einer Fläche
/// und behauptete eine Phase, die die Uhr nie gemeldet hat. Eine Nacht,
/// von der nur `unspecified` vorliegt, steht damit **einfarbig** da —
/// eine erfundene Verteilung wäre schlimmer als keine (`CLAUDE.md`).
const List<SleepStage> schlafVerlaufPhasen = [
  SleepStage.deep,
  SleepStage.core,
  SleepStage.rem,
  SleepStage.unspecified,
];

/// Je Nacht die Schlafstunden **je Phase**, in der Reihenfolge von
/// [schlafVerlaufPhasen] — die Teile, nach denen der Balken des Verlaufs
/// in sich geteilt wird (#504).
///
/// **Dieselben Nächte und dieselbe Folge wie [schlafTagewerte]**, und
/// dieselbe Einheit: Eine Nacht ohne Schlafminuten fehlt, und die Teile
/// einer Nacht ergeben zusammen genau ihre Balkenhöhe. Zwei Rechnungen
/// über dieselbe Nacht, die auseinanderliefen, zeigten einen Stapel, der
/// nicht zu seinem Balken passt.
///
/// **Stunden statt Anteilen**, weil ab `6M` ein Balken ein Kalendermonat
/// ist: Stunden lassen sich über einen Monat aufsummieren, Anteile nicht.
/// Der Anteil entsteht erst beim Zeichnen (`stapelGrenzen`).
///
/// Tagschlaf zählt nicht mit — gerechnet wird über `nacht.session`, wie
/// überall auf diesem Schirm (`docs/SPEC.md` 4.6).
List<({DateTime tag, List<double> teile})> schlafPhasenTagewerte(
  List<SleepNight> naechte,
) {
  final ergebnis = <({DateTime tag, List<double> teile})>[];
  for (final nacht in schlafChronologisch(naechte)) {
    if (schlafMinutenVon(nacht.session) <= 0) continue;
    final teile = List<double>.filled(schlafVerlaufPhasen.length, 0);
    for (final abschnitt in nacht.session.segments) {
      final index = schlafVerlaufPhasen.indexOf(abschnitt.stage);
      // Wachabschnitte stehen nicht in der Liste und fallen damit weg —
      // dieselbe Auslassung wie in `schlafMinutenVon`, nur an einer
      // Stelle ausgedrückt statt an zweien.
      if (index < 0) continue;
      teile[index] +=
          schlafMinutenZwischen(abschnitt.start, abschnitt.end) /
          Duration.minutesPerHour;
    }
    ergebnis.add((tag: nacht.date, teile: List<double>.unmodifiable(teile)));
  }
  return ergebnis;
}

/// Lage und Länge einer Nacht — der Abschnitt „Sieben Nächte".
@immutable
class SchlafNachtLage {
  const SchlafNachtLage({
    required this.datum,
    required this.von,
    required this.bis,
    required this.minutenJePhase,
  });

  final DateTime datum;

  /// Das Fenster über **alle** Abschnitte, auch die wachen.
  final DateTime von;
  final DateTime bis;

  final Map<SleepStage, double> minutenJePhase;
}

/// Die letzten [anzahl] Nächte bis einschließlich [bis], chronologisch.
///
/// Derselbe Kalenderzeitraum wie bei [schlafStatistik] und aus demselben
/// Grund: Ein Tag ohne Nacht fehlt dann sichtbar, statt eine ältere Nacht
/// nachrücken zu lassen.
List<SchlafNachtLage> schlafLetzteNaechte({
  required List<SleepNight> naechte,
  required DateTime bis,
  int anzahl = 7,
}) {
  final ergebnis = <SchlafNachtLage>[];
  for (final nacht in _imZeitraum(naechte: naechte, bis: bis, tage: anzahl)) {
    final (von, nachtEnde) = schlafFensterVon(nacht.session);
    if (von == null || nachtEnde == null) continue;
    final jePhase = <SleepStage, double>{};
    for (final abschnitt in nacht.session.segments) {
      jePhase[abschnitt.stage] =
          (jePhase[abschnitt.stage] ?? 0) +
          schlafMinutenZwischen(abschnitt.start, abschnitt.end);
    }
    ergebnis.add(
      SchlafNachtLage(
        datum: nacht.date,
        von: von,
        bis: nachtEnde,
        minutenJePhase: jePhase,
      ),
    );
  }
  return ergebnis;
}

/// Die Schlafdauer je Nacht als Reihe für das Verlaufsdiagramm —
/// **gehalten**, nicht je Bild gerechnet (Hausregel 2).
///
/// Ein eigener Provider und kein Feld an [SchlafDaten], aus demselben Grund
/// wie bei [schlafLagenProvider]: Der Verlauf hängt an der Reihe, nicht an
/// der gezeigten Nacht, und ändert sich beim Blättern nicht.
///
/// Verdichtet wird erst im Diagramm (`diagrammPunkte`); hier steht ein Wert
/// je Nacht.
final schlafTagewerteProvider =
    Provider.autoDispose<List<({DateTime tag, double wert})>>((ref) {
      final naechte = ref.watch(sleepProvider).value;
      final liste = naechte is Bekannt<List<SleepNight>>
          ? naechte.wert
          : const <SleepNight>[];
      return schlafTagewerte(liste);
    });

/// Die Phasen je Nacht als Teile für die gestapelten Balken des Verlaufs
/// — **gehalten**, nicht je Bild gerechnet (Hausregel 2).
///
/// Ein zweiter Provider neben [schlafTagewerteProvider] und kein zweites
/// Feld daran: Dessen Form ist seit #139 festgenagelt, und ein Verlauf
/// ohne Phasendaten soll weiter einen Balken bekommen. Beide hängen an
/// derselben Reihe und ändern sich beim Blättern nicht.
final schlafPhasenTagewerteProvider =
    Provider.autoDispose<List<({DateTime tag, List<double> teile})>>((ref) {
      final naechte = ref.watch(sleepProvider).value;
      final liste = naechte is Bekannt<List<SleepNight>>
          ? naechte.wert
          : const <SleepNight>[];
      return schlafPhasenTagewerte(liste);
    });

/// Lage und Länge der letzten sieben Nächte — **gehalten**, nicht je Bild
/// gerechnet (Hausregel 2).
///
/// Ein eigener Provider und kein Feld an [SchlafDaten]: Der Abschnitt
/// hängt an `heute` und an der Reihe, nicht an der gezeigten Nacht — er
/// ändert sich beim Blättern nicht, und das soll man am Schnitt sehen.
final schlafLagenProvider = Provider.autoDispose<List<SchlafNachtLage>>((ref) {
  final naechte = ref.watch(sleepProvider).value;
  final liste = naechte is Bekannt<List<SleepNight>>
      ? naechte.wert
      : const <SleepNight>[];
  return schlafLetzteNaechte(naechte: liste, bis: ref.watch(clockProvider)());
});
