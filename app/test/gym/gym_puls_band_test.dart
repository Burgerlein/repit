import 'package:flutter_test/flutter_test.dart';

import 'package:repit/design/platzhalter.dart' show ohneWert;

import 'gym_puls_support.dart';
import 'verlauf_support.dart';

/// Das **Übungsband** und die Zeilen darunter im Gym-Verlauf (#512): wo es
/// steht, wo nicht, was in den Zeilen steht — und dass Pausen Lücken bleiben.
///
/// Grundlage ist `docs/superpowers/specs/2026-11-16-gym-puls-design.md`,
/// Abschnitte 4.3 und 7, und der Entwurf `docs/screens/screens/gym-history.js`
/// (Variante „Entwurf — Puls mit Übungen"). Hülle, Quelle und Schlüssel
/// stehen in `gym_puls_support.dart`. Geschrieben **ohne** die
/// Implementierung gesehen zu haben.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, nie verändert werden.
///
/// ## Tims Entscheidung vom 16.11.2026
///
/// Puls für alle Sitzungen, Band nur, wo Satzzeiten vorliegen. Alles
/// Übernommene hat keine — dort steht der Puls **ohne** Band, und ein Satz
/// sagt, warum. Ein gleichmäßig verteiltes Band wäre eine Behauptung über
/// einen Ablauf, den niemand aufgezeichnet hat.
///
/// ## Was gemessen wird
///
/// `CLAUDE.md` verbietet Layout-Tests. Eine Ausnahme ist hier **die Geometrie
/// des Bands**: Dass eine Pause eine Lücke ist und kein verlängertes Segment,
/// lässt sich nur an den Maßen sehen. Verglichen wird das Band mit sich selbst
/// (Anteil an der Breite), nie gegen eine Pixelzahl.
void main() {
  group('Eine Sitzung ohne Satzzeiten — alles Übernommene', () {
    pulsTest('zeigt den Puls, aber kein Band, und sagt, warum', (
      tester,
      p,
    ) async {
      await p.h.fuelle([pulsSitzung('S', 0)]);
      p.fuelleTag(0);

      await zeigeVerlaufMitPuls(tester, p);

      expect(
        verlaufText(tester, kPulsWert('S')),
        contains('123'),
        reason: 'Der Puls steht bei jeder Sitzung',
      );
      expect(find.byKey(kPulsFlaeche('S')), findsOneWidget);
      expect(
        find.byKey(kVerlaufBand('S')),
        findsNothing,
        reason: 'Ohne Uhrzeit je Satz lässt sich kein Abschnitt berechnen',
      );
      expect(
        find.byKey(kBandGrund('S')),
        findsOneWidget,
        reason: 'Keine leere Fläche: ein Satz sagt, warum das Band fehlt',
      );
      final grund = verlaufText(tester, kBandGrund('S'));
      expect(grund, isNotEmpty);
      expect(
        grund,
        isNot(matches(RegExp('Fehler', caseSensitive: false))),
        reason: 'Es ist keine Störung, sondern der Normalfall',
      );
    });

    pulsTest('keine Zeile trägt Ziffer oder Ø, und nirgends steht eine '
        'erfundene Uhrzeit', (tester, p) async {
      await p.h.fuelle([pulsSitzung('S', 0)]);
      p.fuelleTag(0);

      await zeigeVerlaufMitPuls(tester, p);

      expect(
        find.byKey(kPuls('S')),
        findsOneWidget,
        reason: 'Vorbedingung: Der Block steht — nur ohne Band',
      );
      for (final uid in [idBank, idSchraeg, idDips, idSeitheben]) {
        expect(find.byKey(kUebungNr('S', uid)), findsNothing, reason: uid);
        expect(find.byKey(kUebungPuls('S', uid)), findsNothing, reason: uid);
        expect(find.byKey(kVerlaufUebung('S', uid)), findsOneWidget);
      }
      expect(
        verlaufText(tester, kVerlaufKarte('S')),
        isNot(matches(eineUhrzeit)),
        reason: '`recordedAt` ist `null`: „nicht erfasst"',
      );
    });

    pulsTest('mit Satzzeiten, aber ohne Pulsdaten: weder Band noch Bandgrund '
        'noch Ziffern', (tester, p) async {
      await p.h.fuelle([pulsSitzung('S', 0, mitZeiten: true)]);

      await zeigeVerlaufMitPuls(tester, p);

      expect(find.byKey(kPulsGrund('S')), findsOneWidget, reason: 'Vorbedingung');
      expect(
        find.byKey(kVerlaufBand('S')),
        findsNothing,
        reason:
            'Das Fenster stammt vollständig aus dem Apple-Training; ohne es '
            'lässt sich nichts proportional setzen',
      );
      expect(find.byKey(kBandGrund('S')), findsNothing);
      expect(find.byKey(kUebungNr('S', idBank)), findsNothing);
      expect(find.byKey(kUebungPuls('S', idBank)), findsNothing);
    });
  });

  group('Eine Sitzung mit Satzzeiten', () {
    pulsTest('zeigt das Band, ein Segment je Übung mit Abschnitt, und keinen '
        'Bandgrund', (tester, p) async {
      await p.h.fuelle([pulsSitzung('S', 0, mitZeiten: true)]);
      p.fuelleTag(0);

      await zeigeVerlaufMitPuls(tester, p);

      expect(find.byKey(kVerlaufBand('S')), findsOneWidget);
      for (final n in [1, 2, 3]) {
        expect(find.byKey(kBandAbschnitt('S', n)), findsOneWidget, reason: '$n');
      }
      expect(
        find.byKey(kBandAbschnitt('S', 4)),
        findsNothing,
        reason: 'Seitheben hat keine Satzzeiten und also keinen Abschnitt',
      );
      expect(find.byKey(kBandGrund('S')), findsNothing);
    });

    pulsTest('die Ziffer im Band ist dieselbe wie vor der Übungszeile', (
      tester,
      p,
    ) async {
      await p.h.fuelle([pulsSitzung('S', 0, mitZeiten: true)]);
      p.fuelleTag(0);

      await zeigeVerlaufMitPuls(tester, p);

      final zeilen = {idBank: 1, idSchraeg: 2, idDips: 3};
      zeilen.forEach((uid, n) {
        expect(verlaufText(tester, kUebungNr('S', uid)), '$n', reason: uid);
        expect(
          verlaufText(tester, kBandAbschnitt('S', n)),
          '$n',
          reason: 'Das Segment $n trägt dieselbe Ziffer wie die Zeile $uid',
        );
      });
    });

    pulsTest('rechts in der Zeile steht das Ø des Abschnitts — und die '
        'Stichproben in den Lücken zählen nicht', (tester, p) async {
      await p.h.fuelle([pulsSitzung('S', 0, mitZeiten: true)]);
      p.fuelleTag(0);

      await zeigeVerlaufMitPuls(tester, p);

      // Bankdrücken (Minuten 3 bis 19): 110, 120, 130. Die 200 bei Minute 20
      // liegt in der Lücke danach.
      expect(verlaufText(tester, kUebungPuls('S', idBank)), contains('Ø 120'));
      // Schrägbankdrücken (21 bis 33): 100, 110. Die 150 bei Minute 34 liegt
      // in der Lücke danach.
      expect(verlaufText(tester, kUebungPuls('S', idSchraeg)), contains('Ø 105'));
    });

    pulsTest('ein Abschnitt ohne Stichprobe sagt `Ø –/–`, nie `Ø 0` — das '
        'Segment steht trotzdem', (tester, p) async {
      await p.h.fuelle([pulsSitzung('S', 0, mitZeiten: true)]);
      p.fuelleTag(0);

      await zeigeVerlaufMitPuls(tester, p);

      // Dips (47 bis 57): Dort liegt keine Probe.
      final text = verlaufText(tester, kUebungPuls('S', idDips));
      expect(text, contains(ohneWert));
      expect(text, isNot(matches(eineZiffer)), reason: 'Keine `0` als Antwort');
      expect(
        find.byKey(kBandAbschnitt('S', 3)),
        findsOneWidget,
        reason: 'Die Übung hat stattgefunden, nur der Puls fehlt dort',
      );
    });

    pulsTest('die Kopfzeile kommt aus den Stichproben, nicht aus Apples '
        'Statistik des Trainings', (tester, p) async {
      await p.h.fuelle([pulsSitzung('S', 0, mitZeiten: true)]);
      p.fuelleTag(0);

      await zeigeVerlaufMitPuls(tester, p);

      // `kraft` setzt avgHR 99 und maxHR 150 — die Stichproben sagen 123 und
      // 90 bis 200.
      final wert = verlaufText(tester, kPulsWert('S'));
      expect(wert, contains('123'));
      expect(wert, isNot(contains('99')));
      final bereich = verlaufText(tester, kPulsBereich('S'));
      expect(bereich, contains('90'));
      expect(bereich, contains('200'));
      expect(bereich, isNot(contains('150')));
    });

    pulsTest('Pausen bleiben Lücken: Lage und Breite der Segmente sind '
        'proportional zur Zeit, und zwischen zwei Übungen liegt nichts', (
      tester,
      p,
    ) async {
      await p.h.fuelle([pulsSitzung('S', 0, mitZeiten: true)]);
      p.fuelleTag(0);

      await zeigeVerlaufMitPuls(tester, p);

      // Das Band stellt die ganzen 68 Minuten dar.
      final band = tester.getRect(find.byKey(kVerlaufBand('S')));
      final s1 = tester.getRect(find.byKey(kBandAbschnitt('S', 1)));
      final s2 = tester.getRect(find.byKey(kBandAbschnitt('S', 2)));
      final s3 = tester.getRect(find.byKey(kBandAbschnitt('S', 3)));
      double x(int minute) => band.left + band.width * minute / 68;

      const toleranz = 2.0;
      expect(s1.left, closeTo(x(3), toleranz), reason: 'Anfang bei Minute 3');
      expect(s1.right, closeTo(x(19), toleranz), reason: 'Ende bei Minute 19');
      expect(s2.left, closeTo(x(21), toleranz));
      expect(s2.right, closeTo(x(33), toleranz));
      expect(s3.left, closeTo(x(47), toleranz));
      expect(s3.right, closeTo(x(57), toleranz));
      expect(
        s2.left - s1.right,
        greaterThan(3),
        reason:
            'Zwischen Minute 19 und 21 liegt der Umbau — keine Übung, also '
            'kein verlängertes Segment',
      );
      expect(s3.left - s2.right, greaterThan(3));
    });

    pulsTest('die Zeilen bleiben in der Reihenfolge der Sitzung, auch wenn '
        'die Uhr etwas anderes sagt', (tester, p) async {
      // Übung 3 (Dips) wurde laut Uhr vor Übung 1 eingetragen.
      DateTime z(int minute) => vormittag(0).add(Duration(minutes: minute));
      await p.h.fuelle([
        pulsSitzung(
          'S',
          0,
          uebungen: [
            uebung(idBank, [(60, 10), (62.5, 8)], zeiten: [z(30), z(40)]),
            uebung(idSchraeg, [(22, 12), (22, 10)]),
            uebung(idDips, [(25, 9), (25, 8)], zeiten: [z(5), z(15)]),
          ],
        ),
      ]);
      p.fuelleTag(0);

      await zeigeVerlaufMitPuls(tester, p);

      double oben(String uid) =>
          tester.getTopLeft(find.byKey(kVerlaufUebung('S', uid))).dy;
      expect(oben(idBank), lessThan(oben(idSchraeg)));
      expect(oben(idSchraeg), lessThan(oben(idDips)));
      expect(verlaufText(tester, kUebungNr('S', idDips)), '3');
      expect(verlaufText(tester, kUebungNr('S', idBank)), '1');
    });
  });

  group('Teile einer Sitzung', () {
    pulsTest('fehlt Übung 2, heißt der nächste Abschnitt „3" — die Lücke '
        'steht da, die Zeile dazwischen trägt weder Ziffer noch Ø', (
      tester,
      p,
    ) async {
      DateTime z(int minute) => vormittag(0).add(Duration(minutes: minute));
      await p.h.fuelle([
        pulsSitzung(
          'S',
          0,
          uebungen: [
            uebung(idBank, [(60, 10), (62.5, 8)], zeiten: [z(3), z(19)]),
            uebung(idSchraeg, [(22, 12), (22, 10)]),
            uebung(idDips, [(25, 9), (25, 8)], zeiten: [z(47), z(57)]),
          ],
        ),
      ]);
      p.fuelleTag(0);

      await zeigeVerlaufMitPuls(tester, p);

      expect(find.byKey(kBandAbschnitt('S', 1)), findsOneWidget);
      expect(find.byKey(kBandAbschnitt('S', 2)), findsNothing);
      expect(find.byKey(kBandAbschnitt('S', 3)), findsOneWidget);
      expect(verlaufText(tester, kUebungNr('S', idDips)), '3');
      expect(find.byKey(kUebungNr('S', idSchraeg)), findsNothing);
      expect(find.byKey(kUebungPuls('S', idSchraeg)), findsNothing);
    });

    pulsTest('eine einzige Uhrzeit je Übung reicht nicht: kein Band, der '
        'Bandgrund steht', (tester, p) async {
      DateTime z(int minute) => vormittag(0).add(Duration(minutes: minute));
      await p.h.fuelle([
        pulsSitzung(
          'S',
          0,
          uebungen: [
            uebung(idBank, [(60, 10), (62.5, 8)], zeiten: [z(3), null]),
            uebung(idDips, [(25, 9), (25, 8)], zeiten: [null, z(50)]),
          ],
        ),
      ]);
      p.fuelleTag(0);

      await zeigeVerlaufMitPuls(tester, p);

      expect(find.byKey(kVerlaufBand('S')), findsNothing);
      expect(find.byKey(kBandGrund('S')), findsOneWidget);
      expect(verlaufText(tester, kPulsWert('S')), contains('123'));
    });

    pulsTest('Zeiten außerhalb des Trainings — am nächsten Tag nachgetragen — '
        'ergeben kein Band: Eingabezeit ist nicht Hebezeit', (tester, p) async {
      DateTime z(int minute) => vormittag(0).add(Duration(minutes: minute));
      final tagDanach = 24 * 60;
      await p.h.fuelle([
        pulsSitzung(
          'S',
          0,
          uebungen: [
            uebung(
              idBank,
              [(60, 10), (62.5, 8)],
              zeiten: [z(tagDanach + 5), z(tagDanach + 15)],
            ),
          ],
        ),
      ]);
      p.fuelleTag(0);

      await zeigeVerlaufMitPuls(tester, p);

      expect(find.byKey(kVerlaufBand('S')), findsNothing);
      expect(find.byKey(kBandGrund('S')), findsOneWidget);
      expect(
        verlaufText(tester, kPulsWert('S')),
        contains('123'),
        reason: 'Der Puls steht trotzdem — er braucht keine Satzzeiten',
      );
    });

    pulsTest('Zeitpunkte aus dem Kanal sind Ortszeit: das Band und das Ø '
        'stimmen trotzdem', (tester, p) async {
      await p.h.fuelle([pulsSitzung('S', 0, mitZeiten: true)]);
      p.fuelleTag(0, ortszeit: true);

      await zeigeVerlaufMitPuls(tester, p);

      expect(find.byKey(kVerlaufBand('S')), findsOneWidget);
      expect(find.byKey(kBandAbschnitt('S', 1)), findsOneWidget);
      expect(verlaufText(tester, kUebungPuls('S', idBank)), contains('Ø 120'));
    });
  });

  group('Dieselbe Form', () {
    pulsTest('eine Übungszeile ist gleich hoch, mit Ø und Ziffer oder ohne',
        (tester, p) async {
      await p.h.fuelle([
        pulsSitzung('A', 0, mitZeiten: true), // Band, Ziffern, Ø
        pulsSitzung('B', 1), // kein Band
      ]);
      p.fuelleTag(0);
      p.fuelleTag(1);

      await zeigeVerlauf(tester, p.h);
      await oeffneKarte(tester, 'B');
      await verstreiche(tester);

      expect(find.byKey(kUebungPuls('A', idBank)), findsOneWidget);
      expect(find.byKey(kUebungPuls('B', idBank)), findsNothing);
      for (final uid in [idBank, idSchraeg, idDips, idSeitheben]) {
        expect(
          tester.getSize(find.byKey(kVerlaufUebung('A', uid))).height,
          tester.getSize(find.byKey(kVerlaufUebung('B', uid))).height,
          reason:
              '$uid: Ziffer und Ø nehmen keinen Platz, den die Zeile sonst '
              'nicht hätte — sonst wächst die Karte, sobald Satzzeiten da sind',
        );
      }
    });
  });
}
