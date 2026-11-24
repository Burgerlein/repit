import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/core/messwert.dart';
import 'package:repit/data/cache.dart';
import 'package:repit/data/ernaehrung_repository.dart';
import 'package:repit/data/lebensmittel_repository.dart';
import 'package:repit/data/portion.dart';
import 'package:repit/data/portionen_repository.dart';
import 'package:repit/data/stammdaten.dart';
import 'package:repit/ernaehrung/buchungs_blatt.dart';
import 'package:repit/ernaehrung/erfassen_formular.dart';
import 'package:repit/ernaehrung/erfassen_provider.dart';
import 'package:repit/ernaehrung/ernaehrung_provider.dart';
import 'package:repit/ernaehrung/mahlzeit_view.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_types.dart';

import '../design/support.dart' show textOf;
import 'health_schreiben_attrappe.dart';

/// Tests für **gebuchte Getränke in Millilitern** (#403, unter #275): die
/// Mahlzeitenzeile, das Ändern-Blatt und der Weg, auf dem der Eintrag sein
/// `fluessig` bekommt.
///
/// Geschrieben nach dem Ticket #403 („Mahlzeitenzeile: Getränke stehen mit
/// g statt ml") und dem Auftrag des Koordinators vom 10.11.2026 —
/// **bevor** Eintrag, Zeile oder Blatt davon wussten. Für die
/// Widget-Tests genügt ein Agent, wenn der Test zuerst entsteht, rot
/// gesehen und vor der Implementierung committet wird (`CLAUDE.md`, „Wer
/// Tests schreibt, schreibt nicht die Implementierung"). Diese Datei darf
/// ausgeführt, aber nicht verändert werden.
///
/// Spalte und Migration prüft `test/data/schema_v20_test.dart`, das Feld am
/// Eintrag und den Rundweg durchs Repository
/// `test/data/eintrag_fluessig_test.dart`.
///
/// ## Die Anforderung
///
/// Ein gebuchtes Getränk zeigt in Mahlzeitenzeile und Ändern-Blatt **ml**
/// statt g: „2 Glas (500 ml) · 16:20", „330 ml · 16:20". Wo ein Text
/// geprüft wird, ist er der Zustand — „ml" gegen „g" ist genau der Fehler.
///
/// ## Woher die Einheit kommt (Weg (a))
///
/// 1. **Der Schnappschuss am Eintrag** (`Eintrag.fluessig`), geschrieben
///    beim Buchen aus `LebensmittelVorlage.fluessig` — über das
///    Buchungsblatt (`BuchungsFormular.alsEintrag`), auch bei einem aus
///    Open Food Facts übernommenen Produkt, und beim Rückgängigmachen
///    einer Löschung wieder mit.
/// 2. **Steht dort `null`** (jeder Eintrag von vor der Stufe 20), fällt die
///    Anzeige auf die Vorlage zurück, **sonst auf g.**
///
/// Der Schnappschuss gewinnt gegen die Vorlage: Wird sie später fest oder
/// flüssig gestellt oder gelöscht, bleibt die Einheit des Eintrags.
///
/// ## Was hier vorausgesetzt wird
///
/// Nur, was schon steht, und was die beiden Nachbardateien verlangen
/// (`Eintrag({… fluessig})`). Die Schlüssel stammen aus
/// `portion_aendern_blatt_test.dart` (`portion-gramm`, `portion-knopf-<i>`,
/// `portion-anzahl`, `portion-plus`, `portion-zeile`, `buchung-sichern`,
/// `mahlzeit-eintrag-<id>`). Neue Schlüssel führt diese Datei nicht ein.
/// Wie die Anzeige den Rückfall auf die Vorlage liest, regelt sie nicht —
/// nur, dass er gilt. Er darf aber keine Abfrage je Zeile kosten
/// (`CLAUDE.md`, Hausregel 2).
///
/// ## Festlegungen des Test-Agenten — nicht von Tim freigegeben
///
/// - **Weg (a)**, Schnappschuss am Eintrag — Begründung im Kopf von
///   `schema_v20_test.dart`.
/// - **Der Rückfall gilt auch im Ändern-Blatt**, wenn es über den echten
///   Weg (Tippen auf die Zeile) geöffnet wird. Ein Blatt in Gramm unter
///   einer Zeile in Millilitern widerspräche sich auf demselben Schirm.
/// - **Ob ein altes Getränk beim Sichern im Ändern-Blatt seinen
///   Schnappschuss bekommt**, regelt dieser Test nicht — nur, dass die
///   Zeile danach weiter ml zeigt.
/// - **Der „g"-Knopf heißt bei einem Getränk „ml"** — so steht es heute
///   schon im Wähler (`portions_waehler.dart`), und so wird er hier
///   geprüft. Wer auf ihn wechselt und sichert, behält ml.
///
/// Alle Produkte, Namen und Zahlen sind **erfunden**, alle Zeitpunkte
/// liegen im Jahr 2099.
void main() {
  // Dienstag, 07.04.2099, 18:00 Berliner Zeit (MESZ, +2).
  final jetzt = DateTime.utc(2099, 4, 7, 16);
  const heute = '2099-04-07';

  // 16:20 Berliner Zeit.
  final gegessen = DateTime.utc(2099, 4, 7, 14, 20);

  const saftJe100g = Naehrwerte.je100g(
    kcal: 44,
    eiweissG: 0.7,
    kohlenhydrateG: 9.9,
    fettG: 0.1,
  );

  const brotJe100g = Naehrwerte.je100g(
    kcal: 233,
    eiweissG: 8.8,
    kohlenhydrateG: 41,
    fettG: 1.9,
  );

  /// Ein Schlüssel, unter dem keine Vorlage steht.
  const ohneVorlage = 901;

  const vollstaendig = Stammdaten(
    groesseCm: 180,
    geburtsjahr: 1990,
    zielgewichtKg: 84,
    zieldatum: '2100-01-14',
  );

  // --- Hilfsmittel, wie in `portion_aendern_blatt_test.dart` ---------------

  ({ProviderContainer container, AppCache db}) behaelter() {
    final db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);
    // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        appCacheProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => jetzt),
        healthProvider.overrideWithValue(SchreibAttrappe()),
        stammdatenProvider.overrideWith(() => _Stammdaten(vollstaendig)),
        dailyMetricsProvider.overrideWith(
          () => _Tageswerte(
            Bekannt<List<DailyMetrics>>(
              [
                DailyMetrics(
                  tag: heute,
                  activeKcal: 600,
                  basalKcal: 1600,
                  weightKg: 80,
                ),
              ],
              stand: jetzt,
              laeuft: false,
            ),
          ),
        ),
        fremdeMahlzeitenProvider.overrideWith2(
          (tag) => _Fremde(
            Bekannt<List<FremdeMahlzeit>>(
              const [],
              stand: jetzt,
              laeuft: false,
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    return (container: container, db: db);
  }

  void grossesFenster(WidgetTester tester) {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> zeige(
    WidgetTester tester,
    ProviderContainer container,
    Widget inhalt,
  ) async {
    grossesFenster(tester);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: CupertinoApp(home: CupertinoPageScaffold(child: inhalt)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder schluessel(String s) => find.byKey(Key(s));

  String textUnter(WidgetTester tester, Finder wo) => tester
      .widgetList<Text>(find.descendant(of: wo, matching: find.byType(Text)))
      .map(textOf)
      .join(' ');

  Widget snack() =>
      const MahlzeitView(tagesSchluessel: heute, mahlzeit: Mahlzeit.snack);

  Finder zeile(int eintragId) => schluessel('mahlzeit-eintrag-$eintragId');

  /// Die Vorlage „Prüf-Saft" (flüssig, mit „Glas" 250 ml) bzw. „Prüf-Brot"
  /// (fest, ohne Portion) — gibt Schlüssel und gespeicherte Portion.
  Future<({int id, Portion? glas, LebensmittelVorlage vorlage})> anlegen(
    ProviderContainer c, {
    required bool fluessig,
  }) async {
    final vorlage = fluessig
        ? const LebensmittelVorlage(
            name: 'Prüf-Saft',
            je100g: saftJe100g,
            fluessig: true,
          )
        : const LebensmittelVorlage(name: 'Prüf-Brot', je100g: brotJe100g);
    final id = await c
        .read(lebensmittelRepositoryProvider)
        .legeAn(
          vorlage,
          portionen: fluessig
              ? const [Portion(name: 'Glas', mengeG: 250)]
              : const [],
        );
    final portionen = await c.read(portionenRepositoryProvider).fuer(id);
    return (
      id: id,
      glas: portionen.where((p) => p.name == 'Glas').firstOrNull,
      vorlage: LebensmittelVorlage(
        id: id,
        name: vorlage.name,
        je100g: vorlage.je100g,
        fluessig: vorlage.fluessig,
      ),
    );
  }

  /// Der Eintrag [eintragId], wie er gerade in der Datei steht.
  Future<Eintrag> lies(ProviderContainer c, int eintragId) async {
    final alle = await c
        .read(ernaehrungRepositoryProvider)
        .eintraegeAmTag(heute);
    return alle.firstWhere((e) => e.id == eintragId);
  }

  /// `eintraege.fluessig`, roh aus der Datei — `1`, `0` oder `null`. Der
  /// Wert, den kein Rückfall auf die Vorlage verdecken kann.
  Future<int?> rohFluessig(AppCache db, int eintragId) async {
    final zeile = await db
        .customSelect('SELECT fluessig FROM eintraege WHERE id = $eintragId;')
        .getSingle();
    return zeile.read<int?>('fluessig');
  }

  /// Bucht um 16:20 als Snack — mit Portions-Schnappschuss, wenn [portion]
  /// gesetzt ist. Gibt den Schlüssel zurück.
  Future<int> buche(
    ProviderContainer c, {
    required int lebensmittelId,
    required String name,
    required double mengeG,
    required bool? fluessig,
    Portion? portion,
  }) => c
      .read(ernaehrungRepositoryProvider)
      .buche(
        Eintrag(
          tagesSchluessel: heute,
          mahlzeit: Mahlzeit.snack,
          zeitpunkt: gegessen,
          lebensmittelId: lebensmittelId,
          name: name,
          mengeG: mengeG,
          naehrwerte: saftJe100g.fuerMenge(mengeG),
          fluessig: fluessig,
          portionId: portion?.id,
          portionName: portion?.name,
          portionG: portion?.mengeG,
        ),
      );

  /// Macht aus einem gebuchten Eintrag einen von **vor der Stufe 20**:
  /// `fluessig` steht auf `NULL`, wie die Migration es hinterlässt.
  Future<void> alsAltfall(AppCache db, int eintragId) => db.customStatement(
    'UPDATE eintraege SET fluessig = NULL WHERE id = ?;',
    [eintragId],
  );

  Future<void> vorlageStellen(AppCache db, int id, {required bool fluessig}) =>
      db.customStatement('UPDATE lebensmittel SET fluessig = ? WHERE id = ?;', [
        fluessig ? 1 : 0,
        id,
      ]);

  /// 2 × Glas Saft, gebucht mit Schnappschuss — der Ausgangsfall.
  Future<({int vorlageId, Portion glas, int eintragId})> zweiGlas(
    ProviderContainer c,
  ) async {
    final s = await anlegen(c, fluessig: true);
    final id = await buche(
      c,
      lebensmittelId: s.id,
      name: 'Prüf-Saft',
      mengeG: 500,
      fluessig: true,
      portion: s.glas,
    );
    return (vorlageId: s.id, glas: s.glas!, eintragId: id);
  }

  /// 330 ml Saft ohne Portion, gebucht mit Schnappschuss.
  Future<({int vorlageId, int eintragId})> dosenmenge(
    ProviderContainer c,
  ) async {
    final s = await anlegen(c, fluessig: true);
    final id = await buche(
      c,
      lebensmittelId: s.id,
      name: 'Prüf-Saft',
      mengeG: 330,
      fluessig: true,
    );
    return (vorlageId: s.id, eintragId: id);
  }

  // ═════════════════════════════════════════════════════════════════════
  group('Buchen nimmt fluessig als Schnappschuss mit', () {
    test('das Formular einer flüssigen Vorlage bucht true, einer festen '
        'false', () {
      const saft = LebensmittelVorlage(
        id: 11,
        name: 'Prüf-Saft',
        je100g: saftJe100g,
        fluessig: true,
      );
      const brot = LebensmittelVorlage(
        id: 12,
        name: 'Prüf-Brot',
        je100g: brotJe100g,
      );

      BuchungsFormular neu(LebensmittelVorlage v) => BuchungsFormular.neu(
        vorlage: v,
        tagesSchluessel: heute,
        jetzt: jetzt,
        mahlzeit: Mahlzeit.snack,
      );

      expect(neu(saft).alsEintrag().fluessig, isTrue);
      expect(
        neu(brot).alsEintrag().fluessig,
        isFalse,
        reason: '„in Gramm gebucht" ist eine Aussage, kein Unbekannt',
      );
    });

    test('das Formular eines gebuchten Getränks bleibt flüssig und gibt es '
        'beim Sichern weiter', () {
      final getraenk = Eintrag(
        id: 5,
        tagesSchluessel: heute,
        mahlzeit: Mahlzeit.snack,
        zeitpunkt: gegessen,
        lebensmittelId: ohneVorlage,
        name: 'Prüf-Saft',
        mengeG: 500,
        naehrwerte: saftJe100g.fuerMenge(500),
        fluessig: true,
        portionName: 'Glas',
        portionG: 250,
      );

      final formular = BuchungsFormular.fuer(getraenk);

      expect(formular.fluessig, isTrue);
      expect(formular.alsEintrag().fluessig, isTrue);
      expect(
        BuchungsFormular.fuer(getraenk.copyWith(fluessig: () => false))
            .alsEintrag()
            .fluessig,
        isFalse,
      );
    });

    test('über das Buchungsblatt gebucht: in der Datei 1', () async {
      final b = behaelter();
      final s = await anlegen(b.container, fluessig: true);

      await b.container
          .read(erfassenProvider.notifier)
          .buche(
            BuchungsFormular.neu(
              vorlage: s.vorlage,
              tagesSchluessel: heute,
              jetzt: jetzt,
              mahlzeit: Mahlzeit.snack,
              portionen: [s.glas!],
            ),
          );

      final gebucht =
          (await b.container
                  .read(ernaehrungRepositoryProvider)
                  .eintraegeAmTag(heute))
              .single;
      expect(gebucht.fluessig, isTrue);
      expect(await rohFluessig(b.db, gebucht.id!), 1);
    });

    test('eine feste Vorlage über das Buchungsblatt: in der Datei 0', () async {
      final b = behaelter();
      final s = await anlegen(b.container, fluessig: false);

      await b.container
          .read(erfassenProvider.notifier)
          .buche(
            BuchungsFormular.neu(
              vorlage: s.vorlage,
              tagesSchluessel: heute,
              jetzt: jetzt,
              mahlzeit: Mahlzeit.snack,
            ),
          );

      final gebucht =
          (await b.container
                  .read(ernaehrungRepositoryProvider)
                  .eintraegeAmTag(heute))
              .single;
      expect(await rohFluessig(b.db, gebucht.id!), 0);
    });

    test('ein Getränk aus Open Food Facts, beim Buchen übernommen: in der '
        'Datei 1', () async {
      final b = behaelter();

      await b.container
          .read(erfassenProvider.notifier)
          .buche(
            BuchungsFormular.neu(
              vorlage: const LebensmittelVorlage(
                name: 'Prüf-Schorle',
                je100g: saftJe100g,
                fluessig: true,
                herkunft: Herkunft.off,
                barcode: '0000000000403',
              ),
              tagesSchluessel: heute,
              jetzt: jetzt,
              mahlzeit: Mahlzeit.snack,
            ),
          );

      final gebucht =
          (await b.container
                  .read(ernaehrungRepositoryProvider)
                  .eintraegeAmTag(heute))
              .single;
      expect(gebucht.lebensmittelId, isNotNull, reason: 'übernommen');
      expect(await rohFluessig(b.db, gebucht.id!), 1);
    });

    test(
      'gelöscht und rückgängig gemacht: fluessig kommt mit zurück',
      () async {
        final b = behaelter();
        // Ohne Vorlage — sonst verdeckte der Rückfall einen verlorenen
        // Schnappschuss.
        final id = await buche(
          b.container,
          lebensmittelId: ohneVorlage,
          name: 'Prüf-Saft',
          mengeG: 330,
          fluessig: true,
        );
        final vorher = await lies(b.container, id);

        await b.container.read(ernaehrungRepositoryProvider).loesche(id);
        await b.container
            .read(erfassenProvider.notifier)
            .stelleWiederHer(vorher);

        final zurueck =
            (await b.container
                    .read(ernaehrungRepositoryProvider)
                    .eintraegeAmTag(heute))
                .single;
        expect(zurueck.fluessig, isTrue);
        expect(await rohFluessig(b.db, zurueck.id!), 1);
      },
    );
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Die Mahlzeitenzeile', () {
    testWidgets('mit Portion: „2 Glas (500 ml) · 16:20"', (tester) async {
      final b = behaelter();
      final g = await zweiGlas(b.container);

      await zeige(tester, b.container, snack());

      final text = textUnter(tester, zeile(g.eintragId));
      expect(text, contains('2 Glas (500 ml) · 16:20'));
      expect(text, isNot(contains('500 g')));
    });

    testWidgets('ohne Portion: „330 ml · 16:20"', (tester) async {
      final b = behaelter();
      final d = await dosenmenge(b.container);

      await zeige(tester, b.container, snack());

      final text = textUnter(tester, zeile(d.eintragId));
      expect(text, contains('330 ml · 16:20'));
      expect(text, isNot(contains('330 g')));
    });

    testWidgets('etwas Festes bleibt in Gramm: „120 g · 16:20"', (
      tester,
    ) async {
      final b = behaelter();
      final s = await anlegen(b.container, fluessig: false);
      final id = await buche(
        b.container,
        lebensmittelId: s.id,
        name: 'Prüf-Brot',
        mengeG: 120,
        fluessig: false,
      );

      await zeige(tester, b.container, snack());

      final text = textUnter(tester, zeile(id));
      expect(text, contains('120 g · 16:20'));
      expect(text, isNot(contains('ml')));
    });

    testWidgets('die Vorlage danach fest gestellt: die Zeile bleibt in '
        'Millilitern', (tester) async {
      final b = behaelter();
      final g = await zweiGlas(b.container);
      await vorlageStellen(b.db, g.vorlageId, fluessig: false);

      await zeige(tester, b.container, snack());

      expect(
        textUnter(tester, zeile(g.eintragId)),
        contains('2 Glas (500 ml)'),
      );
    });

    testWidgets('die Vorlage danach flüssig gestellt: ein in Gramm '
        'gebuchter Eintrag bleibt in Gramm', (tester) async {
      final b = behaelter();
      final s = await anlegen(b.container, fluessig: false);
      final id = await buche(
        b.container,
        lebensmittelId: s.id,
        name: 'Prüf-Brot',
        mengeG: 120,
        fluessig: false,
      );
      await vorlageStellen(b.db, s.id, fluessig: true);

      await zeige(tester, b.container, snack());

      final text = textUnter(tester, zeile(id));
      expect(text, contains('120 g · 16:20'));
      expect(text, isNot(contains('120 ml')));
    });

    testWidgets('die Vorlage gelöscht: die Zeile bleibt in Millilitern', (
      tester,
    ) async {
      final b = behaelter();
      final d = await dosenmenge(b.container);
      await b.db.customStatement('DELETE FROM lebensmittel WHERE id = ?;', [
        d.vorlageId,
      ]);

      await zeige(tester, b.container, snack());

      expect(textUnter(tester, zeile(d.eintragId)), contains('330 ml · 16:20'));
    });

    testWidgets('Altfall ohne Schnappschuss: Die Zeile fällt auf die '
        'flüssige Vorlage zurück — „330 ml"', (tester) async {
      final b = behaelter();
      final d = await dosenmenge(b.container);
      await alsAltfall(b.db, d.eintragId);

      await zeige(tester, b.container, snack());

      final text = textUnter(tester, zeile(d.eintragId));
      expect(text, contains('330 ml · 16:20'));
      expect(text, isNot(contains('330 g')));
    });

    testWidgets('Altfall mit Portion: „2 Glas (500 ml)"', (tester) async {
      final b = behaelter();
      final g = await zweiGlas(b.container);
      await alsAltfall(b.db, g.eintragId);

      await zeige(tester, b.container, snack());

      expect(
        textUnter(tester, zeile(g.eintragId)),
        contains('2 Glas (500 ml) · 16:20'),
      );
    });

    testWidgets('Altfall ohne Vorlage: zurück auf Gramm', (tester) async {
      final b = behaelter();
      final id = await buche(
        b.container,
        lebensmittelId: ohneVorlage,
        name: 'Prüf-Saft',
        mengeG: 330,
        fluessig: null,
      );

      await zeige(tester, b.container, snack());

      expect(textUnter(tester, zeile(id)), contains('330 g · 16:20'));
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Das Ändern-Blatt', () {
    testWidgets('mit Portion: „ml", „Glas (250 ml)", „2 × 250 ml = '
        '500 ml"', (tester) async {
      final b = behaelter();
      final g = await zweiGlas(b.container);
      final eintrag = await lies(b.container, g.eintragId);

      await zeige(
        tester,
        b.container,
        BuchungsBlatt(formular: BuchungsFormular.fuer(eintrag)),
      );

      expect(textUnter(tester, schluessel('portion-gramm')), 'ml');
      expect(
        textUnter(tester, schluessel('portion-knopf-0')),
        contains('Glas (250 ml)'),
      );
      final rechnung = textUnter(tester, schluessel('portion-zeile'));
      expect(rechnung, contains('2 × 250 ml = 500 ml'));
      expect(rechnung, isNot(contains(' g')));
    });

    testWidgets('ohne Portion: „ml" und „330 ml"', (tester) async {
      final b = behaelter();
      final d = await dosenmenge(b.container);
      final eintrag = await lies(b.container, d.eintragId);

      await zeige(
        tester,
        b.container,
        BuchungsBlatt(formular: BuchungsFormular.fuer(eintrag)),
      );

      expect(textUnter(tester, schluessel('portion-gramm')), 'ml');
      final zeileText = textUnter(tester, schluessel('portion-zeile'));
      expect(zeileText, contains('330 ml'));
      expect(zeileText, isNot(contains('330 g')));
    });

    testWidgets('etwas Festes bleibt in Gramm', (tester) async {
      final b = behaelter();
      final s = await anlegen(b.container, fluessig: false);
      final id = await buche(
        b.container,
        lebensmittelId: s.id,
        name: 'Prüf-Brot',
        mengeG: 120,
        fluessig: false,
      );
      final eintrag = await lies(b.container, id);

      await zeige(
        tester,
        b.container,
        BuchungsBlatt(formular: BuchungsFormular.fuer(eintrag)),
      );

      expect(textUnter(tester, schluessel('portion-gramm')), 'g');
      expect(textUnter(tester, schluessel('portion-zeile')), contains('120 g'));
    });

    testWidgets('die Vorlage danach fest gestellt: das Blatt bleibt in '
        'Millilitern', (tester) async {
      final b = behaelter();
      final g = await zweiGlas(b.container);
      await vorlageStellen(b.db, g.vorlageId, fluessig: false);
      final eintrag = await lies(b.container, g.eintragId);

      await zeige(
        tester,
        b.container,
        BuchungsBlatt(formular: BuchungsFormular.fuer(eintrag)),
      );

      expect(textUnter(tester, schluessel('portion-gramm')), 'ml');
      expect(
        textUnter(tester, schluessel('portion-knopf-0')),
        contains('Glas (250 ml)'),
      );
    });

    testWidgets('+ und Sichern: Der Eintrag bleibt flüssig, die Zeile zeigt '
        '„3 Glas (750 ml)"', (tester) async {
      final b = behaelter();
      final g = await zweiGlas(b.container);

      await zeige(tester, b.container, snack());
      await tester.tap(zeile(g.eintragId));
      await tester.pumpAndSettle();
      await tester.tap(schluessel('portion-plus'));
      await tester.pumpAndSettle();
      await tester.tap(schluessel('buchung-sichern'));
      await tester.pumpAndSettle();

      expect(await rohFluessig(b.db, g.eintragId), 1);
      expect(
        textUnter(tester, zeile(g.eintragId)),
        contains('3 Glas (750 ml) · 16:20'),
      );
    });

    testWidgets('auf „ml" gewechselt und gesichert: Der Eintrag verliert die '
        'Portion, aber nicht die Einheit', (tester) async {
      final b = behaelter();
      final g = await zweiGlas(b.container);

      await zeige(tester, b.container, snack());
      await tester.tap(zeile(g.eintragId));
      await tester.pumpAndSettle();
      await tester.tap(schluessel('portion-gramm'));
      await tester.pumpAndSettle();
      await tester.tap(schluessel('buchung-sichern'));
      await tester.pumpAndSettle();

      final danach = await lies(b.container, g.eintragId);
      expect(danach.portionName, isNull);
      expect(danach.fluessig, isTrue);
      expect(await rohFluessig(b.db, g.eintragId), 1);
      expect(textUnter(tester, zeile(g.eintragId)), contains('500 ml · 16:20'));
    });

    testWidgets('Altfall über den echten Weg: Das Blatt fällt wie die Zeile '
        'auf die flüssige Vorlage zurück', (tester) async {
      final b = behaelter();
      final d = await dosenmenge(b.container);
      await alsAltfall(b.db, d.eintragId);

      await zeige(tester, b.container, snack());
      await tester.tap(zeile(d.eintragId));
      await tester.pumpAndSettle();

      expect(textUnter(tester, schluessel('portion-gramm')), 'ml');
      expect(
        textUnter(tester, schluessel('portion-zeile')),
        contains('330 ml'),
      );
    });

    testWidgets('Altfall über den echten Weg, gesichert: Die Zeile bleibt in '
        'Millilitern', (tester) async {
      final b = behaelter();
      final g = await zweiGlas(b.container);
      await alsAltfall(b.db, g.eintragId);

      await zeige(tester, b.container, snack());
      await tester.tap(zeile(g.eintragId));
      await tester.pumpAndSettle();
      expect(
        textUnter(tester, schluessel('portion-knopf-0')),
        contains('Glas (250 ml)'),
      );
      await tester.tap(schluessel('portion-plus'));
      await tester.pumpAndSettle();
      await tester.tap(schluessel('buchung-sichern'));
      await tester.pumpAndSettle();

      expect(
        textUnter(tester, zeile(g.eintragId)),
        contains('3 Glas (750 ml) · 16:20'),
      );
    });

    testWidgets('Altfall ohne Vorlage über den echten Weg: Gramm', (
      tester,
    ) async {
      final b = behaelter();
      final id = await buche(
        b.container,
        lebensmittelId: ohneVorlage,
        name: 'Prüf-Saft',
        mengeG: 330,
        fluessig: null,
      );

      await zeige(tester, b.container, snack());
      await tester.tap(zeile(id));
      await tester.pumpAndSettle();

      expect(textUnter(tester, schluessel('portion-gramm')), 'g');
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Zurück und wieder hin (32)', () {
    testWidgets('geändert auf 3 Glas: Die Zeile zeigt „3 Glas (750 ml)" '
        'auch nach dem Zurücknavigieren', (tester) async {
      final b = behaelter();
      final g = await zweiGlas(b.container);
      final z = zeile(g.eintragId);

      grossesFenster(tester);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: b.container,
          child: CupertinoApp(
            home: Builder(
              builder: (context) => CupertinoPageScaffold(
                child: Center(
                  child: CupertinoButton(
                    key: const Key('hin'),
                    onPressed: () => Navigator.of(context).push(
                      CupertinoPageRoute<void>(
                        builder: (_) => const MahlzeitSeite(
                          tagesSchluessel: heute,
                          mahlzeit: Mahlzeit.snack,
                        ),
                      ),
                    ),
                    child: const Text('Snack'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(schluessel('hin'));
      await tester.pumpAndSettle();
      expect(textUnter(tester, z), contains('2 Glas (500 ml)'));

      await tester.tap(z);
      await tester.pumpAndSettle();
      await tester.tap(schluessel('portion-plus'));
      await tester.pumpAndSettle();
      await tester.tap(schluessel('buchung-sichern'));
      await tester.pumpAndSettle();
      expect(textUnter(tester, z), contains('3 Glas (750 ml)'));

      // Zurück …
      Navigator.of(tester.element(find.byType(MahlzeitView))).pop();
      await tester.pumpAndSettle();
      expect(find.byType(MahlzeitView), findsNothing);

      // … und wieder hin.
      await tester.tap(schluessel('hin'));
      await tester.pumpAndSettle();
      expect(textUnter(tester, z), contains('3 Glas (750 ml)'));
    });
  });
}

/// Steuerbare Ableger der echten Notifier — dieselben wie in
/// `test/mahlzeit/mahlzeit_view_test.dart`.
class _Tageswerte extends DailyMetricsNotifier {
  _Tageswerte(this.wert);

  final Messwert<List<DailyMetrics>> wert;

  @override
  Future<Messwert<List<DailyMetrics>>> build() async => wert;
}

class _Stammdaten extends StammdatenNotifier {
  _Stammdaten(this.wert);

  final Stammdaten wert;

  @override
  Future<Stammdaten> build() async => wert;
}

class _Fremde extends FremdeMahlzeitenNotifier {
  _Fremde(this.wert) : super('');

  final Messwert<List<FremdeMahlzeit>> wert;

  @override
  Future<Messwert<List<FremdeMahlzeit>>> build() async => wert;
}
