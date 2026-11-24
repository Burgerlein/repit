// Die drei Tabellen des Zykluskalenders (Schema v25, #592 unter #539):
// `zyklus_eintraege` (ein Tageseintrag je Kalendertag),
// `zyklus_health_spiegel` (je geschriebenem HealthKit-Sample eine Zeile)
// und `zyklus_einstellungen` (die eine Einstellungszeile).
//
// Form und Namen gibt `app/test/data/schema_v25_test.dart` verbindlich
// vor (siehe Dateikopf dort, auch zu dem, was der Test-Agent festgelegt
// hat) — diese Datei darf den Test ausführen, aber nicht verändern
// (`CLAUDE.md`, „Wer Tests schreibt, schreibt nicht die
// Implementierung"). Spec:
// `docs/superpowers/specs/2026-11-23-zyklus-spec.md`, Abschnitt 4.
//
// **Die Tabellen stehen in einer eigenen Datei**, aus demselben Grund wie
// `ereignis_tabelle.dart`: `cache.dart` muss sie importieren, und das
// Repository (`zyklus_repository.dart`) importiert `cache.dart`. Beides
// in einer Datei wäre ein Ringimport.
//
// **Zweite Tabellengruppe (Spec 5.6a): `Messwert<T>` gilt hier nicht.**
// Ein Zyklustag ist eine eigene Angabe; es gibt keinen Lauf aus Apple
// Health, der leer ausgehen könnte. Leer heißt leer (Zyklus-Spec 7).
//
// **Kein Index auf keiner der drei Tabellen**, weil `_reconcileSchema`
// keine Indizes kennt: Ein Index, den der Abgleich nicht nachziehen kann,
// fehlte auf einem Gerät mit fremdem Zwischenstand still. Gefiltert wird
// über den Primärschlüssel bzw. über wenige Dutzend Zeilen je Monat.
import 'package:drift/drift.dart';

/// Ein Tageseintrag des Zykluskalenders (Spec 4.1).
///
/// **Eine Zeile je Kalendertag, kein Textklumpen.** Ein Klumpen bräuchte
/// einen eigenen Codec mit eigenen Tests, wäre mit keiner Abfrage
/// erreichbar und bei der nächsten Schemaänderung nur zu verwerfen —
/// dieselbe Überlegung wie bei `naechte` und `umfaenge`.
///
/// **Eine Zeile ohne jeden Wert gibt es nicht** (Spec 4.1): Ein leerer Tag
/// ist ein Tag ohne Zeile. Durchgesetzt wird das beim Schreiben
/// (`ZyklusRepository.schreibe`), nicht von der Tabelle — SQL kann „ohne
/// jeden Wert" nicht ausdrücken, ohne die Regel ein zweites Mal
/// hinzuschreiben.
///
/// Die Zeilenklasse heißt `ZyklusEintragRow`, weil `ZyklusEintrag` der
/// Werttyp des Repositorys ist.
@DataClassName('ZyklusEintragRow')
class ZyklusEintraege extends Table {
  /// Der Tag als ISO-Tagesstring (`YYYY-MM-DD`), kein Zeitpunkt und keine
  /// Epoch-Zahl. Ein Tag ist eine Kalenderangabe: So vergleicht
  /// `WHERE tag >= ?` lexikografisch richtig und übersteht jede
  /// Zeitumstellung.
  TextColumn get tag => text()();

  /// Der Name aus `Blutungsstaerke` (`leicht`, `mittel`, `stark`),
  /// `NULL`, wenn an diesem Tag keine Blutung eingetragen ist.
  ///
  /// **Ohne `CHECK`:** Eine spätere Fassung schreibt vielleicht eine
  /// vierte Stufe, und eine ältere soll die Datei trotzdem öffnen.
  /// Unbekannte Werte übergeht das **Lesen**, nicht die Tabelle — dieselbe
  /// Regel wie bei `ereignisse.art` (V20).
  ///
  /// **`NULL` und nicht `0` oder „keine":** `0` ist keine Antwort auf
  /// „kein Wert" (`CLAUDE.md`).
  TextColumn get blutung => text().nullable()();

  /// Eine Zwischenblutung — ein eigenes Feld und kein Blutungstag
  /// (Spec 1), damit sie nicht in die Periodenerkennung einfließt.
  BoolColumn get zwischenblutung =>
      boolean().withDefault(const Constant(false))();

  /// Der Name aus `Schmerzstaerke` (`leicht`, `mittel`, `stark`),
  /// `NULL`, wenn kein Schmerz eingetragen ist. Ohne `CHECK`, siehe
  /// [blutung].
  TextColumn get schmerz => text().nullable()();

  /// Die gewählten Symptomschlüssel, kommagetrennt (Spec 4.1). Keine
  /// Symptome heißen **leerer Text**, nicht `NULL`: Es gibt keinen
  /// Unterschied zwischen „keine gewählt" und „nicht gefragt", und zwei
  /// Schreibweisen für dasselbe wären eine Fehlerquelle mehr.
  ///
  /// Die Schlüssel selbst stehen in `lib/zyklus/zyklus_symptome.dart` und
  /// sind Speicherformat — wer einen umbenennt, macht jeden Tag unlesbar,
  /// der ihn trägt.
  TextColumn get symptome => text().withDefault(const Constant(''))();

  /// Sex an diesem Tag.
  BoolColumn get sex => boolean().withDefault(const Constant(false))();

  /// Ob verhütet wurde; `NULL`, wenn nichts dazu eingetragen ist. Nur
  /// sinnvoll, wenn [sex] (Spec 4.1) — erzwungen wird das nicht, das
  /// Formular kann den Zustand gar nicht erzeugen.
  BoolColumn get verhuetet => boolean().nullable()();

  /// Der Name aus `Testergebnis` (`positiv`, `negativ`), `NULL`, wenn
  /// kein Test eingetragen ist. Ohne `CHECK`, siehe [blutung].
  TextColumn get test => text().nullable()();

  /// Freitext, `NULL`, wenn keiner eingetragen ist.
  TextColumn get notiz => text().nullable()();

  /// Der Name aus `ZyklusQuelle` (`eigen` oder `health`). Vorgabe
  /// `eigen`: Ein Tag kommt von der Nutzerin, wenn niemand etwas anderes
  /// sagt — vor dem Erstimport gab es keinen anderen Weg in diese
  /// Tabelle. Ohne `CHECK`, siehe [blutung].
  TextColumn get quelle => text().withDefault(const Constant('eigen'))();

  /// Wann die Zeile zuletzt geschrieben wurde, UTC, als Text
  /// (`storeDateTimeAsText`).
  ///
  /// **Pflicht und ohne Vorgabewert.** Ein `CURRENT_TIMESTAMP` erfände den
  /// Zeitpunkt einer Änderung, die niemand gemacht hat — derselbe Fehler
  /// wie eine Migration, die alte Zeilen frisch aussehen lässt. Drifts
  /// Standard (Unix-Sekunden) gäbe den Zeitpunkt als Ortszeit zurück, und
  /// der wäre dann ungleich sich selbst.
  DateTimeColumn get geaendert => dateTime()();

  /// Je Kalendertag höchstens eine Zeile — das setzt „ein leerer Tag ist
  /// ein Tag ohne Zeile" (Spec 4.1) voraus. Ein zweites Eintragen
  /// desselben Tages ist eine Korrektur und ersetzt die Zeile.
  @override
  Set<Column> get primaryKey => {tag};
}

/// Was die App nach HealthKit geschrieben hat (Spec 4.2) — je Sample eine
/// Zeile.
///
/// **Nur damit lässt sich beim Ändern oder Löschen eines Tages gezielt
/// entfernen**, statt alles von Health neu zu lesen. Ein Zyklustag erzeugt
/// mehrere Samples (Blutung, Sex, je Symptom eines), deshalb trägt ein Tag
/// mehrere Zeilen.
@DataClassName('ZyklusSpiegelRow')
class ZyklusHealthSpiegel extends Table {
  /// Die Sample-UUID aus HealthKit. **Der Schlüssel:** Dasselbe Sample
  /// zweimal zu merken wäre dieselbe Zeile.
  TextColumn get uuid => text()();

  /// Der Tag, zu dem das Sample gehört, als ISO-Tagesstring — damit der
  /// Spiegel je Tag abfragbar ist.
  TextColumn get tag => text()();

  /// Der HealthKit-Typbezeichner des Samples.
  TextColumn get typ => text()();

  /// Kein Vorgabewert an keiner Spalte: Eine Vorgabe erfände eine
  /// Sample-UUID, einen Tag oder einen Typ.
  @override
  Set<Column> get primaryKey => {uuid};
}

/// Die eine Einstellungszeile des Zykluskalenders (Spec 4.3) — wie
/// `ziel_werte`, `stammdaten` und `ki_einstellungen`.
///
/// Einstellungen sind kein Verlauf; eine zweite Zeile wäre ein zweiter,
/// widersprechender Stand, und niemand wüsste, welcher gilt.
///
/// **Die Vorbelegung steht nicht hier, sondern in
/// `ZyklusEinstellungen.vorbelegung`** — und die Migration legt keine
/// Zeile an. Die SQL-Vorgabewerte unten sind kein zweiter Ort für die
/// Vorbelegung, sondern halten [Table]-Spalten nachziehbar: `ALTER TABLE
/// … ADD COLUMN … NOT NULL` lehnt SQLite ohne Vorgabe ab, und
/// `_reconcileSchema` käme dann an einer Tabelle, die ein fremder Zweig
/// unvollständig angelegt hat, nicht weiter. Gelesen wird die Vorgabe
/// nie: Das Repository schreibt immer alle Spalten.
@DataClassName('ZyklusEinstellungenRow')
class ZyklusEinstellungen extends Table {
  /// Der Schlüssel der einen Zeile.
  IntColumn get id => integer().withDefault(const Constant(0))();

  /// Ob der Kalender überhaupt geführt wird. **Aus**, bis jemand ihn
  /// einschaltet — er erscheint unter *Mehr* nur, wenn eingeschaltet
  /// (Spec 7).
  BoolColumn get kalenderAn =>
      boolean().named('kalender_an').withDefault(const Constant(false))();

  /// Der Name aus `ZyklusSicht` (`ueberblick` oder `kinderwunsch`). Ohne
  /// `CHECK`, aus demselben Grund wie bei [ZyklusEintraege.blutung].
  TextColumn get sicht => text().withDefault(const Constant('ueberblick'))();

  /// Ob verhütet wird.
  BoolColumn get verhuetungAn =>
      boolean().named('verhuetung_an').withDefault(const Constant(false))();

  /// Seit wann, als ISO-Tagesstring; `NULL`, solange nicht verhütet wird.
  ///
  /// **Nicht bloß ein Flag:** Nur so bleibt rückwirkend erkennbar, welcher
  /// Zyklus unter Verhütung lief (Spec 3.7) — ein Flag verlöre das beim
  /// nächsten Umschalten.
  TextColumn get verhuetungSeit => text().named('verhuetung_seit').nullable()();

  /// Die Art der Verhütung als Freitext, `NULL`, wenn keine eingetragen
  /// ist. **Keine Aufzählung** (Spec 4.3): Die Arten aus 6.2 gehören zu
  /// den Mitteilungen, nicht zur Ablage.
  TextColumn get verhuetungArt => text().named('verhuetung_art').nullable()();

  /// Ob der Erstimport aus Apple Health schon gelaufen ist.
  BoolColumn get importGelaufen =>
      boolean().named('import_gelaufen').withDefault(const Constant(false))();

  /// Ob die Vorhersage pausiert — etwa nach einem positiven Test
  /// (Spec 3.8).
  BoolColumn get vorhersagePausiert => boolean()
      .named('vorhersage_pausiert')
      .withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
