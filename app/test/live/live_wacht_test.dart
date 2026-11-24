// `drift` exportiert eigene `isNull` und `isNotNull` (Spaltenausdrücke) —
// die verdecken sonst die gleichnamigen Matcher, die `expect` unten
// braucht. Dieselbe Begründung wie in `test/live/live_provider_test.dart`.
import 'dart:async';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/data/ernaehrung_repository.dart';
import 'package:repit/ernaehrung/ernaehrung_provider.dart';
import 'package:repit/ernaehrung/kamera_seite.dart';
import 'package:repit/ernaehrung/off_client.dart';
import 'package:repit/ernaehrung/strichcode_leser.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/live/live_anzeige.dart';
import 'package:repit/live/live_types.dart';
import 'package:repit/live/live_wacht.dart';
import 'package:repit/main.dart';
import 'package:repit/shell/root_view.dart';
import 'package:repit/shell/router.dart';
import 'package:repit/shell/ziele.dart';

import '../ernaehrung/kamera_attrappe.dart';
import '../health/health_reading_attrappe.dart';
import '../tag/behaelter_im_baum.dart';

/// Widget-Tests für **#369** — die Verdrahtung der Live-Aktivität (Task 7
/// des Plans `docs/superpowers/plans/2026-11-05-live-aktivitaet.md`, Spec
/// `docs/superpowers/specs/2026-11-05-live-aktivitaet-design.md`,
/// Abschnitt „Die Dart-Seite → Verdrahtung", V6 und V10).
///
/// **Rollen laut Plan: ein Agent.** Diese Datei entsteht zuerst, wird rot
/// gesehen und committet, bevor `live_wacht.dart` entsteht. Ab da bewacht
/// sie `.githooks/pre-commit`.
///
/// ## Was diese Datei verbindlich vorgibt (aus Plan und Spec)
///
/// In `lib/live/live_wacht.dart`:
///
/// ```dart
/// class LiveWacht extends ConsumerWidget {
///   const LiveWacht({super.key, required AppRouter router, required Widget child});
/// }
/// ```
///
/// In `lib/main.dart`:
///
/// ```dart
/// RepitApp({super.key, ProviderContainer? behaelter, AppRouter? router});
/// ```
///
/// Mit `router` umschließt `LiveWacht` die App, und `RootView` bekommt
/// **dieselbe** Instanz. Ohne `router` gibt es keine `LiveWacht`.
///
/// ## Festlegungen dieses Agenten — nicht von Tim freigegeben
///
/// - **Zustände und Übergänge, keine Beschriftung.** Gezählt werden die
///   Aufrufe an `AttrappeLiveAnzeige` und die `KameraSeite`n im Baum.
/// - **„Noch nicht gelesen" entsteht, indem die Datenbank jede Abfrage auf
///   `eintraege` zurückhält**, bis der Test sie freigibt — wie in
///   `live_provider_test.dart`.
/// - **Der Link öffnet die Kamera ohne vorgewählte Mahlzeit.** Die Spec
///   sagt „Die Mahlzeit kommt aus der Uhrzeit, wie im Buchungsblatt" —
///   das ist der Weg ohne `mahlzeit`.
/// - **Bei `LiveFehlgeschlagen` und `LiveAbgeschaltet` erscheint kein
///   Dialog.** „Nichts auf dem Schirm" wird als „kein
///   `CupertinoAlertDialog`, keine Meldung im Baum, keine Ausnahme" gelesen.
///
/// Alle Zahlen, Namen und Daten sind erfunden. Gerechnet wird im Januar
/// 2099, Berlin ist dann UTC+1.
void main() {
  // Donnerstag, 15.01.2099, 12:00 Berliner Zeit.
  final mittags = DateTime.utc(2099, 1, 15, 11);
  const heute = '2099-01-15';

  // Freitag, 16.01.2099, 02:00 Berliner Zeit — der Kalendertag ist der
  // 16., der Esstag noch der 15. (V3, Wechsel um 04:00).
  final nachts = DateTime.utc(2099, 1, 16, 1);

  Eintrag eintrag(Mahlzeit mahlzeit, {String tag = heute, double kcal = 400}) =>
      Eintrag(
        tagesSchluessel: tag,
        mahlzeit: mahlzeit,
        zeitpunkt: DateTime.parse('${tag}T11:00:00Z'),
        name: 'Prüfgericht',
        naehrwerte: Naehrwerte(kcal: kcal),
      );

  /// Echte Datenbank im Speicher, feste Uhr, Attrappen für Health,
  /// Kamera und Netz, abgeschaltete Wiederholung (`CLAUDE.md`).
  ({
    ProviderContainer container,
    ErnaehrungRepository repo,
    AttrappeLiveAnzeige anzeige,
    AppRouter router,
    _Mitschnitt mitschnitt,
  })
  aufbau({DateTime? jetzt}) {
    final uhr = jetzt ?? mittags;
    final mitschnitt = _Mitschnitt();
    final db = AppCache(NativeDatabase.memory().interceptWith(mitschnitt));
    final anzeige = AttrappeLiveAnzeige();

    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        appCacheProvider.overrideWithValue(db),
        healthProvider.overrideWithValue(_StilleQuelle()),
        clockProvider.overrideWithValue(() => uhr),
        offClientProvider.overrideWithValue(
          OffClient(client: MockClient((_) async => http.Response('', 500))),
        ),
        strichcodeLeserProvider.overrideWithValue(TestLeser()),
        liveAnzeigeProvider.overrideWithValue(anzeige),
      ],
    );
    addTearDown(() async {
      mitschnitt.gibFrei();
      container.dispose();
      await db.close();
    });
    return (
      container: container,
      repo: container.read(ernaehrungRepositoryProvider),
      anzeige: anzeige,
      router: AppRouter(),
      mitschnitt: mitschnitt,
    );
  }

  /// `LiveWacht` um eine `RootView` mit demselben Router, so wie `main.dart`
  /// sie zusammensetzt.
  Widget app(ProviderContainer container, AppRouter router) =>
      BehaelterImBaum(
        container: container,
        child: LiveWacht(
          router: router,
          child: CupertinoApp(home: RootView(router: router)),
        ),
      );

  Future<void> starte(
    WidgetTester tester,
    ProviderContainer container,
    AppRouter router, {
    bool settle = true,
  }) async {
    tester.view.physicalSize = const Size(900, 4800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(app(container, router));
    if (settle) await tester.pumpAndSettle();
  }

  /// Bucht wie das Buchungsblatt: schreiben, dann Bescheid sagen.
  Future<void> buche(
    WidgetTester tester,
    ({
      ProviderContainer container,
      ErnaehrungRepository repo,
      AttrappeLiveAnzeige anzeige,
      AppRouter router,
      _Mitschnitt mitschnitt,
    })
    b,
    Eintrag e,
  ) async {
    await b.repo.buche(e);
    await b.container
        .read(eigeneEintraegeProvider(e.tagesSchluessel).notifier)
        .neuLesen();
    await tester.pumpAndSettle();
  }

  /// Alle Kameras im Baum — **auch die verdeckten** (wie in
  /// `erfassen_knopf_stapel_test.dart`).
  int kameras(WidgetTester tester) =>
      find.byType(KameraSeite, skipOffstage: false).evaluate().length;

  MahlzeitRing ring(EssenKarte karte, Mahlzeit m) =>
      karte.ringe.singleWhere((r) => r.mahlzeit == m);

  // ─────────────────────────────────────────────────────────────────────
  group('Start', () {
    testWidgets('solange die Einträge laden, geht kein zeige an iOS; danach '
        'genau eines, frisch (V6, V10)', (tester) async {
      final b = aufbau();
      b.mitschnitt.halte((sql) => sql.contains('eintraege'));

      await starte(tester, b.container, b.router, settle: false);
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }

      expect(
        b.anzeige.zeigeAufrufe,
        isEmpty,
        reason:
            'eine Karte mit drei offenen Mahlzeiten während des Ladens '
            'behauptete „nichts gegessen" — `01` auf dem Sperrbildschirm',
      );
      expect(b.anzeige.beendeAlleAufrufe, 0);

      b.mitschnitt.gibFrei();
      await tester.pumpAndSettle();

      expect(b.anzeige.zeigeAufrufe, hasLength(1));
      expect(b.anzeige.zeigeAufrufe.single.frisch, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ohne Einträge zeigt die erste Karte alle drei '
        'Hauptmahlzeiten offen', (tester) async {
      final b = aufbau();
      await starte(tester, b.container, b.router);

      final karte = b.anzeige.zeigeAufrufe.single.karte;
      for (final m in [Mahlzeit.fruehstueck, Mahlzeit.mittag, Mahlzeit.abend]) {
        expect(ring(karte, m).eintrag, isFalse, reason: '$m');
      }
    });

    testWidgets('mit Einträgen in der Datenbank zeigt schon die erste Karte '
        'sie als erledigt', (tester) async {
      final b = aufbau();
      await b.repo.buche(eintrag(Mahlzeit.mittag));

      await starte(tester, b.container, b.router);

      expect(b.anzeige.zeigeAufrufe, hasLength(1));
      expect(
        ring(b.anzeige.zeigeAufrufe.single.karte, Mahlzeit.mittag).eintrag,
        isTrue,
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  group('Buchung', () {
    testWidgets('Buchen → genau ein weiteres zeige, nicht frisch, mit der '
        'neuen Karte', (tester) async {
      final b = aufbau();
      await starte(tester, b.container, b.router);
      expect(b.anzeige.zeigeAufrufe, hasLength(1));

      await buche(tester, b, eintrag(Mahlzeit.mittag, kcal: 500));

      expect(
        b.anzeige.zeigeAufrufe,
        hasLength(2),
        reason: 'eine Buchung ist ein Update, nicht zwei',
      );
      final zweites = b.anzeige.zeigeAufrufe.last;
      expect(
        zweites.frisch,
        isFalse,
        reason:
            'aktualisiert, nicht neu '
            'gestartet (V6)',
      );
      expect(zweites.karte, isNot(b.anzeige.zeigeAufrufe.first.karte));
      expect(ring(zweites.karte, Mahlzeit.mittag).eintrag, isTrue);
      expect(ring(zweites.karte, Mahlzeit.mittag).kcal, 500);
    });

    testWidgets('ein Neuaufbau ohne Datenänderung ruft nichts auf '
        '(Review Focus 4)', (tester) async {
      final b = aufbau();
      await starte(tester, b.container, b.router);
      expect(b.anzeige.zeigeAufrufe, hasLength(1));

      // Dieselbe App noch einmal gepumpt, ein Tabwechsel, ein Nachlesen
      // ohne Änderung — nichts davon ist eine neue Karte.
      await tester.pumpWidget(app(b.container, b.router));
      await tester.pumpAndSettle();
      b.router.open(AppTarget.ernaehrung());
      await tester.pumpAndSettle();
      await b.container
          .read(eigeneEintraegeProvider(heute).notifier)
          .neuLesen();
      await tester.pumpAndSettle();

      expect(b.anzeige.zeigeAufrufe, hasLength(1));
      expect(b.anzeige.beendeAlleAufrufe, 0);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  group('Rückkehr in den Vordergrund', () {
    testWidgets('resumed → zeige, frisch (V6)', (tester) async {
      final b = aufbau();
      await starte(tester, b.container, b.router);
      expect(b.anzeige.zeigeAufrufe, hasLength(1));

      await _sendeLebenszyklus(tester, AppLifecycleState.paused);
      await tester.pumpAndSettle();
      await _sendeLebenszyklus(tester, AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(b.anzeige.zeigeAufrufe, hasLength(2));
      expect(
        b.anzeige.zeigeAufrufe.last.frisch,
        isTrue,
        reason: 'nur ein Neustart bringt frische 8 h',
      );
    });

    testWidgets('nach der Rückkehr ist die nächste Buchung wieder ein '
        'Update', (tester) async {
      final b = aufbau();
      await starte(tester, b.container, b.router);
      await _sendeLebenszyklus(tester, AppLifecycleState.paused);
      await _sendeLebenszyklus(tester, AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      await buche(tester, b, eintrag(Mahlzeit.abend));

      expect(b.anzeige.zeigeAufrufe, hasLength(3));
      expect(b.anzeige.zeigeAufrufe.last.frisch, isFalse);
    });

    testWidgets('bei der Rückkehr wird nach dem Link gefragt', (tester) async {
      final b = aufbau();
      await starte(tester, b.container, b.router);
      final vorher = b.anzeige.nimmLinkAufrufe;

      b.anzeige.link = LiveZiel.mahlzeitEintragen;
      await _sendeLebenszyklus(tester, AppLifecycleState.paused);
      await _sendeLebenszyklus(tester, AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(b.anzeige.nimmLinkAufrufe, greaterThan(vorher));
      expect(kameras(tester), 1);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  group('Link „mahlzeit-eintragen"', () {
    testWidgets('öffnet die Kamera auf dem Stapel des gewählten Tabs, mit '
        'dem Esstag, ohne Tabwechsel', (tester) async {
      final b = aufbau(jetzt: nachts);
      await starte(tester, b.container, b.router);
      b.router.open(AppTarget.ernaehrung());
      await tester.pumpAndSettle();
      expect(kameras(tester), 0);

      b.anzeige.link = LiveZiel.mahlzeitEintragen;
      b.anzeige.meldeLink();
      await tester.pumpAndSettle();

      expect(
        b.router.tab,
        Tab.ernaehrung,
        reason:
            'ein Detailziel wechselt '
            'nie den Tab (CLAUDE.md)',
      );
      expect(
        find.byType(KameraSeite),
        findsOneWidget,
        reason: 'sichtbar, also oben auf dem Stapel des gewählten Tabs',
      );
      final kamera = tester.widget<KameraSeite>(find.byType(KameraSeite));
      expect(
        kamera.tagesSchluessel,
        heute,
        reason:
            'um 02:00 ist der Esstag noch der Vortag (V3), nicht der '
            'Kalendertag',
      );
      expect(
        kamera.mahlzeit,
        isNull,
        reason:
            'die Mahlzeit kommt aus der '
            'Uhrzeit, wie im Buchungsblatt',
      );
      expect(kamera.router, same(b.router));
    });

    testWidgets('Kaltstart: ein Link, der vor der App da ist, wird nach dem '
        'ersten Bild geöffnet', (tester) async {
      final b = aufbau();
      b.anzeige.link = LiveZiel.mahlzeitEintragen;

      await starte(tester, b.container, b.router);

      expect(kameras(tester), 1);
      expect(b.router.tab, Tab.heute);
      expect(b.anzeige.link, isNull, reason: 'abgeholt');
    });

    testWidgets('zwei linkDa nacheinander → eine Kamera', (tester) async {
      final b = aufbau();
      await starte(tester, b.container, b.router);

      b.anzeige.link = LiveZiel.mahlzeitEintragen;
      b.anzeige.meldeLink();
      b.anzeige.meldeLink();
      await tester.pumpAndSettle();
      expect(kameras(tester), 1);

      // Ein zweiter Link, während die Kamera schon offen ist.
      b.anzeige.link = LiveZiel.mahlzeitEintragen;
      b.anzeige.meldeLink();
      await tester.pumpAndSettle();
      expect(
        kameras(tester),
        1,
        reason:
            '`oeffneKamera` lässt keine zweite '
            'zu (#326)',
      );
    });

    testWidgets('linkDa ohne Link öffnet nichts', (tester) async {
      final b = aufbau();
      await starte(tester, b.container, b.router);

      b.anzeige.meldeLink();
      await tester.pumpAndSettle();

      expect(kameras(tester), 0);
      expect(tester.takeException(), isNull);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  group('Ergebnisse, die nicht aufgehen', () {
    for (final (name, ergebnis) in [
      ('LiveFehlgeschlagen', const LiveFehlgeschlagen('Prüfmeldung 4711')),
      ('LiveAbgeschaltet', const LiveAbgeschaltet()),
      ('LiveNichtVerfuegbar', const LiveNichtVerfuegbar()),
    ]) {
      testWidgets('$name → nichts auf dem Schirm, keine Ausnahme', (
        tester,
      ) async {
        final b = aufbau();
        b.anzeige.ergebnis = ergebnis;

        await starte(tester, b.container, b.router);
        await buche(tester, b, eintrag(Mahlzeit.fruehstueck));

        expect(tester.takeException(), isNull);
        expect(find.byType(CupertinoAlertDialog), findsNothing);
        expect(find.textContaining('Prüfmeldung 4711'), findsNothing);
        expect(
          b.anzeige.zeigeAufrufe,
          hasLength(2),
          reason: 'eine Karte, die nicht aufgeht, hält Buchen nicht auf',
        );
      });
    }
  });

  // ─────────────────────────────────────────────────────────────────────
  group('RepitApp', () {
    testWidgets('mit router: LiveWacht umschließt die App, RootView hat '
        'denselben Router', (tester) async {
      final b = aufbau();
      tester.view.physicalSize = const Size(900, 4800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        RepitApp(behaelter: b.container, router: b.router),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LiveWacht), findsOneWidget);
      expect(
        tester.widget<RootView>(find.byType(RootView)).router,
        same(b.router),
      );
      expect(b.anzeige.zeigeAufrufe, hasLength(1));
      expect(b.anzeige.zeigeAufrufe.single.frisch, isTrue);

      // Der Behälter steckt hier in der echten App, nicht in
      // `BehaelterImBaum`. Er wird im Testkörper abgeräumt, sonst steht der
      // Zeitgeber des laufenden Tages (#455) noch aus, wenn `testWidgets`
      // nach offenen Timern fragt.
      await tester.pumpWidget(const SizedBox.shrink());
      b.container.dispose();
    });

    testWidgets('ohne router: keine LiveWacht', (tester) async {
      await tester.pumpWidget(const RepitApp());

      expect(find.byType(LiveWacht), findsNothing);
    });
  });
}

/// Schickt einen Lebenszyklus-Zustand so, wie die Plattform ihn schickt —
/// über `SystemChannels.lifecycle` (wie `tageswacht_test.dart`).
Future<void> _sendeLebenszyklus(
  WidgetTester tester,
  AppLifecycleState zustand,
) {
  return tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    SystemChannels.lifecycle.name,
    const StringCodec().encodeMessage(zustand.toString()),
    (_) {},
  );
}

/// Hält Abfragen zurück, bis der Test sie freigibt.
class _Mitschnitt extends QueryInterceptor {
  bool Function(String sql)? _halte;
  Completer<void> _frei = Completer<void>()..complete();

  void halte(bool Function(String sql) bedingung) {
    _halte = bedingung;
    _frei = Completer<void>();
  }

  void gibFrei() {
    _halte = null;
    if (!_frei.isCompleted) _frei.complete();
  }

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async {
    final bedingung = _halte;
    if (bedingung != null && bedingung(statement)) {
      await _frei.future;
    }
    return executor.runSelect(statement, args);
  }
}

class _StilleQuelle extends HealthReadingAttrappe {}
