import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/design/platzhalter.dart' show ohneWert;

import 'support.dart' show ankuendigung;
import 'verlauf_support.dart';

/// Die **Karten** des Schirms „Letzte Trainings" (#79): Reihenfolge,
/// Aufklappen, die Grenze von zwölf, die beiden Kennzahlen, die Sätze, das
/// Aufwärmen, die Uhrzeit je Satz und der Puls.
///
/// Grundlage ist `docs/superpowers/specs/2026-11-11-gym-verlauf-design.md`,
/// Abschnitte 5, 7, 8, 9 und 10, und der Entwurf
/// `docs/screens/screens/gym-history.js`. Hülle und API stehen in
/// `verlauf_support.dart`. Geschrieben **ohne** den späteren Schirm gesehen
/// zu haben.
///
/// ## Was nicht geprüft wird
///
/// Schriftgrößen, Farben, die Blur-Kante der Statusleiste und die Namen der
/// Wochentage in den Titeln. Geprüft wird, **was** dasteht und **wann** —
/// nicht wie es aussieht.
void main() {
  group('Die Karten und ihre Reihenfolge', () {
    verlaufTest('neueste zuerst — nach dem Datum, nicht nach der '
        'Einfügereihenfolge', (tester, h) async {
      await h.fuelle([
        sitzung(id: 'MITTE', datum: vormittag(4)),
        sitzung(id: 'NEU', datum: vormittag(1)),
        sitzung(id: 'ALT', datum: vormittag(8)),
      ]);

      await zeigeVerlauf(tester, h);

      expect(kartenReihenfolge(tester), ['NEU', 'MITTE', 'ALT']);
    });

    verlaufTest('die neueste Karte ist offen, die übrigen sind zu', (
      tester,
      h,
    ) async {
      await h.fuelle(trainingsReihe(4));

      await zeigeVerlauf(tester, h);

      expect(karteOffen('S-0'), isTrue, reason: 'die neueste');
      for (final id in ['S-1', 'S-2', 'S-3']) {
        expect(karteOffen(id), isFalse, reason: '$id ist zu');
        expect(
          find.byKey(kVerlaufKopf(id)),
          findsOneWidget,
          reason: 'Auch eine zugeklappte Karte steht als Zeile da',
        );
      }
    });

    verlaufTest('Antippen klappt eine Karte auf und wieder zu — die '
        'übrigen bleiben, wie sie sind', (tester, h) async {
      await h.fuelle(trainingsReihe(3));
      await zeigeVerlauf(tester, h);

      await oeffneKarte(tester, 'S-1');
      expect(karteOffen('S-1'), isTrue);
      expect(karteOffen('S-0'), isTrue, reason: 'Die neueste bleibt offen');
      expect(karteOffen('S-2'), isFalse);

      await schliesseKarte(tester, 'S-1');
      expect(karteOffen('S-1'), isFalse);
      expect(karteOffen('S-0'), isTrue);

      await schliesseKarte(tester, 'S-0');
      expect(
        karteOffen('S-0'),
        isFalse,
        reason: 'Auch die neueste lässt sich zuklappen',
      );
    });

    verlaufTest('zwei Trainings am selben Tag sind zwei Karten', (
      tester,
      h,
    ) async {
      await h.fuelle([
        sitzung(id: 'MORGENS', datum: vormittag(2), workout: Workout.a),
        sitzung(
          id: 'ABENDS',
          datum: vormittag(2).add(const Duration(hours: 9)),
          workout: Workout.b,
        ),
      ]);

      await zeigeVerlauf(tester, h);

      expect(kartenReihenfolge(tester), [
        'ABENDS',
        'MORGENS',
      ], reason: 'Am selben Tag gewinnt der spätere Zeitpunkt');
    });

    verlaufTest('ein Training ohne Workout fällt nicht heraus', (
      tester,
      h,
    ) async {
      await h.fuelle([
        sitzung(id: 'OHNE', datum: vormittag(1), workout: null),
        sitzung(id: 'MIT', datum: vormittag(2)),
      ]);

      await zeigeVerlauf(tester, h);

      expect(
        kartenReihenfolge(tester),
        ['OHNE', 'MIT'],
        reason:
            '„kein Workout" ist ein eigener Schlüssel, kein Fehler '
            '(`GymSessionMerge`) — eine Sitzung ohne Workout bekommt eine '
            'Karte wie jede andere',
      );
    });
  });

  group('Höchstens zwölf Karten', () {
    verlaufTest('von vierzehn Trainings stehen die zwölf neuesten da', (
      tester,
      h,
    ) async {
      await h.fuelle(trainingsReihe(14));

      await zeigeVerlauf(tester, h);

      final ids = kartenReihenfolge(tester);
      expect(ids, hasLength(12));
      expect(ids.first, 'S-0');
      expect(ids.last, 'S-11');
      expect(find.byKey(kVerlaufKarte('S-12')), findsNothing);
      expect(find.byKey(kVerlaufKarte('S-13')), findsNothing);
    });

    verlaufTest('die Kennzahlen zählen alle Trainings des Zeitraums, nicht '
        'nur die zwölf Karten', (tester, h) async {
      await h.fuelle(trainingsReihe(14));

      await zeigeVerlauf(tester, h);

      expect(
        zahlAus(verlaufText(tester, kVerlaufWertTrainings)),
        14,
        reason:
            'Vierzehn Trainings in vierzehn Tagen: Die Kennzahl ist '
            'keine Zählung der Karten',
      );
    });

    verlaufTest('bei zwölf oder weniger fehlt keines', (tester, h) async {
      await h.fuelle(trainingsReihe(12));

      await zeigeVerlauf(tester, h);

      expect(kartenReihenfolge(tester), hasLength(12));
    });
  });

  group('Die Kennzahlen über 14 Tage', () {
    verlaufTest('vierzehn Berliner Kalendertage bis einschließlich heute — '
        'Tagesgrenzen nach Berliner Zeit', (tester, h) async {
      // Heute ist der 09.03. Das Fenster reicht vom 24.02. bis zum 09.03.
      await h.fuelle([
        // Heute früh: drin.
        sitzung(id: 'HEUTE', datum: vormittag(0)),
        // 23:30 UTC am 23.02. ist 00:30 Berliner Zeit am 24.02.: drin. Ein
        // Vergleich nach UTC-Tag stellte ihn auf den 23.
        sitzung(
          id: 'GRENZE-DRIN',
          datum: DateTime.utc(2026, 2, 23, 23, 30),
          workout: Workout.b,
        ),
        // 22:59 UTC am 23.02. ist 23:59 Berliner Zeit am 23.02.: draußen.
        sitzung(
          id: 'GRENZE-DRAUSSEN',
          datum: DateTime.utc(2026, 2, 23, 22, 59),
          workout: Workout.c,
        ),
      ]);

      await zeigeVerlauf(tester, h);

      expect(
        zahlAus(verlaufText(tester, kVerlaufWertTrainings)),
        2,
        reason: 'Heute und der 24.02. zählen, der 23.02. nicht',
      );
      expect(
        zahlAus(verlaufText(tester, kVerlaufWertVolumen)),
        2200,
        reason: 'Zwei Trainings mit je 1.100 kg — das dritte zählt nicht',
      );
      expect(
        find.byKey(kVerlaufKarte('GRENZE-DRAUSSEN')),
        findsOneWidget,
        reason: 'Als Karte steht es trotzdem da: die Karten sind der Verlauf',
      );
    });

    verlaufTest('das Volumen ist die Summe der Sitzungen und rechnet '
        'unterstützte Sätze nicht mit', (tester, h) async {
      await h.fuelle([
        sitzung(
          id: 'MIT-U',
          datum: vormittag(1),
          uebungen: [
            bank(),
            uebung(idDips, [(-25, 9), (-25, 8), (-30, 8)]),
          ],
        ),
      ]);

      await zeigeVerlauf(tester, h);

      expect(
        zahlAus(verlaufText(tester, kVerlaufWertVolumen)),
        1100,
        reason:
            'Unterstützung ist Hilfe der Maschine, keine Last: '
            '`ImportedSession.volumeKg` zählt sie nicht. Mit dem Betrag '
            'gerechnet wären es 1.325.',
      );
    });
  });

  group('Die Kopfzeile', () {
    verlaufTest('nennt Workout, Berliner Tag, Sätze, Volumen und Dauer', (
      tester,
      h,
    ) async {
      await h.fuelle([
        sitzung(
          id: 'K',
          // 23:30 UTC am 04.03. ist 00:30 Berliner Zeit am 05.03.
          datum: DateTime.utc(2026, 3, 4, 23, 30),
          workout: Workout.a,
          minuten: 65,
        ),
      ]);

      await zeigeVerlauf(tester, h);

      final kopf = verlaufText(tester, kVerlaufKopf('K'));
      expect(kopf, contains(Workout.a.label));
      expect(
        kopf,
        contains('05.03.'),
        reason: 'Der Berliner Tag, nicht der UTC-Tag',
      );
      expect(kopf, isNot(contains('04.03.')));
      expect(kopf, contains('2 Sätze'));
      expect(kopf, contains('1.100 kg'));
      expect(kopf, contains('65 min'));
    });

    verlaufTest('ohne eingetragene Dauer steht keine „0 min" da', (
      tester,
      h,
    ) async {
      await h.fuelle([sitzung(id: 'K', datum: vormittag(1), minuten: null)]);

      await zeigeVerlauf(tester, h);

      final kopf = verlaufText(tester, kVerlaufKopf('K'));
      expect(
        kopf,
        isNot(contains('min')),
        reason:
            '`ImportedSession.minutes` ist `null`, wenn nichts eingetragen '
            'wurde — nicht 0. „0 min" behauptete ein Training ohne Dauer.',
      );
      expect(kopf, contains('2 Sätze'), reason: 'Der Rest steht trotzdem da');
    });

    verlaufTest('ein Training ohne tragende Last zeigt kein „0 kg"', (
      tester,
      h,
    ) async {
      await h.fuelle([
        sitzung(
          id: 'K',
          datum: vormittag(1),
          uebungen: [
            uebung(idDips, [(-25, 9), (-25, 8)]),
          ],
        ),
      ]);

      await zeigeVerlauf(tester, h);

      final kopf = verlaufText(tester, kVerlaufKopf('K'));
      expect(kopf, contains('2 Sätze'), reason: 'Die Sätze zählen mit');
      expect(
        kopf,
        isNot(matches(RegExp(r'(^|\s)0\s*kg'))),
        reason:
            'Das Volumen ist hier 0, weil Unterstützung nicht zählt — „0 '
            'kg" behauptete, es sei nichts bewegt worden',
      );
    });

    verlaufTest('das Aufwärmen steht nicht in den Sätzen und nicht in der '
        'Dauer', (tester, h) async {
      await h.fuelle([
        sitzung(
          id: 'K',
          datum: vormittag(1),
          minuten: 65,
          aufwaermen: const WarmUpDone(
            kind: WarmUpKind.bike,
            minutes: 10,
            km: 3.2,
          ),
        ),
      ]);

      await zeigeVerlauf(tester, h);

      final kopf = verlaufText(tester, kVerlaufKopf('K'));
      expect(kopf, contains('65 min'));
      expect(
        kopf,
        isNot(contains('75')),
        reason: 'Zehn Minuten Rad sind keine Trainingsdauer',
      );
      expect(
        kopf,
        contains('2 Sätze'),
        reason: 'Aufwärmen ist kein Satz (`ImportedSession.setCount`)',
      );
    });
  });

  group('Die Sätze', () {
    verlaufTest('jeder Satz steht als „60 kg × 10" da, in der Reihenfolge, '
        'in der er gemacht wurde', (tester, h) async {
      await h.fuelle([
        sitzung(
          id: 'S',
          datum: vormittag(0),
          uebungen: [
            uebung(idBank, [(60, 10), (62.5, 9), (62.5, 8)]),
          ],
        ),
      ]);

      await zeigeVerlauf(tester, h);

      expect(verlaufText(tester, kVerlaufSatz('S', idBank, 1)), '60 kg × 10');
      expect(
        verlaufText(tester, kVerlaufSatz('S', idBank, 2)),
        '62,5 kg × 9',
        reason: 'Dezimalkomma, nie „62.5"',
      );
      expect(verlaufText(tester, kVerlaufSatz('S', idBank, 3)), '62,5 kg × 8');
      expect(find.byKey(kVerlaufSatz('S', idBank, 4)), findsNothing);
    });

    verlaufTest('die Übungen stehen in der Reihenfolge der Sitzung, mit '
        'ihrem Namen aus dem Katalog', (tester, h) async {
      await h.fuelle([
        sitzung(
          id: 'S',
          datum: vormittag(0),
          uebungen: [
            uebung(idDips, [(-25, 9)]),
            bank(),
            uebung(idSeitheben, [(10, 15)]),
          ],
        ),
      ]);

      await zeigeVerlauf(tester, h);

      final ids = [idDips, idBank, idSeitheben];
      final oben = [
        for (final id in ids)
          tester.getTopLeft(find.byKey(kVerlaufUebung('S', id))).dy,
      ];
      expect(oben[0], lessThan(oben[1]));
      expect(oben[1], lessThan(oben[2]));
      for (final id in ids) {
        expect(
          verlaufText(tester, kVerlaufUebung('S', id)),
          contains(ExerciseCatalog.all[id]!.name),
          reason: id,
        );
      }
    });

    verlaufTest('Unterstützung steht als „kg U", ohne Minus — und zählt '
        'nicht ins Volumen', (tester, h) async {
      await h.fuelle([
        sitzung(
          id: 'S',
          datum: vormittag(0),
          uebungen: [
            bank(),
            uebung(idDips, [(-25, 9), (-25, 8), (-30, 8)]),
          ],
        ),
      ]);

      await zeigeVerlauf(tester, h);

      expect(
        verlaufText(tester, kVerlaufSatz('S', idDips, 1)),
        '25 kg U × 9',
        reason: 'Der Betrag, nicht „−25"',
      );
      expect(verlaufText(tester, kVerlaufSatz('S', idDips, 3)), '30 kg U × 8');
      for (var n = 1; n <= 3; n++) {
        final text = verlaufText(tester, kVerlaufSatz('S', idDips, n));
        expect(text, isNot(contains('-')));
        expect(text, isNot(contains('−')));
      }
      final kopf = verlaufText(tester, kVerlaufKopf('S'));
      expect(
        kopf,
        contains('5 Sätze'),
        reason: 'Unterstützte Sätze sind Sätze',
      );
      expect(
        kopf,
        contains('1.100 kg'),
        reason:
            'Aber Hilfe der Maschine ist keine Last: 600 + 500, nicht 1.325',
      );
      expect(
        verlaufText(tester, kVerlaufInhalt('S')),
        matches(RegExp('Unterst', caseSensitive: false)),
        reason: '„U" allein erklärt sich nicht — die Karte sagt, was es heißt',
      );
    });

    verlaufTest('ohne unterstützten Satz steht auch keine Erklärung dazu', (
      tester,
      h,
    ) async {
      await h.fuelle([sitzung(id: 'S', datum: vormittag(0))]);

      await zeigeVerlauf(tester, h);

      expect(
        verlaufText(tester, kVerlaufInhalt('S')),
        isNot(matches(RegExp('Unterst', caseSensitive: false))),
      );
    });

    verlaufTest('eine Zeitübung steht in Sekunden, ohne Gewicht', (
      tester,
      h,
    ) async {
      await h.fuelle([
        sitzung(
          id: 'S',
          datum: vormittag(0),
          uebungen: [
            uebung(idSeitstuetz, [(0, 30), (0, 35)]),
          ],
        ),
      ]);

      await zeigeVerlauf(tester, h);

      for (final n in [1, 2]) {
        final text = verlaufText(tester, kVerlaufSatz('S', idSeitstuetz, n));
        expect(text, isNot(contains('kg')), reason: 'Satz $n: Sekunden');
        expect(text, matches(RegExp(r'\bs\b')), reason: 'Satz $n');
      }
      expect(
        verlaufText(tester, kVerlaufSatz('S', idSeitstuetz, 1)),
        contains('30'),
      );
    });

    verlaufTest('ein Satz am eigenen Körpergewicht behauptet keine „0 kg"', (
      tester,
      h,
    ) async {
      await h.fuelle([
        sitzung(
          id: 'S',
          datum: vormittag(0),
          uebungen: [
            uebung(idDips, [(0, 12)]),
          ],
        ),
      ]);

      await zeigeVerlauf(tester, h);

      final text = verlaufText(tester, kVerlaufSatz('S', idDips, 1));
      expect(text, contains('12'), reason: 'Die Wiederholungen stehen da');
      expect(
        text,
        isNot(matches(RegExp(r'(^|\s)0([.,]0)?\s*kg'))),
        reason:
            '„0 ist keine Antwort auf ‚kein Wert\'": Ein Satz ohne '
            'Zusatzgewicht hat kein Gewicht, nicht das Gewicht 0',
      );
    });

    verlaufTest('eine Übung, die der Katalog nicht kennt, fällt nicht '
        'lautlos heraus', (tester, h) async {
      await h.fuelle([
        sitzung(
          id: 'S',
          datum: vormittag(0),
          uebungen: [
            bank(),
            uebung(idUnbekannt, [(40, 8), (40, 8), (40, 7)]),
          ],
        ),
      ]);

      await zeigeVerlauf(tester, h);

      expect(tester.takeException(), isNull);
      expect(
        find.byKey(kVerlaufUebung('S', idUnbekannt)),
        findsOneWidget,
        reason:
            'Die Ablage trägt die Sätze, die Kopfzeile zählt sie mit — die '
            'Zeile darunter lässt sie nicht verschwinden',
      );
      expect(
        verlaufText(tester, kVerlaufKopf('S')),
        contains('5 Sätze'),
        reason: 'Dieselbe Zahl wie in der Ablage',
      );
      expect(find.byKey(kVerlaufUebung('S', idBank)), findsOneWidget);
    });

    verlaufTest('die Notiz steht in der offenen Karte — und nur, wenn es '
        'eine gibt', (tester, h) async {
      await h.fuelle([
        sitzung(
          id: 'MIT',
          datum: vormittag(0),
          notiz: 'Schulter links zwickt leicht',
        ),
        sitzung(id: 'OHNE', datum: vormittag(2)),
      ]);

      await zeigeVerlauf(tester, h);
      await oeffneKarte(tester, 'OHNE');

      expect(
        verlaufText(tester, kVerlaufNotiz('MIT')),
        contains('Schulter links zwickt leicht'),
      );
      expect(
        find.byKey(kVerlaufNotiz('OHNE')),
        findsNothing,
        reason: 'Eine leere Notizzeile gäbe es nur, um leer zu sein',
      );
    });

    verlaufTest('eine zugeklappte Karte zeigt keine Sätze', (tester, h) async {
      await h.fuelle(trainingsReihe(2));

      await zeigeVerlauf(tester, h);

      expect(find.byKey(kVerlaufSatz('S-1', idBank, 1)), findsNothing);
      expect(find.byKey(kVerlaufSatz('S-0', idBank, 1)), findsOneWidget);
    });
  });

  group('Das Aufwärmen hat drei Zustände (#40)', () {
    Future<Map<String, String>> zeilen(
      WidgetTester tester,
      VerlaufHuelle h,
    ) async {
      await h.fuelle([
        sitzung(
          id: 'GEMACHT',
          datum: vormittag(0),
          aufwaermen: const WarmUpDone(
            kind: WarmUpKind.bike,
            minutes: 10,
            km: 3.2,
          ),
        ),
        sitzung(
          id: 'UEBERSPRUNGEN',
          datum: vormittag(1),
          aufwaermen: const WarmUpSkipped(),
        ),
        sitzung(id: 'NICHTS', datum: vormittag(2)),
        sitzung(
          id: 'OHNE-STRECKE',
          datum: vormittag(3),
          aufwaermen: const WarmUpDone(kind: WarmUpKind.mobility, minutes: 8),
        ),
      ]);
      await zeigeVerlauf(tester, h);
      for (final id in ['GEMACHT', 'UEBERSPRUNGEN', 'NICHTS', 'OHNE-STRECKE']) {
        await oeffneKarte(tester, id);
      }
      return {
        for (final id in ['GEMACHT', 'UEBERSPRUNGEN', 'NICHTS', 'OHNE-STRECKE'])
          id: verlaufText(tester, kVerlaufAufwaermen(id)),
      };
    }

    verlaufTest('in jeder offenen Karte steht genau eine Aufwärmzeile — auch '
        'wenn nichts eingetragen ist', (tester, h) async {
      await zeilen(tester, h);

      for (final id in ['GEMACHT', 'UEBERSPRUNGEN', 'NICHTS', 'OHNE-STRECKE']) {
        expect(
          find.descendant(
            of: find.byKey(kVerlaufInhalt(id)),
            matching: find.byKey(kVerlaufAufwaermen(id)),
          ),
          findsOneWidget,
          reason:
              '$id: Die Zeile verschwindet nicht, weil nichts eingetragen '
              'ist — nur ihre Füllung ändert sich',
        );
      }
    });

    verlaufTest('gemacht: Art, Minuten und — wo es sie gibt — die Strecke', (
      tester,
      h,
    ) async {
      final z = await zeilen(tester, h);

      expect(z['GEMACHT'], contains('10'), reason: 'die Minuten');
      expect(z['GEMACHT'], contains('3,2'), reason: 'die Strecke, mit Komma');
      expect(z['OHNE-STRECKE'], contains('8'), reason: 'die Minuten');
      expect(
        z['OHNE-STRECKE'],
        isNot(matches(RegExp(r'\bkm\b'))),
        reason:
            'Bei Mobility gibt es keine Strecke: `km` ist `null`, nicht 0 — '
            '„0 km" behauptete eine Strecke von null Kilometern',
      );
    });

    verlaufTest('übersprungen ist eine Antwort und sagt es', (tester, h) async {
      final z = await zeilen(tester, h);

      expect(
        z['UEBERSPRUNGEN'],
        matches(RegExp('überspr', caseSensitive: false)),
        reason: '„Übersprungen" ist eine gegebene Antwort, kein fehlender Wert',
      );
      expect(z['UEBERSPRUNGEN'], isNot(matches(eineZiffer)));
    });

    verlaufTest('nichts eingetragen ist etwas anderes als übersprungen', (
      tester,
      h,
    ) async {
      final z = await zeilen(tester, h);

      expect(
        z['NICHTS'],
        isNot(matches(RegExp('überspr', caseSensitive: false))),
        reason:
            'So kommt alles aus der Übernahme (#59) herein. Ein erfundenes '
            '„übersprungen" behauptete eine Antwort, die niemand gegeben hat.',
      );
      expect(z['NICHTS'], isNot(matches(eineZiffer)));
      expect(
        z['NICHTS'],
        isNot(equals(z['UEBERSPRUNGEN'])),
        reason: 'Zwei verschiedene Auskünfte, zwei verschiedene Zeilen',
      );
      expect(z['NICHTS'], isNot(equals(z['GEMACHT'])));
    });
  });

  group('Die Uhrzeit je Satz (`recordedAt`) — der Normalfall ist: keine', () {
    verlaufTest('eine Sitzung ohne Satz-Uhrzeiten fällt nicht heraus: Karte, '
        'Sätze, Kennzahlen', (tester, h) async {
      await h.fuelle([
        // So kommt alles aus der Übernahme (#59) herein.
        sitzung(id: 'OHNE-ZEITEN', datum: vormittag(0)),
        sitzung(
          id: 'MIT-ZEITEN',
          datum: vormittag(2),
          uebungen: [
            bank(
              zeiten: [
                DateTime.utc(2026, 3, 7, 7, 10),
                DateTime.utc(2026, 3, 7, 7, 14),
              ],
            ),
          ],
        ),
      ]);

      await zeigeVerlauf(tester, h);
      await oeffneKarte(tester, 'MIT-ZEITEN');

      expect(kartenReihenfolge(tester), ['OHNE-ZEITEN', 'MIT-ZEITEN']);
      for (final id in ['OHNE-ZEITEN', 'MIT-ZEITEN']) {
        expect(
          verlaufText(tester, kVerlaufSatz(id, idBank, 1)),
          '60 kg × 10',
          reason: '$id: Die Sätze stehen, ob mit oder ohne Uhrzeit',
        );
        expect(verlaufText(tester, kVerlaufSatz(id, idBank, 2)), '62,5 kg × 8');
      }
      expect(
        zahlAus(verlaufText(tester, kVerlaufWertTrainings)),
        2,
        reason: 'Beide Trainings zählen',
      );
    });

    verlaufTest('ohne Satz-Uhrzeiten steht nirgends eine erfundene Zeit', (
      tester,
      h,
    ) async {
      await h.fuelle([
        sitzung(
          id: 'S',
          datum: vormittag(0),
          aufwaermen: const WarmUpDone(
            kind: WarmUpKind.bike,
            minutes: 10,
            km: 3.2,
          ),
          notiz: 'Schulter links zwickt leicht',
          uebungen: [
            bank(),
            uebung(idDips, [(-25, 9), (-25, 8)]),
          ],
        ),
      ]);

      await zeigeVerlauf(tester, h);

      expect(
        verlaufText(tester, kVerlaufKarte('S')),
        isNot(matches(eineUhrzeit)),
        reason:
            '`recordedAt` ist `null`: „nicht erfasst". Eine Uhrzeit hier '
            'behauptete, der Satz sei zu dieser Minute entstanden.',
      );
      expect(
        find.byKey(kVerlaufBand('S')),
        findsNothing,
        reason:
            'Ohne Uhrzeit je Satz lässt sich kein Abschnitt berechnen — '
            'das Band gibt es dort nicht, es wird nicht gleichmäßig verteilt',
      );
    });

    verlaufTest('die Reihenfolge der Sätze hängt nie an der Uhr', (
      tester,
      h,
    ) async {
      // Satz 1 wurde später eingetragen als Satz 2 — etwa, weil er
      // nachträglich geleert und neu gefüllt wurde (Spec 11.4 des Erfassens).
      await h.fuelle([
        sitzung(
          id: 'S',
          datum: vormittag(0),
          uebungen: [
            bank(
              zeiten: [
                DateTime.utc(2026, 3, 9, 7, 30),
                DateTime.utc(2026, 3, 9, 7, 10),
              ],
            ),
          ],
        ),
      ]);

      await zeigeVerlauf(tester, h);

      expect(verlaufText(tester, kVerlaufSatz('S', idBank, 1)), '60 kg × 10');
      expect(verlaufText(tester, kVerlaufSatz('S', idBank, 2)), '62,5 kg × 8');
    });

    verlaufTest('Satz-Uhrzeiten ändern nichts an Kopfzeile und Kennzahlen', (
      tester,
      h,
    ) async {
      await h.fuelle([
        sitzung(id: 'OHNE', datum: vormittag(1)),
        sitzung(
          id: 'MIT',
          datum: vormittag(2),
          uebungen: [
            bank(
              zeiten: [
                DateTime.utc(2026, 3, 7, 7, 10),
                DateTime.utc(2026, 3, 7, 7, 14),
              ],
            ),
          ],
        ),
      ]);

      await zeigeVerlauf(tester, h);

      for (final id in ['OHNE', 'MIT']) {
        final kopf = verlaufText(tester, kVerlaufKopf(id));
        expect(kopf, contains('2 Sätze'), reason: id);
        expect(kopf, contains('1.100 kg'), reason: id);
        expect(kopf, contains('65 min'), reason: id);
      }
    });
  });
}
