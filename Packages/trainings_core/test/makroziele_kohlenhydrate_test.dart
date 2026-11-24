import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für das **Kohlenhydratziel** in
/// `Packages/trainings_core/lib/src/makroziele.dart` — Issue #310 (zu #282).
///
/// `docs/SPEC.md` 4.8 nennt Ziele für Eiweiß, Fett, Ballaststoffe, Zucker,
/// gesättigte Fette und Wasser — **für Kohlenhydrate steht dort keins**. Das
/// Ziel wird deshalb gerechnet statt gesetzt, so wie in #310 entschieden:
///
/// ```
/// kohlenhydrateZielG = (kalorienziel − eiweissZielG · 4 − fettZielG · 9) / 4
/// ```
///
/// Eine gesetzte Zahl könnte dem gerechneten Kalorienziel widersprechen; eine
/// abgeleitete kann es nicht.
///
/// Die bestehenden Fälle zu `makrozieleFuer` stehen in
/// `test/makroziele_test.dart`. Diese Datei liegt daneben, weil jene
/// committet ist und nach `CLAUDE.md` nicht geändert wird.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf **ausgeführt, nie verändert** werden.
///
/// ## API, die diese Tests verbindlich vorgeben
///
/// ```dart
/// class Makroziele {
///   /// Das gerechnete Kohlenhydratziel in Gramm. `null`, wenn es nicht
///   /// gebildet werden kann — nie `0`, nie negativ.
///   final double? kohlenhydrateZielG;
///   // … die bisherigen Felder unverändert.
/// }
///
/// Makroziele makrozieleFuer({
///   required double gewichtKg,
///   double? kalorienzielKcal,
/// });
/// ```
///
/// Der neue Parameter ist optional: Die bisherigen Aufrufe
/// (`makrozieleFuer(gewichtKg: …)`) bleiben gültig und liefern dann kein
/// Kohlenhydratziel.
///
/// ## Entscheidungen des Test-Agenten, wo #310 Spielraum lässt
///
/// 1. **In die Rechnung geht das Eiweiß-*Minimum*, nicht das Maximum.**
///    Eiweiß ist ein Bereich (1,6–2,0 g/kg), Fett eine Untergrenze
///    (≥ 0,8 g/kg). Beide Pflichtwerte sind damit *Mindestmengen*, und was
///    nach den Mindestmengen vom Budget übrig ist, sind die Kohlenhydrate —
///    das ist die Lesart, die die Formel überhaupt erst trägt. Mit dem
///    Maximum wäre das Ergebnis kein „Rest", sondern bereits um die
///    Eiweiß-Spanne beschnitten, und der Kohlenhydratbalken stünde
///    systematisch zu tief. #310 nennt dasselbe Ende („naheliegend das
///    Minimum, damit der Rest nicht zu knapp wird").
///    [dasEiweissMinimumGehtInDieRechnung] nagelt es fest.
/// 2. **Der Parameter heißt `kalorienzielKcal`.** Die Einheit steht im
///    Namen wie bei `aktivKcal` und `basalKcal` in `kalorienziel.dart`, und
///    ein bloßes `kalorienziel` verdeckte dort die gleichnamige Funktion.
/// 3. **Ein Ergebnis, das es gibt, ist echt positiv.** `0 g` wäre ein Ziel,
///    das niemand gesetzt hat und das sofort auf „erfüllt" stünde — derselbe
///    Grund, aus dem `eiweissMinG` lieber `null` als `0` ist. Wo genau die
///    Grenze liegt, prüft [niemalsNullUndNiemalsNegativ] als Eigenschaft
///    über eine ganze Reihe von Kalorienzielen; ein einzelner Fall „genau
///    0 kcal übrig" wäre in `double`-Arithmetik nicht zuverlässig zu
///    treffen und würde eine korrekte Implementierung um ein Ulp verfehlen
///    bestrafen.
///
/// ## Alle Zahlen hier sind erfunden
///
/// 70,0 kg, 82,5 kg, 50,0 kg und die Kalorienziele sind glatte Rechenwerte,
/// keine Messwerte von Tim.
void main() {
  group('das gerechnete Ziel', () {
    test('70 kg und 2.452 kcal ergeben 375 g Kohlenhydrate', () {
      // 70 kg → Eiweiß mindestens 112 g (448 kcal), Fett mindestens 56 g
      // (504 kcal). Bleiben 2452 − 448 − 504 = 1500 kcal, also 375 g.
      final ziele = makrozieleFuer(gewichtKg: 70, kalorienzielKcal: 2452);

      expect(ziele.kohlenhydrateZielG, closeTo(375, 1e-9));
    });

    test('82,5 kg und 2.733,5 kcal ergeben 402,875 g Kohlenhydrate', () {
      // 132 g Eiweiß (528 kcal), 66 g Fett (594 kcal); bleiben 1611,5 kcal.
      final ziele = makrozieleFuer(gewichtKg: 82.5, kalorienzielKcal: 2733.5);

      expect(ziele.kohlenhydrateZielG, closeTo(402.875, 1e-9));
    });

    test('die übrigen Ziele bleiben, was sie waren', () {
      final ziele = makrozieleFuer(gewichtKg: 70, kalorienzielKcal: 2452);

      expect(ziele.eiweissMinG, closeTo(112, 1e-9));
      expect(ziele.eiweissMaxG, closeTo(140, 1e-9));
      expect(ziele.fettMinG, closeTo(56, 1e-9));
      expect(ziele.ballaststoffeMinG, closeTo(30, 1e-9));
      expect(ziele.zuckerMaxG, closeTo(50, 1e-9));
      expect(ziele.gesaettigtMaxG, closeTo(25, 1e-9));
      // #408: 35 ml je kg, also 2450 ml bei 70 kg.
      expect(ziele.wasserMinMl, closeTo(2450, 1e-9));
    });

    test(
      'das Eiweiß-Minimum geht in die Rechnung, nicht das Maximum',
      dasEiweissMinimumGehtInDieRechnung,
    );
  });

  group('ohne Kalorienziel', () {
    test('fehlt das Kohlenhydratziel, statt 0 zu sein', () {
      final ohneAngabe = makrozieleFuer(gewichtKg: 70);
      final ausdruecklichNull = makrozieleFuer(
        gewichtKg: 70,
        kalorienzielKcal: null,
      );

      expect(ohneAngabe.kohlenhydrateZielG, isNull);
      expect(ausdruecklichNull.kohlenhydrateZielG, isNull);
    });

    test('die anderen Ziele stehen trotzdem', () {
      final ziele = makrozieleFuer(gewichtKg: 70);

      expect(ziele.eiweissMinG, closeTo(112, 1e-9));
      expect(ziele.fettMinG, closeTo(56, 1e-9));
      expect(ziele.ballaststoffeMinG, closeTo(30, 1e-9));
    });
  });

  group('wenn Eiweiß und Fett das Budget übersteigen', () {
    test('50 kg und 600 kcal ergeben kein Ziel statt −20 g', () {
      // 80 g Eiweiß (320 kcal) und 40 g Fett (360 kcal) sind zusammen
      // 680 kcal — 80 mehr, als der Tag hergibt. Eine negative Grammzahl
      // ist keine Auskunft.
      final ziele = makrozieleFuer(gewichtKg: 50, kalorienzielKcal: 600);

      expect(ziele.kohlenhydrateZielG, isNull);
    });

    test('auch bei 0 kcal Ziel', () {
      final ziele = makrozieleFuer(gewichtKg: 70, kalorienzielKcal: 0);

      expect(ziele.kohlenhydrateZielG, isNull);
    });

    test(
      'ein Ziel, das es gibt, ist niemals 0 und niemals negativ',
      niemalsNullUndNiemalsNegativ,
    );
  });

  group('ohne brauchbares Gewicht', () {
    test('fehlt das Kohlenhydratziel, auch mit Kalorienziel', () {
      // Ohne Gewicht gibt es weder Eiweiß- noch Fettziel; dann ist auch der
      // Rest keine Rechnung, sondern eine Erfindung.
      for (final gewicht in <double>[0, -1, -70]) {
        final ziele = makrozieleFuer(
          gewichtKg: gewicht,
          kalorienzielKcal: 2452,
        );

        expect(ziele.eiweissMinG, isNull, reason: '$gewicht kg');
        expect(ziele.fettMinG, isNull, reason: '$gewicht kg');
        expect(ziele.kohlenhydrateZielG, isNull, reason: '$gewicht kg');
      }
    });
  });

  group('die Summe geht auf', () {
    test('Eiweiß·4 + Fett·9 + Kohlenhydrate·4 ergibt das Kalorienziel', () {
      const faelle = <(double, double)>[
        (70, 2452),
        (82.5, 2733.5),
        (64, 2100),
        (95.4, 3187.25),
        (58.2, 1900),
      ];

      for (final (gewichtKg, kalorienzielKcal) in faelle) {
        final ziele = makrozieleFuer(
          gewichtKg: gewichtKg,
          kalorienzielKcal: kalorienzielKcal,
        );

        final summe =
            ziele.eiweissMinG! * 4 +
            ziele.fettMinG! * 9 +
            ziele.kohlenhydrateZielG! * 4;

        expect(
          summe,
          closeTo(kalorienzielKcal, 1e-9),
          reason: '$gewichtKg kg, $kalorienzielKcal kcal',
        );
      }
    });
  });

  group('Wertgleichheit', () {
    test('gleiche Eingaben ergeben gleiche Ziele mit gleichem hashCode', () {
      final a = makrozieleFuer(gewichtKg: 70, kalorienzielKcal: 2452);
      final b = makrozieleFuer(gewichtKg: 70, kalorienzielKcal: 2452);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('ein anderes Kalorienziel ergibt andere Ziele', () {
      // Sonst rechnet Riverpod den abgeleiteten Wert nicht neu, obwohl das
      // Kohlenhydratziel ein anderes ist — `CLAUDE.md`, Fehler `03`.
      final a = makrozieleFuer(gewichtKg: 70, kalorienzielKcal: 2452);
      final b = makrozieleFuer(gewichtKg: 70, kalorienzielKcal: 2600);

      expect(a, isNot(b));
    });

    test('mit Kalorienziel ist nicht dasselbe wie ohne', () {
      final mit = makrozieleFuer(gewichtKg: 70, kalorienzielKcal: 2452);
      final ohne = makrozieleFuer(gewichtKg: 70);

      expect(mit, isNot(ohne));
    });
  });
}

/// Siehe Entscheidung 1 im Dateikopf.
void dasEiweissMinimumGehtInDieRechnung() {
  const gewichtKg = 70.0;
  const kalorienzielKcal = 2452.0;
  final ziele = makrozieleFuer(
    gewichtKg: gewichtKg,
    kalorienzielKcal: kalorienzielKcal,
  );

  final ausDemMinimum =
      (kalorienzielKcal - ziele.eiweissMinG! * 4 - ziele.fettMinG! * 9) / 4;
  final ausDemMaximum =
      (kalorienzielKcal - ziele.eiweissMaxG! * 4 - ziele.fettMinG! * 9) / 4;

  // 375 g gegen 347 g — die beiden Enden sind hier deutlich unterscheidbar.
  expect(ausDemMaximum, lessThan(ausDemMinimum));
  expect(ziele.kohlenhydrateZielG, closeTo(ausDemMinimum, 1e-9));
}

/// Siehe Entscheidung 3 im Dateikopf: Die Eigenschaft wird über eine Reihe
/// von Kalorienzielen geprüft, die die Grenze überstreicht, statt den
/// Umschlagpunkt auf ein Ulp genau festzunageln.
void niemalsNullUndNiemalsNegativ() {
  // 70 kg: Eiweiß und Fett binden zusammen 952 kcal. Die Reihe läuft von
  // deutlich darunter bis deutlich darüber.
  for (var kalorienzielKcal = 800.0;
      kalorienzielKcal <= 1100.0;
      kalorienzielKcal += 5) {
    final ziel = makrozieleFuer(
      gewichtKg: 70,
      kalorienzielKcal: kalorienzielKcal,
    ).kohlenhydrateZielG;

    if (ziel != null) {
      expect(ziel, greaterThan(0), reason: '$kalorienzielKcal kcal');
    }
  }

  // Und die Reihe ist nicht durchweg leer: Weit über der Grenze gibt es ein
  // Ziel, weit darunter keins.
  expect(
    makrozieleFuer(gewichtKg: 70, kalorienzielKcal: 1100).kohlenhydrateZielG,
    isNotNull,
  );
  expect(
    makrozieleFuer(gewichtKg: 70, kalorienzielKcal: 800).kohlenhydrateZielG,
    isNull,
  );
}
