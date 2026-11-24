// Größe und Geburtsjahr aus Apple Health in die Stammdaten-Tabelle (#306).
//
// Der Kanal liest zwei Werte, die seit der Installation freigegeben sind und
// nie abgefragt wurden (`HealthTypeCatalog.swift`:
// `HKQuantityTypeIdentifierHeight`, `HKCharacteristicTypeIdentifierDateOfBirth`).
// Ohne sie rechnet `kalorienziel` aus `trainings_core` **nichts** — Mifflin-St
// Jeor braucht Gewicht, Größe und Alter. Mit ihnen steht im Ernährungsring
// sofort eine echte Zahl, ohne dass Tim etwas einträgt.
//
// Der Transporttyp und sein Codec stehen in
// `test/health/koerpermerkmale_test.dart`, die Swift-Seite in
// `ios/RunnerTests/HealthChannelBodyCharacteristicsTests.swift`. Diese Datei
// prüft nur, was mit den gelesenen Werten passiert.
//
// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
// Diese Datei darf ausgeführt, aber nicht verändert werden.
//
// ## Alle Zahlen sind erfunden
//
// 181 cm, 174 cm, 1899 — keiner dieser Werte hat etwas mit Tim zu tun
// (`CLAUDE.md`: „Echte Gesundheitsdaten stehen nie im Quelltext"). 1899 ist
// bewusst kein Geburtsjahr eines lebenden Menschen: Wer die Zahl je in der
// App sieht, weiß sofort, dass sie aus einem Test stammt. Dass das daraus
// gerechnete Alter absurd ist, stört die letzte Gruppe nicht — der Kern
// prüft keine Plausibilität (`kalorienziel` lässt nur `<= 0` durchfallen),
// und das ist dort auch nicht der Prüfinhalt.
//
// ## API, die diese Tests verbindlich vorgeben
//
// Eine einzige neue Top-Level-Bindung, in `lib/data/stammdaten.dart`:
//
// ```dart
// /// Füllt die Lücken in den Stammdaten aus Apple Health. Wer ihn
// /// beobachtet, stößt den Lauf an.
// final stammdatenAusHealthProvider = FutureProvider<void>(…);
// ```
//
// Wie der Lauf innen aufgebaut ist — eine Methode an `StammdatenNotifier`,
// eine freie Funktion, ein Repository-Aufruf —, ist **nicht** festgelegt.
// Festgelegt ist nur, was von außen zu sehen ist:
//
// 1. **Er füllt Lücken, er überschreibt nicht.** Steht in den Stammdaten
//    schon eine Größe, gewinnt sie. Was Tim eingetragen hat, ist eine
//    Angabe über ihn; was in Health steht, kann von einer alten Waage, einer
//    anderen App oder einem Tippfehler von vor Jahren stammen. Wer von Hand
//    korrigiert und beim nächsten Start denselben falschen Wert wiederfindet,
//    hört auf zu korrigieren.
// 2. **Er fragt den Kanal nicht, wenn es nichts zu füllen gibt.** Die Größe
//    ändert sich nicht täglich; der Wert wird gelesen und **abgelegt**, nicht
//    bei jedem Zugriff erfragt (#306, „Worauf zu achten ist").
// 3. **Er beobachtet `freigabeProvider`.** Der erste Lesezugriff läuft vor
//    der Antwort auf den Dialog und kommt leer zurück. Ohne das `watch`
//    stünde dieses leere Ergebnis bis zum nächsten App-Start — genau Tims
//    Befund vom 29.10.2026 (#176), nur an einer neuen Stelle.
// 4. **Er wirft nicht.** Scheitert das Lesen, bleiben die Stammdaten, wie sie
//    waren. „In Health nicht hinterlegt" und „Lesen verweigert" sind nicht
//    unterscheidbar (Apple verrät den Lesestatus nicht); beide führen zu
//    denselben `null` und zu derselben Anzeige. Ein Fehler, der nach oben
//    durchschlägt, machte aus den beiden ununterscheidbaren Fällen zwei
//    verschiedene — und einer davon hieße fälschlich „etwas ist kaputt".
// 5. **Er kommt mit einer Quelle ohne Merkmale zurecht.** `HealthReading`
//    verlangt `bodyCharacteristics()` nicht (Begründung im Dateikopf von
//    `koerpermerkmale_test.dart`); eine Quelle, die das zweite Protokoll
//    nicht erfüllt, ist deshalb ein zulässiger Normalfall und kein Fehler.
//
// ## Entscheidung: eine 0 füllt die Lücke nicht
//
// Eine Größe von `0.0` oder weniger wird **nicht** abgelegt; das Feld bleibt
// `null`. Der Codec reicht eine 0 unverändert durch (er urteilt nicht, siehe
// `koerpermerkmale_test.dart`), aber hier endet die Kette: Eine 0 in der
// Tabelle sähe aus wie ein eingetragener Wert, verstopfte die Lücke für
// immer — Regel 2 fragte nie wieder nach — und ließe `kalorienziel`
// stillschweigend `null` liefern, ohne dass irgendwo stünde, warum. Das ist
// Fehler `01` in der Ablage statt in der Anzeige.
//
// ## Entscheidung: gerundet wird genau hier, und zwar kaufmännisch
//
// `BodyCharacteristics.heightCm` ist `double` (HealthKit liefert Meter),
// `Stammdaten.groesseCm` ist `int`. Die eine Rundung passiert an dieser
// Kante: 180,6 cm werden 181, 180,4 cm werden 180. Abschneiden wäre eine
// stille Veränderung von Tims Körpergröße nach unten, und zwar systematisch
// bei jedem Lauf.
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/data/stammdaten.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_reading.dart';
import 'package:repit/health/health_types.dart';
import '../health/health_reading_attrappe.dart';

void main() {
  AppCache neueDatenbank() {
    final db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);
    return db;
  }

  ProviderContainer behaelter(AppCache db, HealthReading quelle) {
    final container = ProviderContainer(
      // Hausregel: Ohne das hinge ein erzwungener Fehler in einem
      // nichtdeterministischen Zwischenzustand.
      retry: (_, _) => null,
      overrides: [
        appCacheProvider.overrideWithValue(db),
        healthProvider.overrideWithValue(quelle),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Der Lauf, einmal angestoßen und abgewartet.
  Future<void> lauf(ProviderContainer container) =>
      container.read(stammdatenAusHealthProvider.future);

  group('Lücken füllen — der Ring zeigt eine Zahl, ohne dass Tim tippt', () {
    test('beide Werte landen in der Tabelle', () async {
      final db = neueDatenbank();
      final quelle = _Merkmalsquelle(
        const BodyCharacteristics(heightCm: 181, birthYear: 1899),
      );

      await lauf(behaelter(db, quelle));

      final abgelegt = await StammdatenRepository(db).lies();
      expect(abgelegt.groesseCm, 181);
      expect(abgelegt.geburtsjahr, 1899);
    });

    test('der Provider zeigt den neuen Stand, auch wenn er vorher schon '
        'gelesen wurde', () async {
      final db = neueDatenbank();
      final container = behaelter(
        db,
        _Merkmalsquelle(
          const BodyCharacteristics(heightCm: 181, birthYear: 1899),
        ),
      );
      expect(
        await container.read(stammdatenProvider.future),
        const Stammdaten(),
        reason: 'vor dem Lauf ist nichts bekannt',
      );

      await lauf(container);

      expect(
        container.read(stammdatenProvider).value,
        const Stammdaten(groesseCm: 181, geburtsjahr: 1899),
        reason:
            'sonst wäre es ein Formularzustand, der den Schirm nicht '
            'überlebt — und der Ring zeigte bis zum Neustart weiter „kein '
            'Ziel berechenbar"',
      );
    });

    test('Zielgewicht und Zieldatum rührt der Lauf nicht an', () async {
      // Health kennt beide nicht. Ein Schreibweg, der die ganze Zeile neu
      // setzt, ohne die übrigen Felder mitzunehmen, löschte Tims Körperziel
      // beim nächsten Start — lautlos.
      final db = neueDatenbank();
      await StammdatenRepository(db).schreibe(
        const Stammdaten(zielgewichtKg: 80.5, zieldatum: '2027-03-01'),
      );

      await lauf(
        behaelter(
          db,
          _Merkmalsquelle(
            const BodyCharacteristics(heightCm: 181, birthYear: 1899),
          ),
        ),
      );

      final abgelegt = await StammdatenRepository(db).lies();
      expect(abgelegt.zielgewichtKg, 80.5);
      expect(abgelegt.zieldatum, '2027-03-01');
      expect(abgelegt.groesseCm, 181);
    });

    test('eine krumme Größe wird auf ganze Zentimeter gerundet, nicht '
        'abgeschnitten', () async {
      final db = neueDatenbank();

      await lauf(
        behaelter(db, _Merkmalsquelle(const BodyCharacteristics(heightCm: 180.6))),
      );

      expect(
        (await StammdatenRepository(db).lies()).groesseCm,
        181,
        reason:
            'Abschneiden nähme Tim bei jedem Lauf systematisch einen halben '
            'Zentimeter weg',
      );
    });

    test('und die krumme Größe darunter wird abgerundet', () async {
      final db = neueDatenbank();

      await lauf(
        behaelter(db, _Merkmalsquelle(const BodyCharacteristics(heightCm: 180.4))),
      );

      expect((await StammdatenRepository(db).lies()).groesseCm, 180);
    });
  });

  group('Was fehlt, bleibt null — nicht 0, nicht geschätzt', () {
    test('ohne Größe in Health bleibt die Größe null, das Geburtsjahr kommt '
        'trotzdem an', () async {
      final db = neueDatenbank();

      await lauf(
        behaelter(db, _Merkmalsquelle(const BodyCharacteristics(birthYear: 1899))),
      );

      final abgelegt = await StammdatenRepository(db).lies();
      expect(
        abgelegt.groesseCm,
        isNull,
        reason:
            'eine geratene Körpergröße wäre eine Angabe über Tim, die '
            'niemand gemacht hat',
      );
      expect(abgelegt.geburtsjahr, 1899);
    });

    test('ohne Geburtsdatum in Health bleibt das Geburtsjahr null, die Größe '
        'kommt trotzdem an', () async {
      final db = neueDatenbank();

      await lauf(
        behaelter(db, _Merkmalsquelle(const BodyCharacteristics(heightCm: 181))),
      );

      final abgelegt = await StammdatenRepository(db).lies();
      expect(abgelegt.groesseCm, 181);
      expect(
        abgelegt.geburtsjahr,
        isNull,
        reason: 'ein geschätztes Alter wäre eine stille Falschauskunft',
      );
    });

    test('eine Größe von 0 füllt die Lücke nicht', () async {
      // Siehe Dateikopf. Eine 0 in der Tabelle verstopfte die Lücke für
      // immer, weil danach nie wieder gefragt wird.
      final db = neueDatenbank();

      await lauf(
        behaelter(db, _Merkmalsquelle(const BodyCharacteristics(heightCm: 0))),
      );

      expect((await StammdatenRepository(db).lies()).groesseCm, isNull);
    });

    test('eine negative Größe füllt die Lücke auch nicht', () async {
      final db = neueDatenbank();

      await lauf(
        behaelter(db, _Merkmalsquelle(const BodyCharacteristics(heightCm: -181))),
      );

      expect((await StammdatenRepository(db).lies()).groesseCm, isNull);
    });

    test('ein gescheitertes Lesen wirft nicht und nimmt nichts weg', () async {
      final db = neueDatenbank();
      await StammdatenRepository(db).schreibe(const Stammdaten(groesseCm: 174));

      await expectLater(
        lauf(behaelter(db, _Merkmalsquelle(const BodyCharacteristics(), wirft: true))),
        completes,
        reason:
            'ein Lesefehler ist keine Meldung wert, die es nicht gibt — der '
            'Schirm sagt ohnehin „kein Ziel berechenbar"',
      );
      final abgelegt = await StammdatenRepository(db).lies();
      expect(abgelegt.groesseCm, 174);
      expect(abgelegt.geburtsjahr, isNull);
    });

    test('„nicht hinterlegt" und „Lesen verweigert" sind nicht '
        'unterscheidbar', () async {
      // Apple verrät den Lesestatus nicht, also darf die App die beiden
      // Fälle auch nicht verschieden behandeln. Was unten herauskommt, ist
      // zweimal dasselbe — und damit kann kein Text darüber behaupten,
      // hier sei nichts gemessen worden.
      final ohneEintrag = neueDatenbank();
      final verweigert = neueDatenbank();

      await lauf(behaelter(ohneEintrag, _Merkmalsquelle(const BodyCharacteristics())));
      await lauf(
        behaelter(verweigert, _Merkmalsquelle(const BodyCharacteristics(), wirft: true)),
      );

      expect(
        await StammdatenRepository(ohneEintrag).lies(),
        await StammdatenRepository(verweigert).lies(),
      );
      expect(await StammdatenRepository(ohneEintrag).lies(), const Stammdaten());
    });

    test('eine Quelle ohne Merkmale ist kein Fehler', () async {
      // `HealthReading` verlangt `bodyCharacteristics()` nicht. Eine Quelle,
      // die nur die sieben Zeitraum-Methoden kann, muss den Lauf durchlassen
      // statt ihn zu sprengen.
      final db = neueDatenbank();

      await expectLater(lauf(behaelter(db, _StilleQuelle())), completes);

      expect(await StammdatenRepository(db).lies(), const Stammdaten());
    });
  });

  group('Von Hand gewinnt — Health füllt nur Lücken', () {
    test('eine eingetragene Größe bleibt stehen, das fehlende Geburtsjahr '
        'wird gefüllt', () async {
      final db = neueDatenbank();
      await StammdatenRepository(db).schreibe(const Stammdaten(groesseCm: 174));

      await lauf(
        behaelter(
          db,
          _Merkmalsquelle(
            const BodyCharacteristics(heightCm: 181, birthYear: 1899),
          ),
        ),
      );

      final abgelegt = await StammdatenRepository(db).lies();
      expect(
        abgelegt.groesseCm,
        174,
        reason:
            'wer von Hand korrigiert und beim nächsten Start denselben '
            'falschen Wert wiederfindet, hört auf zu korrigieren',
      );
      expect(abgelegt.geburtsjahr, 1899);
    });

    test('ein eingetragenes Geburtsjahr bleibt stehen', () async {
      final db = neueDatenbank();
      await StammdatenRepository(db).schreibe(const Stammdaten(geburtsjahr: 1899));

      await lauf(
        behaelter(
          db,
          _Merkmalsquelle(
            const BodyCharacteristics(heightCm: 181, birthYear: 1950),
          ),
        ),
      );

      final abgelegt = await StammdatenRepository(db).lies();
      expect(abgelegt.geburtsjahr, 1899);
      expect(abgelegt.groesseCm, 181);
    });
  });

  group('Abgelegt, nicht bei jedem Zugriff erfragt', () {
    test('stehen beide Werte schon da, wird der Kanal gar nicht gefragt',
        () async {
      final db = neueDatenbank();
      await StammdatenRepository(db).schreibe(
        const Stammdaten(groesseCm: 174, geburtsjahr: 1899),
      );
      final quelle = _Merkmalsquelle(
        const BodyCharacteristics(heightCm: 181, birthYear: 1950),
      );

      await lauf(behaelter(db, quelle));

      expect(
        quelle.anfragen,
        0,
        reason: 'die Größe ändert sich nicht täglich',
      );
    });

    test('nach einem erfolgreichen Lauf fragt der nächste Start nicht mehr',
        () async {
      // Zwei Container auf derselben Datenbank sind zwei App-Starts. Der
      // Zähler läuft über beide — gefragt wird genau einmal.
      final db = neueDatenbank();
      final quelle = _Merkmalsquelle(
        const BodyCharacteristics(heightCm: 181, birthYear: 1899),
      );

      await lauf(behaelter(db, quelle));
      await lauf(behaelter(db, quelle));

      expect(quelle.anfragen, 1);
      final abgelegt = await StammdatenRepository(db).lies();
      expect(abgelegt.groesseCm, 181);
      expect(abgelegt.geburtsjahr, 1899);
    });

    test('solange eine Lücke bleibt, darf der nächste Start erneut fragen',
        () async {
      // Die Gegenprobe zum Fall darüber: Nicht „einmal und nie wieder",
      // sondern „solange es etwas zu holen gibt". Sonst wäre ein Health-
      // Eintrag, der erst morgen entsteht, für immer unerreichbar.
      final db = neueDatenbank();
      final quelle = _Merkmalsquelle(const BodyCharacteristics());

      await lauf(behaelter(db, quelle));
      await lauf(behaelter(db, quelle));

      expect(quelle.anfragen, 2);
    });

    test('nach der beantworteten Freigabe läuft es nach', () async {
      // Der erste Lesezugriff läuft vor der Antwort auf den Dialog und
      // kommt leer zurück (#176). Ohne das `watch` auf `freigabeProvider`
      // stünde dieses leere Ergebnis bis zum nächsten App-Start.
      final db = neueDatenbank();
      final quelle = _Merkmalsquelle(const BodyCharacteristics());
      final container = behaelter(db, quelle);

      await lauf(container);
      expect(await StammdatenRepository(db).lies(), const Stammdaten());

      quelle.merkmale = const BodyCharacteristics(heightCm: 181, birthYear: 1899);
      await container.read(freigabeProvider.notifier).frageEinmal();
      await lauf(container);

      final abgelegt = await StammdatenRepository(db).lies();
      expect(abgelegt.groesseCm, 181);
      expect(abgelegt.geburtsjahr, 1899);
    });
  });

  group('Warum es zählt — erst mit beiden rechnet kalorienziel etwas', () {
    // Die Kette, um die es im Ticket geht, am Stück: Health → Stammdaten →
    // `kalorienziel`. Das Gewicht kommt aus den Tageswerten und steht hier
    // als erfundene Zahl; wo die Umrechnung Geburtsjahr → Alter wohnt, ist
    // mit diesem Ticket **nicht** entschieden (siehe Bericht) — deshalb
    // steht sie hier im Test und nirgends sonst.
    const gewichtKg = 72.0;
    const heute = 2026;

    test('mit Größe, Geburtsjahr und Gewicht kommt eine Zahl heraus', () async {
      final db = neueDatenbank();
      await lauf(
        behaelter(
          db,
          _Merkmalsquelle(
            const BodyCharacteristics(heightCm: 181, birthYear: 1899),
          ),
        ),
      );
      final stammdaten = await StammdatenRepository(db).lies();

      final ziel = kalorienziel(
        gewichtKg: gewichtKg,
        groesseCm: stammdaten.groesseCm,
        alter: heute - stammdaten.geburtsjahr!,
      );

      expect(ziel, isNotNull);
      expect(ziel, greaterThan(0));
    });

    test('ohne Größe bleibt es null — kein Ziel berechenbar, keine '
        'geschätzte Zahl', () async {
      final db = neueDatenbank();
      await lauf(
        behaelter(db, _Merkmalsquelle(const BodyCharacteristics(birthYear: 1899))),
      );
      final stammdaten = await StammdatenRepository(db).lies();

      expect(
        kalorienziel(
          gewichtKg: gewichtKg,
          groesseCm: stammdaten.groesseCm,
          alter: heute - stammdaten.geburtsjahr!,
        ),
        isNull,
      );
    });

    test('ohne Geburtsjahr bleibt es ebenfalls null', () async {
      final db = neueDatenbank();
      await lauf(
        behaelter(db, _Merkmalsquelle(const BodyCharacteristics(heightCm: 181))),
      );
      final stammdaten = await StammdatenRepository(db).lies();

      expect(stammdaten.geburtsjahr, isNull);
      expect(
        kalorienziel(
          gewichtKg: gewichtKg,
          groesseCm: stammdaten.groesseCm,
          alter: stammdaten.geburtsjahr == null
              ? null
              : heute - stammdaten.geburtsjahr!,
        ),
        isNull,
      );
    });
  });
}

/// Eine Quelle, die die sieben Zeitraum-Methoden kann und sonst nichts —
/// das zweite Protokoll erfüllt sie **nicht**. Genau der Fall, den es in
/// `app/test/` zwanzigmal gibt.
class _StilleQuelle extends HealthReadingAttrappe {}

/// Dieselbe Quelle, die zusätzlich Merkmale liefert — und mitzählt, wie oft
/// sie danach gefragt wurde.
class _Merkmalsquelle extends _StilleQuelle
    implements BodyCharacteristicsReading {
  _Merkmalsquelle(this.merkmale, {this.wirft = false});

  /// Veränderlich, damit ein Test den Zustand „vor dem Dialog nichts, danach
  /// etwas" nachstellen kann.
  BodyCharacteristics merkmale;

  final bool wirft;

  int anfragen = 0;

  @override
  Future<BodyCharacteristics> bodyCharacteristics() async {
    anfragen += 1;
    if (wirft) {
      throw StateError('Lesen gescheitert — oder nie freigegeben, man sieht '
          'es dem Fehler nicht an');
    }
    return merkmale;
  }
}
