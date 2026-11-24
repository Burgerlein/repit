import 'package:flutter/widgets.dart' show Key;
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/design/platzhalter.dart' show ohneWert;
import 'package:repit/design/zeitdiagramm.dart';
import 'package:repit/gym/gym_vorschlag_texte.dart';
import 'package:repit/shell/diagramm_zeitraum.dart';

import 'gym_fortschritt_support.dart';

/// Widget-Tests für das, was der Schirm „Fortschritt pro Übung" (#93) über
/// den **Verlauf** sagt: Monatsmaximum statt Mittel, Kopfkachel gleich
/// Linienende, Plateau, Unterstützung, Zeitübungen.
///
/// Grundlage: `docs/superpowers/specs/2026-11-11-gym-fortschritt-design.md`,
/// Abschnitte 4, 5 und 7; `docs/SPEC.md` 4.4 (Z. 154: Monatsmaximum, Kopfkachel
/// = Linie). Die API und die Schlüssel stehen im Kopf von
/// `gym_fortschritt_support.dart`; die Rechnung selbst im Kern
/// (`exercise_progress_test.dart`, `chart_buckets_maximum_test.dart`).
///
/// ## Der Fall, der in diesem Ticket ausdrücklich steht
///
/// Board-Nr. **18**: Der Gewichtsverlauf rechnete auf das Monats**mittel**
/// statt auf das Monats**maximum**. 60 kg am 2. und 70 kg am 28. standen bei
/// 65 — einem Gewicht, das nie auf der Stange lag. Am 26.10.2026
/// entschieden, und hier mit **einem Fall, der beides unterscheidet**, an
/// den Schirm genagelt: Wer mittelt, baut den Fehler neu ein.
///
/// ## Wie ein Widget-Test das überhaupt sehen kann
///
/// Das Diagramm ist ein `CustomPaint`; seine Linie ist im Test nicht lesbar.
/// Zwei Dinge sind es: **was dem Bauteil übergeben wird** (`verdichtung`,
/// `reihe`, `zweiteReihe`) und **was die Kacheln nennen** — und die sollen
/// laut Ticket dieselbe Zahl sein wie das Ende der Linie. Die Verdichtung
/// selbst ist im Kern geprüft.
///
/// Alle Daten sind erfunden.
void main() {
  final bankUebung = ExerciseCatalog.all[idBank]!;
  final dipsUebung = ExerciseCatalog.all[idDips]!;

  /// 60 kg am 2., 70 kg am 28. — **ein** Monat, zwei Werte, die sich im
  /// Mittel (65) vom Maximum (70) unterscheiden. 1RM: 80,0 und 84,0.
  List<ImportedSession> mittelOderMaximum() => [
    bank('S1', morgens(3, 2), 60, 10),
    bank('S2', morgens(3, 28), 70, 6),
  ];

  /// Das Gegenstück: das Maximum liegt am **Anfang** des Monats, am Ende
  /// wurde leichter trainiert. 70 am 2. (1RM 84,0), 60 am 28. (1RM 80,0).
  List<ImportedSession> maximumAmAnfang() => [
    bank('S1', morgens(3, 2), 70, 6),
    bank('S2', morgens(3, 28), 60, 10),
  ];

  group('Monatsmaximum, nicht Monatsmittel (Board-Nr. 18)', () {
    testWidgets('das Diagramm bekommt die Verdichtung „Maximum"', (
      tester,
    ) async {
      final h = fortschrittHuelle();
      await h.lege(mittelOderMaximum());
      await zeigeFortschritt(tester, h);

      expect(
        diagramm(tester).verdichtung,
        ChartAggregation.max,
        reason:
            'Eine Reihe, die „Höchstgewicht" heißt, darf nicht den '
            'Durchschnitt der Höchstgewichte zeigen — 65 lag nie auf der '
            'Stange (`docs/SPEC.md` 4.4)',
      );
    });

    testWidgets('die Kachel nennt in der Halbjahresstufe 70 kg, nicht 65', (
      tester,
    ) async {
      final h = fortschrittHuelle();
      await h.lege(mittelOderMaximum());
      await zeigeFortschritt(tester, h);

      await waehleStufe(tester, DiagrammStufe.halbjahr);

      expect(
        kachelWert(tester, kFWertHoechst),
        vorschlagGewichtText(70, bankUebung),
        reason: 'Der Monat hat ein Maximum, und das ist 70',
      );
      final einRm = kachelWert(tester, kFWert1rm);
      expect(
        einRm,
        contains(gymZahlText(84)),
        reason: 'Dasselbe gilt für die gestrichelte 1RM-Linie',
      );
      expect(
        einRm,
        isNot(contains(gymZahlText(82))),
        reason: '82 wäre das Mittel von 80,0 und 84,0',
      );
    });

    testWidgets('dasselbe in der Jahresstufe', (tester) async {
      final h = fortschrittHuelle();
      await h.lege(mittelOderMaximum());
      await zeigeFortschritt(tester, h);

      await waehleStufe(tester, DiagrammStufe.jahr);

      expect(
        kachelWert(tester, kFWertHoechst),
        vorschlagGewichtText(70, bankUebung),
      );
    });

    testWidgets('die Kopfzeile des Diagramms zeigt über diesem einen Monat '
        'nicht 65', (tester) async {
      final h = fortschrittHuelle();
      await h.lege(mittelOderMaximum());
      await zeigeFortschritt(tester, h);

      await waehleStufe(tester, DiagrammStufe.halbjahr);

      final kopf = textVon(tester, const Key('diagramm-kopfzeile'));
      expect(kopf, contains('70'));
      expect(
        kopf,
        isNot(contains('65')),
        reason:
            'Mit einem Punkt im Fenster ist jede Kopfzahl dieser Punkt — '
            'steht dort 65, wurde der Monat gemittelt',
      );
    });

    testWidgets('dem Diagramm gehen die rohen Tageswerte hinein — es '
        'verdichtet selbst, nicht der Schirm', (tester) async {
      final h = fortschrittHuelle();
      await h.lege(mittelOderMaximum());
      await zeigeFortschritt(tester, h);

      expect(
        alsTage(diagramm(tester).reihe),
        [('2026-03-02', 60.0), ('2026-03-28', 70.0)],
        reason:
            'Zwei Fassungen derselben Verdichtung — eine im Schirm, eine im '
            'Bauteil — laufen beim nächsten Umbau auseinander (Entscheidung '
            'vom 02.11.2026 bei `messung_detail_zustand.dart`)',
      );
      expect(
        alsTage(diagramm(tester).zweiteReihe),
        [('2026-03-02', 80.0), ('2026-03-28', 84.0)],
        reason:
            'Die gestrichelte Linie ist das geschätzte 1RM, je Tag das '
            'beste',
      );
    });
  });

  group('Kopfkachel und Linie nennen dieselbe Zahl', () {
    testWidgets('die Kachel folgt der gezeigten Stufe: je Training in `M`, '
        'je Monatsmaximum in `6M` und `J`', (tester) async {
      final h = fortschrittHuelle();
      await h.lege(maximumAmAnfang());
      await zeigeFortschritt(tester, h);

      expect(leiste(tester).gewaehlt, DiagrammStufe.monat);
      expect(
        kachelWert(tester, kFWertHoechst),
        vorschlagGewichtText(60, bankUebung),
        reason:
            'In `M` ist das Ende der Linie das letzte Training: 60 kg am '
            '28. Die Kacheln nahmen früher den unverdichteten letzten '
            'Punkt, die Linie den verdichteten (`docs/SPEC.md` 4.4)',
      );
      expect(kachelWert(tester, kFWert1rm), contains(gymZahlText(80)));

      await waehleStufe(tester, DiagrammStufe.halbjahr);
      expect(
        kachelWert(tester, kFWertHoechst),
        vorschlagGewichtText(70, bankUebung),
        reason: 'In `6M` endet die Linie auf dem Maximum des Monats: 70 kg',
      );
      expect(kachelWert(tester, kFWert1rm), contains(gymZahlText(84)));

      await waehleStufe(tester, DiagrammStufe.jahr);
      expect(
        kachelWert(tester, kFWertHoechst),
        vorschlagGewichtText(70, bankUebung),
      );

      await waehleStufe(tester, DiagrammStufe.monat);
      expect(
        kachelWert(tester, kFWertHoechst),
        vorschlagGewichtText(60, bankUebung),
        reason: 'Und zurück: derselbe Wert wie zuvor in `M`',
      );
    });

    testWidgets('beim Wechsel der Stufe steht nie ein Platzhalter oder ein '
        'Leerzustand', (tester) async {
      final h = fortschrittHuelle();
      await h.lege(maximumAmAnfang());
      await zeigeFortschritt(tester, h);

      for (final stufe in [
        DiagrammStufe.halbjahr,
        DiagrammStufe.jahr,
        DiagrammStufe.woche,
        DiagrammStufe.monat,
      ]) {
        await waehleStufe(tester, stufe);
        expect(
          kachelWert(tester, kFWertHoechst),
          isNotEmpty,
          reason: '$stufe: Die Kachel trägt einen Wert, keine graue Form',
        );
        expect(kachelWert(tester, kFWertHoechst), isNot(ohneWert));
        expect(find.byKey(kFDiagrammLeer), findsNothing, reason: '$stufe');
      }
    });
  });

  group('Plateau — eine Beobachtung, keine Diagnose', () {
    testWidgets('vier Trainings ohne Anstieg des geschätzten 1RM: der '
        'Hinweiskasten nennt es', (tester) async {
      final h = fortschrittHuelle();
      await h.lege([
        for (var i = 0; i < 4; i++) bank('S$i', morgens(2, 9 + 7 * i), 60, 10),
      ]);
      await zeigeFortschritt(tester, h);

      expect(
        find.descendant(
          of: find.byKey(kFHinweis),
          matching: find.byKey(kFPlateau),
        ),
        findsOneWidget,
      );
      expect(find.byKey(kFHinweis), findsOneWidget);
    });

    testWidgets('bei erkanntem Plateau steht dort **nicht zugleich** der '
        'Steigerungsvorschlag', (tester) async {
      final h = fortschrittHuelle();
      // Alle Sätze an der oberen Grenze: ohne Plateau stünde hier „Steigern".
      await h.lege([
        for (var i = 0; i < 4; i++) bank('S$i', morgens(2, 9 + 7 * i), 60, 10),
      ]);
      await zeigeFortschritt(tester, h);

      final vorschlag = vorschlagKurzText(
        const Increase(toWeight: 62.5, by: 2.5, targetReps: 6),
        bankUebung,
        hatVerlauf: true,
      );
      expect(
        textVon(tester, kFHinweis),
        isNot(contains(vorschlag)),
        reason:
            'Ein Kasten, eine Auskunft: Das Plateau ersetzt den Vorschlag '
            '(Entwurf, Variante „Plateau erkannt")',
      );
    });

    testWidgets('drei gleiche Trainings sind keins — der Kasten bleibt da '
        'und trägt den Vorschlag', (tester) async {
      final h = fortschrittHuelle();
      await h.lege([
        for (var i = 0; i < 3; i++) bank('S$i', morgens(2, 16 + 7 * i), 60, 10),
      ]);
      await zeigeFortschritt(tester, h);

      expect(find.byKey(kFPlateau), findsNothing);
      expect(find.byKey(kFHinweis), findsOneWidget);
      expect(
        textVon(tester, kFHinweis),
        contains(
          vorschlagKurzText(
            const Increase(toWeight: 62.5, by: 2.5, targetReps: 6),
            bankUebung,
            hatVerlauf: true,
          ),
        ),
      );
    });

    testWidgets('steigt das 1RM, gibt es kein Plateau', (tester) async {
      final h = fortschrittHuelle();
      await h.lege([
        bank('S0', morgens(2, 9), 57.5, 10),
        bank('S1', morgens(2, 16), 60, 10),
        bank('S2', morgens(2, 23), 62.5, 10),
        bank('S3', morgens(3, 2), 65, 10),
      ]);
      await zeigeFortschritt(tester, h);

      expect(find.byKey(kFPlateau), findsNothing);
    });

    testWidgets('das Plateau nennt keinen Gesundheitsbefund', (tester) async {
      final h = fortschrittHuelle();
      await h.lege([
        for (var i = 0; i < 4; i++) bank('S$i', morgens(2, 9 + 7 * i), 60, 10),
      ]);
      await zeigeFortschritt(tester, h);

      expect(
        textVon(tester, kFPlateau).toLowerCase(),
        isNot(
          matches(
            RegExp(
              r'verletz|überlast|übertrain|krank|diagnos|schmerz|\bop\b|operation',
            ),
          ),
        ),
        reason:
            '`CLAUDE.md`, „Keine Diagnosen": Das Plateau ist eine '
            'Beobachtung aus den eigenen Einträgen. Was sie bedeutet, sagt '
            'der Schirm nicht',
      );
    });
  });

  group('Unterstützte Sätze (Dips mit Hilfe)', () {
    /// −27, −24,5, −24,5 — von Training zu Training weniger Hilfe.
    List<ImportedSession> mitHilfe() => [
      sitzung('S1', morgens(3, 2), {
        idDips: [(-27, 8), (-27, 7)],
      }),
      sitzung('S2', morgens(3, 5), {
        idDips: [(-24.5, 8), (-24.5, 6)],
      }),
      sitzung('S3', morgens(3, 9), {
        idDips: [(-24.5, 9)],
      }),
    ];

    testWidgets('die Höchstgewicht-Kachel nennt die Hilfe, das 1RM sagt „kein '
        'Wert"', (tester) async {
      final h = fortschrittHuelle(uebungId: idDips);
      await h.lege(mitHilfe());
      await zeigeFortschritt(tester, h);

      expect(
        kachelWert(tester, kFWertHoechst),
        vorschlagGewichtText(-24.5, dipsUebung),
        reason:
            'Dieselbe Schreibweise wie überall auf dem Gym-Schirm: '
            '„24,5 kg Unterstützung", nicht „−24,5 kg"',
      );
      expect(
        kachelWert(tester, kFWert1rm),
        ohneWert,
        reason:
            'Epley gibt für Unterstützung `null` — die Kachel bleibt stehen '
            'und sagt es, sie verschwindet nicht und zeigt keine 0',
      );
    });

    testWidgets('der Schirm fällt nicht aus: Linie da, und der Grund steht '
        'einmal im Schirm', (tester) async {
      final h = fortschrittHuelle(uebungId: idDips);
      await h.lege(mitHilfe());
      await zeigeFortschritt(tester, h);

      expect(find.byType(Zeitdiagramm), findsOneWidget);
      expect(
        alsTage(diagramm(tester).reihe),
        [('2026-03-02', -27.0), ('2026-03-05', -24.5), ('2026-03-09', -24.5)],
        reason:
            'Die Höchstgewicht-Linie läuft über die Hilfe: weniger Hilfe '
            'steigt',
      );
      expect(
        diagramm(tester).zweiteReihe,
        isEmpty,
        reason: 'Ein 1RM gibt es nicht — keine gestrichelte Linie aus Nullen',
      );
      expect(find.byKey(kFUnterstuetzung), findsOneWidget);
    });

    testWidgets('ein Training mit Zusatzgewicht hat ein 1RM, die Trainings '
        'davor nicht — die Lücke bleibt eine Lücke', (tester) async {
      final h = fortschrittHuelle(uebungId: idDips);
      await h.lege([
        sitzung('S1', morgens(3, 2), {
          idDips: [(-10, 8)],
        }),
        sitzung('S2', morgens(3, 5), {
          idDips: [(5, 8)],
        }),
      ]);
      await zeigeFortschritt(tester, h);

      expect(alsTage(diagramm(tester).zweiteReihe), [('2026-03-05', 6.3)]);
      expect(
        diagramm(tester).zweiteReihe.any((p) => p.wert == 0),
        isFalse,
        reason: 'Eine Lücke ist keine 0 (Fehler `01`, eine Ebene tiefer)',
      );
    });

    testWidgets('der Hinweis zur Unterstützung hängt an der Übung, nicht an '
        'den Daten: da bei Dips, weg beim Bankdrücken', (tester) async {
      for (final (id, erwartet) in [(idDips, true), (idBank, false)]) {
        final h = fortschrittHuelle(uebungId: id);
        await zeigeFortschritt(tester, h);

        expect(
          find.byKey(kFUnterstuetzung),
          erwartet ? findsOneWidget : findsNothing,
          reason:
              '$id: Eine Zeile, die je nach Datenlage kommt und geht, ließe '
              'den Schirm springen — ob die Übung Unterstützung kennt, '
              'steht im Katalog',
        );
      }
    });

    testWidgets('kein Plateau ohne vier auswertbare Trainings', (tester) async {
      final h = fortschrittHuelle(uebungId: idDips);
      await h.lege([
        for (var i = 0; i < 4; i++)
          sitzung('S$i', morgens(2, 9 + 7 * i), {
            idDips: [(-24.5, 8)],
          }),
      ]);
      await zeigeFortschritt(tester, h);

      expect(
        find.byKey(kFPlateau),
        findsNothing,
        reason:
            '`OneRepMax.isPlateau` braucht vier **auswertbare** Sitzungen; '
            'ohne Schätzung ist der Vergleich nicht zu führen, und „kein '
            'Plateau" ist ehrlicher als ein Plateau auf Nullen',
      );
    });
  });

  group('Zeitübungen (Seitstütz)', () {
    List<ImportedSession> haltezeiten() => [
      sitzung('S1', morgens(3, 2), {
        idSeitstuetz: [(0, 30), (0, 35)],
      }),
      sitzung('S2', morgens(3, 9), {
        idSeitstuetz: [(0, 40)],
      }),
    ];

    testWidgets('zeigen die beste Zeit, nie „0 kg" — und kein 1RM', (
      tester,
    ) async {
      final h = fortschrittHuelle(uebungId: idSeitstuetz);
      await h.lege(haltezeiten());
      await zeigeFortschritt(tester, h);

      expect(
        alsTage(diagramm(tester).reihe),
        [('2026-03-02', 35.0), ('2026-03-09', 40.0)],
        reason:
            'Bei einer Zeitübung stehen im Gewichtsfeld keine Kilogramm, '
            'und die längste Zeit ist, was zählt',
      );
      expect(diagramm(tester).zweiteReihe, isEmpty);

      final hoechst = kachelWert(tester, kFWertHoechst);
      expect(hoechst, contains('40'));
      expect(hoechst, isNot(matches(nullAlsWert)));
      expect(hoechst, isNot(contains('0 kg')));
      expect(kachelWert(tester, kFWert1rm), ohneWert);
    });

    testWidgets('behaupten keine Unterstützung — sie sagen, dass es für sie '
        'kein 1RM gibt', (tester) async {
      final h = fortschrittHuelle(uebungId: idSeitstuetz);
      await h.lege(haltezeiten());
      await zeigeFortschritt(tester, h);

      expect(
        find.byKey(kFUnterstuetzung),
        findsNothing,
        reason:
            'Der Seitstütz kennt keine Unterstützung; der Hinweis dazu '
            'wäre eine falsche Begründung für das fehlende 1RM',
      );
      expect(
        find.byKey(kFZeituebung),
        findsOneWidget,
        reason: 'Der Grund steht einmal, und es ist der richtige',
      );
    });
  });
}
