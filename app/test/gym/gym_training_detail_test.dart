import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/design/muskel_figur.dart';
import 'package:repit/gym/gym_log_view.dart';
import 'package:repit/gym/gym_training_editor_schluessel.dart'
    show kGymEditor, kGymEditorKopieHinweis, kGymEditorLoeschen;
import 'package:repit/gym/gym_trainings_provider.dart';

import '../data/gym_training_support.dart' show setzeRotation;
import '../design/muskel_figur_support.dart' show kMuskelFigurSeite;
import 'gym_trainings_support.dart';

/// Widget-Tests für das **Trainings-Detail** (#533 unter #531, Task 2.2;
/// Spec 8.1 bis 8.3, 11, 12) — **Zustände und Übergänge**, nicht Layout und
/// Beschriftung (`CLAUDE.md`). Hülle, Fixturen und die Lage der Schlüssel
/// stehen im Kopf von `gym_trainings_support.dart`. Die **Import-Vorschau** ist
/// #535 (Scheibe 4) und hat ihre Tests dort.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden. Hält der
/// Implementierende eine Erwartung für falsch, wird das **gemeldet, nicht
/// korrigiert**.
///
/// ## Was die Anforderung bewacht
///
/// - **Fehler `01`:** Solange das Training gelesen wird, steht **nie** „Dieses
///   Training gibt es nicht mehr" — alle Abschnitte stehen, die Knöpfe
///   abgeblendet (Spec 8.3).
/// - **Template und Eigenes unterscheiden sich** an genau den Stellen aus 8.2
///   und 26: Kopie-Hinweis nur beim Template, **Löschen-Zeile nur beim
///   Eigenen** (Templates sind nicht löschbar, Tim, 19.11.2026, Spec 26
///   Nr. 1), Herkunft aus der Kategorie abgeleitet. **Die Figur zeigt beide
///   Seiten** (Entscheidung von Tim, 19.11.2026, Spec 22 Nr. 2).
/// - **Löschen** gibt es nur für ein Eigenes: fragt zurück; danach schließt
///   das Detail und die Übersicht steht ohne das Training da. Ein Template
///   bietet **kein Löschen an** (Spec 26 Nr. 1; der Tombstone-Weg aus Spec 4.4
///   ist ersetzt). Läuft das Training in der Erfassung, lehnt die Ablage ab
///   (Spec 4.7).
/// - **`0` ist keine Antwort auf „kein Wert":** Ein Training ohne bekannte
///   Übung hat keine Dauer, und die Zeile sagt nicht „0 min" (`CLAUDE.md`).
/// - **Keine Zusage ohne Funktion** (Plan, Lücke 7): „Teilen" steht bis #535
///   abgeblendet da und verspricht nichts. „Bearbeiten" war in M2 ebenso
///   abgeblendet und ist seit Task 3.8 wirksam: Ein Eigenes öffnet den
///   Editor, ein Template öffnet ihn als Kopie.
///
/// ## Wer hat was entschieden
///
/// - **Entscheidungen von Tim:** Ein Baustein mit mehreren Aufrufern
///   (18.11.2026); Figur mit beiden Seiten (19.11.2026); Templates sind nicht
///   löschbar (19.11.2026, Spec 26 Nr. 1).
/// - **Vorschläge der Spec, hier vorausgesetzt:** der Wortlaut von Rückfrage,
///   Fußtexten und „Template · mit der App" / „Selbst angelegt" (17.12) —
///   geprüft werden **Stichwörter**: „Template", „Training", „Selbst".
/// - **Festlegung des Test-Agenten:** Die Rückfrage vor dem Löschen sind zwei
///   Schlüssel. `gym-training-detail-loeschen-frage` sitzt auf der **ganzen**
///   Rückfrage — Dialog oder Blatt mit Text **und** Knöpfen, nicht auf einer
///   Zeile darin —, `-loeschen-bestaetigen` auf dem bestätigenden Knopf. Der
///   Abbrechen-Knopf wird über das Wort „Abbrechen" gefunden (der Wortlaut
///   steht in Spec 8.3, als Vorschlag). „Teilen" sitzt in der
///   Navigationsleiste, wird aber über den Schlüssel gefunden.
/// - **Schlüssel sitzen auf dem Widget, das sie beschreiben** — bei einer Zeile
///   auf der Zeile, bei einem Satz auf dem `Text` selbst; die Tests lesen den
///   Text **in** dem Widget mit dem Schlüssel, es selbst eingeschlossen.
///
/// ## Was hier **nicht** geprüft wird
///
/// - **„Training starten" für ein Eigenes.** Bis Scheibe 3 (#534) hat die
///   Erfassung keinen Weg für ein Training ohne Enum-Fall; was der Knopf in M2
///   dort tut, ist in der Spec nicht gesagt (gemeldet).
/// - **Der Editor selbst** (`gym_editor_view_test.dart`) und **das Teilen** —
///   erst mit #535.
/// - **Der Wortlaut** der Fußtexte und die Lede-Zeile.
void main() {
  final push = WorkoutTemplates.byId(Workout.push.code)!;

  Future<TrainingsHuelle> detail(
    WidgetTester tester,
    String id, {
    Future<void> Function(HakenRepo repo)? vorher,
    HakenRepo? repo,
    bool warte = true,
  }) async {
    final h = trainingsHuelle(repo: repo);
    await vorher?.call(h.repo);
    await oeffneUebersicht(tester, h);
    await tippe(
      tester,
      find.byKey(kGymTrainingsName(id)),
      warte: warte,
      warnIfMissed: false,
    );
    expect(
      find.byKey(kGymTrainingDetail),
      findsOneWidget,
      reason: 'Eine Kachel antippen öffnet das Detail (Spec 7.6)',
    );
    return h;
  }

  Future<void> eigenes(HakenRepo repo) =>
      legeEigenes(repo, 'E-1', name: 'Kurzhantel zuhause', tags: ['Home']);

  /// Ob ein Bedienelement ohne Wirkung dasteht: abgeblendet oder nicht
  /// antippbar. Beides zugleich ist die Zusage „steht da, tut nichts".
  bool abgeblendet(WidgetTester tester, Key key) => ohneWirkung(tester, key);

  /// Die Abschnitte, die jedes Detail trägt. **Die Löschen-Zeile gehört nicht
  /// dazu**: Sie steht nur beim Eigenen (Spec 26 Nr. 1) — und ob sie während
  /// des Ladens schon da ist, sagt die Spec nicht (gemeldet), das prüft hier
  /// niemand.
  final abschnitte = [
    kGymTrainingDetailFigur,
    kGymTrainingDetailDauer,
    kGymTrainingDetailUebungenSaetze,
    kGymTrainingDetailTags,
    kGymTrainingDetailHerkunft,
    kGymTrainingDetailStarten,
    kGymTrainingDetailBearbeiten,
  ];

  group('Lädt (`01`)', () {
    Future<TrainingsHuelle> haengend(WidgetTester tester) async {
      final repo = HakenRepo(neueDb());
      final h = trainingsHuelle(repo: repo);
      await oeffneUebersicht(tester, h);
      repo.trainingTor = Completer<void>();
      await tippe(
        tester,
        find.byKey(kGymTrainingsName(Workout.push.code)),
        warte: false,
        warnIfMissed: false,
      );
      expect(find.byKey(kGymTrainingDetail), findsOneWidget);
      return h;
    }

    testWidgets('alle Abschnitte stehen, und es steht kein „nicht gefunden"', (
      tester,
    ) async {
      await haengend(tester);

      for (final key in abschnitte) {
        expect(
          find.byKey(key),
          findsOneWidget,
          reason: '$key fehlt während des Ladens (Spec 8.3)',
        );
      }
      expect(find.byKey(kGymTrainingDetailLaedt), findsOneWidget);
      expect(
        find.byKey(kGymTrainingDetailNichtGefunden),
        findsNothing,
        reason:
            '„Kein Training gefunden" behauptete, nachgesehen worden zu sein '
            '(Fehler `01`)',
      );
      expect(
        alleTexteDes(tester),
        isNot(
          matches(RegExp('gibt es nicht|nicht gefunden', caseSensitive: false)),
        ),
      );
    });

    testWidgets('die Knöpfe stehen abgeblendet da und lösen nichts aus', (
      tester,
    ) async {
      final h = await haengend(tester);
      h.befehle.clear();

      for (final key in [
        kGymTrainingDetailStarten,
        kGymTrainingDetailBearbeiten,
      ]) {
        expect(
          abgeblendet(tester, key),
          isTrue,
          reason: '$key: Noch ist nicht klar, was gestartet würde (Spec 8.3)',
        );
        await tester.tap(find.byKey(key), warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(h.befehle, isEmpty);
    });

    testWidgets('keine Zahl, keine Dauer: die Zeilen sind graue Formen', (
      tester,
    ) async {
      await haengend(tester);

      expect(
        textUnter(tester, kGymTrainingDetailDauer),
        isNot(matches(RegExp(r'\d'))),
        reason: 'Noch weiß niemand, wie lange es dauert',
      );
      expect(
        textUnter(tester, kGymTrainingDetailUebungenSaetze),
        isNot(matches(RegExp(r'\d'))),
      );
    });

    testWidgets('die Figur und die Zeilen haben beim Laden dieselbe Höhe wie '
        'danach', (tester) async {
      final repo = HakenRepo(neueDb());
      final h = trainingsHuelle(repo: repo);
      await oeffneUebersicht(tester, h);
      repo.trainingTor = Completer<void>();
      await tippe(
        tester,
        find.byKey(kGymTrainingsName(Workout.push.code)),
        warte: false,
        warnIfMissed: false,
      );
      final vorher = {
        for (final k in [
          kGymTrainingDetailFigur,
          kGymTrainingDetailDauer,
          kGymTrainingDetailHerkunft,
        ])
          k: tester.getSize(find.byKey(k)),
      };

      repo.trainingTor!.complete();
      await tester.pumpAndSettle();

      for (final eintrag in vorher.entries) {
        final danach = tester.getSize(find.byKey(eintrag.key));
        expect(
          danach.height,
          closeTo(eintrag.value.height, 0.5),
          reason:
              '${eintrag.key} springt zwischen Laden und Fertig (`CLAUDE.md`)',
        );
      }
      expect(find.byKey(kGymTrainingDetailLaedt), findsNothing);
    });
  });

  group('Template (Spec 8.2)', () {
    testWidgets('trägt den Kopie-Hinweis und die Herkunft „Template"', (
      tester,
    ) async {
      await detail(tester, Workout.push.code);

      expect(find.byKey(kGymTrainingDetailKopieHinweis), findsOneWidget);
      expect(
        textUnter(tester, kGymTrainingDetailKopieHinweis),
        contains('Kopie'),
        reason:
            '„Bearbeiten legt eine Kopie unter Eigene an" — die '
            'Überraschung passiert nicht still',
      );
      expect(
        textUnter(tester, kGymTrainingDetailHerkunft),
        contains('Template'),
      );
    });

    testWidgets('bietet kein Löschen an: keine Zeile, keine Rückfrage '
        '(Spec 26 Nr. 1)', (tester) async {
      await detail(tester, Workout.push.code);

      expect(
        find.byKey(kGymTrainingDetailLoeschen),
        findsNothing,
        reason: 'Templates sind nicht löschbar [Tim, 19.11.2026]',
      );
      expect(find.byKey(kGymTrainingDetailLoeschenFrage), findsNothing);
      expect(find.byKey(kGymTrainingDetailLoeschenBestaetigen), findsNothing);
    });

    testWidgets('alle übrigen Abschnitte stehen da, auch ohne Löschen-Zeile', (
      tester,
    ) async {
      await detail(tester, Workout.push.code);

      for (final key in abschnitte) {
        expect(find.byKey(key), findsOneWidget, reason: '$key');
      }
      expect(find.byKey(kGymTrainingDetailTeilen), findsOneWidget);
    });

    testWidgets('die Figur zeigt beide Seiten, einfarbig, mit den '
        'trainierten Muskeln', (tester) async {
      await detail(tester, Workout.push.code);

      final figur = tester.widget<MuskelFigur>(
        find.descendant(
          of: find.byKey(kGymTrainingDetailFigur),
          matching: find.byType(MuskelFigur),
        ),
      );
      expect(
        figur.seite,
        isNull,
        reason: 'Detail-Figur beidseitig [Tim, 19.11.2026, Spec 22 Nr. 2]',
      );
      expect(
        figur.gefaerbt.keys.toSet(),
        WorkoutMuscles.trained(push.exercises),
      );
      expect(
        figur.gefaerbt.values.toSet(),
        hasLength(1),
        reason: 'einfarbig — „trifft diese Muskeln", nicht „wie viel" (8.1)',
      );
      for (final seite in MuskelSeite.values) {
        expect(
          find.descendant(
            of: find.byKey(kGymTrainingDetailFigur),
            matching: find.byKey(kMuskelFigurSeite(seite)),
          ),
          findsOneWidget,
          reason: '$seite',
        );
      }
    });

    testWidgets('jede Übung steht da, in der Reihenfolge des Trainings, mit '
        'Sätzen und Bereich — ohne Gewichte', (tester) async {
      await detail(tester, Workout.push.code);

      double oben(String uid) =>
          tester.getTopLeft(find.byKey(kGymTrainingDetailUebung(uid))).dy;
      for (var i = 0; i < push.exercises.length; i++) {
        final e = push.exercises[i];
        final text = textUnter(tester, kGymTrainingDetailUebung(e.exerciseId));
        expect(text, contains('${e.sets}'), reason: e.exerciseId);
        expect(text, contains('${e.repLow}'), reason: e.exerciseId);
        expect(text, contains('${e.repHigh}'), reason: e.exerciseId);
        expect(
          text,
          isNot(contains('kg')),
          reason: 'Gewichte gehören zur Erfassung (Spec 8.2)',
        );
        if (i > 0) {
          expect(
            oben(e.exerciseId),
            greaterThan(oben(push.exercises[i - 1].exerciseId)),
            reason: 'Reihenfolge des Trainings, nicht alphabetisch',
          );
        }
      }
    });

    testWidgets('die Eckdaten sind gerechnet: Dauer, Übungen · Sätze, Tags', (
      tester,
    ) async {
      await detail(tester, Workout.push.code);

      final saetze = push.exercises.fold<int>(0, (a, e) => a + e.sets);
      expect(
        textUnter(tester, kGymTrainingDetailDauer),
        matches(RegExp('ca\\.\\s*${push.enteredMinutes}')),
      );
      final zaehlung = textUnter(tester, kGymTrainingDetailUebungenSaetze);
      expect(zaehlung, contains('${push.exercises.length}'));
      expect(zaehlung, contains('$saetze'));
      expect(textUnter(tester, kGymTrainingDetailTags), contains('Gym'));
    });

    testWidgets('Starten, Bearbeiten und Teilen stehen da', (tester) async {
      await detail(tester, Workout.push.code);

      for (final key in [
        kGymTrainingDetailStarten,
        kGymTrainingDetailBearbeiten,
        kGymTrainingDetailTeilen,
      ]) {
        expect(find.byKey(key), findsOneWidget, reason: '$key');
      }
    });
  });

  group('Eigenes (Spec 8.2)', () {
    testWidgets('kein Kopie-Hinweis, „Training löschen", Herkunft „Selbst '
        'angelegt"', (tester) async {
      await detail(tester, 'E-1', vorher: eigenes);

      expect(
        find.byKey(kGymTrainingDetailKopieHinweis),
        findsNothing,
        reason: 'Nur ein Template wird beim Bearbeiten kopiert',
      );
      expect(
        textUnter(tester, kGymTrainingDetailLoeschen),
        isNot(contains('Template')),
      );
      expect(textUnter(tester, kGymTrainingDetailHerkunft), contains('Selbst'));
      expect(textUnter(tester, kGymTrainingDetailTags), contains('Home'));
    });

    testWidgets('dieselben Abschnitte stehen da wie beim Template — dazu die '
        'Löschen-Zeile, die nur ein Eigenes hat', (tester) async {
      await detail(tester, 'E-1', vorher: eigenes);

      for (final key in [...abschnitte, kGymTrainingDetailLoeschen]) {
        expect(find.byKey(key), findsOneWidget, reason: '$key');
      }
      expect(find.byKey(kGymTrainingDetailTeilen), findsOneWidget);
    });

    testWidgets('die Figur zeigt beide Seiten und die Muskeln dieser '
        'Übungen', (tester) async {
      await detail(tester, 'E-1', vorher: eigenes);

      final figur = tester.widget<MuskelFigur>(
        find.descendant(
          of: find.byKey(kGymTrainingDetailFigur),
          matching: find.byType(MuskelFigur),
        ),
      );
      expect(figur.seite, isNull);
      expect(
        figur.gefaerbt.keys.toSet(),
        WorkoutMuscles.trained(zweiUebungen()),
      );
    });
  });

  group('Ohne Dauer: nie 0 (`CLAUDE.md`)', () {
    testWidgets('ein Training ohne bekannte Übung zeigt keine „0 min"', (
      tester,
    ) async {
      await detail(
        tester,
        'E-OHNE',
        vorher: (repo) => legeTrainingOhneDauer(repo, 'E-OHNE'),
      );

      final dauer = textUnter(tester, kGymTrainingDetailDauer);
      expect(
        dauer,
        isNot(matches(nullAlsWert)),
        reason: 'Eine Null behauptet „dauert nichts" — das ist `01`',
      );
      expect(dauer, isNot(contains('ca. 0')));
      expect(find.byKey(kGymTrainingDetailDauer), findsOneWidget);
      expect(
        alleTexteDes(tester),
        isNot(matches(RegExp(r'\b0 min'))),
        reason: 'auch nicht in der Lede',
      );
    });

    testWidgets('die Figur steht ungefärbt da — sie verschwindet nicht', (
      tester,
    ) async {
      await detail(
        tester,
        'E-OHNE',
        vorher: (repo) => legeTrainingOhneDauer(repo, 'E-OHNE'),
      );

      final figur = tester.widget<MuskelFigur>(
        find.descendant(
          of: find.byKey(kGymTrainingDetailFigur),
          matching: find.byType(MuskelFigur),
        ),
      );
      expect(figur.gefaerbt, isEmpty);
    });
  });

  group('Nicht gefunden (Spec 8.3)', () {
    testWidgets('ist das Training weg, sagt es ein Satz in der Form der '
        'Detailseite — ohne Knöpfe', (tester) async {
      final h = await detail(tester, 'E-1', vorher: eigenes);

      await h.repo.loesche('E-1');
      h.container.invalidate(gymTrainingProvider('E-1'));
      await tester.pumpAndSettle();

      expect(find.byKey(kGymTrainingDetail), findsOneWidget);
      expect(find.byKey(kGymTrainingDetailNichtGefunden), findsOneWidget);
      expect(find.byKey(kGymTrainingDetailLaedt), findsNothing);
      for (final key in [
        kGymTrainingDetailStarten,
        kGymTrainingDetailBearbeiten,
        kGymTrainingDetailLoeschen,
      ]) {
        expect(
          find.byKey(key),
          findsNothing,
          reason:
              '$key: Ein Training, das es nicht gibt, lässt sich nicht '
              'starten, bearbeiten oder löschen',
        );
      }
    });

    testWidgets('ein gelesenes Training zeigt den Satz nicht', (tester) async {
      await detail(tester, Workout.push.code);

      expect(find.byKey(kGymTrainingDetailNichtGefunden), findsNothing);
      expect(find.byKey(kGymTrainingDetailLaedt), findsNothing);
    });
  });

  group('Löschen (Spec 8.3, 4.4, 4.7)', () {
    testWidgets('fragt zurück und nennt das Training — „Abbrechen" ändert '
        'nichts', (tester) async {
      final h = await detail(tester, 'E-1', vorher: eigenes);

      await tippe(tester, find.byKey(kGymTrainingDetailLoeschen));

      expect(find.byKey(kGymTrainingDetailLoeschenFrage), findsOneWidget);
      expect(
        textUnter(tester, kGymTrainingDetailLoeschenFrage),
        contains('Kurzhantel zuhause'),
        reason: 'Die Rückfrage nennt, was gelöscht würde',
      );
      expect(find.byKey(kGymTrainingDetailLoeschenBestaetigen), findsOneWidget);

      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();

      expect(find.byKey(kGymTrainingDetailLoeschenFrage), findsNothing);
      expect(find.byKey(kGymTrainingDetail), findsOneWidget);
      expect(await h.repo.training('E-1'), isNotNull);
    });

    testWidgets('ein Eigenes: danach ist es weg, das Detail schließt, die '
        'Übersicht steht ohne es da', (tester) async {
      final h = await detail(tester, 'E-1', vorher: eigenes);

      await tippe(tester, find.byKey(kGymTrainingDetailLoeschen));
      await tippe(tester, find.byKey(kGymTrainingDetailLoeschenBestaetigen));

      expect(find.byKey(kGymTrainingDetail), findsNothing);
      expect(find.byKey(kGymTrainings), findsOneWidget);
      expect(find.byKey(kGymTrainingsKachel('E-1')), findsNothing);
      expect(
        find.byKey(kGymTrainingsLeerEigene),
        findsOneWidget,
        reason: 'Es war das einzige Eigene — „Noch keine" steht jetzt da',
      );
      expect(await h.repo.training('E-1'), isNull);
      expect(find.byKey(kGymTrainingsLaedtEigene), findsNothing);
    });

    testWidgets('ein gelöschtes Eigenes verlässt die Rotation, in der es '
        'stand (Spec 24 Nr. 1)', (tester) async {
      final h = await detail(tester, 'E-1', vorher: eigenes);
      await setzeRotation(h.repo.datenbank, [
        Workout.push.code,
        'E-1',
        Workout.pull.code,
        Workout.legs.code,
      ]);

      await tippe(tester, find.byKey(kGymTrainingDetailLoeschen));
      await tippe(tester, find.byKey(kGymTrainingDetailLoeschenBestaetigen));

      expect(await h.repo.rotation(), [
        Workout.push.code,
        Workout.pull.code,
        Workout.legs.code,
      ]);
    });

    testWidgets('läuft das Training in der Erfassung, lehnt die Ablage ab — '
        'und die Rückfrage sagt es', (tester) async {
      final h = await detail(
        tester,
        'E-1',
        vorher: (repo) async {
          await eigenes(repo);
          await laufendesTraining(repo.datenbank, 'E-1');
        },
      );

      await tippe(tester, find.byKey(kGymTrainingDetailLoeschen));
      await tippe(tester, find.byKey(kGymTrainingDetailLoeschenBestaetigen));

      expect(
        await h.repo.training('E-1'),
        isNotNull,
        reason: 'Spec 4.7: Ein Training, das läuft, wird nicht gelöscht',
      );
      expect(
        find.byKey(kGymTrainingDetail),
        findsOneWidget,
        reason: 'Das Detail schließt nicht, wenn nichts gelöscht wurde',
      );
      expect(
        alleTexteDes(tester),
        matches(RegExp('läuft|abschließen|verwerfen', caseSensitive: false)),
        reason: 'Die Rückfrage sagt, warum — statt still nichts zu tun',
      );
    });
  });

  group('Training starten (Spec 8.3)', () {
    testWidgets('ein Template: wirksam, führt über den Router auf den Stapel '
        'des aktuellen Tabs in die Erfassung', (tester) async {
      final h = await detail(tester, Workout.push.code);
      h.befehle.clear();

      expect(
        abgeblendet(tester, kGymTrainingDetailStarten),
        isFalse,
        reason: 'Ein Knopf mit Ziel ist nicht abgeblendet',
      );
      // Der Kontext vor dem Tippen: danach liegt die Erfassung obenauf.
      final kontext = tester.element(find.byKey(kGymTrainingDetail));
      await tester.tap(find.byKey(kGymTrainingDetailStarten));
      await tester.pumpAndSettle();

      expect(h.befehle, hasLength(1));
      expect(h.befehle.single.ersetztStapel, isFalse);
      expect(
        h.befehle.single.builder(kontext),
        isA<GymLogView>(),
        reason: 'Bis #534 über `Workout.fromCode(id)` (Spec 8.3)',
      );
    });
  });

  group('„Bearbeiten" führt in den Editor, „Teilen" bleibt aus (Plan 3.8)', () {
    testWidgets('„Teilen" steht abgeblendet da, löst nichts aus und '
        'verspricht nichts', (tester) async {
      final h = await detail(tester, 'E-1', vorher: eigenes);
      h.befehle.clear();
      final tiefe = tester
          .widgetList(find.byType(CupertinoPageScaffold))
          .length;

      expect(find.byKey(kGymTrainingDetailTeilen), findsOneWidget);
      expect(
        abgeblendet(tester, kGymTrainingDetailTeilen),
        isTrue,
        reason: 'Das Teilen kommt mit #535. Ein Knopf ohne Funktion ist eine '
            'Zusage (Plan, Lücke 7)',
      );
      expect(
        textUnter(tester, kGymTrainingDetailTeilen),
        isNot(matches(verspricht)),
        reason: 'abgeblendet, **ohne Text, der etwas verspricht**',
      );
      await tester.tap(
        find.byKey(kGymTrainingDetailTeilen),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      expect(h.befehle, isEmpty);
      expect(
        tester.widgetList(find.byType(CupertinoPageScaffold)).length,
        tiefe,
        reason: 'Es wurde nichts geschoben',
      );
      expect(find.byKey(kGymTrainingDetail), findsOneWidget);
    });

    testWidgets('bei einem Eigenen ist „Bearbeiten" wirksam und öffnet den '
        'Editor — ohne Kopie-Hinweis, mit „Training löschen"', (tester) async {
      final h = await detail(tester, 'E-1', vorher: eigenes);
      h.befehle.clear();

      expect(abgeblendet(tester, kGymTrainingDetailBearbeiten), isFalse);
      await tester.tap(find.byKey(kGymTrainingDetailBearbeiten));
      await tester.pumpAndSettle();

      expect(find.byKey(kGymEditor), findsOneWidget);
      expect(find.byKey(kGymEditorKopieHinweis), findsNothing);
      expect(find.byKey(kGymEditorLoeschen), findsOneWidget);
    });

    testWidgets('beim Template ist „Bearbeiten (als Kopie)" wirksam und öffnet '
        'den Editor mit Kopie-Hinweis — angelegt ist noch nichts', (
      tester,
    ) async {
      final h = await detail(tester, Workout.push.code);
      h.befehle.clear();

      expect(abgeblendet(tester, kGymTrainingDetailBearbeiten), isFalse);
      await tester.tap(find.byKey(kGymTrainingDetailBearbeiten));
      await tester.pumpAndSettle();

      expect(find.byKey(kGymEditor), findsOneWidget);
      expect(find.byKey(kGymEditorKopieHinweis), findsOneWidget);
      expect(find.byKey(kGymEditorLoeschen), findsNothing);
      expect(
        await h.repo.alle(),
        hasLength(3),
        reason:
            'Es wurde keine Kopie angelegt: Die Kopie entsteht erst beim '
            'Speichern (Spec 4.5)',
      );
    });
  });

  group('Keine Zusage, die nicht stimmt (Spec 12)', () {
    testWidgets('das Detail kündigt nichts an — weder „bald" noch „folgt"', (
      tester,
    ) async {
      await detail(tester, Workout.push.code);

      expect(
        textUnter(tester, kGymTrainingDetail),
        isNot(matches(verspricht)),
        reason: 'Der Schirm sagt, was er tut — nicht, was einmal kommt',
      );
    });
  });
}
