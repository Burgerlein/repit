import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/live/live_anzeige.dart';
import 'package:repit/live/live_types.dart';

/// Tests für **#367** — der Dart-Kanal hinter `LiveAnzeige` mit Attrappe
/// (Task 5 des Plans `docs/superpowers/plans/2026-11-05-live-aktivitaet.md`,
/// Spec `docs/superpowers/specs/2026-11-05-live-aktivitaet-design.md`,
/// Abschnitte „Der Kanal" und „Die Dart-Seite → Kanal hinter einem
/// Protokoll").
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden. Hält der
/// Implementierende einen Fall für falsch, meldet er das. Geschrieben ohne
/// den Code von `lib/live/` gesehen zu haben — es gab ihn beim Schreiben
/// noch nicht.
///
/// ## Woher die Regeln kommen
///
/// - `CLAUDE.md`, Datenschicht: „`nil` darf auf dem Weg durch den Kanal
///   niemals zu `0` werden. Fehlende Felder fehlen in der Map, sie stehen
///   nicht mit Nullwert drin." Und: „`0` ist keine Antwort auf ‚kein
///   Wert'."
/// - Spec, „Dart → Swift": „Fehlt ein Wert, fehlt der Schlüssel. `kcal`
///   ohne Wert steht nicht als `0` und nicht als `null` in der Map, und
///   `ersteOffene` fehlt, wenn keine Mahlzeit offen ist."
/// - Spec, „Kanal hinter einem Protokoll": „**`zeige` wirft nicht.** Eine
///   Karte, die nicht aufgeht, darf weder Buchen noch Öffnen aufhalten."
/// - Plan, Review Focus 2: „`kcal: null` wird `0`."
///
/// Die Swift-Gegenseite prüft `app/ios/RunnerTests/LiveChannelTests.swift`
/// (Task 4) gegen **dieselben Wörter** — die Kanalgrenze ist bewiesen,
/// wenn beide Seiten unabhängig übereinstimmen.
///
/// ## Was diese Datei verbindlich vorgibt (aus Plan und Spec)
///
/// In `lib/live/live_types.dart`:
///
/// ```dart
/// sealed class LiveErgebnis {}
/// // LiveGestartet(), LiveAktualisiert(), LiveAbgeschaltet(),
/// // LiveFehlgeschlagen(String? meldung) mit Feld `meldung`,
/// // LiveNichtVerfuegbar()
/// enum LiveZiel { mahlzeitEintragen }
/// sealed class LiveSoll {}          // mit == und hashCode
/// // KeineLive(), EssenLive(EssenKarte karte) mit Feld `karte`
/// Map<String, Object?> essenKarteAlsMap(EssenKarte karte, {required bool frisch});
/// ```
///
/// In `lib/live/live_anzeige.dart`:
///
/// ```dart
/// abstract interface class LiveAnzeige {
///   Future<LiveErgebnis> zeige(EssenKarte karte, {required bool frisch});
///   Future<void> beendeAlle();
///   Future<LiveZiel?> nimmLink();
///   Stream<void> get linkDa;
/// }
/// class KanalLiveAnzeige implements LiveAnzeige {
///   KanalLiveAnzeige({MethodChannel? kanal});
/// }
/// class AttrappeLiveAnzeige implements LiveAnzeige { … siehe unten … }
/// final liveAnzeigeProvider = Provider<LiveAnzeige>(…); // wirft ohne Override
/// ```
///
/// Der Kanal heißt `de.rosenbach.repit/live`. Methoden von Dart
/// nach Swift: `zeige` (Map unten), `beendeAlle` und `nimmLink` (beide ohne
/// Argumente). Von Swift nach Dart: `linkDa` (ohne Argumente). Antworten
/// auf `zeige`: `"gestartet"`, `"aktualisiert"`, `"abgeschaltet"`.
///
/// Die Argumente von `zeige`, buchstabengleich zur Spec:
///
/// ```text
/// {
///   "fassung": "essen",
///   "frisch": <bool>,
///   "verfaelltUm": <int, Millisekunden seit 1970, UTC>,
///   "essen": {
///     "mahlzeiten": [            // vier, in der Reihenfolge von karte.ringe
///       { "mahlzeit": "<Mahlzeit.name>", "eintrag": <bool>, "kcal": <int> }
///     ],
///     "ersteOffene": "<Mahlzeit.name>",   // fehlt, wenn null
///     "serie": <int>,
///     "serieAbMorgen": <int>
///   }
/// }
/// ```
///
/// ## Die Attrappe — dieselben Namen wie in `live_provider_test.dart`
///
/// Der Test zu Task 6 (`app/test/live/live_provider_test.dart`, `ffb38dd`)
/// hat eine eigene Attrappe `_Anzeige`, weil es diesen Test noch nicht gab.
/// `AttrappeLiveAnzeige` übernimmt **deren** Namen und Verhalten, damit
/// beide zusammenpassen und Task 7 eine von beiden ohne Umlernen benutzen
/// kann:
///
/// ```dart
/// class AttrappeLiveAnzeige implements LiveAnzeige {
///   final List<({EssenKarte karte, bool frisch})> zeigeAufrufe; // Reihenfolge der Aufrufe
///   int beendeAlleAufrufe;   // Zähler
///   int nimmLinkAufrufe;     // Zähler
///   LiveZiel? link;          // setzbar; nimmLink() gibt ihn ab und leert
///   LiveErgebnis ergebnis;   // setzbar; zeige() gibt ihn zurück
///   void meldeLink();        // feuert ein Ereignis auf linkDa
/// }
/// ```
///
/// ## Festlegung des Koordinators — nicht von Tim freigegeben
///
/// - **Eine Mahlzeit ohne Eintrag schickt keinen `kcal`-Schlüssel, auch
///   keine `0`** — egal, was im Ring steht. Der Provider (Task 6) rechnet
///   `kcal = summe.kcal`, und die leere Summe trägt Nullen; ohne diese
///   Regel ginge eine offene Mahlzeit als „0 kcal" an den Sperrbildschirm.
///   `CLAUDE.md`: „`0` ist keine Antwort auf ‚kein Wert'."
/// - **Eine Mahlzeit mit Eintrag und `kcal: null` schickt ebenfalls keinen
///   Schlüssel** (so auch Plan und Spec).
///
/// ## Festlegungen des Test-Agenten — nicht von Tim freigegeben
///
/// - **Eine echte `0` einer Mahlzeit mit Eintrag geht als `0` mit**, und
///   eine Serie von `0` ebenso (V11: „🔥 0"). Die Regel heißt „fehlt statt
///   null", nicht „fehlt statt 0" — sonst würde der schwarze Kaffee zum
///   „–". Dasselbe Verfahren wie in `health_schreiben_kanal_test.dart`.
/// - **Eine unbekannte oder fehlende Antwort auf `zeige` wird
///   `LiveFehlgeschlagen`**, sie wirft nicht und wird nicht still zum
///   Erfolg. „`zeige` wirft nicht" (Spec) gilt in jedem Fall; als Erfolg
///   zu gelten, wäre die stille Umdeutung, die `CLAUDE.md` verbietet.
/// - **`nimmLink` der Attrappe leert den Link**, wie `nimmLink` auf der
///   Swift-Seite (Spec, „Dart → Swift") und wie `_Anzeige` in Task 6.
/// - **`linkDa` liefert je Plattformaufruf genau ein Ereignis.**
///
/// Alle Zahlen und Daten sind erfunden. Gerechnet wird im Januar 2099,
/// Berlin ist dann UTC+1.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const kanal = MethodChannel('de.rosenbach.repit/live');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  // 04:00 Berliner Zeit am 16.01.2099 = 03:00 UTC.
  final verfaellt = DateTime.utc(2099, 1, 16, 3);
  const verfaelltMs = 4072215600000;

  late List<MethodCall> aufrufe;
  late Future<Object?> Function(MethodCall) antwort;

  setUp(() {
    aufrufe = [];
    antwort = (_) async => 'gestartet';
    messenger.setMockMethodCallHandler(kanal, (aufruf) {
      aufrufe.add(aufruf);
      return antwort(aufruf);
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(kanal, null);
  });

  KanalLiveAnzeige anzeige() => KanalLiveAnzeige(kanal: kanal);

  MahlzeitRing ring(Mahlzeit mahlzeit, {required bool eintrag, int? kcal}) =>
      MahlzeitRing(mahlzeit: mahlzeit, eintrag: eintrag, kcal: kcal);

  /// Die Karte aus dem Beispiel der Spec: Frühstück und Mittag gegessen,
  /// Snack und Abend offen.
  EssenKarte beispiel({int serie = 10}) => EssenKarte(
    ringe: [
      ring(Mahlzeit.fruehstueck, eintrag: true, kcal: 686),
      ring(Mahlzeit.mittag, eintrag: true, kcal: 813),
      ring(Mahlzeit.snack, eintrag: false),
      ring(Mahlzeit.abend, eintrag: false),
    ],
    ersteOffene: Mahlzeit.abend,
    serie: serie,
    serieAbMorgen: 0,
    verfaelltUm: verfaellt,
  );

  Map<Object?, Object?> argumente() =>
      aufrufe.single.arguments as Map<Object?, Object?>;

  List<Map<Object?, Object?>> mahlzeitenAus(Map<Object?, Object?> args) => [
    for (final m
        in ((args['essen']! as Map<Object?, Object?>)['mahlzeiten']!
            as List<Object?>))
      m! as Map<Object?, Object?>,
  ];

  Map<Object?, Object?> essenAus(Map<Object?, Object?> args) =>
      args['essen']! as Map<Object?, Object?>;

  /// Sendet einen Aufruf von der Plattformseite an die Dart-Seite.
  Future<void> vonSwift(String methode) async {
    await messenger.handlePlatformMessage(
      kanal.name,
      const StandardMethodCodec().encodeMethodCall(MethodCall(methode)),
      (_) {},
    );
  }

  group('zeige schickt die Map aus der Spec', () {
    test('Methode zeige, genau die Argumente des Spec-Beispiels', () async {
      await anzeige().zeige(beispiel(), frisch: true);

      expect(aufrufe.single.method, 'zeige');
      expect(
        argumente(),
        equals(<String, Object?>{
          'fassung': 'essen',
          'frisch': true,
          'verfaelltUm': verfaelltMs,
          'essen': <String, Object?>{
            'mahlzeiten': [
              {'mahlzeit': 'fruehstueck', 'eintrag': true, 'kcal': 686},
              {'mahlzeit': 'mittag', 'eintrag': true, 'kcal': 813},
              {'mahlzeit': 'snack', 'eintrag': false},
              {'mahlzeit': 'abend', 'eintrag': false},
            ],
            'ersteOffene': 'abend',
            'serie': 10,
            'serieAbMorgen': 0,
          },
        }),
      );
    });

    test('frisch: false geht als false mit', () async {
      await anzeige().zeige(beispiel(), frisch: false);

      expect(argumente()['frisch'], false);
    });

    test('verfaelltUm in Millisekunden seit 1970, UTC — als int', () async {
      await anzeige().zeige(beispiel(), frisch: true);

      expect(argumente()['verfaelltUm'], isA<int>());
      expect(argumente()['verfaelltUm'], verfaelltMs);
      expect(argumente()['verfaelltUm'], verfaellt.millisecondsSinceEpoch);
    });

    test('die Mahlzeiten tragen die Mahlzeit-Namen, in der Reihenfolge der '
        'Ringe', () async {
      await anzeige().zeige(beispiel(), frisch: true);

      expect(
        [for (final m in mahlzeitenAus(argumente())) m['mahlzeit']],
        ['fruehstueck', 'mittag', 'snack', 'abend'],
      );
    });

    test('ein Ring mit Eintrag und kcal: null hat keinen Schlüssel kcal — '
        'auch kein null, keine 0 (Review Focus 2)', () async {
      final karte = EssenKarte(
        ringe: [
          ring(Mahlzeit.fruehstueck, eintrag: true),
          ring(Mahlzeit.mittag, eintrag: true, kcal: 500),
          ring(Mahlzeit.snack, eintrag: false),
          ring(Mahlzeit.abend, eintrag: false),
        ],
        ersteOffene: Mahlzeit.abend,
        serie: 3,
        serieAbMorgen: 3,
        verfaelltUm: verfaellt,
      );

      await anzeige().zeige(karte, frisch: true);

      final fruehstueck = mahlzeitenAus(argumente()).first;
      expect(fruehstueck.containsKey('kcal'), isFalse);
      expect(fruehstueck, {'mahlzeit': 'fruehstueck', 'eintrag': true});
    });

    test('eine Mahlzeit ohne Eintrag schickt keinen kcal-Schlüssel, auch '
        'wenn der Ring 0 trägt (Festlegung des Koordinators)', () async {
      final karte = EssenKarte(
        ringe: [
          ring(Mahlzeit.fruehstueck, eintrag: false, kcal: 0),
          ring(Mahlzeit.mittag, eintrag: false, kcal: 0),
          ring(Mahlzeit.snack, eintrag: false, kcal: 0),
          ring(Mahlzeit.abend, eintrag: false),
        ],
        ersteOffene: Mahlzeit.fruehstueck,
        serie: 2,
        serieAbMorgen: 0,
        verfaelltUm: verfaellt,
      );

      await anzeige().zeige(karte, frisch: true);

      for (final m in mahlzeitenAus(argumente())) {
        expect(
          m.containsKey('kcal'),
          isFalse,
          reason: '${m['mahlzeit']} ohne Eintrag darf keine kcal schicken',
        );
        expect(m.keys.toSet(), {'mahlzeit', 'eintrag'});
        expect(m['eintrag'], false);
      }
    });

    test('eine echte 0 einer Mahlzeit mit Eintrag geht als 0 mit '
        '(Festlegung des Test-Agenten)', () async {
      final karte = EssenKarte(
        ringe: [
          ring(Mahlzeit.fruehstueck, eintrag: true, kcal: 0),
          ring(Mahlzeit.mittag, eintrag: false),
          ring(Mahlzeit.snack, eintrag: false),
          ring(Mahlzeit.abend, eintrag: false),
        ],
        ersteOffene: Mahlzeit.mittag,
        serie: 1,
        serieAbMorgen: 1,
        verfaelltUm: verfaellt,
      );

      await anzeige().zeige(karte, frisch: true);

      expect(mahlzeitenAus(argumente()).first, {
        'mahlzeit': 'fruehstueck',
        'eintrag': true,
        'kcal': 0,
      });
    });

    test('ersteOffene: null → kein Schlüssel ersteOffene; eine Serie von 0 '
        'geht als 0 mit', () async {
      final karte = EssenKarte(
        ringe: [
          ring(Mahlzeit.fruehstueck, eintrag: true, kcal: 420),
          ring(Mahlzeit.mittag, eintrag: true, kcal: 610),
          ring(Mahlzeit.snack, eintrag: false),
          ring(Mahlzeit.abend, eintrag: true, kcal: 730),
        ],
        ersteOffene: null,
        serie: 0,
        serieAbMorgen: 0,
        verfaelltUm: verfaellt,
      );

      await anzeige().zeige(karte, frisch: false);

      final essen = essenAus(argumente());
      expect(essen.containsKey('ersteOffene'), isFalse);
      expect(essen.keys.toSet(), {'mahlzeiten', 'serie', 'serieAbMorgen'});
      expect(essen['serie'], 0);
      expect(essen['serieAbMorgen'], 0);
    });
  });

  group('essenKarteAlsMap', () {
    test('liefert dieselbe Map, die über den Kanal geht', () async {
      await anzeige().zeige(beispiel(), frisch: true);

      expect(essenKarteAlsMap(beispiel(), frisch: true), equals(argumente()));
    });

    test('fehlende Werte fehlen auch hier — kein null-Wert in der Map', () {
      final karte = EssenKarte(
        ringe: [
          ring(Mahlzeit.fruehstueck, eintrag: true),
          ring(Mahlzeit.mittag, eintrag: false, kcal: 0),
          ring(Mahlzeit.snack, eintrag: false),
          ring(Mahlzeit.abend, eintrag: true, kcal: 512),
        ],
        ersteOffene: null,
        serie: 4,
        serieAbMorgen: 4,
        verfaelltUm: verfaellt,
      );

      final map = essenKarteAlsMap(karte, frisch: false);

      expect(map, {
        'fassung': 'essen',
        'frisch': false,
        'verfaelltUm': verfaelltMs,
        'essen': {
          'mahlzeiten': [
            {'mahlzeit': 'fruehstueck', 'eintrag': true},
            {'mahlzeit': 'mittag', 'eintrag': false},
            {'mahlzeit': 'snack', 'eintrag': false},
            {'mahlzeit': 'abend', 'eintrag': true, 'kcal': 512},
          ],
          'serie': 4,
          'serieAbMorgen': 4,
        },
      });
    });
  });

  group('Antworten auf zeige', () {
    test('"gestartet" → LiveGestartet', () async {
      antwort = (_) async => 'gestartet';
      expect(
        await anzeige().zeige(beispiel(), frisch: true),
        isA<LiveGestartet>(),
      );
    });

    test('"aktualisiert" → LiveAktualisiert', () async {
      antwort = (_) async => 'aktualisiert';
      expect(
        await anzeige().zeige(beispiel(), frisch: false),
        isA<LiveAktualisiert>(),
      );
    });

    test('"abgeschaltet" → LiveAbgeschaltet', () async {
      antwort = (_) async => 'abgeschaltet';
      expect(
        await anzeige().zeige(beispiel(), frisch: true),
        isA<LiveAbgeschaltet>(),
      );
    });

    test('PlatformException → LiveFehlgeschlagen mit der Meldung, ohne zu '
        'werfen', () async {
      antwort = (_) async =>
          throw PlatformException(code: 'live', message: 'Prüfmeldung 17');

      final ergebnis = await anzeige().zeige(beispiel(), frisch: true);

      expect(ergebnis, isA<LiveFehlgeschlagen>());
      expect((ergebnis as LiveFehlgeschlagen).meldung, 'Prüfmeldung 17');
    });

    test('auch der Fehler argumente wirft nicht', () async {
      antwort = (_) async =>
          throw PlatformException(code: 'argumente', message: 'kcal: String');

      final ergebnis = await anzeige().zeige(beispiel(), frisch: true);

      expect(ergebnis, isA<LiveFehlgeschlagen>());
      expect((ergebnis as LiveFehlgeschlagen).meldung, 'kcal: String');
    });

    test('kein Handler (MissingPluginException) → LiveNichtVerfuegbar, ohne '
        'zu werfen', () async {
      messenger.setMockMethodCallHandler(kanal, null);

      final ergebnis = await anzeige().zeige(beispiel(), frisch: true);

      expect(ergebnis, isA<LiveNichtVerfuegbar>());
    });

    test('eine unbekannte Antwort → LiveFehlgeschlagen, ohne zu werfen '
        '(Festlegung des Test-Agenten)', () async {
      antwort = (_) async => 'vielleicht';

      expect(
        await anzeige().zeige(beispiel(), frisch: true),
        isA<LiveFehlgeschlagen>(),
      );
    });

    test('keine Antwort (null) → LiveFehlgeschlagen, ohne zu werfen '
        '(Festlegung des Test-Agenten)', () async {
      antwort = (_) async => null;

      expect(
        await anzeige().zeige(beispiel(), frisch: true),
        isA<LiveFehlgeschlagen>(),
      );
    });
  });

  group('beendeAlle', () {
    test('schickt beendeAlle, ohne Argumente', () async {
      antwort = (_) async => null;

      await anzeige().beendeAlle();

      expect(aufrufe.single.method, 'beendeAlle');
      expect(aufrufe.single.arguments, isNull);
    });
  });

  group('nimmLink', () {
    test('schickt nimmLink, ohne Argumente', () async {
      antwort = (_) async => null;

      await anzeige().nimmLink();

      expect(aufrufe.single.method, 'nimmLink');
      expect(aufrufe.single.arguments, isNull);
    });

    test('"mahlzeit-eintragen" → LiveZiel.mahlzeitEintragen', () async {
      antwort = (_) async => 'mahlzeit-eintragen';

      expect(await anzeige().nimmLink(), LiveZiel.mahlzeitEintragen);
    });

    test('null → null', () async {
      antwort = (_) async => null;

      expect(await anzeige().nimmLink(), isNull);
    });

    test('ein unbekannter Host → null, ohne zu werfen', () async {
      antwort = (_) async => 'irgendwas';

      expect(await anzeige().nimmLink(), isNull);
    });
  });

  group('linkDa', () {
    test('ein linkDa von der Plattformseite erscheint im Stream', () async {
      final a = anzeige();
      var ereignisse = 0;
      final abo = a.linkDa.listen((_) => ereignisse++);
      addTearDown(abo.cancel);

      await vonSwift('linkDa');
      await pumpEventQueue();

      expect(ereignisse, 1);

      await vonSwift('linkDa');
      await pumpEventQueue();

      expect(ereignisse, 2);
    });

    test('linkDa ruft selbst nichts auf der Swift-Seite auf', () async {
      final a = anzeige();
      final abo = a.linkDa.listen((_) {});
      addTearDown(abo.cancel);

      await vonSwift('linkDa');
      await pumpEventQueue();

      expect(aufrufe, isEmpty);
    });
  });

  group('AttrappeLiveAnzeige', () {
    test(
      'merkt sich zeige(karte, frisch:) in der Reihenfolge der Aufrufe',
      () async {
        final attrappe = AttrappeLiveAnzeige();

        await attrappe.zeige(beispiel(serie: 1), frisch: true);
        await attrappe.zeige(beispiel(serie: 2), frisch: false);
        await attrappe.zeige(beispiel(serie: 3), frisch: false);

        expect(attrappe.zeigeAufrufe, [
          (karte: beispiel(serie: 1), frisch: true),
          (karte: beispiel(serie: 2), frisch: false),
          (karte: beispiel(serie: 3), frisch: false),
        ]);
      },
    );

    test('gibt das eingestellte Ergebnis zurück', () async {
      final attrappe = AttrappeLiveAnzeige();

      attrappe.ergebnis = LiveAbgeschaltet();
      expect(
        await attrappe.zeige(beispiel(), frisch: true),
        isA<LiveAbgeschaltet>(),
      );

      attrappe.ergebnis = LiveFehlgeschlagen('Prüfmeldung 23');
      final ergebnis = await attrappe.zeige(beispiel(), frisch: false);
      expect(ergebnis, isA<LiveFehlgeschlagen>());
      expect((ergebnis as LiveFehlgeschlagen).meldung, 'Prüfmeldung 23');
    });

    test('zählt beendeAlle und nimmLink', () async {
      final attrappe = AttrappeLiveAnzeige();

      expect(attrappe.zeigeAufrufe, isEmpty);
      expect(attrappe.beendeAlleAufrufe, 0);
      expect(attrappe.nimmLinkAufrufe, 0);

      await attrappe.beendeAlle();
      await attrappe.beendeAlle();
      await attrappe.nimmLink();

      expect(attrappe.beendeAlleAufrufe, 2);
      expect(attrappe.nimmLinkAufrufe, 1);
      expect(attrappe.zeigeAufrufe, isEmpty);
    });

    test(
      'nimmLink gibt den eingestellten Link einmal ab und leert ihn',
      () async {
        final attrappe = AttrappeLiveAnzeige();
        expect(await attrappe.nimmLink(), isNull);

        attrappe.link = LiveZiel.mahlzeitEintragen;

        expect(await attrappe.nimmLink(), LiveZiel.mahlzeitEintragen);
        expect(await attrappe.nimmLink(), isNull);
        expect(attrappe.link, isNull);
      },
    );

    test('meldeLink() feuert linkDa', () async {
      final attrappe = AttrappeLiveAnzeige();
      var ereignisse = 0;
      final abo = attrappe.linkDa.listen((_) => ereignisse++);
      addTearDown(abo.cancel);

      attrappe.meldeLink();
      await pumpEventQueue();

      expect(ereignisse, 1);
    });
  });

  group('LiveSoll', () {
    test('KeineLive() == KeineLive(), mit gleichem hashCode', () {
      expect(KeineLive(), KeineLive());
      expect(KeineLive().hashCode, KeineLive().hashCode);
    });

    test('EssenLive(a) == EssenLive(b), wenn a == b — auch bei zwei getrennt '
        'gebauten Karten', () {
      final a = beispiel();
      final b = beispiel();
      expect(identical(a, b), isFalse);

      expect(EssenLive(a), EssenLive(b));
      expect(EssenLive(a).hashCode, EssenLive(b).hashCode);
      expect(EssenLive(a).karte, a);
    });

    test('EssenLive(a) != EssenLive(b), wenn a != b', () {
      expect(EssenLive(beispiel(serie: 1)), isNot(EssenLive(beispiel())));
    });

    test('KeineLive() != EssenLive(…)', () {
      expect(KeineLive(), isNot(EssenLive(beispiel())));
      expect(EssenLive(beispiel()), isNot(KeineLive()));
    });
  });

  group('liveAnzeigeProvider', () {
    test('wirft, solange ihn niemand überschreibt', () {
      final container = ProviderContainer(retry: (_, _) => null);
      addTearDown(container.dispose);

      expect(() => container.read(liveAnzeigeProvider), throwsA(anything));
    });

    test('liefert die Überschreibung', () {
      final attrappe = AttrappeLiveAnzeige();
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [liveAnzeigeProvider.overrideWithValue(attrappe)],
      );
      addTearDown(container.dispose);

      expect(container.read(liveAnzeigeProvider), same(attrappe));
    });
  });
}
