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
import 'package:repit/ernaehrung/portions_text.dart';
import 'package:repit/ernaehrung/vorwahl_text.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_types.dart';

import 'health_schreiben_attrappe.dart';

/// Tests für **direktes Buchen mit „+" und die Vorwahl in der
/// Trefferzeile** (#438, unter #385).
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung**
/// (`CLAUDE.md`). Diese Datei darf ausgeführt, aber nicht verändert
/// werden. `portions_formular_test.dart` und `erfassen_formular_test.dart`
/// bleiben, wie sie sind, und müssen grün bleiben.
///
/// Geschrieben nach Task 9 des Plans
/// `docs/superpowers/plans/2026-11-10-mahlzeiten-aufteilung.md` und der
/// Spec `docs/superpowers/specs/2026-11-10-mahlzeiten-aufteilung-design.md`
/// (Schnitt 2, V22, V24, V25, V27) — **bevor** es die neuen Teile gab.
///
/// ## Was diese Tests verbindlich vorgeben (aus dem Plan)
///
/// ```dart
/// // ErfassenNotifier
/// Future<int> buche(BuchungsFormular formular);   // ID des neuen Eintrags
/// Future<int> bucheDirekt({required LebensmittelVorlage vorlage,
///     required String tagesSchluessel, required DateTime jetzt,
///     Mahlzeit? mahlzeit});
/// Future<void> nimmZurueck(int eintragId);
///
/// // ErnaehrungRepository
/// Future<Eintrag?> eintrag(int id);
///
/// // lib/ernaehrung/vorwahl_text.dart
/// ({String menge, double? kcal}) vorwahlAnzeige({
///     required LebensmittelVorlage vorlage, Eintrag? letzte});
///
/// // lib/ernaehrung/erfassen_formular.dart
/// Mahlzeit vorgewaehlteMahlzeit({required DateTime jetzt,
///     Mahlzeit? mahlzeit});
/// ```
///
/// ## Festlegungen des Test-Agenten — nicht von Tim freigegeben
///
/// - **`vorgewaehlteMahlzeit` liegt in `erfassen_formular.dart`**, neben
///   `BuchungsFormular.neu`, das sie ruft. Der Plan nennt die Datei nicht.
/// - **`letzte` ist der Eintrag, den die Suchzeile ohnehin hält** — der aus
///   `ErnaehrungRepository.letzteBuchungen` (`letztePortionenProvider`).
///   So wird er hier auch beschafft.
/// - **„Was die Zeile sagt, bucht das Plus" wird an den Gramm geprüft**:
///   Die Menge in der Zeile — ohne Portion die ganze Angabe, mit Portion
///   die in Klammern — ist die gebuchte Menge, in derselben Schreibweise
///   wie `portionsMenge`. Dazu die kcal. Ob die Zeile bei einer inzwischen
///   gelöschten Portion „2 Bon (11,8 g)" oder „11,8 g" sagt, legt diese
///   Datei **nicht** fest; nur, dass die Gramm stimmen.
/// - **Ohne kcal-Angabe ist `kcal` `null`**, nicht `0` (`CLAUDE.md`, „0 ist
///   keine Antwort auf ‚kein Wert'").
/// - **`bucheDirekt` ist `oeffneFormular` plus `buche`** (V25) und wird
///   daran gemessen: Ein über das Blatt unverändert gebuchter Eintrag und
///   ein direkt gebuchter stimmen in allem überein außer ID und
///   Health-Kopie.
/// - **`nimmZurueck` ein zweites Mal** für dieselbe ID tut nichts — der
///   Eintrag fehlt dann, wie bei einer unbekannten ID.
///
/// Alle Produkte, Namen, Zahlen, Strichcodes und Kennungen sind
/// **erfunden**, alle Zeitpunkte liegen im Jahr 2099.
void main() {
  // Dienstag, 07.04.2099, 12:00 Berliner Zeit (MESZ, +2).
  final jetzt = DateTime.utc(2099, 4, 7, 10);
  const tag = '2099-04-07';

  const barcodeQuark = '0000000000079';

  const bonsJe100g = Naehrwerte.je100g(
    kcal: 520,
    eiweissG: 8,
    kohlenhydrateG: 55,
    fettG: 30,
  );
  const flockenJe100g = Naehrwerte.je100g(
    kcal: 370,
    eiweissG: 13,
    kohlenhydrateG: 58,
    fettG: 7,
  );
  const saftJe100g = Naehrwerte.je100g(kcal: 44, kohlenhydrateG: 10);
  const quarkJe100g = Naehrwerte.je100g(
    kcal: 67,
    eiweissG: 12,
    kohlenhydrateG: 4,
    fettG: 0.2,
  );

  /// Ein Online-Treffer aus der Suche: noch nicht in der Tabelle,
  /// Portionen nicht abgefragt.
  const online = LebensmittelVorlage(
    name: 'Prüf-Quark Erfundenwerk',
    je100g: quarkJe100g,
    barcode: barcodeQuark,
    herkunft: Herkunft.off,
  );

  /// Die Menge, die in einem Zeilentext steht: mit Portion die Angabe in
  /// den letzten Klammern („2 Bon (11,8 g)" → „11,8 g"), sonst der ganze
  /// Text („80 g").
  String mengeIn(String zeile) {
    if (!zeile.endsWith(')')) return zeile;
    final auf = zeile.lastIndexOf('(');
    return zeile.substring(auf + 1, zeile.length - 1);
  }

  // ═════════════════════════════════════════════════════════════════════
  group('vorgewaehlteMahlzeit (V22)', () {
    test('ohne Mahlzeit um 12:30 Berliner Zeit → Mittag', () {
      // 10:30 UTC sind im April 12:30 in Berlin. Nach UTC gerechnet wäre
      // es noch Frühstück.
      expect(
        vorgewaehlteMahlzeit(jetzt: DateTime.utc(2099, 4, 7, 10, 30)),
        Mahlzeit.mittag,
      );
    });

    test('mit Abend → Abend, gleich zu welcher Uhrzeit', () {
      expect(
        vorgewaehlteMahlzeit(
          jetzt: DateTime.utc(2099, 4, 7, 10, 30),
          mahlzeit: Mahlzeit.abend,
        ),
        Mahlzeit.abend,
      );
    });

    test('eine vorgewählte Mahlzeit schlägt die Uhr auch abends', () {
      expect(
        vorgewaehlteMahlzeit(
          // 20:00 in Berlin.
          jetzt: DateTime.utc(2099, 4, 7, 18),
          mahlzeit: Mahlzeit.fruehstueck,
        ),
        Mahlzeit.fruehstueck,
      );
    });

    test('das Buchungsblatt wählt dieselbe Mahlzeit vor — zu jeder '
        'Uhrzeit', () {
      const vorlage = LebensmittelVorlage(
        name: 'Prüf-Flocken',
        je100g: flockenJe100g,
      );
      for (final zeitpunkt in [
        DateTime.utc(2099, 4, 7, 0, 30), // 02:30 Berlin
        DateTime.utc(2099, 4, 7, 5), // 07:00 Berlin
        DateTime.utc(2099, 4, 7, 10, 30), // 12:30 Berlin
        DateTime.utc(2099, 4, 7, 14), // 16:00 Berlin
        DateTime.utc(2099, 4, 7, 18), // 20:00 Berlin
        DateTime.utc(2099, 1, 13, 9, 45), // 10:45 Berlin, Winterzeit
      ]) {
        final blatt = BuchungsFormular.neu(
          vorlage: vorlage,
          tagesSchluessel: tag,
          jetzt: zeitpunkt,
        );
        expect(
          blatt.mahlzeit,
          vorgewaehlteMahlzeit(jetzt: zeitpunkt),
          reason: 'um $zeitpunkt',
        );
      }
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('An der Datenbank', () {
    late AppCache db;
    late ProviderContainer container;
    late List<http.Request> anfragen;
    late SchreibAttrappe health;
    late LebensmittelRepository lebensmittel;
    late PortionenRepository portionen;
    late ErnaehrungRepository ernaehrung;

    setUp(() {
      db = AppCache(NativeDatabase.memory());
      anfragen = [];
      health = SchreibAttrappe();
      container = ProviderContainer(
        // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
        retry: (_, _) => null,
        overrides: [
          appCacheProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(() => jetzt),
          healthProvider.overrideWithValue(health),
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

    Future<int> direkt(LebensmittelVorlage vorlage, {Mahlzeit? mahlzeit}) =>
        erfassen().bucheDirekt(
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

    Future<int> flockenInDerTabelle() => lebensmittel.legeAn(
      const LebensmittelVorlage(name: 'Prüf-Flocken', je100g: flockenJe100g),
    );

    Future<int> saftInDerTabelle() => lebensmittel.legeAn(
      const LebensmittelVorlage(
        name: 'Prüf-Saft',
        je100g: saftJe100g,
        fluessig: true,
      ),
    );

    /// Eine frühere Buchung, gestern, damit sie die Zählung von heute nicht
    /// stört.
    Future<void> frueherGebucht(
      int lebensmittelId,
      String name,
      Naehrwerte je100g,
      double mengeG, {
      Portion? portion,
      bool? fluessig,
    }) => ernaehrung.buche(
      Eintrag(
        tagesSchluessel: '2099-04-06',
        mahlzeit: Mahlzeit.snack,
        zeitpunkt: DateTime.utc(2099, 4, 6, 14),
        lebensmittelId: lebensmittelId,
        name: name,
        mengeG: mengeG,
        naehrwerte: je100g.fuerMenge(mengeG),
        portionId: portion?.id,
        portionName: portion?.name,
        portionG: portion?.mengeG,
        fluessig: fluessig,
      ),
    );

    /// Was die Suchzeile über die letzte Buchung weiß.
    Future<Eintrag?> letzteVon(int lebensmittelId) async =>
        (await ernaehrung.letzteBuchungen({lebensmittelId}))[lebensmittelId];

    Future<LebensmittelVorlage> vorlage(int id) async =>
        (await lebensmittel.lies(id))!;

    Future<Eintrag> heuteGebucht(int id) async =>
        (await ernaehrung.eintraegeAmTag(tag)).singleWhere((e) => e.id == id);

    Future<int> zeilenIn(String tabelle) async {
      final zeile = await db
          .customSelect('SELECT COUNT(*) AS n FROM $tabelle')
          .getSingle();
      return zeile.read<int>('n');
    }

    // ───────────────────────────────────────────────────────────────────
    group('ErnaehrungRepository.eintrag', () {
      test('liest einen gebuchten Eintrag samt Kopie', () async {
        final id = await ernaehrung.buche(
          Eintrag(
            tagesSchluessel: tag,
            mahlzeit: Mahlzeit.mittag,
            zeitpunkt: jetzt,
            name: 'Prüf-Brei',
            mengeG: 200,
            naehrwerte: const Naehrwerte(kcal: 300),
          ),
        );
        await ernaehrung.setzeHealthKopie(
          id,
          healthUuid: 'C0FFEE00-0000-0000-0000-0000000000BB',
          stand: HealthStand.geschrieben,
        );

        final e = await ernaehrung.eintrag(id);

        expect(e, isNotNull);
        expect(e!.id, id);
        expect(e.name, 'Prüf-Brei');
        expect(e.mengeG, 200);
        expect(e.healthUuid, 'C0FFEE00-0000-0000-0000-0000000000BB');
        expect(e.healthStand, HealthStand.geschrieben);
      });

      test('eine unbekannte ID ergibt null', () async {
        expect(await ernaehrung.eintrag(4711), isNull);
      });
    });

    // ───────────────────────────────────────────────────────────────────
    group('buche gibt die ID des neuen Eintrags zurück', () {
      test('die ID ist die des gebuchten Eintrags', () async {
        final f = await erfassen().oeffneFormular(
          vorlage: await vorlage(await flockenInDerTabelle()),
          tagesSchluessel: tag,
          jetzt: jetzt,
        );

        final id = await erfassen().buche(f);

        expect((await ernaehrung.eintraegeAmTag(tag)).single.id, id);
      });
    });

    // ───────────────────────────────────────────────────────────────────
    group('Eigenes Lebensmittel, zuletzt „2 Bon"', () {
      test('bucheDirekt bucht 11,8 g mit Schnappschuss „Bon" auf die '
          'vorgewählte Mahlzeit', () async {
        final b = await bonsInDerTabelle();
        await frueherGebucht(
          b.id,
          'Prüf-Bons',
          bonsJe100g,
          11.8,
          portion: b.bon,
        );

        final id = await direkt(await vorlage(b.id));

        final e = await heuteGebucht(id);
        expect(e.lebensmittelId, b.id);
        expect(e.mengeG, closeTo(11.8, 1e-9));
        expect(e.portionId, b.bon.id);
        expect(e.portionName, 'Bon');
        expect(e.portionG, 5.9);
        expect(e.naehrwerte.kcal, closeTo(520 * 11.8 / 100, 1e-9));
        // 12:00 in Berlin.
        expect(e.mahlzeit, Mahlzeit.mittag);
        expect(e.mahlzeit, vorgewaehlteMahlzeit(jetzt: jetzt));
        expect(e.tagesSchluessel, tag);
      });

      test('vorwahlAnzeige sagt „2 Bon (11,8 g)" und die kcal dieser '
          'Menge', () async {
        final b = await bonsInDerTabelle();
        await frueherGebucht(
          b.id,
          'Prüf-Bons',
          bonsJe100g,
          11.8,
          portion: b.bon,
        );

        final anzeige = vorwahlAnzeige(
          vorlage: await vorlage(b.id),
          letzte: await letzteVon(b.id),
        );

        expect(anzeige.menge, '2 Bon (11,8 g)');
        expect(anzeige.kcal, closeTo(520 * 11.8 / 100, 1e-9));
      });

      test('mit vorgewählter Mahlzeit bucht es auf diese', () async {
        final b = await bonsInDerTabelle();
        await frueherGebucht(
          b.id,
          'Prüf-Bons',
          bonsJe100g,
          11.8,
          portion: b.bon,
        );

        final id = await direkt(await vorlage(b.id), mahlzeit: Mahlzeit.abend);

        expect((await heuteGebucht(id)).mahlzeit, Mahlzeit.abend);
      });
    });

    // ───────────────────────────────────────────────────────────────────
    group('Zuletzt in Gramm, ohne Portion', () {
      test(
        'zuletzt 80 g → bucht 80 g ohne Schnappschuss, Anzeige „80 g"',
        () async {
          final id = await flockenInDerTabelle();
          await frueherGebucht(id, 'Prüf-Flocken', flockenJe100g, 80);

          final anzeige = vorwahlAnzeige(
            vorlage: await vorlage(id),
            letzte: await letzteVon(id),
          );
          final eintragId = await direkt(await vorlage(id));

          expect(anzeige.menge, '80 g');
          expect(anzeige.kcal, closeTo(370 * 0.8, 1e-9));

          final e = await heuteGebucht(eintragId);
          expect(e.mengeG, closeTo(80, 1e-9));
          expect(e.portionId, isNull);
          expect(e.portionName, isNull);
          expect(e.portionG, isNull);
          expect(e.naehrwerte.kcal, closeTo(370 * 0.8, 1e-9));
        },
      );

      test('ein Getränk, zuletzt 250 ml → Anzeige „250 ml"', () async {
        final id = await saftInDerTabelle();
        await frueherGebucht(id, 'Prüf-Saft', saftJe100g, 250, fluessig: true);

        final anzeige = vorwahlAnzeige(
          vorlage: await vorlage(id),
          letzte: await letzteVon(id),
        );

        expect(anzeige.menge, '250 ml');
        expect(anzeige.kcal, closeTo(44 * 2.5, 1e-9));
      });
    });

    // ───────────────────────────────────────────────────────────────────
    group('Nie gebucht', () {
      test('→ bucht 100 g, Anzeige „100 g" mit den kcal je 100 g', () async {
        final id = await flockenInDerTabelle();

        final anzeige = vorwahlAnzeige(vorlage: await vorlage(id));
        final eintragId = await direkt(await vorlage(id));

        expect(anzeige.menge, '100 g');
        expect(anzeige.kcal, closeTo(370, 1e-9));

        final e = await heuteGebucht(eintragId);
        expect(e.mengeG, closeTo(100, 1e-9));
        expect(e.portionName, isNull);
      });

      test('flüssig → „100 ml", gebucht als Flüssigkeit', () async {
        final id = await saftInDerTabelle();

        final anzeige = vorwahlAnzeige(vorlage: await vorlage(id));
        final eintragId = await direkt(await vorlage(id));

        expect(anzeige.menge, '100 ml');
        expect(anzeige.kcal, closeTo(44, 1e-9));

        final e = await heuteGebucht(eintragId);
        expect(e.mengeG, closeTo(100, 1e-9));
        expect(e.fluessig, isTrue);
      });

      test('ohne kcal-Angabe ist kcal null, nicht 0', () async {
        final id = await lebensmittel.legeAn(
          const LebensmittelVorlage(
            name: 'Prüf-Gewürz',
            je100g: Naehrwerte.je100g(eiweissG: 3),
          ),
        );

        final anzeige = vorwahlAnzeige(vorlage: await vorlage(id));

        expect(anzeige.menge, '100 g');
        expect(anzeige.kcal, isNull);
      });
    });

    // ───────────────────────────────────────────────────────────────────
    group('Online-Treffer (V24, V25)', () {
      test('vorwahlAnzeige sagt „100 g" mit den kcal je 100 g', () {
        final anzeige = vorwahlAnzeige(vorlage: online);

        expect(anzeige.menge, '100 g');
        expect(anzeige.kcal, closeTo(67, 1e-9));
      });

      test('bucheDirekt übernimmt das Produkt und bucht 100 g — ohne '
          'Portionen, ohne Anfrage an Open Food Facts', () async {
        final eintragId = await direkt(online);

        final uebernommen = await lebensmittel.zuBarcode(barcodeQuark);
        expect(uebernommen, isNotNull);
        expect(uebernommen!.name, 'Prüf-Quark Erfundenwerk');
        // Nie gefragt, also nie beantwortet: Das nächste Öffnen des Blatts
        // fragt einmal nach (#325, Entscheidung 6).
        expect(uebernommen.portionenAbgefragtAm, isNull);
        expect(await portionen.fuer(uebernommen.id!), isEmpty);

        final e = await heuteGebucht(eintragId);
        expect(e.lebensmittelId, uebernommen.id);
        expect(e.mengeG, closeTo(100, 1e-9));
        expect(e.portionName, isNull);
        expect(e.naehrwerte.kcal, closeTo(67, 1e-9));

        expect(anfragen, isEmpty);
      });

      test('zweimal „+" auf denselben Online-Treffer legt das Produkt nur '
          'einmal an', () async {
        await direkt(online);
        await direkt(online);

        expect(await zeilenIn('lebensmittel'), 1);
        expect(await zeilenIn('eintraege'), 2);
        expect(anfragen, isEmpty);
      });
    });

    // ───────────────────────────────────────────────────────────────────
    group('Was die Zeile sagt, bucht das Plus (V24)', () {
      test('für jede Vorlage ist die Menge der Zeile die gebuchte Menge, '
          'und die kcal stimmen', () async {
        final b = await bonsInDerTabelle();
        await frueherGebucht(
          b.id,
          'Prüf-Bons',
          bonsJe100g,
          11.8,
          portion: b.bon,
        );
        final flocken = await flockenInDerTabelle();
        await frueherGebucht(flocken, 'Prüf-Flocken', flockenJe100g, 80);
        final saft = await saftInDerTabelle();

        // Ein Lebensmittel, dessen Portion seit der letzten Buchung
        // gelöscht wurde: Das Blatt wählt dann „g" mit 11,8 vor.
        final alt = await bonsInDerTabelle();
        await frueherGebucht(
          alt.id,
          'Prüf-Bons',
          bonsJe100g,
          11.8,
          portion: alt.bon,
        );
        await portionen.loesche(alt.bon.id!);

        for (final id in [b.id, flocken, saft, alt.id]) {
          final v = await vorlage(id);
          final anzeige = vorwahlAnzeige(
            vorlage: v,
            letzte: await letzteVon(id),
          );

          final e = await heuteGebucht(await direkt(v));

          expect(
            mengeIn(anzeige.menge),
            portionsMenge(e.mengeG!, fluessig: v.fluessig),
            reason: '${v.name} (#$id): „${anzeige.menge}"',
          );
          expect(
            anzeige.kcal,
            closeTo(e.naehrwerte.kcal!, 1e-9),
            reason: '${v.name} (#$id)',
          );
        }
      });
    });

    // ───────────────────────────────────────────────────────────────────
    group('bucheDirekt ist oeffneFormular plus buche (V25)', () {
      test('ein direkt gebuchter Eintrag gleicht einem unverändert über das '
          'Blatt gebuchten', () async {
        final b = await bonsInDerTabelle();
        await frueherGebucht(
          b.id,
          'Prüf-Bons',
          bonsJe100g,
          11.8,
          portion: b.bon,
        );
        final v = await vorlage(b.id);

        final ueberBlatt = await erfassen().buche(
          await erfassen().oeffneFormular(
            vorlage: v,
            tagesSchluessel: tag,
            jetzt: jetzt,
            mahlzeit: Mahlzeit.snack,
          ),
        );
        final ueberPlus = await direkt(v, mahlzeit: Mahlzeit.snack);

        Object inhalt(Eintrag e) => (
          tag: e.tagesSchluessel,
          mahlzeit: e.mahlzeit,
          zeitpunkt: e.zeitpunkt,
          lebensmittelId: e.lebensmittelId,
          name: e.name,
          mengeG: e.mengeG,
          naehrwerte: e.naehrwerte,
          portionId: e.portionId,
          portionName: e.portionName,
          portionG: e.portionG,
          fluessig: e.fluessig,
          vorschlag: e.vorschlag,
        );

        expect(
          inhalt(await heuteGebucht(ueberPlus)),
          inhalt(await heuteGebucht(ueberBlatt)),
        );
      });

      test('die Benutzung wird gemerkt — die Vorlage steht danach '
          'obenan', () async {
        final id = await flockenInDerTabelle();

        await direkt(await vorlage(id));

        expect((await vorlage(id)).zuletztBenutzt, jetzt);
      });

      test('mit Freigabe wird die Health-Kopie geschrieben wie im '
          'Blatt', () async {
        final id = await flockenInDerTabelle();

        final eintragId = await direkt(await vorlage(id));

        final kopie = health.geschrieben.single;
        expect(kopie.name, 'Prüf-Flocken');
        final e = await heuteGebucht(eintragId);
        expect(e.healthUuid, kopie.id);
        expect(e.healthStand, HealthStand.geschrieben);
      });

      test('ohne Freigabe ist trotzdem gebucht, der Eintrag steht auf '
          '„offen"', () async {
        health.freigabe = WriteAuthorization.denied;
        final id = await flockenInDerTabelle();

        final eintragId = await direkt(await vorlage(id));

        final e = await heuteGebucht(eintragId);
        expect(e.healthUuid, isNull);
        expect(e.healthStand, HealthStand.offen);
        expect(health.geschrieben, isEmpty);
      });
    });

    // ───────────────────────────────────────────────────────────────────
    group('nimmZurueck (V27)', () {
      test('der Eintrag ist weg, die Health-Kopie wird gelöscht', () async {
        final id = await flockenInDerTabelle();
        final eintragId = await direkt(await vorlage(id));
        final kopie = health.geschrieben.single.id;

        await erfassen().nimmZurueck(eintragId);

        expect(await ernaehrung.eintrag(eintragId), isNull);
        expect(await ernaehrung.eintraegeAmTag(tag), isEmpty);
        expect(health.loeschVersuche, [kopie]);
      });

      test('auch eine Kopie, die erst nach bucheDirekt geschrieben wurde, '
          'wird gelöscht — der Eintrag wird frisch gelesen', () async {
        health.freigabe = WriteAuthorization.denied;
        final id = await flockenInDerTabelle();
        final eintragId = await direkt(await vorlage(id));
        expect(health.geschrieben, isEmpty);

        // Die Freigabe kommt, der Nachlauf schreibt die Kopie nach — nach
        // dem Buchen, während das Band noch steht.
        health.freigabe = WriteAuthorization.granted;
        await erfassen().healthNachlauf();
        final kopie = health.geschrieben.single.id;
        expect((await ernaehrung.eintrag(eintragId))!.healthUuid, kopie);

        await erfassen().nimmZurueck(eintragId);

        expect(await ernaehrung.eintrag(eintragId), isNull);
        expect(health.loeschVersuche, [kopie]);
      });

      test('ein Eintrag ohne Kopie wird zurückgenommen, ohne Health zu '
          'fragen', () async {
        health.freigabe = WriteAuthorization.denied;
        final id = await flockenInDerTabelle();
        final eintragId = await direkt(await vorlage(id));

        await erfassen().nimmZurueck(eintragId);

        expect(await ernaehrung.eintrag(eintragId), isNull);
        expect(health.loeschVersuche, isEmpty);
      });

      test('nur dieser Eintrag geht, die anderen bleiben', () async {
        final id = await flockenInDerTabelle();
        final erster = await direkt(await vorlage(id));
        final zweiter = await direkt(await vorlage(id));

        await erfassen().nimmZurueck(zweiter);

        expect((await ernaehrung.eintraegeAmTag(tag)).map((e) => e.id), [
          erster,
        ]);
      });

      test('eine unbekannte ID tut nichts', () async {
        final id = await flockenInDerTabelle();
        final eintragId = await direkt(await vorlage(id));
        final vorher = await ernaehrung.eintraegeAmTag(tag);

        await erfassen().nimmZurueck(eintragId + 1000);

        expect(await ernaehrung.eintraegeAmTag(tag), vorher);
        expect(health.loeschVersuche, isEmpty);
      });

      test('ein zweites Zurücknehmen derselben ID tut nichts mehr', () async {
        final id = await flockenInDerTabelle();
        final eintragId = await direkt(await vorlage(id));
        await erfassen().nimmZurueck(eintragId);
        final loeschungen = health.loeschVersuche.length;

        await erfassen().nimmZurueck(eintragId);

        expect(health.loeschVersuche, hasLength(loeschungen));
        expect(await ernaehrung.eintraegeAmTag(tag), isEmpty);
      });
    });
  });
}
