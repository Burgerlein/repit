// `drift` exportiert ein eigenes `isNull` (Spaltenausdruck für `IS NULL` in
// Abfragen) — das verdeckt sonst den gleichnamigen `package:matcher`-Matcher,
// den `expect(..., isNull)` unten braucht. Dieselbe Begründung wie in
// `test/data/schema_v9_test.dart`, Zeile 1–4.
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show Database, sqlite3;

import 'package:repit/data/cache.dart';

import 'schema_tabellen.dart';

/// Tests für **Schema v10** (#269) — die Tabelle `tagesgefuehle` wird
/// gelöscht.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden.
///
/// ## Warum eine Migration etwas wegnimmt
///
/// Tim am 03.11.2026: „Tagesgefühl finde ich mittlerweile doof, lass das
/// weg und bau das aus — auch aus dem Design". Das Tagesgefühl kam mit #118
/// und geht mit #269 wieder: Schirm, Provider, Tabelle, Entwurf.
///
/// **Dass die Tabelle mitgeht, hat Tim ausdrücklich entschieden** (#269,
/// Auswahlmenü vom 03.11.2026), und er weiß, dass seine bisherigen Einträge
/// damit endgültig weg sind — auf dem iPhone liegt die einzige Kopie. Diese
/// Datei hält das fest, damit es später nicht nach einem Versehen aussieht:
/// Eine Migration, die Daten löscht, ist sonst von einem Fehler nicht zu
/// unterscheiden.
///
/// ## API, die diese Tests verbindlich vorgeben
///
/// **1. `AppCache.schemaVersion == 10`** und eine **eigene Stufe**
/// `if (from < 10) { await m.deleteTable('tagesgefuehle'); }` — keine
/// Erweiterung der v9-Stufe. Begründung wie bei v3 bis v9
/// (`schema_v3_test.dart`, Dateikopf): Ein Gerät, das zwischen zwei
/// Tickets aktualisiert wurde, muss den Rest nachholen können.
///
/// **2. Die v5-Stufe bleibt stehen.** Sie legt `tagesgefuehle` an, und das
/// muss sie weiter tun: Ein Gerät, das von v4 kommt, läuft durch v5 und
/// erst danach durch v10. Die Stufe zu entfernen, weil die Tabelle am Ende
/// weg ist, bräche jeden Zwischenstand — die Stufen bilden den Weg ab, den
/// ein Gerät genommen hat, nicht den Endzustand. Geprüft wird das hier
/// nicht an ihrem Quelltext, sondern daran, dass ein v4-Gerät durchkommt;
/// ein `createTable`, das fehlt, fällt dort nicht auf, ein `DROP` auf eine
/// nie angelegte Tabelle dagegen schon, wenn es ohne `IF EXISTS` abgesetzt
/// wird.
///
/// **3. `tagesgefuehle` verschwindet aus `tables.dart` und aus
/// `@DriftDatabase(tables: …)`.** Danach gibt es weder `AppCache
/// .tagesgefuehle` noch `TagesgefuehleCompanion` — diese Datei nennt beide
/// deshalb nirgends, sondern fragt die Datei über `sqlite_master`.
///
/// **4. `beforeOpen: _reconcileSchema()` darf sie nicht wieder anlegen.**
/// Der Abgleich zieht bei **jedem** Öffnen nach, was die Datei gegenüber
/// dem heutigen Schema vermissen lässt (#233/#234). Solange
/// `tagesgefuehle` im Schema steht, vermisst er sie — und legte sie nach
/// jedem Start neu an. **Das ist die Stelle, an der diese Löschung am
/// ehesten wirkungslos bleibt**, und deshalb wird sie unten mit einem
/// zweiten Öffnen derselben Datei belegt, nicht mit einem Blick in den
/// Quelltext.
///
/// ## Was hier nicht geprüft wird
///
/// Der **Import aus dem Dashboard** der eingefrorenen Swift-App
/// (`Packages/TrainingsCore/Sources/TrainingsCore/Import/
/// DashboardImport.swift`, `docs/screens/screens/import.js`) bleibt
/// unberührt — Tims zweite Entscheidung vom 03.11.2026. Die Swift-App ist
/// eingefroren; etwas wegzunehmen wäre dort auch eine Änderung.
///
/// **Alle Zahlen hier sind erfunden** — keine echten Gesundheitswerte.
void main() {
  /// Schema v9: der Stand vor diesem Ticket — alle acht Tabellen, elf
  /// Spalten in `tages_werte`, fünf in `naechte`. `gelesen_am`, `beginn`
  /// und `ende` liegen als ISO-Text mit `Z` vor, weil `AppCache` mit
  /// `storeDateTimeAsText: true` arbeitet (`cache.dart`).
  ///
  /// **Von Hand geschrieben, nicht aus dem heutigen Code erzeugt** — ein
  /// Schema, das aus dem heutigen Code entsteht, ist kein Altschema,
  /// sondern das neue, und bewiese nichts (`migration_test.dart`,
  /// Dateikopf).
  const v9Schema = '''
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

  /// Schema v4 — der Stand, **bevor** die v5-Stufe `tagesgefuehle` anlegt.
  /// Er belegt, dass die v5-Stufe stehenbleiben muss: Ein Gerät von hier
  /// läuft durch v5 (legt an) und danach durch v10 (löscht wieder).
  const v4Schema = '''
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
  ''';

  /// Schema v1 — die drei Tabellen, die es ganz am Anfang gab.
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

  /// Was auf einem v9-Gerät liegt: ein Tag mit allen Werten, eine Nacht mit
  /// einem Abschnitt, Tims eingestellte Ziele, zwei eingetragene
  /// Tagesgefühle und eine von Hand nachgetragene Nacht.
  const v9Bestand = '''
    INSERT INTO tages_werte
      (tag, schritte, ruhepuls_bpm, gelesen_am, hrv_ms, resp_rate,
       recovery_hr_drop, gewicht_kg, trainings_minuten, koerperfett_pct,
       fettfrei_kg)
      VALUES ('2026-10-20', 8042, 51, '2026-10-20T09:00:00.000Z',
              38.4, 15.1, 27, 81.4, 47.5, 21.3, 64.1);
    INSERT INTO naechte (tag, gelesen_am, ruhepuls_bpm, hrv_ms, resp_rate)
      VALUES ('2026-10-20', '2026-10-20T09:00:00.000Z', 49.5, 41.2, 14.3);
    INSERT INTO schlaf_abschnitte (tag, quelle, lfd_nr, phase, beginn, ende)
      VALUES ('2026-10-20', 0, 0, 'core',
              '2026-10-19T21:00:00.000Z', '2026-10-20T04:30:00.000Z');
    INSERT INTO ziel_werte (id, schlafziel_minuten, schlafenszeit_minuten,
                            wochenziel_trainingsminuten)
      VALUES (0, 450, 1290, 300);
    INSERT INTO tagesgefuehle (tag, wert) VALUES ('2026-10-20', 4);
    INSERT INTO tagesgefuehle (tag, wert) VALUES ('2026-10-19', 2);
    INSERT INTO schlaf_eintraege
      (tag, art, lfd_nr, schlaf_minuten, beginn_minuten, ende_minuten, notiz)
      VALUES ('2026-10-20', 'nacht', 0, 415, 1385, 380, 'Uhr vergessen');
  ''';

  /// Was auf einem v4-Gerät liegt — die Zieltabelle gibt es dort schon.
  const v4Bestand = '''
    INSERT INTO tages_werte
      (tag, schritte, ruhepuls_bpm, gelesen_am, hrv_ms, resp_rate,
       recovery_hr_drop)
      VALUES ('2026-10-20', 8042, 51, '2026-10-20T09:00:00.000Z',
              38.4, 15.1, 27);
    INSERT INTO ziel_werte (id, schlafziel_minuten, schlafenszeit_minuten,
                            wochenziel_trainingsminuten)
      VALUES (0, 450, 1290, 300);
  ''';

  /// Der Bestand eines v1-Geräts — nur, was es damals gab.
  const v1Bestand = '''
    INSERT INTO tages_werte (tag, schritte, ruhepuls_bpm)
      VALUES ('2026-10-20', 8042, 51);
  ''';

  /// Eine rohe SQLite-Datei im Speicher, auf einen Altstand gesetzt.
  ///
  /// **Roh und nicht über `AppCache`**, damit sie sich mehrfach öffnen
  /// lässt: `NativeDatabase.opened(…, closeUnderlyingOnClose: false)` legt
  /// eine drift-Verbindung darüber, ohne sie beim Schließen zu zerstören.
  /// Nur so ist das zweite Öffnen derselben Datei prüfbar — und genau das
  /// ist der Fall, in dem `beforeOpen` allein läuft.
  ///
  /// Ohne `PRAGMA user_version` meldet SQLite Version 0, drift riefe
  /// `onCreate` statt `onUpgrade` auf, und der Migrationspfad bliebe
  /// ungeprüft — in `migration_test.dart` ausführlich begründet.
  Database rohdatei(String schema, String bestand, int version) {
    final roh = sqlite3.openInMemory();
    roh.execute(schema);
    roh.execute(bestand);
    roh.execute('PRAGMA user_version = $version;');
    return roh;
  }

  /// Öffnet `AppCache` über eine rohe Datei, ohne sie beim Schließen
  /// mitzunehmen.
  AppCache ueber(Database roh) =>
      AppCache(NativeDatabase.opened(roh, closeUnderlyingOnClose: false));

  /// Dieselbe Abkürzung für die Fälle, in denen einmal Öffnen reicht.
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

  /// Die Tabellen, die es in der Datei wirklich gibt. `sqlite_%` sind die
  /// internen Tabellen von SQLite und gehören niemandes Schema.
  Future<Set<String>> tabellen(AppCache db) async {
    final zeilen = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name NOT LIKE 'sqlite_%';",
        )
        .get();
    return zeilen.map((z) => z.read<String>('name')).toSet();
  }

  /// SQLite erhöht `PRAGMA schema_version` bei jedem `CREATE`, `ALTER` und
  /// `DROP` — und sonst nie. Der Stempel belegt also nicht nur, dass die
  /// Tabelle fehlt, sondern dass beim Öffnen überhaupt nichts am Schema
  /// angefasst wurde.
  Future<int> schemaStempel(AppCache db) async {
    final zeile = await db.customSelect('PRAGMA schema_version;').getSingle();
    return zeile.read<int>('schema_version');
  }

  // ---------------------------------------------------------------------

  group('Schema v10 — die Tabelle tagesgefuehle fällt weg (#269)', () {
    test('die Datenbank steht mindestens auf Version 10', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      expect(
        db.schemaVersion,
        greaterThanOrEqualTo(10),
        reason:
            'eine eigene Stufe, keine Erweiterung der v9-Stufe: Ein Gerät, '
            'das zwischen zwei Tickets aktualisiert wurde, muss den Rest '
            'nachholen können. Seit der Stufe 11 (Task 1 des '
            'Ernährungsplans) steht die Zahl höher; die genaue Zahl zählt '
            '`migration_test.dart`, hier geht es nur darum, dass die Stufe '
            'dieses Tickets überhaupt dazugehört',
      );
      expect(await abgelegteVersion(db), db.schemaVersion);
    });

    test('eine frisch angelegte Datei bringt sie gar nicht erst mit', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      expect(
        await tabellen(db),
        tabellenHeute,
        reason:
            '`onCreate` baut das heutige Schema. Eine Tabelle, die es nicht '
            'mehr gibt, darf auf einem neuen Gerät nicht entstehen — sonst '
            'wäre sie nur auf alten Geräten weg',
      );
    });
  });

  group('Migration v9 → v10 — nimmt genau eine Tabelle weg', () {
    QueryExecutor v9Cache() => altstand(v9Schema, v9Bestand, 9);

    test('die Datenbank steht danach auf der heutigen Version', () async {
      final db = AppCache(v9Cache());
      addTearDown(db.close);

      // Gegen `AppCache.schemaVersion` statt gegen eine eigene Zahl — das
      // ist die Regelung seit #193 (nachzulesen in `migration_test.dart`):
      // Sonst fällt bei jeder neuen Stufe auch ein Fall, der von einer
      // alten handelt. Hier geht es darum, dass der Durchlauf die Nummer
      // festschreibt, nicht darum, welche Nummer das heute ist.
      expect(await abgelegteVersion(db), db.schemaVersion);
    });

    test('tagesgefuehle ist weg — und zwar wirklich aus der Datei', () async {
      final db = AppCache(v9Cache());
      addTearDown(db.close);

      expect(
        await tabellen(db),
        tabellenHeute,
        reason:
            'Tim hat das Mitlöschen ausdrücklich entschieden (#269) und '
            'weiß, dass seine Einträge damit endgültig weg sind. Eine '
            'Tabelle, die nur aus dem Dart-Schema verschwindet, bliebe in '
            'der Datei stehen und wäre beim nächsten Abgleich wieder da',
      );
    });

    test(
      'und die übrigen Tabellen behalten jede Zeile, die sie hatten',
      () async {
        final db = AppCache(v9Cache());
        addTearDown(db.close);

        final tag = (await db.select(db.tagesWerte).get()).single;
        expect(tag.schritte, 8042);
        expect(tag.hrvMs, 38.4);
        expect(tag.gewichtKg, 81.4);
        expect(tag.koerperfettPct, 21.3);
        expect(tag.fettfreiKg, 64.1);
        expect(
          tag.gelesenAm,
          DateTime.utc(2026, 10, 20, 9),
          reason:
              'der Stand überlebt die Migration — er wird nicht auf "jetzt" '
              'gesetzt. Ein erfundener Zeitstempel behauptete, die Zeile '
              'sei frisch',
        );

        final nacht = (await db.select(db.naechte).get()).single;
        expect(nacht.ruhepulsBpm, 49.5);
        expect(nacht.hrvMs, 41.2);
        expect(nacht.respRate, 14.3);

        expect(await db.select(db.schlafAbschnitte).get(), hasLength(1));

        final ziele = (await db.select(db.zielWerte).get()).single;
        expect(
          ziele.wochenzielTrainingsminuten,
          300,
          reason:
              'eine Migration, die eine Tabelle löscht, darf keine zweite '
              'mitnehmen — Tims eingestellte Ziele sind nicht Gegenstand '
              'dieses Tickets',
        );

        final eintrag = (await db.select(db.schlafEintraege).get()).single;
        expect(eintrag.schlafMinuten, 415);
        expect(eintrag.notiz, 'Uhr vergessen');
      },
    );

    test('und die Datei ist danach ganz normal benutzbar', () async {
      final db = AppCache(v9Cache());
      addTearDown(db.close);

      await db
          .into(db.tagesWerte)
          .insertOnConflictUpdate(
            TagesWerteCompanion.insert(
              tag: '2026-10-21',
              schritte: const Value(5000),
            ),
          );

      expect(await db.select(db.tagesWerte).get(), hasLength(2));
    });
  });

  group('Der Weg von unten — die v5-Stufe bleibt stehen', () {
    test(
      'ein Gerät auf v4 kommt oben an: v5 legt tagesgefuehle an, v10 '
      'nimmt sie wieder weg',
      () async {
        final db = AppCache(altstand(v4Schema, v4Bestand, 4));
        addTearDown(db.close);

        expect(await abgelegteVersion(db), db.schemaVersion);
        expect(
          await tabellen(db),
          tabellenHeute,
          reason:
              'die v5-Stufe zu entfernen, weil die Tabelle am Ende weg ist, '
              'bräche jeden Zwischenstand: Die Stufen bilden den Weg ab, '
              'den ein Gerät genommen hat, nicht den Endzustand',
        );
        expect(
          (await db.select(db.zielWerte).get()).single.wochenzielTrainingsminuten,
          300,
          reason: 'und Tims eingestellte Ziele stehen weiter da',
        );
      },
    );

    test('ein Gerät auf v1 kommt ebenfalls oben an', () async {
      final db = AppCache(altstand(v1Schema, v1Bestand, 1));
      addTearDown(db.close);

      expect(await abgelegteVersion(db), db.schemaVersion);
      expect(await tabellen(db), tabellenHeute);

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
      expect(await db.select(db.zielWerte).get(), isEmpty);
      expect(await db.select(db.schlafEintraege).get(), isEmpty);
    });
  });

  group('_reconcileSchema legt sie nicht wieder an (#233/#234)', () {
    test(
      'zweites Öffnen derselben Datei: die Tabelle bleibt weg, und am '
      'Schema wird nichts angefasst',
      () async {
        final roh = rohdatei(v9Schema, v9Bestand, 9);
        addTearDown(roh.dispose);

        final erstesMal = ueber(roh);
        expect(await tabellen(erstesMal), tabellenHeute, reason: 'Vorbedingung');
        final stempelNachDemLoeschen = await schemaStempel(erstesMal);
        await erstesMal.close();

        // Zweites Öffnen: Die Nummer steht schon auf 10, `onUpgrade` läuft
        // gar nicht. Was hier noch laufen kann, ist allein `beforeOpen`.
        final zweitesMal = ueber(roh);
        addTearDown(zweitesMal.close);

        expect(
          await tabellen(zweitesMal),
          tabellenHeute,
          reason:
              'der Abgleich zieht nach, was die Datei gegenüber dem '
              'heutigen Schema vermissen lässt. Bliebe `tagesgefuehle` im '
              'Schema stehen, vermisste er sie — und legte sie nach jedem '
              'Start neu an. Dann wäre die Löschung wirkungslos',
        );
        expect(
          await schemaStempel(zweitesMal),
          stempelNachDemLoeschen,
          reason:
              'SQLite erhöht `PRAGMA schema_version` bei jedem CREATE, '
              'ALTER und DROP und sonst nie. Gleich heißt: beim zweiten '
              'Öffnen ist kein einziges Statement gegen das Schema '
              'gelaufen — weder ein Anlegen noch ein erneutes Löschen',
        );
      },
    );

    test(
      'eine Datei, die schon auf 10 steht und die Tabelle nie hatte, wird '
      'nicht darum ergänzt',
      () async {
        // Kein `onUpgrade`: Die Nummer stimmt bereits. Nur `beforeOpen`
        // kommt zum Zug — derselbe Fall wie auf einem Gerät, das die
        // Migration schon hinter sich hat.
        final db = AppCache(
          altstand(
            v9Schema.replaceFirst(
              RegExp(r'CREATE TABLE tagesgefuehle \([^;]*\);'),
              '',
            ),
            v9Bestand
                .replaceAll(
                  "INSERT INTO tagesgefuehle (tag, wert) "
                  "VALUES ('2026-10-20', 4);",
                  '',
                )
                .replaceAll(
                  "INSERT INTO tagesgefuehle (tag, wert) "
                  "VALUES ('2026-10-19', 2);",
                  '',
                ),
            10,
          ),
        );
        addTearDown(db.close);

        expect(await tabellen(db), tabellenHeute);
        // Die Datei kommt mit der 10 herein und geht mit der heutigen
        // Nummer heraus — die Stufe 11 hat auf ihr noch zu tun. Gegenstand
        // dieses Falls ist die Zeile darüber: dass `tagesgefuehle` nicht
        // wieder auftaucht.
        expect(await abgelegteVersion(db), db.schemaVersion);
      },
    );

    test(
      'eine Datei, die schon auf 10 steht und die Tabelle trotzdem noch hat '
      '— etwa aus einem anderen Zweig —, lässt sich öffnen und benutzen',
      () async {
        // Der Abgleich ist additiv: Er legt Fehlendes an, er räumt nichts
        // weg. Diese Tabelle bleibt also stehen, und das ist richtig so —
        // ein Abgleich, der von sich aus löscht, wäre die gefährlichere
        // Bauart. Festgehalten wird hier, dass sie **nicht stört**: Die App
        // kennt sie nicht mehr und fasst sie nicht an.
        final db = AppCache(altstand(v9Schema, v9Bestand, 10));
        addTearDown(db.close);

        expect(
          await tabellen(db),
          tabellenHeute.union({'tagesgefuehle'}),
          reason: 'der Abgleich räumt nicht auf, er ergänzt nur',
        );
        expect((await db.select(db.tagesWerte).get()).single.schritte, 8042);
      },
    );
  });
}
