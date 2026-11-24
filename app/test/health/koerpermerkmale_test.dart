// Körpergröße und Geburtsjahr aus Apple Health (#306) — die Dart-Seite des
// Kanals: der Transporttyp, sein Codec und die Attrappe.
//
// **Warum es dieses Ticket gibt.** `kalorienziel` aus `trainings_core`
// rechnet ohne Größe und Alter **nichts** — Mifflin-St Jeor braucht Gewicht,
// Größe und Alter, und ein geschätztes Alter wäre eine stille
// Falschauskunft. Beide Typen stehen seit jeher im Lesekatalog
// (`HealthTypeCatalog.swift`: `HKQuantityTypeIdentifierHeight`,
// `HKCharacteristicTypeIdentifierDateOfBirth`) und wurden nie abgefragt.
// Mit ihnen steht im Ernährungsring sofort eine echte Zahl, ohne dass Tim
// etwas einträgt.
//
// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
// Diese Datei darf ausgeführt, aber nicht verändert werden.
//
// Das Füllen der Stammdaten-Tabelle steht in
// `test/data/stammdaten_aus_health_test.dart`, die Swift-Seite in
// `ios/RunnerTests/HealthChannelBodyCharacteristicsTests.swift`.
//
// ## Alle Zahlen hier sind erfunden
//
// Weder die 181 cm noch 1899 noch irgendein anderer Wert in dieser Datei
// hat etwas mit Tim zu tun (`CLAUDE.md`: „Echte Gesundheitsdaten stehen nie
// im Quelltext"). 1899 ist bewusst keine plausible Jahreszahl für einen
// lebenden Menschen — wer sie je in der App sieht, weiß sofort, dass sie
// aus einem Test stammt.
//
// ## API, die diese Tests verbindlich vorgeben
//
// ```dart
// // lib/health/health_types.dart
// class BodyCharacteristics {
//   const BodyCharacteristics({this.heightCm, this.birthYear});
//   factory BodyCharacteristics.ausMap(Map<Object?, Object?> map);
//   final double? heightCm;
//   final int? birthYear;
//   // == und hashCode
// }
//
// // lib/health/health_reading.dart
// abstract class BodyCharacteristicsReading {
//   Future<BodyCharacteristics> bodyCharacteristics();
// }
// ```
//
// `HealthChannel` und `MockHealthReading` erfüllen **beide** Protokolle.
//
// ## Entscheidung 1: ein **zweites** Protokoll, nicht eine achte Methode
//
// `HealthReading` zu erweitern wäre der naheliegende Weg und ist hier
// versperrt: In Dart muss eine Klasse mit `implements` **jedes** Mitglied
// des Protokolls selbst stellen, auch wenn das Protokoll einen Rumpf
// mitbringt. Im Verzeichnis `app/test/` liegen 20 Attrappen der Form
// `class _LeereQuelle implements HealthReading` (gezählt am 04.11.2026).
// Eine achte Methode macht sie alle auf einen Schlag rot — und das sind
// bestehende Testdateien, die niemand anfassen darf, der gerade
// Implementierung schreibt (`CLAUDE.md`, Rollentrennung, und
// `.githooks/pre-commit`).
//
// Das zweite Protokoll ist aber nicht nur der billigere Weg, es ist auch
// der ehrlichere: Ein Merkmal (`HKCharacteristicType`) ist kein Sample. Es
// hat kein Zeitfenster, keine Statistik und keine Quelle, die man
// zusammenführen müsste. Die sieben Methoden von `HealthReading` nehmen
// alle `from`/`through` — `bodyCharacteristics()` nimmt nichts.
//
// **Die Hausregel bleibt gewahrt:** „Views rufen niemals den
// Platform-Channel direkt auf, sonst ist die Mock-Variante wertlos." Auch
// das zweite Protokoll ist ein Protokoll, es liegt in derselben Datei, und
// die Attrappe erfüllt es. Was nicht passiert: ein zweiter
// `MethodChannel`-Aufruf an einer Ansicht vorbei.
//
// ## Entscheidung 2: `heightCm` ist `double`, `birthYear` ist `int`
//
// HealthKit liefert eine Länge als `HKQuantity`, also eine Fließkommazahl
// — 1,806 m sind 180,6 cm. Der Kanal gibt sie unverändert weiter; gerundet
// wird **einmal**, dort, wo der Wert in `Stammdaten.groesseCm` (ein `int`)
// landet, und das steht in `stammdaten_aus_health_test.dart`. Zweimal
// runden hieße, zwei Stellen zu haben, an denen Tim einen halben
// Zentimeter verlieren kann.
//
// Das Geburts**jahr** ist dagegen schon auf der Swift-Seite aus den
// `DateComponents` herausgelöst. `Stammdaten` trägt bewusst kein volles
// Geburtsdatum (siehe dort): Mifflin-St Jeor braucht das Alter in Jahren,
// und ein Datum wäre eine Angabe mehr, als die Formel trägt — und eine
// Angabe mehr, die bei einem Backup mitwandert.
//
// ## Entscheidung 3: der Codec urteilt nicht über Plausibilität
//
// Eine Größe von `0.0` kommt hier unverändert durch, als `0.0` und nicht
// als `null`. Der Codec hat genau eine Aufgabe: abbilden, was drüben stand.
// Ob eine 0 ein Mensch sein kann, entscheidet die Schicht darüber — und sie
// entscheidet es mit „nein, das füllt die Lücke nicht"
// (`stammdaten_aus_health_test.dart`). Beides zusammen ergibt den Vertrag
// aus `CLAUDE.md`: **`nil` wird nie `0`** (Codec) **und `0` wird nie zu
// einem eingetragenen Wert** (Ablage).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:repit/health/health_mock.dart';
import 'package:repit/health/health_reading.dart';
import 'package:repit/health/health_types.dart';

void main() {
  group('Der Werttyp — leer heißt leer', () {
    test('ohne Angaben sind beide Felder null, nicht 0', () {
      const merkmale = BodyCharacteristics();

      expect(
        merkmale.heightCm,
        isNull,
        reason:
            'ein Mensch mit 0 cm ist kein fehlender Wert, sondern eine '
            'falsche Auskunft — Fehler 01 eine Schicht tiefer',
      );
      expect(merkmale.birthYear, isNull);
    });

    test('zwei gleiche Angaben sind gleich und haben denselben hashCode', () {
      // Hausregel: „Ein Werttyp, der Abhängigkeit eines Providers ist,
      // braucht == und hashCode." Ohne das rechnete jeder abgeleitete Wert
      // neu, sobald der Kanal dieselben zwei Zahlen ein zweites Mal
      // liefert — Fehler 03, wortgleich, im neuen Code.
      const einer = BodyCharacteristics(heightCm: 181, birthYear: 1899);
      const anderer = BodyCharacteristics(heightCm: 181, birthYear: 1899);

      expect(einer, anderer);
      expect(einer.hashCode, anderer.hashCode);
    });

    test('ein fehlendes Feld macht den Wert ungleich', () {
      expect(
        const BodyCharacteristics(heightCm: 181),
        isNot(const BodyCharacteristics(heightCm: 181, birthYear: 1899)),
      );
    });
  });

  group('Der Codec — ein fehlendes Feld fehlt in der Map', () {
    test('eine leere Map ergibt zwei null, nicht zwei Nullwerte', () {
      final merkmale = BodyCharacteristics.ausMap(const {});

      expect(
        merkmale.heightCm,
        isNull,
        reason:
            'in Health nicht hinterlegt und Lesen verweigert sehen gleich '
            'aus — beides ist „kein Wert", niemals 0',
      );
      expect(merkmale.birthYear, isNull);
    });

    test('beide Felder kommen unverändert durch', () {
      final merkmale = BodyCharacteristics.ausMap(const {
        'heightCm': 180.6,
        'birthYear': 1899,
      });

      expect(merkmale.heightCm, 180.6);
      expect(merkmale.birthYear, 1899);
    });

    test('fehlt nur die Größe, bleibt nur die Größe null', () {
      final merkmale = BodyCharacteristics.ausMap(const {'birthYear': 1899});

      expect(merkmale.heightCm, isNull);
      expect(merkmale.birthYear, 1899);
    });

    test('fehlt nur das Geburtsjahr, bleibt nur das Geburtsjahr null', () {
      final merkmale = BodyCharacteristics.ausMap(const {'heightCm': 181.0});

      expect(merkmale.heightCm, 181.0);
      expect(merkmale.birthYear, isNull);
    });

    test('eine ganzzahlige Größe kommt auch als int durch', () {
      // Dieselbe Toleranz wie bei `WorkoutSample.ausMap` (`as num`): Welche
      // der beiden Zahlenarten der Standard-Codec für eine glatte Zahl
      // wählt, ist keine Aussage über die Datenlage. Ein Wert, der
      // ankommt, darf nicht daran scheitern.
      final merkmale = BodyCharacteristics.ausMap(const {'heightCm': 180});

      expect(merkmale.heightCm, 180.0);
    });

    test('eine Größe von 0 bleibt 0 und wird nicht still zu null', () {
      // Entscheidung 3 aus dem Dateikopf: Der Codec bildet ab, was drüben
      // stand. Dass diese 0 nie als eingetragene Körpergröße in der
      // Stammdaten-Tabelle landet, ist die Zusage der Schicht darüber —
      // geprüft in `stammdaten_aus_health_test.dart`.
      final merkmale = BodyCharacteristics.ausMap(const {'heightCm': 0.0});

      expect(merkmale.heightCm, 0.0);
    });
  });

  group('Falscher Typ — der Kanal hat seinen Vertrag gebrochen, das soll '
      'laut werden', () {
    test('ein String, wo eine Größe erwartet wird, wirft', () {
      expect(
        () => BodyCharacteristics.ausMap(const {'heightCm': 'hundertachtzig'}),
        throwsA(anything),
        reason:
            'ein falscher Typ ist ein Programmierfehler im Kanal, keine '
            'Datenlage — er darf nicht wie ein harmloses Fehlen aussehen',
      );
    });

    test('ein String, wo ein Geburtsjahr erwartet wird, wirft', () {
      expect(
        () => BodyCharacteristics.ausMap(const {'birthYear': '1899'}),
        throwsA(anything),
      );
    });
  });

  group('Die Attrappe — im Simulator steht eine Zahl, keine Lücke', () {
    test('sie erfüllt das Merkmals-Protokoll', () {
      // Sonst fiele im Simulator genau der Weg aus, den dieses Ticket baut:
      // `HealthChannel` kann dort nichts liefern, der HealthKit-Store des
      // Simulators ist dauerhaft leer.
      expect(MockHealthReading(), isA<BodyCharacteristicsReading>());
    });

    test('sie liefert beide Werte, damit der Ring eine Zahl zeigen kann',
        () async {
      final BodyCharacteristicsReading quelle = MockHealthReading();

      final merkmale = await quelle.bodyCharacteristics();

      expect(merkmale.heightCm, isNotNull);
      expect(merkmale.birthYear, isNotNull);
      expect(
        merkmale.heightCm,
        greaterThan(0),
        reason: 'eine 0 füllt die Lücke nicht und wäre so gut wie nichts',
      );
    });

    test('ihre Werte sind erfunden, aber plausibel', () async {
      // Keine feste Zahl geprüft — welche erfundenen Werte die Attrappe
      // trägt, ist ihre Entscheidung. Geprüft ist nur, dass daraus eine
      // Rechnung werden kann: Mifflin-St Jeor braucht eine Größe und ein
      // Alter, die ein Mensch haben kann. Dass die Werte **nicht Tims**
      // sind, kann kein Test prüfen — es steht im Dateikopf und in der
      // Hausregel.
      final BodyCharacteristicsReading quelle = MockHealthReading();

      final merkmale = await quelle.bodyCharacteristics();

      expect(merkmale.heightCm, inInclusiveRange(140, 220));
      expect(merkmale.birthYear, inInclusiveRange(1940, 2008));
    });

    test('zwei Abfragen liefern dasselbe', () async {
      // Ein wechselnder Wert sähe im Simulator wie ein Fehler aus und
      // machte jede Prüfung von Hand wertlos.
      final BodyCharacteristicsReading quelle = MockHealthReading();

      expect(
        await quelle.bodyCharacteristics(),
        await quelle.bodyCharacteristics(),
      );
    });

    test('sie braucht den Demo-Datensatz dafür nicht', () async {
      // Die Merkmale stehen **nicht** in `test/fixtures/
      // health_export_demo.json`: Das Exportformat (`docs/sample_export.
      // json`) kennt weder Körpergröße noch Geburtsjahr, und die Datei
      // liegt unter `app/test/` — sie zu erweitern wäre eine Änderung an
      // bestehendem Testinhalt. Die beiden Zahlen sind deshalb erfundene
      // Konstanten der Attrappe, und das heißt: Auch ohne Datei kommt eine
      // Antwort, statt dass der Simulator beim Start wirft.
      final BodyCharacteristicsReading ohneDatei = MockHealthReading(
        datenDatei: File('test/fixtures/gibt-es-nicht.json'),
      );

      final merkmale = await ohneDatei.bodyCharacteristics();

      expect(merkmale.heightCm, isNotNull);
      expect(merkmale.birthYear, isNotNull);
    });
  });
}
