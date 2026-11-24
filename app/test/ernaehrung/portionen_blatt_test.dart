import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
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
import 'package:repit/ernaehrung/buchungs_blatt.dart';
import 'package:repit/ernaehrung/erfassen_formular.dart';
import 'package:repit/ernaehrung/erfassen_provider.dart';
import 'package:repit/ernaehrung/off_client.dart';
import 'package:repit/ernaehrung/portions_abruf.dart';
import 'package:repit/health/health_provider.dart';

import '../design/support.dart' show textOf;

/// Widget-Tests für die **Portionswahl im Buchungsblatt** (#399, unter
/// #325): Knopfreihe, Anzahl, Ladezustände.
///
/// Geschrieben nach Task 7 des Plans
/// `docs/superpowers/plans/2026-11-05-portionen.md`, der Spec
/// `docs/superpowers/specs/2026-11-05-portionen-design.md` (Abschnitte
/// „Das Buchungsblatt", „Leerzustände", V7, V8, V13) und dem Entwurf
/// `docs/screens/screens/erfassen.js` (`produkt`, `produkt-laedt`,
/// `produkt-kein-netz`, `produkt-ohne-portion`) — **bevor** der Wähler
/// gebaut war. Für Widget-Tests genügt ein Agent, wenn der Test zuerst
/// entsteht, rot gesehen und vor der Implementierung committet wird
/// (`CLAUDE.md`, „Wer Tests schreibt, schreibt nicht die
/// Implementierung"). Diese Datei darf ausgeführt, aber nicht verändert
/// werden.
///
/// ## Was diese Tests verbindlich vorgeben
///
/// ```dart
/// // lib/ernaehrung/buchungs_blatt.dart
/// class BuchungsBlatt extends ConsumerStatefulWidget {
///   const BuchungsBlatt({
///     super.key,
///     required this.formular,
///     this.abruf,          // brauchtAbruf(vorlage), sonst null
///     this.onFertig,
///   });
/// }
/// ```
///
/// **`abruf` ist eine Festlegung des Test-Agenten**, nicht des Plans und
/// nicht Tims: Der Plan sagt „Das Blatt schaut auf
/// `portionsAbrufProvider(quelle)` nur, wenn `brauchtAbruf` nicht `null`
/// ist", aber `brauchtAbruf` braucht die Vorlage, und das Formular kennt
/// bei einem übernommenen Produkt weder Strichcode noch
/// `portionenAbgefragtAm`. Wer das Blatt öffnet, kennt die Vorlage und
/// reicht die Quelle herein.
///
/// ## Die Schlüssel
///
/// Aus dem Plan: `portion-knopf-<index>` (die Portionen in der Reihe, ab
/// 0, in Reihenfolge), `portion-gramm` (der Knopf „g" bzw. „ml"),
/// `portion-plus`, `portion-minus` (beide `CupertinoButton`, gesperrt heißt
/// `onPressed == null`), `portion-anzahl` (die Anzahl, nur bei gewählter
/// Portion), `portion-zeile` (die eine Zeile unter der Wahl),
/// `portion-platzhalter` (je grauer Platzhalter einer), `portion-neu`
/// („+ Portion"). Dazu, vom Test-Agenten: `portion-reihe` (die Knopfreihe
/// als Ganzes, für die Höhe). Weiter gelten `buchung-menge` (das
/// Mengenfeld, nur bei „g") und `buchung-sichern` aus
/// `erfassen_view_test.dart`.
///
/// ## Was hier geprüft wird — und was nicht
///
/// Zustände und Übergänge, keine Beschriftung um ihrer selbst willen. Wo
/// ein Text geprüft wird, ist er der Zustand: „nicht abrufbar" und „keine
/// Portion bekannt" sind zwei verschiedene Auskünfte, und dass sie nicht
/// vermischt werden, ist die Anforderung (Fehler `01`).
///
/// Alle Produkte, Namen, Zahlen und Strichcodes sind **erfunden**, alle
/// Zeitpunkte liegen im Jahr 2099.
void main() {
  // Dienstag, 07.04.2099, 12:30 Berliner Zeit (MESZ, +2).
  final jetzt = DateTime.utc(2099, 4, 7, 10, 30);
  const heute = '2099-04-07';

  const barcodeBons = '0000000000086';

  const bonsJe100g = Naehrwerte.je100g(
    kcal: 570,
    eiweissG: 7.6,
    kohlenhydrateG: 50,
    fettG: 38,
  );
  const haferJe100g = Naehrwerte.je100g(
    kcal: 372,
    eiweissG: 13.5,
    kohlenhydrateG: 58.7,
    fettG: 7,
  );

  /// Ein Online-Treffer der Suche: noch nicht in der eigenen Tabelle,
  /// Portionen nicht abgefragt.
  const onlineTreffer = LebensmittelVorlage(
    name: 'Prüf-Bons Erfundenwerk',
    je100g: bonsJe100g,
    barcode: barcodeBons,
    herkunft: Herkunft.off,
  );

  // --- Open Food Facts ----------------------------------------------

  http.Response produktAntwort({num portion = 5.9, num packung = 225}) =>
      http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'code': barcodeBons,
            'status': 1,
            'status_verbose': 'product found',
            'product': {
              'code': barcodeBons,
              'product_name': 'Prüf-Bons Erfundenwerk',
              'brands': 'Erfundenwerk',
              'nutriments': {
                'energy-kcal_100g': 570,
                'proteins_100g': 7.6,
                'carbohydrates_100g': 50,
                'fat_100g': 38,
              },
              'serving_quantity': portion,
              'serving_quantity_unit': 'g',
              'product_quantity': packung,
              'product_quantity_unit': 'g',
            },
          }),
        ),
        200,
        headers: const {'content-type': 'application/json; charset=utf-8'},
      );

  // --- Hilfsmittel ---------------------------------------------------

  ({ProviderContainer container, AppCache db, _Netz netz}) behaelter() {
    final db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);
    final netz = _Netz();
    // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        appCacheProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => jetzt),
        offClientProvider.overrideWithValue(OffClient(client: netz.client)),
      ],
    );
    addTearDown(container.dispose);
    return (container: container, db: db, netz: netz);
  }

  Future<void> zeige(
    WidgetTester tester,
    ProviderContainer container,
    Widget inhalt,
  ) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Jedes Mal ein frischer Baum: Ein Zustand mit eigenem Behälter ist
    // ein anderes Blatt, nicht dasselbe mit neuem Formular.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: CupertinoApp(home: CupertinoPageScaffold(child: inhalt)),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Lässt die Zeitüberschreitung einer hängenden Anfrage ablaufen —
  /// sonst bleibt ihr Timer nach dem Test stehen.
  Future<void> ausklingen(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
    await tester.pump();
  }

  Finder schluessel(String s) => find.byKey(Key(s));

  String textUnter(WidgetTester tester, String key) => tester
      .widgetList<Text>(
        find.descendant(of: schluessel(key), matching: find.byType(Text)),
      )
      .map(textOf)
      .join(' ');

  /// Der Text im Eingabefeld unter [key].
  String feldText(WidgetTester tester, String key) => tester
      .widget<EditableText>(
        find.descendant(
          of: schluessel(key),
          matching: find.byType(EditableText),
        ),
      )
      .controller
      .text;

  bool gesperrt(WidgetTester tester, String key) =>
      tester.widget<CupertinoButton>(schluessel(key)).onPressed == null;

  /// „g" ist gewählt: Das Mengenfeld steht da, die Anzahl nicht.
  void gIstGewaehlt() {
    expect(schluessel('buchung-menge'), findsOneWidget);
    expect(schluessel('portion-anzahl'), findsNothing);
  }

  /// Ein eigenes Lebensmittel mit „Bon" (5,9 g) und „Packung" (225 g),
  /// einmal mit 2 Bons gebucht. Gibt Lebensmittel- und Bon-Schlüssel.
  Future<({int id, int bonId})> zweiBonsGebucht(ProviderContainer c) async {
    final id = await c
        .read(lebensmittelRepositoryProvider)
        .legeAn(
          const LebensmittelVorlage(name: 'Prüf-Bons', je100g: bonsJe100g),
          portionen: const [
            Portion(name: 'Bon', mengeG: 5.9),
            Portion(name: 'Packung', mengeG: 225),
          ],
        );
    final portionen = await c.read(portionenRepositoryProvider).fuer(id);
    final bon = portionen.firstWhere((p) => p.name == 'Bon');
    await c
        .read(ernaehrungRepositoryProvider)
        .buche(
          Eintrag(
            tagesSchluessel: '2099-04-06',
            mahlzeit: Mahlzeit.snack,
            zeitpunkt: DateTime.utc(2099, 4, 6, 14, 20),
            lebensmittelId: id,
            name: 'Prüf-Bons',
            mengeG: 11.8,
            naehrwerte: bonsJe100g.fuerMenge(11.8),
            portionId: bon.id,
            portionName: 'Bon',
            portionG: 5.9,
          ),
        );
    return (id: id, bonId: bon.id!);
  }

  Future<BuchungsFormular> oeffne(
    ProviderContainer c,
    LebensmittelVorlage vorlage,
  ) => c
      .read(erfassenProvider.notifier)
      .oeffneFormular(vorlage: vorlage, tagesSchluessel: heute, jetzt: jetzt);

  Future<LebensmittelVorlage> vorlage(ProviderContainer c, int id) async =>
      (await c.read(lebensmittelRepositoryProvider).lies(id))!;

  // ═════════════════════════════════════════════════════════════════════
  group('Der Abruf beim Antippen', () {
    testWidgets('während des Abrufs steht nie „Keine Portion bekannt" — '
        'zwei Platzhalter, „g" gewählt, Buchen offen (Fehler 01)', (
      tester,
    ) async {
      final b = behaelter(); // ohne Antwort: Die Anfrage hängt.
      final formular = await oeffne(b.container, onlineTreffer);
      await zeige(
        tester,
        b.container,
        BuchungsBlatt(formular: formular, abruf: brauchtAbruf(onlineTreffer)),
      );

      expect(b.netz.anfragen, hasLength(1));
      expect(schluessel('portion-platzhalter'), findsNWidgets(2));
      expect(schluessel('portion-zeile'), findsOneWidget);
      expect(
        textUnter(tester, 'portion-zeile').toLowerCase(),
        isNot(contains('keine portion')),
        reason: 'während nachgesehen wird, ist nichts entschieden',
      );
      expect(
        textUnter(tester, 'portion-zeile').toLowerCase(),
        isNot(contains('nicht abrufbar')),
      );
      gIstGewaehlt();
      expect(schluessel('portion-gramm'), findsOneWidget);
      expect(schluessel('portion-neu'), findsOneWidget);
      expect(
        gesperrt(tester, 'buchung-sichern'),
        isFalse,
        reason: 'gebucht werden kann sofort in g',
      );

      await ausklingen(tester);
    });

    testWidgets('kommen die Portionen an, bleibt die Wahl — 30 g bleiben '
        '30 g', (tester) async {
      final b = behaelter();
      final formular = await oeffne(b.container, onlineTreffer);
      await zeige(
        tester,
        b.container,
        BuchungsBlatt(formular: formular, abruf: brauchtAbruf(onlineTreffer)),
      );

      await tester.enterText(schluessel('buchung-menge'), '30');
      await tester.pumpAndSettle();

      b.netz.beantworte(0, produktAntwort());
      await tester.pumpAndSettle();

      expect(schluessel('portion-knopf-0'), findsOneWidget);
      expect(schluessel('portion-knopf-1'), findsOneWidget);
      expect(schluessel('portion-platzhalter'), findsNothing);
      gIstGewaehlt();
      expect(feldText(tester, 'buchung-menge'), '30');
      expect(b.netz.anfragen, hasLength(1), reason: 'eine je Öffnen');

      await ausklingen(tester);
    });

    testWidgets('gescheitert heißt „nicht abrufbar", nicht „keine Portion" — '
        'und kein Platzhalter', (tester) async {
      final b = behaelter();
      b.netz.antwort = (_) => http.Response('überlastet (erfunden)', 503);
      final formular = await oeffne(b.container, onlineTreffer);
      await zeige(
        tester,
        b.container,
        BuchungsBlatt(formular: formular, abruf: brauchtAbruf(onlineTreffer)),
      );

      final zeile = textUnter(tester, 'portion-zeile').toLowerCase();
      expect(zeile, contains('nicht abrufbar'));
      expect(zeile, isNot(contains('keine portion')));
      expect(schluessel('portion-platzhalter'), findsNothing);
      expect(schluessel('portion-neu'), findsOneWidget);
      gIstGewaehlt();
      expect(gesperrt(tester, 'buchung-sichern'), isFalse);
      expect(b.netz.anfragen, hasLength(1), reason: 'keine Wiederholung');
    });

    testWidgets('ohne Abruf und ohne Portion: „Keine Portion bekannt", kein '
        'Platzhalter, keine Anfrage', (tester) async {
      final b = behaelter();
      final id = await b.container
          .read(lebensmittelRepositoryProvider)
          .legeAn(
            const LebensmittelVorlage(
              name: 'Prüf-Hafer kernig',
              je100g: haferJe100g,
            ),
          );
      final v = await vorlage(b.container, id);
      await zeige(
        tester,
        b.container,
        BuchungsBlatt(
          formular: await oeffne(b.container, v),
          abruf: brauchtAbruf(v),
        ),
      );

      expect(
        textUnter(tester, 'portion-zeile').toLowerCase(),
        contains('keine portion bekannt'),
      );
      expect(schluessel('portion-platzhalter'), findsNothing);
      expect(schluessel('portion-knopf-0'), findsNothing);
      expect(schluessel('portion-neu'), findsOneWidget);
      expect(b.netz.anfragen, isEmpty);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Eine Form für alle Zustände', () {
    testWidgets('Zeile und Knopfreihe sind in Laden, Gescheitert, Ohne und '
        'Bekannt gleich hoch', (tester) async {
      final hoehen = <String, (double, double)>{};

      void miss(String zustand) {
        hoehen[zustand] = (
          tester.getSize(schluessel('portion-zeile')).height,
          tester.getSize(schluessel('portion-reihe')).height,
        );
      }

      // Laden.
      final laden = behaelter();
      await zeige(
        tester,
        laden.container,
        BuchungsBlatt(
          formular: await oeffne(laden.container, onlineTreffer),
          abruf: brauchtAbruf(onlineTreffer),
        ),
      );
      miss('laden');

      // Bekannt, „g" gewählt — dieselbe Anfrage, jetzt beantwortet.
      laden.netz.beantworte(0, produktAntwort());
      await tester.pumpAndSettle();
      expect(schluessel('portion-knopf-0'), findsOneWidget);
      miss('bekannt, g');

      // Bekannt, Portion gewählt.
      await tester.tap(schluessel('portion-knopf-0'));
      await tester.pumpAndSettle();
      expect(schluessel('portion-anzahl'), findsOneWidget);
      miss('bekannt, Portion');
      await ausklingen(tester);

      // Gescheitert.
      final kaputt = behaelter();
      kaputt.netz.antwort = (_) => http.Response('weg (erfunden)', 503);
      await zeige(
        tester,
        kaputt.container,
        BuchungsBlatt(
          formular: await oeffne(kaputt.container, onlineTreffer),
          abruf: brauchtAbruf(onlineTreffer),
        ),
      );
      miss('gescheitert');

      // Ohne Portion.
      final ohne = behaelter();
      final id = await ohne.container
          .read(lebensmittelRepositoryProvider)
          .legeAn(
            const LebensmittelVorlage(
              name: 'Prüf-Hafer kernig',
              je100g: haferJe100g,
            ),
          );
      final v = await vorlage(ohne.container, id);
      await zeige(
        tester,
        ohne.container,
        BuchungsBlatt(formular: await oeffne(ohne.container, v)),
      );
      miss('ohne');

      final (zeile, reihe) = hoehen['laden']!;
      expect(zeile, greaterThan(0));
      expect(reihe, greaterThan(0));
      for (final MapEntry(key: zustand, value: (z, r)) in hoehen.entries) {
        expect(z, zeile, reason: 'Zeile, $zustand');
        expect(r, reihe, reason: 'Knopfreihe, $zustand');
      }
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Anzahl und Buchen', () {
    testWidgets('Vorwahl „2 × Bon": Anzahl 2, + ergibt 3, − bei 1 ist '
        'gesperrt', (tester) async {
      final b = behaelter();
      final (:id, bonId: _) = await zweiBonsGebucht(b.container);
      final v = await vorlage(b.container, id);
      await zeige(
        tester,
        b.container,
        BuchungsBlatt(formular: await oeffne(b.container, v)),
      );

      expect(schluessel('buchung-menge'), findsNothing);
      expect(feldText(tester, 'portion-anzahl'), '2');

      await tester.tap(schluessel('portion-plus'));
      await tester.pumpAndSettle();
      expect(feldText(tester, 'portion-anzahl'), '3');

      await tester.tap(schluessel('portion-minus'));
      await tester.pumpAndSettle();
      await tester.tap(schluessel('portion-minus'));
      await tester.pumpAndSettle();
      expect(feldText(tester, 'portion-anzahl'), '1');
      expect(gesperrt(tester, 'portion-minus'), isTrue);
      expect(gesperrt(tester, 'portion-plus'), isFalse);
    });

    testWidgets('ein Tipp auf die schon gewählte Portion setzt die Anzahl '
        'nicht zurück', (tester) async {
      final b = behaelter();
      final (:id, bonId: _) = await zweiBonsGebucht(b.container);
      final v = await vorlage(b.container, id);
      await zeige(
        tester,
        b.container,
        BuchungsBlatt(formular: await oeffne(b.container, v)),
      );
      expect(feldText(tester, 'portion-anzahl'), '2');

      // „Bon" (5,9 g) ist die kleinere der beiden, steht also vorn.
      await tester.tap(schluessel('portion-knopf-0'));
      await tester.pumpAndSettle();

      expect(feldText(tester, 'portion-anzahl'), '2');
    });

    testWidgets('„g" angetippt übernimmt die Gramm der Portion — aus 2 Bons '
        'werden 11,8 g', (tester) async {
      final b = behaelter();
      final (:id, bonId: _) = await zweiBonsGebucht(b.container);
      final v = await vorlage(b.container, id);
      await zeige(
        tester,
        b.container,
        BuchungsBlatt(formular: await oeffne(b.container, v)),
      );

      await tester.tap(schluessel('portion-gramm'));
      await tester.pumpAndSettle();

      gIstGewaehlt();
      expect(feldText(tester, 'buchung-menge'), '11,8');

      // Und zurück: Eine Portion angetippt beginnt bei 1.
      await tester.tap(schluessel('portion-knopf-1'));
      await tester.pumpAndSettle();
      expect(feldText(tester, 'portion-anzahl'), '1');
    });

    testWidgets('Buchen mit „2 × Bon (5,9 g)" schreibt 11,8 g und den '
        'Schnappschuss', (tester) async {
      final b = behaelter();
      final (:id, :bonId) = await zweiBonsGebucht(b.container);
      final v = await vorlage(b.container, id);
      var fertig = false;
      await zeige(
        tester,
        b.container,
        BuchungsBlatt(
          formular: await oeffne(b.container, v),
          onFertig: () => fertig = true,
        ),
      );

      await tester.tap(schluessel('buchung-sichern'));
      await tester.pumpAndSettle();

      expect(fertig, isTrue);
      final eintrag =
          (await b.container
                  .read(ernaehrungRepositoryProvider)
                  .eintraegeAmTag(heute))
              .single;
      expect(eintrag.mengeG, closeTo(11.8, 1e-9));
      expect(eintrag.portionId, bonId);
      expect(eintrag.portionName, 'Bon');
      expect(eintrag.portionG, 5.9);
    });

    testWidgets('ein Tipp auf die Anzahl öffnet eine Zifferneingabe — „0,5" '
        'wird übernommen', (tester) async {
      final b = behaelter();
      final (:id, :bonId) = await zweiBonsGebucht(b.container);
      final v = await vorlage(b.container, id);
      await zeige(
        tester,
        b.container,
        BuchungsBlatt(formular: await oeffne(b.container, v)),
      );

      await tester.tap(schluessel('portion-anzahl'));
      await tester.pumpAndSettle();

      expect(tester.testTextInput.isVisible, isTrue);
      final art =
          tester.testTextInput.setClientArgs!['inputType']
              as Map<String, dynamic>;
      expect(art['name'], 'TextInputType.number', reason: 'Ziffernblock');
      expect(art['decimal'], isTrue, reason: 'auch für 0,5');

      tester.testTextInput.enterText('0,5');
      await tester.pumpAndSettle();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(feldText(tester, 'portion-anzahl'), '0,5');
      expect(
        gesperrt(tester, 'portion-minus'),
        isTrue,
        reason: 'V7: bei 1 oder weniger ist − gesperrt',
      );

      await tester.tap(schluessel('buchung-sichern'));
      await tester.pumpAndSettle();

      final eintrag =
          (await b.container
                  .read(ernaehrungRepositoryProvider)
                  .eintraegeAmTag(heute))
              .single;
      expect(eintrag.mengeG, closeTo(2.95, 1e-9));
      expect(eintrag.portionId, bonId);
    });
  });
}

/// Ein Netz, das der Test in der Hand hat — wie in
/// `off_suche_view_test.dart`.
///
/// Mit [antwort] beantwortet es jede Anfrage sofort. Ohne [antwort]
/// **hängt** jede Anfrage, bis der Test sie mit [beantworte] auflöst —
/// die einzige zuverlässige Art, den Zustand „wird nachgesehen"
/// festzuhalten.
class _Netz {
  final anfragen = <http.Request>[];
  final _offen = <Completer<http.Response>>[];

  http.Response Function(http.Request anfrage)? antwort;

  late final http.Client client = MockClient((anfrage) {
    anfragen.add(anfrage);
    final sofort = antwort;
    if (sofort != null) return Future.sync(() => sofort(anfrage));
    final offen = Completer<http.Response>();
    _offen.add(offen);
    return offen.future;
  });

  void beantworte(int nummer, http.Response mit) =>
      _offen[nummer].complete(mit);
}
