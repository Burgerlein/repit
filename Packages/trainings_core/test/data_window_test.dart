import 'package:test/test.dart';

import 'package:trainings_core/src/berlin_calendar.dart';
import 'package:trainings_core/src/data_window.dart';

/// Tests für `DataWindow`, das Dart-Gegenstück zu
/// `Packages/TrainingsCore/Sources/TrainingsCore/Health/DataWindow.swift`.
///
/// Direkter Import der Implementierungsdatei statt des Barrel-Files
/// `package:trainings_core/trainings_core.dart`, aus demselben Grund wie in
/// `berlin_calendar_test.dart`: Der Task-4-Auftrag nennt nur
/// `lib/src/data_window.dart` als anzulegende Datei, keine Änderung an
/// `lib/trainings_core.dart`. Solange diese Datei nicht existiert, schlägt
/// der Import fehl — das ist der erwartete RED-Zustand vor der Umsetzung.
///
/// Die Vorlage trägt ihre Begründung als Dartdoc:
///
/// > Die Grenze ist tagesgenau, nicht sekundengenau. Ein vom Nutzer gewähltes
/// > Datum meint den ganzen Tag — ein Messwert von 06:40 darf nicht
/// > herausfallen, nur weil die Einstellung um 23:30 gesetzt wurde. Jede
/// > Tagesgrenze läuft deshalb über `BerlinCalendar`, nie über eine Rechnung
/// > mit 86400.
///
/// Zwei Folgen davon werden unten eigens geprüft: (1) ein Messwert am
/// Vormittag eines Tages bleibt drin, auch wenn die Grenze am Abend
/// desselben Tages gesetzt wurde, und (2) zwei Grenzen, die auf denselben
/// Kalendertag fallen, verhalten sich für jede Abfrage identisch.
///
/// **`DataWindow` bekommt `==` und `hashCode`** (Entscheidung nach Abgabe
/// dieses Tasks, nicht aus `task-4-brief.md` selbst): Die App hält
/// `DataWindow` künftig in einem Riverpod-Provider, und abgeleitete
/// Provider rechnen genau dann neu, wenn sich ihre Abhängigkeit *ungleich*
/// anfühlt. Ohne Wertgleichheit wäre jede neu konstruierte `DataWindow` ein
/// neues, ungleiches Objekt, und jeder abgeleitete Wert würde unnötig neu
/// gerechnet — der Fehler, gegen den dieser Umbau gebaut wird (siehe
/// #56). Die Gruppe "Equatable: == und hashCode" weiter unten
/// prüft das: Gleichheit über den normalisierten Tag (nicht die Uhrzeit,
/// zu der die Grenze gesetzt wurde), Ungleichheit über Tage hinweg,
/// `unlimited` als eigener (unbegrenzter) Gleichheitsfall, und dass
/// `hashCode` zu `==` passt — geprüft über ein `Set`, weil ein `==` ohne
/// passenden `hashCode` sonst erst auffällt, sobald jemand eine `Map` oder
/// ein `Set` benutzt.
///
/// Erwartete Werte für Tagesgrenzen werden, wo es auf den exakten UTC-Wert
/// ankommt, über `BerlinCalendar.startOfDay` hergeleitet statt von Hand
/// vorgerechnet — dieselbe Berechnung, die `DataWindow` laut Vorlage selbst
/// für die Normalisierung benutzen muss. Nur so lässt sich der DST-Fall
/// (dayCount über den Oktober 2026) ohne Vorrechnen der Stundenversätze
/// formulieren.
void main() {
  group('Pflichtfälle aus dem Task-Brief (Werte wörtlich übernommen)', () {
    test('ohne Grenze enthaelt alles', () {
      expect(DataWindow.unlimited.contains(DateTime.utc(1990)), isTrue);
    });

    test('Grenze meint den ganzen Tag', () {
      // Grenze auf 23:30 Berliner Zeit gesetzt. Am 23.10.2026 gilt noch
      // Sommerzeit (Umstellung erst am 25.10., siehe
      // berlin_calendar_test.dart), also Versatz +2h: 23:30 Berlin = 21:30
      // UTC. Ein Messwert von 06:40 Berliner Zeit desselben Tages liegt bei
      // 04:40 UTC — zeitlich lange vor der gesetzten Uhrzeit, aber auf
      // demselben Kalendertag, und muss deshalb enthalten sein.
      final w = DataWindow(start: DateTime.utc(2026, 10, 23, 21, 30));
      expect(w.contains(DateTime.utc(2026, 10, 23, 4, 40)), isTrue);
    });

    test('queryStart nimmt die spaetere der beiden Grenzen', () {
      final floor = DateTime.utc(2026, 1, 1);

      // Fenstergrenze liegt nach floor -> die Fenstergrenze gewinnt.
      final spaeterAlsFloor = DataWindow(start: DateTime.utc(2026, 6, 1));
      expect(
        spaeterAlsFloor.queryStart(floor: floor),
        BerlinCalendar.startOfDay(DateTime.utc(2026, 6, 1)),
      );

      // Fenstergrenze liegt vor floor -> floor gewinnt (weiter zurückfragen
      // als floor bringt laut Vorlage nichts, floor ist "das Älteste, was
      // die Quelle hergibt").
      final frueherAlsFloor = DataWindow(start: DateTime.utc(2025, 1, 1));
      expect(frueherAlsFloor.queryStart(floor: floor), floor);
    });

    test('dayCount ist null ohne Grenze und 0 bei Grenze in der Zukunft', () {
      expect(DataWindow.unlimited.dayCount(), isNull);

      // Grenze (normalisiert auf 2027-01-01) liegt nach dem Endtag
      // 2026-01-01 -> "gespeichertes Datum liegt in der Zukunft", 0 Tage,
      // kein Absturz.
      final grenzeInDerZukunft = DataWindow(start: DateTime.utc(2027, 1, 1));
      expect(
        grenzeInDerZukunft.dayCount(through: DateTime.utc(2026, 1, 1)),
        0,
      );
    });

    test(
      'clip laesst die Reihe unveraendert, wenn keine Grenze gesetzt ist',
      () {
        final eintraege = [
          _Messwert(DateTime.utc(2000, 1, 1), 1),
          _Messwert(DateTime.utc(2026, 10, 23), 2),
        ];
        final ergebnis = DataWindow.unlimited.clip(eintraege, (e) => e.datum);
        expect(ergebnis, orderedEquals(eintraege));
      },
    );
  });

  group('contains: Tagesbeginne, nicht Zeitpunkte', () {
    test('ein Messwert am Vortag spaet abends faellt heraus', () {
      // Grenze: Beginn des 23.10.2026 (Berliner Zeit). Ein Messwert um
      // 23:59 Berliner Zeit am 22.10. (21:59 UTC, noch Sommerzeit) liegt auf
      // dem Vortag und muss draussen bleiben.
      final w = DataWindow(start: DateTime.utc(2026, 10, 23, 0, 0));
      expect(w.contains(DateTime.utc(2026, 10, 22, 21, 59)), isFalse);
    });

    test(
      'eine spaete UTC-Uhrzeit gehoert schon zum Berliner Folgetag — die '
      'Falle, die diesem Test selbst einmal einen Zahlendreher eingebracht '
      'hat',
      () {
        // 23:30 UTC am 23.10.2026 sieht nach "23.10." aus, ist aber wegen
        // der Sommerzeit (+2h, Umstellung erst am 25.10.) bereits 01:30
        // Berliner Zeit am 24.10. — ein anderer Kalendertag als der
        // UTC-Datumsteil suggeriert. Ein Fenster, das erst am 24.10.
        // beginnt, muss diesen Messwert deshalb enthalten.
        final w = DataWindow(start: DateTime.utc(2026, 10, 24, 0, 0));
        expect(w.contains(DateTime.utc(2026, 10, 23, 23, 30)), isTrue);

        // Umgekehrt: derselbe Messwert minus zwei Stunden und eine Minute
        // (21:29 UTC) liegt noch auf der Berliner Seite des 23.10. und
        // faellt aus demselben Fenster heraus — die Grenze verlaeuft exakt
        // zwischen 21:59 und 22:00 UTC, nicht zwischen 23:59 und 00:00 UTC.
        expect(w.contains(DateTime.utc(2026, 10, 23, 21, 29)), isFalse);
      },
    );

    test('ein Messwert genau auf dem Tagesbeginn der Grenze ist enthalten', () {
      final tagesbeginn = BerlinCalendar.startOfDay(
        DateTime.utc(2026, 10, 23, 12),
      );
      final w = DataWindow(start: DateTime.utc(2026, 10, 23, 12));
      expect(w.contains(tagesbeginn), isTrue);
    });

    test(
      'zwei Grenzen desselben Kalendertages beurteilen denselben Messwert '
      'gleich',
      () {
        // Normalisierung im Konstruktor macht beide Grenzen für jede Abfrage
        // ununterscheidbar, unabhaengig von der Uhrzeit, zu der sie gesetzt
        // wurden. Ergaenzt die Equatable-Gruppe weiter unten, die dasselbe
        // direkt ueber `==` prueft: hier geht es um die Verhaltensgleichheit
        // bei `contains`, dort um die Objektgleichheit selbst.
        //
        // 21:30 UTC, nicht 23:30: Berlin liegt am 23.10.2026 noch auf UTC+2
        // (Umstellung erst am 25.10.), 23:30 UTC waere bereits 01:30 Berliner
        // Zeit am 24.10. -- ein anderer Kalendertag. Dieselben Eckdaten wie
        // im Pflichtfall "Grenze meint den ganzen Tag" oben.
        final morgens = DataWindow(start: DateTime.utc(2026, 10, 23, 0, 5));
        final abends = DataWindow(start: DateTime.utc(2026, 10, 23, 21, 30));
        final messwertVormittags = DateTime.utc(2026, 10, 23, 4, 40);
        final messwertVortag = DateTime.utc(2026, 10, 22, 10, 0);

        expect(
          morgens.contains(messwertVormittags),
          abends.contains(messwertVormittags),
        );
        expect(morgens.contains(messwertVormittags), isTrue);
        expect(morgens.contains(messwertVortag), abends.contains(messwertVortag));
        expect(morgens.contains(messwertVortag), isFalse);
      },
    );
  });

  group('clip: Rand- und Fehlerfaelle', () {
    test('leere Liste bleibt leer', () {
      final w = DataWindow(start: DateTime.utc(2026, 1, 1));
      expect(w.clip(<_Messwert>[], (e) => e.datum), isEmpty);
    });

    test('alle Eintraege liegen vor der Grenze -> leeres Ergebnis', () {
      final w = DataWindow(start: DateTime.utc(2026, 10, 23));
      final eintraege = [
        _Messwert(DateTime.utc(2026, 10, 1), 1),
        _Messwert(DateTime.utc(2026, 10, 22), 2),
      ];
      expect(w.clip(eintraege, (e) => e.datum), isEmpty);
    });

    test('ein Eintrag genau auf dem Tagesbeginn der Grenze bleibt drin', () {
      final grenztag = DateTime.utc(2026, 10, 23, 15);
      final w = DataWindow(start: grenztag);
      final genauAufDerGrenze = _Messwert(
        BerlinCalendar.startOfDay(grenztag),
        99,
      );
      final davor = _Messwert(DateTime.utc(2026, 10, 22, 10), 1);
      expect(
        w.clip([davor, genauAufDerGrenze], (e) => e.datum),
        [genauAufDerGrenze],
      );
    });

    test(
      'gemischte Liste: nur die Eintraege ab der Grenze bleiben, Reihenfolge '
      'bleibt erhalten',
      () {
        final w = DataWindow(start: DateTime.utc(2026, 10, 10));
        final vorDerGrenze = _Messwert(DateTime.utc(2026, 10, 5), 1);
        final anDerGrenze = _Messwert(DateTime.utc(2026, 10, 10, 8), 2);
        final nachDerGrenze = _Messwert(DateTime.utc(2026, 10, 15), 3);
        final ergebnis = w.clip(
          [vorDerGrenze, anDerGrenze, nachDerGrenze],
          (e) => e.datum,
        );
        expect(ergebnis, [anDerGrenze, nachDerGrenze]);
      },
    );
  });

  group('queryStart: Randfaelle', () {
    test('ohne Grenze gewinnt immer floor', () {
      final floor = DateTime.utc(2024, 3, 1);
      expect(DataWindow.unlimited.queryStart(floor: floor), floor);
    });

    test(
      'Grenze und floor auf demselben Tagesbeginn -> dasselbe Ergebnis, '
      'keine Bevorzugung einer Seite',
      () {
        final tagesbeginn = BerlinCalendar.startOfDay(
          DateTime.utc(2026, 5, 1, 9),
        );
        final w = DataWindow(start: DateTime.utc(2026, 5, 1, 9));
        expect(w.queryStart(floor: tagesbeginn), tagesbeginn);
      },
    );
  });

  group('dayCount: Randfaelle', () {
    test(
      'Grenztag und Endtag sind identisch -> genau ein Tag, nicht null Tage',
      () {
        final tag = DateTime.utc(2026, 6, 15, 18);
        final tagesbeginn = BerlinCalendar.startOfDay(tag);
        final w = DataWindow(start: tag);
        // through exakt der (normalisierte) Tagesbeginn der Grenze selbst:
        // start <= end gilt (Gleichheit), also kein "Zukunft"-Fall, und
        // BerlinCalendar.days(from: x, through: x) liefert laut
        // berlin_calendar_test.dart genau einen Tag.
        expect(w.dayCount(through: tagesbeginn), 1);
      },
    );

    test(
      'ueber die Oktober-2026-Zeitumstellung hinweg sind es 31 Kalendertage, '
      'nicht 30,96 — der Fall, der dieses Paket ausmacht',
      () {
        // Dieselben Eckdaten wie der Pflichtfall
        // "days zaehlt ueber die Umstellung hinweg genau 31 Tage im Oktober"
        // in berlin_calendar_test.dart. Eine Implementierung, die dayCount
        // über eine Stundendifferenz statt über BerlinCalendar.days
        // berechnet, läge hier daneben: der Oktober 2026 hat wegen der
        // Umstellung am 25.10. eine Stunde mehr als 31 * 24h.
        final w = DataWindow(start: DateTime.utc(2026, 10, 1, 5));
        expect(w.dayCount(through: DateTime.utc(2026, 10, 31, 20)), 31);
      },
    );

    test(
      'eine Grenze, die erst nach dem Endtag beginnt, liefert 0 auch wenn '
      'beide im selben Monat liegen',
      () {
        final w = DataWindow(start: DateTime.utc(2026, 11, 1));
        expect(w.dayCount(through: DateTime.utc(2026, 10, 15)), 0);
      },
    );
  });

  group('Equatable: == und hashCode', () {
    // Siehe Begründung im Dateikopf: Riverpod-Provider vergleichen ihre
    // Abhängigkeit per `==`, um unnötiges Neuberechnen zu vermeiden. Ohne
    // Wertgleichheit wäre jede neu konstruierte DataWindow ungleich jeder
    // anderen, egal wie gleich ihr Tag ist.

    test(
      'zwei Fenster aus verschiedenen Uhrzeiten desselben Tages sind gleich',
      () {
        // Derselbe Kalendertag wie im Pflichtfall "Grenze meint den ganzen
        // Tag": die Normalisierung im Konstruktor macht beide Fenster zu
        // demselben Wert, unabhängig von der Uhrzeit, zu der sie gesetzt
        // wurden.
        //
        // 21:30 UTC, nicht 23:30: siehe Begruendung in der Gruppe
        // "contains: Tagesbeginne, nicht Zeitpunkte" oben -- 23:30 UTC waere
        // bereits der 24.10. in Berlin.
        final morgens = DataWindow(start: DateTime.utc(2026, 10, 23, 0, 5));
        final abends = DataWindow(start: DateTime.utc(2026, 10, 23, 21, 30));
        expect(morgens, abends);
      },
    );

    test('zwei Fenster aus verschiedenen Tagen sind ungleich', () {
      final zehnterOktober = DataWindow(start: DateTime.utc(2026, 10, 10));
      final elfterOktober = DataWindow(start: DateTime.utc(2026, 10, 11));
      expect(zehnterOktober, isNot(equals(elfterOktober)));
    });

    test(
      'unlimited ist gleich einem Fenster ohne Grenze und ungleich jedem '
      'begrenzten Fenster',
      () {
        expect(DataWindow.unlimited, DataWindow(start: null));
        expect(
          DataWindow.unlimited,
          isNot(equals(DataWindow(start: DateTime.utc(2026, 1, 1)))),
        );
      },
    );

    test(
      'hashCode passt zu ==: zwei gleiche Fenster belegen in einem Set nur '
      'einen Platz',
      () {
        // Ein == ohne passenden hashCode faellt bei einem reinen
        // Gleichheitsvergleich nicht auf, sondern erst, wenn jemand ein Set
        // oder eine Map benutzt (Task 6/13) -- deshalb hier ueber ein Set
        // geprueft statt nur ueber einen direkten hashCode-Vergleich.
        //
        // 21:30 UTC, nicht 23:30: siehe Begruendung weiter oben in dieser
        // Gruppe -- 23:30 UTC waere bereits der 24.10. in Berlin.
        final morgens = DataWindow(start: DateTime.utc(2026, 10, 23, 0, 5));
        final abends = DataWindow(start: DateTime.utc(2026, 10, 23, 21, 30));
        final menge = {morgens, abends};
        expect(menge, hasLength(1));
        expect(morgens.hashCode, abends.hashCode);
      },
    );
  });
}

/// Testfixtur: ein minimaler Messwert mit Datum, wie ihn `clip` laut Vorlage
/// über `DailyMetrics`, `SleepNight`, `WorkoutSample` & Co. beschneidet. Die
/// Vorlage hält den KeyPath absichtlich offen, weil das Datumsfeld in diesen
/// Typen unterschiedlich heißt — hier heißt es `datum`.
class _Messwert {
  const _Messwert(this.datum, this.wert);

  final DateTime datum;
  final int wert;

  @override
  bool operator ==(Object other) =>
      other is _Messwert && other.datum == datum && other.wert == wert;

  @override
  int get hashCode => Object.hash(datum, wert);

  @override
  String toString() => '_Messwert($datum, $wert)';
}
