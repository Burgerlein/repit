import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für `Packages/trainings_core/lib/src/serie.dart` — Task 1 des
/// Umsetzungsplans `docs/superpowers/plans/2026-11-05-live-aktivitaet.md`
/// (#363), Spec `docs/superpowers/specs/2026-11-05-live-aktivitaet-design.md`,
/// Abschnitt „Die Rechnungen im Kern", Vorgabe V1.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf **ausgeführt, nie verändert** werden.
///
/// ## API, die diese Tests verbindlich vorgeben
///
/// ```dart
/// bool vollstaendig(Set<Mahlzeit> mitEintrag);
///
/// ({int heute, int abMorgen}) serie({
///   required Map<String, Set<Mahlzeit>> mahlzeitenJeTag,
///   required String esstag,
/// });
/// ```
///
/// ## Die Regel (V1, Tim 05.11.2026)
///
/// - Ein Tag ist **vollständig**, sobald mindestens eine Mahlzeit einen
///   Eintrag hat — welche, ist gleich, auch ein Snack.
/// - `heute` zählt rückwärts, angefangen beim Esstag, wenn er vollständig
///   ist, sonst beim Vortag, so lange jeder Tag vollständig ist. Ein Tag,
///   der in der Map fehlt, ist nicht vollständig. **Ein noch leeres Heute
///   bricht die Serie nicht, es zählt nur nicht mit.**
/// - `abMorgen` ist `heute`, wenn der Esstag einen Eintrag hat, sonst `0`:
///   Ein Tag ohne Eintrag ist um 04:00 abgeschlossen und bricht die Serie.
/// - Gezählt wird über den Kalender, nie über Sekunden.
///
/// Die Tagesschlüssel sind ISO-Tage (`2027-01-14`), wie `esstag` sie
/// liefert. Die Jahre sind frei gewählt.
///
/// ## Festlegungen des Test-Agenten — nicht von Tim freigegeben
///
/// - Ein Tag, der in der Map steht, aber mit leerer Menge, wird wie ein
///   fehlender Tag behandelt. Folgt aus `vollstaendig({}) == false`, steht
///   so aber nicht wörtlich in der Spec.
/// - Ein Tag **nach** dem Esstag wird ignoriert, auch wenn er vollständig
///   ist (Plan, Task 1, Step 1). Das gilt hier ebenso für `abMorgen`: Ein
///   Eintrag „morgen" rettet ein leeres Heute nicht.
/// - Der Test mit 400 Tagen am Stück prüft, dass die Serie nach oben nicht
///   gedeckelt ist. Eine Obergrenze nennt die Spec nicht.
void main() {
  /// Ein ISO-Tag aus Jahr, Monat und Tag, unabhängig von der
  /// Implementierung gebaut. `DateTime.utc` normalisiert Überläufe
  /// (`tag + i`) über Monats- und Jahresgrenzen.
  String tag(int jahr, int monat, int t) {
    final d = DateTime.utc(jahr, monat, t);
    final j = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$j-$m-$dd';
  }

  group('vollstaendig', () {
    test('ein Snack allein reicht', () {
      expect(vollstaendig({Mahlzeit.snack}), isTrue);
    });

    test('ein Frühstück allein reicht', () {
      expect(vollstaendig({Mahlzeit.fruehstueck}), isTrue);
    });

    test('ein Mittag allein reicht', () {
      expect(vollstaendig({Mahlzeit.mittag}), isTrue);
    });

    test('ein Abend allein reicht', () {
      expect(vollstaendig({Mahlzeit.abend}), isTrue);
    });

    test('alle vier sind vollständig', () {
      expect(vollstaendig(Mahlzeit.values.toSet()), isTrue);
    });

    test('ohne Eintrag ist der Tag nicht vollständig', () {
      expect(vollstaendig(<Mahlzeit>{}), isFalse);
    });
  });

  group('serie — die Pflichtfälle', () {
    test('drei vollständige Tage bis einschließlich Esstag → 3, 3', () {
      final s = serie(
        mahlzeitenJeTag: {
          '2027-01-12': {Mahlzeit.mittag},
          '2027-01-13': {Mahlzeit.abend},
          '2027-01-14': {Mahlzeit.fruehstueck},
        },
        esstag: '2027-01-14',
      );
      expect(s.heute, 3);
      expect(s.abMorgen, 3);
    });

    test('drei vollständige Tage bis gestern, heute fehlt → 3, 0', () {
      final s = serie(
        mahlzeitenJeTag: {
          '2027-01-11': {Mahlzeit.mittag},
          '2027-01-12': {Mahlzeit.abend},
          '2027-01-13': {Mahlzeit.fruehstueck, Mahlzeit.snack},
        },
        esstag: '2027-01-14',
      );
      expect(s.heute, 3);
      expect(s.abMorgen, 0);
    });

    test('dasselbe, heute steht mit leerer Menge in der Map → 3, 0', () {
      final s = serie(
        mahlzeitenJeTag: {
          '2027-01-11': {Mahlzeit.mittag},
          '2027-01-12': {Mahlzeit.abend},
          '2027-01-13': {Mahlzeit.fruehstueck},
          '2027-01-14': <Mahlzeit>{},
        },
        esstag: '2027-01-14',
      );
      expect(s.heute, 3);
      expect(s.abMorgen, 0);
    });

    test('heute vollständig, gestern fehlt in der Map → 1, 1', () {
      final s = serie(
        mahlzeitenJeTag: {
          '2027-01-12': {Mahlzeit.mittag},
          '2027-01-14': {Mahlzeit.snack},
        },
        esstag: '2027-01-14',
      );
      expect(s.heute, 1);
      expect(s.abMorgen, 1);
    });

    test('leere Map → 0, 0', () {
      final s = serie(mahlzeitenJeTag: const {}, esstag: '2027-01-14');
      expect(s.heute, 0);
      expect(s.abMorgen, 0);
    });

    test('heute leer und gestern leer → 0, 0, auch wenn davor etwas war', () {
      final s = serie(
        mahlzeitenJeTag: {
          '2027-01-10': {Mahlzeit.mittag},
          '2027-01-11': {Mahlzeit.mittag},
          '2027-01-12': {Mahlzeit.mittag},
        },
        esstag: '2027-01-14',
      );
      expect(s.heute, 0);
      expect(s.abMorgen, 0);
    });

    test('nur heute, nur ein Snack → 1, 1', () {
      final s = serie(
        mahlzeitenJeTag: {
          '2027-01-14': {Mahlzeit.snack},
        },
        esstag: '2027-01-14',
      );
      expect(s.heute, 1);
      expect(s.abMorgen, 1);
    });
  });

  group('serie — Lücken', () {
    test('ein fehlender Tag in der Mitte: gezählt wird bis zur Lücke', () {
      final s = serie(
        mahlzeitenJeTag: {
          '2027-01-09': {Mahlzeit.mittag},
          '2027-01-10': {Mahlzeit.mittag},
          '2027-01-11': {Mahlzeit.mittag},
          // 12.01. fehlt
          '2027-01-13': {Mahlzeit.abend},
          '2027-01-14': {Mahlzeit.fruehstueck},
        },
        esstag: '2027-01-14',
      );
      expect(s.heute, 2);
      expect(s.abMorgen, 2);
    });

    test('ein leerer Tag in der Mitte bricht genauso', () {
      final s = serie(
        mahlzeitenJeTag: {
          '2027-01-10': {Mahlzeit.mittag},
          '2027-01-11': {Mahlzeit.mittag},
          '2027-01-12': <Mahlzeit>{},
          '2027-01-13': {Mahlzeit.abend},
          '2027-01-14': {Mahlzeit.fruehstueck},
        },
        esstag: '2027-01-14',
      );
      expect(s.heute, 2);
      expect(s.abMorgen, 2);
    });

    test('Lücke bei leerem Heute: gezählt wird ab gestern bis zur Lücke', () {
      final s = serie(
        mahlzeitenJeTag: {
          '2027-01-10': {Mahlzeit.mittag},
          // 11.01. fehlt
          '2027-01-12': {Mahlzeit.mittag},
          '2027-01-13': {Mahlzeit.abend},
        },
        esstag: '2027-01-14',
      );
      expect(s.heute, 2);
      expect(s.abMorgen, 0);
    });
  });

  group('serie — über Monat, Jahr und Zeitumstellung', () {
    test('über einen Monatswechsel zählt jeder Tag genau einmal', () {
      // 2027 ist kein Schaltjahr: 27.02., 28.02., 01.03., 02.03.
      final s = serie(
        mahlzeitenJeTag: {
          '2027-02-27': {Mahlzeit.mittag},
          '2027-02-28': {Mahlzeit.mittag},
          '2027-03-01': {Mahlzeit.mittag},
          '2027-03-02': {Mahlzeit.mittag},
        },
        esstag: '2027-03-02',
      );
      expect(s.heute, 4);
      expect(s.abMorgen, 4);
    });

    test('über den 29. Februar eines Schaltjahrs', () {
      final s = serie(
        mahlzeitenJeTag: {
          '2028-02-28': {Mahlzeit.mittag},
          '2028-02-29': {Mahlzeit.mittag},
          '2028-03-01': {Mahlzeit.mittag},
        },
        esstag: '2028-03-01',
      );
      expect(s.heute, 3);
      expect(s.abMorgen, 3);
    });

    test('ohne den 29. Februar ist die Serie im Schaltjahr gebrochen', () {
      final s = serie(
        mahlzeitenJeTag: {
          '2028-02-27': {Mahlzeit.mittag},
          '2028-02-28': {Mahlzeit.mittag},
          // 29.02.2028 fehlt
          '2028-03-01': {Mahlzeit.mittag},
        },
        esstag: '2028-03-01',
      );
      expect(s.heute, 1);
      expect(s.abMorgen, 1);
    });

    test('über den Jahreswechsel', () {
      final s = serie(
        mahlzeitenJeTag: {
          '2026-12-30': {Mahlzeit.mittag},
          '2026-12-31': {Mahlzeit.abend},
          '2027-01-01': {Mahlzeit.snack},
          '2027-01-02': {Mahlzeit.fruehstueck},
        },
        esstag: '2027-01-02',
      );
      expect(s.heute, 4);
      expect(s.abMorgen, 4);
    });

    test('über die Umstellung im März (23-Stunden-Tag)', () {
      final s = serie(
        mahlzeitenJeTag: {
          '2027-03-27': {Mahlzeit.mittag},
          '2027-03-28': {Mahlzeit.mittag},
          '2027-03-29': {Mahlzeit.mittag},
        },
        esstag: '2027-03-29',
      );
      expect(s.heute, 3);
      expect(s.abMorgen, 3);
    });

    test('über die Umstellung im Oktober (25-Stunden-Tag)', () {
      final s = serie(
        mahlzeitenJeTag: {
          '2027-10-30': {Mahlzeit.mittag},
          '2027-10-31': {Mahlzeit.mittag},
          '2027-11-01': {Mahlzeit.mittag},
        },
        esstag: '2027-11-01',
      );
      expect(s.heute, 3);
      expect(s.abMorgen, 3);
    });

    test('400 Tage am Stück über beide Umstellungen → 400', () {
      final map = <String, Set<Mahlzeit>>{
        for (var i = 0; i < 400; i++) tag(2027, 1, 1 + i): {Mahlzeit.abend},
      };
      final letzter = tag(2027, 1, 400);
      final s = serie(mahlzeitenJeTag: map, esstag: letzter);
      expect(s.heute, 400);
      expect(s.abMorgen, 400);
    });
  });

  group('serie — was nicht zählt', () {
    test('ein Tag nach dem Esstag wird ignoriert', () {
      final s = serie(
        mahlzeitenJeTag: {
          '2027-01-13': {Mahlzeit.mittag},
          '2027-01-14': {Mahlzeit.mittag},
          '2027-01-15': {Mahlzeit.mittag},
          '2027-01-16': {Mahlzeit.mittag},
        },
        esstag: '2027-01-14',
      );
      expect(s.heute, 2);
      expect(s.abMorgen, 2);
    });

    test('ein Eintrag nach dem Esstag rettet ein leeres Heute nicht', () {
      final s = serie(
        mahlzeitenJeTag: {
          '2027-01-12': {Mahlzeit.mittag},
          '2027-01-13': {Mahlzeit.mittag},
          '2027-01-15': {Mahlzeit.mittag},
        },
        esstag: '2027-01-14',
      );
      expect(s.heute, 2);
      expect(s.abMorgen, 0);
    });

    test('die Eingabe wird nicht verändert', () {
      final map = <String, Set<Mahlzeit>>{
        '2027-01-13': {Mahlzeit.mittag},
        '2027-01-14': <Mahlzeit>{},
      };
      serie(mahlzeitenJeTag: map, esstag: '2027-01-14');
      expect(map.keys, ['2027-01-13', '2027-01-14']);
      expect(map['2027-01-13'], {Mahlzeit.mittag});
      expect(map['2027-01-14'], isEmpty);
    });
  });
}
