import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für die **Double Progression** aus Ticket #91, Block B —
/// `docs/SPEC.md` 4.4 („Steigerungslogik (Double Progression), pro Übung aus
/// dem letzten Training") und die API-Vorgabe
/// `docs/superpowers/specs/2026-11-10-gym-kern-dart-api.md`.
///
/// Fachliche Vorlage ist
/// `Packages/TrainingsCore/Sources/TrainingsCore/Gym/Progression.swift` samt
/// `Tests/TrainingsCoreTests/ProgressionTests.swift`. Die Zahlen müssen
/// dieselben herauskommen.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, nie verändert werden.
///
/// ## API, die diese Tests verbindlich vorgeben
///
/// ```dart
/// final class CompletedSet {
///   const CompletedSet({required double weight, required int reps});
///   final double weight; // negativ = Unterstützung (−27 sind 27 kg Hilfe)
///   final int reps;      // bei Zeitübungen Sekunden
///   // Wertgleichheit.
/// }
///
/// sealed class Suggestion { }
/// final class FirstTime     extends Suggestion { int targetReps; }
/// final class Increase      extends Suggestion { double toWeight, by; int targetReps; }
/// final class Hold          extends Suggestion { double atWeight; int targetReps; }
/// final class Deload        extends Suggestion { double toWeight, fromWeight; int targetReps; }
/// final class IncreaseTime  extends Suggestion { int toSeconds; }
/// final class HarderVariant extends Suggestion { }
///
/// abstract final class Progression {
///   /// [history]: Sitzungen, **neueste zuerst**.
///   static Suggestion suggest(Exercise exercise, List<List<CompletedSet>> history);
/// }
/// ```
///
/// Swifts `enum Suggestion` mit assoziierten Werten wird in Dart eine
/// **sealed class**. Geprüft wird deshalb immer **Fall und Zahl**, nie nur
/// der Fall: Ein `Increase` mit dem falschen Gewicht ist genauso falsch wie
/// ein `Hold` an seiner Stelle.
///
/// ## Die Übungen stehen hier, nicht im Katalog
///
/// Die Swift-Vorlage rechnet gegen `ExerciseCatalog.all["benchPress"]` und
/// Geschwister. Hier sind es **erfundene Prüfübungen** mit denselben
/// Kennzahlen: Ein Test, der an einer Katalogzahl hängt, wird rot, sobald
/// jemand eine Übung anpasst, und zeigt dann auf die falsche Stelle. Die
/// Steigerungslogik kennt vom Katalog ohnehin nur `repLow`, `repHigh`,
/// `increment` und `isTimed`.
///
/// **Alle Zahlen hier sind erfunden.** Kein Gewicht und keine
/// Wiederholungszahl stammt aus Tims Trainingsverlauf.

/// Eine Prüfübung. Alles außer `repLow`, `repHigh`, `increment` und
/// `isTimed` ist für die Steigerungslogik ohne Belang.
Exercise _uebung({
  required String id,
  required int repLow,
  required int repHigh,
  required double increment,
  bool isTimed = false,
  bool allowsAssist = false,
}) {
  return Exercise(
    id: id,
    name: 'Prüfübung',
    sets: 3,
    repLow: repLow,
    repHigh: repHigh,
    increment: increment,
    isTimed: isTimed,
    allowsAssist: allowsAssist,
    cue: 'Nur für den Test.',
    howTo: const ['Schritt eins', 'Schritt zwei', 'Schritt drei'],
    commonMistake: 'Keiner.',
    youTubeQuery: 'Prüfübung',
    muscles: const {Muscle.chest: 1.0},
  );
}

/// Eine Sitzung mit gleichem Gewicht und den genannten Wiederholungen.
List<CompletedSet> _saetze(double weight, List<int> reps) => [
  for (final r in reps) CompletedSet(weight: weight, reps: r),
];

/// Prüft den Fall und gibt ihn getypt zurück, damit die Zahlen danach
/// einzeln und mit Toleranz verglichen werden können.
T _als<T extends Suggestion>(Suggestion vorschlag) {
  expect(
    vorschlag,
    isA<T>(),
    reason: 'Erwartet war $T, geliefert wurde $vorschlag.',
  );
  return vorschlag as T;
}

const double _toleranz = 1e-9;

void main() {
  // 4 × 6–10 Wiederholungen, Schrittweite 2,5 kg — die Form einer schweren
  // Langhantelübung.
  final langhantel = _uebung(
    id: 'pruefLanghantel',
    repLow: 6,
    repHigh: 10,
    increment: 2.5,
  );

  // 3 × 6–12, Schrittweite 2,5 kg, Unterstützung erlaubt. Unterstützung wird
  // negativ gespeichert: −27 sind 27 kg Hilfe von der Maschine.
  final mitHilfe = _uebung(
    id: 'pruefMitHilfe',
    repLow: 6,
    repHigh: 12,
    increment: 2.5,
    allowsAssist: true,
  );

  // 3 × 30–45 Sekunden, Schrittweite 5 Sekunden. `increment` zählt hier
  // Sekunden, nicht Kilogramm.
  final aufZeit = _uebung(
    id: 'pruefAufZeit',
    repLow: 30,
    repHigh: 45,
    increment: 5,
    isTimed: true,
  );

  group('Ohne Verlauf', () {
    test('nennt der Vorschlag den unteren Zielbereich und kein Gewicht', () {
      final v = _als<FirstTime>(Progression.suggest(langhantel, const []));
      expect(v.targetReps, 6);
    });

    test('bekommt eine Zeitübung die untere Sekundenzahl', () {
      final v = _als<IncreaseTime>(Progression.suggest(aufZeit, const []));
      expect(v.toSeconds, 30);
    });

    test('zählt eine Sitzung aus lauter Nullen nicht als Verlauf', () {
      // Sätze mit null Wiederholungen gelten als nicht ausgeführt. Bleibt
      // davon nichts übrig, ist das kein Training und kein Verlauf.
      final v = _als<FirstTime>(
        Progression.suggest(langhantel, [
          _saetze(52.5, const [0, 0, 0]),
        ]),
      );
      expect(v.targetReps, 6);
    });

    test('zählt eine leere Sitzungsliste nicht als Verlauf', () {
      final v = _als<FirstTime>(Progression.suggest(langhantel, [const []]));
      expect(v.targetReps, 6);
    });
  });

  group('Steigern', () {
    test('alle Sätze an der oberen Grenze heißt steigern', () {
      final v = _als<Increase>(
        Progression.suggest(langhantel, [
          _saetze(52.5, const [10, 10, 10, 11]),
        ]),
      );
      expect(v.toWeight, closeTo(55, _toleranz));
      expect(v.by, closeTo(2.5, _toleranz));
      // Nach der Steigerung beginnt der Bereich wieder unten.
      expect(v.targetReps, 6);
    });

    test('`by` ist die Schrittweite der Übung, nicht eine feste Zahl', () {
      final kurzhantel = _uebung(
        id: 'pruefKurzhantel',
        repLow: 8,
        repHigh: 12,
        increment: 2,
      );
      final v = _als<Increase>(
        Progression.suggest(kurzhantel, [
          _saetze(45, const [12, 12, 12]),
        ]),
      );
      expect(v.toWeight, closeTo(47, _toleranz));
      expect(v.by, closeTo(2, _toleranz));
      expect(v.targetReps, 8);
    });

    test('bei mehreren Gewichten zählt der schwerste Satz', () {
      // Der leichtere Aufbausatz mit 40 kg darf das Ergebnis nicht auf 42,5
      // ziehen.
      final v = _als<Increase>(
        Progression.suggest(langhantel, [
          [
            const CompletedSet(weight: 40, reps: 12),
            const CompletedSet(weight: 52.5, reps: 10),
            const CompletedSet(weight: 52.5, reps: 10),
            const CompletedSet(weight: 52.5, reps: 10),
          ],
        ]),
      );
      expect(v.toWeight, closeTo(55, _toleranz));
      expect(v.by, closeTo(2.5, _toleranz));
      expect(v.targetReps, 6);
    });

    test('nur die neueste Sitzung entscheidet über das Steigern', () {
      // Die Sitzung davor war schwach; gesteigert wird trotzdem, weil die
      // neueste oben ankam.
      final v = _als<Increase>(
        Progression.suggest(langhantel, [
          _saetze(52.5, const [10, 10, 10]),
          _saetze(52.5, const [4, 4, 4]),
        ]),
      );
      expect(v.toWeight, closeTo(55, _toleranz));
      expect(v.targetReps, 6);
    });
  });

  group('Halten', () {
    test('ein Satz unter der oberen Grenze heißt halten', () {
      final v = _als<Hold>(
        Progression.suggest(langhantel, [
          _saetze(52.5, const [10, 10, 9, 10]),
        ]),
      );
      expect(v.atWeight, closeTo(52.5, _toleranz));
      // Der schwächste Satz am Höchstgewicht war 9, angestrebt wird 10.
      expect(v.targetReps, 10);
    });

    test('das Wiederholungsziel ist auf die obere Grenze gedeckelt', () {
      // Der schwächste Satz am Höchstgewicht hat schon 10; +1 wäre 11 und
      // läge über der oberen Grenze. Gesteigert wird trotzdem nicht, weil
      // der Aufbausatz mit 40 kg nicht oben ankam.
      final v = _als<Hold>(
        Progression.suggest(langhantel, [
          [
            const CompletedSet(weight: 52.5, reps: 10),
            const CompletedSet(weight: 52.5, reps: 11),
            const CompletedSet(weight: 40, reps: 5),
          ],
        ]),
      );
      expect(v.atWeight, closeTo(52.5, _toleranz));
      expect(v.targetReps, 10);
    });

    test('einmal unter der unteren Grenze heißt noch halten', () {
      final v = _als<Hold>(
        Progression.suggest(langhantel, [
          _saetze(52.5, const [5, 6, 6, 6]),
          _saetze(52.5, const [8, 8, 7, 7]),
        ]),
      );
      expect(v.atWeight, closeTo(52.5, _toleranz));
      expect(v.targetReps, 6);
    });

    test('eine einzelne schwache Sitzung ohne Vorgänger heißt halten', () {
      // Es gibt keine zweite Sitzung, also auch keine zwei schwachen
      // hintereinander.
      final v = _als<Hold>(
        Progression.suggest(langhantel, [
          _saetze(52.5, const [4, 4, 3]),
        ]),
      );
      expect(v.atWeight, closeTo(52.5, _toleranz));
      // Schwächster Satz am Höchstgewicht war 3, angestrebt wird 4.
      expect(v.targetReps, 4);
    });

    test('ein schwacher Satz am leichteren Gewicht löst keinen Deload aus', () {
      // Unter der unteren Grenze zählt nur, was am Höchstgewicht passiert.
      // Die 3 Wiederholungen am Aufbausatz sind kein Einbruch.
      final verlauf = [
        [
          const CompletedSet(weight: 52.5, reps: 8),
          const CompletedSet(weight: 40, reps: 3),
        ],
        [
          const CompletedSet(weight: 52.5, reps: 8),
          const CompletedSet(weight: 40, reps: 3),
        ],
      ];
      final v = _als<Hold>(Progression.suggest(langhantel, verlauf));
      expect(v.atWeight, closeTo(52.5, _toleranz));
      expect(v.targetReps, 9);
    });

    test('die Vorsitzung zählt nur mit ihrem eigenen Höchstgewicht', () {
      // Die neueste Sitzung ist schwach. In der Sitzung davor liegt der
      // schwache Satz aber am leichteren Gewicht — ihr Höchstgewicht trug
      // 8 Wiederholungen. Also kein zweiter schwacher Durchgang.
      final v = _als<Hold>(
        Progression.suggest(langhantel, [
          _saetze(52.5, const [5, 5, 5]),
          [
            const CompletedSet(weight: 40, reps: 3),
            const CompletedSet(weight: 52.5, reps: 8),
          ],
        ]),
      );
      expect(v.atWeight, closeTo(52.5, _toleranz));
      expect(v.targetReps, 6);
    });
  });

  group('Reduzieren', () {
    test(
      'zweimal hintereinander unter der unteren Grenze heißt reduzieren',
      () {
        final v = _als<Deload>(
          Progression.suggest(langhantel, [
            _saetze(52.5, const [5, 5, 4, 4]),
            _saetze(52.5, const [5, 6, 5, 5]),
          ]),
        );
        // 52,5 · 0,9 = 47,25 → auf die Schrittweite 2,5 gerundet 47,5.
        expect(v.toWeight, closeTo(47.5, _toleranz));
        expect(v.fromWeight, closeTo(52.5, _toleranz));
        expect(v.targetReps, 6);
      },
    );

    test(
      'eine dazwischenliegende Nullsitzung verdeckt den Vorgänger nicht',
      () {
        // Die mittlere Sitzung ist nicht ausgeführt und wird verworfen. Damit
        // stehen die beiden schwachen Durchgänge hintereinander.
        final v = _als<Deload>(
          Progression.suggest(langhantel, [
            _saetze(52.5, const [5, 5, 4]),
            _saetze(52.5, const [0, 0, 0]),
            _saetze(52.5, const [5, 5, 4]),
          ]),
        );
        expect(v.toWeight, closeTo(47.5, _toleranz));
        expect(v.fromWeight, closeTo(52.5, _toleranz));
        expect(v.targetReps, 6);
      },
    );

    test('nur die unmittelbar vorige Sitzung zählt als zweiter Einbruch', () {
      // Neueste Sitzung schwach, die davor stark, die dritte wieder schwach.
      // Zwei Einbrüche, aber nicht hintereinander.
      final v = _als<Hold>(
        Progression.suggest(langhantel, [
          _saetze(52.5, const [5, 5, 4]),
          _saetze(52.5, const [8, 8, 8]),
          _saetze(52.5, const [4, 4, 4]),
        ]),
      );
      expect(v.atWeight, closeTo(52.5, _toleranz));
      expect(v.targetReps, 5);
    });
  });

  group('Unterstützung', () {
    test('steigern bewegt den Wert Richtung null', () {
      // −27 plus Schrittweite ist −24,5: weniger Hilfe, also schwerer.
      final v = _als<Increase>(
        Progression.suggest(mitHilfe, [
          _saetze(-27, const [12, 12, 12]),
        ]),
      );
      expect(v.toWeight, closeTo(-24.5, _toleranz));
      expect(v.by, closeTo(2.5, _toleranz));
      expect(v.targetReps, 6);
    });

    test('der schwerste Satz ist der, der näher an null liegt', () {
      // −24,5 ist schwerer als −27, weil weniger Hilfe anliegt. Gehalten
      // wird deshalb bei −24,5 und nicht bei −27.
      final v = _als<Hold>(
        Progression.suggest(mitHilfe, [
          [
            const CompletedSet(weight: -27, reps: 10),
            const CompletedSet(weight: -24.5, reps: 7),
          ],
        ]),
      );
      expect(v.atWeight, closeTo(-24.5, _toleranz));
      expect(v.targetReps, 8);
    });

    test('reduzieren bewegt den Wert von null weg', () {
      // „10 % leichter" heißt bei Unterstützung **mehr** Hilfe, der Betrag
      // wächst also: 27 · 1,1 = 29,7 → auf 2,5 gerundet 30. Wer hier · 0,9
      // rechnet, käme auf −24,5 und machte die Übung schwerer — genau
      // falsch herum.
      final v = _als<Deload>(
        Progression.suggest(mitHilfe, [
          _saetze(-27, const [4, 4, 3]),
          _saetze(-27, const [5, 5, 4]),
        ]),
      );
      expect(v.toWeight, closeTo(-30, _toleranz));
      expect(v.fromWeight, closeTo(-27, _toleranz));
      expect(v.targetReps, 6);
    });

    test('der reduzierte Wert bleibt negativ und ist betragsmäßig größer', () {
      // Zweiter Fall mit anderer Ausgangszahl, damit nicht eine einzelne
      // glatt aufgehende Rechnung die Richtung beweist.
      // 20 · 1,1 = 22 → auf 2,5 gerundet 22,5.
      final v = _als<Deload>(
        Progression.suggest(mitHilfe, [
          _saetze(-20, const [5, 4, 4]),
          _saetze(-20, const [5, 5, 5]),
        ]),
      );
      expect(v.toWeight, closeTo(-22.5, _toleranz));
      expect(v.fromWeight, closeTo(-20, _toleranz));
      expect(v.toWeight, lessThan(v.fromWeight));
      expect(v.toWeight.abs(), greaterThan(v.fromWeight.abs()));
    });

    test('halten nennt das unterstützte Gewicht unverändert', () {
      final v = _als<Hold>(
        Progression.suggest(mitHilfe, [
          _saetze(-27, const [9, 9, 8]),
        ]),
      );
      expect(v.atWeight, closeTo(-27, _toleranz));
      expect(v.targetReps, 9);
    });
  });

  group('Runden auf die Schrittweite', () {
    test('ein reduziertes Gewicht ist an der Hantel einstellbar', () {
      // 40 · 0,9 = 36 — das liegt zwischen zwei Scheiben. Gerundet auf die
      // Schrittweite 2,5 wird daraus 35, nicht 36.
      final v = _als<Deload>(
        Progression.suggest(langhantel, [
          _saetze(40, const [5, 5, 4]),
          _saetze(40, const [5, 5, 5]),
        ]),
      );
      expect(v.toWeight, closeTo(35, _toleranz));
      expect(v.fromWeight, closeTo(40, _toleranz));
    });

    test('gerundet wird zur nächsten Schrittweite, auch nach oben', () {
      // Schrittweite 1 kg: 11 · 0,9 = 9,9 → 10, nicht 9.
      final seitheben = _uebung(
        id: 'pruefSeitheben',
        repLow: 12,
        repHigh: 20,
        increment: 1,
      );
      final v = _als<Deload>(
        Progression.suggest(seitheben, [
          _saetze(11, const [10, 9, 9]),
          _saetze(11, const [11, 10, 10]),
        ]),
      );
      expect(v.toWeight, closeTo(10, _toleranz));
      expect(v.fromWeight, closeTo(11, _toleranz));
      expect(v.targetReps, 12);
    });

    test('die Rundung folgt der Schrittweite der Übung, nicht 2,5', () {
      // Schrittweite 2 kg: 45 · 0,9 = 40,5 → 40.
      final kurzhantel = _uebung(
        id: 'pruefKurzhantel2',
        repLow: 8,
        repHigh: 12,
        increment: 2,
      );
      final v = _als<Deload>(
        Progression.suggest(kurzhantel, [
          _saetze(45, const [7, 6, 6]),
          _saetze(45, const [7, 7, 7]),
        ]),
      );
      expect(v.toWeight, closeTo(40, _toleranz));
      expect(v.fromWeight, closeTo(45, _toleranz));
      expect(v.targetReps, 8);
    });
  });

  group('Zeitübungen', () {
    test('steigern Sekunden statt Gewicht', () {
      final v = _als<IncreaseTime>(
        Progression.suggest(aufZeit, [
          _saetze(0, const [35, 35, 35]),
        ]),
      );
      expect(v.toSeconds, 40);
    });

    test('rechnen vom kürzesten Satz aus', () {
      // Nicht vom längsten und nicht vom Mittel: Der kürzeste Satz ist der,
      // der das nächste Ziel trägt.
      final v = _als<IncreaseTime>(
        Progression.suggest(aufZeit, [
          _saetze(0, const [40, 35, 44]),
        ]),
      );
      expect(v.toSeconds, 40);
    });

    test('decken das nächste Ziel auf die obere Grenze', () {
      // 42 + 5 wären 47 Sekunden; die obere Grenze liegt bei 45.
      final v = _als<IncreaseTime>(
        Progression.suggest(aufZeit, [
          _saetze(0, const [42, 43, 44]),
        ]),
      );
      expect(v.toSeconds, 45);
    });

    test('verlangen eine schwerere Variante, sobald die Obergrenze steht', () {
      _als<HarderVariant>(
        Progression.suggest(aufZeit, [
          _saetze(0, const [45, 45, 46]),
        ]),
      );
    });

    test('nehmen die Obergrenze genau beim Erreichen, nicht erst darüber', () {
      // Der kürzeste Satz liegt exakt auf 45 — das ist „erreicht".
      _als<HarderVariant>(
        Progression.suggest(aufZeit, [
          _saetze(0, const [45, 50, 60]),
        ]),
      );
      // Eine Sekunde darunter ist es noch nicht.
      final v = _als<IncreaseTime>(
        Progression.suggest(aufZeit, [
          _saetze(0, const [44, 50, 60]),
        ]),
      );
      expect(v.toSeconds, 45);
    });

    test('verwerfen Sätze mit null Sekunden', () {
      // Ein leer gelassenes Feld darf den kürzesten Satz nicht auf 0 ziehen.
      final v = _als<IncreaseTime>(
        Progression.suggest(aufZeit, [
          _saetze(0, const [0, 35, 35]),
        ]),
      );
      expect(v.toSeconds, 40);
    });

    test('ignorieren das Gewichtsfeld', () {
      // Bei einer Zeitübung steht im Gewichtsfeld nichts Sinnvolles; der
      // Zweig darf es nicht anfassen.
      final v = _als<IncreaseTime>(
        Progression.suggest(aufZeit, [
          _saetze(12.5, const [35, 35, 35]),
        ]),
      );
      expect(v.toSeconds, 40);
    });
  });

  group('Nicht ausgeführte Sätze', () {
    test('lösen keinen Deload aus', () {
      // Beide Sitzungen tragen je einen leeren Satz. Mit reps 0 als
      // „unter der unteren Grenze" gelesen wäre das zweimal schwach und
      // damit ein Deload — tatsächlich sind es zwei gehaltene Sitzungen.
      final verlauf = [
        [
          const CompletedSet(weight: 52.5, reps: 9),
          const CompletedSet(weight: 52.5, reps: 0),
        ],
        [
          const CompletedSet(weight: 52.5, reps: 9),
          const CompletedSet(weight: 52.5, reps: 0),
        ],
      ];
      final v = _als<Hold>(Progression.suggest(langhantel, verlauf));
      expect(v.atWeight, closeTo(52.5, _toleranz));
      expect(v.targetReps, 10);
    });

    test('verhindern das Steigern nicht', () {
      // Alle tatsächlich ausgeführten Sätze lagen oben.
      final v = _als<Increase>(
        Progression.suggest(langhantel, [
          [
            const CompletedSet(weight: 52.5, reps: 10),
            const CompletedSet(weight: 52.5, reps: 10),
            const CompletedSet(weight: 52.5, reps: 0),
          ],
        ]),
      );
      expect(v.toWeight, closeTo(55, _toleranz));
      expect(v.targetReps, 6);
    });

    test('zählen auch mit negativen Wiederholungen nicht', () {
      // Eine negative Wiederholungszahl ist kein ausgeführter Satz.
      final v = _als<Increase>(
        Progression.suggest(langhantel, [
          [
            const CompletedSet(weight: 52.5, reps: 10),
            const CompletedSet(weight: 52.5, reps: -3),
          ],
        ]),
      );
      expect(v.toWeight, closeTo(55, _toleranz));
    });
  });

  group('Wertgleichheit', () {
    test('zwei gleiche Sätze sind gleich', () {
      const a = CompletedSet(weight: 52.5, reps: 10);
      const b = CompletedSet(weight: 52.5, reps: 10);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(const CompletedSet(weight: 52.5, reps: 9))));
      expect(a, isNot(equals(const CompletedSet(weight: 50, reps: 10))));
    });

    test('zwei gleiche Vorschläge sind gleich', () {
      expect(FirstTime(targetReps: 6), equals(FirstTime(targetReps: 6)));
      expect(
        FirstTime(targetReps: 6).hashCode,
        equals(FirstTime(targetReps: 6).hashCode),
      );

      expect(
        Increase(toWeight: 55, by: 2.5, targetReps: 6),
        equals(Increase(toWeight: 55, by: 2.5, targetReps: 6)),
      );
      expect(
        Hold(atWeight: 52.5, targetReps: 10),
        equals(Hold(atWeight: 52.5, targetReps: 10)),
      );
      expect(
        Deload(toWeight: 47.5, fromWeight: 52.5, targetReps: 6),
        equals(Deload(toWeight: 47.5, fromWeight: 52.5, targetReps: 6)),
      );
      expect(IncreaseTime(toSeconds: 40), equals(IncreaseTime(toSeconds: 40)));
      expect(HarderVariant(), equals(HarderVariant()));
      expect(HarderVariant().hashCode, equals(HarderVariant().hashCode));
    });

    test('Vorschläge mit anderen Zahlen sind ungleich', () {
      expect(
        Increase(toWeight: 55, by: 2.5, targetReps: 6),
        isNot(equals(Increase(toWeight: 57.5, by: 2.5, targetReps: 6))),
      );
      expect(
        Hold(atWeight: 52.5, targetReps: 10),
        isNot(equals(Hold(atWeight: 52.5, targetReps: 9))),
      );
      expect(
        IncreaseTime(toSeconds: 40),
        isNot(equals(IncreaseTime(toSeconds: 45))),
      );
    });

    test('Vorschläge verschiedener Fälle sind ungleich', () {
      // Ohne das wären „halten bei 52,5" und „reduzieren auf 52,5" für
      // einen Vergleich dasselbe.
      expect(FirstTime(targetReps: 6), isNot(equals(HarderVariant())));
      expect(
        Hold(atWeight: 52.5, targetReps: 6),
        isNot(equals(Deload(toWeight: 52.5, fromWeight: 55, targetReps: 6))),
      );
    });
  });
}
