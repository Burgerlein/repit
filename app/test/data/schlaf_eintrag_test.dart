// `drift` exportiert ein eigenes `isNull` (Spaltenausdruck für `IS NULL` in
// Abfragen) — das kollidiert mit `package:matcher`s `isNull`-Matcher.
// Dieselbe Begründung wie in `test/data/migration_test.dart`, Zeile 1–4.
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show Database;
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/data/schlaf_eintrag.dart';

/// Tests für die **Ablage der von Hand eingetragenen Schlafphasen** (#131,
/// Zug 1) — Schema v6, Tabelle `schlaf_eintraege`,
/// `lib/data/schlaf_eintrag.dart`.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden.
///
/// ## Warum es diese Ablage gibt
///
/// `docs/screens/screens/schlaf.js` (ENTWURF vom 26.10.2026, Zustände
/// `von-hand`, `form-zeiten`, `form-dauer`) und `tagschlaf.js` sehen vor,
/// eine Nacht oder ein Nickerchen von Hand einzutragen — „für die Nacht, in
/// der die Uhr auf dem Nachttisch lag". Der Entwurf legt zugleich fest,
/// **wohin** der Eintrag geht:
///
/// > Der Eintrag geht nicht nach Apple Health. `CLAUDE.md` legt fest, dass
/// > die ausgelieferte App auf dem Gerät reine Lesequelle bleibt. Die Nacht
/// > liegt also in der App und wird beim Lesen über die Health-Daten gelegt.
///
/// Daraus folgt alles Weitere:
///
/// - **Zweite Tabellengruppe** (Spec 5.6a): Das sind Tims eigene Daten, kein
///   Lauf aus Apple Health. `Messwert<T>` gilt hier **nicht** — es gibt
///   keinen Lauf, der leer ausgehen könnte. Leer heißt leer, eine fehlende
///   Zeile ist ein fehlender Eintrag, kein `LeerNachLauf`. Es gibt deshalb
///   auch **kein `gelesen_am`**: Eine Spalte, die sagt, wann wir etwas aus
///   Apple Health geholt haben, hätte hier nichts zu tragen.
/// - **Dauerhaft, nicht nachladbar.** Der drift-Cache in `naechte` /
///   `schlaf_abschnitte` darf jederzeit verworfen und neu geholt werden;
///   diese Zeilen nicht — sie sind Tims einzige Kopie. Sie liegen deshalb in
///   derselben Datenbank, aber in einer eigenen Tabelle, nicht als
///   Sonderzeilen zwischen den gecachten Abschnitten.
///
/// ## Entscheidungen dieser Testdatei
///
/// ### Eine Tabelle für Nacht **und** Tagschlaf
///
/// Beide tragen dieselben Felder: ein Tag, eine Dauer, optional zwei
/// Uhrzeiten, optional eine Notiz. Zwei Tabellen mit identischen Spalten
/// wären zwei Stellen, an denen dieselbe Prüfung stehen müsste. Die Art
/// steht deshalb als Spalte (`art`), und zwar als **Name** des Enum-Werts,
/// nicht als Index: Ein später eingefügter Wert verschöbe sonst die
/// Bedeutung jeder abgelegten Zeile — dieselbe Regel, nach der
/// `schlaf_abschnitte.phase` den `SleepStage.name` trägt.
///
/// ### Der Schlüssel ist `{tag, art, lfd_nr}`
///
/// - Eine **Nacht** je Aufwachtag: `lfd_nr` ist dort immer 0, und ein
///   zweiter Eintrag für denselben Tag **ersetzt** den ersten. Zwei
///   eingetragene Nächte für dieselbe Nacht wären zwei Antworten auf
///   dieselbe Frage, und niemand wüsste, welche gilt.
/// - **Mehrere Nickerchen** je Tag: `tagschlaf.js` zeigt den Zustand „Zwei
///   Phasen" ausdrücklich. Die laufende Nummer vergibt die Ablage selbst
///   (`fuegeTagschlafHinzu`), damit kein Aufrufer sie raten muss.
///
/// ### Uhrzeiten als **Minuten nach Mitternacht**, nicht als Zeitstempel
///
/// „Zu Bett 23:10" ist eine Tageszeit, kein Ereignis — dieselbe Entscheidung
/// wie bei `ZielWerte.schlafenszeit_minuten` (#111) und aus demselben Grund
/// (`CLAUDE.md`, „Keine hartcodierten Ereignisse": alles, was ein Ereignis
/// ist, ist ein Objekt; alles, was eine Uhrzeit ist, ist eine Zahl). Dass die
/// Spalte damit **kein** `DateTime` ist, erspart ihr zugleich die ganze
/// Zeitzonenfrage: Ein als Zeitpunkt abgelegtes „02:30 am 25.10.2026"
/// bezeichnete in Berlin zwei verschiedene Momente. Die Regel aus
/// `CLAUDE.md` („Zeitstempel liegen in der Datenbank als Text") bleibt
/// unberührt — es wird hier schlicht kein Zeitstempel abgelegt.
///
/// Der **Tag** dagegen ist der ISO-Tagesschlüssel (`2026-10-29`), wie in
/// jeder anderen Tabelle: `WHERE tag >= ?` vergleicht lexikografisch richtig
/// und übersteht jede Zeitumstellung.
///
/// ### Beide Uhrzeiten oder keine
///
/// Der Entwurf kennt genau zwei Fassungen des Formulars: „Zeiten" (zu Bett
/// **und** aufgestanden) oder „nur Dauer". Eine halbe Angabe gibt es dort
/// nicht, und sie wäre auch nicht zu gebrauchen — aus einem Beginn ohne Ende
/// ließe sich kein Fenster zeichnen. Die Ablage weist sie deshalb ab, statt
/// sie anzunehmen und später irgendwo zu ergänzen.
///
/// ### Die Dauer steht immer in der Zeile, auch mit Zeiten
///
/// Der Entwurf: „Die Dauer rechnet sich aus den Zeiten und lässt sich
/// überschreiben, falls du wach dazwischen lagst." Eine Dauer, die beim
/// Lesen aus den Zeiten zurückgerechnet würde, könnte das Überschreiben gar
/// nicht abbilden. Sie ist deshalb eine eigene, nicht nullbare Spalte — und
/// die Ablage prüft **nicht** nach, ob sie zu den Zeiten passt. Das ist
/// Absicht: Wer von 23:10 bis 06:15 im Bett lag und 7:05 h als 6:30 h
/// korrigiert, hat recht und nicht die Rechnung.
///
/// ## Festgelegte öffentliche API (`lib/data/schlaf_eintrag.dart`)
///
/// ```dart
/// enum SchlafEintragArt { nacht, tagschlaf }
///
/// @immutable
/// class SchlafEintrag {
///   const SchlafEintrag({
///     required String tag,          // ISO-Tagesschlüssel
///     required SchlafEintragArt art,
///     required int lfdNr,
///     required int schlafMinuten,
///     int? beginnMinuten,           // Minuten nach Mitternacht, 0..1439
///     int? endeMinuten,
///     String? notiz,
///   });
///   bool get hatZeiten;             // beginnMinuten != null
/// }
///
/// class SchlafEintragRepository {
///   SchlafEintragRepository(AppCache db);
///   Future<List<SchlafEintrag>> lies(DataWindow fenster);
///   Future<void> schreibeNacht({
///     required String tag,
///     required int schlafMinuten,
///     int? beginnMinuten,
///     int? endeMinuten,
///     String? notiz,
///   });
///   Future<void> fuegeTagschlafHinzu({ … dieselben Felder … });
///   Future<void> loescheNacht(String tag);
///   Future<void> loescheTagschlaf({required String tag, required int lfdNr});
/// }
/// ```
///
/// Die Provider-Schicht darüber (`schlafEintraegeProvider`) prüft
/// `schlaf_eintrag_provider_test.dart`; die Verschmelzung mit den gemessenen
/// Nächten gehört in die Schirm-Schicht und steht in
/// `test/shell/schlaf_von_hand_test.dart`.
void main() {
  // ───────────────────────────────────────────────────────────────────────
  // Schema v6 und die Migration dorthin
  // ───────────────────────────────────────────────────────────────────────

  group('Schema v6 — die Tabelle der eigenen Einträge (#131)', () {
    test('ein frisch angelegter Cache steht mindestens auf Version 6', () async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      // Ein Zugriff, damit `onCreate` tatsächlich läuft — das Öffnen selbst
      // ist bei drift lazy.
      expect(await db.select(db.schlafEintraege).get(), isEmpty);
      expect(
        db.schemaVersion,
        greaterThanOrEqualTo(6),
        reason:
            'v6 bringt `schlaf_eintraege` (#131). Je Ticket eine Stufe, '
            'keine Sammelversion — dieselbe Begründung wie bei v3 bis v5. '
            'Hier stand früher die jeweils aktuelle Zahl wörtlich, und sie '
            'musste bei jeder fremden Stufe nachgezogen werden: 7 nach '
            '#194, 8 nach #193, 9 nach #202, 10 nach #269. Genau das war '
            'der Gegenstand von #208. Seit dem 04.11.2026 steht hier '
            '`greaterThanOrEqualTo(6)` — dieser Fall handelt von der '
            'v6-Stufe und soll nur sagen, dass sie dazugehört. Die genaue '
            'Zahl zählt `migration_test.dart`, und zwar als einzige Stelle '
            '(dasselbe Muster wie in `schema_v9_test.dart`, Commit '
            '32c3df1)',
      );
    });

    test('die Migration von v5 legt die Tabelle an und verwirft nichts — und '
        'sie füllt keine alte Zeile mit erfundenen Werten', () async {
      // Schema v5 von Hand nachgebaut, genau wie in `migration_test.dart`
      // und `schema_v3_test.dart`: `PRAGMA user_version = 5`, sonst sähe
      // drift Version 0 und riefe `onCreate` statt `onUpgrade`.
      final executor = NativeDatabase.memory(
        setup: (Database raw) {
          raw.execute('''
              CREATE TABLE tages_werte (
                tag TEXT NOT NULL PRIMARY KEY,
                schritte INTEGER NULL,
                ruhepuls_bpm INTEGER NULL,
                gelesen_am TEXT NULL,
                hrv_ms REAL NULL,
                resp_rate REAL NULL,
                recovery_hr_drop INTEGER NULL
              );
            ''');
          raw.execute('''
              CREATE TABLE stunden_schritte (
                tag TEXT NOT NULL,
                stunde INTEGER NOT NULL,
                schritte INTEGER NULL,
                PRIMARY KEY (tag, stunde)
              );
            ''');
          raw.execute('''
              CREATE TABLE eigene_daten (
                id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
                tag TEXT NOT NULL,
                inhalt TEXT NOT NULL
              );
            ''');
          raw.execute('''
              CREATE TABLE naechte (
                tag TEXT NOT NULL PRIMARY KEY,
                gelesen_am TEXT NULL
              );
            ''');
          raw.execute('''
              CREATE TABLE schlaf_abschnitte (
                tag TEXT NOT NULL,
                quelle INTEGER NOT NULL,
                lfd_nr INTEGER NOT NULL,
                phase TEXT NOT NULL,
                beginn TEXT NOT NULL,
                ende TEXT NOT NULL,
                PRIMARY KEY (tag, quelle, lfd_nr)
              );
            ''');
          raw.execute('''
              CREATE TABLE ziel_werte (
                id INTEGER NOT NULL DEFAULT 0 PRIMARY KEY,
                schlafziel_minuten INTEGER NOT NULL,
                schlafenszeit_minuten INTEGER NOT NULL,
                wochenziel_trainingsminuten INTEGER NOT NULL
              );
            ''');
          raw.execute('''
              CREATE TABLE tagesgefuehle (
                tag TEXT NOT NULL PRIMARY KEY,
                wert INTEGER NOT NULL
              );
            ''');
          raw.execute(
            "INSERT INTO tages_werte (tag, schritte, ruhepuls_bpm, "
            "gelesen_am) VALUES ('2026-10-20', 8421, 58, "
            "'2026-10-20T06:00:00.000Z');",
          );
          raw.execute(
            "INSERT INTO tagesgefuehle (tag, wert) VALUES "
            "('2026-10-20', 4);",
          );
          raw.execute('PRAGMA user_version = 5;');
        },
      );

      final db = AppCache(executor);
      addTearDown(db.close);

      // Die neue Tabelle gibt es, und sie ist leer. **Keine
      // Platzhalterzeile:** Eine Migration, die für jeden vorhandenen Tag
      // einen leeren Eintrag anlegte, behauptete einen Eintrag, den
      // niemand gemacht hat.
      expect(await db.select(db.schlafEintraege).get(), isEmpty);

      // Und die alten Zeilen stehen unverändert da.
      final tageswert = await (db.select(
        db.tagesWerte,
      )..where((t) => t.tag.equals('2026-10-20'))).getSingle();
      expect(tageswert.schritte, 8421);
      expect(tageswert.ruhepulsBpm, 58);
      expect(tageswert.gelesenAm, DateTime.utc(2026, 10, 20, 6));

    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // Schreiben und Wiederlesen
  // ───────────────────────────────────────────────────────────────────────

  group('Eine Nacht von Hand', () {
    late AppCache db;
    late SchlafEintragRepository repo;

    setUp(() {
      db = AppCache(NativeDatabase.memory());
      repo = SchlafEintragRepository(db);
      addTearDown(db.close);
    });

    test('mit Zeiten: alles kommt unverändert zurück', () async {
      await repo.schreibeNacht(
        tag: '2026-10-29',
        schlafMinuten: 425,
        beginnMinuten: 23 * 60 + 10,
        endeMinuten: 6 * 60 + 15,
        notiz: 'Uhr vergessen',
      );

      final eintraege = await repo.lies(DataWindow.unlimited);

      expect(eintraege, hasLength(1));
      final nacht = eintraege.single;
      expect(nacht.tag, '2026-10-29');
      expect(nacht.art, SchlafEintragArt.nacht);
      expect(nacht.lfdNr, 0);
      expect(nacht.schlafMinuten, 425);
      expect(nacht.beginnMinuten, 1390);
      expect(nacht.endeMinuten, 375);
      expect(nacht.notiz, 'Uhr vergessen');
      expect(nacht.hatZeiten, isTrue);
    });

    test('nur mit Dauer: beide Uhrzeiten bleiben null — und das ist kein '
        'fehlender Wert, sondern die zweite Fassung des Formulars', () async {
      await repo.schreibeNacht(tag: '2026-10-29', schlafMinuten: 420);

      final nacht = (await repo.lies(DataWindow.unlimited)).single;

      expect(nacht.schlafMinuten, 420);
      expect(nacht.beginnMinuten, isNull);
      expect(nacht.endeMinuten, isNull);
      expect(nacht.notiz, isNull);
      expect(nacht.hatZeiten, isFalse);
    });

    test('die Dauer wird nicht gegen die Zeiten geprüft — wer 7:05 h im Bett '
        'lag und 6:30 h schlief, hat recht und nicht die Rechnung', () async {
      await repo.schreibeNacht(
        tag: '2026-10-29',
        schlafMinuten: 390,
        beginnMinuten: 23 * 60 + 10,
        endeMinuten: 6 * 60 + 15,
      );

      final nacht = (await repo.lies(DataWindow.unlimited)).single;

      expect(nacht.schlafMinuten, 390);
    });

    test('ein zweiter Eintrag für denselben Aufwachtag ersetzt den ersten, '
        'statt daneben zu stehen', () async {
      await repo.schreibeNacht(tag: '2026-10-29', schlafMinuten: 420);
      await repo.schreibeNacht(
        tag: '2026-10-29',
        schlafMinuten: 450,
        beginnMinuten: 22 * 60 + 40,
        endeMinuten: 6 * 60 + 30,
      );

      final eintraege = await repo.lies(DataWindow.unlimited);

      expect(eintraege, hasLength(1));
      expect(eintraege.single.schlafMinuten, 450);
      expect(eintraege.single.beginnMinuten, 1360);
    });

    test('und sie lässt sich wieder löschen', () async {
      await repo.schreibeNacht(tag: '2026-10-29', schlafMinuten: 420);
      await repo.schreibeNacht(tag: '2026-10-28', schlafMinuten: 400);

      await repo.loescheNacht('2026-10-29');

      final eintraege = await repo.lies(DataWindow.unlimited);
      expect(eintraege.map((e) => e.tag), ['2026-10-28']);
    });

    test(
      'eine leere Notiz wird zu keiner Notiz, nicht zu einer leeren',
      () async {
        await repo.schreibeNacht(
          tag: '2026-10-29',
          schlafMinuten: 420,
          notiz: '   ',
        );

        expect((await repo.lies(DataWindow.unlimited)).single.notiz, isNull);
      },
    );
  });

  // ───────────────────────────────────────────────────────────────────────
  // Tagschlaf
  // ───────────────────────────────────────────────────────────────────────

  group('Tagschlaf von Hand', () {
    late AppCache db;
    late SchlafEintragRepository repo;

    setUp(() {
      db = AppCache(NativeDatabase.memory());
      repo = SchlafEintragRepository(db);
      addTearDown(db.close);
    });

    test(
      'mehrere Nickerchen am selben Tag stehen nebeneinander und behalten '
      'ihre Reihenfolge — `tagschlaf.js` kennt den Zustand „Zwei Phasen"',
      () async {
        await repo.fuegeTagschlafHinzu(
          tag: '2026-10-29',
          schlafMinuten: 35,
          beginnMinuten: 13 * 60 + 40,
          endeMinuten: 14 * 60 + 15,
        );
        await repo.fuegeTagschlafHinzu(
          tag: '2026-10-29',
          schlafMinuten: 45,
          beginnMinuten: 18 * 60 + 10,
          endeMinuten: 18 * 60 + 55,
          notiz: 'auf der Couch',
        );

        final eintraege = await repo.lies(DataWindow.unlimited);

        expect(eintraege, hasLength(2));
        expect(eintraege.map((e) => e.art), [
          SchlafEintragArt.tagschlaf,
          SchlafEintragArt.tagschlaf,
        ]);
        expect(eintraege.map((e) => e.lfdNr), [0, 1]);
        expect(eintraege.map((e) => e.schlafMinuten), [35, 45]);
        expect(eintraege.last.notiz, 'auf der Couch');
      },
    );

    test(
      'die laufende Nummer vergibt die Ablage, und sie füllt eine Lücke '
      'nicht wieder auf — zwei Phasen mit derselben Nummer gäbe es sonst',
      () async {
        await repo.fuegeTagschlafHinzu(tag: '2026-10-29', schlafMinuten: 35);
        await repo.fuegeTagschlafHinzu(tag: '2026-10-29', schlafMinuten: 45);
        await repo.loescheTagschlaf(tag: '2026-10-29', lfdNr: 0);
        await repo.fuegeTagschlafHinzu(tag: '2026-10-29', schlafMinuten: 20);

        final eintraege = await repo.lies(DataWindow.unlimited);

        expect(eintraege.map((e) => e.lfdNr), [1, 2]);
        expect(eintraege.map((e) => e.schlafMinuten), [45, 20]);
      },
    );

    test('Nacht und Tagschlaf desselben Tages stören einander nicht — eine '
        'gelöschte Nacht nimmt kein Nickerchen mit', () async {
      await repo.schreibeNacht(tag: '2026-10-29', schlafMinuten: 420);
      await repo.fuegeTagschlafHinzu(tag: '2026-10-29', schlafMinuten: 35);

      await repo.loescheNacht('2026-10-29');

      final eintraege = await repo.lies(DataWindow.unlimited);
      expect(eintraege, hasLength(1));
      expect(eintraege.single.art, SchlafEintragArt.tagschlaf);
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // Das Fenster
  // ───────────────────────────────────────────────────────────────────────

  group('Fensterfilterung — DataWindow wird zu WHERE tag >= ? (Spec 5.6)', () {
    test('Einträge vor dem Fensterbeginn fehlen, gefiltert wird in SQL und '
        'nicht erst nach dem Laden', () async {
      final db = AppCache(NativeDatabase.memory());
      final repo = SchlafEintragRepository(db);
      addTearDown(db.close);

      await repo.schreibeNacht(tag: '2026-09-30', schlafMinuten: 400);
      await repo.schreibeNacht(tag: '2026-10-05', schlafMinuten: 410);
      await repo.fuegeTagschlafHinzu(tag: '2026-10-07', schlafMinuten: 30);

      final eintraege = await repo.lies(
        DataWindow(start: DateTime.utc(2026, 10, 1)),
      );

      expect(eintraege.map((e) => e.tag), ['2026-10-05', '2026-10-07']);
    });

    test('ohne Fenstergrenze kommt alles, aufsteigend nach Tag', () async {
      final db = AppCache(NativeDatabase.memory());
      final repo = SchlafEintragRepository(db);
      addTearDown(db.close);

      await repo.schreibeNacht(tag: '2026-10-29', schlafMinuten: 400);
      await repo.schreibeNacht(tag: '2026-10-27', schlafMinuten: 410);
      await repo.schreibeNacht(tag: '2026-10-28', schlafMinuten: 420);

      final eintraege = await repo.lies(DataWindow.unlimited);

      expect(eintraege.map((e) => e.tag), [
        '2026-10-27',
        '2026-10-28',
        '2026-10-29',
      ]);
    });

    test(
      'ein Fenster ohne Treffer liefert eine leere Liste, nicht null',
      () async {
        final db = AppCache(NativeDatabase.memory());
        final repo = SchlafEintragRepository(db);
        addTearDown(db.close);

        await repo.schreibeNacht(tag: '2026-09-30', schlafMinuten: 400);

        final eintraege = await repo.lies(
          DataWindow(start: DateTime.utc(2026, 10, 1)),
        );

        // **Hier gibt es keinen `null`-Fall wie bei `liesNaechte`.** Der
        // Cache unterscheidet „kein Cache" von „leer gelaufen", weil hinter
        // ihm ein Lauf steht, der leer ausgehen kann. Hinter dieser Tabelle
        // steht Tim. Leer heißt leer.
        expect(eintraege, isEmpty);
      },
    );
  });

  // ───────────────────────────────────────────────────────────────────────
  // Was die Ablage abweist
  // ───────────────────────────────────────────────────────────────────────

  group('Unmögliche Werte kommen gar nicht erst hinein', () {
    late AppCache db;
    late SchlafEintragRepository repo;

    setUp(() {
      db = AppCache(NativeDatabase.memory());
      repo = SchlafEintragRepository(db);
      addTearDown(db.close);
    });

    test('eine Nacht ohne Schlafminuten ist keine Nacht', () async {
      await expectLater(
        repo.schreibeNacht(tag: '2026-10-29', schlafMinuten: 0),
        throwsArgumentError,
      );
      await expectLater(
        repo.schreibeNacht(tag: '2026-10-29', schlafMinuten: -30),
        throwsArgumentError,
      );
      expect(await repo.lies(DataWindow.unlimited), isEmpty);
    });

    test('und mehr als ein Tag Schlaf auch nicht', () async {
      await expectLater(
        repo.schreibeNacht(tag: '2026-10-29', schlafMinuten: 1441),
        throwsArgumentError,
      );
    });

    test('eine halbe Zeitangabe wird abgewiesen — der Entwurf kennt „Zeiten" '
        'und „nur Dauer", nichts dazwischen', () async {
      await expectLater(
        repo.schreibeNacht(
          tag: '2026-10-29',
          schlafMinuten: 420,
          beginnMinuten: 1390,
        ),
        throwsArgumentError,
      );
      await expectLater(
        repo.schreibeNacht(
          tag: '2026-10-29',
          schlafMinuten: 420,
          endeMinuten: 375,
        ),
        throwsArgumentError,
      );
    });

    test('eine Uhrzeit liegt zwischen 00:00 und 23:59', () async {
      await expectLater(
        repo.schreibeNacht(
          tag: '2026-10-29',
          schlafMinuten: 420,
          beginnMinuten: 1440,
          endeMinuten: 375,
        ),
        throwsArgumentError,
      );
      await expectLater(
        repo.fuegeTagschlafHinzu(
          tag: '2026-10-29',
          schlafMinuten: 35,
          beginnMinuten: 820,
          endeMinuten: -1,
        ),
        throwsArgumentError,
      );
    });

    test(
      'der Tag ist ein ISO-Tagesschlüssel, kein Zeitstempel und kein '
      'freier Text — sonst vergliche `WHERE tag >= ?` Äpfel mit Birnen',
      () async {
        await expectLater(
          repo.schreibeNacht(
            tag: '2026-10-29T00:00:00.000Z',
            schlafMinuten: 420,
          ),
          throwsArgumentError,
        );
        await expectLater(
          repo.schreibeNacht(tag: '29.10.2026', schlafMinuten: 420),
          throwsArgumentError,
        );
      },
    );
  });
}
