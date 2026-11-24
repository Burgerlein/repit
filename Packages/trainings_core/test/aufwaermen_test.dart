import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für das **Aufwärmen am Trainingsanfang** — Ticket #40, mitgebaut in
/// #78 (Tims Entscheidung vom 10.11.2026), Spec
/// `docs/superpowers/specs/2026-11-10-gym-training-eintragen-design.md`,
/// Abschnitte 10 und 18 (offene Frage 5, dort beantwortet).
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, nie verändert werden.
///
/// ## Was hier festgelegt wird
///
/// ```dart
/// sealed class WarmUp { }
/// final class WarmUpSkipped extends WarmUp { }
/// final class WarmUpDone extends WarmUp {
///   final WarmUpKind kind;
///   final int minutes;
///   final double? km;          // nullbar
/// }
///
/// enum WarmUpKind { bike, treadmill, rowing, crossTrainer, jumpRope,
///                   mobility }
/// // mit `code` und `fromCode`, wie `Workout.code`/`Workout.fromCode`
///
/// final class ImportedSession {
///   const ImportedSession({ …, this.warmUp });   // ohne required, Vorgabe null
///   final WarmUp? warmUp;
/// }
///
/// GymSessionBuilder.session({ …, WarmUp? warmUp });   // Vorgabe null
/// ```
///
/// ## Drei Zustände, nicht zwei
///
/// Das ist der Kern der Sache, und er steht ausdrücklich in #40:
/// „‚Übersprungen‘ ist eine Antwort und für den Plan-Agenten brauchbar; ein
/// leeres Feld ist es nicht."
///
/// - `null` — **nichts eingetragen.** So kommt alles herein, was die
///   Übernahme aus der alten App (#59) bringt; dort gab es kein Feld dafür.
/// - `WarmUpSkipped` — **übersprungen**, eine bewusste Antwort auf eine
///   gestellte Frage.
/// - `WarmUpDone` — **gemacht**, mit Art, Minuten und wo es etwas heißt der
///   Strecke.
///
/// Wer die ersten beiden verwechselt, rechnet später Durchschnitte über Tage,
/// an denen gar nicht trainiert wurde. Die Gruppe „Die drei Zustände" prüft
/// sie deshalb paarweise und nicht nur nebenbei.
///
/// ## Warum der Kerntyp es tragen muss
///
/// Der Rundweg Datenbank → Kern → Datenbank soll verlustfrei sein (Spec 10).
/// Ein Typ, der das Aufwärmen nicht trägt, macht ihn per Definition
/// verlustbehaftet — und was Tim ab dem ersten Training einträgt und wofür es
/// kein Feld gibt, ist nicht nachholbar.
///
/// ## Die harte Randbedingung
///
/// Fünf bestehende Kern-Testdateien bauen `ImportedSession` ohne Aufwärmen
/// (`gym_session_test`, `gym_session_builder_test`, `gym_session_merge_test`,
/// `gym_day_planner_test`, `muscle_volume_test` — soweit sie Sitzungen
/// anlegen). Sie müssen unverändert weiterlaufen; `.githooks/pre-commit`
/// lässt ohnehin niemanden an sie heran. Daraus folgt: **benannter optionaler
/// Parameter, Vorgabe `null`, kein `required`** — geprüft in der Gruppe „Ohne
/// Aufwärmen bleibt alles, wie es war".
///
/// ## `km` ist echt nullbar
///
/// Bei Mobility gibt es keine Strecke. Eine `0.0` wäre die Behauptung „null
/// Kilometer gelaufen" und nicht „keine Strecke erfasst" — dasselbe Muster
/// wie `ImportedSession.minutes` und `VitalWert.wert` (`CLAUDE.md`: „`0` ist
/// keine Antwort auf ‚kein Wert'"). Dass beides unterschieden wird, steht
/// unten als eigener Fall, in `WarmUpDone` **und** in `ImportedSession.==`.
///
/// ## Keine Nutzertexte im Kern
///
/// `WarmUpKind` trägt Codes, keine deutschen Namen. „Rad", „Laufband",
/// „Rudern", „Crosstrainer", „Seilspringen", „Mobility" sind Beschriftungen
/// und gehören in die Ansicht (`CLAUDE.md`). Die Codes sind dagegen
/// **Persistenzschlüssel** — sie landen in der Spalte, die die Migration auf
/// Schema 18 anlegt, und wer sie ändert, macht alte Einträge namenlos. Beides
/// steht unten fest.
///
/// **Alle Zahlen und Zeitpunkte hier sind erfunden.** Keine Minute, keine
/// Strecke und kein Datum stammt aus Tims Trainingsverlauf oder bezeichnet
/// ein wirkliches Ereignis.

/// Die eindeutig deutschen Beschriftungen aus #40. Sie stehen hier **nur**,
/// um zu prüfen, dass keine von ihnen im Kern auftaucht.
///
/// „Crosstrainer" und „Mobility" fehlen mit Absicht: Sie lauten in beiden
/// Sprachen gleich und bewiesen deshalb nichts — ein Treffer wäre kein
/// Verstoß, ein Fehltreffer kein Freispruch. Für sie trägt die Prüfung auf
/// kleingeschriebenes ASCII.
const _beschriftungen = <String>['Rad', 'Laufband', 'Rudern', 'Seilspringen'];

/// Ein vollständiger `switch` über den sealed-Typ, ohne `default`.
///
/// Dass diese Funktion **übersetzt**, ist die eigentliche Prüfung: Nur über
/// einem `sealed` Typ mit genau diesen beiden Fällen ist der Ausdruck
/// vollständig. Käme ein dritter Zustand dazu, meldet der Analyzer ihn hier —
/// und damit an jeder Stelle, die ihn nicht behandelt.
String _zustand(WarmUp? warmUp) => switch (warmUp) {
  null => 'nichts eingetragen',
  WarmUpSkipped() => 'übersprungen',
  WarmUpDone(:final kind, :final minutes, :final km) =>
    'gemacht:${kind.code}:$minutes:${km ?? '-'}',
};

void main() {
  CompletedSet satz(double gewicht, int wiederholungen) =>
      CompletedSet(weight: gewicht, reps: wiederholungen);

  // Berliner Zeit 18:30 am 21.09.2026 (Sommerzeit, UTC+2). Wie überall im
  // Paket ein UTC-Zeitpunkt, der eine Berliner Wanduhrzeit bezeichnet.
  final abends = DateTime.utc(2026, 9, 21, 16, 30);

  ImportedSession sitzung({
    String id = 'sitzung-1',
    DateTime? wann,
    Workout? workout = Workout.a,
    int? minutes = 62,
    String? note,
    List<ImportedExercise>? uebungen,
    WarmUp? warmUp,
  }) => ImportedSession(
    id: id,
    date: wann ?? abends,
    workout: workout,
    minutes: minutes,
    note: note,
    exercises:
        uebungen ??
        [
          ImportedExercise(
            exerciseId: 'benchPress',
            sets: [satz(40, 8), satz(40, 7)],
          ),
        ],
    warmUp: warmUp,
  );

  group('WarmUpKind: die sechs Arten', () {
    test('Es sind genau sechs, nicht mehr und nicht weniger', () {
      expect(WarmUpKind.values, hasLength(6));
    });

    test('Die Codes sind die gespeicherten Bezeichner', () {
      // Persistenzschlüssel. Sie stehen in der Spalte, die Schema 18 anlegt;
      // wer einen ändert, macht alte Einträge namenlos. Deshalb hier alle
      // sechs einzeln festgenagelt und nicht aus `name` abgeleitet.
      expect(WarmUpKind.bike.code, 'bike');
      expect(WarmUpKind.treadmill.code, 'treadmill');
      expect(WarmUpKind.rowing.code, 'rowing');
      expect(WarmUpKind.crossTrainer.code, 'cross_trainer');
      expect(WarmUpKind.jumpRope.code, 'jump_rope');
      expect(WarmUpKind.mobility.code, 'mobility');
    });

    test('Die Reihenfolge ist die aus #40', () {
      // Rad, Laufband, Rudern, Crosstrainer, Seilspringen, Mobility — die
      // Auswahl, die #40 zeichnet. Die Ansicht darf sich darauf verlassen,
      // statt eine zweite Liste von Hand zu führen.
      expect(WarmUpKind.values, [
        WarmUpKind.bike,
        WarmUpKind.treadmill,
        WarmUpKind.rowing,
        WarmUpKind.crossTrainer,
        WarmUpKind.jumpRope,
        WarmUpKind.mobility,
      ]);
    });

    test('Kein Code kommt zweimal vor', () {
      final codes = WarmUpKind.values.map((art) => art.code).toList();
      expect(codes.toSet(), hasLength(codes.length));
    });

    test('Die Codes sind kleingeschriebenes ASCII mit Unterstrich', () {
      // Ein Code wandert durch die Datenbank, später durch den Export und
      // vielleicht durch eine Adresse. Umlaute und Leerzeichen dort sind eine
      // Fehlerquelle, die niemand braucht.
      final muster = RegExp(r'^[a-z]+(_[a-z]+)*$');
      for (final art in WarmUpKind.values) {
        expect(
          muster.hasMatch(art.code),
          isTrue,
          reason: 'Der Code „${art.code}" passt nicht auf $muster.',
        );
      }
    });

    test('Kein Fall trägt einen deutschen Text', () {
      // „Keine Nutzertexte im Kern" (`CLAUDE.md`). Die Beschriftungen gehören
      // in die Ansicht; stünden sie hier, gäbe es sie später zweimal.
      for (final art in WarmUpKind.values) {
        for (final wort in _beschriftungen) {
          expect(
            art.code.toLowerCase(),
            isNot(contains(wort.toLowerCase())),
            reason: '$art trägt die Beschriftung „$wort" im Code.',
          );
          expect(
            art.name.toLowerCase(),
            isNot(contains(wort.toLowerCase())),
            reason: '$art trägt die Beschriftung „$wort" im Namen.',
          );
        }
      }
    });
  });

  group('WarmUpKind.fromCode', () {
    test('Jeder Code findet seine Art zurück', () {
      for (final art in WarmUpKind.values) {
        expect(WarmUpKind.fromCode(art.code), art);
      }
    });

    test('Ein unbekannter Code ergibt null, nicht eine geratene Art', () {
      // Wie `Workout.fromCode`: Geraten wird nicht. Eine stillschweigende
      // Zuordnung schriebe ein fremdes Aufwärmen in den Verlauf.
      expect(WarmUpKind.fromCode('ergometer'), isNull);
      expect(WarmUpKind.fromCode(''), isNull);
      expect(WarmUpKind.fromCode('bike '), isNull);
      expect(WarmUpKind.fromCode('crossTrainer'), isNull);
      expect(WarmUpKind.fromCode('jump-rope'), isNull);
    });

    test('Groß- und Kleinschreibung werden unterschieden', () {
      // `'bike'` ist der gespeicherte Wert. Würde `'Bike'` ebenfalls gelten,
      // wäre nicht mehr entscheidbar, welcher von beiden geschrieben wurde.
      expect(WarmUpKind.fromCode('Bike'), isNull);
      expect(WarmUpKind.fromCode('BIKE'), isNull);
      expect(WarmUpKind.fromCode('Cross_Trainer'), isNull);
      expect(WarmUpKind.fromCode('Mobility'), isNull);
    });
  });

  group('Die drei Zustände sind paarweise verschieden', () {
    test('Übersprungen ist nicht gemacht', () {
      final uebersprungen = WarmUpSkipped();
      final gemacht = WarmUpDone(kind: WarmUpKind.bike, minutes: 10, km: 3.4);

      expect(uebersprungen, isNot(equals(gemacht)));
      expect(gemacht, isNot(equals(uebersprungen)));
      expect({uebersprungen, gemacht}, hasLength(2));
    });

    test('Nichts eingetragen ist weder übersprungen noch gemacht', () {
      // Der Unterschied, um den es geht: `null` ist keine Antwort,
      // `WarmUpSkipped` ist eine.
      const WarmUp? nichts = null;

      expect(nichts, isNot(equals(WarmUpSkipped())));
      expect(
        nichts,
        isNot(equals(WarmUpDone(kind: WarmUpKind.mobility, minutes: 8))),
      );
      expect(WarmUpSkipped(), isNotNull);
    });

    test('Der vollständige switch kennt genau diese drei Fälle', () {
      // Übersetzt der Ausdruck in `_zustand`, ist `WarmUp` sealed und hat
      // genau zwei Unterklassen — und `null` ist der dritte Zustand.
      expect(_zustand(null), 'nichts eingetragen');
      expect(_zustand(WarmUpSkipped()), 'übersprungen');
      expect(
        _zustand(WarmUpDone(kind: WarmUpKind.rowing, minutes: 12, km: 2.5)),
        'gemacht:rowing:12:2.5',
      );
      expect(
        _zustand(WarmUpDone(kind: WarmUpKind.mobility, minutes: 7)),
        'gemacht:mobility:7:-',
      );
    });

    test('Beide Fälle sind ein WarmUp', () {
      expect(WarmUpSkipped(), isA<WarmUp>());
      expect(WarmUpDone(kind: WarmUpKind.bike, minutes: 10), isA<WarmUp>());
    });
  });

  group('WarmUpSkipped als Werttyp', () {
    test('Zwei übersprungene Aufwärmen sind gleich', () {
      // Ohne das wäre jedes neu geladene „übersprungen" ungleich dem vorigen,
      // und jeder abgeleitete Riverpod-Wert liefe neu — Fehler `03`.
      final eines = WarmUpSkipped();
      final anderes = WarmUpSkipped();

      expect(eines, equals(anderes));
      // Über ein Set geprüft: Ein `==` ohne passenden `hashCode` fällt genau
      // hier auf und sonst nirgends.
      expect({eines, anderes}, hasLength(1));
    });
  });

  group('WarmUpDone trägt Art, Minuten und Strecke', () {
    test('Die Felder kommen unverändert wieder heraus', () {
      final gemacht = WarmUpDone(
        kind: WarmUpKind.treadmill,
        minutes: 10,
        km: 1.6,
      );

      expect(gemacht.kind, WarmUpKind.treadmill);
      expect(gemacht.minutes, 10);
      expect(gemacht.km, 1.6);
    });

    test('Gleiche Angaben ergeben gleiche Aufwärmen', () {
      final eines = WarmUpDone(kind: WarmUpKind.bike, minutes: 10, km: 3.4);
      final anderes = WarmUpDone(kind: WarmUpKind.bike, minutes: 10, km: 3.4);

      expect(eines, equals(anderes));
      expect({eines, anderes}, hasLength(1));
    });

    test('Eine andere Art ist ein anderes Aufwärmen', () {
      final rad = WarmUpDone(kind: WarmUpKind.bike, minutes: 10, km: 3.4);
      final band = WarmUpDone(kind: WarmUpKind.treadmill, minutes: 10, km: 3.4);

      expect(rad, isNot(equals(band)));
    });

    test('Andere Minuten sind ein anderes Aufwärmen', () {
      final kurz = WarmUpDone(kind: WarmUpKind.bike, minutes: 10, km: 3.4);
      final lang = WarmUpDone(kind: WarmUpKind.bike, minutes: 15, km: 3.4);

      expect(kurz, isNot(equals(lang)));
      expect({kurz, lang}, hasLength(2));
    });

    test('Eine andere Strecke ist ein anderes Aufwärmen', () {
      // Genau das Signal, um das es in #40 geht: gleiche Dauer, wachsende
      // Strecke. Fiele die Strecke aus `==`, sähe eine Steigerung aus wie
      // Stillstand.
      final woche1 = WarmUpDone(kind: WarmUpKind.bike, minutes: 10, km: 3.4);
      final woche4 = WarmUpDone(kind: WarmUpKind.bike, minutes: 10, km: 3.9);

      expect(woche1, isNot(equals(woche4)));
      expect({woche1, woche4}, hasLength(2));
    });
  });

  group('Die Strecke ist echt nullbar', () {
    test('Ohne Angabe ist km null, nicht 0', () {
      // Bei Mobility gibt es keine Strecke. `0.0` behauptete „null Kilometer
      // zurückgelegt" — das ist `01` in neuer Verpackung.
      final beweglichkeit = WarmUpDone(kind: WarmUpKind.mobility, minutes: 8);

      expect(beweglichkeit.km, isNull);
      expect(beweglichkeit.km, isNot(0.0));
    });

    test('Auch bei einer Art mit Strecke darf sie fehlen', () {
      // Wer aufs Rad steigt und die Anzeige nicht abliest, hat trotzdem
      // aufgewärmt. „Nicht abgelesen" ist nicht „null Kilometer".
      final ohneAnzeige = WarmUpDone(kind: WarmUpKind.bike, minutes: 10);

      expect(ohneAnzeige.km, isNull);
    });

    test('Keine Strecke und null Kilometer sind nicht dasselbe', () {
      final ohne = WarmUpDone(kind: WarmUpKind.mobility, minutes: 8);
      final nullKm = WarmUpDone(kind: WarmUpKind.mobility, minutes: 8, km: 0.0);

      expect(ohne, isNot(equals(nullKm)));
      expect({ohne, nullKm}, hasLength(2));
    });

    test('Die Strecke ist eine Zahl mit Nachkommastellen', () {
      // „Dafür muss die Strecke mit Komma eingebbar sein und als Zahl abgelegt
      // werden, nicht als Text" (#40). 3,4 km ist der Fall aus dem Ticket.
      final gemacht = WarmUpDone(kind: WarmUpKind.bike, minutes: 10, km: 3.4);

      expect(gemacht.km, isA<double>());
      expect(gemacht.km, closeTo(3.4, 1e-9));
    });
  });

  group('Ohne Aufwärmen bleibt alles, wie es war', () {
    test('Eine Sitzung ohne Angabe hat warmUp null', () {
      // Der Hauptfall: Alles, was die Übernahme aus der alten App (#59)
      // bringt, kommt so herein. Dort gab es kein Feld dafür, und ein
      // erfundenes „übersprungen" behauptete eine Antwort, die niemand gegeben
      // hat.
      final ohne = ImportedSession(
        id: 'uebernommen-1',
        date: abends,
        workout: Workout.a,
        minutes: null,
        note: null,
        exercises: [
          ImportedExercise(exerciseId: 'benchPress', sets: [satz(40, 8)]),
        ],
      );

      expect(ohne.warmUp, isNull);
    });

    test('warmUp ist nicht required', () {
      // Die fünf bestehenden Kern-Testdateien bauen `ImportedSession` ohne
      // Aufwärmen und dürfen nicht brechen. Dieser Fall prüft dieselbe
      // Aufrufform noch einmal ausdrücklich, damit sie nicht beiläufig
      // verschwindet.
      final ohne = ImportedSession(
        id: 'ohne-1',
        date: abends,
        workout: null,
        minutes: 45,
        note: 'Nur ein Prüftext.',
        exercises: const [],
      );

      expect(ohne.warmUp, isNull);
      expect(ohne.exercises, isEmpty);
    });

    test('Zwei Sitzungen ohne Aufwärmen bleiben gleich', () {
      expect(sitzung(), equals(sitzung()));
      expect({sitzung(), sitzung()}, hasLength(1));
    });
  });

  group('ImportedSession vergleicht das Aufwärmen mit', () {
    test('Nichts eingetragen und übersprungen sind zwei Sitzungen', () {
      final nichts = sitzung();
      final uebersprungen = sitzung(warmUp: WarmUpSkipped());

      expect(nichts, isNot(equals(uebersprungen)));
      expect({nichts, uebersprungen}, hasLength(2));
    });

    test('Übersprungen und gemacht sind zwei Sitzungen', () {
      final uebersprungen = sitzung(warmUp: WarmUpSkipped());
      final gemacht = sitzung(
        warmUp: WarmUpDone(kind: WarmUpKind.bike, minutes: 10, km: 3.4),
      );

      expect(uebersprungen, isNot(equals(gemacht)));
      expect({uebersprungen, gemacht}, hasLength(2));
    });

    test('Nichts eingetragen und gemacht sind zwei Sitzungen', () {
      final nichts = sitzung();
      final gemacht = sitzung(
        warmUp: WarmUpDone(kind: WarmUpKind.bike, minutes: 10, km: 3.4),
      );

      expect(nichts, isNot(equals(gemacht)));
      expect({nichts, gemacht}, hasLength(2));
    });

    test('Ein anderes Aufwärmen macht eine andere Sitzung', () {
      final woche1 = sitzung(
        warmUp: WarmUpDone(kind: WarmUpKind.bike, minutes: 10, km: 3.4),
      );
      final woche4 = sitzung(
        warmUp: WarmUpDone(kind: WarmUpKind.bike, minutes: 10, km: 3.9),
      );

      expect(woche1, isNot(equals(woche4)));
      expect({woche1, woche4}, hasLength(2));
    });

    test('Keine Strecke und null Kilometer trennen auch die Sitzungen', () {
      final ohne = sitzung(
        warmUp: WarmUpDone(kind: WarmUpKind.mobility, minutes: 8),
      );
      final nullKm = sitzung(
        warmUp: WarmUpDone(kind: WarmUpKind.mobility, minutes: 8, km: 0.0),
      );

      expect(ohne, isNot(equals(nullKm)));
      expect({ohne, nullKm}, hasLength(2));
    });

    test('Dasselbe Aufwärmen, zweimal gebaut, bleibt dieselbe Sitzung', () {
      // Ohne inhaltlichen Vergleich wäre jede neu geladene Sitzung ungleich
      // der vorigen und jeder abgeleitete Riverpod-Wert liefe neu — `03`,
      // wortgleich, im neuen Code.
      final eine = sitzung(
        warmUp: WarmUpDone(kind: WarmUpKind.rowing, minutes: 12, km: 2.5),
      );
      final andere = sitzung(
        warmUp: WarmUpDone(kind: WarmUpKind.rowing, minutes: 12, km: 2.5),
      );

      expect(eine, equals(andere));
      expect({eine, andere}, hasLength(1));
    });

    test('Zwei übersprungene Sitzungen bleiben dieselbe Sitzung', () {
      expect(
        sitzung(warmUp: WarmUpSkipped()),
        equals(sitzung(warmUp: WarmUpSkipped())),
      );
      expect({
        sitzung(warmUp: WarmUpSkipped()),
        sitzung(warmUp: WarmUpSkipped()),
      }, hasLength(1));
    });
  });

  group('Keine Rechnung hängt am Aufwärmen', () {
    final uebungen = [
      ImportedExercise(
        exerciseId: 'benchPress',
        sets: [satz(40, 8), satz(42.5, 6)],
      ),
      ImportedExercise(exerciseId: 'dips', sets: [satz(0, 10)]),
    ];

    test('setCount zählt das Aufwärmen nicht mit', () {
      // Aufwärmen ist kein Satz. Zählte es mit, stiege die Satzzahl, ohne dass
      // mehr gehoben wurde — und der Vergleich über Wochen ginge kaputt.
      expect(sitzung(uebungen: uebungen).setCount, 3);
      expect(sitzung(uebungen: uebungen, warmUp: WarmUpSkipped()).setCount, 3);
      expect(
        sitzung(
          uebungen: uebungen,
          warmUp: WarmUpDone(kind: WarmUpKind.bike, minutes: 10, km: 3.4),
        ).setCount,
        3,
      );
    });

    test('volumeKg zählt das Aufwärmen nicht mit', () {
      // 40 × 8 + 42,5 × 6 + 0 × 10 = 575. Zehn Minuten Rad tragen zur Tonnage
      // nichts bei; sie sind keine Last.
      expect(sitzung(uebungen: uebungen).volumeKg, 575);
      expect(
        sitzung(uebungen: uebungen, warmUp: WarmUpSkipped()).volumeKg,
        575,
      );
      expect(
        sitzung(
          uebungen: uebungen,
          warmUp: WarmUpDone(kind: WarmUpKind.rowing, minutes: 20, km: 4.0),
        ).volumeKg,
        575,
      );
    });

    test('Die Minuten des Aufwärmens stehen daneben, nicht darin', () {
      // #40, „Zu klären": Vorschlag war „daneben" — sonst wandert die Dauer
      // des Trainings nach oben, ohne dass mehr trainiert wurde. Die Form
      // beantwortet das: zwei Felder, und der Kern addiert sie nicht.
      final gemacht = sitzung(
        minutes: 62,
        warmUp: WarmUpDone(kind: WarmUpKind.bike, minutes: 10, km: 3.4),
      );

      expect(gemacht.minutes, 62);
    });
  });

  group('GymSessionBuilder reicht das Aufwärmen durch', () {
    test('Ohne Angabe bleibt das Aufwärmen null', () {
      // Bestehende Aufrufe sollen unverändert weiterlaufen.
      final ergebnis = GymSessionBuilder.session(
        id: 'eigen-1',
        date: abends,
        workout: Workout.a,
        minutes: 62,
        entries: {
          'benchPress': [RawSet(weight: '40', reps: '8')],
        },
      );

      expect(ergebnis, isNotNull);
      expect(ergebnis!.warmUp, isNull);
    });

    test('Ein gemachtes Aufwärmen kommt unverändert in der Sitzung an', () {
      final ergebnis = GymSessionBuilder.session(
        id: 'eigen-2',
        date: abends,
        workout: Workout.a,
        minutes: 62,
        entries: {
          'benchPress': [RawSet(weight: '40', reps: '8')],
        },
        warmUp: WarmUpDone(kind: WarmUpKind.bike, minutes: 10, km: 3.4),
      );

      expect(
        ergebnis?.warmUp,
        equals(WarmUpDone(kind: WarmUpKind.bike, minutes: 10, km: 3.4)),
      );
    });

    test('Ein übersprungenes Aufwärmen kommt als übersprungen an', () {
      // Nicht als `null`. „Übersprungen" ist die Antwort, die der
      // Plan-Agent braucht.
      final ergebnis = GymSessionBuilder.session(
        id: 'eigen-3',
        date: abends,
        workout: Workout.a,
        entries: {
          'benchPress': [RawSet(weight: '40', reps: '8')],
        },
        warmUp: WarmUpSkipped(),
      );

      expect(ergebnis?.warmUp, equals(WarmUpSkipped()));
      expect(ergebnis?.warmUp, isNotNull);
    });

    test('Eine fehlende Strecke bleibt auch im Builder null', () {
      final ergebnis = GymSessionBuilder.session(
        id: 'eigen-4',
        date: abends,
        workout: Workout.d,
        entries: {
          'benchPress': [RawSet(weight: '40', reps: '8')],
        },
        warmUp: WarmUpDone(kind: WarmUpKind.mobility, minutes: 8),
      );

      final warmUp = ergebnis?.warmUp;
      expect(warmUp, isA<WarmUpDone>());
      expect((warmUp as WarmUpDone).km, isNull);
    });

    test('Aufwärmen allein macht aus einer leeren Sitzung keine gültige', () {
      // **Die Stelle, an der man es anders erwarten könnte.** Zehn Minuten
      // Rad sind kein Training: Eine Sitzung ohne einen einzigen brauchbaren
      // Satz bliebe eine Zeile ohne Inhalt in „Letzte Trainings" und ein
      // Punkt bei null im Verlauf.
      final ergebnis = GymSessionBuilder.session(
        id: 'eigen-5',
        date: abends,
        workout: Workout.a,
        entries: const {},
        warmUp: WarmUpDone(kind: WarmUpKind.bike, minutes: 10, km: 3.4),
      );

      expect(ergebnis, isNull);
    });

    test('Auch mit nur unbrauchbaren Sätzen entsteht keine Sitzung', () {
      final ergebnis = GymSessionBuilder.session(
        id: 'eigen-6',
        date: abends,
        workout: Workout.a,
        entries: {
          'benchPress': [
            RawSet(weight: '40', reps: ''),
            RawSet(weight: '40', reps: '0'),
          ],
        },
        warmUp: WarmUpSkipped(),
      );

      expect(ergebnis, isNull);
    });

    test('Ein unbrauchbarer Satz ändert nichts am Aufwärmen', () {
      // Der verworfene Satz fällt weg, das Aufwärmen bleibt vollständig
      // stehen. Es hängt am Training, nicht am einzelnen Satz.
      final ergebnis = GymSessionBuilder.session(
        id: 'eigen-7',
        date: abends,
        workout: Workout.a,
        entries: {
          'benchPress': [
            RawSet(weight: 'abc', reps: '8'),
            RawSet(weight: '40', reps: '8'),
          ],
        },
        warmUp: WarmUpDone(kind: WarmUpKind.jumpRope, minutes: 5),
      );

      expect(ergebnis?.exercises.first.sets, [satz(40, 8)]);
      expect(
        ergebnis?.warmUp,
        equals(WarmUpDone(kind: WarmUpKind.jumpRope, minutes: 5)),
      );
    });

    test('Das Aufwärmen lässt die übrigen Felder unberührt', () {
      final ergebnis = GymSessionBuilder.session(
        id: 'eigen-8',
        date: abends,
        workout: Workout.c,
        minutes: 55,
        note: 'Nur ein Prüftext.',
        entries: {
          'benchPress': [RawSet(weight: '40', reps: '8')],
        },
        warmUp: WarmUpDone(kind: WarmUpKind.crossTrainer, minutes: 12, km: 2.1),
      );

      expect(ergebnis?.id, 'eigen-8');
      expect(ergebnis?.date, abends);
      expect(ergebnis?.workout, Workout.c);
      expect(ergebnis?.minutes, 55);
      expect(ergebnis?.note, 'Nur ein Prüftext.');
      expect(ergebnis?.setCount, 1);
    });
  });

  group('GymSessionMerge verliert das Aufwärmen nicht', () {
    ImportedSession eineSitzung(
      String id,
      DateTime wann,
      Workout? workout, {
      WarmUp? warmUp,
    }) => ImportedSession(
      id: id,
      date: wann,
      workout: workout,
      minutes: null,
      note: null,
      exercises: [
        ImportedExercise(exerciseId: 'benchPress', sets: [satz(40, 8)]),
      ],
      warmUp: warmUp,
    );

    // Berlin 18:00 am 20. bzw. 21.09.2026 (Sommerzeit, UTC+2).
    final tag1 = DateTime.utc(2026, 9, 20, 16);
    final tag2 = DateTime.utc(2026, 9, 21, 16);

    test('Beide Listen bringen ihr Aufwärmen mit durch', () {
      final ergebnis = GymSessionMerge.merge(
        logged: [
          eineSitzung(
            'eigen',
            tag2,
            Workout.a,
            warmUp: WarmUpDone(kind: WarmUpKind.bike, minutes: 10, km: 3.4),
          ),
        ],
        imported: [
          eineSitzung('uebernommen', tag1, Workout.c, warmUp: WarmUpSkipped()),
        ],
      );

      expect(ergebnis, hasLength(2));
      expect(
        ergebnis.first.warmUp,
        equals(WarmUpDone(kind: WarmUpKind.bike, minutes: 10, km: 3.4)),
      );
      expect(ergebnis.last.warmUp, equals(WarmUpSkipped()));
    });

    test('Gewinnt das eigene Training, gewinnt es ganz', () {
      // Auch wenn sein Aufwärmen `null` ist und die übernommene Fassung eines
      // hätte: Zusammengesetzt würde eine Sitzung entstehen, die es nie
      // gegeben hat. Dasselbe Prinzip wie bei den Satz-Uhrzeiten.
      final ergebnis = GymSessionMerge.merge(
        logged: [eineSitzung('eigen', tag1, Workout.a)],
        imported: [
          eineSitzung(
            'uebernommen',
            tag1,
            Workout.a,
            warmUp: WarmUpDone(kind: WarmUpKind.bike, minutes: 10, km: 3.4),
          ),
        ],
      );

      expect(ergebnis, hasLength(1));
      expect(ergebnis.single.id, 'eigen');
      expect(ergebnis.single.warmUp, isNull);
    });

    test('Umgekehrt verschwindet das übernommene „nichts eingetragen"', () {
      final ergebnis = GymSessionMerge.merge(
        logged: [
          eineSitzung(
            'eigen',
            tag1,
            Workout.a,
            warmUp: WarmUpDone(kind: WarmUpKind.treadmill, minutes: 10),
          ),
        ],
        imported: [eineSitzung('uebernommen', tag1, Workout.a)],
      );

      expect(ergebnis, hasLength(1));
      expect(ergebnis.single.id, 'eigen');
      expect(
        ergebnis.single.warmUp,
        equals(WarmUpDone(kind: WarmUpKind.treadmill, minutes: 10)),
      );
    });

    test('Auch ein übersprungenes Aufwärmen wird nicht aufgefüllt', () {
      // „Übersprungen" ist die Antwort des eigenen Trainings. Sie durch die
      // Zahlen der übernommenen Fassung zu ersetzen hieße, Tims Antwort zu
      // überschreiben.
      final ergebnis = GymSessionMerge.merge(
        logged: [
          eineSitzung('eigen', tag1, Workout.a, warmUp: WarmUpSkipped()),
        ],
        imported: [
          eineSitzung(
            'uebernommen',
            tag1,
            Workout.a,
            warmUp: WarmUpDone(kind: WarmUpKind.bike, minutes: 10, km: 3.4),
          ),
        ],
      );

      expect(ergebnis.single.warmUp, equals(WarmUpSkipped()));
    });

    test('Das Aufwärmen gehört nicht zum Schlüssel', () {
      // Dasselbe Training desselben Tages, nur mit anderem Aufwärmen, ist
      // dieselbe Sitzung — sonst stünde sie zweimal da.
      final ergebnis = GymSessionMerge.merge(
        logged: [
          eineSitzung('eigen', tag1, Workout.a, warmUp: WarmUpSkipped()),
        ],
        imported: [
          eineSitzung(
            'uebernommen',
            tag1,
            Workout.a,
            warmUp: WarmUpDone(kind: WarmUpKind.rowing, minutes: 9, km: 1.8),
          ),
        ],
      );

      expect(ergebnis, hasLength(1));
    });

    test('history führt Sätze und kein Aufwärmen', () {
      // Sie speist `Progression.suggest`. Ein Aufwärmen hätte dort weder
      // Gewicht noch Wiederholungen.
      final ohne = GymSessionMerge.history([
        eineSitzung('eigen', tag1, Workout.a),
      ]);
      final mit = GymSessionMerge.history([
        eineSitzung(
          'eigen',
          tag1,
          Workout.a,
          warmUp: WarmUpDone(kind: WarmUpKind.bike, minutes: 10, km: 3.4),
        ),
      ]);

      expect(mit.keys, ['benchPress']);
      expect(mit['benchPress'], [
        [satz(40, 8)],
      ]);
      expect(mit, equals(ohne));
    });
  });
}
