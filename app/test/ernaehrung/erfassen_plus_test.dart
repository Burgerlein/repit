import 'dart:async';
import 'dart:convert';

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
import 'package:repit/data/portion.dart';
import 'package:repit/data/portionen_repository.dart';
import 'package:repit/design/symbole.dart';
import 'package:repit/ernaehrung/buchungs_blatt.dart';
import 'package:repit/ernaehrung/erfassen_provider.dart';
import 'package:repit/ernaehrung/erfassen_weg.dart';
import 'package:repit/ernaehrung/ernaehrung_view.dart';
import 'package:repit/ernaehrung/foto_kamera.dart';
import 'package:repit/ernaehrung/mahlzeit_view.dart';
import 'package:repit/ernaehrung/off_client.dart';
import 'package:repit/ernaehrung/strichcode_leser.dart';
import 'package:repit/ernaehrung/suche_view.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/ki/ki_schluessel.dart';
import 'package:repit/shell/root_view.dart';
import 'package:repit/shell/router.dart';

import '../design/support.dart' show textOf;
import '../tag/behaelter_im_baum.dart';
import 'foto_attrappe.dart';
import 'health_schreiben_attrappe.dart';
import 'kamera_attrappe.dart';

/// **„+" je Treffer, Haken, Rückgängig, Fertig** in der Suche (#440,
/// Schnitt 2 von #385) — Plan
/// `docs/superpowers/plans/2026-11-10-mahlzeiten-aufteilung.md`, Task 11;
/// Spec `docs/superpowers/specs/2026-11-10-mahlzeiten-aufteilung-design.md`,
/// Entscheidung 10, V24–V29 und „Erfassen: Kachelreihe und „+"";
/// Entwurf `docs/screens/screens/erfassen.js` (`SUCHE_NEU`,
/// `ZULETZT_PLUS`, `TREFFER_PLUS`, `PLUS_FUSS`, `FERTIG`, Zustände
/// `vorschlag-suche` und `vorschlag-gebucht`), `foodRow({knopf})` in
/// `docs/screens/components.js`. Tim hat V26 bestätigt: Die Suche bleibt
/// nach dem Buchen offen.
///
/// Geprüft an der **ganzen** App (`RootView`) auf einer Datenbank im
/// Speicher: Gebucht wird über den echten Schreibweg, und ob ein Eintrag
/// danach in der Mahlzeit steht, zeigt der echte Lesweg.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung**
/// (`CLAUDE.md`). Für Widget-Tests genügt ein Agent, solange der Test
/// zuerst entsteht, einmal rot gesehen und committet wird, bevor die
/// Implementierung anfängt. Danach darf diese Datei ausgeführt, aber nicht
/// verändert werden.
///
/// ## Die Schlüssel
///
/// Aus der Spec: `erfassen-plus-<zeile>`, `erfassen-band`,
/// `erfassen-rueckgaengig`, `erfassen-fertig`; dazu wie bisher
/// `erfassen-treffer-<id>`, `erfassen-off-<barcode>`, `erfassen-zaehler`,
/// `erfassen-abbrechen`, `erfassen-suchfeld`.
///
/// ## Festlegungen des Test-Agenten — nicht von Tim freigegeben
///
/// - **`<zeile>` ist alles nach `erfassen-` im Schlüssel der
///   Trefferzeile**: `erfassen-plus-treffer-12` für ein eigenes
///   Lebensmittel, `erfassen-plus-off-<barcode>` für einen Online-Treffer.
///   Die Spec sagt „dasselbe Suffix wie im Schlüssel der Trefferzeile";
///   mit dem Präfix `treffer-`/`off-` kann eine ID nie mit einem
///   Strichcode zusammenfallen.
/// - **Der Knopf behält seinen Schlüssel, auch als Haken** — er bucht in
///   beiden Formen (V28). Ob er den Haken trägt, sagt
///   `erfassen-gebucht-<zeile>` darin.
/// - **Ein per „+" übernommener Online-Treffer trägt den Haken danach an
///   seiner eigenen Zeile** (`erfassen-gebucht-treffer-<neue id>`): Nach
///   der Übernahme steht er unter den eigenen Treffern, die Online-Zeile
///   fällt als Dublette weg.
/// - **Die Zeile folgt der Portion in der Tabelle** (offener Punkt aus
///   #438): Ist die Portion der letzten Buchung gelöscht, sagt die Zeile
///   die Gramm von damals ohne Portion; ist sie geändert, die geänderte
///   Portion. Beides genau das, was das Blatt vorwählt und „+" bucht
///   (V24). Das gilt auch, wenn die Änderung bei offener Suche passiert.
/// - **Das Band nennt die Mahlzeit wie das Suchfeld** (V23): „zum
///   Frühstück", „zu Mittag", „zu Abend", „als Snack".
///
/// Nicht geprüft: Layout und Beschriftung (`CLAUDE.md`) — außer der Menge
/// und den kcal in der Zeile, weil genau das die Anforderung ist (V24),
/// und Name, Menge und Mahlzeit im Band, weil es sagt, was wohin gebucht
/// ist.
///
/// Alle Namen, Zahlen und Strichcodes sind **erfunden**, alle Zeitpunkte
/// liegen im Jahr 2099; kein Test geht ins Netz.
void main() {
  // Dienstag, 07.04.2099, 12:00 Berliner Zeit (MESZ, +2) — die Uhr ergibt
  // Mittag. Vorgewählt ist in den meisten Fällen das Frühstück, damit eine
  // Buchung auf die Uhr-Mahlzeit auffiele.
  final jetzt = DateTime.utc(2099, 4, 7, 10);
  const heute = '2099-04-07';
  const gestern = '2099-04-06';

  const flockenName = 'Probe-Flocken';
  const flockenJe100g = Naehrwerte.je100g(kcal: 370, eiweissG: 13);
  const bonsName = 'Probe-Bons';
  const bonsJe100g = Naehrwerte.je100g(kcal: 520, eiweissG: 8);

  const barcodeQuark = '0000000000079';
  const quarkName = 'Probe-Quark Erfundenwerk';

  /// Die Antwort von `search.openfoodfacts.org/search` mit einem Treffer.
  http.Response suchAntwort() => http.Response.bytes(
    utf8.encode(
      jsonEncode({
        'count': 1,
        'is_count_exact': true,
        'page': 1,
        'page_count': 1,
        'page_size': 25,
        'timed_out': false,
        'hits': [
          {
            'code': barcodeQuark,
            'product_name': quarkName,
            'nutriments': {'energy-kcal_100g': 67, 'proteins_100g': 12},
          },
        ],
      }),
    ),
    200,
    headers: const {'content-type': 'application/json; charset=utf-8'},
  );

  // ───────────────────────────────────────────────────────────────────────
  // Testhülle
  // ───────────────────────────────────────────────────────────────────────

  ({ProviderContainer container, AppRouter router, SchreibAttrappe health})
  behaelter() {
    final db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);
    final health = SchreibAttrappe();
    final netz = MockClient((anfrage) async {
      if (anfrage.url.path.contains('/search')) return suchAntwort();
      // Kein Produkt-Endpunkt: Ein „+" fragt Open Food Facts nicht (V25).
      return http.Response('', 404);
    });

    // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        appCacheProvider.overrideWithValue(db),
        healthProvider.overrideWithValue(health),
        clockProvider.overrideWithValue(() => jetzt),
        offClientProvider.overrideWithValue(OffClient(client: netz)),
        strichcodeLeserProvider.overrideWithValue(TestLeser()),
        fotoKameraProvider.overrideWithValue(TestFotoKamera()),
        kiSchluesselProvider.overrideWithValue(AttrappenSchluesselSpeicher()),
      ],
    );
    addTearDown(container.dispose);
    return (container: container, router: AppRouter(), health: health);
  }

  Future<void> starte(
    WidgetTester tester,
    ({ProviderContainer container, AppRouter router, SchreibAttrappe health}) h,
  ) async {
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
  // Daten
  // ───────────────────────────────────────────────────────────────────────

  /// Legt ein Lebensmittel an und bucht es **gestern** einmal — so steht
  /// es unter „Zuletzt benutzt", und heute ist noch nichts gebucht.
  Future<int> gebucht(
    ProviderContainer c,
    String name,
    Naehrwerte je100g, {
    required double mengeG,
    List<Portion> portionen = const [],
    String? mitPortion,
  }) async {
    final lebensmittel = c.read(lebensmittelRepositoryProvider);
    final id = await lebensmittel.legeAn(
      LebensmittelVorlage(name: name, je100g: je100g),
      portionen: portionen,
    );
    Portion? p;
    if (mitPortion != null) {
      p = (await c.read(portionenRepositoryProvider).fuer(id))
          .firstWhere((x) => x.name == mitPortion);
    }
    await c
        .read(ernaehrungRepositoryProvider)
        .buche(
          Eintrag(
            tagesSchluessel: gestern,
            mahlzeit: Mahlzeit.fruehstueck,
            zeitpunkt: DateTime.utc(2099, 4, 6, 6),
            lebensmittelId: id,
            name: name,
            mengeG: mengeG,
            naehrwerte: je100g.fuerMenge(mengeG),
            portionId: p?.id,
            portionName: p?.name,
            portionG: p?.mengeG,
          ),
        );
    await lebensmittel.merkeBenutzung(id, DateTime.utc(2099, 4, 6, 6));
    return id;
  }

  /// „Probe-Flocken", zuletzt 80 g ohne Portion.
  Future<int> flocken(ProviderContainer c) =>
      gebucht(c, flockenName, flockenJe100g, mengeG: 80);

  /// „Probe-Bons" mit „Bon" (5,9 g), zuletzt 2 Bon.
  Future<int> bons(ProviderContainer c) => gebucht(
    c,
    bonsName,
    bonsJe100g,
    mengeG: 11.8,
    portionen: const [Portion(name: 'Bon', mengeG: 5.9)],
    mitPortion: 'Bon',
  );

  Future<List<Eintrag>> heuteGebucht(ProviderContainer c) =>
      c.read(ernaehrungRepositoryProvider).eintraegeAmTag(heute);

  // ───────────────────────────────────────────────────────────────────────
  // Helfer
  // ───────────────────────────────────────────────────────────────────────

  Future<void> tippe(WidgetTester tester, Finder ziel) async {
    await tester.tap(ziel);
    await tester.pumpAndSettle();
  }

  Future<void> oeffne(
    WidgetTester tester,
    AppRouter router, {
    Mahlzeit? mahlzeit = Mahlzeit.fruehstueck,
    int gebucht = 0,
  }) async {
    oeffneSuche(router, mahlzeit: mahlzeit, gebucht: gebucht);
    await tester.pumpAndSettle();
    expect(find.byType(SucheView), findsOneWidget);
  }

  /// Sucht nach „Probe" — eigene Treffer sofort, online nach der
  /// Entprellung.
  Future<void> sucheProbe(WidgetTester tester) async {
    await tester.enterText(find.byKey(const Key('erfassen-suchfeld')), 'Probe');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
  }

  Finder plus(String zeile) => find.byKey(Key('erfassen-plus-$zeile'));
  Finder haken(String zeile) => find.byKey(Key('erfassen-gebucht-$zeile'));
  Finder band() => find.byKey(const Key('erfassen-band'));

  String textUnter(WidgetTester tester, Finder wo) => tester
      .widgetList<Text>(find.descendant(of: wo, matching: find.byType(Text)))
      .map(textOf)
      .join(' ');

  String zeile(WidgetTester tester, String schluessel) =>
      textUnter(tester, find.byKey(Key('erfassen-$schluessel')));

  String zaehler(WidgetTester tester) =>
      textUnter(tester, find.byKey(const Key('erfassen-zaehler'))).trim();

  bool sichtbar(Finder f) => f.hitTestable().evaluate().isNotEmpty;

  /// Lässt Band und Entprellung auslaufen, damit kein Zeitgeber über das
  /// Testende hinaus hängt.
  Future<void> ausklingen(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 9));
    await tester.pump();
  }

  // ═════════════════════════════════════════════════════════════════════
  group('Die Zeile zeigt, was „+" bucht (V24)', () {
    testWidgets(
      'zuletzt 80 g: „80 g" und die kcal von 80 g, nicht „je 100 g"',
      (tester) async {
        final h = behaelter();
        final id = await flocken(h.container);
        await starte(tester, h);
        await oeffne(tester, h.router);

        final text = zeile(tester, 'treffer-$id');
        expect(text, contains('80 g'));
        expect(text, contains('296 kcal'), reason: '370 kcal × 0,8');
        expect(text, isNot(contains('je 100 g')));
        expect(plus('treffer-$id'), findsOneWidget);
        expect(haken('treffer-$id'), findsNothing);

        await ausklingen(tester);
      },
    );

    testWidgets('ein Online-Treffer: „100 g" und die kcal je 100 g', (
      tester,
    ) async {
      final h = behaelter();
      await starte(tester, h);
      await oeffne(tester, h.router);
      await sucheProbe(tester);

      final text = zeile(tester, 'off-$barcodeQuark');
      expect(text, contains('100 g'));
      expect(text, isNot(contains('je 100 g')));
      expect(text, contains('67 kcal'));
      expect(plus('off-$barcodeQuark'), findsOneWidget);

      await ausklingen(tester);
    });

    testWidgets('die Portion der letzten Buchung ist gelöscht: Die Zeile '
        'sagt die Gramm, und „+" bucht genau sie', (tester) async {
      final h = behaelter();
      final id = await bons(h.container);
      final bon = (await h.container.read(portionenRepositoryProvider).fuer(id))
          .single;
      await h.container.read(portionenRepositoryProvider).loesche(bon.id!);
      await starte(tester, h);
      await oeffne(tester, h.router);

      final text = zeile(tester, 'treffer-$id');
      expect(text, contains('11,8 g'));
      expect(text, isNot(contains('Bon (')));
      expect(text, contains('61 kcal'), reason: '520 kcal × 0,118');

      await tippe(tester, plus('treffer-$id'));
      final eintrag = (await heuteGebucht(h.container)).single;
      expect(eintrag.mengeG, closeTo(11.8, 1e-9));
      expect(eintrag.portionName, isNull);

      await ausklingen(tester);
    });

    testWidgets('die Portion ist geändert: Die Zeile nennt die geänderte, '
        'und „+" bucht genau sie', (tester) async {
      final h = behaelter();
      final id = await bons(h.container);
      final bon = (await h.container.read(portionenRepositoryProvider).fuer(id))
          .single;
      await h.container
          .read(portionenRepositoryProvider)
          .aendere(bon.mit(name: 'Bonbon', mengeG: 6.1));
      await starte(tester, h);
      await oeffne(tester, h.router);

      final text = zeile(tester, 'treffer-$id');
      expect(text, contains('2 Bonbon (12,2 g)'));
      expect(text, contains('63 kcal'), reason: '520 kcal × 0,122');

      await tippe(tester, plus('treffer-$id'));
      final eintrag = (await heuteGebucht(h.container)).single;
      expect(eintrag.mengeG, closeTo(12.2, 1e-9));
      expect(eintrag.portionName, 'Bonbon');

      await ausklingen(tester);
    });

    testWidgets('die Portion wird bei offener Suche gelöscht: Die Zeile '
        'zieht nach, ohne die Suche neu zu öffnen', (tester) async {
      final h = behaelter();
      final id = await bons(h.container);
      await starte(tester, h);
      await oeffne(tester, h.router);
      expect(zeile(tester, 'treffer-$id'), contains('2 Bon (11,8 g)'));

      final bon = (await h.container.read(portionenRepositoryProvider).fuer(id))
          .single;
      // Derselbe Weg, den das Blatt beim Löschen einer Portion nimmt.
      await h.container.read(erfassenProvider.notifier).loeschePortion(id, bon);
      await tester.pumpAndSettle();

      final text = zeile(tester, 'treffer-$id');
      expect(text, contains('11,8 g'));
      expect(text, isNot(contains('Bon (')));

      await ausklingen(tester);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('„+" bucht ohne Blatt (Entscheidung 10)', () {
    testWidgets('ein Eintrag mit genau dieser Menge auf der vorgewählten '
        'Mahlzeit, Haken, Zähler 1, Band mit Name, Menge und Mahlzeit', (
      tester,
    ) async {
      final h = behaelter();
      final id = await flocken(h.container);
      await starte(tester, h);
      await oeffne(tester, h.router);
      expect(zaehler(tester), '0');

      await tippe(tester, plus('treffer-$id'));

      expect(find.byType(BuchungsBlatt), findsNothing, reason: 'kein Blatt');
      expect(find.byType(SucheView), findsOneWidget, reason: 'V26');
      final gebuchtHeute = await heuteGebucht(h.container);
      expect(gebuchtHeute, hasLength(1));
      expect(gebuchtHeute.single.name, flockenName);
      expect(gebuchtHeute.single.mengeG, 80);
      expect(
        gebuchtHeute.single.mahlzeit,
        Mahlzeit.fruehstueck,
        reason: 'die vorgewählte Mahlzeit, nicht die der Uhr (Mittag)',
      );

      expect(haken('treffer-$id'), findsOneWidget);
      expect(zaehler(tester), '1');
      expect(band(), findsOneWidget);
      final text = textUnter(tester, band());
      expect(text, contains(flockenName));
      expect(text, contains('80 g'));
      expect(text, contains('zum Frühstück'));
      expect(find.byKey(const Key('erfassen-rueckgaengig')), findsOneWidget);

      await ausklingen(tester);
    });

    testWidgets('ein Online-Treffer bucht 100 g und trägt danach den Haken', (
      tester,
    ) async {
      final h = behaelter();
      await starte(tester, h);
      await oeffne(tester, h.router);
      await sucheProbe(tester);

      await tippe(tester, plus('off-$barcodeQuark'));

      expect(find.byType(BuchungsBlatt), findsNothing);
      final eintrag = (await heuteGebucht(h.container)).single;
      expect(eintrag.name, quarkName);
      expect(eintrag.mengeG, 100);
      expect(eintrag.lebensmittelId, isNotNull, reason: 'übernommen (V25)');
      expect(haken('treffer-${eintrag.lebensmittelId}'), findsOneWidget);
      expect(zaehler(tester), '1');

      await ausklingen(tester);
    });

    testWidgets('der Zähler zählt weiter, was die Kamera mitgab', (
      tester,
    ) async {
      final h = behaelter();
      final id = await flocken(h.container);
      await starte(tester, h);
      await oeffne(tester, h.router, gebucht: 2);
      expect(zaehler(tester), '2');

      await tippe(tester, plus('treffer-$id'));
      expect(zaehler(tester), '3');

      await ausklingen(tester);
    });

    testWidgets('ein Wechsel in die Kamera nimmt den Zähler nach einem „+" '
        'mit (V21)', (tester) async {
      final h = behaelter();
      final id = await flocken(h.container);
      await starte(tester, h);
      await oeffne(tester, h.router);

      await tippe(tester, plus('treffer-$id'));
      await tippe(tester, find.byKey(const Key('kamera-modus-barcode')));

      expect(find.byKey(const Key('kamera')), findsOneWidget);
      expect(zaehler(tester), '1');

      await ausklingen(tester);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Rückgängig (V27)', () {
    testWidgets('der Eintrag ist weg, Zähler 0, Haken weg — auch in Health', (
      tester,
    ) async {
      final h = behaelter();
      final id = await flocken(h.container);
      await starte(tester, h);
      await oeffne(tester, h.router);

      await tippe(tester, plus('treffer-$id'));
      // Der Nachlauf schreibt auch den offenen Eintrag von gestern mit
      // (#283), deshalb zählt die Kopie des heutigen, nicht die einzige.
      final kopie = (await heuteGebucht(h.container)).single.healthUuid;
      expect(kopie, isNotNull);
      expect(h.health.geschrieben.map((g) => g.id), contains(kopie));

      await tippe(tester, find.byKey(const Key('erfassen-rueckgaengig')));

      expect(await heuteGebucht(h.container), isEmpty);
      expect(zaehler(tester), '0');
      expect(haken('treffer-$id'), findsNothing);
      expect(plus('treffer-$id'), findsOneWidget);
      expect(band(), findsNothing);
      expect(
        h.health.loeschVersuche,
        contains(kopie),
        reason: '„Rückgängig" verspricht, dass er auch in Health weg ist',
      );

      await ausklingen(tester);
    });

    testWidgets('nach 8 s ist das Band weg, der Eintrag bleibt', (
      tester,
    ) async {
      final h = behaelter();
      final id = await flocken(h.container);
      await starte(tester, h);
      await oeffne(tester, h.router);

      await tippe(tester, plus('treffer-$id'));
      expect(band(), findsOneWidget);

      await tester.pump(const Duration(seconds: 7));
      expect(band(), findsOneWidget, reason: 'acht Sekunden, nicht weniger');

      await tester.pump(const Duration(seconds: 1, milliseconds: 100));
      await tester.pump();
      expect(band(), findsNothing);
      expect(await heuteGebucht(h.container), hasLength(1));
      expect(haken('treffer-$id'), findsOneWidget, reason: 'V28');
      expect(zaehler(tester), '1');
    });

    testWidgets('eine zweite Buchung ersetzt das Band; Rückgängig nimmt nur '
        'die zweite zurück, der Haken der ersten bleibt', (tester) async {
      final h = behaelter();
      final f = await flocken(h.container);
      final b = await bons(h.container);
      await starte(tester, h);
      await oeffne(tester, h.router);

      await tippe(tester, plus('treffer-$f'));
      await tippe(tester, plus('treffer-$b'));

      expect(band(), findsOneWidget);
      final text = textUnter(tester, band());
      expect(text, contains(bonsName));
      expect(text, isNot(contains(flockenName)));
      expect(zaehler(tester), '2');

      await tippe(tester, find.byKey(const Key('erfassen-rueckgaengig')));

      final uebrig = await heuteGebucht(h.container);
      expect(uebrig.map((e) => e.name), [flockenName]);
      expect(haken('treffer-$f'), findsOneWidget);
      expect(haken('treffer-$b'), findsNothing);
      expect(zaehler(tester), '1');
      expect(band(), findsNothing);

      await ausklingen(tester);
    });

    testWidgets('zweimal dieselbe Zeile, eine zurück: Der Haken bleibt', (
      tester,
    ) async {
      final h = behaelter();
      final id = await flocken(h.container);
      await starte(tester, h);
      await oeffne(tester, h.router);

      await tippe(tester, plus('treffer-$id'));
      await tippe(tester, plus('treffer-$id'));
      await tippe(tester, find.byKey(const Key('erfassen-rueckgaengig')));

      expect(await heuteGebucht(h.container), hasLength(1));
      expect(
        haken('treffer-$id'),
        findsOneWidget,
        reason: 'die Zeile hat in der Sitzung noch etwas gebucht',
      );
      expect(zaehler(tester), '1');

      await ausklingen(tester);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Der Haken (V28)', () {
    testWidgets('antippen bucht dieselbe Menge noch einmal', (tester) async {
      final h = behaelter();
      final id = await flocken(h.container);
      await starte(tester, h);
      await oeffne(tester, h.router);

      await tippe(tester, plus('treffer-$id'));
      expect(haken('treffer-$id'), findsOneWidget);
      await tippe(tester, plus('treffer-$id'));

      final gebuchtHeute = await heuteGebucht(h.container);
      expect(gebuchtHeute, hasLength(2));
      expect(gebuchtHeute.map((e) => e.mengeG), everyElement(80));
      expect(zaehler(tester), '2');
      expect(haken('treffer-$id'), findsOneWidget);
      expect(find.byType(BuchungsBlatt), findsNothing);

      await ausklingen(tester);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Ein Tipp auf die Zeile öffnet weiter das Blatt (V26)', () {
    testWidgets('nach dem Buchen dort bleibt die Suche offen, Zähler +1, '
        'Band, und Rückgängig nimmt auch diese Buchung zurück', (tester) async {
      final h = behaelter();
      final id = await flocken(h.container);
      await starte(tester, h);
      await oeffne(tester, h.router);

      await tippe(
        tester,
        find.descendant(
          of: find.byType(SucheView),
          matching: find.text(flockenName),
        ),
      );
      expect(find.byType(BuchungsBlatt), findsOneWidget);
      await tester.enterText(find.byKey(const Key('buchung-menge')), '50');
      await tester.pump();
      await tippe(tester, find.byKey(const Key('buchung-sichern')));

      expect(find.byType(BuchungsBlatt), findsNothing);
      expect(find.byType(SucheView), findsOneWidget, reason: 'V26');
      expect(zaehler(tester), '1');
      expect(haken('treffer-$id'), findsOneWidget);
      expect(band(), findsOneWidget);
      expect(textUnter(tester, band()), contains('50 g'));
      expect((await heuteGebucht(h.container)).single.mengeG, 50);

      await tippe(tester, find.byKey(const Key('erfassen-rueckgaengig')));
      expect(await heuteGebucht(h.container), isEmpty);
      expect(zaehler(tester), '0');

      await ausklingen(tester);
    });

    testWidgets('nach „Abbrechen" im Blatt zählt nichts', (tester) async {
      final h = behaelter();
      await flocken(h.container);
      await starte(tester, h);
      await oeffne(tester, h.router);

      await tippe(
        tester,
        find.descendant(
          of: find.byType(SucheView),
          matching: find.text(flockenName),
        ),
      );
      expect(find.byType(BuchungsBlatt), findsOneWidget);
      // Das Blatt hat für „Abbrechen" keinen Schlüssel; gesucht wird im
      // Blatt, nicht irgendwo — die Suche trägt ihr eigenes.
      await tippe(
        tester,
        find.descendant(
          of: find.byType(BuchungsBlatt),
          matching: find.text('Abbrechen'),
        ),
      );

      expect(find.byType(SucheView), findsOneWidget);
      expect(zaehler(tester), '0');
      expect(band(), findsNothing);

      await ausklingen(tester);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('„Fertig" und „Abbrechen" (V29)', () {
    for (final schluessel in const ['erfassen-fertig', 'erfassen-abbrechen']) {
      testWidgets('$schluessel schließt, beide Einträge bleiben', (
        tester,
      ) async {
        final h = behaelter();
        final f = await flocken(h.container);
        final b = await bons(h.container);
        await starte(tester, h);
        await oeffne(tester, h.router);

        await tippe(tester, plus('treffer-$f'));
        await tippe(tester, plus('treffer-$b'));
        await tippe(tester, find.byKey(Key(schluessel)));

        expect(find.byType(SucheView), findsNothing);
        expect((await heuteGebucht(h.container)).map((e) => e.name).toSet(), {
          flockenName,
          bonsName,
        }, reason: 'Schließen nimmt nichts zurück');

        await ausklingen(tester);
      });
    }
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Zurück und wieder hin (32)', () {
    testWidgets('die gebuchten Einträge stehen in der Mahlzeit, auch nach '
        'dem Zurücknavigieren', (tester) async {
      final h = behaelter();
      final f = await flocken(h.container);
      final b = await bons(h.container);
      await starte(tester, h);

      await tippe(
        tester,
        find.descendant(
          of: find.byType(CupertinoTabBar),
          matching: find.byIcon(Symbole.aufloesen('fork.knife')),
        ),
      );
      await tippe(
        tester,
        find.byKey(const Key('ernaehrung-mahlzeit-fruehstueck')),
      );
      await tippe(tester, find.byKey(const Key('mahlzeit-hinzufuegen')));
      await tippe(tester, find.byKey(const Key('kamera-suchen')));
      expect(find.byType(SucheView), findsOneWidget);

      await tippe(tester, plus('treffer-$f'));
      await tippe(tester, plus('treffer-$b'));
      await tippe(tester, find.byKey(const Key('erfassen-fertig')));

      expect(find.byType(SucheView), findsNothing);
      expect(sichtbar(find.byType(MahlzeitView)), isTrue);
      final gebuchtHeute = await heuteGebucht(h.container);
      expect(gebuchtHeute, hasLength(2));
      for (final e in gebuchtHeute) {
        expect(find.byKey(Key('mahlzeit-eintrag-${e.id}')), findsOneWidget);
      }

      await tippe(
        tester,
        find.byType(CupertinoNavigationBarBackButton).hitTestable(),
      );
      expect(sichtbar(find.byType(ErnaehrungView)), isTrue);
      await tippe(
        tester,
        find.byKey(const Key('ernaehrung-mahlzeit-fruehstueck')),
      );
      for (final e in gebuchtHeute) {
        expect(
          find.byKey(Key('mahlzeit-eintrag-${e.id}')),
          findsOneWidget,
          reason: 'ein Wert, der dastand, steht wieder da (`32`)',
        );
      }

      await ausklingen(tester);
    });
  });
}
