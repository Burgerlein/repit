import 'dart:io';

import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für die **Ampel** aus Ticket #109 — Spec
/// `docs/superpowers/specs/2026-10-26-erholung-flutter-design.md` Abschnitt 6
/// und `docs/SPEC.md` 4.6. Vorlage ist
/// `Packages/TrainingsCore/Sources/TrainingsCore/Body/RecoveryTrafficLight.swift`,
/// die Zustände und die Reihenfolge werden von dort übernommen.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Zum Zeitpunkt dieser Datei gibt es die Typen in `lib/` nicht; der Lauf ist
/// rot, und das ist der erwartete Zustand. Diese Datei darf ausgeführt, nie
/// verändert werden.
///
/// ## API, die diese Tests verbindlich vorgeben
///
/// Importiert wird das **Barrel** `package:trainings_core/trainings_core.dart`,
/// nicht eine Datei unter `lib/src/`. Anders als `berlin_calendar_test.dart`
/// und `data_window_test.dart`, die je eine einzelne Datei des Auftrags
/// benannten, legt dieses Ticket eine **Schnittstelle** fest und keinen
/// Dateinamen: Wie die Umsetzung ihre Dateien schneidet, ist ihre Sache —
/// erreichbar sein muss alles über das Barrel, weil die Views es von dort
/// lesen.
///
/// ```dart
/// /// Die vier Messwerte einer Nacht. `null` heißt „kein Wert" — ob nichts
/// /// aufgezeichnet wurde oder der Lesezugriff fehlt, verrät HealthKit nicht.
/// class RecoveryReading {
///   const RecoveryReading({double? sleepHours, double? restingHeartRate,
///                          double? hrv, double? respiratoryRate});
///   final double? sleepHours, restingHeartRate, hrv, respiratoryRate;
///   // Wertgleichheit: == und hashCode über alle vier Felder.
/// }
///
/// /// Der eigene Normalbereich: Mediane über das Fenster.
/// class RecoveryBaseline {
///   const RecoveryBaseline({double? sleepHours, double? restingHeartRate,
///                           double? hrv, double? respiratoryRate});
///   factory RecoveryBaseline.from({
///     required List<RecoveryDay> days,
///     required List<double> sleepHours,
///     int window = HealthMedian.defaultWindow,
///     int minimumSamples = HealthMedian.defaultMinimumSamples,
///   });
///   final double? sleepHours, restingHeartRate, hrv, respiratoryRate;
///   // Wertgleichheit.
/// }
///
/// enum RecoveryMetric { sleep, restingHeartRate, hrv, respiratoryRate }
/// enum RecoveryVerdict { calm, watch, stressed, noData, postOperative }
///
/// class RecoveryEvaluation {
///   const RecoveryEvaluation({required RecoveryVerdict verdict,
///                             required List<RecoveryMetric> signals,
///                             required int measuredCount,
///                             List<RecoveryMetric> rated = const []});
///   final RecoveryVerdict verdict;
///   final List<RecoveryMetric> signals;   // immer in Vertragsreihenfolge
///   final int measuredCount;              // vor allen Abkürzungen gezählt
///   final List<RecoveryMetric> rated;     // seit #261, siehe unten
///   // Wertgleichheit, `signals` und `rated` elementweise.
/// }
///
/// abstract final class RecoveryTrafficLight {
///   static const double minimumSleepHours = 6.0;
///   static const double restingHeartRateMargin = 5.0;
///   static const double hrvFactor = 0.8;
///   static const double respiratoryRateMargin = 1.5;
///   static RecoveryEvaluation evaluate({
///     required RecoveryReading reading,
///     required RecoveryBaseline baseline,
///     bool isPostOperative = false,
///   });
/// }
/// ```
///
/// ### Warum `hrvFactor = 0.8` und nicht `hrvDropShare = 0.2`
///
/// Swift schreibt `0.2` und rechnet `median * (1 - hrvDropShare)`. Spec und
/// `docs/SPEC.md` 4.6 sagen „HRV ≤ Median · 0,8". Die Konstante trägt deshalb
/// genau die Zahl, die in der Spec steht — eine Umrechnung im Kopf ist eine
/// Stelle, an der sich jemand irren kann, und die Views beschriften damit.
///
/// ### Warum die Schwellen aus der Konstante **abgeleitet** erwartet werden
///
/// Die Grenzfälle unten rechnen ihren Erwartungswert aus
/// `RecoveryTrafficLight.hrvFactor` statt aus einer vorgerechneten `48.0`.
/// Genau das fehlt in Swift: Dort stehen die Schwellen dreifach im Quelltext
/// — einmal als Wahrheit, zweimal als Beschriftung — und **kein Test bindet
/// sie aneinander**. Wer hier die Konstante ändert, verschiebt die Erwartung
/// mit; wer nur die Rechnung in `evaluate` ändert, fliegt auf.
///
/// ### Nachzug vom 03.11.2026: `rated` (#261, Stufe 1)
///
/// `RecoveryEvaluation` hat seit #261 ein viertes Feld, `rated` — die
/// Metriken, über die die Ampel überhaupt eine Aussage gemacht hat. Es
/// entstand, weil `HealthMedian` unter fünf Werten keinen Median bildet:
/// Für die ältesten Tage des Rechenfensters gibt es deshalb gar keinen, und
/// ohne `rated` meldete die Ampel dort null Signale und der Ring malte vier
/// grüne Viertel — „alles im Normalbereich", eine Aussage, die niemand
/// gemacht hat. `evaluate` füllt `rated` immer; `==`, `hashCode` und
/// `toString` ziehen mit. Die Fälle dazu stehen in
/// `recovery_traffic_light_rated_test.dart`.
///
/// **Was das an dieser Datei geändert hat — und was nicht.** Der einzige
/// Fall hier, der ein `evaluate`-Ergebnis mit einem von Hand gebauten
/// `RecoveryEvaluation` vergleicht („zwei gleiche `RecoveryEvaluation` sind
/// gleich"), nennt jetzt `rated` mit allen vier Metriken, weil die Fixture
/// `unauffaellig` vier Werte und `baseline` vier Mediane trägt. **Die
/// Aussage des Falls ist dieselbe geblieben**: Zwei gleiche Auswertungen
/// sind gleich. Ohne die Ergänzung verglich er ein vollständig gefülltes
/// Ergebnis mit einem Literal, das beim Vorgabewert `const []` stehen
/// blieb — er prüfte dann nicht mehr die Wertgleichheit, sondern eine
/// Lücke. Beides zugleich grün zu bekommen ginge nur mit einem `==`, das
/// eine leere `rated`-Liste als Joker behandelt; das wäre nicht transitiv
/// und bräche den `hashCode`-Vertrag. Kein anderer Erwartungswert dieser
/// Datei ist angefasst, und ein zweites `RecoveryEvaluation`-Literal gibt
/// es hier nicht.
///
/// Dass der Nachzug nötig war, stand **nicht** in der Spec: Ihre Tabelle
/// „Bestehende Tests, die diese Arbeit bricht"
/// (`docs/superpowers/specs/2026-11-03-erholung-tageswechsel.md`) nennt
/// diese Datei nicht. Gefunden hat es der Implementierende von Stufe 1 und
/// **gemeldet statt korrigiert**, wie `CLAUDE.md` es verlangt; geändert hat
/// es der Test-Agent.
///
/// ### Keine Nutzertexte
///
/// `RecoveryVerdict` ist ein Enum, kein deutscher Satz. `trainings_core`
/// kennt keine Oberflächenbeschriftung (`CLAUDE.md`, Spec Abschnitt 6).
///
/// **Alle Zahlen hier sind erfunden** und tragen bewusst runde, unplausible
/// Werte. Keine echten Gesundheitsdaten, auch nicht „nur als Beispiel".
void main() {
  // Erfundene Mediane. Rund und glatt, damit sofort sichtbar ist, dass sie
  // aus keinem Export stammen.
  const medianPuls = 50.0;
  const medianHrv = 60.0;
  const medianAtem = 14.0;

  const baseline = RecoveryBaseline(
    sleepHours: 7.0,
    restingHeartRate: medianPuls,
    hrv: medianHrv,
    respiratoryRate: medianAtem,
  );

  /// Eine Nacht, in der kein Wert auffällig ist — Ausgangspunkt für alle
  /// Einzelfälle, damit jeder Test genau eine Sache verändert.
  const unauffaellig = RecoveryReading(
    sleepHours: 8.0,
    restingHeartRate: medianPuls,
    hrv: medianHrv,
    respiratoryRate: medianAtem,
  );

  RecoveryEvaluation pruefe(
    RecoveryReading reading, {
    RecoveryBaseline basis = baseline,
    bool nachOp = false,
  }) => RecoveryTrafficLight.evaluate(
    reading: reading,
    baseline: basis,
    isPostOperative: nachOp,
  );

  group('Die Schwellen stehen an genau einer Stelle', () {
    test('die vier Konstanten tragen die Zahlen aus docs/SPEC.md 4.6', () {
      expect(RecoveryTrafficLight.minimumSleepHours, 6.0);
      expect(RecoveryTrafficLight.restingHeartRateMargin, 5.0);
      expect(RecoveryTrafficLight.hrvFactor, 0.8);
      expect(RecoveryTrafficLight.respiratoryRateMargin, 1.5);
    });

    test('0,8 und 1,5 stehen höchstens einmal in der Erholungs-Rechnung', () {
      // Der Fehler, gegen den dieses Ticket gebaut ist: In Swift steht jede
      // Schwelle dreifach. Der Wächter ist bewusst nachsichtig ("höchstens
      // einmal", nicht "genau einmal") — wer `0.80` schreibt oder die
      // Konstante anders herleitet, soll nicht scheitern. Er schlägt nur bei
      // der Krankheit an, die er behandeln soll: derselben Zahl an mehreren
      // Stellen.
      //
      // ## Reichweite: die Erholungsdateien, nicht ganz `lib/` (04.11.2026)
      //
      // Bis zum Ernährungskern las dieser Fall **jede** Datei unter `lib/`
      // als einen Text. Das trug, solange `lib/` im Wesentlichen die
      // Erholung kannte. Mit `makroziele.dart` steht dort jetzt
      // `_fettJeKgMin = 0.8` — das Fettziel aus `docs/SPEC.md` 4.8
      // ("Fett ≥ 0,8 g/kg"). Das ist keine zweite HRV-Schwelle, sondern die
      // einzige Stelle einer eigenen Schwelle eines eigenen Fachgebiets, die
      // zufällig dieselbe Ziffernfolge trägt. `lib/` ist über das Revier des
      // Wächters hinausgewachsen.
      //
      // Ein Wächter, der daran scheitert, zwingt fremde Fachgebiete zu
      // Umschreibungen wie `0.80`, die es nur gäbe, um an einem Grep
      // vorbeizukommen — eine Verschlechterung des Quelltexts zugunsten
      // eines Tests. Darum zählt er ab hier nur dort, wo die Krankheit lebt:
      // in den Dateien der Erholungs-Rechnung. Der Schutz, auf den es
      // ankommt, bleibt — ein nach `recovery_snapshot.dart` kopierter
      // `hrvFactor` fällt weiter auf —, und der Wächter ist immun gegen
      // jedes Fachgebiet, das später dazukommt. Wächst die Erholung um eine
      // Datei, trägt sie das Präfix und ist von selbst mit drin.
      //
      // `night_vitals.dart` steht ausdrücklich mit im Revier: Dort entstehen
      // genau die drei Nachtwerte (Ruhepuls, HRV, Atemfrequenz), gegen die
      // die Schwellen prüfen — eine kopierte Schwelle landete am ehesten
      // dort.
      //
      // Die Vor- und Nachschau verhindert, dass `0.85` (Schwelle der
      // Schlafbewertung, Ticket #110) als Treffer für `0.8` zählt.
      final lib = Directory('lib');
      if (!lib.existsSync()) return;

      String dateiname(File datei) =>
          datei.path.split(Platform.pathSeparator).last;

      bool gehoertZurErholung(File datei) {
        final name = dateiname(datei);
        return name.startsWith('recovery_') || name == 'night_vitals.dart';
      }

      final dateien = lib
          .listSync(recursive: true)
          .whereType<File>()
          .where((datei) => datei.path.endsWith('.dart'))
          .where(gehoertZurErholung)
          .toList();

      // Ein Wächter, dessen Revier leer läuft, ist still grün — und still
      // grün ist schlimmer als rot. Wird `recovery_traffic_light.dart`
      // umbenannt oder aufgeteilt, scheitert dieser Fall hier und nicht
      // erst, wenn die Schwelle längst doppelt steht.
      expect(
        dateien.map(dateiname),
        contains('recovery_traffic_light.dart'),
        reason: 'Das Revier des Wächters muss die Datei der Schwellen führen',
      );

      final quelltext = dateien
          .map((datei) => datei.readAsStringSync())
          .join('\n');

      int zaehle(String zahl) => RegExp(
        r'(?<![\d.])' + RegExp.escape(zahl) + r'(?![\d])',
      ).allMatches(quelltext).length;

      expect(
        zaehle('0.8'),
        lessThanOrEqualTo(1),
        reason: 'Die HRV-Schwelle gehört in genau eine Konstante',
      );
      expect(
        zaehle('1.5'),
        lessThanOrEqualTo(1),
        reason: 'Die Atemfrequenz-Schwelle gehört in genau eine Konstante',
      );
    });
  });

  group('Die Reihenfolge der vier Metriken ist Vertrag', () {
    // Die vier Viertel des Erholungsrings (#114) werden in dieser Reihenfolge
    // gezeichnet. Wer sie umsortiert, färbt im Ring das falsche Viertel ein,
    // und kein Schirm-Test würde das merken — es gibt keine UI-Tests.
    test('RecoveryMetric.values: Schlaf, Ruhepuls, HRV, Atemfrequenz', () {
      expect(RecoveryMetric.values, [
        RecoveryMetric.sleep,
        RecoveryMetric.restingHeartRate,
        RecoveryMetric.hrv,
        RecoveryMetric.respiratoryRate,
      ]);
    });

    test('signals kommt in derselben Reihenfolge, wenn alles anschlägt', () {
      final auswertung = pruefe(
        const RecoveryReading(
          sleepHours: 4.0,
          restingHeartRate: medianPuls + 20,
          hrv: 10.0,
          respiratoryRate: medianAtem + 5,
        ),
      );

      expect(auswertung.signals, [
        RecoveryMetric.sleep,
        RecoveryMetric.restingHeartRate,
        RecoveryMetric.hrv,
        RecoveryMetric.respiratoryRate,
      ]);
      expect(auswertung.verdict, RecoveryVerdict.stressed);
      expect(auswertung.measuredCount, 4);
    });

    test('signals bleibt sortiert, wenn nur Ruhepuls und Atmung anschlagen',
        () {
      final auswertung = pruefe(
        const RecoveryReading(
          sleepHours: 8.0,
          restingHeartRate: medianPuls + 20,
          hrv: medianHrv,
          respiratoryRate: medianAtem + 5,
        ),
      );

      expect(auswertung.signals, [
        RecoveryMetric.restingHeartRate,
        RecoveryMetric.respiratoryRate,
      ]);
    });
  });

  group('Schlaf: fest unter 6 h, strikt kleiner, ohne Median', () {
    test('genau 6 h ist kein Signal', () {
      final reading = RecoveryReading(
        sleepHours: RecoveryTrafficLight.minimumSleepHours,
        restingHeartRate: medianPuls,
        hrv: medianHrv,
        respiratoryRate: medianAtem,
      );
      expect(pruefe(reading).signals, isEmpty);
    });

    test('knapp unter 6 h ist ein Signal', () {
      final reading = RecoveryReading(
        sleepHours: RecoveryTrafficLight.minimumSleepHours - 0.01,
        restingHeartRate: medianPuls,
        hrv: medianHrv,
        respiratoryRate: medianAtem,
      );
      expect(pruefe(reading).signals, [RecoveryMetric.sleep]);
    });

    test('deutlich unter 6 h ist ein Signal', () {
      expect(
        pruefe(const RecoveryReading(sleepHours: 3.0)).signals,
        [RecoveryMetric.sleep],
      );
    });

    test('viel Schlaf ist nie ein Signal', () {
      // Die Schwelle ist einseitig. Zwölf Stunden sind kein Warnzeichen,
      // auch nicht gegen einen niedrigen Median.
      final auswertung = pruefe(
        const RecoveryReading(sleepHours: 12.0),
        basis: const RecoveryBaseline(sleepHours: 5.0),
      );
      expect(auswertung.signals, isEmpty);
      expect(auswertung.verdict, RecoveryVerdict.calm);
    });

    test('Schlaf schlägt auch ohne Median an — die Schwelle ist fest', () {
      final auswertung = pruefe(
        const RecoveryReading(sleepHours: 4.0),
        basis: const RecoveryBaseline(),
      );
      expect(auswertung.signals, [RecoveryMetric.sleep]);
    });

    test('die Schlafschwelle hängt nicht am Schlafziel im Median', () {
      // Ein Median von 9 h macht 6,5 h nicht zum Signal: die Schwelle ist
      // fest und unabhängig vom Schlafziel (Spec Abschnitt 6).
      final auswertung = pruefe(
        const RecoveryReading(sleepHours: 6.5),
        basis: const RecoveryBaseline(sleepHours: 9.0),
      );
      expect(auswertung.signals, isEmpty);
    });
  });

  group('Ruhepuls: >= Median + Zuschlag, Gleichheit ist Signal', () {
    test('knapp unter der Schwelle ist kein Signal', () {
      final reading = RecoveryReading(
        sleepHours: 8.0,
        restingHeartRate:
            medianPuls + RecoveryTrafficLight.restingHeartRateMargin - 0.1,
        hrv: medianHrv,
        respiratoryRate: medianAtem,
      );
      expect(pruefe(reading).signals, isEmpty);
    });

    test('genau auf der Schwelle ist ein Signal', () {
      final reading = RecoveryReading(
        sleepHours: 8.0,
        restingHeartRate:
            medianPuls + RecoveryTrafficLight.restingHeartRateMargin,
        hrv: medianHrv,
        respiratoryRate: medianAtem,
      );
      expect(pruefe(reading).signals, [RecoveryMetric.restingHeartRate]);
    });

    test('deutlich darüber ist ein Signal', () {
      final reading = RecoveryReading(
        sleepHours: 8.0,
        restingHeartRate: medianPuls + 25,
        hrv: medianHrv,
        respiratoryRate: medianAtem,
      );
      expect(pruefe(reading).signals, [RecoveryMetric.restingHeartRate]);
    });

    test('ein niedriger Ruhepuls ist nie ein Signal', () {
      final reading = RecoveryReading(
        sleepHours: 8.0,
        restingHeartRate: medianPuls - 25,
        hrv: medianHrv,
        respiratoryRate: medianAtem,
      );
      expect(pruefe(reading).signals, isEmpty);
    });
  });

  group('HRV: <= Median · Faktor, Gleichheit ist Signal', () {
    test('knapp darüber ist kein Signal', () {
      final reading = RecoveryReading(
        sleepHours: 8.0,
        restingHeartRate: medianPuls,
        hrv: medianHrv * RecoveryTrafficLight.hrvFactor + 0.1,
        respiratoryRate: medianAtem,
      );
      expect(pruefe(reading).signals, isEmpty);
    });

    test('genau auf der Schwelle ist ein Signal', () {
      final reading = RecoveryReading(
        sleepHours: 8.0,
        restingHeartRate: medianPuls,
        hrv: medianHrv * RecoveryTrafficLight.hrvFactor,
        respiratoryRate: medianAtem,
      );
      expect(pruefe(reading).signals, [RecoveryMetric.hrv]);
    });

    test('deutlich darunter ist ein Signal', () {
      final reading = RecoveryReading(
        sleepHours: 8.0,
        restingHeartRate: medianPuls,
        hrv: 1.0,
        respiratoryRate: medianAtem,
      );
      expect(pruefe(reading).signals, [RecoveryMetric.hrv]);
    });

    test('eine hohe HRV ist nie ein Signal', () {
      final reading = RecoveryReading(
        sleepHours: 8.0,
        restingHeartRate: medianPuls,
        hrv: medianHrv * 3,
        respiratoryRate: medianAtem,
      );
      expect(pruefe(reading).signals, isEmpty);
    });
  });

  group('Atemfrequenz: >= Median + Zuschlag, Gleichheit ist Signal', () {
    test('knapp unter der Schwelle ist kein Signal', () {
      final reading = RecoveryReading(
        sleepHours: 8.0,
        restingHeartRate: medianPuls,
        hrv: medianHrv,
        respiratoryRate:
            medianAtem + RecoveryTrafficLight.respiratoryRateMargin - 0.1,
      );
      expect(pruefe(reading).signals, isEmpty);
    });

    test('genau auf der Schwelle ist ein Signal', () {
      final reading = RecoveryReading(
        sleepHours: 8.0,
        restingHeartRate: medianPuls,
        hrv: medianHrv,
        respiratoryRate:
            medianAtem + RecoveryTrafficLight.respiratoryRateMargin,
      );
      expect(pruefe(reading).signals, [RecoveryMetric.respiratoryRate]);
    });

    test('deutlich darüber ist ein Signal', () {
      final reading = RecoveryReading(
        sleepHours: 8.0,
        restingHeartRate: medianPuls,
        hrv: medianHrv,
        respiratoryRate: medianAtem + 10,
      );
      expect(pruefe(reading).signals, [RecoveryMetric.respiratoryRate]);
    });
  });

  group('Das Verdikt zählt Signale', () {
    test('null Signale ergeben calm', () {
      expect(pruefe(unauffaellig).verdict, RecoveryVerdict.calm);
    });

    test('ein Signal ergibt watch', () {
      final reading = RecoveryReading(
        sleepHours: 8.0,
        restingHeartRate:
            medianPuls + RecoveryTrafficLight.restingHeartRateMargin,
        hrv: medianHrv,
        respiratoryRate: medianAtem,
      );
      final auswertung = pruefe(reading);
      expect(auswertung.signals, hasLength(1));
      expect(auswertung.verdict, RecoveryVerdict.watch);
    });

    test('zwei Signale ergeben stressed — der Übergang watch -> stressed', () {
      final reading = RecoveryReading(
        sleepHours: 8.0,
        restingHeartRate:
            medianPuls + RecoveryTrafficLight.restingHeartRateMargin,
        hrv: medianHrv * RecoveryTrafficLight.hrvFactor,
        respiratoryRate: medianAtem,
      );
      final auswertung = pruefe(reading);
      expect(auswertung.signals, hasLength(2));
      expect(auswertung.verdict, RecoveryVerdict.stressed);
    });

    test('drei Signale bleiben stressed', () {
      final reading = RecoveryReading(
        sleepHours: 4.0,
        restingHeartRate:
            medianPuls + RecoveryTrafficLight.restingHeartRateMargin,
        hrv: medianHrv * RecoveryTrafficLight.hrvFactor,
        respiratoryRate: medianAtem,
      );
      final auswertung = pruefe(reading);
      expect(auswertung.signals, hasLength(3));
      expect(auswertung.verdict, RecoveryVerdict.stressed);
    });
  });

  group('Fehlende Messwerte', () {
    test('verdecken kein anderes Signal', () {
      // Schlaf und Ruhepuls fehlen, die HRV ist auffällig. Das Signal muss
      // trotzdem kommen.
      final reading = RecoveryReading(
        hrv: medianHrv * RecoveryTrafficLight.hrvFactor,
        respiratoryRate: medianAtem,
      );
      final auswertung = pruefe(reading);
      expect(auswertung.signals, [RecoveryMetric.hrv]);
      expect(auswertung.verdict, RecoveryVerdict.watch);
    });

    test('zählen nicht in measuredCount mit', () {
      expect(pruefe(const RecoveryReading()).measuredCount, 0);
      expect(pruefe(const RecoveryReading(sleepHours: 8.0)).measuredCount, 1);
      expect(
        pruefe(const RecoveryReading(sleepHours: 8.0, hrv: medianHrv))
            .measuredCount,
        2,
      );
      expect(pruefe(unauffaellig).measuredCount, 4);
    });

    test('ein fehlender Wert ist nicht dasselbe wie ein Wert von null', () {
      // 0 bpm ist ein (absurder, erfundener) Messwert und zählt mit; `null`
      // ist keiner. Die App darf eine Lücke nie als „0" darstellen.
      expect(
        pruefe(const RecoveryReading(restingHeartRate: 0.0)).measuredCount,
        1,
      );
    });
  });

  group('Fehlende Mediane', () {
    test('schalten nur ihre eigene Metrik ab', () {
      // Ohne HRV-Median kann die HRV nicht anschlagen — der auffällige
      // Ruhepuls muss trotzdem kommen.
      final auswertung = pruefe(
        RecoveryReading(
          sleepHours: 8.0,
          restingHeartRate:
              medianPuls + RecoveryTrafficLight.restingHeartRateMargin,
          hrv: 1.0,
          respiratoryRate: medianAtem,
        ),
        basis: const RecoveryBaseline(
          sleepHours: 7.0,
          restingHeartRate: medianPuls,
          respiratoryRate: medianAtem,
        ),
      );
      expect(auswertung.signals, [RecoveryMetric.restingHeartRate]);
    });

    test('ohne Ruhepuls-Median schlägt der Ruhepuls nicht an', () {
      final auswertung = pruefe(
        const RecoveryReading(sleepHours: 8.0, restingHeartRate: 200.0),
        basis: const RecoveryBaseline(sleepHours: 7.0),
      );
      expect(auswertung.signals, isEmpty);
      expect(auswertung.verdict, RecoveryVerdict.calm);
    });

    test('ohne Atem-Median schlägt die Atemfrequenz nicht an', () {
      final auswertung = pruefe(
        const RecoveryReading(sleepHours: 8.0, respiratoryRate: 40.0),
        basis: const RecoveryBaseline(sleepHours: 7.0),
      );
      expect(auswertung.signals, isEmpty);
    });

    test('ohne jeden Median bleibt nur der Schlaf bewertbar', () {
      final auswertung = pruefe(
        const RecoveryReading(
          sleepHours: 4.0,
          restingHeartRate: 200.0,
          hrv: 1.0,
          respiratoryRate: 40.0,
        ),
        basis: const RecoveryBaseline(),
      );
      expect(auswertung.signals, [RecoveryMetric.sleep]);
      expect(auswertung.verdict, RecoveryVerdict.watch);
      // Gemessen wurde trotzdem alles — fehlende Mediane ändern daran nichts.
      expect(auswertung.measuredCount, 4);
    });
  });

  group('noData und postOperative', () {
    test('kein einziger Wert ergibt noData, auch mit voller Baseline', () {
      final auswertung = pruefe(const RecoveryReading());
      expect(auswertung.verdict, RecoveryVerdict.noData);
      expect(auswertung.signals, isEmpty);
      expect(auswertung.measuredCount, 0);
    });

    test('kein Wert und keine Baseline ergibt ebenfalls noData', () {
      final auswertung = pruefe(
        const RecoveryReading(),
        basis: const RecoveryBaseline(),
      );
      expect(auswertung.verdict, RecoveryVerdict.noData);
    });

    test('ein einziger Wert reicht gegen noData', () {
      final auswertung = pruefe(const RecoveryReading(sleepHours: 8.0));
      expect(auswertung.verdict, RecoveryVerdict.calm);
      expect(auswertung.measuredCount, 1);
    });

    test('postOperative schlägt ein Verdikt mit Signalen', () {
      final auswertung = pruefe(
        const RecoveryReading(
          sleepHours: 4.0,
          restingHeartRate: 200.0,
          hrv: 1.0,
          respiratoryRate: 40.0,
        ),
        nachOp: true,
      );
      expect(auswertung.verdict, RecoveryVerdict.postOperative);
      // Nach der OP ruht die Ampel: keine Signale, aber die Zahl der
      // gemessenen Werte stimmt weiter — sie wird vor allen Abkürzungen
      // gezählt.
      expect(auswertung.signals, isEmpty);
      expect(auswertung.measuredCount, 4);
    });

    test('postOperative schlägt auch noData', () {
      final auswertung = pruefe(const RecoveryReading(), nachOp: true);
      expect(auswertung.verdict, RecoveryVerdict.postOperative);
      expect(auswertung.measuredCount, 0);
    });
  });

  group('Wertgleichheit der Trägertypen', () {
    // `RecoverySnapshot` entscheidet über `reading == RecoveryReading()`, ob
    // die Zeile „zuletzt gesehen" überhaupt gebraucht wird (#112). Ohne
    // Wertgleichheit wäre dieser Vergleich immer falsch.
    test('zwei gleiche RecoveryReading sind gleich', () {
      expect(
        const RecoveryReading(sleepHours: 8.0, hrv: 60.0),
        const RecoveryReading(sleepHours: 8.0, hrv: 60.0),
      );
      expect(const RecoveryReading(), const RecoveryReading());
      expect(
        const RecoveryReading(sleepHours: 8.0),
        isNot(const RecoveryReading()),
      );
    });

    test('hashCode passt zu == (geprüft über ein Set)', () {
      // **Bewusst ohne `const`** (korrigiert am 27.10.2026). Dart
      // kanonisiert gleiche `const`-Ausdrücke: Vier `const`-Literale sind
      // zwei Objekte, das Set hat zwei Elemente — und zwar unabhängig
      // davon, wie `==` und `hashCode` aussehen. Mit `const` blieb dieser
      // Test auch dann grün, wenn man `hashCode` aus beiden Klassen löschte;
      // er konnte nichts beweisen. `dart analyze` meldete das zweimal als
      // `equal_elements_in_set`, und das Paket analysierte deshalb nicht
      // sauber durch.
      final einLesewert = RecoveryReading(sleepHours: 8.0);
      final gleicherLesewert = RecoveryReading(sleepHours: 8.0);
      final eineBasis = RecoveryBaseline(sleepHours: 8.0);
      final gleicheBasis = RecoveryBaseline(sleepHours: 8.0);

      // Hält fest, dass die Kanonisierung nicht durch eine spätere
      // Umstellung auf `const` zurückkommt: Es müssen vier verschiedene
      // Objekte sein, bevor das Set überhaupt etwas aussagt.
      expect(gleicherLesewert, isNot(same(einLesewert)));
      expect(gleicheBasis, isNot(same(eineBasis)));

      final menge = {einLesewert, gleicherLesewert, eineBasis, gleicheBasis};

      expect(
        menge,
        hasLength(2),
        reason:
            'ohne `hashCode` landete jedes der vier Objekte in einem '
            'eigenen Eimer, und das Set hätte vier Elemente — trotz `==`',
      );
    });

    test('zwei gleiche RecoveryEvaluation sind gleich', () {
      expect(
        pruefe(unauffaellig),
        const RecoveryEvaluation(
          verdict: RecoveryVerdict.calm,
          signals: [],
          measuredCount: 4,
          // `unauffaellig` trägt vier Werte, `baseline` vier Mediane — also
          // hat die Ampel über alle vier eine Aussage gemacht. Nachgezogen
          // am 03.11.2026 für #261; die Aussage dieses Falls ist dieselbe
          // geblieben, siehe Dateikopf.
          rated: [
            RecoveryMetric.sleep,
            RecoveryMetric.restingHeartRate,
            RecoveryMetric.hrv,
            RecoveryMetric.respiratoryRate,
          ],
        ),
      );
    });
  });
}
