import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/design/icon_row.dart';
import 'package:repit/design/platzhalter.dart';
import 'package:repit/design/section_header.dart';
import 'package:repit/gym/gym_provider.dart';
import 'package:repit/shell/heute_training.dart';
import 'package:repit/shell/router.dart';
import 'package:repit/shell/ziele.dart';

/// Der Abschnitt **Heute Training** auf Home (#501, Punkt 2).
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung**
/// (`CLAUDE.md`). Diese Datei darf ausgeführt, aber nicht verändert
/// werden.
///
/// ## Was Tim entschieden hat
///
/// - **13.11.2026:** Zwischen Ringblock und Erholung steht ein neuer
///   Abschnitt. „Heute noch offen" und „Erledigt" fallen dafür weg.
/// - **16.11.2026:** Er zeigt **die heutige Einheit mit ihrem Stand** —
///   nicht den Wochenstand. An einem Ruhetag steht er trotzdem da und
///   sagt das.
///
/// ## Was hier geprüft wird
///
/// Zustände und Übergänge, nicht Layout und Wortlaut (`CLAUDE.md`). Wo
/// ein Text geprüft wird, über ein Stichwort und nicht über den ganzen
/// Satz — die **eine** Ausnahme ist der Stand am Anfang des Untertitels
/// („Heute", „Angefangen", „Erledigt", „Heute kein Gym", „Pause"): Das
/// ist keine Beschriftung, sondern eine Tabelle Zustand → Wort, und ihr
/// Wert liegt gerade darin, dass sie je Zustand verschieden ist.
///
/// ## Zahlen in dieser Datei
///
/// Alle erfunden. Der Übungskatalog ist Fachinhalt aus `trainings_core`
/// und keine Gesundheitsangabe — deshalb darf er hier vorkommen.
void main() {
  // Montag, 16.11.2026, 09:00 Berliner Zeit (CET, +1).
  final jetzt = DateTime.utc(2026, 11, 16, 8);
  final heute = BerlinCalendar.startOfDay(jetzt);
  final gestern = BerlinCalendar.addDays(heute, -1);

  GymSlot platz(Workout workout, GymSlotStatus status) =>
      GymSlot(workout: workout, weekday: null, status: status);

  GymTag tag(GymFocus focus, {List<GymSlot> woche = const [], bool laedt = false}) =>
      GymTag(tag: GymDay(focus: focus, week: woche), laedt: laedt);

  // Nachgezogen am 19.11.2026 mit TEST_AENDERN=1 (Task 2.8 der eigenen
  // Trainings, Spec 23): Die Fixturen waren Gym A und Gym B. Der Planer
  // liest seit der Rotation-Umstellung die gespeicherte Rotation — Push,
  // Pull, Legs —, und Gym A bis D sind nirgends mehr startbar. Eine Zeile
  // „Heute · Gym A" beschriebe einen Zustand, den es nicht mehr gibt. Die
  // Aussagen der Fälle sind dieselben; nur das Workout wechselt.
  final geplant = tag(const Planned(workout: Workout.push));
  final angefangen = tag(
    const InProgress(workout: Workout.push, done: 3, total: 7),
  );
  final erledigt = tag(
    const Rest(next: null, inDays: null, overdue: null),
    woche: [platz(Workout.push, Done(heute)), platz(Workout.pull, const Open())],
  );
  final ruhetag = tag(
    const Rest(next: null, inDays: null, overdue: null),
    woche: [platz(Workout.push, Done(gestern)), platz(Workout.pull, const Open())],
  );
  final pause = tag(
    Recovery(dayAfterSurgery: 3, earliestReturn: BerlinCalendar.addDays(heute, 11)),
  );
  final laedtNoch = tag(
    const Rest(next: null, inDays: null, overdue: null),
    laedt: true,
  );

  // ───────────────────────────────────────────────────────────────────
  // Die Zeile als reine Rechnung — ohne Widget prüfbar.
  // ───────────────────────────────────────────────────────────────────

  group('Die Zeile nennt die heutige Einheit und ihren Stand', () {
    test('steht heute Push an, steht Push da', () {
      final zeile = heuteTrainingZeile(geplant, heute: heute);

      expect(zeile.titel, contains(Workout.push.label));
      expect(
        zeile.titel,
        contains(Workout.push.title),
        reason: 'der Entwurf schreibt „Push — Brust, Schultern, Trizeps"',
      );
      expect(
        zeile.untertitel,
        startsWith('Heute'),
        reason: 'der Stand steht vorn, das Detail dahinter',
      );
      expect(
        zeile.untertitel,
        contains('${Workout.push.minutes}'),
        reason: 'die ungefähre Dauer aus dem Katalog, nicht geraten',
      );
    });

    test('ein angefangenes Training sagt, wie weit es ist', () {
      final zeile = heuteTrainingZeile(angefangen, heute: heute);

      expect(zeile.titel, contains(Workout.push.label));
      expect(zeile.untertitel, startsWith('Angefangen'));
      expect(
        zeile.untertitel,
        contains('3'),
        reason: 'drei von sieben Übungen sind erfasst',
      );
      expect(zeile.untertitel, contains('7'));
    });

    test('heute schon trainiert: die Einheit bleibt stehen, als erledigt', () {
      final zeile = heuteTrainingZeile(erledigt, heute: heute);

      expect(
        zeile.titel,
        contains(Workout.push.label),
        reason:
            'nach dem Training darf der Abschnitt nicht auf „Ruhetag" '
            'umspringen — sonst sähe der Abend aus wie ein Tag, an dem '
            'nichts geplant war',
      );
      expect(zeile.untertitel, startsWith('Erledigt'));
    });

    test('ein Abschluss von gestern macht heute keinen erledigten Tag', () {
      final zeile = heuteTrainingZeile(ruhetag, heute: heute);

      expect(zeile.titel, 'Ruhetag');
      expect(zeile.untertitel, startsWith('Heute kein Gym'));
    });

    test('ohne jeden Platz bleibt es beim Ruhetag', () {
      final zeile = heuteTrainingZeile(
        tag(const Rest(next: null, inDays: null, overdue: null)),
        heute: heute,
      );

      expect(zeile.titel, 'Ruhetag');
    });

    test('nach der OP steht die ärztliche Freigabe dabei', () {
      final zeile = heuteTrainingZeile(pause, heute: heute);

      expect(zeile.untertitel, startsWith('Pause'));
      expect(
        zeile.untertitel.toLowerCase(),
        contains('ärztlich'),
        reason:
            'eine Pausenempfehlung ohne Absender wäre eine Diagnose '
            '(`CLAUDE.md`)',
      );
    });

    test('kein Datum im Text, das nicht aus den Daten kommt', () {
      for (final zustand in [geplant, angefangen, erledigt, ruhetag, pause]) {
        final zeile = heuteTrainingZeile(zustand, heute: heute);
        expect(
          RegExp(r'20\d\d').hasMatch('${zeile.titel} ${zeile.untertitel}'),
          isFalse,
          reason: 'kein hartcodiertes Ereignisdatum (`CLAUDE.md`)',
        );
      }
    });
  });

  // ───────────────────────────────────────────────────────────────────
  // Der Abschnitt im Baum.
  // ───────────────────────────────────────────────────────────────────

  Widget huelle(Widget kind) => CupertinoApp(
    home: CupertinoPageScaffold(child: kind),
  );

  Future<void> zeige(
    WidgetTester tester,
    GymTag zustand, {
    AppRouter? router,
  }) async {
    await tester.pumpWidget(
      huelle(HeuteTraining(tag: zustand, heute: heute, router: router)),
    );
    await tester.pumpAndSettle();
  }

  group('Der Abschnitt steht in jedem Zustand', () {
    testWidgets('mit seinem Gruppenkopf und genau einer Zeile', (tester) async {
      for (final zustand in [geplant, angefangen, erledigt, ruhetag, pause]) {
        await zeige(tester, zustand);

        final kopf = tester.widgetList<SectionHeader>(
          find.byType(SectionHeader),
        );
        expect(kopf, hasLength(1));
        expect(kopf.first.title, 'Heute Training');
        expect(find.byType(IconRow), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
      }
    });

    testWidgets('und behält dabei seine Höhe — eine Anzeige, eine Form', (
      tester,
    ) async {
      // 393 Punkt: Gerätebreite, nicht Flutters 800er Testfläche.
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      double? erste;
      for (final zustand in [
        geplant,
        angefangen,
        erledigt,
        ruhetag,
        pause,
        laedtNoch,
      ]) {
        await zeige(tester, zustand);
        final hoehe = tester.getRect(find.byType(IconRow)).height;
        erste ??= hoehe;
        expect(
          hoehe,
          closeTo(erste, 0.5),
          reason:
              'fällt die Zeile im Ruhetag kürzer aus, rutscht alles '
              'darunter, sobald ein Training ansteht',
        );
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  });

  group('Während gelesen wird, behauptet nichts eine Datenlage', () {
    testWidgets('kein „Ruhetag", sondern eine graue Form', (tester) async {
      await zeige(tester, laedtNoch);

      expect(
        find.text('Ruhetag'),
        findsNothing,
        reason:
            '„heute kein Gym" ist eine Aussage über die Daten und darf '
            'erst stehen, wenn nachgesehen wurde (Fehler `01`)',
      );
      expect(
        find.byType(Platzhalter),
        findsWidgets,
        reason: 'an seiner Stelle steht die Form, nicht nichts',
      );
    });

    testWidgets('ist nachgesehen, steht der Satz da', (tester) async {
      await zeige(tester, ruhetag);

      expect(find.text('Ruhetag'), findsOneWidget);
      expect(find.byType(Platzhalter), findsNothing);
    });
  });

  group('Die Tür', () {
    testWidgets('führt auf den Gym-Tab — in jedem Zustand dieselbe', (
      tester,
    ) async {
      for (final zustand in [geplant, erledigt, ruhetag, pause]) {
        final router = AppRouter();
        router.open(AppTarget.mehr());
        router.nimmBefehl();
        await zeige(tester, zustand, router: router);

        await tester.tap(find.byType(IconRow));
        await tester.pumpAndSettle();

        expect(
          router.tab,
          Tab.gym,
          reason: 'die Zeile ist die Tür zum Gym-Schirm',
        );

        await tester.pumpWidget(const SizedBox.shrink());
      }
    });

    testWidgets('ohne Router gibt es keine Tür und keinen Winkel', (
      tester,
    ) async {
      await zeige(tester, geplant);

      final zeile = tester.widget<IconRow>(find.byType(IconRow));
      expect(zeile.onTap, isNull);
      expect(
        find.descendant(
          of: find.byType(IconRow),
          matching: find.byIcon(CupertinoIcons.chevron_right),
        ),
        findsNothing,
        reason:
            'ein Winkel ohne Ziel ist genau der Fehler, den '
            '`docs/screens/pruefen.mjs` sucht',
      );
    });

    // **Seit #516 trägt der Gruppenkopf gar keinen Zusatz** — mit Router
    // wie ohne (Tim, 16.11.2026: „den blauen Button Gym und Details
    // ebenfalls weg"). Bis dahin stand hier das Gegenteil: „Gym" mit
    // `aufZusatz` als zweite Tür. Die Tür selbst bleibt, sie liegt auf der
    // Karte darüber — das bewachen die beiden Fälle davor.
    testWidgets('trägt keinen Zusatz, mit Router wie ohne', (tester) async {
      for (final router in [AppRouter(), null]) {
        await zeige(tester, geplant, router: router);

        final kopf = tester.widget<SectionHeader>(find.byType(SectionHeader));
        expect(kopf.zusatz, isNull);
        expect(kopf.aufZusatz, isNull);

        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  });
}
