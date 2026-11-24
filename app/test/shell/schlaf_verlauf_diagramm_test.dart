import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/core/messwert.dart';
import 'package:repit/data/ziele.dart';
import 'package:repit/design/zeitdiagramm.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_types.dart';
import 'package:repit/shell/diagramm_zeitraum.dart';
import 'package:repit/shell/router.dart';
import 'package:repit/shell/schlaf_abschnitte.dart';
import 'package:repit/shell/schlaf_view.dart';
import 'package:repit/shell/schlaf_zustand.dart';

import '../design/support.dart' show textOf;
import '../health/health_reading_attrappe.dart';

/// **#139 — Der Verlauf des Schlaf-Schirms bekommt sein Diagramm.**
///
/// Der Schirm (#92) entstand, **bevor es das Diagramm-Bauteil gab** (#130),
/// und bekam dafür eine Behelfsfassung: nur den Kopf der Diagrammkarte —
/// Durchschnitt, Zeitraum, Fußnote —, keine Stufenleiste und keinen Graphen.
/// Seit #130 steht, wird das eingelöst. Die bestehenden Tests des Schirms
/// (`schlaf_view_test.dart`) nehmen das ausdrücklich aus: „Das Diagramm
/// selbst … gehört zu #130".
///
/// Vorlage ist die Konstante `VERLAUF` in `docs/screens/screens/schlaf.js`.
///
/// ## Festgelegte öffentliche API
///
/// ```dart
/// // lib/shell/schlaf_abschnitte.dart
///
/// /// Die Diagrammkarte des Verlaufs — Leiste, Kopfzeile, Graph, Fußzeile.
/// ///
/// /// **Nur noch die Reihe.** Durchschnitt und Zeitraum rechnet das
/// /// Diagramm über das sichtbare Fenster; ein zweiter, daneben stehender
/// /// Schnitt über einen anderen Zeitraum wären zwei Wahrheiten in einer
/// /// Karte.
/// class SchlafVerlauf extends StatelessWidget {
///   const SchlafVerlauf({
///     super.key,
///     required List<({DateTime tag, double wert})> reihe,
///   });
/// }
///
/// // lib/shell/schlaf_zustand.dart
///
/// /// Die Schlafdauer je Nacht als Diagrammreihe — **gehalten**, nicht je
/// /// Bild gerechnet (Hausregel 2).
/// final Provider<List<({DateTime tag, double wert})>>
///     schlafTagewerteProvider;
/// ```
///
/// ## Was hier geprüft wird — und was nicht
///
/// `CLAUDE.md`: Widget-Tests prüfen **Zustände und Übergänge**, nicht Layout
/// und Beschriftung. Kein Test schreibt einen Satz fest; wo ein Text eine
/// *Regel* trägt, wird die Regel geprüft:
///
/// - Der Verlauf **hat** einen Graphen, nicht nur dessen Kopf.
/// - Die Stufen sind `W M 6M J`, aufgeschlagen wird auf `W` — **kein `T`**.
///   Die Begründung steht im Entwurf und ist teuer bezahlt: Jeder Punkt
///   dieses Diagramms *ist* schon eine Nacht, und eine Nacht hat keine
///   Stundenwerte.
/// - Die Fußzeile sagt, was ein Balken ist — und sagt es auf `6M`/`J`
///   **anders**, weil ein Balken dort ein Monatsmittel ist und keine
///   Nacht.
/// - Die Einheit des Fensters nennt die Nacht als Bezug, die eines
///   abgelesenen Punktes nicht: Ein einzelner Punkt ist kein Schnitt je
///   Nacht (`unit`/`pickedUnit` im Entwurfsboard).
/// - Eine leere Reihe erzeugt **keine Null** — eine erfundene 0 ist genau
///   `01`.
/// - In der Karte steht **ein** Durchschnitt, nicht zwei über verschiedene
///   Zeiträume.
/// - Die Reihe kommt aus einem **gehaltenen** Provider (Hausregel 2), und
///   eine Nacht ohne Schlafminuten fehlt darin, statt als 0 zu erscheinen.
///
/// **Nicht geprüft, bewusst:**
///
/// - **Die Gesten des Diagramms** (Blättern, Ablesen) und die Pixel des
///   Graphen. Beides gehört zu #130 und steht in `zeitdiagramm_test.dart`.
/// - **Die Verdichtung selbst.** Sie liegt in `diagramm_zeitraum.dart` und
///   darunter im Kern; hier entsteht kein zweites Stufen-Enum.
/// - **Die Formatierung der Kopfzahl.** `Zeitdiagramm` formatiert dezimal;
///   ob über dem Schlafdiagramm „6,7" oder „6:40" stehen soll, ist eine
///   Frage an Tim und **kein** Fall dieser Datei. Ein Formatierer-Haken am
///   Bauteil wäre eine Änderung an fremdem, festgenageltem Code.
/// - **Eine Ziellinie.** Der Entwurf zeigt keine; ob das Schlafziel eine
///   bekommt, entscheidet Tim.
///
/// ## Nachgezogen am 03.11.2026 für #253
///
/// „Der Abschnitt des Schirms trägt das Diagramm" klappt den Abschnitt
/// seither **auf**, bevor es nachsieht. Der Verlauf sitzt am Fuß des
/// Schirms in einem `KlappAbschnitt` und ist beim Öffnen zugeklappt (Tim am
/// 03.11.2026: „sonst ist die Seite so lang"), also steht sein Inhalt ohne
/// Zutun nicht im Baum.
///
/// **Die Zusicherungen stehen Wort für Wort unverändert**; dazugekommen ist
/// allein der Weg dorthin — ein Tipp auf `Key('schlaf-verlauf-kopf')`. Wer
/// den Tipp für überflüssig hält und ihn entfernt, macht den Fall rot, ohne
/// dass am Schirm etwas falsch wäre.
///
/// **Was der Fall seither nicht mehr sagt:** dass das Diagramm ohne Zutun
/// sichtbar ist. Das war vorher mitgeprüft, ist aber seit #253
/// ausdrücklich nicht mehr gewollt — dass der Abschnitt **zu** ist, prüft
/// `schlaf_klapp_test.dart`. Übrig bleibt die Aussage, auf die es hier
/// ankommt: Der Abschnitt trägt das Diagramm, und seine Reihe kommt aus dem
/// gehaltenen Provider, statt im Schirm gerechnet zu werden.
///
/// ## Nachgezogen am 03.11.2026 für #255
///
/// **Der Verlauf zeichnet eine Linie, keine Balken.** Entschieden hat das
/// Tim am 03.11.2026: „Die Linie gewinnt — die App zieht nach, nicht das
/// Board." Der Entwurf (`VERLAUF_KARTE` in `docs/screens/screens/schlaf.js`)
/// ist ein `chartCard`, und das kann nur `lineChart`.
///
/// Geändert ist deshalb **eine** Zusicherung — „eine Nacht ist ein Balken"
/// wurde zu „eine Nacht ist ein Punkt auf einer Linie" —, dazu zwei neue:
/// Die Fußzeile nennt in **beiden** Fassungen keinen Balken mehr. Sie sagte
/// bis dahin „Je Punkt eine Nacht. Der Balken zeigt die Zeit im Schlaf" und
/// damit zweierlei in einem Satz.
///
/// ## Zurückgenommen am 16.11.2026 für #504
///
/// **Der Absatz darüber gilt nicht mehr.** Tim hat am 13.11.2026 die
/// Entscheidung aus #255 umgekehrt: Der Verlauf zeichnet wieder **Balken**,
/// und jeder Balken ist in sich nach Schlafphasen gestapelt. Er bleibt hier
/// stehen, weil er erklärt, warum diese Datei zwischendurch vom Punkt
/// sprach — nicht, weil er noch beschreibt, was gilt.
///
/// Angefasst sind deshalb genau die Zusicherungen, die an der umgekehrten
/// Entscheidung hingen (mit `TEST_AENDERN=1` committet):
///
/// - „eine Nacht ist ein Punkt auf einer Linie" ist **entfallen**. Dass der
///   Verlauf Balken zeichnet, steht jetzt in `schlaf_verlauf_stapel_test.
///   dart`, zusammen mit allem anderen, was #504 bringt — zwei Dateien, die
///   dieselbe Entscheidung festnageln, laufen beim nächsten Mal auseinander.
/// - Die beiden Fußzeilen-Fälle fragen nach dem **Balken** statt nach dem
///   Punkt. Die Regel dahinter ist unverändert: Die Fußzeile nennt genau
///   **eine** Darstellung, und ab `6M` nicht mehr die Nacht.
///
/// Alles Übrige steht Wort für Wort wie vorher.
void main() {
  // Montag, 12.10.2026, 09:15 Berlin (CEST, +2).
  final jetzt = DateTime.utc(2026, 10, 12, 7, 15);

  DateTime tagesbeginn(int tag) =>
      BerlinCalendar.startOfDay(DateTime.utc(2026, 10, tag));

  DateTime berlin(int tag, int stunde, [int minute = 0]) =>
      DateTime.utc(2026, 10, tag, stunde - 2, minute);

  // ───────────────────────────────────────────────────────────────────────
  // Daten
  // ───────────────────────────────────────────────────────────────────────

  SleepNight nachtAus({
    required DateTime tag,
    required DateTime beginn,
    required List<(SleepStage, int)> phasen,
  }) {
    final abschnitte = <SleepSegment>[];
    var zeiger = beginn;
    for (final (phase, minuten) in phasen) {
      final ende = zeiger.add(Duration(minutes: minuten));
      abschnitte.add(SleepSegment(stage: phase, start: zeiger, end: ende));
      zeiger = ende;
    }
    return SleepNight(
      date: tag,
      session: SleepSession(segments: abschnitte),
      naps: const [],
    );
  }

  /// Eine Nacht mit allen vier Phasen, 23:00 bis 06:00 — 405 Schlafminuten
  /// und 15 Wachminuten.
  SleepNight nachtVon(int tag) => nachtAus(
    tag: tagesbeginn(tag),
    beginn: berlin(tag - 1, 23),
    phasen: const [
      (SleepStage.core, 120),
      (SleepStage.deep, 60),
      (SleepStage.awake, 15),
      (SleepStage.rem, 90),
      (SleepStage.core, 135),
    ],
  );

  /// Eine Nacht, in der die Uhr **nur Wachliegen** aufgezeichnet hat. Sie
  /// hat keine Schlafminuten und gehört damit in keine Reihe.
  SleepNight wachnachtVon(int tag) => nachtAus(
    tag: tagesbeginn(tag),
    beginn: berlin(tag - 1, 23),
    phasen: const [(SleepStage.awake, 60)],
  );

  List<SleepNight> reihe({int anzahl = 14}) => [
    for (var i = anzahl - 1; i >= 0; i--) nachtVon(12 - i),
  ];

  final werte = [
    for (var tag = 6; tag <= 12; tag++)
      (tag: tagesbeginn(tag), wert: 6.0 + tag % 3 * 0.4),
  ];

  // ───────────────────────────────────────────────────────────────────────
  // Testhüllen
  // ───────────────────────────────────────────────────────────────────────

  Future<void> zeige(WidgetTester tester, Widget inhalt) async {
    tester.view.physicalSize = const Size(900, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: SingleChildScrollView(child: inhalt),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  ProviderContainer behaelter({Messwert<List<SleepNight>>? schlaf}) {
    // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        clockProvider.overrideWithValue(() => jetzt),
        healthProvider.overrideWithValue(_FakeHealthReading()),
        sleepProvider.overrideWith(
          () => _Naechte(
            schlaf ??
                Bekannt<List<SleepNight>>(reihe(), stand: jetzt, laeuft: false),
          ),
        ),
        zieleProvider.overrideWith(() => _Ziele(Ziele.vorbelegung)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  // ───────────────────────────────────────────────────────────────────────
  // Helfer
  // ───────────────────────────────────────────────────────────────────────

  Zeitdiagramm diagramm(WidgetTester tester) =>
      tester.widget<Zeitdiagramm>(find.byType(Zeitdiagramm));

  String textUnter(WidgetTester tester, Finder bereich) => tester
      .widgetList<Text>(
        find.descendant(of: bereich, matching: find.byType(Text)),
      )
      .map(textOf)
      .join(' ');

  String fussnote(WidgetTester tester) => textUnter(
    tester,
    find.byKey(const Key('diagramm-fussnote')),
  ).toLowerCase();

  String kopfzeile(WidgetTester tester) =>
      textUnter(tester, find.byKey(const Key('diagramm-kopfzeile')));

  // ───────────────────────────────────────────────────────────────────────

  group('Die Karte ist ein Diagramm, nicht nur dessen Kopf', () {
    testWidgets('sie trägt einen Graphen samt Zeitraumleiste', (tester) async {
      await zeige(tester, SchlafVerlauf(reihe: werte));

      expect(
        find.byType(Zeitdiagramm),
        findsOneWidget,
        reason:
            'bis #130 zeigte die Karte nur Durchschnitt, Zeitraum und '
            'Fußnote — genau das ist #139',
      );
      expect(find.byType(Zeitraumleiste), findsOneWidget);
    });

    testWidgets('die Reihe geht unverändert an das Bauteil', (tester) async {
      await zeige(tester, SchlafVerlauf(reihe: werte));

      expect(
        diagramm(tester).reihe,
        werte,
        reason:
            'die Verdichtung macht `diagrammPunkte`, nicht der Schirm — '
            'zwei Rechnungen wären zwei Wahrheiten über dasselbe Diagramm',
      );
    });

    // „eine Nacht ist ein Punkt auf einer Linie, kein Balken" stand hier
    // bis zum 16.11.2026 (#255). Tim hat die Entscheidung am 13.11.2026
    // umgekehrt; die Darstellung des Verlaufs wird seither in
    // `schlaf_verlauf_stapel_test.dart` festgenagelt (#504).
  });

  group('Die Stufen', () {
    testWidgets('W M 6M J — und kein T', (tester) async {
      await zeige(tester, SchlafVerlauf(reihe: werte));

      expect(diagramm(tester).stufen, [
        DiagrammStufe.woche,
        DiagrammStufe.monat,
        DiagrammStufe.halbjahr,
        DiagrammStufe.jahr,
      ]);
    });

    testWidgets('aufgeschlagen wird auf der Woche', (tester) async {
      await zeige(tester, SchlafVerlauf(reihe: werte));

      expect(
        tester.widget<Zeitraumleiste>(find.byType(Zeitraumleiste)).gewaehlt,
        DiagrammStufe.woche,
        reason: 'die Startstufe ist die kleinste angebotene (#7)',
      );
    });
  });

  group('Was die Karte über ihre Zahlen sagt', () {
    testWidgets('die Fußzeile nennt den Balken und das Gezählte', (
      tester,
    ) async {
      await zeige(tester, SchlafVerlauf(reihe: werte));

      final text = fussnote(tester);
      expect(text, contains('nacht'));
      expect(
        text,
        contains('bett'),
        reason:
            'gezählt wird die Zeit im Schlaf, nicht die Zeit im Bett — den '
            'Unterschied benennt der Entwurf ausdrücklich',
      );
      expect(
        text,
        isNot(contains('punkt')),
        reason:
            '#255: „Je Punkt eine Nacht. Der Balken zeigt …" nannte zwei '
            'Darstellungen in einem Satz, und seit #504 zeichnet der '
            'Verlauf Balken — „Punkt" ist jetzt das Falsche',
      );
    });

    testWidgets('ab 6M ist ein Balken keine Nacht mehr, und das steht da', (
      tester,
    ) async {
      await zeige(tester, SchlafVerlauf(reihe: werte));

      expect(fussnote(tester), contains('je balken eine nacht'));

      await tester.tap(find.text('6M'));
      await tester.pumpAndSettle();

      final text = fussnote(tester);
      expect(
        text,
        isNot(contains('je balken eine nacht')),
        reason:
            'ab 6M ist ein Balken ein Monatsmittel — „je Balken eine '
            'Nacht" wäre dort schlicht falsch',
      );
      expect(text, contains('monat'));
      expect(
        text,
        isNot(contains('punkt')),
        reason: '#504: auch die zweite Fassung der Fußnote nennt den Balken',
      );
    });

    testWidgets('die Einheit des Fensters nennt die Nacht, die abgelesene '
        'nicht', (tester) async {
      await zeige(tester, SchlafVerlauf(reihe: werte));

      final d = diagramm(tester);
      expect(
        d.einheit,
        contains('Nacht'),
        reason: 'der Wert des Fensters ist ein Schnitt je Nacht',
      );
      expect(d.einheitAbgelesen, isNotNull);
      expect(
        d.einheitAbgelesen,
        isNot(contains('Nacht')),
        reason:
            'ein einzelner Punkt ist der Wert *dieser* Nacht, kein Schnitt '
            'je Nacht (`pickedUnit` im Entwurfsboard)',
      );
    });

    testWidgets('in der Karte steht genau ein Durchschnitt', (tester) async {
      await zeige(tester, SchlafVerlauf(reihe: werte));

      final treffer = 'durchschnitt'
          .allMatches(
            textUnter(tester, find.byType(SchlafVerlauf)).toLowerCase(),
          )
          .length;
      expect(
        treffer,
        1,
        reason:
            'der Kopf des Bauteils rechnet über das sichtbare Fenster; ein '
            'zweiter Schnitt über sieben Nächte daneben wären zwei '
            'Wahrheiten in einer Karte',
      );
    });

    testWidgets('eine leere Reihe erfindet keine Null', (tester) async {
      await zeige(tester, const SchlafVerlauf(reihe: []));

      expect(
        kopfzeile(tester),
        isNot(matches(RegExp(r'\d'))),
        reason:
            'ohne Messung steht „—" und keine Zahl — eine 0 behauptete eine '
            'Nacht ohne Schlaf (`01`)',
      );
    });
  });

  group('Die Reihe kommt aus einem gehaltenen Provider', () {
    testWidgets('der Abschnitt des Schirms trägt das Diagramm', (tester) async {
      final container = behaelter();
      final router = AppRouter();

      tester.view.physicalSize = const Size(900, 8000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: CupertinoApp(home: SchlafView(router: router)),
        ),
      );
      await tester.pumpAndSettle();

      // Zugeklappt seit #253 — der Inhalt entsteht erst beim Aufklappen.
      await tester.tap(find.byKey(const Key('schlaf-verlauf-kopf')));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const Key('schlaf-verlauf')),
          matching: find.byType(Zeitdiagramm),
        ),
        findsOneWidget,
      );
      expect(
        diagramm(tester).reihe,
        container.read(schlafTagewerteProvider),
        reason: 'der Schirm liest den Provider, er rechnet nicht selbst',
      );
    });

    test('ein Wert je Nacht mit Schlaf, in Stunden, chronologisch', () async {
      final container = behaelter(
        schlaf: Bekannt<List<SleepNight>>(
          [nachtVon(10), wachnachtVon(11), nachtVon(12)],
          stand: jetzt,
          laeuft: false,
        ),
      );

      // `sleepProvider` ist ein `AsyncNotifier`: Beim ersten **synchronen**
      // Lesen steht dort `AsyncLoading`, `.value` ist `null` und die Reihe
      // bleibt leer. Ohne dieses `await` misst der Fall den Testaufbau statt
      // der Rechnung — keine Umsetzung könnte ihn grün machen.
      await container.read(sleepProvider.future);

      final gelesen = container.read(schlafTagewerteProvider);

      expect(
        gelesen.map((e) => e.tag),
        [tagesbeginn(10), tagesbeginn(12)],
        reason:
            'eine Nacht ohne Schlafminuten fehlt — sie ist keine gemessene '
            'Null, und das Diagramm zeichnete sie sonst als 0 (`01`)',
      );
      expect(gelesen.first.wert, closeTo(405 / 60, 0.001));
    });

    test(
      'die Reihe wird gehalten, nicht bei jedem Zugriff gerechnet',
      () async {
        final container = behaelter();
        // Ohne das `await` verglich dieser Fall zweimal dieselbe **leere**
        // Liste und war grün, ohne etwas zu prüfen.
        await container.read(sleepProvider.future);

        expect(
          container.read(schlafTagewerteProvider),
          same(container.read(schlafTagewerteProvider)),
          reason: 'Hausregel 2 — eine berechnete Eigenschaft rechnete je Bild',
        );
      },
    );
  });
}

/// Steuerbarer Ableger des echten Notifiers.
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

/// Eine Quelle, die nichts liefert — der Verlauf hängt an [sleepProvider],
/// nicht am Kanal.
class _FakeHealthReading extends HealthReadingAttrappe {}
