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

/// Tests für **Migrationsstufen, die eine fremde Spalte schon vorfinden**
/// (#240) — die Gegenrichtung zu #233 und dort ausdrücklich ausgeklammert.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden.
///
/// ## Der belegte Befund
///
/// `Library/Application Support/cache.sqlite` von Tims iPhone, am 03.11.2026
/// mit `devicectl device copy from` geholt und beim Versuch gefunden, `main`
/// auf das Gerät zu bringen:
///
/// ```
/// PRAGMA user_version;  → 7
/// tages_werte:  tag schritte ruhepuls_bpm gelesen_am hrv_ms resp_rate
///               recovery_hr_drop gewicht_kg trainings_minuten
///               koerperfett_pct fettfrei_kg
/// naechte:      tag gelesen_am ruhepuls_bpm hrv_ms resp_rate
///               werte_gelesen_am
/// Tabellen:     eigene_daten naechte schlaf_abschnitte stunden_schritte
///               tages_werte tagesgefuehle ziel_werte
///               (schlaf_eintraege FEHLT)
/// ```
///
/// Die Datei ist ein Mischling. `koerperfett_pct`/`fettfrei_kg` stammen aus
/// `koerper-datenkette`, `naechte.werte_gelesen_am` und die drei
/// Nacht-Spalten aus `fix-193-nachtwerte`. Beide Zweige stehen auf
/// Schemaversion 7, bauen aber unter derselben Bundle-ID in **dieselbe**
/// Datei — die Nummer sagt deshalb nichts mehr darüber, was in der Datei
/// steht. `schlaf_eintraege` fehlt, weil keiner der beiden Zweige sie
/// angelegt hat.
///
/// `main` steht auf Schemaversion 8. Bei `from = 7` läuft genau eine Stufe,
/// und die setzt ein nacktes `ALTER TABLE naechte ADD COLUMN ruhepuls_bpm`
/// ab (drift 2.35.2 kennt für `ADD COLUMN` kein `IF NOT EXISTS`, SQLite
/// auch nicht). SQLite wirft `duplicate column name: ruhepuls_bpm`, und
/// `onUpgrade` bricht mitten im Lauf ab.
///
/// **Der Abgleich aus #233 rettet das nicht.** Er hängt in `beforeOpen`, und
/// das läuft erst **nach** `onUpgrade`. Auf dieser Datei kommt niemand je
/// dorthin.
///
/// ## Was diese Datei verbindlich vorgibt
///
/// **Keine neue API.** Alles hier geht durch `AppCache(...)` und
/// `CacheRepository`, so wie die App selbst: Datenbank öffnen, erste
/// Abfrage, fertig. Wie die Stufen robust werden — ob sie nachsehen, ob sie
/// einen gemeinsamen Helfer bekommen, ob der Abgleich vorgezogen wird —,
/// ist eine Entscheidung über die Bauform und gehört dem, der
/// implementiert. Geprüft wird ausschließlich das Verhalten: Die Datei
/// öffnet, das Schema stimmt danach, und der Bestand ist unverändert.
///
/// ## Die Anforderung ist nicht auf die v8 beschränkt
///
/// Die Einschränkung `from >= 3` im heutigen `onUpgrade` zeigt, dass dieses
/// Problem schon einmal auftrat und damals über die Versionsnummer gelöst
/// wurde. Die Nummer trägt hier nicht mehr, denn sie sagt nicht, was in der
/// Datei steht. **Keine Stufe, die eine von einer früheren Stufe angelegte
/// Tabelle erweitert, darf sich darauf verlassen, dass die Spalte fehlt.**
/// Die letzte Gruppe unten prüft das über alle Ausgangsversionen, in denen
/// `naechte` schon existiert (v3 bis v7) — heute ist `naechte` die einzige
/// solche Tabelle, und das ist genau der Fall, an dem es geknallt hat.
///
/// ## Was absichtlich nicht geprüft wird
///
/// - **Der Weg über `drift_dev schema dump`/`SchemaVerifier`.** Dieselbe
///   Begründung wie in `migration_test.dart`, `schema_v3_test.dart`,
///   `schema_v8_test.dart` und `schema_abgleich_test.dart`: Es gibt keine
///   eingefrorenen Schema-Dumps unter `drift_schemas/`, und eine Testdatei,
///   die der Implementierung vorausgeht, kann sie nicht anlegen. Die
///   Altschemata unten sind deshalb **von Hand** gebaut.
/// - **Eine Spalte mit falschem Typ oder falschem `NOT NULL`.** SQLite kann
///   das nicht nachträglich ändern; die Reparatur wäre ein Tabellenneubau
///   mit Umkopieren, und der kann Zeilen verlieren. Dieselbe Grenze wie in
///   `schema_abgleich_test.dart`.
/// - **Die fremden Spalten loszuwerden.** `koerperfett_pct`, `fettfrei_kg`
///   und `werte_gelesen_am` gibt es im heutigen Schema nicht. Sie stören
///   nicht, und eine Migration, die Spalten **wegnimmt**, nimmt Daten weg.
///   Geprüft wird deshalb, dass sie stehen bleiben — nicht, dass sie
///   verschwinden.
///
/// ## Zu den Zahlen
///
/// **Alle Werte hier sind erfunden.** Tims Datei liegt außerhalb des
/// Repositorys und ist seine echte Gesundheitsakte; aus ihr stammt
/// ausschließlich die **Form** — Tabellen- und Spaltennamen —, kein
/// einziger Messwert. Die Fixture unten ist von Hand gebaut.
void main() {
  // ---------------------------------------------------------------------
  // Bausteine der von Hand gebauten Dateien.
  //
  // `gelesen_am`, `beginn` und `ende` liegen als ISO-Text mit `Z` vor, weil
  // `AppCache` mit `storeDateTimeAsText: true` arbeitet (`cache.dart`) —
  // drifts Standard (Unix-Sekunden) gäbe sie als Ortszeit zurück, und ein
  // als UTC abgelegter Wert wäre dann ungleich sich selbst.
  // ---------------------------------------------------------------------

  /// `tages_werte` wie auf Tims Gerät: die neun Spalten des heutigen
  /// Schemas **und** die beiden aus `koerper-datenkette`, die es hier nicht
  /// gibt.
  const tagesWerteMitFremdenSpalten = '''
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

  /// `tages_werte` auf dem Stand der Stufe 7 — genau die neun Spalten, die
  /// das heutige Schema vorsieht.
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

  /// `tages_werte` auf dem Stand der Stufe 3 — vor `gewicht_kg` und
  /// `trainings_minuten` (#194).
  const tagesWerteV3 = '''
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

  /// `naechte` wie auf Tims Gerät: die drei Spalten der Stufe 8 sind schon
  /// da, dazu ein `werte_gelesen_am`, das im heutigen Schema nicht
  /// vorkommt. **Hier knallt es.**
  const naechteMitFremderSpalte = '''
    CREATE TABLE naechte (
      tag TEXT NOT NULL PRIMARY KEY,
      gelesen_am TEXT,
      ruhepuls_bpm REAL,
      hrv_ms REAL,
      resp_rate REAL,
      werte_gelesen_am TEXT
    );
  ''';

  /// `naechte` mit den drei Nacht-Spalten, ohne die fremde vierte — ein
  /// Zweig, der nur die Stufe 8 vorweggenommen hat.
  const naechteMitDreiSpalten = '''
    CREATE TABLE naechte (
      tag TEXT NOT NULL PRIMARY KEY,
      gelesen_am TEXT,
      ruhepuls_bpm REAL,
      hrv_ms REAL,
      resp_rate REAL
    );
  ''';

  /// `naechte` so, wie die Stufe 3 sie anlegt — der gesunde Ausgangsstand,
  /// bei dem die Stufe 8 die drei Spalten wirklich nachtragen muss.
  const naechteOhneNachtSpalten = '''
    CREATE TABLE naechte (
      tag TEXT NOT NULL PRIMARY KEY,
      gelesen_am TEXT
    );
  ''';

  const stundenSchritte = '''
    CREATE TABLE stunden_schritte (
      tag TEXT NOT NULL,
      stunde INTEGER NOT NULL,
      schritte INTEGER,
      PRIMARY KEY (tag, stunde)
    );
  ''';

  const eigeneDaten = '''
    CREATE TABLE eigene_daten (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      tag TEXT NOT NULL,
      inhalt TEXT NOT NULL
    );
  ''';

  const schlafAbschnitte = '''
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

  const zielWerte = '''
    CREATE TABLE ziel_werte (
      id INTEGER NOT NULL DEFAULT 0,
      schlafziel_minuten INTEGER NOT NULL,
      schlafenszeit_minuten INTEGER NOT NULL,
      wochenziel_trainingsminuten INTEGER NOT NULL,
      PRIMARY KEY (id)
    );
  ''';

  const tagesgefuehle = '''
    CREATE TABLE tagesgefuehle (
      tag TEXT NOT NULL PRIMARY KEY,
      wert INTEGER NOT NULL
    );
  ''';

  const schlafEintraege = '''
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

  /// Tims Datei vom 03.11.2026, Spalte für Spalte nachgebaut:
  /// `schlaf_eintraege` fehlt, `naechte` hat die Nacht-Spalten schon.
  const timsSchema =
      '$tagesWerteMitFremdenSpalten$stundenSchritte$eigeneDaten'
      '$naechteMitFremderSpalte$schlafAbschnitte$zielWerte$tagesgefuehle';

  /// Eine saubere Datei auf dem Stand der Stufe 7 — alles da, was die
  /// Stufe 7 hinterlässt, und `naechte` **ohne** die drei Nacht-Spalten.
  /// Hier muss die Stufe 8 nach wie vor ihre Arbeit tun.
  const sauberesV7Schema =
      '$tagesWerteV7$stundenSchritte$eigeneDaten'
      '$naechteOhneNachtSpalten$schlafAbschnitte$zielWerte$tagesgefuehle'
      '$schlafEintraege';

  /// `tages_werte` auf dem Stand der Stufe 1 — vor `gelesen_am` und vor den
  /// Erholungs-Spalten.
  const tagesWerteV1 = '''
    CREATE TABLE tages_werte (
      tag TEXT NOT NULL PRIMARY KEY,
      schritte INTEGER,
      ruhepuls_bpm INTEGER
    );
  ''';

  /// Schema v1 — vor `gelesen_am`, vor den Erholungs-Spalten, vor jeder
  /// zusätzlichen Tabelle. Derselbe Stand wie in `migration_test.dart`,
  /// `schema_v8_test.dart` und `schema_abgleich_test.dart`.
  const v1Schema = '$tagesWerteV1$stundenSchritte$eigeneDaten';

  /// Der Bestand auf Tims Gerät, in erfundenen Zahlen: ein Tag mit allen
  /// Werten, die seine Spaltenliste hergibt; zwei Nächte, von denen die
  /// eine die drei Nachtwerte des fremden Zweigs schon trägt und die
  /// andere nicht; ein Schlafabschnitt; Tims eingestellte Ziele; ein
  /// Tagesgefühl.
  const timsBestand = '''
    INSERT INTO tages_werte
      (tag, schritte, ruhepuls_bpm, gelesen_am, hrv_ms, resp_rate,
       recovery_hr_drop, gewicht_kg, trainings_minuten, koerperfett_pct,
       fettfrei_kg)
      VALUES ('2026-10-20', 8042, 51, '2026-10-20T09:00:00.000Z',
              38.4, 15.1, 27, 81.4, 47.5, 21.3, 64.1);
    INSERT INTO naechte
      (tag, gelesen_am, ruhepuls_bpm, hrv_ms, resp_rate, werte_gelesen_am)
      VALUES ('2026-10-20', '2026-10-20T09:00:00.000Z',
              48.6, 41.5, 14.2, '2026-10-20T09:05:00.000Z');
    INSERT INTO naechte (tag, gelesen_am)
      VALUES ('2026-10-19', '2026-10-19T09:00:00.000Z');
    INSERT INTO schlaf_abschnitte (tag, quelle, lfd_nr, phase, beginn, ende)
      VALUES ('2026-10-20', 0, 0, 'core',
              '2026-10-19T21:00:00.000Z', '2026-10-20T04:30:00.000Z');
    INSERT INTO ziel_werte (id, schlafziel_minuten, schlafenszeit_minuten,
                            wochenziel_trainingsminuten)
      VALUES (0, 450, 1290, 300);
    INSERT INTO tagesgefuehle (tag, wert) VALUES ('2026-10-20', 4);
  ''';

  /// Derselbe Bestand ohne die beiden fremden Spalten — für die sauberen
  /// Dateien, deren `tages_werte` sie nicht hat und deren `naechte` ohne
  /// `werte_gelesen_am` auskommt.
  const sauberesV7Bestand = '''
    INSERT INTO tages_werte
      (tag, schritte, ruhepuls_bpm, gelesen_am, hrv_ms, resp_rate,
       recovery_hr_drop, gewicht_kg, trainings_minuten)
      VALUES ('2026-10-20', 8042, 51, '2026-10-20T09:00:00.000Z',
              38.4, 15.1, 27, 81.4, 47.5);
    INSERT INTO naechte (tag, gelesen_am)
      VALUES ('2026-10-20', '2026-10-20T09:00:00.000Z');
    INSERT INTO schlaf_abschnitte (tag, quelle, lfd_nr, phase, beginn, ende)
      VALUES ('2026-10-20', 0, 0, 'core',
              '2026-10-19T21:00:00.000Z', '2026-10-20T04:30:00.000Z');
    INSERT INTO ziel_werte (id, schlafziel_minuten, schlafenszeit_minuten,
                            wochenziel_trainingsminuten)
      VALUES (0, 450, 1290, 300);
    INSERT INTO tagesgefuehle (tag, wert) VALUES ('2026-10-20', 4);
    INSERT INTO schlaf_eintraege
      (tag, art, lfd_nr, schlaf_minuten, beginn_minuten, ende_minuten, notiz)
      VALUES ('2026-10-20', 'nacht', 0, 415, 1385, 380, 'Uhr vergessen');
  ''';

  /// Der kleinste Bestand, der in **jede** der Versionen v3 bis v7 passt:
  /// die sieben Spalten, die es seit der Stufe 3 gibt, und eine Nacht mit
  /// den drei Werten, die der fremde Zweig schon geschrieben hat.
  const gemeinsamerBestand = '''
    INSERT INTO tages_werte
      (tag, schritte, ruhepuls_bpm, gelesen_am, hrv_ms, resp_rate,
       recovery_hr_drop)
      VALUES ('2026-10-20', 8042, 51, '2026-10-20T09:00:00.000Z',
              38.4, 15.1, 27);
    INSERT INTO naechte
      (tag, gelesen_am, ruhepuls_bpm, hrv_ms, resp_rate)
      VALUES ('2026-10-20', '2026-10-20T09:00:00.000Z', 48.6, 41.5, 14.2);
  ''';

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
  QueryExecutor datei(String schema, String bestand, int version) =>
      NativeDatabase.memory(
        setup: (Database roh) {
          roh.execute(schema);
          if (bestand.isNotEmpty) {
            roh.execute(bestand);
          }
          roh.execute('PRAGMA user_version = $version;');
        },
      );

  /// Die Version, die in der Datei selbst steht — nicht die, die
  /// `AppCache.schemaVersion` behauptet.
  Future<int> abgelegteVersion(AppCache db) async {
    final zeile = await db.customSelect('PRAGMA user_version;').getSingle();
    return zeile.read<int>('user_version');
  }

  /// Die Spalten einer Tabelle, so wie sie **tatsächlich** in der Datei
  /// stehen — nicht, was der Dart-Code über sie behauptet.
  Future<Set<String>> spalten(AppCache db, String tabelle) async {
    final zeilen = await db.customSelect('PRAGMA table_info($tabelle);').get();
    return zeilen.map((z) => z.read<String>('name')).toSet();
  }

  /// Die Tabellen, die es in der Datei wirklich gibt. `sqlite_%` sind die
  /// internen Tabellen von SQLite; die gehören niemandes Schema.
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
  Future<String> speichertyp(
    AppCache db,
    String tabelle,
    String spalte,
    String tag,
  ) async {
    final zeile = await db
        .customSelect(
          'SELECT typeof($spalte) AS typ FROM $tabelle WHERE tag = ?;',
          variables: [Variable<String>(tag)],
        )
        .getSingle();
    return zeile.read<String>('typ');
  }

  /// Ein beliebiger Wert aus einer Spalte, die der Dart-Code gar nicht
  /// kennt — für die fremden Spalten, die stehen bleiben müssen.
  Future<String?> fremderWert(
    AppCache db,
    String tabelle,
    String spalte,
    String tag,
  ) async {
    final zeile = await db
        .customSelect(
          'SELECT CAST($spalte AS TEXT) AS wert FROM $tabelle WHERE tag = ?;',
          variables: [Variable<String>(tag)],
        )
        .getSingle();
    return zeile.read<String?>('wert');
  }

  /// Die fünf Spalten, die `naechte` im heutigen Schema hat.
  const nachtSpaltenHeute = {
    'tag',
    'gelesen_am',
    'ruhepuls_bpm',
    'hrv_ms',
    'resp_rate',
  };

  /// Die zwölf Spalten, die `tages_werte` im heutigen Schema hat.
  ///
  /// `koerperfett_pct` und `fettfrei_kg` sind am 03.11.2026 dazugekommen:
  /// Die Stufe 9 (#202, `schema_v9_test.dart`) bringt sie. Sie trug im
  /// Zweig `koerper-datenkette` die Nummer 7 und ist beim Zusammenführen
  /// auf die nächste freie Nummer gerückt (#235).
  ///
  /// Seit der Stufe 26 (#95 mit #16) trägt die Liste dazu `vo2max` —
  /// verlangt in `schema_v26_test.dart`, damit der Ausdauer-Schirm VO₂max
  /// aus dem Cache zeigen kann. Die Altstände oben bleiben unverändert;
  /// die Spalte kommt über Stufe und Abgleich. Beim Nachzug der
  /// Bestands-Pins auf die Stufe 25 (82a2f0f, 18.11.2026) war diese Stelle
  /// übersehen worden, nachgezogen am 24.11.2026 vom Test-Agenten; **Tim
  /// hat die Änderung nicht gesehen.**
  const tagesWerteSpaltenHeute = {
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

  /// Öffnet eine Datei und erzwingt den ersten Zugriff — das Öffnen selbst
  /// ist bei drift lazy, Migration und Abgleich laufen erst bei der ersten
  /// Abfrage.
  Future<void> ersterZugriff(AppCache db) =>
      db.customSelect('SELECT 1 AS eins;').getSingle().then((_) {});

  // ---------------------------------------------------------------------

  group('Tims Datei vom 03.11.2026 — Nummer 7, Nacht-Spalten schon da (#240)', () {
    QueryExecutor timsDatei() => datei(timsSchema, timsBestand, 7);

    test('öffnet ohne Ausnahme', () async {
      final db = AppCache(timsDatei());
      addTearDown(db.close);

      await expectLater(
        ersterZugriff(db),
        completes,
        reason:
            'bei `from = 7` läuft die Stufe `from >= 3 && from < 8` und setzt '
            'ein nacktes `ALTER TABLE naechte ADD COLUMN ruhepuls_bpm` ab. '
            'Die Spalte ist schon da, SQLite wirft `duplicate column name`, '
            'und `onUpgrade` bricht ab — die App kommt auf diesem Gerät nie '
            'bis `beforeOpen`, der Abgleich aus #233 rettet sie also nicht. '
            'Eine Stufe, die eine von einer früheren Stufe angelegte Tabelle '
            'erweitert, muss nachsehen (#240)',
      );
    });

    test(
      'danach steht die Datei auf der Version, die der Code behauptet',
      () async {
        final db = AppCache(timsDatei());
        addTearDown(db.close);

        await ersterZugriff(db);

        expect(
          await abgelegteVersion(db),
          db.schemaVersion,
          reason:
              'eine abgebrochene Migration schreibt ihre Nummer nicht fest. '
              'Steht hier noch die 7, ist `onUpgrade` nicht durchgelaufen — '
              'und die Datei bleibt beim nächsten Start wieder hängen. '
              'Verglichen wird gegen `schemaVersion` statt gegen die Zahl 8: '
              'Die absolute Zahl nennt `migration_test.dart`, sonst fiele '
              'dieser Fall bei jeder künftigen Stufe mit',
        );
      },
    );

    test(
      'und das Schema entspricht vollständig dem heutigen — Tabellen',
      () async {
        final db = AppCache(timsDatei());
        addTearDown(db.close);

        await ersterZugriff(db);

        expect(
          await tabellen(db),
          containsAll(tabellenHeute),
          reason:
              '`schlaf_eintraege` fehlt in dieser Datei ganz: Keiner der '
              'beiden Zweige, die sie auf 7 gehoben haben, kannte die '
              'Tabelle. Sie muss nach dem Öffnen da sein, sonst scheitert '
              'jeder Zugriff auf die von Hand eingetragenen Schlafphasen',
        );
        expect(await db.select(db.schlafEintraege).get(), isEmpty);
      },
    );

    test(
      'und das Schema entspricht vollständig dem heutigen — Spalten',
      () async {
        final db = AppCache(timsDatei());
        addTearDown(db.close);

        await ersterZugriff(db);

        expect(await spalten(db, 'naechte'), containsAll(nachtSpaltenHeute));
        expect(
          await spalten(db, 'tages_werte'),
          containsAll(tagesWerteSpaltenHeute),
          reason:
              'die neun Spalten des heutigen Schemas müssen da sein. Dass die '
              'Datei darüber hinaus zwei fremde trägt, ist kein Mangel — '
              'geprüft wird, dass nichts **fehlt**',
        );
      },
    );

    test('die vorhandenen Zeilen stehen unverändert da', () async {
      final db = AppCache(timsDatei());
      addTearDown(db.close);

      final tagesZeile = (await db.select(db.tagesWerte).get()).single;
      expect(tagesZeile.tag, '2026-10-20');
      expect(tagesZeile.schritte, 8042);
      expect(tagesZeile.ruhepulsBpm, 51);
      expect(tagesZeile.hrvMs, 38.4);
      expect(tagesZeile.respRate, 15.1);
      expect(tagesZeile.recoveryHrDrop, 27);
      expect(tagesZeile.gewichtKg, 81.4);
      expect(tagesZeile.trainingsMinuten, 47.5);
      expect(
        tagesZeile.gelesenAm,
        DateTime.utc(2026, 10, 20, 9),
        reason:
            'der Stand überlebt — er wird nicht auf "jetzt" gesetzt. Ein '
            'nachgetragener Zeitstempel behauptete, die Zeile sei frisch',
      );

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

    test(
      'auch die Nachtwerte, die der fremde Zweig schon geschrieben hat',
      () async {
        final db = AppCache(timsDatei());
        addTearDown(db.close);

        final nacht = await (db.select(
          db.naechte,
        )..where((t) => t.tag.equals('2026-10-20'))).getSingle();

        expect(
          nacht.ruhepulsBpm,
          48.6,
          reason:
              'die Spalte war schon da und trug schon Werte. Eine Migration, '
              'die sie wegwirft und neu anlegt, um das `duplicate column name` '
              'loszuwerden, löscht genau diese Zahlen — der Weg aus der Klemme '
              'darf nicht teurer sein als die Klemme',
        );
        expect(nacht.hrvMs, 41.5);
        expect(nacht.respRate, 14.2);
        expect(nacht.gelesenAm, DateTime.utc(2026, 10, 20, 9));
      },
    );

    test('und die fremden Spalten bleiben stehen — eine Migration nimmt '
        'keine Daten weg', () async {
      final db = AppCache(timsDatei());
      addTearDown(db.close);

      await ersterZugriff(db);

      expect(
        await spalten(db, 'naechte'),
        contains('werte_gelesen_am'),
        reason:
            '`werte_gelesen_am` kennt das heutige Schema nicht. Sie stört '
            'auch nicht — aber wer sie wegräumt, räumt Daten weg, die ein '
            'anderer Zweig geschrieben hat',
      );
      expect(
        await fremderWert(db, 'naechte', 'werte_gelesen_am', '2026-10-20'),
        '2026-10-20T09:05:00.000Z',
      );
      expect(
        await fremderWert(db, 'tages_werte', 'koerperfett_pct', '2026-10-20'),
        '21.3',
      );
    });

    test(
      'keine Migration schreibt einen erfundenen Wert in eine neue Spalte',
      () async {
        final db = AppCache(timsDatei());
        addTearDown(db.close);

        final ohneWerte = await (db.select(
          db.naechte,
        )..where((t) => t.tag.equals('2026-10-19'))).getSingle();

        expect(
          ohneWerte.ruhepulsBpm,
          isNull,
          reason:
              'für diese Nacht wurde nie ein Nachtwert gerechnet. Die '
              'Versuchung, hier den gleichnamigen Tageswert aus `tages_werte` '
              'herüberzuschreiben, wäre genau der falsche Wert, dessentwegen '
              'es #193 gibt',
        );
        expect(ohneWerte.hrvMs, isNull);
        expect(ohneWerte.respRate, isNull);

        // Schärfer als der Dart-Vergleich darüber: In der Datei steht
        // wirklich NULL. Ein `0.0` käme als 'real' heraus.
        expect(
          await speichertyp(db, 'naechte', 'ruhepuls_bpm', '2026-10-19'),
          'null',
        );
        expect(
          await speichertyp(db, 'naechte', 'hrv_ms', '2026-10-19'),
          'null',
        );
        expect(
          await speichertyp(db, 'naechte', 'resp_rate', '2026-10-19'),
          'null',
        );
        expect(
          ohneWerte.gelesenAm,
          DateTime.utc(2026, 10, 19, 9),
          reason:
              'und der Stand, den die Zeile hatte, bleibt der Stand, den sie '
              'hatte — kein nachgetragenes "jetzt"',
        );
      },
    );

    test(
      'danach ist die Datei benutzbar — lesen und schreiben gehen durch',
      () async {
        final db = AppCache(timsDatei());
        addTearDown(db.close);
        final repo = CacheRepository(db);

        await repo.schreibeNachtWerte(const {
          '2026-10-19': NightVitals(
            restingHeartRate: 47.9,
            hrv: 44.0,
            respiratoryRate: 14.8,
          ),
        }, gelesenAm: DateTime.utc(2026, 11, 3, 8));

        final nachtWerte = (await repo.liesNachtWerte(DataWindow.unlimited))!;
        expect(nachtWerte.werte['2026-10-19']!.hrv, 44.0);
        expect(
          nachtWerte.werte['2026-10-20']!.restingHeartRate,
          48.6,
          reason: 'die schon vorhandene Nacht behält ihre Werte',
        );

        await repo.schreibeTagesWerte(const [
          DailyMetrics(tag: '2026-10-21', steps: 9100, weightKg: 81.0),
        ], gelesenAm: DateTime.utc(2026, 11, 3, 8));

        final tage = (await repo.liesTagesWerte(DataWindow.unlimited))!.werte;
        expect(tage.firstWhere((w) => w.tag == '2026-10-21').steps, 9100);
      },
    );
  });

  group('Der Normalfall bleibt heil', () {
    test('eine saubere v7-Datei ohne die Nacht-Spalten bekommt sie nach wie '
        'vor', () async {
      final db = AppCache(datei(sauberesV7Schema, sauberesV7Bestand, 7));
      addTearDown(db.close);

      await ersterZugriff(db);

      expect(
        await spalten(db, 'naechte'),
        nachtSpaltenHeute,
        reason:
            'das ist der Fall, für den die Stufe 8 gebaut wurde. Eine '
            'Robustheit, die den Normalfall mit abschaltet, behebt gar '
            'nichts — sie verschiebt den Fehler nur dorthin, wo er '
            'unsichtbar ist',
      );
      expect(await abgelegteVersion(db), db.schemaVersion);

      final nacht = (await db.select(db.naechte).get()).single;
      expect(nacht.gelesenAm, DateTime.utc(2026, 10, 20, 9));
      expect(nacht.ruhepulsBpm, isNull);
      expect(
        await speichertyp(db, 'naechte', 'ruhepuls_bpm', '2026-10-20'),
        'null',
      );
    });

    test('und ihr übriger Bestand übersteht den Lauf unverändert', () async {
      final db = AppCache(datei(sauberesV7Schema, sauberesV7Bestand, 7));
      addTearDown(db.close);

      final zeile = (await db.select(db.tagesWerte).get()).single;
      expect(zeile.schritte, 8042);
      expect(zeile.gewichtKg, 81.4);
      expect(zeile.trainingsMinuten, 47.5);
      expect(zeile.gelesenAm, DateTime.utc(2026, 10, 20, 9));

      final eintrag = (await db.select(db.schlafEintraege).get()).single;
      expect(eintrag.schlafMinuten, 415);
      expect(
        eintrag.notiz,
        'Uhr vergessen',
        reason:
            'hinter dieser Zeile steht kein Lauf aus Apple Health, sondern '
            'Tim. Sie ist die einzige Kopie',
      );
    });

    test('ein Neuanlegen baut alles auf einen Schlag', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      await ersterZugriff(db);

      expect(await abgelegteVersion(db), db.schemaVersion);
      expect(await tabellen(db), tabellenHeute);
      expect(await spalten(db, 'naechte'), nachtSpaltenHeute);
      expect(await spalten(db, 'tages_werte'), tagesWerteSpaltenHeute);
      expect(
        await db.select(db.naechte).get(),
        isEmpty,
        reason:
            'eine angelegte Nacht ohne Messung wäre eine Nacht mit 0 Minuten '
            'Schlaf — `onCreate` legt Tabellen an, keine Zeilen',
      );
    });

    test('und der ganze Weg von v1 nach oben läuft weiter durch', () async {
      final db = AppCache(datei(v1Schema, v1Bestand, 1));
      addTearDown(db.close);

      await ersterZugriff(db);

      expect(await abgelegteVersion(db), db.schemaVersion);
      expect(await tabellen(db), tabellenHeute);
      expect(await spalten(db, 'naechte'), nachtSpaltenHeute);
      expect(await spalten(db, 'tages_werte'), tagesWerteSpaltenHeute);

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

  group('Der allgemeine Fall — keine Stufe verlässt sich darauf, dass ihre '
      'Spalte fehlt', () {
    // `naechte` entsteht in der Stufe 3 und wird in der Stufe 8 erweitert —
    // heute die einzige Tabelle dieser Art und genau die, an der es knallte.
    // Ein Zweig kann sich auf **jeder** dieser Nummern festgesetzt haben,
    // nachdem er die drei Spalten schon angelegt hatte; die Nummer sagt
    // nicht, was in der Datei steht. Was hier für die Stufe 8 gilt, gilt
    // für jede künftige Stufe, die eine ältere Tabelle erweitert.
    const staende = <int, String>{
      3:
          '$tagesWerteV3$stundenSchritte$eigeneDaten'
          '$naechteMitDreiSpalten$schlafAbschnitte',
      4:
          '$tagesWerteV3$stundenSchritte$eigeneDaten'
          '$naechteMitDreiSpalten$schlafAbschnitte$zielWerte',
      5:
          '$tagesWerteV3$stundenSchritte$eigeneDaten'
          '$naechteMitDreiSpalten$schlafAbschnitte$zielWerte$tagesgefuehle',
      6:
          '$tagesWerteV3$stundenSchritte$eigeneDaten'
          '$naechteMitDreiSpalten$schlafAbschnitte$zielWerte$tagesgefuehle'
          '$schlafEintraege',
      7:
          '$tagesWerteV7$stundenSchritte$eigeneDaten'
          '$naechteMitDreiSpalten$schlafAbschnitte$zielWerte$tagesgefuehle'
          '$schlafEintraege',
    };

    for (final stand in staende.entries) {
      test('Nummer ${stand.key}, Nacht-Spalten schon da: öffnet, kommt oben '
          'an und behält die Werte', () async {
        final db = AppCache(datei(stand.value, gemeinsamerBestand, stand.key));
        addTearDown(db.close);

        await expectLater(
          ersterZugriff(db),
          completes,
          reason:
              'die Stufe 8 läuft bei jeder dieser Nummern mit und träfe auf '
              'eine Spalte, die es schon gibt. `from >= 3` fängt das nicht '
              'ab — die Einschränkung über die Versionsnummer war die '
              'Antwort von damals, und die Nummer trägt nicht mehr (#240)',
        );

        expect(await abgelegteVersion(db), db.schemaVersion);
        expect(await tabellen(db), containsAll(tabellenHeute));
        expect(await spalten(db, 'naechte'), containsAll(nachtSpaltenHeute));
        expect(
          await spalten(db, 'tages_werte'),
          containsAll(tagesWerteSpaltenHeute),
        );

        final nacht = (await db.select(db.naechte).get()).single;
        expect(nacht.ruhepulsBpm, 48.6);
        expect(nacht.hrvMs, 41.5);
        expect(nacht.respRate, 14.2);
        expect(nacht.gelesenAm, DateTime.utc(2026, 10, 20, 9));

        final zeile = (await db.select(db.tagesWerte).get()).single;
        expect(zeile.schritte, 8042);
        expect(zeile.hrvMs, 38.4);
        expect(zeile.gelesenAm, DateTime.utc(2026, 10, 20, 9));
      });
    }
  });
}
