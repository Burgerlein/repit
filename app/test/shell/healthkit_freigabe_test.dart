import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repit/core/messwert.dart';
import 'package:repit/data/cache.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_types.dart';
import 'package:repit/shell/healthkit_test_view.dart';
import '../health/health_reading_attrappe.dart';

/// Tests zu #176 — „Nach der Freigabe muss die App neu gestartet werden".
///
/// Tim am Gerät, 29.10.2026: „ich erlaube es muss ganze app neustarten um
/// daten zu sehen". Der Freigabedialog erscheint beim ersten Lesezugriff,
/// also auf dem HealthKit-Test-Schirm; wer dort „Erlauben" antippt, sieht
/// bis zum Neustart weiter „keine Daten".
///
/// ## Was diese Datei festlegt — und was bewusst nicht
///
/// Festgelegt ist **Verhalten, kein Aufbau**: Nach der beantworteten
/// Freigabe liest der **laufende** Container neu, und zwar derselbe, der
/// vorher schon gelesen hat. Diese Datei nennt **keinen** neuen Provider
/// und keine neue Klasse — wie die Implementierung das erreicht (ein
/// Zustand, den die Lade-Notifier beobachten; ein Anstoß von der
/// Freigabe aus; etwas Drittes), entscheidet sie selbst. Deshalb läuft
/// hier alles über das, was es heute schon gibt: `HealthKitTestView`
/// (der Ort, an dem die Anfrage ausgelöst wird) und die beiden
/// Lade-Provider aus `health_provider.dart`.
///
/// Der Preis dafür ist, dass die Tests den Weg durch ein Widget nehmen,
/// obwohl der Fehler in der Datenschicht sitzt. Das ist Absicht: Ein Test,
/// der einen noch nicht existierenden Providernamen nennt, scheitert vor
/// der Implementierung nur am fehlenden Namen und beweist nichts (`CLAUDE.
/// md`, „Wer Tests schreibt, schreibt nicht die Implementierung").
///
/// ## Warum der erste Lauf leer ausgeht
///
/// Apple verrät den Lesestatus nicht: Eine Abfrage ohne Lesefreigabe
/// liefert **keine Probe**, sie scheitert nicht. Für die App sieht das
/// genauso aus wie „an diesem Tag ist nichts aufgezeichnet" — genau die
/// Ununterscheidbarkeit, die `CLAUDE.md` beschreibt. `_Freigabequelle`
/// unten bildet das nach: vor der beantworteten Freigabe eine leere
/// Liste, danach die Werte.
///
/// ## Was hier **nicht** geprüft wird
///
/// - **Wann der Dialog kommt.** Dass er erst auf dem Test-Schirm erscheint,
///   ist kein Fehler (iOS fragt beim ersten Lesezugriff) und wird von #176
///   ausdrücklich nicht geändert. Der Wächtertest „Tageswerte allein
///   fragen keine Freigabe an" hält genau das fest und ist von Anfang an
///   grün — er bewacht eine Behauptung über den Aufbau, kein neues
///   Verhalten.
/// - **Platzhalter/Skelette auf dem Test-Schirm** (Tims dritter Punkt).
///   Das ist ein eigener Schirm und eine eigene Entscheidung, liegt als
///   eigene Karte.
/// - **Layout und Wortlaut** (`CLAUDE.md`, Widget-Tests prüfen Zustände
///   und Übergänge).
///
/// ## Zahlen in dieser Datei
///
/// Ausschließlich erfunden. Keine Werte aus Tims Export, aus `docs/SPEC.md`
/// oder aus `docs/sample_export.json`.
void main() {
  // Fester Zeitpunkt statt `DateTime.now()` (Spec 5.3b).
  final jetzt = DateTime.utc(2026, 10, 20, 14, 32);
  const heute = '2026-10-20';

  final tageswerte = <DailyMetrics>[
    const DailyMetrics(tag: '2026-10-19', steps: 500),
    const DailyMetrics(tag: heute, steps: 8041, restingHR: 56),
  ];

  final naechte = <SleepNight>[
    SleepNight(
      date: DateTime.utc(2026, 10, 20),
      session: SleepSession(
        segments: [
          SleepSegment(
            stage: SleepStage.core,
            start: DateTime.utc(2026, 10, 19, 22, 10),
            end: DateTime.utc(2026, 10, 20, 5, 40),
          ),
        ],
      ),
    ),
  ];

  /// Ein Container mit In-Memory-Cache und der Fake-Quelle, wie in
  /// `health_provider_test.dart`. `retry: (_, _) => null` ist für Tests
  /// vorgeschrieben (`CLAUDE.md`).
  ProviderContainer behaelter(_Freigabequelle quelle) {
    final db = AppCache(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
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

  /// Der Test-Schirm in dem Rahmen, den sonst `MehrView` stellt — er bringt
  /// selbst keinen mit (Hausregel, siehe seinen Klassenkommentar).
  Widget schirm(ProviderContainer container) => UncontrolledProviderScope(
    container: container,
    child: const CupertinoApp(
      home: CupertinoPageScaffold(child: HealthKitTestView()),
    ),
  );

  Finder typZeile(String feld) => find.byKey(Key('healthkit-typ-$feld'));

  testWidgets(
    'nach dem Antippen von "Erlauben" stehen die Werte auf dem laufenden '
    'Schirm — ohne die App zu beenden (#176, Tims Befund vom 29.10.2026)',
    (tester) async {
      final dialog = Completer<void>();
      final quelle = _Freigabequelle(
        tageswerte: tageswerte,
        naechte: naechte,
        dialogAntwort: dialog,
      );
      final container = behaelter(quelle);

      await tester.pumpWidget(schirm(container));
      await tester.pumpAndSettle();

      // Der Dialog steht offen, der erste Lesezugriff ist durch und ging
      // leer aus — bis hierher ist alles richtig.
      expect(
        quelle.freigabeAnfragen,
        1,
        reason: 'der Schirm hat die eine Freigabe angefragt',
      );
      // **Geändert am 03.11.2026 (#182/#262).** Vorher stand hier
      // `findsNothing` auf der Zeile selbst. Seit das Gerüst in jedem
      // Zustand steht, ist das kein Maß mehr für „keine Probe" — die
      // Zeile ist da, sie ist nur ungefüllt. Geprüft wird deshalb, was
      // die Aussage immer schon war und was der Fall nach der Freigabe
      // spiegelt: Die Zahl steht nicht da.
      expect(
        typZeile('steps'),
        findsOneWidget,
        reason: 'das Geruest steht, auch bevor etwas gelesen wurde',
      );
      expect(
        find.textContaining('8041'),
        findsNothing,
        reason: 'ohne Freigabe liefert Apple Health keine Probe',
      );

      // Tim tippt "Erlauben".
      dialog.complete();
      await tester.pumpAndSettle();

      expect(
        quelle.tagesLaeufe,
        greaterThanOrEqualTo(2),
        reason:
            'der laufende Container fragt nach der Freigabe erneut — '
            'genau das passierte bisher erst beim nächsten App-Start',
      );
      expect(
        typZeile('steps'),
        findsOneWidget,
        reason:
            'die Zeilen stehen auf demselben Schirm, der vorher leer '
            'war; der Baum wurde nie neu aufgebaut',
      );
      expect(find.textContaining('8041'), findsWidgets);
    },
  );

  testWidgets('auch die Nächte werden nach der Freigabe neu gelesen — der '
      'Erholung-Schirm hängt an derselben Freigabe (#176)', (tester) async {
    final dialog = Completer<void>();
    final quelle = _Freigabequelle(
      tageswerte: tageswerte,
      naechte: naechte,
      dialogAntwort: dialog,
    );
    final container = behaelter(quelle);

    // Ein zweiter Schirm hört mit: Auf dem Gerät liegt der
    // Erholung-Schirm im Nachbar-Tab und hat seine Nächte längst
    // (ergebnislos) gelesen, während der Test-Schirm vorn ist.
    final beobachtet = <AsyncValue<Messwert<List<SleepNight>>>>[];
    container.listen(
      sleepProvider,
      (_, next) => beobachtet.add(next),
      fireImmediately: true,
    );

    await tester.pumpWidget(schirm(container));
    await tester.pumpAndSettle();

    expect(
      beobachtet.last.value,
      isA<LeerNachLauf<List<SleepNight>>>(),
      reason: 'ohne Freigabe kommt keine Nacht zurück',
    );

    dialog.complete();
    await tester.pumpAndSettle();

    final zuletzt = beobachtet.last.value;
    expect(
      zuletzt,
      isA<Bekannt<List<SleepNight>>>(),
      reason: 'die Nächte stehen nach der Freigabe da, ohne Neustart',
    );
    expect((zuletzt! as Bekannt<List<SleepNight>>).wert, hasLength(1));
  });

  testWidgets(
    'ein gescheiterter Nachlauf nach der Freigabe nimmt keinen sichtbaren '
    'Wert weg (CLAUDE.md) — und er findet überhaupt statt',
    (tester) async {
      final dialog = Completer<void>();
      final quelle = _Freigabequelle(
        tageswerte: tageswerte,
        naechte: naechte,
        dialogAntwort: dialog,
        // Dieser Fake hat schon vor der Freigabe Werte: So steht beim
        // Nachlauf etwas im Cache, das verloren gehen könnte.
        liefertAuchOhneFreigabe: true,
      );
      final container = behaelter(quelle);

      final beobachtet = <AsyncValue<Messwert<List<DailyMetrics>>>>[];
      container.listen(
        dailyMetricsProvider,
        (_, next) => beobachtet.add(next),
        fireImmediately: true,
      );

      await tester.pumpWidget(schirm(container));
      await tester.pumpAndSettle();
      expect(beobachtet.last.value, isA<Bekannt<List<DailyMetrics>>>());

      // Ab jetzt scheitert der Kanal — der Nachlauf nach der Freigabe
      // läuft also ins Leere.
      quelle.kanalScheitert = true;
      dialog.complete();
      await tester.pumpAndSettle();

      expect(
        quelle.tagesLaeufe,
        greaterThanOrEqualTo(2),
        reason:
            'der Nachlauf hat stattgefunden — sonst beweist der Rest '
            'dieses Tests nichts',
      );
      expect(
        beobachtet.map((a) => a.value).whereType<Fehlgeschlagen>(),
        isEmpty,
        reason:
            'ein gescheiterter Nachlauf nimmt keinen sichtbaren Wert '
            'weg, solange etwas zwischengespeichert ist (CLAUDE.md)',
      );
      expect(beobachtet.last.value, isA<Bekannt<List<DailyMetrics>>>());
      expect(
        typZeile('steps'),
        findsOneWidget,
        reason: 'auf dem Schirm steht weiter, was dastand',
      );
    },
  );

  testWidgets(
    'der eine Dialog pro Installation bleibt einer — auch über mehrere '
    'Bilder und einen Nachlauf hinweg (Wächter)',
    (tester) async {
      final dialog = Completer<void>();
      final quelle = _Freigabequelle(
        tageswerte: tageswerte,
        naechte: naechte,
        dialogAntwort: dialog,
      );
      final container = behaelter(quelle);

      await tester.pumpWidget(schirm(container));
      await tester.pumpAndSettle();
      dialog.complete();
      await tester.pumpAndSettle();
      await tester.pump();
      await tester.pump();

      expect(
        quelle.freigabeAnfragen,
        1,
        reason:
            'ein Dialog pro Installation (CLAUDE.md) — der Nachlauf '
            'darf keinen zweiten auslösen, sonst steht die App in einer '
            'Schleife aus Fragen und Nachläufen',
      );
    },
  );

  test('wer nur Tageswerte oder Nächte liest, löst keine Freigabe aus — der '
      'Dialog bleibt, wo er heute ist (Wächter zu #176 Punkt 1)', () async {
    final quelle = _Freigabequelle(tageswerte: tageswerte, naechte: naechte);
    final container = behaelter(quelle);

    await container.read(dailyMetricsProvider.future);
    await container.read(sleepProvider.future);
    await pumpEventQueue();

    expect(
      quelle.freigabeAnfragen,
      0,
      reason:
          'iOS fragt beim ersten Lesezugriff selbst; die App soll den '
          'Dialog nicht beim Start erzwingen, nur weil Home Tageswerte '
          'liest. Wer das ändern will, entscheidet das als eigene Karte, '
          'nicht nebenbei beim Beheben von #176.',
    );
  });
}

/// Fake-Quelle, die den HealthKit-Ablauf nachbildet: Vor der beantworteten
/// Freigabe kommt **nichts** zurück (Apple verrät den Lesestatus nicht und
/// liefert einfach keine Probe), danach die Werte.
///
/// [dialogAntwort] hält `requestAuthorization()` offen, solange der Test es
/// will — das ist der Moment, in dem der Dialog auf dem Gerät steht und Tim
/// noch nicht getippt hat. Ohne ihn liefe die Freigabe im selben Atemzug
/// durch wie der erste Lesezugriff, und kein Test könnte ein „vorher" von
/// einem „nachher" unterscheiden.
class _Freigabequelle extends HealthReadingAttrappe {
  _Freigabequelle({
    required this.tageswerte,
    required this.naechte,
    this.dialogAntwort,
    this.liefertAuchOhneFreigabe = false,
  });

  final List<DailyMetrics> tageswerte;
  final List<SleepNight> naechte;
  final Completer<void>? dialogAntwort;
  final bool liefertAuchOhneFreigabe;

  /// Von außen umschaltbar: ab dann scheitert jeder Lesezugriff.
  bool kanalScheitert = false;

  int freigabeAnfragen = 0;
  int tagesLaeufe = 0;
  int schlafLaeufe = 0;
  bool _freigegeben = false;

  bool get _liefert => _freigegeben || liefertAuchOhneFreigabe;

  @override
  DateTime get earliestPermittedDate => DateTime.utc(2000);

  @override
  Future<void> requestAuthorization() async {
    freigabeAnfragen += 1;
    await dialogAntwort?.future;
    _freigegeben = true;
  }

  @override
  Future<List<DailyMetrics>> dailyMetrics(
    DateTime from,
    DateTime through,
  ) async {
    tagesLaeufe += 1;
    if (kanalScheitert) throw Exception('Kanal nicht erreichbar');
    return _liefert ? tageswerte : const [];
  }

  @override
  Future<List<SleepNight>> sleepSessions(
    DateTime from,
    DateTime through,
  ) async {
    schlafLaeufe += 1;
    if (kanalScheitert) throw Exception('Kanal nicht erreichbar');
    return _liefert ? naechte : const [];
  }

  @override
  Future<List<WorkoutSample>> workouts(DateTime from, DateTime through) =>
      throw UnimplementedError('in dieser Testdatei nicht erwartet');

  @override
  Future<List<QuantitySample>> quantitySamples(
    VitalKind kind,
    DateTime from,
    DateTime through,
  ) => throw UnimplementedError('in dieser Testdatei nicht erwartet');

  @override
  Future<List<QuantitySample>> hourlySteps(DateTime from, DateTime through) =>
      throw UnimplementedError('in dieser Testdatei nicht erwartet');

  @override
  Future<List<NutritionEntry>> nutritionEntries(DateTime day) =>
      throw UnimplementedError('in dieser Testdatei nicht erwartet');
}
