// Die reine Hälfte der RepDB-Einbindung (#38): Konstanten und Funktionen,
// die RepDB-Daten in das Asset-Format der App umwandeln. Kein Netz, keine
// Dateien, keine Seiteneffekte — deshalb ohne Mocks testbar
// (`scripts/test/exercises-convert.test.mjs`, `node --test scripts/test/`).
//
// Laden und Schreiben steht in `exercises-asset.mjs`.
//
// Lizenz: Die Daten stehen unter der RepDB-Free-Tier-Lizenz, siehe
// `app/assets/exercises/LICENSE-DATA.md`. Sichtbare Attribution ist Pflicht
// (`ATTRIBUTION`, in der App `repdbAttribution`), Weiterverteilung als
// Datensatz ist verboten, und die Bilder dürfen nicht als Eingabe oder
// Referenz für generative Modelle dienen.

/** Der gepinnte Stand des Datensatzes (Release `free-708-2026-11`, 708 Übungen, 14.11.2026). */
export const REPDB_COMMIT = '4b1358a63c9f78f982867726f2a73c0f6cb21475';

export const REPDB_RAW_BASE =
  `https://raw.githubusercontent.com/RepDB/exercise-dataset/${REPDB_COMMIT}/`;

/**
 * SHA-256 der `exercises.json` dieses Stands (2 635 980 Byte). Derselbe Pin
 * liefert dieselben Bytes, sonst bricht `exercises-source.mjs` ab. Wandert der
 * Pin, wandert diese Summe mit — gemessen am ersten Download (Spec 5.7,
 * Nachtrag 18).
 */
export const REPDB_EXERCISES_SHA256 =
  'ad7c602fcc6bd4322b6228673c0fff5ad60b87f219352d44f9b92a763835948f';

/** Das Schema, für das diese Umwandlung geschrieben ist. Ein anderes wirft. */
export const SCHEMA_VERSION = 3;

/**
 * Pflichtangabe der Lizenz (Punkt 2). Das Gegenstück in der App steht in
 * `app/lib/gym/uebungsbilder.dart`; `test/gym/uebungsbilder_test.dart` hält
 * beide zusammen.
 */
export const ATTRIBUTION = 'Exercise data by RepDB (repdb.co)';

/** Spaltennamen des Assets. Die App prüft sie beim Einlesen gegen dieselbe Liste. */
export const FIELDS = [
  'id', 'en', 'de', 'terms', 'primary', 'secondary', 'equipment',
  'compound', 'unilateral', 'images', 'steps', 'tips', 'assisted',
];

/** Vorsatz der Bildpfade im Datensatz. Im Asset steht nur der Dateiname. */
export const IMAGE_PREFIX = 'images/flat/';

/**
 * Anatomische Slugs auf die Muskelgruppen der App (`Muscle.code` in
 * `Packages/trainings_core/lib/src/muscle.dart`). `null` = nicht anzeigen.
 *
 * Abweichung von der Tabelle im Ticket: Das Ticket nennt Regionen einer
 * früheren Oberfläche (`frontDelts`, `abs`, `neck`, `adductors`). Die App
 * kennt 16 Gruppen, und `test/gym/uebungsbilder_test.dart` prüft, dass jeder
 * Code im Asset eine davon ist. Deshalb: Bauch und Schräge zusammen als
 * `core`, der Trapezmuskel als `upperBack`, die Adduktoren gar nicht (die
 * App hat keine Gruppe dafür).
 */
export const MUSCLE_REGION = {
  pectoralis_major: 'chest',
  anterior_deltoid: 'frontDelt',
  lateral_deltoid: 'sideDelt',
  supraspinatus: 'sideDelt',
  posterior_deltoid: 'rearDelt',
  // Neu seit RepDB v1.51 (#555). Zuordnung des Implementierers, nicht von Tim
  // gesehen: hintere Rotatorenmanschette -> hintere Schulter, wie `supraspinatus`
  // auf die Schulterkopf-Gruppe geht. `null` ließe `cable-external-rotation`
  // aus der Bibliothek fallen.
  infraspinatus_teres_minor: 'rearDelt',
  biceps_brachii: 'biceps',
  brachialis: 'biceps',
  triceps_brachii: 'triceps',
  brachioradialis: 'forearms',
  forearm_flexors: 'forearms',
  forearm_extensors: 'forearms',
  forearms: 'forearms',
  gastrocnemius: 'calves',
  soleus: 'calves',
  latissimus_dorsi: 'lats',
  rhomboids: 'upperBack',
  trapezius: 'upperBack',
  erector_spinae: 'lowerBack',
  quadratus_lumborum: 'lowerBack',
  rectus_abdominis: 'core',
  transverse_abdominis: 'core',
  obliques: 'core',
  gluteus_maximus: 'glutes',
  gluteus_medius: 'glutes',
  abductors: 'glutes',
  quadriceps: 'quads',
  hamstrings: 'hamstrings',
  tibialis_anterior: 'tibialis',
  adductors: null,
  hip_flexors: null,
  serratus_anterior: null,
};

/** Gruppe → RepDB-Werte. Umgedreht ergibt das `EQUIPMENT_GROUP`. */
export const EQUIPMENT_GROUPS = {
  barbell: ['barbell', 'trap_bar'],
  dumbbell: ['dumbbell'],
  ezBar: ['ez_bar'],
  kettlebell: ['kettlebell'],
  cable: ['cable'],
  machine: [
    'smith_machine', 'leg_press', 'hack_squat', 'leg_curl', 'leg_extension',
    'pec_deck', 'dip_machine', 'plate_loaded_dip_machine',
    'assisted_pullup_machine', 'lat_pulldown_machine', 'seated_row_machine',
    'chest_press_machine', 'chest_fly_machine', 'shoulder_press_machine',
    'reverse_fly_machine', 'bicep_curl_machine', 'preacher_curl_machine',
    'tricep_extension_machine', 'back_extension_machine',
    'hip_abduction_machine', 'hip_adduction_machine', 'ab_crunch_machine',
    'standing_calf_raise_machine', 'seated_calf_raise_machine',
    'donkey_calf_raise_machine', 'hip_thrust_machine',
    'plate_loaded_lateral_raise_machine', 'shrug_machine',
    'glute_ham_developer',
  ],
  bodyweight: [
    '', 'pull_up_bar', 'dip_station', 'rings', 'suspension_trainer',
  ],
  band: ['resistance_band', 'loop_band'],
  other: [
    'flat_bench', 'plyo_box', 'stability_ball', 'medicine_ball', 'slam_ball',
    'wall_ball', 'plates', 'battle_rope', 'climbing_rope', 'sled',
    'wrist_roller', 'ab_wheel', 'jump_rope', 'air_bike', 'bicycle',
    'stationary_bike', 'elliptical', 'treadmill', 'rower', 'ski_erg',
    'stair_climber',
    // Neu im November-Release (#555), Zuordnung des Implementierers.
    'bosu_ball', 'sandbag',
  ],
};

export const EQUIPMENT_GROUP = Object.fromEntries(
  Object.entries(EQUIPMENT_GROUPS).flatMap(([group, values]) =>
    values.map((value) => [value, group])),
);

/**
 * Bei diesen ist das Gewicht die *Unterstützung*, nicht die Last. Ein
 * Volumen, das sie wie eine Last rechnet, rechnet herum falsch.
 */
export const ASSISTED_IDS = ['assisted-dips', 'assisted-pull-ups'];

/**
 * Korrekturen der maschinellen deutschen Texte, `{ [id]: { de?, en?, terms? } }`.
 * Jede ID muss im Datensatz stehen (`toExerciseAsset` wirft sonst), damit
 * keine Korrektur beim nächsten Update unbemerkt verwaist.
 */
export const CORRECTIONS = {
  // Der deutsche Name ist dem englischen gleich.
  'dips': { de: 'Dips an der Dip-Station' },
  'side-plank': { de: 'Seitstütz' },
  // Halb englisch.
  'cable-overhead-tricep-extension': {
    de: 'Trizeps-Extension über Kopf am Kabelzug',
  },
};

// Nur Wörter, die im Deutschen niemand sagt. „Curl", „Fly", „Press" oder
// „Plank" fehlen mit Absicht: Das ist Fitnessstudio-Deutsch, auch im Katalog
// der App („Hammer Curls", „Reverse Flys").
const ENGLISH_WORD = new RegExp(
  '\\b(dumbbell|barbell|cable|machine|raise|standing|seated|lying|incline|' +
    'decline|bench|bodyweight|overhead|grip|single)\\b',
  'i',
);

/**
 * Findet maschinelle Halb-Übersetzungen („Standing Dumbbell Wadenheben"):
 * Der deutsche Name ist dem englischen gleich oder trägt ein englisches
 * Fachwort. Ein Verdacht, kein Beweis — deshalb lässt sich jede Meldung
 * durch eine Korrektur in `CORRECTIONS` quittieren, auch mit demselben Text.
 */
export function suspiciousGermanName(en, de) {
  return de === en || ENGLISH_WORD.test(de);
}

/** Wirft, wenn das Schema nicht das erwartete ist. */
export function assertSchema(repdb) {
  if (repdb?.schema_version !== SCHEMA_VERSION) {
    throw new Error(
      `RepDB schema_version ${repdb?.schema_version}, erwartet ` +
        `${SCHEMA_VERSION}: Die Umwandlung ist für dieses Schema nicht geprüft.`,
    );
  }
  if (!Array.isArray(repdb.exercises)) {
    throw new Error('RepDB-Datensatz ohne `exercises`-Liste.');
  }
}

/**
 * Die Bilddateien einer Übung, mit Pfad, in fester Reihenfolge. Genau zwei
 * Formen sind erlaubt: `{main}` oder `{start, peak}`; alles andere wirft.
 */
export function imagePaths(exercise) {
  const flat = exercise?.images?.flat;
  const keys = flat && typeof flat === 'object' ? Object.keys(flat).sort() : [];
  const isMain = keys.length === 1 && keys[0] === 'main';
  const isPair = keys.length === 2 && keys[0] === 'peak' && keys[1] === 'start';
  if (!isMain && !isPair) {
    throw new Error(
      `Übung ${exercise?.id}: unbekannte Bildform ${JSON.stringify(flat)}`,
    );
  }
  const paths = isMain ? [flat.main] : [flat.start, flat.peak];
  for (const path of paths) {
    if (typeof path !== 'string' || !path.startsWith(IMAGE_PREFIX)) {
      throw new Error(`Übung ${exercise.id}: unerwarteter Bildpfad ${path}`);
    }
  }
  return paths;
}

/** Wie `imagePaths`, aber nur die Dateinamen — das Präfix kennt der Client. */
function imageNames(exercise) {
  const paths = imagePaths(exercise);
  const names = paths.map((path) => path.slice(IMAGE_PREFIX.length));
  return names.length === 1
    ? { main: names[0] }
    : { start: names[0], peak: names[1] };
}

function regions(slugs, exerciseId) {
  const result = [];
  for (const slug of slugs ?? []) {
    if (!Object.hasOwn(MUSCLE_REGION, slug)) {
      throw new Error(`Übung ${exerciseId}: unbekannter Muskel „${slug}"`);
    }
    const region = MUSCLE_REGION[slug];
    if (region !== null && !result.includes(region)) result.push(region);
  }
  return result;
}

function equipmentGroup(exercise) {
  const value = exercise.equipment ?? '';
  if (!Object.hasOwn(EQUIPMENT_GROUP, value)) {
    throw new Error(`Übung ${exercise.id}: unbekanntes Equipment „${value}"`);
  }
  return EQUIPMENT_GROUP[value];
}

/**
 * Sucht für die Suche: Kleinbuchstaben, Umlaute und Akzente gefaltet, in
 * einzelne Wörter zerlegt. Anfrage und Suchbegriffe müssen dieselbe
 * Faltung durchlaufen.
 */
export function foldSearch(text) {
  return text
    .toLowerCase()
    .replaceAll('ß', 'ss')
    .normalize('NFD')
    .replace(/\p{M}/gu, '')
    .split(/[^a-z0-9]+/)
    .filter((word) => word.length > 0);
}

/**
 * Die Suchwörter einer Übung: die Wörter beider Namen, ohne Dubletten, in
 * der Reihenfolge ihres ersten Auftretens. Stehen unter `CORRECTIONS`
 * `terms`, ersetzen die das Ergebnis.
 */
function searchTerms(en, de, correction) {
  if (correction?.terms) return correction.terms.flatMap(foldSearch);
  return [...new Set([...foldSearch(en), ...foldSearch(de)])];
}

/**
 * Wandelt den RepDB-Datensatz ins Asset-Format: `{fields, exercises}`, jede
 * Übung ein Array in der Reihenfolge von `FIELDS`. Rein — dieselbe Eingabe
 * gibt dieselbe Ausgabe.
 *
 * Wirft bei: falschem Schema, unbekanntem Muskel, unbekanntem Equipment,
 * unbekannter Bildform, einer Korrektur oder Assisted-Markierung auf eine
 * ID, die es nicht gibt, und (bei `strictGerman`) einem verdächtigen
 * deutschen Namen ohne Korrektur.
 *
 * `only` schränkt die Ausgabe auf diese IDs ein; jede muss existieren.
 * Muskel-, Equipment-, Bild- und Namensprüfung gelten nur für die
 * Ausgewählten — ein Update, das eine nicht gewählte Übung ändert, hält den
 * Lauf nicht an. Die ID-Prüfungen (Korrekturen, Assisted, Auswahl) gelten
 * immer für den ganzen Datensatz.
 */
export function toExerciseAsset(
  repdb,
  { corrections = CORRECTIONS, only = null, strictGerman = true } = {},
) {
  assertSchema(repdb);
  const byId = new Map(repdb.exercises.map((e) => [e.id, e]));
  if (byId.size !== repdb.exercises.length) {
    throw new Error('RepDB-Datensatz mit doppelter Übungs-ID.');
  }
  for (const id of Object.keys(corrections)) {
    if (!byId.has(id)) {
      throw new Error(`Korrektur für unbekannte Übung „${id}" — verwaist?`);
    }
  }
  for (const id of ASSISTED_IDS) {
    if (!byId.has(id)) {
      throw new Error(`Assisted-Markierung für unbekannte Übung „${id}"`);
    }
  }
  for (const id of only ?? []) {
    if (!byId.has(id)) throw new Error(`Gewählte Übung „${id}" fehlt im Datensatz.`);
  }
  const chosen = only ? new Set(only) : null;

  const warnings = [];
  const exercises = [];
  for (const e of repdb.exercises) {
    if (chosen && !chosen.has(e.id)) continue;
    const correction = corrections[e.id];
    const en = correction?.en ?? e.name_en;
    const de = correction?.de ?? e.name_de;
    if (!correction?.de && suspiciousGermanName(e.name_en, e.name_de)) {
      const message =
        `Übung ${e.id}: deutscher Name „${e.name_de}" sieht unübersetzt ` +
        'aus — Korrektur in CORRECTIONS eintragen.';
      if (strictGerman) throw new Error(message);
      warnings.push(message);
    }
    const primary = regions(e.primary_muscles, e.id);
    const secondary = regions(e.secondary_muscles, e.id)
      .filter((region) => !primary.includes(region));
    exercises.push([
      e.id,
      en,
      de,
      searchTerms(en, de, correction),
      primary,
      secondary,
      equipmentGroup(e),
      e.mechanic === 'compound',
      e.is_unilateral === true,
      imageNames(e),
      { en: e.instructions_en ?? [], de: e.instructions_de ?? [] },
      { en: e.tips_en ?? [], de: e.tips_de ?? [] },
      ASSISTED_IDS.includes(e.id),
    ]);
  }
  return { fields: FIELDS, exercises, warnings };
}
