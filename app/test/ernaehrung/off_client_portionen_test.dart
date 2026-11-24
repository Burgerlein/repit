import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/lebensmittel_repository.dart';
import 'package:repit/data/portion.dart';
import 'package:repit/ernaehrung/off_client.dart';

/// Tests für **Portion und Packung aus Open Food Facts** (#325, Karte
/// #395, Plan `docs/superpowers/plans/2026-11-05-portionen.md`, Task 3) —
/// gegen einen eingesetzten `http.Client`, **ohne Netz im Test**.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung**
/// (`CLAUDE.md`). Diese Datei darf ausgeführt, aber nicht verändert
/// werden. Die heutigen Fälle in `off_client_test.dart` bleiben, wie sie
/// sind, und müssen grün bleiben.
///
/// ## Was diese Tests verbindlich vorgeben
///
/// Aus dem Plan, Task 3, „Interfaces":
///
/// ```dart
/// // lib/data/portion.dart
/// @immutable
/// class Portion {
///   const Portion({int? id, required String name, required double mengeG,
///       Herkunft herkunft = Herkunft.eigen});
///   Portion mit({String? name, double? mengeG});
///   // id == null heißt „noch nicht gespeichert"; == und hashCode
/// }
///
/// // OffProdukt bekommt, beide in == und hashCode:
/// final List<Portion>? portionen;   // Vorgabe null
/// final bool fluessig;              // Vorgabe false
///
/// // LebensmittelVorlage bekommt, in == und hashCode:
/// final List<Portion>? offPortionen; // Vorgabe null
///
/// // OffProdukt.alsVorlage() gibt fluessig und offPortionen: portionen
/// // weiter.
/// ```
///
/// ## Woher die Regeln kommen
///
/// Spec `docs/superpowers/specs/2026-11-05-portionen-design.md`,
/// Abschnitte „Übernahme" und „Befund". Tims Entscheidungen vom
/// 05.11.2026, hier berührt:
///
/// - **E1:** Portionen aus Open Food Facts heißen fest **„Portion"** und
///   **„Packung"**. `serving_size` wird nicht gelesen.
/// - **E3, E4, V1, V2:** welche Angabe eine Portion wird — gerechnet im
///   Kern (`offPortionen`, geprüft in
///   `Packages/trainings_core/test/portionen_test.dart`). Hier steht nur,
///   **dass** der Client die Kernregel benutzt, an je einem Fall.
/// - **E4:** Den Freitext `quantity` liest die App nie selbst.
/// - **E10:** `fluessig`, wenn `product_quantity_unit` oder
///   `serving_quantity_unit` gleich `ml` ist.
/// - **`portionen == null` heißt „nicht abgefragt"** (Suchtreffer),
///   **`[]` heißt „gefragt, keine"**. Die beiden werden nicht vermischt —
///   aus demselben Grund, aus dem ein fehlender Messwert nicht `0` ist.
///   Ein Suchtreffer, der als „keine Portion bekannt" erschiene, wäre
///   `01` im Wähler (Plan, Review Focus 1).
/// - **Die Suche bleibt, wie sie ist.** Ihr Index kennt die Felder nicht
///   (Befund), und der Suchpfad baut `OffProdukt` mit `portionen: null`
///   (Plan, Task 3, Step 3).
///
/// ## Festlegungen des Test-Agenten — nicht von Tim freigegeben
///
/// - **Ein Suchtreffer hat `portionen == null`, auch wenn seine Antwort
///   die vier Felder zufällig doch trägt.** Der Plan sagt „Der Suchpfad
///   baut `OffProdukt` mit `portionen: null`" ohne Ausnahme; ein Treffer,
///   der mal `null` und mal eine Liste hätte, je nachdem, was der Index
///   gerade liefert, machte den Abruf beim Antippen unvorhersagbar.
/// - **„Unlesbar"** heißt hier: ein Text, der keine Zahl ist (`"etwa
///   6"`, `""`), oder ein JSON-`null`. Unlesbare Mengen sind keine
///   Angabe und reißen die jeweils andere nicht mit.
/// - **Das gefundene Produkt bleibt ein Treffer**, auch wenn alle vier
///   Felder unlesbar sind — die Nährwerte sind ja da. Dann eben mit
///   `portionen == []`.
/// - **Ob `id` in `Portion.==` eingeht, legt diese Datei nicht fest.**
///   Geprüft wird nur, dass alle Portionen aus OFF `id == null` tragen.
/// - **Der Strichcode-Endpunkt fragt `quantity` und `serving_size` nicht
///   an.** E1 und E4 sagen „wird nie gelesen"; was nicht angefragt ist,
///   kann auch nicht versehentlich gelesen werden. Plan, Task 3, Step 3:
///   `_produktFelder` ist `_felder` plus die vier.
///
/// Alle Produkte, Namen und Strichcodes sind **erfunden**. Die
/// Strichcodes beginnen mit lauter Nullen. Die Feldform ist die echte des
/// Endpunkts `/api/v2/product/<ean>.json` — die Werte sind es nicht.
void main() {
  const barcodeKekse = '0000000000048';
  const barcodeSaft = '0000000000055';

  const vierFelder = [
    'serving_quantity',
    'serving_quantity_unit',
    'product_quantity',
    'product_quantity_unit',
  ];

  const naehrwerte = <String, Object?>{
    'energy-kcal_100g': 512,
    'proteins_100g': 7.5,
    'carbohydrates_100g': 58,
    'fat_100g': 27,
    'sugars_100g': 41,
    'saturated-fat_100g': 14,
    'fiber_100g': 2.5,
  };

  /// Ein Produkt am Strichcode-Endpunkt — die vier Portionsfelder nur,
  /// wenn übergeben. Dazu auf Wunsch die Freitexte `quantity` und
  /// `serving_size`, die der Client **nicht** lesen darf.
  Map<String, Object?> produkt({
    String code = barcodeKekse,
    String name = 'Prüfkekse Erfundenwerk',
    Map<String, Object?> felder = const {},
  }) => {
    'code': code,
    'product_name': name,
    'brands': 'Erfundenwerk',
    'nutriments': naehrwerte,
    ...felder,
  };

  Map<String, Object?> produktAntwort(Map<String, Object?> p) => {
    'code': p['code'],
    'status': 1,
    'status_verbose': 'product found',
    'product': p,
  };

  /// Die Antwort von `search.openfoodfacts.org/search`: Treffer unter
  /// `hits`, `brands` als Liste.
  Map<String, Object?> suchAntwort(List<Map<String, Object?>> hits) => {
    'count': hits.length,
    'is_count_exact': true,
    'page': 1,
    'page_count': 1,
    'page_size': 50,
    'timed_out': false,
    'hits': hits,
  };

  /// Eine JSON-Antwort, als UTF-8 kodiert — so, wie Open Food Facts sie
  /// schickt.
  http.Response json(Object? koerper, {int status = 200}) =>
      http.Response.bytes(
        utf8.encode(jsonEncode(koerper)),
        status,
        headers: const {'content-type': 'application/json; charset=utf-8'},
      );

  /// Ein Client, der jede Anfrage mitschreibt und mit [antwort] beantwortet.
  ({OffClient client, List<http.Request> anfragen}) mit(
    FutureOr<http.Response> Function(http.Request anfrage) antwort,
  ) {
    final anfragen = <http.Request>[];
    final client = OffClient(
      client: MockClient((anfrage) async {
        anfragen.add(anfrage);
        return antwort(anfrage);
      }),
    );
    return (client: client, anfragen: anfragen);
  }

  OffProdukt einziges(OffErgebnis ergebnis) {
    expect(ergebnis, isA<Treffer>());
    final produkte = (ergebnis as Treffer).produkte;
    expect(produkte, hasLength(1));
    return produkte.single;
  }

  /// Fragt den Strichcode-Endpunkt mit einem Produkt, das [felder] trägt.
  Future<OffProdukt> amStrichcode(
    Map<String, Object?> felder, {
    String code = barcodeKekse,
  }) async {
    final c = mit(
      (_) => json(produktAntwort(produkt(code: code, felder: felder))),
    );
    return einziges(await c.client.produktZuBarcode(code));
  }

  Set<String> felderDer(http.Request anfrage) => {
    for (final f in (anfrage.url.queryParameters['fields'] ?? '').split(','))
      if (f.trim().isNotEmpty) f.trim(),
  };

  const portion58 = Portion(
    name: 'Portion',
    mengeG: 5.8,
    herkunft: Herkunft.off,
  );
  const packung225 = Portion(
    name: 'Packung',
    mengeG: 225,
    herkunft: Herkunft.off,
  );

  // ═════════════════════════════════════════════════════════════════════
  group('Was angefragt wird', () {
    test('der Strichcode-Endpunkt fragt die vier Portionsfelder ab', () async {
      final c = mit((_) => json(produktAntwort(produkt())));

      await c.client.produktZuBarcode(barcodeKekse);

      expect(c.anfragen, hasLength(1));
      final felder = felderDer(c.anfragen.single);
      expect(
        felder,
        containsAll(vierFelder),
        reason:
            'was der Client liest, muss er anfordern — '
            'gefunden: ${c.anfragen.single.url}',
      );
      expect(
        felder,
        containsAll(const [
          'code',
          'product_name',
          'product_name_de',
          'brands',
          'nutriments',
        ]),
        reason: 'die bisherigen Felder bleiben dabei',
      );
    });

    test('der Strichcode-Endpunkt fragt keine Freitexte ab', () async {
      final c = mit((_) => json(produktAntwort(produkt())));

      await c.client.produktZuBarcode(barcodeKekse);

      final felder = felderDer(c.anfragen.single);
      expect(
        felder,
        isNot(anyOf(contains('quantity'), contains('serving_size'))),
        reason: 'E1, E4: `quantity` und `serving_size` liest die App nie',
      );
    });

    test('die Suche fragt die vier Felder nicht ab', () async {
      final c = mit((_) => json(suchAntwort(const [])));

      await c.client.suche('Prüfkekse');

      expect(c.anfragen, hasLength(1));
      final felder = felderDer(c.anfragen.single);
      for (final f in vierFelder) {
        expect(
          felder,
          isNot(contains(f)),
          reason:
              'der Suchindex kennt `$f` nicht (Spec, Befund) — '
              'die Suche bleibt, wie sie ist',
        );
      }
    });

    test('genau eine Anfrage je Strichcode, auch mit Portionen', () async {
      final c = mit(
        (_) => json(
          produktAntwort(
            produkt(
              felder: const {
                'serving_quantity': 5.8,
                'serving_quantity_unit': 'g',
                'product_quantity': 225,
                'product_quantity_unit': 'g',
              },
            ),
          ),
        ),
      );

      await c.client.produktZuBarcode(barcodeKekse);

      expect(
        c.anfragen,
        hasLength(1),
        reason:
            'der Endpunkt antwortet nach etwa 20 schnellen Anfragen mit '
            'HTTP 429 — Portionen kommen mit derselben Antwort',
      );
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Portion und Packung am Strichcode', () {
    test('Portion 5,8 g und Packung 225 g → zwei Portionen aus OFF', () async {
      final p = await amStrichcode(const {
        'serving_quantity': 5.8,
        'serving_quantity_unit': 'g',
        'product_quantity': 225,
        'product_quantity_unit': 'g',
      });

      expect(p.portionen, const [portion58, packung225]);
      expect(p.fluessig, isFalse);
    });

    test('Namen sind fest „Portion" und „Packung", Herkunft off', () async {
      final p = await amStrichcode(const {
        'serving_quantity': 5.8,
        'serving_quantity_unit': 'g',
        'serving_size': '1 Keks (5,8 g)',
        'product_quantity': 225,
        'product_quantity_unit': 'g',
      });

      expect(p.portionen!.map((x) => x.name), [
        'Portion',
        'Packung',
      ], reason: 'E1: ein Wort aus `serving_size` wird nicht gelesen');
      expect(p.portionen!.map((x) => x.herkunft), [Herkunft.off, Herkunft.off]);
    });

    test('Portionen aus OFF haben keine id', () async {
      final p = await amStrichcode(const {
        'serving_quantity': 5.8,
        'serving_quantity_unit': 'g',
        'product_quantity': 225,
        'product_quantity_unit': 'g',
      });

      expect(p.portionen, hasLength(2));
      for (final x in p.portionen!) {
        expect(x.id, isNull, reason: 'noch nicht gespeichert');
      }
    });

    test('Zahlen als Text werden gelesen', () async {
      final p = await amStrichcode(const {
        'serving_quantity': '5.8',
        'serving_quantity_unit': 'g',
        'product_quantity': '225',
        'product_quantity_unit': 'g',
      });

      expect(p.portionen, const [portion58, packung225]);
    });

    test(
      'unlesbare Portionsmenge ist keine Angabe, die Packung bleibt',
      () async {
        final p = await amStrichcode(const {
          'serving_quantity': 'etwa 6',
          'serving_quantity_unit': 'g',
          'product_quantity': '225',
          'product_quantity_unit': 'g',
        });

        expect(p.portionen, const [packung225]);
      },
    );

    test(
      'unlesbare Packungsmenge ist keine Angabe, die Portion bleibt',
      () async {
        final p = await amStrichcode(const {
          'serving_quantity': 5.8,
          'serving_quantity_unit': 'g',
          'product_quantity': '',
          'product_quantity_unit': 'g',
        });

        expect(p.portionen, const [portion58]);
      },
    );

    test('JSON-null in allen vier Feldern → gefragt, keine', () async {
      final p = await amStrichcode(const {
        'serving_quantity': null,
        'serving_quantity_unit': null,
        'product_quantity': null,
        'product_quantity_unit': null,
      });

      expect(p.portionen, isNotNull);
      expect(p.portionen, isEmpty);
    });

    test('ohne alle vier Felder → portionen ist [], nicht null', () async {
      final p = await amStrichcode(const {});

      expect(
        p.portionen,
        isNotNull,
        reason:
            'der Strichcode-Endpunkt wurde gefragt und hat geantwortet — '
            '„nicht abgefragt" wäre gelogen',
      );
      expect(p.portionen, isEmpty);
      expect(p.fluessig, isFalse);
    });

    test(
      'Freitexte allein ergeben keine Portion (E4, keine Schätzung)',
      () async {
        final p = await amStrichcode(const {
          'quantity': '6 x 20 g',
          'serving_size': '1 Riegel (20 g)',
        });

        expect(p.portionen, isNotNull);
        expect(p.portionen, isEmpty);
      },
    );

    test(
      'Packung ohne Einheit fällt weg — „quantity" ersetzt sie nicht',
      () async {
        final p = await amStrichcode(const {
          'product_quantity': 225,
          'quantity': '225 g',
        });

        expect(p.portionen, isEmpty);
      },
    );

    test('der Client benutzt die Kernregel: Portion 100 g entfällt', () async {
      final p = await amStrichcode(const {
        'serving_quantity': 100,
        'serving_quantity_unit': 'g',
        'product_quantity': 225,
        'product_quantity_unit': 'g',
      });

      expect(p.portionen, const [packung225]);
    });

    test(
      'der Client benutzt die Kernregel: Portion = Packung → Packung',
      () async {
        final p = await amStrichcode(const {
          'serving_quantity': 150,
          'serving_quantity_unit': 'g',
          'product_quantity': '150',
          'product_quantity_unit': 'g',
        });

        expect(p.portionen, const [
          Portion(name: 'Packung', mengeG: 150, herkunft: Herkunft.off),
        ]);
      },
    );

    test('Einheit „ G " wird wie g gelesen', () async {
      final p = await amStrichcode(const {
        'serving_quantity': 5.8,
        'serving_quantity_unit': ' G ',
        'product_quantity': 225,
        'product_quantity_unit': 'g',
      });

      expect(p.portionen, const [portion58, packung225]);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Flüssiges (E10)', () {
    test('product_quantity_unit ml → flüssig, auch in der Vorlage', () async {
      final p = await amStrichcode(code: barcodeSaft, const {
        'serving_quantity': 250,
        'serving_quantity_unit': 'ml',
        'product_quantity': 1000,
        'product_quantity_unit': 'ml',
      });

      expect(p.fluessig, isTrue);
      expect(p.alsVorlage().fluessig, isTrue);
      expect(p.portionen, const [
        Portion(name: 'Portion', mengeG: 250, herkunft: Herkunft.off),
        Portion(name: 'Packung', mengeG: 1000, herkunft: Herkunft.off),
      ], reason: 'mengeG steht in der Einheit des Lebensmittels, hier ml');
    });

    test('nur product_quantity_unit ml genügt', () async {
      final p = await amStrichcode(code: barcodeSaft, const {
        'product_quantity': 330,
        'product_quantity_unit': 'ml',
      });

      expect(p.fluessig, isTrue);
      expect(p.alsVorlage().fluessig, isTrue);
    });

    test('nur serving_quantity_unit ml genügt', () async {
      final p = await amStrichcode(code: barcodeSaft, const {
        'serving_quantity': 250,
        'serving_quantity_unit': 'ml',
      });

      expect(p.fluessig, isTrue);
      expect(p.alsVorlage().fluessig, isTrue);
    });

    test(
      'Portion in g, Packung in ml → nur die Packung, flüssig (V1)',
      () async {
        final p = await amStrichcode(code: barcodeSaft, const {
          'serving_quantity': 30,
          'serving_quantity_unit': 'g',
          'product_quantity': 500,
          'product_quantity_unit': 'ml',
        });

        expect(p.portionen, const [
          Portion(name: 'Packung', mengeG: 500, herkunft: Herkunft.off),
        ]);
        expect(p.fluessig, isTrue);
      },
    );

    test('alles in g → nicht flüssig, auch in der Vorlage', () async {
      final p = await amStrichcode(const {
        'serving_quantity': 5.8,
        'serving_quantity_unit': 'g',
        'product_quantity': 225,
        'product_quantity_unit': 'g',
      });

      expect(p.fluessig, isFalse);
      expect(p.alsVorlage().fluessig, isFalse);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Suchtreffer: nicht abgefragt', () {
    Map<String, Object?> treffer({Map<String, Object?> felder = const {}}) => {
      'code': barcodeKekse,
      'product_name': 'Prüfkekse Erfundenwerk',
      'brands': const ['Erfundenwerk'],
      'nutriments': naehrwerte,
      ...felder,
    };

    test(
      'ein Suchtreffer hat portionen == null und ist nicht flüssig',
      () async {
        final c = mit((_) => json(suchAntwort([treffer()])));

        final p = einziges(await c.client.suche('Prüfkekse'));

        expect(
          p.portionen,
          isNull,
          reason:
              'null heißt „nicht abgefragt" — [] behauptete „keine '
              'Portion bekannt", bevor jemand nachgesehen hat (`01`)',
        );
        expect(p.fluessig, isFalse);
        expect(p.alsVorlage().offPortionen, isNull);
      },
    );

    test('auch mit Portionsfeldern in der Antwort bleibt portionen null '
        '(Festlegung des Test-Agenten)', () async {
      final c = mit(
        (_) => json(
          suchAntwort([
            treffer(
              felder: const {
                'serving_quantity': 250,
                'serving_quantity_unit': 'ml',
                'product_quantity': 1000,
                'product_quantity_unit': 'ml',
              },
            ),
          ]),
        ),
      );

      final p = einziges(await c.client.suche('Prüfkekse'));

      expect(p.portionen, isNull);
      expect(p.fluessig, isFalse);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Vom Produkt zur Vorlage', () {
    test('alsVorlage gibt die Portionen als offPortionen weiter', () async {
      final p = await amStrichcode(const {
        'serving_quantity': 5.8,
        'serving_quantity_unit': 'g',
        'product_quantity': 225,
        'product_quantity_unit': 'g',
      });

      expect(p.alsVorlage().offPortionen, const [portion58, packung225]);
    });

    test('gefragt, keine: die Vorlage trägt [], nicht null', () async {
      final p = await amStrichcode(const {});

      final v = p.alsVorlage();
      expect(
        v.offPortionen,
        isNotNull,
        reason:
            'ein gescanntes Produkt fragt beim Öffnen des Blatts nicht '
            'noch einmal — erkennbar an offPortionen != null (Spec, „Abruf '
            'beim Antippen")',
      );
      expect(v.offPortionen, isEmpty);
    });

    test('Vorgaben: OffProdukt ohne Angabe hat portionen null, nicht '
        'flüssig', () {
      const p = OffProdukt(
        barcode: barcodeKekse,
        name: 'Prüfkekse Erfundenwerk',
        je100g: Naehrwerte.je100g(kcal: 512),
      );

      expect(p.portionen, isNull);
      expect(p.fluessig, isFalse);
    });

    test('Vorgabe: LebensmittelVorlage ohne Angabe hat offPortionen null', () {
      const v = LebensmittelVorlage(
        name: 'Prüfkekse Erfundenwerk',
        je100g: Naehrwerte.je100g(kcal: 512),
      );

      expect(v.offPortionen, isNull);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Wertgleichheit', () {
    const je100g = Naehrwerte.je100g(kcal: 512);

    OffProdukt offProdukt({List<Portion>? portionen, bool fluessig = false}) =>
        OffProdukt(
          barcode: barcodeKekse,
          name: 'Prüfkekse Erfundenwerk',
          je100g: je100g,
          portionen: portionen,
          fluessig: fluessig,
        );

    test('OffProdukt vergleicht portionen nach Inhalt', () {
      final a = offProdukt(portionen: [portion58, packung225]);
      final b = offProdukt(portionen: [portion58, packung225]);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('OffProdukt: null, [] und eine Liste sind drei Verschiedene', () {
      final nichtGefragt = offProdukt();
      final keine = offProdukt(portionen: const []);
      final eine = offProdukt(portionen: const [packung225]);

      expect(nichtGefragt, isNot(keine));
      expect(keine, isNot(eine));
      expect(nichtGefragt, isNot(eine));
    });

    test('OffProdukt unterscheidet sich an fluessig', () {
      expect(offProdukt(), isNot(offProdukt(fluessig: true)));
    });

    LebensmittelVorlage vorlage({List<Portion>? offPortionen}) =>
        LebensmittelVorlage(
          name: 'Prüfkekse Erfundenwerk',
          je100g: je100g,
          barcode: barcodeKekse,
          herkunft: Herkunft.off,
          offPortionen: offPortionen,
        );

    test('LebensmittelVorlage vergleicht offPortionen nach Inhalt', () {
      final a = vorlage(offPortionen: [portion58, packung225]);
      final b = vorlage(offPortionen: [portion58, packung225]);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('LebensmittelVorlage: null und [] sind verschieden', () {
      expect(vorlage(), isNot(vorlage(offPortionen: const [])));
      expect(
        vorlage(offPortionen: const []),
        isNot(vorlage(offPortionen: const [packung225])),
      );
    });

    test('Portion vergleicht nach Wert', () {
      const a = Portion(name: 'Bon', mengeG: 5.9);
      // Nicht const, damit es ein anderes Objekt ist.
      // ignore: prefer_const_constructors
      final b = Portion(name: 'Bon', mengeG: 5.9);

      expect(identical(a, b), isFalse);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(const Portion(name: 'Schale', mengeG: 5.9)));
      expect(a, isNot(const Portion(name: 'Bon', mengeG: 6.1)));
      expect(
        a,
        isNot(const Portion(name: 'Bon', mengeG: 5.9, herkunft: Herkunft.off)),
      );
    });

    test('Portion: ohne Angabe eigen und ohne id', () {
      const a = Portion(name: 'Bon', mengeG: 5.9);

      expect(a.herkunft, Herkunft.eigen);
      expect(a.id, isNull);
    });

    test('Portion.mit ändert Name oder Gramm und behält den Rest', () {
      const a = Portion(
        id: 3,
        name: 'Bon',
        mengeG: 5.9,
        herkunft: Herkunft.off,
      );

      final umbenannt = a.mit(name: 'Kugel');
      expect(umbenannt.id, 3);
      expect(umbenannt.name, 'Kugel');
      expect(umbenannt.mengeG, 5.9);
      expect(umbenannt.herkunft, Herkunft.off);

      final schwerer = a.mit(mengeG: 6.1);
      expect(schwerer.id, 3);
      expect(schwerer.name, 'Bon');
      expect(schwerer.mengeG, 6.1);
      expect(schwerer.herkunft, Herkunft.off);

      expect(a.mit(), a);
    });
  });
}
