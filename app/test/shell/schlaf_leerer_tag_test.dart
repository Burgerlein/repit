import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/core/messwert.dart';
import 'package:repit/data/schlaf_eintrag.dart';
import 'package:repit/data/ziele.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_types.dart';
import 'package:repit/shell/router.dart';
import 'package:repit/shell/schlaf_kalenderblatt.dart';
import 'package:repit/shell/schlaf_view.dart';
import 'package:repit/shell/schlaf_zustand.dart';

import '../design/support.dart' show textOf;
import '../health/health_reading_attrappe.dart';

/// Tests für **leere Tage im Schlaf-Schirm** (#177) — das Kalenderblatt
/// (`lib/shell/schlaf_kalenderblatt.dart`), die Menge, über die geblättert
/// wird (`lib/shell/schlaf_auswahl.dart`), und der Zustand eines gewählten
/// Tages ohne Nacht (`lib/shell/schlaf_zustand.dart`,
/// `lib/shell/schlaf_view.dart`).
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, nie verändert werden.
///
/// ## Woher die Anforderung kommt
///
/// Aus dem Entwurf: `docs/screens/screens/schlaf.js`, Zustände `kalender`
/// und `leerer-tag`, freigegeben am 30.10.2026. Der Dateikopf dort trägt die
/// Begründung jeder einzelnen Entscheidung; hier steht, was davon prüfbar
/// ist.
///
/// Der Anlass: Ein Tag **ohne** Nacht war im Kalenderblatt stumm, und Pfeil
/// wie Wischgeste blätterten über die geladenen Nächte — ein leerer Tag war
/// kein Nachbar. Damit war die Eingabe von Hand (#131) nur für Tage
/// erreichbar, an denen schon eine gemessene Nacht lag: also genau nicht
/// für den Fall, für den es sie gibt. Tims Beschreibung: Er steht auf dem
/// 22., der 21. hat keine Daten, und der Pfeil sprang auf den 20.
///
/// ## Die festgelegte API
///
/// ```dart
/// // lib/shell/schlaf_auswahl.dart
///
/// /// Der früheste Tag, den der Schirm anbietet: der Anfang des gelesenen
/// /// Zeitraums, nach hinten verschoben durch eine ältere eigene Eingabe
/// /// oder eine ältere geladene Nacht. Nie später als `heute`.
/// DateTime fruehesterSchlaftag({
///   required DateTime fensterBeginn,
///   required DateTime heute,
///   List<SleepNight> naechte,
///   List<SchlafEintrag> eintraege,
/// });
///
/// /// Die Nachbarn eines **Kalendertags**; `null` heißt „am Rand".
/// ({DateTime? frueher, DateTime? spaeter}) schlafTagNachbarn({
///   required DateTime tag,
///   required DateTime fruehesterTag,
///   required DateTime heute,
/// });
///
/// // lib/shell/schlaf_kalenderblatt.dart
///
/// /// Welche Form ein Tag im Raster trägt.
/// enum SchlafTagform { nacht, leer, ausserhalb }
///
/// SchlafTagform schlafTagform({
///   required DateTime tag,
///   required bool hatNacht,
///   required DateTime fruehesterTag,
///   required DateTime heute,
/// });
///
/// // lib/shell/schlaf_zustand.dart
///
/// class SchlafDaten {
///   /// Der Tag, um den es im Nachtbereich geht — auch ohne Nacht.
///   /// `null` heißt „es gibt nichts, worauf der Schirm zeigen könnte".
///   final DateTime? gezeigterTag;
///
///   /// Der gezeigte Tag ist **nicht heute**.
///   final bool zeigtAnderenTag;
/// }
///
/// class SchlafZustand {
///   /// Der früheste Tag, den Blätterleiste und Kalenderblatt anbieten.
///   final DateTime fruehesterTag;
/// }
///
/// SchlafZustand schlafZustandAus({
///   …,
///   DateTime? fensterBeginn,
/// });
/// ```
///
/// Wo `fensterBeginn` **nicht** genannt ist, gibt es keinen Zeitraum zu
/// verschenken: Dann ist der früheste Tag `heute`, und der Schirm verhält
/// sich wie vorher. Das ist kein Nebenweg, sondern die ehrliche Vorgabe —
/// ein Zustand, der den gelesenen Zeitraum nicht kennt, darf keinen
/// erfinden.
///
/// ## Schlüssel, die dazukommen
///
/// - `Key('schlaf-leerer-tag')` — der Kasten an der Stelle der Score-Karte
/// - `Key('schlaf-kalender-monat-frueher')`,
///   `Key('schlaf-kalender-monat-spaeter')` — die beiden Monatspfeile
///
/// ## Was hier **nicht** geprüft wird
///
/// - **Das Aussehen der drei Tagesformen.** Gestrichelt gegen durchgezogen
///   gegen gar kein Ring ist Malerei auf einem `CustomPainter`; prüfbar ist
///   die Entscheidung davor, und die steht in [schlafTagform].
/// - **Die Haptik am Rand.** Ein Widget-Test sieht keinen Vibrationsmotor.
/// - **Der Wortlaut der Sätze.** Geprüft wird, dass beide Gründe
///   vorkommen — „aufgezeichnet" und „freigegeben" —, weil Apple den
///   Lesestatus nicht verrät. Nicht, wie der Satz gebaut ist.
///
/// ## Zahlen in dieser Datei
///
/// Alle erfunden und frei gewählt. Keine stammt aus einem Health-Export
/// oder einem Screenshot (`CLAUDE.md`).
void main() {
  // Donnerstag, 22.10.2026, 09:00 Berlin. Sommerzeit endet erst am 25.10.,
  // also noch CEST (+2) — der Tagesbeginn liegt in UTC am 21. um 22:00.
  final jetzt = DateTime.utc(2026, 10, 22, 7);

  DateTime tagesbeginn(int tag, {int monat = 10}) =>
      BerlinCalendar.startOfDay(DateTime.utc(2026, monat, tag));

  final heute = tagesbeginn(22);

  /// Eine schlichte Nacht: sieben Stunden Kernschlaf, die um 23:00 Berliner
  /// Zeit des Vortags beginnen.
  SleepNight nachtVon(int tag, {int monat = 10}) {
    final ende = tagesbeginn(tag, monat: monat);
    final beginn = ende.subtract(const Duration(hours: 1));
    return SleepNight(
      date: ende,
      session: SleepSession(
        segments: [
          SleepSegment(
            stage: SleepStage.core,
            start: beginn,
            end: beginn.add(const Duration(hours: 7)),
          ),
        ],
      ),
      naps: const [],
    );
  }

  /// **Tims Fall.** Gemessen sind der 18., 19., 20. und 22.; der **21.**
  /// fehlt — an dem lag die Uhr auf dem Nachttisch.
  List<SleepNight> timsReihe() => [
    nachtVon(18),
    nachtVon(19),
    nachtVon(20),
    nachtVon(22),
  ];

  // ═══════════════════════════════════════════════════════════════════════
  // 1 — Die Menge, über die geblättert wird
  // ═══════════════════════════════════════════════════════════════════════

  group('schlafTagNachbarn — von Tag zu Tag, nicht von Nacht zu Nacht', () {
    test('mitten im Zeitraum sind es Vortag und Folgetag', () {
      final nachbarn = schlafTagNachbarn(
        tag: tagesbeginn(20),
        fruehesterTag: tagesbeginn(1),
        heute: heute,
      );

      expect(nachbarn.frueher, tagesbeginn(19));
      expect(nachbarn.spaeter, tagesbeginn(21));
    });

    test('der Nachbar eines Tages ist der Nachbartag, auch wenn für ihn keine '
        'Nacht vorliegt — das ist der ganze Punkt von #177', () {
      // Vom 22. aus liegt der 21. davor, nicht der 20.
      final nachbarn = schlafTagNachbarn(
        tag: tagesbeginn(22),
        fruehesterTag: tagesbeginn(1),
        heute: heute,
      );

      expect(
        nachbarn.frueher,
        tagesbeginn(21),
        reason:
            'Der Pfeil sprang bisher über den leeren 21. hinweg auf den '
            '20. Genau das ist die Beobachtung im Ticket.',
      );
    });

    test('am frühesten Tag gibt es kein Früher', () {
      final nachbarn = schlafTagNachbarn(
        tag: tagesbeginn(15),
        fruehesterTag: tagesbeginn(15),
        heute: heute,
      );

      expect(nachbarn.frueher, isNull);
      expect(nachbarn.spaeter, tagesbeginn(16));
    });

    test('an heute gibt es kein Später — eine Nacht, die noch nicht war, '
        'trägt man nicht ein', () {
      final nachbarn = schlafTagNachbarn(
        tag: heute,
        fruehesterTag: tagesbeginn(1),
        heute: heute,
      );

      expect(nachbarn.spaeter, isNull);
      expect(nachbarn.frueher, tagesbeginn(21));
    });

    test('ein Zeitraum von einem einzigen Tag hat gar keine Nachbarn', () {
      final nachbarn = schlafTagNachbarn(
        tag: heute,
        fruehesterTag: heute,
        heute: heute,
      );

      expect(nachbarn.frueher, isNull);
      expect(nachbarn.spaeter, isNull);
    });

    test('über die Zeitumstellung hinweg sind es Kalendertage, keine '
        '24-Stunden-Schritte — die Nacht zum 25.10.2026 hat 25 Stunden', () {
      final nachbarn = schlafTagNachbarn(
        tag: tagesbeginn(25),
        fruehesterTag: tagesbeginn(1),
        heute: tagesbeginn(31),
      );

      expect(nachbarn.frueher, tagesbeginn(24));
      expect(nachbarn.spaeter, tagesbeginn(26));
    });
  });

  group('fruehesterSchlaftag — so weit, wie die App gelesen hat', () {
    test('ohne alles ist es der Anfang des Zeitraums', () {
      expect(
        fruehesterSchlaftag(fensterBeginn: tagesbeginn(1), heute: heute),
        tagesbeginn(1),
      );
    });

    test('eine geladene Nacht vor dem Zeitraum schiebt ihn nach hinten — eine '
        'Nacht, die oben stehen kann, muss anwählbar sein', () {
      expect(
        fruehesterSchlaftag(
          fensterBeginn: tagesbeginn(10),
          heute: heute,
          naechte: [nachtVon(28, monat: 9)],
        ),
        tagesbeginn(28, monat: 9),
      );
    });

    test('eine ältere eigene Eingabe ebenso — sie kennt kein Fenster', () {
      expect(
        fruehesterSchlaftag(
          fensterBeginn: tagesbeginn(10),
          heute: heute,
          eintraege: const [
            SchlafEintrag(
              tag: '2026-09-04',
              art: SchlafEintragArt.nacht,
              lfdNr: 0,
              schlafMinuten: 400,
            ),
          ],
        ),
        tagesbeginn(4, monat: 9),
      );
    });

    test(
      'nie später als heute — sonst zeigte der Schirm auf keinen Tag mehr',
      () {
        expect(
          fruehesterSchlaftag(fensterBeginn: tagesbeginn(28), heute: heute),
          heute,
        );
      },
    );
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 2 — Die drei Formen im Kalenderblatt
  // ═══════════════════════════════════════════════════════════════════════

  group('schlafTagform — jede Form sagt genau eine Sache', () {
    test('mit Nacht ist es eine Nacht', () {
      expect(
        schlafTagform(
          tag: tagesbeginn(20),
          hatNacht: true,
          fruehesterTag: tagesbeginn(1),
          heute: heute,
        ),
        SchlafTagform.nacht,
      );
    });

    test('ohne Nacht im gelesenen Zeitraum ist der Tag leer — und damit '
        'antippbar', () {
      expect(
        schlafTagform(
          tag: tagesbeginn(21),
          hatNacht: false,
          fruehesterTag: tagesbeginn(1),
          heute: heute,
        ),
        SchlafTagform.leer,
      );
    });

    test(
      'vor dem Zeitraum ist er außerhalb — dort hat niemand nachgesehen, '
      'und „nie nachgesehen" ist nicht „nachgesehen und nichts gefunden"',
      () {
        expect(
          schlafTagform(
            tag: tagesbeginn(30, monat: 9),
            hatNacht: false,
            fruehesterTag: tagesbeginn(1),
            heute: heute,
          ),
          SchlafTagform.ausserhalb,
        );
      },
    );

    test('nach heute ebenso — eine Nacht, die noch nicht war', () {
      expect(
        schlafTagform(
          tag: tagesbeginn(23),
          hatNacht: false,
          fruehesterTag: tagesbeginn(1),
          heute: heute,
        ),
        SchlafTagform.ausserhalb,
      );
    });

    test('heute selbst ist nicht außerhalb — es ist der Normalfall', () {
      expect(
        schlafTagform(
          tag: heute,
          hatNacht: false,
          fruehesterTag: tagesbeginn(1),
          heute: heute,
        ),
        SchlafTagform.leer,
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 3 — Der Zustand eines gewählten leeren Tages
  // ═══════════════════════════════════════════════════════════════════════

  group('schlafZustandAus — ein gewählter Tag ohne Nacht', () {
    SchlafZustand zustand({DateTime? gewaehlt, List<SleepNight>? naechte}) =>
        schlafZustandAus(
          naechte: Bekannt<List<SleepNight>>(
            naechte ?? timsReihe(),
            stand: jetzt,
            laeuft: false,
          ),
          ziele: Ziele.vorbelegung,
          gewaehlt: gewaehlt,
          jetzt: jetzt,
          fensterBeginn: tagesbeginn(1),
        );

    SchlafDaten daten(SchlafZustand z) =>
        (z.daten as Bekannt<SchlafDaten>).wert;

    test('der Zeitraum steht am Zustand, nicht an den Daten — er gilt auch '
        'ohne Nächte', () {
      expect(zustand().fruehesterTag, tagesbeginn(1));
    });

    test('ohne Auswahl steht die jüngste Nacht da, nicht ein leerer heute', () {
      final d = daten(zustand());

      expect(d.nacht, isNotNull);
      expect(d.gezeigterTag, tagesbeginn(22));
      expect(d.zeigtAnderenTag, isFalse);
    });

    test('der gewählte leere Tag bleibt leer — kein Ausweichen auf die letzte '
        'Nacht', () {
      final d = daten(zustand(gewaehlt: tagesbeginn(21)));

      expect(d.gezeigterTag, tagesbeginn(21));
      expect(
        d.nacht,
        isNull,
        reason:
            'Für den 21. gibt es keine Nacht. Früher fiel die Auflösung '
            'auf die jüngste zurück; dann stünde oben der 22.',
      );
    });

    test('und er gilt als anderer Tag — Verlauf und Schnitte sagen, dass sie '
        'sich weiter auf heute beziehen', () {
      expect(daten(zustand(gewaehlt: tagesbeginn(21))).zeigtAnderenTag, isTrue);
    });

    test('die Pfeile zeigen auf die Nachbartage, auch auf leere', () {
      final d = daten(zustand(gewaehlt: tagesbeginn(22)));

      expect(d.frueher, tagesbeginn(21));
      expect(d.spaeter, isNull);
    });

    test('und vom leeren Tag aus geht es in beide Richtungen weiter', () {
      final d = daten(zustand(gewaehlt: tagesbeginn(21)));

      expect(d.frueher, tagesbeginn(20));
      expect(d.spaeter, tagesbeginn(22));
    });

    test('ein gewählter Tag außerhalb des Zeitraums wird nicht angenommen — er '
        'käme aus einem Kalenderblatt, das ihn nie angeboten hat', () {
      final d = daten(zustand(gewaehlt: tagesbeginn(1, monat: 7)));

      expect(d.gezeigterTag, tagesbeginn(22));
      expect(d.nacht, isNotNull);
    });

    test('ohne Nächte und ohne Auswahl gibt es keinen gezeigten Tag — dann '
        'steht der Leerzustand da und nicht ein leerer Tag', () {
      final d = daten(zustand(naechte: const []));

      expect(d.gezeigterTag, isNull);
      expect(d.nacht, isNull);
    });

    test('ohne genannten Zeitraum bleibt es bei heute — ein Zustand, der den '
        'gelesenen Zeitraum nicht kennt, erfindet keinen', () {
      final z = schlafZustandAus(
        naechte: Bekannt<List<SleepNight>>(
          timsReihe(),
          stand: jetzt,
          laeuft: false,
        ),
        ziele: Ziele.vorbelegung,
        gewaehlt: null,
        jetzt: jetzt,
      );

      // Die geladenen Nächte schieben ihn trotzdem zurück: Die älteste
      // ist der 18., und sie muss anwählbar bleiben.
      expect(z.fruehesterTag, tagesbeginn(18));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 4 — Blättern über den Provider
  // ═══════════════════════════════════════════════════════════════════════

  group('blaettere — Tims Fall', () {
    ProviderContainer behaelter({List<SleepNight>? naechte}) {
      // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          clockProvider.overrideWithValue(() => jetzt),
          dataWindowProvider.overrideWith(
            (ref) => DataWindow(start: tagesbeginn(1)),
          ),
          sleepProvider.overrideWith(
            () => _Naechte(
              Bekannt<List<SleepNight>>(
                naechte ?? timsReihe(),
                stand: jetzt,
                laeuft: false,
              ),
            ),
          ),
          zieleProvider.overrideWith(() => _Ziele(Ziele.vorbelegung)),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    Future<void> geladen(ProviderContainer container) async {
      container.listen(schlafProvider, (_, _) {}, fireImmediately: true);
      await container.read(sleepProvider.future);
      await container.read(zieleProvider.future);
    }

    test('vom 22. führt ‹ auf den 21., nicht auf den 20. — die Beobachtung aus '
        'dem Ticket, in einem Satz', () async {
      final container = behaelter();
      await geladen(container);

      container
          .read(schlafAuswahlProvider.notifier)
          .blaettere(SchlafBlaettern.frueher);

      expect(container.read(schlafAuswahlProvider), tagesbeginn(21));
    });

    test('und von dort noch einmal auf den 20.', () async {
      final container = behaelter();
      await geladen(container);
      final notifier = container.read(schlafAuswahlProvider.notifier);

      notifier.blaettere(SchlafBlaettern.frueher);
      notifier.blaettere(SchlafBlaettern.frueher);

      expect(container.read(schlafAuswahlProvider), tagesbeginn(20));
    });

    test(
      'zurück nach vorn führt über den leeren Tag, nicht an ihm vorbei',
      () async {
        final container = behaelter();
        await geladen(container);
        final notifier = container.read(schlafAuswahlProvider.notifier);

        notifier.blaettere(SchlafBlaettern.frueher);
        notifier.blaettere(SchlafBlaettern.frueher);
        notifier.blaettere(SchlafBlaettern.spaeter);

        expect(container.read(schlafAuswahlProvider), tagesbeginn(21));
      },
    );

    test('ist die jüngste Nacht zwei Tage alt, führt › auf die leeren Tage — '
        'und damit auf die Eingabe, für die #131 gebaut ist', () async {
      final container = behaelter(
        naechte: [nachtVon(18), nachtVon(19), nachtVon(20)],
      );
      await geladen(container);

      container
          .read(schlafAuswahlProvider.notifier)
          .blaettere(SchlafBlaettern.spaeter);

      expect(container.read(schlafAuswahlProvider), tagesbeginn(21));
    });

    test('am Anfang des Zeitraums passiert nichts', () async {
      final container = behaelter(naechte: [nachtVon(1)]);
      await geladen(container);
      final notifier = container.read(schlafAuswahlProvider.notifier);

      notifier.blaettere(SchlafBlaettern.frueher);

      expect(container.read(schlafAuswahlProvider), isNull);
    });

    test('ohne jede Nacht und ohne Auswahl blättert nichts — es gibt keinen '
        'Ausgangspunkt', () async {
      final container = behaelter(naechte: const []);
      await geladen(container);

      container
          .read(schlafAuswahlProvider.notifier)
          .blaettere(SchlafBlaettern.frueher);

      expect(container.read(schlafAuswahlProvider), isNull);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 5 — Der Schirm
  // ═══════════════════════════════════════════════════════════════════════

  ({ProviderContainer container, Widget app}) huelle({
    Messwert<List<SleepNight>>? schlaf,
    bool mitSeite = false,
  }) {
    final router = AppRouter();
    // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        clockProvider.overrideWithValue(() => jetzt),
        dataWindowProvider.overrideWith(
          (ref) => DataWindow(start: tagesbeginn(1)),
        ),
        healthProvider.overrideWithValue(_LeereQuelle()),
        sleepProvider.overrideWith(
          () => _Naechte(
            schlaf ??
                Bekannt<List<SleepNight>>(
                  timsReihe(),
                  stand: jetzt,
                  laeuft: false,
                ),
          ),
        ),
        zieleProvider.overrideWith(() => _Ziele(Ziele.vorbelegung)),
      ],
    );
    addTearDown(container.dispose);

    return (
      container: container,
      app: UncontrolledProviderScope(
        container: container,
        child: CupertinoApp(
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(padding: const EdgeInsets.only(top: 47, bottom: 34)),
              child: mitSeite
                  ? SchlafSeite(router: router)
                  : SchlafView(router: router),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> zeige(WidgetTester tester, Widget app) async {
    tester.view.physicalSize = const Size(900, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
  }

  String alleTexte(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map(textOf)
      .join(' ')
      .toLowerCase();

  String textUnter(WidgetTester tester, Key key) => tester
      .widgetList<Text>(
        find.descendant(of: find.byKey(key), matching: find.byType(Text)),
      )
      .map(textOf)
      .join(' ');

  bool knopfAktiv(WidgetTester tester, Key key) =>
      tester.widget<CupertinoButton>(find.byKey(key)).onPressed != null;

  group('Der Schirm auf einem leeren Tag', () {
    Future<ProviderContainer> aufDenLeerenTag(WidgetTester tester) async {
      final h = huelle();
      await zeige(tester, h.app);
      h.container.read(schlafAuswahlProvider.notifier).waehle(tagesbeginn(21));
      await tester.pumpAndSettle();
      return h.container;
    }

    testWidgets('die Blätterleiste bleibt stehen und nennt den Tag', (
      tester,
    ) async {
      await aufDenLeerenTag(tester);

      expect(find.byKey(const Key('schlaf-blaetterleiste')), findsOneWidget);
      expect(
        textUnter(tester, const Key('schlaf-blaetterleiste')),
        contains('21'),
      );
    });

    testWidgets(
      'statt des Fensters steht dort, dass es keine Nacht gibt — kein '
      'Gedankenstrich, der wie ein fehlender Messwert aussähe',
      (tester) async {
        await aufDenLeerenTag(tester);

        expect(
          textUnter(tester, const Key('schlaf-blaetterleiste')).toLowerCase(),
          contains('keine nacht'),
        );
      },
    );

    testWidgets('an der Stelle der Score-Karte steht der Kasten, kein Ring', (
      tester,
    ) async {
      await aufDenLeerenTag(tester);

      expect(find.byKey(const Key('schlaf-leerer-tag')), findsOneWidget);
      expect(find.byKey(const Key('schlaf-scorekarte')), findsNothing);
    });

    testWidgets(
      'der Kasten nennt beide Möglichkeiten — Apple verrät den Lesestatus '
      'nicht, also wird keine davon entschieden',
      (tester) async {
        await aufDenLeerenTag(tester);

        final text = textUnter(
          tester,
          const Key('schlaf-leerer-tag'),
        ).toLowerCase();
        expect(text, contains('aufgezeichnet'));
        expect(text, contains('freigegeben'));
      },
    );

    testWidgets(
      'Schlafphasen, Puls und Atmung fehlen ganz — gemessen wurde nichts',
      (tester) async {
        await aufDenLeerenTag(tester);

        expect(find.byKey(const Key('schlaf-phasen')), findsNothing);
        expect(find.byKey(const Key('schlaf-puls')), findsNothing);
        expect(find.byKey(const Key('schlaf-atmung')), findsNothing);
      },
    );

    testWidgets(
      'Verlauf, Schnitte und „Sieben Nächte" stehen weiter da und beziehen '
      'sich auf heute (Entscheidung vom 13.10.2026)',
      (tester) async {
        await aufDenLeerenTag(tester);

        expect(find.byKey(const Key('schlaf-verlauf')), findsOneWidget);
        expect(find.byKey(const Key('schlaf-naechte')), findsOneWidget);
        expect(find.byKey(const Key('schlaf-verlauf-hinweis')), findsOneWidget);
      },
    );

    testWidgets('und der Weg zur Eingabe steht da — er ist hier der einzige, '
        'der weiterführt', (tester) async {
      await aufDenLeerenTag(tester);

      expect(find.byKey(const Key('schlaf-eintragen')), findsOneWidget);
    });

    testWidgets('von dort führen beide Pfeile weiter', (tester) async {
      await aufDenLeerenTag(tester);

      expect(knopfAktiv(tester, const Key('schlaf-frueher')), isTrue);
      expect(knopfAktiv(tester, const Key('schlaf-spaeter')), isTrue);
    });

    testWidgets(
      'der Hinweis über dem Verlauf spricht nicht mehr von einer älteren '
      'Nacht — der gewählte Tag kann neuer sein als die jüngste',
      (tester) async {
        final h = huelle(
          schlaf: Bekannt<List<SleepNight>>(
            [nachtVon(18), nachtVon(19), nachtVon(20)],
            stand: jetzt,
            laeuft: false,
          ),
        );
        await zeige(tester, h.app);
        h.container
            .read(schlafAuswahlProvider.notifier)
            .waehle(tagesbeginn(21));
        await tester.pumpAndSettle();

        final text = textUnter(
          tester,
          const Key('schlaf-verlauf-hinweis'),
        ).toLowerCase();
        expect(text, isNot(contains('ältere nacht')));
        expect(text, contains('heute'));
      },
    );
  });

  group('Aus dem Leerzustand heraus', () {
    testWidgets('ohne gewählten Tag steht weiter der Leerzustand da', (
      tester,
    ) async {
      final h = huelle(schlaf: LeerNachLauf<List<SleepNight>>(gelaufen: jetzt));
      await zeige(tester, h.app);

      expect(find.byKey(const Key('schlaf-leer')), findsOneWidget);
      expect(find.byKey(const Key('schlaf-leerer-tag')), findsNothing);
    });

    testWidgets(
      'ein gewählter Tag schlägt ihn — wer einen Tag angetippt hat, will '
      'etwas über diesen Tag wissen',
      (tester) async {
        final h = huelle(
          schlaf: LeerNachLauf<List<SleepNight>>(gelaufen: jetzt),
        );
        await zeige(tester, h.app);
        h.container
            .read(schlafAuswahlProvider.notifier)
            .waehle(tagesbeginn(15));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('schlaf-leerer-tag')), findsOneWidget);
        expect(find.byKey(const Key('schlaf-leer')), findsNothing);
      },
    );

    testWidgets(
      'die Freigabefrage bleibt trotzdem sichtbar — solange der Lauf gar '
      'nichts brachte, ist sie offen',
      (tester) async {
        final h = huelle(
          schlaf: LeerNachLauf<List<SleepNight>>(gelaufen: jetzt),
        );
        await zeige(tester, h.app);
        h.container
            .read(schlafAuswahlProvider.notifier)
            .waehle(tagesbeginn(15));
        await tester.pumpAndSettle();

        expect(alleTexte(tester), contains('health'));
      },
    );
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 6 — Das Kalenderblatt
  // ═══════════════════════════════════════════════════════════════════════

  group('Das Kalenderblatt lässt auf leere Tage tippen', () {
    Future<void> oeffne(WidgetTester tester, Widget app) async {
      await zeige(tester, app);
      await tester.tap(find.byKey(const Key('schlaf-kalender-knopf')));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'ein Tag ohne Nacht im gelesenen Zeitraum ist tippbar, wählt ihn und '
      'schließt — der Kern von #177',
      (tester) async {
        final h = huelle(mitSeite: true);
        await oeffne(tester, h.app);

        await tester.tap(
          find.byKey(const Key('schlaf-kalender-tag-2026-10-21')),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('schlaf-kalenderblatt')), findsNothing);
        expect(h.container.read(schlafAuswahlProvider), tagesbeginn(21));
      },
    );

    testWidgets('und danach steht der leere Tag auf dem Schirm', (
      tester,
    ) async {
      final h = huelle(mitSeite: true);
      await oeffne(tester, h.app);

      await tester.tap(find.byKey(const Key('schlaf-kalender-tag-2026-10-21')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('schlaf-leerer-tag')), findsOneWidget);
    });

    testWidgets('ein Tag mit Nacht bleibt tippbar und wählt seine Nacht', (
      tester,
    ) async {
      final h = huelle(mitSeite: true);
      await oeffne(tester, h.app);

      await tester.tap(find.byKey(const Key('schlaf-kalender-tag-2026-10-19')));
      await tester.pumpAndSettle();

      expect(h.container.read(schlafAuswahlProvider), tagesbeginn(19));
    });

    testWidgets(
      'ein Tag nach heute ist stumm — eine Nacht, die noch nicht war',
      (tester) async {
        final h = huelle(mitSeite: true);
        await oeffne(tester, h.app);

        await tester.tap(
          find.byKey(const Key('schlaf-kalender-tag-2026-10-25')),
          warnIfMissed: false,
        );
        await tester.pumpAndSettle();

        expect(h.container.read(schlafAuswahlProvider), isNull);
        expect(find.byKey(const Key('schlaf-kalenderblatt')), findsOneWidget);
      },
    );

    testWidgets('der Monat lässt sich zurückblättern, bis der Zeitraum endet', (
      tester,
    ) async {
      final h = huelle(mitSeite: true);
      await oeffne(tester, h.app);

      // Der Zeitraum beginnt am 01.10., also gibt es keinen Vormonat.
      expect(
        knopfAktiv(tester, const Key('schlaf-kalender-monat-frueher')),
        isFalse,
      );
      // Und keinen Folgemonat: Oktober enthält heute.
      expect(
        knopfAktiv(tester, const Key('schlaf-kalender-monat-spaeter')),
        isFalse,
      );
    });

    testWidgets(
      'reicht der Zeitraum in den Vormonat, führt der Pfeil dorthin',
      (tester) async {
        final h = huelle(
          mitSeite: true,
          schlaf: Bekannt<List<SleepNight>>(
            [nachtVon(28, monat: 9), ...timsReihe()],
            stand: jetzt,
            laeuft: false,
          ),
        );
        await oeffne(tester, h.app);

        expect(
          knopfAktiv(tester, const Key('schlaf-kalender-monat-frueher')),
          isTrue,
        );

        await tester.tap(
          find.byKey(const Key('schlaf-kalender-monat-frueher')),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('schlaf-kalender-tag-2026-09-28')),
          findsOneWidget,
        );
        expect(
          knopfAktiv(tester, const Key('schlaf-kalender-monat-spaeter')),
          isTrue,
        );
      },
    );

    testWidgets(
      'unter dem Raster steht, was gestrichelt heißt — ohne den Satz fehlt '
      'dem leeren Tag das einzige Zeichen, das ihn als Tür ausweist',
      (tester) async {
        final h = huelle(mitSeite: true);
        await oeffne(tester, h.app);

        final text = textUnter(
          tester,
          const Key('schlaf-kalenderblatt'),
        ).toLowerCase();
        expect(text, contains('gestrichelt'));
        expect(text, contains('eintragen'));
      },
    );
  });
}

class _Naechte extends SleepNotifier {
  _Naechte(this.wert);

  final Messwert<List<SleepNight>> wert;

  @override
  Future<Messwert<List<SleepNight>>> build() async => wert;
}

class _Ziele extends ZieleNotifier {
  _Ziele(this.wert);

  final Ziele wert;

  @override
  Future<Ziele> build() async => wert;
}

/// Liefert nichts — die Vitalwerte sind hier nicht der Gegenstand.
class _LeereQuelle extends HealthReadingAttrappe {}
