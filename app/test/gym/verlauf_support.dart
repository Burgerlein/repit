import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/data/gym_repository.dart';
import 'package:repit/design/platzhalter.dart' show Platzhalter;
import 'package:repit/gym/gym_verlauf_view.dart';
import 'package:repit/health/health_provider.dart'
    show appCacheProvider, clockProvider;

import 'log_support.dart' show Ablage, Uhr, allesText, textVon;

/// Gemeinsame Hülle, Schlüssel und Fixturen der Widget-Tests zum Schirm
/// **„Letzte Trainings"** (#79), `lib/gym/gym_verlauf_view.dart`.
///
/// Grundlage ist `docs/superpowers/specs/2026-11-11-gym-verlauf-design.md`,
/// besonders die Abschnitte 4 (Datenkette), 6 (Leerzustände), 8 (Karten) und
/// 13 (Was der Test-Agent prüft). Geschrieben **ohne** den späteren Schirm
/// gesehen zu haben.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Dateien dürfen ausgeführt, aber nicht verändert werden.
///
/// ## Festgelegte öffentliche API
///
/// Entscheidung des Test-Agenten, nicht von Tim: Die Spec nennt den Schirm
/// und verlangt, Platzhalter „über ihren Schlüssel" zu prüfen, legt die
/// Namen aber nicht fest.
///
/// ```dart
/// /// Der **ganze geschobene Schirm** — mit Gerüst und Navigationsleiste
/// /// (Zurück, Titel „Letzte Trainings"). Er besorgt seine Daten selbst:
/// /// die Sitzungen aus `gymSitzungenProvider` (also über
/// /// `GymRepository.sitzungen`), den Berliner Tag aus `clockProvider`.
/// class GymVerlaufView extends ConsumerWidget {
///   const GymVerlaufView({super.key});
/// }
///
/// /// Die Tür dorthin, auf den Stapel des aktuellen Tabs.
/// void oeffneGymVerlauf(AppRouter router);
/// ```
///
/// ### Schlüssel
///
/// `<id>` ist `ImportedSession.id`, `<uid>` ist `Exercise.id`, `<n>` die
/// sichtbare Satznummer ab 1.
///
/// | Schlüssel | Was |
/// |---|---|
/// | `gym-verlauf-kennzahlen` | die Kachelreihe als Ganzes — **steht in jeder Datenlage** |
/// | `gym-verlauf-kachel-trainings` / `-volumen` | die beiden Kacheln als Ganzes, mit Beschriftung |
/// | `gym-verlauf-wert-trainings` / `-volumen` | der **Wertplatz** in der Kachel (nur die Zahl, ohne Beschriftung). Steht in jeder Datenlage: gefüllt, ungefüllt oder mit grauer Form |
/// | `gym-verlauf-karten-laedt` | die graue Kartenzeile — **nur** solange nichts bekannt ist |
/// | `gym-verlauf-leer` | der Hinweis „noch nichts da" — **nur**, wenn bekannt leer |
/// | `gym-verlauf-fehler` | der Hinweis „nicht lesbar" — **nur**, wenn das Lesen scheiterte und nichts bekannt ist |
/// | `gym-verlauf-hinweis` | der Hinweis am Fuß — **steht in jeder Datenlage** |
/// | `gym-verlauf-karte-<id>` | die ganze Aufklappkarte |
/// | `gym-verlauf-kopf-<id>` | die tippbare Kopfzeile (Titel und Kurzfassung) |
/// | `gym-verlauf-inhalt-<id>` | der Inhalt — **nur im Baum, solange die Karte offen ist** |
/// | `gym-verlauf-uebung-<id>-<uid>` | eine Übungszeile |
/// | `gym-verlauf-satz-<id>-<uid>-<n>` | eine Satz-Plakette |
/// | `gym-verlauf-aufwaermen-<id>` | die Aufwärmzeile in der offenen Karte |
/// | `gym-verlauf-notiz-<id>` | die Notiz — **nur**, wenn eine da ist |
/// | `gym-verlauf-band-<id>` | das Übungsband (Folgekarte, nicht dieser Schritt) |
///
/// Die Kartenschlüssel haben **bewusst keinen gemeinsamen Anfang
/// untereinander** (`karte-`, `kopf-`, `inhalt-`), damit sich die Karten
/// zählen lassen, ohne Kopf und Inhalt mitzuzählen.
///
/// ## Was die Hülle voraussetzt
///
/// Nur die drei Overrides unten. **Gelesen wird über die Ablage**
/// (`GymRepository.sitzungen`): Die Tore ([Ablage.verlaufTor]) halten das
/// Lesen an, [VerlaufAblage.lesenScheitert] lässt es scheitern,
/// [VerlaufAblage.lesevorgaenge] zählt es. So muss ein Test nicht wissen,
/// wie der Schirm intern liest.
///
/// **Alle Zeitpunkte sind UTC**, alle Daten erfunden. Heute ist Montag,
/// 09.03.2026, 10:00 Berliner Zeit.

/* ---- Zeit und Übungen ------------------------------------------------ */

/// Montag, 09.03.2026, 10:00 Berliner Zeit (MEZ, +1). Erfunden.
final verlaufJetzt = DateTime.utc(2026, 3, 9, 9);

/// Der Vormittag von „heute", [tage] Tage zurück — 08:00 Berliner Zeit, also
/// mitten im Berliner Tag und nirgends an einer Tagesgrenze.
DateTime vormittag(int tage) =>
    DateTime.utc(2026, 3, 9, 7).subtract(Duration(days: tage));

const idBank = 'benchPress';
const idDips = 'dips';
const idSeitstuetz = 'sidePlank';
const idSeitheben = 'lateralRaise';

/// Eine Übung, die der Katalog nicht kennt — erfunden.
const idUnbekannt = 'ghostLift';

/* ---- Fixturen -------------------------------------------------------- */

/// Eine Übung mit ihren Sätzen. [zeiten] ist, wenn gesetzt, **je Satz** die
/// Uhrzeit (`CompletedSet.recordedAt`), `null` heißt „nicht erfasst".
ImportedExercise uebung(
  String id,
  List<(double, int)> saetze, {
  List<DateTime?>? zeiten,
}) => ImportedExercise(
  exerciseId: id,
  sets: [
    for (var i = 0; i < saetze.length; i++)
      CompletedSet(
        weight: saetze[i].$1,
        reps: saetze[i].$2,
        recordedAt: zeiten?[i],
      ),
  ],
);

/// Zwei Sätze Bankdrücken: 60 × 10 und 62,5 × 8 — Volumen 600 + 500 = 1.100.
ImportedExercise bank({List<DateTime?>? zeiten}) =>
    uebung(idBank, [(60, 10), (62.5, 8)], zeiten: zeiten);

/// Eine Sitzung. Vorgabe: Gym A, 65 Minuten, ohne Notiz, ohne Aufwärmen,
/// mit [bank].
ImportedSession sitzung({
  required String id,
  required DateTime datum,
  Workout? workout = Workout.a,
  int? minuten = 65,
  String? notiz,
  WarmUp? aufwaermen,
  List<ImportedExercise>? uebungen,
}) => ImportedSession(
  id: id,
  date: datum,
  workout: workout,
  minutes: minuten,
  note: notiz,
  warmUp: aufwaermen,
  exercises: uebungen ?? [bank()],
);

/// [anzahl] Sitzungen an aufeinanderfolgenden Tagen, die jüngste heute:
/// `S-0` heute, `S-1` gestern …
List<ImportedSession> trainingsReihe(int anzahl) => [
  for (var i = 0; i < anzahl; i++) sitzung(id: 'S-$i', datum: vormittag(i)),
];

/* ---- Ablage ---------------------------------------------------------- */

/// Die Ablage aus `log_support.dart` (mit Tor) und dazu: ein Lesefehler auf
/// Befehl und ein Zähler.
class VerlaufAblage extends Ablage {
  VerlaufAblage(super.db);

  /// Lässt das Lesen der Sitzungen scheitern.
  bool lesenScheitert = false;

  /// Wie oft `sitzungen` aufgerufen wurde — auch die gescheiterten und die
  /// noch angehaltenen.
  int lesevorgaenge = 0;

  @override
  Future<List<ImportedSession>> sitzungen({
    String? vonTag,
    String? bisTag,
  }) async {
    lesevorgaenge++;
    await verlaufTor?.future;
    if (lesenScheitert) {
      throw StateError('Die Platte ist nicht lesbar (vom Test erzwungen)');
    }
    return super.sitzungen(vonTag: vonTag, bisTag: bisTag);
  }
}

/* ---- Hülle ----------------------------------------------------------- */

const kVerlaufHuelleOeffnen = Key('verlauf-huelle-oeffnen');
const kVerlaufHuelleDetail = Key('verlauf-huelle-detail');

/// Alles, was ein Test braucht.
class VerlaufHuelle {
  VerlaufHuelle({
    required this.container,
    required this.db,
    required this.ablage,
    required this.uhr,
    required this.app,
  });

  final ProviderContainer container;
  final AppCache db;
  final VerlaufAblage ablage;
  final Uhr uhr;
  final Widget app;

  /// Was in der Ablage steht — über eine **eigene** Ablage gelesen, die kein
  /// Tor kennt und nicht mitzählt.
  Future<List<ImportedSession>> sitzungen() => GymRepository(db).sitzungen();

  /// Legt Sitzungen ab, ohne die Tore zu berühren.
  Future<void> fuelle(Iterable<ImportedSession> sitzungen) async {
    for (final s in sitzungen) {
      await ablage.legeAb(s);
    }
  }
}

/// Baut Datenbank, Ablage, Uhr, Container und App. **Pumpt nichts.**
///
/// `retry: (_, _) => null` nach `CLAUDE.md`: In Tests ist Riverpods
/// Wiederholung abgeschaltet.
VerlaufHuelle verlaufHuelle() {
  final db = AppCache(NativeDatabase.memory());
  addTearDown(db.close);
  final ablage = VerlaufAblage(db);
  final uhr = Uhr(verlaufJetzt);

  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      appCacheProvider.overrideWithValue(db),
      gymRepositoryProvider.overrideWithValue(ablage),
      clockProvider.overrideWithValue(() => uhr.jetzt),
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

  return VerlaufHuelle(
    container: container,
    db: db,
    ablage: ablage,
    uhr: uhr,
    app: app,
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
void verlaufTest(
  String name,
  Future<void> Function(WidgetTester tester, VerlaufHuelle h) body,
) {
  testWidgets(name, (tester) async {
    final h = verlaufHuelle();
    try {
      await body(tester, h);
    } finally {
      await abbauen(tester, h);
    }
  });
}

/// Nimmt die App aus dem Baum, lässt ein angehaltenes Lesen laufen und
/// schließt den Container.
Future<void> abbauen(WidgetTester tester, VerlaufHuelle h) async {
  final tor = h.ablage.verlaufTor;
  if (tor != null && !tor.isCompleted) tor.complete();
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 2));
  await tester.pump();
  h.container.dispose();
}

/* ---- Bedienung ------------------------------------------------------- */

/// Pumpt die App auf einer Fläche, die hoch genug ist, dass **alle** Karten
/// gebaut sind — kein Fall muss selbst scrollen. Die Breite entspricht einem
/// iPhone.
Future<void> starteVerlauf(WidgetTester tester, VerlaufHuelle h) async {
  tester.view.physicalSize = const Size(402, 8000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(h.app);
  await tester.pump();
}

/// Öffnet den Schirm von der Übersicht aus.
///
/// **Nicht `pumpAndSettle`:** Solange ein Tor das Lesen hält, kann eine
/// Animation nie enden, und die Tests wollen genau diesen Zustand sehen.
Future<void> oeffneVerlauf(WidgetTester tester) async {
  await tester.tap(find.byKey(kVerlaufHuelleOeffnen));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

/// [starteVerlauf] und [oeffneVerlauf] in einem.
Future<void> zeigeVerlauf(WidgetTester tester, VerlaufHuelle h) async {
  await starteVerlauf(tester, h);
  await oeffneVerlauf(tester);
}

/// Lässt das angehaltene Lesen durch.
Future<void> gibFrei(WidgetTester tester, VerlaufHuelle h) async {
  final tor = h.ablage.verlaufTor;
  if (tor != null && !tor.isCompleted) tor.complete();
  await verstreiche(tester);
}

/// Lässt eine Überblendung und die Antwort der Ablage ablaufen.
Future<void> verstreiche(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

/// Verlässt den Schirm wie der Zurück-Knopf.
Future<void> verlasseVerlauf(WidgetTester tester) async {
  Navigator.of(tester.element(find.byType(GymVerlaufView))).pop();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));
}

/// Schiebt einen anderen Schirm über den Verlauf — ein Detailziel, wie es
/// später die Zeile einer Übung wäre.
Future<void> schiebeDetail(WidgetTester tester) async {
  Navigator.of(tester.element(find.byType(GymVerlaufView))).push(
    CupertinoPageRoute<void>(
      builder: (_) => const CupertinoPageScaffold(
        child: Center(child: Text('Detail', key: kVerlaufHuelleDetail)),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));
}

/// Geht vom Detail zurück, **in kleinen Schritten**, und ruft nach jedem
/// [pruefe] — damit ein Platzhalter, der nur für ein Bild aufblitzt, nicht
/// zwischen zwei Prüfungen durchrutscht.
Future<void> zurueckSchrittweise(
  WidgetTester tester, {
  required void Function() pruefe,
}) async {
  Navigator.of(tester.element(find.byKey(kVerlaufHuelleDetail))).pop();
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (find.byType(GymVerlaufView).evaluate().isNotEmpty) pruefe();
  }
}

/// Öffnet die Karte, falls sie zu ist.
Future<void> oeffneKarte(WidgetTester tester, String id) async {
  if (karteOffen(id)) return;
  await tester.tap(find.byKey(kVerlaufKopf(id)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// Schließt die Karte, falls sie offen ist.
Future<void> schliesseKarte(WidgetTester tester, String id) async {
  if (!karteOffen(id)) return;
  await tester.tap(find.byKey(kVerlaufKopf(id)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/* ---- Lesehilfen ------------------------------------------------------ */

/// Ob der Inhalt der Karte im Baum steht.
bool karteOffen(String id) =>
    find.byKey(kVerlaufInhalt(id)).evaluate().isNotEmpty;

/// Alle Karten — gezählt über den Kartenschlüssel allein.
Finder karten() => find.byWidgetPredicate((widget) {
  final key = widget.key;
  return key is ValueKey<String> && key.value.startsWith('gym-verlauf-karte-');
});

/// Die Ids der gebauten Karten, **von oben nach unten**.
List<String> kartenReihenfolge(WidgetTester tester) {
  final eintraege = <(double, String)>[];
  for (final element in karten().evaluate()) {
    final key = element.widget.key! as ValueKey<String>;
    final id = key.value.substring('gym-verlauf-karte-'.length);
    final oben = tester.getTopLeft(find.byKey(key)).dy;
    eintraege.add((oben, id));
  }
  eintraege.sort((a, b) => a.$1.compareTo(b.$1));
  return [for (final e in eintraege) e.$2];
}

/// Alle grauen Formen im ganzen Baum.
Finder platzhalter() => find.byType(Platzhalter);

/// Alle Texte an [key], flach — siehe `log_support.dart`.
String verlaufText(WidgetTester tester, Key key) => textVon(tester, key);

/// Alle Texte im ganzen Baum, flach.
String verlaufAllesText(WidgetTester tester) => allesText(tester);

/// `true`, wenn irgendeine Ziffer im Text steht.
final eineZiffer = RegExp(r'\d');

/// Eine Uhrzeit wie „10:30" — die ein Schirm ohne Satz-Uhrzeiten nirgends
/// zeigen darf.
final eineUhrzeit = RegExp(r'\d{1,2}:\d{2}');

/// Der Grund „noch nichts da" in irgendeiner Formulierung.
final nochNichtsDa = RegExp(r'noch\s+(keine|nichts)', caseSensitive: false);

/// Die erste Zahl im Text, mit Tausenderpunkt und Dezimalkomma gelesen.
double zahlAus(String text) {
  final treffer = RegExp(r'\d+(?:[.,]\d+)*').firstMatch(text);
  expect(treffer, isNotNull, reason: 'In „$text" steht keine Zahl');
  return double.parse(
    treffer!.group(0)!.replaceAll('.', '').replaceAll(',', '.'),
  );
}

/// Maße und Orte der Kennzahlen — für den Vergleich **derselben Anzeige mit
/// sich selbst** in verschiedenen Datenlagen („dieselbe Höhe, dieselbe
/// Breite, dieselbe Stelle").
///
/// Von den Wertplätzen zählen **Höhe und Oberkante**, nicht die Breite: Eine
/// Zahl ist je nach Wert unterschiedlich breit, und eine Kachel, die sich
/// nach ihr richtete, wäre genau der Sprung, den die Regel verhindert — die
/// Kacheln selbst bleiben deshalb in Maß und Ort gleich.
typedef Kennzahlenform = ({
  Size reihe,
  Offset reiheOrt,
  Size kachelTrainings,
  Offset kachelTrainingsOrt,
  Size kachelVolumen,
  Offset kachelVolumenOrt,
  double wertTrainingsHoehe,
  double wertTrainingsOben,
  double wertVolumenHoehe,
  double wertVolumenOben,
});

Kennzahlenform kennzahlenForm(WidgetTester tester) {
  Size gr(Key k) => tester.getSize(find.byKey(k));
  Offset ort(Key k) => tester.getTopLeft(find.byKey(k));
  return (
    reihe: gr(kVerlaufKennzahlen),
    reiheOrt: ort(kVerlaufKennzahlen),
    kachelTrainings: gr(kVerlaufKachelTrainings),
    kachelTrainingsOrt: ort(kVerlaufKachelTrainings),
    kachelVolumen: gr(kVerlaufKachelVolumen),
    kachelVolumenOrt: ort(kVerlaufKachelVolumen),
    wertTrainingsHoehe: gr(kVerlaufWertTrainings).height,
    wertTrainingsOben: ort(kVerlaufWertTrainings).dy,
    wertVolumenHoehe: gr(kVerlaufWertVolumen).height,
    wertVolumenOben: ort(kVerlaufWertVolumen).dy,
  );
}

/* ---- Schlüssel ------------------------------------------------------- */

const kVerlaufKennzahlen = Key('gym-verlauf-kennzahlen');
const kVerlaufKachelTrainings = Key('gym-verlauf-kachel-trainings');
const kVerlaufKachelVolumen = Key('gym-verlauf-kachel-volumen');
const kVerlaufWertTrainings = Key('gym-verlauf-wert-trainings');
const kVerlaufWertVolumen = Key('gym-verlauf-wert-volumen');
const kVerlaufKartenLaedt = Key('gym-verlauf-karten-laedt');
const kVerlaufLeer = Key('gym-verlauf-leer');
const kVerlaufFehler = Key('gym-verlauf-fehler');
const kVerlaufHinweis = Key('gym-verlauf-hinweis');

Key kVerlaufKarte(String id) => Key('gym-verlauf-karte-$id');
Key kVerlaufKopf(String id) => Key('gym-verlauf-kopf-$id');
Key kVerlaufInhalt(String id) => Key('gym-verlauf-inhalt-$id');
Key kVerlaufUebung(String id, String uid) => Key('gym-verlauf-uebung-$id-$uid');
Key kVerlaufSatz(String id, String uid, int n) =>
    Key('gym-verlauf-satz-$id-$uid-$n');
Key kVerlaufAufwaermen(String id) => Key('gym-verlauf-aufwaermen-$id');
Key kVerlaufNotiz(String id) => Key('gym-verlauf-notiz-$id');
Key kVerlaufBand(String id) => Key('gym-verlauf-band-$id');

/// Die Schlüssel, die **in jeder Datenlage** dastehen müssen.
const kVerlaufPflichtAbschnitte = [
  kVerlaufKennzahlen,
  kVerlaufKachelTrainings,
  kVerlaufKachelVolumen,
  kVerlaufWertTrainings,
  kVerlaufWertVolumen,
  kVerlaufHinweis,
];
