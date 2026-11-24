import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/data/gym_repository.dart';
import 'package:repit/gym/gym_log_view.dart';
import 'package:repit/health/health_provider.dart'
    show appCacheProvider, clockProvider;

import '../design/support.dart' show textOf;
import 'support.dart' show texteUnter, flach;

/// Gemeinsame Hülle, Schlüssel und Fixturen der Widget-Tests zum Schirm
/// **„Training eintragen"** (#78), `lib/gym/gym_log_view.dart`.
///
/// Grundlage ist
/// `docs/superpowers/specs/2026-11-10-gym-training-eintragen-design.md`,
/// Abschnitte 3 bis 5, 9, 14 und 17.3, und der Entwurf
/// `docs/screens/screens/gym-log.js`. Geschrieben **ohne** den späteren
/// Schirm gesehen zu haben; die Provider und Texte, die ein anderer Agent
/// parallel baut, fasst diese Datei bewusst nicht an — sie läuft allein über
/// die **Ablage** (`GymRepository`, `appCacheProvider`, `clockProvider`) und
/// über Schlüssel.
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
/// /// (Zurück, Vollbild-Knopf), wie ihn `AppRouter` auf den Stapel des
/// /// aktuellen Tabs schiebt. Er besorgt seine Daten selbst: Entwurf aus
/// /// `gymRepositoryProvider`, Verlauf ebenso, Uhr aus `clockProvider`.
/// class GymLogView extends ConsumerWidget {
///   const GymLogView({super.key, required Workout workout});
/// }
/// ```
///
/// ### Schlüssel — Erfassung
///
/// `<id>` ist `Exercise.id` (`benchPress`, `dips` …), `<n>` die **sichtbare
/// Satznummer, ab 1**. Alle Satzschlüssel gelten **in Erfassung und im
/// Vollbild gleich**; beide Schirme stehen nie zugleich im Baum (die
/// Erfassung ist unter dem Vollbild `Offstage`).
///
/// | Schlüssel | Was |
/// |---|---|
/// | `gym-log-fortschritt` | „9 / 23 Sätze" als Text und Balken; beim Laden graue Formen (`Platzhalter`) |
/// | `gym-log-gespeichert` | der Haken — **nur** da, wenn zwischengespeichert wurde |
/// | `gym-log-bilanz` | „6 Sätze · 2.410 kg Volumen"; beim Laden graue Form |
/// | `gym-log-hinweis` | was dem Nutzer gesagt werden muss (Ablegen gescheitert …) — **nur** da, wenn etwas zu sagen ist |
/// | `gym-log-fussnote` | die Fußnote am Ende |
/// | `gym-log-vollbild` | der Knopf oben rechts (Vollbild-Symbol) |
/// | `gym-eckdaten` | die zuklappbare Zeile „Heute · 70 min · Notiz"; Antippen klappt auf und zu |
/// | `gym-eckdaten-dauer` | Zahlenfeld, vorbelegt mit `workout.minutes`; nur aufgeklappt im Baum |
/// | `gym-eckdaten-notiz` | Freitextfeld; nur aufgeklappt im Baum |
/// | `gym-zwischenspeichern` | Textknopf in der Fußleiste |
/// | `gym-abschliessen` | „Training abschließen" in der Fußleiste |
/// | `gym-abbrechen` | „Training abbrechen" unter den Karten |
/// | `gym-verwerfen-frage` | die Rückfrage (Dialog) — nur da, wenn gefragt wird |
/// | `gym-verwerfen-bestaetigen` | „Training verwerfen" im Dialog |
/// | `gym-verwerfen-weiter` | „Weiter trainieren" im Dialog |
///
/// ### Schlüssel — Übungskarten und Sätze
///
/// | Schlüssel | Was |
/// |---|---|
/// | `gym-uebung-<id>` | die ganze Karte |
/// | `gym-uebung-kopf-<id>` | die Kopfzeile; Antippen klappt eine **erledigte** Übung zu und auf, bei einer unfertigen passiert nichts |
/// | `gym-uebung-zusammenfassung-<id>` | „60 kg × 10 · …" — **nur** im Baum, solange die Karte zugeklappt ist |
/// | `gym-vorschlag-<id>` | die Vorschlagszeile (feste Zeilenzahl); beim Laden des Verlaufs graue Form |
/// | `gym-umschalter-<id>` | „Zusatzgewicht \| Unterstützung" — **nur** bei `Exercise.allowsAssist` im Baum |
/// | `gym-umschalter-<id>-zusatz` / `-unterstuetzung` | die beiden Hälften |
/// | `gym-satz-gewicht-<id>-<n>` | Gewichtsfeld (enthält genau ein `EditableText`); bei Zeitübungen gesperrt (`readOnly`) oder nicht im Baum |
/// | `gym-satz-wdh-<id>-<n>` | Wiederholungs- bzw. Sekundenfeld |
/// | `gym-satz-platzhalter-gewicht-<id>-<n>` | der Platzhalter im leeren Gewichtsfeld (Text: Wert vom letzten Mal oder „–"); **nur** da, solange das Feld leer **und** der Verlauf bekannt ist |
/// | `gym-satz-platzhalter-wdh-<id>-<n>` | dasselbe fürs Wiederholungsfeld |
/// | `gym-satz-einheit-gewicht-<id>-<n>` | „kg" bzw. „kg U"; bei Zeitübungen **nicht im Baum** oder leer |
/// | `gym-satz-einheit-wdh-<id>-<n>` | „Wdh" bzw. „Sek." |
/// | `gym-satz-trend-<id>-<n>` | der Trendpfeil — **nur** da, wenn es einen gibt (der freigehaltene Platz trägt keinen Schlüssel) |
/// | `gym-satz-haken-<id>-<n>` | der Haken — nur bei einem Satz, der zählt |
/// | `gym-satz-entfernen-<id>-<n>` | das Minus — nur bei einem entfernbaren leeren Satz |
/// | `gym-satz-hinzu-<id>` | „+ Satz" |
///
/// ### Schlüssel — Aufwärmen
///
/// | Schlüssel | Was |
/// |---|---|
/// | `gym-aufwaermen` | die Karte als Ganzes, in allen drei Zuständen gleich hoch |
/// | `gym-aufwaermen-art` | die Auswahl der Art; Antippen öffnet ein Menü |
/// | `gym-aufwaermen-art-<code>` | ein Eintrag des Menüs, `<code>` ist `WarmUpKind.code` (`bike`, `mobility` …) |
/// | `gym-aufwaermen-minuten` | Zahlenfeld |
/// | `gym-aufwaermen-km` | Zahlenfeld Strecke — **nicht im Baum bei Mobility** |
/// | `gym-aufwaermen-ueberspringen` | **ein** Knopf: leer → übersprungen → (nochmal) wieder leer; im ausgefüllten Zustand wirkungslos |
///
/// ### Schlüssel — Pausenuhr
///
/// | Schlüssel | Was |
/// |---|---|
/// | `gym-pause` | die Pausenzeile — **genau eine** im ganzen Training, in der ersten unfertigen Übung |
/// | `gym-pause-start` | Start/Stopp |
/// | `gym-pause-zeit` | die Anzeige als `m:ss`; ohne laufende Pause die Zielzeit |
///
/// ### Schlüssel — Vollbild
///
/// | Schlüssel | Was |
/// |---|---|
/// | `gym-vollbild` | die Wurzel des Vollbilds, geschoben über `rootNavigator` |
/// | `gym-vollbild-schliessen` | das Kreuz (speichert den Zwischenstand und schließt) |
/// | `gym-vollbild-weiter` | „Nächste Übung" — **nicht** auf der letzten Übung |
/// | `gym-vollbild-abschliessen` | „Training abschließen" — **nur** auf der letzten Übung |
///
/// Im Vollbild gelten dieselben Schlüssel für Satzfelder, „+ Satz" und
/// Pausenzeile wie in der Erfassung.
///
/// ## Was die Hülle voraussetzt
///
/// Nur die drei Overrides unten. **Alles andere, was der Schirm braucht,
/// muss in Tests von selbst tatenlos sein** — vor allem die Mitteilung
/// „Pause vorbei" (Spec 7.3): Ihr Standard darf den Plugin-Kanal nicht
/// anfassen, sonst läuft `flutter test` nativ nicht.
///
/// **Alle Zeitpunkte sind UTC**, alle Daten erfunden.

/* ---- Zeit und Übungen ------------------------------------------------ */

/// Montag, 09.03.2026, 10:00 Berliner Zeit (MEZ, +1). Erfunden.
final startzeit = DateTime.utc(2026, 3, 9, 9);

const idBank = 'benchPress';
const idSchraeg = 'inclineDumbbellPress';
const idSchulter = 'shoulderPressDumbbell';
const idDips = 'dips';
const idSeitheben = 'lateralRaise';
const idTrizeps = 'overheadTriceps';
const idBizeps = 'bicepsCurl';
const idSeitstuetz = 'sidePlank';

/// Die Reihenfolge von Gym A aus dem Katalog — nie als Liste getippt.
List<Exercise> uebungenVon(Workout workout) =>
    ExerciseCatalog.exercisesFor(workout);

/// Wie viele Satzzeilen ein Workout zu Beginn hat: die Summe der Vorgaben.
int saetzeVon(Workout workout) =>
    uebungenVon(workout).fold(0, (summe, uebung) => summe + uebung.sets);

/// Eine **frühere** Sitzung für den Verlauf — eine Woche vor [startzeit], an
/// einem anderen Berliner Tag als jedes Training in diesen Tests, damit
/// „ersetzen statt verdoppeln" nie eingreift.
ImportedSession verlaufSitzung({
  String id = 'VERLAUF-1',
  DateTime? datum,
  Workout workout = Workout.a,
  required Map<String, List<(double, int)>> saetze,
}) => ImportedSession(
  id: id,
  date: datum ?? DateTime.utc(2026, 3, 2, 9),
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

/// Drei Sätze Bankdrücken vom letzten Mal — **weniger** als die vier Zeilen
/// von heute, damit Satz 4 keinen Wert vom letzten Mal hat.
Map<String, List<(double, int)>> bankVerlauf() => {
  idBank: [(60, 10), (62.5, 9), (62.5, 8)],
};

/* ---- Ablage und Uhr -------------------------------------------------- */

/// Eine Uhr, die der Test vorstellt. Der Schirm liest sie über
/// `clockProvider`.
class Uhr {
  Uhr(this.jetzt);
  DateTime jetzt;
}

/// Die echte Ablage (`GymRepository`) über einer In-Memory-Datenbank — mit
/// Haken für die Fälle, die eine echte Platte nicht auf Befehl liefert:
///
/// - [entwurfTor] und [verlaufTor] halten das Lesen an, bis der Test sie
///   erfüllt. Das ist der Moment „zwischen Öffnen und Eintreffen" aus Spec
///   9.3, ohne dass ein Test wissen muss, wie der Schirm intern liest.
/// - [ablegenScheitert] und [zwischenspeichernScheitert] lassen das
///   Schreiben scheitern.
/// - [entwurfSchreibungen] zählt, wie oft der Zwischenstand geschrieben
///   wurde — Spec 17.3 verlangt „genau ein Schreibvorgang".
///
/// **Gelesen wird in den Tests nie über diese Klasse**, sondern über
/// [LogHuelle.entwurf] und [LogHuelle.sitzungen]: Ein angehaltenes Tor
/// hielte sonst auch die Prüfung an.
class Ablage extends GymRepository {
  Ablage(super.db);

  Completer<void>? entwurfTor;
  Completer<void>? verlaufTor;
  bool ablegenScheitert = false;
  bool zwischenspeichernScheitert = false;
  int entwurfSchreibungen = 0;

  @override
  Future<GymEntwurf?> entwurf() async {
    await entwurfTor?.future;
    return super.entwurf();
  }

  @override
  Future<List<ImportedSession>> sitzungen({
    String? vonTag,
    String? bisTag,
  }) async {
    await verlaufTor?.future;
    return super.sitzungen(vonTag: vonTag, bisTag: bisTag);
  }

  @override
  Future<void> speichereEntwurf(GymEntwurf entwurf) async {
    if (zwischenspeichernScheitert) {
      throw StateError('Die Platte ist voll (vom Test erzwungen)');
    }
    entwurfSchreibungen++;
    await super.speichereEntwurf(entwurf);
  }

  @override
  Future<void> schliesseAb(ImportedSession sitzung) async {
    if (ablegenScheitert) {
      throw StateError('Die Platte ist voll (vom Test erzwungen)');
    }
    await super.schliesseAb(sitzung);
  }
}

/* ---- Hülle ----------------------------------------------------------- */

const kHuelleUebersicht = Key('huelle-uebersicht');
const kHuelleOeffnen = Key('huelle-oeffnen');

/// Alles, was ein Test braucht. **Veränderlich:** [neustart] ersetzt
/// [container] und [app], die Datenbank bleibt.
class LogHuelle {
  LogHuelle({
    required this.container,
    required this.db,
    required this.ablage,
    required this.uhr,
    required this.app,
    required this.workout,
  });

  ProviderContainer container;
  final AppCache db;
  final Ablage ablage;
  final Uhr uhr;
  Widget app;
  final Workout workout;

  /// Was in der Ablage steht — über eine **eigene** Ablage gelesen, die kein
  /// Tor kennt.
  Future<List<ImportedSession>> sitzungen() => GymRepository(db).sitzungen();

  Future<GymEntwurf?> entwurf() => GymRepository(db).entwurf();
}

/// Baut Datenbank, Ablage, Uhr, Container und App. **Pumpt nichts.**
///
/// `retry: (_, _) => null` nach `CLAUDE.md`: In Tests ist Riverpods
/// Wiederholung abgeschaltet.
LogHuelle logHuelle({Workout workout = Workout.a}) {
  final db = AppCache(NativeDatabase.memory());
  addTearDown(db.close);
  final ablage = Ablage(db);
  final uhr = Uhr(startzeit);
  final (container, app) = _baue(db, ablage, uhr, workout);
  return LogHuelle(
    container: container,
    db: db,
    ablage: ablage,
    uhr: uhr,
    app: app,
    workout: workout,
  );
}

(ProviderContainer, Widget) _baue(
  AppCache db,
  Ablage ablage,
  Uhr uhr,
  Workout workout,
) {
  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      appCacheProvider.overrideWithValue(db),
      gymRepositoryProvider.overrideWithValue(ablage),
      clockProvider.overrideWithValue(() => uhr.jetzt),
    ],
  );
  // Ein zweites Mal geschlossen schadet nicht (geprüft); der Test schließt
  // ihn selbst früher, damit kein Zeitgeber offen bleibt (siehe [abbauen]).
  addTearDown(container.dispose);

  // Zwei Reiter, jeder mit eigenem Stapel — wie `RootView`. Der Schirm wird
  // auf den Stapel des Reiters geschoben, das Vollbild über den
  // `rootNavigator`: Nur so ist die Zusage „kein zweiter Navigationsstapel,
  // über der Tableiste" überhaupt prüfbar.
  final app = UncontrolledProviderScope(
    container: container,
    child: CupertinoApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(padding: const EdgeInsets.only(top: 47, bottom: 34)),
        child: child!,
      ),
      home: CupertinoTabScaffold(
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
              index == 0 ? _Uebersicht(workout: workout) : const SizedBox(),
        ),
      ),
    ),
  );
  return (container, app);
}

class _Uebersicht extends StatelessWidget {
  const _Uebersicht({required this.workout});
  final Workout workout;

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    child: SafeArea(
      child: Column(
        children: [
          const Text('Übersicht', key: kHuelleUebersicht),
          CupertinoButton(
            key: kHuelleOeffnen,
            onPressed: () => Navigator.of(context).push(
              CupertinoPageRoute<void>(
                builder: (_) => GymLogView(workout: workout),
              ),
            ),
            child: const Text('Training'),
          ),
        ],
      ),
    ),
  );
}

/// Ein Test mit Hülle — und **immer** sauber abgebaut, auch wenn eine
/// Erwartung scheitert: Ein offener Zeitgeber (die 1,5 Sekunden des
/// Zwischenstands) lässt jeden Widget-Test mit „A Timer is still pending"
/// enden, und die Aufräumhaken laufen erst danach.
void logTest(
  String name,
  Future<void> Function(WidgetTester tester, LogHuelle h) body, {
  Workout workout = Workout.a,
}) {
  testWidgets(name, (tester) async {
    final h = logHuelle(workout: workout);
    try {
      await body(tester, h);
    } finally {
      await abbauen(tester, h);
    }
  });
}

/// Nimmt die App aus dem Baum, lässt offene Wartezeiten ablaufen und
/// schließt den Container.
Future<void> abbauen(WidgetTester tester, LogHuelle h) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 2));
  await tester.pump();
  h.container.dispose();
}

/// Ein Neustart der App über **derselben** Datenbank: Der Baum und der
/// Container sind weg, die Ablage bleibt. So wird geprüft, was wirklich auf
/// der Platte steht und nicht nur im Speicher.
///
/// Ein offener Zeitgeber geht dabei verloren, wie bei einer beendeten App —
/// die Tests warten deshalb vorher, bis geschrieben ist.
Future<void> neustart(WidgetTester tester, LogHuelle h) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  h.container.dispose();
  final (container, app) = _baue(h.db, h.ablage, h.uhr, h.workout);
  h.container = container;
  h.app = app;
  await tester.pumpWidget(app);
  await tester.pump();
}

/* ---- Bedienung ------------------------------------------------------- */

/// Pumpt die App auf einer Fläche, die hoch genug ist, dass **alle** Karten
/// gebaut sind — kein Fall muss selbst scrollen. Die Breite entspricht einem
/// iPhone.
Future<void> starte(WidgetTester tester, LogHuelle h) async {
  tester.view.physicalSize = const Size(402, 8000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(h.app);
  await tester.pump();
}

/// Öffnet den Schirm von der Übersicht aus.
///
/// **Nicht `pumpAndSettle`:** Ein Ladeanzeiger, der neben dem Haken kreist,
/// ließe es nie fertig werden. Die Sekunde lässt den Seitenwechsel enden
/// und die Ablage antworten; sie liegt unter den 1,5 s des Zwischenstands.
Future<void> oeffne(WidgetTester tester) async {
  await tester.tap(find.byKey(kHuelleOeffnen));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

/// [starte] und [oeffne] in einem.
Future<void> zeigeLog(WidgetTester tester, LogHuelle h) async {
  await starte(tester, h);
  await oeffne(tester);
}

/// Lässt eine Seitenüberblendung und die Antwort der Ablage ablaufen.
Future<void> verstreiche(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

/// Verlässt den Schirm wie der Zurück-Knopf und lässt die Überblendung
/// laufen — **kürzer als die 1,5 s des Zwischenstands**, damit ein Wert, der
/// danach in der Ablage steht, vom Verlassen kommt und nicht von der
/// Wartezeit.
Future<void> verlasse(WidgetTester tester) async {
  Navigator.of(tester.element(find.byType(GymLogView))).pop();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));
}

/// Tippt [text] in das Feld [key] — ohne dass Zeit vergeht. Der Zwischenstand
/// wartet 1,5 Sekunden, und Tests, die das prüfen, steuern die Zeit selbst.
Future<void> tippe(WidgetTester tester, Key key, String text) async {
  await tester.enterText(find.byKey(key), text);
  await tester.pump();
}

/// Trägt einen Satz ein. Leere Angaben lassen das Feld, wie es ist.
Future<void> satz(
  WidgetTester tester,
  String id,
  int n, {
  String? gewicht,
  String? wdh,
}) async {
  if (gewicht != null) await tippe(tester, kFeldGewicht(id, n), gewicht);
  if (wdh != null) await tippe(tester, kFeldWdh(id, n), wdh);
}

/// Was **im Feld steht**, nicht was als Platzhalter dahinter liegt.
String feldText(WidgetTester tester, Key key) {
  final feld = find.byKey(key);
  final editierbar = feld.evaluate().single.widget is EditableText
      ? feld
      : find.descendant(of: feld, matching: find.byType(EditableText));
  return tester.widget<EditableText>(editierbar).controller.text;
}

/// Alle Texte an [key] — auch wenn der Schlüssel selbst an einem `Text`
/// sitzt —, flach.
String textVon(WidgetTester tester, Key key) {
  final eigene = [
    for (final element in find.byKey(key).evaluate())
      if (element.widget is Text) textOf(element.widget as Text),
  ];
  return flach([...eigene, texteUnter(tester, key)].join(' '));
}

/// Alle Texte im ganzen Baum, flach.
String allesText(WidgetTester tester) =>
    flach(tester.widgetList<Text>(find.byType(Text)).map(textOf).join(' '));

/// `(fertig, gesamt)` aus „9 / 23 Sätze".
({int fertig, int gesamt}) fortschritt(WidgetTester tester) {
  final treffer = RegExp(r'(\d+)\s*/\s*(\d+)')
      .firstMatch(textVon(tester, kFortschritt));
  expect(
    treffer,
    isNotNull,
    reason: 'Der Fortschritt nennt „n / m" — sonst steht er nicht da',
  );
  return (
    fertig: int.parse(treffer!.group(1)!),
    gesamt: int.parse(treffer.group(2)!),
  );
}

/// Die Zahlen der Bilanz: erst die Sätze, dann das Volumen in kg. Die
/// Tausenderpunkte („2.410") und das Dezimalkomma werden gelesen.
({int saetze, double volumen}) bilanzZahlen(WidgetTester tester) {
  final zahlen = RegExp(r'\d+(?:[.,]\d+)*')
      .allMatches(textVon(tester, kBilanz))
      .map((m) => m.group(0)!)
      .toList();
  expect(zahlen, hasLength(2), reason: 'Die Bilanz nennt Sätze und Volumen');
  double lies(String s) =>
      double.parse(s.replaceAll('.', '').replaceAll(',', '.'));
  return (saetze: lies(zahlen[0]).round(), volumen: lies(zahlen[1]));
}

/// Die Sekunden der Pausenanzeige aus „2:30".
int pauseSekunden(WidgetTester tester) {
  final treffer = RegExp(r'(\d+):(\d{2})')
      .firstMatch(textVon(tester, kPauseZeit));
  expect(treffer, isNotNull, reason: 'Die Pausenanzeige steht als „m:ss"');
  return int.parse(treffer!.group(1)!) * 60 + int.parse(treffer.group(2)!);
}

/// Alle Trendpfeile im Baum.
Finder trendPfeile() => find.byWidgetPredicate((widget) {
  final key = widget.key;
  return key is ValueKey<String> && key.value.startsWith('gym-satz-trend-');
});

/// Alle Platzhalter in Gewichts- und Wiederholungsfeldern.
Finder satzPlatzhalter() => find.byWidgetPredicate((widget) {
  final key = widget.key;
  return key is ValueKey<String> &&
      key.value.startsWith('gym-satz-platzhalter-');
});

/// Der Strich, der „kein Wert vom letzten Mal" heißt — nie eine Zahl.
final strich = RegExp(r'^[–-]$');

/// Wie oft [muster] im Text steht.
int vorkommen(String text, String muster) => muster.allMatches(text).length;

/* ---- Schlüssel ------------------------------------------------------- */

const kFortschritt = Key('gym-log-fortschritt');
const kGespeichert = Key('gym-log-gespeichert');
const kBilanz = Key('gym-log-bilanz');
const kHinweis = Key('gym-log-hinweis');
const kFussnote = Key('gym-log-fussnote');
const kVollbildOeffnen = Key('gym-log-vollbild');
const kEckdaten = Key('gym-eckdaten');
const kEckdatenDauer = Key('gym-eckdaten-dauer');
const kEckdatenNotiz = Key('gym-eckdaten-notiz');
const kZwischenspeichern = Key('gym-zwischenspeichern');
const kAbschliessen = Key('gym-abschliessen');
const kAbbrechen = Key('gym-abbrechen');
const kVerwerfenFrage = Key('gym-verwerfen-frage');
const kVerwerfenBestaetigen = Key('gym-verwerfen-bestaetigen');
const kVerwerfenWeiter = Key('gym-verwerfen-weiter');

Key kUebung(String id) => Key('gym-uebung-$id');
Key kUebungKopf(String id) => Key('gym-uebung-kopf-$id');
Key kZusammenfassung(String id) => Key('gym-uebung-zusammenfassung-$id');
Key kVorschlag(String id) => Key('gym-vorschlag-$id');
Key kUmschalter(String id) => Key('gym-umschalter-$id');
Key kUmschalterZusatz(String id) => Key('gym-umschalter-$id-zusatz');
Key kUmschalterUnterstuetzung(String id) =>
    Key('gym-umschalter-$id-unterstuetzung');
Key kFeldGewicht(String id, int n) => Key('gym-satz-gewicht-$id-$n');
Key kFeldWdh(String id, int n) => Key('gym-satz-wdh-$id-$n');
Key kPlatzhalterGewicht(String id, int n) =>
    Key('gym-satz-platzhalter-gewicht-$id-$n');
Key kPlatzhalterWdh(String id, int n) => Key('gym-satz-platzhalter-wdh-$id-$n');
Key kEinheitGewicht(String id, int n) => Key('gym-satz-einheit-gewicht-$id-$n');
Key kEinheitWdh(String id, int n) => Key('gym-satz-einheit-wdh-$id-$n');
Key kTrend(String id, int n) => Key('gym-satz-trend-$id-$n');
Key kHaken(String id, int n) => Key('gym-satz-haken-$id-$n');
Key kMinus(String id, int n) => Key('gym-satz-entfernen-$id-$n');
Key kSatzHinzu(String id) => Key('gym-satz-hinzu-$id');

const kAufwaermen = Key('gym-aufwaermen');
const kAufwaermenArt = Key('gym-aufwaermen-art');
const kAufwaermenMinuten = Key('gym-aufwaermen-minuten');
const kAufwaermenKm = Key('gym-aufwaermen-km');
const kAufwaermenUeberspringen = Key('gym-aufwaermen-ueberspringen');
Key kAufwaermenArtWahl(WarmUpKind art) => Key('gym-aufwaermen-art-${art.code}');

const kPause = Key('gym-pause');
const kPauseStart = Key('gym-pause-start');
const kPauseZeit = Key('gym-pause-zeit');

const kVollbild = Key('gym-vollbild');
const kVollbildSchliessen = Key('gym-vollbild-schliessen');
const kVollbildWeiter = Key('gym-vollbild-weiter');
const kVollbildAbschliessen = Key('gym-vollbild-abschliessen');

/// Wählt die Art des Aufwärmens über das Menü.
Future<void> waehleArt(WidgetTester tester, WarmUpKind art) async {
  await tester.tap(find.byKey(kAufwaermenArt));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.tap(find.byKey(kAufwaermenArtWahl(art)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// Öffnet das Vollbild über den Knopf oben rechts.
Future<void> oeffneVollbild(WidgetTester tester) async {
  await tester.tap(find.byKey(kVollbildOeffnen));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

/// Nimmt dem Training die Frische, indem das Aufwärmen übersprungen wird —
/// danach öffnet [oeffneVollbild] bei der ersten offenen **Übung** statt auf
/// der Aufwärm-Seite.
///
/// Seit dem 11.11.2026 geht das Vollbild bei einem frischen Training auf der
/// Aufwärm-Seite auf (Tims Entscheidung: „bau cardio auch im fullscreen mode
/// ein, dass man das auch auswählen kann" — liegt es eine Wischgeste links
/// vom Sichtbaren, kann man es dort nicht auswählen). Tests, die von Übung 1
/// handeln und das Aufwärmen nur nicht im Weg haben wollen, rufen das hier
/// davor auf. **Übersprungen ist eine Antwort**, deshalb ist das Training
/// danach nicht mehr frisch. (TEST_AENDERN=1)
Future<void> ueberspringeAufwaermen(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(kAufwaermenUeberspringen));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(kAufwaermenUeberspringen));
  await tester.pump();
}
