import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Die Formel hinter der Verlaufszeile „Alkohol-Tage" (#125): **Ein Tag mit
/// Alkohol > 0 ist ein Alkohol-Tag.**
///
/// Bis heute sagte die Zeile „trägst du selbst ein" und blieb stumm. Die
/// Zahl liegt aber vor: Apple Health führt die Zahl der alkoholischen
/// Getränke je Tag. Die Rechnung gehört damit in den Kern, nicht in den
/// Schirm — er bekommt Zahlen und Daten, keine fertigen Sätze.
///
/// **Getränke, nicht Gramm.** #125 nannte einen Nährwert `dietaryAlcohol`;
/// den gibt es in HealthKit nicht (nachgesehen im iOS-26.1-SDK, belegt in
/// `app/ios/RunnerTests/HealthChannelAlcoholTests.swift`). Der einzige
/// Tagebuch-Typ ist `NumberOfAlcoholicBeverages` mit der Einheit `count`.
/// Für diese Formel ändert das nichts — sie fragt „mehr als nichts?" —,
/// wohl aber den Namen des Feldes: `drinks`, nicht `grams`. Ein Feld, das
/// Gramm verspricht und eine Stückzahl trägt, wäre genau die Art Zusage,
/// die `CLAUDE.md` verbietet.
///
/// ## Was diese Datei festlegt
///
/// Zwei Dinge, die der Schirm braucht und die beide Rechnungen sind:
///
/// 1. **Welche Tage zählen** — [AlcoholDays.from] wandelt Tageswerte
///    (Datum und Getränkezahl, die Zahl nullbar) in die Liste der
///    Alkohol-Tage.
/// 2. **Wann zuletzt** — [AlcoholDays.last] nennt den jüngsten davon.
///
/// **Der Schnappschuss liest [AlcoholDays.last] seit #268 nicht mehr.** Die
/// Zeile sagt nicht mehr „zuletzt am …", sondern ob am **Vortag** des
/// gezeigten Tages etwas erfasst ist; das steht in `alcohol_eve_test.dart`.
/// Was der Schnappschuss aus dem Fenster weiter rechnet, ist die **Zahl**
/// der Alkohol-Tage — und die prüft die letzte Gruppe hier.
///
/// ## Die drei Fälle, die auseinandergehalten werden müssen
///
/// | Getränke | Bedeutung | Alkohol-Tag? |
/// |---|---|---|
/// | größer 0 | getrunken | **ja** |
/// | genau 0 | gemessen, nichts | nein |
/// | `null` | **kein Wert** | nein — und das ist keine Aussage |
///
/// Die dritte Zeile ist die wichtige. Apple verrät den Lesestatus nicht,
/// „keine Daten" und „nicht freigegeben" sind nicht unterscheidbar
/// (`CLAUDE.md`). Ein `null` darf deshalb niemals wie eine gemessene Null
/// wirken: Es macht den Tag zu keinem Alkohol-Tag, aber es belegt auch
/// nicht, dass keiner war. Was der Schirm aus einer leeren Liste macht,
/// entscheidet der Schirm — der Kern behauptet hier nichts.
///
/// **Die Zeile zählt, sie bewertet nicht.** Kein Schwellenwert, keine
/// Empfehlung, keine Farbe: Deshalb steht hier nur eine Liste von Tagen und
/// nirgends ein Urteil darüber, ob es zu viele sind.
///
/// ## Erfundene Zahlen, erfundene Tage
///
/// Jede Zahl in dieser Datei ist ausgedacht. Echte Gesundheitsdaten stehen
/// nie im Quelltext (`CLAUDE.md`), und bei diesem Wert gilt das doppelt.
void main() {
  /// Ein Berliner Kalendertag im Juli — Sommerzeit, also UTC+2. Der Monat
  /// ist mit Absicht weit von jeder Umstellung entfernt, damit die Fälle
  /// zur Tagesgrenze unten genau eine Sache prüfen.
  DateTime juli(int tag, [int stundeUtc = 6]) =>
      DateTime.utc(2026, 7, tag, stundeUtc);

  DateTime julitag(int tag) => BerlinCalendar.startOfDay(juli(tag));

  ({DateTime date, double? drinks}) eintrag(DateTime date, double? drinks) =>
      (date: date, drinks: drinks);

  group('AlcoholDays.from — ein Tag mit Alkohol über 0 zählt', () {
    test('ein Tag mit mehr als 0 Getränken ist ein Alkohol-Tag', () {
      final tage = AlcoholDays.from([eintrag(juli(14), 2)]);

      expect(tage, [julitag(14)]);
    });

    test('ein halbes Getränk zählt auch — die Grenze ist 0, nicht 1', () {
      final tage = AlcoholDays.from([eintrag(juli(14), 0.5)]);

      expect(
        tage,
        [julitag(14)],
        reason:
            'die Regel heißt „größer 0", nicht „mindestens ein ganzes '
            'Getränk" — eine zweite Schwelle wäre eine Bewertung',
      );
    });

    test('genau 0 Getränke ist kein Alkohol-Tag', () {
      final tage = AlcoholDays.from([eintrag(juli(14), 0)]);

      expect(
        tage,
        isEmpty,
        reason: '0 ist ein gemessener Wert und heißt: an diesem Tag nichts',
      );
    });

    test('ein Tag ohne Wert ist kein Alkohol-Tag — und keine Aussage', () {
      final tage = AlcoholDays.from([eintrag(juli(14), null)]);

      expect(
        tage,
        isEmpty,
        reason:
            '„keine Daten" und „nicht freigegeben" sind nicht '
            'unterscheidbar; null darf nicht wie eine gemessene Null wirken, '
            'aber es belegt eben auch nichts',
      );
    });

    test('ein negativer Wert fällt heraus', () {
      final tage = AlcoholDays.from([eintrag(juli(14), -3)]);

      expect(
        tage,
        isEmpty,
        reason:
            'negative Getränke gibt es nicht; ein solcher Wert ist ein '
            'Datenfehler und keine Angabe über einen Abend',
      );
    });

    test('keine Eingabe, keine Tage', () {
      expect(AlcoholDays.from(const []), isEmpty);
    });

    test('aus vielen Tagen bleiben genau die mit Wert über 0', () {
      final tage = AlcoholDays.from([
        eintrag(juli(10), null),
        eintrag(juli(11), 0),
        eintrag(juli(12), 3),
        eintrag(juli(13), null),
        eintrag(juli(14), 1.5),
        eintrag(juli(15), 0),
      ]);

      expect(tage, [julitag(12), julitag(14)]);
    });
  });

  group('AlcoholDays.from — Reihenfolge, Doppel und Tagesgrenzen', () {
    test('die Tage kommen aufsteigend heraus, egal wie sie hereinkommen', () {
      final tage = AlcoholDays.from([
        eintrag(juli(20), 1),
        eintrag(juli(12), 1),
        eintrag(juli(17), 1),
      ]);

      expect(tage, [julitag(12), julitag(17), julitag(20)]);
    });

    test('zwei Werte desselben Kalendertags ergeben einen Tag, nicht zwei', () {
      final tage = AlcoholDays.from([
        eintrag(juli(14, 7), 1),
        eintrag(juli(14, 19), 2),
      ]);

      expect(
        tage,
        [julitag(14)],
        reason: 'gezählt werden Tage, nicht Messpunkte',
      );
    });

    test('ein Tag ohne Wert nimmt demselben Tag seinen Wert nicht weg', () {
      final tage = AlcoholDays.from([
        eintrag(juli(14, 7), null),
        eintrag(juli(14, 19), 2),
      ]);

      expect(tage, [julitag(14)]);
    });

    test('jeder Tag steht auf der Berliner Tagesgrenze', () {
      final tage = AlcoholDays.from([eintrag(juli(14, 15), 1)]);

      expect(tage.single, julitag(14));
      expect(tage.single.isUtc, isTrue);
    });

    test('22:30 UTC im Juli ist in Berlin schon der Folgetag', () {
      // Sommerzeit, UTC+2: 22:30 UTC am 14. ist 00:30 am 15. in Berlin.
      final tage = AlcoholDays.from([eintrag(juli(14, 22).add(const Duration(minutes: 30)), 1)]);

      expect(tage, [julitag(15)]);
    });
  });

  group('AlcoholDays.last — wann zuletzt', () {
    test('liefert den jüngsten Tag', () {
      expect(
        AlcoholDays.last([julitag(12), julitag(14), julitag(13)]),
        julitag(14),
      );
    });

    test('ohne Alkohol-Tag gibt es kein Datum', () {
      expect(
        AlcoholDays.last(const []),
        isNull,
        reason: 'ein erfundenes „zuletzt" wäre schlimmer als gar keines',
      );
    });

    test('ein einzelner Tag ist auch der letzte', () {
      expect(AlcoholDays.last([julitag(14)]), julitag(14));
    });

    test('der letzte Tag einer from-Liste ist ihr letzter Eintrag', () {
      final tage = AlcoholDays.from([
        eintrag(juli(20), 1),
        eintrag(juli(12), 1),
      ]);

      expect(AlcoholDays.last(tage), tage.last);
    });
  });

  group('RecoverySnapshot — nur was im Fenster liegt, zählt', () {
    /// Der Bezugstag aller Fälle: 20.07.2026, mittags Berliner Zeit.
    final heute = juli(20, 10);

    RecoverySnapshot schnappschuss(List<DateTime> alkoholTage) =>
        RecoverySnapshot.make(
          days: const [],
          nights: const [],
          today: heute,
          sleepGoalHours: 7.5,
          bedtimeGoalMinutes: 270,
          alcoholDays: alkoholTage,
        );

    int anzahl(List<DateTime> alkoholTage) =>
        schnappschuss(alkoholTage).trends
            .firstWhere((t) => t.kind == RecoveryTrendKind.alcoholDays)
            .count;

    test('ohne Alkohol-Tage bleibt die Zahl 0', () {
      expect(anzahl(const []), 0);
    });

    test('ein Tag im Fenster zählt, egal zu welcher Uhrzeit er ankam', () {
      expect(anzahl([juli(14, 19)]), 1);
    });

    test('mehrere Tage im Fenster zählen einzeln', () {
      expect(anzahl([juli(12), juli(18), juli(15)]), 3);
    });

    test('ein Tag vor dem Fenster zählt nicht', () {
      // Das Fenster sind 30 Kalendertage einschließlich heute, also ab dem
      // 21.06.2026. Der 01.06. liegt davor.
      final vorDemFenster = DateTime.utc(2026, 6, 1, 6);

      expect(anzahl([vorDemFenster]), 0);
    });

    test('ein Tag aus der Zukunft zählt nicht', () {
      expect(
        anzahl([juli(25)]),
        0,
        reason:
            'ein Zeitstempel aus der Zukunft ist ein Gerät mit verstellter '
            'Uhr, kein Alkohol-Tag',
      );
    });

    test('heute selbst liegt im Fenster', () {
      expect(anzahl([heute]), 1);
    });

    test('die Zeile trägt keinen Durchschnitt', () {
      final zeile = schnappschuss([juli(12), juli(18)]).trends
          .firstWhere((t) => t.kind == RecoveryTrendKind.alcoholDays);

      expect(zeile.count, 2, reason: 'nur die beiden im Fenster');
      expect(
        zeile.average,
        isNull,
        reason: 'ein Schnitt über Ja/Nein ist nichts',
      );
    });
  });
}
