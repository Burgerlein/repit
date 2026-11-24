import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für **`UmfangsFortschritt.seitendifferenz`** (#493, Scheibe 3 von
/// #88) — die Zahl, die man sonst im Kopf ausrechnet: Wie weit liegen rechte
/// und linke Seite desselben Maßes auseinander?
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, nie verändert werden — sie legt fest, was
/// `Packages/trainings_core/lib/src/umfangs_fortschritt.dart` zusätzlich zu
/// leisten hat.
///
/// ## Woher die Festlegungen kommen
///
/// Issue #493 (von Tim freigegebene Scheibe 3 von #88) und als
/// Verhaltensreferenz die Swift-Vorlage: `differenceText`/`differenceDetail`
/// in `Sources/Features/Body/CircumferenceDetailView.swift` und
/// `CircumferenceProgress.deadband` in `Packages/TrainingsCore`.
///
/// ## Festgelegte öffentliche API
///
/// Neu in `Packages/trainings_core/lib/src/umfangs_fortschritt.dart`,
/// exportiert über `lib/trainings_core.dart`:
///
/// ```dart
/// /// Wer von beiden Seiten größer ist. [gleich] heißt „innerhalb der
/// /// Totzone", nicht „exakt gleich".
/// enum SeitenVergleich { diesesGroesser, partnerGroesser, gleich }
///
/// /// Wie weit dieses Maß von seinem Gegenstück entfernt liegt.
/// class UmfangsSeitendifferenz {
///   UmfangsSeitendifferenz({required this.delta, required this.vergleich});
///
///   /// Dieses Maß minus Partner, vorzeichenbehaftet — der Schirm zeigt
///   /// immer ein Maß, die Richtung ist also eindeutig. Den Betrag für
///   /// „0,4 cm" bildet die Ansicht.
///   final double delta;
///
///   /// Steht neben [delta], damit die Ansicht „beide Seiten gleich" nicht
///   /// aus dem Vorzeichen ableiten muss — die Totzone sieht man dem
///   /// Vorzeichen nicht an (derselbe Grund wie bei [UmfangsVeraenderung]).
///   final SeitenVergleich vergleich;
///
///   // `==` und `hashCode` über beide Felder.
/// }
///
/// abstract final class UmfangsFortschritt {
///   static UmfangsSeitendifferenz? seitendifferenz(
///       Umfang mass, List<Umfangsmessung> messungen);
/// }
/// ```
///
/// Vier Festlegungen, die die Signatur offen ließe:
///
/// 1. **`null` heißt „es gibt keine Seitendifferenz"** — das Maß hat keinen
///    Partner ([Umfang.partner] ist `null`), oder einer der beiden Seiten
///    fehlt jeder Wert. Beides sagt der Schirm verschieden, unterscheiden
///    kann er es an [Umfang.partner] selbst.
/// 2. **Verglichen werden die jüngsten Werte beider Seiten**, je Seite
///    unabhängig: Wer die linke Seite zuletzt vor drei Wochen gemessen hat,
///    vergleicht den heutigen rechten Wert mit dem von vor drei Wochen —
///    nicht mit nichts.
/// 3. **`delta` trägt immer die echte, vorzeichenbehaftete Differenz**, auch
///    innerhalb der Totzone — genau wie [UmfangsVeraenderung.delta]. Die
///    Totzone entscheidet nur über [vergleich].
/// 4. **Die Messungen kommen so, wie `UmfangsMerge.messungen` sie liefert:**
///    je Tag eine, aufsteigend. Die Funktion darf sich darauf nicht
///    verlassen — eigene Fälle unten reichen sie absteigend und mit zwei
///    Uhrzeiten desselben Tages herein.
///
/// ## Erfundene Zahlen
///
/// Jeder Zentimeterwert und jedes Datum in dieser Datei ist ausgedacht.
/// Echte Gesundheitswerte stehen nie im Quelltext (`CLAUDE.md`).
void main() {
  /// Ein Zeitpunkt an einem Berliner Kalendertag — UTC-Stunden zwischen 2
  /// und 21 liegen immer auf demselben Berliner Tag wie das UTC-Datum.
  DateTime zeitpunkt(int jahr, int monat, int tag, [int utcStunde = 12]) =>
      DateTime.utc(jahr, monat, tag, utcStunde);

  DateTime tagesbeginn(int jahr, int monat, int tag) =>
      BerlinCalendar.startOfDay(zeitpunkt(jahr, monat, tag));

  Umfangsmessung messung(
    int jahr,
    int monat,
    int tag,
    Map<Umfang, double> werte,
  ) => Umfangsmessung(zeitpunkt: tagesbeginn(jahr, monat, tag), werte: werte);

  group('Seitendifferenz — ohne Partner gibt es keine', () {
    test('ein Maß, das es nur einmal am Körper gibt, hat keine', () {
      // Brust, Schultern, Taille, Hals und Hüfte haben kein Gegenstück —
      // `null` heißt hier „die Frage stellt sich nicht", und der Schirm
      // sagt das anders als „es fehlt eine Seite".
      final messungen = [
        messung(2026, 9, 29, {Umfang.brust: 101.5, Umfang.taille: 83.0}),
        messung(2026, 10, 13, {Umfang.brust: 102.0, Umfang.taille: 82.5}),
      ];
      expect(
        UmfangsFortschritt.seitendifferenz(Umfang.brust, messungen),
        isNull,
      );
      expect(
        UmfangsFortschritt.seitendifferenz(Umfang.taille, messungen),
        isNull,
      );
    });
  });

  group('Seitendifferenz — solange eine Seite fehlt, gibt es keine', () {
    test('ohne Messung', () {
      expect(
        UmfangsFortschritt.seitendifferenz(Umfang.oberarmRechtsAngespannt, []),
        isNull,
      );
    });

    test('nur die eigene Seite wurde je gemessen', () {
      final messungen = [
        messung(2026, 9, 29, {Umfang.oberarmRechtsAngespannt: 29.0}),
        messung(2026, 10, 13, {Umfang.oberarmRechtsAngespannt: 29.3}),
      ];
      expect(
        UmfangsFortschritt.seitendifferenz(
          Umfang.oberarmRechtsAngespannt,
          messungen,
        ),
        isNull,
      );
    });

    test('nur der Partner wurde je gemessen', () {
      // Dieselbe Datenlage, vom rechten Maß aus gesehen: Links gibt es
      // Werte, rechts keinen einzigen — auch dann fehlt eine Seite.
      final messungen = [
        messung(2026, 10, 13, {Umfang.oberarmLinksAngespannt: 28.9}),
      ];
      expect(
        UmfangsFortschritt.seitendifferenz(
          Umfang.oberarmRechtsAngespannt,
          messungen,
        ),
        isNull,
      );
    });

    test('locker und angespannt desselben Arms sind kein Paar', () {
      // Gemeint ist die Seitendifferenz, nicht der Anspannungszuwachs:
      // Rechter Arm locker **und** angespannt gemessen ersetzt die linke
      // Seite nicht.
      final messungen = [
        messung(2026, 10, 13, {
          Umfang.oberarmRechtsAngespannt: 29.3,
          Umfang.oberarmRechtsLocker: 27.8,
        }),
      ];
      expect(
        UmfangsFortschritt.seitendifferenz(
          Umfang.oberarmRechtsAngespannt,
          messungen,
        ),
        isNull,
      );
    });
  });

  group('Seitendifferenz — dieses Maß minus Partner', () {
    test('die größere eigene Seite ergibt ein positives Delta', () {
      final differenz = UmfangsFortschritt.seitendifferenz(
        Umfang.oberarmRechtsAngespannt,
        [
          messung(2026, 10, 13, {
            Umfang.oberarmRechtsAngespannt: 29.6,
            Umfang.oberarmLinksAngespannt: 28.9,
          }),
        ],
      );
      expect(differenz, isNotNull);
      // Nicht auf Gleichheit prüfen: 29,6 − 28,9 ist in Double nicht exakt
      // 0,7.
      expect(differenz!.delta, closeTo(0.7, 1e-9));
      expect(differenz.vergleich, SeitenVergleich.diesesGroesser);
    });

    test('vom anderen Maß aus gesehen dreht sich das Vorzeichen', () {
      // Der Schirm zeigt immer ein Maß; dieselbe Datenlage heißt auf dem
      // linken Schirm „der Partner ist größer".
      final differenz = UmfangsFortschritt.seitendifferenz(
        Umfang.oberarmLinksAngespannt,
        [
          messung(2026, 10, 13, {
            Umfang.oberarmRechtsAngespannt: 29.6,
            Umfang.oberarmLinksAngespannt: 28.9,
          }),
        ],
      );
      expect(differenz!.delta, closeTo(-0.7, 1e-9));
      expect(differenz.vergleich, SeitenVergleich.partnerGroesser);
    });

    test('je Seite zählt ihre jüngste Messung — auch wenn sie älter ist', () {
      // Die Wade links wurde zuletzt am 06.09. gemessen. Der rechte Schirm
      // vergleicht den 13.10. mit dem 06.09. — nicht mit nichts und schon
      // gar nicht mit null.
      final differenz = UmfangsFortschritt.seitendifferenz(Umfang.wadeRechts, [
        messung(2026, 9, 6, {Umfang.wadeRechts: 37.5, Umfang.wadeLinks: 38.0}),
        messung(2026, 10, 13, {Umfang.wadeRechts: 38.4}),
      ]);
      expect(differenz!.delta, closeTo(0.4, 1e-9));
      expect(differenz.vergleich, SeitenVergleich.diesesGroesser);
    });

    test('die Reihenfolge der übergebenen Liste entscheidet nicht', () {
      // Jüngste zuerst ist die Reihenfolge, in der die Ablage liest. Wer
      // blind das letzte Element nimmt, vergleicht hier alte Werte und
      // bekommt Betrag und Richtung falsch.
      final absteigend = [
        messung(2026, 10, 13, {
          Umfang.oberschenkelRechts: 59.0,
          Umfang.oberschenkelLinks: 59.9,
        }),
        messung(2026, 9, 6, {
          Umfang.oberschenkelRechts: 60.5,
          Umfang.oberschenkelLinks: 58.0,
        }),
      ];
      final differenz = UmfangsFortschritt.seitendifferenz(
        Umfang.oberschenkelRechts,
        absteigend,
      );
      expect(differenz!.delta, closeTo(-0.9, 1e-9));
      expect(differenz.vergleich, SeitenVergleich.partnerGroesser);
    });

    test('am selben Tag gewinnt der spätere Zeitpunkt, nicht der frühere', () {
      // Aus `UmfangsMerge` kommt je Tag eine Messung, aus einer
      // ungefilterten Abfrage auch zwei. Der ältere Wert des Tages darf
      // nicht gewinnen, nur weil er zufällig weiter hinten in der Liste
      // steht.
      final differenz = UmfangsFortschritt.seitendifferenz(
        Umfang.unterarmRechts,
        [
          Umfangsmessung(
            zeitpunkt: zeitpunkt(2026, 10, 13, 20),
            werte: const {Umfang.unterarmRechts: 28.4},
          ),
          Umfangsmessung(
            zeitpunkt: zeitpunkt(2026, 10, 13, 7),
            werte: const {Umfang.unterarmRechts: 27.1},
          ),
          messung(2026, 9, 29, {Umfang.unterarmLinks: 27.8}),
        ],
      );
      expect(
        differenz!.delta,
        closeTo(0.6, 1e-9),
        reason:
            'es zählt der Wert von 20 Uhr (28,4), nicht der von 7 Uhr (27,1)',
      );
      expect(differenz.vergleich, SeitenVergleich.diesesGroesser);
    });
  });

  group('Seitendifferenz — die Totzone von 0,2 cm', () {
    test('exakt gleiche Seiten sind gleich', () {
      final differenz = UmfangsFortschritt.seitendifferenz(
        Umfang.oberarmRechtsLocker,
        [
          messung(2026, 10, 13, {
            Umfang.oberarmRechtsLocker: 28.0,
            Umfang.oberarmLinksLocker: 28.0,
          }),
        ],
      );
      expect(differenz!.vergleich, SeitenVergleich.gleich);
      expect(differenz.delta, 0.0);
    });

    test('0,19 cm sind noch gleich — das Delta nennt die Zahl trotzdem', () {
      // Wer vorher auf eine Nachkommastelle rundet, macht daraus 0,2 und
      // behauptet eine Differenz — deshalb steht hier genau diese Zahl.
      final differenz = UmfangsFortschritt.seitendifferenz(
        Umfang.oberarmRechtsAngespannt,
        [
          messung(2026, 10, 13, {
            Umfang.oberarmRechtsAngespannt: 29.49,
            Umfang.oberarmLinksAngespannt: 29.3,
          }),
        ],
      );
      expect(differenz!.vergleich, SeitenVergleich.gleich);
      // Wie bei `UmfangsVeraenderung`: Die Totzone entscheidet über den
      // Vergleich, nicht über die Zahl.
      expect(differenz.delta, closeTo(0.19, 1e-9));
    });

    test('auch in die andere Richtung sind 0,19 cm noch gleich', () {
      final differenz = UmfangsFortschritt.seitendifferenz(
        Umfang.oberarmLinksAngespannt,
        [
          messung(2026, 10, 13, {
            Umfang.oberarmRechtsAngespannt: 29.49,
            Umfang.oberarmLinksAngespannt: 29.3,
          }),
        ],
      );
      expect(differenz!.vergleich, SeitenVergleich.gleich);
      expect(differenz.delta, closeTo(-0.19, 1e-9));
    });

    test('0,2 cm sind keine Totzone mehr', () {
      final differenz = UmfangsFortschritt.seitendifferenz(Umfang.wadeRechts, [
        messung(2026, 10, 13, {
          Umfang.wadeRechts: 38.2,
          Umfang.wadeLinks: 38.0,
        }),
      ]);
      expect(differenz!.vergleich, SeitenVergleich.diesesGroesser);
    });

    // **Der heikelste Fall dieser Datei**, derselbe wie bei der
    // Veränderung: 33,8 − 33,6 ergibt in Double 0,19999999999999574,
    // 40,2 − 40,0 dagegen 0,20000000000000284. Dieselbe Differenz von zwei
    // Zehnteln, einmal knapp über und einmal knapp unter der Grenze. Ohne
    // die Toleranz (`totzone - 1e-9`) hießen dieselben zwei Zehntel einmal
    // „gleich" und einmal „rechts größer", je nachdem, welche Zahlen sie
    // bilden.
    test('0,2 cm bleiben 0,2 cm, egal aus welchen Zahlen sie entstehen', () {
      final aus33 = UmfangsFortschritt.seitendifferenz(Umfang.unterarmRechts, [
        messung(2026, 10, 13, {
          Umfang.unterarmRechts: 33.8,
          Umfang.unterarmLinks: 33.6,
        }),
      ]);
      expect(
        aus33!.vergleich,
        SeitenVergleich.diesesGroesser,
        reason:
            '33,8 − 33,6 ist in Double 0,19999999999999574 — ohne '
            'Epsilon-Toleranz fiele dieselbe Differenz in die Totzone',
      );
    });
  });

  group('`UmfangsSeitendifferenz` ist ein Werttyp', () {
    test('gleiche Felder sind gleich, mit gleichem `hashCode`', () {
      // Sie landet in einem abgeleiteten Provider-Wert — ohne `==` liefe
      // Abgeleitetes je Lesevorgang neu (`CLAUDE.md`, Fehler `03`).
      final messungen = [
        messung(2026, 10, 13, {
          Umfang.oberarmRechtsAngespannt: 29.6,
          Umfang.oberarmLinksAngespannt: 28.9,
        }),
      ];
      final eine = UmfangsFortschritt.seitendifferenz(
        Umfang.oberarmRechtsAngespannt,
        messungen,
      );
      final andere = UmfangsFortschritt.seitendifferenz(
        Umfang.oberarmRechtsAngespannt,
        messungen,
      );
      expect(eine, andere);
      expect(eine.hashCode, andere.hashCode);
    });

    test('ein anderes Delta macht sie ungleich', () {
      final eine = UmfangsFortschritt.seitendifferenz(
        Umfang.oberarmRechtsAngespannt,
        [
          messung(2026, 10, 13, {
            Umfang.oberarmRechtsAngespannt: 29.6,
            Umfang.oberarmLinksAngespannt: 28.9,
          }),
        ],
      );
      final andere = UmfangsFortschritt.seitendifferenz(
        Umfang.oberarmRechtsAngespannt,
        [
          messung(2026, 10, 13, {
            Umfang.oberarmRechtsAngespannt: 29.5,
            Umfang.oberarmLinksAngespannt: 28.9,
          }),
        ],
      );
      expect(eine, isNot(andere));
    });
  });
}
