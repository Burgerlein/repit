// Welche RepDB-Übung zeigt das Bewegungsbild zu welcher Übung des
// Katalogs (`Packages/trainings_core/lib/src/exercise_catalog.dart`)?
//
// Das ist von Hand gemacht, Übung für Übung gegen die englische
// Schrittfolge des Datensatzes gelesen — kein Skript kann das entscheiden.
// Hier steht es als Tabelle, damit ein Mensch es prüfen kann: unsere ID,
// unser deutscher Name, die RepDB-ID, deren englischer Name, und ob der
// Treffer genau oder ungefähr ist.
//
// **Lieber kein Bild als ein falsches.** Ein Bild, das eine andere Bewegung
// zeigt, ist schlimmer als keins: Es sieht richtig aus. Wo der Datensatz
// eine Übung nicht trifft, steht sie nicht hier, und die App zeigt kein
// Bild.
//
// `approximate: true` heißt: Die Bewegung ist dieselbe, Gerät oder Aufbau
// weichen ab. Das Bild hilft, ist aber keine Vorlage; der Schirm sagt das.
// `note` sagt in einem Satz, worin die Abweichung besteht.
//
// `repdbName` ist der englische Name im Datensatz. `exercises-asset.mjs`
// vergleicht ihn beim Lauf mit dem Datensatz und bricht ab, wenn er nicht
// mehr stimmt — ein Update, das die ID unter einer anderen Übung weiterführt,
// fiele sonst nicht auf. `name` (unser deutscher Name) schreibt der Lauf ins
// Asset, damit die App-Tests eine Umbenennung im Katalog bemerken.

export const MAPPING = [
  // Gym A
  {
    id: 'benchPress', name: 'Bankdrücken Langhantel',
    repdb: 'bench-press', repdbName: 'Barbell Bench Press',
  },
  {
    id: 'inclineDumbbellPress', name: 'Schrägbankdrücken Kurzhantel',
    repdb: 'incline-db-press', repdbName: 'Incline Dumbbell Press',
  },
  {
    id: 'shoulderPressDumbbell', name: 'Schulterdrücken Kurzhantel sitzend',
    repdb: 'seated-db-press', repdbName: 'Seated Dumbbell Shoulder Press',
  },
  {
    id: 'dips', name: 'Dips',
    repdb: 'dips', repdbName: 'Chest Dips',
  },
  {
    id: 'lateralRaise', name: 'Seitheben',
    repdb: 'lateral-raise', repdbName: 'Dumbbell Lateral Raise',
  },
  {
    id: 'overheadTriceps', name: 'Trizeps über Kopf am Kabel',
    repdb: 'cable-overhead-tricep-extension',
    repdbName: 'Cable Overhead Tricep Extension',
  },
  {
    id: 'bicepsCurl', name: 'Bizeps-Curls Kurzhantel',
    repdb: 'bicep-curl', repdbName: 'Dumbbell Bicep Curl',
  },

  // Gym B
  {
    id: 'splitSquat', name: 'Bulgarian Split Squat',
    repdb: 'bulgarian-split-squat', repdbName: 'Bulgarian Split Squat',
  },
  {
    id: 'romanianDeadlift', name: 'Rumänisches Kreuzheben',
    repdb: 'romanian-deadlift', repdbName: 'Romanian Deadlift',
  },
  {
    id: 'hipThrust', name: 'Hip Thrust',
    repdb: 'hip-thrust', repdbName: 'Barbell Hip Thrust',
  },
  {
    id: 'calfRaiseStanding', name: 'Wadenheben stehend einbeinig',
    repdb: 'single-leg-calf-raise', repdbName: 'Single Leg Calf Raise',
  },
  {
    id: 'calfRaiseSeated', name: 'Wadenheben sitzend',
    repdb: 'seated-calf-raise', repdbName: 'Seated Calf Raise',
  },
  {
    // Der Datensatz kennt das Zehenheben nur im Sitzen mit einer Kettlebell
    // am Fuß; unsere Übung steht mit dem Rücken an der Wand und ohne
    // Gewicht. Die Bewegung im Sprunggelenk ist dieselbe.
    id: 'tibialisRaise', name: 'Zehenheben an der Wand',
    repdb: 'kettlebell-tibialis-raise', repdbName: 'Kettlebell Tibialis Raise',
    approximate: true,
    note: 'Zeigt dieselbe Bewegung im Sitzen mit einer Kettlebell am Fuß; ' +
      'bei dir steht der Rücken an der Wand, ohne Gewicht.',
  },
  {
    id: 'cableFly', name: 'Kabel-Flys',
    repdb: 'cable-fly', repdbName: 'Cable Fly',
  },
  {
    id: 'sidePlank', name: 'Seitstütz',
    repdb: 'side-plank', repdbName: 'Side Plank',
  },

  // Gym C
  {
    // Unser Eintrag heißt „Klimmzüge oder Latziehen"; das Bild zeigt den
    // Klimmzug, nicht den Latzug (`lat-pulldown` ist eine eigene Übung).
    id: 'pullUp', name: 'Klimmzüge oder Latziehen',
    repdb: 'pull-up', repdbName: 'Pull-Up',
    note: 'Zeigt den Klimmzug, nicht den Latzug.',
  },
  {
    id: 'oneArmRow', name: 'Rudern einarmig Kurzhantel',
    repdb: 'single-arm-db-row', repdbName: 'Single-Arm Dumbbell Row',
  },
  {
    // „eng" ist im Datensatz nicht ausgewiesen: Der Eintrag beschreibt den
    // Zug am Griff ohne Angabe der Breite.
    id: 'cableRowClose', name: 'Kabelrudern eng',
    repdb: 'seated-cable-row', repdbName: 'Seated Cable Row',
    approximate: true,
    note: 'Zeigt das sitzende Kabelrudern ohne Angabe der Griffbreite; ' +
      'enger Griff ist nicht eigens abgebildet.',
  },
  {
    id: 'facePull', name: 'Face Pulls',
    repdb: 'face-pull', repdbName: 'Cable Face Pull',
  },
  {
    id: 'ezCurl', name: 'SZ-Curls',
    repdb: 'ez-bar-curl', repdbName: 'EZ-Bar Curl',
  },
  {
    id: 'hammerCurl', name: 'Hammer Curls',
    repdb: 'hammer-curl', repdbName: 'Dumbbell Hammer Curl',
  },
  {
    id: 'tricepsPushdown', name: 'Trizepsdrücken am Kabel',
    repdb: 'tricep-pushdown', repdbName: 'Cable Tricep Pushdown',
  },

  // Gym D
  {
    id: 'closeGripBench', name: 'Enges Bankdrücken',
    repdb: 'close-grip-bench-press', repdbName: 'Close-Grip Bench Press',
  },
  {
    id: 'shoulderPressMachine', name: 'Schulterdrücken Maschine',
    repdb: 'machine-shoulder-press', repdbName: 'Machine Shoulder Press',
  },
  {
    id: 'reverseFly', name: 'Reverse Flys',
    repdb: 'dumbbell-reverse-fly', repdbName: 'Dumbbell Reverse Fly',
  },
  {
    id: 'inclineCurl', name: 'Schrägbank-Curls',
    repdb: 'incline-db-curl', repdbName: 'Incline Dumbbell Curl',
  },

  // Push, Pull, Legs
  {
    id: 'barbellRow', name: 'Langhantelrudern vorgebeugt',
    repdb: 'barbell-row', repdbName: 'Bent-Over Barbell Row',
  },
  {
    id: 'straightArmPulldown', name: 'Überzüge am Kabel mit gestreckten Armen',
    repdb: 'straight-arm-pulldown', repdbName: 'Straight-Arm Pulldown',
  },
  {
    // `machine-back-extension` ist eine andere Übung (sitzend, Rolle am
    // Rücken); unsere beschreibt das Gerät mit Hüftpolster, also die
    // Hyperextension-Bank.
    id: 'backExtension', name: 'Rückenstrecken',
    repdb: 'back-extension', repdbName: 'Back Extension',
  },
  {
    id: 'legPress', name: 'Beinpresse',
    repdb: 'leg-press', repdbName: 'Leg Press',
  },
  {
    id: 'legCurl', name: 'Beinbeuger-Maschine liegend',
    repdb: 'leg-curl', repdbName: 'Lying Leg Curl',
  },
  {
    id: 'hipAbduction', name: 'Abduktoren-Maschine',
    repdb: 'hip-abduction', repdbName: 'Machine Hip Abduction',
  },
  {
    id: 'legExtension', name: 'Beinstrecker-Maschine',
    repdb: 'leg-extension', repdbName: 'Leg Extension',
  },
];
