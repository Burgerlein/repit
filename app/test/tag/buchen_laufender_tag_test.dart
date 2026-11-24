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

import 'package:repit/core/messwert.dart';
import 'package:repit/data/cache.dart';
import 'package:repit/data/ernaehrung_repository.dart';
import 'package:repit/data/lebensmittel_repository.dart';
import 'package:repit/data/wach_belege.dart';
import 'package:repit/data/wasser_repository.dart';
import 'package:repit/ernaehrung/buchungs_blatt.dart';
import 'package:repit/ernaehrung/erfassen_formular.dart';
import 'package:repit/ernaehrung/erfassen_provider.dart';
import 'package:repit/ernaehrung/ernaehrung_provider.dart';
import 'package:repit/ernaehrung/foto_kamera.dart';
import 'package:repit/ernaehrung/off_client.dart';
import 'package:repit/ernaehrung/strichcode_leser.dart';
import 'package:repit/ernaehrung/suche_view.dart';
import 'package:repit/ernaehrung/wasser_provider.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_types.dart';
import 'package:repit/ki/gemini_client.dart';
import 'package:repit/ki/ki_schluessel.dart';
import 'package:repit/shell/root_view.dart';
import 'package:repit/shell/router.dart';
import 'package:repit/shell/ziele.dart';
import 'package:repit/tag/laufender_tag_provider.dart';

import '../ernaehrung/foto_attrappe.dart';
import '../ernaehrung/health_schreiben_attrappe.dart';
import '../ernaehrung/kamera_attrappe.dart';
import '../health/health_reading_attrappe.dart';
import 'behaelter_im_baum.dart';
import 'berliner_wanduhr.dart';

/// Tests für **das Buchen am laufenden Tag** (#456 unter #375, Tagesgrenze;
/// löst #373 und die Wasser-Falle): Buchungsblatt, Foto-Schätzung und
/// Wasser legen eine Uhrzeit auf den richtigen Kalendertag, und jedes
/// Buchen, Ändern und Löschen hinterlässt einen Wachbeleg.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden. Hält der
/// Implementierende einen Fall für falsch, meldet er ihn.
///
/// ## Woher die Anforderung kommt
///
/// Spec `docs/superpowers/specs/2026-11-10-tagesgrenze-design.md`:
/// Entscheidung 6 (Tim, 10.11.2026), die Vorgaben V13, V14, V15 (vom
/// Planenden formuliert, laut Spec von Tim übernommen), der Befund „Die
/// Falle beim Umstellen, Wasser“ und die Tabelle „Wer auf den laufenden
/// Tag umzieht“ (Zeilen Wasser, Buchungsformular, Foto-Schätzung). Dazu
/// Issue #373. Pflichtfälle aus dem Plan
/// `docs/superpowers/plans/2026-11-10-tagesgrenze.md`, Task 6.
///
/// Verbindlich aus dem Plan:
///
/// ```dart
/// BuchungsFormular.neu(…, Tagesgrund grund = Tagesgrund.normal);
/// // `zeitpunkt` über `zeitpunktImTag`, Mahlzeit über `mahlzeitImTag`.
/// // Den Grund übergibt nur, wer auf den laufenden Tag bucht.
///
/// // Nach jedem Anlegen, Ändern und Löschen eines Essens und eines Glases:
/// wachbelegProvider.merke(WachArt.buchung); // V13
/// ```
///
/// ## Festlegungen des Test-Agenten — nicht von Tim freigegeben
///
/// - **Wie der Grund des laufenden Tages ans Formular kommt, legt diese
///   Datei nicht fest** — ob als Parameter von `oeffneFormular`,
///   `bucheDirekt` oder `KiAuftrag` oder durch Lesen von
///   `laufenderTagProvider` im Notifier. Deshalb laufen die Fälle mit dem
///   laufenden Tag **durch die ganze App** (`RootView`): Ernährungs-Tab →
///   (+) → Kamera → „Suchen“ → Treffer → Buchungsblatt, das „+“ der
///   Trefferzeile, und (+) → Kamera → „KI“ → Auslöser → Prüfblatt →
///   Buchen. Geprüft wird `BuchungsBlatt.formular` und der gebuchte
///   Eintrag in der Tabelle. Fest steht nur die Signatur aus dem Plan,
///   `BuchungsFormular.neu(…, grund:)`, und die prüft die erste Gruppe
///   unmittelbar.
/// - **„Der (+)-Weg“ (#373)** ist der (+) im Ernährungs-Tab ohne eigenen
///   Tag: Er bucht auf den offenen Tag, und der ist seit #455 der laufende.
/// - **`BuchungsFormular.fuer` (Ändern) rechnet `normal`** — V14: Den Grund
///   bekommt nur ein neues Blatt auf dem laufenden Tag. Geprüft ist der
///   Fall „um Di 01:30 auf Montag gebucht, unverändert wieder geöffnet →
///   bleibt Di 01:30“, der mit `normal` aufgeht.
///
/// ## Nachtrag: Ändern eines Eintrags aus dem verlängerten Tag
///
/// Die erste Fassung ließ offen, was mit einem Eintrag Di 05:10 auf dem
/// verlängerten Montag beim Ändern geschieht. Laut Koordinator hat **Tim
/// am 10.11.2026 entschieden:** Wird die Uhrzeit geändert, gilt die
/// normale 4-Uhr-Regel. Bleibt sie unverändert, bleibt der gespeicherte
/// Zeitpunkt **exakt** erhalten. Daraus der Fall „Di 05:10 auf Montag,
/// unverändert → Di 05:10 auf die Sekunde; auf 05:30 gestellt → Mo
/// 05:30“. Nachgetragen vom Test-Agenten von #456.
/// - **Ein Glas auf einem geblätterten Tag** rechnet `zeitpunktImTag` mit
///   `normal` (V14 nennt „Wasser auf einem geblätterten Tag“ ausdrücklich).
/// - **Der Beleg trägt die Uhr** (`clockProvider`), nicht den Zeitpunkt
///   des Eintrags — auch beim Buchen auf einen geblätterten Tag: Wach ist
///   Tim, wenn er tippt. Verlangt wird **mindestens eine** neue Zeile
///   `buchung` mit genau diesem Zeitpunkt je Aktion; ob es mehr als eine
///   wird, legt diese Datei nicht fest.
/// - **„Anlegen“ eines Essens** umfasst `buche`, das „+“ der Trefferzeile,
///   `bucheBestaetigt` (Foto-Schätzung) und `stelleWiederHer`
///   (Rückgängig auf dem Mahlzeiten-Schirm); **„Löschen“** umfasst
///   `loesche` und `nimmZurueck` (Rückgängig im Band der Suche). Alle
///   schreiben oder löschen eine Zeile in `eintraege`.
///
/// Nicht geprüft: Layout und Beschriftung (`CLAUDE.md`).
///
/// **Alle Daten hier sind erfunden und liegen im Jahr 2099** (Plan,
/// „Global Constraints“), Uhrzeiten als Berliner Wanduhr über [berlin].
/// Der 12.01.2099 ist ein Montag.
void main() {
  setUpAll(() async {
    await initializeDateFormatting('de_DE');
  });

  const so = '2099-01-11';
  const mo = '2099-01-12';
  const di = '2099-01-13';

  const flockenName = 'Probe-Flocken';
  const flockenJe100g = Naehrwerte.je100g(kcal: 370, eiweissG: 13);
  const flocken = LebensmittelVorlage(name: flockenName, je100g: flockenJe100g);

  /// Die Hauptnacht Mo 21:00 bis Di 03:30 mit 6 h Schlaf (21:00–00:00 core,
  /// 00:00–00:30 wach, 00:30–03:30 deep), Aufwachtag Dienstag — wie in
  /// `laufender_tag_test.dart`.
  SleepNight fruehBeendeteNacht() => SleepNight(
    date: datumAusTag(di),
    session: SleepSession(
      segments: [
        SleepSegment(
          stage: SleepStage.core,
          start: berlin(mo, 21, 0),
          end: berlin(di, 0, 0),
        ),
        SleepSegment(
          stage: SleepStage.awake,
          start: berlin(di, 0, 0),
          end: berlin(di, 0, 30),
        ),
        SleepSegment(
          stage: SleepStage.deep,
          start: berlin(di, 0, 30),
          end: berlin(di, 3, 30),
        ),
      ],
    ),
  );

  Messwert<List<SleepNight>> mitNacht() => Bekannt<List<SleepNight>>(
    [fruehBeendeteNacht()],
    stand: berlin(di, 3, 40),
    laeuft: false,
  );

  Messwert<List<SleepNight>> ohneNacht() =>
      LeerNachLauf<List<SleepNight>>(gelaufen: berlin(mo, 12, 0));

  /// Eigene Belege, mit denen der Montag um Di 05:10 verlängert ist: eine
  /// Kette 03:10, 04:05, 04:50, die vor 04:00 beginnt (V3).
  Future<void> legeKetteAn(AppCache db) async {
    for (final (art, zeitpunkt) in [
      (WachArt.oeffnen, berlin(di, 3, 10)),
      (WachArt.buchung, berlin(di, 4, 5)),
      (WachArt.buchung, berlin(di, 4, 50)),
    ]) {
      await db
          .into(db.wachBelege)
          .insert(
            WachBelegeCompanion.insert(zeitpunkt: zeitpunkt, art: art.name),
          );
    }
  }

  /// Die Zeitpunkte aller Belege `buchung` in der Tabelle.
  Future<List<DateTime>> buchungsBelege(AppCache db) async => [
    for (final z in await db.select(db.wachBelege).get())
      if (z.art == WachArt.buchung.name) z.zeitpunkt,
  ];

  // ═════════════════════════════════════════════════════════════════════
  group('BuchungsFormular: Uhrzeit und Mahlzeit im Tag (V14, '
      'Entscheidung 6)', () {
    BuchungsFormular neu(String tag, DateTime jetzt, [Tagesgrund? grund]) =>
        grund == null
        ? BuchungsFormular.neu(
            vorlage: flocken,
            tagesSchluessel: tag,
            jetzt: jetzt,
          )
        : BuchungsFormular.neu(
            vorlage: flocken,
            tagesSchluessel: tag,
            jetzt: jetzt,
            grund: grund,
          );

    test('#373: um Di 01:30 auf dem laufenden Montag (läuft noch) → Abend, '
        'Zeitpunkt Di 01:30, nicht Mo 01:30', () {
      final f = neu(mo, berlin(di, 1, 30), Tagesgrund.laeuftNoch);

      expect(f.tagesSchluessel, mo);
      expect(f.mahlzeit, Mahlzeit.abend);
      expect(f.zeitpunkt, _derselbe(berlin(di, 1, 30)));

      final e = f.alsEintrag();
      expect(e.tagesSchluessel, mo);
      expect(e.zeitpunkt, _derselbe(berlin(di, 1, 30)));
    });

    test(
      'Di 05:10 auf dem verlängerten Montag → Abend, Zeitpunkt Di 05:10',
      () {
        final f = neu(mo, berlin(di, 5, 10), Tagesgrund.verlaengert);

        expect(f.mahlzeit, Mahlzeit.abend, reason: 'Entscheidung 6');
        expect(f.zeitpunkt, _derselbe(berlin(di, 5, 10)));
        expect(f.alsEintrag().zeitpunkt, _derselbe(berlin(di, 5, 10)));
      },
    );

    test('Di 03:45 nach einer früh beendeten Nacht, Tag Dienstag → '
        'Frühstück, Zeitpunkt Di 03:45', () {
      final f = neu(di, berlin(di, 3, 45), Tagesgrund.nachtVorbei);

      expect(f.tagesSchluessel, di);
      expect(f.mahlzeit, Mahlzeit.fruehstueck, reason: 'Entscheidung 6');
      expect(f.zeitpunkt, _derselbe(berlin(di, 3, 45)));
    });

    test('Uhrzeit von Hand am laufenden Montag um Di 01:30: 23:00 → Mo 23:00, '
        '02:00 → Di 02:00', () {
      final f = neu(mo, berlin(di, 1, 30), Tagesgrund.laeuftNoch);

      expect(f.mitUhrzeit(23 * 60).zeitpunkt, _derselbe(berlin(mo, 23, 0)));
      expect(f.mitUhrzeit(2 * 60).zeitpunkt, _derselbe(berlin(di, 2, 0)));
      expect(
        f.mitUhrzeit(23 * 60).alsEintrag().zeitpunkt,
        _derselbe(berlin(mo, 23, 0)),
      );
    });

    test('der Grund bleibt beim Setzen der Uhrzeit: im verlängerten Montag '
        '06:00 → Di 06:00, 09:00 → Mo 09:00', () {
      final f = neu(mo, berlin(di, 5, 10), Tagesgrund.verlaengert);

      expect(f.mitUhrzeit(6 * 60).zeitpunkt, _derselbe(berlin(di, 6, 0)));
      expect(f.mitUhrzeit(9 * 60).zeitpunkt, _derselbe(berlin(mo, 9, 0)));
    });

    test(
      'auf Sonntag geblättert, ohne Grund: um Di 14:00 → So 14:00, Mittag',
      () {
        final f = neu(so, berlin(di, 14, 0));

        expect(f.tagesSchluessel, so);
        expect(f.mahlzeit, Mahlzeit.mittag);
        expect(f.zeitpunkt, _derselbe(berlin(so, 14, 0)));
      },
    );

    test(
      'auf Sonntag geblättert, ohne Grund: um Di 01:30 → Mo 01:30, Abend',
      () {
        final f = neu(so, berlin(di, 1, 30));

        expect(f.tagesSchluessel, so);
        expect(f.mahlzeit, Mahlzeit.abend);
        expect(f.zeitpunkt, _derselbe(berlin(mo, 1, 30)));
      },
    );

    test('ein um Di 01:30 auf Montag gebuchter Eintrag, wieder geöffnet, '
        'behält Di 01:30; von Hand auf 23:00 → Mo 23:00', () {
      final f = BuchungsFormular.fuer(
        Eintrag(
          id: 7,
          tagesSchluessel: mo,
          mahlzeit: Mahlzeit.abend,
          zeitpunkt: berlin(di, 1, 30),
          name: flockenName,
          mengeG: 100,
          naehrwerte: flockenJe100g.fuerMenge(100),
        ),
      );

      expect(f.zeitpunkt, _derselbe(berlin(di, 1, 30)));
      expect(f.alsEintrag().zeitpunkt, _derselbe(berlin(di, 1, 30)));
      expect(f.mitUhrzeit(23 * 60).zeitpunkt, _derselbe(berlin(mo, 23, 0)));
    });

    test('ein Eintrag Di 05:10 auf dem verlängerten Montag: unverändert '
        'bleibt der Zeitpunkt exakt, auf 05:30 gestellt gilt die 4-Uhr-Regel '
        '→ Mo 05:30 (Tim, 10.11.2026)', () {
      // Mit Sekunden: „exakt erhalten“ heißt auch die nicht.
      final gespeichert = berlin(di, 5, 10).add(const Duration(seconds: 42));
      final f = BuchungsFormular.fuer(
        Eintrag(
          id: 8,
          tagesSchluessel: mo,
          mahlzeit: Mahlzeit.abend,
          zeitpunkt: gespeichert,
          name: flockenName,
          mengeG: 100,
          naehrwerte: flockenJe100g.fuerMenge(100),
        ),
      );

      expect(f.zeitpunkt, _derselbe(gespeichert));
      expect(f.alsEintrag().zeitpunkt, _derselbe(gespeichert));
      expect(
        f.mitMenge('150').alsEintrag().zeitpunkt,
        _derselbe(gespeichert),
        reason: 'eine geänderte Menge ändert die Uhrzeit nicht',
      );
      expect(
        f.mitUhrzeit(5 * 60 + 30).alsEintrag().zeitpunkt,
        _derselbe(berlin(mo, 5, 30)),
      );
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Der (+)-Weg in der App (#373)', () {
    /// Die ganze App auf einer Datenbank im Speicher, mit einem gebuchten
    /// Lebensmittel „Probe-Flocken“.
    Future<({ProviderContainer container, AppCache db, int flockenId})> starte(
      WidgetTester tester, {
      required DateTime jetzt,
      Messwert<List<SleepNight>>? naechte,
      bool verlaengert = false,
    }) async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);
      if (verlaengert) await legeKetteAn(db);
      final id = await LebensmittelRepository(db).legeAn(flocken);

      // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          appCacheProvider.overrideWithValue(db),
          healthProvider.overrideWithValue(_StilleQuelle()),
          clockProvider.overrideWithValue(() => jetzt),
          strichcodeLeserProvider.overrideWithValue(TestLeser()),
          if (naechte != null)
            sleepProvider.overrideWith(() => _Naechte(naechte)),
        ],
      );
      addTearDown(container.dispose);

      tester.view.physicalSize = const Size(900, 4800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final router = AppRouter();
      await tester.pumpWidget(
        BehaelterImBaum(
          container: container,
          child: CupertinoApp(home: RootView(router: router)),
        ),
      );
      await tester.pumpAndSettle();
      router.open(AppTarget.ernaehrung());
      await tester.pumpAndSettle();
      return (container: container, db: db, flockenId: id);
    }

    Future<void> tippe(WidgetTester tester, Finder ziel) async {
      await tester.tap(ziel);
      await tester.pumpAndSettle();
    }

    /// (+) → Kamera → „Suchen“ → „P“ ins Suchfeld.
    Future<void> zurSuche(WidgetTester tester) async {
      await tippe(tester, find.byKey(const Key('erfassen-knopf')));
      expect(
        find.byKey(const Key('kamera')),
        findsOneWidget,
        reason: 'der (+) öffnet die Kamera',
      );
      await tippe(tester, find.byKey(const Key('kamera-suchen')));
      expect(find.byType(SucheView), findsOneWidget);
      await tester.enterText(find.byKey(const Key('erfassen-suchfeld')), 'P');
      await tester.pumpAndSettle();
    }

    /// … und ein Tipp auf den Treffer: das Buchungsblatt.
    Future<BuchungsFormular> blatt(WidgetTester tester, int id) async {
      await zurSuche(tester);
      await tippe(tester, find.byKey(Key('erfassen-treffer-$id')));
      expect(find.byType(BuchungsBlatt), findsOneWidget);
      return tester.widget<BuchungsBlatt>(find.byType(BuchungsBlatt)).formular;
    }

    /// Lässt Band und Entprellung auslaufen, damit kein Zeitgeber über das
    /// Testende hinaus hängt.
    Future<void> ausklingen(WidgetTester tester) async {
      await tester.pump(const Duration(seconds: 9));
      await tester.pump();
    }

    testWidgets('Di 01:30, laufender Montag: das Blatt bucht auf Montag, '
        'Abend, Di 01:30 — und der Eintrag steht in eigeneEintraegeProvider('
        'Mo)', (tester) async {
      final h = await starte(tester, jetzt: berlin(di, 1, 30));
      expect(h.container.read(laufenderTagProvider).tag, mo);
      expect(h.container.read(offenerTagProvider), mo);

      final f = await blatt(tester, h.flockenId);
      expect(f.tagesSchluessel, mo);
      expect(f.mahlzeit, Mahlzeit.abend);
      expect(f.zeitpunkt, _derselbe(berlin(di, 1, 30)));

      await tippe(tester, find.byKey(const Key('buchung-sichern')));
      expect(find.byType(BuchungsBlatt), findsNothing);

      final montag = h.container.read(eigeneEintraegeProvider(mo)).value;
      expect(montag, isNotNull);
      expect(montag!.map((e) => e.name), [flockenName]);
      expect(montag.single.mahlzeit, Mahlzeit.abend);
      expect(montag.single.zeitpunkt, _derselbe(berlin(di, 1, 30)));
      expect(await ErnaehrungRepository(h.db).eintraegeAmTag(di), isEmpty);
      expect(
        await buchungsBelege(h.db),
        contains(_derselbe(berlin(di, 1, 30))),
        reason: 'V13: Buchen hinterlässt einen Beleg',
      );

      await ausklingen(tester);
    });

    testWidgets('Di 01:30: das „+“ der Trefferzeile bucht ebenso auf Montag, '
        'Abend, Di 01:30', (tester) async {
      final h = await starte(tester, jetzt: berlin(di, 1, 30));

      await zurSuche(tester);
      await tippe(
        tester,
        find.byKey(Key('erfassen-plus-treffer-${h.flockenId}')),
      );

      final montag = await ErnaehrungRepository(h.db).eintraegeAmTag(mo);
      expect(montag.map((e) => e.name), [flockenName]);
      expect(montag.single.mahlzeit, Mahlzeit.abend);
      expect(montag.single.zeitpunkt, _derselbe(berlin(di, 1, 30)));
      expect(await ErnaehrungRepository(h.db).eintraegeAmTag(di), isEmpty);
      expect(
        await buchungsBelege(h.db),
        contains(_derselbe(berlin(di, 1, 30))),
      );

      await ausklingen(tester);
    });

    testWidgets('Di 05:10, verlängerter Montag: Montag, Abend, Di 05:10', (
      tester,
    ) async {
      final h = await starte(
        tester,
        jetzt: berlin(di, 5, 10),
        verlaengert: true,
      );
      expect(
        h.container.read(laufenderTagProvider).grund,
        Tagesgrund.verlaengert,
        reason: 'Voraussetzung: die Kette 03:10, 04:05, 04:50 verlängert',
      );
      expect(h.container.read(offenerTagProvider), mo);

      final f = await blatt(tester, h.flockenId);
      expect(f.tagesSchluessel, mo);
      expect(f.mahlzeit, Mahlzeit.abend, reason: 'Entscheidung 6');
      expect(f.zeitpunkt, _derselbe(berlin(di, 5, 10)));

      await tippe(tester, find.byKey(const Key('buchung-sichern')));
      final montag = await ErnaehrungRepository(h.db).eintraegeAmTag(mo);
      expect(montag.single.zeitpunkt, _derselbe(berlin(di, 5, 10)));

      await ausklingen(tester);
    });

    testWidgets('Di 03:45 nach einer früh beendeten Nacht: Dienstag, '
        'Frühstück, Di 03:45', (tester) async {
      final h = await starte(
        tester,
        jetzt: berlin(di, 3, 45),
        naechte: mitNacht(),
      );
      expect(
        h.container.read(laufenderTagProvider).grund,
        Tagesgrund.nachtVorbei,
        reason: 'Voraussetzung: die Nacht ist vorbei',
      );
      expect(h.container.read(offenerTagProvider), di);

      final f = await blatt(tester, h.flockenId);
      expect(f.tagesSchluessel, di);
      expect(f.mahlzeit, Mahlzeit.fruehstueck, reason: 'Entscheidung 6');
      expect(f.zeitpunkt, _derselbe(berlin(di, 3, 45)));

      await ausklingen(tester);
    });

    testWidgets('auf Sonntag geblättert um Di 01:30: Sonntag, Abend, '
        'Mo 01:30', (tester) async {
      final h = await starte(tester, jetzt: berlin(di, 1, 30));
      await tippe(tester, find.byKey(const Key('ernaehrung-zurueck')));
      expect(h.container.read(offenerTagProvider), so);

      final f = await blatt(tester, h.flockenId);
      expect(f.tagesSchluessel, so);
      expect(f.mahlzeit, Mahlzeit.abend);
      expect(f.zeitpunkt, _derselbe(berlin(mo, 1, 30)));

      await ausklingen(tester);
    });

    testWidgets('auf Sonntag geblättert um Di 05:10 im verlängerten Montag: '
        'der Grund gilt nur für den laufenden Tag — Sonntag, Frühstück, '
        'So 05:10', (tester) async {
      final h = await starte(
        tester,
        jetzt: berlin(di, 5, 10),
        verlaengert: true,
      );
      expect(
        h.container.read(laufenderTagProvider).grund,
        Tagesgrund.verlaengert,
      );
      await tippe(tester, find.byKey(const Key('ernaehrung-zurueck')));
      expect(h.container.read(offenerTagProvider), so);

      final f = await blatt(tester, h.flockenId);
      expect(f.tagesSchluessel, so);
      expect(f.mahlzeit, Mahlzeit.fruehstueck, reason: 'V14: normal');
      expect(f.zeitpunkt, _derselbe(berlin(so, 5, 10)));

      await ausklingen(tester);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('Foto-Schätzung (Tabelle „Wer auf den laufenden Tag umzieht“)', () {
    const schluessel = 'erfunden-schluessel-wxyz';

    http.Response antwort() => http.Response(
      jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {
                  'text': jsonEncode({
                    'isFood': true,
                    'title': 'Probe-Eintopf',
                    'items': [
                      {
                        'name': 'Probe-Eintopf',
                        'grams': 300,
                        'kcal': 360,
                        'proteinG': 20,
                        'carbsG': 40,
                        'fatG': 10,
                        'confident': true,
                      },
                    ],
                    'note': null,
                  }),
                },
              ],
            },
          },
        ],
        'usageMetadata': {
          'promptTokenCount': 1200,
          'candidatesTokenCount': 300,
          'thoughtsTokenCount': 40,
        },
      }),
      200,
      headers: const {'content-type': 'application/json'},
    );

    Future<AppCache> starte(
      WidgetTester tester, {
      required DateTime jetzt,
      bool verlaengert = false,
    }) async {
      final db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);
      if (verlaengert) await legeKetteAn(db);
      final speicher = AttrappenSchluesselSpeicher();
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
        return antwort();
      });
      final off = MockClient((anfrage) async {
        fail('unerwartete Anfrage an Open Food Facts: ${anfrage.url}');
      });

      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          appCacheProvider.overrideWithValue(db),
          healthProvider.overrideWithValue(_StilleQuelle()),
          clockProvider.overrideWithValue(() => jetzt),
          offClientProvider.overrideWithValue(OffClient(client: off)),
          strichcodeLeserProvider.overrideWithValue(TestLeser()),
          fotoKameraProvider.overrideWithValue(TestFotoKamera()),
          kiSchluesselProvider.overrideWithValue(speicher),
          kiAnbieterProvider.overrideWithValue(GeminiAnbieter(gemini)),
        ],
      );
      addTearDown(container.dispose);
      unawaited(speicher.schreibe(schluessel));

      tester.view.physicalSize = const Size(900, 4800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final router = AppRouter();
      await tester.pumpWidget(
        BehaelterImBaum(
          container: container,
          child: CupertinoApp(home: RootView(router: router)),
        ),
      );
      await tester.pumpAndSettle();
      router.open(AppTarget.ernaehrung());
      await tester.pumpAndSettle();
      if (verlaengert) {
        expect(
          container.read(laufenderTagProvider).grund,
          Tagesgrund.verlaengert,
          reason: 'Voraussetzung: die Kette verlängert den Montag',
        );
      }
      expect(container.read(offenerTagProvider), mo);
      return db;
    }

    /// Lässt Zeit vergehen, ohne auf Ruhe zu warten — ein drehender
    /// Indikator ließe `pumpAndSettle` sonst ins Zeitlimit laufen.
    Future<void> ruhe(WidgetTester tester) async {
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> tippe(WidgetTester tester, Finder ziel) async {
      await tester.tap(ziel);
      await ruhe(tester);
    }

    /// (+) → Kamera → „KI“ → Auslöser → Prüfblatt → Buchen.
    Future<void> schaetzeUndBuche(WidgetTester tester) async {
      await tippe(tester, find.byKey(const Key('erfassen-knopf')));
      await tippe(tester, find.byKey(const Key('kamera-modus-ki')));
      await tippe(tester, find.byKey(const Key('ki-ausloeser')));
      expect(find.byKey(const Key('ki-pruefblatt')), findsOneWidget);
      await tippe(tester, find.byKey(const Key('ki-pruef-buchen')));
    }

    testWidgets('um Di 01:30 auf dem laufenden Montag: Abend, Zeitpunkt '
        'Di 01:30', (tester) async {
      final db = await starte(tester, jetzt: berlin(di, 1, 30));

      await schaetzeUndBuche(tester);

      final montag = await ErnaehrungRepository(db).eintraegeAmTag(mo);
      expect(montag.map((e) => e.name), ['Probe-Eintopf']);
      expect(montag.single.mahlzeit, Mahlzeit.abend);
      expect(montag.single.zeitpunkt, _derselbe(berlin(di, 1, 30)));
      expect(await ErnaehrungRepository(db).eintraegeAmTag(di), isEmpty);
      expect(
        await buchungsBelege(db),
        contains(_derselbe(berlin(di, 1, 30))),
        reason: 'V13: auch die Foto-Schätzung bucht ein Essen',
      );
    });

    testWidgets('um Di 05:10 auf dem verlängerten Montag: Abend, Zeitpunkt '
        'Di 05:10', (tester) async {
      final db = await starte(
        tester,
        jetzt: berlin(di, 5, 10),
        verlaengert: true,
      );

      await schaetzeUndBuche(tester);

      final montag = await ErnaehrungRepository(db).eintraegeAmTag(mo);
      expect(montag.map((e) => e.name), ['Probe-Eintopf']);
      expect(montag.single.mahlzeit, Mahlzeit.abend, reason: 'Entscheidung 6');
      expect(montag.single.zeitpunkt, _derselbe(berlin(di, 5, 10)));
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  // Die Fälle am Provider: Wasser und die Belege.
  // ═════════════════════════════════════════════════════════════════════
  group('Am Provider', () {
    late AppCache db;

    setUp(() {
      db = AppCache(NativeDatabase.memory());
      addTearDown(db.close);
    });

    /// Echte Tabelle im Speicher, steuerbare Uhr, Health zum Schreiben,
    /// abgeschaltete Wiederholung (`CLAUDE.md`).
    ({
      ProviderContainer c,
      SchreibAttrappe health,
      void Function(DateTime) stelleUhr,
    })
    behaelter({required DateTime jetzt, Messwert<List<SleepNight>>? naechte}) {
      var uhr = jetzt;
      final health = SchreibAttrappe();
      final c = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          appCacheProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(() => uhr),
          healthProvider.overrideWithValue(health),
          sleepProvider.overrideWith(() => _Naechte(naechte ?? ohneNacht())),
          offClientProvider.overrideWithValue(
            OffClient(
              client: MockClient(
                (_) async => http.Response('nicht im Test', 500),
              ),
            ),
          ),
        ],
      );
      addTearDown(c.dispose);
      return (c: c, health: health, stelleUhr: (neu) => uhr = neu);
    }

    /// Lässt den Anstoß aus `build()` laufen und sieht danach selbst nach —
    /// wie in `laufender_tag_test.dart`.
    Future<Tagesstand> nachgesehen(ProviderContainer c) async {
      c.listen(laufenderTagProvider, (_, _) {});
      await c.read(sleepProvider.future);
      await pumpEventQueue();
      await c.read(laufenderTagProvider.notifier).pruefe();
      await pumpEventQueue();
      return c.read(laufenderTagProvider);
    }

    Future<void> trageEin(ProviderContainer c, String tag, double ml) async {
      c.listen(wasserProvider(tag), (_, _) {});
      await c.read(wasserProvider(tag).future);
      await c.read(wasserProvider(tag).notifier).trageEin(ml);
      await pumpEventQueue();
    }

    // ═════════════════════════════════════════════════════════════════════
    group('Wasser (V14, V15, Befund „Die Falle beim Umstellen“)', () {
      test('Wasser-Falle: ein Glas um Di 01:30 auf dem laufenden Montag trägt '
          'Di 01:30 — in der Tabelle und an Health', () async {
        final b = behaelter(jetzt: berlin(di, 1, 30));
        expect((await nachgesehen(b.c)).tag, mo);

        await trageEin(b.c, mo, 250);

        final montag = await WasserRepository(db).wasserAmTag(mo);
        expect(montag.map((e) => e.mengeMl), [250]);
        expect(montag.single.tagesSchluessel, mo);
        expect(montag.single.zeitpunkt, _derselbe(berlin(di, 1, 30)));
        expect(await WasserRepository(db).wasserAmTag(di), isEmpty);

        expect(b.health.geschrieben, hasLength(1));
        expect(
          b.health.geschrieben.single.at,
          _derselbe(berlin(di, 1, 30)),
          reason: 'nie Mo 01:30 — vor dem Beginn des Tages, auf dem es steht',
        );
      });

      test(
        'ein Glas um Di 05:10 auf dem verlängerten Montag trägt Di 05:10',
        () async {
          await legeKetteAn(db);
          final b = behaelter(jetzt: berlin(di, 5, 10));
          final stand = await nachgesehen(b.c);
          expect(stand.tag, mo);
          expect(stand.grund, Tagesgrund.verlaengert);

          await trageEin(b.c, mo, 500);

          final montag = await WasserRepository(db).wasserAmTag(mo);
          expect(montag.single.zeitpunkt, _derselbe(berlin(di, 5, 10)));
          expect(b.health.geschrieben.single.at, _derselbe(berlin(di, 5, 10)));
        },
      );

      test('ein Glas um Di 03:45 nach einer früh beendeten Nacht, auf dem '
          'laufenden Dienstag, trägt Di 03:45', () async {
        final b = behaelter(jetzt: berlin(di, 3, 45), naechte: mitNacht());
        final stand = await nachgesehen(b.c);
        expect(stand.tag, di);
        expect(stand.grund, Tagesgrund.nachtVorbei);

        await trageEin(b.c, di, 250);

        final dienstag = await WasserRepository(db).wasserAmTag(di);
        expect(dienstag.single.zeitpunkt, _derselbe(berlin(di, 3, 45)));
      });

      test('auf Sonntag geblättert um Di 01:30: das Glas trägt Mo 01:30 '
          '(zeitpunktImTag, normal)', () async {
        final b = behaelter(jetzt: berlin(di, 1, 30));
        await nachgesehen(b.c);

        await trageEin(b.c, so, 250);

        final sonntag = await WasserRepository(db).wasserAmTag(so);
        expect(sonntag.single.tagesSchluessel, so);
        expect(sonntag.single.zeitpunkt, _derselbe(berlin(mo, 1, 30)));
        expect(b.health.geschrieben.single.at, _derselbe(berlin(mo, 1, 30)));
      });

      test(
        'auf Sonntag geblättert um Di 05:10 im verlängerten Montag: das '
        'Glas trägt So 05:10 — der Grund gilt nur für den laufenden Tag',
        () async {
          await legeKetteAn(db);
          final b = behaelter(jetzt: berlin(di, 5, 10));
          expect((await nachgesehen(b.c)).grund, Tagesgrund.verlaengert);

          await trageEin(b.c, so, 250);

          final sonntag = await WasserRepository(db).wasserAmTag(so);
          expect(sonntag.single.zeitpunkt, _derselbe(berlin(so, 5, 10)));
        },
      );
    });

    // ═════════════════════════════════════════════════════════════════════
    group('Jedes Buchen, Ändern, Löschen hinterlässt einen Beleg „buchung“ '
        '(V13)', () {
      /// Stellt die Uhr auf [um], führt [aktion] aus und verlangt danach eine
      /// **neue** Zeile `buchung` mit genau diesem Zeitpunkt.
      Future<void> hinterlaesstBeleg(
        ({
          ProviderContainer c,
          SchreibAttrappe health,
          void Function(DateTime) stelleUhr,
        })
        b,
        DateTime um,
        Future<void> Function() aktion, {
        required String was,
      }) async {
        b.stelleUhr(um);
        final vorher = await buchungsBelege(db);
        expect(
          vorher.where((t) => t.isAtSameMomentAs(um)),
          isEmpty,
          reason: 'vor „$was“ steht noch kein Beleg zu dieser Uhrzeit',
        );

        await aktion();
        await pumpEventQueue();

        final nachher = await buchungsBelege(db);
        expect(
          nachher.where((t) => t.isAtSameMomentAs(um)),
          isNotEmpty,
          reason: '„$was“ hinterlässt einen Beleg „buchung“ mit der Uhr',
        );
      }

      ErfassenNotifier erfassen(ProviderContainer c) {
        c.listen(erfassenProvider, (_, _) {});
        return c.read(erfassenProvider.notifier);
      }

      BuchungsFormular formular(String tag, DateTime jetzt) =>
          BuchungsFormular.neu(
            vorlage: flocken,
            tagesSchluessel: tag,
            jetzt: jetzt,
          );

      Future<Eintrag> einziger(String tag) async =>
          (await ErnaehrungRepository(db).eintraegeAmTag(tag)).single;

      test('Essen: Buchen über das Blatt', () async {
        final b = behaelter(jetzt: berlin(di, 14, 0));
        await nachgesehen(b.c);

        await hinterlaesstBeleg(
          b,
          berlin(di, 14, 0),
          () => erfassen(b.c).buche(formular(di, berlin(di, 14, 0))),
          was: 'buche',
        );
      });

      test(
        'Essen: Buchen auf einen geblätterten Tag — der Beleg trägt die Uhr, '
        'nicht den Zeitpunkt des Eintrags',
        () async {
          final b = behaelter(jetzt: berlin(di, 14, 0));
          await nachgesehen(b.c);

          await hinterlaesstBeleg(
            b,
            berlin(di, 14, 0),
            () => erfassen(b.c).buche(formular(so, berlin(di, 14, 0))),
            was: 'buche auf Sonntag',
          );
          expect(
            (await buchungsBelege(db))
                .where((t) => t.isAtSameMomentAs(berlin(so, 14, 0))),
            isEmpty,
          );
        },
      );

      // Das „+“ der Trefferzeile (`bucheDirekt`) prüft die Gruppe „Der
      // (+)-Weg in der App“ samt Beleg — dort, ohne seine Signatur
      // festzulegen.

      test('Essen: Ändern', () async {
        final b = behaelter(jetzt: berlin(di, 14, 0));
        await nachgesehen(b.c);
        await erfassen(b.c).buche(formular(di, berlin(di, 14, 0)));
        final eintrag = await einziger(di);

        await hinterlaesstBeleg(
          b,
          berlin(di, 14, 5),
          () =>
              erfassen(b.c)
                  .aendere(BuchungsFormular.fuer(eintrag).mitMenge('150')),
          was: 'aendere',
        );
        expect((await einziger(di)).mengeG, 150);
      });

      test('Essen: Löschen', () async {
        final b = behaelter(jetzt: berlin(di, 14, 0));
        await nachgesehen(b.c);
        await erfassen(b.c).buche(formular(di, berlin(di, 14, 0)));
        final eintrag = await einziger(di);

        await hinterlaesstBeleg(
          b,
          berlin(di, 14, 10),
          () => erfassen(b.c).loesche(eintrag),
          was: 'loesche',
        );
        expect(await ErnaehrungRepository(db).eintraegeAmTag(di), isEmpty);
      });

      test('Essen: Rückgängig im Band der Suche (nimmZurueck)', () async {
        final b = behaelter(jetzt: berlin(di, 14, 0));
        await nachgesehen(b.c);
        final id = await erfassen(b.c).buche(formular(di, berlin(di, 14, 0)));

        await hinterlaesstBeleg(
          b,
          berlin(di, 14, 15),
          () => erfassen(b.c).nimmZurueck(id),
          was: 'nimmZurueck',
        );
        expect(await ErnaehrungRepository(db).eintraegeAmTag(di), isEmpty);
      });

      test(
        'Essen: Wiederherstellen nach dem Streichen (stelleWiederHer)',
        () async {
          final b = behaelter(jetzt: berlin(di, 14, 0));
          await nachgesehen(b.c);
          await erfassen(b.c).buche(formular(di, berlin(di, 14, 0)));
          final eintrag = await einziger(di);
          await erfassen(b.c).loesche(eintrag);

          await hinterlaesstBeleg(
            b,
            berlin(di, 14, 20),
            () => erfassen(b.c).stelleWiederHer(eintrag),
            was: 'stelleWiederHer',
          );
          expect((await einziger(di)).name, flockenName);
        },
      );

      test('Essen: ein bestätigter Vorschlag der Foto-Schätzung '
          '(bucheBestaetigt)', () async {
        final b = behaelter(jetzt: berlin(di, 14, 0));
        await nachgesehen(b.c);

        await hinterlaesstBeleg(
          b,
          berlin(di, 14, 25),
          () => erfassen(b.c).bucheBestaetigt([
            Eintrag(
              tagesSchluessel: di,
              mahlzeit: Mahlzeit.mittag,
              zeitpunkt: berlin(di, 14, 25),
              name: 'Probe-Eintopf',
              mengeG: 300,
              naehrwerte: const Naehrwerte(kcal: 360),
            ),
          ]),
          was: 'bucheBestaetigt',
        );
      });

      test('Wasser: Eintragen, Ändern, Löschen', () async {
        final b = behaelter(jetzt: berlin(di, 14, 0));
        await nachgesehen(b.c);

        await hinterlaesstBeleg(
          b,
          berlin(di, 14, 30),
          () => trageEin(b.c, di, 250),
          was: 'Wasser trageEin',
        );

        final glas = (await WasserRepository(db).wasserAmTag(di)).single;
        await hinterlaesstBeleg(
          b,
          berlin(di, 14, 35),
          () => b.c.read(wasserProvider(di).notifier).aendere(glas, 500),
          was: 'Wasser aendere',
        );

        final geaendert = (await WasserRepository(db).wasserAmTag(di)).single;
        expect(geaendert.mengeMl, 500);
        await hinterlaesstBeleg(
          b,
          berlin(di, 14, 40),
          () => b.c.read(wasserProvider(di).notifier).loesche(geaendert),
          was: 'Wasser loesche',
        );
        expect(await WasserRepository(db).wasserAmTag(di), isEmpty);
      });
    });
  });
}

// ───────────────────────────────────────────────────────────────────────
// Helfer und Attrappen
// ───────────────────────────────────────────────────────────────────────

/// Derselbe Zeitpunkt, gleich ob UTC oder Ortszeit — mit der Berliner
/// Wanduhr in der Beschreibung, damit ein Fehlschlag Mo 01:30 und Di 01:30
/// beim Namen nennt.
Matcher _derselbe(DateTime erwartet) => predicate<DateTime>(
  (t) => t.isAtSameMomentAs(erwartet),
  'derselbe Zeitpunkt wie ${_wand(erwartet)}',
);

String _wand(DateTime t) {
  final (stunde, minute) = BerlinCalendar.wallClock(t);
  String zwei(int n) => n.toString().padLeft(2, '0');
  return '${BerlinCalendar.dayKey(t)} ${zwei(stunde)}:${zwei(minute)} Berlin';
}

/// Eine Quelle, die nichts liefert und nichts schreibt.
class _StilleQuelle extends HealthReadingAttrappe {}

/// `sleepProvider` mit festem Stand.
class _Naechte extends SleepNotifier {
  _Naechte(this._stand);

  final Messwert<List<SleepNight>> _stand;

  @override
  Future<Messwert<List<SleepNight>>> build() async => _stand;
}
