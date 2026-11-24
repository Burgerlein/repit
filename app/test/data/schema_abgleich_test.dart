// `drift` exportiert ein eigenes `isNull` (Spaltenausdruck für `IS NULL` in
// Abfragen) — das verdeckt sonst den gleichnamigen `package:matcher`-Matcher,
// den `expect(..., isNull)` unten braucht. Dieselbe Begründung wie in
// `test/data/schema_v7_test.dart`, Zeile 1–4.
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show Database;
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/data/cache_repository.dart';
import 'package:repit/health/health_types.dart';

import 'schema_tabellen.dart';

/// Tests für den **Schema-Abgleich beim Öffnen** (#233).
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden.
///
/// Nachbar von `schema_v7_test.dart` (#194), `schema_v8_test.dart` (#193)
/// und `schema_v9_test.dart` (#202): derselbe Aufbau, dieselben Hilfsmittel,
/// von Hand gebaute Altschemata. Was dort je eine Stufe prüft, prüft hier
/// das, was **neben** den Stufen laufen muss.
///
/// **Diese Datei war gegen die Stufennummerierung des Zweigs
/// `koerper-datenkette` geschrieben** (v6 = Gewicht und Trainingsminuten,
/// v7 = Körperfett und fettfreie Masse) und ist am 03.11.2026 auf die
/// zusammengeführte Kette nachgezogen worden: v6 sind jetzt die
/// Schlafeinträge (#131), v7 das Gewicht (#194), v8 die Nachtwerte auf
/// `naechte` (#193), v9 die beiden Körperspalten (#202, #235). Nachgezogen
/// hat das der Test-Agent, nicht der Implementierende (`CLAUDE.md`,
/// Rollentrennung); Tim hat die Entscheidung nicht gesehen. Geprüft wird
/// dasselbe wie vorher — nur die Zahlen und die Altstände sind an die Kette
/// angepasst.
///
/// *Hinweis für die Nachwelt:* Die Datei lief schon **vor** dem
/// Zusammenführen rot. `main` stand auf `schemaVersion => 8`, während hier
/// durchgehend die 7 erwartet wurde; bei #193 ist sie nicht mitgezogen
/// worden. Nachgemessen am 03.11.2026 in einem eigenen Arbeitsbaum auf
/// `main`: `flutter test test/health test/data` → 275 grün, ein einziger
/// Fehlschlag, und das war diese Datei.
///
/// ## Der belegte Befund
///
/// Tims iPhone am 02./03.11.2026 (#233, mit `xcrun devicectl device copy
/// from` vom Gerät geholt):
///
/// ```
/// PRAGMA user_version;        → 7
/// PRAGMA table_info(tages_werte);
///   tag schritte ruhepuls_bpm gelesen_am hrv_ms resp_rate
///   recovery_hr_drop gewicht_kg trainings_minuten
/// ```
///
/// Die Datei behauptet eine Version, deren Spalten sie nicht hat: Die 7 war
/// damals die Nummer, unter der der Zweig `koerper-datenkette`
/// `koerperfett_pct` und `fettfrei_kg` führte, und genau die beiden fehlten.
/// Jeder Schreibversuch scheitert mit `SqliteException(1): table
/// tages_werte has no column named koerperfett_pct`; der Schirm zeigt
/// weiter alte Werte, weil ein gescheiterter Nachlauf den Cache stehen
/// lässt (`CLAUDE.md`, und das ist richtig) — und verdeckt damit seinen
/// eigenen Fehler.
///
/// Ursache: `onUpgrade` prüft `if (from < n)`. Steht die Datei schon auf
/// `n`, läuft die Stufe nie, auch wenn ihre Spalten fehlen. Hochgezogen hat
/// die Nummer ein **anderer Zweig** — alle Zweige bauen unter derselben
/// Bundle-ID und benutzen dieselbe Datei
/// `Library/Application Support/cache.sqlite`. Mit mehreren parallelen
/// Arbeitssträngen ist das kein Ausnahmefall, sondern trifft jeden
/// künftigen Zweigwechsel wieder.
///
/// **Die Fälle unten stellen den Mechanismus an der heutigen Kette nach,
/// nicht die damalige Zahl.** Der Zustand „Nummer stimmt, Spalten der
/// obersten Stufe fehlen" heißt heute `user_version = 9` ohne
/// `koerperfett_pct`/`fettfrei_kg`. Die 7 von damals steckt in einer
/// anderen Datei: `schema_fremde_spalten_test.dart` prüft den Stand des
/// Geräts vom 03.11.2026 (#240) mit seinen vorweggenommenen Nacht-Spalten.
///
/// ## Was diese Datei verbindlich vorgibt
///
/// **Keine neue API.** Alles hier geht durch `AppCache(...)` und
/// `CacheRepository`, so wie die App selbst: Datenbank öffnen, erste Abfrage,
/// fertig. Ein eigener öffentlicher Einstiegspunkt für den Abgleich wäre eine
/// Entscheidung über die Bauform, und die gehört dem, der implementiert —
/// nicht dem Test. Geprüft wird ausschließlich, was nach dem Öffnen in der
/// Datei steht.
///
/// Daraus folgt eine Festlegung, die unvermeidlich ist: Der Abgleich läuft
/// **beim Öffnen**, ohne dass jemand ihn aufruft, und er läuft **auch dann,
/// wenn `onUpgrade` nicht läuft** (`from == to`). Alles andere ließe die
/// Dateien, um die es geht, unberührt.
///
/// `AppCache.schemaVersion` bleibt bei 9, und die Stufen bleiben, wie sie
/// sind — der Abgleich kommt **zusätzlich** (#233, „Was zu tun ist").
///
/// ## Wo die Grenze liegt, und warum
///
/// **Abgedeckt: fehlende Spalten und fehlende Tabellen.** Beides ist additiv
/// nachziehbar (`ALTER TABLE … ADD COLUMN`, `CREATE TABLE`), beides lässt
/// vorhandene Zeilen in Ruhe, und beides ist genau das, was ein Zweigwechsel
/// hinterlässt: Der eine Zweig kennt eine Spalte oder eine Tabelle, die der
/// andere noch nicht angelegt hat.
///
/// **Nicht abgedeckt — und das ist Absicht:**
///
/// - **Eine Spalte mit falschem Typ, fehlendem `NOT NULL`, fehlendem
///   Vorgabewert oder ein abweichender Primärschlüssel.** SQLite kann das
///   nicht nachträglich ändern; die Reparatur wäre ein Tabellenneubau mit
///   Umkopieren. Ein Neubau kann Zeilen verlieren, und die oberste Zusage
///   dieses Tickets ist, dass Zeilen überleben. Wer so eine Datei hat, hat
///   ein Problem, das ein stiller Abgleich nicht lösen darf, sondern
///   benennen muss.
/// - **Eine fehlende Spalte, die `NOT NULL` ohne Vorgabewert ist, in einer
///   Tabelle, die schon Zeilen hat.** `ALTER TABLE … ADD COLUMN` lehnt das
///   ab, und es gibt keinen ehrlichen Wert, mit dem man die Lücke füllen
///   könnte (`ziel_werte.schlafziel_minuten` wäre so ein Fall). In der
///   heutigen Tabellenliste kommt das nicht vor — jede Spalte, die nach dem
///   Anlegen ihrer Tabelle dazukam, ist nullbar —, aber die Grenze gehört
///   genannt, bevor jemand eine solche Spalte anhängt.
/// - **Verlorene Daten.** Eine Tabelle, die fehlt, kommt leer zurück. Der
///   Abgleich stellt die Form wieder her, nicht den Inhalt; eine Tabelle mit
///   erfundenen Zeilen wäre schlimmer als eine leere.
/// - **Die Gegenrichtung: Nummer zu niedrig, Spalten schon da.** Eine Datei
///   auf `user_version = 8`, deren `tages_werte` die v9-Spalten bereits
///   trägt, lässt `onUpgrade` die v9-Stufe laufen, und die scheitert mit
///   `duplicate column name: koerperfett_pct`. Das ist derselbe
///   Zweigwechsel, nur andersherum, und es ist ein eigener Fehler: Hier
///   müssten die **Stufen** robust werden, während #233 ausdrücklich sagt,
///   die Stufen bleiben wie sie sind. `schema_v9_test.dart` („Ein Gerät,
///   das schon auf v9 steht") stützt sich sogar darauf, dass ein zweites
///   `ALTER TABLE` fehlschlägt. Diese Datei prüft die Gegenrichtung deshalb
///   **nicht**. Sie lag beim Schreiben dieser Zeilen als #234 auf dem Board
///   und ist inzwischen gebaut (`_addColumnIfMissing` in `cache.dart`);
///   geprüft wird sie in `schema_fremde_spalten_test.dart` und
///   `schema_stufen_robust_test.dart`, nicht hier.
///
/// ## Woran „nicht angefasst" gemessen wird
///
/// Am SQLite-Schema-Zähler `PRAGMA schema_version` (nicht zu verwechseln mit
/// `PRAGMA user_version` oder mit `AppCache.schemaVersion`): SQLite erhöht
/// ihn bei jedem `CREATE`, `ALTER` und `DROP` und sonst nie. Nachgemessen am
/// 03.11.2026: `PRAGMA user_version = 9` erhöht ihn nicht,
/// `CREATE TABLE IF NOT EXISTS` auf eine bestehende Tabelle erhöht ihn nicht,
/// `ALTER TABLE … ADD COLUMN` erhöht ihn.
///
/// Das ist der richtige Maßstab, weil er die **Wirkung** misst und nicht die
/// Bauform: Ein Abgleich, der `PRAGMA table_info` liest und dann feststellt,
/// dass nichts zu tun ist, besteht den Test; einer, der vorsorglich bei jedem
/// Start Spalten anhängt oder Tabellen neu baut, besteht ihn nicht. Genau das
/// ist die Gefahr, gegen die der Normalfall abgesichert gehört.
///
/// ## Was absichtlich nicht geprüft wird
///
/// - **Der Weg über `drift_dev schema dump`/`SchemaVerifier`.** Dieselbe
///   Begründung wie in `migration_test.dart`, `schema_v7_test.dart` und
///   `schema_v9_test.dart`: Es gibt keine eingefrorenen Schema-Dumps unter
///   `drift_schemas/`, und eine Testdatei, die der Implementierung
///   vorausgeht, kann sie nicht anlegen. Die kaputten Dateien unten sind
///   deshalb **von Hand** gebaut.
/// - **Die einzelnen Stufen v2 bis v9.** Die stehen in
///   `migration_test.dart`, `schema_v3_test.dart`,
///   `schlaf_eintrag_test.dart`, `schema_v7_test.dart`,
///   `schema_v8_test.dart` und `schema_v9_test.dart` und bleiben dort. Hier
///   wird nur belegt, dass der Abgleich sie nicht beschädigt.
///
/// **Alle Zahlen hier sind erfunden** — keine echten Gesundheitswerte.
void main() {
  // ---------------------------------------------------------------------
  // Bausteine der von Hand gebauten Dateien.
  //
  // `gelesen_am`, `beginn` und `ende` liegen als ISO-Text mit `Z` vor, weil
  // `AppCache` mit `storeDateTimeAsText: true` arbeitet (`cache.dart`) —
  // drifts Standard (Unix-Sekunden) gäbe sie als Ortszeit zurück, und ein
  // als UTC abgelegter Wert wäre dann ungleich sich selbst.
  // ---------------------------------------------------------------------

  /// `tages_werte` vollständig — die elf Spalten von Schema v9, seit der
  /// Stufe 26 (#95) dazu `vo2max`. Nachgezogen vom Test-Agenten; **Tim hat
  /// die Änderung nicht gesehen.**
  const tagesWerteVollstaendig = '''
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
      fettfrei_kg REAL,
      vo2max REAL
    );
  ''';

  /// Genau die Spaltenliste von Tims Gerät: die beiden Spalten der obersten
  /// Stufe fehlen, alles davor ist da. (Auf dem Gerät hieß diese Stufe 7,
  /// heute heißt sie 9 — dieselben zwei Spalten, siehe Dateikopf.)
  const tagesWerteOhneV9Spalten = '''
    CREATE TABLE tages_werte (
      tag TEXT NOT NULL PRIMARY KEY,
      schritte INTEGER,
      ruhepuls_bpm INTEGER,
      gelesen_am TEXT,
      hrv_ms REAL,
      resp_rate REAL,
      recovery_hr_drop INTEGER,
      gewicht_kg REAL,
      trainings_minuten REAL
    );
  ''';

  /// Zwei Stufen Rückstand statt einer — ein Zweig, der von v6 aus auf eine
  /// eigene „9" gesprungen ist. Der Abgleich darf nicht nur die letzte Stufe
  /// nachziehen, sondern muss die ganze Lücke sehen.
  const tagesWerteOhneVierSpalten = '''
    CREATE TABLE tages_werte (
      tag TEXT NOT NULL PRIMARY KEY,
      schritte INTEGER,
      ruhepuls_bpm INTEGER,
      gelesen_am TEXT,
      hrv_ms REAL,
      resp_rate REAL,
      recovery_hr_drop INTEGER
    );
  ''';

  const tabelleTagesgefuehle = '''
    CREATE TABLE tagesgefuehle (
      tag TEXT NOT NULL PRIMARY KEY,
      wert INTEGER NOT NULL
    );
  ''';

  /// Die Tabellen, die es seit v1 gibt.
  const tabellenV1 = '''
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
  ''';

  /// `naechte` vor der Stufe 8 — nur der Tag und der Stand des Laufs.
  const tabelleNaechteV7 = '''
    CREATE TABLE naechte (
      tag TEXT NOT NULL PRIMARY KEY,
      gelesen_am TEXT
    );
  ''';

  /// `naechte` nach der Stufe 8 (#193): dazu die drei Werte **einer**
  /// Nacht, gerechnet über das Schlaffenster statt über den Kalendertag.
  const tabelleNaechteV8 = '''
    CREATE TABLE naechte (
      tag TEXT NOT NULL PRIMARY KEY,
      gelesen_am TEXT,
      ruhepuls_bpm REAL,
      hrv_ms REAL,
      resp_rate REAL
    );
  ''';

  const tabelleSchlafAbschnitte = '''
    CREATE TABLE schlaf_abschnitte (
      tag TEXT NOT NULL,
      quelle INTEGER NOT NULL,
      lfd_nr INTEGER NOT NULL,
      phase TEXT NOT NULL,
      beginn TEXT NOT NULL,
      ende TEXT NOT NULL,
      PRIMARY KEY (tag, quelle, lfd_nr)
    );
  ''';

  const tabelleZielWerte = '''
    CREATE TABLE ziel_werte (
      id INTEGER NOT NULL DEFAULT 0,
      schlafziel_minuten INTEGER NOT NULL,
      schlafenszeit_minuten INTEGER NOT NULL,
      wochenziel_trainingsminuten INTEGER NOT NULL,
      PRIMARY KEY (id)
    );
  ''';

  /// Die von Hand eingetragenen Nächte und Tagschläfe aus #131 — die
  /// Tabelle, die die Stufe 6 anlegt.
  const tabelleSchlafEintraege = '''
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
  ''';

  /// Alle Tabellen außer `tages_werte`, auf dem Stand von v7:
  /// `schlaf_eintraege` ist da, `naechte` noch schmal.
  const uebrigeTabellenV7 =
      '$tabellenV1$tabelleNaechteV7$tabelleSchlafAbschnitte'
      '$tabelleZielWerte$tabelleSchlafEintraege';

  /// Dieselben Tabellen auf dem Stand von v8 und v9: dazu die drei Spalten
  /// auf `naechte`.
  const uebrigeTabellenV9 =
      '$tabellenV1$tabelleNaechteV8$tabelleSchlafAbschnitte'
      '$tabelleZielWerte$tabelleSchlafEintraege';

  /// Dieselben Tabellen ohne `schlaf_eintraege` — für den Fall, in dem
  /// eine **ganze Tabelle** fehlt. Bis zum 03.11.2026 stand hier
  /// `tagesgefuehle`; die Tabelle gibt es seit #269 nicht mehr, der Fall
  /// schon.
  const uebrigeTabellenV9OhneEintraege =
      '$tabellenV1$tabelleNaechteV8$tabelleSchlafAbschnitte'
      '$tabelleZielWerte';

  /// Die Stammdaten aus der Stufe 11 (Task 1 des Ernährungsplans) — die
  /// Tabelle, die ein Gerät auf dem heutigen Stand zusätzlich hat. Die
  /// Altstände unten bekommen sie bewusst **nicht**: Dort ist ihr Fehlen
  /// echt, und die v11-Stufe legt sie beim Durchlauf an.
  const tabelleStammdaten = '''
    CREATE TABLE stammdaten (
      id INTEGER NOT NULL DEFAULT 0,
      groesse_cm INTEGER,
      geburtsjahr INTEGER,
      zielgewicht_kg REAL,
      zieldatum TEXT,
      PRIMARY KEY (id)
    );
  ''';

  /// Die fünf Ernährungstabellen aus der Stufe 12 (Task 3 des
  /// Ernährungsplans) — wie `tabelleStammdaten` gehören sie zum heutigen
  /// Stand und **nicht** in die Altstände unten: Dort ist ihr Fehlen echt,
  /// und die v12-Stufe legt sie beim Durchlauf an.
  ///
  /// `eintraege` steht wörtlich so, wie `schema_v12_test.dart` die Tabelle
  /// festlegt, `lebensmittel` mit den zwölf Spalten der Stufe 13 so, wie
  /// `schema_v13_test.dart` sie festlegt (#285), und dazu `barcode` und
  /// `herkunft` der Stufe 14 so, wie `schema_v14_test.dart` sie festlegt
  /// (#284); `eintraege` dazu mit `vorschlag` der Stufe 15 so, wie
  /// `schema_v15_test.dart` sie festlegt (#332). Mit der Stufe 17 (#393)
  /// tragen `portionen` ihre vier Spalten, `eintraege` den
  /// Portions-Schnappschuss und `lebensmittel` `portionen_abgefragt_am`, so,
  /// wie `schema_v17_test.dart` sie festlegt — nachgezogen vom Test-Agenten,
  /// nicht von Tim gesehen. Mit der Stufe 19 (#403) trägt `eintraege` dazu
  /// `fluessig`, so, wie `schema_v19_test.dart` sie festlegt (INTEGER,
  /// nullbar, ohne Vorgabe) — ebenso nachgezogen vom Test-Agenten, nicht von
  /// Tim gesehen. Mit der Stufe 25 (#542 unter #543) tragen `lebensmittel`
  /// und `rezepte` ihre Sync-Felder, so, wie `migration_v25_test.dart` sie
  /// festlegt (`uuid`, `geaendert_am`, `geloescht_am`, `autor`, bei
  /// `lebensmittel` dazu `quelle_schluessel` — alle TEXT, nullbar, ohne
  /// Vorgabewert); nachgezogen am 23.11.2026 vom Test-Agenten, **Tim hat die
  /// Änderung nicht gesehen**. `rezept_zutaten` trägt vorerst nur seinen
  /// Schlüssel; seine Spalten gehören der Aufgabe, die sie füllt.
  const tabellenErnaehrung = '''
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
      fluessig INTEGER NOT NULL DEFAULT 0,
      zuletzt_benutzt TEXT,
      barcode TEXT,
      herkunft TEXT NOT NULL DEFAULT 'eigen',
      portionen_abgefragt_am TEXT,
      uuid TEXT,
      geaendert_am TEXT,
      geloescht_am TEXT,
      autor TEXT,
      quelle_schluessel TEXT
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
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      uuid TEXT,
      geaendert_am TEXT,
      geloescht_am TEXT,
      autor TEXT
    );
    CREATE TABLE rezept_zutaten (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT
    );
  ''';

  /// Die beiden KI-Tabellen der Stufe 15 (#332), so, wie
  /// `schema_v15_test.dart` sie festlegt — wie `tabellenErnaehrung` nur im
  /// heutigen Stand, nicht in den Altständen. `ki_einstellungen` trägt
  /// dazu den Schlüssel `id` mit Vorgabe 0, den die Spec offenlässt; ohne
  /// ihn legte der Abgleich die Spalte nach und der Normalfall wäre keiner
  /// mehr. Von Hand geschrieben, nicht aus dem heutigen Code erzeugt.
  const tabellenKi = '''
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

  /// Die Tabelle der Stufe 16 (#311), so, wie `schema_v16_test.dart` sie
  /// festlegt — wie `tabellenKi` nur im heutigen Stand. Von Hand
  /// geschrieben; nachgezogen vom Test-Agenten, nicht von Tim gesehen.
  const tabelleWasser = '''
    CREATE TABLE wasser_eintraege (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      tages_schluessel TEXT NOT NULL,
      zeitpunkt TEXT NOT NULL,
      menge_ml REAL NOT NULL,
      health_uuid TEXT,
      health_stand TEXT NOT NULL DEFAULT 'offen'
    );
  ''';

  /// Die Tabelle der Stufe 18 (#410, festes Kalorienziel), so, wie
  /// `schema_v18_test.dart` sie festlegt — wie `tabelleWasser` nur im
  /// heutigen Stand. Von Hand geschrieben; nachgezogen vom Test-Agenten,
  /// nicht von Tim gesehen.
  const tabelleKalorienziele = '''
    CREATE TABLE kalorienziele (
      ab_tag TEXT NOT NULL PRIMARY KEY,
      kcal REAL NOT NULL,
      herkunft TEXT NOT NULL,
      grundumsatz_kcal REAL,
      aktiv_kcal REAL,
      koerperziel_kcal REAL
    );
  ''';

  /// Die Tabelle der Stufe 20 (#430 unter #374, Aufteilung des
  /// Tagesziels auf die Mahlzeiten), so, wie `schema_v20_test.dart` sie
  /// festlegt — wie `tabelleKalorienziele` nur im heutigen Stand. Von Hand
  /// geschrieben; nachgezogen vom Test-Agenten, nicht von Tim gesehen.
  const tabelleMahlzeitAufteilungen = '''
    CREATE TABLE mahlzeit_aufteilungen (
      ab_tag TEXT NOT NULL PRIMARY KEY,
      fruehstueck_pct INTEGER,
      mittag_pct INTEGER,
      abend_pct INTEGER
    );
  ''';

  /// Die Tabelle der Stufe 21 (#444 unter #404, Ereignisse), so, wie
  /// `schema_v21_test.dart` sie festlegt — wie
  /// `tabelleMahlzeitAufteilungen` nur im heutigen Stand. Von Hand
  /// geschrieben; nachgezogen vom Test-Agenten, nicht von Tim gesehen.
  const tabelleEreignisse = '''
    CREATE TABLE ereignisse (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      art TEXT NOT NULL,
      von TEXT NOT NULL,
      bis TEXT NOT NULL,
      notiz TEXT,
      angelegt TEXT NOT NULL,
      geaendert TEXT
    );
  ''';

  /// Die Tabelle der Stufe 22 (#451 unter #375, Wachbelege für die
  /// Tagesgrenze), so, wie `schema_v22_test.dart` sie festlegt — wie
  /// `tabelleEreignisse` nur im heutigen Stand. Von Hand geschrieben;
  /// nachgezogen vom Test-Agenten, nicht von Tim gesehen.
  const tabelleWachBelege = '''
    CREATE TABLE wach_belege (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      zeitpunkt TEXT NOT NULL,
      art TEXT NOT NULL
    );
  ''';

  /// Die Tabelle der Stufe 23 (#476 unter #88, Tims Maßband-Messungen),
  /// so, wie `schema_v23_test.dart` sie festlegt — wie `tabelleWachBelege`
  /// nur im heutigen Stand. Von Hand geschrieben, Spalte für Spalte aus
  /// `Umfaenge` in `app/lib/data/tables.dart` abgelesen: Fehlte hier eine
  /// Spalte oder die ganze Tabelle, zöge `_reconcileSchema` sie beim
  /// Öffnen nach und erhöhte dabei den Schema-Zähler — aus dem Normalfall
  /// „nichts wird angefasst" würde still ein Migrationsfall, und die
  /// Zählung unten meinte etwas anderes als ihr Name. Nachgezogen vom
  /// Test-Agenten, **Tim hat die Änderung nicht gesehen**.
  const tabelleUmfaenge = '''
    CREATE TABLE umfaenge (
      tag TEXT NOT NULL,
      mass TEXT NOT NULL,
      zentimeter REAL NOT NULL,
      eingetragen_am TEXT NOT NULL,
      quelle TEXT NOT NULL,
      PRIMARY KEY (tag, mass, quelle)
    );
  ''';

  /// Die drei Tabellen der Stufe 26 (#592 unter #539, der Zykluskalender;
  /// beim Zusammenführen von 25 auf 26 gerückt),
  /// so, wie `schema_v26_test.dart` sie festlegt — wörtlich aus dessen
  /// `zyklusVorweg` übernommen, aus demselben Grund wie bei
  /// `tabelleUmfaenge`: Fehlte hier eine Spalte oder eine ganze Tabelle,
  /// zöge `_reconcileSchema` sie beim Öffnen nach und erhöhte dabei den
  /// Schema-Zähler. Nachgezogen vom Test-Agenten mit `TEST_AENDERN=1`,
  /// **Tim hat die Änderung nicht gesehen**.
  const tabellenZyklus = '''
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

  /// Der Stand, den ein Gerät nach der Stufe 25 haben müsste — nichts
  /// fehlt, `tagesgefuehle` ist weg (#269), `stammdaten` ist da, die
  /// fünf Ernährungstabellen auch, `lebensmittel` trägt seine Spalten
  /// samt Strichcode, Herkunft und `portionen_abgefragt_am`, `portionen`
  /// ihre vier Spalten, `eintraege` die Spalte `vorschlag` und den
  /// Portions-Schnappschuss samt `fluessig` (Stufe 20, #403), und die
  /// beiden KI-Tabellen, `wasser_eintraege`, die drei Gym-Tabellen
  /// (Stufe 18, #78 mit #40), `kalorienziele` (Stufe 19, #410),
  /// `mahlzeit_aufteilungen` (Stufe 21, #430), `ereignisse`
  /// (Stufe 22, #444), `wach_belege` (Stufe 23, #451) und `umfaenge`
  /// (Stufe 24, #476) stehen da; `lebensmittel` und `rezepte` tragen dazu
  /// die Sync-Felder der Stufe 25 (#542 unter #543).
  ///
  /// Die drei Gym-Tabellen aus Stufe 18 (#78 mit #40) — nachgezogen am
  /// 10.11.2026 mit `TEST_AENDERN=1`. Ohne sie legte der Abgleich sie beim
  /// Öffnen an, und „eine vollständige Datei wird nicht verändert" wäre
  /// über eine Datei gelaufen, die gar nicht vollständig ist.
  const tabellenGym = '''
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
  ''';

  /// Die vier Tabellen der Stufe 25 (#532 unter #531, eigene Trainings und
  /// die gespeicherte Rotation), so, wie `schema_v25_test.dart` sie
  /// festlegt, von Hand geschrieben — dazu trägt `tabellenGym` oben die
  /// Spalte `gym_sitzungen.trainings_name`. Fehlte hier eine Tabelle oder
  /// die Spalte, zöge `_reconcileSchema` sie beim Öffnen nach und erhöhte
  /// dabei den Schema-Zähler — aus dem Normalfall „nichts wird angefasst"
  /// würde still ein Migrationsfall. Nachgezogen vom Test-Agenten, **Tim
  /// hat die Änderung nicht gesehen**.
  const tabellenEigeneTrainings = '''
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

  const vollstaendigesSchema =
      '$tagesWerteVollstaendig$uebrigeTabellenV9$tabelleStammdaten'
      '$tabellenErnaehrung$tabellenKi$tabelleWasser$tabellenGym'
      '$tabelleKalorienziele'
      '$tabelleMahlzeitAufteilungen$tabelleEreignisse$tabelleWachBelege'
      '$tabelleUmfaenge$tabellenZyklus$tabellenEigeneTrainings';

  /// Tims Datei, an der heutigen Kette: Nummer stimmt, Spalten von 8.
  const schemaOhneV9Spalten =
      '$tagesWerteOhneV9Spalten$uebrigeTabellenV9';

  /// Dieselbe Lücke auf einer Datei, die **vor** #269 stehengeblieben ist
  /// und `tagesgefuehle` deshalb noch hat.
  const schemaOhneV9SpaltenMitGefuehlen =
      '$tagesWerteOhneV9Spalten$tabelleTagesgefuehle$uebrigeTabellenV9';

  /// Nummer stimmt, Spalten von 6.
  const schemaOhneVierSpalten =
      '$tagesWerteOhneVierSpalten$uebrigeTabellenV9';

  /// Ein echtes v6-Gerät: `tages_werte` auf dem Stand von v6, `naechte`
  /// noch schmal — und `tagesgefuehle` noch da, so wie damals.
  const schemaSauberV6 =
      '$tagesWerteOhneVierSpalten$tabelleTagesgefuehle$uebrigeTabellenV7';

  /// Nummer stimmt, Spalten vollständig, aber eine ganze Tabelle fehlt.
  const schemaOhneSchlafEintraege =
      '$tagesWerteVollstaendig$uebrigeTabellenV9OhneEintraege';

  /// Schema v1 — vor `gelesen_am`, vor den Erholungs-Spalten, vor jeder
  /// zusätzlichen Tabelle. Derselbe Stand wie in `migration_test.dart`,
  /// `schema_v7_test.dart` und `schema_v9_test.dart`.
  const v1Schema = '''
    CREATE TABLE tages_werte (
      tag TEXT NOT NULL PRIMARY KEY,
      schritte INTEGER,
      ruhepuls_bpm INTEGER
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
  ''';

  /// Alles außer der `tages_werte`-Zeile: eine Nacht mit einem Abschnitt
  /// und Tims eingestellte Ziele.
  const bestandRest = '''
    INSERT INTO naechte (tag, gelesen_am)
      VALUES ('2026-10-20', '2026-10-20T09:00:00.000Z');
    INSERT INTO schlaf_abschnitte (tag, quelle, lfd_nr, phase, beginn, ende)
      VALUES ('2026-10-20', 0, 0, 'core',
              '2026-10-19T21:00:00.000Z', '2026-10-20T04:30:00.000Z');
    INSERT INTO ziel_werte (id, schlafziel_minuten, schlafenszeit_minuten,
                            wochenziel_trainingsminuten)
      VALUES (0, 450, 1290, 300);
  ''';

  const bestandTagesgefuehl = '''
    INSERT INTO tagesgefuehle (tag, wert) VALUES ('2026-10-20', 4);
  ''';

  /// Ein Tag mit allen sieben Werten, die ein v7-/v8-Stand kennt.
  const zeileMitSiebenWerten = '''
    INSERT INTO tages_werte
      (tag, schritte, ruhepuls_bpm, gelesen_am, hrv_ms, resp_rate,
       recovery_hr_drop, gewicht_kg, trainings_minuten)
      VALUES ('2026-10-20', 8042, 51, '2026-10-20T09:00:00.000Z',
              38.4, 15.1, 27, 81.4, 47.5);
  ''';

  /// Ein Tag mit den fünf Werten, die ein v6-Stand kennt.
  const zeileMitFuenfWerten = '''
    INSERT INTO tages_werte
      (tag, schritte, ruhepuls_bpm, gelesen_am, hrv_ms, resp_rate,
       recovery_hr_drop)
      VALUES ('2026-10-20', 8042, 51, '2026-10-20T09:00:00.000Z',
              38.4, 15.1, 27);
  ''';

  /// Ein Tag mit allen neun Werten, die Schema v9 kennt.
  const zeileMitNeunWerten = '''
    INSERT INTO tages_werte
      (tag, schritte, ruhepuls_bpm, gelesen_am, hrv_ms, resp_rate,
       recovery_hr_drop, gewicht_kg, trainings_minuten, koerperfett_pct,
       fettfrei_kg)
      VALUES ('2026-10-20', 8042, 51, '2026-10-20T09:00:00.000Z',
              38.4, 15.1, 27, 81.4, 47.5, 21.3, 64.1);
  ''';

  const bestandOhneV9Werte = '$zeileMitSiebenWerten$bestandRest';
  const bestandOhneV9WerteMitGefuehl =
      '$zeileMitSiebenWerten$bestandRest'
      '$bestandTagesgefuehl';
  const bestandOhneVierWerte = '$zeileMitFuenfWerten$bestandRest';
  const bestandOhneVierWerteMitGefuehl =
      '$zeileMitFuenfWerten$bestandRest'
      '$bestandTagesgefuehl';
  const bestandVollstaendig = '$zeileMitNeunWerten$bestandRest';
  const v1Bestand = '''
    INSERT INTO tages_werte (tag, schritte, ruhepuls_bpm)
      VALUES ('2026-10-20', 8042, 51);
  ''';

  // ---------------------------------------------------------------------
  // Hilfsmittel
  // ---------------------------------------------------------------------

  /// Baut eine Datei von Hand und setzt ihre Nummer selbst. Ohne
  /// `PRAGMA user_version` meldet SQLite Version 0, drift riefe `onCreate`
  /// statt `onUpgrade` auf — in `migration_test.dart` ausführlich begründet.
  ///
  /// [stempel] bekommt, falls gesetzt, den Stand von `PRAGMA schema_version`
  /// **vor** dem ersten Zugriff durch drift: Der `setup`-Rückruf läuft beim
  /// Öffnen der Verbindung und damit vor Migration und Abgleich.
  QueryExecutor datei(
    String schema,
    String bestand,
    int version, {
    void Function(int)? stempel,
  }) => NativeDatabase.memory(
    setup: (Database roh) {
      roh.execute(schema);
      if (bestand.isNotEmpty) {
        roh.execute(bestand);
      }
      roh.execute('PRAGMA user_version = $version;');
      stempel?.call(
        roh.select('PRAGMA schema_version;').single['schema_version'] as int,
      );
    },
  );

  /// Die Nummer, die eine Datei trägt, die alle Stufen hinter sich hat.
  /// Steht hier als Zahl, weil diese Datei Altstände **von Hand** baut:
  /// Ein Fixture, das seine Nummer aus dem heutigen Code zöge, wäre kein
  /// Altstand mehr. Steigt die Schemaversion, steigt sie hier mit — und
  /// die Fälle, die von „Nummer stimmt, Inhalt nicht" handeln, bleiben
  /// genau das.
  ///
  /// Seit dem 10.11.2026 die 19 (#403), nicht die 18: Die 18 gehört der
  /// Stufe, die parallel auf `ziel-fest` entsteht (Kopf von
  /// `schema_v20_test.dart`). Beim Zusammenführen stößt genau diese Zeile
  /// an deren Fassung; richtig ist danach die höhere Zahl, und
  /// [vollstaendigesSchema] trägt beide Stufen. Nachgezogen vom
  /// Test-Agenten, nicht von Tim gesehen.
  ///
  /// Seit dem 10.11.2026 die 20 (#430, `mahlzeit_aufteilungen`);
  /// nachgezogen vom Test-Agenten, nicht von Tim gesehen.
  ///
  /// Seit dem 10.11.2026 die 21 (#444, `ereignisse`); nachgezogen vom
  /// Test-Agenten, nicht von Tim gesehen.
  ///
  /// Seit dem 10.11.2026 die 22 (#451, `wach_belege`); nachgezogen vom
  /// Test-Agenten, nicht von Tim gesehen.
  ///
  /// Seit dem 11.11.2026 die 23 (#476, `umfaenge`); nachgezogen vom
  /// Test-Agenten, **Tim hat die Änderung nicht gesehen**.
  ///
  /// Seit dem 11.11.2026 die 24: Beim Zusammenführen von `umfaenge-88`
  /// und `main` (#485) behält die Gym-Stufe (#78) die 18, und die Stufen
  /// dieses Zweigs sind um eins nach oben gerückt. [vollstaendigesSchema]
  /// trägt seitdem auch die drei Gym-Tabellen. Nachgezogen vom
  /// Test-Agenten, **Tim hat die Änderung nicht gesehen**.
  ///
  /// Seit dem 23.11.2026 trug sie die 25 (#542 unter #543): Die Stufe
  /// hängt `lebensmittel` die fünf und `rezepte` die vier Sync-Felder an.
  /// [vollstaendigesSchema] trägt sie seitdem mit — ohne das zöge der
  /// Abgleich sie beim Öffnen nach, und „eine vollständige Datei wird
  /// nicht verändert" liefe über eine Datei, die keine ist.
  ///
  /// Seit dem 24.11.2026 die **26** (#592 unter #539, die drei
  /// Zyklus-Tabellen).
  ///
  /// Beim Zusammenführen der beiden `main`-Stände am 24.11.2026 kamen zwei
  /// weitere hinzu, beide von dort um zwei nach oben gerückt: die **27**
  /// (#532, eigene Trainings — vier Tabellen und die Spalte
  /// `gym_sitzungen.trainings_name`, verlangt in `schema_v27_test.dart`)
  /// und die **28** (#95 mit #16, `tages_werte.vo2max`, verlangt in
  /// `schema_v28_test.dart`). [vollstaendigesSchema] und
  /// [alleTagesWerteSpalten] tragen beides seitdem mit. Gerückt wird nach
  /// oben, nie verschoben (#485, dieselbe Auflösung wie bei v18, v24 und
  /// v26). Nachgezogen vom Test-Agenten mit `TEST_AENDERN=1`, **Tim hat
  /// die Änderung nicht gesehen**.
  const heutigeNummer = 28;

  /// Die Version, die in der Datei selbst steht — nicht die, die
  /// `AppCache.schemaVersion` behauptet.
  Future<int> abgelegteVersion(AppCache db) async {
    final zeile = await db.customSelect('PRAGMA user_version;').getSingle();
    return zeile.read<int>('user_version');
  }

  /// Der SQLite-Schema-Zähler. Steigt bei jedem `CREATE`, `ALTER` und
  /// `DROP`, bei nichts sonst — siehe Dateikopf.
  Future<int> schemaStempel(AppCache db) async {
    final zeile = await db.customSelect('PRAGMA schema_version;').getSingle();
    return zeile.read<int>('schema_version');
  }

  /// Die Spalten einer Tabelle, so wie sie **tatsächlich** in der Datei
  /// stehen — nicht, was der Dart-Code über sie behauptet. Genau diese
  /// Auskunft fehlte `onUpgrade`.
  Future<Set<String>> spalten(AppCache db, String tabelle) async {
    final zeilen = await db.customSelect('PRAGMA table_info($tabelle);').get();
    return zeilen.map((z) => z.read<String>('name')).toSet();
  }

  /// Die Tabellen, die es in der Datei wirklich gibt.
  Future<Set<String>> tabellen(AppCache db) async {
    final zeilen = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name NOT LIKE 'sqlite_%';",
        )
        .get();
    return zeilen.map((z) => z.read<String>('name')).toSet();
  }

  /// Der SQLite-Speichertyp eines Feldes (`'null'`, `'real'`, `'integer'`,
  /// `'text'`). Schärfer als ein Dart-seitiger `isNull`-Vergleich: Er zeigt,
  /// dass in der Spalte wirklich nichts steht — kein `0.0`, das Dart
  /// vielleicht noch als Zahl durchreichte.
  Future<String> speichertyp(AppCache db, String spalte, String tag) async {
    final zeile = await db
        .customSelect(
          'SELECT typeof($spalte) AS typ FROM tages_werte WHERE tag = ?;',
          variables: [Variable<String>(tag)],
        )
        .getSingle();
    return zeile.read<String>('typ');
  }

  /// Alle zwölf Spalten, die `tages_werte` heute hat: die elf von Schema
  /// v9, seit der Stufe 26 (#95) dazu `vo2max` — verlangt in
  /// `schema_v26_test.dart`. Nachgezogen vom Test-Agenten; **Tim hat die
  /// Änderung nicht gesehen.**
  const alleTagesWerteSpalten = {
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
    'vo2max',
  };

  /// Alle fünf Spalten, die `naechte` seit Schema v8 hat (#193).
  const alleNaechteSpalten = {
    'tag',
    'gelesen_am',
    'ruhepuls_bpm',
    'hrv_ms',
    'resp_rate',
  };

  // ---------------------------------------------------------------------

  group('Nummer stimmt, Spalten fehlen — Tims Datei vom 03.11.2026 (#233)', () {
    // Die Nummer der Datei steht auf dem heutigen Stand — genau das war
    // Tims Fall: formal richtig, inhaltlich nicht. Die Zahl kommt aus
    // `AppCache.schemaVersion`, damit dieser Fall bei der nächsten Stufe
    // nicht zu einem Migrationsfall wird, von dem er nicht handelt.
    QueryExecutor kaputt() => datei(
      schemaOhneV9Spalten,
      bestandOhneV9Werte,
      heutigeNummer,
    );

    test('nach dem Öffnen hat tages_werte alle zwölf Spalten', () async {
      final db = AppCache(kaputt());
      addTearDown(db.close);

      expect(
        await spalten(db, 'tages_werte'),
        alleTagesWerteSpalten,
        reason:
            'die Datei stand auf 9 und hatte die Spalten der Stufe 9 nicht. '
            '`if (from < 9)` lief deshalb nie. Der Abgleich muss die '
            'tatsächlichen Spalten lesen, nicht der Nummer glauben — eine '
            'Migration, die nur auf die Nummer schaut, glaubt der Nummer '
            '(#233)',
      );
    });

    test('und ein Schreibvorgang gelingt danach — genau der, der auf dem '
        'Gerät scheiterte', () async {
      final db = AppCache(kaputt());
      addTearDown(db.close);
      final repo = CacheRepository(db);

      await repo.schreibeTagesWerte(const [
        DailyMetrics(
          tag: '2026-10-21',
          steps: 9100,
          weightKg: 81.0,
          bodyFatPct: 21.3,
          leanKg: 64.1,
        ),
      ], gelesenAm: DateTime.utc(2026, 11, 3, 8));

      final zeilen = (await repo.liesTagesWerte(DataWindow.unlimited))!.werte;
      final neu = zeilen.firstWhere((w) => w.tag == '2026-10-21');

      expect(
        neu.bodyFatPct,
        21.3,
        reason:
            'auf dem Gerät warf genau dieser Weg `SqliteException(1): table '
            'tages_werte has no column named koerperfett_pct`, und weil ein '
            'gescheiterter Nachlauf den Cache stehen lässt, blieb der Fehler '
            'unsichtbar — der Schirm zeigte stundenlang denselben Stand',
      );
      expect(neu.leanKg, 64.1);
      expect(neu.weightKg, 81.0);
    });

    test(
      'die vorhandene Zeile behält jeden ihrer Werte und ihren Stand',
      () async {
        final db = AppCache(kaputt());
        addTearDown(db.close);

        final zeile = (await db.select(db.tagesWerte).get()).single;

        expect(zeile.tag, '2026-10-20');
        expect(zeile.schritte, 8042);
        expect(zeile.ruhepulsBpm, 51);
        expect(zeile.hrvMs, 38.4);
        expect(zeile.respRate, 15.1);
        expect(zeile.recoveryHrDrop, 27);
        expect(zeile.gewichtKg, 81.4);
        expect(zeile.trainingsMinuten, 47.5);
        expect(
          zeile.gelesenAm,
          DateTime.utc(2026, 10, 20, 9),
          reason:
              'der Abgleich zieht Spalten nach, er baut nichts neu. Ein '
              'Tabellenneubau mit Umkopieren könnte Zeilen verlieren, und '
              'ein nachgetragenes "jetzt" behauptete, die Zeile sei frisch',
        );
      },
    );

    test('und der übrige Bestand steht ebenfalls unverändert da', () async {
      final db = AppCache(kaputt());
      addTearDown(db.close);

      expect((await db.select(db.naechte).get()).single.tag, '2026-10-20');
      final abschnitt = (await db.select(db.schlafAbschnitte).get()).single;
      expect(abschnitt.phase, 'core');
      expect(abschnitt.beginn, DateTime.utc(2026, 10, 19, 21));
      expect(abschnitt.ende, DateTime.utc(2026, 10, 20, 4, 30));

      expect(
        (await db.select(db.zielWerte).get()).single.wochenzielTrainingsminuten,
        300,
        reason:
            'Tims eingestellte Ziele fallen nicht auf die Vorbelegung '
            'zurück — das sähe für ihn aus wie "meine Einstellungen sind weg"',
      );
    });

    test('die nachgezogenen Spalten stehen auf NULL, nicht auf 0', () async {
      final db = AppCache(kaputt());
      addTearDown(db.close);

      final zeile = (await db.select(db.tagesWerte).get()).single;
      expect(zeile.koerperfettPct, isNull);
      expect(zeile.fettfreiKg, isNull);

      // Schärfer als der Dart-Vergleich darüber: In der Datei steht wirklich
      // NULL. Ein `0.0` käme als 'real' heraus.
      expect(
        await speichertyp(db, 'koerperfett_pct', '2026-10-20'),
        'null',
        reason:
            'für diese Zeile wurde nie ein Körperfettwert geholt. "0,0 %" '
            'behauptete eine Messung, die es nicht gab — das ist Fehler 01 '
            'in neuer Verpackung (CLAUDE.md)',
      );
      expect(await speichertyp(db, 'fettfrei_kg', '2026-10-20'), 'null');
    });

    test(
      'und die Nummer bleibt stehen — der Abgleich erfindet keine Version',
      () async {
        final db = AppCache(kaputt());
        addTearDown(db.close);

        await db.select(db.tagesWerte).get();

        expect(
          await abgelegteVersion(db),
          db.schemaVersion,
          reason:
              'die Datei war formal schon auf dem richtigen Stand, nur ihr '
              'Inhalt nicht. Eine erhöhte oder zurückgesetzte Nummer machte '
              'aus einer geheilten Datei eine zweite, andere Lüge',
        );
      },
    );
  });

  group('Zwei Stufen Rückstand bei richtiger Nummer', () {
    QueryExecutor kaputt() => datei(
      schemaOhneVierSpalten,
      bestandOhneVierWerte,
      heutigeNummer,
    );

    test('alle fünf fehlenden Spalten werden nachgezogen, nicht nur die der '
        'letzten Stufe', () async {
      final db = AppCache(kaputt());
      addTearDown(db.close);

      expect(
        await spalten(db, 'tages_werte'),
        alleTagesWerteSpalten,
        reason:
            'ein Zweig kann von v6 aus auf seine eigene "9" gesprungen sein. '
            'Der Abgleich vergleicht mit dem, was das Schema heute vorsieht, '
            'und nicht mit dem, was die letzte Stufe hinzugefügt hat',
      );
    });

    test(
      'die Zeile behält ihre fünf Werte, die fünf neuen Spalten sind leer',
      () async {
        final db = AppCache(kaputt());
        addTearDown(db.close);

        final zeile = (await db.select(db.tagesWerte).get()).single;
        expect(zeile.schritte, 8042);
        expect(zeile.hrvMs, 38.4);
        expect(zeile.gelesenAm, DateTime.utc(2026, 10, 20, 9));

        expect(await speichertyp(db, 'gewicht_kg', '2026-10-20'), 'null');
        expect(
          await speichertyp(db, 'trainings_minuten', '2026-10-20'),
          'null',
        );
        expect(await speichertyp(db, 'koerperfett_pct', '2026-10-20'), 'null');
        expect(await speichertyp(db, 'fettfrei_kg', '2026-10-20'), 'null');
        // Seit der Stufe 26 (#95) kommt `vo2max` als fünfte dazu —
        // nachgezogen vom Test-Agenten, **Tim hat die Änderung nicht
        // gesehen.**
        expect(await speichertyp(db, 'vo2max', '2026-10-20'), 'null');
      },
    );
  });

  group('Nummer stimmt, eine ganze Tabelle fehlt', () {
    // Bis zum 03.11.2026 war die fehlende Tabelle `tagesgefuehle`. Die gibt
    // es seit #269 nicht mehr, den Fall schon — er steht jetzt auf
    // `schlaf_eintraege`.
    QueryExecutor kaputt() => datei(
      schemaOhneSchlafEintraege,
      bestandVollstaendig,
      heutigeNummer,
    );

    test('die fehlende Tabelle wird angelegt und ist abfragbar', () async {
      final db = AppCache(kaputt());
      addTearDown(db.close);

      expect(
        await tabellen(db),
        tabellenHeute,
        reason:
            'dasselbe kann jede Tabelle treffen, und eine fehlende Tabelle '
            'ebenso (#233, "Was zu tun ist"). Eine Tabelle ist additiv '
            'nachziehbar, ohne eine einzige vorhandene Zeile anzufassen',
      );
      expect(await db.select(db.schlafEintraege).get(), isEmpty);
    });

    test('sie kommt leer, nicht mit erfundenen Zeilen', () async {
      final db = AppCache(kaputt());
      addTearDown(db.close);

      expect(
        await db.select(db.schlafEintraege).get(),
        isEmpty,
        reason:
            'der Abgleich stellt die Form wieder her, nicht den Inhalt. '
            'Was in der Tabelle stand, ist weg; eine erfundene Zeile wäre '
            'eine Behauptung über eine Nacht, die Tim nie eingetragen hat',
      );

      // Und benutzbar ist sie auch: ein Eintrag geht durch.
      await db
          .into(db.schlafEintraege)
          .insert(
            SchlafEintraegeCompanion.insert(
              tag: '2026-10-21',
              art: 'nacht',
              lfdNr: 0,
              schlafMinuten: 415,
            ),
          );
      expect((await db.select(db.schlafEintraege).get()).single.tag,
          '2026-10-21');
    });

    test('und der Bestand der übrigen Tabellen bleibt unberührt', () async {
      final db = AppCache(kaputt());
      addTearDown(db.close);

      final zeile = (await db.select(db.tagesWerte).get()).single;
      expect(zeile.schritte, 8042);
      expect(zeile.koerperfettPct, 21.3);
      expect(zeile.fettfreiKg, 64.1);
      expect(zeile.gelesenAm, DateTime.utc(2026, 10, 20, 9));
      expect(
        (await db.select(db.zielWerte).get()).single.schlafzielMinuten,
        450,
      );
    });
  });

  group('Der Normalfall bleibt unberührt', () {
    test('eine vollständige Datei wird beim Öffnen nicht verändert', () async {
      var vorher = -1;
      final db = AppCache(
        datei(
          vollstaendigesSchema,
          bestandVollstaendig,
          heutigeNummer,
          stempel: (wert) => vorher = wert,
        ),
      );
      addTearDown(db.close);

      // Der erste Zugriff: Das Öffnen selbst ist bei drift lazy.
      await db.select(db.tagesWerte).get();

      expect(
        await schemaStempel(db),
        vorher,
        reason:
            'PRAGMA schema_version steigt bei jedem CREATE, ALTER und DROP '
            'und bei nichts sonst. Bleibt er stehen, hat niemand am Schema '
            'gearbeitet. Täte der Abgleich das bei jedem Start, wäre er '
            'kein Abgleich mehr, sondern ein Umbau bei jedem Öffnen — und '
            'das träfe jedes Gerät, nicht nur das kaputte',
      );
    });

    test(
      'und ihr Bestand und ihre Nummer stehen danach unverändert da',
      () async {
        final db = AppCache(
          datei(
            vollstaendigesSchema,
            bestandVollstaendig,
            heutigeNummer,
          ),
        );
        addTearDown(db.close);

        final zeile = (await db.select(db.tagesWerte).get()).single;
        expect(zeile.schritte, 8042);
        expect(zeile.gewichtKg, 81.4);
        expect(zeile.trainingsMinuten, 47.5);
        expect(zeile.koerperfettPct, 21.3);
        expect(zeile.fettfreiKg, 64.1);
        expect(zeile.gelesenAm, DateTime.utc(2026, 10, 20, 9));

        expect(await abgelegteVersion(db), db.schemaVersion);
        expect(await tabellen(db), tabellenHeute);
      },
    );

    test('eine frisch angelegte Datei ebenfalls nicht — onCreate hat schon '
        'alles gebaut', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      await db.select(db.tagesWerte).get();
      final nachDemAnlegen = await schemaStempel(db);

      // Ein zweiter Zugriff auf dieselbe Verbindung: Hier darf nichts mehr
      // passieren. (Der Abgleich läuft beim Öffnen, nicht je Abfrage — wäre
      // er je Abfrage und täte etwas, fiele es hier auf.)
      await db.select(db.naechte).get();

      expect(await schemaStempel(db), nachDemAnlegen);
      expect(await spalten(db, 'tages_werte'), alleTagesWerteSpalten);
      expect(await spalten(db, 'naechte'), alleNaechteSpalten);
      expect(await tabellen(db), tabellenHeute);
      expect(await abgelegteVersion(db), db.schemaVersion);
    });
  });

  group('Die gewöhnlichen Stufen laufen weiter wie bisher', () {
    test(
      'v8 → heute: die Stufe zieht die beiden Spalten, der Bestand bleibt',
      () async {
        final db = AppCache(
          datei(
            schemaOhneV9SpaltenMitGefuehlen,
            bestandOhneV9WerteMitGefuehl,
            8,
          ),
        );
        addTearDown(db.close);

        expect(await spalten(db, 'tages_werte'), alleTagesWerteSpalten);
        expect(
          await tabellen(db),
          tabellenHeute,
          reason:
              'zwischen v8 und heute liegt auch die Stufe 10, und die '
              'nimmt `tagesgefuehle` weg (#269)',
        );
        expect(
          await abgelegteVersion(db),
          db.schemaVersion,
          reason:
              'derselbe Dateiinhalt wie Tims Gerät, nur mit der richtigen '
              'Nummer — hier muss die Stufe laufen, nicht der Abgleich. Ein '
              'Abgleich, der die Spalten vor `onUpgrade` nachzöge, ließe die '
              'Stufe danach mit `duplicate column name` scheitern',
        );

        final zeile = (await db.select(db.tagesWerte).get()).single;
        expect(zeile.gewichtKg, 81.4);
        expect(zeile.trainingsMinuten, 47.5);
        expect(zeile.gelesenAm, DateTime.utc(2026, 10, 20, 9));
        expect(await speichertyp(db, 'koerperfett_pct', '2026-10-20'), 'null');
        expect(await speichertyp(db, 'fettfrei_kg', '2026-10-20'), 'null');
      },
    );

    test('v6 → heute: alle ausstehenden Stufen laufen, nichts geht '
        'verloren', () async {
      final db = AppCache(
        datei(schemaSauberV6, bestandOhneVierWerteMitGefuehl, 6),
      );
      addTearDown(db.close);

      expect(await spalten(db, 'tages_werte'), alleTagesWerteSpalten);
      expect(
        await spalten(db, 'naechte'),
        alleNaechteSpalten,
        reason:
            'zwischen v6 und v9 liegt auch die Stufe 8, und die arbeitet an '
            '`naechte`, nicht an `tages_werte`. Ein Durchlauf, der nur die '
            'Spalten der letzten Stufe zöge, ließe sie aus',
      );
      expect(await tabellen(db), tabellenHeute);
      expect(await abgelegteVersion(db), db.schemaVersion);

      final zeile = (await db.select(db.tagesWerte).get()).single;
      expect(zeile.schritte, 8042);
      expect(zeile.ruhepulsBpm, 51);
      expect(zeile.hrvMs, 38.4);
      expect(zeile.respRate, 15.1);
      expect(zeile.recoveryHrDrop, 27);
      expect(zeile.gelesenAm, DateTime.utc(2026, 10, 20, 9));
      expect(
        (await db.select(db.zielWerte).get()).single.wochenzielTrainingsminuten,
        300,
      );
    });

    test('v1 → heute: der ganze Durchlauf von unten endet oben, alle '
        'Tabellen sind da und leer', () async {
      final db = AppCache(datei(v1Schema, v1Bestand, 1));
      addTearDown(db.close);

      expect(await abgelegteVersion(db), db.schemaVersion);
      expect(await tabellen(db), tabellenHeute);
      expect(await spalten(db, 'tages_werte'), alleTagesWerteSpalten);
      expect(await spalten(db, 'naechte'), alleNaechteSpalten);

      final zeile = (await db.select(db.tagesWerte).get()).single;
      expect(zeile.schritte, 8042);
      expect(zeile.ruhepulsBpm, 51);
      expect(
        zeile.gelesenAm,
        isNull,
        reason:
            'v1 kannte die Spalte nicht — woher die Zeile stammt, weiß '
            'niemand mehr, und ein nachgetragenes "jetzt" wäre gelogen',
      );

      expect(await db.select(db.naechte).get(), isEmpty);
      expect(await db.select(db.schlafAbschnitte).get(), isEmpty);
      expect(await db.select(db.zielWerte).get(), isEmpty);
      expect(await db.select(db.schlafEintraege).get(), isEmpty);
    });
  });
}
