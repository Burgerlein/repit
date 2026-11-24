// Zieht den RepDB-Datensatz in dem gepinnten Stand (`REPDB_COMMIT`) und
// schreibt das Asset der App nach `app/assets/exercises/` (#38, #551).
//
//   node scripts/exercises-asset.mjs           die Bibliothek: Anker + erzeugte
//   node scripts/exercises-asset.mjs --alle    alle 708 Übungen
//
// Ohne Schalter kommt **die Bibliothek** ins Asset: die 33 Zeilen der
// Zuordnung (`exercises-mapping.mjs`) und die erzeugten Übungen, die
// `selectExercises` (`exercises-select.mjs`) auswählt — **dieselbe Funktion**
// wie im Generator `exercises-library-to-dart.mjs`, damit Asset und Dart-Datei
// nicht verschiedene Mengen meinen. Weggelassen werden Zeilen ohne
// Hauptmuskel und unsauber übersetzte Namen; ihre Bilder kommen nicht mit.
// `exercises-library-to-dart.mjs --statistik` nennt Mengen und Bildgröße.
//
// Warum „alle erzeugten" der Normalfall ist: Die Bibliothek ist Teil der App,
// die Bilder werden mit committet (Entscheidung vom 20.11.2026, Spec Nachtrag
// 17.3) und gebündelt — es gibt keinen Server, von dem man nachladen könnte.
// Die Bilder bleiben damit für immer in der Git-History, auch wenn man sie
// später löscht; der Datensatz zu 650 Übungen wog 18,21 MiB (gemessen, nicht die
// früher genannten „~21 MB"). `--alle` ist für Arbeiten gedacht, die auch die
// Weggelassenen brauchen (#552).
//
// Der Lauf ist deterministisch: derselbe Commit und dieselbe Zuordnung geben
// byte-identische Dateien. Keine Abhängigkeiten, nur Node. Der Datensatz
// kommt über `exercises-source.mjs` (Zwischenspeicher, SHA-256 geprüft).
//
// Lizenz: Das Ergebnis ist **nur zur Nutzung in der App** gedacht — nicht
// als Datensatz weiterzugeben, nicht als Eingabe für generative Modelle.
// Siehe `LICENSE-DATA.md` im Zielordner.

import { mkdirSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import {
  REPDB_COMMIT,
  imagePaths,
  toExerciseAsset,
} from './exercises-convert.mjs';
import { MAPPING } from './exercises-mapping.mjs';
import { NAMEN_AKZEPTIERT, selectExercises } from './exercises-select.mjs';
import { download, loadRepdb } from './exercises-source.mjs';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const TARGET = join(ROOT, 'app', 'assets', 'exercises');
const BLOCK = 16;

/** WebP beginnt mit `RIFF`, vier Längenbytes, `WEBP`. Eine Fehlerseite nicht. */
function assertWebp(bytes, path) {
  const ok = bytes.length > 12 &&
    bytes.subarray(0, 4).toString('latin1') === 'RIFF' &&
    bytes.subarray(8, 12).toString('latin1') === 'WEBP';
  if (!ok) throw new Error(`${path}: keine WebP-Datei`);
}

/** Die Zuordnung gegen den Datensatz prüfen und als Asset-Abschnitt bauen. */
function buildMedia(byId, exercisesById) {
  const media = [];
  const seen = new Set();
  for (const entry of MAPPING) {
    if (seen.has(entry.id)) throw new Error(`Zuordnung doppelt: ${entry.id}`);
    seen.add(entry.id);
    const dataset = byId.get(entry.repdb);
    if (!dataset) {
      throw new Error(
        `Zuordnung ${entry.id}: RepDB-ID „${entry.repdb}" fehlt im Datensatz.`);
    }
    if (dataset.name_en !== entry.repdbName) {
      throw new Error(
        `Zuordnung ${entry.id}: „${entry.repdb}" heißt jetzt ` +
          `„${dataset.name_en}", erwartet „${entry.repdbName}" — ` +
          'zeigt die ID noch auf dieselbe Übung?');
    }
    if (!exercisesById.has(entry.repdb)) {
      throw new Error(`Zuordnung ${entry.id}: ${entry.repdb} nicht im Asset.`);
    }
    const value = { de: entry.name, repdb: entry.repdb };
    if (entry.approximate) value.approximate = true;
    if (entry.note) value.note = entry.note;
    media.push([entry.id, value]);
  }
  return media;
}

const all = process.argv.includes('--alle');
const unknown = process.argv.slice(2).filter((a) => a !== '--alle');
if (unknown.length > 0) {
  console.error(`Unbekannter Schalter: ${unknown.join(' ')}`);
  process.exit(2);
}

console.log(`RepDB ${REPDB_COMMIT.slice(0, 7)}, ${all ? 'alle Übungen' : 'Auswahl'}`);
const repdb = await loadRepdb();
const license = await download('LICENSE-DATA.md');
const attribution = await download('ATTRIBUTION.md');
const byId = new Map(repdb.exercises.map((e) => [e.id, e]));

let only = null;
if (!all) {
  const selection = selectExercises(repdb, MAPPING);
  only = [...selection.anchors, ...selection.generated];
  const dropped = Object.values(selection.dropped).reduce((n, ids) => n + ids.length, 0);
  console.log(
    `${selection.anchors.length} Anker + ${selection.generated.length} erzeugte ` +
      `Übungen, ${dropped} weggelassen (Namen: exercises-library-to-dart.mjs --statistik)`);
}
const asset = toExerciseAsset(repdb, { only, strictGerman: false });
const exercisesById = new Map(asset.exercises.map((row) => [row[0], row]));
const media = buildMedia(byId, exercisesById);
// Ein Verdacht, den `NAMEN_AKZEPTIERT` quittiert, ist keine Warnung mehr.
for (const warning of asset.warnings) {
  const id = /^Übung ([^:]+):/.exec(warning)?.[1];
  if (!Object.hasOwn(NAMEN_AKZEPTIERT, id)) console.warn(`Warnung: ${warning}`);
}

// Dateien einsammeln, bevor etwas gelöscht wird: Scheitert ein Download, soll
// der alte Stand liegen bleiben.
const wanted = new Set();
for (const row of asset.exercises) {
  for (const path of imagePaths(byId.get(row[0]))) wanted.add(path);
}
const images = new Map();
const paths = [...wanted].sort();
for (let i = 0; i < paths.length; i += BLOCK) {
  const block = paths.slice(i, i + BLOCK);
  const bytes = await Promise.all(block.map(download));
  block.forEach((path, j) => {
    assertWebp(bytes[j], path);
    images.set(path, bytes[j]);
  });
  process.stdout.write(`\rBilder ${Math.min(i + BLOCK, paths.length)}/${paths.length}`);
}
process.stdout.write('\n');

const json =
  '{"source":"RepDB Exercise Dataset (free tier), repdb.co",' +
  `"commit":${JSON.stringify(REPDB_COMMIT)},` +
  `"fields":${JSON.stringify(asset.fields)},\n` +
  '"media":{\n' +
  media.map(([id, value]) => `${JSON.stringify(id)}:${JSON.stringify(value)}`)
    .join(',\n') +
  '\n},\n"exercises":[\n' +
  asset.exercises.map((row) => JSON.stringify(row)).join(',\n') +
  '\n]}\n';

rmSync(TARGET, { recursive: true, force: true });
mkdirSync(join(TARGET, 'images'), { recursive: true });
writeFileSync(join(TARGET, 'exercises.json'), json);
writeFileSync(join(TARGET, 'LICENSE-DATA.md'), license);
writeFileSync(join(TARGET, 'ATTRIBUTION.md'), attribution);
let imageBytes = 0;
for (const [path, bytes] of images) {
  writeFileSync(join(TARGET, 'images', path.slice('images/flat/'.length)), bytes);
  imageBytes += bytes.length;
}

const mb = (n) => (n / 1024 / 1024).toFixed(2);
console.log(
  `${asset.exercises.length} Übungen, ${media.length} Zuordnungen, ` +
    `${images.size} Bilder (${mb(imageBytes)} MiB), ` +
    `exercises.json ${mb(Buffer.byteLength(json))} MiB`,
);
