import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repit/design/ringe.dart';

import 'support.dart';

/// Tests für die Runden eines Rings über 100 % (#386).
///
/// Tim am 05.11.2026: Ist ein Ring voll, dreht er eine **zweite Runde**,
/// leicht abgehoben über der ersten, wie bei den Apple-Aktivitätsringen.
/// Die erste Runde bleibt voll, die zweite läuft ab 12 Uhr bis zum
/// Überhang (130 % → 30 % der zweiten Runde), in derselben Farbe, etwas
/// abgesetzt, und ihre Spitze wirft einen weichen Schatten auf die erste.
/// Die Beschriftung bleibt, wie sie ist.
///
/// **Über 200 %** läuft eine dritte Runde, danach ist Schluss: höchstens
/// drei Runden, gedeckelt bei 300 % (Wahl des umsetzenden Agenten, zur
/// Entscheidung bei Tim — nicht entschieden).
///
/// Geprüft wird die Rechnung als reine Funktion — Runden und Überhang je
/// Wert, wo die Spitze mit Schatten sitzt, und dass jede Runde ihren
/// eigenen Ton hat. Das Zeichnen selbst nur so weit, wie es ohne
/// Pixelvergleich geht: Es baut ohne Fehler, und der Vorlesetext bleibt
/// derselbe wie unter 100 %.
///
/// Alle Zahlen sind erfunden.
void main() {
  group('ringRunden — Runden und Überhang je Wert', () {
    test('ohne Wert keine Runde — nicht eine leere Runde auf 0', () {
      expect(ringRunden(null, 1800), isEmpty);
    });

    test('bei 0 keine Runde', () {
      expect(ringRunden(0, 1800), isEmpty);
    });

    test('bei negativem Wert keine Runde', () {
      expect(ringRunden(-5, 1800), isEmpty);
    });

    test('ohne Ziel (0) keine Runde, statt durch 0 zu teilen', () {
      expect(ringRunden(10, 0), isEmpty);
    });

    test('bei 50 % eine halbe erste Runde', () {
      expect(ringRunden(900, 1800), [0.5]);
    });

    test('bei genau 100 % genau eine volle Runde, noch keine zweite', () {
      expect(ringRunden(1800, 1800), [1.0]);
    });

    test('bei 130 % die erste Runde voll und 30 % der zweiten', () {
      final runden = ringRunden(1300, 1000);
      expect(runden, hasLength(2));
      expect(runden[0], 1.0);
      expect(runden[1], closeTo(0.3, 1e-9));
    });

    test('knapp über 100 % springt die zweite Runde schon an', () {
      final runden = ringRunden(1001, 1000);
      expect(runden, hasLength(2));
      expect(runden[1], closeTo(0.001, 1e-9));
    });

    test('bei genau 200 % zwei volle Runden, noch keine dritte', () {
      expect(ringRunden(40, 20), [1.0, 1.0]);
    });

    test('bei 250 % zwei volle Runden und eine halbe dritte', () {
      final runden = ringRunden(50, 20);
      expect(runden, hasLength(3));
      expect(runden[0], 1.0);
      expect(runden[1], 1.0);
      expect(runden[2], closeTo(0.5, 1e-9));
    });

    test('bei genau 300 % drei volle Runden', () {
      expect(ringRunden(60, 20), [1.0, 1.0, 1.0]);
    });

    test('über 300 % gedeckelt: drei volle Runden, keine vierte', () {
      expect(ringRunden(90, 20), [1.0, 1.0, 1.0]);
      expect(ringRunden(10000, 20), hasLength(ringRundenHoechstens));
    });

    test('höchstens drei Runden', () {
      expect(ringRundenHoechstens, 3);
    });
  });

  group('RingZiel.runden', () {
    test('liefert dieselben Runden wie ringRunden aus Wert und Ziel', () {
      const ziel = RingZiel(
        label: 'Fett',
        wert: 93,
        ziel: 62,
        text: '31 g darüber',
        farbe: CupertinoColors.systemGreen,
      );
      final runden = ziel.runden;
      expect(runden, hasLength(2));
      expect(runden[0], 1.0);
      expect(runden[1], closeTo(0.5, 1e-9));
    });

    test('ohne Wert leer', () {
      const ziel = RingZiel(
        label: 'Fett',
        wert: null,
        ziel: 62,
        text: '–/–',
        farbe: CupertinoColors.systemGreen,
      );
      expect(ziel.runden, isEmpty);
    });

    test('ersteRunde und zweiteRunde stimmen mit runden überein', () {
      const ziel = RingZiel(
        label: 'Training',
        wert: 50,
        ziel: 20,
        text: '30 min darüber',
        farbe: CupertinoColors.systemBlue,
      );
      expect(ziel.ersteRunde, ziel.runden[0]);
      expect(ziel.zweiteRunde, ziel.runden[1]);
    });
  });

  group('ringSpitze — wo die abgehobene Spitze ihren Schatten wirft', () {
    test('unter 100 % keine abgehobene Spitze', () {
      expect(ringSpitze(const [0.5]), isNull);
    });

    test('bei genau 100 % keine — es liegt nichts über der ersten Runde', () {
      expect(ringSpitze(const [1.0]), isNull);
    });

    test('ohne Runden keine', () {
      expect(ringSpitze(const []), isNull);
    });

    test('bei 130 % sitzt sie bei 30 % des Umlaufs', () {
      expect(ringSpitze(ringRunden(1300, 1000)), closeTo(0.3, 1e-9));
    });

    test('bei 250 % sitzt sie am Ende der dritten Runde, bei 50 %', () {
      expect(ringSpitze(ringRunden(50, 20)), closeTo(0.5, 1e-9));
    });

    test('bei genau 200 % sitzt sie oben, bei einem vollen Umlauf', () {
      expect(ringSpitze(ringRunden(40, 20)), 1.0);
    });
  });

  group('ringRundenFarbe — jede Runde in derselben Farbe, etwas abgesetzt', () {
    const basis = Color(0xFF34C759);

    test('die erste Runde trägt die Farbe unverändert', () {
      expect(ringRundenFarbe(basis, 0), basis);
    });

    test('die zweite Runde weicht sichtbar ab, im selben Farbton', () {
      final zweite = ringRundenFarbe(basis, 1);
      expect(zweite, isNot(basis));
      expect(
        HSLColor.fromColor(zweite).hue,
        closeTo(HSLColor.fromColor(basis).hue, 3),
      );
    });

    test('die dritte Runde weicht von der zweiten ab, im selben Farbton', () {
      final zweite = ringRundenFarbe(basis, 1);
      final dritte = ringRundenFarbe(basis, 2);
      expect(dritte, isNot(zweite));
      expect(dritte, isNot(basis));
      expect(
        HSLColor.fromColor(dritte).hue,
        closeTo(HSLColor.fromColor(basis).hue, 3),
      );
    });

    test('die Deckkraft bleibt voll — die Runde darunter scheint nicht '
        'durch', () {
      expect(ringRundenFarbe(basis, 1).a, 1.0);
      expect(ringRundenFarbe(basis, 2).a, 1.0);
    });
  });

  group('Ringe über 100 % (Widget)', () {
    testWidgets('baut ohne Fehler mit zwei und drei Runden und gedeckelt, '
        'groß wie klein', (tester) async {
      const ziele = [
        RingZiel(
          label: 'Eiweiß',
          wert: 130,
          ziel: 100,
          text: '30 g darüber',
          farbe: CupertinoColors.systemPurple,
        ),
        RingZiel(
          label: 'Kohlenhydrate',
          wert: 250,
          ziel: 100,
          text: '150 g darüber',
          farbe: CupertinoColors.systemBlue,
        ),
        RingZiel(
          label: 'Fett',
          wert: 900,
          ziel: 100,
          text: '800 g darüber',
          farbe: CupertinoColors.systemGreen,
        ),
      ];
      await tester.pumpWidget(
        huelle(
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Ringe(ziele),
              Ringe(ziele, durchmesser: 44, strichstaerke: 5),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(Ringe), findsNWidgets(2));
    });

    testWidgets('der Vorlesetext nennt über 100 % weiter die Beschriftung, '
        'keine Runden', (tester) async {
      await tester.pumpWidget(
        huelle(
          const Ringe([
            RingZiel(
              label: 'Fett',
              wert: 93,
              ziel: 62,
              text: '31 g darüber',
              farbe: CupertinoColors.systemGreen,
            ),
          ]),
        ),
      );
      expect(find.bySemanticsLabel('Fett 31 g darüber'), findsOneWidget);
    });
  });
}
