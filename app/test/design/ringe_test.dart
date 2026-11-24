import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repit/design/ringe.dart';

import 'support.dart';

/// Tests für `Ringe`, `RingLegende` und `RingZiel` (Baukasten „Heute,
/// kombiniert", Task H1), nach `rings`/`ringLegend` in
/// `docs/screens/components.js` und `Sources/DesignSystem/ActivityRings.swift`
/// (`RingGoal`, `ActivityRings`, `RingLegend`).
///
/// **Alle Zahlen unten sind erfunden — nicht aus dem Entwurfsboard
/// übernommen.** Das Board behauptet zwar „Zahlen sind erfundene
/// Beispiele", das stimmte an mehreren Stellen aber nicht. Wer es als
/// Vorlage für einen Baustein nimmt, übernimmt seine Zahlen nicht blind.
///
/// **Zweite Fassung dieser Datei.** Die erste ging von einer gedeckelten
/// Übererfüllung aus (ein Ring voll bei 100 %, darüber bleibt er voll).
/// Zwischen Erteilung und Abgabe des Auftrags wurde `rings()` auf `main`
/// umgebaut (Commit, der den Kopfkommentar in `components.js:280-289`
/// trägt): Übererfüllung läuft seit dem 26.10.2026 eine **zweite Runde**
/// auf einem Schatten der eigenen Farbe, damit „Ziel erreicht" und „50 %
/// darüber" sich sichtbar unterscheiden — mit der gedeckelten Fassung sahen
/// beide gleich aus. Ein Test, der die alte Regel festschreibt, wäre
/// schlimmer als keiner gewesen (er hätte die überholte Regel verteidigt),
/// darum die komplette Neufassung statt eines Patches.
///
/// `RingZiel` trägt die beiden Fraktionen deshalb als zwei reine, pur
/// testbare Getter statt einer einzigen — genau wie `RingGoal.fraction`
/// in Swift eine reine Funktion von `value`/`target` ist (`ActivityRings.
/// swift:16`), nur jetzt zwei Zahlen statt einer:
/// - `ersteRunde`: 0 bis 1, deckelt bei 100 % (`p = min(voll, 1)` in
///   `components.js:296`).
/// - `zweiteRunde`: 0 bis 1, der Schattenumlauf für 100–200 % (`ueber =
///   min(max(voll - 1, 0), 1)` in `components.js:301`), danach gedeckelt —
///   wer dreimal herum ist, liest es an der Zahl ab, nicht am Ring.
///
/// Damit lassen sich die vier Grenzen aus dem Auftrag ohne Widget-Pumping
/// absichern: genau 100 %, knapp darüber, genau 200 %, darüber.
///
/// **Ergänzung aus demselben Umbau:** `Ringe` nimmt jetzt optional
/// `durchmesser`/`strichstaerke` entgegen (Vorbild: `rings(goals, size =
/// 122, w = 13)` im Entwurf und `ActivityRings.diameter`/`.lineWidth` in
/// Swift, beide mit Standardwerten). Grund: Der neue Live-Banner
/// (`banner()` in `docs/screens/screens/heute.js:107-125`) zeichnet
/// dieselben Ringe verkleinert (`rings(goals, 44, 5)`) — ohne die beiden
/// Parameter gäbe es für denselben Baustein zwei Code-Pfade statt einem.
/// Der Banner selbst (Uhr, Sätze, Volumen, Puls, zwei Aktions-Knöpfe) ist
/// **kein** Teil dieses Tasks — siehe Bericht: Die Entwurfsfunktion
/// `banner()` hat bis auf `goals` und `txt` ausschließlich fest verdrahtete
/// Demo-Werte, ist selbst also noch nicht auf echte Parameter hin
/// entworfen.
///
/// **Beschriftung „Rest statt Stand":** Seit demselben Umbau nennt `text`
/// nicht mehr einen Stand gegen das Ziel, sondern den **Rest** („noch X
/// kcal") — das ist die eigentliche Entscheidung laut Kopfkommentar von
/// `heute-kombi.js` („ist die Zahl, nach der man handelt"). Für
/// `RingLegende` ändert das nichts an der Prüfung selbst (`text` ist und
/// bleibt ein vom Schirm durchgereichter String, keine von der Komponente
/// berechnete Darstellung — s. `RingGoal.text`-Kommentar in der
/// Swift-Quelle), wohl aber an den Beispieltexten unten, die jetzt die
/// „Rest"-Form zeigen.
void main() {
  group('RingZiel.ersteRunde (reine Logik, ohne Widget)', () {
    test('ist 0, wenn der Wert 0 ist', () {
      const ziel = RingZiel(
        label: 'Kalorien',
        wert: 0,
        ziel: 1800,
        text: 'noch 1.800 kcal',
        farbe: CupertinoColors.systemYellow,
      );
      expect(ziel.ersteRunde, 0);
    });

    test('ist genau 1, wenn der Wert das Ziel genau erreicht (100 %)', () {
      const ziel = RingZiel(
        label: 'Eiweiß',
        wert: 220,
        ziel: 220,
        text: 'Ziel erreicht',
        farbe: CupertinoColors.systemPurple,
      );
      expect(ziel.ersteRunde, 1);
    });

    test('bleibt bei 1 gedeckelt, auch weit über dem Ziel — die erste Runde '
        'wird nie ein zweites Mal voller als voll', () {
      const ziel = RingZiel(
        label: 'Kalorien',
        wert: 5000,
        ziel: 1800,
        text: '3.200 kcal darüber',
        farbe: CupertinoColors.systemYellow,
      );
      expect(ziel.ersteRunde, 1);
    });

    test('ist 0, wenn das Ziel 0 ist, statt durch 0 zu teilen', () {
      const ziel = RingZiel(
        label: 'Training',
        wert: 10,
        ziel: 0,
        text: 'noch 0 min',
        farbe: CupertinoColors.systemBlue,
      );
      expect(ziel.ersteRunde, 0);
    });
  });

  group(
    'RingZiel.zweiteRunde — der Schattenumlauf (reine Logik, ohne Widget)',
    () {
      test('ist 0, solange das Ziel noch nicht erreicht ist (90 %)', () {
        const ziel = RingZiel(
          label: 'Kalorien',
          wert: 1620,
          ziel: 1800,
          text: 'noch 180 kcal',
          farbe: CupertinoColors.systemYellow,
        );
        expect(ziel.zweiteRunde, 0);
      });

      // Grenzwert 1: genau 100 % — die zweite Runde darf hier noch nicht
      // anspringen, sonst zeigte ein exakt erreichtes Ziel bereits einen
      // Schatten, wo keine Übererfüllung vorliegt.
      test('ist genau 0 bei genau 100 % — noch kein Schatten', () {
        const ziel = RingZiel(
          label: 'Eiweiß',
          wert: 220,
          ziel: 220,
          text: 'Ziel erreicht',
          farbe: CupertinoColors.systemPurple,
        );
        expect(ziel.zweiteRunde, 0);
      });

      // Grenzwert 2: knapp über 100 % — hier muss der Schatten echt greifen,
      // sonst wäre die Grenze um eins verschoben (`>=` statt `>`, oder
      // umgekehrt).
      test('springt knapp ueber 100 % auf einen kleinen Wert an', () {
        const ziel = RingZiel(
          label: 'Kalorien',
          wert: 1980,
          ziel: 1800,
          text: '180 kcal darüber',
          farbe: CupertinoColors.systemYellow,
        );
        expect(ziel.zweiteRunde, closeTo(0.1, 0.0001));
      });

      // Grenzwert 3: genau 200 % — die zweite Runde ist hier exakt voll,
      // noch nicht gedeckelt im Sinne von „schon vorher voll".
      test('ist genau 1 bei genau 200 % (zweite Runde exakt voll)', () {
        const ziel = RingZiel(
          label: 'Training',
          wert: 40,
          ziel: 20,
          text: '20 min darüber',
          farbe: CupertinoColors.systemBlue,
        );
        expect(ziel.zweiteRunde, 1);
      });

      // Grenzwert 4: über 200 % — hier darf nichts mehr zunehmen. Ein
      // dritter Umlauf wird nicht gezeichnet, „wer dreimal herum ist, liest
      // es an der Zahl ab" (Kommentar in components.js:289).
      test('bleibt bei 1 gedeckelt, wenn der Wert mehr als das Doppelte des '
          'Ziels erreicht', () {
        const ziel = RingZiel(
          label: 'Kalorien',
          wert: 4500,
          ziel: 1800,
          text: '2.700 kcal darüber',
          farbe: CupertinoColors.systemYellow,
        );
        expect(ziel.zweiteRunde, 1);
      });

      test('ist 0, wenn das Ziel 0 ist, statt durch 0 zu teilen', () {
        const ziel = RingZiel(
          label: 'Training',
          wert: 10,
          ziel: 0,
          text: 'noch 0 min',
          farbe: CupertinoColors.systemBlue,
        );
        expect(ziel.zweiteRunde, 0);
      });
    },
  );

  group('Ringe (Widget)', () {
    testWidgets(
      'baut ohne Fehler ueber alle vier Grenzen hinweg: 0 %, genau 100 %, '
      'knapp darueber, genau 200 % und weit darueber',
      (tester) async {
        await tester.pumpWidget(
          huelle(
            const Ringe([
              RingZiel(
                label: 'Kalorien',
                wert: 0,
                ziel: 1800,
                text: 'noch 1.800 kcal',
                farbe: CupertinoColors.systemYellow,
              ),
              RingZiel(
                label: 'Eiweiß',
                wert: 220,
                ziel: 220,
                text: 'Ziel erreicht',
                farbe: CupertinoColors.systemPurple,
              ),
              RingZiel(
                label: 'Fett',
                wert: 90,
                ziel: 40,
                text: '50 g darüber',
                farbe: CupertinoColors.systemGreen,
              ),
              RingZiel(
                label: 'Training',
                wert: 40,
                ziel: 20,
                text: '20 min darüber',
                farbe: CupertinoColors.systemBlue,
              ),
              RingZiel(
                label: 'Wasser',
                wert: 6,
                ziel: 5.0,
                text: '1,0 l darüber',
                farbe: CupertinoColors.systemTeal,
              ),
            ]),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.byType(Ringe), findsOneWidget);
      },
    );

    testWidgets(
      'baut ohne Fehler mit abweichendem Durchmesser und abweichender '
      'Strichstaerke — die kleine Fassung im Live-Banner (44/5 statt '
      '122/13 laut Entwurf)',
      (tester) async {
        await tester.pumpWidget(
          huelle(
            const Ringe(
              [
                RingZiel(
                  label: 'Kalorien',
                  wert: 1260,
                  ziel: 1800,
                  text: 'noch 540 kcal',
                  farbe: CupertinoColors.systemYellow,
                ),
              ],
              durchmesser: 44,
              strichstaerke: 5,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.byType(Ringe), findsOneWidget);
      },
    );
  });

  group('RingLegende (Widget)', () {
    testWidgets(
      'zeigt Bezeichnung und Resttext jedes uebergebenen Rings — "noch X '
      'kcal/g" statt eines Stands gegen das Ziel (Entscheidung vom '
      '26.10.2026: Rest statt Stand)',
      (tester) async {
        await tester.pumpWidget(
          huelle(
            const RingLegende([
              RingZiel(
                label: 'Kalorien',
                wert: 1260,
                ziel: 1800,
                text: 'noch 540 kcal',
                farbe: CupertinoColors.systemYellow,
              ),
              RingZiel(
                label: 'Eiweiß',
                wert: 150,
                ziel: 220,
                text: 'noch 70 g',
                farbe: CupertinoColors.systemPurple,
              ),
            ]),
          ),
        );

        expect(find.text('Kalorien'), findsOneWidget);
        expect(find.text('noch 540 kcal'), findsOneWidget);
        expect(find.text('Eiweiß'), findsOneWidget);
        expect(find.text('noch 70 g'), findsOneWidget);
      },
    );
  });
}
