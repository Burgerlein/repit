// `drift`s eigene Spaltenausdrücke `isNull`/`isNotNull` verdecken sonst die
// gleichnamigen `package:matcher`-Matcher — dieselbe Begründung wie in
// `test/health/cache_repository_test.dart`, Zeile 1–7.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/data/cache_repository.dart';
import 'package:repit/health/health_types.dart';

/// Tests für den **Schlaf-Cache** (#113, Teil 1 von zwei: hier die Ablage,
/// in `test/health/sleep_provider_test.dart` der Provider darüber).
///
/// **Was dieses Ticket zu entscheiden hat, und wie hier entschieden wird.**
/// `lib/health/health_provider.dart` sagt im Kopfkommentar ausdrücklich,
/// warum es keinen `sleepProvider` gibt: „Für Schlaf legt die Umbau-Spec
/// weder Cache-Tabelle noch Ladereihenfolge fest. Wer ihn anlegt,
/// entscheidet beides." Diese Datei entscheidet die **Cache-Tabelle**.
///
/// ### Entscheidung: zwei Tabellen, eine Zeile je Abschnitt
///
/// ```dart
/// @DataClassName('NachtRow')
/// class Naechte extends Table {
///   /// ISO-Tagesschlüssel des **Aufwachtags** (`BerlinCalendar.dayKey`),
///   /// derselbe Schlüsseltyp wie in `TagesWerte` — damit wird aus
///   /// `DataWindow.clip(...)` auch hier ein `WHERE tag >= ?` (Spec 5.6).
///   TextColumn get tag => text()();
///   DateTimeColumn get gelesenAm => dateTime().named('gelesen_am').nullable()();
///   @override Set<Column> get primaryKey => {tag};
/// }
///
/// @DataClassName('SchlafAbschnittRow')
/// class SchlafAbschnitte extends Table {
///   TextColumn get tag => text()();
///   /// 0 = Hauptnacht, 1..n = n-tes Nickerchen desselben Tages.
///   /// **Kein nullbarer Schlüsselteil:** SQLite lässt NULL in einem
///   /// Primärschlüssel zu und behandelt zwei NULLs als verschieden — ein
///   /// `INSERT OR REPLACE` würde Abschnitte dann verdoppeln statt zu
///   /// ersetzen.
///   IntColumn get quelle => integer()();
///   IntColumn get lfdNr => integer().named('lfd_nr')();
///   TextColumn get phase => text()();          // `SleepStage.name`
///   DateTimeColumn get beginn => dateTime()();
///   DateTimeColumn get ende => dateTime()();
///   @override Set<Column> get primaryKey => {tag, quelle, lfdNr};
/// }
/// ```
///
/// **Warum normalisiert und nicht ein JSON-Klumpen in einer Spalte:** Eine
/// Nacht als Text in einer Zelle bräuchte einen eigenen Codec mit eigenen
/// Tests, wäre mit keiner Abfrage zu erreichen und bei der nächsten
/// Schemaänderung nicht migrierbar, sondern nur noch zu verwerfen. Die
/// Größenordnung spricht nicht dagegen: 30 Nächte zu je ~30 Abschnitten sind
/// ~900 Zeilen, und Spec 5.6 hält Lesegeschwindigkeit ausdrücklich für kein
/// Auswahlkriterium. Der Test „je Abschnitt eine eigene Zeile" unten hält
/// diese Entscheidung fest, damit sie nicht beim Bauen stillschweigend
/// umgedreht wird.
///
/// **Warum `gelesenAm` auf der Nacht und nicht auf dem Abschnitt:** Ein Lauf
/// hat einen Zeitpunkt (Spec 5.3b), und die Nacht ist die Einheit, die der
/// Kanal liefert. Ein Abschnitt ohne seine Nacht gibt es nicht.
///
/// ### API, die diese Tests verbindlich vorgeben
///
/// In `lib/data/cache_repository.dart`, zusätzlich zu den beiden
/// bestehenden Methoden — **dieselbe Klasse, nicht eine zweite**: Es ist
/// dieselbe Brücke zwischen `AppCache` und den Health-Typen, und sie hängt
/// schon am `cacheRepositoryProvider`.
///
/// ```dart
/// /// `null`, wenn im Fenster keine einzige Nacht liegt — „kein Cache" ist
/// /// ein eigener Zustand (Spec 5.3d), keine leere Liste mit erfundenem
/// /// Stand. Nächte kommen aufsteigend nach Tag.
/// Future<({List<SleepNight> werte, DateTime stand})?> liesNaechte(
///   DataWindow fenster,
/// );
///
/// /// Schreibt einen Lauf zurück; `gelesenAm` gilt für alle Nächte dieses
/// /// Aufrufs gleich. Eine erneut geschriebene Nacht **ersetzt** ihre
/// /// Abschnitte.
/// Future<void> schreibeNaechte(
///   List<SleepNight> naechte, {
///   required DateTime gelesenAm,
/// });
/// ```
///
/// ### Was absichtlich nicht geprüft wird
///
/// - **Gruppierung von Abschnitten zu Nächten.** Der Kanal liefert bereits
///   gruppierte Nächte (`health_types.dart`, Klassenkommentar zu
///   `SleepSession`); `SleepGrouping` wird nicht nach Dart portiert. Der
///   Cache speichert und liefert, was er bekommen hat.
/// - **Gemischte Stände innerhalb eines Fensters** — dieselbe bewusste
///   Lücke wie bei `liesTagesWerte`, siehe `cache_repository_test.dart`.
void main() {
  // Erfundene Zahlen, wie in jedem Test dieses Projekts: kein einziger Wert
  // stammt aus echten Gesundheitsdaten.
  final standVormittags = DateTime.utc(2026, 10, 20, 9, 0);

  DateTime tagesbeginn(int jahr, int monat, int tag) =>
      BerlinCalendar.startOfDay(DateTime.utc(jahr, monat, tag, 12));

  SleepSegment abschnitt(
    SleepStage phase,
    DateTime beginn,
    Duration dauer,
  ) => SleepSegment(stage: phase, start: beginn, end: beginn.add(dauer));

  /// Eine erfundene Nacht zum 20.10.2026: eingeschlafen um 20:10 UTC,
  /// dreimal die Phase gewechselt.
  SleepNight nachtZum20() => SleepNight(
    date: tagesbeginn(2026, 10, 20),
    session: SleepSession(
      segments: [
        abschnitt(
          SleepStage.core,
          DateTime.utc(2026, 10, 19, 20, 10),
          const Duration(hours: 2),
        ),
        abschnitt(
          SleepStage.deep,
          DateTime.utc(2026, 10, 19, 22, 10),
          const Duration(minutes: 50),
        ),
        abschnitt(
          SleepStage.rem,
          DateTime.utc(2026, 10, 19, 23, 0),
          const Duration(minutes: 40),
        ),
      ],
    ),
  );

  group('Kein Cache ist ein eigener Zustand (Spec 5.3d)', () {
    test(
      'ein frischer Cache liefert null, nicht eine leere Liste mit '
      'erfundenem Stand',
      () async {
        final db = AppCache(NativeDatabase.memory());
        addTearDown(db.close);

        expect(
          await CacheRepository(db).liesNaechte(DataWindow.unlimited),
          isNull,
        );
      },
    );

    test(
      'eine Nacht ohne bekannten Stand gilt ebenfalls als kein Cache — '
      'kein Bekannt mit DateTime.now() als Attrappe',
      () async {
        final db = AppCache(NativeDatabase.memory());
        addTearDown(db.close);

        // Eine Zeile ohne `gelesen_am`, wie sie nach einer künftigen
        // Migration entstehen könnte. Derselbe Vertrag wie bei
        // `liesTagesWerte` (`cache_repository.dart`): ein `Bekannt` ohne
        // ehrlichen Stand wäre eine erfundene Zahl.
        await db
            .into(db.naechte)
            .insert(const NaechteCompanion(tag: Value('2026-10-20')));

        expect(
          await CacheRepository(db).liesNaechte(DataWindow.unlimited),
          isNull,
        );
      },
    );
  });

  group('Schreiben und Wiederlesen einer Nacht', () {
    test(
      'die Nacht kommt mit Tag, Phasen und Zeiten unverändert zurück, '
      'dazu der gemeinsame Stand',
      () async {
        final db = AppCache(NativeDatabase.memory());
        addTearDown(db.close);
        final repo = CacheRepository(db);
        final original = nachtZum20();

        await repo.schreibeNaechte([original], gelesenAm: standVormittags);

        final ergebnis = await repo.liesNaechte(DataWindow.unlimited);
        expect(ergebnis, isNotNull);
        expect(ergebnis!.stand, standVormittags);

        final zurueck = ergebnis.werte.single;
        expect(
          zurueck.date,
          original.date,
          reason:
              'der Aufwachtag wird aus dem ISO-Schlüssel wieder zu einem '
              'Berliner Tagesbeginn — dieselbe Rechnung wie in '
              'health_types.dart, nicht DateTime.parse auf gut Glück',
        );
        expect(
          zurueck.session.segments.map((a) => a.stage).toList(),
          [SleepStage.core, SleepStage.deep, SleepStage.rem],
          reason: 'Phasen und ihre Reihenfolge überleben den Rundweg',
        );
        expect(
          zurueck.session.segments.map((a) => a.start).toList(),
          original.session.segments.map((a) => a.start).toList(),
        );
        expect(
          zurueck.session.segments.map((a) => a.end).toList(),
          original.session.segments.map((a) => a.end).toList(),
        );
      },
    );

    test(
      'je Abschnitt entsteht eine eigene Zeile — die Nacht liegt nicht als '
      'Textklumpen in einer einzigen Spalte (Entscheidung im Dateikopf)',
      () async {
        final db = AppCache(NativeDatabase.memory());
        addTearDown(db.close);

        await CacheRepository(
          db,
        ).schreibeNaechte([nachtZum20()], gelesenAm: standVormittags);

        expect(await db.select(db.naechte).get(), hasLength(1));
        expect(
          await db.select(db.schlafAbschnitte).get(),
          hasLength(3),
          reason:
              'drei Abschnitte, drei Zeilen. Eine einzige Zeile hieße, die '
              'Nacht steckt als JSON in einer Spalte — unabfragbar und bei '
              'der nächsten Schemaänderung nur noch zu verwerfen',
        );
      },
    );

    test(
      'ein zweiter Lauf auf dieselbe Nacht ersetzt ihre Abschnitte, statt '
      'sie zu verdoppeln',
      () async {
        final db = AppCache(NativeDatabase.memory());
        addTearDown(db.close);
        final repo = CacheRepository(db);

        await repo.schreibeNaechte([nachtZum20()], gelesenAm: standVormittags);

        // Derselbe Aufwachtag, aber Apple Health hat die Nacht inzwischen
        // anders zugeschnitten: nur noch ein Abschnitt. Würden die alten
        // Zeilen stehen bleiben, läse der Schirm eine Nacht, die es nie
        // gab — zusammengesetzt aus zwei Läufen.
        final korrigiert = SleepNight(
          date: tagesbeginn(2026, 10, 20),
          session: SleepSession(
            segments: [
              abschnitt(
                SleepStage.core,
                DateTime.utc(2026, 10, 19, 21, 0),
                const Duration(hours: 7),
              ),
            ],
          ),
        );
        await repo.schreibeNaechte(
          [korrigiert],
          gelesenAm: DateTime.utc(2026, 10, 20, 18, 0),
        );

        final ergebnis = await repo.liesNaechte(DataWindow.unlimited);
        expect(ergebnis!.werte, hasLength(1));
        expect(
          ergebnis.werte.single.session.segments,
          hasLength(1),
          reason: 'die drei alten Abschnitte sind weg, nicht dazu',
        );
        expect(
          ergebnis.werte.single.session.segments.single.end,
          DateTime.utc(2026, 10, 20, 4, 0),
        );
        expect(ergebnis.stand, DateTime.utc(2026, 10, 20, 18, 0));
        expect(
          await db.select(db.schlafAbschnitte).get(),
          hasLength(1),
          reason: 'auch in der Tabelle selbst bleibt nichts liegen',
        );
      },
    );

    test(
      'Nickerchen bleiben von der Hauptnacht getrennt und behalten ihre '
      'Reihenfolge',
      () async {
        final db = AppCache(NativeDatabase.memory());
        addTearDown(db.close);
        final repo = CacheRepository(db);

        final mitTagschlaf = SleepNight(
          date: tagesbeginn(2026, 10, 20),
          session: nachtZum20().session,
          naps: [
            SleepSession(
              segments: [
                abschnitt(
                  SleepStage.core,
                  DateTime.utc(2026, 10, 20, 11, 30),
                  const Duration(minutes: 25),
                ),
              ],
            ),
            SleepSession(
              segments: [
                abschnitt(
                  SleepStage.unspecified,
                  DateTime.utc(2026, 10, 20, 15, 0),
                  const Duration(minutes: 15),
                ),
              ],
            ),
          ],
        );

        await repo.schreibeNaechte([mitTagschlaf], gelesenAm: standVormittags);

        final zurueck =
            (await repo.liesNaechte(DataWindow.unlimited))!.werte.single;

        expect(
          zurueck.session.segments,
          hasLength(3),
          reason:
              'die Hauptnacht hat genau ihre drei Abschnitte — kein '
              'Nickerchen ist hineingerutscht. SPEC 4.6 zählt Tagschlaf '
              'nicht zur Nacht',
        );
        expect(zurueck.naps, hasLength(2));
        expect(
          zurueck.naps.first.segments.single.start,
          DateTime.utc(2026, 10, 20, 11, 30),
        );
        expect(
          zurueck.naps.last.segments.single.stage,
          SleepStage.unspecified,
        );
      },
    );
  });

  group('Fensterfilterung — DataWindow wird zu WHERE tag >= ? (Spec 5.6)', () {
    test(
      'Nächte vor dem Fensterbeginn fehlen, und der Stand gehört zu den '
      'tatsächlich zurückgegebenen Nächten',
      () async {
        final db = AppCache(NativeDatabase.memory());
        addTearDown(db.close);
        final repo = CacheRepository(db);

        SleepNight schlichteNacht(int monat, int tag) => SleepNight(
          date: tagesbeginn(2026, monat, tag),
          session: SleepSession(
            segments: [
              abschnitt(
                SleepStage.core,
                DateTime.utc(2026, monat, tag - 1, 21, 0),
                const Duration(hours: 7),
              ),
            ],
          ),
        );

        await repo.schreibeNaechte([
          schlichteNacht(9, 30),
        ], gelesenAm: DateTime.utc(2026, 9, 30, 8));
        await repo.schreibeNaechte([
          schlichteNacht(10, 2),
          schlichteNacht(10, 3),
        ], gelesenAm: DateTime.utc(2026, 10, 3, 9));

        final ergebnis = await repo.liesNaechte(
          DataWindow(start: DateTime.utc(2026, 10, 1)),
        );

        expect(
          ergebnis!.werte.map((n) => BerlinCalendar.dayKey(n.date)).toList(),
          ['2026-10-02', '2026-10-03'],
          reason:
              'der 30.09. liegt vor dem Fensterbeginn — und die Reihenfolge '
              'ist aufsteigend, unabhängig von der Schreibreihenfolge',
        );
        expect(
          ergebnis.stand,
          DateTime.utc(2026, 10, 3, 9),
          reason:
              'nicht der ältere Stand der herausgefilterten Nacht — sonst '
              'behauptete die Standzeile einen Lauf, dessen Daten gar nicht '
              'auf dem Schirm stehen',
        );
      },
    );

    test(
      'ein Fenster, das keine einzige vorhandene Nacht trifft, liefert '
      'null wie ein leerer Cache — nicht Bekannt([])',
      () async {
        final db = AppCache(NativeDatabase.memory());
        addTearDown(db.close);
        final repo = CacheRepository(db);

        await repo.schreibeNaechte([
          nachtZum20(),
        ], gelesenAm: standVormittags);

        expect(
          await repo.liesNaechte(DataWindow(start: DateTime.utc(2026, 11, 1))),
          isNull,
        );
      },
    );
  });
}
