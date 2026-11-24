import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/design/hypnogramm.dart';
import 'package:repit/health/health_types.dart';
import 'package:repit/shell/schlaf_abschnitte.dart';
import 'package:repit/shell/schlaf_zustand.dart';

import '../design/support.dart' show textOf;

/// **#140 — „Sieben Nächte" in Phasenfarben statt einfarbig.**
///
/// Der Abschnitt entstand mit dem Schlaf-Schirm (#92) und gab seinem Painter
/// genau **eine** Farbe, die von „Kern". Der Balken zeigt dadurch nur Lage
/// und Länge — und „die Regelmäßigkeit steckt in der Lage" steht als
/// Begründung darüber, aber die halbe Aussage fehlt.
///
/// Vorlage ist `NAECHTE` in `docs/screens/screens/schlaf.js` und der
/// Baustein `nightsChart` in `docs/screens/components.js`: Jede Nacht wird
/// nach Phasen gefärbt, darunter steht `stageLegend()`.
///
/// ## Festgelegte öffentliche API
///
/// ```dart
/// // lib/shell/schlaf_abschnitte.dart — unverändert
///
/// /// Lage und Länge der letzten sieben Nächte, je Nacht nach Phasen
/// /// gefärbt.
/// class SchlafNaechteDiagramm extends StatelessWidget {
///   const SchlafNaechteDiagramm({
///     super.key,
///     required List<SchlafNachtLage> lagen,
///   });
/// }
/// ```
///
/// Die Zuordnung Phase → Farbe und die Spurreihenfolge gibt es schon:
/// [SchlafPhasen] in `lib/design/hypnogramm.dart`. **Eine zweite wäre genau
/// der Fehler, den `wach_farbe_test.dart` und `hypnogramm_test.dart` schon
/// einmal abgefangen haben** — „Tief ist dunkler als Kern" gilt in beiden
/// Modi, und eine eigene Farbtabelle im Abschnitt drehte das wieder um.
///
/// ## Was hier geprüft wird — und was nicht
///
/// `CLAUDE.md`: Zustände und Übergänge, nicht Layout und Beschriftung.
///
/// - Jede **gemessene** Phase bekommt einen eigenen Abschnitt, in ihrer
///   Farbe aus [SchlafPhasen] und in deren Spurreihenfolge.
/// - Eine Phase ohne Minuten bekommt **keinen** Abschnitt — ein nullbreiter
///   behauptete eine Messung, die es nicht gab.
/// - Unspezifizierter Schlaf (ältere Uhren) geht nicht verloren.
/// - Im Dunkelmodus kommen die Farben aus derselben Zuordnung.
/// - Unter den Nächten steht die Legende der vier Phasen.
/// - Ohne Lagen stehen **beide** Möglichkeiten da („aufgezeichnet" und
///   „freigegeben") und keine Legende, die Phasen behauptet.
///
/// **Nicht geprüft, bewusst:** Breiten, Abstände und die Lage auf der
/// Nachtuhr. Geprüft wird die Zuordnung Phase → Farbe und Phase →
/// Abschnitt, nicht die Geometrie — die steht in `schlaf_zustand_test.dart`
/// als reine Rechnung.
///
/// **Nicht angefasst:** `lib/design/hypnogramm.dart`. Das Hypnogramm wird
/// unter **#141** neu entworfen, und das beginnt auf dem Board.
void main() {
  DateTime tagesbeginn(int tag) =>
      BerlinCalendar.startOfDay(DateTime.utc(2026, 10, tag));

  DateTime berlin(int tag, int stunde, [int minute = 0]) =>
      DateTime.utc(2026, 10, tag, stunde - 2, minute);

  /// Eine Nacht von 23:00 bis 06:00 mit allen vier Phasen.
  SchlafNachtLage lage({
    Map<SleepStage, double> phasen = const {
      SleepStage.core: 255,
      SleepStage.deep: 60,
      SleepStage.awake: 15,
      SleepStage.rem: 90,
    },
  }) => SchlafNachtLage(
    datum: tagesbeginn(12),
    von: berlin(11, 23),
    bis: berlin(12, 6),
    minutenJePhase: phasen,
  );

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

  /// Der Painter einer Nachtzeile — die [zeile]-te von oben.
  CustomPainter nachtPainter(WidgetTester tester, {int zeile = 0}) => tester
      .widgetList<CustomPaint>(
        find.descendant(
          of: find.byType(SchlafNaechteDiagramm),
          matching: find.byType(CustomPaint),
        ),
      )
      .map((flaeche) => flaeche.painter)
      .whereType<CustomPainter>()
      .elementAt(zeile);

  /// Dieselbe Form wie in `hypnogramm_test.dart`: Der Painter malt auf eine
  /// feste Fläche, damit `paints` ohne Layoutrechnung prüfen kann.
  void Function(Canvas) gemalt(CustomPainter painter) =>
      (canvas) => painter.paint(canvas, const Size(280, 14));

  Color farbeVon(WidgetTester tester, SleepStage phase) {
    final context = tester.element(find.byType(SchlafNaechteDiagramm));
    return CupertinoDynamicColor.resolve(SchlafPhasen.farbe(phase), context);
  }

  String textUnter(WidgetTester tester, Finder bereich) => tester
      .widgetList<Text>(
        find.descendant(of: bereich, matching: find.byType(Text)),
      )
      .map(textOf)
      .join(' ');

  // ───────────────────────────────────────────────────────────────────────

  group('Jede Nacht trägt ihre Phasen', () {
    testWidgets('vier Phasen, vier Abschnitte in der Spurreihenfolge', (
      tester,
    ) async {
      await zeige(tester, SchlafNaechteDiagramm(lagen: [lage()]));

      expect(
        gemalt(nachtPainter(tester)),
        paints
          ..rect(color: farbeVon(tester, SleepStage.awake))
          ..rect(color: farbeVon(tester, SleepStage.rem))
          ..rect(color: farbeVon(tester, SleepStage.core))
          ..rect(color: farbeVon(tester, SleepStage.deep)),
        reason:
            'die Reihenfolge ist `SchlafPhasen.reihenfolge` — dieselbe, die '
            'Hypnogramm und Legende benutzen',
      );
    });

    testWidgets('eine Phase ohne Minuten bekommt keinen Abschnitt', (
      tester,
    ) async {
      await zeige(
        tester,
        SchlafNaechteDiagramm(
          lagen: [
            lage(phasen: const {SleepStage.core: 300, SleepStage.deep: 120}),
          ],
        ),
      );

      expect(
        gemalt(nachtPainter(tester)),
        paintsExactlyCountTimes(#drawRect, 2),
        reason:
            'ein nullbreiter Abschnitt behauptete eine Phase, die in dieser '
            'Nacht nicht gemessen wurde',
      );
    });

    testWidgets('unspezifizierter Schlaf geht nicht verloren', (tester) async {
      await zeige(
        tester,
        SchlafNaechteDiagramm(
          lagen: [
            lage(phasen: const {SleepStage.unspecified: 420}),
          ],
        ),
      );

      expect(
        gemalt(nachtPainter(tester)),
        paints..rect(color: farbeVon(tester, SleepStage.unspecified)),
        reason:
            'ältere Uhren melden Schlaf ohne Phasenangabe — ihre Nacht '
            'bliebe sonst ein leerer Balken',
      );
    });

    testWidgets('im Dunkelmodus kommen die Farben aus derselben Zuordnung', (
      tester,
    ) async {
      await zeige(
        tester,
        SchlafNaechteDiagramm(lagen: [lage()]),
        helligkeit: Brightness.dark,
      );

      expect(
        gemalt(nachtPainter(tester)),
        paints
          ..rect(color: SchlafPhasen.farbe(SleepStage.awake).darkColor)
          ..rect(color: SchlafPhasen.farbe(SleepStage.rem).darkColor)
          ..rect(color: SchlafPhasen.farbe(SleepStage.core).darkColor)
          ..rect(color: SchlafPhasen.farbe(SleepStage.deep).darkColor),
        reason:
            '`SchlafPhasen.farbe` ist die eine Zuordnung — eine zweite im '
            'Abschnitt drehte „Tief ist dunkler als Kern" wieder um',
      );
    });
  });

  group('Die Legende', () {
    testWidgets('unter den Nächten stehen die vier Phasennamen', (
      tester,
    ) async {
      await zeige(tester, SchlafNaechteDiagramm(lagen: [lage()]));

      final text = textUnter(tester, find.byType(SchlafNaechteDiagramm));
      for (final phase in SchlafPhasen.reihenfolge) {
        expect(
          text,
          contains(SchlafPhasen.name(phase)),
          reason:
              'ohne Legende sagen die Farben nichts — der Entwurf setzt '
              '`stageLegend()` unter `nightsChart`',
        );
      }
    });

    testWidgets('ohne Lagen keine Legende, sondern beide Möglichkeiten', (
      tester,
    ) async {
      await zeige(tester, const SchlafNaechteDiagramm(lagen: []));

      final text = textUnter(
        tester,
        find.byType(SchlafNaechteDiagramm),
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
        text,
        isNot(contains(SchlafPhasen.name(SleepStage.rem).toLowerCase())),
        reason: 'eine Legende ohne Balken behauptete Phasen, die nicht da sind',
      );
    });
  });
}
