import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show Database, sqlite3;

import 'package:repit/data/cache.dart';

import 'schema_tabellen.dart';

/// Tests für **Schema v25**: die Sync-Felder an `lebensmittel` und
/// `rezepte` (#542, gebaut unter #543).
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden. Jede Migration
/// bekommt einen Test, dies ist der für die Stufe 25.
///
/// ## Woher die Anforderung kommt
///
/// Spec `docs/superpowers/specs/2026-11-03-ernaehrung-design.md`,
/// Abschnitt **„Sync-fähig von Anfang an (18.11.2026, #542)"**: Später
/// sollen eigene Produkte und Rezepte zwischen den drei Nutzer*innen
/// geteilt werden (Firebase, eigenes Ticket, bewusst **nicht** jetzt).
/// Damit das ein Anbau wird und kein Umbau, bekommen `lebensmittel` und
/// `rezepte` jetzt die Felder, die jeder Sync braucht: **UUID** neben der
/// Autoincrement-ID, **`geaendert_am`**, **Löschmarker** statt hartem
/// Löschen (sobald es Löschen gibt), **Autor/Quelle**. Alle neu, alle
/// nullbar oder mit Vorgabe — die Tabellenregel aus
/// `ernaehrung_tabellen.dart` gilt.
///
/// Dazu `CLAUDE.md`, Tests: „Eine Migration füllt alte Zeilen nicht mit
/// erfundenen Zeitstempeln — das behauptete, sie seien frisch."
///
/// Der Code der Stufe existierte beim Schreiben dieser Datei nicht.
/// Gelesen wurden Spec, `ernaehrung_tabellen.dart` (Kopf-Regeln),
/// `cache.dart` (Stufen, `_addColumnIfMissing`, `_reconcileSchema`) und
/// die bestehenden Migrationstests, nicht die spätere Implementierung.
///
/// ## Was diese Datei verbindlich vorgibt
///
/// **1. `AppCache.schemaVersion >= 25`** und eine eigene Stufe
/// `if (from < 25) { … }`. Geprüft mit `>=`, damit diese Datei bei der
/// nächsten Stufe nicht mitfällt (#208). Nach dem Öffnen eines Altstands
/// steht `user_version` auf `schemaVersion`.
///
/// **2. Fünf neue Spalten an `lebensmittel`**, alle TEXT, alle nullbar,
/// alle ohne Vorgabewert, keine im Schlüssel:
///
/// | Spalte | Trägt |
/// |---|---|
/// | `uuid` | die Sync-Identität neben der Autoincrement-ID |
/// | `geaendert_am` | wann zuletzt geändert (UTC, als Text) |
/// | `geloescht_am` | der Löschmarker statt hartem Löschen |
/// | `autor` | wer die Vorlage angelegt hat |
/// | `quelle_schluessel` | BLS-Code oder EAN der Seed-Herkunft |
///
/// **3. Vier neue Spalten an `rezepte`**, nach demselben Muster:
/// `uuid`, `geaendert_am`, `geloescht_am`, `autor`.
///
/// **4. Altzeilen bleiben unangetastet.** Kein erfundener Zeitstempel,
/// keine nachträglich vergebene UUID, kein erfundener Autor: In jeder
/// Bestandszeile stehen alle neuen Spalten auf `NULL`. `NULL` ist hier
/// keine Lücke, sondern die Wahrheit — vor v25 gab es keinen Sync, also
/// hat niemand eine UUID vergeben und niemand einen Änderungszeitpunkt
/// festgehalten.
///
/// **5. Additiv.** Jede Zeile und jeder Wert jeder Tabelle bleibt.
///
/// **6. Zweimal ausführbar** (#234/#240). Hat ein anderer Zweig die
/// Spalten unter derselben Bundle-ID schon angelegt — samt Werten darin —,
/// öffnet die Datei trotzdem, und die Werte bleiben.
///
/// **7. Abgleich** (#233). Eine Datei auf 25, der die Spalten fehlen,
/// bekommt sie beim Öffnen — leer.
///
/// **8. Frisch angelegt** hat der Cache die Spalten ebenfalls, in
/// derselben Form.
///
/// **9. Von weit unten:** Ein v11-Stand läuft durch alle Stufen. Dabei
/// legt die Stufe 12 `lebensmittel` und `rezepte` aus der **heutigen**
/// Definition an — mit den Sync-Spalten; die Stufe 25 darf daran nicht
/// mit `duplicate column name` sterben (`_addColumnIfMissing`, #234).
///
/// **10. Kein Index und keine `CHECK`-Bedingung** für die neuen Spalten —
/// `_reconcileSchema` kennt keine Indizes, und ein `UNIQUE` auf `uuid`
/// stünde sonst auf manchen Geräten und auf anderen nicht (dieselbe
/// Abwägung wie bei `lebensmittel.barcode`).
///
/// ## Festlegungen des Test-Agenten, nicht von Tim freigegeben
///
/// - **Nummer 25 und die genauen Spaltennamen** stammen aus dem Auftrag
///   zu #543 (gelesen aus `cache.dart` in diesem Zweig: `schemaVersion
///   => 24`, die nächste freie Nummer ist die 25). Die Spec nennt die
///   Felder, nicht die Schreibweise.
/// - **Der Dateiname** `migration_v25_test.dart` stammt aus demselben
///   Auftrag; die Reihe hieß bisher `schema_vNN_test.dart`.
/// - **Alle fünf bzw. vier Spalten nullbar und ohne Vorgabewert**, auch
///   `autor` und `quelle_schluessel`: Jeder Vorgabewert wäre eine
///   erfundene Angabe über Bestandszeilen — ein Vorgabe-Autor behauptete,
///   jede alte Vorlage stamme von ihm, und ein Vorgabe-`quelle_schluessel`
///   eine Seed-Herkunft, die es vor dem Seed nicht gab. Die Spec verlangt
///   nur „nullbar **oder** mit Vorgabe"; nullbar ohne Vorgabe ist die
///   einzige Wahl, die nichts erfindet.
/// - **Keine Spaltenmengen-Gleichheit, nur `containsAll`:** Eine spätere
///   Stufe darf weitere Spalten anhängen, ohne dass diese Datei mitfällt
///   (derselbe Grund wie `>=` bei der Version, #208).
/// - **Die Spalten sprechen über SQL**, nicht über die drift-Klassen —
///   die Datei übersetzt also auch, wenn es die Spalten im Code noch
///   nicht gibt, und meldet dann, *was* fehlt.
///
/// Nachbar von `schema_v13_test.dart` und `schema_v14_test.dart` (auch
/// dort trägt eine Stufe Spalten nach): derselbe Aufbau, von Hand gebaute
/// Altstände, **nicht** aus dem heutigen Code erzeugt
/// (`migration_test.dart`, Dateikopf). Der Stand v24 unten ist
/// `v23Schema` aus `schema_v24_test.dart`, dazu `umfaenge` so, wie
/// `schema_v24_test.dart` sie festlegt. `schema_tabellen.dart` braucht
/// kein Nachziehen: Die Stufe 25 legt keine Tabelle an.
///
/// **Alle Zahlen, Namen, UUIDs und Zeitpunkte hier sind erfunden.** Die
/// Zeitpunkte liegen im Jahr 2099; Tims echte Daten stehen nirgends im
/// Quelltext.
void main() {
  /// Die neuen Spalten — an einer Stelle, damit Form- und NULL-Prüfung
  /// sich darauf beziehen können.
  const neueSpaltenLebensmittel = {
    'uuid',
    'geaendert_am',
    'geloescht_am',
    'autor',
    'quelle_schluessel',
  };
  const neueSpaltenRezepte = {
    'uuid',
    'geaendert_am',
    'geloescht_am',
    'autor',
  };

  /// Die Spalten, die `lebensmittel` auf Stand v24 hat — wörtlich aus dem
  /// Altstand unten. Bestandszeilen werden Spalte für Spalte gegen genau
  /// diese Menge verglichen.
  const spaltenLebensmittelV24 = {
    'id',
    'name',
    'kcal',
    'eiweiss_g',
    'kohlenhydrate_g',
    'fett_g',
    'zucker_g',
    'ballaststoffe_g',
    'gesaettigt_g',
    'wasser_ml',
    'extra',
    'fluessig',
    'zuletzt_benutzt',
    'barcode',
    'herkunft',
    'portionen_abgefragt_am',
  };

  /// `rezepte` trägt auf Stand v24 nur ihren Schlüssel
  /// (`ernaehrung_tabellen.dart`: „`rezepte` und `rezept_zutaten` tragen
  /// vorerst nur ihren Schlüssel").
  const spaltenRezepteV24 = {'id'};

  // --- Altstände, von Hand -----------------------------------------------

  /// Stand v24: `v23Schema` aus `schema_v24_test.dart`, dazu `umfaenge`
  /// (Stufe 24) wie dort festgelegt.
  const v24Schema = '''
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
      herkunft TEXT NOT NULL DEFAULT 'eigen',
      portionen_abgefragt_am TEXT
    );
    CREATE TABLE portionen (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      lebensmittel_id INTEGER,
      name TEXT NOT NULL DEFAULT '',
      menge_g REAL,
      herkunft TEXT NOT NULL DEFAULT 'eigen'
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
      health_stand TEXT NOT NULL DEFAULT 'offen',
      vorschlag TEXT,
      portion_id INTEGER,
      portion_name TEXT,
      portion_g REAL,
      fluessig INTEGER
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
    CREATE TABLE kalorienziele (
      ab_tag TEXT NOT NULL PRIMARY KEY,
      kcal REAL NOT NULL,
      herkunft TEXT NOT NULL,
      grundumsatz_kcal REAL,
      aktiv_kcal REAL,
      koerperziel_kcal REAL
    );
    CREATE TABLE mahlzeit_aufteilungen (
      ab_tag TEXT NOT NULL PRIMARY KEY,
      fruehstueck_pct INTEGER,
      mittag_pct INTEGER,
      abend_pct INTEGER
    );
    CREATE TABLE ereignisse (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      art TEXT NOT NULL,
      von TEXT NOT NULL,
      bis TEXT NOT NULL,
      notiz TEXT,
      angelegt TEXT NOT NULL,
      geaendert TEXT
    );
    CREATE TABLE wach_belege (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      zeitpunkt TEXT NOT NULL,
      art TEXT NOT NULL
    );
    CREATE TABLE gym_sitzungen (
      id TEXT NOT NULL,
      tag TEXT NOT NULL,
      zeitpunkt TEXT NOT NULL,
      workout TEXT NULL,
      minuten INTEGER NULL,
      notiz TEXT NULL,
      health_uuid TEXT NULL,
      aufwaermen_art TEXT NULL CHECK (aufwaermen_art IS NULL OR aufwaermen_art IN ('bike', 'treadmill', 'rowing', 'cross_trainer', 'jump_rope', 'mobility')),
      aufwaermen_minuten INTEGER NULL,
      aufwaermen_km REAL NULL,
      aufwaermen_uebersprungen INTEGER NOT NULL DEFAULT 0 CHECK (aufwaermen_uebersprungen IN (0, 1)),
      aufwaermen_health_uuid TEXT NULL,
      PRIMARY KEY (id),
      UNIQUE (tag, workout)
    );
    CREATE TABLE gym_saetze (
      sitzung_id TEXT NOT NULL,
      uebung_id TEXT NOT NULL,
      uebung_pos INTEGER NOT NULL,
      satz_nr INTEGER NOT NULL,
      gewicht_kg REAL NOT NULL,
      wdh INTEGER NOT NULL,
      zeitpunkt TEXT NULL,
      PRIMARY KEY (sitzung_id, uebung_id, satz_nr)
    );
    CREATE TABLE gym_entwuerfe (
      id INTEGER NOT NULL DEFAULT 0 CHECK (id = 0),
      workout TEXT NOT NULL,
      sitzung_id TEXT NOT NULL,
      zeitpunkt TEXT NOT NULL,
      dauer TEXT NULL,
      notiz TEXT NULL,
      gespeichert_am TEXT NOT NULL,
      felder TEXT NOT NULL,
      PRIMARY KEY (id)
    );
    CREATE TABLE umfaenge (
      tag TEXT NOT NULL,
      mass TEXT NOT NULL,
      zentimeter REAL NOT NULL,
      eingetragen_am TEXT NOT NULL,
      quelle TEXT NOT NULL,
      PRIMARY KEY (tag, mass, quelle)
    );
  ''';

  /// Tims Bestand auf Stand v24 — der aus `schema_v24_test.dart`, dazu
  /// eine zweite Vorlage (aus Open Food Facts, mit Barcode), zwei Rezepte
  /// und eine Messung. Eine Migration, die hier etwas verlöre, verlöre es
  /// endgültig. In `lebensmittel` und `rezepte` stehen die Zeilen, an
  /// denen die Stufe 25 vorbei muss, ohne sie anzufassen.
  const bestand = '''
    INSERT INTO tages_werte (tag, schritte, ruhepuls_bpm, gelesen_am,
                             gewicht_kg)
      VALUES ('2099-03-01', 4321, 55, '2099-03-01T08:00:00.000Z', 81.3);
    INSERT INTO stammdaten (id, groesse_cm, geburtsjahr, zielgewicht_kg,
                            zieldatum)
      VALUES (0, 123, 2001, 84.5, '2099-09-30');
    INSERT INTO lebensmittel (id, name, kcal, fluessig, herkunft,
                              portionen_abgefragt_am)
      VALUES (1, 'Prüfknäcke', 377.7, 0, 'eigen',
              '2099-03-01T10:20:30.000Z');
    INSERT INTO lebensmittel (id, name, kcal, fluessig, barcode, herkunft,
                              zuletzt_benutzt)
      VALUES (2, 'Prüfriegel', 499.9, 0, '4099999999990', 'off',
              '2099-03-01T12:00:00.000Z');
    INSERT INTO portionen (id, lebensmittel_id, name, menge_g, herkunft)
      VALUES (5, 1, 'Prüfbon', 5.9, 'eigen');
    INSERT INTO eintraege
      (id, tages_schluessel, mahlzeit, zeitpunkt, lebensmittel_id, name,
       menge_g, kcal, extra, health_uuid, health_stand, portion_id,
       portion_name, portion_g, fluessig)
      VALUES (1, '2099-03-01', 'fruehstueck', '2099-03-01T07:15:00.000Z', 1,
              'Prüfknäcke', 11.8, 44.6, '{}', 'PRUEF-UUID-0023',
              'geschrieben', 5, 'Prüfbon', 5.9, 0);
    INSERT INTO rezepte (id) VALUES (3);
    INSERT INTO rezepte (id) VALUES (7);
    INSERT INTO rezept_zutaten (id) VALUES (9);
    INSERT INTO kalorienziele
      (ab_tag, kcal, herkunft, grundumsatz_kcal, aktiv_kcal,
       koerperziel_kcal)
      VALUES ('2099-02-20', 2617.25, 'berechnet', 1750.5, 700.2, 166.55);
    INSERT INTO mahlzeit_aufteilungen
      (ab_tag, fruehstueck_pct, mittag_pct, abend_pct)
      VALUES ('2099-02-25', 20, 40, 25);
    INSERT INTO ki_einstellungen (id, modell, limit_usd, preise)
      VALUES (0, 'pruef-modell-x', 3.5, '{}');
    INSERT INTO wasser_eintraege
      (id, tages_schluessel, zeitpunkt, menge_ml, health_stand)
      VALUES (4, '2099-03-01', '2099-03-01T09:15:00.000Z', 333.5, 'offen');
    INSERT INTO ereignisse (id, art, von, bis, notiz, angelegt, geaendert)
      VALUES (1, 'op', '2099-03-02', '2099-03-16', 'Prüfnotiz',
              '2099-02-20T08:00:00.000Z', '2099-02-21T09:30:00.000Z');
    INSERT INTO wach_belege (id, zeitpunkt, art)
      VALUES (1, '2099-03-01T23:40:00.000Z', 'oeffnen');
    INSERT INTO umfaenge (tag, mass, zentimeter, eingetragen_am, quelle)
      VALUES ('2099-03-01', 'pruefmassA', 41.4, '2099-03-01T07:05:00.000Z',
              'getippt');
  ''';

  /// Die Sync-Spalten, wie ein anderer Zweig sie unter derselben Bundle-ID
  /// schon angelegt haben könnte — genau der `ALTER TABLE`-Weg, den auch
  /// eine Stufe nimmt (#234/#240).
  const syncSpaltenVorweg = '''
    ALTER TABLE lebensmittel ADD COLUMN uuid TEXT;
    ALTER TABLE lebensmittel ADD COLUMN geaendert_am TEXT;
    ALTER TABLE lebensmittel ADD COLUMN geloescht_am TEXT;
    ALTER TABLE lebensmittel ADD COLUMN autor TEXT;
    ALTER TABLE lebensmittel ADD COLUMN quelle_schluessel TEXT;
    ALTER TABLE rezepte ADD COLUMN uuid TEXT;
    ALTER TABLE rezepte ADD COLUMN geaendert_am TEXT;
    ALTER TABLE rezepte ADD COLUMN geloescht_am TEXT;
    ALTER TABLE rezepte ADD COLUMN autor TEXT;
  ''';

  /// Werte darin, die der andere Zweig schon geschrieben hat. Alle drei
  /// muss die Stufe stehen lassen — auch den Löschmarker: Eine Stufe, die
  /// ihn leerte, machte eine gelöschte Vorlage wieder lebendig.
  const syncWerteVorweg = '''
    UPDATE lebensmittel SET uuid = 'PRUEF-UUID-L0001',
      geaendert_am = '2099-03-05T08:00:00.000Z', autor = 'pruefautor',
      quelle_schluessel = 'PRUEFBLS-B100000' WHERE id = 1;
    UPDATE lebensmittel SET uuid = 'PRUEF-UUID-L0002',
      geloescht_am = '2099-03-06T09:30:00.000Z' WHERE id = 2;
    UPDATE rezepte SET uuid = 'PRUEF-UUID-R0003',
      geaendert_am = '2099-03-05T10:00:00.000Z', autor = 'pruefautor'
      WHERE id = 3;
  ''';

  /// Schema v11, wörtlich aus `schema_v24_test.dart`: acht Tabellen, noch
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

  const v11Bestand = '''
    INSERT INTO tages_werte (tag, schritte, ruhepuls_bpm, gelesen_am)
      VALUES ('2099-03-01', 4242, 99, '2099-03-01T09:00:00.000Z');
    INSERT INTO stammdaten (id, groesse_cm, geburtsjahr, zielgewicht_kg,
                            zieldatum)
      VALUES (0, 211, 1904, 33.3, '2099-12-31');
  ''';

  /// Die Tabellen, deren Zeilen die Stufe nicht anrühren darf —
  /// einschließlich der beiden, die sie erweitert.
  const alle = [
    'tages_werte',
    'stammdaten',
    'lebensmittel',
    'portionen',
    'eintraege',
    'rezepte',
    'rezept_zutaten',
    'kalorienziele',
    'mahlzeit_aufteilungen',
    'ki_einstellungen',
    'wasser_eintraege',
    'ereignisse',
    'wach_belege',
    'umfaenge',
  ];

  // --- Hilfsmittel, wie in `schema_v24_test.dart` ------------------------

  Database rohdatei(String schema, String inhalt, int version) {
    final roh = sqlite3.openInMemory();
    roh.execute(schema);
    if (inhalt.isNotEmpty) roh.execute(inhalt);
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
    Map<String, ({String typ, bool nullbar, int schluesselNr, String? vorgabe})>
  >
  spalten(AppCache db, String tabelle) async {
    final zeilen = await db.customSelect('PRAGMA table_info($tabelle);').get();
    return {
      for (final z in zeilen)
        z.read<String>('name'): (
          typ: z.read<String>('type').toUpperCase(),
          nullbar: z.read<int>('notnull') == 0,
          schluesselNr: z.read<int>('pk'),
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

  /// Die Form der Sync-Spalten einer Tabelle: alle da, alle TEXT, alle
  /// nullbar, keine mit Vorgabewert, keine im Schlüssel — und kein
  /// eigener Index, keine `CHECK`-Bedingung über sie.
  Future<void> pruefeForm(
    AppCache db,
    String tabelle,
    Set<String> neue,
    Set<String> alt,
  ) async {
    final s = await spalten(db, tabelle);
    expect(
      s.keys.toSet(),
      containsAll(neue),
      reason:
          '$tabelle trägt die Sync-Felder aus der Spec („Sync-fähig von '
          'Anfang an", #542): UUID neben der Autoincrement-ID, '
          'geaendert_am, Löschmarker, Autor/Quelle',
    );
    expect(
      s.keys.toSet(),
      containsAll(alt),
      reason:
          '$tabelle behält jede Spalte, die sie auf v24 hatte — die Stufe '
          'hängt an, sie baut nicht um',
    );

    for (final n in neue) {
      expect(
        s[n]!.typ,
        'TEXT',
        reason:
            '$tabelle.$n ist TEXT: UUID, Autor und Quellschlüssel sind '
            'Wörter, und Zeitstempel liegen in der Datenbank als Text '
            '(storeDateTimeAsText) — drifts Standard (Unix-Sekunden) gäbe '
            'sie als lokale Zeit zurück (CLAUDE.md)',
      );
      expect(
        s[n]!.nullbar,
        isTrue,
        reason:
            '$tabelle.$n ist nullbar: Die Tabellenregel aus '
            'ernaehrung_tabellen.dart — SQLite lehnt ADD COLUMN … NOT NULL '
            'ohne Vorgabewert ab, und genau diesen Weg nehmen Stufe und '
            '_reconcileSchema',
      );
      expect(
        s[n]!.vorgabe,
        isNull,
        reason:
            '$tabelle.$n hat keinen Vorgabewert: Eine Vorgabe an '
            'geaendert_am erfände einen Änderungszeitpunkt, eine an uuid '
            'wäre dieselbe UUID in jeder Zeile, eine an autor behauptete '
            'einen Urheber, und eine an geloescht_am löschte alles — es '
            'gibt für keines der Felder einen ehrlichen Vorgabewert',
      );
      expect(
        s[n]!.schluesselNr,
        0,
        reason:
            '$tabelle.$n gehört nicht in den Schlüssel: Der bleibt die '
            'Autoincrement-ID, die UUID kommt daneben (Spec: „UUID neben '
            'der Autoincrement-ID")',
      );
    }

    final sql =
        (await db
                .customSelect(
                  "SELECT sql FROM sqlite_master WHERE type = 'table' "
                  "AND name = '$tabelle';",
                )
                .getSingle())
            .read<String>('sql');
    for (final n in neue) {
      expect(
        RegExp('$n[^,)]*(UNIQUE|CHECK)', caseSensitive: false).hasMatch(sql),
        isFalse,
        reason:
            '$tabelle.$n ohne UNIQUE und ohne CHECK: Ein UNIQUE auf uuid '
            'ließe sich über _reconcileSchema nicht nachziehen und stünde '
            'auf manchen Geräten und auf anderen nicht — dieselbe Abwägung '
            'wie bei lebensmittel.barcode',
      );
    }

    final indizes = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index' "
          "AND tbl_name = '$tabelle' AND sql IS NOT NULL;",
        )
        .get();
    expect(
      indizes,
      isEmpty,
      reason:
          'kein eigener Index auf $tabelle — _reconcileSchema kennt keine. '
          'Der automatische Index hinter dem Primärschlüssel (sql IS NULL) '
          'zählt nicht',
    );
  }

  /// Jede Bestandszeile trägt in jeder Sync-Spalte `NULL` — keine
  /// erfundene UUID, kein erfundener Zeitstempel, kein erfundener Autor.
  Future<void> pruefeNull(AppCache db, String tabelle, Set<String> neue) async {
    final bestandszeilen = await zeilen(db, tabelle);
    expect(
      bestandszeilen,
      isNotEmpty,
      reason: 'Vorbedingung: $tabelle hat Bestandszeilen',
    );
    for (var i = 0; i < bestandszeilen.length; i++) {
      for (final n in neue) {
        expect(
          bestandszeilen[i][n],
          isNull,
          reason:
              '$tabelle, Zeile ${i + 1}, Spalte $n: eine Migration füllt '
              'alte Zeilen nicht mit erfundenen Zeitstempeln (CLAUDE.md) — '
              'und eine nachträglich vergebene UUID oder ein nachgetragener '
              'Autor wäre derselbe Fehler, eine Spalte weiter. Vor v25 gab '
              'es keinen Sync; NULL ist die Wahrheit über diese Zeilen',
        );
      }
    }
  }

  // ═════════════════════════════════════════════════════════════════════

  group('Vorbedingungen: die Altstände sind so gebaut, wie sie gemeint '
      'sind', () {
    test('v24 hat alle heutigen Tabellen, aber keine der Sync-Spalten', () {
      final roh = rohdatei(v24Schema, bestand, 24);
      addTearDown(roh.close);
      final namen = {
        for (final z in roh.select(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name NOT LIKE 'sqlite_%';",
        ))
          z['name'] as String,
      };
      expect(
        namen,
        tabellenHeute.difference(
          {...tabellenAusStufe26, ...tabellenAusStufe27},
        ),
        reason:
            'die Stufe 25 legt keine Tabelle an — v24 hat schon alle '
            'heutigen außer denen der Stufen 26 und 27 (die 27 kam beim '
            'Zusammenführen der beiden `main`-Stände am 24.11.2026 '
            'dazu). Die drei Zyklus-Tabellen '
            'kamen am 24.11.2026 beim Zusammenführen dazu (#592 unter '
            '#539); ihre Stufe war im eigenen Zweig die 25 und ist nach '
            'oben gerückt, weil `main` die 25 schon vergeben hatte. '
            'Nachgezogen mit `TEST_AENDERN=1`, **Tim hat die Änderung '
            'nicht gesehen**.',
      );

      Set<String> rohSpalten(String tabelle) => {
        for (final z in roh.select('PRAGMA table_info($tabelle);'))
          z['name'] as String,
      };
      expect(rohSpalten('lebensmittel'), spaltenLebensmittelV24);
      expect(rohSpalten('rezepte'), spaltenRezepteV24);
      expect(rohZeilen(roh, 'lebensmittel'), hasLength(2));
      expect(rohZeilen(roh, 'rezepte'), hasLength(2));
    });

    test('v24 vorweg trägt die Sync-Spalten schon, mit Werten darin', () {
      final roh = rohdatei(
        v24Schema + syncSpaltenVorweg,
        bestand + syncWerteVorweg,
        24,
      );
      addTearDown(roh.close);
      final vorlagen = rohZeilen(roh, 'lebensmittel');
      expect(vorlagen[0]['uuid'], 'PRUEF-UUID-L0001');
      expect(vorlagen[1]['geloescht_am'], '2099-03-06T09:30:00.000Z');
      expect(rohZeilen(roh, 'rezepte')[0]['uuid'], 'PRUEF-UUID-R0003');
    });
  });

  group('Schema v25 (#542/#543) — frisch angelegt', () {
    test('die Version ist mindestens 25 und steht so in der Datei', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      expect(db.schemaVersion, greaterThanOrEqualTo(25));
      expect(await abgelegteVersion(db), db.schemaVersion);
    });

    test('ein frischer Cache hat die Sync-Spalten, in der verlangten Form, '
        'und keine Tabelle mehr als vorher', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      expect(
        await tabellen(db),
        tabellenHeute,
        reason:
            'die Stufe 25 hängt Spalten an, sie legt keine Tabelle an — '
            'schema_tabellen.dart bleibt, wie es ist',
      );
      await pruefeForm(db, 'lebensmittel', neueSpaltenLebensmittel,
          spaltenLebensmittelV24);
      await pruefeForm(db, 'rezepte', neueSpaltenRezepte, spaltenRezepteV24);
      expect(
        await zeilen(db, 'lebensmittel'),
        isEmpty,
        reason: 'das Anlegen des Caches ist kein Eintrag',
      );
      expect(await zeilen(db, 'rezepte'), isEmpty);
    });
  });

  group('Migration v24 → heute', () {
    test('hängt die Spalten an, in der verlangten Form, und die Datei steht '
        'danach auf der heutigen Version', () async {
      final roh = rohdatei(v24Schema, bestand, 24);
      addTearDown(roh.close);
      final db = ueber(roh);
      addTearDown(db.close);

      expect(await abgelegteVersion(db), db.schemaVersion);
      expect(
        await abgelegteVersion(db),
        greaterThanOrEqualTo(25),
        reason: 'die Stufe 25 ist über diesen Bestand gelaufen',
      );
      expect(await tabellen(db), tabellenHeute);
      await pruefeForm(db, 'lebensmittel', neueSpaltenLebensmittel,
          spaltenLebensmittelV24);
      await pruefeForm(db, 'rezepte', neueSpaltenRezepte, spaltenRezepteV24);
    });

    test('füllt nichts — in jeder Bestandszeile stehen alle Sync-Spalten '
        'auf NULL', () async {
      final roh = rohdatei(v24Schema, bestand, 24);
      addTearDown(roh.close);
      final db = ueber(roh);
      addTearDown(db.close);

      await pruefeNull(db, 'lebensmittel', neueSpaltenLebensmittel);
      await pruefeNull(db, 'rezepte', neueSpaltenRezepte);
    });

    test('additiv: jede Zeile und jeder Wert bleibt, in allen Tabellen — '
        'Bestandszeilen zeilengleich unverändert', () async {
      final roh = rohdatei(v24Schema, bestand, 24);
      addTearDown(roh.close);
      final vorher = {for (final t in alle) t: rohZeilen(roh, t)};

      final db = ueber(roh);
      addTearDown(db.close);

      expect(
        await abgelegteVersion(db),
        greaterThanOrEqualTo(25),
        reason: 'die Stufe 25 ist über diesen Bestand gelaufen',
      );
      for (final t in alle) {
        pruefeUnveraendert(vorher[t]!, await zeilen(db, t), t);
      }
    });

    test('ein zweites Öffnen derselben Datei ändert am Schema nichts mehr, '
        'und inzwischen vergebene Sync-Werte bleiben', () async {
      final roh = rohdatei(v24Schema, bestand, 24);
      addTearDown(roh.close);

      final erstes = ueber(roh);
      await erstes.customStatement(
        "UPDATE lebensmittel SET uuid = 'PRUEF-UUID-L0001', "
        "geaendert_am = '2099-03-05T08:00:00.000Z' WHERE id = 1;",
      );
      await erstes.close();
      final nachErstem = schemaZaehler(roh);
      final vorlagenNachErstem = rohZeilen(roh, 'lebensmittel');

      final zweites = ueber(roh);
      addTearDown(zweites.close);
      await zweites.customSelect('SELECT 1;').get();

      expect(
        schemaZaehler(roh),
        nachErstem,
        reason:
            'PRAGMA schema_version steigt bei jedem CREATE, ALTER und DROP. '
            'Steigt er beim zweiten Öffnen, hängt die Stufe oder der '
            'Abgleich bei jedem Start etwas neu an',
      );
      pruefeUnveraendert(
        vorlagenNachErstem,
        await zeilen(zweites, 'lebensmittel'),
        'lebensmittel',
      );
    });
  });

  group('Die Stufe ist zweimal ausführbar (#234/#240)', () {
    test('stehen die Spalten schon da, öffnet die Datei, und jeder Wert '
        'darin bleibt — auch der Löschmarker', () async {
      final roh = rohdatei(
        v24Schema + syncSpaltenVorweg,
        bestand + syncWerteVorweg,
        24,
      );
      addTearDown(roh.close);
      final vorher = {for (final t in alle) t: rohZeilen(roh, t)};

      final db = ueber(roh);
      addTearDown(db.close);

      expect(await abgelegteVersion(db), db.schemaVersion);
      expect(
        await abgelegteVersion(db),
        greaterThanOrEqualTo(25),
        reason:
            'die Stufe 25 lief über eine Datei, die ihre Spalten schon '
            'trug, und scheiterte nicht an „duplicate column name". Alle '
            'Zweige bauen unter derselben Bundle-ID und benutzen dieselbe '
            'Datei — das ist _addColumnIfMissing, je Spalte, nicht je Stufe',
      );
      for (final MapEntry(key: t, value: z) in vorher.entries) {
        pruefeUnveraendert(z, await zeilen(db, t), t);
      }
      final vorlagen = await zeilen(db, 'lebensmittel');
      expect(
        vorlagen[1]['geloescht_am'],
        '2099-03-06T09:30:00.000Z',
        reason:
            'eine Stufe, die den Löschmarker leerte, machte eine gelöschte '
            'Vorlage wieder lebendig — ein vorhandener Wert ist ein Wert',
      );
    });
  });

  group('Abgleich beim Öffnen (#233)', () {
    test('eine Datei auf 25, der die Spalten fehlen, bekommt sie — leer, '
        'und verliert nichts', () async {
      // Ein Zweig hat die Nummer hochgezogen, bevor seine Stufe fertig
      // war: `if (from < 25)` läuft dann nie.
      final roh = rohdatei(v24Schema, bestand, 25);
      addTearDown(roh.close);
      final vorher = {for (final t in alle) t: rohZeilen(roh, t)};

      final db = ueber(roh);
      addTearDown(db.close);
      // Der erste Zugriff: Das Öffnen selbst ist bei drift lazy.
      await db.customSelect('SELECT 1;').get();

      final s = await spalten(db, 'lebensmittel');
      expect(
        s.keys.toSet(),
        containsAll(neueSpaltenLebensmittel),
        reason:
            'onUpgrade läuft bei from == 25 nicht in die Stufe 25 — die '
            'Spalten kommen nur über den Abgleich',
      );
      await pruefeForm(db, 'lebensmittel', neueSpaltenLebensmittel,
          spaltenLebensmittelV24);
      await pruefeForm(db, 'rezepte', neueSpaltenRezepte, spaltenRezepteV24);
      await pruefeNull(db, 'lebensmittel', neueSpaltenLebensmittel);
      await pruefeNull(db, 'rezepte', neueSpaltenRezepte);
      for (final t in alle) {
        pruefeUnveraendert(vorher[t]!, await zeilen(db, t), t);
      }
    });
  });

  group('Von weit unten: v11 → heute', () {
    test('ein v11-Stand öffnet ohne Fehler — die Stufe 12 legt beide '
        'Tabellen aus der heutigen Definition an, und die Stufe 25 stirbt '
        'daran nicht', () async {
      final roh = rohdatei(v11Schema, v11Bestand, 11);
      addTearDown(roh.close);
      final vorher = {
        for (final t in ['tages_werte', 'stammdaten']) t: rohZeilen(roh, t),
      };

      final db = ueber(roh);
      addTearDown(db.close);

      // Scheiterte eine Stufe — etwa an `duplicate column name`, weil
      // createTable der Stufe 12 die Sync-Spalten schon mitbringt —,
      // würfe schon dieser erste Zugriff.
      expect(await abgelegteVersion(db), db.schemaVersion);
      expect(await tabellen(db), tabellenHeute);
      await pruefeForm(db, 'lebensmittel', neueSpaltenLebensmittel,
          spaltenLebensmittelV24);
      await pruefeForm(db, 'rezepte', neueSpaltenRezepte, spaltenRezepteV24);
      expect(await zeilen(db, 'lebensmittel'), isEmpty);
      expect(await zeilen(db, 'rezepte'), isEmpty);
      for (final MapEntry(key: t, value: z) in vorher.entries) {
        pruefeUnveraendert(z, await zeilen(db, t), t);
      }
    });
  });

  group('Die Sync-Spalten nehmen Werte an und geben sie unverändert '
      'zurück', () {
    test('uuid, geaendert_am, geloescht_am, autor und quelle_schluessel '
        'lassen sich schreiben und lesen', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      await db.customStatement(
        'INSERT INTO lebensmittel (name, uuid, geaendert_am, geloescht_am, '
        "autor, quelle_schluessel) VALUES ('Prüfknäcke', "
        "'PRUEF-UUID-L0001', '2099-03-05T08:00:00.000Z', "
        "'2099-03-06T09:30:00.000Z', 'pruefautor', '4099999999990');",
      );
      await db.customStatement(
        'INSERT INTO rezepte (uuid, geaendert_am, autor) VALUES '
        "('PRUEF-UUID-R0003', '2099-03-05T10:00:00.000Z', 'pruefautor');",
      );

      final vorlage = (await zeilen(db, 'lebensmittel')).single;
      expect(vorlage['uuid'], 'PRUEF-UUID-L0001');
      expect(vorlage['geaendert_am'], '2099-03-05T08:00:00.000Z');
      expect(vorlage['geloescht_am'], '2099-03-06T09:30:00.000Z');
      expect(vorlage['autor'], 'pruefautor');
      expect(
        vorlage['quelle_schluessel'],
        '4099999999990',
        reason:
            'quelle_schluessel trägt den BLS-Code oder die EAN der '
            'Seed-Herkunft — als Text, denn beides sind Wörter mit '
            'führenden Zeichen, keine Zahlen',
      );

      final rezept = (await zeilen(db, 'rezepte')).single;
      expect(rezept['uuid'], 'PRUEF-UUID-R0003');
      expect(rezept['geaendert_am'], '2099-03-05T10:00:00.000Z');
      expect(
        rezept['geloescht_am'],
        isNull,
        reason: 'nicht gelöscht heißt NULL, nicht ein Platzhaltertext',
      );
      expect(rezept['autor'], 'pruefautor');
    });

    test('eine Zeile ganz ohne Sync-Werte bleibt erlaubt — Buchen ohne '
        'Sync funktioniert weiter', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      await db.customStatement(
        "INSERT INTO lebensmittel (name, kcal) VALUES ('Prüfknäcke', 377.7);",
      );
      await db.customStatement('INSERT INTO rezepte (id) VALUES (1);');

      final vorlage = (await zeilen(db, 'lebensmittel')).single;
      for (final n in neueSpaltenLebensmittel) {
        expect(
          vorlage[n],
          isNull,
          reason:
              'lebensmittel.$n ist nullbar: Der Sync kommt später '
              '(Firebase, eigenes Ticket), und bis dahin — und für alles, '
              'was nie synchronisiert wird — ist NULL der ehrliche Stand',
        );
      }
      final rezept = (await zeilen(db, 'rezepte')).single;
      for (final n in neueSpaltenRezepte) {
        expect(rezept[n], isNull);
      }
    });
  });
}
