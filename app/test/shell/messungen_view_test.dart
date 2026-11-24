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
import 'package:repit/design/zeitdiagramm.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_types.dart';
import 'package:repit/shell/messung_detail_view.dart';
import 'package:repit/shell/messungen_view.dart';
import 'package:repit/shell/router.dart';

import '../design/support.dart' show textOf;
import '../health/health_reading_attrappe.dart';

/// Tests für die **Oberfläche** des Messungen-Schirms (#85) —
/// `lib/shell/messungen_view.dart`. Die Zahlen darunter kommen aus
/// `koerper_zustand.dart` (derselbe Zustand wie `koerper`, zwei
/// Anordnungen) und sind in `koerper_zustand_test.dart` geprüft.
///
/// Grundlage sind der am 02.11.2026 von Tim freigegebene Entwurf
/// `docs/screens/screens/messungen.js` und
/// `docs/superpowers/specs/2026-11-02-koerper-und-messungen-design.md`,
/// Teil D.
///
/// ## Festgelegte öffentliche API (`lib/shell/messungen_view.dart`)
///
/// ```dart
/// /// Öffnet Messungen auf dem Stapel des **aktuell gewählten** Tabs —
/// /// gerufen aus der Bereiche-Zeile „Messungen" auf `koerper`.
/// void oeffneMessungen(AppRouter router);
///
/// /// Der Rahmen: Gerüst und Navigationsleiste um [MessungenView].
/// class MessungenSeite extends StatelessWidget {
///   const MessungenSeite({super.key, required AppRouter router});
/// }
///
/// /// Der Schirm selbst — ohne Gerüst, ohne Leiste, ohne Navigator.
/// class MessungenView extends ConsumerWidget {
///   const MessungenView({super.key, required AppRouter router});
/// }
/// ```
///
/// ## Die Schlüssel, unter denen die Abschnitte stehen
///
/// | Schlüssel | Was |
/// |---|---|
/// | `messungen-karte-gewicht` | Verlaufskarte + Tür, `MessArt.gewicht` |
/// | `messungen-karte-koerperfett` | dieselbe für `koerperfett` |
/// | `messungen-karte-fettfreieMasse` | dieselbe für `fettfreieMasse` |
/// | `messungen-karte-ruhepuls` | dieselbe für `ruhepuls` |
/// | `messungen-einordnung` | der Satz zum Gewichtstrend |
/// | `messungen-grund` | der Grund, **einmal**, oben |
/// | `messungen-eiweiss` | „Eiweiß pro Tag" als Block |
/// | `messungen-eiweiss-ziel` | darin die Zeile „Ziel aus dem Gewicht" |
/// | `messungen-letzte` | „Letzte Messungen" |
/// | `messungen-laden` | der Ladezustand ([NochNie]) |
/// | `messungen-fehler` | der gescheiterte Lauf ([Fehlgeschlagen]) |
///
/// Die vier Kartenschlüssel folgen `MessArt.name`, damit die Zuordnung
/// Karte → Wert an **einer** Stelle steht und nicht in einer zweiten Tabelle
/// nachgebaut wird (dasselbe Muster wie `KoerperWerte.stand`).
///
/// **Jede Karte trägt ihren Schlüssel auf etwas Antippbarem.** Alle vier
/// sind Türen (`messungen.js`, Nachtrag vom 02.11.2026: „wenn ich auf einen
/// der graphen drauf gehe kommt eine detail ansicht").
///
/// ## Worauf diese Datei zielt
///
/// `CLAUDE.md`, „Tests": Zustände und Übergänge. Die beiden, auf die es
/// ankommt — kein „keine Daten"-Grund während des Ladens (`01`), und ein
/// Wert, der dastand, steht nach dem Zurücknavigieren wieder da (`32`) —
/// dazu die drei Regeln aus „Eine Anzeige, die es gibt, hat genau eine
/// Form": dieselben vier Karten in beiden Zuständen, nie eine `0` statt
/// eines fehlenden Werts, und der Grund einmal statt viermal.
///
/// ## Was hier bewusst **nicht** geprüft wird
///
/// - **Der Eiweißkorridor als Zahl.** `ProteinTarget.grams` ist im Kern
///   geprüft; hier zählt nur, dass dort ohne Wägung keine erfundene Zahl
///   steht.
/// - **Der Wortlaut des Einordnungssatzes.** Geprüft wird die Regel: ohne
///   Trend steht dort **keine gerechnete Null**.
/// - **Zahlen aus `docs/screens/`.** Erfunden, nie Erwartungswert.
void main() {
  // Montag, 12.10.2026, 09:15 Berliner Zeit (CEST, +2).
  final jetzt = DateTime.utc(2026, 10, 12, 7, 15);
  final heute = BerlinCalendar.startOfDay(jetzt);

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

  /// Drei Tage mit allen vier Messarten — genug für einen Trend. Die Zahlen
  /// sind erfunden.
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

  /// Eine einzige Wägung: Der Zustand trägt einen Wert, aber **keinen
  /// Trend** — eine Gerade durch einen Punkt hat keine Steigung.
  List<DailyMetrics> eineWaegung() => [messung(0, gewicht: 82.4, ruhepuls: 57)];

  /// Uhr und iPhone haben gemessen, die Waage nie.
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
        healthProvider.overrideWithValue(_FakeHealthReading()),
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
                  ? MessungenSeite(router: router)
                  : MessungenView(router: router),
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

  Key karte(MessArt art) => Key('messungen-karte-${art.name}');

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
          of: find.byType(MessungenView),
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

    testWidgets('der Abstand kommt aus `GlasAbstand`', (tester) async {
      final h = harness();
      await zeige(tester, h.app);

      final scroll = tester.widget<SingleChildScrollView>(
        find.descendant(
          of: find.byType(MessungenView),
          matching: find.byType(SingleChildScrollView),
        ),
      );
      final erwartet = GlasAbstand.of(
        tester.element(find.byType(MessungenView)),
      );
      expect(erwartet.top, greaterThan(0), reason: 'sonst prüft das nichts');
      expect((scroll.padding! as EdgeInsets).top, erwartet.top);
    });

    testWidgets('`oeffneMessungen` schiebt auf den Stapel des aktuellen Tabs', (
      tester,
    ) async {
      final h = harness();
      await zeige(tester, h.app);
      final tabVorher = h.router.tab;

      oeffneMessungen(h.router);
      final befehl = h.router.nimmBefehl();

      expect(befehl, isNotNull);
      expect(befehl!.tab, tabVorher);
      expect(befehl.ersetztStapel, isFalse);
    });
  });

  group('Keine Zeitleiste auf diesem Schirm', () {
    testWidgets('sie sitzt auf dem Detailschirm, nicht hier', (tester) async {
      final h = harness();
      await zeige(tester, h.app);

      expect(
        find.byType(Zeitraumleiste),
        findsNothing,
        reason:
            'Die eine begründete Abweichung von '
            '`MeasurementsView.swift:12–13`: Vier volle Diagramme '
            'untereinander wären vier Fußnoten und vier Achsen auf einem '
            'Schirm, durch den man scrollt (Spec, Teil D)',
      );
      expect(find.byType(Zeitdiagramm), findsNothing);
    });
  });

  group('Eine Anzeige, die es gibt, hat genau eine Form', () {
    testWidgets('mit Werten stehen alle vier Karten und beide Blöcke da', (
      tester,
    ) async {
      final h = harness();
      await zeige(tester, h.app);

      for (final art in MessArt.values) {
        expect(find.byKey(karte(art)), findsOneWidget, reason: '$art');
      }
      expect(find.byKey(const Key('messungen-eiweiss')), findsOneWidget);
      expect(find.byKey(const Key('messungen-letzte')), findsOneWidget);
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

      for (final art in MessArt.values) {
        expect(
          find.byKey(karte(art)),
          findsOneWidget,
          reason:
              '$art: dieselben vier Karten, dieselbe Höhe, nur ohne Füllung '
              '(`messungen.js`, Variante „leer")',
        );
      }
      expect(find.byKey(const Key('messungen-eiweiss')), findsOneWidget);
      expect(find.byKey(const Key('messungen-letzte')), findsOneWidget);
    });

    testWidgets('auch ein leer ausgegangener Lauf lässt alles stehen', (
      tester,
    ) async {
      final h = harness(
        tageswerte: LeerNachLauf<List<DailyMetrics>>(gelaufen: jetzt),
      );
      await zeige(tester, h.app);

      for (final art in MessArt.values) {
        expect(find.byKey(karte(art)), findsOneWidget, reason: '$art');
      }
      expect(find.byKey(const Key('messungen-eiweiss')), findsOneWidget);
      expect(find.byKey(const Key('messungen-letzte')), findsOneWidget);
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

      for (final art in const [
        MessArt.gewicht,
        MessArt.koerperfett,
        MessArt.fettfreieMasse,
      ]) {
        expect(
          RegExp(r'\d').hasMatch(textUnter(tester, karte(art))),
          isFalse,
          reason:
              '$art: ohne Waage gibt es keine Zahl — und „0,0 %" wäre '
              'Fehler `01` in neuer Verpackung (`CLAUDE.md`)',
        );
      }
    });

    // Geprüft wird die **Ziel-Zeile**, nicht der Block. Eine frühere
    // Fassung dieses Falls verbot `contains('0 g')` im ganzen
    // `messungen-eiweiss`-Block, und das war zu weit gefasst: Die
    // Rechenzeile des Entwurfs heißt `1,6–2,0 g pro kg` und enthält
    // „0 g" (aus „2,0 g"), ein echtes Ziel von 100 kg hieße „160–200 g"
    // und enthielte es auch. Der Fall wäre also rot geworden, obwohl
    // alles stimmt — und hätte den Umsetzenden gezwungen, die
    // Schreibweise des freigegebenen Entwurfs aufzugeben, nur um an einem
    // `contains` vorbeizukommen. **Ein `contains` über einen Block, in dem
    // Einheiten vorkommen, trifft irgendwann die falsche Zeile.** Deshalb
    // ein eigener Schlüssel auf genau der Zeile, um die es geht, und dort
    // die schärfere Frage „trägt sie überhaupt eine Ziffer".
    testWidgets('ohne Wägung trägt die Ziel-Zeile keine Ziffer', (
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

      // Erst die Anwesenheit, dann die Aussage: `textUnter` liefert für
      // einen Schlüssel, den es nicht gibt, den leeren String — und der
      // trägt keine Ziffer. Ohne diese Zeile bestünde der Fall genau dann,
      // wenn die Zeile fehlt, also im schlimmsten Fall.
      expect(find.byKey(const Key('messungen-eiweiss-ziel')), findsOneWidget);
      expect(
        RegExp(r'\d')
            .hasMatch(textUnter(tester, const Key('messungen-eiweiss-ziel'))),
        isFalse,
        reason:
            'Das Ziel rechnet sich aus dem Gewicht; ohne Gewicht gibt es '
            'keins, und „0 g Eiweiß" wäre ein Rat, den niemand gegeben hat',
      );
    });

    testWidgets('mit Wägung trägt sie eine', (tester) async {
      final h = harness();
      await zeige(tester, h.app);

      expect(find.byKey(const Key('messungen-eiweiss-ziel')), findsOneWidget);
      expect(
        RegExp(r'\d')
            .hasMatch(textUnter(tester, const Key('messungen-eiweiss-ziel'))),
        isTrue,
        reason:
            'Der Gegenfall zum vorigen — eine Zeile, die nie eine Zahl '
            'trägt, bestünde ihn sonst auch',
      );
    });
  });

  group('Der Grund steht einmal, nicht je Karte', () {
    testWidgets('ohne Waagenwerte steht er genau einmal, oben', (tester) async {
      final h = harness(
        tageswerte: Bekannt<List<DailyMetrics>>(
          ohneWaage(),
          stand: jetzt,
          laeuft: false,
        ),
      );
      await zeige(tester, h.app);

      expect(find.byKey(const Key('messungen-grund')), findsOneWidget);
      for (final art in MessArt.values) {
        expect(
          find.descendant(
            of: find.byKey(karte(art)),
            matching: find.byKey(const Key('messungen-grund')),
          ),
          findsNothing,
          reason:
              '$art: „der Grund steht einmal oben statt viermal in der '
              'Karte" (`messungen.js`, Variante „leer")',
        );
      }
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

      final grund = textUnter(
        tester,
        const Key('messungen-grund'),
      ).toLowerCase();
      expect(grund, contains('apple health'));
      expect(
        grund.contains('freigabe') ||
            grund.contains('lesen') ||
            grund.contains('erlaub'),
        isTrue,
        reason:
            'Apple verrät den Unterschied nicht — beides muss dastehen '
            '(`CLAUDE.md`)',
      );
    });

    testWidgets('mit Werten steht er nicht da', (tester) async {
      final h = harness();
      await zeige(tester, h.app);

      expect(find.byKey(const Key('messungen-grund')), findsNothing);
    });
  });

  group('Der Einordnungssatz zum Gewichtstrend', () {
    testWidgets('mit Trend steht er da', (tester) async {
      final h = harness();
      await zeige(tester, h.app);

      expect(find.byKey(const Key('messungen-einordnung')), findsOneWidget);
      expect(
        textUnter(tester, const Key('messungen-einordnung')).trim(),
        isNotEmpty,
      );
    });

    testWidgets('ohne Trend steht dort keine gerechnete Null', (tester) async {
      final h = harness(
        tageswerte: Bekannt<List<DailyMetrics>>(
          eineWaegung(),
          stand: jetzt,
          laeuft: false,
        ),
      );
      await zeige(tester, h.app);

      final satz = textUnter(tester, const Key('messungen-einordnung'));
      expect(
        satz.trim(),
        isNotEmpty,
        reason:
            'Ohne Trend steht dort, dass noch zu wenige Wägungen vorliegen '
            '— nicht nichts (Spec, Teil D)',
      );
      expect(
        RegExp(r'0[.,]0').hasMatch(satz),
        isFalse,
        reason:
            'Eine Gerade durch einen Punkt hat keine Steigung; „0,00 kg pro '
            'Woche" wäre eine Zahl, die niemand gerechnet hat',
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
        expect(find.byKey(const Key('messungen-grund')), findsNothing);
        expect(find.byKey(const Key('messungen-laden')), findsOneWidget);
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

      expect(find.byKey(const Key('messungen-fehler')), findsOneWidget);
      expect(alleTexte(tester), isNot(contains('keine waagenwerte')));
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

      expect(find.byKey(const Key('messungen-laden')), findsNothing);
      expect(
        RegExp(r'\d').hasMatch(textUnter(tester, karte(MessArt.gewicht))),
        isTrue,
      );
    });
  });

  group('Die Türen', () {
    testWidgets('jede der vier Karten führt auf ihren eigenen Verlauf', (
      tester,
    ) async {
      for (final art in MessArt.values) {
        final h = harness();
        await zeige(tester, h.app);
        final tabVorher = h.router.tab;

        final befehl = await tippe(tester, h.router, karte(art));
        expect(befehl, isNotNull, reason: '$art');
        expect(
          befehl!.tab,
          tabVorher,
          reason:
              '$art: gepusht wird in den Stapel des Tabs, aus dem man kommt '
              '(`AppTarget.aktuell`)',
        );
        expect(befehl.ersetztStapel, isFalse, reason: '$art');

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: h.container,
            child: CupertinoApp(home: Builder(builder: befehl.builder)),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          tester.widget<MessungDetailView>(find.byType(MessungDetailView)).art,
          art,
          reason:
              '$art: welcher Wert gemeint ist, trägt das Ziel als Parameter '
              '— alle vier auf denselben Schirm zu schicken wäre die '
              'Platzhalter-Lösung',
        );
      }
    });

    testWidgets('auch ohne Werte bleibt die Karte eine Tür', (tester) async {
      final h = harness(
        tageswerte: Bekannt<List<DailyMetrics>>(
          ohneWaage(),
          stand: jetzt,
          laeuft: false,
        ),
      );
      await zeige(tester, h.app);

      expect(
        await tippe(tester, h.router, karte(MessArt.gewicht)),
        isNotNull,
        reason:
            'Eine fehlende Tür sieht aus wie eine Funktion, die es nicht '
            'gibt — und der Detailschirm hat seine eigene Leeransicht',
      );
    });
  });

  group('Ein Wert, der dastand, steht nach dem Zurücknavigieren wieder da '
      '(`32`)', () {
    testWidgets('über eine Verlaufskarte hin und zurück', (tester) async {
      final h = harness(mitSeite: true);
      await zeige(tester, h.app);

      final vorher = textUnter(tester, karte(MessArt.gewicht));
      expect(
        RegExp(r'\d').hasMatch(vorher),
        isTrue,
        reason: 'sonst prüft das nichts',
      );

      final befehl = await tippe(tester, h.router, karte(MessArt.gewicht));
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
        find.byKey(const Key('messungen-laden')),
        findsNothing,
        reason:
            'Ein Platzhalter, der bei der Rückkehr aufblitzt, ist genau das '
            'Flackern, gegen das die Regel gebaut ist (`CLAUDE.md`)',
      );
      expect(textUnter(tester, karte(MessArt.gewicht)), vorher);
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
        reason: '`CLAUDE.md`: keine Diagnosen',
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

/// Nur als Lieferant von [earliestPermittedDate] da — der gepushte
/// Detailschirm liest ihn, und der echte `healthProvider` wirft ohne
/// Override.
class _FakeHealthReading extends HealthReadingAttrappe {
  @override
  DateTime get earliestPermittedDate => DateTime.utc(2000);
}
