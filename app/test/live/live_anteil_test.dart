// `drift` exportiert eigene `isNull` und `isNotNull` (Spaltenausdrücke) —
// die verdecken sonst die gleichnamigen Matcher, die `expect` unten
// braucht. Dieselbe Begründung wie in `test/live/live_provider_test.dart`.
import 'dart:async';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/core/messwert.dart';
import 'package:repit/data/cache.dart';
import 'package:repit/data/ereignisse.dart';
import 'package:repit/data/ernaehrung_repository.dart';
import 'package:repit/data/kalorienziele.dart';
import 'package:repit/data/mahlzeit_aufteilungen.dart';
import 'package:repit/data/stammdaten.dart';
import 'package:repit/ernaehrung/ernaehrung_provider.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_types.dart';
import 'package:repit/live/live_anzeige.dart';
import 'package:repit/live/live_provider.dart';
import 'package:repit/live/live_types.dart';

/// Tests für **#435** — der Anteil je Mahlzeit in der Nutzlast der
/// Live-Aktivität und im Live-Zustand (Task 6 des Plans
/// `docs/superpowers/plans/2026-11-10-mahlzeiten-aufteilung.md`, Spec
/// `docs/superpowers/specs/2026-11-10-mahlzeiten-aufteilung-design.md`,
/// Abschnitt „Live-Aktivität: Ringe als Anteil, ersetzt V2", V15, V16).
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden. Hält der
/// Implementierende einen Fall für falsch, meldet er das.
///
/// Nachbarn, die grün und unberührt bleiben: `live_anzeige_test.dart` (die
/// Nutzlast ohne Anteil, V2) und `live_provider_test.dart` (der Zustand
/// ohne Aufteilung). Der Kern ist in
/// `Packages/trainings_core/test/live_anteil_test.dart` geprüft.
///
/// ## API — aus dem Plan (Task 6, „Interfaces")
///
/// ```dart
/// MahlzeitStand({…, double? zielKcal});
/// MahlzeitRing({…, double? anteil});
/// ```
///
/// - `essenKarteAlsMap`: `'anteil': ?anteil` **nur bei `eintrag`** (V15).
/// - `_LiveSollHalter.build`: `null`, solange
///   `ernaehrungsTagProvider(esstag).mahlzeitenLaedt` (V16);
///   `MahlzeitStand.zielKcal = zeile.zielKcal`.
///
/// ## Die Regeln aus der Spec
///
/// - **V15:** je Mahlzeit ein Schlüssel `anteil` (Zahl), nur bei Eintrag
///   und Ziel. **Fehlt ein Wert, fehlt der Schlüssel** — nicht als `0`,
///   nicht als `null`. Ohne Eintrag fehlt er immer, wie `kcal`.
/// - **V16:** Die Live-Aktivität wartet, bis die Liste nicht mehr lädt.
///   Sonst ginge erst eine Karte nach V2 und Sekunden später eine mit
///   Anteil an iOS, und die Ringe sprängen.
/// - **Review Focus 2:** Während Einträge, Aufteilungen oder das
///   Tagesziel geladen werden, schickt die Live-Aktivität nichts.
///
/// ## Festlegungen des Test-Agenten — nicht von Tim freigegeben
///
/// - **Ein Anteil von genau 0 bei Eintrag geht als 0 mit** (Plan,
///   Pflichtfall). Er ist ein Wert, kein fehlender — derselbe Grund wie
///   bei der gewogenen 0 in `kcal`.
/// - **Der Anteil geht als `double`** über den Kanal: Die Swift-Seite
///   (Task 7) liest ihn als `Double`.
/// - **„Noch nicht gelesen" entsteht, indem die Datenbank Abfragen auf
///   eine Tabelle zurückhält**, bis der Test sie freigibt — wie in
///   `live_provider_test.dart`. Zurückgehalten wird `mahlzeit_aufteilungen`
///   bzw. `kalorienziele`; alle anderen Quellen sind dann gelesen.
/// - **Die Steuerung hängt im Test so am Soll wie in `LiveWacht`**:
///   `listen(liveSollProvider, … nimm(neu), fireImmediately: true)`. Gezählt
///   werden die Aufrufe an `AttrappeLiveAnzeige`.
/// - **Das Tagesziel ist eine feste Festlegung von Hand** (2.400 kcal),
///   damit es nicht von Health abhängt. Mit 25 · 35 · 30 · 10 sind die
///   Ziele: Frühstück 600, Mittag 840, Abend 720, Snack 240.
///
/// Alle Zahlen, Namen und Daten sind erfunden. Gerechnet wird im Januar
/// 2099, Berlin ist dann UTC+1.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Donnerstag, 15.01.2099, 12:00 Berliner Zeit.
  final mittags = DateTime.utc(2099, 1, 15, 11);
  const heute = '2099-01-15';

  // 04:00 Berliner Zeit am 16.01.2099 = 03:00 UTC.
  final verfaellt = DateTime.utc(2099, 1, 16, 3);

  // ═════════════════════════════════════════════════════════════════════
  // Nutzlast (V15)
  // ═════════════════════════════════════════════════════════════════════

  MahlzeitRing ring(
    Mahlzeit m, {
    required bool eintrag,
    int? kcal,
    double? anteil,
  }) => MahlzeitRing(mahlzeit: m, eintrag: eintrag, kcal: kcal, anteil: anteil);

  EssenKarte karteMit(List<MahlzeitRing> ringe) => EssenKarte(
    ringe: ringe,
    ersteOffene: Mahlzeit.abend,
    serie: 3,
    serieAbMorgen: 0,
    verfaelltUm: verfaellt,
  );

  List<Map<Object?, Object?>> mahlzeitenAus(Map<Object?, Object?> args) => [
    for (final m
        in ((args['essen']! as Map<Object?, Object?>)['mahlzeiten']!
            as List<Object?>))
      m! as Map<Object?, Object?>,
  ];

  Map<Object?, Object?> mahlzeitAus(Map<Object?, Object?> args, Mahlzeit m) =>
      mahlzeitenAus(args).singleWhere((x) => x['mahlzeit'] == m.name);

  group('Nutzlast: anteil nur bei Eintrag und Ziel (V15)', () {
    test('mit Eintrag und Anteil steht "anteil": 1.14 in der Map', () {
      final map = essenKarteAlsMap(
        karteMit([
          ring(Mahlzeit.fruehstueck, eintrag: true, kcal: 686, anteil: 1.14),
          ring(Mahlzeit.mittag, eintrag: true, kcal: 420, anteil: 0.5),
          ring(Mahlzeit.snack, eintrag: false),
          ring(Mahlzeit.abend, eintrag: false),
        ]),
        frisch: true,
      );

      expect(mahlzeitAus(map, Mahlzeit.fruehstueck), {
        'mahlzeit': 'fruehstueck',
        'eintrag': true,
        'kcal': 686,
        'anteil': 1.14,
      });
      expect(mahlzeitAus(map, Mahlzeit.mittag)['anteil'], 0.5);
      expect(mahlzeitAus(map, Mahlzeit.fruehstueck)['anteil'], isA<double>());
    });

    test('ohne Eintrag fehlt der Schlüssel — auch wenn der Ring 0 trägt', () {
      final map = essenKarteAlsMap(
        karteMit([
          ring(Mahlzeit.fruehstueck, eintrag: false, anteil: 0),
          ring(Mahlzeit.mittag, eintrag: false, anteil: 0),
          ring(Mahlzeit.snack, eintrag: false, anteil: 0),
          ring(Mahlzeit.abend, eintrag: false, anteil: 0),
        ]),
        frisch: false,
      );

      for (final m in mahlzeitenAus(map)) {
        expect(
          m.containsKey('anteil'),
          isFalse,
          reason:
              '${m['mahlzeit']}: eine offene Mahlzeit ist nicht „0 %" — '
              'fehlt ein Wert, fehlt der Schlüssel',
        );
        expect(m, {'mahlzeit': m['mahlzeit'], 'eintrag': false});
      }
    });

    test('ohne Eintrag fehlt er auch bei einem Anteil über 0', () {
      // Darf aus essenKarte nicht entstehen; die Nutzlast entscheidet
      // trotzdem am Eintrag, nicht am Wert.
      final map = essenKarteAlsMap(
        karteMit([
          ring(Mahlzeit.fruehstueck, eintrag: false, anteil: 0.8),
          ring(Mahlzeit.mittag, eintrag: false),
          ring(Mahlzeit.snack, eintrag: false),
          ring(Mahlzeit.abend, eintrag: false),
        ]),
        frisch: true,
      );
      expect(
        mahlzeitAus(map, Mahlzeit.fruehstueck).containsKey('anteil'),
        isFalse,
      );
    });

    test('ohne Ziel fehlt er — mit Eintrag, V2', () {
      final map = essenKarteAlsMap(
        karteMit([
          ring(Mahlzeit.fruehstueck, eintrag: true, kcal: 686),
          ring(Mahlzeit.mittag, eintrag: true),
          ring(Mahlzeit.snack, eintrag: false),
          ring(Mahlzeit.abend, eintrag: false),
        ]),
        frisch: true,
      );

      expect(mahlzeitAus(map, Mahlzeit.fruehstueck), {
        'mahlzeit': 'fruehstueck',
        'eintrag': true,
        'kcal': 686,
      });
      expect(mahlzeitAus(map, Mahlzeit.mittag), {
        'mahlzeit': 'mittag',
        'eintrag': true,
      });
    });

    test('ein Anteil von genau 0 bei Eintrag geht als 0 mit (0 kcal, der '
        'schwarze Kaffee)', () {
      final map = essenKarteAlsMap(
        karteMit([
          ring(Mahlzeit.fruehstueck, eintrag: false),
          ring(Mahlzeit.mittag, eintrag: false),
          ring(Mahlzeit.snack, eintrag: true, kcal: 0, anteil: 0),
          ring(Mahlzeit.abend, eintrag: false),
        ]),
        frisch: true,
      );

      final snack = mahlzeitAus(map, Mahlzeit.snack);
      expect(snack.containsKey('anteil'), isTrue);
      expect(snack['anteil'], 0);
      expect(snack, {
        'mahlzeit': 'snack',
        'eintrag': true,
        'kcal': 0,
        'anteil': 0,
      });
    });

    test('aus essenKarte gerechnet: Anteil nur bei der Mahlzeit mit Eintrag '
        'und Ziel', () {
      final karte = essenKarte(
        mahlzeiten: [
          const MahlzeitStand(
            mahlzeit: Mahlzeit.fruehstueck,
            hatEintrag: true,
            kcal: 686,
            zielKcal: 600,
          ),
          // Ohne Eintrag mit Ziel: der Ring trägt 0, der Schlüssel fehlt.
          const MahlzeitStand(
            mahlzeit: Mahlzeit.mittag,
            hatEintrag: false,
            kcal: null,
            zielKcal: 840,
          ),
          // Mit Eintrag, ohne Kalorienangabe: kein Anteil.
          const MahlzeitStand(
            mahlzeit: Mahlzeit.snack,
            hatEintrag: true,
            kcal: null,
            zielKcal: 240,
          ),
          // Mit Eintrag, ohne Ziel: V2.
          const MahlzeitStand(
            mahlzeit: Mahlzeit.abend,
            hatEintrag: true,
            kcal: 512,
          ),
        ],
        serie: (heute: 3, abMorgen: 3),
        jetzt: mittags,
      );

      final map = essenKarteAlsMap(karte, frisch: true);
      expect(mahlzeitenAus(map), [
        {
          'mahlzeit': 'fruehstueck',
          'eintrag': true,
          'kcal': 686,
          'anteil': 1.14,
        },
        {'mahlzeit': 'mittag', 'eintrag': false},
        {'mahlzeit': 'snack', 'eintrag': true},
        {'mahlzeit': 'abend', 'eintrag': true, 'kcal': 512},
      ]);
    });

    test('über den Kanal: zeige schickt denselben Anteil', () async {
      const kanal = MethodChannel('de.rosenbach.repit/live');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final aufrufe = <MethodCall>[];
      messenger.setMockMethodCallHandler(kanal, (aufruf) async {
        aufrufe.add(aufruf);
        return 'gestartet';
      });
      addTearDown(() => messenger.setMockMethodCallHandler(kanal, null));

      final karte = karteMit([
        ring(Mahlzeit.fruehstueck, eintrag: true, kcal: 686, anteil: 1.14),
        ring(Mahlzeit.mittag, eintrag: false, anteil: 0),
        ring(Mahlzeit.snack, eintrag: true, kcal: 0, anteil: 0),
        ring(Mahlzeit.abend, eintrag: true, kcal: 512),
      ]);
      await KanalLiveAnzeige(kanal: kanal).zeige(karte, frisch: true);

      final args = aufrufe.single.arguments as Map<Object?, Object?>;
      expect(args, equals(essenKarteAlsMap(karte, frisch: true)));
      expect(mahlzeitAus(args, Mahlzeit.fruehstueck)['anteil'], 1.14);
      expect(mahlzeitAus(args, Mahlzeit.mittag).containsKey('anteil'), isFalse);
      expect(mahlzeitAus(args, Mahlzeit.snack)['anteil'], 0);
      expect(mahlzeitAus(args, Mahlzeit.abend).containsKey('anteil'), isFalse);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  // Zustand (V16)
  // ═════════════════════════════════════════════════════════════════════

  group('Zustand: liveSollProvider mit Anteil, wartet nach V16', () {
    const ziel2400 = KalorienzielFestlegung(
      abTag: '2099-01-01',
      kcal: 2400,
      herkunft: KalorienzielHerkunft.hand,
    );
    final aufteilung = MahlzeitAufteilung(
      fruehstueck: 25,
      mittag: 35,
      abend: 30,
    );
    final aufteilungAb = AufteilungAb(
      abTag: '2099-01-01',
      aufteilung: aufteilung,
    );

    Eintrag eintrag(Mahlzeit m, {double? kcal}) => Eintrag(
      tagesSchluessel: heute,
      mahlzeit: m,
      zeitpunkt: DateTime.parse('${heute}T09:00:00Z'),
      name: 'Prüfgericht',
      naehrwerte: Naehrwerte(kcal: kcal),
    );

    /// Echte Datenbank im Speicher, feste Uhr, abgeschaltete Wiederholung
    /// (`CLAUDE.md`). Das feste Tagesziel, [aufteilungen] und [eintraege]
    /// liegen in der Tabelle, **bevor** irgendein Provider liest. Die
    /// Steuerung hängt am Soll wie in `LiveWacht`.
    Future<
      ({
        ProviderContainer container,
        AppCache db,
        AttrappeLiveAnzeige anzeige,
        _Mitschnitt mitschnitt,
        List<LiveSoll?> werte,
      })
    >
    aufbau({
      List<AufteilungAb>? aufteilungen,
      List<Eintrag> eintraege = const [],
      bool Function(String sql)? halte,
    }) async {
      final mitschnitt = _Mitschnitt();
      final db = AppCache(NativeDatabase.memory().interceptWith(mitschnitt));
      final anzeige = AttrappeLiveAnzeige();

      await KalorienzielRepository(db).setze(ziel2400);
      for (final a in aufteilungen ?? [aufteilungAb]) {
        await MahlzeitAufteilungRepository(db).setze(a);
      }
      final repo = ErnaehrungRepository(db);
      for (final e in eintraege) {
        await repo.buche(e);
      }
      if (halte != null) mitschnitt.halte(halte);

      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          appCacheProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(() => mittags),
          stammdatenProvider.overrideWith(
            () => _Stammdaten(const Stammdaten()),
          ),
          dailyMetricsProvider.overrideWith(
            () => _Tageswerte(
              LeerNachLauf<List<DailyMetrics>>(gelaufen: mittags),
            ),
          ),
          fremdeMahlzeitenProvider.overrideWith2(
            (tag) =>
                _Fremde(LeerNachLauf<List<FremdeMahlzeit>>(gelaufen: mittags)),
          ),
          liveAnzeigeProvider.overrideWithValue(anzeige),
        ],
      );
      addTearDown(() async {
        mitschnitt.gibFrei();
        container.dispose();
        await db.close();
      });

      final werte = <LiveSoll?>[];
      container.listen(liveSteuerungProvider, (_, _) {});
      final steuerung = container.read(liveSteuerungProvider.notifier);
      container.listen<LiveSoll?>(liveSollProvider, (_, neu) {
        werte.add(neu);
        unawaited(steuerung.nimm(neu));
      }, fireImmediately: true);

      return (
        container: container,
        db: db,
        anzeige: anzeige,
        mitschnitt: mitschnitt,
        werte: werte,
      );
    }

    EssenKarte karteAus(LiveSoll? soll) {
      expect(soll, isA<EssenLive>());
      return (soll! as EssenLive).karte;
    }

    MahlzeitRing ringIn(EssenKarte k, Mahlzeit m) =>
        k.ringe.singleWhere((r) => r.mahlzeit == m);

    test('solange die Aufteilungen nicht gelesen sind, ist das Soll null — '
        'danach eine EssenLive mit Anteil, und nur die geht an iOS', () async {
      final b = await aufbau(
        eintraege: [eintrag(Mahlzeit.fruehstueck, kcal: 686)],
        halte: _aufAufteilungen,
      );
      final c = b.container;

      await _bis(
        () =>
            c.read(eigeneEintraegeProvider(heute)).hasValue &&
            c.read(serieProvider).hasValue &&
            c.read(kalorienzieleProvider).hasValue &&
            !c.read(auszeitenProvider).laden,
      );
      await _laufenLassen();

      expect(
        c.read(ernaehrungsTagProvider(heute)).mahlzeitenLaedt,
        isTrue,
        reason: 'Vorbedingung: nur die Aufteilungen fehlen noch',
      );
      expect(c.read(ernaehrungsTagProvider(heute)).zielKcal, 2400);
      expect(
        c.read(liveSollProvider),
        isNull,
        reason:
            'V16: sonst ginge erst eine Karte nach V2 an iOS und Sekunden '
            'später eine mit Anteil — die Ringe sprängen',
      );
      expect(b.werte, everyElement(isNull));
      expect(b.anzeige.zeigeAufrufe, isEmpty);
      expect(b.anzeige.beendeAlleAufrufe, 0);

      b.mitschnitt.gibFrei();
      await _bis(() => c.read(liveSollProvider) is EssenLive);
      await _laufenLassen();

      final karte = karteAus(c.read(liveSollProvider));
      expect(ringIn(karte, Mahlzeit.fruehstueck).anteil, 1.14);
      expect(ringIn(karte, Mahlzeit.fruehstueck).kcal, 686);
      expect(ringIn(karte, Mahlzeit.mittag).anteil, 0);
      expect(ringIn(karte, Mahlzeit.abend).anteil, 0);
      expect(ringIn(karte, Mahlzeit.snack).anteil, 0);

      expect(b.werte.whereType<EssenLive>().toList(), [
        EssenLive(karte),
      ], reason: 'keine Karte nach V2 vor der mit Anteil');
      expect(b.anzeige.zeigeAufrufe, [(karte: karte, frisch: true)]);
    });

    test('solange das Tagesziel nicht gelesen ist, ist das Soll null '
        '(Review Focus 2)', () async {
      final b = await aufbau(
        eintraege: [eintrag(Mahlzeit.fruehstueck, kcal: 686)],
        halte: _aufKalorienziele,
      );
      final c = b.container;

      await _bis(
        () =>
            c.read(eigeneEintraegeProvider(heute)).hasValue &&
            c.read(serieProvider).hasValue &&
            c.read(mahlzeitAufteilungenProvider).hasValue &&
            !c.read(auszeitenProvider).laden,
      );
      await _laufenLassen();

      expect(
        c.read(kalorienzieleProvider).hasValue,
        isFalse,
        reason: 'Vorbedingung: das Tagesziel ist noch nicht gelesen',
      );
      expect(c.read(ernaehrungsTagProvider(heute)).mahlzeitenLaedt, isTrue);
      expect(c.read(liveSollProvider), isNull);
      expect(b.werte, everyElement(isNull));
      expect(b.anzeige.zeigeAufrufe, isEmpty);

      b.mitschnitt.gibFrei();
      await _bis(() => c.read(liveSollProvider) is EssenLive);
      await _laufenLassen();

      final karte = karteAus(c.read(liveSollProvider));
      expect(ringIn(karte, Mahlzeit.fruehstueck).anteil, 1.14);
      expect(b.anzeige.zeigeAufrufe, [(karte: karte, frisch: true)]);
    });

    test('das Ziel kommt aus MahlzeitZeile.zielKcal — der Anteil ist '
        'mahlzeitAnteil der Zeile', () async {
      final b = await aufbau(
        eintraege: [
          eintrag(Mahlzeit.fruehstueck, kcal: 686),
          eintrag(Mahlzeit.mittag, kcal: 420),
          eintrag(Mahlzeit.snack, kcal: null),
        ],
      );
      final c = b.container;
      await _bis(() => c.read(liveSollProvider) is EssenLive);
      await _laufenLassen();

      final tag = c.read(ernaehrungsTagProvider(heute));
      final karte = karteAus(c.read(liveSollProvider));
      for (final zeile in tag.mahlzeiten) {
        expect(zeile.zielKcal, isNotNull, reason: 'Vorbedingung');
        expect(
          ringIn(karte, zeile.mahlzeit).anteil,
          mahlzeitAnteil(
            hatEintrag: !zeile.leer,
            kcal: zeile.leer ? null : zeile.summe.kcal,
            zielKcal: zeile.zielKcal,
          ),
          reason: zeile.mahlzeit.name,
        );
      }
      expect(ringIn(karte, Mahlzeit.fruehstueck).anteil, 1.14);
      expect(ringIn(karte, Mahlzeit.mittag).anteil, 0.5);
      expect(
        ringIn(karte, Mahlzeit.snack).anteil,
        isNull,
        reason: 'Eintrag ohne Kalorienangabe: V2, nicht 0',
      );
      expect(ringIn(karte, Mahlzeit.snack).eintrag, isTrue);
      expect(ringIn(karte, Mahlzeit.abend).anteil, 0);
      expect(karte.ersteOffene, Mahlzeit.abend);
    });

    test('ohne gesicherte Aufteilung eine Karte nach V2 — kein Anteil, kein '
        'Startwert als Ersatz', () async {
      final b = await aufbau(
        aufteilungen: const [],
        eintraege: [eintrag(Mahlzeit.fruehstueck, kcal: 686)],
      );
      final c = b.container;
      await _bis(() => c.read(liveSollProvider) is EssenLive);
      await _laufenLassen();

      final karte = karteAus(c.read(liveSollProvider));
      for (final r in karte.ringe) {
        expect(r.anteil, isNull, reason: r.mahlzeit.name);
      }
      expect(ringIn(karte, Mahlzeit.fruehstueck).eintrag, isTrue);
      expect(ringIn(karte, Mahlzeit.fruehstueck).kcal, 686);
      expect(b.anzeige.zeigeAufrufe, hasLength(1));
    });

    test('dieselbe Karte zweimal gerechnet → kein zweiter Aufruf an die '
        'Attrappe; eine neue Aufteilung → ein zweiter, mit neuem '
        'Anteil', () async {
      final b = await aufbau(
        eintraege: [eintrag(Mahlzeit.fruehstueck, kcal: 686)],
      );
      final c = b.container;
      await _bis(() => b.anzeige.zeigeAufrufe.isNotEmpty);
      await _laufenLassen();
      expect(b.anzeige.zeigeAufrufe, hasLength(1));
      final erste = b.anzeige.zeigeAufrufe.single.karte;
      expect(ringIn(erste, Mahlzeit.fruehstueck).anteil, 1.14);

      // Die Einträge neu gelesen, ohne Änderung.
      await c.read(eigeneEintraegeProvider(heute).notifier).neuLesen();
      await _laufenLassen();
      // Dieselbe Aufteilung noch einmal gesichert, ab heute: die Historie
      // ändert sich, die geltende Aufteilung nicht.
      await c
          .read(mahlzeitAufteilungenProvider.notifier)
          .setzeAbHeute(
            MahlzeitAufteilung(fruehstueck: 25, mittag: 35, abend: 30),
          );
      await _laufenLassen();

      expect(
        b.anzeige.zeigeAufrufe,
        hasLength(1),
        reason:
            'jedes Zeigen ist ein Update an iOS (Review Focus 4 der '
            'Live-Spec)',
      );

      // Frühstück 30 % von 2.400 = 720 → 686 / 720 = 0,95.
      await c
          .read(mahlzeitAufteilungenProvider.notifier)
          .setzeAbHeute(
            MahlzeitAufteilung(fruehstueck: 30, mittag: 35, abend: 30),
          );
      await _bis(() => b.anzeige.zeigeAufrufe.length > 1);
      await _laufenLassen();

      expect(b.anzeige.zeigeAufrufe, hasLength(2));
      final zweite = b.anzeige.zeigeAufrufe.last;
      expect(zweite.frisch, isFalse);
      expect(ringIn(zweite.karte, Mahlzeit.fruehstueck).anteil, 0.95);
      expect(
        b.werte.whereType<Null>(),
        hasLength(1),
        reason:
            'nur das erste Soll vor dem Lesen ist null — beim Sichern '
            'der Aufteilung blitzt kein null dazwischen',
      );
    });

    test(
      'was an die Attrappe geht, trägt den Anteil in der Nutzlast',
      () async {
        final b = await aufbau(
          eintraege: [eintrag(Mahlzeit.fruehstueck, kcal: 686)],
        );
        await _bis(() => b.anzeige.zeigeAufrufe.isNotEmpty);
        await _laufenLassen();

        final aufruf = b.anzeige.zeigeAufrufe.single;
        final map = essenKarteAlsMap(aufruf.karte, frisch: aufruf.frisch);
        expect(mahlzeitAus(map, Mahlzeit.fruehstueck), {
          'mahlzeit': 'fruehstueck',
          'eintrag': true,
          'kcal': 686,
          'anteil': 1.14,
        });
        for (final m in [Mahlzeit.mittag, Mahlzeit.snack, Mahlzeit.abend]) {
          expect(mahlzeitAus(map, m), {
            'mahlzeit': m.name,
            'eintrag': false,
          }, reason: '${m.name}: offen, der Ring trägt 0, der Schlüssel fehlt');
        }
      },
    );
  });
}

/// Hängt ein Lesen, scheitert der Fall nach fünf Sekunden, statt die
/// vollen 30 Sekunden zu warten.
const _frist = Duration(seconds: 5);

/// Wartet, bis [bedingung] gilt — höchstens [_frist], dann scheitert der
/// Fall mit einer `TimeoutException`.
Future<void> _bis(bool Function() bedingung) async {
  final ende = DateTime.now().add(_frist);
  while (!bedingung()) {
    if (DateTime.now().isAfter(ende)) {
      throw TimeoutException('Bedingung nicht erreicht', _frist);
    }
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}

/// Lässt die Läufe arbeiten, ohne festzulegen, wie viele Schritte sie
/// brauchen.
Future<void> _laufenLassen() async {
  for (var i = 0; i < 50; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}

bool _aufAufteilungen(String sql) =>
    sql.toLowerCase().contains('mahlzeit_aufteilungen');

bool _aufKalorienziele(String sql) =>
    sql.toLowerCase().contains('kalorienziele');

/// Hält auf Wunsch `SELECT`-Abfragen zurück, bis [gibFrei] kommt.
class _Mitschnitt extends QueryInterceptor {
  bool Function(String sql)? _halte;
  Completer<void> _frei = Completer<void>()..complete();

  void halte(bool Function(String sql) bedingung) {
    _halte = bedingung;
    _frei = Completer<void>();
  }

  void gibFrei() {
    _halte = null;
    if (!_frei.isCompleted) _frei.complete();
  }

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    final bedingung = _halte;
    if (bedingung != null && bedingung(statement)) {
      await _frei.future;
    }
    return executor.runSelect(statement, args);
  }
}

/// Steuerbare Ableger der echten Notifier — Riverpods Provider-Typen sind
/// invariant (siehe `test/ernaehrung/ernaehrung_provider_test.dart`).
class _Tageswerte extends DailyMetricsNotifier {
  _Tageswerte(this.wert);

  final Messwert<List<DailyMetrics>> wert;

  @override
  Future<Messwert<List<DailyMetrics>>> build() async => wert;
}

class _Stammdaten extends StammdatenNotifier {
  _Stammdaten(this.wert);

  final Stammdaten wert;

  @override
  Future<Stammdaten> build() async => wert;
}

class _Fremde extends FremdeMahlzeitenNotifier {
  _Fremde(this.wert) : super('');

  final Messwert<List<FremdeMahlzeit>> wert;

  @override
  Future<Messwert<List<FremdeMahlzeit>>> build() async => wert;
}
