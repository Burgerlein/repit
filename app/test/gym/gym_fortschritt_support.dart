import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/data/gym_repository.dart';
import 'package:repit/design/zeitdiagramm.dart';
import 'package:repit/gym/gym_fortschritt_view.dart';
import 'package:repit/health/health_provider.dart'
    show appCacheProvider, clockProvider;
import 'package:repit/shell/diagramm_zeitraum.dart';

import '../design/support.dart' show textOf;

/// Gemeinsame Hülle, Schlüssel und Fixturen der Tests zum Schirm
/// **„Fortschritt pro Übung"** (#93), `lib/gym/gym_fortschritt_view.dart`.
///
/// Grundlage ist `docs/superpowers/specs/2026-11-11-gym-fortschritt-design.md`
/// und der Entwurf `docs/screens/screens/gym-progress.js`. Geschrieben ohne
/// den späteren Schirm gesehen zu haben; die Hülle läuft allein über die
/// **Ablage** (`GymRepository`, `appCacheProvider`, `clockProvider`) und über
/// Schlüssel.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Dateien dürfen ausgeführt, aber nicht verändert werden.
///
/// ## Festgelegte öffentliche API
///
/// Entscheidung des Test-Agenten, nicht von Tim: Die Spec nennt Schirm und
/// Zustände und verlangt, Platzhalter „über ihren Schlüssel" zu prüfen, legt
/// die Namen aber nicht fest.
///
/// ```dart
/// // lib/gym/gym_fortschritt_view.dart
///
/// /// Öffnet den Schirm auf dem Stapel des **aktuell gewählten** Tabs
/// /// (`AppTarget.aktuell`), nie fest im Gym-Tab. [uebungId] stellt die
/// /// Auswahl vor; ohne sie gilt die erste Übung von Gym A.
/// void oeffneGymFortschritt(AppRouter router, {String? uebungId});
///
/// /// Der **ganze geschobene Schirm** — Gerüst und Navigationsleiste um
/// /// [GymFortschrittView].
/// class GymFortschrittSeite extends StatelessWidget {
///   const GymFortschrittSeite({super.key, String? uebungId});
/// }
///
/// /// Der Schirm selbst — ohne Gerüst, ohne Leiste, ohne Navigator. Er
/// /// besorgt seine Daten selbst und hält die Auswahl der Übung.
/// class GymFortschrittView extends ConsumerStatefulWidget {
///   const GymFortschrittView({super.key, String? uebungId});
/// }
/// ```
///
/// ```dart
/// // lib/gym/gym_fortschritt_provider.dart
///
/// /// Alles, was der Schirm zu **einer** Übung zeigt, einmal gerechnet.
/// /// Werttyp mit == und hashCode (Fehler 03).
/// class GymFortschritt {
///   final Exercise uebung;
///   final bool laedt;            // noch keine Antwort der Ablage
///   final bool fehlgeschlagen;   // das Lesen ist gescheitert
///   final List<ProgressPoint> reihe; // ExerciseProgress.points, roh, nicht verdichtet
///   final bool plateau;          // OneRepMax.isPlateau über die Trainings
///   final Suggestion? vorschlag; // null, solange nicht bekannt
///   bool get bekannt;            // !laedt && !fehlgeschlagen
/// }
///
/// /// Gehalten (Hausregel 2), ohne AsyncValue (Hausregel 1). Wirft
/// /// ArgumentError bei einer Übung, die der Katalog nicht kennt.
/// final gymFortschrittProvider = Provider.family<GymFortschritt, String>(...);
/// ```
///
/// ```dart
/// // lib/design/zeitdiagramm.dart — drei neue, **optionale** Parameter
/// // (ohne sie verhält sich das Bauteil wie bisher)
/// Zeitdiagramm(
///   ...,
///   ChartAggregation verdichtung = ChartAggregation.mean,
///   List<({DateTime tag, double wert})> zweiteReihe = const [],
///   // und die Startstufe, die der Schirm vorgibt statt `startStufe(stufen)`
/// );
///
/// // lib/shell/diagramm_zeitraum.dart
/// List<DiagrammPunkt> diagrammPunkte({
///   ...,
///   ChartAggregation verdichtung = ChartAggregation.mean,
/// });
/// ```
///
/// ### Schlüssel
///
/// | Schlüssel | Was |
/// |---|---|
/// | [kFAuswahl] | die Auswahlzeile „Übung"; trägt den Namen der gewählten Übung; Antippen öffnet ein Menü |
/// | `gym-fortschritt-auswahl-<id>` | ein Eintrag des Menüs, `<id>` ist `Exercise.id` — seit #551 (Nachtrag 17 Nr. 4) **nur Übungen mit Verlauf** und die gerade gewählte, siehe `gym_fortschritt_menue_test.dart` |
/// | [kFKachelHoechst], [kFKachel1rm] | die beiden Kennzahlen als Ganzes (Beschriftung und Wert) |
/// | [kFWertHoechst], [kFWert1rm] | der Wert darin: ein `Text`, oder beim Laden ein `Platzhalter` |
/// | [kFDiagramm] | der Platz der Diagrammkarte — **in jeder Lage da, an derselben Stelle** |
/// | [kFDiagrammLeer] | der Satz „noch zu wenige Trainings" **in** der Diagrammkarte — nur da, wo bekannt ist, dass es weniger als zwei Punkte gibt |
/// | [kFHinweis] | der Hinweiskasten — **in jeder Lage genau einer** |
/// | [kFPlateau] | **im** Hinweiskasten, nur bei erkanntem Plateau |
/// | [kFFehler] | **im** Hinweiskasten, nur wenn das Lesen gescheitert ist |
/// | [kFUnterstuetzung] | der Hinweis „keine 1RM-Schätzung bei Unterstützung" — nur bei Übungen mit `allowsAssist`, dann **auch** beim Laden |
/// | [kFZeituebung] | der Hinweis „Zeitübungen haben kein 1RM" — nur bei `Exercise.isTimed`, an der Stelle von [kFUnterstuetzung] |
/// | [kFFussnote] | die Fußnote zur Formel am Ende — in jeder Lage, derselbe Satz |
/// | [kFErneut] | **im** Hinweiskasten, nur wenn das Lesen gescheitert ist: „Erneut lesen" |
///
/// **Alle Zeitpunkte sind UTC und bezeichnen Berliner Tagesgrenzen**
/// (`CLAUDE.md`, #427); 2026-03 liegt vor der Sommerzeit (MEZ, +1). Alle
/// Daten sind erfunden und hängen an keinem Ereignis.

/* ---- Schlüssel ------------------------------------------------------- */

const kFAuswahl = Key('gym-fortschritt-auswahl');
const kFKachelHoechst = Key('gym-fortschritt-kachel-hoechstgewicht');
const kFKachel1rm = Key('gym-fortschritt-kachel-1rm');
const kFWertHoechst = Key('gym-fortschritt-kachel-hoechstgewicht-wert');
const kFWert1rm = Key('gym-fortschritt-kachel-1rm-wert');
const kFDiagramm = Key('gym-fortschritt-diagramm');
const kFDiagrammLeer = Key('gym-fortschritt-diagramm-leer');
const kFHinweis = Key('gym-fortschritt-hinweis');
const kFPlateau = Key('gym-fortschritt-plateau');
const kFFehler = Key('gym-fortschritt-fehler');
const kFUnterstuetzung = Key('gym-fortschritt-unterstuetzung');
const kFZeituebung = Key('gym-fortschritt-zeituebung');
const kFFussnote = Key('gym-fortschritt-fussnote');
const kFErneut = Key('gym-fortschritt-erneut');

/// Ein Eintrag im Menü der Auswahl.
Key kFWahl(String uebungId) => Key('gym-fortschritt-auswahl-$uebungId');

/// Die Abschnitte, die **in jeder Lage und für jede Übung** dastehen.
const kFPflichtAbschnitte = [
  kFAuswahl,
  kFKachelHoechst,
  kFKachel1rm,
  kFWertHoechst,
  kFWert1rm,
  kFDiagramm,
  kFHinweis,
  kFFussnote,
];

/* ---- Übungen und Tage ------------------------------------------------ */

const idBank = 'benchPress';
const idDips = 'dips';
const idSeitstuetz = 'sidePlank';
const idKlimmzug = 'pullUp';

/// Mittwoch 11.03.2026, 10:00 Berliner Zeit — **erfunden**.
final fJetzt = DateTime.utc(2026, 3, 11, 9);

/// 10:00 Berliner Zeit an einem Tag in 2026.
DateTime morgens(int monat, int tag, [int jahr = 2026]) =>
    DateTime.utc(jahr, monat, tag, 9);

/// Eine abgeschlossene Sitzung mit Sätzen als `(Gewicht, Wdh)`.
///
/// **Jede Sitzung braucht einen eigenen Tag oder ein eigenes Workout**, sonst
/// ersetzt die Ablage die vorige („ersetzen statt verdoppeln"). [id] ist
/// ohnehin eindeutig zu wählen.
ImportedSession sitzung(
  String id,
  DateTime datum,
  Map<String, List<(double, int)>> saetze, {
  Workout workout = Workout.a,
}) => ImportedSession(
  id: id,
  date: datum,
  workout: workout,
  minutes: 65,
  note: null,
  exercises: [
    for (final eintrag in saetze.entries)
      ImportedExercise(
        exerciseId: eintrag.key,
        sets: [
          for (final (gewicht, wdh) in eintrag.value)
            CompletedSet(weight: gewicht, reps: wdh),
        ],
      ),
  ],
);

/// Bankdrücken, ein Satz — der kürzeste Weg zu „ein Training".
ImportedSession bank(String id, DateTime datum, double kg, int wdh) =>
    sitzung(id, datum, {
      idBank: [(kg, wdh)],
    });

/* ---- Die Ablage mit Haken -------------------------------------------- */

/// Die echte Ablage über einer In-Memory-Datenbank — mit Haken für die Fälle,
/// die eine echte Platte nicht auf Befehl liefert.
///
/// **Beide Lesewege sind gehakt** ([saetzeDerUebung] und [sitzungen]): Welche
/// der beiden der Schirm benutzt, ist seine Sache — die Anforderung gilt für
/// beide. Geschrieben wird in den Tests über eine **eigene**, ungehakte
/// Ablage ([FortschrittHuelle.schreiber]).
class FortschrittAblage extends GymRepository {
  FortschrittAblage(super.db);

  /// Solange gesetzt und nicht erfüllt, kommt keine Antwort. Das ist der
  /// Moment „zwischen Öffnen und Eintreffen" — ohne dass ein Test wissen
  /// muss, wie der Schirm intern liest.
  Completer<void>? tor;

  /// Wenn gesetzt, scheitert jedes Lesen mit diesem Fehler.
  Object? fehler;

  /// Wie viele Lesevorgänge begonnen haben, über beide Wege.
  int lesungen = 0;

  Future<void> _vorLesen() async {
    lesungen++;
    await tor?.future;
    final f = fehler;
    if (f != null) throw f;
  }

  @override
  Future<List<GymSatzZeile>> saetzeDerUebung(
    String uebungId, {
    String? vonTag,
    String? bisTag,
  }) async {
    await _vorLesen();
    return super.saetzeDerUebung(uebungId, vonTag: vonTag, bisTag: bisTag);
  }

  @override
  Future<List<ImportedSession>> sitzungen({
    String? vonTag,
    String? bisTag,
  }) async {
    await _vorLesen();
    return super.sitzungen(vonTag: vonTag, bisTag: bisTag);
  }
}

/* ---- Hülle ----------------------------------------------------------- */

const kFHuelleOeffnen = Key('fortschritt-huelle-oeffnen');
const kFHuelleUebersicht = Key('fortschritt-huelle-uebersicht');

/// Alles, was ein Test braucht.
class FortschrittHuelle {
  FortschrittHuelle({
    required this.container,
    required this.db,
    required this.ablage,
    required this.schreiber,
    required this.app,
  });

  final ProviderContainer container;
  final AppCache db;

  /// Die gehakte Ablage, über die der Schirm liest.
  final FortschrittAblage ablage;

  /// Die ungehakte Ablage, über die der Test schreibt.
  final GymRepository schreiber;

  final Widget app;

  /// Legt abgeschlossene Sitzungen ab — eine nach der anderen.
  Future<void> lege(List<ImportedSession> sitzungen) async {
    for (final s in sitzungen) {
      await schreiber.legeAb(s);
    }
  }
}

/// Baut Datenbank, Ablage, Container und App. **Pumpt nichts.**
///
/// [mitStapel] stellt den Schirm **nicht** an die Wurzel, sondern hinter
/// einen Knopf ([kFHuelleOeffnen]) auf den Stapel eines von zwei Reitern —
/// so wie `RootView` ihn schiebt. Nur so ist „zurück und wieder hinein"
/// (Fehler `32`) prüfbar.
///
/// `retry: (_, _) => null` nach `CLAUDE.md`: In Tests ist Riverpods
/// Wiederholung abgeschaltet.
FortschrittHuelle fortschrittHuelle({
  String? uebungId,
  bool mitStapel = false,
}) {
  final db = AppCache(NativeDatabase.memory());
  addTearDown(db.close);
  final ablage = FortschrittAblage(db);
  final schreiber = GymRepository(db);

  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      appCacheProvider.overrideWithValue(db),
      gymRepositoryProvider.overrideWithValue(ablage),
      clockProvider.overrideWithValue(() => fJetzt),
    ],
  );
  addTearDown(container.dispose);

  Widget wurzel(BuildContext context) => mitStapel
      ? CupertinoTabScaffold(
          tabBar: CupertinoTabBar(
            items: const [
              BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.home),
                label: 'Eins',
              ),
              BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.list_bullet),
                label: 'Zwei',
              ),
            ],
          ),
          tabBuilder: (context, index) => CupertinoTabView(
            builder: (context) =>
                index == 0 ? _Uebersicht(uebungId: uebungId) : const SizedBox(),
          ),
        )
      : GymFortschrittSeite(uebungId: uebungId);

  final app = UncontrolledProviderScope(
    container: container,
    child: CupertinoApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(padding: const EdgeInsets.only(top: 47, bottom: 34)),
        child: child!,
      ),
      home: Builder(builder: wurzel),
    ),
  );

  return FortschrittHuelle(
    container: container,
    db: db,
    ablage: ablage,
    schreiber: schreiber,
    app: app,
  );
}

class _Uebersicht extends StatelessWidget {
  const _Uebersicht({this.uebungId});
  final String? uebungId;

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    child: SafeArea(
      child: Column(
        children: [
          const Text('Übersicht', key: kFHuelleUebersicht),
          CupertinoButton(
            key: kFHuelleOeffnen,
            onPressed: () => Navigator.of(context).push(
              CupertinoPageRoute<void>(
                builder: (_) => GymFortschrittSeite(uebungId: uebungId),
              ),
            ),
            child: const Text('Fortschritt'),
          ),
        ],
      ),
    ),
  );
}

/* ---- Bedienung ------------------------------------------------------- */

/// Pumpt die App auf einer Fläche, die hoch genug ist, dass alle Abschnitte
/// gebaut sind. Die Breite entspricht einem iPhone.
Future<void> starte(WidgetTester tester, FortschrittHuelle h) async {
  tester.view.physicalSize = const Size(402, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  // Erst leeren: Mehrere Hüllen in einem Test dürfen einander keinen Zustand
  // vererben (gewählte Übung, gewählte Stufe).
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(h.app);
  await tester.pump();
}

/// Lässt Seitenüberblendung und Antwort der Ablage ablaufen.
///
/// **Nicht `pumpAndSettle`:** Beim Laden steht eine Form, die nie fertig
/// wird, wenn ein Test die Ablage anhält.
Future<void> verstreiche(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
}

/// [starte] und [verstreiche] — der Schirm als Wurzel, Daten sind da.
Future<void> zeigeFortschritt(WidgetTester tester, FortschrittHuelle h) async {
  await starte(tester, h);
  await verstreiche(tester);
}

/// Öffnet den Schirm von der Übersicht aus (nur mit `mitStapel: true`).
Future<void> oeffneFortschritt(WidgetTester tester) async {
  await tester.tap(find.byKey(kFHuelleOeffnen));
  await verstreiche(tester);
}

/// Geht zurück wie der Zurück-Knopf der Navigationsleiste.
Future<void> zurueck(WidgetTester tester) async {
  Navigator.of(tester.element(find.byType(GymFortschrittSeite))).pop();
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

/// Wählt eine Übung über das Menü der Auswahlzeile.
Future<void> waehleUebung(WidgetTester tester, String uebungId) async {
  await tester.tap(find.byKey(kFAuswahl));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.ensureVisible(find.byKey(kFWahl(uebungId)));
  await tester.pump();
  await tester.tap(find.byKey(kFWahl(uebungId)));
  await verstreiche(tester);
}

/// Wählt eine Stufe der Zeitraumleiste — über ihre **Stelle** in der Leiste,
/// nicht über die Beschriftung.
Future<void> waehleStufe(WidgetTester tester, DiagrammStufe stufe) async {
  final index = leiste(tester).stufen.indexOf(stufe);
  expect(index, isNonNegative, reason: 'Die Leiste bietet $stufe an');
  await tester.tap(
    find
        .descendant(
          of: find.byType(Zeitraumleiste),
          matching: find.byType(Text),
        )
        .at(index),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

/* ---- Lesehilfen ------------------------------------------------------ */

/// Macht zerstückelte Texte vergleichbar.
String flach(String text) => text.replaceAll(RegExp(r'\s+'), ' ').trim();

/// Alle sichtbaren Texte an und unter [key], flach.
String textVon(WidgetTester tester, Key key) {
  final eigene = [
    for (final element in find.byKey(key).evaluate())
      if (element.widget is Text) textOf(element.widget as Text),
  ];
  final darunter = tester
      .widgetList<Text>(
        find.descendant(of: find.byKey(key), matching: find.byType(Text)),
      )
      .map(textOf);
  return flach([...eigene, ...darunter].join(' '));
}

/// Alle Texte im ganzen Baum, flach.
String allesText(WidgetTester tester) =>
    flach(tester.widgetList<Text>(find.byType(Text)).map(textOf).join(' '));

/// Der Wert einer Kachel als Text — leer, wenn dort ein `Platzhalter` steht.
String kachelWert(WidgetTester tester, Key wertKey) => textVon(tester, wertKey);

Zeitdiagramm diagramm(WidgetTester tester) =>
    tester.widget<Zeitdiagramm>(find.byType(Zeitdiagramm));

Zeitraumleiste leiste(WidgetTester tester) =>
    tester.widget<Zeitraumleiste>(find.byType(Zeitraumleiste));

/// Die Reihe eines Diagramms als `Tagesschlüssel → Wert`, in der Reihenfolge
/// der Reihe. Der Schlüssel ist der Berliner ISO-Tag (`CLAUDE.md`).
List<(String, double)> alsTage(List<({DateTime tag, double wert})> reihe) => [
  for (final p in reihe) (BerlinCalendar.dayKey(p.tag), p.wert),
];

/// Eine einzelne 0 als Wert — „0 kg", „0" —, nicht die Null in „30–45".
final nullAlsWert = RegExp(r'(^|[\s·])0([\s·%]|$)');
