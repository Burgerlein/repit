import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/core/messwert.dart';
import 'package:repit/data/schlaf_eintrag.dart';
import 'package:repit/data/ziele.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_types.dart';
import 'package:repit/shell/erholung_nacht.dart';
import 'package:repit/shell/erholung_zustand.dart';

/// Tests für den **von Hand eingetragenen Tagschlaf auf dem
/// Erholung-Schirm** (#209).
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung**
/// (`CLAUDE.md`). Diese Datei darf ausgeführt, nie verändert werden.
///
/// ## Der Befund
///
/// Tim trug am 03.11.2026 an einem Tag mit Nacht um 23 Uhr zusätzlich
/// einen Schlaf von 19 bis 20 Uhr ein — und auf dem Erholung-Schirm
/// erschien nichts. Der Eintrag wurde gespeichert; er erreichte den Schirm
/// nur nie. `erholungProvider` las ausschließlich `sleepProvider`, und die
/// Tagschlaf-Kachel hing an `SleepNight.naps`, also allein an der Messung.
///
/// ## Was hier festgelegt wird
///
/// ```dart
/// // lib/shell/erholung_zustand.dart
/// class ErholungDaten {
///   /// Der von Hand eingetragene Tagschlaf desselben Tages —
///   /// **zusätzlich** zu `nacht.naps`, nicht statt ihrer.
///   final List<SchlafEintrag> napEintraege;
/// }
///
/// ErholungZustand erholungZustandAus({
///   …,
///   /// Tims eigene Einträge. Kein `Messwert`: Leer heißt leer.
///   List<SchlafEintrag> eintraege = const [],
/// });
///
/// // lib/shell/erholung_nacht.dart
/// class ErholungTagschlaf extends StatelessWidget {
///   const ErholungTagschlaf({
///     super.key,
///     required List<SleepSession> naps,
///     List<SchlafEintrag> napEintraege = const [],
///     required VoidCallback onTagschlaf,
///   });
/// }
/// ```
///
/// **Die Form der Kachel bleibt, wie sie ist** (#274 entscheidet sie
/// getrennt): Anzahl und Summe, kein Zeitfenster.
///
/// ## Der Tag ist der Tag des Eintrags
///
/// Ein Nickerchen zählt nach dem Kalendertag, an dem es stattfindet (Tims
/// Entscheidung vom 03.11.2026 in #209) — nicht nach der 18-Uhr-Regel, die
/// nur noch beantwortet, zu welcher Nacht eine gemessene Phase gehört.
/// Dieselbe Zuordnung prüft die Swift-Seite für die **gemessenen**
/// Nickerchen (`Packages/TrainingsCore/Tests/TrainingsCoreTests/
/// SleepSessionTests.swift`, „Ein Nickerchen am Abend zählt zu dem Tag, an
/// dem es beginnt"). Hier steht die Hand-Eintrags-Hälfte desselben Satzes:
/// Ein Abendschlaf am 12.10. gehört zum 12.10., nicht zum 13.10.
///
/// ## Keine Nickerchen, keine Kachel
///
/// Der Entwurf sagt es ausdrücklich (`docs/screens/screens/erholung.js`):
/// „Die Kachel erscheint nur an Tagen mit Tagschlaf. Eine fehlende
/// Statuskarte wäre mehrdeutig, ein fehlender Tagschlaf-Kasten nicht: Wer
/// nicht geschlafen hat, hat nicht geschlafen." Ein Tag ohne Nickerchen ist
/// kein fehlender Wert, sondern null Ereignisse — dafür gibt es keine
/// ungefüllte Form.
void main() {
  final jetzt = DateTime.utc(2026, 10, 12, 18, 30);
  final heute = BerlinCalendar.startOfDay(jetzt);
  final morgen = BerlinCalendar.addDays(heute, 1);

  DateTime tagMit(int tagImMonat) =>
      BerlinCalendar.startOfDay(DateTime.utc(2026, 10, tagImMonat, 12));

  /// Ein von Hand eingetragener Abendschlaf, 19:00–20:00.
  ///
  /// Genau Tims Fall: eine Stunde am Abend, zusätzlich zur Nacht. Die
  /// Uhrzeit liegt **nach** 18 Uhr — unter der alten Regel wäre sie beim
  /// Folgetag gelandet.
  SchlafEintrag abendschlaf(
    DateTime tag, {
    int schlafMinuten = 60,
    int lfdNr = 0,
  }) => SchlafEintrag(
    tag: BerlinCalendar.dayKey(tag),
    art: SchlafEintragArt.tagschlaf,
    lfdNr: lfdNr,
    schlafMinuten: schlafMinuten,
    beginnMinuten: 19 * 60,
    endeMinuten: 20 * 60,
  );

  /// Ein von Hand eingetragenes Nickerchen **ohne Zeiten** — die Fassung
  /// „nur Dauer" des Formulars.
  SchlafEintrag nurDauer(
    DateTime tag, {
    int schlafMinuten = 25,
    int lfdNr = 1,
  }) => SchlafEintrag(
    tag: BerlinCalendar.dayKey(tag),
    art: SchlafEintragArt.tagschlaf,
    lfdNr: lfdNr,
    schlafMinuten: schlafMinuten,
  );

  /// Eine gemessene Nacht des [tag]es, 23:00 bis 06:00.
  SleepNight gemesseneNacht(
    DateTime tag, {
    List<SleepSession> naps = const [],
  }) {
    final abend = BerlinCalendar.addDays(tag, -1);
    return SleepNight(
      date: tag,
      session: SleepSession(
        segments: [
          SleepSegment(
            stage: SleepStage.core,
            start: abend.add(const Duration(hours: 23)),
            end: tag.add(const Duration(hours: 6)),
          ),
        ],
      ),
      naps: naps,
    );
  }

  /// Ein gemessenes Nickerchen von [minuten] Minuten, ab 13:40.
  SleepSession gemessenesNickerchen(DateTime tag, {int minuten = 35}) {
    final beginn = tag.add(const Duration(hours: 13, minutes: 40));
    return SleepSession(
      segments: [
        SleepSegment(
          stage: SleepStage.unspecified,
          start: beginn,
          end: beginn.add(Duration(minutes: minuten)),
        ),
      ],
    );
  }

  DailyMetrics tageswert(DateTime tag) =>
      DailyMetrics(tag: BerlinCalendar.dayKey(tag), steps: 8000);

  ErholungDaten datenAus({
    List<SleepNight> naechte = const [],
    List<SchlafEintrag> eintraege = const [],
  }) {
    final zustand = erholungZustandAus(
      tageswerte: Bekannt<List<DailyMetrics>>(
        [tageswert(tagMit(11)), tageswert(heute)],
        stand: jetzt,
        laeuft: false,
      ),
      naechte: Bekannt<List<SleepNight>>(naechte, stand: jetzt, laeuft: false),
      ziele: Ziele.vorbelegung,
      fenster: DataWindow.unlimited,
      jetzt: jetzt,
      eintraege: eintraege,
    );
    final daten = zustand.daten;
    expect(
      daten,
      isA<Bekannt<ErholungDaten>>(),
      reason: 'die Hülle liefert Tageswerte und Nächte als Bekannt',
    );
    return (daten as Bekannt<ErholungDaten>).wert;
  }

  // ─────────────────────────────────────────────────────────────────────
  // Der Zustand
  // ─────────────────────────────────────────────────────────────────────

  group('Ein eingetragener Tagschlaf erreicht den Erholung-Schirm', () {
    test('auch wenn die Uhr an diesem Tag keines erkannt hat', () {
      final daten = datenAus(
        naechte: [gemesseneNacht(heute)],
        eintraege: [abendschlaf(heute)],
      );

      expect(daten.napEintraege.map((e) => e.beginnMinuten), [
        19 * 60,
      ], reason: 'genau der Eintrag, den Tim am 03.11.2026 vermisst hat');
    });

    test('und er kommt zum gemessenen dazu, statt es zu ersetzen', () {
      final daten = datenAus(
        naechte: [
          gemesseneNacht(heute, naps: [gemessenesNickerchen(heute)]),
        ],
        eintraege: [abendschlaf(heute)],
      );

      expect(daten.nacht!.naps, hasLength(1));
      expect(daten.napEintraege, hasLength(1));
    });

    test('auch ohne gemessene Nacht — ein Nickerchen braucht keine', () {
      final daten = datenAus(eintraege: [abendschlaf(heute)]);

      expect(daten.nacht, isNull);
      expect(daten.napEintraege, hasLength(1));
    });

    test('ein Nacht-Eintrag ist kein Nickerchen', () {
      final daten = datenAus(
        naechte: [gemesseneNacht(heute)],
        eintraege: [
          SchlafEintrag(
            tag: BerlinCalendar.dayKey(heute),
            art: SchlafEintragArt.nacht,
            lfdNr: 0,
            schlafMinuten: 430,
            beginnMinuten: 23 * 60,
            endeMinuten: 6 * 60 + 10,
          ),
        ],
      );

      expect(daten.napEintraege, isEmpty);
    });

    test('mehrere stehen nach Beginn sortiert, das ohne Zeiten hinten', () {
      final daten = datenAus(
        naechte: [gemesseneNacht(heute)],
        eintraege: [
          nurDauer(heute, lfdNr: 2),
          abendschlaf(heute, lfdNr: 1),
          SchlafEintrag(
            tag: BerlinCalendar.dayKey(heute),
            art: SchlafEintragArt.tagschlaf,
            lfdNr: 0,
            schlafMinuten: 30,
            beginnMinuten: 13 * 60,
            endeMinuten: 13 * 60 + 30,
          ),
        ],
      );

      expect(daten.napEintraege.map((e) => e.beginnMinuten), [
        13 * 60,
        19 * 60,
        null,
      ]);
    });
  });

  group('Der Tag des Eintrags entscheidet, nicht die 18-Uhr-Regel', () {
    test('ein Abendschlaf am 12. gehört zum 12.', () {
      final daten = datenAus(
        naechte: [gemesseneNacht(heute)],
        eintraege: [abendschlaf(heute)],
      );

      expect(daten.napEintraege, hasLength(1));
      expect(daten.napEintraege.single.tag, BerlinCalendar.dayKey(heute));
    });

    test('und nicht zum 13. — dort steht er nicht', () {
      final daten = datenAus(
        naechte: [gemesseneNacht(heute), gemesseneNacht(morgen)],
        // Derselbe Abendschlaf, aber als Eintrag des Folgetags. Er darf
        // **nicht** auf dem Schirm von heute auftauchen.
        eintraege: [abendschlaf(morgen)],
      );

      expect(
        daten.napEintraege,
        isEmpty,
        reason:
            'der Schirm zeigt heute, und der Eintrag gehört zum 13. — '
            'die alte 18-Uhr-Regel hätte ihn hierher geschoben',
      );
    });

    test('ein Eintrag eines anderen Tages bleibt dort', () {
      final daten = datenAus(
        naechte: [gemesseneNacht(heute)],
        eintraege: [abendschlaf(tagMit(11)), abendschlaf(heute, lfdNr: 1)],
      );

      expect(daten.napEintraege, hasLength(1));
      expect(daten.napEintraege.single.tag, BerlinCalendar.dayKey(heute));
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // Die Kachel
  // ─────────────────────────────────────────────────────────────────────

  group('Die Kachel zählt gemessene und eingetragene zusammen', () {
    Future<List<String>> texte(
      WidgetTester tester, {
      List<SleepSession> naps = const [],
      List<SchlafEintrag> napEintraege = const [],
    }) async {
      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: ErholungTagschlaf(
              naps: naps,
              napEintraege: napEintraege,
              onTagschlaf: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('erholung-tagschlaf')), findsOneWidget);
      return tester
          .widgetList<Text>(
            find.descendant(
              of: find.byKey(const Key('erholung-tagschlaf')),
              matching: find.byType(Text),
            ),
          )
          .map((t) => t.data)
          .whereType<String>()
          .toList();
    }

    testWidgets('ein eingetragenes allein ist eines', (tester) async {
      final gefunden = await texte(tester, napEintraege: [abendschlaf(heute)]);

      expect(gefunden.any((t) => t.contains('ein Nickerchen')), isTrue);
      expect(gefunden.any((t) => t.contains('1 Std.')), isTrue);
    });

    testWidgets('eines gemessen und eines eingetragen sind zwei', (
      tester,
    ) async {
      final gefunden = await texte(
        tester,
        naps: [gemessenesNickerchen(heute, minuten: 30)],
        napEintraege: [abendschlaf(heute, schlafMinuten: 30)],
      );

      expect(gefunden.any((t) => t.contains('2 Nickerchen')), isTrue);
      expect(
        gefunden.any((t) => t.contains('1 Std.')),
        isTrue,
        reason: '30 gemessene und 30 eingetragene Minuten sind eine Stunde',
      );
    });

    testWidgets('die eingetragene Dauer zählt, nicht das Zeitfenster', (
      tester,
    ) async {
      // Fenster 19:00–20:00, aber nur 45 Minuten geschlafen — der Entwurf
      // lässt die gerechnete Dauer überschreiben, „falls du wach
      // dazwischen lagst".
      final gefunden = await texte(
        tester,
        napEintraege: [abendschlaf(heute, schlafMinuten: 45)],
      );

      expect(gefunden.any((t) => t.contains('45')), isTrue);
      expect(
        gefunden.any((t) => t.contains('1 Std.')),
        isFalse,
        reason: 'die Stunde auf der Uhr war keine Stunde Schlaf',
      );
    });

    testWidgets('ein Nickerchen ohne Zeiten zählt trotzdem mit', (
      tester,
    ) async {
      final gefunden = await texte(
        tester,
        napEintraege: [nurDauer(heute, schlafMinuten: 25)],
      );

      expect(gefunden.any((t) => t.contains('ein Nickerchen')), isTrue);
      expect(gefunden.any((t) => t.contains('25')), isTrue);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // Der Schirm
  // ─────────────────────────────────────────────────────────────────────

  group('Der Provider holt sich die Einträge selbst', () {
    ProviderContainer behaelter({
      List<SleepNight> naechte = const [],
      List<SchlafEintrag> eintraege = const [],
    }) {
      // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          clockProvider.overrideWithValue(() => jetzt),
          dailyMetricsProvider.overrideWith(
            () => _Tageswerte(
              Bekannt<List<DailyMetrics>>(
                [tageswert(heute)],
                stand: jetzt,
                laeuft: false,
              ),
            ),
          ),
          sleepProvider.overrideWith(
            () => _Naechte(
              Bekannt<List<SleepNight>>(naechte, stand: jetzt, laeuft: false),
            ),
          ),
          nachtWerteProvider.overrideWith(
            () => _Nachtwerte(
              Bekannt<Map<String, NightVitals>>(
                const {},
                stand: jetzt,
                laeuft: false,
              ),
            ),
          ),
          schlafEintraegeProvider.overrideWith(() => _Eintraege(eintraege)),
          zieleProvider.overrideWith(() => _Ziele(Ziele.vorbelegung)),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test(
      'ein eingetragenes Nickerchen kommt beim Erholung-Zustand an',
      () async {
        final container = behaelter(
          naechte: [gemesseneNacht(heute)],
          eintraege: [abendschlaf(heute)],
        );
        await container.read(sleepProvider.future);
        await container.read(dailyMetricsProvider.future);
        await container.read(schlafEintraegeProvider.future);

        final daten = container.read(erholungProvider).daten;
        expect(daten, isA<Bekannt<ErholungDaten>>());
        expect(
          (daten as Bekannt<ErholungDaten>).wert.napEintraege,
          hasLength(1),
          reason:
              'ohne das bleibt der Eintrag in der Ablage liegen — genau Tims '
              'Befund (#209)',
        );
      },
    );
  });
}

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

class _Eintraege extends SchlafEintraegeNotifier {
  _Eintraege(this.wert);

  final List<SchlafEintrag> wert;

  @override
  Future<List<SchlafEintrag>> build() async => wert;
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
