import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
// Gemeint sind die Kanal-Typen aus health_types.dart — der Kern hat seit #95
// eigene, schlanke Workout-Typen (zone_distribution.dart), deren Namen sonst
// mehrdeutig wären.
import 'package:trainings_core/trainings_core.dart'
    hide WorkoutKind, WorkoutSample;

import 'package:repit/core/messwert.dart';
import 'package:repit/data/cache.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_types.dart';
import 'package:repit/shell/ausdauer_view.dart';
import 'package:repit/shell/router.dart';

import '../design/support.dart' show textOf;
import '../health/health_reading_attrappe.dart';

/// Tests für die **Zonen und ihre Verteilung** auf dem Ausdauer-Schirm
/// (#95, mit #16) — die Lücke, die `ausdauer_view_test.dart` offen lässt.
/// Drei Funde des Zweig-Reviews vom 24.11.2026 stehen hier als Fälle:
///
/// 1. **Die angezeigten Zonengrenzen überlappen nicht.** Der Kern rechnet
///    je Zone `lower` und `upper` aus derselben Grenze
///    (`zone[n].upper == zone[n+1].lower`, `heart_rate_zones.dart`), und
///    `ZoneDistribution._zoneOf` schlägt einen Puls auf einer Grenze der
///    **oberen** Zone zu. Eine Anzeige, die dieselbe bpm-Zahl in zwei
///    Zonen nennt, widerspricht der eigenen Zählung — und die
///    Watch-Anleitung darunter trüge die Abweichung ins Gerät.
///    **Der Kern bleibt, wie er ist** (seine Tests nageln ihn fest); das
///    ist eine Anforderung an die Darstellung.
/// 2. **„noch keine Pulswerte" steht nur, wenn ein Lauf das wirklich
///    ergeben hat** — nicht während des Ladens und nicht nach einem
///    Fehler. Beides wäre `01`: Ladezustand als Leerstand.
/// 3. **Der Vorlesetext der Verteilungsbalken sagt dasselbe.** „keine
///    Laufzeit" ist eine Auskunft über die Daten; über einem Platzhalter
///    und nach einem Fehler gibt es keine.
///
/// Diese Datei entstand **vor** dem Fix und legt sein Verhalten fest
/// (`CLAUDE.md`, „Wer Tests schreibt, schreibt nicht die
/// Implementierung"). Geprüft werden Zustände und Übergänge, nicht Layout
/// und nicht die Formeln — die liegen im Kern.
///
/// **Alle Zahlen hier sind erfunden** und keine echten Gesundheitswerte.
void main() {
  // Dienstag, 17.11.2026, 14:32 Berliner Zeit (CET, +1).
  final jetzt = DateTime.utc(2026, 11, 17, 13, 32);
  final heute = BerlinCalendar.startOfDay(jetzt);

  String schluesselVor(int tage) =>
      BerlinCalendar.dayKey(BerlinCalendar.addDays(heute, -tage));

  /// Zehn Tage mit Ruhepuls (für den Median) und VO₂max der Watch.
  List<DailyMetrics> tageMitWerten() => [
    for (var t = 9; t >= 0; t--)
      DailyMetrics(
        tag: schluesselVor(t),
        steps: 6000 + t,
        restingHR: 55 + (t % 3),
        vo2max: t.isEven ? 45.4 - t * 0.2 : null,
      ),
  ];

  /// Ein Lauf je Zone-Nachbarschaft, damit die Verteilung Anteile trägt.
  List<WorkoutSample> laeufe() => [
    for (var t = 1; t <= 4; t++)
      WorkoutSample(
        id: 'lauf-$t',
        start: BerlinCalendar.addDays(
          heute,
          -t,
        ).add(const Duration(hours: 10)),
        kind: WorkoutKind.running,
        minutes: 30 + t * 5,
        km: 5.0 + t,
        avgHR: 140 + t * 6,
      ),
  ];

  ({ProviderContainer container, AppRouter router, Widget app}) harness({
    List<DailyMetrics>? tage,
    List<WorkoutSample>? workouts,
    Messwert<List<DailyMetrics>>? tageswerte,
  }) {
    final router = AppRouter();
    final db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);

    final container = ProviderContainer(
      // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
      retry: (_, _) => null,
      overrides: [
        clockProvider.overrideWithValue(() => jetzt),
        appCacheProvider.overrideWithValue(db),
        healthProvider.overrideWithValue(
          _FakeHealthReading(tage ?? tageMitWerten(), workouts ?? laeufe()),
        ),
        if (tageswerte != null)
          dailyMetricsProvider.overrideWith(() => _Tageswerte(tageswerte)),
      ],
    );
    addTearDown(container.dispose);

    return (
      container: container,
      router: router,
      app: UncontrolledProviderScope(
        container: container,
        child: CupertinoApp(
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(padding: const EdgeInsets.only(top: 47, bottom: 34)),
              child: AusdauerView(router: router),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> zeige(WidgetTester tester, Widget app) async {
    tester.view.physicalSize = const Size(900, 6200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
  }

  String textUnter(WidgetTester tester, Key key) => tester
      .widgetList<Text>(
        find.descendant(of: find.byKey(key), matching: find.byType(Text)),
      )
      .map(textOf)
      .join(' ');

  /// Die Vorlesetexte der Verteilungsbalken — gelesen am `Semantics`-Widget
  /// selbst, damit dafür nicht der Semantik-Baum eingeschaltet werden muss.
  List<String> vorlesetexte(WidgetTester tester) => [
    for (final semantik in tester.widgetList<Semantics>(
      find.descendant(
        of: find.byKey(const Key('ausdauer-verteilung')),
        matching: find.byType(Semantics),
      ),
    ))
      if (semantik.properties.label case final label?) label,
  ];

  /// Die angezeigten Zonengrenzen als Paare, in der Reihenfolge der Karte.
  List<(int von, int bis)> angezeigteZonen(WidgetTester tester) => [
    for (final treffer in RegExp(
      r'(\d+)–(\d+) bpm',
    ).allMatches(textUnter(tester, const Key('ausdauer-zonen'))))
      (int.parse(treffer.group(1)!), int.parse(treffer.group(2)!)),
  ];

  // ───────────────────────────────────────────────────────────────────────

  group('Die angezeigten Zonengrenzen überlappen nicht', () {
    testWidgets('keine bpm-Zahl steht in zwei Zonen', (tester) async {
      final h = harness();
      await zeige(tester, h.app);

      final zonen = angezeigteZonen(tester);
      expect(zonen, hasLength(5), reason: 'fünf Zonen, fünf Bereiche');

      for (var i = 0; i < zonen.length; i++) {
        expect(
          zonen[i].$1,
          lessThan(zonen[i].$2),
          reason: 'Zone ${i + 1} läuft aufwärts',
        );
      }
      for (var i = 0; i < zonen.length - 1; i++) {
        expect(
          zonen[i].$2,
          lessThan(zonen[i + 1].$1),
          reason:
              'die Obergrenze von Zone ${i + 1} liegt unter der Untergrenze '
              'von Zone ${i + 2} — dieselbe bpm-Zahl in zwei Zonen '
              'widerspräche der eigenen Zählung, die einen Puls auf der '
              'Grenze der oberen Zone zuschlägt',
        );
      }
    });

    testWidgets('die Watch-Anleitung nennt genau die angezeigten '
        'Obergrenzen', (tester) async {
      final h = harness();
      await zeige(tester, h.app);

      final zonen = angezeigteZonen(tester);
      final anleitung = textUnter(
        tester,
        const Key('ausdauer-watch-schritte'),
      );

      // Die Watch kennt die Obergrenzen der Zonen 1 bis 4; die fünfte
      // ergibt sich.
      for (var i = 0; i < 4; i++) {
        expect(
          anleitung,
          contains('Zone ${i + 1} bis ${zonen[i].$2}'),
          reason:
              'was der Schirm als Obergrenze zeigt, muss auch in die Watch '
              'eingetragen werden — sonst zählen beide verschieden',
        );
      }
    });
  });

  group('„noch keine Pulswerte" steht nur, wenn es stimmt (01)', () {
    testWidgets('nicht während des Ladens', (tester) async {
      final h = harness(tageswerte: const NochNie<List<DailyMetrics>>());
      await zeige(tester, h.app);

      expect(
        textUnter(tester, const Key('ausdauer-zonen')).toLowerCase(),
        isNot(contains('noch keine pulswerte')),
        reason:
            'ob Pulswerte vorliegen, weiß die App beim Laden nicht — das '
            'ist ein Ladezustand, kein Leerstand (Fehler 01)',
      );
    });

    testWidgets('nicht nach einem gescheiterten Lauf', (tester) async {
      final h = harness(
        tageswerte: Fehlgeschlagen<List<DailyMetrics>>(
          fehler: StateError('kaputt'),
          gelaufen: jetzt,
        ),
      );
      await zeige(tester, h.app);

      expect(
        textUnter(tester, const Key('ausdauer-zonen')).toLowerCase(),
        isNot(contains('noch keine pulswerte')),
        reason:
            'ein Fehler ist keine Aussage über die Datenlage (CLAUDE.md)',
      );
    });

    testWidgets('aber nach einem leeren Lauf schon', (tester) async {
      final h = harness(
        tage: [DailyMetrics(tag: schluesselVor(0), steps: 9600)],
        workouts: const [],
      );
      await zeige(tester, h.app);

      expect(
        textUnter(tester, const Key('ausdauer-zonen')).toLowerCase(),
        contains('noch keine pulswerte'),
        reason:
            'der Lauf ist fertig und hat keine Pulswerte gebracht — das ist '
            'der eine Zustand, der den Grund nennen darf',
      );
    });
  });

  group('Der Vorlesetext der Verteilungsbalken nennt den Zustand', () {
    testWidgets('beim Laden „wird geladen", nicht „keine Laufzeit"', (
      tester,
    ) async {
      final h = harness(tageswerte: const NochNie<List<DailyMetrics>>());
      await zeige(tester, h.app);

      final texte = vorlesetexte(tester);
      expect(texte, isNotEmpty, reason: 'sonst prüft das nichts');
      for (final text in texte) {
        expect(
          text.toLowerCase(),
          isNot(contains('keine laufzeit')),
          reason:
              'über einem Platzhalter steht keine Auskunft über die Daten '
              '(Fehler 01) — der Vorlesetext nennt den Zustand',
        );
      }
      expect(
        texte.where((t) => t.toLowerCase().contains('wird geladen')),
        isNotEmpty,
      );
    });

    testWidgets('nach einem Fehler nicht „keine Laufzeit"', (tester) async {
      final h = harness(
        tageswerte: Fehlgeschlagen<List<DailyMetrics>>(
          fehler: StateError('kaputt'),
          gelaufen: jetzt,
        ),
      );
      await zeige(tester, h.app);

      final texte = vorlesetexte(tester);
      expect(texte, isNotEmpty, reason: 'sonst prüft das nichts');
      for (final text in texte) {
        expect(text.toLowerCase(), isNot(contains('keine laufzeit')));
      }
    });

    testWidgets('nach einem leeren Lauf „keine Laufzeit"', (tester) async {
      final h = harness(
        tage: [DailyMetrics(tag: schluesselVor(0), steps: 9600)],
        workouts: const [],
      );
      await zeige(tester, h.app);

      expect(
        vorlesetexte(
          tester,
        ).where((t) => t.toLowerCase().contains('keine laufzeit')),
        isNotEmpty,
        reason:
            'hier ist es die Wahrheit: Der Lauf ist fertig, es gibt keine '
            'gemessene Laufzeit',
      );
    });
  });
}

// ─────────────────────────────────────────────────────────────────────────

class _Tageswerte extends DailyMetricsNotifier {
  _Tageswerte(this.wert);

  final Messwert<List<DailyMetrics>> wert;

  @override
  Future<Messwert<List<DailyMetrics>>> build() async => wert;
}

class _FakeHealthReading extends HealthReadingAttrappe {
  _FakeHealthReading(this._tage, this._workouts);

  final List<DailyMetrics> _tage;
  final List<WorkoutSample> _workouts;

  @override
  DateTime get earliestPermittedDate => DateTime.utc(2000);

  @override
  Future<List<DailyMetrics>> dailyMetrics(
    DateTime from,
    DateTime through,
  ) async => _tage;

  @override
  Future<List<WorkoutSample>> workouts(
    DateTime from,
    DateTime through,
  ) async => _workouts;
}
