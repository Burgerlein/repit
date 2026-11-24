import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show Database, sqlite3;

import 'package:repit/data/cache.dart';

import 'schema_tabellen.dart';

/// Tests für **Schema v21**: die Aufteilung des Tagesziels auf die
/// Mahlzeiten, eine Historie „ab Tag" (#430, unter #374).
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden. Jede Migration
/// bekommt einen Test, dies ist der für die Stufe 20.
///
/// ## Woher die Anforderung kommt
///
/// Spec `docs/superpowers/specs/2026-11-10-mahlzeiten-aufteilung-design.md`,
/// Abschnitt „Die Datenschicht", und Plan
/// `docs/superpowers/plans/2026-11-10-mahlzeiten-aufteilung.md`, Task 1.
/// Tim hat am 10.11.2026 Entwurf und Entscheidungen 1 bis 12 freigegeben
/// und die Vorgaben V1 bis V29 des Planenden übernommen. Für diese Stufe
/// tragen:
///
/// - **Entscheidung 1:** Der Startwert 25 · 35 · 30 · 10 gilt erst, wenn
///   Tim einmal sichert. Er steht im Formular, nie in der Tabelle.
/// - **Entscheidung 2 / V1:** Gespeichert werden nur Frühstück, Mittag und
///   Abend, als ganze Prozent in drei nullbaren `INTEGER`-Spalten ohne
///   Vorgabewert. Der Snack ist der Rest und hat keine Spalte.
/// - **V2:** „Ab heute" ist der Berliner Kalendertag; ein zweites Sichern
///   am selben Tag ersetzt die Zeile dieses Tages.
///
/// Der Code der Stufe existierte beim Schreiben dieser Datei nicht.
/// Gelesen wurden Spec und Plan, nicht die spätere Implementierung.
///
/// ## Warum die 21 (ursprünglich die 20)
///
/// Am 10.11.2026 nachgesehen: `main` stand auf `schemaVersion => 19`, der
/// Zweig `mz-schema` ebenso. Parallel plante `te-plan` #375/#404 und
/// reservierte in seinen Specs ausdrücklich die 21 (Auszeit) und die 22
/// (Tagesgrenze), die 20 für #374. Also wurde es damals die 20.
///
/// **Seit dem 11.11.2026 ist es die 21** (#485): In `main` lag inzwischen
/// eine unabhängig vergebene Stufe 18 — die drei Gym-Tabellen (#78) —,
/// die auf Tims iPhone schon gelaufen und dort in der Datei vermerkt ist.
/// Verschöbe man sie, liefe sie dort nie wieder. Beim Zusammenführen von
/// `umfaenge-88` und `main` behält sie deshalb die 18, und jede Stufe
/// dieses Zweigs ab 18 ist um eins nach oben gerückt; die Datei hieß bis
/// dahin `schema_v20_test.dart`. Nachgezogen beim Zusammenführen, **Tim
/// hat die Änderung nicht gesehen**.
///
/// Nachbar von `schema_v19_test.dart` (auch dort legt eine Stufe eine
/// Tabelle an): derselbe Aufbau, von Hand gebaute Altstände, **nicht** aus
/// dem heutigen Code erzeugt (`migration_test.dart`, Dateikopf). Der Stand
/// v20 unten ist der aus `schema_v19_test.dart` (`v17Schema`) mit
/// `kalorienziele` (Stufe 19) und `eintraege.fluessig` (Stufe 20, wie
/// `schema_v20_test.dart` sie festlegt).
///
/// **Diese Datei spricht die Tabelle nur über SQL an**, nicht über die
/// drift-Klassen. Sie übersetzt also auch dann, wenn es die Tabelle im
/// Code noch nicht gibt, und meldet dann, *was* fehlt, statt nur, dass sie
/// nicht baut. Den Weg über drift (`MahlzeitAufteilungRow`, Companion)
/// prüft das Repository in Task 3.
///
/// ## Was diese Datei verbindlich vorgibt
///
/// **1. `AppCache.schemaVersion >= 21`** und eine **eigene Stufe**
/// `if (from < 21) { … }`. Geprüft mit `>=`, damit diese Datei bei der
/// nächsten Stufe nicht mitfällt (#208). Nach dem Öffnen eines v20-Stands
/// steht `user_version` auf `schemaVersion`.
///
/// **2. Eine neue Tabelle `mahlzeit_aufteilungen`**, genau diese vier
/// Spalten (Spec, Tabelle unter „Schemastufe 21"):
///
/// | Spalte | Typ | NULL | Vorgabe | Drift-Name |
/// |---|---|---|---|---|
/// | `ab_tag` | TEXT, **Primärschlüssel** | nein | — | `abTag` |
/// | `fruehstueck_pct` | INTEGER | ja | — | `fruehstueckPct` |
/// | `mittag_pct` | INTEGER | ja | — | `mittagPct` |
/// | `abend_pct` | INTEGER | ja | — | `abendPct` |
///
/// Keine Spalte für den Snack, kein Index (`_reconcileSchema` kennt
/// keine).
///
/// **3. Additiv, ohne Startwert.** Die Stufe legt **keine** Zeile an
/// (Entscheidung 1). Alle übrigen Tabellen behalten jede Zeile und jeden
/// Wert.
///
/// **4. Zweimal ausführbar** (#234/#240). Steht `mahlzeit_aufteilungen`
/// schon in einer Datei mit `user_version = 20`, öffnet sie trotzdem, und
/// die Zeilen darin bleiben.
///
/// **5. Abgleich** (#233). Eine Datei auf 21, der die Tabelle fehlt,
/// bekommt sie beim Öffnen. Eine, deren Tabelle `abend_pct` fehlt, bekommt
/// die Spalte, leer.
///
/// **6. Von weit unten:** Ein v11-Stand läuft durch alle Stufen.
///
/// ## Festlegungen des Test-Agenten, nicht von Tim freigegeben
///
/// - **Eine `CHECK`-Bedingung wird weder verlangt noch verboten.** V3
///   (Vielfache von 5, Summe höchstens 100) prüft der Kern beim Lesen;
///   ob die Tabelle zusätzlich prüft, regelt diese Datei nicht.
/// - **Die Stufe räumt unvollständige Zeilen nicht auf.** Steht vorweg eine
///   Zeile mit `abend_pct = NULL` da, bleibt sie. „Gelesen werden nur
///   vollständige Zeilen" (V1) ist Sache des Repositorys, nicht der
///   Migration; eine Migration, die Zeilen wegnimmt, nähme Tims Werte weg.
/// - **Ein zweites Öffnen ändert am Schema nichts mehr** (gemessen am
///   SQLite-Schema-Zähler, wie in `schema_v20_test.dart`).
/// - **`ab_tag` ist eindeutig:** Ein zweites `INSERT` für denselben Tag
///   scheitert. Das folgt aus dem Primärschlüssel der Spec und aus V2,
///   steht hier aber als eigener Fall, damit ein Schlüssel über mehrere
///   Spalten auffällt.
///
/// ## Bestehende Tests, die mit dieser Stufe mitgehen
///
/// `schema_tabellen.dart` bekommt `tabellenAusStufe21` und die Tabelle in
/// [tabellenHeute]; `migration_test.dart` nennt die absolute Zahl 21;
/// `schema_abgleich_test.dart` die `heutigeNummer` 21 und die Tabelle im
/// vollständigen Schema; `schema_stufen_robust_test.dart` zählt je ein
/// `CREATE TABLE` mehr; `schema_v19_test.dart` nimmt in seiner Vorbedingung
/// die Tabellen der Stufe 21 aus dem Vergleich des v17-Stands, weil v17
/// sie nicht haben kann. Alle nachgezogen vom Test-Agenten
/// (`TEST_AENDERN=1`), nicht von Tim gesehen.
///
/// **Alle Zahlen, Namen und Zeitpunkte hier sind erfunden.** Die Zeitpunkte
/// liegen im Jahr 2099.
void main() {
  // --- Altstände, von Hand -----------------------------------------------

  /// Stand v20: `v17Schema` aus `schema_v19_test.dart`, dazu die drei
  /// Gym-Tabellen (Stufe 18, #78), `kalorienziele` (Stufe 19) und
  /// `eintraege.fluessig` (Stufe 20).
  const v20Schema = '''
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
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL DEFAULT '',
      kcal REAL,
      eiweiss_g REAL,
      kohlenhydrate_g REAL,
      fett_g REAL,
      zucker_g REAL,
      ballaststoffe_g REAL,
      gesaettigt_g REAL,
      wasser_ml REAL,
      extra TEXT NOT NULL DEFAULT '{}',
      fluessig INTEGER NOT NULL DEFAULT 0 CHECK (fluessig IN (0, 1)),
      zuletzt_benutzt TEXT,
      barcode TEXT,
      herkunft TEXT NOT NULL DEFAULT 'eigen',
      portionen_abgefragt_am TEXT
    );
    CREATE TABLE portionen (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      lebensmittel_id INTEGER,
      name TEXT NOT NULL DEFAULT '',
      menge_g REAL,
      herkunft TEXT NOT NULL DEFAULT 'eigen'
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
      health_stand TEXT NOT NULL DEFAULT 'offen',
      vorschlag TEXT,
      portion_id INTEGER,
      portion_name TEXT,
      portion_g REAL,
      fluessig INTEGER
    );
    CREATE TABLE rezepte (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT
    );
    CREATE TABLE rezept_zutaten (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT
    );
    CREATE TABLE ki_einstellungen (
      id INTEGER NOT NULL DEFAULT 0,
      modell TEXT,
      limit_usd REAL,
      preise TEXT NOT NULL DEFAULT '{}',
      geprueft_am TEXT,
      pruef_ergebnis TEXT,
      PRIMARY KEY (id)
    );
    CREATE TABLE ki_anfragen (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      zeitpunkt TEXT NOT NULL,
      monat TEXT NOT NULL,
      modell TEXT NOT NULL,
      zweck TEXT NOT NULL,
      eingabe_token INTEGER NOT NULL,
      ausgabe_token INTEGER NOT NULL,
      denk_token INTEGER NOT NULL,
      kosten_usd REAL
    );
    CREATE TABLE wasser_eintraege (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      tages_schluessel TEXT NOT NULL,
      zeitpunkt TEXT NOT NULL,
      menge_ml REAL NOT NULL,
      health_uuid TEXT,
      health_stand TEXT NOT NULL DEFAULT 'offen'
    );
    CREATE TABLE kalorienziele (
      ab_tag TEXT NOT NULL PRIMARY KEY,
      kcal REAL NOT NULL,
      herkunft TEXT NOT NULL,
      grundumsatz_kcal REAL,
      aktiv_kcal REAL,
      koerperziel_kcal REAL
    );
    CREATE TABLE gym_sitzungen (
      id TEXT NOT NULL,
      tag TEXT NOT NULL,
      zeitpunkt TEXT NOT NULL,
      workout TEXT NULL,
      minuten INTEGER NULL,
      notiz TEXT NULL,
      health_uuid TEXT NULL,
      aufwaermen_art TEXT NULL CHECK (aufwaermen_art IS NULL OR aufwaermen_art IN ('bike', 'treadmill', 'rowing', 'cross_trainer', 'jump_rope', 'mobility')),
      aufwaermen_minuten INTEGER NULL,
      aufwaermen_km REAL NULL,
      aufwaermen_uebersprungen INTEGER NOT NULL DEFAULT 0 CHECK (aufwaermen_uebersprungen IN (0, 1)),
      aufwaermen_health_uuid TEXT NULL,
      PRIMARY KEY (id),
      UNIQUE (tag, workout)
    );
    CREATE TABLE gym_saetze (
      sitzung_id TEXT NOT NULL,
      uebung_id TEXT NOT NULL,
      uebung_pos INTEGER NOT NULL,
      satz_nr INTEGER NOT NULL,
      gewicht_kg REAL NOT NULL,
      wdh INTEGER NOT NULL,
      zeitpunkt TEXT NULL,
      PRIMARY KEY (sitzung_id, uebung_id, satz_nr)
    );
    CREATE TABLE gym_entwuerfe (
      id INTEGER NOT NULL DEFAULT 0 CHECK (id = 0),
      workout TEXT NOT NULL,
      sitzung_id TEXT NOT NULL,
      zeitpunkt TEXT NOT NULL,
      dauer TEXT NULL,
      notiz TEXT NULL,
      gespeichert_am TEXT NOT NULL,
      felder TEXT NOT NULL,
      PRIMARY KEY (id)
    );
  ''';

  /// `mahlzeit_aufteilungen`, wie ein anderer Zweig sie schon angelegt
  /// haben könnte, von Hand nach der Tabelle im Dateikopf.
  const aufteilungenVorweg = '''
    CREATE TABLE mahlzeit_aufteilungen (
      ab_tag TEXT NOT NULL PRIMARY KEY,
      fruehstueck_pct INTEGER,
      mittag_pct INTEGER,
      abend_pct INTEGER
    );
  ''';

  /// Zwei Zeilen darin: eine vollständige und eine, der der Abend fehlt.
  /// Beide muss die Stufe stehen lassen; welche davon gilt, entscheidet
  /// das Repository (V1), nicht die Migration.
  const aufteilungenZeilenVorweg = '''
    INSERT INTO mahlzeit_aufteilungen
      (ab_tag, fruehstueck_pct, mittag_pct, abend_pct)
      VALUES ('2099-03-01', 20, 40, 25);
    INSERT INTO mahlzeit_aufteilungen
      (ab_tag, fruehstueck_pct, mittag_pct, abend_pct)
      VALUES ('2099-03-05', 15, 45, NULL);
  ''';

  /// Eine Tabelle, die ein halb fertiger Zweig angelegt hat: ohne
  /// `abend_pct`.
  const aufteilungenOhneAbend = '''
    CREATE TABLE mahlzeit_aufteilungen (
      ab_tag TEXT NOT NULL PRIMARY KEY,
      fruehstueck_pct INTEGER,
      mittag_pct INTEGER
    );
    INSERT INTO mahlzeit_aufteilungen (ab_tag, fruehstueck_pct, mittag_pct)
      VALUES ('2099-03-02', 30, 30);
  ''';

  /// Tims Bestand auf Stand v20: Einträge in drei Mahlzeiten (einer davon
  /// flüssig gebucht), ein festes Kalorienziel, eine Vorlage, eine Portion,
  /// dazu Stammdaten, KI und Wasser. Eine Migration, die hier etwas
  /// verlöre, verlöre es endgültig.
  const bestand = '''
    INSERT INTO tages_werte (tag, schritte, ruhepuls_bpm, gelesen_am,
                             gewicht_kg)
      VALUES ('2099-03-01', 4321, 55, '2099-03-01T08:00:00.000Z', 81.3);
    INSERT INTO stammdaten (id, groesse_cm, geburtsjahr, zielgewicht_kg,
                            zieldatum)
      VALUES (0, 123, 2001, 84.5, '2099-09-30');
    INSERT INTO lebensmittel (id, name, kcal, fluessig, herkunft,
                              portionen_abgefragt_am)
      VALUES (1, 'Prüfknäcke', 377.7, 0, 'eigen',
              '2099-03-01T10:20:30.000Z');
    INSERT INTO lebensmittel (id, name, kcal, wasser_ml, fluessig, barcode,
                              herkunft)
      VALUES (2, 'Prüftrunk', 42.4, 88.8, 1, '0000000000020', 'off');
    INSERT INTO portionen (id, lebensmittel_id, name, menge_g, herkunft)
      VALUES (5, 1, 'Prüfbon', 5.9, 'eigen');
    INSERT INTO eintraege
      (id, tages_schluessel, mahlzeit, zeitpunkt, lebensmittel_id, name,
       menge_g, kcal, extra, health_uuid, health_stand, portion_id,
       portion_name, portion_g, fluessig)
      VALUES (1, '2099-03-01', 'fruehstueck', '2099-03-01T07:15:00.000Z', 1,
              'Prüfknäcke', 11.8, 44.6, '{}', 'PRUEF-UUID-0020',
              'geschrieben', 5, 'Prüfbon', 5.9, 0);
    INSERT INTO eintraege
      (id, tages_schluessel, mahlzeit, zeitpunkt, lebensmittel_id, name,
       menge_g, kcal, extra, health_stand, vorschlag, fluessig)
      VALUES (2, '2099-03-01', 'abend', '2099-03-01T18:45:00.000Z', NULL,
              'Freier Prüfeintrag', NULL, 512.5, '{}', 'offen',
              '{"anbieter":"pruef","zweck":"foto"}', NULL);
    INSERT INTO eintraege
      (id, tages_schluessel, mahlzeit, zeitpunkt, lebensmittel_id, name,
       menge_g, kcal, wasser_ml, extra, health_stand, fluessig)
      VALUES (3, '2099-03-01', 'snack', '2099-03-01T14:20:00.000Z', 2,
              'Prüftrunk', 250.5, 106.2, 222.4, '{}', 'offen', 1);
    INSERT INTO kalorienziele
      (ab_tag, kcal, herkunft, grundumsatz_kcal, aktiv_kcal,
       koerperziel_kcal)
      VALUES ('2099-02-20', 2617.25, 'berechnet', 1750.5, 700.2, 166.55);
    INSERT INTO kalorienziele (ab_tag, kcal, herkunft)
      VALUES ('2099-02-27', 2450.5, 'hand');
    INSERT INTO ki_einstellungen (id, modell, limit_usd, preise)
      VALUES (0, 'pruef-modell-x', 3.5, '{}');
    INSERT INTO wasser_eintraege
      (id, tages_schluessel, zeitpunkt, menge_ml, health_stand)
      VALUES (4, '2099-03-01', '2099-03-01T09:15:00.000Z', 333.5, 'offen');
  ''';

  /// Schema v11, wörtlich aus `schema_v20_test.dart`: acht Tabellen, noch
  /// keine Ernährung.
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

  const v11Bestand = '''
    INSERT INTO tages_werte (tag, schritte, ruhepuls_bpm, gelesen_am)
      VALUES ('2099-03-01', 4242, 99, '2099-03-01T09:00:00.000Z');
    INSERT INTO stammdaten (id, groesse_cm, geburtsjahr, zielgewicht_kg,
                            zieldatum)
      VALUES (0, 211, 1904, 33.3, '2099-12-31');
  ''';

  /// Die Tabellen, deren Zeilen die Stufe nicht anrühren darf.
  const alle = [
    'tages_werte',
    'stammdaten',
    'lebensmittel',
    'portionen',
    'eintraege',
    'kalorienziele',
    'ki_einstellungen',
    'wasser_eintraege',
  ];

  /// Die Spalten der Tabelle nach dem Dateikopf.
  const spaltenAufteilungen = {
    'ab_tag',
    'fruehstueck_pct',
    'mittag_pct',
    'abend_pct',
  };

  const prozentSpalten = ['fruehstueck_pct', 'mittag_pct', 'abend_pct'];

  // --- Hilfsmittel, wie in `schema_v19_test.dart` ------------------------

  Database rohdatei(String schema, String inhalt, int version) {
    final roh = sqlite3.openInMemory();
    roh.execute(schema);
    if (inhalt.isNotEmpty) roh.execute(inhalt);
    roh.execute('PRAGMA user_version = $version;');
    return roh;
  }

  AppCache ueber(Database roh) =>
      AppCache(NativeDatabase.opened(roh, closeUnderlyingOnClose: false));

  Future<int> abgelegteVersion(AppCache db) async {
    final zeile = await db.customSelect('PRAGMA user_version;').getSingle();
    return zeile.read<int>('user_version');
  }

  Future<Set<String>> tabellen(AppCache db) async {
    final zeilen = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name NOT LIKE 'sqlite_%';",
        )
        .get();
    return zeilen.map((z) => z.read<String>('name')).toSet();
  }

  Set<String> rohTabellen(Database roh) => {
    for (final z in roh.select(
      "SELECT name FROM sqlite_master WHERE type = 'table' "
      "AND name NOT LIKE 'sqlite_%';",
    ))
      z['name'] as String,
  };

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

  Future<List<Map<String, Object?>>> zeilen(AppCache db, String tabelle) async {
    final ergebnis = await db
        .customSelect('SELECT * FROM $tabelle ORDER BY rowid;')
        .get();
    return [for (final z in ergebnis) z.data];
  }

  List<Map<String, Object?>> rohZeilen(Database roh, String tabelle) => [
    for (final z in roh.select('SELECT * FROM $tabelle ORDER BY rowid;'))
      Map<String, Object?>.of(z),
  ];

  int schemaZaehler(Database roh) =>
      roh.select('PRAGMA schema_version;').single['schema_version'] as int;

  void pruefeUnveraendert(
    List<Map<String, Object?>> vorher,
    List<Map<String, Object?>> nachher,
    String tabelle,
  ) {
    expect(
      nachher,
      hasLength(vorher.length),
      reason: 'die Stufe legt in $tabelle keine Zeile an und nimmt keine weg',
    );
    for (var i = 0; i < vorher.length; i++) {
      for (final MapEntry(:key, :value) in vorher[i].entries) {
        expect(
          nachher[i][key],
          value,
          reason:
              '$tabelle, Zeile ${i + 1}, Spalte $key: ein vorhandener '
              'Wert ist Tims Wert',
        );
      }
    }
  }

  /// Die Form von `mahlzeit_aufteilungen` nach der Tabelle im Dateikopf.
  Future<void> pruefeForm(AppCache db) async {
    final s = await spalten(db, 'mahlzeit_aufteilungen');
    expect(
      s.keys.toSet(),
      spaltenAufteilungen,
      reason:
          'genau die vier Spalten der Spec. Keine für den Snack: Er ist '
          'der Rest und hat keine Spalte, die ihm widersprechen könnte '
          '(V1, Entscheidung 2)',
    );

    expect(s['ab_tag']!.typ, 'TEXT', reason: 'der ISO-Tagesschlüssel');
    expect(
      s['ab_tag']!.schluessel,
      isTrue,
      reason: 'je Tag gilt höchstens eine Aufteilung',
    );
    expect(s['ab_tag']!.nullbar, isFalse);
    expect(
      s['ab_tag']!.vorgabe,
      isNull,
      reason: 'ein Vorgabetag erfände einen Tag, an dem Tim gesichert hat',
    );
    expect(
      [
        for (final MapEntry(:key, :value) in s.entries)
          if (value.schluessel) key,
      ],
      ['ab_tag'],
      reason: 'der Tag allein ist der Schlüssel, kein zusammengesetzter',
    );

    for (final p in prozentSpalten) {
      expect(s[p]!.typ, 'INTEGER', reason: '$p: ganze Prozent');
      expect(
        s[p]!.nullbar,
        isTrue,
        reason:
            '$p: nullbar, weil der Abgleich (#233) eine fehlende Spalte '
            'mit ALTER TABLE … ADD COLUMN nachträgt und SQLite das bei '
            'NOT NULL ohne Vorgabe ablehnt (V1)',
      );
      expect(
        s[p]!.vorgabe,
        isNull,
        reason:
            '$p: eine Vorgabe behauptete eine Einstellung, die niemand '
            'gemacht hat (V1, Entscheidung 1)',
      );
    }

    final indizes = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index' "
          "AND tbl_name = 'mahlzeit_aufteilungen' AND sql IS NOT NULL;",
        )
        .get();
    expect(
      indizes,
      isEmpty,
      reason:
          'kein Index — _reconcileSchema kennt keine Indizes. Der '
          'automatische Index des Primärschlüssels (sql IS NULL) zählt '
          'nicht',
    );
  }

  // ═════════════════════════════════════════════════════════════════════

  group('Vorbedingungen: die Altstände sind so gebaut, wie sie gemeint '
      'sind', () {
    test('v20 hat alle heutigen Tabellen außer der neuen, und eintraege '
        'trägt fluessig', () {
      final roh = rohdatei(v20Schema, bestand, 20);
      addTearDown(roh.close);
      final namen = rohTabellen(roh);
      expect(namen, isNot(contains('mahlzeit_aufteilungen')));
      // Seit der Stufe 22 (#444) auch ohne deren Tabellen, seit der Stufe
      // 23 (#451) ebenso ohne die der Stufe 23 und seit der Stufe 24 (#476)
      // ohne die der Stufe 24: Die kann ein v20-Stand nicht haben. Die
      // drei Gym-Tabellen der Stufe 18 hat er dagegen, seit `main` und
      // `umfaenge-88` zusammengeführt sind (#485).
      // Nachgezogen vom Test-Agenten, **Tim hat die Änderung nicht
      // gesehen.**
      expect(
        namen,
        tabellenHeute.difference({
          ...tabellenAusStufe21,
          ...tabellenAusStufe22,
          ...tabellenAusStufe23,
          ...tabellenAusStufe24,
          ...tabellenAusStufe26,
          ...tabellenAusStufe27,
        }),
        reason:
            'v20 hat alle heutigen Tabellen außer denen der Stufe 21 und '
            'späterer Stufen',
      );
      expect(
        roh.select('PRAGMA table_info(eintraege);').map((z) => z['name']),
        contains('fluessig'),
      );
      expect(rohZeilen(roh, 'eintraege'), hasLength(3));
      expect(rohZeilen(roh, 'kalorienziele'), hasLength(2));
    });

    test('v20 vorweg trägt die Tabelle schon, mit zwei Zeilen', () {
      final roh = rohdatei(
        v20Schema + aufteilungenVorweg,
        bestand + aufteilungenZeilenVorweg,
        20,
      );
      addTearDown(roh.close);
      expect(rohZeilen(roh, 'mahlzeit_aufteilungen'), hasLength(2));
    });
  });

  group('Schema v21 (#430) — frisch angelegt', () {
    test('die Version ist mindestens 21 und steht so in der Datei', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      expect(db.schemaVersion, greaterThanOrEqualTo(21));
      expect(await abgelegteVersion(db), db.schemaVersion);
    });

    test('ein frischer Cache hat die Tabelle, in der verlangten Form, und '
        'sie ist leer', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      expect(await tabellen(db), tabellenHeute);
      expect(await tabellen(db), contains('mahlzeit_aufteilungen'));
      await pruefeForm(db);
      expect(
        await zeilen(db, 'mahlzeit_aufteilungen'),
        isEmpty,
        reason:
            'auch ein frischer Cache trägt keinen Startwert: Er gilt erst, '
            'wenn Tim sichert (Entscheidung 1)',
      );
    });
  });

  group('Migration v20 → heute', () {
    test('legt die Tabelle an, mit der verlangten Form, und die Datei steht '
        'danach auf der heutigen Version', () async {
      final roh = rohdatei(v20Schema, bestand, 20);
      addTearDown(roh.close);
      final db = ueber(roh);
      addTearDown(db.close);

      expect(await abgelegteVersion(db), db.schemaVersion);
      expect(await tabellen(db), tabellenHeute);
      await pruefeForm(db);
    });

    test('legt keinen Startwert an — die Tabelle ist leer', () async {
      final roh = rohdatei(v20Schema, bestand, 20);
      addTearDown(roh.close);
      final db = ueber(roh);
      addTearDown(db.close);

      expect(
        await zeilen(db, 'mahlzeit_aufteilungen'),
        isEmpty,
        reason:
            'Entscheidung 1: Der Startwert 25 · 35 · 30 · 10 steht im '
            'Formular, nie in der Tabelle, bevor Tim sichert. Eine Zeile '
            'der Migration gäbe jeder Mahlzeit ein Ziel, das niemand '
            'eingestellt hat, ab einem Tag, an dem niemand gesichert hat',
      );
    });

    test(
      'additiv: jede Zeile und jeder Wert bleibt, in allen Tabellen',
      () async {
        final roh = rohdatei(v20Schema, bestand, 20);
        addTearDown(roh.close);
        final vorher = {for (final t in alle) t: rohZeilen(roh, t)};

        final db = ueber(roh);
        addTearDown(db.close);

        expect(
          await abgelegteVersion(db),
          greaterThanOrEqualTo(21),
          reason: 'die Stufe 21 ist über diesen Bestand gelaufen',
        );
        for (final t in alle) {
          pruefeUnveraendert(vorher[t]!, await zeilen(db, t), t);
        }
        expect(
          (await zeilen(db, 'eintraege')).map((z) => z['fluessig']).toList(),
          [0, null, 1],
          reason: 'der Schnappschuss der Stufe 20 bleibt, wie er war',
        );
      },
    );

    test('ein zweites Öffnen derselben Datei ändert am Schema nichts mehr, '
        'und eine inzwischen gesicherte Zeile bleibt', () async {
      final roh = rohdatei(v20Schema, bestand, 20);
      addTearDown(roh.close);

      final erstes = ueber(roh);
      await erstes.customStatement(
        'INSERT INTO mahlzeit_aufteilungen '
        '(ab_tag, fruehstueck_pct, mittag_pct, abend_pct) '
        "VALUES ('2099-03-02', 30, 35, 20);",
      );
      await erstes.close();
      final nachErstem = schemaZaehler(roh);
      final zeilenNachErstem = rohZeilen(roh, 'mahlzeit_aufteilungen');

      final zweites = ueber(roh);
      addTearDown(zweites.close);
      await zweites.customSelect('SELECT 1;').get();

      expect(
        schemaZaehler(roh),
        nachErstem,
        reason:
            'PRAGMA schema_version steigt bei jedem CREATE, ALTER und DROP. '
            'Steigt er beim zweiten Öffnen, legt die Stufe oder der Abgleich '
            'bei jedem Start etwas neu an',
      );
      pruefeUnveraendert(
        zeilenNachErstem,
        await zeilen(zweites, 'mahlzeit_aufteilungen'),
        'mahlzeit_aufteilungen',
      );
    });
  });

  group('Die Stufe ist zweimal ausführbar (#234/#240)', () {
    test('steht die Tabelle schon da, öffnet die Datei, und jede Zeile darin '
        'bleibt — auch die unvollständige', () async {
      final roh = rohdatei(
        v20Schema + aufteilungenVorweg,
        bestand + aufteilungenZeilenVorweg,
        20,
      );
      addTearDown(roh.close);
      final vorher = {
        for (final t in [...alle, 'mahlzeit_aufteilungen'])
          t: rohZeilen(roh, t),
      };

      final db = ueber(roh);
      addTearDown(db.close);

      expect(await abgelegteVersion(db), db.schemaVersion);
      expect(
        await abgelegteVersion(db),
        greaterThanOrEqualTo(21),
        reason:
            'die Stufe 21 lief über eine Datei, die ihre Tabelle schon trug, '
            'und scheiterte nicht an „table already exists"',
      );
      for (final MapEntry(key: t, value: z) in vorher.entries) {
        pruefeUnveraendert(z, await zeilen(db, t), t);
      }
      await pruefeForm(db);
      expect(
        (await zeilen(db, 'mahlzeit_aufteilungen')).last['abend_pct'],
        isNull,
        reason:
            'die Migration räumt nicht auf und füllt nichts: Welche Zeile '
            'gilt, entscheidet das Repository (V1)',
      );
    });
  });

  group('Abgleich beim Öffnen (#233)', () {
    test('eine Datei auf 21, der die Tabelle fehlt, bekommt sie — leer, und '
        'verliert nichts', () async {
      // Ein Zweig hat die Nummer hochgezogen, bevor seine Stufe fertig
      // war: `if (from < 21)` läuft dann nie.
      final roh = rohdatei(v20Schema, bestand, 21);
      addTearDown(roh.close);
      final vorher = {for (final t in alle) t: rohZeilen(roh, t)};

      final db = ueber(roh);
      addTearDown(db.close);
      // Der erste Zugriff: Das Öffnen selbst ist bei drift lazy.
      await db.customSelect('SELECT 1;').get();

      expect(
        await tabellen(db),
        contains('mahlzeit_aufteilungen'),
        reason:
            'onUpgrade läuft bei from == 21 nicht in die Stufe 21 — die '
            'Tabelle kommt nur über den Abgleich',
      );
      expect(await tabellen(db), tabellenHeute);
      await pruefeForm(db);
      expect(await zeilen(db, 'mahlzeit_aufteilungen'), isEmpty);
      for (final t in alle) {
        pruefeUnveraendert(vorher[t]!, await zeilen(db, t), t);
      }
    });

    test('eine Datei auf 21, deren Tabelle abend_pct fehlt, bekommt die '
        'Spalte — leer, und die Zeile bleibt', () async {
      final roh = rohdatei(v20Schema + aufteilungenOhneAbend, bestand, 21);
      addTearDown(roh.close);
      final vorher = rohZeilen(roh, 'mahlzeit_aufteilungen');

      final db = ueber(roh);
      addTearDown(db.close);
      await db.customSelect('SELECT 1;').get();

      expect(
        (await spalten(db, 'mahlzeit_aufteilungen')).keys,
        contains('abend_pct'),
      );
      await pruefeForm(db);
      pruefeUnveraendert(
        vorher,
        await zeilen(db, 'mahlzeit_aufteilungen'),
        'mahlzeit_aufteilungen',
      );
      expect(
        (await zeilen(db, 'mahlzeit_aufteilungen')).single['abend_pct'],
        isNull,
        reason:
            'der Abgleich erfindet keinen Wert, er hängt nur an — eine 0 '
            'behauptete „Abend: 0 %" (Fehler `01`)',
      );
    });
  });

  group('Von weit unten: v11 → heute', () {
    test('ein v11-Stand öffnet ohne Fehler und hat danach die Tabelle, '
        'leer', () async {
      final roh = rohdatei(v11Schema, v11Bestand, 11);
      addTearDown(roh.close);
      final vorher = {
        for (final t in ['tages_werte', 'stammdaten']) t: rohZeilen(roh, t),
      };

      final db = ueber(roh);
      addTearDown(db.close);

      // Scheiterte eine Stufe, würfe schon dieser erste Zugriff.
      expect(await abgelegteVersion(db), db.schemaVersion);
      expect(await tabellen(db), tabellenHeute);
      await pruefeForm(db);
      expect(await zeilen(db, 'mahlzeit_aufteilungen'), isEmpty);
      for (final MapEntry(key: t, value: z) in vorher.entries) {
        pruefeUnveraendert(z, await zeilen(db, t), t);
      }
    });
  });

  group('Der Schlüssel', () {
    test('ab_tag ist eindeutig: eine zweite Aufteilung für denselben Tag ist '
        'kein zweiter Eintrag', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      await db.customStatement(
        'INSERT INTO mahlzeit_aufteilungen '
        '(ab_tag, fruehstueck_pct, mittag_pct, abend_pct) '
        "VALUES ('2099-03-02', 25, 35, 30);",
      );
      await expectLater(
        db.customStatement(
          'INSERT INTO mahlzeit_aufteilungen '
          '(ab_tag, fruehstueck_pct, mittag_pct, abend_pct) '
          "VALUES ('2099-03-02', 20, 40, 30);",
        ),
        throwsA(anything),
        reason:
            'je Tag gilt höchstens eine Aufteilung; ein zweites Sichern am '
            'selben Tag ersetzt die Zeile über das Repository (V2), statt '
            'eine zweite danebenzulegen',
      );
    });

    test('eine Zeile ohne Prozentwerte lässt sich ablegen — nullbar heißt '
        'nullbar', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      await db.customStatement(
        "INSERT INTO mahlzeit_aufteilungen (ab_tag) VALUES ('2099-03-03');",
      );
      final zeile = (await zeilen(db, 'mahlzeit_aufteilungen')).single;
      for (final p in prozentSpalten) {
        expect(zeile[p], isNull, reason: '$p: keine Vorgabe, also NULL');
      }
    });
  });
}
