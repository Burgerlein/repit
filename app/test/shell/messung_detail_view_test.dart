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
import 'package:repit/shell/diagramm_zeitraum.dart';
import 'package:repit/shell/messung_detail_view.dart';
import 'package:repit/shell/messung_detail_zustand.dart';
import 'package:repit/shell/router.dart';

import '../design/support.dart' show textOf;
import '../health/health_reading_attrappe.dart';

/// Tests für die **Oberfläche** des Verlaufsschirms je Messwert (#203) —
/// `lib/shell/messung_detail_view.dart`. Der Zustand darunter liegt in
/// `messung_detail_zustand.dart` und ist in
/// `messung_detail_zustand_test.dart` geprüft.
///
/// Grundlage sind der am 02.11.2026 von Tim freigegebene Entwurf
/// `docs/screens/screens/messung-detail.js` und
/// `docs/superpowers/specs/2026-11-02-koerper-und-messungen-design.md`,
/// Teil D. Vorbild für Schnitt und Stil ist `verlauf_view_test.dart` — den
/// Schirm gibt es **viermal**, welcher Wert gemeint ist, trägt [MessArt]
/// als Parameter.
///
/// ## Festgelegte öffentliche API (`lib/shell/messung_detail_view.dart`)
///
/// ```dart
/// /// Öffnet den Verlauf eines Messwerts auf dem Stapel des **aktuell
/// /// gewählten** Tabs — gerufen aus `koerper` und aus `messungen`.
/// void oeffneMessungDetail(AppRouter router, MessArt art);
///
/// /// Der Rahmen: Gerüst und Navigationsleiste um [MessungDetailView].
/// class MessungDetailSeite extends StatelessWidget {
///   const MessungDetailSeite({super.key, required MessArt art});
/// }
///
/// /// Der Schirm selbst — ohne Gerüst, ohne Leiste, ohne Navigator.
/// class MessungDetailView extends ConsumerWidget {
///   const MessungDetailView({super.key, required MessArt art});
/// }
/// ```
///
/// ## Die Schlüssel, unter denen die Abschnitte stehen
///
/// | Schlüssel | Was |
/// |---|---|
/// | `messung-detail-diagramm` | Leiste, Kopfzeile, Fläche, Fußzeile |
/// | `messung-detail-einordnung` | die Karte „Einordnung" als Ganzes |
/// | `messung-detail-aktuell` | die Zeile „Aktuell" |
/// | `messung-detail-navy` | die Zeile „Nach Maßband (Navy)" (#88) |
/// | `messung-detail-erklaerung` | der Erklärsatz |
/// | `messung-detail-laden` | der Ladezustand ([NochNie]) |
/// | `messung-detail-fehler` | der gescheiterte Lauf ([Fehlgeschlagen]) |
///
/// ## Was dieser Schirm anders macht als `verlauf`
///
/// **Die Diagrammfläche bleibt im Leerzustand stehen.** `verlauf_view.dart`
/// nimmt sie weg („eine leere Fläche mit Achsen behauptet, es gäbe eine
/// Kurve"); hier verlangt der Entwurf ausdrücklich das Gegenteil: „Leiste,
/// Diagrammfläche, Einordnung und Satz bleiben stehen; nur die Zahlen
/// fehlen" (Spec, Teil D; `messung-detail.js`, Variante „leer", mit eigener
/// grauer Fläche `chartleer` und eigener Fußzeile). Der Unterschied ist
/// Absicht und steht deshalb als eigener Testfall da.
///
/// ## Worauf diese Datei zielt
///
/// Zustände und Übergänge (`CLAUDE.md`, „Tests"): kein „keine Daten"-Grund
/// während des Ladens (`01`), dieselbe Geometrie mit und ohne Werte, nie
/// eine `0` statt eines fehlenden Werts — und ein Wert, der dastand, steht
/// nach einem Stufenwechsel und zurück wieder da (`32`: die Stufe lebt im
/// Bauteil, es wird nichts neu geladen).
///
/// Die **Einordnungszeilen** prüft diese Datei ausnahmsweise an ihrer
/// Beschriftung: Sie „stehen im Entwurf und gelten wörtlich" (Spec, Teil
/// D), sind also Anforderung und nicht Dekor. Geprüft wird, dass jede Art
/// ihre eigenen trägt — nicht ihre Reihenfolge und nicht ihr Wortlaut.
///
/// ## Was hier bewusst **nicht** geprüft wird
///
/// - **Verdichtung, Spanne, Median als Zahl.** Steht im Kern und in
///   `messung_detail_zustand_test.dart`.
/// - **Zahlen aus `docs/screens/`.** Erfunden, nie Erwartungswert.
/// - **Schriftgrößen und Dynamic Type.**
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
  }) => DailyMetrics(
    tag: schluesselVor(tageZurueck),
    restingHR: ruhepuls,
    weightKg: gewicht,
    bodyFatPct: fett,
    leanKg: fettfrei,
  );

  /// Sieben Tage mit allen vier Messarten. Die Zahlen sind erfunden — die
  /// aus `docs/screens/` sind es auch und dürfen nie Erwartungswert sein.
  List<DailyMetrics> mitWerten() => [
    for (var t = 6; t >= 0; t--)
      messung(
        t,
        gewicht: 80.0 + (6 - t) * 0.4,
        fett: 22.5 - (6 - t) * 0.1,
        fettfrei: 60.0 + (6 - t) * 0.3,
        ruhepuls: 57 - (6 - t) % 3,
      ),
  ];

  // ───────────────────────────────────────────────────────────────────────

  /// Zwei Betriebsarten:
  ///
  /// * **[tage] gesetzt** — der echte `dailyMetricsProvider` läuft, schreibt
  ///   die Antwort des Kanals in den In-Memory-Cache, und `messReihe` liest
  ///   sie von dort wieder heraus. Derselbe Weg wie auf dem Gerät.
  /// * **[tageswerte] gesetzt** — der Zustand von `dailyMetricsProvider`
  ///   wird vorgegeben und der Cache bleibt leer. So entstehen `NochNie`,
  ///   `LeerNachLauf`, `Fehlgeschlagen` und der Fall „Lauf hat etwas
  ///   geliefert, für diesen einen Wert aber nichts".
  ({ProviderContainer container, AppRouter router, Widget app}) harness(
    MessArt art, {
    List<DailyMetrics>? tage,
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
        healthProvider.overrideWithValue(
          _FakeHealthReading(tage ?? mitWerten()),
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
                  ? MessungDetailSeite(art: art)
                  : MessungDetailView(art: art),
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

  Zeitraumleiste leiste(WidgetTester tester) =>
      tester.widget<Zeitraumleiste>(find.byType(Zeitraumleiste));

  /// Der Zustand „der Lauf lief, für diesen Wert kam nichts heraus": Es gibt
  /// Tage (das iPhone hat Schritte gezählt), aber keine einzige Messung der
  /// Waage und der Uhr — der Cache bleibt für jede der vier Messarten leer,
  /// der Messwert ist trotzdem [Bekannt]. **Eine leere Reihe ist kein
  /// Leerzustand** (`messung_detail_zustand.dart`).
  Messwert<List<DailyMetrics>> bekanntOhneReihe() =>
      Bekannt<List<DailyMetrics>>(
        [
          DailyMetrics(tag: schluesselVor(1), steps: 8200),
          DailyMetrics(tag: schluesselVor(0), steps: 9600),
        ],
        stand: jetzt,
        laeuft: false,
      );

  // ───────────────────────────────────────────────────────────────────────

  group('Hausordnung', () {
    testWidgets('der Schirm bringt weder Gerüst noch Leiste mit', (
      tester,
    ) async {
      final h = harness(MessArt.gewicht);
      await zeige(tester, h.app);

      expect(find.byType(CupertinoPageScaffold), findsNothing);
      expect(find.byType(CupertinoNavigationBar), findsNothing);
      expect(
        find.descendant(
          of: find.byType(MessungDetailView),
          matching: find.byType(Navigator),
        ),
        findsNothing,
      );
    });

    testWidgets('die Seite bringt beides mit', (tester) async {
      final h = harness(MessArt.gewicht, mitSeite: true);
      await zeige(tester, h.app);

      expect(find.byType(CupertinoPageScaffold), findsOneWidget);
      expect(find.byType(CupertinoNavigationBar), findsOneWidget);
    });

    testWidgets('der Abstand kommt aus `GlasAbstand`', (tester) async {
      final h = harness(MessArt.gewicht);
      await zeige(tester, h.app);

      final scroll = tester.widget<SingleChildScrollView>(
        find.descendant(
          of: find.byType(MessungDetailView),
          matching: find.byType(SingleChildScrollView),
        ),
      );
      final erwartet = GlasAbstand.of(
        tester.element(find.byType(MessungDetailView)),
      );
      expect(erwartet.top, greaterThan(0), reason: 'sonst prüft das nichts');
      expect((scroll.padding! as EdgeInsets).top, erwartet.top);
    });

    testWidgets('alle vier Arten sind erreichbar und tragen ihre Art', (
      tester,
    ) async {
      for (final art in MessArt.values) {
        final h = harness(art);
        await zeige(tester, h.app);
        final tabVorher = h.router.tab;

        oeffneMessungDetail(h.router, art);
        final befehl = h.router.nimmBefehl();
        expect(befehl, isNotNull, reason: '$art');
        expect(befehl!.ersetztStapel, isFalse, reason: '$art');
        expect(
          befehl.tab,
          tabVorher,
          reason:
              '$art: gepusht wird in den Stapel des Tabs, aus dem man kommt '
              '(`AppTarget.aktuell`)',
        );

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
              '— wie `VerlaufArt` bei den Erholungs-Verläufen',
        );
      }
    });
  });

  group('Die Zeitleiste', () {
    testWidgets('sie trägt W M 6M J und kein T', (tester) async {
      final h = harness(MessArt.gewicht);
      await zeige(tester, h.app);

      expect(leiste(tester).stufen, messungsStufen);
      expect(
        leiste(tester).stufen,
        containsAll(const [
          DiagrammStufe.woche,
          DiagrammStufe.monat,
          DiagrammStufe.halbjahr,
          DiagrammStufe.jahr,
        ]),
        reason: 'W M 6M J (Spec, Teil D)',
      );
    });

    testWidgets('beim Aufschlagen ist `W` gewählt', (tester) async {
      for (final art in MessArt.values) {
        final h = harness(art);
        await zeige(tester, h.app);

        expect(
          leiste(tester).gewaehlt,
          DiagrammStufe.woche,
          reason:
              '$art: Startstufe ist `W` — man wiegt sich nicht stündlich '
              '(Spec, Teil D)',
        );
        expect(leiste(tester).gewaehlt, messungsStufen.first, reason: '$art');
      }
    });

    testWidgets('sie steht auch ohne Werte da', (tester) async {
      final h = harness(MessArt.gewicht, tageswerte: bekanntOhneReihe());
      await zeige(tester, h.app);

      expect(
        find.byType(Zeitraumleiste),
        findsOneWidget,
        reason:
            '„Leiste, Diagrammfläche, Einordnung und Satz bleiben stehen; '
            'nur die Zahlen fehlen" (Spec, Teil D)',
      );
      expect(leiste(tester).stufen, messungsStufen);
      expect(leiste(tester).gewaehlt, DiagrammStufe.woche);
    });
  });

  group('Dieselbe Geometrie mit und ohne Werte', () {
    const abschnitte = [
      Key('messung-detail-diagramm'),
      Key('messung-detail-einordnung'),
      Key('messung-detail-erklaerung'),
    ];

    testWidgets('mit Werten stehen Diagramm, Einordnung und Satz da', (
      tester,
    ) async {
      final h = harness(MessArt.gewicht);
      await zeige(tester, h.app);

      for (final key in abschnitte) {
        expect(find.byKey(key), findsOneWidget, reason: '$key');
      }
    });

    testWidgets('ohne Werte stehen genau dieselben drei da', (tester) async {
      for (final art in MessArt.values) {
        final h = harness(art, tageswerte: bekanntOhneReihe());
        await zeige(tester, h.app);

        for (final key in abschnitte) {
          expect(
            find.byKey(key),
            findsOneWidget,
            reason:
                '$art / $key: anders als `verlauf_view.dart` nimmt dieser '
                'Schirm die Diagrammfläche **nicht** weg — der Entwurf '
                'verlangt dieselbe Geometrie',
          );
        }
      }
    });

    testWidgets('auch ein leer ausgegangener Lauf lässt alles stehen', (
      tester,
    ) async {
      final h = harness(
        MessArt.gewicht,
        tageswerte: LeerNachLauf<List<DailyMetrics>>(gelaufen: jetzt),
      );
      await zeige(tester, h.app);

      for (final key in abschnitte) {
        expect(find.byKey(key), findsOneWidget, reason: '$key');
      }
    });

    testWidgets('ohne Werte steht in „Aktuell" keine Null', (tester) async {
      for (final art in MessArt.values) {
        final h = harness(art, tageswerte: bekanntOhneReihe());
        await zeige(tester, h.app);

        expect(
          RegExp(r'\d')
              .hasMatch(textUnter(tester, const Key('messung-detail-aktuell'))),
          isFalse,
          reason:
              '$art: ein fehlender Wert heißt „—", nie „0" (`CLAUDE.md`, '
              '„`0` ist keine Antwort auf ‚kein Wert\'")',
        );
      }
    });
  });

  group('Die Einordnung', () {
    testWidgets('jede Art trägt ihre eigenen Zeilen', (tester) async {
      const erwartet = <MessArt, List<String>>{
        MessArt.gewicht: ['aktuell', 'trend', 'zielkorridor', 'spanne'],
        MessArt.koerperfett: ['aktuell', 'maßband', 'veränderung', 'spanne'],
        MessArt.fettfreieMasse: [
          'aktuell',
          'veränderung',
          'anteil am gewicht',
          'spanne',
        ],
        MessArt.ruhepuls: ['aktuell', 'median', 'spanne'],
      };

      for (final eintrag in erwartet.entries) {
        final h = harness(eintrag.key);
        await zeige(tester, h.app);

        final text = textUnter(
          tester,
          const Key('messung-detail-einordnung'),
        ).toLowerCase();
        for (final zeile in eintrag.value) {
          expect(
            text,
            contains(zeile),
            reason:
                '${eintrag.key}: die Einordnungszeilen stehen im Entwurf '
                'und gelten wörtlich (Spec, Teil D)',
          );
        }
      }
    });

    testWidgets('der Zielkorridor steht auch ohne Werte da', (tester) async {
      final h = harness(MessArt.gewicht, tageswerte: bekanntOhneReihe());
      await zeige(tester, h.app);

      expect(
        textUnter(tester, const Key('messung-detail-einordnung')).toLowerCase(),
        contains('zielkorridor'),
        reason:
            'Er hängt nicht an einer Messung, sondern an der Regel aus '
            '`docs/SPEC.md` (Spec, Teil D)',
      );
    });

    testWidgets(
      'die Maßband-Zeile steht beim Körperfett fest da und trägt keine Zahl',
      (tester) async {
        for (final tageswerte in <Messwert<List<DailyMetrics>>?>[
          null,
          bekanntOhneReihe(),
        ]) {
          final h = harness(MessArt.koerperfett, tageswerte: tageswerte);
          await zeige(tester, h.app);

          expect(
            find.byKey(const Key('messung-detail-navy')),
            findsOneWidget,
            reason:
                'Die Einordnung sagt an dieser Stelle „kein Maßband-Wert", '
                'und zwar als **feste Zeile, nicht als Lücke** (Spec, '
                '„Nicht-Ziele")',
          );
          final text = textUnter(
            tester,
            const Key('messung-detail-navy'),
          ).toLowerCase();
          expect(text, contains('maßband'));
          expect(
            RegExp(r'\d').hasMatch(text),
            isFalse,
            reason:
                'Navy braucht Taille und Hals vom Maßband, und Umfänge gibt '
                'es im Neubau nicht (#88) — `navyProzent` ist immer `null`, '
                'also darf dort nie eine Zahl stehen',
          );
        }
      },
    );

    testWidgets('bei den übrigen drei Arten gibt es sie nicht', (tester) async {
      for (final art in const [
        MessArt.gewicht,
        MessArt.fettfreieMasse,
        MessArt.ruhepuls,
      ]) {
        final h = harness(art);
        await zeige(tester, h.app);

        expect(
          find.byKey(const Key('messung-detail-navy')),
          findsNothing,
          reason:
              '$art: die zweite Quelle gibt es nur beim Körperfett '
              '(`messung-detail.js`)',
        );
      }
    });
  });

  group('Der Erklärsatz', () {
    testWidgets('jede der vier Arten trägt einen eigenen', (tester) async {
      final gesehen = <MessArt, String>{};

      for (final art in MessArt.values) {
        final h = harness(art);
        await zeige(tester, h.app);

        final satz = textUnter(tester, const Key('messung-detail-erklaerung'));
        expect(satz.trim(), isNotEmpty, reason: '$art');
        gesehen[art] = satz;
      }

      expect(
        gesehen.values.toSet(),
        hasLength(MessArt.values.length),
        reason:
            '„Der Erklärsatz ist der eigentliche Inhalt" — die Kurve zeigt, '
            '*dass* sich etwas bewegt, der Satz sagt, *was das bedeutet* '
            '(`messung-detail.js`). Vier gleiche wären vier leere',
      );
    });

    testWidgets(
      'der Satz zur fettfreien Masse sagt, dass sie nicht Muskel ist',
      (tester) async {
        final h = harness(MessArt.fettfreieMasse);
        await zeige(tester, h.app);

        final satz = textUnter(
          tester,
          const Key('messung-detail-erklaerung'),
        ).toLowerCase();
        expect(
          satz.contains('wasser') ||
              satz.contains('nicht nur muskel') ||
              satz.contains('organe'),
          isTrue,
          reason:
              '„Fettfreie Masse ist nicht Muskel — das muss dastehen, sonst '
              'liest man jede Schwankung als Trainingserfolg" '
              '(`messung-detail.js`, Variante „muskelmasse")',
        );
      },
    );

    testWidgets('er steht auch ohne Werte da', (tester) async {
      final h = harness(MessArt.gewicht, tageswerte: bekanntOhneReihe());
      await zeige(tester, h.app);

      expect(
        textUnter(tester, const Key('messung-detail-erklaerung')).trim(),
        isNotEmpty,
      );
    });
  });

  group('Die vier Zustände', () {
    testWidgets(
      'während des Ladens steht nirgends ein „keine Daten"-Grund (`01`)',
      (tester) async {
        final h = harness(
          MessArt.gewicht,
          tageswerte: const NochNie<List<DailyMetrics>>(),
        );
        await zeige(tester, h.app);

        final texte = alleTexte(tester);
        expect(texte, isNot(contains('keine waagenwerte')));
        expect(texte, isNot(contains('keine werte')));
        expect(texte, isNot(contains('noch keine')));
        expect(find.byKey(const Key('messung-detail-laden')), findsOneWidget);
      },
    );

    testWidgets('ein gescheiterter Lauf sagt nicht, es gäbe keine Daten', (
      tester,
    ) async {
      final h = harness(
        MessArt.gewicht,
        tageswerte: Fehlgeschlagen<List<DailyMetrics>>(
          fehler: 'kaputt',
          gelaufen: jetzt,
        ),
      );
      await zeige(tester, h.app);

      expect(find.byKey(const Key('messung-detail-fehler')), findsOneWidget);
      expect(
        alleTexte(tester),
        isNot(contains('keine waagenwerte')),
        reason: 'Ein Fehler ist keine Aussage über die Datenlage',
      );
    });

    testWidgets('ohne Werte nennt der Grund beide Möglichkeiten', (
      tester,
    ) async {
      final h = harness(MessArt.gewicht, tageswerte: bekanntOhneReihe());
      await zeige(tester, h.app);

      final texte = alleTexte(tester);
      expect(texte, contains('apple health'));
      expect(
        texte.contains('freigabe') ||
            texte.contains('lesen') ||
            texte.contains('erlaub'),
        isTrue,
        reason:
            'Apple verrät den Unterschied zwischen „nichts aufgezeichnet" '
            'und „nicht freigegeben" nicht (`CLAUDE.md`)',
      );
    });

    testWidgets('ein laufender Nachlauf nimmt den Wert nicht weg', (
      tester,
    ) async {
      final h = harness(MessArt.gewicht);
      await zeige(tester, h.app);

      expect(find.byKey(const Key('messung-detail-laden')), findsNothing);
      expect(
        RegExp(r'\d')
            .hasMatch(textUnter(tester, const Key('messung-detail-aktuell'))),
        isTrue,
      );
    });
  });

  group('Ein Wert, der dastand, steht wieder da (`32`)', () {
    testWidgets('ein Stufenwechsel und zurück lädt nichts neu', (tester) async {
      final h = harness(MessArt.gewicht);
      await zeige(tester, h.app);

      final vorher = textUnter(tester, const Key('messung-detail-einordnung'));
      expect(
        RegExp(r'\d').hasMatch(vorher),
        isTrue,
        reason: 'sonst prüft das nichts',
      );

      leiste(tester).onWaehle(DiagrammStufe.halbjahr);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('messung-detail-laden')),
        findsNothing,
        reason:
            'Welche Stufe gewählt ist, weiß der Zustand nicht und darf er '
            'nicht wissen: Sie wechselt im Bauteil, ohne dass neu geladen '
            'wird (`messung_detail_zustand.dart`)',
      );

      leiste(tester).onWaehle(DiagrammStufe.woche);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('messung-detail-laden')), findsNothing);
      expect(
        textUnter(tester, const Key('messung-detail-einordnung')),
        vorher,
        reason:
            'Die Einordnung hängt an der Reihe, nicht am Fenster — sie darf '
            'sich beim Blättern gar nicht ändern',
      );
    });
  });

  group('Die Fußnote', () {
    testWidgets('sie nennt Apple Health und ist keine Diagnose', (
      tester,
    ) async {
      final h = harness(MessArt.gewicht);
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

/// Steuerbarer Ableger der echten Quelle — wörtlich wie in
/// `messung_detail_zustand_test.dart`.
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
