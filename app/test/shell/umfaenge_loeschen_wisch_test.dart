import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/data/umfaenge_repository.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/shell/koerper_view.dart';
import 'package:repit/shell/router.dart';

import '../design/support.dart' show textOf;
import '../health/health_reading_attrappe.dart';
import '../tag/behaelter_im_baum.dart';

/// Widget-Tests für das **Löschen per Wischen** (#486 unter #88) — die
/// Übersicht löscht den ganzen Messtag, der Maß-Verlauf ein einzelnes Maß,
/// beide mit Rückfrage.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden. Hält der
/// Implementierende einen Fall für falsch, **meldet** er ihn.
///
/// ## Woher die Anforderung kommt
///
/// Issue #486 und der Entwurf `ac84126`: `docs/screens/screens/umfaenge.js`
/// (Zustände `wischen-tag`, `loeschen-tag`, `nach-loeschen-tag`,
/// `loeschen-letzter`) und `docs/screens/screens/umfang-detail.js`
/// (`vertipper`, Rückfrage, nach dem Löschen). Die Datenschicht darunter
/// prüft `test/data/umfaenge_loeschen_test.dart`.
///
/// ## Worauf diese Datei zielt
///
/// `CLAUDE.md`, „Tests": **Zustände und Übergänge, nicht Layout und
/// Beschriftung.** Die vier Zusagen:
///
/// 1. **Wischen allein löscht nichts** — erst erscheint die Rückfrage.
///    Es gibt keinen Papierkorb und kein Rückgängig; die Rückfrage ist der
///    einzige Halt.
/// 2. **Abbrechen lässt alles stehen** — auf dem Schirm und in der Ablage.
/// 3. **Löschen entfernt die Zeile**, und der gelöschte Wert taucht in
///    keinem Verlauf und keiner Veränderung mehr auf; die übrigen
///    Zeilen/Maße bleiben.
/// 4. **Der letzte Messtag gelöscht heißt Leerzustand** — derselbe, den es
///    schon gibt, und „Alle Messungen" bleibt als Gruppe stehen (eine
///    Anzeige, die es gibt, hat genau eine Form).
///
/// ## Die Schlüssel, auf die sich diese Tests festlegen
///
/// | Schlüssel | Was |
/// |---|---|
/// | `umfaenge-messung-<tag>` | die Messtag-Zeile der Übersicht (besteht) |
/// | `umfang-detail-messung-<tag>` | die Messpunkt-Zeile im Maß-Verlauf (neu) |
/// | `umfang-loeschen-frage` | die Rückfrage (CupertinoAlertDialog) |
/// | `umfang-loeschen-abbrechen` | der sichere Platz |
/// | `umfang-loeschen-bestaetigen` | der rote Platz |
///
/// Die Dialog-Schlüssel gelten auf **beiden** Schirmen: Es ist dieselbe
/// Rückfrage, nur Titel und Text nennen etwas anderes. Welcher Wortlaut
/// genau dasteht, prüft diese Datei absichtlich nicht (kein
/// Beschriftungstest) — **dass** der Dialog erscheint und was Abbrechen und
/// Löschen tun, schon.
///
/// ## Erfundene Zahlen
///
/// Jeder Umfang und jeder Tag ist ausgedacht und liegt im Jahr 2099. Keine
/// Zahl stammt aus `docs/screens/` — die dortigen sind erfunden und wären
/// als Erwartungswert ein Scheinbeweis.
void main() {
  /// 12:00 Berliner Zeit am 16.02.2099 (Winterzeit, UTC+1).
  final jetzt = DateTime.utc(2099, 2, 16, 11);
  const tagAlt = '2099-01-05';
  const tagMitte = '2099-01-19';
  const tagNeu = '2099-02-02';

  final kachel = find.byKey(const Key('koerper-kachel-umfaenge'));
  final uebersicht = find.byKey(const Key('umfaenge-uebersicht'));
  final leerHinweis = find.byKey(const Key('umfaenge-leer'));
  final messungenGruppe = find.byKey(const Key('umfaenge-messungen'));
  final frage = find.byKey(const Key('umfang-loeschen-frage'));
  final abbrechen = find.byKey(const Key('umfang-loeschen-abbrechen'));
  final bestaetigen = find.byKey(const Key('umfang-loeschen-bestaetigen'));

  Finder messZeile(String tag) => find.byKey(Key('umfaenge-messung-$tag'));
  Finder massZeile(Umfang mass) =>
      find.byKey(Key('umfaenge-mass-${mass.schluessel}'));
  Finder detailZeile(String tag) =>
      find.byKey(Key('umfang-detail-messung-$tag'));
  Finder schirm(Umfang mass) =>
      find.byKey(Key('umfang-detail-${mass.schluessel}'));

  late AppCache db;
  late GlobalKey<NavigatorState> navigator;

  setUpAll(() async {
    await initializeDateFormatting('de_DE');
  });

  setUp(() {
    db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);
  });

  UmfaengeRepository ablage() => UmfaengeRepository(db, uhr: () => jetzt);

  Future<void> lege(String tag, Map<Umfang, double> werte) =>
      ablage().schreibeGetippt(tag: tag, werte: werte);

  ProviderContainer behaelter() {
    final container = ProviderContainer(
      // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
      retry: (_, _) => null,
      overrides: [
        appCacheProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => jetzt),
        healthProvider.overrideWithValue(const HealthReadingAttrappe()),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Der Gastgeber: der Körper-Schirm auf einem Navigator, der jeden Befehl
  /// des [AppRouter] schiebt — wie `RootView` es für den Stapel eines Tabs
  /// tut. Danach steht die Übersicht auf dem Stapel.
  Future<void> zeigeUebersicht(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 4200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    navigator = GlobalKey<NavigatorState>();
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
          home: CupertinoPageScaffold(child: KoerperView(router: router)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(kachel);
    await tester.pumpAndSettle();
    await tester.tap(kachel);
    await tester.pumpAndSettle();

    expect(uebersicht, findsOneWidget);
  }

  /// Von der Übersicht aus den Verlauf eines Maßes öffnen.
  Future<void> oeffneVerlauf(WidgetTester tester, Umfang mass) async {
    final zeile = massZeile(mass);
    await tester.ensureVisible(zeile);
    await tester.pumpAndSettle();
    await tester.tap(zeile);
    await tester.pumpAndSettle();
    expect(schirm(mass), findsOneWidget);
  }

  /// Nach links wischen — weit genug, dass die Wischgeste als Löschabsicht
  /// gilt. Danach entscheidet die Rückfrage, nicht die Geste.
  Future<void> wische(WidgetTester tester, Finder zeile) async {
    expect(zeile, findsOneWidget, reason: 'Siehe „Die Schlüssel" im Kopf.');
    await tester.ensureVisible(zeile);
    await tester.pumpAndSettle();
    await tester.drag(zeile, const Offset(-500, 0));
    await tester.pumpAndSettle();
  }

  Future<void> tippe(WidgetTester tester, Finder ziel) async {
    expect(ziel, findsOneWidget, reason: 'Siehe „Die Schlüssel" im Kopf.');
    await tester.tap(ziel);
    await tester.pumpAndSettle();
  }

  String alleTexte(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map(textOf)
      .join(' ')
      .replaceAll(RegExp(r'\s+'), ' ');

  // ───────────────────────────────────────────────────────────────────────
  // Übersicht: der ganze Messtag
  // ───────────────────────────────────────────────────────────────────────

  group('Übersicht · Messtag löschen', () {
    Future<void> zweiMesstage() async {
      await lege(tagAlt, {Umfang.brust: 101.0, Umfang.taille: 86.0});
      await lege(tagNeu, {
        Umfang.brust: 103.5,
        Umfang.taille: 84.0,
        Umfang.hals: 39.5,
      });
    }

    testWidgets('Wischen löscht nichts — erst kommt die Rückfrage', (
      tester,
    ) async {
      await zweiMesstage();
      await zeigeUebersicht(tester);

      await wische(tester, messZeile(tagNeu));

      expect(
        frage,
        findsOneWidget,
        reason:
            'Es gibt keinen Papierkorb und kein Rückgängig — die Rückfrage '
            'ist der einzige Halt (#486). Ohne sie hätte die Geste bereits '
            'gelöscht.',
      );
      expect(
        (await ablage().messungen()).length,
        2,
        reason: 'Solange die Rückfrage offen ist, ist nichts gelöscht.',
      );
    });

    testWidgets('Abbrechen lässt alles stehen', (tester) async {
      await zweiMesstage();
      await zeigeUebersicht(tester);

      await wische(tester, messZeile(tagNeu));
      await tippe(tester, abbrechen);

      expect(frage, findsNothing, reason: 'Die Rückfrage ist beantwortet.');
      expect(
        messZeile(tagNeu),
        findsOneWidget,
        reason: 'Die Zeile gleitet zurück, sie verschwindet nicht.',
      );
      expect(
        (await ablage().messungen()).length,
        2,
        reason: 'Abbrechen löscht nichts — auch nicht in der Ablage.',
      );
    });

    testWidgets('Löschen entfernt den Messtag aus Liste, Werten und Ablage', (
      tester,
    ) async {
      await zweiMesstage();
      await zeigeUebersicht(tester);

      await wische(tester, messZeile(tagNeu));
      await tippe(tester, bestaetigen);

      expect(messZeile(tagNeu), findsNothing);
      expect(
        messZeile(tagAlt),
        findsOneWidget,
        reason: 'Der andere Messtag bleibt stehen.',
      );
      expect(
        await ablage().messungAm(tagNeu),
        isNull,
        reason: 'Der Tag ist aus der Ablage verschwunden.',
      );

      final texte = alleTexte(tester);
      expect(
        texte.contains('103,5'),
        isFalse,
        reason:
            'Der gelöschte Wert taucht nirgends mehr auf — nicht in den '
            'Maß-Zeilen, nicht in der Liste („Fertig, wenn", #486).',
      );
      expect(
        texte.contains('101,0'),
        isTrue,
        reason:
            'Die Maß-Zeilen rechnen neu: Der jüngste Brust-Wert ist jetzt '
            'der des älteren Tages.',
      );
    });

    testWidgets('Der letzte Messtag gelöscht führt in den Leerzustand', (
      tester,
    ) async {
      await lege(tagNeu, {Umfang.brust: 103.5, Umfang.taille: 84.0});
      await zeigeUebersicht(tester);

      await wische(tester, messZeile(tagNeu));
      await tippe(tester, bestaetigen);

      expect(
        leerHinweis,
        findsOneWidget,
        reason:
            'Verschwindet der letzte Messtag, steht der Schirm im Zustand '
            '„Noch nichts erfasst" — kein eigener Leerzustand fürs Löschen '
            '(Entwurf `umfaenge.js`, `loeschen-letzter`).',
      );
      expect(
        messungenGruppe,
        findsOneWidget,
        reason:
            '„Alle Messungen" fällt in keinem Zustand weg — nur die Füllung '
            'ändert sich, nicht die Form.',
      );
      expect(await ablage().messungen(), isEmpty);
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // Maß-Verlauf: ein einzelnes Maß
  // ───────────────────────────────────────────────────────────────────────

  group('Maß-Verlauf · einzelnes Maß löschen', () {
    /// Der Vertipper aus dem Entwurf, mit eigenen erfundenen Zahlen:
    /// In der Mitte steht ein Ausreißer, und am selben Tag ist auch die
    /// Taille gemessen — genau die bleibt stehen.
    Future<void> vertipper() async {
      await lege(tagAlt, {Umfang.brust: 101.0});
      await lege(tagMitte, {Umfang.brust: 112.3, Umfang.taille: 84.0});
      await lege(tagNeu, {Umfang.brust: 103.5});
    }

    testWidgets('Wischen zeigt die Rückfrage, Abbrechen lässt die Zeile '
        'stehen', (tester) async {
      await vertipper();
      await zeigeUebersicht(tester);
      await oeffneVerlauf(tester, Umfang.brust);

      await wische(tester, detailZeile(tagMitte));
      expect(
        frage,
        findsOneWidget,
        reason: 'Auch hier löscht die Geste nichts ohne Rückfrage.',
      );

      await tippe(tester, abbrechen);
      expect(frage, findsNothing);
      expect(
        detailZeile(tagMitte),
        findsOneWidget,
        reason: 'Die Zeile gleitet zurück.',
      );
      expect(
        (await ablage().messungAm(tagMitte))?.werte[Umfang.brust],
        112.3,
        reason: 'Abbrechen löscht nichts — auch nicht in der Ablage.',
      );
    });

    testWidgets('Löschen entfernt den Messpunkt, die übrigen Maße des Tages '
        'bleiben', (tester) async {
      await vertipper();
      await zeigeUebersicht(tester);
      await oeffneVerlauf(tester, Umfang.brust);

      await wische(tester, detailZeile(tagMitte));
      await tippe(tester, bestaetigen);

      expect(detailZeile(tagMitte), findsNothing);
      expect(
        detailZeile(tagAlt),
        findsOneWidget,
        reason: 'Die übrigen Messpunkte dieses Maßes bleiben.',
      );
      expect(detailZeile(tagNeu), findsOneWidget);

      final texte = alleTexte(tester);
      expect(
        texte.contains('112,3'),
        isFalse,
        reason:
            'Der Ausreißer taucht nirgends mehr auf — nicht in der Liste, '
            'nicht in der Spanne, nicht in der Veränderung („Fertig, '
            'wenn", #486).',
      );

      final amTag = await ablage().messungAm(tagMitte);
      expect(
        amTag?.werte,
        {Umfang.taille: 84.0},
        reason:
            'Nur dieses eine Maß ist weg; die Taille desselben Tages steht '
            'noch — das ist der ganze Unterschied zur Übersicht.',
      );
    });

    testWidgets('War es das letzte Maß des Tages, verschwindet der Tag auch '
        'aus der Übersicht', (tester) async {
      await vertipper();
      await zeigeUebersicht(tester);
      await oeffneVerlauf(tester, Umfang.brust);

      // tagNeu trägt nur die Brust — nach dem Löschen ist er kein Messtag
      // mehr.
      await wische(tester, detailZeile(tagNeu));
      await tippe(tester, bestaetigen);
      expect(detailZeile(tagNeu), findsNothing);

      navigator.currentState!.pop();
      await tester.pumpAndSettle();

      expect(uebersicht, findsOneWidget);
      expect(
        messZeile(tagNeu),
        findsNothing,
        reason:
            'Ein Tag ohne Maße ist kein Messtag mehr (Entwurf '
            '`umfang-detail.js`) — und der Stand ist nach dem '
            'Zurücknavigieren derselbe, nicht ein alter (`32`).',
      );
      expect(messZeile(tagMitte), findsOneWidget);
      expect(messZeile(tagAlt), findsOneWidget);
    });
  });
}
