import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
// Der Kern hat seit #95 eigene, schlanke Workout-Typen für die
// Zonen-Rechnung (zone_distribution.dart). Hier sind die Kanal-Typen aus
// health_types.dart gemeint — die Kern-Namen bleiben draußen, genau wie in
// `lib/gym/gym_puls_provider.dart` und den vier Dateien aus 7d61227.
import 'package:trainings_core/trainings_core.dart'
    hide WorkoutKind, WorkoutSample;

import 'package:repit/data/cache.dart';
import 'package:repit/data/gym_repository.dart';
import 'package:repit/gym/gym_verlauf_view.dart';
import 'package:repit/health/health_provider.dart'
    show appCacheProvider, clockProvider, healthProvider;
import 'package:repit/health/health_types.dart';

import '../health/health_reading_attrappe.dart';
import 'log_support.dart' show Uhr;
import 'verlauf_support.dart';

/// Gemeinsame Hülle, Schlüssel, Quelle und Fixturen der Widget-Tests zum
/// **Pulsverlauf und Übungsband** im Gym-Verlauf (#512),
/// `lib/gym/gym_verlauf_view.dart`.
///
/// Grundlage ist `docs/superpowers/specs/2026-11-16-gym-puls-design.md`, vor
/// allem die Abschnitte 3 (Datenkette), 5 (Zustände), 6 (der Block), 7
/// (Band und Zeilen) und 8 (Lesen und Halten). Geschrieben **ohne** die
/// Implementierung gesehen zu haben.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Dateien dürfen ausgeführt, aber nicht verändert werden.
///
/// ## Was die Hülle voraussetzt
///
/// Die Hülle des Verlaufs (`verlauf_support.dart`) überschreibt
/// `healthProvider` nicht — dort wirft er. [pulsHuelle] baut dieselbe Hülle
/// **mit** einer [PulsQuelle] als `healthProvider`, einer Attrappe, die
/// Trainings und Herzfrequenz-Stichproben **so antwortet wie der Kanal** und
/// jeden Aufruf mitschreibt. Die Tests wissen nicht, wie der Schirm intern
/// liest — sie sehen nur Schlüssel und die Aufrufe an die Quelle.
///
/// ## Festgelegte Schlüssel
///
/// `<id>` ist `ImportedSession.id`, `<uid>` ist `Exercise.id`, `<n>` die
/// Position der Übung in der Sitzung ab 1.
///
/// | Schlüssel | Was |
/// |---|---|
/// | `gym-puls-<id>` | der Block als Ganzes **und** sein `Semantics`-Knoten — steht in jeder offenen Karte in jedem Zustand |
/// | `gym-puls-wert-<id>` | Ø-Platz: Zahl, `–/–` oder graue Form |
/// | `gym-puls-bereich-<id>` | Min–Max-Platz |
/// | `gym-puls-flaeche-<id>` | die Fläche der Spannen (oder, ohne Puls, Grund/Hinweis/graue Form) |
/// | `gym-puls-grund-<id>` | der Grund — **nur** bei `LeerNachLauf` |
/// | `gym-puls-fehler-<id>` | der Hinweis — **nur** bei `Fehlgeschlagen` |
/// | `gym-verlauf-band-<id>` | das Band — nur, wo mindestens ein Abschnitt entsteht |
/// | `gym-verlauf-band-<id>-<n>` | das Segment der Übung an Position `n` |
/// | `gym-verlauf-bandgrund-<id>` | der Satz, warum es kein Band gibt — nur bei `Bekannt` ohne Abschnitt |
/// | `gym-verlauf-nr-<id>-<uid>` | die Ziffer vor der Übungszeile — nur bei Abschnitt |
/// | `gym-verlauf-uebungspuls-<id>-<uid>` | das Ø rechts in der Zeile — nur bei Abschnitt |
///
/// **Alle Zeitpunkte sind UTC**, alle Daten erfunden, **kein reales
/// Ereignis, keine echten Gesundheitsdaten.** Heute ist Montag, 09.03.2026,
/// 10:00 Berliner Zeit (`verlaufJetzt`); `vormittag(n)` ist 08:00 Berliner
/// Zeit, `n` Tage zurück.

/* ---- Schlüssel ------------------------------------------------------- */

Key kPuls(String id) => Key('gym-puls-$id');
Key kPulsWert(String id) => Key('gym-puls-wert-$id');
Key kPulsBereich(String id) => Key('gym-puls-bereich-$id');
Key kPulsFlaeche(String id) => Key('gym-puls-flaeche-$id');
Key kPulsGrund(String id) => Key('gym-puls-grund-$id');
Key kPulsFehler(String id) => Key('gym-puls-fehler-$id');
Key kBandAbschnitt(String id, int n) => Key('gym-verlauf-band-$id-$n');
Key kBandGrund(String id) => Key('gym-verlauf-bandgrund-$id');
Key kUebungNr(String id, String uid) => Key('gym-verlauf-nr-$id-$uid');
Key kUebungPuls(String id, String uid) =>
    Key('gym-verlauf-uebungspuls-$id-$uid');

/* ---- Die Quelle ------------------------------------------------------ */

/// Eine Attrappe von `HealthReading`, die Trainings und Herzfrequenz so
/// antwortet wie der Kanal — und mitschreibt, was gefragt wurde.
///
/// - [workouts] liefert, wie `HealthKitReading.workouts`, die Trainings, deren
///   **Berliner Tag** zwischen dem Berliner Tag von `from` und dem von
///   `through` liegt (beide eingeschlossen).
/// - [quantitySamples] liefert die Stichproben der **gefragten Art** im Fenster
///   `[from, through]`, aufsteigend.
/// - [leerOhneFreigabe]: Solange die Freigabe nicht beantwortet ist, antwortet
///   die Quelle **leer und ohne Fehler** — wie Apple Health ohne Lesefreigabe
///   (`CLAUDE.md`, #176).
///
/// Die Tore halten die Antwort an, bis der Test sie erfüllt.
class PulsQuelle extends HealthReadingAttrappe {
  PulsQuelle();

  final List<WorkoutSample> trainings = [];
  final List<QuantitySample> puls = [];

  Completer<void>? trainingsTor;
  Completer<void>? probenTor;
  Completer<void>? freigabeTor;

  /// Lässt `workouts` für **jeden** Tag scheitern.
  bool trainingsScheitern = false;

  /// Lässt `quantitySamples` scheitern.
  bool probenScheitern = false;

  /// Berliner Tagesschlüssel (`BerlinCalendar.dayKey`), für die `workouts`
  /// scheitert.
  final Set<String> scheiterTage = {};

  bool leerOhneFreigabe = false;
  bool _freigegeben = false;

  int freigabeAnfragen = 0;
  final List<({DateTime from, DateTime through})> trainingsAnfragen = [];
  final List<({VitalKind kind, DateTime from, DateTime through})>
  probenAnfragen = [];

  @override
  Future<void> requestAuthorization() async {
    freigabeAnfragen++;
    await freigabeTor?.future;
    _freigegeben = true;
  }

  @override
  Future<List<WorkoutSample>> workouts(DateTime from, DateTime through) async {
    trainingsAnfragen.add((from: from, through: through));
    await trainingsTor?.future;
    if (trainingsScheitern || scheiterTage.contains(BerlinCalendar.dayKey(from))) {
      throw StateError('HealthKit antwortet nicht (vom Test erzwungen)');
    }
    if (leerOhneFreigabe && !_freigegeben) return const [];
    final von = BerlinCalendar.startOfDay(from);
    final bis = BerlinCalendar.startOfDay(through);
    return [
      for (final training in trainings)
        if (!BerlinCalendar.startOfDay(training.start).isBefore(von) &&
            !BerlinCalendar.startOfDay(training.start).isAfter(bis))
          training,
    ]..sort((a, b) => a.start.compareTo(b.start));
  }

  @override
  Future<List<QuantitySample>> quantitySamples(
    VitalKind kind,
    DateTime from,
    DateTime through,
  ) async {
    probenAnfragen.add((kind: kind, from: from, through: through));
    await probenTor?.future;
    if (probenScheitern) {
      throw StateError('HealthKit antwortet nicht (vom Test erzwungen)');
    }
    if (leerOhneFreigabe && !_freigegeben) return const [];
    if (kind != VitalKind.heartRate) return const [];
    return [
      for (final probe in puls)
        if (!probe.date.isBefore(from) && !probe.date.isAfter(through)) probe,
    ]..sort((a, b) => a.date.compareTo(b.date));
  }

  /// Lässt alle angehaltenen Antworten durch.
  void gibAlleFrei() {
    for (final tor in [trainingsTor, probenTor, freigabeTor]) {
      if (tor != null && !tor.isCompleted) tor.complete();
    }
  }
}

/* ---- Fixturen -------------------------------------------------------- */

/// Ein Apple-Krafttraining zur Sitzung [tage] Tage zurück: Beginn
/// [vormittag] (+ [versatz]), Dauer [minuten].
///
/// `avgHR` und `maxHR` sind **absichtlich andere Zahlen** als die der
/// Stichproben ([standardProben]): Wer die Kopfzeile aus Apples Statistik
/// statt aus den Stichproben füllt, zeigt hier 99 statt 123 (Spec,
/// Entscheidung 1).
///
/// [ortszeit]: Der Beginn kommt als Ortszeit, wie ihn der Kanal liefert
/// (`DateTime.fromMillisecondsSinceEpoch`).
WorkoutSample kraft(
  int tage, {
  double minuten = 68,
  WorkoutKind art = WorkoutKind.strength,
  Duration versatz = Duration.zero,
  String? id,
  bool ortszeit = false,
}) {
  final beginn = vormittag(tage).add(versatz);
  return WorkoutSample(
    id: id ?? 'W-$tage',
    start: ortszeit
        ? DateTime.fromMillisecondsSinceEpoch(beginn.millisecondsSinceEpoch)
        : beginn,
    kind: art,
    minutes: minuten,
    avgHR: 99,
    maxHR: 150,
  );
}

/// Herzfrequenz-Stichproben: Minuten nach [start] → Schläge pro Minute.
List<QuantitySample> proben(
  DateTime start,
  Map<int, double> nachMinute, {
  bool ortszeit = false,
}) => [
  for (final eintrag in nachMinute.entries)
    QuantitySample(
      date: _zeit(start.add(Duration(minutes: eintrag.key)), ortszeit),
      value: eintrag.value,
    ),
];

DateTime _zeit(DateTime zeit, bool ortszeit) => ortszeit
    ? DateTime.fromMillisecondsSinceEpoch(zeit.millisecondsSinceEpoch)
    : zeit;

/// Neun Stichproben über ein Training von 68 Minuten, Minute → Wert.
///
/// - Übung 1 (Minuten 3 bis 19) sieht 110, 120, 130 → **Ø 120**.
/// - Die 200 bei Minute 20 und die 150 bei Minute 34 liegen **in den Lücken**
///   zwischen den Übungen und zählen für kein Ø einer Übung.
/// - Übung 2 (21 bis 33) sieht 100 und 110 → **Ø 105**.
/// - Übung 3 (47 bis 57) sieht **nichts** → `Ø –/–`.
/// - Über das ganze Training (0 bis 68, beide Grenzen): Summe 1105, neun
///   Proben → **Ø 123** (122,78), **90 bis 200**.
const standardProben = <int, double>{
  0: 90,
  3: 110,
  10: 120,
  19: 130,
  20: 200,
  21: 100,
  33: 110,
  34: 150,
  68: 95,
};

/// Die Übungen mit Satzzeiten (Minuten nach Beginn des Trainings an Tag
/// [tage]) — oder, mit [mitZeiten] `false`, dieselben ohne: so kommt alles
/// Übernommene herein.
///
/// Position 1 Bankdrücken (3, 19), 2 Schrägbankdrücken (21, 33), 3 Dips
/// (47, 57), 4 Seitheben **ohne** Zeiten.
List<ImportedExercise> bandUebungen(int tage, {bool mitZeiten = true}) {
  DateTime? z(int minute) =>
      mitZeiten ? vormittag(tage).add(Duration(minutes: minute)) : null;
  return [
    uebung(idBank, [(60, 10), (62.5, 8)], zeiten: [z(3), z(19)]),
    uebung(idSchraeg, [(22, 12), (22, 10)], zeiten: [z(21), z(33)]),
    uebung(idDips, [(25, 9), (25, 8)], zeiten: [z(47), z(57)]),
    uebung(idSeitheben, [(10, 15), (10, 12)]),
  ];
}

const idSchraeg = 'inclineDumbbellPress';

/// Eine Sitzung am Tag [tage] zurück mit den [bandUebungen].
ImportedSession pulsSitzung(
  String id,
  int tage, {
  bool mitZeiten = false,
  List<ImportedExercise>? uebungen,
}) => sitzung(
  id: id,
  datum: vormittag(tage),
  uebungen: uebungen ?? bandUebungen(tage, mitZeiten: mitZeiten),
);

/* ---- Hülle ----------------------------------------------------------- */

/// [VerlaufHuelle] samt Quelle.
class PulsHuelle {
  PulsHuelle({required this.h, required this.quelle});

  final VerlaufHuelle h;
  final PulsQuelle quelle;

  /// Das Training und die Stichproben für die Sitzung [tage] zurück —
  /// [standardProben] über 68 Minuten.
  void fuelleTag(int tage, {bool ortszeit = false}) {
    quelle.trainings.add(kraft(tage, ortszeit: ortszeit));
    quelle.puls.addAll(
      proben(vormittag(tage), standardProben, ortszeit: ortszeit),
    );
  }

  /// Die verschiedenen Berliner Tage, für die `workouts` gefragt wurde.
  Set<String> gefragteTage() => {
    for (final anfrage in quelle.trainingsAnfragen)
      BerlinCalendar.dayKey(anfrage.from),
  };
}

/// Baut Datenbank, Ablage, Uhr, Container, Quelle und App. **Pumpt nichts.**
///
/// `retry: (_, _) => null` nach `CLAUDE.md`: In Tests ist Riverpods
/// Wiederholung abgeschaltet.
PulsHuelle pulsHuelle() {
  final db = AppCache(NativeDatabase.memory());
  addTearDown(db.close);
  final ablage = VerlaufAblage(db);
  final uhr = Uhr(verlaufJetzt);
  final quelle = PulsQuelle();

  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      appCacheProvider.overrideWithValue(db),
      gymRepositoryProvider.overrideWithValue(ablage),
      clockProvider.overrideWithValue(() => uhr.jetzt),
      healthProvider.overrideWithValue(quelle),
    ],
  );
  addTearDown(container.dispose);

  final app = UncontrolledProviderScope(
    container: container,
    child: CupertinoApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(padding: const EdgeInsets.only(top: 47, bottom: 34)),
        child: child!,
      ),
      home: const _Uebersicht(),
    ),
  );

  return PulsHuelle(
    h: VerlaufHuelle(
      container: container,
      db: db,
      ablage: ablage,
      uhr: uhr,
      app: app,
    ),
    quelle: quelle,
  );
}

class _Uebersicht extends StatelessWidget {
  const _Uebersicht();

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    child: SafeArea(
      child: CupertinoButton(
        key: kVerlaufHuelleOeffnen,
        onPressed: () => Navigator.of(context).push(
          CupertinoPageRoute<void>(builder: (_) => const GymVerlaufView()),
        ),
        child: const Text('Verlauf'),
      ),
    ),
  );
}

/// Ein Test mit Hülle — und **immer** sauber abgebaut, auch wenn eine
/// Erwartung scheitert.
void pulsTest(
  String name,
  Future<void> Function(WidgetTester tester, PulsHuelle p) body,
) {
  testWidgets(name, (tester) async {
    final p = pulsHuelle();
    try {
      await body(tester, p);
    } finally {
      p.quelle.gibAlleFrei();
      await abbauen(tester, p.h);
    }
  });
}

/* ---- Bedienung und Lesehilfen ---------------------------------------- */

/// Alle grauen Formen **im Block** der Karte [id].
Finder platzhalterImBlock(String id) =>
    find.descendant(of: find.byKey(kPuls(id)), matching: platzhalter());

/// Alle Texte im Block der Karte [id], flach.
String blockText(WidgetTester tester, String id) =>
    verlaufText(tester, kPuls(id));

/// Maß des Blocks.
Size blockGroesse(WidgetTester tester, String id) =>
    tester.getSize(find.byKey(kPuls(id)));

/// Abstand der Oberkante des Blocks zur Oberkante des Karteninhalts.
double blockOben(WidgetTester tester, String id) =>
    tester.getTopLeft(find.byKey(kPuls(id))).dy -
    tester.getTopLeft(find.byKey(kVerlaufInhalt(id))).dy;

/// Der Schirm hat gelesen und alles ist eingetroffen.
Future<void> zeigeVerlaufMitPuls(WidgetTester tester, PulsHuelle p) async {
  await zeigeVerlauf(tester, p.h);
  await verstreiche(tester);
}

/// Öffnet den Schirm von der Übersicht aus und prüft **in kleinen Schritten**
/// nach jedem Bild — damit eine graue Form, die nur für ein Bild aufblitzt,
/// nicht zwischen zwei Prüfungen durchrutscht.
Future<void> oeffneVerlaufSchrittweise(
  WidgetTester tester, {
  required void Function() pruefe,
}) async {
  await tester.tap(find.byKey(kVerlaufHuelleOeffnen));
  await tester.pump();
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (find.byType(GymVerlaufView).evaluate().isNotEmpty) pruefe();
  }
}

/// Ob ein Schlüssel im Baum steht.
bool steht(Key key) => find.byKey(key).evaluate().isNotEmpty;
