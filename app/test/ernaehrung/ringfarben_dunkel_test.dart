import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/core/messwert.dart';
import 'package:repit/data/ernaehrung_repository.dart';
import 'package:repit/design/palette.dart';
import 'package:repit/design/ringe.dart';
import 'package:repit/ernaehrung/ernaehrung_uebersicht.dart';
import 'package:repit/health/health_types.dart';

import 'tag_huelle.dart';

/// **#387 — Die Ernährungsringe zeichnen im Dunkelmodus die hellen Farben.**
///
/// Der Ernährungs-Tab reicht `Palette.iron`, `Palette.river` und
/// `Palette.ok` unaufgelöst als `RingZiel.farbe` an [Ringe] und
/// [RingLegende]. Eine `CupertinoDynamicColor`, die niemand auflöst, malt
/// auf einem `Paint` und in einer `BoxDecoration` ihren **hellen**
/// Standardwert — im Dunkelmodus stehen die Ringe dann in den Farben des
/// Hellmodus (Eiweiß `0xFF6B5B95` statt `0xFFB79DFF`). Home löst die
/// Farben selbst auf (`ernaehrungsRinge` in `lib/shell/heute_anzeigen.dart`)
/// und ist deshalb richtig.
///
/// Geprüft wird hier, was **gemalt** wird, nicht was im `RingZiel` steht:
/// Ob die Auflösung an der Aufrufstelle oder im Baustein passiert, ist
/// Sache der Implementierung — sichtbar ist allein die Farbe auf dem
/// Bildschirm.
///
/// - Auf dem Ernährungs-Tab malen die drei Ringe und die drei
///   Legendenpunkte die Dunkelfarben. **Seit dem 07.11.2026** ersetzt die
///   Übersicht die drei Ringe (Tims Entscheidung, sein YAZIO-Bild, #406);
///   die Aussage gilt dort weiter und wird an deren Bogen und an den drei
///   Makrobalken geprüft.
/// - [Ringe] und [RingLegende] lösen eine übergebene
///   `CupertinoDynamicColor` selbst auf. Damit kann die Verwechslung an
///   keiner künftigen Aufrufstelle wieder passieren.
///
/// Geschrieben vom selben Agenten, der den Fehler behebt (CLAUDE.md:
/// Widget-Tests für Zustände — ein Agent genügt, Test zuerst, rot,
/// committet). Nicht von Tim gesehen. Den Fall des Tabs hat der
/// Test-Agent am 10.11.2026 auf die Übersicht umgestellt (#406); die
/// Bausteinfälle darunter bleiben, denn `Ringe` und `RingLegende` leben
/// auf Home weiter.
///
/// **Alle Zahlen erfunden** — runde Werte.
void main() {
  // Dienstag, 14.07.2026, 12:00 Berliner Zeit (MESZ, +2).
  final jetzt = DateTime.utc(2026, 7, 14, 10);
  const heute = '2026-07-14';

  void dunkel(WidgetTester tester) {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
  }

  /// Die Dunkelfarbe als Matcher. **Nicht `==`:** `Paint` hält seine
  /// Farbe in Float32, und was `Paint.color` zurückgibt, ist um eine
  /// Rundung verschieden von `Color(0xFF…)` — gleich gemalt, aber nie
  /// gleich. `isSameColorAs` vergleicht mit Toleranz und sieht auch über
  /// den Laufzeittyp einer aufgelösten `CupertinoDynamicColor` hinweg.
  Matcher dunkelVon(CupertinoDynamicColor farbe) =>
      isSameColorAs(farbe.darkColor);

  Matcher hellVon(CupertinoDynamicColor farbe) => isSameColorAs(farbe.color);

  Finder ringFlaeche(Finder ringe) =>
      find.descendant(of: ringe, matching: find.byType(CustomPaint));

  /// Die Farben aller gemalten Bögen, in Malreihenfolge — Spuren
  /// eingeschlossen. `paints..arc(color:)` taugt hier nicht: Es nimmt den
  /// jeweils nächsten Bogen, und vor jedem Wertbogen liegt eine Spur.
  List<Color> bogenFarben(Finder flaeche) {
    final farben = <Color>[];
    expect(
      flaeche,
      paints..everything((methode, argumente) {
        if (methode == #drawArc) farben.add((argumente[4] as Paint).color);
        return true;
      }),
    );
    return farben;
  }

  /// Die Farben der Legendenpunkte, von oben nach unten.
  List<Color?> punktFarben(WidgetTester tester, Finder legende) => [
    for (final container in tester.widgetList<Container>(
      find.descendant(of: legende, matching: find.byType(Container)),
    ))
      if (container.decoration case BoxDecoration(
        shape: BoxShape.circle,
        :final color,
      ))
        color,
  ];

  group('Ernährungs-Tab im Dunkelmodus', () {
    testWidgets('Bogen und Balken der Übersicht malen die Dunkelfarben', (
      tester,
    ) async {
      dunkel(tester);
      final h = tagHuelle(
        jetzt: jetzt,
        tageswerte: Bekannt<List<DailyMetrics>>(
          const [
            DailyMetrics(
              tag: heute,
              activeKcal: 600,
              basalKcal: 1600,
              weightKg: 80,
            ),
          ],
          stand: jetzt,
          laeuft: false,
        ),
      );
      await ErnaehrungRepository(h.db).buche(
        Eintrag(
          tagesSchluessel: heute,
          mahlzeit: Mahlzeit.mittag,
          zeitpunkt: jetzt,
          name: 'Testgericht',
          naehrwerte: const Naehrwerte(
            kcal: 1200,
            eiweissG: 100,
            kohlenhydrateG: 150,
            fettG: 40,
          ),
        ),
      );
      await zeigeTag(tester, h.app);

      // Der Bogen: Unter dem Ziel füllt er sich in `Palette.river`.
      final bogen = find.byKey(const Key('ernaehrung-uebersicht-bogen'));
      expect(bogen, findsOneWidget);
      final anteil = tester.widget<UebersichtBogen>(bogen).anteil;
      expect(
        anteil != null && anteil > 0.02 && anteil < 1,
        isTrue,
        reason:
            'Vorbedingung: ein gefüllter Bogen unter dem Ziel — ohne '
            'Füllung malt er nur die Spur, und die Farbe bliebe ungeprüft',
      );
      final gemalt = bogenFarben(
        find.descendant(of: bogen, matching: find.byType(CustomPaint)),
      );
      expect(
        gemalt,
        contains(dunkelVon(Palette.river)),
        reason: 'der gefüllte Teil des Bogens in der Dunkelfarbe',
      );
      expect(
        gemalt,
        isNot(contains(hellVon(Palette.river))),
        reason:
            'der helle Standardwert der Palette gehört nicht in den '
            'Dunkelmodus',
      );

      // Die drei Balken: Kohlenhydrate `river`, Eiweiß `iron`, Fett `ok`.
      const farben = {
        'kohlenhydrate': Palette.river,
        'eiweiss': Palette.iron,
        'fett': Palette.ok,
      };
      for (final MapEntry(key: name, value: farbe) in farben.entries) {
        final saeule = find.byKey(Key('ernaehrung-uebersicht-$name'));
        final balken = tester.widget<MakroSaeule>(saeule);
        expect(
          balken.wert != null &&
              balken.ziel != null &&
              balken.wert! > 0 &&
              balken.wert! <= balken.ziel!,
          isTrue,
          reason:
              '$name: Vorbedingung — ein gefüllter Balken unter dem Ziel. '
              'Ohne Wert gibt es keine Füllung, über dem Ziel färbt er sich '
              'um, und in beiden Fällen bliebe die Farbe ungeprüft',
        );
        final fuellung = [
          for (final container in tester.widgetList<Container>(
            find.descendant(
              of: find.descendant(
                of: saeule,
                matching: find.byType(FractionallySizedBox),
              ),
              matching: find.byType(Container),
            ),
          ))
            ?container.color,
        ];
        expect(fuellung, [
          dunkelVon(farbe),
        ], reason: '$name: die Füllung des Balkens in der Dunkelfarbe');
      }
    });
  });

  group('Die Bausteine lösen selbst auf', () {
    const ziel = RingZiel(
      label: 'Eiweiß',
      wert: 50,
      ziel: 100,
      text: 'noch 50 g',
      farbe: Palette.iron,
    );

    Future<void> zeige(WidgetTester tester, Widget inhalt) async {
      await tester.pumpWidget(
        CupertinoApp(
          theme: const CupertinoThemeData(brightness: Brightness.dark),
          home: CupertinoPageScaffold(child: Center(child: inhalt)),
        ),
      );
    }

    testWidgets('Ringe malt eine dynamische Farbe dunkel', (tester) async {
      await zeige(tester, const Ringe([ziel]));

      final gemalt = bogenFarben(ringFlaeche(find.byType(Ringe)));
      expect(gemalt, contains(dunkelVon(Palette.iron)));
      expect(gemalt, isNot(contains(hellVon(Palette.iron))));
    });

    testWidgets('auch die weitere Runde über 100 % kommt aus der '
        'Dunkelfarbe', (tester) async {
      const ueber = RingZiel(
        label: 'Eiweiß',
        wert: 150,
        ziel: 100,
        text: '50 g darüber',
        farbe: Palette.iron,
      );
      await zeige(tester, const Ringe([ueber]));

      expect(
        bogenFarben(ringFlaeche(find.byType(Ringe))),
        containsAllInOrder([
          dunkelVon(Palette.iron),
          isSameColorAs(ringRundenFarbe(Palette.iron.darkColor, 1)),
        ]),
      );
    });

    testWidgets('RingLegende malt den Punkt dunkel', (tester) async {
      await zeige(
        tester,
        const SizedBox(width: 300, child: RingLegende([ziel])),
      );

      expect(punktFarben(tester, find.byType(RingLegende)), [
        dunkelVon(Palette.iron),
      ]);
    });
  });
}
