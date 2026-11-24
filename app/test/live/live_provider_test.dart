// `drift` exportiert eigene `isNull` und `isNotNull` (Spaltenausdrücke) —
// die verdecken sonst die gleichnamigen Matcher, die `expect` unten
// braucht. Dieselbe Begründung wie in `test/data/ernaehrung_repository_test.dart`.
import 'dart:async';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/core/messwert.dart';
import 'package:repit/data/cache.dart';
import 'package:repit/data/ernaehrung_repository.dart';
import 'package:repit/data/stammdaten.dart';
import 'package:repit/ernaehrung/ernaehrung_provider.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_types.dart';
import 'package:repit/live/live_anzeige.dart';
import 'package:repit/live/live_provider.dart';
import 'package:repit/live/live_types.dart';

/// Tests für **#368** — die Serie aus der Datenbank und der Live-Zustand
/// (Task 6 des Plans `docs/superpowers/plans/2026-11-05-live-aktivitaet.md`,
/// Spec `docs/superpowers/specs/2026-11-05-live-aktivitaet-design.md`,
/// Abschnitt „Die Dart-Seite → Zustand").
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden. Hält der
/// Implementierende einen Fall für falsch, meldet er das.
///
/// ## Was diese Datei verbindlich vorgibt (aus Plan und Spec)
///
/// In `lib/data/ernaehrung_repository.dart`, an `ErnaehrungRepository`:
///
/// ```dart
/// Future<Map<String, Set<Mahlzeit>>> mahlzeitenJeTag({required String bis});
/// ```
///
/// In `lib/live/live_provider.dart`:
///
/// ```dart
/// final esstagProvider = NotifierProvider<EsstagNotifier, String>(…);
/// class EsstagNotifier extends Notifier<String> { Future<void> pruefe(); }
/// final serieProvider = AsyncNotifierProvider<…, ({int heute, int abMorgen})>(…);
/// final liveSollProvider = Provider<LiveSoll?>(…);
/// final liveSteuerungProvider = NotifierProvider<LiveSteuerung, void>(…);
/// class LiveSteuerung extends Notifier<void> {
///   Future<void> nimm(LiveSoll? soll);
///   Future<void> beiRueckkehr();
///   Future<LiveZiel?> holeLink();
/// }
/// ```
///
/// Aus Task 5 benutzt: `LiveSoll` (`KeineLive()`, `EssenLive(karte)` mit
/// dem Feld `karte`), `LiveErgebnis` (`LiveGestartet()`), `LiveZiel`,
/// `LiveAnzeige` und `liveAnzeigeProvider` (ein `Provider<LiveAnzeige>`,
/// überschrieben mit `overrideWithValue`).
///
/// ## Festlegungen des Test-Agenten — nicht von Tim freigegeben
///
/// - **Eine eigene Attrappe statt `AttrappeLiveAnzeige`.** Der Plan nennt
///   für Task 6 die Attrappe aus Task 5. Deren Feldnamen („öffentliche
///   Listen der Aufrufe") legt aber erst der Test zu Task 5 fest, und den
///   gibt es noch nicht. Diese Datei implementiert deshalb selbst das
///   Protokoll `LiveAnzeige`, dessen Signatur die Spec festlegt — so
///   nagelt sie keinen Namen fest, den ein anderer Test anders wählt.
///   `nimmLink` leert dabei, wie die Spec es für den Kanal verlangt.
/// - **SQL-Prüfung über einen `QueryInterceptor`**, wie in
///   `test/data/ernaehrung_tagessummen_test.dart`. Verlangt ist: Jede
///   Abfrage von `mahlzeitenJeTag` trägt ein `WHERE`, eine entdoppelt in
///   der Datenbank (`DISTINCT` laut Spec, `GROUP BY` gilt auch), **keine
///   liefert mehr Zeilen, als es Paare (Tag, Mahlzeit) gibt**, und die
///   Zahl der Abfragen wächst nicht mit der Zahl der Tage.
/// - **„Noch nicht gelesen" wird hergestellt, indem die Datenbank
///   Abfragen auf `eintraege` zurückhält**, bis der Test sie freigibt.
///   Unterschieden wird die Serie-Abfrage an ihrem `DISTINCT`/`GROUP BY`
///   — dieselbe Bedingung, die die SQL-Prüfung oben ohnehin verlangt.
/// - **Ein Nachlesen ohne Änderung meldet kein neues Soll**, auch kein
///   `null` zwischendurch. Ein `null` dazwischen hieße in Task 7 ein
///   zweites `zeige` mit derselben Karte (Review Focus 4).
/// - **`beiRueckkehr()`, während das Soll noch `null` ist, ruft nichts
///   auf, und das nächste Zeigen danach ist frisch.**
/// - **`pruefe()` ohne Wechsel des Esstags meldet nichts** („setzt den
///   Zustand nur bei einer Änderung", Spec).
/// - Über die Kalorien einer **offenen** Mahlzeit sagt diese Datei nichts.
///   Die Spec gibt `kcal = summe.kcal` vor, und die leere Summe trägt
///   Nullen; ob dort `0` oder `null` ankommt, entscheidet nicht dieser
///   Test.
///
/// Alle Zahlen, Namen und Daten sind erfunden. Gerechnet wird im Januar
/// 2099, Berlin ist dann UTC+1.
void main() {
  // Donnerstag, 15.01.2099, 12:00 Berliner Zeit.
  final mittags = DateTime.utc(2099, 1, 15, 11);
  const heute = '2099-01-15';
  const gestern = '2099-01-14';
  const vorgestern = '2099-01-13';

  Eintrag eintrag({
    required String tag,
    Mahlzeit mahlzeit = Mahlzeit.mittag,
    DateTime? zeitpunkt,
    double? kcal = 400,
    String name = 'Prüfgericht',
  }) => Eintrag(
    tagesSchluessel: tag,
    mahlzeit: mahlzeit,
    zeitpunkt: zeitpunkt ?? DateTime.parse('${tag}T11:00:00Z'),
    name: name,
    naehrwerte: Naehrwerte(kcal: kcal),
  );

  /// Echte Datenbank im Speicher, steuerbare Uhr, abgeschaltete
  /// Wiederholung (`CLAUDE.md`). Health und Stammdaten sind
  /// überschrieben — diese Datei fasst den Kanal nicht an.
  ({
    ProviderContainer container,
    ErnaehrungRepository repo,
    _Mitschnitt mitschnitt,
    _Anzeige anzeige,
    void Function(DateTime) stelleUhr,
  })
  behaelter({DateTime? jetzt}) {
    var uhr = jetzt ?? mittags;
    final mitschnitt = _Mitschnitt();
    final db = AppCache(NativeDatabase.memory().interceptWith(mitschnitt));
    final anzeige = _Anzeige();

    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        appCacheProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => uhr),
        stammdatenProvider.overrideWith(() => _Stammdaten(const Stammdaten())),
        dailyMetricsProvider.overrideWith(
          () => _Tageswerte(LeerNachLauf<List<DailyMetrics>>(gelaufen: uhr)),
        ),
        fremdeMahlzeitenProvider.overrideWith2(
          (tag) => _Fremde(LeerNachLauf<List<FremdeMahlzeit>>(gelaufen: uhr)),
        ),
        liveAnzeigeProvider.overrideWithValue(anzeige),
      ],
    );
    addTearDown(() async {
      mitschnitt.gibFrei();
      container.dispose();
      await db.close();
    });
    return (
      container: container,
      repo: container.read(ernaehrungRepositoryProvider),
      mitschnitt: mitschnitt,
      anzeige: anzeige,
      stelleUhr: (neu) => uhr = neu,
    );
  }

  /// Wartet, bis Einträge des Esstags und Serie gelesen sind, und gibt
  /// das Soll zurück.
  Future<LiveSoll?> gelesen(ProviderContainer c) async {
    final tag = c.read(esstagProvider);
    await c.read(eigeneEintraegeProvider(tag).future).timeout(_frist);
    await c.read(serieProvider.future).timeout(_frist);
    await pumpEventQueue();
    return c.read(liveSollProvider);
  }

  EssenKarte karteAus(LiveSoll? soll) {
    expect(soll, isA<EssenLive>());
    return (soll! as EssenLive).karte;
  }

  MahlzeitRing ring(EssenKarte karte, Mahlzeit m) =>
      karte.ringe.singleWhere((r) => r.mahlzeit == m);

  // ─────────────────────────────────────────────────────────────────────
  group('mahlzeitenJeTag (Repository)', () {
    test('ohne Einträge eine leere Map', () async {
      final b = behaelter();
      expect(await b.repo.mahlzeitenJeTag(bis: heute), isEmpty);
    });

    test('je Tag die Menge der Mahlzeiten mit Eintrag', () async {
      final b = behaelter();
      await b.repo.buche(eintrag(tag: vorgestern, mahlzeit: Mahlzeit.snack));
      await b.repo.buche(eintrag(tag: gestern, mahlzeit: Mahlzeit.fruehstueck));
      await b.repo.buche(eintrag(tag: gestern, mahlzeit: Mahlzeit.abend));
      await b.repo.buche(eintrag(tag: heute, mahlzeit: Mahlzeit.mittag));

      expect(await b.repo.mahlzeitenJeTag(bis: heute), {
        vorgestern: {Mahlzeit.snack},
        gestern: {Mahlzeit.fruehstueck, Mahlzeit.abend},
        heute: {Mahlzeit.mittag},
      });
    });

    test(
      'zwei Einträge derselben Mahlzeit ergeben einen Mengeneintrag',
      () async {
        final b = behaelter();
        await b.repo.buche(eintrag(tag: heute, name: 'Suppe'));
        await b.repo.buche(eintrag(tag: heute, name: 'Brot'));

        final je = await b.repo.mahlzeitenJeTag(bis: heute);
        expect(je, {
          heute: {Mahlzeit.mittag},
        });
      },
    );

    test('bis ist eingeschlossen, Tage danach fehlen', () async {
      final b = behaelter();
      await b.repo.buche(eintrag(tag: vorgestern));
      await b.repo.buche(eintrag(tag: gestern));
      await b.repo.buche(eintrag(tag: heute));
      await b.repo.buche(eintrag(tag: '2099-01-20'));

      final je = await b.repo.mahlzeitenJeTag(bis: gestern);
      expect(je.keys.toSet(), {vorgestern, gestern});
    });

    test('es gibt keine untere Grenze — auch ein Tag vor über einem Jahr '
        'steht drin', () async {
      // Spec: „Eine untere Grenze bekommt sie nicht, sonst wäre eine Serie
      // länger als das Fenster falsch."
      final b = behaelter();
      await b.repo.buche(eintrag(tag: '2097-11-30'));
      await b.repo.buche(eintrag(tag: heute));

      final je = await b.repo.mahlzeitenJeTag(bis: heute);
      expect(je.keys.toSet(), {'2097-11-30', heute});
    });

    test('gezählt wird der Esstag des Eintrags, nicht der Kalendertag '
        'seines Zeitpunkts', () async {
      final b = behaelter();
      // 01:30 Berlin am 15.01. gehört zum Abend des 14.01.
      await b.repo.buche(
        eintrag(
          tag: gestern,
          mahlzeit: Mahlzeit.abend,
          zeitpunkt: DateTime.utc(2099, 1, 15, 0, 30),
        ),
      );

      expect(await b.repo.mahlzeitenJeTag(bis: heute), {
        gestern: {Mahlzeit.abend},
      });
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  group('Gefiltert und entdoppelt wird in SQL (Hausregel 2)', () {
    test('jede Abfrage trägt ein WHERE, eine entdoppelt, keine liefert '
        'doppelte Zeilen', () async {
      final b = behaelter();
      // 20 Tage, je zweimal Mittag und einmal Frühstück → 40 Paare.
      for (var i = 1; i <= 20; i++) {
        final tag = '2099-01-${i.toString().padLeft(2, '0')}';
        await b.repo.buche(eintrag(tag: tag, name: 'A'));
        await b.repo.buche(eintrag(tag: tag, name: 'B'));
        await b.repo.buche(eintrag(tag: tag, mahlzeit: Mahlzeit.fruehstueck));
      }
      // Nach `bis` — darf nicht aus der Datenbank kommen.
      for (var i = 21; i <= 28; i++) {
        final tag = '2099-01-${i.toString().padLeft(2, '0')}';
        await b.repo.buche(eintrag(tag: tag));
      }

      b.mitschnitt.abfragen.clear();
      final je = await b.repo.mahlzeitenJeTag(bis: '2099-01-20');
      expect(je, hasLength(20));

      final abfragen = b.mitschnitt.abfragen;
      expect(abfragen, isNotEmpty);
      for (final a in abfragen) {
        final text = a.text.toLowerCase();
        expect(
          text,
          contains('where'),
          reason:
              'ohne Filter käme jede jemals gebuchte Mahlzeit in den '
              'Speicher: ${a.text}',
        );
        expect(
          a.zeilen,
          lessThanOrEqualTo(40),
          reason:
              'mehr Zeilen als Paare (Tag, Mahlzeit) heißt: entdoppelt '
              'oder gefiltert wird erst in Dart: ${a.text}',
        );
      }
      expect(
        abfragen.where((a) => _entdoppelt(a.text)),
        isNotEmpty,
        reason:
            'entdoppelt wird in der Datenbank (DISTINCT laut Spec): '
            '${abfragen.map((a) => a.text)}',
      );
    });

    test('die Zahl der Abfragen wächst nicht mit der Zahl der Tage', () async {
      final b = behaelter();
      for (var i = 1; i <= 2; i++) {
        await b.repo.buche(eintrag(tag: '2099-01-0$i'));
      }
      b.mitschnitt.abfragen.clear();
      await b.repo.mahlzeitenJeTag(bis: '2099-01-31');
      final wenige = b.mitschnitt.abfragen.length;

      for (var i = 3; i <= 28; i++) {
        await b.repo.buche(
          eintrag(tag: '2099-01-${i.toString().padLeft(2, '0')}'),
        );
      }
      b.mitschnitt.abfragen.clear();
      await b.repo.mahlzeitenJeTag(bis: '2099-01-31');
      final viele = b.mitschnitt.abfragen.length;

      expect(viele, wenige, reason: '28 Tage sind eine Abfrage, nicht 28');
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  group('Solange nicht gelesen ist, gibt es kein Soll (V10)', () {
    test('beim ersten Lesen ist das Soll null, danach EssenLive mit drei '
        'offenen Hauptmahlzeiten', () async {
      final b = behaelter();
      final werte = <LiveSoll?>[];
      b.container.listen(
        liveSollProvider,
        (_, neu) => werte.add(neu),
        fireImmediately: true,
      );

      expect(
        werte.first,
        isNull,
        reason:
            'eine Karte mit drei offenen Mahlzeiten während des Ladens '
            'behauptete „nichts gegessen" — 01 auf dem Sperrbildschirm',
      );

      final karte = karteAus(await gelesen(b.container));
      for (final m in [Mahlzeit.fruehstueck, Mahlzeit.mittag, Mahlzeit.abend]) {
        expect(ring(karte, m).eintrag, isFalse, reason: '$m');
      }
      expect(ring(karte, Mahlzeit.snack).eintrag, isFalse);
      expect(karte.ersteOffene, Mahlzeit.fruehstueck);
      expect(karte.serie, 0);
      expect(karte.serieAbMorgen, 0);
      expect(karte.ringe.map((r) => r.mahlzeit).toList(), Mahlzeit.values);
    });

    test('hängt die Datenbank, bleibt das Soll null — auch mit Einträgen '
        'in der Tabelle', () async {
      final b = behaelter();
      await b.repo.buche(eintrag(tag: heute, mahlzeit: Mahlzeit.fruehstueck));

      b.mitschnitt.halte((sql) => _aufEintraege(sql));
      final werte = <LiveSoll?>[];
      b.container.listen(
        liveSollProvider,
        (_, neu) => werte.add(neu),
        fireImmediately: true,
      );
      await pumpEventQueue();

      expect(b.container.read(liveSollProvider), isNull);
      expect(werte, everyElement(isNull));

      b.mitschnitt.gibFrei();
      final karte = karteAus(await gelesen(b.container));
      expect(ring(karte, Mahlzeit.fruehstueck).eintrag, isTrue);
      expect(karte.serie, 1);
    });

    test('Einträge gelesen, Serie noch nicht → null', () async {
      final b = behaelter();
      await b.repo.buche(eintrag(tag: heute));

      b.mitschnitt.halte((sql) => _aufEintraege(sql) && _entdoppelt(sql));
      b.container.listen(liveSollProvider, (_, _) {});
      await b.container
          .read(eigeneEintraegeProvider(heute).future)
          .timeout(_frist);
      await pumpEventQueue();

      expect(
        b.container.read(eigeneEintraegeProvider(heute)).hasValue,
        isTrue,
        reason: 'Vorbedingung: die Einträge des Esstags sind gelesen',
      );
      expect(b.container.read(liveSollProvider), isNull);

      b.mitschnitt.gibFrei();
      expect(await gelesen(b.container), isA<EssenLive>());
    });

    test('Serie gelesen, Einträge noch nicht → null', () async {
      final b = behaelter();
      await b.repo.buche(eintrag(tag: heute));

      b.mitschnitt.halte((sql) => _aufEintraege(sql) && !_entdoppelt(sql));
      b.container.listen(liveSollProvider, (_, _) {});
      await b.container.read(serieProvider.future).timeout(_frist);
      await pumpEventQueue();

      expect(
        b.container.read(serieProvider).hasValue,
        isTrue,
        reason: 'Vorbedingung: die Serie ist gelesen',
      );
      expect(b.container.read(liveSollProvider), isNull);

      b.mitschnitt.gibFrei();
      expect(await gelesen(b.container), isA<EssenLive>());
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  group('Buchen', () {
    test('Buchen plus neuLesen → Mahlzeit erledigt, kcal gerundet, Serie '
        'neu gelesen', () async {
      final b = behaelter();
      await b.repo.buche(eintrag(tag: vorgestern));
      await b.repo.buche(eintrag(tag: gestern, mahlzeit: Mahlzeit.snack));
      b.container.listen(liveSollProvider, (_, _) {});

      final vorher = karteAus(await gelesen(b.container));
      expect(
        vorher.serie,
        2,
        reason: 'heute leer bricht nicht, zählt nur nicht',
      );
      expect(vorher.serieAbMorgen, 0);
      expect(await b.container.read(serieProvider.future), (
        heute: 2,
        abMorgen: 0,
      ));

      await b.repo.buche(
        eintrag(tag: heute, mahlzeit: Mahlzeit.fruehstueck, kcal: 685.5),
      );
      await b.container
          .read(eigeneEintraegeProvider(heute).notifier)
          .neuLesen();

      final nachher = karteAus(await gelesen(b.container));
      final fruehstueck = ring(nachher, Mahlzeit.fruehstueck);
      expect(fruehstueck.eintrag, isTrue);
      expect(fruehstueck.kcal, 686);
      expect(nachher.ersteOffene, Mahlzeit.mittag);
      expect(await b.container.read(serieProvider.future), (
        heute: 3,
        abMorgen: 3,
      ), reason: 'die Serie hört auf eintraegeStandProvider und liest neu');
      expect(nachher.serie, 3);
      expect(nachher.serieAbMorgen, 3);
    });

    test('ein Eintrag ohne Kalorien ist erledigt, kcal bleibt null', () async {
      final b = behaelter();
      await b.repo.buche(
        eintrag(tag: heute, mahlzeit: Mahlzeit.abend, kcal: null),
      );
      b.container.listen(liveSollProvider, (_, _) {});

      final karte = karteAus(await gelesen(b.container));
      final abend = ring(karte, Mahlzeit.abend);
      expect(abend.eintrag, isTrue);
      expect(abend.kcal, isNull, reason: 'null wird nicht 0 (#232)');
    });

    test(
      'zwei Einträge einer Mahlzeit: kcal ist die gerundete Summe',
      () async {
        final b = behaelter();
        await b.repo.buche(eintrag(tag: heute, kcal: 300.2));
        await b.repo.buche(eintrag(tag: heute, kcal: 200.4));
        b.container.listen(liveSollProvider, (_, _) {});

        final karte = karteAus(await gelesen(b.container));
        expect(ring(karte, Mahlzeit.mittag).kcal, 501);
      },
    );

    test('ein Eintrag an einem anderen Tag ändert die Karte nicht, nur die '
        'Serie', () async {
      final b = behaelter();
      b.container.listen(liveSollProvider, (_, _) {});
      final vorher = karteAus(await gelesen(b.container));

      await b.repo.buche(eintrag(tag: gestern, mahlzeit: Mahlzeit.mittag));
      await b.container
          .read(eigeneEintraegeProvider(gestern).notifier)
          .neuLesen();

      final nachher = karteAus(await gelesen(b.container));
      expect(nachher.ringe, vorher.ringe);
      expect(nachher.serie, 1);
      expect(nachher.serieAbMorgen, 0);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  group('Der Esstag (V3)', () {
    test('um 02:00 Berlin ist es der Vortag, die Karte verfällt um 04:00 '
        'desselben Kalendertags', () async {
      // 15.01.2099, 02:00 Berlin = 01:00 UTC.
      final b = behaelter(jetzt: DateTime.utc(2099, 1, 15, 1));
      await b.repo.buche(
        eintrag(
          tag: gestern,
          mahlzeit: Mahlzeit.abend,
          zeitpunkt: DateTime.utc(2099, 1, 15, 0, 30),
        ),
      );
      b.container.listen(liveSollProvider, (_, _) {});

      expect(b.container.read(esstagProvider), gestern);

      final karte = karteAus(await gelesen(b.container));
      expect(karte.verfaelltUm, DateTime.utc(2099, 1, 15, 3));
      expect(
        ring(karte, Mahlzeit.abend).eintrag,
        isTrue,
        reason: 'die Karte zeigt den Esstag, nicht den Kalendertag',
      );
      expect(karte.serie, 1);
    });

    test('Uhr auf 04:00, pruefe() → neuer Esstag, neues Soll', () async {
      final b = behaelter(jetzt: DateTime.utc(2099, 1, 15, 1));
      await b.repo.buche(eintrag(tag: gestern, mahlzeit: Mahlzeit.fruehstueck));
      final tage = <String>[];
      b.container.listen(esstagProvider, (_, neu) => tage.add(neu));
      b.container.listen(liveSollProvider, (_, _) {});

      final alt = karteAus(await gelesen(b.container));
      expect(ring(alt, Mahlzeit.fruehstueck).eintrag, isTrue);

      // 03:59 Berlin: noch derselbe Esstag — pruefe() meldet nichts.
      b.stelleUhr(DateTime.utc(2099, 1, 15, 2, 59));
      await b.container.read(esstagProvider.notifier).pruefe();
      expect(b.container.read(esstagProvider), gestern);
      expect(tage, isEmpty, reason: 'pruefe setzt nur bei einer Änderung');

      // 04:00 Berlin: der neue Esstag.
      b.stelleUhr(DateTime.utc(2099, 1, 15, 3));
      await b.container.read(esstagProvider.notifier).pruefe();
      expect(b.container.read(esstagProvider), heute);
      expect(tage, [heute]);

      final neu = karteAus(await gelesen(b.container));
      expect(neu, isNot(alt));
      expect(neu.verfaelltUm, DateTime.utc(2099, 1, 16, 3));
      expect(
        ring(neu, Mahlzeit.fruehstueck).eintrag,
        isFalse,
        reason: 'der Eintrag gehört zum alten Esstag',
      );
      expect(neu.ersteOffene, Mahlzeit.fruehstueck);
      expect(await b.container.read(serieProvider.future), (
        heute: 1,
        abMorgen: 0,
      ), reason: 'die Serie rechnet auf den neuen Esstag');
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  group('Unverändert ist gleich (Review Focus 4)', () {
    test('zweimal lesen ohne Änderung → dasselbe Soll', () async {
      final b = behaelter();
      await b.repo.buche(eintrag(tag: heute, kcal: 512));
      b.container.listen(liveSollProvider, (_, _) {});

      final erstes = await gelesen(b.container);
      final zweites = await gelesen(b.container);
      expect(zweites, erstes);
      expect(zweites.hashCode, erstes.hashCode);
    });

    test('neuLesen ohne Änderung meldet kein neues Soll, auch kein null '
        'dazwischen', () async {
      final b = behaelter();
      await b.repo.buche(eintrag(tag: heute, kcal: 512));
      final werte = <LiveSoll?>[];
      b.container.listen(liveSollProvider, (_, neu) => werte.add(neu));

      final vorher = await gelesen(b.container);
      expect(vorher, isA<EssenLive>());
      werte.clear();

      await b.container
          .read(eigeneEintraegeProvider(heute).notifier)
          .neuLesen();
      final nachher = await gelesen(b.container);

      expect(nachher, vorher);
      expect(
        werte,
        isEmpty,
        reason: 'jede Meldung wird in Task 7 ein Aufruf an iOS',
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  group('LiveSteuerung (V6)', () {
    EssenKarte karte({int serie = 0}) => essenKarte(
      mahlzeiten: [
        for (final m in Mahlzeit.values)
          MahlzeitStand(mahlzeit: m, hatEintrag: false, kcal: null),
      ],
      serie: (heute: serie, abMorgen: serie),
      jetzt: mittags,
    );

    test('das erste EssenLive geht frisch, das zweite nicht', () async {
      final b = behaelter();
      b.container.listen(liveSteuerungProvider, (_, _) {});
      final s = b.container.read(liveSteuerungProvider.notifier);

      await s.nimm(EssenLive(karte(serie: 1)));
      await s.nimm(EssenLive(karte(serie: 2)));

      expect(b.anzeige.zeigeAufrufe, [
        (karte: karte(serie: 1), frisch: true),
        (karte: karte(serie: 2), frisch: false),
      ]);
      expect(b.anzeige.beendeAlleAufrufe, 0);
    });

    test('nach beiRueckkehr() geht das nächste wieder frisch', () async {
      final b = behaelter();
      b.container.listen(liveSollProvider, (_, _) {});
      b.container.listen(liveSteuerungProvider, (_, _) {});
      final aktuell = karteAus(await gelesen(b.container));
      final s = b.container.read(liveSteuerungProvider.notifier);

      await s.nimm(EssenLive(karte(serie: 1)));
      await s.nimm(EssenLive(karte(serie: 2)));
      await s.beiRueckkehr();

      expect(b.anzeige.zeigeAufrufe, hasLength(3));
      expect(b.anzeige.zeigeAufrufe.last, (
        karte: aktuell,
        frisch: true,
      ), reason: 'die Rückkehr zeigt das aktuelle Soll, frisch');

      await s.nimm(EssenLive(karte(serie: 3)));
      expect(b.anzeige.zeigeAufrufe.last, (
        karte: karte(serie: 3),
        frisch: false,
      ));
    });

    test('beiRueckkehr() ohne gelesenes Soll ruft nichts — das nächste '
        'Zeigen ist frisch', () async {
      final b = behaelter();
      b.container.listen(liveSteuerungProvider, (_, _) {});
      final s = b.container.read(liveSteuerungProvider.notifier);
      await s.nimm(EssenLive(karte(serie: 1)));

      b.mitschnitt.halte((sql) => _aufEintraege(sql));
      await s.beiRueckkehr();
      expect(b.anzeige.zeigeAufrufe, hasLength(1));
      expect(b.anzeige.beendeAlleAufrufe, 0);

      await s.nimm(EssenLive(karte(serie: 2)));
      expect(b.anzeige.zeigeAufrufe.last, (
        karte: karte(serie: 2),
        frisch: true,
      ));
    });

    test('KeineLive → beendeAlle, kein zeige', () async {
      final b = behaelter();
      b.container.listen(liveSteuerungProvider, (_, _) {});
      await b.container.read(liveSteuerungProvider.notifier).nimm(KeineLive());

      expect(b.anzeige.beendeAlleAufrufe, 1);
      expect(b.anzeige.zeigeAufrufe, isEmpty);
    });

    test('null → kein Aufruf', () async {
      final b = behaelter();
      b.container.listen(liveSteuerungProvider, (_, _) {});
      await b.container.read(liveSteuerungProvider.notifier).nimm(null);

      expect(b.anzeige.beendeAlleAufrufe, 0);
      expect(b.anzeige.zeigeAufrufe, isEmpty);
      expect(b.anzeige.nimmLinkAufrufe, 0);
    });

    test('null zählt nicht als Zeigen — das erste EssenLive danach ist '
        'frisch', () async {
      final b = behaelter();
      b.container.listen(liveSteuerungProvider, (_, _) {});
      final s = b.container.read(liveSteuerungProvider.notifier);
      await s.nimm(null);
      await s.nimm(EssenLive(karte()));

      expect(b.anzeige.zeigeAufrufe, [(karte: karte(), frisch: true)]);
    });

    test('holeLink() gibt das Ziel einmal ab', () async {
      final b = behaelter();
      b.container.listen(liveSteuerungProvider, (_, _) {});
      final s = b.container.read(liveSteuerungProvider.notifier);
      b.anzeige.link = LiveZiel.mahlzeitEintragen;

      expect(await s.holeLink(), LiveZiel.mahlzeitEintragen);
      expect(await s.holeLink(), isNull);
      expect(b.anzeige.zeigeAufrufe, isEmpty);
    });
  });
}

/// Hängt ein Lesen, scheitert der Fall nach fünf Sekunden mit einer
/// `TimeoutException`, statt die vollen 30 Sekunden zu warten.
const _frist = Duration(seconds: 5);

bool _aufEintraege(String sql) => sql.toLowerCase().contains('eintraege');

bool _entdoppelt(String sql) {
  final s = sql.toLowerCase();
  return s.contains('distinct') || s.contains('group by');
}

/// Schreibt jede `SELECT`-Abfrage samt Zeilenzahl mit und hält auf
/// Wunsch Abfragen zurück, bis [gibFrei] kommt.
class _Mitschnitt extends QueryInterceptor {
  final abfragen = <({String text, int zeilen})>[];

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
    final zeilen = await executor.runSelect(statement, args);
    abfragen.add((text: statement, zeilen: zeilen.length));
    return zeilen;
  }
}

/// Die Attrappe dieser Datei — sie implementiert das Protokoll aus der
/// Spec und merkt sich jeden Aufruf (siehe Dateikopf, warum nicht
/// `AttrappeLiveAnzeige`).
class _Anzeige implements LiveAnzeige {
  final zeigeAufrufe = <({EssenKarte karte, bool frisch})>[];
  var beendeAlleAufrufe = 0;
  var nimmLinkAufrufe = 0;
  LiveZiel? link;
  final _linkDa = StreamController<void>.broadcast();

  @override
  Future<LiveErgebnis> zeige(EssenKarte karte, {required bool frisch}) async {
    zeigeAufrufe.add((karte: karte, frisch: frisch));
    return LiveGestartet();
  }

  @override
  Future<void> beendeAlle() async => beendeAlleAufrufe++;

  @override
  Future<LiveZiel?> nimmLink() async {
    nimmLinkAufrufe++;
    final ziel = link;
    link = null;
    return ziel;
  }

  @override
  Stream<void> get linkDa => _linkDa.stream;
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
