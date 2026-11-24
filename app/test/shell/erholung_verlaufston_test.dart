import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/design/palette.dart';
import 'package:repit/design/vital_ton.dart';
import 'package:repit/shell/erholung_abschnitte.dart';
import 'package:repit/shell/erholung_zustand.dart';

import '../design/support.dart' show huelle, textOf;

/// Die Ampel der Verlaufszeilen (Erholung-Schirm, Abschnitt 6) — neu am
/// 27.10.2026, nachdem Tim den gebauten Schirm gegen
/// `docs/screens/screens/erholung.js` gehalten hat. Der Entwurf färbt dort
/// seit demselben Tag den Wert jeder Zeile (`trendRow`, `tone`).
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden.
///
/// ## Die festgelegte API
///
/// **Seit #308 fällt die Entscheidung nicht mehr hier** (Tim, 04.11.2026):
/// Derselbe Schlafwert stand auf Heute grün und auf Erholung gelb, weil
/// zwei Funktionen dasselbe mit verschieden vielen Stufen entschieden. Die
/// Zuordnung Wert → Stufe liegt seither im Design-System
/// (`lib/design/vital_ton.dart`, beschrieben in
/// `test/design/vital_ton_test.dart`), und `VerlaufsTon` ist in `VitalTon`
/// aufgegangen — ein Aufzählungstyp, vier Stufen, `unbeurteilt` statt
/// `null`. Geblieben ist hier die Übersetzung der Zeilenart in die Metrik
/// der Ampel; die Zahlen darunter sind unverändert und stehen weiter so,
/// wie sie am 27.10.2026 festgelegt wurden.
///
/// ```dart
/// // lib/shell/erholung_zustand.dart
///
/// /// Übersetzt die Zeilenart in die Metrik der Ampel und fragt
/// /// `vitalTon`. **Entschieden wird dort**, nicht hier — die
/// /// Alkohol-Zeile hat keine Metrik und bleibt deshalb ungefärbt.
/// VitalTon verlaufsTon({
///   required RecoveryTrendKind art,
///   required RecoveryReading messwerte,
///   required RecoveryBaseline baseline,
///   required RecoveryEvaluation? bewertung,
/// });
/// ```
///
/// Eine **reine Funktion**, kein Widget und kein Feld auf einem Werttyp —
/// genau wie `erholungHinweis` daneben, und aus demselben Grund: Die Regel
/// ist eine Entscheidung, keine Darstellung, und so ist sie ohne Pixel und
/// ohne Baum prüfbar.
///
/// **Warum in `app/` und nicht in `trainings_core`:** Die Schwellen selbst
/// stehen längst im Kern (`RecoveryTrafficLight`) und werden hier nur
/// gelesen. Was hinzukommt, ist die Zuordnung „Zahl → Farbe einer Zeile" —
/// eine Aussage über die Oberfläche. `docs/SPEC.md` kennt sie nicht, also
/// ist sie auch keine Formel, die nach `CLAUDE.md` in den Kern gehörte.
///
/// ## Die Zuordnung, verbindlich
///
/// Aus `RecoveryTrafficLight` abgeleitet, wie vom Auftrag verlangt:
///
/// | Ton | Regel |
/// |---|---|
/// | **warnsignal** | die Ampel zählt diesen Wert als Warnsignal |
/// | **nahAmSignal** | noch kein Signal, aber **die halbe Strecke** zur Schwelle ist überschritten |
/// | **normal** | sonst |
/// | **unbeurteilt** | kein Messwert — oder kein Vergleichswert, gegen den sich messen ließe |
///
/// Je Metrik ausgeschrieben, mit den Konstanten des Kerns:
///
/// | Zeile | nahAmSignal ab | warnsignal ab |
/// |---|---|---|
/// | Schlaf | unter `minimumSleepHours + 0,5` h | unter `minimumSleepHours` (6 h) |
/// | Ruhepuls | ab `Median + restingHeartRateMargin / 2` | ab `Median + restingHeartRateMargin` |
/// | HRV | bis `Median · (1 + hrvFactor) / 2` | bis `Median · hrvFactor` |
/// | Atemfrequenz | ab `Median + respiratoryRateMargin / 2` | ab `Median + respiratoryRateMargin` |
/// | Alkohol-Tage | — | — |
///
/// „ab" und „bis" schließen den Wert ein, „unter" nicht — Gleichheit zählt
/// also überall dort als erreicht, wo sie es auch im Kern tut.
///
/// **Die halbe Strecke, nicht ein Viertel oder drei Viertel.** „Nah an der
/// Schwelle" ist eine Setzung; die Mitte ist die einzige Zahl, die sich
/// ohne weitere Begründung verteidigen lässt, und sie steht an **einer**
/// Stelle. Beim Schlaf gibt es keine Strecke, weil die Schwelle fest ist
/// und nicht am Median hängt — dort ist die halbe Stunde darüber das
/// Gegenstück, und das ist der eine Wert, der nicht aus dem Kern kommt.
///
/// ### Zwei Dinge, die daraus folgen und so gewollt sind
///
/// - **Rot und Warnsignal sind dasselbe.** Ein roter Wert in einer Zeile
///   heißt, dass derselbe Wert oben im Hinweiskasten als Warnsignal steht.
///   Zwei Strenge-Grade für denselben Begriff auf einem Schirm wären zwei
///   Bedeutungen, und der Nutzer müsste raten, welche gilt.
/// - **Der Schlaf-Ton hängt an der festen Sechs-Stunden-Grenze**, nicht an
///   dem Durchschnitt, der in derselben Zeile links steht („Ø 6:40 h").
///   Das ist eine bekannte Schiefe: Der Vergleichswert in der Zeile und
///   die Grundlage der Farbe sind beim Schlaf nicht derselbe Wert. Sie
///   aufzulösen hieße, entweder die Ampel des Kerns umzubauen oder in der
///   Zeile einen anderen Vergleichswert zu zeigen als der Entwurf — beides
///   ist eine eigene Entscheidung und steht hier nicht an.
///
/// ### Widerspruch zum Entwurf, gemeldet
///
/// Der Entwurf setzt seit dem 27.10.2026 drei Beispieltöne, und **zwei
/// davon passen nicht zu dieser Regel**: „Ruhepuls 68 · Median 66" ist
/// dort `low`, nach dieser Regel aber `normal` (die mittlere Stufe erst ab
/// 68,5); und „Atemfrequenz 15,2 · Normal 14,0" ist dort `warn`, nach
/// dieser Regel aber `nahAmSignal` (ein Warnsignal erst ab 15,5). Die
/// Zahlen des Boards sind laut eigenem Dateikopf erfunden und von Hand
/// gefärbt. **Hier gilt die Regel**, weil der Auftrag sie aus
/// `RecoveryTrafficLight` abzuleiten verlangt; ob stattdessen die
/// Beispielzahlen des Boards nachgezogen werden, entscheidet Tim.
///
/// ## Zahlen in dieser Datei
///
/// Alle erfunden. Die Mediane sind glatte Zahlen, damit die Schwellen im
/// Kopf nachvollziehbar bleiben.
void main() {
  const median = RecoveryBaseline(
    sleepHours: 7,
    restingHeartRate: 60,
    hrv: 50,
    respiratoryRate: 14,
  );

  /// Die Bewertung kommt aus dem Kern, nicht von Hand: Seit #308 liest
  /// die Oberfläche „Warnsignal" und „überhaupt beurteilt" dort ab, statt
  /// die Schwelle ein zweites Mal zu rechnen. Die geprüften Zahlen sind
  /// dieselben geblieben.
  VitalTon ton(
    RecoveryTrendKind art,
    RecoveryReading messwerte, {
    RecoveryBaseline baseline = median,
  }) => verlaufsTon(
    art: art,
    messwerte: messwerte,
    baseline: baseline,
    bewertung: RecoveryTrafficLight.evaluate(
      reading: messwerte,
      baseline: baseline,
    ),
  );

  group('Schlaf — feste Schwelle, kein Median nötig', () {
    const schwelle = RecoveryTrafficLight.minimumSleepHours; // 6,0

    test('deutlich darüber ist gut', () {
      expect(
        ton(RecoveryTrendKind.sleep, const RecoveryReading(sleepHours: 7.5)),
        VitalTon.normal,
      );
    });

    test('knapp darüber ist kritisch', () {
      expect(
        ton(
          RecoveryTrendKind.sleep,
          const RecoveryReading(sleepHours: schwelle + 0.25),
        ),
        VitalTon.nahAmSignal,
      );
    });

    test('genau auf der Schwelle ist noch kein Signal, aber kritisch', () {
      // `RecoveryTrafficLight`: strikt kleiner — genau sechs Stunden sind
      // kein Warnsignal.
      expect(
        ton(
          RecoveryTrendKind.sleep,
          const RecoveryReading(sleepHours: schwelle),
        ),
        VitalTon.nahAmSignal,
      );
    });

    test('darunter ist schlecht', () {
      expect(
        ton(
          RecoveryTrendKind.sleep,
          const RecoveryReading(sleepHours: schwelle - 0.01),
        ),
        VitalTon.warnsignal,
      );
    });

    test('ohne Vergleichswert bleibt es bei der festen Schwelle', () {
      expect(
        ton(
          RecoveryTrendKind.sleep,
          const RecoveryReading(sleepHours: 5),
          baseline: const RecoveryBaseline(),
        ),
        VitalTon.warnsignal,
        reason: 'der Schlaf braucht keinen Median — die Sechs-Stunden-Grenze '
            'steht fest (`docs/SPEC.md` 4.6)',
      );
    });
  });

  group('Ruhepuls — Median plus Zuschlag', () {
    const zuschlag = RecoveryTrafficLight.restingHeartRateMargin; // 5
    // Median 60: Signal ab 65, kritisch ab 62,5.

    test('auf dem Median ist gut', () {
      expect(
        ton(
          RecoveryTrendKind.restingHeartRate,
          const RecoveryReading(restingHeartRate: 60),
        ),
        VitalTon.normal,
      );
    });

    test('darunter erst recht', () {
      expect(
        ton(
          RecoveryTrendKind.restingHeartRate,
          const RecoveryReading(restingHeartRate: 54),
        ),
        VitalTon.normal,
      );
    });

    test('die halbe Strecke zur Schwelle ist kritisch', () {
      expect(
        ton(
          RecoveryTrendKind.restingHeartRate,
          const RecoveryReading(restingHeartRate: 60 + zuschlag / 2),
        ),
        VitalTon.nahAmSignal,
      );
    });

    test('auf der Schwelle ist schlecht — Gleichheit zählt', () {
      expect(
        ton(
          RecoveryTrendKind.restingHeartRate,
          const RecoveryReading(restingHeartRate: 60 + zuschlag),
        ),
        VitalTon.warnsignal,
        reason:
            '`RecoveryTrafficLight`: „Ruhepuls ab Median + Zuschlag ist ein '
            'Signal; Gleichheit zählt."',
      );
    });

    test('ohne Median gibt es keine Farbe', () {
      expect(
        ton(
          RecoveryTrendKind.restingHeartRate,
          const RecoveryReading(restingHeartRate: 80),
          baseline: const RecoveryBaseline(),
        ),
        VitalTon.unbeurteilt,
        reason:
            'ohne Vergleichswert ist der Wert weder gut noch schlecht — '
            'genau so schaltet die Ampel im Kern diese eine Metrik ab',
      );
    });
  });

  group('HRV — Median mal Faktor, und kleiner ist schlechter', () {
    // Median 50: Signal ab 40 und darunter, kritisch ab 45 und darunter.
    const faktor = RecoveryTrafficLight.hrvFactor; // 0,8

    test('über dem Median ist gut', () {
      expect(
        ton(RecoveryTrendKind.hrv, const RecoveryReading(hrv: 61)),
        VitalTon.normal,
      );
    });

    test('die halbe Strecke nach unten ist kritisch', () {
      expect(
        ton(
          RecoveryTrendKind.hrv,
          const RecoveryReading(hrv: 50 * (1 + faktor) / 2),
        ),
        VitalTon.nahAmSignal,
      );
    });

    test('auf der Schwelle ist schlecht — Gleichheit zählt', () {
      expect(
        ton(RecoveryTrendKind.hrv, const RecoveryReading(hrv: 50 * faktor)),
        VitalTon.warnsignal,
      );
    });

    test('ein Median von null erfindet keine mittlere Stufe', () {
      expect(
        ton(
          RecoveryTrendKind.hrv,
          const RecoveryReading(hrv: 40),
          baseline: const RecoveryBaseline(hrv: 0),
        ),
        VitalTon.normal,
        reason:
            'durch null geteilt wird nirgends, und die halbe Strecke zu 0 '
            'ist keine Strecke. Seit #308 sagt der Kern, ob überhaupt '
            'geurteilt wurde — er führt diese Metrik als beurteilt und '
            'ohne Signal, und die Zeile widerspricht dem Kasten über ihr '
            'nicht. Die Lage selbst kann aus Messwerten nicht entstehen',
      );
    });
  });

  group('Atemfrequenz — Median plus Zuschlag', () {
    const zuschlag = RecoveryTrafficLight.respiratoryRateMargin; // 1,5
    // Median 14: Signal ab 15,5, kritisch ab 14,75.

    test('auf dem Median ist gut', () {
      expect(
        ton(
          RecoveryTrendKind.respiratoryRate,
          const RecoveryReading(respiratoryRate: 14),
        ),
        VitalTon.normal,
      );
    });

    test('die halbe Strecke zur Schwelle ist kritisch', () {
      expect(
        ton(
          RecoveryTrendKind.respiratoryRate,
          const RecoveryReading(respiratoryRate: 14 + zuschlag / 2),
        ),
        VitalTon.nahAmSignal,
      );
    });

    test('auf der Schwelle ist schlecht', () {
      expect(
        ton(
          RecoveryTrendKind.respiratoryRate,
          const RecoveryReading(respiratoryRate: 14 + zuschlag),
        ),
        VitalTon.warnsignal,
      );
    });
  });

  group('Was gar keine Farbe bekommt', () {
    test('eine Lücke in jeder einzelnen Zeile', () {
      for (final art in RecoveryTrendKind.values) {
        expect(
          ton(art, const RecoveryReading()),
          VitalTon.unbeurteilt,
          reason:
              '$art: „—" ist weder gut noch schlecht. Eine Farbe darauf '
              'wäre eine Aussage über Daten, die es nicht gibt',
        );
      }
    });

    test('die Alkohol-Zeile, auch mit vollständigen Messwerten', () {
      expect(
        ton(
          RecoveryTrendKind.alcoholDays,
          const RecoveryReading(
            sleepHours: 4,
            restingHeartRate: 90,
            hrv: 10,
            respiratoryRate: 20,
          ),
        ),
        VitalTon.unbeurteilt,
        reason:
            'die Zeile trägt keinen Messwert, sondern einen Platzhalter — '
            'sie kann nicht gut oder schlecht sein',
      );
    });
  });

  group('Jeder Ton hat seine Farbe aus der Palette', () {
    test('grün, orange, rot — und keine eigene Konstante daneben', () {
      expect(VitalTon.normal.farbe, Palette.ok);
      expect(VitalTon.nahAmSignal.farbe, Palette.low);
      expect(VitalTon.warnsignal.farbe, Palette.warn);
    });

    test('die drei sind in beiden Modi voneinander unterscheidbar', () {
      // `unbeurteilt` trägt seit #308 keine eigene Farbe, sondern die
      // gewöhnliche Schriftfarbe des Schirms — es ist keine vierte Farbe,
      // sondern das Fehlen einer.
      final gefaerbt = [
        for (final ton in VitalTon.values)
          if (ton.farbe case final farbe?) farbe,
      ];
      final hell = {for (final farbe in gefaerbt) farbe.color.toARGB32()};
      final dunkel = {
        for (final farbe in gefaerbt) farbe.darkColor.toARGB32(),
      };

      expect(gefaerbt, hasLength(3));
      expect(hell, hasLength(gefaerbt.length));
      expect(dunkel, hasLength(gefaerbt.length));
    });
  });

  group('Die Zeile zeichnet den Ton, statt ihn nur zu tragen', () {
    Color? farbeDesWertes(WidgetTester tester, String wert) {
      final text = tester.widget<Text>(
        find.byWidgetPredicate((w) => w is Text && textOf(w) == wert),
      );
      return text.style?.color;
    }

    testWidgets('im Hellmodus die helle Variante', (tester) async {
      await tester.pumpWidget(
        huelle(
          const ErholungVerlaufsZeile(
            titel: 'HRV',
            detail: '9 Tage · Median 50 ms',
            wert: '61 ms',
            ton: VitalTon.normal,
          ),
        ),
      );

      expect(
        farbeDesWertes(tester, '61 ms')?.toARGB32(),
        Palette.ok.color.toARGB32(),
      );
    });

    testWidgets('im Dunkelmodus die dunkle — aufgelöst, nicht hängengeblieben', (
      tester,
    ) async {
      await tester.pumpWidget(
        CupertinoApp(
          theme: const CupertinoThemeData(brightness: Brightness.dark),
          home: const CupertinoPageScaffold(
            child: Center(
              child: ErholungVerlaufsZeile(
                titel: 'Ruhepuls',
                detail: '9 Tage · Median 60',
                wert: '68',
                ton: VitalTon.nahAmSignal,
              ),
            ),
          ),
        ),
      );

      expect(
        farbeDesWertes(tester, '68')?.toARGB32(),
        Palette.low.darkColor.toARGB32(),
        reason:
            'eine unaufgelöste `CupertinoDynamicColor` bliebe auf ihrer '
            'hellen Variante stehen (`palette.dart`, Klassenkommentar)',
      );
    });

    testWidgets('ohne Ton trägt der Wert die gewöhnliche Schriftfarbe', (
      tester,
    ) async {
      await tester.pumpWidget(
        huelle(
          const ErholungVerlaufsZeile(
            titel: 'HRV',
            detail: 'keine Werte',
            wert: '—',
          ),
        ),
      );

      final farbe = farbeDesWertes(tester, '—')?.toARGB32();
      for (final ton in VitalTon.values) {
        if (ton.farbe case final eigene?) {
          expect(farbe, isNot(eigene.color.toARGB32()), reason: '$ton');
        }
      }
    });
  });
}
