import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/ernaehrung/ki_sucher.dart';
import 'package:repit/ernaehrung/off_client.dart';
import 'package:repit/ernaehrung/strichcode_leser.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/ki/gemini_client.dart';
import 'package:repit/ki/ki_schluessel.dart';
import 'package:repit/shell/root_view.dart';
import 'package:repit/shell/router.dart';

import '../health/health_reading_attrappe.dart';
import 'foto_attrappe.dart';
import 'kamera_attrappe.dart';
import '../tag/behaelter_im_baum.dart';

/// **Nährwerte je Posten und die Summe des Vorschlags** im Prüfblatt der
/// Foto-Schätzung (#392, Tim, 05.11.2026: „Im Prüfblatt stehen bisher nur
/// kcal"). Geprüft an der ganzen App auf einem Telefon (393 × 852 Punkte)
/// wie `ki_pruefblatt_nachbesserung_test.dart`: (+) → Kamera → „KI" →
/// Auslöser → Prüfblatt. Gemini ist ein `MockClient`; alle Schlüssel,
/// Lebensmittel und Zahlen sind **erfunden**.
///
/// Was Tim verlangt:
///
/// - Je Posten **Eiweiß, Kohlenhydrate, Fett**. Ein fehlender Wert steht als
///   `–`, **nie als 0** (`CLAUDE.md`, „0 ist keine Antwort"). Eine
///   gemessene Null bleibt eine Null.
/// - Dazu die **Summe** des Vorschlags, kcal und Makros, an einer Stelle,
///   die nicht springt.
///
/// ## Festlegungen dieses Agenten, **nicht von Tim**
///
/// - `Key('ki-pruef-summe')` — die Summe. Sie steht **schon, während
///   geschätzt wird**, an derselben Stelle und in derselben Höhe, und trägt
///   dort keine Zahl (`01`: während gelesen wird, ist nichts entschieden).
/// - Summiert wird, **was gebucht würde** — die übernommenen Posten, also
///   dieselben, die „N Einträge buchen" zählt. Ein unsicherer, unberührter
///   Posten **ohne Menge** zählt nicht mit; einer **mit Menge** zählt seit
///   #407 mit und trägt weiter „unsicher" (Tims Meldung vom 07.11.2026:
///   Er musste erst die Menge anfassen, um ihn buchen zu können). Bis
///   dahin hielt diese Datei fest, dass das Brot unten nicht mitzählt.
/// - Gerundet wird auf ganze Gramm und kcal. Welche Kürzel und Trenner
///   davor stehen, schreibt der Test nicht vor; er sucht nach den Zahlen.
void main() {
  setUpAll(() async {
    await initializeDateFormatting('de_DE');
  });

  final jetzt = DateTime.utc(2026, 7, 14, 10);
  const schluessel = 'erfunden-schluessel-naehr';

  /// Vier Posten: zwei vollständig (einer mit einer gemessenen Null bei den
  /// Kohlenhydraten), einer ohne Fett, einer ganz ohne Werte. Die beiden
  /// letzten sind unsicher — ohne alle vier Werte ist kein Posten
  /// plausibel (`plausibel` im Kern). Das Brot hat eine Menge und ist
  /// deshalb seit #407 übernommen; die Soße hat keine und ist es nicht.
  const teller = {
    'isFood': true,
    'title': 'Erfundener Teller',
    'items': [
      {
        'name': 'Erfundenes Huhn',
        'grams': 140,
        'kcal': 231,
        'proteinG': 43.4,
        'carbsG': 0,
        'fatG': 5.0,
        'confident': true,
      },
      {
        'name': 'Erfundener Reis',
        'grams': 180,
        'kcal': 234,
        'proteinG': 4.9,
        'carbsG': 51.2,
        'fatG': 0.4,
        'confident': true,
      },
      {
        'name': 'Erfundenes Brot',
        'grams': 50,
        'kcal': 120,
        'proteinG': 4.0,
        'carbsG': 23.0,
        'fatG': null,
        'confident': true,
      },
      {
        'name': 'Erfundene Soße',
        'grams': null,
        'kcal': null,
        'proteinG': null,
        'carbsG': null,
        'fatG': null,
        'confident': false,
      },
    ],
  };

  http.Response antwort(Object inhalt) => http.Response(
    jsonEncode({
      'candidates': [
        {
          'content': {
            'parts': [
              {'text': jsonEncode(inhalt)},
            ],
          },
        },
      ],
      'usageMetadata': {
        'promptTokenCount': 100,
        'candidatesTokenCount': 20,
        'thoughtsTokenCount': 0,
      },
    }),
    200,
    headers: const {'content-type': 'application/json'},
  );

  /// Lässt Zeit vergehen, ohne auf Ruhe zu warten.
  Future<void> ruhe(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> tippe(WidgetTester tester, Finder ziel) async {
    await tester.tap(ziel);
    await ruhe(tester);
  }

  /// Öffnet das Prüfblatt; die Antworten auf `generateContent` kommen der
  /// Reihe nach aus [antworten].
  Future<void> oeffnePruefblatt(
    WidgetTester tester, {
    required List<Future<http.Response> Function()> antworten,
  }) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);
    final speicher = AttrappenSchluesselSpeicher();
    await speicher.schreibe(schluessel);
    final gemini = MockClient((anfrage) async {
      if (anfrage.method == 'GET') {
        return http.Response(
          jsonEncode({
            'models': [
              {
                'name': 'models/gemini-3.6-flash',
                'displayName': 'gemini-3.6-flash',
                'supportedGenerationMethods': ['generateContent'],
              },
            ],
          }),
          200,
          headers: const {'content-type': 'application/json'},
        );
      }
      if (antworten.isEmpty) {
        fail('unerwartete Anfrage an Gemini: ${anfrage.url.path}');
      }
      return antworten.removeAt(0)();
    });
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        appCacheProvider.overrideWithValue(db),
        healthProvider.overrideWithValue(_StilleQuelle()),
        clockProvider.overrideWithValue(() => jetzt),
        offClientProvider.overrideWithValue(
          OffClient(
            client: MockClient((a) async => fail('kein OFF erwartet: $a')),
          ),
        ),
        strichcodeLeserProvider.overrideWithValue(TestLeser()),
        fotoKameraProvider.overrideWithValue(TestFotoKamera()),
        kiSchluesselProvider.overrideWithValue(speicher),
        kiAnbieterProvider.overrideWithValue(GeminiAnbieter(gemini)),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      BehaelterImBaum(
        container: container,
        child: CupertinoApp(home: RootView(router: AppRouter())),
      ),
    );
    await tester.pumpAndSettle();

    for (final key in ['erfassen-knopf', 'kamera-modus-ki', 'ki-ausloeser']) {
      await tester.tap(find.byKey(Key(key)));
      await ruhe(tester);
    }
    expect(find.byKey(const Key('ki-pruefblatt')), findsOneWidget);
  }

  String textVon(WidgetTester tester, Finder wo) => tester
      .widgetList<Text>(find.descendant(of: wo, matching: find.byType(Text)))
      .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
      .join(' ');

  final zeile0 = find.byKey(const Key('ki-pruef-zeile-0'));
  final zeile1 = find.byKey(const Key('ki-pruef-zeile-1'));
  final zeile2 = find.byKey(const Key('ki-pruef-zeile-2'));
  final zeile3 = find.byKey(const Key('ki-pruef-zeile-3'));
  final summe = find.byKey(const Key('ki-pruef-summe'));

  /// Eine Zahl, die für sich steht — „5" in „5 g", nicht in „51" oder „150".
  Matcher zahl(String z) =>
      contains(RegExp('(?<![\\d,.])${RegExp.escape(z)}(?![\\d,])'));

  /// Eine alleinstehende Null — der Fehler, den „–" verhindern soll.
  final eineNull = zahl('0');

  // ═════════════════════════════════════════════════════════════════════
  group('Je Posten Eiweiß, Kohlenhydrate, Fett', () {
    testWidgets('ein vollständiger Posten zeigt alle drei — eine gemessene '
        'Null bleibt eine Null', (tester) async {
      await oeffnePruefblatt(tester, antworten: [() async => antwort(teller)]);

      final text = textVon(tester, zeile0);
      expect(text, zahl('231'), reason: 'kcal wie bisher');
      expect(text, zahl('43'), reason: 'Eiweiß 43,4 g, gerundet');
      expect(text, zahl('5'), reason: 'Fett 5,0 g');
      expect(
        text,
        eineNull,
        reason: 'Kohlenhydrate 0 g sind eine Angabe, kein fehlender Wert',
      );
    });

    testWidgets('fehlt ein Wert, steht „–" — nie 0', (tester) async {
      await oeffnePruefblatt(tester, antworten: [() async => antwort(teller)]);

      final text = textVon(tester, zeile2);
      expect(text, zahl('4'), reason: 'Eiweiß 4,0 g');
      expect(text, zahl('23'), reason: 'Kohlenhydrate 23,0 g');
      expect(text, contains('–'), reason: 'Fett fehlt — „–" steht dafür');
      expect(text, isNot(eineNull), reason: 'ein fehlendes Fett ist keine 0');
    });

    testWidgets('ein Posten ganz ohne Werte zeigt keine einzige Zahl', (
      tester,
    ) async {
      await oeffnePruefblatt(tester, antworten: [() async => antwort(teller)]);

      final text = textVon(tester, zeile3);
      expect(
        text,
        isNot(contains(RegExp(r'\d'))),
        reason: 'weder kcal noch Makros — `null` bleibt `null`: „$text"',
      );
      expect(
        '–'.allMatches(text).length,
        greaterThanOrEqualTo(4),
        reason: 'kcal und drei Makros stehen je als „–": „$text"',
      );
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Die Summe des Vorschlags', () {
    testWidgets('summiert kcal und Makros der übernommenen Posten', (
      tester,
    ) async {
      await oeffnePruefblatt(tester, antworten: [() async => antwort(teller)]);

      expect(summe, findsOneWidget);
      final text = textVon(tester, summe);
      expect(
        text,
        zahl('585'),
        reason:
            'kcal: 231 + 234 + 120 — mit dem unsicheren Brot, das eine Menge '
            'hat (#407), ohne die Soße ohne Menge — „$text"',
      );
      expect(
        text,
        zahl('52'),
        reason: 'Eiweiß: 43,4 + 4,9 + 4,0 = 52,3 — „$text"',
      );
      expect(
        text,
        zahl('74'),
        reason: 'Kohlenhydrate: 0 + 51,2 + 23,0 = 74,2 — „$text"',
      );
      expect(text, zahl('5'), reason: 'Fett: 5,0 + 0,4 = 5,4 — „$text"');
    });

    testWidgets('fehlt einem übernommenen Posten ein Wert, wird die Summe '
        'weder 0 noch leer', (tester) async {
      await oeffnePruefblatt(tester, antworten: [() async => antwort(teller)]);

      // Das Brot (ohne Fett) ist unsicher, hat aber eine Menge und ist
      // damit übernommen (#407) — ohne dass Tim es anfasst.
      final text = textVon(tester, summe);
      expect(text, zahl('585'), reason: 'kcal: 231 + 234 + 120 — „$text"');
      expect(
        text,
        zahl('5'),
        reason:
            'Fett: 5,4 aus den beiden, die es kennen — nicht 0 und nicht '
            'verschwunden, weil das Brot keins kennt — „$text"',
      );
      expect(text, isNot(eineNull), reason: 'keine Null in der Summe: „$text"');
    });

    testWidgets('steht schon, während geschätzt wird — an derselben Stelle, '
        'in derselben Höhe, ohne Zahl', (tester) async {
      final halt = Completer<http.Response>();
      await oeffnePruefblatt(tester, antworten: [() => halt.future]);

      expect(summe, findsOneWidget, reason: 'die Form steht schon');
      expect(
        textVon(tester, summe),
        isNot(contains(RegExp(r'\d'))),
        reason: 'während geschätzt wird, ist nichts entschieden (`01`)',
      );
      final waehrend = tester.getRect(summe);

      halt.complete(antwort(teller));
      await ruhe(tester);
      expect(zeile0, findsOneWidget);
      expect(
        tester.getRect(summe),
        waehrend,
        reason: 'kommt der Vorschlag, springt die Summe nicht',
      );
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Übergang: Menge ändern', () {
    testWidgets('Zeile und Summe folgen der neuen Menge — und die Summe '
        'bleibt, wo sie war', (tester) async {
      await oeffnePruefblatt(tester, antworten: [() async => antwort(teller)]);
      final vorher = tester.getRect(summe);

      await tippe(tester, zeile0);
      await tippe(tester, find.text('Menge ändern'));
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('ki-pruef-menge-feld')),
          matching: find.byType(EditableText),
        ),
        '280',
      );
      await tester.pump();
      await tippe(tester, find.byKey(const Key('ki-pruef-menge-ok')));

      // 140 g → 280 g: alles mal zwei.
      final zeile = textVon(tester, zeile0);
      expect(zeile, zahl('462'), reason: 'kcal 231 → 462 — „$zeile"');
      expect(zeile, zahl('87'), reason: 'Eiweiß 43,4 → 86,8 — „$zeile"');
      expect(zeile, zahl('10'), reason: 'Fett 5,0 → 10,0 — „$zeile"');

      // Das Brot zählt mit: unsicher, aber mit Menge (#407).
      final s = textVon(tester, summe);
      expect(s, zahl('816'), reason: 'kcal 462 + 234 + 120 — „$s"');
      expect(s, zahl('96'), reason: 'Eiweiß 86,8 + 4,9 + 4,0 = 95,7 — „$s"');
      expect(s, zahl('10'), reason: 'Fett 10,0 + 0,4 = 10,4 — „$s"');

      expect(
        tester.getRect(summe),
        vorher,
        reason: 'die Summe springt nicht, wenn sich eine Menge ändert',
      );
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  // #407, Tims Meldung vom 07.11.2026: Ist die KI bei einem Posten
  // unsicher, soll er direkt buchen können, ohne erst die Menge
  // anzufassen. Unsicher mit Menge ist übernommen, bleibt aber als
  // „unsicher" markiert; ohne Menge bleibt er draußen.
  group('Unsicher mit Menge ist übernommen (#407)', () {
    testWidgets('der Knopf zählt das unsichere Brot mit, die Soße ohne Menge '
        'nicht', (tester) async {
      await oeffnePruefblatt(tester, antworten: [() async => antwort(teller)]);

      final knopf = find.byKey(const Key('ki-pruef-buchen'));
      expect(
        textVon(tester, knopf),
        contains('3 Einträge buchen'),
        reason: 'Huhn, Reis und das Brot — die Soße hat keine Menge',
      );
      expect(
        tester.widget<CupertinoButton>(knopf).onPressed,
        isNotNull,
        reason: 'gebucht werden kann ohne einen Tipp auf eine Zeile',
      );
    });

    testWidgets('das übernommene Brot bleibt als „unsicher" markiert', (
      tester,
    ) async {
      await oeffnePruefblatt(tester, antworten: [() async => antwort(teller)]);

      expect(
        textVon(tester, zeile2),
        contains('unsicher'),
        reason: 'übernommen heißt nicht sicher',
      );
      expect(textVon(tester, zeile3), contains('unsicher'));
      expect(textVon(tester, zeile0), isNot(contains('unsicher')));
    });
  });
}

class _StilleQuelle extends HealthReadingAttrappe {}
