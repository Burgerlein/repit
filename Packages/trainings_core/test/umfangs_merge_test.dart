import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für **`Umfangsmessung`** und **`UmfangsMerge`** (#88, Task 1.3) —
/// das Zusammenführen zweier Quellen: Die Importdatei gehört dem Dashboard,
/// die eingetippten Werte der App.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, nie verändert werden — sie legt fest, was
/// `Packages/trainings_core/lib/src/umfangs_merge.dart` zu leisten hat.
///
/// ## Woher die Festlegungen kommen
///
/// `docs/SPEC.md` 4.6 („Eine zweite Eingabe am selben Tag ändert die erste.
/// Eingetippte Werte schlagen importierte, maßweise"), der Umsetzungsplan
/// (Task 1.3) und die Swift-Vorlage `CircumferenceMerge.swift` samt
/// `CircumferenceMergeTests.swift`.
///
/// **Zusammengeführt wird beim Lesen, nicht beim Schreiben.** In der Tabelle
/// steht `quelle` im Primärschlüssel (Plan, Task 1.6); sonst überschriebe
/// der nächste Importlauf den getippten Wert, und hier gäbe es nichts mehr
/// zu entscheiden.
///
/// ## Festgelegte öffentliche API
///
/// Neu in `Packages/trainings_core/lib/src/umfangs_merge.dart` (die
/// Messung selbst darf auch in `umfang.dart` stehen), exportiert über
/// `lib/trainings_core.dart`:
///
/// ```dart
/// /// Eine Messung: ein Tag und die Maße, die an ihm gemessen wurden.
/// ///
/// /// Ein Wörterbuch und nicht fünfzehn Optionale: Leere Felder werden
/// /// nicht gespeichert, ein fehlendes Maß fehlt.
/// class Umfangsmessung {
///   Umfangsmessung({required this.zeitpunkt, required this.werte});
///
///   /// UTC-Zeitpunkt, der einen Berliner Tag bezeichnet. Was aus
///   /// [UmfangsMerge.messungen] kommt, trägt immer den **Tagesbeginn**.
///   final DateTime zeitpunkt;
///
///   final Map<Umfang, double> werte;
///
///   // `==` und `hashCode` über Zeitpunkt und Werte, siehe unten.
/// }
///
/// abstract final class UmfangsMerge {
///   static List<Umfangsmessung> messungen({
///     required List<Umfangsmessung> importiert,
///     required List<Umfangsmessung> getippt,
///   });
/// }
/// ```
///
/// **`Umfangsmessung` braucht `==` und `hashCode`, und zwar über den
/// Inhalt der Map.** Eine Liste davon ist Abhängigkeit eines Providers;
/// ohne Wertgleichheit wäre jede neu gelesene Liste ungleich der vorigen
/// und jeder abgeleitete Wert liefe neu (`CLAUDE.md`, Fehler `03`). Darts
/// `Map` vergleicht selbst nur die Identität — das muss die Klasse tun.
///
/// ## Erfundene Zahlen
///
/// Jeder Zentimeterwert und jedes Datum in dieser Datei ist ausgedacht.
/// Echte Gesundheitswerte stehen nie im Quelltext (`CLAUDE.md`).
void main() {
  /// Ein Zeitpunkt an einem Berliner Kalendertag.
  ///
  /// UTC-Stunden zwischen 2 und 21 liegen immer auf demselben Berliner Tag
  /// wie das UTC-Datum — der Versatz ist +1 oder +2 Stunden. Die
  /// Testdaten meiden den Umstellungstag; wo es auf ihn ankommt, steht es
  /// im Testnamen (`umfangs_fortschritt_test.dart`).
  DateTime zeitpunkt(int jahr, int monat, int tag, [int utcStunde = 12]) =>
      DateTime.utc(jahr, monat, tag, utcStunde);

  DateTime tagesbeginn(int jahr, int monat, int tag) =>
      BerlinCalendar.startOfDay(zeitpunkt(jahr, monat, tag));

  Umfangsmessung messung(DateTime wann, Map<Umfang, double> werte) =>
      Umfangsmessung(zeitpunkt: wann, werte: werte);

  List<Umfangsmessung> zusammengefuehrt({
    List<Umfangsmessung> importiert = const [],
    List<Umfangsmessung> getippt = const [],
  }) => UmfangsMerge.messungen(importiert: importiert, getippt: getippt);

  group('Ohne Quellen kommt nichts heraus', () {
    test('zwei leere Listen ergeben eine leere Liste', () {
      expect(zusammengefuehrt(), isEmpty);
    });
  });

  group('Eine Quelle allein bleibt stehen', () {
    test('nur importiert', () {
      final ergebnis = zusammengefuehrt(
        importiert: [
          messung(zeitpunkt(2026, 10, 4, 9), {
            Umfang.taille: 79.0,
            Umfang.hals: 37.5,
          }),
        ],
      );
      expect(ergebnis.length, 1);
      expect(ergebnis.single.werte, {Umfang.taille: 79.0, Umfang.hals: 37.5});
      expect(ergebnis.single.zeitpunkt, tagesbeginn(2026, 10, 4));
    });

    test('nur eingetippt', () {
      final ergebnis = zusammengefuehrt(
        getippt: [
          messung(zeitpunkt(2026, 10, 4, 20), {Umfang.brust: 96.5}),
        ],
      );
      expect(ergebnis.length, 1);
      expect(ergebnis.single.werte, {Umfang.brust: 96.5});
      expect(ergebnis.single.zeitpunkt, tagesbeginn(2026, 10, 4));
    });
  });

  group('Am selben Tag gewinnt der eingetippte Wert', () {
    test('je Maß, nicht je Eintrag', () {
      // Der Kern der Sache: Wer abends nur die Taille nachträgt, löscht
      // damit nicht Hals und Brust vom Morgen.
      final ergebnis = zusammengefuehrt(
        importiert: [
          messung(zeitpunkt(2026, 10, 4, 8), {
            Umfang.taille: 79.0,
            Umfang.hals: 37.5,
            Umfang.brust: 96.5,
          }),
        ],
        getippt: [
          messung(zeitpunkt(2026, 10, 4, 20), {Umfang.taille: 78.2}),
        ],
      );
      expect(ergebnis.length, 1);
      expect(ergebnis.single.werte, {
        Umfang.taille: 78.2,
        Umfang.hals: 37.5,
        Umfang.brust: 96.5,
      });
    });

    test('auch wenn der getippte Eintrag früher am Tag liegt', () {
      // Nicht die Uhrzeit entscheidet, sondern die Quelle: Der Import
      // trägt die Uhrzeit des Exports, und die sagt nichts darüber, wann
      // gemessen wurde.
      final ergebnis = zusammengefuehrt(
        importiert: [
          messung(zeitpunkt(2026, 10, 4, 21), {Umfang.taille: 79.0}),
        ],
        getippt: [
          messung(zeitpunkt(2026, 10, 4, 7), {Umfang.taille: 78.2}),
        ],
      );
      expect(ergebnis.single.werte[Umfang.taille], 78.2);
    });

    test('ein Maß, das nur der Import kennt, bleibt erhalten', () {
      final ergebnis = zusammengefuehrt(
        importiert: [
          messung(zeitpunkt(2026, 10, 4), {Umfang.wadeRechts: 38.0}),
        ],
        getippt: [
          messung(zeitpunkt(2026, 10, 4), {Umfang.wadeLinks: 37.8}),
        ],
      );
      expect(ergebnis.single.werte, {
        Umfang.wadeRechts: 38.0,
        Umfang.wadeLinks: 37.8,
      });
    });
  });

  group('Ein Tag ist ein Tag', () {
    test('verschiedene Uhrzeiten desselben Tages ergeben einen Eintrag', () {
      // Ohne Tagesgrenze stünden drei Zeilen für denselben Tag in der
      // Liste „Alle Messungen".
      final ergebnis = zusammengefuehrt(
        importiert: [
          messung(zeitpunkt(2026, 10, 4, 5), {Umfang.taille: 79.0}),
          messung(zeitpunkt(2026, 10, 4, 17), {Umfang.hals: 37.5}),
        ],
        getippt: [
          messung(zeitpunkt(2026, 10, 4, 20), {Umfang.brust: 96.5}),
        ],
      );
      expect(ergebnis.length, 1);
      expect(ergebnis.single.zeitpunkt, tagesbeginn(2026, 10, 4));
      expect(ergebnis.single.werte, {
        Umfang.taille: 79.0,
        Umfang.hals: 37.5,
        Umfang.brust: 96.5,
      });
    });

    test('die Tagesgrenze ist die Berliner, nicht die der UTC-Uhr', () {
      // 22:30 UTC ist in Berlin schon der Folgetag — im Sommer wie im
      // Winter. Wer über `DateTime.utc(...).day` gruppiert, wirft die
      // beiden Messungen in denselben Topf.
      final ergebnis = zusammengefuehrt(
        getippt: [
          messung(DateTime.utc(2026, 10, 4, 22, 30), {Umfang.taille: 79.0}),
          messung(DateTime.utc(2026, 10, 4, 6, 0), {Umfang.taille: 80.0}),
        ],
      );
      expect(ergebnis.length, 2);
      expect(ergebnis.first.zeitpunkt, tagesbeginn(2026, 10, 4));
      expect(ergebnis.last.zeitpunkt, tagesbeginn(2026, 10, 5));
      expect(ergebnis.first.werte[Umfang.taille], 80.0);
      expect(ergebnis.last.werte[Umfang.taille], 79.0);
    });

    test('zwei getippte Einträge desselben Tages: der zweite ändert den '
        'ersten', () {
      // SPEC 4.6: „Eine zweite Eingabe am selben Tag ändert die erste."
      final ergebnis = zusammengefuehrt(
        getippt: [
          messung(zeitpunkt(2026, 10, 4, 7), {
            Umfang.taille: 79.0,
            Umfang.hals: 37.5,
          }),
          messung(zeitpunkt(2026, 10, 4, 19), {Umfang.taille: 78.6}),
        ],
      );
      expect(ergebnis.length, 1);
      expect(ergebnis.single.werte, {Umfang.taille: 78.6, Umfang.hals: 37.5});
    });
  });

  group('Das Ergebnis steht aufsteigend nach Tag', () {
    test('vier Messungen aus zwei Quellen, durcheinander hereingereicht', () {
      final ergebnis = zusammengefuehrt(
        importiert: [
          messung(zeitpunkt(2026, 10, 11), {Umfang.taille: 78.0}),
          messung(zeitpunkt(2026, 9, 6), {Umfang.taille: 80.0}),
        ],
        getippt: [
          messung(zeitpunkt(2026, 10, 4), {Umfang.taille: 79.0}),
          messung(zeitpunkt(2026, 8, 2), {Umfang.taille: 81.0}),
        ],
      );
      expect(ergebnis.length, 4);
      expect(ergebnis.map((m) => m.zeitpunkt).toList(), [
        tagesbeginn(2026, 8, 2),
        tagesbeginn(2026, 9, 6),
        tagesbeginn(2026, 10, 4),
        tagesbeginn(2026, 10, 11),
      ]);
      expect(ergebnis.map((m) => m.werte[Umfang.taille]).toList(), [
        81.0,
        80.0,
        79.0,
        78.0,
      ]);
    });
  });

  group('Ein Tag ohne Werte ist keine Messung', () {
    test('leere Einträge fallen raus', () {
      // In der Liste „Alle Messungen" stünde sonst eine Zeile mit null
      // Werten.
      final ergebnis = zusammengefuehrt(
        importiert: [messung(zeitpunkt(2026, 10, 4), {})],
        getippt: [
          messung(zeitpunkt(2026, 10, 11), {}),
          messung(zeitpunkt(2026, 10, 12), {Umfang.taille: 79.0}),
        ],
      );
      expect(ergebnis.length, 1);
      expect(ergebnis.single.zeitpunkt, tagesbeginn(2026, 10, 12));
    });

    test('ein leerer Eintrag löscht nicht, was an diesem Tag schon steht', () {
      // Ein leerer getippter Eintrag ist kein Löschbefehl. Löschen ist eine
      // eigene Handlung, und die gibt es hier nicht.
      final ergebnis = zusammengefuehrt(
        importiert: [
          messung(zeitpunkt(2026, 10, 4), {Umfang.taille: 79.0}),
        ],
        getippt: [messung(zeitpunkt(2026, 10, 4), {})],
      );
      expect(ergebnis.length, 1);
      expect(ergebnis.single.werte, {Umfang.taille: 79.0});
    });
  });

  group('Die hereingereichten Messungen bleiben unberührt', () {
    test('die Werte-Map einer Quelle wird nicht verändert', () {
      // Wer beim Zusammenführen in die Map des Imports hineinschreibt,
      // ändert den Stand einer fremden Quelle — und das fiele erst beim
      // zweiten Lesen auf.
      final importMessung = messung(zeitpunkt(2026, 10, 4), {
        Umfang.taille: 79.0,
      });
      zusammengefuehrt(
        importiert: [importMessung],
        getippt: [
          messung(zeitpunkt(2026, 10, 4), {
            Umfang.taille: 78.2,
            Umfang.brust: 96.5,
          }),
        ],
      );
      expect(importMessung.werte, {Umfang.taille: 79.0});
    });
  });

  group('`Umfangsmessung` ist ein Werttyp', () {
    test('gleicher Tag und gleiche Werte sind gleich', () {
      expect(
        messung(zeitpunkt(2026, 10, 4), {Umfang.taille: 79.0}),
        messung(zeitpunkt(2026, 10, 4), {Umfang.taille: 79.0}),
      );
    });

    test('gleich heißt auch gleicher `hashCode`', () {
      expect(
        messung(zeitpunkt(2026, 10, 4), {Umfang.taille: 79.0}).hashCode,
        messung(zeitpunkt(2026, 10, 4), {Umfang.taille: 79.0}).hashCode,
      );
    });

    test('ein anderer Wert macht sie ungleich', () {
      expect(
        messung(zeitpunkt(2026, 10, 4), {Umfang.taille: 79.0}),
        isNot(messung(zeitpunkt(2026, 10, 4), {Umfang.taille: 78.2})),
      );
    });

    test('ein anderer Tag macht sie ungleich', () {
      expect(
        messung(zeitpunkt(2026, 10, 4), {Umfang.taille: 79.0}),
        isNot(messung(zeitpunkt(2026, 10, 11), {Umfang.taille: 79.0})),
      );
    });

    test('ein zusätzliches Maß macht sie ungleich', () {
      expect(
        messung(zeitpunkt(2026, 10, 4), {Umfang.taille: 79.0}),
        isNot(
          messung(zeitpunkt(2026, 10, 4), {
            Umfang.taille: 79.0,
            Umfang.hals: 37.5,
          }),
        ),
      );
    });

    test('die Reihenfolge in der Map spielt keine Rolle', () {
      expect(
        messung(zeitpunkt(2026, 10, 4), {
          Umfang.taille: 79.0,
          Umfang.hals: 37.5,
        }),
        messung(zeitpunkt(2026, 10, 4), {
          Umfang.hals: 37.5,
          Umfang.taille: 79.0,
        }),
      );
    });

    test('zwei gleiche Messungen landen einmal in einem Set', () {
      // Die Probe aufs Zusammenspiel von `==` und `hashCode`: Stimmt nur
      // eins von beidem, stehen hier zwei Einträge.
      final menge = {
        messung(zeitpunkt(2026, 10, 4), {Umfang.taille: 79.0}),
        messung(zeitpunkt(2026, 10, 4), {Umfang.taille: 79.0}),
      };
      expect(menge.length, 1);
    });

    test('zwei gleiche Ergebnislisten sind gleich', () {
      // Genau das braucht Riverpod: Eine neu gelesene, inhaltsgleiche
      // Liste darf nichts neu rechnen lassen (`CLAUDE.md`, Fehler `03`).
      List<Umfangsmessung> lauf() => zusammengefuehrt(
        importiert: [
          messung(zeitpunkt(2026, 10, 4, 8), {Umfang.taille: 79.0}),
        ],
        getippt: [
          messung(zeitpunkt(2026, 10, 4, 20), {Umfang.brust: 96.5}),
        ],
      );
      expect(lauf(), lauf());
    });
  });
}
