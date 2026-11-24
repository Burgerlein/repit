import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für `ExerciseProgress` — den Verlauf **einer Übung** über die
/// Trainings, aus dem der Schirm „Fortschritt pro Übung" (#93) seine beiden
/// Linien zeichnet: Höchstgewicht und geschätztes 1RM.
///
/// Grundlage ist `docs/superpowers/specs/2026-11-11-gym-fortschritt-design.md`,
/// Abschnitt 4, dazu `docs/SPEC.md` 4.4 (Epley, Unterstützung negativ,
/// Zeitübungen in Sekunden).
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, nie verändert werden. Hält der
/// Implementierende eine Erwartung für falsch, wird das gemeldet, nicht
/// korrigiert.
///
/// ## API, die diese Tests verbindlich vorgeben
///
/// Neue Datei `lib/src/exercise_progress.dart`, dazu die Export-Zeile in
/// `lib/trainings_core.dart` — diese Datei importiert das Barrel.
///
/// ```dart
/// /// Ein Training, in dem die Übung vorkam: wann, und welche Sätze.
/// /// Werttyp mit == und hashCode (`CLAUDE.md`, Fehler 03).
/// final class ExerciseSession {
///   const ExerciseSession({required DateTime date, required List<CompletedSet> sets});
///   final DateTime date;           // UTC-Zeitpunkt der Sitzung
///   final List<CompletedSet> sets; // in Satzreihenfolge
/// }
///
/// /// Ein Punkt der Verlaufslinien: ein Berliner Tag, an dem trainiert wurde.
/// /// Werttyp mit == und hashCode.
/// final class ProgressPoint {
///   const ProgressPoint({required DateTime day, required double top, double? oneRepMax});
///   final DateTime day;        // Berliner Tagesbeginn (BerlinCalendar.startOfDay)
///   final double top;          // Höchstgewicht in kg — bei Zeitübungen die längste Zeit in s
///   final double? oneRepMax;   // geschätztes 1RM; null, wo keines zu schätzen ist
/// }
///
/// abstract final class ExerciseProgress {
///   /// Aufsteigend nach Tag, höchstens ein Punkt je Berliner Tag.
///   static List<ProgressPoint> points({
///     required Exercise exercise,
///     required List<ExerciseSession> sessions,
///   });
/// }
/// ```
///
/// ## Die Regeln, die hier geprüft werden
///
/// - **Höchstgewicht ist das Maximum der Sätze**, nie ein Mittel. Bei
///   Unterstützung (negativ) ist das der Wert, der **näher an null** liegt —
///   weniger Hilfe ist schwerer.
/// - **Das 1RM ist `OneRepMax.best`** — nicht das 1RM des schwersten Satzes:
///   50 kg × 10 schätzen höher als 55 kg × 6.
/// - **Sätze ohne positive Wiederholungszahl zählen nicht**, wie in
///   `Progression.suggest`.
/// - **Ein Tag ohne zählenden Satz ist kein Punkt.**
/// - **Zwei Trainings am selben Berliner Tag sind ein Punkt**, und er trägt
///   von beiden das Maximum — von beiden Werten, nicht gemittelt.
/// - **Unterstützte Sätze haben kein 1RM** (`OneRepMax.epley` gibt `null`):
///   Der Punkt bleibt, sein `oneRepMax` ist `null` — **keine 0**.
/// - **Zeitübungen** (`Exercise.isTimed`) tragen in `top` ihre längste Zeit
///   in Sekunden und kein 1RM. Epley auf Sekunden wäre Unsinn, ein
///   „Höchstgewicht 0 kg" eine Falschauskunft. *(Empfehlung der Spec,
///   offene Frage 4 — noch nicht von Tim bestätigt.)*
/// - **Körpergewicht (`0.0`) ist ein erfasster Wert**, kein fehlender: Der
///   Punkt steht da, `top` ist `0.0`, ein 1RM gibt es nicht.
///
/// Alle Daten sind erfunden. Zeitpunkte sind UTC; 2026-03 liegt vor der
/// Sommerzeit (MEZ, +1).
void main() {
  final bank = ExerciseCatalog.all['benchPress']!;
  final dips = ExerciseCatalog.all['dips']!;
  final seitstuetz = ExerciseCatalog.all['sidePlank']!;

  CompletedSet satz(double gewicht, int wdh) =>
      CompletedSet(weight: gewicht, reps: wdh);

  ExerciseSession training(DateTime datum, List<CompletedSet> saetze) =>
      ExerciseSession(date: datum, sets: saetze);

  // 10:00 Berliner Zeit.
  DateTime morgens(int monat, int tag) => DateTime.utc(2026, monat, tag, 9);

  List<ProgressPoint> punkte(
    Exercise uebung,
    List<ExerciseSession> trainings,
  ) => ExerciseProgress.points(exercise: uebung, sessions: trainings);

  group('Ein Training, ein Punkt', () {
    test('ohne Trainings gibt es keine Punkte', () {
      expect(punkte(bank, const []), isEmpty);
    });

    test('das Höchstgewicht ist das schwerste Gewicht, das 1RM das beste '
        'der Schätzungen', () {
      final ergebnis = punkte(bank, [
        training(morgens(3, 2), [satz(60, 10), satz(62.5, 8), satz(65, 5)]),
      ]);

      expect(ergebnis, hasLength(1));
      expect(ergebnis.single.top, 65.0);
      expect(
        ergebnis.single.oneRepMax,
        80.0,
        reason:
            '60 × 10 schätzt auf 80,0; 65 × 5 nur auf 75,8. Das 1RM ist '
            'das beste aller Sätze, nicht das des schwersten',
      );
    });

    test('der Punkt liegt auf dem Berliner Tagesbeginn', () {
      final ergebnis = punkte(bank, [
        training(morgens(3, 2), [satz(60, 10)]),
      ]);
      expect(ergebnis.single.day, BerlinCalendar.startOfDay(morgens(3, 2)));
    });

    test('mit einem einzigen Satz ist Höchstgewicht und 1RM trotzdem da', () {
      final ergebnis = punkte(bank, [
        training(morgens(3, 2), [satz(70, 6)]),
      ]);
      expect(ergebnis.single.top, 70.0);
      expect(ergebnis.single.oneRepMax, 84.0);
    });

    test('das Höchstgewicht ist ein Maximum — kein Mittel', () {
      final ergebnis = punkte(bank, [
        training(morgens(3, 2), [satz(60, 10), satz(70, 6)]),
      ]);
      expect(
        ergebnis.single.top,
        70.0,
        reason: '65 lag nie auf der Stange (`docs/SPEC.md` 4.4)',
      );
    });
  });

  group('Was als Satz zählt', () {
    test('ein Satz ohne positive Wiederholungen zählt nicht', () {
      final ergebnis = punkte(bank, [
        training(morgens(3, 2), [satz(100, 0), satz(60, 10)]),
      ]);
      expect(
        ergebnis.single.top,
        60.0,
        reason:
            '100 × 0 wurde nie gehoben — dieselbe Regel wie bei '
            '`Progression.suggest`',
      );
      expect(ergebnis.single.oneRepMax, 80.0);
    });

    test('ein Training, in dem nichts zählt, ist kein Punkt', () {
      final ergebnis = punkte(bank, [
        training(morgens(3, 2), [satz(60, 0)]),
        training(morgens(3, 9), [satz(60, 10)]),
      ]);
      expect(ergebnis.map((p) => p.day), [
        BerlinCalendar.startOfDay(morgens(3, 9)),
      ]);
    });

    test('ein Training ohne Sätze ist kein Punkt', () {
      expect(punkte(bank, [training(morgens(3, 2), const [])]), isEmpty);
    });
  });

  group('Mehrere Trainings', () {
    test('aufsteigend nach Tag, gleichgültig in welcher Reihenfolge sie '
        'kommen — und die Eingabe bleibt unverändert', () {
      final eingabe = [
        training(morgens(3, 16), [satz(62.5, 10)]),
        training(morgens(3, 2), [satz(57.5, 10)]),
        training(morgens(3, 9), [satz(60, 10)]),
      ];
      final kopie = List<ExerciseSession>.of(eingabe);

      final ergebnis = punkte(bank, eingabe);

      expect(ergebnis.map((p) => p.top), [57.5, 60.0, 62.5]);
      expect(ergebnis.map((p) => p.day).toList(), [
        BerlinCalendar.startOfDay(morgens(3, 2)),
        BerlinCalendar.startOfDay(morgens(3, 9)),
        BerlinCalendar.startOfDay(morgens(3, 16)),
      ]);
      expect(eingabe, kopie);
    });

    test('zwei Trainings am selben Berliner Tag sind ein Punkt mit dem '
        'Maximum beider', () {
      final ergebnis = punkte(bank, [
        training(DateTime.utc(2026, 3, 2, 5), [satz(60, 10)]),
        // 20:00 UTC = 21:00 Berliner Zeit — derselbe Tag.
        training(DateTime.utc(2026, 3, 2, 20), [satz(65, 5)]),
      ]);

      expect(ergebnis, hasLength(1));
      expect(ergebnis.single.top, 65.0);
      expect(
        ergebnis.single.oneRepMax,
        80.0,
        reason:
            'Das Maximum der beiden Schätzungen (80,0 und 75,8), '
            'nicht ihr Mittel',
      );
    });

    test('der Tag ist der Berliner, nicht der UTC-Tag', () {
      final ergebnis = punkte(bank, [
        training(DateTime.utc(2026, 3, 2, 9), [satz(60, 10)]),
        // 23:30 UTC = 00:30 Berliner Zeit des 3. — ein anderer Tag, obwohl
        // der UTC-Kalendertag derselbe ist.
        training(DateTime.utc(2026, 3, 2, 23, 30), [satz(65, 10)]),
      ]);

      expect(ergebnis, hasLength(2));
      expect(ergebnis.map((p) => p.top), [60.0, 65.0]);
    });
  });

  group('Unterstützung', () {
    test('das Höchstgewicht ist der Wert näher an null, ein 1RM gibt es '
        'nicht', () {
      final ergebnis = punkte(dips, [
        training(morgens(3, 2), [satz(-27, 8), satz(-24.5, 6)]),
      ]);

      expect(ergebnis, hasLength(1));
      expect(
        ergebnis.single.top,
        -24.5,
        reason: '−24,5 ist schwerer als −27: weniger Hilfe',
      );
      expect(
        ergebnis.single.oneRepMax,
        isNull,
        reason:
            'Epley gibt für Unterstützung `null` — keine 0 und kein '
            'Wert aus dem Betrag',
      );
    });

    test('die Punkte unterstützter Trainings bleiben in der Reihe', () {
      final ergebnis = punkte(dips, [
        training(morgens(3, 2), [satz(-27, 8)]),
        training(morgens(3, 9), [satz(-24.5, 8)]),
        training(morgens(3, 16), [satz(-22, 8)]),
      ]);
      expect(ergebnis.map((p) => p.top), [-27.0, -24.5, -22.0]);
      expect(ergebnis.every((p) => p.oneRepMax == null), isTrue);
    });

    test('ein Training mit Zusatzgewicht hat ein 1RM, ein unterstütztes '
        'davor nicht — die Lücke bleibt eine Lücke', () {
      final ergebnis = punkte(dips, [
        training(morgens(3, 2), [satz(-10, 8)]),
        training(morgens(3, 9), [satz(5, 8)]),
      ]);

      expect(ergebnis.map((p) => p.top), [-10.0, 5.0]);
      expect(ergebnis[0].oneRepMax, isNull);
      expect(ergebnis[1].oneRepMax, 6.3);
    });

    test('unterstützt und mit Zusatz am selben Tag: das Zusatzgewicht ist '
        'das Maximum', () {
      final ergebnis = punkte(dips, [
        training(morgens(3, 2), [satz(-20, 10), satz(5, 8)]),
      ]);
      expect(ergebnis.single.top, 5.0);
      expect(ergebnis.single.oneRepMax, 6.3);
    });

    test('eigenes Körpergewicht (0) ist ein Wert: Der Punkt steht da, ein '
        '1RM gibt es nicht', () {
      final ergebnis = punkte(dips, [
        training(morgens(3, 2), [satz(0, 10)]),
      ]);
      expect(ergebnis, hasLength(1));
      expect(ergebnis.single.top, 0.0);
      expect(ergebnis.single.oneRepMax, isNull);
    });
  });

  group('Zeitübungen', () {
    test('tragen ihre längste Zeit in Sekunden und kein 1RM', () {
      final ergebnis = punkte(seitstuetz, [
        training(morgens(3, 2), [satz(0, 30), satz(0, 35)]),
        training(morgens(3, 9), [satz(0, 40)]),
      ]);

      expect(ergebnis.map((p) => p.top), [35.0, 40.0]);
      expect(ergebnis.every((p) => p.oneRepMax == null), isTrue);
    });

    test('das Gewichtsfeld geht nicht in die Zeit ein', () {
      final ergebnis = punkte(seitstuetz, [
        training(morgens(3, 2), [satz(10, 30)]),
      ]);
      expect(
        ergebnis.single.top,
        30.0,
        reason:
            'Bei einer Zeitübung steht im Gewichtsfeld nichts '
            'Sinnvolles; gelesen wird die Zeit',
      );
    });
  });

  group('Werttypen', () {
    test('ExerciseSession vergleicht Inhalt, nicht Identität', () {
      final eine = ExerciseSession(
        date: morgens(3, 2),
        sets: [satz(60, 10), satz(62.5, 8)],
      );
      final gleiche = ExerciseSession(
        date: morgens(3, 2),
        sets: [satz(60, 10), satz(62.5, 8)],
      );
      expect(eine, gleiche);
      expect(eine.hashCode, gleiche.hashCode);
    });

    test('ExerciseSession: andere Sätze, anderer Tag, andere Reihenfolge '
        'sind ungleich', () {
      final eine = ExerciseSession(
        date: morgens(3, 2),
        sets: [satz(60, 10), satz(62.5, 8)],
      );
      expect(
        eine,
        isNot(ExerciseSession(date: morgens(3, 3), sets: eine.sets)),
      );
      expect(
        eine,
        isNot(
          ExerciseSession(
            date: morgens(3, 2),
            sets: [satz(62.5, 8), satz(60, 10)],
          ),
        ),
      );
      expect(
        eine,
        isNot(ExerciseSession(date: morgens(3, 2), sets: [satz(60, 10)])),
      );
    });

    test('ProgressPoint vergleicht über alle Felder', () {
      final tag = BerlinCalendar.startOfDay(morgens(3, 2));
      final eins = ProgressPoint(day: tag, top: 60, oneRepMax: 80);
      expect(eins, ProgressPoint(day: tag, top: 60, oneRepMax: 80));
      expect(
        eins.hashCode,
        ProgressPoint(day: tag, top: 60, oneRepMax: 80).hashCode,
      );
      expect(eins, isNot(ProgressPoint(day: tag, top: 62.5, oneRepMax: 80)));
      expect(eins, isNot(ProgressPoint(day: tag, top: 60, oneRepMax: 81)));
      expect(eins, isNot(ProgressPoint(day: tag, top: 60)));
      expect(
        eins,
        isNot(
          ProgressPoint(
            day: BerlinCalendar.startOfDay(morgens(3, 3)),
            top: 60,
            oneRepMax: 80,
          ),
        ),
      );
    });

    test('das Ergebnis zweier gleicher Aufrufe ist gleich', () {
      List<ProgressPoint> lauf() => punkte(bank, [
        training(morgens(3, 2), [satz(60, 10)]),
        training(morgens(3, 9), [satz(62.5, 10)]),
      ]);
      expect(lauf(), lauf());
    });
  });
}
