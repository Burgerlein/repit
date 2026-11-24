// Der Zustand des Ausdauer-Schirms (#95, mit #16) — alles, was der Schirm
// zeigt, einmal gerechnet und ohne Widget prüfbar. Die Oberfläche liegt in
// `ausdauer_view.dart`.
//
// Verhalten und API der Oberfläche sind durch
// `app/test/shell/ausdauer_view_test.dart` verbindlich vorgegeben (siehe
// dessen Dateikopf) — diese Datei darf die Tests ausführen, aber nicht
// verändern (`CLAUDE.md`, „Wer Tests schreibt, schreibt nicht die
// Implementierung").
//
// **Die Rechnungen liegen im Kern.** VO₂max-Schätzung (`VO2MaxEstimate`),
// Einordnung (`VO2MaxRating`), HM-Prognose (`RacePrediction`), Zonen
// (`HeartRateZones`), Ruhepuls-Herleitung (`RestingHeartRate`) und
// Zonenverteilung (`ZoneDistribution`) — hier wird zusammengesetzt, nicht
// nachgerechnet. Fachliche Vorlage ist `EnduranceStore.swift`.
//
// **Die Watch-Reihe kommt über `vo2maxReihe` aus dem Cache** (Schema v26),
// nicht aus `dailyMetricsProvider`: Das Rechenfenster sind 30 Tage, die
// Jahresstufe des Diagramms braucht mehr — dieselbe Entscheidung wie in
// `messung_detail_zustand.dart`. Der `Messwert`-Zustand kommt trotzdem von
// den Tageswerten; nebenbei ist das die Stelle, die den Lauf anstößt, der
// den Cache füllt.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../core/async_bruecke.dart';
import '../core/messwert.dart';
import '../data/cache_repository.dart';
import '../health/health_provider.dart';
import '../health/health_types.dart' as kanal
    show DailyMetrics, WorkoutKind, WorkoutSample;
import 'diagramm_zeitraum.dart';

/// Die Stufen dieses Schirms: **M 6M J** — kein `T`, kein `W`, und keine
/// Stufe „Alles" (Tim am 26.10.2026: es bleibt bei den fünfen app-weit).
/// Die Watch liefert VO₂max nicht täglich; `M` ist die engste angebotene
/// Stufe und damit nach der Hausregel die Startstufe (`startStufe`).
const List<DiagrammStufe> ausdauerStufen = [
  DiagrammStufe.monat,
  DiagrammStufe.halbjahr,
  DiagrammStufe.jahr,
];

/// HFmax für die Karvonen-Zonen — dieselbe Festlegung wie in der
/// Swift-Vorlage (`EnduranceStore.swift:21`, aus SPEC 3 Z. 42 / 4.7):
/// aus den höchsten Werten der Health-Daten, nicht aus der Altersformel.
/// Eine Zahl aus der SPEC, kein Ereignisdatum. Sie wandert in die
/// Einstellungen, sobald es die gibt — bis dahin ist dies die **eine**
/// Stelle, die sie kennt.
const int ausdauerHfMax = 205;

/// Das Fenster der Zonenverteilung in Tagen — „Anteil der Laufzeit je
/// Zone, letzte 30 Tage" (Entwurf `ausdauer.js`).
const int verteilungsTage = 30;

/// Das Fenster des Erholungspuls-Schnitts in Tagen — „Ø letzte 30 Tage"
/// (Entwurf `ausdauer.js`, `ERHOLUNGSPULS`).
///
/// **Eigene Konstante, obwohl die Zahl dieselbe ist wie bei
/// [verteilungsTage].** Beide Fenster bedeuten Verschiedenes, und die
/// Beschriftung des Erholungspulses nennt ihre dreißig Tage ausdrücklich:
/// Wer das Verteilungsfenster änderte, änderte sonst stillschweigend eine
/// Zusage, die der Schirm woanders macht — „keine Zusage stehen lassen,
/// die nicht mehr stimmt" (`CLAUDE.md`).
const int erholungsSchnittTage = 30;

/// Die Veränderung der Watch-Kurve wird gegen den ältesten Wert der
/// letzten 90 Tage gerechnet (`EnduranceStore.swift:70`).
const int trendTage = 90;

/// Woraus Einordnung und Prognose rechnen — die Oberfläche nennt die
/// Herkunft (Entwurf, Variante `laufband`).
enum PrognoseQuelle { watch, eigeneSchaetzung }

/// Was der Ausdauer-Schirm aus Apple Health ableitet, einmal gerechnet.
///
/// **Alles sind Felder, keine berechneten Eigenschaften** — eine
/// berechnete Eigenschaft rechnet je Bild, das war Fehler `03`.
///
/// Werttyp mit `==` und `hashCode`: Die Reihen gehen in ein Diagramm;
/// ohne Wertgleichheit wäre jede neu gelesene Reihe ungleich der vorigen
/// und das Diagramm liefe bei jedem Bild neu.
@immutable
class AusdauerDaten {
  const AusdauerDaten({
    required this.watchReihe,
    required this.eigeneReihe,
    required this.watchAktuell,
    required this.eigeneAktuell,
    required this.trendDelta,
    required this.quelle,
    required this.einordnung,
    required this.potenzialMinuten,
    required this.realistischMinuten,
    required this.erholungJuengster,
    required this.erholungSchnitt30,
    required this.ruhepulsBpm,
    required this.ruhepulsQuelle,
    required this.zonen,
    required this.verteilung,
    required this.anteilZone12,
  });

  /// Der VO₂max-Verlauf der Watch, ein Punkt je Tag mit Wert, aufsteigend.
  /// Lücken bleiben Lücken — die Watch schätzt nur draußen mit GPS.
  final List<MeasurementPoint> watchReihe;

  /// Die eigene Schätzung nach Daniels und Gilbert, ein Punkt je Tag mit
  /// Lauf ≥ 3 Minuten und bekannter Distanz; bei mehreren Läufen am Tag
  /// zählt der späteste. Entsteht auch auf dem Laufband — ohne GPS.
  final List<MeasurementPoint> eigeneReihe;

  /// Der jüngste Watch-Wert, `null` ohne einen einzigen.
  final double? watchAktuell;

  /// Die eigene Schätzung aus dem **jüngsten** Lauf mit Distanz,
  /// unabhängig vom Tag — `null` ohne einen solchen Lauf.
  final double? eigeneAktuell;

  /// Jüngster Watch-Wert minus ältester Watch-Wert der letzten
  /// [trendTage] Tage; `null` unter zwei Punkten in diesem Fenster.
  final double? trendDelta;

  /// Woraus Einordnung und Prognose rechnen: der Watch-Wert, wenn es
  /// einen gibt, sonst die eigene Schätzung — `null` ohne beides.
  final PrognoseQuelle? quelle;

  /// Einordnung nach SPEC 4.7 (Männer 20–29); `null` ohne [quelle].
  final VO2MaxRating? einordnung;

  /// HM-Potenzial nach Daniels-VDOT in Minuten; `null` ohne [quelle].
  final double? potenzialMinuten;

  /// Potenzial × 1,12 — die realistische Zahl für Einsteiger.
  final double? realistischMinuten;

  /// Der jüngste Erholungspuls-Abfall (1 min nach Belastung, höchster
  /// Wert des Tages) aus den Tageswerten; `null` ohne einen einzigen.
  final int? erholungJuengster;

  /// Das Mittel der Erholungspuls-Werte der letzten [erholungsSchnittTage]
  /// Tage; `null` ohne einen einzigen. Die Beschriftung des Schirms („Ø
  /// letzte 30 Tage") nennt genau dieses Fenster.
  final double? erholungSchnitt30;

  /// Der Ruhepuls der Zonenrechnung — Median der letzten 30 Werte,
  /// sonst die allgemeine Annahme des Kerns ([RestingHeartRate]).
  final int ruhepulsBpm;

  /// Woher [ruhepulsBpm] stammt — die Oberfläche nennt es.
  final RestingHeartRateSource ruhepulsQuelle;

  /// Die fünf Karvonen-Zonen aus [ausdauerHfMax] und [ruhepulsBpm].
  final HeartRateZoning zonen;

  /// Laufzeit je Zone, letzte [verteilungsTage] Tage — immer sechs
  /// Einträge (Zone 0 bis 5), auch leere ([ZoneDistribution.shares]).
  final List<ZoneShare> verteilung;

  /// Anteil der Laufzeit in Zone 1–2 (Ziel ≥ 80 %), `null` ohne gezählte
  /// Laufzeit.
  final double? anteilZone12;

  @override
  bool operator ==(Object other) =>
      other is AusdauerDaten &&
      listEquals(other.watchReihe, watchReihe) &&
      listEquals(other.eigeneReihe, eigeneReihe) &&
      other.watchAktuell == watchAktuell &&
      other.eigeneAktuell == eigeneAktuell &&
      other.trendDelta == trendDelta &&
      other.quelle == quelle &&
      other.einordnung == einordnung &&
      other.potenzialMinuten == potenzialMinuten &&
      other.realistischMinuten == realistischMinuten &&
      other.erholungJuengster == erholungJuengster &&
      other.erholungSchnitt30 == erholungSchnitt30 &&
      other.ruhepulsBpm == ruhepulsBpm &&
      other.ruhepulsQuelle == ruhepulsQuelle &&
      other.zonen == zonen &&
      listEquals(other.verteilung, verteilung) &&
      other.anteilZone12 == anteilZone12;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(watchReihe),
    Object.hashAll(eigeneReihe),
    watchAktuell,
    eigeneAktuell,
    trendDelta,
    quelle,
    einordnung,
    potenzialMinuten,
    realistischMinuten,
    erholungJuengster,
    erholungSchnitt30,
    ruhepulsBpm,
    ruhepulsQuelle,
    zonen,
    Object.hashAll(verteilung),
    anteilZone12,
  );
}

/// Rechnet den Ausdauer-Zustand aus Cache-Reihen, Läufen und Tageswerten —
/// reine Funktion, ohne Widget prüfbar.
///
/// [tageswerte] ist das Rechenfenster der Tageswerte (für Erholungspuls),
/// [laeufe] sind **alle** Workouts des Fensters (gefiltert wird hier),
/// [ruhepulsReihe] die Ruhepuls-Reihe aus dem Cache (für den Median).
AusdauerDaten ausdauerDatenAus({
  required List<MeasurementPoint> watchReihe,
  required List<kanal.WorkoutSample> laeufe,
  required List<kanal.DailyMetrics> tageswerte,
  required List<MeasurementPoint> ruhepulsReihe,
  required DateTime jetzt,
}) {
  final heute = BerlinCalendar.startOfDay(jetzt);

  // ── Eigene Schätzung: je Tag der späteste Lauf mit Distanz ────────────
  final laufende = [
    for (final lauf in laeufe)
      if (lauf.kind == kanal.WorkoutKind.running) lauf,
  ]..sort((a, b) => a.start.compareTo(b.start));

  final eigeneJeTag = <DateTime, double>{};
  double? eigeneAktuell;
  for (final lauf in laufende) {
    final km = lauf.km;
    if (km == null) continue;
    final schaetzung = VO2MaxEstimate.fromRun(km: km, minutes: lauf.minutes);
    if (schaetzung == null) continue;
    // Aufsteigend sortiert: Der späteste Lauf eines Tages gewinnt, und der
    // letzte insgesamt ist die aktuelle Schätzung.
    eigeneJeTag[BerlinCalendar.startOfDay(lauf.start)] = schaetzung;
    eigeneAktuell = schaetzung;
  }
  final eigeneTage = eigeneJeTag.keys.toList()..sort();
  final eigeneReihe = [
    for (final tag in eigeneTage)
      MeasurementPoint(date: tag, value: eigeneJeTag[tag]!),
  ];

  // ── Watch-Wert und Trend ──────────────────────────────────────────────
  final watchAktuell = watchReihe.isEmpty ? null : watchReihe.last.value;
  double? trendDelta;
  if (watchReihe.length > 1) {
    final juengster = watchReihe.last;
    final grenze = BerlinCalendar.addDays(
      BerlinCalendar.startOfDay(juengster.date),
      -trendTage,
    );
    MeasurementPoint? erster;
    for (final punkt in watchReihe) {
      if (punkt.date.isBefore(grenze)) continue;
      erster = punkt;
      break;
    }
    if (erster != null && erster.date != juengster.date) {
      trendDelta = juengster.value - erster.value;
    }
  }

  // ── Einordnung und Prognose: Watch vor eigener Schätzung ──────────────
  final vdot = watchAktuell ?? eigeneAktuell;
  final quelle = watchAktuell != null
      ? PrognoseQuelle.watch
      : (eigeneAktuell != null ? PrognoseQuelle.eigeneSchaetzung : null);
  final potenzial = vdot == null
      ? null
      : RacePrediction.halfMarathonMinutes(vdot: vdot);
  final realistisch = vdot == null
      ? null
      : RacePrediction.realisticMinutes(vdot: vdot);

  // ── Erholungspuls aus den Tageswerten ─────────────────────────────────
  // Nach Tagesschlüssel sortiert — der ISO-String vergleicht lexikografisch
  // richtig (`CLAUDE.md`).
  final tage = [...tageswerte]..sort((a, b) => a.tag.compareTo(b.tag));
  int? erholungJuengster;
  for (final tag in tage) {
    if (tag.recoveryHRDrop != null) erholungJuengster = tag.recoveryHRDrop;
  }
  final grenze30 = BerlinCalendar.dayKey(
    BerlinCalendar.addDays(heute, -(erholungsSchnittTage - 1)),
  );
  var summe = 0;
  var zaehler = 0;
  for (final tag in tage) {
    final wert = tag.recoveryHRDrop;
    if (wert == null || tag.tag.compareTo(grenze30) < 0) continue;
    summe += wert;
    zaehler += 1;
  }
  final erholungSchnitt = zaehler == 0 ? null : summe / zaehler;

  // ── Ruhepuls und Zonen ────────────────────────────────────────────────
  // Die Reihe kommt aufsteigend aus dem Cache; der Kern schneidet selbst
  // auf die letzten 30 Werte und fällt unter fünf auf die allgemeine
  // Annahme zurück. Manuell gibt es noch nicht — kein Einstellungs-Schirm.
  final (ruhepulsBpm, ruhepulsQuelle) = RestingHeartRate.value(
    manual: null,
    recent: [for (final punkt in ruhepulsReihe) punkt.value.round()],
  );
  final zonen = HeartRateZones.zoning(
    hrMax: ausdauerHfMax,
    hrRest: ruhepulsBpm,
  );

  // ── Verteilung: Läufe der letzten 30 Tage ─────────────────────────────
  final verteilungsGrenze = BerlinCalendar.addDays(
    heute,
    -(verteilungsTage - 1),
  );
  final verteilung = ZoneDistribution.shares(
    [
      for (final lauf in laufende)
        if (!lauf.start.isBefore(verteilungsGrenze))
          WorkoutSample(
            // Beide Enums tragen dieselben sieben Fälle — deckungsgleich
            // mit Swifts `WorkoutKind` (`zone_distribution.dart`).
            kind: WorkoutKind.values.byName(lauf.kind.name),
            minutes: lauf.minutes,
            avgHeartRate: lauf.avgHR,
          ),
    ],
    zoning: zonen,
  );

  return AusdauerDaten(
    watchReihe: watchReihe,
    eigeneReihe: eigeneReihe,
    watchAktuell: watchAktuell,
    eigeneAktuell: eigeneAktuell,
    trendDelta: trendDelta,
    quelle: quelle,
    einordnung: vdot == null ? null : VO2MaxRating.rating(vdot),
    potenzialMinuten: potenzial,
    realistischMinuten: realistisch,
    erholungJuengster: erholungJuengster,
    erholungSchnitt30: erholungSchnitt,
    ruhepulsBpm: ruhepulsBpm,
    ruhepulsQuelle: ruhepulsQuelle,
    zonen: zonen,
    verteilung: verteilung,
    anteilZone12: ZoneDistribution.easyShare(verteilung),
  );
}

/// Der Lade-Teil: besorgt Reihen, Läufe und Tageswerte und rechnet den
/// nackten Zustand. Den `Messwert` daraus macht [ausdauerProvider] — die
/// eine Stelle je Provider, an der `alsMesswert` steht (Hausregel 1).
/// Schnitt und Begründungen wie `_messungDetailLadenProvider`.
final _ausdauerLadenProvider = FutureProvider<AusdauerDaten>((ref) async {
  // Alle Abhängigkeiten vor dem ersten `await`: Was danach käme, wäre je
  // nach Reihenfolge der Läufe mal beobachtet und mal nicht.
  final cacheRepo = ref.watch(cacheRepositoryProvider);
  final fenster = ref.watch(dataWindowProvider);
  final quelle = ref.watch(healthProvider);
  final heute = ref.watch(heutigerTagProvider);
  final jetzt = ref.watch(clockProvider)();
  final tageswerte = await ref.watch(dailyMetricsProvider.future);

  // Dieselbe untere Kante wie beim Lauf, der den Cache gefüllt hat.
  final vonZeit = fenster.queryStart(floor: quelle.earliestPermittedDate);
  final von = BerlinCalendar.dayKey(vonZeit);
  final bis = BerlinCalendar.dayKey(heute);

  // Noch nie gelaufen heißt: noch kein Ergebnis. Eine aufgelöste Future
  // hieße „fertig", und der leere Cache stünde als „keine Werte" da —
  // Fehler `01`. Bleibt sie offen, meldet `alsMesswert` `NochNie`.
  if (tageswerte is NochNie<List<kanal.DailyMetrics>>) {
    return Completer<AusdauerDaten>().future;
  }

  final watchReihe = await cacheRepo.vo2maxReihe(von: von, bis: bis);
  final ruhepulsReihe = await cacheRepo.messReihe(
    MessArt.ruhepuls,
    von: von,
    bis: bis,
  );

  // Läufe kommen ohne Cache direkt vom Kanal — es gibt keine
  // Workout-Tabelle. Ein Scheitern nimmt der Watch-Hälfte nichts weg
  // (dieselbe Abwägung wie `try? await health.workouts` in
  // `EnduranceStore.swift:47`). **Nach einem gescheiterten
  // Tageswerte-Lauf wird gar nicht erst gefragt:** Der Kanal hat gerade
  // nicht geantwortet, und ein Schirm, der die eine Hälfte als Fehler und
  // die andere als frisch gelesen behandelte, zeigte eine Standzeile über
  // Werten, die der gescheiterte Lauf nie gesehen hat — der Fehlerfall
  // bleibt ein Fehlerfall (`ausdauer_view_test.dart`, „Gescheiterter
  // Lauf").
  var laeufe = const <kanal.WorkoutSample>[];
  if (tageswerte is! Fehlgeschlagen<List<kanal.DailyMetrics>>) {
    try {
      laeufe = await quelle.workouts(vonZeit, jetzt);
    } on Object {
      laeufe = const [];
    }
  }

  final daten = ausdauerDatenAus(
    watchReihe: watchReihe,
    laeufe: laeufe,
    tageswerte: tageswerte is Bekannt<List<kanal.DailyMetrics>>
        ? tageswerte.wert
        : const [],
    ruhepulsReihe: ruhepulsReihe,
    jetzt: jetzt,
  );

  // Gescheitert **und** nichts da: nur dann `Fehlgeschlagen` — ein
  // gescheiterter Nachlauf nimmt keinen sichtbaren Wert weg.
  if (tageswerte is Fehlgeschlagen<List<kanal.DailyMetrics>> &&
      daten.watchReihe.isEmpty &&
      daten.eigeneReihe.isEmpty) {
    throw tageswerte.fehler;
  }

  return daten;
});

/// Der **öffentliche** Provider, und der einzige, den die View liest: Sie
/// sieht `Messwert<AusdauerDaten>` und nie ein `AsyncValue`.
///
/// **Leer heißt: weder ein Watch-Wert noch ein Lauf mit Schätzung** — der
/// Leerzustand des Entwurfs („Noch kein Lauf und keine VO₂max"). Zonen
/// und Ruhepuls hängen nicht daran: Ohne Ausdauerdaten zeigt der Schirm
/// die leere Form, nicht eine halbe.
final ausdauerProvider = Provider<Messwert<AusdauerDaten>>((ref) {
  final jetzt = ref.watch(clockProvider)();
  final geladen = ref.watch(_ausdauerLadenProvider);
  final zustand = geladen.value;

  final hatWerte =
      zustand != null &&
      (zustand.watchReihe.isNotEmpty || zustand.eigeneReihe.isNotEmpty);

  return alsMesswert<AusdauerDaten>(
    geladen,
    cache: hatWerte ? (wert: zustand, stand: jetzt) : null,
    jetzt: jetzt,
    istLeer: !hatWerte,
  );
});
