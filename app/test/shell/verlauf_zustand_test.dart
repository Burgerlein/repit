import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/core/messwert.dart';
import 'package:repit/data/ziele.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_types.dart';
import 'package:repit/shell/diagramm_zeitraum.dart';
import 'package:repit/shell/erholung_zustand.dart';
import 'package:repit/shell/verlauf_zustand.dart';

/// Tests für den **Zustand** der Verlaufsseiten (#94) —
/// `lib/shell/verlauf_zustand.dart`. Die Oberfläche liegt in
/// `verlauf_view_test.dart`.
///
/// ## Festgelegte öffentliche API (`lib/shell/verlauf_zustand.dart`)
///
/// ```dart
/// /// Die vier Verläufe. **Ohne Alkohol:** Für eine Ja/Nein-Angabe gibt es
/// /// keine Kurve, und eine Eingabe dafür ist nicht gebaut.
/// enum VerlaufArt { schlaf, hrv, ruhepuls, atemfrequenz }
///
/// /// Höhere Werte sind besser — bestimmt, auf welcher Seite die
/// /// Signalschwelle liegt.
/// bool hoeherIstBesser(VerlaufArt art);
///
/// /// Schlaf wird als Balken gezeichnet, die übrigen drei als Linie.
/// bool alsBalken(VerlaufArt art);
///
/// /// Die Verlaufszeile des Erholung-Schirms → ihr Schirm. `null` für die
/// /// Alkohol-Zeile: Sie führt nirgendwohin.
/// VerlaufArt? verlaufArtZu(RecoveryTrendKind art);
///
/// /// Die Stufen dieses Schirms: **W M 6M J.**
/// const List<DiagrammStufe> verlaufsStufen = [...];
///
/// @immutable
/// class VerlaufDaten {
///   const VerlaufDaten({
///     required VerlaufArt art,
///     required List<({DateTime tag, double wert})> reihe,
///     required double? aktuell,
///     required double? median,
///     required double? signalAb,
///     required ({double von, double bis})? spanne,
///   });
///
///   /// Ob dieser Wert ein Warnsignal ist — **wortgleich mit der Ampel**.
///   bool istSignal(double wert);
/// }
///
/// @immutable
/// class VerlaufZustand {
///   const VerlaufZustand({
///     required VerlaufArt art,
///     required Messwert<VerlaufDaten> daten,
///   });
/// }
///
/// VerlaufZustand verlaufZustandAus({
///   required VerlaufArt art,
///   required ErholungZustand erholung,
/// });
///
/// final verlaufProvider = Provider.family<VerlaufZustand, VerlaufArt>(...);
/// ```
///
/// ## Warum dieser Schnitt
///
/// - **`VerlaufArt` ist ein eigenes Enum, nicht `RecoveryTrendKind`.** Der
///   Kern kennt fünf Verlaufszeilen, darunter die Alkohol-Zeile; die hat
///   keinen Schirm und keinen Messwert (`RecoveryTrend.average` ist dort
///   laut eigenem Vertrag immer `null`). Ein Schirm, der für sie
///   aufzurufen wäre, müsste zur Laufzeit ablehnen. Mit vier Fällen ist der
///   Fall unausdrückbar, und `verlaufArtZu` ist die **eine** Stelle, an der
///   die Zuordnung steht.
/// - **`istSignal` sitzt an den Daten, nicht an der Art.** Es braucht die
///   Schwelle, und die hängt am Median — also an den Daten. Eine Methode auf
///   dem Enum hätte sie erneut ausrechnen müssen, und zwei Rechnungen
///   derselben Schwelle driften.
/// - **`signalAb` ist eine Zahl, kein Satz.** Der Entwurf zeigt die Zeile
///   „Signal ab · unter 46 ms"; das „unter" gehört in die View, die Zahl in
///   den Zustand. Nutzertexte gehören nicht in die Rechnung.
///
/// ## Die eine Regel, die zwei der vier falsch herum haben
///
/// `higherIsBetter` (`TrendDetailView.swift:38–39`): Schlaf und HRV sind
/// besser, wenn sie höher sind, Ruhepuls und Atemfrequenz nicht. Eine
/// Einfärbung nach „unter der Linie ist rot" ist für zwei der vier falsch
/// herum. Und die Seite allein reicht nicht: Der Schlaf ist **strikt**
/// kleiner (`wert < 6`), die HRV **kleiner oder gleich**
/// (`wert <= median · 0,8`). Genau sechs Stunden sind kein Signal, genau
/// 80 % des Medians schon. Deshalb wird `istSignal` hier nicht gegen eine
/// eigene Formel geprüft, sondern **gegen `RecoveryTrafficLight` selbst**.
///
/// ## Am 02.11.2026 nachgezogen (#193, Stufe 4)
///
/// Ruhepuls, HRV und Atemfrequenz kommen seit Stufe 4 aus dem Nachtfenster
/// statt aus `DailyMetrics` — Tims Entscheidung vom 02.11.2026, begründet
/// im Kopf von `erholung_nachtwerte_test.dart`. Diese Datei prüft nicht,
/// **woher** die drei Werte kommen; sie braucht sie nur als Vorlage.
/// Deshalb setzt die Hülle den `RecoverySnapshot` seither selbst ein
/// (`schnappschussAus`), statt ihn über `DailyMetrics` erzeugen zu lassen.
/// Die **Zustandsart** kommt weiter aus `erholungZustandAus`.
///
/// **Was damit hier nicht mehr mitgeprüft wird:** dass die Werte dieses
/// Schirms tatsächlich durch `erholungZustandAus` hindurchlaufen. Das
/// prüft `erholung_nachtwerte_test.dart` — und zwar genauer, als es hier
/// je geschah.
///
/// ## Was hier bewusst **nicht** geprüft wird
///
/// - **Die vier Erklärsätze.** Sie sind Nutzertext und stehen in der View;
///   geprüft wird im View-Test, dass jede Art einen eigenen trägt.
/// - **Format und Einheit** („46 ms", „6:40 h"). Beschriftung, nicht Regel.
void main() {
  // Montag, 12.10.2026, 09:15 Berliner Zeit (CEST, +2).
  final jetzt = DateTime.utc(2026, 10, 12, 7, 15);

  DateTime tagesbeginn(int tag) =>
      BerlinCalendar.startOfDay(DateTime.utc(2026, 10, tag));

  String tagKey(int tag) => '2026-10-${tag.toString().padLeft(2, '0')}';

  DailyMetrics tagwert(
    int tag, {
    int? ruhepuls = 52,
    double? hrv = 60,
    double? atem = 13,
  }) => DailyMetrics(
    tag: tagKey(tag),
    restingHR: ruhepuls,
    hrvMs: hrv,
    respRate: atem,
    exerciseMinutes: 20,
  );

  SleepNight nachtVon(int tag, {double stunden = 7}) {
    final ende = DateTime.utc(2026, 10, tag, 4); // 06:00 Berlin
    final beginn = ende.subtract(Duration(minutes: (stunden * 60).round()));
    return SleepNight(
      date: tagesbeginn(tag),
      session: SleepSession(
        segments: [
          SleepSegment(stage: SleepStage.core, start: beginn, end: ende),
        ],
      ),
      naps: const [],
    );
  }

  List<DailyMetrics> tage({
    int? ruhepulsHeute = 52,
    double? hrvHeute = 60,
    double? atemHeute = 13,
  }) => [
    for (var t = 5; t <= 11; t++) tagwert(t),
    tagwert(12, ruhepuls: ruhepulsHeute, hrv: hrvHeute, atem: atemHeute),
  ];

  List<SleepNight> naechte({double heuteStunden = 7}) => [
    for (var t = 5; t <= 11; t++) nachtVon(t),
    nachtVon(12, stunden: heuteStunden),
  ];

  /// Der Schnappschuss aus den Vorlagen dieser Datei — **mit den drei
  /// Erholungswerten, die der Fall vorgibt.**
  ///
  /// Seit #193, Stufe 4 (02.11.2026) kommen Ruhepuls, HRV und Atemfrequenz
  /// aus dem Nachtfenster und nicht mehr aus `DailyMetrics`;
  /// `erholungZustandAus` nimmt sie als eigenen Parameter entgegen. Diese
  /// Datei prüft aber nicht, **woher** die drei Werte stammen — das prüft
  /// `erholung_nachtwerte_test.dart`. Hier sind sie nur Vorlage, und
  /// deshalb setzt die Hülle den Schnappschuss selbst ein, statt ihn über
  /// den Umweg über `DailyMetrics` zu erzeugen.
  RecoverySnapshot schnappschussAus(
    Messwert<List<DailyMetrics>> tageswerte,
    Messwert<List<SleepNight>> schlaf,
    Ziele ziele,
  ) {
    final tage = tageswerte is Bekannt<List<DailyMetrics>>
        ? tageswerte.wert
        : const <DailyMetrics>[];
    final naechte = schlaf is Bekannt<List<SleepNight>>
        ? schlaf.wert
        : const <SleepNight>[];
    return RecoverySnapshot.make(
      days: [
        for (final tag in tage)
          RecoveryDay(
            date: datumAusTag(tag.tag),
            restingHeartRate: tag.restingHR?.toDouble(),
            hrv: tag.hrvMs,
            respiratoryRate: tag.respRate,
            exerciseMinutes: tag.exerciseMinutes,
          ),
      ],
      nights: [for (final nacht in naechte) alsRecoveryNacht(nacht)],
      today: jetzt,
      sleepGoalHours: ziele.schlafzielMinuten / Duration.minutesPerHour,
      bedtimeGoalMinutes: EveningClock.minutesSinceEveningOfClock(
        hour: ziele.schlafenszeitMinuten ~/ Duration.minutesPerHour,
        minute: ziele.schlafenszeitMinuten % Duration.minutesPerHour,
      ),
      alcoholDays: AlcoholDays.from([
        for (final tag in tage)
          (date: datumAusTag(tag.tag), drinks: tag.alcoholicDrinks),
      ]),
      window: DataWindow(start: tagesbeginn(1)),
    );
  }

  /// Die Zustandsart kommt weiter aus `erholungZustandAus` — nur der
  /// Schnappschuss darin wird ersetzt (siehe [schnappschussAus]).
  ErholungZustand erholungAus({
    Messwert<List<DailyMetrics>>? tageswerte,
    Messwert<List<SleepNight>>? schlaf,
  }) {
    final tagesWert =
        tageswerte ??
        Bekannt<List<DailyMetrics>>(tage(), stand: jetzt, laeuft: false);
    final schlafWert =
        schlaf ??
        Bekannt<List<SleepNight>>(naechte(), stand: jetzt, laeuft: false);
    final roh = erholungZustandAus(
      tageswerte: tagesWert,
      naechte: schlafWert,
      ziele: Ziele.vorbelegung,
      fenster: DataWindow(start: tagesbeginn(1)),
      jetzt: jetzt,
    );
    final daten = roh.daten;
    if (daten is! Bekannt<ErholungDaten>) return roh;
    return ErholungZustand(
      daten: Bekannt<ErholungDaten>(
        ErholungDaten(
          schnappschuss: schnappschussAus(
            tagesWert,
            schlafWert,
            Ziele.vorbelegung,
          ),
          nacht: daten.wert.nacht,
          wochenminuten: daten.wert.wochenminuten,
        ),
        stand: daten.stand,
        laeuft: daten.laeuft,
      ),
      ziele: roh.ziele,
    );
  }

  VerlaufDaten daten(
    VerlaufArt art, {
    Messwert<List<DailyMetrics>>? tageswerte,
    Messwert<List<SleepNight>>? schlaf,
  }) {
    final zustand = verlaufZustandAus(
      art: art,
      erholung: erholungAus(tageswerte: tageswerte, schlaf: schlaf),
    );
    return (zustand.daten as Bekannt<VerlaufDaten>).wert;
  }

  // ─────────────────────────────────────────────────────────────────────

  group('Die vier Ausprägungen', () {
    test('alle vier sind erreichbar, Alkohol ist keine', () {
      expect(VerlaufArt.values, hasLength(4));
      expect(
        VerlaufArt.values,
        const [
          VerlaufArt.schlaf,
          VerlaufArt.hrv,
          VerlaufArt.ruhepuls,
          VerlaufArt.atemfrequenz,
        ],
        reason:
            'Die Abnahme nennt alle vier. Der Entwurf zeigt nur HRV, '
            'Ruhepuls und den leeren Zustand — das ist eine Lücke im '
            'Entwurf, kein Verzicht',
      );
    });

    test('die Verlaufszeilen des Erholung-Schirms finden ihren Schirm', () {
      expect(verlaufArtZu(RecoveryTrendKind.sleep), VerlaufArt.schlaf);
      expect(verlaufArtZu(RecoveryTrendKind.hrv), VerlaufArt.hrv);
      expect(
        verlaufArtZu(RecoveryTrendKind.restingHeartRate),
        VerlaufArt.ruhepuls,
      );
      expect(
        verlaufArtZu(RecoveryTrendKind.respiratoryRate),
        VerlaufArt.atemfrequenz,
      );
    });

    test('die Alkohol-Zeile führt nirgendwohin', () {
      expect(
        verlaufArtZu(RecoveryTrendKind.alcoholDays),
        isNull,
        reason:
            'Ein Zähler über etwas, das niemand eintragen kann, wäre eine '
            'Behauptung — und ein Diagramm darüber erst recht '
            '(`erholung_view_test.dart`: weder Winkel noch Ziel)',
      );
    });
  });

  group('Höher ist besser — bei zweien, nicht bei allen', () {
    test('Schlaf und HRV sind besser, wenn sie höher sind', () {
      expect(hoeherIstBesser(VerlaufArt.schlaf), isTrue);
      expect(hoeherIstBesser(VerlaufArt.hrv), isTrue);
    });

    test('Ruhepuls und Atemfrequenz nicht', () {
      expect(hoeherIstBesser(VerlaufArt.ruhepuls), isFalse);
      expect(hoeherIstBesser(VerlaufArt.atemfrequenz), isFalse);
    });
  });

  group('Balken oder Linie', () {
    test('Schlaf als Balken, die übrigen drei als Linie', () {
      expect(alsBalken(VerlaufArt.schlaf), isTrue);
      for (final art in const [
        VerlaufArt.hrv,
        VerlaufArt.ruhepuls,
        VerlaufArt.atemfrequenz,
      ]) {
        expect(alsBalken(art), isFalse, reason: '$art');
      }
    });
  });

  group('Die Stufen', () {
    test('W M 6M J — anders als bei der Belastung mit J', () {
      expect(verlaufsStufen, const [
        DiagrammStufe.woche,
        DiagrammStufe.monat,
        DiagrammStufe.halbjahr,
        DiagrammStufe.jahr,
      ]);
    });

    test('und die Startstufe ist damit W (#7)', () {
      expect(startStufe(verlaufsStufen), DiagrammStufe.woche);
    });
  });

  group('Die Schwelle liegt bei allen vier auf der richtigen Seite', () {
    test('Schlaf: fest bei sechs Stunden, auch ohne Median', () {
      expect(
        daten(VerlaufArt.schlaf).signalAb,
        RecoveryTrafficLight.minimumSleepHours,
      );

      // Eine einzige Nacht: kein Median, aber die Schwelle steht trotzdem.
      final eine = daten(
        VerlaufArt.schlaf,
        schlaf: Bekannt<List<SleepNight>>(
          [nachtVon(12)],
          stand: jetzt,
          laeuft: false,
        ),
      );
      expect(eine.median, isNull);
      expect(
        eine.signalAb,
        RecoveryTrafficLight.minimumSleepHours,
        reason:
            'Die Sechs-Stunden-Grenze steht fest (`docs/SPEC.md` 4.6) und '
            'hängt nicht am Median — und auch nicht am Schlafziel',
      );
    });

    test('HRV: der Median mal 0,8 — darunter ist schlechter', () {
      final hrv = daten(VerlaufArt.hrv);
      expect(hrv.median, 60);
      expect(hrv.signalAb, closeTo(60 * RecoveryTrafficLight.hrvFactor, 1e-9));
    });

    test('Ruhepuls: der Median plus 5 — darüber ist schlechter', () {
      final puls = daten(VerlaufArt.ruhepuls);
      expect(puls.median, 52);
      expect(
        puls.signalAb,
        closeTo(52 + RecoveryTrafficLight.restingHeartRateMargin, 1e-9),
      );
    });

    test('Atemfrequenz: der Median plus 1,5', () {
      final atem = daten(VerlaufArt.atemfrequenz);
      expect(atem.median, 13);
      expect(
        atem.signalAb,
        closeTo(13 + RecoveryTrafficLight.respiratoryRateMargin, 1e-9),
      );
    });

    test('ohne Median keine Schwelle — bei den drei, die daran hängen', () {
      // Zwei Tage reichen `HealthMedian` nicht (mindestens fünf nötig).
      final duenn = Bekannt<List<DailyMetrics>>(
        [tagwert(11), tagwert(12)],
        stand: jetzt,
        laeuft: false,
      );
      for (final art in const [
        VerlaufArt.hrv,
        VerlaufArt.ruhepuls,
        VerlaufArt.atemfrequenz,
      ]) {
        final ohne = daten(art, tageswerte: duenn);
        expect(ohne.median, isNull, reason: '$art');
        expect(
          ohne.signalAb,
          isNull,
          reason:
              '$art: eine erfundene Schwelle wäre schlimmer als gar keine',
        );
      }
    });

    test(
      '`istSignal` sagt wortgleich dasselbe wie die Ampel — auch genau auf '
      'der Schwelle',
      () {
        // Für jede Art: ein Wert exakt auf der Schwelle und einer knapp
        // daneben. Die Erwartung kommt aus `RecoveryTrafficLight` selbst,
        // nicht aus einer zweiten Formel hier.
        final baseline = daten(VerlaufArt.hrv);
        final schwelleHrv = baseline.signalAb!;

        bool ampelSagtHrv(double wert) => RecoveryTrafficLight.evaluate(
          reading: RecoveryReading(hrv: wert),
          baseline: const RecoveryBaseline(hrv: 60),
        ).signals.contains(RecoveryMetric.hrv);

        for (final wert in [schwelleHrv, schwelleHrv - 1, schwelleHrv + 1]) {
          expect(
            baseline.istSignal(wert),
            ampelSagtHrv(wert),
            reason:
                'HRV bei $wert: Rot in der Kurve und Warnsignal im '
                'Hinweiskasten müssen dasselbe heißen',
          );
        }

        // Schlaf ist **strikt** kleiner: genau sechs Stunden sind kein
        // Signal. Die HRV ist es bei Gleichheit schon — die Seite allein
        // genügt nicht.
        final schlaf = daten(VerlaufArt.schlaf);
        expect(
          schlaf.istSignal(RecoveryTrafficLight.minimumSleepHours),
          isFalse,
        );
        expect(
          schlaf.istSignal(RecoveryTrafficLight.minimumSleepHours - 0.01),
          isTrue,
        );
        expect(
          baseline.istSignal(schwelleHrv),
          isTrue,
          reason: 'HRV: `wert <= median · 0,8` — Gleichheit ist ein Signal',
        );

        // Und die beiden, bei denen größer schlechter ist.
        final puls = daten(VerlaufArt.ruhepuls);
        expect(puls.istSignal(puls.signalAb!), isTrue);
        expect(puls.istSignal(puls.signalAb! - 0.01), isFalse);

        final atem = daten(VerlaufArt.atemfrequenz);
        expect(atem.istSignal(atem.signalAb!), isTrue);
        expect(atem.istSignal(atem.signalAb! - 0.01), isFalse);
      },
    );

    test('ohne Schwelle ist nichts ein Signal', () {
      final ohne = daten(
        VerlaufArt.hrv,
        tageswerte: Bekannt<List<DailyMetrics>>(
          [tagwert(12)],
          stand: jetzt,
          laeuft: false,
        ),
      );
      expect(ohne.signalAb, isNull);
      expect(
        ohne.istSignal(1),
        isFalse,
        reason:
            'Ohne Vergleichswert gibt es kein Signal — nicht „alles ist '
            'rot" und nicht „alles ist grün mit Begründung"',
      );
    });
  });

  group('Die Reihe', () {
    test('HRV, Ruhepuls und Atemfrequenz kommen aus den Tagen', () {
      final hrv = daten(VerlaufArt.hrv);
      expect(hrv.reihe, hasLength(8));
      expect(hrv.reihe.first.tag, tagesbeginn(5));
      expect(hrv.reihe.last.tag, tagesbeginn(12));
      expect(hrv.reihe.last.wert, 60);
    });

    test('der Schlaf kommt aus den Nächten, in Stunden', () {
      final schlaf = daten(VerlaufArt.schlaf);
      expect(schlaf.reihe, hasLength(8));
      expect(schlaf.reihe.last.wert, closeTo(7, 1e-9));
    });

    test('ein Tag ohne diesen Wert fehlt — Lücken bleiben Lücken', () {
      final reihe = daten(
        VerlaufArt.hrv,
        tageswerte: Bekannt<List<DailyMetrics>>(
          tage(hrvHeute: null),
          stand: jetzt,
          laeuft: false,
        ),
      ).reihe;
      expect(reihe, hasLength(7));
      expect(reihe.map((p) => p.tag).contains(tagesbeginn(12)), isFalse);
    });

    test(
      'ein fehlender Wert zieht die anderen Reihen nicht mit herunter',
      () {
        final ohneHrv = Bekannt<List<DailyMetrics>>(
          tage(hrvHeute: null),
          stand: jetzt,
          laeuft: false,
        );
        expect(
          daten(VerlaufArt.ruhepuls, tageswerte: ohneHrv).reihe,
          hasLength(8),
          reason:
              'Ein fehlender Median schaltet nur seine eigene Metrik ab, '
              'nicht die anderen — dasselbe gilt für eine fehlende Messung',
        );
      },
    );

    test('ganz ohne Werte bleibt die Reihe leer, statt zu werfen', () {
      final leer = daten(
        VerlaufArt.hrv,
        tageswerte: Bekannt<List<DailyMetrics>>(
          [tagwert(12, hrv: null)],
          stand: jetzt,
          laeuft: false,
        ),
      );
      expect(leer.reihe, isEmpty);
      expect(leer.aktuell, isNull);
      expect(leer.spanne, isNull);
    });
  });

  group('Die Einordnung', () {
    test('„Aktuell" ist der jüngste Wert der Reihe, nicht der Schnitt', () {
      final hrv = daten(
        VerlaufArt.hrv,
        tageswerte: Bekannt<List<DailyMetrics>>(
          tage(hrvHeute: 44),
          stand: jetzt,
          laeuft: false,
        ),
      );
      expect(
        hrv.aktuell,
        44,
        reason:
            'Die Kopfzeile zeigt den Fensterschnitt, der aktuelle Wert steht '
            'als eigene Zeile darunter (`TrendDetailView.swift:100–103`)',
      );
    });

    test('„Median 30 Tage" ist der Median **ohne** heute', () {
      final hrv = daten(
        VerlaufArt.hrv,
        tageswerte: Bekannt<List<DailyMetrics>>(
          tage(hrvHeute: 10),
          stand: jetzt,
          laeuft: false,
        ),
      );
      expect(
        hrv.median,
        60,
        reason:
            'Der heutige Wert gehört nicht in seinen eigenen Median — sonst '
            'zieht ein Ausreißer seine eigene Schwelle mit sich '
            '(`RecoverySnapshot`, Regel 1)',
      );
    });

    test('„Spanne 7 Tage" ist Kleinster und Größter der letzten sieben', () {
      // Acht Tage: der älteste (05.10.) trägt den Ausreißer und darf
      // deshalb nicht in der Spanne stehen.
      final hrv = daten(
        VerlaufArt.hrv,
        tageswerte: Bekannt<List<DailyMetrics>>(
          [
            tagwert(5, hrv: 200),
            for (var t = 6; t <= 11; t++) tagwert(t, hrv: 60),
            tagwert(12, hrv: 44),
          ],
          stand: jetzt,
          laeuft: false,
        ),
      );
      expect(hrv.spanne, isNotNull);
      expect(hrv.spanne!.von, 44);
      expect(
        hrv.spanne!.bis,
        60,
        reason:
            'Der Ausreißer von 200 liegt acht Tage zurück und gehört nicht '
            'in eine Spanne, die „7 Tage" heißt',
      );
    });

    test('ein einziger Wert gibt eine Spanne von sich zu sich', () {
      final hrv = daten(
        VerlaufArt.hrv,
        tageswerte: Bekannt<List<DailyMetrics>>(
          [tagwert(12, hrv: 44)],
          stand: jetzt,
          laeuft: false,
        ),
      );
      expect(hrv.spanne, isNotNull);
      expect(hrv.spanne!.von, 44);
      expect(hrv.spanne!.bis, 44);
    });
  });

  group('Die vier Messwert-Zustände reicht der Schirm durch', () {
    for (final art in VerlaufArt.values) {
      test('$art: noch nie etwas gesehen', () {
        final zustand = verlaufZustandAus(
          art: art,
          erholung: erholungAus(
            tageswerte: const NochNie<List<DailyMetrics>>(),
            schlaf: const NochNie<List<SleepNight>>(),
          ),
        );
        expect(zustand.art, art);
        expect(zustand.daten, isA<NochNie<VerlaufDaten>>());
      });
    }

    test('ein fertiger Lauf ohne Treffer', () {
      final zustand = verlaufZustandAus(
        art: VerlaufArt.hrv,
        erholung: erholungAus(
          tageswerte: LeerNachLauf<List<DailyMetrics>>(gelaufen: jetzt),
          schlaf: LeerNachLauf<List<SleepNight>>(gelaufen: jetzt),
        ),
      );
      expect(zustand.daten, isA<LeerNachLauf<VerlaufDaten>>());
    });

    test('ein gescheiterter Lauf ohne Cache', () {
      final zustand = verlaufZustandAus(
        art: VerlaufArt.hrv,
        erholung: erholungAus(
          tageswerte: Fehlgeschlagen<List<DailyMetrics>>(
            fehler: 'kaputt',
            gelaufen: jetzt,
          ),
          schlaf: Fehlgeschlagen<List<SleepNight>>(
            fehler: 'kaputt',
            gelaufen: jetzt,
          ),
        ),
      );
      expect(zustand.daten, isA<Fehlgeschlagen<VerlaufDaten>>());
    });

    test(
      'eine leere Reihe ist **kein** Leerzustand, sondern ein bekannter Wert',
      () {
        final zustand = verlaufZustandAus(
          art: VerlaufArt.hrv,
          erholung: erholungAus(
            tageswerte: Bekannt<List<DailyMetrics>>(
              [tagwert(12, hrv: null)],
              stand: jetzt,
              laeuft: false,
            ),
          ),
        );
        expect(
          zustand.daten,
          isA<Bekannt<VerlaufDaten>>(),
          reason:
              'Der Lauf hat etwas geliefert, nur für diesen einen Wert '
              'nichts. Als `LeerNachLauf` zu melden hieße, über den ganzen '
              'Lauf etwas zu behaupten, was nicht stimmt — und der Satz '
              '„keine Werte" hängt an der leeren Reihe, nicht am Zustand',
        );
      },
    );
  });

  group('Der Provider', () {
    /// Die Nachtwerte der Provider-Hülle — sie **spiegeln** die Tageswerte
    /// (#193, Stufe 4). Die Quelle wechselt, die Vorlage nicht.
    Messwert<Map<String, NightVitals>> nachtwerteAus(
      Messwert<List<DailyMetrics>> tageswerte,
    ) => switch (tageswerte) {
      Bekannt<List<DailyMetrics>>(:final wert, :final stand, :final laeuft) =>
        Bekannt<Map<String, NightVitals>>({
          for (final tag in wert)
            tag.tag: NightVitals(
              restingHeartRate: tag.restingHR?.toDouble(),
              hrv: tag.hrvMs,
              respiratoryRate: tag.respRate,
            ),
        }, stand: stand, laeuft: laeuft),
      NochNie<List<DailyMetrics>>() =>
        const NochNie<Map<String, NightVitals>>(),
      LeerNachLauf<List<DailyMetrics>>(:final gelaufen) =>
        LeerNachLauf<Map<String, NightVitals>>(gelaufen: gelaufen),
      Fehlgeschlagen<List<DailyMetrics>>(:final fehler, :final gelaufen) =>
        Fehlgeschlagen<Map<String, NightVitals>>(
          fehler: fehler,
          gelaufen: gelaufen,
        ),
    };

    ProviderContainer behaelter() {
      // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          clockProvider.overrideWithValue(() => jetzt),
          dailyMetricsProvider.overrideWith(
            () => _Tageswerte(
              Bekannt<List<DailyMetrics>>(tage(), stand: jetzt, laeuft: false),
            ),
          ),
          sleepProvider.overrideWith(
            () => _Naechte(
              Bekannt<List<SleepNight>>(naechte(), stand: jetzt, laeuft: false),
            ),
          ),
          // #193, Stufe 4: `erholungProvider` beobachtet seit der
          // Umstellung auch die Nachtwerte.
          nachtWerteProvider.overrideWith(
            () => _Nachtwerte(
              nachtwerteAus(
                Bekannt<List<DailyMetrics>>(
                  tage(),
                  stand: jetzt,
                  laeuft: false,
                ),
              ),
            ),
          ),
          zieleProvider.overrideWith(() => _Ziele(Ziele.vorbelegung)),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('liefert je Art einen eigenen Zustand', () async {
      final container = behaelter();
      await container.read(dailyMetricsProvider.future);
      await container.read(sleepProvider.future);

      for (final art in VerlaufArt.values) {
        expect(container.read(verlaufProvider(art)).art, art);
      }
      expect(
        container.read(verlaufProvider(VerlaufArt.hrv)).art,
        isNot(container.read(verlaufProvider(VerlaufArt.ruhepuls)).art),
      );
    });

    test('hält seinen Zustand, statt ihn bei jedem Zugriff zu rechnen', () async {
      final container = behaelter();
      await container.read(dailyMetricsProvider.future);
      await container.read(sleepProvider.future);

      expect(
        identical(
          container.read(verlaufProvider(VerlaufArt.hrv)),
          container.read(verlaufProvider(VerlaufArt.hrv)),
        ),
        isTrue,
        reason: 'Hausregel 2 — das war `docs/todo/03`',
      );
    });
  });
}

/// Steuerbare Ableger der echten Notifier — siehe `erholung_view_test.dart`.
class _Tageswerte extends DailyMetricsNotifier {
  _Tageswerte(this.wert);

  final Messwert<List<DailyMetrics>> wert;

  @override
  Future<Messwert<List<DailyMetrics>>> build() async => wert;
}

class _Naechte extends SleepNotifier {
  _Naechte(this.wert);

  final Messwert<List<SleepNight>> wert;

  @override
  Future<Messwert<List<SleepNight>>> build() async => wert;
}

class _Ziele extends ZieleNotifier {
  _Ziele(this.wert);

  final Ziele wert;

  @override
  Future<Ziele> build() async => wert;
}

class _Nachtwerte extends NachtWerteNotifier {
  _Nachtwerte(this.wert);

  final Messwert<Map<String, NightVitals>> wert;

  @override
  Future<Messwert<Map<String, NightVitals>>> build() async => wert;
}
