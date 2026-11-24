// Die drei Gym-Tabellen (Schema v18, #78 mit #40 und #418): die
// abgeschlossene Sitzung, ihre Sätze und der Zwischenstand eines laufenden
// Trainings. Entwurf:
// `docs/superpowers/specs/2026-11-10-gym-training-eintragen-design.md`,
// Abschnitt 10.2 („Weg B — eigene Tabellen") und 11.
//
// Form und Namen gibt `app/test/data/schema_v18_test.dart` verbindlich vor
// (siehe Dateikopf dort) — diese Datei darf den Test ausführen, aber nicht
// verändern (`CLAUDE.md`, „Wer Tests schreibt, schreibt nicht die
// Implementierung").
//
// **Zweite Tabellengruppe (Spec 5.6a): `Messwert<T>` gilt hier nicht.**
// Gym-Trainings sind Tims eigene Daten; leer heißt leer. Und bis die
// Übernahme (#59) gelaufen ist, ist das iPhone seine einzige Kopie davon —
// deshalb nimmt keine Stufe und keine Abfrage hier etwas weg.
//
// **Zwei Tabellen für die Sitzung, nicht drei.** Eine `gym_uebungen`
// zwischen Sitzung und Satz trüge drei Spalten und wäre bei jeder Abfrage
// ein Join mehr; sie verdiente ihr Geld nur, wenn es eine Übung ohne Sätze
// geben könnte. Die gibt es nicht — und dass sie es nicht gibt, hält
// `GymRepository.legeAb` fest statt einer stillschweigenden Annahme
// (Spec 10.2).
import 'package:drift/drift.dart';

/// Die abgelegten Codes der sechs Aufwärm-Arten (#40) — wortgleich mit
/// `WarmUpKind.code` im Kern.
///
/// **Sie stehen hier ein zweites Mal, und das ist Absicht.** Die
/// `CHECK`-Bedingung wird in die Datei geschrieben; sie muss deshalb beim
/// Erzeugen des Schemas als Zeichenkette vorliegen, nicht erst zur Laufzeit
/// aus dem Enum kommen. Wer dem Kern eine siebte Art gibt, trägt sie hier
/// nach — und zwar in einer **neuen Stufe**, denn eine `CHECK`-Bedingung
/// steht in `CREATE TABLE` und ändert sich nicht von selbst.
const gymAufwaermArten = [
  'bike',
  'treadmill',
  'rowing',
  'cross_trainer',
  'jump_rope',
  'mobility',
];

/// Ein abgeschlossenes Gym-Training — eine Zeile je Sitzung.
///
/// **Das Aufwärmen (#40) steht in Spalten, nicht in einer eigenen
/// Tabelle.** Es gibt eine Einheit je Sitzung, sie wird immer zusammen mit
/// der Sitzung gelesen und kann ohne sie nicht bestehen — dieselbe
/// Begründung, mit der die Spec `gym_uebungen` wegließ. Die drei Zustände
/// („nichts eingetragen", „übersprungen", „ausgefüllt") stehen in
/// [aufwaermenArt] und [aufwaermenUebersprungen] zusammen; drei nullbare
/// Felder allein könnten die ersten beiden nicht unterscheiden.
@DataClassName('GymSitzungRow')
class GymSitzungen extends Table {
  /// Die UUID der Einheit, vergeben beim Anlegen (#418 Punkt 1) — der
  /// Schlüssel, unter dem die Uhr später über denselben Trainingstag
  /// spricht.
  TextColumn get id => text()();

  /// Der Berliner Kalendertag als ISO-Tagesschlüssel, aus
  /// `BerlinCalendar.dayKey(ImportedSession.date)` gerechnet. **Nicht der
  /// UTC-Kalendertag** — ein Training um 00:30 Berliner Zeit liegt auf dem
  /// UTC-Tag davor. Gefiltert wird über diese Spalte, lexikografisch
  /// (`CLAUDE.md`).
  TextColumn get tag => text()();

  /// Der Zeitpunkt des Abschlusses, **mit Uhrzeit**, als UTC. TEXT in der
  /// Datei (`storeDateTimeAsText`).
  DateTimeColumn get zeitpunkt => dateTime()();

  /// Die **Kennung des Trainings**: für ein Training mit Enum-Fall sein
  /// `Workout.code` (`'A'`, `'Push'`, …), für jedes andere die UUID eines
  /// eigenen Trainings (ab Schema v25, Spec 4.6). **Der Name der Spalte ist
  /// damit ungenau und bleibt:** `UNIQUE (tag, workout)` steht in
  /// `CREATE TABLE`, SQLite kann das nicht ändern, ohne die Tabelle neu zu
  /// bauen und umzukopieren — und ein Neubau dieser Tabelle ist das Risiko,
  /// das Tims einzige Kopie seiner Trainings nicht eingehen darf. Weil die
  /// Spalte keine `CHECK`-Bedingung auf ihre Werte hat, nimmt sie die UUID
  /// ohne Eingriff.
  ///
  /// **Nullbar**: Die Übernahme aus dem Dashboard (#59) kennt Trainings ohne
  /// geführtes Workout, und einem zuzuschlagen hieße raten.
  TextColumn get workout => text().nullable()();

  /// Dauer in Minuten, `null` heißt „nicht erfasst" und nicht „null
  /// Minuten" (Fehler `01`).
  IntColumn get minuten => integer().nullable()();

  /// Freitext, `null` statt der leeren Zeichenkette — die zeichnete eine
  /// leere Notizzeile.
  TextColumn get notiz => text().nullable()();

  /// Die UUID des von der App geschriebenen `HKWorkout` (#418 Punkt 2).
  /// Geschrieben wird sie erst vom Lückenfüller; hier entsteht nur die
  /// Spalte.
  TextColumn get healthUuid => text().named('health_uuid').nullable()();

  /// Womit aufgewärmt wurde, als `WarmUpKind.code`.
  ///
  /// **Der Wertebereich steht in der Datei, nicht nur im Dart-Enum** (#40:
  /// „Freitext lässt sich später nicht vergleichen, und vergleichen ist der
  /// Zweck"). Eine fremde Zeichenkette fiele sonst erst Monate später auf —
  /// beim Vergleichen.
  ///
  /// `customConstraint` und nicht `check(…)`: Die Bedingung muss als
  /// Literal in `CREATE TABLE` landen, damit sie auch dort steht, wo der
  /// Abgleich (#233) die Spalte nachträgt.
  ///
  /// **Die Bedingung steht hier ausgeschrieben und nicht als Konstante.**
  /// drifts Generator liest `customConstraint` zur Kompilierzeit und löst
  /// dabei keine Konstante auf — er übernimmt sie stillschweigend nicht,
  /// und im `CREATE TABLE` fehlt dann die Prüfung, während der Dart-Code
  /// unverändert übersetzt. Dasselbe Muster wie beim `@Test`-Makro in
  /// Swift Testing, das ebenfalls ein echtes Literal verlangt. Aufgefallen
  /// ist es nur, weil `schema_v18_test.dart` die Form der Datei prüft und
  /// nicht das Dart-Enum.
  ///
  /// `NULL` gehört mit in die Zeichenkette: `customConstraint` ersetzt
  /// **alle** erzeugten Bedingungen der Spalte, auch die Nullbarkeit.
  TextColumn get aufwaermenArt =>
      text().named('aufwaermen_art').nullable().customConstraint(
        "NULL CHECK (aufwaermen_art IS NULL OR aufwaermen_art IN "
        "('bike', 'treadmill', 'rowing', 'cross_trainer', 'jump_rope', "
        "'mobility'))",
      )();

  /// Die Dauer des Aufwärmens. Sie steht **neben** [minuten] und nicht
  /// darin — sonst wüchse die Trainingsdauer, ohne dass mehr trainiert
  /// wurde (#40, „Zu klären").
  IntColumn get aufwaermenMinuten =>
      integer().named('aufwaermen_minuten').nullable()();

  /// Die Strecke in Kilometern — **auch im ausgefüllten Fall nullbar**:
  /// Bei Mobility gibt es keine, und wer aufs Rad steigt, ohne die Anzeige
  /// abzulesen, ist trotzdem gefahren. Eine `0` behauptete „null Kilometer
  /// gelaufen", und daraus rechnete die Steigerungskarte einen Rückschritt.
  RealColumn get aufwaermenKm => real().named('aufwaermen_km').nullable()();

  /// Ob das Aufwärmen bewusst übersprungen wurde.
  ///
  /// **`NOT NULL` mit Vorgabe `0`**, und das ist die Wahrheit über eine
  /// Zeile, bei der niemand etwas eingetragen hat: nicht übersprungen,
  /// sondern nichts gesagt. „Übersprungen" ist eine Antwort und wird nur
  /// gesetzt, wenn jemand sie gegeben hat (#40).
  BoolColumn get aufwaermenUebersprungen => boolean()
      .named('aufwaermen_uebersprungen')
      .withDefault(const Constant(false))();

  /// Die UUID des Health-Workouts, das zu diesem Aufwärmen gehört — ein
  /// Ablageschlüssel, kein Kernwert. Zugeordnet wird erst mit #414.
  TextColumn get aufwaermenHealthUuid =>
      text().named('aufwaermen_health_uuid').nullable()();

  /// Der Name des Trainings **zum Zeitpunkt der Sitzung** (Schema v25, #532,
  /// Spec 4.6) — der Verlauf friert ein: Umbenennen und Löschen eines
  /// Trainings schreiben ihn nicht um.
  ///
  /// **Nullbar und ohne Vorgabewert.** Eine alte Zeile bekommt keinen
  /// erfundenen Namen, `NULL` bleibt `NULL` — „Gym A" aus dem Enum
  /// hineinzuschreiben hieße zu behaupten, die Sitzung habe ihn zu ihrer
  /// Zeit getragen. Die Auflösung beim Lesen (`WorkoutNaming.title`) braucht
  /// keinen Eintrag.
  TextColumn get trainingsName => text().named('trainings_name').nullable()();

  @override
  Set<Column> get primaryKey => {id};

  /// „Wird ersetzt, nicht verdoppelt" (Spec 10.4 Punkt 3) als Eigenschaft
  /// der Datenbank.
  ///
  /// **Als `UNIQUE` im Tabellenkopf, nicht als eigenes
  /// `CREATE UNIQUE INDEX`:** `_reconcileSchema` kennt keine Indizes, ein
  /// eigenständiger stünde also auf Geräten, die die Stufe 18 gelaufen
  /// sind, und fehlte auf denen, die die Tabelle über den Abgleich bekommen
  /// haben.
  ///
  /// **Er trägt „kein Workout" nicht mit.** SQLite hält zwei `NULL` für
  /// verschieden; `GymSessionMerge` führt „kein Workout" dagegen als
  /// **einen** Schlüssel. Deshalb vergleicht `GymRepository.legeAb` beim
  /// Nachtragen selbst mit `IS` — dieser Constraint bleibt die zusätzliche
  /// Sicherung für den Nicht-NULL-Fall. In der Spalte steht weiter `NULL`
  /// und nicht `'?'`: Ein Platzhalter wäre eine stille Verfälschung.
  @override
  List<Set<Column>> get uniqueKeys => [
    {tag, workout},
  ];
}

/// Ein einzelner Satz. Die Reihenfolge steht in [uebungPos] und [satzNr],
/// **nicht** in [zeitpunkt]: Eine Sitzung aus der Übernahme (#59) hat gar
/// keine Satz-Uhrzeiten und trotzdem eine eindeutige Reihenfolge.
@DataClassName('GymSatzRow')
class GymSaetze extends Table {
  TextColumn get sitzungId => text().named('sitzung_id')();

  /// Die `Exercise.id` aus dem Katalog.
  TextColumn get uebungId => text().named('uebung_id')();

  /// Die Position der Übung in der Sitzung, **ab 1**.
  ///
  /// Abgelegt und nicht aus `GymSessionOrder.ordered` gerechnet: Die
  /// Reihenfolge geht in `ImportedSession.==` ein, gehört also zur Sitzung.
  /// Rechnete man sie beim Laden neu, änderte eine Umsortierung des
  /// Katalogs rückwirkend, in welcher Reihenfolge Tim vor einem Jahr
  /// trainiert hat.
  IntColumn get uebungPos => integer().named('uebung_pos')();

  /// Die Nummer des Satzes innerhalb der Übung, **ab 1** — damit „Satz 1"
  /// in der Datei auch Satz 1 ist.
  IntColumn get satzNr => integer().named('satz_nr')();

  /// Kilogramm. **Negativ heißt Unterstützung** (−27 sind 27 kg Hilfe der
  /// Maschine), `0.0` heißt eigenes Körpergewicht. Beides sind Werte, keine
  /// Lücken.
  RealColumn get gewichtKg => real().named('gewicht_kg')();

  /// Wiederholungen — bei Zeitübungen Sekunden.
  IntColumn get wdh => integer()();

  /// Wann der Satz **eingetragen** wurde, als UTC — **nullbar und ohne
  /// Vorgabewert.**
  ///
  /// `null` heißt „nicht erfasst", und das ist der **Normalfall**: Die
  /// Übernahme aus der alten App (#59) bringt Tims gesamten bisherigen
  /// Verlauf, und dort gibt es keine Satz-Uhrzeiten. Ein Vorgabewert — ob
  /// `now`, ob `0`, ob Epoch-Null — behauptete, der Satz sei zu dieser
  /// Minute entstanden (Spec 11, Tim 10.11.2026).
  DateTimeColumn get zeitpunkt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {sitzungId, uebungId, satzNr};
}

/// Der Zwischenstand eines laufenden Trainings — **genau eine Zeile**.
///
/// `id` mit Vorgabe `0` als Schlüssel, dasselbe Muster wie `ziel_werte`,
/// `stammdaten` und `ki_einstellungen`: „Ein Entwurf, nicht sieben" (Tim,
/// 10.11.2026) ist damit eine Eigenschaft der Datenbank und nicht nur eine
/// Regel im Dart-Code. Die Spec zeichnet in 10.2 `workout` als Schlüssel;
/// sie ist dort älter als die Entscheidung.
///
/// **Der Entwurf ist Schmierzettel, kein Datensatz.** [dauer] und [felder]
/// tragen rohen Text, so wie getippt — „62,", „abc", ein halb getippter
/// Wert. Eine Spalte `gewicht REAL` könnte das gar nicht aufnehmen.
@DataClassName('GymEntwurfRow')
class GymEntwuerfe extends Table {
  /// Immer `0` — die Tabelle trägt **einen** Entwurf, nicht sieben (Tims
  /// Entscheidung vom 10.11.2026; wer ein zweites Training anfängt,
  /// bekommt eine Rückfrage).
  ///
  /// **Das `CHECK` ist nötig, der Vorgabewert allein trägt nicht.** Eine
  /// `INTEGER`-Spalte, die alleiniger Primärschlüssel ist, wird in SQLite
  /// zum Alias der `rowid`: Fehlt die Spalte beim Einfügen, vergibt SQLite
  /// selbst eine Nummer und **übergeht den `DEFAULT` stillschweigend**.
  /// Ohne das `CHECK` stünden nach zwei rohen Einfügungen zwei Entwürfe
  /// da, obwohl die Spalte das Gegenteil behauptet — eine Zusage, die der
  /// Code nicht durchsetzt. Aufgefallen beim Bauen: Der Test „die
  /// Datenbank selbst lässt keine zweite Zeile zu" war mit der vorigen
  /// Form in keiner Implementierung erfüllbar.
  ///
  /// Dieselbe Falle steht in `ziel_werte`, `stammdaten` und
  /// `ki_einstellungen`; dort hält die Eindeutigkeit nur, weil jeder
  /// Schreibweg die `id` ausdrücklich setzt.
  IntColumn get id => integer()
      .withDefault(const Constant(0))
      .customConstraint('NOT NULL DEFAULT 0 CHECK (id = 0)')();

  /// Die Kennung des Trainings — `Workout.code` oder, ab Schema v25, die
  /// UUID eines eigenen Trainings (Spec 4.7) — **nicht nullbar**: Ein Entwurf
  /// ohne Training wäre keiner, die Fokus-Karte zeigt ihn unter seinem
  /// Namen.
  TextColumn get workout => text()();

  /// Die UUID, die die fertige Sitzung tragen wird (#418 Punkt 1).
  TextColumn get sitzungId => text().named('sitzung_id')();

  /// Das eingestellte Datum des Trainings, als UTC.
  DateTimeColumn get zeitpunkt => dateTime()();

  /// Die getippte Dauer als **roher Text**, nullbar.
  TextColumn get dauer => text().nullable()();

  TextColumn get notiz => text().nullable()();

  /// Wann zuletzt zwischengespeichert wurde — für den Haken in der Leiste.
  DateTimeColumn get gespeichertAm => dateTime().named('gespeichert_am')();

  /// Die Satzzeilen als JSON-Text, roh. Je Übung der Umschalterzustand und
  /// die getippten Felder.
  TextColumn get felder => text()();

  @override
  Set<Column> get primaryKey => {id};
}
