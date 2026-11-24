import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/core/messwert.dart';
import 'package:repit/data/ernaehrung_repository.dart';
import 'package:repit/design/formatierung.dart';
import 'package:repit/design/platzhalter.dart';
import 'package:repit/design/zahlen.dart';
import 'package:repit/ernaehrung/ernaehrung_provider.dart';
import 'package:repit/ernaehrung/ernaehrung_verlauf.dart';
import 'package:repit/health/health_types.dart';

import 'tag_huelle.dart';

/// Tests für **#378**: Langes Drücken auf einen Tag des 14-Tage-Verlaufs
/// zeigt dessen Details — wie in den übrigen Diagrammen der App
/// (`Zeitdiagramm`, „Ablesen durch Halten").
///
/// Geprüft werden **Zustände und Übergänge**, nicht Layout und
/// Beschriftung (`CLAUDE.md`, „Tests"): Halten zeigt Datum, gegessen,
/// Verbrauch und Ziel des gehaltenen Tages; ein fehlender Wert steht als
/// `–/–`, nie als 0; Loslassen springt zurück; ein Tipp wählt nichts aus;
/// und die Anzeige behält beim Halten ihre Höhe.
///
/// ## Festgelegte API — Entscheidung des Test-Agenten, nicht von Tim
///
/// Im aufgeklappten Verlauf:
///
/// - `Key('ernaehrung-verlauf-kopfzeile')` — der Kopf über dem Graphen.
///   Ohne Auswahl „Durchschnitt" und Zeitraum, beim Halten die Details
///   des Tages. Wie bei `Zeitdiagramm` (`diagramm-kopfzeile`) tritt das
///   Abgelesene **an die Stelle** des Durchschnitts, statt in einer eigenen
///   Zeile zu erscheinen, die beim Halten alles darunter verschöbe (#146).
/// - `Key('ernaehrung-verlauf-graph')` — die Zeichenfläche, auf der die
///   Geste liegt. Vierzehn gleich breite Plätze, der älteste links.
///
/// Das Datum steht in derselben Form wie im `Zeitdiagramm` bei Tagen:
/// `Format.wochentagUndDatum` („Montag, 19. Oktober"); verglichen wird
/// ohne Groß- und Kleinschreibung.
///
/// Alle Zahlen erfunden.
void main() {
  // Freitag, 30.10.2026, 12:00 Berliner Zeit. Das Fenster läuft vom 17.10.
  // bis zum 30.10.
  final jetzt = DateTime.utc(2026, 10, 30, 11);
  const heute = '2026-10-30';

  final fenster = [
    for (var i = 13; i >= 0; i--)
      BerlinCalendar.dayKey(BerlinCalendar.addDays(jetzt, -i)),
  ];

  /// Alles gemessen: 450 aktiv + 1.630 Grundumsatz = 2.080 kcal.
  const tagMitAllem = '2026-10-19';

  /// Gegessen 1.300, aber ohne Grundumsatz — kein Verbrauch.
  const tagOhneVerbrauch = '2026-10-20';

  /// Verbrauch gemessen, aber nichts eingetragen.
  const tagOhneEssen = '2026-10-22';

  final tageswerte = Bekannt<List<DailyMetrics>>(
    [
      for (final tag in fenster)
        if (tag == tagOhneVerbrauch)
          DailyMetrics(tag: tag, activeKcal: 400, weightKg: 80)
        else
          DailyMetrics(
            tag: tag,
            activeKcal: 450,
            basalKcal: 1630,
            weightKg: 80,
          ),
    ],
    stand: jetzt,
    laeuft: false,
  );

  Eintrag eintrag(String tag, double kcal) => Eintrag(
    tagesSchluessel: tag,
    mahlzeit: Mahlzeit.mittag,
    zeitpunkt: DateTime.parse('${tag}T11:00:00Z'),
    name: 'Prüfgericht',
    mengeG: 100,
    naehrwerte: Naehrwerte(kcal: kcal),
  );

  Future<TagHuelle> starte(WidgetTester tester) async {
    final h = tagHuelle(jetzt: jetzt, tageswerte: tageswerte);
    final repo = ErnaehrungRepository(h.db);
    await repo.buche(eintrag(tagMitAllem, 1000));
    await repo.buche(eintrag(tagMitAllem, 750));
    await repo.buche(eintrag(tagOhneVerbrauch, 1300));
    await zeigeTag(tester, h.app);

    await tester.tap(find.byKey(const Key('ernaehrung-verlauf-kopf')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ernaehrung-verlauf-graph')), findsOneWidget);
    return h;
  }

  ErnaehrungsVerlauf verlauf(TagHuelle h) {
    h.container.listen(ernaehrungsVerlaufProvider(heute), (_, _) {});
    return h.container.read(ernaehrungsVerlaufProvider(heute));
  }

  String kopf(WidgetTester tester) =>
      texteUnter(tester, const Key('ernaehrung-verlauf-kopfzeile'));

  /// Die Mitte des Platzes von [tag] auf der Zeichenfläche.
  Offset mitteVon(WidgetTester tester, String tag) {
    final i = fenster.indexOf(tag);
    expect(i, isNonNegative, reason: '$tag liegt im Fenster');
    final graph = tester.getRect(
      find.byKey(const Key('ernaehrung-verlauf-graph')),
    );
    return Offset(
      graph.left + graph.width * (i + 0.5) / fenster.length,
      graph.center.dy,
    );
  }

  /// Finger auflegen und liegen lassen, bis das Halten anschlägt — ohne
  /// `pumpAndSettle`, damit „Finger liegt noch auf" prüfbar bleibt.
  Future<TestGesture> halte(WidgetTester tester, String tag) async {
    final geste = await tester.startGesture(mitteVon(tester, tag));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();
    return geste;
  }

  Future<void> lass(WidgetTester tester, TestGesture geste) async {
    await geste.up();
    await tester.pumpAndSettle();
  }

  String datum(String tag) =>
      Format.wochentagUndDatum(kalendertag(datumAusTag(tag))).toLowerCase();

  /// Eine einzelne 0 als Wort — „0 kcal", „0" —, nicht die Null in 1.300.
  final nullAlsWert = RegExp(r'(^|[\s·])0([\s·]|$)');

  group('Halten zeigt die Details des Tages (#378)', () {
    testWidgets('Datum, gegessen, Verbrauch und Ziel des gehaltenen Tages', (
      tester,
    ) async {
      final h = await starte(tester);
      final tagDaten = verlauf(
        h,
      ).tage.firstWhere((t) => t.tag == tagMitAllem);
      expect(tagDaten.gegessenKcal, 1750, reason: 'Vorbedingung');
      expect(tagDaten.verbrauchKcal, 2080, reason: 'Vorbedingung');
      expect(
        tagDaten.zielKcal,
        isNotNull,
        reason: 'Vorbedingung: an diesem Tag ist ein Ziel berechenbar',
      );
      final ziel = formatNumber(tagDaten.zielKcal!);

      final ohneAuswahl = kopf(tester);
      expect(
        ohneAuswahl,
        isNot(contains('1.750')),
        reason: 'ohne Auswahl steht kein Einzelwert im Kopf',
      );

      final geste = await halte(tester, tagMitAllem);
      final gehalten = kopf(tester).toLowerCase();

      expect(
        gehalten,
        contains(datum(tagMitAllem)),
        reason: 'der Kopf nennt den Tag, wie im Zeitdiagramm',
      );
      expect(gehalten, contains('1.750'), reason: 'gegessen');
      expect(gehalten, contains('kcal'), reason: 'gegessen in kcal');
      expect(gehalten, contains('2.080'), reason: 'Verbrauch');
      expect(gehalten, contains(ziel), reason: 'Ziel des Tages');
      expect(
        gehalten,
        isNot(contains('durchschnitt')),
        reason:
            'Beim Ablesen tritt der Tag an die Stelle des Durchschnitts '
            '(`chartCard` im Entwurfsboard)',
      );

      await lass(tester, geste);
    });

    testWidgets('zwei Tage ergeben zwei verschiedene Köpfe', (tester) async {
      await starte(tester);

      final links = await halte(tester, tagMitAllem);
      final kopfLinks = kopf(tester).toLowerCase();
      await lass(tester, links);

      final rechts = await halte(tester, tagOhneEssen);
      final kopfRechts = kopf(tester).toLowerCase();
      await lass(tester, rechts);

      expect(kopfLinks, contains(datum(tagMitAllem)));
      expect(kopfRechts, contains(datum(tagOhneEssen)));
      expect(kopfLinks, isNot(kopfRechts));
    });
  });

  group('Fehlende Werte stehen als –/–, nie als 0 (#378)', () {
    testWidgets('ein Tag ohne Eintrag: gegessen –/–, Verbrauch steht', (
      tester,
    ) async {
      final h = await starte(tester);
      final tagDaten = verlauf(
        h,
      ).tage.firstWhere((t) => t.tag == tagOhneEssen);
      expect(tagDaten.gegessenKcal, isNull, reason: 'Vorbedingung');

      final geste = await halte(tester, tagOhneEssen);
      final gehalten = kopf(tester);

      expect(gehalten, contains(ohneWert));
      expect(
        gehalten,
        isNot(matches(nullAlsWert)),
        reason:
            '„nichts eingetragen" ist keine Aussage über das Essen — eine 0 '
            'behauptete eine',
      );
      expect(
        gehalten,
        contains('2.080'),
        reason: '#231: Der Verbrauch hängt nicht am Gegessenen',
      );

      await lass(tester, geste);
    });

    testWidgets('ein Tag ohne Verbrauch: Verbrauch –/–, gegessen steht', (
      tester,
    ) async {
      final h = await starte(tester);
      final tagDaten = verlauf(
        h,
      ).tage.firstWhere((t) => t.tag == tagOhneVerbrauch);
      expect(tagDaten.verbrauchKcal, isNull, reason: 'Vorbedingung');

      final geste = await halte(tester, tagOhneVerbrauch);
      final gehalten = kopf(tester);

      expect(gehalten, contains('1.300'), reason: 'gegessen');
      expect(gehalten, contains(ohneWert), reason: 'Verbrauch fehlt');
      expect(gehalten, isNot(matches(nullAlsWert)));
      expect(
        gehalten,
        isNot(contains('400')),
        reason: 'eine halbe Summe (nur aktiv) wäre eine falsche Zahl',
      );

      await lass(tester, geste);
    });
  });

  group('Übergänge (#378)', () {
    testWidgets('Loslassen springt zurück', (tester) async {
      await starte(tester);
      final ohneAuswahl = kopf(tester);

      final geste = await halte(tester, tagMitAllem);
      expect(kopf(tester), isNot(ohneAuswahl));

      await lass(tester, geste);
      expect(
        kopf(tester),
        ohneAuswahl,
        reason:
            'Eine Auswahl, die liegen bleibt, zeigt später eine einzelne '
            'Zahl, wo ein Durchschnitt stehen sollte',
      );
    });

    testWidgets('ein Tipp wählt nichts aus — gewählt wird durch Halten', (
      tester,
    ) async {
      await starte(tester);
      final ohneAuswahl = kopf(tester);

      await tester.tapAt(mitteVon(tester, tagMitAllem));
      await tester.pumpAndSettle();

      expect(
        kopf(tester),
        ohneAuswahl,
        reason: 'dieselbe Geste wie in den anderen Diagrammen: Halten',
      );
    });

    testWidgets('beim Halten bleibt der Verlauf gleich hoch', (tester) async {
      await starte(tester);
      final vorher = tester.getSize(
        find.byKey(const Key('ernaehrung-verlauf-diagramm')),
      );

      for (final tag in [tagMitAllem, tagOhneEssen, tagOhneVerbrauch]) {
        final geste = await halte(tester, tag);
        expect(
          tester
              .getSize(find.byKey(const Key('ernaehrung-verlauf-diagramm')))
              .height,
          vorher.height,
          reason:
              'Eine Anzeige, die es gibt, hat genau eine Form — die Details '
              'treten an die Stelle des Durchschnitts, nicht darunter ($tag)',
        );
        await lass(tester, geste);
      }
    });
  });
}
