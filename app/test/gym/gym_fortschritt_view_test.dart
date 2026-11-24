import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show UncontrolledProviderScope;
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/design/glas_abstand.dart';
import 'package:repit/design/platzhalter.dart' show ohneWert;
import 'package:repit/design/zeitdiagramm.dart';
import 'package:repit/gym/gym_fortschritt_view.dart';
import 'package:repit/gym/gym_vorschlag_texte.dart';
import 'package:repit/shell/diagramm_zeitraum.dart';
import 'package:repit/shell/router.dart';

import 'gym_fortschritt_support.dart';

/// Widget-Tests für den Schirm **„Fortschritt pro Übung"** (#93),
/// `lib/gym/gym_fortschritt_view.dart` — Aufbau, Auswahl, Kennzahlen,
/// Diagrammkarte, Startzeitraum, Navigation.
///
/// Grundlage: `docs/superpowers/specs/2026-11-11-gym-fortschritt-design.md`
/// und der Entwurf `docs/screens/screens/gym-progress.js`. Die festgelegte
/// API und die Schlüssel stehen im Kopf von `gym_fortschritt_support.dart`.
/// Die Leerzustände und die beiden Pflichtfälle liegen in
/// `gym_fortschritt_leerzustaende_test.dart`, Monatsmaximum, Plateau,
/// Unterstützung und Zeitübungen in `gym_fortschritt_verlauf_test.dart`.
///
/// ## Worauf diese Datei zielt
///
/// `CLAUDE.md`, „Tests": **Zustände und Übergänge, nicht Layout und
/// Beschriftung.** Wo Texte verglichen werden, rufen die Tests dieselben
/// Funktionen auf wie der Schirm (`vorschlagGewichtText`, `gymZahlText`,
/// `vorschlagKurzText`) — sie nageln keinen Wortlaut fest, sondern die
/// Zusage, dass der Schirm sich seine Sätze nicht selbst zusammenbaut.
///
/// Zwei Ausnahmen, an denen ein Wortlaut Anforderung ist: **„Schätzung" bzw.
/// „geschätzt"** (`CLAUDE.md`: jeder solche Wert ist als Schätzung zu
/// kennzeichnen) und **kein „Durchschnitt" in der Fußnote** der Monatsstufen
/// (der Satz würde sonst das Gegenteil von dem behaupten, was die Linie
/// zeigt).
///
/// ## Was hier bewusst **nicht** geprüft wird
///
/// - **Farben, Abstände, Schriftgrößen, Dynamic Type, Golden-Tests.**
/// - **Das Zeichnen der Linien.** Ein `CustomPaint` ist im Widget-Test nicht
///   lesbar; geprüft wird, **was dem Bauteil übergeben wird** (`reihe`,
///   `zweiteReihe`, `verdichtung`), und die Rechnung steht im Kern.
/// - **Die Kopfzeile des Diagramms** („Durchschnitt" oder „Höchstwert") —
///   offene Frage 2 der Spec.
void main() {
  /// Vier Trainings im Abstand einer Woche, Bankdrücken, aufsteigend. Der
  /// jüngste Stand: 62,5 kg × 10 → geschätzt 83,3.
  List<ImportedSession> vier() => [
    bank('S1', morgens(2, 9), 57.5, 10),
    bank('S2', morgens(2, 16), 60, 10),
    bank('S3', morgens(2, 23), 62.5, 8),
    bank('S4', morgens(3, 2), 62.5, 10),
  ];

  group('Hausordnung', () {
    testWidgets('die Seite bringt Gerüst und Leiste mit', (tester) async {
      final h = fortschrittHuelle();
      await zeigeFortschritt(tester, h);

      expect(find.byType(GymFortschrittSeite), findsOneWidget);
      expect(find.byType(CupertinoPageScaffold), findsOneWidget);
      expect(find.byType(CupertinoNavigationBar), findsOneWidget);
    });

    testWidgets('der Schirm bringt weder Gerüst noch Leiste noch Navigator '
        'mit', (tester) async {
      final h = fortschrittHuelle();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: h.container,
          child: CupertinoApp(
            home: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(padding: const EdgeInsets.only(top: 47, bottom: 34)),
                child: const GymFortschrittView(),
              ),
            ),
          ),
        ),
      );
      await verstreiche(tester);

      expect(find.byType(CupertinoPageScaffold), findsNothing);
      expect(find.byType(CupertinoNavigationBar), findsNothing);
      expect(
        find.descendant(
          of: find.byType(GymFortschrittView),
          matching: find.byType(Navigator),
        ),
        findsNothing,
        reason:
            'Jeder Tab führt seinen eigenen Stapel; ein zweiter hier wäre '
            'ein zweiter (`CLAUDE.md`)',
      );
    });

    testWidgets('der Abstand oben kommt aus `GlasAbstand`', (tester) async {
      final h = fortschrittHuelle();
      await zeigeFortschritt(tester, h);

      final scroll = tester.widget<SingleChildScrollView>(
        find
            .descendant(
              of: find.byType(GymFortschrittView),
              matching: find.byType(SingleChildScrollView),
            )
            .first,
      );
      final erwartet = GlasAbstand.of(
        tester.element(find.byType(GymFortschrittView)),
      );
      expect(erwartet.top, greaterThan(0), reason: 'sonst prüft das nichts');
      expect((scroll.padding! as EdgeInsets).top, erwartet.top);
    });

    testWidgets('jeder Abschnitt steht in jeder Datenlage da', (tester) async {
      final faelle = <String, List<ImportedSession>>{
        'keine Trainings': const [],
        'ein Training': [bank('S1', morgens(3, 2), 60, 10)],
        'vier Trainings': vier(),
      };

      for (final fall in faelle.entries) {
        final h = fortschrittHuelle();
        await h.lege(fall.value);
        await zeigeFortschritt(tester, h);

        for (final key in kFPflichtAbschnitte) {
          expect(
            find.byKey(key),
            findsOneWidget,
            reason:
                '${fall.key}: $key fehlt. Jeder Abschnitt steht in jeder '
                'Lage — nur die Füllung ändert sich',
          );
        }
        expect(find.byType(ErrorWidget), findsNothing, reason: fall.key);
        expect(tester.takeException(), isNull, reason: fall.key);
      }
    });
  });

  group('Navigation', () {
    testWidgets('der Sprung geht auf den Stapel des aktuellen Tabs, ohne '
        'ihn zu wechseln', (tester) async {
      final h = fortschrittHuelle();
      await zeigeFortschritt(tester, h);
      final router = AppRouter();
      final tabVorher = router.tab;

      oeffneGymFortschritt(router);
      final befehl = router.nimmBefehl();

      expect(befehl, isNotNull);
      expect(
        befehl!.ersetztStapel,
        isFalse,
        reason: 'Geschoben wird auf den Stapel, nicht ersetzt',
      );
      expect(
        befehl.tab,
        tabVorher,
        reason:
            'Gepusht wird in den Stapel des Tabs, aus dem man kommt '
            '(`AppTarget.aktuell`) — sonst führte „zurück" in ein Menü, '
            'das der Nutzer nie geöffnet hat',
      );
      expect(router.tab, tabVorher, reason: 'Kein Tab-Wechsel');
    });

    testWidgets('das Ziel ist die Seite, mit der vorgewählten Übung', (
      tester,
    ) async {
      final router = AppRouter();
      oeffneGymFortschritt(router, uebungId: idDips);
      final befehl = router.nimmBefehl()!;

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
      expect((gebaut as GymFortschrittSeite).uebungId, idDips);
    });
  });

  group('Die Auswahl der Übung', () {
    testWidgets('ohne Vorgabe steht die erste Übung von Gym A da', (
      tester,
    ) async {
      final h = fortschrittHuelle();
      await zeigeFortschritt(tester, h);

      final erste = ExerciseCatalog.exercisesFor(Workout.a).first;
      expect(
        textVon(tester, kFAuswahl),
        contains(erste.name),
        reason:
            'Eine feste Vorgabe: Die Auswahl darf nicht erst springen, wenn '
            'der Verlauf eintrifft (Spec 6)',
      );
    });

    testWidgets('die Vorgabe des Aufrufers gewinnt', (tester) async {
      final h = fortschrittHuelle(uebungId: idDips);
      await zeigeFortschritt(tester, h);

      expect(
        textVon(tester, kFAuswahl),
        contains(ExerciseCatalog.all[idDips]!.name),
      );
    });

    // Ersetzt (#551, Nachtrag 17 Nr. 4, Tims Wort, `TEST_AENDERN=1`): Das
    // Menü bietet **nur Trainierte** an, nicht mehr den vollen Katalog.
    // Die Menü-Fälle im Einzelnen stehen in `gym_fortschritt_menue_test.dart`.
    testWidgets('das Menü bietet nur Trainierte an — ohne ein einziges '
        'Training nur die gewählte Übung (Nachtrag 17 Nr. 4)', (tester) async {
      final h = fortschrittHuelle();
      await zeigeFortschritt(tester, h);
      final vorgabe = ExerciseCatalog.exercisesFor(Workout.a).first;

      await tester.tap(find.byKey(kFAuswahl));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.byKey(kFWahl(vorgabe.id), skipOffstage: false),
        findsOneWidget,
        reason:
            'die aktuell gewählte Übung steht im Menü, auch ohne Verlauf — '
            'was die Auswahlzeile nennt, findet das Menü wieder',
      );
      for (final id in ExerciseCatalog.all.keys) {
        if (id == vorgabe.id) continue;
        expect(
          find.byKey(kFWahl(id), skipOffstage: false),
          findsNothing,
          reason:
              '$id: ohne Verlauf nicht im Menü — es beantwortet „wie '
              'entwickle ich mich", nicht „was gibt es" (Tim, 20.11.2026)',
        );
      }
    });

    testWidgets('eine andere Übung wählen zeigt **ihren** Verlauf, nicht '
        'den der vorigen', (tester) async {
      final h = fortschrittHuelle();
      await h.lege([
        sitzung('S1', morgens(3, 2), {
          idBank: [(60, 10)],
          idDips: [(-27, 8)],
        }),
        sitzung('S2', morgens(3, 9), {
          idBank: [(62.5, 10)],
          idDips: [(-24.5, 8)],
        }),
      ]);
      await zeigeFortschritt(tester, h);
      expect(
        kachelWert(tester, kFWertHoechst),
        vorschlagGewichtText(62.5, ExerciseCatalog.all[idBank]!),
      );

      await waehleUebung(tester, idDips);

      expect(
        textVon(tester, kFAuswahl),
        contains(ExerciseCatalog.all[idDips]!.name),
      );
      expect(
        kachelWert(tester, kFWertHoechst),
        vorschlagGewichtText(-24.5, ExerciseCatalog.all[idDips]!),
        reason: 'Dips: der jüngste Stand, nicht der vom Bankdrücken',
      );
    });
  });

  group('Die beiden Kennzahlen', () {
    testWidgets('nennen den jüngsten Stand der Übung', (tester) async {
      final h = fortschrittHuelle();
      await h.lege(vier());
      await zeigeFortschritt(tester, h);

      final bankUebung = ExerciseCatalog.all[idBank]!;
      expect(
        kachelWert(tester, kFWertHoechst),
        vorschlagGewichtText(62.5, bankUebung),
      );
      final einRm = kachelWert(tester, kFWert1rm);
      expect(einRm, contains(gymZahlText(83.3)));
      expect(einRm, contains('kg'));
    });

    testWidgets('ein einziges Training: eine Zahl je Kachel, keine '
        'Entwicklung', (tester) async {
      final h = fortschrittHuelle();
      await h.lege([bank('S1', morgens(3, 2), 70, 6)]);
      await zeigeFortschritt(tester, h);

      expect(
        kachelWert(tester, kFWertHoechst),
        vorschlagGewichtText(70, ExerciseCatalog.all[idBank]!),
      );
      expect(kachelWert(tester, kFWert1rm), contains(gymZahlText(84)));
      expect(
        find.byType(Zeitdiagramm),
        findsNothing,
        reason:
            'Ein Punkt ist keine Linie. Es gibt auch keinen Trendpfeil und '
            'kein „+ 2,5 kg": Es gibt keinen Vergleich, also keinen Pfeil',
      );
      expect(
        find.byKey(kFPlateau),
        findsNothing,
        reason: 'Plateau braucht vier Trainings',
      );
    });

    testWidgets('ohne Training stehen beide da und sagen „kein Wert" — keine '
        '0', (tester) async {
      final h = fortschrittHuelle();
      await zeigeFortschritt(tester, h);

      for (final key in [kFWertHoechst, kFWert1rm]) {
        expect(textVon(tester, key), ohneWert, reason: '$key');
      }
    });

    testWidgets('die Beschriftung des 1RM nennt, dass es geschätzt ist', (
      tester,
    ) async {
      final h = fortschrittHuelle();
      await h.lege(vier());
      await zeigeFortschritt(tester, h);

      expect(
        textVon(tester, kFKachel1rm),
        matches(RegExp('gesch[äa]tzt|Sch[äa]tzung', caseSensitive: false)),
        reason:
            '`CLAUDE.md`: Jeder Trainings-Wert ist als Schätzung zu '
            'kennzeichnen. Die Kachel sagt es **einmal**, kurz — ohne '
            'Absatz je Zahl',
      );
    });

    testWidgets('die Fußnote nennt die Formel und sagt „Schätzung" — in '
        'jeder Lage derselbe Satz', (tester) async {
      final texte = <String>[];
      for (final lage in [
        const <ImportedSession>[],
        [bank('S1', morgens(3, 2), 60, 10)],
        vier(),
      ]) {
        final h = fortschrittHuelle();
        await h.lege(lage);
        await zeigeFortschritt(tester, h);
        texte.add(textVon(tester, kFFussnote));
      }

      for (final text in texte) {
        expect(text, isNotEmpty);
        expect(
          text,
          matches(RegExp('Sch[äa]tzung', caseSensitive: false)),
          reason: 'Epley ist eine Schätzung, kein Maximalversuch',
        );
      }
      expect(
        texte.toSet(),
        hasLength(1),
        reason:
            'Der Grund steht einmal und überall gleich — er hängt nicht an '
            'der Datenlage',
      );
    });
  });

  group('Die Diagrammkarte', () {
    testWidgets('ab dem zweiten Trainingstag steht eine Linie da', (
      tester,
    ) async {
      final h = fortschrittHuelle();
      await h.lege([
        bank('S1', morgens(3, 2), 60, 10),
        bank('S2', morgens(3, 9), 62.5, 10),
      ]);
      await zeigeFortschritt(tester, h);

      expect(
        find.descendant(
          of: find.byKey(kFDiagramm),
          matching: find.byType(Zeitdiagramm),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(kFDiagrammLeer),
        findsNothing,
        reason: 'Mit zwei Punkten steht kein „zu wenige Trainings" mehr da',
      );
    });

    testWidgets('mit einem einzigen Trainingstag steht die Karte da, aber '
        'ohne Linie', (tester) async {
      final h = fortschrittHuelle();
      await h.lege([bank('S1', morgens(3, 2), 60, 10)]);
      await zeigeFortschritt(tester, h);

      expect(find.byKey(kFDiagramm), findsOneWidget);
      expect(find.byType(Zeitdiagramm), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(kFDiagramm),
          matching: find.byKey(kFDiagrammLeer),
        ),
        findsOneWidget,
        reason:
            'Die Karte verschwindet nicht, sie steht ungefüllt da und sagt, '
            'warum (`CLAUDE.md`, „Eine Anzeige hat genau eine Form")',
      );
    });

    testWidgets('zwei Trainings am selben Berliner Tag sind **ein** Punkt', (
      tester,
    ) async {
      final h = fortschrittHuelle();
      await h.lege([
        sitzung('S1', morgens(3, 2), {
          idBank: [(60, 10)],
        }),
        sitzung('S2', morgens(3, 2), {
          idBank: [(65, 5)],
        }, workout: Workout.push),
      ]);
      await zeigeFortschritt(tester, h);

      expect(
        find.byType(Zeitdiagramm),
        findsNothing,
        reason:
            'Zwei Sitzungen an einem Tag sind keine Entwicklung — eine '
            'Linie braucht zwei **Tage**',
      );
      expect(find.byKey(kFDiagrammLeer), findsOneWidget);
      expect(
        kachelWert(tester, kFWertHoechst),
        vorschlagGewichtText(65, ExerciseCatalog.all[idBank]!),
        reason: 'Das Maximum beider Sitzungen',
      );
    });

    testWidgets('die Leiste bietet W M 6M J an und kein T', (tester) async {
      final h = fortschrittHuelle();
      await h.lege(vier());
      await zeigeFortschritt(tester, h);

      expect(
        leiste(tester).stufen,
        containsAll(const [
          DiagrammStufe.woche,
          DiagrammStufe.monat,
          DiagrammStufe.halbjahr,
          DiagrammStufe.jahr,
        ]),
      );
      expect(leiste(tester).stufen, hasLength(4));
    });

    testWidgets('die Fußnote der Monatsstufen behauptet kein Mittel', (
      tester,
    ) async {
      final h = fortschrittHuelle();
      await h.lege(vier());
      await zeigeFortschritt(tester, h);

      for (final stufe in [DiagrammStufe.halbjahr, DiagrammStufe.jahr]) {
        await waehleStufe(tester, stufe);
        expect(
          textVon(tester, const Key('diagramm-fussnote')).toLowerCase(),
          isNot(contains('durchschnitt')),
          reason:
              '$stufe: „Je Punkt ein Monat, gezeigt wird der '
              'Monatsdurchschnitt" stand im alten Entwurf und im Code der '
              'alten App — jetzt zeigt die Linie das Maximum, und der Satz '
              'darf nicht das Gegenteil sagen',
        );
      }
    });
  });

  group('Der Startzeitraum richtet sich nach dem Verlauf', () {
    testWidgets('zwei Trainings in einer Woche starten **nicht** in der '
        'Wochenstufe', (tester) async {
      final h = fortschrittHuelle();
      await h.lege([
        bank('S1', morgens(3, 2), 60, 10),
        bank('S2', morgens(3, 5), 62.5, 10),
      ]);
      await zeigeFortschritt(tester, h);

      expect(
        leiste(tester).gewaehlt,
        DiagrammStufe.monat,
        reason:
            'Bei weniger als drei Monaten Verlauf ist `M` die Startstufe '
            '(`docs/SPEC.md` 4.4, Entscheidung vom 26.10.2026). Das gilt für '
            'diesen Schirm vor der allgemeinen Regel „immer das kleinste '
            'zuerst" (offene Frage 1 der Spec)',
      );
    });

    testWidgets('zwei Monate Verlauf starten in `M` — je Training ein '
        'Punkt', (tester) async {
      final h = fortschrittHuelle();
      await h.lege([
        bank('S1', morgens(1, 12), 55, 10),
        bank('S2', morgens(2, 9), 57.5, 10),
        bank('S3', morgens(3, 2), 60, 10),
      ]);
      await zeigeFortschritt(tester, h);

      expect(leiste(tester).gewaehlt, DiagrammStufe.monat);
    });

    testWidgets('drei Monate Verlauf starten in `6M`', (tester) async {
      final h = fortschrittHuelle();
      await h.lege([
        bank('S1', morgens(12, 8, 2025), 55, 10),
        bank('S2', morgens(1, 12), 57.5, 10),
        bank('S3', morgens(3, 2), 60, 10),
      ]);
      await zeigeFortschritt(tester, h);

      expect(
        leiste(tester).gewaehlt,
        DiagrammStufe.halbjahr,
        reason:
            'Ab etwa drei Monaten Verlauf trägt das halbe Jahr: Es zeigt '
            'mehr als einen Punkt und keine Gerade, die es nie gab',
      );
    });
  });

  group('Keine Zahl ohne Quelle', () {
    testWidgets('der Hinweiskasten nennt den Satz aus der einen Stelle der '
        'Vorschlagstexte', (tester) async {
      final h = fortschrittHuelle();
      // Alle Sätze an der oberen Grenze (10) → Steigern.
      await h.lege([
        sitzung('S1', morgens(3, 2), {
          idBank: [(60, 10), (60, 10)],
        }),
        sitzung('S2', morgens(3, 9), {
          idBank: [(62.5, 10), (62.5, 10)],
        }),
      ]);
      await zeigeFortschritt(tester, h);

      final bankUebung = ExerciseCatalog.all[idBank]!;
      final erwartet = vorschlagKurzText(
        const Increase(toWeight: 65, by: 2.5, targetReps: 6),
        bankUebung,
        hatVerlauf: true,
      );
      expect(textVon(tester, kFHinweis), contains(erwartet));
      expect(
        find.byKey(kFPlateau),
        findsNothing,
        reason: 'Zwei Trainings sind kein Plateau',
      );
    });
  });
}
