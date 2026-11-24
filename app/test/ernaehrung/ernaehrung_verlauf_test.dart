import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/core/messwert.dart';
import 'package:repit/data/ernaehrung_repository.dart';
import 'package:repit/ernaehrung/erfassen_provider.dart';
import 'package:repit/ernaehrung/ernaehrung_provider.dart';
import 'package:repit/ernaehrung/ernaehrung_verlauf.dart';
import 'package:repit/health/health_types.dart';

import 'tag_huelle.dart';

/// Tests für den **14-Tage-Verlauf** auf dem Ernährungs-Tag (#312, mit dem
/// Befund aus #231).
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden. Die
/// SQL-Summen darunter prüft `test/data/ernaehrung_tagessummen_test.dart`.
///
/// ## Was verlangt wird
///
/// SPEC 4.8 und das Ticket: 14 Tage, gegessen als Balken, Verbrauch als
/// Linie, Ziel je Tag als Strich — dazu die Zeile „Letzte 7 Tage: Ziel an
/// X von Y Tagen getroffen, Ø ±Z kcal", und sie stimmt mit der Bilanz
/// überein. Der Abschnitt bleibt eingeklappt und baut seinen Inhalt erst
/// beim Aufklappen (`ernaehrung_view_test.dart`).
///
/// ## Festgelegte API — Entscheidung des Test-Agenten, nicht von Tim
///
/// Neue Datei `lib/ernaehrung/ernaehrung_verlauf.dart`:
///
/// ```dart
/// /// Ein Tag des Verlaufs. Werttyp mit == und hashCode.
/// class VerlaufTag {
///   const VerlaufTag({required this.tag, this.gegessenKcal,
///       this.verbrauchKcal, this.zielKcal});
///   final String tag;            // ISO-Tagesschlüssel
///   final double? gegessenKcal;  // null: kein Eintrag an diesem Tag
///   final double? verbrauchKcal; // aktiv + Grundumsatz; null, wenn eins fehlt
///   final double? zielKcal;      // wie ernaehrungsTagProvider(tag).zielKcal
/// }
///
/// /// Die 14 Tage bis einschließlich des Endtags und die Siebentagezeile.
/// class ErnaehrungsVerlauf {
///   const ErnaehrungsVerlauf({required this.tage, required this.siebenTage});
///   final List<VerlaufTag> tage;   // 14, der älteste zuerst
///   final SiebenTage siebenTage;   // aus dem Kern
/// }
///
/// /// Gehalten, nicht je Zugriff gerechnet. Der Parameter ist der
/// /// **letzte** Tag des Fensters — der Schirm übergibt den offenen Tag.
/// final ernaehrungsVerlaufProvider =
///     Provider.family<ErnaehrungsVerlauf, String>(…);
/// ```
///
/// Im aufgeklappten Verlauf (`Key('ernaehrung-verlauf-inhalt')`):
///
/// - `Key('ernaehrung-verlauf-diagramm')` — das Diagramm, **in jedem
///   Zustand** (eine Anzeige, die es gibt, hat genau eine Form);
/// - `Key('ernaehrung-verlauf-sieben-tage')` — die Siebentagezeile.
///
/// ## Weitere Festlegungen des Test-Agenten — nicht von Tim freigegeben
///
/// - **Die Siebentagezeile zählt nur abgeschlossene Tage.** Endet das
///   Fenster heute, sind es die sieben Tage **vor** heute: Ein Tag, der
///   noch läuft, stünde mittags als „Ziel verfehlt" in der Quote. Endet es
///   an einem vergangenen Tag (über ‹ geblättert), sind es die letzten
///   sieben Tage des Fensters, dieser eingeschlossen.
/// - **Ein Tag ohne Eintrag trägt kein Gegessenes (`null`), keine 0.** An
///   einem vergangenen Tag ist „nichts eingetragen" keine Aussage über das
///   Essen; `SiebenTage` zählt ihn nicht mit, und das Diagramm zeichnet dort
///   keinen Balken der Höhe 0.
/// - **#231:** Ein Tag mit gemessenem Verbrauch, aber ohne Essen, behält
///   seinen Verbrauch. In der Altfassung (Zweig `implement-nutrition`, nie
///   in `main`) hing der Verbrauch am Balken des Gegessenen und verschwand
///   mit ihm. Die fehlende Legende aus #231 prüft diese Datei **nicht** —
///   sie ist Beschriftung.
/// - **Die Zeiträume `1M` und `3M`** aus dem Entwurf (`VERLAUF_DIAGRAMM`)
///   verlangt diese Datei nicht; das Ticket spricht nur von 14 Tagen.
///
/// **#230** (Verbrauchsspur hängt still am globalen Zeitfenster) prüft
/// diese Datei ebenfalls nicht: Der Befund betraf die Altfassung, und
/// solange `dataWindowProvider` unbegrenzt ist, fehlt kein Tag. Ob der
/// Verlauf sich vom Fenster lösen soll, ist eine Architekturfrage, keine
/// Testfrage.
///
/// Alle Zahlen erfunden.
void main() {
  // Freitag, 30.10.2026, 12:00 Berliner Zeit (MEZ, +1). Das Fenster läuft
  // vom 17.10. bis zum 30.10. und damit über das Ende der Sommerzeit am
  // 25.10.
  final jetzt = DateTime.utc(2026, 10, 30, 11);
  const heute = '2026-10-30';
  const gestern = '2026-10-29';

  final fenster = [
    for (var i = 13; i >= 0; i--)
      BerlinCalendar.dayKey(BerlinCalendar.addDays(jetzt, -i)),
  ];

  /// Ganztägig gemessen an jedem Tag außer dem 20.10. (kein Grundumsatz).
  final tageswerte = Bekannt<List<DailyMetrics>>(
    [
      for (final tag in fenster)
        if (tag == '2026-10-20')
          DailyMetrics(tag: tag, activeKcal: 400, weightKg: 80)
        else
          DailyMetrics(
            tag: tag,
            activeKcal: 500,
            basalKcal: 1600,
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

  /// Gebucht an elf der vierzehn Tage. Ohne Eintrag: der 18.10., der 22.10.
  /// (mit Verbrauch — #231) und heute.
  Future<void> bucheBestand(ErnaehrungRepository repo) async {
    for (final tag in fenster) {
      if (tag == '2026-10-18' || tag == '2026-10-22' || tag == heute) continue;
      await repo.buche(eintrag(tag, 1200));
      await repo.buche(eintrag(tag, tag.endsWith('4') ? 1600 : 900));
    }
  }

  Future<TagHuelle> starte(
    WidgetTester tester, {
    bool mitBestand = true,
    Messwert<List<DailyMetrics>>? werte,
  }) async {
    final h = tagHuelle(jetzt: jetzt, tageswerte: werte ?? tageswerte);
    if (mitBestand) await bucheBestand(ErnaehrungRepository(h.db));
    await zeigeTag(tester, h.app);
    return h;
  }

  ErnaehrungsVerlauf verlauf(TagHuelle h, String bis) {
    h.container.listen(ernaehrungsVerlaufProvider(bis), (_, _) {});
    return h.container.read(ernaehrungsVerlaufProvider(bis));
  }

  Future<ErnaehrungsVerlauf> verlaufFertig(
    WidgetTester tester,
    TagHuelle h,
    String bis,
  ) async {
    verlauf(h, bis);
    await tester.pumpAndSettle();
    return verlauf(h, bis);
  }

  group('Vierzehn Tage (#312)', () {
    testWidgets('es sind vierzehn, lückenlos, der älteste zuerst, der '
        'letzte ist der Endtag — auch über die Zeitumstellung', (tester) async {
      final h = await starte(tester);
      final v = await verlaufFertig(tester, h, heute);

      expect(v.tage.map((t) => t.tag), fenster);
      expect(v.tage.first.tag, '2026-10-17');
      expect(v.tage.last.tag, heute);
    });

    testWidgets('über ‹ geblättert endet das Fenster am offenen Tag', (
      tester,
    ) async {
      final h = await starte(tester);
      final v = await verlaufFertig(tester, h, '2026-10-25');
      expect(v.tage, hasLength(14));
      expect(v.tage.last.tag, '2026-10-25');
      expect(v.tage.first.tag, '2026-10-12');
    });

    testWidgets('gegessen ist die Summe der eigenen Einträge, ein Tag ohne '
        'Eintrag trägt null', (tester) async {
      final h = await starte(tester);
      final v = await verlaufFertig(tester, h, heute);
      final nachTag = {for (final t in v.tage) t.tag: t};

      expect(nachTag['2026-10-17']!.gegessenKcal, 2100);
      expect(nachTag['2026-10-24']!.gegessenKcal, 2800);
      for (final ohne in ['2026-10-18', '2026-10-22', heute]) {
        expect(
          nachTag[ohne]!.gegessenKcal,
          isNull,
          reason: '$ohne: nichts eingetragen ist nicht 0 kcal gegessen',
        );
      }
    });

    testWidgets('der Verbrauch ist aktiv plus Grundumsatz — und fehlt, wenn '
        'eins fehlt', (tester) async {
      final h = await starte(tester);
      final v = await verlaufFertig(tester, h, heute);
      final nachTag = {for (final t in v.tage) t.tag: t};

      expect(nachTag['2026-10-19']!.verbrauchKcal, 2100);
      expect(
        nachTag['2026-10-20']!.verbrauchKcal,
        isNull,
        reason: 'ohne Grundumsatz wäre eine halbe Summe eine falsche Zahl',
      );
    });

    testWidgets('#231: an einem Tag ohne Essen steht der Verbrauch trotzdem', (
      tester,
    ) async {
      final h = await starte(tester);
      final v = await verlaufFertig(tester, h, heute);
      final tag = v.tage.singleWhere((t) => t.tag == '2026-10-22');

      expect(tag.gegessenKcal, isNull);
      expect(
        tag.verbrauchKcal,
        2100,
        reason:
            'der Verbrauch hängt nicht am Balken des Gegessenen — ein Tag, '
            'an dem die Uhr gemessen hat, sieht sonst aus wie einer ohne '
            'Messung',
      );
    });

    testWidgets('das Ziel je Tag ist das Ziel des Tag-Schirms — heute der '
        'Planwert, sonst aus dem Verbrauch (#229)', (tester) async {
      final h = await starte(tester);
      final v = await verlaufFertig(tester, h, heute);

      for (final t in v.tage) {
        expect(
          t.zielKcal,
          h.container.read(ernaehrungsTagProvider(t.tag)).zielKcal,
          reason: '${t.tag}: eine zweite Zielrechnung liefe auseinander',
        );
      }
      expect(v.tage.last.zielKcal, isNotNull);
    });
  });

  group('Die Siebentagezeile stimmt mit der Bilanz (#312)', () {
    testWidgets('endet das Fenster heute: die sieben Tage vor heute', (
      tester,
    ) async {
      final h = await starte(tester);
      final v = await verlaufFertig(tester, h, heute);

      final abgeschlossen = v.tage.sublist(6, 13);
      expect(abgeschlossen.first.tag, '2026-10-23');
      expect(abgeschlossen.last.tag, gestern);
      expect(
        v.siebenTage,
        siebenTage([
          for (final t in abgeschlossen)
            (gegessen: t.gegessenKcal, ziel: t.zielKcal),
        ]),
      );
    });

    testWidgets('endet es an einem vergangenen Tag: die letzten sieben, '
        'dieser eingeschlossen', (tester) async {
      final h = await starte(tester);
      final v = await verlaufFertig(tester, h, '2026-10-25');

      final letzte = v.tage.sublist(7);
      expect(letzte.last.tag, '2026-10-25');
      expect(
        v.siebenTage,
        siebenTage([
          for (final t in letzte) (gegessen: t.gegessenKcal, ziel: t.zielKcal),
        ]),
      );
    });
  });

  group('Gehalten und aktuell', () {
    testWidgets('zweimal gelesen ist dieselbe Instanz', (tester) async {
      final h = await starte(tester);
      await verlaufFertig(tester, h, heute);
      expect(
        identical(verlauf(h, heute), verlauf(h, heute)),
        isTrue,
        reason: 'gehalten, nicht bei jedem Zugriff gerechnet (Fehler 03)',
      );
    });

    testWidgets('was gebucht wird, steht ohne Neustart im Verlauf', (
      tester,
    ) async {
      final h = await starte(tester);
      final vorher = await verlaufFertig(tester, h, heute);
      expect(vorher.tage.last.gegessenKcal, isNull);

      await h.container.read(erfassenProvider.notifier).bucheBestaetigt([
        eintrag(heute, 700),
      ]);
      await tester.pumpAndSettle();

      final nachher = verlauf(h, heute);
      expect(nachher.tage.last.gegessenKcal, 700);
    });
  });

  group('Der aufgeklappte Verlauf (#312)', () {
    Future<void> klappeAuf(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('ernaehrung-verlauf-kopf')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('ernaehrung-verlauf-inhalt')),
        findsOneWidget,
      );
    }

    testWidgets('zeigt das Diagramm und die Siebentagezeile, nicht mehr den '
        'Satz „kommt später"', (tester) async {
      final h = await starte(tester);
      await klappeAuf(tester);

      expect(
        find.byKey(const Key('ernaehrung-verlauf-diagramm')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('ernaehrung-verlauf-sieben-tage')),
        findsOneWidget,
      );
      expect(
        texteUnter(
          tester,
          const Key('ernaehrung-verlauf-inhalt'),
        ).toLowerCase(),
        isNot(contains('später')),
      );

      final sieben = verlauf(h, heute).siebenTage;
      expect(
        texteUnter(tester, const Key('ernaehrung-verlauf-sieben-tage')),
        contains('${sieben.getroffen} von ${sieben.tageMitWerten}'),
        reason: 'die Zeile sagt, was die Bilanz sagt',
      );
    });

    testWidgets('ohne jede Erfassung steht dieselbe Form da, ohne „0 von 0"', (
      tester,
    ) async {
      await starte(
        tester,
        mitBestand: false,
        werte: Bekannt<List<DailyMetrics>>(
          const [],
          stand: jetzt,
          laeuft: false,
        ),
      );
      await klappeAuf(tester);

      expect(
        find.byKey(const Key('ernaehrung-verlauf-diagramm')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('ernaehrung-verlauf-sieben-tage')),
        findsOneWidget,
      );
      expect(
        texteUnter(tester, const Key('ernaehrung-verlauf-sieben-tage')),
        isNot(contains('0 von 0')),
        reason:
            'ohne beurteilbaren Tag gibt es keine Quote — „0 von 0" '
            'behauptete eine',
      );
    });

    testWidgets('mit und ohne Werte ist der Verlauf gleich hoch', (
      tester,
    ) async {
      await starte(tester);
      await klappeAuf(tester);
      final mit = tester.getSize(
        find.byKey(const Key('ernaehrung-verlauf-diagramm')),
      );

      await tester.pumpWidget(const SizedBox());
      await starte(
        tester,
        mitBestand: false,
        werte: Bekannt<List<DailyMetrics>>(
          const [],
          stand: jetzt,
          laeuft: false,
        ),
      );
      await klappeAuf(tester);
      final ohne = tester.getSize(
        find.byKey(const Key('ernaehrung-verlauf-diagramm')),
      );

      expect(
        ohne.height,
        mit.height,
        reason:
            'eine Anzeige, die es gibt, hat genau eine Form — sonst '
            'springt alles darunter, sobald Werte eintreffen',
      );
    });
  });
}
