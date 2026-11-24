/// **#504 — `Zeitdiagramm` bekommt gestapelte Balken.**
///
/// `zweiteReihe`/`zweiteFarbe` ist eine zweite **Spur**, kein Stapel. Für
/// den Schlaf-Verlauf braucht das Bauteil eine echte Erweiterung: Ein
/// Balken behält seine Höhe und wird in sich geteilt.
///
/// ## Festgelegte öffentliche API
///
/// ```dart
/// // lib/design/zeitdiagramm.dart
///
/// class Zeitdiagramm extends StatefulWidget {
///   const Zeitdiagramm({
///     …,
///     /// Je Tag die **Teile**, nach denen sein Balken geteilt wird —
///     /// in derselben Einheit wie `reihe`. Leer heißt: einfarbig.
///     List<({DateTime tag, List<double> teile})> stapelReihe = const [],
///     /// Die Farbe je Teil, in derselben Reihenfolge wie die Teile.
///     List<CupertinoDynamicColor> stapelFarben = const [],
///   });
/// }
///
/// // lib/design/zeitdiagramm_zeichnung.dart
///
/// class ZeitdiagrammPainter extends CustomPainter {
///   final List<({int platz, List<double> teile})> stapel;
///   final List<Color> stapelFarben;
/// }
/// ```
///
/// ## Was hier geprüft wird — und was nicht
///
/// - **Additiv.** Ohne `stapelReihe` ändert sich nichts: Schritte und
///   Belastung zeichnen weiter einfache Balken, und der Maler bekommt
///   einen leeren Stapel. Das ist die Zusicherung, an der #504 hängt —
///   ein Umbau, der zwei fremde Schirme mitnimmt, wäre keiner.
/// - **Die Teile landen auf den Plätzen des Fensters**, nicht auf
///   Kalendertagen: Der Maler kennt nur Plätze.
/// - **Ab `6M` fällt ein Monat auf einen Platz**, und die Teile mehrerer
///   Nächte werden dort aufsummiert — der Anteil ist dann ein
///   Monatsschnitt, gewichtet mit den tatsächlichen Minuten.
/// - **Die Farben kommen aufgelöst beim Maler an.** Eine unaufgelöste
///   `CupertinoDynamicColor` bliebe im Dunkelmodus auf ihrer hellen
///   Variante stehen — dieselbe Regel, nach der `ZeitdiagrammPainter`
///   überhaupt fertige Farben entgegennimmt.
///
/// **Nicht geprüft, bewusst:** die gezeichneten Pixel. Was der Maler
/// bekommt, ist das, was im Bild landet; die Aufteilung der Höhe selbst
/// liegt als reine Funktion in `zeitdiagramm_stapel_test.dart`.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/design/palette.dart';
import 'package:repit/design/zeitdiagramm.dart';
import 'package:repit/design/zeitdiagramm_zeichnung.dart';
import 'package:repit/shell/diagramm_zeitraum.dart';

import 'support.dart' show huelle;

void main() {
  DateTime tag(int jahr, int monat, int tag) =>
      BerlinCalendar.startOfDay(DateTime.utc(jahr, monat, tag));

  /// Eine volle Woche, Montag 05.10.2026 bis Sonntag 11.10.2026.
  final woche = [
    for (var i = 0; i < 7; i++)
      (tag: BerlinCalendar.addDays(tag(2026, 10, 5), i), wert: 6.0 + i),
  ];

  /// Zu jeder Nacht der Woche zwei Teile, die zusammen ihre Höhe ergeben.
  final wochenStapel = [
    for (var i = 0; i < 7; i++)
      (
        tag: BerlinCalendar.addDays(tag(2026, 10, 5), i),
        teile: [2.0, 4.0 + i],
      ),
  ];

  Widget diagramm({
    List<({DateTime tag, double wert})>? reihe,
    List<({DateTime tag, List<double> teile})> stapelReihe = const [],
    List<CupertinoDynamicColor> stapelFarben = const [],
    List<DiagrammStufe> stufen = const [DiagrammStufe.woche],
  }) => Zeitdiagramm(
    reihe: reihe ?? woche,
    stufen: stufen,
    fussnote: (s) => 'fuss-${s.name}',
    stapelReihe: stapelReihe,
    stapelFarben: stapelFarben,
  );

  Future<void> zeige(
    WidgetTester tester,
    Widget kind, {
    Brightness helligkeit = Brightness.light,
  }) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      helligkeit == Brightness.light
          ? huelle(SizedBox(width: 360, height: 400, child: kind))
          : CupertinoApp(
              theme: const CupertinoThemeData(brightness: Brightness.dark),
              home: CupertinoPageScaffold(
                child: Center(
                  child: SizedBox(width: 360, height: 400, child: kind),
                ),
              ),
            ),
    );
    await tester.pumpAndSettle();
  }

  ZeitdiagrammPainter maler(WidgetTester tester) => tester
      .widgetList<CustomPaint>(
        find.descendant(
          of: find.byType(Zeitdiagramm),
          matching: find.byType(CustomPaint),
        ),
      )
      .map((anstrich) => anstrich.painter)
      .whereType<ZeitdiagrammPainter>()
      .single;

  List<double>? teileAufPlatz(ZeitdiagrammPainter m, int platz) {
    for (final eintrag in m.stapel) {
      if (eintrag.platz == platz) return eintrag.teile;
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════════

  group('Ohne Stapel bleibt alles, wie es war', () {
    testWidgets('der Maler bekommt einen leeren Stapel', (tester) async {
      await zeige(tester, diagramm());

      expect(
        maler(tester).stapel,
        isEmpty,
        reason:
            'Schritte und Belastung zeichnen weiter einfache Balken — die '
            'Erweiterung für #504 ist additiv',
      );
      expect(maler(tester).stapelFarben, isEmpty);
    });

    testWidgets('die Balken selbst sind unverändert da', (tester) async {
      await zeige(tester, diagramm());

      expect(maler(tester).balken.length, 7);
      expect(maler(tester).alsBalken, isTrue);
    });
  });

  group('Mit Stapel', () {
    testWidgets('jeder Tag der Woche bekommt seine Teile', (tester) async {
      await zeige(
        tester,
        diagramm(
          stapelReihe: wochenStapel,
          stapelFarben: const [Palette.riverDark, Palette.river],
        ),
      );

      expect(maler(tester).stapel.length, 7);
      expect(teileAufPlatz(maler(tester), 0), [2.0, 4.0]);
      expect(teileAufPlatz(maler(tester), 6), [2.0, 10.0]);
    });

    testWidgets('die Teile liegen auf denselben Plätzen wie die Balken', (
      tester,
    ) async {
      await zeige(
        tester,
        diagramm(
          stapelReihe: wochenStapel,
          stapelFarben: const [Palette.riverDark, Palette.river],
        ),
      );

      final m = maler(tester);
      expect(
        m.stapel.map((e) => e.platz).toSet(),
        m.balken.map((e) => e.platz).toSet(),
        reason: 'ein Stapel ohne Balken darunter stünde im Nichts',
      );
    });

    testWidgets('die Farben kommen aufgelöst an', (tester) async {
      // Geprüft wird im **Dunkelmodus**, weil nur dort ein Unterschied zu
      // sehen ist: `CupertinoDynamicColor.resolve` gibt wieder eine
      // `CupertinoDynamicColor` zurück, nur mit gesetztem Wert. Eine
      // unaufgelöste bliebe auf ihrer hellen Variante stehen — genau
      // deshalb nimmt `ZeitdiagrammPainter` überhaupt fertige Farben
      // entgegen.
      await zeige(
        tester,
        diagramm(
          stapelReihe: wochenStapel,
          stapelFarben: const [Palette.riverDark, Palette.river],
        ),
        helligkeit: Brightness.dark,
      );

      final farben = maler(tester).stapelFarben;
      expect(farben.length, 2);
      expect(farben[0].toARGB32(), Palette.riverDark.darkColor.toARGB32());
      expect(farben[1].toARGB32(), Palette.river.darkColor.toARGB32());
    });

    testWidgets('ein Tag ohne Teile bekommt keinen Stapel', (tester) async {
      await zeige(
        tester,
        diagramm(
          stapelReihe: [wochenStapel.first],
          stapelFarben: const [Palette.riverDark, Palette.river],
        ),
      );

      expect(teileAufPlatz(maler(tester), 0), isNotNull);
      expect(
        teileAufPlatz(maler(tester), 3),
        isNull,
        reason:
            'ohne Phasendaten steht der Balken einfarbig da, statt eine '
            'Verteilung zu erfinden (#504)',
      );
    });
  });

  group('Ab 6M ist ein Platz ein Kalendermonat', () {
    final zweiMonate = [
      (tag: tag(2026, 9, 10), wert: 6.0),
      (tag: tag(2026, 9, 20), wert: 8.0),
      (tag: tag(2026, 10, 5), wert: 7.0),
    ];
    final zweiMonateStapel = [
      (tag: tag(2026, 9, 10), teile: [1.0, 5.0]),
      (tag: tag(2026, 9, 20), teile: [3.0, 5.0]),
      (tag: tag(2026, 10, 5), teile: [2.0, 5.0]),
    ];

    testWidgets('die Teile eines Monats werden aufsummiert', (tester) async {
      await zeige(
        tester,
        diagramm(
          reihe: zweiMonate,
          stapelReihe: zweiMonateStapel,
          stufen: const [DiagrammStufe.halbjahr],
          stapelFarben: const [Palette.riverDark, Palette.river],
        ),
      );

      final m = maler(tester);
      // Zwei Monate im Bild, also zwei Stapel — nicht drei Nächte.
      final plaetze = m.stapel.map((e) => e.platz).toSet();
      expect(plaetze.length, 2);

      final september = m.stapel.firstWhere(
        (e) => e.platz == m.stapel.map((x) => x.platz).reduce(
          (a, b) => a < b ? a : b,
        ),
      );
      expect(
        september.teile,
        [4.0, 10.0],
        reason:
            'der Anteil eines Monats ist der Schnitt seiner Nächte, '
            'gewichtet mit den tatsächlichen Minuten (#504)',
      );
    });
  });
}
