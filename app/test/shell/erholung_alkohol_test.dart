import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';
import 'package:repit/core/messwert.dart';
import 'package:repit/data/ziele.dart';
import 'package:repit/design/vital_ton.dart';
import 'package:repit/health/health_types.dart';
import 'package:repit/shell/erholung_abschnitte.dart';
import 'package:repit/shell/erholung_zustand.dart';
import 'package:repit/shell/verlauf_zustand.dart';

/// Die Alkohol-Zeile beantwortet seit #268 eine andere Frage: **ob am
/// Vortag des gezeigten Tages Alkohol erfasst ist** — nicht, wann zuletzt
/// einer war.
///
/// Tim am 03.11.2026: „wenn ich den Schirm heute angucke, steht da, ob ich
/// gestern getrunken habe. Das ist das, was ich wissen will — nicht wann
/// zuletzt." Alkohol drückt die Erholung der folgenden Nacht; „zuletzt am
/// 2. November" sagt über die Nacht auf den 28. Oktober nichts. Nebenbei
/// verschwindet damit der Widerspruch aus #261: Das alte Datum wanderte
/// beim Blättern nicht mit, der Vortag muss es.
///
/// Diese Datei prüft die beiden Stellen, an denen die Zeile entsteht:
///
/// 1. **Der Zustand** — `erholungZustandAus` reicht beides aus den
///    Tageswerten in die Kernrechnung: die Tage **mit** Alkohol und die
///    Tage mit einer gemessenen **Null**. Ohne die zweite Liste gäbe es
///    kein belegtes „nein".
/// 2. **Die Zeile** — `ErholungVerlaeufe` zeigt die Auskunft rechts und
///    die Zahl der Alkohol-Tage im Zeitraum darunter.
///
/// ## Drei Zustände, nicht zwei
///
/// „Nein" und „nicht erfasst" sind zwei verschiedene Dinge. Ein „nein",
/// das in Wahrheit „keine Daten" heißt, wäre Fehler `01` in klein — die
/// Zeile zeigt deshalb `Ja`, `Nein` und „kein Wert" als drei
/// unterscheidbare Dinge. **„Nein" steht nur bei einer gemessenen Null.**
/// Apple Health legt für alkoholische Getränke nur dann eine Probe an,
/// wenn etwas getrunken wurde, und eine fehlende Freigabe sieht genauso
/// aus; der Normalfall ist deshalb „kein Wert", und das ist die ehrliche
/// Auskunft.
///
/// ## Was die Zeile weiterhin nicht darf
///
/// **Keine 0 als Zahl der Alkohol-Tage.** „0 Alkohol-Tage" wäre eine
/// Behauptung über Tims Verhalten, und sie kann allein an der fehlenden
/// Freigabe liegen. Ohne Alkohol-Tag nennt die Zeile beide Möglichkeiten.
///
/// **Keine Bewertung.** Die Zeile stellt einen Zusammenhang her, sie
/// bewertet nicht — keine Ampelfarbe, kein Richtwert, kein „deshalb ist
/// deine HRV niedrig". Das wäre eine Diagnose.
///
/// **Keine Tür.** `verlaufArtZu(RecoveryTrendKind.alcoholDays)` liefert
/// weiter `null`: Ein Verlaufs-Schirm zeigt den Verlauf eines Messwerts,
/// und eine Ja/Nein-Auskunft ist keiner.
///
/// Alle Zahlen und Tage sind erfunden.
void main() {
  // Montag, 12.10.2026, 09:15 Berliner Zeit (CEST, +2) — derselbe Bezugstag
  // wie in `erholung_view_test.dart`, damit beide Dateien über dieselben
  // Tage reden. Der Vortag ist damit Sonntag, der 11.10.2026.
  final jetzt = DateTime.utc(2026, 10, 12, 7, 15);

  String tagKey(int tag) => '2026-10-${tag.toString().padLeft(2, '0')}';

  DailyMetrics tagwert(int tag, {double? getraenke}) =>
      DailyMetrics(tag: tagKey(tag), restingHR: 52, alcoholicDrinks: getraenke);

  /// Der Zustand aus einer Handvoll Tageswerten. Nächte bleiben leer — für
  /// die Alkohol-Zeile spielen sie keine Rolle.
  ErholungZustand zustand(List<DailyMetrics> tage) => erholungZustandAus(
    tageswerte: Bekannt<List<DailyMetrics>>(tage, stand: jetzt, laeuft: false),
    naechte: LeerNachLauf<List<SleepNight>>(gelaufen: jetzt),
    ziele: Ziele.vorbelegung,
    fenster: DataWindow.unlimited,
    jetzt: jetzt,
  );

  RecoverySnapshot schnappschussVon(List<DailyMetrics> tage) {
    final daten = zustand(tage).daten;
    return (daten as Bekannt<ErholungDaten>).wert.schnappschuss;
  }

  RecoveryTrend alkoholZeile(RecoverySnapshot s) =>
      s.trends.firstWhere((t) => t.kind == RecoveryTrendKind.alcoholDays);

  group('Der Zustand liest Alkohol-Tage und gemessene Nullen', () {
    test('ein Tag mit Getränken wird gezählt', () {
      final s = schnappschussVon([
        tagwert(9),
        tagwert(10, getraenke: 2),
        tagwert(11),
      ]);

      expect(alkoholZeile(s).count, 1);
    });

    test('mehrere Tage werden gezählt', () {
      final s = schnappschussVon([
        tagwert(8, getraenke: 1),
        tagwert(9),
        tagwert(10, getraenke: 3),
        tagwert(11),
      ]);

      expect(alkoholZeile(s).count, 2);
    });

    test('ein Tag mit gemessener 0 zählt nicht als Alkohol-Tag', () {
      final s = schnappschussVon([tagwert(10, getraenke: 0)]);

      expect(alkoholZeile(s).count, 0);
    });

    test('Getränke am Vortag heißen „ja"', () {
      final s = schnappschussVon([tagwert(11, getraenke: 2), tagwert(12)]);

      expect(s.alcoholEve, AlcoholEve.drinks);
    });

    test('eine gemessene Null am Vortag heißt „nein"', () {
      final s = schnappschussVon([tagwert(11, getraenke: 0), tagwert(12)]);

      expect(
        s.alcoholEve,
        AlcoholEve.noDrinks,
        reason:
            'ohne die zweite Liste käme hier „kein Wert" heraus, und ein '
            'belegtes Nein wäre nicht mehr ausdrückbar',
      );
    });

    test('ein Vortag ohne Alkoholwert beweist nichts', () {
      final s = schnappschussVon([tagwert(9), tagwert(10), tagwert(11)]);

      expect(s.alcoholEve, AlcoholEve.unknown);
    });

    test('Getränke am gezeigten Tag sagen nichts über den Vortag', () {
      final s = schnappschussVon([tagwert(11), tagwert(12, getraenke: 3)]);

      expect(alkoholZeile(s).count, 1);
      expect(
        s.alcoholEve,
        AlcoholEve.unknown,
        reason: 'Alkohol drückt die Erholung der folgenden Nacht',
      );
    });

    test('die Zeile trägt weiterhin keinen Durchschnitt', () {
      final s = schnappschussVon([tagwert(10, getraenke: 2)]);

      expect(
        alkoholZeile(s).average,
        isNull,
        reason: 'ein Schnitt über Ja/Nein ist keine Zahl, die jemand liest',
      );
    });

    test('ohne Tageswerte bleibt alles leer, ohne zu werfen', () {
      final s = schnappschussVon([]);

      expect(alkoholZeile(s).count, 0);
      expect(s.alcoholEve, AlcoholEve.unknown);
    });
  });

  group('Die Zeile zeigt den Vortag und die Zahl im Zeitraum', () {
    /// Nur die Alkohol-Zeile, für sich gepumpt — der Vertrag des Bausteins
    /// gilt unabhängig davon, wer ihn einsetzt.
    Widget abschnitt({required int anzahl, required AlcoholEve vortag}) =>
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: SingleChildScrollView(
              child: ErholungVerlaeufe(
                trends: [
                  RecoveryTrend(
                    kind: RecoveryTrendKind.alcoholDays,
                    average: null,
                    count: anzahl,
                  ),
                ],
                messwerte: const RecoveryReading(),
                baseline: const RecoveryBaseline(),
                alkoholVortag: vortag,
                onVerlauf: (_) {},
              ),
            ),
          ),
        );

    ErholungVerlaufsZeile zeile(WidgetTester tester) => tester
        .widget<ErholungVerlaufsZeile>(find.byType(ErholungVerlaufsZeile));

    testWidgets('mit Alkohol am Vortag steht rechts „Ja"', (tester) async {
      await tester.pumpWidget(abschnitt(anzahl: 2, vortag: AlcoholEve.drinks));

      expect(zeile(tester).wert, 'Ja');
    });

    testWidgets('mit gemessener Null steht dort „Nein"', (tester) async {
      await tester.pumpWidget(
        abschnitt(anzahl: 2, vortag: AlcoholEve.noDrinks),
      );

      expect(zeile(tester).wert, 'Nein');
    });

    testWidgets('ohne Angabe steht dort weder Ja noch Nein', (tester) async {
      await tester.pumpWidget(abschnitt(anzahl: 2, vortag: AlcoholEve.unknown));

      expect(zeile(tester).wert, keinWert);
      expect(find.text('Nein'), findsNothing);
      expect(find.text('Ja'), findsNothing);
    });

    testWidgets('die drei Zustände sind drei verschiedene Anzeigen', (
      tester,
    ) async {
      final gesehen = <String?>[];
      for (final zustand in AlcoholEve.values) {
        await tester.pumpWidget(abschnitt(anzahl: 2, vortag: zustand));
        gesehen.add(zeile(tester).wert);
      }

      expect(
        gesehen.toSet(),
        hasLength(AlcoholEve.values.length),
        reason:
            'ein „nein", das in Wahrheit „keine Daten" heißt, ist Fehler 01 '
            'in klein',
      );
    });

    testWidgets('die Zeile nennt den Vortag im Titel', (tester) async {
      await tester.pumpWidget(abschnitt(anzahl: 2, vortag: AlcoholEve.drinks));

      expect(zeile(tester).titel.toLowerCase(), contains('vortag'));
    });

    testWidgets('„zuletzt am" steht nirgends mehr', (tester) async {
      await tester.pumpWidget(abschnitt(anzahl: 2, vortag: AlcoholEve.drinks));

      expect(find.textContaining('zuletzt'), findsNothing);
    });

    testWidgets('darunter steht die Zahl der Alkohol-Tage im Zeitraum', (
      tester,
    ) async {
      await tester.pumpWidget(abschnitt(anzahl: 2, vortag: AlcoholEve.drinks));

      final detail = zeile(tester).detail;
      expect(detail, contains('2'));
      expect(detail.toLowerCase(), contains('zeitraum'));
    });

    testWidgets('ein einzelner Tag steht in der Einzahl', (tester) async {
      await tester.pumpWidget(abschnitt(anzahl: 1, vortag: AlcoholEve.drinks));

      expect(zeile(tester).detail, contains('1 Alkohol-Tag '));
    });

    testWidgets('ohne Alkohol-Tag steht dort keine 0', (tester) async {
      await tester.pumpWidget(abschnitt(anzahl: 0, vortag: AlcoholEve.unknown));

      expect(
        zeile(tester).detail,
        isNot(contains('0')),
        reason:
            '„0 Alkohol-Tage" waere eine Behauptung ueber das Verhalten des '
            'Nutzers, und sie kann allein an einer fehlenden Freigabe liegen',
      );
    });

    testWidgets('ohne Alkohol-Tag nennt die Zeile beide Möglichkeiten', (
      tester,
    ) async {
      await tester.pumpWidget(abschnitt(anzahl: 0, vortag: AlcoholEve.unknown));

      final detail = zeile(tester).detail.toLowerCase();
      expect(detail, contains('keine daten'), reason: 'die eine Moeglichkeit');
      expect(
        detail,
        contains('freigegeben'),
        reason: 'die andere — Apple verraet nicht, welche zutrifft',
      );
    });

    testWidgets('„trägst du selbst ein" steht nirgends mehr', (tester) async {
      await tester.pumpWidget(abschnitt(anzahl: 2, vortag: AlcoholEve.drinks));

      expect(find.textContaining('trägst du'), findsNothing);
    });

    testWidgets('die Zeile bekommt keine Farbe, auch mit „Ja"', (tester) async {
      await tester.pumpWidget(abschnitt(anzahl: 3, vortag: AlcoholEve.drinks));

      expect(
        zeile(tester).ton,
        VitalTon.unbeurteilt,
        reason: 'die Zeile stellt einen Zusammenhang her, sie bewertet nicht',
      );
    });

    testWidgets('und sie bleibt eine Nicht-Tür', (tester) async {
      await tester.pumpWidget(abschnitt(anzahl: 3, vortag: AlcoholEve.drinks));

      expect(zeile(tester).onTap, isNull);
      expect(
        find.byWidgetPredicate(
          (w) => w is Icon && w.icon == CupertinoIcons.chevron_right,
        ),
        findsNothing,
        reason:
            'eine Zeile, die drueckbar aussieht und nirgendwohin fuehrt, ist '
            'ein Fehler',
      );
    });

    test('die Entscheidung darüber steht weiter an einer Stelle', () {
      expect(
        verlaufArtZu(RecoveryTrendKind.alcoholDays),
        isNull,
        reason:
            'ein Verlaufs-Schirm zeigt den Verlauf eines Messwerts; eine '
            'Ja/Nein-Auskunft ist keiner',
      );
    });
  });
}
