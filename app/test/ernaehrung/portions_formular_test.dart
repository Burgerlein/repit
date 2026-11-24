import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/data/ernaehrung_repository.dart';
import 'package:repit/data/lebensmittel_repository.dart';
import 'package:repit/data/portion.dart';
import 'package:repit/data/portionen_repository.dart';
import 'package:repit/ernaehrung/erfassen_formular.dart';
import 'package:repit/ernaehrung/erfassen_provider.dart';
import 'package:repit/ernaehrung/off_client.dart';
import 'package:repit/ernaehrung/portions_abruf.dart';
import 'package:repit/ernaehrung/portions_text.dart';
import 'package:repit/health/health_provider.dart';

/// Tests für **Portionswahl, Vorwahl und Buchen mit Portion** (#398, unter
/// #325): die Texte, `BuchungsFormular` mit Portionen und die Wege
/// `oeffneFormular`, `buche` und `aendere` an einer echten Datenbank.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung**
/// (`CLAUDE.md`). Diese Datei darf ausgeführt, aber nicht verändert
/// werden. `erfassen_formular_test.dart`, `erfassen_rundweg_test.dart` und
/// `erfassen_view_test.dart` bleiben, wie sie sind, und müssen grün
/// bleiben.
///
/// Geschrieben nach Task 6 des Plans
/// `docs/superpowers/plans/2026-11-05-portionen.md` und der Spec
/// `docs/superpowers/specs/2026-11-05-portionen-design.md` (Entscheidungen
/// 7–9 und 11, V3, V6, V7, V9, V11, V12, „Vorwahl", „eintraege") — **ohne**
/// den Code der neuen Teile gesehen zu haben (es gab ihn beim Schreiben
/// noch nicht).
///
/// ## Was diese Tests verbindlich vorgeben (aus dem Plan)
///
/// ```dart
/// // lib/ernaehrung/portions_text.dart
/// String portionsKnopf(Portion p, {required bool fluessig});
/// String portionsRechnung({required double anzahl,
///     required double portionG, required bool fluessig});
/// String gebuchtePortion({required double mengeG, required String name,
///     required double portionG});
///
/// // BuchungsFormular, zusätzlich (== und hashCode):
/// final List<Portion> portionen;      // Vorgabe []
/// final Portion? portion;             // null = „g" gewählt
/// final String anzahlText;
/// factory BuchungsFormular.neu({…, List<Portion> portionen = const [],
///     PortionsVorwahl? vorwahl});
/// BuchungsFormular waehlePortion(Portion p);    // Anzahl „1"
/// BuchungsFormular waehleGramm();               // mengeText = Menge
/// BuchungsFormular mitAnzahl(String text);
/// BuchungsFormular plus();
/// BuchungsFormular minus();
/// BuchungsFormular mitPortionen(List<Portion> portionen);
/// BuchungsFormular mitNeuerPortion(Portion p);
/// BuchungsFormular mitGeaenderterPortion(Portion alt, Portion neu);
/// BuchungsFormular ohnePortion(Portion p);
/// BuchungsFormular mitAbruf(AbrufFertig abruf);
///
/// // ErfassenNotifier, zusätzlich:
/// Future<BuchungsFormular> oeffneFormular({required LebensmittelVorlage
///     vorlage, required String tagesSchluessel, required DateTime jetzt,
///     Mahlzeit? mahlzeit});
/// Future<int> legeLebensmittelAn(LebensmittelVorlage vorlage,
///     {List<Portion> portionen = const []});
/// Future<List<Portion>> legePortionAn(int lebensmittelId, Portion p);
/// Future<List<Portion>> aenderePortion(int lebensmittelId, Portion p);
/// Future<List<Portion>> loeschePortion(int lebensmittelId, Portion p);
/// ```
///
/// ## Die Lücke aus Task 4/5, hier mitgeprüft
///
/// **Der Schnappschuss darf auf keinem Weg verloren gehen.**
/// `BuchungsFormular.alsEintrag()` nimmt `portionId`, `portionName` und
/// `portionG` mit; ein Formular aus `BuchungsFormular.fuer(Eintrag)` trägt
/// sie weiter; `mitMahlzeit`, `mitUhrzeit` und `uebernommenAls` lassen sie
/// stehen; und wer im Ändern-Blatt die Anzahl ändert und sichert, behält
/// die Portion. Nur der Wechsel auf „g" nimmt sie weg (V12).
///
/// ## Festlegungen des Test-Agenten — nicht von Tim freigegeben
///
/// - **`anzahlText` ist deutsch geschrieben**, ohne nachgehängte Null:
///   „1", „2", „0,5", „3,33". So steht die Zahl im Ziffernblock (V7).
/// - **`mengeText` nach `waehleGramm` hat höchstens eine
///   Nachkommastelle**, wie die Gramm in den Texten: 3 × 5,9 g ergibt
///   „17,7" und nicht „17,700000000000003".
/// - **`minus` bei gesperrtem − gibt ein gleiches Formular zurück**
///   (`==`, das der Plan für `BuchungsFormular` verlangt).
/// - **`mitAbruf` für einen Online-Treffer** hält `portionen` und
///   `uebernahme.offPortionen` gleich, aufsteigend nach Menge.
/// - **`mitNeuerPortion` usw.** werden an einem **gescannten** Produkt
///   geprüft (`offPortionen` schon gesetzt). Was sie an einem Online-Treffer
///   tun, dessen Abruf noch läuft oder gescheitert ist, legt diese Datei
///   nicht fest: Setzten sie dort `uebernahme.offPortionen` von `null` auf
///   eine Liste, schriebe `uebernimm` beim Buchen
///   `portionen_abgefragt_am`, obwohl Open Food Facts nie geantwortet hat
///   (V4), und das Produkt fragte nie wieder. Das ist an den Koordinator
///   gemeldet.
/// - **`oeffneFormular` fragt Open Food Facts nicht.** Die eine Anfrage je
///   Öffnen gehört dem Abruf-Provider (`portions_abruf_test.dart`); fragte
///   auch `oeffneFormular`, wären es zwei.
/// - **`buche` mit einer gespeicherten Portion** schreibt deren `id` als
///   `portion_id`.
///
/// Alle Produkte, Namen und Zahlen sind **erfunden**, alle Zeitpunkte
/// liegen im Jahr 2099.
void main() {
  // Dienstag, 07.04.2099, 12:00 Berliner Zeit (MESZ, +2).
  final jetzt = DateTime.utc(2099, 4, 7, 10);
  const tag = '2099-04-07';

  const barcodeSkyr = '0000000000062';

  const bonsJe100g = Naehrwerte.je100g(
    kcal: 520,
    eiweissG: 8,
    kohlenhydrateG: 55,
    fettG: 30,
  );
  const skyrJe100g = Naehrwerte.je100g(
    kcal: 64,
    eiweissG: 10.5,
    kohlenhydrateG: 4,
    fettG: 0.3,
  );

  // Gespeicherte Portionen eines gespeicherten Lebensmittels.
  const bon = Portion(id: 11, name: 'Bon', mengeG: 5.9);
  const packung = Portion(
    id: 12,
    name: 'Packung',
    mengeG: 225,
    herkunft: Herkunft.off,
  );

  // Portionen eines noch nicht übernommenen Produkts — ohne Schlüssel.
  const portion150 = Portion(
    name: 'Portion',
    mengeG: 150,
    herkunft: Herkunft.off,
  );
  const packung500 = Portion(
    name: 'Packung',
    mengeG: 500,
    herkunft: Herkunft.off,
  );

  const eigene = LebensmittelVorlage(
    id: 5,
    name: 'Prüf-Bons',
    je100g: bonsJe100g,
  );

  /// Ein Online-Treffer: noch nicht in der Tabelle, Portionen nicht
  /// abgefragt.
  const online = LebensmittelVorlage(
    name: 'Prüf-Skyr Erfundenwerk',
    je100g: skyrJe100g,
    barcode: barcodeSkyr,
    herkunft: Herkunft.off,
  );

  /// Dasselbe Produkt gescannt: Die Antwort kam mit dem Scan.
  const gescannt = LebensmittelVorlage(
    name: 'Prüf-Skyr Erfundenwerk',
    je100g: skyrJe100g,
    barcode: barcodeSkyr,
    herkunft: Herkunft.off,
    offPortionen: [portion150, packung500],
  );

  BuchungsFormular blatt({
    LebensmittelVorlage vorlage = eigene,
    List<Portion> portionen = const [bon, packung],
    PortionsVorwahl? vorwahl,
  }) => BuchungsFormular.neu(
    vorlage: vorlage,
    tagesSchluessel: tag,
    jetzt: jetzt,
    portionen: portionen,
    vorwahl: vorwahl,
  );

  /// Zwei Bons, vorgewählt.
  BuchungsFormular zweiBons() => blatt(vorwahl: const VorwahlPortion(11, 2));

  /// Ein gebuchter Eintrag „2 Bon (11,8 g)".
  final gebuchtZweiBons = Eintrag(
    id: 7,
    tagesSchluessel: tag,
    mahlzeit: Mahlzeit.snack,
    zeitpunkt: DateTime.utc(2099, 4, 7, 14, 20),
    lebensmittelId: 5,
    name: 'Prüf-Bons',
    mengeG: 11.8,
    naehrwerte: bonsJe100g.fuerMenge(11.8),
    portionId: 11,
    portionName: 'Bon',
    portionG: 5.9,
  );

  // ═════════════════════════════════════════════════════════════════════
  group('Texte — Knopf, Rechenzeile, gebuchte Portion', () {
    test('der Knopf heißt „Name (Gramm g)"', () {
      expect(portionsKnopf(bon, fluessig: false), 'Bon (5,9 g)');
    });

    test('bei Flüssigem steht ml', () {
      expect(
        portionsKnopf(
          const Portion(name: 'Portion', mengeG: 250),
          fluessig: true,
        ),
        'Portion (250 ml)',
      );
    });

    test('Gramm mit höchstens einer Nachkommastelle, ohne nachgehängte '
        'Null, mit Tausenderpunkt', () {
      expect(
        portionsKnopf(
          const Portion(name: 'Schale', mengeG: 33.333),
          fluessig: false,
        ),
        'Schale (33,3 g)',
      );
      expect(
        portionsKnopf(
          const Portion(name: 'Riegel', mengeG: 5),
          fluessig: false,
        ),
        'Riegel (5 g)',
      );
      expect(
        portionsKnopf(
          const Portion(name: 'Packung', mengeG: 1000),
          fluessig: true,
        ),
        'Packung (1.000 ml)',
      );
    });

    test('Rechenzeile „2 × 5,9 g = 11,8 g"', () {
      expect(
        portionsRechnung(anzahl: 2, portionG: 5.9, fluessig: false),
        '2 × 5,9 g = 11,8 g',
      );
    });

    test('Rechenzeile mit halber Portion: „0,5 × 60 g = 30 g"', () {
      expect(
        portionsRechnung(anzahl: 0.5, portionG: 60, fluessig: false),
        '0,5 × 60 g = 30 g',
      );
    });

    test('Rechenzeile: Anzahl mit bis zu zwei Stellen, das Ergebnis ohne '
        'Rechenrauschen', () {
      expect(
        portionsRechnung(anzahl: 1.25, portionG: 60, fluessig: false),
        '1,25 × 60 g = 75 g',
      );
      // 3 × 5,9 ist im Rechner 17,700000000000003.
      expect(
        portionsRechnung(anzahl: 3, portionG: 5.9, fluessig: false),
        '3 × 5,9 g = 17,7 g',
      );
    });

    test('Rechenzeile bei Flüssigem in ml', () {
      expect(
        portionsRechnung(anzahl: 2, portionG: 250, fluessig: true),
        '2 × 250 ml = 500 ml',
      );
    });

    test('gebuchte Portion „2 Bon (11,8 g)" — ohne ×, Gramm in Klammern '
        '(V9)', () {
      expect(
        gebuchtePortion(mengeG: 11.8, name: 'Bon', portionG: 5.9),
        '2 Bon (11,8 g)',
      );
    });

    test('gebuchte Portion mit gebrochener Anzahl', () {
      expect(
        gebuchtePortion(mengeG: 30, name: 'Portion', portionG: 60),
        '0,5 Portion (30 g)',
      );
      expect(
        gebuchtePortion(mengeG: 10, name: 'Schale', portionG: 3),
        '3,33 Schale (10 g)',
      );
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Ein frisches Blatt — Vorwahl (Entscheidung 7)', () {
    test('ohne Vorwahl ist „g" gewählt, mit 100', () {
      final f = blatt();

      expect(f.portion, isNull);
      expect(f.mengeText, '100');
      expect(f.mengeG, 100);
      expect(f.portionen, [bon, packung]);
    });

    test('ohne Portionen ist die Liste leer, nicht null', () {
      final f = BuchungsFormular.neu(
        vorlage: eigene,
        tagesSchluessel: tag,
        jetzt: jetzt,
      );

      expect(f.portionen, isEmpty);
      expect(f.portion, isNull);
      expect(f.mengeText, '100');
    });

    test('Vorwahl „2 × Bon" wählt Bon mit Anzahl 2', () {
      final f = zweiBons();

      expect(f.portion, bon);
      expect(f.anzahlText, '2');
      expect(f.mengeG, closeTo(11.8, 1e-9));
      expect(f.kannBuchen, isTrue);
    });

    test('Vorwahl mit gebrochener Anzahl', () {
      final f = blatt(vorwahl: const VorwahlPortion(12, 0.5));

      expect(f.portion, packung);
      expect(f.anzahlText, '0,5');
      expect(f.mengeG, closeTo(112.5, 1e-9));
    });

    test('Vorwahl „g" mit 11,8 setzt die Menge', () {
      final f = blatt(vorwahl: const VorwahlGramm(11.8));

      expect(f.portion, isNull);
      expect(f.mengeText, '11,8');
      expect(f.mengeG, closeTo(11.8, 1e-9));
    });

    test(
      'ein gescanntes Produkt bringt seine Portionen aus der Vorlage mit',
      () {
        final f = BuchungsFormular.neu(
          vorlage: gescannt,
          tagesSchluessel: tag,
          jetzt: jetzt,
        );

        expect(f.portionen, [portion150, packung500]);
        expect(f.portion, isNull);
        expect(f.uebernahme!.offPortionen, [portion150, packung500]);
      },
    );

    test('ein Online-Treffer ohne Abruf hat noch keine Portionen', () {
      final f = BuchungsFormular.neu(
        vorlage: online,
        tagesSchluessel: tag,
        jetzt: jetzt,
      );

      expect(f.portionen, isEmpty);
      expect(f.uebernahme, isNotNull);
      expect(f.uebernahme!.offPortionen, isNull);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Mit Portion rechnet das Blatt Anzahl × Gramm', () {
    test('die Nährwerte folgen aus 11,8 g', () {
      final f = zweiBons();

      expect(f.naehrwerte.kcal, closeTo(520 * 11.8 / 100, 1e-9));
      expect(f.naehrwerte.fettG, closeTo(30 * 11.8 / 100, 1e-9));
    });

    test('Buchen verlangt eine Anzahl größer 0', () {
      expect(zweiBons().mitAnzahl('0').kannBuchen, isFalse);
      expect(zweiBons().mitAnzahl('').kannBuchen, isFalse);
      expect(zweiBons().mitAnzahl('zwei').kannBuchen, isFalse);
      expect(zweiBons().mitAnzahl('0,5').kannBuchen, isTrue);
    });

    test('die Anzahl „0,5" wird gelesen', () {
      final f = zweiBons().mitAnzahl('0,5');

      expect(f.anzahlText, '0,5');
      expect(f.mengeG, closeTo(2.95, 1e-9));
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Wechsel der Einheit (Entscheidung 9)', () {
    test('zwei Bons, „g" angetippt → „g" mit 11,8', () {
      final f = zweiBons().waehleGramm();

      expect(f.portion, isNull);
      expect(f.mengeText, '11,8');
      expect(f.mengeG, closeTo(11.8, 1e-9));
    });

    test('drei Bons, „g" angetippt → 17,7, ohne Rechenrauschen', () {
      final f = zweiBons().plus().waehleGramm();

      expect(f.mengeText, '17,7');
    });

    test('„Bon" angetippt → Anzahl 1', () {
      final f = blatt().mitMenge('30').waehlePortion(bon);

      expect(f.portion, bon);
      expect(f.anzahlText, '1');
      expect(f.mengeG, closeTo(5.9, 1e-9));
    });

    test('von zwei Bons auf „Packung" → Anzahl 1, nicht 2', () {
      final f = zweiBons().waehlePortion(packung);

      expect(f.portion, packung);
      expect(f.anzahlText, '1');
      expect(f.mengeG, closeTo(225, 1e-9));
    });

    test('die Portionen bleiben beim Wechsel auf „g" stehen', () {
      expect(zweiBons().waehleGramm().portionen, [bon, packung]);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Anzahl − und + (V7)', () {
    test('+ bei 2 ergibt 3', () {
      final f = zweiBons().plus();

      expect(f.anzahlText, '3');
      expect(f.mengeG, closeTo(17.7, 1e-9));
    });

    test('− bei 3 ergibt 2', () {
      expect(zweiBons().plus().minus().anzahlText, '2');
    });

    test('− bei 1 ändert nichts', () {
      final f = zweiBons().waehlePortion(bon);
      expect(f.anzahlText, '1');

      final danach = f.minus();

      expect(danach.anzahlText, '1');
      expect(danach.mengeG, closeTo(5.9, 1e-9));
      expect(danach, f);
    });

    test('− bei 0,5 ändert nichts', () {
      final f = zweiBons().mitAnzahl('0,5');

      expect(f.minus().anzahlText, '0,5');
    });

    test('− bei 1,5 geht auf 1, nicht unter 1', () {
      expect(zweiBons().mitAnzahl('1,5').minus().anzahlText, '1');
    });

    test('+ bei 0,5 ergibt 1,5', () {
      expect(zweiBons().mitAnzahl('0,5').plus().anzahlText, '1,5');
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Die Wahl übersteht die anderen Gesten', () {
    test('Mahlzeit und Uhrzeit umstellen lassen die Portion stehen', () {
      final f = zweiBons().mitMahlzeit(Mahlzeit.abend).mitUhrzeit(19 * 60 + 5);

      expect(f.portion, bon);
      expect(f.anzahlText, '2');
      expect(f.portionen, [bon, packung]);
      expect(f.mengeG, closeTo(11.8, 1e-9));
    });

    test('nach dem Übernehmen bleibt die Wahl', () {
      final f = BuchungsFormular.neu(
        vorlage: gescannt,
        tagesSchluessel: tag,
        jetzt: jetzt,
      ).waehlePortion(portion150).plus().uebernommenAls(40);

      expect(f.lebensmittelId, 40);
      expect(f.portion, portion150);
      expect(f.anzahlText, '2');
      expect(f.mengeG, closeTo(300, 1e-9));
      expect(f.alsEintrag().portionName, 'Portion');
      expect(f.alsEintrag().portionG, 150);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Die Portionen kommen an (mitAbruf, V6)', () {
    test(
      'gespeichertes Lebensmittel, „g" mit 30 gewählt → bleibt „g" mit 30',
      () {
        const neuePortion = Portion(
          id: 13,
          name: 'Portion',
          mengeG: 25,
          herkunft: Herkunft.off,
        );
        final f = blatt(portionen: const []).mitMenge('30');

        final danach = f.mitAbruf(
          AbrufFertig(portionen: const [neuePortion, packung], fluessig: false),
        );

        expect(danach.portion, isNull);
        expect(danach.mengeText, '30');
        expect(danach.portionen, [neuePortion, packung]);
        expect(danach.uebernahme, isNull);
      },
    );

    test('gespeichertes Lebensmittel mit zwei Bons → die Wahl bleibt', () {
      const neuePortion = Portion(
        id: 13,
        name: 'Portion',
        mengeG: 25,
        herkunft: Herkunft.off,
      );

      final danach = zweiBons().mitAbruf(
        AbrufFertig(
          portionen: const [bon, neuePortion, packung],
          fluessig: false,
        ),
      );

      expect(danach.portion, bon);
      expect(danach.anzahlText, '2');
      expect(danach.portionen, [bon, neuePortion, packung]);
    });

    test('Online-Treffer, „g" mit 30 → bleibt „g" mit 30, und die Portionen '
        'gehen mit der Übernahme', () {
      final f = BuchungsFormular.neu(
        vorlage: online,
        tagesSchluessel: tag,
        jetzt: jetzt,
      ).mitMenge('30');

      final danach = f.mitAbruf(
        AbrufFertig(portionen: const [portion150, packung500], fluessig: false),
      );

      expect(danach.portion, isNull);
      expect(danach.mengeText, '30');
      expect(danach.portionen, [portion150, packung500]);
      expect(danach.uebernahme!.offPortionen, [portion150, packung500]);
    });

    test('Online-Treffer mit fluessig: true → das Blatt rechnet in ml, die '
        'Zahl bleibt', () {
      final f = BuchungsFormular.neu(
        vorlage: online,
        tagesSchluessel: tag,
        jetzt: jetzt,
      ).mitMenge('30');
      expect(f.fluessig, isFalse);

      final danach = f.mitAbruf(
        AbrufFertig(
          portionen: const [
            Portion(name: 'Portion', mengeG: 250, herkunft: Herkunft.off),
          ],
          fluessig: true,
        ),
      );

      expect(danach.fluessig, isTrue);
      expect(danach.uebernahme!.fluessig, isTrue);
      expect(danach.portion, isNull);
      expect(danach.mengeText, '30');
    });

    test('Online-Treffer, nicht gefunden → [] ist eine Antwort, nicht '
        '„nicht abgefragt"', () {
      final danach = BuchungsFormular.neu(
        vorlage: online,
        tagesSchluessel: tag,
        jetzt: jetzt,
      ).mitAbruf(AbrufFertig(portionen: const [], fluessig: false));

      expect(danach.portionen, isEmpty);
      expect(danach.uebernahme!.offPortionen, isNotNull);
      expect(danach.uebernahme!.offPortionen, isEmpty);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Die Liste ändert sich (mitPortionen, V11)', () {
    test('die gewählte Portion fehlt → „g" mit der bisherigen Menge', () {
      final danach = zweiBons().mitPortionen(const [packung]);

      expect(danach.portion, isNull);
      expect(danach.mengeText, '11,8');
      expect(danach.portionen, [packung]);
    });

    test('die gewählte Portion ist geändert → bleibt gewählt, Anzahl bleibt, '
        'Gramm neu', () {
      final bonNeu = bon.mit(name: 'Schoko-Bon', mengeG: 6.1);

      final danach = zweiBons().mitPortionen([bonNeu, packung]);

      expect(danach.portion, bonNeu);
      expect(danach.anzahlText, '2');
      expect(danach.mengeG, closeTo(12.2, 1e-9));
    });

    test('eine ungespeicherte gewählte Portion wird über Name und Menge '
        'wiedergefunden', () {
      final f = BuchungsFormular.neu(
        vorlage: gescannt,
        tagesSchluessel: tag,
        jetzt: jetzt,
      ).waehlePortion(portion150).plus();
      const gespeichert = Portion(
        id: 41,
        name: 'Portion',
        mengeG: 150,
        herkunft: Herkunft.off,
      );

      final danach = f.mitPortionen(const [gespeichert, packung500]);

      expect(danach.portion, gespeichert);
      expect(danach.anzahlText, '2');
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Portionen eines noch nicht übernommenen Produkts leben im Blatt '
      '(V3)', () {
    BuchungsFormular gescanntesBlatt() => BuchungsFormular.neu(
      vorlage: gescannt,
      tagesSchluessel: tag,
      jetzt: jetzt,
    );

    test(
      'mitNeuerPortion: dazu, gewählt mit Anzahl 1, und in der Übernahme',
      () {
        const loeffel = Portion(name: 'Löffel', mengeG: 15);

        final f = gescanntesBlatt().mitNeuerPortion(loeffel);

        expect(f.portionen, unorderedEquals([loeffel, portion150, packung500]));
        expect(f.portion, loeffel);
        expect(f.anzahlText, '1');
        expect(f.mengeG, closeTo(15, 1e-9));
        expect(
          f.uebernahme!.offPortionen,
          unorderedEquals([loeffel, portion150, packung500]),
        );
      },
    );

    test(
      'mitGeaenderterPortion: ersetzt in beiden Listen, die Wahl bleibt',
      () {
        final becher = portion150.mit(name: 'Becher', mengeG: 160);

        final f = gescanntesBlatt()
            .waehlePortion(portion150)
            .plus()
            .mitGeaenderterPortion(portion150, becher);

        expect(f.portionen, unorderedEquals([becher, packung500]));
        expect(
          f.uebernahme!.offPortionen,
          unorderedEquals([becher, packung500]),
        );
        expect(f.portion, becher);
        expect(f.anzahlText, '2');
        expect(f.mengeG, closeTo(320, 1e-9));
      },
    );

    test('ohnePortion: aus beiden Listen, die gewählte springt auf „g" mit '
        'der aktuellen Menge', () {
      final f = gescanntesBlatt()
          .waehlePortion(portion150)
          .plus()
          .ohnePortion(portion150);

      expect(f.portionen, [packung500]);
      expect(f.uebernahme!.offPortionen, [packung500]);
      expect(f.portion, isNull);
      expect(f.mengeText, '300');
    });

    test('ohnePortion einer nicht gewählten lässt die Wahl stehen', () {
      final f = gescanntesBlatt()
          .waehlePortion(portion150)
          .ohnePortion(packung500);

      expect(f.portion, portion150);
      expect(f.portionen, [portion150]);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Was gebucht wird — der Schnappschuss (Entscheidung 8)', () {
    test('2 × Bon (5,9) → 11,8 g samt Schnappschuss', () {
      final e = zweiBons().alsEintrag();

      expect(e.mengeG, closeTo(11.8, 1e-9));
      expect(e.portionId, 11);
      expect(e.portionName, 'Bon');
      expect(e.portionG, 5.9);
      expect(e.naehrwerte.kcal, closeTo(520 * 11.8 / 100, 1e-9));
    });

    test('mit „g" sind alle drei null', () {
      final e = blatt().mitMenge('30').alsEintrag();

      expect(e.mengeG, 30);
      expect(e.portionId, isNull);
      expect(e.portionName, isNull);
      expect(e.portionG, isNull);
    });

    test('nach dem Wechsel von zwei Bons auf „g" sind alle drei null', () {
      final e = zweiBons().waehleGramm().alsEintrag();

      expect(e.mengeG, closeTo(11.8, 1e-9));
      expect(e.portionId, isNull);
      expect(e.portionName, isNull);
      expect(e.portionG, isNull);
    });

    test('eine ungespeicherte Portion bucht Name und Gramm ohne ID', () {
      final e = BuchungsFormular.neu(
        vorlage: gescannt,
        tagesSchluessel: tag,
        jetzt: jetzt,
      ).waehlePortion(portion150).alsEintrag();

      expect(e.portionId, isNull);
      expect(e.portionName, 'Portion');
      expect(e.portionG, 150);
      expect(e.mengeG, closeTo(150, 1e-9));
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Ändern — das Blatt aus dem Eintrag (V12)', () {
    test('mit Schnappschuss: die Portion ist gewählt, Anzahl 2, und die Liste '
        'ist genau diese eine', () {
      final f = BuchungsFormular.fuer(gebuchtZweiBons);

      const erwartet = Portion(id: 11, name: 'Bon', mengeG: 5.9);
      expect(f.portion, erwartet);
      expect(f.portionen, [erwartet]);
      expect(f.anzahlText, '2');
      expect(f.mengeG, closeTo(11.8, 1e-9));
    });

    test('unverändert gesichert verliert der Eintrag seine Portion nicht', () {
      final e = BuchungsFormular.fuer(gebuchtZweiBons).alsEintrag();

      expect(e.id, 7);
      expect(e.mengeG, closeTo(11.8, 1e-9));
      expect(e.portionId, 11);
      expect(e.portionName, 'Bon');
      expect(e.portionG, 5.9);
    });

    test(
      'Anzahl geändert und gesichert: die Portion bleibt, die Menge folgt',
      () {
        final e = BuchungsFormular.fuer(gebuchtZweiBons).plus().alsEintrag();

        expect(e.mengeG, closeTo(17.7, 1e-9));
        expect(e.portionId, 11);
        expect(e.portionName, 'Bon');
        expect(e.portionG, 5.9);
      },
    );

    test('Mahlzeit umgehängt und gesichert: die Portion bleibt', () {
      final e = BuchungsFormular.fuer(gebuchtZweiBons)
          .mitMahlzeit(Mahlzeit.abend)
          .alsEintrag();

      expect(e.portionId, 11);
      expect(e.portionName, 'Bon');
      expect(e.portionG, 5.9);
    });

    test('auf „g" gewechselt und gesichert: alle drei null', () {
      final e = BuchungsFormular.fuer(gebuchtZweiBons)
          .waehleGramm()
          .alsEintrag();

      expect(e.mengeG, closeTo(11.8, 1e-9));
      expect(e.portionId, isNull);
      expect(e.portionName, isNull);
      expect(e.portionG, isNull);
    });

    test('bis zum Sichern lässt sich zurückwechseln', () {
      final aufGramm = BuchungsFormular.fuer(gebuchtZweiBons).waehleGramm();
      final zurueck = aufGramm.waehlePortion(aufGramm.portionen.single);
      final e = zurueck.alsEintrag();

      expect(e.portionId, 11);
      expect(e.portionName, 'Bon');
      expect(e.portionG, 5.9);
    });

    test('ein Schnappschuss ohne Zeile (portion_id null) bleibt ein '
        'Schnappschuss', () {
      final ohneZeile = gebuchtZweiBons.copyWith(portionId: () => null);

      final f = BuchungsFormular.fuer(ohneZeile);
      final e = f.alsEintrag();

      expect(f.portion, const Portion(name: 'Bon', mengeG: 5.9));
      expect(f.anzahlText, '2');
      expect(e.portionId, isNull);
      expect(e.portionName, 'Bon');
      expect(e.portionG, 5.9);
    });

    test(
      'ohne Schnappschuss bleibt alles wie bisher: „g", keine Portionen',
      () {
        final ohne = gebuchtZweiBons.copyWith(
          mengeG: () => 30,
          naehrwerte: bonsJe100g.fuerMenge(30),
          portionId: () => null,
          portionName: () => null,
          portionG: () => null,
        );

        final f = BuchungsFormular.fuer(ohne);

        expect(f.portion, isNull);
        expect(f.portionen, isEmpty);
        expect(f.mengeText, '30');
        expect(f.alsEintrag().portionName, isNull);
      },
    );
  });

  // ═════════════════════════════════════════════════════════════════════
  group('An der Datenbank — oeffneFormular, buche, aendere', () {
    late AppCache db;
    late ProviderContainer container;
    late List<http.Request> anfragen;
    late LebensmittelRepository lebensmittel;
    late PortionenRepository portionen;
    late ErnaehrungRepository ernaehrung;

    setUp(() {
      db = AppCache(NativeDatabase.memory());
      anfragen = [];
      container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          appCacheProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(() => jetzt),
          offClientProvider.overrideWithValue(
            OffClient(
              client: MockClient((anfrage) async {
                anfragen.add(anfrage);
                return http.Response('nicht im Test', 500);
              }),
            ),
          ),
        ],
      );
      lebensmittel = LebensmittelRepository(db);
      portionen = PortionenRepository(db);
      ernaehrung = ErnaehrungRepository(db);
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    ErfassenNotifier erfassen() => container.read(erfassenProvider.notifier);

    Future<BuchungsFormular> oeffne(
      LebensmittelVorlage vorlage, {
      Mahlzeit? mahlzeit,
    }) => erfassen().oeffneFormular(
      vorlage: vorlage,
      tagesSchluessel: tag,
      jetzt: jetzt,
      mahlzeit: mahlzeit,
    );

    /// Prüf-Bons mit einer Portion „Bon (5,9 g)" in der Tabelle.
    Future<({int id, Portion bon})> bonsInDerTabelle() async {
      final id = await lebensmittel.legeAn(
        const LebensmittelVorlage(name: 'Prüf-Bons', je100g: bonsJe100g),
        portionen: const [Portion(name: 'Bon', mengeG: 5.9)],
      );
      return (id: id, bon: (await portionen.fuer(id)).single);
    }

    Future<void> gebucht(
      int lebensmittelId,
      double mengeG, {
      Portion? portion,
    }) => ernaehrung.buche(
      Eintrag(
        tagesSchluessel: tag,
        mahlzeit: Mahlzeit.snack,
        zeitpunkt: jetzt,
        lebensmittelId: lebensmittelId,
        name: 'Prüf-Bons',
        mengeG: mengeG,
        naehrwerte: bonsJe100g.fuerMenge(mengeG),
        portionId: portion?.id,
        portionName: portion?.name,
        portionG: portion?.mengeG,
      ),
    );

    Future<int> zeilenIn(String tabelle) async {
      final zeile = await db
          .customSelect('SELECT COUNT(*) AS n FROM $tabelle')
          .getSingle();
      return zeile.read<int>('n');
    }

    group('oeffneFormular', () {
      test('letzte Buchung „2 Bon" → Bon gewählt, Anzahl 2', () async {
        final b = await bonsInDerTabelle();
        await gebucht(b.id, 11.8, portion: b.bon);

        final f = await oeffne((await lebensmittel.lies(b.id))!);

        expect(f.portion, b.bon);
        expect(f.anzahlText, '2');
        expect(f.mengeG, closeTo(11.8, 1e-9));
        expect(f.portionen, [b.bon]);
      });

      test('die Portion ist inzwischen gelöscht → „g" mit 11,8', () async {
        final b = await bonsInDerTabelle();
        await gebucht(b.id, 11.8, portion: b.bon);
        await portionen.loesche(b.bon.id!);

        final f = await oeffne((await lebensmittel.lies(b.id))!);

        expect(f.portion, isNull);
        expect(f.mengeText, '11,8');
        expect(f.portionen, isEmpty);
      });

      test('ohne Buchung → „g" mit 100, die Portionen stehen da', () async {
        final b = await bonsInDerTabelle();

        final f = await oeffne((await lebensmittel.lies(b.id))!);

        expect(f.portion, isNull);
        expect(f.mengeText, '100');
        expect(f.portionen, [b.bon]);
      });

      test('es gilt die zuletzt gebuchte, nicht die erste Buchung', () async {
        final b = await bonsInDerTabelle();
        await gebucht(b.id, 11.8, portion: b.bon);
        await gebucht(b.id, 30);

        final f = await oeffne((await lebensmittel.lies(b.id))!);

        expect(f.portion, isNull);
        expect(f.mengeText, '30');
      });

      test('ein Online-Treffer ohne ID hat keine Vorwahl', () async {
        final f = await oeffne(online);

        expect(f.portion, isNull);
        expect(f.mengeText, '100');
        expect(f.portionen, isEmpty);
        expect(f.uebernahme, isNotNull);
      });

      test('ein gescanntes Produkt bringt seine Portionen mit', () async {
        final f = await oeffne(gescannt);

        expect(f.portionen, [portion150, packung500]);
        expect(f.portion, isNull);
      });

      test('die Mahlzeit wird durchgereicht', () async {
        final b = await bonsInDerTabelle();

        final f = await oeffne(
          (await lebensmittel.lies(b.id))!,
          mahlzeit: Mahlzeit.abend,
        );

        expect(f.mahlzeit, Mahlzeit.abend);
      });

      test(
        'Öffnen fragt Open Food Facts nicht — das tut allein der Abruf',
        () async {
          await oeffne(online);
          final id = await lebensmittel.legeAn(
            const LebensmittelVorlage(
              name: 'Prüf-Skyr alt',
              je100g: skyrJe100g,
              barcode: barcodeSkyr,
              herkunft: Herkunft.off,
            ),
          );
          await oeffne((await lebensmittel.lies(id))!);

          expect(anfragen, isEmpty);
        },
      );
    });

    group('buche', () {
      test('Online-Treffer mit abgerufener und gewählter „Portion" → '
          'Lebensmittel, beide Portionen und Eintrag stehen da', () async {
        var f = await oeffne(online);
        f = f.mitAbruf(
          AbrufFertig(
            portionen: const [portion150, packung500],
            fluessig: false,
          ),
        );
        f = f.waehlePortion(f.portionen.firstWhere((p) => p.name == 'Portion'));
        f = f.plus();

        await erfassen().buche(f);

        final uebernommen = await lebensmittel.zuBarcode(barcodeSkyr);
        expect(uebernommen, isNotNull);
        expect(uebernommen!.portionenAbgefragtAm, jetzt);

        final inTabelle = await portionen.fuer(uebernommen.id!);
        expect(inTabelle.map((p) => p.name), ['Portion', 'Packung']);
        final portionZeile = inTabelle.first;

        final e = (await ernaehrung.eintraegeAmTag(tag)).single;
        expect(e.lebensmittelId, uebernommen.id);
        expect(e.mengeG, closeTo(300, 1e-9));
        expect(e.portionId, portionZeile.id);
        expect(e.portionName, 'Portion');
        expect(e.portionG, 150);
      });

      test('eine im Blatt angelegte Portion geht mit — eigen — und der '
          'Eintrag zeigt auf ihre Zeile', () async {
        var f = await oeffne(gescannt);
        f = f.mitNeuerPortion(const Portion(name: 'Löffel', mengeG: 15)).plus();

        await erfassen().buche(f);

        final uebernommen = (await lebensmittel.zuBarcode(barcodeSkyr))!;
        final inTabelle = await portionen.fuer(uebernommen.id!);
        final loeffel = inTabelle.singleWhere((p) => p.name == 'Löffel');
        expect(loeffel.herkunft, Herkunft.eigen);
        expect(inTabelle, hasLength(3));

        final e = (await ernaehrung.eintraegeAmTag(tag)).single;
        expect(e.portionId, loeffel.id);
        expect(e.portionName, 'Löffel');
        expect(e.portionG, 15);
        expect(e.mengeG, closeTo(30, 1e-9));
      });

      test('liegt der Strichcode schon in der Tabelle: portion_id null, der '
          'Schnappschuss steht trotzdem da', () async {
        final vorhanden = await lebensmittel.legeAn(
          const LebensmittelVorlage(
            name: 'Prüf-Skyr alt',
            je100g: skyrJe100g,
            barcode: barcodeSkyr,
            herkunft: Herkunft.off,
          ),
        );

        var f = await oeffne(gescannt);
        f = f.waehlePortion(portion150);

        await erfassen().buche(f);

        expect(await portionen.fuer(vorhanden), isEmpty);
        final e = (await ernaehrung.eintraegeAmTag(tag)).single;
        expect(e.lebensmittelId, vorhanden);
        expect(e.portionId, isNull);
        expect(e.portionName, 'Portion');
        expect(e.portionG, 150);
        expect(e.mengeG, closeTo(150, 1e-9));
      });

      test('gespeichertes Lebensmittel, gespeicherte Portion → portion_id '
          'ist ihre ID', () async {
        final b = await bonsInDerTabelle();
        var f = await oeffne((await lebensmittel.lies(b.id))!);
        f = f.waehlePortion(b.bon).plus();

        await erfassen().buche(f);

        final e = (await ernaehrung.eintraegeAmTag(tag)).single;
        expect(e.portionId, b.bon.id);
        expect(e.portionName, 'Bon');
        expect(e.portionG, 5.9);
        expect(e.mengeG, closeTo(11.8, 1e-9));
      });

      test('ein nur geöffneter, nicht gebuchter Online-Treffer hinterlässt '
          'keine Zeile (V3)', () async {
        var f = await oeffne(online);
        f = f.mitAbruf(
          AbrufFertig(
            portionen: const [portion150, packung500],
            fluessig: false,
          ),
        );
        f = f.waehlePortion(f.portionen.first);
        // „Abbrechen": Das Formular wird verworfen, gebucht wird nicht.

        expect(await zeilenIn('lebensmittel'), 0);
        expect(await zeilenIn('portionen'), 0);
        expect(await zeilenIn('eintraege'), 0);
      });
    });

    group('aendere — die Portion geht im Ändern-Blatt nicht verloren', () {
      Future<Eintrag> zweiBonsGebucht() async {
        final b = await bonsInDerTabelle();
        var f = await oeffne((await lebensmittel.lies(b.id))!);
        f = f.waehlePortion(b.bon).plus();
        await erfassen().buche(f);
        return (await ernaehrung.eintraegeAmTag(tag)).single;
      }

      test('Anzahl geändert und gesichert: die Portion bleibt', () async {
        final vorher = await zweiBonsGebucht();

        await erfassen().aendere(BuchungsFormular.fuer(vorher).plus());

        final nachher = (await ernaehrung.eintraegeAmTag(tag)).single;
        expect(nachher.id, vorher.id);
        expect(nachher.mengeG, closeTo(17.7, 1e-9));
        expect(nachher.portionId, vorher.portionId);
        expect(nachher.portionName, 'Bon');
        expect(nachher.portionG, 5.9);
      });

      test('nur die Mahlzeit umgehängt: die Portion bleibt', () async {
        final vorher = await zweiBonsGebucht();

        await erfassen().aendere(
          BuchungsFormular.fuer(vorher).mitMahlzeit(Mahlzeit.abend),
        );

        final nachher = (await ernaehrung.eintraegeAmTag(tag)).single;
        expect(nachher.mahlzeit, Mahlzeit.abend);
        expect(nachher.mengeG, closeTo(11.8, 1e-9));
        expect(nachher.portionId, vorher.portionId);
        expect(nachher.portionName, 'Bon');
        expect(nachher.portionG, 5.9);
      });

      test('die Portion wurde seitdem geändert: das Ändern-Blatt rechnet mit '
          'dem Schnappschuss', () async {
        final vorher = await zweiBonsGebucht();
        await portionen.aendere(
          Portion(id: vorher.portionId, name: 'Schoko-Bon', mengeG: 6.1),
        );

        final f = BuchungsFormular.fuer(vorher);
        expect(f.portion!.name, 'Bon');
        expect(f.portion!.mengeG, 5.9);

        await erfassen().aendere(f.plus());

        final nachher = (await ernaehrung.eintraegeAmTag(tag)).single;
        expect(nachher.mengeG, closeTo(17.7, 1e-9));
        expect(nachher.portionName, 'Bon');
        expect(nachher.portionG, 5.9);
      });

      test('auf „g" gewechselt und gesichert: alle drei null', () async {
        final vorher = await zweiBonsGebucht();

        await erfassen().aendere(BuchungsFormular.fuer(vorher).waehleGramm());

        final nachher = (await ernaehrung.eintraegeAmTag(tag)).single;
        expect(nachher.mengeG, closeTo(11.8, 1e-9));
        expect(nachher.portionId, isNull);
        expect(nachher.portionName, isNull);
        expect(nachher.portionG, isNull);
      });
    });

    group(
      'Portionen anlegen, ändern, löschen — jede Antwort aus der Tabelle',
      () {
        test('legeLebensmittelAn nimmt die Portionen mit', () async {
          final id = await erfassen().legeLebensmittelAn(
            const LebensmittelVorlage(name: 'Prüf-Bons', je100g: bonsJe100g),
            portionen: const [Portion(name: 'Bon', mengeG: 5.9)],
          );

          final inTabelle = await portionen.fuer(id);
          expect(inTabelle.single.name, 'Bon');
          expect(inTabelle.single.mengeG, 5.9);
        });

        test(
          'legePortionAn gibt die neue Liste zurück, mit Schlüsseln',
          () async {
            final b = await bonsInDerTabelle();

            final liste = await erfassen().legePortionAn(
              b.id,
              const Portion(name: 'Schale', mengeG: 40),
            );

            expect(liste.map((p) => p.name), ['Bon', 'Schale']);
            expect(liste.every((p) => p.id != null), isTrue);
            expect(liste, await portionen.fuer(b.id));
          },
        );

        test('aenderePortion gibt die neue Liste zurück', () async {
          final b = await bonsInDerTabelle();

          final liste = await erfassen().aenderePortion(
            b.id,
            b.bon.mit(name: 'Schoko-Bon', mengeG: 6.1),
          );

          expect(liste.single.id, b.bon.id);
          expect(liste.single.name, 'Schoko-Bon');
          expect(liste.single.mengeG, 6.1);
          expect(liste, await portionen.fuer(b.id));
        });

        test('loeschePortion gibt die neue Liste zurück', () async {
          final b = await bonsInDerTabelle();
          await erfassen().legePortionAn(
            b.id,
            const Portion(name: 'Schale', mengeG: 40),
          );

          final liste = await erfassen().loeschePortion(b.id, b.bon);

          expect(liste.map((p) => p.name), ['Schale']);
          expect(liste, await portionen.fuer(b.id));
        });
      },
    );
  });
}
