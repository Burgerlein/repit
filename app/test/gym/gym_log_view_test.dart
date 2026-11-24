import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/gym/gym_log_view.dart';

import 'log_support.dart';

/// Widget-Tests für den Schirm **„Training eintragen"** (#78),
/// `lib/gym/gym_log_view.dart` — **der Weg, den Tim nächste Woche geht**:
/// Sätze eintippen, sehen, dass sie zählen, Training abschließen, und die
/// Sitzung liegt in der Ablage.
///
/// Grundlage ist
/// `docs/superpowers/specs/2026-11-10-gym-training-eintragen-design.md`,
/// Abschnitte 3, 8 und 17.3. Der Zwischenstand, das Verwerfen und das
/// Scheitern liegen in `gym_log_zwischenstand_test.dart`, das Aufwärmen in
/// `gym_log_aufwaermen_test.dart`, die Leerzustände und die beiden
/// Pflichtfälle in `gym_log_leerzustaende_test.dart`, das Vollbild in
/// `gym_log_vollbild_test.dart`, die Pausenuhr in `gym_log_pause_test.dart`.
/// Hülle, Schlüssel und die festgelegte API stehen in `log_support.dart`.
///
/// Geschrieben aus der Spec, **ohne** den späteren Schirm gesehen zu haben.
///
/// ## Worauf diese Datei zielt
///
/// `CLAUDE.md`, „Tests": **Zustände und Übergänge, nicht Layout und
/// Beschriftung.** Wo Texte verglichen werden, sind es Einheiten („kg U",
/// „Sek.") — die Spec legt sie wörtlich fest —, nie Knopfbeschriftungen.
///
/// Geprüft wird **gegen die Ablage**, nicht gegen den Bildschirm: „Die
/// Sitzung liegt in der Ablage" ist der Satz, auf den es ankommt, denn das
/// iPhone ist Tims einzige Kopie.
///
/// ## Was hier bewusst **nicht** geprüft wird
///
/// Layout, Abstände, Farben, genaue Beschriftungen, Dynamic Type, Golden,
/// die Pausenuhr-Mitteilung (eigener Schritt) und die Medien (#38).
void main() {
  group('Eintragen und abschließen', () {
    logTest('Gewicht und Wiederholungen eintippen, abschließen: die Sitzung '
        'liegt in der Ablage', (tester, h) async {
      await zeigeLog(tester, h);

      // Punkt und Komma werden beide gelesen (Spec 3.5).
      await satz(tester, idBank, 1, gewicht: '60', wdh: '10');
      await satz(tester, idBank, 2, gewicht: '62.5', wdh: '9');
      await satz(tester, idBank, 3, gewicht: '62,5', wdh: '8');
      await satz(tester, idBank, 4, gewicht: '62,5', wdh: '7');
      await satz(tester, idSchraeg, 1, gewicht: '22', wdh: '12');

      await tester.tap(find.byKey(kAbschliessen));
      await verstreiche(tester);

      expect(
        find.byType(GymLogView),
        findsNothing,
        reason:
            'Nach dem Abschließen ist der Schirm zu: „zurück dorthin, '
            'woher man kam" (Spec 15)',
      );
      expect(find.byKey(kHuelleUebersicht), findsOneWidget);

      final sitzungen = await h.sitzungen();
      expect(
        sitzungen,
        hasLength(1),
        reason:
            'Genau eine Sitzung — das ist der Weg, der nächste Woche '
            'tragen muss',
      );
      final sitzung = sitzungen.single;
      expect(sitzung.workout, Workout.a);
      expect(
        BerlinCalendar.dayKey(sitzung.date),
        BerlinCalendar.dayKey(startzeit),
        reason: 'Der Tag ist der Berliner Tag des Trainings (Spec 10.4)',
      );
      expect(sitzung.id, isNotEmpty);
      expect(
        sitzung.exercises.map((e) => e.exerciseId).toList(),
        [idBank, idSchraeg],
        reason:
            'Übungen ohne Satz fehlen; die Reihenfolge ist die des '
            'Katalogs',
      );
      expect(
        [for (final s in sitzung.exercises[0].sets) (s.weight, s.reps)],
        [(60.0, 10), (62.5, 9), (62.5, 8), (62.5, 7)],
        reason: '„62.5" mit Punkt und „62,5" mit Komma sind dasselbe Gewicht',
      );
      expect(
        [for (final s in sitzung.exercises[1].sets) (s.weight, s.reps)],
        [(22.0, 12)],
      );
      expect(
        await h.entwurf(),
        isNull,
        reason:
            'Was abgelegt ist, ist kein Zwischenstand mehr — sonst '
            'zeigte die Gym-Übersicht ein laufendes Training, das keines '
            'ist',
      );
    });

    logTest('nach dem Abschließen kommt kein zweites Mal dasselbe Training '
        'zurück', (tester, h) async {
      await zeigeLog(tester, h);
      await satz(tester, idBank, 1, gewicht: '60', wdh: '10');
      await tester.tap(find.byKey(kAbschliessen));
      await verstreiche(tester);

      await oeffne(tester);

      expect(
        feldText(tester, kFeldWdh(idBank, 1)),
        isEmpty,
        reason:
            'Ein neues Training fängt leer an; der Entwurf des '
            'abgeschlossenen ist weg',
      );
      expect(await h.sitzungen(), hasLength(1));
    });

    logTest('Dauer ist mit der Dauer des Workouts vorbelegt, und eine fehlende '
        'Notiz ist null', (tester, h) async {
      await zeigeLog(tester, h);
      await satz(tester, idBank, 1, gewicht: '60', wdh: '10');

      await tester.tap(find.byKey(kEckdaten));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        feldText(tester, kEckdatenDauer),
        '${Workout.a.minutes}',
        reason: 'Spec 3.3: „vorbelegt mit workout.minutes"',
      );

      await tester.tap(find.byKey(kAbschliessen));
      await verstreiche(tester);

      final sitzung = (await h.sitzungen()).single;
      expect(sitzung.minutes, Workout.a.minutes);
      expect(
        sitzung.note,
        isNull,
        reason: 'Keine Notiz ist `null`, nie die leere Zeichenkette',
      );
    });

    logTest('geänderte Dauer und Notiz landen in der Sitzung', (
      tester,
      h,
    ) async {
      await zeigeLog(tester, h);
      await satz(tester, idBank, 1, gewicht: '60', wdh: '10');

      await tester.tap(find.byKey(kEckdaten));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tippe(tester, kEckdatenDauer, '55');
      await tippe(tester, kEckdatenNotiz, 'Schulter zwickt');

      await tester.tap(find.byKey(kAbschliessen));
      await verstreiche(tester);

      final sitzung = (await h.sitzungen()).single;
      expect(sitzung.minutes, 55);
      expect(sitzung.note, 'Schulter zwickt');
    });

    logTest('jeder Satz trägt den Zeitpunkt, an dem er vollständig wurde — '
        'eine Korrektur verschiebt ihn nicht', (tester, h) async {
      await zeigeLog(tester, h);

      await tippe(tester, kFeldGewicht(idBank, 1), '60');
      h.uhr.jetzt = startzeit.add(const Duration(seconds: 10));
      await tippe(tester, kFeldWdh(idBank, 1), '10');

      // Eine Korrektur am Ende des Trainings: Satz 1 wurde nicht am Ende
      // gemacht (Spec 11.4).
      h.uhr.jetzt = startzeit.add(const Duration(minutes: 20));
      await tippe(tester, kFeldGewicht(idBank, 1), '62');

      // Satz 2 ist später fertig.
      h.uhr.jetzt = startzeit.add(const Duration(minutes: 25));
      await satz(tester, idBank, 2, gewicht: '62', wdh: '9');

      await tester.tap(find.byKey(kAbschliessen));
      await verstreiche(tester);

      final saetze = (await h.sitzungen()).single.exercises.single.sets;
      expect(saetze[0].weight, 62.0);
      expect(
        saetze[0].recordedAt,
        startzeit.add(const Duration(seconds: 10)),
        reason:
            '„Eine spätere Korrektur verschiebt ihn nicht" — sonst '
            'rutschten alle korrigierten Sätze ans Ende, und das '
            'Übungsband zeigte ein Training, das so nie stattfand',
      );
      expect(saetze[1].recordedAt, startzeit.add(const Duration(minutes: 25)));
    });

    logTest('wird ein Satz geleert und neu gefüllt, ist er ein neuer Satz mit '
        'neuem Zeitpunkt', (tester, h) async {
      await zeigeLog(tester, h);
      await satz(tester, idBank, 1, gewicht: '60', wdh: '10');

      h.uhr.jetzt = startzeit.add(const Duration(minutes: 30));
      await tippe(tester, kFeldWdh(idBank, 1), '');
      h.uhr.jetzt = startzeit.add(const Duration(minutes: 40));
      await tippe(tester, kFeldWdh(idBank, 1), '9');

      await tester.tap(find.byKey(kAbschliessen));
      await verstreiche(tester);

      final satz1 = (await h.sitzungen()).single.exercises.single.sets.single;
      expect(satz1.reps, 9);
      expect(satz1.recordedAt, startzeit.add(const Duration(minutes: 40)));
    });
  });

  group('Was ein Satz ist', () {
    logTest('ein Satz gilt als erledigt, sobald Wiederholungen dastehen — '
        'Gewicht ist nicht nötig', (tester, h) async {
      await zeigeLog(tester, h);

      expect(find.byKey(kMinus(idDips, 1)), findsOneWidget);
      expect(find.byKey(kHaken(idDips, 1)), findsNothing);

      await tippe(tester, kFeldWdh(idDips, 1), '8');

      expect(
        find.byKey(kHaken(idDips, 1)),
        findsOneWidget,
        reason:
            'Ein Dip am eigenen Körpergewicht hat kein Gewicht und '
            'bekommt trotzdem seinen Haken (Spec 8.3, Tim, 10.11.2026)',
      );
      expect(
        find.byKey(kMinus(idDips, 1)),
        findsNothing,
        reason: 'Haken und Minus teilen sich einen Platz',
      );

      await tippe(tester, kFeldWdh(idDips, 1), '');

      expect(find.byKey(kHaken(idDips, 1)), findsNothing);
      expect(
        find.byKey(kMinus(idDips, 1)),
        findsOneWidget,
        reason: 'Wird das Feld geleert, kehrt sich beides um (Spec 17.3)',
      );
    });

    logTest('ein Gewicht allein macht keinen Satz', (tester, h) async {
      await zeigeLog(tester, h);

      await tippe(tester, kFeldGewicht(idBank, 1), '60');

      expect(
        find.byKey(kHaken(idBank, 1)),
        findsNothing,
        reason:
            'Der Haken folgt der Ablageregel: ohne lesbare, positive '
            'Wiederholungszahl wird nichts abgelegt',
      );
      expect(fortschritt(tester).fertig, 0);
    });

    logTest('eine Körpergewichtsübung wird ohne Gewicht abgelegt, mit '
        'Gewicht 0', (tester, h) async {
      await zeigeLog(tester, h);

      await tippe(tester, kFeldWdh(idDips, 1), '8');
      expect(
        fortschritt(tester).fertig,
        1,
        reason: 'Der Satz zählt auch in der Anzeige',
      );

      await tester.tap(find.byKey(kAbschliessen));
      await verstreiche(tester);

      final dips = (await h.sitzungen()).single.exercises.single;
      expect(dips.exerciseId, idDips);
      expect(dips.sets, hasLength(1));
      expect(dips.sets.single.reps, 8);
      expect(
        dips.sets.single.weight.abs(),
        0,
        reason:
            'Ein leeres Gewichtsfeld heißt null Kilo — und das Feld '
            'wird nicht mit 0 vorbelegt (Spec 8.3)',
      );
    });

    logTest('der Fortschritt zählt Sätze, nicht Übungen', (tester, h) async {
      await zeigeLog(tester, h);

      expect(
        fortschritt(tester),
        (fertig: 0, gesamt: saetzeVon(Workout.a)),
        reason:
            'Gezählt werden Satzzeilen (Tim, 10.11.2026, #26), nicht die '
            '${uebungenVon(Workout.a).length} Übungen',
      );

      await satz(tester, idBank, 1, wdh: '10');
      await satz(tester, idBank, 2, wdh: '9');
      expect(
        fortschritt(tester).fertig,
        2,
        reason: 'Zwei Sätze einer unfertigen Übung sind zwei, nicht null',
      );

      await satz(tester, idBank, 3, wdh: '8');
      await satz(tester, idBank, 4, wdh: '7');
      expect(
        fortschritt(tester).fertig,
        4,
        reason: 'Eine ganze Übung sind vier Sätze, nicht ein Schritt',
      );

      await satz(tester, idSchraeg, 1, wdh: '12');
      expect(fortschritt(tester).fertig, 5);
      expect(fortschritt(tester).gesamt, saetzeVon(Workout.a));
    });

    logTest('die Bilanz und die Ablage zählen nach derselben Regel — ein '
        'unlesbarer Satz steht in keiner von beiden', (tester, h) async {
      await zeigeLog(tester, h);

      // Zeile 1: unlesbares Gewicht, lesbare Wiederholungen.
      await satz(tester, idBank, 1, gewicht: '1,2,3', wdh: '10');
      // Zeile 2: gültig.
      await satz(tester, idBank, 2, gewicht: '60', wdh: '10');
      // Zeile 3: Wiederholungen 0 — nicht positiv.
      await satz(tester, idBank, 3, gewicht: '50', wdh: '0');

      expect(
        find.byKey(kHaken(idBank, 1)),
        findsNothing,
        reason:
            'Ein unlesbares Gewicht lässt den ganzen Satz wegfallen — '
            'null Kilo zu buchen wäre geraten (Spec 8.3)',
      );
      expect(find.byKey(kHaken(idBank, 2)), findsOneWidget);
      expect(find.byKey(kHaken(idBank, 3)), findsNothing);
      expect(fortschritt(tester).fertig, 1);
      expect(
        bilanzZahlen(tester),
        (saetze: 1, volumen: 600.0),
        reason:
            '„Eine Rechnung, eine Zahl" (Spec 3.8): 60 kg × 10, sonst '
            'nichts',
      );

      await tester.tap(find.byKey(kAbschliessen));
      await verstreiche(tester);

      final sitzung = (await h.sitzungen()).single;
      expect(
        sitzung.setCount,
        1,
        reason:
            'Was in der Bilanz stand, steht in der Ablage — und nicht '
            'mehr und nicht weniger',
      );
      expect(sitzung.volumeKg, 600.0);
    });

    logTest('leere Satzzeilen und Übungen ohne Satz kommen nicht in die '
        'Ablage', (tester, h) async {
      await zeigeLog(tester, h);
      await satz(tester, idBank, 2, gewicht: '60', wdh: '10');

      await tester.tap(find.byKey(kAbschliessen));
      await verstreiche(tester);

      final sitzung = (await h.sitzungen()).single;
      expect(sitzung.exercises, hasLength(1));
      expect(
        sitzung.exercises.single.sets,
        hasLength(1),
        reason:
            'Satz 1 blieb leer und fehlt — der eingetragene ist der '
            'einzige',
      );
    });
  });

  group('Satzzeilen', () {
    logTest('„+ Satz" hängt eine Zeile an, die das Gewicht der letzten erbt', (
      tester,
      h,
    ) async {
      await zeigeLog(tester, h);
      final davor = ExerciseCatalog.all[idBizeps]!.sets;
      expect(find.byKey(kFeldGewicht(idBizeps, davor + 1)), findsNothing);

      await satz(tester, idBizeps, davor, gewicht: '20', wdh: '12');
      await tester.tap(find.byKey(kSatzHinzu(idBizeps)));
      await tester.pump();

      expect(
        feldText(tester, kFeldGewicht(idBizeps, davor + 1)),
        '20',
        reason: 'Spec 3.4: „der das Gewicht des letzten erbt"',
      );
      expect(
        feldText(tester, kFeldWdh(idBizeps, davor + 1)),
        isEmpty,
        reason:
            'Die Wiederholungen erbt sie nicht — sonst zählte ein '
            'Satz, den niemand gemacht hat',
      );
      expect(fortschritt(tester).gesamt, saetzeVon(Workout.a) + 1);
    });

    logTest('das Minus nimmt eine leere Zeile weg — die letzte einer Übung '
        'nie', (tester, h) async {
      await zeigeLog(tester, h);
      final zeilen = ExerciseCatalog.all[idBizeps]!.sets;
      expect(zeilen, 3, reason: 'Vorbedingung: Bizeps-Curls haben 3 Sätze');

      await tester.tap(find.byKey(kMinus(idBizeps, 3)));
      await tester.pump();
      expect(find.byKey(kFeldWdh(idBizeps, 3)), findsNothing);
      expect(find.byKey(kFeldWdh(idBizeps, 2)), findsOneWidget);

      await tester.tap(find.byKey(kMinus(idBizeps, 2)));
      await tester.pump();
      expect(find.byKey(kFeldWdh(idBizeps, 2)), findsNothing);

      expect(
        find.byKey(kFeldWdh(idBizeps, 1)),
        findsOneWidget,
        reason:
            'Eine Übung ohne Satzzeile hätte kein Feld mehr, in das man '
            'tippen könnte (Spec 3.5)',
      );
      expect(
        find.byKey(kMinus(idBizeps, 1)),
        findsNothing,
        reason: 'Der letzte Satz einer Übung lässt sich nicht entfernen',
      );
    });

    logTest('ein gefüllter Satz hat ein Haken und kein Minus — er lässt sich '
        'nicht über das Minus verlieren', (tester, h) async {
      await zeigeLog(tester, h);
      await satz(tester, idBizeps, 2, gewicht: '20', wdh: '12');

      expect(find.byKey(kMinus(idBizeps, 2)), findsNothing);
      expect(find.byKey(kHaken(idBizeps, 2)), findsOneWidget);
    });

    logTest('eine erledigte Übung klappt zu einer Zeile zu und zeigt ihre '
        'Zusammenfassung, mit lokalisierten Zahlen', (tester, h) async {
      await zeigeLog(tester, h);
      await satz(tester, idBank, 1, gewicht: '60', wdh: '10');
      await satz(tester, idBank, 2, gewicht: '62.5', wdh: '9');
      await satz(tester, idBank, 3, gewicht: '62,5', wdh: '8');
      await satz(tester, idBank, 4, gewicht: '62,5', wdh: '7');

      // Ob die Karte beim letzten Satz von selbst zuklappt oder erst auf
      // Antippen, legt die Spec nicht fest („Zuklappen und Aufklappen geht
      // nur bei erledigten Übungen"); beides ist erlaubt.
      if (find.byKey(kZusammenfassung(idBank)).evaluate().isEmpty) {
        await tester.tap(find.byKey(kUebungKopf(idBank)));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
      }

      expect(find.byKey(kZusammenfassung(idBank)), findsOneWidget);
      final zusammenfassung = textVon(tester, kZusammenfassung(idBank));
      expect(zusammenfassung, contains('62,5'));
      expect(
        zusammenfassung,
        isNot(contains('62.5')),
        reason: 'Ausgegeben wird lokalisiert über `Format` (Spec 3.5)',
      );
      expect(zusammenfassung, contains('60'));
      expect(zusammenfassung, contains('10'));

      // Wieder auf: die Werte stehen da.
      await tester.tap(find.byKey(kUebungKopf(idBank)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(kZusammenfassung(idBank)), findsNothing);
      expect(feldText(tester, kFeldGewicht(idBank, 1)), '60');
      expect(feldText(tester, kFeldWdh(idBank, 4)), '7');
    });

    logTest('eine Karte klappt nicht unter den Fingern zu, sobald der letzte '
        'Satz vollständig ist — eine Korrektur geht ohne Aufklappen', (
      tester,
      h,
    ) async {
      await zeigeLog(tester, h);
      await satz(tester, idBank, 1, gewicht: '60', wdh: '10');
      await satz(tester, idBank, 2, gewicht: '60', wdh: '10');
      await satz(tester, idBank, 3, gewicht: '60', wdh: '10');
      // „12" gilt schon nach der getippten „1" als vollständig (Tim,
      // 10.11.2026): Klappte die Karte jetzt zu, verschwände sie mitten in
      // der Eingabe.
      await satz(tester, idBank, 4, gewicht: '60', wdh: '1');
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.byKey(kZusammenfassung(idBank)),
        findsNothing,
        reason: 'Die Karte bleibt offen, solange man in ihr tippt',
      );
      expect(find.byKey(kFeldWdh(idBank, 4)), findsOneWidget);

      await tippe(tester, kFeldWdh(idBank, 4), '12');
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(kZusammenfassung(idBank)), findsNothing);
      expect(feldText(tester, kFeldWdh(idBank, 4)), '12');

      // Die Korrektur „12" wird zu „10" — ohne erst aufzuklappen.
      await tippe(tester, kFeldWdh(idBank, 4), '10');
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(kZusammenfassung(idBank)), findsNothing);
      expect(feldText(tester, kFeldWdh(idBank, 4)), '10');
      expect(fortschritt(tester).fertig, 4);
    });

    logTest('die erledigte Karte klappt erst zu, wenn man mit der nächsten '
        'Übung weitermacht', (tester, h) async {
      await zeigeLog(tester, h);
      for (var n = 1; n <= ExerciseCatalog.all[idBank]!.sets; n++) {
        await satz(tester, idBank, n, gewicht: '60', wdh: '10');
      }
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(kZusammenfassung(idBank)), findsNothing);

      await satz(tester, idSchraeg, 1, gewicht: '22', wdh: '12');
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.byKey(kZusammenfassung(idBank)),
        findsOneWidget,
        reason:
            'Sie bleibt offen, bis die nächste Übung angetippt wird '
            '(Tim, 10.11.2026)',
      );
      expect(find.byKey(kFeldWdh(idSchraeg, 1)), findsOneWidget);
    });

    logTest('eine halb gefüllte Übung bleibt offen und lässt sich nicht '
        'zuklappen', (tester, h) async {
      await zeigeLog(tester, h);
      await satz(tester, idSchraeg, 1, gewicht: '22', wdh: '12');

      await tester.tap(find.byKey(kUebungKopf(idSchraeg)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byKey(kZusammenfassung(idSchraeg)), findsNothing);
      expect(
        feldText(tester, kFeldWdh(idSchraeg, 1)),
        '12',
        reason:
            'Swift: `header` ist `.disabled(!isComplete)` — eine halb '
            'gefüllte Karte bleibt offen (Spec 3.4)',
      );
      expect(find.byKey(kFeldWdh(idSchraeg, 2)), findsOneWidget);
    });
  });

  group(
    'Ein leeres Gewichtsfeld heißt „wie letztes Mal" (Tim, 10.11.2026)',
    () {
      logTest('nur Wiederholungen getippt: gespeichert wird der graue Wert vom '
          'letzten Mal, nicht 0', (tester, h) async {
        await h.ablage.legeAb(verlaufSitzung(saetze: bankVerlauf()));
        await zeigeLog(tester, h);

        await satz(tester, idBank, 1, wdh: '10');
        await satz(tester, idBank, 2, wdh: '9');

        expect(
          find.byKey(kHaken(idBank, 1)),
          findsOneWidget,
          reason:
              'Der Satz gilt weiterhin als erledigt, sobald Wiederholungen '
              'dastehen',
        );
        expect(
          textVon(tester, kPlatzhalterGewicht(idBank, 1)),
          contains('60'),
          reason: 'Das Feld bleibt grau mit dem Wert, der übernommen wird',
        );
        final summe = bilanzZahlen(tester);
        expect(summe.saetze, 2);
        expect(
          summe.volumen,
          closeTo(60.0 * 10 + 62.5 * 9, 1),
          reason:
              'Die Bilanz zählt, was gespeichert wird (Spec 3.8): mit 60 kg '
              'und 62,5 kg, nicht mit 0 (auf ganze kg gerundet ist erlaubt)',
        );

        await tester.tap(find.byKey(kAbschliessen));
        await verstreiche(tester);

        // Die Ablage traegt hier zwei Sitzungen: die Verlaufssitzung,
        // die der Fall vorher anlegt, und die eben abgeschlossene.
        // `.single` warf deshalb „Too many elements"; `.first` ist die
        // neue, weil das Repository neueste zuerst liefert.
        // (10.11.2026, TEST_AENDERN=1 — die Anforderung ist dieselbe.)
        final sitzung = (await h.sitzungen()).first;
        expect(
          [for (final s in sitzung.exercises.single.sets) (s.weight, s.reps)],
          [(60.0, 10), (62.5, 9)],
          reason:
              'Wer nur die Wiederholungen nachträgt, behält sein '
              'Arbeitsgewicht — es wird nicht stillschweigend zu 0',
        );
        expect(sitzung.volumeKg, 60.0 * 10 + 62.5 * 9);
      });

      logTest('ohne Platzhalter heißt leer 0 kg — eine Körpergewichtsübung', (
        tester,
        h,
      ) async {
        // Kein Verlauf: Es gibt nichts zu übernehmen.
        await zeigeLog(tester, h);
        expect(
          textVon(tester, kPlatzhalterGewicht(idBank, 1)),
          matches(strich),
        );

        await satz(tester, idBank, 1, wdh: '10');
        await tester.tap(find.byKey(kAbschliessen));
        await verstreiche(tester);

        final satz1 = (await h.sitzungen()).single.exercises.single.sets.single;
        expect(satz1.reps, 10);
        expect(
          satz1.weight.abs(),
          0,
          reason:
              'Gibt es keinen Platzhalter, bleibt leer gleich 0 kg '
              '(Tim, 10.11.2026)',
        );
      });

      logTest('hat der Verlauf für diesen Satz keinen Wert, heißt leer 0 kg', (
        tester,
        h,
      ) async {
        await h.ablage.legeAb(verlaufSitzung(saetze: bankVerlauf()));
        await zeigeLog(tester, h);
        // Heute vier Zeilen, damals drei: Satz 4 hat keinen Platzhalter.
        expect(
          textVon(tester, kPlatzhalterGewicht(idBank, 4)),
          matches(strich),
        );

        await satz(tester, idBank, 4, wdh: '7');
        await tester.tap(find.byKey(kAbschliessen));
        await verstreiche(tester);

        final satz4 = (await h.sitzungen()).first.exercises.single.sets.single;
        expect(satz4.reps, 7);
        expect(
          satz4.weight.abs(),
          0,
          reason:
              'Wo es keinen grauen Wert gibt, wird auch keiner geliehen '
              'und nicht der des Nachbarsatzes',
        );
      });

      logTest('eine ausdrücklich getippte 0 ist nicht dasselbe wie ein leeres '
          'Feld', (tester, h) async {
        await h.ablage.legeAb(verlaufSitzung(saetze: bankVerlauf()));
        await zeigeLog(tester, h);

        await satz(tester, idBank, 1, gewicht: '0', wdh: '10');
        await satz(tester, idBank, 2, wdh: '9');

        expect(
          find.byKey(kPlatzhalterGewicht(idBank, 1)),
          findsNothing,
          reason: 'Eine getippte 0 steht im Feld und verdrängt den Platzhalter',
        );
        await tester.tap(find.byKey(kAbschliessen));
        await verstreiche(tester);

        final saetze = (await h.sitzungen()).first.exercises.single.sets;
        expect(
          saetze[0].weight.abs(),
          0,
          reason:
              'Sie heißt null Kilo und überschreibt den Platzhalter: '
              'jemand hat wirklich ohne Zusatzgewicht gearbeitet',
        );
        expect(saetze[1].weight, 62.5, reason: 'Das leere Feld daneben nicht');
      });

      logTest('der Platzhalter verschwindet nicht, wenn nur die '
          'Wiederholungen getippt werden und wieder gelöscht', (
        tester,
        h,
      ) async {
        await h.ablage.legeAb(verlaufSitzung(saetze: bankVerlauf()));
        await zeigeLog(tester, h);

        await satz(tester, idBank, 1, wdh: '10');
        await tippe(tester, kFeldWdh(idBank, 1), '');

        expect(textVon(tester, kPlatzhalterGewicht(idBank, 1)), contains('60'));
        expect(find.byKey(kHaken(idBank, 1)), findsNothing);
      });
    },
  );

  group('Unterstützung', () {
    logTest('der Umschalter steht nur bei Übungen, die Unterstützung '
        'erlauben', (tester, h) async {
      await zeigeLog(tester, h);

      expect(find.byKey(kUmschalter(idDips)), findsOneWidget);
      expect(
        find.byKey(kUmschalter(idBank)),
        findsNothing,
        reason: 'Spec 3.4: „nur bei `Exercise.allowsAssist`"',
      );
      expect(find.byKey(kUmschalter(idBizeps)), findsNothing);
    });

    logTest('Unterstützung wird negativ abgelegt und als „kg U" angezeigt', (
      tester,
      h,
    ) async {
      await zeigeLog(tester, h);

      await tester.tap(find.byKey(kUmschalterUnterstuetzung(idDips)));
      await tester.pump();
      await satz(tester, idDips, 1, gewicht: '27', wdh: '8');

      expect(
        textVon(tester, kEinheitGewicht(idDips, 1)),
        'kg U',
        reason: 'Spec 3.5: bei eingeschalteter Unterstützung „kg U"',
      );
      expect(
        feldText(tester, kFeldGewicht(idDips, 1)),
        '27',
        reason:
            'Eingetippt und angezeigt wird die Zahl von der Maschine, '
            'positiv (Spec 8.1)',
      );

      await tester.tap(find.byKey(kAbschliessen));
      await verstreiche(tester);

      final dips = (await h.sitzungen()).single.exercises.single;
      expect(
        dips.sets.single.weight,
        -27.0,
        reason:
            'Nach dem Abschließen trägt der Satz −27, nicht 27 '
            '(Spec 17.3)',
      );
    });

    logTest('mit Zusatzgewicht bleibt das Gewicht positiv, die Einheit heißt '
        '„kg"', (tester, h) async {
      await zeigeLog(tester, h);

      await tester.tap(find.byKey(kUmschalterZusatz(idDips)));
      await tester.pump();
      await satz(tester, idDips, 1, gewicht: '10', wdh: '8');

      expect(textVon(tester, kEinheitGewicht(idDips, 1)), 'kg');
      expect(
        textVon(tester, kEinheitGewicht(idBank, 1)),
        'kg',
        reason:
            'Der Umschalter gehört an die Übung, nicht ans Training: '
            'Bankdrücken bleibt „kg"',
      );

      await tester.tap(find.byKey(kAbschliessen));
      await verstreiche(tester);

      expect(
        (await h.sitzungen()).single.exercises.single.sets.single.weight,
        10.0,
      );
    });

    logTest('der Umschalter gilt für alle Zeilen der Übung', (tester, h) async {
      await zeigeLog(tester, h);

      await tester.tap(find.byKey(kUmschalterUnterstuetzung(idDips)));
      await tester.pump();

      for (var n = 1; n <= ExerciseCatalog.all[idDips]!.sets; n++) {
        expect(
          textVon(tester, kEinheitGewicht(idDips, n)),
          'kg U',
          reason: 'Satz $n',
        );
      }
    });

    logTest('ohne Verlauf steht Unterstützung an, wie der Entwurf es '
        'zeichnet', (tester, h) async {
      await zeigeLog(tester, h);

      expect(
        textVon(tester, kEinheitGewicht(idDips, 1)),
        'kg U',
        reason:
            'Spec 13.3: „Ohne Verlauf gilt der Vorgabewert, und der ist '
            '`Exercise.allowsAssist`"',
      );
    });

    logTest('der zuletzt benutzte Modus wird fürs nächste Mal übernommen', (
      tester,
      h,
    ) async {
      // Letztes Mal mit Zusatzgewicht (positives Gewicht).
      await h.ablage.legeAb(
        verlaufSitzung(
          saetze: {
            idDips: [(10, 8), (10, 8), (10, 7)],
          },
        ),
      );
      await zeigeLog(tester, h);

      expect(
        textVon(tester, kEinheitGewicht(idDips, 1)),
        'kg',
        reason:
            'Spec 8.1 / 13.3: „Modus wird fürs nächste Mal übernommen" — '
            'aus dem letzten abgeschlossenen Training, nicht aus dem '
            'Vorgabewert',
      );
    });
  });

  group('Zeitübungen', () {
    logTest('beim Seitstütz ist das Gewicht gesperrt, die zweite Spalte '
        'heißt „Sek." und das Volumen bleibt unberührt', (tester, h) async {
      await zeigeLog(tester, h);

      final gewicht = find.byKey(kFeldGewicht(idSeitstuetz, 1));
      if (gewicht.evaluate().isNotEmpty) {
        final editierbar = find.descendant(
          of: gewicht,
          matching: find.byType(EditableText),
        );
        expect(
          tester.widget<EditableText>(editierbar).readOnly,
          isTrue,
          reason:
              'Spec 8.2: „Das Gewichtsfeld ist abgeblendet und '
              'gesperrt"',
        );
      }
      expect(
        textVon(tester, kEinheitGewicht(idSeitstuetz, 1)),
        isEmpty,
        reason: 'Spec 8.2: „seine Einheit verschwindet"',
      );
      expect(textVon(tester, kEinheitWdh(idSeitstuetz, 1)), 'Sek.');
      expect(
        textVon(tester, kEinheitWdh(idSplit, 1)),
        'Wdh',
        reason: 'Alle anderen Übungen zählen Wiederholungen',
      );

      await tippe(tester, kFeldWdh(idSeitstuetz, 1), '35');
      expect(find.byKey(kHaken(idSeitstuetz, 1)), findsOneWidget);

      await tester.tap(find.byKey(kAbschliessen));
      await verstreiche(tester);

      final sitzung = (await h.sitzungen()).single;
      final plank = sitzung.exercises.single;
      expect(plank.exerciseId, idSeitstuetz);
      expect(
        plank.sets.single.reps,
        35,
        reason:
            '`CompletedSet.reps` trägt hier Sekunden — dasselbe Feld, '
            'andere Bedeutung (Spec 8.2)',
      );
      expect(plank.sets.single.weight.abs(), 0);
      expect(
        sitzung.volumeKg,
        0,
        reason: 'Das Volumen überspringt Zeitübungen',
      );
    }, workout: Workout.b);
  });
}

/// Die erste Übung von Gym B — eine ganz gewöhnliche, mit Wiederholungen.
const idSplit = 'splitSquat';
