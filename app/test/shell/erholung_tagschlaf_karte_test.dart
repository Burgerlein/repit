import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repit/health/health_types.dart';
import 'package:repit/shell/erholung_nacht.dart';

/// Tests für die **Tagschlaf-Kachel des Erholung-Schirms** (#213) —
/// `ErholungTagschlaf` in `lib/shell/erholung_nacht.dart`.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung**
/// (`CLAUDE.md`). Diese Datei darf ausgeführt, nie verändert werden.
///
/// ## Der Befund
///
/// Die Kachel schrieb „ein Nickerchen heute" — das Wort stand fest im
/// Quelltext. Auf dem Schirm, der den heutigen Tag zeigte, stimmte es;
/// sobald derselbe Schirm sich blättern lässt (#261), behauptet die
/// Kachel etwas Falsches.
///
/// ## Die Kachel kennt den Tag nicht, also sagt sie nichts über ihn
///
/// Sie bekommt eine Liste von Sitzungen und einen Rückruf, sonst nichts.
/// Ein Tagesbezug wäre eine Behauptung ohne Grundlage — **und die Lösung
/// ist, ihn wegzulassen, nicht ihn hereinzureichen.** Einen Tag zu
/// zeigen, den die Kachel heute nicht hat, wäre eine Erweiterung; dieser
/// Test fordert sie nicht.
///
/// Was bleibt, ist der Unterschied, den die Kachel **aus ihren Daten**
/// kennt: eines oder mehrere, und wie lange zusammen.
void main() {
  /// Ein Nickerchen von [minuten] Minuten, ab [stunde] Uhr.
  ///
  /// Der Kalendertag ist beliebig — die Kachel liest ihn nicht, und
  /// genau das ist der Punkt dieser Datei.
  SleepSession nickerchen({required int stunde, int minuten = 30}) {
    final beginn = DateTime.utc(2026, 10, 29, stunde);
    return SleepSession(
      segments: [
        SleepSegment(
          stage: SleepStage.core,
          start: beginn,
          end: beginn.add(Duration(minutes: minuten)),
        ),
      ],
    );
  }

  Future<List<String>> texte(
    WidgetTester tester,
    List<SleepSession> naps,
  ) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: ErholungTagschlaf(naps: naps, onTagschlaf: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('erholung-tagschlaf')), findsOneWidget);
    return tester
        .widgetList<Text>(
          find.descendant(
            of: find.byKey(const Key('erholung-tagschlaf')),
            matching: find.byType(Text),
          ),
        )
        .map((t) => t.data)
        .whereType<String>()
        .toList();
  }

  /// Wörter und Formen, die einen Tag benennen. Ein Datum fiele über die
  /// Ziffernform auf, ein „heute" über das Wort.
  final tagesbezug = RegExp(
    r'heute|gestern|vorgestern|morgen|\bam\b|'
    r'\d{1,2}\.\s*\d{1,2}\.|'
    r'Montag|Dienstag|Mittwoch|Donnerstag|Freitag|Samstag|Sonntag|'
    r'\b(Mo|Di|Mi|Do|Fr|Sa|So)\b',
    caseSensitive: false,
  );

  group('Die Kachel behauptet keinen Tag', () {
    testWidgets('bei einem Nickerchen nicht', (tester) async {
      final gefunden = await texte(tester, [nickerchen(stunde: 13)]);

      for (final text in gefunden) {
        expect(
          tagesbezug.hasMatch(text),
          isFalse,
          reason:
              '„$text" nennt einen Tag, den die Kachel aus ihren Daten '
              'nicht kennt (#213)',
        );
      }
    });

    testWidgets('und bei mehreren auch nicht', (tester) async {
      final gefunden = await texte(tester, [
        nickerchen(stunde: 11),
        nickerchen(stunde: 13),
        nickerchen(stunde: 16),
      ]);

      for (final text in gefunden) {
        expect(
          tagesbezug.hasMatch(text),
          isFalse,
          reason: '„$text" nennt einen Tag (#213)',
        );
      }
    });
  });

  group('Was sie aus ihren Daten kennt, sagt sie weiter', () {
    testWidgets('eines ist eines — in Worten, nicht als Ziffer', (
      tester,
    ) async {
      final gefunden = await texte(tester, [nickerchen(stunde: 13)]);

      expect(
        gefunden.any((t) => t.contains('ein Nickerchen')),
        isTrue,
        reason: 'der Einzelfall bleibt vom Mehrfachfall unterscheidbar',
      );
    });

    testWidgets('drei sind drei', (tester) async {
      final gefunden = await texte(tester, [
        nickerchen(stunde: 11),
        nickerchen(stunde: 13),
        nickerchen(stunde: 16),
      ]);

      expect(gefunden.any((t) => t.contains('3 Nickerchen')), isTrue);
    });

    testWidgets('und die Summe steht als Dauer da', (tester) async {
      final gefunden = await texte(tester, [
        nickerchen(stunde: 11, minuten: 20),
        nickerchen(stunde: 13, minuten: 40),
      ]);

      expect(
        gefunden.any((t) => t.contains('1 Std.')),
        isTrue,
        reason: '20 + 40 Minuten sind eine Stunde',
      );
    });
  });
}
