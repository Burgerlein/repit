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

import '../health/health_reading_attrappe.dart';
import '../tag/behaelter_im_baum.dart';

/// Widget-Tests für das **gescheiterte und das überlebende Löschen** (#486
/// unter #88) — die Nacharbeit zum Review vom 18.11.2026. Den Normalfall
/// prüft `umfaenge_loeschen_wisch_test.dart`; diese Datei nagelt zwei
/// Verhalten fest, die dort fehlten:
///
/// 1. **Scheitert das Löschen, steht die Zeile wieder da** — und ein
///    Hinweis sagt, was los ist. Eine Zeile, die verschwindet, während der
///    Wert noch in der Ablage liegt, ist eine falsche Auskunft; dasselbe
///    Argument wie bei `_panne` in `gewicht_eintragen.dart` („Ein
///    geschlossenes Blatt behauptete, die Probe sei weg").
/// 2. **Das Löschen überlebt das Poppen des Schirms.** Wer löscht und
///    sofort zurückgeht, darf weder einen „ref after dispose"-Fehler
///    auslösen noch einen alten Stand sehen: Der gelöschte Wert ist auch
///    auf dem Schirm darunter verschwunden, sobald das Löschen durch ist.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden.
///
/// ## Die Schlüssel, auf die sich diese Tests festlegen
///
/// | Schlüssel | Was |
/// |---|---|
/// | `umfaenge-loeschen-panne` | der Hinweis auf der Übersicht |
/// | `umfang-detail-loeschen-panne` | der Hinweis auf dem Maß-Verlauf |
///
/// Der Wortlaut der Hinweise ist absichtlich nicht geprüft — Zustände und
/// Übergänge, nicht Beschriftung.
///
/// ## Erfundene Zahlen
///
/// Jeder Umfang und jeder Tag ist ausgedacht und liegt im Jahr 2099.
void main() {
  /// 12:00 Berliner Zeit am 16.02.2099 (Winterzeit, UTC+1).
  final jetzt = DateTime.utc(2099, 2, 16, 11);
  const tagAlt = '2099-01-05';
  const tagNeu = '2099-02-02';

  final kachel = find.byKey(const Key('koerper-kachel-umfaenge'));
  final uebersicht = find.byKey(const Key('umfaenge-uebersicht'));
  final frage = find.byKey(const Key('umfang-loeschen-frage'));
  final bestaetigen = find.byKey(const Key('umfang-loeschen-bestaetigen'));
  final uebersichtPanne = find.byKey(const Key('umfaenge-loeschen-panne'));
  final detailPanne = find.byKey(const Key('umfang-detail-loeschen-panne'));

  Finder messZeile(String tag) => find.byKey(Key('umfaenge-messung-$tag'));
  Finder detailZeile(String tag) =>
      find.byKey(Key('umfang-detail-messung-$tag'));
  Finder massZeile(Umfang mass) =>
      find.byKey(Key('umfaenge-mass-${mass.schluessel}'));
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

  Future<void> zweiMesstage() async {
    await lege(tagAlt, {Umfang.brust: 101.0, Umfang.taille: 86.0});
    await lege(tagNeu, {Umfang.brust: 103.5, Umfang.taille: 84.0});
  }

  ProviderContainer behaelter(UmfaengeRepository repo) {
    final container = ProviderContainer(
      // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
      retry: (_, _) => null,
      overrides: [
        appCacheProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => jetzt),
        healthProvider.overrideWithValue(const HealthReadingAttrappe()),
        umfaengeRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> zeigeUebersicht(
    WidgetTester tester,
    UmfaengeRepository repo,
  ) async {
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
        container: behaelter(repo),
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

  Future<void> oeffneVerlauf(WidgetTester tester, Umfang mass) async {
    final zeile = massZeile(mass);
    await tester.ensureVisible(zeile);
    await tester.pumpAndSettle();
    await tester.tap(zeile);
    await tester.pumpAndSettle();
    expect(schirm(mass), findsOneWidget);
  }

  Future<void> wische(WidgetTester tester, Finder zeile) async {
    expect(zeile, findsOneWidget, reason: 'Siehe „Die Schlüssel" im Kopf.');
    await tester.ensureVisible(zeile);
    await tester.pumpAndSettle();
    await tester.drag(zeile, const Offset(-500, 0));
    await tester.pumpAndSettle();
  }

  Future<void> bestaetige(WidgetTester tester) async {
    expect(frage, findsOneWidget);
    await tester.tap(bestaetigen);
    await tester.pumpAndSettle();
  }

  group('Löschen scheitert', () {
    testWidgets('Übersicht: Die Zeile steht wieder da, der Wert ist '
        'unverändert, ein Hinweis sagt es', (tester) async {
      await zweiMesstage();
      await zeigeUebersicht(tester, _AblageOhneLoeschen(db, uhr: () => jetzt));

      await wische(tester, messZeile(tagNeu));
      await bestaetige(tester);

      expect(
        messZeile(tagNeu),
        findsOneWidget,
        reason:
            'Eine Zeile, die verschwindet, während der Wert noch da ist, '
            'ist eine falsche Auskunft — der Merker wird zurückgenommen.',
      );
      expect(
        (await ablage().messungAm(tagNeu))?.werte[Umfang.brust],
        103.5,
        reason: 'In der Ablage hat sich nichts geändert.',
      );
      expect(
        uebersichtPanne,
        findsOneWidget,
        reason:
            'Ohne Satz tippt man wieder und wieder auf eine Geste, die '
            'nichts tut (dasselbe Argument wie in `gewicht_eintragen.dart`).',
      );
    });

    testWidgets('Maß-Verlauf: Die Zeile steht wieder da, ein Hinweis sagt '
        'es', (tester) async {
      await zweiMesstage();
      await zeigeUebersicht(tester, _AblageOhneLoeschen(db, uhr: () => jetzt));
      await oeffneVerlauf(tester, Umfang.brust);

      await wische(tester, detailZeile(tagNeu));
      await bestaetige(tester);

      expect(detailZeile(tagNeu), findsOneWidget);
      expect(
        (await ablage().messungAm(tagNeu))?.werte[Umfang.brust],
        103.5,
        reason: 'In der Ablage hat sich nichts geändert.',
      );
      expect(detailPanne, findsOneWidget);
    });

    testWidgets('Ein zweiter, gelingender Versuch nimmt den Hinweis wieder '
        'weg', (tester) async {
      await zweiMesstage();
      final launisch = _AblageErsterVersuchScheitert(db, uhr: () => jetzt);
      await zeigeUebersicht(tester, launisch);

      await wische(tester, messZeile(tagNeu));
      await bestaetige(tester);
      expect(uebersichtPanne, findsOneWidget);

      await wische(tester, messZeile(tagNeu));
      await bestaetige(tester);

      expect(uebersichtPanne, findsNothing);
      expect(messZeile(tagNeu), findsNothing);
      expect(await ablage().messungAm(tagNeu), isNull);
    });
  });

  group('Löschen überlebt das Poppen', () {
    testWidgets('Zurück während des Löschens: kein Fehler, und der Stand '
        'darunter ist der neue', (tester) async {
      await zweiMesstage();
      await zeigeUebersicht(
        tester,
        _AblageLoeschtLangsam(db, uhr: () => jetzt),
      );
      await oeffneVerlauf(tester, Umfang.brust);

      await wische(tester, detailZeile(tagNeu));
      expect(frage, findsOneWidget);
      await tester.tap(bestaetigen);
      // Dialog zu, Wischanimation durch, das Löschen läuft jetzt — aber
      // es ist noch nicht fertig (die Ablage braucht 600 ms).
      await tester.pump(const Duration(milliseconds: 300));

      // Zurück auf die Übersicht, während das Löschen noch läuft.
      navigator.currentState!.pop();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      expect(
        tester.takeException(),
        isNull,
        reason:
            'Ein gepoppter Schirm darf das laufende Löschen nicht in '
            '„Cannot use ref after dispose" laufen lassen.',
      );
      expect(uebersicht, findsOneWidget);
      expect(
        (await ablage().messungAm(tagNeu))?.werte[Umfang.brust],
        isNull,
        reason: 'Das Löschen ist trotz Poppen durchgelaufen.',
      );
      expect(
        find.textContaining('103,5'),
        findsNothing,
        reason:
            'Die Übersicht zeigt den neuen Stand — die Invalidierung '
            'überlebt das Poppen, sonst stünde der gelöschte Wert noch da.',
      );
    });
  });
}

/// Eine Ablage, deren Löschen immer scheitert — Lesen und Schreiben laufen
/// normal über die echte Tabelle.
class _AblageOhneLoeschen extends UmfaengeRepository {
  _AblageOhneLoeschen(super.db, {super.uhr});

  @override
  Future<void> loescheMass({required String tag, required Umfang mass}) async =>
      throw StateError('Löschen scheitert (Testattrappe)');

  @override
  Future<void> loescheMesstag(String tag) async =>
      throw StateError('Löschen scheitert (Testattrappe)');
}

/// Eine Ablage, deren Löschen beim ersten Mal scheitert und danach gelingt.
class _AblageErsterVersuchScheitert extends UmfaengeRepository {
  _AblageErsterVersuchScheitert(super.db, {super.uhr});

  var _versuche = 0;

  @override
  Future<void> loescheMesstag(String tag) async {
    _versuche += 1;
    if (_versuche == 1) {
      throw StateError('Löschen scheitert einmal (Testattrappe)');
    }
    return super.loescheMesstag(tag);
  }
}

/// Eine Ablage, deren Löschen 600 ms braucht — lang genug, um den Schirm
/// vorher zu poppen.
class _AblageLoeschtLangsam extends UmfaengeRepository {
  _AblageLoeschtLangsam(super.db, {super.uhr});

  @override
  Future<void> loescheMass({required String tag, required Umfang mass}) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return super.loescheMass(tag: tag, mass: mass);
  }
}
