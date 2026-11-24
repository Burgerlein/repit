// `drift` exportiert eigene `isNull` und `isNotNull` (Spaltenausdrücke für
// `IS NULL` in Abfragen) — die verdecken sonst die gleichnamigen
// `package:matcher`-Matcher, die `expect(..., isNull)` unten braucht.
// Dieselbe Begründung wie in `test/data/schema_v12_test.dart`, Zeile 1–4,
// und in `test/ernaehrung/lebensmittel_repository_test.dart`, Zeile 1–5.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show Database, sqlite3;

import 'package:repit/data/cache.dart';

import 'schema_tabellen.dart';

/// Tests für **Schema v13** — `lebensmittel` bekommt seine Spalten (#285).
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden.
///
/// Nachbar von `schema_v7_test.dart` bis `schema_v12_test.dart`: derselbe
/// Aufbau, dieselben Hilfsmittel, von Hand gebaute Altstände.
///
/// ## Warum es diese Stufe gibt
///
/// `schema_v12_test.dart` hat fünf Tabellen angelegt und **nur `eintraege`
/// spaltengenau festgelegt**; die übrigen vier tragen seither bloß ihren
/// Schlüssel, „ihre Spalten entscheiden die Aufgaben, denen sie gehören"
/// (Dateikopf dort). #285 ist eine davon: Die Vorlagenhälfte der Ernährung
/// braucht `lebensmittel` mit Inhalt — Name, die acht Nährwerte je 100 g,
/// `extra`, `fluessig` und `zuletzt_benutzt`.
///
/// Damit ändert sich das Schema, und **jede Migration bekommt einen Test**
/// (`CLAUDE.md`). Dieser hier.
///
/// ## Was diese Datei verbindlich vorgibt
///
/// **1. `AppCache.schemaVersion == 13`** und eine **eigene Stufe**
/// `if (from < 13) { … }` — keine Erweiterung der v12-Stufe. Begründung wie
/// bei v3 bis v12 (`schema_v3_test.dart`, Dateikopf): Ein Gerät, das
/// zwischen zwei Tickets aktualisiert wurde, muss den Rest nachholen
/// können.
///
/// Die Nummer wurde am 04.11.2026 aus `cache.dart` **gelesen**, nicht
/// abgeschrieben: `grep -n "schemaVersion =>" app/lib/data/cache.dart`
/// meldete `12`, also ist die nächste freie die 13.
///
/// **2. `lebensmittel` trägt danach diese Spalten** (weitere sind erlaubt,
/// siehe unten):
///
/// | Spalte | Typ | NULL | Warum |
/// |---|---|---|---|
/// | `id` | INTEGER | — | Schlüssel, `AUTOINCREMENT`, steht seit v12 |
/// | `name` | TEXT | nein, Vorgabe `''` | eine Vorlage ohne Namen findet die Suche nicht |
/// | `kcal` … `wasser_ml` | REAL | **ja** | die acht Nährwerte je 100 g |
/// | `extra` | TEXT | nein, Vorgabe `'{}'` | JSON, die übrigen Nährwerte |
/// | `fluessig` | INTEGER | nein, Vorgabe `0` | g oder ml — sonst nichts |
/// | `zuletzt_benutzt` | TEXT | **ja** | angelegt ist nicht benutzt |
///
/// **3. Additiv.** Die Stufe hängt Spalten an und baut die Tabelle nicht
/// neu. Sie legt **keine Zeile** an und **füllt kein Feld**.
///
/// ## Entscheidung des Test-Agenten: dieselben Spaltennamen wie `eintraege`
///
/// **Nicht mit Tim abgestimmt, nicht freigegeben** — mit Begründung. Beide
/// Tabellen halten dieselbe Sache, einen `Naehrwerte`-Satz: `eintraege` den
/// eingefrorenen des gebuchten Eintrags, `lebensmittel` den der Vorlage je
/// 100 g. Dieselben acht Felder also dieselben acht Namen (`kcal`,
/// `eiweiss_g`, `kohlenhydrate_g`, `fett_g`, `zucker_g`, `ballaststoffe_g`,
/// `gesaettigt_g`, `wasser_ml`) und derselbe offene Rest (`extra`). Zwei
/// Schreibweisen für dasselbe Feld wären zwei Umwandlungen, die
/// auseinanderlaufen können — und die Zahlen wandern beim Buchen von der
/// einen Tabelle in die andere.
///
/// **Was hier bewusst `extra` heißt und nicht `extra_json`:** `eintraege`
/// nennt die Spalte `extra`, und sie trägt dasselbe.
///
/// ## Entscheidung des Test-Agenten: `name` ist NOT NULL mit Vorgabe `''`
///
/// **Nicht mit Tim abgestimmt, nicht freigegeben** — mit Begründung.
/// `LebensmittelVorlage.name` ist in `lebensmittel_repository_test.dart`
/// ein `required String`, also nicht nullbar; die treue Abbildung davon ist
/// `NOT NULL`, wie bei `Eintraege.name`.
///
/// Dann braucht die Spalte aber einen Vorgabewert: **SQLite lehnt
/// `ALTER TABLE … ADD COLUMN … NOT NULL` ohne Vorgabewert ab**, unabhängig
/// davon, ob Zeilen darin stehen — und genau diesen Weg nimmt diese Stufe,
/// und ebenso der Abgleich aus #233 auf einer Datei, auf der die Tabelle
/// von einem anderen Zweig schon steht. `''` ist dabei kein erfundener
/// Name, sondern das Eingeständnis, dass keiner dasteht; eine Vorlage ohne
/// Namen kann auf einem v12-Gerät gar nicht entstanden sein, weil es die
/// Spalte dort nicht gab und `lebensmittel` ohne sie nichts zu halten
/// hatte.
///
/// Dieselbe Überlegung trägt `extra` (`'{}'`, Abbild der nicht-nullbaren
/// `Naehrwerte.extra`) und `fluessig` (`0`, der Vorgabewert
/// `fluessig = false` aus `LebensmittelVorlage`).
///
/// `zuletzt_benutzt` ist dagegen **nullbar**: „angelegt ist nicht benutzt"
/// (`lebensmittel_repository_test.dart`). Ein Vorgabewert wäre hier ein
/// erfundener Zeitpunkt, und eine Migration trägt keinen nach — sie
/// behauptete sonst, Tim habe etwas gegessen, und sagte auch noch wann.
///
/// ## Entscheidung des Test-Agenten: `fluessig` ist INTEGER
///
/// **Nicht mit Tim abgestimmt, nicht freigegeben** — mit Begründung. SQLite
/// kennt keinen Wahrheitstyp; `drift`s `boolean()` legt eine
/// `INTEGER`-Spalte mit `CHECK (… IN (0, 1))` an. Geprüft wird deshalb
/// `INTEGER` und der Rundweg des Vorgabewerts, nicht die Form der Prüfung —
/// ob jemand den `CHECK` schreibt, ist eine Frage des Werkzeugs.
///
/// **Weitere Spalten sind erlaubt** — geprüft wird mit `containsAll`, wie
/// bei `eintraege` und `stammdaten`. Eine Einschränkung bleibt: **jede**
/// Spalte von `lebensmittel` muss nullbar sein oder einen Vorgabewert
/// haben, aus dem Grund oben. Das prüft diese Datei nicht nur am `PRAGMA`,
/// sondern von außen mit einem `INSERT … DEFAULT VALUES`: Was sich nicht
/// ohne Angaben einfügen lässt, lässt sich auch nicht nachträglich
/// anhängen.
///
/// ## Was diese Datei **nicht** beweisen kann
///
/// **Dass die Stufe `if (from < 13)` wirklich existiert.** Seit #233 hängt
/// `_reconcileSchema` an `beforeOpen` und legt bei **jedem** Öffnen an, was
/// die Datei gegenüber dem heutigen Schema vermissen lässt — fehlende
/// Tabellen **und fehlende Spalten**. Eine vergessene Stufe fiele deshalb
/// von außen nicht auf. Geprüft wird hier das Ergebnis, nicht die Bauform.
///
/// Die Stufe gehört trotzdem geschrieben, aus demselben Grund wie bei v11
/// und v12: Der Abgleich ist das Netz, nicht der Weg. Er kann nur Fehlendes
/// nachlegen, keine Daten umformen.
///
/// **Was `abgelegteVersion` dagegen sehr wohl belegt:** dass der Durchlauf
/// die Nummer aus `AppCache.schemaVersion` in der Datei festschreibt.
/// Bliebe sie auf 12, liefe auf Tims Gerät keine Stufe mehr, die er noch
/// nicht kennt — genau der Fall aus #233. Verglichen wird seit dem
/// 04.11.2026 gegen `db.schemaVersion` statt gegen die 13; die absolute
/// Zahl steht an genau einer Stelle, in `migration_test.dart` (#193,
/// #208). Diese Datei handelt von der Stufe 13, nicht von der heutigen
/// Nummer — die ist mit der Stufe 14 (#284) weitergerückt. Punkt 1 oben
/// heißt seitdem: mindestens 13.
///
/// **Alle Zahlen und Namen hier sind erfunden** und bewusst weit von Tims
/// Werten entfernt. Die Tagesschlüssel liegen im Jahr 2099, damit sie
/// keinen Termin nachahmen.
void main() {
  /// Schema v12: der Stand vor diesem Ticket — dreizehn Tabellen, und
  /// `lebensmittel` trägt nur ihren Schlüssel.
  ///
  /// **Von Hand geschrieben, nicht aus dem heutigen Code erzeugt** — ein
  /// Schema, das aus dem heutigen Code entsteht, ist kein Altschema,
  /// sondern das neue, und bewiese nichts (`migration_test.dart`,
  /// Dateikopf).
  const v12Schema = '''
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
    CREATE TABLE stammdaten (
      id INTEGER NOT NULL DEFAULT 0,
      groesse_cm INTEGER,
      geburtsjahr INTEGER,
      zielgewicht_kg REAL,
      zieldatum TEXT,
      PRIMARY KEY (id)
    );
    CREATE TABLE lebensmittel (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT
    );
    CREATE TABLE portionen (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT
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
      health_stand TEXT NOT NULL DEFAULT 'offen'
    );
    CREATE TABLE rezepte (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT
    );
    CREATE TABLE rezept_zutaten (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT
    );
  ''';

  /// `lebensmittel`, wie ein **anderer Zweig** sie halb ausgebaut haben
  /// könnte — alle bauen unter derselben Bundle-ID und benutzen dieselbe
  /// Datei (#234/#240). `name` und `kcal` stehen schon, der Rest fehlt.
  ///
  /// **Halb und nicht ganz**, und das ist Absicht: Eine Stufe, die beim
  /// ersten vorhandenen Stück abbricht, ließe die halb gelaufene Stufe für
  /// immer halb — dieselbe Begründung wie bei `_addColumnIfMissing`, je
  /// Spalte statt je Stufe.
  const v12SchemaHalbesLebensmittel = '''
    CREATE TABLE lebensmittel (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL DEFAULT '',
      kcal REAL
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

  /// Was in den acht alten Tabellen eines v12-Geräts liegt. **Die
  /// Tageswerte sind Tims einzige Offline-Quelle** — eine Migration, die
  /// hier etwas verlöre, verlöre es endgültig.
  const alterBestand = '''
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
    INSERT INTO stammdaten (id, groesse_cm, geburtsjahr, zielgewicht_kg,
                            zieldatum)
      VALUES (0, 211, 1904, 33.3, '2099-12-31');
  ''';

  /// Eine gebuchte Mahlzeit und eine Vorlage ohne Inhalt — der Zustand, in
  /// dem v12 eine `lebensmittel`-Zeile überhaupt zulässt: nur ein
  /// Schlüssel, es gab ja keine andere Spalte.
  const ernaehrungsBestand = '''
    INSERT INTO eintraege
      (tages_schluessel, mahlzeit, zeitpunkt, lebensmittel_id, name, menge_g,
       kcal, eiweiss_g, kohlenhydrate_g, fett_g, zucker_g, ballaststoffe_g,
       gesaettigt_g, wasser_ml, extra, health_uuid, health_stand)
      VALUES ('2099-03-01', 'abend', '2099-03-01T18:30:00.000Z', 1,
              'Grützwurst mit Kompott', 333.3,
              1234.5, 11.1, 22.2, 33.3, 44.4, 55.5, 66.6, 77.7,
              '{}', NULL, 'offen');
    INSERT INTO lebensmittel (id) VALUES (1);
  ''';

  /// Der Bestand eines v1-Geräts — nur, was es damals gab.
  const v1Bestand = '''
    INSERT INTO tages_werte (tag, schritte, ruhepuls_bpm)
      VALUES ('2099-03-01', 4242, 99);
  ''';

  /// Die acht Nährwertspalten je 100 g — alle REAL, alle nullbar, benannt
  /// wie in `eintraege`.
  const achtNaehrwerte = [
    'kcal',
    'eiweiss_g',
    'kohlenhydrate_g',
    'fett_g',
    'zucker_g',
    'ballaststoffe_g',
    'gesaettigt_g',
    'wasser_ml',
  ];

  /// Die zwölf Spalten, die diese Stufe an `lebensmittel` hängt.
  const neueSpalten = [
    'name',
    ...achtNaehrwerte,
    'extra',
    'fluessig',
    'zuletzt_benutzt',
  ];

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

  /// Der `CREATE TABLE`-Text, wie SQLite ihn aufbewahrt hat.
  Future<String> tabellenText(AppCache db, String tabelle) async {
    final zeile = await db
        .customSelect(
          "SELECT sql FROM sqlite_master WHERE type = 'table' "
          'AND name = ?;',
          variables: [Variable<String>(tabelle)],
        )
        .getSingle();
    return zeile.read<String>('sql');
  }

  /// Die Spalten einer Tabelle, so wie sie wirklich in der Datei stehen:
  /// Name, Typ, ob NULL erlaubt ist, ob sie zum Schlüssel gehört und
  /// welchen Vorgabewert sie trägt.
  ///
  /// `vorgabe` ist der rohe `dflt_value`-Text aus `PRAGMA table_info` — für
  /// eine Spalte ohne Vorgabewert `null`. Verglichen wird damit nur auf
  /// „es gibt einen"; wie SQLite ihn schreibt, ist nicht Gegenstand dieses
  /// Tests, und der Rundweg unten prüft ihn ohnehin von außen.
  ///
  /// `PRAGMA` nimmt keine Platzhalter, der Name steht deshalb im Text — er
  /// stammt hier ausschließlich aus Konstanten dieser Datei.
  Future<
    Map<String, ({String typ, bool nullbar, bool schluessel, String? vorgabe})>
  >
  spalten(AppCache db, String tabelle) async {
    final zeilen = await db.customSelect('PRAGMA table_info($tabelle);').get();
    return {
      for (final z in zeilen)
        z.read<String>('name'): (
          typ: z.read<String>('type').toUpperCase(),
          nullbar: z.read<int>('notnull') == 0,
          schluessel: z.read<int>('pk') > 0,
          vorgabe: z.data['dflt_value'] as String?,
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

  /// Die einzige Zeile einer Tabelle, roh — Spalte für Spalte, so wie sie
  /// in der Datei steht. Ohne den erzeugten Zugriff, damit der Test auch
  /// dann noch etwas aussagt, wenn jemand die Abbildung ändert.
  Future<Map<String, Object?>> einzigeZeile(AppCache db, String tabelle) async {
    final zeile = await db.customSelect('SELECT * FROM $tabelle;').getSingle();
    return zeile.data;
  }

  /// SQLite erhöht `PRAGMA schema_version` bei jedem `CREATE`, `ALTER` und
  /// `DROP` — und sonst nie. Der Stempel belegt also nicht nur, dass eine
  /// Spalte da ist, sondern ob beim Öffnen überhaupt etwas am Schema
  /// angefasst wurde.
  Future<int> schemaStempel(AppCache db) async {
    final zeile = await db.customSelect('PRAGMA schema_version;').getSingle();
    return zeile.read<int>('schema_version');
  }

  // ---------------------------------------------------------------------

  group('Schema v13 — lebensmittel bekommt seine Spalten', () {
    test('die Datenbank steht mindestens auf Version 13', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      expect(
        db.schemaVersion,
        greaterThanOrEqualTo(13),
        reason:
            'eine eigene Stufe, keine Erweiterung der v12-Stufe: Ein Gerät, '
            'das zwischen zwei Tickets aktualisiert wurde, muss den Rest '
            'nachholen können. Bliebe die Nummer auf 12, liefe auf Tims '
            'Gerät keine Stufe mehr, die es noch nicht kennt (#233). Seit '
            'der Stufe 14 (Strichcode und Herkunft, #284) steht die Zahl '
            'höher; die genaue Zahl zählt `migration_test.dart`, hier geht '
            'es nur darum, dass die Stufe dieses Tickets überhaupt '
            'dazugehört',
      );
      expect(
        await abgelegteVersion(db),
        db.schemaVersion,
        reason:
            'die Nummer in der Datei und die im Code sagen dasselbe — sonst '
            'behauptet die eine einen Stand, den die andere nicht hat',
      );
    });

    test('eine frisch angelegte Datei bringt sie gleich mit', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      expect(
        await tabellen(db),
        tabellenHeute,
        reason:
            'dieses Ticket legt keine Tabelle an und nimmt keine weg — es '
            'füllt eine bestehende',
      );
      expect(
        (await spalten(db, 'lebensmittel')).keys,
        containsAll(neueSpalten),
        reason:
            '`onCreate` baut das heutige Schema. Eine Spalte, die es nur '
            'nach einer Migration gäbe, fehlte auf jedem neuen Gerät',
      );
    });
  });

  group('Migration v12 → v13 — additiv, zwölf Spalten an lebensmittel', () {
    QueryExecutor v12Cache() =>
        altstand(v12Schema, '$alterBestand$ernaehrungsBestand', 12);

    test('die Datenbank steht danach auf der heutigen Version', () async {
      final db = AppCache(v12Cache());
      addTearDown(db.close);

      // Gegen `AppCache.schemaVersion` statt gegen eine eigene Zahl — das
      // ist die Regelung seit #193 (nachzulesen in `migration_test.dart`):
      // Sonst fällt bei jeder neuen Stufe auch ein Fall, der von einer
      // alten handelt. Hier geht es darum, dass der Durchlauf die Nummer
      // festschreibt, nicht darum, welche Nummer das heute ist.
      expect(await abgelegteVersion(db), db.schemaVersion);
    });

    test('die Tabellen stehen danach alle noch da', () async {
      final db = AppCache(v12Cache());
      addTearDown(db.close);

      expect(
        await tabellen(db),
        tabellenHeute,
        reason:
            'additiv heißt: Diese Stufe hängt Spalten an und nimmt nichts '
            'weg. Eine Tabelle, die dabei verschwände, nähme Tims einzige '
            'Offline-Quelle mit',
      );
    });

    test('lebensmittel trägt danach die zwölf neuen Spalten', () async {
      final db = AppCache(v12Cache());
      addTearDown(db.close);

      final gefunden = await spalten(db, 'lebensmittel');

      expect(
        gefunden.keys,
        containsAll(neueSpalten),
        reason:
            'weitere Spalten sind erlaubt — geprüft wird mit containsAll, '
            'wie schon bei eintraege und stammdaten. Fehlen darf keine '
            'davon',
      );
      expect(
        gefunden['id']!.schluessel,
        isTrue,
        reason: 'der Schlüssel steht seit v12 und bleibt, wo er ist',
      );
    });

    test('die acht Nährwertspalten sind REAL und nullbar', () async {
      final db = AppCache(v12Cache());
      addTearDown(db.close);

      final gefunden = await spalten(db, 'lebensmittel');

      for (final feld in achtNaehrwerte) {
        expect(
          gefunden[feld]!.typ,
          'REAL',
          reason: '$feld ist ein double? in Naehrwerte, also REAL',
        );
        expect(
          gefunden[feld]!.nullbar,
          isTrue,
          reason:
              '$feld muss fehlen dürfen. Ein Lebensmittel ohne Angabe hat '
              'nicht 0 davon, sondern keine Angabe — #232 ist genau dieser '
              'Fehler in der Altapp. Eine gewogene Null bleibt dagegen 0, '
              'und die steht dann auch da',
        );
      }
    });

    test('name, extra, fluessig und zuletzt_benutzt haben ihre Form', () async {
      final db = AppCache(v12Cache());
      addTearDown(db.close);

      final gefunden = await spalten(db, 'lebensmittel');

      expect(gefunden['name']!.typ, 'TEXT');
      expect(
        gefunden['name']!.nullbar,
        isFalse,
        reason:
            'LebensmittelVorlage.name ist ein required String. Eine Vorlage '
            'ohne Namen fände die Suche nicht und das Buchungsblatt zeigte '
            'eine leere Zeile',
      );
      expect(
        gefunden['name']!.vorgabe,
        isNotNull,
        reason:
            'NOT NULL ohne Vorgabewert lässt sich nicht anhängen — SQLite '
            'lehnt ALTER TABLE … ADD COLUMN … NOT NULL ohne DEFAULT ab, und '
            'genau diesen Weg nimmt diese Stufe',
      );

      expect(
        gefunden['extra']!.typ,
        'TEXT',
        reason:
            'die übrigen Nährwerte als JSON — so ist der spätere '
            'Vitamin-Schirm eine Ansicht und keine Migration. Benannt wie '
            'in eintraege, weil beide dasselbe halten',
      );
      expect(
        gefunden['extra']!.nullbar || gefunden['extra']!.vorgabe != null,
        isTrue,
        reason:
            'Naehrwerte.extra ist eine nicht-nullbare Map; das leere Objekt '
            'ist ihr genaues Abbild. Zwei Schreibweisen für „keine weiteren '
            'Werte" wären eine zu viel',
      );

      expect(
        gefunden['fluessig']!.typ,
        'INTEGER',
        reason:
            'SQLite kennt keinen Wahrheitstyp; drifts boolean() legt eine '
            'INTEGER-Spalte an. Die Spalte entscheidet über g oder ml — '
            'sonst nichts',
      );
      expect(
        gefunden['fluessig']!.nullbar || gefunden['fluessig']!.vorgabe != null,
        isTrue,
        reason:
            'LebensmittelVorlage.fluessig steht vorgabemäßig auf falsch — '
            'ein Lebensmittel ohne Angabe ist fest, nicht unbekannt',
      );

      expect(
        gefunden['zuletzt_benutzt']!.typ,
        'TEXT',
        reason:
            'AppCache arbeitet mit storeDateTimeAsText: true. Drifts '
            'Standard (Unix-Sekunden) gäbe den Zeitpunkt als lokale Zeit '
            'zurück, und ein als UTC abgelegter Wert wäre danach ungleich '
            'sich selbst (`CLAUDE.md`)',
      );
      expect(
        gefunden['zuletzt_benutzt']!.nullbar,
        isTrue,
        reason:
            'angelegt ist nicht benutzt. Ein Vorgabewert wäre hier ein '
            'erfundener Zeitpunkt, und „nie benutzt" ist in der Reihenfolge '
            'der Suche ein eigener Fall',
      );
    });

    test(
      'jede Spalte ist nullbar oder hat einen Vorgabewert — sonst ließe sie '
      'sich gar nicht anhängen',
      () async {
        final db = AppCache(v12Cache());
        addTearDown(db.close);

        final gefunden = await spalten(db, 'lebensmittel');
        expect(
          gefunden.keys,
          containsAll(neueSpalten),
          reason:
              'Vorbedingung — ohne die zwölf Spalten prüft die Schleife '
              'unten nur den Schlüssel und ginge auch auf dem alten Stand '
              'durch',
        );

        for (final eintrag in gefunden.entries) {
          if (eintrag.value.schluessel) continue;
          expect(
            eintrag.value.nullbar || eintrag.value.vorgabe != null,
            isTrue,
            reason:
                '${eintrag.key}: SQLite lehnt ALTER TABLE … ADD COLUMN … '
                'NOT NULL ohne Vorgabewert ab, unabhängig davon, ob Zeilen '
                'darin stehen. Diese Stufe nimmt genau diesen Weg, und der '
                'Abgleich aus #233 ebenso auf einer Datei, auf der die '
                'Tabelle von einem anderen Zweig schon steht',
          );
        }

        // Dasselbe von außen, und zwar für jede Spalte, die es gibt — auch
        // für die, die diese Datei nicht kennt: Was sich ohne Angaben
        // einfügen lässt, lässt sich auch nachträglich anhängen.
        await db.customStatement('INSERT INTO lebensmittel DEFAULT VALUES;');

        expect(await zeilenZahl(db, 'lebensmittel'), 2);
      },
    );

    test('und die Vorgabewerte sind die, die der Vertrag verlangt', () async {
      final db = AppCache(v12Cache());
      addTearDown(db.close);

      // Zwei Aufrufe, nicht einer mit Semikolon: `customStatement` reicht
      // genau ein Statement durch.
      await db.customStatement('DELETE FROM lebensmittel;');
      await db.customStatement('INSERT INTO lebensmittel DEFAULT VALUES;');
      final zeile = await einzigeZeile(db, 'lebensmittel');

      expect(
        zeile['name'],
        '',
        reason:
            'der leere Name ist kein erfundener Name, sondern das '
            'Eingeständnis, dass keiner dasteht',
      );
      expect(
        zeile['extra'],
        '{}',
        reason: 'das leere JSON-Objekt ist das Abbild einer leeren Map',
      );
      expect(
        zeile['fluessig'],
        anyOf(0, false),
        reason: 'vorgabemäßig fest, nicht flüssig — gewogen wird in Gramm',
      );
      expect(
        zeile['zuletzt_benutzt'],
        isNull,
        reason:
            'nicht „jetzt" und nicht DateTime(0): Angelegt ist nicht '
            'benutzt',
      );
      for (final feld in achtNaehrwerte) {
        expect(
          zeile[feld],
          isNull,
          reason:
              '$feld ohne Angabe ist keine Angabe und keine 0 — sonst '
              'behauptete die Vorlage einen Messwert',
        );
      }
    });

    test(
      'die Stufe legt keine Zeile an und füllt kein Feld',
      () async {
        final db = AppCache(v12Cache());
        addTearDown(db.close);

        expect(
          await zeilenZahl(db, 'lebensmittel'),
          1,
          reason:
              'genau die eine, die vorher dastand. Eine nachgelegte Zeile '
              'wäre eine Vorlage, die niemand angelegt hat',
        );
        for (final tabelle in ['portionen', 'rezepte', 'rezept_zutaten']) {
          expect(
            await zeilenZahl(db, tabelle),
            0,
            reason: '$tabelle gehört dieser Stufe nicht und bleibt leer',
          );
        }

        final zeile = await einzigeZeile(db, 'lebensmittel');
        expect(
          zeile['id'],
          1,
          reason:
              'der Schlüssel bleibt — eintraege.lebensmittel_id zeigt '
              'darauf, und eine neu vergebene Nummer hinge den gebuchten '
              'Eintrag an eine fremde Vorlage',
        );
        expect(
          zeile['zuletzt_benutzt'],
          isNull,
          reason:
              'die Migration trägt keinen Zeitpunkt nach. Ein nachgelegtes '
              '„jetzt" behauptete, Tim habe das gerade gegessen',
        );
        expect(
          zeile['name'],
          '',
          reason:
              'der Vorgabewert, kein erfundener Name. Auf einem v12-Gerät '
              'gab es die Spalte nicht, also weiß niemand mehr, wie die '
              'Vorlage hieß — und ein ausgedachter Name wäre eine falsche '
              'Auskunft',
        );
        for (final feld in achtNaehrwerte) {
          expect(
            zeile[feld],
            isNull,
            reason:
                '$feld steht auf NULL, nicht auf 0. Eine nachgezogene Spalte '
                'ist leer, und erfundene Nullwerte wären schlimmer als die '
                'Lücke (Fehler `01`)',
          );
        }
      },
    );

    test(
      'und jede Zeile der zwölf übrigen Tabellen überlebt feldweise '
      'unverändert',
      () async {
        final db = AppCache(v12Cache());
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
        expect(nacht.gelesenAm, DateTime.utc(2099, 3, 1, 9));
        expect(nacht.ruhepulsBpm, 88.8);
        expect(nacht.hrvMs, 12.5);
        expect(nacht.respRate, 44.4);

        expect(await db.select(db.schlafAbschnitte).get(), hasLength(1));

        final ziele = (await db.select(db.zielWerte).get()).single;
        expect(
          ziele.wochenzielTrainingsminuten,
          321,
          reason:
              'eine Migration, die Spalten anhängt, fasst keine fremde '
              'Tabelle an — Tims eingestellte Ziele sind nicht Gegenstand '
              'dieses Tickets',
        );

        final nachtrag = (await db.select(db.schlafEintraege).get()).single;
        expect(nachtrag.schlafMinuten, 417);
        expect(nachtrag.notiz, 'Uhr vergessen');

        final stamm = (await db.select(db.stammdaten).get()).single;
        expect(stamm.groesseCm, 211);
        expect(stamm.geburtsjahr, 1904);
        expect(stamm.zielgewichtKg, 33.3);
        expect(stamm.zieldatum, '2099-12-31');

        // Die gebuchte Mahlzeit, roh aus der Datei gelesen: Sie gehört
        // nicht dieser Stufe und muss sie unangetastet überstehen.
        final eintrag = await einzigeZeile(db, 'eintraege');
        expect(eintrag['tages_schluessel'], '2099-03-01');
        expect(eintrag['mahlzeit'], 'abend');
        expect(eintrag['zeitpunkt'], '2099-03-01T18:30:00.000Z');
        expect(eintrag['lebensmittel_id'], 1);
        expect(
          eintrag['name'],
          'Grützwurst mit Kompott',
          reason:
              'der Eintrag hält seine eigenen Zahlen und seinen eigenen '
              'Namen. Was an der Vorlage passiert, geht ihn nichts an',
        );
        expect(eintrag['menge_g'], 333.3);
        expect(eintrag['kcal'], 1234.5);
        expect(eintrag['wasser_ml'], 77.7);
        expect(eintrag['extra'], '{}');
        expect(eintrag['health_uuid'], isNull);
        expect(eintrag['health_stand'], 'offen');
      },
    );

    test('und die Datei ist danach ganz normal benutzbar', () async {
      final db = AppCache(v12Cache());
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
    /// Nummer zu niedrig, `name` und `kcal` schon da: Ein anderer Zweig hat
    /// die Spalten unter derselben Bundle-ID in dieselbe Datei gelegt, die
    /// Nummer steht aber noch auf 12. Ein `ALTER TABLE … ADD COLUMN` ohne
    /// Nachsehen stürbe hier mit `duplicate column name` — und zwar beim
    /// **Öffnen**, danach wäre die Datenbank gar nicht mehr zu benutzen.
    QueryExecutor vorweggenommen() {
      final schema = v12Schema.replaceFirst(
        '''
    CREATE TABLE lebensmittel (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT
    );
''',
        v12SchemaHalbesLebensmittel,
      );
      return altstand(
        schema,
        '$alterBestand'
        "INSERT INTO lebensmittel (id, name, kcal) "
        "VALUES (1, 'Grützwurst roh', 456.7);",
        12,
      );
    }

    test('der Altstand ist wirklich halb — sonst prüft der Rest nichts', () {
      expect(
        v12Schema,
        contains('''
    CREATE TABLE lebensmittel (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT
    );
'''),
        reason:
            'die Ersetzung oben muss greifen. Greift sie nicht, läuft die '
            'ganze Gruppe gegen den unveränderten v12-Stand und belegt den '
            'Fall gar nicht',
      );
    });

    test('die Datenbank lässt sich überhaupt öffnen', () async {
      final db = AppCache(vorweggenommen());
      addTearDown(db.close);

      expect(
        await zeilenZahl(db, 'lebensmittel'),
        isNonNegative,
        reason:
            'die erste Abfrage löst das Öffnen aus. Wirft die Stufe, kommt '
            'es hier an — und auf dem Gerät gar nicht mehr weiter',
      );
      expect(await abgelegteVersion(db), db.schemaVersion);
    });

    test('die übrigen Spalten kommen trotzdem dazu', () async {
      final db = AppCache(vorweggenommen());
      addTearDown(db.close);

      expect(
        (await spalten(db, 'lebensmittel')).keys,
        containsAll(neueSpalten),
        reason:
            'eine Stufe, die beim ersten vorhandenen Stück abbricht, ließe '
            'die halb gelaufene Stufe für immer halb — dieselbe Begründung '
            'wie bei _addColumnIfMissing, je Spalte statt je Stufe',
      );
    });

    test(
      'und die vorweggenommene Zeile überlebt — die Tabelle wird nicht neu '
      'gebaut',
      () async {
        final db = AppCache(vorweggenommen());
        addTearDown(db.close);

        final zeile = await einzigeZeile(db, 'lebensmittel');
        expect(zeile['id'], 1);
        expect(
          zeile['name'],
          'Grützwurst roh',
          reason:
              'ein vorsorgliches DROP TABLE IF EXISTS vor dem CREATE wäre '
              'eine Stufe, die nie scheitert und trotzdem Tims angelegte '
              'Vorlagen löscht — schlimmer als der Absturz, den sie behebt. '
              'Und ein Neubau mit Umkopieren kann Zeilen verlieren',
        );
        expect(
          zeile['kcal'],
          456.7,
          reason:
              'eine vorhandene Spalte wird nicht geleert. Ein vorhandener '
              'Wert ist Tims Wert',
        );
        expect(zeile['zuletzt_benutzt'], isNull);

        expect(
          (await tabellenText(db, 'lebensmittel')).toUpperCase(),
          contains('AUTOINCREMENT'),
          reason:
              'anhängen heißt anhängen: Der Schlüssel behält seine Form. '
              'Ohne AUTOINCREMENT vergäbe SQLite nach einer Löschung '
              'dieselbe Zeilennummer erneut, und ein gebuchter Eintrag '
              'hinge lautlos an einer fremden Vorlage',
        );

        expect(await db.select(db.tagesWerte).get(), hasLength(1));
      },
    );

    test(
      'zweites Öffnen derselben Datei: nichts wird angefasst, nichts geht '
      'verloren',
      () async {
        final roh = rohdatei(
          v12Schema,
          '$alterBestand$ernaehrungsBestand',
          12,
        );
        addTearDown(roh.dispose);

        final erstesMal = ueber(roh);
        expect(
          (await spalten(erstesMal, 'lebensmittel')).keys,
          containsAll(neueSpalten),
          reason: 'Vorbedingung',
        );
        final stempelNachDerStufe = await schemaStempel(erstesMal);
        await erstesMal.close();

        // Zweites Öffnen: Die Nummer steht schon oben, `onUpgrade` läuft
        // gar nicht. Was hier noch laufen kann, ist allein `beforeOpen`.
        final zweitesMal = ueber(roh);
        addTearDown(zweitesMal.close);

        expect(
          (await spalten(zweitesMal, 'lebensmittel')).keys,
          containsAll(neueSpalten),
        );
        expect(
          await schemaStempel(zweitesMal),
          stempelNachDerStufe,
          reason:
              'SQLite erhöht `PRAGMA schema_version` bei jedem CREATE, '
              'ALTER und DROP und sonst nie. Gleich heißt: beim zweiten '
              'Öffnen ist kein einziges Statement gegen das Schema '
              'gelaufen — die Stufe hat nicht noch einmal angehängt',
        );
        expect(await zeilenZahl(zweitesMal, 'lebensmittel'), 1);
      },
    );
  });

  group('Der Weg von unten', () {
    test('ein Gerät auf v1 kommt ganz oben an — über die Stufe 13 hinweg',
        () async {
      final db = AppCache(altstand(v1Schema, v1Bestand, 1));
      addTearDown(db.close);

      expect(await abgelegteVersion(db), db.schemaVersion);
      expect(await tabellen(db), tabellenHeute);
      expect(
        (await spalten(db, 'lebensmittel')).keys,
        containsAll(neueSpalten),
        reason: 'auch auf dem längsten Weg kommt jede Stufe zum Zug',
      );

      final zeile = (await db.select(db.tagesWerte).get()).single;
      expect(
        zeile.schritte,
        4242,
        reason:
            'sein Tageswert überlebt zwölf Stufen am Stück. Verlöre eine '
            'davon ihn, wäre er endgültig weg',
      );
      expect(zeile.ruhepulsBpm, 99);
      expect(
        zeile.gelesenAm,
        isNull,
        reason:
            'v1 kannte die Spalte nicht — woher die Zeile stammt, weiß '
            'niemand mehr, und ein nachgetragenes "jetzt" wäre gelogen',
      );

      expect(
        await zeilenZahl(db, 'lebensmittel'),
        0,
        reason:
            'die Vorlagen kommen leer, auch auf dem längsten Weg. Eine '
            'nachgelegte Zeile wäre ein Lebensmittel, das niemand angelegt '
            'hat',
      );
    });
  });
}
