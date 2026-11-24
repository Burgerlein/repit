import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/core/messwert.dart';
import 'package:repit/data/ziele.dart';
import 'package:repit/design/erholungs_karte.dart';
import 'package:repit/design/vital_ton.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_types.dart';
import 'package:repit/shell/erholung_abschnitte.dart';
import 'package:repit/shell/heute_view.dart';
import 'package:repit/shell/router.dart';

/// **#308 — derselbe Wert trägt auf jedem Schirm dieselbe Farbe.**
///
/// Tim am 04.11.2026 auf dem Gerät: „Schlaf-Dauer 6:18 h auf dem
/// Home-Screen grün, im Erholungs-Tab gelb. Sollte einheitlich behandelt
/// werden, die Einfärbung."
///
/// `test/design/vital_ton_test.dart` beschreibt die herausgelöste Funktion.
/// Hier steht die andere Hälfte: **dass beide Schirme sie benutzen.** Die
/// Zahl ist dieselbe wie in Tims Beobachtung, und geprüft wird nicht, dass
/// sie gelb ist, sondern dass sie auf beiden Schirmen **dieselbe** Stufe
/// trägt — der Fehler war der Unterschied, nicht die Farbe.
///
/// **Was hier nicht geprüft wird:** die Schwellen. Die stehen im Kern
/// (`RecoveryTrafficLight`) und die mittlere Stufe in `vital_ton.dart`;
/// eine zweite Prüfung hier wären zwei Wahrheiten.
///
/// Alle Zahlen sind erfunden (`CLAUDE.md`).
void main() {
  // Montag, 12.10.2026, 09:15 Berliner Zeit (CEST, +2).
  final jetzt = DateTime.utc(2026, 10, 12, 7, 15);

  /// 6:18 h — die Nacht aus Tims Beobachtung. Kein Warnsignal (die Grenze
  /// liegt bei 6:00 h), aber in der Pufferzone darüber.
  const sechsAchtzehn = 6.3;

  DateTime tagesbeginn(int tag) =>
      BerlinCalendar.startOfDay(DateTime.utc(2026, 10, tag));

  String tagKey(int tag) => '2026-10-${tag.toString().padLeft(2, '0')}';

  DailyMetrics tagwert(int tag) => DailyMetrics(
    tag: tagKey(tag),
    restingHR: 52,
    hrvMs: 60,
    respRate: 13,
    steps: 842,
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
    );
  }

  /// Neun Tage Vorgeschichte und heute — genug für einen Median
  /// ([HealthMedian] verlangt fünf Werte).
  List<DailyMetrics> tage() => [for (var t = 3; t <= 12; t++) tagwert(t)];

  List<SleepNight> naechte(double heuteStunden) => [
    for (var t = 3; t <= 11; t++) nachtVon(t),
    nachtVon(12, stunden: heuteStunden),
  ];

  Messwert<Map<String, NightVitals>> nachtwerteAus(List<DailyMetrics> tage) =>
      Bekannt<Map<String, NightVitals>>(
        {
          for (final tag in tage)
            tag.tag: NightVitals(
              restingHeartRate: tag.restingHR?.toDouble(),
              hrv: tag.hrvMs,
              respiratoryRate: tag.respRate,
            ),
        },
        stand: jetzt,
        laeuft: false,
      );

  Widget heute(double schlafStunden) {
    final werte = tage();
    // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        clockProvider.overrideWithValue(() => jetzt),
        dailyMetricsProvider.overrideWith(
          () => _Tageswerte(
            Bekannt<List<DailyMetrics>>(werte, stand: jetzt, laeuft: false),
          ),
        ),
        nachtWerteProvider.overrideWith(
          () => _Nachtwerte(nachtwerteAus(werte)),
        ),
        sleepProvider.overrideWith(
          () => _Naechte(
            Bekannt<List<SleepNight>>(
              naechte(schlafStunden),
              stand: jetzt,
              laeuft: false,
            ),
          ),
        ),
        zieleProvider.overrideWith(() => _Ziele(Ziele.vorbelegung)),
      ],
    );
    addTearDown(container.dispose);

    return UncontrolledProviderScope(
      container: container,
      child: CupertinoApp(
        home: CupertinoPageScaffold(child: HeuteView(router: AppRouter())),
      ),
    );
  }

  Future<void> zeige(WidgetTester tester, Widget app) async {
    tester.view.physicalSize = const Size(900, 4200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
  }

  VitalTon tonAufHeute(WidgetTester tester, String teil) => tester
      .widget<ErholungsKarte>(find.byType(ErholungsKarte))
      .vitalwerte
      .firstWhere(
        (v) => v.name.toLowerCase().contains(teil),
        orElse: () => throw StateError('kein Vitalwert enthält "$teil"'),
      )
      .ton;

  /// Die Verlaufszeilen des Erholungs-Schirms für sich, mit denselben
  /// Zahlen — der Abschnitt gilt unabhängig davon, wer ihn einsetzt.
  Widget verlaeufe({
    required RecoveryReading messwerte,
    required RecoveryBaseline baseline,
    bool nachOp = false,
  }) => CupertinoApp(
    home: CupertinoPageScaffold(
      child: SingleChildScrollView(
        child: ErholungVerlaeufe(
          trends: [
            for (final art in RecoveryTrendKind.values)
              RecoveryTrend(kind: art, average: null, count: 7),
          ],
          messwerte: messwerte,
          baseline: baseline,
          bewertung: RecoveryTrafficLight.evaluate(
            reading: messwerte,
            baseline: baseline,
            isPostOperative: nachOp,
          ),
          onVerlauf: (_) {},
        ),
      ),
    ),
  );

  VitalTon tonAufErholung(WidgetTester tester, String titel) => tester
      .widgetList<ErholungVerlaufsZeile>(find.byType(ErholungVerlaufsZeile))
      .firstWhere(
        (z) => z.titel.toLowerCase().contains(titel),
        orElse: () => throw StateError('keine Zeile heißt „$titel"'),
      )
      .ton;

  group('6:18 h Schlaf — Tims Beobachtung', () {
    testWidgets('Heute zeigt die mittlere Stufe', (tester) async {
      await zeige(tester, heute(sechsAchtzehn));

      expect(
        tonAufHeute(tester, 'schlaf'),
        VitalTon.nahAmSignal,
        reason:
            'kein Warnsignal, aber in der Pufferzone — bis #308 stand hier '
            'die grüne Stufe, weil Heute nur `signals` und `rated` fragte',
      );
    });

    testWidgets('Erholung zeigt dieselbe', (tester) async {
      await tester.pumpWidget(
        verlaeufe(
          messwerte: const RecoveryReading(
            sleepHours: sechsAchtzehn,
            restingHeartRate: 52,
            hrv: 60,
            respiratoryRate: 13,
          ),
          baseline: const RecoveryBaseline(
            sleepHours: 7,
            restingHeartRate: 52,
            hrv: 60,
            respiratoryRate: 13,
          ),
        ),
      );

      expect(tonAufErholung(tester, 'schlafdauer'), VitalTon.nahAmSignal);
    });

    testWidgets('und beide Male ist es derselbe Wert desselben Typs', (
      tester,
    ) async {
      await zeige(tester, heute(sechsAchtzehn));
      final aufHeute = tonAufHeute(tester, 'schlaf');

      await tester.pumpWidget(
        verlaeufe(
          messwerte: const RecoveryReading(sleepHours: sechsAchtzehn),
          baseline: const RecoveryBaseline(sleepHours: 7),
        ),
      );

      expect(
        tonAufErholung(tester, 'schlafdauer'),
        aufHeute,
        reason:
            'der Fehler war der Unterschied, nicht die Farbe — es gibt '
            'einen Aufzählungstyp und eine Funktion, also kann er nicht '
            'wiederkommen',
      );
    });
  });

  group('Nach der OP ruht die Ampel — auch in den Verlaufszeilen', () {
    testWidgets('keine der vier Zeilen ist gefärbt', (tester) async {
      await tester.pumpWidget(
        verlaeufe(
          messwerte: const RecoveryReading(
            sleepHours: 4,
            restingHeartRate: 80,
            hrv: 20,
            respiratoryRate: 18,
          ),
          baseline: const RecoveryBaseline(
            sleepHours: 7,
            restingHeartRate: 52,
            hrv: 60,
            respiratoryRate: 13,
          ),
          nachOp: true,
        ),
      );

      for (final titel in const ['hrv', 'ruhepuls', 'atem', 'schlafdauer']) {
        expect(
          tonAufErholung(tester, titel),
          VitalTon.unbeurteilt,
          reason:
              '$titel: `rated` ist nach der OP leer. Bis #308 kannte die '
              'Verlaufsampel den Fall nicht und färbte weiter, während '
              'Heute dieselben Werte ungefärbt ließ',
        );
      }
    });
  });

  group('Was gleich bleibt', () {
    testWidgets('die Alkohol-Zeile bekommt weiterhin keine Farbe', (
      tester,
    ) async {
      await tester.pumpWidget(
        verlaeufe(
          messwerte: const RecoveryReading(sleepHours: 4),
          baseline: const RecoveryBaseline(sleepHours: 7),
        ),
      );

      expect(
        tonAufErholung(tester, 'alkohol'),
        VitalTon.unbeurteilt,
        reason: 'die Zeile stellt einen Zusammenhang her, sie bewertet nicht',
      );
    });
  });
}

/// Steuerbare Ableger der echten Notifier — siehe `heute_view_test.dart`:
/// Riverpods Provider-Typen sind invariant, ein eigenständiger
/// `AsyncNotifier` erfüllt die `overrideWith`-Signatur nicht.
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
