import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show Database, sqlite3;

import 'package:repit/data/cache.dart';

import 'schema_tabellen.dart';

/// Tests für **Schema v26**: die drei Tabellen des Zykluskalenders —
/// `zyklus_eintraege` (ein Tageseintrag je Kalendertag),
/// `zyklus_health_spiegel` (je geschriebenem HealthKit-Sample eine Zeile)
/// und `zyklus_einstellungen` (die eine Einstellungszeile). Bereich #539,
/// Stufe 3 des Umsetzungsplans.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden. Hält der
/// Implementierende einen Fall für falsch, **meldet** er ihn, statt ihn
/// passend zu machen. Jede Migration bekommt einen Test, dies ist der für
/// die Stufe 26.
///
/// ## Woher die Anforderung kommt
///
/// Spec `docs/superpowers/specs/2026-11-23-zyklus-spec.md`, **Abschnitt 4
/// (Datenmodell)** — dort stehen die Spalten von `zyklus_eintraege` (4.1)
/// und `zyklus_health_spiegel` (4.2), die Felder der Einstellungen (4.3)
/// und der Satz, der diese Stufe trägt (4.4):
///
/// > „Neue Schemaversion. **Die Migration bekommt einen Test**, wie jede
/// > Migration: Eine Datenbank der vorigen Version wird angelegt,
/// > migriert, und danach muss sie die neuen Tabellen haben, ohne dass
/// > bestehende Daten verloren gehen. Alte Zeilen bekommen keine
/// > erfundenen Zeitstempel."
///
/// Dazu `docs/superpowers/plans/2026-11-23-zyklus-umsetzung.md`, Stufe 3:
/// Zeitstempel als Text, Tagesschlüssel als ISO-String, **Filterung in
/// SQL**.
///
/// Der Code der Stufe existierte beim Schreiben dieser Datei nicht.
/// Gelesen wurden Spec, Plan und die bestehenden Migrationstests, nicht
/// die spätere Implementierung. Diese Datei spricht die Tabellen deshalb
/// **nur über SQL** an, nicht über die drift-Klassen: Sie übersetzt also
/// auch dann, wenn es die Tabellen im Code noch nicht gibt, und meldet
/// dann, *was* fehlt, statt nur, dass sie nicht baut.
///
/// ## Warum die 25
///
/// Am 23.11.2026 in diesem Zweig nachgesehen: `AppCache.schemaVersion
/// => 24` (#476, `umfaenge`). Die nächste freie Nummer ist die 25. Eine
/// Versionsnummer sagt nicht, welches Ticket zuerst fertig war, sondern
/// **was ein Gerät schon ausgeführt hat** — deshalb wird sie gelesen und
/// um eins erhöht, nie verschoben.
///
/// Aufbau wie `schema_v24_test.dart` und `schema_v23_test.dart`: von Hand
/// gebaute Altstände, **nicht** aus dem heutigen Code erzeugt
/// (`migration_test.dart`, Dateikopf).
///
/// ## Was diese Datei verbindlich vorgibt
///
/// **1. `AppCache.schemaVersion >= 25`** und eine **eigene Stufe**
/// `if (from < 26) { … }`. Geprüft mit `>=`, damit diese Datei bei der
/// nächsten Stufe nicht mitfällt (#208). Nach dem Öffnen eines Altstands
/// steht `user_version` auf `schemaVersion`.
///
/// **2. Drei neue Tabellen.** `zyklus_eintraege` nach Spec 4.1:
///
/// | Spalte | Typ | NULL | Vorgabe |
/// |---|---|---|---|
/// | `tag` | TEXT, Primärschlüssel | nein | — |
/// | `blutung` | TEXT | ja | — |
/// | `zwischenblutung` | INTEGER (Bool) | nein | `0` |
/// | `schmerz` | TEXT | ja | — |
/// | `symptome` | TEXT | nein | `''` |
/// | `sex` | INTEGER (Bool) | nein | `0` |
/// | `verhuetet` | INTEGER (Bool) | ja | — |
/// | `test` | TEXT | ja | — |
/// | `notiz` | TEXT | ja | — |
/// | `quelle` | TEXT | nein | `'eigen'` |
/// | `geaendert` | TEXT (DateTime, UTC) | nein | **keine** |
///
/// `zyklus_health_spiegel` nach Spec 4.2: `uuid` (TEXT,
/// Primärschlüssel), `tag` (TEXT), `typ` (TEXT), alle drei Pflicht.
///
/// `zyklus_einstellungen` nach Spec 4.3: `id` (INTEGER,
/// Primärschlüssel), `kalender_an`, `sicht`, `verhuetung_an`,
/// `verhuetung_seit` (nullbar), `verhuetung_art` (nullbar),
/// `import_gelaufen`, `vorhersage_pausiert`.
///
/// **3. Additiv, ohne eine einzige Zeile.** Die Stufe legt weder einen
/// Tageseintrag noch eine Spiegelzeile noch die Einstellungszeile an.
/// Alle übrigen Tabellen behalten jede Zeile und jeden Wert.
///
/// **4. Zweimal ausführbar** (#234/#240). Stehen die Tabellen schon in
/// einer Datei mit `user_version = 24`, öffnet sie trotzdem, und die
/// Zeilen darin bleiben.
///
/// **5. Abgleich** (#233). Eine Datei auf 25, der die Tabellen fehlen,
/// bekommt sie beim Öffnen, leer.
///
/// **6. Von weit unten:** Ein v11-Stand läuft durch alle Stufen.
///
/// **7. `geaendert` kommt als UTC zurück und ist gleich sich selbst**
/// (`CLAUDE.md`, „Zeitstempel liegen in der Datenbank als Text").
///
/// **8. `tag` ist ein ISO-Tagesstring und wird in SQL verglichen** —
/// `WHERE tag >= ? AND tag <= ?` liefert lexikografisch das richtige
/// Fenster, `ORDER BY tag` sortiert chronologisch.
///
/// ## Festlegungen des Test-Agenten, nicht von Tim freigegeben
///
/// Was folgt, steht so weder in der Spec noch im Plan. Es hat der
/// Test-Agent beim Schreiben dieser Datei festgelegt; Tim hat es nicht
/// gesehen.
///
/// - **Die Tabellennamen `zyklus_eintraege` und `zyklus_health_spiegel`**
///   stehen in Spec 4.1 und 4.2. **`zyklus_einstellungen` nicht** — Spec
///   4.3 nennt nur die Felder und keinen Ort. Diese Datei legt eine
///   eigene Tabelle mit genau einer Zeile fest, wie `stammdaten`,
///   `ziel_werte` und `ki_einstellungen` es halten: Einstellungen sind
///   kein Verlauf, eine zweite Zeile wäre ein zweiter, widersprechender
///   Stand.
/// - **Die Spaltennamen in `snake_case`** (`kalender_an`,
///   `verhuetung_seit`, `import_gelaufen`, `vorhersage_pausiert`) — die
///   Spec schreibt sie in Dart-Schreibweise, die Tabellen dieses
///   Repositorys stehen durchgehend in `snake_case`.
/// - **Keine `CHECK`-Bedingung auf `blutung`, `schmerz`, `test`,
///   `quelle`, `sicht` und `verhuetung_art`.** Dieselbe Überlegung wie
///   bei `ereignisse.art`: Eine spätere Fassung schreibt einen Wert, den
///   es heute nicht gibt, und eine ältere soll die Datei trotzdem öffnen.
///   Was die App kennt, entscheidet das **Lesen**, nicht die Tabelle. Die
///   `CHECK (… IN (0, 1))` an den Bool-Spalten erzeugt drift selbst und
///   sind davon nicht berührt.
/// - **Kein `DEFAULT` auf `geaendert`.** Ein `CURRENT_TIMESTAMP` erfände
///   den Zeitpunkt einer Änderung, die niemand gemacht hat — derselbe
///   Fehler wie eine Migration, die alte Zeilen frisch aussehen lässt.
/// - **Kein Index auf keiner der drei Tabellen**, weil
///   `_reconcileSchema` keine Indizes kennt: Ein Index, den der Abgleich
///   nicht nachziehen kann, fehlte auf einem Gerät mit fremdem
///   Zwischenstand still.
/// - **An `zyklus_einstellungen` prüft diese Datei keine Vorgabewerte.**
///   Die Vorbelegung ist eine Dart-Konstante und keine Zeile in der
///   Datenbank (dieselbe Überlegung wie bei `Ziele.vorbelegung`: sonst
///   stünde sie an zwei Orten, und einer wäre irgendwann der falsche).
///   Ob die Spalten darüber hinaus einen SQL-Vorgabewert tragen,
///   entscheidet der Implementierende.
/// - **Ein zweites Öffnen ändert am Schema nichts mehr** (gemessen am
///   SQLite-Schema-Zähler, wie in `schema_v24_test.dart`).
/// - **Die Umfänge der Stufe 24 gehören zum Bestand**, den die Stufe 26
///   nicht anrühren darf.
///
/// ## Bestehende Tests, die mit dieser Stufe mitgehen müssen
///
/// Der Test-Agent hat sie **nicht** angefasst (`.githooks/pre-commit`
/// bräche einen solchen Commit ohnehin ab); sie stehen im Bericht:
/// `schema_tabellen.dart` braucht `tabellenAusStufe26` in
/// [tabellenHeute], `migration_test.dart` die absolute Zahl 25,
/// `schema_abgleich_test.dart` `heutigeNummer = 25` und die drei
/// Tabellen in seinem `vollstaendigesSchema`, und
/// `schema_v18_test.dart`, `schema_v19_test.dart`,
/// `schema_v21_test.dart`, `schema_v22_test.dart`,
/// `schema_v23_test.dart` und `schema_v24_test.dart` müssen die Tabellen
/// der Stufe 26 aus ihren Vorbedingungen herausnehmen — die kann ein
/// Altstand nicht haben.
///
/// **Diese Datei selbst kommt ohne das Nachziehen aus:** Sie drückt den
/// Altstand als `tabellenHeute.difference(neueTabellen)` und den Endstand
/// als `tabellenHeute.union(neueTabellen)` aus — beides stimmt, gleich ob
/// `schema_tabellen.dart` die Tabellen schon führt oder noch nicht.
///
/// **Alle Zahlen, Tage, Notizen und Zeitpunkte hier sind erfunden.** Die
/// Tage liegen im Jahr 2099; es steht kein einziger echter
/// Gesundheitswert im Quelltext (`CLAUDE.md`, „Niemals tun").
void main() {
  const tabelleEintraege = 'zyklus_eintraege';
  const tabelleSpiegel = 'zyklus_health_spiegel';
  const tabelleEinstellungen = 'zyklus_einstellungen';
  const neueTabellen = {tabelleEintraege, tabelleSpiegel, tabelleEinstellungen};

  // Die Stufe 27 (#532, eigene Trainings) kam beim Zusammenführen der
  // beiden `main`-Stände am 24.11.2026 dazu; ihre vier Tabellen fehlen
  // einem v24-Stand ebenso wie die drei dieser Stufe.
  final tabellenVorStufe25 =
      tabellenHeute.difference({...neueTabellen, ...tabellenAusStufe27});
  final tabellenNachStufe25 = tabellenHeute.union(neueTabellen);

  /// Die Spalten von `zyklus_eintraege` (Spec 4.1), je mit Typ,
  /// Nullbarkeit und erwartetem SQL-Vorgabewert.
  const formEintraege = <String, ({String typ, bool nullbar, String? vorgabe})>{
    'tag': (typ: 'TEXT', nullbar: false, vorgabe: null),
    'blutung': (typ: 'TEXT', nullbar: true, vorgabe: null),
    'zwischenblutung': (typ: 'INTEGER', nullbar: false, vorgabe: '0'),
    'schmerz': (typ: 'TEXT', nullbar: true, vorgabe: null),
    'symptome': (typ: 'TEXT', nullbar: false, vorgabe: "''"),
    'sex': (typ: 'INTEGER', nullbar: false, vorgabe: '0'),
    'verhuetet': (typ: 'INTEGER', nullbar: true, vorgabe: null),
    'test': (typ: 'TEXT', nullbar: true, vorgabe: null),
    'notiz': (typ: 'TEXT', nullbar: true, vorgabe: null),
    'quelle': (typ: 'TEXT', nullbar: false, vorgabe: "'eigen'"),
    'geaendert': (typ: 'TEXT', nullbar: false, vorgabe: null),
  };

  /// Die Spalten von `zyklus_health_spiegel` (Spec 4.2) — alle drei
  /// Pflicht, keine mit Vorgabewert.
  const formSpiegel = <String, ({String typ, bool nullbar})>{
    'uuid': (typ: 'TEXT', nullbar: false),
    'tag': (typ: 'TEXT', nullbar: false),
    'typ': (typ: 'TEXT', nullbar: false),
  };

  /// Die Spalten von `zyklus_einstellungen` (Spec 4.3). Vorgabewerte
  /// prüft diese Datei hier nicht, siehe Dateikopf.
  const formEinstellungen = <String, ({String typ, bool nullbar})>{
    'id': (typ: 'INTEGER', nullbar: false),
    'kalender_an': (typ: 'INTEGER', nullbar: false),
    'sicht': (typ: 'TEXT', nullbar: false),
    'verhuetung_an': (typ: 'INTEGER', nullbar: false),
    'verhuetung_seit': (typ: 'TEXT', nullbar: true),
    'verhuetung_art': (typ: 'TEXT', nullbar: true),
    'import_gelaufen': (typ: 'INTEGER', nullbar: false),
    'vorhersage_pausiert': (typ: 'INTEGER', nullbar: false),
  };

  /// Die Spalten, auf denen keine `CHECK`-Bedingung liegen darf: offene
  /// Wortschätze, die eine spätere Fassung erweitert.
  const offeneWortschaetze = [
    'blutung',
    'schmerz',
    'test',
    'quelle',
    'sicht',
    'verhuetung_art',
  ];

  // --- Altstände, von Hand -----------------------------------------------

  /// Stand v24: `v23Schema` aus `schema_v24_test.dart`, dazu `umfaenge`
  /// (Stufe 24) wie dort festgelegt. Von Hand aufgeschrieben, nicht aus
  /// `AppCache` erzeugt.
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

  /// Die drei Tabellen, wie ein anderer Zweig sie schon angelegt haben
  /// könnte — von Hand nach den Tabellen im Dateikopf.
  const zyklusVorweg = '''
    CREATE TABLE zyklus_eintraege (
      tag TEXT NOT NULL,
      blutung TEXT NULL,
      zwischenblutung INTEGER NOT NULL DEFAULT 0 CHECK (zwischenblutung IN (0, 1)),
      schmerz TEXT NULL,
      symptome TEXT NOT NULL DEFAULT '',
      sex INTEGER NOT NULL DEFAULT 0 CHECK (sex IN (0, 1)),
      verhuetet INTEGER NULL CHECK (verhuetet IN (0, 1)),
      test TEXT NULL,
      notiz TEXT NULL,
      quelle TEXT NOT NULL DEFAULT 'eigen',
      geaendert TEXT NOT NULL,
      PRIMARY KEY (tag)
    );
    CREATE TABLE zyklus_health_spiegel (
      uuid TEXT NOT NULL,
      tag TEXT NOT NULL,
      typ TEXT NOT NULL,
      PRIMARY KEY (uuid)
    );
    CREATE TABLE zyklus_einstellungen (
      id INTEGER NOT NULL DEFAULT 0,
      kalender_an INTEGER NOT NULL DEFAULT 0 CHECK (kalender_an IN (0, 1)),
      sicht TEXT NOT NULL DEFAULT 'ueberblick',
      verhuetung_an INTEGER NOT NULL DEFAULT 0 CHECK (verhuetung_an IN (0, 1)),
      verhuetung_seit TEXT NULL,
      verhuetung_art TEXT NULL,
      import_gelaufen INTEGER NOT NULL DEFAULT 0 CHECK (import_gelaufen IN (0, 1)),
      vorhersage_pausiert INTEGER NOT NULL DEFAULT 0 CHECK (vorhersage_pausiert IN (0, 1)),
      PRIMARY KEY (id)
    );
  ''';

  /// Zeilen in den drei Tabellen, wie der fremde Zweig sie hinterlassen
  /// haben könnte. Alle muss die Stufe stehen lassen — es sind
  /// Gesundheitsdaten, und die einzige Kopie liegt auf dem Gerät.
  const zyklusZeilenVorweg = '''
    INSERT INTO zyklus_eintraege
      (tag, blutung, zwischenblutung, schmerz, symptome, sex, verhuetet,
       test, notiz, quelle, geaendert)
      VALUES ('2099-06-03', 'mittel', 0, 'leicht', 'pruefsymptomA', 0, NULL,
              NULL, 'Pruefnotiz', 'eigen', '2099-06-03T07:05:00.000Z');
    INSERT INTO zyklus_eintraege
      (tag, blutung, zwischenblutung, schmerz, symptome, sex, verhuetet,
       test, notiz, quelle, geaendert)
      VALUES ('2099-06-04', 'leicht', 0, NULL, '', 0, NULL, NULL, NULL,
              'health', '2099-06-04T07:05:00.000Z');
    INSERT INTO zyklus_health_spiegel (uuid, tag, typ)
      VALUES ('PRUEF-UUID-0001', '2099-06-03', 'pruef_typ_blutung');
    INSERT INTO zyklus_einstellungen
      (id, kalender_an, sicht, verhuetung_an, verhuetung_seit,
       verhuetung_art, import_gelaufen, vorhersage_pausiert)
      VALUES (0, 1, 'kinderwunsch', 0, NULL, NULL, 1, 0);
  ''';

  /// Der Bestand auf Stand v24, wörtlich der aus `schema_v24_test.dart`,
  /// dazu eine Zeile in `umfaenge`. Eine Migration, die hier etwas
  /// verlöre, verlöre es endgültig.
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
    INSERT INTO portionen (id, lebensmittel_id, name, menge_g, herkunft)
      VALUES (5, 1, 'Prüfbon', 5.9, 'eigen');
    INSERT INTO eintraege
      (id, tages_schluessel, mahlzeit, zeitpunkt, lebensmittel_id, name,
       menge_g, kcal, extra, health_uuid, health_stand, portion_id,
       portion_name, portion_g, fluessig)
      VALUES (1, '2099-03-01', 'fruehstueck', '2099-03-01T07:15:00.000Z', 1,
              'Prüfknäcke', 11.8, 44.6, '{}', 'PRUEF-UUID-0023',
              'geschrieben', 5, 'Prüfbon', 5.9, 0);
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
    INSERT INTO wach_belege (id, zeitpunkt, art)
      VALUES (2, '2099-03-02T00:15:30.000Z', 'buchung');
    INSERT INTO umfaenge (tag, mass, zentimeter, eingetragen_am, quelle)
      VALUES ('2099-04-12', 'pruefmassA', 41.4, '2099-04-12T07:05:00.000Z',
              'getippt');
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

  /// Die Tabellen, deren Zeilen die Stufe nicht anrühren darf.
  const alle = [
    'tages_werte',
    'stammdaten',
    'lebensmittel',
    'portionen',
    'eintraege',
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

  Set<String> rohTabellen(Database roh) => {
    for (final z in roh.select(
      "SELECT name FROM sqlite_master WHERE type = 'table' "
      "AND name NOT LIKE 'sqlite_%';",
    ))
      z['name'] as String,
  };

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

  Future<String> tabellenSql(AppCache db, String tabelle) async {
    final zeile = await db
        .customSelect(
          "SELECT sql FROM sqlite_master WHERE type = 'table' "
          "AND name = '$tabelle';",
        )
        .getSingle();
    return zeile.read<String>('sql');
  }

  Future<void> keineIndizes(AppCache db, String tabelle) async {
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
          '$tabelle: kein eigener Index — _reconcileSchema kennt keine, und '
          'ein Index, den der Abgleich nicht nachziehen kann, fehlte auf '
          'einem Gerät mit fremdem Zwischenstand still. Der automatische '
          'Index hinter dem Primärschlüssel (sql IS NULL) zählt nicht',
    );
  }

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
              '$tabelle, Zeile ${i + 1}, Spalte $key: ein vorhandener Wert '
              'ist ein eingetragener Wert, und die einzige Kopie liegt auf '
              'dem Gerät',
        );
      }
    }
  }

  /// Die Form der drei Tabellen nach Spec 4.1 bis 4.3.
  Future<void> pruefeForm(AppCache db) async {
    // --- zyklus_eintraege ---
    final e = await spalten(db, tabelleEintraege);
    expect(
      e.keys.toSet(),
      formEintraege.keys.toSet(),
      reason:
          'genau die elf Spalten aus Spec 4.1. Ein Tageseintrag ist eine '
          'Zeile je Kalendertag, kein Textklumpen — ein Klumpen bräuchte '
          'einen eigenen Codec und wäre mit keiner Abfrage erreichbar',
    );
    for (final MapEntry(key: name, value: soll) in formEintraege.entries) {
      expect(e[name]!.typ, soll.typ, reason: 'zyklus_eintraege.$name: Typ');
      expect(
        e[name]!.nullbar,
        soll.nullbar,
        reason:
            'zyklus_eintraege.$name: ${soll.nullbar ? 'nullbar — fehlt der '
                      'Wert, fehlt er, und 0 ist keine Antwort auf „kein Wert"' : 'Pflicht'}',
      );
      expect(
        e[name]!.vorgabe,
        soll.vorgabe,
        reason:
            'zyklus_eintraege.$name: Vorgabewert ${soll.vorgabe ?? '(keiner)'}'
            '. geaendert bekommt keinen — ein CURRENT_TIMESTAMP erfände den '
            'Zeitpunkt einer Änderung, die niemand gemacht hat',
      );
    }
    expect(
      e['tag']!.schluesselNr,
      1,
      reason:
          'der Primärschlüssel ist der Tag, und nur er: „Ein leerer Tag ist '
          'ein Tag ohne Zeile" (Spec 4.1) setzt voraus, dass es je Tag '
          'höchstens eine Zeile gibt',
    );
    expect(
      [
        for (final MapEntry(:key, :value) in e.entries)
          if (value.schluesselNr > 0) key,
      ],
      ['tag'],
      reason: 'keine weitere Spalte im Schlüssel',
    );

    final sqlEintraege = await tabellenSql(db, tabelleEintraege);
    for (final spalte in offeneWortschaetze) {
      if (!e.containsKey(spalte)) continue;
      expect(
        sqlEintraege.toUpperCase(),
        isNot(contains('CHECK ($spalte'.toUpperCase())),
        reason:
            'keine CHECK-Bedingung auf $spalte: Eine spätere Fassung '
            'schreibt einen Wert, den es heute nicht gibt, und eine ältere '
            'soll die Datei trotzdem öffnen. Was die App kennt, entscheidet '
            'das Lesen (dieselbe Überlegung wie bei ereignisse.art)',
      );
    }

    // --- zyklus_health_spiegel ---
    final s = await spalten(db, tabelleSpiegel);
    expect(
      s.keys.toSet(),
      formSpiegel.keys.toSet(),
      reason:
          'genau die drei Spalten aus Spec 4.2: je geschriebenem Sample eine '
          'Zeile mit UUID, Tag und Typ — nur damit lässt sich beim Ändern '
          'oder Löschen eines Tages gezielt entfernen, statt alles von '
          'Health neu zu lesen',
    );
    for (final MapEntry(key: name, value: soll) in formSpiegel.entries) {
      expect(s[name]!.typ, soll.typ, reason: 'zyklus_health_spiegel.$name');
      expect(
        s[name]!.nullbar,
        soll.nullbar,
        reason:
            'zyklus_health_spiegel.$name ist Pflicht — ein Spiegel ohne '
            'UUID, Tag oder Typ spiegelt nichts',
      );
      expect(
        s[name]!.vorgabe,
        isNull,
        reason:
            'zyklus_health_spiegel.$name: kein Vorgabewert. Eine Vorgabe '
            'erfände eine Sample-UUID, einen Tag oder einen Typ',
      );
    }
    expect(
      s['uuid']!.schluesselNr,
      1,
      reason:
          'die Sample-UUID ist der Schlüssel: Je Sample eine Zeile, und '
          'dasselbe Sample zweimal zu merken wäre dieselbe Zeile',
    );

    // --- zyklus_einstellungen ---
    final n = await spalten(db, tabelleEinstellungen);
    expect(
      n.keys.toSet(),
      formEinstellungen.keys.toSet(),
      reason:
          'genau die Felder aus Spec 4.3, dazu id. verhuetungSeit steht '
          'ausdrücklich dabei: „Der Zeitpunkt des Umschaltens wird '
          'gespeichert, damit rückwirkend erkennbar bleibt, welcher Zyklus '
          'unter Verhütung lief" (Spec 3.7)',
    );
    for (final MapEntry(key: name, value: soll) in formEinstellungen.entries) {
      expect(n[name]!.typ, soll.typ, reason: 'zyklus_einstellungen.$name: Typ');
      expect(
        n[name]!.nullbar,
        soll.nullbar,
        reason:
            'zyklus_einstellungen.$name: '
            '${soll.nullbar ? 'nullbar — nichts eingetragen ist ein eigener '
                      'Zustand, kein erfundener Wert' : 'Pflicht'}',
      );
    }
    expect(
      n['id']!.schluesselNr,
      1,
      reason:
          'eine Einstellungszeile, Schlüssel id — wie stammdaten, '
          'ziel_werte und ki_einstellungen. Einstellungen sind kein '
          'Verlauf; eine zweite Zeile wäre ein zweiter, widersprechender '
          'Stand',
    );

    for (final t in neueTabellen) {
      await keineIndizes(db, t);
    }
  }

  // ═════════════════════════════════════════════════════════════════════

  group('Vorbedingungen: die Altstände sind so gebaut, wie sie gemeint '
      'sind', () {
    test('v24 hat alle heutigen Tabellen außer den dreien', () {
      final roh = rohdatei(v24Schema, bestand, 24);
      addTearDown(roh.close);
      final namen = rohTabellen(roh);
      for (final t in neueTabellen) {
        expect(namen, isNot(contains(t)));
      }
      expect(
        namen,
        tabellenVorStufe25,
        reason: 'v24 hat alle heutigen Tabellen außer denen der Stufe 26',
      );
      expect(rohZeilen(roh, 'eintraege'), hasLength(1));
      expect(rohZeilen(roh, 'ereignisse'), hasLength(1));
      expect(rohZeilen(roh, 'wach_belege'), hasLength(2));
      expect(rohZeilen(roh, 'umfaenge'), hasLength(1));
    });

    test('v24 vorweg trägt die drei Tabellen schon, mit Zeilen', () {
      final roh = rohdatei(
        v24Schema + zyklusVorweg,
        bestand + zyklusZeilenVorweg,
        24,
      );
      addTearDown(roh.close);
      expect(rohZeilen(roh, tabelleEintraege), hasLength(2));
      expect(rohZeilen(roh, tabelleSpiegel), hasLength(1));
      expect(rohZeilen(roh, tabelleEinstellungen), hasLength(1));
    });
  });

  group('Schema v26 (#539) — frisch angelegt', () {
    test('die Version ist mindestens 26 und steht so in der Datei', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      expect(db.schemaVersion, greaterThanOrEqualTo(26));
      expect(await abgelegteVersion(db), db.schemaVersion);
    });

    test('ein frischer Cache hat die drei Tabellen, in der verlangten Form, '
        'und alle drei sind leer', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      expect(await tabellen(db), tabellenNachStufe25);
      await pruefeForm(db);
      for (final t in neueTabellen) {
        expect(
          await zeilen(db, t),
          isEmpty,
          reason:
              '$t ist leer. Das Anlegen des Caches ist kein Tageseintrag, '
              'kein geschriebenes Sample und keine getroffene Einstellung',
        );
      }
    });

    test('auch zyklus_einstellungen ist leer — die Vorbelegung ist eine '
        'Dart-Konstante, keine Zeile', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      expect(
        await zeilen(db, tabelleEinstellungen),
        isEmpty,
        reason:
            'eine vorab eingefügte Zeile behauptete eine Einstellung, die '
            'niemand getroffen hat (dieselbe Regel wie bei stammdaten und '
            'ki_einstellungen) — und sie stünde an zwei Orten, im Schema und '
            'im Code, von denen einer irgendwann der falsche ist. Der '
            'Kalender ist aus, bis jemand ihn einschaltet',
      );
    });
  });

  group('Migration v24 → heute', () {
    test('legt die drei Tabellen an, in der verlangten Form, und die Datei '
        'steht danach auf der heutigen Version', () async {
      final roh = rohdatei(v24Schema, bestand, 24);
      addTearDown(roh.close);
      final db = ueber(roh);
      addTearDown(db.close);

      expect(await abgelegteVersion(db), db.schemaVersion);
      expect(
        await abgelegteVersion(db),
        greaterThanOrEqualTo(26),
        reason: 'die Stufe 26 ist über diesen Bestand gelaufen',
      );
      expect(await tabellen(db), tabellenNachStufe25);
      await pruefeForm(db);
    });

    test('füllt nichts — keine Zeile, kein erfundener Zeitstempel, keine '
        'Einstellungszeile', () async {
      final roh = rohdatei(v24Schema, bestand, 24);
      addTearDown(roh.close);
      final db = ueber(roh);
      addTearDown(db.close);

      for (final t in neueTabellen) {
        expect(
          await zeilen(db, t),
          isEmpty,
          reason:
              '$t ist nach der Migration leer. „Alte Zeilen bekommen keine '
              'erfundenen Zeitstempel" (Spec 4.4): Vor dieser Stufe lagen '
              'keine Zyklusdaten in dieser Datenbank, es gibt also nichts '
              'umzuschreiben. Die erste Zeile schreibt der Eintragen-Schirm '
              'oder der Erstimport, nicht das Schema',
        );
      }
    });

    test(
      'additiv: jede Zeile und jeder Wert bleibt, in allen Tabellen',
      () async {
        final roh = rohdatei(v24Schema, bestand, 24);
        addTearDown(roh.close);
        final vorher = {for (final t in alle) t: rohZeilen(roh, t)};

        final db = ueber(roh);
        addTearDown(db.close);

        expect(
          await abgelegteVersion(db),
          greaterThanOrEqualTo(26),
          reason: 'die Stufe 26 ist über diesen Bestand gelaufen',
        );
        for (final t in alle) {
          pruefeUnveraendert(vorher[t]!, await zeilen(db, t), t);
        }
      },
    );

    test('ein zweites Öffnen derselben Datei ändert am Schema nichts mehr, '
        'und ein inzwischen eingetragener Tag bleibt', () async {
      final roh = rohdatei(v24Schema, bestand, 24);
      addTearDown(roh.close);

      final erstes = ueber(roh);
      await erstes.customStatement(
        'INSERT INTO zyklus_eintraege (tag, blutung, zwischenblutung, '
        'symptome, sex, quelle, geaendert) '
        "VALUES ('2099-06-03', 'mittel', 0, '', 0, 'eigen', "
        "'2099-06-03T07:05:00.000Z');",
      );
      await erstes.close();
      final nachErstem = schemaZaehler(roh);
      final zeilenNachErstem = rohZeilen(roh, tabelleEintraege);

      final zweites = ueber(roh);
      addTearDown(zweites.close);
      await zweites.customSelect('SELECT 1;').get();

      expect(
        schemaZaehler(roh),
        nachErstem,
        reason:
            'PRAGMA schema_version steigt bei jedem CREATE, ALTER und DROP. '
            'Steigt er beim zweiten Öffnen, legt die Stufe oder der Abgleich '
            'bei jedem Start etwas neu an',
      );
      expect(
        zeilenNachErstem,
        hasLength(1),
        reason: 'Vorbedingung: der Tag ist eingetragen',
      );
      pruefeUnveraendert(
        zeilenNachErstem,
        await zeilen(zweites, tabelleEintraege),
        tabelleEintraege,
      );
    });
  });

  group('Die Stufe ist zweimal ausführbar (#234/#240)', () {
    test('stehen die drei Tabellen schon da, öffnet die Datei, und jede '
        'Zeile darin bleibt', () async {
      final roh = rohdatei(
        v24Schema + zyklusVorweg,
        bestand + zyklusZeilenVorweg,
        24,
      );
      addTearDown(roh.close);
      final vorher = {
        for (final t in [...alle, ...neueTabellen]) t: rohZeilen(roh, t),
      };

      final db = ueber(roh);
      addTearDown(db.close);

      expect(await abgelegteVersion(db), db.schemaVersion);
      expect(
        await abgelegteVersion(db),
        greaterThanOrEqualTo(26),
        reason:
            'die Stufe 26 lief über eine Datei, die ihre Tabellen schon '
            'trug, und scheiterte nicht an „table already exists". Alle '
            'Zweige bauen unter derselben Bundle-ID und benutzen dieselbe '
            'Datei',
      );
      for (final MapEntry(key: t, value: z) in vorher.entries) {
        pruefeUnveraendert(z, await zeilen(db, t), t);
      }
      await pruefeForm(db);
      expect(
        await zeilen(db, tabelleEintraege),
        hasLength(2),
        reason:
            'kein DROP TABLE IF EXISTS vor dem CREATE. Eine Stufe, die nie '
            'scheitert und dabei eingetragene Zyklustage löscht, ist die '
            'schlechtere Stufe — und es sind Gesundheitsdaten',
      );
      expect(await zeilen(db, tabelleSpiegel), hasLength(1));
      expect(await zeilen(db, tabelleEinstellungen), hasLength(1));
    });
  });

  group('Abgleich beim Öffnen (#233)', () {
    test('eine Datei auf 25, der die Tabellen fehlen, bekommt sie — leer, '
        'und verliert nichts', () async {
      // Ein Zweig hat die Nummer hochgezogen, bevor seine Stufe fertig
      // war: `if (from < 26)` läuft dann nie.
      final roh = rohdatei(v24Schema, bestand, 25);
      addTearDown(roh.close);
      final vorher = {for (final t in alle) t: rohZeilen(roh, t)};

      final db = ueber(roh);
      addTearDown(db.close);
      // Der erste Zugriff: Das Öffnen selbst ist bei drift lazy.
      await db.customSelect('SELECT 1;').get();

      expect(
        await tabellen(db),
        tabellenNachStufe25,
        reason:
            'onUpgrade läuft bei from == 25 nicht in die Stufe 26 — die drei '
            'Tabellen kommen nur über den Abgleich',
      );
      await pruefeForm(db);
      for (final t in neueTabellen) {
        expect(await zeilen(db, t), isEmpty);
      }
      for (final t in alle) {
        pruefeUnveraendert(vorher[t]!, await zeilen(db, t), t);
      }
    });
  });

  group('Von weit unten: v11 → heute', () {
    test('ein v11-Stand öffnet ohne Fehler und hat danach die drei '
        'Tabellen, leer', () async {
      final roh = rohdatei(v11Schema, v11Bestand, 11);
      addTearDown(roh.close);
      final vorher = {
        for (final t in ['tages_werte', 'stammdaten']) t: rohZeilen(roh, t),
      };

      final db = ueber(roh);
      addTearDown(db.close);

      // Scheiterte eine Stufe, würfe schon dieser erste Zugriff.
      expect(await abgelegteVersion(db), db.schemaVersion);
      expect(await tabellen(db), tabellenNachStufe25);
      await pruefeForm(db);
      for (final t in neueTabellen) {
        expect(await zeilen(db, t), isEmpty);
      }
      for (final MapEntry(key: t, value: z) in vorher.entries) {
        pruefeUnveraendert(z, await zeilen(db, t), t);
      }
    });
  });

  group('Die Zeilen', () {
    test('geaendert kommt als UTC zurück und ist gleich sich selbst; '
        'abgelegt ist er als Text', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);
      // 00:30:15,250 UTC in der Nacht der Zeitumstellung im Oktober — in
      // Berlin 02:30:15 Sommerzeit, die erste der beiden 02:30.
      final geaendert = DateTime.utc(2099, 10, 25, 0, 30, 15, 250);

      await db.customInsert(
        'INSERT INTO zyklus_eintraege (tag, blutung, zwischenblutung, '
        'symptome, sex, quelle, geaendert) VALUES (?, ?, ?, ?, ?, ?, ?);',
        variables: [
          Variable<String>('2099-10-25'),
          Variable<String>('stark'),
          Variable<bool>(false),
          Variable<String>(''),
          Variable<bool>(false),
          Variable<String>('eigen'),
          Variable<DateTime>(geaendert),
        ],
      );

      final zeile = await db
          .customSelect(
            'SELECT geaendert, typeof(geaendert) AS art_zeit, '
            'typeof(tag) AS art_tag, typeof(zwischenblutung) AS art_bool '
            'FROM zyklus_eintraege;',
          )
          .getSingle();

      expect(
        zeile.read<String>('art_zeit'),
        'text',
        reason:
            'Zeitstempel liegen als Text in der Datenbank; drifts Standard '
            '(Unix-Sekunden) gäbe sie als lokale Zeit zurück, und Dart '
            'vergleicht DateTime samt isUtc',
      );
      expect(zeile.read<String>('art_tag'), 'text');
      expect(
        zeile.read<String>('art_bool'),
        'integer',
        reason: 'SQLite kennt kein BOOLEAN; drift legt 0 und 1 ab',
      );

      final gelesen = zeile.read<DateTime>('geaendert');
      expect(gelesen.isUtc, isTrue, reason: 'als UTC abgelegt, als UTC zurück');
      expect(
        gelesen,
        geaendert,
        reason:
            'ein als UTC gespeicherter Wert, der als Ortszeit herauskäme, '
            'wäre ungleich sich selbst. Die ganze Zeitrechnung läuft über '
            'UTC-Zeitpunkte, die Berliner Tagesgrenzen bezeichnen',
      );
    });

    test('tag, quelle und geaendert sind Pflicht — ohne sie ist die Zeile '
        'kein Tageseintrag', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      const vollstaendig = {
        'tag': "'2099-06-03'",
        'quelle': "'eigen'",
        'geaendert': "'2099-06-03T07:05:00.000Z'",
      };

      for (final fehlt in ['tag', 'geaendert']) {
        final rest = {...vollstaendig}..remove(fehlt);
        await expectLater(
          db.customStatement(
            'INSERT INTO zyklus_eintraege (${rest.keys.join(', ')}) '
            'VALUES (${rest.values.join(', ')});',
          ),
          throwsA(anything),
          reason:
              'ohne $fehlt gibt es keinen ehrlichen Ersatzwert: Der Tag ist '
              'der Schlüssel, und ein erfundener Änderungszeitpunkt '
              'behauptete, die Zeile sei frisch',
        );
      }
      expect(await zeilen(db, tabelleEintraege), isEmpty);
    });

    test('ohne quelle greift der Vorgabewert eigen — ein Tag kommt von der '
        'Nutzerin, wenn niemand etwas anderes sagt', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      await db.customStatement(
        'INSERT INTO zyklus_eintraege (tag, geaendert) '
        "VALUES ('2099-06-03', '2099-06-03T07:05:00.000Z');",
      );

      final zeile = (await zeilen(db, tabelleEintraege)).single;
      expect(zeile['quelle'], 'eigen');
      expect(zeile['symptome'], '');
      expect(zeile['zwischenblutung'], 0);
      expect(zeile['sex'], 0);
      expect(
        zeile['blutung'],
        isNull,
        reason:
            'keine Blutung heißt NULL, nicht „keine" als Wort und schon gar '
            'nicht 0 — 0 ist keine Antwort auf „kein Wert" (CLAUDE.md)',
      );
      expect(zeile['verhuetet'], isNull);
      expect(zeile['test'], isNull);
      expect(zeile['notiz'], isNull);
      expect(zeile['schmerz'], isNull);
    });

    test('derselbe Tag zweimal ist ein Verstoß gegen den Schlüssel', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      const einfuegen =
          'INSERT INTO zyklus_eintraege (tag, blutung, geaendert) '
          "VALUES ('2099-06-03', 'mittel', '2099-06-03T07:05:00.000Z');";
      await db.customStatement(einfuegen);

      await expectLater(
        db.customStatement(einfuegen),
        throwsA(anything),
        reason:
            'je Kalendertag höchstens eine Zeile. Ein zweites Eintragen '
            'desselben Tages ist eine Korrektur und ersetzt die Zeile, es '
            'legt keine zweite an',
      );
      expect(await zeilen(db, tabelleEintraege), hasLength(1));
    });

    test('blutung, schmerz, test und quelle nehmen Werte an, die es heute '
        'nicht gibt', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      await db.customStatement(
        'INSERT INTO zyklus_eintraege (tag, blutung, schmerz, test, quelle, '
        "geaendert) VALUES ('2099-06-03', 'pruefstufeX', 'pruefstufeY', "
        "'pruefergebnisZ', 'pruefquelle', '2099-06-03T07:05:00.000Z');",
      );

      final zeile = (await zeilen(db, tabelleEintraege)).single;
      expect(zeile['blutung'], 'pruefstufeX');
      expect(zeile['schmerz'], 'pruefstufeY');
      expect(zeile['test'], 'pruefergebnisZ');
      expect(
        zeile['quelle'],
        'pruefquelle',
        reason:
            'keine CHECK-Bedingung: Käme eine vierte Blutungsstufe oder eine '
            'dritte Quelle dazu, müsste die Tabelle sonst neu gebaut werden '
            '— und eine ältere Fassung öffnete die Datei nicht mehr',
      );
    });

    test('dieselbe Sample-UUID zweimal ist ein Verstoß gegen den '
        'Schlüssel; ein Tag trägt mehrere Samples', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      await db.customStatement(
        'INSERT INTO zyklus_health_spiegel (uuid, tag, typ) '
        "VALUES ('PRUEF-UUID-0001', '2099-06-03', 'pruef_typ_blutung');",
      );
      await db.customStatement(
        'INSERT INTO zyklus_health_spiegel (uuid, tag, typ) '
        "VALUES ('PRUEF-UUID-0002', '2099-06-03', 'pruef_typ_symptom');",
      );

      expect(
        await zeilen(db, tabelleSpiegel),
        hasLength(2),
        reason:
            'ein Zyklustag erzeugt mehrere Samples (Blutung, Sex, je '
            'Symptom eines) — je geschriebenem Sample eine Zeile',
      );

      await expectLater(
        db.customStatement(
          'INSERT INTO zyklus_health_spiegel (uuid, tag, typ) '
          "VALUES ('PRUEF-UUID-0001', '2099-06-04', 'pruef_typ_blutung');",
        ),
        throwsA(anything),
        reason: 'dieselbe UUID zweimal zu merken wäre dieselbe Zeile',
      );
    });
  });

  group('Gefiltert wird in SQL, über den Tagesstring', () {
    test('ein Monat lässt sich lexikografisch abfragen, über den '
        'Jahreswechsel hinweg', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      const tage = [
        '2099-09-30',
        '2099-10-01',
        '2099-10-25',
        '2099-12-31',
        '2100-01-01',
        '2100-02-15',
      ];
      for (final tag in tage) {
        await db.customStatement(
          'INSERT INTO zyklus_eintraege (tag, blutung, geaendert) '
          "VALUES ('$tag', 'mittel', '${tag}T07:05:00.000Z');",
        );
      }

      final fenster = await db
          .customSelect(
            "SELECT tag FROM zyklus_eintraege WHERE tag >= '2099-10-01' "
            "AND tag <= '2100-01-01' ORDER BY tag;",
          )
          .get();

      expect(
        fenster.map((z) => z.read<String>('tag')).toList(),
        ['2099-10-01', '2099-10-25', '2099-12-31', '2100-01-01'],
        reason:
            'der Datumsschlüssel ist der ISO-Tagesstring, nicht Epoch: Ein '
            'Tag ist eine Kalenderangabe, kein Zeitpunkt. So vergleicht '
            'WHERE tag >= ? lexikografisch richtig und übersteht jede '
            'Zeitumstellung — und die am 25.10.2099 liegt mitten in diesem '
            'Fenster. Nach dem Laden in Dart zu filtern umginge Regel 2 der '
            'Datenschicht',
      );
    });

    test('ORDER BY tag sortiert chronologisch', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      for (final tag in ['2100-01-02', '2099-04-12', '2099-11-09']) {
        await db.customStatement(
          'INSERT INTO zyklus_eintraege (tag, blutung, geaendert) '
          "VALUES ('$tag', 'leicht', '${tag}T07:05:00.000Z');",
        );
      }

      final sortiert = await db
          .customSelect('SELECT tag FROM zyklus_eintraege ORDER BY tag;')
          .get();
      expect(
        sortiert.map((z) => z.read<String>('tag')).toList(),
        ['2099-04-12', '2099-11-09', '2100-01-02'],
        reason:
            'führende Nullen und feste Breite: Textsortierung ist hier '
            'Datumssortierung. Die Clusterregel aus Spec 2.1 liest die Tage '
            'in dieser Reihenfolge',
      );
    });

    test('der Spiegel lässt sich je Tag abfragen', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      await db.customStatement(
        'INSERT INTO zyklus_health_spiegel (uuid, tag, typ) '
        "VALUES ('PRUEF-UUID-0001', '2099-06-03', 'pruef_typ_blutung');",
      );
      await db.customStatement(
        'INSERT INTO zyklus_health_spiegel (uuid, tag, typ) '
        "VALUES ('PRUEF-UUID-0002', '2099-06-04', 'pruef_typ_blutung');",
      );

      final treffer = await db
          .customSelect(
            "SELECT uuid FROM zyklus_health_spiegel WHERE tag = '2099-06-03';",
          )
          .get();
      expect(
        treffer.map((z) => z.read<String>('uuid')).toList(),
        ['PRUEF-UUID-0001'],
        reason:
            'beim Ändern oder Löschen eines Tages werden die zugehörigen '
            'Samples **gezielt** entfernt (Spec 4.2) — dafür muss der Tag '
            'abfragbar sein',
      );
    });
  });
}
