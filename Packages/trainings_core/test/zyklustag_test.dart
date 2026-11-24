import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für `zyklustagAm` — Abschnitt 1 und 5 der Spec
/// `docs/superpowers/specs/2026-11-23-zyklus-spec.md` (Bereich #539).
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf **ausgeführt, nie verändert** werden. Hält der
/// Implementierende eine Erwartung für falsch, wird das **gemeldet, nicht
/// korrigiert**.
///
/// Alle Tage liegen in den Jahren 2098 bis 2100. Es sind erfundene
/// Kalenderangaben, keine Gesundheitsdaten einer realen Person.
///
/// ## API, die diese Tests voraussetzen (Spec, Abschnitt 5)
///
/// ```dart
/// int? zyklustagAm(String tag, List<Periode> perioden);
/// ```
///
/// ## Woher die Erwartungen kommen
///
/// * **Abschnitt 1:** Der Zyklustag ist 1 am Periodenstart und läuft danach
///   fortlaufend weiter. Ein Zyklus reicht von einem Periodenstart bis zum
///   Tag **vor** dem nächsten.
/// * **Abschnitt 5:** `null`, wenn der Tag vor der ersten bekannten Periode
///   liegt.
///
/// ## Festlegungen des Test-Agenten — nicht von Tim freigegeben
///
/// Sie folgen aus der Spec, stehen dort aber nicht wörtlich:
///
/// 1. **Nach dem letzten bekannten Periodenstart zählt der Zyklustag
///    weiter**, auch über die erwartete Länge hinaus. Der laufende Zyklus
///    hat kein Ende, solange kein nächster Start bekannt ist; eine
///    Begrenzung stünde in der Spec.
/// 2. **Ohne Perioden gibt es keinen Zyklustag** — dann liegt jeder Tag vor
///    der ersten bekannten Periode.
/// 3. **Die Reihenfolge der Perioden in der Liste spielt keine Rolle.**
void main() {
  Periode p(String von, String bis) => Periode(von: von, bis: bis);

  // Drei Perioden zu je fünf Tagen im Abstand von 28 Tagen.
  final perioden = [
    p('2099-01-05', '2099-01-09'),
    p('2099-02-02', '2099-02-06'),
    p('2099-03-02', '2099-03-06'),
  ];

  group('Vor der ersten bekannten Periode gibt es keinen Zyklustag', () {
    test('der Tag vor dem ersten Periodenstart ist null', () {
      expect(zyklustagAm('2099-01-04', perioden), isNull);
    });

    test('ein weit zurückliegender Tag ist null', () {
      expect(zyklustagAm('2098-11-30', perioden), isNull);
    });

    test('ohne Perioden ist jeder Tag null', () {
      expect(zyklustagAm('2099-03-10', []), isNull);
    });
  });

  group('Der Periodenstart ist Zyklustag 1', () {
    test('am ersten Periodenstart', () {
      expect(zyklustagAm('2099-01-05', perioden), 1);
    });

    test('am zweiten Periodenstart beginnt die Zählung von vorn', () {
      expect(zyklustagAm('2099-02-02', perioden), 1);
    });

    test('am dritten Periodenstart ebenso', () {
      expect(zyklustagAm('2099-03-02', perioden), 1);
    });
  });

  group('Danach zählt der Zyklustag fortlaufend', () {
    test('der Tag nach dem Start ist Tag 2', () {
      expect(zyklustagAm('2099-01-06', perioden), 2);
    });

    test('der letzte Blutungstag der Periode ist Tag 5', () {
      expect(zyklustagAm('2099-01-09', perioden), 5);
    });

    test('ein Tag zwischen zwei Perioden zählt weiter', () {
      expect(zyklustagAm('2099-01-20', perioden), 16);
    });

    test('der Tag vor dem nächsten Start ist der letzte Tag des Zyklus', () {
      expect(zyklustagAm('2099-02-01', perioden), 28);
      expect(zyklustagAm('2099-03-01', perioden), 28);
    });

    test('im laufenden Zyklus zählt er vom letzten Start aus', () {
      expect(zyklustagAm('2099-03-10', perioden), 9);
    });

    test('der laufende Zyklus endet nicht nach der erwarteten Länge', () {
      expect(zyklustagAm('2099-05-01', perioden), 61);
    });
  });

  group('Ränder', () {
    test('die Zählung läuft über einen Jahreswechsel hinweg', () {
      expect(zyklustagAm('2100-01-02', [p('2099-12-28', '2099-12-31')]), 6);
    });

    test('die Reihenfolge der Perioden in der Liste ändert nichts', () {
      final durcheinander = [perioden[2], perioden[0], perioden[1]];
      expect(zyklustagAm('2099-01-05', durcheinander), 1);
      expect(zyklustagAm('2099-02-01', durcheinander), 28);
      expect(zyklustagAm('2099-03-10', durcheinander), 9);
      expect(zyklustagAm('2099-01-04', durcheinander), isNull);
    });

    test('mit einer einzigen Periode zählt er ab deren Start', () {
      final eine = [p('2099-01-05', '2099-01-09')];
      expect(zyklustagAm('2099-01-05', eine), 1);
      expect(zyklustagAm('2099-02-01', eine), 28);
      expect(zyklustagAm('2099-01-04', eine), isNull);
    });
  });
}
