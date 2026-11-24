// `drift` exportiert eigene `isNull` und `isNotNull` — dieselbe Begründung
// wie in `test/data/schema_v13_test.dart`, Zeile 1–5.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show Database, sqlite3;

import 'package:repit/data/cache.dart';

import 'schema_tabellen.dart';

/// Tests für **Schema v15** — KI-Zugang (#332, unter #287 und #133).
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden.
///
/// Nachbar von `test/data/schema_v14_test.dart` und
/// `test/data/schema_v13_test.dart`, im selben Verzeichnis: derselbe Aufbau,
/// dieselben Hilfsmittel, von Hand gebaute Altstände. Geschrieben nach der
/// Spec `docs/superpowers/specs/2026-11-04-ki-zugang-design.md`, Abschnitt
/// „Datenschicht — Schema 14 → 15", und Task 1 des Plans
/// `docs/superpowers/plans/2026-11-04-ki-zugang.md` — **ohne** den Code der
/// Stufe gesehen zu haben (es gab ihn beim Schreiben noch nicht).
///
/// ## Was diese Datei verbindlich vorgibt
///
/// **1. `AppCache.schemaVersion >= 15`** und eine **eigene Stufe**
/// `if (from < 15) { … }`. Die Nummer wurde am 04.11.2026 aus `cache.dart`
/// gelesen (`schemaVersion => 14`), also ist die nächste freie die 15.
/// Geprüft wird mit `>=`, damit diese Datei bei der nächsten Stufe nicht
/// mitfällt (#208).
///
/// **2. Zwei neue Tabellen** (Spec und Plan, Abschnitt „Interfaces"):
///
/// `ki_einstellungen`, höchstens eine Zeile:
///
/// | Spalte | Typ | NULL | Vorgabe |
/// |---|---|---|---|
/// | `modell` | TEXT | ja | — |
/// | `limit_usd` | REAL | ja (`null` heißt „Vorgabe 10 $") | — |
/// | `preise` | TEXT | nein | `'{}'` |
/// | `geprueft_am` | TEXT (Zeitstempel) | ja | — |
/// | `pruef_ergebnis` | TEXT | ja | — |
///
/// `ki_anfragen`:
///
/// | Spalte | Typ | NULL |
/// |---|---|---|
/// | `id` | INTEGER, Schlüssel | nein |
/// | `zeitpunkt` | TEXT (Zeitstempel, UTC) | nein |
/// | `monat` | TEXT (`JJJJ-MM`) | nein |
/// | `modell`, `zweck` | TEXT | nein |
/// | `eingabe_token`, `ausgabe_token`, `denk_token` | INTEGER | nein |
/// | `kosten_usd` | REAL | **ja** — kein Preis bekannt |
///
/// **3. `eintraege.vorschlag`** (TEXT, nullbar, **ohne Vorgabewert**).
///
/// **4. Additiv.** Keine Zeile in `ki_einstellungen` (dieselbe Regel wie
/// `stammdaten`: eine vorab eingefügte Zeile behauptete eine Einstellung,
/// die niemand getroffen hat), keine in `ki_anfragen`, und alte
/// `eintraege` behalten jeden Wert und bekommen `vorschlag = NULL` — eine
/// Migration erfindet keine Herkunft.
///
/// **5. Zweimal ausführbar** (#234/#240). Steht `vorschlag` oder
/// `ki_anfragen` schon in einer Datei mit `user_version = 14`, öffnet sie
/// trotzdem, und nichts wird verdoppelt oder neu gebaut.
///
/// **6. Zeitstempel kommen als UTC und gleich sich selbst zurück**
/// (`storeDateTimeAsText`, `CLAUDE.md`).
///
/// ## Namen aus dem Plan, die diese Datei voraussetzt
///
/// Der Rundweg der Zeitstempel geht durch den erzeugten Zugriff — nur dort
/// wirkt `storeDateTimeAsText`, und nur dort fiele eine als `text()` statt
/// `dateTime()` deklarierte Spalte auf. Vorausgesetzt sind deshalb die
/// Namen aus dem Plan: Tabellenklassen `KiEinstellungen` und `KiAnfragen`
/// (also `db.kiEinstellungen`, `db.kiAnfragen` und die Companions
/// `KiEinstellungenCompanion`, `KiAnfragenCompanion`), Datenklassen
/// `KiEinstellungenRow` und `KiAnfrageRow`, und die Feldnamen, die drift
/// aus den Spaltennamen der Spec ableitet (`zeitpunkt`, `monat`,
/// `eingabeToken`, `kostenUsd`, `geprueftAm`, …). Der Companion wird über
/// den Standardkonstruktor gebaut, nicht über `.insert(…)` — so hängt der
/// Test nicht daran, welche Felder Pflicht sind.
///
/// ## Festlegungen des Test-Agenten — nicht von Tim freigegeben
///
/// - **Die Token-Spalten und `modell`/`zweck`/`monat`/`zeitpunkt` sind
///   `NOT NULL`.** Die Spec nennt nur `kosten_usd` nullbar, der Plan
///   markiert nur dort `?`. Das ist die Lesart des Koordinators, nicht
///   Tims; der Test schreibt sie fest. Für die Denk-Token passt es zum
///   Plan („fehlt das Feld, zählt es `0` — eine Zählung, kein Messwert").
/// - **`eintraege.vorschlag` hat keinen Vorgabewert.** Eine Vorgabe wäre
///   eine Herkunft, die jeder von Hand gebuchte Eintrag erbte.
/// - **Die Tabellenmenge wird mit `containsAll` gegen [tabellenHeute]
///   geprüft**, der gemeinsamen Liste aus `schema_tabellen.dart` (#304).
///   Auf Gleichheit prüfen die älteren Stufen-Tests; hier geht es nur
///   darum, dass die beiden neuen dabei sind.
/// - **Den Fall „Tabelle steht schon da" prüft diese Datei nur für
///   `ki_anfragen`**, wie der Plan ihn nennt. Für `ki_einstellungen` legt
///   die Spec keinen Schlüssel fest (wie „höchstens eine Zeile" gesichert
///   wird, ist Sache der Implementierung); eine von Hand gebaute Fassung
///   hier würde eine Form erzwingen, die niemand entschieden hat.
/// - Der Schlüssel von `ki_anfragen` muss ein Schlüssel sein;
///   `AUTOINCREMENT` wird nicht verlangt.
///
/// ## Bestehende Tests, die mit der Stufe rot werden
///
/// `schema_v10_test.dart` bis `schema_v13_test.dart`,
/// `schema_abgleich_test.dart`, `schema_stufen_robust_test.dart` und
/// `schema_fremde_spalten_test.dart` vergleichen die Tabellenmenge auf
/// **Gleichheit**. Sie hielten je eine eigene Liste mit 13 Tabellen; mit
/// dieser Stufe lesen sie die gemeinsame aus `schema_tabellen.dart`
/// (#304), die beide neuen schon enthält — auf dem Stand ohne Stufe 15
/// sind sie deshalb rot, bis die Stufe gebaut ist. `migration_test.dart`
/// nennt die absolute Zahl 15. Nachgezogen vom Test-Agenten auf
/// Entscheidung des Koordinators, nicht von Tim freigegeben.
///
/// **Alle Zahlen, Namen und Modellbezeichnungen hier sind erfunden.** Die
/// Zeitpunkte liegen im Jahr 2099, damit sie keinen Termin nachahmen. Kein
/// Test enthält einen Schlüssel.
void main() {
  /// Die dreizehn Tabellen auf Stand v14 — so, wie
  /// `schema_v14_test.dart` sie von Hand anlegt (`restV13` plus
  /// `lebensmittel` mit `barcode` und `herkunft`). Nicht aus dem heutigen
  /// Code erzeugt (`migration_test.dart`, Dateikopf).
  const v14Schema = '''
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
      herkunft TEXT NOT NULL DEFAULT 'eigen'
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

  /// Die Zeile, an der `eintraege` endet. Die Ersetzungen unten setzen
  /// genau hier an; der Vorbedingungstest prüft, dass sie greifen.
  const eintraegeEnde = '''
      health_stand TEXT NOT NULL DEFAULT 'offen'
    );''';

  /// `eintraege`, wie ein **anderer Zweig** sie schon ausgebaut haben
  /// könnte: `vorschlag` steht da, die Nummer noch auf 14.
  final v14MitVorschlag = v14Schema.replaceFirst(
    eintraegeEnde,
    '''
      health_stand TEXT NOT NULL DEFAULT 'offen',
      vorschlag TEXT
    );''',
  );

  /// `ki_anfragen`, wie ein anderer Zweig sie unter derselben Bundle-ID
  /// schon angelegt haben könnte — von Hand, nach der Spec.
  const kiAnfragenVorweg = '''
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
  ''';

  /// Eine gezählte Anfrage in der vorweggenommenen Tabelle. Sie ist
  /// Verbrauch, den Tim bezahlt hat — eine Stufe, die sie wegwirft, setzte
  /// das Monatslimit still zurück.
  const kiAnfrageVorweg = '''
    INSERT INTO ki_anfragen
      (id, zeitpunkt, monat, modell, zweck, eingabe_token, ausgabe_token,
       denk_token, kosten_usd)
      VALUES (7, '2099-03-01T09:30:00.000Z', '2099-03', 'pruef-modell-x',
              'foto', 1234, 321, 55, 0.00456);
  ''';

  /// Tims Bestand auf Stand v14: zwei Vorlagen, zwei gebuchte Einträge —
  /// einer vollständig, mit Health-Kopie und Zusatzwerten, einer mit
  /// Lücken. **Eine Migration, die hier etwas verlöre, verlöre es
  /// endgültig.**
  const bestand = '''
    INSERT INTO tages_werte (tag, schritte, ruhepuls_bpm, gelesen_am)
      VALUES ('2099-03-01', 4321, 55, '2099-03-01T08:00:00.000Z');
    INSERT INTO lebensmittel
      (id, name, kcal, eiweiss_g, fett_g, extra, fluessig, zuletzt_benutzt,
       barcode, herkunft)
      VALUES (1, 'Prüfgrütze', 123.4, 5.6, 7.8, '{}', 0,
              '2099-03-01T06:30:00.000Z', NULL, 'eigen');
    INSERT INTO lebensmittel (id, name, kcal, fluessig, barcode, herkunft)
      VALUES (2, 'Prüfsaft', 44.4, 1, '0000000000017', 'off');
    INSERT INTO eintraege
      (id, tages_schluessel, mahlzeit, zeitpunkt, lebensmittel_id, name,
       menge_g, kcal, eiweiss_g, kohlenhydrate_g, fett_g, zucker_g,
       ballaststoffe_g, gesaettigt_g, wasser_ml, extra, health_uuid,
       health_stand)
      VALUES (1, '2099-03-01', 'fruehstueck', '2099-03-01T06:30:00.000Z', 1,
              'Prüfgrütze', 250, 308.5, 14, 40.5, 19.5, 2.25,
              3.5, 4.75, NULL, '{"pruef_mg":12.5}',
              'PRUEF-UUID-0000-0001', 'geschrieben');
    INSERT INTO eintraege
      (id, tages_schluessel, mahlzeit, zeitpunkt, lebensmittel_id, name,
       menge_g, kcal, extra, health_stand)
      VALUES (2, '2099-03-01', 'abend', '2099-03-01T18:45:00.000Z', NULL,
              'Freier Prüfeintrag', NULL, 512, '{}', 'offen');
  ''';

  // --- Hilfsmittel, wie in `schema_v13_test.dart` ------------------------

  /// Eine rohe SQLite-Datei im Speicher, auf einen Altstand gesetzt — roh,
  /// damit sie sich mehrfach öffnen und vorher auslesen lässt.
  Database rohdatei(String schema, String inhalt, int version) {
    final roh = sqlite3.openInMemory();
    roh.execute(schema);
    roh.execute(inhalt);
    roh.execute('PRAGMA user_version = $version;');
    return roh;
  }

  /// Öffnet `AppCache` über eine rohe Datei, ohne sie beim Schließen
  /// mitzunehmen.
  AppCache ueber(Database roh) =>
      AppCache(NativeDatabase.opened(roh, closeUnderlyingOnClose: false));

  QueryExecutor altstand(String schema, String inhalt, int version) =>
      NativeDatabase.memory(
        setup: (Database roh) {
          roh.execute(schema);
          roh.execute(inhalt);
          roh.execute('PRAGMA user_version = $version;');
        },
      );

  QueryExecutor v14Cache() => altstand(v14Schema, bestand, 14);

  Future<int> abgelegteVersion(AppCache db) async {
    final zeile = await db.customSelect('PRAGMA user_version;').getSingle();
    return zeile.read<int>('user_version');
  }

  Future<int> schemaStempel(AppCache db) async {
    final zeile = await db.customSelect('PRAGMA schema_version;').getSingle();
    return zeile.read<int>('schema_version');
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

  /// Dieselbe Abfrage gegen die rohe Datei, **bevor** `AppCache` sie
  /// öffnet — der Vergleichsstand für „vollständig".
  List<Map<String, Object?>> rohZeilen(Database roh, String tabelle) => [
    for (final z in roh.select('SELECT * FROM $tabelle ORDER BY rowid;'))
      Map<String, Object?>.of(z),
  ];

  /// Jede Spalte, die vorher da war, trägt nachher denselben Wert.
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
          reason: '$tabelle, Zeile ${i + 1}, Spalte $key: ein vorhandener '
              'Wert ist Tims Wert',
        );
      }
    }
  }

  /// Form von `ki_einstellungen` nach Spec.
  Future<void> pruefeEinstellungenForm(AppCache db) async {
    final s = await spalten(db, 'ki_einstellungen');

    expect(
      s.keys,
      containsAll([
        'modell',
        'limit_usd',
        'preise',
        'geprueft_am',
        'pruef_ergebnis',
      ]),
    );

    expect(s['modell']!.typ, 'TEXT');
    expect(
      s['modell']!.nullbar,
      isTrue,
      reason: 'kein Modell gewählt heißt: die Voreinstellung der App gilt',
    );

    expect(s['limit_usd']!.typ, 'REAL');
    expect(
      s['limit_usd']!.nullbar,
      isTrue,
      reason: 'null heißt „Vorgabe 10 \$" — keine Zahl, die niemand '
          'eingegeben hat',
    );

    expect(s['preise']!.typ, 'TEXT');
    expect(s['preise']!.nullbar, isFalse);
    expect(
      s['preise']!.vorgabe,
      isNotNull,
      reason: 'Vorgabe ist das leere Objekt — keine Überschreibungen',
    );

    expect(s['geprueft_am']!.typ, 'TEXT');
    expect(
      s['geprueft_am']!.nullbar,
      isTrue,
      reason: 'nie geprüft ist ein eigener Zustand, kein erfundener Zeitpunkt',
    );

    expect(s['pruef_ergebnis']!.typ, 'TEXT');
    expect(s['pruef_ergebnis']!.nullbar, isTrue);
  }

  /// Form von `ki_anfragen` nach Spec und Plan.
  Future<void> pruefeAnfragenForm(AppCache db) async {
    final s = await spalten(db, 'ki_anfragen');

    expect(
      s.keys,
      containsAll([
        'id',
        'zeitpunkt',
        'monat',
        'modell',
        'zweck',
        'eingabe_token',
        'ausgabe_token',
        'denk_token',
        'kosten_usd',
      ]),
    );

    expect(s['id']!.schluessel, isTrue);

    expect(
      s['zeitpunkt']!.typ,
      'TEXT',
      reason: 'AppCache arbeitet mit storeDateTimeAsText: true — ein '
          'Zeitstempel als Unix-Sekunden käme als Ortszeit zurück '
          '(`CLAUDE.md`)',
    );
    expect(s['zeitpunkt']!.nullbar, isFalse);

    expect(
      s['monat']!.typ,
      'TEXT',
      reason: 'gefiltert wird in SQL über den Monatsschlüssel, '
          'lexikografisch wie der Tagesschlüssel',
    );
    expect(s['monat']!.nullbar, isFalse);

    for (final name in ['modell', 'zweck']) {
      expect(s[name]!.typ, 'TEXT', reason: name);
      expect(s[name]!.nullbar, isFalse, reason: name);
    }

    for (final name in ['eingabe_token', 'ausgabe_token', 'denk_token']) {
      expect(s[name]!.typ, 'INTEGER', reason: name);
      expect(
        s[name]!.nullbar,
        isFalse,
        reason: '$name ist eine Zählung, kein Messwert: Fehlt das Feld in '
            'der Antwort, zählt es 0 (Plan, „Review Focus" 2)',
      );
    }

    expect(s['kosten_usd']!.typ, 'REAL');
    expect(
      s['kosten_usd']!.nullbar,
      isTrue,
      reason: 'ohne bekannten Preis sind die Kosten unbekannt, nicht 0 — '
          'eine 0 senkte die Monatssumme still',
    );
  }

  /// Form von `eintraege.vorschlag`.
  Future<void> pruefeVorschlagForm(AppCache db) async {
    final s = await spalten(db, 'eintraege');

    expect(s.keys, contains('vorschlag'));
    expect(s['vorschlag']!.typ, 'TEXT');
    expect(
      s['vorschlag']!.nullbar,
      isTrue,
      reason: 'ein von Hand gebuchter Eintrag hat keine KI-Herkunft',
    );
    expect(
      s['vorschlag']!.vorgabe,
      isNull,
      reason: 'eine Vorgabe wäre eine Herkunft, die jeder Eintrag erbt — '
          'eine Migration erfindet keine Herkunft',
    );
  }

  // ---------------------------------------------------------------------

  group('Schema v15 — frisch angelegt', () {
    test('die Datenbank steht mindestens auf Version 15', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      expect(
        db.schemaVersion,
        greaterThanOrEqualTo(15),
        reason: 'eine eigene Stufe, keine Erweiterung der v14-Stufe (#233)',
      );
      expect(await abgelegteVersion(db), db.schemaVersion);
    });

    test('beide KI-Tabellen und eintraege.vorschlag sind da', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      expect(await tabellen(db), containsAll(tabellenHeute));
      await pruefeEinstellungenForm(db);
      await pruefeAnfragenForm(db);
      await pruefeVorschlagForm(db);
    });

    test('beide KI-Tabellen kommen leer', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      expect(
        await zeilen(db, 'ki_einstellungen'),
        isEmpty,
        reason: 'eine vorab eingefügte Zeile behauptete eine Einstellung, '
            'die niemand getroffen hat (Spec, wie bei stammdaten)',
      );
      expect(await zeilen(db, 'ki_anfragen'), isEmpty);
    });

    test('eine Einstellungszeile ohne Angaben: preise ist {}, der Rest '
        'leer', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      await db.customStatement(
        'INSERT INTO ki_einstellungen DEFAULT VALUES;',
      );
      final zeile = (await zeilen(db, 'ki_einstellungen')).single;

      expect(zeile['preise'], '{}');
      expect(zeile['modell'], isNull);
      expect(
        zeile['limit_usd'],
        isNull,
        reason: 'nicht 10 und nicht 0: null heißt „Vorgabe" (Spec)',
      );
      expect(zeile['geprueft_am'], isNull);
      expect(zeile['pruef_ergebnis'], isNull);
    });
  });

  group('Migration v14 → v15 — additiv', () {
    test('die Datei steht danach auf der heutigen Version', () async {
      final db = AppCache(v14Cache());
      addTearDown(db.close);

      expect(await abgelegteVersion(db), db.schemaVersion);
      expect(await abgelegteVersion(db), greaterThanOrEqualTo(15));
    });

    test('beide Tabellen und die Spalte sind danach da', () async {
      final db = AppCache(v14Cache());
      addTearDown(db.close);

      expect(await tabellen(db), containsAll(tabellenHeute));
      await pruefeEinstellungenForm(db);
      await pruefeAnfragenForm(db);
      await pruefeVorschlagForm(db);
    });

    test('ki_einstellungen bekommt keine Zeile, ki_anfragen auch nicht',
        () async {
      final db = AppCache(v14Cache());
      addTearDown(db.close);

      expect(
        await zeilen(db, 'ki_einstellungen'),
        isEmpty,
        reason: 'die Stufe legt keine Zeile an — eine solche Zeile '
            'behauptete eine Einstellung, die niemand getroffen hat',
      );
      expect(
        await zeilen(db, 'ki_anfragen'),
        isEmpty,
        reason: 'kein erfundener Verbrauch',
      );
    });

    test('alte eintraege bleiben vollständig, vorschlag ist dort null',
        () async {
      final roh = rohdatei(v14Schema, bestand, 14);
      addTearDown(roh.close);
      final vorher = rohZeilen(roh, 'eintraege');
      expect(vorher, hasLength(2), reason: 'Vorbedingung');

      final db = ueber(roh);
      addTearDown(db.close);
      final nachher = await zeilen(db, 'eintraege');

      pruefeUnveraendert(vorher, nachher, 'eintraege');
      for (final zeile in nachher) {
        expect(zeile.containsKey('vorschlag'), isTrue);
        expect(
          zeile['vorschlag'],
          isNull,
          reason: 'alte Zeilen bleiben null — eine Migration erfindet keine '
              'Herkunft (Spec)',
        );
      }
    });

    test('lebensmittel und tages_werte bleiben, wie sie waren', () async {
      final roh = rohdatei(v14Schema, bestand, 14);
      addTearDown(roh.close);
      final lebensmittelVorher = rohZeilen(roh, 'lebensmittel');
      final tagesWerteVorher = rohZeilen(roh, 'tages_werte');

      final db = ueber(roh);
      addTearDown(db.close);

      pruefeUnveraendert(
        lebensmittelVorher,
        await zeilen(db, 'lebensmittel'),
        'lebensmittel',
      );
      pruefeUnveraendert(
        tagesWerteVorher,
        await zeilen(db, 'tages_werte'),
        'tages_werte',
      );
    });

    test('nach der Migration lässt sich eine Herkunft schreiben und lesen',
        () async {
      final db = AppCache(v14Cache());
      addTearDown(db.close);

      const herkunft =
          '{"anbieter":"gemini","modell":"pruef-modell-x",'
          '"zeitpunkt":"2099-03-01T12:00:00.000Z","zweck":"foto"}';
      await db.customStatement(
        'INSERT INTO eintraege '
        '(tages_schluessel, mahlzeit, zeitpunkt, name, extra, health_stand, '
        'vorschlag) '
        "VALUES ('2099-03-01', 'mittag', '2099-03-01T12:00:00.000Z', "
        "'Prüfteller', '{}', 'offen', ?);",
        [herkunft],
      );

      final neu = (await zeilen(db, 'eintraege')).last;
      expect(neu['vorschlag'], herkunft);
      expect(
        (await zeilen(db, 'eintraege')).first['vorschlag'],
        isNull,
        reason: 'der neue Eintrag färbt nicht auf die alten ab',
      );
    });
  });

  group('Zeitstempel kommen als UTC und gleich sich selbst zurück', () {
    final quellen = <String, QueryExecutor Function()>{
      'frisch angelegt': NativeDatabase.memory,
      'aus v14 migriert': v14Cache,
    };

    for (final MapEntry(key: name, value: quelle) in quellen.entries) {
      test('ki_anfragen.zeitpunkt — $name', () async {
        final db = AppCache(quelle());
        addTearDown(db.close);

        final zeitpunkt = DateTime.utc(2099, 3, 1, 23, 30, 15, 250);
        await db
            .into(db.kiAnfragen)
            .insert(
              KiAnfragenCompanion(
                zeitpunkt: Value(zeitpunkt),
                monat: const Value('2099-03'),
                modell: const Value('pruef-modell-x'),
                zweck: const Value('foto'),
                eingabeToken: const Value(1000),
                ausgabeToken: const Value(200),
                denkToken: const Value(0),
              ),
            );

        final zeile = await db.select(db.kiAnfragen).getSingle();
        expect(
          zeile,
          isA<KiAnfrageRow>(),
          reason: '@DataClassName(\'KiAnfrageRow\') — damit die Datenklasse '
              'nicht mit einem Werttyp des Kerns kollidiert (Plan)',
        );
        expect(zeile.zeitpunkt.isUtc, isTrue);
        expect(
          zeile.zeitpunkt,
          zeitpunkt,
          reason: 'ein als UTC abgelegter Wert, der als Ortszeit zurückkäme, '
              'wäre ungleich sich selbst — und die Monatsgrenze in Berliner '
              'Zeit rechnete ab einem falschen Zeitpunkt',
        );
        expect(zeile.monat, '2099-03');
        expect(zeile.denkToken, 0);
        expect(
          zeile.kostenUsd,
          isNull,
          reason: 'nicht angegeben heißt unbekannt, nicht 0',
        );

        final roh = await db
            .customSelect(
              'SELECT typeof(zeitpunkt) AS art FROM ki_anfragen;',
            )
            .getSingle();
        expect(
          roh.read<String>('art'),
          'text',
          reason: 'storeDateTimeAsText: als Text in der Datei',
        );
      });

      test('ki_einstellungen.geprueft_am — $name', () async {
        final db = AppCache(quelle());
        addTearDown(db.close);

        final geprueft = DateTime.utc(2099, 3, 31, 22, 59, 59, 999);
        await db
            .into(db.kiEinstellungen)
            .insert(KiEinstellungenCompanion(geprueftAm: Value(geprueft)));

        final zeile = await db.select(db.kiEinstellungen).getSingle();
        expect(
          zeile,
          isA<KiEinstellungenRow>(),
          reason: '@DataClassName(\'KiEinstellungenRow\') (Plan)',
        );
        expect(zeile.geprueftAm, isNotNull);
        expect(zeile.geprueftAm!.isUtc, isTrue);
        expect(zeile.geprueftAm, geprueft);
        expect(zeile.preise, '{}');
        expect(zeile.limitUsd, isNull);
      });
    }
  });

  group('Die Stufe ist zweimal ausführbar (#234/#240)', () {
    test('die Altstände sind wirklich vorweggenommen — sonst prüft der Rest '
        'nichts', () {
      expect(
        v14Schema,
        contains(eintraegeEnde),
        reason: 'die Ersetzung muss greifen. Greift sie nicht, läuft die '
            'Gruppe gegen den unveränderten v14-Stand und belegt den Fall '
            'gar nicht',
      );
      expect(v14MitVorschlag, contains('vorschlag TEXT'));
      expect(v14Schema, isNot(contains('vorschlag')));
    });

    test('vorschlag steht schon da: die Datei öffnet, der Wert bleibt',
        () async {
      const herkunft = '{"anbieter":"gemini","zweck":"foto"}';
      final roh = rohdatei(
        v14MitVorschlag,
        "$bestand UPDATE eintraege SET vorschlag = '$herkunft' WHERE id = 2;",
        14,
      );
      addTearDown(roh.close);
      final vorher = rohZeilen(roh, 'eintraege');

      final db = ueber(roh);
      addTearDown(db.close);

      expect(
        await abgelegteVersion(db),
        db.schemaVersion,
        reason: 'die erste Abfrage löst das Öffnen aus. Stirbt die Stufe an '
            '`duplicate column name: vorschlag`, kommt es hier an — und auf '
            'dem Gerät gar nicht mehr weiter',
      );
      pruefeUnveraendert(vorher, await zeilen(db, 'eintraege'), 'eintraege');
      expect(
        (await zeilen(db, 'eintraege'))[1]['vorschlag'],
        herkunft,
        reason: 'eine vorhandene Spalte wird nicht geleert',
      );
      expect(
        (await spalten(db, 'eintraege')).keys.where((k) => k == 'vorschlag'),
        hasLength(1),
      );
      expect(
        await tabellen(db),
        containsAll(tabellenHeute),
        reason: 'die übrigen Stücke der Stufe kommen trotzdem dazu',
      );
    });

    test('ki_anfragen steht schon da: die Datei öffnet, nichts wird '
        'verdoppelt', () async {
      final roh = rohdatei(
        '$v14Schema$kiAnfragenVorweg',
        '$bestand$kiAnfrageVorweg',
        14,
      );
      addTearDown(roh.close);
      final vorher = rohZeilen(roh, 'ki_anfragen');

      final db = ueber(roh);
      addTearDown(db.close);

      expect(
        await abgelegteVersion(db),
        db.schemaVersion,
        reason: 'ein CREATE TABLE ohne IF NOT EXISTS stürbe hier an '
            '`table ki_anfragen already exists`',
      );

      final nachher = await zeilen(db, 'ki_anfragen');
      pruefeUnveraendert(vorher, nachher, 'ki_anfragen');
      expect(
        nachher.single['id'],
        7,
        reason: 'die gezählte Anfrage überlebt — kein DROP und Neubau. Wer '
            'sie wegwirft, setzt das Monatslimit still zurück',
      );
      expect(nachher.single['kosten_usd'], 0.00456);

      final zahl = await db
          .customSelect(
            "SELECT COUNT(*) AS n FROM sqlite_master WHERE type = 'table' "
            "AND name = 'ki_anfragen';",
          )
          .getSingle();
      expect(zahl.read<int>('n'), 1);

      await pruefeVorschlagForm(db);
      await pruefeEinstellungenForm(db);
      expect(await zeilen(db, 'ki_einstellungen'), isEmpty);
      pruefeUnveraendert(
        rohZeilen(roh, 'eintraege'),
        await zeilen(db, 'eintraege'),
        'eintraege',
      );
    });

    test('zweites Öffnen derselben Datei: nichts wird angefasst, nichts geht '
        'verloren', () async {
      final roh = rohdatei(v14Schema, bestand, 14);
      addTearDown(roh.close);

      final erstesMal = ueber(roh);
      await pruefeVorschlagForm(erstesMal);
      expect(
        await tabellen(erstesMal),
        containsAll(tabellenHeute),
        reason: 'Vorbedingung',
      );
      final stempel = await schemaStempel(erstesMal);
      final eintraegeNachDerStufe = await zeilen(erstesMal, 'eintraege');
      await erstesMal.close();

      final zweitesMal = ueber(roh);
      addTearDown(zweitesMal.close);

      expect(
        await schemaStempel(zweitesMal),
        stempel,
        reason: 'SQLite erhöht `PRAGMA schema_version` bei jedem CREATE, '
            'ALTER und DROP. Gleich heißt: beim zweiten Öffnen ist nichts '
            'gegen das Schema gelaufen',
      );
      expect(await zeilen(zweitesMal, 'eintraege'), eintraegeNachDerStufe);
      expect(await zeilen(zweitesMal, 'ki_einstellungen'), isEmpty);
      expect(await zeilen(zweitesMal, 'ki_anfragen'), isEmpty);
    });
  });
}
