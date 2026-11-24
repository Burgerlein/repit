import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/design/segment_ring.dart';
import 'package:repit/shell/schlaf_zustand.dart';

/// Tests für die **entfallende Teilnote Unterbrechungen** in der
/// Schirm-Schicht (#131, Zug 2) — `schlafTeilnoten` und
/// `schlafRingAbschnitte` in `lib/shell/schlaf_score.dart`.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, nie verändert werden.
///
/// ## Was hier dazukommt
///
/// `SchlafTeilnote` **konnte** „entfällt" schon ausdrücken — der Dateikopf
/// von `schlaf_zustand.dart` sagt es wörtlich: „[SchlafTeilnote] kann
/// ‚Unterbrechungen entfällt' ausdrücken; erzeugt wird der Fall nirgends."
/// Mit #131 wird er erzeugt, und dafür braucht es genau zwei Dinge:
///
/// 1. `schlafTeilnoten` reicht `score.interruptions == null` durch, statt
///    die Teilnote immer als gemessen auszugeben.
/// 2. `SchlafEntfallGrund` bekommt einen **zweiten** Wert. Bis heute stand
///    dort einer, und `schlaf_zustand_test.dart` hielt das mit
///    `expect(SchlafEntfallGrund.values, hasLength(1))` fest — die Aussage
///    war „es gibt genau einen Grund", und sie stimmt ab jetzt nicht mehr.
///    Der zweite Grund gehört in das Enum und nicht in einen Satz in der
///    View, aus demselben Grund wie der erste: Wer die Teilnote zeichnet,
///    soll den Grund aus dem Zustand lesen können.
///
/// **Der Ring normiert weiterhin nicht hoch.** Entfallen zwei Teilnoten,
/// bleiben beide Abschnitte stehen und werden als ohne Grundlage
/// gezeichnet. Auf 50/50 aufgeblasen verschwände die Aussage „ein Teil ist
/// nicht gemessen" — und eine von Hand eingetragene Nacht sähe aus wie eine
/// vollständig gemessene.
///
/// ## API, die diese Tests verbindlich vorgeben
///
/// ```dart
/// enum SchlafEntfallGrund { keineEinschlafzeit, keinePhasendaten }
/// ```
void main() {
  group('Die Teilnote Unterbrechungen kann entfallen (#131)', () {
    const vonHand = SleepScore(duration: 44, bedtime: 27, interruptions: null);

    test('punkte ist null, nicht 0 — und die Füllung damit 0', () {
      final unterbrechungen = schlafTeilnoten(vonHand)[2];

      expect(unterbrechungen.teil, SchlafTeil.unterbrechungen);
      expect(unterbrechungen.entfaellt, isTrue);
      expect(unterbrechungen.punkte, isNull);
      expect(unterbrechungen.fuellung, 0);
      expect(unterbrechungen.maximum, SleepScore.maxInterruptions);
    });

    test('und sie trägt ihren eigenen Grund, nicht den der Zubettgehzeit', () {
      final teile = schlafTeilnoten(vonHand);

      expect(teile[2].grund, SchlafEntfallGrund.keinePhasendaten);
      expect(teile[1].grund, isNull);
      expect(teile[0].grund, isNull);
    });

    test('es gibt jetzt genau zwei Gründe — ein dritter müsste hier auftauchen '
        'und nicht in einem Satz in der View', () {
      expect(SchlafEntfallGrund.values, hasLength(2));
      expect(SchlafEntfallGrund.values, [
        SchlafEntfallGrund.keineEinschlafzeit,
        SchlafEntfallGrund.keinePhasendaten,
      ]);
    });

    test('beide Gründe zugleich: nur die Dauer bleibt stehen', () {
      const nurDauer = SleepScore(
        duration: 44,
        bedtime: null,
        interruptions: null,
      );

      final teile = schlafTeilnoten(nurDauer);

      expect(teile[0].entfaellt, isFalse);
      expect(teile[1].grund, SchlafEntfallGrund.keineEinschlafzeit);
      expect(teile[2].grund, SchlafEntfallGrund.keinePhasendaten);
    });

    test('eine gemessene Nacht trägt weiter keinen Grund', () {
      const gemessen = SleepScore(duration: 44, bedtime: 27, interruptions: 10);

      for (final teil in schlafTeilnoten(gemessen)) {
        expect(teil.entfaellt, isFalse, reason: '${teil.teil}');
        expect(teil.grund, isNull, reason: '${teil.teil}');
      }
    });

    test('null Punkte sind weiterhin etwas anderes als „entfällt"', () {
      const null20 = SleepScore(duration: 44, bedtime: 27, interruptions: 0);

      final unterbrechungen = schlafTeilnoten(null20)[2];

      expect(unterbrechungen.entfaellt, isFalse);
      expect(unterbrechungen.punkte, 0);
      expect(unterbrechungen.grund, isNull);
    });
  });

  group('Der Ring normiert auch dann nicht hoch', () {
    test('der 20-%-Abschnitt bleibt stehen und wird als ohne Grundlage '
        'gezeichnet', () {
      final List<RingAbschnitt> ring = schlafRingAbschnitte(
        schlafTeilnoten(
          const SleepScore(duration: 44, bedtime: 27, interruptions: null),
        ),
      );

      expect(ring, hasLength(3));
      expect(ring[2].anteil, closeTo(0.2, 1e-9));
      expect(ring[2].hatGrundlage, isFalse);
      expect(ring[2].fuellung, 0);
      // Die beiden gemessenen behalten ihre Anteile — nichts wird
      // umverteilt.
      expect(ring[0].anteil, closeTo(0.5, 1e-9));
      expect(ring[1].anteil, closeTo(0.3, 1e-9));
      expect(ring[0].hatGrundlage, isTrue);
      expect(ring[1].hatGrundlage, isTrue);
    });

    test('und bei zwei entfallenen Teilnoten bleiben beide stehen', () {
      final ring = schlafRingAbschnitte(
        schlafTeilnoten(
          const SleepScore(duration: 44, bedtime: null, interruptions: null),
        ),
      );

      expect(ring.map((a) => a.hatGrundlage), [true, false, false]);
      expect(
        ring.map((a) => a.anteil).reduce((a, b) => a + b),
        closeTo(1.0, 1e-9),
      );
    });
  });
}
