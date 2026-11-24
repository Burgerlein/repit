import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repit/design/inset_card.dart';
import 'package:repit/ernaehrung/kamera_bausteine.dart';
import 'package:repit/ernaehrung/kamera_unbekannt.dart';

/// Der **Aufbau** von „Strichcode unbekannt" auf einem Telefon (#351).
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden.
///
/// ## Der Befund
///
/// Gemeldet beim Bauen von #348, nicht auf dem Gerät gesehen:
/// `kamera_unbekannt.dart` ruft `GlasAbstand.of(context)` mit dem `context`
/// der Ansicht auf, also **außerhalb** ihres `CupertinoPageScaffold`. Erst
/// das Gerüst zählt die Höhe der durchscheinenden Navigationsleiste in
/// `MediaQuery.padding.top`; mit dem äußeren `context` fehlen die 44 Punkte,
/// und die erste Karte beginnt hinter der Leiste statt darunter. Dieselbe
/// Ursache wie #348 im Prüfblatt (`ki_pruefblatt_aufbau_test.dart`).
///
/// ## Was hier verlangt wird
///
/// Das „Fertig, wenn" des Tickets: **Ungescrollt beginnt die erste Karte
/// unter der Navigationsleiste** — auf Telefongröße und mit einer
/// Statusleiste, denn ohne sie stimmen innerer und äußerer Rand zufällig
/// fast überein.
///
/// Geprüft an `UnbekanntAnsicht` selbst, nicht über den ganzen Weg (+) →
/// Kamera → Scan: Der Fehler sitzt in der Ansicht, und der Weg dorthin ist
/// in `barcode_kamera_test.dart` geprüft. Die Ansicht braucht keinen
/// Provider.
///
/// **Die anderen Schirme mit eigenem Gerüst** (Ticket: „auf dasselbe
/// Muster prüfen") wurden am 04.11.2026 durchgesehen: Sie rufen
/// `GlasAbstand.of` in einem eigenen Widget **unterhalb** des Gerüsts auf
/// (`MahlzeitView`, `ErholungView`, `MessungenView`, `KiZugangView`, …) —
/// nur `kamera_unbekannt.dart` nicht. Deshalb gibt es hier nur diesen
/// Schirm.
///
/// Der Strichcode ist erfunden.
void main() {
  Future<void> zeige(WidgetTester tester, Unbekannt lage) async {
    // Ein Telefon: 393 × 852 Punkte, oben 59 Punkte Statusleiste.
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3.0;
    tester.view.padding = const FakeViewPadding(top: 177, bottom: 102);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);

    await tester.pumpWidget(
      CupertinoApp(
        home: UnbekanntAnsicht(
          lage: lage,
          aufAbbrechen: () {},
          aufAnlegen: () {},
          aufSuchen: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Rect ersteKarte(WidgetTester tester) => tester.getRect(
    find
        .descendant(
          of: find.byKey(const Key('kamera-unbekannt')),
          matching: find.byType(InsetCard),
        )
        .first,
  );

  Rect leiste(WidgetTester tester) =>
      tester.getRect(find.byType(CupertinoNavigationBar));

  for (final (name, lage) in [
    ('nicht hinterlegt', const Unbekannt('0000000000017')),
    (
      'ohne Kalorienangabe',
      const Unbekannt('0000000000024', name: 'Erfundenes Produkt'),
    ),
  ]) {
    testWidgets('#351 ($name): die erste Karte beginnt unter der '
        'Navigationsleiste, nicht dahinter', (tester) async {
      await zeige(tester, lage);

      final karte = ersteKarte(tester);
      final unten = leiste(tester).bottom;
      expect(
        karte.top,
        greaterThanOrEqualTo(unten),
        reason:
            'ungescrollt beginnt die erste Karte bei ${karte.top}, die '
            'Leiste endet bei $unten — der Rand aus GlasAbstand muss die '
            'Leiste mitzählen',
      );
    });
  }

  testWidgets('#351: der Inhalt läuft weiter unter der Leiste durch — der '
      'Rand ist ein Innenabstand, kein kleinerer Viewport', (tester) async {
    await zeige(tester, const Unbekannt('0000000000017'));

    // `CLAUDE.md`: „durchzeichnen statt abschneiden". Der Scrollbereich
    // reicht bis an den oberen Rand; nur sein Inhalt fängt tiefer an.
    final scroll = tester.getRect(find.byKey(const Key('kamera-unbekannt')));
    expect(
      scroll.top,
      lessThan(leiste(tester).bottom),
      reason:
          'eine äußere Padding verkleinerte den Viewport, und der Inhalt '
          'liefe nicht mehr sichtbar unter der Leiste durch',
    );
  });
}
