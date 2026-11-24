// `drift` exportiert eigene `isNull` und `isNotNull` — dieselbe Begründung
// wie in `test/data/schema_v13_test.dart`, Zeile 1–5.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show Database;

import 'package:repit/data/cache.dart';

/// Tests für **Schema v14** — `lebensmittel` bekommt `barcode` und
/// `herkunft` (#284, Open Food Facts).
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden.
///
/// Nachbar von `test/data/schema_v13_test.dart`, im selben Verzeichnis:
/// derselbe Aufbau, dieselben Hilfsmittel, von Hand gebaute Altstände.
///
/// ## Warum es diese Stufe gibt
///
/// Die Spec (`2026-11-03-ernaehrung-design.md`, „Open Food Facts") legt
/// fest: Ein Treffer wird **mit Herkunft `off`** in `lebensmittel`
/// übernommen, ein selbst angelegtes trägt Herkunft `eigen`. Und ein
/// zweites Buchen desselben Produkts darf kein zweites anlegen — dafür
/// muss die Tabelle den Strichcode kennen. `schema_v13_test.dart` hat
/// `lebensmittel` ohne beide Spalten festgelegt; die Kommentare in
/// `ernaehrung_tabellen.dart` schreiben Strichcode und Herkunft
/// ausdrücklich Task 6 zu.
///
/// ## Was diese Datei verbindlich vorgibt
///
/// **1. `AppCache.schemaVersion >= 14`** und eine **eigene Stufe**
/// `if (from < 14) { … }`. Die Nummer wurde am 04.11.2026 aus
/// `cache.dart` gelesen (`schemaVersion => 13`), also ist die nächste
/// freie die 14. Geprüft wird mit `>=`, damit diese Datei bei der
/// nächsten Stufe nicht mitfällt (#208).
///
/// **2. `lebensmittel` trägt danach:**
///
/// | Spalte | Typ | NULL | Warum |
/// |---|---|---|---|
/// | `barcode` | TEXT | **ja** | selbst angelegte haben keinen |
/// | `herkunft` | TEXT | nein, Vorgabe `'eigen'` | `'eigen'` oder `'off'` |
///
/// **3. Additiv.** Alte Zeilen behalten jeden Wert, bekommen
/// `herkunft = 'eigen'` und `barcode = NULL`.
///
/// ## Entscheidung des Test-Agenten: alte Zeilen sind `eigen`
///
/// **Nicht mit Tim abgestimmt, nicht freigegeben** — mit Begründung. Eine
/// Migration füllt alte Zeilen nicht mit Erfundenem (`CLAUDE.md`). `eigen`
/// ist hier aber nicht erfunden, sondern die einzige Möglichkeit: Vor v14
/// gab es keinen Weg von Open Food Facts in die Tabelle, jede Zeile ist
/// von Hand angelegt (#285). Und `NOT NULL` mit Vorgabe, weil SQLite
/// `ADD COLUMN … NOT NULL` ohne Vorgabewert ablehnt — derselbe Grund wie
/// bei `name` in v13.
///
/// ## Entscheidung des Test-Agenten: Herkunft als Text
///
/// **Nicht mit Tim abgestimmt, nicht freigegeben** — mit Begründung.
/// `'eigen'`/`'off'` und nicht `0`/`1`: Wer die Datei mit einem
/// SQLite-Werkzeug öffnet (Übernahme, Fehlersuche), liest, was dasteht.
/// Dieselbe Haltung wie `eintraege.health_stand` (`'offen'`) und
/// `eintraege.mahlzeit` (`'abend'`).
///
/// ## Nicht festgelegt
///
/// **Ob `barcode` einen `UNIQUE`-Index bekommt.** Dass ein Strichcode nur
/// einmal übernommen wird, prüft `lebensmittel_herkunft_test.dart` am
/// Verhalten; wie die Datenbank das absichert, ist Sache der
/// Implementierung. Ein eindeutiger Index wäre zulässig — SQLite erlaubt
/// darin beliebig viele `NULL`, also stören die selbst angelegten nicht.
///
/// ## Bestehende Tests, die mit der Stufe rot werden
///
/// `test/data/migration_test.dart` (`db.schemaVersion, 13`) und
/// `test/data/schema_v13_test.dart` (`db.schemaVersion, 13` und
/// `abgelegteVersion(db), 13`) nageln die heutige Zahl fest. **Diese Datei
/// ändert sie nicht** — das ist an den Koordinator gemeldet.
///
/// **Alle Zahlen und Namen hier sind erfunden.** Die Tagesschlüssel liegen
/// im Jahr 2099, damit sie keinen Termin nachahmen.
void main() {
  /// `lebensmittel` auf Stand v13 — so, wie `ernaehrung_tabellen.dart` sie
  /// am 04.11.2026 anlegt. Von Hand geschrieben, nicht aus dem heutigen
  /// Code erzeugt (`migration_test.dart`, Dateikopf).
  const lebensmittelV13 = '''
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
      zuletzt_benutzt TEXT
    );
  ''';

  /// Dieselbe Tabelle, wie ein **anderer Zweig** sie halb ausgebaut haben
  /// könnte: `barcode` steht schon, `herkunft` fehlt (#234/#240).
  const lebensmittelHalb = '''
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
      barcode TEXT
    );
  ''';

  /// Die übrigen zwölf Tabellen auf Stand v13 — wortgleich zu `v12Schema`
  /// in `schema_v13_test.dart` ohne `lebensmittel`; v13 hat an ihnen
  /// nichts geändert.
  const restV13 = '''
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

  /// Zwei von Hand angelegte Vorlagen, eine davon schon gebucht, und der
  /// Eintrag dazu. **Das ist Tims Arbeit seit #285** — eine Migration, die
  /// hier etwas verlöre, verlöre sie endgültig.
  const bestand = '''
    INSERT INTO lebensmittel
      (id, name, kcal, eiweiss_g, kohlenhydrate_g, fett_g, zucker_g,
       ballaststoffe_g, gesaettigt_g, wasser_ml, extra, fluessig,
       zuletzt_benutzt)
      VALUES (1, 'Prüfgrütze', 123.4, 5.6, NULL, 7.8, NULL,
              NULL, NULL, NULL, '{}', 0, '2099-03-01T06:30:00.000Z');
    INSERT INTO lebensmittel (id, name, kcal, fluessig)
      VALUES (2, 'Prüfsaft', 44.4, 1);
    INSERT INTO eintraege
      (tages_schluessel, mahlzeit, zeitpunkt, lebensmittel_id, name, menge_g,
       kcal, extra, health_stand)
      VALUES ('2099-03-01', 'fruehstueck', '2099-03-01T06:30:00.000Z', 1,
              'Prüfgrütze', 250, 308.5, '{}', 'offen');
  ''';

  QueryExecutor altstand(String schema, String inhalt, int version) =>
      NativeDatabase.memory(
        setup: (Database roh) {
          roh.execute(schema);
          roh.execute(inhalt);
          roh.execute('PRAGMA user_version = $version;');
        },
      );

  Future<int> abgelegteVersion(AppCache db) async {
    final zeile = await db.customSelect('PRAGMA user_version;').getSingle();
    return zeile.read<int>('user_version');
  }

  Future<
    Map<String, ({String typ, bool nullbar, String? vorgabe})>
  >
  spalten(AppCache db, String tabelle) async {
    final zeilen = await db.customSelect('PRAGMA table_info($tabelle);').get();
    return {
      for (final z in zeilen)
        z.read<String>('name'): (
          typ: z.read<String>('type').toUpperCase(),
          nullbar: z.read<int>('notnull') == 0,
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

  /// Prüft die Form der beiden neuen Spalten.
  Future<void> pruefeForm(AppCache db) async {
    final gefunden = await spalten(db, 'lebensmittel');

    expect(gefunden.keys, containsAll(['barcode', 'herkunft']));

    expect(gefunden['barcode']!.typ, 'TEXT');
    expect(
      gefunden['barcode']!.nullbar,
      isTrue,
      reason: 'ein selbst angelegtes Lebensmittel hat keinen Strichcode',
    );

    expect(gefunden['herkunft']!.typ, 'TEXT');
    expect(
      gefunden['herkunft']!.nullbar,
      isFalse,
      reason: 'jede Vorlage stammt von irgendwoher — eigen oder off',
    );
    expect(
      gefunden['herkunft']!.vorgabe,
      isNotNull,
      reason:
          'NOT NULL ohne Vorgabewert lässt sich nicht anhängen — SQLite '
          'lehnt ALTER TABLE … ADD COLUMN … NOT NULL ohne DEFAULT ab',
    );
  }

  // ---------------------------------------------------------------------

  group('Schema v14 — frisch angelegt', () {
    test('die Datenbank steht mindestens auf Version 14', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      expect(
        db.schemaVersion,
        greaterThanOrEqualTo(14),
        reason:
            'eine eigene Stufe, keine Erweiterung der v13-Stufe: Ein Gerät, '
            'das zwischen zwei Tickets aktualisiert wurde, muss den Rest '
            'nachholen können (#233)',
      );
      expect(await abgelegteVersion(db), db.schemaVersion);
    });

    test('lebensmittel bringt barcode und herkunft gleich mit', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      await pruefeForm(db);
    });

    test('ohne Angabe ist eine neue Zeile eigen und ohne Strichcode', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      await db.customStatement('INSERT INTO lebensmittel DEFAULT VALUES;');
      final zeile = (await zeilen(db, 'lebensmittel')).single;

      expect(zeile['herkunft'], 'eigen');
      expect(zeile['barcode'], isNull);
    });
  });

  group('Migration v13 → v14 — additiv, zwei Spalten an lebensmittel', () {
    QueryExecutor v13Cache() =>
        altstand('$restV13$lebensmittelV13', bestand, 13);

    test('die Datei steht danach auf der heutigen Version', () async {
      final db = AppCache(v13Cache());
      addTearDown(db.close);

      expect(await abgelegteVersion(db), db.schemaVersion);
      expect(await abgelegteVersion(db), greaterThanOrEqualTo(14));
    });

    test('lebensmittel trägt danach barcode und herkunft', () async {
      final db = AppCache(v13Cache());
      addTearDown(db.close);

      await pruefeForm(db);
    });

    test('alte Zeilen sind eigen, ohne Strichcode — und behalten jeden '
        'Wert', () async {
      final db = AppCache(v13Cache());
      addTearDown(db.close);

      final alle = await zeilen(db, 'lebensmittel');
      expect(
        alle,
        hasLength(2),
        reason: 'die Stufe legt keine Zeile an und nimmt keine weg',
      );

      final gruetze = alle[0];
      expect(gruetze['id'], 1);
      expect(
        gruetze['herkunft'],
        'eigen',
        reason:
            'vor v14 gab es keinen Weg aus Open Food Facts in die Tabelle — '
            'jede Zeile ist von Hand angelegt',
      );
      expect(
        gruetze['barcode'],
        isNull,
        reason: 'kein erfundener Strichcode',
      );
      expect(gruetze['name'], 'Prüfgrütze');
      expect(gruetze['kcal'], 123.4);
      expect(gruetze['eiweiss_g'], 5.6);
      expect(gruetze['kohlenhydrate_g'], isNull, reason: 'NULL bleibt NULL');
      expect(gruetze['fett_g'], 7.8);
      expect(gruetze['zuletzt_benutzt'], '2099-03-01T06:30:00.000Z');

      final saft = alle[1];
      expect(saft['id'], 2);
      expect(saft['herkunft'], 'eigen');
      expect(saft['barcode'], isNull);
      expect(saft['fluessig'], anyOf(1, true));
      expect(saft['zuletzt_benutzt'], isNull);
    });

    test('der gebuchte Eintrag zeigt weiter auf seine Vorlage', () async {
      final db = AppCache(v13Cache());
      addTearDown(db.close);

      final eintrag = (await zeilen(db, 'eintraege')).single;
      expect(eintrag['lebensmittel_id'], 1);
      expect(eintrag['name'], 'Prüfgrütze');
      expect(eintrag['kcal'], 308.5);
    });

    test('eine halb gelaufene Stufe (barcode schon da) wird vollständig', () async {
      final db = AppCache(
        altstand('$restV13$lebensmittelHalb', bestand, 13),
      );
      addTearDown(db.close);

      await pruefeForm(db);
      expect(await abgelegteVersion(db), db.schemaVersion);
      final alle = await zeilen(db, 'lebensmittel');
      expect(alle.map((z) => z['herkunft']), ['eigen', 'eigen']);
    });

    test('nach der Migration lassen sich beide Herkünfte schreiben', () async {
      final db = AppCache(v13Cache());
      addTearDown(db.close);

      await db.customStatement(
        "INSERT INTO lebensmittel (name, kcal, barcode, herkunft) "
        "VALUES ('Prüfhafer', 371, '0000000000017', 'off');",
      );
      final neu = (await zeilen(db, 'lebensmittel')).last;

      expect(neu['herkunft'], 'off');
      expect(neu['barcode'], '0000000000017');
    });
  });
}
