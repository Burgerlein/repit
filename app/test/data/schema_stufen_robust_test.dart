// `drift` exportiert ein eigenes `isNull` (Spaltenausdruck für `IS NULL` in
// Abfragen) — das verdeckt sonst den gleichnamigen `package:matcher`-Matcher,
// den `expect(..., isNull)` unten braucht. Dieselbe Begründung wie in
// `test/data/schema_abgleich_test.dart`, Zeile 1–4.
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show Database;
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/data/cache_repository.dart';
import 'package:repit/health/health_types.dart';

import 'schema_tabellen.dart';

/// Tests für **robuste Migrationsstufen** (#234) — die Gegenrichtung zu
/// `schema_abgleich_test.dart` (#233).
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden.
///
/// Nachbar von `schema_v7_test.dart` (#194), `schema_v8_test.dart` (#193),
/// `schema_v9_test.dart` (#202) und `schema_abgleich_test.dart` (#233):
/// derselbe Aufbau, dieselben Hilfsmittel, von Hand gebaute Dateien. Was
/// dort je eine Stufe prüft, prüft hier, dass **jede** Stufe eine Datei
/// überlebt, in der ihre Arbeit schon getan ist.
///
/// **Diese Datei stammt aus dem Zweig `koerper-datenkette` und war gegen
/// dessen eigene Stufennummerierung geschrieben** (v6 = Gewicht und
/// Trainingsminuten, v7 = Körperfett und fettfreie Masse). Beim
/// Zusammenführen mit `main` am 03.11.2026 ist sie auf die vereinigte Kette
/// nachgezogen worden — v6 sind jetzt die Schlafeinträge (#131), v7 das
/// Gewicht (#194), v8 die Nachtwerte auf `naechte` (#193) und v9 die beiden
/// Körperspalten (#202, #235). Nachgezogen hat das der Test-Agent, nicht
/// der Implementierende (`CLAUDE.md`, Rollentrennung); Tim hat die
/// Entscheidung nicht gesehen. Geprüft wird dasselbe wie vorher: Die Zahlen
/// und die Altstände sind an die Kette angepasst, die Anforderung nicht.
///
/// **`main` hat zu derselben Anforderung eine eigene, kürzere Datei:**
/// `schema_fremde_spalten_test.dart`. Beide bleiben. Jene geht vom Zustand
/// aus, der am 03.11.2026 wirklich auf Tims iPhone stand (#240), und prüft
/// zusätzlich den allgemeinen Fall über alle Stufen hinweg; diese deckt die
/// halb gelaufene Stufe, die vorweggenommene Tabelle und den gemischten
/// Rückstand von ganz unten ab, die dort fehlen.
///
/// ## Der Befund
///
/// Nicht auf dem Gerät beobachtet, sondern aus demselben Mechanismus
/// abgeleitet, den #233 belegt: Alle Zweige bauen unter derselben Bundle-ID
/// und benutzen dieselbe Datei `Library/Application Support/cache.sqlite`.
///
/// #233 beschreibt die eine Richtung — Nummer zu hoch, Spalten fehlen. Die
/// andere ist genauso möglich: Ein Zweig, der die v9-Spalten schon anlegt,
/// hinterlässt eine `tages_werte` **mit** `koerperfett_pct` und
/// `fettfrei_kg`. Steht in der Datei `user_version = 8` (weil der andere
/// Zweig seine eigene Nummerierung führt), läuft beim nächsten Start
/// `if (from < 9)` und damit
/// `ALTER TABLE tages_werte ADD COLUMN koerperfett_pct REAL`:
///
/// ```
/// SqliteException(1): duplicate column name: koerperfett_pct
/// ```
///
/// Das ist schlimmer als #233. Dort scheitert nur der Schreibweg, und der
/// Cache bleibt lesbar stehen; hier scheitert die Migration selbst, also
/// lässt sich die Datenbank **gar nicht mehr öffnen**.
///
/// ## Warum der Abgleich aus #233 hier nicht hilft
///
/// `_reconcileSchema` hängt an `beforeOpen` und läuft damit **nach**
/// `onUpgrade` (`cache.dart`, und das ist dort richtig begründet: ein
/// vorgezogener Abgleich nähme den Stufen die Arbeit weg und ließe sie
/// danach erst recht mit `duplicate column name` scheitern). Er kommt also
/// nie an die Reihe — `onUpgrade` wirft vorher. Und selbst wenn er liefe,
/// fände er nichts zu tun: Es **fehlt** ja nichts.
///
/// Robust werden müssen deshalb die **Stufen selbst**.
///
/// ## Was diese Datei verbindlich vorgibt
///
/// **Keine neue API.** Alles hier geht durch `AppCache(...)` und
/// `CacheRepository`, so wie die App selbst: Datenbank öffnen, erste
/// Abfrage, fertig. Wie die Stufen robust werden — ob jede `addColumn` ihre
/// Spalte vorher nachsieht, ob ein gemeinsames Hilfsmittel das tut, ob die
/// Prüfung aus `_reconcileSchema` wiederverwendet wird —, ist eine
/// Entscheidung über die Bauform und gehört dem, der implementiert.
/// Geprüft wird ausschließlich, was nach dem Öffnen in der Datei steht.
///
/// `AppCache.schemaVersion` bleibt bei 9, und der Abgleich aus #233 bleibt,
/// wie er ist. Diese Datei verlangt nichts von ihm; sie verlangt, dass
/// `onUpgrade` ihn überhaupt erst erreichen lässt.
///
/// ## Die oberste Zusage: vorhandene Werte überleben
///
/// Eine Stufe, die auf eine schon vorhandene Spalte trifft, darf sie
/// **nicht leeren** und die Tabelle nicht neu bauen. Dasselbe für eine schon
/// vorhandene Tabelle: `DROP TABLE IF EXISTS` gefolgt von `CREATE TABLE`
/// wäre eine Stufe, die nie scheitert und trotzdem Tims Daten verliert —
/// schlimmer als der Absturz, den sie behebt. Die Fälle unten legen deshalb
/// in jede vorbelegte Spalte und jede vorbelegte Tabelle einen Wert und
/// prüfen ihn hinterher nach.
///
/// ## Woran „nichts angefasst" gemessen wird
///
/// Am SQLite-Schema-Zähler `PRAGMA schema_version` — dasselbe Messinstrument
/// wie in `schema_abgleich_test.dart` und aus demselben Grund: Es misst die
/// **Wirkung**, nicht die Bauform. Nachgemessen am 03.11.2026 mit
/// `sqlite3` auf dieser Maschine:
///
/// - `PRAGMA user_version = 9` erhöht ihn **nicht** (eine Stufe darf ihre
///   Nummer also festschreiben, ohne hier aufzufallen).
/// - `ALTER TABLE … ADD COLUMN` erhöht ihn um **genau 1**, auch mehrere
///   innerhalb einer Transaktion (`BEGIN; ALTER; ALTER; COMMIT;` → +2).
/// - Ein **gescheitertes** `ALTER TABLE … ADD COLUMN` (`duplicate column
///   name`) erhöht ihn **nicht**. Die Zählung unten ist damit gegen beide
///   denkbaren Bauformen fair: „vorher nachsehen" und „den Fehler fangen"
///   ergeben dieselbe Zahl.
/// - `CREATE TABLE IF NOT EXISTS` auf eine bestehende Tabelle erhöht ihn
///   **nicht**; `DROP` + `CREATE` erhöhte ihn um 2 und fiele auf.
///
/// ## Der Konflikt mit `schema_v7_test.dart` — und warum diese Datei ihn
/// ohne eine Änderung dort auflöst
///
/// Die Gruppe „Ein Gerät, das schon auf v7 steht" in `schema_v7_test.dart`
/// benutzt heute das Scheitern eines zweiten `ALTER TABLE` als Nachweis
/// dafür, dass die v7-Stufe nicht noch einmal gelaufen ist (dasselbe eine
/// Stufe weiter in `schema_v8_test.dart` und `schema_v9_test.dart`).
/// Robuste Stufen nehmen ihr dieses Messinstrument weg.
///
/// Die Datei bleibt davon trotzdem **unberührt**, und das ist eine
/// Entscheidung mit Gründen:
///
/// 1. **Sie bleibt grün.** Ihre Erwartungen sind Werte (`hrvMs`,
///    `gewichtKg`, `trainingsMinuten`), kein Ausnahme-Matcher. Was verblasst,
///    ist ihre Begründung im Kommentar, nicht ihr Prüfinhalt — und ein
///    Testinhalt, den niemand ändern muss, wird nach `CLAUDE.md` auch von
///    niemandem geändert.
/// 2. **Ihr Nachweis zieht hierher um, in schärferer Form.** Die Gruppe
///    „Eine Stufe ohne Arbeit fasst nichts an" unten stellt genau denselben
///    Stand nach (ein sauberes v8-Schema, `user_version = 8`) und misst am
///    Schema-Zähler, dass keine der Stufen bis einschließlich 8 **auch nur
///    eine** Anweisung abgesetzt hat. Das ist mehr, als das alte Instrument
///    konnte:
///    „ein zweites ALTER würfe" belegte nur, dass die Stufe nicht gescheitert
///    ist, und hätte eine Stufe, die läuft und dabei etwas anderes anfasst,
///    nie bemerkt.
/// 3. **Die Frage selbst verschiebt sich.** Mit robusten Stufen ist „ist die
///    Stufe ein zweites Mal gelaufen?" keine beantwortbare und auch keine
///    interessante Frage mehr. Interessant ist: Wirft etwas, geht etwas
///    verloren, wird vorsorglich am Schema gearbeitet? Genau diese drei
///    beantworten die Gruppen unten.
///
/// ## Was absichtlich nicht geprüft wird
///
/// - **Der zweite Weg aus #234 („je Zweig eine eigene Bundle-ID").** Das ist
///   eine Entscheidung über den Aufbau des Projekts, die Tim treffen muss,
///   und sie ließe sich in einem Dart-Test ohnehin nicht nachstellen. Diese
///   Datei legt den ersten Weg fest, weil nur er in dieser Schicht liegt.
/// - **Eine vorhandene Spalte mit falschem Typ oder falschem `NOT NULL`.**
///   Dieselbe Grenze wie in `schema_abgleich_test.dart`: SQLite verlangt
///   dafür einen Tabellenneubau mit Umkopieren, und der kann Zeilen
///   verlieren. Die oberste Zusage ist, dass Zeilen überleben.
/// - **Der Weg über `drift_dev schema dump`/`SchemaVerifier`.** Dieselbe
///   Begründung wie in `migration_test.dart`, `schema_v7_test.dart`,
///   `schema_v9_test.dart` und `schema_abgleich_test.dart`: Es gibt keine
///   eingefrorenen Schema-Dumps unter `drift_schemas/`, und eine Testdatei,
///   die der Implementierung vorausgeht, kann sie nicht anlegen. Die Dateien
///   unten sind deshalb **von Hand** gebaut.
/// - **Der Inhalt der einzelnen Stufen.** Welche Spalte zu welcher Version
///   gehört, steht in `migration_test.dart`, `schema_v3_test.dart`,
///   `migration_stufen_test.dart`, `schlaf_eintrag_test.dart`,
///   `schema_v7_test.dart`, `schema_v8_test.dart` und
///   `schema_v9_test.dart` und bleibt dort.
///
/// **Alle Zahlen hier sind erfunden** — keine echten Gesundheitswerte.
///
/// ## Nachgezogen mit der Stufe 24 (#476, #485, 11.11.2026)
///
/// Die vier Zählungen unten messen, wie viele Anweisungen am Schema
/// abgesetzt werden. Jedes `CREATE TABLE` einer neuen Stufe erhöht jede
/// davon um genau eins — mit `umfaenge` also 14→15, 20→21, 21→22 und
/// 16→17. Beim Zusammenführen von `umfaenge-88` und `main` (#485) kamen
/// die **drei** `CREATE TABLE` der Gym-Stufe 18 dazu, also je drei mehr:
/// 15→18, 21→24, 22→25 und 17→20. Die Stufen dieses Zweigs sind dabei um
/// eins nach oben gerückt (Kalorienziel 18→19, `eintraege.fluessig`
/// 19→20, Aufteilung 20→21, Ereignisse 21→22, Wachbelege 22→23, Umfänge
/// 23→24); die Gym-Stufe behält die 18, weil sie auf Tims iPhone schon
/// gelaufen ist. Mitgezogen sind die Testnamen und die `reason:`-Texte,
/// die die Stufen einzeln aufzählen: Ein Grund, der eine Stufe ausläßt,
/// zählt etwas anderes auf, als die Zahl behauptet. Nachgezogen vom
/// Test-Agenten, **Tim hat die Änderung nicht gesehen**; inhaltlich ist
/// keine Erwartung verschoben.
///
/// ## Nachgezogen mit den Stufen 26, 27 und 28 (24.11.2026)
///
/// Beim Zusammenführen der beiden `main`-Stände kamen drei Stufen
/// zusammen, die in diesen vier Läufen etwas tun:
///
/// * **26** (#596, Zykluskalender): drei `CREATE TABLE`
///   (`zyklus_eintraege`, `zyklus_health_spiegel`,
///   `zyklus_einstellungen`).
/// * **27** (#532, eigene Trainings): vier `CREATE TABLE`
///   (`gym_trainings`, `gym_training_uebungen`, `gym_training_tags`,
///   `gym_rotation`). Die Spalte `gym_sitzungen.trainings_name` kostet
///   hier nichts, weil `gym_sitzungen` in diesen Läufen erst durch die
///   Stufe 18 mit der heutigen Definition entsteht — die Spalte ist dann
///   schon da.
/// * **28** (#95, `tages_werte.vo2max`): ein `ALTER TABLE`.
///
/// Die **25** (#542, Sync-Felder) kostet in diesen vier Läufen nichts:
/// `lebensmittel` und `rezepte` entstehen dort durch die Stufe 12 aus der
/// heutigen Definition, also samt der Spalten.
///
/// Macht je **acht** mehr als vor dem Zusammenführen: 18→26, 24→32,
/// 25→33 und 20→28. Nur Zahlen, Testnamen und `reason:`-Texte sind
/// mitgezogen; inhaltlich ist keine Erwartung verschoben. Nachgezogen vom
/// Test-Agenten, **Tim hat die Änderung nicht gesehen**.
void main() {
  // ---------------------------------------------------------------------
  // Bausteine der von Hand gebauten Dateien.
  //
  // `gelesen_am`, `beginn` und `ende` liegen als ISO-Text mit `Z` vor, weil
  // `AppCache` mit `storeDateTimeAsText: true` arbeitet (`cache.dart`) —
  // drifts Standard (Unix-Sekunden) gäbe sie als Ortszeit zurück, und ein
  // als UTC abgelegter Wert wäre dann ungleich sich selbst.
  // ---------------------------------------------------------------------

  /// `tages_werte` mit allen elf Spalten, wie Schema v9 sie vorsieht.
  const tagesWerteV9 = '''
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
  ''';

  /// Der Stand von Schema v7 und v8: die beiden v9-Spalten fehlen.
  /// (`tages_werte` selbst ändert sich zwischen v7 und v8 nicht — die
  /// Stufe 8 arbeitet an `naechte`.)
  const tagesWerteV7 = '''
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

  /// Der Stand von Schema v3 bis v6 — vor den beiden v7-Spalten.
  const tagesWerteV6 = '''
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

  /// Eine **halb gelaufene** v7-Stufe: `gewicht_kg` ist schon da,
  /// `trainings_minuten` nicht. So sieht es aus, wenn ein fremder Zweig nur
  /// die erste der beiden Spalten kannte — oder wenn eine frühere Migration
  /// mitten in der Stufe abbrach.
  const tagesWerteV6PlusGewicht = '''
    CREATE TABLE tages_werte (
      tag TEXT NOT NULL PRIMARY KEY,
      schritte INTEGER,
      ruhepuls_bpm INTEGER,
      gelesen_am TEXT,
      hrv_ms REAL,
      resp_rate REAL,
      recovery_hr_drop INTEGER,
      gewicht_kg REAL
    );
  ''';

  /// Schema v1 mit **einer** Spalte aus der Zukunft: `gelesen_am` (Stufe 2)
  /// ist schon da, alles danach nicht. Ein Zweig, der von ganz unten aus
  /// genau einen Schritt gegangen ist.
  const tagesWerteV1PlusGelesenAm = '''
    CREATE TABLE tages_werte (
      tag TEXT NOT NULL PRIMARY KEY,
      schritte INTEGER,
      ruhepuls_bpm INTEGER,
      gelesen_am TEXT
    );
  ''';

  /// Reines Schema v1.
  const tagesWerteV1 = '''
    CREATE TABLE tages_werte (
      tag TEXT NOT NULL PRIMARY KEY,
      schritte INTEGER,
      ruhepuls_bpm INTEGER
    );
  ''';

  /// Die beiden Tabellen, die es seit v1 gibt.
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

  /// `naechte` nach der Stufe 8 (#193): dazu die drei Werte **einer
  /// Nacht**, gerechnet über das Schlaffenster statt über den Kalendertag.
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

  const tabelleTagesgefuehle = '''
    CREATE TABLE tagesgefuehle (
      tag TEXT NOT NULL PRIMARY KEY,
      wert INTEGER NOT NULL
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

  /// Alle Tabellen außer `tages_werte` — der Stand von v5: noch ohne
  /// `schlaf_eintraege` (Stufe 6) und mit dem schmalen `naechte` (vor
  /// Stufe 8).
  const uebrigeTabellenV5 =
      '$tabellenV1$tabelleNaechteV7$tabelleSchlafAbschnitte'
      '$tabelleZielWerte$tabelleTagesgefuehle';

  /// Der Stand von v6 und v7: `schlaf_eintraege` ist dazugekommen,
  /// `naechte` noch schmal.
  const uebrigeTabellenV7 = '$uebrigeTabellenV5$tabelleSchlafEintraege';

  /// Der Stand von v8: dazu die drei Spalten auf `naechte`.
  const uebrigeTabellenV8 =
      '$tabellenV1$tabelleNaechteV8$tabelleSchlafAbschnitte'
      '$tabelleZielWerte$tabelleTagesgefuehle$tabelleSchlafEintraege';

  // --- die vollständigen Dateien --------------------------------------

  /// **Die Datei aus #234**: Spalten und Tabellen auf dem Stand von v9, die
  /// Nummer aber auf 8. `if (from < 9)` läuft und trifft auf
  /// `koerperfett_pct`.
  const schemaNummerZuNiedrig = '$tagesWerteV9$uebrigeTabellenV8';

  /// Nummer 6, `gewicht_kg` schon da — die halb gelaufene v7-Stufe.
  const schemaHalbeStufeSieben = '$tagesWerteV6PlusGewicht$uebrigeTabellenV7';

  /// Nummer 5, `schlaf_eintraege` schon da — die Stufe 6 trifft auf ihre
  /// eigene Tabelle.
  ///
  /// Bis zum 03.11.2026 stand dieser Fall auf `tagesgefuehle` und der
  /// Stufe 5. Die Tabelle gibt es seit #269 nicht mehr; der Fall ist
  /// derselbe, nur eine Stufe weiter — und `schlaf_eintraege` trägt
  /// dieselbe Art Daten: Tims eigene, ohne zweite Kopie.
  const schemaTabelleSchonDa = '$tagesWerteV6$uebrigeTabellenV7';

  /// Nummer 1, aber `gelesen_am` und `naechte` sind schon da — ein Zweig,
  /// der von ganz unten aus Teile der Stufen 2 und 3 vorweggenommen hat.
  const schemaGemischtVonUnten =
      '$tagesWerteV1PlusGelesenAm$tabellenV1$tabelleNaechteV7';

  /// Nummer 8, Spalten und Tabellen auf dem Stand von v8 — der Fall, an
  /// dem sich heute `schema_v9_test.dart` festhält (siehe Dateikopf).
  const schemaSauberV8 = '$tagesWerteV7$uebrigeTabellenV8';

  /// Sauberes v5 und sauberes v1 — die Fälle, in denen die Stufen laufen
  /// müssen wie eh und je.
  const schemaSauberV5 = '$tagesWerteV6$uebrigeTabellenV5';
  const schemaSauberV1 = '$tagesWerteV1$tabellenV1';

  // --- Bestand ---------------------------------------------------------

  /// Eine Nacht mit einem Abschnitt und Tims eingestellte Ziele.
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

  /// Ein Tag mit allen neun Werten, die Schema v9 kennt — **einschließlich**
  /// der beiden, um die es geht. Sie stehen hier, damit nachprüfbar ist,
  /// dass die Stufe sie nicht leert.
  const zeileNeunWerte = '''
    INSERT INTO tages_werte
      (tag, schritte, ruhepuls_bpm, gelesen_am, hrv_ms, resp_rate,
       recovery_hr_drop, gewicht_kg, trainings_minuten, koerperfett_pct,
       fettfrei_kg)
      VALUES ('2026-10-20', 8042, 51, '2026-10-20T09:00:00.000Z',
              38.4, 15.1, 27, 81.4, 47.5, 21.3, 64.1);
  ''';

  /// Ein Tag mit den sieben Werten eines v7-/v8-Stands.
  const zeileSiebenWerte = '''
    INSERT INTO tages_werte
      (tag, schritte, ruhepuls_bpm, gelesen_am, hrv_ms, resp_rate,
       recovery_hr_drop, gewicht_kg, trainings_minuten)
      VALUES ('2026-10-20', 8042, 51, '2026-10-20T09:00:00.000Z',
              38.4, 15.1, 27, 81.4, 47.5);
  ''';

  /// Ein Tag mit den fünf Werten eines v6-Stands **plus** einem Gewicht in
  /// der vorweggenommenen Spalte.
  const zeileSechsWerteMitGewicht = '''
    INSERT INTO tages_werte
      (tag, schritte, ruhepuls_bpm, gelesen_am, hrv_ms, resp_rate,
       recovery_hr_drop, gewicht_kg)
      VALUES ('2026-10-20', 8042, 51, '2026-10-20T09:00:00.000Z',
              38.4, 15.1, 27, 81.4);
  ''';

  /// Ein Tag mit den fünf Werten eines v6-Stands.
  const zeileFuenfWerte = '''
    INSERT INTO tages_werte
      (tag, schritte, ruhepuls_bpm, gelesen_am, hrv_ms, resp_rate,
       recovery_hr_drop)
      VALUES ('2026-10-20', 8042, 51, '2026-10-20T09:00:00.000Z',
              38.4, 15.1, 27);
  ''';

  /// Eine v1-Zeile, die in der vorweggenommenen Spalte `gelesen_am` schon
  /// einen Stand trägt.
  const zeileV1MitStand = '''
    INSERT INTO tages_werte (tag, schritte, ruhepuls_bpm, gelesen_am)
      VALUES ('2026-10-20', 8042, 51, '2026-10-20T09:00:00.000Z');
    INSERT INTO naechte (tag, gelesen_am)
      VALUES ('2026-10-20', '2026-10-20T09:00:00.000Z');
  ''';

  const zeileV1 = '''
    INSERT INTO tages_werte (tag, schritte, ruhepuls_bpm)
      VALUES ('2026-10-20', 8042, 51);
  ''';

  const bestandNummerZuNiedrig =
      '$zeileNeunWerte$bestandRest$bestandTagesgefuehl';
  const bestandHalbeStufeSieben =
      '$zeileSechsWerteMitGewicht$bestandRest$bestandTagesgefuehl';
  const bestandSauberV8 = '$zeileSiebenWerte$bestandRest$bestandTagesgefuehl';
  const bestandSauberV5 = '$zeileFuenfWerte$bestandRest$bestandTagesgefuehl';

  const bestandSchlafEintrag = '''
    INSERT INTO schlaf_eintraege
      (tag, art, lfd_nr, schlaf_minuten, beginn_minuten, ende_minuten, notiz)
      VALUES ('2026-10-20', 'nacht', 0, 415, 1385, 380, 'Uhr vergessen');
  ''';

  /// Für die Datei auf Nummer 5: Die `schlaf_eintraege`-Tabelle existiert
  /// schon und **hat eine Zeile**. Genau sie muss die Stufe 6 überleben.
  const bestandTabelleSchonDa =
      '$zeileFuenfWerte$bestandRest$bestandTagesgefuehl$bestandSchlafEintrag';

  // ---------------------------------------------------------------------
  // Hilfsmittel — wortgleich zu `schema_abgleich_test.dart`.
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

  /// Die Version, die in der Datei selbst steht — nicht die, die
  /// `AppCache.schemaVersion` behauptet. Nur sie belegt, dass die Migration
  /// tatsächlich durchgelaufen ist und ihr Ergebnis festgeschrieben hat.
  Future<int> abgelegteVersion(AppCache db) async {
    final zeile = await db.customSelect('PRAGMA user_version;').getSingle();
    return zeile.read<int>('user_version');
  }

  /// Der SQLite-Schema-Zähler. Steigt bei jedem erfolgreichen `CREATE`,
  /// `ALTER` und `DROP`, bei nichts sonst — siehe Dateikopf.
  Future<int> schemaStempel(AppCache db) async {
    final zeile = await db.customSelect('PRAGMA schema_version;').getSingle();
    return zeile.read<int>('schema_version');
  }

  /// Die Spalten einer Tabelle, so wie sie **tatsächlich** in der Datei
  /// stehen — nicht, was der Dart-Code über sie behauptet.
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

  /// Alle zwölf Spalten, die `tages_werte` nach dem Öffnen heute hat: die
  /// elf von Schema v9, seit der Stufe 26 (#95) dazu `vo2max` — verlangt
  /// in `schema_v26_test.dart`. Die Altstände oben bleiben unverändert;
  /// die Spalte kommt über Stufe und Abgleich. Nachgezogen vom
  /// Test-Agenten; **Tim hat die Änderung nicht gesehen.**
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

  group('Nummer zu niedrig, Spalten schon da — die Datei aus #234', () {
    QueryExecutor kaputt({void Function(int)? stempel}) => datei(
      schemaNummerZuNiedrig,
      bestandNummerZuNiedrig,
      8,
      stempel: stempel,
    );

    test('die Datenbank lässt sich überhaupt öffnen', () async {
      final db = AppCache(kaputt());
      addTearDown(db.close);

      // Das Öffnen selbst ist bei drift lazy — die Migration läuft erst
      // beim ersten Zugriff. Heute wirft genau dieser Zugriff
      // `SqliteException(1): duplicate column name: koerperfett_pct`, und
      // danach ist die Datenbank für die App unbenutzbar: kein Lesen, kein
      // Schreiben, kein Cache. Das ist schlimmer als #233, wo der
      // zwischengespeicherte Stand wenigstens lesbar stehen blieb.
      await db.select(db.tagesWerte).get();

      expect(await spalten(db, 'tages_werte'), alleTagesWerteSpalten);
      expect(await tabellen(db), tabellenHeute);
    });

    test('und steht danach auf der heutigen Version', () async {
      final db = AppCache(kaputt());
      addTearDown(db.close);

      await db.select(db.tagesWerte).get();

      expect(
        await abgelegteVersion(db),
        db.schemaVersion,
        reason:
            'die Stufe hatte nichts zu tun, aber sie ist gelaufen und muss '
            'ihr Ergebnis festschreiben. Bliebe die Nummer auf 8, liefe '
            'dieselbe Stufe bei jedem Start wieder — die Datei bliebe '
            'dauerhaft in dem Zustand, der sie heute abstürzen lässt',
      );
    });

    test('ein Schreibvorgang gelingt danach', () async {
      final db = AppCache(kaputt());
      addTearDown(db.close);
      final repo = CacheRepository(db);

      await repo.schreibeTagesWerte(const [
        DailyMetrics(
          tag: '2026-10-21',
          steps: 9100,
          weightKg: 81.0,
          bodyFatPct: 21.1,
          leanKg: 64.3,
        ),
      ], gelesenAm: DateTime.utc(2026, 11, 3, 8));

      final neu = (await repo.liesTagesWerte(DataWindow.unlimited))!.werte
          .firstWhere((w) => w.tag == '2026-10-21');

      expect(
        neu.bodyFatPct,
        21.1,
        reason:
            'die Spalten waren die ganze Zeit da — nur die Nummer stand '
            'davor. Nach der Reparatur muss der ganz gewöhnliche Schreibweg '
            'durchgehen',
      );
      expect(neu.leanKg, 64.3);
      expect(neu.weightKg, 81.0);
    });

    test('die schon vorhandenen v9-Werte überleben — die Spalte wird nicht '
        'geleert', () async {
      final db = AppCache(kaputt());
      addTearDown(db.close);

      final zeile = (await db.select(db.tagesWerte).get()).single;

      expect(
        zeile.koerperfettPct,
        21.3,
        reason:
            'in dieser Spalte stand ein Wert, bevor die Stufe lief. Eine '
            'Stufe, die sie verwirft und neu anlegt, stürzt zwar nicht '
            'mehr ab, verliert aber Tims Daten — und das wäre schlimmer '
            'als der Absturz, den sie behebt',
      );
      expect(zeile.fettfreiKg, 64.1);
      expect(zeile.gewichtKg, 81.4);
      expect(zeile.trainingsMinuten, 47.5);
      expect(zeile.schritte, 8042);
      expect(zeile.ruhepulsBpm, 51);
      expect(zeile.hrvMs, 38.4);
      expect(zeile.respRate, 15.1);
      expect(zeile.recoveryHrDrop, 27);
      expect(
        zeile.gelesenAm,
        DateTime.utc(2026, 10, 20, 9),
        reason:
            'der Stand überlebt — er wird nicht auf "jetzt" gesetzt. Ein '
            'erfundener Zeitstempel behauptete, die Zeile sei frisch',
      );
    });

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

    test('und am Schema werden dabei genau sechsundzwanzig Anweisungen '
        'abgesetzt — die Stufe 9 hatte nichts zu tun, die Stufe 10 eine '
        'Tabelle zu löschen, die Stufe 11 eine anzulegen, die Stufe 12 '
        'fünf, die Stufe 15 zwei, die Stufe 16 eine, die Stufe 18 drei, '
        'die Stufe 19 eine, die Stufe 21 eine, die Stufe 22 eine, die '
        'Stufe 23 eine, die Stufe 24 eine, die Stufe 26 drei, die '
        'Stufe 27 vier und die Stufe 28 eine Spalte',
        () async {
      var vorher = -1;
      final db = AppCache(kaputt(stempel: (wert) => vorher = wert));
      addTearDown(db.close);

      await db.select(db.tagesWerte).get();

      expect(
        await schemaStempel(db) - vorher,
        26,
        reason:
            'PRAGMA schema_version steigt bei jedem erfolgreichen CREATE, '
            'ALTER und DROP und bei nichts sonst; das Festschreiben der '
            'Nummer (PRAGMA user_version) erhöht ihn nicht. An Spalten '
            'fehlte in dieser Datei nichts — die sechsundzwanzig '
            'Anweisungen sind das DROP der Stufe 10 (#269), das CREATE '
            'TABLE `stammdaten` der Stufe 11, die fünf CREATE TABLE der '
            'Stufe 12 (Task 3 des Ernährungsplans) und die beiden CREATE '
            'TABLE der KI-Tabellen in Stufe 15 (#332) und das CREATE TABLE '
            '`wasser_eintraege` der Stufe 16 (#311) und die drei CREATE '
            'TABLE der Stufe 18 (#78 mit #40) und das CREATE TABLE '
            '`kalorienziele` der Stufe 19 (#410) und das CREATE TABLE '
            '`mahlzeit_aufteilungen` der Stufe 21 (#430) und das CREATE '
            'TABLE `ereignisse` der Stufe 22 (#444) und das CREATE TABLE '
            '`wach_belege` der Stufe 23 (#451) und das CREATE TABLE '
            '`umfaenge` der Stufe 24 (#476; am 11.11.2026 beim '
            'Zusammenführen von `umfaenge-88` und `main` von fünfzehn auf '
            'achtzehn gezogen, #485), die drei CREATE TABLE der '
            'Zyklus-Stufe 26 (#596), die vier CREATE TABLE der Stufe 27 '
            '(#532) und das eine ALTER TABLE `vo2max` der Stufe 28 (#95; '
            'zusammen seit dem 24.11.2026 sechsundzwanzig statt achtzehn, '
            'nachgezogen vom Test-Agenten, **Tim hat die Änderung nicht '
            'gesehen**). '
            'Die Stufe 25 (#542, Sync-Felder) kostet nichts: Stufe 12 '
            'legt `lebensmittel` und `rezepte` schon aus der heutigen '
            'Definition an. `gym_sitzungen.trainings_name` (Stufe 27) '
            'kostet aus demselben Grund nichts — Stufe 18 legt '
            '`gym_sitzungen` schon heutig an —, und '
            '`eintraege.vorschlag` und `eintraege.fluessig` (Stufe 20) '
            'ebenso. Siebenundzwanzig hieße, dass die Stufe 9 doch '
            'etwas angefasst hat; weniger hieße, dass eine von ihnen '
            'ausgeblieben ist',
      );
    });
  });

  group('Eine halb gelaufene Stufe wird zu Ende gebracht', () {
    // Nummer 6, `gewicht_kg` ist da, `trainings_minuten` nicht. Eine Stufe,
    // die einfach den ganzen Block überspringt, sobald die erste Spalte
    // schon existiert — oder die den Fehler fängt und danach abbricht —,
    // ließe `trainings_minuten` für immer fehlen.
    QueryExecutor halb({void Function(int)? stempel}) => datei(
      schemaHalbeStufeSieben,
      bestandHalbeStufeSieben,
      6,
      stempel: stempel,
    );

    test('die fehlende zweite Spalte der Stufe kommt trotzdem', () async {
      final db = AppCache(halb());
      addTearDown(db.close);

      expect(
        await spalten(db, 'tages_werte'),
        alleTagesWerteSpalten,
        reason:
            'die v7-Stufe legt zwei Spalten an. Dass die erste schon da '
            'ist, sagt nichts über die zweite — Robustheit gilt je Spalte, '
            'nicht je Stufe',
      );
      expect(await abgelegteVersion(db), db.schemaVersion);
    });

    test('das vorweggenommene Gewicht bleibt stehen, die nachgezogene '
        'Spalte ist leer', () async {
      final db = AppCache(halb());
      addTearDown(db.close);

      final zeile = (await db.select(db.tagesWerte).get()).single;

      expect(
        zeile.gewichtKg,
        81.4,
        reason:
            'der Wert stand schon in der Datei, bevor die Stufe lief, und '
            'die Stufe fasst ihn nicht an',
      );
      expect(zeile.trainingsMinuten, isNull);
      expect(
        await speichertyp(db, 'trainings_minuten', '2026-10-20'),
        'null',
        reason:
            'für diese Zeile wurden nie Trainingsminuten geholt. "0 Minuten" '
            'behauptete, Tim habe nichts getan — Fehler 01 in neuer '
            'Verpackung (CLAUDE.md)',
      );
      expect(await speichertyp(db, 'koerperfett_pct', '2026-10-20'), 'null');
      expect(await speichertyp(db, 'fettfrei_kg', '2026-10-20'), 'null');
      expect(zeile.hrvMs, 38.4);
      expect(zeile.gelesenAm, DateTime.utc(2026, 10, 20, 9));
    });

    test('und es werden genau die sieben fehlenden Spalten angelegt, keine '
        'achte — dazu das eine DROP der Stufe 10, das eine CREATE der '
        'Stufe 11, die fünf der Stufe 12, die zwei der Stufe 15, das '
        'eine der Stufe 16, die drei der Stufe 18, das eine der Stufe 19, '
        'das eine der Stufe 21, das eine der Stufe 22, das eine der '
        'Stufe 23, das eine der Stufe 24, die drei der Stufe 26, die '
        'vier der Stufe 27 und die Spalte der Stufe 28',
        () async {
      var vorher = -1;
      final db = AppCache(halb(stempel: (wert) => vorher = wert));
      addTearDown(db.close);

      await db.select(db.tagesWerte).get();

      expect(
        await schemaStempel(db) - vorher,
        32,
        reason:
            'sieben Spalten fehlten: trainings_minuten aus der halb '
            'gelaufenen Stufe 7, die drei Nachtwerte der Stufe 8 '
            '(ruhepuls_bpm, hrv_ms, resp_rate auf naechte), '
            'koerperfett_pct/fettfrei_kg aus der Stufe 9 und vo2max aus '
            'der Stufe 26 (#95). Jedes '
            'erfolgreiche ALTER TABLE … ADD COLUMN erhöht den Zähler um '
            'genau 1. Ein gescheitertes erhöht ihn nicht — die Zahl ist '
            'deshalb dieselbe, ob die Stufe vorher nachsieht oder den '
            'Fehler fängt. Dazu kommen das eine DROP der Stufe 10 (#269), '
            'das eine CREATE TABLE `stammdaten` der Stufe 11, die fünf '
            'CREATE TABLE der Stufe 12 (Task 3 des Ernährungsplans) und die '
            'beiden CREATE TABLE der KI-Tabellen in Stufe 15 (#332) und das '
            'CREATE TABLE `wasser_eintraege` der Stufe 16 (#311) und die '
            'drei CREATE TABLE der Stufe 18 (#78 mit #40) und das CREATE '
            'TABLE `kalorienziele` der Stufe 19 (#410) und das CREATE '
            'TABLE `mahlzeit_aufteilungen` der Stufe 21 (#430) und das '
            'CREATE TABLE `ereignisse` der Stufe 22 (#444) und das CREATE '
            'TABLE `wach_belege` der Stufe 23 (#451) und das CREATE TABLE '
            '`umfaenge` der Stufe 24 (#476; am 11.11.2026 von '
            'einundzwanzig auf vierundzwanzig gezogen beim Zusammenführen '
            'von `umfaenge-88` und `main`, #485), die drei CREATE TABLE '
            'der Zyklus-Stufe 26 (#596), die vier CREATE TABLE der '
            'Stufe 27 (#532) und die Spalte vo2max der Stufe 28 (#95; '
            'zusammen seit dem 24.11.2026 zweiunddreißig statt '
            'vierundzwanzig — nachgezogen vom Test-Agenten, **Tim hat die '
            'Änderung nicht gesehen**). '
            'Dreiunddreißig hieße, dass auch gewicht_kg angefasst wurde; '
            'mehr hieße, dass vorsorglich am Schema gearbeitet wird',
      );
    });
  });

  group('Eine Stufe, deren Tabelle schon existiert', () {
    // Nummer 5, aber `schlaf_eintraege` ist schon da und hat eine Zeile.
    // Die Stufe 6 ruft `createTable(schlafEintraege)`.
    //
    // **Diese vier Fälle sind von Anfang an grün** (gemessen am 03.11.2026),
    // und das ist kein Verstoß gegen „erst der rote Test": drifts
    // `Migrator.createTable` setzt `CREATE TABLE IF NOT EXISTS` ab, die
    // Tabellenrichtung ist also heute schon robust. Sie gehören trotzdem
    // hierher, als Wächter (`CLAUDE.md`, „Ein Wächtertest ist von Anfang an
    // grün"): Wer die Stufen umbaut, um die Spaltenrichtung zu heilen,
    // fasst genau diese Methodenaufrufe an — und ein `DROP TABLE IF EXISTS`
    // davor wäre eine Stufe, die nie scheitert und trotzdem Tims von Hand
    // eingetragene Nächte löscht. Ohne diese vier fiele das niemandem auf.
    //
    // **Die löschende Stufe 10 (#269) ist davon ausdrücklich nicht
    // gemeint.** Dort ist das Wegnehmen die Anforderung, hier wäre es ein
    // Unfall; den Unterschied macht, dass Tim das eine entschieden hat und
    // das andere nicht.
    QueryExecutor tabelleDa({void Function(int)? stempel}) =>
        datei(schemaTabelleSchonDa, bestandTabelleSchonDa, 5, stempel: stempel);

    test('die Datenbank lässt sich öffnen und steht danach oben', () async {
      final db = AppCache(tabelleDa());
      addTearDown(db.close);

      await db.select(db.tagesWerte).get();

      expect(await tabellen(db), tabellenHeute);
      expect(await spalten(db, 'tages_werte'), alleTagesWerteSpalten);
      expect(await spalten(db, 'naechte'), alleNaechteSpalten);
      expect(
        await abgelegteVersion(db),
        db.schemaVersion,
        reason:
            'eine Stufe, die `createTable` ruft, trifft denselben '
            'Zweigwechsel wie eine, die `addColumn` ruft — nur mit einer '
            'ganzen Tabelle statt einer Spalte',
      );
    });

    test('und die Zeile in der vorhandenen Tabelle überlebt', () async {
      final db = AppCache(tabelleDa());
      addTearDown(db.close);

      expect(
        (await db.select(db.schlafEintraege).get()).single.notiz,
        'Uhr vergessen',
        reason:
            'Tim hat diese Nacht von Hand eingetragen, und hinter ihr steht '
            'kein Lauf aus Apple Health — sie ist die einzige Kopie. Eine '
            'Stufe, die ihre Tabelle vorsorglich verwirft und neu anlegt, '
            'scheitert nie und löscht trotzdem; das ist der stillere und '
            'der schlimmere Fehler',
      );

      // Und benutzbar ist die Tabelle auch: ein zweiter Eintrag geht durch.
      await db
          .into(db.schlafEintraege)
          .insert(
            SchlafEintraegeCompanion.insert(
              tag: '2026-10-21',
              art: 'tagschlaf',
              lfdNr: 0,
              schlafMinuten: 30,
            ),
          );
      expect((await db.select(db.schlafEintraege).get()).length, 2);
    });

    test('der übrige Bestand bleibt ebenfalls stehen', () async {
      final db = AppCache(tabelleDa());
      addTearDown(db.close);

      final zeile = (await db.select(db.tagesWerte).get()).single;
      expect(zeile.schritte, 8042);
      expect(zeile.hrvMs, 38.4);
      expect(zeile.gelesenAm, DateTime.utc(2026, 10, 20, 9));
      expect(
        (await db.select(db.zielWerte).get()).single.schlafzielMinuten,
        450,
      );
      expect((await db.select(db.naechte).get()).single.tag, '2026-10-20');
    });

    test('und die vorhandene Tabelle wird nicht neu gebaut — nur das '
        'wirklich Fehlende kommt dazu', () async {
      var vorher = -1;
      final db = AppCache(tabelleDa(stempel: (wert) => vorher = wert));
      addTearDown(db.close);

      await db.select(db.tagesWerte).get();

      expect(
        await schemaStempel(db) - vorher,
        33,
        reason:
            'acht Spalten fehlten — die beiden der Stufe 7, die drei der '
            'Stufe 8, die beiden der Stufe 9 und vo2max der Stufe 26 '
            '(#95) —, dazu das eine DROP der '
            'Stufe 10, das eine CREATE TABLE `stammdaten` der Stufe 11 und '
            'die fünf CREATE TABLE der Stufe 12 (Task 3 des '
            'Ernährungsplans) und die beiden CREATE TABLE der KI-Tabellen '
            'in Stufe 15 (#332), das CREATE TABLE `wasser_eintraege` der '
            'Stufe 16 (#311), die drei CREATE TABLE der Stufe 18 (#78 mit '
            '#40), das CREATE TABLE `kalorienziele` der Stufe 19 (#410), '
            'das CREATE TABLE `mahlzeit_aufteilungen` der Stufe 21 (#430), '
            'das CREATE TABLE `ereignisse` der Stufe 22 (#444), das CREATE '
            'TABLE `wach_belege` der Stufe 23 (#451) und das CREATE TABLE '
            '`umfaenge` der Stufe 24 (#476), die drei CREATE TABLE der '
            'Zyklus-Stufe 26 (#596), die vier CREATE TABLE der Stufe 27 '
            '(#532) und die Spalte der Stufe 28 (#95). Macht '
            'dreiunddreißig Anweisungen, sonst nichts (am 11.11.2026 auf '
            'fünfundzwanzig gezogen beim Zusammenführen von '
            '`umfaenge-88` und `main`, #485; seit dem 24.11.2026 '
            'dreiunddreißig mit den Stufen 26, 27 und 28, nachgezogen vom '
            'Test-Agenten, **Tim hat die Änderung nicht gesehen**). '
            'CREATE TABLE '
            'IF NOT EXISTS auf die schon vorhandene schlaf_eintraege erhöht '
            'den Zähler nicht, DROP plus CREATE erhöhte ihn um 2 — eine 35 '
            'wäre also genau der Neubau, der Tims eingetragene Nacht '
            'verlöre',
      );
    });
  });

  group('Gemischter Rückstand von ganz unten', () {
    // Nummer 1, aber `gelesen_am` (Stufe 2) und `naechte` (Stufe 3) sind
    // schon da. Der Durchlauf muss durch alle acht Stufen gehen und dabei
    // in zwei von ihnen etwas überspringen.
    QueryExecutor gemischt() =>
        datei(schemaGemischtVonUnten, zeileV1MitStand, 1);

    test('alle Stufen laufen durch, obwohl zwei von ihnen etwas '
        'vorfinden', () async {
      final db = AppCache(gemischt());
      addTearDown(db.close);

      expect(await spalten(db, 'tages_werte'), alleTagesWerteSpalten);
      expect(
        await tabellen(db),
        tabellenHeute,
        reason:
            'die Stufe 3 legt zwei Tabellen an. `naechte` war schon da, '
            '`schlaf_abschnitte` nicht — wie bei den Spalten gilt auch hier '
            'je Tabelle, nicht je Stufe',
      );
      expect(
        await spalten(db, 'naechte'),
        alleNaechteSpalten,
        reason:
            'die vorweggenommene `naechte` kam aus der Stufe 3 und hatte '
            'nur zwei Spalten. Die Stufe 8 muss ihre drei trotzdem '
            'nachziehen — eine übersprungene Tabelle darf keine '
            'übersprungene Spalte nach sich ziehen',
      );
      expect(await abgelegteVersion(db), db.schemaVersion);
    });

    test(
      'der vorweggenommene Stand und die vorweggenommene Nacht überleben',
      () async {
        final db = AppCache(gemischt());
        addTearDown(db.close);

        final zeile = (await db.select(db.tagesWerte).get()).single;
        expect(zeile.schritte, 8042);
        expect(zeile.ruhepulsBpm, 51);
        expect(
          zeile.gelesenAm,
          DateTime.utc(2026, 10, 20, 9),
          reason:
              'die Spalte war schon da und hatte einen Wert. Die Stufe 2 '
              'darf sie weder neu anlegen noch leeren',
        );

        expect(
          (await db.select(db.naechte).get()).single.gelesenAm,
          DateTime.utc(2026, 10, 20, 9),
          reason:
              'dasselbe eine Tabelle weiter: `naechte` stand schon da, mit '
              'einer Zeile darin',
        );
      },
    );

    test('und alles, was wirklich fehlte, ist danach leer da', () async {
      final db = AppCache(gemischt());
      addTearDown(db.close);

      final zeile = (await db.select(db.tagesWerte).get()).single;
      expect(zeile.hrvMs, isNull);
      expect(zeile.respRate, isNull);
      expect(zeile.recoveryHrDrop, isNull);
      expect(zeile.gewichtKg, isNull);
      expect(zeile.trainingsMinuten, isNull);
      expect(zeile.koerperfettPct, isNull);
      expect(zeile.fettfreiKg, isNull);
      expect(await speichertyp(db, 'hrv_ms', '2026-10-20'), 'null');
      expect(await speichertyp(db, 'koerperfett_pct', '2026-10-20'), 'null');

      expect(await db.select(db.schlafAbschnitte).get(), isEmpty);
      expect(await db.select(db.zielWerte).get(), isEmpty);
      expect(await db.select(db.schlafEintraege).get(), isEmpty);
    });
  });

  group('Eine Stufe ohne Arbeit fasst nichts an', () {
    // Der Nachweis, den `schema_v9_test.dart` („Ein Gerät, das schon auf v9
    // steht") heute am Scheitern eines zweiten ALTER TABLE festmacht —
    // hier am Schema-Zähler, und damit schärfer: Er belegt nicht nur, dass
    // die Stufe nicht gescheitert ist, sondern dass sie nichts getan hat.
    // Siehe Dateikopf.
    //
    // **Auch diese beiden sind von Anfang an grün**, und zwar
    // notwendigerweise: Sie halten fest, was sich beim Reparieren der
    // Stufen **nicht** ändern darf. Das ist ihr ganzer Zweck — ein
    // Messinstrument, das erst nach der Reparatur entstünde, bewiese über
    // den Zustand davor nichts.
    test('keine der Stufen bis 8 setzt auf einer v8-Datei eine Anweisung ab '
        '— nur die Stufen 9, 10, 11, 12, 15, 16, 18, 19, 21, 22, 23, 24, '
        '26, 27 und 28 arbeiten',
        () async {
      var vorher = -1;
      final db = AppCache(
        datei(
          schemaSauberV8,
          bestandSauberV8,
          8,
          stempel: (wert) => vorher = wert,
        ),
      );
      addTearDown(db.close);

      await db.select(db.tagesWerte).get();

      expect(
        await schemaStempel(db) - vorher,
        28,
        reason:
            'genau die beiden Spalten der Stufe 9 fehlten (und die der '
            'Stufe 26), dazu kommen das '
            'eine DROP der Stufe 10 (#269), das eine CREATE TABLE '
            '`stammdaten` der Stufe 11, die fünf CREATE TABLE der '
            'Stufe 12 (Task 3 des Ernährungsplans) und die beiden CREATE '
            'TABLE der KI-Tabellen in Stufe 15 (#332), das CREATE TABLE '
            '`wasser_eintraege` der Stufe 16 (#311), die drei CREATE TABLE '
            'der Stufe 18 (#78 mit #40), das CREATE TABLE `kalorienziele` '
            'der Stufe 19 (#410), das CREATE TABLE '
            '`mahlzeit_aufteilungen` der Stufe 21 (#430), das CREATE TABLE '
            '`ereignisse` der Stufe 22 (#444), das CREATE TABLE '
            '`wach_belege` der Stufe 23 (#451), das CREATE TABLE '
            '`umfaenge` der Stufe 24 (#476), die drei CREATE TABLE der '
            'Zyklus-Stufe 26 (#596), die vier CREATE TABLE der Stufe 27 '
            '(#532) und das eine ALTER TABLE `vo2max` der Stufe 28 (#95; '
            'am 11.11.2026 von siebzehn auf zwanzig gezogen beim '
            'Zusammenführen von `umfaenge-88` und `main`, #485; seit dem '
            '24.11.2026 achtundzwanzig mit den Stufen 26, 27 und 28; '
            '**Tim hat die Änderung nicht gesehen**). Wäre die '
            'Zahl größer, hätte eine frühere Stufe ihre Arbeit noch einmal '
            'getan oder es würde vorsorglich am Schema gearbeitet. Das '
            'alte Instrument in `schema_v9_test.dart` — "ein zweites ALTER '
            'TABLE schlüge fehl" — konnte den ersten Fall gar nicht von '
            'einer übersprungenen Stufe unterscheiden',
      );

      final zeile = (await db.select(db.tagesWerte).get()).single;
      expect(zeile.gewichtKg, 81.4);
      expect(zeile.trainingsMinuten, 47.5);
      expect(zeile.hrvMs, 38.4);
    });

    test('eine frisch angelegte Datei bleibt unberührt — onCreate hat schon '
        'alles gebaut', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      await db.select(db.tagesWerte).get();
      final nachDemAnlegen = await schemaStempel(db);

      await db.select(db.naechte).get();

      expect(await schemaStempel(db), nachDemAnlegen);
      expect(await spalten(db, 'tages_werte'), alleTagesWerteSpalten);
      expect(await spalten(db, 'naechte'), alleNaechteSpalten);
      expect(await tabellen(db), tabellenHeute);
      expect(await abgelegteVersion(db), db.schemaVersion);
    });
  });

  group('Die Stufen laufen weiterhin, wo sie sollen', () {
    test('v8 → heute: die beiden Spalten kommen, der Bestand bleibt',
        () async {
      final db = AppCache(datei(schemaSauberV8, bestandSauberV8, 8));
      addTearDown(db.close);

      expect(await spalten(db, 'tages_werte'), alleTagesWerteSpalten);
      expect(await abgelegteVersion(db), db.schemaVersion);

      final zeile = (await db.select(db.tagesWerte).get()).single;
      expect(zeile.gewichtKg, 81.4);
      expect(zeile.trainingsMinuten, 47.5);
      expect(zeile.gelesenAm, DateTime.utc(2026, 10, 20, 9));
      expect(await speichertyp(db, 'koerperfett_pct', '2026-10-20'), 'null');
      expect(await speichertyp(db, 'fettfrei_kg', '2026-10-20'), 'null');
    });

    test('v5 → heute: alle ausstehenden Stufen laufen, nichts geht '
        'verloren', () async {
      final db = AppCache(datei(schemaSauberV5, bestandSauberV5, 5));
      addTearDown(db.close);

      expect(
        await spalten(db, 'tages_werte'),
        alleTagesWerteSpalten,
        reason:
            'robuste Stufen dürfen nicht dazu führen, dass eine Stufe ihre '
            'Arbeit gar nicht mehr tut. Das ist der Fall, für den es die '
            'Stufen gibt',
      );
      expect(await spalten(db, 'naechte'), alleNaechteSpalten);
      expect(await tabellen(db), tabellenHeute);
      expect(await abgelegteVersion(db), db.schemaVersion);

      final zeile = (await db.select(db.tagesWerte).get()).single;
      expect(zeile.schritte, 8042);
      expect(zeile.ruhepulsBpm, 51);
      expect(zeile.hrvMs, 38.4);
      expect(zeile.respRate, 15.1);
      expect(zeile.recoveryHrDrop, 27);
      expect(zeile.gelesenAm, DateTime.utc(2026, 10, 20, 9));
      expect(await speichertyp(db, 'gewicht_kg', '2026-10-20'), 'null');
      expect(await speichertyp(db, 'trainings_minuten', '2026-10-20'), 'null');
      expect(await speichertyp(db, 'koerperfett_pct', '2026-10-20'), 'null');
      expect(await speichertyp(db, 'fettfrei_kg', '2026-10-20'), 'null');

      expect(
        (await db.select(db.zielWerte).get()).single.wochenzielTrainingsminuten,
        300,
      );
    });

    test(
      'v1 → heute: alle Spalten und alle Tabellen kommen, die Zeile bleibt',
      () async {
        final db = AppCache(datei(schemaSauberV1, zeileV1, 1));
        addTearDown(db.close);

        expect(await spalten(db, 'tages_werte'), alleTagesWerteSpalten);
        expect(await spalten(db, 'naechte'), alleNaechteSpalten);
        expect(await tabellen(db), tabellenHeute);
        expect(await abgelegteVersion(db), db.schemaVersion);

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
        expect(await db.select(db.stundenSchritte).get(), isEmpty);
        expect(await db.select(db.eigeneDaten).get(), isEmpty);
      },
    );

    test('und eine v1-Datei ist danach wirklich benutzbar — ein Lauf '
        'schreibt alle neun Werte', () async {
      final db = AppCache(datei(schemaSauberV1, zeileV1, 1));
      addTearDown(db.close);
      final repo = CacheRepository(db);

      await repo.schreibeTagesWerte(const [
        DailyMetrics(
          tag: '2026-10-20',
          steps: 8042,
          restingHR: 51,
          weightKg: 81.4,
          exerciseMinutes: 47.5,
          bodyFatPct: 21.3,
          leanKg: 64.1,
        ),
      ], gelesenAm: DateTime.utc(2026, 11, 3, 8));

      final zeile = (await repo.liesTagesWerte(DataWindow.unlimited))!
          .werte
          .single;
      expect(zeile.weightKg, 81.4);
      expect(zeile.exerciseMinutes, 47.5);
      expect(zeile.bodyFatPct, 21.3);
      expect(zeile.leanKg, 64.1);
    });
  });
}
