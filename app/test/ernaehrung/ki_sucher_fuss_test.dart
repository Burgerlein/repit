import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/ernaehrung/ki_sucher.dart';
import 'package:repit/ernaehrung/off_client.dart';
import 'package:repit/ernaehrung/strichcode_leser.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/ki/gemini_client.dart';
import 'package:repit/ki/ki_repository.dart';
import 'package:repit/ki/ki_schluessel.dart';
import 'package:repit/shell/root_view.dart';
import 'package:repit/shell/router.dart';

import '../health/health_reading_attrappe.dart';
import 'foto_attrappe.dart';
import 'kamera_attrappe.dart';
import '../tag/behaelter_im_baum.dart';

/// **#355 — der Datenweg steht im Fuß des KI-Suchers.**
///
/// Tim, 04.11.2026, auf dem iPhone: Nach dem Foto kommt **kein**
/// Hinweisblatt („Noch etwas dazu?") mehr; das Foto geht direkt in die
/// Schätzung. Der Satz zum Datenweg stand bis dahin in diesem Blatt (Spec
/// `docs/superpowers/specs/2026-11-04-ki-zugang-design.md`, „Texte, die
/// Zusagen sind": iOS zeigt den Kamera-Freigabetext nur einmal pro
/// Installation, deshalb sagt es die App **vor** dem Foto noch einmal).
/// Er wandert in den Fuß des Suchers — unter den Auslöser — und steht dort
/// **dauerhaft**, solange Schlüssel und Limit eine Schätzung erlauben:
///
/// > Das Foto geht zur Schätzung an Google Gemini und wird nach dem Buchen
/// > verworfen.
///
/// Der Wortlaut ist der aus dem Auftrag des Koordinators für #355; der
/// Ablauf (kein Blatt, Satz im Fuß) ist Tims Entscheidung.
///
/// Was der alte Satz zusagte, gilt weiter: **vor** dem Foto, bei **jedem**
/// Foto — ein Satz, der beim zweiten Mal fehlt, ließe den Fuß springen.
/// Ohne Schlüssel oder über dem Limit gibt es kein Foto; dort steht der
/// Weg in den KI-Zugang, und eine Zusage über ein Foto, das nicht
/// aufgenommen werden kann, steht nicht da.
///
/// Geprüft an der ganzen App (`RootView`) wie `ki_sucher_test.dart`, mit
/// derselben Naht `kiSchaetzungStartenProvider`. Alle Schlüssel und Zahlen
/// sind **erfunden**.
void main() {
  setUpAll(() async {
    await initializeDateFormatting('de_DE');
  });

  // Dienstag, 14.07.2026, 12:00 Berliner Zeit (MESZ, +2).
  final jetzt = DateTime.utc(2026, 7, 14, 10);

  // Erfunden, ohne das Präfix echter Schlüssel.
  const schluessel = 'erfunden-schluessel-fuss';

  const datenweg =
      'Das Foto geht zur Schätzung an Google Gemini und wird nach dem '
      'Buchen verworfen.';

  ({
    ProviderContainer container,
    AppCache db,
    AttrappenSchluesselSpeicher speicher,
    List<KiAuftrag> auftraege,
  })
  behaelter() {
    final db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);
    final speicher = AttrappenSchluesselSpeicher();
    final auftraege = <KiAuftrag>[];

    final gemini = MockClient((anfrage) async {
      if (anfrage.method != 'GET') {
        fail('unerwartete Anfrage an Gemini: ${anfrage.url.path}');
      }
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
    });

    // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
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
        kiSchaetzungStartenProvider.overrideWithValue(
          (context, auftrag) async => auftraege.add(auftrag),
        ),
      ],
    );
    addTearDown(container.dispose);
    return (
      container: container,
      db: db,
      speicher: speicher,
      auftraege: auftraege,
    );
  }

  Future<void> ruhe(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> tippe(WidgetTester tester, Finder ziel) async {
    await tester.tap(ziel);
    await ruhe(tester);
  }

  /// App starten, (+) → Kamera → „KI".
  Future<void> zurKi(WidgetTester tester, ProviderContainer container) async {
    tester.view.physicalSize = const Size(900, 4800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      BehaelterImBaum(
        container: container,
        child: CupertinoApp(home: RootView(router: AppRouter())),
      ),
    );
    await tester.pumpAndSettle();
    await tippe(tester, find.byKey(const Key('erfassen-knopf')));
    await tippe(tester, find.byKey(const Key('kamera-modus-ki')));
    expect(find.byKey(const Key('ki-sucher')), findsOneWidget);
  }

  Finder satzImSucher() => find.descendant(
    of: find.byKey(const Key('ki-sucher')),
    matching: find.textContaining(datenweg),
  );

  testWidgets('mit Schlüssel und unter dem Limit steht der Datenweg im Fuß, '
      'unter dem Auslöser — schon vor dem Foto', (tester) async {
    final h = behaelter();
    await h.speicher.schreibe(schluessel);
    await zurKi(tester, h.container);

    expect(find.byKey(const Key('ki-ausloeser')), findsOneWidget);
    expect(
      satzImSucher(),
      findsOneWidget,
      reason: 'die Zusage steht vor dem Foto, nicht erst danach',
    );
    expect(
      tester.getRect(satzImSucher()).top,
      greaterThanOrEqualTo(
        tester.getRect(find.byKey(const Key('ki-ausloeser'))).bottom,
      ),
      reason: 'im Fuß: unter dem Auslöser, nicht im Fenster',
    );
  });

  testWidgets('der Satz bleibt stehen, auch nachdem ein Foto aufgenommen ist', (
    tester,
  ) async {
    final h = behaelter();
    await h.speicher.schreibe(schluessel);
    await zurKi(tester, h.container);

    await tippe(tester, find.byKey(const Key('ki-ausloeser')));
    expect(h.auftraege, hasLength(1));
    expect(find.byKey(const Key('ki-hinweis-blatt')), findsNothing);
    expect(satzImSucher(), findsOneWidget, reason: 'dauerhaft, nicht einmalig');
  });

  testWidgets('ohne Schlüssel steht er nicht da — es gibt kein Foto', (
    tester,
  ) async {
    final h = behaelter();
    await zurKi(tester, h.container);

    expect(find.byKey(const Key('ki-ohne-schluessel')), findsOneWidget);
    expect(find.textContaining(datenweg), findsNothing);
  });

  testWidgets('über dem Monatslimit steht er nicht da — es gibt kein Foto', (
    tester,
  ) async {
    final h = behaelter();
    await h.speicher.schreibe(schluessel);
    final repo = KiRepository(h.db);
    await repo.setzeLimit(1);
    await repo.protokolliere(
      zeitpunkt: jetzt.subtract(const Duration(hours: 1)),
      modell: 'gemini-3.6-flash',
      zweck: 'foto',
      verbrauch: const KiVerbrauch(eingabe: 1000, ausgabe: 200, denken: 0),
      kosten: 1.5,
    );
    await zurKi(tester, h.container);

    expect(find.byKey(const Key('ki-limit')), findsOneWidget);
    expect(find.textContaining(datenweg), findsNothing);
  });
}

/// Eine Quelle, die nichts liefert — kein Fall hier hängt an Apple Health.
class _StilleQuelle extends HealthReadingAttrappe {}
