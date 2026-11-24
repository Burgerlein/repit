import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repit/design/inset_card.dart';
import 'package:repit/design/kachel_karte.dart';
import 'package:repit/design/kacheln.dart';
import 'package:repit/design/karten_flaeche.dart';
import 'package:repit/design/palette.dart';
import 'package:repit/ki/ki_zugang_bausteine.dart';

import 'support.dart';

/// Wächtertest zu #384: Jede Karte der App trägt dieselbe Fläche wie auf
/// Home — `surface`, Radius 17, kein Rand, kein Schatten (Tim, 05.11.2026).
///
/// Geprüft wird nicht das Bild, sondern die Quelle: `InsetCard`,
/// `KachelKarte` und `kachelFlaeche` lesen Radius und Fläche aus
/// `karten_flaeche.dart`. Zwei Bausteine mit je eigener Zahl drifteten
/// auseinander, sobald jemand einen davon anfasst — genau so standen bis
/// #384 Radius 10 mit Rand und Radius 17 ohne nebeneinander.
///
/// Von Anfang an grün: Der Test prüft eine Behauptung über die Bausteine,
/// kein noch zu bauendes Verhalten.
const _anker = Key('anker');

void main() {
  test('die Kartenform ist Radius 17', () {
    expect(kartenRadius, 17);
  });

  testWidgets('kartenFlaeche: surface, Radius 17, kein Rand, kein Schatten', (
    tester,
  ) async {
    await tester.pumpWidget(huelle(const SizedBox(key: _anker)));
    final context = tester.element(find.byKey(_anker));
    final flaeche = kartenFlaeche(context);

    expect(
      flaeche.color,
      CupertinoDynamicColor.resolve(Palette.surface, context),
    );
    expect(flaeche.borderRadius, BorderRadius.circular(kartenRadius));
    expect(flaeche.border, isNull);
    expect(flaeche.boxShadow, isNull);
  });

  testWidgets('kachelFlaeche ist dieselbe Fläche', (tester) async {
    await tester.pumpWidget(huelle(const SizedBox(key: _anker)));
    final context = tester.element(find.byKey(_anker));

    expect(kachelFlaeche(context), kartenFlaeche(context));
  });

  for (final (name, karte, typ) in [
    ('InsetCard', const InsetCard(child: Text('Inhalt')), InsetCard),
    ('KachelKarte', const KachelKarte(child: Text('Inhalt')), KachelKarte),
  ]) {
    testWidgets('$name trägt kartenFlaeche und beschneidet mit kartenRadius', (
      tester,
    ) async {
      await tester.pumpWidget(huelle(karte));
      final context = tester.element(find.byType(typ));

      final flaechen = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(typ),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((d) => d.decoration)
          .whereType<BoxDecoration>()
          .toList();
      expect(flaechen, contains(kartenFlaeche(context)));
      for (final flaeche in flaechen) {
        expect(flaeche.border, isNull, reason: '$name: kein Rand (#384)');
        expect(flaeche.boxShadow, isNull, reason: '$name: kein Schatten');
      }

      final schnitt = tester.widget<ClipRRect>(
        find
            .descendant(of: find.byType(typ), matching: find.byType(ClipRRect))
            .first,
      );
      expect(
        schnitt.borderRadius,
        BorderRadius.circular(kartenRadius),
        reason: '$name: beschnitten wird mit der Karte, auf ihrem Radius',
      );
    });
  }

  testWidgets('die Karte des KI-Zugangs sitzt auf InsetCard', (tester) async {
    await tester.pumpWidget(huelle(const KiKarte(zeilen: [Text('Erfunden')])));

    expect(
      find.descendant(
        of: find.byType(KiKarte),
        matching: find.byType(InsetCard),
      ),
      findsOneWidget,
      reason:
          'eine Karte, die ihre Fläche selbst baut, bleibt beim '
          'nächsten Umbau der Form stehen',
    );
  });

  test('kein zweiter Kartenradius im Quelltext', () {
    final funde = <String>[];
    for (final datei in Directory('lib').listSync(recursive: true)) {
      if (datei is! File || !datei.path.endsWith('.dart')) continue;
      if (datei.path.endsWith('karten_flaeche.dart')) continue;
      final text = datei.readAsStringSync();
      if (RegExp(r'circular\(\s*17(\.0)?\s*\)').hasMatch(text) ||
          RegExp(r'Radius\s*=\s*17(\.0)?\s*;').hasMatch(text)) {
        funde.add(datei.path);
      }
    }
    expect(
      funde,
      isEmpty,
      reason: 'der Kartenradius steht einmal, in karten_flaeche.dart',
    );
  });
}
