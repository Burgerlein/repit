import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repit/shell/mehr_view.dart';
import 'package:repit/shell/router.dart';
import 'package:repit/uebernahme/uebernahme_view.dart';

/// Die **Tür** zum Schirm „Daten übernehmen" (#59 Teil 1): die Zeile in
/// *Mehr › Verwalten*, die bisher abgeblendet war und „folgt in einer
/// späteren Aufgabe" sagte.
///
/// Grundlage ist `docs/superpowers/specs/2026-11-11-gym-uebernahme-design.md`,
/// Abschnitt 7. **Wer Tests schreibt, schreibt nicht die Implementierung**
/// (`CLAUDE.md`).
///
/// **Diese Datei ersetzt Aussagen aus `test/shell/mehr_view_test.dart`**, die
/// „Daten übernehmen" unter den Zeilen ohne Ziel führen
/// (`inaktiveTitel`). Das habe der Test-Agent **nicht** nachgezogen — der
/// Auftrag verbot, einen bestehenden Test zu ändern. Wer die Tür baut, muss
/// dort „Daten übernehmen" von `inaktiveTitel` nach `aktiveTitel` verschieben;
/// das ist eine Teständerung und braucht `TEST_AENDERN=1` (Spec,
/// Abschnitt 14).
void main() {
  Future<AppRouter> zeigeMehr(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = AppRouter();
    await tester.pumpWidget(
      CupertinoApp(home: MehrView(router: router)),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('Die Zeile „Daten übernehmen" führt über den AppRouter auf den '
      'Stapel des aktuellen Tabs zum Schirm', (tester) async {
    final router = await zeigeMehr(tester);

    await tester.tap(find.text('Daten übernehmen'));
    await tester.pumpAndSettle();
    final befehl = router.nimmBefehl();

    expect(befehl, isNotNull, reason: 'Die Zeile löst einen Befehl aus');
    expect(
      befehl!.ersetztStapel,
      isFalse,
      reason: '`AppTarget.aktuell`: auf den Stapel des Tabs, aus dem man '
          'kommt',
    );
    final ziel = befehl.builder(tester.element(find.byType(MehrView)));
    expect(ziel, isA<UebernahmeSeite>());
  });

  testWidgets('Die Zeile trägt keine Ankündigung mehr', (tester) async {
    await zeigeMehr(tester);

    // Die übrigen Zeilen ohne Ziel tragen den Zusatz weiter; es gibt ihn
    // also noch, aber **nicht mehr an dieser Zeile**.
    final zeile = find.ancestor(
      of: find.text('Daten übernehmen'),
      matching: find.byType(Row),
    );
    final zeilenText = tester
        .widgetList<Text>(
          find.descendant(of: zeile.first, matching: find.byType(Text)),
        )
        .map((t) => t.data ?? '')
        .join(' ');
    expect(zeilenText, isNot(matches(RegExp(r'folgt|bald|später'))));
  });

  testWidgets('`oeffneUebernahme` ist die eine Stelle, die das Ziel kennt', (
    tester,
  ) async {
    final router = AppRouter();

    oeffneUebernahme(router);

    final befehl = router.nimmBefehl();
    expect(befehl, isNotNull);
    expect(befehl!.ersetztStapel, isFalse);
    await tester.pumpWidget(
      CupertinoApp(
        home: Builder(
          builder: (context) {
            expect(befehl.builder(context), isA<UebernahmeSeite>());
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  });
}
