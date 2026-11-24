import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/core/messwert.dart';
import 'package:repit/data/ziele.dart';
import 'package:repit/design/erholungs_karte.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_types.dart';
import 'package:repit/shell/heute_view.dart';
import 'package:repit/shell/router.dart';

/// **#254 — woher die Ampelfarbe auf Heute kommt.**
///
/// Tim am 03.11.2026: „auf dem Home Screen sind die Werte von Erholung
/// immer noch nicht gefärbt". Die Auskunft lag vor und wurde auf dem Weg
/// zur Karte weggelassen: `_vitalwerte` baute die vier Werte aus `reading`
/// und `baseline` und fasste `evaluation` gar nicht erst an.
///
/// Das Bauteil und seine Farben beschreibt
/// `test/design/erholungs_karte_ton_test.dart`. Hier steht die andere
/// Hälfte: **welcher Wert welchen Zustand bekommt** — und zwar genau den,
/// den die Ampel im Kern schon vergeben hat.
///
/// ## Die drei Zustände, und warum es drei sind
///
/// `RecoveryEvaluation` führt zwei Listen. `signals` sind die Warnsignale,
/// `rated` die Metriken, über die überhaupt geurteilt wurde — es gilt
/// `signals ⊆ rated`. Ohne Median gibt es keinen Vergleich, ohne Vergleich
/// kein Warnsignal, und null Warnsignale wären sonst „alles im
/// Normalbereich": eine Aussage, die niemand gemacht hat. Deshalb reicht
/// `signals` allein nicht.
///
/// | Lage | Zustand |
/// |---|---|
/// | in `signals` | `warnsignal` |
/// | in `rated`, nicht in `signals` | `normal` |
/// | nicht in `rated` | `unbeurteilt` |
///
/// **Der Schlaf ist dabei der Sonderfall**, und das ist kein Versehen: Für
/// ihn gilt die feste Sechs-Stunden-Grenze aus `docs/SPEC.md` 4.6, er
/// braucht keinen Median. Ein Schlafwert ohne Vorgeschichte ist deshalb
/// beurteilt, ein HRV-Wert ohne Vorgeschichte nicht.
///
/// ## Was hier **nicht** geprüft wird
///
/// Die Schwellen selbst. Sie stehen im Kern
/// (`RecoveryTrafficLight`, geprüft in `Packages/trainings_core/test/`),
/// und eine zweite Bewertung in der Oberfläche wären zwei Wahrheiten. Hier
/// wird nur geprüft, dass die Karte das Urteil **durchreicht**.
///
/// `postOperative` fehlt, wie schon in `heute_erholungskarte_test.dart`:
/// Der Schirm kann den Zustand heute nicht erzeugen (#41 fehlt), und ein
/// Ereignisdatum im Quelltext verbietet `CLAUDE.md`.
///
/// Alle Zahlen sind erfunden (`CLAUDE.md`, Spec Abschnitt 12).
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
    double? atmung = 13,
  }) => DailyMetrics(
    tag: tagKey(tag),
    restingHR: ruhepuls,
    hrvMs: hrv,
    respRate: atmung,
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
  List<DailyMetrics> tage({DailyMetrics? heute}) => [
    for (var t = 3; t <= 11; t++) tagwert(t),
    if (heute != null) heute,
  ];

  List<SleepNight> naechte({double? heuteStunden = 6.5}) => [
    for (var t = 3; t <= 11; t++) nachtVon(t),
    if (heuteStunden != null) nachtVon(12, stunden: heuteStunden),
  ];

  /// Die Nachtwerte spiegeln die Tageswerte (#193, Stufe 4) — seit dann
  /// kommen Ruhepuls, HRV und Atemfrequenz aus dem Nachtfenster.
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

  Widget harness({List<DailyMetrics>? tageswerte, List<SleepNight>? schlaf}) {
    final werte = tageswerte ?? tage(heute: tagwert(12));
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
              schlaf ?? naechte(),
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

  VitalTon ton(WidgetTester tester, String teil) => tester
      .widget<ErholungsKarte>(find.byType(ErholungsKarte))
      .vitalwerte
      .firstWhere(
        (v) => v.name.toLowerCase().contains(teil),
        orElse: () => throw StateError('kein Vitalwert enthält "$teil"'),
      )
      .ton;

  group('Ein Warnsignal färbt genau seinen Wert', () {
    testWidgets('fünf Stunden Schlaf sind ein Signal — und nur der Schlaf', (
      tester,
    ) async {
      await zeige(tester, harness(schlaf: naechte(heuteStunden: 5)));

      expect(
        ton(tester, 'schlaf'),
        VitalTon.warnsignal,
        reason:
            'unter sechs Stunden führt `RecoveryTrafficLight` den Schlaf '
            'als Warnsignal (`docs/SPEC.md` 4.6)',
      );
      for (final teil in const ['hrv', 'puls', 'atem']) {
        expect(
          ton(tester, teil),
          VitalTon.normal,
          reason:
              '$teil: ein Signal beim Schlaf färbt die anderen drei nicht '
              'mit — sie liegen in ihrem Normalbereich',
        );
      }
    });

    testWidgets('eine eingebrochene HRV ist ein Signal, der Schlaf nicht', (
      tester,
    ) async {
      // Median 60, heute 40 — das sind weniger als 60 · 0,8.
      await zeige(
        tester,
        harness(tageswerte: tage(heute: tagwert(12, hrv: 40))),
      );

      expect(ton(tester, 'hrv'), VitalTon.warnsignal);
      expect(ton(tester, 'schlaf'), VitalTon.normal);
    });
  });

  group('Ohne Warnsignal, aber beurteilt', () {
    testWidgets('alle vier liegen im Normalbereich und sind es auch', (
      tester,
    ) async {
      await zeige(tester, harness());

      for (final teil in const ['schlaf', 'hrv', 'puls', 'atem']) {
        expect(ton(tester, teil), VitalTon.normal, reason: teil);
      }
    });
  });

  group('Ohne Median keine Bewertung', () {
    testWidgets('ein Wert ohne Vorgeschichte ist unbeurteilt', (tester) async {
      // Nur heute, kein einziger Tag davor: Für einen Median braucht
      // `HealthMedian` fünf Werte, hier gibt es keinen.
      await zeige(
        tester,
        harness(
          tageswerte: [tagwert(12)],
          schlaf: [nachtVon(12, stunden: 6.5)],
        ),
      );

      for (final teil in const ['hrv', 'puls', 'atem']) {
        expect(
          ton(tester, teil),
          VitalTon.unbeurteilt,
          reason:
              '$teil: ohne Median gibt es keinen Vergleich — grün hieße '
              '„im Normalbereich", und das hat niemand gesagt',
        );
      }
    });

    testWidgets('der Schlaf dagegen hat eine feste Grenze und ist beurteilt', (
      tester,
    ) async {
      await zeige(
        tester,
        harness(
          tageswerte: [tagwert(12)],
          schlaf: [nachtVon(12, stunden: 6.5)],
        ),
      );

      expect(
        ton(tester, 'schlaf'),
        VitalTon.normal,
        reason:
            'die Sechs-Stunden-Grenze steht fest und braucht keinen Median '
            '(`RecoveryTrafficLight.minimumSleepHours`)',
      );
    });

    testWidgets('und ohne jeden Messwert ist keiner der vier beurteilt', (
      tester,
    ) async {
      await zeige(
        tester,
        harness(tageswerte: tage(), schlaf: naechte(heuteStunden: null)),
      );

      for (final teil in const ['schlaf', 'hrv', 'puls', 'atem']) {
        expect(
          ton(tester, teil),
          VitalTon.unbeurteilt,
          reason:
              '$teil: „keine Werte von der Uhr" ist kein Urteil über die '
              'Erholung',
        );
      }
    });
  });

  group('Was die Farbe nicht ersetzt', () {
    testWidgets('ein gefärbter Wert behält seine Bildunterschrift', (
      tester,
    ) async {
      await zeige(tester, harness(schlaf: naechte(heuteStunden: 5)));

      final schlaf = tester
          .widget<ErholungsKarte>(find.byType(ErholungsKarte))
          .vitalwerte
          .firstWhere((v) => v.name.toLowerCase().contains('schlaf'));

      expect(schlaf.ton, VitalTon.warnsignal);
      expect(
        schlaf.hinweis,
        isNotNull,
        reason:
            'Farbe ist nicht die einzige Auskunft — die Einordnung muss '
            'auch im Text stehen',
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
