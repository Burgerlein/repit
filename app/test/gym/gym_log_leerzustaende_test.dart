import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/design/platzhalter.dart' show Platzhalter;

import 'log_support.dart';

/// Die **Leerzustände** des Schirms „Training eintragen" (#78) und die
/// beiden Anforderungen, auf die es nach `CLAUDE.md` ankommt.
///
/// Grundlage ist
/// `docs/superpowers/specs/2026-11-10-gym-training-eintragen-design.md`,
/// Abschnitte 9.3, 14 und 17.3. Hülle und API stehen in `log_support.dart`.
///
/// Geschrieben aus der Spec, **ohne** den späteren Schirm gesehen zu haben.
///
/// ## Die beiden Pflichtfälle
///
/// 1. **Während des Ladens steht nie ein „keine Daten"-Grund** (Fehler
///    `01`). Zwischen dem Öffnen und dem Eintreffen von Entwurf und Verlauf
///    liegt ein Lesevorgang. Dann darf nicht dastehen: „0 / n" im
///    Fortschritt, „–" als Platzhalter, obwohl es einen Verlauf gibt, und —
///    der schlimmste Fall — „Erstes Mal — taste dich heran", obwohl die
///    Übung schon gemacht wurde: Er behauptet eine Tatsache über Tims
///    Trainingsverlauf, die falsch ist, und er sieht nicht aus wie ein
///    Ladezustand (Spec 9.3).
/// 2. **Ein Wert, der dastand, steht nach dem Zurücknavigieren wieder da**
///    (Fehler `32`). Hier besonders: **Ein eingetippter Satz darf nicht
///    verschwinden**, wenn man ins Vollbild geht und zurück oder den Schirm
///    verlässt und wiederkommt.
///
/// ## Wie „lädt" hergestellt wird
///
/// Nicht über einen überschriebenen Provider, sondern über die Ablage: Die
/// Tore ([Ablage.entwurfTor], [Ablage.verlaufTor]) halten das Lesen an. Das
/// ist der Moment, in dem sich die Frage stellt, und der Test muss dafür
/// nicht wissen, wie der Schirm intern liest.
///
/// ## Warum die Höhe gemessen werden darf
///
/// `CLAUDE.md` verbietet Layout-Tests; die Leerzustandsregel nennt die Höhe
/// ausdrücklich als Ausnahme: „Werte da, keine Werte, lädt — dieselbe Höhe,
/// dieselbe Breite, dieselbe Stelle." Verglichen wird deshalb nur **dieselbe
/// Anzeige mit sich selbst** in verschiedenen Datenlagen, nie gegen eine
/// Zahl.
void main() {
  /// Der „keine Daten"-Grund dieses Schirms.
  const ersteMal = 'Erstes Mal';

  /// Die Abschnitte, die in **jeder** Datenlage dastehen.
  List<Key> abschnitte(Workout workout) => [
    kFortschritt,
    kBilanz,
    kAufwaermen,
    kZwischenspeichern,
    kAbschliessen,
    kAbbrechen,
    kFussnote,
    for (final uebung in uebungenVon(workout)) ...[
      kUebung(uebung.id),
      kVorschlag(uebung.id),
    ],
  ];

  group('Pflicht 1 — während des Ladens steht nie ein „keine Daten"-Grund '
      '(`01`)', () {
    logTest('lädt alles: weder „Erstes Mal" noch „–" noch „0 / n"', (
      tester,
      h,
    ) async {
      // Es gibt einen Verlauf — „Erstes Mal" wäre falsch.
      await h.ablage.legeAb(verlaufSitzung(saetze: bankVerlauf()));
      h.ablage.entwurfTor = Completer<void>();
      h.ablage.verlaufTor = Completer<void>();

      await zeigeLog(tester, h);

      expect(
        allesText(tester),
        isNot(contains(ersteMal)),
        reason:
            'Der Satz behauptet, die Übung sei noch nie gemacht worden. '
            'Solange der Verlauf nicht gelesen ist, ist das eine falsche '
            'Auskunft — und sie sieht nicht aus wie ein Ladezustand '
            '(Spec 9.3)',
      );
      expect(
        satzPlatzhalter(),
        findsNothing,
        reason:
            'Ein „–" im Gewichtsfeld sagt „kein Wert vom letzten Mal", '
            'solange nicht nachgesehen ist, weiß das niemand',
      );
      expect(
        textVon(tester, kFortschritt),
        isNot(matches(RegExp(r'\d\s*/\s*\d'))),
        reason:
            '„0 / ${saetzeVon(Workout.a)} Sätze" hieße „nichts getan" — '
            'Fehler `01` in neuer Verpackung',
      );
      expect(
        textVon(tester, kBilanz),
        isNot(matches(RegExp(r'\d'))),
        reason:
            'Auch die Bilanz trägt beim Laden keine Zahl, schon gar '
            'keine 0 (Spec 14: „graue Form")',
      );
    });

    logTest('lädt alles: stattdessen stehen graue Formen an ihrer Stelle', (
      tester,
      h,
    ) async {
      h.ablage.entwurfTor = Completer<void>();
      h.ablage.verlaufTor = Completer<void>();

      await zeigeLog(tester, h);

      for (final key in abschnitte(Workout.a)) {
        expect(
          find.byKey(key),
          findsOneWidget,
          reason:
              '$key fehlt beim Laden: „Eine Anzeige verschwindet nicht, '
              'weil ihr Wert fehlt" (`CLAUDE.md`)',
        );
      }
      for (final key in [kFortschritt, kBilanz, kVorschlag(idBank)]) {
        expect(
          find.descendant(
            of: find.byKey(key),
            matching: find.byType(Platzhalter),
          ),
          findsAtLeastNWidgets(1),
          reason:
              '$key: „Balken und Zahl als graue Formen gleicher Breite" '
              '(Spec 14). Geprüft über den Baustein, nicht über eine Farbe.',
        );
      }
    });

    logTest('der Entwurf ist da, der Verlauf lädt noch: kein „Erstes Mal", '
        'keine Platzhalter vom letzten Mal', (tester, h) async {
      await h.ablage.legeAb(verlaufSitzung(saetze: bankVerlauf()));
      h.ablage.verlaufTor = Completer<void>();

      await zeigeLog(tester, h);

      expect(
        allesText(tester),
        isNot(contains(ersteMal)),
        reason:
            'Das ist der zweite Weg zum selben Fehler: Der Entwurf ist '
            'gelesen, der Verlauf nicht',
      );
      expect(
        satzPlatzhalter(),
        findsNothing,
        reason: 'Ein „–" stünde dort, obwohl es einen Verlauf gibt',
      );
      expect(
        find.descendant(
          of: find.byKey(kVorschlag(idBank)),
          matching: find.byType(Platzhalter),
        ),
        findsAtLeastNWidgets(1),
        reason:
            'Die Vorschlagszeile steht als graue Form in fester '
            'Zeilenzahl da (Spec 14)',
      );
    });

    logTest('der Verlauf ist da, der Entwurf lädt noch: der Fortschritt '
        'bleibt eine graue Form', (tester, h) async {
      await h.ablage.legeAb(verlaufSitzung(saetze: bankVerlauf()));
      h.ablage.entwurfTor = Completer<void>();

      await zeigeLog(tester, h);

      expect(
        textVon(tester, kFortschritt),
        isNot(matches(RegExp(r'\d\s*/\s*\d'))),
        reason:
            'Ob der Entwurf leer ist oder noch gelesen wird, weiß der '
            'Schirm erst, wenn die Ablage geantwortet hat',
      );
    });

    logTest('ist nachgesehen, stehen die Zahlen da — und keine graue Form '
        'mehr', (tester, h) async {
      await h.ablage.legeAb(verlaufSitzung(saetze: bankVerlauf()));
      final entwurfTor = h.ablage.entwurfTor = Completer<void>();
      final verlaufTor = h.ablage.verlaufTor = Completer<void>();
      await zeigeLog(tester, h);

      entwurfTor.complete();
      verlaufTor.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        fortschritt(tester),
        (fertig: 0, gesamt: saetzeVon(Workout.a)),
        reason:
            'Derselbe Zustand mit abgeschaltetem Ladefeld zeigt alles '
            '(Spec 17.3). „0 / n" ist jetzt die richtige Antwort auf „wie '
            'viel habe ich heute geschafft": nichts.',
      );
      expect(bilanzZahlen(tester), (saetze: 0, volumen: 0.0));
      expect(
        find.descendant(
          of: find.byKey(kFortschritt),
          matching: find.byType(Platzhalter),
        ),
        findsNothing,
        reason:
            '„Der Platzhalter gehört allein in den Ladezustand" '
            '(`CLAUDE.md`)',
      );
      expect(
        satzPlatzhalter(),
        findsWidgets,
        reason: 'Mit bekanntem Verlauf stehen die Werte vom letzten Mal',
      );
      expect(
        allesText(tester),
        contains(ersteMal),
        reason:
            'Die Übungen ohne Verlauf (alle außer Bankdrücken) sagen es '
            'jetzt — nachgesehen ist ja',
      );
    });

    logTest('die Karten behalten beim Laden ihre Form, und die '
        'Vorschlagszeile hat eine feste Zeilenzahl', (tester, h) async {
      final masse = <String, List<double>>{};
      void miss(String lage) {
        masse[lage] = [
          for (final key in [
            kFortschritt,
            kBilanz,
            kAufwaermen,
            kUebung(idBank),
            kUebung(idDips),
          ])
            tester.getSize(find.byKey(key)).height,
        ];
      }

      // 1. lädt
      final entwurfTor = h.ablage.entwurfTor = Completer<void>();
      final verlaufTor = h.ablage.verlaufTor = Completer<void>();
      await zeigeLog(tester, h);
      miss('lädt');

      // 2. geladen, kein Verlauf: Bankdrücken sagt „Erstes Mal — …"
      entwurfTor.complete();
      verlaufTor.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      miss('ohne Verlauf');

      // 3. geladen, mit Verlauf: Bankdrücken sagt „Steigern auf …"
      await h.ablage.legeAb(verlaufSitzung(saetze: bankVerlauf()));
      await neustart(tester, h);
      await oeffne(tester);
      miss('mit Verlauf');

      const namen = [
        'Fortschritt',
        'Bilanz',
        'Aufwärmen',
        'Bankdrücken',
        'Dips',
      ];
      for (var i = 0; i < namen.length; i++) {
        expect(
          masse['ohne Verlauf']![i],
          closeTo(masse['lädt']![i], 0.5),
          reason:
              '${namen[i]} springt zwischen „lädt" und „keine Werte" '
              '(`CLAUDE.md`: „Eine Anzeige, die es gibt, hat genau eine '
              'Form")',
        );
        expect(
          masse['mit Verlauf']![i],
          closeTo(masse['ohne Verlauf']![i], 0.5),
          reason:
              '${namen[i]} wächst, sobald ein Verlauf dazukommt — die '
              'Vorschlagszeile schwankt zwischen einer und zwei Zeilen, und '
              'ohne feste Zeilenzahl rutschen alle Karten darunter '
              '(Spec 14)',
        );
      }
    });
  });

  group(
    'Der allererste Trainingstag ist die Keine-Daten-Ansicht (Spec 14)',
    () {
      logTest('jede Übung zeigt „Erstes Mal" — einmal, nicht je Satzzeile', (
        tester,
        h,
      ) async {
        await zeigeLog(tester, h);

        for (final uebung in uebungenVon(Workout.a)) {
          expect(
            textVon(tester, kVorschlag(uebung.id)),
            contains(ersteMal),
            reason:
                '${uebung.name}: Spec 14 — „in jeder Karte die '
                '`FirstTime`-Zeile"',
          );
        }
        expect(
          vorkommen(allesText(tester), ersteMal),
          uebungenVon(Workout.a).length,
          reason:
              '„Der Grund steht einmal, nicht je Feld": nicht noch einmal '
              'an jeder Satzzeile',
        );
      });

      logTest('die Platzhalter sind ein Strich, nie eine 0', (tester, h) async {
        await zeigeLog(tester, h);

        for (final uebung in uebungenVon(Workout.a)) {
          for (var n = 1; n <= uebung.sets; n++) {
            if (!uebung.isTimed) {
              expect(
                textVon(tester, kPlatzhalterGewicht(uebung.id, n)),
                matches(strich),
                reason:
                    '${uebung.name} Satz $n, Gewicht: „–", keine 0 '
                    '(`CLAUDE.md`: „`0` ist keine Antwort auf ‚kein Wert‘")',
              );
            }
            expect(
              textVon(tester, kPlatzhalterWdh(uebung.id, n)),
              matches(strich),
              reason: '${uebung.name} Satz $n, Wiederholungen',
            );
          }
        }
      });

      logTest('keine Trendpfeile, auch wenn etwas eingetragen ist — es gibt '
          'nichts zu vergleichen', (tester, h) async {
        await zeigeLog(tester, h);
        expect(trendPfeile(), findsNothing);

        await satz(tester, idBank, 1, gewicht: '60', wdh: '10');

        expect(
          trendPfeile(),
          findsNothing,
          reason:
              'Spec 3.5: „ohne Vergleichswert kein Pfeil statt eines '
              'geratenen"',
        );
      });

      logTest('der Fortschritt und die Bilanz stehen bei 0 — das ist hier die '
          'richtige Antwort', (tester, h) async {
        await zeigeLog(tester, h);

        expect(fortschritt(tester), (fertig: 0, gesamt: saetzeVon(Workout.a)));
        expect(
          bilanzZahlen(tester),
          (saetze: 0, volumen: 0.0),
          reason:
              'Spec 14: „‚0 Sätze · 0 kg Volumen‘ ist kein verbotener '
              'Nullwert", sobald der Entwurf gelesen ist',
        );
      });

      logTest('der Schirm ist vollständig benutzbar — er sagt nur nichts über '
          'früher', (tester, h) async {
        await zeigeLog(tester, h);

        for (final key in abschnitte(Workout.a)) {
          expect(find.byKey(key), findsOneWidget, reason: '$key');
        }
        await satz(tester, idBank, 1, gewicht: '60', wdh: '10');
        await tester.tap(find.byKey(kAbschliessen));
        await verstreiche(tester);
        expect(await h.sitzungen(), hasLength(1));
      });

      logTest('die Fußnote verspricht keinen Abgleich mit Apple Health', (
        tester,
        h,
      ) async {
        await zeigeLog(tester, h);

        final fussnote = textVon(tester, kFussnote);
        expect(fussnote, isNotEmpty);
        expect(
          fussnote,
          isNot(contains('Apple Health')),
          reason:
              'Spec 3.7: „Bis der Lückenfüller gebaut ist, steht der '
              'dritte Satz nicht im Schirm." Eine Zusage, die nicht mehr '
              'stimmt, ist schlimmer als gar keine (`CLAUDE.md`)',
        );
        expect(fussnote, isNot(contains('Watch')));
      });
    },
  );

  group('Mit Verlauf stehen die Werte vom letzten Mal', () {
    logTest('Satz 1 zeigt Satz 1 vom letzten Mal, Satz 3 zeigt Satz 3 — und '
        'wo es keinen gab, steht „–"', (tester, h) async {
      await h.ablage.legeAb(verlaufSitzung(saetze: bankVerlauf()));
      await zeigeLog(tester, h);

      expect(textVon(tester, kPlatzhalterGewicht(idBank, 1)), contains('60'));
      expect(textVon(tester, kPlatzhalterWdh(idBank, 1)), contains('10'));
      expect(textVon(tester, kPlatzhalterGewicht(idBank, 2)), contains('62,5'));
      expect(textVon(tester, kPlatzhalterWdh(idBank, 2)), contains('9'));
      expect(textVon(tester, kPlatzhalterWdh(idBank, 3)), contains('8'));
      expect(
        textVon(tester, kPlatzhalterGewicht(idBank, 4)),
        matches(strich),
        reason:
            'Heute vier Zeilen, damals drei: „Gibt es dort keinen Satz, '
            'steht ‚–‘" (Spec 3.5)',
      );
      expect(textVon(tester, kPlatzhalterWdh(idBank, 4)), matches(strich));
    });

    logTest('die Übung mit Verlauf sagt nicht „Erstes Mal", die ohne sagt '
        'es', (tester, h) async {
      await h.ablage.legeAb(verlaufSitzung(saetze: bankVerlauf()));
      await zeigeLog(tester, h);

      expect(textVon(tester, kVorschlag(idBank)), isNot(contains(ersteMal)));
      expect(textVon(tester, kVorschlag(idSchraeg)), contains(ersteMal));
    });

    logTest('ein eingetragener Wert ersetzt den Platzhalter', (
      tester,
      h,
    ) async {
      await h.ablage.legeAb(verlaufSitzung(saetze: bankVerlauf()));
      await zeigeLog(tester, h);
      expect(find.byKey(kPlatzhalterGewicht(idBank, 1)), findsOneWidget);

      await tippe(tester, kFeldGewicht(idBank, 1), '62');

      expect(
        find.byKey(kPlatzhalterGewicht(idBank, 1)),
        findsNothing,
        reason:
            'Ein Platzhalter hinter einem eingetippten Wert wäre '
            'dasselbe Feld mit zwei Zahlen',
      );
      expect(find.byKey(kPlatzhalterWdh(idBank, 1)), findsOneWidget);
    });

    logTest('Trendpfeil, sobald etwas eingetragen ist und es etwas zu '
        'vergleichen gibt', (tester, h) async {
      await h.ablage.legeAb(verlaufSitzung(saetze: bankVerlauf()));
      await zeigeLog(tester, h);
      expect(trendPfeile(), findsNothing, reason: 'Noch nichts eingetragen');

      await satz(tester, idBank, 1, gewicht: '62,5', wdh: '10');
      expect(
        find.byKey(kTrend(idBank, 1)),
        findsOneWidget,
        reason: 'Schwerer als beim letzten Mal: Spec 13.2',
      );

      // Satz 4 hatte beim letzten Mal keinen Gegenpart.
      await satz(tester, idBank, 4, gewicht: '50', wdh: '10');
      expect(
        find.byKey(kTrend(idBank, 4)),
        findsNothing,
        reason: '„Ohne Vergleichswert kein Pfeil statt eines geratenen"',
      );
    });
  });

  group('Pflicht 2 — ein Wert, der dastand, steht nach dem Zurücknavigieren '
      'wieder da (`32`)', () {
    logTest('in zwei Satzzeilen tippen, ins Vollbild und zurück: beide '
        'Werte stehen wieder da, zwischendurch kein Platzhalter', (
      tester,
      h,
    ) async {
      // Mit Verlauf, damit ein Platzhalter vom letzten Mal überhaupt
      // dastünde, wenn der Wert verschwände.
      await h.ablage.legeAb(verlaufSitzung(saetze: bankVerlauf()));
      await zeigeLog(tester, h);
      await satz(tester, idBank, 1, gewicht: '62', wdh: '10');
      await satz(tester, idSchraeg, 1, gewicht: '22', wdh: '12');

      await oeffneVollbild(tester);

      expect(find.byKey(kVollbild), findsOneWidget);
      expect(
        feldText(tester, kFeldGewicht(idBank, 1)),
        '62',
        reason: 'Das Vollbild liest denselben Entwurf wie die Erfassung',
      );
      expect(feldText(tester, kFeldWdh(idBank, 1)), '10');
      expect(find.byKey(kPlatzhalterGewicht(idBank, 1)), findsNothing);

      // Im Vollbild weitertippen: Es muss in der Erfassung ankommen.
      await satz(tester, idBank, 2, gewicht: '62,5', wdh: '9');

      await tester.tap(find.byKey(kVollbildSchliessen));
      await tester.pump();
      // Mitten in der Überblendung, nicht erst danach.
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.byKey(kPlatzhalterGewicht(idBank, 1)),
        findsNothing,
        reason: 'Zwischendurch erscheint kein Platzhalter (Spec 17.3)',
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byKey(kVollbild), findsNothing);
      expect(feldText(tester, kFeldGewicht(idBank, 1)), '62');
      expect(feldText(tester, kFeldWdh(idBank, 1)), '10');
      expect(feldText(tester, kFeldGewicht(idSchraeg, 1)), '22');
      expect(feldText(tester, kFeldWdh(idSchraeg, 1)), '12');
      expect(
        feldText(tester, kFeldGewicht(idBank, 2)),
        '62,5',
        reason: 'Was im Vollbild getippt wurde, steht in der Erfassung',
      );
      expect(feldText(tester, kFeldWdh(idBank, 2)), '9');
      expect(find.byKey(kPlatzhalterGewicht(idBank, 1)), findsNothing);
      expect(find.byKey(kPlatzhalterWdh(idSchraeg, 1)), findsNothing);
      expect(
        fortschritt(tester).fertig,
        3,
        reason: 'Auch der Fortschritt hat nichts verloren',
      );
    });

    logTest('ein eingetippter Satz übersteht mehrmaliges Hin und Her', (
      tester,
      h,
    ) async {
      await zeigeLog(tester, h);
      await satz(tester, idBank, 1, gewicht: '60', wdh: '10');

      for (var i = 0; i < 3; i++) {
        await oeffneVollbild(tester);
        await tester.tap(find.byKey(kVollbildSchliessen));
        await verstreiche(tester);

        expect(
          feldText(tester, kFeldGewicht(idBank, 1)),
          '60',
          reason: 'Runde $i',
        );
        expect(feldText(tester, kFeldWdh(idBank, 1)), '10', reason: 'Runde $i');
      }
    });

    logTest('Schirm verlassen und wiederkommen: der Wert steht wieder da, '
        'zwischendurch kein Platzhalter', (tester, h) async {
      await h.ablage.legeAb(verlaufSitzung(saetze: bankVerlauf()));
      await zeigeLog(tester, h);
      await satz(tester, idBank, 1, gewicht: '62', wdh: '10');
      await satz(tester, idSchraeg, 1, gewicht: '22', wdh: '12');

      await verlasse(tester);
      await verstreiche(tester);
      expect(find.byKey(kHuelleUebersicht), findsOneWidget);

      await tester.tap(find.byKey(kHuelleOeffnen));
      await tester.pump();
      // Das erste Bild nach dem Wiedereintreten: Ein Platzhalter, der hier
      // aufblitzt, ist der Fehler.
      expect(
        find.byKey(kPlatzhalterGewicht(idBank, 1)),
        findsNothing,
        reason:
            'Im ersten Bild nach dem Wiedereintreten steht kein Platzhalter '
            'an der Stelle eines Werts, der dastand',
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(kPlatzhalterGewicht(idBank, 1)), findsNothing);
      await tester.pump(const Duration(seconds: 1));

      expect(feldText(tester, kFeldGewicht(idBank, 1)), '62');
      expect(feldText(tester, kFeldWdh(idBank, 1)), '10');
      expect(feldText(tester, kFeldGewicht(idSchraeg, 1)), '22');
      expect(feldText(tester, kFeldWdh(idSchraeg, 1)), '12');
    });

    logTest('nach einem Neustart kommt der Wert aus dem abgelegten '
        'Zwischenstand', (tester, h) async {
      await h.ablage.legeAb(verlaufSitzung(saetze: bankVerlauf()));
      await zeigeLog(tester, h);
      await satz(tester, idBank, 1, gewicht: '62', wdh: '10');
      await satz(tester, idSchraeg, 1, gewicht: '22', wdh: '12');
      await tester.pump(const Duration(milliseconds: 1600));
      expect(await h.entwurf(), isNotNull, reason: 'Vorbedingung');

      await neustart(tester, h);
      await oeffne(tester);

      expect(
        feldText(tester, kFeldGewicht(idBank, 1)),
        '62',
        reason:
            'Spec 17.3: „dort muss der Wert aus dem abgelegten '
            'Zwischenstand kommen"',
      );
      expect(feldText(tester, kFeldWdh(idBank, 1)), '10');
      expect(feldText(tester, kFeldGewicht(idSchraeg, 1)), '22');
      expect(feldText(tester, kFeldWdh(idSchraeg, 1)), '12');
      expect(find.byKey(kPlatzhalterGewicht(idBank, 1)), findsNothing);
    });

    logTest('beim Wiederlesen des Zwischenstands steht kein „0 / n" und kein '
        '„Erstes Mal" dazwischen', (tester, h) async {
      await h.ablage.legeAb(verlaufSitzung(saetze: bankVerlauf()));
      await zeigeLog(tester, h);
      await satz(tester, idBank, 1, gewicht: '62', wdh: '10');
      await tester.tap(find.byKey(kZwischenspeichern));
      await tester.pump();

      await neustart(tester, h);
      final entwurfTor = h.ablage.entwurfTor = Completer<void>();
      await oeffne(tester);

      expect(
        textVon(tester, kFortschritt),
        isNot(matches(RegExp(r'\d\s*/\s*\d'))),
        reason:
            'Der gespeicherte Satz ist da, der Schirm weiß es nur noch '
            'nicht: „0 / n" wäre `01` — und ein Satz, der dastand, '
            'verschwunden',
      );

      entwurfTor.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(fortschritt(tester).fertig, 1);
      expect(feldText(tester, kFeldWdh(idBank, 1)), '10');
    });
  });
}
