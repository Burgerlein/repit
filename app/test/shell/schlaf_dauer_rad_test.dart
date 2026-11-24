import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repit/shell/schlaf_eintragen.dart';

/// Tests für das **Dauer-Rad im Formular „von Hand eintragen"** (#210) —
/// `lib/shell/schlaf_eintragen.dart`.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung**
/// (`CLAUDE.md`). Diese Datei darf ausgeführt, nie verändert werden.
///
/// ## Der Befund
///
/// Tim, 02.11.2026, auf dem Gerät: „wenn ich 19 - 20 uhr auswähle steht
/// unten immer noch 7:30 stunden". Die Zeilenbeschriftung über dem Rad
/// rechnete richtig, das Rad selbst blieb auf der Vorgabe 23:00–06:30
/// stehen. Rad und Text sagten Verschiedenes — und weil das Rad beim
/// nächsten Anfassen seinen eigenen, veralteten Stand zurückmeldet, wurde
/// ab da auch falsch gesichert.
///
/// ## Zwei Richtungen, und die zweite ist die schwierigere
///
/// 1. **Von außen:** Ändern sich die Uhrzeiten, folgt das Rad der neuen
///    Rechnung.
/// 2. **Von innen:** Dreht der Nutzer am Rad, bleibt es stehen, wo er es
///    hinlegt — es darf **nicht** mitten in der Geste neu aufgebaut
///    werden. Eine naive Lösung, die den Picker an der gerade gezeigten
///    Dauer aufhängt, fällt genau hier um: Das Rad rastet nach der ersten
///    Raste neu ein und bleibt zurück.
///
/// Geprüft wird beides am **sichtbaren Stand des Rades**
/// (`FixedExtentScrollController.selectedItem` der beiden Wheels), nicht
/// an einem Schlüssel oder einem Feld der Implementierung: Wie der Picker
/// dazu gebracht wird, mitzugehen, ist seine Sache.
///
/// **Rad und Zeile müssen dasselbe sagen.** Die Zeile über dem Rad zeigt
/// dieselbe Zahl, die beim Sichern abgelegt wird; stimmen Rad und Zeile
/// überein, stimmt auch der gesicherte Wert. Deshalb kommt diese Datei
/// ohne Ablage aus.
void main() {
  // Ein Rastermaß des Cupertino-Rades. Es steht hier, weil die Gesten
  // unten in Rasten rechnen, nicht in Pixeln.
  const rasterHoehe = 32.0;

  Finder raeder(Finder rad) =>
      find.descendant(of: rad, matching: find.byType(ListWheelScrollView));

  /// Die eingerastete Stelle eines Rades — das, was in der Mitte steht.
  int stelle(WidgetTester tester, Finder wheel) {
    final w = tester.widget<ListWheelScrollView>(wheel);
    return (w.controller! as FixedExtentScrollController).selectedItem;
  }

  /// Das Dauer-Rad, abgelesen in Minuten. Stundenrad mal 60, Minutenrad
  /// mal 5 (`minuteInterval: 5`); der Rest schützt vor einem umlaufenden
  /// Rad.
  int dauerAmRad(WidgetTester tester) {
    final rad = find.byType(CupertinoTimerPicker);
    expect(rad, findsOneWidget);
    return stelle(tester, raeder(rad).at(0)) % 24 * 60 +
        stelle(tester, raeder(rad).at(1)) % 12 * 5;
  }

  /// Die Zeile über dem Rad, als Minuten. Sie steht als „7:30 h" da.
  int dauerInDerZeile(WidgetTester tester) {
    final treffer = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .whereType<String>()
        .where((t) => RegExp(r'^\d+:\d\d h$').hasMatch(t))
        .toList();
    expect(treffer, hasLength(1), reason: 'genau eine Dauerzeile');
    final teile = treffer.single.split(RegExp('[: ]'));
    return int.parse(teile[0]) * 60 + int.parse(teile[1]);
  }

  Future<void> oeffne(
    WidgetTester tester, {
    SchlafEintragenArt art = SchlafEintragenArt.nacht,
  }) async {
    // Hoch genug, dass beide Zeitenräder und das Dauer-Rad gleichzeitig
    // dastehen: Sonst müsste jede Geste erst scrollen, und ein Scrollen
    // über einem Rad ist genau die Geste, die hier geprüft wird.
    tester.view.physicalSize = const Size(800 * 3, 1600 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: CupertinoApp(
          home: Builder(
            builder: (context) => CupertinoButton(
              key: const Key('oeffne'),
              onPressed: () => zeigeSchlafEintragen(
                context,
                art: art,
                tag: DateTime.utc(2026, 10, 29),
              ),
              child: const Text('auf'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('oeffne')));
    await tester.pumpAndSettle();
  }

  /// Dreht ein Rad um [rasten] Stellen (negativ = zurück).
  ///
  /// Nicht `tester.drag`: Dort springt der Stand in einem einzigen Zug um,
  /// und genau die Zwischenmeldungen, an denen eine zu eifrige Lösung den
  /// Picker neu aufbaut, fielen weg. Hier kommt die Geste in kleinen
  /// Schritten mit Pumps dazwischen — so, wie ein Finger sie macht. Am
  /// Ende steht sie kurz still, damit kein Schwung übrig bleibt und das
  /// Rad dorthin einrastet, wo es hingelegt wurde.
  Future<void> drehe(WidgetTester tester, Finder wheel, int rasten) async {
    final schritte = rasten.abs() * 2;
    final weite = rasten.sign * rasterHoehe / 2;

    final geste = await tester.startGesture(tester.getCenter(wheel));
    // Der erste Schritt überwindet den Schwellwert der Geste.
    await geste.moveBy(Offset(0, -rasten.sign.toDouble()));
    await tester.pump(const Duration(milliseconds: 16));
    for (var i = 0; i < schritte; i++) {
      await geste.moveBy(Offset(0, -weite));
      await tester.pump(const Duration(milliseconds: 16));
    }
    for (var i = 0; i < 5; i++) {
      await geste.moveBy(Offset.zero);
      await tester.pump(const Duration(milliseconds: 50));
    }
    await geste.up();
    await tester.pumpAndSettle();
  }

  /// Stellt die beiden Uhrzeitenräder auf 19:00 und 20:00.
  ///
  /// Vorgabe der Nacht ist 23:00–06:30; das sind vier Stunden zurück am
  /// ersten Rad und vierzehn Stunden vor plus sechs Fünf-Minuten-Rasten
  /// zurück am zweiten.
  Future<void> stelleAufNeunzehnBisZwanzig(WidgetTester tester) async {
    final beginn = find.byType(CupertinoDatePicker).at(0);
    final ende = find.byType(CupertinoDatePicker).at(1);

    await drehe(tester, raeder(beginn).at(0), -4);
    await drehe(tester, raeder(ende).at(0), 14);
    await drehe(tester, raeder(ende).at(1), -6);

    expect(stelle(tester, raeder(beginn).at(0)) % 24, 19);
    expect(stelle(tester, raeder(ende).at(0)) % 24, 20);
    expect(stelle(tester, raeder(ende).at(1)) % 12, 0);
  }

  group('Das Rad folgt der Rechnung, wenn sich die Zeiten ändern', () {
    testWidgets('die Vorgabe 23:00–06:30 steht als 7:30 am Rad', (
      tester,
    ) async {
      await oeffne(tester);

      expect(dauerAmRad(tester), 7 * 60 + 30);
      expect(dauerInDerZeile(tester), 7 * 60 + 30);
    });

    testWidgets('19:00–20:00 macht daraus 1:00 — am Rad, nicht nur im Text', (
      tester,
    ) async {
      await oeffne(tester);
      await stelleAufNeunzehnBisZwanzig(tester);

      expect(
        dauerInDerZeile(tester),
        60,
        reason: 'die Zeile rechnete schon immer richtig',
      );
      expect(
        dauerAmRad(tester),
        60,
        reason: 'genau der Befund aus #210: das Rad blieb auf 7:30 stehen',
      );
    });

    testWidgets('über Mitternacht zählt es weiter — 23:00–07:30 sind 8:30', (
      tester,
    ) async {
      await oeffne(tester);
      final ende = find.byType(CupertinoDatePicker).at(1);
      // 06:30 → 07:30: eine Stunde mehr Schlaf über Mitternacht hinweg.
      await drehe(tester, raeder(ende).at(0), 1);

      expect(dauerAmRad(tester), 8 * 60 + 30);
      expect(dauerInDerZeile(tester), 8 * 60 + 30);
    });
  });

  group('Beim Drehen springt das Rad nicht zurück', () {
    testWidgets('fünf Rasten am Minutenrad bleiben fünf Rasten — nicht eine', (
      tester,
    ) async {
      await oeffne(tester);
      final rad = find.byType(CupertinoTimerPicker);

      await drehe(tester, raeder(rad).at(1), 5);

      expect(
        dauerAmRad(tester),
        7 * 60 + 55,
        reason:
            'wird der Picker mitten in der Geste neu aufgebaut, rastet '
            'er nach der ersten Raste ein und bleibt bei 7:35 stehen',
      );
      expect(
        dauerInDerZeile(tester),
        7 * 60 + 55,
        reason: 'Rad und Zeile sagen dasselbe — und das wird gesichert',
      );
    });

    testWidgets('auch am Stundenrad', (tester) async {
      await oeffne(tester);
      final rad = find.byType(CupertinoTimerPicker);

      await drehe(tester, raeder(rad).at(0), -3);

      expect(dauerAmRad(tester), 4 * 60 + 30);
      expect(dauerInDerZeile(tester), 4 * 60 + 30);
    });

    testWidgets(
      'und danach nimmt eine Änderung der Zeiten die Hand wieder zurück',
      (tester) async {
        await oeffne(tester);
        final rad = find.byType(CupertinoTimerPicker);

        await drehe(tester, raeder(rad).at(1), 5);
        expect(dauerAmRad(tester), 7 * 60 + 55);

        await stelleAufNeunzehnBisZwanzig(tester);

        expect(
          dauerAmRad(tester),
          60,
          reason:
              'die überschriebene Dauer fällt weg, sobald die Zeiten sich '
              'ändern — das Rad geht mit',
        );
        expect(dauerInDerZeile(tester), 60);
      },
    );
  });

  group('Das Nickerchen hat dieselbe Mechanik mit anderen Vorgaben', () {
    testWidgets('13:30–14:00 stehen als 0:30 am Rad', (tester) async {
      await oeffne(tester, art: SchlafEintragenArt.tagschlaf);

      expect(dauerAmRad(tester), 30);
      expect(dauerInDerZeile(tester), 30);
    });

    testWidgets('eine halbe Stunde später aufgewacht macht 1:00', (
      tester,
    ) async {
      await oeffne(tester, art: SchlafEintragenArt.tagschlaf);
      final ende = find.byType(CupertinoDatePicker).at(1);

      // 14:00 → 15:00.
      await drehe(tester, raeder(ende).at(0), 1);

      expect(dauerAmRad(tester), 90);
      expect(dauerInDerZeile(tester), 90);
    });
  });
}
