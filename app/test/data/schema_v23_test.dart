import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show Database, sqlite3;

import 'package:repit/data/cache.dart';

import 'schema_tabellen.dart';

/// Tests für **Schema v23**: die Tabelle `wach_belege`, in der die App
/// mitschreibt, wann Tim nachweislich wach war — das Öffnen der App und
/// jede Buchung (#451, unter #375, Tagesgrenze).
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden. Jede Migration
/// bekommt einen Test, dies ist der für die Stufe 22.
///
/// ## Woher die Anforderung kommt
///
/// Spec `docs/superpowers/specs/2026-11-10-tagesgrenze-design.md`, Abschnitt
/// „Die Datenschicht", und Plan
/// `docs/superpowers/plans/2026-11-10-tagesgrenze.md`, Task 1, Step 1 (dort
/// stehen die Pflichtfälle). Für diese Stufe tragen laut Spec:
///
/// - **Entscheidung 3** (dort als Tims Entscheidung vom 10.11.2026
///   geführt): „Das Öffnen der App wird dafür mitgeschrieben, in einer
///   kleinen Tabelle mit Migrationstest."
/// - **V13** (vom Planenden formuliert, laut Spec von Tim übernommen):
///   Belege `oeffnen` und `buchung`; die Tabelle wird nie geleert; eine
///   Zeile sind drei Spalten.
/// - **Spec, „Stufe 23":** Additiv, **ohne eine einzige Zeile.** Die
///   Migration erfindet kein Öffnen der App, auch nicht „jetzt" — ein
///   Beleg mit dem Zeitpunkt der Migration behauptete, Tim sei in diesem
///   Moment wach gewesen.
///
/// Der Code der Stufe existierte beim Schreiben dieser Datei nicht.
/// Gelesen wurden Spec und Plan, nicht die spätere Implementierung.
///
/// ## Warum die 23 (ursprünglich die 22)
///
/// Am 10.11.2026 nachgesehen: `main` stand auf `schemaVersion => 21`
/// (#444, `ereignisse`). Die Spec reservierte die 22 für #375; „Steht
/// dort 21, wird es die 22" (Plan, „Reihenfolge und Zweige"). Die Stufe
/// ging nach der 21 und allein nach `main`.
///
/// **Seit dem 11.11.2026 ist es die 23** (#485): In `main` lag eine
/// unabhängig vergebene Stufe 18 — die drei Gym-Tabellen (#78) —, die auf
/// Tims iPhone schon gelaufen und dort in der Datei vermerkt ist.
/// Verschöbe man sie, liefe sie dort nie wieder. Beim Zusammenführen von
/// `umfaenge-88` und `main` behält sie deshalb die 18, und jede Stufe
/// dieses Zweigs ab 18 ist um eins nach oben gerückt; die Datei hieß bis
/// dahin `schema_v22_test.dart`, und der Altstand unten trägt
/// seitdem auch die drei Gym-Tabellen. Nachgezogen beim Zusammenführen,
/// **Tim hat die Änderung nicht gesehen**.
///
/// Nachbar von `schema_v22_test.dart` (auch dort legt eine Stufe eine
/// Tabelle an): derselbe Aufbau, von Hand gebaute Altstände, **nicht** aus
/// dem heutigen Code erzeugt (`migration_test.dart`, Dateikopf). Der Stand
/// v22 unten ist `v21Schema` aus `schema_v22_test.dart` mit `ereignisse`
/// so, wie `schema_v22_test.dart` sie festlegt.
///
/// **Diese Datei spricht die Tabelle nur über SQL an**, nicht über die
/// drift-Klassen. Sie übersetzt also auch dann, wenn es die Tabelle im
/// Code noch nicht gibt, und meldet dann, *was* fehlt, statt nur, dass sie
/// nicht baut. Den Weg über drift (Repository, `WachArt`) prüft
/// `wach_belege_test.dart` (Task 4).
///
/// ## Was diese Datei verbindlich vorgibt
///
/// **1. `AppCache.schemaVersion >= 23`** und eine **eigene Stufe**
/// `if (from < 23) { … }`. Geprüft mit `>=`, damit diese Datei bei der
/// nächsten Stufe nicht mitfällt (#208). Nach dem Öffnen eines Altstands
/// steht `user_version` auf `schemaVersion`.
///
/// **2. Eine neue Tabelle `wach_belege`**, genau diese drei Spalten (Spec,
/// Tabelle unter „Tabelle `wach_belege`"):
///
/// | Spalte | Typ | NULL | Vorgabe | Drift-Name |
/// |---|---|---|---|---|
/// | `id` | INTEGER, **Primärschlüssel**, AUTOINCREMENT | nein | — | `id` |
/// | `zeitpunkt` | TEXT (DateTime, UTC) | nein | — | `zeitpunkt` |
/// | `art` | TEXT | nein | — | `art` |
///
/// Kein Vorgabewert an keiner Spalte, **kein Index** (Spec:
/// `_reconcileSchema` kennt keine).
///
/// **3. Additiv, ohne Zeile.** Die Stufe legt **keine** Zeile an, auch
/// keinen Beleg „jetzt". Alle übrigen Tabellen behalten jede Zeile und
/// jeden Wert.
///
/// **4. Zweimal ausführbar** (#234/#240). Steht `wach_belege` schon in
/// einer Datei mit `user_version = 22`, öffnet sie trotzdem, und die
/// Zeilen darin bleiben.
///
/// **5. Abgleich** (#233). Eine Datei auf 23, der die Tabelle fehlt,
/// bekommt sie beim Öffnen, leer.
///
/// **6. Von weit unten:** Ein v11-Stand läuft durch alle Stufen.
///
/// **7. `zeitpunkt` kommt als UTC zurück und ist gleich sich selbst**
/// (`CLAUDE.md`, „Zeitstempel liegen in der Datenbank als Text").
///
/// ## Festlegungen des Test-Agenten, nicht von Tim freigegeben
///
/// Was folgt, steht so weder in der Spec noch im Plan. Es hat der
/// Test-Agent beim Schreiben dieser Datei festgelegt; Tim hat es nicht
/// gesehen.
///
/// - **`art` nimmt jeden Text an.** Die Spec sagt, das Lesen übergehe
///   unbekannte Werte — dafür muss die Tabelle sie annehmen. Eine
///   `CHECK`-Bedingung auf `oeffnen`/`buchung` ist deshalb verboten: Eine
///   spätere Fassung, die eine dritte Art schreibt, müsste die Tabelle
///   sonst neu bauen.
/// - **Die Stufe räumt nicht auf.** Steht vorweg eine Zeile mit unbekannter
///   `art` da, bleibt sie. Sie zu übergehen ist Sache des Lesens, nicht der
///   Migration; die Tabelle wird nie geleert (V13).
/// - **Ein zweites Öffnen ändert am Schema nichts mehr** (gemessen am
///   SQLite-Schema-Zähler, wie in `schema_v22_test.dart`).
/// - **Die Ereignisse der Stufe 22 gehören zum Bestand**, den die Stufe 23
///   nicht anrühren darf.
///
/// ## Bestehende Tests, die mit dieser Stufe mitgehen
///
/// `schema_tabellen.dart` bekommt `tabellenAusStufe23` und die Tabelle in
/// [tabellenHeute]; `migration_test.dart` nennt die absolute Zahl 23;
/// `schema_abgleich_test.dart` die `heutigeNummer` 23 und die Tabelle im
/// vollständigen Schema; `schema_stufen_robust_test.dart` zählt je ein
/// `CREATE TABLE` mehr; `schema_v19_test.dart`, `schema_v21_test.dart` und
/// `schema_v22_test.dart` nehmen in ihren Vorbedingungen die Tabellen der
/// Stufe 23 aus dem Vergleich ihres Altstands, weil der sie nicht haben
/// kann. Alle nachgezogen vom Test-Agenten (`TEST_AENDERN=1`), nicht von
/// Tim gesehen.
///
/// **Alle Zahlen, Namen, Notizen und Zeitpunkte hier sind erfunden.** Die
/// Zeitpunkte liegen im Jahr 2099.
void main() {
  // --- Altstände, von Hand -----------------------------------------------

  /// Stand v22: `v21Schema` aus `schema_v22_test.dart`, dazu `ereignisse`
  /// (Stufe 22) wie dort festgelegt. Die drei Gym-Tabellen der Stufe 18
  /// (#78) stehen seit dem Zusammenführen mit `main` mit darin (#485).
  const v22Schema = '''
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
    CREATE TABLE ereignisse (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      art TEXT NOT NULL,
      von TEXT NOT NULL,
      bis TEXT NOT NULL,
      notiz TEXT,
      angelegt TEXT NOT NULL,
      geaendert TEXT
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

  /// `wach_belege`, wie ein anderer Zweig sie schon angelegt haben könnte,
  /// von Hand nach der Tabelle im Dateikopf.
  const wachBelegeVorweg = '''
    CREATE TABLE wach_belege (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      zeitpunkt TEXT NOT NULL,
      art TEXT NOT NULL
    );
  ''';

  /// Drei Zeilen darin: ein Öffnen, eine Buchung und eine Zeile mit einer
  /// Art, die diese Fassung nicht kennt. Alle drei muss die Stufe stehen
  /// lassen; die dritte zu übergehen ist Sache des Lesens.
  const wachBelegeZeilenVorweg = '''
    INSERT INTO wach_belege (id, zeitpunkt, art)
      VALUES (1, '2099-03-01T23:40:00.000Z', 'oeffnen');
    INSERT INTO wach_belege (id, zeitpunkt, art)
      VALUES (2, '2099-03-02T00:15:30.000Z', 'buchung');
    INSERT INTO wach_belege (id, zeitpunkt, art)
      VALUES (3, '2099-03-02T01:05:00.000Z', 'pruefart');
  ''';

  /// Tims Bestand auf Stand v22: Einträge in drei Mahlzeiten (einer davon
  /// flüssig gebucht), zwei Kalorienziele, eine Aufteilung, Wasser, zwei
  /// Ereignisse, dazu Stammdaten, Vorlagen und KI. Eine Migration, die hier
  /// etwas verlöre, verlöre es endgültig.
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
      VALUES (2, 'Prüftrunk', 42.4, 88.8, 1, '0000000000022', 'off');
    INSERT INTO portionen (id, lebensmittel_id, name, menge_g, herkunft)
      VALUES (5, 1, 'Prüfbon', 5.9, 'eigen');
    INSERT INTO eintraege
      (id, tages_schluessel, mahlzeit, zeitpunkt, lebensmittel_id, name,
       menge_g, kcal, extra, health_uuid, health_stand, portion_id,
       portion_name, portion_g, fluessig)
      VALUES (1, '2099-03-01', 'fruehstueck', '2099-03-01T07:15:00.000Z', 1,
              'Prüfknäcke', 11.8, 44.6, '{}', 'PRUEF-UUID-0022',
              'geschrieben', 5, 'Prüfbon', 5.9, 0);
    INSERT INTO eintraege
      (id, tages_schluessel, mahlzeit, zeitpunkt, lebensmittel_id, name,
       menge_g, kcal, extra, health_stand, vorschlag, fluessig)
      VALUES (2, '2099-03-01', 'abend', '2099-03-02T00:45:00.000Z', NULL,
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
    INSERT INTO ereignisse (id, art, von, bis, notiz, angelegt, geaendert)
      VALUES (1, 'op', '2099-03-02', '2099-03-16', 'Prüfnotiz',
              '2099-02-20T08:00:00.000Z', '2099-02-21T09:30:00.000Z');
    INSERT INTO ereignisse (id, art, von, bis, notiz, angelegt, geaendert)
      VALUES (2, 'urlaub', '2099-05-01', '2099-05-10', NULL,
              '2099-03-01T12:00:00.000Z', NULL);
  ''';

  /// Schema v11, wörtlich aus `schema_v22_test.dart`: acht Tabellen, noch
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
    'ereignisse',
  ];

  /// Die Spalten der Tabelle nach dem Dateikopf.
  const spaltenWachBelege = {'id', 'zeitpunkt', 'art'};

  /// Die Pflichtspalten, die als Text abgelegt werden, und warum als Text.
  const pflichtTexte = {
    'zeitpunkt':
        'DateTime als Text (storeDateTimeAsText), nicht als '
        'Unix-Sekunden — sonst käme er als Ortszeit zurück, und das '
        'Fenster „WHERE zeitpunkt BETWEEN ? AND ?" vergliche Zahlen mit '
        'Text',
    'art': 'der Name aus WachArt (oeffnen oder buchung, V13)',
  };

  // --- Hilfsmittel, wie in `schema_v22_test.dart` ------------------------

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

  /// Die Form von `wach_belege` nach der Tabelle im Dateikopf.
  Future<void> pruefeForm(AppCache db) async {
    final s = await spalten(db, 'wach_belege');
    expect(
      s.keys.toSet(),
      spaltenWachBelege,
      reason:
          'genau die drei Spalten der Spec: „Eine Zeile sind drei Spalten" '
          '(V13)',
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
      reason:
          'die id allein ist der Schlüssel. Ein Schlüssel über zeitpunkt '
          'verböte zwei Belege im selben Augenblick — ein Öffnen und eine '
          'Buchung in derselben Millisekunde sind zwei Belege',
    );

    for (final MapEntry(key: p, value: warum) in pflichtTexte.entries) {
      expect(s[p]!.typ, 'TEXT', reason: '$p: $warum');
      expect(s[p]!.nullbar, isFalse, reason: '$p ist Pflicht');
    }

    for (final MapEntry(:key, :value) in s.entries) {
      expect(
        value.vorgabe,
        isNull,
        reason:
            '$key: kein Vorgabewert. Eine Vorgabe an art behauptete eine '
            'Art, die niemand gemeldet hat; an zeitpunkt (etwa '
            'CURRENT_TIMESTAMP) einen Moment, in dem Tim wach gewesen sein '
            'soll',
      );
    }

    final sql =
        (await db
                .customSelect(
                  "SELECT sql FROM sqlite_master WHERE type = 'table' "
                  "AND name = 'wach_belege';",
                )
                .getSingle())
            .read<String>('sql');
    expect(
      sql.toUpperCase(),
      contains('AUTOINCREMENT'),
      reason: 'die Spec verlangt id als INTEGER mit AUTOINCREMENT',
    );

    final indizes = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index' "
          "AND tbl_name = 'wach_belege' AND sql IS NOT NULL;",
        )
        .get();
    expect(
      indizes,
      isEmpty,
      reason:
          'kein Index — _reconcileSchema kennt keine Indizes (Spec). Ein '
          'automatischer Index (sql IS NULL) zählt nicht',
    );
  }

  // ═════════════════════════════════════════════════════════════════════

  group('Vorbedingungen: die Altstände sind so gebaut, wie sie gemeint '
      'sind', () {
    test('v22 hat alle heutigen Tabellen außer der neuen', () {
      final roh = rohdatei(v22Schema, bestand, 22);
      addTearDown(roh.close);
      final namen = rohTabellen(roh);
      expect(namen, isNot(contains('wach_belege')));
      // Seit der Stufe 24 (#476) auch ohne deren Tabellen: Die kann ein
      // v22-Stand nicht haben. Nachgezogen vom Test-Agenten, **Tim hat die
      // Änderung nicht gesehen.**
      expect(
        namen,
        tabellenHeute.difference({
          ...tabellenAusStufe23,
          ...tabellenAusStufe24,
          ...tabellenAusStufe26,
          ...tabellenAusStufe27,
        }),
        reason:
            'v22 hat alle heutigen Tabellen außer denen der Stufe 23 und '
            'späterer Stufen',
      );
      expect(rohZeilen(roh, 'eintraege'), hasLength(3));
      expect(rohZeilen(roh, 'kalorienziele'), hasLength(2));
      expect(rohZeilen(roh, 'mahlzeit_aufteilungen'), hasLength(1));
      expect(rohZeilen(roh, 'wasser_eintraege'), hasLength(1));
      expect(rohZeilen(roh, 'ereignisse'), hasLength(2));
    });

    test('v22 vorweg trägt die Tabelle schon, mit drei Zeilen', () {
      final roh = rohdatei(
        v22Schema + wachBelegeVorweg,
        bestand + wachBelegeZeilenVorweg,
        22,
      );
      addTearDown(roh.close);
      expect(rohZeilen(roh, 'wach_belege'), hasLength(3));
    });
  });

  group('Schema v23 (#451) — frisch angelegt', () {
    test('die Version ist mindestens 23 und steht so in der Datei', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      expect(db.schemaVersion, greaterThanOrEqualTo(23));
      expect(await abgelegteVersion(db), db.schemaVersion);
    });

    test('ein frischer Cache hat die Tabelle, in der verlangten Form, und '
        'sie ist leer', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      expect(await tabellen(db), tabellenHeute);
      expect(await tabellen(db), contains('wach_belege'));
      await pruefeForm(db);
      expect(
        await zeilen(db, 'wach_belege'),
        isEmpty,
        reason:
            'auch das Anlegen des Caches ist kein Öffnen der App durch Tim. '
            'Belege schreibt die App, nicht das Schema',
      );
    });
  });

  group('Migration v22 → heute', () {
    test('legt die Tabelle an, mit der verlangten Form, und die Datei steht '
        'danach auf der heutigen Version', () async {
      final roh = rohdatei(v22Schema, bestand, 22);
      addTearDown(roh.close);
      final db = ueber(roh);
      addTearDown(db.close);

      expect(await abgelegteVersion(db), db.schemaVersion);
      expect(
        await abgelegteVersion(db),
        greaterThanOrEqualTo(23),
        reason: 'die Stufe 23 ist über diesen Bestand gelaufen',
      );
      expect(await tabellen(db), tabellenHeute);
      await pruefeForm(db);
    });

    test('legt keine Zeile an — die Tabelle ist leer, auch kein Beleg '
        '„jetzt"', () async {
      final roh = rohdatei(v22Schema, bestand, 22);
      addTearDown(roh.close);
      final db = ueber(roh);
      addTearDown(db.close);

      expect(
        await zeilen(db, 'wach_belege'),
        isEmpty,
        reason:
            'die Migration erfindet kein Öffnen der App, auch nicht „jetzt" '
            '(Spec, „Stufe 23"). Ein Beleg mit dem Zeitpunkt der Migration '
            'behauptete, Tim sei in diesem Moment wach gewesen — und könnte '
            'einen Tag verlängern, der längst vorbei ist. Den ersten Beleg '
            'schreibt die App beim Kaltstart, nicht die Migration',
      );
    });

    test(
      'additiv: jede Zeile und jeder Wert bleibt, in allen Tabellen',
      () async {
        final roh = rohdatei(v22Schema, bestand, 22);
        addTearDown(roh.close);
        final vorher = {for (final t in alle) t: rohZeilen(roh, t)};

        final db = ueber(roh);
        addTearDown(db.close);

        expect(
          await abgelegteVersion(db),
          greaterThanOrEqualTo(23),
          reason: 'die Stufe 23 ist über diesen Bestand gelaufen',
        );
        for (final t in alle) {
          pruefeUnveraendert(vorher[t]!, await zeilen(db, t), t);
        }
      },
    );

    test('ein zweites Öffnen derselben Datei ändert am Schema nichts mehr, '
        'und ein inzwischen geschriebener Beleg bleibt', () async {
      final roh = rohdatei(v22Schema, bestand, 22);
      addTearDown(roh.close);

      final erstes = ueber(roh);
      await erstes.customStatement(
        'INSERT INTO wach_belege (zeitpunkt, art) '
        "VALUES ('2099-03-02T02:10:00.000Z', 'oeffnen');",
      );
      await erstes.close();
      final nachErstem = schemaZaehler(roh);
      final zeilenNachErstem = rohZeilen(roh, 'wach_belege');

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
        await zeilen(zweites, 'wach_belege'),
        'wach_belege',
      );
      expect(
        zeilenNachErstem,
        hasLength(1),
        reason: 'Vorbedingung: der Beleg ist geschrieben',
      );
    });
  });

  group('Die Stufe ist zweimal ausführbar (#234/#240)', () {
    test('steht die Tabelle schon da, öffnet die Datei, und jede Zeile darin '
        'bleibt — auch die mit unbekannter Art', () async {
      final roh = rohdatei(
        v22Schema + wachBelegeVorweg,
        bestand + wachBelegeZeilenVorweg,
        22,
      );
      addTearDown(roh.close);
      final vorher = {
        for (final t in [...alle, 'wach_belege']) t: rohZeilen(roh, t),
      };

      final db = ueber(roh);
      addTearDown(db.close);

      expect(await abgelegteVersion(db), db.schemaVersion);
      expect(
        await abgelegteVersion(db),
        greaterThanOrEqualTo(23),
        reason:
            'die Stufe 23 lief über eine Datei, die ihre Tabelle schon trug, '
            'und scheiterte nicht an „table already exists"',
      );
      for (final MapEntry(key: t, value: z) in vorher.entries) {
        pruefeUnveraendert(z, await zeilen(db, t), t);
      }
      await pruefeForm(db);
      expect(
        (await zeilen(db, 'wach_belege')).last['art'],
        'pruefart',
        reason:
            'die Migration räumt nicht auf: Eine Art, die diese Fassung nicht '
            'kennt, übergeht das Lesen — gelöscht wird sie nicht. Die '
            'Tabelle wird nie geleert (V13)',
      );
    });
  });

  group('Abgleich beim Öffnen (#233)', () {
    test('eine Datei auf 23, der die Tabelle fehlt, bekommt sie — leer, und '
        'verliert nichts', () async {
      // Ein Zweig hat die Nummer hochgezogen, bevor seine Stufe fertig
      // war: `if (from < 23)` läuft dann nie.
      final roh = rohdatei(v22Schema, bestand, 23);
      addTearDown(roh.close);
      final vorher = {for (final t in alle) t: rohZeilen(roh, t)};

      final db = ueber(roh);
      addTearDown(db.close);
      // Der erste Zugriff: Das Öffnen selbst ist bei drift lazy.
      await db.customSelect('SELECT 1;').get();

      expect(
        await tabellen(db),
        contains('wach_belege'),
        reason:
            'onUpgrade läuft bei from == 23 nicht in die Stufe 23 — die '
            'Tabelle kommt nur über den Abgleich',
      );
      expect(await tabellen(db), tabellenHeute);
      await pruefeForm(db);
      expect(await zeilen(db, 'wach_belege'), isEmpty);
      for (final t in alle) {
        pruefeUnveraendert(vorher[t]!, await zeilen(db, t), t);
      }
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
      expect(await zeilen(db, 'wach_belege'), isEmpty);
      for (final MapEntry(key: t, value: z) in vorher.entries) {
        pruefeUnveraendert(z, await zeilen(db, t), t);
      }
    });
  });

  group('Die Zeilen', () {
    test('zeitpunkt kommt als UTC zurück und ist gleich sich selbst; '
        'abgelegt ist er als Text', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);
      // 00:30:15,250 UTC in der Nacht der Zeitumstellung im Oktober — in
      // Berlin 02:30:15 Sommerzeit, die erste der beiden 02:30.
      final zeitpunkt = DateTime.utc(2099, 10, 25, 0, 30, 15, 250);

      await db.customInsert(
        'INSERT INTO wach_belege (zeitpunkt, art) VALUES (?, ?);',
        variables: [Variable<DateTime>(zeitpunkt), Variable<String>('buchung')],
      );

      final zeile = await db
          .customSelect(
            'SELECT zeitpunkt, typeof(zeitpunkt) AS art_zeitpunkt '
            'FROM wach_belege;',
          )
          .getSingle();

      expect(
        zeile.read<String>('art_zeitpunkt'),
        'text',
        reason:
            'Zeitstempel liegen als Text in der Datenbank; drifts Standard '
            '(Unix-Sekunden) gäbe sie als lokale Zeit zurück',
      );

      final gelesen = zeile.read<DateTime>('zeitpunkt');
      expect(gelesen.isUtc, isTrue, reason: 'als UTC abgelegt, als UTC zurück');
      expect(
        gelesen,
        zeitpunkt,
        reason:
            'Dart vergleicht DateTime samt isUtc — ein als UTC gespeicherter '
            'Wert, der als Ortszeit herauskäme, wäre ungleich sich selbst. '
            'Die Kette der Tagesgrenze rechnet mit 60 Minuten Lücke; eine '
            'Stunde Versatz machte aus ihr eine andere',
      );
    });

    test('art nimmt eine Art an, die es heute nicht gibt', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      await db.customStatement(
        'INSERT INTO wach_belege (zeitpunkt, art) '
        "VALUES ('2099-06-06T01:00:00.000Z', 'pruefart');",
      );
      expect(
        (await zeilen(db, 'wach_belege')).single['art'],
        'pruefart',
        reason:
            'unbekannte Werte übergeht das Lesen (Spec) — also muss die '
            'Tabelle sie annehmen. Eine CHECK-Bedingung auf oeffnen und '
            'buchung zwänge eine spätere Fassung mit einer dritten Art zum '
            'Neubau der Tabelle',
      );
    });

    test('zeitpunkt und art sind Pflicht', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      await expectLater(
        db.customStatement("INSERT INTO wach_belege (art) VALUES ('oeffnen');"),
        throwsA(anything),
        reason:
            'ein Beleg ohne Zeitpunkt belegt nichts — und eine Vorgabe '
            'dafür erfände einen',
      );
      await expectLater(
        db.customStatement(
          'INSERT INTO wach_belege (zeitpunkt) '
          "VALUES ('2099-06-06T01:00:00.000Z');",
        ),
        throwsA(anything),
        reason: 'ein Beleg ohne Art ist weder Öffnen noch Buchung',
      );
      expect(await zeilen(db, 'wach_belege'), isEmpty);
    });
  });
}
