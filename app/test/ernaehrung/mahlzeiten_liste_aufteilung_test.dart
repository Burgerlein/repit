// Die Zeile **„Aufteilung 25 · 35 · 30 · 10 ›"** unter der Mahlzeitenliste
// (#434 unter #374).
//
// ## Woher die Anforderung kommt
//
// **Tims Entscheidung vom 10.11.2026** (Kommentar an #434): Ist die
// Aufteilung gesichert, steht unter der Mahlzeitenliste **an derselben
// Stelle** wie „Ziel je Mahlzeit festlegen" die Zeile „Aufteilung
// 25 · 35 · 30 · 10 ›". Gezeigt werden die geltenden Prozente in der
// Reihenfolge Frühstück · Mittag · Abend · Snack; die Zeile führt zum
// Schirm „Aufteilung" (`oeffneAufteilung`). So hat der Platz in **jedem**
// Zustand dieselbe Form: laden, ohne Aufteilung und mit Aufteilung.
//
// Bis dahin fiel die Stelle mit Aufteilung ganz weg
// (`mahlzeiten_liste_form_test.dart`, Dateikopf: „Das bleibt ein Sprung,
// nach oben statt nach unten"). Diese Datei schließt das.
//
// ## Festlegungen des Test-Agenten — nicht von Tim freigegeben
//
// - **Schlüssel `ernaehrung-aufteilung-zeile`** auf der Zeile. Der
//   Schlüssel `ernaehrung-aufteilung-festlegen` bleibt der Zeile ohne
//   Aufteilung vorbehalten; `mahlzeiten_liste_test.dart` prüft, dass sie
//   mit Aufteilung fehlt.
// - **Die Prozente stehen als „25 · 35 · 30 · 10"**, ohne „%", wie in
//   Tims Satz. Geprüft wird die Zeichenfolge, nicht ihre Aufteilung auf
//   einzelne `Text`-Widgets — `textUnter` setzt die Texte mit Leerzeichen
//   zusammen, gesucht wird deshalb nach den Ziffern in Reihenfolge.
// - **Die Zeile steht, sobald die Aufteilung bekannt ist**, auch während
//   die Einträge noch laden und auch ohne Kalorienziel. Die Aufteilung
//   ist Tims eigene Einstellung (zweite Tabellengruppe, kein
//   `Messwert<T>`); „gesichert" ist sie unabhängig vom Ziel.
//
// ## Wie geprüft wird
//
// An der Liste allein (`MahlzeitenListe`), mit einem Kasten direkt
// darunter an der Stelle von Wasser, wie in
// `mahlzeiten_liste_form_test.dart`. Gemessen wird die Oberkante des
// Kastens. Öffnen und Sichern laufen über die ganze App (`RootView`) auf
// einer Datenbank im Speicher, wie in `mahlzeiten_liste_test.dart`.
//
// Der Fall war beim Anlegen **rot**: Die Liste zeigt mit Aufteilung nichts
// unter der Karte.
//
// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
// Für Widget-Tests genügt ein Agent, wenn der Test zuerst entsteht, rot
// gesehen und vor der Implementierung committet wird. Ab da bewacht ihn
// `.githooks/pre-commit`: Diese Datei darf ausgeführt, aber nicht verändert
// werden. Wer einen Fall für falsch hält, meldet ihn.
//
// **Alle Zahlen und Daten sind erfunden**, Zeitpunkte im Jahr 2099.
import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trainings_core/trainings_core.dart' hide MahlzeitRing;

import 'package:repit/core/messwert.dart';
import 'package:repit/data/cache.dart';
import 'package:repit/data/ernaehrung_repository.dart';
import 'package:repit/data/kalorienziele.dart';
import 'package:repit/data/mahlzeit_aufteilungen.dart';
import 'package:repit/data/stammdaten.dart';
import 'package:repit/design/symbole.dart';
import 'package:repit/ernaehrung/aufteilung_view.dart';
import 'package:repit/ernaehrung/ernaehrung_provider.dart';
import 'package:repit/ernaehrung/mahlzeiten_liste.dart';
import 'package:repit/ernaehrung/off_client.dart';
import 'package:repit/ernaehrung/strichcode_leser.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_types.dart';
import 'package:repit/shell/root_view.dart';
import 'package:repit/shell/router.dart';

import '../design/support.dart' show textOf;
import '../health/health_reading_attrappe.dart';
import 'kamera_attrappe.dart';
import '../tag/behaelter_im_baum.dart';

void main() {
  // Dienstag, 14.07.2099, 12:00 Berliner Zeit (MESZ, +2).
  final jetzt = DateTime.utc(2099, 7, 14, 10);
  const heute = '2099-07-14';

  const ziel1800 = KalorienzielFestlegung(
    abTag: '2099-01-01',
    kcal: 1800,
    herkunft: KalorienzielHerkunft.hand,
  );
  final startwert = MahlzeitAufteilung(fruehstueck: 25, mittag: 35, abend: 30);
  final andere = MahlzeitAufteilung(fruehstueck: 20, mittag: 40, abend: 30);

  Eintrag eintrag(Mahlzeit m, double kcal) => Eintrag(
    tagesSchluessel: heute,
    mahlzeit: m,
    zeitpunkt: jetzt,
    name: 'Prüfgericht',
    naehrwerte: Naehrwerte(kcal: kcal, eiweissG: 10),
  );

  final tagesEintraege = [
    eintrag(Mahlzeit.fruehstueck, 426),
    eintrag(Mahlzeit.mittag, 672),
  ];

  /// Der Tag aus der echten Rechnung (`ernaehrungsTagAus`).
  ErnaehrungsTag tagMit({
    MahlzeitAufteilung? aufteilung,
    List<Eintrag> eigene = const [],
    bool mitZiel = true,
    bool eintraegeLaden = false,
    bool aufteilungenLaden = false,
  }) => ernaehrungsTagAus(
    tagesSchluessel: heute,
    heute: heute,
    eigene: eigene,
    fremde: LeerNachLauf<List<FremdeMahlzeit>>(gelaufen: jetzt),
    tageswerte: LeerNachLauf<List<DailyMetrics>>(gelaufen: jetzt),
    stammdaten: const Stammdaten(),
    jetzt: jetzt,
    kalorienziele: mitZiel ? const [ziel1800] : const [],
    aufteilungen: aufteilung == null
        ? const []
        : [AufteilungAb(abTag: '2099-01-01', aufteilung: aufteilung)],
    aufteilungenLaden: aufteilungenLaden,
    eintraegeLaden: eintraegeLaden,
  );

  final aufteilungZeile = find.byKey(const Key('ernaehrung-aufteilung-zeile'));
  final festlegen = find.byKey(const Key('ernaehrung-aufteilung-festlegen'));
  const danachKey = Key('test-danach');
  final danach = find.byKey(danachKey);

  Future<void> grosseFlaeche(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 4800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  /// Die Liste, darunter ein Kasten an der Stelle von Wasser.
  Future<List<int>> zeigeListe(WidgetTester tester, ErnaehrungsTag tag) async {
    await grosseFlaeche(tester);
    final auf = <int>[];
    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MahlzeitenListe(
                  tag: tag,
                  onMahlzeit: (_) {},
                  onPlus: (_) {},
                  onAufteilung: () => auf.add(1),
                ),
                const SizedBox(key: danachKey, height: 40),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return auf;
  }

  String textUnter(WidgetTester tester, Finder wurzel) {
    expect(
      wurzel,
      findsOneWidget,
      reason: 'Der Schlüssel fehlt — siehe „Festlegungen" im Dateikopf.',
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

  /// Die Prozente in der Zeile, in der Reihenfolge, in der sie stehen.
  List<int> prozenteIn(String text) => RegExp(r'\d+')
      .allMatches(text)
      .map((m) => int.parse(m.group(0)!))
      .toList();

  String alleTexte(WidgetTester tester) =>
      tester.widgetList<Text>(find.byType(Text)).map(textOf).join(' ');

  // ═════════════════════════════════════════════════════════════════════

  group('Mit gesicherter Aufteilung (Tim, 10.11.2026)', () {
    testWidgets('unter der Liste steht „Aufteilung" mit den geltenden '
        'Prozenten, Frühstück · Mittag · Abend · Snack', (tester) async {
      await zeigeListe(
        tester,
        tagMit(aufteilung: startwert, eigene: tagesEintraege),
      );

      final text = textUnter(tester, aufteilungZeile);
      expect(text, contains('Aufteilung'));
      expect(text, contains('25 · 35 · 30 · 10'));
      expect(prozenteIn(text), [25, 35, 30, 10]);
      expect(
        festlegen,
        findsNothing,
        reason: 'Mit Aufteilung gibt es nichts mehr festzulegen.',
      );
    });

    testWidgets('die Prozente sind die geltenden, nicht der Startwert', (
      tester,
    ) async {
      await zeigeListe(
        tester,
        tagMit(aufteilung: andere, eigene: tagesEintraege),
      );

      final text = textUnter(tester, aufteilungZeile);
      expect(text, contains('20 · 40 · 30 · 10'));
      expect(prozenteIn(text), [20, 40, 30, 10]);
    });

    testWidgets('auch ohne Kalorienziel steht die Zeile — gesichert ist '
        'gesichert', (tester) async {
      final tag = tagMit(
        aufteilung: startwert,
        eigene: tagesEintraege,
        mitZiel: false,
      );
      expect(tag.zielKcal, isNull, reason: 'Vorbedingung');
      expect(tag.mahlzeitenLaedt, isFalse, reason: 'Vorbedingung');
      await zeigeListe(tester, tag);

      expect(prozenteIn(textUnter(tester, aufteilungZeile)), [25, 35, 30, 10]);
    });

    testWidgets('ein Tipp ruft onAufteilung', (tester) async {
      final auf = await zeigeListe(
        tester,
        tagMit(aufteilung: startwert, eigene: tagesEintraege),
      );

      await tester.tap(aufteilungZeile);
      await tester.pumpAndSettle();
      expect(auf, [1]);
    });

    testWidgets('ohne Aufteilung steht die Zeile nicht', (tester) async {
      await zeigeListe(tester, tagMit(eigene: tagesEintraege));

      expect(aufteilungZeile, findsNothing);
      expect(festlegen, findsOneWidget, reason: 'Vorbedingung (V9)');
    });
  });

  group('Eine Form: laden, ohne und mit Aufteilung (Tim, 10.11.2026)', () {
    testWidgets('was unter der Liste steht, steht in jedem Zustand an '
        'derselben Stelle', (tester) async {
      final zustaende = <(String, ErnaehrungsTag)>[
        ('ohne Aufteilung', tagMit(eigene: tagesEintraege)),
        (
          'mit Aufteilung',
          tagMit(aufteilung: startwert, eigene: tagesEintraege),
        ),
        ('Einträge laden, keine Aufteilung', tagMit(eintraegeLaden: true)),
        (
          'Aufteilungen laden',
          tagMit(aufteilung: startwert, aufteilungenLaden: true),
        ),
        (
          'Einträge laden, Aufteilung bekannt',
          tagMit(aufteilung: startwert, eintraegeLaden: true),
        ),
        (
          'mit Aufteilung, ohne Kalorienziel',
          tagMit(aufteilung: startwert, eigene: tagesEintraege, mitZiel: false),
        ),
      ];

      final oben = <String, double>{};
      for (final (name, tag) in zustaende) {
        await zeigeListe(tester, tag);
        oben[name] = tester.getTopLeft(danach).dy;
      }

      final bezug = oben['ohne Aufteilung']!;
      for (final MapEntry(key: name, value: y) in oben.entries) {
        expect(
          y,
          bezug,
          reason:
              '$name: Der Abschnitt darunter steht an einer anderen Stelle '
              'als ohne Aufteilung. Der Platz unter der Liste hat in jedem '
              'Zustand dieselbe Form (Tim, 10.11.2026).',
        );
      }
    });

    testWidgets('beim Laden der Aufteilungen steht weder „Aufteilung" noch '
        'eine Prozentzahl (`01`)', (tester) async {
      await zeigeListe(
        tester,
        tagMit(aufteilung: startwert, aufteilungenLaden: true),
      );

      expect(aufteilungZeile, findsNothing);
      expect(festlegen, findsNothing);
      expect(alleTexte(tester), isNot(contains('25 · 35')));
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  // Über den Schirm: die ganze App auf einer Datenbank im Speicher.
  // ═════════════════════════════════════════════════════════════════════

  group('Über den Schirm', () {
    ({ProviderContainer container, AppCache db, AppRouter router})
    behaelter() {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);

      // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          appCacheProvider.overrideWithValue(db),
          healthProvider.overrideWithValue(_StilleQuelle()),
          clockProvider.overrideWithValue(() => jetzt),
          offClientProvider.overrideWithValue(
            OffClient(client: MockClient((_) async => http.Response('', 500))),
          ),
          strichcodeLeserProvider.overrideWithValue(TestLeser()),
        ],
      );
      addTearDown(container.dispose);
      return (container: container, db: db, router: AppRouter());
    }

    Future<void> starte(
      WidgetTester tester,
      ({ProviderContainer container, AppCache db, AppRouter router}) h,
    ) async {
      await grosseFlaeche(tester);
      await tester.pumpWidget(
        BehaelterImBaum(
          container: h.container,
          child: CupertinoApp(home: RootView(router: h.router)),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> tippe(WidgetTester tester, Finder ziel) async {
      await tester.ensureVisible(ziel);
      await tester.pumpAndSettle();
      await tester.tap(ziel);
      await tester.pumpAndSettle();
    }

    Future<void> zumErnaehrungsTab(WidgetTester tester) => tippe(
      tester,
      find.descendant(
        of: find.byType(CupertinoTabBar),
        matching: find.byIcon(Symbole.aufloesen('fork.knife')),
      ),
    );

    Future<void> legeAb(AppCache db) async {
      await KalorienzielRepository(db).setze(ziel1800);
      await MahlzeitAufteilungRepository(db)
          .setze(AufteilungAb(abTag: '2099-01-01', aufteilung: startwert));
      final repo = ErnaehrungRepository(db);
      for (final e in tagesEintraege) {
        await repo.buche(e);
      }
    }

    testWidgets('die Zeile öffnet die Aufteilung', (tester) async {
      final h = behaelter();
      await legeAb(h.db);
      await starte(tester, h);
      await zumErnaehrungsTab(tester);

      expect(prozenteIn(textUnter(tester, aufteilungZeile)), [25, 35, 30, 10]);
      await tippe(tester, aufteilungZeile);
      expect(find.byType(AufteilungView), findsOneWidget);
    });

    testWidgets('nach Ändern und Sichern zeigt die Zeile die neuen Prozente, '
        'ohne Neustart', (tester) async {
      final h = behaelter();
      await legeAb(h.db);
      await starte(tester, h);
      await zumErnaehrungsTab(tester);

      await tippe(tester, aufteilungZeile);
      expect(find.byType(AufteilungView), findsOneWidget);

      // Frühstück +5 → 30 · 35 · 30 · 5.
      await tippe(tester, find.byKey(const Key('aufteilung-plus-fruehstueck')));
      await tippe(tester, find.byKey(const Key('aufteilung-sichern')));

      Navigator.of(tester.element(find.byType(AufteilungView))).pop();
      await tester.pumpAndSettle();
      expect(find.byType(AufteilungView), findsNothing);

      final text = textUnter(tester, aufteilungZeile);
      expect(text, contains('30 · 35 · 30 · 5'));
      expect(prozenteIn(text), [30, 35, 30, 5]);
    });
  });
}

/// Eine Quelle, die nichts liefert — kein Fall hier hängt an Apple Health.
class _StilleQuelle extends HealthReadingAttrappe {}
