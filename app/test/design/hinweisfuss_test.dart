import 'package:flutter_test/flutter_test.dart';

import 'package:repit/design/hinweisfuss.dart';

import 'support.dart';

/// Test für `Hinweisfuss` (Baukasten „Heute, kombiniert", Task H1), nach
/// `disclaimer` in `docs/screens/components.js`
/// (`'<div class="disc">' + esc(text) + '</div>'`).
///
/// Der Baustein ist bewusst so schlicht wie sein Entwurfs-Gegenstück: Er
/// zeigt genau den übergebenen Satz, nichts sonst. Entsprechend knapp fällt
/// die Prüfung aus — ein Vergleich mit `section_header_test.dart` (Task 9),
/// das für dieselbe Schlichtheit ebenfalls nur einen Test hat.
///
/// Welcher Text hineingeht (z. B. der Schätzungs-Hinweis aus
/// `heute-kombi.js`), ist Sache des Schirms, nicht dieses Bausteins — daher
/// kein Test auf einen bestimmten Wortlaut.
///
/// Der Beispielsatz unten ist frei formuliert, keine wörtliche Übernahme
/// aus dem Entwurf, und enthält keine Zahl — anders als an mehreren
/// anderen Stellen des Entwurfsboards (siehe `ringe_test.dart`,
/// `kacheln_test.dart` u. a.) steckt hier also kein Risiko, Tims echte
/// Werte mitzuschleppen.
void main() {
  testWidgets('zeigt den uebergebenen Text', (tester) async {
    await tester.pumpWidget(
      huelle(
        const Hinweisfuss(
          'Der Verbrauch ist eine Schätzung. Keine medizinische Bewertung.',
        ),
      ),
    );

    expect(
      find.text(
        'Der Verbrauch ist eine Schätzung. Keine medizinische Bewertung.',
      ),
      findsOneWidget,
    );
  });
}
