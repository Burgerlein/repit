import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/data/lebensmittel_repository.dart';
import 'package:repit/data/portion.dart';
import 'package:repit/data/portionen_repository.dart';
import 'package:repit/ernaehrung/off_client.dart';
import 'package:repit/ernaehrung/portions_abruf.dart';
import 'package:repit/health/health_provider.dart';

/// Tests für den **Abruf der Portionen beim Antippen** (#398, unter #325)
/// — welcher Treffer fragt, wie oft gefragt wird und was eine Antwort
/// hinterlässt.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung**
/// (`CLAUDE.md`). Diese Datei darf ausgeführt, aber nicht verändert
/// werden.
///
/// Geschrieben nach Task 6 des Plans
/// `docs/superpowers/plans/2026-11-05-portionen.md` und der Spec
/// `docs/superpowers/specs/2026-11-05-portionen-design.md` (Abschnitte
/// „Abruf beim Antippen", „Befund" mit der Ratenbegrenzung, V3, V4) —
/// **ohne** den Code von `portions_abruf.dart` gesehen zu haben (es gab ihn
/// beim Schreiben noch nicht). Netz gibt es im Test keins: Open Food Facts
/// antwortet über einen `MockClient`, der jede Anfrage zählt.
///
/// ## Was diese Tests verbindlich vorgeben (aus dem Plan)
///
/// ```dart
/// // lib/ernaehrung/portions_abruf.dart
/// @immutable
/// class PortionsQuelle {                       // == und hashCode
///   const PortionsQuelle({required String barcode, int? lebensmittelId});
/// }
///
/// sealed class PortionsAbruf {}                // == und hashCode
/// // AbrufLaeuft
/// // AbrufFertig({required List<Portion> portionen, required bool fluessig})
/// // AbrufGescheitert
///
/// final portionsAbrufProvider = NotifierProvider.autoDispose
///     .family<PortionsAbrufNotifier, PortionsAbruf, PortionsQuelle>(…);
///
/// PortionsQuelle? brauchtAbruf(LebensmittelVorlage v);
/// ```
///
/// - **`brauchtAbruf`** kennt genau die zwei Fälle der Spec-Tabelle:
///   Online-Treffer, noch nicht in der eigenen Tabelle (`id == null`,
///   Herkunft `off`, `offPortionen == null`), und ein schon übernommenes
///   Produkt ohne Nachfrage (`id != null`, Herkunft `off`, Strichcode da,
///   `portionenAbgefragtAm == null`). Sonst `null`.
/// - **`build()` gibt `AbrufLaeuft`** und stößt **genau eine**
///   `OffClient.produktZuBarcode` an. `Treffer` und `NichtGefunden` werden
///   `AbrufFertig` (bei `NichtGefunden` mit `[]`), `KeinNetz` wird
///   `AbrufGescheitert` (V4).
/// - **Mit `lebensmittelId`** ruft der Notifier nach einer Antwort
///   `trageOffPortionenNach` und liefert die Portionen **aus der Tabelle**.
/// - **`autoDispose` ist Pflicht:** „eine je Öffnen" heißt, dass ein neues
///   Öffnen neu fragt. Zwei Leser desselben Blatts fragen einmal.
///
/// ## Festlegungen des Test-Agenten — nicht von Tim freigegeben
///
/// - **Der Zeitpunkt der Nachfrage ist `clockProvider`.**
///   `portionen_abgefragt_am` steht danach auf genau dem Zeitpunkt, den die
///   Uhr der App liefert — derselbe Weg wie `buche` mit `jetzt: clock()`.
/// - **Ein Online-Treffer schreibt nichts**, auch nicht nach einer Antwort.
///   V3 sagt, seine Portionen leben im Blatt; ein Abruf, der das Produkt
///   schon beim Antippen anlegte, füllte die eigene Suche mit allem, was
///   Tim angesehen und nicht gegessen hat (#284).
/// - **HTTP 429 ist `AbrufGescheitert`**, wie jeder andere Fehler außer
///   404. Das ist die „bekannte Lücke" der Spec (Wortlaut „kein Netz"), hier
///   nur in ihrer Folge geprüft: nicht nachgesehen, keine Marke.
/// - **Keine Wiederholung im Blatt** wird über die Zahl der Anfragen
///   geprüft, nachdem der Abruf gescheitert ist und der Leser weiter
///   zuhört.
/// - **Ein neuer Abruf beginnt mit `AbrufLaeuft`**, nicht mit dem Ergebnis
///   des vorigen Öffnens. Ein Zwischenspeicher über das Blatt hinaus wäre
///   genau das, was die Spec ausschließt.
///
/// Alle Produkte, Namen, Zahlen und Strichcodes sind **erfunden**, alle
/// Zeitpunkte liegen im Jahr 2099. Die Feldform der Antworten ist die des
/// Strichcode-Endpunkts, die Werte sind es nicht.
void main() {
  final jetzt = DateTime.utc(2099, 4, 7, 10, 30);
  final frueher = DateTime.utc(2099, 3, 1, 8);

  const barcodeJoghurt = '0000000000062';
  const barcodeSaft = '0000000000079';

  const joghurtJe100g = Naehrwerte.je100g(
    kcal: 64,
    eiweissG: 10.5,
    kohlenhydrateG: 4,
    fettG: 0.3,
  );

  const portion150 = Portion(
    name: 'Portion',
    mengeG: 150,
    herkunft: Herkunft.off,
  );
  const packung500 = Portion(
    name: 'Packung',
    mengeG: 500,
    herkunft: Herkunft.off,
  );

  // --- Antworten von Open Food Facts --------------------------------

  /// Ein Produkt am Strichcode-Endpunkt mit Portion und Packung.
  Map<String, Object?> produktAntwort({
    String code = barcodeJoghurt,
    num portion = 150,
    num packung = 500,
    String einheit = 'g',
  }) => {
    'code': code,
    'status': 1,
    'status_verbose': 'product found',
    'product': {
      'code': code,
      'product_name': 'Prüf-Skyr Erfundenwerk',
      'brands': 'Erfundenwerk',
      'nutriments': {
        'energy-kcal_100g': 64,
        'proteins_100g': 10.5,
        'carbohydrates_100g': 4,
        'fat_100g': 0.3,
      },
      'serving_quantity': portion,
      'serving_quantity_unit': einheit,
      'product_quantity': packung,
      'product_quantity_unit': einheit,
    },
  };

  http.Response json(Object? koerper, {int status = 200}) =>
      http.Response.bytes(
        utf8.encode(jsonEncode(koerper)),
        status,
        headers: const {'content-type': 'application/json; charset=utf-8'},
      );

  // --- Hilfsmittel ---------------------------------------------------

  /// Ein Behälter mit echter Datenbank im Speicher, fester Uhr und einem
  /// Open Food Facts, das jede Anfrage mitschreibt und mit [antwort]
  /// beantwortet. Wiederholung aus (`CLAUDE.md`, „Tests").
  ({ProviderContainer container, AppCache db, List<http.Request> anfragen})
  behaelter(FutureOr<http.Response> Function(http.Request) antwort) {
    final db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);
    final anfragen = <http.Request>[];
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        appCacheProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => jetzt),
        offClientProvider.overrideWithValue(
          OffClient(
            client: MockClient((anfrage) async {
              anfragen.add(anfrage);
              return antwort(anfrage);
            }),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    return (container: container, db: db, anfragen: anfragen);
  }

  /// Öffnet das Blatt für [quelle]: ein Leser, der zuhört, bis der Abruf
  /// nicht mehr läuft. Das Abonnement schließt der Fall selbst — das
  /// Schließen **ist** in manchen Fällen der Gegenstand.
  ({ProviderSubscription<PortionsAbruf> abo, Future<PortionsAbruf> ergebnis})
  oeffne(ProviderContainer container, PortionsQuelle quelle) {
    final fertig = Completer<PortionsAbruf>();
    final abo = container.listen<PortionsAbruf>(portionsAbrufProvider(quelle), (
      _,
      neu,
    ) {
      if (neu is! AbrufLaeuft && !fertig.isCompleted) fertig.complete(neu);
    }, fireImmediately: true);
    return (
      abo: abo,
      ergebnis: fertig.future.timeout(const Duration(seconds: 5)),
    );
  }

  /// Öffnen, Ergebnis abwarten, Blatt wieder schließen.
  Future<PortionsAbruf> abruf(
    ProviderContainer container,
    PortionsQuelle quelle,
  ) async {
    final o = oeffne(container, quelle);
    try {
      return await o.ergebnis;
    } finally {
      o.abo.close();
    }
  }

  /// Ein schon übernommenes Produkt, wie es vor #325 in die Tabelle kam:
  /// Herkunft `off`, Strichcode, **noch nie nach Portionen gefragt**.
  Future<int> uebernommen(AppCache db, {List<Portion> portionen = const []}) =>
      LebensmittelRepository(db).legeAn(
        const LebensmittelVorlage(
          name: 'Prüf-Skyr Erfundenwerk',
          je100g: joghurtJe100g,
          barcode: barcodeJoghurt,
          herkunft: Herkunft.off,
        ),
        portionen: portionen,
      );

  Future<int> zeilenIn(AppCache db, String tabelle) async {
    final zeile = await db
        .customSelect('SELECT COUNT(*) AS n FROM $tabelle')
        .getSingle();
    return zeile.read<int>('n');
  }

  // ═════════════════════════════════════════════════════════════════════
  group('brauchtAbruf — nur die zwei Fälle der Spec', () {
    test('ein Online-Treffer ohne abgefragte Portionen fragt — ohne '
        'Lebensmittel-ID', () {
      const treffer = LebensmittelVorlage(
        name: 'Prüf-Skyr Erfundenwerk',
        je100g: joghurtJe100g,
        barcode: barcodeJoghurt,
        herkunft: Herkunft.off,
      );

      final quelle = brauchtAbruf(treffer);

      expect(quelle, isNotNull);
      expect(quelle, const PortionsQuelle(barcode: barcodeJoghurt));
    });

    test('ein gescanntes Produkt fragt nicht — seine Antwort kam mit dem '
        'Scan, auch wenn sie „keine" lautete', () {
      const gescannt = LebensmittelVorlage(
        name: 'Prüf-Skyr Erfundenwerk',
        je100g: joghurtJe100g,
        barcode: barcodeJoghurt,
        herkunft: Herkunft.off,
        offPortionen: [],
      );
      const gescanntMitPortionen = LebensmittelVorlage(
        name: 'Prüf-Skyr Erfundenwerk',
        je100g: joghurtJe100g,
        barcode: barcodeJoghurt,
        herkunft: Herkunft.off,
        offPortionen: [portion150, packung500],
      );

      expect(brauchtAbruf(gescannt), isNull);
      expect(brauchtAbruf(gescanntMitPortionen), isNull);
    });

    test('ein eigenes Lebensmittel fragt nicht', () {
      const eigenes = LebensmittelVorlage(
        id: 3,
        name: 'Prüf-Müsli',
        je100g: Naehrwerte.je100g(kcal: 380),
      );
      const eigenesMitStrichcode = LebensmittelVorlage(
        id: 4,
        name: 'Prüf-Müsli abgeschrieben',
        je100g: Naehrwerte.je100g(kcal: 380),
        barcode: barcodeSaft,
      );

      expect(brauchtAbruf(eigenes), isNull);
      // Herkunft `eigen`, auch mit Strichcode: Tim hat die Werte von der
      // Packung abgeschrieben. Open Food Facts wird dazu nicht gefragt.
      expect(brauchtAbruf(eigenesMitStrichcode), isNull);
    });

    test('ein übernommenes Produkt, das schon gefragt wurde, fragt nicht '
        'wieder', () {
      final schonGefragt = LebensmittelVorlage(
        id: 9,
        name: 'Prüf-Skyr Erfundenwerk',
        je100g: joghurtJe100g,
        barcode: barcodeJoghurt,
        herkunft: Herkunft.off,
        portionenAbgefragtAm: frueher,
      );

      expect(brauchtAbruf(schonGefragt), isNull);
    });

    test('ein übernommenes Produkt ohne Nachfrage fragt einmal — mit '
        'seiner ID', () {
      const nieGefragt = LebensmittelVorlage(
        id: 9,
        name: 'Prüf-Skyr Erfundenwerk',
        je100g: joghurtJe100g,
        barcode: barcodeJoghurt,
        herkunft: Herkunft.off,
      );

      expect(
        brauchtAbruf(nieGefragt),
        const PortionsQuelle(barcode: barcodeJoghurt, lebensmittelId: 9),
      );
    });

    test('ein übernommenes Produkt ohne Strichcode fragt nicht — es gibt '
        'nichts, wonach zu fragen wäre', () {
      const ohneStrichcode = LebensmittelVorlage(
        id: 9,
        name: 'Prüf-Skyr Erfundenwerk',
        je100g: joghurtJe100g,
        herkunft: Herkunft.off,
      );

      expect(brauchtAbruf(ohneStrichcode), isNull);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('PortionsQuelle ist ein Werttyp', () {
    test('gleicher Strichcode und gleiche ID sind gleich — auch als zwei '
        'getrennt gebaute Objekte', () {
      // Bewusst nicht `const`: Zwei `const`-Ausdrücke wären dasselbe
      // Objekt und bewiesen nichts über `==`.
      final a = PortionsQuelle(barcode: barcodeJoghurt, lebensmittelId: 9);
      final b = PortionsQuelle(barcode: barcodeJoghurt, lebensmittelId: 9);

      expect(identical(a, b), isFalse);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('ein anderer Strichcode oder eine andere ID ist eine andere '
        'Quelle', () {
      expect(
        PortionsQuelle(barcode: barcodeJoghurt),
        isNot(PortionsQuelle(barcode: barcodeSaft)),
      );
      expect(
        PortionsQuelle(barcode: barcodeJoghurt),
        isNot(PortionsQuelle(barcode: barcodeJoghurt, lebensmittelId: 9)),
      );
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Eine Anfrage je Öffnen — nicht mehr', () {
    test('beim Öffnen läuft der Abruf, und gefragt wird der '
        'Strichcode-Endpunkt — nicht die Suche', () async {
      final b = behaelter((_) => json(produktAntwort()));

      final o = oeffne(
        b.container,
        const PortionsQuelle(barcode: barcodeJoghurt),
      );
      addTearDown(o.abo.close);

      expect(o.abo.read(), isA<AbrufLaeuft>());
      await o.ergebnis;

      expect(b.anfragen, hasLength(1));
      expect(b.anfragen.single.url.host, 'world.openfoodfacts.org');
      expect(
        b.anfragen.single.url.path,
        '/api/v2/product/$barcodeJoghurt.json',
      );
    });

    test('zwei Leser desselben Blatts ergeben eine Anfrage', () async {
      final b = behaelter((_) => json(produktAntwort()));

      // Zwei getrennt gebaute, gleiche Quellen — so, wie zwei Widgets
      // desselben Blatts sie je für sich aus der Vorlage bauen.
      final erster = oeffne(
        b.container,
        PortionsQuelle(barcode: barcodeJoghurt),
      );
      final zweiter = oeffne(
        b.container,
        PortionsQuelle(barcode: barcodeJoghurt),
      );
      addTearDown(erster.abo.close);
      addTearDown(zweiter.abo.close);

      final a = await erster.ergebnis;
      final c = await zweiter.ergebnis;

      expect(b.anfragen, hasLength(1));
      expect(a, c);
    });

    test('schließen und neu öffnen fragt ein zweites Mal — kein '
        'Zwischenspeicher über das Blatt hinaus', () async {
      final b = behaelter((_) => json(produktAntwort()));
      const quelle = PortionsQuelle(barcode: barcodeJoghurt);

      await abruf(b.container, quelle);
      expect(b.anfragen, hasLength(1));

      // Kein Leser mehr — `autoDispose` räumt den Abruf weg.
      await b.container.pump();

      final wieder = oeffne(b.container, quelle);
      addTearDown(wieder.abo.close);

      // Ein neues Öffnen beginnt von vorn, nicht mit dem alten Ergebnis.
      expect(wieder.abo.read(), isA<AbrufLaeuft>());
      await wieder.ergebnis;
      expect(b.anfragen, hasLength(2));
    });

    test('ein gescheiterter Abruf wird im Blatt nicht wiederholt', () async {
      final b = behaelter((_) => http.Response('Wartung', 503));

      final o = oeffne(
        b.container,
        const PortionsQuelle(barcode: barcodeJoghurt),
      );
      addTearDown(o.abo.close);

      expect(await o.ergebnis, isA<AbrufGescheitert>());

      // Das Blatt bleibt offen. Was hier noch käme, wäre eine Wiederholung.
      for (var i = 0; i < 5; i++) {
        await b.container.pump();
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(b.anfragen, hasLength(1));
      expect(o.abo.read(), isA<AbrufGescheitert>());
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Online-Treffer — die Portionen leben im Blatt (V3)', () {
    test('ein Treffer ergibt AbrufFertig mit Portion und Packung aus der '
        'Antwort', () async {
      final b = behaelter((_) => json(produktAntwort()));

      final ergebnis = await abruf(
        b.container,
        const PortionsQuelle(barcode: barcodeJoghurt),
      );

      expect(
        ergebnis,
        AbrufFertig(portionen: const [portion150, packung500], fluessig: false),
      );
    });

    test('Einheit ml ergibt fluessig: true', () async {
      final b = behaelter(
        (_) => json(
          produktAntwort(
            code: barcodeSaft,
            portion: 250,
            packung: 1000,
            einheit: 'ml',
          ),
        ),
      );

      final ergebnis = await abruf(
        b.container,
        const PortionsQuelle(barcode: barcodeSaft),
      );

      expect(ergebnis, isA<AbrufFertig>());
      final fertig = ergebnis as AbrufFertig;
      expect(fertig.fluessig, isTrue);
      expect(fertig.portionen.map((p) => p.mengeG), [250, 1000]);
    });

    test(
      'nicht gefunden (404) ergibt AbrufFertig mit [] — gefragt, keine',
      () async {
        final b = behaelter((_) => json({'status': 0}, status: 404));

        final ergebnis = await abruf(
          b.container,
          const PortionsQuelle(barcode: barcodeJoghurt),
        );

        expect(ergebnis, AbrufFertig(portionen: const [], fluessig: false));
      },
    );

    test(
      'nicht gefunden (status 0) ergibt ebenfalls AbrufFertig mit []',
      () async {
        final b = behaelter((_) => json({'code': barcodeJoghurt, 'status': 0}));

        final ergebnis = await abruf(
          b.container,
          const PortionsQuelle(barcode: barcodeJoghurt),
        );

        expect(ergebnis, isA<AbrufFertig>());
        expect((ergebnis as AbrufFertig).portionen, isEmpty);
      },
    );

    test('kein Netz ergibt AbrufGescheitert — nicht „keine Portion"', () async {
      final b = behaelter(
        (_) => throw http.ClientException('keine Verbindung'),
      );

      final ergebnis = await abruf(
        b.container,
        const PortionsQuelle(barcode: barcodeJoghurt),
      );

      expect(ergebnis, isA<AbrufGescheitert>());
    });

    test('HTTP 429 (Ratenbegrenzung) ergibt AbrufGescheitert', () async {
      final b = behaelter((_) => http.Response('Too Many Requests', 429));

      final ergebnis = await abruf(
        b.container,
        const PortionsQuelle(barcode: barcodeJoghurt),
      );

      expect(ergebnis, isA<AbrufGescheitert>());
    });

    test('ein nur geöffneter Online-Treffer hinterlässt keine Zeile in '
        'lebensmittel oder portionen', () async {
      final b = behaelter((_) => json(produktAntwort()));

      await abruf(b.container, const PortionsQuelle(barcode: barcodeJoghurt));
      await b.container.pump();

      expect(await zeilenIn(b.db, 'lebensmittel'), 0);
      expect(await zeilenIn(b.db, 'portionen'), 0);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Übernommenes Produkt — die einmalige Nachfrage (Entscheidung 6, '
      'V4, V5)', () {
    test('ein Treffer schreibt die Portionen in die Tabelle, setzt die '
        'Marke und liefert die Zeilen aus der Tabelle', () async {
      final b = behaelter((_) => json(produktAntwort()));
      final id = await uebernommen(b.db);

      final ergebnis = await abruf(
        b.container,
        PortionsQuelle(barcode: barcodeJoghurt, lebensmittelId: id),
      );

      final ausTabelle = await PortionenRepository(b.db).fuer(id);
      expect(ausTabelle.map((p) => p.name), ['Portion', 'Packung']);
      expect(ausTabelle.every((p) => p.id != null), isTrue);
      expect(ausTabelle.every((p) => p.herkunft == Herkunft.off), isTrue);

      expect(ergebnis, isA<AbrufFertig>());
      // Aus der Tabelle, nicht aus der Antwort — mit Schlüsseln, damit
      // eine gewählte Portion beim Buchen ihre `portion_id` hat.
      expect((ergebnis as AbrufFertig).portionen, ausTabelle);

      final danach = await LebensmittelRepository(b.db).lies(id);
      expect(danach!.portionenAbgefragtAm, jetzt);
    });

    test('eigene Portionen, die schon in der Tabelle stehen, kommen im '
        'Ergebnis mit', () async {
      final b = behaelter((_) => json(produktAntwort()));
      final id = await uebernommen(
        b.db,
        portionen: const [Portion(name: 'Löffel', mengeG: 15)],
      );

      final ergebnis = await abruf(
        b.container,
        PortionsQuelle(barcode: barcodeJoghurt, lebensmittelId: id),
      );

      expect(ergebnis, isA<AbrufFertig>());
      expect((ergebnis as AbrufFertig).portionen.map((p) => p.name), [
        'Löffel',
        'Portion',
        'Packung',
      ]);
      expect(ergebnis.portionen, await PortionenRepository(b.db).fuer(id));
    });

    test('nicht gefunden ergibt AbrufFertig mit [] und setzt die Marke — '
        'gefragt ist gefragt', () async {
      final b = behaelter((_) => json({'status': 0}, status: 404));
      final id = await uebernommen(b.db);

      final ergebnis = await abruf(
        b.container,
        PortionsQuelle(barcode: barcodeJoghurt, lebensmittelId: id),
      );

      expect(ergebnis, isA<AbrufFertig>());
      expect((ergebnis as AbrufFertig).portionen, isEmpty);
      expect(await zeilenIn(b.db, 'portionen'), 0);

      final danach = await LebensmittelRepository(b.db).lies(id);
      expect(danach!.portionenAbgefragtAm, jetzt);
    });

    test('kein Netz ergibt AbrufGescheitert, und die Marke bleibt null — '
        'das nächste Öffnen fragt wieder', () async {
      final b = behaelter(
        (_) => throw http.ClientException('keine Verbindung'),
      );
      final id = await uebernommen(b.db);

      final ergebnis = await abruf(
        b.container,
        PortionsQuelle(barcode: barcodeJoghurt, lebensmittelId: id),
      );

      expect(ergebnis, isA<AbrufGescheitert>());
      expect(await zeilenIn(b.db, 'portionen'), 0);

      final danach = await LebensmittelRepository(b.db).lies(id);
      expect(danach!.portionenAbgefragtAm, isNull);
      expect(brauchtAbruf(danach), isNotNull);
    });

    test('HTTP 429 setzt die Marke ebenfalls nicht', () async {
      final b = behaelter((_) => http.Response('Too Many Requests', 429));
      final id = await uebernommen(b.db);

      final ergebnis = await abruf(
        b.container,
        PortionsQuelle(barcode: barcodeJoghurt, lebensmittelId: id),
      );

      expect(ergebnis, isA<AbrufGescheitert>());
      final danach = await LebensmittelRepository(b.db).lies(id);
      expect(danach!.portionenAbgefragtAm, isNull);
    });

    test('nach der Antwort braucht das Produkt keinen Abruf mehr', () async {
      final b = behaelter((_) => json(produktAntwort()));
      final id = await uebernommen(b.db);

      await abruf(
        b.container,
        PortionsQuelle(barcode: barcodeJoghurt, lebensmittelId: id),
      );

      final danach = await LebensmittelRepository(b.db).lies(id);
      expect(brauchtAbruf(danach!), isNull);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('PortionsAbruf ist ein Werttyp', () {
    test('zwei AbrufFertig mit gleichen Portionen sind gleich', () {
      expect(
        AbrufFertig(portionen: const [portion150], fluessig: false),
        AbrufFertig(portionen: const [portion150], fluessig: false),
      );
      expect(
        AbrufFertig(portionen: const [portion150], fluessig: false).hashCode,
        AbrufFertig(portionen: const [portion150], fluessig: false).hashCode,
      );
    });

    test('andere Portionen oder anderes fluessig sind ungleich', () {
      expect(
        AbrufFertig(portionen: const [portion150], fluessig: false),
        isNot(AbrufFertig(portionen: const [packung500], fluessig: false)),
      );
      expect(
        AbrufFertig(portionen: const [portion150], fluessig: false),
        isNot(AbrufFertig(portionen: const [portion150], fluessig: true)),
      );
    });
  });
}
