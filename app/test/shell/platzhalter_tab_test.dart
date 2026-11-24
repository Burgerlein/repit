import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repit/shell/platzhalter_tab.dart';

import '../design/support.dart';

/// Isolierte Tests für `PlatzhalterTab` (Task 10, `lib/shell/platzhalter_tab.dart`).
///
/// Der Baustein zeigt den vier unbenutzbaren Tabs (Heute, Plan, Gym,
/// Ernährung) in M1 einen ruhigen, ehrlichen Hinweis — **kein** leerer
/// Schirm, der nach Fehler aussieht, und **keine** Fehlermeldung. Hier wird
/// nur geprüft, dass der Baustein die ihm übergebenen Texte tatsächlich
/// zeichnet und sich strukturell nicht wie ein Fehler verhält. Die
/// tatsächliche App-Beschriftung je Tab (welcher Text in `RootView` steht)
/// ist bewusst **nicht** Gegenstand dieser Datei — das wäre eine
/// Beschriftungsprüfung, und die verbietet `CLAUDE.md` für Widget-Tests.
/// Dass jeder der vier Tabs tatsächlich einen `PlatzhalterTab` mit nicht
/// leeren Texten zeigt, prüft stattdessen `root_view_test.dart`.
///
/// **Entscheidung, nicht mit Tim abgestimmt:** `titel`/`erklaerung` als
/// getrennte Pflichtfelder, parallel zu `IconRow.title`/`.subtitle` — ein
/// Titel für die Navigationsleiste, ein Fließtext für die Erklärung. Setzt
/// der Implementierende stattdessen ein einzelnes `text`-Feld oder einen
/// `Widget`-Slot um, bitte melden statt den Test umzuschreiben.
void main() {
  const titel = 'Testtitel';
  const erklaerung = 'Testerklaerung: Dieser Bereich ist noch nicht fertig.';

  testWidgets('zeigt Titel und Erklaerung als sichtbaren Text', (tester) async {
    await tester.pumpWidget(
      huelle(const PlatzhalterTab(titel: titel, erklaerung: erklaerung)),
    );

    expect(find.text(titel), findsOneWidget);
    expect(find.text(erklaerung), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'baut ohne Ausnahme und ohne ein ErrorWidget — sieht nicht wie ein Fehler aus',
    (tester) async {
      await tester.pumpWidget(
        huelle(const PlatzhalterTab(titel: titel, erklaerung: erklaerung)),
      );

      expect(find.byType(ErrorWidget), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'zeigt weiterhin Titel und Erklaerung, wenn die Erklaerung lang ist',
    (tester) async {
      // Ein Platzhalter, der nur für kurze Texte funktioniert, bräche beim
      // ersten etwas ausführlicheren Hinweis still (abgeschnittener Text
      // sähe wieder aus wie ein Fehler). Kein Pixel-Test, nur: Beide Texte
      // sind im Baum vorhanden, nichts wirft.
      const langeErklaerung =
          'Dieser Bereich ist noch nicht fertig. Aufbau und Inhalt werden in '
          'einer späteren Aufgabe ergänzt, und bis dahin bleibt diese Stelle '
          'absichtlich ruhig statt leer.';

      await tester.pumpWidget(
        huelle(const PlatzhalterTab(titel: titel, erklaerung: langeErklaerung)),
      );

      expect(find.text(titel), findsOneWidget);
      expect(find.text(langeErklaerung), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
