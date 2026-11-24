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
import 'package:repit/design/zahlen.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_types.dart';
import 'package:repit/shell/ausdauer_view.dart';
import 'package:repit/shell/router.dart';

import '../design/support.dart' show textOf;
import '../health/health_reading_attrappe.dart';

/// Tests für die **Oberfläche** des Ausdauer-Schirms (#95, mit #16) —
/// `lib/shell/ausdauer_view.dart`. Der Zustand darunter liegt in
/// `lib/shell/ausdauer_zustand.dart`.
///
/// Grundlage ist der Entwurf `docs/screens/screens/ausdauer.js` (a4077f3,
/// Zustände `werte`/`laufband`/`leer`) und `docs/SPEC.md` 4.7. Vorbild für
/// Schnitt und Stil ist `messung_detail_view_test.dart`. Diese Datei
/// entstand **vor** der Implementierung und legt deren öffentliche API fest
/// (`CLAUDE.md`, „Wer Tests schreibt, schreibt nicht die Implementierung").
///
/// ## Festgelegte öffentliche API
///
/// ```dart
/// // lib/shell/ausdauer_view.dart
/// /// Öffnet den Ausdauer-Schirm auf dem Stapel des **aktuell gewählten**
/// /// Tabs — gerufen aus `MehrView`.
/// void oeffneAusdauer(AppRouter router);
///
/// /// Der Rahmen: Gerüst und Navigationsleiste um [AusdauerView].
/// class AusdauerSeite extends StatelessWidget {
///   const AusdauerSeite({super.key, required AppRouter router});
/// }
///
/// /// Der Schirm selbst — ohne Gerüst, ohne Leiste, ohne Navigator.
/// class AusdauerView extends ConsumerWidget {
///   const AusdauerView({super.key, required AppRouter router});
/// }
/// ```
///
/// ## Die Schlüssel, unter denen die Abschnitte stehen
///
/// | Schlüssel | Was |
/// |---|---|
/// | `ausdauer-laden` | die Standzeile im Ladezustand ([NochNie]) |
/// | `ausdauer-fehler` | die Standzeile nach gescheitertem Lauf |
/// | `ausdauer-grund` | der „keine Daten"-Kasten, **nur** bei [LeerNachLauf] |
/// | `ausdauer-watch` | die Kachel „Watch" |
/// | `ausdauer-eigene` | die Kachel „Eigene Schätzung" |
/// | `ausdauer-einordnung` | die Karte Einordnung/Trend |
/// | `ausdauer-diagramm` | der VO₂max-Verlauf (Leiste M 6M J) |
/// | `ausdauer-prognose` | die Karte Halbmarathon-Prognose |
/// | `ausdauer-zielzeit` | die Zeile „Zielzeit" (Tür auf Ziele) |
/// | `ausdauer-kadenz` | die Karte Kadenz |
/// | `ausdauer-erholungspuls` | die Karte Erholungspuls |
/// | `ausdauer-zonen` | die Karte Herzfrequenz-Zonen |
/// | `ausdauer-verteilung` | die Verteilung der Laufzeit |
/// | `ausdauer-watch-schritte` | die Anleitung „Apple Watch einstellen" |
///
/// ## Worauf diese Datei zielt
///
/// Zustände und Übergänge (`CLAUDE.md`, „Tests"):
///
/// - Während des Ladens steht **nie** ein „keine Daten"-Grund (`01`).
/// - Ein Wert, der dastand, steht nach dem Zurücknavigieren wieder da
///   (`32`).
/// - Der Leerzustand hat **dieselben Abschnitte** wie der gefüllte —
///   formgleich, `–/–` statt weggelassener Karten (Entwurf, Variante
///   `leer`).
/// - Der Laufband-Zustand (kein Watch-Wert, eigene Schätzung trägt) nennt
///   die Herkunft (Entwurf, Variante `laufband`).
/// - **Die Kadenz-Karte bleibt ehrlich leer**: Der Kanal liefert weder
///   Schrittfrequenz noch Schritte im Lauf-Fenster; eine Behelfsrechnung
///   aus Stundenschritten darf es nicht geben (Auftrag #95). Der Test gibt
///   der Attrappe absichtlich Stundenschritte und erwartet trotzdem keine
///   Kadenz-Zahl.
/// - **Keine Zielzeit im Quelltext**: Ohne Wettkampf-Objekt zeigt die
///   Zeile `—` und führt auf den Ziele-Schirm (Issue #95, Fallstricke).
///
/// ## Was hier bewusst nicht geprüft wird
///
/// - **Formeln** (Daniels/Gilbert, VDOT, Karvonen, Verteilung): im Kern
///   geprüft. Hier zählt nur, dass ihre Ergebnisse ankommen.
/// - **Zahlen aus `docs/screens/`**: erfunden, nie Erwartungswert.
/// - **Layout, Schriftgrößen, Dynamic Type.**
///
/// **Alle Zahlen hier sind erfunden** und keine echten Gesundheitswerte.
void main() {
  // Dienstag, 17.11.2026, 14:32 Berliner Zeit (CET, +1).
  final jetzt = DateTime.utc(2026, 11, 17, 13, 32);
  final heute = BerlinCalendar.startOfDay(jetzt);

  String schluesselVor(int tage) =>
      BerlinCalendar.dayKey(BerlinCalendar.addDays(heute, -tage));

  /// Tageswerte: jeden zweiten Tag ein Watch-VO₂max, dazu Ruhepuls und
  /// Erholungspuls. Der jüngste Watch-Wert ist 46,4.
  List<DailyMetrics> tageMitWatch() => [
    for (var t = 9; t >= 0; t--)
      DailyMetrics(
        tag: schluesselVor(t),
        steps: 6000 + t,
        restingHR: 55 + (t % 3),
        recoveryHRDrop: t == 0 ? 27 : (t == 2 ? 23 : null),
        vo2max: t.isEven ? 45.4 - t * 0.2 + (t == 0 ? 1.0 : 0) : null,
      ),
  ];

  /// Dieselben Tage ohne einen einzigen Watch-Wert — der Laufband-Fall.
  List<DailyMetrics> tageOhneWatch() => [
    for (final tag in tageMitWatch())
      DailyMetrics(
        tag: tag.tag,
        steps: tag.steps,
        restingHR: tag.restingHR,
        recoveryHRDrop: tag.recoveryHRDrop,
      ),
  ];

  /// Tage, die der Lauf geliefert hat, aber ohne VO₂max — zusammen mit
  /// „keine Läufe" ist das der Leerzustand des Schirms.
  List<DailyMetrics> tageOhneAusdauer() => [
    DailyMetrics(tag: schluesselVor(1), steps: 8200),
    DailyMetrics(tag: schluesselVor(0), steps: 9600),
  ];

  WorkoutSample lauf({
    required int tageZurueck,
    required double minuten,
    double? km,
    int? avgHR,
    WorkoutKind kind = WorkoutKind.running,
  }) => WorkoutSample(
    id: 'lauf-$tageZurueck-$kind',
    start: BerlinCalendar.addDays(heute, -tageZurueck).add(
      const Duration(hours: 10),
    ),
    kind: kind,
    minutes: minuten,
    km: km,
    avgHR: avgHR,
  );

  /// Drei Läufe mit Puls und km, dazu ein Laufband-Lauf ohne km (jüngster)
  /// und ein Radtraining, das nirgends mitzählen darf.
  List<WorkoutSample> laeufe() => [
    lauf(tageZurueck: 1, minuten: 32, avgHR: 150), // Laufband, ohne km
    lauf(tageZurueck: 2, minuten: 40, km: 7.0, avgHR: 148),
    lauf(tageZurueck: 4, minuten: 55, km: 9.2, avgHR: 152),
    lauf(tageZurueck: 6, minuten: 25, km: 4.1, avgHR: 139),
    lauf(tageZurueck: 3, minuten: 60, km: 20, kind: WorkoutKind.cycling),
  ];

  /// Die eigene Schätzung, die der Schirm zeigen muss: der **jüngste Lauf
  /// mit km und ≥ 3 Minuten** — der Laufband-Lauf ohne km zählt nicht.
  double erwarteteEigene() =>
      VO2MaxEstimate.fromRun(km: 7.0, minutes: 40)!;

  // ───────────────────────────────────────────────────────────────────────

  ({ProviderContainer container, AppRouter router, Widget app}) harness({
    List<DailyMetrics>? tage,
    List<WorkoutSample>? workouts,
    Messwert<List<DailyMetrics>>? tageswerte,
    bool mitSeite = false,
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
          _FakeHealthReading(tage ?? tageMitWatch(), workouts ?? laeufe()),
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
              child: mitSeite
                  ? AusdauerSeite(router: router)
                  : AusdauerView(router: router),
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

  String alleTexte(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map(textOf)
      .join(' ')
      .toLowerCase();

  String textUnter(WidgetTester tester, Key key) => tester
      .widgetList<Text>(
        find.descendant(of: find.byKey(key), matching: find.byType(Text)),
      )
      .map(textOf)
      .join(' ');

  /// Die Abschnitte, die in **jedem** Zustand stehen — die Formgleichheit
  /// des Entwurfs (`werte`/`laufband`/`leer`: dieselben Abschnitte,
  /// dieselbe Reihenfolge, `–/–` statt weggelassener Karten).
  const abschnitte = [
    Key('ausdauer-watch'),
    Key('ausdauer-eigene'),
    Key('ausdauer-einordnung'),
    Key('ausdauer-diagramm'),
    Key('ausdauer-prognose'),
    Key('ausdauer-zielzeit'),
    Key('ausdauer-kadenz'),
    Key('ausdauer-erholungspuls'),
    Key('ausdauer-zonen'),
    Key('ausdauer-verteilung'),
    Key('ausdauer-watch-schritte'),
  ];

  void erwarteAlleAbschnitte(WidgetTester tester) {
    for (final key in abschnitte) {
      expect(find.byKey(key), findsOneWidget, reason: 'Abschnitt $key fehlt');
    }
  }

  // ───────────────────────────────────────────────────────────────────────

  group('Hausordnung', () {
    testWidgets('der Schirm bringt weder Gerüst noch Leiste mit', (
      tester,
    ) async {
      final h = harness();
      await zeige(tester, h.app);

      expect(find.byType(CupertinoPageScaffold), findsNothing);
      expect(find.byType(CupertinoNavigationBar), findsNothing);
      expect(
        find.descendant(
          of: find.byType(AusdauerView),
          matching: find.byType(Navigator),
        ),
        findsNothing,
      );
    });

    testWidgets('die Seite bringt beides mit', (tester) async {
      final h = harness(mitSeite: true);
      await zeige(tester, h.app);

      expect(find.byType(CupertinoPageScaffold), findsOneWidget);
      expect(find.byType(CupertinoNavigationBar), findsOneWidget);
    });
  });

  group('Laden (NochNie)', () {
    testWidgets('zeigt nie einen „keine Daten"-Grund — und trotzdem alle '
        'Abschnitte', (tester) async {
      final h = harness(tageswerte: const NochNie<List<DailyMetrics>>());
      await zeige(tester, h.app);

      expect(find.byKey(const Key('ausdauer-laden')), findsOneWidget);
      expect(find.byKey(const Key('ausdauer-grund')), findsNothing);

      final texte = alleTexte(tester);
      expect(texte, isNot(contains('keine werte')));
      expect(texte, isNot(contains('kein lauf')));
      expect(texte, isNot(contains('keine daten')));

      erwarteAlleAbschnitte(tester);
    });
  });

  group('Mit Werten (Entwurf „werte")', () {
    testWidgets('beide VO₂max-Zahlen stehen nebeneinander', (tester) async {
      final h = harness();
      await zeige(tester, h.app);

      expect(
        textUnter(tester, const Key('ausdauer-watch')),
        contains(formatNumber(46.4, nachkommastellen: 1)),
        reason: 'der jüngste Watch-Wert der Fixture ist 46,4',
      );
      expect(
        textUnter(tester, const Key('ausdauer-eigene')),
        contains(formatNumber(erwarteteEigene(), nachkommastellen: 1)),
        reason:
            'die eigene Schätzung kommt aus dem jüngsten Lauf mit km — '
            'der Laufband-Lauf ohne km zählt nicht',
      );
      expect(
        alleTexte(tester),
        contains('stand 14:32'),
        reason: 'Zuerst der Cache, dann HealthKit — die Standzeile fällt ab',
      );
    });

    testWidgets('die Prognose steht zweimal, die Zielzeit nie erfunden', (
      tester,
    ) async {
      final h = harness();
      await zeige(tester, h.app);

      final prognose = textUnter(tester, const Key('ausdauer-prognose'));
      expect(prognose.toLowerCase(), contains('potenzial'));
      expect(prognose.toLowerCase(), contains('realistisch'));
      expect(
        RegExp(r'\d:\d\d').allMatches(prognose).length,
        greaterThanOrEqualTo(2),
        reason: 'Potenzial und realistische Zahl stehen beide als Zeit da',
      );

      // Ohne Wettkampf-Objekt gibt es keine Zielzeit — und keine erfundene.
      final zielzeit = textUnter(tester, const Key('ausdauer-zielzeit'));
      expect(zielzeit, contains('—'));
      expect(
        find.descendant(
          of: find.byKey(const Key('ausdauer-zielzeit')),
          matching: find.byIcon(CupertinoIcons.chevron_right),
        ),
        findsOneWidget,
        reason: 'die Zeile ist die Tür auf den Ziele-Schirm',
      );
    });

    testWidgets('die Kadenz bleibt ehrlich leer — keine Behelfsrechnung '
        'aus Stundenschritten', (tester) async {
      final h = harness();
      await zeige(tester, h.app);

      final kadenz = textUnter(tester, const Key('ausdauer-kadenz'));
      expect(
        RegExp(r'\d{3}').hasMatch(kadenz),
        isFalse,
        reason:
            'der Kanal liefert keine Schrittfrequenz und keine Schritte im '
            'Lauf-Fenster — eine dreistellige Kadenz wäre erfunden '
            '(die Attrappe liefert absichtlich Stundenschritte)',
      );
      expect(kadenz, contains('—'));
    });

    testWidgets('die Verteilung nennt den 80-%-Satz', (tester) async {
      final h = harness();
      await zeige(tester, h.app);

      final texte = alleTexte(tester);
      expect(texte, contains('80'));
      expect(texte, contains('zone 1'));
      expect(texte, contains('zone 5'));
    });

    testWidgets('der Erholungspuls kommt aus den Tageswerten', (
      tester,
    ) async {
      final h = harness();
      await zeige(tester, h.app);

      expect(
        textUnter(tester, const Key('ausdauer-erholungspuls')),
        contains('27'),
        reason: 'der jüngste recoveryHRDrop der Fixture ist 27',
      );
    });
  });

  group('Ohne Watch-Wert (Entwurf „laufband")', () {
    testWidgets('die eigene Schätzung trägt, und das steht als Herkunft '
        'dran', (tester) async {
      final h = harness(tage: tageOhneWatch());
      await zeige(tester, h.app);

      // Die Kachel zeigt den fehlenden Wert als `–/–` (Hausregel „Eine
      // Anzeige, die es gibt, hat genau eine Form"), nie als `0`.
      expect(textUnter(tester, const Key('ausdauer-watch')), contains('–/–'));
      expect(
        textUnter(tester, const Key('ausdauer-eigene')),
        contains(formatNumber(erwarteteEigene(), nachkommastellen: 1)),
      );
      expect(
        alleTexte(tester),
        contains('aus der eigenen schätzung'),
        reason: 'Einordnung und Prognose rechnen aus der eigenen Schätzung, '
            'und das steht als Herkunft dran (Entwurf, Variante laufband)',
      );
      erwarteAlleAbschnitte(tester);
    });
  });

  group('Keine Werte (Entwurf „leer")', () {
    testWidgets('der Grund steht einmal, nennt beide Möglichkeiten — und '
        'alle Abschnitte stehen formgleich da', (tester) async {
      final h = harness(tage: tageOhneAusdauer(), workouts: const []);
      await zeige(tester, h.app);

      expect(find.byKey(const Key('ausdauer-grund')), findsOneWidget);
      final grund = textUnter(
        tester,
        const Key('ausdauer-grund'),
      ).toLowerCase();
      expect(grund, contains('health'));
      expect(
        grund,
        contains('freigabe'),
        reason:
            '„keine Daten" und „nicht erlaubt" sind nicht unterscheidbar — '
            'beide werden benannt (CLAUDE.md)',
      );

      erwarteAlleAbschnitte(tester);

      final texte = alleTexte(tester);
      expect(
        RegExp(r'(^|\s)0([,.]0)?(\s|$)').hasMatch(texte),
        isFalse,
        reason: '0 ist keine Antwort auf „kein Wert" (Fehler 01)',
      );
    });
  });

  group('Gescheiterter Lauf (Fehlgeschlagen)', () {
    testWidgets('ohne Cache: Fehlerzeile, aber kein „keine Daten"-Grund', (
      tester,
    ) async {
      final h = harness(
        tageswerte: Fehlgeschlagen<List<DailyMetrics>>(
          fehler: StateError('kaputt'),
          gelaufen: jetzt,
        ),
      );
      await zeige(tester, h.app);

      expect(find.byKey(const Key('ausdauer-fehler')), findsOneWidget);
      expect(find.byKey(const Key('ausdauer-grund')), findsNothing);
      erwarteAlleAbschnitte(tester);
    });
  });

  group('Übergänge', () {
    testWidgets('ein Wert, der dastand, steht nach dem Zurücknavigieren '
        'sofort wieder da (32)', (tester) async {
      final h = harness();

      tester.view.physicalSize = const Size(900, 6200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: h.container,
          child: CupertinoApp(
            home: Builder(
              builder: (context) => CupertinoPageScaffold(
                child: Center(
                  child: CupertinoButton(
                    key: const Key('test-tuer'),
                    onPressed: () => Navigator.of(context).push(
                      CupertinoPageRoute<void>(
                        builder: (_) => AusdauerSeite(router: h.router),
                      ),
                    ),
                    child: const Text('Ausdauer'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('test-tuer')));
      await tester.pumpAndSettle();
      final erwartet = formatNumber(46.4, nachkommastellen: 1);
      expect(
        textUnter(tester, const Key('ausdauer-watch')),
        contains(erwartet),
      );

      // Zurück — und wieder hin.
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('test-tuer')));
      // **Ein** Pump: Der gehaltene Zustand muss sofort dastehen, nicht
      // erst nach einem neuen Lauf.
      await tester.pump();
      await tester.pump();
      expect(
        textUnter(tester, const Key('ausdauer-watch')),
        contains(erwartet),
        reason: 'der Provider hält den Zustand — nichts lädt neu (32)',
      );
      expect(alleTexte(tester), isNot(contains('keine werte')));
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

  /// Absichtlich gefüllt: Die Kadenz darf trotzdem **nicht** aus
  /// Stundenschritten gerechnet werden (Auftrag #95).
  @override
  Future<List<QuantitySample>> hourlySteps(
    DateTime from,
    DateTime through,
  ) async => [QuantitySample(date: from, value: 1234)];
}
