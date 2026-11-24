// Der Zustand des Schlaf-Schirms und des Tagschlaf-Schirms (#92) — alles,
// was beide zeigen, einmal gerechnet und ohne Widget prüfbar. Die
// Oberflächen liegen in `schlaf_view.dart`/`schlaf_abschnitte.dart` und
// `tagschlaf_view.dart`.
//
// API und Vertrag sind durch `app/test/shell/schlaf_zustand_test.dart`
// verbindlich vorgegeben (siehe dessen Dateikopf für die vollständige
// Begründung des Schnitts) — diese Datei darf die Tests ausführen, aber
// nicht verändern (`CLAUDE.md`, „Wer Tests schreibt, schreibt nicht die
// Implementierung").
//
// **Diese Datei ist seit #158 zugleich die Tür zu sechs anderen**
// (29.10.2026, 1002 Zeilen waren es vorher). Sie trägt selbst nur noch die
// gezeigte Nacht, den Zustand des ganzen Schirms und den Provider, der ihn
// hält; der Rest liegt daneben und wird von hier weiterexportiert:
//
// - `schlaf_minuten.dart` — Schlafminuten, Fenster und Wanduhrzeit einer
//   Nacht; von allen anderen gebraucht und deshalb zuunterst.
// - `schlaf_auswahl.dart` — welche Nacht gezeigt wird, ihre Nachbarn, das
//   Blättern und der Ansichtszustand dazu.
// - `schlaf_reihe.dart` — was die ganze Reihe sagt: Zeitfolge,
//   Statistiken, Verlaufswerte, Nachtlagen.
// - `schlaf_score.dart` — die drei Teilnoten, ihre Farben und der Ring.
// - `schlaf_vitalwerte.dart` — Puls- und Atemspannen samt Bezugswerten.
// - `schlaf_tagschlaf.dart` — der Zustand des Tagschlaf-Schirms.
//
// **Die festgelegte API ist `import '…/shell/schlaf_zustand.dart'`.** Die
// Schirme und die Widget-Tests holen von hier alles, so wie
// `schlaf_abschnitte.dart` es seit #153 für ihre vier vormacht; der
// Schnitt bleibt deshalb innen, keine fremde Importzeile und keine
// Testdatei wurde angefasst. Tim hat „aufteilen" verlangt; **wo der
// Schnitt liegt, hat der umsetzende Agent entschieden** — geschnitten
// entlang dessen, was zusammen stimmen muss.
//
// **Was hier bewusst nicht entsteht:**
//
// - **Das Verlaufsdiagramm.** `DiagrammStufe` und `diagrammPunkte` liegen
//   in `lib/shell/diagramm_zeitraum.dart` (#94), das Diagramm-Bauteil
//   selbst in #130. Diese Datei liefert nur die Tageswerte
//   ([schlafTagewerte]) — zwei Rechnungen für dieselbe Verdichtung wären
//   zwei Wahrheiten über dasselbe Diagramm.
// - **„Nacht von Hand eintragen".** ENTWURF vom 26.10.2026
//   (`docs/screens/screens/schlaf.js:20–37`), steht nicht in `docs/SPEC.md`
//   und ist seit Tims Entscheidung vom 27.10.2026 ein eigenes Ticket
//   (#131). [SchlafTeilnote] **kann** „Unterbrechungen entfällt"
//   ausdrücken; erzeugt wird der Fall nirgends.
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../core/messwert.dart';
import '../data/schlaf_eintrag.dart';
import '../data/ziele.dart';
import '../health/health_provider.dart';
import '../health/health_types.dart';
import 'erholung_zustand.dart' show alsRecoveryNacht;
import 'schlaf_texte.dart';
import 'schlaf_von_hand.dart';
import 'schlaf_auswahl.dart';
import 'schlaf_minuten.dart';
import 'schlaf_reihe.dart';
import 'schlaf_score.dart';

export 'schlaf_auswahl.dart';
export 'schlaf_von_hand.dart';
export 'schlaf_minuten.dart';
export 'schlaf_reihe.dart';
export 'schlaf_score.dart';
export 'schlaf_tagschlaf.dart';
export 'schlaf_vitalwerte.dart';

/// Die Nacht, die oben in der Karte steht.
@immutable
class SchlafNacht {
  const SchlafNacht({
    required this.nacht,
    required this.kern,
    required this.score,
    required this.teilnoten,
    required this.von,
    required this.bis,
    required this.naps,
    this.vonHand,
    this.ergaenzung,
    this.napEintraege = const [],
  });

  /// Der Eintrag, wenn diese Nacht **von Hand** eingetragen ist und die
  /// gemessene damit **ersetzt** (#131); `null` sonst.
  ///
  /// Ist er gesetzt, trägt [nacht] keine Abschnitte: Oben steht dann die
  /// eingetragene Nacht, und zwar ganz (`schlaf_von_hand.dart`).
  final SchlafEintrag? vonHand;

  /// Der Eintrag, wenn er zur gemessenen Nacht **dazukommt** (#192);
  /// `null` sonst. Nie zugleich mit [vonHand] gesetzt — ein Eintrag
  /// ersetzt oder er ergänzt, beides gibt es nicht.
  ///
  /// Ist er gesetzt, trägt [nacht] ihre gemessenen Abschnitte weiter: Es
  /// sind zwei Strecken desselben Tages, nicht zwei Aussagen über
  /// dieselbe. [kern] legt beide zusammen, [von]/[bis] bleiben das
  /// gemessene Fenster.
  final SchlafEintrag? ergaenzung;

  /// Die eingetragenen Nickerchen desselben Tages — **zusätzlich** zu
  /// [naps], nicht statt ihrer.
  final List<SchlafEintrag> napEintraege;

  /// „23:10–06:15". Bei einer ersetzten Nacht aus den getippten
  /// Uhrzeiten, sonst aus dem gemessenen Fenster; „—", wenn es keines
  /// gibt. Die **eine** Stelle, an der diese Wahl getroffen wird — zwei
  /// Stellen des Schirms zeigen dasselbe Fenster.
  ///
  /// **Bei einer Ergänzung stehen beide da**, die frühere zuerst:
  /// „19:00–21:30 · 23:00–06:00". Die Nacht ist dann zwei Strecken lang,
  /// und eine Dauer von 9:30 h neben einem einzigen Fenster von 7:00 h
  /// wäre eine Nacht, die sich nicht nachrechnen lässt — genau die Falle,
  /// die der Entwurf „drei verschiedene Nächte in einem Zustand" nennt.
  String get fensterText {
    final vonHand = this.vonHand;
    if (vonHand != null) {
      return schlafFensterTextAusMinuten(
        vonHand.beginnMinuten,
        vonHand.endeMinuten,
      );
    }

    final gemessen = schlafFensterText(von, bis);
    final ergaenzung = this.ergaenzung;
    if (ergaenzung == null) return gemessen;

    final eingetragen = schlafFensterTextAusMinuten(
      ergaenzung.beginnMinuten,
      ergaenzung.endeMinuten,
    );
    final (eintragVon, _) = eintragFensterMinuten(ergaenzung);
    final gemessenVon = von == null
        ? null
        : EveningClock.minutesSinceEvening(von!);
    final eintragZuerst =
        eintragVon != null && (gemessenVon == null || eintragVon < gemessenVon);

    return eintragZuerst
        ? '$eingetragen · $gemessen'
        : '$gemessen · $eingetragen';
  }

  /// Wie viele Phasen Tagschlaf es an diesem Tag gibt, gemessene und
  /// eingetragene zusammen.
  int get tagschlafAnzahl => naps.length + napEintraege.length;

  /// Die Nacht selbst. **Ohne Abschnitte**, wenn sie von Hand eingetragen
  /// ist — ein Hypnogramm gibt es dafür nicht.
  final SleepNight nacht;

  /// Dieselbe Nacht als Eingabe der Kernrechnung — Schlafminuten,
  /// Einschlafzeit, Wachminuten, Wachphasen.
  final RecoveryNight kern;

  final SleepScore score;
  final List<SchlafTeilnote> teilnoten;

  /// Das Fenster über **alle** Abschnitte, auch die wachen.
  final DateTime? von;
  final DateTime? bis;

  /// Der Tagschlaf desselben Tages — eine Tür, kein Summand.
  final List<SleepSession> naps;

  /// Schlafminuten der Nickerchen, gemessene **und** eingetragene.
  /// Wachliegen in einem gemessenen zählt nicht.
  double get tagschlafMinuten {
    var summe = 0.0;
    for (final nap in naps) {
      summe += schlafMinutenVon(nap);
    }
    for (final eintrag in napEintraege) {
      summe += eintrag.schlafMinuten;
    }
    return summe;
  }
}

/// Alles, was der Schlaf-Schirm aus Apple Health zeigt.
@immutable
class SchlafDaten {
  const SchlafDaten({
    required this.nacht,
    required this.frueher,
    required this.spaeter,
    required bool zeigtAeltereNacht,
    required this.statistik7,
    required this.statistik30,
    required this.scores,
    this.gezeigterTag,
  }) : zeigtAnderenTag = zeigtAeltereNacht;

  final SchlafNacht? nacht;

  /// Der Tag, um den es im Nachtbereich geht — auch dann, wenn es für ihn
  /// **keine** Nacht gibt (#177).
  ///
  /// `null` heißt „es gibt nichts, worauf der Schirm zeigen könnte": keine
  /// geladene Nacht und kein gewählter Tag. Dann steht der Leerzustand da,
  /// nicht ein leerer Tag — der leere Tag ist erreichbar, aber nie der Ort,
  /// an dem man ankommt.
  ///
  /// Ist [nacht] gesetzt, ist dies ihr Aufwachtag; die beiden sagen nie
  /// Verschiedenes.
  final DateTime? gezeigterTag;

  /// Die Nachbarn als Datum, nicht als `bool`: Der Schirm braucht das Ziel
  /// ohnehin, und `null` ist dann genau „am Rand".
  final DateTime? frueher;
  final DateTime? spaeter;

  /// Oben steht **nicht heute** — Verlauf und Statistiken sagen dann, dass
  /// sie sich weiter auf heute beziehen.
  ///
  /// **Seit #177 ist das die Bedingung, nicht mehr „nicht die jüngste
  /// Nacht".** Mit erreichbaren leeren Tagen stimmte beides nicht mehr: Der
  /// gewählte Tag kann **neuer** sein als die jüngste Nacht — die Uhr lag
  /// die letzten zwei Nächte daneben —, und eine Nacht ist er dann auch
  /// nicht. Deshalb heißt der Satz im Schirm „Oben steht ein anderer Tag".
  final bool zeigtAnderenTag;

  /// Der Name von vor #177.
  ///
  /// Er steht in `schlaf_view_test.dart` und in `schlaf_zustand_test.dart`,
  /// und **wer die Implementierung schreibt, ändert keine Testdatei**
  /// (`CLAUDE.md`). Die Umbenennung ist deshalb ein eigener Vorgang; bis
  /// dahin zeigt dieser Name auf [zeigtAnderenTag] und sagt in seinem
  /// eigenen Satz, dass er zu eng ist.
  bool get zeigtAeltereNacht => zeigtAnderenTag;

  final SchlafStatistik? statistik7;
  final SchlafStatistik? statistik30;

  /// Ein Score je geladener Nacht **mit Schlaf**, Schlüssel ist
  /// `SleepNight.date`. Score-Karte und Kalenderblatt teilen sich dieselbe
  /// Rechnung: „zwei Wahrheiten über denselben Score wären schlimmer als
  /// eine langsame".
  ///
  /// Ein Tag ohne Nacht **fehlt** — er hat keinen Score null, er hat
  /// keinen, und das Kalenderblatt zeichnet dort die gestrichelte Spur.
  final Map<DateTime, SleepScore> scores;
}

/// Der ganze Schirm.
@immutable
class SchlafZustand {
  const SchlafZustand({
    required this.daten,
    required this.ziele,
    required this.heute,
    DateTime? fruehesterTag,
  }) : fruehesterTag = fruehesterTag ?? heute;

  final Messwert<SchlafDaten> daten;

  /// Tims eigene Ziele — nie ein Leerzustand, nie eine Konstante im
  /// Quelltext des Schirms.
  final Ziele ziele;

  /// Der Berliner Tagesbeginn, auf den Verlauf und Statistiken sich
  /// beziehen.
  final DateTime heute;

  /// Der früheste Tag, den Blätterleiste und Kalenderblatt anbieten (#177)
  /// — der Anfang des gelesenen Zeitraums, nach hinten verschoben durch
  /// eine ältere eigene Eingabe oder eine ältere Nacht im Cache.
  ///
  /// **Er steht hier und nicht an [SchlafDaten]**, weil er auch dann gilt,
  /// wenn der Lauf nichts brachte: Gerade dann ist jeder Tag des Zeitraums
  /// einer, den man von Hand füllen kann, und das Kalenderblatt muss ihn
  /// anbieten können, ohne dass es ein `SchlafDaten` gibt.
  ///
  /// Ohne Angabe ist es [heute] — dann gibt es genau einen Tag, und
  /// geblättert wird nirgendwohin. Das ist die ehrliche Vorgabe: Wer den
  /// Zeitraum nicht nennt, bekommt keinen geschenkt.
  final DateTime fruehesterTag;
}

/// Das Schlafenszeitziel auf der 18-Uhr-Skala.
///
/// Die Ablage hält es als Minuten **nach Mitternacht**, der Score rechnet
/// seit dem 27.10.2026 auf der Skala von [EveningClock]. Wird diese eine
/// Zeile vergessen, liegt das Ziel nach jeder Einschlafzeit und die
/// Teilnote ist konstant voll.
double _schlafenszeitzielMinuten(Ziele ziele) =>
    EveningClock.minutesSinceEveningOfClock(
      hour: ziele.schlafenszeitMinuten ~/ Duration.minutesPerHour,
      minute: ziele.schlafenszeitMinuten % Duration.minutesPerHour,
    );

/// Rechnet die geladenen Nächte und Tims Ziele zu einem Zustand.
SchlafZustand schlafZustandAus({
  required Messwert<List<SleepNight>> naechte,
  required Ziele ziele,
  required DateTime? gewaehlt,
  required DateTime jetzt,
  List<SchlafEintrag> eintraege = const [],
  DateTime? fensterBeginn,
}) {
  final heute = BerlinCalendar.startOfDay(jetzt);
  final geladen = naechte is Bekannt<List<SleepNight>>
      ? naechte.wert
      : const <SleepNight>[];

  // Der erreichbare Zeitraum hängt **nicht** am Ausgang des Laufs: Auch
  // ein Lauf, der nichts brachte, hat die Tage angesehen, und jeder von
  // ihnen lässt sich von Hand füllen. Ohne genannten Fensteranfang bleibt
  // es bei heute — siehe `SchlafZustand.fruehesterTag`.
  final fruehesterTag = fruehesterSchlaftag(
    fensterBeginn: fensterBeginn ?? heute,
    heute: heute,
    naechte: geladen,
    eintraege: eintraege,
  );

  // Ein gewählter Tag außerhalb des Zeitraums wird **nicht** stillschweigend
  // angenommen: Er käme aus einem Kalenderblatt, das ihn nie angeboten hat.
  final DateTime? gewaehlterTag = gewaehlt == null
      ? null
      : () {
          final tag = BerlinCalendar.startOfDay(gewaehlt);
          if (tag.isBefore(fruehesterTag) || tag.isAfter(heute)) return null;
          return tag;
        }();
  // Hat der Lauf nichts gebracht, Tim aber selbst etwas eingetragen, dann
  // **gibt es etwas zu zeigen** — und zwar genau in dem Zustand, in dem man
  // eine Nacht einträgt (`schlaf.js`, Zustand `leer`: dort ist das
  // Eintragen der einzige Weg, der weiterführt). Der `stand` ist der
  // Zeitpunkt des Laufs, der nichts fand; erfunden ist er nicht, und der
  // Schlaf-Schirm liest ihn ohnehin nicht.
  //
  // **`NochNie` und `Fehlgeschlagen` bleiben, was sie sind.** Der eine ist
  // vorübergehend, der andere ist keine Aussage über die Datenlage — ihn
  // hinter einer eingetragenen Nacht verschwinden zu lassen wäre eine.
  final Messwert<SchlafDaten> daten = switch (naechte) {
    NochNie<List<SleepNight>>() => const NochNie<SchlafDaten>(),
    LeerNachLauf<List<SleepNight>>(:final gelaufen) =>
      _nachtEintraegeDa(eintraege)
          ? Bekannt<SchlafDaten>(
              _daten(
                naechte: const [],
                ziele: ziele,
                gewaehlt: gewaehlterTag,
                jetzt: jetzt,
                eintraege: eintraege,
                fruehesterTag: fruehesterTag,
              ),
              stand: gelaufen,
              laeuft: false,
            )
          : LeerNachLauf<SchlafDaten>(gelaufen: gelaufen),
    Fehlgeschlagen<List<SleepNight>>(:final fehler, :final gelaufen) =>
      Fehlgeschlagen<SchlafDaten>(fehler: fehler, gelaufen: gelaufen),
    Bekannt<List<SleepNight>>(:final wert, :final stand, :final laeuft) =>
      Bekannt<SchlafDaten>(
        _daten(
          naechte: wert,
          ziele: ziele,
          gewaehlt: gewaehlterTag,
          jetzt: jetzt,
          eintraege: eintraege,
          fruehesterTag: fruehesterTag,
        ),
        stand: stand,
        laeuft: laeuft,
      ),
  };

  return SchlafZustand(
    daten: daten,
    ziele: ziele,
    heute: heute,
    fruehesterTag: fruehesterTag,
  );
}

/// Der Score einer von Hand eingetragenen Nacht — dieselbe Formel, andere
/// Eingaben.
///
/// Ohne Phasendaten entfällt die Teilnote Unterbrechungen; ohne getippte
/// Zeiten zusätzlich die Zubettgehzeit. Erreichbar sind dann 80 bzw. 50
/// Punkte statt 100 (#131).
SleepScore _scoreVonHand({
  required SchlafEintrag eintrag,
  required double zielStunden,
  required double zielBett,
}) => SleepScoring.score(
  asleepHours: eintrag.schlafMinuten / Duration.minutesPerHour,
  goalHours: zielStunden,
  bedtimeMinutes: einschlafMinutenVon(eintrag),
  bedtimeGoalMinutes: zielBett,
  awakeMinutes: null,
  wakeCount: null,
);

/// Die gemessene Nacht und der Eintrag, der zu ihr **dazukommt**, als eine
/// Nacht (#192) — Kernwerte und Score in einem Zug, damit die Karte nicht
/// andere Zahlen zeigt, als sie bewertet.
///
/// Die drei Entscheidungen dahinter (Dauer zusammen, Zubettgehzeit von der
/// längeren Strecke, Unterbrechungen nur aus der gemessenen) stehen im
/// Kern bei `SleepMerge.combined`. Hier wird nur übersetzt — in beide
/// Richtungen, und **ohne einen Zeitpunkt zu erfinden**:
/// [RecoveryNight.bedtime] ist ein Moment, die getippte Einschlafzeit aber
/// nur eine Uhrzeit. Trägt der Eintrag die Zubettgehzeit, bleibt `bedtime`
/// deshalb leer; gerechnet wird sie trotzdem, über die Abendskala.
({RecoveryNight kern, SleepScore score}) _ergaenzteNacht({
  required SleepNight gemessen,
  required SchlafEintrag eintrag,
  required double zielStunden,
  required double zielBett,
}) {
  final gemessenerKern = alsRecoveryNacht(gemessen);
  final gemesseneBettzeit = gemessenerKern.bedtime;
  final gemesseneBettMinuten = gemesseneBettzeit == null
      ? null
      : EveningClock.minutesSinceEvening(gemesseneBettzeit);

  final zusammen = SleepMerge.combined(
    measuredAsleepMinutes: gemessenerKern.asleepMinutes,
    measuredBedtimeMinutes: gemesseneBettMinuten,
    measuredAwakeMinutes: gemessenerKern.awakeMinutes,
    measuredWakeCount: gemessenerKern.wakeCount,
    entryAsleepMinutes: eintrag.schlafMinuten.toDouble(),
    entryBedtimeMinutes: einschlafMinutenVon(eintrag),
  );

  return (
    kern: RecoveryNight(
      date: gemessen.date,
      asleepMinutes: zusammen.asleepMinutes,
      bedtime: zusammen.bedtimeMinutes == gemesseneBettMinuten
          ? gemesseneBettzeit
          : null,
      awakeMinutes: zusammen.awakeMinutes,
      wakeCount: zusammen.wakeCount,
    ),
    score: SleepScoring.score(
      asleepHours: zusammen.asleepMinutes / Duration.minutesPerHour,
      goalHours: zielStunden,
      bedtimeMinutes: zusammen.bedtimeMinutes,
      bedtimeGoalMinutes: zielBett,
      awakeMinutes: zusammen.awakeMinutes,
      wakeCount: zusammen.wakeCount,
    ),
  );
}

/// Die Nacht dieses Aufwachtags aus einer chronologischen Reihe, oder
/// `null` — es muss für einen Tag keine geben.
SleepNight? _nachtAn(List<SleepNight> sortiert, DateTime tag) {
  for (final nacht in sortiert) {
    if (nacht.date == tag) return nacht;
  }
  return null;
}

bool _nachtEintraegeDa(List<SchlafEintrag> eintraege) =>
    eintraege.any((e) => e.art == SchlafEintragArt.nacht);

SchlafDaten _daten({
  required List<SleepNight> naechte,
  required Ziele ziele,
  required DateTime? gewaehlt,
  required DateTime jetzt,
  required List<SchlafEintrag> eintraege,
  required DateTime fruehesterTag,
}) {
  final zielStunden = ziele.schlafzielMinuten / Duration.minutesPerHour;
  final zielBett = _schlafenszeitzielMinuten(ziele);

  // Die eingetragenen Nächte über die gemessenen gelegt. **Ab hier rechnet
  // der ganze Schirm auf dieser Liste** — Auswahl, Nachbarn und Score
  // sollen dieselbe Reihe sehen, sonst führte das Blättern an einer
  // eingetragenen Nacht vorbei.
  //
  // Verlauf, die beiden Schnitt-Karten und „Sieben Nächte" tun es
  // ausdrücklich **nicht**: Sie hängen an `sleepProvider` und rechnen über
  // Phasen, die eine eingetragene Nacht nicht hat. Eine erfundene
  // Phasenverteilung wäre genau die „Zahl ohne Messung", gegen die dieses
  // Ticket geschrieben ist; der Schirm sagt stattdessen, worauf sie sich
  // beziehen.
  final gemischt = naechteMitEintraegen(
    gemessen: naechte,
    eintraege: eintraege,
  );

  /// Wie der Eintrag eines Tages zur gemessenen Nacht steht — einmal
  /// gefragt, von Score, Karte und Abschnitten geteilt (#192).
  ({SchlafEintrag eintrag, SchlafEintragLage lage})? lageAn(DateTime tag) =>
      nachtEintragLage(tag: tag, gemessen: naechte, eintraege: eintraege);

  // Einmal gerechnet, von Karte und Kalenderblatt geteilt.
  final scores = <DateTime, SleepScore>{
    ...SleepScoring.series(
      nights: [
        for (final nacht in gemischt)
          if (lageAn(nacht.date) == null) alsRecoveryNacht(nacht),
      ],
      goalHours: zielStunden,
      bedtimeGoalMinutes: zielBett,
    ),
    // Die eingetragenen Nächte rechnen nach derselben Formel, nur mit
    // anderen Eingaben: Dauer und Einschlafzeit kommen aus dem Eintrag,
    // Wachminuten und Wachphasen gibt es nicht.
    //
    // **Außer der Eintrag ergänzt nur** (#192): Dann steht die gemessene
    // Nacht vollständig daneben, und beide Strecken zählen zusammen.
    for (final nacht in gemischt)
      if (lageAn(nacht.date) case final da?)
        nacht.date: switch (da.lage) {
          SchlafEintragLage.ersatz => _scoreVonHand(
            eintrag: da.eintrag,
            zielStunden: zielStunden,
            zielBett: zielBett,
          ),
          SchlafEintragLage.ergaenzung => _ergaenzteNacht(
            gemessen: nacht,
            eintrag: da.eintrag,
            zielStunden: zielStunden,
            zielBett: zielBett,
          ).score,
        },
  };

  final heute = BerlinCalendar.startOfDay(jetzt);
  final sortiert = schlafChronologisch(gemischt);

  // **Der Tag kommt vor der Nacht** (#177): Der gewählte, sonst die
  // jüngste vorhandene Nacht. `null` heißt „es gibt nichts, worauf der
  // Schirm zeigen könnte" — dann steht der Leerzustand da.
  //
  // Der Startpunkt bleibt die jüngste Nacht und ist nicht heute: Sonst
  // stünde der Schirm jeden Morgen leer da, bis die Uhr fertig
  // synchronisiert hat — `docs/todo/01` im neuen Gewand, einmal täglich.
  final gezeigterTag =
      gewaehlt ?? (sortiert.isEmpty ? null : sortiert.last.date);

  // **Kein Ausweichen auf die letzte Nacht.** Ein gewählter Tag ohne Nacht
  // ist seit #177 ein eigener Zustand und kein Unfall; `schlafZustandAus`
  // hat vorher aussortiert, was außerhalb des Zeitraums liegt, also ist
  // eine leere Antwort hier immer eine Aussage über den Tag.
  final gezeigt = gezeigterTag == null
      ? null
      : _nachtAn(sortiert, gezeigterTag);

  final nachbarn = gezeigterTag == null
      ? (frueher: null, spaeter: null)
      : schlafTagNachbarn(
          tag: gezeigterTag,
          fruehesterTag: fruehesterTag,
          heute: heute,
        );

  SchlafNacht? nacht;
  if (gezeigt != null) {
    final da = lageAn(gezeigt.date);
    final vonHand = da?.lage == SchlafEintragLage.ersatz ? da!.eintrag : null;
    final ergaenzung = da?.lage == SchlafEintragLage.ergaenzung
        ? da!.eintrag
        : null;
    final kern = switch (da?.lage) {
      null => alsRecoveryNacht(gezeigt),
      SchlafEintragLage.ersatz => RecoveryNight(
        date: gezeigt.date,
        asleepMinutes: da!.eintrag.schlafMinuten.toDouble(),
        // **Kein erfundener Zeitpunkt.** Der Eintrag trägt eine
        // Uhrzeit, keinen Moment; die Einschlafzeit geht als
        // Wanduhrzeit direkt in den Score (`einschlafMinutenVon`), und
        // die Karte liest sie ebenso aus dem Eintrag.
      ),
      SchlafEintragLage.ergaenzung => _ergaenzteNacht(
        gemessen: gezeigt,
        eintrag: da!.eintrag,
        zielStunden: zielStunden,
        zielBett: zielBett,
      ).kern,
    };
    // Dieselbe Rechnung wie in der Reihe; eine Nacht ohne Schlafminuten
    // fehlt dort und bekommt ihren Score hier.
    final score =
        scores[gezeigt.date] ??
        SleepScoring.score(
          asleepHours: kern.asleepHours,
          goalHours: zielStunden,
          bedtimeMinutes: kern.bedtime == null
              ? null
              : EveningClock.minutesSinceEvening(kern.bedtime!),
          bedtimeGoalMinutes: zielBett,
          awakeMinutes: kern.awakeMinutes,
          wakeCount: kern.wakeCount,
        );
    final (von, bis) = schlafFensterVon(gezeigt.session);
    nacht = SchlafNacht(
      nacht: gezeigt,
      kern: kern,
      score: score,
      teilnoten: schlafTeilnoten(score),
      von: von,
      bis: bis,
      naps: gezeigt.naps,
      vonHand: vonHand,
      ergaenzung: ergaenzung,
      napEintraege: tagschlafEintraegeZu(gezeigt.date, eintraege),
    );
  }

  return SchlafDaten(
    nacht: nacht,
    gezeigterTag: gezeigterTag,
    frueher: nachbarn.frueher,
    spaeter: nachbarn.spaeter,
    // Seit #177: „nicht heute", nicht mehr „nicht die jüngste Nacht".
    zeigtAeltereNacht: gezeigterTag != null && gezeigterTag != heute,
    // Die Statistiken hängen an **heute**, nicht an der gewählten Nacht —
    // deshalb stehen sie hier und nicht an `SchlafNacht`.
    statistik7: schlafStatistik(
      naechte: naechte,
      bis: jetzt,
      tage: schlafStatistikKurz,
    ),
    statistik30: schlafStatistik(
      naechte: naechte,
      bis: jetzt,
      tage: schlafStatistikLang,
    ),
    scores: scores,
  );
}

/// Der Zustand des Schlaf-Schirms, **gehalten** statt bei jedem Zugriff
/// gerechnet (Hausregel 2, `docs/todo/03`).
///
/// `autoDispose`, damit er die Auswahl nicht über das Verlassen des
/// Schirms hinaus am Leben hält.
final schlafProvider = Provider.autoDispose<SchlafZustand>((ref) {
  final naechte =
      ref.watch(sleepProvider).value ?? const NochNie<List<SleepNight>>();

  return schlafZustandAus(
    naechte: naechte,
    ziele: zieleAusProvider(ref.watch(zieleProvider)).ziele,
    gewaehlt: ref.watch(schlafAuswahlProvider),
    jetzt: ref.watch(clockProvider)(),
    // **Kein `Messwert`.** Tims eigene Eingabe kennt keinen Lauf, der leer
    // ausgehen könnte (`CLAUDE.md`, Spec 5.6a) — leer heißt leer. Dasselbe
    // `?? const []` wie überall, wo ein `AsyncValue` in die
    // Widget-Schicht stößt: Solange gelesen wird, gibt es noch keine
    // Einträge, und die gemessenen Nächte stehen trotzdem schon da.
    eintraege: ref.watch(schlafEintraegeProvider).value ?? const [],
    // Der gelesene Zeitraum (`docs/SPEC.md` 3: 30 Tage einschließlich
    // heute, vom eingestellten Betrachtungszeitraum höchstens verkürzt).
    // **Derselbe, über den `sleepProvider` liest** — nur so heißt ein
    // gestrichelter Tag im Kalenderblatt „nachgesehen und nichts
    // gefunden" und nicht „nie nachgesehen".
    fensterBeginn: ref.watch(rechenfensterProvider).start,
  );
});
