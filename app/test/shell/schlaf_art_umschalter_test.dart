import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/data/schlaf_eintrag.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/shell/schlaf_eintragen.dart';

/// Tests für den **Umschalter Nacht / Tagschlaf im Formular „von Hand
/// eintragen"** (#502) — `lib/shell/schlaf_eintragen.dart`.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung**
/// (`CLAUDE.md`). Diese Datei darf ausgeführt, nie verändert werden.
///
/// ## Der Befund
///
/// Tim, 13.11.2026: „Wo kann ich Tagschlaf nachtragen, wenn noch keiner
/// vorhanden ist? Finde nur den Button zum Nachtschlaf." Beide Türen auf
/// den Tagschlaf-Schirm hingen an bereits vorhandenen Nickerchen — Henne
/// und Ei. Entschieden ist: **Das Formular bekommt die Wahl, der Schirm
/// keine neue Zeile.** Ohne Nickerchen steht weiterhin keine
/// Nickerchen-Zeile da, die eine Messung von null behaupten würde (#209);
/// Anzeigen und Eintragen sind entkoppelt.
///
/// ## Geprüft werden Zustände und Übergänge, nicht Beschriftungen
///
/// Also: Womit steht das Formular da, wenn es aufgeht? Was ändert sich
/// beim Umschalten — und was ausdrücklich nicht? Wie die beiden Felder
/// heißen, steht hier nirgends.
///
/// ## Drei Zusicherungen
///
/// 1. **Die Vorbelegung richtet sich nach dem Aufrufer.** Vom
///    Schlaf-Schirm ist „Nacht" richtig, vom `(+)` des Tagschlaf-Schirms
///    muss es „Tagschlaf" sein — sonst trägt man dort aus Versehen eine
///    Nacht ein. Dass die beiden Schirme genau diese Arten mitgeben, hält
///    `schlaf_eintragen_test.dart` schon fest (dort kommt hinten ein
///    Eintrag der erwarteten Art heraus); hier steht, was das Formular
///    daraus macht.
/// 2. **Die Vorgaben wechseln mit** — 7 h für die Nacht gegen 30 min für
///    ein Nickerchen, 23:00–06:30 gegen 13:30–14:00.
/// 3. **Aber nicht über eine Eingabe hinweg.** Was von Hand gesetzt wurde,
///    springt beim Umschalten nicht zurück. Das ist derselbe Fall wie beim
///    Dauer-Rad (#210), und er wird hier genauso geprüft: am **sichtbaren
///    Stand der Räder**, nicht an einem Feld der Implementierung. Ein Rad,
///    das etwas anderes zeigt als die Zeile darüber, meldet beim nächsten
///    Anfassen seinen veralteten Stand zurück — ab da wird falsch
///    gesichert.
///
/// Dazu kommt: **Der Tag bleibt der Tag.** Ein Nickerchen zählt nach
/// seinem Beginn, eine Nacht nach dem Aufwachtag (#209). Das Umschalten
/// darf den vorbelegten Tag nicht stillschweigend verschieben — geprüft
/// an dem, was hinten in der Ablage landet.
///
/// Schlüssel, auf die sich diese Tests festlegen:
///
/// | Schlüssel | Was |
/// |---|---|
/// | `schlaf-eintragen-art` | die Auswahl Nacht / Tagschlaf |
/// | `schlaf-eintragen-art-nacht` | ihr linkes Feld |
/// | `schlaf-eintragen-art-tagschlaf` | ihr rechtes Feld |
void main() {
  // Ein Rastermaß des Cupertino-Rades — die Gesten unten rechnen in
  // Rasten, nicht in Pixeln (wie in `schlaf_dauer_rad_test.dart`).
  const rasterHoehe = 32.0;

  final jetzt = DateTime.utc(2026, 10, 29, 9);
  final tag = BerlinCalendar.startOfDay(DateTime.utc(2026, 10, 29, 12));

  Finder raeder(Finder rad) =>
      find.descendant(of: rad, matching: find.byType(ListWheelScrollView));

  int stelle(WidgetTester tester, Finder wheel) {
    final w = tester.widget<ListWheelScrollView>(wheel);
    return (w.controller! as FixedExtentScrollController).selectedItem;
  }

  /// Das Dauer-Rad, abgelesen in Minuten.
  int dauerAmRad(WidgetTester tester) {
    final rad = find.byType(CupertinoTimerPicker);
    expect(rad, findsOneWidget);
    return stelle(tester, raeder(rad).at(0)) % 24 * 60 +
        stelle(tester, raeder(rad).at(1)) % 12 * 5;
  }

  /// Die Zeile über dem Dauer-Rad, als Minuten. Sie steht als „7:30 h" da.
  int dauerInDerZeile(WidgetTester tester) {
    final treffer = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .whereType<String>()
        .where((t) => RegExp(r'^\d+:\d\d h$').hasMatch(t))
        .toList();
    expect(treffer, hasLength(1), reason: 'genau eine Dauerzeile');
    final teile = treffer.single.split(RegExp('[: ]'));
    return int.parse(teile[0]) * 60 + int.parse(teile[1]);
  }

  /// Eines der beiden Uhrzeitenräder (0 = Beginn, 1 = Ende), als Minuten
  /// nach Mitternacht.
  int uhrzeitAmRad(WidgetTester tester, int welches) {
    final rad = find.byType(CupertinoDatePicker).at(welches);
    return stelle(tester, raeder(rad).at(0)) % 24 * 60 +
        stelle(tester, raeder(rad).at(1)) % 12 * 5;
  }

  /// Woraufhin das Formular gerade eingestellt ist — der Zustand der
  /// Auswahl, nicht ihre Beschriftung.
  SchlafEintragenArt artAmSchalter(WidgetTester tester) => tester
      .widget<CupertinoSlidingSegmentedControl<SchlafEintragenArt>>(
        find.byKey(const Key('schlaf-eintragen-art')),
      )
      .groupValue!;

  Future<void> schalteAuf(WidgetTester tester, SchlafEintragenArt art) async {
    await tester.tap(
      find.byKey(
        Key(
          art == SchlafEintragenArt.nacht
              ? 'schlaf-eintragen-art-nacht'
              : 'schlaf-eintragen-art-tagschlaf',
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Dreht ein Rad um [rasten] Stellen (negativ = zurück).
  ///
  /// Wie in `schlaf_dauer_rad_test.dart`: in kleinen Schritten mit Pumps
  /// dazwischen, so wie ein Finger es macht — ein `tester.drag` ließe
  /// genau die Zwischenmeldungen weg, an denen ein zu eifriger Aufbau den
  /// Picker neu einrasten lässt.
  Future<void> drehe(WidgetTester tester, Finder wheel, int rasten) async {
    final schritte = rasten.abs() * 2;
    final weite = rasten.sign * rasterHoehe / 2;

    final geste = await tester.startGesture(tester.getCenter(wheel));
    await geste.moveBy(Offset(0, -rasten.sign.toDouble()));
    await tester.pump(const Duration(milliseconds: 16));
    for (var i = 0; i < schritte; i++) {
      await geste.moveBy(Offset(0, -weite));
      await tester.pump(const Duration(milliseconds: 16));
    }
    for (var i = 0; i < 5; i++) {
      await geste.moveBy(Offset.zero);
      await tester.pump(const Duration(milliseconds: 50));
    }
    await geste.up();
    await tester.pumpAndSettle();
  }

  ({ProviderContainer container, Widget app}) huelle(SchlafEintragenArt art) {
    final db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);
    // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        clockProvider.overrideWithValue(() => jetzt),
        appCacheProvider.overrideWithValue(db),
      ],
    );
    addTearDown(container.dispose);

    return (
      container: container,
      app: UncontrolledProviderScope(
        container: container,
        child: CupertinoApp(
          home: Builder(
            builder: (context) => CupertinoButton(
              key: const Key('oeffne'),
              onPressed: () =>
                  zeigeSchlafEintragen(context, art: art, tag: tag),
              child: const Text('auf'),
            ),
          ),
        ),
      ),
    );
  }

  Future<ProviderContainer> oeffne(
    WidgetTester tester, {
    SchlafEintragenArt art = SchlafEintragenArt.nacht,
  }) async {
    // Hoch genug, dass beide Zeitenräder und das Dauer-Rad gleichzeitig
    // dastehen: Sonst müsste jede Geste erst scrollen, und ein Scrollen
    // über einem Rad ist genau die Geste, die hier geprüft wird.
    tester.view.physicalSize = const Size(800 * 3, 1600 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final h = huelle(art);
    await tester.pumpWidget(h.app);
    await tester.tap(find.byKey(const Key('oeffne')));
    await tester.pumpAndSettle();
    return h.container;
  }

  /// Stellt die beiden Uhrzeitenräder der Nacht auf 19:00 und 20:00.
  ///
  /// Vorgabe der Nacht ist 23:00–06:30; das sind vier Stunden zurück am
  /// ersten Rad und vierzehn Stunden vor plus sechs Fünf-Minuten-Rasten
  /// zurück am zweiten.
  Future<void> stelleAufNeunzehnBisZwanzig(WidgetTester tester) async {
    final beginn = find.byType(CupertinoDatePicker).at(0);
    final ende = find.byType(CupertinoDatePicker).at(1);

    await drehe(tester, raeder(beginn).at(0), -4);
    await drehe(tester, raeder(ende).at(0), 14);
    await drehe(tester, raeder(ende).at(1), -6);

    expect(uhrzeitAmRad(tester, 0), 19 * 60);
    expect(uhrzeitAmRad(tester, 1), 20 * 60);
  }

  // ───────────────────────────────────────────────────────────────────────
  // 1 · Die Vorbelegung
  // ───────────────────────────────────────────────────────────────────────

  group('Das Formular steht so da, wie der Aufrufer es öffnet', () {
    testWidgets('mit „Nacht" aufgerufen, steht der Schalter auf Nacht', (
      tester,
    ) async {
      await oeffne(tester);

      expect(artAmSchalter(tester), SchlafEintragenArt.nacht);
    });

    testWidgets(
      'mit „Tagschlaf" aufgerufen, steht er auf Tagschlaf — sonst trüge '
      'man über das (+) des Tagschlaf-Schirms eine Nacht ein',
      (tester) async {
        await oeffne(tester, art: SchlafEintragenArt.tagschlaf);

        expect(artAmSchalter(tester), SchlafEintragenArt.tagschlaf);
      },
    );

    testWidgets('und beide Wege führen auf denselben Schalter', (tester) async {
      await oeffne(tester);

      await schalteAuf(tester, SchlafEintragenArt.tagschlaf);
      expect(artAmSchalter(tester), SchlafEintragenArt.tagschlaf);

      await schalteAuf(tester, SchlafEintragenArt.nacht);
      expect(artAmSchalter(tester), SchlafEintragenArt.nacht);
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // 2 · Die Vorgaben wechseln mit
  // ───────────────────────────────────────────────────────────────────────

  group('Umschalten bringt die Vorgaben der anderen Art mit', () {
    testWidgets('aus 23:00–06:30 wird 13:30–14:00, aus 7:30 h wird 0:30 h', (
      tester,
    ) async {
      await oeffne(tester);
      expect(uhrzeitAmRad(tester, 0), 23 * 60);
      expect(uhrzeitAmRad(tester, 1), 6 * 60 + 30);
      expect(dauerAmRad(tester), 7 * 60 + 30);

      await schalteAuf(tester, SchlafEintragenArt.tagschlaf);

      expect(uhrzeitAmRad(tester, 0), 13 * 60 + 30);
      expect(uhrzeitAmRad(tester, 1), 14 * 60);
      expect(
        dauerAmRad(tester),
        30,
        reason: 'das Rad geht mit, nicht nur die Zeile',
      );
      expect(dauerInDerZeile(tester), 30);
    });

    testWidgets('und zurück ebenso', (tester) async {
      await oeffne(tester, art: SchlafEintragenArt.tagschlaf);
      expect(uhrzeitAmRad(tester, 0), 13 * 60 + 30);

      await schalteAuf(tester, SchlafEintragenArt.nacht);

      expect(uhrzeitAmRad(tester, 0), 23 * 60);
      expect(uhrzeitAmRad(tester, 1), 6 * 60 + 30);
      expect(dauerAmRad(tester), 7 * 60 + 30);
      expect(dauerInDerZeile(tester), 7 * 60 + 30);
    });

    testWidgets('auch in der Fassung „nur Dauer" — dort ist die Vorgabe 7:00 h '
        'gegen 0:30 h', (tester) async {
      await oeffne(tester);
      await tester.tap(find.byKey(const Key('schlaf-eintragen-modus-dauer')));
      await tester.pumpAndSettle();
      expect(dauerAmRad(tester), 7 * 60);

      await schalteAuf(tester, SchlafEintragenArt.tagschlaf);

      expect(dauerAmRad(tester), 30);
      expect(dauerInDerZeile(tester), 30);
    });

    testWidgets('auch dann, wenn die Zeiten darunter von Hand gesetzt sind — '
        'genau hier bliebe ein Rad stehen, das die Art nicht kennt', (
      tester,
    ) async {
      await oeffne(tester);
      await stelleAufNeunzehnBisZwanzig(tester);

      await tester.tap(find.byKey(const Key('schlaf-eintragen-modus-dauer')));
      await tester.pumpAndSettle();
      expect(dauerAmRad(tester), 7 * 60, reason: 'die Vorgabe der Nacht');

      await schalteAuf(tester, SchlafEintragenArt.tagschlaf);

      expect(
        dauerInDerZeile(tester),
        30,
        reason: 'die Zeile rechnet mit der neuen Art',
      );
      expect(
        dauerAmRad(tester),
        30,
        reason:
            'hängt der Schlüssel des Rades nur an Fassung und Zeiten, '
            'ändert sich hier keiner von dreien — das Rad bliebe auf '
            '7:00 stehen und meldete das beim nächsten Anfassen zurück',
      );
    });

    testWidgets('der Kostensatz folgt der Art, nicht dem Aufruf', (
      tester,
    ) async {
      await oeffne(tester);
      await tester.tap(find.byKey(const Key('schlaf-eintragen-modus-dauer')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('schlaf-eintragen-kosten')), findsOneWidget);

      await schalteAuf(tester, SchlafEintragenArt.tagschlaf);

      expect(
        find.byKey(const Key('schlaf-eintragen-kosten')),
        findsNothing,
        reason: 'ein Nickerchen hat keinen Score, also kostet es nichts',
      );
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // 3 · Was von Hand gesetzt ist, bleibt stehen
  // ───────────────────────────────────────────────────────────────────────

  group('Eine gesetzte Eingabe überlebt das Umschalten', () {
    testWidgets(
      'eine von Hand gesetzte Uhrzeit bleibt — nur die unberührte geht '
      'auf die neue Vorgabe',
      (tester) async {
        await oeffne(tester);
        // Nur das Beginnrad anfassen: 23:00 → 19:00.
        await drehe(
          tester,
          raeder(find.byType(CupertinoDatePicker).at(0)).at(0),
          -4,
        );
        expect(uhrzeitAmRad(tester, 0), 19 * 60);

        await schalteAuf(tester, SchlafEintragenArt.tagschlaf);

        expect(
          uhrzeitAmRad(tester, 0),
          19 * 60,
          reason: 'das war eine Eingabe, keine Vorgabe',
        );
        expect(
          uhrzeitAmRad(tester, 1),
          14 * 60,
          reason: 'das Ende hat nie jemand angefasst',
        );
      },
    );

    testWidgets('eine von Hand gedrehte Dauer bleibt ebenso', (tester) async {
      await oeffne(tester);
      final rad = find.byType(CupertinoTimerPicker);

      // 7:30 → 7:55, fünf Rasten am Minutenrad.
      await drehe(tester, raeder(rad).at(1), 5);
      expect(dauerAmRad(tester), 7 * 60 + 55);

      await schalteAuf(tester, SchlafEintragenArt.tagschlaf);

      expect(
        dauerInDerZeile(tester),
        7 * 60 + 55,
        reason: 'die Vorgabe 0:30 nimmt eine Eingabe nicht zurück',
      );
      expect(dauerAmRad(tester), 7 * 60 + 55);
    });

    testWidgets('und die Notiz steht nach dem Umschalten noch da', (
      tester,
    ) async {
      await oeffne(tester);
      await tester.enterText(
        find.byKey(const Key('schlaf-eintragen-notiz')),
        'auf der Couch',
      );
      await tester.pumpAndSettle();

      await schalteAuf(tester, SchlafEintragenArt.tagschlaf);

      expect(find.text('auf der Couch'), findsOneWidget);
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // 4 · Der Tag bleibt der Tag
  // ───────────────────────────────────────────────────────────────────────

  group('Umschalten verschiebt den vorbelegten Tag nicht', () {
    testWidgets(
      'aus der Nacht wird ein Nickerchen desselben Tages, nicht eines am '
      'Vortag',
      (tester) async {
        final container = await oeffne(tester);

        await schalteAuf(tester, SchlafEintragenArt.tagschlaf);
        await tester.tap(find.byKey(const Key('schlaf-eintragen-sichern')));
        await tester.pumpAndSettle();

        final eintraege = await container.read(schlafEintraegeProvider.future);
        expect(eintraege, hasLength(1));
        expect(eintraege.single.art, SchlafEintragArt.tagschlaf);
        expect(eintraege.single.tag, BerlinCalendar.dayKey(tag));
        expect(eintraege.single.schlafMinuten, 30);
      },
    );

    testWidgets('und umgekehrt genauso', (tester) async {
      final container = await oeffne(tester, art: SchlafEintragenArt.tagschlaf);

      await schalteAuf(tester, SchlafEintragenArt.nacht);
      await tester.tap(find.byKey(const Key('schlaf-eintragen-sichern')));
      await tester.pumpAndSettle();

      final eintraege = await container.read(schlafEintraegeProvider.future);
      expect(eintraege, hasLength(1));
      expect(eintraege.single.art, SchlafEintragArt.nacht);
      expect(eintraege.single.tag, BerlinCalendar.dayKey(tag));
      expect(eintraege.single.schlafMinuten, 7 * 60 + 30);
    });
  });
}
