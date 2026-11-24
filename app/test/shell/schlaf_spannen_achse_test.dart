import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/core/messwert.dart';
import 'package:repit/data/ziele.dart';
import 'package:repit/design/palette.dart';
import 'package:repit/shell/erholung_zustand.dart';
import 'package:repit/shell/schlaf_abschnitte.dart';
import 'package:repit/shell/schlaf_zustand.dart';

import '../design/support.dart' show textOf;

/// **#168 — Puls- und Atemspannen genau wie Apple.**
///
/// Tim am 29.10.2026, mit zwei Bildschirmfotos aus Apple Health: „Bau das
/// so wie Apple bitte genau so!" Freigegeben hat er den Entwurf am selben
/// Tag („Mit Nacht und Messlücke sieht gut aus").
///
/// Die Spec ist dieser freigegebene Entwurf: `minMaxChart` in
/// `docs/screens/components.js`, benutzt von den Zuständen „Mit Nacht",
/// „Ablesen durch Halten" und „Messlücke" in
/// `docs/screens/screens/schlaf.js`.
///
/// ## Was anders wird
///
/// 1. **Keine Werteachse, keine Rasterlinien.** Eine Achse sagt „das Bild
///    reicht von 60 bis 75". Apple sagt „der tiefste Wert war 58, **und
///    zwar hier**".
/// 2. **Genau zwei beschriftete Punkte**, am Balken, an dem sie auftreten:
///    `MAX.` mit dem Wert über dem höchsten, `MIN.` mit dem Wert unter dem
///    tiefsten.
/// 3. **Die Spanne steht als Satz über dem Diagramm** statt als Kopfzeile
///    mit Kicker und Zahl.
/// 4. **Die Zeitachse trägt nur an den beiden Enden eine Uhrzeit.**
/// 5. **Deutlich schmalere Kapseln.**
/// 6. **Die Fußzeile nennt nur noch die Länge eines Abschnitts** — Anfang
///    und Ende der Nacht stehen an der Zeitachse.
///
/// ## Die Umkehr
///
/// **Die Bezugslinie ist weg.** Tim hatte sie am 28.10.2026 entschieden
/// (#157); „genau so wie Apple" hebt das einen Tag später auf. Die Fälle
/// dieser Datei haben bis dahin Achse und Bezugslinie festgenagelt — sie
/// sind deshalb mit `TEST_AENDERN=1` auf das neue Verhalten gezogen
/// worden, nicht gelöscht, weil die Anforderung dieselbe Stelle betrifft.
/// Der Vergleich zum eigenen Normalwert steht weiter auf der
/// Erholungsseite in der Zeile „Ruhepuls".
///
/// ## Was hier nicht geprüft wird
///
/// `CLAUDE.md`: Zustände und Übergänge, nicht Layout und Beschriftung.
/// Farben, Strichstärken und Abstände stehen deshalb nicht hier. Die
/// **Lage** von `MIN.` und `MAX.` ist der Ausnahmefall: Sie **ist** der
/// Ticketinhalt („ein Blick genügt, um zu sagen, wann der Puls am
/// tiefsten war"), und geprüft wird sie als Rechnung — über welchem
/// Abschnitt die Marke steht —, nicht an gemalten Pixeln.
///
/// Alle Zahlen hier sind erfunden (`CLAUDE.md`).
void main() {
  /// Berliner Ortszeit im Oktober 2026 (MESZ, +2) als UTC-Zeitpunkt.
  DateTime berlin(int tag, int stunde, [int minute = 0]) =>
      DateTime.utc(2026, 10, tag, stunde - 2, minute);

  // ───────────────────────────────────────────────────────────────────────
  // Die Nacht des Entwurfs
  // ───────────────────────────────────────────────────────────────────────

  const minutenDerNacht = 450;

  DateTime grenze(int i, int abschnitte) => berlin(11, 23, 10).add(
    Duration(microseconds: minutenDerNacht * 60 * 1000000 * i ~/ abschnitte),
  );

  /// 23:10 → 06:40, auf acht Abschnitte verdichtet — die Nacht, gegen die
  /// der Entwurf gezeichnet ist (`PULS_SPANNEN` in `schlaf.js`).
  ///
  /// Der Höchstwert 74 steht in Abschnitt 0 **und** 7, der Tiefstwert 58
  /// allein in Abschnitt 3. Das ist Absicht: Der Gleichstand oben prüft,
  /// welcher Abschnitt gewinnt.
  List<ValueSpan> pulsNacht({Set<int> leer = const {}, int abschnitte = 8}) {
    const tiefst = [64.0, 61.0, 59.0, 58.0, 60.0, 59.0, 62.0, 65.0];
    const hoechst = [74.0, 69.0, 66.0, 64.0, 67.0, 65.0, 70.0, 74.0];
    return [
      for (var i = 0; i < abschnitte; i++)
        if (leer.contains(i))
          ValueSpan.empty(
            start: grenze(i, abschnitte),
            end: grenze(i + 1, abschnitte),
          )
        else
          ValueSpan(
            start: grenze(i, abschnitte),
            end: grenze(i + 1, abschnitte),
            min: tiefst[i % tiefst.length],
            max: hoechst[i % hoechst.length],
          ),
    ];
  }

  /// Eine Nacht, in der Höchst- und Tiefstwert **mitten im Bild** liegen —
  /// Abschnitt 1 trägt den höchsten, Abschnitt 6 den tiefsten.
  ///
  /// Am Rand schiebt sich die Beschriftung herein, damit sie im Bild
  /// bleibt; in der Mitte steht sie über ihrem Balken. Beides wird
  /// geprüft, aber getrennt.
  List<ValueSpan> nachtMitSpitzenInDerMitte() {
    const tiefst = [62.0, 66.0, 61.0, 60.0, 61.0, 60.0, 55.0, 63.0];
    const hoechst = [70.0, 79.0, 68.0, 66.0, 67.0, 66.0, 62.0, 71.0];
    return [
      for (var i = 0; i < 8; i++)
        ValueSpan(
          start: grenze(i, 8),
          end: grenze(i + 1, 8),
          min: tiefst[i],
          max: hoechst[i],
        ),
    ];
  }

  /// Dieselbe Nacht in Atemzügen — `ATMUNG_SPANNEN` aus dem Entwurf.
  List<ValueSpan> atemNacht() {
    const tiefst = [12.4, 12.1, 11.8, 11.6, 11.9, 12.2, 12.6, 13.1];
    const hoechst = [14.8, 14.1, 13.6, 13.2, 13.8, 14.0, 14.6, 15.2];
    return [
      for (var i = 0; i < 8; i++)
        ValueSpan(
          start: grenze(i, 8),
          end: grenze(i + 1, 8),
          min: tiefst[i],
          max: hoechst[i],
        ),
    ];
  }

  // ───────────────────────────────────────────────────────────────────────
  // Testhüllen
  // ───────────────────────────────────────────────────────────────────────

  Future<void> zeige(WidgetTester tester, Widget inhalt) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: SingleChildScrollView(child: inhalt),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  List<String> texte(WidgetTester tester) => tester
      .widgetList<Text>(
        find.descendant(
          of: find.byType(SchlafSpannenDiagramm),
          matching: find.byType(Text),
        ),
      )
      .map(textOf)
      .toList();

  String satz(WidgetTester tester) =>
      textOf(tester.widget<Text>(find.byKey(const Key('schlaf-spannen-satz'))));

  String fuss(WidgetTester tester) =>
      textOf(tester.widget<Text>(find.byKey(const Key('schlaf-spannen-fuss'))));

  /// Die Mitte des Abschnitts [i] von [anzahl] im Bild — die Abschnitte
  /// teilen die Zeichenfläche gleichmäßig, so steht es im Entwurf.
  double abschnittsmitte(WidgetTester tester, int i, {int anzahl = 8}) {
    final bild = tester.getRect(find.byKey(const Key('schlaf-spannen-bild')));
    return bild.left + (i + 0.5) * bild.width / anzahl;
  }

  /// Hält den Finger über den Abschnitt [i] — **ohne** `pumpAndSettle`,
  /// damit der Zwischenzustand „Finger liegt noch auf" prüfbar bleibt.
  Future<TestGesture> halte(WidgetTester tester, int i) async {
    final bild = tester.getRect(find.byKey(const Key('schlaf-spannen-bild')));
    final geste = await tester.startGesture(
      Offset(abschnittsmitte(tester, i), bild.center.dy),
    );
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();
    return geste;
  }

  Future<void> lass(WidgetTester tester, TestGesture geste) async {
    await geste.up();
    await tester.pumpAndSettle();
  }

  Widget puls(List<ValueSpan> spannen) => SchlafSpannenDiagramm(
    spannen: spannen,
    farbe: Palette.warn,
    groesse: 'dein Puls',
    einheit: 'Schlägen pro Minute',
  );

  Widget atmung(List<ValueSpan> spannen) => SchlafSpannenDiagramm(
    spannen: spannen,
    farbe: Palette.river,
    groesse: 'deine Atemfrequenz',
    einheit: 'Atemzügen pro Minute',
    nachkommastellen: 1,
  );

  // ───────────────────────────────────────────────────────────────────────
  // 1 · Keine Werteachse, keine Bezugslinie
  // ───────────────────────────────────────────────────────────────────────

  group('Die Werteachse ist weg', () {
    testWidgets('keine Rasterlinie trägt mehr ihre Zahl am Rand', (
      tester,
    ) async {
      await zeige(tester, puls(pulsNacht()));

      // Gebaut war eine Achse rechts mit Fünferschritten: 60 · 65 · 70 ·
      // 75. Die beiden Zahlen, die jetzt dastehen, sind 58 und 74 — und
      // die stehen am Balken, nicht am Rand.
      for (final rand in ['60', '65', '70', '75']) {
        expect(
          texte(tester),
          isNot(contains(rand)),
          reason:
              'Apple hat keine Werteachse — „genau so" heißt, dass auch die '
              'Zahlen am Rand verschwinden (#168)',
        );
      }
    });

    testWidgets('die Atemfrequenz zeigt keine ganzzahlige Achse mehr', (
      tester,
    ) async {
      await zeige(tester, atmung(atemNacht()));

      for (final rand in ['12', '13', '14', '15']) {
        expect(texte(tester), isNot(contains(rand)));
      }
    });

    testWidgets('nichts im Bild heißt mehr „Ruhepuls" oder „Normal"', (
      tester,
    ) async {
      await zeige(tester, puls(pulsNacht()));

      // Ein Wächter gegen das Zurückrutschen: Die Bezugslinie war Tims
      // Entscheidung vom 28.10.2026 und ist am 29.10. aufgehoben worden.
      // Der Vergleich zum eigenen Normalwert steht auf der Erholungsseite.
      for (final text in texte(tester)) {
        expect(text, isNot(contains('Ruhepuls')));
        expect(text, isNot(contains('Normal')));
      }
    });

    test('die Grenzen reichen weiter über die Messwerte hinaus', () {
      final grenzen = spannenAchsenGrenzen(tiefster: 58, hoechster: 74);

      expect(
        grenzen.bis,
        greaterThan(74),
        reason:
            'ohne die Luft klebte die höchste Kapsel am oberen Rand, und '
            'der Kreis mit seiner Beschriftung hätte keinen Platz',
      );
      expect(grenzen.von, lessThan(58));
    });

    test('eine Nacht ohne Schwankung bekommt trotzdem eine Höhe', () {
      final grenzen = spannenAchsenGrenzen(tiefster: 60, hoechster: 60);
      expect(
        grenzen.bis,
        greaterThan(grenzen.von),
        reason: 'durch null geteilt wird nirgends',
      );
    });

    test('die Luft ist oben und unten gleich groß', () {
      final grenzen = spannenAchsenGrenzen(tiefster: 58, hoechster: 74);

      expect(
        grenzen.bis - 74,
        closeTo(58 - grenzen.von, 1e-9),
        reason:
            'ohne Bezugslinie zieht nichts mehr einseitig an der Skala — '
            'die Nacht steht mittig',
      );
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // 2 · MIN und MAX am Balken
  // ───────────────────────────────────────────────────────────────────────

  group('Zwei beschriftete Punkte sagen, wann es am tiefsten war', () {
    testWidgets('„MAX." und „MIN." stehen mit ihren Werten im Bild', (
      tester,
    ) async {
      await zeige(tester, puls(pulsNacht()));

      expect(texte(tester), contains('MAX.'));
      expect(texte(tester), contains('MIN.'));
      expect(texte(tester), contains('74'));
      expect(
        texte(tester),
        contains('58'),
        reason:
            'fertig ist das Ticket, wenn ein Blick genügt, um zu sagen, wie '
            'tief der Puls war — ohne eine Achse zu lesen',
      );
    });

    testWidgets('die Marken sitzen über dem Abschnitt, in dem ihr Wert '
        'auftritt', (tester) async {
      await zeige(tester, puls(nachtMitSpitzenInDerMitte()));

      final bild = tester.getRect(find.byKey(const Key('schlaf-spannen-bild')));
      final abschnitt = bild.width / 8;

      expect(
        tester.getCenter(find.byKey(const Key('schlaf-spannen-max'))).dx,
        closeTo(abschnittsmitte(tester, 1), abschnitt / 2),
        reason:
            'der höchste Wert dieser Nacht (79) steht in Abschnitt 1 — '
            '„der tiefste Wert war 58, und zwar hier" ist die ganze Aussage',
      );
      expect(
        tester.getCenter(find.byKey(const Key('schlaf-spannen-min'))).dx,
        closeTo(abschnittsmitte(tester, 6), abschnitt / 2),
        reason: 'der tiefste Wert dieser Nacht (55) steht in Abschnitt 6',
      );
    });

    testWidgets('MAX steht über MIN', (tester) async {
      await zeige(tester, puls(nachtMitSpitzenInDerMitte()));

      expect(
        tester.getRect(find.byKey(const Key('schlaf-spannen-max'))).bottom,
        lessThan(
          tester.getRect(find.byKey(const Key('schlaf-spannen-min'))).top,
        ),
        reason: 'oben der Höchstwert, unten der Tiefstwert — nicht umgekehrt',
      );
    });

    testWidgets('bei gleichem Höchstwert gewinnt der frühere Abschnitt', (
      tester,
    ) async {
      // Die Nacht des Entwurfs trägt die 74 in Abschnitt 0 und in
      // Abschnitt 7. Einer muss es sein, und der frühere ist der, den man
      // zuerst liest.
      await zeige(tester, puls(pulsNacht()));

      final bild = tester.getRect(find.byKey(const Key('schlaf-spannen-bild')));
      expect(
        tester.getCenter(find.byKey(const Key('schlaf-spannen-max'))).dx,
        lessThan(bild.center.dx),
        reason:
            'zwei gleich hohe Abschnitte bekommen nicht zwei Marken, und '
            'die eine sitzt auf dem früheren',
      );
    });

    testWidgets('eine Lücke trägt keine Marke und zieht die Spanne nicht', (
      tester,
    ) async {
      // Abschnitt 0 und 7 tragen die 74 — fällt der erste aus, rutscht die
      // Marke auf den siebten, der Wert bleibt.
      await zeige(tester, puls(pulsNacht(leer: const {0})));

      final bild = tester.getRect(find.byKey(const Key('schlaf-spannen-bild')));
      expect(texte(tester), contains('74'));
      expect(
        tester.getCenter(find.byKey(const Key('schlaf-spannen-max'))).dx,
        greaterThan(bild.center.dx),
        reason: 'ein Abschnitt ohne Messung kann keinen Höchstwert tragen',
      );
    });

    testWidgets('fällt der höchste Abschnitt ganz weg, sinkt der Höchstwert', (
      tester,
    ) async {
      await zeige(tester, puls(pulsNacht(leer: const {0, 7})));

      expect(
        texte(tester),
        isNot(contains('74')),
        reason:
            'eine 74 ohne gemessenen Abschnitt behauptete eine Messung, die '
            'es nicht gibt',
      );
      expect(texte(tester), contains('70'));
    });

    testWidgets('die Marke der Atemfrequenz trägt ihre Nachkommastelle', (
      tester,
    ) async {
      await zeige(tester, atmung(atemNacht()));

      expect(texte(tester), contains('15,2'));
      expect(texte(tester), contains('11,6'));
      expect(
        texte(tester),
        isNot(contains('11.6')),
        reason: 'deutsches Dezimalkomma, kein Punkt',
      );
    });

    testWidgets('am Bildrand bleibt die Beschriftung im Bild', (tester) async {
      await zeige(tester, puls(pulsNacht()));

      final bild = tester.getRect(find.byKey(const Key('schlaf-spannen-bild')));
      for (final marke in ['schlaf-spannen-max', 'schlaf-spannen-min']) {
        final kasten = tester.getRect(find.byKey(Key(marke)));
        expect(kasten.left, greaterThanOrEqualTo(bild.left - 0.5));
        expect(
          kasten.right,
          lessThanOrEqualTo(bild.right + 0.5),
          reason:
              'der Höchstwert steht im ersten Abschnitt — die Schrift darf '
              'wandern, der Kreis bleibt stehen',
        );
      }
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // 3 · Der Satz über dem Diagramm
  // ───────────────────────────────────────────────────────────────────────

  group('Die Spanne steht als Satz über dem Diagramm', () {
    testWidgets('ohne Berührung nennt er die ganze Nacht', (tester) async {
      await zeige(tester, puls(pulsNacht()));

      expect(
        satz(tester),
        'Während du geschlafen hast, lag dein Puls bei 58 bis 74 Schlägen '
        'pro Minute.',
      );
    });

    testWidgets('die Atemfrequenz bekommt ihre eigenen Wörter', (tester) async {
      await zeige(tester, atmung(atemNacht()));

      expect(
        satz(tester),
        'Während du geschlafen hast, lag deine Atemfrequenz bei 11,6 bis '
        '15,2 Atemzügen pro Minute.',
      );
    });

    testWidgets('beim Halten spricht er vom gehaltenen Abschnitt', (
      tester,
    ) async {
      await zeige(tester, puls(pulsNacht()));

      final geste = await halte(tester, 4);
      final gelesen = satz(tester);
      await lass(tester, geste);

      // Abschnitt 4 der Nacht: 02:55 bis 03:51, 60 bis 67.
      expect(
        gelesen,
        'Von 02:55 bis 03:51 lag dein Puls bei 60 bis 67 Schlägen pro '
        'Minute.',
      );
    });

    testWidgets('der letzte Abschnitt endet am Ende der Nacht', (tester) async {
      await zeige(tester, puls(pulsNacht()));

      final geste = await halte(tester, 7);
      final gelesen = satz(tester);
      await lass(tester, geste);

      expect(
        gelesen,
        contains('bis 06:40'),
        reason:
            'hinter dem letzten Abschnitt steht kein nächster, aus dem man '
            'die Uhrzeit nehmen könnte — sie steht in der Nacht selbst',
      );
    });

    testWidgets('über einer Lücke sagt er „keine Messung", nie den '
        'Nachbarwert', (tester) async {
      await zeige(tester, puls(pulsNacht(leer: const {4})));

      final geste = await halte(tester, 4);
      final gelesen = satz(tester);
      await lass(tester, geste);

      expect(gelesen, 'Von 02:55 bis 03:51 liegt keine Messung vor.');
      expect(
        gelesen,
        isNot(contains('59')),
        reason:
            'der Nachbar links spannt 59 bis 66 — ihn hier zu zeigen, '
            'behauptete eine Messung, die es nicht gibt',
      );
    });

    testWidgets('nach dem Loslassen steht wieder die ganze Nacht da', (
      tester,
    ) async {
      await zeige(tester, puls(pulsNacht()));

      final geste = await halte(tester, 4);
      await lass(tester, geste);

      expect(satz(tester), startsWith('Während du geschlafen hast'));
    });

    testWidgets('er springt nicht — sein Platz ist auf zwei Zeilen '
        'festgelegt (#146)', (tester) async {
      // Der Satz über einer Lücke ist kürzer als der über der Nacht. Ohne
      // festen Platz zöge er sich auf eine Zeile zusammen und ließe alles
      // darunter springen — genau die Zeile, die Tim streichen ließ.
      await zeige(tester, puls(pulsNacht(leer: const {4})));

      final vorher = tester.getRect(
        find.byKey(const Key('schlaf-spannen-satz')),
      );
      final bildVorher = tester.getRect(
        find.byKey(const Key('schlaf-spannen-bild')),
      );

      final geste = await halte(tester, 4);
      final waehrend = tester.getRect(
        find.byKey(const Key('schlaf-spannen-satz')),
      );
      final bildWaehrend = tester.getRect(
        find.byKey(const Key('schlaf-spannen-bild')),
      );
      await lass(tester, geste);

      expect(waehrend, vorher);
      expect(bildWaehrend, bildVorher);
    });

    testWidgets('am linken Rand fällt die Berührung auf den ersten '
        'Abschnitt', (tester) async {
      await zeige(tester, puls(pulsNacht()));

      final geste = await halte(tester, 0);
      final gelesen = satz(tester);
      await lass(tester, geste);

      // Abschnitt 0: 64 bis 74, ab 23:10.
      expect(gelesen, startsWith('Von 23:10 bis 00:06'));
      expect(gelesen, contains('64 bis 74'));
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // 4 · Die Zeitachse trägt nur an den Enden eine Uhrzeit
  // ───────────────────────────────────────────────────────────────────────

  group('Nur die beiden Enden der Zeitachse tragen eine Uhrzeit', () {
    testWidgets('Anfang und Ende der Nacht stehen da', (tester) async {
      await zeige(tester, puls(pulsNacht()));

      expect(texte(tester), contains('23:10'));
      expect(
        texte(tester),
        contains('06:40'),
        reason:
            'das rechte Ende ist das Ende der Nacht, nicht der Beginn des '
            'letzten Abschnitts',
      );
    });

    testWidgets('die Abschnitte dazwischen tragen keine mehr', (tester) async {
      await zeige(tester, puls(pulsNacht()));

      for (final uhrzeit in ['00:06', '01:02', '01:58', '02:55', '04:47']) {
        expect(
          texte(tester),
          isNot(contains(uhrzeit)),
          reason:
              'gebaut war jeder zweite Abschnitt beschriftet; Apple setzt '
              'nur die beiden Enden (#168)',
        );
      }
    });

    testWidgets('eine Lücke am Rand lässt die Enden stehen', (tester) async {
      await zeige(tester, puls(pulsNacht(leer: const {0, 7})));

      expect(
        texte(tester),
        contains('23:10'),
        reason:
            'die Nacht fängt nicht später an, nur weil ihre erste Stunde '
            'fehlt',
      );
      expect(texte(tester), contains('06:40'));
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // 5 · Deutlich schmalere Kapseln, Kreise und Lückenrahmen
  // ───────────────────────────────────────────────────────────────────────

  group('Die Kapseln sind deutlich schmaler als vorher', () {
    test('eine Kapsel füllt nicht einmal mehr ein Achtel des Abschnitts', () {
      // Gebaut war sie gut ein Fünftel breit (0,22). Apples sind noch
      // einmal deutlich schmaler.
      expect(spannenKapselBreite(40), lessThan(40 / 8));
    });

    test('sie wird nie dünner als drei Punkt und nie breiter als fünf', () {
      expect(spannenKapselBreite(8), greaterThanOrEqualTo(3));
      expect(spannenKapselBreite(8), lessThanOrEqualTo(5));
      expect(spannenKapselBreite(200), lessThanOrEqualTo(5));
    });

    test('zwischen den Grenzen wächst sie mit dem Abschnitt', () {
      expect(spannenKapselBreite(40), greaterThan(spannenKapselBreite(35)));
    });

    test('der Kreis ist breiter als die Kapsel, auf der er sitzt', () {
      // Sonst verschwände er in ihr und markierte nichts.
      expect(
        spannenMarkenRadius(4),
        greaterThan(2),
        reason: 'eine Kapsel von vier Punkt hat einen Halbmesser von zwei',
      );
    });

    test('der Rahmen einer Messlücke reicht nur über die Messwerte', () {
      final rahmen = spannenLueckenRahmen(
        index: 3,
        abschnittsbreite: 40,
        oben: 33,
        unten: 85,
      );

      expect(rahmen.top, closeTo(33, 1e-9));
      expect(
        rahmen.bottom,
        closeTo(85, 1e-9),
        reason:
            'seit das Raster weg ist, wäre ein Rahmen von oben bis unten '
            'der stärkste Strich im Bild — und er behauptete eine Höhe, '
            'über die niemand etwas weiß',
      );
      expect(rahmen.left, greaterThan(3 * 40));
      expect(rahmen.right, lessThan(4 * 40));
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // 6 · Die Fußzeile
  // ───────────────────────────────────────────────────────────────────────

  group('Die Fußzeile sagt nur noch, wie grob verdichtet wurde', () {
    testWidgets('sie nennt die Länge eines Abschnitts, nicht mehr das '
        'Fenster', (tester) async {
      await zeige(tester, puls(pulsNacht()));

      // 450 min auf acht Abschnitte sind 56 min je Abschnitt. Anfang und
      // Ende stehen an der Zeitachse; zweimal dieselbe Uhrzeit ist das
      // nächste Paar, das auseinanderläuft.
      expect(fuss(tester), 'Je Abschnitt 56 min');
    });

    testWidgets('bei weniger Abschnitten steht eine andere Zahl', (
      tester,
    ) async {
      await zeige(tester, puls(pulsNacht(abschnitte: 6)));

      expect(
        fuss(tester),
        'Je Abschnitt 75 min',
        reason:
            'ohne sie liest man acht Kapseln als acht Messungen — '
            'tatsächlich steckt in jeder knapp eine Stunde',
      );
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // Woher die Bezugswerte kommen — der Provider lebt weiter
  // ───────────────────────────────────────────────────────────────────────

  /// **`nachtBezugswerteProvider` hat seit #168 keinen Aufrufer mehr**, weil
  /// die Bezugslinie weggefallen ist. Er bleibt trotzdem stehen und
  /// behält seine Fälle: Ihn mit zu entfernen wäre eine zweite Änderung in
  /// einem Ticket, das von etwas anderem handelt. Ob er bleibt, entscheidet
  /// Tim am Board.
  group('Ruhepuls und Normalwert des Erholung-Schirms', () {
    /// Ein Schnappschuss mit bekannten Medianen: dreißig Tage mit immer
    /// demselben Ruhepuls und derselben Atemfrequenz — der Median ist dann
    /// genau dieser Wert. Erfundene Zahlen.
    RecoverySnapshot schnappschuss({
      double? ruhepuls = 68,
      double? atmung = 14,
    }) {
      final heute = BerlinCalendar.startOfDay(DateTime.utc(2026, 10, 12));
      return RecoverySnapshot.make(
        days: [
          for (var i = 0; i < 30; i++)
            RecoveryDay(
              date: BerlinCalendar.addDays(heute, -i),
              restingHeartRate: ruhepuls,
              respiratoryRate: atmung,
            ),
        ],
        nights: const [],
        today: heute,
        sleepGoalHours: 8,
        bedtimeGoalMinutes: 22 * 60 + 30,
      );
    }

    ProviderContainer behaelter(RecoverySnapshot stand) {
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          erholungProvider.overrideWith(
            (ref) => ErholungZustand(
              daten: Bekannt<ErholungDaten>(
                ErholungDaten(
                  schnappschuss: stand,
                  nacht: null,
                  wochenminuten: null,
                ),
                stand: DateTime.utc(2026, 10, 12, 8),
                laeuft: false,
              ),
              ziele: Ziele.vorbelegung,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('der Ruhepuls ist der Median des Erholung-Schirms', () {
      final grundlinie = behaelter(schnappschuss())
          .read(nachtBezugswerteProvider);

      expect(grundlinie.restingHeartRate, closeTo(68, 1e-9));
      expect(grundlinie.respiratoryRate, closeTo(14, 1e-9));
    });

    test('ohne Erholungsdaten gibt es keine Bezugswerte', () {
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          erholungProvider.overrideWith(
            (ref) => const ErholungZustand(
              daten: NochNie<ErholungDaten>(),
              ziele: Ziele.vorbelegung,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(nachtBezugswerteProvider).restingHeartRate, isNull);
    });
  });
}
