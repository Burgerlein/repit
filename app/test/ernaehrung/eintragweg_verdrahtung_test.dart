import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/data/ernaehrung_repository.dart';
import 'package:repit/design/symbole.dart';
import 'package:repit/ernaehrung/anlegen_blatt.dart';
import 'package:repit/ernaehrung/buchungs_blatt.dart';
import 'package:repit/ernaehrung/erfassen_provider.dart';
import 'package:repit/ernaehrung/ernaehrung_view.dart';
import 'package:repit/ernaehrung/mahlzeit_view.dart';
import 'package:repit/ernaehrung/strichcode_leser.dart';
import 'package:repit/ernaehrung/suche_view.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/shell/heute_view.dart';
import 'package:repit/shell/root_view.dart';
import 'package:repit/shell/router.dart';

import '../design/support.dart' show textOf;
import 'kamera_attrappe.dart';
import '../health/health_reading_attrappe.dart';
import '../tag/behaelter_im_baum.dart';

/// Die **Verdrahtung** des Eintragwegs (#285, #300) — ob ein Knopf in der
/// App tatsächlich dorthin führt, wo Suche, Anlegen-Blatt und
/// Buchungsblatt schon gebaut liegen.
///
/// Die Oberflächen selbst prüft `erfassen_view_test.dart`, den Schreibweg
/// `erfassen_rundweg_test.dart`, den Mahlzeiten-Schirm
/// `mahlzeit/mahlzeit_view_test.dart`. Diese Datei prüft nur die Türen
/// dazwischen — und zwar an der **ganzen** App (`RootView`), nicht an
/// einem einzeln gepumpten Schirm: Eine Tür, die im Einzeltest aufgeht
/// und in der App an einem fehlenden `router` hängt, ist genau der Fehler,
/// um den es hier geht.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung**
/// (`CLAUDE.md`). Für Widget-Tests genügt ein Agent, solange der Test
/// zuerst entsteht, einmal rot gesehen und committet wird, bevor die
/// Implementierung anfängt. Danach darf diese Datei ausgeführt, aber
/// nicht verändert werden.
///
/// ## Was hier verbindlich ist
///
/// - **Der (+)** öffnet laut Entwurf (`erfassen.js`) die Kamera. Die gibt
///   es noch nicht (Barcode ist #284) — bis dahin öffnet ein Tipp auf den
///   (+) **die Suche**, und der Bogeneintrag „Suchen" ist verfügbar.
/// - **Die vier Wege** auf dem Tag-Schirm: „Suchen" führt in die Suche;
///   Barcode, Foto und Favoriten sagen weiter, dass sie später kommen.
/// - **„Zu dieser Mahlzeit hinzufügen"** führt in die Suche, und das
///   Buchungsblatt kommt mit **dieser** Mahlzeit vorgewählt und dem Tag
///   des Mahlzeiten-Schirms. *(Seit #344 über die Kamera — Nachtrag unten.)*
/// - **Eine eigene Zeile** auf dem Mahlzeiten-Schirm öffnet das echte
///   `BuchungsBlatt`, vorbelegt aus **ihrem** Eintrag.
/// - **Gebucht wird auf den offenen Tag**, nicht auf heute.
/// - **Detailschirme liegen auf dem Stapel des Tabs, aus dem man kam**
///   (`CLAUDE.md`), und „zurück" führt dorthin.
///
/// ## Was hier nicht geprüft wird
///
/// Layout und Beschriftung (`CLAUDE.md`). Die eine Ausnahme ist der Name
/// eines Wegs („Suchen", „Barcode") — er ist die Kennung der Kachel, wie
/// ein Tab-Name, kein Fließtext; dieselbe Begründung wie in
/// `shell/root_view_test.dart`. Und der Name eines Lebensmittels, das der
/// Test selbst anlegt: Das ist Inhalt, keine Beschriftung.
///
/// **Die Navigationsleiste der Suche** ist hier nicht festgelegt — nur,
/// dass es ein Zurück gibt.
///
/// Zahlen und Namen in dieser Datei sind erfunden.
///
/// ## Nachtrag (#324, 04.11.2026): Der (+) öffnet die Kamera
///
/// Der Übergang aus dem ersten Punkt oben ist vorbei: Seit Barcode scannen
/// (#324) öffnet der (+) **die Kamera**, und dort führt „Suchen" oben
/// rechts in die Suche. Die Kachel „Barcode" ist freigeschaltet und öffnet
/// ebenfalls die Kamera — **entschieden vom Koordinator am 04.11.2026,
/// nicht von Tim**. Ebenso von ihm: Nach dem Buchen geht es zurück, woher
/// man kam, und die Kamera ist zu.
///
/// - 'öffnet die Suche — auf dem Stapel des Tabs, in dem man ist' heißt
///   jetzt 'öffnet die Kamera — …' und prüft `Key('kamera')`. Gegenstand
///   bleibt der Stapel: kein Tab-Wechsel.
/// - '„zurück" führt in den Tab, aus dem man kam' geht über „Abbrechen"
///   der Kamera (`Key('kamera-abbrechen')`) statt über das Zurück der
///   Suche — die Kamera hat keine Navigationsleiste mit Zurück.
/// - 'führt über die Suche ins Anlegen-Blatt …' geht über die Kamera und
///   ihr „Suchen" (`Key('kamera-suchen')`). Nach dem Buchen steht neu fest,
///   dass auch die Kamera zu ist.
/// - 'beginnt jedes Mal leer' öffnet die Suche über die Kachel „Suchen" —
///   der Gegenstand ist das Suchfeld, nicht der (+).
/// - '„Barcode" sagt weiter, dass es später kommt' fällt aus der Schleife;
///   neu ist '„Barcode" öffnet die Kamera, im Ernährungs-Tab'. Foto und
///   Favoriten sagen weiter, dass sie später kommen.
/// - **Die Hülle setzt `TestLeser` über `strichcodeLeserProvider` ein**
///   (`kamera_attrappe.dart`) — sonst baute der Vorgabewert ein echtes
///   `MobileScanner`, und jeder Fall nach dem (+) scheiterte am fehlenden
///   Plugin.
///
/// Was die Kamera selbst tut, prüft `barcode_kamera_test.dart`.
///
/// **Geändert vom Test-Agenten von #324, nicht vom Implementierenden. Tim
/// hat diese Änderung nicht gesehen und nicht freigegeben.**
///
/// ## Nachtrag (#344, 04.11.2026): „Hinzufügen" öffnet die Kamera
///
/// **Tims Entscheidung vom 04.11.2026:** „Zu dieser Mahlzeit hinzufügen"
/// öffnet nicht mehr direkt die Suche, sondern denselben Einstieg wie der
/// (+) — die Kamera —, mit Mahlzeit und Tag des Schirms vorgewählt. Die
/// Suche erreicht man von dort über „Suchen" oben rechts
/// (`Key('kamera-suchen')`). Was die Kamera auf diesem Weg selbst tut
/// (Scan bucht in diese Mahlzeit, „Suchen" trägt Mahlzeit und Tag weiter),
/// prüft `mahlzeit_kamera_test.dart`.
///
/// Die drei Fälle, die den alten Weg (Knopf › Suche) festschrieben, gehen
/// jetzt Knopf › Kamera › „Suchen" und behalten ihre Aussage:
///
/// - 'auch über den Mahlzeiten-Schirm eines vergangenen Tages' — gebucht
///   wird weiter auf den offenen Tag, in diese Mahlzeit.
/// - '„Hinzufügen" bucht in genau diese Mahlzeit' — prüft zusätzlich, dass
///   der Knopf die Kamera öffnet und nicht die Suche, und dass nach dem
///   Buchen auch die Kamera zu ist (wie beim (+), #324).
/// - '„zurück" führt über die Suche bis auf den Tag-Schirm' heißt jetzt
///   '„zurück" führt über Kamera und Suche bis auf den Tag-Schirm': Aus der
///   Kamera führt „Abbrechen" auf den Mahlzeiten-Schirm, aus der über sie
///   geöffneten Suche das Zurück ebenso, von dort das Zurück auf den
///   Tag-Schirm. Dass die Suche die Kamera **ersetzt** statt über ihr zu
///   liegen, folgt aus der Festlegung von #324 (nach dem Buchen ist die
///   Kamera zu), nicht aus einer eigenen Entscheidung zu #344.
///
/// **Geändert vom Test-Agenten von #344, nicht vom Implementierenden. Die
/// Entscheidung für den neuen Weg ist Tims; die Umstellung dieser drei
/// Fälle hat er nicht eigens gesehen.**
///
/// **Nachtrag #345** (Tims Entscheidung vom 04.11.2026): Ohne Suchtext
/// stehen unter „Zuletzt benutzt" nur gebuchte Lebensmittel. Ein gerade
/// angelegtes steht dort also nicht; [waehle] sucht deshalb zuerst
/// danach. Vom Test-Agenten von #345 geändert, Tim hat die Änderung nicht
/// gesehen.
///
/// **Nachtrag #434** (10.11.2026): Tim hat die neue Mahlzeitenliste
/// freigegeben (Spec `2026-11-10-mahlzeiten-aufteilung-design.md`, V10).
/// Die Zeile nennt keine Lebensmittel mehr, sondern kcal. 'führt über die
/// Suche ins Anlegen-Blatt …' prüft deshalb „558 kcal" in der Mittagszeile
/// und keine 558 in den anderen, dann öffnet es die Mahlzeit und findet
/// dort „Testhafer". Die Aussage bleibt: Der Eintrag steht nach dem Buchen
/// ohne Neustart in der richtigen Mahlzeit. Vom Test-Agenten von #434
/// umgestellt, Tim hat die Umstellung nicht gesehen.
///
/// **Nachtrag #439** (10.11.2026): Tim hat die Kachelreihe freigegeben
/// (Spec `2026-11-10-mahlzeiten-aufteilung-design.md`, Entscheidung 9 und
/// V22). Die Suche hat seitdem keine Navigationsleiste mit Zurück mehr,
/// sondern den Kopf mit Zähler, Mahlzeit und „Abbrechen"
/// (`Key('erfassen-abbrechen')`). Die drei Fälle, die die Suche über das
/// Zurück verließen ('„Suchen" führt in die Suche, im Ernährungs-Tab',
/// '„Barcode" öffnet die Kamera, im Ernährungs-Tab' und 'beginnt jedes Mal
/// leer'), verlassen sie über [abbrechen] und behalten ihre Aussage. Das
/// Zurück des Mahlzeiten-Schirms bleibt. „Suchen" in der Kamera ist keine
/// Schaltfläche oben rechts mehr, sondern eine Kachel unten — derselbe
/// Schlüssel `kamera-suchen`. Vom Test-Agenten von #439 umgestellt, Tim
/// hat die Umstellung nicht gesehen.
///
/// **Nachtrag #440** (10.11.2026): Tim hat V26 bestätigt (Spec
/// `2026-11-10-mahlzeiten-aufteilung-design.md`): Nach einer Buchung über
/// das Blatt **bleibt die Suche offen** — Zähler, Haken, Band. Bisher
/// schloss sie sich, und das war eine Vorgabe des Koordinators, nicht
/// Tims. Die beiden Fälle, die das Schließen nach dem Buchen
/// festschrieben ('führt über die Suche ins Anlegen-Blatt …' und
/// '„Hinzufügen" bucht in genau diese Mahlzeit'), prüfen jetzt, dass die
/// Suche nach dem Buchen noch dasteht, schließen sie über „Fertig"
/// (`Key('erfassen-fertig')`, V29) und behalten danach ihre Aussage: Die
/// Kamera ist zu, man steht, woher man kam, und der Eintrag steht dort.
/// Vom Test-Agenten von #440 umgestellt, Tim hat die Umstellung nicht
/// gesehen.
void main() {
  // Dienstag, 14.07.2026, 12:00 Berliner Zeit (MESZ, +2). Mittag — so
  // weicht jede ausdrücklich vorgewählte Mahlzeit von der ab, die die
  // Uhrzeit ergäbe.
  final jetzt = DateTime.utc(2026, 7, 14, 10);
  const heute = '2026-07-14';
  const gestern = '2026-07-13';

  // ───────────────────────────────────────────────────────────────────────
  // Testhülle
  // ───────────────────────────────────────────────────────────────────────

  /// Die ganze App auf einer Datenbank im Speicher.
  ///
  /// **Kein Override der Ernährungs-Provider.** Gebucht wird über den
  /// echten Schreibweg in die echte Tabelle, und der Tag-Schirm liest sie
  /// über den echten Lesweg — nur so zeigt sich, ob ein gebuchter Eintrag
  /// ohne Neustart dasteht.
  ({ProviderContainer container, AppCache db, AppRouter router}) behaelter() {
    final db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);

    // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        appCacheProvider.overrideWithValue(db),
        healthProvider.overrideWithValue(_StilleQuelle()),
        clockProvider.overrideWithValue(() => jetzt),
        // #324: Der (+) öffnet die Kamera (Nachtrag im Dateikopf).
        strichcodeLeserProvider.overrideWithValue(TestLeser()),
      ],
    );
    addTearDown(container.dispose);
    return (container: container, db: db, router: AppRouter());
  }

  Future<void> starte(
    WidgetTester tester,
    ({ProviderContainer container, AppCache db, AppRouter router}) h,
  ) async {
    // Groß genug, dass der ganze Tag-Schirm samt der vier Wege gebaut ist
    // und kein Fall selbst scrollen muss.
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

  Future<void> tippePlus(WidgetTester tester) =>
      tippe(tester, find.byKey(const Key('erfassen-knopf')));

  /// Ein Weg unten auf dem Tag-Schirm, über seinen Namen.
  Finder weg(String name) => find.descendant(
    of: find.byKey(const Key('ernaehrung-wege')),
    matching: find.text(name),
  );

  /// Das sichtbare Zurück des obersten Schirms.
  Future<void> zurueck(WidgetTester tester) => tippe(
    tester,
    find.byType(CupertinoNavigationBarBackButton).hitTestable(),
  );

  /// „Abbrechen" im Kopf der Suche — die Suche hat seit #439 kein Zurück
  /// mehr.
  Future<void> abbrechen(WidgetTester tester) =>
      tippe(tester, find.byKey(const Key('erfassen-abbrechen')));

  /// „Fertig" unten in der Suche (#440, V29) — schließt sie nach dem
  /// Buchen; seit V26 bleibt sie danach offen.
  Future<void> fertig(WidgetTester tester) =>
      tippe(tester, find.byKey(const Key('erfassen-fertig')));

  /// Legt über das Blatt „Lebensmittel anlegen" ein Lebensmittel an —
  /// von der Suche aus, so wie Tim es tut.
  Future<void> legeAn(
    WidgetTester tester,
    String name, {
    String kcal = '372',
  }) async {
    await tippe(tester, find.byKey(const Key('erfassen-anlegen')));
    expect(
      find.byType(AnlegenBlatt),
      findsOneWidget,
      reason: 'aus der Suche führt „Lebensmittel anlegen" ins Blatt',
    );
    await tester.enterText(find.byKey(const Key('anlegen-name')), name);
    await tester.enterText(find.byKey(const Key('anlegen-kcal')), kcal);
    await tester.pump();
    await tippe(tester, find.byKey(const Key('anlegen-sichern')));
    expect(find.byType(AnlegenBlatt), findsNothing);
  }

  /// Tippt einen Treffer in der Suche an — öffnet das Buchungsblatt.
  ///
  /// Sucht vorher nach dem Anfangsbuchstaben: Seit #345 steht ein bloß
  /// angelegtes Lebensmittel ohne Suchtext nicht da. **Ein** Buchstabe,
  /// weil die Online-Suche erst ab zwei beginnt — sie ist hier nicht
  /// Gegenstand, und diese Hülle setzt keinen Netz-Ersatz ein.
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
    expect(
      find.byType(BuchungsBlatt),
      findsOneWidget,
      reason: 'ein Treffer führt ins Buchungsblatt',
    );
  }

  BuchungsBlatt blatt(WidgetTester tester) =>
      tester.widget<BuchungsBlatt>(find.byType(BuchungsBlatt));

  Future<void> buche(WidgetTester tester, {String? menge}) async {
    if (menge != null) {
      await tester.enterText(find.byKey(const Key('buchung-menge')), menge);
      await tester.pump();
    }
    await tippe(tester, find.byKey(const Key('buchung-sichern')));
    expect(
      find.byType(BuchungsBlatt),
      findsNothing,
      reason: 'nach dem Buchen schließt das Blatt',
    );
  }

  Future<List<Eintrag>> eintraegeAm(AppCache db, String tag) =>
      ErnaehrungRepository(db).eintraegeAmTag(tag);

  String textUnter(WidgetTester tester, Finder wo) => tester
      .widgetList<Text>(find.descendant(of: wo, matching: find.byType(Text)))
      .map(textOf)
      .join(' ');

  bool sichtbar(Finder f) => f.hitTestable().evaluate().isNotEmpty;

  // ═════════════════════════════════════════════════════════════════════
  group('Der (+) in der Leiste', () {
    testWidgets('öffnet die Kamera — auf dem Stapel des Tabs, in dem man ist', (
      tester,
    ) async {
      final h = behaelter();
      await starte(tester, h);
      expect(h.router.tab, Tab.heute);

      await tippePlus(tester);

      expect(
        find.byType(CupertinoAlertDialog),
        findsNothing,
        reason: 'der (+) sagt nicht mehr „kommt später"',
      );
      expect(find.byKey(const Key('kamera')), findsOneWidget);
      expect(
        h.router.tab,
        Tab.heute,
        reason:
            'ein Detailschirm wechselt nie den Tab (CLAUDE.md) — sonst führte '
            '„zurück" in ein Menü, das Tim nie geöffnet hat',
      );
    });

    testWidgets('„zurück" führt in den Tab, aus dem man kam', (tester) async {
      final h = behaelter();
      await starte(tester, h);

      await tippePlus(tester);
      expect(find.byKey(const Key('kamera')), findsOneWidget);

      await tippe(tester, find.byKey(const Key('kamera-abbrechen')));

      expect(find.byKey(const Key('kamera')), findsNothing);
      expect(h.router.tab, Tab.heute);
      expect(sichtbar(find.byType(HeuteView)), isTrue);
    });

    testWidgets('der Bogeneintrag „Suchen" ist verfügbar und führt dorthin', (
      tester,
    ) async {
      final h = behaelter();
      await starte(tester, h);

      await tester.longPress(find.byKey(const Key('erfassen-knopf')));
      await tester.pumpAndSettle();
      await tippe(tester, find.text('Suchen'));

      expect(find.byType(SucheView), findsOneWidget);
      expect(find.byType(CupertinoAlertDialog), findsNothing);
    });

    testWidgets(
      'führt über die Suche ins Anlegen-Blatt und ins Buchungsblatt — und '
      'der gebuchte Eintrag steht danach auf dem Tag-Schirm',
      (tester) async {
        final h = behaelter();
        await starte(tester, h);
        await zumErnaehrungsTab(tester);

        await tippePlus(tester);
        await tippe(tester, find.byKey(const Key('kamera-suchen')));
        expect(find.byType(SucheView), findsOneWidget);

        await legeAn(tester, 'Testhafer');
        await waehle(tester, 'Testhafer');
        expect(blatt(tester).formular.tagesSchluessel, heute);

        await buche(tester, menge: '150');

        expect(
          find.byType(SucheView),
          findsOneWidget,
          reason: 'nach dem Buchen bleibt die Suche offen (V26)',
        );
        await fertig(tester);
        expect(
          find.byType(SucheView),
          findsNothing,
          reason: '„Fertig" führt zurück, woher man kam (V29)',
        );
        expect(
          find.byKey(const Key('kamera')),
          findsNothing,
          reason: 'nach dem Buchen ist auch die Kamera zu (#324)',
        );
        expect(sichtbar(find.byType(ErnaehrungView)), isTrue);
        expect(h.router.tab, Tab.ernaehrung);

        // 12:00 Berliner Zeit — die Mahlzeit, die die Uhrzeit ergibt.
        // 150 g zu 372 kcal je 100 g sind 558 kcal; ein Kalorienziel
        // gibt es hier nicht, also steht die Summe ohne „/ Ziel" (#434,
        // V10 — die Zeile nennt keine Lebensmittel mehr).
        expect(
          textUnter(
            tester,
            find.byKey(const Key('ernaehrung-mahlzeit-mittag')),
          ),
          contains('558 kcal'),
          reason:
              'ohne Neustart: Der Tag-Schirm liest nach dem Buchen nach '
              '(`ErfassenNotifier._zeigeTagNeu`)',
        );
        for (final andere in const ['fruehstueck', 'abend', 'snack']) {
          expect(
            textUnter(tester, find.byKey(Key('ernaehrung-mahlzeit-$andere'))),
            isNot(contains('558')),
            reason: 'gebucht in die Mahlzeit der Uhrzeit, nicht in $andere',
          );
        }

        // Und in der Mahlzeit steht er mit Namen.
        await tippe(
          tester,
          find.byKey(const Key('ernaehrung-mahlzeit-mittag')),
        );
        final schirm = tester.widget<MahlzeitView>(find.byType(MahlzeitView));
        expect(schirm.mahlzeit, Mahlzeit.mittag);
        expect(schirm.tagesSchluessel, heute);
        expect(
          find.descendant(
            of: find.byType(MahlzeitView),
            matching: find.text('Testhafer'),
          ),
          findsWidgets,
        );

        final gebucht = await eintraegeAm(h.db, heute);
        expect(gebucht, hasLength(1));
        expect(gebucht.single.name, 'Testhafer');
        expect(gebucht.single.mengeG, 150);
      },
    );
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Die vier Wege auf dem Tag-Schirm', () {
    testWidgets('„Suchen" führt in die Suche, im Ernährungs-Tab', (
      tester,
    ) async {
      final h = behaelter();
      await starte(tester, h);
      await zumErnaehrungsTab(tester);

      await tippe(tester, weg('Suchen'));

      expect(find.byType(CupertinoAlertDialog), findsNothing);
      expect(find.byType(SucheView), findsOneWidget);
      expect(h.router.tab, Tab.ernaehrung);

      await abbrechen(tester);
      expect(find.byType(SucheView), findsNothing);
      expect(sichtbar(find.byType(ErnaehrungView)), isTrue);
    });

    testWidgets('„Barcode" öffnet die Kamera, im Ernährungs-Tab', (
      tester,
    ) async {
      final h = behaelter();
      await starte(tester, h);
      await zumErnaehrungsTab(tester);

      await tippe(tester, weg('Barcode'));

      expect(find.byType(CupertinoAlertDialog), findsNothing);
      expect(find.byKey(const Key('kamera')), findsOneWidget);
      expect(h.router.tab, Tab.ernaehrung);

      await tippe(tester, find.byKey(const Key('kamera-abbrechen')));
      expect(find.byKey(const Key('kamera')), findsNothing);
      expect(sichtbar(find.byType(ErnaehrungView)), isTrue);
    });

    for (final name in const ['Foto', 'Favoriten']) {
      testWidgets('„$name" sagt weiter, dass es später kommt', (tester) async {
        final h = behaelter();
        await starte(tester, h);
        await zumErnaehrungsTab(tester);

        await tippe(tester, weg(name));

        expect(
          find.byType(CupertinoAlertDialog),
          findsOneWidget,
          reason:
              'ein Weg, den es noch nicht gibt, sagt das — stumm wäre er '
              'eine Tür, die keine ist',
        );
        expect(find.byType(SucheView), findsNothing);
      });
    }
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Gebucht wird auf den offenen Tag', () {
    testWidgets('wer über ‹ gestern offen hat, bucht auf gestern', (
      tester,
    ) async {
      final h = behaelter();
      await starte(tester, h);
      await zumErnaehrungsTab(tester);

      await tippe(tester, find.byKey(const Key('ernaehrung-zurueck')));
      await tippe(tester, weg('Suchen'));
      await legeAn(tester, 'Testbrot');
      await waehle(tester, 'Testbrot');

      expect(
        blatt(tester).formular.tagesSchluessel,
        gestern,
        reason: 'das Blatt kennt den offenen Tag, nicht „heute"',
      );

      await buche(tester);

      expect(await eintraegeAm(h.db, gestern), hasLength(1));
      expect(
        await eintraegeAm(h.db, heute),
        isEmpty,
        reason:
            'ein Eintrag, der still auf dem falschen Tag landet, fällt erst '
            'nach Wochen auf (`erfassen.js`)',
      );
    });

    testWidgets('auch über den Mahlzeiten-Schirm eines vergangenen Tages', (
      tester,
    ) async {
      final h = behaelter();
      await starte(tester, h);
      await zumErnaehrungsTab(tester);

      await tippe(tester, find.byKey(const Key('ernaehrung-zurueck')));
      await tippe(tester, find.byKey(const Key('ernaehrung-mahlzeit-snack')));
      await tippe(tester, find.byKey(const Key('mahlzeit-hinzufuegen')));
      // #344: erst die Kamera, von dort „Suchen".
      expect(find.byKey(const Key('kamera')), findsOneWidget);
      await tippe(tester, find.byKey(const Key('kamera-suchen')));
      await legeAn(tester, 'Testriegel');
      await waehle(tester, 'Testriegel');

      expect(blatt(tester).formular.tagesSchluessel, gestern);
      expect(blatt(tester).formular.mahlzeit, Mahlzeit.snack);

      await buche(tester);

      final gebucht = await eintraegeAm(h.db, gestern);
      expect(gebucht, hasLength(1));
      expect(gebucht.single.mahlzeit, Mahlzeit.snack);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Der Mahlzeiten-Schirm', () {
    testWidgets('ein Tipp auf eine Mahlzeit führt auf ihren Schirm', (
      tester,
    ) async {
      final h = behaelter();
      await starte(tester, h);
      await zumErnaehrungsTab(tester);

      await tippe(tester, find.byKey(const Key('ernaehrung-mahlzeit-abend')));

      final schirm = tester.widget<MahlzeitView>(find.byType(MahlzeitView));
      expect(schirm.mahlzeit, Mahlzeit.abend);
      expect(schirm.tagesSchluessel, heute);
      expect(h.router.tab, Tab.ernaehrung);
    });

    testWidgets('„Hinzufügen" bucht in genau diese Mahlzeit', (tester) async {
      final h = behaelter();
      await starte(tester, h);
      await zumErnaehrungsTab(tester);

      await tippe(tester, find.byKey(const Key('ernaehrung-mahlzeit-abend')));
      await tippe(tester, find.byKey(const Key('mahlzeit-hinzufuegen')));

      expect(
        find.byType(CupertinoAlertDialog),
        findsNothing,
        reason: '„Hinzufügen" sagt nicht mehr „kommt später"',
      );
      expect(
        find.byKey(const Key('kamera')),
        findsOneWidget,
        reason: 'derselbe Einstieg wie der (+) (#344)',
      );
      expect(find.byType(SucheView), findsNothing);

      await tippe(tester, find.byKey(const Key('kamera-suchen')));
      expect(find.byType(SucheView), findsOneWidget);

      await legeAn(tester, 'Testsuppe');
      await waehle(tester, 'Testsuppe');

      expect(
        blatt(tester).formular.mahlzeit,
        Mahlzeit.abend,
        reason:
            'vorgewählt ist die Mahlzeit, von der man kam — nicht die, die '
            'die Uhrzeit ergäbe (12:00 wäre Mittag)',
      );
      expect(blatt(tester).formular.tagesSchluessel, heute);

      await buche(tester);

      expect(
        find.byType(SucheView),
        findsOneWidget,
        reason: 'nach dem Buchen bleibt die Suche offen (V26)',
      );
      await fertig(tester);
      expect(find.byType(SucheView), findsNothing);
      expect(
        find.byKey(const Key('kamera')),
        findsNothing,
        reason: 'nach dem Buchen ist auch die Kamera zu (#324)',
      );
      expect(
        sichtbar(find.byType(MahlzeitView)),
        isTrue,
        reason: 'zurück auf den Mahlzeiten-Schirm, von dem aus gebucht wurde',
      );

      final gebucht = await eintraegeAm(h.db, heute);
      expect(gebucht, hasLength(1));
      expect(gebucht.single.mahlzeit, Mahlzeit.abend);
      expect(
        find.byKey(Key('mahlzeit-eintrag-${gebucht.single.id}')),
        findsOneWidget,
        reason: 'der neue Eintrag steht sofort auf dem Mahlzeiten-Schirm',
      );
    });

    testWidgets('„zurück" führt über Kamera und Suche bis auf den Tag-Schirm', (
      tester,
    ) async {
      final h = behaelter();
      await starte(tester, h);
      await zumErnaehrungsTab(tester);

      await tippe(tester, find.byKey(const Key('ernaehrung-mahlzeit-abend')));

      // Aus der Kamera: „Abbrechen" führt auf den Mahlzeiten-Schirm.
      await tippe(tester, find.byKey(const Key('mahlzeit-hinzufuegen')));
      expect(find.byKey(const Key('kamera')), findsOneWidget);
      await tippe(tester, find.byKey(const Key('kamera-abbrechen')));
      expect(find.byKey(const Key('kamera')), findsNothing);
      expect(sichtbar(find.byType(MahlzeitView)), isTrue);
      expect(h.router.tab, Tab.ernaehrung);

      // Aus der Suche, über die Kamera geöffnet: „Abbrechen" führt ebenfalls
      // auf den Mahlzeiten-Schirm.
      await tippe(tester, find.byKey(const Key('mahlzeit-hinzufuegen')));
      await tippe(tester, find.byKey(const Key('kamera-suchen')));
      expect(find.byType(SucheView), findsOneWidget);

      await abbrechen(tester);
      expect(find.byType(SucheView), findsNothing);
      expect(sichtbar(find.byType(MahlzeitView)), isTrue);

      await zurueck(tester);
      expect(find.byType(MahlzeitView), findsNothing);
      expect(sichtbar(find.byType(ErnaehrungView)), isTrue);
      expect(h.router.tab, Tab.ernaehrung);
    });

    testWidgets(
      'ein eigener Eintrag öffnet das Buchungsblatt mit seinen Werten — '
      'ändern und sichern ändert die Summe',
      (tester) async {
        final h = behaelter();
        final repo = ErnaehrungRepository(h.db);
        await repo.buche(
          Eintrag(
            tagesSchluessel: heute,
            mahlzeit: Mahlzeit.fruehstueck,
            zeitpunkt: DateTime.utc(2026, 7, 14, 6),
            name: 'Testmüsli',
            mengeG: 200,
            // 200 kcal je 100 g.
            naehrwerte: const Naehrwerte(
              kcal: 400,
              eiweissG: 20,
              kohlenhydrateG: 60,
              fettG: 10,
            ),
          ),
        );
        // `buche` gibt den Schlüssel nicht zurück — er steht danach an der
        // gelesenen Zeile.
        final id = (await repo.eintraegeAmTag(heute)).single.id;

        await starte(tester, h);
        await zumErnaehrungsTab(tester);
        await tippe(
          tester,
          find.byKey(const Key('ernaehrung-mahlzeit-fruehstueck')),
        );
        await tippe(tester, find.byKey(Key('mahlzeit-eintrag-$id')));

        expect(
          find.byType(CupertinoAlertDialog),
          findsNothing,
          reason: 'das echte Blatt, nicht der Platzhalter-Dialog',
        );
        expect(find.byType(BuchungsBlatt), findsOneWidget);
        final formular = blatt(tester).formular;
        expect(
          formular.bearbeitetId,
          id,
          reason: 'das Blatt ändert **diesen** Eintrag, es bucht keinen neuen',
        );
        expect(formular.mengeG, 200);
        expect(formular.mahlzeit, Mahlzeit.fruehstueck);
        expect(formular.tagesSchluessel, heute);

        await buche(tester, menge: '100');

        final nachher = await eintraegeAm(h.db, heute);
        expect(nachher, hasLength(1), reason: 'ersetzt, nicht dazugebucht');
        expect(nachher.single.id, id);
        expect(nachher.single.naehrwerte.kcal, 200);

        final kcal = textUnter(
          tester,
          // Seit #442 (V17) steht die Summe im Raster, die Kalorienzeile
          // gibt es nicht mehr. Nachgezogen vom Test-Agenten.
          find.byKey(const Key('mahlzeit-raster-kcal')),
        );
        expect(kcal, contains('200'));
        expect(
          kcal,
          isNot(contains('400')),
          reason: 'die Summe auf dem Schirm folgt der Änderung ohne Neustart',
        );
      },
    );
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Die Suche', () {
    testWidgets('beginnt jedes Mal leer', (tester) async {
      final h = behaelter();
      await starte(tester, h);
      await zumErnaehrungsTab(tester);

      // Seit #324 öffnet der (+) die Kamera; der Gegenstand hier ist das
      // Suchfeld, deshalb der kürzere Weg über die Kachel.
      await tippe(tester, weg('Suchen'));
      await tester.enterText(
        find.byKey(const Key('erfassen-suchfeld')),
        'Hafer',
      );
      await tester.pumpAndSettle();
      expect(h.container.read(suchtextProvider), 'Hafer');

      await abbrechen(tester);

      expect(
        h.container.read(suchtextProvider),
        isEmpty,
        reason:
            'das Suchfeld steht beim nächsten Öffnen leer da; ein stehen '
            'gebliebener Suchtext filterte unsichtbar weiter',
      );
    });
  });
}

/// Eine Quelle, die nichts liefert — der Tag-Schirm baut darauf ohne
/// Ausnahme, und kein Fall hier hängt an Apple-Health-Werten.
class _StilleQuelle extends HealthReadingAttrappe {}
