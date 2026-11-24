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
import 'package:repit/ernaehrung/ernaehrung_provider.dart';
import 'package:repit/ernaehrung/mahlzeit_view.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_types.dart';

import '../design/support.dart' show textOf;
import 'health_schreiben_attrappe.dart';

/// Widget-Tests für die **gebuchte Portion** (#401, unter #325): das
/// Ändern-Blatt und die Mahlzeitenzeile.
///
/// Geschrieben nach Task 9, Step 2 des Plans
/// `docs/superpowers/plans/2026-11-05-portionen.md`, der Spec
/// `docs/superpowers/specs/2026-11-05-portionen-design.md` (Entscheidung 8,
/// V9, V12, „Das Ändern-Blatt", „Texte, die Zusagen sind") und dem Entwurf
/// (`erfassen.js`, Zustand `aendern`; `mahlzeit.js`, „1 Stück (120 g)") —
/// **bevor** die Mahlzeitenzeile die Portion kannte. Für Widget-Tests
/// genügt ein Agent, wenn der Test zuerst entsteht, rot gesehen und vor
/// der Implementierung committet wird (`CLAUDE.md`, „Wer Tests schreibt,
/// schreibt nicht die Implementierung"). Diese Datei darf ausgeführt, aber
/// nicht verändert werden.
///
/// Die **Suchzeile** (V9, zweiter Teil) steht in
/// `portion_suchzeile_test.dart`: Sie hängt an
/// `ErnaehrungRepository.letzteBuchungen`, und das baut ein anderer Agent
/// (Plan, Task 9: Repository-Teil zwei Agenten).
///
/// ## Was hier vorausgesetzt wird
///
/// Nur, was schon steht: `BuchungsBlatt` und `BuchungsFormular.fuer`
/// (`erfassen_view_test.dart`, `portions_formular_test.dart`), die
/// Schlüssel des Wählers (`portionen_blatt_test.dart`: `portion-gramm`,
/// `portion-knopf-<i>`, `portion-anzahl`, `portion-plus`, `portion-neu`,
/// `portion-zeile`, `buchung-menge`, `buchung-sichern`), die Schlüssel des
/// Dialogs (`portion-dialog-name`) und die der Mahlzeit
/// (`mahlzeit_view_test.dart`: `mahlzeit-eintrag-<id>`). Neue Schlüssel
/// führt diese Datei nicht ein.
///
/// ## Was hier geprüft wird
///
/// - **Schnappschuss statt Verweis** (Entscheidung 8, Review-Fokus 4):
///   Ändern-Blatt und Mahlzeitenzeile lesen Name und Gramm aus dem
///   Eintrag. Wird die Portion in der Tabelle umbenannt, geändert oder
///   gelöscht, steht dort weiter, was beim Buchen galt. Sonst bräche der
///   Satz im Dialog „Gebuchte Einträge behalten ihre Gramm".
/// - **V12:** Die Anzahl rechnet mit den Gramm des Schnappschusses; „g"
///   gewählt und gesichert nimmt dem Eintrag die Portion, bis zum Sichern
///   lässt sich zurückwechseln.
/// - **V9:** „2 Bon (11,8 g) · 16:20" statt „11,8 g · 16:20". Ohne Portion
///   wie heute.
/// - **`32`:** Die gebuchte Portion steht nach dem Zurücknavigieren
///   wieder in der Zeile.
///
/// Wo ein Text geprüft wird, ist er der Zustand: „2 Bon" gegen „Bonbon"
/// ist der Unterschied zwischen Schnappschuss und Verweis.
///
/// ## Festlegungen des Test-Agenten — nicht von Tim freigegeben
///
/// - **„Kein Langdruck" heißt: Ein Langdruck auf die Portion öffnet keinen
///   Dialog.** Ob der Knopf die Geste gar nicht hat oder sie verwirft, ist
///   offen.
/// - **Die Zeile ohne Portion wird mit 120 g geprüft**, nicht mit 11,8 g:
///   Plan und Spec schreiben „wie heute „11,8 g · 16:20"", heute steht dort
///   aber die Menge ohne Nachkommastelle. Ob das so bleibt, entscheidet
///   dieser Test nicht.
///
/// Alle Produkte, Namen und Zahlen sind **erfunden**, alle Zeitpunkte
/// liegen im Jahr 2099.
void main() {
  // Dienstag, 07.04.2099, 18:00 Berliner Zeit (MESZ, +2).
  final jetzt = DateTime.utc(2099, 4, 7, 16);
  const heute = '2099-04-07';

  // 16:20 Berliner Zeit.
  final gegessen = DateTime.utc(2099, 4, 7, 14, 20);

  const bonsJe100g = Naehrwerte.je100g(
    kcal: 570,
    eiweissG: 7.6,
    kohlenhydrateG: 50,
    fettG: 38,
  );

  const vollstaendig = Stammdaten(
    groesseCm: 180,
    geburtsjahr: 1990,
    zielgewichtKg: 84,
    zieldatum: '2100-01-14',
  );

  // --- Hilfsmittel ---------------------------------------------------

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

  String feldText(WidgetTester tester, String key) => tester
      .widget<EditableText>(
        find.descendant(
          of: schluessel(key),
          matching: find.byType(EditableText),
        ),
      )
      .controller
      .text;

  /// Ein eigenes Lebensmittel mit „Bon" (5,9 g) und „Packung" (225 g) —
  /// gibt seinen Schlüssel und die gespeicherte Bon-Portion.
  Future<({int id, Portion bon})> bonsAnlegen(ProviderContainer c) async {
    final id = await c
        .read(lebensmittelRepositoryProvider)
        .legeAn(
          const LebensmittelVorlage(name: 'Prüf-Bons', je100g: bonsJe100g),
          portionen: const [
            Portion(name: 'Bon', mengeG: 5.9),
            Portion(name: 'Packung', mengeG: 225),
          ],
        );
    final portionen = await c.read(portionenRepositoryProvider).fuer(id);
    return (id: id, bon: portionen.firstWhere((p) => p.name == 'Bon'));
  }

  /// Der Eintrag [eintragId], wie er gerade in der Datei steht.
  Future<Eintrag> lies(ProviderContainer c, int eintragId) async {
    final alle = await c
        .read(ernaehrungRepositoryProvider)
        .eintraegeAmTag(heute);
    return alle.firstWhere((e) => e.id == eintragId);
  }

  /// Bucht [mengeG] des Lebensmittels [id] um 16:20 als Snack — mit
  /// Schnappschuss, wenn [portion] gesetzt ist.
  Future<Eintrag> buche(
    ProviderContainer c, {
    required int id,
    required double mengeG,
    Portion? portion,
  }) async {
    final repo = c.read(ernaehrungRepositoryProvider);
    final eintragId = await repo.buche(
      Eintrag(
        tagesSchluessel: heute,
        mahlzeit: Mahlzeit.snack,
        zeitpunkt: gegessen,
        lebensmittelId: id,
        name: 'Prüf-Bons',
        mengeG: mengeG,
        naehrwerte: bonsJe100g.fuerMenge(mengeG),
        portionId: portion?.id,
        portionName: portion?.name,
        portionG: portion?.mengeG,
      ),
    );
    return lies(c, eintragId);
  }

  /// 2 × Bon, gebucht — der Ausgangsfall fast aller Tests hier.
  Future<({int id, Portion bon, Eintrag eintrag})> zweiBons(
    ProviderContainer c,
  ) async {
    final b = await bonsAnlegen(c);
    final e = await buche(c, id: b.id, mengeG: 11.8, portion: b.bon);
    return (id: b.id, bon: b.bon, eintrag: e);
  }

  // ═════════════════════════════════════════════════════════════════════
  group('Das Ändern-Blatt', () {
    testWidgets('öffnet mit „Bon" gewählt und Anzahl 2 — nur „g" und die '
        'gebuchte Portion, kein „+ Portion"', (tester) async {
      final b = behaelter();
      final g = await zweiBons(b.container);

      await zeige(
        tester,
        b.container,
        BuchungsBlatt(formular: BuchungsFormular.fuer(g.eintrag)),
      );

      expect(schluessel('portion-gramm'), findsOneWidget);
      expect(schluessel('portion-knopf-0'), findsOneWidget);
      expect(
        schluessel('portion-knopf-1'),
        findsNothing,
        reason: 'die Packung ist nicht die gebuchte Portion',
      );
      expect(textUnter(tester, schluessel('portion-knopf-0')), contains('Bon'));
      expect(schluessel('portion-anzahl'), findsOneWidget);
      expect(feldText(tester, 'portion-anzahl'), '2');
      expect(schluessel('buchung-menge'), findsNothing);
      expect(
        schluessel('portion-neu'),
        findsNothing,
        reason:
            'eine neue Portion gehört an das Lebensmittel, nicht an einen '
            'gebuchten Eintrag',
      );
    });

    testWidgets('auch nachdem die Portion umbenannt und geändert wurde: '
        '„Bon (5,9 g)", Anzahl 2', (tester) async {
      final b = behaelter();
      final g = await zweiBons(b.container);
      await b.container
          .read(portionenRepositoryProvider)
          .aendere(g.bon.mit(name: 'Bonbon', mengeG: 6.1));
      // Frisch aus der Datei — so, wie die Mahlzeit ihn weiterreicht.
      final eintrag = await lies(b.container, g.eintrag.id!);

      await zeige(
        tester,
        b.container,
        BuchungsBlatt(formular: BuchungsFormular.fuer(eintrag)),
      );

      final knopf = textUnter(tester, schluessel('portion-knopf-0'));
      expect(knopf, contains('Bon'));
      expect(knopf, isNot(contains('Bonbon')));
      expect(knopf, contains('5,9'));
      expect(knopf, isNot(contains('6,1')));
      expect(feldText(tester, 'portion-anzahl'), '2');
      expect(textUnter(tester, schluessel('portion-zeile')), contains('11,8'));
    });

    testWidgets('auch nachdem die Portion gelöscht wurde', (tester) async {
      final b = behaelter();
      final g = await zweiBons(b.container);
      await b.container.read(portionenRepositoryProvider).loesche(g.bon.id!);
      final eintrag = await lies(b.container, g.eintrag.id!);

      await zeige(
        tester,
        b.container,
        BuchungsBlatt(formular: BuchungsFormular.fuer(eintrag)),
      );

      expect(textUnter(tester, schluessel('portion-knopf-0')), contains('Bon'));
      expect(feldText(tester, 'portion-anzahl'), '2');
    });

    testWidgets('ein Langdruck auf die Portion öffnet keinen Dialog', (
      tester,
    ) async {
      final b = behaelter();
      final g = await zweiBons(b.container);
      await zeige(
        tester,
        b.container,
        BuchungsBlatt(formular: BuchungsFormular.fuer(g.eintrag)),
      );

      await tester.longPress(schluessel('portion-knopf-0'));
      await tester.pumpAndSettle();

      expect(schluessel('portion-dialog-name'), findsNothing);
      expect(feldText(tester, 'portion-anzahl'), '2');
    });

    testWidgets('+ rechnet mit den Gramm des Schnappschusses, und der '
        'Schnappschuss bleibt (V12)', (tester) async {
      final b = behaelter();
      final g = await zweiBons(b.container);
      await b.container
          .read(portionenRepositoryProvider)
          .aendere(g.bon.mit(name: 'Bonbon', mengeG: 6.1));
      final eintrag = await lies(b.container, g.eintrag.id!);

      await zeige(
        tester,
        b.container,
        BuchungsBlatt(formular: BuchungsFormular.fuer(eintrag)),
      );
      await tester.tap(schluessel('portion-plus'));
      await tester.pumpAndSettle();
      await tester.tap(schluessel('buchung-sichern'));
      await tester.pumpAndSettle();

      final danach = await lies(b.container, g.eintrag.id!);
      expect(danach.mengeG, closeTo(17.7, 1e-9), reason: '3 × 5,9 g');
      expect(danach.portionId, g.bon.id);
      expect(danach.portionName, 'Bon');
      expect(danach.portionG, 5.9);
    });

    testWidgets('„g" gewählt und gesichert: Der Eintrag hat keine Portion '
        'mehr, die Menge bleibt (V12)', (tester) async {
      final b = behaelter();
      final g = await zweiBons(b.container);
      await zeige(
        tester,
        b.container,
        BuchungsBlatt(formular: BuchungsFormular.fuer(g.eintrag)),
      );

      await tester.tap(schluessel('portion-gramm'));
      await tester.pumpAndSettle();
      expect(schluessel('buchung-menge'), findsOneWidget);
      expect(feldText(tester, 'buchung-menge'), '11,8');

      await tester.tap(schluessel('buchung-sichern'));
      await tester.pumpAndSettle();

      final danach = await lies(b.container, g.eintrag.id!);
      expect(danach.mengeG, closeTo(11.8, 1e-9));
      expect(danach.portionId, isNull);
      expect(danach.portionName, isNull);
      expect(danach.portionG, isNull);
    });

    testWidgets('bis zum Sichern lässt sich von „g" zurückwechseln', (
      tester,
    ) async {
      final b = behaelter();
      final g = await zweiBons(b.container);
      await zeige(
        tester,
        b.container,
        BuchungsBlatt(formular: BuchungsFormular.fuer(g.eintrag)),
      );

      await tester.tap(schluessel('portion-gramm'));
      await tester.pumpAndSettle();
      expect(
        schluessel('portion-knopf-0'),
        findsOneWidget,
        reason: 'die gebuchte Portion bleibt in der Reihe',
      );

      await tester.tap(schluessel('portion-knopf-0'));
      await tester.pumpAndSettle();
      expect(schluessel('portion-anzahl'), findsOneWidget);

      await tester.tap(schluessel('buchung-sichern'));
      await tester.pumpAndSettle();

      final danach = await lies(b.container, g.eintrag.id!);
      expect(danach.portionName, 'Bon');
      expect(danach.portionG, 5.9);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Die Mahlzeitenzeile', () {
    Widget snack() =>
        const MahlzeitView(tagesSchluessel: heute, mahlzeit: Mahlzeit.snack);

    Finder zeile(Eintrag e) => schluessel('mahlzeit-eintrag-${e.id}');

    testWidgets('mit Portion: „2 Bon (11,8 g) · 16:20"', (tester) async {
      final b = behaelter();
      final g = await zweiBons(b.container);

      await zeige(tester, b.container, snack());

      expect(
        textUnter(tester, zeile(g.eintrag)),
        contains('2 Bon (11,8 g) · 16:20'),
      );
    });

    testWidgets('ohne Portion wie heute: Menge und Uhrzeit, keine Portion', (
      tester,
    ) async {
      final b = behaelter();
      final bons = await bonsAnlegen(b.container);
      final e = await buche(b.container, id: bons.id, mengeG: 120);

      await zeige(tester, b.container, snack());

      final text = textUnter(tester, zeile(e));
      expect(text, contains('120 g · 16:20'));
      expect(text, isNot(contains('Bon (')));
    });

    testWidgets('die Portion in der Tabelle umbenannt: Die Zeile zeigt, was '
        'beim Buchen galt', (tester) async {
      final b = behaelter();
      final g = await zweiBons(b.container);
      await b.container
          .read(portionenRepositoryProvider)
          .aendere(g.bon.mit(name: 'Bonbon', mengeG: 6.1));

      await zeige(tester, b.container, snack());

      final text = textUnter(tester, zeile(g.eintrag));
      expect(text, contains('2 Bon (11,8 g)'));
      expect(text, isNot(contains('Bonbon')));
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Zurück und wieder hin (32)', () {
    testWidgets('geändert auf 3 Bon: Die Zeile zeigt es nach dem Sichern und '
        'nach dem Zurücknavigieren wieder', (tester) async {
      final b = behaelter();
      final g = await zweiBons(b.container);
      final zeile = schluessel('mahlzeit-eintrag-${g.eintrag.id}');

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
      expect(textUnter(tester, zeile), contains('2 Bon (11,8 g)'));

      // Die Zeile öffnet das Ändern-Blatt — über den echten Weg.
      await tester.tap(zeile);
      await tester.pumpAndSettle();
      expect(feldText(tester, 'portion-anzahl'), '2');
      await tester.tap(schluessel('portion-plus'));
      await tester.pumpAndSettle();
      await tester.tap(schluessel('buchung-sichern'));
      await tester.pumpAndSettle();

      expect(schluessel('buchung-sichern'), findsNothing, reason: 'zu');
      expect(textUnter(tester, zeile), contains('3 Bon (17,7 g)'));

      // Zurück …
      Navigator.of(tester.element(find.byType(MahlzeitView))).pop();
      await tester.pumpAndSettle();
      expect(find.byType(MahlzeitView), findsNothing);

      // … und wieder hin.
      await tester.tap(schluessel('hin'));
      await tester.pumpAndSettle();
      expect(textUnter(tester, zeile), contains('3 Bon (17,7 g)'));
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
