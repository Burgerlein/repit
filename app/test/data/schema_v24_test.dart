import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show Database, sqlite3;

import 'package:repit/data/cache.dart';

import 'schema_tabellen.dart';

/// Tests für **Schema v24**: die Tabelle `umfaenge`, in der Tims
/// Maßband-Messungen liegen — eine Zeile je Tag **und Maß**, nicht ein
/// Textklumpen je Tag (#476, unter #88).
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden. Jede Migration
/// bekommt einen Test, dies ist der für die Stufe 23.
///
/// ## Woher die Anforderung kommt
///
/// Plan `docs/superpowers/plans/2026-11-11-umfaenge.md`, **Task 1.6 —
/// Tabelle und Migration auf Stufe 24**. Dort stehen die Spalten, der
/// Schlüssel und die Begründungen:
///
/// - **„Eine Zeile je Tag und Maß, kein Textklumpen."** Ein Klumpen
///   bräuchte einen eigenen Codec mit eigenen Tests, wäre mit keiner
///   Abfrage erreichbar und bei der nächsten Schemaänderung nur zu
///   verwerfen — dieselbe Begründung wie bei `naechte` und
///   `schlaf_abschnitte`.
/// - **„`quelle` gehört in den Schlüssel."** Sonst überschriebe der Import
///   beim nächsten Lauf den getippten Wert, und `UmfangsMerge` hätte nichts
///   mehr zu entscheiden — die Zusammenführung passiert beim **Lesen**,
///   nicht beim Schreiben.
/// - **Global Constraints des Plans:** Der Datumsschlüssel ist der
///   ISO-Tagesstring (`BerlinCalendar.dayKey`), gefiltert wird in SQL.
/// - **`CLAUDE.md`, Tests:** „Eine Migration füllt alte Zeilen nicht mit
///   erfundenen Zeitstempeln — das behauptete, sie seien frisch."
///
/// Der Code der Stufe existierte beim Schreiben dieser Datei nicht.
/// Gelesen wurden Plan und bestehende Migrationstests, nicht die spätere
/// Implementierung.
///
/// ## Warum die 24 (ursprünglich die 23)
///
/// Am 11.11.2026 in `umfaenge-88` nachgesehen: `AppCache.schemaVersion
/// => 22` (#451, `wach_belege`). Die nächste freie Nummer war also die
/// 23, und der Plan nennt sie: „Tabelle und Migration auf Stufe 23".
///
/// **Seit dem 11.11.2026 ist es die 24** (#485): In `main` lag eine
/// unabhängig vergebene Stufe 18 — die drei Gym-Tabellen (#78) —, die auf
/// Tims iPhone schon gelaufen und dort in der Datei vermerkt ist.
/// Verschöbe man sie, liefe sie dort nie wieder. Beim Zusammenführen von
/// `umfaenge-88` und `main` behält sie deshalb die 18, und jede Stufe
/// dieses Zweigs ab 18 ist um eins nach oben gerückt; die Datei hieß bis
/// dahin `schema_v23_test.dart`, und der Altstand unten trägt
/// seitdem auch die drei Gym-Tabellen. Nachgezogen beim Zusammenführen,
/// **Tim hat die Änderung nicht gesehen**.
///
/// Nachbar von `schema_v23_test.dart` und `schema_v22_test.dart` (auch
/// dort legt eine Stufe eine Tabelle an): derselbe Aufbau, von Hand
/// gebaute Altstände, **nicht** aus dem heutigen Code erzeugt
/// (`migration_test.dart`, Dateikopf). Der Stand v23 unten ist `v22Schema`
/// aus `schema_v23_test.dart` mit `wach_belege` so, wie
/// `schema_v23_test.dart` sie festlegt.
///
/// **Diese Datei spricht die Tabelle nur über SQL an**, nicht über die
/// drift-Klassen. Sie übersetzt also auch dann, wenn es die Tabelle im
/// Code noch nicht gibt, und meldet dann, *was* fehlt, statt nur, dass sie
/// nicht baut.
///
/// ## Was diese Datei verbindlich vorgibt
///
/// **1. `AppCache.schemaVersion >= 24`** und eine **eigene Stufe**
/// `if (from < 24) { … }`. Geprüft mit `>=`, damit diese Datei bei der
/// nächsten Stufe nicht mitfällt (#208). Nach dem Öffnen eines Altstands
/// steht `user_version` auf `schemaVersion`.
///
/// **2. Eine neue Tabelle `umfaenge`**, genau diese fünf Spalten (Plan,
/// Task 1.6):
///
/// | Spalte | Typ | NULL | Vorgabe | Drift-Name |
/// |---|---|---|---|---|
/// | `tag` | TEXT, Teil des Schlüssels | nein | — | `tag` |
/// | `mass` | TEXT, Teil des Schlüssels | nein | — | `mass` |
/// | `zentimeter` | REAL | nein | — | `zentimeter` |
/// | `eingetragen_am` | TEXT (DateTime, UTC) | nein | — | `eingetragenAm` |
/// | `quelle` | TEXT, Teil des Schlüssels | nein | — | `quelle` |
///
/// Kein Vorgabewert an keiner Spalte, **kein Index**
/// (`_reconcileSchema` kennt keine).
///
/// **3. Der Primärschlüssel ist `(tag, mass, quelle)`** — alle drei, und
/// `tag` zuerst.
///
/// **4. Additiv, ohne Zeile.** Die Stufe legt **keine** Zeile an. Alle
/// übrigen Tabellen behalten jede Zeile und jeden Wert.
///
/// **5. Zweimal ausführbar** (#234/#240). Steht `umfaenge` schon in einer
/// Datei mit `user_version = 23`, öffnet sie trotzdem, und die Zeilen
/// darin bleiben.
///
/// **6. Abgleich** (#233). Eine Datei auf 24, der die Tabelle fehlt,
/// bekommt sie beim Öffnen, leer.
///
/// **7. Von weit unten:** Ein v11-Stand läuft durch alle Stufen.
///
/// **8. `eingetragen_am` kommt als UTC zurück und ist gleich sich selbst**
/// (`CLAUDE.md`, „Zeitstempel liegen in der Datenbank als Text").
///
/// **9. `tag` ist ein ISO-Tagesstring und wird in SQL verglichen** —
/// `WHERE tag >= ? AND tag <= ?` liefert lexikografisch das richtige
/// Fenster.
///
/// ## Festlegungen des Test-Agenten, nicht von Tim freigegeben
///
/// Was folgt, steht so weder im Plan noch in der Spec. Es hat der
/// Test-Agent beim Schreiben dieser Datei festgelegt; Tim hat es nicht
/// gesehen.
///
/// - **Der Dateiname.** Der Plan schreibt die Migration
///   `test/data/migration_test.dart` zu; die bestehende Datei dort handelt
///   aber von den Stufen bis 2 und darf nach der Rollentrennung ohnehin
///   nicht umgebaut werden. Diese Datei folgt stattdessen der Reihe
///   `schema_v10_test.dart` … `schema_v23_test.dart`, in der jede Stufe
///   ihre eigene Datei hat.
/// - **`tag` steht im Schlüssel vorn.** Die drei Spalten sind eine Menge,
///   der Plan schreibt `{tag, mass, quelle}`; SQLite macht daraus eine
///   Reihenfolge, und die ist nicht beliebig: Der Schlüsselindex trägt eine
///   Bereichsabfrage über `tag` nur, wenn `tag` die erste Spalte ist.
///   Gefiltert wird nach Zeitraum, nie nach Maß allein.
/// - **Keine `CHECK`-Bedingung auf `quelle` und keine auf `mass`.** Eine
///   dritte Quelle (etwa ein künftiger Import aus einer anderen App) und
///   ein sechzehntes Maß müssen sich eintragen lassen, ohne die Tabelle neu
///   zu bauen. Was die App als Quelle kennt, entscheidet das Lesen.
/// - **Kein `DEFAULT` auf `eingetragen_am`.** Ein `CURRENT_TIMESTAMP`
///   erfände einen Zeitpunkt für eine Messung, die niemand eingetragen hat
///   — derselbe Fehler wie eine Migration, die alte Zeilen frisch
///   aussehen lässt.
/// - **`zentimeter` ist Pflicht und REAL.** Ein fehlendes Maß ist keine
///   Zeile; es wird nicht als `NULL`-Zeile abgelegt und schon gar nicht
///   als `0` (`CLAUDE.md`, „`0` ist keine Antwort auf ‚kein Wert'").
/// - **Ein zweites Öffnen ändert am Schema nichts mehr** (gemessen am
///   SQLite-Schema-Zähler, wie in `schema_v23_test.dart`).
/// - **Die Wachbelege der Stufe 23 gehören zum Bestand**, den die Stufe 24
///   nicht anrühren darf.
///
/// ## Bestehende Tests, die mit dieser Stufe mitgehen
///
/// Nachgezogen vom Test-Agenten (`TEST_AENDERN=1`), **Tim hat die
/// Änderungen nicht gesehen**: `schema_tabellen.dart` bekommt
/// `tabellenAusStufe24` und die Tabelle in [tabellenHeute];
/// `migration_test.dart` nennt als einzige Stelle die absolute Zahl und
/// steht jetzt auf 24; `schema_abgleich_test.dart` führt `heutigeNummer`
/// 24; `schema_v19_test.dart`, `schema_v21_test.dart`,
/// `schema_v22_test.dart` und `schema_v23_test.dart` nehmen in ihren
/// Vorbedingungen die Tabelle der Stufe 24 aus dem Vergleich — die kann
/// ein Altstand nicht haben. Nur das Nachziehen, keine inhaltlich
/// verschobene Erwartung.
///
/// **Diese Datei selbst käme auch ohne das Nachziehen aus:** Sie drückt
/// den Altstand
/// als `tabellenHeute.difference({'umfaenge'})` und den Endstand als
/// `tabellenHeute.union({'umfaenge'})` aus — beides stimmt, gleich ob
/// `schema_tabellen.dart` die Tabelle schon führt oder noch nicht.
///
/// **Alle Zahlen, Namen, Maße und Zeitpunkte hier sind erfunden.** Die
/// Zeitpunkte liegen im Jahr 2099; Tims echte Messungen stehen nirgends im
/// Quelltext.
void main() {
  /// Die neue Tabelle und ihre Spalten — an einer Stelle, damit der
  /// Altstand und der Endstand sich darauf beziehen können.
  const neueTabelle = 'umfaenge';
  const spaltenUmfaenge = {
    'tag',
    'mass',
    'zentimeter',
    'eingetragen_am',
    'quelle',
  };

  // Seit dem 24.11.2026 fallen auch die Tabellen der Stufen 26 (#592,
  // Zykluskalender) und 27 (#532, eigene Trainings) aus dem Altstand
  // heraus — die kann ein v23-Stand nicht haben. Nachgezogen vom
  // Test-Agenten mit `TEST_AENDERN=1`, Tim hat die Änderung nicht
  // gesehen.
  final tabellenVorStufe24 = tabellenHeute.difference({
    neueTabelle,
    ...tabellenAusStufe26,
    ...tabellenAusStufe27,
  });
  final tabellenNachStufe24 = tabellenHeute.union({neueTabelle});

  // --- Altstände, von Hand -----------------------------------------------

  /// Stand v23: `v22Schema` aus `schema_v23_test.dart`, dazu `wach_belege`
  /// (Stufe 23) wie dort festgelegt. Die drei Gym-Tabellen der Stufe 18
  /// (#78) stehen seit dem Zusammenführen mit `main` mit darin (#485).
  const v23Schema = '''
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
    CREATE TABLE wach_belege (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      zeitpunkt TEXT NOT NULL,
      art TEXT NOT NULL
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

  /// `umfaenge`, wie ein anderer Zweig sie schon angelegt haben könnte,
  /// von Hand nach der Tabelle im Dateikopf.
  const umfaengeVorweg = '''
    CREATE TABLE umfaenge (
      tag TEXT NOT NULL,
      mass TEXT NOT NULL,
      zentimeter REAL NOT NULL,
      eingetragen_am TEXT NOT NULL,
      quelle TEXT NOT NULL,
      PRIMARY KEY (tag, mass, quelle)
    );
  ''';

  /// Drei Zeilen darin: dasselbe Maß desselben Tages aus beiden Quellen
  /// und ein zweites Maß. Alle drei muss die Stufe stehen lassen.
  const umfaengeZeilenVorweg = '''
    INSERT INTO umfaenge (tag, mass, zentimeter, eingetragen_am, quelle)
      VALUES ('2099-04-12', 'pruefmassA', 41.4, '2099-04-12T07:05:00.000Z',
              'getippt');
    INSERT INTO umfaenge (tag, mass, zentimeter, eingetragen_am, quelle)
      VALUES ('2099-04-12', 'pruefmassA', 40.9, '2099-04-12T07:06:00.000Z',
              'import');
    INSERT INTO umfaenge (tag, mass, zentimeter, eingetragen_am, quelle)
      VALUES ('2099-04-12', 'pruefmassB', 99.9, '2099-04-12T07:07:00.000Z',
              'getippt');
  ''';

  /// Tims Bestand auf Stand v23, wörtlich der aus `schema_v23_test.dart`,
  /// dazu die beiden Wachbelege der Stufe 22. Eine Migration, die hier
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
    INSERT INTO portionen (id, lebensmittel_id, name, menge_g, herkunft)
      VALUES (5, 1, 'Prüfbon', 5.9, 'eigen');
    INSERT INTO eintraege
      (id, tages_schluessel, mahlzeit, zeitpunkt, lebensmittel_id, name,
       menge_g, kcal, extra, health_uuid, health_stand, portion_id,
       portion_name, portion_g, fluessig)
      VALUES (1, '2099-03-01', 'fruehstueck', '2099-03-01T07:15:00.000Z', 1,
              'Prüfknäcke', 11.8, 44.6, '{}', 'PRUEF-UUID-0023',
              'geschrieben', 5, 'Prüfbon', 5.9, 0);
    INSERT INTO kalorienziele
      (ab_tag, kcal, herkunft, grundumsatz_kcal, aktiv_kcal,
       koerperziel_kcal)
      VALUES ('2099-02-20', 2617.25, 'berechnet', 1750.5, 700.2, 166.55);
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
    INSERT INTO wach_belege (id, zeitpunkt, art)
      VALUES (1, '2099-03-01T23:40:00.000Z', 'oeffnen');
    INSERT INTO wach_belege (id, zeitpunkt, art)
      VALUES (2, '2099-03-02T00:15:30.000Z', 'buchung');
  ''';

  /// Schema v11, wörtlich aus `schema_v23_test.dart`: acht Tabellen, noch
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
    'wach_belege',
  ];

  /// Die Pflichttexte und warum sie Text sind.
  const pflichtTexte = {
    'tag':
        'der ISO-Tagesstring aus BerlinCalendar.dayKey (2099-04-12), nicht '
        'Epoch: Ein Tag ist eine Kalenderangabe, kein Zeitpunkt, und '
        'WHERE tag >= ? vergleicht lexikografisch richtig',
    'mass': 'der stabile Schlüssel des Maßes (Umfang.schluessel)',
    'eingetragen_am':
        'DateTime als Text (storeDateTimeAsText), nicht als Unix-Sekunden '
        '— sonst käme der Zeitpunkt als Ortszeit zurück und wäre ungleich '
        'sich selbst',
    'quelle': 'getippt oder import — und Teil des Schlüssels',
  };

  // --- Hilfsmittel, wie in `schema_v23_test.dart` ------------------------

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
    Map<String, ({String typ, bool nullbar, int schluesselNr, String? vorgabe})>
  >
  spalten(AppCache db, String tabelle) async {
    final zeilen = await db.customSelect('PRAGMA table_info($tabelle);').get();
    return {
      for (final z in zeilen)
        z.read<String>('name'): (
          typ: z.read<String>('type').toUpperCase(),
          nullbar: z.read<int>('notnull') == 0,
          schluesselNr: z.read<int>('pk'),
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

  /// Die Form von `umfaenge` nach der Tabelle im Dateikopf.
  Future<void> pruefeForm(AppCache db) async {
    final s = await spalten(db, neueTabelle);
    expect(
      s.keys.toSet(),
      spaltenUmfaenge,
      reason:
          'genau die fünf Spalten aus Task 1.6. Eine Zeile je Tag und Maß — '
          'kein Textklumpen je Tag, der einen eigenen Codec bräuchte und '
          'mit keiner Abfrage erreichbar wäre',
    );

    expect(
      s['zentimeter']!.typ,
      'REAL',
      reason:
          'ein Umfang ist eine Kommazahl: 41,4 cm sind nicht 41 cm. Ein '
          'INTEGER verlöre den halben Zentimeter, um den es beim Messen '
          'geht',
    );
    expect(
      s['zentimeter']!.nullbar,
      isFalse,
      reason:
          'ein fehlendes Maß ist keine Zeile. Es wird weder als NULL-Zeile '
          'noch als 0 abgelegt — 0 behauptete einen gemessenen Umfang von '
          'null Zentimetern',
    );

    for (final MapEntry(key: p, value: warum) in pflichtTexte.entries) {
      expect(s[p]!.typ, 'TEXT', reason: '$p: $warum');
      expect(s[p]!.nullbar, isFalse, reason: '$p ist Pflicht: $warum');
    }

    final schluessel =
        (s.entries.where((e) => e.value.schluesselNr > 0).toList()..sort(
              (a, b) => a.value.schluesselNr.compareTo(b.value.schluesselNr),
            ))
            .map((e) => e.key)
            .toList();
    expect(
      schluessel,
      ['tag', 'mass', 'quelle'],
      reason:
          'der Primärschlüssel ist (tag, mass, quelle). Ohne quelle '
          'überschriebe der Import beim nächsten Lauf den getippten Wert, '
          'und UmfangsMerge hätte nichts mehr zu entscheiden — die '
          'Zusammenführung passiert beim Lesen, nicht beim Schreiben. Und '
          'tag steht vorn, weil nach Zeitraum gefiltert wird und der '
          'Schlüsselindex eine Bereichsabfrage nur über seine erste Spalte '
          'trägt',
    );

    for (final MapEntry(:key, :value) in s.entries) {
      expect(
        value.vorgabe,
        isNull,
        reason:
            '$key: kein Vorgabewert. Eine Vorgabe an eingetragen_am (etwa '
            'CURRENT_TIMESTAMP) erfände den Zeitpunkt einer Messung, eine '
            'an zentimeter einen Umfang, und eine an quelle eine Herkunft, '
            'die niemand gemeldet hat',
      );
    }

    final sql =
        (await db
                .customSelect(
                  "SELECT sql FROM sqlite_master WHERE type = 'table' "
                  "AND name = '$neueTabelle';",
                )
                .getSingle())
            .read<String>('sql');
    expect(
      sql.toUpperCase(),
      isNot(contains('CHECK')),
      reason:
          'keine CHECK-Bedingung. Eine dritte Quelle und ein sechzehntes '
          'Maß müssen sich eintragen lassen, ohne die Tabelle neu zu bauen; '
          'was die App kennt, entscheidet das Lesen',
    );

    final indizes = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index' "
          "AND tbl_name = '$neueTabelle' AND sql IS NOT NULL;",
        )
        .get();
    expect(
      indizes,
      isEmpty,
      reason:
          'kein eigener Index — _reconcileSchema kennt keine. Der '
          'automatische Index hinter dem Primärschlüssel (sql IS NULL) '
          'zählt nicht',
    );
  }

  // ═════════════════════════════════════════════════════════════════════

  group('Vorbedingungen: die Altstände sind so gebaut, wie sie gemeint '
      'sind', () {
    test('v23 hat alle heutigen Tabellen außer der neuen', () {
      final roh = rohdatei(v23Schema, bestand, 23);
      addTearDown(roh.close);
      final namen = rohTabellen(roh);
      expect(namen, isNot(contains(neueTabelle)));
      expect(
        namen,
        tabellenVorStufe24,
        reason: 'v23 hat alle heutigen Tabellen außer der der Stufe 24',
      );
      expect(rohZeilen(roh, 'eintraege'), hasLength(1));
      expect(rohZeilen(roh, 'ereignisse'), hasLength(1));
      expect(rohZeilen(roh, 'wach_belege'), hasLength(2));
    });

    test('v23 vorweg trägt die Tabelle schon, mit drei Zeilen', () {
      final roh = rohdatei(
        v23Schema + umfaengeVorweg,
        bestand + umfaengeZeilenVorweg,
        23,
      );
      addTearDown(roh.close);
      expect(rohZeilen(roh, neueTabelle), hasLength(3));
    });
  });

  group('Schema v24 (#476) — frisch angelegt', () {
    test('die Version ist mindestens 24 und steht so in der Datei', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      expect(db.schemaVersion, greaterThanOrEqualTo(24));
      expect(await abgelegteVersion(db), db.schemaVersion);
    });

    test('ein frischer Cache hat die Tabelle, in der verlangten Form, und '
        'sie ist leer', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      expect(await tabellen(db), tabellenNachStufe24);
      expect(await tabellen(db), contains(neueTabelle));
      await pruefeForm(db);
      expect(
        await zeilen(db, neueTabelle),
        isEmpty,
        reason:
            'das Anlegen des Caches ist keine Messung. Eine Beispielmessung '
            'im Schema wäre ein hartcodiertes Ereignis (Plan, Global '
            'Constraints)',
      );
    });
  });

  group('Migration v23 → heute', () {
    test('legt die Tabelle an, mit der verlangten Form, und die Datei steht '
        'danach auf der heutigen Version', () async {
      final roh = rohdatei(v23Schema, bestand, 23);
      addTearDown(roh.close);
      final db = ueber(roh);
      addTearDown(db.close);

      expect(await abgelegteVersion(db), db.schemaVersion);
      expect(
        await abgelegteVersion(db),
        greaterThanOrEqualTo(24),
        reason: 'die Stufe 24 ist über diesen Bestand gelaufen',
      );
      expect(await tabellen(db), tabellenNachStufe24);
      await pruefeForm(db);
    });

    test('füllt nichts — die Tabelle ist leer, und keine Zeile trägt einen '
        'erfundenen Zeitstempel', () async {
      final roh = rohdatei(v23Schema, bestand, 23);
      addTearDown(roh.close);
      final db = ueber(roh);
      addTearDown(db.close);

      expect(
        await zeilen(db, neueTabelle),
        isEmpty,
        reason:
            'eine Migration füllt alte Zeilen nicht mit erfundenen '
            'Zeitstempeln — das behauptete, sie seien frisch (CLAUDE.md). '
            'Es gibt nichts umzuschreiben: Vor dieser Stufe lagen Tims '
            'Umfänge nicht in dieser Datenbank. Die erste Zeile schreibt '
            'der Eintragen-Schirm oder die Übernahme, nicht das Schema',
      );
    });

    test(
      'additiv: jede Zeile und jeder Wert bleibt, in allen Tabellen',
      () async {
        final roh = rohdatei(v23Schema, bestand, 23);
        addTearDown(roh.close);
        final vorher = {for (final t in alle) t: rohZeilen(roh, t)};

        final db = ueber(roh);
        addTearDown(db.close);

        expect(
          await abgelegteVersion(db),
          greaterThanOrEqualTo(24),
          reason: 'die Stufe 24 ist über diesen Bestand gelaufen',
        );
        for (final t in alle) {
          pruefeUnveraendert(vorher[t]!, await zeilen(db, t), t);
        }
      },
    );

    test('ein zweites Öffnen derselben Datei ändert am Schema nichts mehr, '
        'und eine inzwischen eingetragene Messung bleibt', () async {
      final roh = rohdatei(v23Schema, bestand, 23);
      addTearDown(roh.close);

      final erstes = ueber(roh);
      await erstes.customStatement(
        'INSERT INTO umfaenge (tag, mass, zentimeter, eingetragen_am, '
        "quelle) VALUES ('2099-04-12', 'pruefmassA', 41.4, "
        "'2099-04-12T07:05:00.000Z', 'getippt');",
      );
      await erstes.close();
      final nachErstem = schemaZaehler(roh);
      final zeilenNachErstem = rohZeilen(roh, neueTabelle);

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
      expect(
        zeilenNachErstem,
        hasLength(1),
        reason: 'Vorbedingung: die Messung ist eingetragen',
      );
      pruefeUnveraendert(
        zeilenNachErstem,
        await zeilen(zweites, neueTabelle),
        neueTabelle,
      );
    });
  });

  group('Die Stufe ist zweimal ausführbar (#234/#240)', () {
    test('steht die Tabelle schon da, öffnet die Datei, und jede Messung '
        'darin bleibt', () async {
      final roh = rohdatei(
        v23Schema + umfaengeVorweg,
        bestand + umfaengeZeilenVorweg,
        23,
      );
      addTearDown(roh.close);
      final vorher = {
        for (final t in [...alle, neueTabelle]) t: rohZeilen(roh, t),
      };

      final db = ueber(roh);
      addTearDown(db.close);

      expect(await abgelegteVersion(db), db.schemaVersion);
      expect(
        await abgelegteVersion(db),
        greaterThanOrEqualTo(24),
        reason:
            'die Stufe 24 lief über eine Datei, die ihre Tabelle schon trug, '
            'und scheiterte nicht an „table already exists". Alle Zweige '
            'bauen unter derselben Bundle-ID und benutzen dieselbe Datei',
      );
      for (final MapEntry(key: t, value: z) in vorher.entries) {
        pruefeUnveraendert(z, await zeilen(db, t), t);
      }
      await pruefeForm(db);
      expect(
        await zeilen(db, neueTabelle),
        hasLength(3),
        reason:
            'kein DROP TABLE IF EXISTS vor dem CREATE. Eine Stufe, die nie '
            'scheitert und dabei Tims Messungen löscht, ist die schlechtere '
            'Stufe',
      );
    });
  });

  group('Abgleich beim Öffnen (#233)', () {
    test('eine Datei auf 24, der die Tabelle fehlt, bekommt sie — leer, und '
        'verliert nichts', () async {
      // Ein Zweig hat die Nummer hochgezogen, bevor seine Stufe fertig
      // war: `if (from < 24)` läuft dann nie.
      final roh = rohdatei(v23Schema, bestand, 24);
      addTearDown(roh.close);
      final vorher = {for (final t in alle) t: rohZeilen(roh, t)};

      final db = ueber(roh);
      addTearDown(db.close);
      // Der erste Zugriff: Das Öffnen selbst ist bei drift lazy.
      await db.customSelect('SELECT 1;').get();

      expect(
        await tabellen(db),
        contains(neueTabelle),
        reason:
            'onUpgrade läuft bei from == 24 nicht in die Stufe 24 — die '
            'Tabelle kommt nur über den Abgleich',
      );
      expect(await tabellen(db), tabellenNachStufe24);
      await pruefeForm(db);
      expect(await zeilen(db, neueTabelle), isEmpty);
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
      expect(await tabellen(db), tabellenNachStufe24);
      await pruefeForm(db);
      expect(await zeilen(db, neueTabelle), isEmpty);
      for (final MapEntry(key: t, value: z) in vorher.entries) {
        pruefeUnveraendert(z, await zeilen(db, t), t);
      }
    });
  });

  group('Der Schlüssel trägt die Quelle', () {
    test('derselbe Tag und dasselbe Maß liegen aus beiden Quellen '
        'nebeneinander', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      await db.customStatement(
        'INSERT INTO umfaenge (tag, mass, zentimeter, eingetragen_am, '
        "quelle) VALUES ('2099-04-12', 'pruefmassA', 41.4, "
        "'2099-04-12T07:05:00.000Z', 'getippt');",
      );
      await db.customStatement(
        'INSERT INTO umfaenge (tag, mass, zentimeter, eingetragen_am, '
        "quelle) VALUES ('2099-04-12', 'pruefmassA', 40.9, "
        "'2099-04-12T09:30:00.000Z', 'import');",
      );

      final beide = await db
          .customSelect(
            "SELECT quelle, zentimeter FROM umfaenge WHERE tag = '2099-04-12' "
            "AND mass = 'pruefmassA' ORDER BY quelle;",
          )
          .get();
      expect(
        beide.map((z) => z.read<String>('quelle')).toList(),
        ['getippt', 'import'],
        reason:
            'quelle gehört in den Schlüssel: Sonst überschriebe der Import '
            'beim nächsten Lauf den getippten Wert. Die Zusammenführung '
            'passiert beim Lesen (UmfangsMerge), nicht beim Schreiben — '
            'und dafür müssen beide Zeilen dasein',
      );
      expect(beide.map((z) => z.read<double>('zentimeter')).toList(), [
        41.4,
        40.9,
      ]);
    });

    test('derselbe Tag, dasselbe Maß und dieselbe Quelle zweimal ist ein '
        'Verstoß gegen den Schlüssel', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      const einfuegen =
          'INSERT INTO umfaenge (tag, mass, zentimeter, eingetragen_am, '
          "quelle) VALUES ('2099-04-12', 'pruefmassA', 41.4, "
          "'2099-04-12T07:05:00.000Z', 'getippt');";
      await db.customStatement(einfuegen);

      await expectLater(
        db.customStatement(einfuegen),
        throwsA(anything),
        reason:
            'je Tag, Maß und Quelle gibt es genau einen Wert. Ein zweites '
            'Eintragen desselben Maßes am selben Tag ist eine Korrektur und '
            'ersetzt den Wert (INSERT OR REPLACE), es legt keine zweite '
            'Zeile an',
      );
      expect(await zeilen(db, neueTabelle), hasLength(1));
    });

    test('dasselbe Maß an verschiedenen Tagen und verschiedene Maße am '
        'selben Tag liegen nebeneinander', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      await db.customStatement('''
        INSERT INTO umfaenge (tag, mass, zentimeter, eingetragen_am, quelle)
          VALUES ('2099-04-12', 'pruefmassA', 41.4,
                  '2099-04-12T07:05:00.000Z', 'getippt');
      ''');
      await db.customStatement('''
        INSERT INTO umfaenge (tag, mass, zentimeter, eingetragen_am, quelle)
          VALUES ('2099-04-26', 'pruefmassA', 41.9,
                  '2099-04-26T07:05:00.000Z', 'getippt');
      ''');
      await db.customStatement('''
        INSERT INTO umfaenge (tag, mass, zentimeter, eingetragen_am, quelle)
          VALUES ('2099-04-12', 'pruefmassB', 99.9,
                  '2099-04-12T07:06:00.000Z', 'getippt');
      ''');

      expect(
        await zeilen(db, neueTabelle),
        hasLength(3),
        reason:
            'eine Zeile je Tag und Maß. Ein abends nachgetragenes Einzelmaß '
            'darf den Rest des Tages nicht löschen',
      );
    });

    test('mass und quelle nehmen Werte an, die es heute nicht gibt', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      await db.customStatement('''
        INSERT INTO umfaenge (tag, mass, zentimeter, eingetragen_am, quelle)
          VALUES ('2099-04-12', 'pruefmassSechzehn', 12.3,
                  '2099-04-12T07:05:00.000Z', 'pruefquelle');
      ''');

      final zeile = (await zeilen(db, neueTabelle)).single;
      expect(zeile['mass'], 'pruefmassSechzehn');
      expect(
        zeile['quelle'],
        'pruefquelle',
        reason:
            'keine CHECK-Bedingung: Käme ein sechzehntes Maß oder eine '
            'dritte Quelle dazu, müsste die Tabelle sonst neu gebaut '
            'werden. Was die App kennt, entscheidet das Lesen',
      );
    });
  });

  group('Die Zeilen', () {
    test('eingetragen_am kommt als UTC zurück und ist gleich sich selbst; '
        'abgelegt ist er als Text', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);
      // 00:30:15,250 UTC in der Nacht der Zeitumstellung im Oktober — in
      // Berlin 02:30:15 Sommerzeit, die erste der beiden 02:30.
      final eingetragenAm = DateTime.utc(2099, 10, 25, 0, 30, 15, 250);

      await db.customInsert(
        'INSERT INTO umfaenge (tag, mass, zentimeter, eingetragen_am, '
        'quelle) VALUES (?, ?, ?, ?, ?);',
        variables: [
          Variable<String>('2099-10-25'),
          Variable<String>('pruefmassA'),
          Variable<double>(41.4),
          Variable<DateTime>(eingetragenAm),
          Variable<String>('getippt'),
        ],
      );

      final zeile = await db
          .customSelect(
            'SELECT eingetragen_am, typeof(eingetragen_am) AS art_zeit, '
            'typeof(tag) AS art_tag, typeof(zentimeter) AS art_cm '
            'FROM umfaenge;',
          )
          .getSingle();

      expect(
        zeile.read<String>('art_zeit'),
        'text',
        reason:
            'Zeitstempel liegen als Text in der Datenbank; drifts Standard '
            '(Unix-Sekunden) gäbe sie als lokale Zeit zurück',
      );
      expect(zeile.read<String>('art_tag'), 'text');
      expect(zeile.read<String>('art_cm'), 'real');

      final gelesen = zeile.read<DateTime>('eingetragen_am');
      expect(gelesen.isUtc, isTrue, reason: 'als UTC abgelegt, als UTC zurück');
      expect(
        gelesen,
        eingetragenAm,
        reason:
            'Dart vergleicht DateTime samt isUtc — ein als UTC '
            'gespeicherter Wert, der als Ortszeit herauskäme, wäre ungleich '
            'sich selbst. Genau daran scheiterte schon einmal ein '
            'Rundwegtest',
      );
    });

    test('zentimeter kommt mit seinen Nachkommastellen zurück', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      await db.customInsert(
        'INSERT INTO umfaenge (tag, mass, zentimeter, eingetragen_am, '
        'quelle) VALUES (?, ?, ?, ?, ?);',
        variables: [
          Variable<String>('2099-04-12'),
          Variable<String>('pruefmassA'),
          Variable<double>(33.6),
          Variable<DateTime>(DateTime.utc(2099, 4, 12, 7, 5)),
          Variable<String>('getippt'),
        ],
      );

      final gelesen =
          (await db
                  .customSelect('SELECT zentimeter FROM umfaenge;')
                  .getSingle())
              .read<double>('zentimeter');
      expect(
        gelesen,
        33.6,
        reason:
            'der halbe Zentimeter ist das, worum es beim Messen geht. Die '
            'Totzone von UmfangsFortschritt rechnet mit 0,2 cm — sie kann '
            'nichts entscheiden, wenn die Ablage rundet',
      );
    });

    test('jede der fünf Spalten ist Pflicht', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      const vollstaendig = {
        'tag': "'2099-04-12'",
        'mass': "'pruefmassA'",
        'zentimeter': '41.4',
        'eingetragen_am': "'2099-04-12T07:05:00.000Z'",
        'quelle': "'getippt'",
      };

      for (final fehlt in vollstaendig.keys) {
        final rest = {...vollstaendig}..remove(fehlt);
        await expectLater(
          db.customStatement(
            'INSERT INTO umfaenge (${rest.keys.join(', ')}) '
            'VALUES (${rest.values.join(', ')});',
          ),
          throwsA(anything),
          reason:
              'ohne $fehlt ist die Zeile keine Messung — und es gibt keinen '
              'ehrlichen Ersatzwert dafür',
        );
      }
      expect(await zeilen(db, neueTabelle), isEmpty);
    });
  });

  group('Gefiltert wird in SQL, über den Tagesstring', () {
    test('ein Zeitraum lässt sich lexikografisch abfragen, über den '
        'Jahreswechsel hinweg', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      const tage = [
        '2099-09-30',
        '2099-10-01',
        '2099-10-25',
        '2099-12-31',
        '2100-01-01',
        '2100-02-15',
      ];
      for (final tag in tage) {
        await db.customStatement(
          'INSERT INTO umfaenge (tag, mass, zentimeter, eingetragen_am, '
          "quelle) VALUES ('$tag', 'pruefmassA', 41.4, "
          "'${tag}T07:05:00.000Z', 'getippt');",
        );
      }

      final fenster = await db
          .customSelect(
            "SELECT tag FROM umfaenge WHERE tag >= '2099-10-01' "
            "AND tag <= '2100-01-01' ORDER BY tag;",
          )
          .get();

      expect(
        fenster.map((z) => z.read<String>('tag')).toList(),
        ['2099-10-01', '2099-10-25', '2099-12-31', '2100-01-01'],
        reason:
            'der Datumsschlüssel ist der ISO-Tagesstring, nicht Epoch: Ein '
            'Tag ist eine Kalenderangabe, kein Zeitpunkt. So vergleicht '
            'WHERE tag >= ? lexikografisch richtig und übersteht jede '
            'Zeitumstellung — und die Zeitumstellung am 25.10.2099 liegt '
            'mitten in diesem Fenster. Nach dem Laden in Dart zu filtern '
            'umginge Regel 2 der Datenschicht',
      );
    });

    test('ORDER BY tag sortiert chronologisch', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      for (final tag in ['2100-01-02', '2099-04-12', '2099-11-09']) {
        await db.customStatement(
          'INSERT INTO umfaenge (tag, mass, zentimeter, eingetragen_am, '
          "quelle) VALUES ('$tag', 'pruefmassA', 41.4, "
          "'${tag}T07:05:00.000Z', 'getippt');",
        );
      }

      final sortiert = await db
          .customSelect('SELECT tag FROM umfaenge ORDER BY tag;')
          .get();
      expect(
        sortiert.map((z) => z.read<String>('tag')).toList(),
        ['2099-04-12', '2099-11-09', '2100-01-02'],
        reason:
            'führende Nullen und feste Breite: Textsortierung ist hier '
            'Datumssortierung. Der Verlauf je Maß hängt daran',
      );
    });
  });
}
