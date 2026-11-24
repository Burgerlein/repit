import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/design/palette.dart';
import 'package:repit/design/vital_ton.dart';

import 'support.dart' show huelle;

/// **#308 — eine Färbung für beide Schirme.**
///
/// Tim am 04.11.2026 auf dem Gerät: „Schlaf-Dauer 6:18 h auf dem
/// Home-Screen grün, im Erholungs-Tab gelb." Zwei Funktionen entschieden
/// dasselbe mit verschieden vielen Stufen — `verlaufsTon` mit dreien,
/// `_tonFuer` auf Heute mit zweien. Tims Entscheidung: „Dann extrahier die
/// Funktion, dass beide Seiten dieselbe nutzen und wir keinen doppelten
/// Code haben." **Die dreistufige Fassung gilt überall.**
///
/// Diese Datei beschreibt die herausgelöste Funktion. Sie liegt im
/// Design-System und nicht in einem der beiden Schirme: Läge sie in
/// `erholung_zustand.dart` und `heute_view.dart` importierte sie, hinge ein
/// Schirm am anderen. Nutzertexte trägt sie keine, nur die Zuordnung
/// Wert → Stufe.
///
/// ## Die festgelegte API
///
/// ```dart
/// // lib/design/vital_ton.dart
///
/// enum VitalTon {
///   unbeurteilt(null),
///   normal(Palette.ok),
///   nahAmSignal(Palette.low),
///   warnsignal(Palette.warn);
///
///   const VitalTon(this.farbe);
///
///   /// Die Palette-Zuordnung, unaufgelöst — `null` heißt „keine eigene
///   /// Farbe".
///   final CupertinoDynamicColor? farbe;
/// }
///
/// /// Die **eine** Stelle, an der aus Messwert und Urteil eine Stufe wird.
/// VitalTon vitalTon({
///   required RecoveryMetric metrik,
///   required RecoveryReading messwerte,
///   required RecoveryBaseline baseline,
///   required RecoveryEvaluation? bewertung,
/// });
///
/// /// Die **eine** Stelle, an der aus der Stufe eine Farbe wird.
/// Color vitalTonFarbe(VitalTon ton, BuildContext context, Color ink);
/// ```
///
/// **Vier Stufen, nicht drei plus `null`.** `verlaufsTon` gab bisher `null`
/// zurück, wo es nichts zu sagen gab; `VitalTon` kannte denselben Zustand
/// als `unbeurteilt`. Zwei Schreibweisen für denselben Zustand sind genau
/// der Zwilling, den dieses Ticket abschafft — also bleibt eine.
///
/// **Ein Name, nicht zwei.** `VerlaufsTon` und `VitalTon` beschrieben
/// dieselben Stufen; zwei Aufzählungstypen hätten zwei Zuordnungen
/// Stufe → Farbe nach sich gezogen, und damit wäre die zweite Hälfte des
/// Fehlers stehen geblieben.
///
/// ## Die Zuordnung, verbindlich
///
/// | Stufe | Regel |
/// |---|---|
/// | **unbeurteilt** | die Ampel hat über diese Metrik nichts gesagt (`rated`) |
/// | **warnsignal** | die Ampel führt sie als Warnsignal (`signals`) |
/// | **nahAmSignal** | kein Signal, aber **die halbe Strecke** zur Schwelle ist überschritten |
/// | **normal** | sonst |
///
/// Die Reihenfolge ist Vertrag: Erst `rated`, dann `signals`, dann der
/// Abstand. **Rot und „nicht beurteilt" sagt der Kern, nicht die
/// Oberfläche** (#254) — nur die mittlere Stufe entsteht hier, weil es sie
/// im Kern nicht gibt und auch nicht geben soll: Sie ist eine Auskunft über
/// die Darstellung, kein Teil der Bewertung.
///
/// Je Metrik, mit den Konstanten des Kerns:
///
/// | Metrik | nahAmSignal ab | Signal (vom Kern) ab |
/// |---|---|---|
/// | Schlaf | unter `minimumSleepHours + 0,5` h | unter `minimumSleepHours` (6 h) |
/// | Ruhepuls | ab `Median + restingHeartRateMargin / 2` | ab `Median + restingHeartRateMargin` |
/// | HRV | bis `Median · (1 + hrvFactor) / 2` | bis `Median · hrvFactor` |
/// | Atemfrequenz | ab `Median + respiratoryRateMargin / 2` | ab `Median + respiratoryRateMargin` |
///
/// **Die Schwellen ändern sich nicht** (`docs/SPEC.md` 176). Es geht um
/// Darstellung, nicht um Bewertung.
///
/// ## Der Fall, der dabei am ehesten verlorenginge
///
/// `verlaufsTon` gab `null` zurück, wenn Wert oder Median fehlten — **den
/// OP-Fall kannte es nicht.** Nach der OP ruht die Ampel: `rated` ist leer,
/// obwohl Werte und Mediane vorliegen. Eine Funktion, die nur auf `null`
/// prüft, färbte dort weiter und behauptete eine Bewertung, die
/// ausdrücklich ausgesetzt ist. Deshalb nimmt sie die Bewertung entgegen
/// und nicht nur Zahlen.
///
/// ## Zahlen in dieser Datei
///
/// Alle erfunden (`CLAUDE.md`). Die Mediane sind glatt, damit die Schwellen
/// im Kopf nachvollziehbar bleiben.
void main() {
  /// Die Bewertung kommt aus dem Kern, nicht von Hand: Was ein Warnsignal
  /// ist, entscheidet `RecoveryTrafficLight` — hier wird geprüft, was die
  /// Oberfläche daraus macht.
  VitalTon ton(
    RecoveryMetric metrik,
    RecoveryReading messwerte, {
    RecoveryBaseline baseline = _median,
    bool nachOp = false,
  }) => vitalTon(
    metrik: metrik,
    messwerte: messwerte,
    baseline: baseline,
    bewertung: RecoveryTrafficLight.evaluate(
      reading: messwerte,
      baseline: baseline,
      isPostOperative: nachOp,
    ),
  );

  group('Der Fall aus #308 — 6:18 h Schlaf', () {
    test('ist auf beiden Schirmen die mittlere Stufe', () {
      expect(
        ton(RecoveryMetric.sleep, const RecoveryReading(sleepHours: 6.3)),
        VitalTon.nahAmSignal,
        reason:
            '6:18 h ist kein Warnsignal — die Grenze liegt bei 6:00 h —, '
            'aber in der Pufferzone darüber. Genau diese Zahl stand auf '
            'Heute grün und auf Erholung gelb',
      );
    });

    test('auch ohne Median: die Sechs-Stunden-Grenze steht fest', () {
      expect(
        ton(
          RecoveryMetric.sleep,
          const RecoveryReading(sleepHours: 6.3),
          baseline: const RecoveryBaseline(),
        ),
        VitalTon.nahAmSignal,
        reason:
            'der Schlaf braucht keinen Median (`docs/SPEC.md` 4.6) — und '
            'genau deshalb ist er auch ohne Vorgeschichte beurteilt',
      );
    });
  });

  group('Die mittlere Stufe, je Metrik', () {
    test('Schlaf: die halbe Stunde über der festen Grenze', () {
      const schwelle = RecoveryTrafficLight.minimumSleepHours; // 6,0

      expect(
        ton(RecoveryMetric.sleep, const RecoveryReading(sleepHours: 7.5)),
        VitalTon.normal,
      );
      expect(
        ton(RecoveryMetric.sleep, const RecoveryReading(sleepHours: schwelle)),
        VitalTon.nahAmSignal,
        reason:
            'genau sechs Stunden sind kein Signal — der Kern vergleicht '
            'strikt kleiner —, aber auch nicht normal',
      );
      expect(
        ton(
          RecoveryMetric.sleep,
          const RecoveryReading(sleepHours: schwelle + 0.5),
        ),
        VitalTon.normal,
        reason: 'am oberen Rand der Pufferzone ist sie verlassen',
      );
      expect(
        ton(
          RecoveryMetric.sleep,
          const RecoveryReading(sleepHours: schwelle - 0.01),
        ),
        VitalTon.warnsignal,
      );
    });

    test('Ruhepuls: die halbe Strecke zum Zuschlag', () {
      const zuschlag = RecoveryTrafficLight.restingHeartRateMargin; // 5
      // Median 60: Signal ab 65, mittlere Stufe ab 62,5.

      expect(
        ton(
          RecoveryMetric.restingHeartRate,
          const RecoveryReading(restingHeartRate: 60),
        ),
        VitalTon.normal,
      );
      expect(
        ton(
          RecoveryMetric.restingHeartRate,
          const RecoveryReading(restingHeartRate: 60 + zuschlag / 2),
        ),
        VitalTon.nahAmSignal,
      );
      expect(
        ton(
          RecoveryMetric.restingHeartRate,
          const RecoveryReading(restingHeartRate: 60 + zuschlag),
        ),
        VitalTon.warnsignal,
        reason: 'Gleichheit zählt, wie im Kern',
      );
    });

    test('HRV: die einzige Metrik, die nach unten kippt', () {
      const faktor = RecoveryTrafficLight.hrvFactor; // 0,8
      // Median 50: Signal ab 40 abwärts, mittlere Stufe ab 45 abwärts.

      expect(
        ton(RecoveryMetric.hrv, const RecoveryReading(hrv: 61)),
        VitalTon.normal,
      );
      expect(
        ton(
          RecoveryMetric.hrv,
          const RecoveryReading(hrv: 50 * (1 + faktor) / 2),
        ),
        VitalTon.nahAmSignal,
      );
      expect(
        ton(RecoveryMetric.hrv, const RecoveryReading(hrv: 50 * faktor)),
        VitalTon.warnsignal,
      );
    });

    test('Atemfrequenz: die halbe Strecke zum Zuschlag', () {
      const zuschlag = RecoveryTrafficLight.respiratoryRateMargin; // 1,5
      // Median 14: Signal ab 15,5, mittlere Stufe ab 14,75.

      expect(
        ton(
          RecoveryMetric.respiratoryRate,
          const RecoveryReading(respiratoryRate: 14),
        ),
        VitalTon.normal,
      );
      expect(
        ton(
          RecoveryMetric.respiratoryRate,
          const RecoveryReading(respiratoryRate: 14 + zuschlag / 2),
        ),
        VitalTon.nahAmSignal,
      );
      expect(
        ton(
          RecoveryMetric.respiratoryRate,
          const RecoveryReading(respiratoryRate: 14 + zuschlag),
        ),
        VitalTon.warnsignal,
      );
    });
  });

  group('Ohne Urteil keine Farbe', () {
    test('ohne Bewertung ist nichts beurteilt', () {
      for (final metrik in RecoveryMetric.values) {
        expect(
          vitalTon(
            metrik: metrik,
            messwerte: _ruhig,
            baseline: _median,
            bewertung: null,
          ),
          VitalTon.unbeurteilt,
          reason:
              '$metrik: wer keine Bewertung mitgibt, hat nicht bewertet — '
              'grün behauptete „im Normalbereich", und das hat niemand '
              'gesagt',
        );
      }
    });

    test('ein Wert ohne Median ist unbeurteilt — außer dem Schlaf', () {
      expect(
        ton(
          RecoveryMetric.hrv,
          const RecoveryReading(hrv: 40),
          baseline: const RecoveryBaseline(),
        ),
        VitalTon.unbeurteilt,
        reason: 'ohne Vergleichswert ist der Wert weder gut noch schlecht',
      );
      expect(
        ton(
          RecoveryMetric.restingHeartRate,
          const RecoveryReading(restingHeartRate: 80),
          baseline: const RecoveryBaseline(),
        ),
        VitalTon.unbeurteilt,
      );
      expect(
        ton(
          RecoveryMetric.respiratoryRate,
          const RecoveryReading(respiratoryRate: 20),
          baseline: const RecoveryBaseline(),
        ),
        VitalTon.unbeurteilt,
      );
    });

    test('eine Lücke bekommt keine Farbe', () {
      for (final metrik in RecoveryMetric.values) {
        expect(
          ton(metrik, const RecoveryReading()),
          VitalTon.unbeurteilt,
          reason:
              '$metrik: „—" ist weder gut noch schlecht. Eine Farbe darauf '
              'wäre eine Aussage über Daten, die es nicht gibt',
        );
      }
    });

    test('nach der OP ruht die Ampel — trotz Werten und Medianen', () {
      for (final metrik in RecoveryMetric.values) {
        expect(
          ton(metrik, _ruhig, nachOp: true),
          VitalTon.unbeurteilt,
          reason:
              '$metrik: `rated` ist nach der OP leer. Eine Funktion, die '
              'nur auf fehlende Zahlen prüft, färbte hier weiter und '
              'behauptete eine Bewertung, die ausgesetzt ist',
        );
      }
    });

    test('auch ein Wert, der ohne die OP rot wäre, bleibt ungefärbt', () {
      expect(
        ton(
          RecoveryMetric.sleep,
          const RecoveryReading(sleepHours: 4),
          nachOp: true,
        ),
        VitalTon.unbeurteilt,
        reason:
            'nach der OP sind kurze Nächte und niedrige HRV erwartbar — '
            'der Schirm sagt das einmal oben, nicht viermal in Rot',
      );
    });
  });

  group('Rot sagt der Kern', () {
    test('die Stufe folgt `signals`, nicht einer zweiten Rechnung', () {
      // Eine Bewertung, die der Kern so nie baut: Der Schlaf ist beurteilt,
      // steht aber trotz 5 h nicht als Signal. Hier steht sie für die
      // Richtung der Abhängigkeit — die Oberfläche rechnet die Schwelle
      // nicht nach, sie liest das Urteil (#254).
      expect(
        vitalTon(
          metrik: RecoveryMetric.sleep,
          messwerte: const RecoveryReading(sleepHours: 5),
          baseline: _median,
          bewertung: const RecoveryEvaluation(
            verdict: RecoveryVerdict.calm,
            signals: [],
            measuredCount: 1,
            rated: [RecoveryMetric.sleep],
          ),
        ),
        isNot(VitalTon.warnsignal),
        reason:
            'die Karte bewertet nicht selbst — sie zeigt, was der Kern '
            'entschieden hat',
      );
    });

    test('ein Signal wird nicht von der mittleren Stufe verdeckt', () {
      expect(
        ton(RecoveryMetric.hrv, const RecoveryReading(hrv: 10)),
        VitalTon.warnsignal,
        reason:
            'wer unter der Schwelle liegt, hat auch die halbe Strecke '
            'hinter sich — geprüft wird das Signal zuerst',
      );
    });
  });

  group('Jede Stufe hat ihre Farbe', () {
    test('grün, orange, rot — und keine eigene Konstante daneben', () {
      expect(VitalTon.normal.farbe, Palette.ok);
      expect(VitalTon.nahAmSignal.farbe, Palette.low);
      expect(VitalTon.warnsignal.farbe, Palette.warn);
    });

    test('unbeurteilt trägt keine eigene Farbe', () {
      expect(
        VitalTon.unbeurteilt.farbe,
        isNull,
        reason:
            'nicht grau: Grau heißt auf dem Erholungs-Schirm „kein Wert", '
            'und ein gemessener, nur unverglichener Wert darf nicht wie '
            'ein fehlender aussehen',
      );
    });

    test('die drei gefärbten sind in beiden Modi unterscheidbar', () {
      final gefaerbt = [
        for (final ton in VitalTon.values)
          if (ton.farbe case final farbe?) farbe,
      ];

      expect(gefaerbt, hasLength(3));
      expect({
        for (final farbe in gefaerbt) farbe.color.toARGB32(),
      }, hasLength(3));
      expect({
        for (final farbe in gefaerbt) farbe.darkColor.toARGB32(),
      }, hasLength(3));
    });

    testWidgets('aufgelöst wird beim Zeichnen, nicht im Aufzählungstyp', (
      tester,
    ) async {
      late BuildContext hell;
      await tester.pumpWidget(
        huelle(
          Builder(
            builder: (context) {
              hell = context;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(
        vitalTonFarbe(
          VitalTon.nahAmSignal,
          hell,
          CupertinoColors.black,
        ).toARGB32(),
        Palette.low.color.toARGB32(),
      );
      expect(
        vitalTonFarbe(
          VitalTon.unbeurteilt,
          hell,
          CupertinoColors.black,
        ).toARGB32(),
        CupertinoColors.black.toARGB32(),
        reason: 'ohne eigene Farbe bleibt die gewöhnliche Schriftfarbe',
      );
    });

    testWidgets('im Dunkelmodus die dunkle Variante', (tester) async {
      late BuildContext dunkel;
      await tester.pumpWidget(
        CupertinoApp(
          theme: const CupertinoThemeData(brightness: Brightness.dark),
          home: CupertinoPageScaffold(
            child: Builder(
              builder: (context) {
                dunkel = context;
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(
        vitalTonFarbe(
          VitalTon.warnsignal,
          dunkel,
          CupertinoColors.white,
        ).toARGB32(),
        Palette.warn.darkColor.toARGB32(),
        reason:
            'eine unaufgelöste `CupertinoDynamicColor` bliebe auf ihrer '
            'hellen Variante stehen (`palette.dart`, Klassenkommentar)',
      );
    });
  });
}

/// Die Mediane der Vorgeschichte, glatt gewählt — Signal beim Ruhepuls ab
/// 65, bei der HRV ab 40 abwärts, bei der Atemfrequenz ab 15,5.
const _median = RecoveryBaseline(
  sleepHours: 7,
  restingHeartRate: 60,
  hrv: 50,
  respiratoryRate: 14,
);

/// Alle vier Werte unauffällig — die Grundlage, von der aus je ein Wert
/// verschoben wird.
const _ruhig = RecoveryReading(
  sleepHours: 7.5,
  restingHeartRate: 60,
  hrv: 50,
  respiratoryRate: 14,
);
