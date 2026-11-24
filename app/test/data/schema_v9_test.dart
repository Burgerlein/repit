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
import 'package:repit/data/tables.dart';
import 'package:repit/health/health_types.dart';

/// Tests für **Schema v9** (#202, Teil B von
/// `docs/superpowers/specs/2026-11-02-koerper-und-messungen-design.md`) —
/// zwei weitere Spalten in `TagesWerte`, die Migration v8 → v9 und der neue
/// Leseweg `messReihe`.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden.
///
/// **Diese Datei hieß im Zweig `koerper-datenkette` `schema_v7_test.dart`
/// und war durchgehend gegen die Stufe 7 geschrieben** (#235). Auf `main`
/// war die 7 schon an #194 vergeben und die 8 an #193; beim Zusammenführen
/// am 03.11.2026 ist #202 deshalb auf die nächste freie Nummer gerückt, die
/// 9. Umnummeriert hat das der Test-Agent, nicht der Implementierende
/// (`CLAUDE.md`, Rollentrennung); Tim hat die Entscheidung nicht gesehen.
/// Die Begründung, warum eine Stufe nicht nachträglich eine schon belegte
/// Nummer bekommen darf, steht im Dateikopf von `lib/data/cache.dart`:
/// Auf einem Gerät, das schon auf 8 steht, liefe `if (from < 7)` nie, und
/// die beiden Spalten kämen dort nie an. Geprüft hat sich an den Fällen
/// unten nichts — nur die Zahlen und die Namen sind nachgezogen.
///
/// Nachfolger von `schema_v7_test.dart` (#194): derselbe Aufbau, dieselben
/// Hilfsmittel, dieselbe Begründungslinie. Was dort für `gewicht_kg` und
/// `trainings_minuten` galt, gilt hier für die beiden Spalten, die danach
/// noch fehlten.
///
/// ## Warum es diese beiden Spalten gibt
///
/// Körperfett und fettfreie Masse liegen seit Task 12 vollständig im Kanal
/// (`DailyMetrics.bodyFatPct` / `.leanKg`), haben aber keine Spalte im
/// Cache — sie kommen aus ihm deshalb **immer** `null` zurück. Der
/// Körper-Schirm (#82), die Messungen (#85) und der Verlauf je Messwert
/// (#203) stehen ohne sie entweder leer da oder müssen bei jedem Öffnen auf
/// HealthKit warten. Das ist derselbe Fehler, gegen den der Cache gebaut
/// wurde: Ladezustand als Leerstand (`01`).
///
/// ## API, die diese Tests verbindlich vorgeben
///
/// **1. `lib/data/tables.dart`** — zusätzlich zu den sieben Metrikspalten,
/// die `TagesWerte` seit Schema v7 hat, **beide nullbar**:
///
/// ```dart
/// RealColumn get koerperfettPct =>
///     real().named('koerperfett_pct').nullable()();
/// RealColumn get fettfreiKg => real().named('fettfrei_kg').nullable()();
/// ```
///
/// Die SQL-Namen (`koerperfett_pct`, `fettfrei_kg`) stehen so in der Spec,
/// die Dart-Namen folgen daraus und aus dem Stil der Nachbarn
/// (`gewichtKg`, `ruhepulsBpm`): deutsch benannt wie die ganze Tabelle. Die
/// Tests unten greifen auf beide Formen zu und legen sie damit fest.
///
/// **`RealColumn` für beide.** `DailyMetrics` trägt `bodyFatPct` und
/// `leanKg` als `double?`. Eine Ganzzahlspalte zwänge die Brücke zu runden,
/// und gerundete Messwerte sind eine stille Veränderung von Tims Daten auf
/// dem Weg in den Cache.
///
/// **2. `AppCache.schemaVersion == 9`** und eine **eigene, additive Stufe**
/// `if (from < 9) { … }` — keine Erweiterung der v8-Stufe. Begründung wie
/// bei v3/v4/v5/v6/v7/v8 (`schema_v3_test.dart`, Dateikopf): Ein Gerät, das
/// zwischen zwei Tickets aktualisiert wurde, muss den Rest nachholen
/// können.
///
/// **3. `lib/data/cache_repository.dart`** — `schreibeTagesWerte` und
/// `liesTagesWerte` behalten ihre Signatur und reichen die beiden Werte
/// zusätzlich durch. Neu dazu kommt der Leseweg:
///
/// ```dart
/// Future<List<MeasurementPoint>> messReihe(
///   MessArt art, {
///   required String von,
///   required String bis,
/// });
/// ```
///
/// - **In SQL gefiltert** (`WHERE tag >= ? AND tag <= ?`, lexikografisch
///   über den ISO-Tagesstring), nicht nach dem Laden in Dart. Das ist
///   Hausregel 2 aus `CLAUDE.md` und wird unten nicht nur behauptet,
///   sondern am Mitschnitt der tatsächlich abgesetzten Abfrage geprüft.
/// - Beide Grenzen gehören dazu.
/// - Aufsteigend nach Tag.
/// - Eine Zeile, deren Wert `NULL` ist, ist **kein** Messpunkt und kommt
///   nicht zurück. Ein fehlender Wert ist keine Messung mit dem Wert 0.
/// - Trifft nichts, ist das Ergebnis die leere Liste — der Rückgabetyp ist
///   `List<MeasurementPoint>`, nicht `List<MeasurementPoint>?`. „Kein
///   Cache" als eigener Zustand gehört zu `liesTagesWerte`, nicht hierher.
///
/// **4. `MessArt`** — ein Enum mit genau vier Fällen (`gewicht`,
/// `koerperfett`, `fettfreieMasse`, `ruhepuls`), in der App-Schicht
/// (`app/lib/data/`), nicht im Kern: Es benennt Spalten, keine Rechnung.
/// Diese Datei importiert nur `cache_repository.dart` — **`MessArt` muss
/// von dort erreichbar sein**, entweder dort definiert oder von dort mit
/// `export` durchgereicht.
///
/// **5. `MeasurementPoint.date` ist der Berliner Tagesbeginn des
/// Tagesschlüssels**, als UTC-Zeitpunkt — derselbe Rückweg, den
/// `liesNaechte` schon nimmt (`datumAusTag` in `health_types.dart`, dort
/// ausdrücklich öffentlich, damit es ihn nicht zweimal gibt). Die Tests
/// unten rechnen ihn **nicht** mit derselben Funktion nach, sondern nennen
/// die Zeitpunkte ausgeschrieben (22:00 Z im Sommer, 23:00 Z im Winter);
/// ein Test, der die Implementierung mit ihrer eigenen Hilfsfunktion
/// prüft, bewiese nur, dass sie sich selbst gleicht.
///
/// `MeasurementPoint` selbst (`date`, `value`, mit `==` und `hashCode`)
/// kommt aus `trainings_core` und ist Teil A derselben Spec; er wird dort
/// geprüft, nicht hier.
///
/// ## Was absichtlich nicht geprüft wird
///
/// - **Der Weg über `drift_dev schema dump`/`SchemaVerifier`.** Dieselbe
///   Begründung wie in `migration_test.dart`, `schema_v3_test.dart` und
///   `schema_v7_test.dart`: Es gibt keine eingefrorenen Schema-Dumps unter
///   `drift_schemas/`, und eine Testdatei, die der Implementierung
///   vorausgeht, kann sie nicht anlegen. Die Altschemata unten sind
///   deshalb **von Hand** gebaut — ein Schema, das aus dem heutigen Code
///   erzeugt wird, ist kein Altschema, sondern das neue, und bewiese
///   nichts.
/// - **Die vier Felder ohne Spalte**, die danach noch übrig sind
///   (`activeKcal`, `basalKcal`, `vo2max`, `standHours`). Die geerbte
///   Schemagrenze hält weiterhin `cache_repository_test.dart` fest, nicht
///   diese Datei.
/// - **Verdichtung, Trend und Provider.** `ChartBuckets`, `BodyTrend` und
///   die Schirme sind Teil A, C und D derselben Spec und liegen woanders.
///
/// ## Was dieser Schritt an bestehenden Tests mitgezogen hat
///
/// **Erledigt, nicht offen** (nachgezogen am 02.11.2026 vom Test-Agenten
/// dieses Tickets, committet in `af3a6e8`; beim Zusammenführen mit `main`
/// am 03.11.2026 auf die Stufe 9 umgestellt). Hier festgehalten, weil die
/// Stelle, an der eine Erwartung steigt, sonst nirgends begründet ist —
/// und **nicht** von dem zu ändern, der die Implementierung schreibt
/// (`CLAUDE.md`, „Wer Tests schreibt, schreibt nicht die
/// Implementierung"; der Haken in `.githooks/pre-commit` bricht den
/// Commit ab):
///
/// - `migration_test.dart` — `db.schemaVersion` ist auf 9 nachgezogen,
///   samt Testname und Begründung.
/// - `schema_v7_test.dart` (#194) und `schema_v8_test.dart` (#193)
///   brauchten **nichts**: Beide vergleichen den abgelegten Stand gegen
///   `AppCache.schemaVersion` statt gegen eine eigene Zahl (eingeführt mit
///   #193, begründet dort), und genau deshalb fällt bei einer neuen Stufe
///   kein Fall mehr, der von einer alten handelt. Im Zweig war das anders:
///   Dort zog #202 zwei absolute Erwartungen in `schema_v6_test.dart` mit
///   hoch. Jene Datei ist beim Zusammenführen entfallen — sie prüfte
///   Gewicht und Trainingsminuten unter der Zweignummer 6, und dasselbe
///   prüft `schema_v7_test.dart` unter der richtigen Nummer 7.
/// - `cache_repository_test.dart` — `bodyFatPct` und `leanKg` sind aus der
///   Gruppe „Geerbte Schemagrenze" genommen; sie kommen seit diesem Ticket
///   mit ihrem Wert aus dem Cache zurück. Die Liste dort ist von sechs auf
///   vier geschrumpft (`activeKcal`, `basalKcal`, `vo2max`, `standHours`,
///   Testname und Erwartung bei `:329`/`:359`).
///
/// **Alle Zahlen hier sind erfunden** — keine echten Gesundheitswerte.
void main() {
  /// Schema v8: der Stand nach #193 — sieben Metrikspalten in
  /// `tages_werte`, die von Hand eingetragenen Schlafeinträge aus #131 und
  /// die drei Nachtwerte auf `naechte`, aber noch ohne die beiden Spalten
  /// dieses Tickets. `gelesen_am`, `beginn` und `ende` liegen als ISO-Text
  /// mit `Z` vor, weil `AppCache` mit `storeDateTimeAsText: true` arbeitet
  /// (`cache.dart`); drifts Standard (Unix-Sekunden) gäbe sie als Ortszeit
  /// zurück, und ein als UTC abgelegter Wert wäre dann ungleich sich
  /// selbst.
  ///
  /// Im Zweig stand hier ein `v6Schema` ohne `schlaf_eintraege` und ohne
  /// die drei Spalten auf `naechte` — dort gab es beides noch nicht. Ein
  /// Altstand, der die Tabellen seiner eigenen Version nicht mitbringt,
  /// wäre kein v8-Gerät, sondern ein ausgedachtes; die Stufen darunter
  /// prüften dann etwas anderes als das, was sie behaupten.
  const v8Schema = '''
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
    CREATE TABLE tagesgefuehle (
      tag TEXT NOT NULL PRIMARY KEY,
      wert INTEGER NOT NULL
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
  ''';

  /// Schema v1 — vor `gelesen_am`, vor den Erholungs-Spalten, vor den
  /// Spalten aus #194, vor jeder zusätzlichen Tabelle. Derselbe Stand wie
  /// in `migration_test.dart`, `schema_v7_test.dart` und
  /// `schema_v8_test.dart`.
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

  /// Der Bestand eines v8-Geräts: ein Tag mit allen sieben Messwerten und
  /// dem Stand seines Laufs, eine gemessene Nacht mit ihren drei
  /// Nachtwerten und einem Abschnitt, Tims eingestellte Ziele, ein
  /// eingetragenes Tagesgefühl und die von Hand eingetragene Nacht aus
  /// #131 — Letztere seine **einzige** Kopie. Alles, was die Migration auf
  /// v9 unangetastet lassen muss.
  const v8Bestand = '''
    INSERT INTO tages_werte
      (tag, schritte, ruhepuls_bpm, gelesen_am, hrv_ms, resp_rate,
       recovery_hr_drop, gewicht_kg, trainings_minuten)
      VALUES ('2026-10-20', 8042, 51, '2026-10-20T09:00:00.000Z',
              38.4, 15.1, 27, 81.4, 47.5);
    INSERT INTO naechte (tag, gelesen_am, ruhepuls_bpm, hrv_ms, resp_rate)
      VALUES ('2026-10-20', '2026-10-20T09:00:00.000Z', 49.2, 41.7, 14.6);
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

  /// Der Bestand eines v1-Geräts — nur, was es damals gab.
  const v1Bestand = '''
    INSERT INTO tages_werte (tag, schritte, ruhepuls_bpm)
      VALUES ('2026-10-20', 8042, 51);
  ''';

  /// Ohne `PRAGMA user_version` meldet SQLite Version 0, drift riefe
  /// `onCreate` statt `onUpgrade` auf, und der Migrationspfad bliebe
  /// ungeprüft — in `migration_test.dart` ausführlich begründet.
  QueryExecutor altstand(String schema, String bestand, int version) =>
      NativeDatabase.memory(
        setup: (Database roh) {
          roh.execute(schema);
          roh.execute(bestand);
          roh.execute('PRAGMA user_version = $version;');
        },
      );

  /// Die Version, die in der Datei selbst steht — nicht die, die
  /// `AppCache.schemaVersion` behauptet. Nur sie belegt, dass die Migration
  /// tatsächlich gelaufen ist und ihr Ergebnis festgeschrieben hat.
  Future<int> abgelegteVersion(AppCache db) async {
    final zeile = await db.customSelect('PRAGMA user_version;').getSingle();
    return zeile.read<int>('user_version');
  }

  /// Der SQLite-Speichertyp eines Feldes (`'null'`, `'real'`, `'integer'`,
  /// `'text'`). Schärfer als ein Dart-seitiger `isNull`-Vergleich: Er zeigt,
  /// dass in der Spalte wirklich nichts steht — kein `0.0`, das Dart
  /// vielleicht noch als Zahl durchreichte, und kein Zeitstempel.
  Future<String> speichertyp(AppCache db, String spalte, String tag) async {
    final zeile = await db
        .customSelect(
          'SELECT typeof($spalte) AS typ FROM tages_werte WHERE tag = ?;',
          variables: [Variable<String>(tag)],
        )
        .getSingle();
    return zeile.read<String>('typ');
  }

  /// Fünf Tage mit vollständigen Werten, absichtlich **nicht** in
  /// Tagesreihenfolge eingefügt: So fällt auf, wenn `messReihe` die
  /// Sortierung der Einfügereihenfolge überlässt statt sie zu bestellen.
  Future<void> fuenfTage(AppCache db) async {
    const werte = <(String, double)>[
      ('2026-10-03', 81.0),
      ('2026-10-01', 82.0),
      ('2026-10-05', 80.2),
      ('2026-10-02', 81.6),
      ('2026-10-04', 80.7),
    ];
    for (final (tag, gewicht) in werte) {
      await db
          .into(db.tagesWerte)
          .insert(
            TagesWerteCompanion.insert(tag: tag, gewichtKg: Value(gewicht)),
          );
    }
  }

  group('Schema v9 — zwei weitere Spalten in TagesWerte (#202)', () {
    test('Körperfett und fettfreie Masse lassen sich schreiben und kommen '
        'unverändert zurück', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      await db
          .into(db.tagesWerte)
          .insert(
            TagesWerteCompanion.insert(
              tag: '2026-10-20',
              koerperfettPct: const Value(17.3),
              fettfreiKg: const Value(67.1),
            ),
          );

      final zeile = await (db.select(
        db.tagesWerte,
      )..where((t) => t.tag.equals('2026-10-20'))).getSingle();

      expect(zeile.koerperfettPct, 17.3);
      expect(
        zeile.fettfreiKg,
        67.1,
        reason:
            'beide kommen als Kommazahl herein (DailyMetrics.bodyFatPct und '
            '.leanKg sind double?) und müssen als Kommazahl wieder heraus — '
            'eine Ganzzahlspalte rundete Tims Wert still',
      );
    });

    test('beide Spalten sind nullbar — ein nicht gelieferter Wert bleibt '
        'null, kommt nie als 0 zurück', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      await db
          .into(db.tagesWerte)
          .insert(
            TagesWerteCompanion.insert(
              tag: '2026-10-20',
              schritte: const Value(5000),
              // koerperfettPct und fettfreiKg absichtlich nicht gesetzt:
              // An einem Tag ohne Waage gibt es diese Werte schlicht nicht.
            ),
          );

      final zeile = await (db.select(
        db.tagesWerte,
      )..where((t) => t.tag.equals('2026-10-20'))).getSingle();

      expect(zeile.schritte, 5000);
      expect(
        zeile.koerperfettPct,
        isNull,
        reason:
            'nicht gemessen ist nicht "0,0 % Körperfett" — das wäre Fehler '
            '01 in neuer Verpackung (Spec Teil B, CLAUDE.md)',
      );
      expect(
        zeile.fettfreiKg,
        isNull,
        reason: 'dasselbe für die fettfreie Masse: 0 kg ist keine Messung',
      );

      // Schärfer als der Dart-Vergleich darüber: In der Datei steht
      // wirklich NULL, keine 0.0.
      expect(await speichertyp(db, 'koerperfett_pct', '2026-10-20'), 'null');
      expect(await speichertyp(db, 'fettfrei_kg', '2026-10-20'), 'null');
    });

    test('die Datenbank steht mindestens auf Version 9', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      expect(
        db.schemaVersion,
        greaterThanOrEqualTo(9),
        reason:
            'v7 brachte gewicht_kg und trainings_minuten (#194), v8 die drei '
            'Nachtwerte auf naechte (#193), v9 bringt koerperfett_pct und '
            'fettfrei_kg (#202). Seit #269 steht die Zahl höher; die genaue '
            'Zahl zählt `migration_test.dart`, hier geht es nur darum, dass '
            'die Stufe dieses Tickets überhaupt dazugehört',
      );
    });
  });

  group('CacheRepository reicht beide Werte durch (#202, Rundweg)', () {
    test('Körperfett und fettfreie Masse kommen nach dem Zurückschreiben '
        'wieder aus dem Cache — vorher waren sie immer null', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = CacheRepository(db);

      await repo.schreibeTagesWerte(const [
        DailyMetrics(
          tag: '2026-10-20',
          steps: 8042,
          weightKg: 81.4,
          bodyFatPct: 17.3,
          leanKg: 67.1,
        ),
      ], gelesenAm: DateTime.utc(2026, 10, 20, 14, 32));

      final zeile = (await repo.liesTagesWerte(DataWindow.unlimited))!
          .werte
          .single;

      expect(zeile.steps, 8042);
      expect(zeile.weightKg, 81.4);
      expect(
        zeile.bodyFatPct,
        17.3,
        reason:
            'genau der Wert, den die Körperfett-Kachel braucht. Käme er '
            'weiter als null zurück, stünde sie nach jedem Kaltstart zuerst '
            'leer da — die Begründung von #202',
      );
      expect(zeile.leanKg, 67.1, reason: 'dasselbe für die Muskelmasse');
    });

    test('fehlt ein Feld in der Kanal-Antwort, bleibt die Spalte null — auch '
        'wenn der Nachbartag im selben Lauf einen Wert hat', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = CacheRepository(db);

      await repo.schreibeTagesWerte(const [
        // Am 19. stand Tim nicht auf der Waage: In der Kanal-Map fehlen die
        // Schlüssel, `DailyMetrics.ausMap` lässt die Felder null, und genau
        // so gehören sie in die Datenbank.
        DailyMetrics(tag: '2026-10-19', steps: 7000),
        DailyMetrics(
          tag: '2026-10-20',
          steps: 8000,
          bodyFatPct: 17.3,
          leanKg: 67.1,
        ),
      ], gelesenAm: DateTime.utc(2026, 10, 20, 14, 32));

      final werte = (await repo.liesTagesWerte(DataWindow.unlimited))!.werte;

      expect(werte.map((w) => w.tag).toList(), ['2026-10-19', '2026-10-20']);
      expect(
        werte.first.bodyFatPct,
        isNull,
        reason:
            'kein Übernehmen vom Nachbartag und kein 0,0 — nil darf auf dem '
            'Weg durch den Kanal niemals zu 0 werden (CLAUDE.md)',
      );
      expect(werte.first.leanKg, isNull);
      expect(werte.last.bodyFatPct, 17.3);
      expect(werte.last.leanKg, 67.1);

      expect(
        await speichertyp(db, 'koerperfett_pct', '2026-10-19'),
        'null',
        reason:
            'und zwar wirklich NULL in der Spalte, nicht eine 0.0, die Dart '
            'später vielleicht noch als Zahl durchreichte',
      );
      expect(await speichertyp(db, 'fettfrei_kg', '2026-10-19'), 'null');
    });
  });

  group('Migration v8 → v9 — ergänzt, verwirft nicht', () {
    QueryExecutor v8Cache() => altstand(v8Schema, v8Bestand, 8);

    test('die Datenbank steht danach wirklich auf Version 9', () async {
      final db = AppCache(v8Cache());
      addTearDown(db.close);

      // Ein Zugriff zuerst: Das Öffnen selbst ist bei drift lazy, die
      // Migration läuft erst bei der ersten Abfrage.
      await db.select(db.tagesWerte).get();

      expect(
        await abgelegteVersion(db),
        db.schemaVersion,
        reason:
            'die Stufe für #202 ist eine eigene (`if (from < 9)`), keine '
            'Erweiterung der v8-Stufe — sonst gäbe es Geräte mit "v8, aber '
            'schon mit Körperfettspalte", und die wären von außen nicht '
            'mehr unterscheidbar. Verglichen wird gegen `schemaVersion` '
            'statt gegen die Zahl 9: Seit #269 läuft danach noch die '
            'v10-Stufe, und dieser Fall handelt nicht von ihr',
      );
    });

    test(
      'die Zeile aus Schema v8 behält alle ihre Werte und ihren Stand',
      () async {
        final db = AppCache(v8Cache());
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
              'der Stand überlebt die Migration — er wird nicht auf "jetzt" '
              'gesetzt. Ein erfundener Zeitstempel behauptete, die Zeile '
              'sei frisch',
        );
      },
    );

    test(
      'und die beiden neuen Spalten bleiben leer — keine erfundenen Werte',
      () async {
        final db = AppCache(v8Cache());
        addTearDown(db.close);

        final zeile = (await db.select(db.tagesWerte).get()).single;

        expect(
          zeile.koerperfettPct,
          isNull,
          reason:
              'für diese Zeile wurde nie ein Körperfettwert geholt. Eine '
              'Migration, die hier etwas einträgt, behauptete eine Messung, '
              'die es nicht gab — derselbe Fehler wie ein erfundener '
              'Zeitstempel, nur eine Spalte weiter',
        );
        expect(zeile.fettfreiKg, isNull);

        expect(
          await speichertyp(db, 'koerperfett_pct', '2026-10-20'),
          'null',
          reason:
              'NULL heißt hier "nie gemessen", und das ist die Wahrheit. '
              'Kein Rückschreiben (Spec Teil B)',
        );
        expect(await speichertyp(db, 'fettfrei_kg', '2026-10-20'), 'null');
      },
    );

    test(
      'der übrige Bestand des Geräts übersteht die Migration ebenfalls',
      () async {
        final db = AppCache(v8Cache());
        addTearDown(db.close);

        final nacht = (await db.select(db.naechte).get()).single;
        expect(nacht.tag, '2026-10-20');
        expect(
          (nacht.ruhepulsBpm, nacht.hrvMs, nacht.respRate),
          (49.2, 41.7, 14.6),
          reason:
              'die drei Nachtwerte aus #193 standen schon in der Datei. Eine '
              'Stufe, die auf tages_werte zwei Spalten anhängt, darf an '
              'naechte nichts anfassen — additiv heißt additiv',
        );

        final abschnitt = (await db.select(db.schlafAbschnitte).get()).single;
        expect(abschnitt.phase, 'core');
        expect(abschnitt.beginn, DateTime.utc(2026, 10, 19, 21));
        expect(abschnitt.ende, DateTime.utc(2026, 10, 20, 4, 30));

        final eintrag = (await db.select(db.schlafEintraege).get()).single;
        expect(
          (eintrag.tag, eintrag.art, eintrag.schlafMinuten, eintrag.notiz),
          ('2026-10-20', 'nacht', 415, 'Uhr vergessen'),
          reason:
              'die von Hand eingetragene Nacht aus #131 ist Tims einzige '
              'Kopie — sie liegt nirgends sonst. Ein stiller Verlust hier '
              'ist nicht nachholbar',
        );

        final ziele = (await db.select(db.zielWerte).get()).single;
        expect(
          ziele.wochenzielTrainingsminuten,
          300,
          reason:
              'Tims eingestellte Ziele fallen nicht auf die Vorbelegung '
              'zurück — das sähe für ihn aus wie "meine Einstellungen sind '
              'weg"',
        );
      },
    );

    test('und die neuen Spalten sind danach wirklich benutzbar — ein Lauf '
        'schreibt in die migrierte Zeile', () async {
      final db = AppCache(v8Cache());
      addTearDown(db.close);
      final repo = CacheRepository(db);

      await repo.schreibeTagesWerte(const [
        DailyMetrics(
          tag: '2026-10-20',
          steps: 8042,
          bodyFatPct: 17.3,
          leanKg: 67.1,
        ),
      ], gelesenAm: DateTime.utc(2026, 10, 21, 7));

      final zeile = (await repo.liesTagesWerte(DataWindow.unlimited))!
          .werte
          .single;
      expect(zeile.bodyFatPct, 17.3);
      expect(zeile.leanKg, 67.1);
    });
  });

  group('Durchlauf von unten — ein Gerät auf Schema v1 landet oben an', () {
    QueryExecutor v1Cache() => altstand(v1Schema, v1Bestand, 1);

    test(
      'alle Stufen laufen durch, die Datei steht danach auf der heutigen '
      'Version',
      () async {
        final db = AppCache(v1Cache());
        addTearDown(db.close);

        await db.select(db.tagesWerte).get();

        expect(await abgelegteVersion(db), db.schemaVersion);
      },
    );

    test('die v1-Zeile behält ihre Werte, und jede seither dazugekommene '
        'Spalte ist leer', () async {
      final db = AppCache(v1Cache());
      addTearDown(db.close);

      final zeile = (await db.select(db.tagesWerte).get()).single;

      expect(zeile.tag, '2026-10-20');
      expect(zeile.schritte, 8042);
      expect(zeile.ruhepulsBpm, 51);
      expect(
        zeile.gelesenAm,
        isNull,
        reason:
            'v1 kannte die Spalte nicht — woher die Zeile stammt, weiß '
            'niemand mehr, und ein nachgetragenes "jetzt" wäre gelogen',
      );
      expect(zeile.hrvMs, isNull);
      expect(zeile.respRate, isNull);
      expect(zeile.recoveryHrDrop, isNull);
      expect(zeile.gewichtKg, isNull);
      expect(zeile.trainingsMinuten, isNull);
      expect(zeile.koerperfettPct, isNull);
      expect(zeile.fettfreiKg, isNull);
      expect(
        await speichertyp(db, 'koerperfett_pct', '2026-10-20'),
        'null',
        reason:
            'auch über alle Stufen hinweg bleibt die neue Spalte wirklich '
            'leer — kein 0, kein Zeitstempel',
      );
      expect(await speichertyp(db, 'fettfrei_kg', '2026-10-20'), 'null');
    });
  });

  group('Ein Gerät, das schon auf v9 steht', () {
    test('wird nicht noch einmal migriert — ein zweites ALTER TABLE auf eine '
        'bestehende Spalte schlüge fehl', () async {
      final db = AppCache(
        altstand(
          '''
            $v8Schema
            ALTER TABLE tages_werte ADD COLUMN koerperfett_pct REAL;
            ALTER TABLE tages_werte ADD COLUMN fettfrei_kg REAL;
            ''',
          v8Bestand,
          9,
        ),
      );
      addTearDown(db.close);

      // Liefe `onUpgrade` hier erneut, würfe schon dieser erste Zugriff
      // (`duplicate column name: koerperfett_pct`) — ein eigener
      // Ausnahme-Matcher braucht es dafür nicht.
      final zeile = (await db.select(db.tagesWerte).get()).single;
      expect(zeile.hrvMs, 38.4);
      expect(zeile.gewichtKg, 81.4);
      expect(zeile.koerperfettPct, isNull);
      expect(zeile.fettfreiKg, isNull);
    });
  });

  group('messReihe — der Leseweg je Messwert (#202)', () {
    test('MessArt hat genau vier Fälle', () {
      expect(
        MessArt.values,
        [
          MessArt.gewicht,
          MessArt.koerperfett,
          MessArt.fettfreieMasse,
          MessArt.ruhepuls,
        ],
        reason:
            'die vier Verlaufskarten des Messungen-Schirms (Spec Teil B und '
            'D). Ein fünfter Fall ohne Spalte dahinter wäre eine Anzeige, '
            'die nie etwas zeigt',
      );
    });

    test('jede Messart liest ihre eigene Spalte', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = CacheRepository(db);

      await db
          .into(db.tagesWerte)
          .insert(
            TagesWerteCompanion.insert(
              tag: '2026-10-01',
              gewichtKg: const Value(81.4),
              koerperfettPct: const Value(17.3),
              fettfreiKg: const Value(67.1),
              ruhepulsBpm: const Value(51),
            ),
          );

      Future<List<double>> werte(MessArt art) async {
        // Der Rückgabetyp steht hier ausgeschrieben, damit er mitgeprüft
        // wird: `List<MeasurementPoint>` aus `trainings_core` (Teil A
        // derselben Spec), kein eigener Satztyp der App-Schicht und kein
        // `List<double>` ohne Zeitpunkt.
        final List<MeasurementPoint> punkte = await repo.messReihe(
          art,
          von: '2026-10-01',
          bis: '2026-10-01',
        );
        return punkte.map((p) => p.value).toList();
      }

      expect(await werte(MessArt.gewicht), [81.4]);
      expect(await werte(MessArt.koerperfett), [17.3]);
      expect(await werte(MessArt.fettfreieMasse), [67.1]);
      expect(
        await werte(MessArt.ruhepuls),
        [51.0],
        reason:
            'ruhepuls_bpm ist eine Ganzzahlspalte, MeasurementPoint.value '
            'ist double — der Wert kommt als 51.0 heraus, nicht als Fehler',
      );
    });

    test('eine Zeile ohne Wert ist kein Messpunkt und fällt weg', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = CacheRepository(db);

      await db.batch((batch) {
        batch.insertAll(db.tagesWerte, [
          TagesWerteCompanion.insert(
            tag: '2026-10-01',
            koerperfettPct: const Value(17.3),
          ),
          // Am 2. gab es Schritte, aber keinen Waagenwert.
          TagesWerteCompanion.insert(
            tag: '2026-10-02',
            schritte: const Value(8042),
          ),
          TagesWerteCompanion.insert(
            tag: '2026-10-03',
            koerperfettPct: const Value(16.9),
          ),
        ]);
      });

      final punkte = await repo.messReihe(
        MessArt.koerperfett,
        von: '2026-10-01',
        bis: '2026-10-03',
      );

      expect(
        punkte.map((p) => p.value).toList(),
        [17.3, 16.9],
        reason:
            'zwei Punkte, nicht drei — der 2. hat keinen Wert. Ein dritter '
            'Punkt mit 0,0 zöge die Kurve auf null und behauptete eine '
            'Messung, die es nicht gab (Fehler 01)',
      );
      expect(punkte, hasLength(2));
    });

    test(
      'beide Grenzen gehören dazu, alles außerhalb bleibt draußen',
      () async {
        final db = AppCache(NativeDatabase.memory());
        addTearDown(db.close);
        final repo = CacheRepository(db);
        await fuenfTage(db);

        final punkte = await repo.messReihe(
          MessArt.gewicht,
          von: '2026-10-02',
          bis: '2026-10-04',
        );

        expect(
          punkte.map((p) => p.value).toList(),
          [81.6, 81.0, 80.7],
          reason:
              'der 2. und der 4. zählen mit (beide Grenzen einschließlich), '
              'der 1. und der 5. nicht',
        );
      },
    );

    test(
      'aufsteigend sortiert, unabhängig von der Einfügereihenfolge',
      () async {
        final db = AppCache(NativeDatabase.memory());
        addTearDown(db.close);
        final repo = CacheRepository(db);
        await fuenfTage(db);

        final punkte = await repo.messReihe(
          MessArt.gewicht,
          von: '2026-10-01',
          bis: '2026-10-05',
        );

        expect(punkte.map((p) => p.value).toList(), [
          82.0,
          81.6,
          81.0,
          80.7,
          80.2,
        ]);
        for (var i = 1; i < punkte.length; i++) {
          expect(
            punkte[i].date.isAfter(punkte[i - 1].date),
            isTrue,
            reason:
                'ein Verlauf, der nicht nach der Zeit sortiert ist, zeichnet '
                'eine Linie, die vor- und zurückspringt',
          );
        }
      },
    );

    test(
      'trifft nichts, kommt die leere Liste — kein null, kein Wurf',
      () async {
        final db = AppCache(NativeDatabase.memory());
        addTearDown(db.close);
        final repo = CacheRepository(db);
        await fuenfTage(db);

        expect(
          await repo.messReihe(
            MessArt.gewicht,
            von: '2026-11-01',
            bis: '2026-11-30',
          ),
          isEmpty,
          reason:
              '"kein Cache" als eigener Zustand gehört zu liesTagesWerte; '
              'hier heißt leer schlicht leer',
        );
      },
    );

    test('der Zeitpunkt eines Punkts ist der Berliner Tagesbeginn, als '
        'UTC-Zeitpunkt', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = CacheRepository(db);

      await db.batch((batch) {
        batch.insertAll(db.tagesWerte, [
          TagesWerteCompanion.insert(
            tag: '2026-01-15',
            gewichtKg: const Value(82.0),
          ),
          TagesWerteCompanion.insert(
            tag: '2026-07-01',
            gewichtKg: const Value(80.5),
          ),
        ]);
      });

      final punkte = await repo.messReihe(
        MessArt.gewicht,
        von: '2026-01-01',
        bis: '2026-12-31',
      );

      expect(punkte, hasLength(2));
      expect(
        punkte.first.date,
        DateTime.utc(2026, 1, 14, 23),
        reason:
            'im Januar steht Berlin auf UTC+1: Mitternacht des 15. ist '
            '23:00 Z am 14. Ein DateTime.parse auf den Tagesstring läge '
            'eine Stunde daneben',
      );
      expect(
        punkte.last.date,
        DateTime.utc(2026, 6, 30, 22),
        reason:
            'im Juli steht Berlin auf UTC+2: Mitternacht des 1. ist 22:00 Z '
            'am 30. Juni — zwei Stunden, nicht eine',
      );
      expect(
        punkte.every((p) => p.date.isUtc),
        isTrue,
        reason:
            'die ganze Zeitrechnung läuft über UTC-Zeitpunkte, die Berliner '
            'Tagesgrenzen bezeichnen (CLAUDE.md). Ein Ortszeit-DateTime '
            'wäre ungleich sich selbst',
      );
    });

    test('die Auswahl steht in SQL, nicht in Dart (Hausregel 2)', () async {
      final mitschnitt = _SqlMitschnitt();
      final db = AppCache(NativeDatabase.memory().interceptWith(mitschnitt));
      addTearDown(db.close);
      final repo = CacheRepository(db);
      await fuenfTage(db);

      mitschnitt.abfragen.clear();
      final punkte = await repo.messReihe(
        MessArt.gewicht,
        von: '2026-10-02',
        bis: '2026-10-04',
      );
      expect(punkte, hasLength(3));

      final gelesen = mitschnitt.abfragen
          .where((a) => a.sql.contains('tages_werte'))
          .toList();

      expect(
        gelesen,
        hasLength(1),
        reason: 'eine Reihe, eine Abfrage — nicht eine Abfrage je Tag',
      );
      expect(
        gelesen.single.sql.toUpperCase(),
        contains('WHERE'),
        reason:
            'DataWindow wird zu WHERE tag >= ? AND tag <= ?, lexikografisch '
            'über den ISO-Tagesstring (Spec Teil B)',
      );
      expect(
        gelesen.single.args,
        containsAll(<Object?>['2026-10-02', '2026-10-04']),
        reason:
            'beide Grenzen gehen als gebundene Werte an SQLite, nicht in '
            'den Abfragetext gestückelt',
      );
      expect(
        gelesen.single.zeilen,
        3,
        reason:
            'SQLite gab nur die drei Zeilen des Fensters zurück. Kämen alle '
            'fünf heraus und würde Dart danach filtern, wäre das genau der '
            'Fehler 03, gegen den Hausregel 2 geschrieben ist — und auf '
            'einem Jahr Daten die Last, die beim Scrollen ruckelt',
      );
    });
  });
}

/// Mitschnitt der Abfragen, die wirklich an SQLite gehen — samt der Zahl
/// der Zeilen, die zurückkamen.
///
/// Das ist der einzige Weg, „in SQL gefiltert" zu **prüfen** statt zu
/// glauben: Eine Dart-seitige Filterung liefert dasselbe Ergebnis und ist
/// am Rückgabewert allein nicht zu erkennen. Sichtbar wird sie erst daran,
/// dass die Datenbank mehr Zeilen herausgibt, als am Ende Punkte
/// herauskommen.
class _SqlMitschnitt extends QueryInterceptor {
  final List<({String sql, List<Object?> args, int zeilen})> abfragen = [];

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    final zeilen = await executor.runSelect(statement, args);
    abfragen.add((sql: statement, args: args, zeilen: zeilen.length));
    return zeilen;
  }
}
