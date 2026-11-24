// Die Historie des festen Kalorienziels (Schema v18, #410). Form und Namen
// gibt `app/test/data/schema_v19_test.dart` verbindlich vor (siehe
// Dateikopf dort) — diese Datei darf den Test ausführen, aber nicht
// verändern (`CLAUDE.md`, „Wer Tests schreibt, schreibt nicht die
// Implementierung").
//
// **Die Tabelle steht in einer eigenen Datei, nicht in
// `kalorienziele.dart`**, aus demselben Grund wie bei `wasser_tabellen.dart`
// und `Stammdaten` in `tables.dart`: `cache.dart` muss sie importieren, und
// `kalorienziele.dart` importiert `cache.dart`. Beides in einer Datei wäre
// ein Ringimport, den sonst keine Ablage hat.
//
// **Zweite Tabellengruppe (Spec 5.6a): `Messwert<T>` gilt hier nicht.**
// Ein festgelegtes Ziel ist Tims eigene Angabe (oder eine einmal für ihn
// gerechnete Zahl); leer heißt leer.
import 'package:drift/drift.dart';

/// Ein festgelegtes Kalorienziel — gilt ab [abTag] bis zur nächsten Zeile.
@DataClassName('KalorienzielRow')
class Kalorienziele extends Table {
  /// Der Tag, ab dem das Ziel gilt, als ISO-Tagesschlüssel. **Der
  /// Primärschlüssel**: Je Tag gilt höchstens ein Ziel (Festlegung des
  /// Test-Agenten, nicht von Tim). `ab_tag <= ?` vergleicht lexikografisch
  /// richtig.
  TextColumn get abTag => text().named('ab_tag')();

  /// Das Ziel in kcal. `REAL`, denn die gerechnete Zahl hat Nachkommastellen,
  /// und Runden wäre eine stille Änderung.
  RealColumn get kcal => real()();

  /// `berechnet` oder `hand` (später `coach`). **Ohne Vorgabewert** — ein
  /// Vorgabewert behauptete eine Herkunft, die niemand festgehalten hat.
  TextColumn get herkunft => text()();

  /// Die drei Anteile einer berechneten Festlegung, damit die Herleitung an
  /// einem festen Tag die Zahl im Ring erklärt und nicht die von heute
  /// (#314). **Nullbar, ohne Vorgabewert**: Ein Ziel von Hand hat keine
  /// Anteile, und eine `0` behauptete welche (Fehler `01`).
  RealColumn get grundumsatzKcal =>
      real().named('grundumsatz_kcal').nullable()();

  RealColumn get aktivKcal => real().named('aktiv_kcal').nullable()();

  RealColumn get koerperzielKcal =>
      real().named('koerperziel_kcal').nullable()();

  @override
  Set<Column> get primaryKey => {abTag};
}
