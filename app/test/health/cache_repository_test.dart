// `drift` exportiert eigene Spaltenausdrücke `isNull`/`isNotNull` (für `IS
// NULL`/`IS NOT NULL` in Abfragen) — das kollidiert mit den gleichnamigen
// `package:matcher`-Matchern, die `expect(..., isNull)`/`expect(...,
// isNotNull)` unten brauchen. Siehe `test/data/migration_test.dart`,
// Zeile 1-4, derselbe Grund (dort nur `isNull`, weil `isNotNull` dort nicht
// gebraucht wird).
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/data/cache_repository.dart';
import 'package:repit/health/health_types.dart';

/// Tests für `CacheRepository` (Task 13) — die Lese-/Schreib-Brücke zwischen
/// `AppCache` (drift, Task 6) und `DailyMetrics` (Task 12), die
/// `health_provider.dart` für die Ladereihenfolge aus Spec 5.5 braucht:
/// „`build()` liest zuerst den drift-Cache ... und schreibt das Ergebnis
/// zurück." Diese Datei prüft **nur** diese Brücke, isoliert von Riverpod —
/// die Verdrahtung in einen Provider steht in `health_provider_test.dart`.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// `lib/data/cache_repository.dart` existiert noch nicht; diese Datei legt
/// die API fest, gegen die der Implementierende baut, und darf von ihm
/// ausgeführt, aber nicht verändert werden.
///
/// **API, die diese Tests verbindlich vorgeben:**
///
/// ```dart
/// class CacheRepository {
///   CacheRepository(AppCache db);
///
///   /// `null`, wenn es im Fenster keine einzige Cache-Zeile gibt — "kein
///   /// Cache" ist ein eigener Zustand (Spec 5.3d), keine leere Liste mit
///   /// einem erfundenen Stand.
///   Future<({List<DailyMetrics> werte, DateTime stand})?> liesTagesWerte(
///     DataWindow fenster,
///   );
///
///   /// Schreibt einen Lauf zurück. `gelesenAm` gilt für **alle** Zeilen
///   /// dieses Aufrufs gleich — ein Lauf hat einen Zeitpunkt (Spec 5.3b:
///   /// der Stand ist je Zeile unterschiedlich *zwischen Läufen*, nicht
///   /// *innerhalb* eines Laufs).
///   Future<void> schreibeTagesWerte(
///     List<DailyMetrics> werte, {
///     required DateTime gelesenAm,
///   });
/// }
/// ```
///
/// **Wichtige, in Task 6 bereits festgelegte Einschränkung, die diese Tests
/// bewusst respektieren statt zu umgehen:** `TagesWerte`
/// (`lib/data/tables.dart`, von dieser Datei nicht verändert) kennt nur zwei
/// Messwertspalten — `schritte` und `ruhepulsBpm` — nicht alle 13 Felder von
/// `DailyMetrics`. Ein `CacheRepository`, das versucht, z. B. `weightKg`
/// zurückzulesen, kann das mit dem bestehenden Schema nicht leisten. Diese
/// Tests prüfen deshalb nur `steps`/`restingHR` inhaltlich und einen
/// eigenen Test dafür, dass die übrigen Felder bewusst `null` bleiben (siehe
/// Gruppe weiter unten) — das ist eine geerbte Schemagrenze aus Task 6,
/// keine Lücke, die dieser Task schließen soll.
///
/// **Nachtrag vom 31.10.2026 — die Grenze schrumpft zum zweiten Mal, und
/// der Absatz darüber beschreibt sie nicht mehr richtig.** Zu `schritte`
/// und `ruhepulsBpm` sind `hrv_ms`, `resp_rate` und `recovery_hr_drop`
/// gekommen (Schema v3, #113, geprüft in `test/data/schema_v3_test.dart`);
/// `gewicht_kg` und `trainings_minuten` kommen mit #194 dazu (Schema v6,
/// verlangt in `test/data/schema_v6_test.dart`, das bis zur Umsetzung rot
/// ist). `weightKg` ist damit **kein** Beispiel für die Grenze mehr,
/// sondern eines für ihre Aufhebung — der Fall unten ist deshalb auf
/// `vo2max` gewandert.
///
/// Es bleiben sechs Felder ohne eigene Spalte: `activeKcal`, `basalKcal`,
/// `vo2max`, `bodyFatPct`, `leanKg` und `standHours`. Für sie gilt der
/// Absatz darüber unverändert — sie kommen aus dem Cache weiterhin immer
/// `null` zurück, und das ist eine Schemagrenze, kein Fehler dieser Brücke.
/// Die Grenze wird kleiner, nicht aufgehoben. Die beiden Fälle unten gelten
/// **vor und nach** #194 unverändert; sie sind grün, solange niemand eines
/// dieser sechs Felder anfasst.
///
/// **Nachtrag vom 02.11.2026 — die Grenze schrumpft zum dritten Mal, und
/// zwei der sechs sind weg.** #202 legt `bodyFatPct` und `leanKg` ab
/// (Schema v7, als `koerperfett_pct` und `fettfrei_kg`, verlangt in
/// `test/data/schema_v7_test.dart`, das bis zur Umsetzung rot ist). Sie
/// kommen danach mit ihrem Wert aus dem Cache zurück — „weiterhin immer
/// `null`" gilt für sie nicht mehr, und ein Fall, der es behauptete,
/// prüfte keine Grenze mehr, sondern hielte eine überholte Erwartung fest.
/// Beide sind deshalb aus dem Fall unten genommen.
///
/// Es bleiben **vier** Felder ohne eigene Spalte: `activeKcal`,
/// `basalKcal`, `vo2max` und `standHours`. Für sie gilt der Absatz darüber
/// unverändert. Die Änderung kommt vom Test-Agenten des #202, nicht von
/// dem, der die Implementierung schreibt — der darf eine bestehende
/// Erwartung nicht passend machen (`CLAUDE.md`, Rollentrennung). Tim hat
/// sie nicht gesehen.
///
/// **Nachtrag vom 18.11.2026 — die Grenze schrumpft zum vierten Mal.**
/// #95 (mit #16) legt `vo2max` ab (Schema v26, als Spalte `vo2max`,
/// verlangt in `test/data/schema_v26_test.dart`, das bis zur Umsetzung
/// rot ist; die Stufe hieß bis zum Zusammenführen am 24.11.2026 die 25
/// und ist um eins nach oben gerückt, weil `main` die 25 inzwischen an
/// #532 vergeben hatte — #485). Der Beispiel-Fall unten ist deshalb von `vo2max` auf
/// `activeKcal` gewandert — derselbe Vorgang wie am 31.10. bei `weightKg`
/// und am 02.11. bei `bodyFatPct`/`leanKg`. Es bleiben **drei** Felder
/// ohne eigene Spalte: `activeKcal`, `basalKcal` und `standHours`.
/// Nachgezogen vom Test-Agenten des #95 (`TEST_AENDERN=1`); **Tim hat die
/// Änderung nicht gesehen.**
///
/// **Was absichtlich nicht geprüft wird:** Wie `stand` aggregiert wird, wenn
/// Zeilen im selben Fenster aus **verschiedenen** Läufen mit
/// unterschiedlichem `gelesenAm` stammen (z. B. nach einem nur teilweise
/// erfolgreichen Nachlauf). Jeder Test unten schreibt ein Fenster in einem
/// einzigen `schreibeTagesWerte`-Aufruf, also mit genau einem gemeinsamen
/// `gelesenAm` — der einzige Fall, den Spec 5.5/5.3b tatsächlich vorsieht
/// ("ein Lauf hat einen Zeitpunkt"). Eine Aggregationsregel für gemischte
/// Zeitstempel hier festzunageln würde eine Entscheidung erfinden, die die
/// Spec nicht trifft.
void main() {
  group(
    'Kein Cache ist ein eigener Zustand, keine leere Liste (Spec 5.3d)',
    () {
      test(
        'ein frischer, leerer Cache liefert null, nicht eine leere Liste '
        'mit einem erfundenen Stand',
        () async {
          final db = AppCache(NativeDatabase.memory());
          addTearDown(db.close);
          final repo = CacheRepository(db);

          final ergebnis = await repo.liesTagesWerte(DataWindow.unlimited);

          expect(
            ergebnis,
            isNull,
            reason:
                'ein Messwert-Provider muss zwischen "noch nie gelesen" '
                '(kein Cache) und "gelesen, nichts da" unterscheiden können '
                '— das kann er nur, wenn diese Brücke "kein Cache" nicht '
                'als Bekannt([]) vortäuscht',
          );
        },
      );
    },
  );

  group('Schreiben und Wiederlesen eines Laufs', () {
    test(
      'ein geschriebener Lauf kommt mit denselben Werten und dem '
      'gemeinsamen Stand zurück, aufsteigend nach Tag sortiert',
      () async {
        final db = AppCache(NativeDatabase.memory());
        addTearDown(db.close);
        final repo = CacheRepository(db);
        final geholt = DateTime.utc(2026, 10, 20, 14, 32);

        // Absichtlich unsortiert geschrieben — die Brücke muss selbst
        // sortieren, nicht sich auf die Schreibreihenfolge verlassen
        // (dieselbe Erwartung wie migration_test.dart, Gruppe
        // "Reihenfolge", hier eine Ebene höher).
        await repo.schreibeTagesWerte(const [
          DailyMetrics(tag: '2026-10-21', steps: 9000, restingHR: 50),
          DailyMetrics(tag: '2026-10-19', steps: 7000, restingHR: 52),
          DailyMetrics(tag: '2026-10-20', steps: 8000, restingHR: 51),
        ], gelesenAm: geholt);

        final ergebnis = await repo.liesTagesWerte(DataWindow.unlimited);

        expect(ergebnis, isNotNull);
        expect(
          ergebnis!.werte.map((w) => w.tag).toList(),
          ['2026-10-19', '2026-10-20', '2026-10-21'],
        );
        expect(ergebnis.werte.map((w) => w.steps).toList(), [7000, 8000, 9000]);
        expect(
          ergebnis.werte.map((w) => w.restingHR).toList(),
          [52, 51, 50],
        );
        expect(
          ergebnis.stand,
          geholt,
          reason:
              'alle drei Zeilen stammen aus demselben Aufruf, tragen also '
              'denselben "gelesenAm" — der Stand des gelesenen Fensters ist '
              'in diesem (einzigen von der Spec vorgesehenen) Fall '
              'eindeutig, keine Aggregation nötig',
        );
      },
    );

    test(
      'ein nicht gelieferter Messwert bleibt null, kommt nicht als 0 '
      'zurück — derselbe Vertrag wie bei TagesWerte direkt '
      '(migration_test.dart), hier auf Ebene von DailyMetrics geprüft',
      () async {
        final db = AppCache(NativeDatabase.memory());
        addTearDown(db.close);
        final repo = CacheRepository(db);

        await repo.schreibeTagesWerte(const [
          DailyMetrics(tag: '2026-10-20', steps: 4000),
          // restingHR absichtlich nicht gesetzt.
        ], gelesenAm: DateTime.utc(2026, 10, 20, 9));

        final ergebnis = await repo.liesTagesWerte(DataWindow.unlimited);
        final zeile = ergebnis!.werte.single;
        expect(zeile.steps, 4000);
        expect(zeile.restingHR, isNull, reason: 'kein Messwert ist nicht 0 bpm');
      },
    );
  });

  group('Fensterfilterung — DataWindow.clip wird zu WHERE tag >= ? (Spec 5.6)', () {
    test(
      'Tage vor dem Fensterbeginn fehlen im Ergebnis, auch wenn sie im '
      'Cache stehen',
      () async {
        final db = AppCache(NativeDatabase.memory());
        addTearDown(db.close);
        final repo = CacheRepository(db);

        // Der alte Tag trägt einen deutlich älteren Stand als die
        // eingeschlossenen Tage — das macht die nächste Prüfung
        // aussagekräftig: Würde die Filterung erst *nach* der
        // Stand-Berechnung greifen, läse man hier fälschlich den älteren
        // Stand mit heraus.
        await repo.schreibeTagesWerte(const [
          DailyMetrics(tag: '2026-09-30', steps: 1000),
        ], gelesenAm: DateTime.utc(2026, 9, 30, 8));
        await repo.schreibeTagesWerte(const [
          DailyMetrics(tag: '2026-10-01', steps: 2000),
          DailyMetrics(tag: '2026-10-02', steps: 3000),
        ], gelesenAm: DateTime.utc(2026, 10, 2, 9));

        final ergebnis = await repo.liesTagesWerte(
          DataWindow(start: DateTime.utc(2026, 10, 1)),
        );

        expect(ergebnis, isNotNull);
        expect(
          ergebnis!.werte.map((w) => w.tag).toSet(),
          {'2026-10-01', '2026-10-02'},
          reason: 'der 30.09. liegt vor dem Fensterbeginn und darf nicht '
              'mitkommen',
        );
        expect(
          ergebnis.stand,
          DateTime.utc(2026, 10, 2, 9),
          reason: 'der Stand gehört zu den tatsächlich zurückgegebenen '
              'Zeilen, nicht zur ältesten Zeile im ganzen Cache',
        );
      },
    );

    test(
      'ein Fenster, das keine einzige vorhandene Zeile trifft, liefert '
      'null wie ein leerer Cache — nicht Bekannt([])',
      () async {
        final db = AppCache(NativeDatabase.memory());
        addTearDown(db.close);
        final repo = CacheRepository(db);

        await repo.schreibeTagesWerte(const [
          DailyMetrics(tag: '2026-09-01', steps: 1000),
        ], gelesenAm: DateTime.utc(2026, 9, 1));

        final ergebnis = await repo.liesTagesWerte(
          DataWindow(start: DateTime.utc(2026, 10, 1)),
        );

        expect(ergebnis, isNull);
      },
    );
  });

  group('Ein zweiter Lauf auf denselben Tag überschreibt, verdoppelt nicht', () {
    test(
      'schreibeTagesWerte zweimal auf denselben Tag hinterlässt eine '
      'Zeile mit dem neuesten Wert und dem neuesten Stand',
      () async {
        final db = AppCache(NativeDatabase.memory());
        addTearDown(db.close);
        final repo = CacheRepository(db);

        await repo.schreibeTagesWerte(const [
          DailyMetrics(tag: '2026-10-20', steps: 1000),
        ], gelesenAm: DateTime.utc(2026, 10, 20, 9));
        await repo.schreibeTagesWerte(const [
          DailyMetrics(tag: '2026-10-20', steps: 9000),
        ], gelesenAm: DateTime.utc(2026, 10, 20, 18));

        final ergebnis = await repo.liesTagesWerte(DataWindow.unlimited);
        expect(ergebnis!.werte, hasLength(1));
        expect(ergebnis.werte.single.steps, 9000);
        expect(ergebnis.stand, DateTime.utc(2026, 10, 20, 18));
      },
    );
  });

  group(
    'Geerbte Schemagrenze aus Task 6 (nicht Gegenstand dieses Tasks)',
    () {
      test(
        'Felder ohne eigene Spalte (z. B. activeKcal) kommen aus dem Cache '
        'immer als null zurück, auch wenn sie beim Schreiben gesetzt waren',
        () async {
          final db = AppCache(NativeDatabase.memory());
          addTearDown(db.close);
          final repo = CacheRepository(db);

          await repo.schreibeTagesWerte(const [
            DailyMetrics(tag: '2026-10-20', steps: 4000, activeKcal: 620),
          ], gelesenAm: DateTime.utc(2026, 10, 20));

          final zeile =
              (await repo.liesTagesWerte(DataWindow.unlimited))!.werte.single;
          expect(zeile.steps, 4000);
          expect(
            zeile.activeKcal,
            isNull,
            reason:
                '`TagesWerte` hat keine Spalte für activeKcal — das ist '
                'eine bestehende Schemagrenze, kein Fehler dieser Brücke. '
                'Ein Test, der hier einen Wert erwartete, würde eine falsche '
                'Erwartung festschreiben. Der Fall stand bis zum 31.10.2026 '
                'auf `weightKg` (abgeräumt von #194, Schema v6) und bis zum '
                '18.11.2026 auf `vo2max` (abgeräumt von #95, Schema v26, '
                'siehe `test/data/schema_v26_test.dart`); er ist deshalb '
                'wieder auf ein Feld gewandert, das weiterhin keine Spalte '
                'hat — gelöscht wird er nicht, die Grenze wird nur kleiner',
          );
        },
      );

      // `bodyFatPct` und `leanKg` standen bis zum 02.11.2026 mit in dieser
      // Liste. #202 legt sie ab (Schema v7, `koerperfett_pct` und
      // `fettfrei_kg`, siehe `test/data/schema_v7_test.dart`); sie kommen
      // danach mit ihrem Wert zurück, und eine Erwartung auf `null` wäre
      // hier falsch geworden. Herausgenommen vom Test-Agenten des #202 —
      // derselbe Vorgang wie am 31.10. bei `weightKg`: Die Grenze wird
      // kleiner, der Fall bleibt stehen.
      test(
        'und das gilt für alle drei verbliebenen Felder, nicht nur für '
        'eines',
        () async {
          final db = AppCache(NativeDatabase.memory());
          addTearDown(db.close);
          final repo = CacheRepository(db);

          await repo.schreibeTagesWerte(const [
            DailyMetrics(
              tag: '2026-10-20',
              steps: 4000,
              activeKcal: 620,
              basalKcal: 1680,
              // `bodyFatPct` und `leanKg` stehen hier seit #202 nicht
              // mehr: Sie haben seit Schema v7 eine Spalte und kommen mit
              // ihrem Wert zurück. Dass das stimmt, prüft
              // `test/data/schema_v7_test.dart` — hier wären sie nur noch
              // eine Erwartung, die der Code zu Recht verletzt. `vo2max`
              // steht seit #95 (Schema v26) aus demselben Grund nicht mehr
              // hier — geprüft in `test/data/schema_v26_test.dart`.
              standHours: 11,
            ),
          ], gelesenAm: DateTime.utc(2026, 10, 20));

          final zeile =
              (await repo.liesTagesWerte(DataWindow.unlimited))!.werte.single;
          expect(zeile.steps, 4000);
          expect(zeile.activeKcal, isNull);
          expect(zeile.basalKcal, isNull);
          expect(
            zeile.standHours,
            isNull,
            reason:
                'die vollständige Liste der Felder, für die die Grenze noch '
                'gilt — sie hier einmal aufzuschreiben macht sichtbar, wenn '
                'das nächste Ticket eines davon abräumt. #202 hat das mit '
                '`bodyFatPct`/`leanKg` getan, #95 mit `vo2max`; drei sind '
                'übrig',
          );
        },
      );
    },
  );
}
