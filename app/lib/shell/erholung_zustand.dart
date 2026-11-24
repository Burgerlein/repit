// Der Zustand des Erholung-Schirms (#115) — alles, was der Schirm zeigt,
// einmal gerechnet und ohne Widget prüfbar. Die Oberfläche liegt in
// `erholung_view.dart`.
//
// API und Vertrag sind durch `app/test/shell/erholung_zustand_test.dart`
// verbindlich vorgegeben (siehe dessen Dateikopf für die vollständige
// Begründung des Schnitts) — diese Datei darf die Tests ausführen, aber
// nicht verändern (`CLAUDE.md`, „Wer Tests schreibt, schreibt nicht die
// Implementierung").
//
// **Warum `Messwert` nur um die Health-Hälfte liegt:** `Ziele` sind Tims
// eigene Daten; für sie gibt es keinen Lauf, der leer ausgehen kann
// (`CLAUDE.md`). Sie stehen deshalb unverpackt neben
// `Messwert<ErholungDaten>` — und genau deshalb darf der Schirm
// Datumszeile, Tipps und Fußnote auch dann zeigen, wenn Apple Health noch
// nichts geliefert hat.
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../core/messwert.dart';
import '../data/schlaf_eintrag.dart';
import '../data/ziele.dart';
import '../design/palette.dart';
import '../design/vital_ton.dart';
import '../health/health_provider.dart';
import '../health/health_types.dart';
import 'schlaf_von_hand.dart';

/// Der Ton einer Verlaufszeile.
///
/// **Entschieden wird in [vitalTon]**, nicht hier (#308, Tim am
/// 04.11.2026: „Dann extrahier die Funktion, dass beide Seiten dieselbe
/// nutzen und wir keinen doppelten Code haben."). Bis dahin stand die
/// Zuordnung Wert → Stufe in dieser Datei und eine zweite, gröbere in
/// `heute_view.dart`; derselbe Schlafwert stand deshalb auf einem Schirm
/// grün und auf dem anderen gelb.
///
/// Geblieben ist die Übersetzung der **Zeilenart** in die Metrik der
/// Ampel. Sie gehört hierher: `RecoveryTrendKind` ist das Vokabular dieses
/// Schirms, `RecoveryMetric` das der Ampel, und die Alkohol-Zeile hat
/// keine Metrik — die Zeile stellt einen Zusammenhang her, sie bewertet
/// nicht (#125). Eine Ampel über ihr wäre eine Diagnose.
VitalTon verlaufsTon({
  required RecoveryTrendKind art,
  required RecoveryReading messwerte,
  required RecoveryBaseline baseline,
  required RecoveryEvaluation? bewertung,
}) {
  final metrik = switch (art) {
    RecoveryTrendKind.sleep => RecoveryMetric.sleep,
    RecoveryTrendKind.hrv => RecoveryMetric.hrv,
    RecoveryTrendKind.restingHeartRate => RecoveryMetric.restingHeartRate,
    RecoveryTrendKind.respiratoryRate => RecoveryMetric.respiratoryRate,
    RecoveryTrendKind.alcoholDays => null,
  };
  if (metrik == null) return VitalTon.unbeurteilt;

  return vitalTon(
    metrik: metrik,
    messwerte: messwerte,
    baseline: baseline,
    bewertung: bewertung,
  );
}

/// Die Health-Hälfte des Schirms, einmal gerechnet.
///
/// Trägt die Nacht **zusätzlich** zum Schnappschuss: `RecoverySnapshot
/// .night` ist ein `RecoveryNight` und kennt keine Abschnitte; das
/// Hypnogramm braucht aber die `SleepSession`, und die Tagschlaf-Kachel
/// braucht `SleepNight.naps`. Beides aus dem Kern herauszureichen hieße,
/// `SleepSegment` nach `trainings_core` zu ziehen — die Rechnung braucht es
/// nicht, das Bild schon.
@immutable
class ErholungDaten {
  const ErholungDaten({
    required this.schnappschuss,
    required this.nacht,
    required this.wochenminuten,
    this.napEintraege = const [],
  });

  final RecoverySnapshot schnappschuss;

  /// Die Nacht von **heute**, mit ihren Abschnitten und ihrem Tagschlaf.
  /// `null`, wenn für heute keine Nacht vorliegt.
  final SleepNight? nacht;

  /// Der von Hand eingetragene Tagschlaf von heute (#209) —
  /// **zusätzlich** zu `nacht.naps`, nicht statt ihrer.
  ///
  /// Ein Nickerchen gibt es je Tag mehrfach; ein eingetragenes ersetzt
  /// deshalb keines, es kommt dazu (dieselbe Regel wie auf dem
  /// Schlaf-Schirm, `schlaf_von_hand.dart`).
  ///
  /// **Nicht als `SleepSession` eingereiht.** Ein Eintrag trägt eine
  /// Uhrzeit und eine Schlafdauer, die auseinanderfallen dürfen („falls du
  /// wach dazwischen lagst"), und in der Fassung „nur Dauer" gar kein
  /// Fenster. Daraus Abschnitte zu bauen hieße, ein Hypnogramm zu
  /// erfinden, das es nie gab — dieselbe Entscheidung, die eine von Hand
  /// eingetragene Nacht ohne Abschnitte stehen lässt.
  ///
  /// **Steht auch dann, wenn [nacht] `null` ist:** Ein Nickerchen braucht
  /// keine Nacht.
  final List<SchlafEintrag> napEintraege;

  /// `null` heißt „diese Woche ist nichts aufgezeichnet", `0` heißt „diese
  /// Woche nichts trainiert". `TrainingLoad.weekMinutes` liefert für beides
  /// `0.0`; die Unterscheidung braucht die Tagesliste, also fällt sie hier
  /// und nicht in der View.
  final double? wochenminuten;
}

/// Alles, was der Schirm zeigt.
@immutable
class ErholungZustand {
  const ErholungZustand({required this.daten, required this.ziele});

  final Messwert<ErholungDaten> daten;

  /// Tims eigene Ziele — nie ein Leerzustand, nie eine Konstante im
  /// Quelltext des Schirms.
  final Ziele ziele;
}

/// Ein Tageswert aus Apple Health **plus die Werte seiner Nacht** als
/// Eingabe der Kernrechnung.
///
/// **Ruhepuls, HRV und Atemfrequenz kommen aus [nachtwerte]** (#193,
/// Stufe 4), nicht mehr aus `tag`: Apples `RestingHeartRate` ist ein
/// Tageswert, der im Lauf des Tages mitwächst, und HRV wie Atemfrequenz
/// hat die App über den ganzen Kalendertag gemittelt. `DailyMetrics` trägt
/// die drei Felder weiterhin — die App bekommt sie vom Kanal und darf sie
/// nur nicht mehr als „die Nacht" ausgeben.
///
/// **`exerciseMinutes` bleibt Tageswert: Training ist keine Nacht.**
///
/// **Kein Rückfall auf den Tageswert.** Fehlt der Nachtwert, bleibt das
/// Feld `null` — Tims Entscheidung vom 02.11.2026, getragen von einer
/// Messung seines Health-Exports (in den letzten 90 Tagen reichten die
/// Proben in 7 von 7 Nächten). Apples Tageswert einzusetzen, auch
/// gekennzeichnet, wäre Fehler `01` in neuer Verpackung: eine Zahl, die
/// eine Messung behauptet, die es für diese Nacht nicht gibt.
///
/// Ein fehlendes Feld bleibt `null` und wird nie zu `0` — eine Lücke ist
/// keine gemessene Null. Die drei Felder fehlen **einzeln**: Zu wenige
/// Pulsproben nehmen HRV und Atemfrequenz nicht mit.
RecoveryDay alsRecoveryDay(DailyMetrics tag, {NightVitals? nachtwerte}) =>
    RecoveryDay(
      date: datumAusTag(tag.tag),
      restingHeartRate: nachtwerte?.restingHeartRate,
      hrv: nachtwerte?.hrv,
      respiratoryRate: nachtwerte?.respiratoryRate,
      exerciseMinutes: tag.exerciseMinutes,
    );

/// Eine Nacht aus Apple Health als Eingabe der Kernrechnung.
///
/// **Schlafminuten zählen jeden Abschnitt außer `awake`**, auch
/// `unspecified`: Ältere Uhren und das iPhone melden Schlaf ohne
/// Phasenangabe, und den als „nicht geschlafen" zu lesen wäre falsch.
///
/// **Wachliegen am Rand ist keine Unterbrechung.** Nur die wachen
/// Abschnitte *zwischen* dem ersten und dem letzten Schlafabschnitt zählen;
/// die halbe Stunde vor dem Einschlafen und das Dösen nach dem Aufwachen
/// sind keine Weckvorgänge.
RecoveryNight alsRecoveryNacht(SleepNight nacht) {
  // `SleepSession` sortiert seine Abschnitte beim Bauen nach `start`.
  final abschnitte = nacht.session.segments;
  bool schlaeft(SleepSegment a) => a.stage != SleepStage.awake;

  var erster = -1, letzter = -1;
  for (var i = 0; i < abschnitte.length; i++) {
    if (!schlaeft(abschnitte[i])) continue;
    if (erster < 0) erster = i;
    letzter = i;
  }

  var schlafMinuten = 0.0;
  var wachMinuten = 0.0;
  var wachPhasen = 0;
  for (var i = 0; i < abschnitte.length; i++) {
    final a = abschnitte[i];
    final minuten =
        a.end.difference(a.start).inMicroseconds /
        Duration.microsecondsPerMinute;
    if (schlaeft(a)) {
      schlafMinuten += minuten;
      continue;
    }
    if (i > erster && i < letzter) {
      wachMinuten += minuten;
      wachPhasen += 1;
    }
  }

  return RecoveryNight(
    date: nacht.date,
    asleepMinutes: schlafMinuten,
    bedtime: erster < 0 ? null : abschnitte[erster].start,
    awakeMinutes: wachMinuten,
    wakeCount: wachPhasen,
  );
}

/// Rechnet die beiden Health-Hälften und Tims eigene Daten zu einem Zustand.
///
/// **Die Tabelle, auf der `docs/todo/01` lebt**, liegt in [_verbinde]:
/// solange eine Hälfte noch unterwegs ist, steht nirgends ein „keine
/// Daten"-Grund.
///
/// **Die Nachtwerte sind keine dritte Hälfte** (#193, Stufe 4). Ob es
/// etwas zu zeigen gibt, entscheiden Tageswerte und Nächte („Eine Hälfte
/// reicht"); der Schirm steht auch ohne sie — Schlaf, Score, Training,
/// Alkohol und die Datumszeile hängen nicht an ihnen. Sie tun genau zwei
/// Dinge: Sie füllen Ruhepuls, HRV und Atemfrequenz, und sie machen
/// `laeuft` wahr, solange sie unterwegs sind (ihr Stand zählt beim „der
/// frühere gewinnt" mit).
///
/// Andersherum wäre aus jedem `LeerNachLauf` der beiden bestehenden
/// Hälften ein Ladezustand geworden — und damit hätte sich jede bestehende
/// Zusicherung über die vier `Messwert`-Zustände von Erholungs-, Verlauf-
/// und Belastungsschirm stillschweigend geändert.
///
/// [nachtwerte] ist benannt und hat einen Vorgabewert, damit bestehende
/// Aufrufer übersetzt bleiben. Der Vorgabewert `NochNie` heißt „noch nicht
/// nachgesehen", **nicht** „nimm die Tageswerte".
///
/// [eintraege] sind Tims eigene Schlafeinträge (#209) und tragen aus
/// demselben Grund **keinen `Messwert`** wie im `schlafProvider`: Hinter
/// ihnen steht kein Lauf, der leer ausgehen könnte — leer heißt leer
/// (`CLAUDE.md`, Spec 5.6a). Auch sie haben einen Vorgabewert, damit
/// bestehende Aufrufer übersetzt bleiben; die leere Liste heißt hier
/// „keine Einträge" und nicht „noch nicht nachgesehen".
ErholungZustand erholungZustandAus({
  required Messwert<List<DailyMetrics>> tageswerte,
  required Messwert<List<SleepNight>> naechte,
  Messwert<Map<String, NightVitals>> nachtwerte =
      const NochNie<Map<String, NightVitals>>(),
  required Ziele ziele,
  required DataWindow fenster,
  required DateTime jetzt,
  List<SchlafEintrag> eintraege = const [],
}) {
  return ErholungZustand(
    daten: _verbinde(
      tageswerte: tageswerte,
      naechte: naechte,
      nachtwerte: nachtwerte,
      ziele: ziele,
      fenster: fenster,
      jetzt: jetzt,
      eintraege: eintraege,
    ),
    ziele: ziele,
  );
}

Messwert<ErholungDaten> _verbinde({
  required Messwert<List<DailyMetrics>> tageswerte,
  required Messwert<List<SleepNight>> naechte,
  required Messwert<Map<String, NightVitals>> nachtwerte,
  required Ziele ziele,
  required DataWindow fenster,
  required DateTime jetzt,
  required List<SchlafEintrag> eintraege,
}) {
  final tage = tageswerte is Bekannt<List<DailyMetrics>>
      ? tageswerte.wert
      : const <DailyMetrics>[];
  final naechteListe = naechte is Bekannt<List<SleepNight>>
      ? naechte.wert
      : const <SleepNight>[];
  // Kein Eintrag heißt „für diese Nacht keine drei Werte" — nicht „nimm
  // Apples Tageswert". Leer ist leer.
  final nachtkarte = nachtwerte is Bekannt<Map<String, NightVitals>>
      ? nachtwerte.wert
      : const <String, NightVitals>{};

  // Eine Hälfte reicht: Wer Tageswerte hat, aber noch keine Nächte, sieht
  // die Ringe — nicht einen Leerstand, bis beides da ist. **Die
  // Nachtwerte stehen bewusst nicht in dieser Bedingung:** Sie füllen drei
  // Felder, sie entscheiden nicht, ob der Schirm etwas zu zeigen hat.
  if (tageswerte is Bekannt<List<DailyMetrics>> ||
      naechte is Bekannt<List<SleepNight>>) {
    final staende = <DateTime>[
      if (tageswerte is Bekannt<List<DailyMetrics>>) tageswerte.stand,
      if (naechte is Bekannt<List<SleepNight>>) naechte.stand,
      // Der Stand der Nachtwerte zählt mit, sobald es einen gibt: Drei der
      // vier Spalten stammen von ihnen, und eine Standzeile darf nicht
      // neuer behaupten, als die Werte darunter sind.
      if (nachtwerte is Bekannt<Map<String, NightVitals>>) nachtwerte.stand,
    ];
    // Der **frühere** Stand gewinnt: „Stand 14:32" darf nicht neuer
    // behaupten, als die ältere Hälfte ist.
    final stand = staende.reduce((a, b) => a.isBefore(b) ? a : b);

    final laeuft =
        (tageswerte is Bekannt<List<DailyMetrics>> && tageswerte.laeuft) ||
        (naechte is Bekannt<List<SleepNight>> && naechte.laeuft) ||
        (nachtwerte is Bekannt<Map<String, NightVitals>> &&
            nachtwerte.laeuft) ||
        tageswerte is NochNie<List<DailyMetrics>> ||
        naechte is NochNie<List<SleepNight>> ||
        nachtwerte is NochNie<Map<String, NightVitals>>;

    return Bekannt<ErholungDaten>(
      _daten(
        tage: tage,
        naechte: naechteListe,
        nachtwerte: nachtkarte,
        ziele: ziele,
        fenster: fenster,
        jetzt: jetzt,
        eintraege: eintraege,
      ),
      stand: stand,
      laeuft: laeuft,
    );
  }

  // Solange irgendetwas läuft, steht kein „keine Daten"-Grund. **Hier
  // zählen nur die beiden Hälften**, nicht die Nachtwerte: Sind Tageswerte
  // und Nächte leer nach Lauf, bleibt es dabei, auch wenn die Nachtwerte
  // nie gelaufen sind. Sonst wäre aus „gelaufen, nichts gefunden" ein
  // Ladezustand geworden.
  if (tageswerte is NochNie<List<DailyMetrics>> ||
      naechte is NochNie<List<SleepNight>>) {
    return const NochNie<ErholungDaten>();
  }

  // Ein Fehler ist keine Aussage über die Datenlage — er gewinnt deshalb
  // gegen „leer".
  if (tageswerte is Fehlgeschlagen<List<DailyMetrics>>) {
    return Fehlgeschlagen<ErholungDaten>(
      fehler: tageswerte.fehler,
      gelaufen: tageswerte.gelaufen,
    );
  }
  if (naechte is Fehlgeschlagen<List<SleepNight>>) {
    return Fehlgeschlagen<ErholungDaten>(
      fehler: naechte.fehler,
      gelaufen: naechte.gelaufen,
    );
  }

  // Beide leer nach Lauf: der **spätere** Zeitpunkt, denn so lange ist
  // tatsächlich nichts angekommen.
  final a = (tageswerte as LeerNachLauf<List<DailyMetrics>>).gelaufen;
  final b = (naechte as LeerNachLauf<List<SleepNight>>).gelaufen;
  return LeerNachLauf<ErholungDaten>(gelaufen: a.isAfter(b) ? a : b);
}

ErholungDaten _daten({
  required List<DailyMetrics> tage,
  required List<SleepNight> naechte,
  required Map<String, NightVitals> nachtwerte,
  required Ziele ziele,
  required DataWindow fenster,
  required DateTime jetzt,
  required List<SchlafEintrag> eintraege,
}) {
  final schnappschuss = RecoverySnapshot.make(
    // Nachgeschlagen wird unter dem **ISO-Tagesschlüssel** — demselben
    // String, den `DailyMetrics.tag` und `Naechte.tag` tragen. Ein Tag ist
    // eine Kalenderangabe, kein Zeitpunkt (`CLAUDE.md`).
    //
    // **Wert und Median wechseln gemeinsam:** `RecoverySnapshot.make`
    // rechnet seine `baseline` aus genau dieser `days`-Liste. Ein
    // Nachtwert gegen einen Tagesmedian ergäbe zwei plausible Zahlen und
    // eine falsche Ampel — deshalb gibt es hier nur diese eine Quelle.
    days: [
      for (final tag in tage)
        alsRecoveryDay(tag, nachtwerte: nachtwerte[tag.tag]),
    ],
    nights: [for (final nacht in naechte) alsRecoveryNacht(nacht)],
    today: jetzt,
    sleepGoalHours: ziele.schlafzielMinuten / Duration.minutesPerHour,
    // Die Ablage hält das Schlafenszeitziel als Minuten **nach
    // Mitternacht**; der Score rechnet auf der 18-Uhr-Skala. Diese eine
    // Zeile ist die Umrechnung — wird sie vergessen, liegt das Ziel immer
    // nach jeder Einschlafzeit und die Teilnote ist konstant voll.
    bedtimeGoalMinutes: EveningClock.minutesSinceEveningOfClock(
      hour: ziele.schlafenszeitMinuten ~/ Duration.minutesPerHour,
      minute: ziele.schlafenszeitMinuten % Duration.minutesPerHour,
    ),
    window: fenster,
    // Alkohol-Tage (#125): Die Regel „mehr als nichts" steht im Kern, die
    // Zuordnung Tageswert → Eintrag hier. `alcoholicDrinks` bleibt `null`,
    // wenn Apple Health für den Tag nichts hergibt — `AlcoholDays.from`
    // lässt einen solchen Tag heraus, ohne ihn zu einem Tag ohne Alkohol zu
    // erklären.
    alcoholDays: AlcoholDays.from([
      for (final tag in tage)
        (date: datumAusTag(tag.tag), drinks: tag.alcoholicDrinks),
    ]),
    // Die gemessenen Nullen (#268) — das belegte „nein" für den Vortag.
    // Ohne diese zweite Liste gäbe es nur „ja" und „kein Wert", und ein
    // „nein" wäre entweder erfunden oder unausdrückbar.
    alcoholFreeDays: AlcoholDays.measuredZero([
      for (final tag in tage)
        (date: datumAusTag(tag.tag), drinks: tag.alcoholicDrinks),
    ]),
    // `isPostOperative` bleibt beim Vorgabewert `false`: Es gibt noch keine
    // Ereignis-Objekte (#41), und der Schirm darf den Fall nicht erfinden
    // (Spec Abschnitt 9: kein Ereignisdatum im Quelltext).
  );

  final heute = BerlinCalendar.startOfDay(jetzt);
  SleepNight? nacht;
  for (final kandidat in naechte) {
    if (kandidat.date == heute) nacht = kandidat;
  }

  final (wocheVon, wocheBis) = TrainingLoad.weekBounds(
    containing: schnappschuss.today,
  );
  final gemessen = schnappschuss.days.any(
    (tag) =>
        !tag.date.isBefore(wocheVon) &&
        tag.date.isBefore(wocheBis) &&
        tag.exerciseMinutes != null,
  );

  return ErholungDaten(
    schnappschuss: schnappschuss,
    nacht: nacht,
    wochenminuten: gemessen ? schnappschuss.weekMinutes : null,
    // **Dieselbe Zuordnung wie auf dem Schlaf-Schirm** (#209):
    // `tagschlafEintraegeZu` ist die eine Stelle, die entscheidet, welche
    // Einträge zu einem Tag gehören und in welcher Reihenfolge sie stehen.
    // Zwei Stellen wären zwei Wahrheiten über dieselbe Tabelle.
    napEintraege: tagschlafEintraegeZu(heute, eintraege),
  );
}

/// Der Zustand des Erholung-Schirms, **gehalten** statt bei jedem Zugriff
/// gerechnet (Hausregel 2, `docs/todo/03`).
///
/// Der Schirm besorgt seine Daten selbst: Jeder Schirm ist aus jedem Tab
/// erreichbar, niemand darf sich darauf verlassen, dass vorher eine
/// Übersicht geladen hat.
///
/// `AsyncValue` endet hier und taucht in der Widget-Schicht nicht auf —
/// dasselbe reine Durchreichen wie `heuteZustandAusProvider` in
/// `heute_view.dart`, mit `NochNie`-Rückfall, solange ein Provider noch
/// kein Ergebnis hat.
final erholungProvider = Provider<ErholungZustand>((ref) {
  final tageswerte =
      ref.watch(dailyMetricsProvider).value ??
      const NochNie<List<DailyMetrics>>();
  final naechte =
      ref.watch(sleepProvider).value ?? const NochNie<List<SleepNight>>();
  // Puls, HRV und Atemfrequenz je Nacht (#193). Derselbe `NochNie`-Rückfall
  // wie bei den beiden Hälften: Hat der Provider noch kein Ergebnis, ist
  // „noch nicht nachgesehen" die Antwort — nicht „nichts da".
  final nachtwerte =
      ref.watch(nachtWerteProvider).value ??
      const NochNie<Map<String, NightVitals>>();
  return erholungZustandAus(
    tageswerte: tageswerte,
    naechte: naechte,
    nachtwerte: nachtwerte,
    ziele: zieleAusProvider(ref.watch(zieleProvider)).ziele,
    fenster: ref.watch(rechenfensterProvider),
    jetzt: ref.watch(clockProvider)(),
    // **Kein `Messwert`.** Tims eigene Eingabe kennt keinen Lauf, der leer
    // ausgehen könnte — dasselbe `?? const []` wie im `schlafProvider`:
    // Solange gelesen wird, gibt es noch keine Einträge, und die
    // gemessenen Nächte stehen trotzdem schon da.
    eintraege: ref.watch(schlafEintraegeProvider).value ?? const [],
  );
});

/// Der Hinweiskasten (Abschnitt 3) als Wert, nicht als Widget.
@immutable
class ErholungHinweis {
  const ErholungHinweis({
    required this.signale,
    required this.absaetze,
    required this.kante,
    required this.zeigtHealthEinstellungen,
  });

  /// Je ein benanntes Warnsignal, in der Vertragsreihenfolge von
  /// [RecoveryMetric] — unabhängig davon, in welcher Reihenfolge der
  /// Aufrufer sie übergibt.
  final List<String> signale;

  /// Der Rat darunter, Absatz für Absatz.
  final List<String> absaetze;

  /// Die farbige Kante der Karte.
  final CupertinoDynamicColor kante;

  /// Nur bei `noData`: Apple verrät den Lesestatus nicht, also ist der Weg
  /// in die Health-Einstellungen der einzige, den der Nutzer gehen kann.
  final bool zeigtHealthEinstellungen;
}

/// Der Hinweiskasten zum Verdikt — `null` bei `calm`, dann fällt er ganz
/// weg und die Ringe bleiben stehen.
///
/// Reine Funktion, kein Widget: Die Regeln (fällt bei `calm` weg; nennt bei
/// fehlenden Daten beide Möglichkeiten; Knopf nur bei `noData`; Kantenfarbe
/// je Verdikt) sind Entscheidungen, keine Darstellung — und als Funktion
/// auch für `postOperative` prüfbar, einen Zustand, den der Schirm heute gar
/// nicht erzeugen *kann*.
ErholungHinweis? erholungHinweis({
  required RecoveryEvaluation bewertung,
  required RecoveryReading messwerte,
  required RecoveryBaseline baseline,
}) {
  switch (bewertung.verdict) {
    case RecoveryVerdict.calm:
      return null;

    case RecoveryVerdict.noData:
      return const ErholungHinweis(
        signale: [],
        absaetze: [_ohneWerte],
        kante: Palette.rest,
        zeigtHealthEinstellungen: true,
      );

    case RecoveryVerdict.postOperative:
      return const ErholungHinweis(
        signale: [],
        absaetze: [_nachOp],
        kante: Palette.warn,
        zeigtHealthEinstellungen: false,
      );

    case RecoveryVerdict.watch:
    case RecoveryVerdict.stressed:
      final signale = <String>[
        for (final metrik in RecoveryMetric.values)
          if (bewertung.signals.contains(metrik))
            _signalText(metrik, messwerte, baseline),
      ];
      return ErholungHinweis(
        signale: signale,
        // Nur der Rat, kein Anhang über eine bevorstehende OP: Der Satz
        // „Kommen Fieber oder Halsschmerzen dazu: vor der OP die Klinik
        // anrufen" stand hier bis zum 27.10.2026 **in jedem** Fall mit
        // Warnsignal — und setzte damit fest voraus, dass eine OP ansteht.
        // Das ist genau die Art Behauptung, die `CLAUDE.md` verbietet
        // („Kein Datum eines Ereignisses steht je im Quelltext", und eine
        // festverdrahtete Zusage über ein Ereignis ist nichts Besseres als
        // sein Datum). Tims Entscheidung: Wenn so ein Hinweis kommt, dann
        // vom KI-Coach, der die tatsächlichen Ereignisse kennt — nicht aus
        // einem festen Satz.
        //
        // Der Hinweis zur ärztlichen Freigabe bleibt dort, wo er hingehört:
        // im Zustand `postOperative`, der nur greift, wenn wirklich eine
        // OP-Erholung läuft.
        absaetze: [signale.length == 1 ? _ratEinSignal : _ratMehrereSignale],
        kante: Palette.bib,
        zeigtHealthEinstellungen: false,
      );
  }
}

/// **„freigegeben", nicht „freigeben":** Beide Möglichkeiten müssen als
/// Zustand dastehen, nicht als Aufforderung — der Satz erklärt die Lücke,
/// bevor er zum Handeln auffordert.
const _ohneWerte =
    'Zwei Erklärungen, beide möglich: Entweder hat die Uhr nichts '
    'aufgezeichnet — oder der Lesezugriff auf Schlaf, HRV, Ruhepuls und '
    'Atemfrequenz ist nicht freigegeben. Apple verrät nicht, welches von '
    'beidem zutrifft. Also beides prüfen: Uhr nachts tragen, Lesezugriff in '
    'den Health-Einstellungen freigeben.';

const _nachOp =
    'Jetzt zählt nur Ruhe. Niedrige HRV und höherer Ruhepuls sind nach '
    'einer OP erwartbar, der Körper heilt. Deshalb bewertet die App die '
    'Werte bis zur ärztlichen Freigabe nicht. Bei Blut im Mund oder Fieber '
    'die Klinik anrufen, im Notfall 112.';

const _ratEinSignal =
    'Normales Training ist in Ordnung, geh heute früher ins Bett.';

const _ratMehrereSignale =
    'Heute locker trainieren oder pausieren, viel trinken, früh ins Bett.';

/// Benennt ein Warnsignal — **mit** seiner Zahl, wenn Wert und Median
/// vorliegen, sonst ohne. Eine erfundene Zahl wäre schlimmer als gar keine.
String _signalText(
  RecoveryMetric metrik,
  RecoveryReading messwerte,
  RecoveryBaseline baseline,
) {
  switch (metrik) {
    case RecoveryMetric.sleep:
      // Die Schwelle steht als Konstante in `trainings_core` und wird von
      // hier aus beschriftet — in Swift stand sie dreifach im Quelltext.
      final stunden = RecoveryTrafficLight.minimumSleepHours;
      return 'Schlaf unter ${_zahl(stunden)} Stunden';

    case RecoveryMetric.restingHeartRate:
      final wert = messwerte.restingHeartRate;
      final median = baseline.restingHeartRate;
      if (wert == null || median == null) {
        return 'Ruhepuls über deinem Median';
      }
      return 'Ruhepuls ${_zahl(wert - median)} bpm über deinem Median';

    case RecoveryMetric.hrv:
      final wert = messwerte.hrv;
      final median = baseline.hrv;
      if (wert == null || median == null || median == 0) {
        return 'HRV unter deinem Median';
      }
      return 'HRV ${_zahl((1 - wert / median) * 100)} % unter deinem Median';

    case RecoveryMetric.respiratoryRate:
      final wert = messwerte.respiratoryRate;
      final median = baseline.respiratoryRate;
      if (wert == null || median == null) {
        return 'Atemfrequenz über deinem Median';
      }
      return 'Atemfrequenz ${_zahl(wert - median)} über deinem Median';
  }
}

/// Ganze Zahlen ohne Nachkommastelle, sonst eine — mit Komma, nicht mit
/// Punkt.
String _zahl(double wert) {
  final gerundet = (wert * 10).round() / 10;
  if (gerundet == gerundet.roundToDouble()) return gerundet.round().toString();
  return gerundet.toStringAsFixed(1).replaceAll('.', ',');
}
