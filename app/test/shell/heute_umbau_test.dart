import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/core/messwert.dart';
import 'package:repit/data/cache.dart';
import 'package:repit/data/ziele.dart';
import 'package:repit/design/erholungs_karte.dart';
import 'package:repit/design/grosse_ueberschrift.dart';
import 'package:repit/design/kacheln.dart';
import 'package:repit/design/section_header.dart';
import 'package:repit/ernaehrung/strichcode_leser.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_types.dart';
import 'package:repit/shell/heute_view.dart';
import 'package:repit/shell/root_view.dart';
import 'package:repit/shell/router.dart';

import '../design/support.dart' show textOf;
import '../ernaehrung/kamera_attrappe.dart';

/// Der Umbau von Home nach dem Vorbild der alten App (#501).
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung**
/// (`CLAUDE.md`). Diese Datei darf ausgeführt, aber nicht verändert
/// werden.
///
/// ## Was Tim entschieden hat (13. und 16.11.2026)
///
/// 1. ~~Der Kopf trägt groß das Datum, „Heute" steht in der
///    Navigationsleiste.~~ **Seit #514 (16.11.2026) überholt:** Die
///    Leiste trägt den Wochentag, großes Datum und Stand-Zeile sind
///    weg — bewacht von `heute_leiste_wochentag_test.dart`. Die Zeile
///    „Woche 6 von 38 · Grundlage" bleibt ersatzlos gestrichen.
/// 2. **Zwischen Ringblock und Erholung steht „Heute Training"** — was
///    der Abschnitt zeigt, prüft `heute_training_test.dart`; hier steht
///    nur, dass er an dieser Stelle steht.
/// 3. **Die Erholungskarte zeigt Schlaf · Ruhepuls · HRV ·
///    Atemfrequenz**, jeden Wert mit seiner Einheit und darunter
///    durchgehend „Normal …".
/// 4. **Schritte und Gewicht bekommen ihren Verlauf zurück** — seit #510
///    zeigt die Linie nur die letzte Woche (Tim, 16.11.2026).
/// 5. **„Heute noch offen" und „Erledigt" stehen nicht mehr auf Home.**
///
/// ## Was hier nicht geprüft wird
///
/// Layout und Wortlaut (`CLAUDE.md`). Die Reihenfolge der vier Werte und
/// ihre Einheiten sind kein Wortlaut, sondern eine Tabelle Zustand →
/// Anzeige: Genau daran ist der Neubau von der alten App abgewichen, und
/// genau das soll nicht wieder auseinanderlaufen.
///
/// **Die Spaltenbreite steht hier nicht.** `flutter test` ersetzt die
/// Schriften durch eine Testschrift, in der jede Glyphe so breit ist wie
/// sie hoch ist; „11,8/min" misst dort ein Vielfaches dessen, was Barlow
/// Condensed auf dem Gerät braucht. Ob die Einheit in die Spalte passt,
/// gehört deshalb in die Prüfanleitung, nicht in einen Test, der das
/// Gegenteil beweisen würde (`CLAUDE.md`, „Was ein Widget-Test nicht
/// sehen kann…").
///
/// ## Zahlen in dieser Datei
///
/// Alle erfunden — und ausdrücklich **nicht** die aus #501. Das Issue
/// zeigt die neue Schreibweise an `8:38 h · 55 bpm · 50 ms · 11,8/min`;
/// die stammen aus Tims Bildschirmfoto der alten App, also aus seinen
/// echten Werten. Sie gehören nach `CLAUDE.md` in kein Mock und in
/// keinen Test, auch nicht „nur zum Ansehen". Geprüft wird hier die
/// Form, nicht die Zahl.
void main() {
  // Montag, 16.11.2026, 09:15 Berliner Zeit (CET, +1).
  final jetzt = DateTime.utc(2026, 11, 16, 8, 15);

  String tagKey(int tag) => '2026-11-${tag.toString().padLeft(2, '0')}';

  DateTime tagesbeginn(int tag) =>
      BerlinCalendar.startOfDay(DateTime.utc(2026, 11, tag, 12));

  /// Neun Tage davor und heute. Schritte steigen, das Gewicht steht nur
  /// an jedem zweiten Tag auf der Waage — so ist zu sehen, dass Lücken
  /// übersprungen und nicht als Null gezählt werden.
  List<DailyMetrics> fenster() => [
    for (var t = 7; t <= 16; t++)
      DailyMetrics(
        tag: tagKey(t),
        restingHR: 61,
        hrvMs: 74,
        respRate: 13.4,
        steps: 5000 + (t - 7) * 100,
        exerciseMinutes: 20,
        weightKg: t.isEven ? 57.0 + (t - 7) * 0.1 : null,
      ),
  ];

  SleepNight nacht(int tag, {double stunden = 7}) {
    final ende = DateTime.utc(2026, 11, tag, 5); // 06:00 Berlin
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

  List<SleepNight> naechte() => [for (var t = 7; t <= 16; t++) nacht(t)];

  Messwert<Map<String, NightVitals>> nachtwerteAus(List<DailyMetrics> tage) =>
      Bekannt<Map<String, NightVitals>>({
        for (final tag in tage)
          tag.tag: NightVitals(
            restingHeartRate: tag.restingHR?.toDouble(),
            hrv: tag.hrvMs,
            respiratoryRate: tag.respRate,
          ),
      }, stand: jetzt, laeuft: false);

  ({ProviderContainer container, Widget app}) harness({
    List<DailyMetrics>? tageswerte,
    List<SleepNight>? schlaf,
  }) {
    final werte = tageswerte ?? fenster();
    // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        clockProvider.overrideWithValue(() => jetzt),
        dailyMetricsProvider.overrideWith(
          () => _Tageswerte(
            Bekannt<List<DailyMetrics>>(werte, stand: jetzt, laeuft: false),
          ),
        ),
        nachtWerteProvider.overrideWith(() => _Nachtwerte(nachtwerteAus(werte))),
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
      app: UncontrolledProviderScope(
        container: container,
        child: const CupertinoApp(
          home: CupertinoPageScaffold(child: HeuteView()),
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

  List<String> abschnitte(WidgetTester tester) => tester
      .widgetList<SectionHeader>(find.byType(SectionHeader))
      .map((s) => s.title)
      .toList();

  ErholungsKarte karte(WidgetTester tester) =>
      tester.widget<ErholungsKarte>(find.byType(ErholungsKarte));

  KachelWert kachel(WidgetTester tester, String teil) =>
      tester.widget<Kacheln>(find.byType(Kacheln)).werte.firstWhere(
        (w) => w.label.toLowerCase().contains(teil),
        orElse: () => throw StateError('keine Kachel enthält "$teil"'),
      );

  // ───────────────────────────────────────────────────────────────────
  // 1. Der Kopf
  // ───────────────────────────────────────────────────────────────────

  // Die Gruppe „Der Kopf trägt groß das Datum" stand hier bis #514:
  // Tim hat am 16.11.2026 den großen Datumskopf samt Stand-Zeile
  // gestrichen, die Leiste trägt seither den Wochentag. Die geltende
  // Anforderung bewacht `heute_leiste_wochentag_test.dart`; eine Gruppe,
  // die das Gegenteil festschreibt, hätte hier nur noch Rot produziert.

  // ───────────────────────────────────────────────────────────────────
  // 2. und 5. Die Reihenfolge der Abschnitte
  // ───────────────────────────────────────────────────────────────────

  group('Die Abschnitte stehen in Tims Reihenfolge', () {
    testWidgets('Heute Training · Erholung · Zahlen — und sonst nichts', (
      tester,
    ) async {
      await zeige(tester, harness().app);

      expect(abschnitte(tester), ['Heute Training', 'Erholung', 'Zahlen']);
    });

    testWidgets('auch wenn gar keine Werte vorliegen', (tester) async {
      await zeige(tester, harness(tageswerte: const [], schlaf: const []).app);

      expect(
        abschnitte(tester),
        ['Heute Training', 'Erholung', 'Zahlen'],
        reason:
            'Überschriften stehen sofort da und in derselben Reihenfolge '
            'wie mit Werten (#24)',
      );
    });

    testWidgets(
      'und nirgends steht ein Satz über etwas, das noch fehlt',
      (tester) async {
        // **Zurückgeholt aus `heute_ernaehrung_test.dart`** (Fall „kein
        // Hinweis auf Trainingseinheiten", Tim am 05.11.2026: „sieht
        // hässlich aus, Tim weiß es"). Der Fall ist mit der Gruppe
        // „Heute noch offen" gefallen, und zwei seiner drei
        // Zusicherungen hingen auch wirklich an den gestrichenen
        // Abschnitten. Diese dritte nicht: Sie sucht im **ganzen
        // Schirm**, in jedem Zustand, und ist die einzige Stelle, die
        // Tims Entscheidung schirmweit durchsetzt.
        //
        // Sie zählt gerade jetzt: „Heute Training" ist selbst
        // unvollständig (ein geplanter Lauf steht noch nicht da), und
        // ein Satz „Läufe sind noch nicht angebunden" wäre die
        // naheliegende nächste Ergänzung.
        for (final (name, h) in <(String, Widget)>[
          ('mit Werten', harness().app),
          (
            'ohne Werte',
            harness(tageswerte: const [], schlaf: const []).app,
          ),
        ]) {
          await zeige(tester, h);
          final texte = tester
              .widgetList<Text>(find.byType(Text))
              .map((t) => textOf(t).toLowerCase());
          expect(
            texte.where((t) => t.contains('angebunden')),
            isEmpty,
            reason: '$name: kein Satz über etwas, das noch fehlt',
          );
          await tester.pumpWidget(const SizedBox.shrink());
        }
      },
    );

    testWidgets('„Heute noch offen" und „Erledigt" sind weg', (tester) async {
      await zeige(tester, harness().app);

      expect(abschnitte(tester), isNot(contains('Heute noch offen')));
      expect(abschnitte(tester), isNot(contains('Erledigt')));
      for (final schluessel in const [
        Key('heute-offen-mahlzeit-fruehstueck'),
        Key('heute-offen-mahlzeit-mittag'),
        Key('heute-offen-mahlzeit-snack'),
        Key('heute-offen-mahlzeit-abend'),
        Key('heute-offen-leer'),
        Key('heute-erledigt-mahlzeiten'),
        Key('heute-erledigt-leer'),
      ]) {
        expect(
          find.byKey(schluessel),
          findsNothing,
          reason:
              'Tim, 13.11.2026: „Erledigt kann weg, heute noch offen auch" '
              '— $schluessel',
        );
      }
    });
  });

  // ───────────────────────────────────────────────────────────────────
  // 3. Die Erholungskarte
  // ───────────────────────────────────────────────────────────────────

  group('Die Erholungskarte sieht aus wie in der alten App', () {
    testWidgets('Schlaf · Ruhepuls · HRV · Atemfrequenz, in dieser Folge', (
      tester,
    ) async {
      await zeige(tester, harness().app);

      expect(
        karte(tester).vitalwerte.map((v) => v.name).toList(),
        ['Schlaf', 'Ruhepuls', 'HRV', 'Atemfrequenz'],
        reason:
            'dieselbe Folge, die `RecoveryMetric` im Kern deklariert — '
            'die vierte Spalte heißt „Atemfrequenz", nicht „Atmung"',
      );
    });

    testWidgets('und die Folge bleibt, wenn kein Wert vorliegt', (
      tester,
    ) async {
      await zeige(tester, harness(tageswerte: const [], schlaf: const []).app);

      expect(
        karte(tester).vitalwerte.map((v) => v.name).toList(),
        ['Schlaf', 'Ruhepuls', 'HRV', 'Atemfrequenz'],
      );
      for (final wert in karte(tester).vitalwerte) {
        expect(
          wert.wert,
          isNull,
          reason: '${wert.name}: kein erfundener Wert, keine Null',
        );
      }
    });

    testWidgets('jeder Wert trägt seine Einheit', (tester) async {
      await zeige(tester, harness().app);

      final werte = {
        for (final v in karte(tester).vitalwerte) v.name: v.wert,
      };
      expect(werte['Schlaf'], matches(RegExp(r'^\d+:\d{2} h$')));
      expect(werte['Ruhepuls'], matches(RegExp(r'^\d+ bpm$')));
      expect(werte['HRV'], matches(RegExp(r'^\d+ ms$')));
      expect(werte['Atemfrequenz'], matches(RegExp(r'^\d+,\d/min$')));
    });

    testWidgets('und darunter steht durchgehend „Normal …", mit Einheit', (
      tester,
    ) async {
      await zeige(tester, harness().app);

      for (final wert in karte(tester).vitalwerte) {
        expect(
          wert.hinweis,
          startsWith('Normal '),
          reason:
              '${wert.name}: kein Durcheinander aus „Ø", „Median" und '
              '„Normal" mehr',
        );
      }
      final hinweise = {
        for (final v in karte(tester).vitalwerte) v.name: v.hinweis,
      };
      expect(hinweise['Schlaf'], endsWith(' h'));
      expect(hinweise['Ruhepuls'], endsWith(' bpm'));
      expect(hinweise['HRV'], endsWith(' ms'));
      expect(hinweise['Atemfrequenz'], endsWith('/min'));
    });

    testWidgets('die Schwelle hinter dem „·" bleibt weg', (tester) async {
      await zeige(tester, harness().app);

      for (final wert in karte(tester).vitalwerte) {
        expect(
          wert.hinweis,
          isNot(contains('·')),
          reason:
              '${wert.name}: vier Werte nebeneinander lassen dafür keinen '
              'Platz, und eine abgeschnittene Schwelle ist keine Auskunft '
              '(`shortCaption` in der alten App)',
        );
      }
    });

    testWidgets('ohne Vergleichswert steht dort gar nichts', (tester) async {
      // Ein einziger Tag: Für einen Median braucht `HealthMedian` fünf.
      await zeige(
        tester,
        harness(
          tageswerte: [fenster().last],
          schlaf: [nacht(16)],
        ).app,
      );

      for (final wert in karte(tester).vitalwerte) {
        expect(
          wert.hinweis,
          isNull,
          reason:
              '${wert.name}: eine Zahl, die niemand gemessen hat, ist '
              'schlimmer als keine',
        );
      }
    });
  });

  // ───────────────────────────────────────────────────────────────────
  // 4. Die Verläufe der Kacheln
  // ───────────────────────────────────────────────────────────────────

  group('Schritte und Gewicht zeigen ihren Verlauf', () {
    testWidgets('die Schrittekachel bekommt die letzte Woche des Fensters', (
      tester,
    ) async {
      await zeige(tester, harness().app);

      // Die Linie zeigt seit #510 nur die letzte Woche (Tim, 16.11.2026):
      // bei heute = Tag 16 also Tag 10 bis Tag 16. Der ISO-Tagesschlüssel
      // vergleicht lexikografisch richtig (CLAUDE.md).
      final woche = fenster().where((tag) => tag.tag.compareTo(tagKey(10)) >= 0);

      final verlauf = kachel(tester, 'schritt').verlauf;
      expect(verlauf, isNotNull);
      expect(
        verlauf!.length,
        greaterThanOrEqualTo(2),
        reason: 'sieben Tage der Woche liegen vor',
      );
      expect(
        verlauf,
        orderedEquals([for (final tag in woche) tag.steps!.toDouble()]),
        reason:
            'die Werte der letzten Woche, in ihrer Reihenfolge — die drei '
            'älteren Tage des Fensters gehören nicht in die Linie (#510)',
      );
    });

    testWidgets('die Gewichtskachel überspringt die Lücken', (tester) async {
      await zeige(tester, harness().app);

      final verlauf = kachel(tester, 'gewicht').verlauf;
      expect(verlauf, isNotNull);
      expect(
        verlauf,
        orderedEquals([
          for (final tag in fenster())
            if (tag.weightKg != null && tag.tag.compareTo(tagKey(10)) >= 0)
              tag.weightKg!,
        ]),
        reason:
            'ein Tag ohne Messung ist keine Null — er fällt aus der Linie, '
            'statt sie auf den Boden zu ziehen; und vor der Woche liegende '
            'Messungen gehören gar nicht hinein (#510)',
      );
    });

    testWidgets('zu wenige Punkte heißt keine Linie', (tester) async {
      await zeige(
        tester,
        harness(tageswerte: [fenster().last], schlaf: [nacht(16)]).app,
      );

      expect(
        kachel(tester, 'schritt').verlauf,
        anyOf(isNull, isEmpty),
        reason: 'aus einem Punkt wird keine Linie',
      );
      expect(
        find.byType(Verlaufslinie),
        findsNothing,
        reason: 'und die Kachel zeichnet auch keine',
      );
    });

    testWidgets('ohne jeden Wert bleibt die Kachel ohne Linie — aber da', (
      tester,
    ) async {
      await zeige(tester, harness(tageswerte: const [], schlaf: const []).app);

      expect(find.byType(Verlaufslinie), findsNothing);
      expect(
        tester.widget<Kacheln>(find.byType(Kacheln)).werte.map((w) => w.label),
        containsAll(<String>['Schritte', 'Gewicht']),
        reason: 'keine Kachel fällt weg, nur weil ihre Linie fehlt',
      );
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

class _Nachtwerte extends NachtWerteNotifier {
  _Nachtwerte(this.wert);

  final Messwert<Map<String, NightVitals>> wert;

  @override
  Future<Messwert<Map<String, NightVitals>>> build() async => wert;
}

class _Ziele extends ZieleNotifier {
  _Ziele(this.wert);

  final Ziele wert;

  @override
  Future<Ziele> build() async => wert;
}

/// Hält `HeuteView` im Tab-Gerüst harmlos — wie `_StillerNotifier` in
/// `root_view_test.dart`.
class _Stiller extends DailyMetricsNotifier {
  @override
  Future<Messwert<List<DailyMetrics>>> build() async =>
      LeerNachLauf<List<DailyMetrics>>(gelaufen: DateTime.utc(2026, 1, 1));
}
