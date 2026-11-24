import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/gym/gym_log_view.dart';

import 'log_support.dart';

/// Das **Vollbild** des Schirms „Training eintragen" (#78): dasselbe
/// Training, eine Übung, größer gesetzt.
///
/// Grundlage ist
/// `docs/superpowers/specs/2026-11-10-gym-training-eintragen-design.md`,
/// Abschnitte 4 und 15. Hülle und API stehen in `log_support.dart`; die
/// beiden Pflichtfälle, die das Vollbild berühren (Werte überstehen Hin und
/// Zurück), stehen in `gym_log_leerzustaende_test.dart`.
///
/// Geschrieben aus der Spec, **ohne** den späteren Schirm gesehen zu haben.
///
/// ## Worauf diese Datei zielt
///
/// **Kein zweiter Navigationsstapel.** `CLAUDE.md` und Spec 4.1: Zwei
/// verschachtelte Stapel schließen die gepushte Seite sofort wieder, und
/// das fällt in keinem anderen Test auf. Geprüft wird es hier im Baum:
/// Das Vollbild liegt auf dem `rootNavigator`, über der Tableiste, und
/// trägt weder einen eigenen `Navigator` noch ein Gerüst mit
/// Navigationsleiste. Die Hülle (`log_support.dart`) hat zwei Reiter mit je
/// eigenem Stapel — ohne sie wäre „über der Tableiste" nicht prüfbar.
///
/// **Das Vollbild schließt sich selbst mit einem Ergebnis**, und die
/// Erfassung darunter schließt das Training ab, nachdem das Vollbild weg
/// ist (Spec 4.4). Es ruft nie selbst `complete()` und poppt nie zwei
/// Routen.
///
/// ## Was hier bewusst **nicht** geprüft wird
///
/// Schriftgröße, Layout, die Seitenzahl-Anzeige, `Hero`-Tags (die Spec
/// verbietet gleiche Tags in zwei Stapeln; ohne `Hero` ist nichts zu
/// prüfen) und die Darstellung unter der halbtransparenten Tastatur
/// (flutter#179482 — von Hand).
void main() {
  /// Die Übungen von Gym A in ihrer Reihenfolge.
  final ids = [for (final uebung in uebungenVon(Workout.a)) uebung.id];

  /// Ist die Übung [id] die, die das Vollbild gerade zeigt? Geprüft über ihr
  /// erstes Wiederholungsfeld **innerhalb** des Vollbilds.
  bool zeigtImVollbild(String id) => find
      .descendant(
        of: find.byKey(kVollbild),
        matching: find.byKey(kFeldWdh(id, 1)),
      )
      .evaluate()
      .isNotEmpty;

  /// Trägt alle Zeilen einer Übung ein — nur Wiederholungen, die genügen.
  Future<void> fuelleUebung(WidgetTester tester, String id) async {
    for (var n = 1; n <= ExerciseCatalog.all[id]!.sets; n++) {
      await satz(tester, id, n, wdh: '${12 - n}');
    }
  }

  group('Kein zweiter Navigationsstapel (Spec 4.1)', () {
    logTest('das Vollbild liegt auf dem Wurzel-Navigator, über der '
        'Tableiste', (tester, h) async {
      await zeigeLog(tester, h);

      await oeffneVollbild(tester);

      expect(find.byKey(kVollbild), findsOneWidget);
      final kontext = tester.element(find.byKey(kVollbild));
      expect(
        Navigator.of(kontext),
        same(Navigator.of(kontext, rootNavigator: true)),
        reason:
            'Spec 4.1: „Geschoben wird über '
            '`Navigator.of(context, rootNavigator: true)`". Der nächste '
            'Navigator über dem Vollbild ist der Wurzel-Navigator, nicht '
            'der des Reiters',
      );
      expect(
        find.byType(CupertinoTabBar),
        findsNothing,
        reason:
            'Die Tableiste liegt unter dem Vollbild: Es hat „weder '
            'Navigations- noch Tableiste, sondern einen eigenen Kopf mit '
            'Kreuz und einen eigenen Fuß" (Entwurf `gym-log.js:12–16`)',
      );
    });

    logTest('im Baum des Vollbilds steht kein Navigator, keine '
        'Navigationsleiste, kein Reiter-Stapel', (tester, h) async {
      await zeigeLog(tester, h);

      await oeffneVollbild(tester);

      for (final (name, typ) in [
        ('Navigator', find.byType(Navigator)),
        ('CupertinoNavigationBar', find.byType(CupertinoNavigationBar)),
        ('CupertinoTabView', find.byType(CupertinoTabView)),
        ('CupertinoTabBar', find.byType(CupertinoTabBar)),
        ('CupertinoPageScaffold', find.byType(CupertinoPageScaffold)),
      ]) {
        expect(
          find.descendant(of: find.byKey(kVollbild), matching: typ),
          findsNothing,
          reason:
              '$name im Vollbild: Zwei verschachtelte Stapel schließen '
              'die Seite sofort wieder, und das fällt sonst nirgends auf',
        );
      }
    });

    logTest('das Vollbild bleibt offen und baut ohne Ausnahme', (
      tester,
      h,
    ) async {
      await zeigeLog(tester, h);

      await oeffneVollbild(tester);
      await tester.pump(const Duration(seconds: 2));

      expect(
        find.byKey(kVollbild),
        findsOneWidget,
        reason: 'Ein zweiter Stapel ließe die Seite sofort wieder zugehen',
      );
      expect(find.byType(ErrorWidget), findsNothing);
      expect(tester.takeException(), isNull);
    });

    logTest('das Kreuz schließt das Vollbild und lässt die Erfassung stehen', (
      tester,
      h,
    ) async {
      await zeigeLog(tester, h);
      // Das Aufwärmen aus dem Weg — seit dem 11.11.2026 öffnet das
      // Vollbild bei einem frischen Training dort. Dieser Fall
      // handelt von den Übungsseiten. (TEST_AENDERN=1)
      await ueberspringeAufwaermen(tester);
      await oeffneVollbild(tester);

      await tester.tap(find.byKey(kVollbildSchliessen));
      await verstreiche(tester);

      expect(find.byKey(kVollbild), findsNothing);
      expect(
        find.byType(GymLogView),
        findsOneWidget,
        reason:
            'Eine Route weniger, nicht zwei: Das Kreuz bringt zurück '
            'zur Erfassung (Spec 15)',
      );
    });

    logTest('das Kreuz speichert den Zwischenstand', (tester, h) async {
      await zeigeLog(tester, h);
      // Das Aufwärmen aus dem Weg — seit dem 11.11.2026 öffnet das
      // Vollbild bei einem frischen Training dort. Dieser Fall
      // handelt von den Übungsseiten. (TEST_AENDERN=1)
      await ueberspringeAufwaermen(tester);
      await oeffneVollbild(tester);

      await satz(tester, idBank, 1, gewicht: '60', wdh: '10');
      await tester.tap(find.byKey(kVollbildSchliessen));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      expect(
        await h.entwurf(),
        isNotNull,
        reason:
            'Spec 4.2: „Das Kreuz speichert den Zwischenstand und '
            'schließt" — seit dem Tippen sind 0,7 s vergangen, die 1,5 s '
            'sind es nicht',
      );
    });
  });

  group('Welche Übung das Vollbild zeigt (Spec 4.3)', () {
    logTest('es öffnet bei der ersten Übung, sobald das Aufwärmen '
        'beantwortet ist', (tester, h) async {
      // Bis zum 11.11.2026 hieß dieser Fall „wenn noch nichts erledigt
      // ist" und öffnete auch bei einem ganz frischen Training bei
      // Übung 1. Seitdem geht das Vollbild dann auf der Aufwärm-Seite
      // auf (Tims Entscheidung). Die Aussage hier ist unverändert: Es
      // öffnet bei der **ersten** Übung und nicht bei der zweiten.
      // (TEST_AENDERN=1)
      await zeigeLog(tester, h);
      await ueberspringeAufwaermen(tester);

      await oeffneVollbild(tester);

      expect(zeigtImVollbild(ids[0]), isTrue);
      expect(zeigtImVollbild(ids[1]), isFalse);
    });

    logTest('es öffnet bei der ersten noch nicht erledigten Übung, nicht bei '
        'der ersten überhaupt', (tester, h) async {
      await zeigeLog(tester, h);
      await fuelleUebung(tester, ids[0]);
      await fuelleUebung(tester, ids[1]);

      await oeffneVollbild(tester);

      expect(
        zeigtImVollbild(ids[2]),
        isTrue,
        reason:
            'Übung 1 und 2 sind erledigt: Das Vollbild öffnet bei '
            'Übung 3',
      );
      expect(zeigtImVollbild(ids[0]), isFalse);
      expect(zeigtImVollbild(ids[1]), isFalse);
    });

    logTest('eine halb gefüllte Übung ist noch nicht erledigt', (
      tester,
      h,
    ) async {
      await zeigeLog(tester, h);
      await satz(tester, ids[0], 1, wdh: '10');

      await oeffneVollbild(tester);

      expect(
        zeigtImVollbild(ids[0]),
        isTrue,
        reason:
            'Ein Satz von vieren ist nicht erledigt — hier geht es '
            'weiter',
      );
    });

    logTest('die Seite wechselt nicht von selbst, wenn eine Übung fertig '
        'wird', (tester, h) async {
      await zeigeLog(tester, h);
      // Das Aufwärmen aus dem Weg — seit dem 11.11.2026 öffnet das
      // Vollbild bei einem frischen Training dort. Dieser Fall
      // handelt von den Übungsseiten. (TEST_AENDERN=1)
      await ueberspringeAufwaermen(tester);
      await oeffneVollbild(tester);

      await fuelleUebung(tester, ids[0]);
      await tester.pump(const Duration(seconds: 2));

      expect(
        zeigtImVollbild(ids[0]),
        isTrue,
        reason:
            'Spec 4.3: „Wer gerade den letzten Satz einträgt, will als '
            'Nächstes vielleicht noch einen vierten anhängen; ein Schirm, '
            'der unter den Händen weiterspringt, nimmt ihm das weg"',
      );
      expect(zeigtImVollbild(ids[1]), isFalse);

      // Und der vierte Satz lässt sich anhängen.
      final davor = ExerciseCatalog.all[ids[0]]!.sets;
      await tester.tap(find.byKey(kSatzHinzu(ids[0])));
      await tester.pump();
      expect(find.byKey(kFeldWdh(ids[0], davor + 1)), findsOneWidget);
    });
  });

  group('Blättern', () {
    logTest('„Nächste Übung" zeigt die nächste, ohne die Eingaben zu '
        'verlieren', (tester, h) async {
      await zeigeLog(tester, h);
      // Das Aufwärmen aus dem Weg — seit dem 11.11.2026 öffnet das
      // Vollbild bei einem frischen Training dort. Dieser Fall
      // handelt von den Übungsseiten. (TEST_AENDERN=1)
      await ueberspringeAufwaermen(tester);
      await oeffneVollbild(tester);
      await satz(tester, ids[0], 1, gewicht: '60', wdh: '10');

      await tester.tap(find.byKey(kVollbildWeiter));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(zeigtImVollbild(ids[1]), isTrue);
      expect(zeigtImVollbild(ids[0]), isFalse);

      await tester.tap(find.byKey(kVollbildSchliessen));
      await verstreiche(tester);
      expect(
        feldText(tester, kFeldWdh(ids[0], 1)),
        '10',
        reason: 'Beim Blättern geht nichts verloren',
      );
    });

    logTest('Wischen geht auch', (tester, h) async {
      await zeigeLog(tester, h);
      // Das Aufwärmen aus dem Weg — seit dem 11.11.2026 öffnet das
      // Vollbild bei einem frischen Training dort. Dieser Fall
      // handelt von den Übungsseiten. (TEST_AENDERN=1)
      await ueberspringeAufwaermen(tester);
      await oeffneVollbild(tester);
      expect(zeigtImVollbild(ids[0]), isTrue, reason: 'Vorbedingung');

      await tester.fling(find.byKey(kVollbild), const Offset(-400, 0), 1500);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(
        zeigtImVollbild(ids[1]),
        isTrue,
        reason: 'Spec 4.3: „Waagerecht wischbar, eine Seite je Übung"',
      );
    });

    logTest('auf der letzten Übung heißt der Knopf „Training abschließen"', (
      tester,
      h,
    ) async {
      await zeigeLog(tester, h);
      // Das Aufwärmen aus dem Weg — seit dem 11.11.2026 öffnet das
      // Vollbild bei einem frischen Training dort. Dieser Fall
      // handelt von den Übungsseiten. (TEST_AENDERN=1)
      await ueberspringeAufwaermen(tester);
      await oeffneVollbild(tester);

      for (var i = 0; i < ids.length - 1; i++) {
        expect(
          find.byKey(kVollbildWeiter),
          findsOneWidget,
          reason: 'Übung ${i + 1}: noch nicht die letzte',
        );
        expect(find.byKey(kVollbildAbschliessen), findsNothing);
        await tester.tap(find.byKey(kVollbildWeiter));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
      }

      expect(zeigtImVollbild(ids.last), isTrue);
      expect(
        find.byKey(kVollbildAbschliessen),
        findsOneWidget,
        reason:
            'Spec 4.2: „Auf der letzten Übung heißt der Knopf ‚Training '
            'abschließen‘"',
      );
      expect(find.byKey(kVollbildWeiter), findsNothing);
    });
  });

  group('Abschließen aus dem Vollbild (Spec 4.4)', () {
    /// Geht im Vollbild bis zur letzten Übung.
    Future<void> geheZurLetzten(WidgetTester tester) async {
      for (var i = 0; i < ids.length - 1; i++) {
        await tester.tap(find.byKey(kVollbildWeiter));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
      }
    }

    logTest('schließt zuerst das Vollbild und dann das Training ab — der '
        'Schirm darunter ist danach weg, in der Ablage steht genau eine '
        'Sitzung', (tester, h) async {
      await zeigeLog(tester, h);
      await satz(tester, idBank, 1, gewicht: '60', wdh: '10');
      await oeffneVollbild(tester);
      await geheZurLetzten(tester);

      await tester.tap(find.byKey(kVollbildAbschliessen));
      await verstreiche(tester);
      await tester.pump(const Duration(seconds: 1));

      expect(find.byKey(kVollbild), findsNothing);
      expect(
        find.byType(GymLogView),
        findsNothing,
        reason:
            'Spec 15: „zurück dorthin, woher man kam" — beide Schirme '
            'sind zu',
      );
      expect(find.byKey(kHuelleUebersicht), findsOneWidget);
      expect(
        tester.takeException(),
        isNull,
        reason:
            'Zwei Schirme gleichzeitig zu schließen geht schief '
            '(Spec 4.4)',
      );

      final sitzungen = await h.sitzungen();
      expect(sitzungen, hasLength(1));
      expect(sitzungen.single.setCount, 1);
      expect(await h.entwurf(), isNull);
    });

    logTest('scheitert das Ablegen, schließt das Vollbild und die Erfassung '
        'sagt es', (tester, h) async {
      await zeigeLog(tester, h);
      await satz(tester, idBank, 1, gewicht: '60', wdh: '10');
      await oeffneVollbild(tester);
      await geheZurLetzten(tester);
      h.ablage.ablegenScheitert = true;

      await tester.tap(find.byKey(kVollbildAbschliessen));
      await verstreiche(tester);

      expect(find.byKey(kVollbild), findsNothing);
      expect(
        find.byType(GymLogView),
        findsOneWidget,
        reason:
            'Die Erfassung bleibt stehen: Wer jetzt zurückgeht, glaubt, '
            'es sei gespeichert',
      );
      expect(
        find.byKey(kHinweis),
        findsOneWidget,
        reason: 'Der Nutzer erfährt es (Spec 18, Frage 11)',
      );
      expect(await h.sitzungen(), isEmpty);
      expect(feldText(tester, kFeldWdh(idBank, 1)), '10');

      // Der Zwischenstand bleibt in der Ablage stehen.
      await tester.pump(const Duration(seconds: 2));
      expect(
        await h.entwurf(),
        isNotNull,
        reason: 'Tims einzige Kopie bleibt stehen',
      );

      // Danach geht es aus der Erfassung.
      h.ablage.ablegenScheitert = false;
      await tester.tap(find.byKey(kAbschliessen));
      await verstreiche(tester);
      expect(await h.sitzungen(), hasLength(1));
      expect(find.byType(GymLogView), findsNothing);
    });
  });
}
