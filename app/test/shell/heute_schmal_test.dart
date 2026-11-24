import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/core/messwert.dart';
import 'package:repit/design/erholungs_karte.dart';
import 'package:repit/design/kacheln.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_types.dart';
import 'package:repit/shell/heute_view.dart';

/// Der Heute-Schirm auf **Gerätebreite**, nicht auf Flutters Testfläche.
///
/// ## Warum es diese Datei gibt
///
/// `flutter test` baut standardmäßig auf 800×600 Punkten — breiter als jedes
/// iPhone. Ein Text, der auf dem Gerät nicht in seine Zeilen passt, passt
/// dort bequem, und jeder Widget-Test bleibt grün, während auf dem Gerät die
/// Hälfte der Aussage fehlt.
///
/// Genau das ist auf Home passiert (Review zu #137): Die Erläuterung unter
/// einer leeren Kachel lautet „Keine Daten oder kein Zugriff — siehe
/// Health-Einstellungen" (57 Zeichen). Die Kachel teilt sich die
/// Bildschirmbreite mit der zweiten, bleibt also bei 393 Punkt Gerätebreite
/// rund 140 Punkt innen; bei `fontSize: 11` sind das etwa 25 Zeichen je
/// Zeile, bei `maxLines: 2` also rund 50. „Health-Einstellungen" ist ein
/// unteilbarer Block von 20 Zeichen und fällt als Ganzes weg.
///
/// Was damit verschwindet, ist keine Verzierung. `CLAUDE.md` verlangt
/// ausdrücklich: „Beides benennen **und auf die Health-Einstellungen
/// verweisen**." Im Fall „Teils Werte" gibt es keine Grundzeile über dem
/// Gerüst — die Kachel ist der einzige Ort, an dem der Verweis steht. Ohne
/// ihn sagt der Schirm, dass etwas fehlt, aber nicht, wo man es in Ordnung
/// bringt.
///
/// ## Was hier geprüft wird — und was ausdrücklich nicht
///
/// Geprüft wird **nicht**, wie der Text lautet. Geprüft wird, dass der Text,
/// den die Ansicht selbst gewählt hat (`KachelWert.zusatz`,
/// `ErholungsKarte.satz`), auf Gerätebreite **vollständig gezeichnet** wird:
/// `RenderParagraph.didExceedMaxLines` ist genau dann `true`, wenn
/// `maxLines` den Text gekappt hat. Dazu kommt die eine Zusicherung, die
/// `CLAUDE.md` wörtlich verlangt — dass der Verweis auf die
/// Health-Einstellungen überhaupt dasteht.
///
/// Dass die Höhe dabei nicht wächst, steht hier mit dabei: Sonst ließe sich
/// der Fund „beheben", indem man `maxLines` streicht — dann passt der Text,
/// und die Kachel wächst genau dann, wenn Werte fehlen. Das ist der Sprung,
/// gegen den #137 gebaut ist. Beide Zusicherungen zusammen lassen genau die
/// Lösungen zu, die beides halten: kürzer formulieren, kleinere Schrift oder
/// mehr fest reservierte Zeilen.
///
/// ## Die Gerätemaße
///
/// 393×852 Punkte — die Breite der aktuellen iPhone-Grundmodelle und das
/// Maß, auf dem Tim prüft. Kein Gerätename im Code: Es ist die Fläche, die
/// zählt, nicht das Modell.
void main() {
  // Erfundene Zahlen, wie überall in diesen Tests (CLAUDE.md: keine echten
  // Gesundheitswerte im Quelltext). Schritte bewusst dreistellig.
  final jetzt = DateTime.utc(2026, 10, 20, 14, 32);
  const heute = '2026-10-20';

  const ohneSchritte = [
    DailyMetrics(tag: heute, weightKg: 57.2, exerciseMinutes: 18.0),
  ];
  const mitAllem = [
    DailyMetrics(
      tag: heute,
      steps: 842,
      restingHR: 55,
      hrvMs: 70.0,
      respRate: 14.0,
      weightKg: 57.2,
      exerciseMinutes: 18.0,
    ),
  ];
  const ohneAlles = [DailyMetrics(tag: heute)];

  /// Setzt die Testfläche auf Gerätemaße und räumt sie hinterher wieder ab —
  /// `tester.view` wirkt über den einzelnen Test hinaus.
  void aufGeraetebreite(WidgetTester tester) {
    const dpr = 3.0;
    tester.view.devicePixelRatio = dpr;
    tester.view.physicalSize = const Size(393 * dpr, 852 * dpr);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  /// Die Nachtwerte dieser Hülle — sie **spiegeln** die Tageswerte (#193,
  /// Stufe 4).
  ///
  /// Seit Stufe 4 kommen Ruhepuls, HRV und Atemfrequenz aus dem
  /// Nachtfenster statt aus `DailyMetrics` (Tims Entscheidung vom
  /// 02.11.2026; Begründung und Messung stehen im Kopf von
  /// `erholung_nachtwerte_test.dart`). Damit die Zusicherungen dieser Datei
  /// weiter dasselbe prüfen wie vorher, liefert die Hülle dieselben Zahlen
  /// noch einmal als Nachtwerte: **Die Quelle wechselt, die Vorlage
  /// nicht.** Der Zustand wandert mit — ein gescheiterter Tageslauf
  /// bedeutet hier auch einen gescheiterten Nachtlauf.
  Messwert<Map<String, NightVitals>> nachtwerteAus(
    Messwert<List<DailyMetrics>> tageswerte,
  ) => switch (tageswerte) {
    Bekannt<List<DailyMetrics>>(:final wert, :final stand, :final laeuft) =>
      Bekannt<Map<String, NightVitals>>({
        for (final tag in wert)
          tag.tag: NightVitals(
            restingHeartRate: tag.restingHR?.toDouble(),
            hrv: tag.hrvMs,
            respiratoryRate: tag.respRate,
          ),
      }, stand: stand, laeuft: laeuft),
    NochNie<List<DailyMetrics>>() => const NochNie<Map<String, NightVitals>>(),
    LeerNachLauf<List<DailyMetrics>>(:final gelaufen) =>
      LeerNachLauf<Map<String, NightVitals>>(gelaufen: gelaufen),
    Fehlgeschlagen<List<DailyMetrics>>(:final fehler, :final gelaufen) =>
      Fehlgeschlagen<Map<String, NightVitals>>(
        fehler: fehler,
        gelaufen: gelaufen,
      ),
  };

  ({ProviderContainer container, Widget app}) harness(
    Messwert<List<DailyMetrics>> zustand,
  ) {
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        dailyMetricsProvider.overrideWith(
          () => _FesterNotifier(zustand: zustand),
        ),
        clockProvider.overrideWithValue(() => jetzt),
        // #193, Stufe 4: Ruhepuls, HRV und Atemfrequenz kommen aus dem
        // Nachtfenster.
        nachtWerteProvider.overrideWith(
          () => _Nachtwerte(nachtwerteAus(zustand)),
        ),
      ],
    );
    final app = UncontrolledProviderScope(
      container: container,
      child: const CupertinoApp(
        home: CupertinoPageScaffold(child: HeuteView()),
      ),
    );
    return (container: container, app: app);
  }

  ({ProviderContainer container, Widget app}) mitWerten(
    List<DailyMetrics> werte,
  ) => harness(
    Bekannt<List<DailyMetrics>>(werte, stand: jetzt, laeuft: false),
  );

  testWidgets(
    'auf Gerätebreite läuft keine Zeile über — beim Schreiben dieser Datei '
    'gefunden, nicht im Review: die Ringlegende um 21, die Erholungskarte '
    'um 79 Punkte',
    (tester) async {
      aufGeraetebreite(tester);

      for (final (name, zustand) in <(String, Messwert<List<DailyMetrics>>)>[
        ('mit Werten', Bekannt(mitAllem, stand: jetzt, laeuft: false)),
        ('ohne Werte', Bekannt(ohneAlles, stand: jetzt, laeuft: false)),
        ('LeerNachLauf', LeerNachLauf(gelaufen: jetzt)),
      ]) {
        final h = harness(zustand);
        addTearDown(h.container.dispose);
        await tester.pumpWidget(h.app);
        await tester.pumpAndSettle();

        expect(
          tester.takeException(),
          isNull,
          reason: '$name: Ein übergelaufener RenderFlex zeichnet auf dem '
              'Gerät den gelb-schwarzen Balken und verschluckt, was nicht '
              'mehr passt. Auf Flutters Testfläche von 800 Punkten passt '
              'alles — deshalb steht es hier und nicht in '
              'heute_view_test.dart',
        );

        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );

  testWidgets(
    'die Erläuterung einer leeren Kachel wird auf Gerätebreite vollständig '
    'gezeichnet und verweist auf die Health-Einstellungen',
    (tester) async {
      aufGeraetebreite(tester);
      final h = mitWerten(ohneSchritte);
      addTearDown(h.container.dispose);

      await tester.pumpWidget(h.app);
      await tester.pumpAndSettle();

      final kacheln = tester.widget<Kacheln>(find.byType(Kacheln));
      final schritte = kacheln.werte.firstWhere(
        (w) => w.label.toLowerCase().contains('schritt'),
      );

      expect(
        schritte.zusatz.toLowerCase(),
        contains('health-einstellungen'),
        reason: 'CLAUDE.md: "Beides benennen UND auf die '
            'Health-Einstellungen verweisen." Im Fall "Teils Werte" gibt es '
            'keine Grundzeile über dem Gerüst — diese Kachel ist der '
            'einzige Ort, an dem der Verweis steht',
      );
      expect(
        schritte.zusatz.toLowerCase(),
        contains('zugriff'),
        reason: 'die zweite der beiden Möglichkeiten, die Apple nicht '
            'unterscheidet, steht hier ebenfalls allein',
      );

      _nichtAbgeschnitten(
        tester,
        find.descendant(
          of: find.byType(Kacheln),
          matching: find.text(schritte.zusatz),
        ),
        was: 'die Erläuterung der Schritte-Kachel',
      );
    },
  );

  testWidgets(
    'auch wenn beide Kacheln leer sind, steht in beiden der vollständige '
    'Grund',
    (tester) async {
      aufGeraetebreite(tester);
      final h = mitWerten(ohneAlles);
      addTearDown(h.container.dispose);

      await tester.pumpWidget(h.app);
      await tester.pumpAndSettle();

      final kacheln = tester.widget<Kacheln>(find.byType(Kacheln));
      for (final wert in kacheln.werte) {
        expect(
          wert.zusatz.toLowerCase(),
          contains('health-einstellungen'),
          reason: '${wert.label}: der Verweis steht in jeder leeren Kachel',
        );
        _nichtAbgeschnitten(
          tester,
          find.descendant(
            of: find.byType(Kacheln),
            matching: find.text(wert.zusatz),
          ),
          was: 'die Erläuterung der Kachel "${wert.label}"',
        );
      }
    },
  );

  testWidgets(
    'der Satz der Erholungskarte wird auf Gerätebreite vollständig '
    'gezeichnet — sonst fehlt die halbe Aussage',
    (tester) async {
      aufGeraetebreite(tester);
      final h = mitWerten(ohneAlles);
      addTearDown(h.container.dispose);

      await tester.pumpWidget(h.app);
      await tester.pumpAndSettle();

      final karte = tester.widget<ErholungsKarte>(find.byType(ErholungsKarte));
      _nichtAbgeschnitten(
        tester,
        find.descendant(
          of: find.byType(ErholungsKarte),
          matching: find.text(karte.satz),
        ),
        was: 'der Satz der Erholungskarte ("${karte.satz}")',
      );
    },
  );

  testWidgets(
    'dasselbe für einen fertigen Lauf ohne jeden Treffer, wo der Grund auch '
    'über dem Gerüst steht',
    (tester) async {
      aufGeraetebreite(tester);
      final h = harness(LeerNachLauf<List<DailyMetrics>>(gelaufen: jetzt));
      addTearDown(h.container.dispose);

      await tester.pumpWidget(h.app);
      await tester.pumpAndSettle();

      final karte = tester.widget<ErholungsKarte>(find.byType(ErholungsKarte));
      _nichtAbgeschnitten(
        tester,
        find.descendant(
          of: find.byType(ErholungsKarte),
          matching: find.text(karte.satz),
        ),
        was: 'der Satz der Erholungskarte bei LeerNachLauf',
      );

      final kacheln = tester.widget<Kacheln>(find.byType(Kacheln));
      for (final wert in kacheln.werte) {
        _nichtAbgeschnitten(
          tester,
          find.descendant(
            of: find.byType(Kacheln),
            matching: find.text(wert.zusatz),
          ),
          was: 'die Erläuterung der Kachel "${wert.label}" bei LeerNachLauf',
        );
      }
    },
  );

  testWidgets(
    'und der Grund passt in die reservierte Höhe: Kachelstreifen und '
    'Erholungskarte sind ohne Werte genauso hoch wie mit',
    (tester) async {
      aufGeraetebreite(tester);

      final mit = mitWerten(mitAllem);
      addTearDown(mit.container.dispose);
      await tester.pumpWidget(mit.app);
      await tester.pumpAndSettle();
      final kachelnMitWerten = tester.getRect(find.byType(Kacheln)).height;
      final karteMitWerten = tester.getRect(find.byType(ErholungsKarte)).height;

      await tester.pumpWidget(const SizedBox.shrink());

      final ohne = mitWerten(ohneAlles);
      addTearDown(ohne.container.dispose);
      await tester.pumpWidget(ohne.app);
      await tester.pumpAndSettle();

      expect(
        tester.getRect(find.byType(Kacheln)).height,
        closeTo(kachelnMitWerten, 0.5),
        reason: 'die Kachel darf nicht wachsen, nur weil der Grund länger '
            'ist als "heute gezählt" — sonst ist der Fund nur verschoben: '
            'erst war der Text gekappt, jetzt springt der Schirm',
      );
      expect(
        tester.getRect(find.byType(ErholungsKarte)).height,
        closeTo(karteMitWerten, 0.5),
        reason: 'dasselbe für die Erholungskarte, deren Satz im Leerfall '
            'ein anderer ist als im Normalfall',
      );
    },
  );
}

/// Kein `Text` unter [finder] ist von `maxLines` gekappt.
///
/// `RenderParagraph.didExceedMaxLines` ist die einzige Stelle, an der sich
/// das von außen ablesen lässt: Der Ellipsis-Punkt ersetzt Glyphen beim
/// Zeichnen, die Zeichenkette im Widget bleibt vollständig. Ein Test, der
/// nur `find.textContaining(...)` benutzt, sieht die Kappung deshalb nie.
void _nichtAbgeschnitten(
  WidgetTester tester,
  Finder finder, {
  required String was,
}) {
  final absaetze = tester.renderObjectList<RenderParagraph>(finder).toList();
  expect(absaetze, isNotEmpty, reason: '$was: nicht gefunden');
  for (final absatz in absaetze) {
    expect(
      absatz.didExceedMaxLines,
      isFalse,
      reason: '$was wird auf Gerätebreite abgeschnitten — auf Flutters '
          'Testfläche von 800 Punkten fällt das nie auf',
    );
  }
}

/// Ein `DailyMetricsNotifier`, der einen festen Zustand ausgibt. Wie die
/// Zustandsfolge zustande kommt, prüft `health_provider_test.dart`; hier
/// geht es allein darum, wie der Schirm auf Gerätebreite aussieht.
class _FesterNotifier extends DailyMetricsNotifier {
  _FesterNotifier({required this.zustand});

  final Messwert<List<DailyMetrics>> zustand;

  @override
  Future<Messwert<List<DailyMetrics>>> build() async => zustand;
}

class _Nachtwerte extends NachtWerteNotifier {
  _Nachtwerte(this.wert);

  final Messwert<Map<String, NightVitals>> wert;

  @override
  Future<Messwert<Map<String, NightVitals>>> build() async => wert;
}
