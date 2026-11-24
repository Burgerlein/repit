// `drift` exportiert eigene `isNull` und `isNotNull` — dieselbe Begründung
// wie in `test/data/schema_v13_test.dart`, Zeile 1–5.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show Database, sqlite3;

import 'package:repit/data/cache.dart';

import 'schema_tabellen.dart';

/// Tests für **Schema v20** — `eintraege.fluessig`, der Schnappschuss
/// „in Millilitern gebucht" am Eintrag (#403, unter #275).
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden. Jede Migration
/// bekommt einen Test — dies ist der für die Stufe 20.
///
/// Geschrieben nach dem Ticket #403 („Mahlzeitenzeile: Getränke stehen mit
/// g statt ml") und dem Auftrag des Koordinators vom 10.11.2026 — **ohne**
/// den Code der Stufe gesehen zu haben (es gab ihn beim Schreiben noch
/// nicht).
///
/// ## Warum die 20 (ursprünglich die 19, und nicht die 18)
///
/// Die Nummer wurde am 10.11.2026 aus `cache.dart` gelesen, auf diesem
/// Zweig (`getraenke-ml`), in `main` und auf dem Zweig `ziel-fest`: überall
/// `schemaVersion => 17`. **Die 18 ist trotzdem nicht frei:** Auf
/// `ziel-fest` entsteht parallel eine eigene Stufe, und sie bekommt
/// voraussichtlich die 18. Zwei Zweige, die beide die 18 nehmen, laufen
/// genau in den Fall, den der Kopf von `schemaVersion` in `cache.dart`
/// beschreibt: Auf einem Gerät, das schon auf 18 steht, liefe die zweite
/// Stufe 18 nie. Deshalb nimmt diese Stufe die **übernächste** Nummer.
///
/// **Beim Zusammenführen:** Die Stufe 18 von `ziel-fest` muss **vor oder
/// mit** dieser in `main` landen. Landet die 19 zuerst und wird ein Gerät
/// damit installiert, steht es auf 19 und überspränge eine später
/// nachgereichte Stufe 18 — dann trüge nur noch der Abgleich (#233) ihre
/// Spalten nach. Kommt die 18 nie, ist die Lücke harmlos: Eine Stufe
/// `if (from < 18)`, die es nicht gibt, fehlt niemandem.
///
/// **Seit dem 11.11.2026 ist es die 20** (#485): In `main` liegt eine
/// dritte, unabhängig vergebene Stufe 18 — die drei Gym-Tabellen (#78) —,
/// und die ist auf Tims iPhone schon gelaufen. Beim Zusammenführen von
/// `umfaenge-88` und `main` behält sie die 18, das feste Kalorienziel
/// rückt auf die 19 und diese Stufe auf die 20. Die Datei hieß bis dahin
/// `schema_v19_test.dart`. Nachgezogen beim Zusammenführen, **Tim hat die
/// Änderung nicht gesehen**.
///
/// Nachbar von `schema_v17_test.dart`: derselbe Aufbau, dieselben
/// Hilfsmittel, von Hand gebaute Altstände — **nicht** aus dem heutigen
/// Code erzeugt (`migration_test.dart`, Dateikopf). Der Stand v17 unten ist
/// der von `schema_v17_test.dart` nach der Stufe 17: `lebensmittel` mit
/// Marke, `portionen` mit Spalten, `eintraege` mit Portions-Schnappschuss.
///
/// ## Was diese Datei verbindlich vorgibt
///
/// **1. `AppCache.schemaVersion >= 20`** und eine **eigene Stufe**
/// `if (from < 20) { … }`. Geprüft mit `>=`, damit diese Datei bei der
/// nächsten Stufe nicht mitfällt (#208).
///
/// **2. `eintraege.fluessig`**: INTEGER, **nullbar**, **ohne Vorgabewert**,
/// Drift-Name `fluessig`. `1` heißt „in Millilitern gebucht", `0` „in
/// Gramm", `NULL` „unbekannt". Geschrieben wird es beim Buchen als
/// Schnappschuss aus `LebensmittelVorlage.fluessig`, eingefroren wie die
/// Nährwerte (`eintrag_fluessig_test.dart`).
///
/// **3. Additiv, ohne Rückschreiben.** Alte Einträge tragen danach `NULL`
/// — **auch die, deren Vorlage flüssig ist.** Die Stufe liest nicht aus
/// `lebensmittel` nach: Was die Vorlage heute sagt, ist nicht, was beim
/// Buchen galt, und eine Migration erfindet keinen Schnappschuss. Die
/// Anzeige fällt bei `NULL` auf die Vorlage zurück, sonst auf „g"
/// (`getraenk_ml_test.dart`). Alle übrigen Tabellen behalten jede Zeile
/// und jeden Wert; `lebensmittel.fluessig` bleibt, wie es ist.
///
/// **4. Zweimal ausführbar** (#234/#240): Ein v17-Stand, der die Spalte
/// schon trägt, öffnet, und ihre Werte bleiben.
///
/// **5. Abgleich** (#233): Eine Datei auf 20, der die Spalte fehlt, bekommt
/// sie beim Öffnen — leer, ohne erfundene Werte.
///
/// **6. Von weit unten:** Ein v11-Stand läuft durch alle Stufen, ohne an
/// `duplicate column name` zu sterben.
///
/// **7. Kein Index über `eintraege.fluessig`** — `_reconcileSchema` kennt
/// keine Indizes (dieselbe Begründung wie in `schema_v17_test.dart`).
///
/// ## Festlegungen des Test-Agenten — nicht von Tim freigegeben
///
/// - **Weg (a), Schnappschuss am Eintrag, statt (b), aus der Vorlage
///   lesen.** Empfohlen vom Koordinator, gewählt vom Test-Agenten: Ein
///   Eintrag soll auch nach Löschen oder Ändern der Vorlage stimmen, und
///   das passt zum Prinzip der eingefrorenen Werte am Eintrag. Ein Grund
///   dagegen fand sich nicht.
/// - **Nullbar statt `NOT NULL DEFAULT 0`.** Ein Vorgabewert `0` behauptete
///   für jedes alte Getränk „in Gramm gebucht" — `01` in neuer Verpackung,
///   und die Anzeige könnte dann nicht mehr auf die Vorlage zurückfallen.
/// - **Eine `CHECK`-Bedingung wird nicht verlangt.** `lebensmittel
///   .fluessig` trägt eine; ob die neue Spalte sie auch trägt, regelt
///   dieser Test nicht.
/// - **Ein zweites Öffnen ändert am Schema nichts mehr** (gemessen am
///   SQLite-Schema-Zähler, wie in `schema_v17_test.dart`).
///
/// ## Bestehende Tests, die mit dieser Stufe mitgehen
///
/// `migration_test.dart` nennt die absolute Zahl 17, `schema_abgleich_test
/// .dart` die `heutigeNummer` 17 und ein vollständiges Schema ohne
/// `eintraege.fluessig`. Beide nachgezogen vom Test-Agenten
/// (`TEST_AENDERN=1`) auf 19, seit dem Zusammenführen am 11.11.2026 auf
/// 24, nicht von Tim gesehen. **Beim Zusammenführen stießen genau diese
/// beiden Stellen aneinander** — richtig ist danach die höhere Zahl, mit
/// allen Stufen im vollständigen Schema. `schema_tabellen.dart` bleibt:
/// Die Stufe legt keine Tabelle an.
///
/// **Alle Zahlen, Namen und Zeitpunkte hier sind erfunden.** Die Zeitpunkte
/// liegen im Jahr 2099.
void main() {
  // --- Altstände, von Hand -----------------------------------------------

  /// Die Tabellen, die diese Stufe nicht anfasst, auf Stand v17 — wörtlich
  /// wie `unberuehrtV16` in `schema_v17_test.dart` (die Stufe 17 hat sie
  /// nicht berührt), dazu `lebensmittel` und `portionen` nach der Stufe 17.
  const unberuehrtV17 = '''
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
  ''';

  /// `eintraege` auf Stand v17 — mit `vorschlag` (Stufe 15) und dem
  /// Portions-Schnappschuss (Stufe 17) —, auf Wunsch schon mit
  /// `fluessig`, wie ein anderer Zweig die Spalte angelegt haben könnte.
  String eintraege({required bool mitFluessig}) =>
      '''
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
      portion_g REAL${mitFluessig ? ',\n      fluessig INTEGER' : ''}
    );
  ''';

  /// Stand v17, wie er auf einem Gerät liegt, das die Stufe 20 noch nicht
  /// kennt.
  final v17Schema = unberuehrtV17 + eintraege(mitFluessig: false);

  /// Stand v17, auf dem ein anderer Zweig `eintraege.fluessig` schon
  /// angelegt hat (#234/#240) — alle bauen unter derselben Bundle-ID.
  final v17Vorweg = unberuehrtV17 + eintraege(mitFluessig: true);

  /// Tims Bestand auf Stand v17: eine feste Vorlage (`fluessig = 0`) und
  /// eine flüssige (`fluessig = 1`), drei Einträge — einer aus der festen,
  /// einer frei mit Vorschlag, einer aus der flüssigen mit Portion. Dazu je
  /// eine Zeile in Portionen, KI und Wasser. Eine Migration, die hier etwas
  /// verlöre, verlöre es endgültig.
  ///
  /// **Eintrag 3 ist der Prüfstein:** Seine Vorlage ist flüssig, und die
  /// Stufe darf das trotzdem **nicht** in den Eintrag schreiben.
  const bestand = '''
    INSERT INTO tages_werte (tag, schritte, ruhepuls_bpm, gelesen_am)
      VALUES ('2099-03-01', 4321, 55, '2099-03-01T08:00:00.000Z');
    INSERT INTO lebensmittel
      (id, name, kcal, eiweiss_g, wasser_ml, extra, fluessig,
       zuletzt_benutzt, barcode, herkunft, portionen_abgefragt_am)
      VALUES (1, 'Prüfknäcke', 377.7, 9.9, NULL, '{}', 0,
              '2099-03-01T07:15:00.000Z', NULL, 'eigen', NULL);
    INSERT INTO lebensmittel
      (id, name, kcal, eiweiss_g, wasser_ml, extra, fluessig,
       zuletzt_benutzt, barcode, herkunft, portionen_abgefragt_am)
      VALUES (2, 'Prüftrunk', 42.4, 3.3, 88.8, '{"jod_ug":1.5}', 1,
              NULL, '0000000000019', 'off', '2099-03-01T10:20:30.000Z');
    INSERT INTO portionen (id, lebensmittel_id, name, menge_g, herkunft)
      VALUES (7, 2, 'Prüfglas', 250.5, 'eigen');
    INSERT INTO eintraege
      (id, tages_schluessel, mahlzeit, zeitpunkt, lebensmittel_id, name,
       menge_g, kcal, eiweiss_g, wasser_ml, extra, health_uuid,
       health_stand, vorschlag, portion_id, portion_name, portion_g)
      VALUES (1, '2099-03-01', 'fruehstueck', '2099-03-01T07:15:00.000Z', 1,
              'Prüfknäcke', 11.8, 44.6, 1.2, NULL, '{}', 'PRUEF-UUID-0001',
              'geschrieben', NULL, NULL, NULL, NULL);
    INSERT INTO eintraege
      (id, tages_schluessel, mahlzeit, zeitpunkt, lebensmittel_id, name,
       menge_g, kcal, extra, health_stand, vorschlag)
      VALUES (2, '2099-03-01', 'abend', '2099-03-01T18:45:00.000Z', NULL,
              'Freier Prüfeintrag', NULL, 512, '{}', 'offen',
              '{"anbieter":"pruef","zweck":"foto"}');
    INSERT INTO eintraege
      (id, tages_schluessel, mahlzeit, zeitpunkt, lebensmittel_id, name,
       menge_g, kcal, eiweiss_g, wasser_ml, extra, health_uuid,
       health_stand, vorschlag, portion_id, portion_name, portion_g)
      VALUES (3, '2099-03-01', 'snack', '2099-03-01T14:20:00.000Z', 2,
              'Prüftrunk', 501.0, 212.4, 16.5, 444.9, '{}', NULL,
              'offen', NULL, 7, 'Prüfglas', 250.5);
    INSERT INTO ki_einstellungen (id, modell, limit_usd, preise)
      VALUES (0, 'pruef-modell-x', 3.5, '{}');
    INSERT INTO wasser_eintraege
      (id, tages_schluessel, zeitpunkt, menge_ml, health_uuid, health_stand)
      VALUES (4, '2099-03-01', '2099-03-01T09:15:00.000Z', 333.5, NULL,
              'offen');
  ''';

  /// Werte in der vorweggenommenen Spalte — alle drei Fälle, und
  /// absichtlich **gegen** die Vorlage: Eintrag 1 (feste Vorlage) steht auf
  /// 1, Eintrag 3 (flüssige Vorlage) auf 0. Bliebe davon etwas nicht
  /// stehen, hätte die Stufe aus der Vorlage nachgeschrieben.
  const vorwegWerte = '''
    UPDATE eintraege SET fluessig = 1 WHERE id = 1;
    UPDATE eintraege SET fluessig = NULL WHERE id = 2;
    UPDATE eintraege SET fluessig = 0 WHERE id = 3;
  ''';

  /// Schema v11 — wörtlich aus `schema_v17_test.dart`: acht Tabellen, noch
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

  /// `eintraege` in der alten Form, wie ein anderer Zweig sie auf einem
  /// v11-Gerät angelegt haben könnte — wörtlich aus `schema_v17_test.dart`.
  const eintraegeVorwegV11 = '''
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

  const v11Bestand = '''
    INSERT INTO tages_werte (tag, schritte, ruhepuls_bpm, gelesen_am)
      VALUES ('2099-03-01', 4242, 99, '2099-03-01T09:00:00.000Z');
    INSERT INTO stammdaten (id, groesse_cm, geburtsjahr, zielgewicht_kg,
                            zieldatum)
      VALUES (0, 211, 1904, 33.3, '2099-12-31');
  ''';

  /// Die Tabellen, deren Zeilen die Stufe nicht anrühren darf — auch
  /// `eintraege`: Die neue Spalte kommt dazu, jede alte bleibt.
  const alle = [
    'tages_werte',
    'lebensmittel',
    'portionen',
    'eintraege',
    'ki_einstellungen',
    'wasser_eintraege',
  ];

  // --- Hilfsmittel, wie in `schema_v17_test.dart` ------------------------

  Database rohdatei(String schema, String inhalt, int version) {
    final roh = sqlite3.openInMemory();
    roh.execute(schema);
    roh.execute(inhalt);
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

  Set<String> rohSpalten(Database roh, String tabelle) => {
    for (final z in roh.select('PRAGMA table_info($tabelle);'))
      z['name'] as String,
  };

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

  /// Die Form der neuen Spalte nach Punkt 2 im Dateikopf.
  Future<void> pruefeForm(AppCache db) async {
    final e = await spalten(db, 'eintraege');
    expect(e.keys, contains('fluessig'));
    expect(e['fluessig']!.typ, 'INTEGER', reason: 'ein Wahrheitswert als 0/1');
    expect(
      e['fluessig']!.nullbar,
      isTrue,
      reason:
          'nullbar: Ein alter Eintrag weiß nicht, ob er in Millilitern '
          'gebucht wurde — NULL ist genau das',
    );
    expect(
      e['fluessig']!.vorgabe,
      isNull,
      reason:
          'kein Vorgabewert: `DEFAULT 0` behauptete für jedes alte Getränk '
          '„in Gramm gebucht", und die Anzeige könnte nicht mehr auf die '
          'Vorlage zurückfallen',
    );

    // Die Portions-Spalten der Stufe 17 stehen weiter da.
    expect(e.keys, containsAll(['portion_id', 'portion_name', 'portion_g']));

    // `lebensmittel.fluessig` bleibt, was es war.
    final l = await spalten(db, 'lebensmittel');
    expect(l['fluessig']!.nullbar, isFalse);

    final indizes = await db
        .customSelect(
          "SELECT name, sql FROM sqlite_master WHERE type = 'index' "
          "AND tbl_name = 'eintraege' AND sql IS NOT NULL;",
        )
        .get();
    for (final i in indizes) {
      expect(
        i.read<String>('sql'),
        isNot(contains('fluessig')),
        reason: 'kein Index — _reconcileSchema kennt keine Indizes',
      );
    }
  }

  // ═════════════════════════════════════════════════════════════════════

  group('Vorbedingungen: die Altstände sind so gebaut, wie sie gemeint '
      'sind', () {
    test('v17 trägt eintraege.fluessig nicht, aber den Portions-'
        'Schnappschuss', () {
      final roh = rohdatei(v17Schema, bestand, 17);
      addTearDown(roh.close);
      expect(rohSpalten(roh, 'eintraege'), isNot(contains('fluessig')));
      expect(
        rohSpalten(roh, 'eintraege'),
        containsAll(['portion_id', 'portion_name', 'portion_g']),
      );
      expect(rohZeilen(roh, 'eintraege'), hasLength(3));
      expect(
        roh
            .select('SELECT fluessig FROM lebensmittel WHERE id = 2;')
            .single['fluessig'],
        1,
        reason: 'die Vorlage von Eintrag 3 ist flüssig',
      );
    });

    test('v17 vorweg trägt die Spalte, mit Werten gegen die Vorlage', () {
      final roh = rohdatei(v17Vorweg, bestand + vorwegWerte, 17);
      addTearDown(roh.close);
      expect(rohSpalten(roh, 'eintraege'), contains('fluessig'));
      expect(
        [
          for (final z in roh.select(
            'SELECT fluessig FROM eintraege ORDER BY id;',
          ))
            z['fluessig'],
        ],
        [1, null, 0],
      );
    });
  });

  group('Schema v20 — frisch angelegt', () {
    test('die Version ist mindestens 20', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      expect(db.schemaVersion, greaterThanOrEqualTo(20));
      expect(await abgelegteVersion(db), db.schemaVersion);
    });

    test('eintraege.fluessig ist da, in der verlangten Form, und keine '
        'Tabelle mehr oder weniger', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      expect(
        await tabellen(db),
        tabellenHeute,
        reason: 'die Stufe legt keine Tabelle an',
      );
      await pruefeForm(db);
    });

    test('drift kennt die Spalte unter dem Namen fluessig', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      expect(db.eintraege.fluessig.name, 'fluessig');
    });
  });

  group('Migration v17 → heute', () {
    test('die Datei steht danach auf der heutigen Version, mit der '
        'verlangten Form', () async {
      final roh = rohdatei(v17Schema, bestand, 17);
      addTearDown(roh.close);
      final db = ueber(roh);
      addTearDown(db.close);

      expect(await abgelegteVersion(db), db.schemaVersion);
      expect(await tabellen(db), tabellenHeute);
      await pruefeForm(db);
    });

    test(
      'additiv: jede Zeile und jeder Wert bleibt, in allen Tabellen',
      () async {
        final roh = rohdatei(v17Schema, bestand, 17);
        addTearDown(roh.close);
        final vorher = {for (final t in alle) t: rohZeilen(roh, t)};

        final db = ueber(roh);
        addTearDown(db.close);

        for (final t in alle) {
          pruefeUnveraendert(vorher[t]!, await zeilen(db, t), t);
        }
      },
    );

    test('alte Einträge tragen NULL — auch der aus der flüssigen Vorlage. '
        'Die Stufe liest nicht aus lebensmittel nach', () async {
      final roh = rohdatei(v17Schema, bestand, 17);
      addTearDown(roh.close);
      final db = ueber(roh);
      addTearDown(db.close);

      final roheZeilen = await zeilen(db, 'eintraege');
      expect(roheZeilen, hasLength(3));
      for (final z in roheZeilen) {
        expect(
          z['fluessig'],
          isNull,
          reason:
              'Eintrag ${z['id']}: Was die Vorlage heute sagt, ist nicht, '
              'was beim Buchen galt — eine Migration erfindet keinen '
              'Schnappschuss',
        );
      }
      final typen = await db
          .customSelect('SELECT typeof(fluessig) AS art FROM eintraege;')
          .get();
      expect(typen.map((z) => z.read<String>('art')).toSet(), {
        'null',
      }, reason: 'wirklich NULL in der Datei, keine 0');

      final getippt = await (db.select(
        db.eintraege,
      )..orderBy([(e) => OrderingTerm.asc(e.id)])).get();
      expect(getippt, hasLength(3));
      for (final z in getippt) {
        expect(z.fluessig, isNull, reason: 'Eintrag ${z.id}');
      }
    });

    test('lebensmittel.fluessig bleibt, wie es war', () async {
      final roh = rohdatei(v17Schema, bestand, 17);
      addTearDown(roh.close);
      final db = ueber(roh);
      addTearDown(db.close);

      final l = await zeilen(db, 'lebensmittel');
      expect(l.map((z) => z['fluessig']).toList(), [0, 1]);
    });

    test(
      'ein zweites Öffnen derselben Datei ändert am Schema nichts mehr',
      () async {
        final roh = rohdatei(v17Schema, bestand, 17);
        addTearDown(roh.close);

        final erstes = ueber(roh);
        await erstes.select(erstes.tagesWerte).get();
        await erstes.close();
        final nachErstem = schemaZaehler(roh);
        final eintraegeNachErstem = rohZeilen(roh, 'eintraege');

        final zweites = ueber(roh);
        addTearDown(zweites.close);
        await zweites.select(zweites.tagesWerte).get();

        expect(
          schemaZaehler(roh),
          nachErstem,
          reason:
              'PRAGMA schema_version steigt bei jedem CREATE, ALTER und DROP. '
              'Steigt er beim zweiten Öffnen, hängt die Stufe oder der '
              'Abgleich die Spalte bei jedem Start erneut an',
        );
        pruefeUnveraendert(
          eintraegeNachErstem,
          await zeilen(zweites, 'eintraege'),
          'eintraege',
        );
      },
    );
  });

  group('Die Stufe ist zweimal ausführbar (#234/#240)', () {
    test('steht die Spalte schon da, öffnet die Datei, und jeder Wert darin '
        'bleibt — auch gegen die Vorlage', () async {
      final roh = rohdatei(v17Vorweg, bestand + vorwegWerte, 17);
      addTearDown(roh.close);
      final vorher = {for (final t in alle) t: rohZeilen(roh, t)};

      final db = ueber(roh);
      addTearDown(db.close);

      expect(await abgelegteVersion(db), db.schemaVersion);
      for (final t in alle) {
        pruefeUnveraendert(vorher[t]!, await zeilen(db, t), t);
      }
      await pruefeForm(db);
    });

    test('und die Werte kommen über drift als true, null, false '
        'heraus', () async {
      final roh = rohdatei(v17Vorweg, bestand + vorwegWerte, 17);
      addTearDown(roh.close);
      final db = ueber(roh);
      addTearDown(db.close);

      final getippt = await (db.select(
        db.eintraege,
      )..orderBy([(e) => OrderingTerm.asc(e.id)])).get();
      expect(getippt.map((e) => e.fluessig).toList(), [true, null, false]);
    });
  });

  group('Abgleich beim Öffnen (#233)', () {
    test('eine Datei auf 20, der eintraege.fluessig fehlt, bekommt die '
        'Spalte — leer, und verliert nichts', () async {
      final roh = rohdatei(v17Schema, bestand, 20);
      addTearDown(roh.close);
      final vorher = {for (final t in alle) t: rohZeilen(roh, t)};

      final db = ueber(roh);
      addTearDown(db.close);
      // Der erste Zugriff: Das Öffnen selbst ist bei drift lazy.
      await db.select(db.tagesWerte).get();

      expect(
        (await spalten(db, 'eintraege')).keys,
        contains('fluessig'),
        reason:
            'onUpgrade läuft bei from == 20 nicht in die Stufe 20 — die '
            'Spalte kommt nur über den Abgleich',
      );
      await pruefeForm(db);
      for (final t in alle) {
        pruefeUnveraendert(vorher[t]!, await zeilen(db, t), t);
      }
      for (final z in await zeilen(db, 'eintraege')) {
        expect(
          z['fluessig'],
          isNull,
          reason: 'der Abgleich erfindet keinen Wert, er hängt nur an',
        );
      }
    });
  });

  group('Von weit unten: v11 → heute', () {
    test('ein v11-Stand öffnet ohne `duplicate column name` und hat danach '
        'eintraege.fluessig', () async {
      final roh = rohdatei(v11Schema, v11Bestand, 11);
      addTearDown(roh.close);
      final vorher = rohZeilen(roh, 'tages_werte');

      final db = ueber(roh);
      addTearDown(db.close);

      // Scheiterte eine Stufe an einer doppelten Spalte, würfe schon dieser
      // erste Zugriff.
      expect(await abgelegteVersion(db), db.schemaVersion);
      expect(await tabellen(db), tabellenHeute);
      await pruefeForm(db);
      pruefeUnveraendert(
        vorher,
        await zeilen(db, 'tages_werte'),
        'tages_werte',
      );
    });

    test('auch wenn ein anderer Zweig eintraege schon in alter Form angelegt '
        'hat: die Spalte kommt dazu, die Zeile bleibt', () async {
      final roh = rohdatei(v11Schema + eintraegeVorwegV11, v11Bestand, 11);
      addTearDown(roh.close);
      final vorher = rohZeilen(roh, 'eintraege');

      final db = ueber(roh);
      addTearDown(db.close);

      expect(await abgelegteVersion(db), db.schemaVersion);
      await pruefeForm(db);
      pruefeUnveraendert(vorher, await zeilen(db, 'eintraege'), 'eintraege');
      expect((await zeilen(db, 'eintraege')).single['fluessig'], isNull);
    });
  });
}
