import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/shell/diagramm_zeitraum.dart';

/// Tests für die **Rechnung hinter jedem Diagramm** von #94 —
/// `lib/shell/diagramm_zeitraum.dart`. Die beiden Schirme, die sie
/// benutzen, liegen in `belastung_*_test.dart` und `verlauf_*_test.dart`.
///
/// ## Warum das eine eigene Datei ist
///
/// Ob aus Zahlen Pixel werden, kann im Flutter-Zweig niemand prüfen —
/// Golden-Tests gibt es hier nicht. Was sich prüfen lässt, ist die
/// **Geometrie als reine Rechnung**, genau wie `RingGeometrie` es für die
/// Ringe vormacht (`lib/design/segment_ring.dart`): Welche Punkte das
/// Diagramm zeichnet, wo das Fenster beginnt, auf welche Grenze es rastet.
/// Das ist der einzige Weg, der ohne Pixelvergleich trägt.
///
/// ## Festgelegte öffentliche API (`lib/shell/diagramm_zeitraum.dart`)
///
/// ```dart
/// /// Die Stufen der Zeitraumleiste (Entwurfs-Spec
/// /// `2026-10-13-graphen-zeitraum-und-ablesen-design.md`, „Rastgrenzen je
/// /// Stufe"). `T` fehlt: Keiner der beiden Schirme hat Stundenwerte.
/// enum DiagrammStufe { woche, monat, halbjahr, jahr }
///
/// /// Ein gezeichneter Punkt.
/// @immutable
/// class DiagrammPunkt {
///   const DiagrammPunkt({
///     required DateTime beginn,
///     required double wert,
///     required int tage,
///   });
/// }
///
/// /// Die Startstufe ist die **kleinste** angebotene.
/// DiagrammStufe startStufe(List<DiagrammStufe> stufen);
///
/// /// Verdichtet Tageswerte zur Stufe.
/// List<DiagrammPunkt> diagrammPunkte({
///   required List<({DateTime tag, double wert})> werte,
///   required DiagrammStufe stufe,
/// });
///
/// /// Rastet einen Zeitpunkt auf die Grenze seiner Stufe.
/// DateTime rastgrenze(DateTime zeitpunkt, DiagrammStufe stufe);
///
/// /// Das Fenster, das beim Aufschlagen sichtbar ist — halboffen.
/// (DateTime von, DateTime bis) startFenster({
///   required DiagrammStufe stufe,
///   required DateTime juengster,
/// });
/// ```
///
/// ## Was diese Datei entscheidet, weil es nirgends steht
///
/// - **`tage` zählt verschiedene Kalendertage, der Mittelwert läuft über
///   die Messwerte.** Wörtlich die nachgetragene Klärung 1 der Entwurfs-Spec
///   (Z. 126–132). Für die heutigen Abnehmer ist das dasselbe — sie liefern
///   Tageswerte. Die Annahme steht hier, damit sie jemand findet.
/// - **Das Startfenster endet an der Rastgrenze *nach* dem jüngsten Wert,
///   nicht an der davor.** Sonst liegt der neueste Balken außerhalb des
///   Fensters, und der Schirm schlägt auf einer leeren Fläche auf.
/// - **`startStufe` ist eine eigene Funktion und keine Zeile im Widget.**
///   Das ist `#7` („Das Startfenster eines Diagramms greift nicht
///   zuverlässig"): In Swift steht die Absicht als Kommentar
///   (`LoadDetailView.swift:66–70`) und der Code tut etwas anderes. Eine
///   Absicht, die niemand ausführen kann, ist keine. Als Funktion ist sie
///   prüfbar, und der Schirm kann sie nicht umgehen.
///
/// ## Die Startstufe ist seit dem 27.10.2026 die **kleinste** angebotene
///
/// **Tims Entscheidung**, im Wortlaut: „immer das kleinste zuerst". Die
/// Entwurfs-Spec ist nachgezogen
/// (`2026-10-13-graphen-zeitraum-und-ablesen-design.md`, Z. 48: „die
/// **kleinste** angebotene Stufe"); vorher stand dort `M`, und in dieser
/// Datei stand „die **erste** angebotene".
///
/// Warum das die bessere Regel ist — und das ist die Begründung des
/// Test-Agenten, nicht Tims:
///
/// Die alte Regel hing an der **Reihenfolge einer Liste, die ein Schirm
/// aufschreibt.** Ein Schirm, der seine Stufen anders sortiert, bekäme still
/// eine andere Startstufe, ohne dass irgendwo ein Fehler sichtbar würde —
/// kein Typ, kein Test, kein Absturz. Genau diese Sorte Fehler ist `#7`:
/// „Das Startfenster eines Diagramms greift nicht zuverlässig", und in Swift
/// war er echt. Die neue Regel ist **durch die Eingabe nicht
/// kaputtzumachen**: Dieselbe Menge Stufen ergibt dieselbe Startstufe, in
/// welcher Reihenfolge und wie oft sie auch dastehen.
///
/// „Kleinste" heißt: die mit dem niedrigsten `index`, denn `DiagrammStufe`
/// ist aufsteigend deklariert (`woche, monat, halbjahr, jahr`). Dass das so
/// bleibt, hält ein Wächtertest in dieser Datei fest — sonst drehte eine
/// Umsortierung des `enum` jede Startstufe um, ohne `startStufe` anzufassen.
///
/// Was **nicht** mitgewandert ist: Eine leere Liste wirft weiter.
///
/// ## Was hier bewusst **nicht** geprüft wird
///
/// - **Pixel, Achsenbeschriftung, Farben.** Kein Golden-Test, keine
///   Beschriftung (`CLAUDE.md`: Widget-Tests nur für Zustände und
///   Übergänge).
/// - **Blättern und Ablesen.** Beides ist Geste und gehört zum
///   Diagramm-Bauteil, nicht zu dieser Rechnung. Siehe Bericht.
void main() {
  // Alle Grenzen als Berliner Tagesbeginn, zurückgegeben als UTC-Zeitpunkt —
  // genau wie `BerlinCalendar` es tut.
  DateTime tag(int jahr, int monat, int tag) =>
      BerlinCalendar.startOfDay(DateTime.utc(jahr, monat, tag));

  ({DateTime tag, double wert}) wert(DateTime t, double v) =>
      (tag: t, wert: v);

  group('Die Startstufe ist die kleinste angebotene (#7)', () {
    test('Belastung beginnt auf W, nicht auf M', () {
      expect(
        startStufe(const [
          DiagrammStufe.woche,
          DiagrammStufe.monat,
          DiagrammStufe.halbjahr,
        ]),
        DiagrammStufe.woche,
        reason:
            'Tims Entscheidung vom 27.10.2026: „immer das kleinste zuerst". '
            'Der Kommentar in `LoadDetailView.swift:66–70` behauptet „M als '
            'Start", die Liste eine Zeile darüber beginnt mit `.week` — im '
            'Nachbau gilt die kleinste angebotene Stufe, nicht der Kommentar',
      );
    });

    test('die Reihenfolge der Liste ändert nichts mehr', () {
      expect(
        startStufe(const [DiagrammStufe.monat, DiagrammStufe.woche]),
        DiagrammStufe.woche,
        reason:
            'Bis zum 27.10.2026 war die **erste** angebotene Stufe die '
            'Startstufe, und damit hing sie an der Reihenfolge einer Liste, '
            'die ein Schirm aufschreibt. Wer seine Stufen anders sortiert, '
            'bekäme still ein anderes Startfenster — ohne Typfehler, ohne '
            'Absturz, ohne Hinweis. Genau das ist #7',
      );
      expect(
        startStufe(const [DiagrammStufe.woche, DiagrammStufe.monat]),
        DiagrammStufe.woche,
        reason: 'dieselbe Menge Stufen, dieselbe Startstufe',
      );
    });

    test('eine unsortierte Liste ergibt trotzdem die kleinste', () {
      expect(
        startStufe(const [
          DiagrammStufe.jahr,
          DiagrammStufe.halbjahr,
          DiagrammStufe.monat,
        ]),
        DiagrammStufe.monat,
        reason:
            '`stufen.first` gäbe hier `jahr`: zwölf Monate, in denen ein '
            'einzelner Balken nichts mehr bedeutet. „Der kleinste Ausschnitt '
            'ist der, in dem einzelne Balken noch etwas bedeuten" '
            '(Entwurfs-Spec, Voreinstellung)',
      );
    });

    test('Doppel ändern nichts', () {
      expect(
        startStufe(const [
          DiagrammStufe.halbjahr,
          DiagrammStufe.halbjahr,
          DiagrammStufe.monat,
          DiagrammStufe.halbjahr,
        ]),
        DiagrammStufe.monat,
        reason:
            'Eine Stufe doppelt anzumelden ist ein Versehen des Schirms, '
            'kein Stimmrecht. Eine Regel, die zählt statt zu vergleichen, '
            'würde hier `halbjahr` wählen',
      );
    });

    test('eine einzige Stufe ist ihre eigene Startstufe', () {
      for (final stufe in DiagrammStufe.values) {
        expect(startStufe([stufe]), stufe);
      }
    });

    test('„kleinste" liest sich an der Reihenfolge der Deklaration ab', () {
      expect(
        DiagrammStufe.values,
        const [
          DiagrammStufe.woche,
          DiagrammStufe.monat,
          DiagrammStufe.halbjahr,
          DiagrammStufe.jahr,
        ],
        reason:
            'Wächtertest, von Anfang an grün — er prüft eine Behauptung über '
            'das Paket, kein noch zu bauendes Verhalten (`CLAUDE.md`). Die '
            'kleinste angebotene Stufe ist die mit dem niedrigsten `index`, '
            'und das stimmt nur, solange der `enum` aufsteigend deklariert '
            'ist. Wer `jahr` nach vorn zöge, drehte jede Startstufe um, ohne '
            'eine Zeile in `startStufe` anzufassen',
      );
    });

    test('eine leere Liste gibt es nicht — das wirft', () {
      expect(
        () => startStufe(const []),
        throwsA(anything),
        reason:
            'Ein Diagramm ohne Stufe hat keine Startstufe. Still eine zu '
            'erfinden hieße, eine Leiste zu zeigen, die der Schirm nicht '
            'angemeldet hat',
      );
    });
  });

  group('Rastgrenzen je Stufe', () {
    test('W rastet auf Montag', () {
      // Donnerstag, 22.10.2026.
      expect(
        rastgrenze(tag(2026, 10, 22), DiagrammStufe.woche),
        tag(2026, 10, 19),
      );
    });

    test('ein Montag bleibt stehen', () {
      expect(
        rastgrenze(tag(2026, 10, 19), DiagrammStufe.woche),
        tag(2026, 10, 19),
      );
    });

    test('W rastet auch über die Zeitumstellung richtig', () {
      // Die Sommerzeit endet am Sonntag, 25.10.2026. Die Woche ab dem
      // 19.10. hat 169 Stunden; wer `- 3 · 86400` rechnet, landet auf dem
      // 18.10. und damit auf einem Sonntag.
      expect(
        rastgrenze(tag(2026, 10, 25), DiagrammStufe.woche),
        tag(2026, 10, 19),
      );
      expect(BerlinCalendar.weekday(tag(2026, 10, 19)), DateTime.monday);
    });

    test('M, 6M und J rasten alle drei auf den Monatsersten', () {
      for (final stufe in const [
        DiagrammStufe.monat,
        DiagrammStufe.halbjahr,
        DiagrammStufe.jahr,
      ]) {
        expect(
          rastgrenze(tag(2026, 10, 22), stufe),
          tag(2026, 10, 1),
          reason:
              '$stufe — „J rastet auf den Monats-, nicht den Jahresanfang": '
              'Jahresgrenzen sind zu grob, rückwärts liegt die nächste '
              'außerhalb der Daten, und dann rastet gar nichts '
              '(Entwurfs-Spec Z. 193–195)',
        );
      }
    });

    test('ein Monatserster bleibt stehen', () {
      expect(
        rastgrenze(tag(2026, 3, 1), DiagrammStufe.monat),
        tag(2026, 3, 1),
      );
    });
  });

  group('Das Startfenster', () {
    test('W: Montag bis Montag, halboffen', () {
      final (von, bis) = startFenster(
        stufe: DiagrammStufe.woche,
        juengster: tag(2026, 10, 22),
      );
      expect(von, tag(2026, 10, 19));
      expect(bis, tag(2026, 10, 26));
    });

    test('W über die Zeitumstellung ist 169 Stunden lang, nicht 168', () {
      final (von, bis) = startFenster(
        stufe: DiagrammStufe.woche,
        juengster: tag(2026, 10, 22),
      );
      expect(
        bis.difference(von),
        const Duration(hours: 169),
        reason:
            'Die Woche ab dem 19.10.2026 hat 169 Stunden. Wer `+ 7 · 86400` '
            'rechnet, trifft die falsche Mitternacht und der Montagvormittag '
            'fällt in die Vorwoche (`TrainingLoad.weekBounds`)',
      );
    });

    test('M: Monatserster bis Monatserster', () {
      final (von, bis) = startFenster(
        stufe: DiagrammStufe.monat,
        juengster: tag(2026, 10, 22),
      );
      expect(von, tag(2026, 10, 1));
      expect(bis, tag(2026, 11, 1));
    });

    test('6M: sechs Monate, die den jüngsten Wert einschließen', () {
      final (von, bis) = startFenster(
        stufe: DiagrammStufe.halbjahr,
        juengster: tag(2026, 10, 22),
      );
      expect(bis, tag(2026, 11, 1));
      expect(von, tag(2026, 5, 1));
    });

    test('J: zwölf Monate', () {
      final (von, bis) = startFenster(
        stufe: DiagrammStufe.jahr,
        juengster: tag(2026, 10, 22),
      );
      expect(bis, tag(2026, 11, 1));
      expect(von, tag(2025, 11, 1));
    });

    test('das Fenster endet **nach** dem jüngsten Wert, nie davor', () {
      for (final stufe in DiagrammStufe.values) {
        final juengster = tag(2026, 10, 22);
        final (von, bis) = startFenster(stufe: stufe, juengster: juengster);
        expect(
          von.isAfter(juengster),
          isFalse,
          reason: '$stufe: der jüngste Wert liegt vor dem Fensterbeginn',
        );
        expect(
          bis.isAfter(juengster),
          isTrue,
          reason:
              '$stufe: das Fenster ist halboffen, der jüngste Wert muss '
              'echt davorliegen — sonst schlägt der Schirm auf einer leeren '
              'Fläche auf, und genau das ist #7',
        );
      }
    });

    test('ein Jahreswechsel verschiebt das Fenster nicht um ein Jahr', () {
      final (von, bis) = startFenster(
        stufe: DiagrammStufe.halbjahr,
        juengster: tag(2026, 1, 15),
      );
      expect(bis, tag(2026, 2, 1));
      expect(von, tag(2025, 8, 1));
    });
  });

  group('Verdichtung: W und M reichen Tageswerte durch', () {
    test('unverändert und aufsteigend sortiert', () {
      final punkte = diagrammPunkte(
        werte: [
          wert(tag(2026, 10, 12), 42),
          wert(tag(2026, 10, 10), 18),
          wert(tag(2026, 10, 11), 0),
        ],
        stufe: DiagrammStufe.woche,
      );

      expect(punkte.map((p) => p.beginn).toList(), [
        tag(2026, 10, 10),
        tag(2026, 10, 11),
        tag(2026, 10, 12),
      ]);
      expect(punkte.map((p) => p.wert).toList(), [18, 0, 42]);
      expect(punkte.every((p) => p.tage == 1), isTrue);
    });

    test('eine gemessene Null bleibt ein Punkt', () {
      final punkte = diagrammPunkte(
        werte: [wert(tag(2026, 10, 11), 0)],
        stufe: DiagrammStufe.monat,
      );
      expect(
        punkte,
        hasLength(1),
        reason:
            'Eine gemessene Null ist ein Messwert. Sie wegzulassen hieße zu '
            'behaupten, an dem Tag sei nicht gemessen worden',
      );
      expect(punkte.single.wert, 0);
    });

    test('Lücken bleiben Lücken — es wird nichts aufgefüllt', () {
      final punkte = diagrammPunkte(
        werte: [wert(tag(2026, 10, 10), 10), wert(tag(2026, 10, 14), 20)],
        stufe: DiagrammStufe.monat,
      );
      expect(
        punkte,
        hasLength(2),
        reason:
            'Kein Interpolieren über Tage, an denen die Uhr im Schrank lag '
            '(Entwurfs-Spec, „Lücken bleiben Lücken")',
      );
    });

    test('ein Zeitpunkt mitten am Tag wird auf den Tagesbeginn gezogen', () {
      final punkte = diagrammPunkte(
        // 14:30 Berliner Zeit am 12.10.2026.
        werte: [wert(DateTime.utc(2026, 10, 12, 12, 30), 7)],
        stufe: DiagrammStufe.woche,
      );
      expect(
        punkte.single.beginn,
        tag(2026, 10, 12),
        reason:
            'Ein Diagramm, das seine x-Achse aus den Punkten baut, braucht '
            'gleich lange Abstände — sonst steht ein Balken schief, weil der '
            'Messwert um 14:30 ankam',
      );
    });

    test('leere Eingabe gibt ein leeres Ergebnis, keinen Absturz', () {
      for (final stufe in DiagrammStufe.values) {
        expect(diagrammPunkte(werte: const [], stufe: stufe), isEmpty);
      }
    });
  });

  group('Verdichtung: 6M und J bilden Monatsmittel', () {
    test('je Kalendermonat ein Punkt auf dem Monatsersten', () {
      final punkte = diagrammPunkte(
        werte: [
          wert(tag(2026, 9, 3), 10),
          wert(tag(2026, 9, 25), 20),
          wert(tag(2026, 10, 2), 60),
        ],
        stufe: DiagrammStufe.halbjahr,
      );

      expect(punkte.map((p) => p.beginn).toList(), [
        tag(2026, 9, 1),
        tag(2026, 10, 1),
      ]);
      expect(punkte.map((p) => p.wert).toList(), [15, 60]);
    });

    test(
      'der Teiler ist die Zahl der **gemessenen** Tage, nicht die Länge des '
      'Monats',
      () {
        final punkte = diagrammPunkte(
          werte: [wert(tag(2026, 9, 3), 30), wert(tag(2026, 9, 4), 60)],
          stufe: DiagrammStufe.halbjahr,
        );
        expect(
          punkte.single.wert,
          45,
          reason:
              'Zwei gemessene Tage, Mittel 45. Durch 30 geteilt wären es 3 — '
              'eine Zahl, die behauptet, an 28 Tagen sei nichts gewesen',
        );
        expect(punkte.single.tage, 2);
      },
    );

    test('ein Monat ohne jede Messung fehlt im Ergebnis', () {
      final punkte = diagrammPunkte(
        werte: [wert(tag(2026, 8, 3), 10), wert(tag(2026, 10, 2), 20)],
        stufe: DiagrammStufe.jahr,
      );
      expect(
        punkte.map((p) => p.beginn).toList(),
        [tag(2026, 8, 1), tag(2026, 10, 1)],
        reason: 'Der September kommt nicht vor — eine Lücke ist eine Lücke',
      );
    });

    test(
      'mehrere Messwerte am selben Tag: das Mittel läuft über die Messwerte, '
      '`tage` zählt die Kalendertage',
      () {
        final punkte = diagrammPunkte(
          werte: [
            wert(tag(2026, 9, 3), 10),
            wert(tag(2026, 9, 3), 20),
            wert(tag(2026, 9, 10), 60),
          ],
          stufe: DiagrammStufe.halbjahr,
        );
        expect(punkte.single.wert, closeTo(30, 1e-9));
        expect(
          punkte.single.tage,
          2,
          reason:
              'Nachgetragene Klärung 1 der Entwurfs-Spec (Z. 126–132). Die '
              'heutigen Abnehmer liefern Tageswerte — die Annahme steht hier, '
              'damit sie jemand findet, wenn eine Reihe das einmal nicht tut',
        );
      },
    );

    test('Monate kommen aufsteigend, auch über den Jahreswechsel', () {
      final punkte = diagrammPunkte(
        werte: [
          wert(tag(2026, 1, 5), 1),
          wert(tag(2025, 12, 5), 2),
          wert(tag(2025, 11, 5), 3),
        ],
        stufe: DiagrammStufe.jahr,
      );
      expect(punkte.map((p) => p.beginn).toList(), [
        tag(2025, 11, 1),
        tag(2025, 12, 1),
        tag(2026, 1, 1),
      ]);
    });

    test(
      'die Monatsgrenze läuft über den Berliner Kalender, nicht über UTC',
      () {
        // 31.10.2026, 23:30 Berliner Zeit = 22:30 UTC. Nach UTC-Datum
        // derselbe Tag; nach Berliner Datum ebenfalls — aber die Umkehrung
        // beißt: 01.11.2026, 00:30 Berlin ist 31.10. 23:30 UTC, also nach
        // UTC noch Oktober.
        final punkte = diagrammPunkte(
          werte: [wert(DateTime.utc(2026, 10, 31, 23, 30), 5)],
          stufe: DiagrammStufe.halbjahr,
        );
        expect(
          punkte.single.beginn,
          tag(2026, 11, 1),
          reason:
              'Der Messwert fiel am 1. November um 00:30 Berliner Zeit an. '
              'Wer `DateTime.month` auf dem UTC-Zeitpunkt liest, schiebt ihn '
              'in den Oktober',
        );
      },
    );
  });

  group('DiagrammPunkt ist ein Werttyp', () {
    test('gleiche Felder sind gleich — sonst rechnet jedes Bild neu', () {
      final a = DiagrammPunkt(beginn: tag(2026, 10, 12), wert: 42, tage: 1);
      final b = DiagrammPunkt(beginn: tag(2026, 10, 12), wert: 42, tage: 1);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(
        a == DiagrammPunkt(beginn: tag(2026, 10, 12), wert: 43, tage: 1),
        isFalse,
      );
    });
  });
}
