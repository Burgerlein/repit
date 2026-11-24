import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repit/design/klapp_abschnitt.dart';
import 'package:repit/shell/erholung_abschnitte.dart';

import 'support.dart' show huelle, textOf;

/// Tests für [KlappAbschnitt] — `lib/design/klapp_abschnitt.dart` (#253).
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, nie verändert werden.
///
/// ## Woher das Bauteil kommt
///
/// Die Klapp-Mechanik stand bis zum 03.11.2026 genau einmal von Hand in
/// `ErholungTipps` (Tims Wunsch vom 27.10.2026, „unten die Tipps sollten
/// default eingeklappt sein"). Mit #253 kommen vier weitere Abschnitte auf
/// dem Schlaf-Schirm dazu. Fünfmal dieselbe Mechanik von Hand wäre fünfmal
/// die Gelegenheit, sie unterschiedlich falsch zu machen — also ein
/// Bauteil.
///
/// Im Entwurf heißt es `sectionCard({ title, hint, open: false })`
/// (`docs/screens/components.js`).
///
/// ## Die festgelegte API
///
/// ```dart
/// class KlappAbschnitt extends StatefulWidget {
///   const KlappAbschnitt({
///     super.key,
///     required String titel,
///     required Widget Function() inhalt,
///     String? hinweis,
///     Key? kopfSchluessel,
///     Key? inhaltSchluessel,
///     EdgeInsets randAbstand,
///   });
/// }
/// ```
///
/// [inhalt] ist eine **Funktion**, kein fertiges Widget: Zugeklappt soll
/// der Inhalt nicht nur unsichtbar sein, sondern gar nicht erst entstehen
/// (Hausregel 2 — was nicht zu sehen ist, wird auch nicht gerechnet).
///
/// ## Was hier geprüft wird — und was nicht
///
/// `CLAUDE.md`: **Zustände und Übergänge**, nicht Layout und Beschriftung.
/// Kein Test schreibt eine Schriftgröße, einen Abstand oder einen Wortlaut
/// fest. Die drei Zustände sind: zu, offen, und „offen bleibt offen".
void main() {
  Widget abschnitt({
    String titel = 'Letzte 7 Nächte bis heute',
    String? hinweis,
    Widget Function()? inhalt,
  }) => huelle(
    KlappAbschnitt(
      titel: titel,
      hinweis: hinweis,
      kopfSchluessel: const Key('kopf'),
      inhaltSchluessel: const Key('inhalt'),
      inhalt: inhalt ?? () => const Text('der ganze Inhalt'),
    ),
  );

  String zeilenText(WidgetTester tester) => tester
      .widgetList<Text>(
        find.descendant(
          of: find.byKey(const Key('kopf')),
          matching: find.byType(Text),
        ),
      )
      .map(textOf)
      .join(' ');

  // ═════════════════════════════════════════════════════════════════════
  // 1 — Zugeklappt beim Bauen
  // ═════════════════════════════════════════════════════════════════════

  group('Im Ausgangszustand ist der Abschnitt zu', () {
    testWidgets('sein Inhalt steht nicht im Baum', (tester) async {
      await tester.pumpWidget(abschnitt());

      expect(find.byKey(const Key('inhalt')), findsNothing);
    });

    testWidgets('und er wird gar nicht erst gebaut — zugeklappt heißt nicht '
        'unsichtbar, sondern ungerechnet', (tester) async {
      var gebaut = 0;

      await tester.pumpWidget(
        abschnitt(
          inhalt: () {
            gebaut += 1;
            return const Text('der ganze Inhalt');
          },
        ),
      );

      expect(gebaut, 0);
    });

    testWidgets('die Zeile selbst steht trotzdem da — sie ist die Tür', (
      tester,
    ) async {
      await tester.pumpWidget(abschnitt());

      expect(find.byKey(const Key('kopf')), findsOneWidget);
      expect(zeilenText(tester), contains('Letzte 7 Nächte'));
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  // 2 — Auf und zu
  // ═════════════════════════════════════════════════════════════════════

  group('Auf und zu', () {
    testWidgets('ein Tipp auf die Zeile klappt auf', (tester) async {
      await tester.pumpWidget(abschnitt());

      await tester.tap(find.byKey(const Key('kopf')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('inhalt')), findsOneWidget);
    });

    testWidgets('ein zweiter Tipp klappt wieder zu', (tester) async {
      await tester.pumpWidget(abschnitt());

      await tester.tap(find.byKey(const Key('kopf')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('kopf')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('inhalt')), findsNothing);
    });

    testWidgets('der Inhalt entsteht erst beim Aufklappen', (tester) async {
      var gebaut = 0;

      await tester.pumpWidget(
        abschnitt(
          inhalt: () {
            gebaut += 1;
            return const Text('der ganze Inhalt');
          },
        ),
      );
      await tester.tap(find.byKey(const Key('kopf')));
      await tester.pumpAndSettle();

      expect(gebaut, greaterThan(0));
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  // 3 — Aufgeklappt bleibt aufgeklappt
  // ═════════════════════════════════════════════════════════════════════

  group('Aufgeklappt bleibt aufgeklappt', () {
    testWidgets(
      'auch wenn Hinweis und Inhalt sich ändern — ein offener Abschnitt ist '
      'ein Zustand der Oberfläche, kein abgeleiteter Wert (32)',
      (tester) async {
        await tester.pumpWidget(
          abschnitt(hinweis: 'Ø 7:12 h', inhalt: () => const Text('alt')),
        );

        await tester.tap(find.byKey(const Key('kopf')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('inhalt')), findsOneWidget);

        // Der nächste Durchlauf der Health-Daten: andere Zahl, anderer
        // Inhalt, dieselbe Stelle im Baum.
        await tester.pumpWidget(
          abschnitt(hinweis: 'Ø 6:40 h', inhalt: () => const Text('neu')),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('inhalt')), findsOneWidget);
        expect(find.text('neu'), findsOneWidget);
      },
    );

    testWidgets('und zugeklappt bleibt zugeklappt', (tester) async {
      await tester.pumpWidget(abschnitt(hinweis: 'Ø 7:12 h'));

      await tester.pumpWidget(abschnitt(hinweis: 'Ø 6:40 h'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('inhalt')), findsNothing);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  // 4 — Die Zahl in der Zeile
  // ═════════════════════════════════════════════════════════════════════

  group('Der Hinweis in der zugeklappten Zeile', () {
    testWidgets('steht neben dem Titel, wenn es ihn gibt', (tester) async {
      await tester.pumpWidget(abschnitt(hinweis: 'Ø 7:12 h'));

      expect(zeilenText(tester), contains('7:12'));
    });

    testWidgets(
      'fehlt er, steht dort nichts — keine 0 und kein Strich, der wie ein '
      'Messwert aussähe (CLAUDE.md)',
      (tester) async {
        await tester.pumpWidget(abschnitt());

        final zeile = zeilenText(tester);
        expect(zeile, isNot(contains('0')));
        expect(zeile, isNot(contains('—')));
        expect(zeile, isNot(contains('–/–')));
      },
    );
  });

  // ═════════════════════════════════════════════════════════════════════
  // 5 — Das Bauteil wird benutzt, nicht nachgebaut
  // ═════════════════════════════════════════════════════════════════════

  group('ErholungTipps zieht auf das Bauteil um', () {
    testWidgets('der Abschnitt ist ein KlappAbschnitt', (tester) async {
      await tester.pumpWidget(huelle(const ErholungTipps()));

      expect(find.byType(KlappAbschnitt), findsOneWidget);
    });

    testWidgets('und verhält sich unverändert: zu, auf, zu', (tester) async {
      await tester.pumpWidget(huelle(const ErholungTipps()));

      expect(find.byKey(const Key('erholung-tipps-inhalt')), findsNothing);

      await tester.tap(find.byKey(const Key('erholung-tipps-kopf')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('erholung-tipps-inhalt')), findsOneWidget);

      await tester.tap(find.byKey(const Key('erholung-tipps-kopf')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('erholung-tipps-inhalt')), findsNothing);
    });
  });
}
