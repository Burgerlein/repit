// Der Client für **Gemini** (#338) — Modellliste, Foto-Schätzung und
// Testbild. Der einzige Weg der App zur KI; Schirme erreichen ihn
// ausschließlich über [kiAnbieterProvider].
//
// API und Vertrag sind durch `app/test/ki/gemini_client_test.dart`
// verbindlich vorgegeben (siehe dessen Dateikopf) — diese Datei darf die
// Tests ausführen, aber nicht verändern (`CLAUDE.md`, „Wer Tests schreibt,
// schreibt nicht die Implementierung").
//
// ## Der Schlüssel
//
// Er geht **nur** im Kopf `x-goog-api-key` mit — nie als `?key=` in der
// URL, nie im Körper, nie in einem Log. Kein Fehler nennt ihn: Die
// Fehlertypen tragen nur Status, Stufe und Verbrauch, nie den Körper der
// Serverantwort — Google schickt einen abgelehnten Schlüssel dort
// gelegentlich zurück. Gelesen wird der Körper eines Fehlers nur, um
// `API_KEY_INVALID` und `FreeTier` zu erkennen.
//
// ## Namenskonflikt
//
// `KeinNetz` gibt es auch in `lib/ernaehrung/off_client.dart` (dort ein
// Ergebnis von Open Food Facts, hier ein [KiFehler]). Wer beide Dateien
// importiert, braucht für eine davon ein Präfix.
import 'dart:async';
import 'dart:convert';
import 'dart:io' show IOException;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:trainings_core/trainings_core.dart';

// ---------------------------------------------------------------------------
// Fehler

/// Was bei einer Anfrage an Gemini schiefgehen kann — **geworfen**, nicht
/// zurückgegeben.
///
/// `toString` nennt nie den Schlüssel und nie den Körper der
/// Serverantwort, nur den Fall.
sealed class KiFehler implements Exception {
  const KiFehler();
}

/// Google lehnt den Schlüssel ab: 400 mit `API_KEY_INVALID`, 401 oder 403.
final class SchluesselAbgelehnt extends KiFehler {
  const SchluesselAbgelehnt();

  @override
  bool operator ==(Object other) => other is SchluesselAbgelehnt;

  @override
  int get hashCode => (SchluesselAbgelehnt).hashCode;

  @override
  String toString() => 'SchluesselAbgelehnt()';
}

/// 429 — das Kontingent ist erschöpft.
final class Kontingent extends KiFehler {
  const Kontingent({required this.kostenloseStufe});

  /// `true` nur, wenn eine `quotaId` einer `QuotaFailure` auf `FreeTier`
  /// endet. Ohne lesbare Angabe `false`: Die Stufe ist dann unbekannt,
  /// nicht „bezahlt".
  final bool kostenloseStufe;

  @override
  bool operator ==(Object other) =>
      other is Kontingent && other.kostenloseStufe == kostenloseStufe;

  @override
  int get hashCode => Object.hash(Kontingent, kostenloseStufe);

  @override
  String toString() => 'Kontingent(kostenloseStufe: $kostenloseStufe)';
}

/// Gemini war nicht zu erreichen: keine Verbindung, abgebrochen oder nach
/// 60 s keine Antwort — **niemand hat geprüft**, ob der Schlüssel taugt.
final class KeinNetz extends KiFehler {
  const KeinNetz();

  @override
  bool operator ==(Object other) => other is KeinNetz;

  @override
  int get hashCode => (KeinNetz).hashCode;

  @override
  String toString() => 'KeinNetz()';
}

/// 200, aber die Antwort ist unlesbar oder verletzt das Schema.
final class AntwortUnbrauchbar extends KiFehler {
  const AntwortUnbrauchbar({this.verbrauch});

  /// Was Google trotzdem gezählt hat — `null`, wenn die Antwort keine
  /// lesbaren Zähler trägt (dann gibt es nichts zu buchen). Festlegung
  /// des Test-Agenten, siehe Kopf von `gemini_client_test.dart`.
  final KiVerbrauch? verbrauch;

  @override
  bool operator ==(Object other) =>
      other is AntwortUnbrauchbar && other.verbrauch == verbrauch;

  @override
  int get hashCode => Object.hash(AntwortUnbrauchbar, verbrauch);

  @override
  String toString() => 'AntwortUnbrauchbar(verbrauch: $verbrauch)';
}

/// Alles andere: 5xx und die übrigen 4xx, auch ein 400 ohne
/// `API_KEY_INVALID` — sonst hieße jede kaputte Anfrage „Schlüssel
/// ungültig".
final class Sonstiges extends KiFehler {
  const Sonstiges({this.status});

  /// Der HTTP-Status, falls es einen gab.
  final int? status;

  @override
  bool operator ==(Object other) =>
      other is Sonstiges && other.status == status;

  @override
  int get hashCode => Object.hash(Sonstiges, status);

  @override
  String toString() => 'Sonstiges(status: $status)';
}

// ---------------------------------------------------------------------------
// Schnittstelle

/// Der Weg zur KI. Jede Methode wirft bei Misserfolg einen [KiFehler].
abstract interface class KiAnbieter {
  /// Die Modelle, die sich für die Foto-Schätzung eignen — gefiltert und
  /// sortiert mit [fotoModelle]. Live geholt, über alle Seiten; scheitert
  /// eine Seite, scheitert der ganze Aufruf.
  Future<List<KiModell>> modelle(String schluessel);

  /// Schätzt das Essen auf [jpeg]. [hinweis] und [feste] gehen mit; wo
  /// Hinweis und Foto sich widersprechen, gilt der Hinweis.
  Future<({SchaetzAntwort antwort, KiVerbrauch verbrauch})> schaetze({
    required String schluessel,
    required String modell,
    required List<int> jpeg,
    String? hinweis,
    List<SchaetzPosten> feste = const [],
  });

  /// Schickt ein winziges JPEG an [modell]. Jedes 200 gilt, egal was im
  /// Text steht; zurück kommt, was Google dafür gezählt hat.
  Future<KiVerbrauch> testbild({
    required String schluessel,
    required String modell,
  });
}

// ---------------------------------------------------------------------------
// Gemini

/// [KiAnbieter] gegen die Gemini-API (`v1beta`).
class GeminiAnbieter implements KiAnbieter {
  /// [client] wird eingesetzt — im Betrieb `http.Client()`, in Tests ein
  /// `MockClient`. Geschlossen wird er von dem, der ihn anlegt
  /// ([kiAnbieterProvider]).
  GeminiAnbieter(this._client);

  final http.Client _client;

  @override
  Future<List<KiModell>> modelle(String schluessel) => _mitFrist(() async {
    final roh = <Map<String, Object?>>[];
    String? seite;
    do {
      final uri = _basis
          .resolve('models')
          .replace(
            queryParameters: {
              'pageSize': '$_seitenGroesse',
              'pageToken': ?seite,
            },
          );
      final antwort = await _client.get(uri, headers: _kopf(schluessel));
      _pruefeStatus(antwort);

      final json = _leseJson(antwort);
      if (json is! Map<String, Object?>) throw const AntwortUnbrauchbar();
      final liste = json['models'] ?? const <Object?>[];
      if (liste is! List) throw const AntwortUnbrauchbar();
      for (final eintrag in liste) {
        if (eintrag is! Map<String, Object?>) {
          throw const AntwortUnbrauchbar();
        }
        roh.add(eintrag);
      }
      final weiter = json['nextPageToken'];
      seite = weiter is String && weiter.isNotEmpty ? weiter : null;
    } while (seite != null);

    try {
      return fotoModelle(roh);
    } on FormatException {
      throw const AntwortUnbrauchbar();
    }
  });

  @override
  Future<({SchaetzAntwort antwort, KiVerbrauch verbrauch})> schaetze({
    required String schluessel,
    required String modell,
    required List<int> jpeg,
    String? hinweis,
    List<SchaetzPosten> feste = const [],
  }) => _mitFrist(() async {
    final antwort = await _generiere(schluessel, modell, {
      'systemInstruction': {
        'parts': [
          {'text': _prompt},
        ],
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            _bildTeil(jpeg),
            for (final text in _zusaetze(hinweis, feste)) {'text': text},
          ],
        },
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'responseJsonSchema': _antwortSchema,
      },
    });

    final json = _leseJson(antwort);
    if (json is! Map<String, Object?>) throw const AntwortUnbrauchbar();
    final verbrauch = _verbrauchAus(json);
    try {
      final text = _antwortText(json);
      final inhalt = jsonDecode(text);
      if (inhalt is! Map<String, Object?>) {
        throw const FormatException('Die Antwort ist kein Objekt');
      }
      return (
        antwort: leseAntwort(inhalt),
        verbrauch: verbrauch ?? _keinVerbrauch,
      );
    } on FormatException {
      throw AntwortUnbrauchbar(verbrauch: verbrauch);
    }
  });

  @override
  Future<KiVerbrauch> testbild({
    required String schluessel,
    required String modell,
  }) => _mitFrist(() async {
    final antwort = await _generiere(schluessel, modell, {
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': 'Antworte mit OK'},
            _bildTeil(_testbildJpeg),
          ],
        },
      ],
    });
    // Jedes 200 gilt (Spec). Was nicht lesbar ist, zählt nichts.
    final json = _leseJson(antwort);
    return (json is Map<String, Object?> ? _verbrauchAus(json) : null) ??
        _keinVerbrauch;
  });

  /// `POST models/<modell>:generateContent` — prüft den Status und gibt
  /// die Antwort zurück.
  Future<http.Response> _generiere(
    String schluessel,
    String modell,
    Map<String, Object?> koerper,
  ) async {
    final uri = _basis.resolve(
      'models/${Uri.encodeComponent(modell)}:generateContent',
    );
    final antwort = await _client.post(
      uri,
      headers: {
        ..._kopf(schluessel),
        'content-type': 'application/json; charset=utf-8',
      },
      body: jsonEncode(koerper),
    );
    _pruefeStatus(antwort);
    return antwort;
  }
}

/// Der Client für den Riverpod-Baum — in Tests mit
/// `kiAnbieterProvider.overrideWithValue(…)` ersetzt.
final kiAnbieterProvider = Provider<KiAnbieter>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return GeminiAnbieter(client);
});

// ---------------------------------------------------------------------------
// Transport

final _basis = Uri.parse('https://generativelanguage.googleapis.com/v1beta/');

/// So viele Modelle je Seite, wie Google zulässt.
const _seitenGroesse = 1000;

/// **60 s**, dann ist Schluss — für jeden Aufruf als Ganzes, über alle
/// Seiten der Modellliste hinweg. Ein Schlüsselprüfen, das ohne Netz nie
/// endet, ließe den Schirm ewig „prüft" sagen.
const _frist = Duration(seconds: 60);

const _keinVerbrauch = KiVerbrauch(eingabe: 0, ausgabe: 0, denken: 0);

Map<String, String> _kopf(String schluessel) => {'x-goog-api-key': schluessel};

/// Führt [arbeit] mit [_frist] aus und übersetzt Netzfehler in
/// [KeinNetz]. Ein [KiFehler] geht unverändert durch; alles andere ist ein
/// Programmierfehler und wird nicht verschluckt.
Future<T> _mitFrist<T>(Future<T> Function() arbeit) async {
  try {
    return await arbeit().timeout(_frist);
  } on KiFehler {
    rethrow;
  } on TimeoutException {
    throw const KeinNetz();
  } on IOException {
    // `SocketException`, `HandshakeException`, `HttpException`.
    throw const KeinNetz();
  } on http.ClientException {
    throw const KeinNetz();
  }
}

/// Wirft den passenden [KiFehler], wenn [antwort] kein 2xx ist.
void _pruefeStatus(http.Response antwort) {
  final status = antwort.statusCode;
  if (status >= 200 && status < 300) return;
  final details = _fehlerDetails(antwort);
  switch (status) {
    case 400 when details.any((d) => d['reason'] == 'API_KEY_INVALID'):
    case 401:
    case 403:
      throw const SchluesselAbgelehnt();
    case 429:
      throw Kontingent(kostenloseStufe: _kostenloseStufe(details));
    default:
      throw Sonstiges(status: status);
  }
}

/// `error.details` eines Fehlerkörpers — leer, wenn der Körper sie nicht
/// lesbar trägt.
List<Map<String, Object?>> _fehlerDetails(http.Response antwort) {
  final Object? json;
  try {
    json = _leseJson(antwort);
  } on AntwortUnbrauchbar {
    return const [];
  }
  if (json is! Map<String, Object?>) return const [];
  final fehler = json['error'];
  if (fehler is! Map<String, Object?>) return const [];
  final details = fehler['details'];
  if (details is! List) return const [];
  return [
    for (final d in details)
      if (d is Map<String, Object?>) d,
  ];
}

/// `true`, wenn eine `quotaId` einer `QuotaFailure` auf `FreeTier` endet.
/// Die Form stammt aus Forenberichten; Task 11 prüft sie an einem echten
/// 429.
bool _kostenloseStufe(List<Map<String, Object?>> details) {
  for (final d in details) {
    final verstoesse = d['violations'];
    if (verstoesse is! List) continue;
    for (final v in verstoesse) {
      if (v is! Map<String, Object?>) continue;
      final quotaId = v['quotaId'];
      if (quotaId is String && quotaId.endsWith('FreeTier')) return true;
    }
  }
  return false;
}

/// Der Körper als JSON. `bodyBytes` und nicht `body`: Ohne Zeichensatz im
/// Kopf fiele `body` auf Latin-1 zurück; Google schickt UTF-8.
Object? _leseJson(http.Response antwort) {
  try {
    return jsonDecode(utf8.decode(antwort.bodyBytes));
  } on FormatException {
    throw const AntwortUnbrauchbar();
  }
}

/// `usageMetadata` als [KiVerbrauch] — `null`, wenn es fehlt oder nicht
/// lesbar ist.
KiVerbrauch? _verbrauchAus(Map<String, Object?> json) {
  final usage = json['usageMetadata'];
  if (usage is! Map<String, Object?>) return null;
  try {
    return KiVerbrauch.ausUsage(usage);
  } on FormatException {
    return null;
  }
}

/// Der Antworttext aus `candidates[0].content.parts` — der erste Teil mit
/// Text, der kein Gedanke ist. Wirft [FormatException], wenn es keinen
/// gibt (etwa bei einer blockierten Anfrage ohne Kandidaten).
String _antwortText(Map<String, Object?> json) {
  final kandidaten = json['candidates'];
  if (kandidaten is! List || kandidaten.isEmpty) {
    throw const FormatException('Keine Kandidaten');
  }
  final erster = kandidaten.first;
  final inhalt = erster is Map<String, Object?> ? erster['content'] : null;
  final teile = inhalt is Map<String, Object?> ? inhalt['parts'] : null;
  if (teile is! List) throw const FormatException('Keine Teile');
  for (final teil in teile) {
    if (teil is! Map<String, Object?> || teil['thought'] == true) continue;
    final text = teil['text'];
    if (text is String) return text;
  }
  throw const FormatException('Kein Text');
}

Map<String, Object?> _bildTeil(List<int> jpeg) => {
  'inline_data': {'mime_type': 'image/jpeg', 'data': base64Encode(jpeg)},
};

// ---------------------------------------------------------------------------
// Prompt und Schema

/// Die Anweisung an das Modell — Pflichtinhalte aus der Spec („Prompt").
const _prompt = '''
Du schätzt Mahlzeiten auf Fotos für ein Ernährungstagebuch.

- Schätze jeden sichtbaren Bestandteil einzeln, mit Gramm. Nimm Tellergröße und Besteck als Maßstab.
- Öl, Butter und Soßen sind eigene Posten. Ist ihre Menge nicht schätzbar, setze "grams": null und "confident": false, statt zu raten.
- Gramm und Nährwerte gelten für die geschätzte Menge, nicht je 100 g. Was du nicht schätzen kannst, ist null, nie 0.
- Sind mehrere Teller zu sehen, zählt der im Vordergrund oder in der Mitte.
- Ist eine Nährwerttabelle im Bild lesbar, gehen ihre Angaben vor deiner Schätzung.
- Ist kein Essen zu sehen, ist das Bild zu dunkel oder zu unscharf: "isFood": false und keine Posten.
- Namen auf Deutsch, so wie man das Lebensmittel nennt.
- Wo ein Hinweis des Nutzers und das Foto sich widersprechen, gilt der Hinweis.
- Posten, die der Nutzer bereits festgelegt hat, schätzt du nicht erneut und führst sie nicht auf.
- Keine Bewertung, keine Gesundheitsaussage — nur Lebensmittel und Mengen.
- "note" ist ein kurzer Satz zu dem, was unsicher ist, oder fehlt.''';

/// Hinweis und feste Posten als eigene Textteile.
List<String> _zusaetze(String? hinweis, List<SchaetzPosten> feste) {
  final text = hinweis?.trim();
  return [
    if (text != null && text.isNotEmpty) 'Hinweis des Nutzers: $text',
    if (feste.isNotEmpty)
      'Bereits festgelegt, nicht erneut schätzen:\n'
          '${feste.map(_festerPosten).join('\n')}',
  ];
}

String _festerPosten(SchaetzPosten p) {
  final gramm = p.gramm;
  return gramm == null
      ? '- ${p.name}, Menge unbekannt'
      : '- ${p.name}, ${_zahl(gramm)} g';
}

/// `180.0` als `180`, `12.5` als `12.5`.
String _zahl(double wert) =>
    wert == wert.roundToDouble() ? wert.toStringAsFixed(0) : '$wert';

const _zahlOderNull = {
  'type': ['number', 'null'],
};

/// `generationConfig.responseJsonSchema` — die Form aus der Spec
/// („Antwortschema"). Geprüft wird die Antwort trotzdem selbst, mit
/// [leseAntwort].
const _antwortSchema = {
  'type': 'object',
  'properties': {
    'isFood': {'type': 'boolean'},
    'title': {'type': 'string'},
    'items': {
      'type': 'array',
      'items': {
        'type': 'object',
        'properties': {
          'name': {'type': 'string'},
          'grams': _zahlOderNull,
          'kcal': _zahlOderNull,
          'proteinG': _zahlOderNull,
          'carbsG': _zahlOderNull,
          'fatG': _zahlOderNull,
          'confident': {'type': 'boolean'},
        },
        'required': [
          'name',
          'grams',
          'kcal',
          'proteinG',
          'carbsG',
          'fatG',
          'confident',
        ],
      },
    },
    'note': {'type': 'string'},
  },
  'required': ['isFood', 'items'],
};

// ---------------------------------------------------------------------------
// Testbild

/// Ein 8×8-JPEG in Grau, 635 Byte, ohne Metadaten, als Base64 — im Code,
/// damit das Testbild weder Kamera noch Datei braucht.
final _testbildJpeg = base64Decode(
  '/9j/4AAQSkZJRgABAQAASABIAAD/wAARCAAIAAgDASIAAhEBAxEB/8QAHwAAAQUB'
  'AQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQID'
  'AAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0'
  'NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKT'
  'lJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl'
  '5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL'
  '/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHB'
  'CSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpj'
  'ZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3'
  'uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9sAQwAGBgYG'
  'BgYKBgYKDgoKCg4SDg4ODhIXEhISEhIXHBcXFxcXFxwcHBwcHBwcIiIiIiIiJycn'
  'JycsLCwsLCwsLCws/9sAQwEHBwcLCgsTCgoTLh8aHy4uLi4uLi4uLi4uLi4uLi4u'
  'Li4uLi4uLi4uLi4uLi4uLi4uLi4uLi4uLi4uLi4uLi4u/90ABAAB/9oADAMBAAIR'
  'AxEAPwAooooA/9k=',
);
