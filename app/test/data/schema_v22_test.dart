import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show Database, sqlite3;

import 'package:repit/data/cache.dart';

import 'schema_tabellen.dart';

/// Tests für **Schema v22**: die Tabelle `ereignisse`, zunächst für die
/// Auszeiten — OP, Krankheit, Verletzung, Urlaub (#444, unter #404).
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden. Jede Migration
/// bekommt einen Test, dies ist der für die Stufe 21.
///
/// ## Woher die Anforderung kommt
///
/// Spec `docs/superpowers/specs/2026-11-10-auszeit-design.md`, Abschnitt
/// „Die Datenschicht", und Plan `docs/superpowers/plans/2026-11-10-auszeit.md`,
/// Task 1. Laut Spec hat Tim am 10.11.2026 den Entwurf und die
/// Entscheidungen 1 bis 11 freigegeben und die Vorgaben V1 bis V20 des
/// Planenden übernommen. Für diese Stufe tragen:
///
/// - **Entscheidung 2:** Felder `art`, `von`, `bis`, `notiz`, `angelegt`,
///   `geaendert`, abgelegt in einer drift-Tabelle mit neuer Schemastufe und
///   Migrationstest. Keine Spalte „Wirkung".
/// - **V1:** Die Tabelle heißt `ereignisse`, nicht „Auszeit" — mit #389
///   kommt der Spieltag dazu, und der ist keine Auszeit.
/// - **V20:** Eine Zeile mit unbekannter `art` übergeht das Lesen. Eine
///   spätere Fassung kann sie geschrieben haben.
/// - **„Keine hartcodierten Ereignisse"** (`CLAUDE.md`) und Spec, „Stufe
///   22": Die Migration legt **keine** Zeile an, auch keine OP „aus der
///   alten App".
///
/// Der Code der Stufe existierte beim Schreiben dieser Datei nicht.
/// Gelesen wurden Spec und Plan, nicht die spätere Implementierung.
///
/// ## Warum die 22 (ursprünglich die 21)
///
/// Am 10.11.2026 nachgesehen: `main` stand auf `schemaVersion => 20`
/// (#430, `mahlzeit_aufteilungen`). Die Spec reservierte die 21 für #404
/// und die 22 für #375; „Steht dort 19 oder 20, wird es die 21" (Plan, „Reihenfolge
/// und Zweige"). Die Stufe geht allein und als Erstes nach `main`.
///
/// Der Plan nennt als Altstand „den höchsten in `main`, heute v19". Seit
/// die 20 in `main` lag, war das v20 — gebaut ist er unten als v21.
///
/// **Seit dem 11.11.2026 ist es die 22** (#485): In `main` lag eine
/// unabhängig vergebene Stufe 18 — die drei Gym-Tabellen (#78) —, die auf
/// Tims iPhone schon gelaufen und dort in der Datei vermerkt ist.
/// Verschöbe man sie, liefe sie dort nie wieder. Beim Zusammenführen von
/// `umfaenge-88` und `main` behält sie deshalb die 18, und jede Stufe
/// dieses Zweigs ab 18 ist um eins nach oben gerückt; die Datei hieß bis
/// dahin `schema_v21_test.dart`, und der Altstand unten trägt
/// seitdem auch die drei Gym-Tabellen. Nachgezogen beim Zusammenführen,
/// **Tim hat die Änderung nicht gesehen**.
///
/// Nachbar von `schema_v21_test.dart` (auch dort legt eine Stufe eine
/// Tabelle an): derselbe Aufbau, von Hand gebaute Altstände, **nicht** aus
/// dem heutigen Code erzeugt (`migration_test.dart`, Dateikopf). Der Stand
/// v21 unten ist `v20Schema` aus `schema_v21_test.dart` mit
/// `mahlzeit_aufteilungen` so, wie `schema_v21_test.dart` sie festlegt.
///
/// **Diese Datei spricht die Tabelle nur über SQL an**, nicht über die
/// drift-Klassen. Sie übersetzt also auch dann, wenn es die Tabelle im
/// Code noch nicht gibt, und meldet dann, *was* fehlt, statt nur, dass sie
/// nicht baut. Den Weg über drift (`Ereignis`, Companion) prüft das
/// Repository (`ereignisse_test.dart`).
///
/// ## Was diese Datei verbindlich vorgibt
///
/// **1. `AppCache.schemaVersion >= 22`** und eine **eigene Stufe**
/// `if (from < 22) { … }`. Geprüft mit `>=`, damit diese Datei bei der
/// nächsten Stufe nicht mitfällt (#208). Nach dem Öffnen eines Altstands
/// steht `user_version` auf `schemaVersion`.
///
/// **2. Eine neue Tabelle `ereignisse`**, genau diese sieben Spalten (Spec,
/// Tabelle unter „Tabelle `ereignisse`"):
///
/// | Spalte | Typ | NULL | Vorgabe | Drift-Name |
/// |---|---|---|---|---|
/// | `id` | INTEGER, **Primärschlüssel**, AUTOINCREMENT | nein | — | `id` |
/// | `art` | TEXT | nein | — | `art` |
/// | `von` | TEXT (ISO-Tag) | nein | — | `von` |
/// | `bis` | TEXT (ISO-Tag) | nein | — | `bis` |
/// | `notiz` | TEXT | ja | — | `notiz` |
/// | `angelegt` | TEXT (DateTime, UTC) | nein | — | `angelegt` |
/// | `geaendert` | TEXT (DateTime, UTC) | ja | — | `geaendert` |
///
/// Kein Vorgabewert an keiner Spalte, kein Index (`_reconcileSchema` kennt
/// keine).
///
/// **3. Additiv, ohne Zeile.** Die Stufe legt **keine** Zeile an. Alle
/// übrigen Tabellen behalten jede Zeile und jeden Wert.
///
/// **4. Zweimal ausführbar** (#234/#240). Steht `ereignisse` schon in einer
/// Datei mit `user_version = 21`, öffnet sie trotzdem, und die Zeilen darin
/// bleiben.
///
/// **5. Abgleich** (#233). Eine Datei auf 22, der die Tabelle fehlt,
/// bekommt sie beim Öffnen, leer. Eine, deren Tabelle `geaendert` fehlt,
/// bekommt die Spalte, leer.
///
/// **6. Von weit unten:** Ein v11-Stand läuft durch alle Stufen.
///
/// **7. `angelegt` kommt als UTC zurück und ist gleich sich selbst**
/// (`CLAUDE.md`, „Zeitstempel liegen in der Datenbank als Text").
///
/// ## Festlegungen des Test-Agenten, nicht von Tim freigegeben
///
/// - **`art` nimmt jeden Text an.** Eine `CHECK`-Bedingung auf die vier
///   heutigen Arten ist verboten: Die Spec sieht vor, dass eine spätere
///   Fassung `spieltag` schreibt (#389, V20). Eine Tabelle, die das
///   ablehnt, müsste dafür neu gebaut werden — mit Tims Zeilen darin.
/// - **„`bis` nicht vor `von`" wird in der Tabelle weder verlangt noch
///   verboten.** V5 sichert das im Formular; ob die Tabelle zusätzlich
///   prüft, regelt diese Datei nicht.
/// - **Die Stufe räumt nicht auf.** Steht vorweg eine Zeile mit unbekannter
///   `art` da, bleibt sie. Sie zu übergehen ist Sache des Lesens (V20),
///   nicht der Migration; eine Migration, die Zeilen wegnimmt, nähme Tims
///   Einträge weg.
/// - **Eine gelöschte `id` wird nicht wieder vergeben.** Das ist, was
///   AUTOINCREMENT in SQLite zusichert, und V3 braucht es: Bei gleichem
///   `bis` nennt die Herleitung die zuletzt angelegte Auszeit, erkannt an
///   der höchsten `id`. Eine wiederverwendete Nummer machte eine neue
///   Auszeit zur älteren.
/// - **Ein zweites Öffnen ändert am Schema nichts mehr** (gemessen am
///   SQLite-Schema-Zähler, wie in `schema_v21_test.dart`).
///
/// ## Bestehende Tests, die mit dieser Stufe mitgehen
///
/// `schema_tabellen.dart` bekommt `tabellenAusStufe22` und die Tabelle in
/// [tabellenHeute]; `migration_test.dart` nennt die absolute Zahl 22;
/// `schema_abgleich_test.dart` die `heutigeNummer` 22 und die Tabelle im
/// vollständigen Schema; `schema_stufen_robust_test.dart` zählt je ein
/// `CREATE TABLE` mehr; `schema_v19_test.dart` und `schema_v21_test.dart`
/// nehmen in ihren Vorbedingungen die Tabellen der Stufe 22 aus dem
/// Vergleich ihres Altstands, weil der sie nicht haben kann. Alle
/// nachgezogen vom Test-Agenten (`TEST_AENDERN=1`), nicht von Tim gesehen.
///
/// **Alle Zahlen, Namen, Notizen und Zeitpunkte hier sind erfunden.** Die
/// Zeitpunkte liegen im Jahr 2099.
void main() {
  // --- Altstände, von Hand -----------------------------------------------

  /// Stand v21: `v20Schema` aus `schema_v21_test.dart`, dazu
  /// `mahlzeit_aufteilungen` (Stufe 21) wie dort festgelegt. Die drei
  /// Gym-Tabellen der Stufe 18 (#78) stehen seit dem Zusammenführen mit
  /// `main` mit darin (#485).
  const v21Schema = '''
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
    CREATE TABLE mahlzeit_aufteilungen (
      ab_tag TEXT NOT NULL PRIMARY KEY,
      fruehstueck_pct INTEGER,
      mittag_pct INTEGER,
      abend_pct INTEGER
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

  /// `ereignisse`, wie ein anderer Zweig sie schon angelegt haben könnte,
  /// von Hand nach der Tabelle im Dateikopf.
  const ereignisseVorweg = '''
    CREATE TABLE ereignisse (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      art TEXT NOT NULL,
      von TEXT NOT NULL,
      bis TEXT NOT NULL,
      notiz TEXT,
      angelegt TEXT NOT NULL,
      geaendert TEXT
    );
  ''';

  /// Zwei Zeilen darin: eine geänderte OP mit Notiz und eine Zeile mit
  /// einer Art, die diese Fassung nicht kennt. Beide muss die Stufe stehen
  /// lassen; die zweite zu übergehen ist Sache des Lesens (V20).
  const ereignisseZeilenVorweg = '''
    INSERT INTO ereignisse (id, art, von, bis, notiz, angelegt, geaendert)
      VALUES (1, 'op', '2099-03-02', '2099-03-16', 'Prüfnotiz',
              '2099-02-20T08:00:00.000Z', '2099-02-21T09:30:00.000Z');
    INSERT INTO ereignisse (id, art, von, bis, notiz, angelegt, geaendert)
      VALUES (2, 'pruefart', '2099-04-01', '2099-04-01', NULL,
              '2099-02-22T10:00:00.000Z', NULL);
  ''';

  /// Eine Tabelle, die ein halb fertiger Zweig angelegt hat: ohne
  /// `geaendert`.
  const ereignisseOhneGeaendert = '''
    CREATE TABLE ereignisse (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      art TEXT NOT NULL,
      von TEXT NOT NULL,
      bis TEXT NOT NULL,
      notiz TEXT,
      angelegt TEXT NOT NULL
    );
    INSERT INTO ereignisse (id, art, von, bis, notiz, angelegt)
      VALUES (7, 'urlaub', '2099-05-01', '2099-05-10', NULL,
              '2099-03-01T12:00:00.000Z');
  ''';

  /// Tims Bestand auf Stand v21: Einträge in drei Mahlzeiten (einer davon
  /// flüssig gebucht), zwei Kalorienziele, eine Aufteilung, Wasser, dazu
  /// Stammdaten, Vorlagen und KI. Eine Migration, die hier etwas verlöre,
  /// verlöre es endgültig.
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
      VALUES (2, 'Prüftrunk', 42.4, 88.8, 1, '0000000000021', 'off');
    INSERT INTO portionen (id, lebensmittel_id, name, menge_g, herkunft)
      VALUES (5, 1, 'Prüfbon', 5.9, 'eigen');
    INSERT INTO eintraege
      (id, tages_schluessel, mahlzeit, zeitpunkt, lebensmittel_id, name,
       menge_g, kcal, extra, health_uuid, health_stand, portion_id,
       portion_name, portion_g, fluessig)
      VALUES (1, '2099-03-01', 'fruehstueck', '2099-03-01T07:15:00.000Z', 1,
              'Prüfknäcke', 11.8, 44.6, '{}', 'PRUEF-UUID-0021',
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
    INSERT INTO mahlzeit_aufteilungen
      (ab_tag, fruehstueck_pct, mittag_pct, abend_pct)
      VALUES ('2099-02-25', 20, 40, 25);
    INSERT INTO ki_einstellungen (id, modell, limit_usd, preise)
      VALUES (0, 'pruef-modell-x', 3.5, '{}');
    INSERT INTO wasser_eintraege
      (id, tages_schluessel, zeitpunkt, menge_ml, health_stand)
      VALUES (4, '2099-03-01', '2099-03-01T09:15:00.000Z', 333.5, 'offen');
  ''';

  /// Schema v11, wörtlich aus `schema_v21_test.dart`: acht Tabellen, noch
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
    'mahlzeit_aufteilungen',
    'ki_einstellungen',
    'wasser_eintraege',
  ];

  /// Die Spalten der Tabelle nach dem Dateikopf.
  const spaltenEreignisse = {
    'id',
    'art',
    'von',
    'bis',
    'notiz',
    'angelegt',
    'geaendert',
  };

  /// Die Pflichtspalten, die als Text abgelegt werden, und warum als Text.
  const pflichtTexte = {
    'art': 'der Name aus EreignisArt',
    'von':
        'ein ISO-Tag — „WHERE von <= ? AND bis >= ?" vergleicht '
        'lexikografisch richtig',
    'bis': 'ein ISO-Tag, wie von',
    'angelegt':
        'DateTime als Text (storeDateTimeAsText), nicht als '
        'Unix-Sekunden',
  };

  /// Die nullbaren Spalten.
  const nullbareTexte = ['notiz', 'geaendert'];

  // --- Hilfsmittel, wie in `schema_v21_test.dart` ------------------------

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

  /// Die Form von `ereignisse` nach der Tabelle im Dateikopf.
  Future<void> pruefeForm(AppCache db) async {
    final s = await spalten(db, 'ereignisse');
    expect(
      s.keys.toSet(),
      spaltenEreignisse,
      reason:
          'genau die sieben Spalten der Spec. Keine Spalte „Wirkung": Die '
          'Wirkung folgt vorerst aus der Art (Entscheidung 2)',
    );

    expect(s['id']!.typ, 'INTEGER');
    expect(s['id']!.schluessel, isTrue);
    expect(s['id']!.nullbar, isFalse);
    expect(
      [
        for (final MapEntry(:key, :value) in s.entries)
          if (value.schluessel) key,
      ],
      ['id'],
      reason: 'die id allein ist der Schlüssel, kein zusammengesetzter',
    );

    for (final MapEntry(key: p, value: warum) in pflichtTexte.entries) {
      expect(s[p]!.typ, 'TEXT', reason: '$p: $warum');
      expect(s[p]!.nullbar, isFalse, reason: '$p ist Pflicht');
    }

    for (final p in nullbareTexte) {
      expect(s[p]!.typ, 'TEXT', reason: p);
      expect(
        s[p]!.nullbar,
        isTrue,
        reason: p == 'geaendert'
            ? 'geaendert ist NULL, solange die Zeile nie geändert wurde — '
                  'ein Zeitstempel beim Anlegen behauptete eine Änderung'
            : 'notiz: leer heißt NULL (V6)',
      );
    }

    for (final MapEntry(:key, :value) in s.entries) {
      expect(
        value.vorgabe,
        isNull,
        reason:
            '$key: kein Vorgabewert. Eine Vorgabe an art behauptete eine '
            'Art, die niemand gewählt hat; an von/bis einen Zeitraum, den '
            'niemand eingetragen hat',
      );
    }

    final sql =
        (await db
                .customSelect(
                  "SELECT sql FROM sqlite_master WHERE type = 'table' "
                  "AND name = 'ereignisse';",
                )
                .getSingle())
            .read<String>('sql');
    expect(
      sql.toUpperCase(),
      contains('AUTOINCREMENT'),
      reason:
          'die Spec verlangt AUTOINCREMENT: Nur damit vergibt SQLite eine '
          'gelöschte id nicht neu (V3, zuletzt angelegt = höchste id)',
    );

    final indizes = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index' "
          "AND tbl_name = 'ereignisse' AND sql IS NOT NULL;",
        )
        .get();
    expect(
      indizes,
      isEmpty,
      reason:
          'kein Index — _reconcileSchema kennt keine Indizes. Ein '
          'automatischer Index (sql IS NULL) zählt nicht',
    );
  }

  // ═════════════════════════════════════════════════════════════════════

  group('Vorbedingungen: die Altstände sind so gebaut, wie sie gemeint '
      'sind', () {
    test('v21 hat alle heutigen Tabellen außer der neuen', () {
      final roh = rohdatei(v21Schema, bestand, 21);
      addTearDown(roh.close);
      final namen = rohTabellen(roh);
      expect(namen, isNot(contains('ereignisse')));
      // Seit der Stufe 23 (#451) auch ohne deren Tabellen und seit der
      // Stufe 24 (#476) ohne die der Stufe 24: Die kann ein v21-Stand nicht
      // haben. Nachgezogen vom Test-Agenten, **Tim hat die Änderung nicht
      // gesehen.**
      expect(
        namen,
        tabellenHeute.difference({
          ...tabellenAusStufe22,
          ...tabellenAusStufe23,
          ...tabellenAusStufe24,
          ...tabellenAusStufe26,
          ...tabellenAusStufe27,
        }),
        reason:
            'v21 hat alle heutigen Tabellen außer denen der Stufe 22 und '
            'späterer Stufen',
      );
      expect(rohZeilen(roh, 'eintraege'), hasLength(3));
      expect(rohZeilen(roh, 'kalorienziele'), hasLength(2));
      expect(rohZeilen(roh, 'mahlzeit_aufteilungen'), hasLength(1));
      expect(rohZeilen(roh, 'wasser_eintraege'), hasLength(1));
    });

    test('v21 vorweg trägt die Tabelle schon, mit zwei Zeilen', () {
      final roh = rohdatei(
        v21Schema + ereignisseVorweg,
        bestand + ereignisseZeilenVorweg,
        21,
      );
      addTearDown(roh.close);
      expect(rohZeilen(roh, 'ereignisse'), hasLength(2));
    });
  });

  group('Schema v22 (#444) — frisch angelegt', () {
    test('die Version ist mindestens 22 und steht so in der Datei', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      expect(db.schemaVersion, greaterThanOrEqualTo(22));
      expect(await abgelegteVersion(db), db.schemaVersion);
    });

    test('ein frischer Cache hat die Tabelle, in der verlangten Form, und '
        'sie ist leer', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      expect(await tabellen(db), tabellenHeute);
      expect(await tabellen(db), contains('ereignisse'));
      await pruefeForm(db);
      expect(
        await zeilen(db, 'ereignisse'),
        isEmpty,
        reason:
            'auch ein frischer Cache trägt kein Ereignis: Kein Datum eines '
            'Ereignisses steht je im Quelltext (CLAUDE.md)',
      );
    });
  });

  group('Migration v21 → heute', () {
    test('legt die Tabelle an, mit der verlangten Form, und die Datei steht '
        'danach auf der heutigen Version', () async {
      final roh = rohdatei(v21Schema, bestand, 21);
      addTearDown(roh.close);
      final db = ueber(roh);
      addTearDown(db.close);

      expect(await abgelegteVersion(db), db.schemaVersion);
      expect(await tabellen(db), tabellenHeute);
      await pruefeForm(db);
    });

    test('legt keine Zeile an — die Tabelle ist leer', () async {
      final roh = rohdatei(v21Schema, bestand, 21);
      addTearDown(roh.close);
      final db = ueber(roh);
      addTearDown(db.close);

      expect(
        await zeilen(db, 'ereignisse'),
        isEmpty,
        reason:
            'die Migration legt keine OP an, auch keine „aus der alten '
            'App" (Spec, „Stufe 22"). Ein Ereignis aus der Migration wäre '
            'ein hartcodiertes Datum — genau der Fehler, der die Glocke der '
            'Altapp ein anderes OP-Datum sagen ließ als Plan und Gym',
      );
    });

    test(
      'additiv: jede Zeile und jeder Wert bleibt, in allen Tabellen',
      () async {
        final roh = rohdatei(v21Schema, bestand, 21);
        addTearDown(roh.close);
        final vorher = {for (final t in alle) t: rohZeilen(roh, t)};

        final db = ueber(roh);
        addTearDown(db.close);

        expect(
          await abgelegteVersion(db),
          greaterThanOrEqualTo(22),
          reason: 'die Stufe 22 ist über diesen Bestand gelaufen',
        );
        for (final t in alle) {
          pruefeUnveraendert(vorher[t]!, await zeilen(db, t), t);
        }
      },
    );

    test('ein zweites Öffnen derselben Datei ändert am Schema nichts mehr, '
        'und eine inzwischen angelegte Zeile bleibt', () async {
      final roh = rohdatei(v21Schema, bestand, 21);
      addTearDown(roh.close);

      final erstes = ueber(roh);
      await erstes.customStatement(
        'INSERT INTO ereignisse (art, von, bis, notiz, angelegt, geaendert) '
        "VALUES ('krankheit', '2099-03-03', '2099-03-06', NULL, "
        "'2099-03-03T07:00:00.000Z', NULL);",
      );
      await erstes.close();
      final nachErstem = schemaZaehler(roh);
      final zeilenNachErstem = rohZeilen(roh, 'ereignisse');

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
        await zeilen(zweites, 'ereignisse'),
        'ereignisse',
      );
    });
  });

  group('Die Stufe ist zweimal ausführbar (#234/#240)', () {
    test('steht die Tabelle schon da, öffnet die Datei, und jede Zeile darin '
        'bleibt — auch die mit unbekannter Art', () async {
      final roh = rohdatei(
        v21Schema + ereignisseVorweg,
        bestand + ereignisseZeilenVorweg,
        21,
      );
      addTearDown(roh.close);
      final vorher = {
        for (final t in [...alle, 'ereignisse']) t: rohZeilen(roh, t),
      };

      final db = ueber(roh);
      addTearDown(db.close);

      expect(await abgelegteVersion(db), db.schemaVersion);
      expect(
        await abgelegteVersion(db),
        greaterThanOrEqualTo(22),
        reason:
            'die Stufe 22 lief über eine Datei, die ihre Tabelle schon trug, '
            'und scheiterte nicht an „table already exists"',
      );
      for (final MapEntry(key: t, value: z) in vorher.entries) {
        pruefeUnveraendert(z, await zeilen(db, t), t);
      }
      await pruefeForm(db);
      expect(
        (await zeilen(db, 'ereignisse')).last['art'],
        'pruefart',
        reason:
            'die Migration räumt nicht auf: Eine Art, die diese Fassung nicht '
            'kennt, übergeht das Lesen (V20) — gelöscht wird sie nicht',
      );
    });
  });

  group('Abgleich beim Öffnen (#233)', () {
    test('eine Datei auf 22, der die Tabelle fehlt, bekommt sie — leer, und '
        'verliert nichts', () async {
      // Ein Zweig hat die Nummer hochgezogen, bevor seine Stufe fertig
      // war: `if (from < 22)` läuft dann nie.
      final roh = rohdatei(v21Schema, bestand, 22);
      addTearDown(roh.close);
      final vorher = {for (final t in alle) t: rohZeilen(roh, t)};

      final db = ueber(roh);
      addTearDown(db.close);
      // Der erste Zugriff: Das Öffnen selbst ist bei drift lazy.
      await db.customSelect('SELECT 1;').get();

      expect(
        await tabellen(db),
        contains('ereignisse'),
        reason:
            'onUpgrade läuft bei from == 22 nicht in die Stufe 22 — die '
            'Tabelle kommt nur über den Abgleich',
      );
      expect(await tabellen(db), tabellenHeute);
      await pruefeForm(db);
      expect(await zeilen(db, 'ereignisse'), isEmpty);
      for (final t in alle) {
        pruefeUnveraendert(vorher[t]!, await zeilen(db, t), t);
      }
    });

    test('eine Datei auf 22, deren Tabelle geaendert fehlt, bekommt die '
        'Spalte — leer, und die Zeile bleibt', () async {
      final roh = rohdatei(v21Schema + ereignisseOhneGeaendert, bestand, 22);
      addTearDown(roh.close);
      final vorher = rohZeilen(roh, 'ereignisse');

      final db = ueber(roh);
      addTearDown(db.close);
      await db.customSelect('SELECT 1;').get();

      expect((await spalten(db, 'ereignisse')).keys, contains('geaendert'));
      await pruefeForm(db);
      pruefeUnveraendert(vorher, await zeilen(db, 'ereignisse'), 'ereignisse');
      expect(
        (await zeilen(db, 'ereignisse')).single['geaendert'],
        isNull,
        reason:
            'der Abgleich erfindet keinen Zeitstempel, er hängt nur an — '
            'ein Wert behauptete eine Änderung, die es nie gab (CLAUDE.md: '
            'keine erfundenen Zeitstempel in einer Migration)',
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
      expect(await zeilen(db, 'ereignisse'), isEmpty);
      for (final MapEntry(key: t, value: z) in vorher.entries) {
        pruefeUnveraendert(z, await zeilen(db, t), t);
      }
    });
  });

  group('Die Zeilen', () {
    test('angelegt kommt als UTC zurück und ist gleich sich selbst; '
        'abgelegt ist es als Text', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);
      final angelegt = DateTime.utc(2099, 3, 1, 23, 30, 15, 250);
      final geaendert = DateTime.utc(2099, 3, 2, 0, 5);

      await db.customInsert(
        'INSERT INTO ereignisse (art, von, bis, notiz, angelegt, geaendert) '
        'VALUES (?, ?, ?, ?, ?, ?);',
        variables: [
          Variable<String>('op'),
          Variable<String>('2099-03-02'),
          Variable<String>('2099-03-16'),
          Variable<String>('Prüfnotiz'),
          Variable<DateTime>(angelegt),
          Variable<DateTime>(geaendert),
        ],
      );

      final zeile = await db
          .customSelect(
            'SELECT angelegt, geaendert, typeof(angelegt) AS art_angelegt, '
            'typeof(geaendert) AS art_geaendert FROM ereignisse;',
          )
          .getSingle();

      expect(
        zeile.read<String>('art_angelegt'),
        'text',
        reason:
            'Zeitstempel liegen als Text in der Datenbank; drifts Standard '
            '(Unix-Sekunden) gäbe sie als lokale Zeit zurück',
      );
      expect(zeile.read<String>('art_geaendert'), 'text');

      final gelesen = zeile.read<DateTime>('angelegt');
      expect(gelesen.isUtc, isTrue, reason: 'als UTC abgelegt, als UTC zurück');
      expect(
        gelesen,
        angelegt,
        reason:
            'Dart vergleicht DateTime samt isUtc — ein als UTC gespeicherter '
            'Wert, der als Ortszeit herauskäme, wäre ungleich sich selbst',
      );
      final gelesenGeaendert = zeile.read<DateTime>('geaendert');
      expect(gelesenGeaendert.isUtc, isTrue);
      expect(gelesenGeaendert, geaendert);
    });

    test('von und bis bleiben die ISO-Tage, die geschrieben wurden', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      await db.customStatement(
        'INSERT INTO ereignisse (art, von, bis, angelegt) '
        "VALUES ('verletzung', '2099-10-25', '2099-10-26', "
        "'2099-10-25T06:00:00.000Z');",
      );
      final zeile = (await zeilen(db, 'ereignisse')).single;
      expect(zeile['von'], '2099-10-25');
      expect(zeile['bis'], '2099-10-26');
      expect(
        zeile['notiz'],
        isNull,
        reason: 'notiz hat keine Vorgabe, also NULL',
      );
      expect(
        zeile['geaendert'],
        isNull,
        reason: 'geaendert hat keine Vorgabe — eine neue Zeile ist ungeändert',
      );
    });

    test('art nimmt eine Art an, die es heute nicht gibt', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      await db.customStatement(
        'INSERT INTO ereignisse (art, von, bis, angelegt) '
        "VALUES ('spieltag', '2099-06-06', '2099-06-06', "
        "'2099-06-01T08:00:00.000Z');",
      );
      expect(
        (await zeilen(db, 'ereignisse')).single['art'],
        'spieltag',
        reason:
            'mit #389 schreibt eine spätere Fassung den Spieltag in dieselbe '
            'Tabelle (V1, V20). Eine CHECK-Bedingung auf die vier heutigen '
            'Arten zwänge dann zum Neubau der Tabelle — mit Tims Zeilen',
      );
    });

    test('eine gelöschte id wird nicht wieder vergeben', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      Future<int> lege(String art) => db.customInsert(
        'INSERT INTO ereignisse (art, von, bis, angelegt) '
        "VALUES ('$art', '2099-03-02', '2099-03-16', "
        "'2099-03-01T08:00:00.000Z');",
      );

      await lege('op');
      final zweite = await lege('krankheit');
      await db.customStatement('DELETE FROM ereignisse WHERE id = $zweite;');
      final dritte = await lege('urlaub');

      expect(
        dritte,
        greaterThan(zweite),
        reason:
            'AUTOINCREMENT: Bei gleichem bis nennt die Herleitung die '
            'zuletzt angelegte Auszeit, erkannt an der höchsten id (V3). '
            'Eine wiederverwendete Nummer machte die neue zur älteren',
      );
    });
  });
}
