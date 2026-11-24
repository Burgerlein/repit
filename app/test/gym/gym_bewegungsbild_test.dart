import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/gym/gym_log_bausteine.dart';
import 'package:repit/gym/gym_log_schluessel.dart';
import 'package:repit/gym/gym_log_texte.dart';
import 'package:repit/gym/uebungsbilder.dart';
import 'package:repit/gym/uebungsbilder_provider.dart';

/// Das Bewegungsbild im aufgeklappten „So geht's" (#38).
///
/// Geschrieben vom selben Agenten wie die Implementierung, auf Wunsch von
/// Tim — die Rollentrennung aus `CLAUDE.md` gilt hier nicht.
///
/// **Die RepDB-Bilder werden hier nicht gelesen.** Das Bündel, in dem die
/// Widgets stehen, liefert für jede Datei unter `assets/exercises/images/`
/// ein eigenes 1×1-PNG; geprüft wird, *welcher Pfad* gezeigt wird, nicht
/// wie das Bild aussieht. Die Zuordnung liest nur `exercises.json`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Die echte Zuordnung aus dem Asset (nur der Text, nie ein Bild).
  final bilder = Uebungsbilder.parse(
    File('assets/exercises/exercises.json').readAsStringSync(),
  );

  Exercise katalog(String id) => ExerciseCatalog.all[id]!;

  /// Eine Übung mit zwei Bildern, ohne Hinweis.
  final schlicht = bilder.exerciseIds
      .map((id) => bilder.fuer(id)!)
      .firstWhere((b) => b.peak != null && !b.approximate && b.note == null);
  final einzel = bilder.fuer('sidePlank')!;
  final ungefaehr = bilder.fuer('tibialisRaise')!;
  final mitNotiz = bilder.fuer('pullUp')!;

  Future<void> pumpe(
    WidgetTester tester,
    String id, {
    Uebungsbilder? mit,
    bool oeffnen = true,
    bool gross = false,
    bool settle = true,
  }) async {
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [uebungsbilderProvider.overrideWithValue(mit ?? bilder)],
        child: DefaultAssetBundle(
          bundle: _BuendelOhneRepdb(),
          child: CupertinoApp(
            home: CupertinoPageScaffold(
              child: SingleChildScrollView(
                child: GymSoGehts(uebung: katalog(id), gross: gross),
              ),
            ),
          ),
        ),
      ),
    );
    if (oeffnen) {
      await tester.tap(find.byKey(kGymSoGehts(id)));
      settle ? await tester.pumpAndSettle() : await tester.pump();
    }
  }

  /// Die Asset-Pfade der gezeigten Bilder, in Reihenfolge.
  List<String> gezeigt(WidgetTester tester) => [
    for (final bild in tester.widgetList<Image>(find.byType(Image)))
      (bild.image as AssetImage).assetName,
  ];

  group('Bild da', () {
    testWidgets('zwei Bilder uebereinander, Start unten, Umkehrpunkt darauf', (
      tester,
    ) async {
      // Bis zum 11.11.2026 standen die beiden Bilder nebeneinander. Tim
      // wollte die Bewegung sehen, nicht zwei Standbilder: Jetzt liegen
      // sie deckungsgleich uebereinander, und das Endbild blendet in einer
      // Schleife ein und aus. RepDB liefert keine GIFs, nur Start und
      // Umkehrpunkt. (TEST_AENDERN=1 — geprueft wird dieselbe Sache,
      // naemlich dass beide Bilder da sind und in welcher Lage.)
      await pumpe(tester, schlicht.exerciseId);
      expect(gezeigt(tester), schlicht.frames);
      expect(schlicht.frames, hasLength(2));
      final unten = tester.getRect(
        find.byKey(kGymBildFrame(schlicht.exerciseId, 1)),
      );
      final oben = tester.getRect(
        find.byKey(kGymBildFrame(schlicht.exerciseId, 2)),
      );
      expect(
        oben,
        unten,
        reason: 'deckungsgleich — sonst springt das Bild beim Ueberblenden',
      );
    });

    testWidgets('ein einzelnes Bild bei Halteübungen', (tester) async {
      await pumpe(tester, einzel.exerciseId);
      expect(gezeigt(tester), [einzel.start]);
      expect(einzel.peak, isNull);
    });

    testWidgets('Attribution steht unter dem Bild, wörtlich', (tester) async {
      await pumpe(tester, schlicht.exerciseId);
      final attribution = find.byKey(kGymBildAttribution(schlicht.exerciseId));
      expect(attribution, findsOneWidget);
      expect(
        (tester.widget<Text>(attribution)).data,
        'Exercise data by RepDB (repdb.co)',
      );
      expect(
        tester.getTopLeft(attribution).dy,
        greaterThan(
          tester
              .getBottomLeft(find.byKey(kGymBildFrame(schlicht.exerciseId, 1)))
              .dy,
        ),
      );
    });

    testWidgets(
      'ohne Hinweis, wenn das Bild genau ist und nichts zu sagen ist',
      (tester) async {
        await pumpe(tester, schlicht.exerciseId);
        expect(find.byKey(kGymBildHinweis(schlicht.exerciseId)), findsNothing);
      },
    );

    testWidgets('die Anleitung steht unter dem Bild, vollständig', (
      tester,
    ) async {
      await pumpe(tester, schlicht.exerciseId);
      final uebung = katalog(schlicht.exerciseId);
      for (final schritt in uebung.howTo) {
        expect(find.text(schritt), findsOneWidget);
      }
      // `!`: `commonMistake` wird mit #551 `String?`. `schlicht` ist eine der
      // 33 Katalogübungen, und die haben ihren häufigen Fehler weiter.
      expect(
        find.text(gymHaeufigerFehler(uebung.commonMistake!)),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(find.text(uebung.howTo.first)).dy,
        greaterThan(
          tester.getBottomLeft(find.byKey(kGymBildAttribution(uebung.id))).dy,
        ),
      );
    });

    testWidgets('zugeklappt steht kein Bild im Baum', (tester) async {
      await pumpe(tester, schlicht.exerciseId, oeffnen: false);
      expect(find.byType(Image), findsNothing);
      expect(find.byKey(kGymBild(schlicht.exerciseId)), findsNothing);
    });

    testWidgets('auch im Vollbild (gross) steht es da', (tester) async {
      await pumpe(tester, schlicht.exerciseId, gross: true);
      expect(gezeigt(tester), schlicht.frames);
      expect(
        find.byKey(kGymBildAttribution(schlicht.exerciseId)),
        findsOneWidget,
      );
    });
  });

  group('Bild fehlt: gibt es nicht', () {
    testWidgets('kein Kasten, keine Attribution, Anleitung vollständig', (
      tester,
    ) async {
      final id = schlicht.exerciseId;
      await pumpe(tester, id, mit: Uebungsbilder.leer);
      expect(find.byType(Image), findsNothing);
      expect(find.byKey(kGymBild(id)), findsNothing);
      expect(find.byKey(kGymBildFrame(id, 1)), findsNothing);
      // Die Attribution gehört zum Bild: Wo keins steht, steht auch sie
      // nicht — sie hängt nicht „leer" an der Anleitung.
      expect(find.byKey(kGymBildAttribution(id)), findsNothing);

      final uebung = katalog(id);
      for (final schritt in uebung.howTo) {
        expect(find.text(schritt), findsOneWidget);
      }
      // `!`: `commonMistake` wird mit #551 `String?`. `schlicht` ist eine der
      // 33 Katalogübungen, und die haben ihren häufigen Fehler weiter.
      expect(
        find.text(gymHaeufigerFehler(uebung.commonMistake!)),
        findsOneWidget,
      );
    });

    testWidgets('die Anleitung rückt auf: kein Leerraum an der Stelle', (
      tester,
    ) async {
      final id = schlicht.exerciseId;
      await pumpe(tester, id, mit: Uebungsbilder.leer);
      final ohne = tester.getTopLeft(find.text(katalog(id).howTo.first)).dy;
      final kopf = tester.getBottomLeft(find.byKey(kGymSoGehts(id))).dy;
      // Nur der Abstand unter der Überschrift, keine Bildhöhe.
      expect(ohne - kopf, lessThan(30));
    });
  });

  group('Ungefähres Bild', () {
    testWidgets('sagt, dass es nicht genau diese Übung zeigt', (tester) async {
      expect(ungefaehr.approximate, isTrue);
      await pumpe(tester, ungefaehr.exerciseId);
      final hinweis = find.byKey(kGymBildHinweis(ungefaehr.exerciseId));
      expect(hinweis, findsOneWidget);
      final text = tester.widget<Text>(hinweis).data!;
      expect(text, startsWith(gymBildUngefaehr));
      expect(text, contains(ungefaehr.note!));
    });

    testWidgets('der Hinweis steht unter der Attribution, nicht davor', (
      tester,
    ) async {
      final id = ungefaehr.exerciseId;
      await pumpe(tester, id);
      expect(
        tester.getTopLeft(find.byKey(kGymBildHinweis(id))).dy,
        greaterThan(tester.getTopLeft(find.byKey(kGymBildAttribution(id))).dy),
      );
    });

    testWidgets('eine Notiz ohne „ungefähr" trägt den Vorspann nicht', (
      tester,
    ) async {
      expect(mitNotiz.approximate, isFalse);
      await pumpe(tester, mitNotiz.exerciseId);
      final text = tester
          .widget<Text>(find.byKey(kGymBildHinweis(mitNotiz.exerciseId)))
          .data!;
      expect(text, mitNotiz.note);
      expect(text, isNot(contains(gymBildUngefaehr)));
    });

    testWidgets('ungefähr ohne Satz: der Vorspann allein', (tester) async {
      const bild = Uebungsbild(
        exerciseId: 'benchPress',
        repdbId: 'x',
        repdbName: 'X',
        start: 'assets/exercises/images/x.webp',
        approximate: true,
      );
      await pumpe(tester, 'benchPress', mit: _mit(bild));
      expect(
        tester.widget<Text>(find.byKey(kGymBildHinweis('benchPress'))).data,
        gymBildUngefaehr,
      );
    });
  });

  group('Dieselbe Geometrie in allen Lagen', () {
    testWidgets('der Platz steht ab dem ersten Bild da, quadratisch', (
      tester,
    ) async {
      final id = schlicht.exerciseId;
      await pumpe(tester, id, settle: false);
      final davor = tester.getRect(find.byKey(kGymBildFrame(id, 1)));
      final textDavor = tester.getTopLeft(find.text(katalog(id).howTo.first));
      expect(davor.width, greaterThan(0));
      expect(davor.width, closeTo(davor.height, 0.01));

      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(tester.getRect(find.byKey(kGymBildFrame(id, 1))), davor);
      expect(
        tester.getTopLeft(find.text(katalog(id).howTo.first)),
        textDavor,
        reason: 'Das Bild blendet in seinen Platz ein und schiebt nichts.',
      );
    });

    testWidgets('ein Bild ist nie größer als 280', (tester) async {
      await pumpe(tester, einzel.exerciseId);
      final groesse = tester.getSize(
        find.byKey(kGymBildFrame(einzel.exerciseId, 1)),
      );
      expect(groesse.width, lessThanOrEqualTo(280));
      expect(groesse.width, closeTo(groesse.height, 0.01));
    });
  });

  group('Bilddatei lässt sich nicht lesen', () {
    testWidgets('der Platz bleibt, es steht da, was los ist', (tester) async {
      final id = schlicht.exerciseId;
      tester.view.physicalSize = const Size(800, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [uebungsbilderProvider.overrideWithValue(bilder)],
          child: DefaultAssetBundle(
            bundle: _BuendelOhneRepdb(kaputt: true),
            child: CupertinoApp(
              home: CupertinoPageScaffold(
                child: SingleChildScrollView(
                  child: GymSoGehts(uebung: katalog(id)),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(kGymSoGehts(id)));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(kGymBildFrame(id, 1)), findsOneWidget);
      // Einer statt zwei seit dem 11.11.2026: Die Bilder liegen
      // uebereinander, und zwei Platzhaltertexte deckungsgleich
      // uebereinander waeren sinnlos. Der Text steht auf dem Startbild.
      // (TEST_AENDERN=1)
      expect(find.text(gymBildNichtLesbar), findsOneWidget);
      // Die Anleitung bleibt vollständig.
      expect(find.text(katalog(id).howTo.first), findsOneWidget);
    });
  });

  group('Provider', () {
    test('wirft ohne Override, statt still keine Bilder zu liefern', () {
      final behaelter = ProviderContainer(retry: (_, _) => null);
      addTearDown(behaelter.dispose);
      expect(() => behaelter.read(uebungsbilderProvider), throwsA(anything));
    });

    test('ladeUebungsbilder liest das echte Asset', () async {
      final geladen = await ladeUebungsbilder(rootBundle);
      expect(geladen.exerciseIds.toSet(), bilder.exerciseIds.toSet());
    });

    test(
      'ein unlesbares Asset ergibt „keine Bilder" und wird gemeldet',
      () async {
        final gemeldet = <FlutterErrorDetails>[];
        final alt = FlutterError.onError;
        FlutterError.onError = gemeldet.add;
        addTearDown(() => FlutterError.onError = alt);

        final geladen = await ladeUebungsbilder(
          _BuendelOhneRepdb(kaputt: true),
        );
        expect(geladen, same(Uebungsbilder.leer));
        expect(geladen.fuer('benchPress'), isNull);
        expect(gemeldet, hasLength(1));
      },
    );
  });
}

/// Ein [Uebungsbilder] mit genau diesem Bild, über den echten Text-Weg.
Uebungsbilder _mit(Uebungsbild bild) {
  final spalten = Uebungsbilder.erwarteteSpalten;
  final zeile = List<Object?>.filled(spalten.length, null);
  zeile[spalten.indexOf('id')] = bild.repdbId;
  zeile[spalten.indexOf('en')] = bild.repdbName;
  zeile[spalten.indexOf('images')] = {'main': 'x.webp'};
  return Uebungsbilder.parse(
    jsonEncode({
      'fields': spalten,
      'exercises': [zeile],
      'media': {
        bild.exerciseId: {
          'repdb': bild.repdbId,
          'approximate': bild.approximate,
          'note': bild.note,
        },
      },
    }),
  );
}

/// Liefert für jede Datei unter `assets/exercises/images/` ein 1×1-PNG —
/// die RepDB-Bilder selbst werden nie gelesen. Alles andere (Manifest,
/// Schriften) kommt aus dem echten Bündel. Mit [kaputt]: eine Fehlermeldung
/// statt Daten, für jede Anfrage unter `assets/exercises/`.
class _BuendelOhneRepdb extends CachingAssetBundle {
  _BuendelOhneRepdb({this.kaputt = false});

  final bool kaputt;

  static final _png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA'
    '60e6kgAAAABJRU5ErkJggg==',
  );

  @override
  Future<ByteData> load(String key) async {
    if (key.startsWith('assets/exercises/')) {
      if (kaputt) throw FlutterError('absichtlich kaputt: $key');
      if (key.startsWith('assets/exercises/images/')) {
        return ByteData.sublistView(Uint8List.fromList(_png));
      }
    }
    return rootBundle.load(key);
  }
}
