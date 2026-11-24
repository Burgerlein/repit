import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repit/design/palette.dart';
import 'package:repit/design/ring_karte.dart';
import 'package:repit/design/segment_ring.dart';

import 'support.dart';

/// Tests für die Ringkarte des Erholung-Schirms: `RingSpalte`,
/// `RingKartenDaten`, `RingKarte`, `ErholungWert` und `ErholungRinge`
/// (Ticket #114, Spec `2026-10-26-erholung-flutter-design.md` Abschnitt 5,
/// Vorlage `Sources/Features/Recovery/RecoveryRings.swift`).
///
/// ## Die öffentliche API, die diese Datei festschreibt
///
/// ```dart
/// class RingSpalte {
///   const RingSpalte({
///     required List<RingAbschnitt> abschnitte,
///     required String mitte,     // „76", „2", „187" oder „—"
///     required String caption,   // „Score", „von 70", „Signale", „min", …
///     required String detail,    // „5:35 h", „Schlaf, HRV", „Woche · Ziel 210"
///   });
/// }
///
/// class RingKartenDaten {
///   const RingKartenDaten({
///     required RingSpalte schlaf,
///     required RingSpalte erholung,
///     required RingSpalte belastung,
///   });
/// }
///
/// class RingKarte extends StatelessWidget {
///   const RingKarte({
///     super.key,
///     required RingKartenDaten daten,
///     required VoidCallback onSchlaf,
///     required VoidCallback onErholung,
///     required VoidCallback onBelastung,
///     required VoidCallback onHilfe,
///   });
/// }
///
/// /// Die vier Werte der Ampel in der **Vertragsreihenfolge** (Spec 6).
/// enum ErholungWert { schlaf, ruhepuls, hrv, atemfrequenz }
/// extension ErholungWertName on ErholungWert { String get name; }
///
/// abstract final class ErholungRinge {
///   static RingSpalte schlaf({
///     required int gesamt,
///     required int punkteDauer,            // 0..50
///     required int? punkteZubettgehzeit,   // 0..30, null = keine Einschlafzeit
///     required int punkteUnterbrechungen,  // 0..20
///     required String dauer,               // „5:35 h"
///   });
///   static RingSpalte schlafOhneNacht();
///   static RingSpalte erholung({required List<ErholungWert> signale});
///   static RingSpalte erholungOhneWerte();
///   static RingSpalte erholungNachOp();
///   static RingSpalte belastung({
///     required double? wochenminuten,      // null = nichts aufgezeichnet
///     required double wochenziel,
///   });
/// }
/// ```
///
/// ### Warum der Schnitt so ist
///
/// **Die Karte bekommt ein fertiges Wertobjekt und ruft keinen Provider.**
/// `RingKarte` kennt weder Riverpod noch den Schnappschuss aus #112 — sie
/// bekommt `RingKartenDaten` und vier Rückrufe. Nur so ist sie ohne
/// Container testbar, und nur so entscheidet der Schirm (#115), auf welchen
/// Stapel die drei Türen schieben: Jeder Tab führt seinen eigenen Stapel,
/// die Karte darf das nicht wissen (CLAUDE.md).
///
/// **Drei Rückrufe statt eines Tür-Enums:** Die Karte hat genau drei
/// Spalten, fest benannt. Ein `onTuer(RingTuer)` wäre eine zweite Liste von
/// Fällen, die mit `RingKartenDaten` synchron bleiben müsste.
///
/// **`ErholungRinge` ist die Dart-Entsprechung von `enum RecoveryRings` in
/// Swift — „die Zahlen der drei Ringe, einmal an einer Stelle".** Die
/// Zustände, die #114 ausdrücklich geprüft haben will („von 70" statt
/// „Score", Signalzahl statt Prozent, leerer Ring, `noData`), sind
/// Entscheidungen über Text und Segmente, nicht über Pixel. Als reine
/// Funktionen sind sie ohne Widget prüfbar; stünden sie im Schirm, hinge
/// jeder dieser Tests an #112, #113 und einem Provider-Container.
///
/// **Primitive Parameter statt der Typen aus `trainings_core`:** #109
/// (Ampel, Verdikt) und #110 (Schlaf-Score) sind noch nicht gebaut. Diese
/// Datei schreibt ihre Namen deshalb **nicht** fest — sonst entschiede der
/// Test-Agent der Oberfläche über die Signatur der Rechenschicht. Die drei
/// Fälle des Erholungsrings sind aus demselben Grund drei benannte
/// Funktionen (`erholung`, `erholungOhneWerte`, `erholungNachOp`) und kein
/// nachgebautes Verdikt-Enum: #115 bildet die fünf Verdikte aus #109 auf
/// diese drei Darstellungen ab, und `calm`/`watch`/`stressed` sehen hier
/// gleich aus (so auch `RecoveryRings.recovery`, `default`-Zweig).
///
/// **Deutsche Nutzertexte stehen hier richtig:** `lib/design/` ist
/// Oberfläche. In `trainings_core` dürfen sie nicht stehen (CLAUDE.md).
///
/// Alle Zahlen sind erfunden.
void main() {
  group('ErholungRinge.schlaf — drei Segmente, 50/30/20', () {
    test('trägt drei Abschnitte mit den Anteilen 50/30/20', () {
      final spalte = ErholungRinge.schlaf(
        gesamt: 76,
        punkteDauer: 40,
        punkteZubettgehzeit: 21,
        punkteUnterbrechungen: 15,
        dauer: '6:12 h',
      );

      expect(spalte.abschnitte.length, 3);
      expect(spalte.abschnitte[0].anteil, closeTo(0.5, 1e-12));
      expect(spalte.abschnitte[1].anteil, closeTo(0.3, 1e-12));
      expect(spalte.abschnitte[2].anteil, closeTo(0.2, 1e-12));
    });

    test('füllt jedes Segment nach seiner eigenen Teilnote', () {
      final spalte = ErholungRinge.schlaf(
        gesamt: 76,
        punkteDauer: 40,
        punkteZubettgehzeit: 21,
        punkteUnterbrechungen: 15,
        dauer: '6:12 h',
      );

      expect(spalte.abschnitte[0].fuellung, closeTo(40 / 50, 1e-12));
      expect(spalte.abschnitte[1].fuellung, closeTo(21 / 30, 1e-12));
      expect(spalte.abschnitte[2].fuellung, closeTo(15 / 20, 1e-12));
    });

    test('zeigt den Score in der Mitte, die Caption "Score" und als Detail '
        'nur die Dauer', () {
      final spalte = ErholungRinge.schlaf(
        gesamt: 76,
        punkteDauer: 40,
        punkteZubettgehzeit: 21,
        punkteUnterbrechungen: 15,
        dauer: '6:12 h',
      );

      expect(spalte.mitte, '76');
      expect(spalte.caption, 'Score');
      expect(spalte.detail, '6:12 h');
    });

    // Ohne Zubettgehzeit sind nur 70 Punkte erreichbar. Steht da trotzdem
    // „Score", liest sich die Zahl als Note aus 100.
    test('ohne Zubettgehzeit heißt die Caption "von 70", nicht "Score"', () {
      final spalte = ErholungRinge.schlaf(
        gesamt: 48,
        punkteDauer: 31,
        punkteZubettgehzeit: null,
        punkteUnterbrechungen: 17,
        dauer: '5:35 h',
      );

      expect(spalte.caption, 'von 70');
      expect(spalte.mitte, '48');
    });

    // Die Aussage trägt allein die Caption. Rechnete der Ring auf 70 um,
    // sähe eine Nacht ohne Einschlafzeit besser aus als sie ist.
    test('ohne Zubettgehzeit bleibt das 30-%-Segment stehen und wird '
        'gestrichelt — der Ring normiert nicht auf 70 um', () {
      final spalte = ErholungRinge.schlaf(
        gesamt: 48,
        punkteDauer: 31,
        punkteZubettgehzeit: null,
        punkteUnterbrechungen: 17,
        dauer: '5:35 h',
      );

      expect(spalte.abschnitte.length, 3);
      expect(spalte.abschnitte[1].anteil, closeTo(0.3, 1e-12));
      expect(spalte.abschnitte[1].hatGrundlage, isFalse);
      expect(
        spalte.abschnitte.fold<double>(0, (summe, a) => summe + a.anteil),
        closeTo(1, 1e-12),
      );
      // Die beiden gemessenen Teile behalten ihre Grundlage.
      expect(spalte.abschnitte[0].hatGrundlage, isTrue);
      expect(spalte.abschnitte[2].hatGrundlage, isTrue);
    });

    test('ohne Nacht ein einziges graues Segment über den ganzen Kreis, '
        '"—" / "kein Wert" / "keine Nacht"', () {
      final spalte = ErholungRinge.schlafOhneNacht();

      expect(spalte.abschnitte.length, 1);
      expect(spalte.abschnitte.single.anteil, 1);
      expect(spalte.abschnitte.single.hatGrundlage, isFalse);
      expect(spalte.abschnitte.single.farbe, Palette.rest);
      expect(spalte.mitte, '—');
      expect(spalte.caption, 'kein Wert');
      expect(spalte.detail, 'keine Nacht');
    });
  });

  group('ErholungRinge.erholung — vier Viertel, keine Prozentzahl', () {
    test('teilt den Kreis in vier gleiche Viertel, eins je Wert', () {
      final spalte = ErholungRinge.erholung(signale: const []);

      expect(spalte.abschnitte.length, 4);
      for (final abschnitt in spalte.abschnitte) {
        expect(abschnitt.anteil, closeTo(0.25, 1e-12));
      }
    });

    // Vier Messwerte ergeben keine Note auf den Körper. Die Mitte zählt
    // Signale — „54 % erholt" wäre eine Diagnose, die niemand gestellt hat.
    test('die Mitte zählt die Signale, die Caption heißt "Signale" — nirgends '
        'eine Prozentzahl oder ein "von 4"', () {
      final spalte = ErholungRinge.erholung(
        signale: const [ErholungWert.schlaf, ErholungWert.hrv],
      );

      expect(spalte.mitte, '2');
      expect(spalte.caption, 'Signale');
      expect(spalte.caption, isNot(contains('%')));
      expect(spalte.caption, isNot(contains('von')));
      expect(spalte.mitte, isNot(contains('%')));
    });

    test('nennt im Detail die Namen der Signale, in der Vertragsreihenfolge', () {
      // Absichtlich in der falschen Reihenfolge übergeben: Die Darstellung
      // folgt der Vertragsreihenfolge Schlaf · Ruhepuls · HRV ·
      // Atemfrequenz, nicht der Reihenfolge des Aufrufers — sonst stünde
      // dasselbe Ergebnis je nach Aufrufweg anders da.
      final spalte = ErholungRinge.erholung(
        signale: const [ErholungWert.hrv, ErholungWert.schlaf],
      );

      expect(spalte.detail, 'Schlaf, HRV');
    });

    test('ohne Signal sagt das Detail "alles im Normalbereich"', () {
      final spalte = ErholungRinge.erholung(signale: const []);

      expect(spalte.mitte, '0');
      expect(spalte.detail, 'alles im Normalbereich');
    });

    test('färbt das Viertel eines Signals anders als eines im Normalbereich — '
        'und zwar an der Stelle, die der Vertragsreihenfolge entspricht', () {
      final spalte = ErholungRinge.erholung(signale: const [ErholungWert.hrv]);

      // Reihenfolge: 0 Schlaf · 1 Ruhepuls · 2 HRV · 3 Atemfrequenz.
      expect(spalte.abschnitte[2].farbe, Palette.bib);
      expect(spalte.abschnitte[0].farbe, Palette.ok);
      expect(spalte.abschnitte[1].farbe, Palette.ok);
      expect(spalte.abschnitte[3].farbe, Palette.ok);
    });

    test('gemessene Viertel sind voll und haben eine Grundlage', () {
      final spalte = ErholungRinge.erholung(signale: const [ErholungWert.ruhepuls]);

      for (final abschnitt in spalte.abschnitte) {
        expect(abschnitt.fuellung, 1);
        expect(abschnitt.hatGrundlage, isTrue);
      }
    });

    test('ohne Werte alle Viertel grau und ohne Grundlage, "—" / "keine '
        'Werte" / "Uhr prüfen"', () {
      final spalte = ErholungRinge.erholungOhneWerte();

      expect(spalte.abschnitte.length, 4);
      for (final abschnitt in spalte.abschnitte) {
        expect(abschnitt.farbe, Palette.rest);
        expect(abschnitt.hatGrundlage, isFalse);
        expect(abschnitt.fuellung, 0);
      }
      expect(spalte.mitte, '—');
      expect(spalte.caption, 'keine Werte');
      expect(spalte.detail, 'Uhr prüfen');
    });

    // Nach der OP ruht die Ampel. „Schlecht erholt" wäre nach einer
    // Operation keine Warnung, sondern der Normalfall — und eine Zahl, die
    // zum Trainieren verleitet.
    test('nach der OP ruht die Ampel: "pausiert" / "nach der OP", nicht '
        '"schlecht"', () {
      final spalte = ErholungRinge.erholungNachOp();

      expect(spalte.mitte, '—');
      expect(spalte.caption, 'pausiert');
      expect(spalte.detail, 'nach der OP');
      for (final abschnitt in spalte.abschnitte) {
        expect(abschnitt.farbe, Palette.rest);
        expect(abschnitt.hatGrundlage, isFalse);
      }
    });
  });

  group('ErholungRinge.belastung', () {
    test('ein Segment über den ganzen Kreis, gefüllt nach Wochenminuten '
        'durch Wochenziel', () {
      final spalte = ErholungRinge.belastung(wochenminuten: 105, wochenziel: 210);

      expect(spalte.abschnitte.length, 1);
      expect(spalte.abschnitte.single.anteil, 1);
      expect(spalte.abschnitte.single.fuellung, closeTo(0.5, 1e-12));
      expect(spalte.abschnitte.single.hatGrundlage, isTrue);
    });

    test('zeigt gerundete Minuten, die Caption "min" und das Ziel im Detail', () {
      final spalte = ErholungRinge.belastung(wochenminuten: 186.6, wochenziel: 210);

      expect(spalte.mitte, '187');
      expect(spalte.caption, 'min');
      expect(spalte.detail, 'Woche · Ziel 210');
    });

    test('teilt nicht durch null, wenn das Wochenziel 0 ist', () {
      final spalte = ErholungRinge.belastung(wochenminuten: 40, wochenziel: 0);

      expect(spalte.abschnitte.single.fuellung, 0);
      expect(spalte.abschnitte.single.fuellung.isFinite, isTrue);
      expect(spalte.mitte, '40');
    });

    // Eine gemessene Null ist eine Aussage: „diese Woche nichts trainiert".
    // Ohne Aufzeichnung gibt es diese Aussage nicht — „0 min" behauptete
    // sie trotzdem.
    test('ohne aufgezeichnete Minuten "—" und "nichts aufgezeichnet", nie '
        '"0 min"', () {
      final spalte = ErholungRinge.belastung(wochenminuten: null, wochenziel: 210);

      expect(spalte.mitte, '—');
      expect(spalte.mitte, isNot('0'));
      expect(spalte.detail, 'nichts aufgezeichnet');
      expect(spalte.abschnitte.single.hatGrundlage, isFalse);
      expect(spalte.abschnitte.single.fuellung, 0);
    });

    test('eine gemessene Null bleibt eine Null', () {
      final spalte = ErholungRinge.belastung(wochenminuten: 0, wochenziel: 210);

      expect(spalte.mitte, '0');
      expect(spalte.abschnitte.single.hatGrundlage, isTrue);
    });
  });

  group('RingKarte (Widget)', () {
    RingKartenDaten dreiSpalten() {
      return RingKartenDaten(
        schlaf: ErholungRinge.schlaf(
          gesamt: 48,
          punkteDauer: 31,
          punkteZubettgehzeit: null,
          punkteUnterbrechungen: 17,
          dauer: '5:35 h',
        ),
        erholung: ErholungRinge.erholung(
          signale: const [ErholungWert.schlaf, ErholungWert.hrv],
        ),
        belastung: ErholungRinge.belastung(wochenminuten: 105, wochenziel: 210),
      );
    }

    Future<void> pumpKarte(
      WidgetTester tester, {
      VoidCallback? onSchlaf,
      VoidCallback? onErholung,
      VoidCallback? onBelastung,
      VoidCallback? onHilfe,
    }) {
      return tester.pumpWidget(
        huelle(
          RingKarte(
            daten: dreiSpalten(),
            onSchlaf: onSchlaf ?? () {},
            onErholung: onErholung ?? () {},
            onBelastung: onBelastung ?? () {},
            onHilfe: onHilfe ?? () {},
          ),
        ),
      );
    }

    testWidgets('zeigt die Kopfzeile HEUTE und die drei Spaltenbeschriftungen', (
      tester,
    ) async {
      await pumpKarte(tester);

      expect(find.text('HEUTE'), findsOneWidget);
      expect(find.text('SCHLAF'), findsOneWidget);
      expect(find.text('ERHOLUNG'), findsOneWidget);
      expect(find.text('BELASTUNG'), findsOneWidget);
    });

    testWidgets('zeigt Mitte, Caption und Detail jeder Spalte', (tester) async {
      await pumpKarte(tester);

      expect(find.text('48'), findsOneWidget);
      expect(find.text('von 70'), findsOneWidget);
      expect(find.text('5:35 h'), findsOneWidget);

      expect(find.text('2'), findsOneWidget);
      expect(find.text('Signale'), findsOneWidget);
      expect(find.text('Schlaf, HRV'), findsOneWidget);

      expect(find.text('105'), findsOneWidget);
      expect(find.text('min'), findsOneWidget);
      expect(find.text('Woche · Ziel 210'), findsOneWidget);
    });

    testWidgets('zeichnet drei Ringe', (tester) async {
      await pumpKarte(tester);

      expect(find.byType(SegmentRing), findsNWidgets(3));
    });

    testWidgets('jede Spalte öffnet ihre eigene Tür', (tester) async {
      var schlaf = 0, erholung = 0, belastung = 0;
      await pumpKarte(
        tester,
        onSchlaf: () => schlaf++,
        onErholung: () => erholung++,
        onBelastung: () => belastung++,
      );

      await tester.tap(find.text('SCHLAF'));
      await tester.pump();
      expect([schlaf, erholung, belastung], [1, 0, 0]);

      await tester.tap(find.text('ERHOLUNG'));
      await tester.pump();
      expect([schlaf, erholung, belastung], [1, 1, 0]);

      await tester.tap(find.text('BELASTUNG'));
      await tester.pump();
      expect([schlaf, erholung, belastung], [1, 1, 1]);
    });

    testWidgets('das Fragezeichen öffnet das Hilfe-Blatt und keine Tür', (
      tester,
    ) async {
      var hilfe = 0, schlaf = 0;
      await pumpKarte(
        tester,
        onHilfe: () => hilfe++,
        onSchlaf: () => schlaf++,
      );

      await tester.tap(find.text('?'));
      await tester.pump();

      expect(hilfe, 1);
      expect(schlaf, 0);
    });

    testWidgets('das Fragezeichen trägt eine Beschriftung für VoiceOver — ein '
        '"?" allein wird vorgelesen wie ein Satzzeichen', (tester) async {
      final semantik = tester.ensureSemantics();
      await pumpKarte(tester);

      // Als RegExp, nicht als fester String: Ob die Beschriftung die des
      // Knopfes ersetzt oder das „?" mit einschließt, ist eine Frage der
      // Umsetzung, nicht des Verhaltens.
      expect(
        find.bySemanticsLabel(RegExp('Was die Ringe bedeuten')),
        findsOneWidget,
      );

      semantik.dispose();
    });

    // Ein gepushter Baustein bringt weder Navigator noch Gerüst mit — den
    // stellt der Gastgeber (CLAUDE.md). Zwei verschachtelte Stapel schließen
    // die gepushte Seite sofort wieder, und das fällt ohne UI-Tests nirgends
    // auf.
    testWidgets('bringt keinen eigenen Navigator und kein eigenes Gerüst mit', (
      tester,
    ) async {
      await pumpKarte(tester);

      expect(
        find.descendant(
          of: find.byType(RingKarte),
          matching: find.byType(Navigator),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(RingKarte),
          matching: find.byType(CupertinoPageScaffold),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(RingKarte),
          matching: find.byType(CupertinoNavigationBar),
        ),
        findsNothing,
      );
    });

    // Farbige Kanten an abgerundeten Karten werden mit der Karte
    // beschnitten, nicht selbst abgerundet: erst die Kante, dann der Clip
    // auf der ganzen Karte (CLAUDE.md) — in Flutter also ein `ClipRRect`
    // außen, wie in `InsetCard`.
    testWidgets('beschneidet die Karte außen mit einem ClipRRect', (tester) async {
      await pumpKarte(tester);

      expect(
        find.descendant(
          of: find.byType(RingKarte),
          matching: find.byType(ClipRRect),
        ),
        findsAtLeastNWidgets(1),
      );
    });
  });
}
