// `drift` exportiert eigene `isNull` und `isNotNull` — dieselbe Begründung
// wie in `test/data/schema_v13_test.dart`, Zeile 1–5.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show Database, sqlite3;

import 'package:repit/data/cache.dart';

import 'schema_tabellen.dart';

/// Tests für **Schema v16** — eingetragenes Wasser (#311).
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden. Jede Migration
/// bekommt einen Test — dies ist der für die Stufe 16.
///
/// Nachbar von `schema_v15_test.dart`: derselbe Aufbau, dieselben
/// Hilfsmittel, von Hand gebaute Altstände — **nicht** aus dem heutigen
/// Code erzeugt (`migration_test.dart`, Dateikopf). Der Stand v15 unten ist
/// der von `schema_v15_test.dart` plus `eintraege.vorschlag` und den beiden
/// KI-Tabellen, so wie `AppCache` sie am 04.11.2026 anlegt.
///
/// ## Die erste Entscheidung aus #311 — vom Test-Agenten, nicht von Tim
///
/// Das Ticket nennt sie selbst: Wasser als **eigene Tabelle** oder als
/// **Eintrag ohne Lebensmittel** in `eintraege`, das schon eine Spalte
/// `wasser_ml` trägt. Gewählt ist die **eigene Tabelle**:
///
/// - **Wasser ist keine Mahlzeit.** `eintraege.mahlzeit` ist `NOT NULL`;
///   ein Glas Wasser bekäme eine erfundene Mahlzeit und stünde danach in
///   einer der vier Zeilen. Dann sagte „Mittag" nach einem Glas Wasser
///   „eingetragen" — und genau diese Frage („habe ich Mittag schon
///   eingetragen") ist der Grund, warum es vier Zeilen gibt
///   (`docs/screens/screens/ernaehrung.js`).
/// - **`eintraege.wasser_ml` bleibt, was es ist:** das Wasser **in** einem
///   Lebensmittel (Milch, Suppe), eingefroren wie jeder Nährwert.
///
/// ## Was diese Datei verbindlich vorgibt
///
/// **1. `AppCache.schemaVersion >= 16`** und eine **eigene Stufe**
/// `if (from < 16) { … }` (die 15 ist seit #332 vergeben).
///
/// **2. Eine neue Tabelle `wasser_eintraege`:**
///
/// | Spalte | Typ | NULL | Vorgabe |
/// |---|---|---|---|
/// | `id` | INTEGER, Schlüssel, **AUTOINCREMENT** | nein | — |
/// | `tages_schluessel` | TEXT (ISO-Tag) | nein | — |
/// | `zeitpunkt` | TEXT (Zeitstempel, UTC) | nein | — |
/// | `menge_ml` | REAL | nein | — |
/// | `health_uuid` | TEXT | ja | — |
/// | `health_stand` | TEXT | nein | `'offen'` |
///
/// Drift-Namen: Tabellenklasse `WasserEintraege` (`db.wasserEintraege`),
/// Datenklasse `WasserEintragRow`, Companion `WasserEintraegeCompanion`.
///
/// - **AUTOINCREMENT** aus demselben Grund wie bei `eintraege.id`: Der
///   Health-Nachlauf merkt sich IDs; eine nach dem Löschen neu vergebene
///   Nummer setzte den Stand eines fremden Eintrags.
/// - **`menge_ml` ist `NOT NULL`:** Ein eingetragenes Glas ohne Menge ist
///   kein Eintrag. Anders als `eintraege.menge_g`, wo der Schnelleintrag
///   nichts wiegt.
/// - **`health_stand` mit denselben drei Wörtern** wie `eintraege`
///   (`offen`, `geschrieben`, `nicht_moeglich`): Wasser geht denselben Weg
///   nach Apple Health wie eine Mahlzeit (Spec, „Wasser").
///
/// **3. Additiv.** Keine Zeile in `wasser_eintraege` nach der Migration —
/// auch nicht aus `eintraege.wasser_ml`: Das ist Wasser in Lebensmitteln,
/// kein eingetragenes Glas, und eine Migration erfindet keine Einträge.
/// Alle übrigen Tabellen behalten jede Zeile und jeden Wert.
///
/// **4. Zweimal ausführbar** (#234/#240). Steht `wasser_eintraege` schon in
/// einer Datei mit `user_version = 15`, öffnet sie trotzdem, und die Zeile
/// darin bleibt.
///
/// **5. Zeitstempel kommen als UTC und gleich sich selbst zurück**
/// (`storeDateTimeAsText`, `CLAUDE.md`).
///
/// ## Bestehende Tests, die mit dieser Stufe mitgehen
///
/// `schema_tabellen.dart` trägt `wasser_eintraege` in [tabellenHeute];
/// die älteren Stufen-Tests vergleichen auf Gleichheit dagegen und sind
/// ohne die Stufe rot. `migration_test.dart` nennt die absolute Zahl 16.
/// Beide nachgezogen vom Test-Agenten (`TEST_AENDERN=1`), nicht von Tim
/// gesehen.
///
/// **Alle Zahlen, Namen und Zeitpunkte hier sind erfunden.** Die Zeitpunkte
/// liegen im Jahr 2099.
void main() {
  /// Die dreizehn Tabellen auf Stand v14 — so, wie
  /// `schema_v14_test.dart` sie von Hand anlegt (`restV13` plus
  /// `lebensmittel` mit `barcode` und `herkunft`). Nicht aus dem heutigen
  /// Code erzeugt (`migration_test.dart`, Dateikopf).
  const v14Schema = '''
    CREATE TABLE tages_werte (
      tag TEXT NOT NULL PRIMARY KEY,
      schritte INTEGER,
      ruhepuls_bpm INTEGER,
      gelesen_am TEXT,
      hrv_ms REAL,
      resp_rate REAL,
      recovery_hr_drop INTEGER,
      gewicht_kg REAL,
      trainings_minuten REAL,
      koerperfett_pct REAL,
      fettfrei_kg REAL
    );
    CREATE TABLE stunden_schritte (
      tag TEXT NOT NULL,
      stunde INTEGER NOT NULL,
      schritte INTEGER,
      PRIMARY KEY (tag, stunde)
    );
    CREATE TABLE eigene_daten (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      tag TEXT NOT NULL,
      inhalt TEXT NOT NULL
    );
    CREATE TABLE naechte (
      tag TEXT NOT NULL PRIMARY KEY,
      gelesen_am TEXT,
      ruhepuls_bpm REAL,
      hrv_ms REAL,
      resp_rate REAL
    );
    CREATE TABLE schlaf_abschnitte (
      tag TEXT NOT NULL,
      quelle INTEGER NOT NULL,
      lfd_nr INTEGER NOT NULL,
      phase TEXT NOT NULL,
      beginn TEXT NOT NULL,
      ende TEXT NOT NULL,
      PRIMARY KEY (tag, quelle, lfd_nr)
    );
    CREATE TABLE ziel_werte (
      id INTEGER NOT NULL DEFAULT 0,
      schlafziel_minuten INTEGER NOT NULL,
      schlafenszeit_minuten INTEGER NOT NULL,
      wochenziel_trainingsminuten INTEGER NOT NULL,
      PRIMARY KEY (id)
    );
    CREATE TABLE schlaf_eintraege (
      tag TEXT NOT NULL,
      art TEXT NOT NULL,
      lfd_nr INTEGER NOT NULL,
      schlaf_minuten INTEGER NOT NULL,
      beginn_minuten INTEGER,
      ende_minuten INTEGER,
      notiz TEXT,
      PRIMARY KEY (tag, art, lfd_nr)
    );
    CREATE TABLE stammdaten (
      id INTEGER NOT NULL DEFAULT 0,
      groesse_cm INTEGER,
      geburtsjahr INTEGER,
      zielgewicht_kg REAL,
      zieldatum TEXT,
      PRIMARY KEY (id)
    );
    CREATE TABLE lebensmittel (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL DEFAULT '',
      kcal REAL,
      eiweiss_g REAL,
      kohlenhydrate_g REAL,
      fett_g REAL,
      zucker_g REAL,
      ballaststoffe_g REAL,
      gesaettigt_g REAL,
      wasser_ml REAL,
      extra TEXT NOT NULL DEFAULT '{}',
      fluessig INTEGER NOT NULL DEFAULT 0 CHECK (fluessig IN (0, 1)),
      zuletzt_benutzt TEXT,
      barcode TEXT,
      herkunft TEXT NOT NULL DEFAULT 'eigen'
    );
    CREATE TABLE portionen (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT
    );
    CREATE TABLE eintraege (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      tages_schluessel TEXT NOT NULL,
      mahlzeit TEXT NOT NULL,
      zeitpunkt TEXT NOT NULL,
      lebensmittel_id INTEGER,
      name TEXT NOT NULL,
      menge_g REAL,
      kcal REAL,
      eiweiss_g REAL,
      kohlenhydrate_g REAL,
      fett_g REAL,
      zucker_g REAL,
      ballaststoffe_g REAL,
      gesaettigt_g REAL,
      wasser_ml REAL,
      extra TEXT NOT NULL DEFAULT '{}',
      health_uuid TEXT,
      health_stand TEXT NOT NULL DEFAULT 'offen'
    );
    CREATE TABLE rezepte (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT
    );
    CREATE TABLE rezept_zutaten (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT
    );
  ''';

  /// v15 = v14 + `eintraege.vorschlag` + die beiden KI-Tabellen.
  final v15Schema =
      v14Schema.replaceFirst(
        '''
      health_stand TEXT NOT NULL DEFAULT 'offen'
    );''',
        '''
      health_stand TEXT NOT NULL DEFAULT 'offen',
      vorschlag TEXT
    );''',
      ) +
      '''
    CREATE TABLE ki_einstellungen (
      id INTEGER NOT NULL DEFAULT 0,
      modell TEXT,
      limit_usd REAL,
      preise TEXT NOT NULL DEFAULT '{}',
      geprueft_am TEXT,
      pruef_ergebnis TEXT,
      PRIMARY KEY (id)
    );
    CREATE TABLE ki_anfragen (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      zeitpunkt TEXT NOT NULL,
      monat TEXT NOT NULL,
      modell TEXT NOT NULL,
      zweck TEXT NOT NULL,
      eingabe_token INTEGER NOT NULL,
      ausgabe_token INTEGER NOT NULL,
      denk_token INTEGER NOT NULL,
      kosten_usd REAL
    );
  ''';

  /// `wasser_eintraege`, wie ein anderer Zweig sie schon angelegt haben
  /// könnte — von Hand, nach der Tabelle oben.
  const wasserVorweg = '''
    CREATE TABLE wasser_eintraege (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      tages_schluessel TEXT NOT NULL,
      zeitpunkt TEXT NOT NULL,
      menge_ml REAL NOT NULL,
      health_uuid TEXT,
      health_stand TEXT NOT NULL DEFAULT 'offen'
    );
  ''';

  const wasserZeileVorweg = '''
    INSERT INTO wasser_eintraege
      (id, tages_schluessel, zeitpunkt, menge_ml, health_uuid, health_stand)
      VALUES (4, '2099-03-01', '2099-03-01T09:15:00.000Z', 333.5,
              'PRUEF-UUID-WASSER-0004', 'geschrieben');
  ''';

  /// Tims Bestand auf Stand v15: eine Mahlzeit **mit Wasser im
  /// Lebensmittel**, eine ohne, eine gezählte KI-Anfrage, eine Einstellung.
  /// Eine Migration, die hier etwas verlöre, verlöre es endgültig.
  const bestand = '''
    INSERT INTO tages_werte (tag, schritte, ruhepuls_bpm, gelesen_am)
      VALUES ('2099-03-01', 4321, 55, '2099-03-01T08:00:00.000Z');
    INSERT INTO lebensmittel (id, name, kcal, wasser_ml, fluessig, herkunft)
      VALUES (1, 'Prüfsuppe', 40.5, 88, 1, 'eigen');
    INSERT INTO eintraege
      (id, tages_schluessel, mahlzeit, zeitpunkt, lebensmittel_id, name,
       menge_g, kcal, wasser_ml, extra, health_uuid, health_stand,
       vorschlag)
      VALUES (1, '2099-03-01', 'mittag', '2099-03-01T11:30:00.000Z', 1,
              'Prüfsuppe', 300, 121.5, 264, '{}', 'PRUEF-UUID-0001',
              'geschrieben', NULL);
    INSERT INTO eintraege
      (id, tages_schluessel, mahlzeit, zeitpunkt, name, kcal, extra,
       health_stand, vorschlag)
      VALUES (2, '2099-03-01', 'abend', '2099-03-01T18:45:00.000Z',
              'Freier Prüfeintrag', 512, '{}', 'offen',
              '{"anbieter":"pruef","zweck":"foto"}');
    INSERT INTO ki_einstellungen (id, modell, limit_usd, preise)
      VALUES (0, 'pruef-modell-x', 3.5, '{}');
    INSERT INTO ki_anfragen
      (id, zeitpunkt, monat, modell, zweck, eingabe_token, ausgabe_token,
       denk_token, kosten_usd)
      VALUES (7, '2099-03-01T09:30:00.000Z', '2099-03', 'pruef-modell-x',
              'foto', 1234, 321, 55, 0.00456);
  ''';

  // --- Hilfsmittel, wie in `schema_v15_test.dart` ------------------------

  Database rohdatei(String schema, String inhalt, int version) {
    final roh = sqlite3.openInMemory();
    roh.execute(schema);
    roh.execute(inhalt);
    roh.execute('PRAGMA user_version = $version;');
    return roh;
  }

  AppCache ueber(Database roh) =>
      AppCache(NativeDatabase.opened(roh, closeUnderlyingOnClose: false));

  Future<int> abgelegteVersion(AppCache db) async {
    final zeile = await db.customSelect('PRAGMA user_version;').getSingle();
    return zeile.read<int>('user_version');
  }

  Future<Set<String>> tabellen(AppCache db) async {
    final zeilen = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name NOT LIKE 'sqlite_%';",
        )
        .get();
    return zeilen.map((z) => z.read<String>('name')).toSet();
  }

  Future<
    Map<String, ({String typ, bool nullbar, bool schluessel, String? vorgabe})>
  >
  spalten(AppCache db, String tabelle) async {
    final zeilen = await db.customSelect('PRAGMA table_info($tabelle);').get();
    return {
      for (final z in zeilen)
        z.read<String>('name'): (
          typ: z.read<String>('type').toUpperCase(),
          nullbar: z.read<int>('notnull') == 0,
          schluessel: z.read<int>('pk') > 0,
          vorgabe: z.data['dflt_value'] as String?,
        ),
    };
  }

  Future<List<Map<String, Object?>>> zeilen(AppCache db, String tabelle) async {
    final ergebnis = await db
        .customSelect('SELECT * FROM $tabelle ORDER BY rowid;')
        .get();
    return [for (final z in ergebnis) z.data];
  }

  List<Map<String, Object?>> rohZeilen(Database roh, String tabelle) => [
    for (final z in roh.select('SELECT * FROM $tabelle ORDER BY rowid;'))
      Map<String, Object?>.of(z),
  ];

  void pruefeUnveraendert(
    List<Map<String, Object?>> vorher,
    List<Map<String, Object?>> nachher,
    String tabelle,
  ) {
    expect(
      nachher,
      hasLength(vorher.length),
      reason: 'die Stufe legt in $tabelle keine Zeile an und nimmt keine weg',
    );
    for (var i = 0; i < vorher.length; i++) {
      for (final MapEntry(:key, :value) in vorher[i].entries) {
        expect(
          nachher[i][key],
          value,
          reason:
              '$tabelle, Zeile ${i + 1}, Spalte $key: ein vorhandener '
              'Wert ist Tims Wert',
        );
      }
    }
  }

  /// Die Form von `wasser_eintraege` nach der Tabelle im Dateikopf.
  Future<void> pruefeWasserForm(AppCache db) async {
    final s = await spalten(db, 'wasser_eintraege');
    expect(
      s.keys,
      containsAll([
        'id',
        'tages_schluessel',
        'zeitpunkt',
        'menge_ml',
        'health_uuid',
        'health_stand',
      ]),
    );

    expect(s['id']!.schluessel, isTrue);
    expect(s['id']!.typ, 'INTEGER');

    expect(s['tages_schluessel']!.typ, 'TEXT');
    expect(
      s['tages_schluessel']!.nullbar,
      isFalse,
      reason: 'gefiltert wird über den ISO-Tag, lexikografisch (CLAUDE.md)',
    );

    expect(
      s['zeitpunkt']!.typ,
      'TEXT',
      reason:
          'storeDateTimeAsText — als Unix-Sekunden käme der Zeitpunkt '
          'als Ortszeit zurück (CLAUDE.md)',
    );
    expect(s['zeitpunkt']!.nullbar, isFalse);

    expect(s['menge_ml']!.typ, 'REAL', reason: '333,5 ml sind eine Menge');
    expect(
      s['menge_ml']!.nullbar,
      isFalse,
      reason: 'ein eingetragenes Glas ohne Menge ist kein Eintrag',
    );

    expect(s['health_uuid']!.typ, 'TEXT');
    expect(s['health_uuid']!.nullbar, isTrue);

    expect(s['health_stand']!.typ, 'TEXT');
    expect(s['health_stand']!.nullbar, isFalse);
    expect(s['health_stand']!.vorgabe, "'offen'");

    final sql = await db
        .customSelect(
          "SELECT sql FROM sqlite_master WHERE name = 'wasser_eintraege';",
        )
        .getSingle();
    expect(
      sql.read<String>('sql').toUpperCase(),
      contains('AUTOINCREMENT'),
      reason:
          'ohne AUTOINCREMENT vergibt SQLite eine gelöschte ID neu, und der '
          'Health-Nachlauf setzte den Stand eines fremden Eintrags',
    );
  }

  // ═════════════════════════════════════════════════════════════════════

  test('Vorbedingung: der Altstand v15 ist so gebaut, wie er gemeint ist', () {
    final roh = rohdatei(v15Schema, bestand, 15);
    addTearDown(roh.close);
    final namen = {
      for (final z in roh.select(
        "SELECT name FROM sqlite_master WHERE type = 'table' "
        "AND name NOT LIKE 'sqlite_%';",
      ))
        z['name'] as String,
    };
    expect(namen, isNot(contains('wasser_eintraege')));
    expect(namen, containsAll(['ki_einstellungen', 'ki_anfragen']));
    expect(
      roh.select('PRAGMA table_info(eintraege);').map((z) => z['name']),
      contains('vorschlag'),
    );
  });

  group('Schema v16 (#311)', () {
    test('die Version ist mindestens 16, und ein frischer Cache hat die '
        'Tabelle', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      expect(db.schemaVersion, greaterThanOrEqualTo(16));
      expect(await tabellen(db), containsAll(tabellenHeute));
      expect(await tabellen(db), contains('wasser_eintraege'));
      await pruefeWasserForm(db);
      expect(await zeilen(db, 'wasser_eintraege'), isEmpty);
    });

    test('v15 → v16 legt die Tabelle an, mit der verlangten Form', () async {
      final roh = rohdatei(v15Schema, bestand, 15);
      addTearDown(roh.close);
      final db = ueber(roh);
      addTearDown(db.close);

      expect(await tabellen(db), containsAll(tabellenHeute));
      await pruefeWasserForm(db);
      expect(await abgelegteVersion(db), db.schemaVersion);
    });

    test('v15 → v16 ist additiv: keine erfundenen Wasser-Einträge, auch '
        'nicht aus dem Wasser in Lebensmitteln', () async {
      final roh = rohdatei(v15Schema, bestand, 15);
      addTearDown(roh.close);
      final db = ueber(roh);
      addTearDown(db.close);

      expect(
        await zeilen(db, 'wasser_eintraege'),
        isEmpty,
        reason:
            '`eintraege.wasser_ml` ist Wasser in einer Suppe, kein '
            'eingetragenes Glas — und eine Migration erfindet nichts',
      );
    });

    test(
      'v15 → v16 lässt jede vorhandene Zeile und jeden Wert stehen',
      () async {
        final roh = rohdatei(v15Schema, bestand, 15);
        addTearDown(roh.close);
        const alle = [
          'tages_werte',
          'lebensmittel',
          'eintraege',
          'ki_einstellungen',
          'ki_anfragen',
        ];
        final vorher = {for (final t in alle) t: rohZeilen(roh, t)};

        final db = ueber(roh);
        addTearDown(db.close);

        for (final t in alle) {
          pruefeUnveraendert(vorher[t]!, await zeilen(db, t), t);
        }
      },
    );

    test('zweimal ausführbar: steht die Tabelle schon da, bleibt ihre Zeile '
        'und nichts wird doppelt angelegt', () async {
      final roh = rohdatei(
        v15Schema + wasserVorweg,
        bestand + wasserZeileVorweg,
        15,
      );
      addTearDown(roh.close);
      final vorher = rohZeilen(roh, 'wasser_eintraege');

      final db = ueber(roh);
      addTearDown(db.close);

      expect(await abgelegteVersion(db), db.schemaVersion);
      pruefeUnveraendert(
        vorher,
        await zeilen(db, 'wasser_eintraege'),
        'wasser_eintraege',
      );
      await pruefeWasserForm(db);
    });

    test('ein zweites Öffnen derselben Datei ändert nichts mehr', () async {
      final roh = rohdatei(v15Schema, bestand, 15);
      addTearDown(roh.close);

      final erstes = ueber(roh);
      await erstes.customStatement(
        "INSERT INTO wasser_eintraege (tages_schluessel, zeitpunkt, menge_ml) "
        "VALUES ('2099-03-02', '2099-03-02T07:00:00.000Z', 250);",
      );
      final nachErstem = await zeilen(erstes, 'wasser_eintraege');
      await erstes.close();

      final zweites = ueber(roh);
      addTearDown(zweites.close);
      pruefeUnveraendert(
        nachErstem,
        await zeilen(zweites, 'wasser_eintraege'),
        'wasser_eintraege',
      );
      expect(
        nachErstem.single['health_stand'],
        'offen',
        reason:
            'eine Zeile, deren Stand niemand festgehalten hat, ist nicht '
            'nach Health geschrieben',
      );
    });

    test('Zeitstempel gehen als UTC hinein und kommen gleich zurück', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      final zeitpunkt = DateTime.utc(2099, 3, 28, 23, 45, 12);
      await db
          .into(db.wasserEintraege)
          .insert(
            WasserEintraegeCompanion(
              tagesSchluessel: const Value('2099-03-29'),
              zeitpunkt: Value(zeitpunkt),
              mengeMl: const Value(250),
            ),
          );
      final zeile = (await db.select(db.wasserEintraege).get()).single;

      expect(zeile.zeitpunkt, zeitpunkt);
      expect(zeile.zeitpunkt.isUtc, isTrue);
      expect(zeile.mengeMl, 250);
      expect(zeile.healthUuid, isNull);
      expect(zeile.healthStand, 'offen');
    });
  });
}
