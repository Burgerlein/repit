import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/gym/gym_log_view.dart';

import 'log_support.dart';

/// Der **Zwischenstand** des Schirms „Training eintragen" (#78): wann er
/// geschrieben wird, was passiert, wenn es scheitert, und das Verwerfen.
///
/// Grundlage ist
/// `docs/superpowers/specs/2026-11-10-gym-training-eintragen-design.md`,
/// Abschnitte 3.6, 9.1 und 17.3. Hülle und API stehen in `log_support.dart`.
///
/// Geschrieben aus der Spec, **ohne** den späteren Schirm gesehen zu haben.
///
/// ## Warum gegen die Ablage und nicht gegen den Haken
///
/// Spec 17.3: „Prüfbar über die Ablage, nicht über den Haken." Gezählt
/// werden die Aufrufe von `GymRepository.speichereEntwurf`
/// ([Ablage.entwurfSchreibungen]); was in der Ablage steht, wird über eine
/// zweite, ungehinderte `GymRepository` gelesen.
///
/// ## Die Zeit
///
/// Ein Widget-Test hat eine eigene Uhr: `tester.pump(Duration)` spult sie
/// vor, ohne dass etwas wartet. Eingetippt wird **ohne** dass Zeit vergeht
/// (`tippe` pumpt `Duration.zero`), damit „1,4 s" und „1,6 s" genau das
/// heißen.
///
/// ## Was hier das Wichtigste ist
///
/// „**Scheitert das Ablegen, bleibt der Entwurf stehen**, und der Nutzer
/// erfährt es." Die alte App schluckt den Fehler und löscht den Entwurf
/// trotzdem (`GymLogDraft.swift:288–290`) — das wird nicht portiert, und es
/// geht um Tims einzige Kopie (Spec 18, Frage 11, Tim, 10.11.2026).
void main() {
  group('Wann der Zwischenstand geschrieben wird (Spec 9.1)', () {
    logTest('nach 1,5 Sekunden ohne weitere Eingabe — nicht früher', (
      tester,
      h,
    ) async {
      await zeigeLog(tester, h);

      await satz(tester, idBank, 1, gewicht: '60', wdh: '10');

      await tester.pump(const Duration(milliseconds: 1400));
      expect(
        h.ablage.entwurfSchreibungen,
        0,
        reason: 'Nach 1,4 s ist noch nichts geschrieben',
      );
      expect(await h.entwurf(), isNull);

      await tester.pump(const Duration(milliseconds: 200));
      expect(
        h.ablage.entwurfSchreibungen,
        1,
        reason: 'Nach 1,6 s genau ein Schreibvorgang',
      );
      final gespeichert = await h.entwurf();
      expect(gespeichert, isNotNull);
      expect(gespeichert!.workout, Workout.a);
    });

    logTest('nicht bei jedem Zeichen: Zwei Eingaben im Abstand von 0,5 s '
        'ergeben einen Schreibvorgang', (tester, h) async {
      await zeigeLog(tester, h);

      await satz(tester, idBank, 1, gewicht: '60', wdh: '10');
      await tester.pump(const Duration(milliseconds: 500));
      await satz(tester, idBank, 2, gewicht: '62,5', wdh: '9');

      // 1,4 s nach der **letzten** Eingabe: Die Wartezeit hat bei der
      // zweiten von vorn begonnen.
      await tester.pump(const Duration(milliseconds: 1400));
      expect(
        h.ablage.entwurfSchreibungen,
        0,
        reason: 'Jede Änderung startet die Wartezeit neu (Spec 9.1 Punkt 1)',
      );

      await tester.pump(const Duration(milliseconds: 200));
      expect(h.ablage.entwurfSchreibungen, 1);

      // Und beide Eingaben stehen darin: nach einem Neustart sind sie da.
      await neustart(tester, h);
      await oeffne(tester);
      expect(feldText(tester, kFeldWdh(idBank, 1)), '10');
      expect(feldText(tester, kFeldGewicht(idBank, 2)), '62,5');
      expect(feldText(tester, kFeldWdh(idBank, 2)), '9');
    });

    logTest('der Haken „Zwischengespeichert" steht erst, wenn geschrieben '
        'wurde', (tester, h) async {
      await zeigeLog(tester, h);
      expect(find.byKey(kGespeichert), findsNothing);

      await satz(tester, idBank, 1, gewicht: '60', wdh: '10');
      expect(
        find.byKey(kGespeichert),
        findsNothing,
        reason:
            'Ein Haken vor dem Schreiben wäre eine Zusage, die nicht '
            'stimmt (`CLAUDE.md`)',
      );

      await tester.pump(const Duration(milliseconds: 1600));
      expect(find.byKey(kGespeichert), findsOneWidget);
    });

    logTest('„Zwischenspeichern" schreibt sofort', (tester, h) async {
      await zeigeLog(tester, h);
      await satz(tester, idBank, 1, gewicht: '60', wdh: '10');

      await tester.tap(find.byKey(kZwischenspeichern));
      await tester.pump();

      expect(
        await h.entwurf(),
        isNotNull,
        reason: 'Es ist keine Zeit vergangen: das war der Knopf',
      );
      expect(find.byKey(kGespeichert), findsOneWidget);
    });

    logTest('beim Verlassen des Schirms wird sofort geschrieben', (
      tester,
      h,
    ) async {
      await zeigeLog(tester, h);
      await satz(tester, idBank, 1, gewicht: '60', wdh: '10');

      await verlasse(tester);

      expect(
        await h.entwurf(),
        isNotNull,
        reason:
            'Spec 9.1 Punkt 5 — seit der Eingabe sind 0,7 s vergangen, '
            'die 1,5 s hat der Schirm nicht abgewartet',
      );
    });

    logTest('ein leerer Entwurf wird nicht geschrieben', (tester, h) async {
      await zeigeLog(tester, h);

      await tester.pump(const Duration(seconds: 3));

      expect(h.ablage.entwurfSchreibungen, 0);
      expect(
        await h.entwurf(),
        isNull,
        reason:
            'Sonst sähe die Gym-Übersicht ein angefangenes Training, '
            'wo keines ist (Spec 9.1 Punkt 4)',
      );
    });

    logTest('ein leer gewordener Entwurf wird gelöscht, nicht überschrieben', (
      tester,
      h,
    ) async {
      await zeigeLog(tester, h);
      await satz(tester, idBank, 1, gewicht: '60', wdh: '10');
      await tester.tap(find.byKey(kZwischenspeichern));
      await tester.pump();
      expect(await h.entwurf(), isNotNull, reason: 'Vorbedingung');

      await tippe(tester, kFeldGewicht(idBank, 1), '');
      await tippe(tester, kFeldWdh(idBank, 1), '');
      await tester.pump(const Duration(milliseconds: 1600));

      expect(
        await h.entwurf(),
        isNull,
        reason:
            'Wer alles wieder herauslöscht, hat kein Training '
            'angefangen',
      );
    });

    logTest('ein Neustart bringt den Zwischenstand zurück', (tester, h) async {
      await zeigeLog(tester, h);
      await satz(tester, idBank, 1, gewicht: '60', wdh: '10');
      await tester.pump(const Duration(milliseconds: 1600));

      await neustart(tester, h);
      await oeffne(tester);

      expect(feldText(tester, kFeldGewicht(idBank, 1)), '60');
      expect(feldText(tester, kFeldWdh(idBank, 1)), '10');
      expect(
        find.byKey(kHaken(idBank, 1)),
        findsOneWidget,
        reason: 'Der Satz zählt auch nach dem Neustart',
      );
    });
  });

  group('Scheitert das Schreiben, erfährt es der Nutzer', () {
    logTest('ein gescheiterter Zwischenstand wird gesagt — und die Eingaben '
        'bleiben stehen', (tester, h) async {
      await zeigeLog(tester, h);
      h.ablage.zwischenspeichernScheitert = true;

      await satz(tester, idBank, 1, gewicht: '60', wdh: '10');
      await tester.pump(const Duration(milliseconds: 1600));

      expect(
        find.byKey(kHinweis),
        findsOneWidget,
        reason:
            'Schweigen wäre die Vorlage: Die alte App schluckt den '
            'Fehler (Spec 18, Frage 11)',
      );
      expect(textVon(tester, kHinweis), isNotEmpty);
      expect(
        find.byKey(kGespeichert),
        findsNothing,
        reason: 'Der Haken fehlt zu Recht',
      );
      expect(
        feldText(tester, kFeldWdh(idBank, 1)),
        '10',
        reason: 'Was getippt wurde, steht noch da',
      );

      // Geht es wieder, lässt es sich nachholen.
      h.ablage.zwischenspeichernScheitert = false;
      await tester.tap(find.byKey(kZwischenspeichern));
      await tester.pump();
      expect(await h.entwurf(), isNotNull);
      expect(find.byKey(kGespeichert), findsOneWidget);
    });

    logTest('scheitert das Ablegen, bleibt der Entwurf stehen und der '
        'Schirm sagt es', (tester, h) async {
      await zeigeLog(tester, h);
      await satz(tester, idBank, 1, gewicht: '60', wdh: '10');
      await satz(tester, idBank, 2, gewicht: '62,5', wdh: '9');
      await satz(tester, idSchraeg, 1, gewicht: '22', wdh: '12');
      h.ablage.ablegenScheitert = true;

      // Sofort nach dem letzten Satz, ohne den Zwischenstand abzuwarten —
      // so trainiert man.
      await tester.tap(find.byKey(kAbschliessen));
      await verstreiche(tester);

      expect(
        find.byType(GymLogView),
        findsOneWidget,
        reason:
            'Der Schirm bleibt offen: Wer jetzt zurückgeht, glaubt, '
            'es sei gespeichert',
      );
      expect(find.byKey(kHuelleUebersicht), findsNothing);
      expect(
        find.byKey(kHinweis),
        findsOneWidget,
        reason: 'Der Nutzer erfährt es (Spec 18, Frage 11)',
      );
      expect(textVon(tester, kHinweis), isNotEmpty);
      expect(await h.sitzungen(), isEmpty, reason: 'Nichts wurde abgelegt');

      expect(
        feldText(tester, kFeldGewicht(idBank, 2)),
        '62,5',
        reason: 'Die Eingaben stehen noch auf dem Schirm',
      );
      expect(feldText(tester, kFeldWdh(idSchraeg, 1)), '12');

      // Und auch in der Ablage: Der Entwurf wurde **nicht** gelöscht. Wer
      // jetzt die App beendet, hat sein Training noch.
      await tester.pump(const Duration(seconds: 2));
      final entwurf = await h.entwurf();
      expect(
        entwurf,
        isNotNull,
        reason:
            'Tims einzige Kopie: Die alte App löscht den Entwurf '
            'trotzdem (`GymLogDraft.swift:288–290`) — das wird nicht '
            'portiert',
      );
      expect(entwurf!.workout, Workout.a);

      // Danach geht es: Derselbe Knopf, dieselben Eingaben, eine Sitzung.
      h.ablage.ablegenScheitert = false;
      await tester.tap(find.byKey(kAbschliessen));
      await verstreiche(tester);

      expect(find.byType(GymLogView), findsNothing);
      final sitzungen = await h.sitzungen();
      expect(sitzungen, hasLength(1));
      expect(sitzungen.single.setCount, 3);
      expect(await h.entwurf(), isNull);
    });
  });

  group('Training abbrechen (Spec 3.6)', () {
    logTest('ohne Eintrag fragt es nicht nach', (tester, h) async {
      await zeigeLog(tester, h);

      await tester.tap(find.byKey(kAbbrechen));
      await tester.pump();

      expect(
        find.byKey(kVerwerfenFrage),
        findsNothing,
        reason:
            '„Der Fall ‚aus Versehen gestartet‘ soll nicht nachfragen '
            'müssen"',
      );
      await verstreiche(tester);
      expect(find.byType(GymLogView), findsNothing);
      expect(find.byKey(kHuelleUebersicht), findsOneWidget);
    });

    logTest('mit Eintrag fragt es nach, nennt die Sätze, und „Weiter '
        'trainieren" lässt alles stehen', (tester, h) async {
      await zeigeLog(tester, h);
      await satz(tester, idBank, 1, gewicht: '60', wdh: '10');
      await satz(tester, idBank, 2, gewicht: '62,5', wdh: '9');

      await tester.tap(find.byKey(kAbbrechen));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byKey(kVerwerfenFrage), findsOneWidget);
      expect(
        textVon(tester, kVerwerfenFrage),
        contains('2'),
        reason: 'Die Rückfrage nennt, wie viele Sätze verloren gehen',
      );

      await tester.tap(find.byKey(kVerwerfenWeiter));
      await tester.pump();
      // 400 ms reichten nicht: Ein `showCupertinoDialog` braucht in dieser
      // Flutter-Fassung gemessene 450 ms, bis er aus dem Baum ist. Der
      // Test prüfte damit nur, dass er zu früh hinsah.
      // (10.11.2026, TEST_AENDERN=1 — die Anforderung ist dieselbe.)
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byKey(kVerwerfenFrage), findsNothing);
      expect(find.byType(GymLogView), findsOneWidget);
      expect(feldText(tester, kFeldWdh(idBank, 2)), '9');
    });

    logTest('verwerfen löscht den Zwischenstand, und danach wird nichts mehr '
        'geschrieben', (tester, h) async {
      await zeigeLog(tester, h);
      await satz(tester, idBank, 1, gewicht: '60', wdh: '10');
      await tester.tap(find.byKey(kZwischenspeichern));
      await tester.pump();
      expect(await h.entwurf(), isNotNull, reason: 'Vorbedingung');
      final davor = h.ablage.entwurfSchreibungen;

      // Eine weitere Eingabe: Die Wartezeit läuft **noch**, als verworfen
      // wird. Das ist Swifts `isDiscarded`-Falle (Spec 3.6).
      await satz(tester, idBank, 2, gewicht: '62,5', wdh: '9');
      await tester.tap(find.byKey(kAbbrechen));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byKey(kVerwerfenBestaetigen));
      await verstreiche(tester);

      expect(find.byType(GymLogView), findsNothing);
      expect(await h.entwurf(), isNull);

      await tester.pump(const Duration(seconds: 3));
      expect(
        await h.entwurf(),
        isNull,
        reason:
            'Die noch laufende Wartezeit hat den gerade gelöschten '
            'Entwurf neu angelegt — genau die Falle aus Spec 3.6',
      );
      expect(
        h.ablage.entwurfSchreibungen,
        davor,
        reason: 'Nach dem Verwerfen darf nichts mehr geschrieben werden',
      );
      expect(await h.sitzungen(), isEmpty);
    });

    logTest('nach dem Verwerfen fängt ein neues Training leer an', (
      tester,
      h,
    ) async {
      await zeigeLog(tester, h);
      await satz(tester, idBank, 1, gewicht: '60', wdh: '10');
      await tester.tap(find.byKey(kAbbrechen));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byKey(kVerwerfenBestaetigen));
      await verstreiche(tester);

      await oeffne(tester);

      expect(feldText(tester, kFeldGewicht(idBank, 1)), isEmpty);
      expect(feldText(tester, kFeldWdh(idBank, 1)), isEmpty);
      expect(fortschritt(tester).fertig, 0);
    });
  });
}
