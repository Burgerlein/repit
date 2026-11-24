import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/design/muskel_figur.dart';
import 'package:repit/gym/gym_trainings_provider.dart';

import '../design/muskel_figur_support.dart'
    show kMuskelFigurSeite, muskelnAuf, painterVon;
import 'gym_trainings_support.dart';

/// Widget-Tests für die **Figur der Kachel** in der Trainings-Übersicht
/// (#533 unter #531, Task 2.2; Spec 7.2, 7.5, 7.8): Welche Muskeln sie färbt,
/// wie sie sich dreht, was ein Tipp tut und was VoiceOver liest. Der Baustein
/// `MuskelFigur` selbst steht in `app/test/design/muskel_figur_test.dart`.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden. Hält der
/// Implementierende eine Erwartung für falsch, wird das **gemeldet, nicht
/// korrigiert**.
///
/// ## Was die Anforderung bewacht
///
/// - **Ein horizontaler Zug auf der Figur wechselt die Seite**, ein Tipp
///   darauf öffnet das Detail (Spec 7.5; Entscheidung von Tim, 19.11.2026).
///   Die Fläche des Zugs ist die Figur, **nicht die Kachel**.
/// - **Die Seite gehört dem Schirm** (`gymTrainingsSeiteProvider`), nicht der
///   Kachel: Sie überlebt Detail und Zurück (`32`) und beginnt immer „vorne"
///   (Spec 22 Nr. 2, 7.5).
/// - **Einfarbig** (Spec 7.2, 8.1): Die Kachel sagt „trifft diese Muskeln",
///   nicht „wie viel" — **eine** Farbe, und die gefärbte Menge ist genau
///   `WorkoutMuscles.trained`.
/// - **Der Vorlesetext nennt Zustand und Muskeln, nicht das Zeichen**
///   (`CLAUDE.md`): Seite **und** gefärbte Muskeln in Worten; VoiceOver kann
///   nicht wischen und bekommt die Aktion „Figur umdrehen".
///
/// ## Wer hat was entschieden
///
/// - **Entscheidungen von Tim:** Figur dreht sich per Swipe; Antippen der
///   Kachel öffnet das Detail; einfarbig (19.11.2026, Spec 7.5, 22 Nr. 2).
/// - **Vorschläge der Spec, hier vorausgesetzt:** Start immer „vorne" (17.10);
///   der Wortlaut des Vorlesetextes („Vorderseite, trifft Brust und vordere
///   Schulter") — geprüft werden **Stichwörter**: „Vorderseite"/„Rückseite"
///   und die deutschen Muskelnamen.
/// - **Festlegung des Test-Agenten:** Ein Zug in **jede** Richtung wechselt die
///   Seite (Spec: „vorne ↔ hinten"; es gibt nur zwei).
///
/// ## Was hier **nicht** geprüft wird
///
/// - **Die Kollision mit dem Zurück-Wisch am linken Rand** — sieht kein
///   Widget-Test; steht in der Prüfanleitung (Spec 7.5).
/// - **Die Animation des Drehens.**
/// - **Welche Farbe** — nur dass es eine ist.
void main() {
  final trainiert = {
    for (final id in [Workout.push.code, Workout.pull.code, Workout.legs.code])
      id: WorkoutMuscles.trained(WorkoutTemplates.byId(id)!.exercises),
  };

  Finder figurIn(String id) => find.descendant(
    of: find.byKey(kGymTrainingsFigur(id)),
    matching: find.byType(MuskelFigur),
  );

  MuskelFigur figur(WidgetTester tester, String id) =>
      tester.widget<MuskelFigur>(figurIn(id));

  Future<TrainingsHuelle> geoeffnet(
    WidgetTester tester, {
    Future<void> Function(HakenRepo repo)? vorher,
  }) async {
    final h = trainingsHuelle();
    await vorher?.call(h.repo);
    await oeffneUebersicht(tester, h);
    return h;
  }

  /// Ein Zug nach links — wie ein Daumen, der die Figur dreht.
  Future<void> ziehe(
    WidgetTester tester,
    String id, {
    Offset zug = const Offset(-70, 0),
  }) async {
    await tester.ensureVisible(find.byKey(kGymTrainingsFigur(id)));
    await tester.pumpAndSettle();
    await tester.drag(find.byKey(kGymTrainingsFigur(id)), zug);
    await tester.pumpAndSettle();
  }

  group('Die Figur der Kachel färbt `WorkoutMuscles.trained` — einfarbig', () {
    testWidgets('jede Kachel trägt genau die trainierten Muskeln', (
      tester,
    ) async {
      await geoeffnet(tester);

      for (final eintrag in trainiert.entries) {
        expect(
          figur(tester, eintrag.key).gefaerbt.keys.toSet(),
          eintrag.value,
          reason:
              '${eintrag.key}: Haupt- und Nebenmuskeln, einmal gerechnet vom '
              'Provider (Spec 5.5, 6.3)',
        );
      }
    });

    testWidgets('es ist eine Farbe, nicht eine je Muskel (Spec 7.2, 8.1)', (
      tester,
    ) async {
      await geoeffnet(tester);

      for (final id in trainiert.keys) {
        expect(
          figur(tester, id).gefaerbt.values.toSet(),
          hasLength(1),
          reason:
              '$id: „zwei Farblogiken auf derselben Figur wären eine falsche '
              'Auskunft" (Spec 8.1)',
        );
      }
    });

    testWidgets('die Kachel zeigt eine Seite — und beginnt „vorne"', (
      tester,
    ) async {
      final h = await geoeffnet(tester);

      for (final id in trainiert.keys) {
        expect(figur(tester, id).seite, MuskelSeite.vorne, reason: id);
        expect(
          h.container.read(gymTrainingsSeiteProvider(id)),
          MuskelSeite.vorne,
          reason: '$id: Startseite ist immer „vorne" (Spec 7.5)',
        );
        expect(
          find.descendant(
            of: find.byKey(kGymTrainingsKachel(id)),
            matching: find.byKey(kMuskelFigurSeite(MuskelSeite.hinten)),
          ),
          findsNothing,
          reason: '$id: nur eine Seite je Kachel',
        );
      }
    });

    testWidgets('ein Training ohne Muskeln hat dieselbe Figur — ungefärbt', (
      tester,
    ) async {
      await geoeffnet(
        tester,
        vorher: (repo) => legeTrainingOhneDauer(repo, 'E-OHNE'),
      );

      expect(
        figurIn('E-OHNE'),
        findsOneWidget,
        reason: 'Die Figur verschwindet nicht, weil nichts zu färben ist',
      );
      expect(figur(tester, 'E-OHNE').gefaerbt, isEmpty);
      expect(
        hoehe(tester, kGymTrainingsFigur('E-OHNE')),
        closeTo(hoehe(tester, kGymTrainingsFigur(Workout.push.code)), 0.5),
      );
    });
  });

  group('Der Zug dreht die Figur (Spec 7.5)', () {
    testWidgets('ein horizontaler Zug wechselt die Seite — die Kachel zeigt '
        'dann die Rückseite', (tester) async {
      final h = await geoeffnet(tester);

      await ziehe(tester, Workout.pull.code);

      expect(
        h.container.read(gymTrainingsSeiteProvider(Workout.pull.code)),
        MuskelSeite.hinten,
      );
      expect(figur(tester, Workout.pull.code).seite, MuskelSeite.hinten);
      expect(
        find.descendant(
          of: find.byKey(kGymTrainingsKachel(Workout.pull.code)),
          matching: find.byKey(kMuskelFigurSeite(MuskelSeite.hinten)),
        ),
        findsOneWidget,
      );
    });

    testWidgets('ein zweiter Zug dreht zurück — in jede Richtung', (
      tester,
    ) async {
      final h = await geoeffnet(tester);
      final seite = gymTrainingsSeiteProvider(Workout.legs.code);

      await ziehe(tester, Workout.legs.code, zug: const Offset(-70, 0));
      expect(h.container.read(seite), MuskelSeite.hinten);
      await ziehe(tester, Workout.legs.code, zug: const Offset(70, 0));
      expect(
        h.container.read(seite),
        MuskelSeite.vorne,
        reason: 'vorne ↔ hinten: es gibt nur zwei Seiten',
      );
      await ziehe(tester, Workout.legs.code, zug: const Offset(70, 0));
      expect(h.container.read(seite), MuskelSeite.hinten);
    });

    testWidgets('gedreht wird nur diese Kachel', (tester) async {
      final h = await geoeffnet(tester);

      await ziehe(tester, Workout.push.code);

      expect(
        h.container.read(gymTrainingsSeiteProvider(Workout.push.code)),
        MuskelSeite.hinten,
      );
      expect(
        h.container.read(gymTrainingsSeiteProvider(Workout.pull.code)),
        MuskelSeite.vorne,
      );
      expect(figur(tester, Workout.pull.code).seite, MuskelSeite.vorne);
    });

    testWidgets('ein Zug öffnet nicht das Detail', (tester) async {
      final h = await geoeffnet(tester);
      h.befehle.clear();

      await ziehe(tester, Workout.push.code);

      expect(
        find.byKey(kGymTrainingDetail),
        findsNothing,
        reason: '„Horizontaler Zug und Tipp kommen sich nicht in die Quere"',
      );
      expect(h.befehle, isEmpty);
      expect(find.byKey(kGymTrainings), findsOneWidget);
    });

    testWidgets('ein senkrechter Zug dreht nichts — er gehört dem Scrollen', (
      tester,
    ) async {
      final h = await geoeffnet(tester);
      // Eine Fläche, auf der die Seite scrollt: Nur dann konkurriert das
      // Scrollen um den Zug. Auf einer Fläche, die alles zeigt, bliebe der
      // senkrechte Zug herrenlos — und ein einzelner Erkenner gewinnt
      // herrenlose Züge beim Loslassen.
      tester.view.physicalSize = const Size(402, 400);
      await tester.pumpAndSettle();

      await ziehe(tester, Workout.push.code, zug: const Offset(0, -60));

      expect(
        h.container.read(gymTrainingsSeiteProvider(Workout.push.code)),
        MuskelSeite.vorne,
      );
    });

    testWidgets('ein Zug neben der Figur — auf dem Namen — dreht nichts', (
      tester,
    ) async {
      final h = await geoeffnet(tester);

      await tester.drag(
        find.byKey(kGymTrainingsName(Workout.push.code)),
        const Offset(-70, 0),
      );
      await tester.pumpAndSettle();

      expect(
        h.container.read(gymTrainingsSeiteProvider(Workout.push.code)),
        MuskelSeite.vorne,
        reason:
            'Die Fläche des Zugs ist die Figur, nicht die ganze Kachel '
            '(Spec 7.5)',
      );
    });

    testWidgets('die gedrehte Seite steht nach Detail und Zurück wieder da '
        '(`32`)', (tester) async {
      final h = await geoeffnet(tester);
      await ziehe(tester, Workout.pull.code);

      await tippe(tester, find.byKey(kGymTrainingsName(Workout.pull.code)));
      expect(find.byKey(kGymTrainingDetail), findsOneWidget);
      await zurueck(tester, h);

      expect(figur(tester, Workout.pull.code).seite, MuskelSeite.hinten);
      expect(
        h.container.read(gymTrainingsSeiteProvider(Workout.pull.code)),
        MuskelSeite.hinten,
      );
    });

    testWidgets('ein Tipp auf die Figur öffnet das Detail (Spec 7.5)', (
      tester,
    ) async {
      final h = await geoeffnet(tester);
      h.befehle.clear();

      await tippe(tester, find.byKey(kGymTrainingsFigur(Workout.push.code)));

      expect(find.byKey(kGymTrainingDetail), findsOneWidget);
      expect(h.befehle, hasLength(1));
      expect(h.befehle.single.ersetztStapel, isFalse);
      expect(
        h.container.read(gymTrainingsSeiteProvider(Workout.push.code)),
        MuskelSeite.vorne,
        reason: 'Ein Tipp dreht nicht',
      );
    });

    testWidgets('die zwei Punkte stehen bei jeder Kachel', (tester) async {
      await geoeffnet(tester);

      for (final id in trainiert.keys) {
        expect(
          find.byKey(kGymTrainingsPunkte(id)),
          findsOneWidget,
          reason: '$id: sie sagen, dass es eine zweite Seite gibt (7.2)',
        );
      }
    });
  });

  group('VoiceOver: Seite und Muskeln in Worten, Aktion „Figur umdrehen"', () {
    /// Ein Training mit neutralem Namen, damit kein Muskelname schon im Titel
    /// steht — und damit **kein** Wort aus der Muskelliste zufällig passt.
    Future<void> neutral(HakenRepo repo) =>
        legeEigenes(repo, 'E-1', name: 'Training X', tags: const []);

    final eigeneMuskeln = WorkoutMuscles.trained(zweiUebungen());

    testSemantik('vorne: Vorderseite und die dort liegenden Muskeln, keine '
        'untrainierten', (tester) async {
      await geoeffnet(tester, vorher: neutral);

      final text = semantikTexte(
        tester,
        find.byKey(kGymTrainingsKachel('E-1')),
      );

      expect(text, matches(RegExp('vorderseite|vorne')));
      expect(text, isNot(matches(RegExp('rückseite|hinten'))));
      final vorne = muskelnAuf(MuskelSeite.vorne);
      expect(
        eigeneMuskeln.intersection(vorne),
        isNotEmpty,
        reason: 'Vorbedingung: das Beispiel trifft vorne etwas',
      );
      for (final m in eigeneMuskeln.intersection(vorne)) {
        expect(text, contains(m.german.toLowerCase()), reason: m.german);
      }
      for (final m in Muscle.values.toSet().difference(eigeneMuskeln)) {
        expect(
          text,
          isNot(contains(m.german.toLowerCase())),
          reason: '${m.german} wird nicht trainiert — und nicht genannt',
        );
      }
    });

    testSemantik('nach dem Zug: Rückseite und die dort liegenden Muskeln', (
      tester,
    ) async {
      await geoeffnet(tester, vorher: neutral);

      await ziehe(tester, 'E-1');
      final text = semantikTexte(
        tester,
        find.byKey(kGymTrainingsKachel('E-1')),
      );

      expect(text, matches(RegExp('rückseite|hinten')));
      expect(text, isNot(matches(RegExp('vorderseite|vorne'))));
      final hinten = muskelnAuf(MuskelSeite.hinten);
      expect(
        eigeneMuskeln.intersection(hinten),
        isNotEmpty,
        reason: 'Vorbedingung: das Beispiel trifft hinten etwas',
      );
      for (final m in eigeneMuskeln.intersection(hinten)) {
        expect(text, contains(m.german.toLowerCase()), reason: m.german);
      }
    });

    testSemantik('ein Training ohne Muskeln nennt keinen — und sagt es nicht '
        'als „0 Muskeln"', (tester) async {
      await geoeffnet(
        tester,
        vorher: (repo) => legeTrainingOhneDauer(repo, 'E-OHNE'),
      );

      final text = semantikTexte(
        tester,
        find.byKey(kGymTrainingsKachel('E-OHNE')),
      );

      for (final m in Muscle.values) {
        expect(text, isNot(contains(m.german.toLowerCase())), reason: m.german);
      }
      expect(text, isNot(contains('strich')));
    });

    testSemantik('die Kachel nennt Namen, Dauer, Übungen und Tag in Worten', (
      tester,
    ) async {
      await geoeffnet(tester);

      final push = WorkoutTemplates.byId(Workout.push.code)!;
      final text = semantikTexte(
        tester,
        find.byKey(kGymTrainingsKachel(Workout.push.code)),
      );

      expect(text, contains('push'));
      expect(text, contains('${push.enteredMinutes}'));
      expect(text, contains('${push.exercises.length}'));
      expect(text, contains('übung'));
      expect(text, contains('gym'), reason: 'der Tag steht im Vorlesetext');
    });

    testSemantik('ein Entwurf liest sich als Entwurf', (tester) async {
      await geoeffnet(tester, vorher: (repo) => legeEntwurf(repo, 'ENT-1'));

      final text = semantikTexte(
        tester,
        find.byKey(kGymTrainingsKachel('ENT-1')),
      );

      expect(text, contains('entwurf'));
    });

    testSemantik('die graue Kachel liest „wird geladen" — ohne Ziffer', (
      tester,
    ) async {
      final repo = HakenRepo(neueDb())..alleTor = Completer<void>();
      final h = trainingsHuelle(repo: repo);
      await oeffneUebersicht(tester, h, warte: false);

      for (final key in [
        kGymTrainingsLaedtTemplates,
        kGymTrainingsLaedtEigene,
      ]) {
        final text = semantikTexte(tester, find.byKey(key));
        expect(text, contains('geladen'), reason: '$key');
        expect(text, isNot(matches(RegExp(r'\d'))), reason: '$key');
      }
    });

    testSemantik('die Aktion „Figur umdrehen" gibt es, und sie dreht', (
      tester,
    ) async {
      final h = await geoeffnet(tester);
      final seite = gymTrainingsSeiteProvider(Workout.pull.code);

      final aktionen =
          semantikAktionen(
            tester,
            find.byKey(kGymTrainingsKachel(Workout.pull.code)),
          ).where(
            (a) => a.aktion.label?.toLowerCase().contains('umdrehen') ?? false,
          );
      expect(
        aktionen,
        isNotEmpty,
        reason:
            'VoiceOver kann nicht wischen: Ohne die Aktion bliebe die '
            'Rückseite für immer unerreichbar (Spec 7.5)',
      );

      await fuehreAus(tester, aktionen.first);
      expect(h.container.read(seite), MuskelSeite.hinten);

      final danach =
          semantikAktionen(
            tester,
            find.byKey(kGymTrainingsKachel(Workout.pull.code)),
          ).where(
            (a) => a.aktion.label?.toLowerCase().contains('umdrehen') ?? false,
          );
      await fuehreAus(tester, danach.first);
      expect(h.container.read(seite), MuskelSeite.vorne);
    });
  });

  group('Hero-Tags (flutter#25218)', () {
    testWidgets('kein eigener Hero-Tag steht zweimal da — Übersicht und '
        'Detail übereinander', (tester) async {
      await geoeffnet(tester);
      await tippe(tester, find.byKey(kGymTrainingsName(Workout.push.code)));
      expect(find.byKey(kGymTrainingDetail), findsOneWidget);

      // Der Standard-Tag der Navigationsleiste (`_HeroTag`, je Navigator)
      // ist Sache des Frameworks und trägt den Übergang der Leisten; hier
      // zählen die Tags, die der Schirm selbst vergibt.
      final tags = tester
          .widgetList<Hero>(find.byType(Hero, skipOffstage: false))
          .map((hero) => hero.tag)
          .where((tag) => !tag.runtimeType.toString().contains('HeroTag'))
          .toList();

      expect(
        tags.toSet(),
        hasLength(tags.length),
        reason:
            'derselbe Schirm kann in mehreren Stapeln liegen — ein Tag, '
            'der in zwei gleich ist, kollidiert (Spec 7.6; es gibt keine '
            'eigenen Tags, solange keine Figur übergeht)',
      );
    });
  });
}
