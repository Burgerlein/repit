// Die Verlaufslinie der Zahlen-Kacheln zeigt nur die letzte Woche (#510).
//
// Tim, 16.11.2026: „nur eine Woche zurück zeigen, dann sind die besser zu
// lesen." Das Rechenfenster bleibt 30 Tage — es trägt auch „vor N Tagen
// gemessen" und den Gewichtswert selbst —, aber die Linie nimmt davon nur
// die letzten sieben Kalendertage, heute eingeschlossen.
//
// Begrenzt wird nach **Tagen**, nicht nach Punkten: Bei lückigem Gewicht
// wären „die letzten 7 Werte" sonst ein Monat, und genau die Kleinteiligkeit
// wollte Tim los sein.
//
// Alle Zahlen und Tage erfunden.
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repit/design/kacheln.dart';
import 'package:repit/health/health_types.dart';
import 'package:repit/shell/heute_anzeigen.dart';

/// Baut die Kacheln über einen echten [BuildContext] und gibt sie heraus —
/// [zahlenKacheln] ist eine Funktion, kein Widget, und braucht den Context
/// nur zum Auflösen der Farben.
Future<List<KachelWert>> kacheln(
  WidgetTester tester, {
  required List<DailyMetrics> fenster,
  required String heuteTag,
}) async {
  late List<KachelWert> ergebnis;
  await tester.pumpWidget(
    CupertinoApp(
      home: Builder(
        builder: (context) {
          ergebnis = zahlenKacheln(
            context,
            fenster.isEmpty ? null : fenster.last,
            fenster,
            heuteTag: heuteTag,
            laedt: false,
          );
          return const SizedBox();
        },
      ),
    ),
  );
  return ergebnis;
}

KachelWert kachel(List<KachelWert> alle, String label) =>
    alle.firstWhere((k) => k.label == label);

/// Vierzehn aufsteigende Märztage, der letzte ist „heute".
const heute = '2031-03-14';
List<String> tage() => [for (var t = 1; t <= 14; t++) '2031-03-${t < 10 ? '0$t' : t}'];

void main() {
  testWidgets('die Schritte-Linie trägt nur die letzten sieben Tage', (
    tester,
  ) async {
    // Schritte an allen 14 Tagen, als unterscheidbare Werte 1000·Tag.
    final fenster = [
      for (final (i, tag) in tage().indexed)
        DailyMetrics(tag: tag, steps: (i + 1) * 1000),
    ];

    final alle = await kacheln(tester, fenster: fenster, heuteTag: heute);

    expect(
      kachel(alle, 'Schritte').verlauf,
      orderedEquals(const <double>[
        8000, 9000, 10000, 11000, 12000, 13000, 14000,
      ]),
      reason:
          'die Woche ist 08.–14., alles davor gehört nicht in die Linie',
    );
  });

  testWidgets('beim Gewicht zählen nur Messungen aus der Woche', (
    tester,
  ) async {
    // Messungen am 02., 05. (vor der Woche) und am 10., 12. (in ihr).
    final fenster = [
      for (final tag in tage())
        DailyMetrics(
          tag: tag,
          weightKg: switch (tag) {
            '2031-03-02' => 80.0,
            '2031-03-05' => 81.0,
            '2031-03-10' => 82.5,
            '2031-03-12' => 82.1,
            _ => null,
          },
        ),
    ];

    final alle = await kacheln(tester, fenster: fenster, heuteTag: heute);

    expect(
      kachel(alle, 'Gewicht').verlauf,
      orderedEquals(const <double>[82.5, 82.1]),
      reason:
          'die Messungen vor der Woche tragen weder Punkt noch Richtung bei',
    );
  });

  testWidgets('eine einzige Messung in der Woche ergibt keine Linie', (
    tester,
  ) async {
    // Draußen lägen genug Punkte — aber die Linie zeigt die Woche, und in
    // der Woche gibt es nur einen. Aus einem Punkt wird keine Linie.
    final fenster = [
      for (final tag in tage())
        DailyMetrics(
          tag: tag,
          weightKg: switch (tag) {
            '2031-03-02' => 80.0,
            '2031-03-05' => 81.0,
            '2031-03-12' => 82.1,
            _ => null,
          },
        ),
    ];

    final alle = await kacheln(tester, fenster: fenster, heuteTag: heute);

    expect(
      kachel(alle, 'Gewicht').verlauf,
      isNull,
      reason:
          'unter zwei Punkten in der Woche gibt es keine Linie — auch wenn '
          'das 30-Tage-Fenster mehr hätte',
    );
    expect(
      kachel(alle, 'Gewicht').wert,
      isNotNull,
      reason:
          'der Zahlwert kommt weiter aus dem ganzen Fenster: die letzte '
          'Waage war am 12., und die steht da',
    );
  });

  testWidgets('die Grenze liegt am Kalendertag, nicht an der Listenposition', (
    tester,
  ) async {
    // Ein lückiges Fenster aus nur vier Einträgen: zwei alte, zwei junge.
    // Wer stattdessen „die letzten 7 Listeneinträge" nähme, bekäme hier
    // alle vier — die Tagesgrenze lässt nur die zwei jungen durch.
    final fenster = [
      const DailyMetrics(tag: '2031-03-01', steps: 1000),
      const DailyMetrics(tag: '2031-03-04', steps: 2000),
      const DailyMetrics(tag: '2031-03-09', steps: 3000),
      const DailyMetrics(tag: '2031-03-14', steps: 4000),
    ];

    final alle = await kacheln(tester, fenster: fenster, heuteTag: heute);

    expect(
      kachel(alle, 'Schritte').verlauf,
      orderedEquals(const <double>[3000, 4000]),
      reason: 'nur der 09. und der 14. liegen in der Woche bis zum 14.',
    );
  });
}
