// Der Schirm **„KI-Zugang"** (#339, Plan
// `docs/superpowers/plans/2026-11-04-ki-zugang.md`, Task 8).
//
// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
// Für Widget-Tests genügt laut Plan ein Agent, solange dieser Test zuerst
// entsteht, rot gesehen und **vor** der Implementierung committet wird. Ab
// dem Commit bewacht ihn `.githooks/pre-commit`: Wer einen Fall für falsch
// hält, meldet ihn, statt ihn passend zu machen.
//
// ## Woher die Anforderungen kommen
//
// - Spec `docs/superpowers/specs/2026-11-04-ki-zugang-design.md`, „Der
//   Schlüssel", „Modellwahl", „Verbrauch und Limit", „Zustände und die
//   eine Form".
// - Entwurf `docs/screens/screens/ki-zugang.js`, alle 14 Zustände.
// - Pflichtfälle aus Task 8, Step 1, wörtlich übernommen.
//
// ## Festgelegte öffentliche API
//
// ```dart
// // lib/ki/ki_zugang_view.dart
// /// Schiebt den Schirm auf den Stapel des **aktuell gewählten** Tabs.
// void oeffneKiZugang(AppRouter router);
//
// /// Gerüst und Navigationsleiste um den Schirm, **kein** eigener
// /// Navigator. Der Schirm besorgt seine Daten selbst
// /// (`kiZugangProvider`).
// class KiZugangSeite extends StatelessWidget {
//   const KiZugangSeite({super.key});
// }
// ```
//
// Dazu im Mehr-Menü eine **aktive** Zeile „KI-Zugang" (Plan: unter
// „Verwalten", benannte Abweichung vom Board).
//
// Die Abhängigkeiten, die der Test ersetzt: `kiSchluesselProvider`
// (Attrappe), `kiAnbieterProvider` (der echte `GeminiAnbieter` über einem
// `MockClient` — so prüft der Test auch die Fehlerabbildung bis in die
// Ansicht), `appCacheProvider` (drift im Arbeitsspeicher) und
// `clockProvider`.
//
// ## Die Schlüssel
//
// Schirm:
// - `ki-zugang-gruppe-gemini`, `ki-zugang-gruppe-modell`,
//   `ki-zugang-gruppe-verbrauch` — die drei Gruppen. **Stehen in jedem
//   Zustand.** Je der ganze Block der Gruppe (Kopf, Karte, Hinweise).
// - `ki-zugang-schluessel` — die Zeile „Schlüssel" (Tür ins Eintragblatt).
// - `ki-zugang-geprueft` — der Wert der Zeile „Geprüft".
// - `ki-zugang-modell` — die Zeile „Foto-Schätzung" (Tür ins Modellblatt).
// - `ki-zugang-monat`, `ki-zugang-anfragen` — die beiden Werte des
//   Verbrauchs.
// - `ki-zugang-hinweis-oben` — der Hinweis über den Gruppen (Modell weg,
//   gespeicherter Schlüssel abgelehnt, kein Netz, Kontingent). Fehlt, wenn
//   es nichts zu sagen gibt.
// - `ki-zugang-limit-hinweis` — der Hinweis „Monatslimit erreicht".
// - `ki-zugang-knopf` — der Knopf unten („Schlüssel hinterlegen" bzw.
//   „Schlüssel entfernen").
//
// Blatt „Gemini-Schlüssel":
// - `ki-schluessel-blatt`, `ki-schluessel-feld` (das `CupertinoTextField`
//   selbst), `ki-schluessel-sichern`, `ki-schluessel-abbrechen`.
// - `ki-schluessel-prueft`, `ki-schluessel-abgelehnt`,
//   `ki-schluessel-kein-netz` — die Füllung der Ergebnisfläche.
//
// Blatt „Modell für Fotos":
// - `ki-modell-blatt`; je Modell `ki-modell-<id>`; die grauen Zeilen
//   während des Ladens tragen `ki-modell-grau`.
// - `ki-modell-grund` — warum ein Modell nicht übernommen wurde.
//
// Bestätigung „Schlüssel entfernen?":
// - `ki-entfernen-blatt`, `ki-entfernen-bestaetigen`,
//   `ki-entfernen-abbrechen`.
//
// ## Entscheidungen des Test-Agenten (nicht mit Tim abgestimmt)
//
// 1. **Mit Schlüssel prüft der Schirm beim ersten Öffnen einmal nach**
//    (Modellliste abrufen). Daraus folgen die Zustände „Modell nicht mehr
//    angeboten", „Gespeicherter Schlüssel abgelehnt" und „Kein Netz" des
//    Entwurfs — ohne Nachlauf gäbe es sie nicht. Ohne Schlüssel geht
//    keine Anfrage hinaus.
// 2. **Ein Wert, der dastand, steht nach dem Zurücknavigieren sofort
//    wieder da** (`32`) — der Test sperrt das Netz beim zweiten Öffnen und
//    erwartet die Endung trotzdem.
// 3. **Der Status „Geprüft" sagt bei einem abgelehnten Schlüssel
//    „abgelehnt"** (Entwurf: „heute, 12:10 · abgelehnt"). Geprüft wird nur,
//    ob das Wort dasteht oder fehlt — das ist der Zustand, nicht die
//    Beschriftung.
//
// ## Was hier absichtlich **nicht** geprüft wird
//
// Layout, Farben, Schriftgrößen, der Wortlaut von Hinweisen und
// Knöpfen (`CLAUDE.md`). Ausnahmen, weil der Plan sie als Zustand nennt:
// `–/–` im Status ohne Schlüssel, der Knopf „Schlüssel hinterlegen" und das
// Enddatum im Limit-Hinweis.
//
// ## Erfundene Werte
//
// Der Schlüssel ist eine erfundene Zeichenfolge **ohne** das Präfix
// `AIza`. Kein Test geht ins Netz. Die Uhr steht im März 2031.
import 'dart:async';
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
import 'package:repit/design/platzhalter.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/ki/gemini_client.dart';
import 'package:repit/ki/gemini_preise.dart';
import 'package:repit/ki/ki_repository.dart';
import 'package:repit/ki/ki_schluessel.dart';
import 'package:repit/ki/ki_zugang_view.dart';
import 'package:repit/shell/mehr_view.dart';
import 'package:repit/shell/router.dart';

import '../design/support.dart' show textOf;

/// Erfunden, ohne `AIza`.
const _schluessel = 'test-schluessel-erfunden-0000-wxyz';

/// Ein zweiter, ebenso erfundener — für „ersetzen".
const _andererSchluessel = 'test-schluessel-anders-1111-qrst';

/// Die Uhr der Tests: 14. März 2031, mittags Berliner Zeit.
final _jetzt = DateTime.utc(2031, 3, 14, 11, 30);

const _gruppen = [
  Key('ki-zugang-gruppe-gemini'),
  Key('ki-zugang-gruppe-modell'),
  Key('ki-zugang-gruppe-verbrauch'),
];

http.Response _json(int status, Object koerper) => http.Response(
  jsonEncode(koerper),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

/// Die Modellliste, wie Google sie schickt — nur Felder, die der Filter
/// liest.
http.Response _liste(List<String> ids) => _json(200, {
  'models': [
    for (final id in ids)
      {
        'name': 'models/$id',
        'displayName': id,
        'supportedGenerationMethods': ['generateContent'],
      },
  ],
});

final _abgelehnt400 = _json(400, {
  'error': {
    'code': 400,
    'status': 'INVALID_ARGUMENT',
    'details': [
      {
        '@type': 'type.googleapis.com/google.rpc.ErrorInfo',
        'reason': 'API_KEY_INVALID',
      },
    ],
  },
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
    'thoughtsTokenCount': 10,
  },
});

/// Ein Testaufbau: Speicher, Datenbank, Netz und Behälter.
class _Aufbau {
  _Aufbau(this.db, this.speicher);

  final AppCache db;
  final AttrappenSchluesselSpeicher speicher;

  /// Was jede Anfrage beantwortet. Wird pro Test gesetzt.
  FutureOr<http.Response> Function(http.Request anfrage) antwort = (_) =>
      _liste(const ['gemini-3.6-flash']);

  /// Gesetzt, wartet jeder Abruf der Modellliste darauf.
  Completer<void>? sperre;

  final anfragen = <http.Request>[];

  KiRepository get repo => KiRepository(db);

  late final ProviderContainer container = () {
    final client = MockClient((anfrage) async {
      anfragen.add(anfrage);
      final s = sperre;
      if (s != null && anfrage.method == 'GET') await s.future;
      return antwort(anfrage);
    });
    final c = ProviderContainer(
      // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
      retry: (_, _) => null,
      overrides: [
        appCacheProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => _jetzt),
        kiSchluesselProvider.overrideWithValue(speicher),
        kiAnbieterProvider.overrideWithValue(GeminiAnbieter(client)),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }();

  List<http.Request> get modellAbrufe =>
      anfragen.where((a) => a.method == 'GET').toList();
}

Future<_Aufbau> _aufbau({String? schluessel}) async {
  final db = AppCache(NativeDatabase.memory());
  addTearDown(db.close);
  final speicher = AttrappenSchluesselSpeicher();
  if (schluessel != null) await speicher.schreibe(schluessel);
  return _Aufbau(db, speicher);
}

/// Lässt Zeit vergehen, ohne auf Ruhe zu warten — ein Lade-Indikator
/// dreht sich sonst ewig und `pumpAndSettle` liefe ins Zeitlimit.
Future<void> _ruhe(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _zeige(WidgetTester tester, _Aufbau a) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: a.container,
      child: const CupertinoApp(home: KiZugangSeite()),
    ),
  );
  await _ruhe(tester);
}

/// Alle Texte unterhalb (und auf) [wurzel], zusammengefügt.
String _textUnter(WidgetTester tester, Finder wurzel) {
  expect(
    wurzel,
    findsOneWidget,
    reason: 'Der Schlüssel fehlt — siehe „Die Schlüssel" im Dateikopf.',
  );
  return tester
      .widgetList<Text>(
        find.descendant(
          of: wurzel,
          matching: find.byType(Text),
          matchRoot: true,
        ),
      )
      .map(textOf)
      .join(' ');
}

/// Alle sichtbaren Texte im Baum.
Iterable<String> _alleTexte(WidgetTester tester) =>
    tester.widgetList<Text>(find.byType(Text)).map(textOf);

CupertinoButton _knopf(WidgetTester tester, Key key) =>
    tester.widget<CupertinoButton>(
      find
          .descendant(
            of: find.byKey(key),
            matching: find.byType(CupertinoButton),
            matchRoot: true,
          )
          .first,
    );

CupertinoTextField _feld(WidgetTester tester) => tester
    .widget<CupertinoTextField>(find.byKey(const Key('ki-schluessel-feld')));

Future<void> _oeffneEintragen(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('ki-zugang-knopf')));
  await _ruhe(tester);
  expect(find.byKey(const Key('ki-schluessel-blatt')), findsOneWidget);
}

Future<void> _tippeSchluessel(WidgetTester tester, String wert) async {
  await tester.enterText(find.byKey(const Key('ki-schluessel-feld')), wert);
  await tester.pump();
}

Future<void> _sichere(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('ki-schluessel-sichern')));
  await _ruhe(tester);
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('de_DE');
  });

  group('ohne Schlüssel', () {
    testWidgets('Status –/–, Knopf „Schlüssel hinterlegen", drei Gruppen', (
      tester,
    ) async {
      final a = await _aufbau();
      await _zeige(tester, a);

      for (final g in _gruppen) {
        expect(find.byKey(g), findsOneWidget, reason: '$g fehlt');
      }
      expect(
        _textUnter(tester, find.byKey(const Key('ki-zugang-geprueft'))),
        contains(ohneWert),
      );
      expect(
        _textUnter(tester, find.byKey(const Key('ki-zugang-knopf'))),
        contains('Schlüssel hinterlegen'),
      );
      expect(find.byKey(const Key('ki-zugang-hinweis-oben')), findsNothing);
      expect(
        a.anfragen,
        isEmpty,
        reason: 'Ohne Schlüssel geht keine Anfrage hinaus.',
      );
    });

    testWidgets('die Gruppen haben dieselbe Höhe wie mit gültigem Schlüssel', (
      tester,
    ) async {
      final ohne = await _aufbau();
      await _zeige(tester, ohne);
      final hoehenOhne = [
        for (final g in _gruppen) tester.getSize(find.byKey(g)).height,
      ];

      final mit = await _aufbau(schluessel: _schluessel);
      await mit.repo.setzePruefung(_jetzt, 'gueltig');
      await _zeige(tester, mit);
      final hoehenMit = [
        for (final g in _gruppen) tester.getSize(find.byKey(g)).height,
      ];

      expect(
        hoehenMit,
        hoehenOhne,
        reason: 'Eine Anzeige hat genau eine Form (CLAUDE.md).',
      );
    });
  });

  group('Schlüssel eintragen', () {
    testWidgets('das Feld ist verdeckt', (tester) async {
      final a = await _aufbau();
      await _zeige(tester, a);
      await _oeffneEintragen(tester);

      expect(_feld(tester).obscureText, isTrue);
    });

    testWidgets('Sichern mit 200: Endung sichtbar, Speicher hält den Wert', (
      tester,
    ) async {
      final a = await _aufbau();
      a.antwort = (_) => _liste(const ['gemini-3.6-flash']);
      await _zeige(tester, a);
      await _oeffneEintragen(tester);
      await _tippeSchluessel(tester, _schluessel);
      await _sichere(tester);

      expect(await a.speicher.lies(), _schluessel);
      expect(
        find.byKey(const Key('ki-schluessel-blatt')),
        findsNothing,
        reason: 'Nach dem Sichern schließt das Blatt.',
      );
      expect(
        _textUnter(tester, find.byKey(const Key('ki-zugang-schluessel'))),
        contains(endung(_schluessel)),
      );
      expect(
        _textUnter(tester, find.byKey(const Key('ki-zugang-geprueft'))),
        isNot(contains(ohneWert)),
      );
      expect(
        _textUnter(tester, find.byKey(const Key('ki-zugang-knopf'))),
        isNot(contains('Schlüssel hinterlegen')),
      );

      // Der Schlüssel steht nirgends im Klartext, nur seine Endung.
      for (final t in _alleTexte(tester)) {
        expect(t, isNot(contains(_schluessel)));
      }
      // Und er ging nur im Kopf mit.
      expect(a.anfragen, isNotEmpty);
      for (final r in a.anfragen) {
        expect(r.headers['x-goog-api-key'], _schluessel);
        expect(r.url.toString(), isNot(contains(_schluessel)));
      }
      expect((await a.repo.einstellungen()).pruefErgebnis, 'gueltig');
    });

    testWidgets(
      'Sichern mit 400: Speicher leer, Grund im Blatt, Feld gefüllt',
      (tester) async {
        final a = await _aufbau();
        a.antwort = (_) => _abgelehnt400;
        await _zeige(tester, a);
        await _oeffneEintragen(tester);
        await _tippeSchluessel(tester, _schluessel);
        await _sichere(tester);

        expect(await a.speicher.lies(), isNull);
        expect(find.byKey(const Key('ki-schluessel-blatt')), findsOneWidget);
        expect(
          find.byKey(const Key('ki-schluessel-abgelehnt')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('ki-schluessel-kein-netz')), findsNothing);
        expect(
          _feld(tester).controller!.text,
          _schluessel,
          reason: 'Das Feld bleibt gefüllt, damit man den Tippfehler sieht.',
        );
      },
    );

    testWidgets('Sichern ohne Netz: Speicher leer, kein „abgelehnt"', (
      tester,
    ) async {
      final a = await _aufbau();
      a.antwort = (_) => throw http.ClientException('offline');
      await _zeige(tester, a);
      await _oeffneEintragen(tester);
      await _tippeSchluessel(tester, _schluessel);
      await _sichere(tester);

      expect(
        await a.speicher.lies(),
        isNull,
        reason: 'Ungeprüft wird nicht gesichert.',
      );
      expect(find.byKey(const Key('ki-schluessel-kein-netz')), findsOneWidget);
      expect(find.byKey(const Key('ki-schluessel-abgelehnt')), findsNothing);
      for (final t in _alleTexte(tester)) {
        expect(
          t.toLowerCase(),
          isNot(contains('abgelehnt')),
          reason: 'Ohne Netz ist über den Schlüssel nichts bekannt.',
        );
        expect(t.toLowerCase(), isNot(contains('ungültig')));
      }
      expect(_feld(tester).controller!.text, _schluessel);
      expect((await a.repo.einstellungen()).pruefErgebnis, isNull);
    });

    testWidgets('während der Prüfung ist „Sichern" aus', (tester) async {
      final a = await _aufbau();
      final antwort = Completer<http.Response>();
      a.antwort = (_) => antwort.future;
      await _zeige(tester, a);
      await _oeffneEintragen(tester);
      await _tippeSchluessel(tester, _schluessel);
      await tester.tap(find.byKey(const Key('ki-schluessel-sichern')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('ki-schluessel-prueft')), findsOneWidget);
      expect(
        _knopf(tester, const Key('ki-schluessel-sichern')).onPressed,
        isNull,
      );

      await tester.tap(
        find.byKey(const Key('ki-schluessel-sichern')),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(
        a.anfragen,
        hasLength(1),
        reason: 'Ein zweiter Tipp startet keinen zweiten Abruf.',
      );

      antwort.complete(_liste(const ['gemini-3.6-flash']));
      await _ruhe(tester);
      expect(await a.speicher.lies(), _schluessel);
    });

    testWidgets('ersetzen: über die Zeile „Schlüssel" kommt ein neuer hinein', (
      tester,
    ) async {
      final a = await _aufbau(schluessel: _schluessel);
      await a.repo.setzePruefung(_jetzt, 'gueltig');
      await _zeige(tester, a);

      await tester.tap(find.byKey(const Key('ki-zugang-schluessel')));
      await _ruhe(tester);
      expect(find.byKey(const Key('ki-schluessel-blatt')), findsOneWidget);
      expect(
        _feld(tester).controller!.text,
        isEmpty,
        reason: 'Der gesicherte Schlüssel wird nie zurück ins Feld gelesen.',
      );

      await _tippeSchluessel(tester, _andererSchluessel);
      await _sichere(tester);

      expect(await a.speicher.lies(), _andererSchluessel);
      expect(
        _textUnter(tester, find.byKey(const Key('ki-zugang-schluessel'))),
        contains(endung(_andererSchluessel)),
      );
    });
  });

  group('mit Schlüssel beim Öffnen', () {
    testWidgets('kein Netz: der letzte Stand bleibt, nichts heißt abgelehnt', (
      tester,
    ) async {
      final a = await _aufbau(schluessel: _schluessel);
      await a.repo.setzePruefung(_jetzt, 'gueltig');
      a.antwort = (_) => throw http.ClientException('offline');
      await _zeige(tester, a);

      expect(
        _textUnter(tester, find.byKey(const Key('ki-zugang-schluessel'))),
        contains(endung(_schluessel)),
      );
      final status = _textUnter(
        tester,
        find.byKey(const Key('ki-zugang-geprueft')),
      );
      expect(status, contains('gültig'));
      expect(status, isNot(contains('abgelehnt')));
      expect(
        find.byKey(const Key('ki-zugang-hinweis-oben')),
        findsOneWidget,
        reason: 'Der Schirm sagt, dass er den alten Stand zeigt.',
      );
      expect(await a.speicher.lies(), _schluessel);
      expect((await a.repo.einstellungen()).pruefErgebnis, 'gueltig');
    });

    testWidgets(
      'gespeicherter Schlüssel abgelehnt: Status, Hinweis, er bleibt',
      (tester) async {
        final a = await _aufbau(schluessel: _schluessel);
        await a.repo.setzePruefung(_jetzt, 'gueltig');
        a.antwort = (_) => _json(403, {
          'error': {'code': 403, 'status': 'PERMISSION_DENIED'},
        });
        await _zeige(tester, a);

        expect(
          _textUnter(tester, find.byKey(const Key('ki-zugang-geprueft'))),
          contains('abgelehnt'),
        );
        expect(find.byKey(const Key('ki-zugang-hinweis-oben')), findsOneWidget);
        expect(
          _textUnter(tester, find.byKey(const Key('ki-zugang-schluessel'))),
          contains(endung(_schluessel)),
          reason: 'Er bleibt stehen, damit man sieht, welcher es war.',
        );
        expect(await a.speicher.lies(), _schluessel);
        expect((await a.repo.einstellungen()).pruefErgebnis, 'abgelehnt');
      },
    );

    testWidgets('gültig und gemerktes Modell in der Liste: kein Hinweis oben', (
      tester,
    ) async {
      final a = await _aufbau(schluessel: _schluessel);
      await a.repo.setzeModell('gemini-3.5-flash-lite');
      a.antwort = (_) =>
          _liste(const ['gemini-3.6-flash', 'gemini-3.5-flash-lite']);
      await _zeige(tester, a);

      expect(find.byKey(const Key('ki-zugang-hinweis-oben')), findsNothing);
      expect(
        _textUnter(tester, find.byKey(const Key('ki-zugang-modell'))),
        contains('gemini-3.5-flash-lite'),
      );
      expect(
        a.modellAbrufe,
        hasLength(1),
        reason: 'Mit Schlüssel prüft der Schirm beim Öffnen einmal nach.',
      );
    });

    testWidgets('gemerktes Modell fehlt: Hinweis oben, Voreinstellung gilt', (
      tester,
    ) async {
      final a = await _aufbau(schluessel: _schluessel);
      await a.repo.setzeModell('gemini-2.0-weg-preview');
      a.antwort = (_) =>
          _liste(const ['gemini-3.6-flash', 'gemini-3.5-flash-lite']);
      await _zeige(tester, a);

      expect(
        _textUnter(tester, find.byKey(const Key('ki-zugang-hinweis-oben'))),
        contains('gemini-2.0-weg-preview'),
      );
      expect(
        _textUnter(tester, find.byKey(const Key('ki-zugang-modell'))),
        contains(voreingestelltesModell),
      );
    });
  });

  group('Modell wählen', () {
    testWidgets('Modellblatt lädt: graue Zeilen, danach die Liste', (
      tester,
    ) async {
      final a = await _aufbau(schluessel: _schluessel);
      a.antwort = (_) =>
          _liste(const ['gemini-3.6-flash', 'gemini-3.5-flash-lite']);
      await _zeige(tester, a);

      a.sperre = Completer<void>();
      await tester.tap(find.byKey(const Key('ki-zugang-modell')));
      await _ruhe(tester);

      expect(find.byKey(const Key('ki-modell-blatt')), findsOneWidget);
      expect(find.byKey(const Key('ki-modell-grau')), findsWidgets);
      expect(find.byKey(const Key('ki-modell-gemini-3.6-flash')), findsNothing);
      // Der Schirm dahinter zeigt das gewählte Modell weiter.
      expect(
        _textUnter(tester, find.byKey(const Key('ki-zugang-modell'))),
        contains('gemini-3.6-flash'),
      );

      a.sperre!.complete();
      await _ruhe(tester);

      expect(find.byKey(const Key('ki-modell-grau')), findsNothing);
      expect(
        find.byKey(const Key('ki-modell-gemini-3.6-flash')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('ki-modell-gemini-3.5-flash-lite')),
        findsOneWidget,
      );
      expect(
        a.modellAbrufe,
        hasLength(2),
        reason: 'Die Liste wird beim Öffnen des Blatts live geholt.',
      );
    });

    testWidgets('Testbild 200: das neue Modell gilt, seine Token zählen', (
      tester,
    ) async {
      final a = await _aufbau(schluessel: _schluessel);
      a.antwort = (r) => r.method == 'POST'
          ? _testbildOk
          : _liste(const ['gemini-3.6-flash', 'gemini-3.5-flash-lite']);
      await _zeige(tester, a);
      final vorher = await a.repo.monat(monatsSchluessel(_jetzt));

      await tester.tap(find.byKey(const Key('ki-zugang-modell')));
      await _ruhe(tester);
      await tester.tap(
        find.byKey(const Key('ki-modell-gemini-3.5-flash-lite')),
      );
      await _ruhe(tester);

      expect(find.byKey(const Key('ki-modell-blatt')), findsNothing);
      expect((await a.repo.einstellungen()).modell, 'gemini-3.5-flash-lite');
      expect(
        _textUnter(tester, find.byKey(const Key('ki-zugang-modell'))),
        contains('gemini-3.5-flash-lite'),
      );
      final nachher = await a.repo.monat(monatsSchluessel(_jetzt));
      expect(
        nachher.anfragen,
        vorher.anfragen + 1,
        reason: 'Die Token des Testbilds zählen in den Verbrauch.',
      );
      expect(
        _textUnter(tester, find.byKey(const Key('ki-zugang-anfragen'))),
        contains('${nachher.anfragen}'),
      );
    });

    testWidgets(
      'Testbild abgelehnt: das alte bleibt, der Grund steht im Blatt',
      (tester) async {
        final a = await _aufbau(schluessel: _schluessel);
        await a.repo.setzeModell('gemini-3.6-flash');
        a.antwort = (r) => r.method == 'POST'
            ? _json(400, {
                'error': {'code': 400, 'status': 'INVALID_ARGUMENT'},
              })
            : _liste(const ['gemini-3.6-flash', 'gemini-3.5-flash-lite']);
        await _zeige(tester, a);

        await tester.tap(find.byKey(const Key('ki-zugang-modell')));
        await _ruhe(tester);
        await tester.tap(
          find.byKey(const Key('ki-modell-gemini-3.5-flash-lite')),
        );
        await _ruhe(tester);

        expect(find.byKey(const Key('ki-modell-blatt')), findsOneWidget);
        expect(find.byKey(const Key('ki-modell-grund')), findsOneWidget);
        expect((await a.repo.einstellungen()).modell, 'gemini-3.6-flash');
      },
    );
  });

  group('Verbrauch und Limit', () {
    testWidgets('Limit erreicht: Hinweis mit dem Ersten des Folgemonats', (
      tester,
    ) async {
      final a = await _aufbau(schluessel: _schluessel);
      await a.repo.setzeLimit(1);
      for (var i = 0; i < 2; i++) {
        await a.repo.protokolliere(
          zeitpunkt: _jetzt,
          modell: 'gemini-3.6-flash',
          zweck: 'foto',
          verbrauch: const KiVerbrauch(eingabe: 1, ausgabe: 1, denken: 0),
          kosten: 0.6,
        );
      }
      await _zeige(tester, a);

      expect(
        _textUnter(tester, find.byKey(const Key('ki-zugang-limit-hinweis'))),
        contains('1. April'),
      );
    });

    testWidgets('unter dem Limit: kein Limit-Hinweis', (tester) async {
      final a = await _aufbau(schluessel: _schluessel);
      await a.repo.protokolliere(
        zeitpunkt: _jetzt,
        modell: 'gemini-3.6-flash',
        zweck: 'foto',
        verbrauch: const KiVerbrauch(eingabe: 1, ausgabe: 1, denken: 0),
        kosten: 0.5,
      );
      await _zeige(tester, a);

      expect(find.byKey(const Key('ki-zugang-limit-hinweis')), findsNothing);
    });
  });

  group('Schlüssel entfernen', () {
    testWidgets('Bestätigung, danach ohne Schlüssel, Verbrauch bleibt', (
      tester,
    ) async {
      final a = await _aufbau(schluessel: _schluessel);
      await a.repo.setzePruefung(_jetzt, 'gueltig');
      for (var i = 0; i < 3; i++) {
        await a.repo.protokolliere(
          zeitpunkt: _jetzt,
          modell: 'gemini-3.6-flash',
          zweck: 'foto',
          verbrauch: const KiVerbrauch(eingabe: 1000, ausgabe: 100, denken: 0),
          kosten: 0.25,
        );
      }
      await _zeige(tester, a);
      final monatVorher = _textUnter(
        tester,
        find.byKey(const Key('ki-zugang-monat')),
      );
      final anfragenVorher = _textUnter(
        tester,
        find.byKey(const Key('ki-zugang-anfragen')),
      );

      await tester.tap(find.byKey(const Key('ki-zugang-knopf')));
      await _ruhe(tester);
      expect(find.byKey(const Key('ki-entfernen-blatt')), findsOneWidget);
      expect(
        await a.speicher.lies(),
        _schluessel,
        reason: 'Erst die Bestätigung löscht.',
      );

      await tester.tap(find.byKey(const Key('ki-entfernen-bestaetigen')));
      await _ruhe(tester);

      expect(await a.speicher.lies(), isNull);
      expect(find.byKey(const Key('ki-entfernen-blatt')), findsNothing);
      expect(
        _textUnter(tester, find.byKey(const Key('ki-zugang-geprueft'))),
        contains(ohneWert),
      );
      expect(
        _textUnter(tester, find.byKey(const Key('ki-zugang-knopf'))),
        contains('Schlüssel hinterlegen'),
      );
      for (final g in _gruppen) {
        expect(find.byKey(g), findsOneWidget);
      }
      expect(
        _textUnter(tester, find.byKey(const Key('ki-zugang-monat'))),
        monatVorher,
      );
      expect(
        _textUnter(tester, find.byKey(const Key('ki-zugang-anfragen'))),
        anfragenVorher,
      );
    });

    testWidgets('Abbrechen in der Bestätigung lässt den Schlüssel stehen', (
      tester,
    ) async {
      final a = await _aufbau(schluessel: _schluessel);
      await _zeige(tester, a);

      await tester.tap(find.byKey(const Key('ki-zugang-knopf')));
      await _ruhe(tester);
      await tester.tap(find.byKey(const Key('ki-entfernen-abbrechen')));
      await _ruhe(tester);

      expect(find.byKey(const Key('ki-entfernen-blatt')), findsNothing);
      expect(await a.speicher.lies(), _schluessel);
      expect(
        _textUnter(tester, find.byKey(const Key('ki-zugang-schluessel'))),
        contains(endung(_schluessel)),
      );
    });
  });

  testWidgets('ein Wert, der dastand, steht nach dem Zurücknavigieren wieder '
      'da (32)', (tester) async {
    final a = await _aufbau(schluessel: _schluessel);
    await a.repo.setzePruefung(_jetzt, 'gueltig');
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: a.container,
        child: CupertinoApp(
          navigatorKey: navigator,
          home: const CupertinoPageScaffold(child: SizedBox.expand()),
        ),
      ),
    );

    unawaited(
      navigator.currentState!.push(
        CupertinoPageRoute<void>(builder: (_) => const KiZugangSeite()),
      ),
    );
    await _ruhe(tester);
    expect(
      _textUnter(tester, find.byKey(const Key('ki-zugang-schluessel'))),
      contains(endung(_schluessel)),
    );

    navigator.currentState!.pop();
    await _ruhe(tester);
    expect(find.byKey(const Key('ki-zugang-schluessel')), findsNothing);

    // Beim zweiten Öffnen antwortet Google nicht — der Wert muss trotzdem
    // sofort dastehen, nicht erst nach einem Lauf.
    a.sperre = Completer<void>();
    unawaited(
      navigator.currentState!.push(
        CupertinoPageRoute<void>(builder: (_) => const KiZugangSeite()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      _textUnter(tester, find.byKey(const Key('ki-zugang-schluessel'))),
      contains(endung(_schluessel)),
    );
    expect(
      _textUnter(tester, find.byKey(const Key('ki-zugang-geprueft'))),
      isNot(contains(ohneWert)),
    );
    a.sperre!.complete();
    await _ruhe(tester);
  });

  group('Einstieg', () {
    testWidgets('Mehr-Menü: „KI-Zugang" ist tippbar und schiebt auf den '
        'aktuellen Stapel', (tester) async {
      tester.view.physicalSize = const Size(800, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final router = AppRouter();
      final tabVorher = router.tab;
      await tester.pumpWidget(CupertinoApp(home: MehrView(router: router)));
      await tester.pumpAndSettle();

      expect(find.text('KI-Zugang'), findsOneWidget);
      await tester.tap(find.text('KI-Zugang'));
      await tester.pumpAndSettle();

      final befehl = router.nimmBefehl();
      expect(befehl, isNotNull);
      expect(befehl!.ersetztStapel, isFalse);
      expect(router.tab, tabVorher);
    });

    test('oeffneKiZugang schiebt auf den Stapel des aktuellen Tabs', () {
      final router = AppRouter();
      final tabVorher = router.tab;
      oeffneKiZugang(router);

      final befehl = router.nimmBefehl();
      expect(befehl, isNotNull);
      expect(befehl!.ersetztStapel, isFalse);
      expect(befehl.tab, tabVorher);
      expect(router.tab, tabVorher);
    });
  });
}
