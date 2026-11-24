// „Modell für Fotos" auf einem **Telefon** mit einer **langen** Liste
// (#346, Tims Befund vom 04.11.2026: „Modell lässt sich nicht wechseln").
//
// Der Befund an der echten Modellliste (60 Einträge, vom Koordinator mit
// Tims Schlüssel abgerufen, **nicht** im Repository): Nach dem Filter
// bleiben 22 Modelle. `ki_zugang_view_test.dart` prüft das Blatt mit zwei
// Modellen auf einer 2.400 Punkte hohen Fläche — dort steht alles im
// Bild. Auf dem Telefon ist das Blatt 64 % von 852 Punkten hoch; der Grund,
// warum ein Modell das Testbild nicht angenommen hat, stand **unter** der
// Liste und damit außerhalb des Blatts. Tim tippt, der Kringel dreht, das
// Häkchen bleibt, wo es war — und kein Wort dazu, das er sehen könnte.
//
// Die Modellliste hier ist **erfunden**, in derselben Form wie die von
// Google (`name`, `displayName`, `supportedGenerationMethods`). Kein echter
// Schlüssel.
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
import 'package:repit/health/health_provider.dart';
import 'package:repit/ki/gemini_client.dart';
import 'package:repit/ki/ki_repository.dart';
import 'package:repit/ki/ki_schluessel.dart';
import 'package:repit/ki/ki_zugang_view.dart';

const _schluessel = 'test-schluessel-erfunden-2222-lmno';
final _jetzt = DateTime.utc(2031, 3, 14, 11, 30);

/// 22 erfundene Modelle — so viele, wie der Filter an der echten Liste
/// übrig lässt. Das gewählte (`gemini-3.6-flash`) steht in der Mitte, das
/// letzte stabile weit unten.
const _ids = [
  'gemini-pro-latest',
  'gemini-flash-latest',
  'gemini-flash-lite-latest',
  'gemini-9.1-flash',
  'gemini-9.0-pro',
  'gemini-8.5-flash',
  'gemini-8.0-flash',
  'gemini-7.5-flash-lite',
  'gemini-7.0-pro',
  'gemini-3.6-flash',
  'gemini-3.5-flash',
  'gemini-3.5-flash-lite',
  'gemini-3.1-flash-lite',
  'gemini-2.5-pro',
  'gemini-2.5-flash-lite',
  'gemini-2.5-flash',
  'gemini-9.9-flash-preview',
  'gemini-9.8-pro-preview',
  'gemini-9.7-flash-lite-preview',
  'gemini-9.6-flash-exp',
  'gemini-9.5-pro-preview',
  'gemini-9.4-flash-preview',
];

http.Response _json(int status, Object koerper) => http.Response(
  jsonEncode(koerper),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

http.Response _liste() => _json(200, {
  'models': [
    for (final id in _ids)
      {
        'name': 'models/$id',
        'displayName': id,
        'supportedGenerationMethods': ['generateContent', 'countTokens'],
      },
  ],
});

final _testbildOk = _json(200, {
  'candidates': [
    {
      'content': {
        'parts': [
          {'text': 'OK'},
        ],
      },
    },
  ],
  'usageMetadata': {
    'promptTokenCount': 300,
    'candidatesTokenCount': 2,
    'thoughtsTokenCount': 0,
  },
});

final _testbildAbgelehnt = _json(400, {
  'error': {'code': 400, 'status': 'INVALID_ARGUMENT', 'message': 'erfunden'},
});

Future<void> _ruhe(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Baut den KI-Zugang auf einem Telefon (393 × 852 Punkte) mit Schlüssel
/// und gewähltem `gemini-3.6-flash`. [testbild] beantwortet jedes POST.
Future<KiRepository> _zeige(
  WidgetTester tester, {
  required http.Response Function() testbild,
}) async {
  tester.view.physicalSize = const Size(1179, 2556);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final db = AppCache(NativeDatabase.memory());
  addTearDown(db.close);
  final repo = KiRepository(db);
  await repo.setzeModell('gemini-3.6-flash');
  final speicher = AttrappenSchluesselSpeicher();
  await speicher.schreibe(_schluessel);

  final client = MockClient(
    (anfrage) async => anfrage.method == 'GET' ? _liste() : testbild(),
  );
  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      appCacheProvider.overrideWithValue(db),
      clockProvider.overrideWithValue(() => _jetzt),
      kiSchluesselProvider.overrideWithValue(speicher),
      kiAnbieterProvider.overrideWithValue(GeminiAnbieter(client)),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const CupertinoApp(home: KiZugangSeite()),
    ),
  );
  await _ruhe(tester);
  return repo;
}

/// Öffnet das Blatt, scrollt bis [id] und tippt es an.
Future<void> _waehle(WidgetTester tester, String id) async {
  await tester.tap(find.byKey(const Key('ki-zugang-modell')));
  await _ruhe(tester);
  expect(find.byKey(const Key('ki-modell-blatt')), findsOneWidget);

  final zeile = find.byKey(Key('ki-modell-$id'));
  await tester.scrollUntilVisible(
    zeile,
    200,
    scrollable: find
        .descendant(
          of: find.byKey(const Key('ki-modell-blatt')),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pump();
  await tester.tap(zeile.hitTestable());
  await _ruhe(tester);
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('de_DE');
  });

  testWidgets('Testbild abgelehnt, Modell weit unten: der Grund steht '
      'sichtbar im Blatt, nicht unterhalb davon', (tester) async {
    final repo = await _zeige(tester, testbild: () => _testbildAbgelehnt);

    await _waehle(tester, 'gemini-2.5-flash');

    expect(find.byKey(const Key('ki-modell-blatt')), findsOneWidget);
    expect((await repo.einstellungen()).modell, 'gemini-3.6-flash');
    expect(find.byKey(const Key('ki-modell-grund')), findsOneWidget);
    expect(
      find.byKey(const Key('ki-modell-grund')).hitTestable(),
      findsOneWidget,
      reason:
          'Der Grund muss auf dem Schirm stehen — sonst sieht Tim nur, dass '
          'nichts passiert.',
    );
  });

  testWidgets('Testbild 200, Modell weit unten: das neue gilt, das Blatt '
      'schließt', (tester) async {
    final repo = await _zeige(tester, testbild: () => _testbildOk);

    await _waehle(tester, 'gemini-2.5-flash');

    expect(find.byKey(const Key('ki-modell-blatt')), findsNothing);
    expect((await repo.einstellungen()).modell, 'gemini-2.5-flash');
  });
}
