// Eingetragenes Wasser (Schema v16, #311). Form und Namen gibt
// `app/test/data/schema_v16_test.dart` verbindlich vor (siehe Dateikopf
// dort) — diese Datei darf den Test ausführen, aber nicht verändern
// (`CLAUDE.md`, „Wer Tests schreibt, schreibt nicht die Implementierung").
//
// **Eine eigene Tabelle, keine Zeile in `eintraege`** (Festlegung des
// Test-Agenten, nicht von Tim): Ein Glas Wasser ist keine Mahlzeit.
// `eintraege.mahlzeit` ist `NOT NULL`, und ein Glas stünde danach in einer
// der vier Zeilen — „Mittag" sagte dann „eingetragen". `eintraege.wasser_ml`
// bleibt das Wasser **in** einem Lebensmittel.
//
// **Zweite Tabellengruppe (Spec 5.6a): `Messwert<T>` gilt hier nicht.**
// Eingetragenes Wasser sind Tims eigene Daten; leer heißt leer.
import 'package:drift/drift.dart';

/// Ein eingetragenes Glas Wasser.
@DataClassName('WasserEintragRow')
class WasserEintraege extends Table {
  /// Mit `AUTOINCREMENT`, aus demselben Grund wie `Eintraege.id`: Der
  /// Health-Nachlauf merkt sich IDs, und eine nach einer Löschung neu
  /// vergebene Nummer setzte den Stand eines fremden Eintrags.
  IntColumn get id => integer().autoIncrement()();

  /// Der Tag, auf den eingetragen wurde, als ISO-Tagesschlüssel — der
  /// **offene** Tag des Schirms, nicht der Kalendertag von [zeitpunkt]:
  /// Wer über ‹ gestern offen hat und ein Glas einträgt, meint gestern.
  TextColumn get tagesSchluessel => text().named('tages_schluessel')();

  /// Wann eingetragen wurde, als UTC-Zeitpunkt. TEXT in der Datei
  /// (`storeDateTimeAsText`, `CLAUDE.md`).
  DateTimeColumn get zeitpunkt => dateTime()();

  /// Die Menge in Millilitern. `NOT NULL` — ein Glas ohne Menge ist kein
  /// Eintrag. `REAL`, denn 333,5 ml sind eine Menge, und Runden wäre eine
  /// stille Änderung von Tims Wert.
  RealColumn get mengeMl => real().named('menge_ml')();

  /// Die UUID der Probe in Apple Health — nullbar, die kennt erst, wer
  /// geschrieben hat.
  TextColumn get healthUuid => text().named('health_uuid').nullable()();

  /// `offen`, `geschrieben` oder `nicht_moeglich` — dieselben drei Wörter
  /// wie `eintraege.health_stand`. Der Vorgabewert `offen` ist die
  /// Wahrheit über eine Zeile, deren Stand niemand festgehalten hat.
  TextColumn get healthStand =>
      text().named('health_stand').withDefault(const Constant('offen'))();
}
