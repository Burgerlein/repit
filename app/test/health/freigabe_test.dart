// Die Freigabe-Anfrage an Apple Health (#183).
//
// **Beobachtung, die dazu geführt hat** (Tim, 02.11.2026, auf dem iPhone):
// „wir haben keine freigabe auf diese daten aus apple health". Die Werte
// standen auf keinem Schirm, und der Grund war nicht ein fehlender Typ im
// Katalog — `HealthTypeCatalog` führt Gewicht, Körperfett und fettfreie
// Masse längst —, sondern dass die App **nie gefragt hat**:
// `requestAuthorization()` lief ausschließlich auf dem Diagnoseschirm
// *Mehr › HealthKit-Test*. Wer ihn nie öffnet, wird nie gefragt.
//
// Entschieden am 02.11.2026 von Tim: Die Anfrage gehört an den **ersten
// Lesezugriff**. Der erklärende Willkommensschirm kommt später und hat
// seinen Entwurf bereits (`docs/screens/screens/erststart.js`).
//
// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
// Diese Datei darf ausgeführt, aber nicht verändert werden.
//
// ## Nachtrag vom 03.11.2026 — der Auslöser ist der Schirm, nicht der
// Lade-Provider
//
// Diese Datei stammt aus dem Zweig `koerper-datenkette`. Dort war die
// Freigabe ein schlichter `FutureProvider<void>`, den `DailyMetricsNotifier`
// und `SleepNotifier` **abwarteten**, bevor sie den Kanal fragten. Auf
// `main` geht das nicht: Dort beobachten dieselben Notifier den
// Freigabe-**Stand** (`freigabeProvider`, #176), damit nach dem
// beantworteten Dialog ein Nachlauf stattfindet. Ein Auslöser **in** diesen
// Providern setzte genau den Stand, auf den sie warten — der eigene Lauf
// würde mitten im Laden entsorgt und gäbe nie einen Wert aus. Nachgemessen
// beim Zusammenführen: mit Auslöser im Provider 36 rote Fälle in
// `test/health`, ohne ihn 117 grüne.
//
// Gelöst ist es so: Der Auslöser steht in **`HeuteView.build`**
// (`ref.watch(freigabeAnfrageProvider)`, `lib/shell/heute_view.dart`) — und
// unverändert in `HealthKitTestView`. Beide Anforderungen bleiben damit
// erhalten: Der erste Schirm fragt nach der Freigabe (#183), und der
// beantwortete Dialog löst den Nachlauf aus (#176).
//
// **Was dieser Nachtrag an Prüfinhalt gekostet hat, steht unten unter
// „Was hier nicht mehr geprüft werden kann".** Nachgezogen hat die Datei
// der Test-Agent des Zusammenführens, nicht der Implementierende
// (`CLAUDE.md`, Rollentrennung). Tim hat die Entscheidung nicht gesehen.
//
// ## Was diese Datei verbindlich vorgibt
//
// ```dart
// /// Der beobachtbare Stand der einen Freigabe.
// enum Freigabestand { ungefragt, beantwortet }
// final freigabeProvider = NotifierProvider<FreigabeNotifier, Freigabestand>(…);
//
// /// Der Auslöser. Wer ihn beobachtet, fragt an.
// final freigabeAnfrageProvider = FutureProvider<void>(…);
// ```
//
// Und: `HeuteView` — der erste Schirm, den Tim sieht — beobachtet den
// Auslöser.
//
// ## Vier Festlegungen mit Begründung
//
// 1. **Beobachten fragt nicht.** `ref.watch(freigabeProvider)` darf keinen
//    Dialog auslösen, sonst zöge jeder Lade-Provider, der den Stand
//    beobachtet, den Dialog in den App-Start. Gefragt wird nur über
//    `freigabeAnfrageProvider`.
// 2. **Genau einmal.** Es gibt einen Dialog pro Installation
//    (`CLAUDE.md`). Zwei Leser, zwei Schirme, mehrfaches Neubauen
//    desselben Schirms — eine Anfrage.
// 3. **Gefragt wird überhaupt**, und zwar vom ersten Schirm. Ohne das ist
//    #183 nicht behoben: Apple liefert ohne Lesefreigabe eine **leere
//    Antwort ohne Fehler**, und der Schirm sagt dann „nichts aufgezeichnet
//    oder nicht freigegeben", obwohl die App nur hätte fragen müssen.
// 4. **Eine gescheiterte Anfrage hält den Lauf nicht auf.** Apple verrät
//    den Lesestatus nicht; ob die Freigabe fehlt oder nichts
//    aufgezeichnet wurde, ist nicht unterscheidbar. Wer bei einem Fehler
//    der Anfrage gar nicht erst liest, macht aus „vielleicht nichts da"
//    ein sicheres Nichts — und verliert den Cache gleich mit. Der Stand
//    bleibt dann `ungefragt`: Eine Anfrage, die geworfen hat, ist nicht
//    beantwortet worden.
//
// ## Was hier nicht mehr geprüft werden kann
//
// **Die Reihenfolge „Freigabe vor Lesezugriff" gibt es in der Datenschicht
// nicht mehr.** Der Zweig prüfte, dass `dailyMetricsProvider` die Anfrage
// abwartet, bevor er den Kanal fragt. Das ist seit #176 nicht nur ungeprüft,
// sondern ausdrücklich **nicht** mehr gewollt: `healthkit_freigabe_test.dart`
// hält als Wächter fest, dass ein reiner Lesezugriff **keine** Freigabe
// auslöst („der Dialog bleibt, wo er heute ist"). Beide Zusagen schließen
// einander aus; beim Zusammenführen hat die aus #176 gewonnen.
//
// An ihre Stelle tritt der Nachlauf: Der erste Lauf darf leer ausgehen,
// weil nach der beantworteten Freigabe ein zweiter folgt. Geprüft wird das
// in `test/shell/healthkit_freigabe_test.dart`, nicht hier.
//
// **Offen und gemeldet, nicht stillschweigend gestrichen:** Dass damit der
// allererste Lauf nach einer Neuinstallation leer zurückkommt, ist kein
// Fehler mehr, sondern der Weg — aber es ist eine andere Zusage als die,
// die im Kopf dieser Datei ursprünglich stand.
//
// **Alle Zahlen hier sind erfunden** — keine echten Gesundheitswerte.
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
// Gemeint sind die Kanal-Typen aus health_types.dart — der Kern hat seit #95
// eigene, schlanke Workout-Typen (zone_distribution.dart), deren Namen sonst
// mehrdeutig wären. Reine Entwirrung, keine Erwartung geändert.
import 'package:trainings_core/trainings_core.dart'
    hide WorkoutKind, WorkoutSample;

import 'package:repit/core/messwert.dart';
import 'package:repit/data/cache.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_types.dart';
import 'package:repit/shell/heute_view.dart';
import 'health_reading_attrappe.dart';

void main() {
  final jetzt = DateTime.utc(2026, 11, 2, 12);

  late _MitschnittReading quelle;
  late AppCache db;

  ProviderContainer behaelter() {
    final container = ProviderContainer(
      // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
      retry: (_, _) => null,
      overrides: [
        appCacheProvider.overrideWithValue(db),
        healthProvider.overrideWithValue(quelle),
        clockProvider.overrideWithValue(() => jetzt),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  /// `HeuteView` im Rahmen, den sonst `RootView` stellt — der Schirm bringt
  /// keinen eigenen mit (siehe `heute_view_test.dart`). Die Lade-Provider
  /// laufen hier **echt**, gegen die Mitschnitt-Quelle und eine
  /// In-Memory-Datenbank: Geprüft wird ja gerade die Verdrahtung.
  ({ProviderContainer container, Widget app}) schirm() {
    final container = behaelter();
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

  setUp(() {
    quelle = _MitschnittReading();
    db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);
  });

  group('Der Auslöser der Freigabe', () {
    test('fragt die Lesefreigabe an und meldet die Antwort weiter', () async {
      final container = behaelter();

      await container.read(freigabeAnfrageProvider.future);

      expect(quelle.freigabeAnfragen, 1);
      expect(
        container.read(freigabeProvider),
        Freigabestand.beantwortet,
        reason:
            'der Stand ist das, was die Lade-Provider beobachten (#176). '
            'Bliebe er auf `ungefragt`, fände der Nachlauf nach dem Dialog '
            'nicht statt — Tims Befund vom 29.10.2026, „ich erlaube es muss '
            'ganze app neustarten um daten zu sehen"',
      );
    });

    test('fragt genau einmal, egal wie viele Leser es gibt', () async {
      final container = behaelter();

      await Future.wait([
        container.read(freigabeAnfrageProvider.future),
        container.read(freigabeAnfrageProvider.future),
      ]);
      await container.read(freigabeAnfrageProvider.future);

      expect(
        quelle.freigabeAnfragen,
        1,
        reason:
            'Es gibt genau einen Berechtigungsdialog pro Installation '
            '(`CLAUDE.md`) — der Provider hält sein Ergebnis',
      );
    });

    test('den Stand nur zu beobachten löst keinen Dialog aus', () async {
      final container = behaelter();

      expect(container.read(freigabeProvider), Freigabestand.ungefragt);
      expect(
        quelle.freigabeAnfragen,
        0,
        reason:
            'die Lade-Provider beobachten diesen Stand, damit sie nach dem '
            'Dialog neu laufen (#176). Hätte das Beobachten selbst eine '
            'Nebenwirkung, zöge jeder von ihnen den Dialog in den '
            'App-Start — und über diesen Zeitpunkt hat niemand entschieden',
      );
    });

    test('eine gescheiterte Anfrage laesst den Stand auf ungefragt und '
        'reicht den Fehler durch', () async {
      // Nur die Quelle wird ersetzt; die Datenbank aus `setUp` bleibt.
      // Eine zweite `AppCache` auf demselben Testlauf warnt drift zu Recht
      // an (zwei Instanzen, ein Executor).
      quelle = _MitschnittReading(freigabeWirft: true);
      final container = behaelter();

      await expectLater(
        container.read(freigabeAnfrageProvider.future),
        throwsA(isA<StateError>()),
      );

      expect(
        container.read(freigabeProvider),
        Freigabestand.ungefragt,
        reason:
            'eine Anfrage, die geworfen hat, ist nicht beantwortet worden. '
            'Ein Stand auf `beantwortet` löste einen Nachlauf aus, dem '
            'nichts vorausgegangen ist — und verhinderte, dass später noch '
            'einmal gefragt wird',
      );
    });
  });

  group('Der erste Schirm fragt (#183)', () {
    testWidgets('HeuteView loest die Anfrage aus, ohne dass jemand sie von '
        'Hand liest', (tester) async {
      final h = schirm();

      await tester.pumpWidget(h.app);
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        quelle.freigabeAnfragen,
        1,
        reason:
            'genau das war #183: `requestAuthorization()` lief nur auf '
            '*Mehr › HealthKit-Test*, und wer den nie öffnete, wurde nie '
            'gefragt. Der Auslöser sitzt seit dem Zusammenführen hier, '
            'nicht mehr in den Lade-Providern (Nachtrag im Dateikopf)',
      );
    });

    testWidgets('und auch nach mehrfachem Neubauen bleibt es bei einem '
        'Dialog', (tester) async {
      final h = schirm();

      await tester.pumpWidget(h.app);
      await tester.pump(const Duration(milliseconds: 50));
      // Schirm verlassen und wieder öffnen — derselbe Container, also
      // dieselbe App-Sitzung.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(h.app);
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        quelle.freigabeAnfragen,
        1,
        reason:
            'ein Dialog pro Installation (`CLAUDE.md`). Ein Auslöser, der '
            'bei jedem Bauen neu fragt, stellte Tim bei jedem Tab-Wechsel '
            'einen Systemdialog in den Weg',
      );
    });
  });

  group('Eine gescheiterte Anfrage haelt den Lauf nicht auf', () {
    test('die Tageswerte kommen trotzdem', () async {
      // Nur die Quelle wird ersetzt; die Datenbank aus `setUp` bleibt.
      // Eine zweite `AppCache` auf demselben Testlauf warnt drift zu Recht
      // an (zwei Instanzen, ein Executor).
      quelle = _MitschnittReading(freigabeWirft: true);
      final container = behaelter();

      // Erst anfragen (und scheitern lassen), dann lesen — so herum steht
      // es auf dem Gerät: Der Schirm stößt die Anfrage an und baut
      // weiter.
      await expectLater(
        container.read(freigabeAnfrageProvider.future),
        throwsA(isA<StateError>()),
      );
      final werte = await container.read(dailyMetricsProvider.future);

      expect(
        quelle.verlauf,
        contains('dailyMetrics'),
        reason:
            'Apple verrät den Lesestatus nicht. Wer bei einem Fehler der '
            'Anfrage gar nicht erst liest, macht aus „vielleicht nichts da" '
            'ein sicheres Nichts',
      );
      expect(werte, isA<Bekannt<List<DailyMetrics>>>());
    });
  });
}

/// Schneidet mit, **was** gefragt wurde und **in welcher Reihenfolge**.
class _MitschnittReading extends HealthReadingAttrappe {
  _MitschnittReading({this.freigabeWirft = false});

  final bool freigabeWirft;

  final List<String> verlauf = [];
  int freigabeAnfragen = 0;

  @override
  DateTime get earliestPermittedDate => DateTime.utc(2000);

  @override
  Future<void> requestAuthorization() async {
    freigabeAnfragen += 1;
    verlauf.add('freigabe');
    // Eine kurze Pause: Ohne sie liefe ein Aufrufer, der nicht wirklich
    // abwartet, zufällig trotzdem in der richtigen Reihenfolge durch.
    await Future<void>.delayed(const Duration(milliseconds: 5));
    if (freigabeWirft) throw StateError('Freigabe abgelehnt');
  }

  @override
  Future<List<DailyMetrics>> dailyMetrics(
    DateTime from,
    DateTime through,
  ) async {
    verlauf.add('dailyMetrics');
    return [
      DailyMetrics(
        tag: BerlinCalendar.dayKey(DateTime.utc(2026, 11, 2)),
        weightKg: 82.4,
      ),
    ];
  }

  @override
  Future<List<SleepNight>> sleepSessions(
    DateTime from,
    DateTime through,
  ) async {
    verlauf.add('sleepSessions');
    return const [];
  }

  @override
  Future<List<WorkoutSample>> workouts(DateTime from, DateTime through) async {
    verlauf.add('workouts');
    return const [];
  }

  @override
  Future<List<QuantitySample>> quantitySamples(
    VitalKind kind,
    DateTime from,
    DateTime through,
  ) async {
    verlauf.add('quantitySamples');
    return const [];
  }

  @override
  Future<List<QuantitySample>> hourlySteps(
    DateTime from,
    DateTime through,
  ) async {
    verlauf.add('hourlySteps');
    return const [];
  }

  @override
  Future<List<NutritionEntry>> nutritionEntries(DateTime day) async {
    verlauf.add('nutritionEntries');
    return const [];
  }
}
