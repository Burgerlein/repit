import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/core/messwert.dart';
import 'package:repit/data/ziele.dart';
import 'package:repit/design/erholungs_karte.dart';
import 'package:repit/design/platzhalter.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_types.dart';
import 'package:repit/shell/heute_view.dart';
import 'package:repit/shell/router.dart';

/// Die Erholungskarte auf **Heute**, nachdem ihre drei Werte aus der Nacht
/// kommen (#193, Stufe 4). Die Rechnung selbst steht in
/// `erholung_nachtwerte_test.dart`; hier geht es um das, was ein
/// Zustandstest nicht sehen kann — **dass die Anzeige ihre Form behält.**
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden.
///
/// ## Warum diese Datei
///
/// Stufe 4 ist eine sichtbare Änderung: Wo bisher Apples Tageswert stand,
/// steht künftig nichts, wenn die Nacht keine Proben hergibt. Das ist
/// ehrlicher — aber es ist genau der Moment, in dem eine Anzeige
/// verschwindet, wenn niemand hinsieht. `CLAUDE.md`, „Eine Anzeige, die es
/// gibt, hat genau eine Form":
///
/// - **Werte da, keine Werte, lädt — dieselbe Höhe, dieselbe Breite,
///   dieselbe Stelle.** Nur die Füllung unterscheidet sich.
/// - **`0` ist keine Antwort auf „kein Wert".**
/// - **Während des Ladens steht nie ein „keine Daten"-Grund** (Fehler
///   `01`).
///
/// Bei `Kacheln` und bei dieser Karte springt sogar die Breite mit, weil
/// sich die verbliebenen Spalten den Platz teilen — eine fehlende Spalte
/// ist deshalb nicht nur unschön, sie verschiebt die übrigen drei.
///
/// ## Was hier **nicht** geprüft wird
///
/// - **Die Reihenfolge der vier Spalten** — gemeldet, nicht entschieden
///   (siehe `heute_erholungskarte_test.dart`).
/// - **Der Platzhalter** (`VitalWert.platzhalter`): Das Animieren der
///   grauen Flächen ist #24.
/// - **Der fehlende Grund auf dem Heute-Schirm** (#199) und die
///   Stand-Zeile (#200).
/// - **Wortlaut und Layout.** Geprüft werden Zustände und Übergänge.
///
/// ## Zahlen in dieser Datei
///
/// Alle erfunden (`CLAUDE.md`, Spec Abschnitt 12). Die Tageswerte sind
/// absichtlich andere als die Nachtwerte — sonst wäre nicht zu sehen,
/// welche von beiden die Karte zeigt.
void main() {
  // Montag, 12.10.2026, 09:15 Berliner Zeit (CEST, +2).
  final jetzt = DateTime.utc(2026, 10, 12, 7, 15);

  DateTime tagesbeginn(int tag) =>
      BerlinCalendar.startOfDay(DateTime.utc(2026, 10, tag, 12));

  String tagKey(int tag) => BerlinCalendar.dayKey(tagesbeginn(tag));

  DailyMetrics tagwert(int tag) => DailyMetrics(
    tag: tagKey(tag),
    // Die Tageswerte des Kanals: 62 bpm, 40 ms, 16/min. Keiner davon darf
    // nach Stufe 4 noch in der Karte landen.
    restingHR: 62,
    hrvMs: 40,
    respRate: 16,
    steps: 842,
    exerciseMinutes: 20,
  );

  SleepNight nachtVon(int tag, {double stunden = 7}) {
    final ende = tagesbeginn(tag).add(const Duration(hours: 6));
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

  List<DailyMetrics> tage() => [for (var t = 3; t <= 12; t++) tagwert(t)];

  List<SleepNight> naechte() => [for (var t = 3; t <= 12; t++) nachtVon(t)];

  /// Die Nachtwerte: 48 bpm, 50 ms, 13/min an allen zehn Tagen.
  Map<String, NightVitals> nachtkarte() => {
    for (var t = 3; t <= 12; t++)
      tagKey(t): const NightVitals(
        restingHeartRate: 48,
        hrv: 50,
        respiratoryRate: 13,
      ),
  };

  ({ProviderContainer container, Widget app}) harness({
    Messwert<Map<String, NightVitals>>? nachtwerte,
  }) {
    final router = AppRouter();
    // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        clockProvider.overrideWithValue(() => jetzt),
        dailyMetricsProvider.overrideWith(
          () => _Tageswerte(
            Bekannt<List<DailyMetrics>>(tage(), stand: jetzt, laeuft: false),
          ),
        ),
        sleepProvider.overrideWith(
          () => _Naechte(
            Bekannt<List<SleepNight>>(naechte(), stand: jetzt, laeuft: false),
          ),
        ),
        nachtWerteProvider.overrideWith(
          () => _Nachtwerte(
            nachtwerte ??
                Bekannt<Map<String, NightVitals>>(
                  nachtkarte(),
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

  // ─────────────────────────────────────────────────────────────────────

  group('Die Karte zeigt die Nachtwerte', () {
    testWidgets('Ruhepuls, HRV und Atemfrequenz kommen aus der Nacht', (
      tester,
    ) async {
      await zeige(tester, harness().app);

      expect(vital(tester, 'ruhepuls').wert, '48 bpm');
      expect(vital(tester, 'hrv').wert, '50 ms');
      expect(
        vital(tester, 'atem').wert,
        contains('13'),
        reason: '16/min wäre der Tageswert aus Apple Health',
      );
    });

    testWidgets('und ihr Normalwert darunter ebenso', (tester) async {
      await zeige(tester, harness().app);

      expect(
        vital(tester, 'hrv').hinweis,
        contains('50'),
        reason:
            'Wert und Median müssen aus derselben Quelle kommen — sonst sind '
            'beide Zahlen plausibel und die Ampel falsch',
      );
      expect(vital(tester, 'hrv').hinweis, isNot(contains('40')));
    });

    testWidgets('der Schlaf bleibt, woher er kam — aus den Nächten', (
      tester,
    ) async {
      await zeige(tester, harness().app);

      expect(vital(tester, 'schlaf').wert, isNotNull);
    });
  });

  group('Ohne Nachtwerte bleibt die Form', () {
    /// Dieselben vier Spalten in allen drei Zuständen. Fällt eine weg,
    /// wächst der Schirm, sobald der Wert eintrifft, und die verbliebenen
    /// Spalten teilen sich bis dahin die Breite.
    Future<List<String>> namen(
      WidgetTester tester,
      Messwert<Map<String, NightVitals>>? nachtwerte,
    ) async {
      await zeige(tester, harness(nachtwerte: nachtwerte).app);
      return [for (final v in karte(tester).vitalwerte) v.name];
    }

    testWidgets('ein leerer Nachtlauf nimmt keine Spalte weg', (tester) async {
      final mitWerten = await namen(tester, null);
      final ohneWerte = await namen(
        tester,
        LeerNachLauf<Map<String, NightVitals>>(gelaufen: jetzt),
      );

      expect(ohneWerte, mitWerten);
      expect(ohneWerte, hasLength(4));
    });

    testWidgets('und der laufende Nachtlauf auch nicht', (tester) async {
      final mitWerten = await namen(tester, null);
      final laedt = await namen(
        tester,
        const NochNie<Map<String, NightVitals>>(),
      );

      expect(laedt, mitWerten);
    });

    testWidgets(
      'eine Nacht ohne Proben sagt „keine Werte", sie verschwindet nicht — '
      'und steht nie auf 0',
      (tester) async {
        await zeige(
          tester,
          harness(
            nachtwerte: LeerNachLauf<Map<String, NightVitals>>(gelaufen: jetzt),
          ).app,
        );

        for (final teil in ['ruhepuls', 'hrv', 'atem']) {
          expect(
            vital(tester, teil).wert,
            isNull,
            reason:
                '„$teil" ohne Nachtwert zeigt $ohneWert — eine 0 behauptete '
                'eine Messung (Fehler 01)',
          );
        }
        expect(
          find.text(ohneWert),
          findsAtLeastNWidgets(3),
          reason: 'die drei Spalten stehen ungefüllt da',
        );
      },
    );

    testWidgets(
      'der Schlaf steht weiter, auch wenn der Nachtlauf gescheitert ist — '
      'ein gescheiterter Lauf nimmt keinen sichtbaren Wert weg',
      (tester) async {
        await zeige(
          tester,
          harness(
            nachtwerte: Fehlgeschlagen<Map<String, NightVitals>>(
              fehler: StateError('Kanal weg'),
              gelaufen: jetzt,
            ),
          ).app,
        );

        expect(vital(tester, 'schlaf').wert, isNotNull);
        expect(vital(tester, 'hrv').wert, isNull);
        expect(karte(tester).vitalwerte, hasLength(4));
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
