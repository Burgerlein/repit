// Der Client für **Open Food Facts** (#284) — Namenssuche und Produkt zum
// Strichcode. Der einzige Weg der App ins Netz für Lebensmittel; die Suche
// erreicht ihn ausschließlich über [offClientProvider].
//
// API und Vertrag sind durch `app/test/ernaehrung/off_client_test.dart`
// und, für Portion und Packung (#325),
// `app/test/ernaehrung/off_client_portionen_test.dart` verbindlich
// vorgegeben (siehe deren Dateiköpfe) — diese Datei darf die Tests
// ausführen, aber nicht verändern (`CLAUDE.md`, „Wer Tests schreibt,
// schreibt nicht die Implementierung").
//
// ## Was die echte API am 04.11.2026 geantwortet hat
//
// Die Tests laufen gegen einen `MockClient` und beweisen nicht, dass die
// App auf dem Telefon Treffer bekommt. Deshalb wurden beide Endpunkte von
// Hand gefragt:
//
// - **Die Namenssuche läuft über `search.openfoodfacts.org/search`**, nicht
//   über `/cgi/search.pl` auf `world.openfoodfacts.org`. Die alte
//   Schnittstelle antwortete am 04.11.2026 drei von drei Malen mit HTTP 503
//   und einer HTML-Seite; die neue drei von drei Malen mit 200 in unter
//   0,2 s. Parameter: `q`, `langs=de`, `page_size` (50), `fields`; die Treffer
//   stehen unter **`hits`**. Einen Länderfilter trägt die Anfrage nicht.
// - **`fields=`** schneidet die Antwort auf das, was gebraucht wird. Ohne
//   den Parameter schickt OFF je Produkt mehrere Dutzend Kilobyte.
// - Die Nährwerte heißen wirklich `energy-kcal_100g`, `proteins_100g`,
//   `carbohydrates_100g`, `fat_100g`, `sugars_100g`, `saturated-fat_100g`,
//   `fiber_100g` — Zahlen, mal ganz, mal gebrochen. `energy_100g` ist
//   Kilojoule (es stand bei jedem Produkt gleich `energy-kj_100g`).
//   Produkte ohne Kalorienangabe gibt es: Sie tragen dann nur
//   `energy-kj_100g` und werden umgerechnet (siehe [_kcalAus]).
// - **`brands` hat zwei Formen:** In der Suche eine Liste von Texten, beim
//   Strichcode ein Text, oft leer (`""`).
// - **`/api/v2/product/<ean>.json`** antwortet auf einen gültigen, aber
//   unbekannten Strichcode mit **HTTP 404** und `status: 0`, auf einen
//   ungültigen mit HTTP 200 und `status: 0`.
//
// **Keine Antwort davon liegt im Repository.** Die Tests haben ihre
// eigenen, erfundenen Produkte.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:trainings_core/trainings_core.dart';

import '../data/lebensmittel_repository.dart';
import '../data/portion.dart';

/// Was eine Anfrage an Open Food Facts ergibt — **drei Fälle, nicht
/// zwei.** „Kein Netz" und „nicht hinterlegt" werden nie vermischt,
/// dieselbe Regel wie bei fehlenden HealthKit-Daten.
sealed class OffErgebnis {
  const OffErgebnis();
}

/// Mindestens ein anzeigbares Produkt — **nie leer**. Eine leere Liste ist
/// [NichtGefunden].
final class Treffer extends OffErgebnis {
  const Treffer(this.produkte);

  final List<OffProdukt> produkte;

  @override
  bool operator ==(Object other) =>
      other is Treffer && listEquals(other.produkte, produkte);

  @override
  int get hashCode => Object.hashAll(produkte);
}

/// Open Food Facts hat geantwortet und kennt nichts Anzeigbares.
final class NichtGefunden extends OffErgebnis {
  const NichtGefunden();
}

/// Open Food Facts war nicht zu erreichen oder hat nicht lesbar
/// geantwortet — **niemand hat nachgesehen**.
final class KeinNetz extends OffErgebnis {
  const KeinNetz();
}

/// Ein Produkt aus Open Food Facts — Nährwerte **je 100 g**.
///
/// **Werttyp mit [==] und [hashCode] über alle Felder.** Die Trefferliste
/// ist Abhängigkeit eines Providers; ohne Wertgleichheit liefe jeder
/// abgeleitete Wert bei jedem Lauf neu — Fehler `03`.
@immutable
class OffProdukt {
  const OffProdukt({
    required this.barcode,
    required this.name,
    this.marke,
    required this.je100g,
    this.portionen,
    this.fluessig = false,
  });

  /// Der Strichcode — woran die eigene Tabelle das Produkt nach dem
  /// Übernehmen wiedererkennt.
  final String barcode;

  /// `product_name_de`, sonst `product_name` — nie leer.
  final String name;

  /// `brands` — `null`, wenn leer oder fehlend.
  final String? marke;

  /// Ein fehlendes Feld ist `null`, **nie `0`**: Eine Null behauptete
  /// „enthält nichts davon" (Fehler `01` unterhalb von allem).
  final Naehrwerte je100g;

  /// **Ohne Kalorien kein Eintrag.** Der Client reicht solche Produkte
  /// trotzdem durch — er ist Transport, nicht Filter. Verworfen werden sie
  /// erst in der Trefferliste der Suche
  /// (`LebensmittelDubletten.zeilen`, seit dem 04.11.2026).
  bool get buchbar => je100g.kcal != null;

  /// Portion und Packung aus Open Food Facts (#325), gefiltert nach den
  /// Regeln im Kern ([offPortionen]). **`null` heißt „nicht abgefragt"**
  /// — so steht es bei jedem Suchtreffer, denn der Suchindex kennt die
  /// Felder nicht. **`[]` heißt „gefragt, keine"** — der
  /// Strichcode-Endpunkt hat geantwortet und nichts Brauchbares geliefert.
  /// Die beiden werden nicht vermischt, aus demselben Grund, aus dem ein
  /// fehlender Messwert nicht `0` ist.
  final List<Portion>? portionen;

  /// Ob `product_quantity_unit` oder `serving_quantity_unit` gleich `ml`
  /// ist (Entscheidung 10 aus #325). Bei Suchtreffern immer `false` —
  /// nicht abgefragt.
  final bool fluessig;

  /// Die Vorlage, die beim Buchen in die eigene Tabelle wandert: ohne
  /// Schlüssel (den vergibt die Datenbank), mit Herkunft
  /// [Herkunft.off] und Strichcode, ohne `zuletztBenutzt` — gefunden ist
  /// nicht benutzt. [fluessig] und [portionen] gehen mit, `null` bleibt
  /// `null`.
  LebensmittelVorlage alsVorlage() => LebensmittelVorlage(
    name: name,
    je100g: je100g,
    fluessig: fluessig,
    barcode: barcode,
    herkunft: Herkunft.off,
    offPortionen: portionen,
  );

  @override
  bool operator ==(Object other) =>
      other is OffProdukt &&
      other.barcode == barcode &&
      other.name == name &&
      other.marke == marke &&
      other.je100g == je100g &&
      listEquals(other.portionen, portionen) &&
      other.fluessig == fluessig;

  @override
  int get hashCode => Object.hash(
    barcode,
    name,
    marke,
    je100g,
    portionen == null ? null : Object.hashAll(portionen!),
    fluessig,
  );

  @override
  String toString() =>
      'OffProdukt(barcode: $barcode, name: $name, marke: $marke, '
      'je100g: $je100g, portionen: $portionen, fluessig: $fluessig)';
}

/// Fragt Open Food Facts — **und wirft nie.** Was schiefgeht, ist
/// [KeinNetz] oder [NichtGefunden], nicht eine Ausnahme, die ein Schirm
/// fangen müsste.
class OffClient {
  OffClient({required this.client});

  /// Der eingesetzte HTTP-Client — im Betrieb `http.Client()`, in Tests
  /// ein `MockClient`. Geschlossen wird er von dem, der ihn anlegt
  /// ([offClientProvider]).
  final http.Client client;

  /// Die Namenssuche über `search.openfoodfacts.org` — deutsche Namen
  /// bevorzugt, **ohne Länderfilter**.
  Future<OffErgebnis> suche(String text) async {
    final uri = Uri.https(_suchHost, '/search', {
      'q': text.trim(),
      'langs': 'de',
      'page_size': '$_hoechstens',
      'fields': _felder,
    });

    final (:fertig, :json) = await _hole(uri);
    if (fertig != null) return fertig;

    if (json is! Map<String, dynamic>) return const KeinNetz();
    final liste = json['hits'];
    if (liste is! List) return const KeinNetz();

    final produkte = <OffProdukt>[];
    for (final eintrag in liste) {
      if (produkte.length == _hoechstens) break;
      if (eintrag is! Map<String, dynamic>) continue;
      final produkt = _produktAus(eintrag);
      if (produkt != null) produkte.add(produkt);
    }
    return produkte.isEmpty ? const NichtGefunden() : Treffer(produkte);
  }

  /// Das Produkt zu einem Strichcode.
  Future<OffErgebnis> produktZuBarcode(String ean) async {
    // Maskiert, damit ein Schrägstrich im Strichcode keinen anderen Pfad
    // fragt.
    final code = Uri.encodeComponent(ean.trim());
    final uri = Uri.https(_host, '/api/v2/product/$code.json', {
      'fields': _produktFelder,
    });

    final (:fertig, :json) = await _hole(uri);
    if (fertig != null) return fertig;

    if (json is! Map<String, dynamic>) return const KeinNetz();
    if (json['status'] != 1) return const NichtGefunden();
    final eintrag = json['product'];
    if (eintrag is! Map<String, dynamic>) return const NichtGefunden();

    // Der Strichcode der Anfrage gilt, wenn das Produkt selbst keinen
    // nennt — er ist genau der, nach dem gefragt wurde.
    final produkt = _produktAus(
      eintrag,
      ersatzCode: _text(json['code']),
      mitPortionen: true,
    );
    return produkt == null ? const NichtGefunden() : Treffer([produkt]);
  }

  /// Schickt die Anfrage und liest den Körper als JSON.
  ///
  /// Gibt den gelesenen Körper in `json` zurück — oder in `fertig` gleich
  /// das Ergebnis, wenn es nichts zu lesen gibt: **404 ist
  /// [NichtGefunden]** (so meldet OFF einen unbekannten Strichcode), alles
  /// andere, was kein 2xx ist, **und** jede Ausnahme, jede
  /// Zeitüberschreitung, jeder unlesbare Körper ist [KeinNetz]. „Nicht
  /// gefunden" behauptete, OFF kenne nichts dazu — und das weiß in dem
  /// Moment niemand.
  Future<({OffErgebnis? fertig, Object? json})> _hole(Uri uri) async {
    try {
      final antwort = await client
          .get(uri, headers: const {'User-Agent': _kennung})
          .timeout(_frist);
      if (antwort.statusCode == 404) {
        return (fertig: const NichtGefunden(), json: null);
      }
      if (antwort.statusCode < 200 || antwort.statusCode >= 300) {
        return (fertig: const KeinNetz(), json: null);
      }
      // `bodyBytes` und nicht `body`: `body` dekodiert nach dem
      // Zeichensatz im Kopf und fällt ohne Angabe auf Latin-1 zurück —
      // aus „Müsli" würde „MÃ¼sli". OFF schickt UTF-8.
      return (fertig: null, json: jsonDecode(utf8.decode(antwort.bodyBytes)));
    } catch (_) {
      // Bewusst alles: Socket, `ClientException`, `TimeoutException`,
      // `FormatException` aus einer HTML-Wartungsseite. Der Vertrag ist
      // „wirft nie", und jeder dieser Fälle heißt dasselbe — niemand hat
      // nachgesehen.
      return (fertig: const KeinNetz(), json: null);
    }
  }
}

/// Ein Produkt aus seinem JSON — oder `null`, wenn es nicht anzeigbar ist.
///
/// **Ohne Namen fällt es weg** (es gäbe nichts, wonach Tim es erkennt),
/// **ohne Strichcode ebenfalls** (die eigene Tabelle erkennte es nach dem
/// Übernehmen nicht wieder, und jedes Buchen legte ein neues an). **Ohne
/// Kalorien bleibt es** — nicht buchbar; ob es angezeigt wird, entscheidet
/// die Suche, nicht der Client.
///
/// **Portionen nur mit [mitPortionen]**, also nur am Strichcode-Endpunkt.
/// Ein Suchtreffer bekommt `portionen: null` („nicht abgefragt"), auch
/// wenn seine Antwort die Felder zufällig trägt — sonst hätte derselbe
/// Treffer mal `null` und mal eine Liste, und der Abruf beim Antippen wäre
/// unvorhersagbar.
OffProdukt? _produktAus(
  Map<String, dynamic> roh, {
  String? ersatzCode,
  bool mitPortionen = false,
}) {
  final name = _text(roh['product_name_de']) ?? _text(roh['product_name']);
  final barcode = _text(roh['code']) ?? ersatzCode;
  if (name == null || barcode == null) return null;

  final werte = roh['nutriments'];
  final n = werte is Map<String, dynamic> ? werte : const <String, dynamic>{};
  final angaben = mitPortionen ? _portionsAngabenAus(roh) : null;

  return OffProdukt(
    barcode: barcode,
    name: name,
    marke: _markeAus(roh['brands']),
    je100g: Naehrwerte.je100g(
      kcal: _kcalAus(n),
      eiweissG: _zahl(n['proteins_100g']),
      kohlenhydrateG: _zahl(n['carbohydrates_100g']),
      fettG: _zahl(n['fat_100g']),
      zuckerG: _zahl(n['sugars_100g']),
      gesaettigtG: _zahl(n['saturated-fat_100g']),
      ballaststoffeG: _zahl(n['fiber_100g']),
    ),
    portionen: angaben?.portionen.map(_portionAus).toList(growable: false),
    fluessig: angaben?.fluessig ?? false,
  );
}

/// Portion und Packung aus den vier Feldern — gefiltert im Kern
/// ([offPortionen]). Der Freitext `quantity` und `serving_size` werden
/// nie gelesen: keine geschätzte Portion (Entscheidungen 1 und 4 aus
/// #325).
OffPortionsAngaben _portionsAngabenAus(Map<String, dynamic> roh) =>
    offPortionen(
      portionMenge: _zahl(roh['serving_quantity']),
      portionEinheit: _einheitAus(roh['serving_quantity_unit']),
      packungMenge: _zahl(roh['product_quantity']),
      packungEinheit: _einheitAus(roh['product_quantity_unit']),
    );

/// Die Einheit als Text, wie OFF sie schickt — getrimmt und klein
/// geschrieben wird im Kern. Alles, was kein Text ist, ist keine Angabe.
String? _einheitAus(Object? wert) => wert is String ? wert : null;

/// Aus der Kernangabe die Portion der App: fester Name nach der Art
/// (Entscheidung 1 aus #325), Herkunft [Herkunft.off], ohne Schlüssel —
/// gespeichert wird erst beim Übernehmen.
Portion _portionAus(OffPortion p) => Portion(
  name: switch (p.art) {
    OffPortionsArt.portion => 'Portion',
    OffPortionsArt.packung => 'Packung',
  },
  mengeG: p.menge,
  herkunft: Herkunft.off,
);

/// Die Kalorien je 100 g — `energy-kcal_100g`, sonst aus
/// `energy-kj_100g` umgerechnet (kJ / 4,184, **ungerundet**), sonst `null`.
///
/// Das ist eine Einheitenumrechnung, keine Schätzung: Die Packung trägt
/// beide Werte, OFF hat manchmal nur einen gespeichert. Steht
/// `energy-kcal_100g` da, gewinnt es, auch wenn die Kilojoule nicht dazu
/// passen. **`energy_100g` wird nie gelesen** — es ist bei OFF Kilojoule
/// unter einem irreführenden Namen; wer es als Kalorien läse, buchte das
/// 4,2-Fache.
double? _kcalAus(Map<String, dynamic> n) {
  final kcal = _zahl(n['energy-kcal_100g']);
  if (kcal != null) return kcal;
  final kj = _zahl(n['energy-kj_100g']);
  return kj == null ? null : kj / _kjJeKcal;
}

/// Die Marke aus `brands` — in der Suche eine **Liste** von Texten (die
/// erste nicht leere Angabe gilt), beim Strichcode ein **Text**. `null`,
/// wenn nichts Lesbares dasteht.
String? _markeAus(Object? brands) {
  if (brands is List) {
    for (final angabe in brands) {
      final marke = _text(angabe);
      if (marke != null) return marke;
    }
    return null;
  }
  return _text(brands);
}

/// Ein Text ohne Ränder — `null`, wenn er fehlt oder leer ist. Nur
/// Leerzeichen gelten als leer. Ein Strichcode, der als Zahl ankommt, wird
/// zu seinem Text.
String? _text(Object? wert) {
  final text = switch (wert) {
    final String s => s.trim(),
    final int i => '$i',
    _ => null,
  };
  return text == null || text.isEmpty ? null : text;
}

/// Ein Nährwert — `null`, wenn er fehlt. **Eine gelieferte 0 bleibt 0.**
///
/// OFF liefert Zahlen; ein Text mit Zahl darin wird gelesen, alles andere
/// ist keine Angabe. Negative und nicht endliche Werte gibt es auf keiner
/// Packung und gelten ebenfalls als keine Angabe.
double? _zahl(Object? wert) {
  final zahl = switch (wert) {
    final num n => n.toDouble(),
    final String s => double.tryParse(s.trim()),
    _ => null,
  };
  if (zahl == null || !zahl.isFinite || zahl < 0) return null;
  return zahl;
}

/// Der Strichcode-Endpunkt `/api/v2/product/…`.
const _host = 'world.openfoodfacts.org';

/// Die Namenssuche. `/cgi/search.pl` auf [_host] antwortete am 04.11.2026
/// drei von drei Malen mit HTTP 503.
const _suchHost = 'search.openfoodfacts.org';

/// 1 kcal = 4,184 kJ.
const _kjJeKcal = 4.184;

/// **50, nicht 25** (Tim, 04.11.2026: „8000 mal das gleiche"). Gleiche
/// Produkte werden danach zusammengefasst
/// (`LebensmittelDubletten.zeilen`), und aus 25 Treffern zu
/// „Nutella" blieben zwölf Zeilen. Auf 25 **Zeilen** begrenzt wird erst
/// dort, nach dem Zusammenfassen — hier wäre es zu früh.
const _hoechstens = 50;

/// Fünf Sekunden, dann ist Schluss. Die eigenen Treffer stehen ohnehin
/// sofort da; länger zu warten hieße nur, länger einen Platzhalter zu
/// zeigen.
const _frist = Duration(seconds: 5);

/// Was OFF zurückschicken soll — genau die Felder, die gelesen werden.
const _felder = 'code,product_name,product_name_de,brands,nutriments';

/// Die Felder des Strichcode-Endpunkts: [_felder] plus Portion und
/// Packung (#325). **Nur hier** — der Suchindex kennt sie nicht. Die
/// Freitexte `quantity` und `serving_size` werden nicht angefragt; was
/// nicht angefragt ist, kann nicht versehentlich gelesen werden.
const _produktFelder =
    '$_felder,serving_quantity,serving_quantity_unit,'
    'product_quantity,product_quantity_unit';

/// Open Food Facts verlangt, dass eine App sich mit einem **eigenen**
/// `User-Agent` ausweist, und sperrt sonst auf Verdacht. Keine
/// E-Mail-Adresse: Das Repository ist kein Ort für Kontaktdaten.
const _kennung = 'TrainingsApp/0.1 (privates Projekt; iOS; Flutter)';

/// Der Client für den Riverpod-Baum — in Tests mit
/// `offClientProvider.overrideWithValue(OffClient(client: MockClient(…)))`
/// ersetzt.
final offClientProvider = Provider<OffClient>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return OffClient(client: client);
});
