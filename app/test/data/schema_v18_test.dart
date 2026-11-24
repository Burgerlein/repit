// `drift` exportiert eigene `isNull` und `isNotNull` — dieselbe Begründung
// wie in `test/data/schema_v13_test.dart`, Zeile 1–5.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show Database, sqlite3;

import 'package:repit/data/cache.dart';

import 'schema_tabellen.dart';

/// Tests für **Schema v18** — die Ablage der Gym-Trainings (#78, mit #418).
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden. Jede Migration
/// bekommt einen Test — dies ist der für die Stufe 18.
///
/// Geschrieben nach
/// `docs/superpowers/specs/2026-11-10-gym-training-eintragen-design.md`,
/// Abschnitt 10.2 („Weg B — eigene Tabellen"), 10.4 und 17.2, dazu Tims
/// Entscheidungen vom 10.11.2026 — **ohne** den Code der Stufe gesehen zu
/// haben (es gab ihn beim Schreiben noch nicht). Die Nummer wurde am
/// 10.11.2026 aus `cache.dart` gelesen (`schemaVersion => 17`), also ist
/// die nächste freie die 18.
///
/// Nachbar von `schema_v17_test.dart`: derselbe Aufbau, dieselben
/// Hilfsmittel, von Hand gebaute Altstände — **nicht** aus dem heutigen
/// Code erzeugt (`migration_test.dart`, Dateikopf).
///
/// ## Was diese Datei verbindlich vorgibt
///
/// **1. `AppCache.schemaVersion >= 18`** und eine **eigene Stufe**
/// `if (from < 18) { … }`. Geprüft mit `>=`, damit diese Datei bei der
/// nächsten Stufe nicht mitfällt (#208).
///
/// **2. Drei neue Tabellen**, sonst keine. Die siebzehn bestehenden bleiben,
/// wie sie sind.
///
/// `gym_sitzungen` — eine Zeile je abgeschlossenem Training:
///
/// | Spalte | Typ | NULL | Vorgabe | Drift-Name |
/// |---|---|---|---|---|
/// | `id` | TEXT, PK | nein | — | `id` |
/// | `tag` | TEXT | nein | — | `tag` |
/// | `zeitpunkt` | TEXT | nein | — | `zeitpunkt` |
/// | `workout` | TEXT | **ja** | — | `workout` |
/// | `minuten` | INTEGER | **ja** | — | `minuten` |
/// | `notiz` | TEXT | **ja** | — | `notiz` |
/// | `health_uuid` | TEXT | **ja** | — | `healthUuid` |
/// | `aufwaermen_art` | TEXT | **ja** | — | `aufwaermenArt` |
/// | `aufwaermen_minuten` | INTEGER | **ja** | — | `aufwaermenMinuten` |
/// | `aufwaermen_km` | REAL | **ja** | — | `aufwaermenKm` |
/// | `aufwaermen_uebersprungen` | INTEGER | nein | `0` | `aufwaermenUebersprungen` |
/// | `aufwaermen_health_uuid` | TEXT | **ja** | — | `aufwaermenHealthUuid` |
///
/// dazu **`UNIQUE (tag, workout)`** und
/// **`CHECK (aufwaermen_art IS NULL OR aufwaermen_art IN (…))`** über die
/// sechs Arten aus #40.
///
/// **Das Aufwärmen (#40) steht in Spalten, nicht in einer dritten
/// Tabelle.** Es gibt **eine** Einheit je Sitzung, sie wird immer zusammen
/// mit der Sitzung gelesen und kann ohne sie nicht bestehen — genau die
/// Begründung, mit der die Spec in 10.2 `gym_uebungen` wegließ („wäre bei
/// jeder Abfrage ein Join mehr"). Auch die Auswertung über die Zeit wird
/// damit eine Abfrage über **eine** Tabelle statt ein Join.
///
/// Die drei Zustände — nichts eingetragen, übersprungen, ausgefüllt —
/// stehen so in der Datei:
///
/// | Zustand | `aufwaermen_art` | `aufwaermen_minuten` | `aufwaermen_uebersprungen` |
/// |---|---|---|---|
/// | nichts eingetragen | NULL | NULL | `0` |
/// | übersprungen | NULL | NULL | `1` |
/// | ausgefüllt | gesetzt | gesetzt | `0` |
///
/// `aufwaermen_km` ist **auch im ausgefüllten Fall nullbar**: Bei Mobility
/// gibt es keine Strecke, und eine `0` behauptete „null Kilometer
/// gelaufen" (#40, `CLAUDE.md` zu Fehler `01`).
///
/// `gym_saetze` — eine Zeile je Satz, PK `(sitzung_id, uebung_id, satz_nr)`:
///
/// | Spalte | Typ | NULL | Vorgabe | Drift-Name |
/// |---|---|---|---|---|
/// | `sitzung_id` | TEXT | nein | — | `sitzungId` |
/// | `uebung_id` | TEXT | nein | — | `uebungId` |
/// | `uebung_pos` | INTEGER | nein | — | `uebungPos` |
/// | `satz_nr` | INTEGER | nein | — | `satzNr` |
/// | `gewicht_kg` | REAL | nein | — | `gewichtKg` |
/// | `wdh` | INTEGER | nein | — | `wdh` |
/// | `zeitpunkt` | TEXT | **ja** | **—** | `zeitpunkt` |
///
/// `gym_entwuerfe` — **genau ein** Entwurf, PK `id` mit Vorgabe `0`:
///
/// | Spalte | Typ | NULL | Vorgabe | Drift-Name |
/// |---|---|---|---|---|
/// | `id` | INTEGER, PK | nein | `0` | `id` |
/// | `workout` | TEXT | nein | — | `workout` |
/// | `sitzung_id` | TEXT | nein | — | `sitzungId` |
/// | `zeitpunkt` | TEXT | nein | — | `zeitpunkt` |
/// | `dauer` | TEXT | **ja** | — | `dauer` |
/// | `notiz` | TEXT | **ja** | — | `notiz` |
/// | `gespeichert_am` | TEXT | nein | — | `gespeichertAm` |
/// | `felder` | TEXT | nein | — | `felder` |
///
/// **3. Die Stufe legt keine Zeile an und füllt nichts.** Es gibt keine
/// Gym-Daten vor Stufe 18; die Stufe legt leere Tabellen an. Keine
/// erfundenen Zeitstempel, keine Platzhalterzeile (Spec 10.4 Punkt 5).
///
/// **4. `gym_saetze.zeitpunkt` ist nullbar und hat keinen Vorgabewert.**
/// Das ist die Spalte aus Abschnitt 11: Die Übernahme aus der alten App
/// (#59) kennt keine Satz-Uhrzeiten, und ein Vorgabewert — ob `now`, ob
/// `0`, ob Epoch-Null — behauptete, der Satz sei zu dieser Minute gehoben
/// worden. `null` heißt hier ehrlich „nicht erfasst", und das ist der
/// **Normalfall** für alles Übernommene, nicht der Randfall (Tim,
/// 10.11.2026).
///
/// **5. Zweimal ausführbar** (#234/#240): Ein v17-Stand, auf dem ein anderer
/// Zweig die Tabellen schon angelegt hat, öffnet, und seine Zeilen bleiben.
///
/// **6. Abgleich** (#233): Einer Datei, die schon auf 18 steht, der aber
/// `gym_saetze` fehlt, legt das Öffnen die Tabelle an.
///
/// **7. Von weit unten:** Ein v11-Stand läuft durch alle Stufen durch.
///
/// **8. Zeitstempel kommen als UTC und gleich sich selbst zurück**
/// (`storeDateTimeAsText`, `CLAUDE.md`) — auch der nullbare Satz-Zeitpunkt.
///
/// **9. Kein zusätzlicher Index.** Die Eindeutigkeit über `(tag, workout)`
/// steht als **Tabellen-Constraint** in `CREATE TABLE`, nicht als eigenes
/// `CREATE UNIQUE INDEX`. Grund: `_reconcileSchema` kennt keine Indizes
/// (`cache.dart`, Doc-Kommentar; `schema_v17_test.dart`, Punkt 10). Ein
/// eigenständiger Index stünde auf Geräten, die die Stufe 18 gelaufen sind,
/// und fehlte auf Geräten, die die Tabelle über den Abgleich bekommen
/// haben — ein `UNIQUE` im Tabellenkopf wandert mit der Tabelle, auf
/// beiden Wegen. In drift: `uniqueKeys`, nicht `@TableIndex`.
///
/// ## Festlegungen des Test-Agenten — nicht von Tim freigegeben
///
/// - **Die Namen der Spalten und Tabellen** sind die der Spec, Abschnitt
///   10.2; die Drift-Namen oben sind daraus abgeleitet (`lowerCamelCase`,
///   wie überall in `lib/data/`).
/// - **`gym_entwuerfe` trägt eine `id`-Spalte mit Vorgabe `0` als
///   Schlüssel** statt `workout` als Schlüssel, wie die Spec sie in
///   Abschnitt 10.2 zeichnet. Grund ist Tims Entscheidung vom 10.11.2026,
///   Punkt 5: **„Ein Entwurf, nicht sieben."** Mit `workout` als Schlüssel
///   könnten sieben Zeilen nebeneinander stehen, und die Regel bliebe eine
///   Zusage im Dart-Code; mit `id DEFAULT 0` ist sie eine Eigenschaft der
///   Datenbank — dasselbe Muster wie `ziel_werte`, `stammdaten` und
///   `ki_einstellungen`. Die Spec ist hier älter als die Entscheidung.
///   **Das gehört gemeldet, nicht stillschweigend gedreht.**
/// - **„—" in der Vorgabe-Spalte heißt „kein Vorgabewert".**
/// - **Kein Fremdschlüssel-Constraint** (`REFERENCES`) auf
///   `gym_saetze.sitzung_id`: SQLite erzwingt Fremdschlüssel nur bei
///   eingeschaltetem `PRAGMA foreign_keys`, und der steht in dieser App
///   nirgends. Ein `REFERENCES`, das nie prüft, ist eine Zusage, die der
///   Code nicht durchsetzt (`CLAUDE.md`). Dass die Sätze an ihrer Sitzung
///   hängen, hält `gym_ablage_test.dart` fest.
/// - **Keine `CHECK`-Bedingung auf `wdh`.** Dass ein Satz ohne
///   Wiederholungen keiner ist, prüft `gym_ablage_test.dart` am Vertrag der
///   Ablage. Ob es zusätzlich in der Datenbank stehen soll, ist eine
///   offene Frage und wird hier nicht entschieden.
/// - **`aufwaermen_art` bekommt sehr wohl eine `CHECK`-Bedingung.** #40
///   verlangt ausdrücklich „eine kurze Auswahl […], nicht als freies Feld:
///   Freitext lässt sich später nicht vergleichen, und vergleichen ist der
///   Zweck". Ein Wertebereich, der nur im Dart-Enum steht, lässt eine
///   fremde Zeichenkette in der Datei zu, und die fiele erst Monate später
///   auf — beim Vergleichen.
/// - **Die abgelegten Codes sind englisch** (`bike`, `treadmill`, `rowing`,
///   `cross_trainer`, `jump_rope`, `mobility`), wie `Workout.code`:
///   Spaltenwerte sind Code, keine Oberfläche. Die deutschen
///   Beschriftungen stehen in der Ansicht.
/// - **Nicht abgedeckt:** eine Datei, auf der ein anderer Zweig
///   `gym_sitzungen` **ohne** die Aufwärm-Spalten angelegt hat. Dort müsste
///   `_addColumnIfMissing` die Spalte samt ihrer `CHECK`-Bedingung
///   nachtragen, und ob drifts `addColumn` die Bedingung mitschreibt, hat
///   der Test-Agent nicht nachgesehen (er hätte dafür in den Code sehen
///   müssen). **Das ist eine Lücke und gehört gemeldet**, nicht
///   stillschweigend gelassen.
///
/// ## Bestehende Tests, die mit dieser Stufe mitgehen müssen
///
/// Der Test-Agent hat **keine** bestehende Testdatei angefasst (Auftrag).
/// Mit der Implementierung werden rot und brauchen `TEST_AENDERN=1`:
///
/// - `schema_tabellen.dart` — die drei neuen Tabellen fehlen in
///   `tabellenHeute`; davon hängen `schema_abgleich_test.dart`,
///   `schema_stufen_robust_test.dart`, `schema_fremde_spalten_test.dart`
///   und die Stufen-Tests ab.
/// - `migration_test.dart:258` — nennt die absolute Zahl `17`.
/// - `schema_abgleich_test.dart:608` — `heutigeNummer = 17`.
///
/// Diese Datei drückte ihren Endstand ursprünglich als
/// `tabellenHeute + tabellenAusStufe18` aus, weil `schema_tabellen.dart`
/// die drei Gym-Tabellen noch nicht kannte. **Am 10.11.2026 nachgezogen
/// (`TEST_AENDERN=1`):** Die Liste dort führt sie jetzt als
/// `tabellenAusStufe18`, und `tabellenHeute` ist wieder, was der Name
/// sagt — alle Tabellen, die es heute gibt.
///
/// ## Beim Zusammenführen mit `umfaenge-88` (11.11.2026, #485)
///
/// Der Zweig `umfaenge-88` hatte unabhängig **ebenfalls** eine Stufe 18
/// vergeben (`kalorienziele`, #410) und darüber die Stufen 19 bis 23.
/// Diese Stufe **bleibt die 18**: Sie ist auf Tims iPhone schon gelaufen
/// und dort in der Datei vermerkt; verschöbe man sie, liefe sie dort nie
/// wieder, und `gym_sitzungen` — seine einzige Kopie der Trainings —
/// hinge allein am Abgleich beim Öffnen. Die Stufen von `umfaenge-88`
/// sind stattdessen um eins nach oben gerückt (19 bis 24). An dieser
/// Datei hat das nur eines geändert: Die Vorbedingung über den v17-Stand
/// nimmt jetzt auch die Tabellen der Stufen 19 bis 24 aus dem Vergleich,
/// weil `tabellenHeute` sie seitdem führt. Nachgezogen beim
/// Zusammenführen, **Tim hat die Änderung nicht gesehen**.
///
/// **Alle Zahlen, Namen und Zeitpunkte hier sind erfunden.** Die Zeitpunkte
/// liegen im Jahr 2099. Es stehen keine echten Trainingsdaten darin.
void main() {
  // `tabellenAusStufe18` und `tabellenHeute` kommen seit dem 10.11.2026
  // aus `schema_tabellen.dart` — eine Stelle statt zwei (#304).
  const tabellenNachStufe18 = tabellenHeute;

  // --- Altstände, von Hand -----------------------------------------------

  /// Die siebzehn Tabellen auf Stand v17, so wie sie auf einem Gerät
  /// liegen, das die Stufe 18 noch nicht kennt. Wörtlich aufgeschrieben,
  /// nicht aus `AppCache` erzeugt.
  const v17Schema = '''
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
      portion_g REAL
    );
  ''';

  /// Die sechs Arten des Aufwärmens aus #40, als abgelegte Codes.
  const aufwaermArten = [
    'bike',
    'treadmill',
    'rowing',
    'cross_trainer',
    'jump_rope',
    'mobility',
  ];

  /// `gym_sitzungen`, wie ein anderer Zweig sie angelegt haben könnte.
  final gymSitzungenVorweg =
      '''
    CREATE TABLE gym_sitzungen (
      id TEXT NOT NULL PRIMARY KEY,
      tag TEXT NOT NULL,
      zeitpunkt TEXT NOT NULL,
      workout TEXT,
      minuten INTEGER,
      notiz TEXT,
      health_uuid TEXT,
      aufwaermen_art TEXT CHECK (aufwaermen_art IS NULL OR aufwaermen_art
        IN (${aufwaermArten.map((a) => "'$a'").join(', ')})),
      aufwaermen_minuten INTEGER,
      aufwaermen_km REAL,
      aufwaermen_uebersprungen INTEGER NOT NULL DEFAULT 0
        CHECK (aufwaermen_uebersprungen IN (0, 1)),
      aufwaermen_health_uuid TEXT,
      UNIQUE (tag, workout)
    );
  ''';

  /// Die drei Gym-Tabellen, wie ein anderer Zweig sie unter derselben
  /// Bundle-ID schon angelegt haben könnte (#234/#240).
  final gymTabellenVorweg =
      '''
    $gymSitzungenVorweg
    CREATE TABLE gym_saetze (
      sitzung_id TEXT NOT NULL,
      uebung_id TEXT NOT NULL,
      uebung_pos INTEGER NOT NULL,
      satz_nr INTEGER NOT NULL,
      gewicht_kg REAL NOT NULL,
      wdh INTEGER NOT NULL,
      zeitpunkt TEXT,
      PRIMARY KEY (sitzung_id, uebung_id, satz_nr)
    );
    CREATE TABLE gym_entwuerfe (
      id INTEGER NOT NULL DEFAULT 0,
      workout TEXT NOT NULL,
      sitzung_id TEXT NOT NULL,
      zeitpunkt TEXT NOT NULL,
      dauer TEXT,
      notiz TEXT,
      gespeichert_am TEXT NOT NULL,
      felder TEXT NOT NULL,
      PRIMARY KEY (id)
    );
  ''';

  /// Tims Bestand auf Stand v17 — eine Zeile in jeder Tabelle, die etwas
  /// zu verlieren hat. Eine Migration, die hier etwas verlöre, verlöre es
  /// endgültig: Die Datenbank ist seine einzige Kopie.
  const bestand = '''
    INSERT INTO tages_werte (tag, schritte, ruhepuls_bpm, gelesen_am)
      VALUES ('2099-03-01', 4321, 55, '2099-03-01T08:00:00.000Z');
    INSERT INTO schlaf_eintraege
      (tag, art, lfd_nr, schlaf_minuten, beginn_minuten, ende_minuten, notiz)
      VALUES ('2099-03-01', 'nacht', 1, 444, 1350, 420, 'Prüfnacht');
    INSERT INTO stammdaten (id, groesse_cm, geburtsjahr, zielgewicht_kg)
      VALUES (0, 211, 1904, 33.3);
    INSERT INTO lebensmittel (id, name, kcal, herkunft)
      VALUES (1, 'Prüfknäcke', 377.7, 'eigen');
    INSERT INTO portionen (id, lebensmittel_id, name, menge_g, herkunft)
      VALUES (5, 1, 'Prüfbon', 5.9, 'eigen');
    INSERT INTO eintraege
      (id, tages_schluessel, mahlzeit, zeitpunkt, lebensmittel_id, name,
       menge_g, kcal, extra, health_stand, portion_id, portion_name,
       portion_g)
      VALUES (1, '2099-03-01', 'frueh', '2099-03-01T07:15:00.000Z', 1,
              'Prüfknäcke', 11.8, 44.6, '{}', 'geschrieben', 5, 'Prüfbon',
              5.9);
    INSERT INTO wasser_eintraege
      (id, tages_schluessel, zeitpunkt, menge_ml, health_stand)
      VALUES (4, '2099-03-01', '2099-03-01T09:15:00.000Z', 333.5, 'offen');
    INSERT INTO ki_einstellungen (id, modell, limit_usd, preise)
      VALUES (0, 'pruef-modell-x', 3.5, '{}');
  ''';

  /// Was in den vorweggenommenen Gym-Tabellen stehen könnte. Es gehört
  /// jemandem und muss bleiben — **mit einem Satz ohne Uhrzeit**, dem
  /// Normalfall der Übernahme (#59).
  const gymWerteVorweg = '''
    INSERT INTO gym_sitzungen
      (id, tag, zeitpunkt, workout, minuten, notiz, health_uuid,
       aufwaermen_art, aufwaermen_minuten, aufwaermen_km,
       aufwaermen_uebersprungen, aufwaermen_health_uuid)
      VALUES ('pruef-sitzung-1', '2099-03-01',
              '2099-03-01T17:30:00.000Z', 'A', 68, 'Prüfnotiz', NULL,
              'bike', 10, 3.4, 0, 'PRUEF-HK-RAD-1');
    INSERT INTO gym_saetze
      (sitzung_id, uebung_id, uebung_pos, satz_nr, gewicht_kg, wdh,
       zeitpunkt)
      VALUES ('pruef-sitzung-1', 'pruef-uebung', 1, 1, 42.5, 9,
              '2099-03-01T17:05:00.000Z');
    INSERT INTO gym_saetze
      (sitzung_id, uebung_id, uebung_pos, satz_nr, gewicht_kg, wdh,
       zeitpunkt)
      VALUES ('pruef-sitzung-1', 'pruef-uebung', 1, 2, -27.0, 8, NULL);
    INSERT INTO gym_entwuerfe
      (id, workout, sitzung_id, zeitpunkt, dauer, notiz, gespeichert_am,
       felder)
      VALUES (0, 'C', 'pruef-sitzung-2', '2099-03-02T16:00:00.000Z', '70',
              NULL, '2099-03-02T16:04:00.000Z', '{"pruef":true}');
  ''';

  /// Schema v11 — acht Tabellen, noch keine Ernährung. Wörtlich aus
  /// `schema_v17_test.dart`, das es aus `schema_v12_test.dart` hat.
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

  /// Die verlangte Form, Tabelle für Tabelle: Typ, Nullbarkeit,
  /// Schlüsseleigenschaft, Vorgabewert.
  const form = <String, Map<String, (String, bool, bool, String?)>>{
    'gym_sitzungen': {
      'id': ('TEXT', false, true, null),
      'tag': ('TEXT', false, false, null),
      'zeitpunkt': ('TEXT', false, false, null),
      'workout': ('TEXT', true, false, null),
      'minuten': ('INTEGER', true, false, null),
      'notiz': ('TEXT', true, false, null),
      'health_uuid': ('TEXT', true, false, null),
      'aufwaermen_art': ('TEXT', true, false, null),
      'aufwaermen_minuten': ('INTEGER', true, false, null),
      'aufwaermen_km': ('REAL', true, false, null),
      'aufwaermen_uebersprungen': ('INTEGER', false, false, '0'),
      'aufwaermen_health_uuid': ('TEXT', true, false, null),
    },
    'gym_saetze': {
      'sitzung_id': ('TEXT', false, true, null),
      'uebung_id': ('TEXT', false, true, null),
      'uebung_pos': ('INTEGER', false, false, null),
      'satz_nr': ('INTEGER', false, true, null),
      'gewicht_kg': ('REAL', false, false, null),
      'wdh': ('INTEGER', false, false, null),
      'zeitpunkt': ('TEXT', true, false, null),
    },
    'gym_entwuerfe': {
      'id': ('INTEGER', false, true, '0'),
      'workout': ('TEXT', false, false, null),
      'sitzung_id': ('TEXT', false, false, null),
      'zeitpunkt': ('TEXT', false, false, null),
      'dauer': ('TEXT', true, false, null),
      'notiz': ('TEXT', true, false, null),
      'gespeichert_am': ('TEXT', false, false, null),
      'felder': ('TEXT', false, false, null),
    },
  };

  // --- Hilfsmittel, wie in `schema_v17_test.dart` ------------------------

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
              '$tabelle, Zeile ${i + 1}, Spalte $key: ein vorhandener Wert '
              'ist Tims Wert',
        );
      }
    }
  }

  /// Die Spalten über `(tag, workout)`, die SQLite als eindeutig führt —
  /// samt der Herkunft (`u` = Tabellen-Constraint, `c` = eigenes
  /// `CREATE INDEX`, `pk` = Primärschlüssel).
  Future<List<({String herkunft, List<String> spalten})>> eindeutigkeiten(
    AppCache db,
    String tabelle,
  ) async {
    final liste = await db.customSelect('PRAGMA index_list($tabelle);').get();
    final out = <({String herkunft, List<String> spalten})>[];
    for (final i in liste) {
      if (i.read<int>('unique') != 1) continue;
      final name = i.read<String>('name');
      final info = await db.customSelect('PRAGMA index_info("$name");').get();
      out.add((
        herkunft: i.read<String>('origin'),
        spalten: [for (final s in info) s.data['name'] as String? ?? '?'],
      ));
    }
    return out;
  }

  /// Die Form aller drei Tabellen, nach den Tabellen im Dateikopf.
  Future<void> pruefeForm(AppCache db) async {
    for (final MapEntry(key: tabelle, value: erwartet) in form.entries) {
      final ist = await spalten(db, tabelle);
      // Seit der Stufe 25 (#532) trägt `gym_sitzungen` außerdem
      // `trainings_name`; die kennt Stufe 18 nicht. Die Form dieser Spalte
      // legt `schema_v25_test.dart` fest. Nachgezogen vom Test-Agenten,
      // **Tim hat die Änderung nicht gesehen**.
      final spaltenSpaeter = tabelle == 'gym_sitzungen'
          ? {'trainings_name'}
          : <String>{};
      expect(
        ist.keys.toSet().difference(spaltenSpaeter),
        erwartet.keys.toSet(),
        reason:
            '$tabelle trägt genau die Spalten aus Abschnitt 10.2 der Spec — '
            'keine mehr, keine weniger (ohne die späterer Stufen)',
      );
      for (final MapEntry(key: name, value: soll) in erwartet.entries) {
        final (typ, nullbar, schluessel, vorgabe) = soll;
        expect(ist[name]!.typ, typ, reason: '$tabelle.$name: Typ');
        expect(
          ist[name]!.nullbar,
          nullbar,
          reason: '$tabelle.$name: Nullbarkeit',
        );
        expect(
          ist[name]!.schluessel,
          schluessel,
          reason: '$tabelle.$name: Teil des Primärschlüssels',
        );
        expect(
          ist[name]!.vorgabe,
          vorgabe,
          reason: '$tabelle.$name: Vorgabewert',
        );
      }
    }

    // Der Satz-Zeitpunkt noch einmal einzeln — er ist der Grund, warum
    // diese Stufe überhaupt jetzt entsteht (Spec 11, Tim 10.11.2026).
    final satz = await spalten(db, 'gym_saetze');
    expect(
      satz['zeitpunkt']!.nullbar,
      isTrue,
      reason:
          'die Übernahme aus der alten App (#59) kennt keine Satz-Uhrzeiten '
          '— ohne `null` wäre der Normalfall nicht ablegbar',
    );
    expect(
      satz['zeitpunkt']!.vorgabe,
      isNull,
      reason:
          'kein Vorgabewert: weder `now` noch `0` noch Epoch-Null. Ein '
          'Vorgabewert behauptete, der Satz sei zu dieser Minute gehoben '
          'worden',
    );

    // Das Aufwärmen (#40): Strecke echt nullbar, „übersprungen" mit
    // Vorgabe 0, der Wertebereich in der Datei und nicht nur im Enum.
    final sitzung = await spalten(db, 'gym_sitzungen');
    expect(
      sitzung['aufwaermen_km']!.nullbar,
      isTrue,
      reason:
          'bei Mobility gibt es keine Strecke — eine 0 behauptete „null '
          'Kilometer gelaufen" (#40)',
    );
    expect(sitzung['aufwaermen_km']!.vorgabe, isNull);
    expect(
      sitzung['aufwaermen_uebersprungen']!.nullbar,
      isFalse,
      reason:
          '„übersprungen" ist eine Antwort und hat drei Zustände mit '
          '`aufwaermen_art` zusammen, nicht selbst einen dritten',
    );
    expect(
      sitzung['aufwaermen_uebersprungen']!.vorgabe,
      '0',
      reason:
          'die Wahrheit über eine Zeile, bei der niemand etwas eingetragen '
          'hat: nicht übersprungen, sondern nichts gesagt',
    );

    final tabellenSql = await db
        .customSelect(
          "SELECT sql FROM sqlite_master WHERE type = 'table' "
          "AND name = 'gym_sitzungen';",
        )
        .getSingle();
    final sql = tabellenSql.read<String>('sql');
    for (final art in aufwaermArten) {
      expect(
        sql,
        contains("'$art'"),
        reason:
            'der Wertebereich von `aufwaermen_art` steht in der Datei, '
            'nicht nur im Dart-Enum: „Freitext lässt sich später nicht '
            'vergleichen, und vergleichen ist der Zweck" (#40). Fehlt: '
            '$art',
      );
    }

    // Eindeutigkeit über (tag, workout) — als Tabellen-Constraint.
    final eindeutig = await eindeutigkeiten(db, 'gym_sitzungen');
    final ueberTagUndWorkout = [
      for (final e in eindeutig)
        if (e.spalten.toSet().containsAll({'tag', 'workout'}) &&
            e.spalten.length == 2)
          e,
    ];
    expect(
      ueberTagUndWorkout,
      hasLength(1),
      reason:
          'genau eine Eindeutigkeit über (tag, workout) — derselbe '
          'Schlüssel, unter dem GymSessionMerge zwei Sitzungen für '
          'dieselbe hält (Spec 10.2)',
    );
    expect(
      ueberTagUndWorkout.single.herkunft,
      'u',
      reason:
          'als UNIQUE im Tabellenkopf, nicht als eigenes CREATE UNIQUE '
          'INDEX: `_reconcileSchema` kennt keine Indizes, ein '
          'eigenständiger Index stünde auf manchen Geräten und auf anderen '
          'nicht (cache.dart, schema_v17_test.dart Punkt 10)',
    );

    // Sonst kein Index über die Gym-Tabellen.
    final fremde = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index' "
          "AND tbl_name LIKE 'gym_%' AND sql IS NOT NULL;",
        )
        .get();
    expect(
      fremde,
      isEmpty,
      reason:
          'kein mit CREATE INDEX angelegter Index auf den Gym-Tabellen — '
          'dieselbe Begründung wie bei `portionen`',
    );
  }

  // ═════════════════════════════════════════════════════════════════════

  group('Vorbedingungen: die Altstände sind so gebaut, wie sie gemeint '
      'sind', () {
    test('der v17-Stand kennt keine Gym-Tabelle', () {
      final roh = rohdatei(v17Schema, bestand, 17);
      addTearDown(roh.close);
      final namen = {
        for (final z in roh.select(
          "SELECT name FROM sqlite_master WHERE type = 'table';",
        ))
          z['name'] as String,
      };
      for (final t in tabellenAusStufe18) {
        expect(namen, isNot(contains(t)));
      }
      // `tabellenHeute` schließt seit dem 10.11.2026 die Gym-Tabellen ein
      // — ein v17-Stand hat sie gerade nicht, deshalb hier ohne sie. Seit
      // dem Zusammenführen von `umfaenge-88` und `main` (#485) stehen in
      // `tabellenHeute` außerdem die Tabellen der Stufen 19 bis 24, seit
      // dem 24.11.2026 dazu die der Stufe 25 (#592); die kann ein
      // v17-Stand genauso wenig haben.
      expect(
        namen,
        containsAll(
          tabellenHeute.difference({
            ...tabellenAusStufe18,
            ...tabellenAusStufe19,
            ...tabellenAusStufe21,
            ...tabellenAusStufe22,
            ...tabellenAusStufe23,
            ...tabellenAusStufe24,
            ...tabellenAusStufe26,
            ...tabellenAusStufe27,
          }),
        ),
      );
    });

    test('der vorweggenommene Stand trägt alle drei, mit Werten', () {
      final roh = rohdatei(
        v17Schema + gymTabellenVorweg,
        bestand + gymWerteVorweg,
        17,
      );
      addTearDown(roh.close);
      expect(rohZeilen(roh, 'gym_sitzungen'), hasLength(1));
      expect(rohZeilen(roh, 'gym_saetze'), hasLength(2));
      expect(rohZeilen(roh, 'gym_entwuerfe'), hasLength(1));
      expect(
        rohZeilen(roh, 'gym_saetze')[1]['zeitpunkt'],
        isNull,
        reason: 'der zweite Satz steht ohne Uhrzeit da — der Normalfall',
      );
    });
  });

  group('Schema v18 — frisch angelegt', () {
    test('die Version ist mindestens 18', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      expect(
        db.schemaVersion,
        greaterThanOrEqualTo(18),
        reason: 'die Gym-Ablage ist die Stufe 18 (Spec 10.4)',
      );
      expect(await abgelegteVersion(db), db.schemaVersion);
    });

    test('die drei Tabellen sind da, in der verlangten Form, und keine '
        'Tabelle mehr oder weniger', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      expect(await tabellen(db), tabellenNachStufe18);
      await pruefeForm(db);
    });

    test('sie sind leer — die Stufe legt keine Zeile an', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      for (final t in tabellenAusStufe18) {
        expect(
          await zeilen(db, t),
          isEmpty,
          reason: '$t: keine Platzhalterzeile, kein erfundener Zeitstempel',
        );
      }
    });
  });

  group('Migration v17 → v18', () {
    test('die Datei steht danach auf der heutigen Version, mit der '
        'verlangten Form', () async {
      final roh = rohdatei(v17Schema, bestand, 17);
      addTearDown(roh.close);
      final db = ueber(roh);
      addTearDown(db.close);

      expect(await abgelegteVersion(db), db.schemaVersion);
      expect(await tabellen(db), tabellenNachStufe18);
      await pruefeForm(db);
    });

    test('additiv: jede Zeile und jeder Wert der siebzehn bestehenden '
        'Tabellen bleibt', () async {
      final roh = rohdatei(v17Schema, bestand, 17);
      addTearDown(roh.close);
      const alte = [
        'tages_werte',
        'schlaf_eintraege',
        'stammdaten',
        'lebensmittel',
        'portionen',
        'eintraege',
        'wasser_eintraege',
        'ki_einstellungen',
      ];
      final vorher = {for (final t in alte) t: rohZeilen(roh, t)};

      final db = ueber(roh);
      addTearDown(db.close);

      for (final t in alte) {
        pruefeUnveraendert(vorher[t]!, await zeilen(db, t), t);
      }
    });

    test('die Stufe füllt die neuen Tabellen nicht — auch nicht aus '
        '`eigene_daten`', () async {
      final roh = rohdatei(v17Schema, '''
        $bestand
        INSERT INTO eigene_daten (tag, inhalt)
          VALUES ('2099-03-01', '{"art":"gym","workout":"A"}');
      ''', 17);
      addTearDown(roh.close);
      final db = ueber(roh);
      addTearDown(db.close);

      for (final t in tabellenAusStufe18) {
        expect(
          await zeilen(db, t),
          isEmpty,
          reason:
              '$t: es gibt keine Gym-Daten vor Stufe 18, und eine Stufe, '
              'die eine Zeile erfände, erfände auch ihren Zeitstempel',
        );
      }
      expect(
        await zeilen(db, 'eigene_daten'),
        hasLength(1),
        reason: 'und sie räumt auch nichts weg',
      );
    });

    test(
      'ein zweites Öffnen derselben Datei ändert am Schema nichts mehr',
      () async {
        final roh = rohdatei(v17Schema, bestand, 17);
        addTearDown(roh.close);

        final erstes = ueber(roh);
        await erstes.select(erstes.tagesWerte).get();
        await erstes.close();
        final nachErstem = schemaZaehler(roh);

        final zweites = ueber(roh);
        addTearDown(zweites.close);
        await zweites.select(zweites.tagesWerte).get();

        expect(
          schemaZaehler(roh),
          nachErstem,
          reason:
              'PRAGMA schema_version steigt bei jedem CREATE, ALTER und '
              'DROP. Steigt er beim zweiten Öffnen, baut die Stufe oder '
              'der Abgleich bei jedem Start um',
        );
      },
    );

    test('frisch angelegt und migriert ergeben dasselbe Schema', () async {
      final frisch = AppCache(NativeDatabase.memory());
      addTearDown(frisch.close);

      final roh = rohdatei(v17Schema, bestand, 17);
      addTearDown(roh.close);
      final migriert = ueber(roh);
      addTearDown(migriert.close);

      expect(await tabellen(migriert), await tabellen(frisch));
      for (final t in tabellenAusStufe18) {
        expect(
          await spalten(frisch, t),
          isNotEmpty,
          reason: '$t: sonst verglichen beide Wege zwei leere Mengen',
        );
        expect(
          await spalten(migriert, t),
          await spalten(frisch, t),
          reason:
              '$t: beide Wege führen zum selben Schema — sonst hängt das '
              'Verhalten davon ab, wann jemand die App installiert hat',
        );
        // Die Records tragen eine `List<String>`, und Dart vergleicht eine
        // Liste in einem Record über **Identität**, nicht über Inhalt —
        // zwei inhaltsgleiche Ergebnisse wären also nie gleich, und die
        // Fehlermeldung zeigte zweimal denselben Text nebeneinander. Hier
        // deshalb über eine vergleichbare Form. Die Anforderung ist
        // unverändert: beide Wege führen zu denselben Eindeutigkeiten.
        // (Nachgezogen am 10.11.2026 mit TEST_AENDERN=1; die Zeile konnte
        // in keiner Implementierung grün werden.)
        String alsText(({String herkunft, List<String> spalten}) e) =>
            '${e.herkunft}:${e.spalten.join(",")}';
        expect(
          [for (final e in await eindeutigkeiten(migriert, t)) alsText(e)],
          [for (final e in await eindeutigkeiten(frisch, t)) alsText(e)],
          reason: '$t: auch die Eindeutigkeiten',
        );
      }
    });
  });

  group('Die Stufe ist zweimal ausführbar (#234/#240)', () {
    test('stehen die Tabellen schon da, öffnet die Datei, und jede Zeile '
        'darin bleibt', () async {
      final roh = rohdatei(
        v17Schema + gymTabellenVorweg,
        bestand + gymWerteVorweg,
        17,
      );
      addTearDown(roh.close);
      const alle = [
        'tages_werte',
        'eintraege',
        'gym_sitzungen',
        'gym_saetze',
        'gym_entwuerfe',
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

    test(
      'der Satz ohne Uhrzeit kommt nicht mit einer erfundenen heraus',
      () async {
        final roh = rohdatei(
          v17Schema + gymTabellenVorweg,
          bestand + gymWerteVorweg,
          17,
        );
        addTearDown(roh.close);
        final db = ueber(roh);
        addTearDown(db.close);

        final saetze = await zeilen(db, 'gym_saetze');
        expect(saetze, hasLength(2));
        expect(saetze[0]['zeitpunkt'], '2099-03-01T17:05:00.000Z');
        expect(
          saetze[1]['zeitpunkt'],
          isNull,
          reason:
              'null bleibt null — weder die Stufe noch der Abgleich tragen '
              'hier etwas nach (Tim, 10.11.2026)',
        );
        expect(
          saetze[1]['gewicht_kg'],
          -27.0,
          reason: 'negatives Gewicht ist Unterstützung und bleibt negativ',
        );
      },
    );

    test('das eingetragene Aufwärmen bleibt stehen', () async {
      final roh = rohdatei(
        v17Schema + gymTabellenVorweg,
        bestand + gymWerteVorweg,
        17,
      );
      addTearDown(roh.close);
      final db = ueber(roh);
      addTearDown(db.close);

      final z = (await zeilen(db, 'gym_sitzungen')).single;
      expect(z['aufwaermen_art'], 'bike');
      expect(z['aufwaermen_minuten'], 10);
      expect(z['aufwaermen_km'], 3.4);
      expect(z['aufwaermen_uebersprungen'], 0);
      expect(z['aufwaermen_health_uuid'], 'PRUEF-HK-RAD-1');
    });
  });

  group('Der Wertebereich des Aufwärmens steht in der Datei (#40)', () {
    test('die sechs Arten gehen durch', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      for (final (i, art) in aufwaermArten.indexed) {
        await db.customInsert(
          'INSERT INTO gym_sitzungen (id, tag, zeitpunkt, workout, '
          'aufwaermen_art, aufwaermen_minuten) VALUES (?, ?, ?, ?, ?, 10);',
          variables: [
            Variable.withString('pruef-$i'),
            Variable.withString('2099-03-0${i + 1}'),
            Variable<DateTime>(DateTime.utc(2099, 3, i + 1, 17)),
            Variable.withString('A'),
            Variable.withString(art),
          ],
        );
      }
      expect(await zeilen(db, 'gym_sitzungen'), hasLength(6));
    });

    test('eine siebte Art lässt die Datei nicht zu', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      // Erst eine gültige Zeile: Ohne sie ginge dieser Test auch dann
      // durch, wenn es die Tabelle gar nicht gibt.
      await db.customInsert(
        'INSERT INTO gym_sitzungen (id, tag, zeitpunkt, workout, '
        "aufwaermen_art, aufwaermen_minuten) VALUES ('pruef-gut', "
        "'2099-03-01', '2099-03-01T17:00:00.000Z', 'A', 'rowing', 10);",
      );

      await expectLater(
        db.customInsert(
          'INSERT INTO gym_sitzungen (id, tag, zeitpunkt, workout, '
          "aufwaermen_art, aufwaermen_minuten) VALUES ('pruef-x', "
          "'2099-03-01', '2099-03-01T17:00:00.000Z', 'A', 'einrad', 10);",
        ),
        throwsA(anything),
        reason:
            'Freitext lässt sich später nicht vergleichen, und vergleichen '
            'ist der Zweck (#40). Ein Wertebereich, der nur im Enum steht, '
            'fällt erst Monate später auf',
      );
    });

    test('kein Aufwärmen eingetragen ist erlaubt und heißt nicht '
        'übersprungen', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      await db.customInsert(
        'INSERT INTO gym_sitzungen (id, tag, zeitpunkt, workout) '
        "VALUES ('pruef-ohne', '2099-03-01', "
        "'2099-03-01T17:00:00.000Z', 'A');",
      );

      final z = (await zeilen(db, 'gym_sitzungen')).single;
      expect(z['aufwaermen_art'], isNull);
      expect(z['aufwaermen_minuten'], isNull);
      expect(
        z['aufwaermen_uebersprungen'],
        0,
        reason:
            'nichts eingetragen ist nicht dasselbe wie übersprungen — der '
            'Vorgabewert darf den einen Zustand nicht zum anderen machen',
      );
    });
  });

  group('Abgleich beim Öffnen (#233)', () {
    test('eine Datei auf 18, der `gym_saetze` fehlt, bekommt die Tabelle '
        '— und verliert nichts', () async {
      // Ein Zweig hat die Nummer hochgezogen, bevor seine Stufe fertig war:
      // `gym_sitzungen` steht da, `gym_saetze` und `gym_entwuerfe` fehlen.
      final roh = rohdatei(v17Schema + gymSitzungenVorweg, '''
        $bestand
        INSERT INTO gym_sitzungen (id, tag, zeitpunkt, workout, minuten)
          VALUES ('pruef-sitzung-9', '2099-03-01',
                  '2099-03-01T17:30:00.000Z', 'B', 65);
      ''', 18);
      addTearDown(roh.close);
      final vorher = rohZeilen(roh, 'gym_sitzungen');

      final db = ueber(roh);
      addTearDown(db.close);
      // Der erste Zugriff: Das Öffnen selbst ist bei drift lazy.
      await db.select(db.tagesWerte).get();

      expect(
        await tabellen(db),
        tabellenNachStufe18,
        reason:
            'onUpgrade läuft bei from == 18 nicht in die Stufe 18 — die '
            'Tabellen kommen nur über den Abgleich',
      );
      await pruefeForm(db);
      pruefeUnveraendert(
        vorher,
        await zeilen(db, 'gym_sitzungen'),
        'gym_sitzungen',
      );
      expect(
        await zeilen(db, 'gym_saetze'),
        isEmpty,
        reason: 'eine nachgelegte Tabelle kommt leer — sie erfindet nichts',
      );
    });
  });

  group('Von weit unten: v11 → heute', () {
    test('ein v11-Stand öffnet ohne `duplicate column name` und hat danach '
        'die drei Gym-Tabellen', () async {
      final roh = rohdatei(v11Schema, v11Bestand, 11);
      addTearDown(roh.close);
      final vorher = rohZeilen(roh, 'tages_werte');

      final db = ueber(roh);
      addTearDown(db.close);

      expect(await abgelegteVersion(db), db.schemaVersion);
      expect(await tabellen(db), tabellenNachStufe18);
      await pruefeForm(db);
      pruefeUnveraendert(
        vorher,
        await zeilen(db, 'tages_werte'),
        'tages_werte',
      );
      for (final t in tabellenAusStufe18) {
        expect(await zeilen(db, t), isEmpty);
      }
    });

    test('auch wenn ein anderer Zweig die Gym-Tabellen auf einem v11-Gerät '
        'schon angelegt hat', () async {
      final roh = rohdatei(
        v11Schema + gymTabellenVorweg,
        '$v11Bestand$gymWerteVorweg',
        11,
      );
      addTearDown(roh.close);
      final vorher = {for (final t in tabellenAusStufe18) t: rohZeilen(roh, t)};

      final db = ueber(roh);
      addTearDown(db.close);

      expect(await abgelegteVersion(db), db.schemaVersion);
      await pruefeForm(db);
      for (final t in tabellenAusStufe18) {
        pruefeUnveraendert(vorher[t]!, await zeilen(db, t), t);
      }
    });
  });

  group('Zeitpunkte kommen als UTC und gleich sich selbst zurück', () {
    final quellen = <String, AppCache Function()>{
      'frisch angelegt': () => AppCache(NativeDatabase.memory()),
      'aus v17 migriert': () => AppCache(
        NativeDatabase.memory(
          setup: (roh) {
            roh.execute(v17Schema);
            roh.execute(bestand);
            roh.execute('PRAGMA user_version = 17;');
          },
        ),
      ),
    };

    for (final MapEntry(key: name, value: oeffne) in quellen.entries) {
      test('$name: gym_sitzungen.zeitpunkt', () async {
        final db = oeffne();
        addTearDown(db.close);

        // Kurz vor Mitternacht UTC: in Berlin schon der Folgetag. Käme der
        // Wert als Ortszeit zurück, wäre er ungleich sich selbst.
        final zeitpunkt = DateTime.utc(2099, 10, 24, 22, 30, 15, 123);
        await db.customInsert(
          'INSERT INTO gym_sitzungen (id, tag, zeitpunkt, workout) '
          'VALUES (?, ?, ?, ?);',
          variables: [
            Variable.withString('pruef-utc'),
            Variable.withString('2099-10-25'),
            Variable<DateTime>(zeitpunkt),
            Variable.withString('A'),
          ],
        );

        final art = await db
            .customSelect(
              "SELECT typeof(zeitpunkt) AS art FROM gym_sitzungen "
              "WHERE id = 'pruef-utc';",
            )
            .getSingle();
        expect(
          art.read<String>('art'),
          'text',
          reason: 'storeDateTimeAsText: als Text in der Datei',
        );

        final zeile = await db
            .customSelect(
              "SELECT zeitpunkt FROM gym_sitzungen WHERE id = 'pruef-utc';",
            )
            .getSingle();
        final gelesen = zeile.read<DateTime>('zeitpunkt');
        expect(gelesen.isUtc, isTrue);
        expect(gelesen, zeitpunkt);
      });

      test('$name: gym_saetze.zeitpunkt, gesetzt und null', () async {
        final db = oeffne();
        addTearDown(db.close);

        final satzZeit = DateTime.utc(2099, 10, 24, 22, 31, 0, 456);
        await db.customInsert(
          'INSERT INTO gym_sitzungen (id, tag, zeitpunkt, workout) '
          'VALUES (?, ?, ?, ?);',
          variables: [
            Variable.withString('pruef-utc'),
            Variable.withString('2099-10-25'),
            Variable<DateTime>(DateTime.utc(2099, 10, 24, 22, 40)),
            Variable.withString('A'),
          ],
        );
        await db.customInsert(
          'INSERT INTO gym_saetze (sitzung_id, uebung_id, uebung_pos, '
          'satz_nr, gewicht_kg, wdh, zeitpunkt) VALUES (?, ?, 1, 1, 0.0, '
          '12, ?);',
          variables: [
            Variable.withString('pruef-utc'),
            Variable.withString('pruef-uebung'),
            Variable<DateTime>(satzZeit),
          ],
        );
        await db.customInsert(
          'INSERT INTO gym_saetze (sitzung_id, uebung_id, uebung_pos, '
          'satz_nr, gewicht_kg, wdh) VALUES (?, ?, 1, 2, 0.0, 11);',
          variables: [
            Variable.withString('pruef-utc'),
            Variable.withString('pruef-uebung'),
          ],
        );

        final alle = await db
            .customSelect(
              'SELECT satz_nr, zeitpunkt FROM gym_saetze ORDER BY satz_nr;',
            )
            .get();
        expect(alle, hasLength(2));
        expect(alle[0].read<DateTime>('zeitpunkt'), satzZeit);
        expect(alle[0].read<DateTime>('zeitpunkt').isUtc, isTrue);
        expect(
          alle[1].data['zeitpunkt'],
          isNull,
          reason:
              'ein Satz ohne Uhrzeit bleibt ohne — kein Rückfall auf jetzt, '
              'auf den Sitzungsbeginn oder auf Epoch-Null',
        );
      });
    }
  });
}
