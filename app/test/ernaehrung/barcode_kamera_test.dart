import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/data/ernaehrung_repository.dart';
import 'package:repit/data/lebensmittel_repository.dart';
import 'package:repit/design/symbole.dart';
import 'package:repit/ernaehrung/anlegen_blatt.dart';
import 'package:repit/ernaehrung/buchungs_blatt.dart';
import 'package:repit/ernaehrung/ernaehrung_view.dart';
import 'package:repit/ernaehrung/off_client.dart';
import 'package:repit/ernaehrung/strichcode_leser.dart';
import 'package:repit/ernaehrung/suche_view.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/shell/heute_view.dart';
import 'package:repit/shell/root_view.dart';
import 'package:repit/shell/router.dart';

import '../design/support.dart' show textOf;
import 'kamera_attrappe.dart';
import '../health/health_reading_attrappe.dart';
import '../tag/behaelter_im_baum.dart';

/// Tests für **Barcode scannen** (#324) — `docs/screens/screens/erfassen.js`,
/// Zustände `barcode` und `unbekannt`, dazu der Kopfkommentar zum (+).
///
/// Geprüft an der **ganzen** App (`RootView`) auf einer Datenbank im
/// Speicher, wie `eintragweg_verdrahtung_test.dart`: Eine Tür, die im
/// Einzeltest aufgeht und in der App an einem fehlenden `router` hängt, ist
/// genau der Fehler, um den es bei einem Eintragweg geht. Open Food Facts
/// kommt über einen eingesetzten `http.Client` (`offClientProvider`), wie in
/// `off_suche_view_test.dart` — kein Netz im Test.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Für Widget-Tests genügt ein Agent, solange der Test zuerst entsteht,
/// einmal rot gesehen und committet wird, bevor die Implementierung
/// anfängt. Danach darf diese Datei ausgeführt, aber nicht verändert
/// werden.
///
/// ## Die Naht zur Kamera — Entscheidung des Test-Agenten
///
/// **Nicht mit Tim abgestimmt, nicht freigegeben** — mit Begründung.
///
/// Neu in **`lib/ernaehrung/strichcode_leser.dart`**:
///
/// ```dart
/// abstract interface class StrichcodeLeser {
///   /// Die Kameravorschau. Meldet jeden erkannten Code über [aufCode] und
///   /// eine verweigerte Kamerafreigabe über [aufVerweigert].
///   Widget sucher({
///     required ValueChanged<String> aufCode,
///     required VoidCallback aufVerweigert,
///   });
///
///   /// Öffnet die Einstellungen dieser App (Kamerafreigabe).
///   Future<void> oeffneEinstellungen();
/// }
///
/// final strichcodeLeserProvider = Provider<StrichcodeLeser>(…);
/// ```
///
/// Die echte Fassung baut in `sucher` ein `MobileScanner` und reicht
/// `onDetect` an `aufCode` weiter, den Fehler „Freigabe verweigert" an
/// `aufVerweigert`; der Test ersetzt den Provider mit `TestLeser`
/// (`kamera_attrappe.dart`) und
/// **importiert `mobile_scanner` nicht**.
///
/// Warum so und nicht anders:
///
/// - **Ein Widget-Bauer statt eines `Stream<String>`.** Die Kamera hat einen
///   Lebenszyklus: Sie läuft, solange ihre Vorschau im Baum steht, und hört
///   auf, wenn sie verschwindet. Ein Stream im Provider lebte unabhängig vom
///   Schirm, und wer ihn abhört, müsste Start und Stopp selbst
///   nachbauen. Mit dem Bauer gehört die Kamera dem Schirm, der sie zeigt —
///   dieselbe Form, die `MobileScanner(onDetect: …)` selbst hat.
/// - **`aufCode` meldet roh, jedes Bild.** Die Naht entprellt nicht. So
///   verhält sich die echte Kamera — sie sieht dieselbe Packung dreißigmal
///   in der Sekunde —, und „ein Code wird einmal ausgewertet" ist damit
///   Pflicht des **Schirms**, prüfbar hier, statt in der Naht versteckt und
///   im Test weggemockt.
/// - **Die Verweigerung kommt über dieselbe Naht.** `mobile_scanner` fragt
///   die Freigabe beim Start der Vorschau und meldet die Absage als Fehler
///   der Vorschau. Eine eigene Berechtigungsabfrage daneben wäre ein zweiter
///   Weg zur selben Auskunft.
/// - **Der Weg in die Einstellungen gehört mit in die Naht**, weil er
///   ebenfalls Plattform ist. Der Test zählt nur, dass er gerufen wurde.
///
/// `TestLeser` liefert Codes **nur an eine Vorschau, die im Baum steht** —
/// genau wie die echte Kamera: Ohne Vorschau keine Erkennung. Eine
/// Implementierung, die die Kamera abbaut, solange ein Blatt offen ist, ist
/// damit ebenso richtig wie eine, die sie stehen lässt und selbst entprellt.
///
/// ## Die Schlüssel
///
/// - `Key('kamera')` — der Kameraschirm, solange er da ist
/// - `Key('kamera-abbrechen')` — im Kopf, zurück, woher man kam (seit #439
///   rechts, bis dahin links)
/// - `Key('kamera-suchen')` — die Kachel „Suchen" unten, in die Suche (seit
///   #439; bis dahin oben rechts)
/// - `Key('kamera-modus-ki')` — „KI-Foto" in der Kachelreihe (seit #340
///   aktiv, s. u.; bis #439 „KI" im Umschalter)
/// - `Key('kamera-unbekannt')` — Zustand `unbekannt`
/// - `Key('kamera-unbekannt-anlegen')` — „Produkt anlegen"
/// - `Key('kamera-unbekannt-suchen')` — „Stattdessen suchen"
/// - `Key('kamera-kein-netz')` — Open Food Facts nicht erreichbar
/// - `Key('kamera-nochmal')` — „Nochmal versuchen" nach „kein Netz"
/// - `Key('kamera-verweigert')` — der Satz bei verweigerter Kamera
/// - `Key('kamera-einstellungen')` — der Weg in die Einstellungen
///
/// Die bestehenden (`erfassen-knopf`, `anlegen-name`, `anlegen-kcal`,
/// `anlegen-sichern`, `buchung-sichern`, `ernaehrung-zurueck`) gelten
/// weiter, ebenso `BuchungsBlatt.formular`.
///
/// ## Entscheidungen des Test-Agenten
///
/// **Nicht mit Tim abgestimmt, nicht freigegeben.**
///
/// - **„Gefunden ist nicht übernommen."** Ein OFF-Treffer öffnet das
///   Buchungsblatt mit `OffProdukt.alsVorlage()` — ohne Schlüssel —, und
///   erst das Buchen legt ihn in die eigene Tabelle. Dieselbe Regel wie in
///   der Suche (`off_suche_view_test.dart`); wer nur scannt und abbricht,
///   hat nichts angelegt.
/// - **Ein selbst angelegtes Produkt trägt Herkunft `eigen`**, auch wenn
///   sein Strichcode aus dem Scanner kam: Die Werte hat Tim von der Packung
///   abgeschrieben, nicht aus Open Food Facts übernommen.
/// - **Bei verweigerter Kamera bleibt „Suchen" erreichbar.** Ohne Kamera
///   ist die Suche der einzige Weg, und ein Schirm, der nur „geh in die
///   Einstellungen" sagt, ist eine Sackgasse.
/// - **Gebucht wird über das bestehende Buchungsblatt** (`BuchungsBlatt`),
///   nicht über ein zweites.
///
/// ## Entscheidungen des Koordinators (04.11.2026)
///
/// **Vom Koordinator entschieden, nicht von Tim. Tim hat sie nicht
/// gesehen und nicht freigegeben.** Der Test-Agent hatte sie als offene
/// Punkte gemeldet; sie stehen hier, damit niemand sie für Tims Wort hält.
///
/// 1. **Nach dem Buchen** geht es zurück, woher man kam — wie beim übrigen
///    Eintragweg —, und die Kamera ist zu. **Nach dem Anlegen aus
///    „unbekannt"** geht es **direkt ins Buchungsblatt** mit dem neuen
///    Lebensmittel: Wer eine Packung scannt, will sie essen, nicht nur
///    ablegen.
/// 2. **Ein Code wird je Kamera-Sitzung einmal ausgewertet.** Nach „kein
///    Netz" fragt „Nochmal versuchen" (`Key('kamera-nochmal')`) **denselben**
///    Code erneut. Nach „Abbrechen" ist die Sitzung zu Ende; eine neue
///    Sitzung wertet neu aus.
/// 3. **Ein OFF-Treffer ohne Kalorien** — auch nach der kJ-Umrechnung
///    nicht — ist nicht buchbar und geht den Weg von „unbekannt", aber das
///    Anlegen-Blatt kommt **mit Name und Strichcode vorbelegt**. Eine
///    gelieferte, aber unbrauchbare Angabe ist kein „kein Netz".
/// 4. **„Stattdessen suchen" ist eine echte Tür.** Die Kachel „Barcode" auf
///    dem Tag-Schirm und der Bogeneintrag „Barcode" sind freigeschaltet und
///    öffnen die Kamera (geprüft in `eintragweg_verdrahtung_test.dart` und
///    `shell/root_view_test.dart`; hier nur der offene Tag über die Kachel).
///
/// Daraus vom Test-Agenten abgeleitet, ebenfalls ohne Tim: **„Abbrechen" im
/// Buchungsblatt** schließt nur das Blatt — die Kamera steht wieder da, die
/// Sitzung läuft weiter, und derselbe Code wird darin nicht neu ausgewertet.
/// „Abbrechen" ist dort der Name des Knopfs (`ErfassenKopf` trägt keinen
/// Schlüssel dafür), keine geprüfte Beschriftung.
///
/// ## Was hier **nicht** festgelegt ist
///
/// - Ob „Suchen" die Kamera ersetzt oder sich über sie legt. Festgelegt ist
///   nur Punkt 1: Nach dem Buchen ist die Kamera zu.
/// - Layout, Wortlaut, die Taschenlampe.
///
/// ## Nachtrag #340 — „KI" schaltet um
///
/// **Vom Test-Agenten von #340 umgestellt; Tim hat die Umstellung nicht
/// gesehen.** Bis #340 war „KI" abgeblendet, und ein Fall hier prüfte, dass
/// ein Tipp darauf nichts tut. Seit dem KI-Sucher (Plan
/// `docs/superpowers/plans/2026-11-04-ki-zugang.md`, Task 9) schaltet „KI"
/// tatsächlich um. Das Umschalten selbst — Barcode → KI → Barcode, welche
/// Kamera dann läuft und dass der Leser danach wieder auswertet — prüft
/// `ki_sucher_test.dart` (Gruppe „Ein Sucher, zwei Modi"). Hier bleibt nur
/// die Barcode-Aussage: **Die Kamera öffnet im Barcode-Modus**, der Umschalter
/// steht da, und gescannt wird, ohne dass man erst umschaltet. „KI" wird in
/// dieser Datei nicht angetippt — die Hülle setzt keine Fotokamera ein.
///
/// Alle Produkte, Namen und Strichcodes hier sind **erfunden**.
void main() {
  // Dienstag, 14.07.2026, 12:00 Berliner Zeit (MESZ, +2).
  final jetzt = DateTime.utc(2026, 7, 14, 10);
  const heute = '2026-07-14';
  const gestern = '2026-07-13';

  // Erfunden, und so, dass niemand sie für echte hält.
  const codeEigen = '0000000004242';
  const codeOff = '0000000004259';
  const codeUnbekannt = '0000000004266';

  const eigenJe100g = Naehrwerte.je100g(kcal: 360, eiweissG: 11, fettG: 6);

  // ───────────────────────────────────────────────────────────────────────
  // Open Food Facts
  // ───────────────────────────────────────────────────────────────────────

  /// Die Antwort von `/api/v2/product/<code>.json` auf einen bekannten
  /// Strichcode.
  http.Response produktAntwort(
    String code, {
    String name = 'Prüfriegel Kakao',
    Map<String, Object?> naehrwerte = const {
      'energy-kcal_100g': 412,
      'proteins_100g': 21.5,
      'carbohydrates_100g': 48,
      'fat_100g': 13.2,
    },
  }) => http.Response.bytes(
    utf8.encode(
      jsonEncode({
        'code': code,
        'status': 1,
        'product': {
          'code': code,
          'product_name': name,
          'brands': '',
          'nutriments': naehrwerte,
        },
      }),
    ),
    200,
    headers: const {'content-type': 'application/json; charset=utf-8'},
  );

  const offJe100g = Naehrwerte.je100g(
    kcal: 412,
    eiweissG: 21.5,
    kohlenhydrateG: 48,
    fettG: 13.2,
  );

  /// So meldet OFF einen gültigen, aber unbekannten Strichcode (Kopf von
  /// `off_client.dart`, gemessen am 04.11.2026).
  http.Response unbekanntAntwort(String code) => http.Response(
    jsonEncode({'code': code, 'status': 0, 'status_verbose': 'not found'}),
    404,
  );

  // ───────────────────────────────────────────────────────────────────────
  // Testhülle
  // ───────────────────────────────────────────────────────────────────────

  ({
    ProviderContainer container,
    AppCache db,
    AppRouter router,
    _Netz netz,
    TestLeser leser,
  })
  behaelter() {
    final db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);
    final netz = _Netz();
    final leser = TestLeser();

    // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        appCacheProvider.overrideWithValue(db),
        healthProvider.overrideWithValue(_StilleQuelle()),
        clockProvider.overrideWithValue(() => jetzt),
        offClientProvider.overrideWithValue(OffClient(client: netz.client)),
        strichcodeLeserProvider.overrideWithValue(leser),
      ],
    );
    addTearDown(container.dispose);
    return (
      container: container,
      db: db,
      router: AppRouter(),
      netz: netz,
      leser: leser,
    );
  }

  Future<void> starte(
    WidgetTester tester,
    ({
      ProviderContainer container,
      AppCache db,
      AppRouter router,
      _Netz netz,
      TestLeser leser,
    })
    h,
  ) async {
    tester.view.physicalSize = const Size(900, 4800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      BehaelterImBaum(
        container: h.container,
        child: CupertinoApp(home: RootView(router: h.router)),
      ),
    );
    await tester.pumpAndSettle();
  }

  // ───────────────────────────────────────────────────────────────────────
  // Helfer
  // ───────────────────────────────────────────────────────────────────────

  Future<void> tippe(WidgetTester tester, Finder ziel) async {
    await tester.tap(ziel);
    await tester.pumpAndSettle();
  }

  Future<void> zumErnaehrungsTab(WidgetTester tester) => tippe(
    tester,
    find.descendant(
      of: find.byType(CupertinoTabBar),
      matching: find.byIcon(Symbole.aufloesen('fork.knife')),
    ),
  );

  /// Tippt den (+) an und erwartet die Kamera mit laufender Vorschau.
  Future<void> zurKamera(
    WidgetTester tester,
    TestLeser leser,
  ) async {
    await tippe(tester, find.byKey(const Key('erfassen-knopf')));
    expect(
      find.byKey(const Key('kamera')),
      findsOneWidget,
      reason: 'der (+) öffnet die Kamera (`erfassen.js`, Kopfkommentar)',
    );
    expect(
      leser.laeuft,
      isTrue,
      reason: 'die Vorschau aus `StrichcodeLeser.sucher` steht im Baum',
    );
  }

  /// Lässt die Kamera [code] erkennen und wartet, bis alles steht.
  Future<void> scanne(
    WidgetTester tester,
    TestLeser leser,
    String code,
  ) async {
    leser.erkenne(code);
    await tester.pumpAndSettle();
  }

  BuchungsBlatt blatt(WidgetTester tester) =>
      tester.widget<BuchungsBlatt>(find.byType(BuchungsBlatt));

  Future<void> buche(WidgetTester tester) async {
    await tippe(tester, find.byKey(const Key('buchung-sichern')));
    expect(
      find.byType(BuchungsBlatt),
      findsNothing,
      reason: 'nach dem Buchen schließt das Blatt',
    );
  }

  Future<List<Eintrag>> eintraegeAm(AppCache db, String tag) =>
      ErnaehrungRepository(db).eintraegeAmTag(tag);

  bool sichtbar(Finder f) => f.hitTestable().evaluate().isNotEmpty;

  /// Nur die Anfragen nach dem Produkt zu einem Strichcode.
  List<http.Request> produktAnfragen(_Netz netz) => netz.anfragen
      .where((a) => a.url.path.startsWith('/api/v2/product/'))
      .toList();

  // ═════════════════════════════════════════════════════════════════════
  group('Der (+) öffnet die Kamera', () {
    testWidgets('statt der Suche — auf dem Stapel des Tabs, in dem man ist', (
      tester,
    ) async {
      final h = behaelter();
      await starte(tester, h);
      expect(h.router.tab, Tab.heute);

      await zurKamera(tester, h.leser);

      expect(
        find.byType(SucheView),
        findsNothing,
        reason: 'der Übergang „(+) öffnet die Suche" ist mit #324 vorbei',
      );
      expect(find.byType(CupertinoAlertDialog), findsNothing);
      expect(
        h.router.tab,
        Tab.heute,
        reason:
            'ein Detailschirm wechselt nie den Tab (CLAUDE.md) — sonst führte '
            '„zurück" in ein Menü, das Tim nie geöffnet hat',
      );
    });

    testWidgets('„Abbrechen" führt zurück in den Tab, aus dem man kam', (
      tester,
    ) async {
      final h = behaelter();
      await starte(tester, h);
      await zurKamera(tester, h.leser);

      await tippe(tester, find.byKey(const Key('kamera-abbrechen')));

      expect(find.byKey(const Key('kamera')), findsNothing);
      expect(h.leser.laeuft, isFalse, reason: 'ohne Schirm keine Kamera');
      expect(h.router.tab, Tab.heute);
      expect(sichtbar(find.byType(HeuteView)), isTrue);
    });

    testWidgets('die Kachel „Suchen" führt in die Suche', (tester) async {
      final h = behaelter();
      await starte(tester, h);
      await zurKamera(tester, h.leser);

      await tippe(tester, find.byKey(const Key('kamera-suchen')));

      expect(find.byType(SucheView), findsOneWidget);
      expect(sichtbar(find.byType(SucheView)), isTrue);
      expect(h.router.tab, Tab.heute);
    });

    testWidgets(
      'die Kamera öffnet im Barcode-Modus — gescannt wird ohne Umschalten',
      (tester) async {
        final h = behaelter();
        await LebensmittelRepository(h.db).legeAn(
          const LebensmittelVorlage(
            name: 'Prüfmüsli',
            je100g: eigenJe100g,
            barcode: codeEigen,
          ),
        );
        await starte(tester, h);
        await zurKamera(tester, h.leser);

        // Die Kachelreihe steht da, aber noch ist Barcode gewählt: kein
        // KI-Sucher, der Leser läuft. Das Umschalten selbst prüft
        // `ki_sucher_test.dart`.
        expect(find.byKey(const Key('kamera-modus-ki')), findsOneWidget);
        expect(find.byKey(const Key('ki-sucher')), findsNothing);
        expect(h.leser.laeuft, isTrue);

        await scanne(tester, h.leser, codeEigen);
        expect(find.byType(BuchungsBlatt), findsOneWidget);
      },
    );
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Erst die eigene Tabelle, dann Open Food Facts', () {
    // Umgestellt mit #325 (Test-Agent, 05.11.2026): Bis dahin verlangte
    // dieser Fall für jede Herkunft null Anfragen. Seit Tims Entscheidung 6
    // (`docs/superpowers/specs/2026-11-05-portionen-design.md`) fragt ein
    // übernommenes Produkt, das nie nach Portionen gefragt wurde, beim
    // Öffnen des Blatts **einmal** nach — das prüft die Gruppe
    // „Ein übernommenes Produkt fragt einmal nach seinen Portionen" unten.
    // Die Aussage hier bleibt: **Fürs Nachschlagen** wird Open Food Facts
    // nicht gefragt, gefunden wird über die eigene Tabelle. Damit keine
    // Portionsnachfrage sie verdeckt, trägt das Produkt aus OFF hier die
    // Marke `portionen_abgefragt_am`.
    for (final herkunft in Herkunft.values) {
      testWidgets(
        'ein Code aus der eigenen Tabelle (Herkunft ${herkunft.name}'
        '${herkunft == Herkunft.off ? ', Portionen schon abgefragt' : ''}) '
        'öffnet das Buchungsblatt — ohne Netzanfrage',
        (tester) async {
          final h = behaelter();
          // Jede Anfrage wäre hier ein Fehler; die Antwort ist egal, gezählt
          // wird, dass keine kam.
          h.netz.antwort = (_) => http.Response('', 500);
          final repo = LebensmittelRepository(h.db);
          const vorlage = LebensmittelVorlage(
            name: 'Prüfmüsli',
            je100g: eigenJe100g,
            barcode: codeEigen,
          );
          final id = herkunft == Herkunft.off
              ? await repo.uebernimm(
                  LebensmittelVorlage(
                    name: 'Prüfmüsli',
                    je100g: eigenJe100g,
                    barcode: codeEigen,
                    herkunft: Herkunft.off,
                    portionenAbgefragtAm: jetzt.subtract(
                      const Duration(days: 3),
                    ),
                  ),
                )
              : await repo.legeAn(vorlage);
          await starte(tester, h);
          await zurKamera(tester, h.leser);

          await scanne(tester, h.leser, codeEigen);

          expect(find.byType(BuchungsBlatt), findsOneWidget);
          final formular = blatt(tester).formular;
          expect(
            formular.lebensmittelId,
            id,
            reason: 'gebucht wird aus der vorhandenen Zeile, keine neue',
          );
          expect(formular.name, 'Prüfmüsli');
          expect(formular.je100g, eigenJe100g);
          expect(
            h.netz.anfragen,
            isEmpty,
            reason:
                'ein schon bekanntes Produkt ist offline und sofort da — '
                'Open Food Facts wird nicht gefragt (#324)',
          );
        },
      );
    }

    testWidgets(
      'ein Code, den nur Open Food Facts kennt, öffnet das Buchungsblatt mit '
      'dessen Werten — und liegt nach dem Buchen in der eigenen Tabelle',
      (tester) async {
        final h = behaelter();
        h.netz.antwort = (_) => produktAntwort(codeOff);
        final repo = LebensmittelRepository(h.db);
        await starte(tester, h);
        await zurKamera(tester, h.leser);

        await scanne(tester, h.leser, codeOff);

        final anfragen = produktAnfragen(h.netz);
        expect(anfragen, hasLength(1));
        expect(
          anfragen.single.url.path,
          contains(codeOff),
          reason: 'gefragt wird nach genau dem gescannten Strichcode',
        );

        expect(find.byType(BuchungsBlatt), findsOneWidget);
        final formular = blatt(tester).formular;
        expect(formular.name, 'Prüfriegel Kakao');
        expect(formular.je100g, offJe100g);
        expect(
          formular.lebensmittelId,
          isNull,
          reason: 'gefunden ist nicht übernommen — erst das Buchen legt an',
        );
        expect(
          await repo.zuBarcode(codeOff),
          isNull,
          reason: 'wer nur scannt und abbricht, hat nichts angelegt',
        );

        await buche(tester);

        expect(
          find.byKey(const Key('kamera')),
          findsNothing,
          reason:
              'nach dem Buchen ist die Kamera zu (Entscheidung 1 des '
              'Koordinators)',
        );
        expect(h.leser.laeuft, isFalse);
        expect(
          sichtbar(find.byType(HeuteView)),
          isTrue,
          reason: 'zurück, woher man kam — wie beim übrigen Eintragweg',
        );
        expect(h.router.tab, Tab.heute);

        final uebernommen = await repo.zuBarcode(codeOff);
        expect(
          uebernommen,
          isNotNull,
          reason: 'beim Buchen wandert das Produkt in die eigene Tabelle',
        );
        expect(uebernommen!.herkunft, Herkunft.off);
        expect(uebernommen.je100g, offJe100g);

        final gebucht = await eintraegeAm(h.db, heute);
        expect(gebucht, hasLength(1));
        expect(
          gebucht.single.lebensmittelId,
          uebernommen.id,
          reason: 'der Eintrag zeigt auf die übernommene Zeile',
        );
      },
    );
  });

  // ═════════════════════════════════════════════════════════════════════
  // Tims Entscheidung 6 vom 05.11.2026 (Spec „Portionen", Abschnitt
  // „Abruf beim Antippen"): Ein Produkt, das vor #325 übernommen wurde
  // (`portionen_abgefragt_am` ist `null`), fragt beim nächsten Öffnen des
  // Buchungsblatts einmal nach seinen Portionen. Danach nie wieder. Das gilt
  // auch, wenn das Blatt aus der Kamera kommt.
  group('Ein übernommenes Produkt fragt einmal nach seinen Portionen', () {
    testWidgets(
      'ohne Marke `portionen_abgefragt_am` → genau eine Anfrage nach dem '
      'Strichcode, und das Blatt steht schon, bevor sie beantwortet ist',
      (tester) async {
        final h = behaelter();
        // Keine sofortige Antwort: Die Anfrage hängt, bis der Test sie löst.
        final repo = LebensmittelRepository(h.db);
        final id = await repo.uebernimm(
          const LebensmittelVorlage(
            name: 'Prüfmüsli',
            je100g: eigenJe100g,
            barcode: codeEigen,
            herkunft: Herkunft.off,
          ),
        );
        expect(
          (await repo.lies(id))!.portionenAbgefragtAm,
          isNull,
          reason: 'Voraussetzung: übernommen, aber nie nach Portionen gefragt',
        );
        await starte(tester, h);
        await zurKamera(tester, h.leser);

        await scanne(tester, h.leser, codeEigen);

        expect(
          find.byType(BuchungsBlatt),
          findsOneWidget,
          reason:
              'das Blatt öffnet sofort aus der eigenen Tabelle — es wartet '
              'nicht auf Open Food Facts',
        );
        expect(blatt(tester).formular.lebensmittelId, id);
        final anfragen = produktAnfragen(h.netz);
        expect(
          anfragen,
          hasLength(1),
          reason:
              'Entscheidung 6: ein vor #325 übernommenes Produkt fragt beim '
              'Öffnen einmal nach seinen Portionen',
        );
        expect(
          h.netz.anfragen,
          hasLength(1),
          reason: 'sonst nichts — keine Suche, kein zweiter Weg',
        );
        expect(
          anfragen.single.url.path,
          contains(codeEigen),
          reason: 'gefragt wird nach genau diesem Strichcode',
        );

        h.netz.beantworte(0, produktAntwort(codeEigen, name: 'Prüfmüsli'));
        await tester.pumpAndSettle();

        expect(find.byType(BuchungsBlatt), findsOneWidget);
        expect(
          (await repo.lies(id))!.portionenAbgefragtAm,
          isNotNull,
          reason: 'nach einer Antwort gilt das Produkt als gefragt (V4)',
        );

        // Blatt zu, Kamera zu, Kamera auf: eine neue Sitzung, dasselbe
        // Produkt. Jetzt trägt es die Marke und fragt nicht mehr.
        await tippe(
          tester,
          find.descendant(
            of: find.byType(BuchungsBlatt),
            matching: find.text('Abbrechen'),
          ),
        );
        await tippe(tester, find.byKey(const Key('kamera-abbrechen')));
        await zurKamera(tester, h.leser);
        await scanne(tester, h.leser, codeEigen);

        expect(find.byType(BuchungsBlatt), findsOneWidget);
        expect(
          h.netz.anfragen,
          hasLength(1),
          reason: 'einmal, nicht bei jedem Öffnen (Entscheidung 6)',
        );
      },
    );
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Nicht hinterlegt — Zustand „unbekannt"', () {
    final varianten = <String, http.Response Function(http.Request)>{
      'HTTP 404': (_) => unbekanntAntwort(codeUnbekannt),
      'HTTP 200 mit status 0': (_) => http.Response(
        jsonEncode({'code': codeUnbekannt, 'status': 0}),
        200,
      ),
    };

    for (final MapEntry(key: name, value: antwort) in varianten.entries) {
      testWidgets('$name → „unbekannt", nicht „kein Netz"', (tester) async {
        final h = behaelter();
        h.netz.antwort = antwort;
        await starte(tester, h);
        await zurKamera(tester, h.leser);

        await scanne(tester, h.leser, codeUnbekannt);

        expect(find.byKey(const Key('kamera-unbekannt')), findsOneWidget);
        expect(
          find.byKey(const Key('kamera-kein-netz')),
          findsNothing,
          reason: '„kein Netz" und „nicht hinterlegt" werden nie vermischt',
        );
        expect(find.byType(BuchungsBlatt), findsNothing);
        expect(
          find.byType(CupertinoAlertDialog),
          findsNothing,
          reason: 'ein unbekannter Strichcode ist kein Fehler (`erfassen.js`)',
        );
      });
    }

    testWidgets(
      '„Produkt anlegen" öffnet das Anlegen-Blatt mit vorbelegtem Strichcode '
      '— das angelegte Lebensmittel trägt ihn',
      (tester) async {
        final h = behaelter();
        h.netz.antwort = (_) => unbekanntAntwort(codeUnbekannt);
        final repo = LebensmittelRepository(h.db);
        await starte(tester, h);
        await zurKamera(tester, h.leser);
        await scanne(tester, h.leser, codeUnbekannt);

        await tippe(tester, find.byKey(const Key('kamera-unbekannt-anlegen')));
        expect(find.byType(AnlegenBlatt), findsOneWidget);

        // Tim tippt nur ab, was auf der Packung steht — den Strichcode
        // nicht.
        await tester.enterText(
          find.byKey(const Key('anlegen-name')),
          'Prüfkeks',
        );
        await tester.enterText(find.byKey(const Key('anlegen-kcal')), '455');
        await tester.pump();
        expect(
          await repo.zuBarcode(codeUnbekannt),
          isNull,
          reason: 'vor dem Sichern ist nichts angelegt',
        );

        await tippe(tester, find.byKey(const Key('anlegen-sichern')));

        final angelegt = await repo.zuBarcode(codeUnbekannt);
        expect(
          angelegt,
          isNotNull,
          reason:
              'der Strichcode war vorbelegt — sonst erkennte der nächste Scan '
              'dieselbe Packung nicht wieder',
        );
        expect(angelegt!.name, 'Prüfkeks');
        expect(angelegt.je100g.kcal, 455);
        expect(
          angelegt.herkunft,
          Herkunft.eigen,
          reason: 'die Werte hat Tim von der Packung, nicht aus OFF',
        );

        // Entscheidung 1 des Koordinators: direkt ins Buchungsblatt.
        expect(find.byType(AnlegenBlatt), findsNothing);
        expect(
          find.byType(BuchungsBlatt),
          findsOneWidget,
          reason:
              'wer eine Packung scannt, will sie essen, nicht nur ablegen — '
              'nach dem Anlegen kommt das Buchungsblatt',
        );
        expect(blatt(tester).formular.lebensmittelId, angelegt.id);
        expect(blatt(tester).formular.tagesSchluessel, heute);

        await buche(tester);

        final gebucht = await eintraegeAm(h.db, heute);
        expect(gebucht, hasLength(1));
        expect(gebucht.single.lebensmittelId, angelegt.id);
        expect(find.byKey(const Key('kamera')), findsNothing);
        expect(sichtbar(find.byType(HeuteView)), isTrue);
      },
    );

    testWidgets(
      'ein OFF-Treffer ohne Kalorien geht den Weg von „unbekannt" — das '
      'Anlegen-Blatt kommt mit Name und Strichcode vorbelegt',
      (tester) async {
        final h = behaelter();
        // Weder `energy-kcal_100g` noch `energy-kj_100g`: auch umgerechnet
        // keine Kalorien.
        h.netz.antwort = (_) => produktAntwort(
          codeOff,
          name: 'Prüfwaffel Sesam',
          naehrwerte: const {'proteins_100g': 9.5, 'fat_100g': 3.1},
        );
        final repo = LebensmittelRepository(h.db);
        await starte(tester, h);
        await zurKamera(tester, h.leser);

        await scanne(tester, h.leser, codeOff);

        expect(
          find.byKey(const Key('kamera-unbekannt')),
          findsOneWidget,
          reason: 'nicht buchbar heißt: derselbe Weg wie „nicht hinterlegt"',
        );
        expect(
          find.byKey(const Key('kamera-kein-netz')),
          findsNothing,
          reason: 'eine gelieferte, aber unbrauchbare Angabe ist kein „kein Netz"',
        );
        expect(
          find.byType(BuchungsBlatt),
          findsNothing,
          reason: 'ohne Kalorien kein Eintrag (`OffProdukt.buchbar`)',
        );

        await tippe(tester, find.byKey(const Key('kamera-unbekannt-anlegen')));
        expect(find.byType(AnlegenBlatt), findsOneWidget);

        // Nur die Kalorien von der Packung — der Name ist vorbelegt. Ohne
        // ihn bliebe „Sichern" gesperrt.
        await tester.enterText(find.byKey(const Key('anlegen-kcal')), '398');
        await tester.pump();
        await tippe(tester, find.byKey(const Key('anlegen-sichern')));

        final angelegt = await repo.zuBarcode(codeOff);
        expect(
          angelegt,
          isNotNull,
          reason: 'Strichcode vorbelegt, Name vorbelegt — Sichern ging durch',
        );
        expect(angelegt!.name, 'Prüfwaffel Sesam');
        expect(angelegt.je100g.kcal, 398);
        expect(find.byType(BuchungsBlatt), findsOneWidget);
        expect(blatt(tester).formular.lebensmittelId, angelegt.id);
      },
    );

    testWidgets(
      'ein OFF-Treffer nur mit Kilojoule ist buchbar — umgerechnet, nicht '
      '„unbekannt"',
      (tester) async {
        final h = behaelter();
        h.netz.antwort = (_) => produktAntwort(
          codeOff,
          naehrwerte: const {'energy-kj_100g': 1046},
        );
        await starte(tester, h);
        await zurKamera(tester, h.leser);

        await scanne(tester, h.leser, codeOff);

        expect(find.byKey(const Key('kamera-unbekannt')), findsNothing);
        expect(find.byType(BuchungsBlatt), findsOneWidget);
        expect(blatt(tester).formular.je100g.kcal, closeTo(1046 / 4.184, 1e-9));
      },
    );

    testWidgets('„Stattdessen suchen" führt in die Suche', (tester) async {
      final h = behaelter();
      h.netz.antwort = (_) => unbekanntAntwort(codeUnbekannt);
      await starte(tester, h);
      await zurKamera(tester, h.leser);
      await scanne(tester, h.leser, codeUnbekannt);

      await tippe(tester, find.byKey(const Key('kamera-unbekannt-suchen')));

      expect(find.byType(SucheView), findsOneWidget);
      expect(sichtbar(find.byType(SucheView)), isTrue);
      expect(h.router.tab, Tab.heute);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Kein Netz ist ein eigener Zustand', () {
    final varianten = <String, http.Response Function(http.Request)>{
      'Socket-Fehler': (_) => throw const SocketException('kein Netz'),
      'HTTP 503': (_) => http.Response('<html>Wartung</html>', 503),
    };

    for (final MapEntry(key: name, value: antwort) in varianten.entries) {
      testWidgets('$name → „kein Netz", nicht „unbekannt"', (tester) async {
        final h = behaelter();
        h.netz.antwort = antwort;
        await starte(tester, h);
        await zurKamera(tester, h.leser);

        await scanne(tester, h.leser, codeOff);

        expect(find.byKey(const Key('kamera-kein-netz')), findsOneWidget);
        expect(
          find.byKey(const Key('kamera-unbekannt')),
          findsNothing,
          reason:
              '„nicht hinterlegt" behauptete, OFF kenne das Produkt nicht — '
              'und das weiß in dem Moment niemand',
        );
        expect(
          find.byType(AnlegenBlatt),
          findsNothing,
          reason: 'ohne Netz wird kein Anlegen angeboten, als sei es unbekannt',
        );
        expect(find.byType(BuchungsBlatt), findsNothing);
      });
    }

    testWidgets(
      '„Nochmal versuchen" fragt denselben Code erneut — die Kamera allein '
      'tut es in dieser Sitzung nicht',
      (tester) async {
        final h = behaelter();
        h.netz.antwort = (_) => throw const SocketException('kein Netz');
        await starte(tester, h);
        await zurKamera(tester, h.leser);

        await scanne(tester, h.leser, codeOff);
        expect(find.byKey(const Key('kamera-kein-netz')), findsOneWidget);
        expect(produktAnfragen(h.netz), hasLength(1));

        // Die Packung ist noch im Bild — je Sitzung wird einmal
        // ausgewertet, auch nach „kein Netz" (Entscheidung 2).
        await scanne(tester, h.leser, codeOff);
        expect(produktAnfragen(h.netz), hasLength(1));

        h.netz.antwort = (_) => produktAntwort(codeOff);
        await tippe(tester, find.byKey(const Key('kamera-nochmal')));

        final anfragen = produktAnfragen(h.netz);
        expect(anfragen, hasLength(2));
        expect(
          anfragen.last.url.path,
          contains(codeOff),
          reason: '„Nochmal" fragt **denselben** Code',
        );
        expect(find.byKey(const Key('kamera-kein-netz')), findsNothing);
        expect(find.byType(BuchungsBlatt), findsOneWidget);
        expect(blatt(tester).formular.name, 'Prüfriegel Kakao');
      },
    );
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Ein Code wird je Kamera-Sitzung einmal ausgewertet', () {
    testWidgets(
      'nach „Abbrechen" im Buchungsblatt nicht noch einmal — in einer neuen '
      'Sitzung schon',
      (tester) async {
        final h = behaelter();
        h.netz.antwort = (_) => produktAntwort(codeOff);
        await starte(tester, h);
        await zurKamera(tester, h.leser);

        await scanne(tester, h.leser, codeOff);
        expect(find.byType(BuchungsBlatt), findsOneWidget);

        await tippe(
          tester,
          find.descendant(
            of: find.byType(BuchungsBlatt),
            matching: find.text('Abbrechen'),
          ),
        );
        expect(find.byType(BuchungsBlatt), findsNothing);
        expect(
          sichtbar(find.byKey(const Key('kamera'))),
          isTrue,
          reason: '„Abbrechen" im Blatt schließt das Blatt, nicht die Kamera',
        );

        // Dieselbe Sitzung, die Packung noch im Bild.
        await scanne(tester, h.leser, codeOff);
        expect(produktAnfragen(h.netz), hasLength(1));
        expect(
          find.byType(BuchungsBlatt),
          findsNothing,
          reason: 'sonst spränge das Blatt sofort wieder auf',
        );

        // Kamera zu, Kamera auf: eine neue Sitzung.
        await tippe(tester, find.byKey(const Key('kamera-abbrechen')));
        await zurKamera(tester, h.leser);
        await scanne(tester, h.leser, codeOff);

        expect(produktAnfragen(h.netz), hasLength(2));
        expect(find.byType(BuchungsBlatt), findsOneWidget);
      },
    );

    testWidgets(
      'dreimal derselbe Code, während Open Food Facts noch antwortet → '
      'eine Anfrage, ein Blatt',
      (tester) async {
        final h = behaelter();
        // Keine sofortige Antwort: Die Anfrage hängt, bis der Test sie löst.
        await starte(tester, h);
        await zurKamera(tester, h.leser);

        for (var i = 0; i < 3; i++) {
          h.leser.erkenne(codeOff);
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(
          produktAnfragen(h.netz),
          hasLength(1),
          reason:
              'die Kamera sieht dieselbe Packung in jedem Bild — gefragt wird '
              'einmal',
        );

        h.netz.beantworte(0, produktAntwort(codeOff));
        await tester.pumpAndSettle();
        expect(find.byType(BuchungsBlatt), findsOneWidget);

        // Das Blatt ist offen, die Packung womöglich noch im Bild.
        h.leser.erkenne(codeOff);
        await tester.pumpAndSettle();
        h.leser.erkenne(codeOff);
        await tester.pumpAndSettle();

        expect(produktAnfragen(h.netz), hasLength(1));
        expect(
          find.byType(BuchungsBlatt),
          findsOneWidget,
          reason: 'kein zweites Blatt über dem ersten',
        );
      },
    );

    testWidgets('dreimal derselbe eigene Code im selben Bild → ein Blatt', (
      tester,
    ) async {
      final h = behaelter();
      h.netz.antwort = (_) => http.Response('', 500);
      await LebensmittelRepository(h.db).legeAn(
        const LebensmittelVorlage(
          name: 'Prüfmüsli',
          je100g: eigenJe100g,
          barcode: codeEigen,
        ),
      );
      await starte(tester, h);
      await zurKamera(tester, h.leser);

      // Ohne Bild dazwischen: Die Nachfrage in der eigenen Tabelle ist
      // asynchron, und genau in diese Lücke fallen die beiden weiteren.
      h.leser
        ..erkenne(codeEigen)
        ..erkenne(codeEigen)
        ..erkenne(codeEigen);
      await tester.pumpAndSettle();

      expect(find.byType(BuchungsBlatt), findsOneWidget);
      expect(h.netz.anfragen, isEmpty);
    });

    testWidgets('dreimal derselbe unbekannte Code → eine Anfrage, einmal '
        '„unbekannt"', (tester) async {
      final h = behaelter();
      h.netz.antwort = (_) => unbekanntAntwort(codeUnbekannt);
      await starte(tester, h);
      await zurKamera(tester, h.leser);

      h.leser
        ..erkenne(codeUnbekannt)
        ..erkenne(codeUnbekannt)
        ..erkenne(codeUnbekannt);
      await tester.pumpAndSettle();
      h.leser.erkenne(codeUnbekannt);
      await tester.pumpAndSettle();

      expect(produktAnfragen(h.netz), hasLength(1));
      expect(
        find.byKey(const Key('kamera-unbekannt')),
        findsOneWidget,
        reason: 'nicht dreimal derselbe Zustand übereinander',
      );
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Kamera verweigert', () {
    testWidgets(
      'ein Satz mit dem Weg in die Einstellungen statt eines schwarzen '
      'Schirms — und die Suche bleibt erreichbar',
      (tester) async {
        final h = behaelter();
        await starte(tester, h);
        await zurKamera(tester, h.leser);

        h.leser.verweigere();
        await tester.pumpAndSettle();

        final satz = find.byKey(const Key('kamera-verweigert'));
        expect(satz, findsOneWidget);
        expect(sichtbar(satz), isTrue);
        final text = tester
            .widgetList<Text>(
              find.descendant(of: satz, matching: find.byType(Text)),
            )
            .map(textOf)
            .join(' ')
            .trim();
        expect(text, isNotEmpty, reason: 'ein Satz, kein leerer Kasten');

        await tippe(tester, find.byKey(const Key('kamera-einstellungen')));
        expect(
          h.leser.einstellungenGeoeffnet,
          1,
          reason: 'der Weg führt über `StrichcodeLeser.oeffneEinstellungen`',
        );

        await tippe(tester, find.byKey(const Key('kamera-suchen')));
        expect(
          find.byType(SucheView),
          findsOneWidget,
          reason: 'ohne Kamera ist die Suche der einzige Weg — keine Sackgasse',
        );
      },
    );
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Gebucht wird auf den offenen Tag', () {
    testWidgets('wer über ‹ gestern offen hat und scannt, bucht auf gestern', (
      tester,
    ) async {
      final h = behaelter();
      h.netz.antwort = (_) => http.Response('', 500);
      await LebensmittelRepository(h.db).legeAn(
        const LebensmittelVorlage(
          name: 'Prüfmüsli',
          je100g: eigenJe100g,
          barcode: codeEigen,
        ),
      );
      await starte(tester, h);
      await zumErnaehrungsTab(tester);
      await tippe(tester, find.byKey(const Key('ernaehrung-zurueck')));

      await zurKamera(tester, h.leser);
      expect(h.router.tab, Tab.ernaehrung);
      await scanne(tester, h.leser, codeEigen);

      expect(
        blatt(tester).formular.tagesSchluessel,
        gestern,
        reason: 'das Blatt kennt den offenen Tag, nicht „heute"',
      );

      await buche(tester);

      expect(await eintraegeAm(h.db, gestern), hasLength(1));
      expect(
        await eintraegeAm(h.db, heute),
        isEmpty,
        reason:
            'ein Eintrag, der still auf dem falschen Tag landet, fällt erst '
            'nach Wochen auf (`erfassen.js`)',
      );
      expect(find.byKey(const Key('kamera')), findsNothing);
      expect(
        sichtbar(find.byType(ErnaehrungView)),
        isTrue,
        reason: 'zurück auf den Tag-Schirm, von dem aus gescannt wurde',
      );
    });

    testWidgets('auch über die Kachel „Barcode" auf dem Tag-Schirm', (
      tester,
    ) async {
      final h = behaelter();
      h.netz.antwort = (_) => http.Response('', 500);
      await LebensmittelRepository(h.db).legeAn(
        const LebensmittelVorlage(
          name: 'Prüfmüsli',
          je100g: eigenJe100g,
          barcode: codeEigen,
        ),
      );
      await starte(tester, h);
      await zumErnaehrungsTab(tester);
      await tippe(tester, find.byKey(const Key('ernaehrung-zurueck')));

      await tippe(
        tester,
        find.descendant(
          of: find.byKey(const Key('ernaehrung-wege')),
          matching: find.text('Barcode'),
        ),
      );
      expect(find.byKey(const Key('kamera')), findsOneWidget);
      await scanne(tester, h.leser, codeEigen);

      expect(blatt(tester).formular.tagesSchluessel, gestern);
      await buche(tester);
      expect(await eintraegeAm(h.db, gestern), hasLength(1));
      expect(await eintraegeAm(h.db, heute), isEmpty);
    });

    testWidgets('auch mit einem Treffer aus Open Food Facts', (tester) async {
      final h = behaelter();
      h.netz.antwort = (_) => produktAntwort(codeOff);
      await starte(tester, h);
      await zumErnaehrungsTab(tester);
      await tippe(tester, find.byKey(const Key('ernaehrung-zurueck')));

      await zurKamera(tester, h.leser);
      await scanne(tester, h.leser, codeOff);
      expect(blatt(tester).formular.tagesSchluessel, gestern);

      await buche(tester);

      final gebucht = await eintraegeAm(h.db, gestern);
      expect(gebucht, hasLength(1));
      expect(gebucht.single.name, 'Prüfriegel Kakao');
      expect(await eintraegeAm(h.db, heute), isEmpty);
    });
  });
}

// ─────────────────────────────────────────────────────────────────────────
// Netz und Health
// ─────────────────────────────────────────────────────────────────────────

/// Ein `http.Client`, der jede Anfrage festhält — und entweder sofort über
/// [antwort] antwortet oder hängt, bis [beantworte] sie löst.
class _Netz {
  final anfragen = <http.Request>[];
  final _offen = <Completer<http.Response>>[];

  http.Response Function(http.Request anfrage)? antwort;

  late final http.Client client = MockClient((anfrage) {
    anfragen.add(anfrage);
    final sofort = antwort;
    if (sofort != null) return Future.sync(() => sofort(anfrage));
    final offen = Completer<http.Response>();
    _offen.add(offen);
    return offen.future;
  });

  void beantworte(int nummer, http.Response mit) =>
      _offen[nummer].complete(mit);
}

/// Eine Quelle, die nichts liefert — kein Fall hier hängt an Apple Health.
class _StilleQuelle extends HealthReadingAttrappe {}
