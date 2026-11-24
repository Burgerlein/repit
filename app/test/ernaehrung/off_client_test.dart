import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/lebensmittel_repository.dart';
import 'package:repit/ernaehrung/off_client.dart';

/// Tests für den **Open-Food-Facts-Client** (#284, Plan Task 6) — gegen
/// einen eingesetzten `http.Client`, **ohne Netz im Test**.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung**
/// (`CLAUDE.md`). Diese Datei darf ausgeführt, aber nicht verändert
/// werden.
///
/// ## Was diese Tests verbindlich vorgeben
///
/// Neu in `lib/ernaehrung/off_client.dart`:
///
/// ```dart
/// /// Was eine Anfrage an Open Food Facts ergibt — **drei Fälle, nicht
/// /// zwei.** „Kein Netz" und „nicht hinterlegt" werden nie vermischt,
/// /// dieselbe Regel wie bei fehlenden HealthKit-Daten.
/// sealed class OffErgebnis { const OffErgebnis(); }
///
/// /// Mindestens ein anzeigbares Produkt — **nie leer**. Eine leere Liste
/// /// ist [NichtGefunden].
/// final class Treffer extends OffErgebnis {
///   const Treffer(this.produkte);
///   final List<OffProdukt> produkte;
/// }
///
/// /// Open Food Facts hat geantwortet und kennt nichts Anzeigbares.
/// final class NichtGefunden extends OffErgebnis { const NichtGefunden(); }
///
/// /// Open Food Facts war nicht zu erreichen oder hat nicht lesbar
/// /// geantwortet.
/// final class KeinNetz extends OffErgebnis { const KeinNetz(); }
///
/// /// Ein Produkt aus Open Food Facts — Nährwerte **je 100 g**.
/// @immutable
/// class OffProdukt {
///   const OffProdukt({
///     required this.barcode,
///     required this.name,
///     this.marke,
///     required this.je100g,
///   });
///   final String barcode;
///   final String name;
///   final String? marke;          // `brands`, `null` wenn leer/fehlend
///   final Naehrwerte je100g;      // fehlendes Feld → null, nie 0
///
///   /// Ohne Kalorien kein Eintrag.
///   bool get buchbar;             // je100g.kcal != null
///
///   /// Die Vorlage, die beim Buchen in die eigene Tabelle wandert:
///   /// `id` null, `herkunft` Herkunft.off, `barcode` gesetzt,
///   /// `zuletztBenutzt` null.
///   LebensmittelVorlage alsVorlage();
///   // == und hashCode über alle Felder
/// }
///
/// class OffClient {
///   OffClient({required http.Client client});
///   Future<OffErgebnis> suche(String text);
///   Future<OffErgebnis> produktZuBarcode(String ean);
/// }
///
/// /// Der Client für den Riverpod-Baum — in Tests mit
/// /// `offClientProvider.overrideWithValue(OffClient(client: MockClient(…)))`
/// /// ersetzt.
/// final offClientProvider = Provider<OffClient>(…);
/// ```
///
/// Dazu `http` als direkte Abhängigkeit in `app/pubspec.yaml` (Plan,
/// Task 6, „Modify"). Bis sie dasteht, scheitert diese Datei schon am
/// Import — das ist das erwartete Rot.
///
/// **Beide Methoden werfen nie** wegen Netz oder Antwort. Was schiefgeht,
/// ist [KeinNetz] oder [NichtGefunden], nicht eine Ausnahme, die ein
/// Schirm fangen müsste.
///
/// ## Entscheidung des Test-Agenten: welche Antwort was bedeutet
///
/// **Nicht mit Tim abgestimmt, nicht freigegeben** — mit Begründung.
///
/// | Antwort | Ergebnis | Warum |
/// |---|---|---|
/// | 200, `status: 1`, Produkt mit Namen | `Treffer` | |
/// | 200, `status: 0` | `NichtGefunden` | Brief, Review Focus 4 |
/// | 200, `product` leer, `null` oder fehlend | `NichtGefunden` | dto. — kein Treffer mit lauter Nullen |
/// | **404** | `NichtGefunden` | So antwortet OFF auf `/api/v2/product/…` für einen **unbekannten** Strichcode (mit `status: 0` im Körper). Das ist Auskunft, keine Störung. |
/// | 5xx, 429, andere Nicht-2xx | `KeinNetz` | Die Quelle ist da, liefert aber nichts. „Nicht gefunden" behauptete, OFF kenne das Produkt nicht — das weiß in dem Moment niemand. |
/// | 200 mit unlesbarem Körper (HTML-Fehlerseite) | `KeinNetz` | dto. |
/// | `SocketException`, `ClientException` | `KeinNetz` | |
/// | keine Antwort nach **5 s** | `KeinNetz` | Brief, Spec |
///
/// Die Leitlinie: `NichtGefunden` heißt „OFF hat nachgesehen und hat es
/// nicht". Alles, wo niemand nachgesehen hat, ist `KeinNetz` — auf dem
/// Schirm „Online nicht erreichbar".
///
/// ## Entscheidung des Test-Agenten: was als Produkt zählt
///
/// **Nicht mit Tim abgestimmt, nicht freigegeben** — mit Begründung.
///
/// - **Name:** `product_name_de`, wenn nicht leer, sonst `product_name`.
///   Ist beides leer oder fehlt, **fällt das Produkt weg** (Brief). Nur
///   Leerzeichen gelten als leer.
/// - **Strichcode:** `code`. Ein Produkt **ohne** `code` fällt ebenfalls
///   weg: Der Strichcode ist das, woran die eigene Tabelle ein
///   übernommenes Produkt wiedererkennt — ohne ihn legte jedes Buchen ein
///   neues an, und das Entdoppeln in der Suche ginge nicht.
/// - **Nährwerte:** genau die sieben Schlüssel aus dem Brief —
///   `energy-kcal_100g`, `proteins_100g`, `carbohydrates_100g`,
///   `fat_100g`, `sugars_100g`, `saturated-fat_100g`, `fiber_100g`.
///   **Nicht** `energy_100g`: Das ist bei OFF Kilojoule unter einem
///   irreführenden Namen. Ein Client, der es als Kalorien läse, buchte
///   das 4,2-Fache. Fehlende Kalorien kommen stattdessen aus
///   `energy-kj_100g` — siehe die Vorgabe vom 04.11.2026 unten.
/// - **Eine gelieferte 0 bleibt 0**, ein fehlender Schlüssel bleibt
///   `null` (`CLAUDE.md`: „Ein Codec, der fehlende Felder auf 0 abbildet,
///   baut `01` unterhalb von allem neu ein").
/// - **Höchstens 50 Produkte**, auch wenn der Server mehr schickt —
///   und bis dahin **alle**. Bis zum 04.11.2026 waren es 25; siehe die
///   zweite Vorgabe vom 04.11.2026 unten.
///
/// ## Entscheidung des Test-Agenten: ein eigener User-Agent
///
/// **Nicht mit Tim abgestimmt, nicht freigegeben** — mit Begründung. Open
/// Food Facts verlangt in seinen API-Regeln, dass eine App sich mit einem
/// eigenen `User-Agent` ausweist, und sperrt sonst auf Verdacht. Geprüft
/// wird nur, **dass** einer gesetzt ist und nicht Darts Vorgabe ist — was
/// darin steht, ist Sache der Implementierung. **Keine E-Mail-Adresse
/// darin**: Das Repository ist kein Ort für Tims Kontaktdaten.
///
/// ## Vorgabe vom 04.11.2026: die Suche zieht um, Kilojoule zählen
///
/// Aus dem Auftrag an den Test-Agenten, nicht von ihm entschieden.
///
/// - **Die Namenssuche fragt `search.openfoodfacts.org/search`**, nicht
///   mehr `/cgi/search.pl` auf `world.openfoodfacts.org`. Die alte
///   Schnittstelle antwortete am 04.11.2026 drei von drei Malen mit
///   HTTP 503 und einer HTML-Seite; auf dem Telefon stünde ständig
///   „Online nicht erreichbar". Parameter: `q` (der Suchtext ohne
///   Ränder), `langs=de`, `page_size` (seit der zweiten Vorgabe unten
///   `50`) und `fields` mit mindestens
///   `code`, `product_name`, `product_name_de`, `brands`, `nutriments`.
///   Die Antwort trägt die Treffer unter **`hits`**, nicht unter
///   `products`.
/// - **Der Strichcode bleibt bei `/api/v2/product/<ean>.json`** auf
///   `world.openfoodfacts.org` — der antwortet zuverlässig.
/// - **`brands` hat zwei Formen.** In der Suche ist es eine Liste von
///   Texten: Die Marke ist die erste Angabe, eine leere Liste oder lauter
///   leere Texte heißen keine Marke. Beim Strichcode ist es weiter ein
///   Text. Je Form ein Fall. Ob eine leere **erste** Angabe vor einer
///   nicht leeren übersprungen wird, legt diese Datei nicht fest.
/// - **Kilojoule werden umgerechnet.** Fehlt `energy-kcal_100g`, steht
///   aber `energy-kj_100g` da, sind die Kalorien kJ / 4,184. Das ist eine
///   Einheitenumrechnung, keine Schätzung: Die Packung trägt beide Werte,
///   OFF hat manchmal nur einen gespeichert — von 20 echten Treffern
///   trugen 5 nur Kilojoule und wären sonst nicht buchbar. Steht
///   `energy-kcal_100g` da, gewinnt es, auch wenn die Kilojoule nicht
///   dazu passen. `energy_100g` bleibt ungelesen, auch zum Umrechnen.
///   Geprüft wird ungerundet, auf ±0,01 kcal.
/// - **Der Länderfilter wird nicht mehr geprüft.** Die vorgegebene
///   Anfrage trägt keinen; die Spec (Abschnitt „Namenssuche gegen Open
///   Food Facts") verlangt ihn noch. Das ist an den Koordinator gemeldet,
///   nicht hier entschieden.
///
/// ## Zweite Vorgabe vom 04.11.2026: 50 fragen, nach dem Zusammenfassen 25
///
/// Aus dem Auftrag an den Test-Agenten, nicht von ihm entschieden. Tim auf
/// dem Gerät: „man findet direkt 8000 mal das gleiche, wenn ich nach
/// Nutella suche." Gleiche Produkte erscheinen seitdem einmal (Regel und
/// Fälle in `Packages/trainings_core/test/lebensmittel_dubletten_test.dart`).
/// Damit nach dem Zusammenfassen noch genug übrig ist, fragt die Suche
/// **`page_size=50`** und reicht **bis zu 50** Produkte weiter. Die Grenze
/// von 25 gilt erst für die angezeigten Zeilen, **nach** dem
/// Zusammenfassen — geprüft in `off_suche_view_test.dart`, nicht hier.
/// Schnitte der Client vorher auf 25 ab, blieben bei „Nutella" aus 25
/// Treffern zwölf Zeilen (gemessen am 04.11.2026).
///
/// Ob der Client selbst zusammenfasst, legt diese Datei nicht fest; die
/// Fälle hier haben lauter verschiedene Namen.
///
/// **Treffer ohne Kalorien und Treffer über 900 kcal je 100 g** werden
/// seit der Ergänzung vom selben Tag aus der Trefferliste verworfen —
/// **nicht hier**, sondern im Kern (`LebensmittelDubletten
/// .onlineVertreter`), als erster Schritt vor dem Zusammenfassen. Der
/// Client bleibt Transport: Er liefert, was Open Food Facts kennt, und
/// sagt mit `buchbar`, ob Kalorien dabei sind. Aus Kilojoule umgerechnete
/// Kalorien zählen als vorhanden.
///
/// Alle Produkte, Namen und Strichcodes hier sind **erfunden**. Die
/// Strichcodes beginnen mit lauter Nullen, damit sie nach keinem echten
/// Produkt aussehen.
void main() {
  const barcodeHafer = '0000000000017';
  const barcodeSkyr = '0000000000024';
  const barcodeOhneName = '0000000000031';

  /// Die sieben Nährwertschlüssel **und** Störfelder daneben: Kilojoule
  /// unter `energy_100g`, Portionsangaben unter `_serving`. Ein Client,
  /// der den falschen Schlüssel greift, fällt an den Zahlen auf.
  const vollstaendig = <String, Object?>{
    'energy-kcal_100g': 371,
    'energy_100g': 1552,
    'energy-kj_100g': 1552,
    'energy-kcal_serving': 148.4,
    'proteins_100g': 12.5,
    'proteins_serving': 5,
    'carbohydrates_100g': 59,
    'fat_100g': 6.5,
    'sugars_100g': 1.2,
    'saturated-fat_100g': 1.1,
    'fiber_100g': 9.5,
  };

  Map<String, Object?> produkt({
    String? code = barcodeHafer,
    String? name = 'Haferflocken Prüfmühle',
    String? nameDe,
    String? marke,
    Map<String, Object?>? naehrwerte = vollstaendig,
  }) => {
    'code': ?code,
    'product_name': ?name,
    'product_name_de': ?nameDe,
    'brands': ?marke,
    'nutriments': ?naehrwerte,
  };

  /// Eine JSON-Antwort, **als UTF-8 kodiert** — so, wie Open Food Facts
  /// sie schickt. `http.Response(String, …)` kodierte sonst Latin-1, und
  /// ein Umlaut-Test bewiese dann nichts.
  http.Response json(Object? koerper, {int status = 200}) => http.Response.bytes(
    utf8.encode(jsonEncode(koerper)),
    status,
    headers: const {'content-type': 'application/json; charset=utf-8'},
  );

  /// Ein Treffer der Namenssuche (`search.openfoodfacts.org`) — wie
  /// [produkt], nur ist `brands` hier eine **Liste** von Texten.
  Map<String, Object?> treffer({
    String? code = barcodeHafer,
    String? name = 'Haferflocken Prüfmühle',
    String? nameDe,
    List<String>? marken,
    Map<String, Object?>? naehrwerte = vollstaendig,
  }) => {
    'code': ?code,
    'product_name': ?name,
    'product_name_de': ?nameDe,
    'brands': ?marken,
    'nutriments': ?naehrwerte,
  };

  Map<String, Object?> produktAntwort(Map<String, Object?>? p) => {
    'code': barcodeHafer,
    'status': 1,
    'status_verbose': 'product found',
    'product': p,
  };

  /// Die Antwort von `search.openfoodfacts.org/search`: Treffer unter
  /// `hits`, nicht unter `products`.
  Map<String, Object?> suchAntwort(List<Map<String, Object?>> hits) => {
    'count': hits.length,
    'is_count_exact': true,
    'page': 1,
    'page_count': 1,
    'page_size': 50,
    'timed_out': false,
    'hits': hits,
  };

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

  List<OffProdukt> alle(OffErgebnis ergebnis) {
    expect(ergebnis, isA<Treffer>());
    return (ergebnis as Treffer).produkte;
  }

  // ═════════════════════════════════════════════════════════════════════
  group('Produkt zum Strichcode', () {
    test('fragt /api/v2/product/<ean>.json bei world.openfoodfacts.org', () async {
      final c = mit((_) => json(produktAntwort(produkt())));

      await c.client.produktZuBarcode(barcodeHafer);

      expect(c.anfragen, hasLength(1));
      final url = c.anfragen.single.url;
      expect(c.anfragen.single.method, 'GET');
      expect(url.scheme, 'https');
      expect(url.host, 'world.openfoodfacts.org');
      expect(url.path, '/api/v2/product/$barcodeHafer.json');
    });

    test('ein gefundenes Produkt ist ein Treffer mit allen sieben Werten', () async {
      final c = mit(
        (_) => json(produktAntwort(produkt(marke: 'Erfundenwerk'))),
      );

      final p = einziges(await c.client.produktZuBarcode(barcodeHafer));

      expect(p.barcode, barcodeHafer);
      expect(p.name, 'Haferflocken Prüfmühle');
      expect(p.marke, 'Erfundenwerk');
      expect(p.je100g.kcal, 371);
      expect(p.je100g.eiweissG, 12.5);
      expect(p.je100g.kohlenhydrateG, 59);
      expect(p.je100g.fettG, 6.5);
      expect(p.je100g.zuckerG, 1.2);
      expect(p.je100g.gesaettigtG, 1.1);
      expect(p.je100g.ballaststoffeG, 9.5);
      expect(p.buchbar, isTrue);
    });

    test('kcal kommt aus energy-kcal_100g, nicht aus energy_100g (Kilojoule)', () async {
      final c = mit((_) => json(produktAntwort(produkt())));

      final p = einziges(await c.client.produktZuBarcode(barcodeHafer));

      expect(
        p.je100g.kcal,
        371,
        reason:
            '`energy_100g` ist bei Open Food Facts Kilojoule. Wer es als '
            'Kalorien liest, bucht das 4,2-Fache',
      );
    });

    test('HTTP 200 mit status 0 ist NichtGefunden', () async {
      final c = mit(
        (_) => json({
          'code': barcodeHafer,
          'status': 0,
          'status_verbose': 'product not found',
        }),
      );

      expect(
        await c.client.produktZuBarcode(barcodeHafer),
        isA<NichtGefunden>(),
      );
    });

    test('HTTP 200 mit leerem product ist NichtGefunden, '
        'kein Treffer mit lauter Nullen', () async {
      final c = mit((_) => json(produktAntwort(const {})));

      expect(
        await c.client.produktZuBarcode(barcodeHafer),
        isA<NichtGefunden>(),
      );
    });

    test('HTTP 200 mit product null oder ohne product ist NichtGefunden', () async {
      final ohne = mit(
        (_) => json({'code': barcodeHafer, 'status': 1}),
      );
      final mitNull = mit((_) => json(produktAntwort(null)));

      expect(
        await ohne.client.produktZuBarcode(barcodeHafer),
        isA<NichtGefunden>(),
      );
      expect(
        await mitNull.client.produktZuBarcode(barcodeHafer),
        isA<NichtGefunden>(),
      );
    });

    test('HTTP 404 ist NichtGefunden — so meldet OFF einen unbekannten '
        'Strichcode', () async {
      final c = mit(
        (_) => json({
          'code': barcodeHafer,
          'status': 0,
          'status_verbose': 'product not found',
        }, status: 404),
      );

      expect(
        await c.client.produktZuBarcode(barcodeHafer),
        isA<NichtGefunden>(),
      );
    });

    test('ein Produkt ohne Namen ist NichtGefunden', () async {
      final ohneName = mit((_) => json(produktAntwort(produkt(name: null))));
      final leererName = mit((_) => json(produktAntwort(produkt(name: '  '))));

      expect(
        await ohneName.client.produktZuBarcode(barcodeHafer),
        isA<NichtGefunden>(),
      );
      expect(
        await leererName.client.produktZuBarcode(barcodeHafer),
        isA<NichtGefunden>(),
      );
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Fehlende Nährwerte bleiben null, nicht 0', () {
    test('ein fehlender Schlüssel ist null — je Feld', () async {
      const schluessel = {
        'energy-kcal_100g',
        'proteins_100g',
        'carbohydrates_100g',
        'fat_100g',
        'sugars_100g',
        'saturated-fat_100g',
        'fiber_100g',
      };
      double? feld(Naehrwerte n, String s) => switch (s) {
        'energy-kcal_100g' => n.kcal,
        'proteins_100g' => n.eiweissG,
        'carbohydrates_100g' => n.kohlenhydrateG,
        'fat_100g' => n.fettG,
        'sugars_100g' => n.zuckerG,
        'saturated-fat_100g' => n.gesaettigtG,
        'fiber_100g' => n.ballaststoffeG,
        _ => throw ArgumentError(s),
      };

      for (final fehlt in schluessel) {
        final naehrwerte = Map<String, Object?>.of(vollstaendig)
          ..remove(fehlt)
          // Ohne die Kilojoule: Sonst rechnete der Client fehlende
          // Kalorien zu Recht aus ihnen um (Gruppe „Kilojoule werden
          // umgerechnet").
          ..remove('energy_100g')
          ..remove('energy-kj_100g');
        final c = mit(
          (_) => json(produktAntwort(produkt(naehrwerte: naehrwerte))),
        );

        final p = einziges(await c.client.produktZuBarcode(barcodeHafer));

        expect(
          feld(p.je100g, fehlt),
          isNull,
          reason:
              'fehlt `$fehlt`, fehlt der Wert — eine 0 behauptete „enthält '
              'nichts davon" (`CLAUDE.md`, Fehler 01 unterhalb von allem)',
        );
        for (final da in schluessel.difference({fehlt})) {
          expect(
            feld(p.je100g, da),
            isNotNull,
            reason: '`$da` stand da und darf nicht mit `$fehlt` verschwinden',
          );
        }
      }
    });

    test('ganz ohne nutriments: Treffer mit lauter null — und nicht buchbar', () async {
      final c = mit(
        (_) => json(produktAntwort(produkt(naehrwerte: null))),
      );

      final p = einziges(await c.client.produktZuBarcode(barcodeHafer));

      expect(p.je100g.kcal, isNull);
      expect(p.je100g.eiweissG, isNull);
      expect(p.je100g.kohlenhydrateG, isNull);
      expect(p.je100g.fettG, isNull);
      expect(p.je100g.zuckerG, isNull);
      expect(p.je100g.gesaettigtG, isNull);
      expect(p.je100g.ballaststoffeG, isNull);
      expect(
        p.buchbar,
        isFalse,
        reason: 'ohne Kalorien kein Eintrag',
      );
    });

    test('eine gelieferte 0 bleibt 0', () async {
      final c = mit(
        (_) => json(
          produktAntwort(
            produkt(
              naehrwerte: const {
                'energy-kcal_100g': 0,
                'sugars_100g': 0,
                'fat_100g': 0.0,
              },
            ),
          ),
        ),
      );

      final p = einziges(await c.client.produktZuBarcode(barcodeHafer));

      expect(p.je100g.kcal, 0);
      expect(p.je100g.zuckerG, 0);
      expect(p.je100g.fettG, 0);
      expect(
        p.buchbar,
        isTrue,
        reason: '0 kcal ist eine Angabe (Mineralwasser), keine fehlende',
      );
      expect(p.je100g.eiweissG, isNull);
    });

    test('ohne Kalorien, aber mit Eiweiß: nicht buchbar', () async {
      final c = mit(
        (_) => json(
          produktAntwort(
            produkt(naehrwerte: const {'proteins_100g': 10, 'fat_100g': 3}),
          ),
        ),
      );

      final p = einziges(await c.client.produktZuBarcode(barcodeHafer));

      expect(p.je100g.kcal, isNull);
      expect(p.je100g.eiweissG, 10);
      expect(p.buchbar, isFalse);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  // Vorgabe vom 04.11.2026 (Kopf): 1 kcal = 4,184 kJ.
  group('Kilojoule werden umgerechnet', () {
    test('nur energy-kj_100g: kcal = kJ / 4,184, buchbar — bei beiden '
        'Wegen', () async {
      const naehrwerte = <String, Object?>{
        'energy-kj_100g': 1552,
        'proteins_100g': 12.5,
      };
      final strichcode = mit(
        (_) => json(produktAntwort(produkt(naehrwerte: naehrwerte))),
      );
      final suche = mit(
        (_) => json(suchAntwort([treffer(naehrwerte: naehrwerte)])),
      );

      final ausStrichcode = einziges(
        await strichcode.client.produktZuBarcode(barcodeHafer),
      );
      final ausSuche = einziges(await suche.client.suche('Hafer'));

      for (final (weg, p) in [
        ('Strichcode', ausStrichcode),
        ('Suche', ausSuche),
      ]) {
        expect(
          p.je100g.kcal,
          closeTo(1552 / 4.184, 0.01),
          reason:
              '$weg: Fehlt energy-kcal_100g, kommen die Kalorien aus den '
              'Kilojoule — sonst wäre jedes vierte Produkt nicht buchbar',
        );
        expect(p.buchbar, isTrue, reason: weg);
        expect(p.je100g.eiweissG, 12.5, reason: weg);
      }
    });

    test('gebrochene Kilojoule werden genauso umgerechnet', () async {
      final c = mit(
        (_) => json(
          produktAntwort(
            produkt(naehrwerte: const {'energy-kj_100g': 1046.5}),
          ),
        ),
      );

      final p = einziges(await c.client.produktZuBarcode(barcodeHafer));

      expect(p.je100g.kcal, closeTo(1046.5 / 4.184, 0.01));
    });

    test('steht energy-kcal_100g da, gewinnt es — auch wenn die Kilojoule '
        'nicht dazu passen', () async {
      const naehrwerte = <String, Object?>{
        'energy-kcal_100g': 371,
        'energy-kj_100g': 1000,
      };
      final strichcode = mit(
        (_) => json(produktAntwort(produkt(naehrwerte: naehrwerte))),
      );
      final suche = mit(
        (_) => json(suchAntwort([treffer(naehrwerte: naehrwerte)])),
      );

      expect(
        einziges(await strichcode.client.produktZuBarcode(barcodeHafer))
            .je100g
            .kcal,
        371,
      );
      expect(einziges(await suche.client.suche('Hafer')).je100g.kcal, 371);
    });

    test('0 kJ sind 0 kcal — eine Angabe, keine fehlende', () async {
      final c = mit(
        (_) => json(
          produktAntwort(produkt(naehrwerte: const {'energy-kj_100g': 0})),
        ),
      );

      final p = einziges(await c.client.produktZuBarcode(barcodeHafer));

      expect(p.je100g.kcal, 0);
      expect(p.buchbar, isTrue);
    });

    test('energy_100g wird nicht gelesen — auch nicht zum Umrechnen', () async {
      final nurEnergy = mit(
        (_) => json(
          produktAntwort(
            produkt(
              naehrwerte: const {'energy_100g': 1552, 'proteins_100g': 12.5},
            ),
          ),
        ),
      );
      final nebenKj = mit(
        (_) => json(
          suchAntwort([
            treffer(
              naehrwerte: const {'energy_100g': 9999, 'energy-kj_100g': 1552},
            ),
          ]),
        ),
      );

      final ohne = einziges(
        await nurEnergy.client.produktZuBarcode(barcodeHafer),
      );
      expect(
        ohne.je100g.kcal,
        isNull,
        reason:
            '`energy_100g` ist Kilojoule unter einem irreführenden Namen. '
            'Fehlen energy-kcal_100g und energy-kj_100g, fehlen die Kalorien',
      );
      expect(ohne.buchbar, isFalse, reason: 'ohne Kalorien kein Eintrag');

      expect(
        einziges(await nebenKj.client.suche('Hafer')).je100g.kcal,
        closeTo(1552 / 4.184, 0.01),
        reason: 'umgerechnet wird aus energy-kj_100g, nicht aus energy_100g',
      );
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Name und Marke', () {
    test('product_name_de geht vor product_name', () async {
      final c = mit(
        (_) => json(
          produktAntwort(
            produkt(name: 'Oat flakes test', nameDe: 'Haferflocken Prüfmühle'),
          ),
        ),
      );

      final p = einziges(await c.client.produktZuBarcode(barcodeHafer));

      expect(p.name, 'Haferflocken Prüfmühle');
    });

    test('ein leeres product_name_de fällt auf product_name zurück', () async {
      final c = mit(
        (_) => json(
          produktAntwort(produkt(name: 'Haferflocken Prüfmühle', nameDe: '')),
        ),
      );

      final p = einziges(await c.client.produktZuBarcode(barcodeHafer));

      expect(p.name, 'Haferflocken Prüfmühle');
    });

    test('Umlaute kommen heil an (UTF-8)', () async {
      final c = mit(
        (_) => json(produktAntwort(produkt(name: 'Müsli Größe Übermaß'))),
      );

      final p = einziges(await c.client.produktZuBarcode(barcodeHafer));

      expect(p.name, 'Müsli Größe Übermaß');
    });

    test('ohne brands ist die Marke null, nicht leer', () async {
      final ohne = mit((_) => json(produktAntwort(produkt())));
      final leer = mit((_) => json(produktAntwort(produkt(marke: ''))));

      expect(einziges(await ohne.client.produktZuBarcode(barcodeHafer)).marke,
          isNull);
      expect(einziges(await leer.client.produktZuBarcode(barcodeHafer)).marke,
          isNull);
    });

    test('Strichcode: brands ist ein Text — er ist die Marke', () async {
      final c = mit(
        (_) => json(produktAntwort(produkt(marke: 'Erfundenwerk'))),
      );

      final p = einziges(await c.client.produktZuBarcode(barcodeHafer));

      expect(
        p.marke,
        'Erfundenwerk',
        reason: '/api/v2/product liefert brands weiter als Text, nicht als '
            'Liste',
      );
    });

    test('Suche: brands ist eine Liste — die erste Angabe ist die Marke', () async {
      final c = mit(
        (_) => json(
          suchAntwort([
            treffer(marken: const ['Erfundenwerk', 'Zweitmarke Prüf']),
          ]),
        ),
      );

      final p = einziges(await c.client.suche('Hafer'));

      expect(p.marke, 'Erfundenwerk');
    });

    test('Suche: ohne brands, leere Liste oder lauter leere Texte — keine '
        'Marke', () async {
      for (final marken in const <List<String>?>[
        null,
        [],
        ['', '  '],
      ]) {
        final c = mit((_) => json(suchAntwort([treffer(marken: marken)])));

        final p = einziges(await c.client.suche('Hafer'));

        expect(p.marke, isNull, reason: 'brands: $marken');
      }
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Namenssuche', () {
    test('fragt search.openfoodfacts.org/search mit q, langs=de, '
        '50 Treffern und den nötigen Feldern', () async {
      final c = mit((_) => json(suchAntwort([treffer()])));

      await c.client.suche('Haferflocken');

      expect(c.anfragen, hasLength(1));
      final url = c.anfragen.single.url;
      final q = url.queryParameters;
      expect(c.anfragen.single.method, 'GET');
      expect(url.scheme, 'https');
      expect(
        url.host,
        'search.openfoodfacts.org',
        reason:
            '/cgi/search.pl auf world.openfoodfacts.org antwortete am '
            '04.11.2026 drei von drei Malen mit HTTP 503',
      );
      expect(url.path, '/search');
      expect(q['q'], 'Haferflocken');
      expect(q['langs'], 'de');
      expect(
        q['page_size'],
        '50',
        reason:
            'gleiche Produkte werden zusammengefasst — damit danach noch 25 '
            'Zeilen übrig sind, fragt die Suche doppelt so viele',
      );
      expect(
        (q['fields'] ?? '').split(',').map((f) => f.trim()),
        containsAll(const [
          'code',
          'product_name',
          'product_name_de',
          'brands',
          'nutriments',
        ]),
        reason: 'was der Client liest, muss er anfordern. Gefunden: $url',
      );
    });

    test('der Suchtext geht ohne Ränder hinaus', () async {
      final c = mit((_) => json(suchAntwort([treffer()])));

      await c.client.suche('  Haferflocken  ');

      expect(c.anfragen.single.url.queryParameters['q'], 'Haferflocken');
    });

    test('Treffer in der Reihenfolge des Servers, je mit eigenem Strichcode', () async {
      final c = mit(
        (_) => json(
          suchAntwort([
            treffer(),
            treffer(
              code: barcodeSkyr,
              name: 'Skyr Prüfhof',
              naehrwerte: const {'energy-kcal_100g': 63, 'proteins_100g': 11},
            ),
          ]),
        ),
      );

      final produkte = alle(await c.client.suche('Prüf'));

      expect(produkte.map((p) => p.barcode), [barcodeHafer, barcodeSkyr]);
      expect(produkte.map((p) => p.name), [
        'Haferflocken Prüfmühle',
        'Skyr Prüfhof',
      ]);
      expect(produkte[1].je100g.kcal, 63);
      expect(produkte[1].je100g.fettG, isNull);
    });

    test('Produkte ohne Namen fallen weg', () async {
      final c = mit(
        (_) => json(
          suchAntwort([
            treffer(code: barcodeOhneName, name: null),
            treffer(),
            treffer(code: '0000000000048', name: '   '),
          ]),
        ),
      );

      final produkte = alle(await c.client.suche('Hafer'));

      expect(produkte.map((p) => p.barcode), [barcodeHafer]);
    });

    test('Produkte ohne Strichcode fallen weg', () async {
      final c = mit(
        (_) => json(
          suchAntwort([
            treffer(code: null, name: 'Haferflocken ohne Code'),
            treffer(),
          ]),
        ),
      );

      final produkte = alle(await c.client.suche('Hafer'));

      expect(produkte.map((p) => p.barcode), [barcodeHafer]);
    });

    test('Produkte ohne Kalorien liefert der Client mit, nicht buchbar — '
        'verworfen werden sie erst in der Trefferliste', () async {
      final c = mit(
        (_) => json(
          suchAntwort([
            treffer(naehrwerte: const {'proteins_100g': 12}),
          ]),
        ),
      );

      final p = einziges(await c.client.suche('Hafer'));

      expect(p.buchbar, isFalse);
      expect(p.je100g.kcal, isNull);
    });

    test('keine Produkte ist NichtGefunden', () async {
      final c = mit((_) => json(suchAntwort(const [])));

      expect(await c.client.suche('Hafer'), isA<NichtGefunden>());
    });

    test('nur namenlose Produkte ist NichtGefunden, kein leerer Treffer', () async {
      final c = mit(
        (_) => json(
          suchAntwort([
            treffer(name: null),
            treffer(code: barcodeOhneName, name: ''),
          ]),
        ),
      );

      expect(await c.client.suche('Hafer'), isA<NichtGefunden>());
    });

    test('höchstens 50 Treffer, auch wenn der Server mehr schickt', () async {
      final c = mit(
        (_) => json(
          suchAntwort([
            for (var i = 0; i < 60; i++)
              treffer(
                code: '00000000${(100 + i).toString().padLeft(5, '0')}',
                name: 'Prüfprodukt $i',
              ),
          ]),
        ),
      );

      final produkte = alle(await c.client.suche('Prüf'));

      expect(produkte.length, lessThanOrEqualTo(50));
    });

    test('bis 50 kommen alle an — abgeschnitten wird erst nach dem '
        'Zusammenfassen', () async {
      final c = mit(
        (_) => json(
          suchAntwort([
            for (var i = 0; i < 40; i++)
              treffer(
                code: '00000000${(100 + i).toString().padLeft(5, '0')}',
                name: 'Prüfprodukt $i',
              ),
          ]),
        ),
      );

      final produkte = alle(await c.client.suche('Prüf'));

      expect(
        produkte.map((p) => p.name),
        [for (var i = 0; i < 40; i++) 'Prüfprodukt $i'],
        reason:
            'vierzig verschiedene Produkte, in der Reihenfolge des Servers — '
            'ein Client, der schon hier auf 25 kürzt, ließe nach dem '
            'Zusammenfassen zu wenig übrig',
      );
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Kein Netz ist nicht „nicht gefunden"', () {
    test('eine SocketException ist KeinNetz — bei beiden Wegen', () async {
      final c = mit(
        (_) => throw const SocketException('Netz weg (erfunden)'),
      );

      expect(await c.client.suche('Hafer'), isA<KeinNetz>());
      expect(await c.client.produktZuBarcode(barcodeHafer), isA<KeinNetz>());
    });

    test('eine ClientException ist KeinNetz', () async {
      final c = mit(
        (anfrage) => throw http.ClientException('Verbindung zu', anfrage.url),
      );

      expect(await c.client.suche('Hafer'), isA<KeinNetz>());
      expect(await c.client.produktZuBarcode(barcodeHafer), isA<KeinNetz>());
    });

    test('ein Serverfehler ist KeinNetz, nicht NichtGefunden', () async {
      for (final status in const [500, 502, 503, 429]) {
        final c = mit((_) => json({'error': 'erfunden'}, status: status));

        expect(
          await c.client.suche('Hafer'),
          isA<KeinNetz>(),
          reason:
              'HTTP $status: Niemand hat nachgesehen. „Nicht gefunden" '
              'behauptete, Open Food Facts kenne nichts dazu',
        );
        expect(
          await c.client.produktZuBarcode(barcodeHafer),
          isA<KeinNetz>(),
          reason: 'HTTP $status beim Strichcode',
        );
      }
    });

    test('ein unlesbarer Körper ist KeinNetz, nicht NichtGefunden', () async {
      final c = mit(
        (_) => http.Response(
          '<html><body>Wartung (erfunden)</body></html>',
          200,
          headers: const {'content-type': 'text/html; charset=utf-8'},
        ),
      );

      expect(await c.client.suche('Hafer'), isA<KeinNetz>());
      expect(await c.client.produktZuBarcode(barcodeHafer), isA<KeinNetz>());
    });

    // `testWidgets` und nicht `test`: Nur dort läuft die Uhr unter
    // Kontrolle des Tests. Fünf echte Sekunden je Fall wären zu langsam,
    // und eine eingesetzte kürzere Grenze bewiese die fünf nicht.
    testWidgets('nach 5 Sekunden ohne Antwort: KeinNetz — vorher nicht', (
      tester,
    ) async {
      for (final weg in ['suche', 'barcode']) {
        final c = mit((_) => Completer<http.Response>().future);
        OffErgebnis? ergebnis;
        final anfrage = weg == 'suche'
            ? c.client.suche('Hafer')
            : c.client.produktZuBarcode(barcodeHafer);
        unawaited(anfrage.then((e) => ergebnis = e));

        await tester.pump(const Duration(milliseconds: 4900));
        expect(
          ergebnis,
          isNull,
          reason: '$weg: Die Grenze ist 5 Sekunden, nicht weniger',
        );

        await tester.pump(const Duration(milliseconds: 150));
        expect(
          ergebnis,
          isA<KeinNetz>(),
          reason: '$weg: Nach 5 Sekunden ist Schluss (Brief, Spec)',
        );
      }
    });

    testWidgets('eine Antwort nach 4,5 Sekunden gilt noch', (tester) async {
      final c = mit((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 4500));
        return json(suchAntwort([treffer()]));
      });
      OffErgebnis? ergebnis;
      unawaited(c.client.suche('Hafer').then((e) => ergebnis = e));

      await tester.pump(const Duration(milliseconds: 4600));

      expect(ergebnis, isA<Treffer>());
      // Den Rest der Grenze verstreichen lassen, damit kein Zeitgeber
      // über das Testende hinaus hängt.
      await tester.pump(const Duration(seconds: 1));
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Die Anfrage weist sich aus', () {
    test('mit eigenem User-Agent, nicht mit Darts Vorgabe', () async {
      final c = mit((_) => json(suchAntwort([treffer()])));

      await c.client.suche('Hafer');
      await c.client.produktZuBarcode(barcodeHafer);

      for (final anfrage in c.anfragen) {
        final kennung = anfrage.headers.entries
            .where((e) => e.key.toLowerCase() == 'user-agent')
            .map((e) => e.value)
            .firstOrNull;
        expect(
          kennung,
          isNotNull,
          reason:
              'Open Food Facts verlangt einen eigenen User-Agent und sperrt '
              'sonst auf Verdacht',
        );
        expect(kennung!.trim(), isNotEmpty);
        expect(kennung, isNot(startsWith('Dart/')));
        expect(
          kennung,
          isNot(contains('@')),
          reason: 'keine E-Mail-Adresse im Quelltext',
        );
      }
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Vom Produkt zur Vorlage', () {
    test('alsVorlage: ohne Schlüssel, Herkunft off, mit Strichcode', () {
      const je100g = Naehrwerte.je100g(kcal: 371, eiweissG: 12.5);
      const p = OffProdukt(
        barcode: barcodeHafer,
        name: 'Haferflocken Prüfmühle',
        je100g: je100g,
      );

      final v = p.alsVorlage();

      expect(
        v.id,
        isNull,
        reason: 'angelegt wird erst beim Buchen, und den Schlüssel vergibt '
            'die Datenbank',
      );
      expect(v.herkunft, Herkunft.off);
      expect(v.barcode, barcodeHafer);
      expect(v.name, 'Haferflocken Prüfmühle');
      expect(v.je100g, je100g);
      expect(v.zuletztBenutzt, isNull, reason: 'gefunden ist nicht benutzt');
    });

    test('OffProdukt hat Wertgleichheit', () {
      const a = OffProdukt(
        barcode: barcodeHafer,
        name: 'Haferflocken Prüfmühle',
        marke: 'Erfundenwerk',
        je100g: Naehrwerte.je100g(kcal: 371),
      );
      const b = OffProdukt(
        barcode: barcodeHafer,
        name: 'Haferflocken Prüfmühle',
        marke: 'Erfundenwerk',
        je100g: Naehrwerte.je100g(kcal: 371),
      );
      const anders = OffProdukt(
        barcode: barcodeSkyr,
        name: 'Haferflocken Prüfmühle',
        marke: 'Erfundenwerk',
        je100g: Naehrwerte.je100g(kcal: 371),
      );

      // Die Trefferliste ist Abhängigkeit eines Providers. Ohne `==`
      // rechnete jeder Lauf alles Abgeleitete neu — Fehler `03`.
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(anders));
    });
  });
}
