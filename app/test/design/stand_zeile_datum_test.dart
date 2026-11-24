import 'package:flutter_test/flutter_test.dart';

import 'package:repit/core/messwert.dart';
import 'package:repit/design/stand_zeile.dart';

import 'support.dart';

/// Tests für die Erweiterung von `StandZeile` um das Datum (#200),
/// gegen `docs/superpowers/specs/2026-11-03-healthkit-test-
/// aufteilung.md`, Abschnitt 5.
///
/// Die Fälle ohne Datum deckt `stand_zeile_test.dart` ab; hier steht
/// nur, was neu ist.
///
/// **`jetzt` ist verpflichtend, nicht optional.** Ein Vorgabewert
/// `DateTime.now()` sähe bequemer aus und wäre die Rückkehr des Fehlers:
/// Wer ihn vergisst, bekommt eine Zeile, die sich richtig verhält,
/// solange man sie am selben Tag ansieht — und falsch, sobald es darauf
/// ankommt. Ein Pflichtparameter lässt sich nicht vergessen.
void main() {
  // Dieselbe Lesart wie in `formatierung_stand_test.dart`: Felder, nicht
  // Instant. Siehe dort für die Begründung.
  final jetzt = DateTime.utc(2026, 11, 3, 15, 31);

  testWidgets('ein Stand vom selben Tag bleibt bei der blossen Uhrzeit', (
    tester,
  ) async {
    await tester.pumpWidget(
      huelle(
        StandZeile(
          Bekannt<int>(1, stand: DateTime.utc(2026, 11, 3, 7, 12), laeuft: false),
          jetzt: jetzt,
        ),
      ),
    );

    expect(find.text('Stand 07:12'), findsOneWidget);
  });

  testWidgets('ein Stand von gestern ist als solcher erkennbar', (
    tester,
  ) async {
    await tester.pumpWidget(
      huelle(
        StandZeile(
          Bekannt<int>(
            1,
            stand: DateTime.utc(2026, 11, 2, 21, 58),
            laeuft: false,
          ),
          jetzt: jetzt,
        ),
      ),
    );

    expect(find.text('Stand gestern 21:58'), findsOneWidget);
  });

  testWidgets('der Lauf-Hinweis haengt auch hinter dem Datum', (tester) async {
    await tester.pumpWidget(
      huelle(
        StandZeile(
          Bekannt<int>(
            1,
            stand: DateTime.utc(2026, 11, 2, 21, 58),
            laeuft: true,
          ),
          jetzt: jetzt,
        ),
      ),
    );

    expect(find.text('Stand gestern 21:58 · wird aktualisiert'), findsOneWidget);
  });

  /// Die Zeile darf ihre Höhe nicht ändern, sonst rutscht beim
  /// Eintreffen der Werte alles darunter (`CLAUDE.md`, „Eine Anzeige,
  /// die es gibt, hat genau eine Form"). Gemessen wird die gerenderte
  /// Höhe, nicht die Zeichenzahl — nur sie entscheidet über den Sprung.
  testWidgets('bleibt in allen drei Faellen gleich hoch', (tester) async {
    final hoehen = <double>[];

    for (final stand in [
      DateTime.utc(2026, 11, 3, 7, 12),
      DateTime.utc(2026, 11, 2, 21, 58),
      DateTime.utc(2026, 10, 27, 21, 58),
    ]) {
      await tester.pumpWidget(
        huelle(
          StandZeile(
            Bekannt<int>(1, stand: stand, laeuft: false),
            jetzt: jetzt,
          ),
        ),
      );
      hoehen.add(tester.getSize(find.byType(StandZeile)).height);
    }

    expect(
      hoehen.toSet(),
      hasLength(1),
      reason: 'drei verschiedene Staende, eine Hoehe — sonst springt der '
          'Schirm, sobald der Stand aelter wird: $hoehen',
    );
  });
}
