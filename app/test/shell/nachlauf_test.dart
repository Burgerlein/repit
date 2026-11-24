// Tests zum **Nachlauf beim Zurückkehren nach vorn** (#309).
//
// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
// Diese Datei darf ausgeführt, aber nicht verändert werden.
//
// ## Der Befund (Tim, 04.11.2026, 09:04)
//
// Apple Health zeigte für die Nacht 7 Std. 53 Min., unsere App 6:18 h. Die
// Rechnung war unschuldig: `SleepGrouping.phases` auf denselben Rohdaten
// ergibt eine Phase über 7,86 h. Die App hatte die Daten schlicht nicht —
// ihre Anzeige endete auf dem Stand vom frühen Morgen.
//
// Der Grund steht in `Tageswacht`: Sie ruft bei `AppLifecycleState.resumed`
// genau eine Sache auf, `pruefeTageswechsel()`, und die tut nur etwas, wenn
// sich der **Tag** geändert hat. Derselbe Tag → kein neuer Zustand → kein
// abgeleiteter Provider rechnet neu → **kein Lauf gegen HealthKit**.
// Gelesen wurde nur beim Kaltstart und um Mitternacht. Das trifft jeden
// Wert; beim Schlaf fällt es am stärksten auf, weil er sich morgens noch
// stundenlang ändert.
//
// ## Tims Entscheidung (04.11.2026)
//
// > „Beim Zurückkehren nach vorn wird nachgefragt — aber nur, wenn der
// > letzte Lauf eine Weile her ist."
//
// Nicht bei *jeder* Rückkehr: Ein Lauf holt dreißig Tage über alle Typen.
// Nicht nur zum Ziehen: Man müsste wissen, dass es nötig ist.
//
// ## Was diese Datei verbindlich vorgibt
//
// Eine benannte Konstante `nachlaufSchwelle` (`Duration`) in
// `lib/health/health_provider.dart`. **Ihr Wert ist hier nicht
// festgeschrieben** — er ist eine Entscheidung, keine Ableitung, und Tim
// kann ihn jederzeit anders wollen. Jeder Zeitpunkt unten ist deshalb aus
// der Konstante abgeleitet: Die Tests prüfen die Regel, nicht die Zahl.
//
// Dass der Anstoß in `Tageswacht` sitzt und nicht in einem zweiten
// Lebenszyklus-Beobachter, prüft `tageswacht_test.dart` mit („main.dart
// hängt sie unter den ProviderScope"); hier wird `Tageswacht` deshalb
// unmittelbar gepumpt.
//
// ## Was hier *nicht* geprüft wird
//
// Der Wortlaut der Stand-Zeile (die wäre #294) und das Layout irgendeines
// Schirms. Geprüft werden Zustände und Übergänge.
//
// **Alle Zeitpunkte und Zahlen hier sind erfunden** — kein echter
// Gesundheitswert.
import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/core/messwert.dart';
import 'package:repit/data/cache.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_types.dart';
import 'package:repit/shell/tageswacht.dart';
import '../health/health_reading_attrappe.dart';
import '../tag/behaelter_im_baum.dart';

void main() {
  /// Der erste Lauf: 03.11.2026, 06:45 UTC = 07:45 Berliner Winterzeit.
  /// Mitten am Tag, weit weg von jeder Tagesgrenze — was hier passiert,
  /// passiert wegen der Schwelle und nicht wegen Mitternacht.
  final ersterLauf = DateTime.utc(2026, 11, 3, 6, 45);

  /// Die Berliner Tagesgrenze zum 04.11.2026 — für den Fall, in dem der
  /// Tag wechselt, **obwohl** die Schwelle noch nicht abgelaufen ist.
  final tagesgrenze = BerlinCalendar.startOfDay(DateTime.utc(2026, 11, 4, 12));

  late _ZaehlendeQuelle quelle;
  late AppCache db;
  late ProviderContainer container;
  late DateTime jetzt;

  setUp(() {
    jetzt = ersterLauf;
    quelle = _ZaehlendeQuelle(nacht: _nacht(ersterLauf));
    db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);
    container = ProviderContainer(
      // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
      retry: (_, _) => null,
      overrides: [
        appCacheProvider.overrideWithValue(db),
        healthProvider.overrideWithValue(quelle),
        clockProvider.overrideWithValue(() => jetzt),
      ],
    );
    addTearDown(container.dispose);
  });

  /// Pumpt die Wacht und hält die beiden Lade-Provider am Leben, so wie es
  /// ein offener Schirm täte. Ohne einen Leser gäbe es die Provider nicht,
  /// und dann gäbe es auch nichts nachzuladen.
  Future<void> zeige(WidgetTester tester) async {
    container.listen(dailyMetricsProvider, (_, _) {});
    container.listen(sleepProvider, (_, _) {});
    await tester.pumpWidget(
      BehaelterImBaum(
        container: container,
        child: const Tageswacht(child: SizedBox.shrink()),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Schickt einen Lebenszyklus-Zustand so, wie die Plattform ihn schickt —
  /// über `SystemChannels.lifecycle`. Dieselbe Hilfe wie in
  /// `tageswacht_test.dart`; die Binding-Methode selbst ist `@protected`.
  Future<void> sendeLebenszyklus(
    WidgetTester tester,
    AppLifecycleState zustand,
  ) {
    return tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.lifecycle.name,
      const StringCodec().encodeMessage(zustand.toString()),
      (_) {},
    );
  }

  /// App weg, Uhr weiterstellen, App zurück.
  Future<void> wegUndZurueck(WidgetTester tester, DateTime neueUhrzeit) async {
    await sendeLebenszyklus(tester, AppLifecycleState.paused);
    jetzt = neueUhrzeit;
    await sendeLebenszyklus(tester, AppLifecycleState.resumed);
    await tester.pumpAndSettle();
  }

  group('Nachlauf — die Schwelle entscheidet', () {
    testWidgets(
      'der letzte Lauf ist länger her als die Schwelle: es läuft neu',
      (tester) async {
        await zeige(tester);
        expect(quelle.tageswerteRufe, 1, reason: 'Testvoraussetzung');
        expect(quelle.schlafRufe, 1, reason: 'Testvoraussetzung');

        await wegUndZurueck(
          tester,
          ersterLauf.add(nachlaufSchwelle + const Duration(minutes: 1)),
        );

        expect(
          quelle.tageswerteRufe,
          2,
          reason:
              'Genau der Fall vom 04.11.2026: Die App kommt nach vorn, der '
              'letzte Lauf ist Stunden her — dann muss sie fragen (#309).',
        );
        expect(
          quelle.schlafRufe,
          2,
          reason:
              'Beim Schlaf ist es Tim aufgefallen: Er wächst morgens noch '
              'stundenlang weiter.',
        );
      },
    );

    testWidgets('der letzte Lauf ist eben erst gewesen: es läuft nicht neu', (
      tester,
    ) async {
      await zeige(tester);
      expect(quelle.tageswerteRufe, 1, reason: 'Testvoraussetzung');

      await wegUndZurueck(tester, ersterLauf.add(nachlaufSchwelle ~/ 2));

      expect(
        quelle.tageswerteRufe,
        1,
        reason:
            'Ein Lauf holt dreißig Tage über alle Typen. Wer zehnmal am '
            'Tag zwischen Apps wechselt, löste sonst zehn volle Läufe aus '
            '(Tim, 04.11.2026).',
      );
      expect(quelle.schlafRufe, 1);
    });

    testWidgets(
      'der Tag wechselt: es läuft neu, auch wenn die Schwelle noch nicht '
      'abgelaufen ist',
      (tester) async {
        jetzt = tagesgrenze.subtract(nachlaufSchwelle ~/ 4);
        quelle = _ZaehlendeQuelle(nacht: _nacht(ersterLauf));
        container = ProviderContainer(
          retry: (_, _) => null,
          overrides: [
            appCacheProvider.overrideWithValue(db),
            healthProvider.overrideWithValue(quelle),
            clockProvider.overrideWithValue(() => jetzt),
          ],
        );
        addTearDown(container.dispose);

        await zeige(tester);
        final tagVorher = container.read(heutigerTagProvider);
        expect(quelle.tageswerteRufe, 1, reason: 'Testvoraussetzung');

        // Eine halbe Schwelle später — aber über Mitternacht hinweg.
        await wegUndZurueck(tester, tagesgrenze.add(nachlaufSchwelle ~/ 4));

        expect(
          container.read(heutigerTagProvider),
          isNot(tagVorher),
          reason: 'Testvoraussetzung: der Berliner Kalendertag ist gewechselt',
        );
        expect(
          quelle.tageswerteRufe,
          2,
          reason:
              'Der Tageswechsel bleibt, wie er ist — der neue Anstoß kommt '
              'dazu, er ersetzt ihn nicht. Sonst zeigt „Heute" gestern '
              '(#124).',
        );
      },
    );
  });

  group('Nachlauf — was dabei nicht passieren darf', () {
    testWidgets('kein zweiter Lauf, während schon einer unterwegs ist', (
      tester,
    ) async {
      await zeige(tester);
      expect(quelle.tageswerteRufe, 1, reason: 'Testvoraussetzung');

      // Der nächste Lauf hängt, bis wir ihn freigeben.
      final haenger = Completer<List<DailyMetrics>>();
      quelle.naechsteTageswerte = () => haenger.future;

      await sendeLebenszyklus(tester, AppLifecycleState.paused);
      jetzt = ersterLauf.add(nachlaufSchwelle + const Duration(minutes: 1));
      await sendeLebenszyklus(tester, AppLifecycleState.resumed);
      await tester.pump();
      expect(
        quelle.tageswerteRufe,
        2,
        reason: 'Testvoraussetzung: der Nachlauf ist angestoßen und hängt',
      );

      // Noch einmal nach vorn, während der Lauf von eben noch unterwegs
      // ist. Die Uhr läuft dabei weiter — die Schwelle allein würde einen
      // zweiten Lauf also erlauben.
      await sendeLebenszyklus(tester, AppLifecycleState.paused);
      jetzt = jetzt.add(nachlaufSchwelle + const Duration(minutes: 1));
      await sendeLebenszyklus(tester, AppLifecycleState.resumed);
      await tester.pump();

      expect(
        quelle.tageswerteRufe,
        2,
        reason:
            'Es läuft bereits einer. Ein zweiter nähme dem ersten nur seinen '
            'Platz weg und käme keine Sekunde früher an.',
      );

      haenger.complete(const [DailyMetrics(tag: '2026-11-03', steps: 4200)]);
      await tester.pumpAndSettle();
    });

    testWidgets('der Cache bleibt stehen, während der Nachlauf läuft — kein '
        'Platzhalter, kein „keine Daten"', (tester) async {
      await zeige(tester);

      final gesehen = <Messwert<List<DailyMetrics>>>[];
      container.listen<AsyncValue<Messwert<List<DailyMetrics>>>>(
        dailyMetricsProvider,
        (_, next) {
          final wert = next.value;
          if (wert != null) gesehen.add(wert);
        },
        fireImmediately: true,
      );

      final haenger = Completer<List<DailyMetrics>>();
      quelle.naechsteTageswerte = () => haenger.future;
      await wegUndZurueck(
        tester,
        ersterLauf.add(nachlaufSchwelle + const Duration(minutes: 1)),
      );

      expect(
        gesehen.whereType<NochNie<List<DailyMetrics>>>(),
        isEmpty,
        reason:
            'Der Platzhalter gehört allein in `NochNie`, und das ist der '
            'Zustand ohne jeden Wert — über einem vorhandenen blitzt er '
            'nicht auf (`CLAUDE.md`).',
      );
      expect(
        gesehen.whereType<LeerNachLauf<List<DailyMetrics>>>(),
        isEmpty,
        reason:
            'Während des Ladens steht nie ein „keine Daten"-Grund — das '
            'ist Fehler `01`.',
      );
      expect(
        gesehen.last,
        isA<Bekannt<List<DailyMetrics>>>().having(
          (b) => b.laeuft,
          'laeuft',
          isTrue,
        ),
        reason:
            'Zuerst der Cache, dann HealthKit: `Bekannt(…, laeuft: true)` '
            'trägt die Zeile „Stand 07:45 · wird aktualisiert".',
      );

      haenger.complete(const [DailyMetrics(tag: '2026-11-03', steps: 4200)]);
      await tester.pumpAndSettle();
    });

    testWidgets(
      'ein leerer Nachlauf nimmt den zwischengespeicherten Wert nicht weg '
      '(#224)',
      (tester) async {
        await zeige(tester);

        quelle.naechsteTageswerte = () async => const <DailyMetrics>[];
        await wegUndZurueck(
          tester,
          ersterLauf.add(nachlaufSchwelle + const Duration(minutes: 1)),
        );

        final ergebnis = container.read(dailyMetricsProvider).value;
        expect(
          ergebnis,
          isA<Bekannt<List<DailyMetrics>>>(),
          reason:
              'Apple verrät den Lesestatus nicht — „keine Daten" und „nicht '
              'erlaubt" sind nicht unterscheidbar (#224). Der neue Anstoß '
              'darf diese Regel nicht umgehen.',
        );
        expect(
          (ergebnis! as Bekannt<List<DailyMetrics>>).stand,
          ersterLauf,
          reason:
              'Die Stand-Zeile nennt den Lauf, der diesen Wert gesehen hat — '
              'und das war nicht der leere von jetzt.',
        );
      },
    );

    testWidgets(
      'inactive allein stößt nichts an — das Kontrollzentrum ist keine '
      'Rückkehr',
      (tester) async {
        await zeige(tester);

        jetzt = ersterLauf.add(nachlaufSchwelle + const Duration(minutes: 1));
        await sendeLebenszyklus(tester, AppLifecycleState.inactive);
        await tester.pumpAndSettle();

        expect(
          quelle.tageswerteRufe,
          1,
          reason:
              'inactive läuft auf iOS auch dann durch, wenn die App gar '
              'nicht weg war. Jeder Weg zurück nach vorn endet bei resumed.',
        );

        await sendeLebenszyklus(tester, AppLifecycleState.resumed);
        await tester.pumpAndSettle();

        expect(quelle.tageswerteRufe, 2);
      },
    );
  });
}

/// Eine gemessene Nacht mit einem durchgehenden Abschnitt: 21:00 Berliner
/// Zeit am Vorabend bis 06:00 am Aufwachtag. Erfunden.
SleepNight _nacht(DateTime um) {
  final beginn = BerlinCalendar.startOfDay(um);
  return SleepNight(
    date: beginn,
    session: SleepSession(
      segments: [
        SleepSegment(
          stage: SleepStage.core,
          start: beginn.subtract(const Duration(hours: 3)),
          end: beginn.add(const Duration(hours: 6)),
        ),
      ],
    ),
  );
}

/// Zählt die Kanal-Aufrufe und lässt den nächsten austauschen.
class _ZaehlendeQuelle extends HealthReadingAttrappe {
  _ZaehlendeQuelle({required this.nacht});

  final SleepNight nacht;
  int tageswerteRufe = 0;
  int schlafRufe = 0;
  FutureOr<List<DailyMetrics>> Function()? naechsteTageswerte;

  @override
  DateTime get earliestPermittedDate => DateTime.utc(2000);

  @override
  Future<List<DailyMetrics>> dailyMetrics(
    DateTime from,
    DateTime through,
  ) async {
    tageswerteRufe += 1;
    final antwort = naechsteTageswerte;
    if (antwort != null) {
      naechsteTageswerte = null;
      return await antwort();
    }
    return const [DailyMetrics(tag: '2026-11-03', steps: 4200)];
  }

  @override
  Future<List<SleepNight>> sleepSessions(
    DateTime from,
    DateTime through,
  ) async {
    schlafRufe += 1;
    return [nacht];
  }
}
