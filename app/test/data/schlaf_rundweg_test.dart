import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/data/cache_repository.dart';
import 'package:repit/health/health_types.dart';

/// Tests für den **Rundweg der Nickerchen** durch den Schlaf-Cache —
/// Nachtrag zu `test/data/schlaf_cache_test.dart` (#113) nach einem
/// Review-Befund vom 27.10.2026 (Befund F).
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden.
///
/// ## Der Befund
///
/// `CacheRepository._alsZeilen` erzeugt für eine `SleepSession` **ohne**
/// Abschnitte keine einzige Zeile; `liesNaechte` rekonstruiert die
/// Nickerchen aber aus `quellen.keys`, also aus den tatsächlich
/// vorhandenen Zeilen. Eine Quelle ohne Zeilen hat keinen Schlüssel — das
/// Nickerchen fehlt beim Lesen, und alle folgenden rücken eine Stelle vor:
///
/// ```dart
/// naps: [SleepSession(segments: []), SleepSession(segments: [x])]
/// // kommt zurück als
/// naps: [SleepSession(segments: [x])]
/// ```
///
/// Das ist ein entarteter Fall — ein Nickerchen ohne jeden Abschnitt ist
/// kein Schlaf. Es ist aber ein Fall, den der Kanal bauen **kann**:
/// `SleepNight.ausMap` legt für jeden Eintrag unter `naps` eine
/// `SleepSession` an, auch wenn dessen `segments` leer oder nicht
/// vorhanden ist. Und die Zusage des Caches ist, dass herauskommt, was
/// hineinging. Ein Rundweg, der in einem Fall etwas anderes zurückgibt,
/// ist kein Rundweg, sondern einer mit einer Ausnahme, die niemand
/// aufgeschrieben hat.
///
/// ## Was diese Tests verbindlich vorgeben
///
/// **Keine Signaturänderung.** Verlangt wird nur, dass `schreibeNaechte`
/// und `liesNaechte` zusammen die Zahl und die Reihenfolge der Nickerchen
/// erhalten. Wie — eine Zeile je Quelle auch ohne Abschnitte, eine Spalte
/// mit der Zahl der Nickerchen auf `naechte`, oder ein anderer Weg —
/// entscheidet die Umsetzung. Käme dabei eine Schemaänderung heraus,
/// gehört laut `CLAUDE.md` eine neue Version **und** ein Migrationstest
/// dazu.
///
/// **Die leere Hauptnacht ist nicht betroffen:** Sie hat die feste Quelle 0
/// und wird beim Lesen mit `quellen[0] ?? const []` immer gebaut. Der Test
/// unten hält das als Nebenbedingung fest, damit eine Lösung des
/// Nickerchen-Falls sie nicht mit kaputtmacht.
///
/// **Alle Zeiten und Zahlen hier sind erfunden.**
void main() {
  final tag = BerlinCalendar.startOfDay(DateTime.utc(2026, 10, 20, 12));
  final gelesenAm = DateTime.utc(2026, 10, 20, 14, 32);

  SleepSession nickerchen(int stunde) => SleepSession(
    segments: [
      SleepSegment(
        stage: SleepStage.core,
        start: DateTime.utc(2026, 10, 20, stunde),
        end: DateTime.utc(2026, 10, 20, stunde, 30),
      ),
    ],
  );

  final hauptnacht = SleepSession(
    segments: [
      SleepSegment(
        stage: SleepStage.core,
        start: DateTime.utc(2026, 10, 19, 21),
        end: DateTime.utc(2026, 10, 20, 4, 30),
      ),
    ],
  );

  Future<SleepNight> rundweg(SleepNight hinein) async {
    final db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = CacheRepository(db);
    await repo.schreibeNaechte([hinein], gelesenAm: gelesenAm);
    return (await repo.liesNaechte(DataWindow.unlimited))!.werte.single;
  }

  group('Was hineinging, kommt heraus — auch leere Nickerchen', () {
    test(
      'ein leeres Nickerchen vor einem vollen geht nicht verloren, und das '
      'volle rutscht nicht an seine Stelle',
      () async {
        final zurueck = await rundweg(
          SleepNight(
            date: tag,
            session: hauptnacht,
            naps: [SleepSession(segments: const []), nickerchen(13)],
          ),
        );

        expect(
          zurueck.naps,
          hasLength(2),
          reason:
              'zwei Nickerchen hinein, zwei heraus. Eines zu verlieren '
              'heißt, dass die zweite Sitzung danach die erste ist — und '
              'jede Zählung darüber ist um eins daneben',
        );
        expect(zurueck.naps.first.segments, isEmpty);
        expect(
          zurueck.naps.last.segments.single.start,
          DateTime.utc(2026, 10, 20, 13),
          reason: 'die Reihenfolge bleibt, wie sie hereinkam',
        );
      },
    );

    test('ein leeres Nickerchen hinter einem vollen ebenso', () async {
      final zurueck = await rundweg(
        SleepNight(
          date: tag,
          session: hauptnacht,
          naps: [nickerchen(13), SleepSession(segments: const [])],
        ),
      );

      expect(zurueck.naps, hasLength(2));
      expect(
        zurueck.naps.first.segments.single.start,
        DateTime.utc(2026, 10, 20, 13),
      );
      expect(zurueck.naps.last.segments, isEmpty);
    });

    test('ein einzelnes leeres Nickerchen bleibt ein Nickerchen', () async {
      final zurueck = await rundweg(
        SleepNight(
          date: tag,
          session: hauptnacht,
          naps: [SleepSession(segments: const [])],
        ),
      );

      expect(zurueck.naps, hasLength(1));
      expect(zurueck.naps.single.segments, isEmpty);
    });

    test(
      'gar keine Nickerchen bleiben gar keine — kein erfundener Eintrag',
      () async {
        final zurueck = await rundweg(
          SleepNight(date: tag, session: hauptnacht),
        );

        expect(zurueck.naps, isEmpty);
      },
    );

    test(
      'eine leere Hauptnacht kommt weiterhin leer zurück (Nebenbedingung)',
      () async {
        final zurueck = await rundweg(
          SleepNight(
            date: tag,
            session: SleepSession(segments: const []),
            naps: [nickerchen(13)],
          ),
        );

        expect(zurueck.session.segments, isEmpty);
        expect(zurueck.naps, hasLength(1));
      },
    );

    test(
      'ein erneuter Lauf ersetzt die Nickerchen, statt sie zu mischen',
      () async {
        final db = AppCache(NativeDatabase.memory());
        addTearDown(db.close);
        final repo = CacheRepository(db);

        await repo.schreibeNaechte([
          SleepNight(
            date: tag,
            session: hauptnacht,
            naps: [nickerchen(13), nickerchen(16)],
          ),
        ], gelesenAm: gelesenAm);
        await repo.schreibeNaechte([
          SleepNight(
            date: tag,
            session: hauptnacht,
            naps: [SleepSession(segments: const [])],
          ),
        ], gelesenAm: gelesenAm);

        final zurueck =
            (await repo.liesNaechte(DataWindow.unlimited))!.werte.single;

        expect(
          zurueck.naps,
          hasLength(1),
          reason:
              'blieben die alten Zeilen stehen, läse der Schirm eine Nacht, '
              'die es nie gab — zusammengesetzt aus zwei Läufen',
        );
        expect(zurueck.naps.single.segments, isEmpty);
      },
    );
  });
}
