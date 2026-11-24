import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für **die Tagesgrenzen des Schnappschusses** — Nachtrag zu
/// `recovery_snapshot_test.dart` (#112) nach einem Review-Befund vom
/// 27.10.2026.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden.
///
/// ## Der Befund
///
/// `RecoverySnapshot.make` normalisiert in `inWindow` über
/// `BerlinCalendar.startOfDay`, vergleicht in `dayOf` und `nightOf` aber
/// **rohe** `DateTime`-Werte mit `==`. Ein `RecoveryDay`, dessen `date`
/// irgendein anderer Zeitpunkt desselben Berliner Kalendertags ist, landet
/// damit in `days`/`nights` — ist für `night`, `score` und `reading`
/// aber unsichtbar:
///
/// ```dart
/// final heute = BerlinCalendar.startOfDay(DateTime.utc(2026, 6, 17));
/// final roh = DateTime.utc(2026, 6, 17); // derselbe Berliner Tag
/// RecoverySnapshot.make(
///   days: [RecoveryDay(date: roh, restingHeartRate: 60)],
///   nights: [RecoveryNight(date: roh, asleepMinutes: 420)],
///   today: heute, sleepGoalHours: 8, bedtimeGoalMinutes: 270,
/// );
/// // days = 1, nights = 1 — aber night = null, reading = alles null,
/// // verdict = RecoveryVerdict.noData.
/// ```
///
/// Das ist Fehler `01` in Reinform — **Daten sind da, und die Rechnung sagt
/// „keine Werte"** —, und zwar unterhalb von `Messwert<T>`, wo der
/// sealed-Typ ihn nicht mehr sehen kann. Gehalten wurde die Zusicherung
/// bisher allein von einem Doc-Kommentar in `recovery_input.dart` („`date`
/// ist der Berliner Tagesbeginn"); `CLAUDE.md` sagt dazu: Ein Doc-Kommentar,
/// der zusichert, was der Code nicht durchsetzt, ist schlimmer als gar
/// keiner. Die bestehenden Tests fangen es nicht ab, weil **jeder** von
/// ihnen seine Daten über `BerlinCalendar.startOfDay` baut.
///
/// Die Falle schnappt beim Verdrahten zu (#115): Wer die Tageswerte des
/// Caches auf `RecoveryDay` abbildet und dabei den Tagesschlüssel über
/// `DateTime.parse('2026-06-17')` in ein Datum zurückverwandelt, bekommt
/// genau diesen Fall.
///
/// ## Was diese Tests verbindlich vorgeben
///
/// **Keine Signaturänderung.** `RecoverySnapshot.make` bleibt, wie es ist.
/// Verlangt wird nur, dass die Zuordnung „gehört dieser Wert zu diesem
/// Kalendertag?" **überall** über `BerlinCalendar` läuft, nicht nur in
/// `inWindow`. Der naheliegende Weg ist, `days` und `nights` beim Eintritt
/// einmal auf den Berliner Tagesbeginn zu normalisieren — dann stimmen
/// `dayOf`, `nightOf`, `baselineBefore`, `weekMinutes`, `lastSeen` und die
/// Datumsangaben in `signalHistory` von selbst, und die Zusicherung des
/// Doc-Kommentars gilt als Eigenschaft des Ergebnisses statt als Bitte an
/// den Aufrufer. Welcher Weg genommen wird, entscheidet die Umsetzung; die
/// Tests unten prüfen nur das Ergebnis.
///
/// Daraus folgt eine beobachtbare Zusage, die vorher keine war:
/// **`days`, `nights`, `signalHistory` und `lastSeen` tragen Berliner
/// Tagesgrenzen**, egal was hereingereicht wurde. Ein Diagramm, das aus
/// `days` seine x-Achse baut, bekommt damit gleich lange Abstände statt
/// krummer Zeitpunkte.
///
/// ## Was absichtlich nicht geprüft wird
///
/// - **Zwei Einträge für denselben Berliner Tag.** Nach der Normalisierung
///   tragen sie dasselbe Datum. Ob dann der erste, der letzte oder eine
///   Zusammenfassung gewinnt, ist eine Entscheidung über Daten, die der
///   Kanal so gar nicht liefert — sie hier zu erfinden hieße, eine Regel
///   festzuschreiben, die niemand gebraucht hat.
/// - **Nicht-UTC-`DateTime`-Werte** (etwa aus `DateTime.parse('2026-06-17')`,
///   das eine **lokale** Zeit liefert). Ihr Berliner Kalendertag hängt von
///   der Zeitzone der Maschine ab, auf der der Test läuft — eine Erwartung
///   darauf wäre in Koblenz grün und in Tokio rot. Geprüft werden deshalb
///   ausschließlich UTC-Zeitpunkte; der Lokalzeit-Fall ist ein Grund für
///   den Befund, kein Testfall.
///
/// **Alle Zahlen hier sind erfunden.**
void main() {
  // 17.06.2026, ein Mittwoch. Sommerzeit: Der Berliner Tag beginnt um
  // 2026-06-16T22:00Z und endet um 2026-06-17T22:00Z.
  final heute = BerlinCalendar.startOfDay(DateTime.utc(2026, 6, 17, 12));

  // 22:30 als Schlafenszeitziel, wie in `recovery_snapshot_test.dart`.
  final zielBett = EveningClock.minutesSinceEveningOfClock(
    hour: 22,
    minute: 30,
  );

  RecoverySnapshot bauen({
    List<RecoveryDay> days = const [],
    List<RecoveryNight> nights = const [],
    DateTime? today,
  }) => RecoverySnapshot.make(
    days: days,
    nights: nights,
    today: today ?? heute,
    sleepGoalHours: 8,
    bedtimeGoalMinutes: zielBett,
  );

  group(
    'Ein roher Zeitstempel desselben Berliner Tages wird gefunden, nicht '
    'nur mitgezählt (Fehler 01)',
    () {
      test(
        'Mitternacht UTC: die Nacht von heute ist die heutige Nacht, und '
        'die Tageswerte von heute stehen im reading',
        () {
          // 2026-06-17T00:00Z ist in Berlin der 17.06., 02:00 Uhr — genau
          // der Wert, den `DateTime.utc(jahr, monat, tag)` aus einem
          // Tagesschlüssel macht.
          final roh = DateTime.utc(2026, 6, 17);
          expect(
            BerlinCalendar.dayKey(roh),
            BerlinCalendar.dayKey(heute),
            reason: 'Vorbedingung: derselbe Berliner Kalendertag',
          );

          final schnappschuss = bauen(
            days: [
              RecoveryDay(
                date: roh,
                restingHeartRate: 60,
                hrv: 50,
                respiratoryRate: 14,
              ),
            ],
            nights: [RecoveryNight(date: roh, asleepMinutes: 420)],
          );

          expect(
            schnappschuss.night?.asleepMinutes,
            420,
            reason:
                'die Nacht liegt in `nights` — sie darf nicht gleichzeitig '
                'als "keine heutige Nacht" gelten',
          );
          expect(schnappschuss.score, isNotNull);
          expect(schnappschuss.reading.sleepHours, 7.0);
          expect(schnappschuss.reading.restingHeartRate, 60);
          expect(schnappschuss.reading.hrv, 50);
          expect(schnappschuss.reading.respiratoryRate, 14);
          expect(
            schnappschuss.evaluation.verdict,
            isNot(RecoveryVerdict.noData),
            reason:
                'vier gemessene Werte liegen vor. "Keine Daten" wäre hier '
                'genau der Fehler, gegen den der Umbau gebaut ist',
          );
          expect(schnappschuss.evaluation.measuredCount, 4);
        },
      );

      test('Mittag UTC trifft denselben Berliner Tag', () {
        final roh = DateTime.utc(2026, 6, 17, 12);

        final schnappschuss = bauen(
          days: [RecoveryDay(date: roh, hrv: 55)],
          nights: [RecoveryNight(date: roh, asleepMinutes: 480)],
        );

        expect(schnappschuss.night?.asleepMinutes, 480);
        expect(schnappschuss.reading.hrv, 55);
        expect(schnappschuss.reading.sleepHours, 8.0);
      });

      test(
        'am Zeitumstellungstag zählen beide Enden des 25-Stunden-Tages zum '
        'selben Berliner Tag',
        () {
          // 25.10.2026: Die Sommerzeit endet um 01:00 UTC. Der Berliner Tag
          // beginnt um 2026-10-24T22:00Z (00:00 MESZ) und endet um
          // 2026-10-25T23:00Z (00:00 MEZ) — 25 Stunden.
          final tagsUeberDieUmstellung = BerlinCalendar.startOfDay(
            DateTime.utc(2026, 10, 25, 12),
          );
          // 00:30 Berliner Zeit, noch Sommerzeit.
          final frueh = DateTime.utc(2026, 10, 24, 22, 30);
          // 23:30 Berliner Zeit, schon Winterzeit.
          final spaet = DateTime.utc(2026, 10, 25, 22, 30);

          expect(
            [BerlinCalendar.dayKey(frueh), BerlinCalendar.dayKey(spaet)],
            ['2026-10-25', '2026-10-25'],
            reason:
                'Vorbedingung: beide Zeitpunkte liegen im selben Berliner '
                'Kalendertag, obwohl sie 25 Stunden auseinanderliegen',
          );

          final schnappschuss = bauen(
            today: tagsUeberDieUmstellung,
            days: [RecoveryDay(date: frueh, restingHeartRate: 58)],
            nights: [RecoveryNight(date: spaet, asleepMinutes: 450)],
          );

          expect(schnappschuss.reading.restingHeartRate, 58);
          expect(schnappschuss.night?.asleepMinutes, 450);
          expect(schnappschuss.reading.sleepHours, 7.5);
        },
      );

      test(
        'der Tag davor bleibt der Tag davor — die Normalisierung zieht '
        'nichts in den heutigen Tag hinein, was nicht hineingehört',
        () {
          // 2026-06-16T22:30Z ist in Berlin bereits der 17.06., 00:30 Uhr.
          // 2026-06-16T21:30Z ist noch der 16.06., 23:30 Uhr.
          final nochGestern = DateTime.utc(2026, 6, 16, 21, 30);

          final schnappschuss = bauen(
            days: [RecoveryDay(date: nochGestern, hrv: 70)],
            nights: [
              RecoveryNight(date: nochGestern, asleepMinutes: 400),
            ],
          );

          expect(schnappschuss.reading.hrv, isNull);
          expect(schnappschuss.night, isNull);
          expect(
            schnappschuss.days,
            hasLength(1),
            reason: 'im Fenster liegt der Tag weiterhin',
          );
        },
      );
    },
  );

  group(
    'Die Baseline trennt heute von den Tagen davor auch bei rohen '
    'Zeitstempeln',
    () {
      test(
        'der heutige Wert steht nicht in seinem eigenen Median, und die '
        'fünf Tage davor stehen drin',
        () {
          // Fünf Tage davor mit auseinanderliegenden HRV-Werten: Der Median
          // ist 30. Zählte der heutige Wert (200) mit, wären es sechs Werte
          // und der Median läge bei 40 — die beiden Fälle sind
          // unterscheidbar, anders als bei lauter gleichen Werten.
          final schnappschuss = bauen(
            days: [
              RecoveryDay(date: DateTime.utc(2026, 6, 12), hrv: 10),
              RecoveryDay(date: DateTime.utc(2026, 6, 13), hrv: 20),
              RecoveryDay(date: DateTime.utc(2026, 6, 14), hrv: 30),
              RecoveryDay(date: DateTime.utc(2026, 6, 15), hrv: 40),
              RecoveryDay(date: DateTime.utc(2026, 6, 16), hrv: 50),
              RecoveryDay(date: DateTime.utc(2026, 6, 17), hrv: 200),
            ],
          );

          expect(schnappschuss.reading.hrv, 200);
          expect(
            schnappschuss.baseline.hrv,
            30,
            reason:
                'Regel 1 des Schnappschusses: Der heutige Wert gehört nicht '
                'in seinen eigenen Median — sonst zieht ein Ausreißer seine '
                'eigene Schwelle mit sich',
          );
        },
      );

      test(
        'die Nacht von heute zählt nicht in den Schlaf-Median von heute',
        () {
          final schnappschuss = bauen(
            nights: [
              RecoveryNight(date: DateTime.utc(2026, 6, 12), asleepMinutes: 360),
              RecoveryNight(date: DateTime.utc(2026, 6, 13), asleepMinutes: 420),
              RecoveryNight(date: DateTime.utc(2026, 6, 14), asleepMinutes: 480),
              RecoveryNight(date: DateTime.utc(2026, 6, 15), asleepMinutes: 540),
              RecoveryNight(date: DateTime.utc(2026, 6, 16), asleepMinutes: 600),
              RecoveryNight(date: DateTime.utc(2026, 6, 17), asleepMinutes: 60),
            ],
          );

          expect(schnappschuss.reading.sleepHours, 1.0);
          expect(schnappschuss.baseline.sleepHours, 8.0);
        },
      );
    },
  );

  group('Listen und Signalband stehen auf Berliner Tagesgrenzen', () {
    test(
      'days und nights tragen den Tagesbeginn, nicht den hereingereichten '
      'Zeitpunkt',
      () {
        final schnappschuss = bauen(
          days: [
            RecoveryDay(date: DateTime.utc(2026, 6, 16), hrv: 50),
            RecoveryDay(date: DateTime.utc(2026, 6, 17, 12), hrv: 55),
          ],
          nights: [
            RecoveryNight(date: DateTime.utc(2026, 6, 17), asleepMinutes: 420),
          ],
        );

        expect(
          schnappschuss.days.map((d) => d.date).toList(),
          [
            BerlinCalendar.startOfDay(DateTime.utc(2026, 6, 16, 12)),
            heute,
          ],
          reason:
              'ein Diagramm, das aus `days` seine x-Achse baut, braucht '
              'gleich lange Abstände — nicht die krummen Zeitpunkte, die '
              'zufällig hereingereicht wurden',
        );
        expect(schnappschuss.nights.single.date, heute);
      },
    );

    test('die Datumsangaben des Signalbands sind Tagesgrenzen', () {
      final schnappschuss = bauen(
        days: [
          for (var i = 5; i >= 1; i--)
            RecoveryDay(date: DateTime.utc(2026, 6, 17 - i), hrv: 100),
          RecoveryDay(date: DateTime.utc(2026, 6, 17), hrv: 10),
        ],
      );

      expect(
        schnappschuss.signalHistory.map((e) => e.date).toList(),
        [
          for (var i = 5; i >= 0; i--)
            BerlinCalendar.startOfDay(DateTime.utc(2026, 6, 17 - i, 12)),
        ],
        reason:
            'sonst zeigt das Band von gestern auf einen anderen Zeitpunkt '
            'als die Ampel von gestern',
      );
      // Das Band selbst rechnet weiter richtig — der Median der Tage davor
      // steht bei 100, und 10 liegt unter 100 · 0,8.
      expect(schnappschuss.signalHistory.last.count, 1);
      expect(schnappschuss.signalHistory.last.measured, isTrue);
    });

    test('lastSeen ist eine Tagesgrenze, kein roher Zeitstempel', () {
      final schnappschuss = bauen(
        days: [
          RecoveryDay(date: DateTime.utc(2026, 6, 15, 9), hrv: 50),
          RecoveryDay(date: DateTime.utc(2026, 6, 17)),
        ],
      );

      expect(
        schnappschuss.reading,
        const RecoveryReading(),
        reason: 'Vorbedingung: heute liegt nichts vor',
      );
      expect(
        schnappschuss.lastSeen,
        BerlinCalendar.startOfDay(DateTime.utc(2026, 6, 15, 12)),
      );
    });

    test(
      'die Wochenlast zählt einen rohen Zeitstempel in die richtige Woche',
      () {
        // Montag, 15.06.2026 — der Beginn der Woche, in der der 17.06.
        // liegt. 2026-06-14T22:30Z ist in Berlin bereits Montag, 00:30 Uhr;
        // roh verglichen fiele der Tag in die Vorwoche.
        final montagFrueh = DateTime.utc(2026, 6, 14, 22, 30);

        final schnappschuss = bauen(
          days: [RecoveryDay(date: montagFrueh, exerciseMinutes: 45)],
        );

        expect(schnappschuss.weekMinutes, 45);
      },
    );
  });
}
