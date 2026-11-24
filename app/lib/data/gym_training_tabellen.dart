// Die vier Tabellen der eigenen Trainings (Schema v25, #532 unter #531): die
// Definitionen (`gym_trainings`), ihre Übungen und Tags und die gespeicherte
// Rotation. Entwurf: `docs/superpowers/specs/2026-11-19-eigene-trainings-
// design.md`, Abschnitt 4.1 und 4.2, dazu die Nachträge 23 bis 25.
//
// Form und Namen geben `app/test/data/schema_v25_test.dart` und
// `gym_training_support.dart` verbindlich vor — diese Datei darf die Tests
// ausführen, aber nicht verändern (`CLAUDE.md`, „Wer Tests schreibt, schreibt
// nicht die Implementierung").
//
// **Zweite Tabellengruppe (Spec 5.6a): `Messwert<T>` gilt hier nicht.** Das
// sind Tims eigene Daten; leer heißt leer.
//
// **Alles, was die Spec „nie" nennt, steht als `CHECK` in der Datei**, nicht
// nur im Dart-Code. Zwei Regeln dazu, beide aus `gym_tabellen.dart`
// übernommen:
//
// - `customConstraint` ersetzt **alle** erzeugten Bedingungen der Spalte,
//   auch `NOT NULL` — es steht deshalb mit in der Zeichenkette.
// - **Die Bedingung steht als Literal da, nicht als Konstante.** drifts
//   Generator liest `customConstraint` zur Kompilierzeit und löst keine
//   Konstante auf; im `CREATE TABLE` fehlte dann die Prüfung, während der
//   Dart-Code unverändert übersetzte.
//
// **`UNIQUE` steht im Tabellenkopf** (`uniqueKeys`), nie als
// `CREATE UNIQUE INDEX`: `_reconcileSchema` kennt keine Indizes, ein
// eigenständiger stünde auf Geräten, die die Stufe 25 gelaufen sind, und
// fehlte auf denen, die die Tabelle über den Abgleich bekommen haben.
//
// **Kein Fremdschlüssel** (Spec 4.1): Die Datenbank benutzt keine. Die
// Konsistenz hält `GymTrainingRepository` in einer Transaktion — und der
// Verlauf soll gerade nicht an einer Zeile hängen, die verschwinden darf.
import 'package:drift/drift.dart';

/// Eine Workout-Definition — eine Zeile je Training.
@DataClassName('GymTrainingRow')
class GymTrainings extends Table {
  /// Templates: ihre feste Kennung (`'Push'`, …, `Workout.code`). Eigene:
  /// eine UUID in Großbuchstaben, vergeben beim Anlegen.
  TextColumn get id => text()();

  /// Der ganze Name, z. B. `Push — Brust, Schultern, Trizeps`.
  TextColumn get name => text()();

  /// `'template'` oder `'eigene'` — wortgleich mit `WorkoutCategory.code`.
  /// Ausgeschrieben aus dem Grund im Dateikopf; wer dem Kern eine dritte
  /// Kategorie gibt, braucht eine neue Stufe, denn eine `CHECK`-Bedingung
  /// steht in `CREATE TABLE` und ändert sich nicht von selbst.
  TextColumn get kategorie => text().customConstraint(
    "NOT NULL CHECK (kategorie IN ('template', 'eigene'))",
  )();

  /// Die eingetragene Dauer in Minuten. **`NULL` heißt „geschätzt"**, nicht
  /// „0 Minuten" (Fehler `01`); die Schätzung wird nie gespeichert.
  IntColumn get dauerEingetragenMin =>
      integer().named('dauer_eingetragen_min').nullable()();

  /// Ein Zwischenstand des Editors. **Ein Template ist nie ein Entwurf.**
  BoolColumn get istEntwurf => boolean()
      .named('ist_entwurf')
      .withDefault(const Constant(false))
      .customConstraint(
        "NOT NULL DEFAULT 0 CHECK (ist_entwurf = 0 OR kategorie = 'eigene')",
      )();

  /// Der Tombstone — **nur bei Templates.** Eigene Trainings werden wirklich
  /// gelöscht, weil nur ein Update Templates neu einspielt.
  BoolColumn get geloescht => boolean()
      .withDefault(const Constant(false))
      .customConstraint(
        "NOT NULL DEFAULT 0 CHECK (geloescht = 0 OR kategorie = 'template')",
      )();

  /// Die Anzeigereihenfolge **innerhalb der Kategorie**: Templates = Platz in
  /// der Startbefüllung (1…), Eigene = größte vorhandene Zahl der Eigenen + 1.
  /// Kein Zeitstempel — die Spalte braucht keine Uhr.
  IntColumn get reihenfolge => integer()();

  /// **Vorschlag des Plans (Plan 1), von Tim nicht beantwortet:** Hängt ein
  /// Zwischenstand an einem bestehenden Training, steht hier dessen
  /// Kennung. `NULL` für alles andere, auch für einen frei stehenden
  /// Entwurf. Je Training höchstens ein Zwischenstand (`UNIQUE`); der
  /// Zwischenstand ersetzt das Training erst beim Speichern.
  TextColumn get entwurfVon => text()
      .named('entwurf_von')
      .nullable()
      .customConstraint(
        "NULL CHECK (entwurf_von IS NULL OR "
        "(ist_entwurf = 1 AND kategorie = 'eigene'))",
      )();

  @override
  Set<Column> get primaryKey => {id};

  /// Je Training höchstens ein Zwischenstand. SQLite hält zwei `NULL` für
  /// verschieden, mehrere Entwürfe ohne `entwurf_von` stehen also
  /// nebeneinander.
  @override
  List<Set<Column>> get uniqueKeys => [
    {entwurfVon},
  ];
}

/// Die Übungen eines Trainings in ihrer Reihenfolge.
@DataClassName('GymTrainingUebungRow')
class GymTrainingUebungen extends Table {
  TextColumn get trainingId => text().named('training_id')();

  /// Die Position, **ab 1** — abgelegt, nicht aus der Zeilenreihenfolge der
  /// Abfrage gerechnet (dieselbe Begründung wie `gym_saetze.uebung_pos`).
  IntColumn get pos =>
      integer().customConstraint('NOT NULL CHECK (pos >= 1)')();

  /// Die `Exercise.id` aus dem Katalog. **Keine Prüfung gegen den Katalog in
  /// der Datenbank:** Eine ID, die der Katalog nicht (mehr) kennt, wird beim
  /// Lesen benannt (Spec 6.2), nicht beim Schreiben verhindert.
  TextColumn get uebungId => text().named('uebung_id')();

  IntColumn get saetze =>
      integer().customConstraint('NOT NULL CHECK (saetze >= 1)')();

  /// Untere Grenze des Wiederholungsbereichs, bei Zeitübungen Sekunden.
  IntColumn get wdhVon => integer()
      .named('wdh_von')
      .customConstraint('NOT NULL CHECK (wdh_von >= 1)')();

  IntColumn get wdhBis => integer()
      .named('wdh_bis')
      .customConstraint('NOT NULL CHECK (wdh_bis >= wdh_von)')();

  /// **Platz für #537.** `NULL` heißt „aus dem Katalog". Kein Schirm liest die
  /// Spalte als Eingabe, solange #537 nicht gebaut ist; die Ablage schreibt
  /// und liest sie, was sie bekommt (siehe `GymTrainingRepository`).
  RealColumn get steigerung => real().nullable()();

  @override
  Set<Column> get primaryKey => {trainingId, uebungId};

  /// Eine Position höchstens einmal je Training.
  @override
  List<Set<Column>> get uniqueKeys => [
    {trainingId, pos},
  ];
}

/// Die Tags eines Trainings in der Reihenfolge der Anzeige.
@DataClassName('GymTrainingTagRow')
class GymTrainingTags extends Table {
  TextColumn get trainingId => text().named('training_id')();

  /// Die Reihenfolge der Anzeige, **ab 1**.
  IntColumn get pos =>
      integer().customConstraint('NOT NULL CHECK (pos >= 1)')();

  /// Schon normalisiert (`WorkoutTags.normalize`).
  TextColumn get tag => text()();

  @override
  Set<Column> get primaryKey => {trainingId, tag};

  @override
  List<Set<Column>> get uniqueKeys => [
    {trainingId, pos},
  ];
}

/// Die gespeicherte Wochenrotation: geordnete Kennungen von Trainings,
/// **ohne Wochentage** (Spec 24 Nr. 2 — Wochentage sind #536 und bekommen dort
/// ihre eigene Stufe; eine Spalte auf Vorrat wäre eine Behauptung über einen
/// Entwurf, den es noch nicht gibt).
///
/// **Der Platz ist der Schlüssel, nicht die Kennung.** `UNIQUE (training_id)`
/// neben einem Schlüssel auf `training_id` wäre überflüssig; so ist „ein
/// Training steht höchstens einmal in der Rotation" (Spec 14.1) eine
/// Eigenschaft der Datenbank.
@DataClassName('GymRotationRow')
class GymRotation extends Table {
  /// Der Platz, **ab 1**.
  IntColumn get pos =>
      integer().customConstraint('NOT NULL CHECK (pos >= 1)')();

  /// Die Kennung eines Trainings. Kein Fremdschlüssel: Ob es das Training
  /// gibt, hält das Repository.
  TextColumn get trainingId => text().named('training_id')();

  @override
  Set<Column> get primaryKey => {pos};

  @override
  List<Set<Column>> get uniqueKeys => [
    {trainingId},
  ];
}
