import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/core/messwert.dart';
import 'package:repit/data/ziele.dart';
import 'package:repit/design/palette.dart';
import 'package:repit/design/segment_ring.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_types.dart';
import 'package:repit/shell/router.dart';
import 'package:repit/shell/schlaf_kalenderblatt.dart';
import 'package:repit/shell/schlaf_view.dart';
import 'package:repit/shell/schlaf_zustand.dart';
import '../health/health_reading_attrappe.dart';

/// Tests für **die Ringe im Kalenderblatt** (#243) —
/// `lib/shell/schlaf_kalenderblatt.dart` und `lib/design/segment_ring.dart`.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, nie verändert werden.
///
/// ## Woher die Anforderung kommt
///
/// Tim am 03.11.2026 auf dem Gerät: „im Kalender sollen die Ringe die
/// echten Ringe sein, nicht so erfundene Farben" — „es soll den Ring von
/// Schlaf nachstellen, den wir da oben benutzen."
///
/// Bis dahin trug jeder Tag **einen** Bogen, dessen Farbe aus der
/// Bewertung kam: vier Palettentöne, deren Bedeutung man ohne Legende
/// raten musste. Jetzt trägt er die Abschnitte des Schlaf-Rings aus der
/// Ringkarte: 50 % Dauer in `river`, 30 % Zubettgehzeit in `ok`, 20 %
/// Unterbrechungen in `wach`, **jedes Segment nach seiner eigenen
/// Teilnote** gefüllt.
///
/// ## Die beiden Eigenheiten des Vorbilds
///
/// Beide stehen schon an `ErholungRinge.schlaf` und müssen mitwandern,
/// sonst sagt der kleine Ring etwas anderes als der große:
///
/// 1. **Ohne Zubettgehzeit bleibt das 30-%-Segment stehen** und wird als
///    „ohne Grundlage" gezeichnet. Der Ring rechnet **nicht** auf 70 hoch
///    — sonst sähe eine Nacht ohne Einschlafzeit besser aus, als sie ist.
/// 2. **Ohne Nacht steht ein einziges Segment über den ganzen Kreis**,
///    nicht drei leere. Drei leere sähen aus wie eine Nacht mit null
///    Punkten in jedem Teil, und „kein Wert" ist nicht „Wert null"
///    (`docs/SPEC.md` 4.6).
///
/// ## Was hier nicht geprüft wird
///
/// - **Pixel.** Ob der Bogen hübsch liegt, sieht kein Widget-Test; geprüft
///   wird, welche Abschnitte in die Zelle gehen — dieselbe Trennung wie
///   bei `RingGeometrie`, deren Geometrie ohne Bild prüfbar ist
///   (`segment_ring_test.dart`).
/// - **Die Strichelung.** Dass ein Abschnitt ohne Grundlage gestrichelt
///   wird, steht in `segment_ring_test.dart` und gilt dort für jeden Ring.
///   Hier zählt nur, dass das Segment **ohne Grundlage** ankommt.
///
/// ## Zahlen in dieser Datei
///
/// Alle erfunden und frei gewählt (`CLAUDE.md`).
void main() {
  // Freitag, 20.08.2027, 09:00 Berlin (MESZ, +2).
  final jetzt = DateTime.utc(2027, 8, 20, 7);

  DateTime tagesbeginn(int jahr, int monat, int tag) =>
      BerlinCalendar.startOfDay(DateTime.utc(jahr, monat, tag));

  /// Eine Nacht mit Phasen — sie hat eine Einschlafzeit und Wachphasen,
  /// also alle drei Teilnoten.
  SleepNight nachtVon(int jahr, int monat, int tag) {
    final ende = tagesbeginn(jahr, monat, tag);
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

  // ═════════════════════════════════════════════════════════════════════
  // 1 — Die Abschnitte einer Nacht
  // ═════════════════════════════════════════════════════════════════════

  group('Ein Tag mit Nacht trägt den Schlaf-Ring in klein', () {
    const score = SleepScore(duration: 44, bedtime: 27, interruptions: 10);

    test('drei Abschnitte mit den Anteilen 50, 30 und 20 Prozent', () {
      final ring = schlafTagAbschnitte(score: score, form: SchlafTagform.nacht);

      expect(ring, hasLength(3));
      expect(ring[0].anteil, closeTo(0.5, 1e-9));
      expect(ring[1].anteil, closeTo(0.3, 1e-9));
      expect(ring[2].anteil, closeTo(0.2, 1e-9));
    });

    test('in den Farben der Ringkarte: river, ok, wach', () {
      final ring = schlafTagAbschnitte(score: score, form: SchlafTagform.nacht);

      expect(ring[0].farbe, same(Palette.river));
      expect(ring[1].farbe, same(Palette.ok));
      expect(ring[2].farbe, same(Palette.wach));
    });

    test('jedes Segment nach seiner eigenen Teilnote, nicht nach dem '
        'Gesamtscore', () {
      final ring = schlafTagAbschnitte(score: score, form: SchlafTagform.nacht);

      expect(ring[0].fuellung, closeTo(44 / 50, 1e-9));
      expect(ring[1].fuellung, closeTo(27 / 30, 1e-9));
      expect(ring[2].fuellung, closeTo(10 / 20, 1e-9));
    });

    test('und alle drei haben eine Grundlage', () {
      final ring = schlafTagAbschnitte(score: score, form: SchlafTagform.nacht);

      expect(ring.every((a) => a.hatGrundlage), isTrue);
    });

    // **Zwei Wahrheiten über denselben Score wären schlimmer als eine
    // langsame** (Dateikopf des Kalenderblatts). Der Ring der Zelle und der
    // Ring der Karte oben rechnen über dieselben Teilnoten.
    test('dieselben Abschnitte wie die Karte oben', () {
      final imKalender = schlafTagAbschnitte(
        score: score,
        form: SchlafTagform.nacht,
      );
      final aufDerKarte = schlafRingAbschnitte(schlafTeilnoten(score));

      expect(imKalender, hasLength(aufDerKarte.length));
      for (var i = 0; i < aufDerKarte.length; i++) {
        expect(imKalender[i].anteil, closeTo(aufDerKarte[i].anteil, 1e-9));
        expect(imKalender[i].fuellung, closeTo(aufDerKarte[i].fuellung, 1e-9));
        expect(imKalender[i].farbe, same(aufDerKarte[i].farbe));
        expect(imKalender[i].hatGrundlage, aufDerKarte[i].hatGrundlage);
      }
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  // 2 — Ohne Zubettgehzeit bleibt das Segment stehen
  // ═════════════════════════════════════════════════════════════════════

  group('Eine Nacht ohne Einschlafzeit', () {
    const ohneZubett = SleepScore(
      duration: 44,
      bedtime: null,
      interruptions: 10,
    );

    test(
      'behält ihre drei Abschnitte — der Ring rechnet nicht auf 70 hoch',
      () {
        final ring = schlafTagAbschnitte(
          score: ohneZubett,
          form: SchlafTagform.nacht,
        );

        expect(ring, hasLength(3));
        expect(
          ring[0].anteil,
          closeTo(0.5, 1e-9),
          reason:
              'Auf 70 hochgerechnet wären es 50/70 ≈ 0,71 — und die Nacht '
              'sähe besser aus, als sie ist.',
        );
        expect(ring[1].anteil, closeTo(0.3, 1e-9));
        expect(ring[2].anteil, closeTo(0.2, 1e-9));
      },
    );

    test('und das mittlere Segment kommt ohne Grundlage an', () {
      final ring = schlafTagAbschnitte(
        score: ohneZubett,
        form: SchlafTagform.nacht,
      );

      expect(ring[1].hatGrundlage, isFalse);
      expect(
        ring[1].fuellung,
        0,
        reason:
            '„Nicht gemessen" ist nicht „null Punkte" — gefüllt wird '
            'nichts, gezeichnet wird gestrichelt.',
      );
      expect(ring[0].hatGrundlage, isTrue);
      expect(ring[2].hatGrundlage, isTrue);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  // 3 — Ohne Nacht ein einziges Segment
  // ═════════════════════════════════════════════════════════════════════

  group('Ein Tag ohne Nacht', () {
    test('trägt genau einen Abschnitt über den ganzen Kreis', () {
      final ring = schlafTagAbschnitte(score: null, form: SchlafTagform.leer);

      expect(
        ring,
        hasLength(1),
        reason:
            'Drei leere Segmente sähen aus wie eine Nacht mit null Punkten '
            'in jedem Teil.',
      );
      expect(ring.single.anteil, 1);
    });

    test('und der hat keine Grundlage — gestrichelt, nicht blass', () {
      final ring = schlafTagAbschnitte(score: null, form: SchlafTagform.leer);

      expect(ring.single.hatGrundlage, isFalse);
      expect(ring.single.fuellung, 0);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  // 4 — Außerhalb gar kein Ring
  // ═════════════════════════════════════════════════════════════════════

  group('Ein Tag außerhalb des gelesenen Zeitraums', () {
    test('trägt gar keinen Abschnitt', () {
      expect(
        schlafTagAbschnitte(score: null, form: SchlafTagform.ausserhalb),
        isEmpty,
        reason:
            'Dort hat niemand nachgesehen — das ist der Unterschied '
            'zwischen `LeerNachLauf` und `NochNie`.',
      );
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  // 5 — Die Lücke der kleinen Zelle
  // ═════════════════════════════════════════════════════════════════════

  // Der große Ring ist 92 Punkte breit, die Zelle 30. Auf diesem
  // Durchmesser ist die Lücke des großen Rings 1,2 Punkte lang, und eine
  // runde Kappe trägt an jedem Ende 1,5 Punkte auf: Die Lücke wäre weg.
  // Dieser Fall bewacht die Entscheidung, nicht ihre genaue Zahl.
  group('Der kleine Ring hält die Segmente weiter auseinander', () {
    test('seine Lücke ist breiter als die des großen Rings', () {
      expect(
        SegmentRingKlein.luecke,
        greaterThan(RingGeometrie.standardLuecke),
      );
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  // 6 — Im Blatt
  // ═════════════════════════════════════════════════════════════════════

  group('Im Kalenderblatt', () {
    Widget huelle() {
      final router = AppRouter();
      // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          clockProvider.overrideWithValue(() => jetzt),
          dataWindowProvider.overrideWith(
            (ref) => DataWindow(start: tagesbeginn(2027, 8, 1)),
          ),
          healthProvider.overrideWithValue(_LeereQuelle()),
          sleepProvider.overrideWith(
            () => _Naechte(
              Bekannt<List<SleepNight>>(
                [nachtVon(2027, 8, 19), nachtVon(2027, 8, 20)],
                stand: jetzt,
                laeuft: false,
              ),
            ),
          ),
          zieleProvider.overrideWith(() => _Ziele(Ziele.vorbelegung)),
        ],
      );
      addTearDown(container.dispose);

      return UncontrolledProviderScope(
        container: container,
        child: CupertinoApp(home: SchlafSeite(router: router)),
      );
    }

    Future<void> oeffne(WidgetTester tester) async {
      tester.view.physicalSize = const Size(900, 6000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(huelle());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('schlaf-kalender-knopf')));
      await tester.pumpAndSettle();
    }

    /// Die Abschnitte, die die Zelle dieses Tages zeichnet; `null` heißt
    /// „kein Ring".
    List<RingAbschnitt>? ringVon(WidgetTester tester, String schluessel) {
      final treffer = find.descendant(
        of: find.byKey(Key('schlaf-kalender-tag-$schluessel')),
        matching: find.byType(SegmentRingKlein),
      );
      if (treffer.evaluate().isEmpty) return null;
      return tester.widget<SegmentRingKlein>(treffer).abschnitte;
    }

    testWidgets('ein Tag mit Nacht zeigt drei Abschnitte', (tester) async {
      await oeffne(tester);

      final ring = ringVon(tester, '2027-08-19');
      expect(ring, isNotNull);
      expect(ring, hasLength(3));
      expect(ring![0].anteil, closeTo(0.5, 1e-9));
    });

    testWidgets('ein Tag ohne Nacht zeigt einen einzigen', (tester) async {
      await oeffne(tester);

      final ring = ringVon(tester, '2027-08-10');
      expect(ring, isNotNull);
      expect(ring, hasLength(1));
      expect(ring!.single.hatGrundlage, isFalse);
    });

    testWidgets('ein Tag in der Zukunft zeigt gar keinen', (tester) async {
      await oeffne(tester);

      expect(
        find.byKey(const Key('schlaf-kalender-tag-2027-08-25')),
        findsOneWidget,
      );
      expect(ringVon(tester, '2027-08-25'), isNull);
    });
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

/// Liefert nichts — Puls und Atmung sind hier nicht der Gegenstand.
class _LeereQuelle extends HealthReadingAttrappe {}
