import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repit/shell/root_view.dart';

import '../design/support.dart' show huelle;

/// Isolierte Tests für `ErfassenKnopf`/`BogenEintrag` (task-navbar,
/// `lib/shell/root_view.dart`) — der (+)/(×)-Knopf mit Bogenmenü aus der
/// neuen Tableiste. Parallel zu `tab_badge_test.dart` aus Task 10: Ein
/// eigener, isoliert prüfbarer Baustein statt in `RootView` verwoben.
///
/// Quelle: `docs/screens/components.js` ab Zeile 158, insbesondere
/// `tabMenu()` und dessen Kommentarkopf. `root_view_test.dart` prüft nur,
/// dass `RootView` diesen Baustein tatsächlich verwendet (mit den drei
/// M1-Einträgen, alle ausgegraut); diese Datei prüft den Baustein selbst,
/// mit frei gewählten Beispieleinträgen (auch verfügbaren — in M1 kommt das
/// nirgends vor, aber der Baustein selbst ist nicht auf „immer ausgegraut"
/// beschränkt, genau wie `TabBadge` schon ohne echten Wert in M1 isoliert
/// mit einem Wert getestet wurde).
///
/// ## Festgelegte API
///
/// - `class BogenEintrag` (immutable):
///   `const BogenEintrag({required String titel, String? hinweis,
///   required String symbol, bool verfuegbar = true, VoidCallback? onTap})`.
///   `hinweis` ist optional (Untertitel, hier nirgends geprüft — CLAUDE.md:
///   keine Beschriftungsprüfung). `symbol` ist ein Name aus
///   `Symbole.tabelle`; diese Datei verwendet ausschließlich bereits
///   vorhandene Namen (`'list.bullet'`, `'target'`, `'heart'`, `'dumbbell'`,
///   `'ruler'`), nicht die auf dem Board für Barcode/Foto genannten
///   (`'expand'`, `'photo'`) — die fehlen noch in `Symbole.tabelle` und
///   sind nicht Gegenstand dieser isolierten Tests (siehe Bericht).
/// - `class ErfassenKnopf extends StatefulWidget`, mit einer Liste
///   `eintraege` (Typ `List<BogenEintrag>`) und einem Callback
///   `onErfassen` (Typ `VoidCallback`), beide `required`.
///   Der Hauptknopf trägt `Key('erfassen-knopf')`, unabhängig vom
///   Dreh-/Beschriftungszustand (+/×) — **derselbe Knopf**, nicht zwei.
/// - **Tippen (geschlossen)** ruft `onErfassen()` auf und öffnet den Bogen
///   nicht.
/// - **Langdrücken (geschlossen)** öffnet den Bogen (bis zu vier Einträge
///   aus `eintraege`, der Rest wird nicht gebaut — „höchstens vier" aus dem
///   Kommentarkopf von `tabMenu()`), ohne `onErfassen()` aufzurufen.
/// - **Tippen (offen)** schließt den Bogen wieder — derselbe Knopf.
/// - Jeder Eintrag ist über `find.text(titel)` auffindbar, solange der
///   Bogen offen ist. Ein Tipp auf einen Eintrag mit `verfuegbar: false`
///   ruft dessen `onTap` **nicht** auf und lässt ihn stehen (er verschwindet
///   nicht); ein Tipp auf einen Eintrag mit `verfuegbar: true` ruft dessen
///   `onTap` auf.
void main() {
  Future<void> vergroessern(WidgetTester tester) async {
    // Der Bogen liegt laut Board absolut über der ganzen Leiste (Radius 92
    // um einen Punkt 73 über der Unterkante) — auf der Default-Testfläche
    // könnten Einträge außerhalb des sichtbaren Bereichs landen und wären
    // dann für `tester.tap`/`find.text` nicht mehr sicher erreichbar.
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  const knopf = Key('erfassen-knopf');

  testWidgets('zeigt zu Beginn nur den Knopf, keinen Bogeneintrag', (
    tester,
  ) async {
    await vergroessern(tester);
    await tester.pumpWidget(
      huelle(
        ErfassenKnopf(
          eintraege: const [
            BogenEintrag(titel: 'Suchen', symbol: 'list.bullet'),
            BogenEintrag(titel: 'Ziele', symbol: 'target'),
          ],
          onErfassen: () {},
        ),
      ),
    );

    expect(find.byKey(knopf), findsOneWidget);
    expect(find.text('Suchen'), findsNothing);
    expect(find.text('Ziele'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tippen ruft die Erfassung auf und faehrt nichts auf', (
    tester,
  ) async {
    await vergroessern(tester);
    var gerufen = 0;
    await tester.pumpWidget(
      huelle(
        ErfassenKnopf(
          eintraege: const [
            BogenEintrag(titel: 'Suchen', symbol: 'list.bullet'),
          ],
          onErfassen: () => gerufen++,
        ),
      ),
    );

    await tester.tap(find.byKey(knopf));
    await tester.pumpAndSettle();

    expect(gerufen, 1);
    expect(
      find.text('Suchen'),
      findsNothing,
      reason: 'Tippen allein fährt den Bogen nicht auf.',
    );
  });

  testWidgets(
    'Langdruecken faehrt den Bogen auf, ohne die Erfassung aufzurufen',
    (tester) async {
      await vergroessern(tester);
      var gerufen = 0;
      await tester.pumpWidget(
        huelle(
          ErfassenKnopf(
            eintraege: const [
              BogenEintrag(titel: 'Suchen', symbol: 'list.bullet'),
              BogenEintrag(titel: 'Ziele', symbol: 'target'),
            ],
            onErfassen: () => gerufen++,
          ),
        ),
      );

      await tester.longPress(find.byKey(knopf));
      await tester.pumpAndSettle();

      expect(find.text('Suchen'), findsOneWidget);
      expect(find.text('Ziele'), findsOneWidget);
      expect(
        gerufen,
        0,
        reason:
            'Langdrücken öffnet nur den Bogen, es ruft nicht die Erfassung '
            'auf.',
      );
    },
  );

  testWidgets(
    'nach dem Auffahren schliesst ein erneutes Tippen denselben Knopf den '
    'Bogen wieder',
    (tester) async {
      await vergroessern(tester);
      await tester.pumpWidget(
        huelle(
          ErfassenKnopf(
            eintraege: const [
              BogenEintrag(titel: 'Suchen', symbol: 'list.bullet'),
            ],
            onErfassen: () {},
          ),
        ),
      );

      await tester.longPress(find.byKey(knopf));
      await tester.pumpAndSettle();
      expect(find.text('Suchen'), findsOneWidget);

      await tester.tap(find.byKey(knopf));
      await tester.pumpAndSettle();

      expect(
        find.text('Suchen'),
        findsNothing,
        reason:
            'Derselbe Knopf (jetzt das Kreuz) schließt den Bogen wieder — '
            'kein zweiter Knopf nötig.',
      );
    },
  );

  testWidgets('hoechstens vier Eintraege, auch wenn mehr uebergeben werden', (
    tester,
  ) async {
    await vergroessern(tester);
    await tester.pumpWidget(
      huelle(
        ErfassenKnopf(
          eintraege: const [
            BogenEintrag(titel: 'Eins', symbol: 'list.bullet'),
            BogenEintrag(titel: 'Zwei', symbol: 'target'),
            BogenEintrag(titel: 'Drei', symbol: 'heart'),
            BogenEintrag(titel: 'Vier', symbol: 'dumbbell'),
            BogenEintrag(titel: 'Fuenf', symbol: 'ruler'),
          ],
          onErfassen: () {},
        ),
      ),
    );

    await tester.longPress(find.byKey(knopf));
    await tester.pumpAndSettle();

    for (final titel in const ['Eins', 'Zwei', 'Drei', 'Vier']) {
      expect(find.text(titel), findsOneWidget, reason: titel);
    }
    expect(
      find.text('Fuenf'),
      findsNothing,
      reason: 'der Bogen trägt höchstens vier Einträge (tabMenu()-Vorgabe)',
    );
  });

  testWidgets(
    'ein nicht verfuegbarer Eintrag ist sichtbar, aber ein Tipp loest nichts '
    'aus und er verschwindet nicht',
    (tester) async {
      await vergroessern(tester);
      var gerufen = 0;
      await tester.pumpWidget(
        huelle(
          ErfassenKnopf(
            eintraege: [
              BogenEintrag(
                titel: 'Suchen',
                symbol: 'list.bullet',
                verfuegbar: false,
                onTap: () => gerufen++,
              ),
            ],
            onErfassen: () {},
          ),
        ),
      );

      await tester.longPress(find.byKey(knopf));
      await tester.pumpAndSettle();
      expect(find.text('Suchen'), findsOneWidget);

      await tester.tap(find.text('Suchen'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(gerufen, 0, reason: 'ausgegraute Einträge tun nichts');
      expect(
        find.text('Suchen'),
        findsOneWidget,
        reason:
            'er verschwindet nicht, er bleibt ausgegraut stehen — nicht '
            'weggelassen.',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('ein verfuegbarer Eintrag loest seinen eigenen Tipp aus', (
    tester,
  ) async {
    await vergroessern(tester);
    var gerufen = 0;
    await tester.pumpWidget(
      huelle(
        ErfassenKnopf(
          eintraege: [
            BogenEintrag(
              titel: 'Suchen',
              symbol: 'list.bullet',
              onTap: () => gerufen++,
            ),
          ],
          onErfassen: () {},
        ),
      ),
    );

    await tester.longPress(find.byKey(knopf));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Suchen'));
    await tester.pumpAndSettle();

    expect(gerufen, 1);
  });

  testWidgets('baut ohne Ausnahme, offen wie geschlossen', (tester) async {
    await vergroessern(tester);
    await tester.pumpWidget(
      huelle(
        ErfassenKnopf(
          eintraege: const [
            BogenEintrag(
              titel: 'Suchen',
              symbol: 'list.bullet',
              verfuegbar: false,
            ),
            BogenEintrag(
              titel: 'Barcode',
              symbol: 'target',
              verfuegbar: false,
            ),
            BogenEintrag(titel: 'Foto', symbol: 'heart', verfuegbar: false),
          ],
          onErfassen: () {},
        ),
      ),
    );

    expect(tester.takeException(), isNull);

    await tester.longPress(find.byKey(knopf));
    await tester.pumpAndSettle();
    expect(find.byType(ErrorWidget), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
