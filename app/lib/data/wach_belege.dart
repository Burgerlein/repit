// Die eigenen Wachbelege der Tagesgrenze (#454 unter #375): `WachArt`,
// Repository und Provider. Die Tabelle selbst steht in
// `wach_beleg_tabelle.dart`.
//
// API und Vertrag sind durch `app/test/data/wach_belege_test.dart`
// verbindlich vorgegeben (siehe dessen Dateikopf, dort auch, welche Punkte
// der Test-Agent festgelegt hat) — diese Datei darf die Tests ausführen,
// aber nicht verändern (`CLAUDE.md`, „Wer Tests schreibt, schreibt nicht
// die Implementierung"). Spec:
// `docs/superpowers/specs/2026-11-10-tagesgrenze-design.md`, Abschnitte
// „Tabelle `wach_belege`" und „Repository".
//
// **Zweite Tabellengruppe (Spec 5.6a): `Messwert<T>` gilt hier nicht.** Ein
// Beleg ist etwas, das Tim in der App getan hat; leer heißt leer. Ob ein Tag
// noch läuft, rechnet der Kern (`laufenderTag`, `tagesende`), nicht diese
// Datei.
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../health/health_provider.dart';
import 'cache.dart';

/// Was Tim in der App getan hat, das ihn als wach ausweist (V13).
///
/// In der Spalte `art` steht der Name des Werts (`oeffnen`, `buchung`).
/// **Ein Wert wird nie umbenannt**: Die Tabelle wird nie geleert, und eine
/// alte Zeile mit dem früheren Namen fiele beim Lesen still heraus.
enum WachArt {
  /// Kaltstart der App und jedes `resumed`.
  oeffnen,

  /// Anlegen, Ändern oder Löschen eines Essens oder eines Glases Wasser.
  buchung;

  /// Unter welcher Quelle der Kern den Beleg führt.
  WachQuelle get quelle => switch (this) {
    WachArt.oeffnen => WachQuelle.app,
    WachArt.buchung => WachQuelle.eintrag,
  };
}

/// Lese-/Schreib-Brücke zwischen `AppCache` und den Wachbelegen — SQL hier,
/// Riverpod darunter.
///
/// **Alles in UTC.** drift legt mit `storeDateTimeAsText` einen
/// UTC-Zeitpunkt als `…Z` ab, eine Ortszeit dagegen als Wanduhr mit
/// angehängtem Versatz. Gefiltert wird in SQL als Textvergleich; mit
/// gemischten Versätzen läge in der doppelten Stunde im Oktober das zweite
/// 02:30 vor dem ersten. Deshalb gehen Zeitpunkte und Grenzen nur als UTC
/// in die Datenbank.
class WachbelegRepository {
  WachbelegRepository(this._db);

  final AppCache _db;

  /// Legt einen Beleg der Art [art] zum Zeitpunkt [zeitpunkt] ab, als UTC.
  /// Jeder Aufruf ist eine eigene Zeile; nichts wird ersetzt (V13).
  Future<void> merke(WachArt art, DateTime zeitpunkt) => _db
      .into(_db.wachBelege)
      .insert(
        WachBelegeCompanion.insert(zeitpunkt: zeitpunkt.toUtc(), art: art.name),
      );

  /// Die Belege von [von] bis [bis], **beide Grenzen einschließlich**,
  /// zeitlich aufsteigend, Zeitpunkte als UTC. Gefiltert in SQL.
  ///
  /// Eine Zeile mit unbekannter `art` wird übergangen: Sie stammt von einem
  /// anderen Zweig unter derselben Bundle-ID oder aus einer späteren
  /// Fassung, und eine geratene Quelle behauptete einen Beleg, den diese
  /// Fassung nicht kennt.
  Future<List<Wachbeleg>> zwischen(DateTime von, DateTime bis) async {
    final zeilen =
        await (_db.select(_db.wachBelege)
              ..where(
                (t) => t.zeitpunkt.isBetweenValues(von.toUtc(), bis.toUtc()),
              )
              ..orderBy([
                (t) => OrderingTerm.asc(t.zeitpunkt),
                (t) => OrderingTerm.asc(t.id),
              ]))
            .get();
    final arten = WachArt.values.asNameMap();
    return [
      for (final zeile in zeilen)
        if (arten[zeile.art] case final art?)
          Wachbeleg(von: zeile.zeitpunkt.toUtc(), quelle: art.quelle),
    ];
  }
}

/// Das Repository über den drift-Cache aus [appCacheProvider].
final wachbelegRepositoryProvider = Provider<WachbelegRepository>(
  (ref) => WachbelegRepository(ref.watch(appCacheProvider)),
);
