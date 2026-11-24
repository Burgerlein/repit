// `drift` exportiert ein eigenes `isNull` (Spaltenausdruck für `IS NULL` in
// Abfragen) — das verdeckt sonst den gleichnamigen `package:matcher`-Matcher,
// den `expect(..., isNull)` unten braucht. Dieselbe Begründung wie in
// `test/data/schema_v11_test.dart`, Zeile 1–4.
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show Database, sqlite3;

import 'package:repit/data/cache.dart';
import 'package:repit/data/ernaehrung_repository.dart';

import 'schema_tabellen.dart';

/// Tests für **Schema v12** — die fünf Ernährungstabellen kommen dazu
/// (Task 3 des Ernährungsplans,
/// `docs/superpowers/plans/2026-11-03-ernaehrung.md`).
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden.
///
/// Nachbar von `schema_v7_test.dart` bis `schema_v11_test.dart`: derselbe
/// Aufbau, dieselben Hilfsmittel, von Hand gebaute Altstände.
///
/// ## Warum es diese Tabellen gibt
///
/// Die eigene Tabelle ist die Wahrheit, Apple Health bekommt eine Kopie —
/// am 03.11.2026 hat Tim die Richtung umgedreht. Damit braucht der
/// Ernährungsschirm einen eigenen Speicher: `lebensmittel` und `portionen`
/// als Vorlage, `eintraege` als Tatsache, `rezepte` und `rezept_zutaten`
/// für das Gekochte.
///
/// **Diese Datei legt `eintraege` fest und sonst keine Spalte.** Die
/// übrigen vier Tabellen müssen entstehen — ihre Spalten entscheiden die
/// Aufgaben, denen sie gehören (Open Food Facts in Task 6, Rezepte in
/// Task 8). Eine Spaltenliste hier wäre eine Entscheidung über Code, den
/// niemand geschrieben hat, und der Erste, der ein Feld braucht, müsste
/// einen Test ändern, den er nicht ändern darf.
///
/// ## API, die diese Tests verbindlich vorgeben
///
/// **1. `AppCache.schemaVersion == 12`** und eine **eigene Stufe**
/// `if (from < 12) { … }` — keine Erweiterung der v11-Stufe. Begründung wie
/// bei v3 bis v11 (`schema_v3_test.dart`, Dateikopf): Ein Gerät, das
/// zwischen zwei Tickets aktualisiert wurde, muss den Rest nachholen
/// können.
///
/// Die Nummer wurde am 04.11.2026 aus `cache.dart` **gelesen**, nicht
/// abgeschrieben: `grep -n "schemaVersion =>" app/lib/data/cache.dart`
/// meldete `11`, also ist die nächste freie die 12. Dieselbe Begründung wie
/// bei #235 — eine Nummer sagt nicht, welches Ticket zuerst fertig war,
/// sondern was ein Gerät schon ausgeführt hat.
///
/// **2. Fünf Tabellen**, in der Datei `lebensmittel`, `portionen`,
/// `eintraege`, `rezepte` und `rezept_zutaten`.
///
/// **3. `eintraege` trägt diese Spalten** (weitere sind erlaubt, siehe
/// unten):
///
/// | Spalte | Typ | NULL | Warum |
/// |---|---|---|---|
/// | `id` | INTEGER | — | Schlüssel, `AUTOINCREMENT` |
/// | `tages_schluessel` | TEXT | nein | ISO-Tagesstring, **der Esstag** |
/// | `mahlzeit` | TEXT | nein | `fruehstueck`/`mittag`/`snack`/`abend` |
/// | `zeitpunkt` | TEXT | nein | UTC-Zeitpunkt als Text |
/// | `lebensmittel_id` | INTEGER | **ja** | Schnelleintrag hat keines |
/// | `name` | TEXT | nein | was auf dem Teller lag |
/// | `menge_g` | REAL | **ja** | der Schnelleintrag wiegt nichts |
/// | `kcal` … `wasser_ml` | REAL | **ja** | die acht eingefrorenen Werte |
/// | `extra` | TEXT | — | JSON, die übrigen Nährwerte |
/// | `health_uuid` | TEXT | **ja** | erst nach dem Schreiben bekannt |
/// | `health_stand` | TEXT | nein | `offen`/`geschrieben`/`nicht_moeglich` |
///
/// - **`AUTOINCREMENT` auf `id`, nicht nur `INTEGER PRIMARY KEY`.** Ohne
///   das vergibt SQLite nach einer Löschung dieselbe Zeilennummer erneut.
///   Der Health-Nachlauf merkt sich IDs offener Einträge und ruft später
///   `setzeHealthStand(id, …)` — eine wiederverwendete ID setzte den Stand
///   eines **fremden** Eintrags, und zwar lautlos.
/// - **`menge_g` ist nullbar**, und das ist eine Entscheidung, die der Plan
///   offenließ. Der Schnelleintrag „nur Kalorien" trägt laut Entwurf „einen
///   Namen und seine eingefrorenen Nährwerte und sonst nichts" — er hat
///   kein Gewicht. Eine `NOT NULL`-Spalte zwänge dort zu einer `0`, und
///   „0 g gegessen" ist eine Behauptung, kein fehlender Wert (`CLAUDE.md`,
///   „`0` ist keine Antwort auf ‚kein Wert'"). Das ist `#232` eine Etage
///   tiefer.
/// - **`zeitpunkt` ist TEXT, nicht INTEGER.** `AppCache` arbeitet mit
///   `storeDateTimeAsText: true`; drifts Standard gäbe den Zeitpunkt als
///   **lokale** Zeit zurück, und ein als UTC abgelegter Wert wäre danach
///   ungleich sich selbst (`CLAUDE.md`).
/// - **`tages_schluessel` ist der Esstag, nicht der Kalendertag des
///   Zeitpunkts.** Der Abend läuft bis 03:59; ein Eintrag um 01:30 gehört
///   zum Abend davor. Die beiden Felder weichen dann um einen Tag
///   voneinander ab, und genau deshalb gibt es beide. Geprüft wird das in
///   `ernaehrung_repository_test.dart`.
///
/// **Weitere Spalten sind erlaubt** — geprüft wird mit `containsAll`, wie
/// schon bei `stammdaten`. Eine Einschränkung bleibt trotzdem: Eine
/// zusätzliche Spalte muss **nullbar sein oder einen Vorgabewert haben**.
/// SQLite lehnt `ALTER TABLE … ADD COLUMN … NOT NULL` ohne Vorgabewert ab,
/// unabhängig davon, ob Zeilen darin stehen — und genau diesen Weg nimmt
/// der Abgleich aus #233 auf einer Datei, in der die Tabelle von einem
/// anderen Zweig schon steht. Das ist keine Schikane dieses Tests, sondern
/// die Form, die jede nachträglich ergänzbare Spalte haben muss.
///
/// **4. In `lib/data/ernaehrung_repository.dart`** liegen `Eintrag`,
/// `HealthStand` und `ErnaehrungRepository`; ihr Vertrag steht vollständig
/// in `ernaehrung_repository_test.dart`. Diese Datei benutzt davon nur
/// `ErnaehrungRepository(db).eintraegeAmTag(...)`, um zu belegen, dass die
/// Migration keine Zeile anlegt.
///
/// **Die Tabellenklassen gehören nach `lib/data/ernaehrung_tabellen.dart`**
/// (so der Plan) und tragen `@DataClassName('…Row')` wie `StammdatenRow`
/// und `ZielWerteRow` — sonst kollidiert die erzeugte Datenklasse mit dem
/// Werttyp `Eintrag`, sobald eine Datei beides importiert. Die Tests unten
/// fragen die Tabellen über `customSelect` und legen den Namen der
/// Datenklasse damit nicht fest.
///
/// ## Was diese Datei **nicht** beweisen kann
///
/// **Dass die Stufe `if (from < 12)` wirklich existiert.** Seit #233 hängt
/// `_reconcileSchema` an `beforeOpen` und legt bei **jedem** Öffnen an, was
/// die Datei gegenüber dem heutigen Schema vermissen lässt. Eine vergessene
/// Stufe fiele deshalb von außen nicht auf — die Tabellen stünden trotzdem
/// da. Geprüft wird hier also das Ergebnis, nicht die Bauform.
///
/// Die Stufe gehört trotzdem geschrieben, aus demselben Grund wie bei v11:
/// Der Abgleich ist das Netz, nicht der Weg. Er kann nur Fehlendes
/// nachlegen, keine Daten umformen — wer die Stufe weglässt, merkt das beim
/// ersten Ticket, das mehr braucht als eine leere Tabelle.
///
/// **Was `abgelegteVersion` dagegen sehr wohl belegt:** dass der Durchlauf
/// die Nummer aus `AppCache.schemaVersion` in der Datei festschreibt.
/// Bliebe sie auf 11, liefe auf Tims Gerät keine Stufe mehr, die er noch
/// nicht kennt — genau der Fall aus #233. Verglichen wird seit dem
/// 04.11.2026 gegen `db.schemaVersion` statt gegen die 12; die absolute
/// Zahl steht an genau einer Stelle, in `migration_test.dart` (#193,
/// #208). Diese Datei handelt von der Stufe 12, nicht von der heutigen
/// Nummer — die ist mit der Stufe 13 weitergerückt.
///
/// **Alle Zahlen hier sind erfunden** und bewusst weit von Tims Werten
/// entfernt. Die Tagesschlüssel liegen im Jahr 2099, damit sie keinen
/// Termin nachahmen.
void main() {
  /// Schema v11: der Stand vor diesem Ticket — acht Tabellen.
  /// `gelesen_am`, `beginn` und `ende` liegen als ISO-Text mit `Z` vor, weil
  /// `AppCache` mit `storeDateTimeAsText: true` arbeitet (`cache.dart`).
  ///
  /// **Von Hand geschrieben, nicht aus dem heutigen Code erzeugt** — ein
  /// Schema, das aus dem heutigen Code entsteht, ist kein Altschema, sondern
  /// das neue, und bewiese nichts (`migration_test.dart`, Dateikopf).
  const v11Schema = '''
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
  ''';

  /// `eintraege`, wie ein **anderer Zweig** sie angelegt haben könnte —
  /// alle bauen unter derselben Bundle-ID und benutzen dieselbe Datei
  /// (#234/#240). Form und Spaltennamen entsprechen dem, was diese Datei
  /// oben festlegt.
  ///
  /// **Nur diese eine der fünf**, und das ist Absicht: Die übrigen vier
  /// legt diese Datei nicht fest, also darf sie auch keinen Altstand von
  /// ihnen erfinden. Ein halb vorhandener Satz Tabellen ist außerdem der
  /// realistischere Fall — ein anderer Zweig ist irgendwo mittendrin.
  const eintraegeVorweg = '''
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
      extra TEXT,
      health_uuid TEXT,
      health_stand TEXT NOT NULL
    );
    INSERT INTO eintraege
      (tages_schluessel, mahlzeit, zeitpunkt, lebensmittel_id, name, menge_g,
       kcal, eiweiss_g, kohlenhydrate_g, fett_g, zucker_g, ballaststoffe_g,
       gesaettigt_g, wasser_ml, extra, health_uuid, health_stand)
      VALUES ('2099-03-01', 'abend', '2099-03-01T18:30:00.000Z', NULL,
              'Grützwurst mit Kompott', 333.3,
              1234.5, 11.1, 22.2, 33.3, 44.4, 55.5, 66.6, 77.7,
              '{}', NULL, 'offen');
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

  /// Was auf einem v11-Gerät liegt: ein Tag mit allen Werten, eine Nacht mit
  /// einem Abschnitt, Tims eingestellte Ziele, eine von Hand nachgetragene
  /// Nacht und seine Stammdaten. **Die Tageswerte sind Tims einzige
  /// Offline-Quelle** — eine Migration, die hier etwas verlöre, verlöre es
  /// endgültig.
  const v11Bestand = '''
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

  /// Der Bestand eines v1-Geräts — nur, was es damals gab.
  const v1Bestand = '''
    INSERT INTO tages_werte (tag, schritte, ruhepuls_bpm)
      VALUES ('2099-03-01', 4242, 99);
  ''';

  /// Die fünf, die dieses Ticket anlegt.
  const neueTabellen = {
    'lebensmittel',
    'portionen',
    'eintraege',
    'rezepte',
    'rezept_zutaten',
  };

  /// Die Spalten von `eintraege`, die diese Datei festlegt.
  const eintragsSpalten = [
    'id',
    'tages_schluessel',
    'mahlzeit',
    'zeitpunkt',
    'lebensmittel_id',
    'name',
    'menge_g',
    'kcal',
    'eiweiss_g',
    'kohlenhydrate_g',
    'fett_g',
    'zucker_g',
    'ballaststoffe_g',
    'gesaettigt_g',
    'wasser_ml',
    'extra',
    'health_uuid',
    'health_stand',
  ];

  /// Die acht eingefrorenen Nährwertspalten — alle REAL, alle nullbar.
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
  /// Name, Typ, ob NULL erlaubt ist und ob sie zum Schlüssel gehört.
  ///
  /// `PRAGMA` nimmt keine Platzhalter, der Name steht deshalb im Text — er
  /// stammt hier ausschließlich aus Konstanten dieser Datei.
  Future<Map<String, ({String typ, bool nullbar, bool schluessel})>> spalten(
    AppCache db,
    String tabelle,
  ) async {
    final zeilen = await db.customSelect('PRAGMA table_info($tabelle);').get();
    return {
      for (final z in zeilen)
        z.read<String>('name'): (
          typ: z.read<String>('type').toUpperCase(),
          nullbar: z.read<int>('notnull') == 0,
          schluessel: z.read<int>('pk') > 0,
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

  group('Schema v12 — die fünf Ernährungstabellen kommen dazu', () {
    test('die Datenbank steht mindestens auf Version 12', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      expect(
        db.schemaVersion,
        greaterThanOrEqualTo(12),
        reason:
            'eine eigene Stufe, keine Erweiterung der v11-Stufe: Ein Gerät, '
            'das zwischen zwei Tickets aktualisiert wurde, muss den Rest '
            'nachholen können. Bliebe die Nummer auf 11, liefe auf Tims '
            'Gerät keine Stufe mehr, die es noch nicht kennt (#233). Seit '
            'der Stufe 13 (die Spalten von `lebensmittel`) steht die Zahl '
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

  group('Migration v11 → v12 — additiv, fünf Tabellen', () {
    QueryExecutor v11Cache() => altstand(v11Schema, v11Bestand, 11);

    test('die Datenbank steht danach auf der heutigen Version', () async {
      final db = AppCache(v11Cache());
      addTearDown(db.close);

      // Gegen `AppCache.schemaVersion` statt gegen eine eigene Zahl — das
      // ist die Regelung seit #193 (nachzulesen in `migration_test.dart`):
      // Sonst fällt bei jeder neuen Stufe auch ein Fall, der von einer
      // alten handelt. Hier geht es darum, dass der Durchlauf die Nummer
      // festschreibt, nicht darum, welche Nummer das heute ist.
      expect(await abgelegteVersion(db), db.schemaVersion);
    });

    test('und die fünf Tabellen stehen wirklich in der Datei', () async {
      final db = AppCache(v11Cache());
      addTearDown(db.close);

      final gefunden = await tabellen(db);
      expect(
        gefunden,
        containsAll(neueTabellen),
        reason:
            'lebensmittel und portionen als Vorlage, eintraege als '
            'Tatsache, rezepte und rezept_zutaten für das Gekochte',
      );
      expect(
        gefunden,
        tabellenHeute,
        reason:
            'additiv heißt: die acht alten stehen danach alle noch da. '
            'Eine Stufe, die beim Anlegen etwas wegnimmt, nähme Tims '
            'einzige Offline-Quelle mit',
      );
    });

    test('eintraege trägt die achtzehn Spalten aus dem Dateikopf', () async {
      final db = AppCache(v11Cache());
      addTearDown(db.close);

      final gefunden = await spalten(db, 'eintraege');

      expect(
        gefunden.keys,
        containsAll(eintragsSpalten),
        reason:
            'weitere Spalten sind erlaubt — geprüft wird mit containsAll, '
            'wie schon bei stammdaten. Fehlen darf keine davon',
      );
    });

    test('die Schlüsselspalte zählt hoch und vergibt nicht neu', () async {
      final db = AppCache(v11Cache());
      addTearDown(db.close);

      final gefunden = await spalten(db, 'eintraege');
      expect(gefunden['id']!.typ, 'INTEGER');
      expect(gefunden['id']!.schluessel, isTrue);

      expect(
        (await tabellenText(db, 'eintraege')).toUpperCase(),
        contains('AUTOINCREMENT'),
        reason:
            'ohne AUTOINCREMENT vergibt SQLite nach einer Löschung dieselbe '
            'Zeilennummer erneut. Der Health-Nachlauf merkt sich die IDs '
            'offener Einträge und ruft später setzeHealthStand(id, …) — '
            'eine wiederverwendete ID setzte den Stand eines fremden '
            'Eintrags, und zwar lautlos',
      );
    });

    test('die Pflichtfelder eines Eintrags sind NOT NULL', () async {
      final db = AppCache(v11Cache());
      addTearDown(db.close);

      final gefunden = await spalten(db, 'eintraege');

      expect(gefunden['tages_schluessel']!.typ, 'TEXT');
      expect(
        gefunden['tages_schluessel']!.nullbar,
        isFalse,
        reason:
            'ein Eintrag ohne Esstag stünde auf keinem Schirm. Gefiltert '
            'wird über genau diese Spalte',
      );

      expect(gefunden['mahlzeit']!.typ, 'TEXT');
      expect(gefunden['mahlzeit']!.nullbar, isFalse);

      expect(
        gefunden['zeitpunkt']!.typ,
        'TEXT',
        reason:
            'AppCache arbeitet mit storeDateTimeAsText: true. Drifts '
            'Standard (Unix-Sekunden) gäbe den Zeitpunkt als lokale Zeit '
            'zurück, und ein als UTC abgelegter Wert wäre danach ungleich '
            'sich selbst',
      );
      expect(gefunden['zeitpunkt']!.nullbar, isFalse);

      expect(gefunden['name']!.typ, 'TEXT');
      expect(
        gefunden['name']!.nullbar,
        isFalse,
        reason: 'auch der Schnelleintrag trägt einen Namen',
      );

      expect(gefunden['health_stand']!.typ, 'TEXT');
      expect(
        gefunden['health_stand']!.nullbar,
        isFalse,
        reason:
            'jeder Eintrag hat einen der drei Stände. Ein leeres Feld wäre '
            'ein vierter, unbenannter',
      );
    });

    test('und die Felder, die fehlen dürfen, sind nullbar', () async {
      final db = AppCache(v11Cache());
      addTearDown(db.close);

      final gefunden = await spalten(db, 'eintraege');

      expect(gefunden['lebensmittel_id']!.typ, 'INTEGER');
      expect(
        gefunden['lebensmittel_id']!.nullbar,
        isTrue,
        reason:
            'der Schnelleintrag „nur Kalorien" hat kein Lebensmittel. Jede '
            'Abfrage muss das aushalten (Entwurf, „Schnelleintrag und '
            'Favoriten")',
      );

      expect(gefunden['menge_g']!.typ, 'REAL');
      expect(
        gefunden['menge_g']!.nullbar,
        isTrue,
        reason:
            'der Schnelleintrag trägt „einen Namen und seine eingefrorenen '
            'Nährwerte und sonst nichts" — er wiegt nichts. Eine '
            'NOT-NULL-Spalte zwänge dort zu einer 0, und „0 g gegessen" ist '
            'eine Behauptung, kein fehlender Wert (`CLAUDE.md`)',
      );

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
              'Fehler in der Altapp',
        );
      }

      expect(gefunden['health_uuid']!.typ, 'TEXT');
      expect(
        gefunden['health_uuid']!.nullbar,
        isTrue,
        reason:
            'die UUID kennt erst, wer geschrieben hat. Gebucht wird aber '
            'immer, auch ohne Freigabe (Entwurf, „Wenn die Schreibfreigabe '
            'fehlt")',
      );

      expect(
        gefunden['extra']!.typ,
        'TEXT',
        reason:
            'die 26 Mikronährstoffe als JSON — so ist der spätere '
            'Vitamin-Schirm eine Ansicht und keine Migration',
      );
    });

    test(
      'die Migration legt keine Zeile an — fünf leere Tabellen, keine '
      'erfundene Mahlzeit',
      () async {
        final db = AppCache(v11Cache());
        addTearDown(db.close);

        for (final tabelle in neueTabellen) {
          expect(
            await zeilenZahl(db, tabelle),
            0,
            reason:
                '$tabelle kommt leer. Eine vorab eingefügte Zeile '
                'behauptete, Tim habe etwas gegessen — und ein '
                'nachgelegter Zeitstempel behauptete, wann',
          );
        }

        expect(
          await ErnaehrungRepository(db).eintraegeAmTag('2099-03-01'),
          isEmpty,
          reason:
              'der Tag, an dem auf diesem Gerät Schritte und Schlaf liegen, '
              'hat trotzdem keine Mahlzeit — die Migration erfindet keine',
        );
      },
    );

    test(
      'und bestehende Zeilen der acht alten Tabellen überleben unverändert',
      () async {
        final db = AppCache(v11Cache());
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
              'eine Migration, die Tabellen anlegt, fasst keine bestehende '
              'an — Tims eingestellte Ziele sind nicht Gegenstand dieses '
              'Tickets',
        );

        final eintrag = (await db.select(db.schlafEintraege).get()).single;
        expect(eintrag.schlafMinuten, 417);
        expect(eintrag.notiz, 'Uhr vergessen');

        final stamm = (await db.select(db.stammdaten).get()).single;
        expect(stamm.groesseCm, 211);
        expect(stamm.geburtsjahr, 1904);
        expect(stamm.zielgewichtKg, 33.3);
        expect(
          stamm.zieldatum,
          '2099-12-31',
          reason:
              'die Stufe davor ist eine Stufe davor und keine, die noch '
              'einmal läuft',
        );
      },
    );

    test('und die Datei ist danach ganz normal benutzbar', () async {
      final db = AppCache(v11Cache());
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
    /// Nummer zu niedrig, `eintraege` schon da: Ein anderer Zweig hat die
    /// Tabelle unter derselben Bundle-ID in dieselbe Datei gelegt, die
    /// Nummer steht aber noch auf 11. Ein `CREATE TABLE` ohne
    /// `IF NOT EXISTS` stürbe hier — und zwar beim **Öffnen**, danach wäre
    /// die Datenbank gar nicht mehr zu benutzen.
    QueryExecutor vorweggenommen() =>
        altstand('$v11Schema$eintraegeVorweg', v11Bestand, 11);

    test('die Datenbank lässt sich überhaupt öffnen', () async {
      final db = AppCache(vorweggenommen());
      addTearDown(db.close);

      expect(
        await zeilenZahl(db, 'eintraege'),
        isNonNegative,
        reason:
            'die erste Abfrage löst das Öffnen aus. Wirft die Stufe, kommt '
            'es hier an — und auf dem Gerät gar nicht mehr weiter',
      );
      expect(await abgelegteVersion(db), db.schemaVersion);
    });

    test('die übrigen vier kommen trotzdem dazu', () async {
      final db = AppCache(vorweggenommen());
      addTearDown(db.close);

      expect(
        await tabellen(db),
        tabellenHeute,
        reason:
            'eine Stufe, die beim ersten vorhandenen Stück abbricht, ließe '
            'die halb gelaufene Stufe für immer halb — dieselbe Begründung '
            'wie bei _addColumnIfMissing, je Spalte statt je Stufe',
      );
    });

    test(
      'und die vorweggenommene Mahlzeit überlebt — die Tabelle wird nicht '
      'neu gebaut',
      () async {
        final db = AppCache(vorweggenommen());
        addTearDown(db.close);

        final gelesen = await ErnaehrungRepository(db).eintraegeAmTag(
          '2099-03-01',
        );
        expect(gelesen, hasLength(1));
        expect(
          gelesen.single.name,
          'Grützwurst mit Kompott',
          reason:
              'ein vorsorgliches DROP TABLE IF EXISTS vor dem CREATE wäre '
              'eine Stufe, die nie scheitert und trotzdem Tims gebuchte '
              'Mahlzeiten löscht — schlimmer als der Absturz, den sie '
              'behebt',
        );
        expect(gelesen.single.naehrwerte.kcal, 1234.5);

        expect(await db.select(db.tagesWerte).get(), hasLength(1));
      },
    );

    test(
      'zweites Öffnen derselben Datei: nichts wird angefasst, nichts geht '
      'verloren',
      () async {
        final roh = rohdatei(v11Schema, v11Bestand, 11);
        addTearDown(roh.dispose);

        final erstesMal = ueber(roh);
        expect(await tabellen(erstesMal), tabellenHeute, reason: 'Vorbedingung');
        final stempelNachDerStufe = await schemaStempel(erstesMal);
        await erstesMal.close();

        // Zweites Öffnen: Die Nummer steht schon oben, `onUpgrade` läuft
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
      },
    );
  });

  group('Der Weg von unten', () {
    test('ein Gerät auf v1 kommt ganz oben an — über die Stufe 12 hinweg',
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

      for (final tabelle in neueTabellen) {
        expect(
          await zeilenZahl(db, tabelle),
          0,
          reason:
              'die neuen Tabellen kommen leer, auch auf dem längsten Weg. '
              'Eine nachgelegte Zeile wäre eine Mahlzeit, die niemand '
              'gegessen hat',
        );
      }
    });
  });
}
