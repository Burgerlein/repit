import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show Database, sqlite3;

import 'package:repit/data/cache.dart';

import 'schema_tabellen.dart';

/// Tests für **Schema v19** — die Historie des festen Kalorienziels
/// (#410, unter #275).
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden. Jede Migration
/// bekommt einen Test — dies ist der für die Stufe 19.
///
/// ## Woher die Anforderung kommt
///
/// Ticket #410, „Kalorienziel fest — ändert sich nur durch den Coach"
/// (Tim, 07.11.2026). Die Ausgestaltung ist eine **Vorgabe des
/// Koordinators**; Tim hat die Rückfrage dazu weggeklickt, sie also weder
/// bestätigt noch verworfen:
///
/// - Das Ziel wird **einmal** mit der heutigen Formel berechnet und
///   gespeichert, sobald es berechenbar ist und noch keins gespeichert ist.
/// - Es gilt **ab dem Tag seines Festlegens** für alle folgenden Tage.
/// - Ändern geht von Hand (später auch über den Coach); jede Änderung gilt
///   ab ihrem Tag, frühere Tage behalten den alten Wert — **eine
///   Historie**, keine einzelne Zahl.
///
/// Die Nummer wurde am 10.11.2026 nachgesehen: `main` und die Zweige
/// `ki-unsicher`, `wasser-ziel`, `getraenke-ml` und `planung-tag-erholung`
/// stehen auf `schemaVersion => 17`, kein Zweig führt eine 18. Also war
/// die nächste freie damals die 18.
///
/// **Seit dem 11.11.2026 ist es die 19** (#485): In `main` lag inzwischen
/// eine Gym-Stufe 18 (#78), die auf Tims iPhone schon gelaufen und dort in
/// der Datei vermerkt ist. Verschöbe man sie, liefe sie dort nie wieder.
/// Beim Zusammenführen von `umfaenge-88` und `main` behält die Gym-Stufe
/// deshalb die 18, und diese Stufe und alle darüber sind um eins nach oben
/// gerückt; die Datei hieß bis dahin `schema_v18_test.dart`. Nachgezogen
/// beim Zusammenführen, **Tim hat die Änderung nicht gesehen**.
///
/// Der Code der Stufe existierte beim Schreiben dieser Datei nicht.
/// Nachbar von `schema_v16_test.dart` (auch dort legt eine Stufe eine
/// Tabelle an): derselbe Aufbau, von Hand gebaute Altstände — **nicht** aus
/// dem heutigen Code erzeugt (`migration_test.dart`, Dateikopf). Der Stand
/// v17 unten ist der aus `schema_v17_test.dart` (`v16Vorweg` mit den
/// Spalten der Stufe 17).
///
/// **Diese Datei spricht die Tabelle nur über SQL an**, nicht über die
/// drift-Klassen. Sie übersetzt also auch dann, wenn es die Tabelle im Code
/// noch nicht gibt, und meldet dann, *was* fehlt, statt nur, dass sie nicht
/// baut. Den Weg über drift (Datenklasse, Companion, Zeitstempel) prüft
/// `kalorienziele_test.dart` über das Repository.
///
/// ## Was diese Datei verbindlich vorgibt
///
/// **1. `AppCache.schemaVersion >= 19`** und eine **eigene Stufe**
/// `if (from < 19) { … }`. Geprüft mit `>=`, damit diese Datei bei der
/// nächsten Stufe nicht mitfällt (#208).
///
/// **2. Eine neue Tabelle `kalorienziele`** — genau diese sechs Spalten:
///
/// | Spalte | Typ | NULL | Vorgabe | Drift-Name |
/// |---|---|---|---|---|
/// | `ab_tag` | TEXT (ISO-Tag), **Primärschlüssel** | nein | — | `abTag` |
/// | `kcal` | REAL | nein | — | `kcal` |
/// | `herkunft` | TEXT | nein | — | `herkunft` |
/// | `grundumsatz_kcal` | REAL | ja | — | `grundumsatzKcal` |
/// | `aktiv_kcal` | REAL | ja | — | `aktivKcal` |
/// | `koerperziel_kcal` | REAL | ja | — | `koerperzielKcal` |
///
/// Drift-Namen: Tabellenklasse `Kalorienziele` (`db.kalorienziele`),
/// Datenklasse `KalorienzielRow`, Companion `KalorienzieleCompanion`.
///
/// **3. Additiv.** Die Stufe legt **keine** Zeile an — auch dann nicht,
/// wenn die Stammdaten ein Ziel berechenbar machten. Das erste Ziel legt
/// die App fest, nicht die Migration: Eine Migration kennt weder das
/// Gewicht aus Apple Health noch den heutigen Tag, und ein Ziel „ab dem
/// Tag der Migration" erfände einen Zeitpunkt (`CLAUDE.md`: „Eine
/// Migration füllt alte Zeilen nicht mit erfundenen Zeitstempeln").
/// Alle übrigen Tabellen behalten jede Zeile und jeden Wert.
///
/// **4. Zweimal ausführbar** (#234/#240). Steht `kalorienziele` schon in
/// einer Datei mit `user_version = 17`, öffnet sie trotzdem, und die Zeile
/// darin bleibt.
///
/// **5. Abgleich** (#233). Eine Datei auf 19, der die Tabelle fehlt,
/// bekommt sie beim Öffnen.
///
/// ## Festlegungen des Test-Agenten — nicht von Tim freigegeben
///
/// - **`ab_tag` ist der Primärschlüssel.** Je Tag gilt höchstens ein Ziel;
///   wer am selben Tag zweimal ändert, ersetzt die erste Änderung, statt
///   eine zweite Zeile daneben zu legen, von der niemand wüsste, welche
///   gilt. Der Tag ist der ISO-Tagesstring, kein Zeitpunkt (`CLAUDE.md`,
///   „Der Datumsschlüssel ist der ISO-Tagesstring") — `ab_tag <= ?`
///   vergleicht lexikografisch richtig.
/// - **`herkunft` ohne Vorgabewert.** Die Wörter sind `berechnet` und
///   `hand` (später `coach`). Ein Vorgabewert behauptete eine Herkunft,
///   die niemand festgehalten hat.
/// - **Die drei Anteile werden mitgespeichert, nullbar.** Ohne sie könnte
///   die Herleitung (#314) an einem festen Tag nur die *heutigen* Anteile
///   zeigen, und deren Summe wäre nicht mehr die Zahl im Ring — genau der
///   Widerspruch, den #314 beseitigt hat. Ein von Hand gesetztes Ziel hat
///   keine Anteile: `NULL`, nicht `0` (Fehler `01`).
/// - **Kein Zeitstempel `festgelegt_am`.** „Seit wann" ist der Tag, und der
///   steht in `ab_tag`. Eine weitere Spalte verlangt diese Datei nicht —
///   und lässt auch keine zu (die Spaltenmenge wird auf Gleichheit
///   geprüft): Wer eine braucht, meldet das.
///
/// ## Bestehende Tests, die mit dieser Stufe mitgehen
///
/// `schema_tabellen.dart` bekommt `kalorienziele` in [tabellenHeute];
/// `migration_test.dart` nennt die absolute Zahl 19;
/// `schema_abgleich_test.dart` die `heutigeNummer` 19 und die Tabelle im
/// vollständigen Schema; `schema_stufen_robust_test.dart` zählt je ein
/// `CREATE TABLE` mehr. Alle nachgezogen vom Test-Agenten
/// (`TEST_AENDERN=1`), nicht von Tim gesehen.
///
/// **Alle Zahlen, Namen und Zeitpunkte hier sind erfunden.** Die Zeitpunkte
/// liegen im Jahr 2099.
void main() {
  // --- Altstände, von Hand -----------------------------------------------

  /// Stand v17 — `v16Vorweg` aus `schema_v17_test.dart`: alle Tabellen der
  /// Stufen bis 16, dazu die Spalten der Stufe 17 an `lebensmittel`,
  /// `portionen` und `eintraege`.
  const v17Schema = '''
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
      portion_g REAL
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
  ''';

  /// `kalorienziele`, wie ein anderer Zweig sie schon angelegt haben
  /// könnte — von Hand, nach der Tabelle im Dateikopf.
  const kalorienzieleVorweg = '''
    CREATE TABLE kalorienziele (
      ab_tag TEXT NOT NULL PRIMARY KEY,
      kcal REAL NOT NULL,
      herkunft TEXT NOT NULL,
      grundumsatz_kcal REAL,
      aktiv_kcal REAL,
      koerperziel_kcal REAL
    );
  ''';

  const kalorienzielZeileVorweg = '''
    INSERT INTO kalorienziele
      (ab_tag, kcal, herkunft, grundumsatz_kcal, aktiv_kcal, koerperziel_kcal)
      VALUES ('2099-03-01', 2617.25, 'berechnet', 1750.5, 700.2, 166.55);
  ''';

  /// Tims Bestand auf Stand v17 — **mit vollständigen Stammdaten und einem
  /// Gewicht**, also mit allem, woraus sich ein Kalorienziel rechnen
  /// ließe. Genau das macht den Fall „die Migration erfindet kein Ziel"
  /// scharf: Sie hätte die Zutaten und darf sie trotzdem nicht benutzen.
  const bestand = '''
    INSERT INTO tages_werte (tag, schritte, ruhepuls_bpm, gelesen_am,
                             gewicht_kg)
      VALUES ('2099-03-01', 4321, 55, '2099-03-01T08:00:00.000Z', 81.3);
    INSERT INTO stammdaten (id, groesse_cm, geburtsjahr, zielgewicht_kg,
                            zieldatum)
      VALUES (0, 123, 2001, 84.5, '2099-09-30');
    INSERT INTO lebensmittel (id, name, kcal, herkunft,
                              portionen_abgefragt_am)
      VALUES (1, 'Prüfknäcke', 377.7, 'eigen', '2099-03-01T10:20:30.000Z');
    INSERT INTO portionen (id, lebensmittel_id, name, menge_g, herkunft)
      VALUES (5, 1, 'Prüfbon', 5.9, 'eigen');
    INSERT INTO eintraege
      (id, tages_schluessel, mahlzeit, zeitpunkt, lebensmittel_id, name,
       menge_g, kcal, extra, health_uuid, health_stand, portion_id,
       portion_name, portion_g)
      VALUES (1, '2099-03-01', 'frueh', '2099-03-01T07:15:00.000Z', 1,
              'Prüfknäcke', 11.8, 44.6, '{}', 'PRUEF-UUID-0001',
              'geschrieben', 5, 'Prüfbon', 5.9);
    INSERT INTO ki_einstellungen (id, modell, limit_usd, preise)
      VALUES (0, 'pruef-modell-x', 3.5, '{}');
    INSERT INTO wasser_eintraege
      (id, tages_schluessel, zeitpunkt, menge_ml, health_stand)
      VALUES (4, '2099-03-01', '2099-03-01T09:15:00.000Z', 333.5, 'offen');
  ''';

  /// Die Spalten der Tabelle nach dem Dateikopf.
  const spaltenKalorienziele = {
    'ab_tag',
    'kcal',
    'herkunft',
    'grundumsatz_kcal',
    'aktiv_kcal',
    'koerperziel_kcal',
  };

  // --- Hilfsmittel, wie in `schema_v16_test.dart` ------------------------

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

  /// Die Form von `kalorienziele` nach der Tabelle im Dateikopf.
  Future<void> pruefeForm(AppCache db) async {
    final s = await spalten(db, 'kalorienziele');
    expect(
      s.keys.toSet(),
      spaltenKalorienziele,
      reason:
          'genau die sechs Spalten aus dem Dateikopf — eine weitere '
          'verlangt niemand, und wer eine braucht, meldet das',
    );

    expect(s['ab_tag']!.typ, 'TEXT');
    expect(
      s['ab_tag']!.schluessel,
      isTrue,
      reason: 'je Tag gilt höchstens ein Ziel',
    );
    expect(s['ab_tag']!.nullbar, isFalse);
    expect(
      [
        for (final MapEntry(:key, :value) in s.entries)
          if (value.schluessel) key,
      ],
      ['ab_tag'],
      reason: 'der Tag allein ist der Schlüssel, kein zusammengesetzter',
    );

    expect(s['kcal']!.typ, 'REAL', reason: '2617,25 kcal sind eine Zahl');
    expect(
      s['kcal']!.nullbar,
      isFalse,
      reason: 'ein festgelegtes Ziel ohne Zahl ist kein Ziel',
    );

    expect(s['herkunft']!.typ, 'TEXT');
    expect(s['herkunft']!.nullbar, isFalse);
    expect(
      s['herkunft']!.vorgabe,
      isNull,
      reason:
          'ein Vorgabewert behauptete eine Herkunft, die niemand '
          'festgehalten hat',
    );

    for (final anteil in [
      'grundumsatz_kcal',
      'aktiv_kcal',
      'koerperziel_kcal',
    ]) {
      expect(s[anteil]!.typ, 'REAL', reason: anteil);
      expect(
        s[anteil]!.nullbar,
        isTrue,
        reason: '$anteil: ein von Hand gesetztes Ziel hat keine Anteile',
      );
      expect(
        s[anteil]!.vorgabe,
        isNull,
        reason:
            '$anteil: ein Vorgabewert 0 behauptete einen Anteil von null '
            'kcal statt „keiner bekannt" (Fehler `01`)',
      );
    }
  }

  // ═════════════════════════════════════════════════════════════════════

  test('Vorbedingung: der Altstand v17 ist so gebaut, wie er gemeint ist', () {
    final roh = rohdatei(v17Schema, bestand, 17);
    addTearDown(roh.close);
    final namen = {
      for (final z in roh.select(
        "SELECT name FROM sqlite_master WHERE type = 'table' "
        "AND name NOT LIKE 'sqlite_%';",
      ))
        z['name'] as String,
    };
    expect(namen, isNot(contains('kalorienziele')));
    // Seit der Stufe 21 (#430) ohne die Tabellen der Stufe 21, seit der
    // Stufe 22 (#444) ohne die der Stufe 22, seit der Stufe 23 (#451) ohne
    // die der Stufe 23, seit der Stufe 24 (#476) ohne die der Stufe 24 und
    // seit dem Zusammenführen mit `main` (#485) ohne die drei Gym-Tabellen
    // der Stufe 18: Die kann ein v17-Stand nicht haben. Nachgezogen vom
    // Test-Agenten, **Tim hat die Änderung nicht gesehen.**
    expect(
      namen,
      tabellenHeute.difference({
        ...tabellenAusStufe18,
        'kalorienziele',
        ...tabellenAusStufe21,
        ...tabellenAusStufe22,
        ...tabellenAusStufe23,
        ...tabellenAusStufe24,
        ...tabellenAusStufe26,
        ...tabellenAusStufe27,
      }),
      reason:
          'v17 hat alle heutigen Tabellen außer der neuen und denen späterer '
          'Stufen',
    );
    expect(
      roh.select('PRAGMA table_info(eintraege);').map((z) => z['name']),
      contains('portion_g'),
    );
  });

  group('Schema v19 (#410)', () {
    test('die Version ist mindestens 19, und ein frischer Cache hat die '
        'Tabelle — leer', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      expect(db.schemaVersion, greaterThanOrEqualTo(19));
      expect(await tabellen(db), containsAll(tabellenHeute));
      expect(await tabellen(db), contains('kalorienziele'));
      await pruefeForm(db);
      expect(await zeilen(db, 'kalorienziele'), isEmpty);
    });

    test('v17 → v19 legt die Tabelle an, mit der verlangten Form', () async {
      final roh = rohdatei(v17Schema, bestand, 17);
      addTearDown(roh.close);
      final db = ueber(roh);
      addTearDown(db.close);

      expect(await tabellen(db), tabellenHeute);
      await pruefeForm(db);
      expect(await abgelegteVersion(db), db.schemaVersion);
    });

    test('v17 → v19 erfindet kein Ziel — auch nicht, wenn Stammdaten und '
        'Gewicht eins berechenbar machten', () async {
      final roh = rohdatei(v17Schema, bestand, 17);
      addTearDown(roh.close);
      final db = ueber(roh);
      addTearDown(db.close);

      expect(
        await zeilen(db, 'kalorienziele'),
        isEmpty,
        reason:
            'das erste Ziel legt die App fest, an dem Tag, an dem sie es '
            'rechnet. Eine Migration kennt diesen Tag nicht — eine Zeile '
            'von ihr behauptete einen Zeitpunkt, den es nie gab',
      );
    });

    test(
      'v17 → v19 lässt jede vorhandene Zeile und jeden Wert stehen',
      () async {
        final roh = rohdatei(v17Schema, bestand, 17);
        addTearDown(roh.close);
        const alle = [
          'tages_werte',
          'stammdaten',
          'lebensmittel',
          'portionen',
          'eintraege',
          'ki_einstellungen',
          'wasser_eintraege',
        ];
        final vorher = {for (final t in alle) t: rohZeilen(roh, t)};

        final db = ueber(roh);
        addTearDown(db.close);

        for (final t in alle) {
          pruefeUnveraendert(vorher[t]!, await zeilen(db, t), t);
        }
      },
    );

    test('zweimal ausführbar: steht die Tabelle schon da, bleibt ihre Zeile '
        'und nichts wird doppelt angelegt', () async {
      final roh = rohdatei(
        v17Schema + kalorienzieleVorweg,
        bestand + kalorienzielZeileVorweg,
        17,
      );
      addTearDown(roh.close);
      final vorher = rohZeilen(roh, 'kalorienziele');

      final db = ueber(roh);
      addTearDown(db.close);

      expect(await abgelegteVersion(db), db.schemaVersion);
      pruefeUnveraendert(
        vorher,
        await zeilen(db, 'kalorienziele'),
        'kalorienziele',
      );
      await pruefeForm(db);
    });

    test('Abgleich (#233): eine Datei auf 19, der die Tabelle fehlt, '
        'bekommt sie beim Öffnen', () async {
      // Ein Zweig hat die Nummer hochgezogen, bevor seine Stufe fertig war —
      // `if (from < 19)` läuft dann nie.
      final roh = rohdatei(v17Schema, bestand, 19);
      addTearDown(roh.close);
      final db = ueber(roh);
      addTearDown(db.close);

      expect(await tabellen(db), contains('kalorienziele'));
      await pruefeForm(db);
      expect(await zeilen(db, 'kalorienziele'), isEmpty);
    });

    test('ein zweites Öffnen derselben Datei ändert nichts mehr', () async {
      final roh = rohdatei(v17Schema, bestand, 17);
      addTearDown(roh.close);

      final erstes = ueber(roh);
      await erstes.customStatement(
        'INSERT INTO kalorienziele (ab_tag, kcal, herkunft) '
        "VALUES ('2099-03-02', 2800.5, 'hand');",
      );
      final nachErstem = await zeilen(erstes, 'kalorienziele');
      await erstes.close();

      final zweites = ueber(roh);
      addTearDown(zweites.close);
      pruefeUnveraendert(
        nachErstem,
        await zeilen(zweites, 'kalorienziele'),
        'kalorienziele',
      );
      expect(
        nachErstem.single['grundumsatz_kcal'],
        isNull,
        reason: 'ein von Hand gesetztes Ziel hat keine Anteile — und keine 0',
      );
    });

    test('ab_tag ist eindeutig: ein zweites Ziel für denselben Tag ist kein '
        'zweiter Eintrag', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      await db.customStatement(
        'INSERT INTO kalorienziele (ab_tag, kcal, herkunft) '
        "VALUES ('2099-03-02', 2800, 'hand');",
      );
      await expectLater(
        db.customStatement(
          'INSERT INTO kalorienziele (ab_tag, kcal, herkunft) '
          "VALUES ('2099-03-02', 2900, 'hand');",
        ),
        throwsA(anything),
        reason:
            'je Tag gilt höchstens ein Ziel — ersetzt wird über das '
            'Repository, nicht danebengelegt',
      );
    });
  });
}
