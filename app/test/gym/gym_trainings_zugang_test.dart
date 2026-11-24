import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/design/platzhalter.dart' show Platzhalter;
import 'package:repit/gym/gym_training_editor_schluessel.dart'
    show kGymEditor, kGymEditorKopieHinweis;
import 'package:repit/gym/gym_trainings_provider.dart';

import 'gym_trainings_support.dart';
import 'support.dart' show ankuendigung, kZeilePlaene;

/// Widget-Tests für den **Zugang** zur Trainings-Übersicht (#533 unter #531,
/// Tasks 2.2 und 2.5; Spec 7.1, 7.9, 12): die Zeile „Trainings" im Gym-Tab,
/// ihr Wert, und die Bedienelemente der Übersicht, deren Ziel erst Scheibe 3
/// und 4 bringen.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden. Hält der
/// Implementierende eine Erwartung für falsch, wird das **gemeldet, nicht
/// korrigiert**.
///
/// ## Was die Anforderung bewacht
///
/// - **Die Zeile hat ein Ziel** und trägt deshalb einen Winkel; sie ersetzt
///   „Alle Pläne", das **nirgends** mehr in der Gym-Oberfläche steht
///   (Spec 7.9, 12 Nr. 7). Der Schlüssel `gym-auswertung-plaene` bleibt.
/// - **Der Wert ist `readyCount`** — die fertigen, startbaren Trainings,
///   **keine Entwürfe** (Spec 7.3, 7.9). Während des Ladens eine graue Form,
///   **nie „0"** (Fehler `01`); nach Detail und Zurück steht er wieder da,
///   ohne neues Lesen (`32`).
/// - **Die Wege in den Editor** (Plan 3.8, Spec 7.6): „+" und der Fuß-Knopf
///   „Eigenes Training anlegen" waren in M2 abgeblendet (Plan 2.5, Lücke 7).
///   Seit Task 3.8 sind sie wirksam und öffnen den Editor, neu — ohne
///   Kopie-Hinweis; sie tragen weiter keinen Text, der etwas verspricht.
/// - **Keine Behauptung, die der Code nicht zusichert** (Spec 12 Nr. 1): Der
///   Satz „… mit Bild und Technikhinweis in der Erfassung" steht nirgends.
///
/// ## Wer hat was entschieden
///
/// - **Entscheidungen von Tim:** Die Zeile heißt „Trainings", Symbol und
///   Platzierung unverändert (19.11.2026, Spec 7.9); Entwürfe sind weder
///   startbar noch einplanbar (19.11.2026).
/// - **Folgerung:** `readyCount` zählt keine Entwürfe (Spec 7.9).
/// - **Festlegung des Test-Agenten, nicht in der Spec:** Ist der Stand
///   gelesen, aber **leer** (alle Templates und alle Eigenen gelöscht), steht
///   in der Zeile **keine „0"**: Der Test mit der Gym-Hülle ohne Ablage
///   (`gym_view_test.dart`: „`0` ist keine Antwort auf „kein Wert"") verlangt
///   das, und der Stand „gelesen und leer" ist vom Stand „Lesen gescheitert"
///   nicht zu unterscheiden. Gemeldet; die Spec sagt dazu nichts.
void main() {
  final wert = RegExp(r'\d+');

  /// Die Zahl, die in der Zeile steht — oder `null`, wo keine steht.
  int? zeilenZahl(WidgetTester tester) {
    final treffer = wert.firstMatch(textUnter(tester, kZeilePlaene));
    return treffer == null ? null : int.parse(treffer.group(0)!);
  }

  Future<TrainingsHuelle> gym(
    WidgetTester tester, {
    HakenRepo? repo,
    Future<void> Function(HakenRepo repo)? vorher,
    bool warte = true,
  }) async {
    final h = trainingsHuelle(repo: repo);
    await vorher?.call(h.repo);
    await zeigeGym(tester, h, warte: warte);
    return h;
  }

  final zeile = find.byKey(kZeilePlaene);

  group('Die Zeile „Trainings"', () {
    testWidgets('heißt „Trainings" — „Alle Pläne" steht nirgends mehr', (
      tester,
    ) async {
      await gym(tester);

      expect(textUnter(tester, kZeilePlaene), contains('Trainings'));
      expect(
        alleTexteDes(tester),
        isNot(contains('Alle Pläne')),
        reason: 'Spec 12 Nr. 7: „Trainings" ersetzt „Alle Pläne"',
      );
    });

    testWidgets('hat ein Ziel: Winkel da, tippbar, keine Ankündigung mehr', (
      tester,
    ) async {
      await gym(tester);

      expect(
        find.descendant(
          of: zeile,
          matching: find.byIcon(CupertinoIcons.chevron_right),
        ),
        findsOneWidget,
        reason: '„Der Winkel folgt der Tür" — jetzt gibt es die Tür',
      );
      expect(hatAusloeser(tester, zeile), isTrue);
      expect(
        textUnter(tester, kZeilePlaene),
        isNot(matches(ankuendigung)),
        reason:
            'Der Zusatz „folgt in einer späteren Aufgabe" fällt weg, '
            'sobald das Ziel steht',
      );
    });

    testWidgets('führt über den AppRouter auf den Stapel des aktuellen Tabs '
        'zur Übersicht', (tester) async {
      final h = await gym(tester);
      final tabVorher = h.router.tab;
      h.befehle.clear();

      await tippe(tester, zeile);

      expect(h.befehle, hasLength(1));
      expect(
        h.befehle.single.ersetztStapel,
        isFalse,
        reason: '`AppTarget.aktuell`: nie fest in den Gym-Tab (`CLAUDE.md`)',
      );
      expect(h.router.tab, tabVorher, reason: 'Kein Tab-Wechsel');
      expect(find.byKey(kGymTrainings), findsOneWidget);
    });

    testWidgets('die Tür steht auch beim Lesen offen — die Übersicht besorgt '
        'ihre Daten selbst', (tester) async {
      final repo = HakenRepo(neueDb())..alleTor = Completer<void>();
      final h = await gym(tester, repo: repo, warte: false);
      h.befehle.clear();

      await tippe(tester, zeile, warte: false);

      expect(h.befehle, hasLength(1));
      expect(find.byKey(kGymTrainings), findsOneWidget);
    });

    testWidgets('die anderen drei Zeilen bleiben, wie sie waren', (
      tester,
    ) async {
      await gym(tester);

      for (final key in [
        const Key('gym-auswertung-fortschritt'),
        const Key('gym-auswertung-trainings'),
        const Key('gym-auswertung-muskeln'),
      ]) {
        expect(find.byKey(key), findsOneWidget, reason: '$key');
      }
      expect(
        hatAusloeser(tester, find.byKey(const Key('gym-auswertung-muskeln'))),
        isFalse,
        reason: '„Trainierte Muskeln" wartet weiter auf #96',
      );
    });
  });

  group('Der Wert ist `readyCount` (Spec 7.9)', () {
    testWidgets('drei Templates: „3"', (tester) async {
      await gym(tester);

      expect(zeilenZahl(tester), 3);
    });

    testWidgets('Eigene zählen mit, Entwürfe nicht', (tester) async {
      await gym(
        tester,
        vorher: (repo) async {
          await legeEigenes(repo, 'E-1');
          await legeEigenes(repo, 'E-2', name: 'Zweites');
          await legeEntwurf(repo, 'ENT-1');
        },
      );

      expect(
        zeilenZahl(tester),
        5,
        reason:
            'drei Templates und zwei fertige Eigene; der Entwurf zählt '
            'nicht (Spec 7.3, 7.9)',
      );
    });

    testWidgets('ein gelöschtes Eigenes nimmt die Zahl mit', (tester) async {
      final h = await gym(
        tester,
        vorher: (repo) => legeEigenes(repo, 'E-1'),
      );
      expect(zeilenZahl(tester), 4);

      await h.repo.loesche('E-1');
      leseNeu(h);
      await tester.pumpAndSettle();

      expect(zeilenZahl(tester), 3);
    });

    testWidgets('ein Template lässt sich nicht löschen, die Zahl bleibt '
        '(Spec 26 Nr. 1)', (tester) async {
      final h = await gym(tester);
      expect(zeilenZahl(tester), 3);

      await expectLater(h.repo.loesche(Workout.pull.code), throwsStateError);
      leseNeu(h);
      await tester.pumpAndSettle();

      expect(zeilenZahl(tester), 3);
    });

    testWidgets('ein neues Eigenes zählt nach neuem Lesen sofort', (
      tester,
    ) async {
      final h = await gym(tester);

      await legeEigenes(h.repo, 'E-1');
      leseNeu(h);
      await tester.pumpAndSettle();

      expect(zeilenZahl(tester), 4);
    });

    testWidgets('der Wert hängt am Filter der Übersicht nicht', (tester) async {
      final h = await gym(
        tester,
        vorher: (repo) => legeEigenes(repo, 'E-1', tags: ['Home']),
      );
      await tippe(tester, zeile);
      await tippe(tester, find.byKey(kGymTrainingsChip('Home')));
      await zurueck(tester, h);

      expect(
        zeilenZahl(tester),
        4,
        reason: 'Die Zahl zählt alle fertigen Trainings, nicht die gefilterten',
      );
    });
  });

  group('Während des Ladens: graue Form, nie „0" (`01`)', () {
    testWidgets('eine graue Form an der Stelle des Werts, keine Zahl', (
      tester,
    ) async {
      final repo = HakenRepo(neueDb())..alleTor = Completer<void>();
      await gym(tester, repo: repo, warte: false);

      expect(
        find.descendant(of: zeile, matching: find.byType(Platzhalter)),
        findsOneWidget,
      );
      expect(zeilenZahl(tester), isNull);
      expect(
        textUnter(tester, kZeilePlaene),
        isNot(matches(nullAlsWert)),
        reason:
            'Eine Null behauptete „keine Trainings", wo noch niemand '
            'nachgesehen hat',
      );
    });

    testWidgets('mit dem Lesen steht die Zahl da, der Platzhalter ist weg', (
      tester,
    ) async {
      final repo = HakenRepo(neueDb())..alleTor = Completer<void>();
      await gym(tester, repo: repo, warte: false);

      repo.alleTor!.complete();
      await tester.pumpAndSettle();

      expect(zeilenZahl(tester), 3);
      expect(
        find.descendant(of: zeile, matching: find.byType(Platzhalter)),
        findsNothing,
      );
    });

    testWidgets('die Zeile hat beim Laden dieselbe Höhe wie danach', (
      tester,
    ) async {
      final repo = HakenRepo(neueDb())..alleTor = Completer<void>();
      await gym(tester, repo: repo, warte: false);
      final laedt = tester.getSize(zeile);

      repo.alleTor!.complete();
      await tester.pumpAndSettle();

      expect(
        tester.getSize(zeile).height,
        closeTo(laedt.height, 0.5),
        reason: '„Werte da, keine Werte, lädt — dieselbe Höhe" (`CLAUDE.md`)',
      );
      expect(tester.getSize(zeile).width, closeTo(laedt.width, 0.5));
    });

    testWidgets('während neu gelesen wird, bleibt die Zahl stehen', (
      tester,
    ) async {
      final h = await gym(tester);
      expect(zeilenZahl(tester), 3);

      h.repo.alleTor = Completer<void>();
      h.container.invalidate(gymTrainingsQuelleProvider);
      await tester.pump(const Duration(milliseconds: 100));

      expect(zeilenZahl(tester), 3);
      expect(
        find.descendant(of: zeile, matching: find.byType(Platzhalter)),
        findsNothing,
        reason: 'Der Platzhalter gehört allein in den Ladezustand',
      );
    });

    testWidgets('Übersicht und zurück: die Zahl steht wieder da, ohne neues '
        'Lesen (`32`)', (tester) async {
      final h = await gym(tester);
      expect(zeilenZahl(tester), 3);
      final gelesen = h.repo.alleAufrufe;

      await tippe(tester, zeile);
      await zurueck(tester, h);

      expect(zeilenZahl(tester), 3);
      expect(
        find.descendant(of: zeile, matching: find.byType(Platzhalter)),
        findsNothing,
      );
      expect(
        h.repo.alleAufrufe,
        gelesen,
        reason: 'Der Stand wird gehalten, nicht je Rückkehr gelesen (`03`)',
      );
    });
  });

  group('Die Knöpfe der Übersicht führen in den Editor (Plan 3.8)', () {
    for (final eintrag in {
      '„+"': kGymTrainingsPlus,
      'der Fuß-Knopf': kGymTrainingsAnlegen,
    }.entries) {
      testWidgets('${eintrag.key} ist wirksam und öffnet den Editor, neu', (
        tester,
      ) async {
        final h = trainingsHuelle();
        await oeffneUebersicht(tester, h);

        expect(find.byKey(eintrag.value), findsOneWidget);
        expect(
          ohneWirkung(tester, eintrag.value),
          isFalse,
          reason: '${eintrag.value}: Ein Knopf mit Ziel ist nicht abgeblendet',
        );
        await tester.ensureVisible(find.byKey(eintrag.value));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(eintrag.value));
        await tester.pumpAndSettle();

        expect(find.byKey(kGymEditor), findsOneWidget);
        expect(
          find.byKey(kGymEditorKopieHinweis),
          findsNothing,
          reason: 'Neu, nicht Kopie',
        );
        expect(
          await h.repo.alle(),
          hasLength(3),
          reason: 'Öffnen legt nichts an (Spec 22 Nr. 3)',
        );
      });
    }

    testWidgets('sie versprechen nichts: kein „bald", kein „folgt"', (
      tester,
    ) async {
      final h = trainingsHuelle();
      await oeffneUebersicht(tester, h);

      for (final key in [kGymTrainingsPlus, kGymTrainingsAnlegen]) {
        expect(
          textUnter(tester, key),
          isNot(matches(verspricht)),
          reason: '$key: ohne Text, der etwas verspricht',
        );
      }
    });

    testWidgets('sie stehen auch im Leerzustand und beim Laden da — gleiche '
        'Form', (tester) async {
      final repo = HakenRepo(neueDb())..alleTor = Completer<void>();
      final h = trainingsHuelle(repo: repo);
      await oeffneUebersicht(tester, h, warte: false);

      expect(find.byKey(kGymTrainingsPlus), findsOneWidget);
      expect(find.byKey(kGymTrainingsAnlegen), findsOneWidget);
    });
  });

  group('Keine Zusage, die nicht stimmt (Spec 12)', () {
    testWidgets('die Übersicht verspricht nichts und behauptet kein Bild und '
        'keinen Technikhinweis', (tester) async {
      final h = trainingsHuelle();
      await legeEigenes(h.repo, 'E-1');
      await oeffneUebersicht(tester, h);

      final texte = textUnter(tester, kGymTrainings);
      expect(texte, isNot(matches(verspricht)));
      expect(
        texte,
        isNot(matches(RegExp('technikhinweis|mit bild', caseSensitive: false))),
        reason:
            'Nicht jede Übung hat ein Bild (Spec 12 Nr. 1): ein Satz, der es '
            'zusichert, wäre schlimmer als gar keiner',
      );
      expect(texte, isNot(contains('Alle Pläne')));
    });

    testWidgets('es gibt keinen Hinweisfuß mehr — in keinem Zustand '
        '(Spec 26 Nr. 2)', (tester) async {
      // Der Schlüssel steht hier als Literal: Er darf aus `lib` verschwinden,
      // ohne dass dieser Test nicht mehr übersetzt.
      const hinweisfuss = Key('gym-trainings-hinweis');
      final h = trainingsHuelle();
      await oeffneUebersicht(tester, h);
      expect(find.byKey(hinweisfuss), findsNothing, reason: 'mit Templates');

      await legeEigenes(h.repo, 'E-1');
      leseNeu(h);
      await tester.pumpAndSettle();
      expect(find.byKey(hinweisfuss), findsNothing, reason: 'mit Eigenen');
    });
  });
}
