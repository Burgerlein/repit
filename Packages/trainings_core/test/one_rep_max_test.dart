import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für das **geschätzte Einwiederholungsmaximum** aus Ticket #91,
/// Block B — `docs/SPEC.md` 4.4 („Fortschritt pro Übung … geschätztes 1RM
/// (Epley: Gewicht·(1+Wdh/30)). Plateau = kein 1RM-Anstieg über
/// 4 Trainings.") und die API-Vorgabe
/// `docs/superpowers/specs/2026-11-10-gym-kern-dart-api.md`.
///
/// Fachliche Vorlage ist
/// `Packages/TrainingsCore/Sources/TrainingsCore/Gym/OneRepMax.swift` samt
/// `Tests/TrainingsCoreTests/OneRepMaxTests.swift`.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, nie verändert werden.
///
/// ## API, die diese Tests verbindlich vorgeben
///
/// ```dart
/// abstract final class OneRepMax {
///   /// Epley, auf eine Nachkommastelle gerundet. `null` bei Gewicht ≤ 0
///   /// oder Wiederholungen ≤ 0.
///   static double? epley({required double weight, required int reps});
///   /// Der beste Satz einer Sitzung, `null` wenn keiner schätzbar ist.
///   static double? best(List<CompletedSet> session);
///   /// [sessions] neueste zuerst.
///   static bool isPlateau(List<List<CompletedSet>> sessions);
/// }
/// ```
///
/// Epley ist eine **Schätzung**, kein Maximalversuch, und wird mit
/// steigender Wiederholungszahl ungenauer.
///
/// **Alle Zahlen hier sind erfunden.** Kein Gewicht und keine
/// Wiederholungszahl stammt aus Tims Trainingsverlauf.
void main() {
  group('Epley', () {
    test('50 kg mal 10 Wiederholungen ergeben rund 66,7 kg', () {
      // 50 · (1 + 10/30) = 66,666… → eine Nachkommastelle: 66,7.
      final v = OneRepMax.epley(weight: 50, reps: 10);
      expect(v, isNotNull);
      expect(v!, closeTo(66.7, 0.05));
    });

    test('das Ergebnis trägt genau eine Nachkommastelle', () {
      // 50 · (1 + 7/30) = 61,666… → 61,7, nicht 61,66666…
      final v = OneRepMax.epley(weight: 50, reps: 7);
      expect(v, isNotNull);
      expect(v!, closeTo(61.7, 1e-9));
    });

    test('eine einzelne Wiederholung ist das Gewicht selbst', () {
      // Ein Satz mit einer Wiederholung *ist* das Maximum — gemessen, nicht
      // geschätzt. Die Formel ergäbe 62 und läge damit 3,3 % über einem
      // tatsächlich bewegten Gewicht. Das ist der einzige Fall, in dem die
      // Schätzung überprüfbar ist, und ausgerechnet dort wäre sie daneben.
      final v = OneRepMax.epley(weight: 60, reps: 1);
      expect(v, isNotNull);
      expect(v!, closeTo(60, 1e-9));
    });

    test('zwei Wiederholungen rechnen schon mit der Formel', () {
      // Die Ausnahme gilt genau für eine Wiederholung, nicht für „wenige".
      // 60 · (1 + 2/30) = 64.
      final v = OneRepMax.epley(weight: 60, reps: 2);
      expect(v, isNotNull);
      expect(v!, closeTo(64, 1e-9));
    });

    test('bei Unterstützung gibt es keine Schätzung', () {
      // Das Gewicht ist negativ; was tatsächlich gehoben wird, hinge vom
      // Körpergewicht ab. Eine Schätzung darauf wäre eine Schätzung auf
      // einer Schätzung. Lieber nichts sagen als raten.
      expect(OneRepMax.epley(weight: -27, reps: 10), isNull);
      expect(OneRepMax.epley(weight: -27, reps: 1), isNull);
    });

    test('null Wiederholungen oder null Gewicht ergeben nichts', () {
      expect(OneRepMax.epley(weight: 50, reps: 0), isNull);
      expect(OneRepMax.epley(weight: 0, reps: 10), isNull);
      expect(OneRepMax.epley(weight: 0, reps: 0), isNull);
    });

    test('negative Wiederholungen ergeben nichts', () {
      expect(OneRepMax.epley(weight: 50, reps: -3), isNull);
    });

    test('ein sehr leichtes Gewicht wird geschätzt, nicht verworfen', () {
      // Die Grenze liegt bei null, nicht bei „nennenswert".
      final v = OneRepMax.epley(weight: 0.5, reps: 10);
      expect(v, isNotNull);
      expect(v!, closeTo(0.7, 1e-9));
    });
  });

  group('Der beste Satz einer Sitzung', () {
    test(
      'ist der mit dem höchsten geschätzten Maximum, nicht der schwerste',
      () {
        // 50 · (1 + 10/30) = 66,7 schlägt 55 · (1 + 6/30) = 66,0 — obwohl
        // 55 kg mehr Gewicht sind.
        final sitzung = const [
          CompletedSet(weight: 50, reps: 10),
          CompletedSet(weight: 55, reps: 6),
        ];
        final v = OneRepMax.best(sitzung);
        expect(v, isNotNull);
        expect(v!, closeTo(66.7, 0.05));
      },
    );

    test('überspringt Sätze ohne Schätzung', () {
      // Der leere Satz und der unterstützte tragen nichts bei, die Sitzung
      // hat trotzdem ein Ergebnis.
      final sitzung = const [
        CompletedSet(weight: 52.5, reps: 0),
        CompletedSet(weight: -27, reps: 8),
        CompletedSet(weight: 60, reps: 1),
      ];
      final v = OneRepMax.best(sitzung);
      expect(v, isNotNull);
      expect(v!, closeTo(60, 1e-9));
    });

    test('ist nichts, wenn kein Satz schätzbar ist', () {
      expect(OneRepMax.best(const []), isNull);
      expect(
        OneRepMax.best(const [
          CompletedSet(weight: -27, reps: 10),
          CompletedSet(weight: -24.5, reps: 8),
        ]),
        isNull,
      );
      expect(
        OneRepMax.best(const [CompletedSet(weight: 52.5, reps: 0)]),
        isNull,
      );
    });
  });

  group('Plateau', () {
    // Sätze mit genau einer Wiederholung ergeben das Gewicht selbst. So
    // steht in jeder Sitzung die Zahl, über die der Vergleich läuft, ohne
    // Umweg über die Formel.
    List<CompletedSet> sitzungMit(double maximum) => [
      CompletedSet(weight: maximum, reps: 1),
    ];

    test('vier Trainings ohne Anstieg sind ein Plateau', () {
      final flach = [
        const [CompletedSet(weight: 50, reps: 10)],
        const [CompletedSet(weight: 50, reps: 10)],
        const [CompletedSet(weight: 50, reps: 10)],
        const [CompletedSet(weight: 50, reps: 10)],
      ];
      expect(OneRepMax.isPlateau(flach), isTrue);
    });

    test('mit Anstieg ist es kein Plateau', () {
      final steigend = [
        const [CompletedSet(weight: 55, reps: 10)],
        const [CompletedSet(weight: 52.5, reps: 10)],
        const [CompletedSet(weight: 50, reps: 10)],
        const [CompletedSet(weight: 50, reps: 9)],
      ];
      expect(OneRepMax.isPlateau(steigend), isFalse);
    });

    test('ein Rückgang ist auch ein Plateau', () {
      // Verglichen wird „neueste gegen älteste"; wer schlechter wird, steigt
      // erst recht nicht.
      final fallend = [
        sitzungMit(95),
        sitzungMit(98),
        sitzungMit(99),
        sitzungMit(100),
      ];
      expect(OneRepMax.isPlateau(fallend), isTrue);
    });

    test('ein Prozent Anstieg zählt noch als Plateau', () {
      // Ein Prozent Luft, damit Messrauschen kein Plateau verhindert:
      // 101 liegt genau auf 100 · 1,01 und gilt noch als Stillstand.
      final knappDarunter = [
        sitzungMit(101),
        sitzungMit(100),
        sitzungMit(100),
        sitzungMit(100),
      ];
      expect(OneRepMax.isPlateau(knappDarunter), isTrue);
    });

    test('mehr als ein Prozent Anstieg ist kein Plateau', () {
      // 101,5 liegt über 100 · 1,01 — das ist echter Fortschritt.
      final knappDarueber = [
        sitzungMit(101.5),
        sitzungMit(100),
        sitzungMit(100),
        sitzungMit(100),
      ];
      expect(OneRepMax.isPlateau(knappDarueber), isFalse);
    });

    test('verglichen wird die neueste mit der viertletzten Sitzung', () {
      // Dazwischen darf es auf und ab gehen; entscheidend sind die Enden
      // des Fensters.
      final zackig = [
        sitzungMit(100),
        sitzungMit(120),
        sitzungMit(80),
        sitzungMit(100),
      ];
      expect(OneRepMax.isPlateau(zackig), isTrue);
    });

    test('unter vier Trainings wird kein Plateau gemeldet', () {
      expect(OneRepMax.isPlateau(const []), isFalse);
      expect(OneRepMax.isPlateau([sitzungMit(50)]), isFalse);
      expect(OneRepMax.isPlateau([sitzungMit(50), sitzungMit(50)]), isFalse);
      expect(
        OneRepMax.isPlateau([sitzungMit(50), sitzungMit(50), sitzungMit(50)]),
        isFalse,
      );
    });

    test('ab vier Trainings zählen nur die vier neuesten', () {
      // Die fünfte Sitzung liegt weit darunter und würde das Fenster
      // kippen, wenn sie mitzählte.
      final fuenf = [
        sitzungMit(100),
        sitzungMit(100),
        sitzungMit(100),
        sitzungMit(100),
        sitzungMit(50),
      ];
      expect(OneRepMax.isPlateau(fuenf), isTrue);
    });

    test('eine Sitzung ohne Schätzung im Fenster meldet kein Plateau', () {
      // Vier Trainings, aber nur drei Zahlen — dann ist der Vergleich nicht
      // zu führen, und „kein Plateau" ist die ehrlichere Antwort als ein
      // auf drei Werten errechnetes Ja.
      final mitLuecke = [
        sitzungMit(100),
        const <CompletedSet>[],
        sitzungMit(100),
        sitzungMit(100),
      ];
      expect(OneRepMax.isPlateau(mitLuecke), isFalse);
    });

    test('eine Sitzung aus lauter unterstützten Sätzen bricht das Fenster', () {
      final nurUnterstuetzt = [
        sitzungMit(100),
        const [CompletedSet(weight: -27, reps: 10)],
        sitzungMit(100),
        sitzungMit(100),
      ];
      expect(OneRepMax.isPlateau(nurUnterstuetzt), isFalse);
    });
  });
}
