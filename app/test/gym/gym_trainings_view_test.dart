import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/design/muskel_figur.dart' show MuskelSeite;
import 'package:repit/gym/gym_training_editor_schluessel.dart'
    show kGymEditor;
import 'package:repit/gym/gym_trainings_provider.dart';

import 'gym_trainings_support.dart';

/// Widget-Tests für die **Trainings-Übersicht** (#533 unter #531, Task 2.2;
/// Spec 7.1 bis 7.7, 11, 12) — **Zustände und Übergänge**, nicht Layout und
/// Beschriftung (`CLAUDE.md`). Hülle, Fixturen, Lesehilfen und die Lage der
/// Schlüssel stehen im Kopf von `gym_trainings_support.dart`; die Figur der
/// Kachel (Drehen, Semantik) in `gym_trainings_figur_test.dart`, das Detail in
/// `gym_training_detail_test.dart`, die Gym-Tab-Zeile und die Knöpfe ohne
/// Ziel in `gym_trainings_zugang_test.dart`.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden. Hält der
/// Implementierende eine Erwartung für falsch, wird das **gemeldet, nicht
/// korrigiert**.
///
/// ## Was die Anforderung bewacht
///
/// - **Fehler `01`:** Während des Ladens steht nie ein „keine"-Grund — weder
///   „Noch keine eigenen Trainings" noch „Kein Template trägt diesen Tag" noch
///   „Alle Templates gelöscht". Je Gruppe steht **genau eine graue Kachel** in
///   Kachelgröße (Spec 7.4).
/// - **Fehler `32`:** Ein Filter, eine gedrehte Figur und ein gelesener Stand
///   stehen nach Detail und Zurück wieder da, **ohne** Platzhalter und ohne
///   neues Lesen (Spec 7.5, 7.6).
/// - **Jede Anzeige hat genau eine Form** (`CLAUDE.md`, Spec 11): Alle sieben
///   Abschnitte aus 7.1 stehen in **jedem** Zustand; alle Kacheln sind gleich
///   hoch — mit und ohne Tags, als Entwurf, ohne Dauer („–").
/// - **`0` ist keine Antwort auf „kein Wert":** Ein Training ohne Dauer zeigt
///   „–" und wird als „keine Dauer" vorgelesen.
/// - **Keine Lede, kein Hinweisfuß** [Tim, 19.11.2026, Spec 26 Nr. 2]: Der
///   Schirm hat in **keinem** Zustand eine Erläuterungszeile unter der
///   Überschrift und keinen grauen Fuß. Der Erklärsatz des **leeren
///   „Eigene"-Zustands** bleibt — ein Leerzustand ohne Erklärung wäre die
///   alte Falle.
/// - **Templates sind nicht löschbar** (Spec 26 Nr. 1): Die Zustände „ein
///   Template fehlt" und „alle Templates fehlen" entstehen nur noch über
///   einen **per SQL gesetzten Tombstone** — die Spalte bleibt, und die
///   Übersicht muss mit ihm umgehen können.
///
/// ## Wer hat was entschieden
///
/// - **Entscheidungen von Tim:** Aufbau der Kachel (18.11.2026); Entwurfs-
///   Kachel unter „Eigene" mit Kapsel, öffnet den Editor, weder startbar noch
///   einplanbar (19.11.2026); Push, Pull und Legs als Templates
///   (19.11.2026, Spec 23).
/// - **Vorschläge der Spec, hier vorausgesetzt (nicht von Tim entschieden):**
///   die Wortlaute der Leerzustände (7.4), „ca."-Präfix und Einzahl „1 Übung"
///   (7.2), „Ohne Namen" (7.3). Geprüft werden **Stichwörter und das
///   Vorhandensein**, nie ein ganzer Satz.
/// - **Festlegung des Test-Agenten:** wie ein gewählter Filter angezeigt wird
///   — der Vorlesetext der gewählten Kapsel enthält „ausgewählt" (Spec 7.8),
///   keine andere trägt das Wort.
///
/// ## Was hier **nicht** geprüft wird
///
/// - **Der Editor selbst** (`gym_editor_view_test.dart`). Hier wird nur
///   geprüft, dass die Entwurfs-Kachel ihn öffnet und **nicht** das Detail
///   (Spec 7.3, Plan 3.8).
/// - **Farben, Abstände, Schriftgrößen, Pixelpositionen.** Verglichen werden
///   nur Größen **derselben Anzeige mit sich selbst** in zwei Datenlagen.
void main() {
  // Die Schlüssel der entfallenen Lede und des Hinweisfußes stehen hier als
  // Literale: Sie dürfen aus `lib` verschwinden, ohne dass diese Datei nicht
  // mehr übersetzt.
  const lede = Key('gym-trainings-lede');
  const hinweisfuss = Key('gym-trainings-hinweis');

  /// Ein Template-Tombstone, von Hand gesetzt (Spec 26 Nr. 1).
  Future<void> tombstone(HakenRepo repo, String id) =>
      repo.datenbank.customStatement(
        "UPDATE gym_trainings SET geloescht = 1 WHERE id = '$id';",
      );

  Finder mitPraefix(String praefix) => find.byWidgetPredicate((w) {
    final k = w.key;
    return k is ValueKey<String> && k.value.startsWith(praefix);
  });
  Finder alleKacheln() => mitPraefix('gym-trainings-kachel-');
  Finder alleChips() => mitPraefix('gym-trainings-chip-');

  final templateIds = [Workout.push.code, Workout.pull.code, Workout.legs.code];

  /// Die Abschnitte aus Spec 7.1, die in **jedem** Zustand stehen — ohne
  /// Lede und ohne Hinweisfuß (Spec 26 Nr. 2).
  final pflicht = [
    kGymTrainings,
    kGymTrainingsFilter,
    kGymTrainingsChipAlle,
    kGymTrainingsGruppeTemplates,
    kGymTrainingsGruppeEigene,
    kGymTrainingsPlus,
    kGymTrainingsAnlegen,
  ];

  /// Zwei Eigene mit Tags, eines ohne, ein Entwurf — der Fall „liste".
  Future<void> fuelle(HakenRepo repo) async {
    await legeEigenes(repo, 'E-1', name: 'Kurzhantel zuhause', tags: ['Home']);
    await legeEigenes(repo, 'E-2', name: 'Mamas Einstieg', tags: ['Gym']);
    await legeEigenes(repo, 'E-3', name: 'Ohne Tags', tags: const []);
    await legeEntwurf(repo, 'ENT-1', tags: ['Home']);
  }

  group('Jeder Abschnitt steht in jedem Zustand (Spec 7.1, 11)', () {
    testWidgets('lädt, Liste, keine Eigenen, gefiltert, keine Templates mehr', (
      tester,
    ) async {
      final zustaende = <String, Future<TrainingsHuelle> Function()>{
        'lädt': () async {
          final repo = HakenRepo(neueDb())..alleTor = Completer<void>();
          return trainingsHuelle(repo: repo);
        },
        'liste': () async {
          final h = trainingsHuelle();
          await fuelle(h.repo);
          return h;
        },
        'eigene-leer': () async => trainingsHuelle(),
        'gefiltert': () async {
          final h = trainingsHuelle();
          await fuelle(h.repo);
          h.container.read(gymTrainingsFilterProvider.notifier).setze('Home');
          return h;
        },
        'keine Templates': () async {
          final h = trainingsHuelle();
          for (final id in templateIds) {
            await tombstone(h.repo, id);
          }
          return h;
        },
      };

      for (final fall in zustaende.entries) {
        final h = await fall.value();
        await oeffneUebersicht(tester, h, warte: fall.key != 'lädt');

        for (final key in pflicht) {
          expect(
            find.byKey(key),
            findsOneWidget,
            reason:
                '${fall.key}: $key fehlt. „Jeder Abschnitt steht in jedem '
                'Zustand" (Spec 7.1) — sonst springt der Schirm.',
          );
        }
        expect(
          find.byKey(lede),
          findsNothing,
          reason: '${fall.key}: keine Lede mehr (Spec 26 Nr. 2)',
        );
        expect(
          find.byKey(hinweisfuss),
          findsNothing,
          reason: '${fall.key}: kein Hinweisfuß mehr (Spec 26 Nr. 2)',
        );
        expect(find.byType(ErrorWidget), findsNothing, reason: fall.key);
        expect(tester.takeException(), isNull, reason: fall.key);
      }
    });

    testWidgets('die Gruppen stehen in der Reihenfolge aus 7.1: Filter, '
        'Templates, Eigene, Fuß-Knopf', (tester) async {
      final h = trainingsHuelle();
      await fuelle(h.repo);
      await oeffneUebersicht(tester, h);

      double oben(Key key) => tester.getTopLeft(find.byKey(key)).dy;
      final reihe = [
        kGymTrainingsFilter,
        kGymTrainingsGruppeTemplates,
        kGymTrainingsKachel(Workout.push.code),
        kGymTrainingsGruppeEigene,
        kGymTrainingsKachel('E-1'),
        kGymTrainingsAnlegen,
      ];
      for (var i = 1; i < reihe.length; i++) {
        expect(
          oben(reihe[i]),
          greaterThan(oben(reihe[i - 1])),
          reason: '${reihe[i]} steht nicht unter ${reihe[i - 1]}',
        );
      }
    });
  });

  group('Während des Ladens steht nie ein „keine"-Grund (`01`)', () {
    Future<TrainingsHuelle> haengend(WidgetTester tester) async {
      final repo = HakenRepo(neueDb())..alleTor = Completer<void>();
      final h = trainingsHuelle(repo: repo);
      await oeffneUebersicht(tester, h, warte: false);
      return h;
    }

    testWidgets('je Gruppe genau eine graue Kachel — und keine echte', (
      tester,
    ) async {
      await haengend(tester);

      expect(find.byKey(kGymTrainingsLaedtTemplates), findsOneWidget);
      expect(find.byKey(kGymTrainingsLaedtEigene), findsOneWidget);
      expect(
        alleKacheln(),
        findsNothing,
        reason: 'noch ist nichts gelesen — eine echte Kachel wäre erfunden',
      );
    });

    testWidgets('kein Leerzustand-Satz, keine Zahl, kein Fehler', (
      tester,
    ) async {
      await haengend(tester);

      for (final key in [
        kGymTrainingsLeerEigene,
        kGymTrainingsLeerTemplates,
        kGymTrainingsLeerGefiltertTemplates,
        kGymTrainingsLeerGefiltertEigene,
      ]) {
        expect(find.byKey(key), findsNothing, reason: '$key');
      }
      final texte = alleTexteDes(tester);
      expect(
        texte,
        isNot(matches(keineBehauptung)),
        reason:
            'Ein „keine …" wäre eine Aussage über eine Datenlage, in die '
            'noch niemand gesehen hat (Fehler `01`)',
      );
      expect(find.byType(ErrorWidget), findsNothing);
    });

    testWidgets('die Filterzeile hat „Alle" als einzige Kapsel', (
      tester,
    ) async {
      await haengend(tester);

      expect(find.byKey(kGymTrainingsChipAlle), findsOneWidget);
      expect(
        alleChips(),
        findsOneWidget,
        reason: 'Welche Tags es gibt, weiß noch niemand (Spec 7.4)',
      );
    });

    testWidgets('die grauen Kacheln haben Kachelgröße', (tester) async {
      final repo = HakenRepo(neueDb())..alleTor = Completer<void>();
      final h = trainingsHuelle(repo: repo);
      await oeffneUebersicht(tester, h, warte: false);

      final grauT = tester.getSize(find.byKey(kGymTrainingsLaedtTemplates));
      final grauE = tester.getSize(find.byKey(kGymTrainingsLaedtEigene));

      repo.alleTor!.complete();
      await tester.pumpAndSettle();
      final echt = tester.getSize(
        find.byKey(kGymTrainingsKachel(Workout.push.code)),
      );

      for (final grau in [grauT, grauE]) {
        expect(
          grau.height,
          closeTo(echt.height, 0.5),
          reason: 'Der Platzhalter ist dieselbe Form in Grau (`CLAUDE.md`)',
        );
        expect(grau.width, closeTo(echt.width, 0.5));
      }
    });

    testWidgets('mit dem Lesen verschwinden die grauen Kacheln und die '
        'echten stehen da', (tester) async {
      final repo = HakenRepo(neueDb())..alleTor = Completer<void>();
      final h = trainingsHuelle(repo: repo);
      await oeffneUebersicht(tester, h, warte: false);

      repo.alleTor!.complete();
      await tester.pumpAndSettle();

      expect(find.byKey(kGymTrainingsLaedtTemplates), findsNothing);
      expect(find.byKey(kGymTrainingsLaedtEigene), findsNothing);
      for (final id in templateIds) {
        expect(find.byKey(kGymTrainingsKachel(id)), findsOneWidget, reason: id);
      }
    });
  });

  group('Templates und Eigene (Variante `liste`)', () {
    testWidgets('die Templates sind Push, Pull und Legs — in dieser '
        'Reihenfolge, unter ihrem Gruppenkopf', (tester) async {
      final h = trainingsHuelle();
      await oeffneUebersicht(tester, h);

      double oben(String id) =>
          tester.getTopLeft(find.byKey(kGymTrainingsKachel(id))).dy;
      expect(oben(Workout.push.code), lessThan(oben(Workout.pull.code)));
      expect(oben(Workout.pull.code), lessThan(oben(Workout.legs.code)));
      expect(
        oben(Workout.push.code),
        greaterThan(
          tester.getTopLeft(find.byKey(kGymTrainingsGruppeTemplates)).dy,
        ),
      );
      for (final id in ['A', 'B', 'C', 'D']) {
        expect(
          find.byKey(kGymTrainingsKachel(id)),
          findsNothing,
          reason: 'Gym $id ist kein Template mehr (Spec 23)',
        );
      }
      expect(
        alleKacheln(),
        findsNWidgets(3),
        reason: 'ohne Eigene stehen genau die drei Templates da',
      );
    });

    testWidgets('jede Kachel nennt Namen, Dauer und Zahl der Übungen — die '
        'Zahlen aus dem Katalog', (tester) async {
      final h = trainingsHuelle();
      await oeffneUebersicht(tester, h);

      for (final id in templateIds) {
        final training = WorkoutTemplates.byId(id)!;
        expect(
          textUnter(tester, kGymTrainingsName(id)),
          contains(WorkoutNaming.shortName(training.name)),
          reason: id,
        );
        expect(
          textUnter(tester, kGymTrainingsAnzahl(id)),
          contains('${training.exercises.length}'),
          reason: '$id: die Zahl der Übungen',
        );
        expect(
          textUnter(tester, kGymTrainingsDauer(id)),
          contains('${training.enteredMinutes}'),
          reason: '$id: die eingetragene Dauer der Startbefüllung',
        );
      }
    });

    testWidgets('„ca." steht vor jeder Dauer — auch vor einer geschätzten', (
      tester,
    ) async {
      final h = trainingsHuelle();
      await fuelle(h.repo);
      await oeffneUebersicht(tester, h);

      final geschaetzt = WorkoutDuration.estimate(zweiUebungen());
      expect(geschaetzt, isNotNull, reason: 'Vorbedingung');
      expect(
        textUnter(tester, kGymTrainingsDauer('E-1')),
        matches(RegExp('ca\\.\\s*$geschaetzt')),
        reason:
            'Eine Schätzung ist kein Versprechen (Spec 12 Nr. 4); „ca." '
            'steht vor jeder Dauer (Spec 7.2)',
      );
      expect(
        textUnter(tester, kGymTrainingsDauer(Workout.push.code)),
        matches(RegExp(r'ca\.\s*70')),
      );
    });

    testWidgets('eine Übung heißt „1 Übung", nicht „1 Übungen"', (
      tester,
    ) async {
      final h = trainingsHuelle();
      await legeEigenes(
        h.repo,
        'E-EINS',
        exercises: [uebung('benchPress')],
        tags: const [],
      );
      await oeffneUebersicht(tester, h);

      final text = textUnter(tester, kGymTrainingsAnzahl('E-EINS'));
      expect(text, contains('1'));
      expect(
        text,
        isNot(contains('Übungen')),
        reason: 'Einzahl bei einer Übung (Spec 7.2, Vorschlag)',
      );
    });

    testWidgets('die Tag-Zeile steht bei jeder Kachel — auch ohne Tags', (
      tester,
    ) async {
      final h = trainingsHuelle();
      await fuelle(h.repo);
      await oeffneUebersicht(tester, h);

      for (final id in [...templateIds, 'E-1', 'E-2', 'E-3', 'ENT-1']) {
        expect(
          find.byKey(kGymTrainingsTags(id)),
          findsOneWidget,
          reason:
              '$id: „die Tag-Zeile ist auch ohne Tags reserviert" '
              '(Spec 7.2)',
        );
      }
      expect(textUnter(tester, kGymTrainingsTags('E-3')), isEmpty);
      expect(
        textUnter(tester, kGymTrainingsTags(Workout.push.code)),
        contains('Gym'),
      );
    });

    testWidgets('alle Kacheln sind gleich hoch — mit und ohne Tags, als '
        'Entwurf, ohne Dauer, ohne Namen', (tester) async {
      final h = trainingsHuelle();
      await fuelle(h.repo);
      await legeTrainingOhneDauer(h.repo, 'E-OHNE');
      await legeEntwurf(
        h.repo,
        'ENT-2',
        name: '',
        exercises: const [],
        tags: const [],
      );
      await oeffneUebersicht(tester, h);

      final ids = [
        ...templateIds,
        'E-1',
        'E-2',
        'E-3',
        'E-OHNE',
        'ENT-1',
        'ENT-2',
      ];
      final referenz = hoehe(tester, kGymTrainingsKachel(Workout.push.code));
      for (final id in ids) {
        expect(
          find.byKey(kGymTrainingsKachel(id)),
          findsOneWidget,
          reason: '$id fehlt',
        );
        expect(
          hoehe(tester, kGymTrainingsKachel(id)),
          closeTo(referenz, 0.5),
          reason:
              '$id: „Eine Kachel ohne Tags ist genauso hoch wie eine mit" '
              '(Spec 7.2) — als Größenvergleich, nicht als Zahl',
        );
      }
    });
  });

  group('Ohne Dauer: „–", nie 0 (Spec 7.2, `CLAUDE.md`)', () {
    testSemantik('ein Training ohne bekannte Übung zeigt „–" und liest sich '
        'als „keine Dauer"', (tester) async {
      final h = trainingsHuelle();
      await legeTrainingOhneDauer(h.repo, 'E-OHNE');
      await oeffneUebersicht(tester, h);

      final dauer = textUnter(tester, kGymTrainingsDauer('E-OHNE'));
      expect(dauer, contains('–'), reason: 'die Dauerzeile bleibt stehen');
      expect(dauer, isNot(matches(nullAlsWert)));
      expect(dauer, isNot(contains('ca.')));

      final vorgelesen = semantikTexte(
        tester,
        find.byKey(kGymTrainingsKachel('E-OHNE')),
      );
      expect(
        vorgelesen,
        contains('keine dauer'),
        reason: 'Der Vorlesetext nennt den Zustand, nicht das Zeichen (7.8)',
      );
      expect(vorgelesen, isNot(contains('strich')));
    });

    testWidgets('ein Entwurf zeigt statt der Dauer „Entwurf — noch nicht '
        'fertig" und trägt die Kapsel — ein fertiges Training nicht', (
      tester,
    ) async {
      final h = trainingsHuelle();
      await fuelle(h.repo);
      await oeffneUebersicht(tester, h);

      expect(find.byKey(kGymTrainingsEntwurf('ENT-1')), findsOneWidget);
      for (final id in [...templateIds, 'E-1', 'E-2', 'E-3']) {
        expect(
          find.byKey(kGymTrainingsEntwurf(id)),
          findsNothing,
          reason: '$id ist fertig — die Kapsel steht nur bei Entwürfen',
        );
      }
      final dauer = textUnter(tester, kGymTrainingsDauer('ENT-1'));
      expect(dauer, contains('Entwurf'));
      expect(dauer, isNot(contains('ca.')));
    });

    testWidgets('ein Entwurf ohne Namen heißt „Ohne Namen" — nicht leer', (
      tester,
    ) async {
      final h = trainingsHuelle();
      await legeEntwurf(
        h.repo,
        'ENT-2',
        name: '',
        exercises: const [],
        tags: const [],
      );
      await oeffneUebersicht(tester, h);

      expect(
        textUnter(tester, kGymTrainingsName('ENT-2')),
        isNotEmpty,
        reason:
            'Spec 7.3 (Vorschlag „Ohne Namen"): eine Kachel ohne Namen '
            'ließe sich nicht lesen',
      );
    });
  });

  group('Noch keine Eigenen (Variante `eigene-leer`)', () {
    testWidgets('der Gruppenkopf bleibt, darunter steht der Erklärsatz', (
      tester,
    ) async {
      final h = trainingsHuelle();
      await oeffneUebersicht(tester, h);

      expect(find.byKey(kGymTrainingsGruppeEigene), findsOneWidget);
      expect(find.byKey(kGymTrainingsLeerEigene), findsOneWidget);
      final satz = textUnter(tester, kGymTrainingsLeerEigene);
      expect(
        satz,
        contains('Bearbeiten'),
        reason: 'Er nennt den zweiten Weg: ein Template bearbeiten (7.4)',
      );
      expect(satz, contains('Kopie'));
      expect(
        tester.getTopLeft(find.byKey(kGymTrainingsLeerEigene)).dy,
        greaterThan(
          tester.getTopLeft(find.byKey(kGymTrainingsGruppeEigene)).dy,
        ),
      );
    });

    testWidgets('der Erklärsatz steht nur, wenn gelesen, leer und '
        'ungefiltert', (tester) async {
      final h = trainingsHuelle();
      await legeEigenes(h.repo, 'E-1', tags: ['Home']);
      await oeffneUebersicht(tester, h);

      expect(
        find.byKey(kGymTrainingsLeerEigene),
        findsNothing,
        reason: 'Es gibt ein Eigenes — der Satz behauptete das Gegenteil',
      );
      expect(find.byKey(kGymTrainingsKachel('E-1')), findsOneWidget);
    });

    testWidgets('der Weg zum Anlegen ist derselbe wie im gefüllten Zustand — '
        'gleiche Form, andere Füllung', (tester) async {
      final leer = trainingsHuelle();
      await oeffneUebersicht(tester, leer);
      final plusLeer = tester.getSize(find.byKey(kGymTrainingsPlus));
      final anlegenLeer = tester.getSize(find.byKey(kGymTrainingsAnlegen));
      final kopfLeer = tester.getSize(find.byKey(kGymTrainingsGruppeEigene));

      final voll = trainingsHuelle();
      await fuelle(voll.repo);
      await oeffneUebersicht(tester, voll);

      expect(find.byKey(kGymTrainingsPlus), findsOneWidget);
      expect(find.byKey(kGymTrainingsAnlegen), findsOneWidget);
      expect(tester.getSize(find.byKey(kGymTrainingsPlus)), plusLeer);
      expect(tester.getSize(find.byKey(kGymTrainingsAnlegen)), anlegenLeer);
      expect(
        tester.getSize(find.byKey(kGymTrainingsGruppeEigene)),
        kopfLeer,
        reason: 'Der Gruppenkopf ist in beiden Zuständen derselbe',
      );
    });
  });

  group('Gefiltert (Variante `gefiltert`) und die Filterzeile', () {
    Future<TrainingsHuelle> geoeffnet(WidgetTester tester) async {
      final h = trainingsHuelle();
      await fuelle(h.repo);
      await oeffneUebersicht(tester, h);
      return h;
    }

    testWidgets('die Filterzeile: „Alle" zuerst, danach die benutzten Tags '
        'nach Häufigkeit', (tester) async {
      await geoeffnet(tester);

      double links(Key key) => tester.getTopLeft(find.byKey(key)).dx;
      expect(find.byKey(kGymTrainingsChip('Gym')), findsOneWidget);
      expect(find.byKey(kGymTrainingsChip('Home')), findsOneWidget);
      expect(
        links(kGymTrainingsChipAlle),
        lessThan(links(kGymTrainingsChip('Gym'))),
      );
      expect(
        links(kGymTrainingsChip('Gym')),
        lessThan(links(kGymTrainingsChip('Home'))),
        reason:
            'Gym steht auf drei Templates und einem Eigenen, Home auf einem '
            'Eigenen und einem Entwurf — absteigend nach Häufigkeit (Spec '
            '5.6, `allTags`)',
      );
      expect(
        alleChips(),
        findsNWidgets(3),
        reason: 'genau die benutzten Tags — und „Alle"',
      );
    });

    testSemantik('genau eine Kapsel ist an — der Vorlesetext sagt es', (
      tester,
    ) async {
      final h = await geoeffnet(tester);
      final kapseln = [
        kGymTrainingsChipAlle,
        kGymTrainingsChip('Gym'),
        kGymTrainingsChip('Home'),
      ];

      List<bool> an() => [
        for (final k in kapseln)
          semantikLabel(tester, find.byKey(k)).contains('ausgewählt'),
      ];

      expect(an(), [true, false, false], reason: 'zu Beginn ist „Alle" an');

      await tippe(tester, find.byKey(kGymTrainingsChip('Home')));
      expect(an(), [false, false, true]);
      expect(h.container.read(gymTrainingsFilterProvider), 'Home');

      await tippe(tester, find.byKey(kGymTrainingsChipAlle));
      expect(an(), [true, false, false]);
      expect(h.container.read(gymTrainingsFilterProvider), isNull);
    });

    testWidgets('dieselbe Kapsel noch einmal wählt nichts ab', (tester) async {
      final h = await geoeffnet(tester);

      await tippe(tester, find.byKey(kGymTrainingsChip('Home')));
      await tippe(tester, find.byKey(kGymTrainingsChip('Home')));

      expect(
        h.container.read(gymTrainingsFilterProvider),
        'Home',
        reason: '„Alle" ist die Abwahl; genau eine Kapsel ist immer an (7.6)',
      );
      expect(find.byKey(kGymTrainingsKachel('E-1')), findsOneWidget);
      expect(find.byKey(kGymTrainingsKachel('E-2')), findsNothing);
    });

    testWidgets('„Home": beide Köpfe bleiben, die Gruppe ohne Treffer sagt es, '
        'die andere zeigt ihr Training', (tester) async {
      await geoeffnet(tester);

      await tippe(tester, find.byKey(kGymTrainingsChip('Home')));

      expect(find.byKey(kGymTrainingsGruppeTemplates), findsOneWidget);
      expect(find.byKey(kGymTrainingsGruppeEigene), findsOneWidget);
      expect(
        find.byKey(kGymTrainingsLeerGefiltertTemplates),
        findsOneWidget,
        reason:
            'Kein Template trägt „Home" — es steht da, statt zu '
            'verschwinden (Spec 7.4)',
      );
      for (final id in templateIds) {
        expect(find.byKey(kGymTrainingsKachel(id)), findsNothing, reason: id);
      }
      expect(find.byKey(kGymTrainingsKachel('E-1')), findsOneWidget);
      expect(
        find.byKey(kGymTrainingsKachel('ENT-1')),
        findsOneWidget,
        reason: 'Ein Entwurf mit passendem Tag steht mit seiner Kapsel da',
      );
      expect(find.byKey(kGymTrainingsKachel('E-2')), findsNothing);
      expect(find.byKey(kGymTrainingsKachel('E-3')), findsNothing);
      expect(find.byKey(kGymTrainingsLeerGefiltertEigene), findsNothing);
      expect(
        find.byKey(kGymTrainingsLeerEigene),
        findsNothing,
        reason: 'gefiltert ist nicht „noch keine Eigenen"',
      );
    });

    testWidgets('auch gefiltert steht keine Lede da, die den Filter nennt '
        '(Spec 26 Nr. 2)', (tester) async {
      await geoeffnet(tester);

      await tippe(tester, find.byKey(kGymTrainingsChip('Home')));

      expect(find.byKey(lede), findsNothing);
    });

    testWidgets('„Gym" ohne eigenes Treffertraining: „Eigene" sagt es, und der '
        'Leerzustand der Eigenen steht nicht', (tester) async {
      final h = trainingsHuelle();
      await legeEigenes(h.repo, 'E-1', tags: ['Home']);
      await oeffneUebersicht(tester, h);

      await tippe(tester, find.byKey(kGymTrainingsChip('Gym')));

      for (final id in templateIds) {
        expect(find.byKey(kGymTrainingsKachel(id)), findsOneWidget, reason: id);
      }
      expect(find.byKey(kGymTrainingsLeerGefiltertTemplates), findsNothing);
      expect(find.byKey(kGymTrainingsLeerGefiltertEigene), findsOneWidget);
      expect(find.byKey(kGymTrainingsLeerEigene), findsNothing);
      expect(find.byKey(kGymTrainingsKachel('E-1')), findsNothing);
    });

    testWidgets('„Alle" zeigt wieder alles', (tester) async {
      await geoeffnet(tester);
      await tippe(tester, find.byKey(kGymTrainingsChip('Home')));

      await tippe(tester, find.byKey(kGymTrainingsChipAlle));

      for (final id in [...templateIds, 'E-1', 'E-2', 'E-3', 'ENT-1']) {
        expect(find.byKey(kGymTrainingsKachel(id)), findsOneWidget, reason: id);
      }
      expect(find.byKey(kGymTrainingsLeerGefiltertTemplates), findsNothing);
    });

    testWidgets('wird der letzte Treffer gelöscht, fällt der Filter auf „Alle" '
        'zurück', (tester) async {
      final h = trainingsHuelle();
      await legeEigenes(h.repo, 'E-1', tags: ['Home']);
      await oeffneUebersicht(tester, h);
      await tippe(tester, find.byKey(kGymTrainingsChip('Home')));
      expect(h.container.read(gymTrainingsFilterProvider), 'Home');

      await h.repo.loesche('E-1');
      leseNeu(h);
      await tester.pumpAndSettle();

      expect(h.container.read(gymTrainingsFilterProvider), isNull);
      expect(
        find.byKey(kGymTrainingsChip('Home')),
        findsNothing,
        reason: 'Der Tag wird nicht mehr benutzt',
      );
      for (final id in templateIds) {
        expect(
          find.byKey(kGymTrainingsKachel(id)),
          findsOneWidget,
          reason: '$id: Auf „Alle" zurück stehen die Templates wieder da',
        );
      }
      expect(
        find.byKey(kGymTrainingsLeerGefiltertTemplates),
        findsNothing,
        reason: 'Kein Filter mehr — kein „trägt diesen Tag"',
      );
    });
  });

  group('Keine Templates mehr (Spec 7.4, 26 Nr. 1)', () {
    testWidgets('der Gruppenkopf bleibt, darunter steht der Satz — die Eigenen '
        'bleiben', (tester) async {
      final h = trainingsHuelle();
      await legeEigenes(h.repo, 'E-1', tags: ['Home']);
      for (final id in templateIds) {
        await tombstone(h.repo, id);
      }
      await oeffneUebersicht(tester, h);

      expect(find.byKey(kGymTrainingsGruppeTemplates), findsOneWidget);
      expect(find.byKey(kGymTrainingsLeerTemplates), findsOneWidget);
      for (final id in templateIds) {
        expect(find.byKey(kGymTrainingsKachel(id)), findsNothing, reason: id);
      }
      expect(find.byKey(kGymTrainingsKachel('E-1')), findsOneWidget);
      expect(
        find.byKey(kGymTrainingsLeerGefiltertTemplates),
        findsNothing,
        reason:
            'ohne Filter ist es „alle gelöscht", nicht „trägt den Tag nicht"',
      );
    });

    testWidgets('ein einzelnes Template mit Tombstone lässt der Übersicht die '
        'anderen beiden (Tombstone per SQL, Spec 26 Nr. 1)', (tester) async {
      final h = trainingsHuelle();
      await tombstone(h.repo, Workout.pull.code);
      await oeffneUebersicht(tester, h);

      expect(
        find.byKey(kGymTrainingsKachel(Workout.push.code)),
        findsOneWidget,
      );
      expect(find.byKey(kGymTrainingsKachel(Workout.pull.code)), findsNothing);
      expect(
        find.byKey(kGymTrainingsKachel(Workout.legs.code)),
        findsOneWidget,
      );
      expect(
        find.byKey(kGymTrainingsLeerTemplates),
        findsNothing,
        reason: 'Zwei Templates stehen noch da',
      );
    });
  });

  group('Übergänge (Spec 7.6)', () {
    testWidgets('ein im Hintergrund gespeichertes Training ist nach neuem '
        'Lesen sofort da — und der Stand bleibt dabei stehen', (tester) async {
      final h = trainingsHuelle();
      await oeffneUebersicht(tester, h);
      expect(find.byKey(kGymTrainingsLeerEigene), findsOneWidget);

      await legeEigenes(h.repo, 'E-NEU', name: 'Neu gespeichert');
      leseNeu(h);
      await tester.pumpAndSettle();

      expect(find.byKey(kGymTrainingsKachel('E-NEU')), findsOneWidget);
      expect(find.byKey(kGymTrainingsLeerEigene), findsNothing);
      expect(find.byKey(kGymTrainingsLaedtTemplates), findsNothing);
    });

    testWidgets('während neu gelesen wird, bleibt der Stand stehen — kein '
        'Platzhalter (`01`, `32`)', (tester) async {
      final h = trainingsHuelle();
      await fuelle(h.repo);
      await oeffneUebersicht(tester, h);

      h.repo.alleTor = Completer<void>();
      h.container.invalidate(gymTrainingsQuelleProvider);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(kGymTrainingsLaedtTemplates), findsNothing);
      expect(find.byKey(kGymTrainingsLaedtEigene), findsNothing);
      for (final id in [...templateIds, 'E-1']) {
        expect(find.byKey(kGymTrainingsKachel(id)), findsOneWidget, reason: id);
      }
    });

    testWidgets('ein gescheitertes Nachlesen nimmt keine Kachel weg', (
      tester,
    ) async {
      final h = trainingsHuelle();
      await fuelle(h.repo);
      await oeffneUebersicht(tester, h);

      h.repo.alleScheitert = true;
      h.container.invalidate(gymTrainingsQuelleProvider);
      await tester.pumpAndSettle();

      for (final id in [...templateIds, 'E-1']) {
        expect(find.byKey(kGymTrainingsKachel(id)), findsOneWidget, reason: id);
      }
      expect(find.byKey(kGymTrainingsLeerEigene), findsNothing);
    });

    testSemantik('Detail und zurück: Filter, gelesener Stand und Figurseite '
        'stehen wieder da — ohne Platzhalter, ohne neues Lesen (`32`)', (
      tester,
    ) async {
      final h = trainingsHuelle();
      await fuelle(h.repo);
      await oeffneUebersicht(tester, h);
      await tippe(tester, find.byKey(kGymTrainingsChip('Gym')));
      h.container
          .read(gymTrainingsSeiteProvider(Workout.pull.code).notifier)
          .setze(MuskelSeite.hinten);
      await tester.pumpAndSettle();
      final gelesen = h.repo.alleAufrufe;
      final pushVorher = hoehe(tester, kGymTrainingsKachel(Workout.push.code));

      await tippe(tester, find.byKey(kGymTrainingsName(Workout.push.code)));
      expect(find.byKey(kGymTrainingDetail), findsOneWidget);
      await zurueck(tester, h);

      expect(find.byKey(kGymTrainings), findsOneWidget);
      expect(
        h.container.read(gymTrainingsFilterProvider),
        'Gym',
        reason: 'Der Filter überlebt Detail und Zurück (Spec 7.6)',
      );
      expect(
        semantikLabel(tester, find.byKey(kGymTrainingsChip('Gym'))),
        contains('ausgewählt'),
      );
      expect(find.byKey(kGymTrainingsKachel('E-2')), findsOneWidget);
      expect(find.byKey(kGymTrainingsKachel('E-1')), findsNothing);
      expect(
        h.container.read(gymTrainingsSeiteProvider(Workout.pull.code)),
        MuskelSeite.hinten,
        reason: 'Die Figur steht, wie man sie gelassen hat (7.5)',
      );
      expect(find.byKey(kGymTrainingsLaedtTemplates), findsNothing);
      expect(find.byKey(kGymTrainingsLaedtEigene), findsNothing);
      expect(
        h.repo.alleAufrufe,
        gelesen,
        reason:
            'Der Stand wird gehalten, nicht je Rückkehr neu gelesen '
            '(Hausregel 2, Fehler `03`)',
      );
      expect(
        hoehe(tester, kGymTrainingsKachel(Workout.push.code)),
        closeTo(pushVorher, 0.5),
      );
    });

    testWidgets('eine Kachel antippen öffnet das Detail auf dem Stapel des '
        'aktuellen Tabs — ohne Tab-Wechsel', (tester) async {
      final h = trainingsHuelle();
      await fuelle(h.repo);
      await oeffneUebersicht(tester, h);
      final tabVorher = h.router.tab;
      h.befehle.clear();

      await tippe(tester, find.byKey(kGymTrainingsName('E-1')));

      expect(find.byKey(kGymTrainingDetail), findsOneWidget);
      expect(h.befehle, hasLength(1));
      expect(
        h.befehle.single.ersetztStapel,
        isFalse,
        reason:
            '`AppTarget.aktuell`: auf den Stapel des Tabs, in dem man ist, '
            'nie fest in den Gym-Tab (Spec 7.6, `CLAUDE.md`)',
      );
      expect(h.router.tab, tabVorher, reason: 'Kein Tab-Wechsel');
    });

    testWidgets('die Entwurfs-Kachel öffnet den Editor, nicht das Detail', (
      tester,
    ) async {
      final h = trainingsHuelle();
      await fuelle(h.repo);
      await oeffneUebersicht(tester, h);

      await tippe(
        tester,
        find.byKey(kGymTrainingsName('ENT-1')),
        warnIfMissed: false,
      );

      expect(
        find.byKey(kGymTrainingDetail),
        findsNothing,
        reason:
            'Ein Entwurf ist weder startbar noch einplanbar und öffnet den '
            'Editor, nicht das Detail (Spec 7.3).',
      );
      expect(
        find.byKey(kGymEditor),
        findsOneWidget,
        reason: 'Der Editor liegt jetzt obenauf (Plan 3.8)',
      );
    });
  });
}
