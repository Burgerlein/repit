import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/design/muskel_figur.dart';

import 'muskel_figur_support.dart';

/// Widget-Tests für **`MuskelFigur`** (#533 unter #531, Task 2.1; Spec 8.1).
/// Vertrag, Schlüssel und Lesehilfen stehen im Kopf von
/// `muskel_figur_support.dart`.
///
/// ## Was die Anforderung bewacht
///
/// - **Die gefärbte Menge kommt an.** Der Aufrufer rechnet sie
///   (`WorkoutMuscles.trained`); der Painter trägt sie als Eigenschaft, und der
///   Test liest sie — keine Pixel.
/// - **Muskeln mit mehreren Pfaden färben alle ihre Pfade** (Rumpf, Unterarme,
///   Oberschenkel …), **ein Muskel, der auf der gezeigten Seite nicht liegt,
///   erscheint dort nicht**, und **Haut bleibt Haut** (Spec 8.1).
/// - **Der Painter ist wertgleich** (Spec 13): `==` über die gefärbte Menge —
///   samt Farben — und die Seite, damit er nicht bei jedem Bild neu zeichnet
///   (Fehler `03`).
/// - **Der Vorlesetext nennt Zustand und Muskeln, nicht das Zeichen**
///   (`CLAUDE.md`): Der Baustein trägt den Text des Aufrufers als **einen**
///   Knoten; eine leere Menge baut ohne Fehler und sagt es der Aufrufer.
///
/// ## Wer hat was entschieden
///
/// - **Entscheidung von Tim [19.11.2026, Spec 22 Nr. 2]:** Das Detail zeigt
///   beide Seiten nebeneinander, die Kachel eine; gedreht wird nur die Kachel.
/// - **Folgerung aus Spec 8.1:** Form des Widgets, die Regeln zu Pfaden und
///   Haut, „der Painter trägt die gefärbte Menge als Eigenschaft".
/// - **Festlegung des Test-Agenten:** Name und Form von
///   [MuskelFigurPainter], die Schlüssel — siehe Kopf von
///   `muskel_figur_support.dart`.
///
/// **Die Zahlen für Push, Pull und Legs unten sind aus dem Katalog und der
/// Pfaddatei hergeleitet und als Zahl hingeschrieben** (Stand 19.11.2026:
/// `WorkoutMuscles.trained` der drei Start-Templates gegen
/// `docs/screens/figure-data.js`).
void main() {
  final push = WorkoutMuscles.trained(
    WorkoutTemplates.byId(Workout.push.code)!.exercises,
  );
  final pull = WorkoutMuscles.trained(
    WorkoutTemplates.byId(Workout.pull.code)!.exercises,
  );
  final legs = WorkoutMuscles.trained(
    WorkoutTemplates.byId(Workout.legs.code)!.exercises,
  );

  Map<Muscle, Color> faerbe(Set<Muscle> menge) => {
    for (final m in menge) m: rot,
  };

  group('Welche Hälften stehen da', () {
    testWidgets('`vorne` zeigt nur die Vorderseite', (tester) async {
      await zeigeFigur(
        tester,
        MuskelFigur(
          gefaerbt: faerbe(push),
          seite: MuskelSeite.vorne,
          semantik: 'Vorderseite',
        ),
      );

      expect(find.byKey(kMuskelFigurSeite(MuskelSeite.vorne)), findsOneWidget);
      expect(find.byKey(kMuskelFigurSeite(MuskelSeite.hinten)), findsNothing);
    });

    testWidgets('`hinten` zeigt nur die Rückseite', (tester) async {
      await zeigeFigur(
        tester,
        MuskelFigur(
          gefaerbt: faerbe(pull),
          seite: MuskelSeite.hinten,
          semantik: 'Rückseite',
        ),
      );

      expect(find.byKey(kMuskelFigurSeite(MuskelSeite.hinten)), findsOneWidget);
      expect(find.byKey(kMuskelFigurSeite(MuskelSeite.vorne)), findsNothing);
    });

    testWidgets('`null` zeigt beide Hälften nebeneinander, vorne links', (
      tester,
    ) async {
      await zeigeFigur(
        tester,
        MuskelFigur(gefaerbt: faerbe(push), semantik: 'beide Seiten'),
      );

      final vorne = find.byKey(kMuskelFigurSeite(MuskelSeite.vorne));
      final hinten = find.byKey(kMuskelFigurSeite(MuskelSeite.hinten));
      expect(vorne, findsOneWidget);
      expect(hinten, findsOneWidget);
      expect(
        tester.getTopLeft(vorne).dx,
        lessThan(tester.getTopLeft(hinten).dx),
        reason: 'wie `muscleFigure` im Board: VORNE links, HINTEN rechts',
      );
      expect(
        tester.getSize(vorne),
        tester.getSize(hinten),
        reason: 'beide Hälften sind gleich groß',
      );
    });

    testWidgets('bei `seite: null` tragen beide Hälften dieselbe Menge', (
      tester,
    ) async {
      await zeigeFigur(
        tester,
        MuskelFigur(gefaerbt: faerbe(pull), semantik: 'beide Seiten'),
      );

      expect(
        painterVon(tester, MuskelSeite.vorne).gefaerbt,
        faerbe(pull),
        reason:
            'die Aufteilung auf die Seite rechnet der Painter, nicht der '
            'Aufrufer',
      );
      expect(painterVon(tester, MuskelSeite.hinten).gefaerbt, faerbe(pull));
    });
  });

  group('Die gefärbte Menge kommt beim Painter an', () {
    testWidgets('Menge und Seite stehen als Eigenschaften am Painter', (
      tester,
    ) async {
      final menge = {Muscle.chest: rot, Muscle.triceps: blau};
      await zeigeFigur(
        tester,
        MuskelFigur(
          gefaerbt: menge,
          seite: MuskelSeite.vorne,
          semantik: 'Vorderseite',
        ),
      );

      final painter = painterVon(tester, MuskelSeite.vorne);
      expect(painter.gefaerbt, menge);
      expect(painter.seite, MuskelSeite.vorne);
    });

    testWidgets('Push: vorne drei Muskeln mit je einem Pfad, hinten zwei', (
      tester,
    ) async {
      // Aus Katalog und Pfaddatei hergeleitet: Push trifft Brust, vordere
      // Schulter, seitliche Schulter, Trizeps. Vorne liegen die ersten drei
      // (je ein Pfad), hinten seitliche Schulter und Trizeps (je ein Pfad).
      expect(push, {
        Muscle.chest,
        Muscle.frontDelt,
        Muscle.sideDelt,
        Muscle.triceps,
      }, reason: 'Vorbedingung: die Menge des Katalogs');
      await zeigeFigur(
        tester,
        MuskelFigur(gefaerbt: faerbe(push), semantik: 'beide Seiten'),
      );

      final vorne = painterVon(tester, MuskelSeite.vorne);
      expect(vorne.gefaerbteMuskeln, {
        Muscle.chest,
        Muscle.frontDelt,
        Muscle.sideDelt,
      });
      expect(vorne.gefaerbtePfade, 3);

      final hinten = painterVon(tester, MuskelSeite.hinten);
      expect(hinten.gefaerbteMuskeln, {Muscle.sideDelt, Muscle.triceps});
      expect(hinten.gefaerbtePfade, 2);
    });

    testWidgets('Pull: ein Rücken-Training färbt vorne wenig, hinten viel', (
      tester,
    ) async {
      expect(pull, {
        Muscle.biceps,
        Muscle.forearms,
        Muscle.glutes,
        Muscle.hamstrings,
        Muscle.lats,
        Muscle.lowerBack,
        Muscle.rearDelt,
        Muscle.upperBack,
      }, reason: 'Vorbedingung: die Menge des Katalogs');
      await zeigeFigur(
        tester,
        MuskelFigur(gefaerbt: faerbe(pull), semantik: 'beide Seiten'),
      );

      final vorne = painterVon(tester, MuskelSeite.vorne);
      expect(vorne.gefaerbteMuskeln, {
        Muscle.biceps,
        Muscle.forearms,
        Muscle.upperBack,
      });
      // Unterarme haben vorne zwei Pfade, Bizeps und oberer Rücken je einen.
      expect(vorne.gefaerbtePfade, 4);

      final hinten = painterVon(tester, MuskelSeite.hinten);
      expect(hinten.gefaerbteMuskeln, {
        Muscle.forearms,
        Muscle.glutes,
        Muscle.hamstrings,
        Muscle.lats,
        Muscle.lowerBack,
        Muscle.rearDelt,
        Muscle.upperBack,
      });
      // Unterarme 2, Gesäß 1, Oberschenkel hinten 2, Latissimus 1, unterer
      // Rücken 1, hintere Schulter 1, oberer Rücken 2.
      expect(hinten.gefaerbtePfade, 10);
    });

    testWidgets('Legs: Muskeln mit mehreren Pfaden färben alle ihre Pfade', (
      tester,
    ) async {
      expect(legs, {
        Muscle.calves,
        Muscle.glutes,
        Muscle.hamstrings,
        Muscle.lowerBack,
        Muscle.quads,
      }, reason: 'Vorbedingung: die Menge des Katalogs');
      await zeigeFigur(
        tester,
        MuskelFigur(gefaerbt: faerbe(legs), semantik: 'beide Seiten'),
      );

      final vorne = painterVon(tester, MuskelSeite.vorne);
      expect(vorne.gefaerbteMuskeln, {Muscle.calves, Muscle.quads});
      // Waden ein Pfad, Oberschenkel vorne **drei**.
      expect(vorne.gefaerbtePfade, 4);

      final hinten = painterVon(tester, MuskelSeite.hinten);
      expect(hinten.gefaerbteMuskeln, {
        Muscle.calves,
        Muscle.glutes,
        Muscle.hamstrings,
        Muscle.lowerBack,
      });
      // Waden 1, Gesäß 1, Oberschenkel hinten **zwei**, unterer Rücken 1.
      expect(hinten.gefaerbtePfade, 5);
    });

    testWidgets(
      'der Rumpf färbt alle seine Pfade — vorne fünf, hinten keinen',
      (tester) async {
        await zeigeFigur(
          tester,
          MuskelFigur(gefaerbt: {Muscle.core: rot}, semantik: 'beide Seiten'),
        );

        expect(painterVon(tester, MuskelSeite.vorne).gefaerbtePfade, 5);
        expect(
          painterVon(tester, MuskelSeite.hinten).gefaerbteMuskeln,
          isEmpty,
          reason:
              'ein Muskel, der auf der gezeigten Seite nicht liegt, '
              'erscheint dort nicht',
        );
        expect(painterVon(tester, MuskelSeite.hinten).gefaerbtePfade, 0);
      },
    );

    testWidgets('Haut bleibt Haut: auch alle Muskeln färben nur Muskelpfade', (
      tester,
    ) async {
      await zeigeFigur(
        tester,
        MuskelFigur(gefaerbt: alleMuskeln(), semantik: 'beide Seiten'),
      );

      // Aus der Datei: vorne 17, hinten 13 Muskelpfade (eine Körperhälfte);
      // vorne gibt es zusätzlich einen Hautpfad ohne Zuordnung.
      expect(painterVon(tester, MuskelSeite.vorne).gefaerbtePfade, 17);
      expect(painterVon(tester, MuskelSeite.hinten).gefaerbtePfade, 13);
      expect(hautPfade(MuskelSeite.vorne), 1, reason: 'Vorbedingung');
    });

    test('die erwarteten Pfade stimmen mit dem Painter überein', () {
      for (final seite in MuskelSeite.values) {
        expect(
          MuskelFigurPainter.pfadeJeMuskel(seite),
          erwartetePfade(seite),
          reason: '$seite: Der Painter liest dieselbe Datei wie der Test',
        );
      }
    });

    testWidgets('ein Muskel außerhalb der Menge färbt nichts', (tester) async {
      await zeigeFigur(
        tester,
        MuskelFigur(gefaerbt: {Muscle.chest: rot}, semantik: 'beide Seiten'),
      );

      expect(painterVon(tester, MuskelSeite.vorne).gefaerbteMuskeln, {
        Muscle.chest,
      });
      expect(painterVon(tester, MuskelSeite.hinten).gefaerbteMuskeln, isEmpty);
    });
  });

  group('Die leere Menge', () {
    testWidgets('baut ohne Fehler und färbt nichts — für jede Seite', (
      tester,
    ) async {
      for (final seite in [null, ...MuskelSeite.values]) {
        await zeigeFigur(
          tester,
          MuskelFigur(
            gefaerbt: const {},
            seite: seite,
            semantik: 'trifft keine Muskeln',
          ),
        );

        expect(find.byType(ErrorWidget), findsNothing, reason: '$seite');
        expect(tester.takeException(), isNull, reason: '$seite');
        for (final gezeigt in seite == null ? MuskelSeite.values : [seite]) {
          expect(
            painterVon(tester, gezeigt).gefaerbteMuskeln,
            isEmpty,
            reason: '$seite/$gezeigt',
          );
          expect(painterVon(tester, gezeigt).gefaerbtePfade, 0);
        }
      }
    });

    testWidgets('behält ihre Größe — die Figur verschwindet nicht', (
      tester,
    ) async {
      await zeigeFigur(
        tester,
        MuskelFigur(
          gefaerbt: faerbe(push),
          seite: MuskelSeite.vorne,
          semantik: 'Vorderseite',
        ),
      );
      final mitMenge = tester.getSize(find.byType(MuskelFigur));

      await zeigeFigur(
        tester,
        const MuskelFigur(
          gefaerbt: {},
          seite: MuskelSeite.vorne,
          semantik: 'keine Muskeln',
        ),
      );

      expect(
        tester.getSize(find.byType(MuskelFigur)),
        mitMenge,
        reason:
            '„Eine Anzeige, die es gibt, hat genau eine Form" — ohne '
            'Muskeln steht sie ungefüllt da (`CLAUDE.md`)',
      );
    });
  });

  group('Der Painter ist wertgleich (Spec 13, Fehler `03`)', () {
    MuskelFigurPainter bau({
      Map<Muscle, Color>? gefaerbt,
      MuskelSeite seite = MuskelSeite.vorne,
    }) => MuskelFigurPainter(
      gefaerbt: gefaerbt ?? {Muscle.chest: rot, Muscle.triceps: blau},
      seite: seite,
    );

    test(
      'gleicher Inhalt in neuen Objekten ist gleich und zeichnet nicht neu',
      () {
        final a = bau();
        final b = bau();

        expect(a, b);
        expect(a.hashCode, b.hashCode);
        expect(a.shouldRepaint(b), isFalse);
      },
    );

    test('eine andere Seite zeichnet neu', () {
      expect(bau().shouldRepaint(bau(seite: MuskelSeite.hinten)), isTrue);
      expect(bau(), isNot(bau(seite: MuskelSeite.hinten)));
    });

    test('eine andere Menge zeichnet neu', () {
      final anders = bau(gefaerbt: {Muscle.chest: rot});

      expect(bau().shouldRepaint(anders), isTrue);
      expect(bau(), isNot(anders));
    });

    test('eine andere Farbe desselben Muskels zeichnet neu', () {
      final anders = bau(gefaerbt: {Muscle.chest: blau, Muscle.triceps: blau});

      expect(
        bau().shouldRepaint(anders),
        isTrue,
        reason: 'Wer die Farbe wechselt, will das neue Bild sehen',
      );
    });

    test('die Reihenfolge, in der die Map gebaut wurde, zählt nicht', () {
      final a = bau(gefaerbt: {Muscle.chest: rot, Muscle.triceps: blau});
      final b = bau(gefaerbt: {Muscle.triceps: blau, Muscle.chest: rot});

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.shouldRepaint(b), isFalse);
    });

    testWidgets('ein Neuaufbau mit gleicher Menge übergibt einen gleichen '
        'Painter', (tester) async {
      Widget figur() => MuskelFigur(
        gefaerbt: {Muscle.chest: rot, Muscle.triceps: blau},
        seite: MuskelSeite.vorne,
        semantik: 'Vorderseite',
      );

      await zeigeFigur(tester, figur());
      final vorher = painterVon(tester, MuskelSeite.vorne);
      await zeigeFigur(tester, figur());
      final nachher = painterVon(tester, MuskelSeite.vorne);

      expect(nachher, vorher);
      expect(nachher.shouldRepaint(vorher), isFalse);
    });
  });

  group(
    'Der Vorlesetext ist ein Knoten (`CLAUDE.md`: Zustand, nicht Zeichen)',
    () {
      testSemantik('der Text des Aufrufers steht genau einmal da', (
        tester,
      ) async {
        const text = 'Vorderseite, trifft Brust und vordere Schulter';

        await zeigeFigur(
          tester,
          MuskelFigur(
            gefaerbt: faerbe(push),
            seite: MuskelSeite.vorne,
            semantik: text,
          ),
        );

        expect(
          find.bySemanticsLabel(RegExp('^${RegExp.escape(text)}\$')),
          findsOneWidget,
        );
      });

      testSemantik('die Beschriftungen „VORNE" und „HINTEN" lesen sich nicht '
          'einzeln vor', (tester) async {
        await zeigeFigur(
          tester,
          MuskelFigur(gefaerbt: faerbe(push), semantik: 'beide Seiten'),
        );

        expect(
          find.bySemanticsLabel(RegExp('^(VORNE|HINTEN)\$')),
          findsNothing,
          reason:
              'ein Knoten mit dem Text des Aufrufers, Kinder ausgeschlossen',
        );
        expect(find.bySemanticsLabel('beide Seiten'), findsOneWidget);
      });

      testSemantik('die leere Menge liest sich so, wie der Aufrufer es sagt', (
        tester,
      ) async {
        const text = 'Vorderseite, trifft keine Muskeln';

        await zeigeFigur(
          tester,
          const MuskelFigur(
            gefaerbt: {},
            seite: MuskelSeite.vorne,
            semantik: text,
          ),
        );

        expect(find.bySemanticsLabel(text), findsOneWidget);
      });
    },
  );
}
