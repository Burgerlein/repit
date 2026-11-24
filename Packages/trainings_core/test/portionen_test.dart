import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für die **Portionsregeln im Kern** (#325, Karte #394, Plan
/// `docs/superpowers/plans/2026-11-05-portionen.md`, Task 2): welche
/// Angaben von Open Food Facts eine Portion werden, was beim Öffnen des
/// Buchungsblatts vorgewählt ist und wie die Anzahl rechnet.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf **ausgeführt, nie verändert** werden. Hält der
/// Implementierende einen Fall für falsch, meldet er das.
///
/// ## Woher die Regeln kommen
///
/// Aus der Spec `docs/superpowers/specs/2026-11-05-portionen-design.md`.
/// Die Entscheidungen 3, 4, 7, 9, 10 und 11 sind **Tims Entscheidungen
/// vom 05.11.2026**; V1, V2 und V7 hat der Planende formuliert und Tim am
/// 05.11.2026 übernommen.
///
/// - **Entscheidung 3:** Eine Portion nur mit Angabe in g oder ml. Genau
///   100 entfällt (Bezugsgröße). Gleich der Packung → nur die Packung.
///   Größer als die Packung → die Portion entfällt.
/// - **Entscheidung 4:** Packung nur aus `product_quantity` mit Einheit g
///   oder ml.
/// - **Entscheidung 10:** `fluessig`, wenn `product_quantity_unit` oder
///   `serving_quantity_unit` gleich `ml` ist.
/// - **V1:** Verschiedene Einheiten bei Portion und Packung → die Portion
///   entfällt, die Packung bleibt. Steht nur eine Angabe da, gilt die
///   Regel nicht.
/// - **V2:** „Genau 100", „gleich" und „größer" mit Toleranz 0,01.
/// - **V7:** + addiert 1, − zieht 1 ab und nie unter 1; bei Anzahl ≤ 1
///   ist − gesperrt. Die Anzahl aus der Vorwahl ist `menge_g / portion_g`,
///   auf zwei Nachkommastellen gerundet.
/// - **Vorwahl** (Spec, Abschnitt „Vorwahl"): Gibt es die `portion_id` des
///   jüngsten Eintrags noch, wird diese Portion samt Anzahl vorgewählt
///   (Entscheidung 7), sonst „g" mit seiner Menge, ohne Eintrag „g" mit
///   100.
///
/// Die Pflichtfälle stehen im Plan, Task 2, Step 1.
///
/// ## Festlegungen des Test-Agenten — nicht von Tim freigegeben
///
/// - **Eine Packung mit Menge 0, negativ oder `null` ist keine Packung.**
///   Die Spec sagt es für die Packung nicht wörtlich; sie sagt es für
///   gespeicherte Portionen („eine Portion ohne Gramm ist keine") und
///   zählt im Befund nur `product_quantity > 0`.
/// - **Einheiten außer g und ml sind keine** — auch `kg` und `l` nicht.
///   Entscheidung 4 sagt „g oder ml"; OFF rechnet `product_quantity`
///   selbst auf g bzw. ml um. Umgerechnet wird nicht.
/// - **`fluessig` hängt nur an der rohen Einheit**, auch wenn die Menge
///   dazu fehlt (Entscheidung 10 nennt nur die Einheit). Fall
///   „Packungseinheit ml ohne Menge".
/// - **`anzahlMinus(1.9) == 1`.** „Nie unter 1" ist hier als Begrenzung
///   gelesen, nicht als Sperre: gesperrt ist − erst ab Anzahl ≤ 1.
/// - **Gerundet wird die Vorwahl-Anzahl auch dann**, wenn sie über
///   `portionsVorwahl` entsteht (`10 g / 3 g` → `3.33`).
/// - **Toleranzgrenzen werden nur mit deutlichem Abstand geprüft**
///   (0,001 bzw. 0,004 drinnen, 0,02 draußen), nicht genau bei 0,01 —
///   ob „<" oder „≤", legt diese Datei nicht fest.
///
/// Alle Zahlen sind erfunden.
void main() {
  const portion = OffPortionsArt.portion;
  const packung = OffPortionsArt.packung;

  OffPortion p(double menge) => OffPortion(art: portion, menge: menge);
  OffPortion pk(double menge) => OffPortion(art: packung, menge: menge);

  // ═════════════════════════════════════════════════════════════════════
  group('offPortionen — welche Angaben eine Portion werden', () {
    test('Portion 5,8 g und Packung 225 g → beide, aufsteigend', () {
      final a = offPortionen(
        portionMenge: 5.8,
        portionEinheit: 'g',
        packungMenge: 225,
        packungEinheit: 'g',
      );

      expect(a.fluessig, isFalse);
      expect(a.portionen, [p(5.8), pk(225)]);
    });

    test('Packung zuerst übergeben ändert die Reihenfolge nicht', () {
      // Benannte Parameter haben keine Reihenfolge — aber eine
      // Implementierung, die die Packung zuerst einsortiert, fiele hier
      // auf.
      final a = offPortionen(
        packungEinheit: 'g',
        packungMenge: 225,
        portionEinheit: 'g',
        portionMenge: 5.8,
      );

      expect(a.portionen.map((x) => x.art), [portion, packung]);
    });

    test('Portion genau 100 g entfällt, die Packung bleibt (E3)', () {
      final a = offPortionen(
        portionMenge: 100,
        portionEinheit: 'g',
        packungMenge: 400,
        packungEinheit: 'g',
      );

      expect(a.portionen, [pk(400)], reason: '100 ist die Bezugsgröße');
    });

    test('Portion 99,999 g gilt als 100 und entfällt (V2)', () {
      final a = offPortionen(
        portionMenge: 99.999,
        portionEinheit: 'g',
        packungMenge: 400,
        packungEinheit: 'g',
      );

      expect(a.portionen, [pk(400)]);
    });

    test('Portion 100,004 g gilt als 100 und entfällt (V2)', () {
      final a = offPortionen(
        portionMenge: 100.004,
        portionEinheit: 'g',
        packungMenge: 400,
        packungEinheit: 'g',
      );

      expect(a.portionen, [pk(400)]);
    });

    test('Portion 99,98 g ist nicht 100 und bleibt', () {
      final a = offPortionen(
        portionMenge: 99.98,
        portionEinheit: 'g',
        packungMenge: 400,
        packungEinheit: 'g',
      );

      expect(a.portionen, [p(99.98), pk(400)]);
    });

    test('Portion genau 100 ml entfällt ebenso', () {
      final a = offPortionen(
        portionMenge: 100,
        portionEinheit: 'ml',
        packungMenge: 1000,
        packungEinheit: 'ml',
      );

      expect(a.portionen, [pk(1000)]);
    });

    test('Portion 100 g ohne Packung entfällt — es bleibt nichts', () {
      final a = offPortionen(portionMenge: 100, portionEinheit: 'g');

      expect(a.portionen, isEmpty);
    });

    test('Portion gleich der Packung (150 = 150) → nur die Packung (E3)', () {
      final a = offPortionen(
        portionMenge: 150,
        portionEinheit: 'g',
        packungMenge: 150,
        packungEinheit: 'g',
      );

      expect(a.portionen, [pk(150)]);
    });

    test('Portion 150,004 gegen Packung 150 gilt als gleich (V2)', () {
      final a = offPortionen(
        portionMenge: 150.004,
        portionEinheit: 'g',
        packungMenge: 150,
        packungEinheit: 'g',
      );

      expect(a.portionen, [pk(150)]);
    });

    test('Portion 149,98 gegen Packung 150 ist nicht gleich und bleibt', () {
      final a = offPortionen(
        portionMenge: 149.98,
        portionEinheit: 'g',
        packungMenge: 150,
        packungEinheit: 'g',
      );

      expect(a.portionen, [p(149.98), pk(150)]);
    });

    test('Portion 300 g größer als Packung 250 g → nur die Packung (E3)', () {
      final a = offPortionen(
        portionMenge: 300,
        portionEinheit: 'g',
        packungMenge: 250,
        packungEinheit: 'g',
      );

      expect(a.portionen, [pk(250)]);
    });

    test(
      'Portion 30 g, Packung 500 ml → nur die Packung, flüssig (V1, E10)',
      () {
        final a = offPortionen(
          portionMenge: 30,
          portionEinheit: 'g',
          packungMenge: 500,
          packungEinheit: 'ml',
        );

        expect(a.portionen, [
          pk(500),
        ], reason: 'ein Vergleich über zwei Einheiten wäre geraten');
        expect(a.fluessig, isTrue);
      },
    );

    test('Portion 250 ml, Packung 500 g → nur die Packung, flüssig (V1)', () {
      final a = offPortionen(
        portionMenge: 250,
        portionEinheit: 'ml',
        packungMenge: 500,
        packungEinheit: 'g',
      );

      expect(a.portionen, [pk(500)]);
      expect(
        a.fluessig,
        isTrue,
        reason: 'E10: eine der beiden Einheiten ist ml',
      );
    });

    test('Portion 250 ml ohne Packung bleibt — V1 braucht beide Angaben', () {
      final a = offPortionen(portionMenge: 250, portionEinheit: 'ml');

      expect(a.portionen, [p(250)]);
      expect(a.fluessig, isTrue);
    });

    test('Portion 250 ml, Packung 1000 ml → beide, flüssig', () {
      final a = offPortionen(
        portionMenge: 250,
        portionEinheit: 'ml',
        packungMenge: 1000,
        packungEinheit: 'ml',
      );

      expect(a.portionen, [p(250), pk(1000)]);
      expect(a.fluessig, isTrue);
    });

    group('keine Portion, die Packung bleibt', () {
      final faelle = <String, ({double? menge, String? einheit})>{
        'Portion ohne Einheit': (menge: 30, einheit: null),
        'Portion mit Einheit „stück"': (menge: 30, einheit: 'stück'),
        'Portion mit leerer Einheit': (menge: 30, einheit: ''),
        'Portion mit Menge 0': (menge: 0, einheit: 'g'),
        'Portion mit negativer Menge': (menge: -5, einheit: 'g'),
        'Portion mit Menge null': (menge: null, einheit: 'g'),
        'Portion in kg (Festlegung des Test-Agenten)': (
          menge: 0.03,
          einheit: 'kg',
        ),
      };

      for (final MapEntry(key: name, value: f) in faelle.entries) {
        test(name, () {
          final a = offPortionen(
            portionMenge: f.menge,
            portionEinheit: f.einheit,
            packungMenge: 225,
            packungEinheit: 'g',
          );

          expect(a.portionen, [pk(225)]);
          expect(a.fluessig, isFalse);
        });
      }
    });

    group('keine Packung, die Portion bleibt — ohne Vergleich', () {
      // Die Portion ist absichtlich **größer** als die Packungsmenge: Wird
      // die Packung verworfen, darf sie die Portion nicht mitreißen.
      final faelle = <String, ({double? menge, String? einheit})>{
        'Packung ohne Einheit': (menge: 250, einheit: null),
        'Packung mit Einheit „stück"': (menge: 250, einheit: 'stück'),
        'Packung in l (Festlegung des Test-Agenten)': (
          menge: 0.25,
          einheit: 'l',
        ),
        'Packung mit Menge 0 (Festlegung des Test-Agenten)': (
          menge: 0,
          einheit: 'g',
        ),
        'Packung mit negativer Menge (Festlegung des Test-Agenten)': (
          menge: -250,
          einheit: 'g',
        ),
        'Packung mit Menge null': (menge: null, einheit: 'g'),
      };

      for (final MapEntry(key: name, value: f) in faelle.entries) {
        test(name, () {
          final a = offPortionen(
            portionMenge: 300,
            portionEinheit: 'g',
            packungMenge: f.menge,
            packungEinheit: f.einheit,
          );

          expect(a.portionen, [p(300)]);
        });
      }
    });

    test('Packung allein → nur die Packung', () {
      final a = offPortionen(packungMenge: 225, packungEinheit: 'g');

      expect(a.portionen, [pk(225)]);
      expect(a.fluessig, isFalse);
    });

    test('Einheit „ ML " gilt als ml — getrimmt, klein geschrieben', () {
      final a = offPortionen(
        portionMenge: 250,
        portionEinheit: ' ML ',
        packungMenge: 1000,
        packungEinheit: 'ml',
      );

      expect(a.portionen, [p(250), pk(1000)]);
      expect(a.fluessig, isTrue);
    });

    test('Einheit „ G" gilt als g', () {
      final a = offPortionen(
        portionMenge: 5.8,
        portionEinheit: 'G',
        packungMenge: 225,
        packungEinheit: ' g',
      );

      expect(a.portionen, [p(5.8), pk(225)]);
      expect(a.fluessig, isFalse);
    });

    test('„ ML " bei der Packung macht flüssig', () {
      final a = offPortionen(packungMenge: 330, packungEinheit: ' ML ');

      expect(a.portionen, [pk(330)]);
      expect(a.fluessig, isTrue);
    });

    test('alles null → nicht flüssig, keine Portionen', () {
      final a = offPortionen();

      expect(a.fluessig, isFalse);
      expect(a.portionen, isEmpty);
      expect(a, OffPortionsAngaben(fluessig: false, portionen: const []));
    });

    group('flüssig hängt an der rohen Einheit, nicht am Ergebnis', () {
      test('Portion 100 ml allein entfällt, flüssig bleibt', () {
        final a = offPortionen(portionMenge: 100, portionEinheit: 'ml');

        expect(a.portionen, isEmpty);
        expect(a.fluessig, isTrue);
      });

      test('Portion 500 ml größer als Packung 330 ml: flüssig', () {
        final a = offPortionen(
          portionMenge: 500,
          portionEinheit: 'ml',
          packungMenge: 330,
          packungEinheit: 'ml',
        );

        expect(a.portionen, [pk(330)]);
        expect(a.fluessig, isTrue);
      });

      test('Portion 250 ml, Packung ohne Einheit: flüssig', () {
        final a = offPortionen(
          portionMenge: 250,
          portionEinheit: 'ml',
          packungMenge: 1000,
        );

        expect(a.portionen, [p(250)]);
        expect(a.fluessig, isTrue);
      });

      test('Packungseinheit ml ohne Menge (Festlegung des Test-Agenten)', () {
        final a = offPortionen(packungEinheit: 'ml');

        expect(a.portionen, isEmpty);
        expect(a.fluessig, isTrue);
      });

      test('Portion mit Menge 0 in ml: keine Portion, aber flüssig', () {
        final a = offPortionen(portionMenge: 0, portionEinheit: 'ml');

        expect(a.portionen, isEmpty);
        expect(a.fluessig, isTrue);
      });
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('portionsVorwahl — was beim Öffnen gewählt ist', () {
    test('ohne letzten Eintrag → g mit 100', () {
      expect(
        portionsVorwahl(letzte: null, vorhandenePortionen: const {}),
        VorwahlGramm(100),
      );
    });

    test('ohne letzten Eintrag, auch wenn Portionen da sind → g mit 100', () {
      expect(
        portionsVorwahl(letzte: null, vorhandenePortionen: const {7, 8}),
        VorwahlGramm(100),
      );
    });

    test('2 Bon zuletzt, Portion 7 vorhanden → Portion 7, Anzahl 2 (E7)', () {
      final v = portionsVorwahl(
        letzte: const LetzteBuchung(mengeG: 11.8, portionId: 7, portionG: 5.9),
        vorhandenePortionen: const {3, 7},
      );

      expect(v, VorwahlPortion(7, 2));
      expect(v, isA<VorwahlPortion>());
      expect(
        (v as VorwahlPortion).anzahl,
        2.0,
        reason:
            '11,8 / 5,9 ist in double 2.0000000000000004 — gerundet '
            'wird auf zwei Nachkommastellen (V7)',
      );
      expect(v.portionId, 7);
    });

    test('dieselbe Buchung, Portion 7 gelöscht → g mit 11,8', () {
      expect(
        portionsVorwahl(
          letzte: const LetzteBuchung(
            mengeG: 11.8,
            portionId: 7,
            portionG: 5.9,
          ),
          vorhandenePortionen: const {3},
        ),
        VorwahlGramm(11.8),
      );
    });

    test('dieselbe Buchung, gar keine Portionen mehr → g mit 11,8', () {
      expect(
        portionsVorwahl(
          letzte: const LetzteBuchung(
            mengeG: 11.8,
            portionId: 7,
            portionG: 5.9,
          ),
          vorhandenePortionen: const {},
        ),
        VorwahlGramm(11.8),
      );
    });

    test('letzte Buchung in g (30 g) → g mit 30 (E7)', () {
      expect(
        portionsVorwahl(
          letzte: const LetzteBuchung(mengeG: 30),
          vorhandenePortionen: const {7},
        ),
        VorwahlGramm(30),
      );
    });

    test('portionG 0 bei gesetzter portionId → g mit der Menge', () {
      expect(
        portionsVorwahl(
          letzte: const LetzteBuchung(mengeG: 30, portionId: 7, portionG: 0),
          vorhandenePortionen: const {7},
        ),
        VorwahlGramm(30),
        reason: 'durch 0 teilen ergäbe Unendlich als Anzahl',
      );
    });

    test('portionG null bei gesetzter portionId → g mit der Menge', () {
      expect(
        portionsVorwahl(
          letzte: const LetzteBuchung(mengeG: 30, portionId: 7),
          vorhandenePortionen: const {7},
        ),
        VorwahlGramm(30),
      );
    });

    test('Schnappschuss ohne portionId (Portion hatte keine Zeile) → g', () {
      // Spec, „eintraege": `portion_id` darf null sein, wenn Name und
      // Gramm gesetzt sind. „Die Vorwahl fällt dann auf g zurück."
      expect(
        portionsVorwahl(
          letzte: const LetzteBuchung(mengeG: 11.8, portionG: 5.9),
          vorhandenePortionen: const {7},
        ),
        VorwahlGramm(11.8),
      );
    });

    test('Anzahl wird auf 0,01 gerundet: 10 g bei 3 g je Portion → 3,33', () {
      expect(
        portionsVorwahl(
          letzte: const LetzteBuchung(mengeG: 10, portionId: 4, portionG: 3),
          vorhandenePortionen: const {4},
        ),
        VorwahlPortion(4, 3.33),
      );
    });

    test('halbe Portion bleibt halbe Portion', () {
      expect(
        portionsVorwahl(
          letzte: const LetzteBuchung(mengeG: 125, portionId: 2, portionG: 250),
          vorhandenePortionen: const {2},
        ),
        VorwahlPortion(2, 0.5),
      );
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Anzahl (E11, V7)', () {
    test('anzahlAus(11,8 g, 5,9 g) ist genau 2', () {
      final n = anzahlAus(mengeG: 11.8, portionG: 5.9);

      expect(n, 2);
      expect(n, 2.0, reason: 'nicht 2.0000000000000004');
    });

    test('anzahlAus(10 g, 3 g) ist 3,33', () {
      expect(anzahlAus(mengeG: 10, portionG: 3), 3.33);
    });

    test('anzahlAus(20 g, 3 g) ist 6,67 — kaufmännisch gerundet', () {
      expect(anzahlAus(mengeG: 20, portionG: 3), 6.67);
    });

    test('anzahlPlus addiert 1', () {
      expect(anzahlPlus(2), 3);
      expect(anzahlPlus(1), 2);
      expect(anzahlPlus(0.5), 1.5);
    });

    test('anzahlMinus zieht 1 ab', () {
      expect(anzahlMinus(3), 2);
      expect(anzahlMinus(2), 1);
      expect(anzahlMinus(1.5), 1);
    });

    test('anzahlMinus geht nie unter 1 (Festlegung: 1,9 → 1)', () {
      expect(anzahlMinus(1.9), 1);
    });

    test('anzahlMinus ist bei 1 gesperrt (null)', () {
      expect(anzahlMinus(1), isNull);
    });

    test('anzahlMinus ist unter 1 gesperrt (0,5 → null)', () {
      expect(anzahlMinus(0.5), isNull);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Wertgleichheit', () {
    test('zwei gleich gebaute OffPortionsAngaben sind gleich', () {
      final a = OffPortionsAngaben(
        fluessig: true,
        portionen: [p(250), pk(1000)],
      );
      final b = OffPortionsAngaben(
        fluessig: true,
        portionen: [p(250), pk(1000)],
      );

      expect(identical(a, b), isFalse);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('dasselbe Ergebnis aus zwei Aufrufen ist gleich', () {
      OffPortionsAngaben lauf() => offPortionen(
        portionMenge: 5.8,
        portionEinheit: 'g',
        packungMenge: 225,
        packungEinheit: 'g',
      );

      expect(lauf(), lauf());
      expect(lauf().hashCode, lauf().hashCode);
    });

    test('OffPortionsAngaben unterscheiden sich an flüssig und Liste', () {
      final basis = OffPortionsAngaben(fluessig: false, portionen: [pk(225)]);

      expect(
        basis,
        isNot(OffPortionsAngaben(fluessig: true, portionen: [pk(225)])),
      );
      expect(
        basis,
        isNot(OffPortionsAngaben(fluessig: false, portionen: [pk(250)])),
      );
      expect(
        basis,
        isNot(OffPortionsAngaben(fluessig: false, portionen: [p(225)])),
      );
      expect(
        basis,
        isNot(OffPortionsAngaben(fluessig: false, portionen: const [])),
      );
    });

    test('OffPortion vergleicht Art und Menge', () {
      expect(p(5.8), p(5.8));
      expect(p(5.8).hashCode, p(5.8).hashCode);
      expect(p(5.8), isNot(pk(5.8)));
      expect(p(5.8), isNot(p(5.9)));
    });

    test('LetzteBuchung vergleicht alle drei Felder', () {
      const a = LetzteBuchung(mengeG: 11.8, portionId: 7, portionG: 5.9);

      expect(a, const LetzteBuchung(mengeG: 11.8, portionId: 7, portionG: 5.9));
      expect(
        a.hashCode,
        const LetzteBuchung(mengeG: 11.8, portionId: 7, portionG: 5.9).hashCode,
      );
      expect(a, isNot(const LetzteBuchung(mengeG: 11.8, portionG: 5.9)));
      expect(a, isNot(const LetzteBuchung(mengeG: 11.8, portionId: 7)));
      expect(
        a,
        isNot(const LetzteBuchung(mengeG: 12, portionId: 7, portionG: 5.9)),
      );
    });

    test('Vorwahlen vergleichen nach Wert', () {
      expect(VorwahlGramm(30), VorwahlGramm(30));
      expect(VorwahlGramm(30).hashCode, VorwahlGramm(30).hashCode);
      expect(VorwahlGramm(30), isNot(VorwahlGramm(31)));

      expect(VorwahlPortion(7, 2), VorwahlPortion(7, 2));
      expect(VorwahlPortion(7, 2).hashCode, VorwahlPortion(7, 2).hashCode);
      expect(VorwahlPortion(7, 2), isNot(VorwahlPortion(8, 2)));
      expect(VorwahlPortion(7, 2), isNot(VorwahlPortion(7, 3)));
    });

    test('die Vorwahl ist ein sealed-Typ mit zwei Fällen', () {
      // Der switch kompiliert nur, wenn er vollständig ist — käme ein
      // dritter Fall dazu, fiele diese Datei am Analyzer auf.
      String art(PortionsVorwahl v) => switch (v) {
        VorwahlGramm() => 'g',
        VorwahlPortion() => 'portion',
      };

      expect(art(VorwahlGramm(100)), 'g');
      expect(art(VorwahlPortion(1, 1)), 'portion');
    });

    test('toString nennt den Inhalt', () {
      for (final o in <Object>[
        p(5.8),
        OffPortionsAngaben(fluessig: false, portionen: [p(5.8)]),
        const LetzteBuchung(mengeG: 11.8, portionId: 7, portionG: 5.9),
        VorwahlGramm(30),
        VorwahlPortion(7, 2),
      ]) {
        expect(o.toString(), isNot(startsWith('Instance of')));
      }
    });
  });
}
