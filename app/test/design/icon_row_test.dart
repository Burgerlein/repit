import 'package:flutter/cupertino.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repit/design/icon_row.dart';

import 'support.dart';

/// Tests für `IconRow` (Task 9, `lib/design/icon_row.dart`), nach
/// `Sources/DesignSystem/InsetList.swift`.
///
/// Geprüft wird Struktur und Verhalten — nicht Pixel: Radius, Kachelgröße
/// (29×29 laut Swift-Quelle, 30×30 laut Brief — beides Layout) und Abstände
/// sind hier bewusst außen vor.
///
/// **Entscheidung, nicht mit Tim abgestimmt:** `symbol` ist als `String`
/// angenommen (ein Name aus `Symbole.tabelle`), nicht als `IconData` direkt
/// — parallel zu `Sources/Features/Shell/MoreView.swift`, wo jede Zeile
/// ebenfalls einen bloßen Namen (`"calendar"`, `"dumbbell"`, …) trägt und
/// erst `Image(systemName:)` ihn auflöst. In Dart übernimmt `symbole.dart`
/// diese Auflösung; `IconRow` bekommt weiterhin nur den Namen. Löst der
/// Implementierende das stattdessen über `IconData` direkt am Aufrufer,
/// bitte melden statt den Test umzuschreiben.
void main() {
  const accent = Color(0xFF2B6A8A);

  // Der Chevron ist seit dem *Mehr*-Menü aus Task 11 keine reine Verzierung
  // mehr, sondern eine Aussage: "das führt irgendwohin". Anlass war, dass
  // neun von zehn Zeilen dort in M1 nirgendwohin führen — abgeblendet, mit
  // einem Hinweis im Untertitel ("— folgt in einer späteren Aufgabe."), aber
  // bis dahin trotzdem mit Pfeil. Der Pfeil wird zuerst gesehen und sagt
  // "hier geht's weiter", während der Text "kommt noch" sagt — genau das
  // "sieht drückbar aus, führt nirgendwohin", gegen das sich
  // `docs/screens/pruefen.mjs` am Entwurfsboard richtet. Deshalb zeichnet
  // `IconRow` den Chevron jetzt nur noch, wenn `onTap` gesetzt ist, und
  // beide Richtungen müssen geprüft sein, nicht nur eine neue Icon-Zahl:
  // Eine Zeile ohne `onTap`, die trotzdem einen Pfeil zeigt, wäre derselbe
  // Fehler wie vorher, nur mit einer anderen Zahl im Test.
  bool istChevron(Widget widget) =>
      widget is Icon && widget.icon == CupertinoIcons.chevron_right;

  testWidgets(
    'zeigt Titel, Untertitel, Symbol und Chevron, wenn onTap gegeben ist',
    (tester) async {
      await tester.pumpWidget(
        huelle(
          IconRow(
            title: 'Titel',
            subtitle: 'Untertitel',
            symbol: 'calendar',
            accent: accent,
            onTap: () {},
          ),
        ),
      );

      expect(find.text('Titel'), findsOneWidget);
      expect(find.text('Untertitel'), findsOneWidget);
      expect(find.byWidgetPredicate(istChevron), findsOneWidget);
      // Symbolkachel + Chevron: zwei Icons, keines davon mit Beschriftung
      // geprüft (das wäre Pixel/Glyphe, siehe symbole_test.dart).
      expect(find.byType(Icon), findsNWidgets(2));
    },
  );

  testWidgets('zeigt keinen Chevron, wenn kein onTap gegeben ist', (
    tester,
  ) async {
    await tester.pumpWidget(
      huelle(const IconRow(title: 'Titel', symbol: 'calendar', accent: accent)),
    );

    expect(find.text('Titel'), findsOneWidget);
    expect(find.byWidgetPredicate(istChevron), findsNothing);
    // Die Symbolkachel bleibt — nur der Chevron fällt weg.
    expect(find.byType(Icon), findsOneWidget);
  });

  testWidgets('ruft onTap auf, wenn die Zeile angetippt wird', (tester) async {
    var getippt = 0;
    await tester.pumpWidget(
      huelle(
        IconRow(
          title: 'Titel',
          symbol: 'calendar',
          accent: accent,
          onTap: () => getippt++,
        ),
      ),
    );

    await tester.tap(find.byType(IconRow));
    await tester.pump();

    expect(getippt, 1);
  });

  testWidgets('ist antippbar, wenn onTap gegeben ist', (tester) async {
    // `handle.dispose()` läuft hier bewusst **inline am Ende des Testkörpers**,
    // nicht über `addTearDown`: `testWidgets` prüft auf offene
    // `SemanticsHandle`s als letzten Schritt der eigenen async-Funktion,
    // noch bevor `package:test` die via `addTearDown` registrierten
    // Aufräum-Callbacks abarbeitet. Mit `addTearDown` kommt das `dispose()`
    // dadurch zu spät und der Test schlägt mit "must be disposed" fehl, egal
    // was zuvor geprüft wurde — nachgestellt an einem Minimalbeispiel ohne
    // `IconRow`, das denselben Fehler zeigte und mit manuellem `dispose()`
    // grün lief.
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(
      huelle(
        IconRow(
          title: 'Titel',
          symbol: 'calendar',
          accent: accent,
          onTap: () {},
        ),
      ),
    );

    final semantics = tester.getSemantics(find.byType(IconRow));
    expect(semantics.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

    handle.dispose();
  });

  testWidgets('ist nicht antippbar, wenn kein onTap gegeben ist', (
    tester,
  ) async {
    // Siehe Begründung im vorigen Fall: `dispose()` inline, nicht über
    // `addTearDown`.
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(
      huelle(const IconRow(title: 'Titel', symbol: 'calendar', accent: accent)),
    );

    final semantics = tester.getSemantics(find.byType(IconRow));
    expect(
      semantics.getSemanticsData().hasAction(SemanticsAction.tap),
      isFalse,
    );

    handle.dispose();
  });
}
