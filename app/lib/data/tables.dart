// Tabellen des drift-Caches (Task 6). Siehe `docs/superpowers/specs/
// 2026-10-23-flutter-rebuild-design.md`, Abschnitte 5.5, 5.6, 5.6a, sowie
// `app/test/data/migration_test.dart`, das diese API verbindlich vorgibt.
//
// Zwei Tabellengruppen in einer Datenbank (Spec 5.6a):
// - `TagesWerte` und `StundenSchritte` sind der Cache aus Apple Health.
//   `Messwert<T>` (siehe `lib/core/messwert.dart`) gilt für Abgeleitetes aus
//   diesen Tabellen — ein fehlender Lauf, nicht ein fehlender Wert.
// - `EigeneDaten` steht stellvertretend für Tims eigene Daten (Gym,
//   Umfänge, Tagestausch). `Messwert<T>` gilt dort nicht: leer heißt leer.
//
// Jede Metrikspalte in der Cache-Gruppe ist nullbar — ein fehlender Wert ist
// nicht `0`, sondern abwesend (Global Constraint aus task-6-brief.md).
import 'package:drift/drift.dart';

/// Tageswerte aus Apple Health, ein Eintrag je Kalendertag.
///
/// `tag` ist der ISO-Tagesschlüssel aus `BerlinCalendar.dayKey(...)`
/// (`YYYY-MM-DD`), kein Zeitstempel: Ein lexikografischer Vergleich
/// (`WHERE tag >= ? AND tag <= ?`) liefert dieselbe Reihenfolge wie ein
/// Datumsvergleich, übersteht aber jede Sommerzeitumstellung (Spec 5.6,
/// letzter Punkt).
@DataClassName('TagesWerteRow')
class TagesWerte extends Table {
  TextColumn get tag => text()();
  IntColumn get schritte => integer().nullable()();
  IntColumn get ruhepulsBpm => integer().named('ruhepuls_bpm').nullable()();

  /// Wann diese Zeile aus Apple Health geholt wurde — `null`, solange
  /// unbekannt (etwa nach einer Migration aus Schema v1, das diese Spalte
  /// noch nicht kannte). Der Stand je Zeile aus Spec 5.3b, nicht ein
  /// globaler Zeitstempel für den ganzen Cache: Task 13 braucht ihn je
  /// Zeile für `Bekannt(…, stand: …)`.
  DateTimeColumn get gelesenAm => dateTime().named('gelesen_am').nullable()();

  /// Herzfrequenzvariabilität in Millisekunden (Schema v3, #113) —
  /// `DailyMetrics.hrvMs`. Nullbar wie jede Metrikspalte: An einem Tag ohne
  /// Uhr am Handgelenk gibt es diesen Wert schlicht nicht, und „0 ms HRV"
  /// wäre ein Alarmwert, kein fehlender Wert.
  RealColumn get hrvMs => real().named('hrv_ms').nullable()();

  /// Atemfrequenz je Minute (Schema v3, #113) — `DailyMetrics.respRate`.
  RealColumn get respRate => real().named('resp_rate').nullable()();

  /// Puls-Erholung in Schlägen (Schema v3, #113) —
  /// `DailyMetrics.recoveryHRDrop`. Der Spaltenname schreibt sich mit
  /// kleinem `r` (`recovery_hr_drop`), damit drifts Standard-Snake-Case und
  /// der `.named(...)`-Wert dieselbe Form haben.
  IntColumn get recoveryHrDrop =>
      integer().named('recovery_hr_drop').nullable()();

  /// Körpergewicht in Kilogramm (Schema v7, #194) — `DailyMetrics.weightKg`.
  /// Bis dahin hatte dieses Feld keine Spalte und kam aus dem Cache **immer**
  /// `null` zurück; die Gewichtskachel stand nach jedem Kaltstart deshalb
  /// erst leer da. Nullbar wie jede Metrikspalte: An einem Tag ohne Waage
  /// gibt es diesen Wert nicht, und „0 kg" wäre keine fehlende Messung,
  /// sondern eine absurde.
  RealColumn get gewichtKg => real().named('gewicht_kg').nullable()();

  /// Trainingsminuten (Schema v7, #194) — `DailyMetrics.exerciseMinutes`.
  ///
  /// **`RealColumn`, nicht `IntColumn`:** `DailyMetrics.exerciseMinutes` ist
  /// `double?`. Eine Ganzzahlspalte zwänge die Brücke zu runden, und das
  /// wäre eine stille Veränderung von Tims Daten auf dem Weg in den Cache.
  /// Nullbar: Kein Wert heißt „nicht gemessen", nicht „0 Minuten
  /// trainiert" — ein Ring auf 0 behauptet „nichts getan" (Fehler `01`).
  RealColumn get trainingsMinuten =>
      real().named('trainings_minuten').nullable()();

  /// Körperfettanteil in Prozent (Schema v7, #202) —
  /// `DailyMetrics.bodyFatPct`. Wie bei `gewichtKg` fehlte bis dahin die
  /// Spalte, der Wert kam aus dem Cache also **immer** `null` zurück, und
  /// die Körperfett-Kachel stand nach jedem Kaltstart erst leer da.
  ///
  /// **`RealColumn`, nicht `IntColumn`:** `DailyMetrics.bodyFatPct` ist
  /// `double?`, und ein gerundeter Prozentwert wäre eine stille Veränderung
  /// von Tims Daten auf dem Weg in den Cache. Nullbar: An einem Tag ohne
  /// Waage gibt es diesen Wert nicht, und „0,0 % Körperfett" wäre keine
  /// fehlende Messung, sondern eine absurde (Fehler `01`).
  RealColumn get koerperfettPct =>
      real().named('koerperfett_pct').nullable()();

  /// Fettfreie Masse in Kilogramm (Schema v7, #202) —
  /// `DailyMetrics.leanKg`. Dieselbe Begründung wie bei [koerperfettPct]:
  /// `double?` im Kanal, also `RealColumn`, und nullbar, weil „0 kg
  /// Muskelmasse" keine Messung ist.
  RealColumn get fettfreiKg => real().named('fettfrei_kg').nullable()();

  /// VO₂max in ml/kg/min (Schema v26, #95) — `DailyMetrics.vo2max`. Bis
  /// dahin hatte dieses Feld keine Spalte und kam aus dem Cache **immer**
  /// `null` zurück (geerbte Schemagrenze aus Task 6); die VO₂max-Anzeige
  /// des Ausdauer-Schirms stünde nach jedem Kaltstart erst leer da.
  ///
  /// **Kein `.named(…)`:** drifts Standard-Snake-Case von `vo2max` ist
  /// `vo2max` selbst — anders als bei [recoveryHrDrop] haben Standard und
  /// Wunschname dieselbe Form.
  ///
  /// **`RealColumn`, nicht `IntColumn`:** `DailyMetrics.vo2max` ist
  /// `double?`; eine Ganzzahlspalte zwänge die Brücke zu runden, und
  /// gerundete ml/kg/min wären eine stille Veränderung von Tims Daten auf
  /// dem Weg in den Cache. Nullbar wie jede Metrikspalte: An einem Tag
  /// ohne Ausdauereinheit mit der Uhr gibt es diesen Wert schlicht nicht,
  /// und „VO₂max 0" wäre keine fehlende Messung, sondern eine absurde
  /// (Fehler `01`). Kein Vorgabewert — eine Vorgabe erfände eine Messung,
  /// die niemand gemacht hat.
  RealColumn get vo2max => real().nullable()();

  @override
  Set<Column> get primaryKey => {tag};
}

/// Stundenwerte der Schritte, ein Eintrag je Stunde und Tag.
@DataClassName('StundenSchritteRow')
class StundenSchritte extends Table {
  TextColumn get tag => text()();
  IntColumn get stunde => integer()();
  IntColumn get schritte => integer().nullable()();

  @override
  Set<Column> get primaryKey => {tag, stunde};
}

/// Tims eigene Daten (Gym-Trainings, Umfänge, Tagestausch) — zweite
/// Tabellengruppe aus Spec 5.6a. `EigeneDaten` ist hier ein
/// Platzhalter-Repräsentant: die konkreten Tabellen sind nicht Gegenstand
/// dieses Tasks. Für diese Gruppe gilt `Messwert<T>` **nicht** — ein Tag
/// ohne Eintrag ist schlicht leer, keine Platzhalterzeile.
@DataClassName('EigeneDatenRow')
class EigeneDaten extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get tag => text()();
  TextColumn get inhalt => text()();
}

/// Eine Nacht aus Apple Health, ein Eintrag je Aufwachtag (Schema v3, #113).
///
/// Der Schlaf-Cache besteht aus **zwei** Tabellen: hier die Nacht mit ihrem
/// Stand, in [SchlafAbschnitte] eine Zeile je Abschnitt. Eine Nacht als
/// Textklumpen in einer einzigen Spalte bräuchte einen eigenen Codec mit
/// eigenen Tests, wäre mit keiner Abfrage erreichbar und bei der nächsten
/// Schemaänderung nur noch zu verwerfen (Entscheidung in
/// `test/data/schlaf_cache_test.dart`, Dateikopf).
@DataClassName('NachtRow')
class Naechte extends Table {
  /// ISO-Tagesschlüssel des **Aufwachtags** (`BerlinCalendar.dayKey`),
  /// derselbe Schlüsseltyp wie in [TagesWerte] — damit wird aus
  /// `DataWindow.clip(...)` auch hier ein `WHERE tag >= ?` (Spec 5.6).
  TextColumn get tag => text()();

  /// Wann diese Nacht aus Apple Health geholt wurde. Der Stand liegt auf der
  /// **Nacht**, nicht auf dem einzelnen Abschnitt: Ein Lauf hat einen
  /// Zeitpunkt (Spec 5.3b), und ein Abschnitt ohne seine Nacht gibt es
  /// nicht. Nullbar, weil eine künftige Migration Zeilen ohne bekannten
  /// Stand hinterlassen könnte — die gelten dann als „kein Cache", nicht
  /// als Cache mit einem erfundenen Zeitstempel.
  DateTimeColumn get gelesenAm => dateTime().named('gelesen_am').nullable()();

  /// Der Ruhepuls **dieser Nacht** in bpm (Schema v8, #193) — das
  /// 5. Perzentil der Pulsproben im Schlaffenster, gerechnet von
  /// `NightVitals` im Kern.
  ///
  /// Die drei Spalten stehen hier und nicht in [TagesWerte], obwohl es sie
  /// dort gleichnamig schon gibt: Dort ist es der Wert des **Kalendertags**,
  /// und genau dessen Verwechslung mit der Nacht behebt #193. Zwei Spalten
  /// gleichen Namens in zwei Tabellen sind hier kein Versehen, sondern der
  /// Unterschied selbst.
  ///
  /// **`RealColumn`, anders als [TagesWerte.ruhepulsBpm]:** Apples
  /// `RestingHeartRate` kam als ganze Zahl; dieser Wert ist ein linear
  /// interpoliertes Perzentil (`NightVitals.restingHeartRate` ist
  /// `double?`). Eine Ganzzahlspalte zwänge die Brücke zu runden, und das
  /// wäre eine stille Veränderung des gerechneten Werts auf dem Weg in den
  /// Cache — derselbe Grund, aus dem [TagesWerte.trainingsMinuten] in #194
  /// eine `RealColumn` wurde.
  ///
  /// Nullbar wie jede Metrikspalte: Unter fünf Pulsproben gibt es keinen
  /// Ruhepuls, und „0 bpm" wäre kein fehlender Wert, sondern ein Alarmwert.
  ///
  /// **Gespeichert wird das Ergebnis, nicht die Eingabe.** Die Rohproben
  /// liegen nicht im Cache und sollen es nicht — für dreißig Tage wären das
  /// rund 24.000 Pulsproben.
  RealColumn get ruhepulsBpm => real().named('ruhepuls_bpm').nullable()();

  /// Die Herzfrequenzvariabilität dieser Nacht in Millisekunden (Schema v8,
  /// #193) — der Median der Proben im Schlaffenster. Für sie gibt es keine
  /// Mindestzahl an Proben: Die Uhr misst HRV nur zwei- bis sechsmal je
  /// Nacht.
  RealColumn get hrvMs => real().named('hrv_ms').nullable()();

  /// Die Atemfrequenz dieser Nacht je Minute (Schema v8, #193), ebenfalls
  /// der Median. Nacht und Tag unterscheiden sich hier kaum; sie kommt
  /// trotzdem aus dem Nachtfenster, weil ein Ampelsignal, das an einer
  /// anderen Zeitspanne hängt als die beiden anderen, sich nicht erklären
  /// ließe (von Tim am 02.11.2026 so entschieden).
  RealColumn get respRate => real().named('resp_rate').nullable()();

  @override
  Set<Column> get primaryKey => {tag};
}

/// Ein Abschnitt einer Nacht mit einer einzigen Phase (Schema v3, #113).
@DataClassName('SchlafAbschnittRow')
class SchlafAbschnitte extends Table {
  /// Aufwachtag, wie in [Naechte].
  TextColumn get tag => text()();

  /// 0 = Hauptnacht, 1..n = n-tes Nickerchen desselben Tages. SPEC 4.6
  /// zählt Tagschlaf nicht zur Nacht, deshalb trägt der Schlüssel die
  /// Herkunft mit.
  ///
  /// **Kein nullbarer Schlüsselteil:** SQLite lässt NULL in einem
  /// Primärschlüssel zu und behandelt zwei NULLs als verschieden — ein
  /// `INSERT OR REPLACE` würde Abschnitte dann verdoppeln statt zu
  /// ersetzen.
  IntColumn get quelle => integer()();

  /// Laufende Nummer innerhalb der Quelle, bei 0 beginnend. Hält die
  /// Reihenfolge der Abschnitte fest, ohne sie aus den Zeiten
  /// zurückrechnen zu müssen.
  IntColumn get lfdNr => integer().named('lfd_nr')();

  /// `SleepStage.name` — der Name der Phase, nicht ihr Index: Eine später
  /// eingefügte Phase verschöbe sonst stillschweigend die Bedeutung aller
  /// abgelegten Zeilen.
  TextColumn get phase => text()();

  DateTimeColumn get beginn => dateTime()();
  DateTimeColumn get ende => dateTime()();

  @override
  Set<Column> get primaryKey => {tag, quelle, lfdNr};
}

/// Tims Ziele (Schema v4, #111) — **genau eine Zeile**, `id == 0`.
///
/// Ziele sind kein Verlauf; eine zweite Zeile wäre ein zweiter,
/// widersprechender Stand. Zweite Tabellengruppe aus Spec 5.6a: Das sind
/// Tims eigene Daten, kein Lauf, der leer ausgehen könnte — `Messwert<T>`
/// gilt hier nicht. Eine leere Tabelle heißt: noch nichts eingestellt. Die
/// Vorbelegung steht in Dart (`Ziele.vorbelegung`), nicht als vorab
/// eingefügte Zeile; sonst gäbe es sie an zwei Orten, und einer von beiden
/// wäre irgendwann der falsche.
@DataClassName('ZielWerteRow')
class ZielWerte extends Table {
  IntColumn get id => integer().withDefault(const Constant(0))();

  /// Schlafziel in ganzen Minuten — Minuten statt Stunden, damit „7:30 h"
  /// ohne Gleitkommarundung ausdrückbar bleibt.
  IntColumn get schlafzielMinuten => integer().named('schlafziel_minuten')();

  /// Schlafenszeitziel als **Minuten nach Mitternacht**. Kein `DateTime`:
  /// 22:30 ist eine Tageszeit, kein Ereignis (`CLAUDE.md`, „Keine
  /// hartcodierten Ereignisse"). Und nicht auf der 18-Uhr-Skala der
  /// Zubettgehzeit-Formel (#110): Die Ablage soll lesbar sein, ohne die
  /// Formel zu kennen.
  IntColumn get schlafenszeitMinuten =>
      integer().named('schlafenszeit_minuten')();

  /// Wochenziel Trainingsminuten (Spec 10a Punkt 4).
  IntColumn get wochenzielTrainingsminuten =>
      integer().named('wochenziel_trainingsminuten')();

  @override
  Set<Column> get primaryKey => {id};
}

/// Von Hand eingetragene Schlafphasen (Schema v6, #131) — Nacht **und**
/// Tagschlaf in einer Tabelle.
///
/// Zweite Tabellengruppe (Spec 5.6a), und zwar der Teil davon, der nicht
/// nachladbar ist: Hinter diesen Zeilen steht kein Lauf aus Apple Health,
/// sondern Tim. `Messwert<T>` gilt hier **nicht**, leer heißt leer, und es
/// gibt deshalb auch kein `gelesen_am` — eine Spalte, die sagt, wann wir
/// etwas geholt haben, hätte hier nichts zu tragen.
///
/// **Die App schreibt nichts nach Apple Health** (`CLAUDE.md`: auf dem
/// Gerät reine Lesequelle). Der Eintrag liegt hier und wird beim Lesen
/// über die gemessenen Nächte gelegt.
///
/// **Eine Tabelle für beide Arten**, weil beide dieselben Felder tragen:
/// ein Tag, eine Dauer, optional zwei Uhrzeiten, optional eine Notiz. Zwei
/// Tabellen mit identischen Spalten wären zwei Stellen für dieselbe
/// Prüfung.
@DataClassName('SchlafEintragRow')
class SchlafEintraege extends Table {
  /// ISO-Tagesschlüssel aus `BerlinCalendar.dayKey(...)`, wie in
  /// [TagesWerte] — bei der Nacht der **Aufwachtag**, beim Tagschlaf der
  /// Tag des Nickerchens.
  TextColumn get tag => text()();

  /// `SchlafEintragArt.name`, nicht der Index: Ein später eingefügter Wert
  /// verschöbe sonst die Bedeutung jeder abgelegten Zeile — dieselbe
  /// Regel, nach der [SchlafAbschnitte.phase] den `SleepStage.name` trägt.
  TextColumn get art => text()();

  /// Laufende Nummer innerhalb von Tag und Art, bei 0 beginnend. Bei einer
  /// Nacht immer 0 — eine zweite eingetragene Nacht für denselben
  /// Aufwachtag wäre eine zweite Antwort auf dieselbe Frage. Beim
  /// Tagschlaf zählt sie hoch; `tagschlaf.js` kennt den Zustand „Zwei
  /// Phasen" ausdrücklich.
  IntColumn get lfdNr => integer().named('lfd_nr')();

  /// Die geschlafene Zeit in ganzen Minuten. **Nicht nullbar und nicht aus
  /// den Zeiten zurückgerechnet:** Der Entwurf lässt die aus den Zeiten
  /// gerechnete Dauer überschreiben („falls du wach dazwischen lagst"), und
  /// eine abgeleitete Dauer könnte das nicht abbilden.
  IntColumn get schlafMinuten => integer().named('schlaf_minuten')();

  /// Zubettgehen bzw. Einschlafen als **Minuten nach Mitternacht**
  /// (0..1439); `null` in der Formularfassung „nur Dauer".
  ///
  /// Kein `DateTime`: „23:10" ist eine Tageszeit, kein Ereignis — dieselbe
  /// Entscheidung wie bei [ZielWerte.schlafenszeitMinuten]. Sie erspart
  /// zugleich die Zeitzonenfrage: Als Zeitpunkt abgelegt bezeichnete
  /// „02:30 am 25.10.2026" in Berlin zwei verschiedene Momente.
  IntColumn get beginnMinuten => integer().named('beginn_minuten').nullable()();

  /// Aufstehen bzw. Aufwachen, ebenfalls Minuten nach Mitternacht.
  /// Entweder stehen beide Uhrzeiten da oder keine — eine halbe Angabe
  /// ergäbe kein Fenster.
  IntColumn get endeMinuten => integer().named('ende_minuten').nullable()();

  /// Tims Notiz („Uhr vergessen"). Leer heißt leer: Eine leere Zeichenkette
  /// wird beim Schreiben zu `null`, sonst gäbe es zwei Schreibweisen für
  /// „keine Notiz".
  TextColumn get notiz => text().nullable()();

  @override
  Set<Column> get primaryKey => {tag, art, lfdNr};
}


/// Tims Stammdaten (Schema v11, Ernährungsplan Task 1) — **genau eine
/// Zeile**, `id == 0`, wie bei [ZielWerte]. Stammdaten sind kein Verlauf;
/// eine zweite Zeile wäre ein zweiter, widersprechender Stand.
///
/// Vier Angaben über Tim, die nicht aus Apple Health kommen: Körpergröße
/// und Geburtsjahr für Mifflin-St Jeor, Zielgewicht und Zieldatum für den
/// Überschuss aus dem Körperziel (`docs/superpowers/specs/
/// 2026-11-03-ernaehrung-design.md`, „Stammdaten und Körperziel").
///
/// **Alle vier sind nullbar, und das ist der Kern dieser Tabelle.** Zweite
/// Tabellengruppe (Spec 5.6a): Dahinter steht kein Lauf aus Apple Health,
/// der leer ausgehen könnte, sondern Tim — `Messwert<T>` gilt hier nicht,
/// leer heißt leer, und ein `gelesen_am` hätte nichts zu tragen. Solange
/// nichts eingetragen ist, steht dort nichts: kein `0`, kein vorbelegtes
/// Geburtsjahr, kein Platzhalterdatum. Ein Grundumsatz aus einer
/// erfundenen Größe sähe aus wie eine Rechnung und wäre eine Behauptung —
/// Fehler `01` eine Schicht tiefer.
///
/// **Und anders als [ZielWerte] gibt es keine Vorbelegung.** Acht Stunden
/// Schlaf sind eine Empfehlung, die für jeden gilt; eine Körpergröße gilt
/// für niemanden außer Tim. Sie zu raten wäre keine Vorbelegung, sondern
/// eine Erfindung.
@DataClassName('StammdatenRow')
class Stammdaten extends Table {
  IntColumn get id => integer().withDefault(const Constant(0))();

  /// Körpergröße in ganzen Zentimetern.
  IntColumn get groesseCm => integer().named('groesse_cm').nullable()();

  /// Geburtsjahr als vierstellige Jahreszahl — kein Geburtsdatum und kein
  /// `DateTime`. Mifflin-St Jeor braucht das Alter in Jahren; ein volles
  /// Datum wäre eine Angabe mehr, als die Formel trägt.
  IntColumn get geburtsjahr => integer().nullable()();

  /// Zielgewicht in Kilogramm.
  ///
  /// **`RealColumn`, nicht `IntColumn`:** Eine Ganzzahlspalte zwänge zum
  /// Runden, und das wäre eine stille Veränderung von Tims Wert auf dem
  /// Weg in den Cache — derselbe Grund, aus dem
  /// [TagesWerte.trainingsMinuten] in #194 eine `RealColumn` wurde.
  RealColumn get zielgewichtKg => real().named('zielgewicht_kg').nullable()();

  /// Das Datum, zu dem das Zielgewicht erreicht sein soll, als
  /// **ISO-Tagesstring** (`YYYY-MM-DD`) — derselbe Schlüsseltyp wie
  /// [TagesWerte.tag]. Kein Zeitpunkt und keine Epoch-Zahl: Ein Zieldatum
  /// ist eine Kalenderangabe; als Zeitstempel abgelegt hinge es an einer
  /// Zeitzone und wäre nach der nächsten Umstellung der Vortag.
  TextColumn get zieldatum => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Tims Maßband-Messungen (Schema v23, #476 unter #88) — **eine Zeile je
/// Tag und Maß**, nicht ein Textklumpen je Tag. Ein Klumpen bräuchte einen
/// eigenen Codec mit eigenen Tests, wäre mit keiner Abfrage erreichbar und
/// bei der nächsten Schemaänderung nur zu verwerfen; dieselbe Überlegung
/// wie bei [Naechte] und [SchlafAbschnitte]. Form und Namen gibt
/// `app/test/data/schema_v24_test.dart` verbindlich vor.
///
/// **Zweite Tabellengruppe (Spec 5.6a): `Messwert<T>` gilt hier nicht.**
/// Hinter einem Umfang steht kein Lauf aus Apple Health, der leer ausgehen
/// könnte, sondern Tim mit einem Maßband. Leer heißt leer.
///
/// **Kein Vorgabewert an keiner Spalte.** Eine Vorgabe an [eingetragenAm]
/// (etwa `CURRENT_TIMESTAMP`) erfände den Zeitpunkt einer Messung, eine an
/// [zentimeter] einen Umfang und eine an [quelle] eine Herkunft, die
/// niemand gemeldet hat. `NOT NULL` ohne Vorgabe ist bei einer neuen
/// Tabelle erlaubt: Die Stufe 24 und `_reconcileSchema` legen sie jeweils
/// in einem Zug an.
///
/// **Kein `CHECK` auf [mass] und keines auf [quelle].** Ein sechzehntes
/// Maß und eine dritte Quelle müssen sich eintragen lassen, ohne die
/// Tabelle neu zu bauen — was die App kennt, entscheidet das Lesen.
///
/// **Kein Index**, weil `_reconcileSchema` keine Indizes kennt und ein
/// Index, den der Abgleich nicht nachziehen kann, auf einem Gerät mit
/// fremdem Zwischenstand still fehlte. Gefiltert wird in SQL über [tag];
/// das trägt der Index hinter dem Primärschlüssel, weil [tag] dort vorn
/// steht.
///
/// Die Zeilenklasse heißt `UmfangRow`, weil `Umfang` der Werttyp des Kerns
/// ist (`trainings_core`).
@DataClassName('UmfangRow')
class Umfaenge extends Table {
  /// Der Tag der Messung als ISO-Tagesstring aus `BerlinCalendar.dayKey`
  /// (`YYYY-MM-DD`), kein Zeitpunkt und keine Epoch-Zahl — derselbe
  /// Schlüsseltyp wie [TagesWerte.tag]. Ein Tag ist eine Kalenderangabe:
  /// So vergleicht `WHERE tag >= ?` lexikografisch richtig und übersteht
  /// jede Zeitumstellung.
  TextColumn get tag => text()();

  /// Der stabile Schlüssel des Maßes (Bauch, Brust, Oberarm links …), nicht
  /// seine Beschriftung. Die deutschen Namen stehen in der Ansicht; ein
  /// umbenanntes Maß darf die abgelegten Messungen nicht verwaisen lassen.
  TextColumn get mass => text()();

  /// Der gemessene Umfang in Zentimetern.
  ///
  /// **`RealColumn` und Pflicht.** Ein Umfang ist eine Kommazahl: 41,4 cm
  /// sind nicht 41 cm, und die Totzone des Fortschritts rechnet mit 0,2 cm
  /// — sie kann nichts entscheiden, wenn die Ablage rundet. Ein fehlendes
  /// Maß ist keine Zeile; es wird weder als `NULL`-Zeile noch als `0`
  /// abgelegt, denn `0` behauptete einen gemessenen Umfang von null
  /// Zentimetern (`CLAUDE.md`, „`0` ist keine Antwort auf ‚kein Wert'").
  RealColumn get zentimeter => real()();

  /// Wann die Messung eingetragen wurde, UTC, als Text
  /// (`storeDateTimeAsText`). Driftets Standard (Unix-Sekunden) gäbe den
  /// Zeitpunkt als Ortszeit zurück, und der wäre dann ungleich sich selbst.
  DateTimeColumn get eingetragenAm => dateTime().named('eingetragen_am')();

  /// Woher der Wert stammt: `getippt` oder `import`.
  ///
  /// **Die Quelle gehört in den Schlüssel.** Stünde sie nicht darin,
  /// überschriebe der Import beim nächsten Lauf den getippten Wert, und das
  /// Zusammenführen hätte nichts mehr zu entscheiden. Es passiert beim
  /// **Lesen**, nicht beim Schreiben — und dafür müssen beide Zeilen
  /// nebeneinander liegen bleiben.
  TextColumn get quelle => text()();

  /// `tag` steht vorn, und das ist keine Schreibweise: Der Index hinter dem
  /// Primärschlüssel trägt eine Bereichsabfrage nur über seine **erste**
  /// Spalte. Gefiltert wird nach Zeitraum, nie nach Maß allein.
  @override
  Set<Column> get primaryKey => {tag, mass, quelle};
}
