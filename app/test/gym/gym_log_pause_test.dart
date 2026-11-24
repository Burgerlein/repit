import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'log_support.dart';

/// Die **Pausenuhr** des Schirms „Training eintragen" (#78): wo sie steht
/// und was sie anzeigt. Nicht die Mitteilung „Pause vorbei" — die ist ein
/// eigener Schritt.
///
/// Grundlage ist
/// `docs/superpowers/specs/2026-11-10-gym-training-eintragen-design.md`,
/// Abschnitte 7.1, 7.2 und 17.3. Hülle und API stehen in `log_support.dart`.
///
/// Geschrieben aus der Spec, **ohne** den späteren Schirm gesehen zu haben.
///
/// ## Worauf diese Datei zielt
///
/// **Die Uhr rechnet gegen die Uhr, nicht gegen einen Zähler** (Spec 7.1,
/// die wichtigste Zeile der ganzen Pausenuhr): Sie merkt sich den
/// Startzeitpunkt, nicht die abgelaufenen Sekunden. Ein hochgezählter Stand
/// stünde still, sobald die App in den Hintergrund geht, und zeigte danach
/// eine zu kurze Pause an.
///
/// Geprüft wird das so: Die Test-Uhr ([Uhr]) wird um 90 s vorgestellt, es
/// läuft **ein** Anzeigetakt, und die Anzeige muss um 90 s weitergesprungen
/// sein — ein Zähler stünde nach einem Takt bei einer halben Sekunde.
///
/// **Es gibt genau eine Uhr, und sie steht in der Übung, in der man gerade
/// ist** — der ersten noch nicht erledigten, derselben, bei der das Vollbild
/// aufgeht (Spec 7.1).
///
/// ## Der Takt
///
/// Der 500-ms-Takt läuft hier **echt**, in der Zeit des Widget-Tests:
/// `tester.pump(Duration)` löst ihn aus, und beim Abbauen (`abbauen` in
/// `log_support.dart`) verschwindet er mit dem Schirm — sonst endete jeder
/// Test mit „A Timer is still pending" (Spec 7.2).
///
/// ## Was hier nicht geprüft wird
///
/// Dass der Takt nicht den ganzen Schirm neu zeichnet (Spec 7.2) — das ist
/// eine Messung mit DevTools, kein Widget-Test.
void main() {
  /// Bankdrücken hat `repHigh` 10: Die empfohlene Pause ist 150 s.
  final ziel = RestGuidance.seconds(ExerciseCatalog.all[idBank]!);

  /// Lässt einen Anzeigetakt laufen.
  Future<void> takt(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 600));
  }

  group('Wo die Uhr steht', () {
    logTest('genau eine Pausenzeile im ganzen Training, in der ersten '
        'unfertigen Übung', (tester, h) async {
      await zeigeLog(tester, h);

      expect(
        find.byKey(kPause),
        findsOneWidget,
        reason:
            'Spec 7.1: „sieben Karten mit sieben Uhren wären sieben Mal '
            'dieselbe Frage"',
      );
      expect(
        find.descendant(
          of: find.byKey(kUebung(idBank)),
          matching: find.byKey(kPause),
        ),
        findsOneWidget,
        reason: 'Zu Beginn steht sie in Übung 1',
      );
    });

    logTest('ist eine Übung fertig, wandert die Uhr in die nächste', (
      tester,
      h,
    ) async {
      await zeigeLog(tester, h);

      for (var n = 1; n <= ExerciseCatalog.all[idBank]!.sets; n++) {
        await satz(tester, idBank, n, wdh: '${12 - n}');
      }
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byKey(kPause), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(kUebung(idSchraeg)),
          matching: find.byKey(kPause),
        ),
        findsOneWidget,
        reason:
            'Spec 7.1: „In welcher Übung man gerade ist" ist die erste '
            'noch nicht erledigte — dieselbe Zahl, bei der das Vollbild '
            'aufgeht',
      );
    });

    logTest('die Zielzeit kommt aus der Übung', (tester, h) async {
      await zeigeLog(tester, h);

      expect(
        pauseSekunden(tester),
        ziel,
        reason:
            'Ohne laufende Pause steht die empfohlene Zeit da '
            '(`RestGuidance.seconds`, Spec 7.1)',
      );
    });
  });

  group('Was sie anzeigt', () {
    logTest('vor Ablauf zählt sie herunter, und sie rechnet gegen die Uhr, '
        'nicht gegen einen Zähler', (tester, h) async {
      await zeigeLog(tester, h);

      await tester.tap(find.byKey(kPauseStart));
      await tester.pump();
      expect(pauseSekunden(tester), ziel, reason: 'Gerade gestartet');

      // Die Uhr springt um 90 s — wie nach einer Minute im Hintergrund.
      h.uhr.jetzt = startzeit.add(const Duration(seconds: 90));
      await takt(tester);

      expect(
        pauseSekunden(tester),
        ziel - 90,
        reason:
            'Spec 17.3: „Prüfbar mit einer gesteuerten Zeitquelle: '
            'starten, die Uhr um 90 s vorstellen — die Anzeige zeigt 90 s '
            'verstrichen." Ein Zähler stünde nach einem Takt bei '
            '${ziel - 1}',
      );

      h.uhr.jetzt = startzeit.add(const Duration(seconds: 100));
      await takt(tester);
      expect(
        pauseSekunden(tester),
        ziel - 100,
        reason: 'Sie zählt herunter, nicht hoch',
      );
    });

    logTest('nach Ablauf zählt sie hoch, statt stehen zu bleiben', (
      tester,
      h,
    ) async {
      await zeigeLog(tester, h);
      await tester.tap(find.byKey(kPauseStart));
      await tester.pump();

      h.uhr.jetzt = startzeit.add(Duration(seconds: ziel + 50));
      await takt(tester);
      final ueberlauf = pauseSekunden(tester);
      expect(
        ueberlauf,
        50,
        reason:
            'Spec 7.1: „‚1:12‘ ist die Restzeit, danach die Zeit über '
            'der Pause" — 50 s über der Pause',
      );

      h.uhr.jetzt = startzeit.add(Duration(seconds: ziel + 60));
      await takt(tester);
      expect(
        pauseSekunden(tester),
        ueberlauf + 10,
        reason:
            'Nach Ablauf wächst die Zahl, sie fällt nicht weiter und '
            'steht nicht still',
      );
    });

    logTest('Stopp setzt die Anzeige auf die Zielzeit zurück', (
      tester,
      h,
    ) async {
      await zeigeLog(tester, h);
      await tester.tap(find.byKey(kPauseStart));
      await tester.pump();
      h.uhr.jetzt = startzeit.add(const Duration(seconds: 40));
      await takt(tester);
      expect(pauseSekunden(tester), ziel - 40, reason: 'Vorbedingung');

      await tester.tap(find.byKey(kPauseStart));
      await tester.pump();
      h.uhr.jetzt = startzeit.add(const Duration(seconds: 80));
      await takt(tester);

      expect(
        pauseSekunden(tester),
        ziel,
        reason: 'Eine angehaltene Uhr zählt nicht weiter',
      );
    });

    logTest('die Uhr gehört zum Training, nicht zur Übung: Sie läuft im '
        'Vollbild weiter', (tester, h) async {
      await zeigeLog(tester, h);
      await tester.tap(find.byKey(kPauseStart));
      await tester.pump();

      await oeffneVollbild(tester);
      h.uhr.jetzt = startzeit.add(const Duration(seconds: 30));
      await takt(tester);

      expect(
        find.byKey(kPause),
        findsOneWidget,
        reason:
            'Spec 7.1: „Läge sie im Vollbild, stünde sie still, sobald '
            'man es verlässt"',
      );
      expect(
        pauseSekunden(tester),
        ziel - 30,
        reason:
            'Dieselbe Uhr, im Vollbild gelesen — sie wurde in der '
            'Erfassung gestartet',
      );

      await tester.tap(find.byKey(kVollbildSchliessen));
      await verstreiche(tester);
      expect(pauseSekunden(tester), ziel - 30);
    });
  });
}
