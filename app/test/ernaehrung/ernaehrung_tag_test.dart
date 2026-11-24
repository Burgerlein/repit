import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/core/messwert.dart';
import 'package:repit/data/ernaehrung_repository.dart';
import 'package:repit/data/stammdaten.dart';
import 'package:repit/ernaehrung/ernaehrung_provider.dart';
import 'package:repit/health/health_types.dart';

/// Tests für den **Zustand** des Ernährungs-Tag-Schirms (#282, Task 4 des
/// Ernährungsplans) — die reine Funktion `ernaehrungsTagAus` in
/// `lib/ernaehrung/ernaehrung_provider.dart`.
///
/// Die Verdrahtung in den Riverpod-Baum prüft
/// `ernaehrung_provider_test.dart`, die Oberfläche
/// `ernaehrung_view_test.dart`. Die Dreiteilung ist die Hausform von
/// `erholung_zustand_test.dart` / `erholung_view_test.dart` und hat
/// denselben Grund: Die Kreuzungen aus „eigene Einträge da / nicht da" und
/// den vier `Messwert`-Zuständen der Health-Hälfte sind als Tabelle
/// prüfbar, nicht als ein Dutzend gepumpter Schirme — und genau auf diesen
/// Kreuzungen lebt Fehler `01`.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung**
/// (`CLAUDE.md`). Diese Datei darf ausgeführt, aber nicht verändert
/// werden.
///
/// ## Was diese Datei verbindlich vorgibt
///
/// In `lib/ernaehrung/ernaehrung_provider.dart`:
///
/// ```dart
/// /// Eine fremde Mahlzeit aus Apple Health — eine, die **nicht** aus
/// /// dieser App stammt. Die eigenen Proben sind auf der Swift-Seite des
/// /// Kanals an ihrer Quelle erkannt und übersprungen (Task 5), hier
/// /// kommen also nur fremde an.
/// @immutable
/// class FremdeMahlzeit {
///   const FremdeMahlzeit({
///     required DateTime zeitpunkt,   // UTC
///     required String name,
///     required Naehrwerte naehrwerte,
///   });
///   // == und hashCode über alle Felder
/// }
///
/// /// Eine der vier Mahlzeitenzeilen des Tages.
/// @immutable
/// class MahlzeitZeile {
///   const MahlzeitZeile({
///     required Mahlzeit mahlzeit,
///     required List<Eintrag> eigene,        // chronologisch
///     required List<FremdeMahlzeit> fremde, // chronologisch
///     required Naehrwerte summe,            // eigene + fremde
///   });
///   bool get leer;                          // eigene.isEmpty && fremde.isEmpty
///   // == und hashCode über alle Felder
/// }
///
/// /// Der fertig gerechnete Tag — die eine Abhängigkeit des Schirms.
/// @immutable
/// class ErnaehrungsTag {
///   const ErnaehrungsTag({
///     required String tagesSchluessel,
///     required bool istHeute,
///     required List<MahlzeitZeile> mahlzeiten, // immer vier, in
///                                              // Mahlzeit.values-Reihenfolge
///     required Messwert<Naehrwerte> gegessen,
///     required double? zielKcal,
///     required bool zielLaedt,
///     required Makroziele makroziele,
///     required Tagesbilanz bilanz,
///   });
///   // == und hashCode über alle Felder
/// }
///
/// ErnaehrungsTag ernaehrungsTagAus({
///   required String tagesSchluessel,
///   required String heute,                        // ISO-Tagesstring
///   required List<Eintrag> eigene,                // dieses Esstags
///   required Messwert<List<FremdeMahlzeit>> fremde,
///   required Messwert<List<DailyMetrics>> tageswerte,
///   required Stammdaten stammdaten,
///   required DateTime jetzt,
/// });
/// ```
///
/// **`==`/`hashCode` sind Pflicht, nicht Kür.** Alle drei Typen sind
/// Abhängigkeit eines Providers; ohne Wertgleichheit rechnet Riverpod
/// Ring, Makros und Verlauf bei jedem Zugriff neu — Fehler `03`,
/// wortgleich, im neuen Code (`CLAUDE.md`).
///
/// ## Die sieben Entscheidungen, die hier festgeschrieben sind
///
/// 1. **Die eigene Tabelle ist die Wahrheit, Health zählt dazu.** Der Ring
///    zeigt eigene Einträge **sofort** als `Bekannt(…, laeuft: true)` und
///    zählt nach, was der Health-Lauf bringt. Ein Ladeplatzhalter steht nur
///    dann, wenn **beides** noch nie da war.
/// 2. **Ein Tag ohne Eintrag hat `0` gegessen, nicht „keinen Wert"** —
///    sobald der Health-Lauf durch ist. Das ist kein Verstoß gegen „`0` ist
///    keine Antwort auf ‚kein Wert'", sondern dessen Kehrseite: Für Tims
///    eigene Daten gibt es keinen Lauf, der leer ausgehen kann, und der
///    Entwurf zeigt den Zustand `leer` ausdrücklich mit dem vollen
///    Tagesbudget („Morgens: alle vier Mahlzeiten offen, das volle
///    Tagesbudget übrig", `ernaehrung.js`). Die leere Summe trägt deshalb
///    **alle acht Werte als `0`**.
/// 3. **Mit mindestens einem Eintrag gilt wieder die Regel von
///    `Naehrwerte.operator +`:** Ein Lebensmittel ohne Ballaststoffangabe
///    macht die Tagessumme dort `null`, nicht `0` (Review Focus 2, #232).
///    Der Unterschied zu 2. ist der zwischen „nichts gegessen" und „nicht
///    deklariert".
/// 4. **Ein gescheiterter Health-Lauf nimmt keinen sichtbaren Wert weg**
///    (`CLAUDE.md`). Stehen eigene Einträge da, bleiben sie als `Bekannt`
///    stehen; steht nichts da, ist `Fehlgeschlagen` die ehrliche Antwort —
///    ein Fehler ist keine Aussage über die Datenlage, und `0` wäre eine.
/// 5. **#229: Das Ziel für heute bewegt sich nicht.** Für den **heutigen**
///    Tag geht `kalorienziel` ohne `aktivKcal`/`basalKcal` — es fällt damit
///    auf Mifflin-St Jeor zurück, den „Planwert für heute" aus der Spec.
///    Für **vergangene** Tage zählt der gemessene Verbrauch. Ohne das
///    wüchse das Ziel über den Tag und stünde morgens anders da als abends.
/// 6. **Der Verbrauch in der Bilanz ist immer der gemessene**, auch heute.
///    Er ist eine Messung und keine Vorgabe; nur das **Ziel** wird für
///    heute ruhiggestellt. Fehlt eine der beiden Hälften (aktiv, Grund),
///    ist er `null` — eine halbe Summe wäre eine falsche Zahl.
/// 7. **`zielLaedt` trennt „noch nicht nachgesehen" von „nicht
///    berechenbar".** Beides ergibt `zielKcal == null`, aber nur das
///    zweite darf einen Grund anzeigen. Ohne diese Unterscheidung stünde
///    während des Ladens „kein Ziel berechenbar" auf dem Schirm, und das
///    ist Fehler `01` in neuer Verpackung.
///
/// ## Was hier **nicht** festgelegt wird
///
/// Die drei Zeilen der Herleitung („Grundumsatz", „Aktiv heute",
/// „Körperziel"). Sie stehen in einem eingeklappten Abschnitt, kein
/// Pflichtfall hängt an ihren Zahlen, und ein eigener Werttyp dafür wäre
/// mehr Vertrag, als der Auftrag trägt. Der Schirm prüft nur, dass der
/// Abschnitt da und eingeklappt ist.
///
/// ## Zahlen in dieser Datei
///
/// Alle erfunden und erkennbar künstlich — runde Hunderter, keine Werte
/// aus `ernaehrung.js` (`CLAUDE.md`: keine echten Gesundheitsdaten, auch
/// nicht in Tests).
void main() {
  // Der Tag, auf dem diese Datei rechnet: Dienstag, 14.07.2026 — ein
  // beliebiges Datum ohne Bezug zu irgendeinem Ereignis.
  const heute = '2026-07-14';
  const gestern = '2026-07-13';
  final jetzt = DateTime.utc(2026, 7, 14, 10); // 12:00 Berlin

  /// Ein eigener Eintrag. `kcal` ist der einzige Pflichtwert; alles andere
  /// bleibt weg, damit jeder Fall sagt, was er meint.
  Eintrag eintrag({
    int id = 1,
    String tag = heute,
    Mahlzeit mahlzeit = Mahlzeit.mittag,
    int stundeUtc = 10,
    String name = 'Testgericht',
    double? kcal = 400,
    double? eiweissG,
    double? ballaststoffeG,
  }) => Eintrag(
    id: id,
    tagesSchluessel: tag,
    mahlzeit: mahlzeit,
    zeitpunkt: DateTime.utc(2026, 7, 14, stundeUtc),
    name: name,
    naehrwerte: Naehrwerte(
      kcal: kcal,
      eiweissG: eiweissG,
      ballaststoffeG: ballaststoffeG,
    ),
  );

  FremdeMahlzeit fremdeMahlzeit({
    int stundeUtc = 16,
    String name = 'Fremdeintrag',
    double? kcal = 300,
    double? eiweissG,
  }) => FremdeMahlzeit(
    zeitpunkt: DateTime.utc(2026, 7, 14, stundeUtc),
    name: name,
    naehrwerte: Naehrwerte(kcal: kcal, eiweissG: eiweissG),
  );

  Messwert<List<FremdeMahlzeit>> fremdeDa(
    List<FremdeMahlzeit> liste, {
    bool laeuft = false,
  }) => Bekannt<List<FremdeMahlzeit>>(liste, stand: jetzt, laeuft: laeuft);

  DailyMetrics tageswert(
    String tag, {
    int? aktiv = 600,
    int? basal = 1600,
    double? gewicht = 80,
  }) => DailyMetrics(
    tag: tag,
    activeKcal: aktiv,
    basalKcal: basal,
    weightKg: gewicht,
  );

  Messwert<List<DailyMetrics>> tageswerteDa(List<DailyMetrics> liste) =>
      Bekannt<List<DailyMetrics>>(liste, stand: jetzt, laeuft: false);

  /// Vollständige Stammdaten — nur mit ihnen gibt es überhaupt ein Ziel.
  /// Größe und Geburtsjahr sind erfunden.
  const vollstaendig = Stammdaten(
    groesseCm: 180,
    geburtsjahr: 1990,
    zielgewichtKg: 84,
    zieldatum: '2027-01-14',
  );

  ErnaehrungsTag tag({
    String tagesSchluessel = heute,
    List<Eintrag> eigene = const [],
    Messwert<List<FremdeMahlzeit>>? fremde,
    Messwert<List<DailyMetrics>>? tageswerte,
    Stammdaten stammdaten = vollstaendig,
  }) => ernaehrungsTagAus(
    tagesSchluessel: tagesSchluessel,
    heute: heute,
    eigene: eigene,
    fremde: fremde ?? fremdeDa(const []),
    tageswerte:
        tageswerte ??
        tageswerteDa([tageswert(gestern), tageswert(heute)]),
    stammdaten: stammdaten,
    jetzt: jetzt,
  );

  /// Der gegessene Wert, wenn einer dasteht — sonst scheitert der Test mit
  /// einer lesbaren Meldung statt mit einem Cast.
  Naehrwerte gegessenWert(ErnaehrungsTag t) {
    final gegessen = t.gegessen;
    expect(
      gegessen,
      isA<Bekannt<Naehrwerte>>(),
      reason: 'dieser Fall setzt einen sichtbaren Wert voraus',
    );
    return (gegessen as Bekannt<Naehrwerte>).wert;
  }

  MahlzeitZeile zeile(ErnaehrungsTag t, Mahlzeit mahlzeit) =>
      t.mahlzeiten.firstWhere((z) => z.mahlzeit == mahlzeit);

  // ─────────────────────────────────────────────────────────────────────
  group('Die vier Mahlzeitenzeilen', () {
    test('es sind immer vier, in der Reihenfolge des Entwurfs', () {
      // Auch an einem Tag, an dem gar nichts eingetragen ist: „Eine
      // Mahlzeitenzeile ohne Eintrag verschwindet nicht, sie zeigt ein
      // Plus" (`ernaehrung.js`, Zustand `leer`).
      final leer = tag();
      expect(leer.mahlzeiten.map((z) => z.mahlzeit).toList(), Mahlzeit.values);
      expect(leer.mahlzeiten.every((z) => z.leer), isTrue);

      // Und an einem Tag mit genau einer Mahlzeit ebenfalls vier.
      final einer = tag(eigene: [eintrag(mahlzeit: Mahlzeit.mittag)]);
      expect(einer.mahlzeiten, hasLength(4));
      expect(zeile(einer, Mahlzeit.mittag).leer, isFalse);
      expect(zeile(einer, Mahlzeit.abend).leer, isTrue);
    });

    test('ein eigener Eintrag steht in der Zeile, die er selbst nennt', () {
      // Die Mahlzeit steht am Eintrag, nicht an seiner Uhrzeit: Tim darf
      // sie im Buchungsblatt umhängen, und eine zweite Zuordnung hier
      // überstimmte das stillschweigend.
      final t = tag(
        eigene: [eintrag(mahlzeit: Mahlzeit.abend, stundeUtc: 6)],
      );
      expect(zeile(t, Mahlzeit.abend).eigene, hasLength(1));
      expect(zeile(t, Mahlzeit.fruehstueck).eigene, isEmpty);
    });

    test(
      'eine fremde Mahlzeit landet in der Zeile ihrer Uhrzeit — und 00:30 '
      'gehört zum Abend',
      () {
        // Fremde Proben tragen keine Mahlzeit, nur eine Uhrzeit. Die
        // Einteilung ist `Mahlzeitfenster.fuer`, und der Abend umschließt
        // Mitternacht (Review Focus 1).
        //
        // 06:00 UTC = 08:00 Berlin (MESZ) → Frühstück.
        // 22:30 UTC = 00:30 Berlin        → Abend.
        final t = tag(
          fremde: fremdeDa([
            fremdeMahlzeit(stundeUtc: 6, name: 'Fremd morgens'),
            FremdeMahlzeit(
              zeitpunkt: DateTime.utc(2026, 7, 14, 22, 30),
              name: 'Fremd nachts',
              naehrwerte: const Naehrwerte(kcal: 100),
            ),
          ]),
        );

        expect(zeile(t, Mahlzeit.fruehstueck).fremde, hasLength(1));
        expect(zeile(t, Mahlzeit.abend).fremde, hasLength(1));
        expect(zeile(t, Mahlzeit.mittag).fremde, isEmpty);
      },
    );

    test('die Summe einer Zeile zählt eigene und fremde zusammen', () {
      final t = tag(
        eigene: [eintrag(mahlzeit: Mahlzeit.mittag, stundeUtc: 10, kcal: 400)],
        fremde: fremdeDa([fremdeMahlzeit(stundeUtc: 11, kcal: 300)]),
      );
      // 11:00 UTC = 13:00 Berlin → Mittag.
      expect(zeile(t, Mahlzeit.mittag).summe.kcal, 700);
    });

    test('eine Zeile ohne Eintrag trägt acht Nullen, keinen fehlenden Wert', () {
      // „Noch nichts eingetragen" ist eine Aussage, kein Loch: Der Schirm
      // schreibt dort „0 kcal", und das stimmt.
      final summe = zeile(tag(), Mahlzeit.snack).summe;
      expect(summe.kcal, 0);
      expect(summe.eiweissG, 0);
      expect(summe.kohlenhydrateG, 0);
      expect(summe.fettG, 0);
      expect(summe.zuckerG, 0);
      expect(summe.ballaststoffeG, 0);
      expect(summe.gesaettigtG, 0);
      expect(summe.wasserMl, 0);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  group('Das Gegessene — eigene Einträge und der Health-Lauf', () {
    test(
      'eigene Einträge stehen sofort da, während Health noch läuft '
      '(Bekannt, laeuft: true)',
      () {
        final t = tag(
          eigene: [eintrag(kcal: 400)],
          fremde: const NochNie<List<FremdeMahlzeit>>(),
        );

        final gegessen = t.gegessen;
        expect(gegessen, isA<Bekannt<Naehrwerte>>());
        final bekannt = gegessen as Bekannt<Naehrwerte>;
        expect(bekannt.wert.kcal, 400);
        expect(
          bekannt.laeuft,
          isTrue,
          reason: 'der Health-Lauf steht noch aus und kann nachzählen',
        );
      },
    );

    test(
      'ein Platzhalter nur, wenn beides noch nie da war: keine eigenen '
      'Einträge und kein Health-Lauf',
      () {
        final t = tag(
          eigene: const [],
          fremde: const NochNie<List<FremdeMahlzeit>>(),
        );
        expect(t.gegessen, isA<NochNie<Naehrwerte>>());
      },
    );

    test('ist der Lauf durch, zählt das Fremde mit', () {
      final t = tag(
        eigene: [eintrag(kcal: 400)],
        fremde: fremdeDa([fremdeMahlzeit(kcal: 300)]),
      );
      expect(gegessenWert(t).kcal, 700);
    });

    test(
      'ein fertiger Lauf ohne fremde Mahlzeiten ist kein Leerstand — '
      'die eigene Tabelle ist die Wahrheit',
      () {
        // `LeerNachLauf` wäre hier falsch: Health hat nachgesehen und
        // nichts Fremdes gefunden, und das ist ein vollständiges Ergebnis.
        final mitEigenen = tag(
          eigene: [eintrag(kcal: 400)],
          fremde: LeerNachLauf<List<FremdeMahlzeit>>(gelaufen: jetzt),
        );
        expect(gegessenWert(mitEigenen).kcal, 400);
        expect((mitEigenen.gegessen as Bekannt<Naehrwerte>).laeuft, isFalse);

        final ohneAlles = tag(
          eigene: const [],
          fremde: LeerNachLauf<List<FremdeMahlzeit>>(gelaufen: jetzt),
        );
        expect(
          ohneAlles.gegessen,
          isA<Bekannt<Naehrwerte>>(),
          reason:
              'nachgesehen und nichts gefunden heißt an einem eigenen Tag '
              'schlicht: nichts gegessen',
        );
        expect(gegessenWert(ohneAlles).kcal, 0);
      },
    );

    test(
      'ein gescheiterter Lauf nimmt keinen sichtbaren Wert weg — und '
      'erfindet auch keinen',
      () {
        final fehler = Fehlgeschlagen<List<FremdeMahlzeit>>(
          fehler: Exception('Kanal nicht erreichbar'),
          gelaufen: jetzt,
        );

        final mitEigenen = tag(eigene: [eintrag(kcal: 400)], fremde: fehler);
        expect(gegessenWert(mitEigenen).kcal, 400);
        expect((mitEigenen.gegessen as Bekannt<Naehrwerte>).laeuft, isFalse);

        final ohneAlles = tag(eigene: const [], fremde: fehler);
        expect(
          ohneAlles.gegessen,
          isA<Fehlgeschlagen<Naehrwerte>>(),
          reason:
              'ohne eigenen Eintrag und ohne gelungenen Lauf wäre „0 '
              'gegessen" eine Behauptung über etwas, das niemand gesehen '
              'hat',
        );
      },
    );

    test(
      'ein Lebensmittel ohne Ballaststoffangabe macht die Tagessumme dort '
      'null, nicht 0 (#232, Review Focus 2)',
      () {
        final t = tag(
          eigene: [
            eintrag(id: 1, kcal: 400, eiweissG: 20),
            eintrag(id: 2, kcal: 300, eiweissG: 10, ballaststoffeG: 5),
          ],
        );
        final summe = gegessenWert(t);
        expect(summe.kcal, 700);
        expect(summe.eiweissG, 30);
        expect(
          summe.ballaststoffeG,
          5,
          reason: 'die Summe der vorhandenen, wenn nur eine Angabe fehlt',
        );

        final ohneAngabe = tag(eigene: [eintrag(kcal: 400)]);
        expect(
          gegessenWert(ohneAngabe).ballaststoffeG,
          isNull,
          reason:
              'fehlen alle Angaben, bleibt die Summe `null` — keine '
              'Ballaststoffe von null, sondern keine Angabe',
        );
      },
    );
  });

  // ─────────────────────────────────────────────────────────────────────
  group('Das Ziel', () {
    test('ohne Stammdaten gibt es kein Ziel — und das ist kein Ladezustand', () {
      final t = tag(stammdaten: const Stammdaten());
      expect(t.zielKcal, isNull);
      expect(
        t.zielLaedt,
        isFalse,
        reason:
            'hier fehlen Angaben, nicht ein Lauf — der Schirm darf den '
            'Grund nennen und auf die Einstellungen führen',
      );
      expect(t.bilanz.status, Zielstatus.keinZiel);
    });

    test('ohne Gewicht gibt es kein Ziel, aber es lädt noch', () {
      // Noch nie nachgesehen: `zielKcal` ist `null`, weil niemand gefragt
      // hat. Stünde dort „kein Ziel berechenbar", wäre das Fehler `01`.
      final t = tag(tageswerte: const NochNie<List<DailyMetrics>>());
      expect(t.zielKcal, isNull);
      expect(t.zielLaedt, isTrue);
    });

    test(
      'ein fertiger Lauf ohne Gewicht lädt nicht mehr — dann fehlt es '
      'wirklich',
      () {
        final t = tag(
          tageswerte: LeerNachLauf<List<DailyMetrics>>(gelaufen: jetzt),
        );
        expect(t.zielKcal, isNull);
        expect(t.zielLaedt, isFalse);
      },
    );

    test('das letzte bekannte Gewicht trägt den Tag, nicht nur das von heute', () {
      // Tim wiegt sich nicht täglich. Gäbe es das Ziel nur an Wiegetagen,
      // stünde der Ring an fünf von sieben Tagen auf „kein Ziel".
      final t = tag(
        tageswerte: tageswerteDa([
          tageswert(gestern, gewicht: 80),
          tageswert(heute, gewicht: null),
        ]),
      );
      expect(t.zielKcal, isNotNull);
      expect(t.makroziele.eiweissMinG, isNotNull);
    });

    test(
      'das Ziel für HEUTE bewegt sich nicht, wenn der Watch-Verbrauch '
      'steigt (#229)',
      () {
        // Derselbe Tag, zwei Läufe mit verschiedenem `aktivKcal` — und
        // zwar mit einem Grundumsatz über 1.400, bei dem die Watch-Daten
        // sonst ganztägig gälten. Käme das Ziel von dort, stünde morgens
        // eine andere Zahl als abends.
        final morgens = tag(
          tageswerte: tageswerteDa([tageswert(heute, aktiv: 150)]),
        );
        final abends = tag(
          tageswerte: tageswerteDa([tageswert(heute, aktiv: 900)]),
        );

        expect(morgens.zielKcal, isNotNull);
        expect(
          abends.zielKcal,
          morgens.zielKcal,
          reason:
              'für heute gilt der Planwert, nicht der bisher gemessene '
              'Verbrauch',
        );
      },
    );

    test('für vergangene Tage gilt der gemessene Verbrauch (#229)', () {
      final wenig = tag(
        tagesSchluessel: gestern,
        tageswerte: tageswerteDa([tageswert(gestern, aktiv: 150)]),
      );
      final viel = tag(
        tagesSchluessel: gestern,
        tageswerte: tageswerteDa([tageswert(gestern, aktiv: 900)]),
      );

      expect(wenig.zielKcal, isNotNull);
      expect(
        viel.zielKcal,
        greaterThan(wenig.zielKcal!),
        reason:
            'ein vergangener Tag ist abgeschlossen — dort ist der '
            'gemessene Verbrauch die bessere Zahl als eine Schätzung',
      );
    });

    test('istHeute unterscheidet die beiden Fälle sichtbar', () {
      expect(tag().istHeute, isTrue);
      expect(tag(tagesSchluessel: gestern).istHeute, isFalse);
    });

    test('der Verbrauch in der Bilanz ist auch heute der gemessene', () {
      // Nur das **Ziel** wird für heute ruhiggestellt. Der Verbrauch ist
      // eine Messung, und die Verlaufslinie heißt „Verbraucht".
      final t = tag(
        tageswerte: tageswerteDa([tageswert(heute, aktiv: 600, basal: 1600)]),
      );
      expect(t.bilanz.verbrauchKcal, 2200);
    });

    test('eine halbe Summe ist kein Verbrauch', () {
      final t = tag(
        tageswerte: tageswerteDa([tageswert(heute, aktiv: 600, basal: null)]),
      );
      expect(
        t.bilanz.verbrauchKcal,
        isNull,
        reason: 'aktiv ohne Grundumsatz wäre eine falsche Zahl, kein Teilwert',
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  group('Die Bilanz', () {
    test('sie trägt das Gegessene, sobald es dasteht', () {
      final t = tag(eigene: [eintrag(kcal: 400)]);
      expect(t.bilanz.gegessenKcal, 400);
      expect(t.bilanz.zielKcal, t.zielKcal);
    });

    test('solange nichts dasteht, trägt sie keinen Wert — und keine 0', () {
      final t = tag(
        eigene: const [],
        fremde: const NochNie<List<FremdeMahlzeit>>(),
      );
      expect(
        t.bilanz.gegessenKcal,
        isNull,
        reason: 'ein Ring auf 0 behauptete „nichts gegessen" (Fehler `01`)',
      );
      expect(t.bilanz.status, Zielstatus.keineWerte);
    });

    test('über dem Ziel sagt sie es auch', () {
      final t = tag(
        eigene: [eintrag(id: 1, kcal: 4000)],
        tageswerte: tageswerteDa([tageswert(heute)]),
      );
      expect(t.bilanz.status, Zielstatus.ueberZiel);
      expect(t.bilanz.abweichungKcal, greaterThan(0));
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  group('Die Makroziele', () {
    test('sie hängen am Gewicht und fehlen ohne eines', () {
      final mitGewicht = tag();
      expect(mitGewicht.makroziele.eiweissMinG, isNotNull);
      expect(mitGewicht.makroziele.fettMinG, isNotNull);

      final ohneGewicht = tag(
        tageswerte: LeerNachLauf<List<DailyMetrics>>(gelaufen: jetzt),
      );
      expect(
        ohneGewicht.makroziele.eiweissMinG,
        isNull,
        reason: 'nie `0` — ein Ziel von 0 g stünde sofort auf „erfüllt"',
      );
      expect(ohneGewicht.makroziele.fettMinG, isNull);
    });

    test('die vier festen Ziele stehen immer', () {
      final ohneGewicht = tag(
        tageswerte: LeerNachLauf<List<DailyMetrics>>(gelaufen: jetzt),
      );
      expect(ohneGewicht.makroziele.ballaststoffeMinG, 30);
      // #408 (Tims Meldung vom 07.11.2026): ohne Gewicht 2 l. Mit Gewicht
      // hängt das Wasserziel am Gewicht und ist kein festes Ziel mehr.
      expect(ohneGewicht.makroziele.wasserMinMl, 2000);
    });

    // Nachtrag vom 04.11.2026: Seit dem Umbau des Entwurfsboards
    // (`docs/screens/screens/ernaehrung.js`, Commit eab3818) trägt der
    // Schirm **drei Ringe** — Eiweiß, Kohlenhydrate, Fett. Das
    // Kohlenhydratziel steht in `docs/SPEC.md` nicht; es wird aus dem
    // Kalorienziel gerechnet (#310, `makrozieleFuer`). Damit hängt es an
    // einer Zahl, die dieser Tag schon kennt — und der Tag ist die
    // einzige Stelle, an der beide zusammenkommen.
    test('das Kohlenhydratziel kommt aus dem Kalorienziel (#310)', () {
      final t = tag(eigene: [eintrag()]);

      expect(
        t.zielKcal,
        isNotNull,
        reason: 'Vorbedingung: sonst prüft die nächste Zeile nichts',
      );
      expect(
        t.makroziele.kohlenhydrateZielG,
        makrozieleFuer(
          gewichtKg: 80,
          kalorienzielKcal: t.zielKcal,
        ).kohlenhydrateZielG,
        reason:
            'das Ziel ist der Rest des Budgets nach den Mindestmengen '
            'Eiweiß und Fett. Eine eigene Rechnung im Tag wäre eine '
            'zweite, die der ersten widersprechen kann',
      );
      expect(t.makroziele.kohlenhydrateZielG, greaterThan(0));
    });

    test('ohne Kalorienziel fehlt es — und steht nicht auf 0', () {
      // Das Gewicht ist da (Eiweiß und Fett haben Ziele), die Stammdaten
      // fehlen. Ohne Kalorienziel gibt es keinen Rest zu verteilen.
      final t = tag(stammdaten: const Stammdaten());

      expect(t.zielKcal, isNull);
      expect(t.makroziele.eiweissMinG, isNotNull);
      expect(t.makroziele.fettMinG, isNotNull);
      expect(
        t.makroziele.kohlenhydrateZielG,
        isNull,
        reason:
            'ein Kohlenhydratring auf 0 behauptete „nichts gegessen" — '
            'Fehler `01` in neuer Verpackung',
      );
    });

    test('und während der Health-Lauf läuft, fehlt es ebenfalls', () {
      final t = tag(tageswerte: const NochNie<List<DailyMetrics>>());

      expect(t.zielLaedt, isTrue);
      expect(
        t.makroziele.kohlenhydrateZielG,
        isNull,
        reason:
            'solange nachgesehen wird, ist nichts entschieden — weder das '
            'Kalorienziel noch der Rest danach',
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  group('Wertgleichheit — sonst rechnet der Schirm je Bild neu (`03`)', () {
    test('zweimal dieselbe Eingabe ergibt zwei gleiche Tage', () {
      final a = tag(eigene: [eintrag(kcal: 400)]);
      final b = tag(eigene: [eintrag(kcal: 400)]);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('ein anderer Eintrag ergibt einen ungleichen Tag', () {
      final a = tag(eigene: [eintrag(kcal: 400)]);
      final b = tag(eigene: [eintrag(kcal: 500)]);
      expect(a, isNot(b));
    });

    test('auch MahlzeitZeile und FremdeMahlzeit vergleichen über ihre Werte', () {
      expect(
        fremdeMahlzeit(kcal: 300),
        fremdeMahlzeit(kcal: 300),
      );
      expect(
        fremdeMahlzeit(kcal: 300).hashCode,
        fremdeMahlzeit(kcal: 300).hashCode,
      );
      expect(fremdeMahlzeit(kcal: 300), isNot(fremdeMahlzeit(kcal: 400)));

      final a = tag(eigene: [eintrag(kcal: 400)]);
      final b = tag(eigene: [eintrag(kcal: 400)]);
      expect(zeile(a, Mahlzeit.mittag), zeile(b, Mahlzeit.mittag));
      expect(
        zeile(a, Mahlzeit.mittag).hashCode,
        zeile(b, Mahlzeit.mittag).hashCode,
      );
    });
  });
}
