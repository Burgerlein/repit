import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/data/ereignisse.dart';
import 'package:repit/design/icon_row.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/shell/mehr_view.dart';
import 'package:repit/shell/router.dart';
import 'package:repit/ziele/ziele_view.dart';

import '../design/support.dart' show textOf;
import '../health/health_reading_attrappe.dart';
import '../tag/behaelter_im_baum.dart';

/// Widget-Tests für den **ersten Schnitt des Ziele-Schirms** (#448 unter
/// #404): `ZieleView`, das Blatt „Auszeit eintragen“/„Auszeit ändern“ und
/// die Mehr-Zeile „Ziele“.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Für Widget-Tests genügt ein Agent, wenn der Test zuerst entsteht, rot
/// gesehen und **vor der Implementierung committet** wird — ab da bewacht
/// ihn `.githooks/pre-commit`. Diese Datei darf ausgeführt, aber nicht
/// verändert werden. Hält der Implementierende einen Fall für falsch,
/// meldet er ihn.
///
/// ## Woher die Anforderung kommt
///
/// Spec `docs/superpowers/specs/2026-11-10-auszeit-design.md`, Abschnitte
/// „Die Schirme“ und „Tests und Rollen“, dazu V4, V5, V6, V7, V8, V11, V18
/// und V19. Die Vorgaben V1–V20 hat der Planende formuliert; Tim hat sie am
/// 10.11.2026 übernommen („Ja, so bauen“). Fälle und Schlüssel stehen im
/// Plan `docs/superpowers/plans/2026-11-10-auszeit.md`, Task 5, Step 2.
/// Entwurf: `docs/screens/screens/auszeit.js` (`liste`, `leer`, `op`,
/// `urlaub`).
///
/// Die beiden Fälle, auf die es laut `CLAUDE.md` ankommt:
///
/// - **Während des Lesens steht nie „Keine Auszeit eingetragen“** (`01`).
/// - **Eine angelegte Auszeit steht nach Zurück und erneutem Öffnen wieder
///   da** (`32`).
///
/// ## Die Schlüssel (Plan, Task 5)
///
/// `ziele-ereignisse` (der Abschnitt), `ziele-leer` (der leere Zustand),
/// `ziele-freigabe` (der Freigabe-Hinweis unter der Liste), `ziele-plus`
/// (das „+“ in der Navigationsleiste), `auszeit-art-<name>` (je Segment,
/// `<name>` ist `EreignisArt.name`), `auszeit-von`, `auszeit-bis` (die
/// Zeilen, die das Datumsrad aufklappen), `auszeit-notiz` (auf dem
/// Textfeld), `auszeit-sichern`, `auszeit-loeschen`, `auszeit-zeile-<id>`
/// (je Zeile der Liste, `<id>` ist die `id` des Ereignisses).
///
/// ## Festlegungen des Test-Agenten — nicht von Tim freigegeben
///
/// - **Ein zusätzlicher Schlüssel `auszeit-freigabe`** für den
///   Freigabe-Hinweis im Blatt. Der Plan verlangt „Blatt mit … dem
///   Freigabe-Hinweis; Art ‚Urlaub‘ → kein Freigabe-Hinweis“, nennt dafür
///   aber keinen Schlüssel.
/// - **Der Freigabe-Text wird auf seinen vollständigen Wortlaut geprüft**,
///   in der Liste und im Blatt. Das ist eine Beschriftungsprüfung und damit
///   eine bewusste Ausnahme von `CLAUDE.md` („Tests“): Der Plan verlangt den
///   Hinweis „ungekürzt“ (Global Constraints), und ein gekürzter
///   Gesundheitshinweis ist ein Fehler, kein Stilmittel („Keine
///   Diagnosen“). Geprüft wird nur, dass der Satz aus der Spec enthalten
///   ist; Zeilenumbrüche und Leerraum zählen nicht.
/// - **Solange gelesen wird, steht der Abschnitt `ziele-ereignisse` da,
///   aber weder `ziele-leer` noch `ziele-freigabe`.** Spec: „steht der
///   Abschnittskopf da und darunter nichts“.
/// - **Nach „Löschen“ in der Rückfrage ist auch das Blatt zu** — ein offenes
///   Ändern-Blatt für ein gelöschtes Ereignis gäbe es nicht mehr zu sichern.
/// - **Der Esstag kommt über `clockProvider`** (`esstagProvider` rechnet aus
///   ihm). Die Uhr steht auf 2099-10-14, 12:00 Berliner Zeit.
/// - **Der Weg auf den Schirm läuft immer über die Mehr-Zeile „Ziele“** und
///   einen Gastgeber, der den Befehl des `AppRouter` auf einen Navigator
///   schiebt — wie `RootView` es tut. So legt der Test nicht fest, ob das
///   „+“ in `ZieleView` selbst oder in einem Rahmen darum sitzt.
/// - **Das Datumsrad wird nicht gedreht**, sondern sein `onDateTimeChanged`
///   unmittelbar aufgerufen — wie in `vorlaeufige_werte_test.dart`.
///
/// ## Was hier absichtlich nicht geprüft wird
///
/// Layout, Farben, Abstände und der Wortlaut von Titeln, Untertiteln,
/// Wirkungstexten und Knöpfen (außer dem Freigabe-Text, siehe oben, und
/// „Löschen“/„Abbrechen“ in der Rückfrage, die V7 festlegt und ohne die sich
/// die beiden Knöpfe nicht unterscheiden lassen). Die Formularlogik
/// (Vorbelegung, Nachziehen, Notiz) prüft `auszeit_formular_test.dart`
/// ohne Widget; hier steht nur, dass das Blatt sie benutzt.
///
/// **Alle Daten hier sind erfunden und liegen im Jahr 2099** (Plan,
/// „Global Constraints“).
void main() {
  /// 12:00 in Berlin (Sommerzeit, UTC+2) — der Esstag ist der 14.10.2099.
  final jetzt = DateTime.utc(2099, 10, 14, 10);
  const esstag = '2099-10-14';

  /// Der Hinweis aus der Spec („Kein Rat, sondern eine Planungsannahme“),
  /// für Liste und Formular derselbe.
  const freigabeText =
      'Wie lange du dich erholst, ist eine Planungsannahme, keine Freigabe. '
      'Wann du wieder belasten und normal essen darfst, entscheidet deine '
      'Ärztin oder dein Arzt.';

  final abschnitt = find.byKey(const Key('ziele-ereignisse'));
  final leer = find.byKey(const Key('ziele-leer'));
  final listenFreigabe = find.byKey(const Key('ziele-freigabe'));
  final plus = find.byKey(const Key('ziele-plus'));
  final blattFreigabe = find.byKey(const Key('auszeit-freigabe'));
  final von = find.byKey(const Key('auszeit-von'));
  final bis = find.byKey(const Key('auszeit-bis'));
  final notiz = find.byKey(const Key('auszeit-notiz'));
  final sichern = find.byKey(const Key('auszeit-sichern'));
  final loeschen = find.byKey(const Key('auszeit-loeschen'));
  Finder art(EreignisArt a) => find.byKey(Key('auszeit-art-${a.name}'));
  Finder zeile(int id) => find.byKey(Key('auszeit-zeile-$id'));

  late AppCache db;

  setUpAll(() async {
    await initializeDateFormatting('de_DE');
  });

  setUp(() {
    db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);
  });

  ProviderContainer behaelter({EreignisRepository? repo}) {
    final container = ProviderContainer(
      // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
      retry: (_, _) => null,
      overrides: [
        appCacheProvider.overrideWithValue(db),
        // Der Schirm fragt Apple Health nicht; die Attrappe steht hier,
        // damit ein Provider, der später einen Lauf dazubekommt, nicht in
        // `UnimplementedError` läuft.
        healthProvider.overrideWithValue(_LeereQuelle()),
        clockProvider.overrideWithValue(() => jetzt),
        if (repo != null) ereignisRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Legt ein Ereignis unmittelbar in der Tabelle ab und gibt seine `id`
  /// zurück — am Schirm vorbei, wie es eine frühere Sitzung getan hätte.
  Future<int> lege(Ereignis e) =>
      EreignisRepository(db, uhr: () => jetzt).legeAn(e);

  /// Liest unmittelbar aus der Tabelle, nicht über den Provider: Was hier
  /// steht, hat den Schirm überlebt.
  Future<List<Ereignis>> abgelegt() => EreignisRepository(db).alle();

  /// Der Gastgeber: das Mehr-Menü auf einem Navigator, der jeden Befehl des
  /// [AppRouter] schiebt — wie `RootView` es für den Stapel eines Tabs tut.
  Future<GlobalKey<NavigatorState>> zeigeMehr(
    WidgetTester tester,
    ProviderContainer container,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
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
        container: container,
        child: CupertinoApp(
          navigatorKey: navigator,
          home: MehrView(router: router),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return navigator;
  }

  Finder zieleZeile() => find.widgetWithText(IconRow, 'Ziele');

  /// Mehr › Ziele, und warten, bis der Schirm steht.
  Future<GlobalKey<NavigatorState>> zeigeZiele(
    WidgetTester tester, {
    ProviderContainer? container,
  }) async {
    final navigator = await zeigeMehr(tester, container ?? behaelter());
    await tester.tap(zieleZeile());
    await tester.pumpAndSettle();
    return navigator;
  }

  Future<void> tippe(WidgetTester tester, Finder ziel) async {
    expect(ziel, findsOneWidget, reason: 'Siehe „Die Schlüssel“ im Kopf.');
    await tester.ensureVisible(ziel);
    await tester.pumpAndSettle();
    await tester.tap(ziel);
    await tester.pumpAndSettle();
  }

  /// Alle Texte unter [wurzel], zusammengefügt, Leerraum vereinheitlicht.
  String textUnter(WidgetTester tester, Finder wurzel) => tester
      .widgetList<Text>(
        find.descendant(
          of: wurzel,
          matching: find.byType(Text),
          matchRoot: true,
        ),
      )
      .map(textOf)
      .join(' ')
      .replaceAll(RegExp(r'\s+'), ' ');

  String notizText(WidgetTester tester) => tester
      .widget<EditableText>(
        find.descendant(
          of: notiz,
          matching: find.byType(EditableText),
          matchRoot: true,
        ),
      )
      .controller
      .text;

  group('Lesen und Leer (`01`)', () {
    testWidgets('während des Lesens steht nie „Keine Auszeit eingetragen“', (
      tester,
    ) async {
      final antwort = Completer<List<Ereignis>>();
      final container = behaelter(repo: _HaengendesRepo(db, antwort));
      await zeigeMehr(tester, container);

      await tester.tap(zieleZeile());
      // Kein `pumpAndSettle`: Ein Ladezeichen, das sich dreht, käme nie zur
      // Ruhe. Eine Sekunde reicht für den Übergang der Seite.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(
        find.byType(ZieleView),
        findsOneWidget,
        reason: 'Die Mehr-Zeile „Ziele“ öffnet den Schirm (V18).',
      );
      expect(
        abschnitt,
        findsOneWidget,
        reason: 'Der Abschnittskopf steht auch während des Lesens (Spec).',
      );
      expect(
        leer,
        findsNothing,
        reason:
            'Während die Tabelle gelesen wird, ist nichts bekannt — ein '
            '„Keine Auszeit eingetragen“ wäre Fehler 01.',
      );
      expect(listenFreigabe, findsNothing);

      antwort.complete(const []);
      await tester.pumpAndSettle();

      expect(
        leer,
        findsOneWidget,
        reason: 'Erst nach dem Lesen steht der leere Zustand.',
      );
    });

    testWidgets('leere Tabelle → leerer Zustand, kein Freigabe-Hinweis', (
      tester,
    ) async {
      await zeigeZiele(tester);

      expect(abschnitt, findsOneWidget);
      expect(leer, findsOneWidget);
      expect(
        listenFreigabe,
        findsNothing,
        reason: 'Im leeren Zustand steht der Hinweis nicht (V11, Entwurf).',
      );
    });

    testWidgets('eine abgelegte OP steht als Zeile, mit Freigabe-Hinweis', (
      tester,
    ) async {
      final id = await lege(
        const Ereignis(
          art: EreignisArt.op,
          von: '2099-10-10',
          bis: '2099-10-24',
        ),
      );
      await zeigeZiele(tester);

      expect(zeile(id), findsOneWidget);
      expect(leer, findsNothing);
      expect(listenFreigabe, findsOneWidget);
      expect(
        textUnter(tester, listenFreigabe),
        contains(freigabeText),
        reason: 'Der Hinweis steht ungekürzt da (Plan, Global Constraints).',
      );
    });

    testWidgets('eine vergangene Krankheit genügt für den Hinweis (V11)', (
      tester,
    ) async {
      final id = await lege(
        const Ereignis(
          art: EreignisArt.krankheit,
          von: '2099-09-21',
          bis: '2099-09-24',
        ),
      );
      await zeigeZiele(tester);

      expect(zeile(id), findsOneWidget);
      expect(listenFreigabe, findsOneWidget, reason: 'V11: „egal ob laufend“.');
    });

    testWidgets('nur Urlaub → Zeile, aber kein Freigabe-Hinweis (V11)', (
      tester,
    ) async {
      final id = await lege(
        const Ereignis(
          art: EreignisArt.urlaub,
          von: '2099-10-12',
          bis: '2099-10-19',
        ),
      );
      await zeigeZiele(tester);

      expect(zeile(id), findsOneWidget);
      expect(leer, findsNothing);
      expect(listenFreigabe, findsNothing);
    });
  });

  group('Eintragen', () {
    testWidgets('„+“ öffnet das Blatt mit Freigabe-Hinweis, ohne Löschen', (
      tester,
    ) async {
      await zeigeZiele(tester);
      await tippe(tester, plus);

      expect(sichern, findsOneWidget, reason: 'Das Blatt ist offen.');
      expect(
        blattFreigabe,
        findsOneWidget,
        reason: 'OP ist vorgewählt, und bei der OP steht der Hinweis.',
      );
      expect(textUnter(tester, blattFreigabe), contains(freigabeText));
      expect(
        loeschen,
        findsNothing,
        reason: '„Auszeit löschen“ gibt es nur im Ändern-Blatt (V7).',
      );
      for (final a in EreignisArt.values) {
        expect(art(a), findsOneWidget, reason: 'Segment für ${a.name}.');
      }
    });

    testWidgets('Urlaub nimmt den Freigabe-Hinweis weg, Krankheit bringt '
        'ihn zurück', (tester) async {
      await zeigeZiele(tester);
      await tippe(tester, plus);

      await tippe(tester, art(EreignisArt.urlaub));
      expect(
        blattFreigabe,
        findsNothing,
        reason: 'Bei Urlaub gibt es nichts freizugeben (Spec).',
      );

      await tippe(tester, art(EreignisArt.krankheit));
      expect(blattFreigabe, findsOneWidget);

      await tippe(tester, art(EreignisArt.verletzung));
      expect(blattFreigabe, findsOneWidget);
    });

    testWidgets('Sichern ohne Änderung legt eine OP vom Esstag bis '
        '14 Tage danach an', (tester) async {
      await zeigeZiele(tester);
      await tippe(tester, plus);
      await tippe(tester, sichern);

      final liste = await abgelegt();
      expect(liste, hasLength(1));
      expect(liste.single.art, EreignisArt.op, reason: 'OP ist vorgewählt.');
      expect(liste.single.von, esstag, reason: 'Beginn = der Esstag (V4).');
      expect(liste.single.bis, '2099-10-28', reason: 'Ende = Beginn + 14.');
      expect(liste.single.notiz, isNull);
    });

    testWidgets('nach dem Sichern steht die Zeile und der Freigabe-Hinweis '
        '(V11)', (tester) async {
      await zeigeZiele(tester);
      expect(leer, findsOneWidget);

      await tippe(tester, plus);
      await tippe(tester, sichern);

      final id = (await abgelegt()).single.id!;
      expect(sichern, findsNothing, reason: 'Das Blatt ist zu.');
      expect(zeile(id), findsOneWidget);
      expect(leer, findsNothing);
      expect(listenFreigabe, findsOneWidget);
    });

    testWidgets('Urlaub sichern: Zeile ja, Freigabe-Hinweis nein', (
      tester,
    ) async {
      await zeigeZiele(tester);
      await tippe(tester, plus);
      await tippe(tester, art(EreignisArt.urlaub));
      await tippe(tester, sichern);

      final e = (await abgelegt()).single;
      expect(e.art, EreignisArt.urlaub);
      expect(e.von, esstag);
      expect(e.bis, esstag, reason: 'Außer bei der OP: Ende = Beginn (V4).');
      expect(zeile(e.id!), findsOneWidget);
      expect(listenFreigabe, findsNothing);
    });

    testWidgets('die Notiz wird getrimmt abgelegt (V6)', (tester) async {
      await zeigeZiele(tester);
      await tippe(tester, plus);

      expect(notiz, findsOneWidget);
      await tester.enterText(notiz, '  Knie  ');
      await tester.pumpAndSettle();
      await tippe(tester, sichern);

      expect((await abgelegt()).single.notiz, 'Knie');
    });

    testWidgets('Datumswahl: ein Rad im Modus Datum, höchstens eins offen '
        '(V19)', (tester) async {
      await zeigeZiele(tester);
      await tippe(tester, plus);

      expect(
        find.byType(CupertinoDatePicker),
        findsNothing,
        reason: 'Das Rad klappt erst auf Tippen auf.',
      );

      await tippe(tester, von);
      expect(find.byType(CupertinoDatePicker), findsOneWidget);
      expect(
        tester
            .widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker))
            .mode,
        CupertinoDatePickerMode.date,
      );

      await tippe(tester, bis);
      expect(
        find.byType(CupertinoDatePicker),
        findsOneWidget,
        reason: 'Offen ist höchstens eins (V19).',
      );
    });

    testWidgets('ein neuer Beginn im Rad zieht das Ende der OP nach (V4)', (
      tester,
    ) async {
      await zeigeZiele(tester);
      await tippe(tester, plus);
      await tippe(tester, von);

      tester
          .widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker))
          .onDateTimeChanged(DateTime(2099, 10, 20, 12));
      await tester.pumpAndSettle();
      await tippe(tester, sichern);

      final e = (await abgelegt()).single;
      expect(e.von, '2099-10-20');
      expect(
        e.bis,
        '2099-11-03',
        reason: 'Das Blatt nimmt die Formularlogik, nicht eine eigene.',
      );
    });
  });

  group('Zurück und wieder hin (`32`)', () {
    testWidgets('eine angelegte Auszeit steht nach erneutem Öffnen wieder da', (
      tester,
    ) async {
      final navigator = await zeigeZiele(tester);
      await tippe(tester, plus);
      await tippe(tester, sichern);
      final id = (await abgelegt()).single.id!;
      expect(zeile(id), findsOneWidget);

      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(
        find.byType(ZieleView),
        findsNothing,
        reason: 'Zurück im Mehr-Menü.',
      );

      await tester.tap(zieleZeile());
      await tester.pumpAndSettle();

      expect(zeile(id), findsOneWidget);
      expect(listenFreigabe, findsOneWidget);
      expect(leer, findsNothing);
    });
  });

  group('Ändern und Löschen (V7)', () {
    Future<int> legeOp() => lege(
      const Ereignis(
        art: EreignisArt.op,
        von: '2099-10-10',
        bis: '2099-10-24',
        notiz: 'Knie',
      ),
    );

    testWidgets('ein Tipp auf die Zeile öffnet das Blatt vorbelegt, mit '
        'Löschen', (tester) async {
      final id = await legeOp();
      await zeigeZiele(tester);
      await tippe(tester, zeile(id));

      expect(sichern, findsOneWidget, reason: 'Das Blatt ist offen.');
      expect(loeschen, findsOneWidget);
      expect(notizText(tester), 'Knie', reason: 'Vorbelegt.');
      expect(blattFreigabe, findsOneWidget);
    });

    testWidgets('Notiz und Art ändern, sichern → die Zeile zeigt den neuen '
        'Stand', (tester) async {
      final id = await legeOp();
      await zeigeZiele(tester);
      final vorher = textUnter(tester, zeile(id));

      await tippe(tester, zeile(id));
      await tester.enterText(notiz, 'Knie, beide');
      await tester.pumpAndSettle();
      await tippe(tester, art(EreignisArt.verletzung));
      await tippe(tester, sichern);

      final liste = await abgelegt();
      expect(liste, hasLength(1), reason: 'Geändert, nicht neu angelegt.');
      final e = liste.single;
      expect(e.id, id);
      expect(e.art, EreignisArt.verletzung);
      expect(e.notiz, 'Knie, beide');
      expect(e.von, '2099-10-10');
      expect(
        e.bis,
        '2099-10-24',
        reason: 'Im Ändern-Blatt gilt das Ende als von Hand gesetzt (V4).',
      );
      expect(e.geaendert, isNotNull, reason: 'Über `aendere`, nicht neu.');

      expect(sichern, findsNothing, reason: 'Das Blatt ist zu.');
      expect(zeile(id), findsOneWidget);
      expect(
        textUnter(tester, zeile(id)),
        isNot(vorher),
        reason: 'Die Zeile zeigt den neuen Stand, nicht den alten.',
      );

      await tippe(tester, zeile(id));
      expect(notizText(tester), 'Knie, beide');
    });

    testWidgets('„Auszeit löschen“ fragt; „Abbrechen“ lässt die Zeile', (
      tester,
    ) async {
      final id = await legeOp();
      await zeigeZiele(tester);
      await tippe(tester, zeile(id));
      await tippe(tester, loeschen);

      final rueckfrage = find.byType(CupertinoAlertDialog);
      expect(rueckfrage, findsOneWidget, reason: 'Löschen fragt (V7).');

      await tippe(
        tester,
        find.descendant(of: rueckfrage, matching: find.text('Abbrechen')),
      );

      expect(rueckfrage, findsNothing);
      expect(await abgelegt(), hasLength(1));
      expect(zeile(id), findsOneWidget);
    });

    testWidgets('„Löschen“ in der Rückfrage nimmt die Zeile', (tester) async {
      final id = await legeOp();
      await zeigeZiele(tester);
      await tippe(tester, zeile(id));
      await tippe(tester, loeschen);

      final rueckfrage = find.byType(CupertinoAlertDialog);
      await tippe(
        tester,
        find.descendant(of: rueckfrage, matching: find.text('Löschen')),
      );

      expect(rueckfrage, findsNothing);
      expect(sichern, findsNothing, reason: 'Auch das Blatt ist zu.');
      expect(await abgelegt(), isEmpty);
      expect(zeile(id), findsNothing);
      expect(leer, findsOneWidget);
      expect(listenFreigabe, findsNothing);
    });
  });

  group('Mehr › Ziele (V18)', () {
    testWidgets('die Zeile ist aktiv und schiebt auf den aktuellen Stapel', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final router = AppRouter();
      final tabVorher = router.tab;
      await tester.pumpWidget(CupertinoApp(home: MehrView(router: router)));
      await tester.pumpAndSettle();

      expect(
        tester.widget<IconRow>(zieleZeile()).onTap,
        isNotNull,
        reason: 'Die Zeile führt jetzt irgendwohin (V18).',
      );
      final opazitaet = tester
          .widgetList<Opacity>(
            find.ancestor(of: zieleZeile(), matching: find.byType(Opacity)),
          )
          .fold<double>(1, (p, o) => p * o.opacity);
      expect(opazitaet, 1.0, reason: 'Nicht mehr ausgegraut (V18).');

      await tester.tap(zieleZeile());
      await tester.pumpAndSettle();

      expect(
        router.tab,
        tabVorher,
        reason:
            'Ein Menüpunkt wechselt nie den '
            'Tab (`CLAUDE.md`).',
      );
      final befehl = router.nimmBefehl();
      expect(befehl, isNotNull);
      expect(
        befehl!.ersetztStapel,
        isFalse,
        reason: 'Geschoben (`AppTarget.aktuell`), nicht ersetzt.',
      );

      await tester.pumpWidget(
        BehaelterImBaum(
          container: behaelter(),
          child: CupertinoApp(home: Builder(builder: befehl.builder)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ZieleView), findsOneWidget);
      expect(
        find.byType(Navigator),
        findsOneWidget,
        reason:
            'Ein gepushter Schirm bringt keinen eigenen Navigator mit '
            '(`CLAUDE.md`).',
      );
      expect(plus, findsOneWidget, reason: 'Das „+“ gehört zum Schirm.');
    });
  });
}

/// Ein Repository, dessen Lesen erst antwortet, wenn der Test es sagt.
class _HaengendesRepo extends EreignisRepository {
  _HaengendesRepo(super.db, this.antwort);

  final Completer<List<Ereignis>> antwort;

  @override
  Future<List<Ereignis>> alle() => antwort.future;
}

/// Eine Quelle, die nichts hergibt. Der Schirm fragt Apple Health nicht.
class _LeereQuelle extends HealthReadingAttrappe {
  @override
  DateTime get earliestPermittedDate => DateTime.utc(2000);
}
