import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show sqlite3;

import 'package:repit/data/cache.dart';
import 'package:repit/data/ernaehrung_repository.dart'
    show HealthStand;
import 'package:repit/data/wasser_repository.dart';

/// Tests für das **Wasser-Repository** (#311) — Eintragen, Ändern, Löschen
/// und der Health-Stand eines eingetragenen Glases.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden. Die Tabelle
/// selbst und ihre Migration prüft `schema_v16_test.dart`; warum Wasser eine
/// eigene Tabelle bekommt, steht dort im Kopf.
///
/// ## Festgelegte API — Entscheidung des Test-Agenten, nicht von Tim
///
/// Neue Datei `lib/data/wasser_repository.dart`, derselbe Schnitt wie
/// `ErnaehrungRepository` (SQL hier, Riverpod nebenan):
///
/// ```dart
/// /// Ein eingetragenes Glas Wasser. Werttyp mit == und hashCode über alle
/// /// Felder.
/// class WasserEintrag {
///   const WasserEintrag({
///     this.id,
///     required this.tagesSchluessel,   // ISO-Tag, vom offenen Tag
///     required this.zeitpunkt,         // UTC
///     required this.mengeMl,
///     this.healthUuid,
///     this.healthStand = HealthStand.offen,
///   });
/// }
///
/// class WasserRepository {
///   WasserRepository(AppCache db);
///
///   /// Die Einträge eines Tages, nach Zeitpunkt aufsteigend — in SQL
///   /// gefiltert. Leerer Tag: leere Liste.
///   Future<List<WasserEintrag>> wasserAmTag(String tagesSchluessel);
///
///   /// Legt an und gibt die neue ID zurück; eine mitgegebene ID wird nicht
///   /// übernommen.
///   Future<int> trageEin(WasserEintrag eintrag);
///
///   /// Schreibt einen bestehenden Eintrag neu (alle Felder). Wirft
///   /// `ArgumentError`, wenn `id` null ist.
///   Future<void> aendere(WasserEintrag eintrag);
///
///   /// Nimmt genau eine Zeile weg; eine unbekannte ID ändert nichts.
///   Future<void> loesche(int id);
///
///   /// Stand und Kennung einer Zeile zusammen — wie
///   /// `ErnaehrungRepository.setzeHealthKopie`.
///   Future<void> setzeHealthKopie(int id,
///       {required String? healthUuid, required HealthStand stand});
///
///   /// Alles mit Stand `offen`, über alle Tage, das Älteste zuerst.
///   Future<List<WasserEintrag>> offeneHealthEintraege();
/// }
///
/// final wasserRepositoryProvider = Provider<WasserRepository>(…);
/// ```
///
/// [HealthStand] ist **derselbe** Typ wie bei den Mahlzeiten
/// (`ernaehrung_repository.dart`) — ein zweiter Enum für dieselben drei
/// Wörter wäre eine zweite Stelle, die auseinanderlaufen kann.
///
/// Alle Zahlen und Zeitpunkte erfunden, im Jahr 2099.
void main() {
  const tagA = '2099-03-01';
  const tagB = '2099-03-02';

  WasserEintrag glas({
    String tag = tagA,
    DateTime? zeitpunkt,
    double mengeMl = 250,
  }) => WasserEintrag(
    tagesSchluessel: tag,
    zeitpunkt: zeitpunkt ?? DateTime.parse('${tag}T09:00:00Z'),
    mengeMl: mengeMl,
  );

  ({AppCache db, WasserRepository repo}) frisch() {
    final db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);
    return (db: db, repo: WasserRepository(db));
  }

  group('Eintragen und lesen', () {
    test('ein Tag ohne Wasser ist eine leere Liste', () async {
      final h = frisch();
      expect(await h.repo.wasserAmTag(tagA), isEmpty);
    });

    test('was eingetragen wird, kommt genau so zurück', () async {
      final h = frisch();
      final zeitpunkt = DateTime.utc(2099, 3, 1, 13, 40, 12);
      final id = await h.repo.trageEin(
        glas(zeitpunkt: zeitpunkt, mengeMl: 333.5),
      );

      final gelesen = await h.repo.wasserAmTag(tagA);
      expect(gelesen, hasLength(1));
      final e = gelesen.single;
      expect(e.id, id);
      expect(e.tagesSchluessel, tagA);
      expect(e.zeitpunkt, zeitpunkt);
      expect(e.zeitpunkt.isUtc, isTrue);
      expect(e.mengeMl, 333.5, reason: 'kein Runden — 333,5 ml sind Tims Wert');
      expect(e.healthUuid, isNull);
      expect(e.healthStand, HealthStand.offen);
    });

    test('eine mitgegebene ID wird nicht übernommen', () async {
      final h = frisch();
      final erste = await h.repo.trageEin(glas());
      final zweite = await h.repo.trageEin(
        WasserEintrag(
          id: erste,
          tagesSchluessel: tagA,
          zeitpunkt: DateTime.utc(2099, 3, 1, 10),
          mengeMl: 500,
        ),
      );
      expect(zweite, isNot(erste));
      expect(await h.repo.wasserAmTag(tagA), hasLength(2));
    });

    test('nur der verlangte Tag, nach Zeitpunkt aufsteigend', () async {
      final h = frisch();
      await h.repo.trageEin(
        glas(zeitpunkt: DateTime.utc(2099, 3, 1, 15), mengeMl: 300),
      );
      await h.repo.trageEin(glas(tag: tagB, mengeMl: 999));
      await h.repo.trageEin(
        glas(zeitpunkt: DateTime.utc(2099, 3, 1, 7), mengeMl: 200),
      );

      final a = await h.repo.wasserAmTag(tagA);
      expect(a.map((e) => e.mengeMl), [200, 300]);
      expect((await h.repo.wasserAmTag(tagB)).single.mengeMl, 999);
    });

    test('der Tag ist der eingetragene Tag, nicht der Kalendertag des '
        'Zeitpunkts', () async {
      // Wer über ‹ gestern offen hat und ein Glas einträgt, meint gestern.
      final h = frisch();
      await h.repo.trageEin(
        glas(tag: tagA, zeitpunkt: DateTime.utc(2099, 3, 2, 12)),
      );
      expect(await h.repo.wasserAmTag(tagA), hasLength(1));
      expect(await h.repo.wasserAmTag(tagB), isEmpty);
    });

    test('überlebt einen Neustart', () async {
      final roh = sqlite3.openInMemory();
      addTearDown(roh.close);

      final erstes = AppCache(
        NativeDatabase.opened(roh, closeUnderlyingOnClose: false),
      );
      await WasserRepository(erstes).trageEin(glas(mengeMl: 500));
      await erstes.close();

      final zweites = AppCache(
        NativeDatabase.opened(roh, closeUnderlyingOnClose: false),
      );
      addTearDown(zweites.close);
      final gelesen = await WasserRepository(zweites).wasserAmTag(tagA);
      expect(gelesen.single.mengeMl, 500);
    });

    test('Wasser landet nicht bei den Mahlzeiten', () async {
      final h = frisch();
      await h.repo.trageEin(glas());
      expect(
        await ErnaehrungRepositoryProbe(h.db).eintraegeAmTag(tagA),
        isEmpty,
        reason:
            'ein Glas Wasser ist keine Mahlzeit (Kopf von '
            'schema_v16_test.dart)',
      );
    });
  });

  group('Ändern', () {
    test('ändert die Menge genau dieser Zeile', () async {
      final h = frisch();
      final id = await h.repo.trageEin(glas(mengeMl: 250));
      await h.repo.trageEin(glas(mengeMl: 500));

      final alt = (await h.repo.wasserAmTag(tagA))
          .firstWhere((e) => e.id == id);
      await h.repo.aendere(
        WasserEintrag(
          id: alt.id,
          tagesSchluessel: alt.tagesSchluessel,
          zeitpunkt: alt.zeitpunkt,
          mengeMl: 400,
          healthUuid: alt.healthUuid,
          healthStand: alt.healthStand,
        ),
      );

      final danach = await h.repo.wasserAmTag(tagA);
      expect(danach, hasLength(2), reason: 'Ändern ist kein zweites Eintragen');
      expect(danach.map((e) => e.mengeMl).toSet(), {400, 500});
    });

    test('ohne ID ist Ändern ein Programmierfehler', () async {
      final h = frisch();
      expect(() => h.repo.aendere(glas()), throwsArgumentError);
    });
  });

  group('Löschen', () {
    test('nimmt genau eine Zeile weg', () async {
      final h = frisch();
      final id = await h.repo.trageEin(glas(mengeMl: 250));
      await h.repo.trageEin(glas(mengeMl: 500));
      await h.repo.trageEin(glas(tag: tagB));

      await h.repo.loesche(id);

      expect((await h.repo.wasserAmTag(tagA)).single.mengeMl, 500);
      expect(await h.repo.wasserAmTag(tagB), hasLength(1));
    });

    test('eine unbekannte ID ändert nichts', () async {
      final h = frisch();
      await h.repo.trageEin(glas());
      await h.repo.loesche(4711);
      expect(await h.repo.wasserAmTag(tagA), hasLength(1));
    });

    test('eine gelöschte ID wird nicht neu vergeben', () async {
      final h = frisch();
      final erste = await h.repo.trageEin(glas());
      await h.repo.loesche(erste);
      final zweite = await h.repo.trageEin(glas());
      expect(
        zweite,
        isNot(erste),
        reason:
            'der Health-Nachlauf merkt sich IDs — eine wiederverwendete '
            'setzte den Stand eines fremden Eintrags',
      );
    });
  });

  group('Health-Stand', () {
    test('setzeHealthKopie schreibt Stand und Kennung einer Zeile', () async {
      final h = frisch();
      final a = await h.repo.trageEin(glas(mengeMl: 250));
      final b = await h.repo.trageEin(glas(mengeMl: 500));

      await h.repo.setzeHealthKopie(
        a,
        healthUuid: 'C0FFEE00-0000-0000-0000-000000000001',
        stand: HealthStand.geschrieben,
      );

      final nachId = {for (final e in await h.repo.wasserAmTag(tagA)) e.id: e};
      expect(nachId[a]!.healthStand, HealthStand.geschrieben);
      expect(nachId[a]!.healthUuid, 'C0FFEE00-0000-0000-0000-000000000001');
      expect(nachId[b]!.healthStand, HealthStand.offen);
      expect(nachId[b]!.healthUuid, isNull);

      await h.repo.setzeHealthKopie(
        a,
        healthUuid: null,
        stand: HealthStand.nichtMoeglich,
      );
      final wieder = (await h.repo.wasserAmTag(tagA))
          .firstWhere((e) => e.id == a);
      expect(wieder.healthUuid, isNull);
      expect(wieder.healthStand, HealthStand.nichtMoeglich);
    });

    test('offene Einträge über alle Tage, das Älteste zuerst — ohne '
        'geschriebene und abgelehnte', () async {
      final h = frisch();
      final spaet = await h.repo.trageEin(glas(tag: tagB));
      final frueh = await h.repo.trageEin(glas(tag: tagA));
      final geschrieben = await h.repo.trageEin(glas(tag: tagA));
      final abgelehnt = await h.repo.trageEin(glas(tag: tagA));
      await h.repo.setzeHealthKopie(
        geschrieben,
        healthUuid: 'C0FFEE00-0000-0000-0000-000000000002',
        stand: HealthStand.geschrieben,
      );
      await h.repo.setzeHealthKopie(
        abgelehnt,
        healthUuid: null,
        stand: HealthStand.nichtMoeglich,
      );

      final offen = await h.repo.offeneHealthEintraege();
      expect(offen.map((e) => e.id), [frueh, spaet]);
    });

    test('die drei Stände liegen als dieselben Wörter wie bei den '
        'Mahlzeiten in der Datei', () async {
      final h = frisch();
      final a = await h.repo.trageEin(glas());
      await h.repo.setzeHealthKopie(
        a,
        healthUuid: null,
        stand: HealthStand.nichtMoeglich,
      );
      final zeile = await h.db
          .customSelect('SELECT health_stand FROM wasser_eintraege;')
          .getSingle();
      expect(zeile.read<String>('health_stand'), 'nicht_moeglich');
    });
  });

  group('Wertgleichheit', () {
    test('zwei gleich gelesene Einträge sind gleich', () async {
      final h = frisch();
      await h.repo.trageEin(glas());
      final a = await h.repo.wasserAmTag(tagA);
      final b = await h.repo.wasserAmTag(tagA);
      expect(a.single, b.single);
      expect(a.single.hashCode, b.single.hashCode);
    });
  });
}

/// Liest die Mahlzeiten eines Tages roh aus `eintraege` — ohne die API von
/// `ErnaehrungRepository` an diese Datei zu binden.
class ErnaehrungRepositoryProbe {
  ErnaehrungRepositoryProbe(this._db);
  final AppCache _db;

  Future<List<Map<String, Object?>>> eintraegeAmTag(String tag) async => [
    for (final z
        in await _db
            .customSelect(
              'SELECT * FROM eintraege WHERE tages_schluessel = ?;',
              variables: [Variable.withString(tag)],
            )
            .get())
      z.data,
  ];
}
