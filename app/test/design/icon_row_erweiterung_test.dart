import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repit/design/icon_row.dart';

import 'support.dart';

/// Tests für die Erweiterung von `IconRow` um `value` und `big` (Baukasten
/// „Heute, kombiniert", Task H1). `IconRow` selbst stammt aus Task 9/11
/// (`icon_row.dart`, siehe `icon_row_test.dart`) — diese Datei kommt
/// **zusätzlich** hinzu, statt die bestehende Testdatei anzufassen (CLAUDE.md:
/// „Bestehende Tests rührst du nicht an"; Auftrag: „Die neun Dateien unter
/// app/test/design/ gehören anderen; leg eigene an").
///
/// Entwurfsgrundlage: `row({symbol, tint, title, subtitle, value, big,
/// opens, dead})` in `docs/screens/components.js` — `value` ist der Wert
/// rechts (z. B. „44 %", „Starten"), `big` vergrößert die Symbolkachel
/// (`.ic.lg` im CSS, vgl. die Übungszeile im Entwurf: „Drücken — Brust,
/// Schulter, Trizeps" mit `big: true`).
///
/// **Die Wasserzeile unten nutzt erfundene Zahlen, nicht das
/// Entwurfsbeispiel** — das Board hielt seine Behauptung „erfundene
/// Beispiele" auch hier nicht ein.
///
/// Zwei Dinge werden hier bewusst **nicht** geprüft:
/// - Die exakte Kantenlänge der vergrößerten Kachel (Pixelwert, Layout,
///   siehe CLAUDE.md) — stattdessen eine **relative** Prüfung: Das Symbol
///   muss bei `big: true` größer dargestellt werden als ohne, unabhängig
///   davon, welche zwei Pixelwerte die Implementierung konkret wählt.
/// - Wie `value` formatiert wird (Prozent, Wort, Zahl) — nur, dass der
///   übergebene Text überhaupt erscheint bzw. bei Weglassen nicht.
///
/// Die Chevron-Regel aus Task 11 ([erscheint nur bei gesetztem `onTap`])
/// wird hier zusätzlich in Kombination mit `value` abgesichert — eine
/// Regression, bei der `value` versehentlich den Chevron miterzwingt, wäre
/// sonst nur durch Zufall in der alten Testdatei aufgefallen.
void main() {
  const accent = Color(0xFF2B6A8A);

  bool istChevron(Widget widget) =>
      widget is Icon && widget.icon == CupertinoIcons.chevron_right;

  testWidgets('zeigt den uebergebenen Wert rechts in der Zeile', (
    tester,
  ) async {
    await tester.pumpWidget(
      huelle(
        const IconRow(
          title: 'Wasser',
          subtitle: '0,6 von 3,0 l',
          symbol: 'scale',
          accent: accent,
          value: '20 %',
        ),
      ),
    );

    expect(find.text('20 %'), findsOneWidget);
  });

  testWidgets('zeigt keinen Wert, wenn keiner uebergeben wird', (tester) async {
    await tester.pumpWidget(
      huelle(
        const IconRow(
          title: 'Wasser',
          subtitle: '0,6 von 3,0 l',
          symbol: 'scale',
          accent: accent,
        ),
      ),
    );

    expect(find.text('20 %'), findsNothing);
  });

  testWidgets(
    'zeigt trotz gesetztem Wert keinen Chevron, wenn onTap fehlt — die '
    'Chevron-Regel aus Task 11 gilt unveraendert weiter',
    (tester) async {
      await tester.pumpWidget(
        huelle(
          const IconRow(
            title: 'Wasser',
            symbol: 'scale',
            accent: accent,
            value: '20 %',
          ),
        ),
      );

      expect(find.byWidgetPredicate(istChevron), findsNothing);
    },
  );

  testWidgets('stellt das Symbol bei big: true groesser dar als ohne big', (
    tester,
  ) async {
    await tester.pumpWidget(
      huelle(const IconRow(title: 'Normal', symbol: 'scale', accent: accent)),
    );
    final normaleGroesse = tester.widget<Icon>(find.byType(Icon)).size;

    await tester.pumpWidget(
      huelle(
        const IconRow(
          title: 'Groß',
          symbol: 'dumbbell.fill',
          accent: accent,
          big: true,
        ),
      ),
    );
    final grosseGroesse = tester.widget<Icon>(find.byType(Icon)).size;

    expect(normaleGroesse, isNotNull);
    expect(grosseGroesse, isNotNull);
    expect(
      grosseGroesse!,
      greaterThan(normaleGroesse!),
      reason:
          'big: true steht im Entwurf für die größere Symbolkachel '
          '(.ic.lg), z. B. bei der Übungszeile "Drücken — Brust, '
          'Schulter, Trizeps".',
    );
  });
}
