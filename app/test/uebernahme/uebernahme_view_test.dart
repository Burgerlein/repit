import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/gym/gym_verlauf_provider.dart'
    show gymSitzungenProvider;

import 'export_fixtur.dart';
import 'uebernahme_support.dart';

/// Die **Zustände und Übergänge** des Schirms „Daten übernehmen" (#59 Teil 1,
/// mit #482) und die beiden Anforderungen, auf die es nach `CLAUDE.md`
/// ankommt. Hülle, Schlüssel und API stehen in `uebernahme_support.dart`.
///
/// Geschrieben aus `docs/superpowers/specs/2026-11-11-gym-uebernahme-design.md`,
/// Abschnitte 7 bis 9, **ohne** den späteren Schirm gesehen zu haben. Geprüft
/// werden Zustände und Übergänge, **nicht** Beschriftung und Layout.
///
/// ## Die beiden Pflichtfälle
///
/// 1. **Eine Zahl, die es nicht gibt, steht nicht als `0` da** (Fehler `01`).
///    Vor dem ersten Lauf, während des Laufs und nach einer abgelehnten oder
///    gescheiterten Übernahme sind alle fünf Wertplätze ungefüllt (`–/–`):
///    „0 Trainings in der Datei" behauptete, die Datei sei leer gewesen.
///    Eine `0` nach einem **gelaufenen** Lauf ist dagegen eine Antwort.
/// 2. **Was dastand, steht nach dem Zurücknavigieren wieder da** (Fehler
///    `32`): Das Ergebnis liegt im Provider, nicht im Widget.
///
/// ## Dazu
///
/// Eine abgelehnte Datei wird **benannt**; ein selbst eingetragenes
/// Training überlebt den Lauf (#482); zweimal dieselbe Datei verdoppelt
/// nichts; der Knopf lässt sich während des Laufs nicht ein zweites Mal
/// auslösen.
void main() {
  Uint8List dreiTrainings() => alsBytes(
    exportDatei(
      sitzungen: [
        rohSitzung(id: 'S-A', datum: zeit(10), workout: 'A'),
        rohSitzung(id: 'S-B', datum: zeit(12), workout: 'B'),
        rohSitzung(id: 'S-C', datum: zeit(14), workout: 'C'),
      ],
    ),
  );

  group('vor dem ersten Lauf', () {
    uebernahmeTest('genau die Leer-Meldung steht, die Zahlen sind ungefüllt, '
        'der Knopf und der Hinweis stehen da', (tester, h) async {
      await zeigeUebernahme(tester, h);

      expect(stehendeMeldungen(), [kUebernahmeLeer]);
      expect(find.byKey(kUebernahmeErgebnis), findsOneWidget);
      erwarteUngefuellt(tester);
      expect(find.byKey(kUebernahmeWaehlen), findsOneWidget);
      expect(find.byKey(kUebernahmeUmfang), findsOneWidget);
      expect(find.byKey(kUebernahmeUnbekannt), findsNothing);
      expect(find.byKey(kUebernahmeUngelesen), findsNothing);
      expect(find.byKey(kUebernahmeZeitzone), findsNothing);
      expect(h.waehler.aufrufe, 0, reason: 'Der Schirm wählt nicht von selbst');
      expect(h.ablage.uebernahmen, 0);
    });

    uebernahmeTest('Abbruch der Auswahl: Es ändert sich nichts', (
      tester,
      h,
    ) async {
      await zeigeUebernahme(tester, h);
      h.waehler.naechste = null;

      await waehle(tester);

      expect(h.waehler.aufrufe, 1);
      expect(stehendeMeldungen(), [kUebernahmeLeer]);
      erwarteUngefuellt(tester);
      expect(h.ablage.uebernahmen, 0);
      expect(await h.sitzungen(), isEmpty);
    });
  });

  group('Pflicht 1 — während des Laufs steht keine Zahl (`01`)', () {
    uebernahmeTest('läuft: nur die Läuft-Meldung, die Zahlen ungefüllt, der '
        'Knopf löst nicht ein zweites Mal aus', (tester, h) async {
      await zeigeUebernahme(tester, h);
      h.waehleDatei(dreiTrainings());
      h.ablage.tor = Completer<void>();

      await waehle(tester);

      expect(stehendeMeldungen(), [kUebernahmeLaeuft]);
      erwarteUngefuellt(tester, warum: 'Während geschrieben wird:');
      expect(find.byKey(kUebernahmeWaehlen), findsOneWidget);

      await tester.tap(find.byKey(kUebernahmeWaehlen), warnIfMissed: false);
      await verstreiche(tester);
      expect(h.waehler.aufrufe, 1, reason: 'kein zweiter Lauf neben dem ersten');
      expect(h.ablage.uebernahmen, 1);

      h.ablage.tor!.complete();
      await verstreiche(tester);

      expect(stehendeMeldungen(), [kUebernahmeFertig]);
      expect(zahlText(tester, kZahlNeu), '3');
      expect(h.ablage.uebernahmen, 1);
      expect((await h.sitzungen()).length, 3);
    });
  });

  group('eine gute Datei', () {
    uebernahmeTest('Die Zahlen stehen da und gehen auf', (tester, h) async {
      await zeigeUebernahme(tester, h);
      h.waehleDatei(dreiTrainings());

      await waehle(tester);

      expect(stehendeMeldungen(), [kUebernahmeFertig]);
      expect(zahlText(tester, kZahlInDatei), '3');
      expect(zahlText(tester, kZahlNeu), '3');
      expect(zahlText(tester, kZahlSchonDa), '0');
      expect(zahlText(tester, kZahlNichtUebernommen), '0');
      expect(zahlText(tester, kZahlNichtLesbar), '0');
      expect((await h.sitzungen()).length, 3);
    });

    uebernahmeTest('Die Übernahme erreicht den Rest der App: '
        '`gymSitzungenProvider` kennt die neuen Trainings', (tester, h) async {
      // Sonst zeigte der Verlauf weiter „noch nichts da", obwohl die
      // Übernahme „3 neu" gemeldet hat.
      expect(await h.container.read(gymSitzungenProvider.future), isEmpty);
      await zeigeUebernahme(tester, h);
      h.waehleDatei(dreiTrainings());

      await waehle(tester);

      final liste = await h.container.read(gymSitzungenProvider.future);
      expect(liste.map((s) => s.id), ['S-C', 'S-B', 'S-A']);
    });

    uebernahmeTest('Nicht lesbare Sitzungen stehen mit ihrer Position da, die '
        'übrigen werden übernommen', (tester, h) async {
      await zeigeUebernahme(tester, h);
      h.waehleDatei(
        alsBytes(
          exportDatei(
            sitzungen: [
              rohSitzung(id: 'GUT', datum: zeit(10), workout: 'A'),
              rohSitzung(id: 'KAPUTT', datum: 'nie', workout: 'B'),
            ],
          ),
        ),
      );

      await waehle(tester);

      expect(zahlText(tester, kZahlInDatei), '2');
      expect(zahlText(tester, kZahlNeu), '1');
      expect(zahlText(tester, kZahlNichtLesbar), '1');
      expect(find.byKey(kUebernahmeNichtLesbar(1)), findsOneWidget);
      expect(find.byKey(kUebernahmeNichtLesbar(0)), findsNothing);
    });

    uebernahmeTest('Unbekannte Übungen und Workouts werden genannt', (
      tester,
      h,
    ) async {
      await zeigeUebernahme(tester, h);
      h.waehleDatei(
        alsBytes(
          exportDatei(
            sitzungen: [
              rohSitzung(
                id: 'S-X',
                datum: zeit(10),
                workout: 'gymA',
                uebungen: [
                  rohUebung('ghostLift', [rohSatz(10, 10)]),
                ],
              ),
            ],
          ),
        ),
      );

      await waehle(tester);

      expect(find.byKey(kUebernahmeUnbekannt), findsOneWidget);
      final text = meldungText(tester, kUebernahmeUnbekannt);
      expect(text, contains('ghostLift'));
      expect(text, contains('gymA'));
    });

    uebernahmeTest('Ohne Unbekanntes steht der Hinweis nicht da', (
      tester,
      h,
    ) async {
      await zeigeUebernahme(tester, h);
      h.waehleDatei(dreiTrainings());

      await waehle(tester);

      expect(find.byKey(kUebernahmeUnbekannt), findsNothing);
    });

    uebernahmeTest('Stände, die dieser Schritt nicht liest, werden benannt', (
      tester,
      h,
    ) async {
      await zeigeUebernahme(tester, h);
      h.waehleDatei(
        alsBytes(
          exportDatei(
            sitzungen: [rohSitzung(id: 'S-A', datum: zeit(10), workout: 'A')],
            uebrige: {
              'swaps': [
                {'week': 3, 'first': 'Di', 'second': 'Do'},
              ],
              'dashboardImport': [
                {
                  'sessions': [
                    for (var i = 0; i < 7; i++)
                      rohSitzung(id: 'D$i', datum: zeit(i + 1)),
                  ],
                  'scales': <Object?>[],
                  'circumferences': <Object?>[],
                },
              ],
            },
          ),
        ),
      );

      await waehle(tester);

      expect(find.byKey(kUebernahmeUngelesen), findsOneWidget);
      expect(
        meldungText(tester, kUebernahmeUngelesen),
        contains('7'),
        reason: 'Die Zahl der Dashboard-Sitzungen steht da — damit niemand '
            'den Verlauf für vollständig hält',
      );
    });

    uebernahmeTest('Ohne ungelesene Stände steht der Hinweis nicht da', (
      tester,
      h,
    ) async {
      await zeigeUebernahme(tester, h);
      h.waehleDatei(dreiTrainings());

      await waehle(tester);

      expect(find.byKey(kUebernahmeUngelesen), findsNothing);
    });

    uebernahmeTest('Eine andere Zeitzone als Berlin wird gemeldet, Berlin '
        'nicht', (tester, h) async {
      await zeigeUebernahme(tester, h);
      h.waehleDatei(dreiTrainings());
      await waehle(tester);
      expect(find.byKey(kUebernahmeZeitzone), findsNothing);

      h.waehleDatei(
        alsBytes(
          exportDatei(
            zone: 'America/New_York',
            sitzungen: [rohSitzung(id: 'S-N', datum: zeit(20), workout: 'D')],
          ),
        ),
      );
      await waehle(tester);

      expect(find.byKey(kUebernahmeZeitzone), findsOneWidget);
      expect(meldungText(tester, kUebernahmeZeitzone), contains('New_York'));
    });
  });

  group('zweimal dieselbe Datei verdoppelt nichts', () {
    uebernahmeTest('der zweite Lauf: nichts neu, alles schon da, die '
        'Ablage unverändert', (tester, h) async {
      await zeigeUebernahme(tester, h);
      h.waehleDatei(dreiTrainings());
      await waehle(tester);
      final vorher = await h.sitzungen();

      await waehle(tester);

      expect(stehendeMeldungen(), [kUebernahmeFertig]);
      expect(zahlText(tester, kZahlInDatei), '3');
      expect(
        zahlText(tester, kZahlNeu),
        '0',
        reason: 'Nach einem gelaufenen Lauf ist die `0` eine Antwort',
      );
      expect(zahlText(tester, kZahlSchonDa), '3');
      expect(await h.sitzungen(), vorher);
    });
  });

  group('#482 — ein selbst eingetragenes Training bleibt', () {
    uebernahmeTest('Die Sitzung der Datei wird genannt und übersprungen; das '
        'Eigene steht danach unverändert da', (tester, h) async {
      final eigen = ImportedSession(
        id: 'EIGEN',
        date: DateTime.utc(2099, 1, 14, 9, 40),
        workout: Workout.a,
        minutes: 61,
        note: 'Erfundene Notiz',
        warmUp: const WarmUpDone(kind: WarmUpKind.bike, minutes: 8, km: 2.5),
        exercises: [
          ImportedExercise(
            exerciseId: 'benchPress',
            sets: [
              CompletedSet(
                weight: 65,
                reps: 6,
                recordedAt: DateTime.utc(2099, 1, 14, 9, 12),
              ),
            ],
          ),
        ],
      );
      await h.fuelle([eigen]);
      await zeigeUebernahme(tester, h);
      h.waehleDatei(
        alsBytes(
          exportDatei(
            sitzungen: [
              rohSitzung(id: 'ALT', datum: '2099-01-13T23:00:00Z', workout: 'A'),
              rohSitzung(id: 'S-B', datum: zeit(16), workout: 'B'),
            ],
          ),
        ),
      );

      await waehle(tester);

      expect(zahlText(tester, kZahlNeu), '1');
      expect(zahlText(tester, kZahlNichtUebernommen), '1');
      expect(find.byKey(kUebernahmeAuslassung('ALT')), findsOneWidget);
      expect(find.byKey(kUebernahmeAuslassung('S-B')), findsNothing);
      final liste = await h.sitzungen();
      expect(liste.firstWhere((s) => s.id == 'EIGEN'), eigen);
      expect(liste.any((s) => s.id == 'ALT'), isFalse);
    });
  });

  group('eine Datei, die nicht gelesen wird — benannt, nichts geschrieben', () {
    uebernahmeTest('Fremdes Format: Der Grund nennt, was stattdessen dastand; '
        'die Zahlen bleiben ungefüllt (keine `0`)', (tester, h) async {
      await zeigeUebernahme(tester, h);
      h.waehleDatei(
        alsBytes(
          exportDatei(
            format: 'dashboard-manual-export',
            sitzungen: [rohSitzung(id: 'S-A', datum: zeit(10), workout: 'A')],
          ),
        ),
      );

      await waehle(tester);

      expect(stehendeMeldungen(), [kUebernahmeAbgelehnt]);
      expect(
        meldungText(tester, kUebernahmeAbgelehnt),
        contains('dashboard-manual-export'),
      );
      erwarteUngefuellt(tester, warum: 'Nach einer abgelehnten Datei:');
      expect(h.ablage.uebernahmen, 0);
      expect(await h.sitzungen(), isEmpty);
      expect(find.byKey(kUebernahmeWaehlen), findsOneWidget);
    });

    uebernahmeTest('Fassung 1: abgelehnt, die gefundene und die gelesene '
        'Fassung stehen im Grund', (tester, h) async {
      await zeigeUebernahme(tester, h);
      h.waehleDatei(alsBytes(fassungEins()));

      await waehle(tester);

      expect(stehendeMeldungen(), [kUebernahmeAbgelehnt]);
      final text = meldungText(tester, kUebernahmeAbgelehnt);
      expect(text, matches(RegExp(r'\b1\b')), reason: 'die gefundene Fassung');
      expect(text, matches(RegExp(r'\b2\b')), reason: 'die lesbare Fassung');
      erwarteUngefuellt(tester);
      expect(await h.sitzungen(), isEmpty);
    });

    uebernahmeTest('Kaputtes JSON: eine Meldung, kein Absturz, kein halber '
        'Import', (tester, h) async {
      await zeigeUebernahme(tester, h);
      final voll = alsBytes(
        exportDatei(
          sitzungen: [
            rohSitzung(id: 'S-A', datum: zeit(10), workout: 'A'),
            rohSitzung(id: 'S-B', datum: zeit(12), workout: 'B'),
          ],
        ),
      );
      h.waehleDatei(Uint8List.sublistView(voll, 0, voll.length ~/ 2));

      await waehle(tester);

      expect(tester.takeException(), isNull);
      expect(stehendeMeldungen(), [kUebernahmeAbgelehnt]);
      expect(meldungText(tester, kUebernahmeAbgelehnt), isNotEmpty);
      erwarteUngefuellt(tester);
      expect(await h.sitzungen(), isEmpty);
    });

    uebernahmeTest('Danach geht eine gute Datei: Die Ablehnung verschwindet', (
      tester,
      h,
    ) async {
      await zeigeUebernahme(tester, h);
      h.waehleDatei(alsBytes(fassungEins()));
      await waehle(tester);
      expect(stehendeMeldungen(), [kUebernahmeAbgelehnt]);

      h.waehleDatei(dreiTrainings());
      await waehle(tester);

      expect(stehendeMeldungen(), [kUebernahmeFertig]);
      expect(zahlText(tester, kZahlNeu), '3');
    });
  });

  group('die Ablage scheitert', () {
    uebernahmeTest('Eine eigene Meldung, Zahlen ungefüllt, nichts geschrieben '
        '— und ein zweiter Versuch geht', (tester, h) async {
      await zeigeUebernahme(tester, h);
      h.waehleDatei(dreiTrainings());
      h.ablage.scheitert = true;

      await waehle(tester);

      expect(tester.takeException(), isNull);
      expect(stehendeMeldungen(), [kUebernahmeGescheitert]);
      erwarteUngefuellt(tester, warum: 'Nach einem Schreibfehler:');
      expect(await h.sitzungen(), isEmpty);

      h.ablage.scheitert = false;
      await waehle(tester);

      expect(stehendeMeldungen(), [kUebernahmeFertig]);
      expect(zahlText(tester, kZahlNeu), '3');
    });
  });

  group('Pflicht 2 — was dastand, steht nach dem Zurücknavigieren wieder da '
      '(`32`)', () {
    uebernahmeTest('Das Ergebnis überlebt Verlassen und Wiederkommen, ohne '
        'zwischendurch zu verschwinden', (tester, h) async {
      await zeigeUebernahme(tester, h);
      h.waehleDatei(dreiTrainings());
      await waehle(tester);
      expect(zahlText(tester, kZahlNeu), '3');

      Navigator.of(tester.element(find.byKey(kUebernahmeWaehlen))).push(
        CupertinoPageRoute<void>(
          builder: (_) => const CupertinoPageScaffold(
            child: Center(child: Text('Detail', key: kHuelleDetail)),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      Navigator.of(tester.element(find.byKey(kHuelleDetail))).pop();

      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find.byKey(kUebernahmeErgebnis).evaluate().isNotEmpty) {
          expect(stehendeMeldungen(), [kUebernahmeFertig]);
          expect(zahlText(tester, kZahlNeu), '3');
          expect(zahlText(tester, kZahlInDatei), '3');
        }
      }
      expect(stehendeMeldungen(), [kUebernahmeFertig]);
    });

    uebernahmeTest('Auch nach dem Schließen und Neuöffnen des Schirms steht '
        'das Ergebnis des letzten Laufs da', (tester, h) async {
      await zeigeUebernahme(tester, h);
      h.waehleDatei(dreiTrainings());
      await waehle(tester);

      Navigator.of(tester.element(find.byKey(kUebernahmeWaehlen))).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.tap(find.byKey(kHuelleOeffnen));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(stehendeMeldungen(), [kUebernahmeFertig]);
      expect(zahlText(tester, kZahlNeu), '3');
    });
  });
}
