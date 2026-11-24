// `drift` exportiert ein eigenes `isNull` **und** ein eigenes `isNotNull`
// (Spaltenausdrücke für `IS NULL`/`IS NOT NULL` in Abfragen) — die verdecken
// sonst die gleichnamigen `package:matcher`-Matcher, die `expect(...,
// isNull)` und `expect(..., isNotNull)` unten brauchen. Dieselbe Begründung
// wie in `test/data/migration_test.dart`, Zeile 1–4; dort steht nur `isNull`,
// weil dort kein `isNotNull` vorkommt.
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show Database;
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/data/cache_repository.dart';
import 'package:repit/health/health_types.dart';

/// Tests für **Schema v8** (#193, Stufe 3 von
/// `docs/superpowers/specs/2026-11-02-193-nachtwerte.md`) — drei neue
/// Spalten auf `Naechte` und die Migration dorthin.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden.
///
/// ## Die Stufe heißt v8, nicht v7
///
/// Die Spec schreibt für Stufe 3 „Cache: Schema v7". Das stimmt seit dem
/// Zusammenführen von #194 nicht mehr: Dort ist die **v7** für `gewicht_kg`
/// und `trainings_minuten` vergeben worden, die **v6** blieb bei
/// `schlaf_eintraege` (#131). `AppCache.schemaVersion` steht heute auf 7,
/// also ist die nächste freie Stufe die 8. Das ist keine Entscheidung
/// Tims und keine der Spec, sondern die Folge einer schon vergebenen
/// Nummer; die Spec ist im selben Zug nachgezogen worden.
///
/// ## Warum es diese drei Spalten gibt
///
/// `NightVitals` (Stufe 1, `Packages/trainings_core/lib/src/night_vitals.dart`)
/// rechnet Ruhepuls, HRV und Atemfrequenz **einer Nacht** aus den Proben im
/// Schlaffenster. Die Rohproben liegen nicht im Cache und sollen es nicht —
/// das wären für dreißig Tage rund 24.000 Pulsproben (Spec, „Warum eine
/// eigene Spalte"). **Gespeichert wird das Ergebnis, nicht die Eingabe.**
///
/// Die Nacht ist die Einheit, zu der die drei Werte gehören, also gehören
/// sie auf `Naechte` und nicht auf `TagesWerte`: Dort stehen die Tageswerte
/// desselben Kalendertags, und genau deren Verwechslung mit der Nacht ist
/// der Fehler, den #193 behebt. Zwei Spalten gleichen Namens in zwei
/// Tabellen sind hier kein Versehen, sondern der Unterschied selbst.
///
/// ## API, die diese Tests verbindlich vorgeben
///
/// In `lib/data/tables.dart`, zusätzlich zu `tag` und `gelesenAm` auf
/// `Naechte` — **alle drei nullbar**, denn ein fehlender Messwert ist nicht
/// `0` (Global Constraint, `migration_test.dart`):
///
/// ```dart
/// RealColumn get ruhepulsBpm => real().named('ruhepuls_bpm').nullable()();
/// RealColumn get hrvMs => real().named('hrv_ms').nullable()();
/// RealColumn get respRate => real().named('resp_rate').nullable()();
/// ```
///
/// Die SQL-Namen stehen so in der Spec; die Dart-Namen sind die der
/// gleichnamigen Spalten in `TagesWerte`, damit nicht zwei Schreibweisen
/// für dieselbe Größe entstehen.
///
/// **`RealColumn` auch für den Ruhepuls**, anders als in `TagesWerte`, wo
/// er eine `IntColumn` ist. Apples `RestingHeartRate` kam als ganze Zahl;
/// der Wert hier ist das linear interpolierte 5. Perzentil
/// (`NightVitals.restingHeartRate` ist `double?`). Eine Ganzzahlspalte
/// zwänge die Brücke zu runden, und das wäre eine stille Veränderung des
/// gerechneten Werts auf dem Weg in den Cache — derselbe Grund, aus dem
/// `trainings_minuten` in #194 eine `RealColumn` wurde.
///
/// Daraus folgt `AppCache.schemaVersion == 8` (geprüft in
/// `migration_test.dart` und `schlaf_eintrag_test.dart`, die beide die
/// Stufen mitzählen) und eine **eigene, additive Stufe** `if (from < 8)` —
/// keine Erweiterung der v7-Stufe. Begründung wie bei v3 bis v7
/// (`schema_v3_test.dart`, Dateikopf): Ein Gerät, das zwischen zwei
/// Tickets aktualisiert wurde, muss den Rest nachholen können.
///
/// In `lib/data/cache_repository.dart` kommen **zwei** Methoden dazu:
///
/// ```dart
/// Future<({Map<String, NightVitals> werte, DateTime stand})?>
///     liesNachtWerte(DataWindow fenster);
///
/// Future<void> schreibeNachtWerte(
///   Map<String, NightVitals> werte, {
///   required DateTime gelesenAm,
/// });
/// ```
///
/// Der Schlüssel ist der ISO-Tagesschlüssel des **Aufwachtags**, derselbe
/// wie in `Naechte.tag` — ein Tag ist eine Kalenderangabe, kein Zeitpunkt
/// (`CLAUDE.md`).
///
/// Drei Entscheidungen, die diese Datei trifft, weil sie irgendwo getroffen
/// werden müssen:
///
/// 1. **`schreibeNachtWerte` legt keine Nacht an.** Gibt es zu einem Tag
///    keine Zeile in `Naechte`, entsteht auch keine. Eine Zeile ohne
///    Abschnitte läse `liesNaechte` als Nacht **ohne Schlaf** — eine Nacht
///    mit 0 Minuten, also ein erfundener Wert und Fehler `01` eine Tabelle
///    weiter. Der Fall tritt im Betrieb nicht auf: Gerechnet wird über die
///    Nächte aus `sleepProvider`, und der hat sie vorher geschrieben.
/// 2. **`gelesen_am` wird mitgeschrieben**, wie in jedem anderen
///    Schreibweg dieser Brücke: Ein Lauf hat einen Zeitpunkt (Spec 5.3b).
///    Dass damit auch der Stand der Nacht auf diesen Lauf rückt, ist
///    gewollt — beide Läufe gehören zum selben Start der App, und ein
///    zweiter Zeitstempel allein für die drei Spalten wäre eine vierte
///    Spalte, die die Spec nicht vorsieht.
/// 3. **Eine Nacht ohne jeden der drei Werte ist kein Cache-Eintrag.** Sie
///    taucht in der Karte nicht auf, und trägt **keine** Nacht des Fensters
///    einen Wert, liefert `liesNachtWerte` `null` — „kein Cache" ist ein
///    eigener Zustand (Spec 5.3d). Sonst stünde nach dem ersten Schlaflauf
///    eine leere Karte als „Bekannt" da, und das ist genau der Ladezustand,
///    der als Leerstand gelesen wird.
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
/// - **Ob ein erneuter Schlaflauf (`schreibeNaechte`) die drei Spalten
///   stehen lässt.** Das ist das `NULL`-Überschreiben aus #197, in der Spec
///   zu #193 ausdrücklich als „nicht Gegenstand" geführt und dort zu
///   entscheiden. Ein Test hier schriebe eine Entscheidung fest, die
///   niemand getroffen hat.
/// - **Die Rechnung selbst.** Die steht im Kern und ist mit 43 Fällen in
///   `Packages/trainings_core/test/night_vitals_test.dart` belegt. Hier
///   geht es nur darum, dass das Ergebnis heil durch die Datenbank kommt.
///
/// **Alle Zahlen hier sind erfunden** — keine echten Gesundheitswerte.
void main() {
  /// Schema v7 — der Stand vor dieser Stufe, von Hand nachgebaut.
  /// `gelesen_am`, `beginn` und `ende` liegen als ISO-Text mit `Z` vor,
  /// weil `AppCache` mit `storeDateTimeAsText: true` arbeitet
  /// (`cache.dart`); drifts Standard (Unix-Sekunden) gäbe sie als Ortszeit
  /// zurück, und ein als UTC abgelegter Wert wäre dann ungleich sich
  /// selbst.
  const v7Schema = '''
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
      gelesen_am TEXT
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

  /// Schema v6 — v7 ohne die beiden Spalten aus #194. Ein Gerät, das
  /// zwischen #131 und #194 nicht aktualisiert wurde, steht hier; es muss
  /// in einem Lauf bei v8 ankommen und dabei **beide** ausstehenden Stufen
  /// nachholen.
  const v6Schema = '''
    CREATE TABLE tages_werte (
      tag TEXT NOT NULL PRIMARY KEY,
      schritte INTEGER,
      ruhepuls_bpm INTEGER,
      gelesen_am TEXT,
      hrv_ms REAL,
      resp_rate REAL,
      recovery_hr_drop INTEGER
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
      gelesen_am TEXT
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

  /// Schema v1 — vor `gelesen_am`, vor den Erholungs-Spalten, vor jeder
  /// zusätzlichen Tabelle. Derselbe Stand wie in `migration_test.dart` und
  /// `schema_v7_test.dart`.
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

  /// Der Bestand eines Geräts auf v6 oder v7: ein Tag mit seinen
  /// Tageswerten, eine gemessene Nacht mit einem Abschnitt, Tims Ziele, ein
  /// Tagesgefühl und die von Hand eingetragene Nacht aus #131 — Letztere
  /// seine **einzige** Kopie. Alles davon muss die Stufe auf v8 unverändert
  /// überstehen.
  const bestand = '''
    INSERT INTO tages_werte
      (tag, schritte, ruhepuls_bpm, gelesen_am, hrv_ms, resp_rate,
       recovery_hr_drop)
      VALUES ('2026-10-20', 8042, 51, '2026-10-20T09:00:00.000Z',
              38.4, 15.1, 27);
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

  /// Der Bestand eines v1-Geräts — nur, was es damals gab.
  const v1Bestand = '''
    INSERT INTO tages_werte (tag, schritte, ruhepuls_bpm)
      VALUES ('2026-10-20', 8042, 51);
  ''';

  /// Ohne `PRAGMA user_version` meldet SQLite Version 0, drift riefe
  /// `onCreate` statt `onUpgrade` auf, und der Migrationspfad bliebe
  /// ungeprüft — in `migration_test.dart` ausführlich begründet.
  QueryExecutor altstand(String schema, String inhalt, int version) =>
      NativeDatabase.memory(
        setup: (Database roh) {
          roh.execute(schema);
          roh.execute(inhalt);
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

  /// Der SQLite-Speichertyp eines Feldes in `naechte` (`'null'`, `'real'`,
  /// `'integer'`, `'text'`). Schärfer als ein Dart-seitiger
  /// `isNull`-Vergleich: Er zeigt, dass in der Spalte wirklich nichts
  /// steht — kein `0.0`, das Dart vielleicht noch als Zahl durchreichte.
  Future<String> speichertyp(AppCache db, String spalte, String tag) async {
    final zeile = await db
        .customSelect(
          'SELECT typeof($spalte) AS typ FROM naechte WHERE tag = ?;',
          variables: [Variable<String>(tag)],
        )
        .getSingle();
    return zeile.read<String>('typ');
  }

  /// Eine Nacht mit einem einzigen Abschnitt — gebraucht, wo eine Zeile in
  /// `Naechte` vorliegen muss, damit `schreibeNachtWerte` etwas zu ergänzen
  /// hat.
  SleepNight nacht(String tag) {
    // Die Zeiten hängen am Aufwachtag, statt für jede Nacht dieselben zu
    // sein: Ein Abschnitt, der zu einem anderen Tag gehört als seine
    // Nacht, wäre genau der Zahlendreher, den diese Testfälle sonst
    // einschleppen.
    final aufwachtag = datumAusTag(tag);
    return SleepNight(
      date: aufwachtag,
      session: SleepSession(
        segments: [
          SleepSegment(
            stage: SleepStage.core,
            start: aufwachtag.subtract(const Duration(hours: 3)),
            end: aufwachtag.add(const Duration(hours: 6, minutes: 30)),
          ),
        ],
      ),
    );
  }

  group('Schema v8 — drei neue Spalten in Naechte (#193)', () {
    test('die drei Werte lassen sich schreiben und kommen unverändert '
        'zurück', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      await db
          .into(db.naechte)
          .insert(
            NaechteCompanion.insert(
              tag: '2026-10-20',
              ruhepulsBpm: const Value(48.6),
              hrvMs: const Value(41.5),
              respRate: const Value(14.2),
            ),
          );

      final zeile = await (db.select(
        db.naechte,
      )..where((t) => t.tag.equals('2026-10-20'))).getSingle();

      expect(
        zeile.ruhepulsBpm,
        48.6,
        reason:
            'der Ruhepuls der Nacht ist das linear interpolierte 5. '
            'Perzentil und damit eine Kommazahl. Eine Ganzzahlspalte '
            'rundete ihn still — dieselbe Begründung wie bei '
            '`trainings_minuten` in #194',
      );
      expect(zeile.hrvMs, 41.5);
      expect(zeile.respRate, 14.2);
    });

    test('alle drei Spalten sind nullbar — ein nicht gemessener Wert bleibt '
        'null, kommt nie als 0 zurück', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      await db
          .into(db.naechte)
          .insert(
            NaechteCompanion.insert(
              tag: '2026-10-20',
              gelesenAm: Value(DateTime.utc(2026, 10, 20, 9)),
              // Die drei Werte absichtlich nicht gesetzt: eine Nacht ohne
              // Uhr am Handgelenk hat keinen davon.
            ),
          );

      final zeile = await (db.select(
        db.naechte,
      )..where((t) => t.tag.equals('2026-10-20'))).getSingle();

      expect(
        zeile.ruhepulsBpm,
        isNull,
        reason:
            'nicht gemessen ist nicht "0 bpm". Ein Ruhepuls von 0 wäre '
            'kein fehlender Wert, sondern ein Alarmwert — Fehler 01 eine '
            'Tabelle weiter',
      );
      expect(zeile.hrvMs, isNull);
      expect(zeile.respRate, isNull);
      expect(
        zeile.gelesenAm,
        DateTime.utc(2026, 10, 20, 9),
        reason: 'der Stand der Nacht bleibt, was er war',
      );
    });
  });

  group('CacheRepository hält die Nachtwerte (#193, Rundweg)', () {
    test('geschriebene Nachtwerte kommen unter ihrem Tagesschlüssel wieder '
        'heraus, mit dem Stand ihres Laufs', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = CacheRepository(db);
      final geholt = DateTime.utc(2026, 10, 20, 14, 32);

      await repo.schreibeNaechte([
        nacht('2026-10-20'),
      ], gelesenAm: DateTime.utc(2026, 10, 20, 9));
      await repo.schreibeNachtWerte(const {
        '2026-10-20': NightVitals(
          restingHeartRate: 48.6,
          hrv: 41.5,
          respiratoryRate: 14.2,
        ),
      }, gelesenAm: geholt);

      final gelesen = await repo.liesNachtWerte(DataWindow.unlimited);

      expect(gelesen, isNotNull);
      expect(
        gelesen!.werte['2026-10-20'],
        const NightVitals(
          restingHeartRate: 48.6,
          hrv: 41.5,
          respiratoryRate: 14.2,
        ),
        reason:
            'NightVitals trägt == und hashCode, der Vergleich geht also '
            'über den Wert und nicht über die Instanz',
      );
      expect(
        gelesen.stand,
        geholt,
        reason:
            'ein Lauf hat einen Zeitpunkt (Spec 5.3b) — das ist der '
            'Stand, den die Ansicht als "Stand 14:32" liest',
      );
    });

    test('eine Nacht mit nur einem der drei Werte kommt mit genau diesem '
        'einen zurück — die beiden anderen bleiben null', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = CacheRepository(db);

      await repo.schreibeNaechte([
        nacht('2026-10-20'),
      ], gelesenAm: DateTime.utc(2026, 10, 20, 9));
      await repo.schreibeNachtWerte(const {
        // Die Uhr misst HRV nur zwei- bis sechsmal je Nacht; dass eine
        // Nacht nur einen der drei Werte hat, ist der Normalfall, nicht
        // die Ausnahme.
        '2026-10-20': NightVitals(hrv: 41.5),
      }, gelesenAm: DateTime.utc(2026, 10, 20, 14, 32));

      final werte = (await repo.liesNachtWerte(DataWindow.unlimited))!.werte;

      expect(werte['2026-10-20']!.hrv, 41.5);
      expect(
        werte['2026-10-20']!.restingHeartRate,
        isNull,
        reason:
            'zu wenige Pulsproben heißt null, nicht 0 (NightVitals, '
            'mindestens fünf Proben). Ein Ruhepuls von 0 bpm stünde als '
            'Zahl auf dem Schirm',
      );
      expect(werte['2026-10-20']!.respiratoryRate, isNull);
    });

    test('eine Nacht ohne jeden der drei Werte taucht gar nicht auf — und '
        'trägt keine Nacht des Fensters einen, gibt es keinen Cache', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = CacheRepository(db);

      // Genau der Zustand nach dem allerersten Schlaflauf: Die Nächte
      // liegen im Cache, die Nachtwerte sind noch nie gerechnet worden.
      await repo.schreibeNaechte([
        nacht('2026-10-20'),
      ], gelesenAm: DateTime.utc(2026, 10, 20, 9));

      expect(
        await repo.liesNachtWerte(DataWindow.unlimited),
        isNull,
        reason:
            '"kein Cache" ist ein eigener Zustand (Spec 5.3d). Eine leere '
            'Karte mit einem Stand behauptete einen Lauf, den es nicht '
            'gab — und der Provider gäbe daraufhin Bekannt({}) aus, also '
            'einen Ladezustand als Leerstand',
      );
    });

    test('schreibeNachtWerte legt keine Nacht an, die es nicht gibt', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = CacheRepository(db);

      await repo.schreibeNachtWerte(const {
        '2026-10-20': NightVitals(restingHeartRate: 48.6),
      }, gelesenAm: DateTime.utc(2026, 10, 20, 14, 32));

      expect(
        await db.select(db.naechte).get(),
        isEmpty,
        reason:
            'eine Zeile in `naechte` ohne Abschnitte läse `liesNaechte` '
            'als Nacht ohne Schlaf — eine Nacht mit 0 Minuten, also ein '
            'erfundener Wert. Die Nachtwerte ergänzen eine Nacht, sie '
            'bringen keine hervor',
      );
      expect(await repo.liesNachtWerte(DataWindow.unlimited), isNull);
    });

    test('ein zweiter Lauf überschreibt die Werte derselben Nacht, statt '
        'sie zu verdoppeln', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = CacheRepository(db);

      await repo.schreibeNaechte([
        nacht('2026-10-20'),
      ], gelesenAm: DateTime.utc(2026, 10, 20, 9));
      await repo.schreibeNachtWerte(const {
        '2026-10-20': NightVitals(restingHeartRate: 48.6, hrv: 41.5),
      }, gelesenAm: DateTime.utc(2026, 10, 20, 9, 5));
      await repo.schreibeNachtWerte(const {
        '2026-10-20': NightVitals(restingHeartRate: 47.9, hrv: 44.0),
      }, gelesenAm: DateTime.utc(2026, 10, 20, 14, 32));

      final gelesen = (await repo.liesNachtWerte(DataWindow.unlimited))!;

      expect(gelesen.werte, hasLength(1));
      expect(gelesen.werte['2026-10-20']!.restingHeartRate, 47.9);
      expect(gelesen.werte['2026-10-20']!.hrv, 44.0);
      expect(gelesen.stand, DateTime.utc(2026, 10, 20, 14, 32));
    });

    test('das Fenster filtert in SQL — Nächte vor dem Fensterbeginn kommen '
        'nicht mit, und der Stand gehört zu den übrigen', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = CacheRepository(db);

      await repo.schreibeNaechte([
        nacht('2026-10-18'),
        nacht('2026-10-20'),
      ], gelesenAm: DateTime.utc(2026, 10, 18, 9));
      await repo.schreibeNachtWerte(const {
        '2026-10-18': NightVitals(restingHeartRate: 50.1),
      }, gelesenAm: DateTime.utc(2026, 10, 18, 9, 5));
      await repo.schreibeNachtWerte(const {
        '2026-10-20': NightVitals(restingHeartRate: 48.6),
      }, gelesenAm: DateTime.utc(2026, 10, 20, 14, 32));

      final gelesen = (await repo.liesNachtWerte(
        DataWindow(start: DateTime.utc(2026, 10, 19, 12)),
      ))!;

      expect(
        gelesen.werte.keys.toList(),
        ['2026-10-20'],
        reason:
            'gefiltert wird in SQL über den Tagesschlüssel — nach dem '
            'Laden in Dart zu filtern umginge Regel 2 der Datenschicht',
      );
      expect(
        gelesen.stand,
        DateTime.utc(2026, 10, 20, 14, 32),
        reason:
            'der Stand gehört zu den tatsächlich zurückgegebenen Nächten, '
            'nicht zu einer außerhalb des Fensters — sonst behauptete die '
            'Standzeile einen Lauf, dessen Daten gar nicht auf dem Schirm '
            'stehen',
      );
    });

    test('eine Nacht ohne bekannten Stand gilt als kein Cache — kein '
        'Bekannt mit erfundenem Zeitstempel', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = CacheRepository(db);

      // Eine Nacht, deren `gelesen_am` leer ist: so sieht eine Zeile nach
      // einer Migration aus einem Schema ohne diese Spalte aus.
      await db
          .into(db.naechte)
          .insert(
            NaechteCompanion.insert(
              tag: '2026-10-20',
              ruhepulsBpm: const Value(48.6),
            ),
          );

      expect(
        await repo.liesNachtWerte(DataWindow.unlimited),
        isNull,
        reason:
            'dieselbe Regel wie bei liesNaechte und liesTagesWerte: Ein '
            'Bekannt ohne ehrlichen Stand wäre eine erfundene Zahl',
      );
    });
  });

  group('Migration v7 → v8 — ergänzt, verwirft nicht', () {
    QueryExecutor v7Cache() => altstand(v7Schema, bestand, 7);

    test(
      'die Datenbank steht danach auf dem Stand, den der Code behauptet',
      () async {
        final db = AppCache(v7Cache());
        addTearDown(db.close);

        // Ein Zugriff zuerst: Das Öffnen selbst ist bei drift lazy, die
        // Migration läuft erst bei der ersten Abfrage.
        await db.select(db.naechte).get();

        expect(
          await abgelegteVersion(db),
          db.schemaVersion,
          reason:
              'eine eigene Stufe `if (from < 8)`, keine Erweiterung der '
              'v7-Stufe — sonst gäbe es Geräte mit "v7, aber schon mit '
              'Nachtwerten", und die wären von außen nicht mehr '
              'unterscheidbar. Verglichen wird gegen `schemaVersion` statt '
              'gegen die Zahl 8: Dass die v8-Stufe gelaufen ist, zeigen die '
              'Spaltenprüfungen darunter. Die absolute Zahl nennt nur '
              '`migration_test.dart` — sonst fällt bei jeder neuen Stufe '
              'auch dieser Fall, obwohl er von v8 handelt (#208)',
        );
      },
    );

    test(
      'die Nacht aus Schema v7 behält ihren Stand und ihre Abschnitte',
      () async {
        final db = AppCache(v7Cache());
        addTearDown(db.close);

        final nachtZeile = (await db.select(db.naechte).get()).single;
        expect(nachtZeile.tag, '2026-10-20');
        expect(
          nachtZeile.gelesenAm,
          DateTime.utc(2026, 10, 20, 9),
          reason:
              'der Stand überlebt die Migration — er wird nicht auf "jetzt" '
              'gesetzt. Ein erfundener Zeitstempel behauptete, die Zeile sei '
              'frisch',
        );

        final abschnitt = (await db.select(db.schlafAbschnitte).get()).single;
        expect(abschnitt.phase, 'core');
        expect(abschnitt.beginn, DateTime.utc(2026, 10, 19, 21));
        expect(abschnitt.ende, DateTime.utc(2026, 10, 20, 4, 30));
      },
    );

    test(
      'und die drei neuen Spalten bleiben leer — keine erfundenen Werte',
      () async {
        final db = AppCache(v7Cache());
        addTearDown(db.close);

        final zeile = (await db.select(db.naechte).get()).single;

        expect(
          zeile.ruhepulsBpm,
          isNull,
          reason:
              'für diese Nacht wurde nie ein Nachtwert gerechnet. Eine '
              'Migration, die hier etwas einträgt, behauptete eine Messung, '
              'die es nicht gab — und bei #193 wäre die Versuchung groß, den '
              'Tageswert aus `tages_werte` herüberzuschreiben. Genau der ist '
              'der falsche Wert, dessentwegen es dieses Ticket gibt',
        );
        expect(zeile.hrvMs, isNull);
        expect(zeile.respRate, isNull);

        // Schärfer als der Dart-Vergleich darüber: In der Datei steht
        // wirklich NULL. Ein `0.0` käme als 'real' heraus.
        expect(
          await speichertyp(db, 'ruhepuls_bpm', '2026-10-20'),
          'null',
          reason: 'NULL heißt hier "nie gerechnet", und das ist die Wahrheit',
        );
        expect(await speichertyp(db, 'hrv_ms', '2026-10-20'), 'null');
        expect(await speichertyp(db, 'resp_rate', '2026-10-20'), 'null');
      },
    );

    test('und `tages_werte` behält seine gleichnamigen Spalten — die '
        'Tageswerte sind davon unberührt', () async {
      final db = AppCache(v7Cache());
      addTearDown(db.close);

      final zeile = (await db.select(db.tagesWerte).get()).single;

      expect(zeile.schritte, 8042);
      expect(zeile.ruhepulsBpm, 51);
      expect(
        zeile.hrvMs,
        38.4,
        reason:
            '`hrv_ms` gibt es jetzt zweimal, in `tages_werte` und in '
            '`naechte`. Die neue Spalte ist eine zusätzliche, keine '
            'verschobene — solange Stufe 4 nicht umgestellt hat, rechnet '
            'der Schirm weiter mit der alten',
      );
      expect(zeile.respRate, 15.1);
      expect(zeile.recoveryHrDrop, 27);
      expect(zeile.gelesenAm, DateTime.utc(2026, 10, 20, 9));
    });

    test(
      'der übrige Bestand des Geräts übersteht die Migration ebenfalls',
      () async {
        final db = AppCache(v7Cache());
        addTearDown(db.close);

        final ziele = (await db.select(db.zielWerte).get()).single;
        expect(
          ziele.wochenzielTrainingsminuten,
          300,
          reason:
              'Tims eingestellte Ziele fallen nicht auf die Vorbelegung '
              'zurück — das sähe für ihn aus wie "meine Einstellungen sind '
              'weg"',
        );

        final eintrag = (await db.select(db.schlafEintraege).get()).single;
        expect(eintrag.schlafMinuten, 415);
        expect(
          eintrag.notiz,
          'Uhr vergessen',
          reason:
              'hinter dieser Zeile steht kein Lauf aus Apple Health, sondern '
              'Tim. Sie ist die einzige Kopie — eine Migration, die sie '
              'anfasst, ist nicht zu heilen',
        );
      },
    );

    test('und die neuen Spalten sind danach wirklich benutzbar — ein Lauf '
        'schreibt in die migrierte Zeile', () async {
      final db = AppCache(v7Cache());
      addTearDown(db.close);
      final repo = CacheRepository(db);

      await repo.schreibeNachtWerte(const {
        '2026-10-20': NightVitals(
          restingHeartRate: 48.6,
          hrv: 41.5,
          respiratoryRate: 14.2,
        ),
      }, gelesenAm: DateTime.utc(2026, 10, 21, 7));

      final gelesen = (await repo.liesNachtWerte(DataWindow.unlimited))!;
      expect(
        gelesen.werte['2026-10-20'],
        const NightVitals(
          restingHeartRate: 48.6,
          hrv: 41.5,
          respiratoryRate: 14.2,
        ),
      );
      expect(gelesen.stand, DateTime.utc(2026, 10, 21, 7));
    });
  });

  group('Durchlauf von unten — ältere Stände holen alles nach', () {
    test('ein Gerät auf v6 holt beide ausstehenden Stufen nach', () async {
      final db = AppCache(altstand(v6Schema, bestand, 6));
      addTearDown(db.close);

      await db.select(db.naechte).get();

      expect(await abgelegteVersion(db), db.schemaVersion);

      final tag = (await db.select(db.tagesWerte).get()).single;
      expect(
        tag.gewichtKg,
        isNull,
        reason:
            'die v7-Stufe läuft hier mit — ein Gerät, das zwischen #131 '
            'und #193 nicht aktualisiert wurde, darf keine Stufe '
            'überspringen',
      );
      expect(tag.trainingsMinuten, isNull);

      final nachtZeile = (await db.select(db.naechte).get()).single;
      expect(nachtZeile.ruhepulsBpm, isNull);
      expect(nachtZeile.hrvMs, isNull);
      expect(nachtZeile.respRate, isNull);
      expect(
        nachtZeile.gelesenAm,
        DateTime.utc(2026, 10, 20, 9),
        reason: 'über zwei Stufen hinweg bleibt der Stand der Nacht stehen',
      );
    });

    test('ein Gerät auf v1 kommt an, behält seine Werte, und jede seither '
        'dazugekommene Spalte ist leer', () async {
      final db = AppCache(altstand(v1Schema, v1Bestand, 1));
      addTearDown(db.close);

      await db.select(db.tagesWerte).get();

      expect(await abgelegteVersion(db), db.schemaVersion);

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
    });

    test('und alle seither angelegten Tabellen sind da und leer — die '
        'Nächte-Tabelle bringt keine Platzhalterzeile mit', () async {
      final db = AppCache(altstand(v1Schema, v1Bestand, 1));
      addTearDown(db.close);

      expect(
        await db.select(db.naechte).get(),
        isEmpty,
        reason:
            'eine angelegte Nacht ohne Messung wäre eine Nacht mit 0 '
            'Minuten Schlaf und 0 bpm Ruhepuls — die Migration legt keine '
            'Zeile an, sie legt eine Tabelle an',
      );
      expect(await db.select(db.schlafAbschnitte).get(), isEmpty);
      expect(await db.select(db.zielWerte).get(), isEmpty);
      expect(await db.select(db.schlafEintraege).get(), isEmpty);
    });
  });

  group('Ein Gerät, das schon auf v8 steht', () {
    test('wird nicht noch einmal migriert — ein zweites ALTER TABLE auf '
        'eine bestehende Spalte schlüge fehl', () async {
      final db = AppCache(
        altstand(
          '''
            $v7Schema
            ALTER TABLE naechte ADD COLUMN ruhepuls_bpm REAL;
            ALTER TABLE naechte ADD COLUMN hrv_ms REAL;
            ALTER TABLE naechte ADD COLUMN resp_rate REAL;
            ''',
          bestand,
          8,
        ),
      );
      addTearDown(db.close);

      // Liefe `onUpgrade` hier erneut, würfe schon dieser erste Zugriff
      // (`duplicate column name: ruhepuls_bpm`) — ein eigener
      // Ausnahme-Matcher braucht es dafür nicht.
      final zeile = (await db.select(db.naechte).get()).single;
      expect(zeile.tag, '2026-10-20');
      expect(zeile.ruhepulsBpm, isNull);
      expect(zeile.hrvMs, isNull);
      expect(zeile.respRate, isNull);
    });
  });
}
