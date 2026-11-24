import 'package:test/test.dart';
import 'package:trainings_core/src/exercise_library_daten.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für die **Regeltabelle** der erzeugten Übungen (Spec 6, mit den
/// Festlegungen aus Nachtrag 18) — gesehen von der Seite der Bibliothek: Was
/// steht an der Übung, die der Generator aus einer RepDB-Zeile gemacht hat?
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden.
///
/// ## Woher die Zahlen kommen
///
/// - **Die Erwartungswerte je Zweig** sind aus Spec Abschnitt 6 abgeschrieben
///   (Spalte „Sätze × Wdh, Steigerung“) und aus Nachtrag 19 (Zweig CARDIO),
///   nicht aus dem Generator gelesen.
/// - **Die Beispiel-IDs** sind die der Spec (12.1), jede gegen die Menge des
///   708er-Stands geprüft (Plan, Lücke 3). **Keine fiel heraus:** Auch
///   `box-jump` steht drin, weil die Akzeptanzliste („Studio-Deutsch“) es
///   zurückholt. Wo ein Nachtrag die Tabelle ändert, steht es am Fall.
/// - **Die Anzahl je Wertepaket** (vorletzte Gruppe) und die drei Listen der
///   Weggelassenen hat der Test-Agent selbst am gepinnten Datensatz
///   nachgezählt (`scripts/.cache/exercises.json`, RepDB `4b1358a`, 708
///   Übungen, SHA-256 `ad7c602f…948f`), indem er Spec 6 samt Nachträgen 18 bis
///   20 unabhängig auf alle Zeilen anwandte. Nur JSON-Felder, keine Bilddatei.
///   Herausgekommen sind **548** Erzeugte (darunter **19** Cardio), **108**
///   unsauber Übersetzte, **19** ohne Hauptmuskel. Die Statistik des
///   Generators nennt dieselben Zweigzahlen — als Gegenbeleg, nicht als Quelle.
///
/// ## Wer was entschieden hat
///
/// - **Tim (Nachtrag 17 und 19):** nur sauber übersetzte Namen; Cardio kommt
///   in die Bibliothek. Die Liste der 108 Ausgeschlossenen unten ist das
///   Ergebnis der Namensregel am Datensatz, **mit der Akzeptanzliste der
///   Testphase** (Nachtrag 18: Studio-Begriffe, seither erweitert, z. B. um
///   `sissy-squat`). Die Akzeptanzliste hat Tim **nicht durchgesehen** — sie
///   ist eine Festlegung der Testphase, keine seiner Entscheidungen.
/// - **Vorschlag der Spec, vorausgesetzt:** die Tabelle selbst (Spec 15.6),
///   die Übungen ohne Hauptmuskel draußen (15.4), Muskelgewichte 1,0/0,5
///   (15.5), Trage-Übungen als Zeitübung (15.11), und für Cardio die „Brücke“
///   aus Nachtrag 19: Zweig CARDIO, 1 Satz × 300–600 s, +5 s, Zeitübung —
///   Nachtrag 19 nennt sie ausdrücklich einen Vorschlag.
/// - **Festlegung der Testphase (Nachtrag 18, Folgerungen, nicht von Tim
///   entschieden):** `band-assisted-pull-ups` ist N und nicht W1; die
///   +5-Regel für Beine greift bei **irgendeinem** Hauptmuskel in den drei
///   Beingruppen; Kettlebell-olympisch steigert um 2.
/// - **Folgerungen aus dem 708er-Sprung (Nachtrag 20, nicht von Tim
///   entschieden):** `savasana` fällt bewusst heraus; `infraspinatus_teres_minor`
///   zählt als hintere Schulter; `bosu_ball` und `sandbag` sind „Sonstiges“.
///
/// Die Zahlen sind **allgemeine Startwerte**, keine Empfehlung im Einzelfall
/// und keine ärztliche Vorgabe.
void main() {
  /// Eine Erwartung an die Vorgaben einer Übung. `increment` in kg, bei
  /// Zeitübungen in Sekunden.
  void erwarte(
    String id, {
    required int sets,
    required int low,
    required int high,
    required double increment,
    bool timed = false,
    bool assist = false,
  }) {
    final e = ExerciseLibrary.byId(id);
    expect(e, isNotNull, reason: '$id steht nicht in der Bibliothek');
    expect(ExerciseLibrary.isCatalog(id), isFalse, reason: '$id ist ein Anker');
    expect(e!.sets, sets, reason: '$id: Sätze');
    expect(e.repLow, low, reason: '$id: untere Wiederholungsgrenze');
    expect(e.repHigh, high, reason: '$id: obere Wiederholungsgrenze');
    expect(e.increment, increment, reason: '$id: Steigerung');
    expect(e.isTimed, timed, reason: '$id: isTimed');
    expect(e.allowsAssist, assist, reason: '$id: allowsAssist');
  }

  /// Die 19 Cardio-Übungen des Datensatzes (Kategorie `cardio`).
  const cardio = [
    'air-bike',
    'battle-rope-double-slam',
    'battle-ropes',
    'burpees',
    'cycling',
    'elliptical-trainer',
    'heel-flicks',
    'high-knees',
    'incline-treadmill-walk',
    'jump-rope',
    'jumping-jacks',
    'mountain-climbers',
    'rowing-machine',
    'running',
    'ski-erg',
    'stair-climber',
    'stationary-bike',
    'treadmill-running',
    'walking',
  ];

  group('Je Zweig der Regeltabelle ein Beispiel (Spec 6, Beispiele 12.1)', () {
    test('Z1 Dehnung halten: 2 × 30–60 s, +5 s, Zeitübung', () {
      erwarte(
        'bench-hamstring-stretch',
        sets: 2,
        low: 30,
        high: 60,
        increment: 5,
        timed: true,
      );
    });

    test('Z2 schwere Halteübung: 3 × 10–20 s, +5 s', () {
      erwarte('planche', sets: 3, low: 10, high: 20, increment: 5, timed: true);
    });

    test('Z3 Halteübung: 3 × 30–45 s, +5 s', () {
      erwarte('plank', sets: 3, low: 30, high: 45, increment: 5, timed: true);
    });

    test('A Unterstützung: 3 × 8–12, +2,5, `allowsAssist`', () {
      erwarte(
        'assisted-dips',
        sets: 3,
        low: 8,
        high: 12,
        increment: 2.5,
        assist: true,
      );
      erwarte(
        'assisted-pull-ups',
        sets: 3,
        low: 8,
        high: 12,
        increment: 2.5,
        assist: true,
      );
    });

    test('O olympisch: 4 × 3–5, +2,5', () {
      erwarte('snatch', sets: 4, low: 3, high: 5, increment: 2.5);
    });

    test('P Plyometrie: 3 × 5–8, +2,5', () {
      erwarte('box-jump', sets: 3, low: 5, high: 8, increment: 2.5);
    });

    test('D Dehnung dynamisch: 2 × 8–12, +1', () {
      erwarte('cat-cow', sets: 2, low: 8, high: 12, increment: 1);
    });

    test('B1 Langhantel verbunden, Beine: 3 × 6–10, +5', () {
      erwarte('squat', sets: 3, low: 6, high: 10, increment: 5);
    });

    test('B1 Langhantel verbunden, sonst: 3 × 6–10, +2,5', () {
      erwarte('ohp', sets: 3, low: 6, high: 10, increment: 2.5);
    });

    test('B2 Langhantel isoliert: 3 × 8–12, +2,5', () {
      erwarte('barbell-curl', sets: 3, low: 8, high: 12, increment: 2.5);
    });

    test('E SZ-Stange: 3 × 8–12, +2,5', () {
      erwarte(
        'close-grip-ez-bar-curl',
        sets: 3,
        low: 8,
        high: 12,
        increment: 2.5,
      );
    });

    test('K1 Kurzhantel verbunden: 3 × 8–12, +2', () {
      erwarte('db-bench-press', sets: 3, low: 8, high: 12, increment: 2);
    });

    test('K2 Kurzhantel isoliert: 3 × 10–15, +1', () {
      erwarte('concentration-curl', sets: 3, low: 10, high: 15, increment: 1);
    });

    test('G1 Kettlebell verbunden: 3 × 8–12, +2', () {
      erwarte('kettlebell-swing', sets: 3, low: 8, high: 12, increment: 2);
    });

    test('G2 Kettlebell isoliert: 3 × 10–15, +1', () {
      erwarte(
        'kettlebell-hammer-curl',
        sets: 3,
        low: 10,
        high: 15,
        increment: 1,
      );
    });

    test('C1 Kabel verbunden: 3 × 10–12, +2,5', () {
      erwarte('lat-pulldown', sets: 3, low: 10, high: 12, increment: 2.5);
    });

    test('C2 Kabel isoliert: 3 × 12–15, +2,5', () {
      erwarte('cable-curl', sets: 3, low: 12, high: 15, increment: 2.5);
    });

    test('M1 Maschine verbunden, Beine: 3 × 8–12, +5', () {
      erwarte('hack-squat', sets: 3, low: 8, high: 12, increment: 5);
    });

    test('M1 Maschine verbunden, sonst: 3 × 8–12, +2,5', () {
      erwarte('chest-press-machine', sets: 3, low: 8, high: 12, increment: 2.5);
    });

    test('M2 Maschine isoliert: 3 × 12–15, +2,5', () {
      erwarte('seated-leg-curl', sets: 3, low: 12, high: 15, increment: 2.5);
    });

    test('W1 Körpergewicht verbunden: 3 × 8–15, +2,5', () {
      erwarte('push-up', sets: 3, low: 8, high: 15, increment: 2.5);
    });

    test('W2 Körpergewicht isoliert: 3 × 12–20, +2,5', () {
      erwarte('glute-bridge', sets: 3, low: 12, high: 20, increment: 2.5);
    });

    test('N Band: 3 × 12–20, +1', () {
      erwarte('band-pull-apart', sets: 3, low: 12, high: 20, increment: 1);
    });

    test('S1 Sonstiges verbunden: 3 × 8–12, +2,5', () {
      erwarte('sled-push', sets: 3, low: 8, high: 12, increment: 2.5);
    });

    test('S2 Sonstiges isoliert: 3 × 12–15, +2,5', () {
      erwarte('svend-press', sets: 3, low: 12, high: 15, increment: 2.5);
    });
  });

  group('Was Nachtrag 18 gegenüber dem Text der Spec festlegt', () {
    test('`band-assisted-pull-ups` ist N (Band), nicht W1, und erlaubt keine '
        'Unterstützung — das Band ist nicht in kg gestuft', () {
      erwarte(
        'band-assisted-pull-ups',
        sets: 3,
        low: 12,
        high: 20,
        increment: 1,
      );
    });

    test('Die +5-Regel greift, sobald **irgendein** Hauptmuskel in den drei '
        'Beingruppen liegt: Kreuzheben und Good Morning steigen um 5', () {
      // Hauptmuskeln: Unterer Rücken, Gesäß, Oberschenkel hinten — nicht alle
      // in den Beinen. Im Text der Spec stünde +2,5.
      erwarte('deadlift', sets: 3, low: 6, high: 10, increment: 5);
      erwarte('good-morning', sets: 3, low: 6, high: 10, increment: 5);
    });

    test('Kettlebell olympisch steigert um 2 statt 2,5 (Spec 6, Zweig O)', () {
      erwarte('kettlebell-swing-clean', sets: 4, low: 3, high: 5, increment: 2);
    });
  });

  group('Cardio ist drin: Zweig CARDIO (Spec Nachtrag 19)', () {
    test('Alle 19 Cardio-Übungen stehen in der Bibliothek, jede als '
        'Zeitübung: 1 Satz × 300–600 s, +5 s', () {
      expect(cardio.toSet(), hasLength(19));
      for (final id in cardio) {
        erwarte(id, sets: 1, low: 300, high: 600, increment: 5, timed: true);
        expect(
          exerciseSearchTerms.containsKey(id),
          isTrue,
          reason: '$id: keine Suchwörter',
        );
      }
    });

    test('Cardio bleibt in der Obergrenze von `WorkoutRules`: 600 Sekunden '
        'sind das Höchste, was ein Zeitbereich darf', () {
      for (final id in cardio) {
        expect(
          ExerciseLibrary.byId(id)!.repHigh,
          lessThanOrEqualTo(WorkoutRules.maxSeconds),
          reason: id,
        );
      }
    });

    test('Die Suche findet Cardio wie jede andere Übung: über den deutschen '
        'und den englischen Namen', () {
      const erwartet = {
        'laufen': 'running',
        'running': 'running',
        'gehen': 'walking',
        'seilspringen': 'jump-rope',
        'jump rope': 'jump-rope',
        'fahrradergometer': 'stationary-bike',
        'burpees': 'burpees',
      };
      for (final eintrag in erwartet.entries) {
        expect(
          ExerciseLibrary.search(eintrag.key).map((e) => e.id),
          contains(eintrag.value),
          reason: eintrag.key,
        );
      }
    });

    test('Eine Cardio-Übung trägt ihre Muskeln aus dem Datensatz: `burpees` '
        'trifft Gesäß, Brust und Oberschenkel vorne voll', () {
      final burpees = ExerciseLibrary.byId('burpees')!;
      expect(burpees.muscles, {
        Muscle.glutes: 1.0,
        Muscle.chest: 1.0,
        Muscle.quads: 1.0,
        Muscle.frontDelt: 0.5,
        Muscle.core: 0.5,
        Muscle.triceps: 0.5,
      });
      expect(ExerciseLibrary.mainMuscle(burpees), Muscle.chest);
    });
  });

  group('Was der 708er-Stand dazubringt (Spec Nachtrag 20)', () {
    test('`sissy-squat` steht drin (die Spec nannte ihn als Lücke): '
        'Körpergewicht, isoliert: 3 × 12–20, +2,5', () {
      erwarte('sissy-squat', sets: 3, low: 12, high: 20, increment: 2.5);
      expect(ExerciseLibrary.byId('sissy-squat')!.muscles, {
        Muscle.quads: 1.0,
        Muscle.core: 0.5,
      });
    });

    test('`infraspinatus_teres_minor` zählt als hintere Schulter: '
        '`band-shoulder-external-rotation` trifft sie voll — der Nebenmuskel '
        'liegt in derselben Gruppe', () {
      expect(ExerciseLibrary.byId('band-shoulder-external-rotation')!.muscles, {
        Muscle.rearDelt: 1.0,
      });
      erwarte(
        'cable-external-rotation',
        sets: 3,
        low: 12,
        high: 15,
        increment: 2.5,
      );
      expect(
        ExerciseLibrary.byId('cable-external-rotation')!
            .muscles[Muscle.rearDelt],
        1.0,
      );
    });

    test('Geräte `bosu_ball` und `sandbag` sind „Sonstiges“: verbunden S1, '
        'isoliert S2, gehalten Z3', () {
      erwarte('balance-dome-squat', sets: 3, low: 8, high: 12, increment: 2.5);
      erwarte(
        'balance-dome-crunch',
        sets: 3,
        low: 12,
        high: 15,
        increment: 2.5,
      );
      erwarte(
        'sandbag-carry',
        sets: 3,
        low: 30,
        high: 45,
        increment: 5,
        timed: true,
      );
    });
  });

  group('Die Reihenfolge der Zweige: die erste zutreffende Zeile gilt', () {
    test('Eine Halteübung mit Gerät ist Z, nicht Kettlebell- oder '
        'Kurzhantel-Zweig', () {
      // `dumbbell-farmers-walk`, `suitcase-carry`: `static` schlägt K/G.
      erwarte(
        'dumbbell-farmers-walk',
        sets: 3,
        low: 30,
        high: 45,
        increment: 5,
        timed: true,
      );
      erwarte(
        'suitcase-carry',
        sets: 3,
        low: 30,
        high: 45,
        increment: 5,
        timed: true,
      );
    });

    test('Eine schwere Halteübung mit Gerät ist Z2, nicht Z3 und nicht G1', () {
      erwarte(
        'double-kettlebell-overhead-carry',
        sets: 3,
        low: 10,
        high: 20,
        increment: 5,
        timed: true,
      );
    });

    test('Eine Halteübung am Körpergewicht ist Z3, nicht W', () {
      erwarte(
        'dead-hang',
        sets: 3,
        low: 30,
        high: 45,
        increment: 5,
        timed: true,
      );
    });

    test('Zwei Zweige, die nicht verwechselt werden: Maschinen-Unterstützung '
        '(A) und Bandunterstützung (N)', () {
      expect(ExerciseLibrary.byId('assisted-pull-ups')!.allowsAssist, isTrue);
      expect(
        ExerciseLibrary.byId('band-assisted-pull-ups')!.allowsAssist,
        isFalse,
      );
    });
  });

  group('Muskelzuordnung: Hauptmuskeln 1,0, Nebenmuskeln 0,5', () {
    test('`squat`: Gesäß und Oberschenkel vorne 1, Unterer Rücken und '
        'Oberschenkel hinten 0,5', () {
      expect(ExerciseLibrary.byId('squat')!.muscles, {
        Muscle.glutes: 1.0,
        Muscle.quads: 1.0,
        Muscle.lowerBack: 0.5,
        Muscle.hamstrings: 0.5,
      });
    });

    test('`lat-pulldown`: Latissimus 1, Bizeps, Hintere Schulter und Oberer '
        'Rücken 0,5', () {
      expect(ExerciseLibrary.byId('lat-pulldown')!.muscles, {
        Muscle.lats: 1.0,
        Muscle.biceps: 0.5,
        Muscle.rearDelt: 0.5,
        Muscle.upperBack: 0.5,
      });
    });

    test('`svend-press`: Brust 1, Vordere Schulter und Trizeps 0,5', () {
      expect(ExerciseLibrary.byId('svend-press')!.muscles, {
        Muscle.chest: 1.0,
        Muscle.frontDelt: 0.5,
        Muscle.triceps: 0.5,
      });
    });

    test('`deadlift`: drei Hauptmuskeln, zwei Nebenmuskeln', () {
      expect(ExerciseLibrary.byId('deadlift')!.muscles, {
        Muscle.lowerBack: 1.0,
        Muscle.glutes: 1.0,
        Muscle.hamstrings: 1.0,
        Muscle.quads: 0.5,
        Muscle.upperBack: 0.5,
      });
    });

    test('Liegt ein Muskel bei Haupt- **und** Nebenmuskeln, gilt 1,0: '
        '`banded-glute-bridge` trifft das Gesäß über beide Listen', () {
      // Hauptmuskel: großer Gesäßmuskel; Nebenmuskel: mittlerer Gesäßmuskel —
      // beides ist bei uns „Gesäß“.
      expect(ExerciseLibrary.byId('banded-glute-bridge')!.muscles, {
        Muscle.glutes: 1.0,
        Muscle.hamstrings: 0.5,
      });
    });
  });

  group('Was nicht in der Bibliothek steht', () {
    // Kein Hauptmuskel in unseren 16 Gruppen (Adduktoren, Hüftbeuger) —
    // und `savasana`, dem der 708er-Stand die Muskeln genommen hat (Nachtrag 20).
    const ohneHauptmuskel = [
      '90-90-hold',
      '90-90-switch',
      'banded-adductor-stretch',
      'banded-standing-hip-adduction',
      'bench-adductor-stretch',
      'butterfly-stretch',
      'downward-dog-to-low-lunge',
      'frog-stretch',
      'half-kneeling-hip-flexor-rock',
      'hip-adduction',
      'kneeling-hip-flexor-stretch',
      'lean-back-90-90-hold',
      'lizard-stretch',
      'reclined-butterfly',
      'savasana',
      'side-lying-hip-adduction',
      'side-lying-hip-adduction-hold',
      'standing-adductor-stretch',
      'wide-stance-leg-press',
    ];
    // Nachtrag 17 Nr. 2: unsauber übersetzt — der Filter beanstandet den
    // deutschen Namen, und die Akzeptanzliste holt ihn nicht zurück.
    const unsauber = [
      'ball-pike',
      'banded-fire-hydrant',
      'banded-good-morning',
      'banded-romanian-deadlift',
      'banded-squat',
      'banded-sumo-walk',
      'banded-terminal-knee-extension',
      'bench-pull',
      'bodyweight-calf-raise',
      'bodyweight-good-morning',
      'bodyweight-overhead-press',
      'bodyweight-squat',
      'box-squat',
      'cheat-curl',
      'clamshells',
      'cocoons',
      'copenhagen-plank',
      'copenhagen-plank-raises',
      'crab-dips',
      'db-somersault-squat',
      'double-kettlebell-clean',
      'double-kettlebell-dead-clean',
      'double-kettlebell-dead-split-snatch',
      'double-kettlebell-jerk',
      'double-kettlebell-push-press',
      'double-kettlebell-split-jerk',
      'double-kettlebell-swing-snatch',
      'drag-curl',
      'dragon-flag',
      'dumbbell-bench-pull',
      'dumbbell-hip-thrust',
      'fire-hydrant',
      'floor-press',
      'flutter-kicks',
      'high-plank',
      'hollow-body-hold',
      'inchworm',
      'incline-push-ups',
      'inverted-row',
      'jackknife-sit-up',
      'jefferson-curl',
      'kettlebell-bulgarian-split-squat',
      'kettlebell-floor-press',
      'kettlebell-halo',
      'kettlebell-russian-twist',
      'kettlebell-svend-press',
      'landmine-press',
      'nordic-hamstring-curl',
      'pilates-leg-pull-back',
      'pilates-leg-pull-front',
      'pilates-roll-down',
      'pilates-roll-over',
      'pilates-spine-stretch-forward',
      'pilates-spine-twist',
      'pistol-squat',
      'planche-lean-floor',
      'plate-pinch',
      'rack-pull',
      'renegade-row',
      'reverse-crunches',
      'reverse-curl',
      'reverse-grip-bent-over-row',
      'reverse-nordic-curl',
      'reverse-plank',
      'reverse-plank-dips',
      'ring-dead-hang',
      'ring-dips',
      'ring-face-pull',
      'ring-l-sit',
      'ring-muscle-up',
      'ring-plank',
      'ring-push-up',
      'ring-row',
      'rings-inverted-row',
      'seated-dumbbell-lateral-raise',
      'seated-dumbbell-tricep-extension',
      'seated-smith-machine-shoulder-press',
      'shrimp-squat',
      'side-lunge',
      'side-lying-hip-abduction',
      'side-lying-hip-abduction-hold',
      'single-arm-dumbbell-overhead-tricep-extension',
      'sled-row',
      'smith-machine-bench-press',
      'smith-machine-bent-over-row',
      'smith-machine-bulgarian-split',
      'smith-machine-calf-raise',
      'smith-machine-decline-bench-press',
      'smith-machine-front-squat',
      'smith-machine-good-morning',
      'smith-machine-incline-bench-press',
      'smith-machine-rdl',
      'smith-machine-reverse-grip-bent-over-row',
      'smith-machine-reverse-lunge',
      'smith-machine-split-squat',
      'smith-machine-upright-row',
      'spider-curl',
      'spiderman-push-up',
      'spoto-press',
      'strict-curl',
      'superman',
      'toes-to-bar',
      'trx-face-pull',
      'trx-pistol-squat',
      'trx-y-fly',
      'wall-ball',
      'worlds-greatest-stretch',
      'wrist-roller',
    ];
    // Die RepDB-Zeilen der 33 Anker (`MAPPING[].repdb`): Das Bild gehört dem
    // Anker, die Zeile erzeugt keine zweite Übung. Eine Zeile heißt wie ihr
    // Anker: `dips`.
    const ankerZeilen = [
      'bench-press',
      'incline-db-press',
      'seated-db-press',
      'dips',
      'lateral-raise',
      'cable-overhead-tricep-extension',
      'bicep-curl',
      'bulgarian-split-squat',
      'romanian-deadlift',
      'hip-thrust',
      'single-leg-calf-raise',
      'seated-calf-raise',
      'kettlebell-tibialis-raise',
      'cable-fly',
      'side-plank',
      'pull-up',
      'single-arm-db-row',
      'seated-cable-row',
      'face-pull',
      'ez-bar-curl',
      'hammer-curl',
      'tricep-pushdown',
      'close-grip-bench-press',
      'machine-shoulder-press',
      'dumbbell-reverse-fly',
      'incline-db-curl',
      'barbell-row',
      'straight-arm-pulldown',
      'back-extension',
      'leg-press',
      'leg-curl',
      'hip-abduction',
      'leg-extension',
    ];

    test('Die Listen haben die nachgezählte Größe und überschneiden sich '
        'nicht: 708 = 33 + 19 + 108 + 548 (Cardio ist bei den 548)', () {
      expect(ohneHauptmuskel.toSet(), hasLength(19));
      expect(unsauber.toSet(), hasLength(108));
      expect(ankerZeilen.toSet(), hasLength(33));
      final zusammen = {...ohneHauptmuskel, ...unsauber, ...ankerZeilen};
      expect(zusammen, hasLength(33 + 19 + 108));
      expect(33 + 19 + 108 + generatedExercises.length, 708);
    });

    test('Keine der 19 Übungen ohne Hauptmuskel steht in der Bibliothek', () {
      for (final id in ohneHauptmuskel) {
        expect(ExerciseLibrary.byId(id), isNull, reason: id);
        expect(exerciseSearchTerms.containsKey(id), isFalse, reason: id);
      }
    });

    test('`savasana` steht **nicht** in der Bibliothek: Der 708er-Stand hat '
        'der „Totenstellung“ die Muskeln genommen, und wir folgen dem '
        'Datensatz (Spec Nachtrag 20 Nr. 1, bewusst entfernt)', () {
      expect(ohneHauptmuskel, contains('savasana'));
      expect(ExerciseLibrary.byId('savasana'), isNull);
      expect(ExerciseLibrary.isCatalog('savasana'), isFalse);
      expect(ExerciseLibrary.all.containsKey('savasana'), isFalse);
      expect(generatedExercises.where((e) => e.id == 'savasana'), isEmpty);
      expect(exerciseSearchTerms.containsKey('savasana'), isFalse);
      // Auch die Suche findet sie nicht — weder über die ID noch über den
      // deutschen Namen („Totenstellung“) noch über den englischen.
      for (final anfrage in ['savasana', 'totenstellung', 'corpse']) {
        expect(
          ExerciseLibrary.search(anfrage).map((e) => e.id),
          isNot(contains('savasana')),
          reason: anfrage,
        );
      }
    });

    test('Keine der 108 unsauber übersetzten steht in der Bibliothek — sie '
        'kommen über die Überschreibliste nach und nach dazu', () {
      for (final id in unsauber) {
        expect(ExerciseLibrary.byId(id), isNull, reason: id);
        expect(exerciseSearchTerms.containsKey(id), isFalse, reason: id);
      }
    });

    test('Die RepDB-Zeilen der 33 Anker erzeugen keine zweite Übung — bis '
        'auf `dips`, das schon der Anker ist', () {
      for (final id in ankerZeilen) {
        if (id == 'dips') {
          expect(ExerciseLibrary.isCatalog(id), isTrue);
        } else {
          expect(ExerciseLibrary.byId(id), isNull, reason: id);
        }
      }
    });
  });

  group('Eigenschaft über alle 548 Erzeugten: so viele je Wertepaket', () {
    // Schlüssel: Sätze | untere | obere Grenze | Steigerung | Zeit | Unterst.
    // Jede Zahl ist das Ergebnis, das Spec 6 samt Nachtrag 18 am Datensatz
    // liefert; mehrere Zweige mit gleichen Werten fallen in ein Paket zusammen.
    const erwartet = {
      // Z1
      '2|30|60|5.0|true|false': 60,
      // Z2
      '3|10|20|5.0|true|false': 16,
      // Z3
      '3|30|45|5.0|true|false': 67,
      // Cardio (Nachtrag 19)
      '1|300|600|5.0|true|false': 19,
      // A
      '3|8|12|2.5|false|true': 2,
      // O (Kettlebell +2) und O
      '4|3|5|2.5|false|false': 11,
      '4|3|5|2.0|false|false': 1,
      // P
      '3|5|8|2.5|false|false': 4,
      // D
      '2|8|12|1.0|false|false': 10,
      // B1: Beine +5 / sonst +2,5
      '3|6|10|5.0|false|false': 20,
      '3|6|10|2.5|false|false': 18,
      // M1 Beine +5
      '3|8|12|5.0|false|false': 8,
      // B2, E, M1 (sonst), S1
      '3|8|12|2.5|false|false': 57,
      // K1, G1
      '3|8|12|2.0|false|false': 68,
      // K2, G2
      '3|10|15|1.0|false|false': 42,
      // C1
      '3|10|12|2.5|false|false': 13,
      // C2, M2, S2
      '3|12|15|2.5|false|false': 36,
      // W1
      '3|8|15|2.5|false|false': 65,
      // W2
      '3|12|20|2.5|false|false': 15,
      // N
      '3|12|20|1.0|false|false': 16,
    };

    test('Die 548 verteilen sich genau so auf die Wertepakete — kein '
        'Zweig fällt durch, keiner ist hinzugekommen', () {
      final gezaehlt = <String, int>{};
      for (final e in generatedExercises) {
        final schluessel =
            '${e.sets}|${e.repLow}|${e.repHigh}|${e.increment}|'
            '${e.isTimed}|${e.allowsAssist}';
        gezaehlt[schluessel] = (gezaehlt[schluessel] ?? 0) + 1;
      }
      expect(gezaehlt, erwartet);
      expect(erwartet.values.fold<int>(0, (a, b) => a + b), 548);
    });
  });

  group('Die Hauptmuskeln der Beispiele (Gruppierung, Spec 4.6 und K8)', () {
    test('Kniebeugen liegen im Gesäß: bei Gleichstand gilt der kleinere '
        '`Muscle.index`', () {
      expect(
        ExerciseLibrary.mainMuscle(ExerciseLibrary.byId('squat')!),
        Muscle.glutes,
      );
      expect(
        ExerciseLibrary.mainMuscle(ExerciseCatalog.all['splitSquat']!),
        Muscle.glutes,
      );
    });

    test('`ohp` (Vordere und Seitliche Schulter, je 1,0) liegt bei der '
        'Vorderen Schulter', () {
      expect(
        ExerciseLibrary.mainMuscle(ExerciseLibrary.byId('ohp')!),
        Muscle.frontDelt,
      );
    });

    test('`hammerCurl` bleibt beim Bizeps', () {
      expect(
        ExerciseLibrary.mainMuscle(ExerciseCatalog.all['hammerCurl']!),
        Muscle.biceps,
      );
    });
  });
}
