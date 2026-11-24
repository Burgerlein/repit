import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/design/palette.dart';
import 'package:repit/design/zeitdiagramm.dart';
import 'package:repit/health/health_types.dart';
import 'package:repit/shell/schlaf_abschnitte.dart';
import 'package:repit/shell/schlaf_zustand.dart';

import '../design/support.dart' show textOf;

/// **#148 Teil 2, #152 und #154 — die drei Diagramme des Schlaf-Schirms.**
///
/// Alle drei liegen in `lib/shell/schlaf_abschnitte.dart`, deshalb in einer
/// Datei. Die Spec ist das Entwurfsboard: `docs/screens/screens/schlaf.js`
/// mit den Bausteinen `minMaxChart` und `nightsChart` aus
/// `docs/screens/components.js`.
///
/// ## #148 · Puls und Atmung sind unlesbar, Spitzenwerte fehlen
///
/// Tim am Gerät: „Herzfrequenz und Atemfrequenz Graph, die sind nicht
/// lesbar. da fehlen auch die Spitzenwerte aus dem Design." Gebaut wurde
/// **jede Einzelmessung** als eigene Kapsel — rund achtzehn nebeneinander,
/// teils zwei Punkt breit. Der Entwurf verdichtet auf **acht** Abschnitte
/// mit je einer Spanne.
///
/// Die Verdichtung selbst ist eine Rechnung und liegt im Kern
/// (`SpanBuckets`, `Packages/trainings_core/test/span_buckets_test.dart`).
/// Diese Datei prüft, was die Ansicht daraus macht.
///
/// **Zwei Entscheidungen hat Tim am 28.10.2026 getroffen:**
///
/// 1. Eine Stunde ohne Messung wird **nicht gezeichnet**, der Platz bleibt
///    frei. Kein blasser Strich auf der Grundlinie — der sähe aus wie ein
///    sehr niedriger Messwert. Der Abschnitt bleibt trotzdem im Raster,
///    damit die Achse nicht verrutscht.
/// 2. Die Atemfrequenz bekommt **eine Nachkommastelle**, der Puls bleibt
///    ganzzahlig. Die Atemfrequenz schwankt um gut eine Einheit; gerundet
///    verschwindet genau das Signal, auf das die Ampel schaut.
///
/// ## #152 · Ziellinie im Schlaf-Verlauf
///
/// Wie bei Belastung, wo die grüne Linie das Tagesziel zeigt. Das
/// Schlafziel liegt in `lib/data/ziele.dart` — **keine Zielkonstante im
/// Quelltext** (`CLAUDE.md`).
///
/// ## #154 · Die Achse der sieben Nächte
///
/// Gebaut lief sie 18:00 → 18:00 (24 h), deshalb saßen alle Nächte als
/// kurze Klötzchen in der Mitte. Der Entwurf (`nightsChart`) läuft
/// **21:00 → 10:00** (13 h) und zieht Rasterlinien samt Uhrzeiten bei
/// 21, 24, 27, 30, 33 Stunden.
///
/// ## Was hier geprüft wird — und was nicht
///
/// `CLAUDE.md`: Zustände und Übergänge, nicht Layout und Beschriftung. Wo
/// ein Text eine *Regel* trägt, wird die Regel geprüft, nicht der Wortlaut.
///
/// **Die Achse der sieben Nächte ist der Ausnahmefall**: Sie *ist* der
/// Ticketinhalt. Geprüft wird sie deshalb als reine Abbildung Zeitpunkt →
/// Anteil, nicht an gemalten Pixeln.
///
/// **Nicht geprüft, bewusst:** Kapselbreiten, Abstände, Schriftgrößen und
/// die Farbzuordnung der Nachtbalken — die steht schon in
/// `schlaf_naechte_farben_test.dart`.
void main() {
  DateTime tagesbeginn(int tag) =>
      BerlinCalendar.startOfDay(DateTime.utc(2026, 10, tag));

  /// Berliner Ortszeit im Oktober 2026 (MESZ, +2) als UTC-Zeitpunkt.
  DateTime berlin(int tag, int stunde, [int minute = 0]) =>
      DateTime.utc(2026, 10, tag, stunde - 2, minute);

  // ───────────────────────────────────────────────────────────────────────
  // Testhüllen
  // ───────────────────────────────────────────────────────────────────────

  Future<void> zeige(
    WidgetTester tester,
    Widget inhalt, {
    Brightness helligkeit = Brightness.light,
  }) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      CupertinoApp(
        theme: CupertinoThemeData(brightness: helligkeit),
        home: CupertinoPageScaffold(
          child: SingleChildScrollView(child: inhalt),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  List<String> texteUnter(WidgetTester tester, Finder bereich) => tester
      .widgetList<Text>(
        find.descendant(of: bereich, matching: find.byType(Text)),
      )
      .map(textOf)
      .toList();

  String textUnter(WidgetTester tester, Finder bereich) =>
      texteUnter(tester, bereich).join(' ');

  // ───────────────────────────────────────────────────────────────────────
  // #148 · Puls und Atmung
  // ───────────────────────────────────────────────────────────────────────

  group('Verdichtete Spannen statt Einzelmessungen', () {
    /// Die Nacht des Entwurfs: 23:10 → 06:40, auf acht Abschnitte
    /// verdichtet. Alle Zahlen sind erfunden.
    List<ValueSpan> nacht({Set<int> leer = const {}}) {
      const minuten = 450;
      final von = berlin(11, 23, 10);
      DateTime grenze(int i) =>
          von.add(Duration(microseconds: minuten * 60 * 1000000 * i ~/ 8));
      const tiefst = [58.0, 52.0, 49.0, 48.0, 51.0, 50.0, 54.0, 57.0];
      const hoechst = [71.0, 64.0, 58.0, 55.0, 62.0, 59.0, 68.0, 74.0];
      return [
        for (var i = 0; i < 8; i++)
          if (leer.contains(i))
            ValueSpan.empty(start: grenze(i), end: grenze(i + 1))
          else
            ValueSpan(
              start: grenze(i),
              end: grenze(i + 1),
              min: tiefst[i],
              max: hoechst[i],
            ),
      ];
    }

    CustomPainter spannenPainter(WidgetTester tester) => tester
        .widgetList<CustomPaint>(
          find.descendant(
            of: find.byType(SchlafSpannenDiagramm),
            matching: find.byType(CustomPaint),
          ),
        )
        .map((flaeche) => flaeche.painter)
        .whereType<CustomPainter>()
        .first;

    void Function(Canvas) gemalt(CustomPainter painter) =>
        (canvas) => painter.paint(canvas, const Size(280, 96));

    Widget diagramm(List<ValueSpan> spannen, {int nachkommastellen = 0}) =>
        SchlafSpannenDiagramm(
          spannen: spannen,
          farbe: Palette.warn,
          // Seit #168 trägt der Satz über dem Diagramm die Spanne, und er
          // nennt Messgröße und Einheit in Worten statt „bpm".
          groesse: nachkommastellen == 0 ? 'dein Puls' : 'deine Atemfrequenz',
          einheit: nachkommastellen == 0
              ? 'Schlägen pro Minute'
              : 'Atemzügen pro Minute',
          nachkommastellen: nachkommastellen,
        );

    testWidgets('acht Abschnitte geben acht Kapseln, nicht achtzehn', (
      tester,
    ) async {
      await zeige(tester, diagramm(nacht()));

      expect(
        gemalt(spannenPainter(tester)),
        paintsExactlyCountTimes(#drawRRect, 8),
        reason:
            'das ist der ganze Ticketinhalt — der Entwurf zeigt acht '
            'Spannen, gebaut war jede Einzelmessung eine eigene Kapsel',
      );
    });

    testWidgets(
      'eine Stunde ohne Messung wird nicht gezeichnet, der Platz bleibt '
      'frei (Tims Entscheidung vom 28.10.2026)',
      (tester) async {
        await zeige(tester, diagramm(nacht(leer: const {3, 5})));

        expect(
          gemalt(spannenPainter(tester)),
          paintsExactlyCountTimes(#drawRRect, 6),
          reason:
              'ein blasser Strich auf der Grundlinie sähe aus wie ein sehr '
              'niedriger Messwert — eine Lücke bleibt eine Lücke',
        );
      },
    );

    testWidgets('die Legende nennt Tiefst- und Höchstwert der ganzen Nacht', (
      tester,
    ) async {
      await zeige(tester, diagramm(nacht()));

      final text = textUnter(tester, find.byType(SchlafSpannenDiagramm));
      expect(text, contains('48'));
      expect(
        text,
        contains('74'),
        reason:
            'Tim: „da fehlen auch die Spitzenwerte aus dem Design" — der '
            'Höchstwert der Nacht gehört in die Legende',
      );
    });

    testWidgets('leere Abschnitte spannen die Skala nicht auf', (tester) async {
      await zeige(tester, diagramm(nacht(leer: const {0, 7})));

      final text = textUnter(tester, find.byType(SchlafSpannenDiagramm));
      expect(
        text,
        contains('48'),
        reason: 'Tiefst- und Höchstwert kommen aus den gemessenen Abschnitten',
      );
      expect(
        text,
        isNot(contains('74')),
        reason:
            'der Abschnitt mit der 74 trägt keine Messung mehr — eine 74 in '
            'der Legende behauptete eine Messung, die es nicht gibt',
      );
    });

    testWidgets(
      'die Atemfrequenz bekommt eine Nachkommastelle, der Puls nicht',
      (tester) async {
        await zeige(
          tester,
          SchlafSpannenDiagramm(
            spannen: [
              ValueSpan(
                start: berlin(11, 23, 10),
                end: berlin(12, 0, 10),
                min: 11.6,
                max: 15.2,
              ),
            ],
            farbe: Palette.river,
            groesse: 'deine Atemfrequenz',
            einheit: 'Atemzügen pro Minute',
            nachkommastellen: 1,
          ),
        );

        final text = textUnter(tester, find.byType(SchlafSpannenDiagramm));
        expect(
          text,
          contains('11,6'),
          reason:
              'die Atemfrequenz schwankt um gut eine Einheit — gerundet '
              'verschwindet genau das Signal, auf das die Ampel schaut '
              '(Tims Entscheidung vom 28.10.2026)',
        );
        expect(text, contains('15,2'));
        expect(
          text,
          isNot(contains('11.6')),
          reason: 'deutsches Dezimalkomma, kein Punkt',
        );
      },
    );

    testWidgets('der Puls bleibt ganzzahlig', (tester) async {
      await zeige(
        tester,
        SchlafSpannenDiagramm(
          spannen: [
            ValueSpan(
              start: berlin(11, 23, 10),
              end: berlin(12, 0, 10),
              min: 48.4,
              max: 73.6,
            ),
          ],
          farbe: Palette.warn,
          groesse: 'dein Puls',
          einheit: 'Schlägen pro Minute',
        ),
      );

      final text = textUnter(tester, find.byType(SchlafSpannenDiagramm));
      expect(text, contains('48'));
      expect(text, contains('74'));
      // Gemeint ist „kein Dezimalkomma in den Zahlen", nicht „nirgends ein
      // Komma". Seit #168 steht über dem Diagramm ein Satz („Während du
      // geschlafen hast, …"), und dessen Grammatikkomma traf die alte
      // Fassung. Die Regel prüft jetzt, was der Fallname behauptet, und
      // überlebt Prosa.
      expect(text, isNot(matches(RegExp(r'\d,\d'))));
    });

    testWidgets(
      'unter den Kapseln steht eine Zeitachse — **nur die beiden Enden** '
      'tragen eine Uhrzeit (#168)',
      (tester) async {
        await zeige(tester, diagramm(nacht()));

        final texte = texteUnter(tester, find.byType(SchlafSpannenDiagramm));
        // 23:10 ist der Beginn des ersten Abschnitts, 06:40 das Ende der
        // Nacht. Bis zum 28.10.2026 trug jeder zweite Abschnitt seine
        // Uhrzeit; Apple setzt nur die Enden, und Tim hat das am
        // 29.10.2026 so entschieden („genau so wie Apple").
        expect(texte, contains('23:10'));
        expect(
          texte,
          contains('06:40'),
          reason: 'ohne Achse sind das Kapseln ohne Bezug',
        );
        for (final uhrzeit in ['01:02', '02:55', '04:47']) {
          expect(texte, isNot(contains(uhrzeit)));
        }
      },
    );

    testWidgets('eine leere Stunde lässt die Achse an ihrem Platz', (
      tester,
    ) async {
      await zeige(tester, diagramm(nacht(leer: const {2})));

      expect(
        texteUnter(tester, find.byType(SchlafSpannenDiagramm)),
        contains('23:10'),
        reason:
            'der leere Abschnitt bleibt im Raster stehen — fiele er heraus, '
            'verrutschte ab dort jede Beschriftung',
      );
    });

    testWidgets('ohne Spannen stehen beide Möglichkeiten da', (tester) async {
      await zeige(tester, diagramm(const []));

      final text = textUnter(
        tester,
        find.byType(SchlafSpannenDiagramm),
      ).toLowerCase();
      expect(text, contains('aufgezeichnet'));
      expect(
        text,
        contains('freigegeben'),
        reason:
            'Apple verrät den Lesestatus nicht — „keine Daten" und „nicht '
            'erlaubt" sind nicht zu unterscheiden',
      );
      expect(
        find.descendant(
          of: find.byType(SchlafSpannenDiagramm),
          matching: find.byType(CustomPaint),
        ),
        findsNothing,
        reason: 'ein leeres Raster behauptete eine Nacht mit Abschnitten',
      );
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // #152 · Ziellinie im Verlauf
  // ───────────────────────────────────────────────────────────────────────

  group('Das Schlafziel steht als Linie im Verlauf', () {
    final reihe = [
      for (var tag = 6; tag <= 12; tag++)
        (tag: tagesbeginn(tag), wert: 6.0 + tag % 3 * 0.4),
    ];

    testWidgets('mit Schlafziel trägt das Diagramm genau eine Linie', (
      tester,
    ) async {
      await zeige(
        tester,
        SchlafVerlauf(reihe: reihe, schlafzielStunden: 480 / 60),
      );

      final diagramm = tester.widget<Zeitdiagramm>(find.byType(Zeitdiagramm));
      expect(diagramm.linien, hasLength(1));
      expect(
        diagramm.linien.single.wert,
        closeTo(8, 1e-9),
        reason:
            'wie bei Belastung, wo die grüne Linie das Tagesziel zeigt — '
            'die Reihe steht in Stunden, also steht auch das Ziel dort',
      );
    });

    testWidgets('ein anderes Ziel ergibt eine andere Linie', (tester) async {
      await zeige(
        tester,
        SchlafVerlauf(reihe: reihe, schlafzielStunden: 450 / 60),
      );

      expect(
        tester
            .widget<Zeitdiagramm>(find.byType(Zeitdiagramm))
            .linien
            .single
            .wert,
        closeTo(7.5, 1e-9),
        reason:
            'der Wert kommt aus den Zielen, nie als Konstante aus dem '
            'Quelltext (`CLAUDE.md`)',
      );
    });

    testWidgets('ohne Schlafziel keine Linie', (tester) async {
      await zeige(tester, SchlafVerlauf(reihe: reihe));

      expect(
        tester.widget<Zeitdiagramm>(find.byType(Zeitdiagramm)).linien,
        isEmpty,
        reason: 'ohne Ziel keine Behauptung über ein Ziel',
      );
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // #154 · Die Achse der sieben Nächte
  // ───────────────────────────────────────────────────────────────────────

  group('Die sieben Nächte laufen von 21:00 bis 10:00', () {
    test('die Ränder der Achse sind 21:00 und 10:00', () {
      expect(schlafNaechteAnteil(berlin(11, 21)), closeTo(0, 1e-9));
      expect(schlafNaechteAnteil(berlin(12, 10)), closeTo(1, 1e-9));
    });

    test('eine Nacht füllt den Großteil der Achse, kein Drittel', () {
      final von = schlafNaechteAnteil(berlin(11, 23, 10));
      final bis = schlafNaechteAnteil(berlin(12, 6, 40));

      // 7:30 h von 13 h sind 57,7 % — auf der alten 24-Stunden-Achse waren
      // es 31 %, und genau deshalb saßen alle Nächte als kurze Klötzchen
      // in der Mitte.
      expect(bis - von, closeTo(450 / 780, 1e-9));
      expect(
        bis - von,
        greaterThan(0.5),
        reason:
            'auf einer 24-Stunden-Achse belegt eine Sieben-Stunden-Nacht '
            'weniger als ein Drittel — das ist #154',
      );
    });

    test('Mitternacht liegt bei drei von dreizehn Stunden', () {
      expect(schlafNaechteAnteil(berlin(12, 0)), closeTo(3 / 13, 1e-9));
    });

    test('was vor 21:00 oder nach 10:00 liegt, wird an den Rand geklemmt', () {
      expect(schlafNaechteAnteil(berlin(11, 20)), 0);
      expect(
        schlafNaechteAnteil(berlin(12, 11)),
        1,
        reason:
            'ein Balken, der über die Fläche hinausliefe, zeichnete über '
            'die Nachbarspalte',
      );
    });

    testWidgets('die Rasterstunden des Entwurfs stehen unter dem Diagramm', (
      tester,
    ) async {
      await zeige(
        tester,
        SchlafNaechteDiagramm(
          lagen: [
            SchlafNachtLage(
              datum: tagesbeginn(12),
              von: berlin(11, 23, 10),
              bis: berlin(12, 6, 40),
              minutenJePhase: const {
                SleepStage.core: 255,
                SleepStage.deep: 90,
                SleepStage.rem: 75,
                SleepStage.awake: 30,
              },
            ),
          ],
        ),
      );

      // Verglichen wird der **ganze** Text einer Beschriftung: „21" steckt
      // sonst schon im Satz unter dem Diagramm und „00" in jeder vollen
      // Stunde der Dauerspalte.
      final texte = texteUnter(tester, find.byType(SchlafNaechteDiagramm));
      for (final stunde in ['21', '00', '03', '06', '09']) {
        expect(
          texte,
          contains(stunde),
          reason:
              '`nightsChart` zieht Rasterlinien samt Uhrzeiten bei 21, 24, '
              '27, 30 und 33 Stunden',
        );
      }
    });

    testWidgets('der Satz darunter behauptet keine 18-Uhr-Achse mehr', (
      tester,
    ) async {
      await zeige(
        tester,
        SchlafNaechteDiagramm(
          lagen: [
            SchlafNachtLage(
              datum: tagesbeginn(12),
              von: berlin(11, 23, 10),
              bis: berlin(12, 6, 40),
              minutenJePhase: const {SleepStage.core: 450},
            ),
          ],
        ),
      );

      final text = textUnter(tester, find.byType(SchlafNaechteDiagramm));
      expect(
        text,
        isNot(contains('18:00')),
        reason:
            '`CLAUDE.md`: keine Zusage stehen lassen, die nicht mehr stimmt',
      );
      expect(text, contains('21:00'));
      expect(text, contains('10:00'));
    });
  });
}
