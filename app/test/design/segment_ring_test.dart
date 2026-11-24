import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repit/design/segment_ring.dart';

import 'support.dart';

/// Tests für den **zweiten** Ring-Baustein: `RingAbschnitt`,
/// `RingGeometrie` und `SegmentRing` (Ticket #114, Spec
/// `2026-10-26-erholung-flutter-design.md` Abschnitt 5).
///
/// `lib/design/ringe.dart` bleibt unangetastet — der zeichnet
/// **konzentrische** Ringe mit zweiter Runde bei Übererfüllung. Hier geht es
/// um **einen** Kreis, in **Segmente** geteilt, ohne zweite Runde: ein
/// Baustein daneben, kein Umbau.
///
/// ## Die öffentliche API, die diese Datei festschreibt
///
/// ```dart
/// class RingAbschnitt {
///   const RingAbschnitt({
///     required double anteil,      // Anteil am ganzen Kreis, alle zusammen 1
///     required double fuellung,    // 0..1 *innerhalb* des eigenen Anteils
///     required Color farbe,        // Palette-Eintrag, unaufgelöst
///     bool hatGrundlage = true,    // false → gestrichelt
///   });
/// }
///
/// class RingGeometrie {
///   const RingGeometrie(List<RingAbschnitt> abschnitte);
///   static const double luecke = 0.014;            // Umdrehungen
///   static const double fuellSchwelle = 0.02;
///   static const double drehung = -math.pi / 2;    // −90°
///   double start(int index);        // Umdrehungen, Summe der Anteile davor
///   double laenge(int index);       // Umdrehungen, Anteil minus Lücke
///   double fuellLaenge(int index);  // Umdrehungen, 0 ohne Grundlage
///   bool gestrichelt(int index);
/// }
///
/// class SegmentRing extends StatelessWidget {
///   const SegmentRing({
///     super.key,
///     required List<RingAbschnitt> abschnitte,
///     required String mitte,
///     required String caption,
///     double durchmesser = 92,
///   });
/// }
/// ```
///
/// **Warum die Geometrie eine eigene, reine Klasse ist und keine private
/// Rechnung im Painter:** Die vier Regeln aus `RecoveryRings.swift`
/// (`RingGauge`, Z. 20–70) sollen unverändert übernommen werden —
/// Startwinkel als Summe der Anteile davor, 0,014 Umdrehungen Lücke,
/// −90°-Drehung, Füllung erst ab 2 %. Prüfen lässt sich das nur an Zahlen;
/// alles andere wäre ein Pixelvergleich, und Pixel sind hier ausdrücklich
/// nicht zu testen (#114, „Fertig, wenn"). Der Painter **muss** diese
/// Klasse benutzen: `winkel = RingGeometrie.drehung + 2π · start(i)`,
/// Bogenlänge `2π · laenge(i)` bzw. `2π · fuellLaenge(i)`.
///
/// **Die wichtigste Zeile des Tickets** steht als eigener Test weiter unten:
/// Ein Abschnitt ohne Datengrundlage wird **gestrichelt** gezeichnet, nicht
/// nur blass. Ein durchgehender blasser Bogen sieht aus wie null Punkte und
/// behauptet damit ein schlechtes Ergebnis, das niemand gemessen hat.
/// Testbar ist davon die Entscheidung (`gestrichelt(i)`), nicht der Strich
/// selbst — dass der Painter daraus wirklich Striche macht, bleibt eine
/// Sichtprüfung im Simulator. Deshalb gehört die Entscheidung in die reine
/// Schicht und nicht in eine `if`-Abfrage mitten im `paint`.
///
/// Alle Zahlen hier sind erfunden.
void main() {
  // Der Schlaf-Ring: drei Segmente, Anteile 50/30/20.
  const dreiSegmente = [
    RingAbschnitt(anteil: 0.5, fuellung: 0.8, farbe: CupertinoColors.systemBlue),
    RingAbschnitt(anteil: 0.3, fuellung: 0.5, farbe: CupertinoColors.systemGreen),
    RingAbschnitt(anteil: 0.2, fuellung: 0.25, farbe: CupertinoColors.systemRed),
  ];

  group('RingGeometrie — Startwinkel und Lücke', () {
    test('der Startwinkel ist die Summe der Anteile aller Abschnitte davor', () {
      const geometrie = RingGeometrie(dreiSegmente);

      expect(geometrie.start(0), 0);
      expect(geometrie.start(1), closeTo(0.5, 1e-12));
      expect(geometrie.start(2), closeTo(0.8, 1e-12));
    });

    test('zwischen zwei Abschnitten bleiben 0,014 Umdrehungen Lücke', () {
      const geometrie = RingGeometrie(dreiSegmente);

      expect(geometrie.laenge(0), closeTo(0.5 - 0.014, 1e-12));
      expect(geometrie.laenge(1), closeTo(0.3 - 0.014, 1e-12));
      expect(geometrie.laenge(2), closeTo(0.2 - 0.014, 1e-12));
    });

    // Der leere Schlaf-Ring ist **ein** Segment über den ganzen Kreis. Mit
    // Lücke wäre er ein Kreis mit einem Schlitz — ein Zeichen, das nichts
    // bedeutet.
    test('bei einem einzigen Abschnitt bleibt keine Lücke — der Kreis ist ganz', () {
      const geometrie = RingGeometrie([
        RingAbschnitt(
          anteil: 1,
          fuellung: 0,
          farbe: CupertinoColors.systemGrey,
          hatGrundlage: false,
        ),
      ]);

      expect(geometrie.laenge(0), 1);
    });

    test('ein Abschnitt, der kleiner als die Lücke ist, wird nicht negativ', () {
      const geometrie = RingGeometrie([
        RingAbschnitt(anteil: 0.01, fuellung: 1, farbe: CupertinoColors.systemBlue),
        RingAbschnitt(anteil: 0.99, fuellung: 1, farbe: CupertinoColors.systemGreen),
      ]);

      expect(geometrie.laenge(0), 0);
    });

    test('der ganze Kreis ist um eine Vierteldrehung nach links gedreht, '
        'damit oben angefangen wird', () {
      expect(RingGeometrie.drehung, closeTo(-math.pi / 2, 1e-12));
    });
  });

  group('RingGeometrie — die Füllung', () {
    RingGeometrie mitFuellung(double fuellung, {bool hatGrundlage = true}) {
      return RingGeometrie([
        RingAbschnitt(
          anteil: 1,
          fuellung: fuellung,
          farbe: CupertinoColors.systemBlue,
          hatGrundlage: hatGrundlage,
        ),
      ]);
    }

    test('füllt gar nicht bei 0', () {
      expect(mitFuellung(0).fuellLaenge(0), 0);
    });

    // Grenzwert aus `RingGauge`: `segment.fill > 0.02`. Genau 2 % ist noch
    // nichts — ein Strichlein, das kürzer als die runde Kappe ist, sähe aus
    // wie ein Punkt und nicht wie „fast nichts".
    test('füllt bei genau 2 % noch nicht', () {
      expect(mitFuellung(0.02).fuellLaenge(0), 0);
    });

    test('füllt knapp über 2 % wirklich', () {
      final geometrie = mitFuellung(0.021);

      expect(geometrie.fuellLaenge(0), greaterThan(0));
      expect(geometrie.fuellLaenge(0), closeTo(geometrie.laenge(0) * 0.021, 1e-12));
    });

    test('füllt anteilig am eigenen Abschnitt, nicht am ganzen Kreis', () {
      const geometrie = RingGeometrie(dreiSegmente);

      expect(geometrie.fuellLaenge(0), closeTo(geometrie.laenge(0) * 0.8, 1e-12));
      expect(geometrie.fuellLaenge(1), closeTo(geometrie.laenge(1) * 0.5, 1e-12));
    });

    test('deckelt bei 100 % — keine zweite Runde wie bei den Tagesringen', () {
      final geometrie = mitFuellung(1.4);

      expect(geometrie.fuellLaenge(0), closeTo(geometrie.laenge(0), 1e-12));
    });

    test('wird bei einer negativen Füllung nicht negativ', () {
      expect(mitFuellung(-0.5).fuellLaenge(0), 0);
    });

    // Ohne Datengrundlage gibt es nichts zu füllen — selbst wenn jemand eine
    // Füllung übergibt. Sonst stünde über dem gestrichelten Bogen ein
    // kräftiger, der eine Messung behauptet.
    test('füllt einen Abschnitt ohne Datengrundlage nicht', () {
      expect(mitFuellung(0.9, hatGrundlage: false).fuellLaenge(0), 0);
    });
  });

  group('RingGeometrie — gestrichelt statt blass', () {
    test('ein Abschnitt ohne Datengrundlage wird gestrichelt, ein gemessener '
        'durchgezogen', () {
      const geometrie = RingGeometrie([
        RingAbschnitt(anteil: 0.5, fuellung: 0.7, farbe: CupertinoColors.systemBlue),
        RingAbschnitt(
          anteil: 0.3,
          fuellung: 0,
          farbe: CupertinoColors.systemGreen,
          hatGrundlage: false,
        ),
        RingAbschnitt(anteil: 0.2, fuellung: 0.4, farbe: CupertinoColors.systemRed),
      ]);

      expect(geometrie.gestrichelt(0), isFalse);
      expect(geometrie.gestrichelt(1), isTrue);
      expect(geometrie.gestrichelt(2), isFalse);
    });

    // Ein gemessener, aber leerer Abschnitt ist etwas anderes als ein
    // ungemessener: null Punkte sind eine Aussage, „nicht gemessen" ist
    // keine. Beide sehen blass aus, nur einer ist gestrichelt.
    test('ein gemessener Abschnitt mit null Punkten bleibt durchgezogen', () {
      const geometrie = RingGeometrie([
        RingAbschnitt(anteil: 1, fuellung: 0, farbe: CupertinoColors.systemBlue),
      ]);

      expect(geometrie.gestrichelt(0), isFalse);
    });
  });

  group('SegmentRing (Widget)', () {
    testWidgets('zeigt Mitte und Caption', (tester) async {
      await tester.pumpWidget(
        huelle(
          const SegmentRing(
            abschnitte: dreiSegmente,
            mitte: '76',
            caption: 'Score',
          ),
        ),
      );

      expect(find.text('76'), findsOneWidget);
      expect(find.text('Score'), findsOneWidget);
    });

    testWidgets('baut den leeren Ring — ein graues Segment über den ganzen '
        'Kreis, Mitte "—"', (tester) async {
      await tester.pumpWidget(
        huelle(
          const SegmentRing(
            abschnitte: [
              RingAbschnitt(
                anteil: 1,
                fuellung: 0,
                farbe: CupertinoColors.systemGrey,
                hatGrundlage: false,
              ),
            ],
            mitte: '—',
            caption: 'kein Wert',
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('—'), findsOneWidget);
      expect(find.text('kein Wert'), findsOneWidget);
    });

    testWidgets('baut drei Abschnitte, von denen einer keine Grundlage hat, '
        'ohne Fehler', (tester) async {
      await tester.pumpWidget(
        huelle(
          const SegmentRing(
            abschnitte: [
              RingAbschnitt(anteil: 0.5, fuellung: 0.7, farbe: CupertinoColors.systemBlue),
              RingAbschnitt(
                anteil: 0.3,
                fuellung: 0,
                farbe: CupertinoColors.systemGreen,
                hatGrundlage: false,
              ),
              RingAbschnitt(anteil: 0.2, fuellung: 0.4, farbe: CupertinoColors.systemRed),
            ],
            mitte: '48',
            caption: 'von 70',
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('von 70'), findsOneWidget);
    });

    testWidgets('baut auch ohne Abschnitte, statt beim Zeichnen zu scheitern', (
      tester,
    ) async {
      await tester.pumpWidget(
        huelle(const SegmentRing(abschnitte: [], mitte: '—', caption: 'kein Wert')),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('nimmt einen abweichenden Durchmesser entgegen', (tester) async {
      await tester.pumpWidget(
        huelle(
          const SegmentRing(
            abschnitte: dreiSegmente,
            mitte: '76',
            caption: 'Score',
            durchmesser: 64,
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(SegmentRing), findsOneWidget);
    });
  });
}
