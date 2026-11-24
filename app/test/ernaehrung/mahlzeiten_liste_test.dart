// Die **Mahlzeitenliste** auf dem Ernährungs-Tab (#434 unter #374): je
// Mahlzeit ein Symbol im Ring, „gegessen / Ziel kcal" und ein „+" in die
// Kamera — Zustände und Übergänge.
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
// Abschnitte „Die Mahlzeitenliste" und „Leerzustände", Entscheidungen 4, 7
// und 8, Vorgaben V2 (Live-Spec), V8–V12 — von Tim am 10.11.2026
// übernommen. Plan Task 5. Entwurf `docs/screens/screens/ernaehrung.js`
// (`MAHLZEITEN_NEU`, Zustände `vorschlag-mahlzeiten`, `-morgens`,
// `vorschlag-ohne-aufteilung`, `vorschlag-mahlzeiten-laedt`), Bausteine
// `mahlzeitZeile` und `mzRing` in `docs/screens/components.js`.
//
// Dazu zwei Punkte aus den Kommentaren an #434:
//
// - **Mini-Ring** (Tim, 10.11.2026, Nachtrag in der Spec): Ein Ring mit
//   Eintrag, dessen Anteil auf 0 gerundet ist (2 von 450 kcal), zeigt
//   einen kleinen Mindestausschlag. Das ist Darstellung, der Anteil im
//   Kern bleibt 0.
// - **Lesefehler** (Hinweis des Koordinators aus #432): Scheitert das
//   Lesen der Aufteilungen, gilt das als „keine Aufteilung", wie beim
//   festen Kalorienziel (#410). Die Liste lädt nicht ewig.
//
// ## API (Plan Task 5, „Interfaces")
//
// ```dart
// // lib/design/mahlzeit_ring.dart
// class MahlzeitRing extends StatelessWidget {
//   const MahlzeitRing({required String symbol, required double? anteil,
//       required bool eintrag, bool laedt = false, double durchmesser = 46,
//       double strichstaerke = 4.5});
// }
// // lib/ernaehrung/mahlzeiten_liste.dart
// const mahlzeitenInListe = [Mahlzeit.fruehstueck, Mahlzeit.mittag,
//     Mahlzeit.abend, Mahlzeit.snack];
// class MahlzeitenListe extends StatelessWidget {
//   const MahlzeitenListe({required ErnaehrungsTag tag,
//       required void Function(Mahlzeit) onMahlzeit,
//       required void Function(Mahlzeit) onPlus,
//       required VoidCallback onAufteilung});
// }
// ```
//
// ## Schlüssel (Spec, „Die Mahlzeitenliste")
//
// `ernaehrung-mahlzeiten` (der Abschnitt), `ernaehrung-mahlzeit-<m>` (die
// Zeile), `ernaehrung-mahlzeit-plus-<m>`, `ernaehrung-mahlzeit-ring-<m>`,
// `ernaehrung-aufteilung-festlegen`; `<m>` ist `Mahlzeit.name`.
//
// ## Festlegungen des Test-Agenten — nicht von Tim freigegeben
//
// - **Die Spur ist kein Bogen.** Jede Runde des Rings ist genau ein
//   `drawArc`, die Spur darunter ein Kreis. So lassen sich die Runden
//   zählen. Eine abgesetzte Spitze wie bei den großen Ringen (#386) zeichnet
//   der Entwurf (`mzRing`) nicht.
// - **Der Mindestausschlag ist sichtbar, aber klein:** mehr als 0 und
//   höchstens ein Zehntel eines Umlaufs.
// - **`ernaehrung-mahlzeit-ring-<m>` sitzt auf dem `MahlzeitRing` selbst
//   oder auf einer Hülle mit genau einem darin.**
// - **Der Text unter dem Namen ist ein Text**, „426 / 450 kcal" am Stück.
//   Ob eine Zahl als „1.800" oder „1800" dasteht, prüft hier niemand; die
//   Zahlen dieser Datei sind dreistellig.
// - **Der Lesefehler wird am Schirm geprüft**, nicht am Provider allein:
//   Was zählt, ist, dass die Zeile „Ziel je Mahlzeit festlegen" kommt und
//   die Liste nicht in Grau stehen bleibt.
//
// ## Was hier nicht geprüft wird
//
// Abstände, Schriften, Größen in Punkt (`CLAUDE.md`: Widget-Tests nur für
// Zustände und Übergänge). Die eine Geometrie-Aussage ist keine
// Layout-Prüfung, sondern die Regel „Eine Anzeige hat genau eine Form":
// Die Zeilen sind in jedem Zustand gleich hoch.
//
// **Alle Zahlen und Daten sind erfunden**, Zeitpunkte im Jahr 2099.
import 'dart:math' as math;

import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
// `MahlzeitRing` gibt es zweimal: im Kern der Ring der Live-Aktivität
// (Werttyp), hier das Widget. Gemeint ist in dieser Datei das Widget.
import 'package:trainings_core/trainings_core.dart' hide MahlzeitRing;

import 'package:repit/core/messwert.dart';
import 'package:repit/data/cache.dart';
import 'package:repit/data/ernaehrung_repository.dart';
import 'package:repit/data/kalorienziele.dart';
import 'package:repit/data/mahlzeit_aufteilungen.dart';
import 'package:repit/data/stammdaten.dart';
import 'package:repit/design/mahlzeit_ring.dart';
import 'package:repit/design/palette.dart';
import 'package:repit/design/symbole.dart';
import 'package:repit/ernaehrung/aufteilung_view.dart';
import 'package:repit/ernaehrung/ernaehrung_provider.dart';
import 'package:repit/ernaehrung/kamera_seite.dart';
import 'package:repit/ernaehrung/mahlzeit_view.dart';
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
  const gestern = '2099-07-13';

  // 1.800 kcal, aufgeteilt 25 · 35 · 30 · 10 → 450 · 630 · 540 · 180.
  const ziel1800 = KalorienzielFestlegung(
    abTag: '2099-01-01',
    kcal: 1800,
    herkunft: KalorienzielHerkunft.hand,
  );
  final aufteilung = MahlzeitAufteilung(fruehstueck: 25, mittag: 35, abend: 30);

  Eintrag eintrag(
    Mahlzeit m,
    double? kcal, {
    String tag = heute,
    String name = 'Prüfgericht',
  }) => Eintrag(
    tagesSchluessel: tag,
    mahlzeit: m,
    zeitpunkt: jetzt,
    name: name,
    naehrwerte: Naehrwerte(kcal: kcal, eiweissG: 10),
  );

  // Frühstück 426 / 450 (0,95), Mittag 672 / 630 (1,07, über dem Ziel),
  // Abend ohne Eintrag, Snack 162 / 180.
  final tagesEintraege = [
    eintrag(Mahlzeit.fruehstueck, 426),
    eintrag(Mahlzeit.mittag, 672),
    eintrag(Mahlzeit.snack, 162),
  ];

  /// Der Tag aus der echten Rechnung (`ernaehrungsTagAus`), nicht von Hand
  /// gebaut — so trägt jede Zeile Ziel und Anteil aus dem Provider, wie im
  /// Schirm (Regel 2).
  ErnaehrungsTag tagMit({
    List<Eintrag> eigene = const [],
    bool mitAufteilung = true,
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
    aufteilungen: mitAufteilung
        ? [AufteilungAb(abTag: '2099-01-01', aufteilung: aufteilung)]
        : const [],
    aufteilungenLaden: aufteilungenLaden,
    eintraegeLaden: eintraegeLaden,
  );

  Finder zeile(Mahlzeit m) => find.byKey(Key('ernaehrung-mahlzeit-${m.name}'));
  Finder plus(Mahlzeit m) =>
      find.byKey(Key('ernaehrung-mahlzeit-plus-${m.name}'));
  Finder ringStelle(Mahlzeit m) =>
      find.byKey(Key('ernaehrung-mahlzeit-ring-${m.name}'));
  final festlegen = find.byKey(const Key('ernaehrung-aufteilung-festlegen'));
  final abschnitt = find.byKey(const Key('ernaehrung-mahlzeiten'));

  Future<void> grosseFlaeche(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 4800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  /// Die Liste allein, mit mitschreibenden Rückrufen.
  Future<({List<Mahlzeit> geoeffnet, List<Mahlzeit> plusse, List<int> auf})>
  zeigeListe(WidgetTester tester, ErnaehrungsTag tag) async {
    await grosseFlaeche(tester);
    final geoeffnet = <Mahlzeit>[];
    final plusse = <Mahlzeit>[];
    final auf = <int>[];
    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: SingleChildScrollView(
            child: MahlzeitenListe(
              tag: tag,
              onMahlzeit: geoeffnet.add,
              onPlus: plusse.add,
              onAufteilung: () => auf.add(1),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (geoeffnet: geoeffnet, plusse: plusse, auf: auf);
  }

  /// Der Ring allein.
  Future<void> zeigeRing(WidgetTester tester, MahlzeitRing ring) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(child: Center(child: ring)),
      ),
    );
    await tester.pump();
  }

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

  String alleTexte(WidgetTester tester) =>
      tester.widgetList<Text>(find.byType(Text)).map(textOf).join(' ');

  MahlzeitRing ringIn(WidgetTester tester, Finder wurzel) {
    expect(
      wurzel,
      findsOneWidget,
      reason: 'Der Schlüssel fehlt — siehe „Schlüssel" im Dateikopf.',
    );
    return tester.widget<MahlzeitRing>(
      find.descendant(
        of: wurzel,
        matching: find.byType(MahlzeitRing),
        matchRoot: true,
      ),
    );
  }

  /// Die Bögen, die [stelle] zeichnet — je Runde einer (siehe
  /// „Festlegungen" im Dateikopf).
  List<({double sweep, Color farbe})> boegen(Finder stelle) {
    final liste = <({double sweep, Color farbe})>[];
    expect(
      stelle,
      paints..everything((methode, argumente) {
        if (methode == #drawArc) {
          liste.add((
            sweep: (argumente[2] as double).abs(),
            farbe: (argumente[4] as Paint).color,
          ));
        }
        return true;
      }),
    );
    return liste;
  }

  const umlauf = 2 * math.pi;

  // ═════════════════════════════════════════════════════════════════════

  group('Reihenfolge (Entscheidung 8, V8)', () {
    test('mahlzeitenInListe ist Frühstück, Mittag, Abend, Snack', () {
      expect(mahlzeitenInListe, [
        Mahlzeit.fruehstueck,
        Mahlzeit.mittag,
        Mahlzeit.abend,
        Mahlzeit.snack,
      ]);
    });

    testWidgets('die Zeilen stehen untereinander in dieser Reihenfolge, '
        'der Snack zuletzt', (tester) async {
      await zeigeListe(tester, tagMit(eigene: tagesEintraege));

      final oben = [
        for (final m in mahlzeitenInListe) tester.getTopLeft(zeile(m)).dy,
      ];
      expect(oben, orderedEquals([...oben]..sort()));
      expect(oben.toSet(), hasLength(4));
    });
  });

  group('Mit Ziel (V10, Entscheidung 7)', () {
    testWidgets('„426 / 450 kcal", über dem Ziel „672 / 630 kcal"', (
      tester,
    ) async {
      await zeigeListe(tester, tagMit(eigene: tagesEintraege));

      expect(
        textUnter(tester, zeile(Mahlzeit.fruehstueck)),
        contains('426 / 450 kcal'),
      );
      expect(
        textUnter(tester, zeile(Mahlzeit.mittag)),
        contains('672 / 630 kcal'),
      );
      expect(
        textUnter(tester, zeile(Mahlzeit.snack)),
        contains('162 / 180 kcal'),
      );
    });

    testWidgets('ohne Eintrag „– / 540 kcal", nie „0 / 540"', (tester) async {
      await zeigeListe(tester, tagMit(eigene: tagesEintraege));

      final abend = textUnter(tester, zeile(Mahlzeit.abend));
      expect(abend, contains('– / 540 kcal'));
      expect(abend, isNot(contains('0 / 540')));
      expect(abend, isNot(contains('noch nichts eingetragen')));
    });

    testWidgets('morgens: vier Zeilen mit „– / Ziel", keine Festlegen-Zeile', (
      tester,
    ) async {
      await zeigeListe(tester, tagMit());

      expect(
        textUnter(tester, zeile(Mahlzeit.fruehstueck)),
        contains('– / 450 kcal'),
      );
      expect(
        textUnter(tester, zeile(Mahlzeit.mittag)),
        contains('– / 630 kcal'),
      );
      expect(
        textUnter(tester, zeile(Mahlzeit.abend)),
        contains('– / 540 kcal'),
      );
      expect(
        textUnter(tester, zeile(Mahlzeit.snack)),
        contains('– / 180 kcal'),
      );
      expect(festlegen, findsNothing);
    });

    testWidgets('Eintrag ohne Kalorienangabe: „–/– / 540 kcal"', (
      tester,
    ) async {
      await zeigeListe(tester, tagMit(eigene: [eintrag(Mahlzeit.abend, null)]));

      expect(
        textUnter(tester, zeile(Mahlzeit.abend)),
        contains('–/– / 540 kcal'),
      );
    });

    testWidgets('mit Aufteilung steht keine Festlegen-Zeile', (tester) async {
      await zeigeListe(tester, tagMit(eigene: tagesEintraege));
      expect(festlegen, findsNothing);
    });
  });

  group('Ohne Aufteilung (Entscheidung 1, V9, V10)', () {
    testWidgets('nur die Summe bzw. „noch nichts eingetragen", kein Ziel', (
      tester,
    ) async {
      await zeigeListe(
        tester,
        tagMit(eigene: tagesEintraege, mitAufteilung: false),
      );

      final fruehstueck = textUnter(tester, zeile(Mahlzeit.fruehstueck));
      expect(fruehstueck, contains('426 kcal'));
      expect(
        fruehstueck,
        isNot(contains('/')),
        reason:
            'Ohne gesicherte Aufteilung erfindet die App kein Ziel — '
            'auch nicht den Startwert.',
      );
      expect(
        textUnter(tester, zeile(Mahlzeit.abend)),
        contains('noch nichts eingetragen'),
      );
    });

    testWidgets('darunter genau einmal „Ziel je Mahlzeit festlegen", ein '
        'Tipp ruft onAufteilung', (tester) async {
      final r = await zeigeListe(
        tester,
        tagMit(eigene: tagesEintraege, mitAufteilung: false),
      );

      expect(festlegen, findsOneWidget);
      await tester.tap(festlegen);
      await tester.pumpAndSettle();
      expect(r.auf, [1]);
      expect(r.geoeffnet, isEmpty);
      expect(r.plusse, isEmpty);
    });

    testWidgets('ohne Kalorienziel, aber mit Aufteilung: keine '
        'Festlegen-Zeile, nur die Summe', (tester) async {
      final tag = tagMit(eigene: tagesEintraege, mitZiel: false);
      expect(
        tag.zielKcal,
        isNull,
        reason:
            'Vorbedingung: ohne Festlegung und ohne Health-Werte gibt '
            'es kein Tagesziel.',
      );
      expect(tag.mahlzeitenLaedt, isFalse);
      await zeigeListe(tester, tag);

      expect(festlegen, findsNothing);
      expect(
        textUnter(tester, zeile(Mahlzeit.fruehstueck)),
        contains('426 kcal'),
      );
      expect(
        textUnter(tester, zeile(Mahlzeit.fruehstueck)),
        isNot(contains('/')),
      );
    });
  });

  group('Laden (`01`, V9)', () {
    for (final (name, tag) in [
      ('Einträge', () => tagMit(eintraegeLaden: true, mitAufteilung: false)),
      ('Aufteilungen', () => tagMit(aufteilungenLaden: true)),
    ]) {
      testWidgets('$name laden: weder „noch nichts eingetragen" noch die '
          'Festlegen-Zeile', (tester) async {
        final t = tag();
        expect(t.mahlzeitenLaedt, isTrue);
        await zeigeListe(tester, t);

        expect(alleTexte(tester), isNot(contains('noch nichts eingetragen')));
        expect(alleTexte(tester), isNot(contains('kcal')));
        expect(festlegen, findsNothing);
      });
    }

    testWidgets('beim Laden: kein Symbol, keine Füllung, das „+" steht', (
      tester,
    ) async {
      await zeigeListe(tester, tagMit(eintraegeLaden: true));

      for (final m in mahlzeitenInListe) {
        final ring = ringIn(tester, ringStelle(m));
        expect(ring.laedt, isTrue, reason: m.name);
        expect(boegen(ringStelle(m)), isEmpty, reason: m.name);
        expect(plus(m), findsOneWidget, reason: m.name);
      }
      for (final symbol in ['☕️', '🍜', '🥗', '🍎']) {
        expect(find.text(symbol), findsNothing);
      }
    });
  });

  group('Eine Form (`CLAUDE.md`, „Eine Anzeige hat genau eine Form")', () {
    testWidgets('jede Zeile ist mit Ziel, ohne Ziel, morgens und beim Laden '
        'gleich hoch', (tester) async {
      Future<Map<Mahlzeit, Size>> groessen(ErnaehrungsTag tag) async {
        await zeigeListe(tester, tag);
        return {for (final m in mahlzeitenInListe) m: tester.getSize(zeile(m))};
      }

      final mitZiel = await groessen(tagMit(eigene: tagesEintraege));
      final ohne = await groessen(
        tagMit(eigene: tagesEintraege, mitAufteilung: false),
      );
      final morgens = await groessen(tagMit());
      final laedt = await groessen(tagMit(eintraegeLaden: true));

      for (final m in mahlzeitenInListe) {
        expect(ohne[m], mitZiel[m], reason: 'ohne Aufteilung, ${m.name}');
        expect(morgens[m], mitZiel[m], reason: 'morgens, ${m.name}');
        expect(laedt[m], mitZiel[m], reason: 'lädt, ${m.name}');
      }
    });

    testWidgets('der Abschnitt ist beim Laden so hoch wie mit Werten', (
      tester,
    ) async {
      await zeigeListe(tester, tagMit(eigene: tagesEintraege));
      final mitWerten = tester.getSize(abschnitt);
      await zeigeListe(tester, tagMit(eintraegeLaden: true));
      expect(tester.getSize(abschnitt), mitWerten);
      await zeigeListe(tester, tagMit());
      expect(tester.getSize(abschnitt), mitWerten);
    });
  });

  group('Ring (Entscheidung 4, V2, Mini-Ring)', () {
    final ring = find.byType(MahlzeitRing);
    final warn = {Palette.warn.color, Palette.warn.darkColor};

    testWidgets('Anteil 1,07: zwei Runden, keine davon rot', (tester) async {
      await zeigeRing(
        tester,
        const MahlzeitRing(symbol: '🍜', anteil: 1.07, eintrag: true),
      );

      final b = boegen(ring);
      expect(b, hasLength(2));
      expect(b[0].sweep, closeTo(umlauf, 1e-6));
      expect(b[1].sweep, closeTo(umlauf * 0.07, 1e-3));
      for (final bogen in b) {
        expect(
          warn,
          isNot(contains(bogen.farbe)),
          reason: 'Über dem Ziel wird eine Mahlzeit nicht rot.',
        );
      }
      expect(
        b[1].farbe,
        isNot(b[0].farbe),
        reason: 'Die zweite Runde hebt sich von der ersten ab (#386).',
      );
    });

    testWidgets('Anteil 0,5: eine halbe Runde', (tester) async {
      await zeigeRing(
        tester,
        const MahlzeitRing(symbol: '☕️', anteil: 0.5, eintrag: true),
      );
      final b = boegen(ring);
      expect(b, hasLength(1));
      expect(b.single.sweep, closeTo(umlauf / 2, 1e-6));
    });

    testWidgets('ab 3,0 höchstens drei Runden', (tester) async {
      await zeigeRing(
        tester,
        const MahlzeitRing(symbol: '☕️', anteil: 3.0, eintrag: true),
      );
      expect(boegen(ring), hasLength(3));
    });

    testWidgets('ohne Anteil mit Eintrag: eine volle Runde (V2)', (
      tester,
    ) async {
      await zeigeRing(
        tester,
        const MahlzeitRing(symbol: '🥗', anteil: null, eintrag: true),
      );
      final b = boegen(ring);
      expect(b, hasLength(1));
      expect(b.single.sweep, closeTo(umlauf, 1e-6));
    });

    testWidgets('ohne Eintrag keine Runde, mit oder ohne Anteil', (
      tester,
    ) async {
      await zeigeRing(
        tester,
        const MahlzeitRing(symbol: '🥗', anteil: null, eintrag: false),
      );
      expect(boegen(ring), isEmpty);

      await zeigeRing(
        tester,
        const MahlzeitRing(symbol: '🥗', anteil: 0, eintrag: false),
      );
      expect(boegen(ring), isEmpty);
    });

    testWidgets('Mini-Ring: mit Eintrag und Anteil 0 ein kleiner '
        'Mindestausschlag', (tester) async {
      await zeigeRing(
        tester,
        const MahlzeitRing(symbol: '☕️', anteil: 0, eintrag: true),
      );
      final b = boegen(ring);
      expect(b, hasLength(1));
      expect(b.single.sweep, greaterThan(0));
      expect(b.single.sweep, lessThanOrEqualTo(umlauf / 10));
    });

    testWidgets('Mini-Ring: ein Anteil unter dem Mindestausschlag zeigt '
        'den Mindestausschlag, nicht weniger', (tester) async {
      await zeigeRing(
        tester,
        const MahlzeitRing(symbol: '☕️', anteil: 0, eintrag: true),
      );
      final minimum = boegen(ring).single.sweep;

      await zeigeRing(
        tester,
        const MahlzeitRing(symbol: '☕️', anteil: 0.01, eintrag: true),
      );
      expect(boegen(ring).single.sweep, greaterThanOrEqualTo(minimum));
    });

    testWidgets('Mini-Ring in der Liste: 2 von 450 kcal', (tester) async {
      final tag = tagMit(eigene: [eintrag(Mahlzeit.fruehstueck, 2)]);
      final zeileFruehstueck = tag.mahlzeiten.firstWhere(
        (z) => z.mahlzeit == Mahlzeit.fruehstueck,
      );
      expect(
        zeileFruehstueck.anteil,
        0,
        reason: 'Vorbedingung: Der Kern rundet 2 / 450 auf 0.',
      );
      await zeigeListe(tester, tag);

      expect(
        textUnter(tester, zeile(Mahlzeit.fruehstueck)),
        contains('2 / 450 kcal'),
      );
      final b = boegen(ringStelle(Mahlzeit.fruehstueck));
      expect(b, hasLength(1));
      expect(b.single.sweep, greaterThan(0));
    });

    testWidgets('beim Laden weder Füllung noch Symbol', (tester) async {
      await zeigeRing(
        tester,
        const MahlzeitRing(
          symbol: '☕️',
          anteil: 0.5,
          eintrag: true,
          laedt: true,
        ),
      );
      expect(boegen(ring), isEmpty);
      expect(find.text('☕️'), findsNothing);
    });

    testWidgets('in der Liste trägt jeder Ring Anteil und Eintrag seiner '
        'Zeile', (tester) async {
      await zeigeListe(tester, tagMit(eigene: tagesEintraege));

      final fruehstueck = ringIn(tester, ringStelle(Mahlzeit.fruehstueck));
      expect(fruehstueck.anteil, closeTo(0.95, 1e-9));
      expect(fruehstueck.eintrag, isTrue);
      expect(fruehstueck.symbol, '☕️');

      final mittag = ringIn(tester, ringStelle(Mahlzeit.mittag));
      expect(mittag.anteil, closeTo(1.07, 1e-9));
      expect(boegen(ringStelle(Mahlzeit.mittag)), hasLength(2));

      final abend = ringIn(tester, ringStelle(Mahlzeit.abend));
      expect(abend.eintrag, isFalse);
      expect(boegen(ringStelle(Mahlzeit.abend)), isEmpty);
      expect(abend.symbol, '🥗');

      expect(ringIn(tester, ringStelle(Mahlzeit.mittag)).symbol, '🍜');
      expect(ringIn(tester, ringStelle(Mahlzeit.snack)).symbol, '🍎');
    });

    testWidgets('ohne Aufteilung: voll mit Eintrag, leer ohne (V2)', (
      tester,
    ) async {
      await zeigeListe(
        tester,
        tagMit(eigene: tagesEintraege, mitAufteilung: false),
      );

      final voll = boegen(ringStelle(Mahlzeit.mittag));
      expect(voll, hasLength(1));
      expect(voll.single.sweep, closeTo(umlauf, 1e-6));
      expect(boegen(ringStelle(Mahlzeit.abend)), isEmpty);
    });
  });

  group('Zwei Flächen (V12)', () {
    testWidgets('ein Tipp auf die Zeile ruft onMahlzeit', (tester) async {
      final r = await zeigeListe(tester, tagMit(eigene: tagesEintraege));

      await tester.tap(zeile(Mahlzeit.fruehstueck));
      await tester.pumpAndSettle();
      expect(r.geoeffnet, [Mahlzeit.fruehstueck]);
      expect(r.plusse, isEmpty);
    });

    testWidgets('ein Tipp auf „+" ruft onPlus, nicht onMahlzeit', (
      tester,
    ) async {
      final r = await zeigeListe(tester, tagMit(eigene: tagesEintraege));

      await tester.tap(plus(Mahlzeit.abend));
      await tester.pumpAndSettle();
      expect(r.plusse, [Mahlzeit.abend]);
      expect(r.geoeffnet, isEmpty);
    });

    testWidgets('auch beim Laden lässt sich über „+" eintragen', (
      tester,
    ) async {
      final r = await zeigeListe(tester, tagMit(eintraegeLaden: true));

      await tester.tap(plus(Mahlzeit.mittag));
      await tester.pumpAndSettle();
      expect(r.plusse, [Mahlzeit.mittag]);
    });
  });

  group('Vorlesetexte (V11)', () {
    testWidgets('mit Ziel, ohne Eintrag, ohne Ziel', (tester) async {
      final semantik = tester.ensureSemantics();
      await zeigeListe(tester, tagMit(eigene: tagesEintraege));

      expect(
        find.bySemanticsLabel('Frühstück, 426 von 450 Kilokalorien'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          'Abend, nichts eingetragen, Ziel 540 '
          'Kilokalorien',
        ),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Zum Frühstück hinzufügen'), findsOneWidget);

      await zeigeListe(
        tester,
        tagMit(eigene: tagesEintraege, mitAufteilung: false),
      );
      expect(find.bySemanticsLabel('Snack, 162 Kilokalorien'), findsOneWidget);
      semantik.dispose();
    });

    testWidgets('beim Laden „wird geladen"', (tester) async {
      final semantik = tester.ensureSemantics();
      await zeigeListe(tester, tagMit(eintraegeLaden: true));

      expect(find.bySemanticsLabel('Frühstück, wird geladen'), findsOneWidget);
      semantik.dispose();
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  // Über den Schirm: die ganze App (`RootView`) auf einer Datenbank im
  // Speicher, wie `mahlzeit_kamera_test.dart` — eine Tür, die im
  // Einzeltest aufgeht und in der App an einem fehlenden Router hängt, ist
  // genau der Fehler, um den es geht.
  // ═════════════════════════════════════════════════════════════════════

  group('Über den Schirm', () {
    ({ProviderContainer container, AppCache db, AppRouter router}) behaelter({
      bool aufteilungenKaputt = false,
    }) {
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
          if (aufteilungenKaputt)
            mahlzeitAufteilungenProvider.overrideWith(_KaputteAufteilungen.new),
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

    Future<void> legeAb(AppCache db, {bool mitAufteilung = true}) async {
      await KalorienzielRepository(db).setze(ziel1800);
      if (mitAufteilung) {
        await MahlzeitAufteilungRepository(db)
            .setze(AufteilungAb(abTag: '2099-01-01', aufteilung: aufteilung));
      }
      final repo = ErnaehrungRepository(db);
      for (final e in tagesEintraege) {
        await repo.buche(e);
      }
    }

    testWidgets('„+" öffnet die Kamera mit dieser Mahlzeit und dem offenen '
        'Tag', (tester) async {
      final h = behaelter();
      await legeAb(h.db);
      await starte(tester, h);
      await zumErnaehrungsTab(tester);
      await tippe(tester, find.byKey(const Key('ernaehrung-zurueck')));

      await tippe(tester, plus(Mahlzeit.abend));

      expect(find.byType(KameraSeite), findsOneWidget);
      final kamera = tester.widget<KameraSeite>(find.byType(KameraSeite));
      expect(kamera.mahlzeit, Mahlzeit.abend);
      expect(kamera.tagesSchluessel, gestern);
      expect(
        find.byType(MahlzeitView),
        findsNothing,
        reason: 'Das „+" öffnet nicht die Mahlzeit.',
      );
    });

    testWidgets('die Zeile öffnet die Mahlzeit', (tester) async {
      final h = behaelter();
      await legeAb(h.db);
      await starte(tester, h);
      await zumErnaehrungsTab(tester);

      await tippe(tester, zeile(Mahlzeit.snack));

      final schirm = tester.widget<MahlzeitView>(find.byType(MahlzeitView));
      expect(schirm.mahlzeit, Mahlzeit.snack);
      expect(schirm.tagesSchluessel, heute);
      expect(find.byType(KameraSeite), findsNothing);
    });

    testWidgets('„Ziel je Mahlzeit festlegen" öffnet die Aufteilung', (
      tester,
    ) async {
      final h = behaelter();
      await legeAb(h.db, mitAufteilung: false);
      await starte(tester, h);
      await zumErnaehrungsTab(tester);

      await tippe(tester, festlegen);
      expect(find.byType(AufteilungView), findsOneWidget);
    });

    testWidgets('zurück und wieder hin (`32`): der Ring mit Anteil steht '
        'wieder da', (tester) async {
      final h = behaelter();
      await legeAb(h.db);
      await starte(tester, h);
      await zumErnaehrungsTab(tester);

      expect(
        ringIn(tester, ringStelle(Mahlzeit.fruehstueck)).anteil,
        closeTo(0.95, 1e-9),
      );

      await tippe(tester, zeile(Mahlzeit.fruehstueck));
      expect(find.byType(MahlzeitView), findsOneWidget);
      Navigator.of(tester.element(find.byType(MahlzeitView))).pop();
      await tester.pumpAndSettle();
      expect(find.byType(MahlzeitView), findsNothing);

      expect(
        ringIn(tester, ringStelle(Mahlzeit.fruehstueck)).anteil,
        closeTo(0.95, 1e-9),
      );
      expect(
        textUnter(tester, zeile(Mahlzeit.fruehstueck)),
        contains('426 / 450 kcal'),
      );
    });

    testWidgets('Lesefehler der Aufteilung: gilt als „keine Aufteilung", '
        'die Liste lädt nicht ewig', (tester) async {
      final h = behaelter(aufteilungenKaputt: true);
      await legeAb(h.db, mitAufteilung: false);
      await starte(tester, h);
      await zumErnaehrungsTab(tester);

      final tag = h.container.read(ernaehrungsTagProvider(heute));
      expect(tag.mahlzeitenLaedt, isFalse);
      expect(tag.aufteilung, isNull);

      expect(festlegen, findsOneWidget);
      expect(
        textUnter(tester, zeile(Mahlzeit.fruehstueck)),
        contains('426 kcal'),
      );
      expect(
        textUnter(tester, zeile(Mahlzeit.abend)),
        contains('noch nichts eingetragen'),
      );
      expect(ringIn(tester, ringStelle(Mahlzeit.fruehstueck)).laedt, isFalse);
    });
  });
}

/// Eine Quelle, die nichts liefert — kein Fall hier hängt an Apple Health.
class _StilleQuelle extends HealthReadingAttrappe {}

/// Eine Attrappe, deren Lesen scheitert.
class _KaputteAufteilungen extends MahlzeitAufteilungenNotifier {
  @override
  Future<List<AufteilungAb>> build() async =>
      throw StateError('Aufteilungen nicht lesbar (Testattrappe)');
}
