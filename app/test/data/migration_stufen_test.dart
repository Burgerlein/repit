// `drift` exportiert ein eigenes `isNull` (Spaltenausdruck für `IS NULL` in
// Abfragen) — das verdeckt sonst den gleichnamigen `package:matcher`-Matcher.
// Dieselbe Begründung wie in `test/data/migration_test.dart`, Zeile 1–4.
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show Database;

import 'package:repit/data/cache.dart';
import 'package:repit/data/ziele.dart';

/// Tests für die **mittleren Migrationsstufen** — Nachtrag zu
/// `migration_test.dart` und `schema_v3_test.dart` nach einem Review-Befund
/// vom 27.10.2026 (Befund E).
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden.
///
/// ## Die Lücke
///
/// `lib/data/cache.dart` behandelte zur Zeit dieses Befunds vier Stufen
/// (`from < 2`, `< 3`, `< 4`, `< 5`). Geprüft wurde bisher nur ein Start
/// bei `user_version = 1`
/// (`migration_test.dart`) und bei `= 2` (`schema_v3_test.dart`) — beide
/// laufen also durch **alle** Stufen. Ein Start bei 3 oder 4 kam in keinem
/// Test vor.
///
/// Das ist ausgerechnet der Fall, für den es drei Versionen statt einer
/// gibt. `schema_v3_test.dart` begründet die Aufteilung wörtlich damit: „Ein
/// Gerät, das zwischen zwei dieser Tickets aktualisiert wurde, muss den Rest
/// nachholen können." Genau dieses Gerät war der einzige ungeprüfte Fall.
/// `CLAUDE.md`: „Jede Migration bekommt einen Test, so wie jede Formel einen
/// bekommt."
///
/// ## Keine API-Änderung
///
/// Diese Datei verlangt nichts Neues. Sie hält fest, was `cache.dart` schon
/// behauptet, und schließt die Lücke, durch die eine falsch gezählte Stufe
/// unbemerkt bliebe — etwa ein `if (from == 4)` statt `if (from < 5)`, oder
/// eine Stufe, die beim Aufräumen in eine andere hineinrutscht.
///
/// Die Altschemata unten sind **von Hand** gebaut, so wie es
/// `migration_test.dart` und `schema_v3_test.dart` vormachen: Ein Schema,
/// das aus dem heutigen Code erzeugt wird, ist kein Altschema, sondern das
/// neue — und bewiese nichts.
///
/// **Alle Zahlen hier sind erfunden.**
void main() {
  /// Die drei Tabellen, die seit Schema v1 unverändert sind, plus die
  /// `gelesen_am`-Spalte aus v2. `gelesen_am`, `beginn` und `ende` liegen
  /// als ISO-Text mit `Z` vor, weil `AppCache` mit
  /// `storeDateTimeAsText: true` arbeitet.
  const grundtabellen = '''
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
  ''';

  /// Die Zieltabelle aus v4 (#111).
  const zieltabelle = '''
    CREATE TABLE ziel_werte (
      id INTEGER NOT NULL DEFAULT 0,
      schlafziel_minuten INTEGER NOT NULL,
      schlafenszeit_minuten INTEGER NOT NULL,
      wochenziel_trainingsminuten INTEGER NOT NULL,
      PRIMARY KEY (id)
    );
  ''';

  /// Die Daten, die auf jedem dieser Altstände schon liegen — ein Tag mit
  /// Erholungswerten und eine Nacht mit einem Abschnitt.
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
  ''';

  /// Ohne `PRAGMA user_version` meldet SQLite Version 0, drift riefe
  /// `onCreate` statt `onUpgrade` auf, und der Migrationspfad bliebe
  /// ungeprüft — in `migration_test.dart` ausführlich begründet.
  QueryExecutor altstand(String schema, int version) => NativeDatabase.memory(
    setup: (Database roh) {
      roh.execute(schema);
      roh.execute(bestand);
      roh.execute('PRAGMA user_version = $version;');
    },
  );

  group(
    'Ein Gerät, das auf Schema v3 stehengeblieben ist (#113 installiert, '
    '#111 nicht)',
    () {
      QueryExecutor v3Cache() => altstand(grundtabellen, 3);

      test('holt die fehlende Zieltabelle nach, und sie ist leer', () async {
        final db = AppCache(altstand(grundtabellen, 3));
        addTearDown(db.close);

        expect(
          await db.select(db.zielWerte).get(),
          isEmpty,
          reason:
              '#111 — leer heißt: Tim hat noch nichts eingestellt. Die '
              'Vorbelegung steht in Dart, nicht als Zeile in der Datenbank',
        );
      });

      test(
        'und verliert dabei nichts von dem, was schon dalag',
        () async {
          final db = AppCache(v3Cache());
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
                'der Stand überlebt die Migration — er wird nicht auf '
                '"jetzt" gesetzt. Ein erfundener Zeitstempel behauptete, '
                'die Zeile sei frisch',
          );

          expect((await db.select(db.naechte).get()).single.tag, '2026-10-20');
          final abschnitt = (await db.select(db.schlafAbschnitte).get()).single;
          expect(abschnitt.phase, 'core');
          expect(abschnitt.beginn, DateTime.utc(2026, 10, 19, 21));
          expect(abschnitt.ende, DateTime.utc(2026, 10, 20, 4, 30));
        },
      );

      test(
        'und die nachgeholte Tabelle ist danach wirklich benutzbar',
        () async {
          final db = AppCache(v3Cache());
          addTearDown(db.close);

          await ZieleRepository(db).schreibe(
            Ziele.vorbelegung.kopieMit(wochenzielTrainingsminuten: 300),
          );

          expect(
            (await ZieleRepository(db).lies()).wochenzielTrainingsminuten,
            300,
          );
        },
      );
    },
  );

  group(
    'Ein Gerät, das auf Schema v4 stehengeblieben ist (#111 installiert)',
    () {
      QueryExecutor v4Cache() => NativeDatabase.memory(
        setup: (Database roh) {
          roh.execute(grundtabellen);
          roh.execute(zieltabelle);
          roh.execute(bestand);
          // Tim hat seine Ziele bereits eingestellt — genau das, was eine
          // Migration ihm nicht wegnehmen darf.
          roh.execute(
            'INSERT INTO ziel_werte (id, schlafziel_minuten, '
            'schlafenszeit_minuten, wochenziel_trainingsminuten) '
            'VALUES (0, 450, 1290, 300);',
          );
          roh.execute('PRAGMA user_version = 4;');
        },
      );

      test(
        'und Tims eingestellte Ziele überleben — sie fallen nicht auf die '
        'Vorbelegung zurück',
        () async {
          final db = AppCache(v4Cache());
          addTearDown(db.close);

          final ziele = await ZieleRepository(db).lies();

          expect(ziele.schlafzielMinuten, 450);
          expect(ziele.schlafenszeitMinuten, 1290);
          expect(ziele.wochenzielTrainingsminuten, 300);
          expect(
            ziele,
            isNot(Ziele.vorbelegung),
            reason:
                'eine Migration, die die Zieltabelle neu anlegt statt sie '
                'stehenzulassen, sähe für Tim aus wie "meine Einstellungen '
                'sind weg" — und die Vorbelegung behauptete, er habe nie '
                'etwas eingestellt',
          );
          expect(
            (await db.select(db.zielWerte).get()),
            hasLength(1),
            reason: 'und es bleibt bei genau einer Zeile',
          );
        },
      );

      test('die übrigen Daten bleiben ebenfalls unangetastet', () async {
        final db = AppCache(v4Cache());
        addTearDown(db.close);

        final zeile = (await db.select(db.tagesWerte).get()).single;
        expect(zeile.hrvMs, 38.4);
        expect(zeile.gelesenAm, DateTime.utc(2026, 10, 20, 9));
        expect(await db.select(db.schlafAbschnitte).get(), hasLength(1));
      });
    },
  );

  group('Ein Gerät, das schon auf v5 steht', () {
    test(
      'läuft die v5-Stufe nicht noch einmal — ein zweites CREATE TABLE auf '
      'eine bestehende Tabelle schlüge fehl; die v10-Stufe räumt sie danach '
      'weg (#269)',
      () async {
        final db = AppCache(
          NativeDatabase.memory(
            setup: (Database roh) {
              roh.execute(grundtabellen);
              roh.execute(zieltabelle);
              roh.execute('''
                CREATE TABLE tagesgefuehle (
                  tag TEXT NOT NULL PRIMARY KEY,
                  wert INTEGER NOT NULL
                );
              ''');
              roh.execute(bestand);
              roh.execute(
                "INSERT INTO tagesgefuehle (tag, wert) "
                "VALUES ('2026-10-20', 4);",
              );
              roh.execute('PRAGMA user_version = 5;');
            },
          ),
        );
        addTearDown(db.close);

        expect(
          (await db.select(db.tagesWerte).get()).single.hrvMs,
          38.4,
          reason:
              'die Stufen zwischen 5 und 10 lassen den Bestand in Ruhe — '
              'auch die eine, die etwas löscht',
        );

        final tabellen = await db
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'table' "
              "AND name = 'tagesgefuehle';",
            )
            .get();
        expect(
          tabellen,
          isEmpty,
          reason:
              'bis zum 03.11.2026 stand hier, dass Tims Tagesgefühl die '
              'Migration überlebt. Seit #269 ist das Gegenteil die '
              'Anforderung: Tim hat das Mitlöschen entschieden und weiß, '
              'dass seine Einträge damit endgültig weg sind',
        );
      },
    );
  });
}
