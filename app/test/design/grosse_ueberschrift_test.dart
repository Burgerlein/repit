import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repit/design/grosse_ueberschrift.dart';

import 'support.dart';

/// Tests für `GrosseUeberschrift` (Baukasten „Heute, kombiniert", Task H1,
/// noch ohne `lib/design/grosse_ueberschrift.dart` — die Implementierung
/// folgt in einem zweiten Schritt).
///
/// Entwurfsgrundlage: `large(title, lede)` in `docs/screens/components.js`
/// — Datum groß, darunter optional die Einordnung („Woche 2 von 38 · Vor
/// der OP"). Swift kennt dafür keine eigene Komponente (`t-large`/`t-lede`
/// stehen nur im CSS/JS-Entwurf); die beiden Felder sind hier deshalb neu
/// benannt, nicht aus einer Swift-Quelle übernommen.
///
/// **Entscheidung, nicht mit Tim abgestimmt:** Konstruktor positional für
/// den Titel, `einordnung` benannt und optional — spiegelt `large(title,
/// lede)`, bei dem `lede` ebenfalls weggelassen werden kann
/// (`(lede ? ... : '')` im Entwurf).
///
/// Geprüft wird nur, ob Titel und Einordnung erscheinen bzw. bei fehlender
/// Einordnung nichts Zusätzliches gezeigt wird — nicht Schriftgröße oder
/// Abstand (Layout, siehe CLAUDE.md).
///
/// Die Beispieltexte unten (Datum, Wochenzählung) sind reine Platzhalter
/// ohne Gesundheits- oder Körperbezug — anders als an mehreren anderen
/// Stellen des Entwurfsboards (siehe `ringe_test.dart`, `kacheln_test.dart`
/// u. a.) steckt hier keine von Tims echten Werten dahinter. Trotzdem:
/// Wer einen Baustein aus `docs/screens/screens/*.js` nachbaut, sollte
/// Zahlen vorher gegen `docs/SPEC.md` Abschnitt 1/3 und
/// `docs/sample_export.json` abgleichen — das Board selbst ist dafür noch
/// nicht bereinigt.
void main() {
  testWidgets('zeigt den Titel', (tester) async {
    await tester.pumpWidget(
      huelle(const GrosseUeberschrift('Dienstag, 14. Oktober')),
    );

    expect(find.text('Dienstag, 14. Oktober'), findsOneWidget);
  });

  testWidgets('zeigt die Einordnung, wenn sie uebergeben wird', (tester) async {
    await tester.pumpWidget(
      huelle(
        const GrosseUeberschrift(
          'Dienstag, 14. Oktober',
          einordnung: 'Woche 2 von 38 · Vor der OP',
        ),
      ),
    );

    expect(find.text('Woche 2 von 38 · Vor der OP'), findsOneWidget);
  });

  testWidgets(
    'zeigt keine zweite Zeile, wenn keine Einordnung uebergeben wird',
    (tester) async {
      await tester.pumpWidget(
        huelle(const GrosseUeberschrift('Dienstag, 14. Oktober')),
      );

      // Ohne `einordnung` darf nur der Titel als Text stehen — kein leerer
      // Platzhalter, keine zweite Zeile, die etwas behauptet, was nicht
      // uebergeben wurde.
      expect(find.byType(Text), findsOneWidget);
    },
  );
}
