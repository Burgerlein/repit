import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/core/messwert.dart';
import 'package:repit/data/cache.dart';
import 'package:repit/data/ernaehrung_repository.dart';
import 'package:repit/data/stammdaten.dart';
import 'package:repit/ernaehrung/ernaehrung_kalender.dart';
import 'package:repit/ernaehrung/ernaehrung_provider.dart';
import 'package:repit/ernaehrung/ernaehrung_view.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_types.dart';

import '../health/health_reading_attrappe.dart';
import '../tag/behaelter_im_baum.dart';

/// Tests für den **Kalender** des Ernährungs-Tags (#409) —
/// `lib/ernaehrung/ernaehrung_kalender.dart`.
///
/// Vorlage ist der Schlaf-Kalender (Tim, 07.11.2026: „Kalender-Icon wie
/// bei Schlaf"), gezeichnet in `docs/screens/screens/ernaehrung.js`,
/// Zustand `kalender`. Ein Agent schreibt Test und Implementierung
/// (`CLAUDE.md`, Widget-Tests für Zustände und Übergänge); diese Datei
/// entsteht zuerst, wird rot gesehen und committet.
///
/// ## Festgelegte öffentliche API
///
/// ```dart
/// /// Was der Ring eines Tages zeigt. Werttyp mit `==`.
/// class KalenderRingWert {
///   /// Gegessen durch Ziel, auf 0 bis 1 gedeckelt.
///   final double anteil;
///   /// Mehr gegessen als das Ziel.
///   final bool ueber;
///   /// Einträge da, aber kein Ziel für diesen Tag — gestrichelt.
///   final bool ohneZiel;
/// }
///
/// /// Die eine Stelle, an der ein Tag seinen Ring bekommt. `null` heißt
/// /// **gar kein Ring**: Zukunft, oder die Summen sind noch nicht gelesen.
/// KalenderRingWert? ernaehrungKalenderRing({
///   required String tag,
///   required String heute,
///   required bool gelesen,
///   Naehrwerte? summe,   // `null`: an diesem Tag nichts eingetragen
///   double? ziel,
/// });
///
/// class ErnaehrungKalenderKnopf  // Key('ernaehrung-kalender-knopf')
/// class ErnaehrungKalenderblatt  // Key('ernaehrung-kalenderblatt')
/// class KalenderAnteilRing { final KalenderRingWert wert; }
/// ```
///
/// Tageszellen: `Key('ernaehrung-kalender-tag-<ISO-Tag>')`; Monatspfeile:
/// `Key('ernaehrung-kalender-monat-frueher' | '-spaeter')` — dieselbe Form
/// wie beim Schlaf, aus demselben Baustein.
///
/// Alle Zahlen erfunden.
void main() {
  // Dienstag, 14.07.2026, 12:00 Berliner Zeit (MESZ, +2).
  final jetzt = DateTime.utc(2026, 7, 14, 10);
  const heute = '2026-07-14';

  const vollstaendig = Stammdaten(
    groesseCm: 180,
    geburtsjahr: 1990,
    zielgewichtKg: 84,
    zieldatum: '2027-01-14',
  );

  /// Tageswerte für jeden Tag vom 01.06. bis heute — damit jeder Tag ein
  /// gerechnetes Ziel hat und kein Fall an einer Lücke hängt.
  List<DailyMetrics> tageswerte() => [
    for (
      var d = DateTime.utc(2026, 6, 1);
      !d.isAfter(DateTime.utc(2026, 7, 14));
      d = d.add(const Duration(days: 1))
    )
      DailyMetrics(
        tag:
            '${d.year}-${d.month.toString().padLeft(2, '0')}-'
            '${d.day.toString().padLeft(2, '0')}',
        activeKcal: 600,
        basalKcal: 1600,
        weightKg: 80,
      ),
  ];

  Eintrag eintrag(String tag, double kcal) => Eintrag(
    tagesSchluessel: tag,
    mahlzeit: Mahlzeit.mittag,
    zeitpunkt: DateTime.utc(2026, 7, 14, 10),
    name: 'Testgericht',
    naehrwerte: Naehrwerte(
      kcal: kcal,
      eiweissG: 100,
      kohlenhydrateG: 150,
      fettG: 40,
    ),
  );

  ({ProviderContainer container, AppCache db, Widget app}) harness({
    Stammdaten stammdaten = vollstaendig,
    Messwert<List<DailyMetrics>>? metriken,
  }) {
    final db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);

    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        appCacheProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => jetzt),
        healthProvider.overrideWithValue(_StilleQuelle()),
        stammdatenProvider.overrideWith(() => _Stammdaten(stammdaten)),
        dailyMetricsProvider.overrideWith(
          () => _Tageswerte(
            metriken ??
                Bekannt<List<DailyMetrics>>(
                  tageswerte(),
                  stand: jetzt,
                  laeuft: false,
                ),
          ),
        ),
        fremdeMahlzeitenProvider.overrideWith2(
          (tag) => _Fremde(
            Bekannt<List<FremdeMahlzeit>>(
              const [],
              stand: jetzt,
              laeuft: false,
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    return (
      container: container,
      db: db,
      app: BehaelterImBaum(
        container: container,
        child: const CupertinoApp(
          home: CupertinoPageScaffold(
            navigationBar: CupertinoNavigationBar(
              middle: Text('Ernährung'),
              trailing: ErnaehrungKalenderKnopf(),
            ),
            child: ErnaehrungView(),
          ),
        ),
      ),
    );
  }

  Future<void> oeffne(WidgetTester tester, Widget app) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ernaehrung-kalender-knopf')));
    await tester.pumpAndSettle();
  }

  Finder zelle(String tag) => find.byKey(Key('ernaehrung-kalender-tag-$tag'));

  KalenderRingWert? ring(WidgetTester tester, String tag) {
    final ringe = find.descendant(
      of: zelle(tag),
      matching: find.byType(KalenderAnteilRing),
    );
    if (ringe.evaluate().isEmpty) return null;
    return tester.widget<KalenderAnteilRing>(ringe).wert;
  }

  double zielAm(
    ({ProviderContainer container, AppCache db, Widget app}) h,
    String tag,
  ) => h.container.read(ernaehrungsTagProvider(tag)).zielKcal!;

  // ───────────────────────────────────────────────────────────────────────

  group('ernaehrungKalenderRing (ohne Widget)', () {
    const summe = Naehrwerte(kcal: 900);

    test(
      'solange die Summen nicht gelesen sind, trägt kein Tag einen Ring',
      () {
        expect(
          ernaehrungKalenderRing(
            tag: '2026-07-10',
            heute: heute,
            gelesen: false,
            ziel: 1800,
          ),
          isNull,
          reason:
              'ein leerer Ring hieße „nichts eingetragen" — eine Aussage über '
              'eine Abfrage, die noch läuft (Fehler 01)',
        );
      },
    );

    test('die Zukunft trägt keinen Ring', () {
      expect(
        ernaehrungKalenderRing(
          tag: '2026-07-15',
          heute: heute,
          gelesen: true,
          summe: summe,
          ziel: 1800,
        ),
        isNull,
      );
    });

    test('ein Tag ohne Einträge hat einen leeren Ring, keinen fehlenden', () {
      final wert = ernaehrungKalenderRing(
        tag: '2026-07-10',
        heute: heute,
        gelesen: true,
        ziel: 1800,
      );
      expect(wert, isNotNull);
      expect(wert!.anteil, 0);
      expect(wert.ohneZiel, isFalse);
    });

    test('der Anteil ist gegessen durch Ziel, gedeckelt', () {
      expect(
        ernaehrungKalenderRing(
          tag: heute,
          heute: heute,
          gelesen: true,
          summe: summe,
          ziel: 1800,
        )!.anteil,
        closeTo(0.5, 1e-9),
      );
      final ueber = ernaehrungKalenderRing(
        tag: heute,
        heute: heute,
        gelesen: true,
        summe: const Naehrwerte(kcal: 2700),
        ziel: 1800,
      )!;
      expect(ueber.anteil, 1);
      expect(ueber.ueber, isTrue);
    });

    test('Einträge ohne Ziel sind „kein Ziel", nicht 0 % und nicht 100 %', () {
      final wert = ernaehrungKalenderRing(
        tag: heute,
        heute: heute,
        gelesen: true,
        summe: summe,
      )!;
      expect(wert.ohneZiel, isTrue);
      expect(wert.anteil, 0);
    });
  });

  group('Das Kalenderblatt', () {
    testWidgets('der Knopf öffnet es, im Monat des offenen Tags', (
      tester,
    ) async {
      final h = harness();
      await oeffne(tester, h.app);

      expect(find.byKey(const Key('ernaehrung-kalenderblatt')), findsOneWidget);
      expect(zelle(heute), findsOneWidget);
      expect(zelle('2026-07-01'), findsOneWidget);
    });

    testWidgets('je Tag ein Ring mit dem Anteil gegessen/Ziel', (tester) async {
      final h = harness();
      final repo = ErnaehrungRepository(h.db);
      await repo.buche(eintrag('2026-07-10', 1200));
      await repo.buche(eintrag('2026-07-12', 4000));
      await oeffne(tester, h.app);

      final zehnter = ring(tester, '2026-07-10');
      expect(zehnter, isNotNull);
      expect(zehnter!.anteil, closeTo(1200 / zielAm(h, '2026-07-10'), 1e-9));
      expect(zehnter.ueber, isFalse);

      final zwoelfter = ring(tester, '2026-07-12')!;
      expect(zwoelfter.anteil, 1, reason: 'gedeckelt dargestellt');
      expect(zwoelfter.ueber, isTrue);

      final elfter = ring(tester, '2026-07-11');
      expect(elfter, isNotNull, reason: 'ohne Einträge: leerer Ring');
      expect(elfter!.anteil, 0);

      expect(
        ring(tester, '2026-07-20'),
        isNull,
        reason: 'die Zukunft trägt keinen Ring',
      );
    });

    testWidgets('ohne Ziel steht ein Tag mit Einträgen als „kein Ziel" da', (
      tester,
    ) async {
      final h = harness(
        stammdaten: const Stammdaten(),
        metriken: LeerNachLauf<List<DailyMetrics>>(gelaufen: jetzt),
      );
      await ErnaehrungRepository(h.db).buche(eintrag('2026-07-10', 1200));
      await oeffne(tester, h.app);

      final wert = ring(tester, '2026-07-10')!;
      expect(wert.ohneZiel, isTrue);
      expect(wert.anteil, 0);
    });

    testWidgets('ein Tipp auf einen Tag öffnet ihn und schließt das Blatt', (
      tester,
    ) async {
      final h = harness();
      await ErnaehrungRepository(h.db).buche(eintrag('2026-07-10', 1200));
      await oeffne(tester, h.app);

      await tester.tap(zelle('2026-07-10'));
      await tester.pumpAndSettle();

      expect(h.container.read(offenerTagProvider), '2026-07-10');
      expect(find.byKey(const Key('ernaehrung-kalenderblatt')), findsNothing);
    });

    testWidgets('ein Tag in der Zukunft ist stumm', (tester) async {
      final h = harness();
      await oeffne(tester, h.app);

      await tester.tap(zelle('2026-07-20'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(h.container.read(offenerTagProvider), heute);
      expect(find.byKey(const Key('ernaehrung-kalenderblatt')), findsOneWidget);
    });

    testWidgets('nach vorn ist im laufenden Monat Schluss, nach hinten geht '
        'es in den Vormonat — mit dessen Einträgen', (tester) async {
      final h = harness();
      await ErnaehrungRepository(h.db).buche(eintrag('2026-06-20', 1200));
      await oeffne(tester, h.app);

      expect(
        tester
            .widget<CupertinoButton>(
              find.byKey(const Key('ernaehrung-kalender-monat-spaeter')),
            )
            .onPressed,
        isNull,
      );

      await tester.tap(
        find.byKey(const Key('ernaehrung-kalender-monat-frueher')),
      );
      await tester.pumpAndSettle();

      expect(zelle('2026-06-20'), findsOneWidget);
      expect(zelle(heute), findsNothing);
      final wert = ring(tester, '2026-06-20')!;
      expect(wert.anteil, closeTo(1200 / zielAm(h, '2026-06-20'), 1e-9));
    });
  });
}

class _Tageswerte extends DailyMetricsNotifier {
  _Tageswerte(this.wert);

  final Messwert<List<DailyMetrics>> wert;

  @override
  Future<Messwert<List<DailyMetrics>>> build() async => wert;
}

class _Stammdaten extends StammdatenNotifier {
  _Stammdaten(this.wert);

  final Stammdaten wert;

  @override
  Future<Stammdaten> build() async => wert;
}

class _Fremde extends FremdeMahlzeitenNotifier {
  _Fremde(this.wert) : super('');

  final Messwert<List<FremdeMahlzeit>> wert;

  @override
  Future<Messwert<List<FremdeMahlzeit>>> build() async => wert;
}

class _StilleQuelle extends HealthReadingAttrappe {}
