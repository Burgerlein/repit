import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/data/ernaehrung_repository.dart';
import 'package:repit/data/lebensmittel_repository.dart';
import 'package:repit/design/symbole.dart';
import 'package:repit/ernaehrung/buchungs_blatt.dart';
import 'package:repit/ernaehrung/ernaehrung_view.dart';
import 'package:repit/ernaehrung/mahlzeit_view.dart';
import 'package:repit/ernaehrung/off_client.dart';
import 'package:repit/ernaehrung/strichcode_leser.dart';
import 'package:repit/ernaehrung/suche_view.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/shell/root_view.dart';
import 'package:repit/shell/router.dart';

import 'kamera_attrappe.dart';
import '../health/health_reading_attrappe.dart';
import '../tag/behaelter_im_baum.dart';

/// „Zu dieser Mahlzeit hinzufügen" öffnet **die Kamera** (#344) — denselben
/// Einstieg wie der (+), aber mit **dieser** Mahlzeit und **diesem** Tag
/// vorgewählt: im Buchungsblatt nach einem Scan, und auf dem Weg über
/// „Suchen" (seit #439 eine Kachel unten, bis dahin oben rechts).
///
/// Anforderung von Tim (04.11.2026, Gerät): „Frühstück › hinzufügen ›
/// Barcode scannen bucht ins Frühstück des offenen Tages; ‚Suchen' von dort
/// ebenso." Ohne Mahlzeit — der Weg über den (+) — bleibt alles, wie es war:
/// Die Mahlzeit ergibt sich aus der Uhrzeit.
///
/// **Die Uhrzeit ist die des Trackens (#328)**, auch mit vorgewählter
/// Mahlzeit: Tim, 04.11.2026, „immer die Uhrzeit, an der ich es tracke, man
/// kann es ja manuell umstellen". Dass das Vorwählen der Mahlzeit die
/// Uhrzeit **nicht** auf die Fenstermitte zieht, ist eine Auslegung des
/// Test-Agenten von #344 aus dieser Aussage — Tim hat sie für diesen Weg
/// nicht eigens entschieden. Das Umhängen **im Blatt** zieht weiter auf die
/// Mitte (`erfassen_formular_test.dart`); das prüft diese Datei nicht.
///
/// Geprüft an der **ganzen** App (`RootView`) auf einer Datenbank im
/// Speicher, wie `eintragweg_verdrahtung_test.dart` und
/// `barcode_kamera_test.dart`: Eine Tür, die im Einzeltest aufgeht und in
/// der App an einem fehlenden `router` hängt, ist genau der Fehler, um den
/// es hier geht.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung**
/// (`CLAUDE.md`). Für Widget-Tests genügt ein Agent, solange der Test
/// zuerst entsteht, einmal rot gesehen und committet wird, bevor die
/// Implementierung anfängt. Danach darf diese Datei ausgeführt, aber nicht
/// verändert werden.
///
/// Nicht geprüft: Layout und Beschriftung (`CLAUDE.md`), und was die Kamera
/// selbst tut — das prüft `barcode_kamera_test.dart`.
///
/// **Nachtrag #345** (Tims Entscheidung vom 04.11.2026): Ohne Suchtext
/// stehen unter „Zuletzt benutzt" nur gebuchte Lebensmittel. Das
/// Lebensmittel dieser Hülle ist nur angelegt; [waehle] sucht deshalb
/// zuerst danach, wie in `eintragweg_verdrahtung_test.dart`. Vom
/// Test-Agenten von #345 geändert, Tim hat die Änderung nicht gesehen.
///
/// **Nachtrag #440** (10.11.2026): Tim hat V26 bestätigt (Spec
/// `2026-11-10-mahlzeiten-aufteilung-design.md`): Nach einer Buchung über
/// das Blatt bleibt die Suche offen. 'das Blatt aus der Suche kommt mit
/// Mahlzeit und Tag' prüft deshalb, dass sie nach dem Buchen noch
/// dasteht, schließt sie über „Fertig" (`Key('erfassen-fertig')`, V29)
/// und erwartet danach wie bisher den Mahlzeiten-Schirm. Die Kamera
/// schließt nach einer Buchung weiter wie bisher. Vom Test-Agenten von
/// #440 umgestellt, Tim hat die Umstellung nicht gesehen.
///
/// Alle Produkte, Namen und Strichcodes hier sind **erfunden**.
void main() {
  // Dienstag, 14.07.2026, 12:00 Berliner Zeit (MESZ, +2). Mittag — so
  // weicht jede ausdrücklich vorgewählte Mahlzeit von der ab, die die
  // Uhrzeit ergäbe.
  final jetzt = DateTime.utc(2026, 7, 14, 10);
  const heute = '2026-07-14';
  const gestern = '2026-07-13';

  /// 12:00 auf der Berliner Wanduhr — die Uhrzeit des Trackens (#328).
  const uhrzeitDesTrackens = 12 * 60;

  // Erfunden, und so, dass niemand ihn für echt hält.
  const codeEigen = '0000000004242';
  const eigenName = 'Prüfmüsli';

  // ───────────────────────────────────────────────────────────────────────
  // Testhülle
  // ───────────────────────────────────────────────────────────────────────

  ({
    ProviderContainer container,
    AppCache db,
    AppRouter router,
    TestLeser leser,
  })
  behaelter() {
    final db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);
    final leser = TestLeser();

    // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        appCacheProvider.overrideWithValue(db),
        healthProvider.overrideWithValue(_StilleQuelle()),
        clockProvider.overrideWithValue(() => jetzt),
        // Kein Netz im Test. Der gescannte Code steht in der eigenen
        // Tabelle, Open Food Facts wird gar nicht gefragt.
        offClientProvider.overrideWithValue(
          OffClient(client: MockClient((_) async => http.Response('', 500))),
        ),
        strichcodeLeserProvider.overrideWithValue(leser),
      ],
    );
    addTearDown(container.dispose);
    return (container: container, db: db, router: AppRouter(), leser: leser);
  }

  Future<void> starte(
    WidgetTester tester,
    ({
      ProviderContainer container,
      AppCache db,
      AppRouter router,
      TestLeser leser,
    })
    h,
  ) async {
    await LebensmittelRepository(h.db).legeAn(
      const LebensmittelVorlage(
        name: eigenName,
        je100g: Naehrwerte.je100g(kcal: 360, eiweissG: 11, fettG: 6),
        barcode: codeEigen,
      ),
    );

    tester.view.physicalSize = const Size(900, 4800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      BehaelterImBaum(
        container: h.container,
        child: CupertinoApp(home: RootView(router: h.router)),
      ),
    );
    await tester.pumpAndSettle();
  }

  // ───────────────────────────────────────────────────────────────────────
  // Helfer
  // ───────────────────────────────────────────────────────────────────────

  Future<void> tippe(WidgetTester tester, Finder ziel) async {
    await tester.tap(ziel);
    await tester.pumpAndSettle();
  }

  Future<void> zumErnaehrungsTab(WidgetTester tester) => tippe(
    tester,
    find.descendant(
      of: find.byType(CupertinoTabBar),
      matching: find.byIcon(Symbole.aufloesen('fork.knife')),
    ),
  );

  /// Ernährungs-Tab, über ‹ auf gestern, dann auf den Schirm des Abends —
  /// ein Tag, der nicht heute ist, und eine Mahlzeit, die 12:00 nicht
  /// ergäbe.
  Future<void> zumAbendVonGestern(WidgetTester tester) async {
    await zumErnaehrungsTab(tester);
    await tippe(tester, find.byKey(const Key('ernaehrung-zurueck')));
    await tippe(tester, find.byKey(const Key('ernaehrung-mahlzeit-abend')));
    final schirm = tester.widget<MahlzeitView>(find.byType(MahlzeitView));
    expect(schirm.mahlzeit, Mahlzeit.abend);
    expect(schirm.tagesSchluessel, gestern);
  }

  Future<void> hinzufuegen(WidgetTester tester) =>
      tippe(tester, find.byKey(const Key('mahlzeit-hinzufuegen')));

  Future<void> scanne(WidgetTester tester, TestLeser leser, String code) async {
    leser.erkenne(code);
    await tester.pumpAndSettle();
  }

  /// Tippt einen Treffer in der Suche an — öffnet das Buchungsblatt.
  ///
  /// Sucht vorher nach dem Anfangsbuchstaben: Seit #345 steht ein bloß
  /// angelegtes Lebensmittel ohne Suchtext nicht da. **Ein** Buchstabe,
  /// weil die Online-Suche erst ab zwei beginnt — sie ist hier nicht
  /// Gegenstand.
  Future<void> waehle(WidgetTester tester, String name) async {
    await tester.enterText(
      find.byKey(const Key('erfassen-suchfeld')),
      name.substring(0, 1),
    );
    await tester.pumpAndSettle();
    await tippe(
      tester,
      find.descendant(of: find.byType(SucheView), matching: find.text(name)),
    );
    expect(find.byType(BuchungsBlatt), findsOneWidget);
  }

  BuchungsBlatt blatt(WidgetTester tester) =>
      tester.widget<BuchungsBlatt>(find.byType(BuchungsBlatt));

  Future<void> buche(WidgetTester tester) async {
    await tippe(tester, find.byKey(const Key('buchung-sichern')));
    expect(
      find.byType(BuchungsBlatt),
      findsNothing,
      reason: 'nach dem Buchen schließt das Blatt',
    );
  }

  Future<List<Eintrag>> eintraegeAm(AppCache db, String tag) =>
      ErnaehrungRepository(db).eintraegeAmTag(tag);

  bool sichtbar(Finder f) => f.hitTestable().evaluate().isNotEmpty;

  // ═════════════════════════════════════════════════════════════════════
  group('„Zu dieser Mahlzeit hinzufügen" öffnet die Kamera', () {
    testWidgets('statt der Suche — auf dem Stapel des Tabs, in dem man ist', (
      tester,
    ) async {
      final h = behaelter();
      await starte(tester, h);
      await zumAbendVonGestern(tester);

      await hinzufuegen(tester);

      expect(
        find.byKey(const Key('kamera')),
        findsOneWidget,
        reason: 'derselbe Einstieg wie der (+) (#344)',
      );
      expect(
        h.leser.laeuft,
        isTrue,
        reason: 'die Vorschau aus `StrichcodeLeser.sucher` steht im Baum',
      );
      expect(find.byType(SucheView), findsNothing);
      expect(find.byType(CupertinoAlertDialog), findsNothing);
      expect(
        h.router.tab,
        Tab.ernaehrung,
        reason: 'ein Detailschirm wechselt nie den Tab (CLAUDE.md)',
      );
    });

    testWidgets('„Abbrechen" führt zurück auf den Mahlzeiten-Schirm', (
      tester,
    ) async {
      final h = behaelter();
      await starte(tester, h);
      await zumAbendVonGestern(tester);
      await hinzufuegen(tester);

      await tippe(tester, find.byKey(const Key('kamera-abbrechen')));

      expect(find.byKey(const Key('kamera')), findsNothing);
      expect(h.leser.laeuft, isFalse);
      expect(sichtbar(find.byType(MahlzeitView)), isTrue);
      expect(h.router.tab, Tab.ernaehrung);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Ein Scan bucht in diese Mahlzeit und auf diesen Tag', () {
    testWidgets('das Blatt kommt mit Mahlzeit und Tag des Schirms', (
      tester,
    ) async {
      final h = behaelter();
      await starte(tester, h);
      await zumAbendVonGestern(tester);
      await hinzufuegen(tester);

      await scanne(tester, h.leser, codeEigen);

      expect(find.byType(BuchungsBlatt), findsOneWidget);
      final formular = blatt(tester).formular;
      expect(
        formular.mahlzeit,
        Mahlzeit.abend,
        reason:
            'vorgewählt ist die Mahlzeit, von der man kam — nicht die, die '
            'die Uhrzeit ergäbe (12:00 wäre Mittag)',
      );
      expect(
        formular.tagesSchluessel,
        gestern,
        reason: 'der Tag des Mahlzeiten-Schirms, nicht „heute"',
      );
      expect(
        formular.minutenSeitMitternacht,
        uhrzeitDesTrackens,
        reason:
            'die Uhrzeit des Trackens (#328) — die vorgewählte Mahlzeit '
            'zieht sie nicht auf die Fenstermitte',
      );
    });

    testWidgets('gebucht steht der Eintrag dort, und die Kamera ist zu', (
      tester,
    ) async {
      final h = behaelter();
      await starte(tester, h);
      await zumAbendVonGestern(tester);
      await hinzufuegen(tester);
      await scanne(tester, h.leser, codeEigen);

      await buche(tester);

      final gebucht = await eintraegeAm(h.db, gestern);
      expect(gebucht, hasLength(1));
      expect(gebucht.single.name, eigenName);
      expect(gebucht.single.mahlzeit, Mahlzeit.abend);
      expect(
        await eintraegeAm(h.db, heute),
        isEmpty,
        reason:
            'ein Eintrag, der still auf dem falschen Tag landet, fällt erst '
            'nach Wochen auf (`erfassen.js`)',
      );

      expect(find.byKey(const Key('kamera')), findsNothing);
      expect(
        sichtbar(find.byType(MahlzeitView)),
        isTrue,
        reason: 'zurück auf den Mahlzeiten-Schirm, von dem aus gescannt wurde',
      );
      expect(
        find.byKey(Key('mahlzeit-eintrag-${gebucht.single.id}')),
        findsOneWidget,
        reason: 'der neue Eintrag steht sofort auf dem Mahlzeiten-Schirm',
      );
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('„Suchen" aus dieser Kamera trägt Mahlzeit und Tag weiter', () {
    testWidgets('das Blatt aus der Suche kommt mit Mahlzeit und Tag', (
      tester,
    ) async {
      final h = behaelter();
      await starte(tester, h);
      await zumAbendVonGestern(tester);
      await hinzufuegen(tester);

      await tippe(tester, find.byKey(const Key('kamera-suchen')));

      expect(find.byType(SucheView), findsOneWidget);
      expect(find.byKey(const Key('kamera')), findsNothing);
      expect(h.router.tab, Tab.ernaehrung);

      await waehle(tester, eigenName);

      final formular = blatt(tester).formular;
      expect(formular.mahlzeit, Mahlzeit.abend);
      expect(formular.tagesSchluessel, gestern);
      expect(
        formular.minutenSeitMitternacht,
        uhrzeitDesTrackens,
        reason: 'die Uhrzeit des Trackens (#328), auch über die Suche',
      );

      await buche(tester);

      final gebucht = await eintraegeAm(h.db, gestern);
      expect(gebucht, hasLength(1));
      expect(gebucht.single.mahlzeit, Mahlzeit.abend);
      expect(await eintraegeAm(h.db, heute), isEmpty);
      expect(
        find.byType(SucheView),
        findsOneWidget,
        reason: 'nach dem Buchen bleibt die Suche offen (V26)',
      );
      await tippe(tester, find.byKey(const Key('erfassen-fertig')));
      expect(find.byType(SucheView), findsNothing);
      expect(sichtbar(find.byType(MahlzeitView)), isTrue);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Der Weg über den (+) bleibt, wie er war', () {
    testWidgets('ein Scan wählt die Mahlzeit aus der Uhrzeit', (tester) async {
      final h = behaelter();
      await starte(tester, h);
      await zumErnaehrungsTab(tester);
      await tippe(tester, find.byKey(const Key('ernaehrung-zurueck')));

      await tippe(tester, find.byKey(const Key('erfassen-knopf')));
      expect(find.byKey(const Key('kamera')), findsOneWidget);
      await scanne(tester, h.leser, codeEigen);

      final formular = blatt(tester).formular;
      expect(
        formular.mahlzeit,
        Mahlzeit.mittag,
        reason: 'ohne vorgewählte Mahlzeit ergibt sie sich aus 12:00',
      );
      expect(formular.tagesSchluessel, gestern);
      expect(formular.minutenSeitMitternacht, uhrzeitDesTrackens);
    });

    testWidgets('„Suchen" wählt die Mahlzeit aus der Uhrzeit', (tester) async {
      final h = behaelter();
      await starte(tester, h);
      await zumErnaehrungsTab(tester);
      await tippe(tester, find.byKey(const Key('ernaehrung-zurueck')));

      await tippe(tester, find.byKey(const Key('erfassen-knopf')));
      await tippe(tester, find.byKey(const Key('kamera-suchen')));
      expect(find.byType(SucheView), findsOneWidget);
      await waehle(tester, eigenName);

      final formular = blatt(tester).formular;
      expect(formular.mahlzeit, Mahlzeit.mittag);
      expect(formular.tagesSchluessel, gestern);
      expect(formular.minutenSeitMitternacht, uhrzeitDesTrackens);
    });
  });
}

/// Eine Quelle, die nichts liefert — kein Fall hier hängt an Apple Health.
class _StilleQuelle extends HealthReadingAttrappe {}
