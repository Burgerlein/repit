import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für `periodenAus` — Abschnitt 2 der Spec
/// `docs/superpowers/specs/2026-11-23-zyklus-spec.md` (Bereich #539).
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf **ausgeführt, nie verändert** werden. Hält der
/// Implementierende eine Erwartung für falsch, wird das **gemeldet, nicht
/// korrigiert**.
///
/// Alle Tage liegen im Jahr 2099. Es sind erfundene Kalenderangaben, keine
/// Gesundheitsdaten einer realen Person (`CLAUDE.md`, „Echte
/// Gesundheitsdaten stehen nie im Quelltext").
///
/// ## API, die diese Tests voraussetzen (Spec, Abschnitt 5)
///
/// ```dart
/// enum Blutungsstaerke { leicht, mittel, stark }
/// class Periode { final String von; final String bis; }
/// List<Periode> periodenAus(Map<String, Blutungsstaerke?> blutungstage);
/// ```
///
/// ## Woher die Erwartungen kommen
///
/// * **2.1 Regel 1:** Der erste und der letzte Tag einer Periode sind
///   Blutungstage.
/// * **2.1 Regel 2:** Innerhalb einer Periode liegen höchstens **zwei**
///   aufeinanderfolgende Tage ohne Blutung. Drei oder mehr trennen.
/// * **2.1 Regel 3:** Eine Periode ist höchstens **10 Tage** lang.
///   Blutungstage darüber hinaus verlängern sie nicht und beginnen keine
///   neue.
/// * **2.1:** Ein neuer Periodenstart braucht mindestens **10 Tage**
///   Abstand zum vorigen Periodenstart. Nähere Blutungstage, die nicht nach
///   Regel 2 zur laufenden Periode gehören, sind Zwischenblutung.
/// * **2.2:** Die beiden Beispiele gelten wörtlich.
/// * **Abschnitt 1:** Blutungstag ist ein Tageseintrag mit `blutung` ∈
///   {leicht, mittel, stark}. Zwischenblutung ist ein **eigenes Feld** und
///   **kein** Blutungstag.
/// * **4.1:** Die Spalte `blutung` speichert `leicht`, `mittel`, `stark` —
///   die Enum-Namen sind damit Speicherformat.
///
/// ## Festlegungen des Test-Agenten — nicht von Tim freigegeben
///
/// Sie folgen aus der Spec, stehen dort aber nicht wörtlich:
///
/// 1. **Ein Eintrag mit dem Wert `null` ist kein Blutungstag.** Die Signatur
///    nimmt `Map<String, Blutungsstaerke?>`; ein Tageseintrag ohne Blutung
///    ist nach Abschnitt 1 kein Blutungstag. So — und nur so — ist
///    „Zwischenblutung startet nie eine Periode" im Kern überhaupt
///    ausdrückbar: Ein Tag, an dem nur Zwischenblutung eingetragen ist,
///    erreicht `periodenAus` ohne Blutungsstärke.
/// 2. **Das Ergebnis ist nach `von` aufsteigend sortiert und hängt nicht von
///    der Reihenfolge im Wörterbuch ab.** Eine `Map` in Dart behält die
///    Einfügereihenfolge; ein Ergebnis, das davon abhinge, wäre je nach
///    Ladeweg ein anderes.
/// 3. **Eine eintägige Periode ist eine Periode** (`von == bis`). Regel 1
///    verlangt nur, dass erster und letzter Tag Blutungstage sind.
/// 4. **Endet das 10-Tage-Fenster auf einem Tag ohne Blutung, endet die
///    Periode am letzten Blutungstag darin.** Regel 1 verlangt einen
///    Blutungstag als letzten Tag, Regel 3 begrenzt das Fenster.
/// 5. **`Periode` ist ein Werttyp** mit `==` und `hashCode`
///    (`CLAUDE.md`: „Ein Werttyp, der Abhängigkeit eines Providers ist,
///    braucht `==` und `hashCode`"), und der Konstruktor nimmt die beiden
///    Felder **benannt** — wie `AuszeitTage`.
void main() {
  /// Macht aus einer Liste von Tagen Blutungstage mittlerer Stärke.
  Map<String, Blutungsstaerke?> blutungstage(List<String> tage) => {
    for (final t in tage) t: Blutungsstaerke.mittel,
  };

  /// `von..bis` je Periode — lesbare Erwartungen, lesbare Fehlermeldungen.
  List<String> spannen(List<Periode> perioden) => [
    for (final p in perioden) '${p.von}..${p.bis}',
  ];

  group('Blutungsstaerke', () {
    test('die Namen sind die gespeicherten Werte der Spalte blutung', () {
      expect(Blutungsstaerke.leicht.name, 'leicht');
      expect(Blutungsstaerke.mittel.name, 'mittel');
      expect(Blutungsstaerke.stark.name, 'stark');
    });
  });

  group('Periode ist ein Werttyp', () {
    test('zwei Perioden mit gleichem von und bis sind gleich', () {
      expect(
        Periode(von: '2099-06-06', bis: '2099-06-10'),
        equals(Periode(von: '2099-06-06', bis: '2099-06-10')),
      );
      expect(
        Periode(von: '2099-06-06', bis: '2099-06-10').hashCode,
        equals(Periode(von: '2099-06-06', bis: '2099-06-10').hashCode),
      );
    });

    test('ein anderes von macht sie ungleich', () {
      expect(
        Periode(von: '2099-06-06', bis: '2099-06-10'),
        isNot(equals(Periode(von: '2099-06-07', bis: '2099-06-10'))),
      );
    });

    test('ein anderes bis macht sie ungleich', () {
      expect(
        Periode(von: '2099-06-06', bis: '2099-06-10'),
        isNot(equals(Periode(von: '2099-06-06', bis: '2099-06-11'))),
      );
    });
  });

  group('Die beiden Beispiele aus 2.2 — sie müssen wörtlich gelten', () {
    test('6., 7., 9., 10., dann der 20.: zwei Perioden', () {
      final ergebnis = periodenAus(
        blutungstage([
          '2099-06-06',
          '2099-06-07',
          '2099-06-09',
          '2099-06-10',
          '2099-06-20',
        ]),
      );

      expect(
        spannen(ergebnis),
        equals(['2099-06-06..2099-06-10', '2099-06-20..2099-06-20']),
        reason:
            'Der 8. ist eine Lücke von einem Tag und erlaubt; der 20. liegt '
            '14 Tage nach dem 6. und startet eine neue Periode.',
      );
    });

    test(
      '6., 7., 8. und der 12.: eine Periode, der 12. ist Zwischenblutung',
      () {
        final ergebnis = periodenAus(
          blutungstage([
            '2099-06-06',
            '2099-06-07',
            '2099-06-08',
            '2099-06-12',
          ]),
        );

        expect(
          spannen(ergebnis),
          equals(['2099-06-06..2099-06-08']),
          reason:
              'Der 12. liegt 6 Tage nach dem Start — keine neue Periode. Er '
              'gehört auch nicht zur ersten: mehr als zwei Tage Lücke.',
        );
      },
    );
  });

  group('Lücken innerhalb einer Periode — die Grenze liegt bei zwei Tagen', () {
    test('eine Lücke von einem Tag trennt nicht', () {
      expect(
        spannen(
          periodenAus(blutungstage(['2099-06-01', '2099-06-02', '2099-06-04'])),
        ),
        equals(['2099-06-01..2099-06-04']),
      );
    });

    test('eine Lücke von zwei Tagen trennt nicht', () {
      expect(
        spannen(
          periodenAus(blutungstage(['2099-06-01', '2099-06-02', '2099-06-05'])),
        ),
        equals(['2099-06-01..2099-06-05']),
      );
    });

    test(
      'eine Lücke von drei Tagen trennt — der ferne Tag gehört nicht dazu',
      () {
        // Der 6. liegt nur 5 Tage nach dem Start und startet deshalb auch
        // keine neue Periode (10-Tage-Mindestabstand): Er ist Zwischenblutung.
        expect(
          spannen(
            periodenAus(
              blutungstage(['2099-06-01', '2099-06-02', '2099-06-06']),
            ),
          ),
          equals(['2099-06-01..2099-06-02']),
        );
      },
    );

    test('eine Lücke von drei Tagen trennt zwei echte Perioden', () {
      // 01.–08. ist eine Periode; 09., 10., 11. sind leer (drei Tage), und
      // der 12. liegt 11 Tage nach dem Start — Abstand genügt.
      expect(
        spannen(
          periodenAus(
            blutungstage([
              '2099-06-01',
              '2099-06-02',
              '2099-06-03',
              '2099-06-04',
              '2099-06-05',
              '2099-06-06',
              '2099-06-07',
              '2099-06-08',
              '2099-06-12',
              '2099-06-13',
            ]),
          ),
        ),
        equals(['2099-06-01..2099-06-08', '2099-06-12..2099-06-13']),
      );
    });
  });

  group('Eine Periode ist höchstens 10 Tage lang (Regel 3)', () {
    test('zehn Blutungstage am Stück sind genau eine Periode', () {
      expect(
        spannen(
          periodenAus(
            blutungstage([
              for (var t = 1; t <= 10; t++)
                '2099-07-${t.toString().padLeft(2, '0')}',
            ]),
          ),
        ),
        equals(['2099-07-01..2099-07-10']),
      );
    });

    test('der 11. und 12. Tag verlängern sie nicht und starten keine neue', () {
      expect(
        spannen(
          periodenAus(
            blutungstage([
              for (var t = 1; t <= 12; t++)
                '2099-07-${t.toString().padLeft(2, '0')}',
            ]),
          ),
        ),
        equals(['2099-07-01..2099-07-10']),
      );
    });

    test(
      'nach drei leeren Tagen beginnt trotz Überhang wieder eine Periode',
      () {
        // 11. und 12. sind Überhang (Regel 3), 13.–15. sind leer, der 16.
        // liegt 15 Tage nach dem Start.
        expect(
          spannen(
            periodenAus(
              blutungstage([
                for (var t = 1; t <= 12; t++)
                  '2099-07-${t.toString().padLeft(2, '0')}',
                '2099-07-16',
                '2099-07-17',
              ]),
            ),
          ),
          equals(['2099-07-01..2099-07-10', '2099-07-16..2099-07-17']),
        );
      },
    );

    test('endet das Fenster auf einem leeren Tag, endet die Periode davor', () {
      // 01.–09. Blutung, 10. leer, 11. und 12. wieder Blutung: Das Fenster
      // reicht bis zum 10., der letzte Tag muss aber ein Blutungstag sein.
      expect(
        spannen(
          periodenAus(
            blutungstage([
              for (var t = 1; t <= 9; t++)
                '2099-07-${t.toString().padLeft(2, '0')}',
              '2099-07-11',
              '2099-07-12',
            ]),
          ),
        ),
        equals(['2099-07-01..2099-07-09']),
      );
    });
  });

  group('Ein neuer Start braucht 10 Tage Abstand zum vorigen Start', () {
    test('neun Tage Abstand reichen nicht — das ist Zwischenblutung', () {
      expect(
        spannen(
          periodenAus(
            blutungstage([
              '2099-08-01',
              '2099-08-02',
              '2099-08-03',
              '2099-08-10',
            ]),
          ),
        ),
        equals(['2099-08-01..2099-08-03']),
      );
    });

    test('zehn Tage Abstand genügen', () {
      expect(
        spannen(
          periodenAus(
            blutungstage([
              '2099-08-01',
              '2099-08-02',
              '2099-08-03',
              '2099-08-11',
            ]),
          ),
        ),
        equals(['2099-08-01..2099-08-03', '2099-08-11..2099-08-11']),
      );
    });

    test('eine Zwischenblutung verschiebt den nächsten Start nicht', () {
      // Der 10. ist Zwischenblutung (9 Tage Abstand). Der 15. liegt 14 Tage
      // nach dem 1. — gemessen wird am Periodenstart, nicht am 10.
      expect(
        spannen(
          periodenAus(
            blutungstage([
              '2099-08-01',
              '2099-08-02',
              '2099-08-03',
              '2099-08-10',
              '2099-08-15',
              '2099-08-16',
            ]),
          ),
        ),
        equals(['2099-08-01..2099-08-03', '2099-08-15..2099-08-16']),
      );
    });
  });

  group('Zwischenblutung ist kein Blutungstag (Abschnitt 1)', () {
    test('ein Tag ohne Blutungsstärke startet keine Periode', () {
      expect(periodenAus({'2099-09-05': null, '2099-09-06': null}), isEmpty);
    });

    test('ein Tag ohne Blutungsstärke unterbricht eine Periode nicht', () {
      // Der 3. steht als Eintrag ohne Blutung da (etwa nur Zwischenblutung)
      // und zählt als Lücke von einem Tag — nicht als Blutungstag.
      expect(
        spannen(
          periodenAus({
            '2099-09-01': Blutungsstaerke.mittel,
            '2099-09-02': Blutungsstaerke.stark,
            '2099-09-03': null,
            '2099-09-04': Blutungsstaerke.leicht,
          }),
        ),
        equals(['2099-09-01..2099-09-04']),
      );
    });

    test('ein Tag ohne Blutungsstärke am Rand gehört nicht zur Periode', () {
      expect(
        spannen(
          periodenAus({
            '2099-09-01': null,
            '2099-09-02': Blutungsstaerke.mittel,
            '2099-09-03': Blutungsstaerke.mittel,
            '2099-09-04': null,
          }),
        ),
        equals(['2099-09-02..2099-09-03']),
      );
    });
  });

  group('Jede Blutungsstärke zählt gleich', () {
    test('leicht, mittel und stark bilden zusammen eine Periode', () {
      expect(
        spannen(
          periodenAus({
            '2099-10-01': Blutungsstaerke.leicht,
            '2099-10-02': Blutungsstaerke.stark,
            '2099-10-03': Blutungsstaerke.mittel,
          }),
        ),
        equals(['2099-10-01..2099-10-03']),
      );
    });

    test('ein einzelner leichter Tag ist eine eintägige Periode', () {
      expect(
        spannen(periodenAus({'2099-10-01': Blutungsstaerke.leicht})),
        equals(['2099-10-01..2099-10-01']),
      );
    });
  });

  group('Ränder', () {
    test('ohne Einträge gibt es keine Periode', () {
      expect(periodenAus({}), isEmpty);
    });

    test('das Ergebnis ist nach von sortiert, egal wie die Tage ankommen', () {
      final durcheinander = {
        '2099-06-20': Blutungsstaerke.mittel,
        '2099-06-07': Blutungsstaerke.leicht,
        '2099-06-10': Blutungsstaerke.mittel,
        '2099-06-06': Blutungsstaerke.stark,
        '2099-06-09': Blutungsstaerke.mittel,
      };

      expect(
        spannen(periodenAus(durcheinander)),
        equals(['2099-06-06..2099-06-10', '2099-06-20..2099-06-20']),
      );
    });

    test('Perioden laufen über einen Monatswechsel hinweg', () {
      expect(
        spannen(
          periodenAus(
            blutungstage([
              '2099-01-30',
              '2099-01-31',
              '2099-02-01',
              '2099-02-02',
            ]),
          ),
        ),
        equals(['2099-01-30..2099-02-02']),
      );
    });

    test('Perioden laufen über einen Jahreswechsel hinweg', () {
      expect(
        spannen(
          periodenAus(blutungstage(['2099-12-30', '2099-12-31', '2100-01-01'])),
        ),
        equals(['2099-12-30..2100-01-01']),
      );
    });
  });
}
