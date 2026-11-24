/// **#504 — Je Nacht die Phasen, aus denen ihr Balken gestapelt wird.**
///
/// Der Schlaf-Verlauf zeichnet seit dem 13.11.2026 wieder Balken (Tim,
/// `#504` kehrt `#255` um), und jeder Balken ist in sich nach Schlafphasen
/// geteilt. Die Höhe bleibt die Schlafdauer aus [schlafTagewerte]; **was
/// hier entsteht, sind die Teile**, nach denen diese Höhe aufgeteilt wird.
///
/// ## Festgelegte öffentliche API
///
/// ```dart
/// // lib/shell/schlaf_zustand.dart (Fassade über schlaf_reihe.dart)
///
/// /// Die Phasen des Verlaufs, **von unten nach oben** im Balken.
/// const List<SleepStage> schlafVerlaufPhasen;
///
/// /// Je Nacht die Schlafstunden je Phase, in der Reihenfolge von
/// /// [schlafVerlaufPhasen].
/// List<({DateTime tag, List<double> teile})> schlafPhasenTagewerte(
///   List<SleepNight> naechte,
/// );
///
/// /// Dasselbe, **gehalten** (Hausregel 2).
/// final Provider<List<({DateTime tag, List<double> teile})>>
///     schlafPhasenTagewerteProvider;
/// ```
///
/// ## Was hier geprüft wird — und warum
///
/// - **„Wach" ist nicht dabei.** Die Höhe des Balkens ist die Zeit *im
///   Schlaf* (`schlafMinutenVon` lässt `awake` aus). Ein Wach-Anteil in
///   einem Balken, dessen Höhe Wach gar nicht enthält, widerspräche sich
///   — entschieden beim Bau von #504.
/// - **Die Teile ergeben zusammen die Balkenhöhe.** Zwei Rechnungen über
///   dieselbe Nacht dürfen nicht auseinanderlaufen; sonst zeigte der
///   Stapel etwas anderes als der Balken, in dem er steht.
/// - **Eine Nacht ohne Phasenangabe steht einfarbig da.** Ältere Uhren und
///   das iPhone melden `SleepStage.unspecified`; daraus ist kein
///   Tiefschlafanteil zu gewinnen, und eine erfundene Verteilung wäre
///   schlimmer als keine (`CLAUDE.md`, Fehler `01`). Sie bekommt ihren
///   eigenen Platz im Stapel statt auf die Kern-Spur geschlagen zu werden.
/// - **Eine Nacht ohne Schlaf fehlt**, genau wie in [schlafTagewerte] —
///   sie ist keine gemessene Null.
/// - **Gehalten, nicht je Bild gerechnet** (Hausregel 2).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/core/messwert.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_types.dart';
import 'package:repit/shell/schlaf_zustand.dart';

import '../health/health_reading_attrappe.dart';

void main() {
  // Montag, 12.10.2026, 09:15 Berlin (CEST, +2).
  final jetzt = DateTime.utc(2026, 10, 12, 7, 15);

  DateTime tagesbeginn(int tag) =>
      BerlinCalendar.startOfDay(DateTime.utc(2026, 10, tag));

  DateTime berlin(int tag, int stunde, [int minute = 0]) =>
      DateTime.utc(2026, 10, tag, stunde - 2, minute);

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

  /// Alle vier Phasen, 23:00 bis 06:00 — 405 Schlafminuten, 15 wach.
  /// Kern 255, Tief 60, REM 90.
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

  /// Eine ältere Uhr: Schlaf ohne Phasenangabe, 360 Minuten.
  SleepNight ohnePhasenVon(int tag) => nachtAus(
    tag: tagesbeginn(tag),
    beginn: berlin(tag - 1, 23),
    phasen: const [(SleepStage.unspecified, 360)],
  );

  /// Nur Wachliegen — keine Schlafminuten, gehört in keine Reihe.
  SleepNight wachnachtVon(int tag) => nachtAus(
    tag: tagesbeginn(tag),
    beginn: berlin(tag - 1, 23),
    phasen: const [(SleepStage.awake, 60)],
  );

  ProviderContainer behaelter(List<SleepNight> naechte) {
    // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        clockProvider.overrideWithValue(() => jetzt),
        healthProvider.overrideWithValue(_FakeHealthReading()),
        sleepProvider.overrideWith(
          () => _Naechte(
            Bekannt<List<SleepNight>>(naechte, stand: jetzt, laeuft: false),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// Der Index einer Phase im Stapel, damit kein Fall eine Reihenfolge
  /// festschreibt, die er gar nicht meint.
  int platzVon(SleepStage phase) => schlafVerlaufPhasen.indexOf(phase);

  group('Die Reihenfolge der Phasen im Balken', () {
    test('Wach ist nicht dabei', () {
      expect(
        schlafVerlaufPhasen,
        isNot(contains(SleepStage.awake)),
        reason:
            'die Höhe des Balkens ist die Zeit im Schlaf; ein Wach-Anteil '
            'in einem Balken, dessen Höhe Wach nicht enthält, '
            'widerspräche sich (#504)',
      );
    });

    test('Tief steht unten, darüber Kern und REM', () {
      expect(platzVon(SleepStage.deep), 0);
      expect(
        platzVon(SleepStage.core),
        greaterThan(platzVon(SleepStage.deep)),
      );
      expect(platzVon(SleepStage.rem), greaterThan(platzVon(SleepStage.core)));
    });

    test('Schlaf ohne Angabe hat einen eigenen Platz', () {
      expect(
        platzVon(SleepStage.unspecified),
        isNonNegative,
        reason:
            'auf die Kern-Spur geschlagen behauptete er eine Phase, die '
            'die Uhr nie gemeldet hat (#504)',
      );
    });
  });

  group('Was je Nacht herauskommt', () {
    test('die Minuten je Phase, in Stunden', () {
      final teile = schlafPhasenTagewerte([nachtVon(12)]).single.teile;

      expect(teile[platzVon(SleepStage.deep)], closeTo(60 / 60, 1e-9));
      expect(teile[platzVon(SleepStage.core)], closeTo(255 / 60, 1e-9));
      expect(teile[platzVon(SleepStage.rem)], closeTo(90 / 60, 1e-9));
      expect(teile[platzVon(SleepStage.unspecified)], 0);
    });

    test('die Teile ergeben zusammen die Balkenhöhe', () {
      final nacht = nachtVon(12);
      final hoehe = schlafTagewerte([nacht]).single.wert;
      final summe = schlafPhasenTagewerte(
        [nacht],
      ).single.teile.fold<double>(0, (a, b) => a + b);

      expect(
        summe,
        closeTo(hoehe, 1e-9),
        reason:
            'Stapel und Balken rechnen über dieselbe Nacht — zwei '
            'Wahrheiten darüber wären eine falsche Auskunft',
      );
    });

    test('Wachminuten fallen weg', () {
      final summe = schlafPhasenTagewerte(
        [nachtVon(12)],
      ).single.teile.fold<double>(0, (a, b) => a + b);

      expect(summe, closeTo(405 / 60, 1e-9));
    });

    test('eine Nacht ohne Phasenangabe füllt nur ihren eigenen Platz', () {
      final teile = schlafPhasenTagewerte([ohnePhasenVon(12)]).single.teile;

      expect(teile[platzVon(SleepStage.unspecified)], closeTo(6, 1e-9));
      expect(
        [
          teile[platzVon(SleepStage.deep)],
          teile[platzVon(SleepStage.core)],
          teile[platzVon(SleepStage.rem)],
        ],
        everyElement(0),
        reason:
            'der Balken steht einfarbig da — eine erfundene Verteilung '
            'wäre schlimmer als keine (#504)',
      );
    });

    test('eine Nacht ohne Schlaf fehlt', () {
      expect(
        schlafPhasenTagewerte([
          nachtVon(10),
          wachnachtVon(11),
          nachtVon(12),
        ]).map((e) => e.tag),
        [tagesbeginn(10), tagesbeginn(12)],
        reason:
            'sie ist keine gemessene Null — dieselbe Regel wie in '
            'schlafTagewerte',
      );
    });

    test('dieselben Tage wie die Balken, in derselben Folge', () {
      final naechte = [nachtVon(12), ohnePhasenVon(10), nachtVon(11)];

      expect(
        schlafPhasenTagewerte(naechte).map((e) => e.tag),
        schlafTagewerte(naechte).map((e) => e.tag),
        reason: 'ein Stapel ohne Balken darunter wäre ein Stapel im Nichts',
      );
    });

    test('eine leere Reihe ergibt eine leere Reihe', () {
      expect(schlafPhasenTagewerte(const []), isEmpty);
    });
  });

  group('Der Provider', () {
    test('liefert dieselben Teile wie die Funktion', () async {
      final naechte = [nachtVon(11), nachtVon(12)];
      final container = behaelter(naechte);
      await container.read(sleepProvider.future);

      expect(
        container.read(schlafPhasenTagewerteProvider).map((e) => e.tag),
        schlafPhasenTagewerte(naechte).map((e) => e.tag),
      );
    });

    test('wird gehalten, nicht bei jedem Zugriff gerechnet', () async {
      final container = behaelter([nachtVon(11), nachtVon(12)]);
      await container.read(sleepProvider.future);

      expect(
        container.read(schlafPhasenTagewerteProvider),
        same(container.read(schlafPhasenTagewerteProvider)),
        reason: 'Hausregel 2 — eine berechnete Eigenschaft rechnete je Bild',
      );
    });
  });
}

/// Steuerbarer Ableger des echten Notifiers.
class _Naechte extends SleepNotifier {
  _Naechte(this.wert);

  final Messwert<List<SleepNight>> wert;

  @override
  Future<Messwert<List<SleepNight>>> build() async => wert;
}

/// Eine Quelle, die nichts liefert — die Reihe hängt an [sleepProvider],
/// nicht am Kanal.
class _FakeHealthReading extends HealthReadingAttrappe {}
