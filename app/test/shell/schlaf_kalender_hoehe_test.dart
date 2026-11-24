import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/core/messwert.dart';
import 'package:repit/data/ziele.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_types.dart';
import 'package:repit/shell/router.dart';
import 'package:repit/shell/schlaf_view.dart';
import '../health/health_reading_attrappe.dart';

/// Tests für **die Kalenderkachel springt nicht mehr** (#258) —
/// `lib/shell/schlaf_kalenderblatt.dart`.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, nie verändert werden.
///
/// ## Woher die Anforderung kommt
///
/// Tim am 03.11.2026 auf dem Gerät: „die Monatsansicht springt je nachdem,
/// wie die Wochen sind. Bau das so, dass die Kachel nicht groß und klein
/// wird."
///
/// Gebaut fiel die Zahl der Zeilen aus dem Monat ab — aus dem Wochentag des
/// Monatsersten und der Monatslänge werden **vier, fünf oder sechs**. Beim
/// Blättern wechselte die Kachel damit ihre Höhe, und weil sie in einem
/// Blatt über dem Schirm sitzt, sprang das ganze Blatt mit.
///
/// Das ist dieselbe Regel wie für fehlende Werte (`CLAUDE.md`, „Eine
/// Anzeige, die es gibt, hat genau eine Form"), nur ist die Ursache hier
/// der Kalender und nicht die Datenlage.
///
/// ## Die beiden Monate
///
/// Erfunden ist daran nichts — es sind Kalendertatsachen:
///
/// - **Februar 2027** beginnt an einem Montag und hat 28 Tage. Das Raster
///   geht genau auf: **vier** Zeilen.
/// - **August 2027** beginnt an einem Sonntag und hat 31 Tage. Sechs leere
///   Felder davor, 31 Tage, macht 37 Felder: **sechs** Zeilen.
///
/// Das ist der größtmögliche Unterschied, den ein Monat hergibt. Steht die
/// Kachel über diesen beiden still, steht sie über jedem Monat still.
///
/// ## Was hier geprüft wird — und was nicht
///
/// Geprüft wird **nicht**, dass die Kachel eine bestimmte Höhe hat. Eine
/// festgeschriebene Pixelhöhe wäre genau die Lösung, die das Ticket
/// ausschließt — sie bräche bei größerer Schrift. Geprüft wird, dass die
/// Höhe über die Monate hinweg **dieselbe** ist, welche auch immer das ist.
///
/// ## Zahlen in dieser Datei
///
/// Alle erfunden und frei gewählt. Keine stammt aus einem Health-Export
/// oder einem Screenshot (`CLAUDE.md`).
void main() {
  // Freitag, 20.08.2027, 09:00 Berlin (MESZ, +2).
  final jetzt = DateTime.utc(2027, 8, 20, 7);

  DateTime tagesbeginn(int jahr, int monat, int tag) =>
      BerlinCalendar.startOfDay(DateTime.utc(jahr, monat, tag));

  /// Sieben Stunden Kernschlaf, die eine Stunde vor dem Tagesbeginn
  /// anfangen — damit der Schirm überhaupt eine Nacht zu zeigen hat.
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

  Widget huelle() {
    final router = AppRouter();
    // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        clockProvider.overrideWithValue(() => jetzt),
        // Der gelesene Zeitraum beginnt im Februar, also führen die
        // Monatspfeile von August bis dorthin zurück.
        dataWindowProvider.overrideWith(
          (ref) => DataWindow(start: tagesbeginn(2027, 2, 1)),
        ),
        healthProvider.overrideWithValue(_LeereQuelle()),
        sleepProvider.overrideWith(
          () => _Naechte(
            Bekannt<List<SleepNight>>(
              [
                // **Die Nacht vom 1. Februar ist der Grund, dass sich bis
                // dorthin zurückblättern lässt.** Das Rechenfenster hält
                // dreißig Tage vor; eine geladene Nacht davor schiebt den
                // frühesten Tag nach hinten, weil eine Nacht, die oben
                // stehen kann, auch anwählbar sein muss.
                nachtVon(2027, 2, 1),
                nachtVon(2027, 8, 18),
                nachtVon(2027, 8, 19),
                nachtVon(2027, 8, 20),
              ],
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

  /// Öffnet den Schirm und darauf das Kalenderblatt.
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

  Size blattMass(WidgetTester tester) =>
      tester.getSize(find.byKey(const Key('schlaf-kalenderblatt')));

  Future<void> einenMonatZurueck(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('schlaf-kalender-monat-frueher')));
    await tester.pumpAndSettle();
  }

  // ═════════════════════════════════════════════════════════════════════
  // 1 — Vier Wochen und sechs Wochen sind gleich hoch
  // ═════════════════════════════════════════════════════════════════════

  group('Die Kachel wird nicht groß und klein', () {
    testWidgets(
      'ein Februar mit vier Zeilen ist so hoch wie ein August mit sechs',
      (tester) async {
        await oeffne(tester);

        // August 2027 — sechs Zeilen.
        expect(
          find.byKey(const Key('schlaf-kalender-tag-2027-08-31')),
          findsOneWidget,
          reason: 'Das Blatt steht nicht im August 2027.',
        );
        final august = blattMass(tester);

        for (var i = 0; i < 6; i++) {
          await einenMonatZurueck(tester);
        }

        // Februar 2027 — vier Zeilen.
        expect(
          find.byKey(const Key('schlaf-kalender-tag-2027-02-28')),
          findsOneWidget,
          reason: 'Das Blatt steht nicht im Februar 2027.',
        );
        final februar = blattMass(tester);

        expect(
          februar.height,
          august.height,
          reason:
              'Der Februar 2027 braucht vier Zeilen, der August 2027 sechs. '
              'Wechselt die Kachel dabei ihre Höhe, springt beim Blättern '
              'das ganze Blatt — genau Tims Beobachtung.',
        );
      },
    );

    testWidgets('und jeder Monat dazwischen ebenso', (tester) async {
      await oeffne(tester);

      final hoehen = <double>[blattMass(tester).height];
      for (var i = 0; i < 6; i++) {
        await einenMonatZurueck(tester);
        hoehen.add(blattMass(tester).height);
      }

      expect(
        hoehen.toSet(),
        hasLength(1),
        reason:
            'Februar bis August 2027 brauchen vier, fünf und sechs Zeilen. '
            'Gemessen: $hoehen',
      );
    });

    testWidgets('und die Breite bleibt es auch', (tester) async {
      await oeffne(tester);

      final august = blattMass(tester);
      for (var i = 0; i < 6; i++) {
        await einenMonatZurueck(tester);
      }

      expect(blattMass(tester).width, august.width);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  // 2 — Die Tage bleiben, wo sie sind
  // ═════════════════════════════════════════════════════════════════════

  group('Die überzähligen Zeilen stehen hinten, nicht vorn', () {
    testWidgets(
      'der Monatserste sitzt in jedem Monat auf derselben Höhe — die leeren '
      'Felder hängen unten an, sie schieben das Raster nicht nach unten',
      (tester) async {
        await oeffne(tester);

        final imAugust = tester.getTopLeft(
          find.byKey(const Key('schlaf-kalender-tag-2027-08-01')),
        );

        for (var i = 0; i < 6; i++) {
          await einenMonatZurueck(tester);
        }

        final imFebruar = tester.getTopLeft(
          find.byKey(const Key('schlaf-kalender-tag-2027-02-01')),
        );

        expect(imFebruar.dy, imAugust.dy);
      },
    );

    testWidgets('und der letzte Tag eines kurzen Monats steht trotzdem da', (
      tester,
    ) async {
      await oeffne(tester);

      for (var i = 0; i < 6; i++) {
        await einenMonatZurueck(tester);
      }

      expect(
        find.byKey(const Key('schlaf-kalender-tag-2027-02-28')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('schlaf-kalender-tag-2027-02-29')),
        findsNothing,
        reason: 'Der Februar 2027 hat 28 Tage — die Auffüllung erfindet keine.',
      );
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
