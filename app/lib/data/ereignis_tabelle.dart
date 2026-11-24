// Die Ereignisse, zunächst die Auszeiten — OP, Krankheit, Verletzung,
// Urlaub (Schema v21, #444 unter #404). Form und Namen gibt
// `app/test/data/schema_v21_test.dart` verbindlich vor (siehe Dateikopf
// dort) — diese Datei darf den Test ausführen, aber nicht verändern
// (`CLAUDE.md`, „Wer Tests schreibt, schreibt nicht die Implementierung").
// Spec: `docs/superpowers/specs/2026-11-10-auszeit-design.md`, Abschnitt
// „Die Datenschicht".
//
// **Die Tabelle steht in einer eigenen Datei**, aus demselben Grund wie
// `kalorienziel_tabelle.dart`: `cache.dart` muss sie importieren, und das
// Repository (`ereignisse.dart`) importiert `cache.dart`. Beides in einer
// Datei wäre ein Ringimport.
//
// **Zweite Tabellengruppe (Spec 5.6a): `Messwert<T>` gilt hier nicht.**
// Ein Ereignis ist Tims eigene Angabe; leer heißt leer.
import 'package:drift/drift.dart';

/// Ein Ereignis mit Zeitraum — heute eine Auszeit, mit #389 auch der
/// Spieltag. Deshalb heißt die Tabelle `ereignisse` und nicht „Auszeit"
/// (Spec, V1).
///
/// **Kein Vorgabewert an keiner Spalte.** Eine Vorgabe behauptete eine Art,
/// einen Zeitraum oder einen Zeitpunkt, den niemand eingetragen hat.
/// `NOT NULL` ohne Vorgabe ist bei einer neuen Tabelle erlaubt: Die Stufe
/// 21 und `_reconcileSchema` legen sie jeweils in einem Zug an.
///
/// **Kein Index**, weil `_reconcileSchema` keine Indizes kennt und ein
/// Index, den der Abgleich nicht nachziehen kann, auf einem Gerät mit
/// fremdem Zwischenstand still fehlte. Es sind ein paar Dutzend Zeilen.
///
/// Die Zeilenklasse heißt `EreignisRow`, weil `Ereignis` der Werttyp des
/// Repositorys ist (Spec, „Repository und Provider").
@DataClassName('EreignisRow')
class Ereignisse extends Table {
  /// Fortlaufende Nummer. `AUTOINCREMENT`, damit eine gelöschte Nummer nie
  /// wieder vergeben wird: Bei gleichem `bis` nennt die Herleitung die
  /// zuletzt angelegte Auszeit, erkannt an der höchsten `id` (V3).
  IntColumn get id => integer().autoIncrement()();

  /// Der Name aus `EreignisArt` (`op`, `krankheit`, `verletzung`,
  /// `urlaub`). **Ohne `CHECK`:** Eine spätere Fassung schreibt `spieltag`
  /// (#389); unbekannte Werte übergeht das Lesen, nicht die Tabelle (V20).
  TextColumn get art => text()();

  /// Der erste Tag, als ISO-Tagesschlüssel. Ein Tag ist eine
  /// Kalenderangabe, kein Zeitpunkt; `WHERE von <= ? AND bis >= ?`
  /// vergleicht lexikografisch richtig.
  TextColumn get von => text()();

  /// Der letzte Tag, einschließlich, als ISO-Tagesschlüssel. Dass er nicht
  /// vor [von] liegt, sichert das Formular (V5), nicht die Tabelle.
  TextColumn get bis => text()();

  /// Freitext, `NULL`, wenn keiner eingetragen ist.
  TextColumn get notiz => text().nullable()();

  /// Wann die Zeile angelegt wurde, UTC, als Text (`storeDateTimeAsText`).
  DateTimeColumn get angelegt => dateTime()();

  /// Wann die Zeile zuletzt geändert wurde, UTC. **`NULL` bis zur ersten
  /// Änderung** — ein Zeitstempel beim Anlegen behauptete eine Änderung,
  /// die es nie gab.
  DateTimeColumn get geaendert => dateTime().nullable()();
}
