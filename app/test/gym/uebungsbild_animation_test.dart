import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repit/gym/gym_log_texte.dart';
import 'package:repit/gym/uebungsbild_animation.dart';
import 'package:repit/gym/uebungsbild_miniatur.dart';

/// Die Animation der Übungsbilder (#38): großes Bild mit Überblendung,
/// reduzierte Bewegung, Vorschaubild, Robustheit.
///
/// Geschrieben vom selben Agenten wie die Implementierung, auf Wunsch von
/// Tim — die Rollentrennung aus `CLAUDE.md` gilt hier nicht.
///
/// **Die RepDB-Bilder werden hier nicht gelesen:** Das Bündel liefert für
/// jeden Pfad ein erzeugtes 1×1-PNG. Geprüft wird, *welcher Pfad* gezeigt
/// wird und *wie* sich die Deckkraft verhält, nicht, wie ein Bild aussieht.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const start = 'test/start.webp';
  const ende = 'test/ende.webp';
  const rahmen = Key('rahmen');
  const endeLage = Key('ende');

  /// Pumpt das Widget und gibt dem Vorladen die echte Zeit, die es braucht
  /// (Bilddekodierung läuft außerhalb der Fake-Uhr).
  Future<void> pumpe(
    WidgetTester tester, {
    String? zweites = ende,
    String erstes = start,
    _Buendel? buendel,
    double dichte = 1.0,
  }) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = dichte;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _Huelle(
        buendel: buendel ?? _Buendel(),
        child: UebungsbildAnimation(
          start: erstes,
          ende: zweites,
          frameKey: rahmen,
          endeKey: endeLage,
        ),
      ),
    );
    await _vorladen(tester);
  }

  Finder imRahmen(Finder was) =>
      find.descendant(of: find.byKey(rahmen), matching: was);

  /// Deckkraft des Endbildes, `null`, wenn es keine Überblendung gibt.
  double? deckkraft(WidgetTester tester) {
    final lage = find.byKey(endeLage);
    if (lage.evaluate().isEmpty) return null;
    return tester.widget<FadeTransition>(lage).opacity.value;
  }

  List<String> gezeigt(WidgetTester tester) => [
    for (final bild in tester.widgetList<Image>(imRahmen(find.byType(Image))))
      (bild.image as AssetImage).assetName,
  ];

  Future<void> vor(WidgetTester tester, int ms) =>
      tester.pump(Duration(milliseconds: ms));

  group('Konstanten', () {
    test('1200 ms halten, 400 ms überblenden, 3,2 s je Zyklus', () {
      expect(kBildHalten, const Duration(milliseconds: 1200));
      expect(kBildUeberblendung, const Duration(milliseconds: 400));
      expect(kBildZyklus, (kBildHalten + kBildUeberblendung) * 2);
      expect(kBildZyklus, const Duration(milliseconds: 3200));
    });
  });

  group('Zwei Bilder: die Schleife läuft', () {
    testWidgets('Start unten, Ende darüber, beide im Baum', (tester) async {
      await pumpe(tester);
      expect(gezeigt(tester), [start, ende]);
    });

    testWidgets('1200 nur Start, 400 über, 1200 nur Ende, 400 zurück', (
      tester,
    ) async {
      await pumpe(tester);
      expect(deckkraft(tester), 0);

      await vor(tester, 1100);
      expect(deckkraft(tester), 0, reason: 'noch in den ersten 1200 ms');

      await vor(tester, 300); // 1400: mitten in der Überblendung
      expect(deckkraft(tester), allOf(greaterThan(0), lessThan(1)));

      await vor(tester, 600); // 2000: Ende steht
      expect(deckkraft(tester), 1);

      await vor(tester, 700); // 2700: noch gehalten
      expect(deckkraft(tester), 1);

      await vor(tester, 300); // 3000: mitten in der Rücküberblendung
      expect(deckkraft(tester), allOf(greaterThan(0), lessThan(1)));

      await vor(tester, 300); // 3300: nächster Zyklus, nur Start
      expect(deckkraft(tester), 0);
    });

    testWidgets('sie hört nicht auf: nach vielen Zyklen läuft sie weiter', (
      tester,
    ) async {
      await pumpe(tester);
      for (var i = 0; i < 5; i++) {
        await vor(tester, 3200);
      }
      await vor(tester, 1900); // 1,9 s in den sechsten Zyklus: Ende steht
      expect(deckkraft(tester), 1);
      expect(tester.binding.hasScheduledFrame, isTrue);
    });

    testWidgets('sie beginnt erst, wenn beide Bilder geladen sind', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _Huelle(
          buendel: _Buendel(),
          child: const UebungsbildAnimation(
            start: start,
            ende: ende,
            frameKey: rahmen,
            endeKey: endeLage,
          ),
        ),
      );
      // Das Dekodieren hat noch nicht stattgefunden: nichts läuft.
      await vor(tester, 1500);
      expect(deckkraft(tester), 0);
      await _vorladen(tester);
      await vor(tester, 1);
      await vor(tester, 1500);
      expect(deckkraft(tester), allOf(greaterThan(0), lessThan(1)));
    });

    testWidgets('Quadrat, von Anfang an', (tester) async {
      await pumpe(tester);
      final groesse = tester.getSize(find.byKey(rahmen));
      expect(groesse.width, greaterThan(0));
      expect(groesse.width, closeTo(groesse.height, 0.01));
    });

    testWidgets('Ecken 20', (tester) async {
      await pumpe(tester);
      final rundung = tester.widget<ClipRRect>(
        find.ancestor(of: find.byKey(rahmen), matching: find.byType(ClipRRect)),
      );
      expect(rundung.borderRadius, BorderRadius.circular(20));
    });
  });

  group('Ein Bild: statisch', () {
    testWidgets('kein Überblenden, nur ein Bild im Baum', (tester) async {
      await pumpe(tester, zweites: null);
      expect(gezeigt(tester), [start]);
      expect(deckkraft(tester), isNull);
    });

    testWidgets('es läuft nichts: pumpAndSettle kommt zur Ruhe', (
      tester,
    ) async {
      await pumpe(tester, zweites: null);
      await vor(tester, 5000);
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });

  group('Reduzierte Bewegung', () {
    void reduzieren(WidgetTester tester, {required bool an}) {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          FakeAccessibilityFeatures(disableAnimations: an);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
    }

    testWidgets('keine Schleife, das Endbild steht', (tester) async {
      reduzieren(tester, an: true);
      await pumpe(tester);
      expect(deckkraft(tester), isNull);
      expect(gezeigt(tester), [ende]);
      await vor(tester, 5000);
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(gezeigt(tester), [ende]);
    });

    testWidgets('ein Tippen wechselt zwischen Start und Ende', (tester) async {
      reduzieren(tester, an: true);
      await pumpe(tester);
      expect(gezeigt(tester), [ende]);

      await tester.tap(find.byKey(rahmen));
      await tester.pump();
      expect(gezeigt(tester), [start]);

      await tester.tap(find.byKey(rahmen));
      await tester.pump();
      expect(gezeigt(tester), [ende]);
    });

    testWidgets('mit einem Bild gibt es nichts zu wechseln', (tester) async {
      reduzieren(tester, an: true);
      await pumpe(tester, zweites: null);
      await tester.tap(find.byKey(rahmen));
      await tester.pump();
      expect(gezeigt(tester), [start]);
    });

    testWidgets('wird die Einstellung zur Laufzeit angeschaltet, hält sie an', (
      tester,
    ) async {
      await pumpe(tester);
      await vor(tester, 1400);
      expect(deckkraft(tester), allOf(greaterThan(0), lessThan(1)));

      reduzieren(tester, an: true);
      await tester.pump();
      await tester.pump();
      expect(deckkraft(tester), isNull);
      expect(gezeigt(tester), [ende]);
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('wird sie zur Laufzeit abgeschaltet, läuft die Schleife', (
      tester,
    ) async {
      reduzieren(tester, an: true);
      await pumpe(tester);
      expect(deckkraft(tester), isNull);

      reduzieren(tester, an: false);
      await tester.pump();
      await tester.pump();
      expect(deckkraft(tester), 0);
      await vor(tester, 1400);
      expect(deckkraft(tester), allOf(greaterThan(0), lessThan(1)));
    });

    testWidgets('der Screenreader hört, dass ein Tippen wechselt', (
      tester,
    ) async {
      reduzieren(tester, an: true);
      final handle = tester.ensureSemantics();
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _Huelle(
          buendel: _Buendel(),
          child: const UebungsbildAnimation(
            start: start,
            ende: ende,
            frameKey: rahmen,
            endeKey: endeLage,
            semantik: 'Bewegungsablauf',
          ),
        ),
      );
      await _vorladen(tester);
      final knoten = tester.getSemantics(
        find.bySemanticsLabel('Bewegungsablauf'),
      );
      expect(knoten.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      handle.dispose();
    });
  });

  group('Nur Sichtbares animiert', () {
    /// Das Bild steht erst nach 2000 Pixeln im Fenster.
    Future<ScrollController> pumpeImScroll(WidgetTester tester) async {
      final regler = ScrollController();
      addTearDown(regler.dispose);
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _Huelle(
          buendel: _Buendel(),
          scroll: regler,
          child: Column(
            children: const [
              SizedBox(height: 2000),
              SizedBox(
                width: 200,
                child: UebungsbildAnimation(
                  start: start,
                  ende: ende,
                  frameKey: rahmen,
                  endeKey: endeLage,
                ),
              ),
              SizedBox(height: 2000),
            ],
          ),
        ),
      );
      await _vorladen(tester);
      return regler;
    }

    testWidgets('außerhalb des Fensters läuft nichts', (tester) async {
      await pumpeImScroll(tester);
      await vor(tester, 1500);
      expect(deckkraft(tester), 0);
      expect(
        tester.binding.hasScheduledFrame,
        isFalse,
        reason: 'ein Bild außerhalb des Fensters verlangt keine Bilder',
      );
    });

    testWidgets('gescrollt ins Fenster beginnt sie, hinaus hält sie an', (
      tester,
    ) async {
      final regler = await pumpeImScroll(tester);

      regler.jumpTo(1500);
      await tester.pump();
      await vor(tester, 1);
      await vor(tester, 1500);
      final mitten = deckkraft(tester)!;
      expect(mitten, allOf(greaterThan(0), lessThan(1)));

      regler.jumpTo(0);
      await tester.pump();
      await vor(tester, 1);
      final gehalten = deckkraft(tester);
      await vor(tester, 1000);
      expect(deckkraft(tester), gehalten, reason: 'steht still');
      expect(tester.binding.hasScheduledFrame, isFalse);

      regler.jumpTo(1500);
      await tester.pump();
      await vor(tester, 1);
      await vor(tester, 500);
      expect(deckkraft(tester), isNot(gehalten), reason: 'läuft wieder');
    });
  });

  group('Verdeckte Seite', () {
    testWidgets('unter einer weiteren Seite des Navigators steht sie still', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        DefaultAssetBundle(
          bundle: _Buendel(),
          child: CupertinoApp(
            navigatorKey: navigator,
            home: const CupertinoPageScaffold(
              child: Center(
                child: SizedBox(
                  width: 200,
                  child: UebungsbildAnimation(
                    start: start,
                    ende: ende,
                    frameKey: rahmen,
                    endeKey: endeLage,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await _vorladen(tester);
      await vor(tester, 1500);
      expect(deckkraft(tester), allOf(greaterThan(0), lessThan(1)));

      navigator.currentState!.push(
        CupertinoPageRoute<void>(
          builder: (_) => const CupertinoPageScaffold(child: SizedBox()),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });

  group('Robustheit', () {
    testWidgets('fehlt das Startbild: Platzhalter, keine Ausnahme', (
      tester,
    ) async {
      await pumpe(tester, buendel: _Buendel(fehlt: {start}));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text(gymBildNichtLesbar), findsOneWidget);
    });

    testWidgets('fehlt das Endbild: das Startbild steht, nichts läuft', (
      tester,
    ) async {
      await pumpe(tester, buendel: _Buendel(fehlt: {ende}));
      await vor(tester, 1500);
      expect(tester.takeException(), isNull);
      expect(deckkraft(tester), 0);
      expect(find.text(gymBildNichtLesbar), findsNothing);
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('lässt sich nichts lesen: ein Platzhalter, keine Ausnahme', (
      tester,
    ) async {
      await pumpe(tester, buendel: _Buendel(kaputt: true));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text(gymBildNichtLesbar), findsOneWidget);
    });

    testWidgets('andere Übung im selben Widget: neu laden, neu beginnen', (
      tester,
    ) async {
      final buendel = _Buendel();
      await pumpe(tester, buendel: buendel);
      await vor(tester, 1400);
      expect(deckkraft(tester), allOf(greaterThan(0), lessThan(1)));

      await tester.pumpWidget(
        _Huelle(
          buendel: buendel,
          child: const UebungsbildAnimation(
            start: 'test/start2.webp',
            ende: 'test/ende2.webp',
            frameKey: rahmen,
            endeKey: endeLage,
          ),
        ),
      );
      expect(gezeigt(tester), ['test/start2.webp', 'test/ende2.webp']);
      expect(deckkraft(tester), 0, reason: 'von vorn');
      await vor(tester, 1500);
      expect(deckkraft(tester), 0, reason: 'erst läuft nichts, bis geladen');

      await _vorladen(tester);
      await vor(tester, 1);
      await vor(tester, 1500);
      expect(deckkraft(tester), allOf(greaterThan(0), lessThan(1)));
      expect(
        buendel.geladen,
        containsAll(['test/start2.webp', 'test/ende2.webp']),
      );
    });

    testWidgets('von zwei Bildern auf eins: keine Schleife mehr', (
      tester,
    ) async {
      final buendel = _Buendel();
      await pumpe(tester, buendel: buendel);
      await tester.pumpWidget(
        _Huelle(
          buendel: buendel,
          child: const UebungsbildAnimation(
            start: 'test/start3.webp',
            frameKey: rahmen,
            endeKey: endeLage,
          ),
        ),
      );
      await _vorladen(tester);
      await tester.pumpAndSettle();
      expect(deckkraft(tester), isNull);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('abgebaut: der Controller ist frei, nichts läuft weiter', (
      tester,
    ) async {
      await pumpe(tester);
      await vor(tester, 1400);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });

  group('Vorschaubild', () {
    testWidgets('zeigt das Startbild, statisch', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _Huelle(
          buendel: _Buendel(),
          child: const UebungsbildMiniatur(start: start),
        ),
      );
      final bilder = tester.widgetList<Image>(find.byType(Image)).toList();
      expect(bilder, hasLength(1));
      final provider = bilder.single.image as ResizeImage;
      expect((provider.imageProvider as AssetImage).assetName, start);
      expect(find.byKey(endeLage), findsNothing);
      await _vorladen(tester);
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('48 groß, Ecken 8', (tester) async {
      await tester.pumpWidget(
        _Huelle(
          buendel: _Buendel(),
          child: const Center(child: UebungsbildMiniatur(start: start)),
        ),
      );
      expect(
        tester.getSize(find.byType(UebungsbildMiniatur)),
        const Size(48, 48),
      );
      expect(
        tester.widget<ClipRRect>(find.byType(ClipRRect)).borderRadius,
        BorderRadius.circular(8),
      );
    });

    testWidgets('eigene Größe wird übernommen', (tester) async {
      await tester.pumpWidget(
        _Huelle(
          buendel: _Buendel(),
          child: const Center(
            child: UebungsbildMiniatur(start: start, groesse: 32),
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(UebungsbildMiniatur)),
        const Size(32, 32),
      );
    });

    testWidgets('dekodiert in Größe mal Pixeldichte, nicht in voller Größe', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _Huelle(
          buendel: _Buendel(),
          child: const UebungsbildMiniatur(start: start),
        ),
      );
      final provider =
          tester.widget<Image>(find.byType(Image)).image as ResizeImage;
      expect(provider.width, 144);
      expect(provider.height, isNull);
    });

    testWidgets('fehlt das Bild: neutrale Fläche, keine Ausnahme', (
      tester,
    ) async {
      await tester.pumpWidget(
        _Huelle(
          buendel: _Buendel(fehlt: {start}),
          child: const Center(child: UebungsbildMiniatur(start: start)),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byIcon(CupertinoIcons.photo), findsOneWidget);
      expect(
        tester.getSize(find.byType(UebungsbildMiniatur)),
        const Size(48, 48),
      );
    });
  });
}

/// Gibt der Bilddekodierung die echte Zeit, die sie außerhalb der Fake-Uhr
/// braucht, und pumpt danach die Ergebnisse ein.
Future<void> _vorladen(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pump();
}

class _Huelle extends StatelessWidget {
  const _Huelle({required this.buendel, required this.child, this.scroll});

  final AssetBundle buendel;
  final Widget child;
  final ScrollController? scroll;

  @override
  Widget build(BuildContext context) {
    final inhalt = Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: scroll == null ? 200 : null, child: child),
    );
    return DefaultAssetBundle(
      bundle: buendel,
      child: CupertinoApp(
        home: CupertinoPageScaffold(
          child: scroll == null
              ? inhalt
              : SingleChildScrollView(controller: scroll, child: child),
        ),
      ),
    );
  }
}

/// Liefert für jeden Pfad ein 1×1-PNG; [fehlt] sind Pfade, die es nicht gibt,
/// [kaputt] lässt jede Anfrage scheitern. [geladen] merkt sich die Pfade.
class _Buendel extends CachingAssetBundle {
  _Buendel({this.fehlt = const {}, this.kaputt = false});

  final Set<String> fehlt;
  final bool kaputt;
  final List<String> geladen = [];

  static final _png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA'
    '60e6kgAAAABJRU5ErkJggg==',
  );

  @override
  Future<ByteData> load(String key) async {
    if (key.startsWith('test/')) {
      geladen.add(key);
      if (kaputt) throw FlutterError('absichtlich kaputt: $key');
      if (fehlt.contains(key)) throw FlutterError('gibt es nicht: $key');
      return ByteData.sublistView(Uint8List.fromList(_png));
    }
    return rootBundle.load(key);
  }
}
