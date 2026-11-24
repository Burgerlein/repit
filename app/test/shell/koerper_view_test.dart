import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/core/messwert.dart';
import 'package:repit/data/cache.dart';
import 'package:repit/data/cache_repository.dart';
import 'package:repit/design/glas_abstand.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_types.dart';
import 'package:repit/shell/koerper_view.dart';
import 'package:repit/shell/messung_detail_view.dart';
import 'package:repit/shell/messungen_view.dart';
import 'package:repit/shell/router.dart';

import '../design/support.dart' show textOf;
import '../health/health_reading_attrappe.dart';

/// Tests für die **Oberfläche** des Körper-Schirms (#82) —
/// `lib/shell/koerper_view.dart`. Der Zustand darunter liegt in
/// `koerper_zustand.dart` und ist in `koerper_zustand_test.dart` geprüft;
/// hier steht kein einziger Rechenwert noch einmal.
///
/// Grundlage sind der am 02.11.2026 von Tim freigegebene Entwurf
/// `docs/screens/screens/koerper.js` und
/// `docs/superpowers/specs/2026-11-02-koerper-und-messungen-design.md`,
/// Teil D. Vorbild für Schnitt und Stil ist `verlauf_view_test.dart`.
///
/// ## Festgelegte öffentliche API (`lib/shell/koerper_view.dart`)
///
/// ```dart
/// /// Öffnet den Körper-Schirm auf dem Stapel des **aktuell gewählten**
/// /// Tabs — die eine Stelle, die das weiß. Von dort ruft `MehrView`.
/// void oeffneKoerper(AppRouter router);
///
/// /// Der Rahmen: Gerüst und Navigationsleiste um [KoerperView].
/// class KoerperSeite extends StatelessWidget {
///   const KoerperSeite({super.key, required AppRouter router});
/// }
///
/// /// Der Schirm selbst — ohne Gerüst, ohne Leiste, ohne Navigator.
/// class KoerperView extends ConsumerWidget {
///   const KoerperView({super.key, required AppRouter router});
/// }
/// ```
///
/// ## Die Schlüssel, unter denen die Abschnitte stehen
///
/// | Schlüssel | Was |
/// |---|---|
/// | `koerper-kopfkarte` | die Gewichts-Kopfkarte, **eine Tür** |
/// | `koerper-kopfkarte-wert` | die große Zahl bzw. ihr Platzhalter |
/// | `koerper-kein-ziel` | „Kein Körperziel festgelegt" (#41 fehlt) |
/// | `koerper-grund` | der Grund, **einmal**, unter der Kopfkarte |
/// | `koerper-kacheln` | der Block „Auf einen Blick" als Ganzes |
/// | `koerper-kachel-koerperfett` | Kachel + Tür auf `messung-detail` |
/// | `koerper-kachel-muskelmasse` | Kachel + Tür auf `messung-detail` |
/// | `koerper-kachel-schritte` | Kachel, Tür auf den Platzhalter (#84) |
/// | `koerper-kachel-umfaenge` | Kachel, Tür auf den Platzhalter (#88) |
/// | `koerper-bereich-muskelkarte` | Zeile „Muskelkarte" (#96) |
/// | `koerper-bereich-schritte` | Zeile „Schritte" (#84) |
/// | `koerper-bereich-messungen` | Zeile „Messungen" → `MessungenSeite` |
/// | `koerper-bereich-umfaenge` | Zeile „Umfänge" (#88) |
/// | `koerper-laden` | der Ladezustand ([NochNie]) |
/// | `koerper-fehler` | der gescheiterte Lauf ([Fehlgeschlagen]) |
///
/// **Die Kacheln tragen ihren Schlüssel auf etwas Antippbarem.** Zwei von
/// ihnen sind Türen (`koerper.js`, Nachtrag vom 02.11.2026), und eine Tür,
/// die nur in der Mitte aufgeht, ist keine.
///
/// ## Worauf diese Datei zielt
///
/// `CLAUDE.md`, „Tests": Zustände und Übergänge, nicht Layout und
/// Beschriftung. Die beiden, auf die es ankommt:
///
/// 1. **Während des Ladens steht nie ein „keine Daten"-Grund** (`01`).
/// 2. **Ein Wert, der dastand, steht nach dem Zurücknavigieren wieder da**
///    (`32`).
///
/// Dazu, weil der Entwurf sie ausdrücklich verlangt: **Jede Anzeige behält
/// in beiden Zuständen dieselbe Form** — keine Kachel verschwindet, weil
/// ihr Wert fehlt („Eine Anzeige, die es gibt, hat genau eine Form"),
/// **`0` ist keine Antwort auf „kein Wert"**, und **der Grund steht
/// einmal**, nicht je Kachel.
///
/// ## Was hier bewusst **nicht** geprüft wird
///
/// - **Zahlen, Einheiten, Schreibweisen.** „82,4 kg" ist Beschriftung; die
///   Rechnung dahinter steht in `koerper_zustand_test.dart`.
/// - **Die Zahlen aus `docs/screens/`.** Sie sind erfunden (so sagt es
///   jeder Dateikopf dort) und dürfen nie Erwartungswert sein; die
///   Fixturen hier sind eigene.
/// - **Schriftgrößen und Dynamic Type.** `content_size` wird nirgends
///   verstellt.
void main() {
  // Montag, 12.10.2026, 09:15 Berliner Zeit (CEST, +2) — dieselbe Uhr wie
  // in `koerper_zustand_test.dart` und `verlauf_view_test.dart`.
  final jetzt = DateTime.utc(2026, 10, 12, 7, 15);
  final heute = BerlinCalendar.startOfDay(jetzt);

  /// Der Berliner Tagesbeginn von vor [tage] Tagen — über
  /// [BerlinCalendar.addDays], nie über `Duration(days: …)`.
  String schluesselVor(int tage) =>
      BerlinCalendar.dayKey(BerlinCalendar.addDays(heute, -tage));

  DailyMetrics messung(
    int tageZurueck, {
    double? gewicht,
    double? fett,
    double? fettfrei,
    int? ruhepuls,
    int? schritte,
  }) => DailyMetrics(
    tag: schluesselVor(tageZurueck),
    steps: schritte,
    restingHR: ruhepuls,
    weightKg: gewicht,
    bodyFatPct: fett,
    leanKg: fettfrei,
  );

  /// Drei Tage mit allen vier Messarten. Die Zahlen sind erfunden.
  List<DailyMetrics> mitWerten() => [
    messung(
      4,
      gewicht: 80.0,
      fett: 22.0,
      fettfrei: 60.0,
      ruhepuls: 55,
      schritte: 8200,
    ),
    messung(
      2,
      gewicht: 81.0,
      fett: 22.3,
      fettfrei: 61.0,
      ruhepuls: 56,
      schritte: 9100,
    ),
    messung(
      0,
      gewicht: 82.4,
      fett: 22.5,
      fettfrei: 62.1,
      ruhepuls: 57,
      schritte: 9600,
    ),
  ];

  /// Was der Cache einer App liefert, die nie eine Waage gesehen hat: Uhr
  /// und iPhone haben gemessen, die Waage nicht. Der Zustand ist damit
  /// [Bekannt] — ein Schirm, der drei Werte hat und wegen des vierten
  /// „keine Daten" sagt, wäre Fehler `01`.
  List<DailyMetrics> ohneWaage() => [
    messung(2, ruhepuls: 55, schritte: 8200),
    messung(0, ruhepuls: 57, schritte: 9600),
  ];

  // ───────────────────────────────────────────────────────────────────────

  ({ProviderContainer container, AppRouter router, Widget app}) harness({
    Messwert<List<DailyMetrics>>? tageswerte,
    bool mitSeite = false,
  }) {
    final router = AppRouter();
    final db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);

    // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        clockProvider.overrideWithValue(() => jetzt),
        appCacheProvider.overrideWithValue(db),
        healthProvider.overrideWithValue(_FakeHealthReading(const [])),
        dailyMetricsProvider.overrideWith(
          () => _Tageswerte(
            tageswerte ??
                Bekannt<List<DailyMetrics>>(
                  mitWerten(),
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
                  ? KoerperSeite(router: router)
                  : KoerperView(router: router),
            ),
          ),
        ),
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

  const kacheln = [
    Key('koerper-kachel-koerperfett'),
    Key('koerper-kachel-muskelmasse'),
    Key('koerper-kachel-schritte'),
    Key('koerper-kachel-umfaenge'),
  ];

  const bereiche = [
    Key('koerper-bereich-muskelkarte'),
    Key('koerper-bereich-schritte'),
    Key('koerper-bereich-messungen'),
    Key('koerper-bereich-umfaenge'),
  ];

  /// Tippt und holt den ausstehenden Navigationsbefehl ab.
  Future<AppRouterBefehl?> tippe(
    WidgetTester tester,
    AppRouter router,
    Key key,
  ) async {
    await tester.ensureVisible(find.byKey(key));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(key));
    await tester.pumpAndSettle();
    return router.nimmBefehl();
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
          of: find.byType(KoerperView),
          matching: find.byType(Navigator),
        ),
        findsNothing,
        reason:
            'Eine gepushte Ansicht bringt niemals ihren eigenen '
            'Navigationsstapel mit (`CLAUDE.md`)',
      );
    });

    testWidgets('die Seite bringt beides mit', (tester) async {
      final h = harness(mitSeite: true);
      await zeige(tester, h.app);

      expect(find.byType(CupertinoPageScaffold), findsOneWidget);
      expect(find.byType(CupertinoNavigationBar), findsOneWidget);
    });

    testWidgets('der Abstand kommt aus `GlasAbstand`', (tester) async {
      final h = harness();
      await zeige(tester, h.app);

      final scroll = tester.widget<SingleChildScrollView>(
        find.descendant(
          of: find.byType(KoerperView),
          matching: find.byType(SingleChildScrollView),
        ),
      );
      final erwartet = GlasAbstand.of(tester.element(find.byType(KoerperView)));
      expect(erwartet.top, greaterThan(0), reason: 'sonst prüft das nichts');
      expect((scroll.padding! as EdgeInsets).top, erwartet.top);
    });

    testWidgets('`oeffneKoerper` schiebt auf den Stapel des aktuellen Tabs', (
      tester,
    ) async {
      final h = harness();
      await zeige(tester, h.app);
      final tabVorher = h.router.tab;

      oeffneKoerper(h.router);
      final befehl = h.router.nimmBefehl();

      expect(befehl, isNotNull);
      expect(
        befehl!.tab,
        tabVorher,
        reason:
            'Nur die Tab-Fälle von `AppTarget` wechseln den Tab — sonst '
            'führte „zurück" in ein Menü, das der Nutzer nie geöffnet hat',
      );
      expect(befehl.ersetztStapel, isFalse);
    });
  });

  group('Eine Anzeige, die es gibt, hat genau eine Form', () {
    testWidgets('mit Werten stehen Kopfkarte, vier Kacheln und Bereiche da', (
      tester,
    ) async {
      final h = harness();
      await zeige(tester, h.app);

      expect(find.byKey(const Key('koerper-kopfkarte')), findsOneWidget);
      for (final key in kacheln) {
        expect(find.byKey(key), findsOneWidget, reason: '$key');
      }
      for (final key in bereiche) {
        expect(find.byKey(key), findsOneWidget, reason: '$key');
      }
    });

    testWidgets('ohne Waagenwerte verschwindet keine einzige davon', (
      tester,
    ) async {
      final h = harness(
        tageswerte: Bekannt<List<DailyMetrics>>(
          ohneWaage(),
          stand: jetzt,
          laeuft: false,
        ),
      );
      await zeige(tester, h.app);

      expect(
        find.byKey(const Key('koerper-kopfkarte')),
        findsOneWidget,
        reason:
            'Eine Anzeige verschwindet nicht, weil ihr Wert fehlt; sie '
            'steht ungefüllt da (`CLAUDE.md`)',
      );
      for (final key in kacheln) {
        expect(
          find.byKey(key),
          findsOneWidget,
          reason:
              '$key: fällt eine Kachel weg, teilen sich die übrigen ihren '
              'Platz — dann springt sogar die Breite',
        );
      }
      for (final key in bereiche) {
        expect(find.byKey(key), findsOneWidget, reason: '$key');
      }
    });

    testWidgets('auch ein leer ausgegangener Lauf lässt alles stehen', (
      tester,
    ) async {
      final h = harness(
        tageswerte: LeerNachLauf<List<DailyMetrics>>(gelaufen: jetzt),
      );
      await zeige(tester, h.app);

      expect(find.byKey(const Key('koerper-kopfkarte')), findsOneWidget);
      for (final key in kacheln) {
        expect(find.byKey(key), findsOneWidget, reason: '$key');
      }
      for (final key in bereiche) {
        expect(find.byKey(key), findsOneWidget, reason: '$key');
      }
    });

    testWidgets('wo ein Wert fehlt, steht keine Null', (tester) async {
      final h = harness(
        tageswerte: Bekannt<List<DailyMetrics>>(
          ohneWaage(),
          stand: jetzt,
          laeuft: false,
        ),
      );
      await zeige(tester, h.app);

      expect(
        textUnter(tester, const Key('koerper-kopfkarte-wert')),
        isNot(contains('0')),
        reason:
            'Ein Ring auf 0 behauptet „nichts getan" — das ist `01` in '
            'neuer Verpackung (`CLAUDE.md`)',
      );
      for (final key in const [
        Key('koerper-kachel-koerperfett'),
        Key('koerper-kachel-muskelmasse'),
      ]) {
        expect(
          RegExp(r'\d').hasMatch(textUnter(tester, key)),
          isFalse,
          reason:
              '$key: ohne Waage gibt es für Körperfett und Muskelmasse '
              'keine Zahl — auch keine 0,0',
        );
      }
    });
  });

  group('Der Grund steht einmal, nicht je Feld', () {
    testWidgets('ohne Waagenwerte steht er genau einmal', (tester) async {
      final h = harness(
        tageswerte: Bekannt<List<DailyMetrics>>(
          ohneWaage(),
          stand: jetzt,
          laeuft: false,
        ),
      );
      await zeige(tester, h.app);

      expect(
        find.byKey(const Key('koerper-grund')),
        findsOneWidget,
        reason:
            'Ein Hinweis in einer schmalen Spalte läuft über mehrere Zeilen '
            'und macht die Karte höher, sobald Werte fehlen',
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('koerper-kacheln')),
          matching: find.byKey(const Key('koerper-grund')),
        ),
        findsNothing,
        reason: 'der Grund gehört unter die Kopfkarte, nicht in die Kacheln',
      );
    });

    testWidgets('er nennt beide Möglichkeiten', (tester) async {
      final h = harness(
        tageswerte: Bekannt<List<DailyMetrics>>(
          ohneWaage(),
          stand: jetzt,
          laeuft: false,
        ),
      );
      await zeige(tester, h.app);

      final texte = alleTexte(tester);
      expect(
        texte.contains('waage') || texte.contains('apple health'),
        isTrue,
        reason: 'die eine Möglichkeit: es hat nichts geschrieben',
      );
      expect(
        texte.contains('freigabe') ||
            texte.contains('lesen') ||
            texte.contains('erlaub'),
        isTrue,
        reason:
            'die andere — Apple verrät den Lesestatus nicht, also müssen '
            'beide dastehen (`CLAUDE.md`)',
      );
    });

    testWidgets('mit Werten steht er nicht da', (tester) async {
      final h = harness();
      await zeige(tester, h.app);

      expect(find.byKey(const Key('koerper-grund')), findsNothing);
    });
  });

  group('Kein Körperziel (#41 fehlt)', () {
    testWidgets('statt Balken und Zielabstand steht der Satz — in beiden '
        'Zuständen', (tester) async {
      for (final tageswerte in <Messwert<List<DailyMetrics>>>[
        Bekannt<List<DailyMetrics>>(mitWerten(), stand: jetzt, laeuft: false),
        Bekannt<List<DailyMetrics>>(ohneWaage(), stand: jetzt, laeuft: false),
      ]) {
        final h = harness(tageswerte: tageswerte);
        await zeige(tester, h.app);

        expect(
          find.byKey(const Key('koerper-kein-ziel')),
          findsOneWidget,
          reason:
              'Die Kopfkarte zeigt keinen Fortschrittsbalken und keinen '
              'Abstand zum Ziel, sondern an dieser Stelle den Satz (Spec, '
              '„Nicht-Ziele")',
        );
      }
    });

    testWidgets('und er trägt keine erfundene Zielzahl', (tester) async {
      final h = harness();
      await zeige(tester, h.app);

      expect(
        RegExp(r'\d')
            .hasMatch(textUnter(tester, const Key('koerper-kein-ziel'))),
        isFalse,
        reason:
            'Ein Zielgewicht oder Zieldatum im Quelltext ist ein Regelbruch '
            '(`CLAUDE.md`, „Keine hartcodierten Ereignisse") — auch als '
            'Vorbelegung',
      );
      expect(
        alleTexte(tester),
        isNot(contains('bis zum ziel')),
        reason:
            'Der Zielabstand aus `koerper.js` („noch 4,6 kg bis zum Ziel '
            'von 63,0 kg · Juni 2028") ist ausdrückliches Nicht-Ziel',
      );
    });
  });

  group('Die vier Zustände', () {
    testWidgets(
      'während des Ladens steht nirgends ein „keine Daten"-Grund (`01`)',
      (tester) async {
        final h = harness(tageswerte: const NochNie<List<DailyMetrics>>());
        await zeige(tester, h.app);

        final texte = alleTexte(tester);
        expect(texte, isNot(contains('keine waagenwerte')));
        expect(texte, isNot(contains('keine werte')));
        expect(
          find.byKey(const Key('koerper-grund')),
          findsNothing,
          reason:
              '`LeerNachLauf` ist der einzige Zustand, der einen Grund '
              'anzeigen darf (`messwert.dart`)',
        );
        expect(find.byKey(const Key('koerper-laden')), findsOneWidget);
      },
    );

    testWidgets('ein gescheiterter Lauf sagt nicht, es gäbe keine Daten', (
      tester,
    ) async {
      final h = harness(
        tageswerte: Fehlgeschlagen<List<DailyMetrics>>(
          fehler: 'kaputt',
          gelaufen: jetzt,
        ),
      );
      await zeige(tester, h.app);

      expect(find.byKey(const Key('koerper-fehler')), findsOneWidget);
      expect(
        alleTexte(tester),
        isNot(contains('keine waagenwerte')),
        reason: 'Ein Fehler ist keine Aussage über die Datenlage',
      );
    });

    testWidgets('ein laufender Nachlauf nimmt den Wert nicht weg', (
      tester,
    ) async {
      final h = harness(
        tageswerte: Bekannt<List<DailyMetrics>>(
          mitWerten(),
          stand: jetzt,
          laeuft: true,
        ),
      );
      await zeige(tester, h.app);

      expect(
        find.byKey(const Key('koerper-laden')),
        findsNothing,
        reason:
            'Der Platzhalter gehört allein in `NochNie`. Liegt ein '
            'zwischengespeicherter Wert vor, bleibt der stehen',
      );
      expect(
        RegExp(r'\d')
            .hasMatch(textUnter(tester, const Key('koerper-kopfkarte-wert'))),
        isTrue,
      );
    });
  });

  group('Die Türen', () {
    testWidgets('die Kopfkarte führt auf den Verlauf des Gewichts', (
      tester,
    ) async {
      final h = harness();
      await zeige(tester, h.app);
      final tabVorher = h.router.tab;

      final befehl = await tippe(
        tester,
        h.router,
        const Key('koerper-kopfkarte'),
      );

      expect(befehl, isNotNull);
      expect(
        befehl!.tab,
        tabVorher,
        reason:
            'Gepusht wird in den Stapel des Tabs, aus dem man kommt '
            '(`AppTarget.aktuell`, Spec Teil D)',
      );
      expect(befehl.ersetztStapel, isFalse);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: h.container,
          child: CupertinoApp(home: Builder(builder: befehl.builder)),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.widget<MessungDetailView>(find.byType(MessungDetailView)).art,
        MessArt.gewicht,
      );
    });

    testWidgets('Körperfett und Muskelmasse führen auf ihren eigenen Wert', (
      tester,
    ) async {
      // Eine Liste, keine `const`-Map: `Key` hat keine primitive Gleichheit
      // und taugt deshalb nicht als Schlüssel einer konstanten Map.
      const tueren = <({Key schluessel, MessArt art})>[
        (
          schluessel: Key('koerper-kachel-koerperfett'),
          art: MessArt.koerperfett,
        ),
        (
          schluessel: Key('koerper-kachel-muskelmasse'),
          art: MessArt.fettfreieMasse,
        ),
      ];

      for (final tuer in tueren) {
        final h = harness();
        await zeige(tester, h.app);

        final befehl = await tippe(tester, h.router, tuer.schluessel);
        expect(befehl, isNotNull, reason: '${tuer.schluessel}');
        expect(befehl!.ersetztStapel, isFalse, reason: '${tuer.schluessel}');

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: h.container,
            child: CupertinoApp(home: Builder(builder: befehl.builder)),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          tester.widget<MessungDetailView>(find.byType(MessungDetailView)).art,
          tuer.art,
          reason:
              '${tuer.schluessel}: vorher sahen die Kacheln drückbar aus, '
              'ohne es zu sein (`koerper.js`, Nachtrag 02.11.2026)',
        );
      }
    });

    testWidgets('die Bereiche-Zeile „Messungen" führt auf `messungen`', (
      tester,
    ) async {
      final h = harness();
      await zeige(tester, h.app);
      final tabVorher = h.router.tab;

      final befehl = await tippe(
        tester,
        h.router,
        const Key('koerper-bereich-messungen'),
      );

      expect(befehl, isNotNull);
      expect(befehl!.tab, tabVorher);
      expect(befehl.ersetztStapel, isFalse);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: h.container,
          child: CupertinoApp(home: Builder(builder: befehl.builder)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MessungenView), findsOneWidget);
    });

    testWidgets('keine Bereiche-Zeile bleibt stumm', (tester) async {
      for (final key in bereiche) {
        final h = harness();
        await zeige(tester, h.app);

        expect(
          await tippe(tester, h.router, key),
          isNotNull,
          reason:
              '$key: Muskelkarte, Schritte und Umfänge führen auf einen '
              'Platzhalter, bis ihr Ticket dran ist (Spec, Teil D) — eine '
              'Zeile, die stumm nichts tut, sieht aus wie ein Fehler',
        );
      }
    });
  });

  group('Ein Wert, der dastand, steht nach dem Zurücknavigieren wieder da '
      '(`32`)', () {
    testWidgets('über die Kopfkarte hin und zurück', (tester) async {
      final h = harness(mitSeite: true);
      await zeige(tester, h.app);

      final vorher = textUnter(tester, const Key('koerper-kopfkarte-wert'));
      expect(
        RegExp(r'\d').hasMatch(vorher),
        isTrue,
        reason: 'sonst prüft das nichts',
      );

      final befehl = await tippe(
        tester,
        h.router,
        const Key('koerper-kopfkarte'),
      );
      final navigator = tester.state<NavigatorState>(
        find.byType(Navigator).first,
      );
      unawaited(
        navigator.push<void>(
          CupertinoPageRoute<void>(builder: befehl!.builder),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MessungDetailView), findsOneWidget);

      navigator.pop();
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('koerper-laden')),
        findsNothing,
        reason:
            'Zurück heißt nicht „noch einmal von vorn" — ein Platzhalter, '
            'der hier aufblitzt, ist genau das Flackern aus `CLAUDE.md`',
      );
      expect(textUnter(tester, const Key('koerper-kopfkarte-wert')), vorher);
    });
  });

  group('Die Fußnote', () {
    testWidgets('sie nennt Apple Health und ist keine Diagnose', (
      tester,
    ) async {
      final h = harness();
      await zeige(tester, h.app);

      final texte = alleTexte(tester);
      expect(texte, contains('apple health'));
      expect(
        texte.contains('schätzung') || texte.contains('medizinisch'),
        isTrue,
        reason:
            '`CLAUDE.md`: keine Diagnosen — jeder Gesundheitswert ist als '
            'Schätzung zu kennzeichnen',
      );
    });
  });
}

/// Steuerbarer Ableger des echten Notifiers — siehe `verlauf_view_test.dart`.
class _Tageswerte extends DailyMetricsNotifier {
  _Tageswerte(this.wert);

  final Messwert<List<DailyMetrics>> wert;

  @override
  Future<Messwert<List<DailyMetrics>>> build() async => wert;
}

/// Nur als Lieferant von [earliestPermittedDate] da: `messungDetailProvider`
/// liest ihn für die untere Kante seiner Abfrage, und der echte
/// `healthProvider` wirft ohne Override.
class _FakeHealthReading extends HealthReadingAttrappe {
  _FakeHealthReading(this._tage);

  final List<DailyMetrics> _tage;

  @override
  DateTime get earliestPermittedDate => DateTime.utc(2000);

  @override
  Future<List<DailyMetrics>> dailyMetrics(
    DateTime from,
    DateTime through,
  ) async => _tage;
}
