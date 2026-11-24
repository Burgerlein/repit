import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/gym_training_repository.dart';
import 'package:repit/design/platzhalter.dart' show Platzhalter;
import 'package:repit/gym/gym_entwurf_provider.dart';
import 'package:repit/gym/gym_fokus_texte.dart';
import 'package:repit/gym/gym_log_view.dart';
import 'package:repit/gym/gym_provider.dart';
import 'package:repit/gym/gym_trainings_provider.dart';
import 'package:repit/gym/gym_verlauf_provider.dart';
import 'package:repit/gym/gym_wochen_texte.dart';
import 'package:repit/health/health_provider.dart'
    show appCacheProvider, clockProvider;
import 'package:repit/shell/heute_training.dart';

import '../data/gym_training_support.dart' show setzeRotation;
import 'gym_trainings_support.dart';
import 'support.dart'
    show
        flach,
        heute,
        jetzt,
        kLede,
        kKarte,
        kPlatz,
        kWoche,
        kWocheLeer,
        rotationPpl,
        texteUnter;

/// Tests für die **Rotation-Umstellung** (Task 2.8 des Plans
/// `docs/superpowers/plans/2026-11-19-eigene-trainings-plan.md`, vorgezogener
/// Datenteil von #536; Spec 23, 24, 25): `GymDayPlanner`, Wochenleiste,
/// Fokus-Karte und Heute-Zeile lesen die **gespeicherte Rotation** statt
/// `Workout.rotation` — **drei Plätze statt vier**, Push, Pull, Legs.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden. Hält der
/// Implementierende eine Erwartung für falsch, wird das **gemeldet, nicht
/// korrigiert**.
///
/// ## Was die Anforderung bewacht
///
/// - **Gym A bis D sind nirgends mehr startbar** (Spec 23): kein Platz in der
///   Wochenleiste, keiner in der Fokus-Karte, kein überfälliges Gym D. Auch
///   ein hereingereichter Wochenplan oder eine „erledigt"-Meldung für A–D
///   füllt keinen Platz.
/// - **Fehler `01`:** Solange die Rotation gelesen wird, steht kein „Ruhetag",
///   kein „offen" und kein Grund-Satz — `GymTag.laedt` schließt die Rotation
///   ein. Ein gelesener Stand bleibt stehen, auch wenn neu gelesen wird oder
///   das Nachlesen scheitert (`32`). Scheitert schon das erste Lesen, ist es
///   „nichts da" — **nicht** ein Platzhalter für immer.
/// - **Eine Form, null bis drei Plätze** (`CLAUDE.md`, Spec 24 Nr. 1): Hat die
///   Rotation weniger Plätze, hat die Leiste die, die da sind; sie behält Höhe
///   und Breite. Hat sie keinen, steht **ein Satz in der Form der Leiste**
///   da. **Seit Spec 26 Nr. 1 sind Templates nicht löschbar:** Die Rotation
///   schrumpft über das Repository erst mit #536; die Fälle nehmen Plätze
///   deshalb **per direkter Änderung** der Rotationszeilen heraus
///   (`nimmAusDerRotation`) — der Zustand der Leiste bleibt bewacht, auch
///   wenn heute kein Weg dorthin führt.
/// - **Spec 24 Nr. 4:** Eine Rotationskennung ohne bekanntes Training lässt die
///   Kette **werfen**, statt still zu verschwinden.
///
/// ## Wer hat was entschieden
///
/// - **Entscheidungen von Tim [19.11.2026]:** Push/Pull/Legs sind die
///   Start-Templates und die Start-Rotation; die Umstellung wird vorgezogen
///   (Spec 23).
/// - **Folgerungen aus Spec 24:** Löschen nimmt ein Training aus der Rotation
///   (Nr. 1); eine unbekannte Kennung wirft (Nr. 4); „Kein Schirm ändert sich"
///   (3.2) gilt nicht mehr (Nr. 5).
/// - **Festlegungen des Test-Agenten — Tim hat sie nicht gesehen:**
///   - `gymTagAus` bekommt den benannten Parameter **`rotation`**
///     (`List<Workout>`), Vorgabe **Push, Pull, Legs** — nicht
///     `Workout.rotation` (Plan 2.8).
///   - `gymTagProvider` liest `gymRotationProvider`; **`laedt` schließt die
///     Rotation ein** und bleibt `true`, bis Rotation, Entwurf und Sitzungen
///     gelesen sind.
///   - Der **leere Satz** der Leiste (null Plätze) trägt den Schlüssel
///     `gym-woche-leer` ([kWocheLeer]); er steht **nur**, wenn gelesen und
///     leer. **Solange gelesen wird**, stehen in der Leiste graue Formen
///     (mindestens eine), nie Statustext und nie der leere Satz.
///   - Wie breit die Kacheln bei zwei oder einem Platz sind (füllen sie die
///     Breite oder behalten sie die von dreien), ist **nicht** geprüft: Die
///     Spec sagt „die Leiste bleibt eine Form" und nennt keine Kachelbreite.
///
/// ## Was hier **nicht** geprüft wird
///
/// - **Der Fehlerzustand des Schirms bei einer unbekannten Kennung.** Spec 24
///   Nr. 4 sagt nur „der Provider wirft"; wie `GymView` ein geworfenes
///   `gymTagProvider` zeigt, steht nirgends. Geprüft wird das Werfen und dass
///   **kein** Satz über „Ruhetag", „offen" oder eine Zahl dasteht.
/// - **Der Einplan-Schirm, Wochentage belegen, #426** — bleiben bei #536.
/// - **`Workout.rotation` im Kern** — `Packages/trainings_core/test/` bleibt,
///   wie es ist; das Enum ändert sich nicht.

/// Nimmt Plätze **von Hand** aus der gespeicherten Rotation (SQL), die
/// übrigen rücken nach. Seit Spec 26 Nr. 1 gibt es für Templates keinen
/// Löschweg mehr, der die Rotation verkleinerte.
Future<void> nimmAusDerRotation(HakenRepo repo, Iterable<Workout> weg) async {
  final codes = [for (final w in weg) w.code];
  final rest = [
    for (final id in await repo.rotation())
      if (!codes.contains(id)) id,
  ];
  await setzeRotation(repo.datenbank, rest);
}

void main() {
  final push = Workout.push;
  final pull = Workout.pull;
  final legs = Workout.legs;

  List<Workout> plaetze(GymTag tag) => [
    for (final platz in tag.tag.week) platz.workout,
  ];

  final montag = DateTime.monday;
  final mittwoch = DateTime.wednesday;

  group('`gymTagAus` — die Rotation als Parameter', () {
    test(
      'ohne Angabe sind es Push, Pull, Legs — drei Plätze, nicht A bis D',
      () {
        final tag = gymTagAus(heute: heute);

        expect(plaetze(tag), [push, pull, legs]);
        expect(
          plaetze(tag),
          isNot(Workout.rotation),
          reason: 'Gym A bis D sind nicht mehr die Woche (Spec 23)',
        );
        expect(tag.tag.week.every((p) => p.status is Open), isTrue);
        expect(tag.tag.week.every((p) => p.weekday == null), isTrue);
        expect(tag.tag.focus, isA<Rest>());
      },
    );

    test('eine übergebene Rotation bestimmt Plätze und Reihenfolge', () {
      expect(plaetze(gymTagAus(heute: heute, rotation: [legs, push])), [
        legs,
        push,
      ]);
      expect(plaetze(gymTagAus(heute: heute, rotation: [pull])), [pull]);
    });

    test('eine leere Rotation ist eine leere Woche — und wirft nicht', () {
      final tag = gymTagAus(heute: heute, rotation: const []);

      expect(tag.tag.week, isEmpty);
      expect(tag.tag.doneThisWeek, 0);
      expect(
        tag.tag.focus,
        const Rest(next: null, inDays: null, overdue: null),
      );
    });

    test('ein Wochenplan für Gym A bis D füllt keinen Platz', () {
      final tag = gymTagAus(
        heute: heute,
        plan: [
          PlannedGym(workout: Workout.a, weekday: montag),
          PlannedGym(workout: Workout.b, weekday: mittwoch),
        ],
      );

      expect(plaetze(tag), [push, pull, legs]);
      expect(
        tag.tag.focus,
        isNot(isA<Planned>()),
        reason: 'Heute (Montag) steht nicht Gym A an — es hat keinen Platz',
      );
    });

    test('ein Wochenplan für Legs gibt dem Platz seinen Tag und sortiert ihn '
        'vor die ohne Tag', () {
      final tag = gymTagAus(
        heute: heute,
        plan: [PlannedGym(workout: legs, weekday: mittwoch)],
      );

      expect(plaetze(tag), [legs, push, pull]);
      expect(tag.tag.week.first.weekday, mittwoch);
      expect(tag.tag.week[1].weekday, isNull);
    });

    test('ein überfälliges Gym D erscheint nirgends', () {
      final tag = gymTagAus(heute: heute, nachzuholen: const [Workout.d]);

      expect(plaetze(tag), [push, pull, legs]);
      expect(
        tag.tag.week.any((p) => p.status is Overdue),
        isFalse,
        reason: 'Ein Workout außerhalb der Rotation wird nie überfällig',
      );
      expect((tag.tag.focus as Rest).overdue, isNull);
    });

    test('ein überfälliges Push zählt: Platz überfällig, Fokus nennt es', () {
      final tag = gymTagAus(heute: heute, nachzuholen: [push]);

      expect(
        tag.tag.week.singleWhere((p) => p.workout == push).status,
        isA<Overdue>(),
      );
      expect((tag.tag.focus as Rest).overdue, push);
    });

    test(
      'ein erledigtes Push und Legs füllen ihre Plätze, Pull bleibt offen',
      () {
        final tag = gymTagAus(
          heute: heute,
          erledigt: {push: heute, legs: heute},
        );

        expect(
          tag.tag.week.singleWhere((p) => p.workout == push).status,
          Done(heute),
        );
        expect(
          tag.tag.week.singleWhere((p) => p.workout == legs).status,
          Done(heute),
        );
        expect(
          tag.tag.week.singleWhere((p) => p.workout == pull).status,
          isA<Open>(),
        );
        expect(tag.tag.doneThisWeek, 2);
      },
    );

    test('ein erledigtes Legs füllt keinen Platz, wenn Legs nicht in der '
        'Rotation steht', () {
      final tag = gymTagAus(
        heute: heute,
        rotation: [push, pull],
        erledigt: {legs: heute},
      );

      expect(plaetze(tag), [push, pull]);
      expect(
        tag.tag.doneThisWeek,
        0,
        reason: 'Gezählt werden Plätze — Legs hat keinen mehr (Spec 24 Nr. 1)',
      );
    });

    test('ein erledigtes Gym A füllt keinen Platz', () {
      final tag = gymTagAus(heute: heute, erledigt: {Workout.a: heute});

      expect(plaetze(tag), [push, pull, legs]);
      expect(tag.tag.doneThisWeek, 0);
    });

    test('ein laufendes Push belegt Platz und Fokus-Karte', () {
      final tag = gymTagAus(
        heute: heute,
        entwurf: const GymDraft(
          workout: Workout.push,
          doneExercises: 2,
          totalExercises: 7,
        ),
      );

      expect(
        tag.tag.week.singleWhere((p) => p.workout == push).status,
        isA<Running>(),
      );
      expect(
        tag.tag.focus,
        const InProgress(workout: Workout.push, done: 2, total: 7),
      );
    });

    test(
      'der Tageszustand ist ein Werttyp: zwei gleiche Aufrufe sind gleich',
      () {
        expect(gymTagAus(heute: heute), gymTagAus(heute: heute));
        expect(
          gymTagAus(heute: heute),
          isNot(gymTagAus(heute: heute, rotation: [push, pull])),
        );
      },
    );
  });

  group('`gymTagProvider` liest die gespeicherte Rotation', () {
    /// Container über der echten Ablage. [gymTagProvider] ist **echt**.
    ProviderContainer kette(HakenRepo repo) {
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          appCacheProvider.overrideWithValue(repo.datenbank),
          gymTrainingRepositoryProvider.overrideWithValue(repo),
          clockProvider.overrideWithValue(() => jetzt),
        ],
      );
      addTearDown(container.dispose);
      // Gehalten, wie der Schirm es tut.
      container.listen(gymTagProvider, (_, _) {}, onError: (_, _) {});
      return container;
    }

    Future<void> lesen(ProviderContainer c, {bool rotation = true}) async {
      Future<void> still(Future<Object?> f) async {
        try {
          await f;
        } on Object {
          // Ein gescheitertes Lesen ist ein Ergebnis wie jedes andere.
        }
      }

      await still(c.read(gymEntwurfProvider.future));
      await still(c.read(gymSitzungenProvider.future));
      if (rotation) await still(c.read(gymRotationQuelleProvider.future));
      await pumpEventQueue();
    }

    Future<ProviderContainer> geladen(HakenRepo repo) async {
      final c = kette(repo);
      await lesen(c);
      return c;
    }

    test(
      'mit gelesener Rotation: Push, Pull, Legs — `laedt` ist `false`',
      () async {
        final c = await geladen(HakenRepo(neueDb()));

        final tag = c.read(gymTagProvider);

        expect(tag.laedt, isFalse);
        expect(plaetze(tag), [push, pull, legs]);
      },
    );

    test('`laedt` gilt, solange die Rotation gelesen wird — auch wenn Entwurf '
        'und Sitzungen längst da sind (`01`)', () async {
      final repo = HakenRepo(neueDb())..rotationTor = Completer<void>();
      final c = kette(repo);
      await lesen(c, rotation: false);

      expect(
        c.read(gymTagProvider).laedt,
        isTrue,
        reason:
            'Ohne die Rotation weiß der Tag nicht, wie viele Plätze die Woche '
            'hat — „Ruhetag" wäre eine Behauptung ohne Grundlage',
      );

      repo.rotationTor!.complete();
      await lesen(c);

      expect(c.read(gymTagProvider).laedt, isFalse);
      expect(plaetze(c.read(gymTagProvider)), [push, pull, legs]);
    });

    test('ein gelesener Stand bleibt beim erneuten Lesen stehen', () async {
      final repo = HakenRepo(neueDb());
      final c = await geladen(repo);
      final vorher = c.read(gymTagProvider);

      repo.rotationTor = Completer<void>();
      c.invalidate(gymRotationQuelleProvider);
      await pumpEventQueue();

      final waehrend = c.read(gymTagProvider);
      expect(waehrend, vorher, reason: 'kein Platzhalter, kein Sprung (`32`)');
      expect(waehrend.laedt, isFalse);
    });

    test('ein gescheitertes Nachlesen nimmt keinen Platz weg', () async {
      final repo = HakenRepo(neueDb());
      final c = await geladen(repo);
      final vorher = c.read(gymTagProvider);

      repo.rotationScheitert = true;
      c.invalidate(gymRotationQuelleProvider);
      await lesen(c);

      expect(c.read(gymTagProvider), vorher);
    });

    test('scheitert schon das erste Lesen, ist es „nichts da" — kein '
        'Platzhalter für immer', () async {
      final repo = HakenRepo(neueDb())..rotationScheitert = true;
      final c = await geladen(repo);

      final tag = c.read(gymTagProvider);

      expect(
        tag.laedt,
        isFalse,
        reason:
            'Es gibt keine Quelle, die etwas erfinden könnte, und es '
            'läuft nichts mehr',
      );
      expect(tag.tag.week, isEmpty);
    });

    test(
      'nach dem Herausnehmen eines Platzes und neuem Lesen: zwei Plätze',
      () async {
        final repo = HakenRepo(neueDb());
        final c = await geladen(repo);
        expect(plaetze(c.read(gymTagProvider)), [push, pull, legs]);

        await nimmAusDerRotation(repo, [pull]);
        c.invalidate(gymRotationQuelleProvider);
        await lesen(c);

        expect(plaetze(c.read(gymTagProvider)), [push, legs]);
        expect(c.read(gymTagProvider).laedt, isFalse);
      },
    );

    test(
      'ist die Rotation leer, ist die Woche leer — mit `laedt == false`',
      () async {
        final repo = HakenRepo(neueDb());
        await nimmAusDerRotation(repo, [push, pull, legs]);
        final c = await geladen(repo);

        final tag = c.read(gymTagProvider);

        expect(tag.tag.week, isEmpty);
        expect(tag.laedt, isFalse);
      },
    );

    test(
      'ein aus der Rotation genommener Platz taucht in der Fokus-Karte nicht '
      'mehr auf',
      () async {
        final repo = HakenRepo(neueDb());
        final c = await geladen(repo);
        await nimmAusDerRotation(repo, [push]);
        c.invalidate(gymRotationQuelleProvider);
        await lesen(c);

        final tag = c.read(gymTagProvider);

        expect(plaetze(tag), [pull, legs]);
        expect(tag.tag.focus, isA<Rest>());
        expect((tag.tag.focus as Rest).next, isNull);
      },
    );

    test('eine Kennung ohne Training lässt die Kette werfen — kein stilles '
        'Verwerfen (Spec 24 Nr. 4)', () async {
      final repo = HakenRepo(neueDb())
        ..rotationErsatz = ['Push', 'ZZ-UNBEKANNT'];
      final c = await geladen(repo);

      expect(
        () => c.read(gymTagProvider),
        throwsA(anything),
        reason:
            'Ein Programmierfehler, keine Datenlage: Er soll sichtbar '
            'sein, statt zu einer Rotation zu werden, die still kürzer ist',
      );
    });

    test(
      'der Tag wird gehalten, nicht je Zugriff gerechnet (Fehler `03`)',
      () async {
        final c = await geladen(HakenRepo(neueDb()));

        expect(
          identical(c.read(gymTagProvider), c.read(gymTagProvider)),
          isTrue,
        );
      },
    );

    test(
      'ohne Ablage im Baum: die Startbefüllung — drei Plätze, nicht A bis D',
      () {
        final c = ProviderContainer(
          retry: (_, _) => null,
          overrides: [clockProvider.overrideWithValue(() => jetzt)],
        );
        addTearDown(c.dispose);
        c.listen(gymTagProvider, (_, _) {});

        final tag = c.read(gymTagProvider);

        expect(tag.laedt, isFalse);
        expect(plaetze(tag), [push, pull, legs]);
      },
    );
  });

  group('Wochenleiste und Fokus-Karte zeigen die Rotation', () {
    Future<TrainingsHuelle> gym(
      WidgetTester tester, {
      HakenRepo? repo,
      Future<void> Function(HakenRepo repo)? vorher,
      bool warte = true,
    }) async {
      final h = trainingsHuelle(repo: repo, echterTag: true);
      await vorher?.call(h.repo);
      await zeigeGym(tester, h, warte: warte);
      return h;
    }

    Future<void> loescheAlle(HakenRepo repo, Iterable<Workout> weg) =>
        nimmAusDerRotation(repo, weg);

    testWidgets('drei Plätze: Push, Pull, Legs — und kein Gym A bis D', (
      tester,
    ) async {
      await gym(tester);

      for (final w in rotationPpl) {
        expect(find.byKey(kPlatz(w)), findsOneWidget, reason: w.label);
      }
      for (final w in Workout.rotation) {
        expect(
          find.byKey(kPlatz(w)),
          findsNothing,
          reason: '${w.label}: in der Oberfläche nirgends mehr startbar (23)',
        );
      }
      expect(find.byKey(kWocheLeer), findsNothing);
    });

    testWidgets('die Plätze stehen in der Reihenfolge der Rotation', (
      tester,
    ) async {
      await gym(tester);

      double links(Workout w) => tester.getTopLeft(find.byKey(kPlatz(w))).dx;
      expect(links(push), lessThan(links(pull)));
      expect(links(pull), lessThan(links(legs)));
    });

    testWidgets('jeder Platz ist die Tür zur Erfassung — genau dieses '
        'Trainings', (tester) async {
      final h = await gym(tester);

      for (final w in rotationPpl) {
        h.befehle.clear();
        // Der Kontext vor dem Tippen: danach liegt die Erfassung obenauf,
        // und die Leiste ist ausgeblendet.
        final kontext = tester.element(find.byKey(kWoche));
        await tippe(tester, find.byKey(kPlatz(w)));
        expect(h.befehle, hasLength(1), reason: w.label);
        expect(h.befehle.single.ersetztStapel, isFalse, reason: w.label);
        expect(
          h.befehle.single.builder(kontext),
          isA<GymLogView>(),
          reason: w.label,
        );
        await zurueck(tester, h);
      }
    });

    testWidgets('während die Rotation gelesen wird: graue Formen, kein '
        '„Ruhetag", kein „offen", kein Grund-Satz (`01`)', (tester) async {
      final repo = HakenRepo(neueDb())..rotationTor = Completer<void>();
      await gym(tester, repo: repo, warte: false);

      expect(find.byKey(kWoche), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(kWoche),
          matching: find.byType(Platzhalter),
        ),
        findsAtLeastNWidgets(1),
        reason: 'Die Leiste steht da, ihre Inhalte als graue Formen (Spec 10)',
      );
      final texte = flach(alleTexteDes(tester));
      expect(
        flach(texteUnter(tester, kWoche)),
        isNot(contains(gymWochenStatus(const Open()))),
      );
      expect(find.byKey(kWocheLeer), findsNothing);
      expect(texte, isNot(contains('Ruhetag')));
      expect(
        texte,
        isNot(
          contains(
            flach(
              gymFokusUntertitel(
                const Rest(next: null, inDays: null, overdue: null),
                heute: heute,
              ).split('\n').last,
            ),
          ),
        ),
      );
      expect(find.byKey(kKarte), findsOneWidget);
      expect(find.byKey(kLede), findsOneWidget);
    });

    testWidgets('mit dem Lesen stehen die drei Plätze da, ohne dass die '
        'Leiste ihre Größe ändert', (tester) async {
      final repo = HakenRepo(neueDb())..rotationTor = Completer<void>();
      await gym(tester, repo: repo, warte: false);
      final laedt = tester.getSize(find.byKey(kWoche));

      repo.rotationTor!.complete();
      await tester.pumpAndSettle();

      expect(find.byKey(kPlatz(push)), findsOneWidget);
      expect(
        tester.getSize(find.byKey(kWoche)).height,
        closeTo(laedt.height, 0.5),
        reason: '„Werte da, keine Werte, lädt — dieselbe Höhe" (`CLAUDE.md`)',
      );
      expect(
        tester.getSize(find.byKey(kWoche)).width,
        closeTo(laedt.width, 0.5),
      );
    });

    testWidgets(
      'nach dem Herausnehmen eines Platzes: zwei Plätze, dieselbe Form',
      (tester) async {
        final drei = trainingsHuelle(echterTag: true);
        await zeigeGym(tester, drei);
        final referenz = tester.getSize(find.byKey(kWoche));

        await gym(tester, vorher: (repo) => loescheAlle(repo, [pull]));

        expect(find.byKey(kPlatz(push)), findsOneWidget);
        expect(find.byKey(kPlatz(legs)), findsOneWidget);
        expect(
          find.byKey(kPlatz(pull)),
          findsNothing,
          reason:
              'Ein herausgenommener Platz ist nicht mehr in der Woche (24 Nr. 1)',
        );
        expect(
          tester.getSize(find.byKey(kWoche)).height,
          closeTo(referenz.height, 0.5),
        );
        expect(
          tester.getSize(find.byKey(kWoche)).width,
          closeTo(referenz.width, 0.5),
        );
      },
    );

    testWidgets('ein Platz: dieselbe Form', (tester) async {
      final drei = trainingsHuelle(echterTag: true);
      await zeigeGym(tester, drei);
      final referenz = tester.getSize(find.byKey(kWoche));

      await gym(tester, vorher: (repo) => loescheAlle(repo, [push, pull]));

      expect(find.byKey(kPlatz(legs)), findsOneWidget);
      expect(find.byKey(kPlatz(push)), findsNothing);
      expect(find.byKey(kPlatz(pull)), findsNothing);
      expect(
        tester.getSize(find.byKey(kWoche)).height,
        closeTo(referenz.height, 0.5),
      );
      expect(
        tester.getSize(find.byKey(kWoche)).width,
        closeTo(referenz.width, 0.5),
      );
    });

    testWidgets('kein Platz: ein Satz in der Form der Leiste — nie 0, nie ein '
        'Platzhalter', (tester) async {
      final drei = trainingsHuelle(echterTag: true);
      await zeigeGym(tester, drei);
      final referenz = tester.getSize(find.byKey(kWoche));

      await gym(tester, vorher: (repo) => loescheAlle(repo, rotationPpl));

      for (final w in rotationPpl) {
        expect(find.byKey(kPlatz(w)), findsNothing, reason: w.label);
      }
      expect(
        find.byKey(kWocheLeer),
        findsOneWidget,
        reason:
            'Die leere Woche sagt es — statt zu verschwinden (Spec 24 Nr. 1)',
      );
      expect(flach(texteUnter(tester, kWoche)), isNotEmpty);
      expect(
        flach(texteUnter(tester, kWoche)),
        isNot(matches(nullAlsWert)),
        reason: 'Eine Null behauptete „null Trainings erledigt"',
      );
      expect(
        find.descendant(
          of: find.byKey(kWoche),
          matching: find.byType(Platzhalter),
        ),
        findsNothing,
        reason: 'Der Platzhalter gehört allein in den Ladezustand',
      );
      expect(
        tester.getSize(find.byKey(kWoche)).height,
        closeTo(referenz.height, 0.5),
      );
      expect(
        tester.getSize(find.byKey(kWoche)).width,
        closeTo(referenz.width, 0.5),
      );
      expect(find.byKey(kKarte), findsOneWidget, reason: 'Die Karte bleibt');
    });

    testWidgets('wird bei offenem Schirm ein Platz herausgenommen, schrumpft '
        'die Leiste nach neuem Lesen — ohne Sprung in der Form', (
      tester,
    ) async {
      final h = await gym(tester);
      final vorher = tester.getSize(find.byKey(kWoche));
      expect(find.byKey(kPlatz(pull)), findsOneWidget);

      await nimmAusDerRotation(h.repo, [pull]);
      leseNeu(h);
      await tester.pumpAndSettle();

      expect(find.byKey(kPlatz(pull)), findsNothing);
      expect(find.byKey(kPlatz(push)), findsOneWidget);
      expect(find.byKey(kPlatz(legs)), findsOneWidget);
      expect(
        tester.getSize(find.byKey(kWoche)).height,
        closeTo(vorher.height, 0.5),
      );
      expect(
        tester.getSize(find.byKey(kWoche)).width,
        closeTo(vorher.width, 0.5),
      );
    });

    testWidgets('ein gescheitertes Lesen der Rotation lässt keinen Platz-'
        'halter stehen und erfindet keine Woche', (tester) async {
      final repo = HakenRepo(neueDb())..rotationScheitert = true;
      await gym(tester, repo: repo);

      expect(
        find.descendant(
          of: find.byKey(kWoche),
          matching: find.byType(Platzhalter),
        ),
        findsNothing,
        reason:
            'Es läuft nichts mehr; ein Platzhalter für immer wäre `01` '
            'in anderer Gestalt',
      );
      for (final w in rotationPpl) {
        expect(
          find.byKey(kPlatz(w)),
          findsNothing,
          reason: '${w.label}: „nichts da" ist nicht „die Startbefüllung"',
        );
      }
    });

    testWidgets('eine unbekannte Kennung in der Rotation: weder „Ruhetag" noch '
        '„offen" noch eine Zahl', (tester) async {
      final repo = HakenRepo(neueDb())
        ..rotationErsatz = ['Push', 'ZZ-UNBEKANNT'];
      final h = trainingsHuelle(repo: repo, echterTag: true);

      await tester.pumpWidget(h.app);
      await tester.pumpAndSettle();
      // Der Schirm darf laut scheitern (Spec 24 Nr. 4); gemeldet wird der
      // Fehler des Bauens, und er wird hier abgeholt.
      tester.takeException();

      final texte = flach(alleTexteDes(tester));
      expect(texte, isNot(contains('Ruhetag')));
      expect(texte, isNot(contains(gymWochenStatus(const Open()))));
      expect(texte, isNot(matches(nullAlsWert)));
      expect(find.byKey(kWocheLeer), findsNothing);
    });
  });

  group('Die Heute-Zeile liest denselben Tag (Plan 2.8)', () {
    test('Push heute erledigt: die Zeile nennt Push als erledigt', () {
      final tag = gymTagAus(heute: heute, erledigt: {push: heute});

      final zeile = heuteTrainingZeile(tag, heute: heute);

      expect(zeile.titel, contains(push.label));
      expect(zeile.untertitel, startsWith('Erledigt'));
    });

    test('Legs heute erledigt, Legs nicht in der Rotation: Ruhetag, kein '
        'erfundener Platz', () {
      final tag = gymTagAus(
        heute: heute,
        rotation: [push, pull],
        erledigt: {legs: heute},
      );

      expect(heuteTrainingZeile(tag, heute: heute).titel, 'Ruhetag');
    });

    test('ein laufendes Push steht als „angefangen" da', () {
      final tag = gymTagAus(
        heute: heute,
        entwurf: const GymDraft(
          workout: Workout.push,
          doneExercises: 3,
          totalExercises: 7,
        ),
      );

      final zeile = heuteTrainingZeile(tag, heute: heute);

      expect(zeile.titel, contains(push.label));
      expect(zeile.untertitel, startsWith('Angefangen'));
    });

    test(
      'nichts erledigt, nichts läuft: „Ruhetag" — keine Einheit aus A bis D',
      () {
        final zeile = heuteTrainingZeile(gymTagAus(heute: heute), heute: heute);

        expect(zeile.titel, 'Ruhetag');
        for (final w in Workout.rotation) {
          expect(zeile.titel, isNot(contains(w.label)));
          expect(zeile.untertitel, isNot(contains(w.title)));
        }
      },
    );

    test('eine leere Rotation: derselbe Ruhetag, keine Ausnahme', () {
      final zeile = heuteTrainingZeile(
        gymTagAus(heute: heute, rotation: const []),
        heute: heute,
      );

      expect(zeile.titel, 'Ruhetag');
    });
  });
}
