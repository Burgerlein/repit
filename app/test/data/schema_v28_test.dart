import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show Database, sqlite3;
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/data/cache_repository.dart';
import 'package:repit/health/health_types.dart';

import 'schema_tabellen.dart';

/// Tests für **Schema v28**: die Spalte `vo2max` in `tages_werte` (#95,
/// Ausdauer-Schirm — mit #16).
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden. Jede Migration
/// bekommt einen Test, dies ist der für die Stufe 28.
///
/// ## Woher die Anforderung kommt
///
/// Der Ausdauer-Schirm (#95) braucht VO₂max aus dem Cache — Hausregel
/// „Zuerst der Cache, dann HealthKit" (`CLAUDE.md`, Datenschicht):
/// `build()` liest den drift-Cache und zeigt sofort `Bekannt(…, laeuft:
/// true)`, bevor HealthKit gefragt wird. `DailyMetrics.vo2max`
/// (`lib/health/health_types.dart`) kommt seit jeher aus dem Kanal, aber
/// `TagesWerte` hat keine Spalte dafür; `CacheRepository` nennt das selbst
/// die **geerbte Schemagrenze** aus Task 6 (`lib/data/cache_repository.dart`,
/// Doc-Kommentar an `_alsDailyMetrics`): `activeKcal`, `basalKcal`,
/// `vo2max` und `standHours` kommen aus dem Cache **immer** `null` zurück.
/// Für den Ausdauer-Schirm hieße das: Die VO₂max-Anzeige steht nach jedem
/// Kaltstart erst leer da, bis HealthKit antwortet — Ladezustand als
/// Leerstand, derselbe Fehler, den #194 für die Gewichtskachel und #202
/// für Körperfett abgeräumt haben. Diese Stufe räumt ihn für `vo2max` ab;
/// die Grenze schrumpft von vier auf drei Felder, aufgehoben ist sie nicht.
///
/// Der Code der Stufe existierte beim Schreiben dieser Datei nicht.
/// Gelesen wurden `CLAUDE.md`, die Nachbarspalten in `lib/data/tables.dart`
/// und die bestehenden Migrationstests (`schema_v7_test.dart` als Muster
/// für eine Spalten-Stufe, `schema_v27_test.dart` für den jüngsten
/// Altstand), nicht die spätere Implementierung.
///
/// ## Warum die 26 — und warum diese Datei einmal `schema_v27_test.dart`
/// hieß
///
/// Am 17.11.2026 in `entwurf-ausdauer-95` nachgesehen:
/// `AppCache.schemaVersion => 24` (#476, `umfaenge`). Die nächste freie
/// Nummer war damals die 25, und unter diesem Namen ist die Datei auch
/// entstanden.
///
/// Beim Zusammenführen am 24.11.2026 hatte `main` die 25 inzwischen an
/// **#532** vergeben: die Tabellen der eigenen Trainings samt
/// `gym_sitzungen.trainings_name`, mit eigener Datei
/// `schema_v27_test.dart`. Zwei verschiedene Stufen unter derselben Nummer
/// gibt es nicht — ein Gerät, das die eine ausgeführt hat, führte die
/// andere nie aus, und `user_version` sagt nicht „welches Ticket war
/// fertig", sondern „was hat dieses Gerät schon getan". Das ist genau der
/// Fund **#485**, und aufgelöst wird er wie bei v18 und v24: **die
/// jüngere, noch nicht in `main` liegende Stufe rückt hoch.** Die
/// vo2max-Spalte ist deshalb die 26 und läuft **nach** der Gym-Stufe; die
/// Gym-Stufe und ihre Testdatei bleiben unangetastet.
///
/// Diese Datei ist derselbe Test wie am 17.11., nur eine Stufe höher: Der
/// Altstand ist jetzt ein **v25**-Stand (mit den vier Gym-Tabellen und der
/// Namensspalte), und der Weg, den sie prüft, ist v27 → 26.
///
/// ## Was diese Datei verbindlich vorgibt
///
/// **1. `AppCache.schemaVersion >= 26`** und eine **eigene, additive
/// Stufe** `if (from < 26) { … }` mit `_addColumnIfMissing` — keine
/// Erweiterung der v25-Stufe. Geprüft mit `>=`, damit diese Datei bei der
/// nächsten Stufe nicht mitfällt (#208); die absolute Zahl nennt nur
/// `migration_test.dart`. Nach dem Öffnen eines Altstands steht
/// `user_version` auf `schemaVersion`.
///
/// **2. Eine neue Spalte in `tages_werte`**, keine neue Tabelle:
///
/// | Spalte | Typ | NULL | Vorgabe | Drift-Name |
/// |---|---|---|---|---|
/// | `vo2max` | REAL | ja | — | `vo2max` |
///
/// In `lib/data/tables.dart`, im Stil der Nachbarn:
///
/// ```dart
/// RealColumn get vo2max => real().nullable()();
/// ```
///
/// - **Der Name ist `vo2max`**, in SQL wie in Dart. Das Kanalfeld heißt
///   `vo2max` (`DailyMetrics.vo2max`, `health_mock.dart`,
///   `healthkit_test_view.dart`), und drifts Standard-Snake-Case von
///   `vo2max` ist `vo2max` selbst — anders als bei `recoveryHrDrop`
///   braucht es hier kein `.named(…)`, weil Standard und Wunschname
///   dieselbe Form haben (Begründung wie am Nachbarn, nur umgekehrt).
/// - **`RealColumn`, nicht `IntColumn`.** `DailyMetrics.vo2max` ist
///   `double?`; eine Ganzzahlspalte zwänge die Brücke zu runden, und
///   gerundete ml/kg/min wären eine stille Veränderung von Tims Daten auf
///   dem Weg in den Cache — dieselbe Begründung wie bei
///   `trainingsMinuten` (#194) und `koerperfettPct` (#202).
/// - **Nullbar wie jede Metrikspalte.** An einem Tag ohne Ausdauereinheit
///   mit der Uhr liefert HealthKit diesen Wert schlicht nicht, und
///   „VO₂max 0" wäre keine fehlende Messung, sondern eine absurde —
///   `0` ist keine Antwort auf „kein Wert" (`CLAUDE.md`, Fehler `01`).
/// - **Kein Vorgabewert.** Eine Vorgabe erfände eine Messung, die niemand
///   gemacht hat.
///
/// **3. Additiv, ohne Rückschreiben.** Bestandszeilen behalten jede ihrer
/// elf Spalten wortgleich, und `vo2max` steht dort auf **NULL** — nicht
/// auf `0`, nicht auf einem erfundenen Wert: Eine Migration füllt alte
/// Zeilen nicht mit erfundenen Werten (`CLAUDE.md`, Tests). Alle übrigen
/// Tabellen behalten jede Zeile und jeden Wert.
///
/// **4. Zweimal ausführbar** (#234/#240). Trägt eine Datei mit
/// `user_version = 27` die Spalte schon (ein anderer Zweig unter derselben
/// Bundle-ID), öffnet sie trotzdem — kein `duplicate column name` — und
/// ein Wert darin bleibt.
///
/// **5. Abgleich** (#233). Eine Datei auf 26, der die Spalte fehlt,
/// bekommt sie beim Öffnen, leer.
///
/// **6. Von weit unten:** Ein v11-Stand läuft durch alle Stufen.
///
/// **7. Der Rundweg über `CacheRepository`:** `schreibeTagesWerte`
/// schreibt `vo2max` mit, `liesTagesWerte` gibt ihn zurück — **keine
/// Signatur ändert sich**, nur das Verhalten, wie bei #194 und #202. Ein
/// Tag ohne Wert bleibt `null`, auch wenn der Nachbartag im selben Lauf
/// einen hat.
///
/// ## Festlegungen des Test-Agenten, nicht von Tim freigegeben
///
/// - **Der Dateiname** folgt der Reihe `schema_v10_test.dart` …
///   `schema_v27_test.dart`, in der jede Stufe ihre eigene Datei hat.
/// - **Kein exakter Spaltensatz von `tages_werte`.** Diese Datei prüft
///   ihre eigene Spalte und dass die elf alten noch da sind — nicht, dass
///   es keine dreizehnte gibt. Den vollständigen Satz pinnen
///   `schema_abgleich_test.dart` und `schema_stufen_robust_test.dart`;
///   eine dritte Kopie fiele bei jeder künftigen Spalte mit um (#208,
///   sinngemäß). Muster ist `schema_v7_test.dart`, nicht
///   `schema_v27_test.dart`.
/// - **Kein Test auf eine `MessArt` oder Messreihe für VO₂max.** Ob der
///   Ausdauer-Schirm eine Verlaufskurve bekommt, entscheidet der Entwurf
///   (#95), nicht diese Migration. Ein Test darauf schriebe eine
///   Entscheidung fest, die niemand getroffen hat.
/// - **Kein Test auf das Überschreib-Verhalten eines zweiten Laufs.**
///   `schreibeTagesWerte` ersetzt die Zeile seit jeher ganz; ob ein
///   späterer Lauf ohne VO₂max den Wert stehen lassen soll, ist eine
///   Frage der Leseschicht (`Messwert<T>`), nicht des Schemas.
///
/// ## Bestehende Tests, die mit dieser Stufe mitgehen — **nachgezogen**
///
/// Das Nachziehen ist Sache des Test-Agenten (`TEST_AENDERN=1`),
/// **niemals** des Implementierenden. Am 17.11.2026 ist es auf die 25
/// geschehen, am 24.11.2026 mit dem Stufenumzug auf die 26:
///
/// - `migration_test.dart` — nennt als einzige Stelle die absolute Zahl.
/// - `schema_abgleich_test.dart` — `heutigeNummer`, die zwölf Spalten in
///   `alleTagesWerteSpalten`, `vollstaendigesSchema` mit `vo2max`.
/// - `schema_stufen_robust_test.dart` — eigene Kopie von
///   `alleTagesWerteSpalten`, und die Zahl der Anweisungen je Stufe.
/// - `schema_fremde_spalten_test.dart` — der Stufensatz, durch den ein
///   fremder Zwischenstand läuft.
/// - `test/health/cache_repository_test.dart` — Gruppe „Geerbte
///   Schemagrenze": `vo2max` ist aus der Liste heraus, drei Felder
///   bleiben (`activeKcal`, `basalKcal`, `standHours`).
///
/// **Alle Zahlen, Namen und Zeitpunkte hier sind erfunden.** Die
/// Zeitpunkte liegen im Jahr 2099; Tims echte Gesundheitswerte stehen
/// nirgends im Quelltext.
void main() {
  const neueSpalte = 'vo2max';

  // --- Altstände, von Hand -----------------------------------------------

  /// Stand v27: der v24-Stand aus `schema_v24_test.dart` (`v23Schema` plus
  /// `umfaenge`), dazu **alles, was die Stufe 27 anlegt** — die vier
  /// Tabellen der eigenen Trainings und die Spalte
  /// `gym_sitzungen.trainings_name` —, wörtlich aus `tabellenVorweg` und
  /// `spalteTrainingsNameVorweg` in `schema_v27_test.dart`. Von Hand
  /// gebaut, **nicht** aus dem heutigen Code erzeugt — ein Schema, das aus
  /// dem heutigen Code erzeugt wird, ist kein Altschema, sondern das neue,
  /// und bewiese nichts (`migration_test.dart`, Dateikopf).
  ///
  /// Der Altstand trägt die Stufe 27 **vollständig**, damit der Weg, den
  /// diese Datei prüft, wirklich v27 → 26 ist und nicht v24 → 28: Ein
  /// Altstand ohne die Gym-Tabellen ließe die Stufe 27 mitlaufen, und dann
  /// wäre nicht mehr zu erkennen, ob die Spalte aus der Stufe 28 kommt
  /// oder aus dem Abgleich, den die vorige Stufe ausgelöst hat.
  const v27Schema = '''
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
      trainings_name TEXT NULL,
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
    CREATE TABLE gym_trainings (
      id TEXT NOT NULL,
      name TEXT NOT NULL,
      kategorie TEXT NOT NULL CHECK (kategorie IN ('template', 'eigene')),
      dauer_eingetragen_min INTEGER NULL,
      ist_entwurf INTEGER NOT NULL DEFAULT 0 CHECK (ist_entwurf = 0 OR kategorie = 'eigene'),
      geloescht INTEGER NOT NULL DEFAULT 0 CHECK (geloescht = 0 OR kategorie = 'template'),
      reihenfolge INTEGER NOT NULL,
      entwurf_von TEXT NULL CHECK (entwurf_von IS NULL OR (ist_entwurf = 1 AND kategorie = 'eigene')),
      PRIMARY KEY (id),
      UNIQUE (entwurf_von)
    );
    CREATE TABLE gym_training_uebungen (
      training_id TEXT NOT NULL,
      pos INTEGER NOT NULL CHECK (pos >= 1),
      uebung_id TEXT NOT NULL,
      saetze INTEGER NOT NULL CHECK (saetze >= 1),
      wdh_von INTEGER NOT NULL CHECK (wdh_von >= 1),
      wdh_bis INTEGER NOT NULL CHECK (wdh_bis >= wdh_von),
      steigerung REAL NULL,
      PRIMARY KEY (training_id, uebung_id),
      UNIQUE (training_id, pos)
    );
    CREATE TABLE gym_training_tags (
      training_id TEXT NOT NULL,
      pos INTEGER NOT NULL CHECK (pos >= 1),
      tag TEXT NOT NULL,
      PRIMARY KEY (training_id, tag),
      UNIQUE (training_id, pos)
    );
    CREATE TABLE gym_rotation (
      pos INTEGER NOT NULL CHECK (pos >= 1),
      training_id TEXT NOT NULL,
      PRIMARY KEY (pos),
      UNIQUE (training_id)
    );
    -- Die drei Tabellen der Stufe 26 (#592, Zykluskalender). Sie stehen
    -- hier, seit die beiden `main`-Stände am 24.11.2026 zusammengeführt
    -- wurden: Der Altstand dieser Datei war bis dahin ein v25-Stand und
    -- ist seitdem ein v27-Stand — und ein v27-Stand trägt die Stufe 26
    -- bereits. Ohne sie liefe die Stufe 26 von `user_version = 27` aus
    -- nie, und der Abgleich zöge sie beim Öffnen nach; der Weg, den diese
    -- Datei prüft, wäre dann nicht mehr v27 → 28. Wörtlich aus
    -- `zyklusVorweg` in `schema_v26_test.dart`.
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

  /// Die Spalte, wie ein anderer Zweig sie unter derselben Bundle-ID schon
  /// angelegt haben könnte, von Hand nach der Tabelle im Dateikopf.
  const vo2maxVorweg = '''
    ALTER TABLE tages_werte ADD COLUMN vo2max REAL;
  ''';

  /// Tims Bestand auf Stand v25 — quer durch beide Tabellengruppen, damit
  /// „additiv" nicht nur für `tages_werte` belegt ist. Die erste
  /// `tages_werte`-Zeile trägt **alle elf** Spalten, die zweite ist
  /// absichtlich lückig: Ihre NULLs müssen NULLs bleiben. Eine Migration,
  /// die hier etwas verlöre oder auffüllte, verlöre bzw. erfände es
  /// endgültig.
  ///
  /// Dazu eine Gym-Sitzung mit ihrem Satz: Das ist Tims einzige Kopie
  /// seiner Trainings, und eine Stufe, die an `tages_werte` arbeitet, hat
  /// dort nichts zu suchen. `trainings_name` bleibt dabei absichtlich
  /// leer — eine alte Sitzung bekommt keinen erfundenen Namen.
  const bestand = '''
    INSERT INTO tages_werte
      (tag, schritte, ruhepuls_bpm, gelesen_am, hrv_ms, resp_rate,
       recovery_hr_drop, gewicht_kg, trainings_minuten, koerperfett_pct,
       fettfrei_kg)
      VALUES ('2099-03-01', 4321, 55, '2099-03-01T08:00:00.000Z', 38.4,
              15.1, 27, 81.3, 47.5, 21.2, 63.9);
    INSERT INTO tages_werte (tag, schritte)
      VALUES ('2099-03-02', 1234);
    INSERT INTO stunden_schritte (tag, stunde, schritte)
      VALUES ('2099-03-01', 9, 876);
    INSERT INTO naechte (tag, gelesen_am, ruhepuls_bpm, hrv_ms, resp_rate)
      VALUES ('2099-03-01', '2099-03-01T08:00:00.000Z', 52.5, 41.1, 14.8);
    INSERT INTO schlaf_abschnitte (tag, quelle, lfd_nr, phase, beginn, ende)
      VALUES ('2099-03-01', 0, 0, 'core',
              '2099-02-28T21:00:00.000Z', '2099-03-01T04:30:00.000Z');
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
              'Prüfknäcke', 11.8, 44.6, '{}', 'PRUEF-UUID-0025',
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
    INSERT INTO umfaenge (tag, mass, zentimeter, eingetragen_am, quelle)
      VALUES ('2099-03-01', 'pruefmassA', 41.4, '2099-03-01T07:05:00.000Z',
              'getippt');
    INSERT INTO gym_sitzungen
      (id, tag, zeitpunkt, workout, minuten, notiz, health_uuid,
       aufwaermen_uebersprungen)
      VALUES ('PRUEF-S1', '2099-03-01', '2099-03-01T17:00:00.000Z', 'Push',
              70, 'Prüfnotiz', NULL, 1);
    INSERT INTO gym_saetze
      (sitzung_id, uebung_id, uebung_pos, satz_nr, gewicht_kg, wdh,
       zeitpunkt)
      VALUES ('PRUEF-S1', 'benchPress', 1, 1, 62.5, 8,
              '2099-03-01T17:10:00.000Z');
  ''';

  /// Eine Zeile, wie der andere Zweig sie mit seinem Stand geschrieben
  /// haben könnte — mit einem VO₂max-Wert, den die Stufe nicht anrühren
  /// darf.
  const vo2maxZeileVorweg = '''
    INSERT INTO tages_werte (tag, schritte, vo2max)
      VALUES ('2099-03-03', 2222, 47.9);
  ''';

  /// Schema v11, wörtlich aus `schema_v27_test.dart`: acht Tabellen, noch
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
  ///
  /// **`gym_trainings`, `gym_training_uebungen`, `gym_training_tags` und
  /// `gym_rotation` stehen hier absichtlich nicht.** In die schreibt
  /// `beforeOpen` beim ersten Öffnen die Startbefüllung — Push, Pull, Legs
  /// und die Rotation (Stufe 27, #532) —, und das ist so gewollt. Eine
  /// Zeilenzahl, die „bleibt gleich" verlangt, wäre dort schlicht falsch;
  /// was diese Tabellen angeht, prüft `schema_v27_test.dart`.
  /// `gym_sitzungen` und `gym_saetze` fasst die Startbefüllung nicht an
  /// und stehen deshalb hier.
  const alle = [
    'tages_werte',
    'stunden_schritte',
    'naechte',
    'schlaf_abschnitte',
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
    'gym_sitzungen',
    'gym_saetze',
  ];

  /// Die elf Spalten, die `tages_werte` vor dieser Stufe hat — sie müssen
  /// danach alle noch da sein. Kein exakter Satz: siehe Dateikopf,
  /// „Festlegungen des Test-Agenten".
  const alteSpalten = {
    'tag',
    'schritte',
    'ruhepuls_bpm',
    'gelesen_am',
    'hrv_ms',
    'resp_rate',
    'recovery_hr_drop',
    'gewicht_kg',
    'trainings_minuten',
    'koerperfett_pct',
    'fettfrei_kg',
  };

  // --- Hilfsmittel, wie in `schema_v27_test.dart` ------------------------

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

  Set<String> rohSpalten(Database roh, String tabelle) => {
    for (final z in roh.select('PRAGMA table_info($tabelle);'))
      z['name'] as String,
  };

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

  /// Der SQLite-Speichertyp eines Feldes (`'null'`, `'real'`, …). Schärfer
  /// als ein Dart-seitiger `isNull`-Vergleich: Er zeigt, dass in der Spalte
  /// wirklich nichts steht — kein `0.0`, das Dart vielleicht noch als Zahl
  /// durchreichte (`schema_v7_test.dart`).
  Future<String> speichertyp(AppCache db, String spalte, String tag) async {
    final zeile = await db
        .customSelect(
          'SELECT typeof($spalte) AS typ FROM tages_werte WHERE tag = ?;',
          variables: [Variable<String>(tag)],
        )
        .getSingle();
    return zeile.read<String>('typ');
  }

  /// Die Form der neuen Spalte nach der Tabelle im Dateikopf — und dass
  /// die elf alten Spalten noch da sind und `tag` der Schlüssel bleibt.
  Future<void> pruefeForm(AppCache db) async {
    final s = await spalten(db, 'tages_werte');

    expect(
      s.keys.toSet(),
      containsAll(alteSpalten),
      reason:
          'die Stufe ergänzt, sie baut nicht um — alle elf bisherigen '
          'Spalten bleiben',
    );
    expect(
      s.keys,
      contains(neueSpalte),
      reason:
          'die Spalte vo2max in tages_werte ist der ganze Inhalt der '
          'Stufe 28: Ohne sie bleibt DailyMetrics.vo2max hinter der '
          'geerbten Schemagrenze aus Task 6, und die VO₂max-Anzeige des '
          'Ausdauer-Schirms stünde nach jedem Kaltstart erst leer da (#95)',
    );

    expect(
      s[neueSpalte]!.typ,
      'REAL',
      reason:
          'DailyMetrics.vo2max ist double? — eine Ganzzahlspalte zwänge '
          'die Brücke zu runden, und gerundete ml/kg/min wären eine stille '
          'Veränderung von Tims Daten auf dem Weg in den Cache',
    );
    expect(
      s[neueSpalte]!.nullbar,
      isTrue,
      reason:
          'nullbar wie jede Metrikspalte: An einem Tag ohne '
          'Ausdauereinheit mit der Uhr gibt es diesen Wert schlicht nicht, '
          'und „VO₂max 0" wäre ein absurder Messwert, kein fehlender',
    );
    expect(
      s[neueSpalte]!.schluesselNr,
      0,
      reason: 'der Schlüssel von tages_werte ist tag und bleibt es',
    );
    expect(
      s[neueSpalte]!.vorgabe,
      isNull,
      reason:
          'kein Vorgabewert — eine Vorgabe erfände eine Messung, die '
          'niemand gemacht hat',
    );
    expect(s['tag']!.schluesselNr, 1);
  }

  // ═════════════════════════════════════════════════════════════════════

  group('Vorbedingungen: die Altstände sind so gebaut, wie sie gemeint '
      'sind', () {
    test('v27 hat alle heutigen Tabellen, und tages_werte hat die Spalte '
        'nicht', () {
      final roh = rohdatei(v27Schema, bestand, 27);
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
        tabellenHeute,
        reason:
            'die Stufe 28 legt keine Tabelle an — v27 hat bereits alle '
            'heutigen; nur die Spalte fehlt',
      );
      expect(rohSpalten(roh, 'tages_werte'), alteSpalten);
      expect(rohZeilen(roh, 'tages_werte'), hasLength(2));
      expect(rohZeilen(roh, 'umfaenge'), hasLength(1));
      expect(rohZeilen(roh, 'wach_belege'), hasLength(1));
    });

    test('v27 vorweg trägt die Spalte schon, mit einem Wert', () {
      final roh = rohdatei(
        v27Schema + vo2maxVorweg,
        bestand + vo2maxZeileVorweg,
        25,
      );
      addTearDown(roh.close);
      expect(rohSpalten(roh, 'tages_werte'), contains(neueSpalte));
      expect(rohZeilen(roh, 'tages_werte'), hasLength(3));
    });
  });

  group('Schema v28 (#95) — frisch angelegt', () {
    test('die Version ist mindestens 26 und steht so in der Datei', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      expect(db.schemaVersion, greaterThanOrEqualTo(28));
      expect(await abgelegteVersion(db), db.schemaVersion);
    });

    test('ein frischer Cache hat die Spalte in der verlangten Form — und '
        'keine neue Tabelle', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      await pruefeForm(db);
      expect(
        await tabellen(db),
        tabellenHeute,
        reason:
            'die Stufe 28 ist eine Spalte, keine Tabelle — der '
            'Tabellensatz bleibt der der Stufe 27',
      );
    });
  });

  group('Migration v27 → heute', () {
    test('ergänzt die Spalte in der verlangten Form, und die Datei steht '
        'danach auf der heutigen Version', () async {
      final roh = rohdatei(v27Schema, bestand, 27);
      addTearDown(roh.close);
      final db = ueber(roh);
      addTearDown(db.close);

      expect(await abgelegteVersion(db), db.schemaVersion);
      expect(
        await abgelegteVersion(db),
        greaterThanOrEqualTo(28),
        reason: 'die Stufe 28 ist über diesen Bestand gelaufen',
      );
      await pruefeForm(db);
    });

    test('füllt nichts nach — vo2max steht auf Bestandszeilen wirklich auf '
        'NULL, nicht auf 0 und nicht auf einem erfundenen Wert', () async {
      final roh = rohdatei(v27Schema, bestand, 27);
      addTearDown(roh.close);
      final db = ueber(roh);
      addTearDown(db.close);

      expect(
        await speichertyp(db, neueSpalte, '2099-03-01'),
        'null',
        reason:
            'für diese Zeile wurde nie eine VO₂max geholt. Eine Migration, '
            'die hier einen Wert einträgt, behauptete eine Messung, die es '
            'nicht gab (CLAUDE.md, Tests) — und ein 0.0 käme als "real" '
            'heraus, ein Wert vom Nachbartag auch. NULL heißt „nie '
            'gemessen", und das ist die Wahrheit',
      );
      expect(await speichertyp(db, neueSpalte, '2099-03-02'), 'null');
    });

    test(
      'additiv: jede Zeile und jeder Wert bleibt, in allen Tabellen',
      () async {
        final roh = rohdatei(v27Schema, bestand, 27);
        addTearDown(roh.close);
        final vorher = {for (final t in alle) t: rohZeilen(roh, t)};

        final db = ueber(roh);
        addTearDown(db.close);

        expect(
          await abgelegteVersion(db),
          greaterThanOrEqualTo(28),
          reason: 'die Stufe 28 ist über diesen Bestand gelaufen',
        );
        for (final t in alle) {
          pruefeUnveraendert(vorher[t]!, await zeilen(db, t), t);
        }
      },
    );

    test('die volle Bestandszeile behält alle elf Werte wortgleich — auch '
        'ihren Stand', () async {
      final roh = rohdatei(v27Schema, bestand, 27);
      addTearDown(roh.close);
      final db = ueber(roh);
      addTearDown(db.close);

      final zeile = (await db
              .customSelect(
                "SELECT * FROM tages_werte WHERE tag = '2099-03-01';",
              )
              .getSingle())
          .data;

      expect(zeile['schritte'], 4321);
      expect(zeile['ruhepuls_bpm'], 55);
      expect(zeile['hrv_ms'], 38.4);
      expect(zeile['resp_rate'], 15.1);
      expect(zeile['recovery_hr_drop'], 27);
      expect(zeile['gewicht_kg'], 81.3);
      expect(zeile['trainings_minuten'], 47.5);
      expect(zeile['koerperfett_pct'], 21.2);
      expect(zeile['fettfrei_kg'], 63.9);
      expect(
        zeile['gelesen_am'],
        '2099-03-01T08:00:00.000Z',
        reason:
            'der Stand überlebt die Migration — er wird nicht auf „jetzt" '
            'gesetzt. Ein erfundener Zeitstempel behauptete, die Zeile sei '
            'frisch (CLAUDE.md, Tests)',
      );
      expect(zeile[neueSpalte], isNull);
    });

    test('ein zweites Öffnen derselben Datei ändert am Schema nichts mehr, '
        'und ein inzwischen geschriebener Wert bleibt', () async {
      final roh = rohdatei(v27Schema, bestand, 27);
      addTearDown(roh.close);

      final erstes = ueber(roh);
      await erstes.customStatement(
        "UPDATE tages_werte SET vo2max = 47.9 WHERE tag = '2099-03-01';",
      );
      await erstes.close();
      final nachErstem = schemaZaehler(roh);
      final zeilenNachErstem = rohZeilen(roh, 'tages_werte');

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
        zeilenNachErstem.first[neueSpalte],
        47.9,
        reason: 'Vorbedingung: der Wert ist geschrieben',
      );
      pruefeUnveraendert(
        zeilenNachErstem,
        await zeilen(zweites, 'tages_werte'),
        'tages_werte',
      );
    });
  });

  group('Die Stufe ist zweimal ausführbar (#234/#240)', () {
    test('steht die Spalte schon da, öffnet die Datei — kein „duplicate '
        'column name" — und jeder Wert darin bleibt', () async {
      final roh = rohdatei(
        v27Schema + vo2maxVorweg,
        bestand + vo2maxZeileVorweg,
        25,
      );
      addTearDown(roh.close);
      final vorher = {for (final t in alle) t: rohZeilen(roh, t)};

      final db = ueber(roh);
      addTearDown(db.close);

      expect(await abgelegteVersion(db), db.schemaVersion);
      expect(
        await abgelegteVersion(db),
        greaterThanOrEqualTo(28),
        reason:
            'die Stufe 28 lief über eine Datei, die ihre Spalte schon trug, '
            'und scheiterte nicht an „duplicate column name" — jedes '
            'addColumn geht über _addColumnIfMissing (#234). Alle Zweige '
            'bauen unter derselben Bundle-ID und benutzen dieselbe Datei',
      );
      for (final MapEntry(key: t, value: z) in vorher.entries) {
        pruefeUnveraendert(z, await zeilen(db, t), t);
      }
      await pruefeForm(db);
      expect(
        (await zeilen(db, 'tages_werte')).last[neueSpalte],
        47.9,
        reason:
            'der Wert des anderen Zweigs ist Tims Wert — die Stufe nimmt '
            'ihn nicht weg und setzt ihn nicht zurück',
      );
    });
  });

  group('Abgleich beim Öffnen (#233)', () {
    test('eine Datei auf 26, der die Spalte fehlt, bekommt sie — leer, und '
        'verliert nichts', () async {
      // Ein Zweig hat die Nummer hochgezogen, bevor seine Stufe fertig
      // war: `if (from < 26)` läuft dann nie.
      final roh = rohdatei(v27Schema, bestand, 26);
      addTearDown(roh.close);
      final vorher = {for (final t in alle) t: rohZeilen(roh, t)};

      final db = ueber(roh);
      addTearDown(db.close);
      // Der erste Zugriff: Das Öffnen selbst ist bei drift lazy.
      await db.customSelect('SELECT 1;').get();

      expect(
        (await spalten(db, 'tages_werte')).keys,
        contains(neueSpalte),
        reason:
            'onUpgrade läuft bei from == 26 nicht in die Stufe 28 — die '
            'Spalte kommt nur über den Abgleich',
      );
      await pruefeForm(db);
      expect(await speichertyp(db, neueSpalte, '2099-03-01'), 'null');
      for (final t in alle) {
        pruefeUnveraendert(vorher[t]!, await zeilen(db, t), t);
      }
    });
  });

  group('Von weit unten: v11 → heute', () {
    test('ein v11-Stand öffnet ohne Fehler und hat danach die Spalte, '
        'leer', () async {
      final roh = rohdatei(v11Schema, v11Bestand, 11);
      addTearDown(roh.close);
      final vorher = {
        for (final t in ['tages_werte', 'stammdaten']) t: rohZeilen(roh, t),
      };

      final db = ueber(roh);
      addTearDown(db.close);

      // Scheiterte eine Stufe, würfe schon dieser erste Zugriff.
      expect(await abgelegteVersion(db), db.schemaVersion);
      expect(await tabellen(db), tabellenHeute);
      await pruefeForm(db);
      expect(
        await speichertyp(db, neueSpalte, '2099-03-01'),
        'null',
        reason:
            'auch über fünfzehn Stufen hinweg bleibt die neue Spalte '
            'wirklich leer — kein 0, kein erfundener Wert',
      );
      for (final MapEntry(key: t, value: z) in vorher.entries) {
        pruefeUnveraendert(z, await zeilen(db, t), t);
      }
    });
  });

  group('CacheRepository reicht den Wert durch (#95, Rundweg)', () {
    test('vo2max kommt nach dem Zurückschreiben wieder aus dem Cache — '
        'vorher war er immer null (geerbte Schemagrenze)', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = CacheRepository(db);

      await repo.schreibeTagesWerte(const [
        DailyMetrics(tag: '2099-03-01', steps: 4321, vo2max: 48.7),
      ], gelesenAm: DateTime.utc(2099, 3, 1, 14, 32));

      final zeile = (await repo.liesTagesWerte(DataWindow.unlimited))!
          .werte
          .single;

      expect(zeile.steps, 4321);
      expect(
        zeile.vo2max,
        48.7,
        reason:
            'genau der Wert, den der Ausdauer-Schirm braucht — „Zuerst der '
            'Cache, dann HealthKit". Käme er weiter als null zurück, stünde '
            'die VO₂max-Anzeige nach jedem Kaltstart erst leer da (#95); '
            'und die Nachkommastelle gehört dazu, eine gerundete 49 wäre '
            'eine stille Veränderung von Tims Wert',
      );
    });

    test('in der Datei liegt der Wert als REAL, nicht als Text und nicht '
        'gerundet', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = CacheRepository(db);

      await repo.schreibeTagesWerte(const [
        DailyMetrics(tag: '2099-03-01', vo2max: 48.7),
      ], gelesenAm: DateTime.utc(2099, 3, 1, 14, 32));

      final zeile = await db
          .customSelect(
            'SELECT vo2max, typeof(vo2max) AS typ FROM tages_werte '
            "WHERE tag = '2099-03-01';",
          )
          .getSingle();
      expect(zeile.read<String>('typ'), 'real');
      expect(zeile.read<double>('vo2max'), 48.7);
    });

    test('ein Tag ohne vo2max bleibt auch dann null, wenn der Nachbartag im '
        'selben Lauf einen Wert hat — und in der Datei steht NULL, nicht '
        '0', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = CacheRepository(db);

      await repo.schreibeTagesWerte(const [
        DailyMetrics(tag: '2099-03-01', steps: 7000),
        DailyMetrics(tag: '2099-03-02', steps: 8000, vo2max: 48.7),
      ], gelesenAm: DateTime.utc(2099, 3, 2, 14, 32));

      final werte = (await repo.liesTagesWerte(DataWindow.unlimited))!.werte;
      expect(werte.map((w) => w.tag).toList(), ['2099-03-01', '2099-03-02']);
      expect(
        werte.first.vo2max,
        isNull,
        reason:
            'am 1. gab es keine Ausdauereinheit mit der Uhr — kein '
            'Übernehmen vom Nachbartag, kein 0. nil darf auf dem Weg durch '
            'den Kanal und den Cache niemals zu 0 werden (CLAUDE.md, '
            'Fehler 01)',
      );
      expect(werte.last.vo2max, 48.7);
      expect(
        await speichertyp(db, neueSpalte, '2099-03-01'),
        'null',
        reason:
            'schärfer als der Dart-Vergleich darüber: In der Datei steht '
            'wirklich NULL, kein 0.0, das die Brücke vielleicht noch '
            'durchreichte',
      );
    });

    test('und die neue Spalte ist nach der Migration wirklich benutzbar — '
        'ein Lauf schreibt in die migrierte Zeile', () async {
      final roh = rohdatei(v27Schema, bestand, 27);
      addTearDown(roh.close);
      final db = ueber(roh);
      addTearDown(db.close);
      final repo = CacheRepository(db);

      await repo.schreibeTagesWerte(const [
        DailyMetrics(tag: '2099-03-01', steps: 4321, vo2max: 48.7),
      ], gelesenAm: DateTime.utc(2099, 3, 2, 7));

      final werte = (await repo.liesTagesWerte(DataWindow.unlimited))!.werte;
      final zeile = werte.singleWhere((w) => w.tag == '2099-03-01');
      expect(zeile.vo2max, 48.7);
    });
  });
}
