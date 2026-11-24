// Die beiden KI-Tabellen (Schema v15, #332): Einstellungen des KI-Zugangs
// und die gezählten Anfragen (`docs/superpowers/specs/
// 2026-11-04-ki-zugang-design.md`, „Datenschicht — Schema 14 → 15").
//
// Form und Namen gibt `app/test/data/schema_v15_test.dart` verbindlich vor
// (siehe Dateikopf dort) — diese Datei darf den Test ausführen, aber nicht
// verändern (`CLAUDE.md`, „Wer Tests schreibt, schreibt nicht die
// Implementierung").
//
// **Zweite Tabellengruppe (Spec 5.6a): `Messwert<T>` gilt hier nicht.**
// Einstellungen und Verbrauch sind Tims eigene Daten; leer heißt leer.
//
// **Der Schlüssel liegt nicht hier.** Die Datenbank wandert ins
// iCloud-Gerätebackup, der Schlüssel nicht — er lebt ausschließlich in der
// Keychain (`CLAUDE.md`, „Niemals tun").
//
// Die Datenklassen heißen `KiEinstellungenRow` und `KiAnfrageRow`, damit
// sie nicht mit Werttypen des Kerns kollidieren (Plan, Task 1).
import 'package:drift/drift.dart';

/// Die Einstellungen des KI-Zugangs — **höchstens eine Zeile**, `id == 0`,
/// wie bei `Stammdaten`. Einstellungen sind kein Verlauf; eine zweite Zeile
/// wäre ein zweiter, widersprechender Stand.
///
/// **Die Stufe 15 legt keine Zeile an.** Eine vorab eingefügte Zeile
/// behauptete eine Einstellung, die niemand getroffen hat. Fehlt die Zeile,
/// gelten die Vorgaben der App — das entscheidet die Anzeige, nicht die
/// Datenbank.
@DataClassName('KiEinstellungenRow')
class KiEinstellungen extends Table {
  IntColumn get id => integer().withDefault(const Constant(0))();

  /// Das gewählte Modell — **nullbar**: Nichts gewählt heißt, die
  /// Voreinstellung der App gilt.
  TextColumn get modell => text().nullable()();

  /// Das Monatslimit in US-Dollar — **nullbar**: `null` heißt „Vorgabe",
  /// nicht `0` und keine Zahl, die niemand eingegeben hat.
  RealColumn get limitUsd => real().named('limit_usd').nullable()();

  /// Eigene Preise je Modell als JSON-Objekt, Überschreibungen der
  /// vorbelegten. **`NOT NULL` mit Vorgabewert `{}`**: Das leere Objekt
  /// heißt „keine Überschreibungen", und der Vorgabewert macht die Spalte
  /// nachtragbar (#233).
  TextColumn get preise => text().withDefault(const Constant('{}'))();

  /// Wann der Schlüssel zuletzt geprüft wurde, als UTC-Zeitpunkt —
  /// **nullbar**: Nie geprüft ist ein eigener Zustand, kein erfundener
  /// Zeitpunkt.
  ///
  /// `AppCache` arbeitet mit `storeDateTimeAsText: true`, die Spalte ist
  /// also TEXT (`CLAUDE.md`).
  DateTimeColumn get geprueftAm => dateTime().named('geprueft_am').nullable()();

  /// Ergebnis der letzten Prüfung als Wort — `gueltig`, `abgelehnt` oder
  /// `kontingent` (Spec). Nullbar aus demselben Grund wie [geprueftAm].
  TextColumn get pruefErgebnis => text().named('pruef_ergebnis').nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Eine gezählte Anfrage an den KI-Anbieter — Verbrauch, den Tim bezahlt.
///
/// Gefiltert wird in SQL über [monat], lexikografisch wie der
/// Tagesschlüssel; nach dem Laden in Dart zu filtern umginge Regel 2
/// (`CLAUDE.md`).
@DataClassName('KiAnfrageRow')
class KiAnfragen extends Table {
  /// Der Schlüssel, mit `AUTOINCREMENT` wie bei `Eintraege.id`: Eine nach
  /// einer Löschung erneut vergebene Nummer wäre eine andere Anfrage unter
  /// demselben Namen.
  IntColumn get id => integer().autoIncrement()();

  /// Wann die Anfrage abgeschickt wurde, als UTC-Zeitpunkt. TEXT in der
  /// Datei (`storeDateTimeAsText`).
  DateTimeColumn get zeitpunkt => dateTime()();

  /// Der Monatsschlüssel in Berliner Zeit (`JJJJ-MM`), beim Schreiben aus
  /// [zeitpunkt] gerechnet. Abgelegt statt bei jeder Abfrage gerechnet,
  /// damit die Monatssumme in SQL filtern kann.
  TextColumn get monat => text()();

  /// Das Modell, an das die Anfrage ging.
  TextColumn get modell => text()();

  /// Wofür die Anfrage war, etwa `foto` oder `pruefung`.
  TextColumn get zweck => text()();

  /// Die gezählten Token. **`NOT NULL`**: Es sind Zählungen, keine
  /// Messwerte — fehlt ein Feld in der Antwort, zählt es `0` (Plan,
  /// „Review Focus" 2).
  IntColumn get eingabeToken => integer().named('eingabe_token')();
  IntColumn get ausgabeToken => integer().named('ausgabe_token')();
  IntColumn get denkToken => integer().named('denk_token')();

  /// Die Kosten in US-Dollar — **nullbar**: Ohne bekannten Preis sind die
  /// Kosten unbekannt, nicht `0`. Eine `0` senkte die Monatssumme still.
  RealColumn get kostenUsd => real().named('kosten_usd').nullable()();
}
