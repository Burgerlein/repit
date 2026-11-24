// `drift` exportiert ein eigenes `isNull` (Spaltenausdruck für `IS NULL` in
// Abfragen) — das verdeckt sonst den gleichnamigen `package:matcher`-Matcher,
// den `expect(..., isNull)` unten braucht. Dieselbe Begründung wie in
// `test/data/migration_test.dart`, Zeile 1–4.
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show Database;
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/data/cache_repository.dart';
import 'package:repit/data/tables.dart';
import 'package:repit/health/health_types.dart';

/// Tests für **Schema v7** (#194, Abschnitt 2 von
/// `docs/superpowers/specs/2026-10-31-194-tageswechsel-und-cachespalten.md`)
/// — zwei neue Spalten in `TagesWerte` und die Migration dorthin.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden.
///
/// ## Nachtrag vom 02.11.2026 — die Stufe heißt v7, nicht v6
///
/// Die Spec schrieb v6. Zur selben Zeit hob ein zweiter Zweig (#131,
/// `schlaf_eintraege`) die Version ebenfalls auf 6, und der war beim
/// Zusammenführen schon auf Tims Gerät: Dort steht `user_version = 6` für
/// „die Tabelle der eingetragenen Nächte ist angelegt", mit seinen
/// Einträgen darin. Bekäme #131 die 7 und #194 die 6, liefe die Stufe
/// `from < 6` auf diesem Gerät nie und die beiden Spalten kämen dort nie
/// an — stumm, denn `createTable` schreibt `CREATE TABLE IF NOT EXISTS`.
/// Darum trägt #131 die 6 und #194 die 7; der Inhalt dieser Datei ist
/// derselbe
/// geblieben, nur eine Stufe höher gehängt. Die Umnummerierung hat nicht
/// der Test-Agent gemacht, sondern das Zusammenführen — ausdrücklich mit
/// `TEST_AENDERN=1`, und begründet in der Commit-Nachricht.
///
/// ## Warum es diese beiden Spalten gibt
///
/// Tims Beobachtung in #194: „Werte verschwinden nach einer Zeit wieder."
/// Einzelne, nicht alle. Für Gewicht und Trainingsminuten ist die Ursache
/// belegt: `TagesWerte` hat Spalten für fünf der dreizehn Kennzahlen,
/// `weightKg` und `exerciseMinutes` sind nicht dabei. Beide kommen aus dem
/// Cache deshalb **immer** `null` zurück — nach jedem Kaltstart stehen
/// Gewichtskachel und Trainingsring erst leer da, bis HealthKit antwortet.
/// Das ist derselbe Fehler, gegen den der Cache gebaut wurde: Ladezustand
/// als Leerstand.
///
/// ## API, die diese Tests verbindlich vorgeben
///
/// In `lib/data/tables.dart`, zusätzlich zu den bestehenden fünf
/// Metrikspalten von `TagesWerte` — **beide nullbar**, denn ein fehlender
/// Messwert ist nicht `0` (Global Constraint, `migration_test.dart`):
///
/// ```dart
/// RealColumn get gewichtKg => real().named('gewicht_kg').nullable()();
/// RealColumn get trainingsMinuten =>
///     real().named('trainings_minuten').nullable()();
/// ```
///
/// Die Dart-Namen (`gewichtKg`, `trainingsMinuten`) und die SQL-Namen
/// (`gewicht_kg`, `trainings_minuten`) stehen so in der Spec; die Tests
/// unten greifen auf beide zu und legen sie damit fest. Deutsche Feldnamen
/// im Stil der Nachbarn (`schritte`, `ruhepulsBpm`) — die Tabellen sind
/// durchgängig deutsch benannt, eine englische Spalte dazwischen wäre der
/// Bruch.
///
/// **`RealColumn` für beide, auch für die Minuten.** `DailyMetrics`
/// (`health_types.dart`) trägt `exerciseMinutes` als `double?`, nicht als
/// `int?`. Eine `IntColumn` zwänge die Brücke zu runden, und gerundete
/// Minuten sind eine stille Veränderung von Tims Daten auf dem Weg in den
/// Cache.
///
/// Daraus folgt `AppCache.schemaVersion == 7` (geprüft in
/// `migration_test.dart`, Pflichtfall 1, im selben Zug angepasst) und eine
/// **eigene, additive Stufe** `if (from < 7) { … }` — keine Erweiterung der
/// v6-Stufe. Begründung wie bei v3/v4/v5 (`schema_v3_test.dart`,
/// Dateikopf): Ein Gerät, das zwischen zwei Tickets aktualisiert wurde,
/// muss den Rest nachholen können.
///
/// In `lib/data/cache_repository.dart` ändert sich **keine Signatur**, nur
/// das Verhalten: `schreibeTagesWerte` schreibt beide Werte mit,
/// `liesTagesWerte` gibt sie zurück. Die geerbte Schemagrenze für die
/// übrigen Felder bleibt bestehen — sie schrumpft von acht auf sechs
/// (`activeKcal`, `basalKcal`, `vo2max`, `bodyFatPct`, `leanKg`,
/// `standHours`), siehe `cache_repository_test.dart`, Gruppe „Geerbte
/// Schemagrenze".
///
/// ## Was absichtlich nicht geprüft wird
///
/// - **Der Weg über `drift_dev schema dump`/`SchemaVerifier`.** Dieselbe
///   Begründung wie in `migration_test.dart` und `schema_v3_test.dart`: Es
///   gibt keine eingefrorenen Schema-Dumps unter `drift_schemas/`, und eine
///   Testdatei, die der Implementierung vorausgeht, kann sie nicht anlegen.
///   Die Altschemata unten sind deshalb **von Hand** gebaut — ein Schema,
///   das aus dem heutigen Code erzeugt wird, ist kein Altschema, sondern
///   das neue, und bewiese nichts.
/// - **Der Rückfall auf den jüngsten vorhandenen Wert** (#194, Punkt 1).
///   Laut Spec ausdrücklich nicht Gegenstand: eine Entwurfsfrage, die erst
///   übers Board geht. Ein Test darauf schriebe hier eine Entscheidung
///   fest, die niemand getroffen hat.
/// - **Die übrigen sechs Felder ohne Spalte.** Sie bleiben `null`, und das
///   hält weiterhin `cache_repository_test.dart` fest, nicht diese Datei.
///
/// **Alle Zahlen hier sind erfunden** — keine echten Gesundheitswerte.
void main() {
  /// `gelesen_am`, `beginn` und `ende` liegen als ISO-Text mit `Z` vor, weil
  /// `AppCache` mit `storeDateTimeAsText: true` arbeitet (`cache.dart`) —
  /// genau das Format, das drift beim Schreiben eines UTC-`DateTime`
  /// erzeugt. Driftets Standard (Unix-Sekunden) gäbe sie als Ortszeit
  /// zurück, und ein als UTC abgelegter Wert wäre dann ungleich sich
  /// selbst.
  const v5Schema = '''
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
  ''';

  /// Schema v6 — v5 plus `schlaf_eintraege` (#131), die von Hand
  /// eingetragenen Nächte und Tagschläfe. **Das ist der Stand, der beim
  /// Zusammenführen auf Tims iPhone lag**, und deshalb der Altstand, der
  /// hier zählt: Die Migration auf v7 muss ihn antreffen, ergänzen und
  /// nichts davon anfassen.
  const v6Schema =
      '''
    $v5Schema
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
  /// zusätzlichen Tabelle. Derselbe Stand wie in `migration_test.dart`,
  /// hier um die beiden anderen v1-Tabellen ergänzt, damit ein Lauf von
  /// ganz unten ein vollständiges Altgerät nachstellt und nicht nur eine
  /// Tabelle davon.
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

  /// Der Bestand eines v6-Geräts: ein Tag mit allen fünf Messwerten und dem
  /// Stand seines Laufs, eine Nacht mit einem Abschnitt, Tims eingestellte
  /// Ziele, ein eingetragenes Tagesgefühl — und die von Hand eingetragene
  /// Nacht aus #131. Alles, was die Migration auf v7 unangetastet lassen
  /// muss.
  ///
  /// **Die eingetragene Nacht ist der Grund für die ganze Numerierung.**
  /// Sie steht nur hier, in keiner Apple-Health-Quelle; geht sie verloren,
  /// ist sie weg. Ein Migrationsschritt, der sie zweimal anlegt oder die
  /// Tabelle noch einmal erzeugt, scheitert an genau diesem Fall.
  const v6Bestand = '''
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

  group('Schema v7 — zwei neue Spalten in TagesWerte (#194)', () {
    test('Gewicht und Trainingsminuten lassen sich schreiben und kommen '
        'unverändert zurück', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      await db
          .into(db.tagesWerte)
          .insert(
            TagesWerteCompanion.insert(
              tag: '2026-10-20',
              gewichtKg: const Value(81.4),
              trainingsMinuten: const Value(47.5),
            ),
          );

      final zeile = await (db.select(
        db.tagesWerte,
      )..where((t) => t.tag.equals('2026-10-20'))).getSingle();

      expect(zeile.gewichtKg, 81.4);
      expect(
        zeile.trainingsMinuten,
        47.5,
        reason:
            'die Minuten kommen als Kommazahl herein (DailyMetrics.'
            'exerciseMinutes ist double?) und müssen als Kommazahl wieder '
            'heraus — eine Ganzzahlspalte rundete Tims Wert still',
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
              // gewichtKg und trainingsMinuten absichtlich nicht gesetzt:
              // An einem Tag ohne Waage und ohne Training gibt es diese
              // Werte schlicht nicht.
            ),
          );

      final zeile = await (db.select(
        db.tagesWerte,
      )..where((t) => t.tag.equals('2026-10-20'))).getSingle();

      expect(zeile.schritte, 5000);
      expect(
        zeile.gewichtKg,
        isNull,
        reason:
            'nicht gewogen ist nicht "0 kg" — eine Kachel, die 0 zeigt, '
            'behauptet eine Messung, die es nicht gab',
      );
      expect(
        zeile.trainingsMinuten,
        isNull,
        reason:
            'kein Wert ist nicht "0 Minuten trainiert". Ein Ring auf 0 '
            'sagt "nichts getan", und das ist Fehler 01 in neuer '
            'Verpackung (CLAUDE.md)',
      );
    });
  });

  group('CacheRepository reicht beide Werte durch (#194, Rundweg)', () {
    test('Gewicht und Trainingsminuten kommen nach dem Zurückschreiben wieder '
        'aus dem Cache — vorher waren sie immer null', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = CacheRepository(db);
      final geholt = DateTime.utc(2026, 10, 20, 14, 32);

      await repo.schreibeTagesWerte(const [
        DailyMetrics(
          tag: '2026-10-20',
          steps: 8042,
          restingHR: 51,
          weightKg: 81.4,
          exerciseMinutes: 47.5,
        ),
      ], gelesenAm: geholt);

      final zeile = (await repo.liesTagesWerte(DataWindow.unlimited))!
          .werte
          .single;

      expect(zeile.steps, 8042);
      expect(zeile.restingHR, 51);
      expect(
        zeile.weightKg,
        81.4,
        reason:
            'genau der Wert, den die Gewichtskachel braucht. Käme er '
            'weiter als null zurück, stünde sie nach jedem Kaltstart '
            'zuerst leer da — #194',
      );
      expect(
        zeile.exerciseMinutes,
        47.5,
        reason: 'dasselbe für den Trainingsring',
      );
    });

    test('ein Tag ohne Gewicht bleibt auch dann null, wenn der Nachbartag im '
        'selben Lauf einen Wert hat', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = CacheRepository(db);

      await repo.schreibeTagesWerte(const [
        DailyMetrics(tag: '2026-10-19', steps: 7000),
        DailyMetrics(
          tag: '2026-10-20',
          steps: 8000,
          weightKg: 81.4,
          exerciseMinutes: 47.5,
        ),
      ], gelesenAm: DateTime.utc(2026, 10, 20, 14, 32));

      final werte = (await repo.liesTagesWerte(DataWindow.unlimited))!.werte;

      expect(werte.map((w) => w.tag).toList(), ['2026-10-19', '2026-10-20']);
      expect(
        werte.first.weightKg,
        isNull,
        reason:
            'am 19. stand Tim nicht auf der Waage — kein Übernehmen vom '
            'Nachbartag, kein 0. Der Rückfall auf den jüngsten '
            'vorhandenen Wert ist #194 Punkt 1 und ausdrücklich nicht '
            'Gegenstand dieses Tickets',
      );
      expect(werte.first.exerciseMinutes, isNull);
      expect(werte.last.weightKg, 81.4);
      expect(werte.last.exerciseMinutes, 47.5);
    });
  });

  group('Migration v6 → v7 — ergänzt, verwirft nicht', () {
    QueryExecutor v6Cache() => altstand(v6Schema, v6Bestand, 6);

    test(
      'die Datenbank steht danach auf dem Stand, den der Code behauptet',
      () async {
        final db = AppCache(v6Cache());
        addTearDown(db.close);

        // Ein Zugriff zuerst: Das Öffnen selbst ist bei drift lazy, die
        // Migration läuft erst bei der ersten Abfrage.
        await db.select(db.tagesWerte).get();

        expect(
          await abgelegteVersion(db),
          db.schemaVersion,
          reason:
              'die Stufe für #194 ist eine eigene (`if (from < 7)`), keine '
              'Erweiterung der v6-Stufe — sonst gäbe es Geräte mit "v6, aber '
              'schon mit Gewichtsspalte", und die wären von außen nicht mehr '
              'unterscheidbar. Geprüft wird gegen `schemaVersion` und nicht '
              'gegen die Zahl 7: Dass die Stufe gelaufen ist, zeigen die '
              'Spaltenprüfungen unten; dass die Datei danach auf dem Stand '
              'des Codes steht, zeigt diese Zeile. Die **absolute** Zahl '
              'nennt nur `migration_test.dart` (#208 — sie stand vorher auch '
              'hier, und jede neue Stufe ließ diesen Fall mitfallen, obwohl '
              'er von v7 handelt)',
        );
      },
    );

    test(
      'die Zeile aus Schema v6 behält alle ihre Werte und ihren Stand',
      () async {
        final db = AppCache(v6Cache());
        addTearDown(db.close);

        final zeile = (await db.select(db.tagesWerte).get()).single;

        expect(zeile.tag, '2026-10-20');
        expect(zeile.schritte, 8042);
        expect(zeile.ruhepulsBpm, 51);
        expect(zeile.hrvMs, 38.4);
        expect(zeile.respRate, 15.1);
        expect(zeile.recoveryHrDrop, 27);
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
        final db = AppCache(v6Cache());
        addTearDown(db.close);

        final zeile = (await db.select(db.tagesWerte).get()).single;

        expect(
          zeile.gewichtKg,
          isNull,
          reason:
              'für diese Zeile wurde nie ein Gewicht geholt. Eine '
              'Migration, die hier einen Wert einträgt, behauptete eine '
              'Messung, die es nicht gab — derselbe Fehler wie ein '
              'erfundener Zeitstempel, nur eine Spalte weiter',
        );
        expect(zeile.trainingsMinuten, isNull);

        // Schärfer als der Dart-Vergleich darüber: In der Datei steht
        // wirklich NULL. Ein `0.0` käme als 'real' heraus, ein
        // zurückgeschriebener Zeitstempel als 'real' oder 'text'.
        expect(
          await speichertyp(db, 'gewicht_kg', '2026-10-20'),
          'null',
          reason:
              'NULL heißt hier "nie gemessen", und das ist die Wahrheit. '
              'Kein Rückschreiben (Spec #194, Abschnitt 2)',
        );
        expect(
          await speichertyp(db, 'trainings_minuten', '2026-10-20'),
          'null',
        );
      },
    );

    test(
      'der übrige Bestand des Geräts übersteht die Migration ebenfalls',
      () async {
        final db = AppCache(v6Cache());
        addTearDown(db.close);

        expect((await db.select(db.naechte).get()).single.tag, '2026-10-20');
        final abschnitt = (await db.select(db.schlafAbschnitte).get()).single;
        expect(abschnitt.phase, 'core');
        expect(abschnitt.beginn, DateTime.utc(2026, 10, 19, 21));
        expect(abschnitt.ende, DateTime.utc(2026, 10, 20, 4, 30));

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

    test('und Tims von Hand eingetragene Nacht steht danach unverändert da — '
        'nicht verdoppelt, nicht verworfen', () async {
      final db = AppCache(v6Cache());
      addTearDown(db.close);

      final eintrag = (await db.select(db.schlafEintraege).get()).single;
      expect(eintrag.tag, '2026-10-20');
      expect(eintrag.art, 'nacht');
      expect(eintrag.schlafMinuten, 415);
      expect(eintrag.beginnMinuten, 1385);
      expect(eintrag.endeMinuten, 380);
      expect(
        eintrag.notiz,
        'Uhr vergessen',
        reason:
            'hinter dieser Zeile steht kein Lauf aus Apple Health, sondern '
            'Tim. Sie ist die einzige Kopie — eine Migration, die sie '
            'anfasst, ist nicht zu heilen (CLAUDE.md, „Die eingefrorene '
            'Swift-App" sinngemäß: es geht um Tims einzige Datenkopie)',
      );
    });

    test('und die neuen Spalten sind danach wirklich benutzbar — ein Lauf '
        'schreibt in die migrierte Zeile', () async {
      final db = AppCache(v6Cache());
      addTearDown(db.close);
      final repo = CacheRepository(db);

      await repo.schreibeTagesWerte(const [
        DailyMetrics(
          tag: '2026-10-20',
          steps: 8042,
          weightKg: 81.4,
          exerciseMinutes: 47.5,
        ),
      ], gelesenAm: DateTime.utc(2026, 10, 21, 7));

      final zeile = (await repo.liesTagesWerte(DataWindow.unlimited))!
          .werte
          .single;
      expect(zeile.weightKg, 81.4);
      expect(zeile.exerciseMinutes, 47.5);
    });
  });

  group('Durchlauf von unten — ein Gerät auf Schema v1 holt alles nach', () {
    QueryExecutor v1Cache() => altstand(v1Schema, v1Bestand, 1);

    test('alle Stufen laufen durch, die Datei steht danach auf dem Stand des '
        'Codes', () async {
      final db = AppCache(v1Cache());
      addTearDown(db.close);

      await db.select(db.tagesWerte).get();

      expect(
        await abgelegteVersion(db),
        db.schemaVersion,
        reason:
            'dass die v7-Stufe dabei war, zeigen die beiden Fälle '
            'darunter — hier geht es darum, dass ein Gerät von ganz '
            'unten überhaupt ankommt und sein Ergebnis festschreibt',
      );
    });

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
      expect(
        await speichertyp(db, 'gewicht_kg', '2026-10-20'),
        'null',
        reason:
            'auch über sechs Stufen hinweg bleibt die neue Spalte wirklich '
            'leer — kein 0, kein Zeitstempel',
      );
      expect(await speichertyp(db, 'trainings_minuten', '2026-10-20'), 'null');
    });

    test('und alle seither angelegten Tabellen sind da und leer — nicht mit '
        'Platzhalterzeilen gefüllt', () async {
      final db = AppCache(v1Cache());
      addTearDown(db.close);

      expect(await db.select(db.naechte).get(), isEmpty);
      expect(await db.select(db.schlafAbschnitte).get(), isEmpty);
      expect(await db.select(db.zielWerte).get(), isEmpty);
      expect(await db.select(db.schlafEintraege).get(), isEmpty);
      expect(await db.select(db.stundenSchritte).get(), isEmpty);
      expect(await db.select(db.eigeneDaten).get(), isEmpty);
    });
  });

  group('Ein Gerät, das schon auf v7 steht', () {
    test('wird nicht noch einmal migriert — ein zweites ALTER TABLE auf eine '
        'bestehende Spalte schlüge fehl', () async {
      final db = AppCache(
        altstand(
          '''
            $v6Schema
            ALTER TABLE tages_werte ADD COLUMN gewicht_kg REAL;
            ALTER TABLE tages_werte ADD COLUMN trainings_minuten REAL;
            ''',
          v6Bestand,
          7,
        ),
      );
      addTearDown(db.close);

      // Liefe `onUpgrade` hier erneut, würfe schon dieser erste Zugriff
      // (`duplicate column name: gewicht_kg`) — ein eigener
      // Ausnahme-Matcher braucht es dafür nicht.
      final zeile = (await db.select(db.tagesWerte).get()).single;
      expect(zeile.hrvMs, 38.4);
      expect(zeile.gewichtKg, isNull);
      expect(zeile.trainingsMinuten, isNull);
    });
  });
}
