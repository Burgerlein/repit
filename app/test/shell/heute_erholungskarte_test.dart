import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/core/messwert.dart';
import 'package:repit/data/ziele.dart';
import 'package:repit/design/erholungs_karte.dart';
import 'package:repit/design/palette.dart';
import 'package:repit/design/section_header.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_types.dart';
import 'package:repit/shell/heute_view.dart';
import 'package:repit/shell/router.dart';

import '../design/support.dart' show textOf;

/// Die Erholungskarte auf **Heute** — `docs/screens/screens/heute.js`,
/// `const RECOVERY` und `sectionHead('Erholung')` — der Verweis „Details ›"
/// ist seit #516 weg (Tim, 16.11.2026).
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden.
///
/// ## Warum eine eigene Datei
///
/// `heute_view_test.dart` beschreibt den Schirm als Ganzes und ist beim
/// Erholungsblock bewusst grob geblieben („HRV/Ruhepuls/Atmung echt, Schlaf
/// fehlt mit Grund") — das war richtig, solange es keinen Schlaf-Provider
/// gab. Jetzt gibt es ihn, und die Karte bekommt vier eigene Zusagen, die
/// alle an **Zuständen** hängen. Die gehören zusammen und nicht verstreut
/// in eine Datei, die von Ringen, Kacheln und Platzhaltern handelt.
///
/// ## Was der Entwurf verlangt (und gebaut nicht da war)
///
/// | Entwurf | gebaut (26.10.) |
/// |---|---|
/// | Gruppenkopf „Erholung" (seit #516 ohne Verweis) | nur „Erholung" |
/// | Überschrift **nach Verdikt** | immer „Erholung" |
/// | Untertitel nach Verdikt | immer derselbe Satz |
/// | unter jedem Wert der Normalwert („Ø 6:40", „Median 58", …) | keine Bildunterschrift |
/// | Schlaf als Zahl | „Schlaf ist noch nicht angebunden" |
///
/// Die vier Überschriften stehen im Entwurf als feste Zeichenketten und
/// werden hier **wörtlich** festgeschrieben — anders als sonst in dieser
/// Testreihe, wo kein Satz festgenagelt wird. Der Grund: Es ist keine
/// Beschriftung, sondern eine Tabelle Zustand → Text, und ihr Wert liegt
/// gerade darin, dass sie je Zustand verschieden ist. Ein Test, der nur
/// „irgendein Text" prüft, ließe das generische „Erholung" durch.
///
/// `postOperative` fehlt in dieser Datei, wie schon in
/// `erholung_view_test.dart`: Der Schirm kann den Zustand heute nicht
/// erzeugen (`isPostOperative` bleibt `false`, #41 fehlt), und ein
/// Ereignisdatum im Quelltext verbietet die Spec. Die Überschrift dafür
/// („Erholung nach der OP") steht trotzdem im Entwurf und gehört in die
/// Tabelle des Umsetzenden — sie ist hier nur nicht prüfbar.
///
/// ## Was hier **nicht** geprüft wird
///
/// - Die Reihenfolge der vier Werte. Der Entwurf zeigt Schlaf · HRV ·
///   Ruhepuls · Atmung, gebaut ist HRV · Ruhepuls · Atmung · Schlaf. Das
///   ist gemeldet, aber niemand hat es entschieden, und ein Test darauf
///   wäre eine eigene Entscheidung.
/// - Dass die vier Werte **mittig** statt linksbündig stehen (Tims Befund
///   vom 27.10.) — Layout, also Prüfanleitung statt Test.
/// - Welchen Weg die Karte nimmt, um an die Erholungsdaten zu kommen.
///   `erholungProvider` liegt bereit und hält seinen Wert (Hausregel 2);
///   ob der Schirm ihn liest oder einen eigenen abgeleiteten Provider
///   bekommt, ist Sache des Umsetzenden. Nur gerechnet werden darf nicht
///   bei jedem Bild (`docs/todo/03`).
///
/// ## Zahlen in dieser Datei
///
/// Alle erfunden (`CLAUDE.md`, Spec Abschnitt 12).
void main() {
  // Montag, 12.10.2026, 09:15 Berliner Zeit (CEST, +2).
  final jetzt = DateTime.utc(2026, 10, 12, 7, 15);

  DateTime tagesbeginn(int tag) =>
      BerlinCalendar.startOfDay(DateTime.utc(2026, 10, tag));

  String tagKey(int tag) => '2026-10-${tag.toString().padLeft(2, '0')}';

  DailyMetrics tagwert(int tag, {int? ruhepuls = 52, double? hrv = 60}) =>
      DailyMetrics(
        tag: tagKey(tag),
        restingHR: ruhepuls,
        hrvMs: hrv,
        respRate: 13,
        steps: 842,
        exerciseMinutes: 20,
      );

  SleepNight nachtVon(int tag, {double stunden = 7}) {
    final ende = DateTime.utc(2026, 10, tag, 4); // 06:00 Berlin
    final beginn = ende.subtract(Duration(minutes: (stunden * 60).round()));
    return SleepNight(
      date: tagesbeginn(tag),
      session: SleepSession(
        segments: [
          SleepSegment(stage: SleepStage.core, start: beginn, end: ende),
        ],
      ),
    );
  }

  List<DailyMetrics> tage({bool mitHeute = true}) => [
    for (var t = 3; t <= 11; t++) tagwert(t),
    if (mitHeute) tagwert(12),
  ];

  /// Die neun Nächte davor dauern sieben Stunden, heute [heuteStunden] —
  /// so sind Messwert und Vergleichswert auseinanderzuhalten.
  List<SleepNight> naechte({bool mitHeute = true, double heuteStunden = 6.5}) =>
      [
        for (var t = 3; t <= 11; t++) nachtVon(t),
        if (mitHeute) nachtVon(12, stunden: heuteStunden),
      ];

  /// Die Nachtwerte dieser Hülle — sie **spiegeln** die Tageswerte (#193,
  /// Stufe 4).
  ///
  /// Seit Stufe 4 kommen Ruhepuls, HRV und Atemfrequenz aus dem
  /// Nachtfenster statt aus `DailyMetrics` (Tims Entscheidung vom
  /// 02.11.2026; Begründung und Messung stehen im Kopf von
  /// `erholung_nachtwerte_test.dart`). Damit die Zusicherungen dieser Datei
  /// weiter dasselbe prüfen wie vorher, liefert die Hülle dieselben Zahlen
  /// noch einmal als Nachtwerte: **Die Quelle wechselt, die Vorlage
  /// nicht.**
  Messwert<Map<String, NightVitals>> nachtwerteAus(List<DailyMetrics> tage) =>
      Bekannt<Map<String, NightVitals>>({
        for (final tag in tage)
          tag.tag: NightVitals(
            restingHeartRate: tag.restingHR?.toDouble(),
            hrv: tag.hrvMs,
            respiratoryRate: tag.respRate,
          ),
      }, stand: jetzt, laeuft: false);

  ({ProviderContainer container, AppRouter router, Widget app}) harness({
    List<DailyMetrics>? tageswerte,
    List<SleepNight>? schlaf,
  }) {
    final router = AppRouter();
    // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        clockProvider.overrideWithValue(() => jetzt),
        dailyMetricsProvider.overrideWith(
          () => _Tageswerte(
            Bekannt<List<DailyMetrics>>(
              tageswerte ?? tage(),
              stand: jetzt,
              laeuft: false,
            ),
          ),
        ),
        // #193, Stufe 4: Ruhepuls, HRV und Atemfrequenz kommen aus dem
        // Nachtfenster.
        nachtWerteProvider.overrideWith(
          () => _Nachtwerte(nachtwerteAus(tageswerte ?? tage())),
        ),
        sleepProvider.overrideWith(
          () => _Naechte(
            Bekannt<List<SleepNight>>(
              schlaf ?? naechte(),
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
      router: router,
      app: UncontrolledProviderScope(
        container: container,
        child: CupertinoApp(
          home: CupertinoPageScaffold(child: HeuteView(router: router)),
        ),
      ),
    );
  }

  Future<void> zeige(WidgetTester tester, Widget app) async {
    tester.view.physicalSize = const Size(900, 4200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
  }

  ErholungsKarte karte(WidgetTester tester) =>
      tester.widget<ErholungsKarte>(find.byType(ErholungsKarte));

  VitalWert vital(WidgetTester tester, String teil) =>
      karte(tester).vitalwerte.firstWhere(
        (v) => v.name.toLowerCase().contains(teil),
        orElse: () => throw StateError('kein Vitalwert enthält "$teil"'),
      );

  /// Wörtlich wie in `mehr_view_test.dart` und `erholung_view_test.dart`.
  bool tippbar(Element element) {
    var gefunden = false;
    element.visitAncestorElements((vorfahre) {
      final widget = vorfahre.widget;
      if (widget is GestureDetector && widget.onTap != null) {
        gefunden = true;
        return false;
      }
      if (widget is CupertinoButton && widget.onPressed != null) {
        gefunden = true;
        return false;
      }
      return true;
    });
    return gefunden;
  }

  group('Der Gruppenkopf', () {
    // **Seit #516 ohne Verweis** (Tim, 16.11.2026). Bis dahin verlangte
    // dieser Fall „Details ›"; die Tür ist seither allein die Karte, und
    // ihr Chevron zeigt sie an. Der Fall darunter bleibt trotzdem stehen —
    // er bewacht, dass kein „›" ohne Ziel zurückkommt.
    testWidgets('heißt „Erholung" und trägt keinen Verweis', (tester) async {
      final h = harness();
      await zeige(tester, h.app);

      final kopf = tester
          .widgetList<SectionHeader>(find.byType(SectionHeader))
          .firstWhere((s) => s.title == 'Erholung');

      expect(kopf.zusatz, isNull);
    });

    testWidgets('und das „›" führt auch wirklich irgendwohin', (tester) async {
      final h = harness();
      await zeige(tester, h.app);

      for (final element in find
          .byWidgetPredicate((w) => w is Text && textOf(w).contains('›'))
          .evaluate()) {
        expect(
          tippbar(element),
          isTrue,
          reason:
              '„${textOf(element.widget as Text)}" sieht aus wie eine Tür. '
              'Eine Zeile, die drückbar aussieht und nirgendwohin führt, '
              'ist ein Fehler (docs/screens/pruefen.mjs)',
        );
      }
    });
  });

  group('Überschrift und Untertitel folgen dem Verdikt', () {
    testWidgets('alle vier Werte im Normalbereich: „Gut erholt"', (
      tester,
    ) async {
      final h = harness();
      await zeige(tester, h.app);

      expect(karte(tester).ueberschrift, 'Gut erholt');
      expect(
        karte(tester).akzent.toARGB32(),
        CupertinoDynamicColor.resolve(
          Palette.ok,
          tester.element(find.byType(ErholungsKarte)),
        ).toARGB32(),
      );
    });

    testWidgets('mit einem Warnsignal: „Achte auf dich"', (tester) async {
      final h = harness(schlaf: naechte(heuteStunden: 5));
      await zeige(tester, h.app);

      expect(karte(tester).ueberschrift, 'Achte auf dich');
    });

    testWidgets('ohne jeden Wert: „Keine Werte von der Uhr"', (tester) async {
      final h = harness(
        tageswerte: tage(mitHeute: false),
        schlaf: naechte(mitHeute: false),
      );
      await zeige(tester, h.app);

      expect(karte(tester).ueberschrift, 'Keine Werte von der Uhr');
      // Apple verrät den Lesestatus nicht — beide Möglichkeiten werden
      // benannt, nie „nichts getrackt" (`CLAUDE.md`).
      final satz = karte(tester).satz.toLowerCase();
      expect(satz, contains('aufgezeichnet'));
      expect(satz, contains('freigegeben'));
    });

    testWidgets('die Überschrift ist nie das generische „Erholung"', (
      tester,
    ) async {
      for (final fall in <(String, List<SleepNight>)>[
        ('ruhig', naechte()),
        ('ein Signal', naechte(heuteStunden: 5)),
      ]) {
        final h = harness(schlaf: fall.$2);
        await zeige(tester, h.app);

        expect(karte(tester).ueberschrift, isNot('Erholung'), reason: fall.$1);
      }
    });

    testWidgets('und der Untertitel unterscheidet die Zustände mit', (
      tester,
    ) async {
      final h = harness();
      await zeige(tester, h.app);
      final ruhig = karte(tester).satz;

      final h2 = harness(schlaf: naechte(heuteStunden: 5));
      await zeige(tester, h2.app);

      expect(
        karte(tester).satz,
        isNot(ruhig),
        reason:
            'ein Untertitel, der bei jedem Verdikt derselbe ist, trägt '
            'keine Aussage',
      );
    });
  });

  group('Die vier Werte', () {
    testWidgets('Schlaf ist verdrahtet und steht als Zahl da', (tester) async {
      final h = harness();
      await zeige(tester, h.app);

      final schlaf = vital(tester, 'schlaf');
      expect(
        schlaf.wert,
        isNotNull,
        reason: 'es gibt einen Schlaf-Provider und eine Cache-Tabelle',
      );
      expect(
        RegExp(r'\d').hasMatch(schlaf.wert!),
        isTrue,
        reason: 'die Nacht von heute: 6:30 h',
      );
    });

    testWidgets('und niemand behauptet mehr, er sei nicht angebunden', (
      tester,
    ) async {
      final h = harness();
      await zeige(tester, h.app);

      final texte = tester
          .widgetList<Text>(find.byType(Text))
          .map(textOf)
          .join(' ')
          .toLowerCase();

      expect(
        texte,
        isNot(contains('schlaf ist noch nicht angebunden')),
        reason:
            'eine Zusage, die nicht mehr stimmt, bleibt nicht stehen '
            '(`CLAUDE.md`)',
      );
    });

    testWidgets('jeder Wert trägt seinen Normalwert als Bildunterschrift', (
      tester,
    ) async {
      final h = harness();
      await zeige(tester, h.app);

      for (final teil in const ['schlaf', 'hrv', 'puls', 'atem']) {
        final wert = vital(tester, teil);
        expect(wert.hinweis, isNotNull, reason: teil);
        expect(
          RegExp(r'\d').hasMatch(wert.hinweis!),
          isTrue,
          reason:
              '$teil: der Entwurf zeigt „Ø 6:40", „Median 58", „Ø 66", '
              '„Normal 14,0" — eine Zahl, kein Satz',
        );
      }
    });

    testWidgets(
      'ohne Vergleichswert steht dort keine erfundene Zahl',
      (tester) async {
        // Nur heute, kein einziger Tag davor: Für einen Median braucht
        // `HealthMedian` fünf Werte, hier gibt es keinen.
        final h = harness(tageswerte: [tagwert(12)], schlaf: [nachtVon(12)]);
        await zeige(tester, h.app);

        for (final teil in const ['hrv', 'puls', 'atem']) {
          final hinweis = vital(tester, teil).hinweis;
          if (hinweis == null) continue;
          expect(
            RegExp(r'\d').hasMatch(hinweis),
            isFalse,
            reason:
                '$teil: ohne Median gibt es keinen Normalwert — und eine '
                'Zahl, die niemand gemessen hat, ist schlimmer als keine',
          );
        }
      },
    );

    testWidgets('ein fehlender Messwert bleibt ein fehlender Messwert', (
      tester,
    ) async {
      final h = harness(
        tageswerte: tage(mitHeute: false),
        schlaf: naechte(mitHeute: false),
      );
      await zeige(tester, h.app);

      for (final teil in const ['schlaf', 'hrv', 'puls', 'atem']) {
        expect(
          vital(tester, teil).wert,
          isNull,
          reason: '$teil: kein erfundener Wert, keine stillschweigende Null',
        );
      }
    });
  });
}

/// Steuerbare Ableger der echten Notifier — siehe `heute_view_test.dart`:
/// Riverpods Provider-Typen sind invariant, ein eigenständiger
/// `AsyncNotifier` erfüllt die `overrideWith`-Signatur nicht.
class _Tageswerte extends DailyMetricsNotifier {
  _Tageswerte(this.wert);

  final Messwert<List<DailyMetrics>> wert;

  @override
  Future<Messwert<List<DailyMetrics>>> build() async => wert;
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

class _Nachtwerte extends NachtWerteNotifier {
  _Nachtwerte(this.wert);

  final Messwert<Map<String, NightVitals>> wert;

  @override
  Future<Messwert<Map<String, NightVitals>>> build() async => wert;
}
