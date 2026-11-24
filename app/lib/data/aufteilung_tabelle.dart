// Die Historie der Aufteilung des Tagesziels auf die Mahlzeiten (Schema
// v20, #430 unter #374). Form und Namen gibt
// `app/test/data/schema_v21_test.dart` verbindlich vor (siehe Dateikopf
// dort) — diese Datei darf den Test ausführen, aber nicht verändern
// (`CLAUDE.md`, „Wer Tests schreibt, schreibt nicht die Implementierung").
// Spec: `docs/superpowers/specs/2026-11-10-mahlzeiten-aufteilung-design.md`,
// Abschnitt „Die Datenschicht".
//
// **Die Tabelle steht in einer eigenen Datei**, aus demselben Grund wie
// `kalorienziel_tabelle.dart`: `cache.dart` muss sie importieren, und was
// später mit ihr rechnet, importiert `cache.dart`. Beides in einer Datei
// wäre ein Ringimport.
//
// **Zweite Tabellengruppe (Spec 5.6a): `Messwert<T>` gilt hier nicht.**
// Die Aufteilung ist Tims eigene Einstellung; leer heißt leer.
import 'package:drift/drift.dart';

/// Eine gesicherte Aufteilung — gilt ab [abTag] bis zur nächsten Zeile.
///
/// **Keine Spalte für den Snack** (Spec, V1 und Entscheidung 2): Er ist
/// der Rest auf 100 und wird nicht gespeichert. Eine eigene Spalte könnte
/// mit den drei übrigen in Widerspruch geraten.
///
/// **Kein Startwert in der Tabelle** (Entscheidung 1): 25 · 35 · 30 · 10
/// steht im Formular und gilt erst, wenn Tim einmal sichert. Die Stufe 21
/// legt deshalb keine Zeile an.
///
/// **Kein Index**, weil `_reconcileSchema` keine Indizes kennt und ein
/// Index, den der Abgleich nicht nachziehen kann, auf einem Gerät mit
/// fremdem Zwischenstand still fehlte.
@DataClassName('MahlzeitAufteilungRow')
class MahlzeitAufteilungen extends Table {
  /// Der Berliner Kalendertag, ab dem die Aufteilung gilt, als
  /// ISO-Tagesschlüssel. **Der Primärschlüssel**: Je Tag gilt höchstens
  /// eine, ein zweites Sichern am selben Tag ersetzt die Zeile (V2).
  /// `ab_tag <= ?` vergleicht lexikografisch richtig.
  TextColumn get abTag => text().named('ab_tag')();

  /// Der Anteil des Frühstücks in ganzen Prozent.
  ///
  /// Alle drei Prozentspalten sind **nullbar und ohne Vorgabewert** (V1).
  /// Eine Vorgabe behauptete eine Einstellung, die niemand gemacht hat.
  /// Nullbar auch deshalb, weil `_reconcileSchema` eine fehlende
  /// `NOT NULL`-Spalte ohne Vorgabe nicht in eine Tabelle mit Zeilen
  /// nachziehen kann — eine solche Spalte wäre auf einem Gerät mit fremdem
  /// Zwischenstand nicht zu reparieren.
  IntColumn get fruehstueckPct =>
      integer().named('fruehstueck_pct').nullable()();

  /// Der Anteil des Mittagessens in ganzen Prozent; siehe [fruehstueckPct].
  IntColumn get mittagPct => integer().named('mittag_pct').nullable()();

  /// Der Anteil des Abendessens in ganzen Prozent; siehe [fruehstueckPct].
  IntColumn get abendPct => integer().named('abend_pct').nullable()();

  @override
  Set<Column> get primaryKey => {abTag};
}
