// `drift` exportiert ein eigenes `isNull` (Spaltenausdruck für `IS NULL` in
// Abfragen) — das verdeckt sonst den gleichnamigen `package:matcher`-Matcher,
// den `expect(..., isNull)` unten braucht. Dieselbe Begründung wie in
// `test/data/schema_v10_test.dart`, Zeile 1–4.
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show Database, sqlite3;

import 'package:repit/data/cache.dart';
import 'package:repit/data/stammdaten.dart';

import 'schema_tabellen.dart';

/// Tests für **Schema v11** — die Tabelle `stammdaten` kommt dazu (Task 1
/// des Ernährungsplans, `docs/superpowers/plans/2026-11-03-ernaehrung.md`).
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden.
///
/// Nachbar von `schema_v7_test.dart` bis `schema_v10_test.dart`: derselbe
/// Aufbau, dieselben Hilfsmittel, von Hand gebaute Altstände.
///
/// ## Warum es diese Tabelle gibt
///
/// Der Ernährungsschirm braucht vier Angaben über Tim, die nicht aus Apple
/// Health kommen und keinen Verlauf haben: Körpergröße, Geburtsjahr,
/// Zielgewicht und das Datum, zu dem er dort sein will. Aus Größe, Alter
/// und Gewicht rechnet Task 2 den Grundumsatz; ohne diese Werte gibt es
/// kein Kalorienziel.
///
/// **Alle vier sind nullbar, und das ist der Kern dieser Tabelle.** Solange
/// Tim nichts eingetragen hat, steht dort nichts — kein `0`, kein
/// vorbelegtes Geburtsjahr, kein Platzhalterdatum. Ein Grundumsatz, der aus
/// einer erfundenen Größe entsteht, sähe aus wie eine Rechnung und wäre
/// eine Behauptung. Das ist Fehler `01` eine Schicht tiefer.
///
/// **Zweite Tabellengruppe (Spec 5.6a): `Messwert<T>` gilt hier nicht.**
/// Hinter diesen vier Feldern steht kein Lauf aus Apple Health, der leer
/// ausgehen könnte, sondern Tim. Leer heißt leer. Deshalb gibt es auch kein
/// `gelesen_am` — eine Spalte, die sagt, wann wir etwas geholt haben, hätte
/// hier nichts zu tragen.
///
/// **Anders als bei den Zielen gibt es keine Vorbelegung.** `Ziele` kennt
/// `Ziele.vorbelegung`, weil 8 Stunden Schlaf eine Empfehlung sind, die für
/// jeden gilt. Eine Körpergröße gilt für niemanden außer Tim; sie zu raten
/// wäre keine Vorbelegung, sondern eine Erfindung. `lies()` antwortet
/// deshalb mit vier `null`, nicht mit Zahlen.
///
/// ## API, die diese Tests verbindlich vorgeben
///
/// **1. `AppCache.schemaVersion == 11`** und eine **eigene Stufe**
/// `if (from < 11) { await m.createTable(stammdaten); }` — keine Erweiterung
/// der v10-Stufe. Begründung wie bei v3 bis v10 (`schema_v3_test.dart`,
/// Dateikopf): Ein Gerät, das zwischen zwei Tickets aktualisiert wurde, muss
/// den Rest nachholen können.
///
/// Die Nummer wurde am 04.11.2026 aus `cache.dart` **gelesen**, nicht
/// abgeschrieben: `grep -n "schemaVersion =>" app/lib/data/cache.dart`
/// meldete `10`, also ist die nächste freie die 11. Dieselbe Begründung wie
/// bei #235 — eine Nummer sagt nicht, welches Ticket zuerst fertig war,
/// sondern was ein Gerät schon ausgeführt hat.
///
/// **2. Die Tabelle heißt in der Datei `stammdaten`** und trägt mindestens
/// die vier Spalten `groesse_cm` (INTEGER), `geburtsjahr` (INTEGER),
/// `zielgewicht_kg` (REAL) und `zieldatum` (TEXT), alle vier nullbar.
///
/// - **`zielgewicht_kg` ist REAL, nicht INTEGER.** Eine Ganzzahlspalte
///   zwänge zum Runden, und das wäre eine stille Veränderung von Tims Wert
///   auf dem Weg in den Cache — derselbe Grund, aus dem
///   `TagesWerte.trainingsMinuten` in #194 eine `RealColumn` wurde.
/// - **`zieldatum` ist TEXT und trägt den ISO-Tagesstring** (`YYYY-MM-DD`),
///   kein Zeitpunkt und keine Epoch-Zahl. Ein Zieldatum ist eine
///   Kalenderangabe; als Zeitstempel abgelegt hinge es an einer Zeitzone und
///   wäre nach der nächsten Umstellung der Vortag (`CLAUDE.md`, „Der
///   Datumsschlüssel ist der ISO-Tagesstring").
///
/// Ob daneben ein Schlüssel steht (`id` mit `withDefault(const Constant(0))`
/// wie bei `ZielWerte` — Stammdaten sind kein Verlauf, eine zweite Zeile
/// wäre ein zweiter, widersprechender Stand), ist die Entscheidung dessen,
/// der implementiert. Diese Datei prüft deshalb mit `containsAll` und nicht
/// auf eine genaue Spaltenliste.
///
/// **Ein Hinweis zum `@DataClassName`:** Hieße die Datenklasse der Tabelle
/// ebenfalls `Stammdaten`, kollidierte sie mit dem Werttyp gleichen Namens,
/// sobald eine Datei beides importiert — so wie diese hier. Die Hausform
/// (`TagesWerteRow`, `ZielWerteRow`, `NachtRow`) löst das:
/// `@DataClassName('StammdatenRow')`. Die Tests unten fragen die Tabelle
/// deshalb über `customSelect` und nicht über den erzeugten Zugriff; sie
/// legen den Namen der Datenklasse nicht fest, stolpern aber auch nicht
/// darüber.
///
/// **3. In `lib/data/stammdaten.dart`:**
///
/// ```dart
/// @immutable
/// class Stammdaten {
///   const Stammdaten({
///     this.groesseCm,
///     this.geburtsjahr,
///     this.zielgewichtKg,
///     this.zieldatum,
///   });
///   final int? groesseCm;
///   final int? geburtsjahr;
///   final double? zielgewichtKg;
///   final String? zieldatum;   // ISO-Tagesstring
///   // == und hashCode über alle vier Felder
/// }
///
/// class StammdatenRepository {
///   StammdatenRepository(AppCache db);
///   Future<Stammdaten> lies();          // vier null, solange nichts da ist
///   Future<void> schreibe(Stammdaten);  // überschreibend, eine Zeile
/// }
/// ```
///
/// `const Stammdaten()` — alle vier Felder weggelassen — ist der leere
/// Stand und damit die Antwort auf eine leere Tabelle.
///
/// **`==` und `hashCode` sind Pflicht**, nicht Zierde: Riverpod rechnet
/// Abgeleitetes neu, sobald die Abhängigkeit ungleich vergleicht. Ohne
/// Wertgleichheit baute jeder Lesevorgang ein neues, ungleiches Objekt, und
/// jeder Beobachter — das Kalorienziel, der Grundumsatz, der ganze
/// Ernährungsschirm — rechnete bei jedem Zugriff neu. Das wäre Fehler `03`,
/// wortgleich, im neuen Code.
///
/// ## Was diese Datei **nicht** beweisen kann
///
/// **Dass die Stufe `if (from < 11)` wirklich existiert.** Seit #233 hängt
/// `_reconcileSchema` an `beforeOpen` und legt bei **jedem** Öffnen an, was
/// die Datei gegenüber dem heutigen Schema vermissen lässt. Eine vergessene
/// Stufe fiele deshalb von außen nicht auf — die Tabelle stünde trotzdem da.
/// Geprüft wird hier also das Ergebnis, nicht die Bauform.
///
/// Die Stufe gehört trotzdem geschrieben, und zwar aus demselben Grund, aus
/// dem es den Abgleich gibt: Er ist das Netz, nicht der Weg. Ein Schema, das
/// nur noch über den Abgleich entsteht, hat keine Migrationskette mehr,
/// sondern eine Reparatur bei jedem Start — und die kann keine Daten
/// umformen, nur Fehlendes nachlegen. Wer die Stufe weglässt, merkt das beim
/// ersten Ticket, das mehr braucht als eine leere Tabelle.
///
/// **Was `abgelegteVersion` dagegen sehr wohl belegt:** dass der Durchlauf
/// die Nummer aus `AppCache.schemaVersion` in der Datei festschreibt.
/// Bliebe sie auf 10, liefe auf Tims Gerät keine Stufe mehr, die er noch
/// nicht kennt — genau der Fall aus #233. Verglichen wird seit dem
/// 04.11.2026 gegen `db.schemaVersion` statt gegen die 11; die absolute
/// Zahl steht an genau einer Stelle, in `migration_test.dart` (#193,
/// #208). Diese Datei handelt von der Stufe 11, nicht von der heutigen
/// Nummer — die ist mit der Stufe 12 weitergerückt.
///
/// **Alle Zahlen hier sind erfunden** und bewusst weit von Tims Werten
/// entfernt: 211 cm, Geburtsjahr 1904, 33,3 kg Zielgewicht. Echte
/// Gesundheitsdaten stehen nie im Quelltext, auch nicht in einem Test
/// (`CLAUDE.md`). Die Tagesschlüssel liegen im Jahr 2099, damit sie keinen
/// Termin nachahmen.
void main() {
  /// Schema v10: der Stand vor diesem Ticket — sieben Tabellen, elf Spalten
  /// in `tages_werte`, fünf in `naechte`, `tagesgefuehle` seit #269 weg.
  /// `gelesen_am`, `beginn` und `ende` liegen als ISO-Text mit `Z` vor, weil
  /// `AppCache` mit `storeDateTimeAsText: true` arbeitet (`cache.dart`).
  ///
  /// **Von Hand geschrieben, nicht aus dem heutigen Code erzeugt** — ein
  /// Schema, das aus dem heutigen Code entsteht, ist kein Altschema, sondern
  /// das neue, und bewiese nichts (`migration_test.dart`, Dateikopf).
  const v10Schema = '''
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
  ''';

  /// Die Tabelle, wie ein **anderer Zweig** sie angelegt haben könnte —
  /// alle bauen unter derselben Bundle-ID und benutzen dieselbe Datei
  /// (#234/#240). Form und Spaltennamen entsprechen dem, was diese Datei
  /// oben festlegt.
  const stammdatenVorweg = '''
    CREATE TABLE stammdaten (
      id INTEGER NOT NULL DEFAULT 0,
      groesse_cm INTEGER,
      geburtsjahr INTEGER,
      zielgewicht_kg REAL,
      zieldatum TEXT,
      PRIMARY KEY (id)
    );
    INSERT INTO stammdaten (id, groesse_cm, geburtsjahr, zielgewicht_kg,
                            zieldatum)
      VALUES (0, 211, 1904, 33.3, '2099-12-31');
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

  /// Was auf einem v10-Gerät liegt: ein Tag mit allen Werten, eine Nacht mit
  /// einem Abschnitt, Tims eingestellte Ziele und eine von Hand
  /// nachgetragene Nacht. **Die Tageswerte sind Tims einzige Offline-Quelle**
  /// — eine Migration, die hier etwas verlöre, verlöre es endgültig.
  const v10Bestand = '''
    INSERT INTO tages_werte
      (tag, schritte, ruhepuls_bpm, gelesen_am, hrv_ms, resp_rate,
       recovery_hr_drop, gewicht_kg, trainings_minuten, koerperfett_pct,
       fettfrei_kg)
      VALUES ('2099-03-01', 4242, 99, '2099-03-01T09:00:00.000Z',
              11.1, 33.3, 7, 199.9, 444.4, 55.5, 22.2);
    INSERT INTO naechte (tag, gelesen_am, ruhepuls_bpm, hrv_ms, resp_rate)
      VALUES ('2099-03-01', '2099-03-01T09:00:00.000Z', 88.8, 12.5, 44.4);
    INSERT INTO schlaf_abschnitte (tag, quelle, lfd_nr, phase, beginn, ende)
      VALUES ('2099-03-01', 0, 0, 'core',
              '2099-02-28T21:00:00.000Z', '2099-03-01T04:30:00.000Z');
    INSERT INTO ziel_werte (id, schlafziel_minuten, schlafenszeit_minuten,
                            wochenziel_trainingsminuten)
      VALUES (0, 444, 1234, 321);
    INSERT INTO schlaf_eintraege
      (tag, art, lfd_nr, schlaf_minuten, beginn_minuten, ende_minuten, notiz)
      VALUES ('2099-03-01', 'nacht', 0, 417, 1385, 380, 'Uhr vergessen');
  ''';

  /// Der Bestand eines v1-Geräts — nur, was es damals gab.
  const v1Bestand = '''
    INSERT INTO tages_werte (tag, schritte, ruhepuls_bpm)
      VALUES ('2099-03-01', 4242, 99);
  ''';

  /// Die vier Spalten, auf die es ankommt.
  const vierFelder = ['groesse_cm', 'geburtsjahr', 'zielgewicht_kg',
    'zieldatum'];

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

  /// Die Spalten einer Tabelle, so wie sie wirklich in der Datei stehen:
  /// Name, Typ und ob NULL erlaubt ist.
  ///
  /// `PRAGMA` nimmt keine Platzhalter, der Name steht deshalb im Text — er
  /// stammt hier ausschließlich aus Konstanten dieser Datei.
  Future<Map<String, ({String typ, bool nullbar})>> spalten(
    AppCache db,
    String tabelle,
  ) async {
    final zeilen = await db.customSelect('PRAGMA table_info($tabelle);').get();
    return {
      for (final z in zeilen)
        z.read<String>('name'): (
          typ: z.read<String>('type').toUpperCase(),
          nullbar: z.read<int>('notnull') == 0,
        ),
    };
  }

  /// Wie viele Zeilen in einer Tabelle stehen — gefragt wird die Datei,
  /// nicht der erzeugte Zugriff.
  Future<int> zeilenZahl(AppCache db, String tabelle) async {
    final zeile = await db
        .customSelect('SELECT COUNT(*) AS anzahl FROM $tabelle;')
        .getSingle();
    return zeile.read<int>('anzahl');
  }

  /// SQLite erhöht `PRAGMA schema_version` bei jedem `CREATE`, `ALTER` und
  /// `DROP` — und sonst nie. Der Stempel belegt also nicht nur, dass eine
  /// Tabelle da ist, sondern ob beim Öffnen überhaupt etwas am Schema
  /// angefasst wurde.
  Future<int> schemaStempel(AppCache db) async {
    final zeile = await db.customSelect('PRAGMA schema_version;').getSingle();
    return zeile.read<int>('schema_version');
  }

  // ---------------------------------------------------------------------

  group('Schema v11 — die Tabelle stammdaten kommt dazu', () {
    test('die Datenbank steht mindestens auf Version 11', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      expect(
        db.schemaVersion,
        greaterThanOrEqualTo(11),
        reason:
            'eine eigene Stufe, keine Erweiterung der v10-Stufe: Ein Gerät, '
            'das zwischen zwei Tickets aktualisiert wurde, muss den Rest '
            'nachholen können. Bliebe die Nummer auf 10, liefe auf Tims '
            'Gerät keine Stufe mehr, die es noch nicht kennt (#233). Seit '
            'der Stufe 12 (Task 3 des Ernährungsplans) steht die Zahl '
            'höher; die genaue Zahl zählt `migration_test.dart`, hier geht '
            'es nur darum, dass die Stufe dieses Tickets überhaupt '
            'dazugehört',
      );
      expect(await abgelegteVersion(db), db.schemaVersion);
    });

    test('eine frisch angelegte Datei bringt sie gleich mit', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      expect(
        await tabellen(db),
        tabellenHeute,
        reason:
            '`onCreate` baut das heutige Schema. Eine Tabelle, die es nur '
            'nach einer Migration gäbe, fehlte auf jedem neuen Gerät',
      );
    });
  });

  group('Migration v10 → v11 — legt genau eine Tabelle an', () {
    QueryExecutor v10Cache() => altstand(v10Schema, v10Bestand, 10);

    test('die Datenbank steht danach auf der heutigen Version', () async {
      final db = AppCache(v10Cache());
      addTearDown(db.close);

      // Gegen `AppCache.schemaVersion` statt gegen eine eigene Zahl — das
      // ist die Regelung seit #193 (nachzulesen in `migration_test.dart`):
      // Sonst fällt bei jeder neuen Stufe auch ein Fall, der von einer
      // alten handelt. Hier geht es darum, dass der Durchlauf die Nummer
      // festschreibt, nicht darum, welche Nummer das heute ist.
      expect(await abgelegteVersion(db), db.schemaVersion);
    });

    test('und stammdaten steht wirklich in der Datei', () async {
      final db = AppCache(v10Cache());
      addTearDown(db.close);

      expect(await tabellen(db), tabellenHeute);
    });

    test(
      'mit vier nullbaren Spalten — Zielgewicht als REAL, Zieldatum als Text',
      () async {
        final db = AppCache(v10Cache());
        addTearDown(db.close);

        final gefunden = await spalten(db, 'stammdaten');

        expect(
          gefunden.keys,
          containsAll(vierFelder),
          reason:
              'Größe, Geburtsjahr, Zielgewicht und Zieldatum. Ob daneben '
              'ein Schlüssel steht, ist die Entscheidung dessen, der '
              'implementiert — deshalb containsAll und keine genaue Liste',
        );

        expect(gefunden['groesse_cm']!.typ, 'INTEGER');
        expect(gefunden['geburtsjahr']!.typ, 'INTEGER');
        expect(
          gefunden['zielgewicht_kg']!.typ,
          'REAL',
          reason:
              'eine Ganzzahlspalte zwänge zum Runden, und das wäre eine '
              'stille Veränderung von Tims Wert auf dem Weg in den Cache — '
              'derselbe Grund wie bei TagesWerte.trainingsMinuten (#194)',
        );
        expect(
          gefunden['zieldatum']!.typ,
          'TEXT',
          reason:
              'ein Zieldatum ist eine Kalenderangabe, kein Zeitpunkt. Als '
              'Zeitstempel abgelegt hinge es an einer Zeitzone und wäre '
              'nach der nächsten Umstellung der Vortag',
        );

        for (final feld in vierFelder) {
          expect(
            gefunden[feld]!.nullbar,
            isTrue,
            reason:
                '$feld muss leer bleiben dürfen. Eine NOT-NULL-Spalte '
                'zwänge die Migration zu einem Vorgabewert, und jeder '
                'Vorgabewert wäre eine erfundene Angabe über Tim',
          );
        }
      },
    );

    test(
      'die Migration legt keine Zeile an — vier leere Felder, keine '
      'erfundenen Werte',
      () async {
        final db = AppCache(v10Cache());
        addTearDown(db.close);

        expect(
          await zeilenZahl(db, 'stammdaten'),
          0,
          reason:
              'eine vorab eingefügte Zeile behauptete, Tim habe etwas '
              'eingetragen. Leer heißt leer (Spec 5.6a)',
        );

        final gelesen = await StammdatenRepository(db).lies();
        expect(
          gelesen.groesseCm,
          isNull,
          reason: 'nicht 0 — ein Mensch mit 0 cm ist kein fehlender Wert',
        );
        expect(gelesen.geburtsjahr, isNull, reason: 'nicht 0 und kein Jahr');
        expect(
          gelesen.zielgewichtKg,
          isNull,
          reason: 'nicht 0.0 — daraus entstünde ein gerechneter Grundumsatz',
        );
        expect(
          gelesen.zieldatum,
          isNull,
          reason:
              'kein Platzhalterdatum. Ein Datum im Quelltext wäre ein '
              'erfundenes Ereignis (`CLAUDE.md`)',
        );
      },
    );

    test(
      'und bestehende Zeilen anderer Tabellen überleben unverändert',
      () async {
        final db = AppCache(v10Cache());
        addTearDown(db.close);

        final tag = (await db.select(db.tagesWerte).get()).single;
        expect(tag.tag, '2099-03-01');
        expect(
          tag.schritte,
          4242,
          reason:
              'die Tageswerte im Cache sind Tims einzige Offline-Quelle — '
              'eine Migration verwirft nie eine vorhandene Zeile',
        );
        expect(tag.ruhepulsBpm, 99);
        expect(tag.hrvMs, 11.1);
        expect(tag.respRate, 33.3);
        expect(tag.recoveryHrDrop, 7);
        expect(tag.gewichtKg, 199.9);
        expect(tag.trainingsMinuten, 444.4);
        expect(tag.koerperfettPct, 55.5);
        expect(tag.fettfreiKg, 22.2);
        expect(
          tag.gelesenAm,
          DateTime.utc(2099, 3, 1, 9),
          reason:
              'der Stand überlebt die Migration — er wird nicht auf "jetzt" '
              'gesetzt. Ein erfundener Zeitstempel behauptete, die Zeile '
              'sei frisch',
        );

        final nacht = (await db.select(db.naechte).get()).single;
        expect(nacht.ruhepulsBpm, 88.8);
        expect(nacht.hrvMs, 12.5);
        expect(nacht.respRate, 44.4);

        expect(await db.select(db.schlafAbschnitte).get(), hasLength(1));

        final ziele = (await db.select(db.zielWerte).get()).single;
        expect(
          ziele.wochenzielTrainingsminuten,
          321,
          reason:
              'eine Migration, die eine Tabelle anlegt, fasst keine zweite '
              'an — Tims eingestellte Ziele sind nicht Gegenstand dieses '
              'Tickets',
        );

        final eintrag = (await db.select(db.schlafEintraege).get()).single;
        expect(eintrag.schlafMinuten, 417);
        expect(eintrag.notiz, 'Uhr vergessen');
      },
    );

    test('und die Datei ist danach ganz normal benutzbar', () async {
      final db = AppCache(v10Cache());
      addTearDown(db.close);

      await db
          .into(db.tagesWerte)
          .insertOnConflictUpdate(
            TagesWerteCompanion.insert(
              tag: '2099-03-02',
              schritte: const Value(1111),
            ),
          );

      expect(await db.select(db.tagesWerte).get(), hasLength(2));
    });
  });

  group('Die Stufe ist zweimal ausführbar (#234/#240)', () {
    /// Nummer zu niedrig, Tabelle schon da: Ein anderer Zweig hat sie unter
    /// derselben Bundle-ID in dieselbe Datei gelegt, die Nummer steht aber
    /// noch auf 10. Ein `CREATE TABLE` ohne `IF NOT EXISTS` stürbe hier —
    /// und zwar beim **Öffnen**, danach wäre die Datenbank gar nicht mehr
    /// zu benutzen.
    QueryExecutor vorweggenommen() => altstand(
      '$v10Schema$stammdatenVorweg',
      v10Bestand,
      10,
    );

    test('die Datenbank lässt sich überhaupt öffnen', () async {
      final db = AppCache(vorweggenommen());
      addTearDown(db.close);

      expect(
        await zeilenZahl(db, 'stammdaten'),
        isNonNegative,
        reason:
            'die erste Abfrage löst das Öffnen aus. Wirft die Stufe, kommt '
            'es hier an — und auf dem Gerät gar nicht mehr weiter',
      );
      expect(await abgelegteVersion(db), db.schemaVersion);
    });

    test(
      'und die vorweggenommene Zeile überlebt — die Tabelle wird nicht neu '
      'gebaut',
      () async {
        final db = AppCache(vorweggenommen());
        addTearDown(db.close);

        final gelesen = await StammdatenRepository(db).lies();
        expect(gelesen.groesseCm, 211);
        expect(gelesen.geburtsjahr, 1904);
        expect(gelesen.zielgewichtKg, 33.3);
        expect(
          gelesen.zieldatum,
          '2099-12-31',
          reason:
              'ein vorsorgliches DROP TABLE IF EXISTS vor dem CREATE wäre '
              'eine Stufe, die nie scheitert und trotzdem Tims Werte '
              'löscht — schlimmer als der Absturz, den sie behebt',
        );

        expect(await db.select(db.tagesWerte).get(), hasLength(1));
      },
    );

    test(
      'zweites Öffnen derselben Datei: nichts wird angefasst, nichts geht '
      'verloren',
      () async {
        final roh = rohdatei(v10Schema, v10Bestand, 10);
        addTearDown(roh.dispose);

        final erstesMal = ueber(roh);
        expect(await tabellen(erstesMal), tabellenHeute, reason: 'Vorbedingung');
        await StammdatenRepository(erstesMal).schreibe(
          const Stammdaten(
            groesseCm: 142,
            geburtsjahr: 1888,
            zielgewichtKg: 199.9,
            zieldatum: '2088-01-01',
          ),
        );
        final stempelNachDerStufe = await schemaStempel(erstesMal);
        await erstesMal.close();

        // Zweites Öffnen: Die Nummer steht schon auf 11, `onUpgrade` läuft
        // gar nicht. Was hier noch laufen kann, ist allein `beforeOpen`.
        final zweitesMal = ueber(roh);
        addTearDown(zweitesMal.close);

        expect(await tabellen(zweitesMal), tabellenHeute);
        expect(
          await schemaStempel(zweitesMal),
          stempelNachDerStufe,
          reason:
              'SQLite erhöht `PRAGMA schema_version` bei jedem CREATE, '
              'ALTER und DROP und sonst nie. Gleich heißt: beim zweiten '
              'Öffnen ist kein einziges Statement gegen das Schema '
              'gelaufen — die Stufe hat nicht noch einmal angelegt',
        );

        final gelesen = await StammdatenRepository(zweitesMal).lies();
        expect(
          gelesen.groesseCm,
          142,
          reason:
              'was beim ersten Lauf eingetragen wurde, steht beim zweiten '
              'Öffnen noch da — sonst wäre die Tabelle neu gebaut worden',
        );
        expect(gelesen.zieldatum, '2088-01-01');
        expect(await zeilenZahl(zweitesMal, 'stammdaten'), 1);
      },
    );
  });

  group('Der Weg von unten', () {
    test('ein Gerät auf v1 kommt ganz oben an — über die Stufe 11 hinweg',
        () async {
      final db = AppCache(altstand(v1Schema, v1Bestand, 1));
      addTearDown(db.close);

      expect(await abgelegteVersion(db), db.schemaVersion);
      expect(await tabellen(db), tabellenHeute);

      final zeile = (await db.select(db.tagesWerte).get()).single;
      expect(zeile.schritte, 4242);
      expect(zeile.ruhepulsBpm, 99);
      expect(
        zeile.gelesenAm,
        isNull,
        reason:
            'v1 kannte die Spalte nicht — woher die Zeile stammt, weiß '
            'niemand mehr, und ein nachgetragenes "jetzt" wäre gelogen',
      );

      expect(
        await zeilenZahl(db, 'stammdaten'),
        0,
        reason:
            'die neue Tabelle kommt leer, auch auf dem längsten Weg. Eine '
            'nachgelegte Zeile wäre eine Angabe über Tim, die niemand '
            'gemacht hat',
      );
    });
  });

  group('Rundweg — geschrieben ist gelesen', () {
    AppCache frisch() {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);
      return db;
    }

    test('ohne abgelegte Zeile stehen alle vier Felder auf null', () async {
      final db = frisch();

      expect(
        await StammdatenRepository(db).lies(),
        const Stammdaten(),
        reason:
            'anders als bei den Zielen gibt es keine Vorbelegung: 8 Stunden '
            'Schlaf sind eine Empfehlung für jeden, eine Körpergröße gilt '
            'für niemanden außer Tim',
      );
      expect(await zeilenZahl(db, 'stammdaten'), 0);
    });

    test('vollständig geschrieben kommt unverändert zurück', () async {
      final db = frisch();
      final repo = StammdatenRepository(db);

      const eingetragen = Stammdaten(
        groesseCm: 211,
        geburtsjahr: 1904,
        zielgewichtKg: 33.3,
        zieldatum: '2099-12-31',
      );
      await repo.schreibe(eingetragen);

      expect(await repo.lies(), eingetragen);
    });

    test('teilweise geschrieben — die leeren Felder bleiben leer', () async {
      final db = frisch();
      final repo = StammdatenRepository(db);

      await repo.schreibe(const Stammdaten(groesseCm: 211));

      final gelesen = await repo.lies();
      expect(gelesen.groesseCm, 211);
      expect(
        gelesen.geburtsjahr,
        isNull,
        reason:
            'wer nur die Größe einträgt, hat kein Geburtsjahr angegeben — '
            'und 0 wäre eines',
      );
      expect(gelesen.zielgewichtKg, isNull);
      expect(gelesen.zieldatum, isNull);
    });

    test(
      'ein zweites Schreiben überschreibt — es entsteht keine zweite Zeile '
      'und kein zweiter, widersprechender Stand',
      () async {
        final db = frisch();
        final repo = StammdatenRepository(db);

        await repo.schreibe(const Stammdaten(groesseCm: 211));
        await repo.schreibe(const Stammdaten(groesseCm: 142));

        expect(await zeilenZahl(db, 'stammdaten'), 1);
        expect((await repo.lies()).groesseCm, 142);
      },
    );

    test(
      'ein geleertes Feld wird wirklich geleert — null überschreibt einen '
      'vorhandenen Wert',
      () async {
        final db = frisch();
        final repo = StammdatenRepository(db);

        await repo.schreibe(
          const Stammdaten(
            groesseCm: 211,
            geburtsjahr: 1904,
            zielgewichtKg: 33.3,
            zieldatum: '2099-12-31',
          ),
        );
        await repo.schreibe(const Stammdaten(groesseCm: 211));

        expect(
          await repo.lies(),
          const Stammdaten(groesseCm: 211),
          reason:
              'wer ein Feld löscht, hat es gelöscht. Ein Schreibweg, der '
              'null als "nicht angegeben, bitte stehen lassen" liest '
              '(`Value.absent()` statt `Value(null)`), macht das Löschen '
              'unmöglich — und zwar lautlos',
        );
      },
    );

    test(
      'das Zieldatum bleibt der ISO-Tagesstring, Zeichen für Zeichen',
      () async {
        final db = frisch();
        final repo = StammdatenRepository(db);

        await repo.schreibe(const Stammdaten(zieldatum: '2088-01-01'));

        expect(
          (await repo.lies()).zieldatum,
          '2088-01-01',
          reason:
              'ein Umweg über DateTime und zurück verschöbe den Tag auf '
              'einem anders eingestellten Gerät um einen',
        );
      },
    );

    test('ein geschriebener Stand überlebt den Neustart der App', () async {
      final db = frisch();

      await StammdatenRepository(
        db,
      ).schreibe(const Stammdaten(geburtsjahr: 1888, zielgewichtKg: 199.9));

      final gelesen = await StammdatenRepository(db).lies();
      expect(gelesen.geburtsjahr, 1888);
      expect(gelesen.zielgewichtKg, 199.9);
    });
  });

  group('Wertgleichheit — ohne sie rechnet Riverpod alles neu', () {
    test('zwei Stammdaten mit denselben Werten sind gleich', () {
      const einer = Stammdaten(
        groesseCm: 211,
        geburtsjahr: 1904,
        zielgewichtKg: 33.3,
        zieldatum: '2099-12-31',
      );
      const anderer = Stammdaten(
        groesseCm: 211,
        geburtsjahr: 1904,
        zielgewichtKg: 33.3,
        zieldatum: '2099-12-31',
      );

      expect(
        einer,
        anderer,
        reason:
            'ohne Wertgleichheit baute jeder Lesevorgang ein neues, '
            'ungleiches Objekt — und Grundumsatz, Kalorienziel und der '
            'ganze Ernährungsschirm rechneten bei jedem Zugriff neu. Das '
            'wäre Fehler 03, wortgleich, im neuen Code',
      );
      expect(einer.hashCode, anderer.hashCode);
    });

    test('zwei leere Stammdaten sind ebenfalls gleich', () {
      expect(const Stammdaten(), const Stammdaten());
      expect(const Stammdaten().hashCode, const Stammdaten().hashCode);
    });

    test('ein einziges abweichendes Feld macht sie ungleich', () {
      const grund = Stammdaten(
        groesseCm: 211,
        geburtsjahr: 1904,
        zielgewichtKg: 33.3,
        zieldatum: '2099-12-31',
      );

      expect(
        grund,
        isNot(
          const Stammdaten(
            groesseCm: 142,
            geburtsjahr: 1904,
            zielgewichtKg: 33.3,
            zieldatum: '2099-12-31',
          ),
        ),
      );
      expect(
        grund,
        isNot(
          const Stammdaten(
            groesseCm: 211,
            geburtsjahr: 1888,
            zielgewichtKg: 33.3,
            zieldatum: '2099-12-31',
          ),
        ),
      );
      expect(
        grund,
        isNot(
          const Stammdaten(
            groesseCm: 211,
            geburtsjahr: 1904,
            zielgewichtKg: 199.9,
            zieldatum: '2099-12-31',
          ),
        ),
      );
      expect(
        grund,
        isNot(
          const Stammdaten(
            groesseCm: 211,
            geburtsjahr: 1904,
            zielgewichtKg: 33.3,
            zieldatum: '2088-01-01',
          ),
        ),
      );
    });

    test(
      'und ein fehlendes Feld ist nicht dasselbe wie ein eingetragenes',
      () {
        expect(
          const Stammdaten(groesseCm: 211),
          isNot(const Stammdaten()),
          reason:
              'genau diese Unterscheidung trägt den ganzen Schirm: '
              '"nichts eingetragen" ist nicht "0 eingetragen"',
        );
      },
    );
  });
}
