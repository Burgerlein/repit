// `drift` exportiert eigene `isNull` und `isNotNull` — dieselbe Begründung
// wie in `test/data/schema_v13_test.dart`, Zeile 1–5.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show Database, sqlite3;

import 'package:repit/data/cache.dart';

import 'schema_tabellen.dart';

/// Tests für **Schema v17** — Portionen und der Schnappschuss im Eintrag
/// (#393, unter #325).
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden. Jede Migration
/// bekommt einen Test — dies ist der für die Stufe 17.
///
/// Geschrieben nach der Spec `docs/superpowers/specs/2026-11-05-portionen-design.md`,
/// Abschnitt „Die Datenschicht", und Task 1 des Plans
/// `docs/superpowers/plans/2026-11-05-portionen.md` — **ohne** den Code der
/// Stufe gesehen zu haben (es gab ihn beim Schreiben noch nicht). Die
/// Nummer wurde am 05.11.2026 aus `cache.dart` gelesen, auf dem Zweig und
/// in `main` (`schemaVersion => 16`), also ist die nächste freie die 17.
///
/// Nachbar von `schema_v16_test.dart`: derselbe Aufbau, dieselben
/// Hilfsmittel, von Hand gebaute Altstände — **nicht** aus dem heutigen
/// Code erzeugt (`migration_test.dart`, Dateikopf). Der Stand v16 unten ist
/// der von `schema_v16_test.dart` plus `wasser_eintraege`; der Stand v11 ist
/// der aus `schema_v12_test.dart`.
///
/// ## Was diese Datei verbindlich vorgibt (aus der Spec)
///
/// **1. `AppCache.schemaVersion >= 17`** und eine **eigene Stufe**
/// `if (from < 17) { … }`. Geprüft mit `>=`, damit diese Datei bei der
/// nächsten Stufe nicht mitfällt (#208).
///
/// **2. `portionen`** behält `id` und bekommt:
///
/// | Spalte | Typ | NULL | Vorgabe | Drift-Name |
/// |---|---|---|---|---|
/// | `lebensmittel_id` | INTEGER | ja | — | `lebensmittelId` |
/// | `name` | TEXT | nein | `''` | `name` |
/// | `menge_g` | REAL | ja | — | `mengeG` |
/// | `herkunft` | TEXT | nein | `'eigen'` | `herkunft` |
///
/// **3. `eintraege`** bekommt den Schnappschuss, alle drei nullbar:
/// `portion_id` INTEGER (`portionId`), `portion_name` TEXT (`portionName`),
/// `portion_g` REAL (`portionG`). **Keine Spalte für die Anzahl.**
///
/// **4. `lebensmittel`** bekommt `portionen_abgefragt_am` (TEXT, Zeitstempel
/// in UTC, nullbar, **ohne Vorgabewert**, `portionenAbgefragtAm`). Ein
/// Vorgabewert behauptete eine Anfrage an Open Food Facts, die es nie gab.
///
/// **5. Additiv.** Die Stufe legt keine Portion an, setzt kein
/// `portionen_abgefragt_am`, setzt `fluessig` nicht neu. Alte Einträge
/// tragen danach in allen drei Schnappschuss-Spalten `NULL` — sie sind alle
/// in Gramm gebucht, und die Migration erfindet nichts. Alle übrigen
/// Tabellen behalten jede Zeile und jeden Wert.
///
/// **6. Zweimal ausführbar** (#234/#240): Ein v16-Stand, der die neuen
/// Spalten schon trägt, öffnet, und seine Werte bleiben.
///
/// **7. Abgleich** (#233): Eine Datei auf 17, der eine der neuen Spalten
/// fehlt, bekommt sie beim Öffnen.
///
/// **8. Von weit unten:** Ein v11-Stand läuft durch alle Stufen, ohne an
/// `duplicate column name` zu sterben — Stufe 12 legt `eintraege` schon aus
/// der heutigen Definition an, und Stufe 17 darf die Spalten dann nicht ein
/// zweites Mal anhängen.
///
/// **9. Zeitstempel kommen als UTC und gleich sich selbst zurück**
/// (`storeDateTimeAsText`, `CLAUDE.md`).
///
/// **10. Kein Index auf `portionen`** (Spec: `_reconcileSchema` kennt keine
/// Indizes, ein Index stünde auf manchen Geräten und auf anderen nicht).
///
/// ## Festlegungen des Test-Agenten — nicht von Tim freigegeben
///
/// - **„—" in der Vorgabe-Spalte der Spec heißt hier „kein Vorgabewert"**,
///   auch für `portionen.lebensmittel_id`, `portionen.menge_g` und die drei
///   Schnappschuss-Spalten. Ein `portion_g DEFAULT 0` wäre `01` in neuer
///   Verpackung: eine Portion von 0 g statt „ohne Portion gebucht".
/// - **Auch über die neuen Spalten von `eintraege` und `lebensmittel` liegt
///   kein Index.** Die Spec sagt „Kein Index" bei `portionen`; die
///   Begründung (`_reconcileSchema` kennt keine Indizes) gilt für die beiden
///   anderen Tabellen genauso.
/// - **Ein v11-Stand mit einer `eintraege` in alter Form** (aus
///   `schema_v12_test.dart`, `eintraegeVorweg`) bekommt die drei Spalten
///   angehängt, und seine Zeile bleibt. Das geht über den Pflichtfall
///   „von weit unten" hinaus.
/// - **Ein zweites Öffnen ändert am Schema nichts mehr** (gemessen am
///   SQLite-Schema-Zähler, wie in `schema_abgleich_test.dart`).
/// - Die Datenklassen werden nur über ihre Felder angesprochen, nicht über
///   ihre Namen — die Spec legt die Namen der Datenklassen und Companions
///   nicht fest, nur die der Spalten.
///
/// ## Bestehende Tests, die mit dieser Stufe mitgehen
///
/// `migration_test.dart` nennt die absolute Zahl 16, `schema_abgleich_test
/// .dart` die `heutigeNummer` 16 und ein vollständiges Schema ohne die neuen
/// Spalten. Beide nachgezogen vom Test-Agenten (`TEST_AENDERN=1`), nicht
/// von Tim gesehen. `schema_tabellen.dart` bleibt: Die Stufe legt keine
/// Tabelle an.
///
/// **Alle Zahlen, Namen und Zeitpunkte hier sind erfunden.** Die Zeitpunkte
/// liegen im Jahr 2099.
void main() {
  // --- Altstände, von Hand -----------------------------------------------

  /// Die Tabellen, die diese Stufe nicht anfasst, auf Stand v16 — wie
  /// `schema_v16_test.dart` sie von Hand anlegt, plus `wasser_eintraege`.
  const unberuehrtV16 = '''
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
    CREATE TABLE rezepte (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT
    );
    CREATE TABLE rezept_zutaten (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT
    );
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
    CREATE TABLE wasser_eintraege (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      tages_schluessel TEXT NOT NULL,
      zeitpunkt TEXT NOT NULL,
      menge_ml REAL NOT NULL,
      health_uuid TEXT,
      health_stand TEXT NOT NULL DEFAULT 'offen'
    );
  ''';

  /// `lebensmittel` auf Stand v16 (Stufe 13 und 14), mit oder ohne die
  /// Marke der Stufe 17.
  String lebensmittel({required bool mitMarke}) {
    const marke = ',\n      portionen_abgefragt_am TEXT';
    return '''
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
      herkunft TEXT NOT NULL DEFAULT 'eigen'${mitMarke ? marke : ''}
    );
  ''';
  }

  /// `portionen`: seit Stufe 12 nur `id` — oder schon mit den vier Spalten,
  /// wie ein anderer Zweig sie angelegt haben könnte.
  String portionen({required bool mitSpalten}) {
    const spalten = '''
      ,
      lebensmittel_id INTEGER,
      name TEXT NOT NULL DEFAULT '',
      menge_g REAL,
      herkunft TEXT NOT NULL DEFAULT 'eigen'
    ''';
    return '''
    CREATE TABLE portionen (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT${mitSpalten ? spalten : ''}
    );
  ''';
  }

  /// `eintraege` auf Stand v16 (mit `vorschlag` der Stufe 15), dazu die
  /// Schnappschuss-Spalten, die [schnappschuss] nennt.
  String eintraege({List<String> schnappschuss = const []}) {
    const typen = {
      'portion_id': 'INTEGER',
      'portion_name': 'TEXT',
      'portion_g': 'REAL',
    };
    final zusatz = [for (final s in schnappschuss) ',\n      $s ${typen[s]}']
        .join();
    return '''
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
      health_stand TEXT NOT NULL DEFAULT 'offen',
      vorschlag TEXT$zusatz
    );
  ''';
  }

  /// Stand v16, wie er auf einem Gerät liegt, das die Stufe 17 noch nicht
  /// kennt.
  final v16Schema =
      unberuehrtV16 +
      lebensmittel(mitMarke: false) +
      portionen(mitSpalten: false) +
      eintraege();

  /// Stand v16, auf dem ein anderer Zweig die Spalten der Stufe 17 schon
  /// angelegt hat (#234/#240) — alle bauen unter derselben Bundle-ID.
  final v16Vorweg =
      unberuehrtV16 +
      lebensmittel(mitMarke: true) +
      portionen(mitSpalten: true) +
      eintraege(
        schnappschuss: const ['portion_id', 'portion_name', 'portion_g'],
      );

  /// Eine Datei, die schon `user_version = 17` trägt, der aber
  /// `eintraege.portion_g` fehlt (#233): Ein Zweig hat die Nummer
  /// hochgezogen, bevor seine Stufe fertig war.
  final v17OhnePortionG =
      unberuehrtV16 +
      lebensmittel(mitMarke: true) +
      portionen(mitSpalten: true) +
      eintraege(schnappschuss: const ['portion_id', 'portion_name']);

  /// Tims Bestand auf Stand v16: zwei Lebensmittel (ein eigenes und ein
  /// übernommenes, flüssiges mit Strichcode), zwei Einträge (einer mit
  /// Lebensmittel, einer frei mit Vorschlag), dazu je eine Zeile in den
  /// übrigen Ernährungs-, KI- und Wassertabellen. Eine Migration, die hier
  /// etwas verlöre, verlöre es endgültig.
  const bestand = '''
    INSERT INTO tages_werte (tag, schritte, ruhepuls_bpm, gelesen_am)
      VALUES ('2099-03-01', 4321, 55, '2099-03-01T08:00:00.000Z');
    INSERT INTO lebensmittel
      (id, name, kcal, eiweiss_g, wasser_ml, extra, fluessig,
       zuletzt_benutzt, barcode, herkunft)
      VALUES (1, 'Prüfknäcke', 377.7, 9.9, NULL, '{}', 0,
              '2099-03-01T07:15:00.000Z', NULL, 'eigen');
    INSERT INTO lebensmittel
      (id, name, kcal, eiweiss_g, wasser_ml, extra, fluessig,
       zuletzt_benutzt, barcode, herkunft)
      VALUES (2, 'Prüftrunk', 42.4, 3.3, 88.8, '{"jod_ug":1.5}', 1,
              NULL, '0000000000017', 'off');
    INSERT INTO eintraege
      (id, tages_schluessel, mahlzeit, zeitpunkt, lebensmittel_id, name,
       menge_g, kcal, eiweiss_g, wasser_ml, extra, health_uuid,
       health_stand, vorschlag)
      VALUES (1, '2099-03-01', 'frueh', '2099-03-01T07:15:00.000Z', 1,
              'Prüfknäcke', 11.8, 44.6, 1.2, NULL, '{}', 'PRUEF-UUID-0001',
              'geschrieben', NULL);
    INSERT INTO eintraege
      (id, tages_schluessel, mahlzeit, zeitpunkt, lebensmittel_id, name,
       menge_g, kcal, extra, health_stand, vorschlag)
      VALUES (2, '2099-03-01', 'abend', '2099-03-01T18:45:00.000Z', NULL,
              'Freier Prüfeintrag', NULL, 512, '{}', 'offen',
              '{"anbieter":"pruef","zweck":"foto"}');
    INSERT INTO ki_einstellungen (id, modell, limit_usd, preise)
      VALUES (0, 'pruef-modell-x', 3.5, '{}');
    INSERT INTO wasser_eintraege
      (id, tages_schluessel, zeitpunkt, menge_ml, health_uuid, health_stand)
      VALUES (4, '2099-03-01', '2099-03-01T09:15:00.000Z', 333.5, NULL,
              'offen');
  ''';

  /// Die eine Portionszeile eines v16-Geräts: nur `id`, mehr gab es nicht.
  const portionNurId = '''
    INSERT INTO portionen (id) VALUES (5);
  ''';

  /// Werte in den vorweggenommenen Spalten — sie gehören jemandem und
  /// müssen bleiben.
  const vorwegWerte = '''
    INSERT INTO portionen (id, lebensmittel_id, name, menge_g, herkunft)
      VALUES (5, 1, 'Prüfbon', 5.9, 'eigen');
    INSERT INTO portionen (id, lebensmittel_id, name, menge_g, herkunft)
      VALUES (6, 2, 'Packung', 250.5, 'off');
    UPDATE eintraege
      SET portion_id = 5, portion_name = 'Prüfbon', portion_g = 5.9
      WHERE id = 1;
    UPDATE lebensmittel
      SET portionen_abgefragt_am = '2099-03-01T10:20:30.000Z'
      WHERE id = 2;
  ''';

  /// Werte auf der Datei ohne `portion_g` — dieselben, nur ohne Gramm.
  const ohnePortionGWerte = '''
    INSERT INTO portionen (id, lebensmittel_id, name, menge_g, herkunft)
      VALUES (5, 1, 'Prüfbon', 5.9, 'eigen');
    UPDATE eintraege
      SET portion_id = 5, portion_name = 'Prüfbon'
      WHERE id = 1;
  ''';

  /// Schema v11 — wörtlich aus `schema_v12_test.dart`: acht Tabellen, noch
  /// keine Ernährung.
  const v11Schema = '''
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
  ''';

  /// `eintraege` in der alten Form, wie ein anderer Zweig sie auf einem
  /// v11-Gerät angelegt haben könnte — wörtlich aus `schema_v12_test.dart`.
  const eintraegeVorwegV11 = '''
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
      extra TEXT,
      health_uuid TEXT,
      health_stand TEXT NOT NULL
    );
    INSERT INTO eintraege
      (tages_schluessel, mahlzeit, zeitpunkt, lebensmittel_id, name, menge_g,
       kcal, eiweiss_g, kohlenhydrate_g, fett_g, zucker_g, ballaststoffe_g,
       gesaettigt_g, wasser_ml, extra, health_uuid, health_stand)
      VALUES ('2099-03-01', 'abend', '2099-03-01T18:30:00.000Z', NULL,
              'Grützwurst mit Kompott', 333.3,
              1234.5, 11.1, 22.2, 33.3, 44.4, 55.5, 66.6, 77.7,
              '{}', NULL, 'offen');
  ''';

  const v11Bestand = '''
    INSERT INTO tages_werte (tag, schritte, ruhepuls_bpm, gelesen_am)
      VALUES ('2099-03-01', 4242, 99, '2099-03-01T09:00:00.000Z');
    INSERT INTO stammdaten (id, groesse_cm, geburtsjahr, zielgewicht_kg,
                            zieldatum)
      VALUES (0, 211, 1904, 33.3, '2099-12-31');
  ''';

  const neueSpalten = {
    'portionen': ['lebensmittel_id', 'name', 'menge_g', 'herkunft'],
    'eintraege': ['portion_id', 'portion_name', 'portion_g'],
    'lebensmittel': ['portionen_abgefragt_am'],
  };

  // --- Hilfsmittel, wie in `schema_v16_test.dart` ------------------------

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

  Set<String> rohSpalten(Database roh, String tabelle) => {
    for (final z in roh.select('PRAGMA table_info($tabelle);'))
      z['name'] as String,
  };

  int schemaZaehler(Database roh) =>
      roh.select('PRAGMA schema_version;').single['schema_version'] as int;

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

  /// Die Form der neuen Spalten nach den Tabellen im Dateikopf.
  Future<void> pruefeForm(AppCache db) async {
    // portionen
    final p = await spalten(db, 'portionen');
    expect(p.keys, containsAll(['id', ...neueSpalten['portionen']!]));
    expect(p['id']!.schluessel, isTrue, reason: 'id bleibt der Schlüssel');

    expect(p['lebensmittel_id']!.typ, 'INTEGER');
    expect(
      p['lebensmittel_id']!.nullbar,
      isTrue,
      reason: 'nullbar, weil die Spalte nachgetragen wird (Spec)',
    );
    expect(p['lebensmittel_id']!.vorgabe, isNull);

    expect(p['name']!.typ, 'TEXT');
    expect(p['name']!.nullbar, isFalse);
    expect(
      p['name']!.vorgabe,
      "''",
      reason:
          'NOT NULL ohne Vorgabe ließe sich nicht anhängen — SQLite lehnt '
          'ALTER TABLE … ADD COLUMN … NOT NULL ohne DEFAULT ab',
    );

    expect(p['menge_g']!.typ, 'REAL', reason: '5,9 g sind eine Menge');
    expect(p['menge_g']!.nullbar, isTrue);
    expect(
      p['menge_g']!.vorgabe,
      isNull,
      reason: 'eine Portion von 0 g wäre keine — `0` ist keine Antwort',
    );

    expect(p['herkunft']!.typ, 'TEXT');
    expect(p['herkunft']!.nullbar, isFalse);
    expect(p['herkunft']!.vorgabe, "'eigen'");

    // eintraege
    final e = await spalten(db, 'eintraege');
    expect(e.keys, containsAll(neueSpalten['eintraege']!));
    expect(
      e.keys,
      isNot(contains('anzahl')),
      reason:
          'keine Spalte für die Anzahl — sie ist menge_g / portion_g, und '
          'eine zweite Spalte könnte der ersten widersprechen',
    );
    for (final (name, typ) in [
      ('portion_id', 'INTEGER'),
      ('portion_name', 'TEXT'),
      ('portion_g', 'REAL'),
    ]) {
      expect(e[name]!.typ, typ, reason: 'eintraege.$name');
      expect(
        e[name]!.nullbar,
        isTrue,
        reason: 'eintraege.$name: ohne Portion gebucht heißt null',
      );
      expect(
        e[name]!.vorgabe,
        isNull,
        reason:
            'eintraege.$name: ein Vorgabewert erfände für jeden alten '
            'Eintrag eine Portion',
      );
    }

    // lebensmittel
    final l = await spalten(db, 'lebensmittel');
    expect(l.keys, containsAll(neueSpalten['lebensmittel']!));
    expect(
      l['portionen_abgefragt_am']!.typ,
      'TEXT',
      reason:
          'storeDateTimeAsText — als Unix-Sekunden käme der Zeitpunkt als '
          'Ortszeit zurück (CLAUDE.md)',
    );
    expect(l['portionen_abgefragt_am']!.nullbar, isTrue);
    expect(
      l['portionen_abgefragt_am']!.vorgabe,
      isNull,
      reason:
          'kein Vorgabewert: er behauptete eine Anfrage, die es nie gab — '
          'und null ist genau das, was die einmalige Nachfrage auslöst',
    );

    // Kein Index
    final indizesPortionen = await db
        .customSelect('PRAGMA index_list(portionen);')
        .get();
    expect(
      indizesPortionen,
      isEmpty,
      reason:
          'kein Index auf portionen — _reconcileSchema kennt keine Indizes, '
          'und ein Index stünde auf manchen Geräten und auf anderen nicht',
    );
    final indizes = await db
        .customSelect(
          "SELECT name, sql FROM sqlite_master WHERE type = 'index' "
          "AND tbl_name IN ('eintraege', 'lebensmittel') "
          'AND sql IS NOT NULL;',
        )
        .get();
    for (final i in indizes) {
      final sql = i.read<String>('sql');
      for (final s in [
        ...neueSpalten['eintraege']!,
        ...neueSpalten['lebensmittel']!,
      ]) {
        expect(
          sql,
          isNot(contains(s)),
          reason: 'kein Index über $s (dieselbe Begründung wie bei portionen)',
        );
      }
    }
  }

  // ═════════════════════════════════════════════════════════════════════

  group('Vorbedingungen: die Altstände sind so gebaut, wie sie gemeint '
      'sind', () {
    test('v16 trägt keine der neuen Spalten', () {
      final roh = rohdatei(v16Schema, bestand + portionNurId, 16);
      addTearDown(roh.close);
      for (final MapEntry(key: tabelle, value: namen) in neueSpalten.entries) {
        for (final s in namen) {
          expect(rohSpalten(roh, tabelle), isNot(contains(s)));
        }
      }
      expect(rohZeilen(roh, 'portionen'), hasLength(1));
      expect(rohZeilen(roh, 'lebensmittel'), hasLength(2));
      expect(rohZeilen(roh, 'eintraege'), hasLength(2));
    });

    test('v16 vorweg trägt alle neuen Spalten, mit Werten', () {
      final roh = rohdatei(v16Vorweg, bestand + vorwegWerte, 16);
      addTearDown(roh.close);
      for (final MapEntry(key: tabelle, value: namen) in neueSpalten.entries) {
        expect(rohSpalten(roh, tabelle), containsAll(namen));
      }
      expect(
        roh
            .select('SELECT portion_g FROM eintraege WHERE id = 1;')
            .single['portion_g'],
        5.9,
      );
    });

    test('v17 ohne portion_g trägt alles außer portion_g', () {
      final roh = rohdatei(v17OhnePortionG, bestand + ohnePortionGWerte, 17);
      addTearDown(roh.close);
      expect(rohSpalten(roh, 'eintraege'), isNot(contains('portion_g')));
      expect(
        rohSpalten(roh, 'eintraege'),
        containsAll(['portion_id', 'portion_name']),
      );
      expect(
        rohSpalten(roh, 'portionen'),
        containsAll(neueSpalten['portionen']!),
      );
      expect(
        rohSpalten(roh, 'lebensmittel'),
        contains('portionen_abgefragt_am'),
      );
    });
  });

  group('Schema v17 — frisch angelegt', () {
    test('die Version ist mindestens 17', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      expect(db.schemaVersion, greaterThanOrEqualTo(17));
      expect(await abgelegteVersion(db), db.schemaVersion);
    });

    test('die neuen Spalten sind da, in der verlangten Form, und keine '
        'Tabelle mehr oder weniger', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      expect(
        await tabellen(db),
        tabellenHeute,
        reason: 'die Stufe legt keine Tabelle an',
      );
      await pruefeForm(db);
      expect(await zeilen(db, 'portionen'), isEmpty);
    });
  });

  group('Migration v16 → v17', () {
    test('die Datei steht danach auf der heutigen Version, mit der '
        'verlangten Form', () async {
      final roh = rohdatei(v16Schema, bestand + portionNurId, 16);
      addTearDown(roh.close);
      final db = ueber(roh);
      addTearDown(db.close);

      expect(await abgelegteVersion(db), db.schemaVersion);
      expect(await tabellen(db), tabellenHeute);
      await pruefeForm(db);
    });

    test(
      'additiv: jede Zeile und jeder Wert bleibt, in allen Tabellen',
      () async {
        final roh = rohdatei(v16Schema, bestand + portionNurId, 16);
        addTearDown(roh.close);
        const alle = [
          'tages_werte',
          'lebensmittel',
          'portionen',
          'eintraege',
          'ki_einstellungen',
          'wasser_eintraege',
        ];
        final vorher = {for (final t in alle) t: rohZeilen(roh, t)};

        final db = ueber(roh);
        addTearDown(db.close);

        for (final t in alle) {
          pruefeUnveraendert(vorher[t]!, await zeilen(db, t), t);
        }
      },
    );

    test('alte Einträge tragen keinen Schnappschuss — sie sind in Gramm '
        'gebucht, und die Migration erfindet nichts', () async {
      final roh = rohdatei(v16Schema, bestand + portionNurId, 16);
      addTearDown(roh.close);
      final db = ueber(roh);
      addTearDown(db.close);

      final alle = await zeilen(db, 'eintraege');
      expect(alle, hasLength(2));
      for (final z in alle) {
        expect(z['portion_id'], isNull, reason: 'Eintrag ${z['id']}');
        expect(z['portion_name'], isNull, reason: 'Eintrag ${z['id']}');
        expect(z['portion_g'], isNull, reason: 'Eintrag ${z['id']}');
      }

      final getippt = await db.select(db.eintraege).get();
      expect(getippt, hasLength(2));
      for (final z in getippt) {
        expect(z.portionId, isNull);
        expect(z.portionName, isNull);
        expect(z.portionG, isNull);
      }
    });

    test('kein Lebensmittel gilt danach als abgefragt', () async {
      final roh = rohdatei(v16Schema, bestand + portionNurId, 16);
      addTearDown(roh.close);
      final db = ueber(roh);
      addTearDown(db.close);

      final alle = await zeilen(db, 'lebensmittel');
      expect(alle, hasLength(2));
      for (final z in alle) {
        expect(
          z['portionen_abgefragt_am'],
          isNull,
          reason:
              'Lebensmittel ${z['id']}: null löst die einmalige Nachfrage '
              'aus — ein gesetzter Wert verhinderte sie für immer',
        );
      }
      expect(alle.map((z) => z['fluessig']).toList(), [
        0,
        1,
      ], reason: 'die Stufe setzt fluessig nicht neu');

      final getippt = await db.select(db.lebensmittel).get();
      for (final z in getippt) {
        expect(z.portionenAbgefragtAm, isNull);
      }
    });

    test('die alte Portionszeile bekommt die Vorgaben, keine neue Zeile '
        'kommt dazu', () async {
      final roh = rohdatei(v16Schema, bestand + portionNurId, 16);
      addTearDown(roh.close);
      final db = ueber(roh);
      addTearDown(db.close);

      final alle = await zeilen(db, 'portionen');
      expect(
        alle,
        hasLength(1),
        reason:
            'die Stufe legt keine Portion an, auch nicht aus alten '
            'Einträgen oder Lebensmitteln',
      );
      final z = alle.single;
      expect(z['id'], 5);
      expect(z['name'], '');
      expect(z['herkunft'], 'eigen');
      expect(z['lebensmittel_id'], isNull);
      expect(z['menge_g'], isNull);

      final getippt = await db.select(db.portionen).getSingle();
      expect(getippt.id, 5);
      expect(getippt.name, '');
      expect(getippt.herkunft, 'eigen');
      expect(getippt.lebensmittelId, isNull);
      expect(getippt.mengeG, isNull);
    });

    test(
      'ein zweites Öffnen derselben Datei ändert am Schema nichts mehr',
      () async {
        final roh = rohdatei(v16Schema, bestand + portionNurId, 16);
        addTearDown(roh.close);

        final erstes = ueber(roh);
        await erstes.select(erstes.tagesWerte).get();
        await erstes.close();
        final nachErstem = schemaZaehler(roh);
        final zeilenNachErstem = {
          for (final t in neueSpalten.keys) t: rohZeilen(roh, t),
        };

        final zweites = ueber(roh);
        addTearDown(zweites.close);
        await zweites.select(zweites.tagesWerte).get();

        expect(
          schemaZaehler(roh),
          nachErstem,
          reason:
              'PRAGMA schema_version steigt bei jedem CREATE, ALTER und DROP. '
              'Steigt er beim zweiten Öffnen, hängt die Stufe oder der '
              'Abgleich bei jedem Start erneut an',
        );
        for (final t in neueSpalten.keys) {
          pruefeUnveraendert(zeilenNachErstem[t]!, await zeilen(zweites, t), t);
        }
      },
    );
  });

  group('Die Stufe ist zweimal ausführbar (#234/#240)', () {
    test('stehen die Spalten schon da, öffnet die Datei, und jeder Wert '
        'darin bleibt', () async {
      final roh = rohdatei(v16Vorweg, bestand + vorwegWerte, 16);
      addTearDown(roh.close);
      const alle = [
        'tages_werte',
        'lebensmittel',
        'portionen',
        'eintraege',
        'ki_einstellungen',
        'wasser_eintraege',
      ];
      final vorher = {for (final t in alle) t: rohZeilen(roh, t)};

      final db = ueber(roh);
      addTearDown(db.close);

      expect(await abgelegteVersion(db), db.schemaVersion);
      for (final t in alle) {
        pruefeUnveraendert(vorher[t]!, await zeilen(db, t), t);
      }
      await pruefeForm(db);
    });

    test('und die Werte kommen über drift richtig heraus', () async {
      final roh = rohdatei(v16Vorweg, bestand + vorwegWerte, 16);
      addTearDown(roh.close);
      final db = ueber(roh);
      addTearDown(db.close);

      final portionen = await (db.select(
        db.portionen,
      )..orderBy([(p) => OrderingTerm.asc(p.id)])).get();
      expect(portionen, hasLength(2));
      expect(portionen[0].lebensmittelId, 1);
      expect(portionen[0].name, 'Prüfbon');
      expect(portionen[0].mengeG, 5.9);
      expect(portionen[0].herkunft, 'eigen');
      expect(portionen[1].lebensmittelId, 2);
      expect(portionen[1].name, 'Packung');
      expect(portionen[1].mengeG, 250.5);
      expect(portionen[1].herkunft, 'off');

      final eintraege = await (db.select(
        db.eintraege,
      )..orderBy([(e) => OrderingTerm.asc(e.id)])).get();
      expect(eintraege[0].portionId, 5);
      expect(eintraege[0].portionName, 'Prüfbon');
      expect(eintraege[0].portionG, 5.9);
      expect(eintraege[0].mengeG, 11.8);
      expect(eintraege[1].portionId, isNull);
      expect(eintraege[1].portionName, isNull);
      expect(eintraege[1].portionG, isNull);

      final lebensmittel = await (db.select(
        db.lebensmittel,
      )..orderBy([(l) => OrderingTerm.asc(l.id)])).get();
      expect(lebensmittel[0].portionenAbgefragtAm, isNull);
      expect(
        lebensmittel[1].portionenAbgefragtAm,
        DateTime.utc(2099, 3, 1, 10, 20, 30),
      );
      expect(lebensmittel[1].portionenAbgefragtAm!.isUtc, isTrue);
    });
  });

  group('Abgleich beim Öffnen (#233)', () {
    test('eine Datei auf 17, der eintraege.portion_g fehlt, bekommt die '
        'Spalte — und verliert nichts', () async {
      final roh = rohdatei(v17OhnePortionG, bestand + ohnePortionGWerte, 17);
      addTearDown(roh.close);
      const alle = [
        'tages_werte',
        'lebensmittel',
        'portionen',
        'eintraege',
        'ki_einstellungen',
        'wasser_eintraege',
      ];
      final vorher = {for (final t in alle) t: rohZeilen(roh, t)};

      final db = ueber(roh);
      addTearDown(db.close);
      // Der erste Zugriff: Das Öffnen selbst ist bei drift lazy.
      await db.select(db.tagesWerte).get();

      expect(
        (await spalten(db, 'eintraege')).keys,
        contains('portion_g'),
        reason:
            'onUpgrade läuft bei from == 17 nicht in die Stufe 17 — die '
            'Spalte kommt nur über den Abgleich',
      );
      await pruefeForm(db);
      expect(await abgelegteVersion(db), db.schemaVersion);
      for (final t in alle) {
        pruefeUnveraendert(vorher[t]!, await zeilen(db, t), t);
      }

      final eintrag = (await zeilen(db, 'eintraege')).first;
      expect(eintrag['portion_id'], 5);
      expect(eintrag['portion_name'], 'Prüfbon');
      expect(
        eintrag['portion_g'],
        isNull,
        reason: 'der Abgleich erfindet keine Gramm, er hängt nur die Spalte an',
      );
    });
  });

  group('Von weit unten: v11 → heute', () {
    test('ein v11-Stand öffnet ohne `duplicate column name` und hat danach '
        'die neuen Spalten', () async {
      final roh = rohdatei(v11Schema, v11Bestand, 11);
      addTearDown(roh.close);
      final vorher = rohZeilen(roh, 'tages_werte');

      final db = ueber(roh);
      addTearDown(db.close);

      // Scheiterte eine Stufe an einer doppelten Spalte, würfe schon dieser
      // erste Zugriff.
      expect(await abgelegteVersion(db), db.schemaVersion);
      expect(await tabellen(db), tabellenHeute);
      await pruefeForm(db);
      pruefeUnveraendert(
        vorher,
        await zeilen(db, 'tages_werte'),
        'tages_werte',
      );
      expect(await zeilen(db, 'portionen'), isEmpty);
      expect(await zeilen(db, 'lebensmittel'), isEmpty);
    });

    test('auch wenn ein anderer Zweig eintraege schon in alter Form angelegt '
        'hat: die Spalten kommen dazu, die Zeile bleibt', () async {
      final roh = rohdatei(v11Schema + eintraegeVorwegV11, v11Bestand, 11);
      addTearDown(roh.close);
      final vorher = rohZeilen(roh, 'eintraege');

      final db = ueber(roh);
      addTearDown(db.close);

      expect(await abgelegteVersion(db), db.schemaVersion);
      await pruefeForm(db);
      pruefeUnveraendert(vorher, await zeilen(db, 'eintraege'), 'eintraege');
      final z = (await zeilen(db, 'eintraege')).single;
      expect(z['portion_id'], isNull);
      expect(z['portion_name'], isNull);
      expect(z['portion_g'], isNull);
    });
  });

  group('portionen_abgefragt_am kommt als UTC und gleich sich selbst '
      'zurück', () {
    final quellen = <String, AppCache Function()>{
      'frisch angelegt': () => AppCache(NativeDatabase.memory()),
      'aus v16 migriert': () => AppCache(
        NativeDatabase.memory(
          setup: (roh) {
            roh.execute(v16Schema);
            roh.execute(bestand + portionNurId);
            roh.execute('PRAGMA user_version = 16;');
          },
        ),
      ),
    };

    for (final MapEntry(key: name, value: oeffne) in quellen.entries) {
      test(name, () async {
        final db = oeffne();
        addTearDown(db.close);

        // Kurz vor Mitternacht UTC: in Berlin schon der Folgetag. Käme der
        // Wert als Ortszeit zurück, wäre er ungleich sich selbst.
        final abgefragt = DateTime.utc(2099, 3, 28, 23, 45, 12, 345);
        await db.customInsert(
          'INSERT INTO lebensmittel (id, name, portionen_abgefragt_am) '
          'VALUES (?, ?, ?);',
          variables: [
            Variable.withInt(99),
            Variable.withString('Prüfquark'),
            Variable<DateTime>(abgefragt),
          ],
        );

        final roh = await db
            .customSelect(
              'SELECT typeof(portionen_abgefragt_am) AS art '
              'FROM lebensmittel WHERE id = 99;',
            )
            .getSingle();
        expect(
          roh.read<String>('art'),
          'text',
          reason: 'storeDateTimeAsText: als Text in der Datei',
        );

        final zeile = await (db.select(
          db.lebensmittel,
        )..where((l) => l.id.equals(99))).getSingle();
        expect(zeile.portionenAbgefragtAm, isNotNull);
        expect(zeile.portionenAbgefragtAm!.isUtc, isTrue);
        expect(zeile.portionenAbgefragtAm, abgefragt);
      });
    }
  });
}
