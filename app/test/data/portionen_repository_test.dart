// `drift` exportiert eigene `isNull` und `isNotNull` — dieselbe Begründung
// wie in `test/data/ernaehrung_repository_test.dart`, Zeile 1–5.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException;
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/data/lebensmittel_repository.dart';
import 'package:repit/data/portion.dart';
import 'package:repit/data/portionen_repository.dart';
import 'package:repit/health/health_provider.dart';

/// Tests für **Portionen im Repository** — anlegen, ändern, löschen,
/// übernehmen und einmal nachfragen (#396, unter #325).
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden.
///
/// Geschrieben nach Task 4 des Plans
/// `docs/superpowers/plans/2026-11-05-portionen.md` und der Spec
/// `docs/superpowers/specs/2026-11-05-portionen-design.md` („Die
/// Datenschicht", „Übernahme", „Abruf beim Antippen", V3–V5) — **ohne** den
/// Code von `portionen_repository.dart` gesehen zu haben (es gab ihn beim
/// Schreiben noch nicht). `lebensmittel_repository_test.dart` und
/// `lebensmittel_herkunft_test.dart` bleiben, wie sie sind, und müssen
/// weiter grün laufen.
///
/// ## Was diese Tests verbindlich vorgeben (aus dem Plan)
///
/// ```dart
/// class LebensmittelVorlage {
///   …
///   final DateTime? portionenAbgefragtAm;   // in == und hashCode
/// }
///
/// class PortionenRepository {
///   PortionenRepository(AppCache db);
///   Future<List<Portion>> fuer(int lebensmittelId);
///   Future<int> legeAn(int lebensmittelId, Portion portion);
///   Future<void> aendere(Portion portion);  // ArgumentError ohne id
///   Future<void> loesche(int id);
/// }
/// final portionenRepositoryProvider = Provider<PortionenRepository>(…);
///
/// class LebensmittelRepository {
///   Future<int> legeAn(LebensmittelVorlage vorlage,
///       {List<Portion> portionen = const []});
///   Future<int> uebernimm(LebensmittelVorlage vorlage, {DateTime? jetzt});
///   Future<bool> trageOffPortionenNach(int id,
///       {required List<Portion> portionen,
///        required bool fluessig,
///        required DateTime jetzt});
/// }
/// ```
///
/// - **`fuer`** liest nur Zeilen dieses Lebensmittels mit `menge_g > 0`,
///   sortiert nach `menge_g`, bei Gleichstand nach `id` — in SQL.
/// - **`aendere`** schreibt Name und Menge. Die Herkunft bleibt.
/// - **`legeAn`**, **`uebernimm`** und **`trageOffPortionenNach`** schreiben
///   Lebensmittel und Portionen je in **einer** Transaktion (Review
///   Focus 6). Geprüft über einen Trigger, der das Anlegen einer Portion
///   namens „Kaputt" abbricht.
/// - **`portionenAbgefragtAm`**: `uebernimm` setzt es auf `jetzt`, sobald
///   `offPortionen != null` — auch bei `[]` („gefragt, keine"). Bei `null`
///   („nicht abgefragt") bleibt es `null`. Ein schon vorhandener Strichcode
///   wird nicht angefasst, auch nicht seine Portionen und nicht seine
///   Marke.
/// - **`trageOffPortionenNach`** ist die einmalige Nachfrage
///   (Entscheidung 6, V5): Ist die Marke schon gesetzt, tut sie nichts und
///   antwortet `false`. `fluessig` geht nur von `false` auf `true`.
/// - **`offPortionen` ist aus der Tabelle gelesen immer `null`.** Es gehört
///   nur zu einem noch nicht übernommenen OFF-Produkt.
///
/// ## Festlegungen des Test-Agenten — nicht von Tim freigegeben
///
/// - **`uebernimm` behält die Herkunft jeder Portion, wie sie kommt.** Der
///   Plan sagt für Portion und Packung aus OFF „Herkunft `off`" — das
///   tragen die Portionen aus `OffProdukt` schon. V3 lässt aber auch im
///   Blatt angelegte Portionen eines noch nicht übernommenen Treffers mit
///   der Übernahme in die Tabelle gehen; eine eigene Portion „Bon" wäre
///   dann fälschlich als OFF markiert, wenn `uebernimm` die Herkunft
///   überschriebe. Geprüft im Fall „eine im Blatt angelegte Portion bleibt
///   eigen".
/// - **`aendere` mit einer `Portion`, deren Herkunft `eigen` lautet,
///   macht aus einer OFF-Portion keine eigene.** „Die Herkunft bleibt"
///   heißt hier: Die Spalte wird nicht geschrieben, egal was im Werttyp
///   steht.
/// - **Die Transaktionsprobe** gilt nicht nur für `legeAn` (Pflichtfall
///   des Plans), sondern auch für `uebernimm` und `trageOffPortionenNach`
///   — beide sind im Plan als „in einer Transaktion" beschrieben.
/// - **Der Abbruch kommt als `SqliteException` heraus**, so wie SQLite ihn
///   wirft. Ein Repository, das ihn verschluckte, meldete Erfolg für etwas,
///   das nicht gespeichert ist.
///
/// Alle Produkte, Namen, Zahlen und Strichcodes hier sind **erfunden**,
/// alle Zeitpunkte liegen im Jahr 2099.
void main() {
  final jetzt = DateTime.utc(2099, 4, 7, 9, 30);
  final spaeter = DateTime.utc(2099, 4, 9, 18, 15);

  const barcodeBons = '0000000000031';
  const barcodeSaft = '0000000000048';

  const bonsJe100g = Naehrwerte.je100g(
    kcal: 555,
    eiweissG: 7.7,
    kohlenhydrateG: 51.1,
    fettG: 33.3,
  );

  // --- Hilfsmittel ---------------------------------------------------

  ({
    AppCache db,
    LebensmittelRepository lebensmittel,
    PortionenRepository portionen,
  })
  aufbau() {
    final db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);
    return (
      db: db,
      lebensmittel: LebensmittelRepository(db),
      portionen: PortionenRepository(db),
    );
  }

  /// Ein Online-Treffer bzw. gescanntes Produkt, wie es aus
  /// `OffProdukt.alsVorlage()` kommt: ohne Schlüssel, Herkunft `off`.
  LebensmittelVorlage offVorlage({
    String barcode = barcodeBons,
    String name = 'Prüf-Bons',
    List<Portion>? offPortionen,
    bool fluessig = false,
  }) => LebensmittelVorlage(
    name: name,
    je100g: bonsJe100g,
    barcode: barcode,
    herkunft: Herkunft.off,
    fluessig: fluessig,
    offPortionen: offPortionen,
  );

  const offPortion = Portion(
    name: 'Portion',
    mengeG: 5.8,
    herkunft: Herkunft.off,
  );
  const offPackung = Portion(
    name: 'Packung',
    mengeG: 225,
    herkunft: Herkunft.off,
  );

  /// Eine Zeile roh in `portionen` — ohne das Repository, damit die
  /// Leseprüfungen nicht vom Schreibweg abhängen.
  Future<int> rohPortion(
    AppCache db, {
    required int? lebensmittelId,
    String name = 'Roh',
    required double? mengeG,
    String herkunft = 'eigen',
  }) => db.customInsert(
    'INSERT INTO portionen (lebensmittel_id, name, menge_g, herkunft) '
    'VALUES (?, ?, ?, ?);',
    variables: [
      Variable<int>(lebensmittelId),
      Variable<String>(name),
      Variable<double>(mengeG),
      Variable<String>(herkunft),
    ],
  );

  /// Was in `portionen` zu einem Lebensmittel steht, roh aus der Datei und
  /// in der Reihenfolge des Anlegens.
  Future<List<({String name, double? mengeG, String herkunft})>> rohPortionen(
    AppCache db,
    int lebensmittelId,
  ) async {
    final zeilen = await db
        .customSelect(
          'SELECT name, menge_g, herkunft FROM portionen '
          'WHERE lebensmittel_id = ? ORDER BY id;',
          variables: [Variable<int>(lebensmittelId)],
        )
        .get();
    return [
      for (final z in zeilen)
        (
          name: z.read<String>('name'),
          mengeG: z.read<double?>('menge_g'),
          herkunft: z.read<String>('herkunft'),
        ),
    ];
  }

  Future<int> anzahl(AppCache db, String tabelle) async {
    final zeile = await db
        .customSelect('SELECT COUNT(*) AS n FROM $tabelle;')
        .getSingle();
    return zeile.read<int>('n');
  }

  /// Bricht jedes Anlegen einer Portion namens „Kaputt" ab — die Ausnahme
  /// mitten in einer Transaktion, die der Plan verlangt.
  Future<void> kaputtTrigger(AppCache db) => db.customStatement(
    'CREATE TRIGGER portion_kaputt BEFORE INSERT ON portionen '
    "WHEN NEW.name = 'Kaputt' "
    "BEGIN SELECT RAISE(ABORT, 'erzwungen im Test'); END;",
  );

  // ═════════════════════════════════════════════════════════════════════
  group('LebensmittelVorlage.portionenAbgefragtAm', () {
    test('ohne Angabe null', () {
      const v = LebensmittelVorlage(name: 'Prüfbrot', je100g: bonsJe100g);
      expect(v.portionenAbgefragtAm, isNull);
    });

    test('gehört zu == und hashCode', () {
      final a = LebensmittelVorlage(
        name: 'Prüfbrot',
        je100g: bonsJe100g,
        portionenAbgefragtAm: jetzt,
      );
      final b = LebensmittelVorlage(
        name: 'Prüfbrot',
        je100g: bonsJe100g,
        portionenAbgefragtAm: jetzt,
      );
      final andererZeitpunkt = LebensmittelVorlage(
        name: 'Prüfbrot',
        je100g: bonsJe100g,
        portionenAbgefragtAm: spaeter,
      );
      const ohne = LebensmittelVorlage(name: 'Prüfbrot', je100g: bonsJe100g);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(andererZeitpunkt));
      expect(a, isNot(ohne));
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('PortionenRepository.fuer', () {
    test(
      'sortiert nach Menge aufsteigend: 225 / 5,8 / 60 → 5,8 / 60 / 225',
      () async {
        final h = aufbau();
        final id = await h.lebensmittel.legeAn(
          const LebensmittelVorlage(name: 'Prüf-Bons', je100g: bonsJe100g),
        );

        final packung = await rohPortion(
          h.db,
          lebensmittelId: id,
          name: 'Packung',
          mengeG: 225,
          herkunft: 'off',
        );
        final portion = await rohPortion(
          h.db,
          lebensmittelId: id,
          name: 'Portion',
          mengeG: 5.8,
          herkunft: 'off',
        );
        final schale = await rohPortion(
          h.db,
          lebensmittelId: id,
          name: 'Schale',
          mengeG: 60,
        );

        expect(await h.portionen.fuer(id), [
          Portion(
            id: portion,
            name: 'Portion',
            mengeG: 5.8,
            herkunft: Herkunft.off,
          ),
          Portion(id: schale, name: 'Schale', mengeG: 60),
          Portion(
            id: packung,
            name: 'Packung',
            mengeG: 225,
            herkunft: Herkunft.off,
          ),
        ]);
      },
    );

    test('bei gleicher Menge entscheidet die id', () async {
      final h = aufbau();
      final id = await h.lebensmittel.legeAn(
        const LebensmittelVorlage(name: 'Prüf-Bons', je100g: bonsJe100g),
      );
      final erste = await rohPortion(
        h.db,
        lebensmittelId: id,
        name: 'Zweite Sorte',
        mengeG: 30,
      );
      final zweite = await rohPortion(
        h.db,
        lebensmittelId: id,
        name: 'Erste Sorte',
        mengeG: 30,
      );

      final gelesen = await h.portionen.fuer(id);
      expect(gelesen.map((p) => p.id), [erste, zweite]);
    });

    test('Zeilen mit menge_g 0, NULL, negativ oder ohne lebensmittel_id '
        'erscheinen nicht', () async {
      final h = aufbau();
      final id = await h.lebensmittel.legeAn(
        const LebensmittelVorlage(name: 'Prüf-Bons', je100g: bonsJe100g),
      );
      await rohPortion(h.db, lebensmittelId: id, name: 'Null', mengeG: 0);
      await rohPortion(h.db, lebensmittelId: id, name: 'Leer', mengeG: null);
      await rohPortion(h.db, lebensmittelId: id, name: 'Minus', mengeG: -5);
      await rohPortion(h.db, lebensmittelId: null, name: 'Waise', mengeG: 12);
      final echt = await rohPortion(
        h.db,
        lebensmittelId: id,
        name: 'Bon',
        mengeG: 5.9,
      );

      expect(await h.portionen.fuer(id), [
        Portion(id: echt, name: 'Bon', mengeG: 5.9),
      ]);
    });

    test('Portionen eines anderen Lebensmittels erscheinen nicht', () async {
      final h = aufbau();
      final bons = await h.lebensmittel.legeAn(
        const LebensmittelVorlage(name: 'Prüf-Bons', je100g: bonsJe100g),
      );
      final saft = await h.lebensmittel.legeAn(
        const LebensmittelVorlage(
          name: 'Prüfsaft',
          je100g: bonsJe100g,
          fluessig: true,
        ),
      );
      await rohPortion(h.db, lebensmittelId: saft, name: 'Glas', mengeG: 200);
      final bon = await rohPortion(
        h.db,
        lebensmittelId: bons,
        name: 'Bon',
        mengeG: 5.9,
      );

      expect(await h.portionen.fuer(bons), [
        Portion(id: bon, name: 'Bon', mengeG: 5.9),
      ]);
    });

    test('ohne Portion eine leere Liste', () async {
      final h = aufbau();
      final id = await h.lebensmittel.legeAn(
        const LebensmittelVorlage(name: 'Prüf-Bons', je100g: bonsJe100g),
      );
      expect(await h.portionen.fuer(id), isEmpty);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('PortionenRepository: anlegen, ändern, löschen', () {
    test('legeAn gibt den Schlüssel zurück, fuer liest die Portion samt '
        'Herkunft', () async {
      final h = aufbau();
      final id = await h.lebensmittel.legeAn(
        const LebensmittelVorlage(name: 'Prüf-Bons', je100g: bonsJe100g),
      );

      final bon = await h.portionen.legeAn(
        id,
        const Portion(name: 'Bon', mengeG: 5.9),
      );
      final packung = await h.portionen.legeAn(id, offPackung);

      expect(await h.portionen.fuer(id), [
        Portion(id: bon, name: 'Bon', mengeG: 5.9),
        Portion(
          id: packung,
          name: 'Packung',
          mengeG: 225,
          herkunft: Herkunft.off,
        ),
      ]);
      expect(await rohPortionen(h.db, id), [
        (name: 'Bon', mengeG: 5.9, herkunft: 'eigen'),
        (name: 'Packung', mengeG: 225.0, herkunft: 'off'),
      ]);
    });

    test('aendere ändert Name und Menge, die Herkunft off bleibt', () async {
      final h = aufbau();
      final id = await h.lebensmittel.legeAn(
        const LebensmittelVorlage(name: 'Prüf-Bons', je100g: bonsJe100g),
      );
      final pid = await rohPortion(
        h.db,
        lebensmittelId: id,
        name: 'Portion',
        mengeG: 5.8,
        herkunft: 'off',
      );

      // Herkunft im Werttyp absichtlich `eigen` (Vorgabe): Sie darf die
      // Spalte nicht überschreiben (Dateikopf, Festlegung 2).
      await h.portionen.aendere(Portion(id: pid, name: 'Bon', mengeG: 6.1));

      expect(await h.portionen.fuer(id), [
        Portion(id: pid, name: 'Bon', mengeG: 6.1, herkunft: Herkunft.off),
      ]);
    });

    test('aendere fasst nur diese eine Zeile an', () async {
      final h = aufbau();
      final id = await h.lebensmittel.legeAn(
        const LebensmittelVorlage(name: 'Prüf-Bons', je100g: bonsJe100g),
      );
      final a = await rohPortion(
        h.db,
        lebensmittelId: id,
        name: 'A',
        mengeG: 10,
      );
      final b = await rohPortion(
        h.db,
        lebensmittelId: id,
        name: 'B',
        mengeG: 20,
      );

      await h.portionen.aendere(Portion(id: a, name: 'A neu', mengeG: 11));

      expect(await h.portionen.fuer(id), [
        Portion(id: a, name: 'A neu', mengeG: 11),
        Portion(id: b, name: 'B', mengeG: 20),
      ]);
    });

    test('aendere ohne id wirft ArgumentError', () async {
      final h = aufbau();
      expect(
        () => h.portionen.aendere(const Portion(name: 'Bon', mengeG: 5.9)),
        throwsArgumentError,
      );
    });

    test('loesche entfernt genau diese Zeile', () async {
      final h = aufbau();
      final id = await h.lebensmittel.legeAn(
        const LebensmittelVorlage(name: 'Prüf-Bons', je100g: bonsJe100g),
      );
      final weg = await rohPortion(
        h.db,
        lebensmittelId: id,
        name: 'Weg',
        mengeG: 10,
      );
      final bleibt = await rohPortion(
        h.db,
        lebensmittelId: id,
        name: 'Bleibt',
        mengeG: 20,
      );

      await h.portionen.loesche(weg);

      expect(await h.portionen.fuer(id), [
        Portion(id: bleibt, name: 'Bleibt', mengeG: 20),
      ]);
      expect(await anzahl(h.db, 'portionen'), 1);
    });

    test(
      'portionenRepositoryProvider liefert ein Repository auf dem Cache',
      () async {
        final db = AppCache(NativeDatabase.memory());
        addTearDown(db.close);
        final container = ProviderContainer(
          retry: (_, _) => null,
          overrides: [appCacheProvider.overrideWithValue(db)],
        );
        addTearDown(container.dispose);

        final id = await LebensmittelRepository(db).legeAn(
          const LebensmittelVorlage(name: 'Prüf-Bons', je100g: bonsJe100g),
        );
        final repo = container.read(portionenRepositoryProvider);
        final pid = await repo.legeAn(
          id,
          const Portion(name: 'Bon', mengeG: 5.9),
        );

        expect(await PortionenRepository(db).fuer(id), [
          Portion(id: pid, name: 'Bon', mengeG: 5.9),
        ]);
      },
    );
  });

  // ═════════════════════════════════════════════════════════════════════
  group('LebensmittelRepository.legeAn mit Portionen', () {
    test('legt Lebensmittel und beide Portionen an', () async {
      final h = aufbau();

      final id = await h.lebensmittel.legeAn(
        const LebensmittelVorlage(name: 'Prüf-Bons', je100g: bonsJe100g),
        portionen: const [
          Portion(name: 'Bon', mengeG: 5.9),
          Portion(name: 'Schale', mengeG: 60),
        ],
      );

      expect(await rohPortionen(h.db, id), [
        (name: 'Bon', mengeG: 5.9, herkunft: 'eigen'),
        (name: 'Schale', mengeG: 60.0, herkunft: 'eigen'),
      ]);
      expect((await h.portionen.fuer(id)).map((p) => (p.name, p.mengeG)), [
        ('Bon', 5.9),
        ('Schale', 60.0),
      ]);
    });

    test('ohne Portionen wie bisher: keine Zeile in portionen', () async {
      final h = aufbau();
      await h.lebensmittel.legeAn(
        const LebensmittelVorlage(name: 'Prüf-Bons', je100g: bonsJe100g),
      );
      expect(await anzahl(h.db, 'portionen'), 0);
    });

    test('scheitert die zweite Portion, steht weder Lebensmittel noch erste '
        'Portion da', () async {
      final h = aufbau();
      await kaputtTrigger(h.db);

      await expectLater(
        h.lebensmittel.legeAn(
          const LebensmittelVorlage(name: 'Prüf-Bons', je100g: bonsJe100g),
          portionen: const [
            Portion(name: 'Bon', mengeG: 5.9),
            Portion(name: 'Kaputt', mengeG: 60),
          ],
        ),
        throwsA(isA<SqliteException>()),
      );

      expect(await anzahl(h.db, 'lebensmittel'), 0);
      expect(await anzahl(h.db, 'portionen'), 0);
    });

    test('schreibt portionenAbgefragtAm aus der Vorlage', () async {
      final h = aufbau();
      final mit = await h.lebensmittel.legeAn(
        LebensmittelVorlage(
          name: 'Prüf-Bons',
          je100g: bonsJe100g,
          portionenAbgefragtAm: jetzt,
        ),
      );
      final ohne = await h.lebensmittel.legeAn(
        const LebensmittelVorlage(name: 'Prüfbrot', je100g: bonsJe100g),
      );

      final gelesen = await h.lebensmittel.lies(mit);
      expect(gelesen!.portionenAbgefragtAm, jetzt);
      expect(gelesen.portionenAbgefragtAm!.isUtc, isTrue);
      expect((await h.lebensmittel.lies(ohne))!.portionenAbgefragtAm, isNull);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Lesepfade füllen portionenAbgefragtAm', () {
    test('lies, zuBarcode und suche', () async {
      final h = aufbau();
      final id = await h.lebensmittel.uebernimm(
        offVorlage(offPortionen: const []),
        jetzt: jetzt,
      );

      expect((await h.lebensmittel.lies(id))!.portionenAbgefragtAm, jetzt);
      expect(
        (await h.lebensmittel.zuBarcode(barcodeBons))!.portionenAbgefragtAm,
        jetzt,
      );
      final treffer = await h.lebensmittel.suche('Prüf-Bons');
      expect(treffer.single.portionenAbgefragtAm, jetzt);

      // Ohne Suchtext nur Gebuchtes (#345) — einmal benutzt, dann da.
      await h.lebensmittel.merkeBenutzung(id, spaeter);
      final zuletzt = await h.lebensmittel.suche('');
      expect(zuletzt.single.portionenAbgefragtAm, jetzt);
    });

    test('offPortionen ist aus der Tabelle gelesen immer null', () async {
      final h = aufbau();
      final id = await h.lebensmittel.uebernimm(
        offVorlage(offPortionen: const [offPortion, offPackung]),
        jetzt: jetzt,
      );

      expect((await h.lebensmittel.lies(id))!.offPortionen, isNull);
      expect(
        (await h.lebensmittel.zuBarcode(barcodeBons))!.offPortionen,
        isNull,
      );
      expect(
        (await h.lebensmittel.suche('Prüf-Bons')).single.offPortionen,
        isNull,
      );
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('LebensmittelRepository.uebernimm mit Portionen', () {
    test('offPortionen [Portion, Packung] → beide da mit Herkunft off, '
        'abgefragt am jetzt', () async {
      final h = aufbau();

      final id = await h.lebensmittel.uebernimm(
        offVorlage(offPortionen: const [offPortion, offPackung]),
        jetzt: jetzt,
      );

      expect(await rohPortionen(h.db, id), [
        (name: 'Portion', mengeG: 5.8, herkunft: 'off'),
        (name: 'Packung', mengeG: 225.0, herkunft: 'off'),
      ]);
      final gelesen = await h.lebensmittel.lies(id);
      expect(gelesen!.portionenAbgefragtAm, jetzt);
      expect(gelesen.portionenAbgefragtAm!.isUtc, isTrue);
    });

    test('offPortionen null → keine Portion, abgefragt bleibt null', () async {
      final h = aufbau();

      // Ohne `jetzt`: Bei `null` braucht es keins — so wie heute.
      final id = await h.lebensmittel.uebernimm(offVorlage());

      expect(await anzahl(h.db, 'portionen'), 0);
      expect((await h.lebensmittel.lies(id))!.portionenAbgefragtAm, isNull);
    });

    test(
      'offPortionen null mit jetzt → abgefragt bleibt trotzdem null',
      () async {
        final h = aufbau();

        final id = await h.lebensmittel.uebernimm(offVorlage(), jetzt: jetzt);

        expect(await anzahl(h.db, 'portionen'), 0);
        expect((await h.lebensmittel.lies(id))!.portionenAbgefragtAm, isNull);
      },
    );

    test('offPortionen [] → keine Portion, abgefragt am jetzt', () async {
      final h = aufbau();

      final id = await h.lebensmittel.uebernimm(
        offVorlage(offPortionen: const []),
        jetzt: jetzt,
      );

      expect(await anzahl(h.db, 'portionen'), 0);
      expect((await h.lebensmittel.lies(id))!.portionenAbgefragtAm, jetzt);
    });

    test(
      'offPortionen gesetzt ohne jetzt → ArgumentError, nichts angelegt',
      () async {
        final h = aufbau();

        await expectLater(
          h.lebensmittel.uebernimm(
            offVorlage(offPortionen: const [offPortion]),
          ),
          throwsArgumentError,
        );
        await expectLater(
          h.lebensmittel.uebernimm(offVorlage(offPortionen: const [])),
          throwsArgumentError,
        );

        expect(await anzahl(h.db, 'lebensmittel'), 0);
        expect(await anzahl(h.db, 'portionen'), 0);
      },
    );

    test('Strichcode schon da → dieselbe id, keine neue Portion, '
        'abgefragt unverändert null', () async {
      final h = aufbau();
      final erst = await h.lebensmittel.uebernimm(offVorlage());

      final dann = await h.lebensmittel.uebernimm(
        offVorlage(offPortionen: const [offPortion, offPackung]),
        jetzt: jetzt,
      );

      expect(dann, erst);
      expect(await anzahl(h.db, 'lebensmittel'), 1);
      expect(await anzahl(h.db, 'portionen'), 0);
      expect((await h.lebensmittel.lies(erst))!.portionenAbgefragtAm, isNull);
    });

    test('Strichcode schon da → abgefragt bleibt beim ersten Zeitpunkt, '
        'Portionen bleiben, wie sie sind', () async {
      final h = aufbau();
      final erst = await h.lebensmittel.uebernimm(
        offVorlage(offPortionen: const [offPortion]),
        jetzt: jetzt,
      );

      final dann = await h.lebensmittel.uebernimm(
        offVorlage(
          offPortionen: const [
            Portion(name: 'Portion', mengeG: 9.9, herkunft: Herkunft.off),
            offPackung,
          ],
        ),
        jetzt: spaeter,
      );

      expect(dann, erst);
      expect(await rohPortionen(h.db, erst), [
        (name: 'Portion', mengeG: 5.8, herkunft: 'off'),
      ]);
      expect((await h.lebensmittel.lies(erst))!.portionenAbgefragtAm, jetzt);
    });

    test(
      'eine im Blatt angelegte Portion bleibt eigen (V3, Festlegung 1)',
      () async {
        final h = aufbau();

        final id = await h.lebensmittel.uebernimm(
          offVorlage(
            offPortionen: const [
              offPortion,
              Portion(name: 'Bon', mengeG: 5.9),
            ],
          ),
          jetzt: jetzt,
        );

        expect(await rohPortionen(h.db, id), [
          (name: 'Portion', mengeG: 5.8, herkunft: 'off'),
          (name: 'Bon', mengeG: 5.9, herkunft: 'eigen'),
        ]);
      },
    );

    test(
      'scheitert eine Portion, steht weder Produkt noch Portion da',
      () async {
        final h = aufbau();
        await kaputtTrigger(h.db);

        await expectLater(
          h.lebensmittel.uebernimm(
            offVorlage(
              offPortionen: const [
                offPortion,
                Portion(name: 'Kaputt', mengeG: 225, herkunft: Herkunft.off),
              ],
            ),
            jetzt: jetzt,
          ),
          throwsA(isA<SqliteException>()),
        );

        expect(await anzahl(h.db, 'lebensmittel'), 0);
        expect(await anzahl(h.db, 'portionen'), 0);
      },
    );
  });

  // ═════════════════════════════════════════════════════════════════════
  group('LebensmittelRepository.trageOffPortionenNach', () {
    /// Ein vor #325 übernommenes Produkt: Herkunft `off`, Strichcode da,
    /// nie nach Portionen gefragt.
    Future<int> altesProdukt(
      LebensmittelRepository repo, {
      bool fluessig = false,
    }) => repo.uebernimm(offVorlage(fluessig: fluessig));

    test('legt die Portionen mit Herkunft off an, setzt die Marke und '
        'antwortet true', () async {
      final h = aufbau();
      final id = await altesProdukt(h.lebensmittel);

      final ergebnis = await h.lebensmittel.trageOffPortionenNach(
        id,
        portionen: const [offPortion, offPackung],
        fluessig: false,
        jetzt: jetzt,
      );

      expect(ergebnis, isTrue);
      expect(await rohPortionen(h.db, id), [
        (name: 'Portion', mengeG: 5.8, herkunft: 'off'),
        (name: 'Packung', mengeG: 225.0, herkunft: 'off'),
      ]);
      expect((await h.lebensmittel.lies(id))!.portionenAbgefragtAm, jetzt);
    });

    test('leere Antwort: keine Portion, Marke trotzdem gesetzt', () async {
      final h = aufbau();
      final id = await altesProdukt(h.lebensmittel);

      final ergebnis = await h.lebensmittel.trageOffPortionenNach(
        id,
        portionen: const [],
        fluessig: false,
        jetzt: jetzt,
      );

      expect(ergebnis, isTrue);
      expect(await anzahl(h.db, 'portionen'), 0);
      expect((await h.lebensmittel.lies(id))!.portionenAbgefragtAm, jetzt);
    });

    test('zweimal hintereinander: beim zweiten Mal false und keine '
        'doppelten Portionen', () async {
      final h = aufbau();
      final id = await altesProdukt(h.lebensmittel);

      final erstes = await h.lebensmittel.trageOffPortionenNach(
        id,
        portionen: const [offPortion, offPackung],
        fluessig: false,
        jetzt: jetzt,
      );
      final zweites = await h.lebensmittel.trageOffPortionenNach(
        id,
        portionen: const [offPortion, offPackung],
        fluessig: false,
        jetzt: spaeter,
      );

      expect(erstes, isTrue);
      expect(zweites, isFalse);
      expect(await rohPortionen(h.db, id), hasLength(2));
      expect(
        (await h.lebensmittel.lies(id))!.portionenAbgefragtAm,
        jetzt,
        reason: 'die Marke bleibt beim ersten Zeitpunkt',
      );
    });

    test('Marke schon gesetzt: tut nichts, auch nicht an fluessig', () async {
      final h = aufbau();
      final id = await h.lebensmittel.uebernimm(
        offVorlage(offPortionen: const []),
        jetzt: jetzt,
      );

      final ergebnis = await h.lebensmittel.trageOffPortionenNach(
        id,
        portionen: const [offPortion],
        fluessig: true,
        jetzt: spaeter,
      );

      expect(ergebnis, isFalse);
      expect(await anzahl(h.db, 'portionen'), 0);
      final gelesen = await h.lebensmittel.lies(id);
      expect(gelesen!.portionenAbgefragtAm, jetzt);
      expect(gelesen.fluessig, isFalse);
    });

    test('fluessig: true auf fluessig = false → true (V5)', () async {
      final h = aufbau();
      final id = await altesProdukt(h.lebensmittel);

      await h.lebensmittel.trageOffPortionenNach(
        id,
        portionen: const [],
        fluessig: true,
        jetzt: jetzt,
      );

      expect((await h.lebensmittel.lies(id))!.fluessig, isTrue);
    });

    test('fluessig: false auf fluessig = true → bleibt true (V5)', () async {
      final h = aufbau();
      final id = await altesProdukt(h.lebensmittel, fluessig: true);

      await h.lebensmittel.trageOffPortionenNach(
        id,
        portionen: const [],
        fluessig: false,
        jetzt: jetzt,
      );

      expect((await h.lebensmittel.lies(id))!.fluessig, isTrue);
    });

    test('eigene Portionen bleiben stehen, nur dieses Lebensmittel bekommt '
        'eine Marke', () async {
      final h = aufbau();
      final id = await altesProdukt(h.lebensmittel);
      final anderes = await h.lebensmittel.uebernimm(
        offVorlage(barcode: barcodeSaft, name: 'Prüfsaft'),
      );
      final bon = await h.portionen.legeAn(
        id,
        const Portion(name: 'Bon', mengeG: 5.9),
      );

      await h.lebensmittel.trageOffPortionenNach(
        id,
        portionen: const [offPackung],
        fluessig: false,
        jetzt: jetzt,
      );

      final gelesen = await h.portionen.fuer(id);
      expect(gelesen.first, Portion(id: bon, name: 'Bon', mengeG: 5.9));
      expect(gelesen.map((p) => p.name), ['Bon', 'Packung']);
      expect(
        (await h.lebensmittel.lies(anderes))!.portionenAbgefragtAm,
        isNull,
      );
    });

    test('scheitert eine Portion: keine Portion, keine Marke, fluessig '
        'unverändert', () async {
      final h = aufbau();
      final id = await altesProdukt(h.lebensmittel);
      await kaputtTrigger(h.db);

      await expectLater(
        h.lebensmittel.trageOffPortionenNach(
          id,
          portionen: const [
            offPortion,
            Portion(name: 'Kaputt', mengeG: 225, herkunft: Herkunft.off),
          ],
          fluessig: true,
          jetzt: jetzt,
        ),
        throwsA(isA<SqliteException>()),
      );

      expect(await anzahl(h.db, 'portionen'), 0);
      final gelesen = await h.lebensmittel.lies(id);
      expect(gelesen!.portionenAbgefragtAm, isNull);
      expect(gelesen.fluessig, isFalse);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Probe der Probe', () {
    test(
      'der Trigger bricht das Anlegen von „Kaputt" mit SqliteException ab',
      () async {
        final h = aufbau();
        await kaputtTrigger(h.db);

        await expectLater(
          rohPortion(h.db, lebensmittelId: 1, name: 'Kaputt', mengeG: 1),
          throwsA(isA<SqliteException>()),
        );
        await rohPortion(h.db, lebensmittelId: 1, name: 'Heil', mengeG: 1);
        expect(await anzahl(h.db, 'portionen'), 1);
      },
    );
  });
}
