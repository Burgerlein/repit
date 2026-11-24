// Der Schirm **„Aufteilung"** und die Zeile „Aufteilung auf Mahlzeiten" in
// „Vorläufige Werte" (#433 unter #374) — Zustände und Übergänge.
//
// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
// Für Widget-Tests genügt ein Agent, wenn der Test zuerst entsteht, rot
// gesehen und **vor der Implementierung committet** wird. Ab da bewacht ihn
// `.githooks/pre-commit`: Diese Datei darf ausgeführt, aber nicht verändert
// werden. Wer einen Fall für falsch hält, meldet ihn.
//
// ## Woher die Anforderungen kommen
//
// Spec `docs/superpowers/specs/2026-11-10-mahlzeiten-aufteilung-design.md`,
// Abschnitt „Der Schirm „Aufteilung"", Leerzustände und die Vorgaben V2,
// V3, V13, V14 — von Tim am 10.11.2026 übernommen. Plan Task 4. Entwurf
// `docs/screens/screens/aufteilung.js` (Zustände `startwert`, `geaendert`,
// `ohne-ziel`) und `vorlaeufige-werte.js` (Zustand `vorschlag-aufteilung`).
//
// - **Entscheidung 1:** Der Startwert 25 · 35 · 30 · 10 steht im Formular,
//   **nie in der Tabelle**, bevor Tim sichert.
// - **Entscheidung 2, V3:** Snack ist der Rest. „+" ist gesperrt, solange
//   der Rest unter 5 liegt, „−" bei 0 %.
// - **Entscheidung 5, V2:** Gesichert wird ab heute (Berliner Tag).
// - **V13:** Das Formular beginnt mit der heute geltenden Aufteilung, ohne
//   eine mit dem Startwert. „Sichern" ist aktiv, solange heute keine gilt
//   oder das Formular von ihr abweicht. „Zurücksetzen" steht da, sobald das
//   Formular vom Startwert abweicht, und ändert nur das Formular.
// - **V14:** „Vorläufige Werte" bekommt den Router; die Zeile zeigt die
//   heute geltende Aufteilung als „25 · 35 · 30 · 10 %", sonst „–/–".
// - **Leerzustände:** Ohne Tagesziel stehen die kcal als „–/–", Sichern
//   geht trotzdem. Lädt die Aufteilung, stehen die Prozente als graue Form
//   und „Sichern" ist aus.
// - **`32`:** Ein Wert, der dastand, steht nach dem Zurücknavigieren
//   wieder da.
//
// ## API (Plan Task 4, „Interfaces")
//
// ```dart
// // lib/ernaehrung/aufteilung_view.dart
// void oeffneAufteilung(AppRouter router);   // AppTarget.aktuell
// class AufteilungSeite extends StatelessWidget { const AufteilungSeite(); }
// class AufteilungView extends ConsumerStatefulWidget { … }
//
// // lib/shell/vorlaeufige_werte_view.dart
// class VorlaeufigeWerteSeite { const VorlaeufigeWerteSeite({AppRouter? router}); }
// ```
//
// ## Schlüssel (Spec, „Der Schirm „Aufteilung"")
//
// `aufteilung-plus-<m>`, `aufteilung-minus-<m>`, `aufteilung-prozent-<m>`,
// `aufteilung-kcal-<m>`, `aufteilung-sichern`, `aufteilung-zuruecksetzen`,
// `vorlaeufige-werte-aufteilung`; `<m>` ist `Mahlzeit.name`.
//
// ## Festlegungen des Test-Agenten — nicht von Tim freigegeben
//
// - **Die Knopf-Schlüssel sitzen auf einem `CupertinoButton` oder auf einer
//   Hülle mit genau einem darin.** „Gesperrt" heißt `onPressed == null` —
//   so prüft es auch `vorlaeufige_werte_kalorienziel_test.dart`.
// - **Die Snackzeile hat keine Knöpfe**, also auch keine Schlüssel
//   `aufteilung-plus-snack` und `aufteilung-minus-snack`. Der Entwurf
//   zeichnet dort „Rest" statt − und +.
// - **Das Tagesziel kommt aus `ernaehrungsTagProvider(heute).zielKcal`**
//   (V5, Spec: „Der Schirm besorgt seine Daten selbst"). Die Fälle legen
//   es als feste Festlegung von Hand ab; ohne Festlegung und ohne
//   Health-Werte gibt es keins.
// - **Ob eine Zahl als „1.800" oder „1800" dasteht, ist Beschriftung.**
//   Geprüft werden die Ziffern.
//
// ## Was hier nicht geprüft wird
//
// Layout, Farben, Wortlaut von Hinweis und Fuß, Vorlesetexte (`CLAUDE.md`:
// Widget-Tests nur für Zustände und Übergänge).
//
// **Alle Zahlen und Daten sind erfunden**, Zeitpunkte im Jahr 2099.
import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/core/messwert.dart';
import 'package:repit/data/cache.dart';
import 'package:repit/data/kalorienziele.dart';
import 'package:repit/data/mahlzeit_aufteilungen.dart';
import 'package:repit/data/stammdaten.dart';
import 'package:repit/design/platzhalter.dart';
import 'package:repit/ernaehrung/aufteilung_view.dart';
import 'package:repit/ernaehrung/ernaehrung_provider.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_types.dart';
import 'package:repit/shell/router.dart';
import 'package:repit/shell/vorlaeufige_werte_view.dart';

import '../design/support.dart' show textOf;
import '../health/health_reading_attrappe.dart';

void main() {
  // 10.03.2099, 23:30 UTC — in Berlin (MEZ, +1) schon Mittwoch, der 11.,
  // 00:30. Wer den UTC-Tag nimmt statt des Berliner (V2), sichert auf den
  // 10. und fällt auf.
  const heute = '2099-03-11';
  const gestern = '2099-03-10';
  final jetzt = DateTime.utc(2099, 3, 10, 23, 30);

  const ziel1800 = KalorienzielFestlegung(
    abTag: '2099-01-01',
    kcal: 1800,
    herkunft: KalorienzielHerkunft.hand,
  );

  Finder plus(Mahlzeit m) => find.byKey(Key('aufteilung-plus-${m.name}'));
  Finder minus(Mahlzeit m) => find.byKey(Key('aufteilung-minus-${m.name}'));
  Finder prozent(Mahlzeit m) => find.byKey(Key('aufteilung-prozent-${m.name}'));
  Finder kcal(Mahlzeit m) => find.byKey(Key('aufteilung-kcal-${m.name}'));
  final sichern = find.byKey(const Key('aufteilung-sichern'));
  final zuruecksetzen = find.byKey(const Key('aufteilung-zuruecksetzen'));
  final vwZeile = find.byKey(const Key('vorlaeufige-werte-aufteilung'));

  const eingestellt = [Mahlzeit.fruehstueck, Mahlzeit.mittag, Mahlzeit.abend];

  late AppCache db;

  setUpAll(() async {
    await initializeDateFormatting('de_DE');
  });

  setUp(() {
    db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);
  });

  ProviderContainer behaelter({bool aufteilungenAntwortenNie = false}) {
    final container = ProviderContainer(
      // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
      retry: (_, _) => null,
      overrides: [
        appCacheProvider.overrideWithValue(db),
        healthProvider.overrideWithValue(const HealthReadingAttrappe()),
        clockProvider.overrideWithValue(() => jetzt),
        stammdatenProvider.overrideWith(() => _Stammdaten(const Stammdaten())),
        dailyMetricsProvider.overrideWith(
          () => _Tageswerte(LeerNachLauf<List<DailyMetrics>>(gelaufen: jetzt)),
        ),
        fremdeMahlzeitenProvider.overrideWith2(
          (tag) => _Fremde(LeerNachLauf<List<FremdeMahlzeit>>(gelaufen: jetzt)),
        ),
        if (aufteilungenAntwortenNie)
          mahlzeitAufteilungenProvider.overrideWith(_NieAufteilungen.new),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> grosseFlaeche(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<ProviderContainer> zeigeAufteilung(
    WidgetTester tester, {
    ProviderContainer? mit,
    bool settle = true,
  }) async {
    await grosseFlaeche(tester);
    final container = mit ?? behaelter();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const CupertinoApp(home: AufteilungSeite()),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
    return container;
  }

  Future<void> legeZielAb() => KalorienzielRepository(db).setze(ziel1800);

  Future<void> legeAufteilungAb(String abTag, MahlzeitAufteilung a) =>
      MahlzeitAufteilungRepository(db)
          .setze(AufteilungAb(abTag: abTag, aufteilung: a));

  Future<List<AufteilungAb>> tabelle() =>
      MahlzeitAufteilungRepository(db).alle();

  String textUnter(WidgetTester tester, Finder wurzel) {
    expect(
      wurzel,
      findsOneWidget,
      reason: 'Der Schlüssel fehlt — siehe „Schlüssel" im Dateikopf.',
    );
    return tester
        .widgetList<Text>(
          find.descendant(
            of: wurzel,
            matching: find.byType(Text),
            matchRoot: true,
          ),
        )
        .map(textOf)
        .join(' ');
  }

  String ziffern(String text) => text.replaceAll(RegExp(r'\D'), '');

  int prozentVon(WidgetTester tester, Mahlzeit m) {
    final z = ziffern(textUnter(tester, prozent(m)));
    expect(z, isNotEmpty, reason: '${m.name}: keine Prozentzahl');
    return int.parse(z);
  }

  List<int> formular(WidgetTester tester) => [
    for (final m in [...eingestellt, Mahlzeit.snack]) prozentVon(tester, m),
  ];

  bool aktiv(WidgetTester tester, Finder knopf) {
    expect(
      knopf,
      findsOneWidget,
      reason: 'Der Schlüssel fehlt — siehe „Schlüssel" im Dateikopf.',
    );
    final b = tester.widget<CupertinoButton>(
      find
          .descendant(
            of: knopf,
            matching: find.byType(CupertinoButton),
            matchRoot: true,
          )
          .first,
    );
    return b.onPressed != null;
  }

  Future<void> tippe(WidgetTester tester, Finder ziel, {int mal = 1}) async {
    for (var i = 0; i < mal; i++) {
      await tester.tap(ziel);
      await tester.pumpAndSettle();
    }
  }

  // ═════════════════════════════════════════════════════════════════════

  group('Erstes Öffnen (Entscheidung 1)', () {
    testWidgets('der Startwert steht im Formular, die Tabelle bleibt leer', (
      tester,
    ) async {
      await legeZielAb();
      await zeigeAufteilung(tester);

      expect(formular(tester), [25, 35, 30, 10]);
      expect(
        await tabelle(),
        isEmpty,
        reason:
            'Der Startwert gilt erst nach „Sichern" — Öffnen legt nichts '
            'an.',
      );
      expect(
        aktiv(tester, sichern),
        isTrue,
        reason: 'Heute gilt keine Aufteilung, also ist „Sichern" aktiv (V13).',
      );
    });

    testWidgets('„Sichern" legt genau eine Zeile ab heute an', (tester) async {
      await legeZielAb();
      await zeigeAufteilung(tester);

      await tippe(tester, sichern);

      final t = await tabelle();
      expect(t, hasLength(1));
      expect(t.single.abTag, heute, reason: 'ab heute, Berliner Tag (V2)');
      expect(t.single.aufteilung, MahlzeitAufteilung.startwert);
    });

    testWidgets('das Formular beginnt mit der heute geltenden Aufteilung, '
        'auch wenn sie von einem früheren Tag stammt', (tester) async {
      await legeZielAb();
      await legeAufteilungAb(
        gestern,
        MahlzeitAufteilung(fruehstueck: 20, mittag: 40, abend: 30),
      );
      await zeigeAufteilung(tester);

      expect(formular(tester), [20, 40, 30, 10]);
      expect(
        aktiv(tester, sichern),
        isFalse,
        reason: 'Das Formular weicht von der geltenden nicht ab (V13).',
      );
    });
  });

  group('Rest und Sperren (Entscheidung 2, V3)', () {
    testWidgets('zweimal „+" beim Frühstück: 35 %, Snack 0 %, jedes „+" '
        'gesperrt', (tester) async {
      await legeZielAb();
      await zeigeAufteilung(tester);

      await tippe(tester, plus(Mahlzeit.fruehstueck), mal: 2);

      expect(formular(tester), [35, 35, 30, 0]);
      for (final m in eingestellt) {
        expect(
          aktiv(tester, plus(m)),
          isFalse,
          reason: '${m.name}: kein Rest mehr, also kein „+"',
        );
        expect(
          aktiv(tester, minus(m)),
          isTrue,
          reason: '${m.name}: über 0 %, „−" geht',
        );
      }
    });

    testWidgets('„−" bei 0 % ist gesperrt', (tester) async {
      await legeZielAb();
      await zeigeAufteilung(tester);

      await tippe(tester, minus(Mahlzeit.fruehstueck), mal: 5);

      expect(formular(tester), [0, 35, 30, 35]);
      expect(aktiv(tester, minus(Mahlzeit.fruehstueck)), isFalse);
      expect(aktiv(tester, plus(Mahlzeit.fruehstueck)), isTrue);
    });

    testWidgets('der Snack ist der Rest und hat keine Knöpfe', (tester) async {
      await legeZielAb();
      await zeigeAufteilung(tester);

      expect(prozent(Mahlzeit.snack), findsOneWidget);
      expect(plus(Mahlzeit.snack), findsNothing);
      expect(minus(Mahlzeit.snack), findsNothing);
    });
  });

  group('kcal je Mahlzeit', () {
    testWidgets('bei Tagesziel 1.800: 450 · 630 · 540 · 180', (tester) async {
      await legeZielAb();
      await zeigeAufteilung(tester);

      expect(ziffern(textUnter(tester, kcal(Mahlzeit.fruehstueck))), '450');
      expect(ziffern(textUnter(tester, kcal(Mahlzeit.mittag))), '630');
      expect(ziffern(textUnter(tester, kcal(Mahlzeit.abend))), '540');
      expect(ziffern(textUnter(tester, kcal(Mahlzeit.snack))), '180');
    });

    testWidgets('die kcal ziehen mit dem Formular mit', (tester) async {
      await legeZielAb();
      await zeigeAufteilung(tester);

      await tippe(tester, plus(Mahlzeit.fruehstueck));

      expect(ziffern(textUnter(tester, kcal(Mahlzeit.fruehstueck))), '540');
      expect(ziffern(textUnter(tester, kcal(Mahlzeit.snack))), '90');
    });

    testWidgets('ohne Tagesziel „–/–" — und Sichern geht trotzdem', (
      tester,
    ) async {
      await zeigeAufteilung(tester);

      for (final m in Mahlzeit.values) {
        final t = textUnter(tester, kcal(m));
        expect(t, contains(ohneWert), reason: '${m.name}: ohne Ziel „–/–"');
        expect(ziffern(t), isEmpty, reason: '${m.name}: keine Zahl, keine 0');
      }
      expect(formular(tester), [25, 35, 30, 10]);
      expect(aktiv(tester, sichern), isTrue);

      await tippe(tester, sichern);

      expect(await tabelle(), hasLength(1));
    });
  });

  group('Sichern und Zurücksetzen (V13)', () {
    testWidgets('nach dem Sichern gesperrt, bis sich etwas ändert', (
      tester,
    ) async {
      await legeZielAb();
      await zeigeAufteilung(tester);

      await tippe(tester, sichern);
      expect(aktiv(tester, sichern), isFalse, reason: 'nichts zu sichern');
      expect(formular(tester), [25, 35, 30, 10], reason: 'der Schirm bleibt');

      await tippe(tester, plus(Mahlzeit.mittag));
      expect(aktiv(tester, sichern), isTrue, reason: 'Formular weicht ab');

      await tippe(tester, minus(Mahlzeit.mittag));
      expect(
        aktiv(tester, sichern),
        isFalse,
        reason: 'wieder gleich der geltenden — nichts zu sichern',
      );
    });

    testWidgets('ein zweites Sichern am selben Tag ersetzt die Zeile (V2)', (
      tester,
    ) async {
      await legeZielAb();
      await zeigeAufteilung(tester);

      await tippe(tester, sichern);
      await tippe(tester, plus(Mahlzeit.abend));
      await tippe(tester, sichern);

      final t = await tabelle();
      expect(t, hasLength(1));
      expect(
        t.single.aufteilung,
        MahlzeitAufteilung(fruehstueck: 25, mittag: 35, abend: 35),
      );
    });

    testWidgets('„Zurücksetzen" erscheint erst nach einer Abweichung vom '
        'Startwert und setzt nur das Formular', (tester) async {
      await legeZielAb();
      await zeigeAufteilung(tester);

      expect(zuruecksetzen, findsNothing, reason: 'Formular = Startwert');

      await tippe(tester, plus(Mahlzeit.fruehstueck));
      expect(zuruecksetzen, findsOneWidget);

      await tippe(tester, zuruecksetzen);

      expect(formular(tester), [25, 35, 30, 10]);
      expect(zuruecksetzen, findsNothing);
      expect(
        await tabelle(),
        isEmpty,
        reason: 'Zurücksetzen ändert nur das Formular, es sichert nicht',
      );
    });

    testWidgets('mit einer gesicherten Aufteilung neben dem Startwert: '
        'Zurücksetzen holt den Startwert ins Formular, die Tabelle bleibt', (
      tester,
    ) async {
      final alt = MahlzeitAufteilung(fruehstueck: 20, mittag: 40, abend: 30);
      await legeZielAb();
      await legeAufteilungAb(heute, alt);
      await zeigeAufteilung(tester);

      expect(zuruecksetzen, findsOneWidget);
      await tippe(tester, zuruecksetzen);

      expect(formular(tester), [25, 35, 30, 10]);
      expect(aktiv(tester, sichern), isTrue, reason: 'weicht nun ab');
      expect((await tabelle()).single.aufteilung, alt);
    });
  });

  group('Laden (Leerzustände, `01`)', () {
    testWidgets('solange die Aufteilungen nicht gelesen sind: keine '
        'Prozentzahl, „Sichern" aus', (tester) async {
      await legeZielAb();
      await zeigeAufteilung(
        tester,
        mit: behaelter(aufteilungenAntwortenNie: true),
      );

      for (final m in Mahlzeit.values) {
        expect(
          ziffern(textUnter(tester, prozent(m))),
          isEmpty,
          reason:
              '${m.name}: Während des Ladens steht kein Startwert da — er '
              'sähe aus wie die gesicherte Aufteilung.',
        );
      }
      expect(aktiv(tester, sichern), isFalse);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  // „Vorläufige Werte" (V14)
  // ═════════════════════════════════════════════════════════════════════

  group('Zeile in „Vorläufige Werte" (V14)', () {
    Future<ProviderContainer> zeigeVw(
      WidgetTester tester, {
      AppRouter? router,
      ProviderContainer? mit,
    }) async {
      await grosseFlaeche(tester);
      final container = mit ?? behaelter();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: CupertinoApp(home: VorlaeufigeWerteSeite(router: router)),
        ),
      );
      await tester.pumpAndSettle();
      return container;
    }

    testWidgets('vor dem ersten Sichern „–/–", nicht der Startwert', (
      tester,
    ) async {
      await zeigeVw(tester);

      final t = textUnter(tester, vwZeile);
      expect(t, contains(ohneWert));
      expect(t, isNot(contains('25')), reason: 'der Startwert gilt nicht');
    });

    testWidgets('nach dem Sichern „25 · 35 · 30 · 10 %"', (tester) async {
      await legeAufteilungAb(heute, MahlzeitAufteilung.startwert);
      await zeigeVw(tester);

      final t = textUnter(tester, vwZeile);
      expect(t, contains('25 · 35 · 30 · 10 %'));
      expect(t, isNot(contains(ohneWert)));
    });

    testWidgets('während des Ladens weder „–/–" noch Zahlen', (tester) async {
      await zeigeVw(tester, mit: behaelter(aufteilungenAntwortenNie: true));

      final t = textUnter(tester, vwZeile);
      expect(
        t,
        isNot(contains(ohneWert)),
        reason: '`01`: laden ist nicht leer',
      );
      expect(t, isNot(contains(RegExp(r'\d+ · \d+'))));
    });

    testWidgets('ein Tipp schiebt den Schirm auf den aktuellen Stapel', (
      tester,
    ) async {
      final router = AppRouter();
      final tabVorher = router.tab;
      await zeigeVw(tester, router: router);

      await tester.tap(vwZeile);
      await tester.pumpAndSettle();

      final befehl = router.nimmBefehl();
      expect(befehl, isNotNull, reason: 'Sprung über den AppRouter (V14)');
      expect(befehl!.ersetztStapel, isFalse, reason: 'AppTarget.aktuell');
      expect(router.tab, tabVorher, reason: 'kein Tabwechsel');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: behaelter(),
          child: CupertinoApp(home: Builder(builder: befehl.builder)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AufteilungView), findsOneWidget);
    });

    testWidgets('`oeffneAufteilung` tut dasselbe von außen', (tester) async {
      final router = AppRouter();
      final tabVorher = router.tab;

      oeffneAufteilung(router);

      final befehl = router.nimmBefehl();
      expect(befehl, isNotNull);
      expect(befehl!.ersetztStapel, isFalse);
      expect(router.tab, tabVorher);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  // Zurück und wieder hin (`32`)
  // ═════════════════════════════════════════════════════════════════════

  group('Zurück und wieder hin (`32`)', () {
    testWidgets('die gesicherte Aufteilung steht wieder da — im Schirm und '
        'in der Zeile', (tester) async {
      await grosseFlaeche(tester);
      await legeZielAb();
      final router = AppRouter();
      final container = behaelter();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: CupertinoApp(home: VorlaeufigeWerteSeite(router: router)),
        ),
      );
      await tester.pumpAndSettle();

      Future<void> hin() async {
        await tester.tap(vwZeile);
        await tester.pumpAndSettle();
        final befehl = router.nimmBefehl()!;
        tester
            .state<NavigatorState>(find.byType(Navigator))
            .push(CupertinoPageRoute<void>(builder: befehl.builder));
        await tester.pumpAndSettle();
        expect(find.byType(AufteilungView), findsOneWidget);
      }

      Future<void> zurueck() async {
        tester.state<NavigatorState>(find.byType(Navigator)).pop();
        await tester.pumpAndSettle();
        expect(find.byType(AufteilungView), findsNothing);
      }

      await hin();
      await tippe(tester, plus(Mahlzeit.fruehstueck));
      await tippe(tester, sichern);
      await zurueck();

      expect(textUnter(tester, vwZeile), contains('30 · 35 · 30 · 5 %'));

      await hin();
      expect(formular(tester), [30, 35, 30, 5]);
      expect(aktiv(tester, sichern), isFalse);
    });

    testWidgets('ein frisch gebauter Schirm über demselben Behälter zeigt '
        'die gesicherte Aufteilung', (tester) async {
      await legeZielAb();
      final container = await zeigeAufteilung(tester);

      await tippe(tester, minus(Mahlzeit.abend));
      await tippe(tester, sichern);

      await tester.pumpWidget(const SizedBox());
      await zeigeAufteilung(tester, mit: container);

      expect(formular(tester), [25, 35, 25, 15]);
    });
  });
}

/// Steuerbare Ableger der echten Notifier — Riverpods Provider-Typen sind
/// invariant (siehe `ernaehrung_provider_test.dart`).
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

/// Eine Attrappe, die nie antwortet: Die Aufteilungen bleiben „noch nicht
/// gelesen".
class _NieAufteilungen extends MahlzeitAufteilungenNotifier {
  @override
  Future<List<AufteilungAb>> build() => _nie<List<AufteilungAb>>();
}

Future<T> _nie<T>() => Completer<T>().future;
