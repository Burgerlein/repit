import 'package:flutter_test/flutter_test.dart';
// Gemeint sind die Kanal-Typen aus health_types.dart — der Kern hat seit #95
// eigene, schlanke Workout-Typen (zone_distribution.dart), deren Namen sonst
// mehrdeutig wären. Reine Entwirrung, keine Erwartung geändert.
import 'package:trainings_core/trainings_core.dart'
    hide WorkoutKind, WorkoutSample;

import 'package:repit/health/health_types.dart';
import 'package:repit/tag/tagesgrenze_eingaben.dart';

/// Tests für die **Eingaben der Tagesgrenze aus Health** (#454 unter #375)
/// — die reinen Funktionen `nachtAus`, `belegeAusSchritten` und
/// `belegeAusTrainings` in `lib/tag/tagesgrenze_eingaben.dart`.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden. Hält der
/// Implementierende einen Fall für falsch, meldet er ihn.
///
/// ## Woher die Anforderung kommt
///
/// Spec `docs/superpowers/specs/2026-11-10-tagesgrenze-design.md`,
/// Abschnitt „Eingaben aus Health“, dazu (vom Planenden formuliert, laut
/// Spec von Tim am 10.11.2026 übernommen):
///
/// - **V1:** Schritte zählen als Wachbeleg ab 100 in der Stunde
///   (`wachSchritteJeStunde`). Beleg ist der **Beginn** der Stunde
///   (`QuantitySample.date`), Quelle `schritte`.
/// - **V2:** Ein Training ist eine Spanne von `WorkoutSample.start` bis
///   `start + minutes`, Quelle `training`.
/// - **V4:** Die Nacht ist die Hauptnacht (`SleepNight.session`, ohne
///   Nickerchen). Beginn = Beginn des ersten Abschnitts, der nicht `awake`
///   ist; Ende = Ende des letzten solchen; Schlaf = Summe ihrer Dauern.
///   `null`, wenn die Nacht keinen Schlafabschnitt hat.
///
/// Pflichtfälle aus dem Plan `docs/superpowers/plans/2026-11-10-tagesgrenze.md`,
/// Task 4: wach–core–deep–wach–rem; nur `awake` → `null`; `unspecified`
/// zählt als Schlaf; 99 → kein Beleg, 100 → Beleg am Stundenbeginn;
/// Training von `start` bis `start + minutes`.
///
/// ## Festlegungen des Test-Agenten — nicht von Tim freigegeben
///
/// - **Die Reihenfolge der Belege folgt der Eingabe.** Die Eingaben hier
///   sind zeitlich sortiert, wie Health sie liefert; die Kern-Rechnungen
///   sortieren ohnehin selbst. Verglichen wird deshalb als Liste.
/// - **Ein wacher Abschnitt mitten in der Nacht** zählt nicht zum Schlaf,
///   verschiebt aber weder Beginn noch Ende (das folgt aus V4, ist dort
///   aber nicht als Fall genannt).
/// - **`minutes` mit Nachkommastellen** wird sekundengenau übernommen
///   (42,5 min → 42 min 30 s).
///
/// **Alle Zeitpunkte hier sind erfunden und liegen im Jahr 2099**, in UTC.
/// Diese Funktionen rechnen keine Wanduhr, deshalb genügen UTC-Zeitpunkte.
void main() {
  DateTime t(int tag, int stunde, [int minute = 0]) =>
      DateTime.utc(2099, 1, tag, stunde, minute);

  SleepSegment abschnitt(SleepStage stage, DateTime start, DateTime end) =>
      SleepSegment(stage: stage, start: start, end: end);

  SleepNight nacht(List<SleepSegment> abschnitte, {List<SleepSession>? naps}) =>
      SleepNight(
        date: t(13, 0),
        session: SleepSession(segments: abschnitte),
        naps: naps ?? const [],
      );

  group('nachtAus (V4)', () {
    test('wach–core–deep–wach–rem: Beginn von core, Ende von rem, '
        'Schlaf = core + deep + rem', () {
      final n = nacht([
        abschnitt(SleepStage.awake, t(12, 22, 30), t(12, 23, 10)),
        abschnitt(SleepStage.core, t(12, 23, 10), t(13, 1, 0)), // 110 min
        abschnitt(SleepStage.deep, t(13, 1, 0), t(13, 2, 15)), // 75 min
        abschnitt(SleepStage.awake, t(13, 2, 15), t(13, 2, 40)),
        abschnitt(SleepStage.rem, t(13, 2, 40), t(13, 4, 0)), // 80 min
      ]);

      expect(
        nachtAus(n),
        GemeldeteNacht(
          beginn: t(12, 23, 10),
          ende: t(13, 4, 0),
          schlaf: const Duration(minutes: 110 + 75 + 80),
        ),
      );
    });

    test('ein Wachabschnitt am Ende verschiebt das Ende nicht', () {
      final n = nacht([
        abschnitt(SleepStage.core, t(13, 0, 30), t(13, 6, 0)),
        abschnitt(SleepStage.awake, t(13, 6, 0), t(13, 6, 45)),
      ]);

      expect(
        nachtAus(n),
        GemeldeteNacht(
          beginn: t(13, 0, 30),
          ende: t(13, 6, 0),
          schlaf: const Duration(hours: 5, minutes: 30),
        ),
      );
    });

    test('nur awake → null', () {
      final n = nacht([
        abschnitt(SleepStage.awake, t(12, 23, 0), t(13, 0, 0)),
        abschnitt(SleepStage.awake, t(13, 1, 0), t(13, 1, 30)),
      ]);

      expect(nachtAus(n), isNull);
    });

    test('ohne Abschnitte → null', () {
      expect(nachtAus(nacht(const [])), isNull);
    });

    test('unspecified zählt als Schlaf', () {
      final n = nacht([
        abschnitt(SleepStage.awake, t(12, 23, 0), t(12, 23, 20)),
        abschnitt(SleepStage.unspecified, t(12, 23, 20), t(13, 3, 20)),
      ]);

      expect(
        nachtAus(n),
        GemeldeteNacht(
          beginn: t(12, 23, 20),
          ende: t(13, 3, 20),
          schlaf: const Duration(hours: 4),
        ),
      );
    });

    test('nur unspecified ist eine Nacht', () {
      final n = nacht([
        abschnitt(SleepStage.unspecified, t(13, 0, 47), t(13, 7, 0)),
      ]);

      expect(
        nachtAus(n),
        GemeldeteNacht(
          beginn: t(13, 0, 47),
          ende: t(13, 7, 0),
          schlaf: const Duration(hours: 6, minutes: 13),
        ),
      );
    });

    test('Nickerchen zählen nicht: weder Beginn, Ende noch Schlaf', () {
      final n = nacht(
        [abschnitt(SleepStage.core, t(13, 0, 0), t(13, 6, 0))],
        naps: [
          SleepSession(
            segments: [abschnitt(SleepStage.core, t(12, 18, 30), t(12, 21, 45))],
          ),
          SleepSession(
            segments: [abschnitt(SleepStage.core, t(13, 14, 0), t(13, 14, 40))],
          ),
        ],
      );

      expect(
        nachtAus(n),
        GemeldeteNacht(
          beginn: t(13, 0, 0),
          ende: t(13, 6, 0),
          schlaf: const Duration(hours: 6),
        ),
      );
    });

    test('nur Nickerchen, keine Hauptnacht → null', () {
      final n = nacht(
        const [],
        naps: [
          SleepSession(
            segments: [abschnitt(SleepStage.core, t(12, 18, 30), t(12, 21, 45))],
          ),
        ],
      );

      expect(nachtAus(n), isNull);
    });
  });

  group('belegeAusSchritten (V1)', () {
    test('99 in der Stunde → kein Beleg', () {
      expect(
        belegeAusSchritten([QuantitySample(date: t(13, 2), value: 99)]),
        isEmpty,
      );
    });

    test('knapp unter 100 → kein Beleg', () {
      expect(
        belegeAusSchritten([QuantitySample(date: t(13, 2), value: 99.9)]),
        isEmpty,
      );
    });

    test('100 in der Stunde → ein Beleg am Stundenbeginn, Quelle schritte',
        () {
      expect(belegeAusSchritten([QuantitySample(date: t(13, 5), value: 100)]), [
        Wachbeleg(von: t(13, 5), quelle: WachQuelle.schritte),
      ]);
    });

    test('der Beleg ist ein Zeitpunkt, keine Spanne über die Stunde', () {
      final beleg = belegeAusSchritten([
        QuantitySample(date: t(13, 5), value: 2400),
      ]).single;

      expect(beleg.von, t(13, 5));
      expect(beleg.bis, t(13, 5));
    });

    test('gemischt: nur die Stunden ab 100', () {
      expect(
        belegeAusSchritten([
          QuantitySample(date: t(13, 1), value: 12),
          QuantitySample(date: t(13, 2), value: 100),
          QuantitySample(date: t(13, 3), value: 99),
          QuantitySample(date: t(13, 4), value: 850),
        ]),
        [
          Wachbeleg(von: t(13, 2), quelle: WachQuelle.schritte),
          Wachbeleg(von: t(13, 4), quelle: WachQuelle.schritte),
        ],
      );
    });

    test('keine Proben → keine Belege', () {
      expect(belegeAusSchritten(const []), isEmpty);
    });
  });

  group('belegeAusTrainings (V2)', () {
    WorkoutSample training(String id, DateTime start, double minuten) =>
        WorkoutSample(
          id: id,
          start: start,
          kind: WorkoutKind.walking,
          minutes: minuten,
        );

    test('Beginn ist start, Ende start + minutes, Quelle training', () {
      expect(belegeAusTrainings([training('a', t(13, 5, 10), 45)]), [
        Wachbeleg(
          von: t(13, 5, 10),
          bis: t(13, 5, 55),
          quelle: WachQuelle.training,
        ),
      ]);
    });

    test('Minuten mit Nachkommastellen werden sekundengenau übernommen', () {
      final beleg = belegeAusTrainings([
        training('a', t(12, 23, 0), 42.5),
      ]).single;

      expect(
        beleg.bis,
        t(12, 23, 0).add(const Duration(minutes: 42, seconds: 30)),
      );
    });

    test('jedes Training wird ein Beleg', () {
      expect(
        belegeAusTrainings([
          training('a', t(12, 18, 0), 60),
          training('b', t(13, 6, 0), 30),
        ]),
        [
          Wachbeleg(von: t(12, 18), bis: t(12, 19), quelle: WachQuelle.training),
          Wachbeleg(
            von: t(13, 6),
            bis: t(13, 6, 30),
            quelle: WachQuelle.training,
          ),
        ],
      );
    });

    test('keine Trainings → keine Belege', () {
      expect(belegeAusTrainings(const []), isEmpty);
    });
  });
}
