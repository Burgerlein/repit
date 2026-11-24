import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/gym/gym_log_bausteine.dart';
import 'package:repit/gym/gym_log_schluessel.dart';
import 'package:repit/gym/gym_log_texte.dart';
import 'package:repit/gym/uebungsbilder.dart';
import 'package:repit/gym/uebungsbilder_provider.dart';

import 'gym_editor_support.dart' show EditorBuendel, editorBilder;

/// Das Technik-Blatt („So geht's", `GymSoGehts`) über der **Bibliothek**
/// (#551, Spec 9.7, Entscheidung 7; Plan Task 3.6): Die erzeugten Übungen
/// haben keinen „häufigsten Fehler" (`commonMistake == null`, es wird keiner
/// erfunden), dafür `tips` — die stehen unter den Schritten, je Zeile mit
/// „Tipp: ". **Der Wortlaut „Tipp: " ist Vorschlag der Spec (9.7).**
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden. Hält der
/// Implementierende eine Erwartung für falsch, wird das gemeldet, nicht
/// korrigiert.
///
/// Kein Test für Schriftgrößen (Memory „keine Schriftgrößen-Tests"), keiner
/// für die geschlossene Anzeige — die bleibt gleich (Hausregel „eine Form")
/// und ist durch die bestehenden Tests gedeckt. Die RepDB-Bilddateien werden
/// nie gelesen ([EditorBuendel] liefert 1×1-PNGs); die Zuordnung baut
/// [editorBilder] über den echten Text-Weg.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Eine erzeugte Übung mit Tipps und ohne „häufigsten Fehler".
  final erzeugte = ExerciseLibrary.all.values.firstWhere(
    (u) =>
        !ExerciseLibrary.isCatalog(u.id) &&
        u.tips.isNotEmpty &&
        u.commonMistake == null,
  );

  /// Ein Anker mit „häufigstem Fehler" und ohne Tipps.
  final anker = ExerciseCatalog.all.values.firstWhere(
    (u) => u.commonMistake != null && u.tips.isEmpty,
  );

  Future<void> pumpe(
    WidgetTester tester,
    Exercise uebung, {
    Uebungsbilder? bilder,
  }) async {
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          uebungsbilderProvider.overrideWithValue(bilder ?? Uebungsbilder.leer),
        ],
        child: DefaultAssetBundle(
          bundle: EditorBuendel(),
          child: CupertinoApp(
            home: CupertinoPageScaffold(
              child: SingleChildScrollView(child: GymSoGehts(uebung: uebung)),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(kGymSoGehts(uebung.id)));
    await tester.pumpAndSettle();
  }

  group('Erzeugte Übung (Spec 9.7)', () {
    testWidgets('ohne `commonMistake` steht kein „Häufiger Fehler" da — '
        'es wird keiner erfunden', (tester) async {
      await pumpe(tester, erzeugte);

      expect(erzeugte.commonMistake, isNull, reason: 'Voraussetzung');
      expect(find.textContaining('Häufiger Fehler'), findsNothing);
      for (final schritt in erzeugte.howTo) {
        expect(
          find.text(schritt),
          findsOneWidget,
          reason: 'die Schritte stehen vollständig da',
        );
      }
    });

    testWidgets('die Tipps stehen unter den Schritten, je Zeile mit '
        '„Tipp: " (Wortlaut ist Vorschlag, Spec 9.7)', (tester) async {
      await pumpe(tester, erzeugte);

      expect(erzeugte.tips, isNotEmpty, reason: 'Voraussetzung');
      for (final tipp in erzeugte.tips) {
        expect(
          find.textContaining('Tipp: $tipp'),
          findsOneWidget,
          reason: 'jeder Tipp steht als eigene Zeile da',
        );
      }
      final letzterSchritt = tester
          .getBottomLeft(find.text(erzeugte.howTo.last))
          .dy;
      final ersterTipp = tester
          .getTopLeft(find.textContaining('Tipp: ${erzeugte.tips.first}'))
          .dy;
      expect(
        ersterTipp,
        greaterThanOrEqualTo(letzterSchritt),
        reason: 'die Tipps stehen darunter, nicht zwischen den Schritten',
      );
    });

    testWidgets('Bewegungsbild und Attribution stehen auch bei einer '
        'erzeugten Übung — unter dem Bild', (tester) async {
      await pumpe(
        tester,
        erzeugte,
        bilder: editorBilder(einzel: [erzeugte.id]),
      );

      expect(find.byKey(kGymBild(erzeugte.id)), findsOneWidget);
      final attribution = find.byKey(kGymBildAttribution(erzeugte.id));
      expect(attribution, findsOneWidget);
      expect(
        tester.widget<Text>(attribution).data,
        repdbAttribution,
        reason:
            'Die Pflichtangabe der RepDB-Lizenz gilt für alle Übungen '
            'gleich (Spec 9.7, 10)',
      );
      expect(
        tester.getTopLeft(attribution).dy,
        greaterThan(
          tester.getBottomLeft(find.byKey(kGymBildFrame(erzeugte.id, 1))).dy,
        ),
      );
    });
  });

  group('Anker bleiben unverändert (Spec 9.7)', () {
    testWidgets('ein Anker zeigt weiter seinen „Häufigen Fehler" — und ohne '
        '`tips` keine Tipp-Zeile', (tester) async {
      await pumpe(tester, anker);

      expect(
        find.text(gymHaeufigerFehler(anker.commonMistake!)),
        findsOneWidget,
        reason: 'die 33 haben ihren häufigen Fehler weiter',
      );
      for (final schritt in anker.howTo) {
        expect(find.text(schritt), findsOneWidget);
      }
      expect(
        find.textContaining('Tipp: '),
        findsNothing,
        reason: 'ohne `tips` keine leere Tipp-Zeile — leer heißt leer',
      );
    });
  });
}
