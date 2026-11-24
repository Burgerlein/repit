import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repit/design/erholungs_karte.dart';
import 'package:repit/design/kacheln.dart';
import 'package:repit/design/platzhalter.dart' show ohneWert;
import 'package:repit/design/ringe.dart';

import 'support.dart';

/// Eine Regel für alle drei Anzeigen: **Der Vorlesetext nennt den Zustand,
/// nicht das Zeichen.**
///
/// `CLAUDE.md` („Eine Anzeige, die es gibt, hat genau eine Form"): „Der
/// Vorlesetext nennt den Zustand, nicht das Zeichen. ‚Training, keine
/// Werte' — nicht ‚Training Strich Schrägstrich Strich'." Die Spec
/// (`docs/superpowers/specs/2026-10-28-leerzustaende-design.md`) führt das
/// als Anti-Ziel und begründet es allgemein, formuliert hat sie es nur für
/// `Ringe`. Der Grund gilt wörtlich für `Kacheln` und `ErholungsKarte`:
/// `–/–` ist für das Auge gemacht, vorgelesen ist es Lärm.
///
/// Gefunden im Review zu #137: `Ringe` löst es über `_vorlesetext`, die
/// beiden anderen zeichnen `Text(zahl ?? ohneWert, …)` ohne eigene
/// Semantik. Schritte, Gewicht, HRV, Ruhepuls und Atmung sagen das Zeichen
/// also wörtlich an. Im Ladezustand ist es umgekehrt: Der Ring sagt „wird
/// geladen", die graue Fläche der anderen beiden sagt gar nichts.
///
/// ## Wie geprüft wird
///
/// Über `find.bySemanticsLabel` auf dem gezeichneten Baum, nicht über eine
/// Eigenschaft eines Bausteins: Welcher Baustein das Label trägt und wie er
/// die Kinder stummschaltet (`ExcludeSemantics`, `MergeSemantics`, ein
/// eigenes `Semantics`), bleibt dem Umsetzenden überlassen. Geprüft wird,
/// was VoiceOver vorfände.
///
/// Der Wortlaut ist bis auf zwei Stücke frei: Der **Name** der Anzeige muss
/// vorkommen (sonst weiß niemand, wovon die Rede ist) und danach die
/// Aussage „keine Werte" bzw. „wird geladen" — beides wörtlich so, wie
/// `Ringe` es heute schon sagt. Zwei Formulierungen für denselben Zustand
/// in einer App wären schlechter als eine mittelmäßige.
///
/// Zahlen wie immer erfunden (`CLAUDE.md`: keine echten Gesundheitswerte).
void main() {
  /// Das Zeichen darf in keinem Vorlesetext auftauchen — egal, ob als
  /// eigener Knoten oder in ein Elternlabel hineingemischt.
  void keinZeichenImVorlesetext(String wo) {
    expect(
      find.bySemanticsLabel(RegExp(RegExp.escape(ohneWert))),
      findsNothing,
      reason: '$wo: VoiceOver läse „Strich Schrägstrich Strich" vor — das '
          'ist schlechter als das frühere Weglassen und ein ausdrückliches '
          'Anti-Ziel der Spec',
    );
  }

  group('Ringe — die Fassung, an der die beiden anderen sich messen', () {
    testWidgets('ohne Wert: „Training, keine Werte"', (tester) async {
      await tester.pumpWidget(
        huelle(
          const Ringe([
            RingZiel(
              label: 'Training',
              wert: null,
              ziel: 30,
              text: ohneWert,
              farbe: CupertinoColors.systemBlue,
            ),
          ]),
        ),
      );

      expect(
        find.bySemanticsLabel(RegExp('Training.*keine Werte')),
        findsOneWidget,
      );
      keinZeichenImVorlesetext('Ringe');
    });
  });

  group('Kacheln', () {
    testWidgets('ohne Wert nennt die Kachel ihren Namen und den Zustand, '
        'nicht das Zeichen', (tester) async {
      await tester.pumpWidget(
        huelle(
          const Kacheln([
            KachelWert(
              label: 'Schritte',
              wert: null,
              zusatz: 'Keine Daten oder kein Zugriff',
              farbe: CupertinoColors.systemGreen,
            ),
          ]),
        ),
      );

      expect(
        find.bySemanticsLabel(RegExp('Schritte.*keine Werte')),
        findsOneWidget,
        reason: 'wie beim Ring: erst die Beschriftung, dann der Zustand in '
            'Worten',
      );
      keinZeichenImVorlesetext('Kacheln');
    });

    testWidgets('mit Wert bleibt die Zahl hörbar — die Stummschaltung des '
        'Zeichens darf den Normalfall nicht mitnehmen', (tester) async {
      await tester.pumpWidget(
        huelle(
          const Kacheln([
            KachelWert(
              label: 'Schritte',
              wert: '842',
              zusatz: 'heute gezählt',
              farbe: CupertinoColors.systemGreen,
            ),
          ]),
        ),
      );

      expect(find.bySemanticsLabel(RegExp('842')), findsOneWidget);
    });

    testWidgets('während des Ladens sagt die Kachel „wird geladen" statt zu '
        'schweigen', (tester) async {
      await tester.pumpWidget(
        huelle(
          const Kacheln([
            KachelWert(
              label: 'Schritte',
              wert: null,
              platzhalter: '00.000',
              zusatz: '',
              farbe: CupertinoColors.systemGreen,
            ),
          ]),
        ),
      );

      expect(
        find.bySemanticsLabel(RegExp('Schritte.*wird geladen')),
        findsOneWidget,
        reason: 'die graue Fläche ist für das Auge; wer sie nicht sieht, '
            'hört sonst nur „Schritte" und hält die Kachel für leer',
      );
      expect(
        find.bySemanticsLabel(RegExp('keine Werte')),
        findsNothing,
        reason: 'während des Ladens gibt es keinen „keine Daten"-Grund zu '
            'nennen — auch nicht vorgelesen (Fehler 01 aus CLAUDE.md)',
      );
    });
  });

  group('ErholungsKarte', () {
    testWidgets('eine Spalte ohne Wert nennt ihren Namen und den Zustand', (
      tester,
    ) async {
      await tester.pumpWidget(
        huelle(
          const ErholungsKarte(
            ueberschrift: 'Keine Werte von der Uhr',
            satz: 'Nichts aufgezeichnet, oder kein Lesezugriff.',
            akzent: CupertinoColors.systemGrey,
            vitalwerte: [
              VitalWert(name: 'HRV'),
              VitalWert(name: 'Ruhepuls'),
            ],
          ),
        ),
      );

      expect(
        find.bySemanticsLabel(RegExp('HRV.*keine Werte')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp('Ruhepuls.*keine Werte')),
        findsOneWidget,
      );
      keinZeichenImVorlesetext('ErholungsKarte');
    });

    testWidgets('mit Wert bleibt die Zahl hörbar', (tester) async {
      await tester.pumpWidget(
        huelle(
          const ErholungsKarte(
            ueberschrift: 'Erholung',
            satz: 'HRV, Ruhepuls und Atmung aus Apple Health.',
            akzent: CupertinoColors.systemGreen,
            vitalwerte: [VitalWert(name: 'HRV', wert: '61')],
          ),
        ),
      );

      expect(find.bySemanticsLabel(RegExp('61')), findsOneWidget);
    });

    testWidgets('während des Ladens sagt die Spalte „wird geladen"', (
      tester,
    ) async {
      await tester.pumpWidget(
        huelle(
          const ErholungsKarte(
            ueberschrift: 'Erholung',
            satz: 'HRV, Ruhepuls und Atmung aus Apple Health.',
            akzent: CupertinoColors.systemGrey,
            vitalwerte: [VitalWert(name: 'HRV', platzhalter: '00')],
          ),
        ),
      );

      expect(
        find.bySemanticsLabel(RegExp('HRV.*wird geladen')),
        findsOneWidget,
      );
    });
  });
}
