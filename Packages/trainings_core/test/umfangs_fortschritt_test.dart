import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für **`UmfangsFortschritt`** (#88, Task 1.4) — Richtung, Verlauf
/// und Kennzahlen je Maß: Veränderung gegen die vorige Messung, seit Start,
/// pro Monat, Spanne und wann die nächste Messung ansteht.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, nie verändert werden — sie legt fest, was
/// `Packages/trainings_core/lib/src/umfangs_fortschritt.dart` zu leisten
/// hat.
///
/// ## Woher die Festlegungen kommen
///
/// `docs/superpowers/specs/2026-10-13-umfaenge-fortschritt-design.md`, der
/// Umsetzungsplan (Task 1.4) und die Swift-Vorlage
/// `CircumferenceProgress.swift` samt `CircumferenceProgressTests.swift`.
///
/// **Jede Funktion sammelt zuerst die Werte dieses einen Maßes.** Ein Tag,
/// an dem nur die Taille nachgemessen wurde, ist für den Oberarm keine
/// Messung — sonst verglichen die Zeilen untereinander verschiedene
/// Zeiträume, ohne dass man es sähe. Eine Lücke wird nicht gefüllt, schon
/// gar nicht mit `0` (`CLAUDE.md`: „`0` ist keine Antwort auf ‚kein Wert'").
///
/// ## Festgelegte öffentliche API
///
/// Neu in `Packages/trainings_core/lib/src/umfangs_fortschritt.dart`,
/// exportiert über `lib/trainings_core.dart`:
///
/// ```dart
/// enum UmfangsRichtung { hoch, runter, unveraendert }
///
/// /// Was sich seit der vorigen Messung dieses Maßes getan hat.
/// class UmfangsVeraenderung {
///   UmfangsVeraenderung({
///     required this.delta,
///     required this.richtung,
///     required this.istFortschritt,
///   });
///
///   /// Vorzeichenbehaftet. Den Betrag für „↑ 0,4" bildet die Ansicht.
///   final double delta;
///   final UmfangsRichtung richtung;
///   final bool istFortschritt;
///
///   // `==` und `hashCode` über alle drei Felder.
/// }
///
/// abstract final class UmfangsFortschritt {
///   static const double totzone = 0.2;
///
///   static UmfangsVeraenderung? veraenderung(
///       Umfang mass, List<Umfangsmessung> messungen);
///   static double? seitStart(Umfang mass, List<Umfangsmessung> messungen);
///   static double? proMonat(Umfang mass, List<Umfangsmessung> messungen);
///   static (double niedrigster, double hoechster)? spanne(
///       Umfang mass, List<Umfangsmessung> messungen);
///   static DateTime? naechsteFaellig(List<Umfangsmessung> messungen);
/// }
/// ```
///
/// Zwei Festlegungen, die die Signatur offen ließe:
///
/// 1. **`delta` ist vorzeichenbehaftet**, genau wie `seitStart` und
///    `proMonat`. Die Richtung steht zusätzlich daneben, damit die Ansicht
///    den Pfeil nicht aus dem Vorzeichen ableiten muss.
/// 2. **Die Messungen kommen so, wie `UmfangsMerge.messungen` sie
///    liefert:** je Tag eine, aufsteigend. Die Funktionen dürfen sich
///    darauf nicht verlassen — ein eigener Fall unten reicht sie
///    absteigend herein.
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

  group('Veränderung — ohne zweiten Punkt gibt es keine', () {
    test('ohne Messung', () {
      expect(
        UmfangsFortschritt.veraenderung(Umfang.oberarmRechtsAngespannt, []),
        isNull,
      );
    });

    test('eine einzelne Messung hat nichts zum Vergleichen', () {
      // Der Zustand, der diesen Entwurf ausgelöst hat: Die Veränderung
      // gibt es, ihr fehlt nur der zweite Punkt. Auf dem Schirm steht
      // „erste Messung", nicht „±0,0".
      final messungen = [
        messung(2026, 10, 13, {
          Umfang.oberarmRechtsAngespannt: 29.3,
          Umfang.taille: 82.5,
        }),
      ];
      expect(
        UmfangsFortschritt.veraenderung(
          Umfang.oberarmRechtsAngespannt,
          messungen,
        ),
        isNull,
      );
      expect(UmfangsFortschritt.veraenderung(Umfang.taille, messungen), isNull);
    });

    test('ein Maß, das nur in einer Messung steht, hat keine Richtung', () {
      // Drei Messtage, die Wade aber nur an einem: Der Pfeil in ihrer
      // Zeile bleibt ein Strich, obwohl es drei Messungen gibt.
      final messungen = [
        messung(2026, 9, 6, {Umfang.taille: 83.0}),
        messung(2026, 9, 20, {Umfang.taille: 82.7}),
        messung(2026, 10, 4, {Umfang.taille: 82.5, Umfang.wadeLinks: 38.0}),
      ];
      expect(
        UmfangsFortschritt.veraenderung(Umfang.wadeLinks, messungen),
        isNull,
      );
    });

    test('ein Maß, das in keiner Messung steht, hat keine Richtung', () {
      final messungen = [
        messung(2026, 9, 6, {Umfang.taille: 83.0}),
        messung(2026, 10, 4, {Umfang.taille: 82.5}),
      ];
      expect(
        UmfangsFortschritt.veraenderung(Umfang.unterarmRechts, messungen),
        isNull,
      );
    });
  });

  group('Veränderung — Betrag und Richtung', () {
    test('ein größerer Wert zeigt aufwärts', () {
      final veraenderung = UmfangsFortschritt.veraenderung(
        Umfang.oberarmRechtsAngespannt,
        [
          messung(2026, 9, 29, {Umfang.oberarmRechtsAngespannt: 28.9}),
          messung(2026, 10, 13, {Umfang.oberarmRechtsAngespannt: 29.3}),
        ],
      );
      expect(veraenderung, isNotNull);
      // Nicht auf Gleichheit prüfen: 29,3 − 28,9 ist in Double nicht exakt
      // 0,4.
      expect(veraenderung!.delta, closeTo(0.4, 1e-9));
      expect(veraenderung.richtung, UmfangsRichtung.hoch);
    });

    test('ein kleinerer Wert zeigt abwärts', () {
      final veraenderung = UmfangsFortschritt.veraenderung(Umfang.taille, [
        messung(2026, 9, 29, {Umfang.taille: 83.2}),
        messung(2026, 10, 13, {Umfang.taille: 82.5}),
      ]);
      expect(veraenderung!.delta, closeTo(-0.7, 1e-9));
      expect(veraenderung.richtung, UmfangsRichtung.runter);
    });

    test('verglichen wird mit der letzten Messung, die das Maß hat', () {
      // Am 20.09. wurde nur die Taille nachgemessen. Der Oberarm vergleicht
      // deshalb den 04.10. mit dem 06.09. — nicht mit nichts und schon gar
      // nicht mit null.
      final messungen = [
        messung(2026, 9, 6, {
          Umfang.oberarmRechtsAngespannt: 29.0,
          Umfang.taille: 83.0,
        }),
        messung(2026, 9, 20, {Umfang.taille: 82.7}),
        messung(2026, 10, 4, {
          Umfang.oberarmRechtsAngespannt: 29.6,
          Umfang.taille: 82.5,
        }),
      ];
      final arm = UmfangsFortschritt.veraenderung(
        Umfang.oberarmRechtsAngespannt,
        messungen,
      );
      expect(arm!.delta, closeTo(0.6, 1e-9));
      expect(arm.richtung, UmfangsRichtung.hoch);
      // Die Taille kennt die Lücke nicht und vergleicht wie gewohnt.
      final taille = UmfangsFortschritt.veraenderung(Umfang.taille, messungen);
      expect(taille!.delta, closeTo(-0.2, 1e-9));
    });

    test('die Reihenfolge der übergebenen Liste entscheidet nicht', () {
      // Jüngste zuerst ist die Reihenfolge, in der die Ablage liest
      // (Plan, Task 2.1: „absteigend nach Tag"). Wer blind die letzten
      // beiden Elemente nimmt, bekommt hier das Vorzeichen falsch herum.
      final absteigend = [
        messung(2026, 10, 13, {Umfang.oberarmRechtsAngespannt: 29.3}),
        messung(2026, 9, 29, {Umfang.oberarmRechtsAngespannt: 28.9}),
      ];
      final veraenderung = UmfangsFortschritt.veraenderung(
        Umfang.oberarmRechtsAngespannt,
        absteigend,
      );
      expect(veraenderung!.delta, closeTo(0.4, 1e-9));
      expect(veraenderung.richtung, UmfangsRichtung.hoch);
    });

    test('zwei gleiche Werte stehen still', () {
      final veraenderung = UmfangsFortschritt.veraenderung(Umfang.huefte, [
        messung(2026, 9, 29, {Umfang.huefte: 95.0}),
        messung(2026, 10, 13, {Umfang.huefte: 95.0}),
      ]);
      expect(veraenderung!.richtung, UmfangsRichtung.unveraendert);
      expect(veraenderung.delta, 0.0);
    });
  });

  group('Die Totzone von 0,2 cm', () {
    test('sie liegt bei 0,2 und steht als Konstante da', () {
      // Maßband, Zugspannung und Messstelle streuen zu stark, als dass ein
      // Zehntel eine Aussage wäre.
      expect(UmfangsFortschritt.totzone, 0.2);
    });

    test('0,19 cm sind noch Totzone', () {
      // Wer vorher auf eine Nachkommastelle rundet, macht daraus 0,2 und
      // zeigt einen Pfeil — deshalb steht hier genau diese Zahl.
      final veraenderung = UmfangsFortschritt.veraenderung(
        Umfang.oberarmRechtsAngespannt,
        [
          messung(2026, 9, 29, {Umfang.oberarmRechtsAngespannt: 29.3}),
          messung(2026, 10, 13, {Umfang.oberarmRechtsAngespannt: 29.49}),
        ],
      );
      expect(veraenderung!.richtung, UmfangsRichtung.unveraendert);
    });

    test('0,2 cm sind keine Totzone mehr', () {
      // Die Grenze gehört zur Bewegung: unter 0,2 ein Strich, ab 0,2 ein
      // Pfeil.
      final veraenderung = UmfangsFortschritt.veraenderung(Umfang.hals, [
        messung(2026, 9, 29, {Umfang.hals: 40.0}),
        messung(2026, 10, 13, {Umfang.hals: 40.2}),
      ]);
      expect(veraenderung!.richtung, UmfangsRichtung.hoch);
    });

    // **Der heikelste Fall dieser Datei.** 40,2 − 40,0 ergibt in Double
    // 0,20000000000000284, 33,8 − 33,6 dagegen 0,19999999999999574.
    // Dieselbe Differenz von zwei Zehnteln, einmal knapp über und einmal
    // knapp unter der Grenze. Ohne Toleranz (`totzone - 1e-9`) bekäme sie
    // einmal einen Pfeil und einmal einen Strich, je nachdem, welche
    // Zahlen sie bilden — und niemand könnte erklären, warum.
    test('0,2 cm bleiben 0,2 cm, egal aus welchen Zahlen sie entstehen', () {
      final aus33 = UmfangsFortschritt.veraenderung(Umfang.unterarmRechts, [
        messung(2026, 9, 29, {Umfang.unterarmRechts: 33.6}),
        messung(2026, 10, 13, {Umfang.unterarmRechts: 33.8}),
      ]);
      final aus40 = UmfangsFortschritt.veraenderung(Umfang.hals, [
        messung(2026, 9, 29, {Umfang.hals: 40.0}),
        messung(2026, 10, 13, {Umfang.hals: 40.2}),
      ]);
      expect(
        aus33!.richtung,
        UmfangsRichtung.hoch,
        reason:
            '33,8 − 33,6 ist in Double 0,19999999999999574 — ohne '
            'Epsilon-Toleranz fiele dieselbe Bewegung in die Totzone',
      );
      expect(aus33.richtung, aus40!.richtung);
    });

    test('auch abwärts', () {
      final veraenderung = UmfangsFortschritt.veraenderung(Umfang.taille, [
        messung(2026, 9, 29, {Umfang.taille: 83.8}),
        messung(2026, 10, 13, {Umfang.taille: 83.6}),
      ]);
      expect(veraenderung!.richtung, UmfangsRichtung.runter);
    });
  });

  group('Was Fortschritt ist, hängt am Maß', () {
    test('beim Oberarm ist aufwärts Fortschritt', () {
      final veraenderung = UmfangsFortschritt.veraenderung(
        Umfang.oberarmRechtsAngespannt,
        [
          messung(2026, 9, 29, {Umfang.oberarmRechtsAngespannt: 28.9}),
          messung(2026, 10, 13, {Umfang.oberarmRechtsAngespannt: 29.3}),
        ],
      );
      expect(veraenderung!.istFortschritt, isTrue);
    });

    test('beim Oberarm ist abwärts kein Fortschritt', () {
      final veraenderung = UmfangsFortschritt.veraenderung(
        Umfang.oberarmRechtsAngespannt,
        [
          messung(2026, 9, 29, {Umfang.oberarmRechtsAngespannt: 29.3}),
          messung(2026, 10, 13, {Umfang.oberarmRechtsAngespannt: 28.9}),
        ],
      );
      expect(veraenderung!.richtung, UmfangsRichtung.runter);
      expect(veraenderung.istFortschritt, isFalse);
    });

    test('bei der Taille ist abwärts Fortschritt', () {
      // Die Regel steckt als `wenigerIstBesser` im Maß und nicht in der
      // Farbe der Ansicht.
      final veraenderung = UmfangsFortschritt.veraenderung(Umfang.taille, [
        messung(2026, 9, 29, {Umfang.taille: 83.2}),
        messung(2026, 10, 13, {Umfang.taille: 82.5}),
      ]);
      expect(veraenderung!.richtung, UmfangsRichtung.runter);
      expect(veraenderung.istFortschritt, isTrue);
    });

    test('bei der Taille ist aufwärts kein Fortschritt', () {
      final veraenderung = UmfangsFortschritt.veraenderung(Umfang.taille, [
        messung(2026, 9, 29, {Umfang.taille: 82.5}),
        messung(2026, 10, 13, {Umfang.taille: 83.2}),
      ]);
      expect(veraenderung!.richtung, UmfangsRichtung.hoch);
      expect(veraenderung.istFortschritt, isFalse);
    });

    test('in der Totzone ist nichts Fortschritt — auch nicht bei der '
        'Taille', () {
      // Grau, nicht grün: Eine Zahl, die im Rauschen liegt, ist kein
      // Erfolg.
      final arm = UmfangsFortschritt.veraenderung(
        Umfang.oberarmRechtsAngespannt,
        [
          messung(2026, 9, 29, {Umfang.oberarmRechtsAngespannt: 29.3}),
          messung(2026, 10, 13, {Umfang.oberarmRechtsAngespannt: 29.3}),
        ],
      );
      final taille = UmfangsFortschritt.veraenderung(Umfang.taille, [
        messung(2026, 9, 29, {Umfang.taille: 82.5}),
        messung(2026, 10, 13, {Umfang.taille: 82.5}),
      ]);
      expect(arm!.richtung, UmfangsRichtung.unveraendert);
      expect(arm.istFortschritt, isFalse);
      expect(taille!.richtung, UmfangsRichtung.unveraendert);
      expect(taille.istFortschritt, isFalse);
    });
  });

  group('`UmfangsVeraenderung` ist ein Werttyp', () {
    test('gleiche Felder sind gleich, mit gleichem `hashCode`', () {
      // Sie ist Abhängigkeit eines Providers (Plan, Global Constraints).
      final messungen = [
        messung(2026, 9, 29, {Umfang.taille: 83.2}),
        messung(2026, 10, 13, {Umfang.taille: 82.5}),
      ];
      final eine = UmfangsFortschritt.veraenderung(Umfang.taille, messungen);
      final andere = UmfangsFortschritt.veraenderung(Umfang.taille, messungen);
      expect(eine, andere);
      expect(eine.hashCode, andere.hashCode);
    });

    test('ein anderer Betrag macht sie ungleich', () {
      final eine = UmfangsFortschritt.veraenderung(Umfang.taille, [
        messung(2026, 9, 29, {Umfang.taille: 83.2}),
        messung(2026, 10, 13, {Umfang.taille: 82.5}),
      ]);
      final andere = UmfangsFortschritt.veraenderung(Umfang.taille, [
        messung(2026, 9, 29, {Umfang.taille: 83.2}),
        messung(2026, 10, 13, {Umfang.taille: 82.4}),
      ]);
      expect(eine, isNot(andere));
    });
  });

  group('Seit Start', () {
    test('ohne Messung gibt es keinen Wert', () {
      expect(UmfangsFortschritt.seitStart(Umfang.taille, []), isNull);
    });

    test('solange die erste Messung die aktuelle ist, fällt er weg', () {
      expect(
        UmfangsFortschritt.seitStart(Umfang.oberarmRechtsAngespannt, [
          messung(2026, 10, 13, {Umfang.oberarmRechtsAngespannt: 29.3}),
        ]),
        isNull,
      );
    });

    test('gerechnet wird über alle Messungen hinweg', () {
      final messungen = [
        messung(2026, 8, 2, {
          Umfang.oberarmRechtsAngespannt: 27.9,
          Umfang.taille: 83.5,
        }),
        messung(2026, 9, 6, {
          Umfang.oberarmRechtsAngespannt: 28.6,
          Umfang.taille: 83.0,
        }),
        messung(2026, 10, 13, {
          Umfang.oberarmRechtsAngespannt: 29.3,
          Umfang.taille: 82.5,
        }),
      ];
      expect(
        UmfangsFortschritt.seitStart(Umfang.oberarmRechtsAngespannt, messungen),
        closeTo(1.4, 1e-9),
      );
      expect(
        UmfangsFortschritt.seitStart(Umfang.taille, messungen),
        closeTo(-1.0, 1e-9),
      );
    });

    test('genommen wird die erste Messung, die das Maß hat', () {
      final messungen = [
        messung(2026, 8, 2, {Umfang.taille: 83.5}),
        messung(2026, 9, 6, {Umfang.oberarmRechtsAngespannt: 28.6}),
        messung(2026, 10, 13, {Umfang.oberarmRechtsAngespannt: 29.3}),
      ];
      expect(
        UmfangsFortschritt.seitStart(Umfang.oberarmRechtsAngespannt, messungen),
        closeTo(0.7, 1e-9),
      );
      // Die Taille steht nur einmal da und bleibt ohne Wert.
      expect(UmfangsFortschritt.seitStart(Umfang.taille, messungen), isNull);
    });

    test('seit Start kennt keine Totzone', () {
      // Die Spalte nennt die Zahl; der Strich gilt dem Pfeil daneben.
      expect(
        UmfangsFortschritt.seitStart(Umfang.hals, [
          messung(2026, 8, 2, {Umfang.hals: 39.7}),
          messung(2026, 10, 13, {Umfang.hals: 39.8}),
        ]),
        closeTo(0.1, 1e-9),
      );
    });
  });

  group('Pro Monat', () {
    test('ohne zwei Messungen gibt es keine Rate', () {
      expect(
        UmfangsFortschritt.proMonat(Umfang.oberarmRechtsAngespannt, []),
        isNull,
      );
      expect(
        UmfangsFortschritt.proMonat(Umfang.oberarmRechtsAngespannt, [
          messung(2026, 10, 13, {Umfang.oberarmRechtsAngespannt: 29.3}),
        ]),
        isNull,
      );
    });

    test('0,5 cm in 14 Tagen sind rund 1,09 cm im Monat', () {
      // 0,5 / 14 · 30,44 = 1,0871. Ein mittlerer Monat: Auf den Tag genau
      // zu rechnen hieße, dem Maßband eine Genauigkeit zu unterstellen,
      // die es nicht hat.
      expect(
        UmfangsFortschritt.proMonat(Umfang.oberarmRechtsAngespannt, [
          messung(2026, 9, 29, {Umfang.oberarmRechtsAngespannt: 29.0}),
          messung(2026, 10, 13, {Umfang.oberarmRechtsAngespannt: 29.5}),
        ]),
        closeTo(1.0871, 0.001),
      );
    });

    test('eine schrumpfende Taille ergibt eine negative Rate', () {
      expect(
        UmfangsFortschritt.proMonat(Umfang.taille, [
          messung(2026, 9, 29, {Umfang.taille: 83.0}),
          messung(2026, 10, 13, {Umfang.taille: 82.5}),
        ]),
        closeTo(-1.0871, 0.001),
      );
    });

    test('gerechnet wird in Kalendertagen, nicht in 86400 Sekunden', () {
      // Zwischen dem 20.03. und dem 03.04.2026 liegt die Umstellung auf
      // Sommerzeit: vierzehn Kalendertage, aber nur 335 Stunden. Die
      // beiden Berliner Tagesbeginne sind 13 Tage und 23 Stunden
      // auseinander, und `Duration.inDays` schneidet ab — wer so rechnet,
      // teilt durch 13 und zeigt eine Rate, die es nicht gibt.
      expect(
        UmfangsFortschritt.proMonat(Umfang.taille, [
          messung(2026, 3, 20, {Umfang.taille: 83.0}),
          messung(2026, 4, 3, {Umfang.taille: 82.5}),
        ]),
        closeTo(-1.0871, 0.001),
      );
    });

    test('zwei Messungen desselben Tages ergeben keine Rate', () {
      // Sonst wäre es eine Division durch null, und auf dem Schirm stünde
      // „inf cm pro Monat".
      expect(
        UmfangsFortschritt.proMonat(Umfang.oberarmRechtsAngespannt, [
          Umfangsmessung(
            zeitpunkt: tagesbeginn(2026, 10, 13),
            werte: const {Umfang.oberarmRechtsAngespannt: 29.0},
          ),
          Umfangsmessung(
            zeitpunkt: tagesbeginn(2026, 10, 13),
            werte: const {Umfang.oberarmRechtsAngespannt: 29.5},
          ),
        ]),
        isNull,
      );
    });

    test('auch zwei Uhrzeiten desselben Tages ergeben keine Rate', () {
      // Aus `UmfangsMerge` kommt das nicht, aus einer ungefilterten
      // Abfrage schon.
      expect(
        UmfangsFortschritt.proMonat(Umfang.taille, [
          Umfangsmessung(
            zeitpunkt: zeitpunkt(2026, 10, 13, 7),
            werte: const {Umfang.taille: 83.0},
          ),
          Umfangsmessung(
            zeitpunkt: zeitpunkt(2026, 10, 13, 20),
            werte: const {Umfang.taille: 82.5},
          ),
        ]),
        isNull,
      );
    });
  });

  group('Spanne', () {
    test('ohne Messung dieses Maßes gibt es keine', () {
      expect(
        UmfangsFortschritt.spanne(Umfang.oberarmRechtsAngespannt, []),
        isNull,
      );
      expect(
        UmfangsFortschritt.spanne(Umfang.oberarmRechtsAngespannt, [
          messung(2026, 10, 13, {Umfang.taille: 82.5}),
        ]),
        isNull,
      );
    });

    test('eine Messung ist ihr eigener kleinster und größter Wert', () {
      final spanne = UmfangsFortschritt.spanne(Umfang.oberarmRechtsAngespannt, [
        messung(2026, 10, 13, {Umfang.oberarmRechtsAngespannt: 29.3}),
      ]);
      expect(spanne, (29.3, 29.3));
    });

    test('der größte Wert wird auch in der Mitte gefunden', () {
      // Wer nur Anfang und Ende vergleicht, verfehlt ihn.
      final spanne = UmfangsFortschritt.spanne(Umfang.oberarmRechtsAngespannt, [
        messung(2026, 8, 2, {Umfang.oberarmRechtsAngespannt: 29.0}),
        messung(2026, 9, 6, {Umfang.oberarmRechtsAngespannt: 30.1}),
        messung(2026, 10, 13, {Umfang.oberarmRechtsAngespannt: 29.6}),
      ]);
      expect(spanne, (29.0, 30.1));
    });

    test('Tage ohne dieses Maß werden übersprungen', () {
      final spanne = UmfangsFortschritt.spanne(Umfang.oberarmRechtsAngespannt, [
        messung(2026, 8, 2, {Umfang.taille: 83.5}),
        messung(2026, 9, 6, {Umfang.oberarmRechtsAngespannt: 28.6}),
        messung(2026, 10, 13, {Umfang.oberarmRechtsAngespannt: 29.3}),
      ]);
      expect(spanne, (28.6, 29.3));
    });
  });

  group('Nächste Messung fällig', () {
    test('ohne Messung steht nichts an', () {
      expect(UmfangsFortschritt.naechsteFaellig([]), isNull);
    });

    test('zwei Wochen nach der jüngsten Messung, auf den Tagesbeginn', () {
      // Der Satz „sinnvoll ist das etwa ab dem 27.10." wird gerechnet und
      // nicht eingetippt. Die Uhrzeit des Eintragens spielt keine Rolle.
      final faellig = UmfangsFortschritt.naechsteFaellig([
        messung(2026, 9, 29, {Umfang.taille: 83.0}),
        Umfangsmessung(
          zeitpunkt: zeitpunkt(2026, 10, 13, 19),
          werte: const {Umfang.taille: 82.5},
        ),
      ]);
      expect(faellig, tagesbeginn(2026, 10, 27));
    });

    test('die zwei Wochen zählen Kalendertage, keine 86400 Sekunden', () {
      // In der Nacht zum 25.10.2026 endet die Sommerzeit. Vierzehnmal
      // 86400 Sekunden landen deshalb am 26.10. um 23 Uhr statt am 27.10.
      final faellig = UmfangsFortschritt.naechsteFaellig([
        messung(2026, 10, 13, {Umfang.taille: 82.5}),
      ]);
      expect(faellig, tagesbeginn(2026, 10, 27));
      expect(
        faellig,
        isNot(tagesbeginn(2026, 10, 13).add(const Duration(days: 14))),
      );
    });

    test('maßgeblich ist die jüngste Messung, nicht die letzte der Liste', () {
      final faellig = UmfangsFortschritt.naechsteFaellig([
        messung(2026, 10, 13, {Umfang.taille: 82.5}),
        messung(2026, 8, 2, {Umfang.taille: 83.5}),
        messung(2026, 9, 6, {Umfang.taille: 83.0}),
      ]);
      expect(faellig, tagesbeginn(2026, 10, 27));
    });

    test('es zählt jede Messung, gleich welches Maß sie trägt', () {
      // Gemessen wird der ganze Körper auf einmal; der Termin hängt nicht
      // an einem einzelnen Maß.
      final faellig = UmfangsFortschritt.naechsteFaellig([
        messung(2026, 9, 29, {Umfang.taille: 83.0}),
        messung(2026, 10, 13, {Umfang.wadeLinks: 37.8}),
      ]);
      expect(faellig, tagesbeginn(2026, 10, 27));
    });
  });
}
