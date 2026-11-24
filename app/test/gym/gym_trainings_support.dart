import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/data/gym_training_repository.dart';
import 'package:repit/gym/gym_provider.dart';
import 'package:repit/gym/gym_trainings_provider.dart';
import 'package:repit/gym/gym_trainings_schluessel.dart';
import 'package:repit/gym/gym_view.dart';
import 'package:repit/health/health_provider.dart'
    show appCacheProvider, clockProvider;
import 'package:repit/shell/router.dart';

import '../data/gym_training_support.dart';
import 'support.dart' show heute, jetzt, kZeilePlaene;

export '../data/gym_training_support.dart'
    show
        eigenes,
        laufendesTraining,
        neueDb,
        oeffne,
        uebung,
        ueber,
        zweiUebungen;

export 'package:repit/gym/gym_trainings_schluessel.dart';

/// Gemeinsame Hülle, Fixturen und Lesehilfen der Widget-Tests zur
/// **Trainings-Übersicht**, zum **Trainings-Detail** und zur **Gym-Tab-Zeile
/// „Trainings"** (#533 unter #531, Tasks 2.2 bis 2.5 des Plans
/// `docs/superpowers/plans/2026-11-19-eigene-trainings-plan.md`).
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Dateien dürfen ausgeführt, aber nicht verändert werden. Hält der
/// Implementierende eine Erwartung für falsch, wird das **gemeldet, nicht
/// korrigiert**.
///
/// Grundlage: Spec `docs/superpowers/specs/2026-11-19-eigene-trainings-
/// design.md`, Abschnitte 7, 8, 11, 12 und die Nachträge 22 bis 25; Entwürfe
/// `docs/screens/screens/gym-trainings.js` und `gym-training-detail.js`.
///
/// ## Die Schlüssel
///
/// Die Schlüssel aus Spec 7.7 und 8.5 stehen **in einer Datei**,
/// `app/lib/gym/gym_trainings_schluessel.dart` (Plan 2.2: „die Datei legt der
/// Test-Agent an"); die Tests importieren sie von dort. **Der Implementierende
/// benennt keinen davon um.**
///
/// Dazu zwei Festlegungen zur **Lage** der Schlüssel, die die Spec offen
/// lässt — **Festlegung des Test-Agenten, Tim hat sie nicht gesehen:**
///
/// - Wo die Spec sagt „auch der `Semantics`-Knoten" (die Kachel), **trägt das
///   Widget mit dem Schlüssel selbst den Knoten**. Dasselbe gilt für die
///   Filterkapseln (`gym-trainings-chip-<tag>`: Vorlesetext „Gym, ausgewählt"
///   bzw. „Gym", Spec 7.8) und für die Figur (`gym-trainings-figur-<id>`).
/// - **Die Figur der Kachel ist die Fläche des Zugs.** Ihr Knoten oder ein
///   Knoten innerhalb der Kachel trägt die benutzerdefinierte Aktion „Figur
///   umdrehen" (Spec 7.5); ob sie am Knoten der Figur oder am der Kachel
///   hängt, ist offen und wird **nicht** geprüft — gesucht wird im ganzen
///   Teilbaum der Kachel ([semantikTexte], [semantikAktionen]).
///
/// ## Wie die Tests zur Übersicht kommen
///
/// Über die **Gym-Tab-Zeile** („Trainings", Schlüssel `gym-auswertung-
/// plaene`) und einen Gastgeber, der die Befehle des `AppRouter` auf einen
/// `Navigator` schiebt — wie `RootView` es für den Stapel eines Tabs tut.
/// Damit legen die Tests **weder Klassennamen noch Konstruktoren** der neuen
/// Schirme fest; sie sehen nur Schlüssel und den Befehl des Routers. Ein
/// Schirm, den der Router nicht erreicht, ist für sie nicht da.
///
/// ## Die Datenlage
///
/// Eine **echte In-Memory-Datenbank**: Beim Öffnen läuft die Startbefüllung
/// (Push, Pull, Legs und die Rotation, #532). [HakenRepo] sitzt darüber und
/// hält das Lesen an, wo ein Test den Ladezustand braucht — genau wie die
/// Provider-Tests. **Alle Namen, Tags, Zahlen und Zeitpunkte sind erfunden.**

/// Ein Repository über einer echten In-Memory-Datenbank, mit Haken für das,
/// was eine echte Platte nicht auf Befehl liefert.
class HakenRepo extends GymTrainingRepository {
  HakenRepo(AppCache db) : datenbank = db, super(db);

  final AppCache datenbank;

  /// Hält `alle()` an, bis der Test es erfüllt.
  Completer<void>? alleTor;

  /// Hält `training(id)` an, bis der Test es erfüllt.
  Completer<void>? trainingTor;

  /// Hält `rotation()` an, bis der Test es erfüllt.
  Completer<void>? rotationTor;

  bool alleScheitert = false;
  bool rotationScheitert = false;

  /// Ersetzt die Antwort von `rotation()`, wo ein Test einen Stand braucht,
  /// den die Ablage nicht erzeugen kann.
  List<String>? rotationErsatz;

  int alleAufrufe = 0;
  int rotationAufrufe = 0;

  @override
  Future<List<WorkoutDefinition>> alle({bool mitEntwuerfen = true}) async {
    alleAufrufe++;
    await alleTor?.future;
    if (alleScheitert) throw StateError('Die Platte ist voll (vom Test)');
    return super.alle(mitEntwuerfen: mitEntwuerfen);
  }

  @override
  Future<WorkoutDefinition?> training(String id) async {
    await trainingTor?.future;
    return super.training(id);
  }

  @override
  Future<List<String>> rotation() async {
    rotationAufrufe++;
    await rotationTor?.future;
    if (rotationScheitert) throw StateError('Die Platte ist voll (vom Test)');
    return rotationErsatz ?? super.rotation();
  }
}

typedef TrainingsHuelle = ({
  ProviderContainer container,
  AppCache db,
  HakenRepo repo,
  AppRouter router,
  GlobalKey<NavigatorState> navigator,
  List<AppRouterBefehl> befehle,
  Widget app,
});

/// Baut Container und App: der Gym-Schirm als Wurzel eines Navigators, der
/// jeden Befehl des [AppRouter] schiebt.
///
/// [gymTagProvider] ist mit einem festen Tag überschrieben — außer bei
/// [echterTag]: Dann läuft die echte Kette `gymRotationProvider` →
/// `gymTagProvider` über die Ablage (Tests der Rotation, Task 2.8). Sonst
/// interessiert sich nur die Gym-Zeile für die Trainings, nicht der
/// Tageszustand; alles, was die Trainings betrifft, läuft über die **echten**
/// Provider und die echte Ablage. `retry: (_, _) => null` nach `CLAUDE.md`.
TrainingsHuelle trainingsHuelle({
  AppCache? db,
  HakenRepo? repo,
  bool echterTag = false,
}) {
  final datenbank = db ?? repo?.datenbank ?? neueDb();
  final haken = repo ?? HakenRepo(datenbank);
  final router = AppRouter();
  final navigator = GlobalKey<NavigatorState>();
  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      appCacheProvider.overrideWithValue(datenbank),
      gymTrainingRepositoryProvider.overrideWithValue(haken),
      clockProvider.overrideWithValue(() => jetzt),
      if (!echterTag) gymTagProvider.overrideWithValue(gymTagAus(heute: heute)),
    ],
  );
  addTearDown(container.dispose);

  // Jeder Befehl, den der Router ausgibt, in der Reihenfolge — der Gastgeber
  // schiebt ihn und schreibt ihn mit.
  final befehle = <AppRouterBefehl>[];
  void schiebe() {
    final befehl = router.nimmBefehl();
    if (befehl == null) return;
    befehle.add(befehl);
    navigator.currentState!.push(
      CupertinoPageRoute<void>(builder: befehl.builder),
    );
  }

  router.addListener(schiebe);
  addTearDown(() => router.removeListener(schiebe));

  return (
    container: container,
    db: datenbank,
    repo: haken,
    router: router,
    navigator: navigator,
    befehle: befehle,
    app: UncontrolledProviderScope(
      container: container,
      child: CupertinoApp(
        navigatorKey: navigator,
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(padding: const EdgeInsets.only(top: 47, bottom: 34)),
            child: CupertinoPageScaffold(child: GymView(router: router)),
          ),
        ),
      ),
    ),
  );
}

/// Pumpt die App auf einer hohen Fläche (damit auch zehn Kacheln gebaut
/// stehen) in iPhone-Breite. [warte] `false`: nur in Zehntelschritten pumpen
/// — für Fälle, in denen etwas hängt und nichts zur Ruhe kommt.
Future<void> zeigeGym(
  WidgetTester tester,
  TrainingsHuelle h, {
  bool warte = true,
}) async {
  tester.view.physicalSize = const Size(402, 4200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(h.app);
  await ruhe(tester, warte: warte);
}

/// `pumpAndSettle` — oder, wo etwas hängt, eine Sekunde in Zehntelschritten.
Future<void> ruhe(WidgetTester tester, {bool warte = true}) async {
  if (warte) {
    await tester.pumpAndSettle();
    return;
  }
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Öffnet die Übersicht über die Zeile „Trainings" des Gym-Tabs.
Future<void> oeffneUebersicht(
  WidgetTester tester,
  TrainingsHuelle h, {
  bool warte = true,
}) async {
  await zeigeGym(tester, h, warte: warte);
  await tippe(tester, find.byKey(kZeilePlaene), warte: warte);
  expect(
    find.byKey(kGymTrainings),
    findsOneWidget,
    reason:
        'Die Zeile „Trainings" (`gym-auswertung-plaene`) führt auf die '
        'Übersicht (Spec 7.9)',
  );
}

/// Tippt auf [ziel] — nach `ensureVisible`.
Future<void> tippe(
  WidgetTester tester,
  Finder ziel, {
  bool warte = true,
  bool warnIfMissed = true,
}) async {
  expect(ziel, findsOneWidget, reason: 'Siehe „Die Schlüssel" im Kopf.');
  await tester.ensureVisible(ziel);
  await ruhe(tester, warte: warte);
  await tester.tap(ziel, warnIfMissed: warnIfMissed);
  await ruhe(tester, warte: warte);
}

/// Geht einen Schritt auf dem Navigator zurück.
Future<void> zurueck(WidgetTester tester, TrainingsHuelle h) async {
  h.navigator.currentState!.pop();
  await tester.pumpAndSettle();
}

/// Die Zeile „Trainings" der Gym-Tab-Zeile.
Finder gymZeile() => find.byKey(kZeilePlaene);

/* ---- Fixturen -------------------------------------------------------- */

/// Ein eigenes, fertiges Training — gespeichert.
Future<WorkoutDefinition> legeEigenes(
  HakenRepo repo,
  String id, {
  String name = 'Kurzhantel zuhause',
  List<String>? tags,
  List<WorkoutExercise>? exercises,
  int? enteredMinutes,
}) async {
  final definition = eigenes(
    id,
    name: name,
    tags: tags,
    exercises: exercises,
    enteredMinutes: enteredMinutes,
  );
  await repo.speichere(definition);
  return definition;
}

/// Ein gespeicherter Entwurf — mit Namen und Übungen, wenn nichts anderes
/// verlangt ist.
Future<WorkoutDefinition> legeEntwurf(
  HakenRepo repo,
  String id, {
  String name = 'Oberkörper kurz',
  List<String> tags = const [],
  List<WorkoutExercise>? exercises,
}) async {
  final definition = eigenes(
    id,
    name: name,
    tags: tags,
    exercises: exercises ?? [uebung('benchPress'), uebung('lateralRaise')],
    isDraft: true,
  );
  await repo.speichere(definition);
  return definition;
}

/// Ein eigenes Training, dessen **einzige** Übung der Katalog nicht kennt —
/// damit hat es keine Dauer (Spec 5.3: `null`) und keine Muskeln.
///
/// Gespeichert wird zuerst ein gültiges Training, danach wird die Übung in
/// der Datei auf eine unbekannte Kennung gesetzt — den Weg, auf dem eine
/// Katalogänderung so etwas erzeugt (Spec 6.2).
Future<void> legeTrainingOhneDauer(
  HakenRepo repo,
  String id, {
  String name = 'Altes Training',
}) async {
  await legeEigenes(
    repo,
    id,
    name: name,
    tags: const [],
    exercises: [uebung('benchPress')],
  );
  await repo.datenbank.customStatement(
    "UPDATE gym_training_uebungen SET uebung_id = 'ZZ-UNBEKANNT' "
    "WHERE training_id = '$id';",
  );
}

/// Liest die Trainings des Gym-Tabs neu — so, wie es ein Schreiber tut
/// (`ref.invalidate`, Spec 6.3).
void leseNeu(TrainingsHuelle h) {
  h.container.invalidate(gymTrainingsQuelleProvider);
  h.container.invalidate(gymRotationQuelleProvider);
}

/* ---- Lesehilfen ------------------------------------------------------ */

/// Alle sichtbaren Texte **in** dem Widget mit dem Schlüssel — es selbst
/// eingeschlossen: Sitzt der Schlüssel auf dem `Text`, ist es sein Text.
/// Durch Leerzeichen verbunden und auf einfache Leerzeichen gebracht.
String textUnter(WidgetTester tester, Key key) => tester
    .widgetList<Text>(
      find.descendant(
        of: find.byKey(key),
        matching: find.byType(Text),
        matchRoot: true,
      ),
    )
    .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
    .join(' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Ob das Widget mit dem Schlüssel einen Antipp-Auslöser hat — **es selbst,
/// darunter oder darüber**: ein `GestureDetector` mit `onTap` oder ein
/// `CupertinoButton` mit `onPressed`. (Die Hilfe `istTippbar` aus
/// `support.dart` übersieht einen Auslöser, der **auf** dem Schlüssel sitzt.)
bool hatAusloeser(WidgetTester tester, Finder ziel) {
  bool nimmt(Widget w) =>
      (w is GestureDetector && w.onTap != null) ||
      (w is CupertinoButton && w.onPressed != null);
  final darueber = tester.widgetList(
    find.ancestor(
      of: ziel,
      matching: find.byWidgetPredicate((_) => true),
      matchRoot: true,
    ),
  );
  if (darueber.any(nimmt)) return true;
  final darunter = tester.widgetList(
    find.descendant(
      of: ziel,
      matching: find.byWidgetPredicate((_) => true),
      matchRoot: true,
    ),
  );
  return darunter.any(nimmt);
}

/// Das Produkt aller `Opacity` über oder um das Widget — `1.0` ohne.
double deckkraft(WidgetTester tester, Finder ziel) {
  final werte = tester.widgetList<Opacity>(
    find.ancestor(of: ziel, matching: find.byType(Opacity), matchRoot: true),
  );
  if (werte.isEmpty) return 1.0;
  return werte.map((o) => o.opacity).reduce((a, b) => a * b);
}

/// Ob ein Bedienelement **ohne Wirkung** dasteht: abgeblendet oder ohne
/// Antipp-Auslöser. Beides zugleich ist die Zusage „steht da, tut nichts".
bool ohneWirkung(WidgetTester tester, Key key) =>
    deckkraft(tester, find.byKey(key)) < 1 ||
    !hatAusloeser(tester, find.byKey(key));

/// Alle sichtbaren Texte des Baums.
String alleTexteDes(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
    .join(' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Die Höhe des Widgets mit dem Schlüssel.
double hoehe(WidgetTester tester, Key key) =>
    tester.getSize(find.byKey(key)).height;

/// Die Daten **aller** Semantik-Knoten im Teilbaum um [ziel] — der Knoten des
/// Widgets selbst eingeschlossen. Setzt `tester.ensureSemantics()` voraus.
List<SemanticsData> semantikDaten(WidgetTester tester, Finder ziel) {
  final wurzel = tester.getSemantics(ziel);
  final liste = <SemanticsData>[];
  void besuche(SemanticsNode knoten) {
    liste.add(knoten.getSemanticsData());
    knoten.visitChildren((kind) {
      besuche(kind);
      return true;
    });
  }

  besuche(wurzel);
  return liste;
}

/// Alles, was ein Screenreader im Teilbaum um [ziel] liest — Beschriftungen,
/// Werte, Hinweise —, kleingeschrieben und durch Leerzeichen verbunden.
String semantikTexte(WidgetTester tester, Finder ziel) => semantikDaten(
  tester,
  ziel,
).map((d) => '${d.label} ${d.value} ${d.hint}').join(' ').toLowerCase();

/// Die Beschriftung des **einen** Knotens von [ziel] — für Kapseln und alles,
/// was selbst ein Knoten ist.
String semantikLabel(WidgetTester tester, Finder ziel) =>
    tester.getSemantics(ziel).label;

/// Die benutzerdefinierten Aktionen im Teilbaum um [ziel], mit dem Knoten,
/// an dem sie hängen.
List<({SemanticsNode knoten, CustomSemanticsAction aktion})> semantikAktionen(
  WidgetTester tester,
  Finder ziel,
) {
  final ergebnis = <({SemanticsNode knoten, CustomSemanticsAction aktion})>[];
  void besuche(SemanticsNode knoten) {
    for (final id
        in knoten.getSemanticsData().customSemanticsActionIds ?? <int>[]) {
      final aktion = CustomSemanticsAction.getAction(id);
      if (aktion != null) ergebnis.add((knoten: knoten, aktion: aktion));
    }
    knoten.visitChildren((kind) {
      besuche(kind);
      return true;
    });
  }

  besuche(tester.getSemantics(ziel));
  return ergebnis;
}

/// Führt die benutzerdefinierte Aktion aus, wie VoiceOver es täte.
Future<void> fuehreAus(
  WidgetTester tester,
  ({SemanticsNode knoten, CustomSemanticsAction aktion}) eintrag,
) async {
  // Über den Owner des Knotens, nicht über den der Wurzel: In Flutter 3.47
  // hängt der Semantik-Baum der Testfläche nicht am Root-Owner.
  eintrag.knoten.owner!.performAction(
    eintrag.knoten.id,
    SemanticsAction.customAction,
    CustomSemanticsAction.getIdentifier(eintrag.aktion),
  );
  await tester.pumpAndSettle();
}

/// Eine einzelne 0 als Wert — „0 min", „0" —, nicht die Null in „30–45".
final nullAlsWert = RegExp(r'(^|[\s·])0([\s·%]|$)');

/// Wonach eine **Zusage** klingt: ein Knopf, der nichts tut, darf sie nicht
/// tragen (Plan, Lücke 7).
final verspricht = RegExp(
  r'noch nicht|bald|später|folgt|demnächst|in kürze',
  caseSensitive: false,
);

/// Wonach eine Aussage über Tims Datenlage klingt. Solange gelesen wird,
/// darf nichts davon dastehen (Fehler `01`).
final keineBehauptung = RegExp(
  r'noch keine|kein template|keine templates|kein eigenes|'
  r'alle templates gelöscht|trägt diesen tag',
  caseSensitive: false,
);

/// Ein `testWidgets` mit eingeschalteter Semantik. Das Handle wird **im**
/// Test freigegeben: Ein `addTearDown` liefe erst nach der Prüfung des
/// Testrahmens, und die verlangt, dass kein Handle mehr offen ist.
void testSemantik(
  String beschreibung,
  Future<void> Function(WidgetTester tester) test,
) => testWidgets(beschreibung, (tester) async {
  final handle = tester.ensureSemantics();
  try {
    await test(tester);
  } finally {
    handle.dispose();
  }
});
