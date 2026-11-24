import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/data/zyklus_repository.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/shell/router.dart';
import 'package:repit/zyklus/zyklus_raster.dart';
import 'package:repit/zyklus/zyklus_tag_view.dart';
import 'package:repit/zyklus/zyklus_texte.dart';
import 'package:repit/zyklus/zyklus_view.dart';

import '../design/support.dart' show textOf;
import '../health/health_reading_attrappe.dart';
import '../tag/behaelter_im_baum.dart';

/// Widget-Tests für den Schirm **„Zyklus"** — den Kalender (#571 unter
/// #539, Stufe 5 des Umsetzungsplans), `lib/zyklus/zyklus_view.dart`.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden. Hält der
/// Implementierende einen Fall für falsch, **meldet** er ihn, statt ihn
/// passend zu machen.
///
/// ## Woher die Anforderung kommt
///
/// - Spec `docs/superpowers/specs/2026-11-23-zyklus-spec.md`, Abschnitt
///   3 (Vorhersage), 5.1 (Provider-Schicht) und 7 (Schirme).
/// - Entwurfsboard `docs/screens/screens/zyklus.js` — die sieben
///   Zustände dort sind die Abnahmekriterien.
/// - Plan `docs/superpowers/plans/2026-11-23-zyklus-umsetzung.md`,
///   Stufe 5: „alle Zustände des Entwurfs, Keine-Daten-Ansicht dabei".
///
/// Der Code des Schirms existierte beim Schreiben dieser Datei nicht.
/// Gelesen wurden Spec, Plan, Entwurfsboard, die fertigen Bausteine
/// (`zyklus_raster.dart`, `zyklus_texte.dart`), der Kern
/// (`Packages/trainings_core/lib/src/zyklus_*.dart`) und die bereits
/// festgelegte Ablage (`app/test/data/zyklus_repository_test.dart`).
///
/// ## Worauf diese Datei zielt
///
/// `CLAUDE.md`, „Tests": **Zustände und Übergänge, nicht Layout und
/// Beschriftung.** Kein Fall hier prüft eine Farbe, einen Abstand oder
/// den Wortlaut eines Knopfes. Geprüft wird:
///
/// 1. **Während des Ladens steht nie ein „keine Daten"-Grund** (`01`).
/// 2. **Ein Wert, der dastand, steht nach dem Zurücknavigieren wieder
///    da** (`32`).
/// 3. Die Zustände des Entwurfs: laufender Zyklus, noch keine
///    Vorhersage, nächster Monat, unter Pille, Test positiv, und dass
///    **jeder Tag eine Tür** ist.
///
/// Was im Tag liegt, wird über das Widget `ZyklusZelle` gelesen — über
/// seinen Werttyp [ZyklusTag], nicht über Pixel. Die Zelle selbst ist
/// gebaut und anderswo geprüft; hier zählt, **was der Schirm ihr
/// übergibt**.
///
/// ## Die API, auf die sich diese Datei festlegt
///
/// Spec und Entwurf nennen keine Dart-Namen. Damit der Implementierende
/// nicht raten muss (der Plan: „Was unterwegs auffällt, wird als Karte
/// abgelegt und im Code benannt, nicht geraten"), legt diese Datei fest
/// — **nicht von Tim freigegeben**:
///
/// | Was | Wo |
/// |---|---|
/// | `ZyklusSeite({required AppRouter router})` | `lib/zyklus/zyklus_view.dart` |
/// | `void oeffneZyklus(AppRouter router)` | ebenda, für das Mehr-Menü (#573) |
/// | `ZyklusTagSeite({required String tag})` | `lib/zyklus/zyklus_tag_view.dart` |
/// | `void oeffneZyklusTag(AppRouter router, {required String tag})` | ebenda |
///
/// Schlüssel:
///
/// | Schlüssel | Was |
/// |---|---|
/// | `zyklus` | der Schirm selbst (`CupertinoPageScaffold`) |
/// | `zyklus-legende` | die Legende unter dem Raster — steht immer |
/// | `zyklus-lage` | die [LageZeile] unter der Legende, wenn es eine Lage gibt |
/// | `zyklus-eintragen` | die Zeile am Fuß, die das Eintragen öffnet |
///
/// Weitere Festlegungen, jede mit ihrem Grund an Ort und Stelle:
///
/// - **`ZyklusRepository` bleibt erweiterbar** (nicht `final`, nicht
///   `sealed`): Der Ladezustand lässt sich sonst nicht erzeugen, ohne
///   eine echte Datenbank künstlich langsam zu machen.
/// - **Der Schirm öffnet den Monat, in dem `clockProvider` steht** —
///   nicht `DateTime.now()`. Die Uhr hier steht im Jahr 2099, damit das
///   auffällt.
/// - **Ein Tipp auf einen Tag markiert nichts.** Er öffnet das
///   Eintragen für diesen Tag, und danach steht das Raster da wie
///   vorher; die Zeile am Fuß meint weiter heute.
///
///   *Diese Datei hat bis zum 24.11.2026 das Gegenteil festgelegt — der
///   angetippte Tag bleibe gewählt, die Zelle sei `gedrueckt`, die
///   Zeile am Fuß nenne sein Datum (Entwurf, Variante `tag-gewaehlt`).
///   Das war eine Festlegung dieses Test-Agenten, von Tim nie gesehen,
///   und sie war falsch: Tim hat am Gerät gemeldet, „beim Drücken auf
///   einen Tag kommt ein blauer Kreis der verschwindet nicht mehr"
///   (#603). Es gab keinen Weg zurück in den Zustand „kein Tag
///   gewählt". Der Grund für die Festlegung trägt obendrein nicht: Der
///   Tipp öffnet das Eintragen des angetippten Tages direkt, also kommt
///   niemand in die Lage, über die Zeile am Fuß versehentlich auf heute
///   einzutragen, was gestern war.*
///
/// ## Was diese Datei vom Entwurf abweichend verlangt
///
/// Die Variante `keine-vorhersage` auf dem Board zeigt **keine**
/// Lagezeile. `CLAUDE.md` („Eine fehlende Anzeige sieht aus wie eine
/// Funktion, die es nicht gibt") und Spec 3.1 („die Ansicht sagt ‚noch
/// keine Vorhersage'") verlangen aber, dass der Grund sichtbar ist —
/// und `zyklus_texte.dart` hält die beiden Sätze dafür bereits bereit
/// ([zyklusKeineVorhersage], [zyklusKeineVorhersageGrund]). Diese Datei
/// verlangt deshalb die Lagezeile auch dort. **Der Entwurf ist im
/// selben Zug nachzuziehen** (`CLAUDE.md`, „jede beschlossene Änderung
/// wird im Entwurf nachgezogen").
///
/// ## Erfundene Daten
///
/// Jeder Tag, jede Blutung und jedes Symptom hier ist ausgedacht und
/// liegt im Jahr 2099. **Es steht kein einziger echter
/// Gesundheitswert im Quelltext** (`CLAUDE.md`, „Niemals tun") — und
/// erst recht keiner aus einem fremden Zyklus.
void main() {
  // 12:00 Berliner Zeit am 17.11.2099 (Winterzeit, UTC+1). Bewusst weit
  // weg von dem Tag, an dem dieser Test läuft: Nur so fällt auf, wenn
  // jemand `DateTime.now()` statt `clockProvider` benutzt.
  final jetzt = DateTime.utc(2099, 11, 17, 11);
  const heute = '2099-11-17';

  // Die drei erfundenen Perioden. Zwei abgeschlossene Zyklen (30 und 27
  // Tage) — die Mindestmenge für eine Vorhersage (Spec 3.1).
  const periodeA = ['2099-09-10', '2099-09-11', '2099-09-12', '2099-09-13',
    '2099-09-14'];
  const periodeB = ['2099-10-10', '2099-10-11', '2099-10-12', '2099-10-13',
    '2099-10-14'];
  const periodeC = ['2099-11-06', '2099-11-07', '2099-11-08', '2099-11-09'];

  const sexTag = '2099-11-14';
  const beschwerdeTag = '2099-11-15';

  /// Wonach ein „keine Daten"-Grund klingt. Während gelesen wird, darf
  /// nichts davon dastehen (`01`).
  final leerMuster = RegExp(
    r'noch keine|keine Vorhersage|keine Daten|nichts eingetragen|'
    r'nichts erfasst',
    caseSensitive: false,
  );

  final schirm = find.byKey(const Key('zyklus'));
  final legende = find.byKey(const Key('zyklus-legende'));
  final lage = find.byKey(const Key('zyklus-lage'));
  final eintragenZeile = find.byKey(const Key('zyklus-eintragen'));

  Finder zelle(String tag) => find.byWidgetPredicate(
    (widget) => widget is ZyklusZelle && widget.tag.tag == tag,
    description: 'ZyklusZelle für $tag',
  );

  late AppCache db;
  late ZyklusRepository repo;

  setUpAll(() async {
    await initializeDateFormatting('de_DE');
  });

  setUp(() async {
    db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);
    repo = ZyklusRepository(db, uhr: () => jetzt);
    // Der Kalender ist eingeschaltet — sonst gäbe es den Schirm nicht
    // (Spec 7). Das Einschalten selbst prüft „Zyklus einrichten" (#573).
    await repo.schreibeEinstellungen(
      ZyklusEinstellungen.vorbelegung.kopieMit(kalenderAn: true),
    );
  });

  /// Legt Blutungstage ab — am Schirm vorbei, wie eine frühere Sitzung.
  Future<void> legeBlutung(List<String> tage) async {
    for (final tag in tage) {
      await repo.schreibe(
        ZyklusEintrag(tag: tag, blutung: Blutungsstaerke.mittel),
      );
    }
  }

  /// Der Regelfall des Entwurfs: zwei abgeschlossene Zyklen, der dritte
  /// läuft, dazu ein Tag mit Sex und einer mit Beschwerden.
  Future<void> legeLaufendenZyklus() async {
    await legeBlutung([...periodeA, ...periodeB, ...periodeC]);
    await repo.schreibe(const ZyklusEintrag(tag: sexTag, sex: true));
    await repo.schreibe(
      const ZyklusEintrag(
        tag: beschwerdeTag,
        schmerz: Schmerzstaerke.leicht,
      ),
    );
  }

  /// Was der Kern aus demselben Datenstand rechnet. Die Zahlen werden
  /// hier **nicht noch einmal von Hand** hingeschrieben: Der Kern ist in
  /// `Packages/trainings_core/test/` geprüft, und diese Datei fragt, ob
  /// der Schirm **dasselbe** zeigt. Stünden die Tage hier doppelt, wäre
  /// bei der ersten Regeländerung einer der beiden Orte falsch.
  Zyklusvorhersage erwartet({
    List<String> blutungstage = const [],
    bool hormonell = false,
    bool pausiert = false,
  }) => zyklusVorhersage(
    perioden: periodenAus({
      for (final tag in blutungstage) tag: Blutungsstaerke.mittel,
    }),
    heute: heute,
    krankheitstage: const [],
    hormonell: hormonell,
    pausiert: pausiert,
  );

  ProviderContainer behaelter({ZyklusRepository? ersatz}) {
    final container = ProviderContainer(
      // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
      retry: (_, _) => null,
      overrides: [
        appCacheProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => jetzt),
        // Der Kalender fragt Apple Health nicht; die Attrappe steht
        // hier, damit ein Provider, der später einen Lauf dazubekommt,
        // nicht in `UnimplementedError` läuft.
        healthProvider.overrideWithValue(const HealthReadingAttrappe()),
        if (ersatz != null) zyklusRepositoryProvider.overrideWithValue(ersatz),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Der Gastgeber: der Kalender auf einem `Navigator`, der jeden Befehl
  /// des [AppRouter] schiebt — wie `RootView` es für den Stapel eines
  /// Tabs tut. So legt diese Datei keinen Weg über das Mehr-Menü fest
  /// (den gibt es erst mit #573), sondern nur den Schirm selbst.
  Future<GlobalKey<NavigatorState>> zeigeKalender(
    WidgetTester tester, {
    ProviderContainer? container,
    bool warten = true,
  }) async {
    // Ein hoher Schirm, damit Raster, Legende, Lage und die Zeile am Fuß
    // gleichzeitig aufgebaut und sichtbar sind.
    tester.view.physicalSize = const Size(900, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final navigator = GlobalKey<NavigatorState>();
    final router = AppRouter();
    void schiebe() {
      final befehl = router.nimmBefehl();
      if (befehl == null) return;
      navigator.currentState!.push(
        CupertinoPageRoute<void>(builder: befehl.builder),
      );
    }

    router.addListener(schiebe);
    addTearDown(() => router.removeListener(schiebe));

    await tester.pumpWidget(
      BehaelterImBaum(
        container: container ?? behaelter(),
        child: CupertinoApp(
          navigatorKey: navigator,
          home: ZyklusSeite(router: router),
        ),
      ),
    );
    if (warten) {
      await tester.pumpAndSettle();
      expect(schirm, findsOneWidget, reason: 'Der Kalender steht.');
    }
    return navigator;
  }

  /// Alle Texte des Baums, zusammengefügt, Leerraum vereinheitlicht.
  String alleTexte(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map(textOf)
      .join(' ')
      .replaceAll(RegExp(r'\s+'), ' ');

  /// Ob irgendwo auf dem Schirm dieser Text steht — **ohne Rücksicht
  /// auf Groß- und Kleinschreibung**: `HilfeKopf` und `SectionHeader`
  /// setzen Überschriften in Versalien, und das ist eine Gestaltung,
  /// kein Inhalt.
  bool nennt(WidgetTester tester, String text) =>
      alleTexte(tester).toUpperCase().contains(text.toUpperCase());

  /// Was der Schirm dieser Zelle übergeben hat.
  ZyklusTag imRaster(WidgetTester tester, String tag) =>
      tester.widget<ZyklusZelle>(zelle(tag)).tag;

  /// Alle Tage eines Monats, die im Raster stehen — `monat` ist das
  /// Präfix des Tagesschlüssels, etwa `2099-11`.
  List<ZyklusTag> tageDesMonats(WidgetTester tester, String monat) => [
    for (final z in tester.widgetList<ZyklusZelle>(find.byType(ZyklusZelle)))
      if (z.tag.tag.startsWith(monat)) z.tag,
  ];

  /// Die Zustände, die eine Vorhersage ausmachen — hell gefüllt,
  /// gepunktet, türkis. Ohne Vorhersage darf keiner davon dastehen.
  const gerechnet = {
    ZyklusTagZustand.vorhergesagt,
    ZyklusTagZustand.rand,
    ZyklusTagZustand.eisprung,
    ZyklusTagZustand.fruchtbar,
  };

  /// Jeder Tag eines Fensters, beide Ränder einschließlich.
  ///
  /// Reine Kalenderrechnung auf Jahr, Monat, Tag — kein Zeitpunkt, keine
  /// Zeitzone: Ein Tag ist hier eine Kalenderangabe (`CLAUDE.md`).
  List<String> tageIn(Zyklusfenster fenster) {
    String alsTag(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';

    var datum = DateTime.utc(
      int.parse(fenster.von.substring(0, 4)),
      int.parse(fenster.von.substring(5, 7)),
      int.parse(fenster.von.substring(8, 10)),
    );
    final tage = <String>[];
    while (alsTag(datum).compareTo(fenster.bis) <= 0) {
      tage.add(alsTag(datum));
      datum = DateTime.utc(datum.year, datum.month, datum.day + 1);
    }
    return tage;
  }

  // ───────────────────────────────────────────────────────────────────
  // Der laufende Zyklus (Entwurf, Variante `laufend`)
  // ───────────────────────────────────────────────────────────────────

  group('Laufender Zyklus', () {
    testWidgets('die eingetragenen Tage stehen gefüllt, der Rest des '
        'Monats leer', (tester) async {
      await legeLaufendenZyklus();
      await zeigeKalender(tester);

      for (final tag in periodeC) {
        expect(
          imRaster(tester, tag).zustand,
          ZyklusTagZustand.eingetragen,
          reason:
              '$tag: gefüllt heißt eingetragen. Was die Nutzerin selbst '
              'abgelegt hat, ist keine Schätzung',
        );
      }
      expect(
        imRaster(tester, '2099-11-02').zustand,
        isNull,
        reason:
            'ein Tag ohne Eintrag und ohne Vorhersage trägt keinen '
            'Zustand — und verschwindet trotzdem nicht aus dem Raster',
      );
    });

    testWidgets('die Vorhersage ist zu sehen: Eisprung und fruchtbares '
        'Fenster stehen da, wo der Kern sie rechnet', (tester) async {
      await legeLaufendenZyklus();
      final rechnung = erwartet(
        blutungstage: [...periodeA, ...periodeB, ...periodeC],
      );
      await zeigeKalender(tester);

      expect(
        rechnung.eisprung,
        isNotNull,
        reason: 'Vorbedingung: zwei abgeschlossene Zyklen reichen (Spec 3.1)',
      );
      expect(
        imRaster(tester, rechnung.eisprung!).zustand,
        ZyklusTagZustand.eisprung,
        reason:
            'der geschätzte Eisprung liegt im Tag, nicht darunter — und '
            'er steht an dem Tag, den der Kern nennt, nicht an einem, den '
            'der Schirm selbst gerechnet hat',
      );
      for (final tag in tageIn(rechnung.fruchtbar!)) {
        if (tag == rechnung.eisprung) continue;
        expect(
          imRaster(tester, tag).zustand,
          ZyklusTagZustand.fruchtbar,
          reason: '$tag gehört zum geschätzten fruchtbaren Fenster',
        );
      }
    });

    testWidgets('der Zyklustag steht ab dem letzten Periodenstart', (
      tester,
    ) async {
      await legeLaufendenZyklus();
      final perioden = periodenAus({
        for (final tag in [...periodeA, ...periodeB, ...periodeC])
          tag: Blutungsstaerke.mittel,
      });
      await zeigeKalender(tester);

      expect(
        imRaster(tester, periodeC.first).zyklustag,
        1,
        reason: 'Tag 1 ist der erste Tag der laufenden Periode (Spec 1)',
      );
      expect(
        imRaster(tester, heute).zyklustag,
        zyklustagAm(heute, perioden),
        reason:
            'die Zahl, nach der in jedem Arztgespräch gefragt wird — sie '
            'kommt aus dem Kern, nicht aus einer zweiten Rechnung im '
            'Schirm',
      );
    });

    testWidgets('was eingetragen ist, hängt unter dem Tag', (tester) async {
      await legeLaufendenZyklus();
      await zeigeKalender(tester);

      expect(
        imRaster(tester, sexTag).marken,
        contains(ZyklusMarke.sex),
        reason: 'ein Herz für Sex — was eingetragen ist, hängt darunter',
      );
      expect(
        imRaster(tester, beschwerdeTag).marken,
        contains(ZyklusMarke.notiz),
        reason: 'ein Punkt für Schmerzen oder Symptome',
      );
      expect(
        imRaster(tester, '2099-11-02').marken,
        isEmpty,
        reason: 'ein Tag ohne Eintrag trägt keine Marke',
      );
    });

    testWidgets('heute ist als heute gekennzeichnet, und zwar der Tag aus '
        'clockProvider', (tester) async {
      await legeLaufendenZyklus();
      await zeigeKalender(tester);

      expect(imRaster(tester, heute).heute, isTrue);
      expect(
        tageDesMonats(tester, '2099-11').where((t) => t.heute),
        hasLength(1),
        reason: 'genau ein Tag ist heute',
      );
    });

    testWidgets('die Legende steht, eine Lagezeile gibt es nicht', (
      tester,
    ) async {
      await legeLaufendenZyklus();
      await zeigeKalender(tester);

      expect(
        legende,
        findsOneWidget,
        reason:
            'sie schließt das Raster nach unten ab und ist die eine '
            'Erklärung, die nicht hinter das Fragezeichen wandert',
      );
      expect(
        lage,
        findsNothing,
        reason:
            'es gibt keine Lage zu melden: Die Vorhersage läuft. Eine '
            'Zeile, die immer dasteht, sagt nichts mehr',
      );
    });

    testWidgets('der Kalender steht auf dem Monat der Uhr', (tester) async {
      await legeLaufendenZyklus();
      await zeigeKalender(tester);

      expect(
        tageDesMonats(tester, '2099-11'),
        hasLength(30),
        reason:
            'November 2099 hat dreißig Tage, und jede Zelle ist immer '
            'vorhanden — sonst springt das Raster',
      );
    });
  });

  // ───────────────────────────────────────────────────────────────────
  // Noch keine Vorhersage (Entwurf, Variante `keine-vorhersage`)
  // ───────────────────────────────────────────────────────────────────

  group('Noch keine Vorhersage', () {
    testWidgets('das Raster behält seine Form, und nichts ist hell oder '
        'gepunktet', (tester) async {
      await legeBlutung(periodeC);
      await zeigeKalender(tester);

      expect(
        tageDesMonats(tester, '2099-11'),
        hasLength(30),
        reason:
            'dieselbe Höhe, dieselbe Breite, dieselbe Stelle — nur die '
            'Füllung unterscheidet sich (`CLAUDE.md`)',
      );
      for (final tag in tageDesMonats(tester, '2099-11')) {
        expect(
          gerechnet.contains(tag.zustand),
          isFalse,
          reason:
              '${tag.tag}: Ein Zyklus allein reicht für keinen Median. '
              'Geraten wird nicht (Spec 3.1)',
        );
      }
      for (final tag in periodeC) {
        expect(
          imRaster(tester, tag).zustand,
          ZyklusTagZustand.eingetragen,
          reason: 'eingetragen wird ab dem ersten Tag — und steht auch da',
        );
      }
    });

    testWidgets('der Grund ist sichtbar', (tester) async {
      await legeBlutung(periodeC);
      await zeigeKalender(tester);

      expect(
        lage,
        findsOneWidget,
        reason:
            'eine fehlende Anzeige sieht aus wie eine Funktion, die es '
            'nicht gibt (`CLAUDE.md`). Spec 3.1: „die Ansicht sagt ‚noch '
            'keine Vorhersage‘"',
      );
      expect(nennt(tester, zyklusKeineVorhersage), isTrue);
      expect(
        nennt(tester, zyklusKeineVorhersageGrund),
        isTrue,
        reason:
            'der Satz steht fertig in `zyklus_texte.dart` — er sagt, '
            'woran es liegt, statt es die Nutzerin raten zu lassen',
      );
    });

    testWidgets('ohne jeden Eintrag steht derselbe Schirm, nur ungefüllt', (
      tester,
    ) async {
      await zeigeKalender(tester);

      expect(tageDesMonats(tester, '2099-11'), hasLength(30));
      expect(legende, findsOneWidget);
      expect(
        eintragenZeile,
        findsOneWidget,
        reason: 'eintragen geht ab dem ersten Tag',
      );
      for (final tag in tageDesMonats(tester, '2099-11')) {
        expect(tag.zustand, isNull);
        expect(tag.marken, isEmpty);
      }
    });
  });

  // ───────────────────────────────────────────────────────────────────
  // Nächster Monat (Entwurf, Variante `vorhersage`)
  // ───────────────────────────────────────────────────────────────────

  group('Geblättert', () {
    testWidgets('der nächste Monat zeigt das Kernfenster und seinen Rand', (
      tester,
    ) async {
      await legeLaufendenZyklus();
      final rechnung = erwartet(
        blutungstage: [...periodeA, ...periodeB, ...periodeC],
      );
      await zeigeKalender(tester);

      await tester.tap(find.bySemanticsLabel('Nächster Monat'));
      await tester.pumpAndSettle();

      expect(
        tester
            .widgetList<ZyklusMonat>(find.byType(ZyklusMonat))
            .any((m) => m.monat.contains('Dezember')),
        isTrue,
        reason: 'ein Monat, geblättert — nicht ein endloser Streifen',
      );
      for (final tag in tageIn(rechnung.kern!)) {
        expect(
          imRaster(tester, tag).zustand,
          ZyklusTagZustand.vorhergesagt,
          reason: '$tag liegt im Kernfenster der nächsten Blutung',
        );
      }
      for (final tag in [
        ...tageIn(rechnung.randVor!),
        ...tageIn(rechnung.randNach!),
      ]) {
        expect(
          imRaster(tester, tag).zustand,
          ZyklusTagZustand.rand,
          reason:
              '$tag gehört zum Unsicherheitsband — es behauptet keinen '
              'Tag, sondern einen Bereich',
        );
      }
    });
  });

  // ───────────────────────────────────────────────────────────────────
  // Unter hormoneller Verhütung (Entwurf, Variante `pille`)
  // ───────────────────────────────────────────────────────────────────

  group('Unter hormoneller Verhütung', () {
    Future<void> legeVerhuetung() => repo.schreibeEinstellungen(
      ZyklusEinstellungen.vorbelegung.kopieMit(
        kalenderAn: true,
        verhuetungAn: true,
        verhuetungSeit: '2099-09-01',
        verhuetungArt: 'pruefart',
      ),
    );

    testWidgets('die Fruchtbarkeitszeichen stehen blass, die Blutung '
        'nicht', (tester) async {
      await legeLaufendenZyklus();
      await legeVerhuetung();
      await zeigeKalender(tester);

      for (final monat in tester.widgetList<ZyklusMonat>(
        find.byType(ZyklusMonat),
      )) {
        expect(
          monat.blaesse,
          ZyklusBlaesse.fruchtbarkeitBlass,
          reason:
              'zurückgenommen ist allein die Fruchtbarkeit. Die Blutung '
              'folgt unter Pille dem Einnahmeschema und ist sogar '
              'regelmäßiger als sonst (Spec 3.7, Tim am 23.11.2026)',
        );
      }
      for (final tag in periodeC) {
        expect(
          imRaster(tester, tag).zustand,
          ZyklusTagZustand.eingetragen,
          reason:
              '$tag: ein eingetragener Wert wird nicht blass dargestellt '
              '— er wurde tatsächlich eingetragen',
        );
      }
    });

    testWidgets('kein Tag wird als sicher dargestellt: die '
        'Fruchtbarkeitszeichen bleiben stehen', (tester) async {
      await legeLaufendenZyklus();
      await legeVerhuetung();
      final rechnung = erwartet(
        blutungstage: [...periodeA, ...periodeB, ...periodeC],
        hormonell: true,
      );
      await zeigeKalender(tester);

      expect(
        rechnung.sicherheit,
        Fruchtbarkeitssicherheit.unterHormonellerVerhuetung,
        reason: 'Vorbedingung',
      );
      expect(
        imRaster(tester, rechnung.eisprung!).zustand,
        ZyklusTagZustand.eisprung,
        reason:
            'wer unter Pille gar nichts zeigt, behauptet stillschweigend '
            'Schutz an jedem Tag (Spec 3.7, Tims Einwand vom 23.11.2026)',
      );
    });

    testWidgets('ohne Verhütung ist nichts blass', (tester) async {
      await legeLaufendenZyklus();
      await zeigeKalender(tester);

      for (final monat in tester.widgetList<ZyklusMonat>(
        find.byType(ZyklusMonat),
      )) {
        expect(monat.blaesse, ZyklusBlaesse.voll);
      }
    });
  });

  // ───────────────────────────────────────────────────────────────────
  // Test positiv (Entwurf, Variante `test-positiv`)
  // ───────────────────────────────────────────────────────────────────

  group('Nach einem positiven Schwangerschaftstest', () {
    Future<void> legeTest() => repo.schreibe(
      const ZyklusEintrag(
        tag: beschwerdeTag,
        test: Testergebnis.positiv,
      ),
    );

    testWidgets('die Vorhersage pausiert — kein Tag ist mehr hell, '
        'gepunktet oder türkis', (tester) async {
      await legeLaufendenZyklus();
      await legeTest();
      await zeigeKalender(tester);

      for (final tag in tageDesMonats(tester, '2099-11')) {
        expect(
          gerechnet.contains(tag.zustand),
          isFalse,
          reason:
              '${tag.tag}: „Blutung in 3 Tagen" wäre hier selbst eine '
              'falsche Auskunft (Spec 3.8)',
        );
      }
      for (final tag in periodeC) {
        expect(
          imRaster(tester, tag).zustand,
          ZyklusTagZustand.eingetragen,
          reason: 'was eingetragen ist, bleibt stehen — pausiert ist nur '
              'die Vorhersage',
        );
      }
    });

    testWidgets('die Lagezeile nennt den Grund und den Tag des Tests', (
      tester,
    ) async {
      await legeLaufendenZyklus();
      await legeTest();
      await zeigeKalender(tester);

      expect(lage, findsOneWidget);
      expect(nennt(tester, zyklusPausiertLeitwort), isTrue);
      expect(
        nennt(tester, '15.'),
        isTrue,
        reason:
            'der Tag des Tests steht da — „seit dem positiven Test am '
            '15. November". Welches Format, entscheidet die Ansicht; '
            'dass es der richtige Tag ist, nicht',
      );
      expect(nennt(tester, 'November'), isTrue);
      expect(
        nennt(tester, 'ärztliche'),
        isTrue,
        reason:
            'keine Diagnosen (`CLAUDE.md`): Was der Test bedeutet, klärt '
            'eine ärztliche Praxis — die App deutet nichts',
      );
    });

    testWidgets('die Lagezeile steht unter der Legende, nicht über dem '
        'Raster', (tester) async {
      await legeLaufendenZyklus();
      await legeTest();
      await zeigeKalender(tester);

      expect(
        tester.getTopLeft(lage).dy,
        greaterThan(tester.getTopLeft(legende).dy),
        reason:
            'oben drängte sie sich vor das Bild, um das es geht, und '
            'schob das Raster nach unten (Tim, 23.11.2026). Eine '
            'Reihenfolge, keine Gestaltung',
      );
    });

    testWidgets('eingetragen wird weiter', (tester) async {
      await legeLaufendenZyklus();
      await legeTest();
      await zeigeKalender(tester);

      expect(eintragenZeile, findsOneWidget);
      await tester.tap(eintragenZeile);
      await tester.pumpAndSettle();

      expect(
        find.byType(ZyklusTagSeite),
        findsOneWidget,
        reason: 'die Pause hält die Vorhersage an, nicht das Eintragen',
      );
    });
  });

  // ───────────────────────────────────────────────────────────────────
  // Jeder Tag ist eine Tür
  // ───────────────────────────────────────────────────────────────────

  group('Jeder Tag ist eine Tür', () {
    testWidgets('ein Tipp auf einen vergangenen Tag öffnet das Eintragen '
        'für genau diesen Tag', (tester) async {
      await legeLaufendenZyklus();
      await zeigeKalender(tester);

      await tester.tap(zelle(sexTag));
      await tester.pumpAndSettle();

      expect(find.byType(ZyklusTagSeite), findsOneWidget);
      expect(
        tester.widget<ZyklusTagSeite>(find.byType(ZyklusTagSeite)).tag,
        sexTag,
        reason:
            'so trägt man nach, was man gestern vergessen hat (Tim, '
            '23.11.2026) — und zwar auf den Tag, den man angetippt hat',
      );
    });

    testWidgets('vor dem ersten Tipp nennt die Zeile am Fuß heute', (
      tester,
    ) async {
      await legeLaufendenZyklus();
      await zeigeKalender(tester);

      expect(
        nennt(tester, zyklusEintragenTitel),
        isTrue,
        reason: 'ohne Wahl ist heute gemeint',
      );
    });

    // Die beiden folgenden Fälle standen bis zum 24.11.2026 auf dem
    // Kopf: Sie hielten fest, dass der angetippte Tag gewählt **bleibt**
    // — türkiser Ring in der Zelle, Datum statt „Heute" in der Zeile am
    // Fuß. Das war eine Festlegung dieses Test-Agenten (Dateikopf), nicht
    // Tims, und Tim hat sie am Gerät als Fehler gemeldet: „beim Drücken
    // auf einen Tag kommt ein blauer Kreis der verschwindet nicht mehr"
    // (#603). Der Ring ließ sich nicht wieder loswerden — es gab keinen
    // Weg zurück in den Zustand „kein Tag gewählt".
    //
    // Darum halten sie jetzt das Gegenteil fest. Was die Auswahl
    // verhindern sollte, verhindert der Fall oben schon: Der Tipp öffnet
    // das Eintragen des angetippten Tages unmittelbar, also kommt
    // niemand in die Lage, über die Zeile am Fuß den falschen Tag zu
    // erwischen.
    testWidgets('ein Tipp markiert keinen Tag — nach der Rückkehr steht '
        'das Raster da wie vorher', (tester) async {
      await legeLaufendenZyklus();
      final navigator = await zeigeKalender(tester);

      final vorher = tageDesMonats(tester, '2099-11');

      await tester.tap(zelle(sexTag));
      await tester.pumpAndSettle();
      navigator.currentState!.pop();
      await tester.pumpAndSettle();

      expect(
        tageDesMonats(tester, '2099-11'),
        vorher,
        reason:
            'ein Tipp ist eine Tür, keine Wahl. Eine Markierung, die '
            'nichts wieder aufhebt, ist ein Zustand ohne Ausweg (Tim am '
            'Gerät, #603)',
      );
      expect(
        nennt(tester, zyklusEintragenTitel),
        isTrue,
        reason: 'die Zeile am Fuß meint weiter heute',
      );
    });

    testWidgets('die Zeile am Fuß öffnet heute, auch nachdem ein anderer '
        'Tag angetippt war', (tester) async {
      await legeLaufendenZyklus();
      final navigator = await zeigeKalender(tester);

      await tester.tap(zelle(sexTag));
      await tester.pumpAndSettle();
      navigator.currentState!.pop();
      await tester.pumpAndSettle();

      await tester.tap(eintragenZeile);
      await tester.pumpAndSettle();

      expect(
        tester.widget<ZyklusTagSeite>(find.byType(ZyklusTagSeite)).tag,
        heute,
        reason:
            'die Zeile heißt „Heute eintragen" — dann trägt sie auch auf '
            'heute ein. Das Eintragen bleibt über jeden Tag erreichbar, '
            'über seine Zelle',
      );
    });

    testWidgets('ohne Wahl öffnet die Zeile am Fuß den heutigen Tag', (
      tester,
    ) async {
      await legeLaufendenZyklus();
      await zeigeKalender(tester);

      await tester.tap(eintragenZeile);
      await tester.pumpAndSettle();

      expect(
        tester.widget<ZyklusTagSeite>(find.byType(ZyklusTagSeite)).tag,
        heute,
        reason: 'heute kommt aus clockProvider, nicht aus DateTime.now()',
      );
    });
  });

  // ───────────────────────────────────────────────────────────────────
  // Während des Lesens steht kein „keine Daten"-Grund (`01`)
  // ───────────────────────────────────────────────────────────────────

  group('Während des Lesens steht kein „keine Daten"-Grund (`01`)', () {
    testWidgets('das Raster steht schon da, der Grund nicht', (tester) async {
      final antwort = Completer<void>();
      await zeigeKalender(
        tester,
        container: behaelter(ersatz: _HaengendesRepo(db, antwort)),
        warten: false,
      );
      // Kein `pumpAndSettle`: Ein Ladezeichen, das sich dreht, käme nie
      // zur Ruhe. Eine Sekunde reicht für den Aufbau.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(schirm, findsOneWidget, reason: 'Der Schirm steht, er lädt nur.');
      expect(
        tageDesMonats(tester, '2099-11'),
        hasLength(30),
        reason:
            'der Ladezustand ist kein Leerstand: Ein Monat hat seine Tage, '
            'bevor irgendetwas gelesen ist',
      );
      for (final text in tester.widgetList<Text>(find.byType(Text))) {
        expect(
          leerMuster.hasMatch(textOf(text)),
          isFalse,
          reason:
              'Text „${textOf(text)}" nennt einen „keine Daten"-Grund, '
              'während noch gelesen wird — das ist Fehler `01`, wortgleich '
              'im neuen Code',
        );
      }

      antwort.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('erst wenn der Lauf fertig ist, darf er sagen, dass nichts '
        'da ist', (tester) async {
      final antwort = Completer<void>();
      await zeigeKalender(
        tester,
        container: behaelter(ersatz: _HaengendesRepo(db, antwort)),
        warten: false,
      );
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      antwort.complete();
      await tester.pumpAndSettle();

      expect(schirm, findsOneWidget);
      expect(tageDesMonats(tester, '2099-11'), hasLength(30));
      expect(
        nennt(tester, zyklusKeineVorhersage),
        isTrue,
        reason:
            'jetzt steht fest, dass nichts vorliegt — und jetzt darf es '
            'auch dastehen',
      );
    });

    testWidgets('ein Lesefehler ist kein Leerstand', (tester) async {
      await zeigeKalender(
        tester,
        container: behaelter(ersatz: _KaputtesRepo(db)),
      );

      expect(
        schirm,
        findsOneWidget,
        reason: 'ein Schirm, der bei einem Lesefehler verschwindet, sieht '
            'aus wie ein Absturz',
      );
      expect(
        tageDesMonats(tester, '2099-11'),
        hasLength(30),
        reason: 'das Raster behält seine Form, egal was schiefgeht',
      );
      for (final text in tester.widgetList<Text>(find.byType(Text))) {
        expect(
          leerMuster.hasMatch(textOf(text)),
          isFalse,
          reason:
              'Text „${textOf(text)}" behauptet, es lägen keine Daten vor '
              '— dabei ließen sie sich nur nicht lesen. Das sind zwei '
              'verschiedene Auskünfte (`CLAUDE.md`, LeerNachLauf gegen '
              'Fehlgeschlagen)',
        );
      }
    });
  });

  // ───────────────────────────────────────────────────────────────────
  // Ein Wert, der dastand, steht wieder da (`32`)
  // ───────────────────────────────────────────────────────────────────

  group('Ein Wert, der dastand, steht nach dem Zurücknavigieren wieder da '
      '(`32`)', () {
    testWidgets('hinein ins Eintragen, zurück — das Raster trägt dieselben '
        'Tage', (tester) async {
      await legeLaufendenZyklus();
      final navigator = await zeigeKalender(tester);
      final vorher = tageDesMonats(tester, '2099-11');

      await tester.tap(zelle(sexTag));
      await tester.pumpAndSettle();
      navigator.currentState!.pop();
      await tester.pumpAndSettle();

      final nachher = tageDesMonats(tester, '2099-11');
      expect(nachher, hasLength(vorher.length));
      for (final tag in periodeC) {
        expect(
          imRaster(tester, tag).zustand,
          ZyklusTagZustand.eingetragen,
          reason:
              '$tag war gefüllt, bevor navigiert wurde — er ist es '
              'danach. Genau das ist `32`',
        );
      }
      expect(imRaster(tester, sexTag).marken, contains(ZyklusMarke.sex));
    });

    testWidgets('ein Tag, der am Schirm vorbei dazukommt, steht beim '
        'nächsten Aufbau im Raster', (tester) async {
      await legeLaufendenZyklus();
      final navigator = await zeigeKalender(tester);

      await tester.tap(zelle('2099-11-02'));
      await tester.pumpAndSettle();
      await repo.schreibe(
        const ZyklusEintrag(
          tag: '2099-11-02',
          blutung: Blutungsstaerke.leicht,
        ),
      );
      navigator.currentState!.pop();
      await tester.pumpAndSettle();

      expect(
        imRaster(tester, '2099-11-02').zustand,
        ZyklusTagZustand.eingetragen,
        reason:
            'der Kalender liest seine Daten selbst und beim Zurückkommen '
            'neu — ein Schirm, der einen abgelegten Tag nicht zeigt, '
            'behauptet, es gäbe ihn nicht',
      );
    });
  });

  // ───────────────────────────────────────────────────────────────────
  // Was Tim am Gerät gefunden hat (#601)
  //
  // Drei Funde vom 24.11.2026, jeder als eigener Fall. Sie prüfen
  // weiter **Zustände und Übergänge**, nicht Gestaltung: dass man aus
  // einem Monat wieder herauskommt, dass die Zeilenhöhe nicht an der
  // Gerätebreite hängt, und dass heute im Raster eine Markierung trägt
  // — welche, bleibt der Umsetzung überlassen.
  // ───────────────────────────────────────────────────────────────────

  /// Tippt auf einen Monatspfeil, **ohne Warnung, wenn er nicht
  /// trifft**: Ein ausgeschalteter Pfeil nimmt den Tipp nicht an, und
  /// genau das ist hier die Frage — kein Fehler im Test.
  Future<void> tippePfeil(WidgetTester tester, String label) async {
    await tester.tapAt(tester.getCenter(find.bySemanticsLabel(label)));
    await tester.pumpAndSettle();
  }

  /// Wie viele sichtbare Formen eine Zelle malt — jede Fläche und jeder
  /// Rand zählt eine. **Keine Farbe, kein Maß:** Gezählt wird nur, ob
  /// überhaupt etwas da ist.
  int sichtbareFormen(WidgetTester tester, String tag) => tester
      .widgetList<Container>(
        find.descendant(of: zelle(tag), matching: find.byType(Container)),
      )
      .where((behaelter) {
        final schmuck = behaelter.decoration;
        return schmuck is BoxDecoration &&
            (schmuck.color != null || schmuck.border != null);
      })
      .length;

  group('Aus dem Kalender führt ein Weg zurück (#601)', () {
    testWidgets('ohne Vorhersage kommt man aus dem vorigen Monat wieder '
        'heraus', (tester) async {
      await legeBlutung(periodeC);
      await zeigeKalender(tester);

      expect(
        erwartet(blutungstage: periodeC).grund,
        VorhersageGrund.zuWenigDaten,
        reason:
            'Vorbedingung: ein Zyklus allein reicht für keinen Median — '
            'der Normalfall für jede neue Nutzerin',
      );

      await tippePfeil(tester, 'Voriger Monat');
      expect(
        tageDesMonats(tester, '2099-10'),
        hasLength(31),
        reason: 'Vorbedingung: zurück geht es',
      );

      await tippePfeil(tester, 'Nächster Monat');
      expect(
        tageDesMonats(tester, '2099-11'),
        hasLength(30),
        reason:
            'wer zurückblättert, muss wieder herauskommen. Hängt der '
            'Pfeil an der Vorhersage statt an der Stelle im Kalender, '
            'ist der vorige Monat eine Sackgasse',
      );
    });

    testWidgets('auch ohne jeden Eintrag lässt sich hin und her blättern', (
      tester,
    ) async {
      await zeigeKalender(tester);

      await tippePfeil(tester, 'Nächster Monat');
      expect(
        tageDesMonats(tester, '2099-12'),
        hasLength(31),
        reason:
            'ein Monat ohne Vorhersage ist kein Grund, den Weg zu '
            'versperren: Die Zellen stehen da und lassen sich füllen',
      );

      await tippePfeil(tester, 'Voriger Monat');
      expect(tageDesMonats(tester, '2099-11'), hasLength(30));
    });
  });

  group('Das Raster wächst nicht mit der Bildschirmbreite (#601)', () {
    testWidgets('die Zeilenhöhe bleibt dieselbe, egal wie breit der Schirm '
        'ist', (tester) async {
      await legeLaufendenZyklus();
      await zeigeKalender(tester);

      double zellenhoehe() => tester.getSize(zelle(heute)).height;
      double rasterhoehe() =>
          tester.getRect(zelle('2099-11-30')).bottom -
          tester.getRect(zelle('2099-11-01')).top;

      final zelleBreit = zellenhoehe();
      final rasterBreit = rasterhoehe();

      // Derselbe Schirm, schmaler — ein iPhone statt der Fläche, auf der
      // diese Datei sonst aufbaut.
      tester.view.physicalSize = const Size(400, 2600);
      await tester.pumpAndSettle();

      expect(
        zellenhoehe(),
        zelleBreit,
        reason:
            'die Zelle hat eine feste Höhe. Hängt die Zeilenhöhe am '
            'Seitenverhältnis, wächst der Weißraum mit dem Gerät',
      );
      expect(
        rasterhoehe(),
        rasterBreit,
        reason:
            'und mit ihm der ganze Monat — dann rutscht die Zeile am Fuß '
            'nach unten aus dem Bild (Tim am Gerät, 24.11.2026)',
      );
    });

    testWidgets('das Raster trägt keinen eigenen Innenabstand', (
      tester,
    ) async {
      await legeLaufendenZyklus();
      await zeigeKalender(tester);

      // Der erste Tag des Monats ist ein Sonntag, liegt also in der
      // ersten Zeile — seine Oberkante **ist** die Oberkante des
      // Rasters, wenn das Raster keinen Innenabstand hat.
      final raster = tester.getRect(find.byType(GridView));
      final ersteZeile = tester.getRect(zelle('2099-11-01'));

      expect(
        ersteZeile.top,
        raster.top,
        reason:
            'Ein ScrollView ohne eigenes `padding` übernimmt die '
            'MediaQuery-SafeArea als Innenabstand — oben die '
            'Navigationsleiste, unten den Home-Indikator. Der Weissraum '
            'sitzt dann **im** Raster und wächst mit der Gerätekante. '
            'Gemessen auf dem iPhone 17 Pro: Rasteranfang 100, erste '
            'Zelle 144 (Tim am Gerät, 24.11.2026). Nachgetragen mit '
            '`TEST_AENDERN=1`; **Tim hat die Änderung nicht gesehen.**',
      );
      expect(
        raster.bottom - raster.top,
        tester.getRect(zelle('2099-11-30')).bottom - ersteZeile.top,
        reason:
            'und unten genauso — sonst steht die Legende tiefer, als '
            'das Raster reicht',
      );
    });
  });

  group('Heute ist im Raster zu erkennen (#601)', () {
    const nachbar = '2099-11-16';

    testWidgets('heute trägt eine Markierung, die ein gleichartiger '
        'Nachbartag nicht trägt', (tester) async {
      await legeBlutung(periodeC);
      await zeigeKalender(tester);

      expect(imRaster(tester, heute).heute, isTrue);
      expect(imRaster(tester, nachbar).heute, isFalse);
      expect(
        imRaster(tester, heute).zustand,
        imRaster(tester, nachbar).zustand,
        reason:
            'Vorbedingung: beide Tage tragen denselben Zustand — sie '
            'unterscheiden sich allein darin, dass einer heute ist',
      );
      expect(imRaster(tester, heute).zyklustag, isNotNull);
      expect(
        imRaster(tester, nachbar).zyklustag,
        isNotNull,
        reason: 'Vorbedingung: beide tragen eine Plakette',
      );

      expect(
        sichtbareFormen(tester, heute),
        greaterThan(sichtbareFormen(tester, nachbar)),
        reason:
            'eine fette Ziffer unter dreißig Ziffern sieht man nicht '
            '(Tim am Gerät, 24.11.2026). Welche Form die Markierung '
            'hat, bleibt offen — dass es eine gibt, nicht',
      );
    });

    testWidgets('der Vorlesetext nennt heute weiterhin beim Namen', (
      tester,
    ) async {
      await legeBlutung(periodeC);
      await zeigeKalender(tester);

      expect(
        find.bySemanticsLabel(RegExp(r'^17\.,\s*heute')),
        findsOneWidget,
        reason:
            'der Vorlesetext nennt den Zustand, nicht das Zeichen '
            '(`CLAUDE.md`) — eine Markierung, die nur zu sehen ist, '
            'erreicht VoiceOver nicht',
      );
    });
  });

  // ───────────────────────────────────────────────────────────────────
  // Ein hinterlegter Test färbt den Tag (#598)
  //
  // Tim am 24.11.2026: „wenn man nen test hinterlegt kann man das ja so
  // grau machen, wie wenn man seine tage hat in rot — aber sonst ist es
  // ein leerer tag ja, da ist ja sonst nix."
  //
  // Drei Aussagen stecken darin, und jede bekommt hier einen Fall:
  //
  //  1. Ein Tag mit Schwangerschaftstest — **egal ob positiv oder
  //     negativ** — trägt eine Markierung im Tag, so wie ein
  //     Blutungstag eine trägt.
  //  2. Ein Tag mit bloßer Notiz bleibt leer. Ausdrücklich so gewollt.
  //  3. Eine Zwischenblutung ohne Stärke bleibt ebenfalls unmarkiert.
  //
  // Dazu kommt der Konflikt, den die Entscheidung aufmacht: Seit #601
  // trägt **heute** selbst eine neutrale Markierung. Zwei verschiedene
  // Auskünfte dürfen nicht dieselbe Form haben, also muss ein Tag, der
  // heute **und** Test ist, mehr zeigen als einer, der nur Test ist.
  //
  // Wie das aussieht, legt kein Fall hier fest — **Zustände und
  // Übergänge, nicht Gestaltung** (`CLAUDE.md`). Gezählt wird nur, ob
  // überhaupt etwas da ist, mit demselben [sichtbareFormen] wie bei
  // #601.
  // ───────────────────────────────────────────────────────────────────

  group('Ein hinterlegter Test färbt den Tag (#598)', () {
    const testTag = '2099-11-13';
    const notizTag = '2099-11-12';
    const leerTag = '2099-11-11';

    /// Ein Zyklus, ein Test, eine bloße Notiz — und ein Tag daneben, an
    /// dem gar nichts steht.
    ///
    /// **Ein Zyklus allein reicht für keine Vorhersage** (Spec 3.1):
    /// Die drei Tage tragen deshalb keinen gerechneten Zustand und
    /// unterscheiden sich allein darin, was eingetragen ist.
    Future<void> legeTestUndNotiz({
      Testergebnis ergebnis = Testergebnis.negativ,
    }) async {
      await legeBlutung(periodeC);
      await repo.schreibe(ZyklusEintrag(tag: testTag, test: ergebnis));
      await repo.schreibe(
        const ZyklusEintrag(tag: notizTag, notiz: 'nur ein Gedanke'),
      );
    }

    testWidgets('ein Tag mit Test trägt ihn, und er ist zu sehen', (
      tester,
    ) async {
      await legeTestUndNotiz();
      await zeigeKalender(tester);

      expect(
        imRaster(tester, testTag).zustand,
        isNull,
        reason:
            'der Test ist ein Eintrag, kein Zustand: Ein Tag kann '
            'Blutung und Test zugleich tragen, und was die Nutzerin '
            'eingetragen hat, verschiebt keine Vorhersage',
      );
      expect(
        sichtbareFormen(tester, testTag),
        greaterThan(sichtbareFormen(tester, leerTag)),
        reason:
            'ein Tag, an dem etwas abgelegt ist und nichts zu sehen, '
            'sieht aus wie ein verlorener Eintrag (Tim, 24.11.2026)',
      );
    });

    testWidgets('ein positiver Test wird genauso markiert wie ein '
        'negativer', (tester) async {
      await legeTestUndNotiz(ergebnis: Testergebnis.positiv);
      await zeigeKalender(tester);

      expect(
        sichtbareFormen(tester, testTag),
        greaterThan(sichtbareFormen(tester, leerTag)),
        reason:
            'das Raster vermerkt, **dass** getestet wurde; gedeutet '
            'wird der Test in der Lagezeile, nicht im Tag. Ein Ergebnis, '
            'das nur im positiven Fall sichtbar wäre, verriete es jedem, '
            'der über die Schulter schaut',
      );
    });

    testWidgets('ein Tag mit nur einer Notiz bleibt leer', (tester) async {
      await legeTestUndNotiz();
      await zeigeKalender(tester);

      expect(
        imRaster(tester, notizTag).zustand,
        isNull,
        reason: 'eine Notiz ist kein Zustand',
      );
      expect(
        imRaster(tester, notizTag).marken,
        isEmpty,
        reason:
            'unter dem Tag hängt ein Herz für Sex und ein Punkt für '
            'Beschwerden — für Freitext hängt dort nichts',
      );
      expect(
        sichtbareFormen(tester, notizTag),
        sichtbareFormen(tester, leerTag),
        reason:
            '„aber sonst ist es ein leerer tag ja, da ist ja sonst nix" '
            '(Tim, 24.11.2026) — ausdrücklich so gewollt',
      );
    });

    testWidgets('eine Zwischenblutung ohne Stärke bleibt unmarkiert', (
      tester,
    ) async {
      await legeBlutung(periodeC);
      await repo.schreibe(
        const ZyklusEintrag(tag: notizTag, zwischenblutung: true),
      );
      await zeigeKalender(tester);

      expect(
        imRaster(tester, notizTag).zustand,
        isNull,
        reason:
            'ohne Stärke ist nichts über die Blutung gesagt — gefüllt '
            'hieße „eingetragen", und eingetragen ist nur das Kreuzchen',
      );
      expect(
        sichtbareFormen(tester, notizTag),
        sichtbareFormen(tester, leerTag),
      );
    });

    testWidgets('heute bleibt neben einem Test erkennbar', (tester) async {
      await legeTestUndNotiz();
      await repo.schreibe(
        const ZyklusEintrag(tag: heute, test: Testergebnis.negativ),
      );
      await zeigeKalender(tester);

      expect(
        imRaster(tester, heute).heute,
        isTrue,
        reason: 'Vorbedingung: der 17. ist heute',
      );
      expect(
        imRaster(tester, heute).zustand,
        imRaster(tester, testTag).zustand,
        reason:
            'Vorbedingung: beide Tage tragen denselben Zustand und '
            'denselben Eintrag — sie unterscheiden sich allein darin, '
            'dass einer heute ist',
      );
      expect(
        sichtbareFormen(tester, heute),
        greaterThan(sichtbareFormen(tester, testTag)),
        reason:
            'heute und „Test eingetragen" sind zwei verschiedene '
            'Auskünfte. Tragen sie dieselbe Form, sagt der Kalender '
            'beides und meint keines von beiden',
      );
    });

    testWidgets('heute bleibt auch neben einer eingetragenen Blutung '
        'erkennbar', (tester) async {
      // Eine laufende Periode, die bis heute reicht — der häufigste Fall
      // überhaupt, und der, in dem sich zwei Markierungen begegnen.
      await legeBlutung(['2099-11-15', '2099-11-16', heute]);
      await zeigeKalender(tester);

      expect(
        imRaster(tester, heute).zustand,
        ZyklusTagZustand.eingetragen,
        reason: 'Vorbedingung: heute ist ein Blutungstag',
      );
      expect(
        imRaster(tester, '2099-11-16').zustand,
        ZyklusTagZustand.eingetragen,
        reason: 'Vorbedingung: der Vortag auch',
      );
      expect(
        sichtbareFormen(tester, heute),
        greaterThan(sichtbareFormen(tester, '2099-11-16')),
        reason:
            'die Blutung darf heute nicht verschlucken. Eine Markierung, '
            'die nur auf leeren Tagen erscheint, ist keine',
      );
    });

    testWidgets('der Vorlesetext sagt, dass ein Test eingetragen ist', (
      tester,
    ) async {
      await legeTestUndNotiz();
      await zeigeKalender(tester);

      expect(
        find.bySemanticsLabel(RegExp(r'^13\.,.*Test eingetragen')),
        findsOneWidget,
        reason:
            'eine Markierung, die nur zu sehen ist, erreicht VoiceOver '
            'nicht — der Vorlesetext nennt den Zustand, nicht das '
            'Zeichen (`CLAUDE.md`)',
      );
      expect(
        find.bySemanticsLabel(RegExp(r'^12\.,.*Test eingetragen')),
        findsNothing,
        reason:
            'und der Tag daneben, an dem nur eine Notiz steht, sagt es '
            'nicht',
      );
    });
  });
}

/// Ein Repository, dessen Lesen erst antwortet, wenn der Test es sagt.
///
/// Geschrieben wird dabei nie — ein Fall, der dieses Repository benutzt,
/// prüft den Ladezustand und sonst nichts.
///
/// **Kein `super.db`:** Diese Datei legt sich auf einen ersten
/// positionellen Parameter fest, nicht auf dessen Namen.
class _HaengendesRepo extends ZyklusRepository {
  _HaengendesRepo(AppCache db, this.antwort) : super(db);

  final Completer<void> antwort;

  @override
  Future<ZyklusEintrag?> lies(String tag) async {
    await antwort.future;
    return null;
  }

  @override
  Future<List<ZyklusEintrag>> imZeitraum({
    required String von,
    required String bis,
  }) async {
    await antwort.future;
    return const [];
  }

  @override
  Future<ZyklusEinstellungen> liesEinstellungen() async {
    await antwort.future;
    return ZyklusEinstellungen.vorbelegung.kopieMit(kalenderAn: true);
  }
}

/// Ein Repository, dessen Lesen scheitert.
class _KaputtesRepo extends ZyklusRepository {
  _KaputtesRepo(AppCache db) : super(db);

  @override
  Future<ZyklusEintrag?> lies(String tag) =>
      Future.error(StateError('Tabelle nicht lesbar (erzwungen im Test)'));

  @override
  Future<List<ZyklusEintrag>> imZeitraum({
    required String von,
    required String bis,
  }) => Future.error(StateError('Tabelle nicht lesbar (erzwungen im Test)'));
}
