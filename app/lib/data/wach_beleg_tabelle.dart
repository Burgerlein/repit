// Die Belege für die Tagesgrenze: wann Tim nachweislich wach war, soweit
// die App es selbst sieht (Schema v22, #451 unter #375). Form und Namen
// gibt `app/test/data/schema_v23_test.dart` verbindlich vor (siehe
// Dateikopf dort) — diese Datei darf den Test ausführen, aber nicht
// verändern (`CLAUDE.md`, „Wer Tests schreibt, schreibt nicht die
// Implementierung"). Spec:
// `docs/superpowers/specs/2026-11-10-tagesgrenze-design.md`, Abschnitt
// „Die Datenschicht".
//
// **Die Tabelle steht in einer eigenen Datei**, aus demselben Grund wie
// `kalorienziel_tabelle.dart`: `cache.dart` muss sie importieren, und das
// Repository (`wach_belege.dart`) importiert `cache.dart`. Beides in einer
// Datei wäre ein Ringimport.
//
// **Zweite Tabellengruppe (Spec 5.6a): `Messwert<T>` gilt hier nicht.**
// Ein Beleg ist etwas, das Tim in der App getan hat; leer heißt leer.
import 'package:drift/drift.dart';

/// Ein Zeitpunkt, an dem Tim nachweislich wach war, weil er die App
/// geöffnet oder etwas gebucht hat (Spec, Entscheidung 3 und V13). Die
/// Tagesgrenze liest daraus, ob ein Tag nach 04:00 noch läuft.
///
/// **Die Tabelle wird nie geleert** (V13). Eine Zeile sind drei Spalten;
/// auch bei 60 Belegen am Tag sind das kaum 1 MB im Jahr.
///
/// **Kein Vorgabewert an keiner Spalte.** Eine Vorgabe behauptete eine Art
/// oder einen Zeitpunkt, den niemand erlebt hat. `NOT NULL` ohne Vorgabe
/// ist bei einer neuen Tabelle erlaubt: Die Stufe 23 und `_reconcileSchema`
/// legen sie jeweils in einem Zug an.
///
/// **Kein Index**, weil `_reconcileSchema` keine Indizes kennt und ein
/// Index, den der Abgleich nicht nachziehen kann, auf einem Gerät mit
/// fremdem Zwischenstand still fehlte. Gelesen wird ein Fenster von
/// höchstens 28 Stunden, gefiltert in SQL über [zeitpunkt].
///
/// Die Zeilenklasse heißt `WachBelegRow`, weil `Wachbeleg` der Werttyp
/// des Kerns ist (`trainings_core`, `tagesgrenze.dart`).
@DataClassName('WachBelegRow')
class WachBelege extends Table {
  /// Fortlaufende Nummer.
  IntColumn get id => integer().autoIncrement()();

  /// Wann Tim wach war, UTC, als Text (`storeDateTimeAsText`).
  DateTimeColumn get zeitpunkt => dateTime()();

  /// Der Name aus `WachArt` (`oeffnen`, `buchung`, V13). **Ohne `CHECK`
  /// und ohne Vorgabe:** Unbekannte Werte übergeht das Lesen, nicht die
  /// Tabelle.
  TextColumn get art => text()();
}
