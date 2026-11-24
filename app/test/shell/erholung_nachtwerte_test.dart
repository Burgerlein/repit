import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/core/messwert.dart';
import 'package:repit/data/ziele.dart';
import 'package:repit/health/health_types.dart';
import 'package:repit/shell/erholung_zustand.dart';
import 'package:repit/shell/verlauf_zustand.dart';

/// Tests für **Stufe 4** von #193 — die Verdrahtung der Nachtwerte in den
/// Zustand des Erholung-Schirms und von dort in die Verlaufsseiten.
/// Grundlage ist `docs/superpowers/specs/2026-11-02-193-nachtwerte.md`,
/// Abschnitt „Stufe 4 — Verdrahtung" samt „Was dabei nicht passieren darf".
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden.
///
/// ## Worum es geht
///
/// Apples `RestingHeartRate` ist ein **Tageswert**, der im Lauf des Tages
/// mitwächst; HRV und Atemfrequenz hat die App bisher über den ganzen
/// Kalendertag gemittelt. Die Stufen 1 bis 3 haben die Nachtwerte gerechnet
/// (`NightVitals` im Kern), über den Kanal geholt und je Nacht gehalten
/// (`nachtWerteProvider`, Cache-Schema v8) — **nur zeigt sie kein Schirm.**
/// Alle drei Zahlen kommen weiterhin aus `DailyMetrics`. Das ist Stufe 4.
///
/// ## Festgelegte öffentliche API (`lib/shell/erholung_zustand.dart`)
///
/// ```dart
/// /// Ein Tageswert aus Apple Health **plus die Werte seiner Nacht** als
/// /// Eingabe der Kernrechnung. Die drei Erholungswerte kommen aus
/// /// [nachtwerte]; `exerciseMinutes` bleibt Tageswert.
/// RecoveryDay alsRecoveryDay(DailyMetrics tag, {NightVitals? nachtwerte});
///
/// ErholungZustand erholungZustandAus({
///   required Messwert<List<DailyMetrics>> tageswerte,
///   required Messwert<List<SleepNight>> naechte,
///   Messwert<Map<String, NightVitals>> nachtwerte =
///       const NochNie<Map<String, NightVitals>>(),
///   required Ziele ziele,
///   required DataWindow fenster,
///   required DateTime jetzt,
/// });
/// ```
///
/// Die Karte wird unter dem **ISO-Tagesschlüssel** nachgeschlagen, also
/// unter demselben String, den `DailyMetrics.tag` und `Naechte.tag` tragen
/// (`BerlinCalendar.dayKey`) — ein Tag ist eine Kalenderangabe, kein
/// Zeitpunkt (`CLAUDE.md`).
///
/// `nachtwerte` ist ein benannter Parameter mit Vorgabewert, damit die
/// bestehenden Aufrufer übersetzt bleiben; der Vorgabewert ist `NochNie`
/// und bedeutet „noch nicht nachgesehen", **nicht** „nimm die Tageswerte".
///
/// ## Die Nachtwerte sind **keine dritte Hälfte des Schirms**
///
/// `_verbinde` entscheidet aus Tageswerten und Nächten, **ob** es etwas zu
/// zeigen gibt („Eine Hälfte reicht"). Die Nachtwerte entscheiden das
/// nicht mit: Der Schirm steht auch ohne sie — Schlaf, Score, Training,
/// Alkohol und die Datumszeile hängen nicht an ihnen. Sie tun genau zwei
/// Dinge:
///
/// 1. Sie **füllen** `restingHeartRate`, `hrv` und `respiratoryRate`.
/// 2. Sie machen `laeuft` wahr, solange sie unterwegs sind — und ihr Stand
///    zählt beim „der frühere gewinnt" mit.
///
/// Was daraus folgt und unten geprüft wird: Ein `LeerNachLauf` beider
/// bestehender Hälften bleibt `LeerNachLauf`, auch wenn die Nachtwerte nie
/// gelaufen sind. Wären sie eine dritte Hälfte, würde aus „gelaufen,
/// nichts gefunden" ein Ladezustand — und jede bestehende Zusicherung über
/// die vier `Messwert`-Zustände des Schirms wäre eine andere geworden,
/// ohne dass jemand darüber entschieden hat.
///
/// ## Was hier bewusst **nicht** geprüft wird
///
/// - **Der Rückfall auf den jüngsten vorhandenen Wert** (#194, Punkt 1).
///   Eine Nacht ohne Pulsproben bleibt hier leer und holt sich keinen Wert
///   von vorgestern.
/// - **Der fehlende Grund auf dem Heute-Schirm** (#199) und die
///   Stand-Zeile (#200).
/// - **`NULL`-Überschreiben beim Zurückschreiben** (#197).
/// - **Was ein erfolgreicher, aber leerer Lauf mit einem Cache-Wert
///   macht.** Das ist app-weites Verhalten von `alsMesswert`, kein
///   Verhalten dieses Schirms. Mit **#224** ist es entschieden (Tim,
///   03.11.2026): Der Cache-Wert bleibt stehen, `LeerNachLauf` gilt nur
///   noch ohne Cache. Geprüft wird das dort, wo die Regel lebt —
///   `test/core/messwert_test.dart` und
///   `test/health/leerer_lauf_behaelt_cache_test.dart`.
/// - **Das Aufräumen der doppelten Spalten** (#225).
/// - **Layout und Beschriftung.** Geprüft werden Zustände und Übergänge
///   (`CLAUDE.md`).
///
/// ## Kein Rückfall auf den Tageswert — entschieden und gemessen
///
/// **Von Tim am 02.11.2026** (Auswahlmenü): Eine Nacht ohne Pulsproben
/// zeigt „keine Werte". Kein Rückfall auf Apples Tageswert, auch nicht
/// gekennzeichnet.
///
/// Die Entscheidung ist gemessen, nicht geraten. In Tims Health-Export vom
/// 13.10.2026 reichten die Proben in den letzten 90 Tagen in **7 von 7**
/// Nächten für alle drei Werte (Median 90 Pulsproben, 2 HRV-Proben, 40
/// Atemproben); über das letzte Jahr 93 % / 86 % / 93 %. Der Fall „Nacht
/// da, aber zu wenige Proben" kommt faktisch nicht vor — die ehrliche
/// Antwort kostet also nichts. **Deshalb wird der Rückfall nicht gebaut,
/// auch nicht der Vollständigkeit halber.** Wer ihn später nachrüstet,
/// baut Fehler `01` wieder ein, gegen den #193 angetreten ist.
///
/// Diese Entscheidung kostet einen bestehenden Test: In
/// `erholung_zustand_test.dart` prüfte „ein Tageswert wandert vollständig
/// und als Datum herüber", dass die drei Werte aus `DailyMetrics` kommen.
/// Er ist am 02.11.2026 auf das zurückgeschnitten, was weiter gilt (Datum
/// und Trainingsminuten) — mit Begründung in seinem eigenen Dateikopf.
///
/// ## Zahlen in dieser Datei
///
/// Alle erfunden. Keine stammt aus einem Export, einem Screenshot oder
/// `docs/screens/` (`CLAUDE.md`, Spec Abschnitt 12).
///
/// Die Tageswerte sind **absichtlich andere** als die Nachtwerte. Nur so
/// ist eine gemischte Quelle — Nachtwert gegen Tagesmedian — überhaupt
/// unterscheidbar; stimmten beide überein, ginge genau der Fehler durch,
/// gegen den diese Datei gebaut ist.
void main() {
  // Montag, 12.10.2026, 09:15 Berliner Zeit (CEST, +2) — weit vor der
  // Umstellung am 25.10. Montag, damit die Trainingswoche an diesem Tag
  // beginnt.
  final jetzt = DateTime.utc(2026, 10, 12, 7, 15);

  /// Der Berliner Tagesbeginn des Oktobertags [tag]. Über [BerlinCalendar]
  /// gerechnet und nicht von Hand mit einem UTC-Zeitpunkt gepaart — an
  /// genau dieser Paarung lag der Zahlendreher in den `DataWindow`-Tests.
  DateTime tagesbeginn(int tag) =>
      BerlinCalendar.startOfDay(DateTime.utc(2026, 10, tag, 12));

  String tagKey(int tag) => BerlinCalendar.dayKey(tagesbeginn(tag));

  /// Ein Tageswert aus Apple Health. Die drei Erholungswerte stehen hier
  /// weiterhin drin — die App bekommt sie vom Kanal und darf sie nur nicht
  /// mehr anzeigen.
  DailyMetrics tagwert(
    int tag, {
    int? ruhepuls = 62,
    double? hrv = 40,
    double? atmung = 16,
    double? trainingsminuten = 20,
  }) => DailyMetrics(
    tag: tagKey(tag),
    restingHR: ruhepuls,
    hrvMs: hrv,
    respRate: atmung,
    exerciseMinutes: trainingsminuten,
  );

  /// Eine Nacht, die um 06:00 Berliner Zeit endet und [stunden] lang ist.
  SleepNight nachtVon(int tag, {double stunden = 7}) {
    final ende = tagesbeginn(tag).add(const Duration(hours: 6));
    final beginn = ende.subtract(Duration(minutes: (stunden * 60).round()));
    return SleepNight(
      date: tagesbeginn(tag),
      session: SleepSession(
        segments: [
          SleepSegment(stage: SleepStage.core, start: beginn, end: ende),
        ],
      ),
    );
  }

  List<DailyMetrics> tagereihe({
    int? ruhepulsHeute = 62,
    double? hrvHeute = 40,
    double? atmungHeute = 16,
    int? ruhepulsDavor = 62,
    double? hrvDavor = 40,
    double? atmungDavor = 16,
  }) => [
    for (var t = 3; t <= 11; t++)
      tagwert(t, ruhepuls: ruhepulsDavor, hrv: hrvDavor, atmung: atmungDavor),
    tagwert(12, ruhepuls: ruhepulsHeute, hrv: hrvHeute, atmung: atmungHeute),
  ];

  List<SleepNight> nachtreihe() => [for (var t = 3; t <= 12; t++) nachtVon(t)];

  /// Die Nachtwerte der zehn Tage, heute (12.) getrennt von den neun davor —
  /// so sind Messwert und Vergleichswert auseinanderzuhalten.
  Map<String, NightVitals> nachtkarte({
    double? ruhepulsHeute = 48,
    double? hrvHeute = 50,
    double? atmungHeute = 13,
    double? ruhepulsDavor = 48,
    double? hrvDavor = 50,
    double? atmungDavor = 13,
  }) => {
    for (var t = 3; t <= 11; t++)
      tagKey(t): NightVitals(
        restingHeartRate: ruhepulsDavor,
        hrv: hrvDavor,
        respiratoryRate: atmungDavor,
      ),
    tagKey(12): NightVitals(
      restingHeartRate: ruhepulsHeute,
      hrv: hrvHeute,
      respiratoryRate: atmungHeute,
    ),
  };


  ErholungZustand zustand({
    Messwert<List<DailyMetrics>>? tageswerte,
    Messwert<List<SleepNight>>? naechte,
    Messwert<Map<String, NightVitals>>? nachtwerte,
    List<DailyMetrics>? tage,
    Map<String, NightVitals>? karte,
  }) => erholungZustandAus(
    tageswerte:
        tageswerte ??
        Bekannt<List<DailyMetrics>>(
          tage ?? tagereihe(),
          stand: jetzt,
          laeuft: false,
        ),
    naechte:
        naechte ??
        Bekannt<List<SleepNight>>(nachtreihe(), stand: jetzt, laeuft: false),
    nachtwerte:
        nachtwerte ??
        Bekannt<Map<String, NightVitals>>(
          karte ?? nachtkarte(),
          stand: jetzt,
          laeuft: false,
        ),
    ziele: Ziele.vorbelegung,
    fenster: DataWindow(start: tagesbeginn(1)),
    jetzt: jetzt,
  );

  ErholungDaten datenAus(ErholungZustand z) {
    final daten = z.daten;
    if (daten is! Bekannt<ErholungDaten>) {
      fail('erwartet war Bekannt, da stand $daten');
    }
    return daten.wert;
  }

  RecoverySnapshot schnappschuss({
    Messwert<Map<String, NightVitals>>? nachtwerte,
    List<DailyMetrics>? tage,
    Map<String, NightVitals>? karte,
  }) =>
      datenAus(zustand(nachtwerte: nachtwerte, tage: tage, karte: karte))
          .schnappschuss;

  VerlaufDaten verlauf(VerlaufArt art, {Map<String, NightVitals>? karte}) {
    final daten = verlaufZustandAus(
      art: art,
      erholung: zustand(karte: karte),
    ).daten;
    if (daten is! Bekannt<VerlaufDaten>) {
      fail('erwartet war Bekannt, da stand $daten');
    }
    return daten.wert;
  }

  // ─────────────────────────────────────────────────────────────────────

  group('alsRecoveryDay — die Quelle wechselt, der Typ bleibt', () {
    test('die drei Werte kommen aus der Nacht, nicht aus dem Tageswert', () {
      final kern = alsRecoveryDay(
        tagwert(12, ruhepuls: 62, hrv: 40, atmung: 16, trainingsminuten: 44),
        nachtwerte: const NightVitals(
          restingHeartRate: 48,
          hrv: 61,
          respiratoryRate: 13.2,
        ),
      );

      expect(kern.date, tagesbeginn(12));
      expect(kern.restingHeartRate, 48.0);
      expect(kern.hrv, 61.0);
      expect(kern.respiratoryRate, 13.2);
    });

    test('exerciseMinutes bleibt Tageswert — Training ist keine Nacht', () {
      final kern = alsRecoveryDay(
        tagwert(12, trainingsminuten: 44),
        nachtwerte: const NightVitals(restingHeartRate: 48),
      );

      expect(kern.exerciseMinutes, 44.0);
    });

    test('ohne Nachtwerte bleiben die drei null — Apples Tageswert tritt nicht '
        'an ihre Stelle, und null wird nie zu 0', () {
      final kern = alsRecoveryDay(
        tagwert(12, ruhepuls: 62, hrv: 40, atmung: 16),
        nachtwerte: null,
      );

      expect(
        kern.restingHeartRate,
        isNull,
        reason:
            'ein Ring auf 0 oder ein eingesetzter Tageswert behauptet eine '
            'Messung, die es für diese Nacht nicht gibt (Fehler 01)',
      );
      expect(kern.hrv, isNull);
      expect(kern.respiratoryRate, isNull);
      expect(kern.exerciseMinutes, 20.0, reason: 'der Tageswert bleibt');
    });

    test('ein einzelnes fehlendes Feld fehlt einzeln — zu wenige Pulsproben '
        'nehmen HRV und Atmung nicht mit', () {
      final kern = alsRecoveryDay(
        tagwert(12),
        nachtwerte: const NightVitals(hrv: 61, respiratoryRate: 13.2),
      );

      expect(kern.restingHeartRate, isNull);
      expect(kern.hrv, 61.0);
      expect(kern.respiratoryRate, 13.2);
    });
  });

  group('erholungZustandAus — je Tag die Werte seiner eigenen Nacht', () {
    test('heute trägt die Nachtwerte von heute, nicht die von gestern', () {
      final karte = nachtkarte(hrvHeute: 61, hrvDavor: 44);
      final snap = schnappschuss(karte: karte);

      expect(snap.reading.hrv, 61.0);
      final gestern = snap.days.firstWhere((t) => t.date == tagesbeginn(11));
      expect(gestern.hrv, 44.0);
    });

    test('ein Tag ohne Eintrag in der Karte trägt keine drei Werte — und nicht '
        'die aus Apple Health', () {
      final karte = nachtkarte()..remove(tagKey(12));
      final snap = schnappschuss(karte: karte);

      expect(snap.reading.restingHeartRate, isNull);
      expect(snap.reading.hrv, isNull);
      expect(snap.reading.respiratoryRate, isNull);
      expect(
        snap.reading.sleepHours,
        isNotNull,
        reason: 'der Schlaf hängt an den Nächten und bleibt stehen',
      );
      final heute = snap.days.firstWhere((t) => t.date == tagesbeginn(12));
      expect(
        heute.exerciseMinutes,
        20.0,
        reason: 'der Tageswert verschwindet nicht mit den Nachtwerten',
      );
    });

    test('eine Nacht mit zu wenigen Pulsproben zeigt keinen Ruhepuls, behält '
        'aber HRV und Atemfrequenz', () {
      final karte = nachtkarte()
        ..[tagKey(12)] = const NightVitals(hrv: 61, respiratoryRate: 13.2);
      final snap = schnappschuss(karte: karte);

      expect(snap.reading.restingHeartRate, isNull);
      expect(snap.reading.hrv, 61.0);
      expect(snap.reading.respiratoryRate, 13.2);
    });
  });

  group('Die drei Zustände der Nachtwerte nehmen nichts weg', () {
    test(
      'solange die Nachtwerte noch laufen, steht kein „keine Daten"-Grund',
      () {
        final z = zustand(
          nachtwerte: const NochNie<Map<String, NightVitals>>(),
        );

        expect(
          z.daten,
          isA<Bekannt<ErholungDaten>>(),
          reason:
              'Tageswerte und Nächte liegen vor; ein Leerstand oder ein '
              'Fehler wäre Fehler 01 — der Ladezustand als Leerstand',
        );
        expect(
          (z.daten as Bekannt<ErholungDaten>).laeuft,
          isTrue,
          reason: 'eine Hälfte ist noch unterwegs',
        );
      },
    );

    test('ein gescheiterter Nachtlauf nimmt den Schlaf nicht weg', () {
      final z = zustand(
        nachtwerte: Fehlgeschlagen<Map<String, NightVitals>>(
          fehler: StateError('Kanal weg'),
          gelaufen: jetzt,
        ),
      );

      final snap = datenAus(z).schnappschuss;
      expect(snap.reading.sleepHours, isNotNull);
      expect(snap.reading.hrv, isNull);
      expect(snap.reading.restingHeartRate, isNull);
      expect(snap.reading.respiratoryRate, isNull);
    });

    test('ein leerer Nachtlauf lässt die übrigen Hälften stehen', () {
      final z = zustand(
        nachtwerte: LeerNachLauf<Map<String, NightVitals>>(gelaufen: jetzt),
      );

      final snap = datenAus(z).schnappschuss;
      expect(snap.reading.sleepHours, isNotNull);
      expect(snap.days, isNotEmpty);
      expect(snap.reading.hrv, isNull);
    });

    test('sind Tageswerte und Nächte nie gelaufen, ist es NochNie', () {
      final z = zustand(
        tageswerte: const NochNie<List<DailyMetrics>>(),
        naechte: const NochNie<List<SleepNight>>(),
        nachtwerte: const NochNie<Map<String, NightVitals>>(),
      );

      expect(z.daten, isA<NochNie<ErholungDaten>>());
    });

    test('nie gelaufene Nachtwerte machen aus einem leeren Lauf keinen '
        'Ladezustand — sie sind keine dritte Hälfte des Schirms', () {
      final z = zustand(
        tageswerte: LeerNachLauf<List<DailyMetrics>>(gelaufen: jetzt),
        naechte: LeerNachLauf<List<SleepNight>>(gelaufen: jetzt),
        nachtwerte: const NochNie<Map<String, NightVitals>>(),
      );

      expect(
        z.daten,
        isA<LeerNachLauf<ErholungDaten>>(),
        reason:
            'ob es etwas zu zeigen gibt, entscheiden Tageswerte und '
            'Nächte; die Nachtwerte füllen nur drei Felder. Wären sie '
            'eine dritte Hälfte, wäre jede bestehende Zusicherung über die '
            'vier Zustände des Schirms eine andere geworden',
      );
    });

    test('der frühere Stand gewinnt auch gegen den der Nachtwerte — eine '
        'Standzeile darf nicht neuer behaupten als die älteste Hälfte', () {
      final frueher = jetzt.subtract(const Duration(hours: 3));
      final z = zustand(
        nachtwerte: Bekannt<Map<String, NightVitals>>(
          nachtkarte(),
          stand: frueher,
          laeuft: false,
        ),
      );

      expect((z.daten as Bekannt<ErholungDaten>).stand, frueher);
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // Die Ampelschwellen bleiben unverändert (SPEC 176): Ruhepuls ≥ 5 bpm
  // über dem Median, HRV ≤ Median · 0,8, Atemfrequenz ≥ 1,5 darüber. Wert
  // **und** Median wandern gemeinsam auf die Nachtwerte; die Abstände
  // behalten ihre Bedeutung.
  //
  // **Warum die Zahlen so krumm aussehen.** Jeder der drei Fälle ist so
  // gelegt, dass das Signal **nur** entsteht, wenn Wert und Median beide
  // aus der Nacht kommen. Die drei anderen Paarungen — Nachtwert gegen
  // Tagesmedian, Tageswert gegen Nachtmedian, Tageswert gegen Tagesmedian —
  // ergeben jede für sich kein Signal. Ein Test, der nur das Ergebnis
  // vergleicht, ließe die gemischte Quelle durch: beide Zahlen plausibel,
  // die Ampel falsch.
  group('Die Ampel rechnet Wert und Median aus derselben Quelle', () {
    test('Ruhepuls: 55 gegen den Nachtmedian 48 ist ein Signal', () {
      // Nacht: 48 an den neun Tagen davor, heute 55 → Schwelle 53, Signal.
      // Tag:   62 davor, heute 50 → 55 ≥ 67 nein, 50 ≥ 53 nein, 50 ≥ 67 nein.
      final snap = schnappschuss(
        tage: tagereihe(ruhepulsHeute: 50, ruhepulsDavor: 62),
        karte: nachtkarte(ruhepulsHeute: 55, ruhepulsDavor: 48),
      );

      expect(snap.reading.restingHeartRate, 55.0, reason: 'der Nachtwert');
      expect(snap.baseline.restingHeartRate, 48.0, reason: 'der Nachtmedian');
      expect(snap.evaluation.signals, const [RecoveryMetric.restingHeartRate]);
    });

    test('HRV: 39 gegen den Nachtmedian 50 ist ein Signal', () {
      // Nacht: 50 davor, heute 39 → Schwelle 40, Signal.
      // Tag:   40 davor, heute 41 → 39 ≤ 32 nein, 41 ≤ 40 nein, 41 ≤ 32 nein.
      final snap = schnappschuss(
        tage: tagereihe(hrvHeute: 41, hrvDavor: 40),
        karte: nachtkarte(hrvHeute: 39, hrvDavor: 50),
      );

      expect(snap.reading.hrv, 39.0, reason: 'der Nachtwert');
      expect(snap.baseline.hrv, 50.0, reason: 'der Nachtmedian');
      expect(snap.evaluation.signals, const [RecoveryMetric.hrv]);
    });

    test('Atemfrequenz: 15,0 gegen den Nachtmedian 13,0 ist ein Signal', () {
      // Nacht: 13,0 davor, heute 15,0 → Schwelle 14,5, Signal.
      // Tag:   16,0 davor, heute 13,5 → 15,0 ≥ 17,5 nein, 13,5 ≥ 14,5 nein,
      //        13,5 ≥ 17,5 nein.
      final snap = schnappschuss(
        tage: tagereihe(atmungHeute: 13.5, atmungDavor: 16),
        karte: nachtkarte(atmungHeute: 15, atmungDavor: 13),
      );

      expect(snap.reading.respiratoryRate, 15.0, reason: 'der Nachtwert');
      expect(snap.baseline.respiratoryRate, 13.0, reason: 'der Nachtmedian');
      expect(snap.evaluation.signals, const [RecoveryMetric.respiratoryRate]);
    });

    test('und die Schwellen selbst sind dieselben geblieben — der Abstand, '
        'nicht die Zahl, trägt die Bedeutung', () {
      expect(RecoveryTrafficLight.restingHeartRateMargin, 5.0);
      expect(RecoveryTrafficLight.hrvFactor, 0.8);
      expect(RecoveryTrafficLight.respiratoryRateMargin, 1.5);
      expect(RecoveryTrafficLight.minimumSleepHours, 6.0);
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // „Zwei Quellen für dieselbe Auskunft wären zwei Wahrheiten."
  group('Der Verlauf-Schirm zieht aus derselben Quelle', () {
    test('die HRV-Reihe trägt die Nachtwerte, nicht die Tageswerte', () {
      final daten = verlauf(
        VerlaufArt.hrv,
        karte: nachtkarte(hrvHeute: 39, hrvDavor: 50),
      );

      expect(daten.aktuell, 39.0);
      expect(daten.median, 50.0);
      expect(daten.signalAb, 40.0);
      expect(daten.istSignal(39), isTrue);
      expect(
        daten.reihe.map((punkt) => punkt.wert),
        everyElement(anyOf(50.0, 39.0)),
        reason: '40 und 41 sind die Tageswerte und haben hier nichts zu suchen',
      );
    });

    test('die Ruhepuls-Reihe ebenso', () {
      final daten = verlauf(
        VerlaufArt.ruhepuls,
        karte: nachtkarte(ruhepulsHeute: 55, ruhepulsDavor: 48),
      );

      expect(daten.aktuell, 55.0);
      expect(daten.median, 48.0);
      expect(daten.reihe.map((punkt) => punkt.wert), isNot(contains(62.0)));
    });

    test('die Atemfrequenz-Reihe ebenso', () {
      final daten = verlauf(
        VerlaufArt.atemfrequenz,
        karte: nachtkarte(atmungHeute: 15, atmungDavor: 13),
      );

      expect(daten.aktuell, 15.0);
      expect(daten.median, 13.0);
      expect(daten.reihe.map((punkt) => punkt.wert), isNot(contains(16.0)));
    });

    test('ein Tag ohne Nachtwerte fällt aus der Reihe heraus — er steht weder '
        'mit 0 noch mit Apples Tageswert darin', () {
      final daten = verlauf(
        VerlaufArt.hrv,
        karte: nachtkarte()..remove(tagKey(12)),
      );

      expect(
        daten.reihe.map((punkt) => punkt.tag),
        isNot(contains(tagesbeginn(12))),
      );
      expect(daten.reihe.map((punkt) => punkt.wert), isNot(contains(0.0)));
      expect(daten.reihe.map((punkt) => punkt.wert), isNot(contains(40.0)));
    });

    test('und der Schlaf bleibt, woher er kam — aus den Nächten', () {
      final daten = verlauf(
        VerlaufArt.schlaf,
        karte: nachtkarte()..remove(tagKey(12)),
      );

      expect(
        daten.reihe,
        hasLength(10),
        reason: 'zehn Nächte, unabhängig davon, was die Nachtwerte hergeben',
      );
      expect(daten.aktuell, 7.0);
    });
  });
}
