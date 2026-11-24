import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/design/platzhalter.dart' show Platzhalter;
import 'package:repit/gym/gym_fortschritt_view.dart';
import 'package:repit/gym/gym_provider.dart';

import 'support.dart';

/// Die Zeile **„Fortschritt pro Übung"** in der Gruppe „Auswertung" des
/// Gym-Schirms (#77) — ab #93 hat sie ein Ziel.
///
/// Grundlage: `docs/superpowers/specs/2026-11-10-gym-fokus-karte-design.md`,
/// Abschnitt 7 („Sobald ein Ziel steht, fällt der Zusatz weg, Chevron und
/// `onTap` kommen dazu, und der Wert wird gefüllt — je Zeile eine Änderung
/// an genau einer Stelle"), und
/// `docs/superpowers/specs/2026-11-11-gym-fortschritt-design.md`, Abschnitt 9.
/// Die Hülle liegt in `support.dart` (#77), nur gelesen, nie verändert.
///
/// **Diese Datei prüft nur die eine Zeile.** Die drei anderen Zeilen
/// gehören anderen Tickets (#79, #96, #107); was für sie gilt, steht
/// weiter in `gym_view_test.dart` und `gym_view_leerzustaende_test.dart` —
/// und genau dort wird sich ändern, was für **diese** Zeile nicht mehr
/// stimmt (siehe Spec 9.4: Welche bestehenden Testfälle mit dem Schirm rot
/// werden und von wem sie nachgezogen werden).
///
/// Alle Daten sind erfunden.
void main() {
  /// Sätze, mit denen `Progression.suggest` auf **Steigern** steht: alle
  /// Sätze an der oberen Grenze.
  List<List<CompletedSet>> steigern(String id) {
    final u = ExerciseCatalog.all[id]!;
    return [
      [
        CompletedSet(weight: 20, reps: u.repHigh),
        CompletedSet(weight: 20, reps: u.repHigh),
      ],
    ];
  }

  /// Sätze, mit denen der Vorschlag auf **Halten** steht: an der unteren
  /// Grenze, nicht darunter.
  List<List<CompletedSet>> halten(String id) {
    final u = ExerciseCatalog.all[id]!;
    return [
      [
        CompletedSet(weight: 20, reps: u.repLow),
        CompletedSet(weight: 20, reps: u.repLow),
      ],
    ];
  }

  GymTag mitVerlauf(Map<String, List<List<CompletedSet>>> verlauf) =>
      gymTagAus(heute: heute, plan: wochenplan, verlauf: verlauf);

  String zeilenText(WidgetTester tester) =>
      flach(texteUnter(tester, kZeileFortschritt));

  group('Die Zeile hat jetzt eine Tür', () {
    testWidgets('sie trägt einen Winkel und ist tippbar — in jedem der vier '
        'Zustände', (tester) async {
      for (final fall in alleVierZustaende().entries) {
        final h = gymHuelle(fall.value);
        await zeige(tester, h.app);

        expect(find.byKey(kZeileFortschritt), findsOneWidget, reason: fall.key);
        expect(
          find.descendant(
            of: find.byKey(kZeileFortschritt),
            matching: find.byIcon(CupertinoIcons.chevron_right),
          ),
          findsOneWidget,
          reason:
              '${fall.key}: „Der Winkel folgt der Tür" — und die Tür gibt '
              'es seit #93',
        );
        expect(
          istTippbar(tester, find.byKey(kZeileFortschritt)),
          isTrue,
          reason: fall.key,
        );
      }
    });

    testWidgets('der Zusatz „folgt in einer späteren Aufgabe" ist weg', (
      tester,
    ) async {
      final h = gymHuelle(tagGeplant());
      await zeige(tester, h.app);

      expect(
        zeilenText(tester),
        isNot(matches(ankuendigung)),
        reason:
            'Eine Zeile, die ein Ziel hat, kündigt keines mehr an — sonst '
            'steht dort eine Zusage, die nicht mehr stimmt',
      );
    });

    testWidgets('ein Tipp schiebt den Schirm auf den Stapel des aktuellen '
        'Tabs', (tester) async {
      final h = gymHuelle(tagGeplant());
      await zeige(tester, h.app);
      final tabVorher = h.router.tab;

      await tester.ensureVisible(find.byKey(kZeileFortschritt));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(kZeileFortschritt));
      await tester.pumpAndSettle();

      final befehl = h.router.nimmBefehl();
      expect(befehl, isNotNull, reason: 'Die Zeile löst einen Befehl aus');
      expect(befehl!.ersetztStapel, isFalse);
      expect(
        befehl.tab,
        tabVorher,
        reason:
            'Geschoben wird auf den Stapel des Tabs, aus dem man kommt '
            '(`AppTarget.aktuell`), nicht fest in den Gym-Tab',
      );
      expect(h.router.tab, tabVorher, reason: 'Kein Tab-Wechsel');
    });

    testWidgets('das Ziel ist die Seite „Fortschritt pro Übung"', (
      tester,
    ) async {
      final h = gymHuelle(tagGeplant());
      await zeige(tester, h.app);

      await tester.ensureVisible(find.byKey(kZeileFortschritt));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(kZeileFortschritt));
      await tester.pumpAndSettle();
      final befehl = h.router.nimmBefehl()!;

      late Widget gebaut;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            gebaut = befehl.builder(context);
            return const SizedBox.shrink();
          },
        ),
      );
      expect(gebaut, isA<GymFortschrittSeite>());
    });
  });

  group('Der Wert der Zeile', () {
    testWidgets('nennt, für wie viele Übungen der Vorschlag auf Steigern '
        'steht — und zählt Halten nicht mit', (tester) async {
      final h = gymHuelle(
        mitVerlauf({
          'benchPress': steigern('benchPress'),
          'inclineDumbbellPress': steigern('inclineDumbbellPress'),
          'lateralRaise': halten('lateralRaise'),
        }),
      );
      await zeige(tester, h.app);

      expect(
        zeilenText(tester),
        matches(RegExp(r'2\s*↑')),
        reason: 'Zwei von drei Übungen mit Verlauf stehen auf Steigern',
      );
    });

    testWidgets('mit einer Übung auf Steigern steht dort 1', (tester) async {
      final h = gymHuelle(
        mitVerlauf({
          'benchPress': steigern('benchPress'),
          'lateralRaise': halten('lateralRaise'),
        }),
      );
      await zeige(tester, h.app);

      expect(zeilenText(tester), matches(RegExp(r'1\s*↑')));
    });

    testWidgets('ohne Verlauf steht dort keine 0', (tester) async {
      final h = gymHuelle(tagGeplant());
      await zeige(tester, h.app);

      expect(
        zeilenText(tester),
        isNot(matches(nullAlsWert)),
        reason:
            '„0 ↑" behauptete, es sei nachgesehen worden, und nichts sei '
            'zu steigern — eine Null ist keine Antwort auf „kein Wert" '
            '(`CLAUDE.md`)',
      );
    });

    testWidgets('mit Verlauf, aber ohne Übung auf Steigern, steht dort '
        'ebenfalls keine 0', (tester) async {
      final h = gymHuelle(mitVerlauf({'lateralRaise': halten('lateralRaise')}));
      await zeige(tester, h.app);

      expect(zeilenText(tester), isNot(matches(nullAlsWert)));
      expect(zeilenText(tester), isNot(contains('↑')));
    });

    testWidgets('während des Lesens steht an der Stelle des Werts eine '
        'graue Form', (tester) async {
      final h = gymHuelle(tagRuheLeer(laedt: true));
      await zeige(tester, h.app);

      expect(
        find.descendant(
          of: find.byKey(kZeileFortschritt),
          matching: find.byType(Platzhalter),
        ),
        findsOneWidget,
      );
    });
  });
}
