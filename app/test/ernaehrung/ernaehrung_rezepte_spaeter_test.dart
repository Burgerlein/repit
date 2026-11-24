import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repit/design/icon_row.dart';

import 'tag_huelle.dart';

/// Tests für **#359** — „Ernährung: Rezepte als ‚kommt später'
/// kennzeichnen".
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Für Widget-Tests genügt ein Agent, solange der Test zuerst entsteht,
/// rot gesehen und committet wird. Danach darf diese Datei ausgeführt,
/// aber nicht verändert werden.
///
/// ## Tims Auftrag (04.11.2026)
///
/// „Auf der Ernährungsseite bei Rezepte wie bei Einkaufen hinschreiben,
/// dass es später kommt. Rezepte und Einkaufswagen werden noch nicht
/// gebaut."
///
/// ## Was „wie bei Einkaufen" heißt
///
/// Die Einkauf-Zeile steht seit #282 da, **ohne Tür**: kein `onTap`, kein
/// Winkel, abgeblendet, und ihr Untertitel sagt, dass sie später kommt
/// (`ErnaehrungRezepte` in `ernaehrung_abschnitte.dart`). Die Rezepte-Zeile
/// hatte dagegen eine Tür, hinter der ein Dialog „kommt später" stand —
/// eine Zeile, die aussieht wie eine Tür, und erst nach dem Tipp sagt,
/// dass dahinter nichts ist.
///
/// Verlangt wird deshalb für **beide** Zeilen dasselbe:
///
/// - Die Zeile steht da (eine Anzeige verschwindet nicht, weil ihre
///   Funktion fehlt — `CLAUDE.md`).
/// - Sie sagt **selbst**, dass sie später kommt: Unter ihr steht ein Text
///   mit „später".
/// - Sie ist **nicht antippbar** und zeigt keinen Winkel.
/// - Ein Tipp öffnet nichts — keinen Dialog, keinen Schirm.
///
/// **Nicht geprüft:** der genaue Wortlaut, die Farbe der Abblendung, die
/// Reihenfolge der beiden Zeilen.
///
/// ## Festlegung des Test-Agenten — nicht von Tim freigegeben
///
/// „Wie bei Einkaufen" ist als **dieselbe Form** gelesen, also auch ohne
/// Tür — nicht als „Tür behalten, Satz dazuschreiben". Der Entwurf
/// (`ernaehrung.js`, `REZEPTE`) zeichnet beide Zeilen mit `opens`; er ist
/// im selben Zug nachzuziehen (`CLAUDE.md`, „Entwurfsübersicht").
void main() {
  final jetzt = DateTime.utc(2026, 7, 14, 10);

  Finder zeile(String titel) => find
      .ancestor(
        of: find.descendant(
          of: find.byKey(const Key('ernaehrung-rezepte')),
          matching: find.text(titel),
        ),
        matching: find.byType(IconRow),
      )
      .first;

  for (final titel in ['Eigene Rezepte', 'Einkauf']) {
    group('„$titel" (#359)', () {
      testWidgets('steht da und sagt selbst, dass es später kommt', (
        tester,
      ) async {
        final h = tagHuelle(jetzt: jetzt);
        await zeigeTag(tester, h.app);

        expect(zeile(titel), findsOneWidget);
        final texte = [
          for (final e
              in find
                  .descendant(of: zeile(titel), matching: find.byType(RichText))
                  .evaluate())
            (e.widget as RichText).text.toPlainText(),
        ].join(' ').toLowerCase();
        expect(
          texte,
          contains('später'),
          reason:
              'die Zeile selbst sagt, dass sie später kommt — nicht erst ein '
              'Dialog nach dem Tipp (gefunden: „$texte")',
        );
      });

      testWidgets('ist nicht antippbar und zeigt keinen Winkel', (
        tester,
      ) async {
        final h = tagHuelle(jetzt: jetzt);
        await zeigeTag(tester, h.app);

        final row = tester.widget<IconRow>(zeile(titel));
        expect(
          row.onTap,
          isNull,
          reason: 'wie „Einkauf": keine Tür, solange dahinter nichts ist',
        );

        final textElement = find
            .descendant(
              of: find.byKey(const Key('ernaehrung-rezepte')),
              matching: find.text(titel),
            )
            .evaluate()
            .single;
        expect(
          tippbar(textElement),
          isFalse,
          reason: 'keine Zeile, die drückbar ist und nirgendwohin führt',
        );

        for (final winkel in [
          CupertinoIcons.chevron_right,
          CupertinoIcons.chevron_forward,
        ]) {
          expect(
            find.descendant(of: zeile(titel), matching: find.byIcon(winkel)),
            findsNothing,
            reason: 'ein Winkel verspricht eine Tür',
          );
        }
      });

      testWidgets('ein Tipp öffnet nichts', (tester) async {
        final h = tagHuelle(jetzt: jetzt);
        await zeigeTag(tester, h.app);

        await tester.tap(zeile(titel), warnIfMissed: false);
        await tester.pumpAndSettle();

        expect(find.byType(CupertinoAlertDialog), findsNothing);
        expect(
          find.byKey(const Key('ernaehrung-rezepte')).hitTestable(),
          findsOneWidget,
          reason:
              'der Tag steht weiter vorn — kein Schirm darüber, der „kommt '
              'später" sagt',
        );
      });
    });
  }
}
