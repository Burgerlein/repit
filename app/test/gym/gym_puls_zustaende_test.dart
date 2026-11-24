import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
// Der Kern hat seit #95 eigene, schlanke Workout-Typen für die
// Zonen-Rechnung (zone_distribution.dart). Gemeint sind hier die
// Kanal-Typen aus health_types.dart — die Kern-Namen bleiben draußen.
import 'package:trainings_core/trainings_core.dart'
    hide WorkoutKind, WorkoutSample;

import 'package:repit/design/platzhalter.dart' show ohneWert;
import 'package:repit/health/health_types.dart';

import 'gym_puls_support.dart';
import 'support.dart' show ankuendigung;
import 'verlauf_support.dart';

/// Die **Zustände und Übergänge** des Pulsblocks im Gym-Verlauf (#512) und
/// die beiden Anforderungen, auf die es nach `CLAUDE.md` ankommt.
///
/// Grundlage ist `docs/superpowers/specs/2026-11-16-gym-puls-design.md`,
/// Abschnitte 3, 5, 6, 8 und 10. Hülle, Quelle und Schlüssel stehen in
/// `gym_puls_support.dart`. Geschrieben **ohne** die Implementierung
/// gesehen zu haben.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, nie verändert werden.
///
/// ## Die beiden Pflichtfälle
///
/// 1. **Während des Ladens steht nie ein „keine Daten"-Grund** (Fehler
///    `01`). Der Puls ist Abgeleitetes aus Apple Health; „keine Daten" und
///    „nicht erlaubt" sind nicht unterscheidbar, und solange nicht
///    nachgesehen ist, weiß der Schirm nichts davon.
/// 2. **Ein Wert, der dastand, steht nach dem Zurücknavigieren wieder da**
///    (Fehler `32`) — auch wenn die Quelle inzwischen hängt oder scheitert.
///
/// ## Was die Tests über das Lesen festlegen
///
/// Nicht, **wie oft** gelesen wird (die Freigabe löst einen Nachlauf aus,
/// Zählen wäre brüchig), sondern **ob**: für geöffnete Karten, für den
/// Berliner Tag der Sitzung, für genau das gefundene Training.
void main() {
  group('Pflicht 1 — während des Ladens steht nie ein „keine Daten"-Grund '
      '(`01`)', () {
    pulsTest('lädt, und die Quelle hätte nichts: weder Grund noch Fehler noch '
        'eine Zahl', (tester, p) async {
      await p.h.fuelle([pulsSitzung('S', 0)]);
      p.quelle.trainingsTor = Completer<void>();

      await zeigeVerlauf(tester, p.h);

      expect(
        find.byKey(kPuls('S')),
        findsOneWidget,
        reason: 'Der Block steht auch, solange gelesen wird',
      );
      expect(find.byKey(kPulsGrund('S')), findsNothing);
      expect(find.byKey(kPulsFehler('S')), findsNothing);
      expect(blockText(tester, 'S'), isNot(matches(eineZiffer)));
      expect(blockText(tester, 'S'), isNot(contains(ohneWert)));
      expect(
        platzhalterImBlock('S'),
        findsWidgets,
        reason: 'Der Platzhalter gehört allein in `NochNie`',
      );
    });

    pulsTest('lädt, und die Quelle hätte Daten: ebenfalls keine Zahl und kein '
        'Grund', (tester, p) async {
      await p.h.fuelle([pulsSitzung('S', 0)]);
      p.fuelleTag(0);
      p.quelle.trainingsTor = Completer<void>();

      await zeigeVerlauf(tester, p.h);

      expect(find.byKey(kPulsGrund('S')), findsNothing);
      expect(find.byKey(kPulsFehler('S')), findsNothing);
      expect(blockText(tester, 'S'), isNot(matches(eineZiffer)));
      expect(platzhalterImBlock('S'), findsWidgets);
    });

    pulsTest('das Training ist gefunden, die Stichproben fehlen noch: immer '
        'noch kein Grund', (tester, p) async {
      await p.h.fuelle([pulsSitzung('S', 0)]);
      p.fuelleTag(0);
      p.quelle.probenTor = Completer<void>();

      await zeigeVerlauf(tester, p.h);
      await verstreiche(tester);

      expect(
        p.quelle.probenAnfragen,
        isNotEmpty,
        reason: 'Vorbedingung: Das Training ist gefunden, der Schirm fragt',
      );
      expect(find.byKey(kPulsGrund('S')), findsNothing);
      expect(find.byKey(kPulsFehler('S')), findsNothing);
      expect(blockText(tester, 'S'), isNot(matches(eineZiffer)));
      expect(platzhalterImBlock('S'), findsWidgets);
    });

    pulsTest('danach: die graue Form ist weg, der Wert steht', (
      tester,
      p,
    ) async {
      await p.h.fuelle([pulsSitzung('S', 0)]);
      p.fuelleTag(0);
      p.quelle.trainingsTor = Completer<void>();
      await zeigeVerlauf(tester, p.h);

      p.quelle.gibAlleFrei();
      await verstreiche(tester);

      expect(platzhalterImBlock('S'), findsNothing);
      expect(find.byKey(kPulsGrund('S')), findsNothing);
      expect(verlaufText(tester, kPulsWert('S')), contains('123'));
    });

    pulsTest('danach, und es ist wirklich nichts da: jetzt steht der Grund',
        (tester, p) async {
      await p.h.fuelle([pulsSitzung('S', 0)]);
      p.quelle.trainingsTor = Completer<void>();
      await zeigeVerlauf(tester, p.h);
      expect(find.byKey(kPulsGrund('S')), findsNothing, reason: 'Vorbedingung');

      p.quelle.gibAlleFrei();
      await verstreiche(tester);

      expect(platzhalterImBlock('S'), findsNothing);
      expect(find.byKey(kPulsGrund('S')), findsOneWidget);
    });
  });

  group('Pflicht 2 — ein Wert, der dastand, steht nach dem Zurücknavigieren '
      'wieder da (`32`)', () {
    pulsTest('ein Schirm darüber und wieder zurück: der Puls steht wieder '
        'da, ohne Platzhalter dazwischen und ohne neues Lesen', (tester, p) async {
      await p.h.fuelle([pulsSitzung('S', 0)]);
      p.fuelleTag(0);
      await zeigeVerlaufMitPuls(tester, p);
      expect(
        verlaufText(tester, kPulsWert('S')),
        contains('123'),
        reason: 'Vorbedingung',
      );
      final trainingsAnfragen = p.quelle.trainingsAnfragen.length;
      final probenAnfragen = p.quelle.probenAnfragen.length;

      await schiebeDetail(tester);
      await zurueckSchrittweise(
        tester,
        pruefe: () {
          expect(
            platzhalterImBlock('S'),
            findsNothing,
            reason: 'Zwischendurch blitzt keine graue Form auf',
          );
          expect(find.byKey(kPulsGrund('S')), findsNothing);
          expect(find.byKey(kPulsFehler('S')), findsNothing);
          expect(verlaufText(tester, kPulsWert('S')), contains('123'));
        },
      );

      expect(
        p.quelle.trainingsAnfragen.length,
        trainingsAnfragen,
        reason: 'Ein `Bekannt` wird nicht erneut gelesen (Spec 8.1)',
      );
      expect(p.quelle.probenAnfragen.length, probenAnfragen);
    });

    pulsTest('den Schirm verlassen und wiederkommen, während die Quelle '
        'hängt: der Wert steht sofort da', (tester, p) async {
      await p.h.fuelle([pulsSitzung('S', 0)]);
      p.fuelleTag(0);
      await zeigeVerlaufMitPuls(tester, p);
      expect(verlaufText(tester, kPulsWert('S')), contains('123'));

      await verlasseVerlauf(tester);
      p.quelle.trainingsTor = Completer<void>();
      p.quelle.probenTor = Completer<void>();
      await oeffneVerlauf(tester);

      expect(
        platzhalterImBlock('S'),
        findsNothing,
        reason: 'Ein Wert, der dastand, steht wieder da — nicht als graue Form',
      );
      expect(find.byKey(kPulsGrund('S')), findsNothing);
      expect(verlaufText(tester, kPulsWert('S')), contains('123'));
    });

    pulsTest('den Schirm verlassen und wiederkommen, während die Quelle '
        'scheitert: ein gescheiterter Nachlauf nimmt nichts weg', (
      tester,
      p,
    ) async {
      await p.h.fuelle([pulsSitzung('S', 0)]);
      p.fuelleTag(0);
      await zeigeVerlaufMitPuls(tester, p);
      expect(verlaufText(tester, kPulsWert('S')), contains('123'));

      await verlasseVerlauf(tester);
      p.quelle.trainingsScheitern = true;
      p.quelle.probenScheitern = true;
      await oeffneVerlauf(tester);
      await verstreiche(tester);

      expect(find.byKey(kPulsFehler('S')), findsNothing);
      expect(find.byKey(kPulsGrund('S')), findsNothing);
      expect(verlaufText(tester, kPulsWert('S')), contains('123'));
    });
  });

  group('Wiederlesen — ein Ergebnis ohne Puls wird beim nächsten Öffnen '
      'erneut gelesen (Spec 8.2)', () {
    pulsTest('erst nichts, dann hat die Uhr nachsynchronisiert: der Puls '
        'erscheint, ohne dass dazwischen eine graue Form aufblitzt', (
      tester,
      p,
    ) async {
      await p.h.fuelle([pulsSitzung('S', 0)]);
      await zeigeVerlaufMitPuls(tester, p);
      expect(find.byKey(kPulsGrund('S')), findsOneWidget, reason: 'Vorbedingung');

      await verlasseVerlauf(tester);
      p.fuelleTag(0);
      await oeffneVerlaufSchrittweise(
        tester,
        pruefe: () => expect(
          platzhalterImBlock('S'),
          findsNothing,
          reason:
              'Das alte Ergebnis bleibt stehen, bis die neue Antwort da '
              'ist — der Platzhalter gehört allein in `NochNie`',
        ),
      );

      expect(find.byKey(kPulsGrund('S')), findsNothing);
      expect(verlaufText(tester, kPulsWert('S')), contains('123'));
    });

    pulsTest('erst gescheitert, dann geht es: der Puls erscheint beim '
        'nächsten Öffnen', (tester, p) async {
      await p.h.fuelle([pulsSitzung('S', 0)]);
      p.fuelleTag(0);
      p.quelle.trainingsScheitern = true;
      await zeigeVerlaufMitPuls(tester, p);
      expect(find.byKey(kPulsFehler('S')), findsOneWidget, reason: 'Vorbedingung');

      await verlasseVerlauf(tester);
      p.quelle.trainingsScheitern = false;
      await oeffneVerlaufSchrittweise(
        tester,
        pruefe: () => expect(platzhalterImBlock('S'), findsNothing),
      );

      expect(find.byKey(kPulsFehler('S')), findsNothing);
      expect(verlaufText(tester, kPulsWert('S')), contains('123'));
    });
  });

  group('Die Zustände', () {
    pulsTest('kein Krafttraining an dem Tag: ein Grund, einmal, und `–/–` an '
        'der Stelle der Zahl', (tester, p) async {
      await p.h.fuelle([pulsSitzung('S', 0)]);
      // Stichproben liegen da, aber kein Training, dem sie gehören.
      p.quelle.puls.addAll(proben(vormittag(0), standardProben));

      await zeigeVerlaufMitPuls(tester, p);

      expect(find.byKey(kPulsGrund('S')), findsOneWidget);
      expect(find.byKey(kPulsFehler('S')), findsNothing);
      expect(platzhalterImBlock('S'), findsNothing);
      expect(verlaufText(tester, kPulsWert('S')), contains(ohneWert));
      expect(
        blockText(tester, 'S'),
        isNot(matches(eineZiffer)),
        reason: 'Keine Zahl, keine `0` — ein Ring auf 0 ist `01`',
      );
      expect(
        p.quelle.probenAnfragen,
        isEmpty,
        reason:
            'Ohne Training gibt es keine zweite Abfrage: Der Puls eines '
            'anderen Trainings wäre falsch',
      );
    });

    pulsTest('der Grund benennt beides und verweist auf die '
        'Health-Einstellungen', (tester, p) async {
      await p.h.fuelle([pulsSitzung('S', 0)]);

      await zeigeVerlaufMitPuls(tester, p);

      final grund = verlaufText(tester, kPulsGrund('S'));
      expect(
        grund,
        matches(RegExp('Uhr')),
        reason: 'Die Uhr lief nicht mit — der Normalfall bei alten Trainings',
      );
      expect(
        grund,
        matches(RegExp('freigegeben|Freigabe|Zugriff', caseSensitive: false)),
        reason:
            '„keine Daten" und „nicht erlaubt" sind bei HealthKit nicht '
            'unterscheidbar — beides wird benannt',
      );
      expect(grund, contains('Health'));
      expect(grund, contains('Einstellungen'));
      expect(
        grund,
        isNot(
          matches(
            RegExp(
              'nichts getrackt|nicht trainiert|kein Training',
              caseSensitive: false,
            ),
          ),
        ),
        reason: 'Das Training steht in der Karte darüber',
      );
    });

    pulsTest('ein Training ohne Stichprobe ist derselbe Zustand mit demselben '
        'Grund', (tester, p) async {
      await p.h.fuelle([pulsSitzung('S', 0)]);
      p.quelle.trainings.add(kraft(0));

      await zeigeVerlaufMitPuls(tester, p);

      expect(find.byKey(kPulsGrund('S')), findsOneWidget);
      expect(find.byKey(kPulsFehler('S')), findsNothing);
      expect(verlaufText(tester, kPulsWert('S')), contains(ohneWert));
      expect(blockText(tester, 'S'), isNot(matches(eineZiffer)));
    });

    pulsTest('das Lesen der Trainings scheitert: ein Hinweis, nie der Grund '
        'von „keine Daten"', (tester, p) async {
      await p.h.fuelle([pulsSitzung('S', 0)]);
      p.fuelleTag(0);
      p.quelle.trainingsScheitern = true;

      await zeigeVerlaufMitPuls(tester, p);

      expect(find.byKey(kPulsFehler('S')), findsOneWidget);
      expect(find.byKey(kPulsGrund('S')), findsNothing);
      expect(platzhalterImBlock('S'), findsNothing);
      final text = verlaufText(tester, kPulsFehler('S'));
      expect(
        text,
        isNot(
          matches(
            RegExp(
              'keine Daten|nicht freigegeben|nichts getrackt|Einstellungen',
              caseSensitive: false,
            ),
          ),
        ),
        reason: 'Ein gescheitertes Lesen sagt nichts über die Datenlage',
      );
      expect(blockText(tester, 'S'), isNot(matches(eineZiffer)));
    });

    pulsTest('das Lesen der Stichproben scheitert: derselbe Hinweis', (
      tester,
      p,
    ) async {
      await p.h.fuelle([pulsSitzung('S', 0)]);
      p.fuelleTag(0);
      p.quelle.probenScheitern = true;

      await zeigeVerlaufMitPuls(tester, p);

      expect(find.byKey(kPulsFehler('S')), findsOneWidget);
      expect(find.byKey(kPulsGrund('S')), findsNothing);
    });

    pulsTest('mit Training und Stichproben: Ø, Bereich und Fläche stehen, '
        'kein Grund, kein Fehler', (tester, p) async {
      await p.h.fuelle([pulsSitzung('S', 0)]);
      p.fuelleTag(0);

      await zeigeVerlaufMitPuls(tester, p);

      expect(verlaufText(tester, kPulsWert('S')), contains('123'));
      final bereich = verlaufText(tester, kPulsBereich('S'));
      expect(bereich, contains('90'));
      expect(bereich, contains('200'));
      expect(find.byKey(kPulsFlaeche('S')), findsOneWidget);
      expect(find.byKey(kPulsGrund('S')), findsNothing);
      expect(find.byKey(kPulsFehler('S')), findsNothing);
      expect(platzhalterImBlock('S'), findsNothing);
    });

    pulsTest('nur ein Lauf am Tag zählt nicht: der Puls eines Laufs unter '
        'einer Gym-Sitzung wäre falsch', (tester, p) async {
      await p.h.fuelle([pulsSitzung('S', 0)]);
      p.quelle.trainings.add(kraft(0, art: WorkoutKind.running));
      p.quelle.puls.addAll(proben(vormittag(0), standardProben));

      await zeigeVerlaufMitPuls(tester, p);

      expect(find.byKey(kPulsGrund('S')), findsOneWidget);
      expect(p.quelle.probenAnfragen, isEmpty);
    });

    pulsTest('bei zwei Krafttrainings gewinnt das längere — und gefragt wird '
        'nur sein Fenster', (tester, p) async {
      await p.h.fuelle([pulsSitzung('S', 0)]);
      final kurz = kraft(0, minuten: 30, id: 'kurz');
      final lang = kraft(
        0,
        minuten: 68,
        id: 'lang',
        versatz: const Duration(hours: 2),
      );
      p.quelle.trainings.addAll([kurz, lang]);
      // Eine Probe im Fenster des kürzeren, die nicht eingehen darf.
      p.quelle.puls.addAll(proben(kurz.start, {10: 250}));
      p.quelle.puls.addAll(proben(lang.start, standardProben));

      await zeigeVerlaufMitPuls(tester, p);

      expect(p.quelle.probenAnfragen, isNotEmpty);
      for (final anfrage in p.quelle.probenAnfragen) {
        expect(anfrage.from.isAtSameMomentAs(lang.start), isTrue);
      }
      expect(verlaufText(tester, kPulsBereich('S')), contains('200'));
      expect(verlaufText(tester, kPulsBereich('S')), isNot(contains('250')));
    });
  });

  group('Der Berliner Tag und die Anfrage', () {
    pulsTest('ein Training um 00:10 Berliner Zeit gehört zum neuen Tag, '
        'obwohl es in UTC noch der Vortag ist', (tester, p) async {
      await p.h.fuelle([pulsSitzung('S', 0)]);
      final beginn = DateTime.utc(2026, 3, 8, 23, 10);
      p.quelle.trainings.add(
        WorkoutSample(
          id: 'nacht',
          start: beginn,
          kind: WorkoutKind.strength,
          minutes: 60,
        ),
      );
      p.quelle.puls.addAll(proben(beginn, {5: 100, 10: 110}));

      await zeigeVerlaufMitPuls(tester, p);

      expect(verlaufText(tester, kPulsWert('S')), contains('105'));
      expect(find.byKey(kPulsGrund('S')), findsNothing);
    });

    pulsTest('ein Training um 23:30 Berliner Zeit am Vortag gehört nicht '
        'dazu', (tester, p) async {
      await p.h.fuelle([pulsSitzung('S', 0)]);
      final beginn = DateTime.utc(2026, 3, 8, 22, 30);
      p.quelle.trainings.add(
        WorkoutSample(
          id: 'spaet',
          start: beginn,
          kind: WorkoutKind.strength,
          minutes: 60,
        ),
      );
      p.quelle.puls.addAll(proben(beginn, {5: 100, 10: 110}));

      await zeigeVerlaufMitPuls(tester, p);

      expect(find.byKey(kPulsGrund('S')), findsOneWidget);
    });

    pulsTest('eine übernommene Sitzung trägt den Berliner Tagesbeginn als '
        'UTC (08.03., 23:00) — gemeint ist der 9. März', (tester, p) async {
      // Wer `date.day` in UTC liest, fragt hier den 8. März.
      await p.h.fuelle([
        sitzung(
          id: 'S',
          datum: DateTime.utc(2026, 3, 8, 23),
          uebungen: bandUebungen(0, mitZeiten: false),
        ),
      ]);
      p.fuelleTag(0);

      await zeigeVerlaufMitPuls(tester, p);

      expect(verlaufText(tester, kPulsWert('S')), contains('123'));
      expect(find.byKey(kPulsGrund('S')), findsNothing);
    });

    pulsTest('die Anfragen: `workouts` über den Berliner Tag der Sitzung, '
        'dann die Herzfrequenz von Beginn bis Beginn plus Dauer', (
      tester,
      p,
    ) async {
      await p.h.fuelle([pulsSitzung('S', 0)]);
      p.fuelleTag(0);

      await zeigeVerlaufMitPuls(tester, p);

      final tag = BerlinCalendar.startOfDay(vormittag(0));
      expect(p.quelle.trainingsAnfragen, isNotEmpty);
      for (final anfrage in p.quelle.trainingsAnfragen) {
        expect(BerlinCalendar.startOfDay(anfrage.from), tag);
        expect(BerlinCalendar.startOfDay(anfrage.through), tag);
      }
      final beginn = vormittag(0);
      expect(p.quelle.probenAnfragen, isNotEmpty);
      for (final anfrage in p.quelle.probenAnfragen) {
        expect(anfrage.kind, VitalKind.heartRate);
        expect(anfrage.from.isAtSameMomentAs(beginn), isTrue);
        expect(
          anfrage.through.isAtSameMomentAs(
            beginn.add(const Duration(minutes: 68)),
          ),
          isTrue,
        );
      }
    });

    pulsTest('Zeitpunkte aus dem Kanal sind Ortszeit: der Puls stimmt trotzdem',
        (tester, p) async {
      await p.h.fuelle([pulsSitzung('S', 0)]);
      p.fuelleTag(0, ortszeit: true);

      await zeigeVerlaufMitPuls(tester, p);

      expect(verlaufText(tester, kPulsWert('S')), contains('123'));
      final bereich = verlaufText(tester, kPulsBereich('S'));
      expect(bereich, contains('90'));
      expect(bereich, contains('200'));
    });
  });

  group('Gelesen wird nur für geöffnete Karten', () {
    pulsTest('zugeklappte Karten fragen nichts und haben keinen Block; '
        'Öffnen fragt, Zuklappen und Wiederöffnen nicht noch einmal', (
      tester,
      p,
    ) async {
      await p.h.fuelle([for (var i = 0; i < 4; i++) pulsSitzung('S-$i', i)]);
      for (var i = 0; i < 4; i++) {
        p.fuelleTag(i);
      }

      await zeigeVerlaufMitPuls(tester, p);

      final heute = BerlinCalendar.dayKey(vormittag(0));
      expect(
        p.gefragteTage(),
        {heute},
        reason: 'Nur die neueste Karte ist offen',
      );
      for (var i = 1; i < 4; i++) {
        expect(find.byKey(kPuls('S-$i')), findsNothing);
      }

      await oeffneKarte(tester, 'S-2');
      await verstreiche(tester);

      expect(p.gefragteTage(), {heute, BerlinCalendar.dayKey(vormittag(2))});
      expect(verlaufText(tester, kPulsWert('S-2')), contains('123'));

      final davor = p.quelle.trainingsAnfragen.length;
      await schliesseKarte(tester, 'S-2');
      expect(find.byKey(kPuls('S-2')), findsNothing);
      await oeffneKarte(tester, 'S-2');
      await verstreiche(tester);

      expect(p.quelle.trainingsAnfragen.length, davor);
      expect(verlaufText(tester, kPulsWert('S-2')), contains('123'));
    });
  });

  group('Freigabe (#176, #183)', () {
    pulsTest('der Dialog wird einmal angefragt, gleich wie viele Karten '
        'offen sind und wie oft der Schirm geöffnet wird', (tester, p) async {
      await p.h.fuelle([for (var i = 0; i < 3; i++) pulsSitzung('S-$i', i)]);
      for (var i = 0; i < 3; i++) {
        p.fuelleTag(i);
      }
      await zeigeVerlaufMitPuls(tester, p);
      await oeffneKarte(tester, 'S-1');
      await oeffneKarte(tester, 'S-2');
      await verstreiche(tester);

      await verlasseVerlauf(tester);
      await oeffneVerlauf(tester);

      expect(
        p.quelle.freigabeAnfragen,
        1,
        reason:
            'Der Schirm löst die Anfrage aus — er ist aus jedem Tab '
            'erreichbar — und der Provider hält ihr Ergebnis',
      );
    });

    pulsTest('antwortet der Nutzer nach dem ersten, leeren Lauf, liest der '
        'Block neu: das leere Ergebnis steht nicht bis zum nächsten Start', (
      tester,
      p,
    ) async {
      await p.h.fuelle([pulsSitzung('S', 0)]);
      p.fuelleTag(0);
      p.quelle.leerOhneFreigabe = true;
      p.quelle.freigabeTor = Completer<void>();

      await zeigeVerlaufMitPuls(tester, p);
      expect(p.quelle.freigabeAnfragen, 1, reason: 'Vorbedingung');

      p.quelle.freigabeTor!.complete();
      await verstreiche(tester);
      await verstreiche(tester);

      expect(verlaufText(tester, kPulsWert('S')), contains('123'));
      expect(find.byKey(kPulsGrund('S')), findsNothing);
    });
  });

  group('Dieselbe Höhe, dieselbe Stelle', () {
    pulsTest('der Block hat in jedem Zustand dieselbe Größe und dieselbe '
        'Oberkante — lädt, Puls mit Band, Puls ohne Band, kein Puls, kein '
        'Training, gescheitert', (tester, p) async {
      await p.h.fuelle([
        pulsSitzung('S-0', 0, mitZeiten: true), // Puls, Band
        pulsSitzung('S-1', 1), // Puls, kein Band
        pulsSitzung('S-2', 2), // Training, aber kein Puls
        pulsSitzung('S-3', 3), // kein Training
        pulsSitzung('S-4', 4), // Lesen scheitert
      ]);
      p.fuelleTag(0);
      p.fuelleTag(1);
      p.quelle.trainings.add(kraft(2));
      p.quelle.scheiterTage.add(BerlinCalendar.dayKey(vormittag(4)));
      p.quelle.trainingsTor = Completer<void>();

      await zeigeVerlauf(tester, p.h);
      for (var i = 1; i < 5; i++) {
        await oeffneKarte(tester, 'S-$i');
      }
      await verstreiche(tester);

      final bezug = blockGroesse(tester, 'S-0');
      final oben = blockOben(tester, 'S-0');
      for (var i = 1; i < 5; i++) {
        expect(platzhalterImBlock('S-$i'), findsWidgets, reason: 'S-$i lädt');
        expect(blockGroesse(tester, 'S-$i'), bezug, reason: 'S-$i lädt');
        expect(blockOben(tester, 'S-$i'), oben, reason: 'S-$i lädt');
      }

      p.quelle.gibAlleFrei();
      await verstreiche(tester);

      // Vorbedingungen: Jeder Zustand ist wirklich eingetreten.
      expect(steht(kBandAbschnitt('S-0', 1)), isTrue, reason: 'S-0: Band');
      expect(steht(kBandGrund('S-1')), isTrue, reason: 'S-1: Puls, kein Band');
      expect(steht(kPulsGrund('S-2')), isTrue, reason: 'S-2: kein Puls');
      expect(steht(kPulsGrund('S-3')), isTrue, reason: 'S-3: kein Training');
      expect(steht(kPulsFehler('S-4')), isTrue, reason: 'S-4: gescheitert');

      for (var i = 0; i < 5; i++) {
        expect(
          blockGroesse(tester, 'S-$i'),
          bezug,
          reason: 'S-$i: gleiche Größe wie beim Laden',
        );
        expect(
          blockOben(tester, 'S-$i'),
          oben,
          reason: 'S-$i: gleiche Stelle im Karteninhalt',
        );
      }
    });
  });

  group('Zusagen und Vorlesetext', () {
    pulsTest('der Fuß kündigt nichts mehr an und nennt Quelle, Messung und '
        'Eintragszeit', (tester, p) async {
      await p.h.fuelle([pulsSitzung('S', 0)]);
      p.fuelleTag(0);

      await zeigeVerlaufMitPuls(tester, p);

      final fuss = verlaufText(tester, kVerlaufHinweis);
      expect(
        fuss,
        isNot(matches(ankuendigung)),
        reason:
            'Der Puls ist gebaut — „folgt in einer späteren Aufgabe" wäre '
            'eine Zusage, die nicht mehr stimmt',
      );
      expect(fuss, contains('Apple Health'));
      expect(fuss, matches(RegExp('Messung')));
      expect(fuss, matches(RegExp('eingetragen')));
    });

    pulsTest('der Fuß steht auch im leeren Verlauf mit denselben Aussagen', (
      tester,
      p,
    ) async {
      await zeigeVerlaufMitPuls(tester, p);

      final fuss = verlaufText(tester, kVerlaufHinweis);
      expect(fuss, isNot(matches(ankuendigung)));
      expect(fuss, contains('Apple Health'));
    });

    pulsTest('der Vorlesetext nennt mit Puls die Zahlen', (tester, p) async {
      final handle = tester.ensureSemantics();
      try {
        await p.h.fuelle([pulsSitzung('S', 0)]);
        p.fuelleTag(0);
        await zeigeVerlaufMitPuls(tester, p);

        final label = tester.getSemantics(find.byKey(kPuls('S'))).label;

        expect(label, contains('123'));
        expect(label, contains('200'));
      } finally {
        handle.dispose();
      }
    });

    pulsTest('der Vorlesetext nennt ohne Puls den Zustand, nicht das '
        'Zeichen', (tester, p) async {
      final handle = tester.ensureSemantics();
      try {
        await p.h.fuelle([pulsSitzung('S', 0)]);
        await zeigeVerlaufMitPuls(tester, p);

        final label = tester.getSemantics(find.byKey(kPuls('S'))).label;

        expect(label, matches(RegExp('kein', caseSensitive: false)));
        expect(label, isNot(contains(ohneWert)));
        expect(label, isNot(matches(RegExp('Strich', caseSensitive: false))));
      } finally {
        handle.dispose();
      }
    });

    pulsTest('der Vorlesetext während des Ladens nennt keine Zahl', (
      tester,
      p,
    ) async {
      final handle = tester.ensureSemantics();
      try {
        await p.h.fuelle([pulsSitzung('S', 0)]);
        p.fuelleTag(0);
        p.quelle.trainingsTor = Completer<void>();
        await zeigeVerlauf(tester, p.h);

        final label = tester.getSemantics(find.byKey(kPuls('S'))).label;

        expect(label, isNot(matches(eineZiffer)));
      } finally {
        handle.dispose();
      }
    });
  });
}
