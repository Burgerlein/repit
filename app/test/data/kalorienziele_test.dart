import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/data/kalorienziele.dart';
import 'package:repit/health/health_provider.dart';

/// Tests für die **Historie des festen Kalorienziels** (#410) — Werttyp,
/// Repository und Provider in `lib/data/kalorienziele.dart`.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden.
///
/// Die Tabelle selbst (Spalten, Stufe 19) prüft `schema_v19_test.dart`, die
/// Wirkung auf den Ernährungstag `ernaehrung/kalorienziel_fest_test.dart`.
///
/// ## Woher die Anforderung kommt
///
/// Ticket #410 (Tim, 07.11.2026: „Das Kalorienziel soll fest sein und sich
/// nicht täglich ändern — außer der Coach passt es an"). Die Ausgestaltung
/// ist eine **Vorgabe des Koordinators**, Tim hat die Rückfrage dazu
/// weggeklickt: einmal berechnen und speichern; der gespeicherte Wert gilt
/// ab dem Tag seines Festlegens; Ändern von Hand (später über den Coach),
/// jede Änderung ab ihrem Tag, frühere Tage behalten den alten Wert.
///
/// ## Festgelegte API — Entscheidung des Test-Agenten, nicht von Tim
///
/// Neue Datei `lib/data/kalorienziele.dart`:
///
/// ```dart
/// /// Woher ein festes Ziel stammt. In der Tabelle als `name` des Werts
/// /// (`'berechnet'`, `'hand'`); `coach` kommt mit dem Coach dazu.
/// enum KalorienzielHerkunft { berechnet, hand }
///
/// /// Ein festgelegtes Kalorienziel — gilt ab [abTag] bis zur nächsten
/// /// Festlegung. Werttyp mit == und hashCode über alle Felder.
/// @immutable
/// class KalorienzielFestlegung {
///   const KalorienzielFestlegung({
///     required String abTag,               // ISO-Tagesstring
///     required double kcal,
///     required KalorienzielHerkunft herkunft,
///     KalorienzielAnteile? anteile,        // nur bei `berechnet`
///   });
/// }
///
/// /// Die Festlegung, die an [tagesSchluessel] gilt: die mit dem
/// /// spätesten `abTag <= tagesSchluessel`. `null` vor der ersten.
/// /// Die Eingabe muss nicht sortiert sein.
/// KalorienzielFestlegung? geltendeFestlegung(
///   List<KalorienzielFestlegung> historie,
///   String tagesSchluessel,
/// );
///
/// class KalorienzielRepository {
///   KalorienzielRepository(AppCache db);
///   /// Alle Festlegungen, aufsteigend nach `abTag`.
///   Future<List<KalorienzielFestlegung>> alle();
///   /// Legt ab; eine Festlegung für einen Tag, der schon eine hat,
///   /// **ersetzt** sie.
///   Future<void> setze(KalorienzielFestlegung festlegung);
/// }
///
/// final kalorienzielRepositoryProvider = Provider<KalorienzielRepository>(…);
///
/// /// Die Historie, gehalten. Kein `Messwert` — Tims eigene Daten, leer
/// /// heißt leer.
/// final kalorienzieleProvider = AsyncNotifierProvider<
///     KalorienzieleNotifier, List<KalorienzielFestlegung>>(…);
///
/// class KalorienzieleNotifier
///     extends AsyncNotifier<List<KalorienzielFestlegung>> {
///   /// Ein Ziel von Hand, **ab heute** (Berliner Tag aus `clockProvider`).
///   Future<void> setzeVonHand(double kcal);
/// }
/// ```
///
/// ## Weitere Festlegungen des Test-Agenten — nicht von Tim freigegeben
///
/// - **Die Anteile kommen nur als ganze Gruppe zurück.** Gespeichert in
///   drei Spalten; gelesen wird `KalorienzielAnteile(…, gemessen: false)`,
///   wenn alle drei dastehen, sonst `null`. `gemessen` ist immer `false`:
///   Festgelegt wird mit der Formel für heute, und die nimmt nie den
///   gemessenen Verbrauch (#229).
/// - **Ein von Hand gesetztes Ziel trägt keine Anteile** — in der Tabelle
///   `NULL`, nicht `0`.
/// - **`setzeVonHand` nimmt den Berliner Tag**, nicht den UTC-Tag: Um 23:30
///   UTC ist in Berlin im Sommer schon morgen.
///
/// **Alle Zahlen und Daten hier sind erfunden.**
void main() {
  late AppCache db;

  setUp(() {
    db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);
  });

  const anteile = KalorienzielAnteile(
    grundumsatzKcal: 1750.5,
    aktivKcal: 700.2,
    koerperzielKcal: 166.55,
    gemessen: false,
  );

  final berechnet = KalorienzielFestlegung(
    abTag: '2026-07-10',
    kcal: anteile.summeKcal,
    herkunft: KalorienzielHerkunft.berechnet,
    anteile: anteile,
  );

  const vonHand = KalorienzielFestlegung(
    abTag: '2026-07-20',
    kcal: 2900,
    herkunft: KalorienzielHerkunft.hand,
  );

  Future<List<Map<String, Object?>>> rohzeilen() async => [
    for (final z
        in await db
            .customSelect('SELECT * FROM kalorienziele ORDER BY ab_tag;')
            .get())
      z.data,
  ];

  group('Der Werttyp', () {
    test('vergleicht über alle Felder', () {
      final gleich = KalorienzielFestlegung(
        abTag: '2026-07-10',
        kcal: anteile.summeKcal,
        herkunft: KalorienzielHerkunft.berechnet,
        anteile: anteile,
      );
      expect(gleich, berechnet);
      expect(gleich.hashCode, berechnet.hashCode);

      expect(
        const KalorienzielFestlegung(
          abTag: '2026-07-20',
          kcal: 2900,
          herkunft: KalorienzielHerkunft.berechnet,
        ),
        isNot(vonHand),
        reason:
            'dieselbe Zahl, andere Herkunft — die Herleitung zeigt etwas '
            'anderes, also ist es ein anderer Wert',
      );
      expect(
        const KalorienzielFestlegung(
          abTag: '2026-07-21',
          kcal: 2900,
          herkunft: KalorienzielHerkunft.hand,
        ),
        isNot(vonHand),
      );
    });
  });

  group('Welche Festlegung an einem Tag gilt', () {
    final historie = [vonHand, berechnet]; // absichtlich unsortiert

    test('vor der ersten gilt keine', () {
      expect(geltendeFestlegung(historie, '2026-07-09'), isNull);
      expect(geltendeFestlegung(const [], '2026-07-09'), isNull);
    });

    test('ab ihrem Tag gilt sie — der Tag selbst eingeschlossen', () {
      expect(geltendeFestlegung(historie, '2026-07-10'), berechnet);
      expect(geltendeFestlegung(historie, '2026-07-19'), berechnet);
    });

    test('eine spätere Änderung gilt ab ihrem Tag, frühere Tage behalten '
        'die alte', () {
      expect(geltendeFestlegung(historie, '2026-07-20'), vonHand);
      expect(geltendeFestlegung(historie, '2026-12-31'), vonHand);
      expect(geltendeFestlegung(historie, '2026-07-19'), berechnet);
    });

    test('über den Kalender, nicht über die Länge des Strings — auch über '
        'einen Jahreswechsel', () {
      const silvester = KalorienzielFestlegung(
        abTag: '2026-12-31',
        kcal: 2500,
        herkunft: KalorienzielHerkunft.hand,
      );
      expect(geltendeFestlegung([silvester], '2027-01-01'), silvester);
      expect(geltendeFestlegung([silvester], '2026-12-30'), isNull);
    });
  });

  group('Das Repository', () {
    test('eine leere Tabelle ist eine leere Historie', () async {
      expect(await KalorienzielRepository(db).alle(), isEmpty);
    });

    test('was abgelegt wird, kommt gleich zurück — samt Anteilen', () async {
      final repo = KalorienzielRepository(db);
      await repo.setze(berechnet);

      final zurueck = (await repo.alle()).single;
      expect(zurueck, berechnet);
      expect(zurueck.anteile, anteile);
      expect(
        zurueck.anteile!.gemessen,
        isFalse,
        reason: 'festgelegt wird mit der Formel für heute (#229)',
      );
    });

    test('die Herkunft steht als Wort in der Tabelle', () async {
      final repo = KalorienzielRepository(db);
      await repo.setze(berechnet);
      await repo.setze(vonHand);

      final zeilen = await rohzeilen();
      expect(zeilen.map((z) => z['herkunft']), ['berechnet', 'hand']);
      expect(zeilen.map((z) => z['ab_tag']), ['2026-07-10', '2026-07-20']);
    });

    test(
      'ein von Hand gesetztes Ziel hat keine Anteile — NULL, nicht 0',
      () async {
        final repo = KalorienzielRepository(db);
        await repo.setze(vonHand);

        final zeile = (await rohzeilen()).single;
        expect(zeile['grundumsatz_kcal'], isNull);
        expect(zeile['aktiv_kcal'], isNull);
        expect(zeile['koerperziel_kcal'], isNull);
        expect((await repo.alle()).single.anteile, isNull);
      },
    );

    test(
      'aufsteigend nach Tag, egal in welcher Reihenfolge abgelegt',
      () async {
        final repo = KalorienzielRepository(db);
        await repo.setze(vonHand);
        await repo.setze(berechnet);
        await repo.setze(
          const KalorienzielFestlegung(
            abTag: '2026-07-15',
            kcal: 2700,
            herkunft: KalorienzielHerkunft.hand,
          ),
        );

        expect((await repo.alle()).map((f) => f.abTag), [
          '2026-07-10',
          '2026-07-15',
          '2026-07-20',
        ]);
      },
    );

    test('eine zweite Festlegung für denselben Tag ersetzt die erste — '
        'je Tag gilt höchstens ein Ziel', () async {
      final repo = KalorienzielRepository(db);
      await repo.setze(berechnet);
      const ersatz = KalorienzielFestlegung(
        abTag: '2026-07-10',
        kcal: 2650,
        herkunft: KalorienzielHerkunft.hand,
      );
      await repo.setze(ersatz);

      expect(await repo.alle(), [ersatz]);
      expect(
        (await rohzeilen()).single['grundumsatz_kcal'],
        isNull,
        reason:
            'die Anteile der ersetzten Berechnung gehören nicht zu einem '
            'Ziel von Hand — sie bleiben nicht stehen',
      );
    });

    test('eine spätere Festlegung lässt die frühere stehen — das ist die '
        'Historie', () async {
      final repo = KalorienzielRepository(db);
      await repo.setze(berechnet);
      await repo.setze(vonHand);

      expect(await repo.alle(), [berechnet, vonHand]);
    });

    test('über drift: Companion und Datenklasse tragen die Spaltennamen der '
        'Stufe 19', () async {
      await db
          .into(db.kalorienziele)
          .insert(
            const KalorienzieleCompanion(
              abTag: Value('2026-07-12'),
              kcal: Value(2600.5),
              herkunft: Value('hand'),
            ),
          );
      final KalorienzielRow zeile =
          (await db.select(db.kalorienziele).get()).single;
      expect(zeile.abTag, '2026-07-12');
      expect(zeile.kcal, 2600.5);
      expect(zeile.herkunft, 'hand');
      expect(zeile.grundumsatzKcal, isNull);
      expect(zeile.aktivKcal, isNull);
      expect(zeile.koerperzielKcal, isNull);
    });
  });

  group('Der Provider', () {
    ProviderContainer behaelter(DateTime jetzt) {
      final container = ProviderContainer(
        // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
        retry: (_, _) => null,
        overrides: [
          appCacheProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(() => jetzt),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('liest die Historie aus der Tabelle', () async {
      await KalorienzielRepository(db).setze(berechnet);
      final c = behaelter(DateTime.utc(2026, 7, 14, 10));

      expect(await c.read(kalorienzieleProvider.future), [berechnet]);
    });

    test('ohne Festlegung: leer, kein Fehler', () async {
      final c = behaelter(DateTime.utc(2026, 7, 14, 10));
      expect(await c.read(kalorienzieleProvider.future), isEmpty);
    });

    test('setzeVonHand legt ein Ziel ab heute ab und lässt die früheren '
        'stehen', () async {
      await KalorienzielRepository(db).setze(berechnet);
      final c = behaelter(DateTime.utc(2026, 7, 14, 10)); // 12:00 Berlin
      await c.read(kalorienzieleProvider.future);

      await c.read(kalorienzieleProvider.notifier).setzeVonHand(3100);

      const erwartet = KalorienzielFestlegung(
        abTag: '2026-07-14',
        kcal: 3100,
        herkunft: KalorienzielHerkunft.hand,
      );
      expect(await KalorienzielRepository(db).alle(), [berechnet, erwartet]);
      expect(c.read(kalorienzieleProvider).value, [
        berechnet,
        erwartet,
      ], reason: 'der Provider steht ohne Neustart auf dem neuen Stand');
    });

    test('setzeVonHand nimmt den Berliner Tag, nicht den UTC-Tag', () async {
      // 23:30 UTC am 14.07. ist in Berlin (MESZ) schon 01:30 am 15.07.
      final c = behaelter(DateTime.utc(2026, 7, 14, 23, 30));
      await c.read(kalorienzieleProvider.future);

      await c.read(kalorienzieleProvider.notifier).setzeVonHand(2800);

      expect(
        (await KalorienzielRepository(db).alle()).single.abTag,
        '2026-07-15',
      );
    });

    test('zweimal am selben Tag von Hand: die zweite Zahl gilt, ein '
        'Eintrag', () async {
      final c = behaelter(DateTime.utc(2026, 7, 14, 10));
      await c.read(kalorienzieleProvider.future);
      final notifier = c.read(kalorienzieleProvider.notifier);

      await notifier.setzeVonHand(2800);
      await notifier.setzeVonHand(2750);

      expect(await KalorienzielRepository(db).alle(), const [
        KalorienzielFestlegung(
          abTag: '2026-07-14',
          kcal: 2750,
          herkunft: KalorienzielHerkunft.hand,
        ),
      ]);
    });
  });
}
