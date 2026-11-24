import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repit/core/messwert.dart';
import 'package:repit/design/platzhalter.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_types.dart';
import 'package:repit/shell/healthkit_test_view.dart';
import '../health/health_reading_attrappe.dart';

/// Tests für den Umbau des HealthKit-Test-Schirms auf die Aufteilung des
/// Entwurfs (#262), gegen
/// `docs/superpowers/specs/2026-11-03-healthkit-test-aufteilung.md` und
/// `docs/screens/screens/healthtest.js`.
///
/// Die Grundfälle — welche Zeile welchen Rohwert trägt, dass nichts
/// gerundet wird, dass beide Gründe genannt werden — stehen weiter in
/// `healthkit_test_view_test.dart`. **Hier steht nur, was neu ist**, und
/// zwar nach `CLAUDE.md` („Views bekommen Widget-Tests, aber nur für
/// Zustände und Übergänge, nicht für Layout und Beschriftung") nur als
/// Zustandsaussage:
///
/// · Das Gerüst steht in **jedem** Zustand, nicht nur in `Bekannt`
///   (#182). Das ist die eigentliche Anforderung; ob die Gruppe
///   „Aktivität heute" oder anders heißt, prüft kein Test — das
///   entscheidet das Board, und ein Test darauf kostete mehr Pflege,
///   als er wert ist.
/// · Ein Körperwert, der nicht von heute ist, steht mit Datum da statt
///   als „keine Daten" (#237).
/// · Ziehen von oben stößt einen neuen Lauf an (#228, Teil).
///
/// **Geprüft wird über die Schlüssel, nicht über Texte.** Die dreizehn
/// `healthkit-typ-<feld>` sind dieselben wie bisher — der Umbau ordnet
/// sie um, er benennt sie nicht um.
void main() {
  final jetzt = DateTime.utc(2026, 11, 3, 15, 31);

  DailyMetrics tag(
    String iso, {
    int? steps,
    double? weightKg,
    double? bodyFatPct,
    double? leanKg,
  }) => DailyMetrics(
    tag: iso,
    steps: steps,
    weightKg: weightKg,
    bodyFatPct: bodyFatPct,
    leanKg: leanKg,
  );

  const typSchluessel = [
    'steps',
    'activeKcal',
    'basalKcal',
    'restingHR',
    'hrvMs',
    'respRate',
    'vo2max',
    'weightKg',
    'bodyFatPct',
    'leanKg',
    'exerciseMinutes',
    'standHours',
    'recoveryHRDrop',
  ];

  /// Die drei Gruppen, für die es noch keinen Provider gibt (#123). Sie
  /// stehen trotzdem da — Tims Entscheidung vom 03.11.2026.
  const leereGruppen = ['workouts', 'ernaehrung', 'schlaf'];

  ({ProviderContainer container, Widget app, _Steuerung steuerung}) harness({
    Messwert<List<DailyMetrics>>? zwischenwert,
    required Future<Messwert<List<DailyMetrics>>> Function() endwert,
  }) {
    final steuerung = _Steuerung();
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        dailyMetricsProvider.overrideWith(
          () => _GesteuerterNotifier(
            zwischenwert: zwischenwert,
            endwert: endwert,
            steuerung: steuerung,
          ),
        ),
        clockProvider.overrideWithValue(() => jetzt),
        healthProvider.overrideWithValue(_StummeHealthReading()),
      ],
    );
    return (
      container: container,
      app: UncontrolledProviderScope(
        container: container,
        child: const CupertinoApp(
          home: CupertinoPageScaffold(child: HealthKitTestView()),
        ),
      ),
      steuerung: steuerung,
    );
  }

  Finder typZeile(String feld) => find.byKey(Key('healthkit-typ-$feld'));
  Finder gruppe(String name) => find.byKey(Key('healthkit-gruppe-$name'));

  String textUnter(WidgetTester tester, Key key) => tester
      .widgetList<Text>(
        find.descendant(of: find.byKey(key), matching: find.byType(Text)),
      )
      .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
      .join(' ');

  group('das Geruest steht in jedem Zustand (#182)', () {
    testWidgets('NochNie: alle Zeilen da, Werte als graue Formen', (
      tester,
    ) async {
      final nieFertig = Completer<Messwert<List<DailyMetrics>>>();
      final h = harness(endwert: () => nieFertig.future);
      addTearDown(h.container.dispose);
      addTearDown(() {
        if (!nieFertig.isCompleted) {
          nieFertig.complete(LeerNachLauf<List<DailyMetrics>>(gelaufen: jetzt));
        }
      });

      await tester.pumpWidget(h.app);
      await tester.pump();

      for (final feld in typSchluessel) {
        expect(typZeile(feld), findsOneWidget, reason: feld);
      }
      expect(find.byType(Platzhalter), findsWidgets);
    });

    /// „Stand" ist in `NochNie` nicht ungenau, sondern falsch: Es wurde
    /// nie etwas gelesen, es gibt keinen Zeitpunkt, den man nennen
    /// könnte. Trotzdem muss an dieser Stelle **eine** Zeile stehen,
    /// sonst rutscht der Schirm beim Eintreffen der Werte nach oben.
    testWidgets('NochNie: eine Zeile an der Stelle des Stands, aber kein '
        '"Stand"', (tester) async {
      final nieFertig = Completer<Messwert<List<DailyMetrics>>>();
      final h = harness(endwert: () => nieFertig.future);
      addTearDown(h.container.dispose);
      addTearDown(() {
        if (!nieFertig.isCompleted) {
          nieFertig.complete(LeerNachLauf<List<DailyMetrics>>(gelaufen: jetzt));
        }
      });

      await tester.pumpWidget(h.app);
      await tester.pump();

      final slot = find.byKey(const Key('healthkit-standzeile'));
      expect(slot, findsOneWidget);
      // Auf den Platz eingegrenzt, nicht auf den ganzen Schirm: Die
      // Fußnote sagt „der Stand oben sagt, wann zuletzt" und trifft eine
      // Suche über alle Texte mit. Gemeint war immer nur diese Zeile.
      // *(Eingegrenzt am 03.11.2026 beim Bauen — die erste Fassung
      // dieses Falls suchte über den ganzen Baum und schlug an einem
      // Satz fehl, der mit dem Geprüften nichts zu tun hat.)*
      expect(
        tester
            .widgetList<Text>(
              find.descendant(of: slot, matching: find.byType(Text)),
            )
            .map((t) => t.data ?? '')
            .join(' '),
        isNot(contains('Stand')),
      );
    });

    testWidgets('LeerNachLauf: alle Zeilen da, kein Platzhalter', (
      tester,
    ) async {
      final h = harness(
        endwert: () async =>
            LeerNachLauf<List<DailyMetrics>>(gelaufen: jetzt),
      );
      addTearDown(h.container.dispose);

      await tester.pumpWidget(h.app);
      await tester.pumpAndSettle();

      for (final feld in typSchluessel) {
        expect(typZeile(feld), findsOneWidget, reason: feld);
      }
      expect(
        find.byType(Platzhalter),
        findsNothing,
        reason: 'der Lauf ist fertig — eine graue Form behauptete, es ginge '
            'noch weiter',
      );
    });

    testWidgets('Fehlgeschlagen: Zeilen da, Grund einmal statt je Zeile', (
      tester,
    ) async {
      final h = harness(
        endwert: () async => Fehlgeschlagen<List<DailyMetrics>>(
          fehler: Exception('Kanal nicht erreichbar'),
          gelaufen: jetzt,
        ),
      );
      addTearDown(h.container.dispose);

      await tester.pumpWidget(h.app);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      for (final feld in typSchluessel) {
        expect(typZeile(feld), findsOneWidget, reason: feld);
      }
    });

    /// Das Gerüst muss in jedem Zustand **dieselbe** Höhe haben, sonst
    /// hat der Platzhalter den Sprung nur verschoben.
    testWidgets('eine Zeile ist in allen Zustaenden gleich hoch', (
      tester,
    ) async {
      final hoehen = <double>[];

      Future<void> miss(
        Future<Messwert<List<DailyMetrics>>> Function() endwert,
      ) async {
        final h = harness(endwert: endwert);
        addTearDown(h.container.dispose);
        await tester.pumpWidget(h.app);
        await tester.pumpAndSettle();
        hoehen.add(tester.getSize(typZeile('steps')).height);
      }

      await miss(
        () async => Bekannt<List<DailyMetrics>>(
          [tag('2026-11-03', steps: 9215)],
          stand: jetzt,
          laeuft: false,
        ),
      );
      await miss(
        () async => LeerNachLauf<List<DailyMetrics>>(gelaufen: jetzt),
      );

      expect(
        hoehen.toSet(),
        hasLength(1),
        reason: 'mit Wert und ohne Wert dieselbe Hoehe: $hoehen',
      );
    });
  });

  group('die Gruppen ohne Provider stehen trotzdem da (#123)', () {
    testWidgets('alle drei sind in jedem Zustand zu finden', (tester) async {
      for (final endwert in <Future<Messwert<List<DailyMetrics>>> Function()>[
        () async => Bekannt<List<DailyMetrics>>(
          [tag('2026-11-03', steps: 9215)],
          stand: jetzt,
          laeuft: false,
        ),
        () async => LeerNachLauf<List<DailyMetrics>>(gelaufen: jetzt),
      ]) {
        final h = harness(endwert: endwert);
        addTearDown(h.container.dispose);
        await tester.pumpWidget(h.app);
        await tester.pumpAndSettle();

        for (final name in leereGruppen) {
          expect(gruppe(name), findsOneWidget, reason: name);
        }
      }
    });
  });

  group('Koerperwerte tragen ihr Datum, statt "keine Daten" zu behaupten '
      '(#237)', () {
    testWidgets('ein Gewicht von vorgestern steht mit Datum da', (
      tester,
    ) async {
      final h = harness(
        endwert: () async => Bekannt<List<DailyMetrics>>([
          tag('2026-11-01', weightKg: 58.4),
          tag('2026-11-02', steps: 7000),
          tag('2026-11-03', steps: 9215),
        ], stand: jetzt, laeuft: false),
      );
      addTearDown(h.container.dispose);

      await tester.pumpWidget(h.app);
      await tester.pumpAndSettle();

      final text = textUnter(tester, const Key('healthkit-typ-weightKg'));
      expect(text, contains('58,4'));
      expect(
        text,
        contains('01.11.'),
        reason: 'ohne Datum saehe der Wert aus wie eine heutige Messung',
      );
      expect(
        text.toLowerCase(),
        isNot(contains('keine daten')),
        reason: 'der Wert ist da, er ist nur nicht von heute',
      );
    });

    testWidgets('ein Gewicht von heute steht ohne Datum da', (tester) async {
      final h = harness(
        endwert: () async => Bekannt<List<DailyMetrics>>([
          tag('2026-11-03', steps: 9215, weightKg: 58.4),
        ], stand: jetzt, laeuft: false),
      );
      addTearDown(h.container.dispose);

      await tester.pumpWidget(h.app);
      await tester.pumpAndSettle();

      final text = textUnter(tester, const Key('healthkit-typ-weightKg'));
      expect(text, contains('58,4'));
      expect(
        text,
        isNot(contains('03.11.')),
        reason: 'die Klammer faellt nur auf, solange sie die Ausnahme ist',
      );
    });

    /// Je Feld einzeln gesucht, nicht je Wägung: Eine Waage liefert
    /// Gewicht und Körperfett, aber nicht immer Magermasse. Ein
    /// gemeinsames Datum für die ganze Gruppe wäre für mindestens eine
    /// Zeile gelogen.
    testWidgets('jedes Feld traegt sein eigenes Datum', (tester) async {
      final h = harness(
        endwert: () async => Bekannt<List<DailyMetrics>>([
          tag('2026-10-28', leanKg: 50.1),
          tag('2026-11-01', weightKg: 58.4, bodyFatPct: 14.2),
          tag('2026-11-03', steps: 9215),
        ], stand: jetzt, laeuft: false),
      );
      addTearDown(h.container.dispose);

      await tester.pumpWidget(h.app);
      await tester.pumpAndSettle();

      expect(
        textUnter(tester, const Key('healthkit-typ-weightKg')),
        contains('01.11.'),
      );
      expect(
        textUnter(tester, const Key('healthkit-typ-leanKg')),
        contains('28.10.'),
      );
    });

    /// Erst wenn im ganzen Fenster nichts liegt, stimmt der Satz mit den
    /// beiden Möglichkeiten wieder — dann aber auch wirklich.
    testWidgets('ohne jeden Wert im Fenster gilt weiter der Luecken-Satz', (
      tester,
    ) async {
      final h = harness(
        endwert: () async => Bekannt<List<DailyMetrics>>([
          tag('2026-11-02', steps: 7000),
          tag('2026-11-03', steps: 9215),
        ], stand: jetzt, laeuft: false),
      );
      addTearDown(h.container.dispose);

      await tester.pumpWidget(h.app);
      await tester.pumpAndSettle();

      final text = textUnter(
        tester,
        const Key('healthkit-typ-weightKg'),
      ).toLowerCase();
      expect(text, contains('keine daten'));
    });

    /// Der Tagesschlüssel ist ein ISO-String, kein Zeitpunkt. Wer ihn
    /// über `BerlinCalendar.startOfDay` schickt und dann formatiert,
    /// bekommt den Vortag — der Berliner Tagesbeginn liegt als
    /// UTC-Zeitpunkt vor Mitternacht (am 02.11.2026 genau so passiert).
    testWidgets('das Datum ist der Tag des Werts, nicht der davor', (
      tester,
    ) async {
      final h = harness(
        endwert: () async => Bekannt<List<DailyMetrics>>([
          tag('2026-07-14', weightKg: 58.4),
          tag('2026-11-03', steps: 9215),
        ], stand: jetzt, laeuft: false),
      );
      addTearDown(h.container.dispose);

      await tester.pumpWidget(h.app);
      await tester.pumpAndSettle();

      final text = textUnter(tester, const Key('healthkit-typ-weightKg'));
      expect(text, contains('14.07.'));
      expect(text, isNot(contains('13.07.')));
    });
  });

  group('Ziehen von oben liest neu (#228, Teil)', () {
    testWidgets('ein Zug stoesst einen zweiten Lauf an', (tester) async {
      final h = harness(
        endwert: () async => Bekannt<List<DailyMetrics>>([
          tag('2026-11-03', steps: 9215),
        ], stand: jetzt, laeuft: false),
      );
      addTearDown(h.container.dispose);

      await tester.pumpWidget(h.app);
      await tester.pumpAndSettle();
      expect(h.steuerung.laeufe, 1);

      await tester.fling(typZeile('steps'), const Offset(0, 320), 1200);
      await tester.pumpAndSettle();

      expect(
        h.steuerung.laeufe,
        greaterThan(1),
        reason: 'ohne einen neuen Lauf hilft nur ein Neustart der App (#184)',
      );
    });
  });
}

/// Zählt die Läufe, damit ein Test den Zug von oben von „nichts
/// passiert" unterscheiden kann.
class _Steuerung {
  int laeufe = 0;
}

class _GesteuerterNotifier extends DailyMetricsNotifier {
  _GesteuerterNotifier({
    this.zwischenwert,
    required this.endwert,
    required this.steuerung,
  });

  final Messwert<List<DailyMetrics>>? zwischenwert;
  final Future<Messwert<List<DailyMetrics>>> Function() endwert;
  final _Steuerung steuerung;

  @override
  Future<Messwert<List<DailyMetrics>>> build() async {
    steuerung.laeufe += 1;
    final z = zwischenwert;
    if (z != null) state = AsyncData(z);
    return endwert();
  }
}

/// Liefert nichts und wirft nicht: Dieser Schirm bezieht seine Daten
/// ausschließlich über `dailyMetricsProvider` (Hausregel „Views rufen
/// niemals den Platform-Channel direkt auf").
class _StummeHealthReading extends HealthReadingAttrappe {
  @override
  DateTime get earliestPermittedDate => DateTime.utc(2000);

  @override
  Future<List<DailyMetrics>> dailyMetrics(DateTime from, DateTime through) =>
      throw UnimplementedError('ueber dailyMetricsProvider, nicht direkt');

  @override
  Future<List<SleepNight>> sleepSessions(DateTime from, DateTime through) =>
      throw UnimplementedError('hier nicht erwartet');

  @override
  Future<List<WorkoutSample>> workouts(DateTime from, DateTime through) =>
      throw UnimplementedError('hier nicht erwartet');

  @override
  Future<List<QuantitySample>> quantitySamples(
    VitalKind kind,
    DateTime from,
    DateTime through,
  ) => throw UnimplementedError('hier nicht erwartet');

  @override
  Future<List<QuantitySample>> hourlySteps(DateTime from, DateTime through) =>
      throw UnimplementedError('hier nicht erwartet');

  @override
  Future<List<NutritionEntry>> nutritionEntries(DateTime day) =>
      throw UnimplementedError('hier nicht erwartet');
}
