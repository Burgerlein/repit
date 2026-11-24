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
import 'package:repit/ernaehrung/ki_pruefblatt_zeilen.dart';
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

/// Der **Aufbau** des Prüfblatts auf einem Telefon — zwei Befunde von Tim
/// auf dem iPhone (04.11.2026):
///
/// - **#348** „Das Scrollverhalten ist falsch, das Bild geht aus dem
///   Viewport raus." Ungescrollt beginnt das Foto **unter** der
///   Navigationsleiste, nicht dahinter — der Rand aus `GlasAbstand` muss
///   die Leiste mitzählen. Danach scrollt es mit dem Inhalt, wie im
///   Entwurf (`TELLER` steht im Fluss des Blatts); Festlegung dieses
///   Agenten, **nicht von Tim**.
/// - **#349** „Viel Leerraum unter ‚Zeile hinzufügen'": Ein Vorschlag mit
///   wenigen Posten trägt unter seiner Karte keinen Leerraum bis zum
///   Hinweisfeld — die Karte endet, und nach dem üblichen Abstand folgt das
///   Feld.
///
/// Geprüft an der ganzen App wie `ki_pruefblatt_test.dart`: (+) → Kamera →
/// „KI" → Auslöser (seit #355 ohne Hinweisblatt dazwischen). Alle
/// Schlüssel, Lebensmittel und Zahlen sind **erfunden**.
///
/// **Umgestellt mit #353:** Das Foto hat keine feste Höhe mehr, sondern das
/// Seitenverhältnis der Aufnahme (`ki_pruefblatt_nachbesserung_test.dart`).
/// Die frühere Erwartung `PruefBild.hoehe` ist deshalb aus dem Fall zu #348
/// entfernt; was #348 verlangt — unter der Leiste, scrollt mit —, bleibt.
void main() {
  setUpAll(() async {
    await initializeDateFormatting('de_DE');
  });

  final jetzt = DateTime.utc(2026, 7, 14, 10);
  const schluessel = 'erfunden-schluessel-abcd';

  Map<String, Object?> posten(String name, int gramm, int kcal) => {
    'name': name,
    'grams': gramm,
    'kcal': kcal,
    'proteinG': kcal / 16,
    'carbsG': kcal / 16,
    'fatG': kcal / 36,
    'confident': true,
  };

  http.Response antwort(List<Map<String, Object?>> liste) => http.Response(
    jsonEncode({
      'candidates': [
        {
          'content': {
            'parts': [
              {
                'text': jsonEncode({
                  'isFood': true,
                  'title': 'Erfundener Teller',
                  'items': liste,
                  'note': null,
                }),
              },
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

  Future<void> oeffnePruefblatt(
    WidgetTester tester,
    List<Map<String, Object?>> liste,
  ) async {
    // Ein Telefon: 393 × 852 Punkte.
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
      return antwort(liste);
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

    Future<void> tippe(String key) async {
      await tester.tap(find.byKey(Key(key)));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    await tippe('erfassen-knopf');
    await tippe('kamera-modus-ki');
    await tippe('ki-ausloeser');
    expect(find.byKey(const Key('ki-pruefblatt')), findsOneWidget);
    expect(find.byKey(const Key('ki-pruef-zeile-0')), findsOneWidget);
  }

  testWidgets('#349: Zwei Posten — unter „Zeile hinzufügen" folgt nach dem '
      'üblichen Abstand das Hinweisfeld, kein Leerraum', (tester) async {
    await oeffnePruefblatt(tester, [
      posten('Erfundenes A', 140, 231),
      posten('Erfundenes B', 180, 234),
    ]);

    final dazu = tester.getRect(find.byKey(const Key('ki-pruef-zeile-dazu')));
    final hinweis = tester.getRect(find.byKey(const Key('ki-pruef-hinweis')));
    final luecke = hinweis.top - dazu.bottom;
    expect(
      luecke,
      lessThanOrEqualTo(24),
      reason:
          'zwischen „Zeile hinzufügen" und dem Hinweisfeld stehen '
          '${luecke.toStringAsFixed(0)} Punkte — Kartenrand und 10 Punkte '
          'Abstand, mehr nicht',
    );
  });

  testWidgets('#348: Das Foto steht vollständig unter der Leiste und '
      'scrollt mit dem Inhalt', (tester) async {
    await oeffnePruefblatt(tester, [
      posten('Erfundenes A', 140, 231),
      posten('Erfundenes B', 180, 234),
      posten('Erfundenes C', 120, 41),
      posten('Erfundenes D', 30, 90),
      posten('Erfundenes E', 15, 133),
    ]);

    final bild = find.byType(PruefBild);
    expect(bild, findsOneWidget);
    final leiste = tester.getRect(find.byType(CupertinoNavigationBar).last);
    final vorher = tester.getRect(bild);
    expect(
      vorher.top,
      greaterThanOrEqualTo(leiste.bottom),
      reason:
          'ungescrollt beginnt das Foto unter der Navigationsleiste, nicht '
          'dahinter (oben ${vorher.top}, Leiste endet bei ${leiste.bottom})',
    );

    await tester.drag(
      find.byKey(const Key('ki-pruefblatt')),
      const Offset(0, -80),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getRect(bild).top,
      lessThan(vorher.top),
      reason: 'das Foto gehört zum Inhalt und scrollt mit',
    );
  });
}

class _StilleQuelle extends HealthReadingAttrappe {}
