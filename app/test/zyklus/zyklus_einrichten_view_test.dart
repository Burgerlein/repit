import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/data/zyklus_repository.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/shell/mehr_view.dart';
import 'package:repit/shell/router.dart';
import 'package:repit/zyklus/zyklus_einrichten_view.dart';
import 'package:repit/zyklus/zyklus_texte.dart';
import 'package:repit/zyklus/zyklus_view.dart';
import 'package:repit/zyklus/zyklus_zustand.dart';

import '../design/support.dart' show textOf;
import '../health/health_reading_attrappe.dart';
import '../tag/behaelter_im_baum.dart';

/// Widget-Tests für den Schirm **„Zyklus einrichten"** (#573 unter #539),
/// `lib/zyklus/zyklus_einrichten_view.dart` — und für die beiden Wege
/// dorthin: die Zeile unter *Mehr* und das Zahnrad in der Leiste des
/// Kalenders.
///
/// ## Eine Rolle, zwei Commits
///
/// `CLAUDE.md` erlaubt für Widget-Tests **einen** Agenten für Test und
/// Implementierung — unter einer Bedingung: Der Test entsteht zuerst, wird
/// einmal rot gesehen und ist **committet, bevor die Implementierung
/// anfängt**. Ab da bewacht ihn `.githooks/pre-commit`. Genau so ist diese
/// Datei entstanden; der Schirm existierte beim Schreiben nicht.
///
/// ## Woher die Anforderung kommt
///
/// - Entwurfsboard `docs/screens/screens/zyklus-einrichten.js` — die sechs
///   Zustände dort (Ausgeschaltet, Hinter dem Fragezeichen, Beim
///   Einschalten, Eingerichtet, Mit hormoneller Verhütung, Nichts in
///   Health) sind die Abnahmekriterien.
/// - Spec `docs/superpowers/specs/2026-11-23-zyklus-spec.md`, Abschnitte
///   3.7 (hormonelle Verhütung), 4.3 (Einstellungen) und 7 (Schirme).
/// - `CLAUDE.md`: Erklärtexte hinter das `?`, Keine-Daten-Ansicht gehört
///   zum ersten Schritt, `AsyncValue` nicht in der Widget-Schicht.
///
/// ## Worauf diese Datei zielt
///
/// `CLAUDE.md`, „Tests": **Zustände und Übergänge, nicht Layout und
/// Beschriftung.** Kein Fall hier prüft eine Farbe oder einen Abstand.
/// Wo ein Wortlaut vorkommt, kommt er aus `zyklus_texte.dart` — geprüft
/// wird dann nicht die Formulierung, sondern dass **dieser** Satz an
/// **dieser** Stelle steht (etwa: „Ausblenden löscht nichts" steht vor dem
/// Umlegen, nicht danach).
///
/// Geprüft wird:
///
/// 1. Der Ausgangszustand: ein Schalter, die eine Folge, sonst nichts.
/// 2. Einschalten **schreibt** die Einstellung und lässt die Abschnitte
///    erscheinen; Ausschalten **löscht keine Einträge**.
/// 3. Sicht und Verhütung landen in der Ablage, und die Verhütung trägt
///    ihren Zeitpunkt — ein zeitloses Ja/Nein wäre nicht nachvollziehbar
///    (Spec 3.7).
/// 4. Die Keine-Daten-Ansicht des Imports: Die Zeile steht auch dann, wenn
///    Health nichts hergibt, und sagt es.
/// 5. Das Hilfe-Blatt öffnet sich hinter dem `?`.
/// 6. Die Zeile unter *Mehr* erscheint **nur** bei eingeschaltetem
///    Kalender; „Zyklus einrichten" steht immer.
///
/// ## Die API, auf die sich diese Datei festlegt
///
/// Spec und Entwurf nennen keine Dart-Namen. Damit der Implementierende
/// nicht raten muss, legt diese Datei fest — **nicht von Tim gesehen**:
///
/// | Was | Wo |
/// |---|---|
/// | `void oeffneZyklusEinrichten(AppRouter router)` | `lib/zyklus/zyklus_einrichten_view.dart` |
/// | `ZyklusEinrichtenSeite({Key? key})` | ebenda |
/// | `MehrSeite({required AppRouter router})` | `lib/shell/mehr_view.dart` |
/// | `sealed class ZyklusImportStand` + `zyklusImportStandProvider` | `lib/zyklus/zyklus_zustand.dart` |
///
/// Schlüssel:
///
/// | Schlüssel | Was |
/// |---|---|
/// | `zyklus-einrichten` | der Schirm selbst |
/// | `zyklus-einrichten-schalter` | die Schalterzeile „Zyklus" |
/// | `zyklus-einrichten-ausblenden` | die Zeile „Ausblenden löscht nichts" |
/// | `zyklus-einrichten-import` | der Abschnitt „Aus Apple Health" |
/// | `zyklus-einrichten-wofuer` | der Abschnitt „Wofür" |
/// | `zyklus-einrichten-sicht-ueberblick` / `-kinderwunsch` | die beiden Felder |
/// | `zyklus-einrichten-verhuetung` | der Abschnitt „Hormonelle Verhütung" |
/// | `zyklus-einrichten-verhuetung-schalter` | dessen Schalterzeile |
/// | `zyklus-einrichten-seit` | die Zeile „Seit" |
/// | `zyklus-zahnrad` | das Zahnrad in der Leiste des Kalenders |
/// | `mehr-zyklus` | die Zeile „Zyklus" unter *Mehr* |
/// | `mehr-zyklus-einrichten` | die Zeile „Zyklus einrichten" unter *Mehr* |
///
/// Weitere Festlegungen, jede mit ihrem Grund an Ort und Stelle:
///
/// - **`MehrView` bleibt ohne `ref`.** Drei bestehende Testdateien pumpen
///   sie ohne `ProviderScope` (`mehr_view_test.dart`,
///   `mehr_attribution_test.dart`, `vorlaeufige_werte_test.dart`); eine
///   `ConsumerWidget` an dieser Stelle machte sie alle rot. Den Schalter
///   liest deshalb eine Ebene höher `MehrSeite`, und `MehrView` bekommt
///   den Stand als `zyklusAn` gereicht — Vorgabe `false`, damit die
///   bestehenden Tests unverändert gelten.
/// - **`MehrZiel` bekommt keine neuen Fälle.**
///   `mehr_view_test.dart` bindet `MehrZiel.values.length` an die Zahl der
///   dreizehn festen Zeilen. Eine Zeile, die nur manchmal da ist, passt
///   ohnehin nicht in diese Aufzählung.
/// - **Der Import hat eine eigene Naht** (`ZyklusImportStand`): Den
///   HealthKit-Leser für Zyklusdaten gibt es noch nicht, der Zustand
///   „nichts in Health" wäre sonst unerreichbar — und die
///   Keine-Daten-Ansicht ist kein Nachtrag (`CLAUDE.md`).
///
/// ## Erfundene Daten
///
/// Jeder Tag hier ist ausgedacht und liegt im Jahr 2099. **Es steht kein
/// einziger echter Gesundheitswert im Quelltext** (`CLAUDE.md`).
void main() {
  // 12:00 Berliner Zeit am 17.11.2099 — weit weg von dem Tag, an dem
  // dieser Test läuft, damit ein `DateTime.now()` auffiele.
  final jetzt = DateTime.utc(2099, 11, 17, 11);

  const blutungstage = ['2099-11-06', '2099-11-07', '2099-11-08'];

  final schirm = find.byKey(const Key('zyklus-einrichten'));
  final schalter = find.byKey(const Key('zyklus-einrichten-schalter'));
  final ausblenden = find.byKey(const Key('zyklus-einrichten-ausblenden'));
  final importAbschnitt = find.byKey(const Key('zyklus-einrichten-import'));
  final wofuer = find.byKey(const Key('zyklus-einrichten-wofuer'));
  final verhuetung = find.byKey(const Key('zyklus-einrichten-verhuetung'));
  final verhuetungSchalter = find.byKey(
    const Key('zyklus-einrichten-verhuetung-schalter'),
  );
  final seit = find.byKey(const Key('zyklus-einrichten-seit'));
  final kinderwunsch = find.byKey(
    const Key('zyklus-einrichten-sicht-kinderwunsch'),
  );

  late AppCache db;
  late ZyklusRepository repo;

  setUpAll(() async {
    await initializeDateFormatting('de_DE');
  });

  setUp(() async {
    db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);
    repo = ZyklusRepository(db, uhr: () => jetzt);
  });

  Future<void> legeBlutung() async {
    for (final tag in blutungstage) {
      await repo.schreibe(
        ZyklusEintrag(tag: tag, blutung: Blutungsstaerke.mittel),
      );
    }
  }

  ProviderContainer behaelter({ZyklusImportStand? importStand}) {
    final container = ProviderContainer(
      // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
      retry: (_, _) => null,
      overrides: [
        appCacheProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => jetzt),
        healthProvider.overrideWithValue(const HealthReadingAttrappe()),
        if (importStand != null)
          zyklusImportStandProvider.overrideWithValue(importStand),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Der Schirm auf einem `Navigator`, wie ihn `RootView` für den Stapel
  /// eines Tabs stellt.
  Future<void> zeigeSchirm(
    WidgetTester tester, {
    ProviderContainer? container,
  }) async {
    tester.view.physicalSize = const Size(900, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      BehaelterImBaum(
        container: container ?? behaelter(),
        child: const CupertinoApp(home: ZyklusEinrichtenSeite()),
      ),
    );
    await tester.pumpAndSettle();
    expect(schirm, findsOneWidget, reason: 'Der Schirm steht.');
  }

  /// Schaltet den Kalender ein, bevor der Schirm aufgeht — der
  /// Dauerzustand des Entwurfs (`eingerichtet`).
  Future<void> schalteEin() => repo.schreibeEinstellungen(
    ZyklusEinstellungen.vorbelegung.kopieMit(kalenderAn: true),
  );

  /// Alle Texte des Baums, zusammengefügt, Leerraum vereinheitlicht.
  String alleTexte(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map(textOf)
      .join(' ')
      .replaceAll(RegExp(r'\s+'), ' ');

  bool nennt(WidgetTester tester, String text) => alleTexte(
    tester,
  ).toUpperCase().contains(text.replaceAll(RegExp(r'\s+'), ' ').toUpperCase());

  // ───────────────────────────────────────────────────────────────────
  // Ausgeschaltet (Entwurf, Variante `aus`)
  // ───────────────────────────────────────────────────────────────────

  group('Ausgeschaltet', () {
    testWidgets('der Schalter steht und ist aus', (tester) async {
      await zeigeSchirm(tester);

      expect(schalter, findsOneWidget);
      expect(
        tester.widget<CupertinoSwitch>(
          find.descendant(of: schalter, matching: find.byType(CupertinoSwitch)),
        ).value,
        isFalse,
        reason:
            'Die Vorbelegung ist aus — eine App, die den Kalender '
            'ungefragt zeigt, hat ihn eingeschaltet, ohne zu fragen.',
      );
    });

    testWidgets('„Ausblenden löscht nichts" steht sichtbar', (tester) async {
      await zeigeSchirm(tester);

      expect(
        ausblenden,
        findsOneWidget,
        reason:
            'Eine Folge, die man vor dem Umlegen wissen muss, steht '
            'sichtbar — nicht hinter dem Fragezeichen (Fassung C).',
      );
      expect(nennt(tester, zyklusAusblendenFolge), isTrue);
    });

    testWidgets('es gibt keine weiteren Abschnitte', (tester) async {
      await zeigeSchirm(tester);

      expect(importAbschnitt, findsNothing);
      expect(wofuer, findsNothing);
      expect(verhuetung, findsNothing);
    });
  });

  // ───────────────────────────────────────────────────────────────────
  // Einschalten (Entwurf, Variante `einschalten`)
  // ───────────────────────────────────────────────────────────────────

  group('Einschalten', () {
    testWidgets('schreibt die Einstellung in die Ablage', (tester) async {
      await zeigeSchirm(tester);

      await tester.tap(schalter);
      await tester.pumpAndSettle();

      expect(
        (await repo.liesEinstellungen()).kalenderAn,
        isTrue,
        reason:
            'Der Schalter ist die einzige Stelle, an der sich der '
            'Kalender abschalten lässt — er muss ankommen.',
      );
    });

    testWidgets('lässt die drei Abschnitte erscheinen', (tester) async {
      await zeigeSchirm(tester);

      await tester.tap(schalter);
      await tester.pumpAndSettle();

      expect(importAbschnitt, findsOneWidget);
      expect(wofuer, findsOneWidget);
      expect(verhuetung, findsOneWidget);
    });

    testWidgets('nimmt den Hinweis „Ausblenden löscht nichts" weg', (
      tester,
    ) async {
      await zeigeSchirm(tester);

      await tester.tap(schalter);
      await tester.pumpAndSettle();

      expect(
        ausblenden,
        findsNothing,
        reason:
            'Die Zeile sagt, was beim Ausschalten passiert — '
            'eingeschaltet hat sie keinen Anlass (Entwurf).',
      );
    });
  });

  // ───────────────────────────────────────────────────────────────────
  // Ausschalten — die Zusage, die der Schirm gibt
  // ───────────────────────────────────────────────────────────────────

  group('Ausschalten', () {
    testWidgets('löscht keinen einzigen Eintrag', (tester) async {
      await legeBlutung();
      await schalteEin();
      await zeigeSchirm(tester);

      await tester.tap(schalter);
      await tester.pumpAndSettle();

      expect((await repo.liesEinstellungen()).kalenderAn, isFalse);
      expect(
        (await repo.imZeitraum(
          von: '2099-01-01',
          bis: '2099-12-31',
        )).map((e) => e.tag).toList(),
        blutungstage,
        reason:
            'Der Schirm sagt zu: „Ausblenden löscht nichts". Eine '
            'Zusage, die der Code nicht hält, ist schlimmer als keine '
            '(CLAUDE.md).',
      );
    });

    testWidgets('lässt die Einträge auch nach dem Wiedereinschalten stehen', (
      tester,
    ) async {
      await legeBlutung();
      await schalteEin();
      await zeigeSchirm(tester);

      await tester.tap(schalter);
      await tester.pumpAndSettle();
      await tester.tap(schalter);
      await tester.pumpAndSettle();

      expect((await repo.liesEinstellungen()).kalenderAn, isTrue);
      expect(
        (await repo.imZeitraum(von: '2099-01-01', bis: '2099-12-31')).length,
        blutungstage.length,
        reason: '„nach dem Einschalten ist alles wieder da".',
      );
    });
  });

  // ───────────────────────────────────────────────────────────────────
  // Die zwei Fragen (Entwurf, Varianten `eingerichtet`, `mit-verhuetung`)
  // ───────────────────────────────────────────────────────────────────

  group('Wofür', () {
    testWidgets('Kinderwunsch landet in der Ablage', (tester) async {
      await schalteEin();
      await zeigeSchirm(tester);

      await tester.tap(kinderwunsch);
      await tester.pumpAndSettle();

      expect(
        (await repo.liesEinstellungen()).sicht,
        ZyklusSicht.kinderwunsch,
      );
    });

    testWidgets('Überblick steht vorbelegt da', (tester) async {
      await schalteEin();
      await zeigeSchirm(tester);

      expect(
        find.byKey(const Key('zyklus-einrichten-sicht-ueberblick')),
        findsOneWidget,
      );
      expect((await repo.liesEinstellungen()).sicht, ZyklusSicht.ueberblick);
    });
  });

  group('Hormonelle Verhütung', () {
    testWidgets('das Umschalten landet in der Ablage', (tester) async {
      await schalteEin();
      await zeigeSchirm(tester);

      await tester.tap(verhuetungSchalter);
      await tester.pumpAndSettle();

      expect((await repo.liesEinstellungen()).verhuetungAn, isTrue);
    });

    testWidgets('die Zeile „Seit" steht erst, wenn verhütet wird', (
      tester,
    ) async {
      await schalteEin();
      await zeigeSchirm(tester);

      expect(
        seit,
        findsNothing,
        reason:
            'Ein Feld ohne seinen Anlass fragt etwas, das niemand '
            'beantworten kann (dasselbe Muster wie „Verhütet" auf '
            '„Tag eintragen").',
      );

      await tester.tap(verhuetungSchalter);
      await tester.pumpAndSettle();

      expect(seit, findsOneWidget);
    });

    testWidgets('die Verhütung trägt ihren Zeitpunkt', (tester) async {
      await schalteEin();
      await zeigeSchirm(tester);

      await tester.tap(verhuetungSchalter);
      await tester.pumpAndSettle();
      await tester.tap(seit);
      await tester.pumpAndSettle();

      final rad = find.byType(CupertinoDatePicker);
      expect(
        rad,
        findsOneWidget,
        reason: 'Die Zeile „Seit" klappt ein Datumsrad auf.',
      );
      tester
          .widget<CupertinoDatePicker>(rad)
          .onDateTimeChanged(DateTime(2099, 3, 1));
      await tester.pumpAndSettle();

      expect(
        (await repo.liesEinstellungen()).verhuetungSeit,
        '2099-03-01',
        reason:
            'Rückwirkend muss erkennbar bleiben, welcher Zyklus unter '
            'Verhütung lief (Spec 3.7) — ein zeitloses Ja/Nein kann das '
            'nicht.',
      );
    });

    testWidgets('das Zurücknehmen nimmt den Zeitpunkt mit', (tester) async {
      await repo.schreibeEinstellungen(
        const ZyklusEinstellungen(
          kalenderAn: true,
          sicht: ZyklusSicht.ueberblick,
          verhuetungAn: true,
          verhuetungSeit: '2099-03-01',
          verhuetungArt: null,
          importGelaufen: false,
          vorhersagePausiert: false,
        ),
      );
      await zeigeSchirm(tester);

      await tester.tap(verhuetungSchalter);
      await tester.pumpAndSettle();

      final stand = await repo.liesEinstellungen();
      expect(stand.verhuetungAn, isFalse);
      expect(
        stand.verhuetungSeit,
        isNull,
        reason:
            'Ein stehengebliebener Zeitpunkt behauptete eine Verhütung, '
            'die es nicht mehr gibt.',
      );
    });
  });

  // ───────────────────────────────────────────────────────────────────
  // Nichts in Health (Entwurf, Variante `ohne-health`)
  // ───────────────────────────────────────────────────────────────────

  group('Aus Apple Health', () {
    testWidgets('die Zeile steht auch dann, wenn Health nichts hergibt, und '
        'sagt es', (tester) async {
      await schalteEin();
      await zeigeSchirm(
        tester,
        container: behaelter(importStand: const ZyklusImportNichts()),
      );

      expect(
        importAbschnitt,
        findsOneWidget,
        reason:
            'Eine fehlende Zeile sähe aus wie eine Funktion, die es '
            'nicht gibt (CLAUDE.md).',
      );
      expect(nennt(tester, zyklusImportNichts), isTrue);
    });

    testWidgets('ein Fund wartet sichtbar auf eine Entscheidung', (
      tester,
    ) async {
      await schalteEin();
      await zeigeSchirm(
        tester,
        container: behaelter(importStand: const ZyklusImportGefunden(14)),
      );

      expect(importAbschnitt, findsOneWidget);
      expect(nennt(tester, zyklusImportWartet), isTrue);
    });

    testWidgets('ein gelaufener Import wartet auf nichts mehr', (tester) async {
      await schalteEin();
      await zeigeSchirm(
        tester,
        container: behaelter(importStand: const ZyklusImportGelaufen()),
      );

      expect(importAbschnitt, findsOneWidget);
      expect(
        nennt(tester, zyklusImportWartet),
        isFalse,
        reason: 'Was übernommen ist, wartet nicht mehr.',
      );
    });
  });

  // ───────────────────────────────────────────────────────────────────
  // Hinter dem Fragezeichen (Entwurf, Variante `hilfe`)
  // ───────────────────────────────────────────────────────────────────

  group('Hilfe', () {
    testWidgets('das Blatt öffnet sich hinter dem `?`', (tester) async {
      await zeigeSchirm(tester);

      expect(find.byKey(const Key('hilfe-fertig')), findsNothing);

      await tester.tap(find.text('?').first);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('hilfe-fertig')),
        findsOneWidget,
        reason: 'Erklärtexte stehen hinter dem `?` (Fassung C).',
      );
      expect(
        nennt(tester, zyklusEinrichtenHilfePflicht),
        isTrue,
        reason:
            'Der Pflichtsatz steht einmal oben im Blatt — keine '
            'Diagnosen, keine Verhütungsmethode (CLAUDE.md).',
      );
    });
  });

  // ───────────────────────────────────────────────────────────────────
  // Die Wege hierher
  // ───────────────────────────────────────────────────────────────────

  group('Mehr', () {
    Future<AppRouter> zeigeMehr(WidgetTester tester) async {
      tester.view.physicalSize = const Size(900, 3600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final router = AppRouter();
      await tester.pumpWidget(
        BehaelterImBaum(
          container: behaelter(),
          child: CupertinoApp(home: MehrSeite(router: router)),
        ),
      );
      await tester.pumpAndSettle();
      return router;
    }

    testWidgets('die Zeile „Zyklus" fehlt, solange der Kalender aus ist', (
      tester,
    ) async {
      await zeigeMehr(tester);

      expect(
        find.byKey(const Key('mehr-zyklus')),
        findsNothing,
        reason:
            'Was aus ist, verschwindet ganz (Entwurf, mehr.js) — ein '
            'abgeblendeter Eintrag sähe aus wie etwas, das noch kommt.',
      );
    });

    testWidgets('die Zeile „Zyklus" steht, sobald der Kalender an ist', (
      tester,
    ) async {
      await schalteEin();
      final router = await zeigeMehr(tester);

      final zeile = find.byKey(const Key('mehr-zyklus'));
      expect(zeile, findsOneWidget);

      await tester.tap(zeile);
      await tester.pumpAndSettle();

      expect(
        router.nimmBefehl(),
        isNotNull,
        reason: 'Die Zeile führt in den Kalender.',
      );
    });

    testWidgets('„Zyklus einrichten" steht auch bei ausgeschaltetem '
        'Kalender und führt auf den Schirm', (tester) async {
      final router = await zeigeMehr(tester);

      final zeile = find.byKey(const Key('mehr-zyklus-einrichten'));
      expect(
        zeile,
        findsOneWidget,
        reason:
            'Es ist der einzige Ort, an dem sich der Kalender '
            'einschalten lässt — er darf nicht an seinem eigenen '
            'Schalter hängen.',
      );

      await tester.tap(zeile);
      await tester.pumpAndSettle();

      expect(router.nimmBefehl(), isNotNull);
    });
  });

  group('Zahnrad im Kalender', () {
    testWidgets('öffnet „Zyklus einrichten"', (tester) async {
      await schalteEin();

      tester.view.physicalSize = const Size(900, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final navigator = GlobalKey<NavigatorState>();
      final router = AppRouter();
      void schiebe() {
        final befehl = router.nimmBefehl();
        if (befehl == null) return;
        navigator.currentState!.push(
          CupertinoPageRoute<void>(builder: befehl.builder),
        );
      }

      router.addListener(schiebe);
      addTearDown(() => router.removeListener(schiebe));

      await tester.pumpWidget(
        BehaelterImBaum(
          container: behaelter(),
          child: CupertinoApp(
            navigatorKey: navigator,
            home: ZyklusSeite(router: router),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('zyklus-zahnrad')));
      await tester.pumpAndSettle();

      expect(
        schirm,
        findsOneWidget,
        reason:
            'Das Entwurfsboard zeigt das Zahnrad in jeder Variante des '
            'Kalenders; es führt hierher.',
      );
    });
  });
}
