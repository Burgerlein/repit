import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/design/zeitdiagramm.dart';
import 'package:repit/design/zeitdiagramm_fenster.dart';
// Der Maler trägt, was das Bauteil ihm übergibt — hier: die fertige
// Beschriftung jeder Ziellinie. Das ist der einzige Weg, sie zu prüfen,
// ohne Pixel zu vergleichen.
import 'package:repit/design/zeitdiagramm_zeichnung.dart';
import 'package:repit/shell/diagramm_zeitraum.dart';

import 'support.dart' show huelle;

/// Tests für #178 — zwei Ziellinien dicht beieinander sind nicht zu
/// unterscheiden.
///
/// ## Der Befund (ausgerechnet, nicht vermutet)
///
/// Auf dem Schlaf-Verlauf stehen zwei waagerechte Linien: „Normal" auf dem
/// eigenen 30-Tage-Median und „Warnsignal" auf der festen Grenze von sechs
/// Stunden. Beide tragen denselben Wert in derselben Einheit, beide sind
/// richtig gerechnet — **es ist kein Rechenfehler.**
///
/// Die Zeichenfläche ist 120 Punkt hoch (Bildhöhe 148 aus
/// `docs/screens/components.css`, minus 8 Punkt Luft oben und 20 für die
/// Achse), Schlaf wird als Balken gezeichnet, die Achse beginnt also bei 0.
/// Liegt der Median bei 6:41 h und die Grenze bei 6:00 h und reicht die
/// Achse bis zur höchsten Nacht (hier 7,4), stehen die beiden Linien
/// `(6,683 − 6,0) / 7,4 · 120 ≈ 11,1` Punkt auseinander. Eine Beschriftung
/// reserviert zwölf Punkt über ihrer Linie
/// (`_beschriftungHoehe`). **Sie überlappen sich zwangsläufig** — und beide
/// trugen nur ihren Namen.
///
/// ## Zwei Hälften
///
/// 1. **Die Beschriftung trägt ihren Wert**: „Normal 6:41 h" statt
///    „Normal". Dann sind die beiden auch bei zehn Punkt Abstand nicht zu
///    verwechseln. So hält es das Entwurfsboard längst
///    (`lineChart` in `docs/screens/components.js`: „Der Name trägt den
///    Wert" — `Tagesziel 30 min`).
/// 2. **Zwei Beschriftungen überlagern sich nicht.** Die Zahl im Namen
///    macht sie unterscheidbar, nicht lesbar: Übereinandergedruckte Schrift
///    bleibt übereinandergedruckte Schrift. Der Mechanismus dafür steht
///    seit #162 da — eine Beschriftung kann **unter** ihre Linie fallen.
///
/// ## Entscheidungen dieser Datei — vom Agenten von #178, nicht von Tim
///
/// 1. **Die Zahl kommt vom Schirm, nicht vom Maler.** Ein Diagramm weiß
///    nicht, ob sein Wert Stunden, Minuten oder Schläge sind; beim Schlaf
///    muss „6:41 h" dastehen und nicht „6,7" (#151, Tims Entscheidung vom
///    28.10.2026). Geprüft wird deshalb, dass die Zeichenkette des Schirms
///    **unverändert** bis zum Maler durchkommt — nicht, wie sie entsteht.
///
/// 2. **Geprüft werden Lagen, keine Pixel.** Dass zwei Beschriftungen sich
///    nicht überlagern, ist eine Aussage über zwei Strecken auf der
///    y-Achse. Ein Pixelvergleich sagte dasselbe, aber erst nach einem
///    Schriftbild, einer Gerätegröße und einem Dunkelmodus.
///
/// 3. **Die Zahl im Namen ist weglassbar, und das ist festgehalten.** Ein
///    Doc-Kommentar, der zusichert, was der Code nicht durchsetzt, ist
///    schlimmer als gar keiner (`CLAUDE.md`). Ohne Zahl bleibt es beim
///    Namen allein; dass das noch möglich ist, steht hier als eigener Fall
///    da und nicht als Versprechen daneben.
///
/// 4. **Keine echten Gesundheitsdaten.** Alle Zahlen sind erfunden.
void main() {
  // ───────────────────────────────────────────────────────────────────────
  // Hülle
  // ───────────────────────────────────────────────────────────────────────

  DateTime tag(int jahr, int monat, int tag) =>
      BerlinCalendar.startOfDay(DateTime.utc(jahr, monat, tag));

  /// Eine volle Kalenderwoche ab dem 26.10.2026 mit den übergebenen Werten.
  List<({DateTime tag, double wert})> reihe(List<double> werte) => [
    for (var i = 0; i < werte.length; i++)
      (tag: BerlinCalendar.addDays(tag(2026, 10, 26), i), wert: werte[i]),
  ];

  /// Die Höhe der Zeichenfläche: 148 Punkt Bildhöhe, minus 8 Punkt Luft
  /// oben und 20 für die Achse (`components.css`, `.chart`).
  const flaeche = 120.0;
  const luftOben = 8.0;

  /// Der Platz, den eine Beschriftung in 9 Punkt belegt — zwölf Punkt,
  /// davon knapp elf Schrift.
  const beschriftungHoehe = 12.0;

  /// Die Lage einer Ziellinie in der Zeichenfläche, so wie der Maler sie
  /// rechnet: oben die Obergrenze der Achse, unten ihre Untergrenze.
  double linienY(double wert, (double, double) grenzen) =>
      luftOben +
      (1 - (wert - grenzen.$1) / (grenzen.$2 - grenzen.$1)) * flaeche;

  /// Ob sich zwei Beschriftungen von je [beschriftungHoehe] Punkt Höhe
  /// berühren oder überschneiden.
  bool ueberlappen(double a, double b) =>
      a < b + beschriftungHoehe && b < a + beschriftungHoehe;

  // ═══════════════════════════════════════════════════════════════════════
  // 1 · Die Beschriftung trägt ihren Wert
  // ═══════════════════════════════════════════════════════════════════════

  group('Die Beschriftung einer Ziellinie trägt ihren Wert', () {
    test('Name und Wert stehen zusammen in der Beschriftung', () {
      const linie = Ziellinie(
        name: 'Normal',
        wert: 6.683,
        wertText: '6:41 h',
        farbe: CupertinoColors.systemGrey,
      );

      expect(
        linie.beschriftung,
        'Normal 6:41 h',
        reason:
            'Dieses Diagramm hat keine Werteachse. Ohne die Zahl im Namen '
            'ließe sich die Linie nicht ablesen, und zwei Linien zehn Punkt '
            'auseinander wären nicht zu unterscheiden (#178)',
      );
    });

    test('die Zahl schreibt der Schirm, nicht der Maler', () {
      // „6:41 h" und nicht „6,7": Ein Diagramm weiß nicht, ob sein Wert
      // Stunden, Minuten oder Schläge sind (#151). Der Maler bekommt die
      // fertige Zeichenkette und fasst sie nicht an.
      const linie = Ziellinie(
        name: 'Tagesziel',
        wert: 30,
        wertText: '30 min',
        farbe: CupertinoColors.systemGreen,
      );

      expect(linie.beschriftung, 'Tagesziel 30 min');
      expect(
        linie.beschriftung.contains('30.0'),
        isFalse,
        reason:
            'Der Maler darf aus der Zahl nichts eigenes machen — „30.0" ist '
            'genau das, was dabei herauskäme',
      );
    });

    test('ohne Zahl bleibt es beim Namen allein', () {
      const linie = Ziellinie(
        name: 'Schlafziel',
        wert: 8,
        farbe: CupertinoColors.systemGreen,
      );

      expect(
        linie.beschriftung,
        'Schlafziel',
        reason:
            'Der Wert ist weglassbar, solange noch ein Aufrufer ohne ihn '
            'auskommt. Das steht hier als Fall da und nicht als Zusicherung '
            'daneben, die der Code nicht durchsetzt',
      );
    });

    test('eine andere Zahl macht zwei Linien ungleich', () {
      // Sonst zeichnete der Maler die alte Beschriftung weiter:
      // `shouldRepaint` vergleicht die Liste der Linien.
      final a = Ziellinie(
        name: 'Normal',
        wert: 6.683,
        wertText: '6:41 h',
        farbe: CupertinoColors.systemGrey,
      );
      final b = Ziellinie(
        name: 'Normal',
        wert: 6.683,
        wertText: '6:42 h',
        farbe: CupertinoColors.systemGrey,
      );

      expect(a, isNot(same(b)));
      expect(
        a,
        isNot(b),
        reason:
            'Gleiche Lage, andere Beschriftung — stünden sie gleich da, '
            'bliebe die alte Zahl im Bild stehen',
      );
    });

    testWidgets('der Maler bekommt die fertige Beschriftung', (tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        huelle(
          SizedBox(
            width: 360,
            height: 400,
            child: Zeitdiagramm(
              reihe: reihe(const [6.0, 7.1, 6.6, 5.7, 6.9, 7.4, 7.0]),
              stufen: const [DiagrammStufe.woche],
              fussnote: (_) => 'fuss',
              linien: const [
                Ziellinie(
                  name: 'Normal',
                  wert: 6.683,
                  wertText: '6:41 h',
                  farbe: CupertinoColors.systemGrey,
                ),
                Ziellinie(
                  name: 'Warnsignal',
                  wert: 6,
                  wertText: '6:00 h',
                  farbe: CupertinoColors.systemRed,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final maler = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((anstrich) => anstrich.painter)
          .whereType<ZeitdiagrammPainter>()
          .first;

      expect(
        [for (final linie in maler.linien) linie.beschriftung],
        ['Normal 6:41 h', 'Warnsignal 6:00 h'],
        reason:
            'Was der Schirm geschrieben hat, kommt unverändert beim Maler '
            'an — er setzt die Zahl nicht selbst',
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 2 · Zwei dichte Beschriftungen überlagern sich nicht
  // ═══════════════════════════════════════════════════════════════════════

  group('Zwei dichte Ziellinien tragen zwei lesbare Beschriftungen', () {
    test('der Fall aus #178: Median und feste Grenze', () {
      // Sieben Nächte, Median 6:41 h, Warnsignal 6:00 h — erfundene Zahlen
      // in der Größenordnung des gemeldeten Bildes.
      final stand = Fensterstand.aus(
        reihe: reihe(const [6.0, 7.1, 6.6, 5.7, 6.9, 7.4, 7.0]),
        stufe: DiagrammStufe.woche,
        verschiebung: 0,
      );
      final grenzen = stand.grenzen(
        linien: const [6.683, 6.0],
        alsBalken: true,
      );

      final normal = linienY(6.683, grenzen);
      final warnsignal = linienY(6.0, grenzen);
      expect(
        (warnsignal - normal).abs(),
        lessThan(beschriftungHoehe),
        reason:
            'Die Voraussetzung des Falls: Die beiden Linien liegen weniger '
            'als eine Beschriftungshöhe auseinander — sonst prüft dieser '
            'Fall nichts',
      );

      final lagen = ziellinienBeschriftungenY([normal, warnsignal]);
      expect(
        ueberlappen(lagen[0], lagen[1]),
        isFalse,
        reason:
            'Bei ${(warnsignal - normal).abs().toStringAsFixed(1)} Punkt '
            'Abstand und zwölf Punkt Beschriftungshöhe müssen die beiden '
            'auseinandertreten — sonst stehen „Normal" und „Warnsignal" '
            'übereinander (#178). Beschriftungen bei ${lagen[0]} und '
            '${lagen[1]}',
      );
    });

    test('eine einzelne Linie steht, wo sie immer stand', () {
      // Diese Änderung behebt eine Überlagerung, sie gestaltet die
      // Beschriftung nicht um: Wo nur eine Linie liegt, bleibt alles wie
      // seit #162.
      for (final y in const [20.0, 40.0, 60.0, 100.0, 125.0]) {
        expect(ziellinienBeschriftungenY([y]), [
          ziellinienBeschriftungY(y),
        ], reason: 'bei einer einzelnen Linie auf y = $y');
      }
    });

    test('keine zwei Beschriftungen überlagern sich, wo die Linien auch '
        'liegen', () {
      // Die ganze Zeichenfläche durch, in Zweierschritten: Es gibt kein
      // Paar von Ziellinien, dessen Beschriftungen übereinanderstehen.
      for (var a = luftOben; a <= luftOben + flaeche; a += 2) {
        for (var b = a; b <= luftOben + flaeche; b += 2) {
          final lagen = ziellinienBeschriftungenY([a, b]);
          if (a == b) continue; // Zwei Linien auf derselben Lage sind eine.
          expect(
            ueberlappen(lagen[0], lagen[1]),
            isFalse,
            reason:
                'Linien auf y = $a und y = $b, Beschriftungen bei '
                '${lagen[0]} und ${lagen[1]}',
          );
        }
      }
    });

    test('jede Beschriftung bleibt im Bild und von ihrer Linie weg', () {
      /// Die Höhe der Schrift selbst — knapp elf Punkt.
      const schrifthoehe = 11.0;

      for (var a = luftOben; a <= luftOben + flaeche; a += 2) {
        for (var b = a + 2; b <= luftOben + flaeche; b += 2) {
          final lagen = ziellinienBeschriftungenY([a, b]);
          for (final (i, y) in lagen.indexed) {
            final linie = i == 0 ? a : b;
            expect(
              y,
              greaterThanOrEqualTo(0),
              reason:
                  'Linien auf $a und $b: Beschriftung bei $y, das `clipRect` '
                  'schnitte sie weg',
            );
            expect(
              y + schrifthoehe <= linie || y >= linie,
              isTrue,
              reason:
                  'Linien auf $a und $b: Die Beschriftung bei $y läge auf '
                  'ihrer eigenen gestrichelten Linie bei $linie — die App '
                  'zeichnet keinen Hof hinter die Schrift',
            );
          }
        }
      }
    });

    test('die Reihenfolge der Linien ändert die Lagen nicht', () {
      // Welche Beschriftung ausweicht, darf nicht davon abhängen, in
      // welcher Reihenfolge der Schirm seine Linien übergibt: Der Schirm
      // sortiert sie nicht, und eine Liste, die einmal anders herum
      // ankommt, ließe das Bild springen.
      final hin = ziellinienBeschriftungenY([21.1, 32.0]);
      final zurueck = ziellinienBeschriftungenY([32.0, 21.1]);

      expect(zurueck, [hin[1], hin[0]]);
    });

    test('drei dichte Linien bleiben drei lesbare Beschriftungen', () {
      final lagen = ziellinienBeschriftungenY([40.0, 46.0, 52.0]);

      for (var i = 0; i < lagen.length; i++) {
        for (var j = i + 1; j < lagen.length; j++) {
          expect(
            ueberlappen(lagen[i], lagen[j]),
            isFalse,
            reason:
                'Beschriftung $i bei ${lagen[i]} und $j bei ${lagen[j]} — '
                'auch die dritte Linie braucht ihren eigenen Platz',
          );
        }
      }
    });
  });
}
