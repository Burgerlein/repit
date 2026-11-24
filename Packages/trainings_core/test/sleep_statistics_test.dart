import 'dart:math';

import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für das **zirkuläre Mittel von Uhrzeiten** —
/// `Packages/trainings_core/lib/src/sleep_statistics.dart`.
///
/// ## Warum diese Datei im Kern liegt und nicht in `app/test/`
///
/// `CLAUDE.md`: „Jede Formel aus `docs/SPEC.md` bekommt einen Test, und zwar
/// **im Kern** […] Eine Formel, deren Test in `app/test/` landet, beweist die
/// Importgrenze nicht mehr mit." Das zirkuläre Mittel ist eine Formel aus
/// `docs/SPEC.md` 4.6 (Z. 236–246), ausgeschrieben samt Herleitung an echten
/// Daten. Sie braucht nichts als `dart:math` und gehört damit genau dorthin,
/// wo `SleepScoring` schon liegt.
///
/// **Die Zusammensetzung der Statistik bleibt dagegen in der App**
/// (`app/lib/shell/schlaf_zustand.dart`, siehe `schlaf_zustand_test.dart`):
/// Ø Schlafdauer, Ø Einschlafzeit, Ø Aufwachzeit und die Phasenanteile
/// brauchen `SleepSegment`, und das ist ein Transporttyp des Kanals, der nach
/// `CLAUDE.md` ausdrücklich **nicht** in den Kern gehört („Transporttypen
/// gehören nicht in den Kern … Der Kern trägt Rechnungen"). Die Swift-Vorlage
/// `TrainingsCore/Sleep/SleepStatistics.swift` kann beides zusammenlegen, weil
/// dort `SleepSession` im Paket liegt; in Dart tut es das nicht.
///
/// ## Festgelegte öffentliche API
///
/// ```dart
/// /// Was mehrere Nächte über ihre Uhrzeiten sagen — die eine Rechnung
/// /// daran, die eine Rechnung ist.
/// abstract final class SleepStatistics {
///   /// Eine volle Umdrehung in Minuten.
///   static const double fullTurn = 1440;
///
///   /// Ab dieser Länge der Vektorsumme gilt ein Mittel als bestimmt.
///   static const double resultantFloor = 1e-9;
///
///   /// Das zirkuläre Mittel von Uhrzeiten, in Minuten auf derselben Skala
///   /// wie die Eingabe. `null`, wenn es keines gibt.
///   static double? circularMeanMinutes(List<double> values);
/// }
/// ```
///
/// Dazu der Export aus `lib/trainings_core.dart`.
///
/// ## Die Regeln, die hier festgeschrieben werden
///
/// 1. **Ein gewöhnlicher Durchschnitt reicht nicht.** Zwei Zeiten beiderseits
///    einer Tagesgrenze mitteln sich auf die Grenze, nicht auf die
///    Gegenseite. Jeder Test, der das prüft, nennt daneben, was der lineare
///    Durchschnitt ergäbe — sonst ist nicht zu sehen, dass die Rechnung
///    überhaupt eine andere ist.
/// 2. **Kein Mittel ist ein Ergebnis.** Liegen die Zeiten gleichmäßig über
///    den Kreis verteilt oder genau gegenüber, zeigt die Vektorsumme ins
///    Nichts; dann steht in der Ansicht ein Gedankenstrich und keine
///    erfundene Uhrzeit (SPEC 4.6). `null`, nicht `0`.
/// 3. **Die Skala darf ins Negative gehen.** `EveningClock` liefert seit dem
///    27.10.2026 für 17:50 den Wert −10 (`sleep_scoring.dart`); auf dem Kreis
///    ist das dieselbe Richtung wie 1430, und die Funktion darf daran nicht
///    scheitern.
/// 4. **Das Ergebnis liegt immer in `[0, fullTurn)`.** Sonst müsste jeder
///    Aufrufer dieselbe Normalisierung noch einmal schreiben.
///
/// ## Zahlen in dieser Datei
///
/// Alle erfunden und frei gewählt — keine stammt aus einem Health-Export
/// (`CLAUDE.md`).
void main() {
  /// Minuten seit Mitternacht, damit die Testfälle lesbar bleiben.
  double uhr(int stunde, [int minute = 0]) =>
      (stunde * Duration.minutesPerHour + minute).toDouble();

  /// Der gewöhnliche Durchschnitt — nur, um ihn danebenzustellen.
  double linear(List<double> werte) =>
      werte.reduce((a, b) => a + b) / werte.length;

  /// Der Abstand zweier Uhrzeiten **auf dem Kreis**, 0 bis 720 Minuten.
  double kreisAbstand(double a, double b) {
    final roh =
        ((a - b) % SleepStatistics.fullTurn + SleepStatistics.fullTurn) %
        SleepStatistics.fullTurn;
    return roh > SleepStatistics.fullTurn / 2
        ? SleepStatistics.fullTurn - roh
        : roh;
  }

  /// „Dieselbe Uhrzeit" heißt auf einem Kreis: derselbe Punkt, nicht
  /// dieselbe Zahl.
  ///
  /// **Nicht `closeTo`.** Ein Mittel, das rechnerisch auf Mitternacht fällt,
  /// kommt in `double` als winzig positive oder winzig negative Richtung
  /// heraus; die Normalisierung nach `[0, 1440)` macht aus der zweiten
  /// 1439,999999…. Beides ist Mitternacht, `closeTo(0, …)` fiele bei einer
  /// von beiden um — und zwar je nach Rundung mal so, mal so. Ein Test, der
  /// an einer Vorzeichenlaune hängt, prüft nicht die Regel, sondern das
  /// Wetter.
  Matcher aufDemKreis(double soll) => predicate<double?>(
    (mittel) => mittel != null && kreisAbstand(mittel, soll) < 1e-6,
    'eine Uhrzeit, die auf dem Kreis bei $soll Minuten liegt',
  );

  group('Die Konstanten sind benannt, nicht eingestreut', () {
    test('eine volle Umdrehung sind 1440 Minuten', () {
      expect(SleepStatistics.fullTurn, 1440);
    });

    test(
      'die Schwelle für „es gibt ein Mittel" ist klein, aber nicht null — '
      'drei gleichmäßig verteilte Zeiten ergeben in double nicht exakt 0',
      () {
        expect(SleepStatistics.resultantFloor, greaterThan(0));
        expect(SleepStatistics.resultantFloor, lessThan(1e-6));
      },
    );
  });

  group('Entartete Eingaben', () {
    test('keine Zeiten: kein Mittel', () {
      expect(SleepStatistics.circularMeanMinutes(const []), isNull);
    });

    test('eine einzige Zeit ist ihr eigenes Mittel', () {
      expect(
        SleepStatistics.circularMeanMinutes([uhr(23, 10)]),
        aufDemKreis(uhr(23, 10)),
      );
    });

    test('dieselbe Zeit mehrfach bleibt dieselbe Zeit', () {
      expect(
        SleepStatistics.circularMeanMinutes([
          uhr(22, 45),
          uhr(22, 45),
          uhr(22, 45),
        ]),
        aufDemKreis(uhr(22, 45)),
      );
    });
  });

  group('Zirkulär, nicht linear — das ist der ganze Punkt', () {
    test(
      '23:00 und 01:00 mitteln sich auf Mitternacht; der lineare '
      'Durchschnitt läge zwölf Stunden daneben, auf dem Mittag',
      () {
        final zeiten = [uhr(23), uhr(1)];

        final mittel = SleepStatistics.circularMeanMinutes(zeiten);

        expect(mittel, aufDemKreis(0));
        // Das, was eine naive Rechnung ergäbe — und was hier gerade nicht
        // herauskommen darf.
        expect(linear(zeiten), closeTo(uhr(12), 1e-6));
      },
    );

    test('23:50 und 00:10 mitteln sich ebenfalls auf Mitternacht', () {
      expect(
        SleepStatistics.circularMeanMinutes([uhr(23, 50), uhr(0, 10)]),
        aufDemKreis(0),
      );
    });

    test(
      'die Lage aus SPEC 4.6: ein später Nachmittag neben einem frühen Abend '
      '— auf dem Kreis Nachbarn, linear ein halber Tag auseinander',
      () {
        // 1365 und 240 sind die beiden Zahlen, an denen der Fehler am
        // 13.10.2026 auffiel (SPEC 4.6 Z. 236–246). Auf dem Kreis liegen
        // sie 135 Minuten auseinander, linear 1125.
        final zeiten = [1365.0, 240.0];

        final mittel = SleepStatistics.circularMeanMinutes(zeiten)!;

        // Das Mittel liegt **zwischen** beiden — auf dem kurzen Bogen über
        // die 1440er-Grenze hinweg, nicht auf dem langen durch den Tag.
        expect(mittel, aufDemKreis(82.5));
        expect(linear(zeiten), closeTo(802.5, 1e-6));
      },
    );

    test(
      'drei Zeiten um die Tagesgrenze: das Mittel bleibt in ihrer Nähe, '
      'nicht auf der Gegenseite',
      () {
        final mittel = SleepStatistics.circularMeanMinutes([
          uhr(23),
          uhr(23, 30),
          uhr(0, 30),
        ])!;

        // Zwischen 23:00 und 00:30, nicht irgendwo am Nachmittag.
        expect(
          mittel > uhr(23) || mittel < uhr(1),
          isTrue,
          reason: 'Mittel lag bei $mittel',
        );
      },
    );

    test('Zeiten ohne Grenzüberschreitung mitteln sich ganz gewöhnlich', () {
      final zeiten = [uhr(22), uhr(23)];

      expect(
        SleepStatistics.circularMeanMinutes(zeiten),
        aufDemKreis(linear(zeiten)),
      );
    });
  });

  group('Kein Mittel ist ein Ergebnis — null, nicht null Uhr', () {
    test(
      'genau gegenüber: 00:00 und 12:00 haben kein Mittel, weil beide '
      'Richtungen gleich gut wären',
      () {
        expect(
          SleepStatistics.circularMeanMinutes([uhr(0), uhr(12)]),
          isNull,
        );
      },
    );

    test('drei gleichmäßig verteilte Zeiten haben kein Mittel', () {
      expect(
        SleepStatistics.circularMeanMinutes([uhr(0), uhr(8), uhr(16)]),
        isNull,
      );
    });

    test('vier gleichmäßig verteilte Zeiten haben kein Mittel', () {
      expect(
        SleepStatistics.circularMeanMinutes([uhr(0), uhr(6), uhr(12), uhr(18)]),
        isNull,
      );
    });

    test(
      'knapp daneben hat eines — die Schwelle darf nicht so groß sein, dass '
      'sie echte Mittel verschluckt',
      () {
        final mittel = SleepStatistics.circularMeanMinutes([
          uhr(0),
          uhr(12) - 1,
        ]);

        expect(mittel, isNotNull);
      },
    );
  });

  group('Die Skala: negativ, über 1440, Ergebnis immer im Kreis', () {
    test(
      'eine negative Minute ist dieselbe Richtung wie ihr Gegenstück über '
      '1440 — EveningClock liefert für 17:50 seit dem 27.10. −10',
      () {
        final negativ = SleepStatistics.circularMeanMinutes([-10, 10])!;
        final positiv = SleepStatistics.circularMeanMinutes([1430, 10])!;

        expect(kreisAbstand(negativ, positiv), lessThan(1e-6));
      },
    );

    test('eine einzelne negative Zeit kommt als Winkel im Kreis zurück', () {
      expect(SleepStatistics.circularMeanMinutes([-75]), aufDemKreis(1365));
    });

    test('Werte jenseits einer vollen Umdrehung zählen wie ihr Rest', () {
      expect(
        SleepStatistics.circularMeanMinutes([1450, 1450]),
        aufDemKreis(10),
      );
    });

    test('das Ergebnis liegt für jede Eingabe in [0, 1440)', () {
      final zufall = Random(4711);
      for (var lauf = 0; lauf < 200; lauf++) {
        final werte = [
          for (var i = 0; i < 1 + zufall.nextInt(8); i++)
            zufall.nextDouble() * 4000 - 2000,
        ];

        final mittel = SleepStatistics.circularMeanMinutes(werte);
        if (mittel == null) continue;

        expect(mittel, greaterThanOrEqualTo(0.0), reason: '$werte');
        expect(mittel, lessThan(SleepStatistics.fullTurn), reason: '$werte');
      }
    });

    test('die Reihenfolge der Eingabe ist gleichgültig', () {
      final werte = [uhr(23, 10), uhr(0, 40), uhr(22, 20), uhr(1, 5)];
      final andersherum = werte.reversed.toList();

      expect(
        kreisAbstand(
          SleepStatistics.circularMeanMinutes(werte)!,
          SleepStatistics.circularMeanMinutes(andersherum)!,
        ),
        lessThan(1e-9),
      );
    });
  });
}
