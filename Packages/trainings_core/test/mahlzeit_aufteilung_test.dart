import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für `Packages/trainings_core/lib/src/mahlzeit_aufteilung.dart`,
/// Task 2 (#431, zu #374) des Plans
/// `docs/superpowers/plans/2026-11-10-mahlzeiten-aufteilung.md`. Grundlage
/// ist die Spec `docs/superpowers/specs/2026-11-10-mahlzeiten-aufteilung-design.md`,
/// Abschnitt „Die Rechnungen im Kern", Tims Entscheidungen 1 bis 5 vom
/// 10.11.2026 und die Vorgaben V3 bis V7 (von Tim am 10.11.2026
/// übernommen).
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf **ausgeführt, nie verändert** werden. Hält der
/// Implementierende eine Erwartung für falsch, wird das **gemeldet, nicht
/// korrigiert**.
///
/// ## API, die diese Tests vorgeben (aus der Spec)
///
/// ```dart
/// const int aufteilungSchritt = 5;
/// const int rundenHoechstens = 3;
///
/// final class MahlzeitAufteilung {
///   MahlzeitAufteilung({required int fruehstueck, required int mittag,
///                       required int abend});   // wirft ArgumentError
///   static final MahlzeitAufteilung startwert;
///   final int fruehstueck, mittag, abend;
///   int get snack;
///   int prozent(Mahlzeit m);
///   bool kannPlus(Mahlzeit m);
///   bool kannMinus(Mahlzeit m);
///   MahlzeitAufteilung plus(Mahlzeit m);   // StateError, wenn !kannPlus
///   MahlzeitAufteilung minus(Mahlzeit m);  // StateError, wenn !kannMinus
/// }
///
/// final class AufteilungAb {
///   const AufteilungAb({required String abTag,
///                       required MahlzeitAufteilung aufteilung});
/// }
///
/// MahlzeitAufteilung? geltendeAufteilung(List<AufteilungAb> historie,
///                                        String tagesSchluessel);
/// double? mahlzeitZielKcal({required double? tageszielKcal,
///                           required MahlzeitAufteilung? aufteilung,
///                           required Mahlzeit mahlzeit});
/// double? mahlzeitAnteil({required bool hatEintrag, required double? kcal,
///                         required double? zielKcal});
/// List<double> anteilRunden(double? anteil);
/// ```
///
/// ## Festlegungen des Test-Agenten, nicht von Tim freigegeben
///
/// Die Spec lässt hier Spielraum; die Tests legen fest:
///
/// 1. **Kommazahlen werden mit `closeTo(…, 1e-9)` geprüft**, nicht mit
///    `equals`. So bleibt offen, ob die Implementierung `× p / 100` oder
///    `× (p / 100)` rechnet. Die Toleranz ist eng genug, dass ein
///    gerundetes Ziel (916 statt 915,95) oder ein ungerundeter Anteil
///    (0,9467 statt 0,95) trotzdem auffällt.
/// 2. **`toString` ist nicht der Standard „Instance of …"**. Die Spec
///    verlangt `toString`, sagt aber nicht, wie er aussieht; geprüft wird
///    nur, dass er die drei Zahlen nennt.
/// 3. **`plus` und `minus` verändern das Original nicht.** Die Spec gibt
///    eine neue Aufteilung zurück und nennt die Felder `final`; der Test
///    hält das fest.
///
/// ## Alle Zahlen sind erfunden
///
/// Tagesziele und kcal sind glatte Rechenwerte, keine Daten von Tim. Die
/// Tage liegen im Jahr 2099.
void main() {
  MahlzeitAufteilung a(int f, int m, int ab) =>
      MahlzeitAufteilung(fruehstueck: f, mittag: m, abend: ab);

  group('Konstanten', () {
    test('Schrittweite ist 5 % (Entscheidung 3)', () {
      expect(aufteilungSchritt, 5);
    });

    test('höchstens drei Runden (#386)', () {
      expect(rundenHoechstens, 3);
    });
  });

  group('MahlzeitAufteilung — Startwert (Entscheidung 1)', () {
    test('25 · 35 · 30, Snack 10', () {
      final s = MahlzeitAufteilung.startwert;
      expect(s.fruehstueck, 25);
      expect(s.mittag, 35);
      expect(s.abend, 30);
      expect(s.snack, 10);
    });
  });

  group('MahlzeitAufteilung — Konstruktor prüft V3', () {
    test('negativer Wert wirft ArgumentError, in jedem der drei Felder', () {
      expect(() => a(-5, 35, 30), throwsArgumentError);
      expect(() => a(25, -5, 30), throwsArgumentError);
      expect(() => a(25, 35, -5), throwsArgumentError);
    });

    test('kein Vielfaches von 5 wirft ArgumentError, in jedem Feld', () {
      expect(() => a(27, 35, 30), throwsArgumentError);
      expect(() => a(25, 27, 30), throwsArgumentError);
      expect(() => a(25, 35, 27), throwsArgumentError);
    });

    test('Summe über 100 wirft ArgumentError (40 · 40 · 30 = 110)', () {
      expect(() => a(40, 40, 30), throwsArgumentError);
    });

    test('Summe 105 wirft ebenfalls (35 · 35 · 35)', () {
      expect(() => a(35, 35, 35), throwsArgumentError);
    });

    test('0 · 0 · 0 ist erlaubt, der Snack bekommt 100', () {
      final x = a(0, 0, 0);
      expect(x.snack, 100);
    });

    test('30 · 35 · 35 ist erlaubt, der Snack bekommt 0', () {
      final x = a(30, 35, 35);
      expect(x.snack, 0);
    });

    test('Frühstück, Mittag oder Abend dürfen einzeln auf 0 % (V3)', () {
      expect(a(0, 35, 30).fruehstueck, 0);
      expect(a(25, 0, 30).mittag, 0);
      expect(a(25, 35, 0).abend, 0);
    });
  });

  group('MahlzeitAufteilung.prozent', () {
    test('nennt alle vier Mahlzeiten des Startwerts', () {
      final s = MahlzeitAufteilung.startwert;
      expect(s.prozent(Mahlzeit.fruehstueck), 25);
      expect(s.prozent(Mahlzeit.mittag), 35);
      expect(s.prozent(Mahlzeit.abend), 30);
      expect(s.prozent(Mahlzeit.snack), 10);
    });

    test('auch bei einer anderen Aufteilung', () {
      final x = a(20, 40, 25);
      expect(x.prozent(Mahlzeit.fruehstueck), 20);
      expect(x.prozent(Mahlzeit.mittag), 40);
      expect(x.prozent(Mahlzeit.abend), 25);
      expect(x.prozent(Mahlzeit.snack), 15);
    });
  });

  group('MahlzeitAufteilung.kannPlus / kannMinus (V3)', () {
    test('„+" ist bei Snack 0 für alle drei gesperrt', () {
      final x = a(30, 35, 35);
      expect(x.kannPlus(Mahlzeit.fruehstueck), isFalse);
      expect(x.kannPlus(Mahlzeit.mittag), isFalse);
      expect(x.kannPlus(Mahlzeit.abend), isFalse);
    });

    test('„+" geht bei Snack 5', () {
      final x = a(30, 35, 30);
      expect(x.snack, 5);
      expect(x.kannPlus(Mahlzeit.fruehstueck), isTrue);
      expect(x.kannPlus(Mahlzeit.mittag), isTrue);
      expect(x.kannPlus(Mahlzeit.abend), isTrue);
    });

    test('„−" ist bei 0 % gesperrt', () {
      final x = a(25, 35, 0);
      expect(x.kannMinus(Mahlzeit.abend), isFalse);
    });

    test('„−" geht bei 5 %', () {
      final x = a(5, 35, 30);
      expect(x.kannMinus(Mahlzeit.fruehstueck), isTrue);
    });

    test('Snack hat nie „+" oder „−" (Entscheidung 2)', () {
      for (final x in [
        MahlzeitAufteilung.startwert,
        a(0, 0, 0),
        a(30, 35, 35),
      ]) {
        expect(x.kannPlus(Mahlzeit.snack), isFalse, reason: '$x');
        expect(x.kannMinus(Mahlzeit.snack), isFalse, reason: '$x');
      }
    });
  });

  group('MahlzeitAufteilung.plus / minus', () {
    test('plus(fruehstueck) von 25 · 35 · 30 ergibt 30 · 35 · 30, Snack 5', () {
      final x = MahlzeitAufteilung.startwert.plus(Mahlzeit.fruehstueck);
      expect(x.fruehstueck, 30);
      expect(x.mittag, 35);
      expect(x.abend, 30);
      expect(x.snack, 5);
    });

    test('minus(mittag) von 25 · 35 · 30 ergibt 25 · 30 · 30, Snack 15', () {
      final x = MahlzeitAufteilung.startwert.minus(Mahlzeit.mittag);
      expect(x, a(25, 30, 30));
      expect(x.snack, 15);
    });

    test('plus und minus verändern das Original nicht', () {
      final x = a(25, 35, 30);
      x.plus(Mahlzeit.abend);
      x.minus(Mahlzeit.abend);
      expect(x, a(25, 35, 30));
      expect(MahlzeitAufteilung.startwert, a(25, 35, 30));
    });

    test('plus bei gesperrtem Knopf wirft StateError', () {
      expect(() => a(30, 35, 35).plus(Mahlzeit.fruehstueck), throwsStateError);
      expect(
        () => MahlzeitAufteilung.startwert.plus(Mahlzeit.snack),
        throwsStateError,
      );
    });

    test('minus bei gesperrtem Knopf wirft StateError', () {
      expect(() => a(25, 35, 0).minus(Mahlzeit.abend), throwsStateError);
      expect(
        () => MahlzeitAufteilung.startwert.minus(Mahlzeit.snack),
        throwsStateError,
      );
    });
  });

  group('MahlzeitAufteilung — Gleichheit', () {
    test('gleiche Zahlen sind gleich, mit gleichem hashCode', () {
      expect(a(25, 35, 30), a(25, 35, 30));
      expect(a(25, 35, 30).hashCode, a(25, 35, 30).hashCode);
      expect(MahlzeitAufteilung.startwert, a(25, 35, 30));
    });

    test('vertauschte Zahlen sind ungleich', () {
      expect(a(25, 35, 30), isNot(a(30, 35, 25)));
      expect(a(25, 35, 30), isNot(a(25, 30, 35)));
    });

    test('toString nennt die Zahlen (Festlegung 2)', () {
      final t = a(20, 40, 25).toString();
      expect(t, isNot(startsWith('Instance of')));
      expect(t, contains('20'));
      expect(t, contains('40'));
      expect(t, contains('25'));
    });
  });

  group('AufteilungAb — Gleichheit', () {
    test('gleicher Tag und gleiche Aufteilung sind gleich', () {
      final x = AufteilungAb(abTag: '2099-03-01', aufteilung: a(25, 35, 30));
      final y = AufteilungAb(abTag: '2099-03-01', aufteilung: a(25, 35, 30));
      expect(x, y);
      expect(x.hashCode, y.hashCode);
    });

    test('anderer Tag ist ungleich', () {
      expect(
        AufteilungAb(abTag: '2099-03-01', aufteilung: a(25, 35, 30)),
        isNot(AufteilungAb(abTag: '2099-03-02', aufteilung: a(25, 35, 30))),
      );
    });

    test('andere Aufteilung ist ungleich', () {
      expect(
        AufteilungAb(abTag: '2099-03-01', aufteilung: a(25, 35, 30)),
        isNot(AufteilungAb(abTag: '2099-03-01', aufteilung: a(30, 35, 25))),
      );
    });

    test('toString ist nicht der Standard (Festlegung 2)', () {
      final t = AufteilungAb(
        abTag: '2099-03-01',
        aufteilung: a(25, 35, 30),
      ).toString();
      expect(t, isNot(startsWith('Instance of')));
      expect(t, contains('2099-03-01'));
    });
  });

  group('geltendeAufteilung (Entscheidung 5)', () {
    final erste = a(25, 35, 30);
    final zweite = a(20, 40, 30);
    final historie = [
      AufteilungAb(abTag: '2099-03-01', aufteilung: erste),
      AufteilungAb(abTag: '2099-03-10', aufteilung: zweite),
    ];

    test('leere Historie ergibt null — nie den Startwert', () {
      expect(geltendeAufteilung(const [], '2099-03-05'), isNull);
    });

    test('zwischen beiden gilt die erste', () {
      expect(geltendeAufteilung(historie, '2099-03-05'), erste);
    });

    test('am Tag der zweiten gilt die zweite', () {
      expect(geltendeAufteilung(historie, '2099-03-10'), zweite);
    });

    test('nach der zweiten gilt die zweite', () {
      expect(geltendeAufteilung(historie, '2099-12-31'), zweite);
    });

    test('am Tag der ersten gilt die erste', () {
      expect(geltendeAufteilung(historie, '2099-03-01'), erste);
    });

    test('vor der ersten ergibt null', () {
      expect(geltendeAufteilung(historie, '2099-02-28'), isNull);
    });

    test('unsortierte Eingabe gibt dasselbe', () {
      final umgekehrt = historie.reversed.toList();
      expect(geltendeAufteilung(umgekehrt, '2099-03-05'), erste);
      expect(geltendeAufteilung(umgekehrt, '2099-03-10'), zweite);
      expect(geltendeAufteilung(umgekehrt, '2099-02-28'), isNull);
    });
  });

  group('mahlzeitZielKcal (V4, V5)', () {
    final s = MahlzeitAufteilung.startwert;

    test('1.800 × 25 % ergibt 450', () {
      expect(
        mahlzeitZielKcal(
          tageszielKcal: 1800,
          aufteilung: s,
          mahlzeit: Mahlzeit.fruehstueck,
        ),
        450,
      );
    });

    test('alle vier Mahlzeiten des Startwerts bei 1.800', () {
      double? ziel(Mahlzeit m) =>
          mahlzeitZielKcal(tageszielKcal: 1800, aufteilung: s, mahlzeit: m);
      expect(ziel(Mahlzeit.mittag), closeTo(630, 1e-9));
      expect(ziel(Mahlzeit.abend), closeTo(540, 1e-9));
      expect(ziel(Mahlzeit.snack), closeTo(180, 1e-9));
    });

    test('2.617 × 35 % ergibt 915,95 — ungerundet (V5)', () {
      expect(
        mahlzeitZielKcal(
          tageszielKcal: 2617,
          aufteilung: s,
          mahlzeit: Mahlzeit.mittag,
        ),
        closeTo(915.95, 1e-9),
      );
    });

    test('ohne Tagesziel null', () {
      expect(
        mahlzeitZielKcal(
          tageszielKcal: null,
          aufteilung: s,
          mahlzeit: Mahlzeit.mittag,
        ),
        isNull,
      );
    });

    test(
      'ohne Aufteilung null — kein Startwert als Ersatz (Entscheidung 1)',
      () {
        expect(
          mahlzeitZielKcal(
            tageszielKcal: 1800,
            aufteilung: null,
            mahlzeit: Mahlzeit.mittag,
          ),
          isNull,
        );
      },
    );

    test('Tagesziel 0 ergibt null', () {
      expect(
        mahlzeitZielKcal(
          tageszielKcal: 0,
          aufteilung: s,
          mahlzeit: Mahlzeit.mittag,
        ),
        isNull,
      );
    });

    test('negatives Tagesziel ergibt null', () {
      expect(
        mahlzeitZielKcal(
          tageszielKcal: -100,
          aufteilung: s,
          mahlzeit: Mahlzeit.mittag,
        ),
        isNull,
      );
    });

    test('Mahlzeit mit 0 % hat kein Ziel (V4)', () {
      expect(
        mahlzeitZielKcal(
          tageszielKcal: 1800,
          aufteilung: a(25, 35, 0),
          mahlzeit: Mahlzeit.abend,
        ),
        isNull,
      );
      expect(
        mahlzeitZielKcal(
          tageszielKcal: 1800,
          aufteilung: a(30, 35, 35),
          mahlzeit: Mahlzeit.snack,
        ),
        isNull,
      );
    });
  });

  group('mahlzeitAnteil (V6)', () {
    test('ohne Ziel null', () {
      expect(
        mahlzeitAnteil(hatEintrag: true, kcal: 426, zielKcal: null),
        isNull,
      );
      expect(
        mahlzeitAnteil(hatEintrag: false, kcal: null, zielKcal: null),
        isNull,
      );
    });

    test('Ziel 0 oder negativ ergibt null', () {
      expect(mahlzeitAnteil(hatEintrag: true, kcal: 426, zielKcal: 0), isNull);
      expect(mahlzeitAnteil(hatEintrag: true, kcal: 426, zielKcal: -1), isNull);
    });

    test('kein Eintrag, Ziel 540 ergibt 0', () {
      expect(mahlzeitAnteil(hatEintrag: false, kcal: null, zielKcal: 540), 0);
    });

    test('Eintrag ohne Kalorienangabe ergibt null — nicht 0', () {
      expect(
        mahlzeitAnteil(hatEintrag: true, kcal: null, zielKcal: 540),
        isNull,
      );
    });

    test('426 / 450 ergibt 0,95 (auf 0,01 gerundet)', () {
      expect(
        mahlzeitAnteil(hatEintrag: true, kcal: 426, zielKcal: 450),
        closeTo(0.95, 1e-9),
      );
    });

    test('672 / 630 ergibt 1,07', () {
      expect(
        mahlzeitAnteil(hatEintrag: true, kcal: 672, zielKcal: 630),
        closeTo(1.07, 1e-9),
      );
    });

    test('genau am Ziel ergibt 1', () {
      expect(
        mahlzeitAnteil(hatEintrag: true, kcal: 540, zielKcal: 540),
        closeTo(1.0, 1e-9),
      );
    });

    test('2.000 / 450 wird auf 3,0 gedeckelt', () {
      expect(
        mahlzeitAnteil(hatEintrag: true, kcal: 2000, zielKcal: 450),
        closeTo(3.0, 1e-9),
      );
    });

    test('negative kcal ergeben 0', () {
      expect(
        mahlzeitAnteil(hatEintrag: true, kcal: -50, zielKcal: 540),
        closeTo(0, 1e-9),
      );
    });

    test('ungerundetes Ziel aus mahlzeitZielKcal wird angenommen', () {
      // 458 / 915,95 = 0,50003 → 0,50
      expect(
        mahlzeitAnteil(hatEintrag: true, kcal: 458, zielKcal: 915.95),
        closeTo(0.5, 1e-9),
      );
    });
  });

  group('anteilRunden (V7)', () {
    test('null, 0, negativ und NaN ergeben keine Runde', () {
      expect(anteilRunden(null), isEmpty);
      expect(anteilRunden(0), isEmpty);
      expect(anteilRunden(-1), isEmpty);
      expect(anteilRunden(double.nan), isEmpty);
    });

    test('0,5 ergibt eine halbe Runde', () {
      expect(anteilRunden(0.5), [0.5]);
    });

    test(
      '1 ergibt genau eine volle Runde — die zweite erst beim Überschreiten',
      () {
        expect(anteilRunden(1.0), [1.0]);
      },
    );

    test('1,3 ergibt eine volle und 0,3 der zweiten', () {
      final r = anteilRunden(1.3);
      expect(r, hasLength(2));
      expect(r[0], 1.0);
      expect(r[1], closeTo(0.3, 1e-9));
    });

    test('2,5 ergibt zwei volle und eine halbe', () {
      expect(anteilRunden(2.5), [1.0, 1.0, 0.5]);
    });

    test('3 ergibt drei volle Runden', () {
      expect(anteilRunden(3.0), [1.0, 1.0, 1.0]);
    });

    test('4,2 wird bei drei vollen Runden gedeckelt', () {
      expect(anteilRunden(4.2), [1.0, 1.0, 1.0]);
    });

    test('nie mehr als rundenHoechstens Runden', () {
      expect(anteilRunden(100), hasLength(rundenHoechstens));
    });
  });
}
