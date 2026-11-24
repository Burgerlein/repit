import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/ki/gemini_client.dart';

/// Tests für den **Gemini-Client** (#338, Plan
/// `docs/superpowers/plans/2026-11-04-ki-zugang.md`, Task 7) — gegen einen
/// eingesetzten `http.Client`, **ohne Netz im Test**.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung**
/// (`CLAUDE.md`). Diese Datei darf ausgeführt, aber nicht verändert
/// werden; `.githooks/pre-commit` erzwingt es.
///
/// **Kein echter Schlüssel.** [_schluessel] ist erfunden und trägt das
/// Präfix eines echten Google-Schlüssels bewusst nicht.
///
/// ## Was diese Tests verbindlich vorgeben
///
/// Neu in `lib/ki/gemini_client.dart` (Schnittstelle aus dem Plan):
///
/// ```dart
/// sealed class KiFehler implements Exception { … }
/// final class SchluesselAbgelehnt extends KiFehler { … }
/// final class Kontingent extends KiFehler { final bool kostenloseStufe; }
/// final class KeinNetz extends KiFehler { … }
/// final class AntwortUnbrauchbar extends KiFehler {
///   /// Siehe „Festlegungen" unten — nicht aus dem Plan.
///   final KiVerbrauch? verbrauch;
/// }
/// final class Sonstiges extends KiFehler { final int? status; }
///
/// abstract interface class KiAnbieter {
///   Future<List<KiModell>> modelle(String schluessel);
///   Future<({SchaetzAntwort antwort, KiVerbrauch verbrauch})> schaetze({
///     required String schluessel,
///     required String modell,
///     required List<int> jpeg,
///     String? hinweis,
///     List<SchaetzPosten> feste = const [],
///   });
///   Future<KiVerbrauch> testbild({
///     required String schluessel,
///     required String modell,
///   });
/// }
///
/// class GeminiAnbieter implements KiAnbieter {
///   GeminiAnbieter(http.Client client);
/// }
///
/// final kiAnbieterProvider = Provider<KiAnbieter>(…);
/// ```
///
/// Fehler werden als [KiFehler] **geworfen** (Plan). Der Name [KeinNetz]
/// gibt es auch in `lib/ernaehrung/off_client.dart`; wer beide Dateien
/// importiert, braucht ein Präfix.
///
/// ## Aus Plan und Spec übernommen
///
/// - Basis `https://generativelanguage.googleapis.com/v1beta/`.
/// - **Der Schlüssel geht nur im Kopf `x-goog-api-key`**, nie in der URL,
///   nie im Körper (Review Focus 1). Jede abgeschickte Anfrage wird darauf
///   geprüft, nicht nur eine.
/// - `models.list`: `GET v1beta/models` mit `pageSize=1000`, Seiten über
///   `nextPageToken` → `pageToken`. Gefiltert wird mit [fotoModelle] aus
///   dem Kern — die Tests benutzen den Kern als Maßstab, statt den Filter
///   hier ein zweites Mal aufzuschreiben.
/// - `generateContent`: `POST v1beta/models/<modell>:generateContent`, das
///   JPEG als `inline_data` mit `mime_type: image/jpeg` und Base64,
///   `generationConfig.responseMimeType = application/json` und
///   `responseJsonSchema`; Hinweis und feste Posten gehen mit.
/// - Die Antwort steht in `candidates[0].content.parts[0].text` und wird mit
///   [leseAntwort] aus dem Kern geprüft; `usageMetadata` wird mit
///   [KiVerbrauch.ausUsage] gelesen.
/// - Fehlerabbildung (Spec, „Gemini-Client"):
///
/// | Antwort | Fehler |
/// |---|---|
/// | 400 mit `ErrorInfo.reason = API_KEY_INVALID`, 401, 403 | `SchluesselAbgelehnt` |
/// | 429 | `Kontingent(kostenloseStufe: …)` |
/// | `SocketException`, `ClientException`, Zeitlimit | `KeinNetz` |
/// | 200, aber unlesbar oder gegen das Schema | `AntwortUnbrauchbar` |
/// | 5xx, sonstige 4xx | `Sonstiges(status)` |
///
/// - **`kostenloseStufe` ist `true` nur, wenn eine `quotaId` einer
///   `QuotaFailure` auf `FreeTier` endet.** Die Form stammt aus
///   Forenberichten, nicht aus der Doku. Task 11 prüft sie an einem echten
///   Fehler; weicht sie ab, passt der **Test-Agent** den Fall an
///   (`TEST_AENDERN=1`), nicht der Implementierende.
/// - Zeitlimit **60 s** für die Schätzung.
/// - Testbild: ein winziges JPEG; „Antwortet das Modell mit 200, gilt es."
///
/// ## Festlegungen des Test-Agenten
///
/// **Nicht von Tim freigegeben** — jeweils mit Begründung.
///
/// - **`AntwortUnbrauchbar` trägt den Verbrauch, falls die Antwort einen
///   meldet.** Task 10 verlangt eine Zeile in `ki_anfragen` „auch bei
///   Fehlern mit `usageMetadata`", die Schnittstelle in Task 7 hat dafür
///   aber keinen Weg: Ein geworfener Fehler hat kein Rückgabe-Record. Der
///   einzige Fall, in dem Google trotz Fehler zählt, ist ein 200 ohne
///   brauchbaren Inhalt — darum genau dort ein Feld, und `null`, wenn die
///   Antwort keine Zähler trägt (dann gibt es auch nichts zu buchen).
/// - **Der Schlüssel steht in keinem `toString` eines Fehlers**, auch
///   nicht, wenn der Server ihn in seiner Fehlermeldung zurückschickt.
///   Wer den Fehlerkörper in die Meldung übernimmt, muss ihn vorher
///   bereinigen — oder lässt ihn weg.
/// - **Ein 400 ohne `API_KEY_INVALID` ist `Sonstiges(400)`**, nicht
///   „abgelehnt": Sonst hieße jede kaputte Anfrage „Schlüssel ungültig",
///   und Tim tauschte einen Schlüssel, der in Ordnung ist.
/// - **Ein 429 mit unlesbarem Körper ist `Kontingent(false)`** — der
///   Status reicht für „Kontingent", die Stufe bleibt unbekannt.
/// - **`isFood: false` ist eine Antwort, kein Fehler** ([KeinEssen]).
/// - **Scheitert die zweite Seite der Modellliste, scheitert der ganze
///   Aufruf.** Eine halbe Liste ließe das gemerkte Modell „nicht mehr
///   angeboten" erscheinen, obwohl es nur auf der fehlenden Seite stand.
/// - **Die Modellliste und das Testbild geben spätestens nach 60 s auf**
///   (früher ist erlaubt). Ein Schlüsselprüfen, das ohne Netz nie endet,
///   ließe den Schirm ewig „prüft" sagen (Review Focus 5).
/// - **Das Testbild gilt bei jedem 200**, egal was im Text steht (Spec).
///   „Winzig" heißt hier: unter 4 KB, Anfang `FF D8`, Ende `FF D9`.
/// - **Antworten sind UTF-8**, wie Google sie schickt
///   (`application/json; charset=UTF-8`); Umlaute kommen heil an.
///
/// Alle Modelle, Speisen und Zahlen hier sind **erfunden**.
void main() {
  group('der Schlüssel geht nur im Kopf mit (Review Focus 1)', () {
    test('Modellliste, Schätzung und Testbild: jede Anfrage trägt ihn im '
        'Kopf, keine in URL oder Körper', () async {
      final c = _mit((anfrage) {
        if (anfrage.method == 'GET') {
          final seite = anfrage.url.queryParameters['pageToken'];
          return _json({
            'models': [_rohModell(seite == null ? 'gemini-a' : 'gemini-b')],
            if (seite == null) 'nextPageToken': 'seite-2',
          });
        }
        return _json(
          _generateAntwort(text: jsonEncode(_rohSchaetzung), usage: _usage),
        );
      });

      await c.anbieter.modelle(_schluessel);
      await c.anbieter.schaetze(
        schluessel: _schluessel,
        modell: 'gemini-3.6-flash',
        jpeg: _jpeg,
        hinweis: 'ohne Soße',
        feste: [_festerPosten],
      );
      await c.anbieter.testbild(
        schluessel: _schluessel,
        modell: 'gemini-3.6-flash',
      );

      expect(c.anfragen, hasLength(4));
      _pruefeSchluesselNurImKopf(c.anfragen);
    });

    test('auch eine abgelehnte Anfrage trägt ihn nicht in der URL', () async {
      final c = _mit((_) => _json(_schluesselUngueltig(), 400));

      for (final weg in _wege.entries) {
        await _fehlerVon(weg.value(c.anbieter));
      }

      expect(c.anfragen, hasLength(_wege.length));
      _pruefeSchluesselNurImKopf(c.anfragen);
    });

    test('kein Fehler nennt ihn in toString — auch nicht, wenn der Server '
        'ihn zurückschickt', () async {
      final echo = 'API key not valid: $_schluessel';
      final antworten = <String, FutureOr<http.Response> Function()>{
        '400 API_KEY_INVALID': () => _json(_schluesselUngueltig(echo), 400),
        '401': () => _json(_fehler(401, 'UNAUTHENTICATED', echo), 401),
        '403': () => _json(_fehler(403, 'PERMISSION_DENIED', echo), 403),
        '429': () => _json(_fehler(429, 'RESOURCE_EXHAUSTED', echo), 429),
        '500': () => _json(_fehler(500, 'INTERNAL', echo), 500),
        '200 unbrauchbar': () => _json(
          _generateAntwort(text: 'kein JSON, $_schluessel', usage: _usage),
        ),
        'SocketException': () =>
            throw const SocketException('Verbindung abgebrochen'),
        'ClientException': () => throw http.ClientException(
          'Verbindung abgebrochen',
          Uri.parse('https://generativelanguage.googleapis.com/v1beta/'),
        ),
      };

      for (final fall in antworten.entries) {
        final c = _mit((_) => fall.value());
        for (final weg in _wege.entries) {
          // Ein 200 ist nur für die Schätzung ein Fehler: Das Testbild
          // gilt bei jedem 200, die Modellliste liest anderes.
          if (fall.key.startsWith('200') && weg.key != 'schaetze') continue;
          final fehler = await _fehlerVon(weg.value(c.anbieter));
          expect(
            fehler.toString(),
            isNot(contains(_schluessel)),
            reason:
                '${fall.key}, ${weg.key}: Kein Fehlertext enthält den '
                'Schlüssel (Spec, „Der Schlüssel")',
          );
        }
      }
    });
  });

  group('Modellliste', () {
    test(
      'zwei Seiten werden zusammengeführt und mit dem Kern gefiltert',
      () async {
        final seite1 = [
          _rohModell('gemini-3.6-flash', anzeige: 'Gemini 3.6 Flash'),
          _rohModell('gemini-3.6-flash-image'),
          _rohModell('text-embedding-9', methoden: ['embedContent']),
        ];
        final seite2 = [
          _rohModell('gemini-3.6-pro-preview', anzeige: 'Gemini 3.6 Pro'),
          _rohModell('gemini-3.1-flash', anzeige: 'Gemini 3.1 Flash'),
        ];
        final c = _mit((anfrage) {
          final token = anfrage.url.queryParameters['pageToken'];
          return token == null
              ? _json({'models': seite1, 'nextPageToken': 'erfunden-seite-2'})
              : _json({'models': seite2});
        });

        final modelle = await c.anbieter.modelle(_schluessel);

        expect(modelle, fotoModelle([...seite1, ...seite2]));
        expect(
          modelle.map((m) => m.id),
          contains('gemini-3.1-flash'),
          reason: 'Ein Modell, das nur auf Seite 2 steht, fehlt nicht',
        );

        expect(
          c.anfragen,
          hasLength(2),
          reason: 'Ohne nextPageToken ist nach Seite 2 Schluss',
        );
        for (final a in c.anfragen) {
          expect(a.method, 'GET');
          expect(a.url.host, 'generativelanguage.googleapis.com');
          expect(a.url.path, '/v1beta/models');
          expect(a.url.queryParameters['pageSize'], '1000');
        }
        expect(
          c.anfragen[0].url.queryParameters.containsKey('pageToken'),
          isFalse,
        );
        expect(
          c.anfragen[1].url.queryParameters['pageToken'],
          'erfunden-seite-2',
        );
      },
    );

    test('scheitert Seite 2, scheitert der ganze Aufruf', () async {
      final c = _mit((anfrage) {
        final token = anfrage.url.queryParameters['pageToken'];
        return token == null
            ? _json({
                'models': [_rohModell('gemini-3.6-flash')],
                'nextPageToken': 'erfunden-seite-2',
              })
            : _json(_fehler(500, 'INTERNAL', 'erfunden'), 500);
      });

      final fehler = await _fehlerVon(c.anbieter.modelle(_schluessel));
      expect(fehler, isA<Sonstiges>());
    });

    test('200 mit unlesbarem Körper → AntwortUnbrauchbar', () async {
      final c = _mit((_) => http.Response('<html>Wartung</html>', 200));
      expect(
        await _fehlerVon(c.anbieter.modelle(_schluessel)),
        isA<AntwortUnbrauchbar>(),
      );
    });

    test(
      '200 mit Feld vom falschen Typ (Kern wirft) → AntwortUnbrauchbar',
      () async {
        final c = _mit(
          (_) => _json({
            'models': [
              {
                'name': 42,
                'supportedGenerationMethods': ['generateContent'],
              },
            ],
          }),
        );
        expect(
          await _fehlerVon(c.anbieter.modelle(_schluessel)),
          isA<AntwortUnbrauchbar>(),
        );
      },
    );
  });

  group('Fehlerabbildung — für Modellliste, Schätzung und Testbild', () {
    Future<void> erwarte(
      FutureOr<http.Response> Function() antwort,
      Matcher passt,
      String fall,
    ) async {
      for (final weg in _wege.entries) {
        final c = _mit((_) => antwort());
        final fehler = await _fehlerVon(weg.value(c.anbieter));
        expect(fehler, passt, reason: '$fall, ${weg.key}');
      }
    }

    test('400 mit API_KEY_INVALID → SchluesselAbgelehnt', () async {
      await erwarte(
        () => _json(_schluesselUngueltig(), 400),
        isA<SchluesselAbgelehnt>(),
        '400 API_KEY_INVALID',
      );
    });

    test('401 und 403 → SchluesselAbgelehnt', () async {
      await erwarte(
        () => _json(_fehler(401, 'UNAUTHENTICATED', 'erfunden'), 401),
        isA<SchluesselAbgelehnt>(),
        '401',
      );
      await erwarte(
        () => _json(
          _fehler(
            403,
            'PERMISSION_DENIED',
            'Method doesn\'t allow '
                'unregistered callers (erfunden).',
          ),
          403,
        ),
        isA<SchluesselAbgelehnt>(),
        '403',
      );
    });

    test(
      '400 ohne API_KEY_INVALID → Sonstiges(400), nicht abgelehnt',
      () async {
        await erwarte(
          () => _json(
            _fehler(
              400,
              'INVALID_ARGUMENT',
              'Request contains an invalid '
                  'argument (erfunden).',
            ),
            400,
          ),
          isA<Sonstiges>().having((f) => f.status, 'status', 400),
          '400 sonstwie',
        );
      },
    );

    test('429 ohne Details → Kontingent(kostenloseStufe: false)', () async {
      await erwarte(
        () => _json(_fehler(429, 'RESOURCE_EXHAUSTED', 'erfunden'), 429),
        isA<Kontingent>().having(
          (f) => f.kostenloseStufe,
          'kostenloseStufe',
          isFalse,
        ),
        '429 ohne Details',
      );
    });

    test(
      '429 mit quotaId auf FreeTier → Kontingent(kostenloseStufe: true)',
      () async {
        await erwarte(
          () => _json(
            _kontingent('GenerateRequestsPerDayPerProjectPerModel-FreeTier'),
            429,
          ),
          isA<Kontingent>().having(
            (f) => f.kostenloseStufe,
            'kostenloseStufe',
            isTrue,
          ),
          '429 FreeTier',
        );
      },
    );

    test('429 mit quotaId ohne FreeTier → Kontingent(false)', () async {
      await erwarte(
        () => _json(
          _kontingent('GenerateRequestsPerMinutePerProjectPerModel'),
          429,
        ),
        isA<Kontingent>().having(
          (f) => f.kostenloseStufe,
          'kostenloseStufe',
          isFalse,
        ),
        '429 bezahlt',
      );
    });

    test('429 mit unlesbarem Körper → Kontingent(false)', () async {
      await erwarte(
        () => http.Response('<html>Too Many Requests</html>', 429),
        isA<Kontingent>().having(
          (f) => f.kostenloseStufe,
          'kostenloseStufe',
          isFalse,
        ),
        '429 HTML',
      );
    });

    test('SocketException und ClientException → KeinNetz', () async {
      await erwarte(
        () => throw const SocketException('Failed host lookup (erfunden)'),
        isA<KeinNetz>(),
        'SocketException',
      );
      await erwarte(
        () => throw http.ClientException('Connection closed (erfunden)'),
        isA<KeinNetz>(),
        'ClientException',
      );
    });

    test('5xx und sonstige 4xx → Sonstiges(status)', () async {
      for (final status in [404, 500, 503]) {
        await erwarte(
          () => _json(_fehler(status, 'ERFUNDEN', 'erfunden'), status),
          isA<Sonstiges>().having((f) => f.status, 'status', status),
          '$status',
        );
      }
    });
  });

  group('Zeitlimit', () {
    // `testWidgets` und nicht `test`: Nur dort läuft die Uhr unter
    // Kontrolle des Tests. 60 echte Sekunden je Fall wären zu langsam,
    // und eine eingesetzte kürzere Grenze bewiese die 60 nicht.
    testWidgets('Schätzung: nach 60 s ohne Antwort KeinNetz — vorher nicht', (
      tester,
    ) async {
      final c = _mit((_) => Completer<http.Response>().future);
      Object? fehler;
      unawaited(
        c.anbieter
            .schaetze(
              schluessel: _schluessel,
              modell: 'gemini-3.6-flash',
              jpeg: _jpeg,
            )
            .then<void>((_) {}, onError: (Object e) => fehler = e),
      );

      await tester.pump(const Duration(milliseconds: 59900));
      expect(fehler, isNull, reason: 'Die Grenze ist 60 s, nicht weniger');

      await tester.pump(const Duration(milliseconds: 200));
      expect(fehler, isA<KeinNetz>(), reason: 'Nach 60 s ist Schluss');
    });

    testWidgets('Modellliste und Testbild geben spätestens nach 60 s auf', (
      tester,
    ) async {
      for (final weg in ['modelle', 'testbild']) {
        final c = _mit((_) => Completer<http.Response>().future);
        Object? fehler;
        unawaited(
          _wege[weg]!(c.anbieter)
              .then<void>((_) {}, onError: (Object e) => fehler = e),
        );

        await tester.pump(const Duration(milliseconds: 60100));
        expect(fehler, isA<KeinNetz>(), reason: weg);
      }
    });
  });

  group('Schätzung — Antwort', () {
    test('200 mit gültigem JSON → Erkannt, gelesen wie im Kern', () async {
      final c = _mit(
        (_) => _json(
          _generateAntwort(text: jsonEncode(_rohSchaetzung), usage: _usage),
        ),
      );

      final ergebnis = await c.anbieter.schaetze(
        schluessel: _schluessel,
        modell: 'gemini-3.6-flash',
        jpeg: _jpeg,
      );

      final erwartet = leseAntwort(_rohSchaetzung) as Erkannt;
      final antwort = ergebnis.antwort;
      expect(antwort, isA<Erkannt>());
      antwort as Erkannt;
      expect(antwort.titel, erwartet.titel);
      expect(
        antwort.titel,
        'Hähnchen mit Reis und Brokkoli',
        reason: 'UTF-8 kommt heil an',
      );
      expect(antwort.posten, erwartet.posten);
      expect(antwort.notiz, erwartet.notiz);
      expect(
        antwort.posten[1].gramm,
        isNull,
        reason: '`grams: null` bleibt null, nie 0 (Review Focus 4)',
      );
      expect(antwort.posten[1].werte.kcal, isNull);
    });

    test(
      'usageMetadata wird zu KiVerbrauch, Denk-Token eingeschlossen',
      () async {
        final c = _mit(
          (_) => _json(
            _generateAntwort(text: jsonEncode(_rohSchaetzung), usage: _usage),
          ),
        );

        final ergebnis = await c.anbieter.schaetze(
          schluessel: _schluessel,
          modell: 'gemini-3.6-flash',
          jpeg: _jpeg,
        );

        expect(
          ergebnis.verbrauch,
          const KiVerbrauch(eingabe: 1290, ausgabe: 210, denken: 480),
        );
      },
    );

    test('isFood: false → KeinEssen, kein Fehler', () async {
      final c = _mit(
        (_) => _json(
          _generateAntwort(
            text: jsonEncode({'isFood': false, 'items': <Object?>[]}),
            usage: _usage,
          ),
        ),
      );

      final ergebnis = await c.anbieter.schaetze(
        schluessel: _schluessel,
        modell: 'gemini-3.6-flash',
        jpeg: _jpeg,
      );
      expect(ergebnis.antwort, isA<KeinEssen>());
    });

    test(
      'Text, der kein JSON ist → AntwortUnbrauchbar mit Verbrauch',
      () async {
        final c = _mit(
          (_) => _json(
            _generateAntwort(
              text: 'Auf dem Bild sehe ich Reis.',
              usage: _usage,
            ),
          ),
        );

        final fehler = await _fehlerVon(
          c.anbieter.schaetze(
            schluessel: _schluessel,
            modell: 'gemini-3.6-flash',
            jpeg: _jpeg,
          ),
        );
        expect(fehler, isA<AntwortUnbrauchbar>());
        expect(
          (fehler as AntwortUnbrauchbar).verbrauch,
          const KiVerbrauch(eingabe: 1290, ausgabe: 210, denken: 480),
          reason: 'Google hat gezählt; Task 10 bucht die Zeile trotzdem',
        );
      },
    );

    test('JSON gegen das Schema → AntwortUnbrauchbar mit Verbrauch', () async {
      for (final text in [
        jsonEncode({'title': 'ohne isFood', 'items': <Object?>[]}),
        jsonEncode([_rohSchaetzung]),
        jsonEncode({
          'isFood': true,
          'title': 'Teller',
          'items': [
            {'name': 'Reis', 'grams': -5, 'confident': true},
          ],
        }),
      ]) {
        final c = _mit(
          (_) => _json(_generateAntwort(text: text, usage: _usage)),
        );
        final fehler = await _fehlerVon(
          c.anbieter.schaetze(
            schluessel: _schluessel,
            modell: 'gemini-3.6-flash',
            jpeg: _jpeg,
          ),
        );
        expect(fehler, isA<AntwortUnbrauchbar>(), reason: text);
        expect(
          (fehler as AntwortUnbrauchbar).verbrauch,
          const KiVerbrauch(eingabe: 1290, ausgabe: 210, denken: 480),
          reason: text,
        );
      }
    });

    test('200 ohne Kandidaten (Anfrage blockiert) → AntwortUnbrauchbar mit '
        'Verbrauch', () async {
      final c = _mit(
        (_) => _json({
          'promptFeedback': {'blockReason': 'OTHER'},
          'usageMetadata': {'promptTokenCount': 1290},
        }),
      );

      final fehler = await _fehlerVon(
        c.anbieter.schaetze(
          schluessel: _schluessel,
          modell: 'gemini-3.6-flash',
          jpeg: _jpeg,
        ),
      );
      expect(fehler, isA<AntwortUnbrauchbar>());
      expect(
        (fehler as AntwortUnbrauchbar).verbrauch,
        const KiVerbrauch(eingabe: 1290, ausgabe: 0, denken: 0),
      );
    });

    test(
      '200 mit unlesbarem Körper → AntwortUnbrauchbar ohne Verbrauch',
      () async {
        final c = _mit((_) => http.Response('<html>Wartung</html>', 200));

        final fehler = await _fehlerVon(
          c.anbieter.schaetze(
            schluessel: _schluessel,
            modell: 'gemini-3.6-flash',
            jpeg: _jpeg,
          ),
        );
        expect(fehler, isA<AntwortUnbrauchbar>());
        expect((fehler as AntwortUnbrauchbar).verbrauch, isNull);
      },
    );
  });

  group('Schätzung — Anfrage', () {
    Future<http.Request> schicke({
      String? hinweis,
      List<SchaetzPosten> feste = const [],
    }) async {
      final c = _mit(
        (_) => _json(
          _generateAntwort(text: jsonEncode(_rohSchaetzung), usage: _usage),
        ),
      );
      await c.anbieter.schaetze(
        schluessel: _schluessel,
        modell: 'gemini-3.6-flash',
        jpeg: _jpeg,
        hinweis: hinweis,
        feste: feste,
      );
      expect(c.anfragen, hasLength(1));
      return c.anfragen.single;
    }

    test('POST an models/<modell>:generateContent, JSON-Körper', () async {
      final a = await schicke();
      expect(a.method, 'POST');
      expect(a.url.host, 'generativelanguage.googleapis.com');
      expect(a.url.path, '/v1beta/models/gemini-3.6-flash:generateContent');
      expect(a.headers['content-type'], startsWith('application/json'));
    });

    test('das JPEG geht als inline_data mit image/jpeg und Base64', () async {
      final teile = _bildTeile(_koerper(await schicke()));
      expect(teile, hasLength(1), reason: 'Genau ein Bild');
      expect(teile.single['mime_type'], 'image/jpeg');
      expect(teile.single['data'], base64Encode(_jpeg));
    });

    test('responseMimeType ist application/json, mit Antwortschema', () async {
      final koerper = _koerper(await schicke());
      final config = koerper['generationConfig'] as Map<String, dynamic>;
      expect(config['responseMimeType'], 'application/json');

      final schema = config['responseJsonSchema'] as Map<String, dynamic>;
      final felder = (schema['properties'] as Map<String, dynamic>).keys;
      expect(felder, containsAll(['isFood', 'title', 'items', 'note']));

      final items =
          (schema['properties'] as Map<String, dynamic>)['items']
              as Map<String, dynamic>;
      final posten = items['items'] as Map<String, dynamic>;
      expect(
        (posten['properties'] as Map<String, dynamic>).keys,
        containsAll([
          'name',
          'grams',
          'kcal',
          'proteinG',
          'carbsG',
          'fatG',
          'confident',
        ]),
      );
    });

    test('der Hinweis geht mit', () async {
      const hinweis = 'Reis nur halbe Portion, ohne Soße';
      final texte = _texte(_koerper(await schicke(hinweis: hinweis)));
      expect(texte.any((t) => t.contains(hinweis)), isTrue);
    });

    test('die festen Posten gehen mit, mit Namen und Menge', () async {
      final texte = _texte(_koerper(await schicke(feste: [_festerPosten])));
      final alles = texte.join('\n');
      expect(alles, contains('Basmatireis, gekocht'));
      expect(alles, contains('180'));
    });
  });

  group('Testbild', () {
    test('ein winziges JPEG an das gewählte Modell; jedes 200 gilt', () async {
      for (final text in ['OK', 'Ich sehe ein graues Quadrat.']) {
        final c = _mit(
          (_) => _json(
            _generateAntwort(
              text: text,
              usage: {'promptTokenCount': 300, 'candidatesTokenCount': 2},
            ),
          ),
        );

        final verbrauch = await c.anbieter.testbild(
          schluessel: _schluessel,
          modell: 'gemini-3.6-pro-preview',
        );

        expect(
          verbrauch,
          const KiVerbrauch(eingabe: 300, ausgabe: 2, denken: 0),
          reason: text,
        );
        final a = c.anfragen.single;
        expect(a.method, 'POST');
        expect(
          a.url.path,
          '/v1beta/models/gemini-3.6-pro-preview:generateContent',
        );

        final teile = _bildTeile(_koerper(a));
        expect(teile, hasLength(1));
        expect(teile.single['mime_type'], 'image/jpeg');
        final bytes = base64Decode(teile.single['data'] as String);
        expect(bytes.length, lessThan(4096), reason: 'winzig');
        expect(bytes.take(2), [0xFF, 0xD8], reason: 'JPEG-Anfang');
        expect(bytes.skip(bytes.length - 2), [0xFF, 0xD9], reason: 'JPEG-Ende');
      }
    });
  });

  test('kiAnbieterProvider liefert einen GeminiAnbieter', () {
    final container = ProviderContainer(retry: (_, _) => null);
    addTearDown(container.dispose);
    expect(container.read(kiAnbieterProvider), isA<GeminiAnbieter>());
  });
}

// ---------------------------------------------------------------------------
// Hilfen — alles erfunden.

/// Erfunden, ohne das Präfix echter Google-Schlüssel.
const _schluessel = 'TESTSCHLUESSEL-erfunden-0000-kein-echter';

/// Kein gültiges Bild, nur JPEG-Rahmen um erfundene Bytes — der Client
/// schickt, er dekodiert nicht.
const _jpeg = <int>[0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3, 4, 5, 6, 7, 0xFF, 0xD9];

const _usage = <String, Object?>{
  'promptTokenCount': 1290,
  'candidatesTokenCount': 210,
  'thoughtsTokenCount': 480,
  'totalTokenCount': 1980,
};

const _rohSchaetzung = <String, Object?>{
  'isFood': true,
  'title': 'Hähnchen mit Reis und Brokkoli',
  'items': [
    {
      'name': 'Hähnchenbrust, gegrillt',
      'grams': 140,
      'kcal': 231,
      'proteinG': 43.4,
      'carbsG': 0,
      'fatG': 5.0,
      'confident': true,
    },
    {
      'name': 'Soße',
      'grams': null,
      'kcal': null,
      'proteinG': null,
      'carbsG': null,
      'fatG': null,
      'confident': false,
    },
  ],
  'note': 'Soße: Fett auf dem Bild kaum erkennbar',
};

const _festerPosten = SchaetzPosten(
  name: 'Basmatireis, gekocht',
  gramm: 180,
  werte: Naehrwerte(kcal: 234, eiweissG: 4.9, kohlenhydrateG: 50.4, fettG: 0.7),
  sicher: true,
  herkunft: PostenHerkunft.vonDir,
);

final _wege = <String, Future<Object?> Function(KiAnbieter)>{
  'modelle': (a) => a.modelle(_schluessel),
  'schaetze': (a) => a.schaetze(
    schluessel: _schluessel,
    modell: 'gemini-3.6-flash',
    jpeg: _jpeg,
  ),
  'testbild': (a) =>
      a.testbild(schluessel: _schluessel, modell: 'gemini-3.6-flash'),
};

({GeminiAnbieter anbieter, List<http.Request> anfragen}) _mit(
  FutureOr<http.Response> Function(http.Request anfrage) antwort,
) {
  final anfragen = <http.Request>[];
  final client = MockClient((anfrage) async {
    anfragen.add(anfrage);
    return antwort(anfrage);
  });
  return (anbieter: GeminiAnbieter(client), anfragen: anfragen);
}

Future<KiFehler> _fehlerVon(Future<Object?> aufruf) async {
  try {
    await aufruf;
  } on KiFehler catch (f) {
    return f;
  }
  fail('Erwartet war ein KiFehler, der Aufruf ist aber gelungen');
}

void _pruefeSchluesselNurImKopf(List<http.Request> anfragen) {
  for (final a in anfragen) {
    expect(
      a.headers['x-goog-api-key'],
      _schluessel,
      reason: '${a.method} ${a.url.path}: Schlüssel im Kopf',
    );
    expect(
      a.url.toString(),
      isNot(contains(_schluessel)),
      reason: '${a.method} ${a.url.path}: nie in der URL',
    );
    expect(
      a.url.queryParameters.containsKey('key'),
      isFalse,
      reason: '${a.method} ${a.url.path}: kein ?key=',
    );
    expect(
      a.body,
      isNot(contains(_schluessel)),
      reason: '${a.method} ${a.url.path}: nie im Körper',
    );
  }
}

http.Response _json(Object koerper, [int status = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(koerper)),
  status,
  headers: const {'content-type': 'application/json; charset=UTF-8'},
);

Map<String, Object?> _rohModell(
  String id, {
  String? anzeige,
  List<String> methoden = const ['generateContent', 'countTokens'],
}) => {
  'name': 'models/$id',
  'baseModelId': id,
  'version': '001',
  'displayName': ?anzeige,
  'inputTokenLimit': 1048576,
  'outputTokenLimit': 65536,
  'supportedGenerationMethods': methoden,
};

Map<String, Object?> _generateAntwort({
  required String text,
  Map<String, Object?>? usage,
}) => {
  'candidates': [
    {
      'content': {
        'role': 'model',
        'parts': [
          {'text': text},
        ],
      },
      'finishReason': 'STOP',
      'index': 0,
    },
  ],
  'usageMetadata': ?usage,
  'modelVersion': 'gemini-3.6-flash',
};

Map<String, Object?> _fehler(
  int code,
  String status,
  String meldung, [
  List<Object?> details = const [],
]) => {
  'error': {
    'code': code,
    'message': meldung,
    'status': status,
    if (details.isNotEmpty) 'details': details,
  },
};

Map<String, Object?> _schluesselUngueltig([
  String meldung = 'API key not valid. Please pass a valid API key.',
]) => _fehler(400, 'INVALID_ARGUMENT', meldung, [
  {
    '@type': 'type.googleapis.com/google.rpc.ErrorInfo',
    'reason': 'API_KEY_INVALID',
    'domain': 'googleapis.com',
    'metadata': {'service': 'generativelanguage.googleapis.com'},
  },
]);

/// Die Form laut Forenberichten — Task 11 prüft sie an einem echten 429.
Map<String, Object?> _kontingent(String quotaId) => _fehler(
  429,
  'RESOURCE_EXHAUSTED',
  'You exceeded your current quota '
      '(erfunden).',
  [
    {
      '@type': 'type.googleapis.com/google.rpc.QuotaFailure',
      'violations': [
        {
          'quotaMetric': 'generativelanguage.googleapis.com/erfunden',
          'quotaId': quotaId,
          'quotaDimensions': {'location': 'global', 'model': 'erfunden'},
        },
      ],
    },
    {'@type': 'type.googleapis.com/google.rpc.RetryInfo', 'retryDelay': '37s'},
  ],
);

Map<String, dynamic> _koerper(http.Request a) =>
    jsonDecode(a.body) as Map<String, dynamic>;

/// Alle `inline_data`-Teile in `contents[*].parts[*]`.
List<Map<String, dynamic>> _bildTeile(Map<String, dynamic> koerper) => [
  for (final inhalt in koerper['contents'] as List)
    for (final teil in (inhalt as Map<String, dynamic>)['parts'] as List)
      if ((teil as Map<String, dynamic>).containsKey('inline_data'))
        teil['inline_data'] as Map<String, dynamic>,
];

/// Jeder Text unter einem Schlüssel `text`, wo immer er im Körper steht —
/// Prompt, Hinweis und feste Posten dürfen auf Teile verteilt sein.
List<String> _texte(Object? knoten) => switch (knoten) {
  Map() => [
    for (final e in knoten.entries)
      if (e.key == 'text' && e.value is String)
        e.value as String
      else
        ..._texte(e.value),
  ],
  List() => [for (final k in knoten) ..._texte(k)],
  _ => const [],
};
