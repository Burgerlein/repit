// `drift` exportiert ein eigenes `isNull` (Spaltenausdruck für `IS NULL` in
// Abfragen) — das kollidiert mit `package:matcher`s `isNull`-Matcher, den
// `expect(..., isNull)` unten braucht. Dieselbe Begründung wie in
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

/// Tests für **Schema v3** (#113) und die Migration von einem bestehenden
/// Cache auf den heutigen Stand.
///
/// **Warum es diese Spalten gibt — Tims Entscheidung vom 27.10.2026**
/// (`docs/superpowers/specs/2026-10-26-erholung-flutter-design.md`,
/// Abschnitt 10a Punkt 3, wörtlich): „Der Cache bekommt Schema v3. Drei
/// Spalten in `TagesWerte` — HRV, Atemfrequenz und Puls-Erholung —, dazu die
/// Migration v2→v3 und ein Migrationstest. Ohne sie kommen genau die Werte,
/// die die Ampel braucht, aus dem Cache immer `null` zurück, und der Schirm
/// steht bei jedem Öffnen zuerst leer da. Das ist der Fehler, den der Umbau
/// abstellen soll: Ladezustand ist kein Leerstand."
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden.
///
/// ## Entscheidung dieser Testdatei: drei Versionen, nicht eine
///
/// Drei Tickets legen gleichzeitig etwas ab (#113, #111, #118). Sie bekommen
/// **je eine eigene Schemaversion**, nicht gemeinsam eine:
///
/// | Version | Ticket | Was dazukommt |
/// |---|---|---|
/// | v3 | #113 | `tages_werte.hrv_ms`, `.resp_rate`, `.recovery_hr_drop`; Tabellen `naechte`, `schlaf_abschnitte` |
/// | v4 | #111 | Tabelle `ziel_werte` |
/// | v5 | #118 | Tabelle `tagesgefuehle` — seit #269 (v10) wieder gelöscht |
///
/// Daraus folgt `AppCache.schemaVersion == 5` (geprüft in
/// `migration_test.dart`, Pflichtfall 1) und ein `onUpgrade`, das **jede**
/// Stufe einzeln behandelt (`if (from < 3) … if (from < 4) … if (from < 5)
/// …`), nicht eine Sammelstufe. Begründung: Ein Gerät, das zwischen zwei
/// dieser Tickets aktualisiert wurde, muss den Rest nachholen können — mit
/// einer einzigen Sammelversion gäbe es Geräte mit „v3, aber schon mit
/// Zieltabelle", und die wären von außen nicht mehr unterscheidbar. Spec 10a
/// nennt für #113 ausdrücklich die Zahl 3; die beiden folgenden Zahlen sind
/// die Fortsetzung derselben Zählung, keine zweite Erfindung.
///
/// **Nachtrag vom 03.11.2026 (#269).** Die v5-Stufe legt `tagesgefuehle`
/// weiterhin an — ein Gerät von v2 läuft durch sie hindurch —, aber die
/// v10-Stufe löscht die Tabelle danach wieder. Die Erwartung „nach der
/// Migration steht eine leere `tagesgefuehle` da" ist deshalb hier
/// entfallen; dass die v5-Stufe stehenbleibt, prüft
/// `schema_v10_test.dart` am Weg von v4 aus.
///
/// Welche Spalten **welchem** Ticket gehören, steht in der Tabelle oben;
/// die Tabellen `naechte`/`schlaf_abschnitte` haben ihre eigene Testdatei
/// (`test/data/schlaf_cache_test.dart`), `ziel_werte` ebenso
/// (`ziele_test.dart`). **Hier** wird nur
/// geprüft, dass die Migration sie anlegt und dabei nichts verwirft.
///
/// ## API, die diese Tests verbindlich vorgeben
///
/// In `lib/data/tables.dart`, zusätzlich zu den bestehenden drei Spalten von
/// `TagesWerte` — **alle drei nullbar**, denn ein fehlender Messwert ist
/// nicht `0` (Global Constraint, `migration_test.dart`):
///
/// ```dart
/// RealColumn get hrvMs => real().named('hrv_ms').nullable()();
/// RealColumn get respRate => real().named('resp_rate').nullable()();
/// IntColumn get recoveryHrDrop =>
///     integer().named('recovery_hr_drop').nullable()();
/// ```
///
/// Die Dart-Namen (`hrvMs`, `respRate`, `recoveryHrDrop`) sind durch die
/// Zugriffe unten festgelegt, die SQL-Namen durch das handgebaute v2-Schema
/// im Migrationstest. Sie entsprechen `DailyMetrics.hrvMs`, `.respRate` und
/// `.recoveryHRDrop` (`health_types.dart`) — `recoveryHrDrop` schreibt sich
/// in der Tabelle mit kleinem `r`, damit drifts Standard-Snake-Case und der
/// `.named(...)`-Wert dieselbe Form haben.
///
/// In `lib/data/cache_repository.dart` ändert sich **keine Signatur**, nur
/// das Verhalten: `schreibeTagesWerte` schreibt die drei Werte mit,
/// `liesTagesWerte` gibt sie zurück. Die geerbte Schemagrenze für die
/// übrigen Felder (`weightKg` & Co., siehe `cache_repository_test.dart`,
/// Gruppe „Geerbte Schemagrenze") bleibt bestehen — sie schrumpft nur um
/// diese drei.
///
/// ## Was absichtlich nicht geprüft wird
///
/// - **Der Weg über `drift_dev schema dump`/`SchemaVerifier`.** Dieselbe
///   Begründung wie in `migration_test.dart`: Es gibt keine eingefrorenen
///   Schema-Dumps unter `drift_schemas/`, und eine Testdatei, die der
///   Implementierung vorausgeht, kann sie nicht anlegen. Das v2-Schema wird
///   deshalb von Hand nachgebaut, genau wie dort das v1-Schema.
/// - **Ob `exerciseMinutes` eine Spalte bekommt.** Spec 10a nennt drei
///   Spalten, nicht vier. Die Trainingsminuten des Belastungs-Rings kommen
///   bis auf Weiteres ohne Cache aus; das ist eine bestehende Grenze, keine
///   Lücke dieses Tickets.
void main() {
  group('Schema v3 — drei neue Spalten in TagesWerte (#113, Spec 10a)', () {
    test(
      'HRV, Atemfrequenz und Puls-Erholung lassen sich schreiben und '
      'kommen unverändert zurück',
      () async {
        final db = AppCache(NativeDatabase.memory());
        addTearDown(db.close);

        await db
            .into(db.tagesWerte)
            .insert(
              TagesWerteCompanion.insert(
                tag: '2026-10-20',
                hrvMs: const Value(41.5),
                respRate: const Value(14.2),
                recoveryHrDrop: const Value(23),
              ),
            );

        final zeile =
            await (db.select(
              db.tagesWerte,
            )..where((t) => t.tag.equals('2026-10-20'))).getSingle();

        expect(zeile.hrvMs, 41.5);
        expect(zeile.respRate, 14.2);
        expect(zeile.recoveryHrDrop, 23);
      },
    );

    test(
      'jede der drei Spalten ist nullbar — ein nicht gelieferter Wert '
      'bleibt null, kommt nie als 0 zurück',
      () async {
        final db = AppCache(NativeDatabase.memory());
        addTearDown(db.close);

        await db
            .into(db.tagesWerte)
            .insert(
              TagesWerteCompanion.insert(
                tag: '2026-10-20',
                schritte: const Value(5000),
                // hrvMs, respRate und recoveryHrDrop absichtlich nicht
                // gesetzt: An einem Tag ohne Uhr am Handgelenk gibt es
                // diese Werte schlicht nicht.
              ),
            );

        final zeile =
            await (db.select(
              db.tagesWerte,
            )..where((t) => t.tag.equals('2026-10-20'))).getSingle();

        expect(zeile.schritte, 5000);
        expect(
          zeile.hrvMs,
          isNull,
          reason: 'keine Messung ist nicht "0 ms HRV" — das wäre ein '
              'Alarmwert, kein fehlender Wert',
        );
        expect(
          zeile.respRate,
          isNull,
          reason: 'keine Messung ist nicht "0 Atemzüge pro Minute"',
        );
        expect(
          zeile.recoveryHrDrop,
          isNull,
          reason: 'keine Messung ist nicht "der Puls fiel um 0 Schläge"',
        );
      },
    );
  });

  group(
    'Migration v2 → aktuell — ein bestehender Cache wird ergänzt, nicht '
    'verworfen (#113, #111, #118)',
    () {
      /// Handgebautes Schema v2, so wie drift es bis zum 26.10.2026 angelegt
      /// hat: `tages_werte` mit `gelesen_am`, dazu `stunden_schritte` und
      /// `eigene_daten`. `gelesen_am` liegt als ISO-Text mit `Z` vor, weil
      /// `AppCache` mit `storeDateTimeAsText: true` arbeitet (siehe
      /// `cache.dart`) — genau das Format, das drift beim Schreiben eines
      /// UTC-`DateTime` erzeugt.
      QueryExecutor v2Cache() => NativeDatabase.memory(
        setup: (Database roh) {
          roh.execute('''
            CREATE TABLE tages_werte (
              tag TEXT NOT NULL PRIMARY KEY,
              schritte INTEGER,
              ruhepuls_bpm INTEGER,
              gelesen_am TEXT
            );
          ''');
          roh.execute('''
            CREATE TABLE stunden_schritte (
              tag TEXT NOT NULL,
              stunde INTEGER NOT NULL,
              schritte INTEGER,
              PRIMARY KEY (tag, stunde)
            );
          ''');
          roh.execute('''
            CREATE TABLE eigene_daten (
              id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
              tag TEXT NOT NULL,
              inhalt TEXT NOT NULL
            );
          ''');
          roh.execute(
            "INSERT INTO tages_werte (tag, schritte, ruhepuls_bpm, gelesen_am) "
            "VALUES ('2026-10-20', 8042, 51, '2026-10-20T09:00:00.000Z');",
          );
          // Ohne dieses Pragma meldet SQLite Version 0, drift riefe
          // `onCreate` statt `onUpgrade` auf, und der Migrationspfad bliebe
          // ungeprüft — siehe `migration_test.dart`, dort ausführlich
          // begründet.
          roh.execute('PRAGMA user_version = 2;');
        },
      );

      test(
        'die Zeile aus Schema v2 behält ihre Werte und ihren Stand, und '
        'die drei neuen Spalten bleiben leer — keine erfundenen Zahlen',
        () async {
          final db = AppCache(v2Cache());
          addTearDown(db.close);

          final zeile = (await db.select(db.tagesWerte).get()).single;

          expect(zeile.tag, '2026-10-20');
          expect(zeile.schritte, 8042);
          expect(zeile.ruhepulsBpm, 51);
          expect(
            zeile.gelesenAm,
            DateTime.utc(2026, 10, 20, 9),
            reason:
                'der in v2 bereits mitgeschriebene Stand überlebt die '
                'Migration — er wird nicht auf "jetzt" gesetzt und nicht '
                'verworfen',
          );
          expect(
            zeile.hrvMs,
            isNull,
            reason:
                'für diese Zeile wurde nie eine HRV geholt. Eine Migration, '
                'die hier einen Wert einträgt, behauptete eine Messung, die '
                'es nicht gab — derselbe Fehler wie ein erfundener '
                'Zeitstempel, nur eine Spalte weiter',
          );
          expect(zeile.respRate, isNull);
          expect(zeile.recoveryHrDrop, isNull);
        },
      );

      test(
        'die Migration legt die vier neuen Tabellen an: sie sind da und '
        'leer — nicht mit Platzhalterzeilen gefüllt',
        () async {
          final db = AppCache(v2Cache());
          addTearDown(db.close);

          expect(
            await db.select(db.naechte).get(),
            isEmpty,
            reason: '#113 — die Nächte des Schlaf-Caches',
          );
          expect(
            await db.select(db.schlafAbschnitte).get(),
            isEmpty,
            reason: '#113 — die Abschnitte je Nacht',
          );
          expect(
            await db.select(db.zielWerte).get(),
            isEmpty,
            reason:
                '#111 — die Ziele. Leer heißt hier: Tim hat noch nichts '
                'eingestellt. Die Vorbelegung (8 h, 22:30, 210 min) steht '
                'in Dart, nicht als Zeile in der Datenbank — sonst gäbe es '
                'sie an zwei Orten, und einer von beiden wäre irgendwann '
                'der falsche',
          );
        },
      );

      test(
        'die beiden anderen v2-Tabellen überstehen die Migration ebenfalls',
        () async {
          final db = AppCache(v2Cache());
          addTearDown(db.close);

          await db
              .into(db.stundenSchritte)
              .insert(
                StundenSchritteCompanion.insert(tag: '2026-10-20', stunde: 7),
              );
          await db
              .into(db.eigeneDaten)
              .insert(
                EigeneDatenCompanion.insert(
                  tag: '2026-10-20',
                  inhalt: 'Rückentag',
                ),
              );

          expect(await db.select(db.stundenSchritte).get(), hasLength(1));
          expect(await db.select(db.eigeneDaten).get(), hasLength(1));
        },
      );
    },
  );

  group(
    'CacheRepository reicht die drei neuen Werte durch (#113, Befund 2)',
    () {
      test(
        'HRV, Atemfrequenz und Puls-Erholung kommen nach dem '
        'Zurückschreiben wieder aus dem Cache — vorher waren sie immer null',
        () async {
          final db = AppCache(NativeDatabase.memory());
          addTearDown(db.close);
          final repo = CacheRepository(db);
          final geholt = DateTime.utc(2026, 10, 20, 14, 32);

          await repo.schreibeTagesWerte(const [
            DailyMetrics(
              tag: '2026-10-20',
              steps: 8042,
              restingHR: 51,
              hrvMs: 38.4,
              respRate: 15.1,
              recoveryHRDrop: 27,
            ),
          ], gelesenAm: geholt);

          final zeile =
              (await repo.liesTagesWerte(DataWindow.unlimited))!.werte.single;

          expect(zeile.steps, 8042);
          expect(zeile.restingHR, 51);
          expect(
            zeile.hrvMs,
            38.4,
            reason:
                'genau der Wert, den die Ampel braucht (Spec 6: HRV ≤ '
                'Median · 0,8). Käme er weiter als null zurück, stünde der '
                'Schirm bei jedem Öffnen zuerst leer da',
          );
          expect(zeile.respRate, 15.1);
          expect(zeile.recoveryHRDrop, 27);
        },
      );

      test(
        'ein Tag ohne HRV bleibt auch dann null, wenn der Nachbartag im '
        'selben Lauf einen Wert hat',
        () async {
          final db = AppCache(NativeDatabase.memory());
          addTearDown(db.close);
          final repo = CacheRepository(db);

          await repo.schreibeTagesWerte(const [
            DailyMetrics(tag: '2026-10-19', steps: 7000),
            DailyMetrics(tag: '2026-10-20', steps: 8000, hrvMs: 38.4),
          ], gelesenAm: DateTime.utc(2026, 10, 20, 14, 32));

          final werte =
              (await repo.liesTagesWerte(DataWindow.unlimited))!.werte;

          expect(werte.map((w) => w.tag).toList(), [
            '2026-10-19',
            '2026-10-20',
          ]);
          expect(
            werte.first.hrvMs,
            isNull,
            reason:
                'der 19. hat keine Messung — kein Übernehmen vom Nachbartag, '
                'kein 0',
          );
          expect(werte.last.hrvMs, 38.4);
        },
      );
    },
  );
}
