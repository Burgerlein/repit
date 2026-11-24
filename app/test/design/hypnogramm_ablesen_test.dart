import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repit/design/hypnogramm.dart';
import 'package:repit/health/health_types.dart';

import 'support.dart';

/// Tests zum neu entworfenen Hypnogramm (Ticket #141) und zur Messlücke
/// (#156). Vorlage ist der freigegebene Entwurf vom 28.10.2026:
/// `docs/screens/components.js` (`hypnogram`) und
/// `docs/screens/screens/schlaf.js`, Zustände „Mit Nacht", „Ablesen durch
/// Halten" und „Messlücke".
///
/// Tim über die gebaute Fassung am Gerät: „sieht echt kacke aus, und man
/// kann nicht reindrücken, um die Uhrzeit besser zu erfahren wie bei
/// Graphen."
///
/// ## Was diese Datei festschreibt
///
/// ```dart
/// class Hypnogramm extends StatefulWidget {
///   const Hypnogramm({
///     super.key,
///     required SleepSession session,
///     bool kompakt = true,
///     bool ablesbar = false,   // Uhrzeitachse, Kopfzeile, Ablesen
///   });
/// }
///
/// /// Ein Eintrag im Bild: ein gemessener Abschnitt **oder** eine Messlücke.
/// class Hypnogrammeintrag {
///   SleepStage? get phase;    // null = Messlücke
///   DateTime get von, bis;
///   bool get istLuecke;
///   Duration get dauer;
/// }
///
/// class HypnogrammGeometrie {
///   List<Hypnogrammeintrag> get eintraege;
///   List<({DateTime von, DateTime bis})> get gemesseneStrecken;
///   List<DateTime> get volleStunden;
///   ({double links, double breite}) lage(Hypnogrammeintrag e, double gesamt);
///   int? trefferBei(double x, double gesamt);
/// }
/// ```
///
/// ## Die fünf Aussagen
///
/// 1. **Der Eckenradius ist fest 2**, nicht die halbe Balkenhöhe. Bei
///    `rx = Balkenhöhe / 2` wird jeder Abschnitt, der schmaler ist als
///    hoch, zur Kapsel — bei 25 Abschnitten fast jeder. Das kehrt die
///    Entscheidung vom 27.10.2026 um; sie fiel gegen eine geschönte Nacht
///    mit 17 Abschnitten, deren kürzester acht Minuten dauerte.
/// 2. **Mindestbreite 2,4 Punkt.** Eine Minute von 450 ist auf 320 Punkten
///    0,7 Punkt breit und damit unsichtbar. Das Bild rundet nach oben; die
///    Minuten stehen anderswo und bleiben die Wahrheit.
/// 3. **Eine Uhrzeitachse** unter dem Bild: Linien je volle Stunde,
///    beschriftet alle zwei Stunden.
/// 4. **Ablesen durch Halten.** Und die Regel, auf die es dabei ankommt:
///    Ein Block von einer Minute ist schmaler als eine Fingerkuppe, also
///    muss die Berührung auf den **nächstliegenden** Abschnitt fallen,
///    nicht auf den zeitlich getroffenen — sonst ist genau der Fall
///    unablesbar, für den das Ablesen gebaut wird.
/// 5. **Eine Messlücke** belegt ihren Platz auf der Zeitachse, trägt keinen
///    Block, und die grauen Spuren brechen dort ab. Eine durchlaufende Spur
///    behauptete, es sei gemessen und nur nichts gewesen.
///
/// **Keine Verbindungslinie zwischen den Blöcken** (Tim, 28.10.2026). Der
/// Entwurf kennt eine Option dafür; sie wird nicht gerufen.
///
/// Alle Zahlen sind erfunden. Echte Gesundheitsdaten stehen nie im
/// Quelltext (`CLAUDE.md`).
void main() {
  DateTime t(int stunde, int minute) => DateTime(2026, 3, 17, stunde, minute);
  DateTime t2(int stunde, int minute) => DateTime(2026, 3, 18, stunde, minute);

  /// 450 Minuten von 23:10 bis 06:40 — das Fenster des Entwurfs. Mittendrin
  /// eine Wachphase von **einer** Minute: der Fall, an dem sich Form und
  /// Ablesen entscheiden.
  SleepSession langeNacht() => SleepSession(
    segments: [
      SleepSegment(stage: SleepStage.core, start: t(23, 10), end: t2(2, 30)),
      SleepSegment(stage: SleepStage.awake, start: t2(2, 30), end: t2(2, 31)),
      SleepSegment(stage: SleepStage.core, start: t2(2, 31), end: t2(6, 40)),
    ],
  );

  /// Dieselbe Nacht, aber die Uhr lag von 02:26 bis 04:01 daneben — 95
  /// Minuten ohne Messung (#156).
  SleepSession nachtMitLuecke() => SleepSession(
    segments: [
      SleepSegment(stage: SleepStage.core, start: t(23, 10), end: t2(2, 26)),
      SleepSegment(stage: SleepStage.core, start: t2(4, 1), end: t2(6, 40)),
    ],
  );

  /// Zwei Wachphasen, zusammen 22 Minuten — die Zusammenfassung, die in
  /// Ruhe über dem Bild steht.
  SleepSession nachtMitZweiWach() => SleepSession(
    segments: [
      SleepSegment(stage: SleepStage.awake, start: t(23, 10), end: t(23, 22)),
      SleepSegment(stage: SleepStage.core, start: t(23, 22), end: t2(5, 0)),
      SleepSegment(stage: SleepStage.awake, start: t2(5, 0), end: t2(5, 10)),
      SleepSegment(stage: SleepStage.core, start: t2(5, 10), end: t2(6, 40)),
    ],
  );

  /// Die volle Fassung in einer bekannten Breite: 44 Punkt Spurnamen, dann
  /// 320 Punkt Bild. Darauf rechnen die Erwartungen unten.
  Widget bildMitBreite(Widget kind) =>
      huelle(SizedBox(width: 44 + 320, child: kind));

  HypnogrammPainter? painterVon(WidgetTester tester) {
    final gemalt = tester
        .widgetList<CustomPaint>(
          find.descendant(
            of: find.byType(Hypnogramm),
            matching: find.byType(CustomPaint),
          ),
        )
        .map((flaeche) => flaeche.painter)
        .whereType<HypnogrammPainter>();
    return gemalt.isEmpty ? null : gemalt.first;
  }

  /// Hält den Finger an [x] im Bild — `x` zählt ab der linken Kante der
  /// Zeichenfläche, nicht ab der des Schirms.
  Future<TestGesture> halteBei(WidgetTester tester, double x) async {
    final flaeche = tester.getTopLeft(find.byKey(const Key('hypnogramm-bild')));
    final gesture = await tester.startGesture(flaeche + Offset(x, 10));
    await tester.pump(const Duration(milliseconds: 600));
    return gesture;
  }

  String kopfzeile(WidgetTester tester, String teil) {
    final kopf = find.byKey(const Key('hypnogramm-kopf'));
    final texte = tester
        .widgetList<Text>(find.descendant(of: kopf, matching: find.byType(Text)))
        .map(textOf)
        .toList();
    return teil == 'links' ? texte.first : texte.last;
  }

  // ───────────────────────────────────────────────────────────────────────
  // 1 + 2 — die Form
  // ───────────────────────────────────────────────────────────────────────

  group('Die Form der Blöcke (#141)', () {
    // Volle Fassung: Spur 40, Balken 21. Bei `rx = Balkenhöhe / 2` wäre der
    // Radius 10,5 — und jeder Block schmaler als 21 Punkt eine Kapsel.
    const flaeche = Size(320, 160);
    const balken = 21.0;

    void Function(Canvas) gemalt(List<SleepSegment> abschnitte) {
      final painter = HypnogrammPainter(
        abschnitte: abschnitte,
        farben: {
          for (final phase in SleepStage.values) phase: const Color(0xFF123456),
        },
        fensterFarbe: const Color(0x0D15242A),
        kompakt: false,
      );
      return (canvas) => painter.paint(canvas, flaeche);
    }

    test('der Eckenradius ist fest 2, nicht die halbe Balkenhöhe', () {
      RRect gerundet(double links, double oben, double breite) =>
          RRect.fromRectAndRadius(
            Rect.fromLTWH(links, oben, breite, balken),
            const Radius.circular(2),
          );

      expect(
        gemalt([
          SleepSegment(stage: SleepStage.core, start: t(23, 0), end: t2(0, 0)),
          SleepSegment(stage: SleepStage.deep, start: t2(0, 0), end: t2(1, 0)),
        ]),
        paints
          // Die vier Spuren über die volle Breite …
          ..rrect(rrect: gerundet(0, 0, 320))
          ..rrect(rrect: gerundet(0, 40, 320))
          ..rrect(rrect: gerundet(0, 80, 320))
          ..rrect(rrect: gerundet(0, 120, 320))
          // … und die beiden Blöcke darauf, je eine Stunde.
          ..rrect(rrect: gerundet(0, 80, 160))
          ..rrect(rrect: gerundet(160, 120, 160)),
        reason:
            'bei `rx = Balkenhöhe / 2` wird jeder Abschnitt, der schmaler '
            'ist als hoch, zur Kapsel — bei 25 Abschnitten fast jeder',
      );
    });

    test('ein Abschnitt von einer Minute wird auf 2,4 Punkt verbreitert', () {
      // 450 Minuten auf 320 Punkten: Eine Minute ist 0,711 Punkt breit und
      // damit unsichtbar. Links liegt der Block bei 320 · 200/450.
      expect(
        gemalt(langeNacht().segments),
        paints
          ..rrect()
          ..rrect()
          ..rrect()
          ..rrect()
          ..rrect()
          ..rrect(
            rrect: RRect.fromRectAndRadius(
              Rect.fromLTWH(320 * 200 / 450, 0, 2.4, balken),
              const Radius.circular(2),
            ),
          ),
        reason:
            'das Bild rundet hier nach oben — lieber ein Strich, der ein '
            'bisschen zu breit ist, als eine Wachphase, die es laut Bild '
            'nicht gibt',
      );
    });

    test('zwischen den Blöcken steht keine Verbindungslinie', () {
      expect(
        gemalt(langeNacht().segments),
        paintsExactlyCountTimes(#drawLine, 0),
        reason:
            'Tims Entscheidung vom 28.10.2026: bei 25 Abschnitten ordnen '
            'Verbinder nicht mehr, sie sind ein Gitter',
      );
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // 3 — die Uhrzeitachse
  // ───────────────────────────────────────────────────────────────────────

  group('Die Uhrzeitachse (#141)', () {
    test('die Geometrie nennt jede volle Stunde im Fenster', () {
      final geometrie = HypnogrammGeometrie(langeNacht());

      expect(geometrie.volleStunden, [
        t2(0, 0),
        t2(1, 0),
        t2(2, 0),
        t2(3, 0),
        t2(4, 0),
        t2(5, 0),
        t2(6, 0),
      ]);
    });

    testWidgets('beschriftet wird alle zwei Stunden, nicht jede', (
      tester,
    ) async {
      await tester.pumpWidget(
        bildMitBreite(
          Hypnogramm(session: langeNacht(), kompakt: false, ablesbar: true),
        ),
      );

      expect(find.text('00:00'), findsOneWidget);
      expect(find.text('02:00'), findsOneWidget);
      expect(find.text('04:00'), findsOneWidget);
      expect(find.text('06:00'), findsOneWidget);
      expect(find.text('01:00'), findsNothing);
      expect(find.text('03:00'), findsNothing);
    });

    // Kompakt sitzt das Bild in der Nachtkarte, auf dem Tagschlaf-Schirm
    // führt die Karte darüber schon die Wachzeit. Zwei Stellen mit
    // derselben Zahl laufen auseinander — Entscheidung des
    // Entwurfsagenten vom 27./28.10.2026.
    testWidgets('ohne `ablesbar` gibt es keine Achse', (tester) async {
      await tester.pumpWidget(
        bildMitBreite(Hypnogramm(session: langeNacht(), kompakt: false)),
      );

      expect(find.text('02:00'), findsNothing);
      expect(find.text('04:00'), findsNothing);
      expect(painterVon(tester)!.achse, isEmpty);
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // 4 — Ablesen durch Halten
  // ───────────────────────────────────────────────────────────────────────

  group('Ablesen durch Halten (#141)', () {
    testWidgets('in Ruhe steht die Zusammenfassung der Wachphasen', (
      tester,
    ) async {
      await tester.pumpWidget(
        bildMitBreite(
          Hypnogramm(
            session: nachtMitZweiWach(),
            kompakt: false,
            ablesbar: true,
          ),
        ),
      );

      expect(kopfzeile(tester, 'links'), 'WACH');
      expect(kopfzeile(tester, 'rechts'), '2× · 22 min');
    });

    testWidgets('beim Halten nennt die Kopfzeile Zeitspanne, Phase und Dauer', (
      tester,
    ) async {
      await tester.pumpWidget(
        bildMitBreite(
          Hypnogramm(session: langeNacht(), kompakt: false, ablesbar: true),
        ),
      );

      // Mitten im ersten Kern-Block: 23:10 bis 02:30, 3:20 lang.
      final gesture = await halteBei(tester, 40);
      await tester.pump();

      expect(kopfzeile(tester, 'links'), '23:10 – 02:30');
      expect(kopfzeile(tester, 'rechts'), 'Kern · 3:20');
      expect(painterVon(tester)!.auswahl, 0);

      await gesture.up();
      await tester.pump();

      expect(kopfzeile(tester, 'links'), 'WACH');
      expect(painterVon(tester)!.auswahl, isNull);
    });

    // Die Regel aus dem Entwurf, ohne die das Ablesen genau den Fall nicht
    // trifft, für den es gebaut ist.
    testWidgets('die Berührung fällt auf den nächstliegenden Abschnitt, nicht '
        'auf den zeitlich getroffenen', (tester) async {
      await tester.pumpWidget(
        bildMitBreite(
          Hypnogramm(session: langeNacht(), kompakt: false, ablesbar: true),
        ),
      );

      // Der Ein-Minuten-Block liegt zwischen 142,2 und 144,6 Punkten —
      // gezeichnet, nicht gerechnet. **Zeitlich** gehört x = 144 längst
      // zum nächsten Kern-Block (202,5 von 450 Minuten).
      final gesture = await halteBei(tester, 144);
      await tester.pump();

      expect(
        kopfzeile(tester, 'rechts'),
        'Wach · 1 min',
        reason:
            'ein Block von einer Minute ist schmaler als eine Fingerkuppe; '
            'wer auf ihn drückt, meint ihn',
      );
      expect(kopfzeile(tester, 'links'), '02:30 – 02:31');

      await gesture.up();
    });

    testWidgets('ohne `ablesbar` gibt es weder Kopfzeile noch Auswahl', (
      tester,
    ) async {
      await tester.pumpWidget(
        bildMitBreite(Hypnogramm(session: langeNacht(), kompakt: false)),
      );

      expect(find.byKey(const Key('hypnogramm-kopf')), findsNothing);

      final gesture = await halteBei(tester, 144);
      await tester.pump();

      expect(painterVon(tester)!.auswahl, isNull);
      await gesture.up();
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // 5 — die Messlücke (#156)
  // ───────────────────────────────────────────────────────────────────────

  group('Messlücke (#156)', () {
    test('ein Abstand zwischen zwei Abschnitten wird zur Lücke', () {
      final eintraege = HypnogrammGeometrie(nachtMitLuecke()).eintraege;

      expect(eintraege.length, 3);
      expect(eintraege[1].istLuecke, isTrue);
      expect(eintraege[1].phase, isNull);
      expect(eintraege[1].von, t2(2, 26));
      expect(eintraege[1].bis, t2(4, 1));
      expect(eintraege[0].istLuecke, isFalse);
      expect(eintraege[2].istLuecke, isFalse);
    });

    // Zwischen zwei Abschnitten liegen oft Sekunden. Jeden davon als Lücke
    // zu zeichnen wäre Unsinn — die Schwelle gehört in die Umsetzung und
    // ist dort begründet.
    test('ein Abstand von vier Minuten ist keine Lücke', () {
      final geometrie = HypnogrammGeometrie(
        SleepSession(
          segments: [
            SleepSegment(
              stage: SleepStage.core,
              start: t(23, 10),
              end: t2(1, 0),
            ),
            SleepSegment(
              stage: SleepStage.core,
              start: t2(1, 4),
              end: t2(6, 40),
            ),
          ],
        ),
      );

      expect(geometrie.eintraege.length, 2);
      expect(geometrie.eintraege.any((e) => e.istLuecke), isFalse);
    });

    test('die grauen Spuren brechen an der Lücke ab', () {
      final strecken = HypnogrammGeometrie(nachtMitLuecke()).gemesseneStrecken;

      expect(strecken.length, 2);
      expect(strecken.first.von, t(23, 10));
      expect(strecken.first.bis, t2(2, 26));
      expect(strecken.last.von, t2(4, 1));
      expect(strecken.last.bis, t2(6, 40));
    });

    test('über der Lücke steht kein Block, und die Spuren laufen nicht '
        'durch', () {
      final painter = HypnogrammPainter(
        abschnitte: nachtMitLuecke().segments,
        farben: {
          for (final phase in SleepStage.values) phase: const Color(0xFF123456),
        },
        fensterFarbe: const Color(0x0D15242A),
        kompakt: false,
      );

      expect(
        (canvas) => painter.paint(canvas, const Size(320, 160)),
        // Vier Spuren zu je zwei Stücken, dazu zwei Blöcke: zehn.
        paintsExactlyCountTimes(#drawRRect, 10),
        reason:
            'eine durchlaufende Spur behauptete, es sei gemessen und nur '
            'nichts gewesen',
      );
    });

    testWidgets('über der Lücke steht beim Halten „keine Messung", nie der '
        'Nachbarwert', (tester) async {
      await tester.pumpWidget(
        bildMitBreite(
          Hypnogramm(session: nachtMitLuecke(), kompakt: false, ablesbar: true),
        ),
      );

      // Die Lücke liegt zwischen 320 · 196/450 = 139,4 und 320 · 291/450
      // = 206,9 Punkten.
      final gesture = await halteBei(tester, 170);
      await tester.pump();

      expect(kopfzeile(tester, 'rechts'), 'keine Messung');
      expect(kopfzeile(tester, 'links'), '02:26 – 04:01');

      await gesture.up();
    });

    test('eine Lücke zählt in keine Phasensumme', () {
      final eintraege = HypnogrammGeometrie(nachtMitLuecke()).eintraege;
      final gemessen = eintraege
          .where((e) => !e.istLuecke)
          .fold(Duration.zero, (summe, e) => summe + e.dauer);

      expect(gemessen, const Duration(minutes: 196 + 159));
    });
  });
}
