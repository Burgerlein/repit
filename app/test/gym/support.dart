import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/gym/gym_provider.dart';
import 'package:repit/gym/gym_view.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/shell/router.dart';

import '../design/support.dart' show textOf;

/// Gemeinsame Hülle und Fixturen der Widget-Tests zum Gym-Übersichtsschirm
/// (#77). Die Erwartungen stehen in `gym_view_test.dart` und
/// `gym_view_leerzustaende_test.dart`; hier liegt nur, was beide brauchen.
///
/// Grundlage ist
/// `docs/superpowers/specs/2026-11-10-gym-fokus-karte-design.md`,
/// Abschnitt 13 („Was der Test-Agent prüft"). Vorbild für Schnitt und Stil
/// ist `test/shell/koerper_view_test.dart`.
///
/// ## Festgelegte öffentliche API (`lib/gym/gym_view.dart`)
///
/// ```dart
/// /// Der Wurzelschirm des Gym-Tabs — ohne Gerüst, ohne Leiste, ohne
/// /// Navigator. Die stellt `RootView` (Spec Abschnitt 3).
/// class GymView extends ConsumerWidget {
///   const GymView({super.key, required AppRouter router});
/// }
/// ```
///
/// **Er besorgt seine Daten selbst** (Spec Abschnitt 3): außer dem
/// [AppRouter] wird ihm nichts hereingereicht, den Tageszustand liest er
/// aus [gymTagProvider].
///
/// ## Die Schlüssel, unter denen die Abschnitte stehen
///
/// Entscheidung des Test-Agenten, nicht von Tim — die Spec nennt die fünf
/// Abschnitte (Abschnitt 3) und verlangt, den Platzhalter „über seinen
/// Schlüssel" zu prüfen (Abschnitt 13), legt die Namen aber nicht fest.
///
/// | Schlüssel | Was |
/// |---|---|
/// | [kLede] | der Lede unter der Überschrift „Gym" |
/// | [kKarte] | die Fokus-Karte als Ganzes |
/// | [kKapsel] | die Kapsel oben in der Karte |
/// | [kTitel] | der Titel der Karte |
/// | [kUntertitel] | der Untertitel, mit fester Zeilenzahl |
/// | [kFortschritt] | der Fortschrittsbalken — **nur** bei `InProgress` |
/// | [kAktionen] | die Knopfreihe der Karte |
/// | [kKartenFuss] | die Fußzeile der Karte, wo es eine gibt |
/// | [kWoche] | die Wochenleiste „Diese Woche" als Ganzes |
/// | `kPlatz(workout)` | eine der Kacheln der Rotation — seit der Umstellung auf die gespeicherte Rotation (Spec 23) **drei**: Push, Pull, Legs |
/// | [kWocheLeer] | der Satz der Leiste, wenn die Rotation leer ist — **nur** dann (Task 2.8) |
/// | [kAuswertung] | die Karte mit den vier Auswertungszeilen |
/// | [kZeileFortschritt] … [kZeilePlaene] | die vier Zeilen |
/// | [kHinweis] | der Hinweis am Fuß des Schirms — **entfallen** (Spec 26 Nr. 3); die Tests prüfen, dass er fehlt |
///
/// **Alle Zeitpunkte sind UTC und bezeichnen Berliner Tagesgrenzen**
/// (`CLAUDE.md`, #427). Alle Daten sind erfunden: Die Woche liegt im März
/// 2026 und hat mit keinem echten Termin etwas zu tun, und der OP-Tag ist
/// hier eine frei gewählte Zahl von Tagen vor [heute] — kein eingetragenes
/// Ereignis (`CLAUDE.md`, „Keine hartcodierten Ereignisse").

/// Montag, 09.03.2026, 10:00 Berliner Zeit (MEZ, +1).
final jetzt = DateTime.utc(2026, 3, 9, 9);

/// Der Berliner Tagesbeginn dazu — derselbe Wert, den
/// `heutigerTagProvider` aus [jetzt] macht.
final heute = BerlinCalendar.startOfDay(jetzt);

/* ---- Schlüssel ------------------------------------------------------- */

const kLede = Key('gym-lede');
const kKarte = Key('gym-fokus-karte');
const kKapsel = Key('gym-fokus-kapsel');
const kTitel = Key('gym-fokus-titel');
const kUntertitel = Key('gym-fokus-untertitel');
const kFortschritt = Key('gym-fokus-fortschritt');
const kAktionen = Key('gym-fokus-aktionen');
const kKartenFuss = Key('gym-fokus-fuss');
const kWoche = Key('gym-woche');
const kAuswertung = Key('gym-auswertung');
const kZeileFortschritt = Key('gym-auswertung-fortschritt');
const kZeileTrainings = Key('gym-auswertung-trainings');
const kZeileMuskeln = Key('gym-auswertung-muskeln');
const kZeilePlaene = Key('gym-auswertung-plaene');
const kHinweis = Key('gym-hinweis');

/// Der Satz in der Form der Wochenleiste, wenn die gespeicherte Rotation leer
/// ist (alle Templates gelöscht, Spec 24 Nr. 1). **Festlegung des
/// Test-Agenten**, siehe `gym_rotation_umstellung_test.dart`.
const kWocheLeer = Key('gym-woche-leer');

/// Die Rotation, die die Woche zum Start hat — Push, Pull, Legs (Spec 23).
/// **Nicht** `Workout.rotation`: Das wären Gym A bis D.
const rotationPpl = [Workout.push, Workout.pull, Workout.legs];

/// Die Kachel eines Workouts in der Wochenleiste — eine der drei der
/// Rotation (Push, Pull, Legs).
Key kPlatz(Workout workout) => Key('gym-woche-platz-${workout.code}');

/// Die vier Auswertungszeilen in der Reihenfolge aus Spec Abschnitt 7.
const auswertungsZeilen = [
  kZeileFortschritt,
  kZeileTrainings,
  kZeileMuskeln,
  kZeilePlaene,
];

/// Die Abschnitte, die **in jedem Zustand und in jeder Datenlage**
/// dastehen (Spec Abschnitt 3: „Keiner verschwindet, weil ein Wert
/// fehlt"). **Ohne den Hinweis am Fuß** ([kHinweis]): Er ist entfallen
/// (Spec 26 Nr. 3) und steht höchstens im Zustand `recovery` (ärztliche
/// Freigabe), nicht in jedem.
const pflichtAbschnitte = [
  kLede,
  kKarte,
  kKapsel,
  kTitel,
  kUntertitel,
  kAktionen,
  kWoche,
  kAuswertung,
  kZeileFortschritt,
  kZeileTrainings,
  kZeileMuskeln,
  kZeilePlaene,
];

/* ---- Fixturen -------------------------------------------------------- */

/// Der Wochenplan: Push montags, Pull mittwochs — Legs ohne festen Tag.
/// Erfunden, wie alles hier. Seit der Rotation-Umstellung (Task 2.8, Spec 23)
/// stehen Push, Pull und Legs in der Woche; ein Plan für Gym A bis D füllte
/// keinen Platz mehr. Legs bleibt ohne Tag, damit „ein Platz ohne festen Tag"
/// (`gym_view_test.dart`) weiter einen Fall hat.
const wochenplan = [
  PlannedGym(workout: Workout.push, weekday: DateTime.monday),
  PlannedGym(workout: Workout.pull, weekday: DateTime.wednesday),
];

/// Wie viele Übungen Push hat — aus dem Katalog, nie als Zahl getippt.
int get uebungenPush => ExerciseCatalog.exercisesFor(Workout.push).length;

/// `InProgress` — ein Training läuft, [erfasst] Übungen stehen schon drin.
GymTag tagLaeuft({int erfasst = 2}) => gymTagAus(
  heute: heute,
  plan: wochenplan,
  entwurf: GymDraft(
    workout: Workout.push,
    doneExercises: erfasst,
    totalExercises: uebungenPush,
  ),
);

/// `Planned` — heute (Montag) steht Push an.
GymTag tagGeplant({ImportedSession? zuletzt}) =>
    gymTagAus(heute: heute, plan: wochenplan, letzteSitzung: zuletzt);

/// `Rest` **mit** `next`: heute ist nichts geplant, Pull kommt am
/// Mittwoch.
GymTag tagRuheMitNaechstem() => gymTagAus(
  heute: heute,
  plan: const [
    PlannedGym(workout: Workout.pull, weekday: DateTime.wednesday),
    PlannedGym(workout: Workout.legs, weekday: DateTime.thursday),
  ],
);

/// `Rest` **ohne** alles — der ehrlich leere Stand aus Spec 9.1: kein
/// Plan, keine Trainings, kein Entwurf, kein OP-Termin.
GymTag tagRuheLeer({bool laedt = false}) =>
    gymTagAus(heute: heute, laedt: laedt);

/// `Rest` mit einem Nachzügler aus einer früheren Woche.
///
/// Legs statt Gym D (Task 2.8): Gym D ist nicht mehr in der Rotation und
/// würde vom Planer weggefiltert — ein Nachzügler muss einen Platz haben.
GymTag tagRuheMitNachzuegler() =>
    gymTagAus(heute: heute, nachzuholen: const [Workout.legs]);

/// `Recovery` — [tageNachOp] Kalendertage nach einer **erfundenen** OP.
///
/// Das Datum entsteht aus [heute] minus [tageNachOp] und steht nirgends
/// als Zahl im Testtext: Zwei verschiedene Werte müssen zwei verschiedene
/// Wiedereinstiegstermine auf dem Schirm ergeben, sonst ist irgendwo ein
/// Datum fest verdrahtet (Spec Abschnitt 13).
GymTag tagErholung({int tageNachOp = 9}) => gymTagAus(
  heute: heute,
  opTermin: BerlinCalendar.addDays(heute, -tageNachOp),
);

/// Die vier Zustände unter ihrem Namen aus der Spec, für Durchläufe über
/// alle Fälle.
Map<String, GymTag> alleVierZustaende() => {
  'inProgress': tagLaeuft(),
  'planned': tagGeplant(),
  'rest': tagRuheMitNaechstem(),
  'recovery': tagErholung(),
};

/* ---- Hülle ----------------------------------------------------------- */

typedef GymHuelle = ({
  ProviderContainer container,
  AppRouter router,
  Widget app,
});

/// Baut Container und App um [GymView] mit genau [tag] als Tageszustand.
///
/// `gymTagProvider` wird mit einem Wert überschrieben statt die
/// Quellprovider zu stellen: Die gibt es noch nicht (Spec 9.2), und der
/// Schirm interessiert sich ohnehin nur für den fertigen [GymTag].
/// `clockProvider` steht, damit `heutigerTagProvider` auf [heute] zeigt —
/// der Schirm braucht ihn für Wochentagsnamen.
///
/// `retry: (_, _) => null` nach `CLAUDE.md`: Riverpods Wiederholung ist in
/// Tests abgeschaltet.
GymHuelle gymHuelle(GymTag tag) {
  final router = AppRouter();
  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      clockProvider.overrideWithValue(() => jetzt),
      gymTagProvider.overrideWithValue(tag),
    ],
  );
  addTearDown(container.dispose);

  return (
    container: container,
    router: router,
    app: UncontrolledProviderScope(
      container: container,
      child: CupertinoApp(
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

/// Setzt einen anderen Tageszustand — für die Übergangstests.
///
/// Die Liste steht hier ein zweites Mal statt in einer Hilfsfunktion:
/// Riverpod 3 macht den Typ `Override` nicht öffentlich, eine gemeinsame
/// Funktion ließe sich also nicht annotieren.
void setze(GymHuelle h, GymTag tag) => h.container.updateOverrides([
  clockProvider.overrideWithValue(() => jetzt),
  gymTagProvider.overrideWithValue(tag),
]);

/// Pumpt die App auf einer Fläche, die hoch genug für alle fünf
/// Abschnitte ist. Die Breite entspricht einem iPhone: Der Schirm muss
/// dort stehen, nicht nur auf einer erfundenen Tafel.
Future<void> zeige(WidgetTester tester, Widget app) async {
  tester.view.physicalSize = const Size(402, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
}

/* ---- Lesehilfen ------------------------------------------------------ */

/// Alle sichtbaren Texte des Baums, durch Leerzeichen verbunden.
String alleTexte(WidgetTester tester) =>
    tester.widgetList<Text>(find.byType(Text)).map(textOf).join(' ');

/// Alle sichtbaren Texte unterhalb von [key], durch Leerzeichen verbunden.
String texteUnter(WidgetTester tester, Key key) => tester
    .widgetList<Text>(
      find.descendant(of: find.byKey(key), matching: find.byType(Text)),
    )
    .map(textOf)
    .join(' ');

/// `true`, wenn irgendein Vorfahre von [finder] ein `GestureDetector` mit
/// gesetztem `onTap` oder ein `CupertinoButton` mit gesetztem `onPressed`
/// ist — die beiden Wege, auf denen diese reine Cupertino-App etwas
/// antippbar macht. Derselbe Griff wie in `mehr_view_test.dart`.
bool istTippbar(WidgetTester tester, Finder finder) {
  bool nimmt(Widget w) =>
      (w is GestureDetector && w.onTap != null) ||
      (w is CupertinoButton && w.onPressed != null);

  // **Vorfahren und Nachfahren.** Bis zum 11.11.2026 sah diese Prüfung nur
  // nach oben — und übersah damit jede Zeile, die ihren Tipp-Auslöser
  // selbst mitbringt. `IconRow` tut genau das: Der `GestureDetector` liegt
  // **innerhalb** der Zeile, denn nur so erscheint der Chevron. Eine
  // verdrahtete Auswertungszeile galt dadurch als nicht tippbar, obwohl sie
  // es ist. `gym_verlauf_zugang_test.dart` hatte den Fehler schon von Hand
  // umgangen; hier ist er behoben. (TEST_AENDERN=1)
  //
  // Für die Gegenrichtung („ist **nicht** tippbar") bleibt die Aussage
  // dieselbe: Eine Zeile ohne Ziel hat weder innen noch außen einen
  // Auslöser.
  final umgebung = tester.widgetList(
    find.ancestor(of: finder, matching: find.byWidgetPredicate((_) => true)),
  );
  if (umgebung.any(nimmt)) return true;

  final innen = tester.widgetList(
    find.descendant(of: finder, matching: find.byWidgetPredicate((_) => true)),
  );
  return innen.any(nimmt);
}

/// Produkt aller `Opacity`-Vorfahren von [finder] — `1.0` ohne.
double opazitaet(WidgetTester tester, Finder finder) {
  final werte = tester.widgetList<Opacity>(
    find.ancestor(of: finder, matching: find.byType(Opacity)),
  );
  if (werte.isEmpty) return 1.0;
  return werte.map((o) => o.opacity).reduce((a, b) => a * b);
}

/// Die Knöpfe der Fokus-Karte.
Finder knoepfe() => find.descendant(
  of: find.byKey(kAktionen),
  matching: find.byType(CupertinoButton),
);

/// Macht mehrzeilige und zerstückelte Texte vergleichbar: Ob der Schirm
/// den Untertitel als ein `Text` mit `\n` oder als zwei `Text` baut, ist
/// eine Umsetzungsfrage und keine Anforderung.
String flach(String text) => text.replaceAll(RegExp(r'\s+'), ' ').trim();

/// Eine einzelne 0 als Wert — „0 kg", „0" —, nicht die Null in „30–45".
final nullAlsWert = RegExp(r'(^|[\s·])0([\s·%]|$)');

/// Wie `mehr_view.dart` eine Zeile ohne Ziel ankündigt. Der genaue
/// Wortlaut ist bewusst nicht festgenagelt (`CLAUDE.md`: Widget-Tests
/// prüfen keine Beschriftungen) — nur, dass es eine Ankündigung ist.
final ankuendigung = RegExp(
  r'noch nicht|bald|später|folgt',
  caseSensitive: false,
);
