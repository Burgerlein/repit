import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show Database, sqlite3;
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/cache.dart';

import 'schema_tabellen.dart';

/// Tests für **Schema v27**: die Tabellen eigener Trainings
/// (`gym_trainings`, `gym_training_uebungen`, `gym_training_tags`), die
/// gespeicherte Rotation (`gym_rotation`), die Namensspalte
/// `gym_sitzungen.trainings_name` und die Startbefüllung mit Push, Pull und
/// Legs (#532, unter #531; Rotation-Datenteil aus #536 vorgezogen).
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden. Jede Migration
/// bekommt einen Test, dies ist der für die Stufe 27.
///
/// ## Woher die Anforderung kommt
///
/// Spec `docs/superpowers/specs/2026-11-19-eigene-trainings-design.md`,
/// Abschnitt 4 (Datenmodell, 4.8 die Migration, 20 die Pflichtliste) und
/// **die Nachträge 22 bis 24, die ältere Abschnitte schlagen**:
///
/// - **Abschnitt 23 [Tim, 19.11.2026]:** Die Start-Templates sind **Push,
///   Pull und Legs** — drei, nicht vier, **keine** Zeilen `A` bis `D` (die
///   Abschnitte 4.3 und 22.1 sind damit überholt). Die Rotation kommt mit in
///   diese Stufe: geordnete Kennungen, **ohne Wochentage**, startbefüllt mit
///   Push, Pull, Legs.
/// - **Abschnitt 24 Nr. 2 und 3:** Die Rotation-Tabelle hat **keine
///   Wochentag-Spalte**. Eingespielt wird **mit Merker**, nicht „wenn leer":
///   Löschen kann die Rotation leeren, und „füllen, wenn leer" erweckte
///   Gelöschtes wieder. Dasselbe Muster wie der Template-Tombstone.
/// - **4.1/4.2:** Spalten, Typen, Schlüssel, `UNIQUE` **im Tabellenkopf**
///   (kein `CREATE UNIQUE INDEX` — `_reconcileSchema` kennt keine Indizes)
///   und die `CHECK`-Bedingungen **in der Datei**, nicht nur im Dart-Code.
/// - **4.3/4.4:** `spieleTemplatesEin` legt jedes Template an, dessen `id`
///   weder lebt noch einen Tombstone trägt, und **fasst nie eine vorhandene
///   Zeile an**. Ein Tombstone kommt nie zurück.
/// - **4.6:** `gym_sitzungen.trainings_name TEXT`, nullbar; **eine alte
///   Zeile bekommt keinen erfundenen Namen**, `NULL` bleibt `NULL`. Die
///   Spalte `workout` bleibt unverändert (kein Tabellenneubau, keine
///   `CHECK`-Bedingung), damit sie eine UUID statt eines Codes aufnimmt.
/// - **4.8:** Eine **eigene** Stufe `if (from < 25) { … }`, erst die
///   Tabellen, dann die Spalte; additiv, **ohne eine einzige Zeile**, kein
///   `DROP`, kein Index.
/// - **`CLAUDE.md`, Tests:** „Eine Migration füllt alte Zeilen nicht mit
///   erfundenen Zeitstempeln — das behauptete, sie seien frisch." Dasselbe
///   gilt für Namen.
///
/// Der Code der Stufe existierte beim Schreiben dieser Datei nicht. Gelesen
/// wurden Spec, Plan (Task 1.4) und bestehende Migrationstests, nicht die
/// spätere Implementierung.
///
/// ## Warum die 25
///
/// Beim Schreiben (19.11.2026) stand `AppCache.schemaVersion` in `main` und
/// in jedem Zweig auf 24. Diese Datei prüft mit `>=`, damit sie bei der
/// nächsten Stufe nicht mitfällt (#208).
///
/// ## Wie geprüft wird
///
/// **Diese Datei spricht die Tabellen nur über SQL an**, nicht über
/// drift-Klassen. Sie übersetzt also auch, solange es die Tabellen im Code
/// nicht gibt, und meldet dann, *was* fehlt, statt nur, dass sie nicht baut.
///
/// **`spieleTemplatesEin` und `spieleRotationEin` werden nicht beim Namen
/// gerufen**, sondern über das, was die Spec verlangt: Sie laufen in
/// `AppCache.beforeOpen`. Die Tests öffnen deshalb dieselbe Datei mehrfach
/// hintereinander (`closeUnderlyingOnClose: false`) und sehen nach, was
/// danach da ist. Wie die Methoden heißen und wo sie stehen, ist damit
/// Sache der Implementierung.
///
/// ## Festlegungen des Test-Agenten, nicht von Tim freigegeben
///
/// Was folgt, steht so weder in Spec noch in Plan. Der Test-Agent hat es
/// beim Schreiben dieser Datei festgelegt; **Tim hat es nicht gesehen.**
///
/// - **`gym_trainings.entwurf_von` ist ein Vorschlag des Plans (Plan 1),
///   keine Entscheidung.** Der Plan schlägt `entwurf_von TEXT`, nullbar,
///   mit `CHECK (entwurf_von IS NULL OR (ist_entwurf = 1 AND kategorie =
///   'eigene'))` und `UNIQUE (entwurf_von)` vor; Tim hat die Frage nicht
///   beantwortet, und die Spec 4.1 führt die Spalte nicht. Die Tests
///   verlangen sie trotzdem — Task 1.4 sagt „hängt an Plan 1". Entfällt
///   sie, ändern sich die Konstante [spaltenTrainings] und die Gruppe
///   „Plan 1: entwurf_von" und sonst nichts.
/// - **`gym_rotation` hat genau zwei Spalten:** `pos INTEGER NOT NULL
///   PRIMARY KEY` (ab 1) und `training_id TEXT NOT NULL`, dazu
///   `UNIQUE (training_id)` im Tabellenkopf und `CHECK (pos >= 1)`.
///   Plan 15/16 nennen „Spalten, Schlüssel, CHECK `pos >= 1`, UNIQUE
///   (training_id) im Tabellenkopf" und lassen **Namen und Primärschlüssel
///   offen**. Festgelegt ist hier: Schlüssel ist `pos`, weil
///   `UNIQUE (training_id)` sonst neben einem Schlüssel auf `training_id`
///   überflüssig wäre. „Ein Training steht höchstens einmal in der
///   Rotation" (Spec 14.1) ist damit eine Eigenschaft der Datenbank.
/// - **Der Merker ist nur als Verhalten festgelegt**, nicht als Ablage:
///   Eine geleerte oder veränderte Rotation wird beim nächsten Öffnen nicht
///   wieder befüllt. **Wo der Merker liegt, sagen Spec und Plan nicht.**
///   Diese Datei nimmt an, dass er **keine fünfte Tabelle** braucht
///   ([tabellenAusStufe27] hat vier) und keine Spalte in einer bestehenden;
///   braucht er eine, gehört das zuerst entschieden und diese Datei dann
///   nachgezogen.
/// - **Die Stufe selbst lässt sich von `beforeOpen` nicht trennen.** Beim
///   Öffnen läuft beides. Geprüft wird deshalb, dass **nach** dem Öffnen
///   genau das da ist, was die Startbefüllung verlangt, und nichts, was
///   die Stufe zusätzlich geschrieben haben könnte (keine Zeile `A`–`D`,
///   keine Übungen und Tags fremder Trainings), und dass auf einem Gerät
///   mit schon vorhandenen, **gelöschten** Templates nichts davon
///   wiederkommt.
/// - **Boolesche Spalten** (`ist_entwurf`, `geloescht`) heißen in der Datei
///   `INTEGER` oder `BOOLEAN`, je nachdem, was `customConstraint` ergibt;
///   beides gilt. Nicht nullbar, Vorgabe `0`.
/// - **`id` ist nicht nullbar**, obwohl SQLite bei `TEXT PRIMARY KEY` ohne
///   `NOT NULL` ein `NULL` zuließe.
/// - **Auch `gym_training_tags.pos` hat `CHECK (pos >= 1)`.** Die Spec
///   nennt in 4.2 `pos >= 1` allgemein und in 4.1 für die Tags „ab 1".
/// - **Kein Fremdschlüssel** an keiner der vier Tabellen (Spec 4.1,
///   „Warum kein Fremdschlüssel").
/// - **Die Dauern 70/70/60 sind ein Vorschlag** (Spec 4.3 für A–D, Plan 12
///   für Push/Pull/Legs: `Workout.minutes`), und **der Tag `Gym`** ist der
///   Vorschlag aus Plan 12. Beides ist nicht entschieden und steht hier als
///   Literal.
/// - **Der Name ist `'${label} — ${title}'`** (Spec 4.3, Folgerung): für
///   Push, Pull, Legs ohne „Gym" davor, weil `Workout.label` dort nur den
///   Code liefert — `Push — Brust, Schultern, Trizeps`.
/// - **`reihenfolge` der Templates ist 1, 2, 3** (Spec 4.1: „Position in der
///   Startbefüllung (1…)").
/// - **Übungen, Sätze, Wiederholungsbereiche der Startbefüllung** werden
///   mit `ExerciseCatalog.exercisesFor` verglichen (Spec 4.3: „die
///   Katalogwerte … als Werte kopiert"), dazu stehen die Zahlen als Anker
///   da: Push 7 Übungen / 23 Sätze, Pull 7 / 23, Legs 7 / 25. Die Gleichheit
///   mit dem Katalog beweist der Kerntest `workout_templates_test.dart`;
///   hier geht es um die Ablage.
/// - **Ein fehlendes Template kommt wieder** (Spec 4.3: „jedes Template,
///   dessen `id` in der Tabelle weder lebt noch einen Tombstone trägt") —
///   samt seinen Übungen und Tags. Das ist der Mechanismus für spätere
///   Update-Templates.
///
/// ## Was die Spec offen lässt und diese Datei **nicht** entscheidet
///
/// - **Rotation auf einem Gerät mit schon vorhandenen Zeilen, aber ohne
///   Merker** (etwa ein Stand, den der Abgleich nachgelegt hat): Ergänzt
///   die Einspielung fehlende Kennungen, oder tut sie nichts und setzt nur
///   den Merker? Geprüft wird nur, dass die vorhandene Zeile **nicht
///   angefasst** wird.
/// - **Rotation, wenn eines der drei Templates beim Einspielen schon einen
///   Tombstone trägt.** Spec 14.1: Tombstones sind nicht einplanbar — ob
///   die Einspielung sie dann auslässt, ist nicht gesagt.
///
/// **Alle Zahlen, Namen und Zeitpunkte hier sind erfunden** (Jahr 2099);
/// Tims echte Trainings stehen nirgends im Quelltext.
void main() {
  const neueTabellen = {
    'gym_trainings',
    'gym_training_uebungen',
    'gym_training_tags',
    'gym_rotation',
  };

  /// Die Spalten von `gym_trainings`: Spec 4.1, dazu `entwurf_von` aus
  /// Plan 1 (Vorschlag, siehe Dateikopf).
  const spaltenTrainings = {
    'id',
    'name',
    'kategorie',
    'dauer_eingetragen_min',
    'ist_entwurf',
    'geloescht',
    'reihenfolge',
    'entwurf_von',
  };

  // Die Stufe 26 (#592, Zykluskalender) kam beim Zusammenführen der
  // beiden `main`-Stände am 24.11.2026 dazu; ihre drei Tabellen fehlen
  // einem v24-Stand ebenso wie die vier dieser Stufe.
  final tabellenVorStufe25 =
      tabellenHeute.difference({...neueTabellen, ...tabellenAusStufe26});

  // --- Altstände, von Hand -----------------------------------------------

  /// Stand v24: `v23Schema` aus `schema_v24_test.dart` mit `umfaenge`
  /// (Stufe 24), wörtlich. Die Tabellen der Stufe 27 und die Spalte
  /// `trainings_name` fehlen.
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

  /// Die Spalte der Stufe 27, wie ein anderer Zweig sie schon angelegt
  /// haben könnte.
  const spalteTrainingsNameVorweg = '''
    ALTER TABLE gym_sitzungen ADD COLUMN trainings_name TEXT NULL;
  ''';

  /// Die vier Tabellen der Stufe 27, wie ein anderer Zweig sie schon
  /// angelegt haben könnte — von Hand nach Spec 4.1/4.2, mit `UNIQUE` im
  /// Tabellenkopf und den `CHECK`-Bedingungen in der Datei.
  const tabellenVorweg = '''
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
  ''';

  /// Tims Bestand auf Stand v24, erfunden: der Bestand von
  /// `schema_v24_test.dart`, dazu Gym-Sitzungen, -Sätze, ein Entwurf der
  /// Erfassung und zwei Umfänge. Eine Migration, die hier etwas verlöre,
  /// verlöre es endgültig — Tims einzige Kopie der Trainings.
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
    INSERT INTO gym_sitzungen
      (id, tag, zeitpunkt, workout, minuten, notiz, health_uuid,
       aufwaermen_art, aufwaermen_minuten, aufwaermen_km,
       aufwaermen_uebersprungen, aufwaermen_health_uuid)
      VALUES ('PRUEF-S1', '2099-03-02', '2099-03-02T17:00:00.000Z', 'A', 70,
              'Prüfnotiz', 'PRUEF-UUID-S1', 'bike', 10, 3.5, 0,
              'PRUEF-UUID-W1');
    INSERT INTO gym_sitzungen
      (id, tag, zeitpunkt, workout, minuten, notiz, health_uuid,
       aufwaermen_uebersprungen)
      VALUES ('PRUEF-S2', '2099-03-04', '2099-03-04T17:00:00.000Z', 'Push',
              65, NULL, NULL, 1);
    INSERT INTO gym_sitzungen
      (id, tag, zeitpunkt, workout, minuten, notiz, health_uuid,
       aufwaermen_uebersprungen)
      VALUES ('PRUEF-S3', '2099-03-06', '2099-03-06T17:00:00.000Z', 'Legs',
              NULL, NULL, NULL, 0);
    INSERT INTO gym_saetze
      (sitzung_id, uebung_id, uebung_pos, satz_nr, gewicht_kg, wdh,
       zeitpunkt)
      VALUES ('PRUEF-S1', 'benchPress', 1, 1, 62.5, 8,
              '2099-03-02T17:10:00.000Z');
    INSERT INTO gym_saetze
      (sitzung_id, uebung_id, uebung_pos, satz_nr, gewicht_kg, wdh,
       zeitpunkt)
      VALUES ('PRUEF-S1', 'benchPress', 1, 2, 62.5, 7, NULL);
    INSERT INTO gym_saetze
      (sitzung_id, uebung_id, uebung_pos, satz_nr, gewicht_kg, wdh,
       zeitpunkt)
      VALUES ('PRUEF-S2', 'pullUp', 1, 1, -27.0, 6, NULL);
    INSERT INTO gym_entwuerfe
      (id, workout, sitzung_id, zeitpunkt, dauer, notiz, gespeichert_am,
       felder)
      VALUES (0, 'Pull', 'PRUEF-S4', '2099-03-08T17:00:00.000Z', '55',
              'Entwurfsnotiz', '2099-03-08T17:20:00.000Z', '{"p":1}');
    INSERT INTO umfaenge (tag, mass, zentimeter, eingetragen_am, quelle)
      VALUES ('2099-04-12', 'pruefmassA', 41.4, '2099-04-12T07:05:00.000Z',
              'getippt');
    INSERT INTO umfaenge (tag, mass, zentimeter, eingetragen_am, quelle)
      VALUES ('2099-04-12', 'pruefmassB', 99.9, '2099-04-12T07:07:00.000Z',
              'getippt');
  ''';

  /// Ein eigenes Training samt Übungen und Tag, wie ein anderer Zweig es
  /// schon hätte schreiben können (nur für die Tests „zweimal ausführbar"),
  /// und eine Sitzung, die ihren Namen schon trägt.
  const vorwegZeilen = '''
    INSERT INTO gym_trainings
      (id, name, kategorie, dauer_eingetragen_min, ist_entwurf, geloescht,
       reihenfolge)
      VALUES ('PRUEF-EIGENES-1', 'Prüftraining Eins', 'eigene', 45, 0, 0, 1);
    INSERT INTO gym_training_uebungen
      (training_id, pos, uebung_id, saetze, wdh_von, wdh_bis, steigerung)
      VALUES ('PRUEF-EIGENES-1', 1, 'benchPress', 3, 6, 10, NULL);
    INSERT INTO gym_training_uebungen
      (training_id, pos, uebung_id, saetze, wdh_von, wdh_bis, steigerung)
      VALUES ('PRUEF-EIGENES-1', 2, 'pullUp', 4, 5, 8, NULL);
    INSERT INTO gym_training_tags (training_id, pos, tag)
      VALUES ('PRUEF-EIGENES-1', 1, 'Prüftag');
  ''';

  /// Alle drei Templates **mit Tombstone**, samt Übungen und Tags — so,
  /// wie ein Gerät aussähe, auf dem Tim sie gelöscht hat.
  const tombstonesVorweg = '''
    INSERT INTO gym_trainings
      (id, name, kategorie, dauer_eingetragen_min, ist_entwurf, geloescht,
       reihenfolge)
      VALUES ('Push', 'Prüfname Push', 'template', 11, 0, 1, 1);
    INSERT INTO gym_trainings
      (id, name, kategorie, dauer_eingetragen_min, ist_entwurf, geloescht,
       reihenfolge)
      VALUES ('Pull', 'Prüfname Pull', 'template', NULL, 0, 1, 2);
    INSERT INTO gym_trainings
      (id, name, kategorie, dauer_eingetragen_min, ist_entwurf, geloescht,
       reihenfolge)
      VALUES ('Legs', 'Prüfname Legs', 'template', 33, 0, 1, 3);
    INSERT INTO gym_training_uebungen
      (training_id, pos, uebung_id, saetze, wdh_von, wdh_bis, steigerung)
      VALUES ('Push', 1, 'benchPress', 2, 3, 4, NULL);
    INSERT INTO gym_training_tags (training_id, pos, tag)
      VALUES ('Push', 1, 'Prüftag');
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
    'gym_sitzungen',
    'gym_saetze',
    'gym_entwuerfe',
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

  /// Öffnet die Datei **tatsächlich**: drift öffnet lazy, und `beforeOpen`
  /// läuft erst beim ersten Zugriff.
  Future<AppCache> oeffne(Database roh) async {
    final db = ueber(roh);
    await db.customSelect('SELECT 1;').get();
    return db;
  }

  /// Öffnet, schließt und lässt die Datei offen — ein App-Start.
  Future<void> starte(Database roh) async {
    final db = await oeffne(roh);
    await db.close();
  }

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

  Future<List<Map<String, Object?>>> zeilen(
    AppCache db,
    String tabelle, {
    String ordnung = 'rowid',
  }) async {
    final ergebnis = await db
        .customSelect('SELECT * FROM $tabelle ORDER BY $ordnung;')
        .get();
    return [for (final z in ergebnis) z.data];
  }

  List<Map<String, Object?>> rohZeilen(Database roh, String tabelle) => [
    for (final z in roh.select('SELECT * FROM $tabelle ORDER BY rowid;'))
      Map<String, Object?>.of(z),
  ];

  int schemaZaehler(Database roh) =>
      roh.select('PRAGMA schema_version;').single['schema_version'] as int;

  /// Wie [pruefeUnveraendert], aber `nachher` darf **mehr** Zeilen haben —
  /// hinten, nach den alten. Für Tabellen, in die `beforeOpen` etwas
  /// einspielt.
  void pruefePraefix(
    List<Map<String, Object?>> vorher,
    List<Map<String, Object?>> nachher,
    String tabelle,
  ) {
    expect(
      nachher.length,
      greaterThanOrEqualTo(vorher.length),
      reason: 'in $tabelle fehlt eine vorhandene Zeile',
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

  /// Nichts fehlt, nichts hat sich geändert; **neue Spalten** in `nachher`
  /// (etwa `trainings_name`) bleiben außer Betracht, jeder Wert aus
  /// `vorher` nicht.
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
    pruefePraefix(vorher, nachher, tabelle);
  }

  Future<int> anzahl(AppCache db, String tabelle, [String wo = '1 = 1']) async {
    final z = await db
        .customSelect('SELECT COUNT(*) AS n FROM $tabelle WHERE $wo;')
        .getSingle();
    return z.read<int>('n');
  }

  /// Die `UNIQUE`-Schlüssel einer Tabelle als `"a,b"`-Texte — nur die, die
  /// im Tabellenkopf stehen (`origin = 'u'`), nicht die eines
  /// `CREATE UNIQUE INDEX` (`origin = 'c'`) und nicht den Primärschlüssel.
  Future<Set<String>> eindeutigkeiten(AppCache db, String tabelle) async {
    final indizes = await db.customSelect('PRAGMA index_list($tabelle);').get();
    final ergebnis = <String>{};
    for (final i in indizes) {
      if (i.read<String>('origin') != 'u') continue;
      final name = i.read<String>('name');
      final info = await db.customSelect('PRAGMA index_info("$name");').get();
      final nach = [...info]
        ..sort((a, b) => a.read<int>('seqno').compareTo(b.read<int>('seqno')));
      ergebnis.add(nach.map((z) => z.read<String>('name')).join(','));
    }
    return ergebnis;
  }

  List<String> schluessel(
    Map<String, ({String typ, bool nullbar, int schluesselNr, String? vorgabe})>
    s,
  ) =>
      (s.entries.where((e) => e.value.schluesselNr > 0).toList()..sort(
            (a, b) => a.value.schluesselNr.compareTo(b.value.schluesselNr),
          ))
          .map((e) => e.key)
          .toList();

  Future<void> verstoesst(AppCache db, String sql, String warum) async {
    var geworfen = false;
    try {
      await db.customStatement(sql);
    } catch (_) {
      geworfen = true;
    }
    expect(geworfen, isTrue, reason: 'muss abgelehnt werden: $warum\n$sql');
  }

  Future<void> erlaubt(AppCache db, String sql, String warum) async {
    try {
      await db.customStatement(sql);
    } catch (e) {
      fail('muss angenommen werden: $warum\n$sql\n$e');
    }
  }

  String trainingSql(
    String id, {
    String name = "'Prüfname'",
    String kategorie = "'eigene'",
    String dauer = 'NULL',
    String entwurf = '0',
    String geloescht = '0',
    String reihenfolge = '1',
    String? von,
  }) =>
      'INSERT INTO gym_trainings (id, name, kategorie, '
      'dauer_eingetragen_min, ist_entwurf, geloescht, reihenfolge'
      '${von == null ? '' : ', entwurf_von'}) '
      "VALUES ('$id', $name, $kategorie, $dauer, $entwurf, $geloescht, "
      '$reihenfolge${von == null ? '' : ', $von'});';

  String uebungSql(
    String trainingId,
    int pos,
    String uebungId, {
    String saetze = '3',
    String von = '8',
    String bis = '12',
    String steigerung = 'NULL',
  }) =>
      'INSERT INTO gym_training_uebungen (training_id, pos, uebung_id, '
      'saetze, wdh_von, wdh_bis, steigerung) '
      "VALUES ('$trainingId', $pos, '$uebungId', $saetze, $von, $bis, "
      '$steigerung);';

  String tagSql(String trainingId, int pos, String tag) =>
      'INSERT INTO gym_training_tags (training_id, pos, tag) '
      "VALUES ('$trainingId', $pos, '$tag');";

  String rotationSql(int pos, String trainingId) =>
      'INSERT INTO gym_rotation (pos, training_id) '
      "VALUES ($pos, '$trainingId');";

  // --- Die verlangte Form -------------------------------------------------

  /// Spalten, Typen, Nullbarkeit, Vorgaben, Schlüssel und `UNIQUE` aller
  /// vier Tabellen nach Spec 4.1/4.2 — gelesen aus der Datei, nicht aus dem
  /// Dart-Code.
  Future<void> pruefeForm(AppCache db) async {
    final anyBool = anyOf('INTEGER', 'BOOLEAN');

    // gym_trainings
    final t = await spalten(db, 'gym_trainings');
    expect(
      t.keys.toSet(),
      spaltenTrainings,
      reason: 'genau diese Spalten (Spec 4.1, dazu entwurf_von aus Plan 1)',
    );
    for (final MapEntry(key: n, value: erwartung) in {
      'id': ('TEXT', false),
      'name': ('TEXT', false),
      'kategorie': ('TEXT', false),
      'dauer_eingetragen_min': ('INTEGER', true),
      'reihenfolge': ('INTEGER', false),
      'entwurf_von': ('TEXT', true),
    }.entries) {
      expect(t[n]!.typ, erwartung.$1, reason: 'gym_trainings.$n: Typ');
      expect(
        t[n]!.nullbar,
        erwartung.$2,
        reason:
            'gym_trainings.$n: nullbar? (`customConstraint` ersetzt auch '
            'NOT NULL — es muss in der Zeichenkette stehen). dauer_'
            'eingetragen_min ist nullbar: NULL heißt „geschätzt", nicht '
            '„0 Minuten" (Fehler 01)',
      );
    }
    for (final n in ['ist_entwurf', 'geloescht']) {
      expect(t[n]!.typ, anyBool, reason: 'gym_trainings.$n ist ein Bool');
      expect(t[n]!.nullbar, isFalse, reason: 'gym_trainings.$n: NOT NULL');
      expect(t[n]!.vorgabe, '0', reason: 'gym_trainings.$n: Vorgabe 0');
    }
    for (final n in [
      'id',
      'name',
      'kategorie',
      'dauer_eingetragen_min',
      'reihenfolge',
      'entwurf_von',
    ]) {
      expect(
        t[n]!.vorgabe,
        isNull,
        reason:
            'gym_trainings.$n: keine Vorgabe — ein Vorgabename oder eine '
            'Vorgabedauer erfände etwas, das niemand eingetragen hat',
      );
    }
    expect(schluessel(t), ['id']);
    expect(
      await eindeutigkeiten(db, 'gym_trainings'),
      {'entwurf_von'},
      reason:
          'UNIQUE (entwurf_von) im Tabellenkopf (Plan 1: je Training '
          'höchstens ein Zwischenstand)',
    );

    // gym_training_uebungen
    final u = await spalten(db, 'gym_training_uebungen');
    expect(u.keys.toSet(), {
      'training_id',
      'pos',
      'uebung_id',
      'saetze',
      'wdh_von',
      'wdh_bis',
      'steigerung',
    });
    for (final MapEntry(key: n, value: erwartung) in {
      'training_id': ('TEXT', false),
      'pos': ('INTEGER', false),
      'uebung_id': ('TEXT', false),
      'saetze': ('INTEGER', false),
      'wdh_von': ('INTEGER', false),
      'wdh_bis': ('INTEGER', false),
      'steigerung': ('REAL', true),
    }.entries) {
      expect(u[n]!.typ, erwartung.$1, reason: 'gym_training_uebungen.$n: Typ');
      expect(
        u[n]!.nullbar,
        erwartung.$2,
        reason:
            'gym_training_uebungen.$n: nullbar? steigerung ist der Platz '
            'für #537: NULL heißt „aus dem Katalog"',
      );
      expect(u[n]!.vorgabe, isNull, reason: '$n: keine Vorgabe');
    }
    expect(schluessel(u), ['training_id', 'uebung_id']);
    expect(await eindeutigkeiten(db, 'gym_training_uebungen'), {
      'training_id,pos',
    }, reason: 'UNIQUE (training_id, pos) im Tabellenkopf');

    // gym_training_tags
    final g = await spalten(db, 'gym_training_tags');
    expect(g.keys.toSet(), {'training_id', 'pos', 'tag'});
    for (final MapEntry(key: n, value: typ) in {
      'training_id': 'TEXT',
      'pos': 'INTEGER',
      'tag': 'TEXT',
    }.entries) {
      expect(g[n]!.typ, typ, reason: 'gym_training_tags.$n: Typ');
      expect(g[n]!.nullbar, isFalse, reason: '$n ist Pflicht');
      expect(g[n]!.vorgabe, isNull, reason: '$n: keine Vorgabe');
    }
    expect(schluessel(g), ['training_id', 'tag']);
    expect(await eindeutigkeiten(db, 'gym_training_tags'), {
      'training_id,pos',
    }, reason: 'UNIQUE (training_id, pos) im Tabellenkopf');

    // gym_rotation
    final r = await spalten(db, 'gym_rotation');
    expect(
      r.keys.toSet(),
      {'pos', 'training_id'},
      reason:
          'genau zwei Spalten, **keine Wochentag-Spalte** (Spec 24 Nr. 2): '
          'Wochentage sind #536 und bekommen dort ihre eigene Stufe — eine '
          'Spalte auf Vorrat wäre eine Behauptung über einen Entwurf, den '
          'es noch nicht gibt',
    );
    expect(r['pos']!.typ, 'INTEGER');
    expect(r['pos']!.nullbar, isFalse);
    expect(r['training_id']!.typ, 'TEXT');
    expect(r['training_id']!.nullbar, isFalse);
    expect(r['pos']!.vorgabe, isNull);
    expect(r['training_id']!.vorgabe, isNull);
    expect(schluessel(r), ['pos']);
    expect(
      await eindeutigkeiten(db, 'gym_rotation'),
      {'training_id'},
      reason:
          'UNIQUE (training_id) im Tabellenkopf: Ein Training steht '
          'höchstens einmal in der Rotation (Spec 14.1)',
    );

    // Kein eigener Index, kein Fremdschlüssel.
    for (final tabelle in neueTabellen) {
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
            '$tabelle: kein eigener Index — `_reconcileSchema` kennt keine; '
            'ein CREATE UNIQUE INDEX stünde auf Geräten, die die Stufe '
            'gelaufen sind, und fehlte auf denen, die die Tabelle über den '
            'Abgleich bekamen',
      );
      expect(
        await db.customSelect('PRAGMA foreign_key_list($tabelle);').get(),
        isEmpty,
        reason:
            '$tabelle: kein Fremdschlüssel (Spec 4.1) — der Verlauf soll '
            'gerade nicht an einer Zeile hängen, die verschwinden darf',
      );
    }
  }

  /// Die `CHECK`-Bedingungen aus 4.2 **in der Datei**: Jeder Verstoß wirft,
  /// und jedem steht die Gegenprobe gegenüber, die sich nur im verletzten
  /// Wert unterscheidet — sonst wüsste man nicht, *woran* es lag.
  Future<void> pruefeChecks(AppCache db) async {
    // Die Rotation der Startbefüllung räumt der Test weg: Sie hätte sonst
    // die Positionen 1 bis 3 und die Kennungen Push, Pull, Legs belegt.
    await db.customStatement('DELETE FROM gym_rotation;');

    // --- gym_trainings ---
    await erlaubt(db, trainingSql('P-1', kategorie: "'eigene'"), 'eigene');
    await erlaubt(db, trainingSql('P-2', kategorie: "'template'"), 'template');
    await verstoesst(
      db,
      trainingSql('P-3', kategorie: "'sonstige'"),
      'kategorie IN (template, eigene)',
    );

    await erlaubt(
      db,
      trainingSql('P-4', kategorie: "'template'", geloescht: '1'),
      'ein Template darf einen Tombstone tragen',
    );
    await verstoesst(
      db,
      trainingSql('P-5', kategorie: "'eigene'", geloescht: '1'),
      'nur Templates tragen einen Tombstone (4.2); eigene werden wirklich '
      'gelöscht (4.4)',
    );

    await erlaubt(
      db,
      trainingSql('P-6', kategorie: "'eigene'", entwurf: '1'),
      'ein eigenes Training darf ein Entwurf sein',
    );
    await verstoesst(
      db,
      trainingSql('P-7', kategorie: "'template'", entwurf: '1'),
      'ein Template ist nie ein Entwurf (4.2)',
    );

    await verstoesst(db, trainingSql('P-1'), 'id ist der Primärschlüssel');
    await verstoesst(
      db,
      "INSERT INTO gym_trainings (id, kategorie, reihenfolge) "
          "VALUES ('P-8', 'eigene', 1);",
      'name ist Pflicht',
    );
    await verstoesst(
      db,
      "INSERT INTO gym_trainings (id, name, reihenfolge) "
          "VALUES ('P-9', 'Prüfname', 1);",
      'kategorie ist Pflicht (customConstraint ersetzt NOT NULL)',
    );
    await verstoesst(
      db,
      "INSERT INTO gym_trainings (id, name, kategorie) "
          "VALUES ('P-10', 'Prüfname', 'eigene');",
      'reihenfolge ist Pflicht',
    );
    await erlaubt(
      db,
      "INSERT INTO gym_trainings (id, name, kategorie, reihenfolge) "
          "VALUES ('P-11', 'Prüfname', 'eigene', 2);",
      'ohne ist_entwurf, geloescht und Dauer: Vorgaben 0, 0 und NULL',
    );
    final vorgaben = await zeilen(db, 'gym_trainings WHERE id = \'P-11\'');
    expect(vorgaben.single['ist_entwurf'], 0);
    expect(vorgaben.single['geloescht'], 0);
    expect(
      vorgaben.single['dauer_eingetragen_min'],
      isNull,
      reason: 'NULL heißt „geschätzt", nicht „0 Minuten" (Fehler 01)',
    );

    // --- entwurf_von (Plan 1, Vorschlag) ---
    await erlaubt(
      db,
      trainingSql('P-12', entwurf: '1', von: "'P-1'"),
      'ein Entwurf darf ein bestehendes Training überlagern',
    );
    await verstoesst(
      db,
      trainingSql('P-13', entwurf: '0', von: "'P-2'"),
      'entwurf_von nur bei ist_entwurf = 1',
    );
    await verstoesst(
      db,
      trainingSql('P-14', kategorie: "'template'", entwurf: '1', von: "'P-2'"),
      'entwurf_von nur bei kategorie = eigene (und ein Template ist nie ein '
      'Entwurf)',
    );
    await verstoesst(
      db,
      trainingSql('P-15', entwurf: '1', von: "'P-1'"),
      'UNIQUE (entwurf_von): je Training höchstens ein Zwischenstand',
    );
    await erlaubt(
      db,
      trainingSql('P-16', entwurf: '1'),
      'mehrere Entwürfe ohne entwurf_von nebeneinander (NULL ist nicht '
      'gleich NULL)',
    );
    await erlaubt(
      db,
      trainingSql('P-17', entwurf: '1'),
      'mehrere Entwürfe ohne entwurf_von nebeneinander (zweiter)',
    );

    // --- gym_training_uebungen ---
    await erlaubt(db, uebungSql('P-1', 1, 'benchPress'), 'erste Übung');
    await erlaubt(
      db,
      uebungSql('P-1', 2, 'pullUp', steigerung: '2.5'),
      'steigerung ist REAL und darf gesetzt sein',
    );
    await verstoesst(db, uebungSql('P-1', 0, 'dips'), 'pos >= 1');
    await verstoesst(db, uebungSql('P-1', -1, 'dips'), 'pos >= 1 (negativ)');
    await verstoesst(
      db,
      uebungSql('P-1', 3, 'dips', saetze: '0'),
      'saetze >= 1',
    );
    await erlaubt(
      db,
      uebungSql('P-1', 3, 'dips', saetze: '1'),
      'saetze = 1 (Gegenprobe)',
    );
    await verstoesst(
      db,
      uebungSql('P-1', 4, 'lateralRaise', von: '0', bis: '5'),
      'wdh_von >= 1',
    );
    await verstoesst(
      db,
      uebungSql('P-1', 4, 'lateralRaise', von: '9', bis: '8'),
      'wdh_bis >= wdh_von',
    );
    await erlaubt(
      db,
      uebungSql('P-1', 4, 'lateralRaise', von: '8', bis: '8'),
      'wdh_bis = wdh_von (Gegenprobe)',
    );
    await verstoesst(
      db,
      uebungSql('P-1', 5, 'benchPress'),
      'PRIMARY KEY (training_id, uebung_id): eine Übung höchstens einmal '
      'je Training',
    );
    await verstoesst(
      db,
      uebungSql('P-1', 1, 'legPress'),
      'UNIQUE (training_id, pos): eine Position höchstens einmal je '
      'Training',
    );
    await erlaubt(
      db,
      uebungSql('P-2', 1, 'benchPress'),
      'dieselbe Übung und Position in einem anderen Training (Gegenprobe)',
    );
    await verstoesst(
      db,
      "INSERT INTO gym_training_uebungen (training_id, pos, uebung_id, "
          "saetze, wdh_von) VALUES ('P-3', 1, 'dips', 3, 8);",
      'wdh_bis ist Pflicht',
    );

    // --- gym_training_tags ---
    await erlaubt(db, tagSql('P-1', 1, 'Gym'), 'erster Tag');
    await verstoesst(db, tagSql('P-1', 0, 'Zuhause'), 'pos >= 1');
    await verstoesst(
      db,
      tagSql('P-1', 2, 'Gym'),
      'PRIMARY KEY (training_id, tag): ein Tag höchstens einmal je Training',
    );
    await verstoesst(
      db,
      tagSql('P-1', 1, 'Zuhause'),
      'UNIQUE (training_id, pos)',
    );
    await erlaubt(
      db,
      tagSql('P-1', 2, 'Zuhause'),
      'anderer Tag, andere Position (Gegenprobe)',
    );
    await erlaubt(
      db,
      tagSql('P-2', 1, 'Gym'),
      'derselbe Tag und dieselbe Position in einem anderen Training',
    );

    // --- gym_rotation ---
    await erlaubt(db, rotationSql(1, 'P-1'), 'erster Platz');
    await verstoesst(db, rotationSql(0, 'P-2'), 'pos >= 1');
    await verstoesst(db, rotationSql(-1, 'P-2'), 'pos >= 1 (negativ)');
    await verstoesst(
      db,
      rotationSql(1, 'P-2'),
      'PRIMARY KEY (pos): ein Platz ist höchstens einmal belegt',
    );
    await verstoesst(
      db,
      rotationSql(2, 'P-1'),
      'UNIQUE (training_id): ein Training steht höchstens einmal in der '
      'Rotation (Spec 14.1)',
    );
    await erlaubt(
      db,
      rotationSql(2, 'P-2'),
      'anderer Platz, anderes Training (Gegenprobe)',
    );
    await erlaubt(
      db,
      rotationSql(3, 'GIBT-ES-NICHT'),
      'kein Fremdschlüssel: die Datenbank prüft nicht, ob es das Training '
      'gibt — das hält das Repository',
    );
  }

  /// Die Form von `gym_sitzungen.trainings_name` (Spec 4.6) — und dass der
  /// Rest der Tabelle bleibt, was er war.
  Future<void> pruefeSitzungsSpalte(AppCache db) async {
    final s = await spalten(db, 'gym_sitzungen');
    expect(s.containsKey('trainings_name'), isTrue, reason: 'die Spalte fehlt');
    expect(s['trainings_name']!.typ, 'TEXT');
    expect(
      s['trainings_name']!.nullbar,
      isTrue,
      reason:
          'nullbar: Eine alte Zeile bekommt keinen erfundenen Namen, NULL '
          'bleibt NULL (Spec 4.6)',
    );
    expect(
      s['trainings_name']!.vorgabe,
      isNull,
      reason:
          'keine Vorgabe: Ein Vorgabename behauptete, jede alte Sitzung '
          'hätte ihn zu ihrer Zeit getragen',
    );
    expect(s['trainings_name']!.schluesselNr, 0);
    expect(s.keys.toSet(), {
      'id',
      'tag',
      'zeitpunkt',
      'workout',
      'minuten',
      'notiz',
      'health_uuid',
      'aufwaermen_art',
      'aufwaermen_minuten',
      'aufwaermen_km',
      'aufwaermen_uebersprungen',
      'aufwaermen_health_uuid',
      'trainings_name',
    }, reason: 'genau eine neue Spalte (Spec 4.1), keine weitere');
    expect(s['workout']!.typ, 'TEXT');
    expect(
      s['workout']!.nullbar,
      isTrue,
      reason: '`workout` bleibt, wie sie war (Spec 4.6)',
    );
    expect(
      await eindeutigkeiten(db, 'gym_sitzungen'),
      {'tag,workout'},
      reason:
          'UNIQUE (tag, workout) bleibt — SQLite kann das nicht ändern, ohne '
          'die Tabelle neu zu bauen, und ein Neubau ist das Risiko, das '
          'Tims einzige Kopie nicht eingehen darf (Spec 4.6)',
    );
  }

  /// Die Startbefüllung nach Spec 23 (Push/Pull/Legs) und 4.3.
  Future<void> pruefeStartbefuellung(AppCache db) async {
    const erwartet = [
      (
        id: 'Push',
        name: 'Push — Brust, Schultern, Trizeps',
        dauer: 70,
        reihenfolge: 1,
        uebungen: 7,
        saetze: 23,
      ),
      (
        id: 'Pull',
        name: 'Pull — Rücken, hintere Schulter, Bizeps',
        dauer: 70,
        reihenfolge: 2,
        uebungen: 7,
        saetze: 23,
      ),
      (
        id: 'Legs',
        name: 'Legs — Beine komplett',
        dauer: 60,
        reihenfolge: 3,
        uebungen: 7,
        saetze: 25,
      ),
    ];

    final trainings = await zeilen(db, 'gym_trainings', ordnung: 'reihenfolge');
    expect(
      trainings.map((z) => z['id']).toList(),
      ['Push', 'Pull', 'Legs'],
      reason:
          'drei Templates, in dieser Reihenfolge — **keine** Zeile A bis D '
          '(Spec 23: „Gym A–D werden nicht mitgeliefert")',
    );
    for (var i = 0; i < erwartet.length; i++) {
      final e = erwartet[i];
      final z = trainings[i];
      expect(z['name'], e.name, reason: '${e.id}: Name');
      expect(z['kategorie'], 'template', reason: '${e.id}: Kategorie');
      expect(
        z['dauer_eingetragen_min'],
        e.dauer,
        reason: '${e.id}: eingetragene Dauer (Vorschlag: Workout.minutes)',
      );
      expect(z['ist_entwurf'], 0, reason: '${e.id}: kein Entwurf');
      expect(z['geloescht'], 0, reason: '${e.id}: kein Tombstone');
      expect(z['reihenfolge'], e.reihenfolge, reason: '${e.id}: Reihenfolge');
      expect(z['entwurf_von'], isNull, reason: '${e.id}: kein Zwischenstand');
    }

    final tags = await zeilen(
      db,
      'gym_training_tags',
      ordnung: 'training_id, pos',
    );
    expect(
      tags.map((z) => (z['training_id'], z['pos'], z['tag'])).toList(),
      [('Legs', 1, 'Gym'), ('Pull', 1, 'Gym'), ('Push', 1, 'Gym')],
      reason:
          'je Template genau der Tag „Gym" (Vorschlag aus Plan 12), und '
          'sonst keine Tags',
    );

    for (final e in erwartet) {
      final u = await zeilen(
        db,
        "gym_training_uebungen WHERE training_id = '${e.id}'",
        ordnung: 'pos',
      );
      expect(u, hasLength(e.uebungen), reason: '${e.id}: Zahl der Übungen');
      expect(
        u.fold<int>(0, (a, z) => a + (z['saetze']! as int)),
        e.saetze,
        reason: '${e.id}: Summe der Sätze',
      );
      expect(u.map((z) => z['pos']).toList(), [
        for (var p = 1; p <= e.uebungen; p++) p,
      ], reason: '${e.id}: Positionen ab 1, ohne Lücke');
      final katalog = ExerciseCatalog.exercisesFor(Workout.fromCode(e.id)!);
      expect(
        u
            .map(
              (z) => (z['uebung_id'], z['saetze'], z['wdh_von'], z['wdh_bis']),
            )
            .toList(),
        [for (final x in katalog) (x.id, x.sets, x.repLow, x.repHigh)],
        reason:
            '${e.id}: Übungen, Sätze und Wiederholungsbereich sind die '
            'Katalogwerte zum Zeitpunkt der Startbefüllung, als Werte '
            'kopiert (Spec 4.3)',
      );
      expect(
        u.every((z) => z['steigerung'] == null),
        isTrue,
        reason:
            '${e.id}: steigerung bleibt NULL — „aus dem Katalog"; die '
            'Stufe schreibt nie etwas anderes (Spec 4.1)',
      );
    }
    expect(
      await anzahl(db, 'gym_training_uebungen'),
      21,
      reason: 'sieben Übungen je Template, nichts darüber hinaus',
    );

    // Die Rotation: Push, Pull, Legs, in dieser Reihenfolge, ohne Tag.
    final rotation = await zeilen(db, 'gym_rotation', ordnung: 'pos');
    expect(
      rotation.map((z) => (z['pos'], z['training_id'])).toList(),
      [(1, 'Push'), (2, 'Pull'), (3, 'Legs')],
      reason:
          'die Rotation ist startbefüllt mit Push, Pull, Legs (Spec 23), '
          'in dieser Reihenfolge, Positionen ab 1',
    );
    expect(
      await anzahl(
        db,
        'gym_rotation r JOIN gym_trainings t ON t.id = r.training_id',
        't.geloescht = 0 AND t.ist_entwurf = 0',
      ),
      3,
      reason:
          'jede Kennung der Rotation hat ein lebendes Training — die '
          'Rotation kommt **nach** den Templates (Plan 16)',
    );
  }

  /// Alles auf einmal, was ein v27-Stand tragen muss.
  Future<void> pruefeEndstand(AppCache db) async {
    expect(await tabellen(db), tabellenHeute);
    await pruefeForm(db);
    await pruefeSitzungsSpalte(db);
  }

  // ═════════════════════════════════════════════════════════════════════

  group('Vorbedingungen: die Altstände sind so gebaut, wie sie gemeint '
      'sind', () {
    test('v24 hat alle heutigen Tabellen außer den vier neuen', () {
      final roh = rohdatei(v24Schema, bestand, 24);
      addTearDown(roh.close);
      final namen = rohTabellen(roh);
      expect(namen.intersection(neueTabellen), isEmpty);
      expect(
        namen,
        tabellenVorStufe25,
        reason: 'v24 hat alle heutigen Tabellen außer denen der Stufe 27',
      );
      expect(rohZeilen(roh, 'gym_sitzungen'), hasLength(3));
      expect(rohZeilen(roh, 'gym_saetze'), hasLength(3));
      expect(rohZeilen(roh, 'gym_entwuerfe'), hasLength(1));
      expect(rohZeilen(roh, 'umfaenge'), hasLength(2));
      expect(
        roh
            .select('PRAGMA table_info(gym_sitzungen);')
            .map((z) => z['name'])
            .toSet(),
        isNot(contains('trainings_name')),
        reason: 'v24 hat die Spalte der Stufe 27 noch nicht',
      );
    });

    test('v24 vorweg trägt Tabellen und Spalte schon, mit Zeilen', () {
      final roh = rohdatei(
        v24Schema + tabellenVorweg + spalteTrainingsNameVorweg,
        bestand + vorwegZeilen,
        24,
      );
      addTearDown(roh.close);
      // `tabellenHeute` minus die drei der Stufe 26: Der Altstand ist ein
      // v24-Stand, dem ein fremder Zweig die Tabellen dieser Stufe schon
      // hingelegt hat — die des Zykluskalenders hat er nicht, die legt
      // erst die Stufe 26. Die stand bis zum Zusammenführen der beiden
      // `main`-Stände am 24.11.2026 nicht in `tabellenHeute`.
      expect(
        rohTabellen(roh),
        tabellenHeute.difference(tabellenAusStufe26),
      );
      expect(rohZeilen(roh, 'gym_trainings'), hasLength(1));
      expect(rohZeilen(roh, 'gym_training_uebungen'), hasLength(2));
    });
  });

  group('Schema v27 (#532) — frisch angelegt', () {
    test('die Version ist mindestens 27 und steht so in der Datei', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      expect(db.schemaVersion, greaterThanOrEqualTo(27));
      expect(await abgelegteVersion(db), db.schemaVersion);
    });

    test('ein frischer Cache hat alle vier Tabellen und die Spalte, in der '
        'verlangten Form', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      await pruefeEndstand(db);
      expect(await tabellen(db), containsAll(neueTabellen));
    });

    test('ein frischer Cache trägt die Startbefüllung: drei Templates und '
        'die Rotation Push, Pull, Legs', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      await pruefeStartbefuellung(db);
    });

    test('die CHECK-Bedingungen aus 4.2 stehen in der Datei, und jeder '
        'Verstoß wirft', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      await pruefeChecks(db);
    });

    test('eine neue Sitzung hat keinen Namen, und ein geschriebener Name '
        'kommt unverändert zurück', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      await db.customStatement(
        'INSERT INTO gym_sitzungen (id, tag, zeitpunkt, workout) '
        "VALUES ('PRUEF-N1', '2099-05-01', '2099-05-01T17:00:00.000Z', 'A');",
      );
      await db.customStatement(
        'INSERT INTO gym_sitzungen (id, tag, zeitpunkt, workout, '
        "trainings_name) VALUES ('PRUEF-N2', '2099-05-02', "
        "'2099-05-02T17:00:00.000Z', 'PRUEF-UUID-1', 'Mein Üben — Arme');",
      );

      final z = await zeilen(db, 'gym_sitzungen', ordnung: 'id');
      expect(z[0]['trainings_name'], isNull);
      expect(z[1]['trainings_name'], 'Mein Üben — Arme');
      expect(
        z[1]['workout'],
        'PRUEF-UUID-1',
        reason:
            'die Spalte `workout` nimmt die Kennung eines eigenen '
            'Trainings (eine UUID) ohne Eingriff auf — sie hat keine '
            'CHECK-Bedingung auf ihre Werte (Spec 4.6)',
      );
    });

    test('UNIQUE (tag, workout) gilt weiter, auch für eine UUID', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      const einfuegen =
          'INSERT INTO gym_sitzungen (id, tag, zeitpunkt, workout) '
          "VALUES ('%ID%', '2099-05-01', '2099-05-01T17:00:00.000Z', "
          "'PRUEF-UUID-1');";
      await erlaubt(
        db,
        einfuegen.replaceFirst('%ID%', 'PRUEF-U1'),
        'erste Sitzung des Tages mit dieser Kennung',
      );
      await verstoesst(
        db,
        einfuegen.replaceFirst('%ID%', 'PRUEF-U2'),
        'dasselbe Training am selben Tag zweimal (UNIQUE (tag, workout))',
      );
    });
  });

  group('Migration v24 → heute', () {
    test('legt die vier Tabellen und die Spalte an, in der verlangten Form, '
        'und die Datei steht danach auf der heutigen Version', () async {
      final roh = rohdatei(v24Schema, bestand, 24);
      addTearDown(roh.close);
      final db = await oeffne(roh);
      addTearDown(db.close);

      expect(await abgelegteVersion(db), db.schemaVersion);
      expect(
        await abgelegteVersion(db),
        greaterThanOrEqualTo(27),
        reason: 'die Stufe 27 ist über diesen Bestand gelaufen',
      );
      await pruefeEndstand(db);
    });

    test('alte Sitzungen behalten ihren Stand — und ihre Spalte '
        'trainings_name ist NULL, nicht ein erfundener Name', () async {
      final roh = rohdatei(v24Schema, bestand, 24);
      addTearDown(roh.close);
      final db = await oeffne(roh);
      addTearDown(db.close);

      final z = await zeilen(db, 'gym_sitzungen');
      expect(z, hasLength(3));
      expect(
        z.map((r) => r['trainings_name']).toList(),
        [null, null, null],
        reason:
            'eine Migration füllt alte Zeilen nicht mit erfundenen '
            'Zeitstempeln — das behauptete, sie seien frisch (CLAUDE.md). '
            'Dasselbe gilt für Namen: „Gym A" aus dem Enum abzuleiten und '
            'hineinzuschreiben, hieße zu behaupten, die Sitzung habe ihn zu '
            'ihrer Zeit getragen. Die Auflösung beim Lesen (Spec 4.6, '
            'Stufe 2) braucht keinen Eintrag',
      );
      expect(z.map((r) => r['workout']).toList(), [
        'A',
        'Push',
        'Legs',
      ], reason: 'die Schlüsselspalte bleibt, wie sie war');
    });

    test('additiv: jede Zeile und jeder Wert bleibt, in allen alten '
        'Tabellen', () async {
      final roh = rohdatei(v24Schema, bestand, 24);
      addTearDown(roh.close);
      final vorher = {for (final t in alle) t: rohZeilen(roh, t)};

      final db = await oeffne(roh);
      addTearDown(db.close);

      expect(
        await abgelegteVersion(db),
        greaterThanOrEqualTo(27),
        reason: 'die Stufe 27 ist über diesen Bestand gelaufen',
      );
      for (final t in alle) {
        pruefeUnveraendert(vorher[t]!, await zeilen(db, t), t);
      }
    });

    test('nach der Migration steht in den neuen Tabellen genau die '
        'Startbefüllung und nichts, was die Stufe zusätzlich geschrieben '
        'haben könnte', () async {
      final roh = rohdatei(v24Schema, bestand, 24);
      addTearDown(roh.close);
      final db = await oeffne(roh);
      addTearDown(db.close);

      await pruefeStartbefuellung(db);
      expect(
        await anzahl(db, 'gym_trainings', "id IN ('A', 'B', 'C', 'D')"),
        0,
        reason:
            'keine Zeile A bis D — auch nicht für Tims Trainings, die '
            'unter diesen Codes im Verlauf stehen (Spec 23)',
      );
      expect(
        await anzahl(db, 'gym_trainings'),
        3,
        reason:
            'die Stufe legt kein Training aus den alten Sitzungen an: Der '
            'Verlauf hängt an keiner Zeile (Spec 4.6)',
      );
    });

    test('die Stufe erweckt keinen Tombstone: Sind alle drei Templates '
        'schon gelöscht, bleiben sie es, mit ihrem Inhalt', () async {
      final roh = rohdatei(
        v24Schema + tabellenVorweg + spalteTrainingsNameVorweg,
        bestand + tombstonesVorweg,
        24,
      );
      addTearDown(roh.close);
      final vorher = {
        for (final t in [
          'gym_trainings',
          'gym_training_uebungen',
          'gym_training_tags',
        ])
          t: rohZeilen(roh, t),
      };

      final db = await oeffne(roh);
      addTearDown(db.close);

      for (final MapEntry(key: t, value: z) in vorher.entries) {
        pruefeUnveraendert(z, await zeilen(db, t), t);
      }
      expect(
        await anzahl(db, 'gym_trainings', 'geloescht = 0'),
        0,
        reason:
            'ein Tombstone kommt nie zurück (Spec 4.4): weder durch die '
            'Stufe noch durch spieleTemplatesEin',
      );
    });

    test(
      'ein zweites Öffnen derselben Datei ändert am Schema nichts mehr',
      () async {
        final roh = rohdatei(v24Schema, bestand, 24);
        addTearDown(roh.close);

        await starte(roh);
        final nachErstem = schemaZaehler(roh);

        final zweites = await oeffne(roh);
        addTearDown(zweites.close);

        expect(
          schemaZaehler(roh),
          nachErstem,
          reason:
              'PRAGMA schema_version steigt bei jedem CREATE, ALTER und DROP. '
              'Steigt er beim zweiten Öffnen, legt die Stufe oder der Abgleich '
              'bei jedem Start etwas neu an',
        );
      },
    );
  });

  group('Startbefüllung: spieleTemplatesEin und die Rotation (Spec 4.3, '
      '23, 24)', () {
    test('zweimal geöffnet ist dasselbe wie einmal: nichts doppelt, nichts '
        'verändert (idempotent)', () async {
      final roh = rohdatei(v24Schema, bestand, 24);
      addTearDown(roh.close);

      await starte(roh);
      final vorher = {for (final t in neueTabellen) t: rohZeilen(roh, t)};

      final db = await oeffne(roh);
      addTearDown(db.close);

      for (final MapEntry(key: t, value: z) in vorher.entries) {
        pruefeUnveraendert(z, await zeilen(db, t), t);
      }
      await pruefeStartbefuellung(db);
    });

    test('ein gelöschtes Template (Tombstone) kommt beim nächsten Start nicht '
        'wieder, und seine Übungen und Tags bleiben', () async {
      final roh = rohdatei(v24Schema, bestand, 24);
      addTearDown(roh.close);

      final erstes = await oeffne(roh);
      await erstes.customStatement(
        "UPDATE gym_trainings SET geloescht = 1 WHERE id = 'Pull';",
      );
      await erstes.close();
      final vorher = {
        for (final t in [
          'gym_trainings',
          'gym_training_uebungen',
          'gym_training_tags',
        ])
          t: rohZeilen(roh, t),
      };

      final zweites = await oeffne(roh);
      addTearDown(zweites.close);

      expect(
        await anzahl(zweites, 'gym_trainings'),
        3,
        reason: 'keine zweite Zeile `Pull` — es ist ihre id, die bekannt ist',
      );
      expect(
        await anzahl(zweites, 'gym_trainings', "id = 'Pull' AND geloescht = 1"),
        1,
        reason:
            'der Tombstone bleibt ein Tombstone (Spec 4.4: Ein Tombstone '
            'kommt nie zurück)',
      );
      expect(await anzahl(zweites, 'gym_trainings', 'geloescht = 0'), 2);
      for (final MapEntry(key: t, value: z) in vorher.entries) {
        pruefeUnveraendert(z, await zeilen(zweites, t), t);
      }
    });

    test('ein vorhandenes Template wird nie angefasst: nicht der Name, nicht '
        'die Dauer, nicht Übungen, nicht Tags', () async {
      final roh = rohdatei(v24Schema, bestand, 24);
      addTearDown(roh.close);

      final erstes = await oeffne(roh);
      await erstes.customStatement(
        "UPDATE gym_trainings SET name = 'Mein Push', "
        'dauer_eingetragen_min = NULL, reihenfolge = 9 '
        "WHERE id = 'Push';",
      );
      await erstes.customStatement(
        "DELETE FROM gym_training_uebungen WHERE training_id = 'Push' "
        'AND pos = 7;',
      );
      await erstes.customStatement(tagSql('Push', 2, 'Prüftag'));
      await erstes.close();
      final vorher = {
        for (final t in [
          'gym_trainings',
          'gym_training_uebungen',
          'gym_training_tags',
        ])
          t: rohZeilen(roh, t),
      };

      final zweites = await oeffne(roh);
      addTearDown(zweites.close);

      for (final MapEntry(key: t, value: z) in vorher.entries) {
        pruefeUnveraendert(z, await zeilen(zweites, t), t);
      }
      expect(
        await anzahl(zweites, 'gym_training_uebungen', "training_id = 'Push'"),
        6,
        reason:
            'Template-Inhalte werden nie nachträglich überschrieben (Spec '
            '4.3): Die fehlende siebte Übung kommt nicht zurück',
      );
    });

    test('ein eigenes Training bleibt unberührt, und die Templates kommen '
        'neben ihm an', () async {
      final roh = rohdatei(
        v24Schema + tabellenVorweg + spalteTrainingsNameVorweg,
        bestand + vorwegZeilen,
        24,
      );
      addTearDown(roh.close);
      final vorher = {
        for (final t in [
          'gym_trainings',
          'gym_training_uebungen',
          'gym_training_tags',
        ])
          t: rohZeilen(roh, t),
      };

      final db = await oeffne(roh);
      addTearDown(db.close);

      for (final MapEntry(key: t, value: z) in vorher.entries) {
        pruefePraefix(z, await zeilen(db, t), t);
      }
      expect(
        await anzahl(db, 'gym_trainings'),
        4,
        reason: 'das eigene Training und die drei Templates',
      );
      expect(
        await anzahl(db, 'gym_trainings', "id IN ('Push', 'Pull', 'Legs')"),
        3,
      );
      expect(
        await anzahl(
          db,
          'gym_training_uebungen',
          "training_id = 'PRUEF-EIGENES-1'",
        ),
        2,
        reason: 'die Übungen des eigenen Trainings bleiben, wie sie waren',
      );
    });

    test('ein fehlendes Template kommt wieder, samt Übungen und Tags — der '
        'Mechanismus für spätere Update-Templates', () async {
      final roh = rohdatei(v24Schema, bestand, 24);
      addTearDown(roh.close);

      final erstes = await oeffne(roh);
      for (final t in ['gym_training_uebungen', 'gym_training_tags']) {
        await erstes.customStatement(
          "DELETE FROM $t WHERE training_id = 'Legs';",
        );
      }
      await erstes.customStatement(
        "DELETE FROM gym_trainings WHERE id = 'Legs';",
      );
      await erstes.close();

      final zweites = await oeffne(roh);
      addTearDown(zweites.close);

      expect(
        await anzahl(zweites, 'gym_trainings'),
        3,
        reason:
            'Spec 4.3: `spieleTemplatesEin` legt jedes Template an, dessen '
            'id in der Tabelle weder lebt noch einen Tombstone trägt',
      );
      expect(
        await anzahl(zweites, 'gym_training_uebungen', "training_id = 'Legs'"),
        7,
      );
      expect(
        await anzahl(zweites, 'gym_training_tags', "training_id = 'Legs'"),
        1,
      );
    });
  });

  group('Der Merker der Rotation (Spec 24 Nr. 3)', () {
    test('eine geleerte Rotation wird beim nächsten Start nicht wieder '
        'befüllt', () async {
      final roh = rohdatei(v24Schema, bestand, 24);
      addTearDown(roh.close);

      final erstes = await oeffne(roh);
      expect(await anzahl(erstes, 'gym_rotation'), 3, reason: 'Vorbedingung');
      await erstes.customStatement('DELETE FROM gym_rotation;');
      await erstes.close();

      final zweites = await oeffne(roh);
      addTearDown(zweites.close);

      expect(
        await anzahl(zweites, 'gym_rotation'),
        0,
        reason:
            'Löschen kann die Rotation leeren. „Füllen, wenn leer" erweckte '
            'Gelöschtes beim nächsten Start wieder — dasselbe Muster wie '
            'der Template-Tombstone. Eingespielt wird einmal je '
            'Installation, nicht bei jedem Öffnen',
      );
    });

    test('auch eine verkleinerte Rotation wird nicht wieder ergänzt, und '
        'ein Mehrfachstart ändert nichts', () async {
      final roh = rohdatei(v24Schema, bestand, 24);
      addTearDown(roh.close);

      final erstes = await oeffne(roh);
      await erstes.customStatement(
        "DELETE FROM gym_rotation WHERE training_id <> 'Legs';",
      );
      await erstes.close();
      await starte(roh);

      final db = await oeffne(roh);
      addTearDown(db.close);
      expect(
        (await zeilen(
          db,
          'gym_rotation',
        )).map((z) => z['training_id']).toList(),
        ['Legs'],
        reason: 'die Rotation bleibt, wie der Nutzer sie hinterlassen hat',
      );
    });

    test('dasselbe auf einer frischen Installation', () async {
      // Eine Datei statt `NativeDatabase.memory()`, damit sie sich zweimal
      // öffnen lässt: eine frische Installation ist hier eine leere Datei.
      final roh = sqlite3.openInMemory();
      addTearDown(roh.close);

      final erstes = await oeffne(roh);
      expect(await anzahl(erstes, 'gym_rotation'), 3, reason: 'Vorbedingung');
      await pruefeStartbefuellung(erstes);
      await erstes.customStatement('DELETE FROM gym_rotation;');
      await erstes.close();

      final zweites = await oeffne(roh);
      addTearDown(zweites.close);
      expect(await anzahl(zweites, 'gym_rotation'), 0);
      expect(
        await anzahl(zweites, 'gym_trainings'),
        3,
        reason: 'die Templates bleiben, nur die Rotation war leer',
      );
    });

    test('ein gelöschtes Template bringt die Rotation nicht zurück, und '
        'eine geleerte Rotation die Templates nicht', () async {
      final roh = rohdatei(v24Schema, bestand, 24);
      addTearDown(roh.close);

      final erstes = await oeffne(roh);
      await erstes.customStatement('DELETE FROM gym_rotation;');
      await erstes.customStatement(
        "UPDATE gym_trainings SET geloescht = 1 WHERE id = 'Push';",
      );
      await erstes.close();

      final zweites = await oeffne(roh);
      addTearDown(zweites.close);
      expect(await anzahl(zweites, 'gym_rotation'), 0);
      expect(await anzahl(zweites, 'gym_trainings', 'geloescht = 1'), 1);
      expect(await anzahl(zweites, 'gym_trainings'), 3);
    });

    test('ein Gerät mit schon vorhandener Rotationszeile behält sie, wie '
        'sie ist (nie anfassen)', () async {
      // Offen bleibt, ob die Einspielung fehlende Kennungen ergänzt oder
      // nur den Merker setzt (siehe Dateikopf). Beides lässt diese Zeile
      // stehen.
      final roh = rohdatei(
        v24Schema + tabellenVorweg + spalteTrainingsNameVorweg,
        "$bestand INSERT INTO gym_rotation (pos, training_id) "
        "VALUES (1, 'Legs');",
        24,
      );
      addTearDown(roh.close);

      final db = await oeffne(roh);
      addTearDown(db.close);

      final z = await zeilen(db, 'gym_rotation', ordnung: 'pos');
      expect(z, isNotEmpty);
      expect(
        (z.first['pos'], z.first['training_id']),
        (1, 'Legs'),
        reason: 'eine vorhandene Zeile fasst die Einspielung nie an',
      );
      expect(
        z.map((r) => r['training_id']).toSet().length,
        z.length,
        reason: 'jedes Training höchstens einmal',
      );
    });

    test('Tabellen vom Abgleich nachgelegt: die Rotation wird beim ersten '
        'Start eingespielt', () async {
      final roh = rohdatei(v24Schema + spalteTrainingsNameVorweg, bestand, 25);
      addTearDown(roh.close);

      final db = await oeffne(roh);
      addTearDown(db.close);

      await pruefeStartbefuellung(db);
    });
  });

  group('Die Stufe ist zweimal ausführbar (#234/#240)', () {
    test('stehen Tabellen und Spalte schon da, öffnet die Datei, und jede '
        'Zeile darin bleibt — auch der Name einer Sitzung', () async {
      final roh = rohdatei(
        v24Schema + tabellenVorweg + spalteTrainingsNameVorweg,
        "$bestand $vorwegZeilen "
        "UPDATE gym_sitzungen SET trainings_name = 'Prüfname Sitzung' "
        "WHERE id = 'PRUEF-S2';",
        24,
      );
      addTearDown(roh.close);
      final vorher = {
        for (final t in [
          ...alle,
          'gym_trainings',
          'gym_training_uebungen',
          'gym_training_tags',
        ])
          t: rohZeilen(roh, t),
      };

      final db = await oeffne(roh);
      addTearDown(db.close);

      expect(await abgelegteVersion(db), db.schemaVersion);
      expect(
        await abgelegteVersion(db),
        greaterThanOrEqualTo(27),
        reason:
            'die Stufe 27 lief über eine Datei, die ihre Tabellen und ihre '
            'Spalte schon trug, und scheiterte nicht an „table already '
            'exists" oder „duplicate column name". Alle Zweige bauen unter '
            'derselben Bundle-ID und benutzen dieselbe Datei',
      );
      for (final MapEntry(key: t, value: z) in vorher.entries) {
        pruefePraefix(z, await zeilen(db, t), t);
      }
      expect(
        (await zeilen(
          db,
          'gym_sitzungen',
          ordnung: 'id',
        )).map((z) => z['trainings_name']).toList(),
        [null, 'Prüfname Sitzung', null],
        reason:
            'kein DROP TABLE IF EXISTS vor dem CREATE und kein '
            'Zurücksetzen der Spalte. Eine Stufe, die nie scheitert und '
            'dabei Namen löscht, ist die schlechtere Stufe',
      );
      await pruefeEndstand(db);
    });

    test('Tabellen schon da, Spalte nicht: die Spalte kommt', () async {
      final roh = rohdatei(
        v24Schema + tabellenVorweg,
        bestand + vorwegZeilen,
        24,
      );
      addTearDown(roh.close);

      final db = await oeffne(roh);
      addTearDown(db.close);

      await pruefeSitzungsSpalte(db);
      expect(await tabellen(db), tabellenHeute);
      expect(await anzahl(db, 'gym_trainings', "id = 'PRUEF-EIGENES-1'"), 1);
    });

    test('Spalte schon da, Tabellen nicht: die Tabellen kommen, und der '
        'Name in der Spalte bleibt', () async {
      final roh = rohdatei(
        v24Schema + spalteTrainingsNameVorweg,
        "$bestand UPDATE gym_sitzungen SET trainings_name = 'Prüfname' "
        "WHERE id = 'PRUEF-S1';",
        24,
      );
      addTearDown(roh.close);

      final db = await oeffne(roh);
      addTearDown(db.close);

      await pruefeEndstand(db);
      expect(
        (await zeilen(
          db,
          'gym_sitzungen',
          ordnung: 'id',
        )).map((z) => z['trainings_name']).toList(),
        ['Prüfname', null, null],
      );
    });
  });

  group('Abgleich beim Öffnen (#233)', () {
    test('eine Datei auf 25, der Tabellen und Spalte fehlen, bekommt sie — '
        'und verliert nichts', () async {
      // Ein Zweig hat die Nummer hochgezogen, bevor seine Stufe fertig
      // war: `if (from < 25)` läuft dann nie.
      final roh = rohdatei(v24Schema, bestand, 25);
      addTearDown(roh.close);
      final vorher = {for (final t in alle) t: rohZeilen(roh, t)};

      final db = await oeffne(roh);
      addTearDown(db.close);

      expect(
        await tabellen(db),
        containsAll(neueTabellen),
        reason:
            'onUpgrade läuft bei from == 25 nicht in die Stufe 27 — die '
            'Tabellen kommen nur über den Abgleich',
      );
      await pruefeEndstand(db);
      for (final t in alle) {
        pruefeUnveraendert(vorher[t]!, await zeilen(db, t), t);
      }
      expect(
        (await zeilen(db, 'gym_sitzungen')).map((z) => z['trainings_name']),
        everyElement(isNull),
        reason: 'auch über den Abgleich: NULL, kein erfundener Name',
      );
    });

    test('eine Datei auf 24, der `gym_sitzungen` ganz fehlt (fremder '
        'Zwischenstand), öffnet ohne „no such table", und die Tabelle '
        'kommt — mit der Spalte', () async {
      // Die Stufe 27 darf `trainings_name` nicht an eine Tabelle hängen
      // wollen, die es in der Datei nicht gibt: Der Abgleich legt sie
      // danach an, aus der heutigen Definition, und damit samt Spalte.
      // Dieselbe Lage prüfen `schema_v19_test.dart` und
      // `schema_v20_test.dart` mit ihren Dateien auf 19 und 20.
      final roh = rohdatei(v11Schema, v11Bestand, 24);
      addTearDown(roh.close);
      final vorher = {
        for (final t in ['tages_werte', 'stammdaten']) t: rohZeilen(roh, t),
      };

      final db = await oeffne(roh);
      addTearDown(db.close);

      await pruefeEndstand(db);
      for (final MapEntry(key: t, value: z) in vorher.entries) {
        pruefeUnveraendert(z, await zeilen(db, t), t);
      }
    });

    test('eine Datei auf 25 mit Tabellen, aber ohne Spalte, bekommt die '
        'Spalte', () async {
      final roh = rohdatei(
        v24Schema + tabellenVorweg,
        bestand + vorwegZeilen,
        25,
      );
      addTearDown(roh.close);

      final db = await oeffne(roh);
      addTearDown(db.close);

      await pruefeSitzungsSpalte(db);
      await pruefeEndstand(db);
      expect(await anzahl(db, 'gym_trainings', "id = 'PRUEF-EIGENES-1'"), 1);
    });

    test(
      'eine Datei auf 25 mit Spalte, aber ohne Tabellen, bekommt die '
      'Tabellen — zuerst die Tabellen, dann die Spalte (Stufen 13–17)',
      () async {
        final roh = rohdatei(
          v24Schema + spalteTrainingsNameVorweg,
          bestand,
          25,
        );
        addTearDown(roh.close);

        final db = await oeffne(roh);
        addTearDown(db.close);

        expect(await tabellen(db), containsAll(neueTabellen));
        await pruefeEndstand(db);
      },
    );
  });

  group('Von weit unten: v11 → heute', () {
    test('ein v11-Stand öffnet ohne Fehler und hat danach alles, in der '
        'verlangten Form, samt Startbefüllung', () async {
      final roh = rohdatei(v11Schema, v11Bestand, 11);
      addTearDown(roh.close);
      final vorher = {
        for (final t in ['tages_werte', 'stammdaten']) t: rohZeilen(roh, t),
      };

      final db = await oeffne(roh);
      addTearDown(db.close);

      // Scheiterte eine Stufe, würfe schon dieser erste Zugriff.
      expect(await abgelegteVersion(db), db.schemaVersion);
      await pruefeEndstand(db);
      await pruefeStartbefuellung(db);
      for (final MapEntry(key: t, value: z) in vorher.entries) {
        pruefeUnveraendert(z, await zeilen(db, t), t);
      }
    });
  });

  group('Plan 1: entwurf_von (Vorschlag, nicht entschieden)', () {
    test('die Templates tragen keinen Zwischenstand, und die Spalte ist '
        'nullbar', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      expect(
        await anzahl(db, 'gym_trainings', 'entwurf_von IS NOT NULL'),
        0,
        reason: 'die Startbefüllung schreibt keinen Zwischenstand',
      );
      expect(
        (await spalten(db, 'gym_trainings'))['entwurf_von']!.nullbar,
        isTrue,
      );
    });
  });
}
