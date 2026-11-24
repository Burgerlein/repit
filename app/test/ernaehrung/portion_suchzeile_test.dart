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
import 'package:repit/ernaehrung/erfassen_provider.dart';
import 'package:repit/ernaehrung/off_client.dart';
import 'package:repit/ernaehrung/suche_view.dart';
import 'package:repit/health/health_provider.dart';

import '../design/support.dart' show textOf;
import 'health_schreiben_attrappe.dart';

/// Widget-Tests für die **Trefferzeile der Suche mit der letzten Portion**
/// (#401, unter #325; Spec, V9 — von Tim am 05.11.2026 übernommen).
///
/// Geschrieben nach Task 9, Step 2 des Plans
/// `docs/superpowers/plans/2026-11-05-portionen.md`, der Spec
/// `docs/superpowers/specs/2026-11-05-portionen-design.md` (V9,
/// Entscheidung 8, „Abruf beim Antippen") und dem Entwurf `erfassen.js`
/// (`SCHOKO_TREFFER`: „Schoko-Bons · 2 Bon (11,8 g) · 67 kcal · eigen") —
/// **bevor** die Zeile gebaut war. Diese Datei darf ausgeführt, aber nicht
/// verändert werden (`CLAUDE.md`, „Wer Tests schreibt, schreibt nicht die
/// Implementierung").
///
/// **Eine eigene Datei, nicht in `portion_aendern_blatt_test.dart`:** Die
/// Zeile hängt an `ErnaehrungRepository.letzteBuchungen`
/// (`test/data/letzte_buchungen_test.dart`), und das baut laut Plan ein
/// zweiter Agent. Bis dahin ist diese Datei rot, die andere nicht.
///
/// ## Was hier geprüft wird
///
/// - Ein **eigenes** Lebensmittel, zuletzt mit „2 Bon" gebucht, zeigt
///   „2 Bon (11,8 g)" und die **Kalorien dieser Menge**, nicht die je
///   100 g.
/// - **Ohne Portion bleibt es bei „je 100 g"** — auch wenn zuletzt in g
///   gebucht wurde, und wenn nie gebucht wurde.
/// - **Online-Treffer bleiben unverändert**, und für die Zeilen geht
///   **keine** Anfrage an den Produkt-Endpunkt (Review-Fokus 2: keine
///   Massenabfrage durch die Hintertür).
/// - **Schnappschuss statt Verweis** (Entscheidung 8): Die Zeile nennt die
///   Portion so, wie sie gebucht wurde, auch nach dem Umbenennen in der
///   Tabelle.
/// - **Neu gebucht, neu gezeigt:** Wer danach 3 Bons bucht, sieht in der
///   Zeile „3 Bon" — die Zeile hält keinen alten Stand fest.
///
/// Neue Schlüssel führt diese Datei nicht ein: `erfassen-suchfeld`,
/// `erfassen-treffer-<id>` und `erfassen-off-<barcode>` gibt es
/// (`erfassen_view_test.dart`, `off_suche_view_test.dart`).
///
/// ## Festlegungen des Test-Agenten — nicht von Tim freigegeben
///
/// - **Wie der Provider heißt und wovon er abhängt, legt diese Datei nicht
///   fest.** Der Plan nennt `letztePortionenProvider`; geprüft wird nur,
///   was der Schirm zeigt.
/// - **Ein Getränk zeigt „ml"**: „2 Glas (500 ml)". V9 nennt nur Gramm;
///   der Knopf im Buchungsblatt schreibt bei Flüssigem aber „ml" (Spec,
///   „Das Buchungsblatt"), und eine Zeile in Gramm widerspräche ihm.
/// - **Die Kalorien werden mit `formatNumber` ohne Nachkommastelle
///   geschrieben**, wie heute in der Zeile: 570 kcal × 0,118 = 67,26 →
///   „67".
///
/// ## Nachtrag #440 (10.11.2026)
///
/// Tim hat V24 freigegeben (Spec
/// `2026-11-10-mahlzeiten-aufteilung-design.md`): **Die zweite Zeile
/// zeigt, was „+" bucht**, aus derselben Vorwahl wie das Blatt
/// (`portionsVorwahl`). Das ersetzt „je 100 g". Drei Fälle schrieben das
/// Alte fest und sind umgestellt:
///
/// - 'ohne Portion bleibt „je 100 g" …' heißt jetzt 'ohne Portion: die
///   Gramm vom letzten Mal, nie gebucht 100 g' — zuletzt 60 g gebucht
///   zeigt „60 g" und die kcal von 60 g, nie gebucht „100 g".
/// - 'die Portion in der Tabelle umbenannt …' zeigt jetzt die geänderte
///   Portion, „2 Bonbon (12,2 g)": Genau die wählt das Blatt vor, und
///   genau die bucht „+". Der Schnappschuss (Entscheidung 8) gilt weiter
///   für den gebuchten Eintrag, nicht mehr für diese Zeile — sonst sagte
///   sie etwas anderes, als „+" bucht.
/// - 'bleiben unverändert …' (Online-Treffer) erwartet „100 g" statt
///   „je 100 g". Dass für die Zeilen niemand den Produkt-Endpunkt fragt,
///   bleibt.
///
/// Vom Test-Agenten von #440 umgestellt, Tim hat die Umstellung nicht
/// gesehen.
///
/// Alle Produkte, Namen, Zahlen und Strichcodes sind **erfunden**, alle
/// Zeitpunkte liegen im Jahr 2099.
void main() {
  // Dienstag, 07.04.2099, 18:00 Berliner Zeit (MESZ, +2).
  final jetzt = DateTime.utc(2099, 4, 7, 16);
  const heute = '2099-04-07';

  const barcodeCrispy = '0000000000093';

  const bonsJe100g = Naehrwerte.je100g(kcal: 570, eiweissG: 7.6);
  const haferJe100g = Naehrwerte.je100g(kcal: 372, eiweissG: 13.5);
  const linsenJe100g = Naehrwerte.je100g(kcal: 453, eiweissG: 5);
  const saftJe100g = Naehrwerte.je100g(kcal: 44, eiweissG: 0.5);

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
            'code': barcodeCrispy,
            'product_name': 'Probe-Bons crispy',
            'nutriments': {'energy-kcal_100g': 527, 'proteins_100g': 6},
          },
        ],
      }),
    ),
    200,
    headers: const {'content-type': 'application/json; charset=utf-8'},
  );

  // --- Hilfsmittel ---------------------------------------------------

  ({ProviderContainer container, _Netz netz}) behaelter() {
    final db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);
    final netz = _Netz()..antwort = (_) => suchAntwort();
    // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        appCacheProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => jetzt),
        offClientProvider.overrideWithValue(OffClient(client: netz.client)),
        healthProvider.overrideWithValue(SchreibAttrappe()),
      ],
    );
    addTearDown(container.dispose);
    return (container: container, netz: netz);
  }

  /// Zeigt die Suche und sucht nach „Probe" — eigene Treffer sofort,
  /// online nach der Entprellung.
  Future<void> sucheProbe(WidgetTester tester, ProviderContainer c) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const CupertinoApp(
          home: CupertinoPageScaffold(child: SucheView()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('erfassen-suchfeld')), 'Probe');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
  }

  /// Lässt jede noch laufende Frist verstreichen, damit kein Zeitgeber
  /// über das Testende hinaus hängt.
  Future<void> ausklingen(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 6));
    await tester.pump();
  }

  String textUnter(WidgetTester tester, String key) => tester
      .widgetList<Text>(
        find.descendant(of: find.byKey(Key(key)), matching: find.byType(Text)),
      )
      .map(textOf)
      .join(' ');

  String treffer(WidgetTester tester, int id) =>
      textUnter(tester, 'erfassen-treffer-$id');

  Future<int> legeAn(
    ProviderContainer c,
    String name,
    Naehrwerte je100g, {
    bool fluessig = false,
    List<Portion> portionen = const [],
  }) => c
      .read(lebensmittelRepositoryProvider)
      .legeAn(
        LebensmittelVorlage(name: name, je100g: je100g, fluessig: fluessig),
        portionen: portionen,
      );

  Future<Portion> portion(ProviderContainer c, int id, String name) async =>
      (await c.read(portionenRepositoryProvider).fuer(id))
          .firstWhere((p) => p.name == name);

  Future<void> buche(
    ProviderContainer c, {
    required int id,
    required String name,
    required Naehrwerte je100g,
    required double mengeG,
    Portion? portion,
  }) => c
      .read(ernaehrungRepositoryProvider)
      .buche(
        Eintrag(
          tagesSchluessel: heute,
          mahlzeit: Mahlzeit.snack,
          zeitpunkt: DateTime.utc(2099, 4, 7, 14, 20),
          lebensmittelId: id,
          name: name,
          mengeG: mengeG,
          naehrwerte: je100g.fuerMenge(mengeG),
          portionId: portion?.id,
          portionName: portion?.name,
          portionG: portion?.mengeG,
        ),
      );

  /// „Probe-Bons" mit „Bon" (5,9 g) und „Packung" (225 g), zuerst mit 30 g,
  /// zuletzt mit 2 Bons gebucht.
  Future<({int id, Portion bon})> zweiBons(ProviderContainer c) async {
    final id = await legeAn(
      c,
      'Probe-Bons',
      bonsJe100g,
      portionen: const [
        Portion(name: 'Bon', mengeG: 5.9),
        Portion(name: 'Packung', mengeG: 225),
      ],
    );
    final bon = await portion(c, id, 'Bon');
    await buche(c, id: id, name: 'Probe-Bons', je100g: bonsJe100g, mengeG: 30);
    await buche(
      c,
      id: id,
      name: 'Probe-Bons',
      je100g: bonsJe100g,
      mengeG: 11.8,
      portion: bon,
    );
    return (id: id, bon: bon);
  }

  // ═════════════════════════════════════════════════════════════════════
  group('Die eigene Trefferzeile', () {
    testWidgets('zuletzt mit 2 Bon gebucht: „2 Bon (11,8 g)" und die '
        'Kalorien dieser Menge', (tester) async {
      final b = behaelter();
      final bons = await zweiBons(b.container);

      await sucheProbe(tester, b.container);

      final text = treffer(tester, bons.id);
      expect(text, contains('2 Bon (11,8 g)'));
      expect(text, contains('67 kcal'), reason: '570 kcal × 0,118');
      expect(text, isNot(contains('je 100 g')));
      expect(text, isNot(contains('570')));

      await ausklingen(tester);
    });

    testWidgets('ohne Portion: die Gramm vom letzten Mal, nie gebucht '
        '100 g (V24)', (tester) async {
      final b = behaelter();
      final hafer = await legeAn(
        b.container,
        'Probe-Hafer',
        haferJe100g,
        portionen: const [Portion(name: 'Schale', mengeG: 60)],
      );
      // In g gebucht, obwohl es eine Portion gibt.
      await buche(
        b.container,
        id: hafer,
        name: 'Probe-Hafer',
        je100g: haferJe100g,
        mengeG: 60,
      );
      final linsen = await legeAn(b.container, 'Probe-Linsen', linsenJe100g);

      await sucheProbe(tester, b.container);

      final haferText = treffer(tester, hafer);
      expect(haferText, contains('60 g'));
      expect(haferText, contains('223 kcal'), reason: '372 kcal × 0,6');
      expect(haferText, isNot(contains('je 100 g')));
      expect(haferText, isNot(contains('Schale')));

      final linsenText = treffer(tester, linsen);
      expect(linsenText, contains('100 g'));
      expect(linsenText, isNot(contains('je 100 g')));
      expect(linsenText, contains('453 kcal'));

      await ausklingen(tester);
    });

    testWidgets('ein Getränk: „2 Glas (500 ml)"', (tester) async {
      final b = behaelter();
      final saft = await legeAn(
        b.container,
        'Probe-Saft',
        saftJe100g,
        fluessig: true,
        portionen: const [Portion(name: 'Glas', mengeG: 250)],
      );
      await buche(
        b.container,
        id: saft,
        name: 'Probe-Saft',
        je100g: saftJe100g,
        mengeG: 500,
        portion: await portion(b.container, saft, 'Glas'),
      );

      await sucheProbe(tester, b.container);

      final text = treffer(tester, saft);
      expect(text, contains('2 Glas (500 ml)'));
      expect(text, contains('220 kcal'), reason: '44 kcal × 5');

      await ausklingen(tester);
    });

    testWidgets('die Portion in der Tabelle geändert: Die Zeile nennt sie, '
        'wie das Blatt sie vorwählt und „+" sie bucht (V24)', (tester) async {
      final b = behaelter();
      final bons = await zweiBons(b.container);
      await b.container
          .read(portionenRepositoryProvider)
          .aendere(bons.bon.mit(name: 'Bonbon', mengeG: 6.1));

      await sucheProbe(tester, b.container);

      final text = treffer(tester, bons.id);
      expect(text, contains('2 Bonbon (12,2 g)'));
      expect(text, contains('70 kcal'), reason: '570 kcal × 0,122');
      expect(text, isNot(contains('11,8')));

      await ausklingen(tester);
    });

    testWidgets('danach 3 Bons gebucht: Die Zeile zeigt „3 Bon (17,7 g)"', (
      tester,
    ) async {
      final b = behaelter();
      final bons = await zweiBons(b.container);
      await sucheProbe(tester, b.container);
      expect(treffer(tester, bons.id), contains('2 Bon (11,8 g)'));

      // Der echte Weg: Formular mit Vorwahl (2 Bons), +, buchen.
      final vorlage = (await b.container
          .read(lebensmittelRepositoryProvider)
          .lies(bons.id))!;
      final formular = await b.container
          .read(erfassenProvider.notifier)
          .oeffneFormular(
            vorlage: vorlage,
            tagesSchluessel: heute,
            jetzt: jetzt,
          );
      await b.container.read(erfassenProvider.notifier).buche(formular.plus());
      await tester.pumpAndSettle();

      final text = treffer(tester, bons.id);
      expect(text, contains('3 Bon (17,7 g)'));
      expect(text, contains('101 kcal'), reason: '570 kcal × 0,177');

      await ausklingen(tester);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Online-Treffer', () {
    testWidgets('bleiben unverändert, und für die Zeilen fragt niemand den '
        'Produkt-Endpunkt', (tester) async {
      final b = behaelter();
      await zweiBons(b.container);

      await sucheProbe(tester, b.container);

      final online = textUnter(tester, 'erfassen-off-$barcodeCrispy');
      expect(online, contains('100 g'));
      expect(online, isNot(contains('je 100 g')));
      expect(online, contains('527'));
      expect(online, isNot(contains('Bon (')));

      expect(b.netz.anfragen, isNotEmpty, reason: 'online wurde gesucht');
      expect(
        b.netz.anfragen.where((a) => a.url.path.contains('/product')),
        isEmpty,
        reason:
            'keine Anfrage je Treffer — die Portion der Zeile kommt aus der '
            'eigenen Tabelle (Review-Fokus 2)',
      );

      await ausklingen(tester);
    });
  });
}

/// Ein Netz, das der Test in der Hand hat — dieselbe Form wie in
/// `off_suche_view_test.dart`.
class _Netz {
  final anfragen = <http.Request>[];

  http.Response Function(http.Request anfrage)? antwort;

  late final http.Client client = MockClient((anfrage) {
    anfragen.add(anfrage);
    final sofort = antwort;
    if (sofort != null) return Future.sync(() => sofort(anfrage));
    return Completer<http.Response>().future;
  });
}
