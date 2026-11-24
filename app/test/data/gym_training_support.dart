import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show Database;
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/cache.dart';

/// Gemeinsame Hilfen der Tests zu **Repository, Rotation, Zwischenstand und
/// Trainingsname** der eigenen Trainings (#532, unter #531). Keine Testdatei
/// im engeren Sinn: Sie enthält nur Bauteile, keine Erwartung.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden.
///
/// Spezifikation: Spec
/// `docs/superpowers/specs/2026-11-19-eigene-trainings-design.md`,
/// Abschnitt 6 und die Nachträge 22 bis 25; Plan Task 1.6 und 1.8.
///
/// **Alle Namen, Zahlen und Zeitpunkte sind erfunden** (Jahr 2099); Tims
/// echte Trainings stehen nirgends im Quelltext.

/// Eine frische In-Memory-Datenbank. Beim Öffnen läuft `beforeOpen` — mit
/// der Startbefüllung (Push, Pull, Legs und die Rotation).
AppCache neueDb() {
  final db = AppCache(NativeDatabase.memory());
  addTearDown(db.close);
  return db;
}

/// Öffnet eine rohe Datei so, dass sie sich mehrfach hintereinander öffnen
/// lässt (`closeUnderlyingOnClose: false`) — ein App-Start nach dem anderen.
AppCache ueber(Database roh) =>
    AppCache(NativeDatabase.opened(roh, closeUnderlyingOnClose: false));

/// Öffnet **tatsächlich**: drift öffnet lazy, und `beforeOpen` läuft erst
/// beim ersten Zugriff.
Future<AppCache> oeffne(Database roh) async {
  final db = ueber(roh);
  await db.customSelect('SELECT 1;').get();
  return db;
}

/// Eine Übung eines Trainings. Vorgaben nur dort, wo ein Test sie nicht
/// selbst prüft.
WorkoutExercise uebung(
  String id, {
  int sets = 3,
  int repLow = 8,
  int repHigh = 12,
}) => WorkoutExercise(
  exerciseId: id,
  sets: sets,
  repLow: repLow,
  repHigh: repHigh,
  increment: null,
);

/// Zwei bekannte Übungen — jede Liste wird bei jedem Aufruf **neu** gebaut.
List<WorkoutExercise> zweiUebungen() => [
  uebung('benchPress', sets: 4, repLow: 6, repHigh: 10),
  uebung('lateralRaise', sets: 4, repLow: 12, repHigh: 20),
];

/// Ein eigenes Training, gültig, wenn nichts anderes verlangt ist.
WorkoutDefinition eigenes(
  String id, {
  String name = 'Oberkörper zuhause',
  List<String>? tags,
  List<WorkoutExercise>? exercises,
  int? enteredMinutes,
  bool isDraft = false,
}) => WorkoutDefinition(
  id: id,
  name: name,
  category: WorkoutCategory.own,
  tags: tags ?? ['Home'],
  exercises: exercises ?? zweiUebungen(),
  enteredMinutes: enteredMinutes,
  isDraft: isDraft,
);

/// Die Zeilen einer Tabelle, so wie sie in der Datei stehen.
Future<List<Map<String, Object?>>> zeilen(
  AppCache db,
  String tabelle, {
  String ordnung = 'rowid',
  String wo = '1 = 1',
}) async {
  final ergebnis = await db
      .customSelect('SELECT * FROM $tabelle WHERE $wo ORDER BY $ordnung;')
      .get();
  return [for (final z in ergebnis) z.data];
}

Future<int> anzahl(AppCache db, String tabelle, [String wo = '1 = 1']) async {
  final z = await db
      .customSelect('SELECT COUNT(*) AS n FROM $tabelle WHERE $wo;')
      .getSingle();
  return z.read<int>('n');
}

/// Die Rotation, wie sie in der Datei steht: (Platz, Kennung), nach Platz.
Future<List<(int, String)>> rotationInDatei(AppCache db) async => [
  for (final z in await zeilen(db, 'gym_rotation', ordnung: 'pos'))
    (z['pos']! as int, z['training_id']! as String),
];

/// Schreibt die Rotation **von Hand** in die Datei — die Stufe hat keinen
/// Schreiber außer der Einspielung (Spec 24 Nr. 4), also baut ein Test den
/// Stand, den er braucht, über SQL. Die Plätze zählen ab 1.
Future<void> setzeRotation(AppCache db, List<String> kennungen) async {
  await db.customStatement('DELETE FROM gym_rotation;');
  for (var i = 0; i < kennungen.length; i++) {
    await db.customStatement(
      'INSERT INTO gym_rotation (pos, training_id) '
      "VALUES (${i + 1}, '${kennungen[i]}');",
    );
  }
}

/// Die Kennungen der Übungen eines Trainings in der Reihenfolge der Datei.
Future<List<String>> uebungenInDatei(AppCache db, String trainingId) async => [
  for (final z in await zeilen(
    db,
    'gym_training_uebungen',
    ordnung: 'pos',
    wo: "training_id = '$trainingId'",
  ))
    z['uebung_id']! as String,
];

/// Wie viele Zeilen ein Training in allen drei Tabellen hat.
Future<(int, int, int)> zeilenVon(AppCache db, String trainingId) async => (
  await anzahl(db, 'gym_trainings', "id = '$trainingId'"),
  await anzahl(db, 'gym_training_uebungen', "training_id = '$trainingId'"),
  await anzahl(db, 'gym_training_tags', "training_id = '$trainingId'"),
);

/// Alle drei Tabellen eines Trainings als Zeilen — für „nichts hat sich
/// geändert"-Vergleiche.
Future<Map<String, List<Map<String, Object?>>>> abbild(
  AppCache db,
  String trainingId,
) async => {
  'gym_trainings': await zeilen(db, 'gym_trainings', wo: "id = '$trainingId'"),
  'gym_training_uebungen': await zeilen(
    db,
    'gym_training_uebungen',
    ordnung: 'pos',
    wo: "training_id = '$trainingId'",
  ),
  'gym_training_tags': await zeilen(
    db,
    'gym_training_tags',
    ordnung: 'pos',
    wo: "training_id = '$trainingId'",
  ),
};

/// Ein laufendes Training der **Erfassung** (`gym_entwuerfe`), von Hand
/// geschrieben — für die Sperre aus Spec 4.7. Die Spalte `workout` trägt
/// die Kennung des Trainings, auch eine UUID.
Future<void> laufendesTraining(AppCache db, String kennung) =>
    db.customStatement(
      'INSERT INTO gym_entwuerfe '
      '(id, workout, sitzung_id, zeitpunkt, dauer, notiz, gespeichert_am, '
      'felder) '
      "VALUES (0, '$kennung', 'PRUEF-SITZUNG', "
      "'2099-03-08T17:00:00.000Z', '55', NULL, "
      "'2099-03-08T17:20:00.000Z', '{\"p\":1}');",
    );

/// Das Gerüst der vier neuen Tabellen — wörtlich die Form aus Spec 4.1/4.2
/// und aus `schema_v25_test.dart` (`tabellenVorweg`, ohne `gym_rotation`
/// bzw. mit). Für die Tests, die einen **Altstand** brauchen, den ein
/// anderer Zweig angelegt haben könnte.
const ddlTrainings = '''
  CREATE TABLE gym_trainings (
    id TEXT NOT NULL,
    name TEXT NOT NULL,
    kategorie TEXT NOT NULL CHECK (kategorie IN ('template', 'eigene')),
    dauer_eingetragen_min INTEGER NULL,
    ist_entwurf INTEGER NOT NULL DEFAULT 0 CHECK (ist_entwurf = 0 OR kategorie = 'eigene'),
    geloescht INTEGER NOT NULL DEFAULT 0 CHECK (geloescht = 0 OR kategorie = 'template'),
    reihenfolge INTEGER NOT NULL,
    entwurf_von TEXT NULL CHECK (entwurf_von IS NULL OR (ist_entwurf = 1 AND kategorie = 'eigene')),
    PRIMARY KEY (id),
    UNIQUE (entwurf_von)
  );
  CREATE TABLE gym_training_uebungen (
    training_id TEXT NOT NULL,
    pos INTEGER NOT NULL CHECK (pos >= 1),
    uebung_id TEXT NOT NULL,
    saetze INTEGER NOT NULL CHECK (saetze >= 1),
    wdh_von INTEGER NOT NULL CHECK (wdh_von >= 1),
    wdh_bis INTEGER NOT NULL CHECK (wdh_bis >= wdh_von),
    steigerung REAL NULL,
    PRIMARY KEY (training_id, uebung_id),
    UNIQUE (training_id, pos)
  );
  CREATE TABLE gym_training_tags (
    training_id TEXT NOT NULL,
    pos INTEGER NOT NULL CHECK (pos >= 1),
    tag TEXT NOT NULL,
    PRIMARY KEY (training_id, tag),
    UNIQUE (training_id, pos)
  );
''';

const ddlRotation = '''
  CREATE TABLE gym_rotation (
    pos INTEGER NOT NULL CHECK (pos >= 1),
    training_id TEXT NOT NULL,
    PRIMARY KEY (pos),
    UNIQUE (training_id)
  );
''';

/// `gym_sitzungen` auf Stand v24, wörtlich aus `schema_v25_test.dart`
/// (`v24Schema`) — ohne `trainings_name`. Die Altdateien der Tests unten
/// tragen sie, damit die Stufe ihre Spalte an eine **vorhandene** Tabelle
/// hängt; den Fall „Tabelle fehlt ganz" prüft `schema_v25_test.dart`.
const ddlSitzungenV24 = '''
  CREATE TABLE gym_sitzungen (
    id TEXT NOT NULL,
    tag TEXT NOT NULL,
    zeitpunkt TEXT NOT NULL,
    workout TEXT NULL,
    minuten INTEGER NULL,
    notiz TEXT NULL,
    health_uuid TEXT NULL,
    aufwaermen_art TEXT NULL CHECK (aufwaermen_art IS NULL OR aufwaermen_art IN ('bike', 'treadmill', 'rowing', 'cross_trainer', 'jump_rope', 'mobility')),
    aufwaermen_minuten INTEGER NULL,
    aufwaermen_km REAL NULL,
    aufwaermen_uebersprungen INTEGER NOT NULL DEFAULT 0 CHECK (aufwaermen_uebersprungen IN (0, 1)),
    aufwaermen_health_uuid TEXT NULL,
    PRIMARY KEY (id),
    UNIQUE (tag, workout)
  );
''';
