import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/design/platzhalter.dart'
    show Platzhalter, ohneWert;
import 'package:repit/gym/gym_verlauf_view.dart';
import 'package:repit/gym/gym_view.dart';
import 'package:repit/shell/router.dart' show AppRouterBefehl;

import 'support.dart';

/// Der **Zugang** zum Schirm „Letzte Trainings" (#79): die Zeile in der
/// Gruppe „Auswertung" und der Knopf „Verlauf" in der Fokus-Karte des
/// Gym-Schirms (#77).
///
/// Grundlage ist `docs/superpowers/specs/2026-11-11-gym-verlauf-design.md`,
/// Abschnitt 11, und die Fokus-Karten-Spec Abschnitte 7 und 11: „Sobald ein
/// Ziel steht, fällt der Zusatz weg, Chevron und `onTap` kommen dazu, und der
/// Wert wird gefüllt — je Zeile eine Änderung an genau einer Stelle."
///
/// **Diese Datei ersetzt die Aussage der älteren Gym-Tests, alle vier
/// Auswertungszeilen seien ohne Tür.** Seit #79 gilt das für drei von ihnen;
/// `gym_view_test.dart` ist an den betroffenen Stellen nachgezogen.
void main() {
  /// Eine **erfundene** Sitzung. 23:30 UTC am 04.03. ist 00:30 Berliner
  /// Zeit am 05.03. — der Wert der Zeile ist der Berliner Tag.
  final zuletzt = ImportedSession(
    id: 'ZULETZT',
    date: DateTime.utc(2026, 3, 4, 23, 30),
    workout: Workout.a,
    minutes: 65,
    note: null,
    exercises: const [
      ImportedExercise(
        exerciseId: 'benchPress',
        sets: [CompletedSet(weight: 60, reps: 10)],
      ),
    ],
  );

  /// Löst die Zeile oder den Knopf aus und liest den Befehl ab.
  Future<AppRouterBefehl?> loeseAus(
    WidgetTester tester,
    GymHuelle h,
    Finder ziel,
  ) async {
    await tester.ensureVisible(ziel);
    await tester.pumpAndSettle();
    await tester.tap(ziel, warnIfMissed: false);
    await tester.pumpAndSettle();
    return h.router.nimmBefehl();
  }

  /// Ob die Zeile eine Tür hat: ein Antipp-Auslöser **in** der Zeile (so
  /// baut `IconRow` sich, wenn `onTap` gesetzt ist) oder um sie herum.
  bool hatTuer(WidgetTester tester, Key zeile) {
    final innen = find.descendant(
      of: find.byKey(zeile),
      matching: find.byWidgetPredicate(
        (w) =>
            (w is GestureDetector && w.onTap != null) ||
            (w is CupertinoButton && w.onPressed != null),
      ),
    );
    return innen.evaluate().isNotEmpty || istTippbar(tester, find.byKey(zeile));
  }

  group('Die Zeile „Letzte Trainings"', () {
    testWidgets('hat eine Tür: Chevron da, tippbar, keine Ankündigung mehr', (
      tester,
    ) async {
      final h = gymHuelle(tagGeplant(zuletzt: zuletzt));
      await zeige(tester, h.app);

      expect(
        find.descendant(
          of: find.byKey(kZeileTrainings),
          matching: find.byIcon(CupertinoIcons.chevron_right),
        ),
        findsOneWidget,
        reason: '„Der Winkel folgt der Tür" — jetzt gibt es die Tür',
      );
      expect(hatTuer(tester, kZeileTrainings), isTrue);
      expect(
        flach(texteUnter(tester, kZeileTrainings)),
        isNot(matches(ankuendigung)),
        reason:
            'Der Zusatz „— folgt in einer späteren Aufgabe." fällt weg, '
            'sobald das Ziel steht — sonst stünde eine Ankündigung an einer '
            'Zeile, die längst funktioniert',
      );
    });

    testWidgets('führt über den AppRouter auf den Stapel des aktuellen Tabs '
        'zum Verlauf', (tester) async {
      final h = gymHuelle(tagGeplant(zuletzt: zuletzt));
      await zeige(tester, h.app);

      final befehl = await loeseAus(tester, h, find.byKey(kZeileTrainings));

      expect(befehl, isNotNull, reason: 'Die Zeile löst einen Befehl aus');
      expect(
        befehl!.ersetztStapel,
        isFalse,
        reason:
            '`AppTarget.aktuell`: auf den Stapel des Tabs, aus dem man '
            'kommt, nicht fest in den Gym-Tab (`CLAUDE.md`)',
      );
      final ziel = befehl.builder(tester.element(find.byType(GymView)));
      expect(ziel, isA<GymVerlaufView>());
    });

    testWidgets('die Tür ist auch beim Lesen offen — der Schirm besorgt '
        'seine Daten selbst', (tester) async {
      final h = gymHuelle(tagRuheLeer(laedt: true));
      await zeige(tester, h.app);

      final befehl = await loeseAus(tester, h, find.byKey(kZeileTrainings));

      expect(
        befehl,
        isNotNull,
        reason:
            'Der Verlauf liest selbst; er wartet nicht darauf, dass die '
            'Übersicht geladen hat',
      );
    });

    testWidgets('der Wert ist der Berliner Tag der jüngsten Sitzung', (
      tester,
    ) async {
      final h = gymHuelle(tagGeplant(zuletzt: zuletzt));
      await zeige(tester, h.app);

      final text = flach(texteUnter(tester, kZeileTrainings));
      expect(
        text,
        contains('05.03.'),
        reason: 'Tag und Monat, ohne Jahr, nach Berliner Zeit',
      );
      expect(text, isNot(contains('04.03.')));
    });

    testWidgets('ohne Trainings bleibt der Wert leer — keine 0, kein –/–, '
        'keine graue Form', (tester) async {
      final h = gymHuelle(tagGeplant());
      await zeige(tester, h.app);

      final text = flach(texteUnter(tester, kZeileTrainings));
      expect(
        text,
        isNot(matches(RegExp(r'\d{2}\.\d{2}\.'))),
        reason: 'Es gibt kein Datum zu nennen, und es wird keines erfunden',
      );
      expect(text, isNot(matches(nullAlsWert)));
      expect(text, isNot(contains(ohneWert)));
      expect(
        find.descendant(
          of: find.byKey(kZeileTrainings),
          matching: find.byType(Platzhalter),
        ),
        findsNothing,
        reason: 'Nachgesehen wurde — da kommt nichts mehr',
      );
    });

    testWidgets('die Zeile ohne Ziel führt weiter nirgendwohin', (
      tester,
    ) async {
      // „Fortschritt pro Übung" stand hier, bis sie mit #93 ihre Tür
      // bekam. (11.11.2026, TEST_AENDERN=1) „Trainings"
      // (`gym-auswertung-plaene`, früher „Alle Pläne") stand hier, bis sie
      // mit #533 ihre Tür bekam: die Trainings-Übersicht (Spec 7.9). Tür und
      // Wert prüft `gym_trainings_zugang_test.dart`. (19.11.2026,
      // TEST_AENDERN=1)
      final h = gymHuelle(tagGeplant(zuletzt: zuletzt));
      await zeige(tester, h.app);

      for (final zeile in [kZeileMuskeln]) {
        expect(
          hatTuer(tester, zeile),
          isFalse,
          reason:
              '$zeile: Das Ziel fehlt weiter (#96) — eine Zeile, '
              'die aussieht wie ein Knopf und schweigt, ist der gesuchte '
              'Fehler',
        );
        final befehl = await loeseAus(tester, h, find.byKey(zeile));
        expect(befehl, isNull, reason: '$zeile');
      }
    });
  });

  group('Der Knopf „Verlauf" in der Fokus-Karte', () {
    Finder verlaufKnopf() => find.descendant(
      of: find.byKey(kAktionen),
      matching: find.widgetWithText(CupertinoButton, 'Verlauf'),
    );

    for (final fall in {
      'inProgress': tagLaeuft,
      'planned': tagGeplant,
    }.entries) {
      testWidgets('${fall.key}: ist wirksam und führt zum Verlauf', (
        tester,
      ) async {
        final h = gymHuelle(fall.value());
        await zeige(tester, h.app);

        expect(
          verlaufKnopf(),
          findsOneWidget,
          reason: '${fall.key}: Der Knopf steht da',
        );
        final knopf = tester.widget<CupertinoButton>(verlaufKnopf());
        expect(
          knopf.onPressed,
          isNotNull,
          reason: 'Ein Knopf ohne Ziel steht abgeblendet da — dieser hat eines',
        );
        expect(
          opazitaet(tester, verlaufKnopf()),
          1.0,
          reason: 'Nicht mehr abgeblendet',
        );

        final befehl = await loeseAus(tester, h, verlaufKnopf());

        expect(befehl, isNotNull);
        expect(befehl!.ersetztStapel, isFalse);
        expect(
          befehl.builder(tester.element(find.byType(GymView))),
          isA<GymVerlaufView>(),
        );
      });
    }
  });
}
