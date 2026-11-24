import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/cache.dart';
import 'package:repit/data/gym_training_repository.dart'
    show gymTrainingRepositoryProvider;
import 'package:repit/gym/gym_editor_provider.dart';
import 'package:repit/gym/gym_log_provider.dart' show gymIdProvider;
import 'package:repit/gym/gym_provider.dart';
import 'package:repit/gym/gym_training_editor_schluessel.dart';
import 'package:repit/gym/gym_trainings_provider.dart';
import 'package:repit/gym/gym_view.dart';
import 'package:repit/gym/uebungsbilder.dart';
import 'package:repit/gym/uebungsbilder_provider.dart';
import 'package:repit/health/health_provider.dart'
    show appCacheProvider, clockProvider;
import 'package:repit/shell/router.dart';

import '../data/gym_training_support.dart' show anzahl, neueDb, zeilen;
import 'gym_trainings_support.dart';
import 'support.dart' show heute, jetzt;

export 'package:repit/gym/gym_training_editor_schluessel.dart';

export '../data/gym_training_support.dart'
    show
        abbild,
        anzahl,
        eigenes,
        laufendesTraining,
        neueDb,
        oeffne,
        rotationInDatei,
        setzeRotation,
        uebung,
        ueber,
        uebungenInDatei,
        zeilen,
        zeilenVon,
        zweiUebungen;
export 'gym_trainings_support.dart';

/// Gemeinsame Hülle und Hilfen der Tests zum **Editor eigener Trainings**
/// (#534 unter #531, Tasks 3.3 und 3.5 des Plans
/// `docs/superpowers/plans/2026-11-19-eigene-trainings-plan.md`). Keine
/// Testdatei im engeren Sinn: Sie enthält Bauteile und keine Erwartung.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden. Hält der
/// Implementierende eine Erwartung für falsch, wird das **gemeldet, nicht
/// korrigiert**.
///
/// Grundlage: Spec `docs/superpowers/specs/2026-11-19-eigene-trainings-
/// design.md`, Abschnitte 9, 15 und die Nachträge 22 bis 26; Entwurf
/// `docs/screens/screens/gym-training-editor.js`.
///
/// ## Festlegungen des Test-Agenten — Tim hat sie nicht gesehen
///
/// Die Spec legt für den Editor nur die **Form** fest (9.2:
/// `GymEditorQuelle`, `GymEditorStand`, `gymEditorProvider` als
/// `NotifierProvider.autoDispose.family`) und die Schlüssel (9.7). **Die
/// Methoden des Notifiers nennt sie nicht**; die Tests brauchen sie und legen
/// sie hier fest. Der Implementierende benennt nichts davon um — hält er ein
/// Stück für falsch, meldet er es.
///
/// ```dart
/// // lib/gym/gym_editor_provider.dart
/// sealed class GymEditorQuelle {                       // ==, hashCode je Fall
///   const factory GymEditorQuelle.neu();
///   const factory GymEditorQuelle.bearbeite(String id);  // ein Eigenes
///   const factory GymEditorQuelle.kopie(String vonId);   // ein Template
///   const factory GymEditorQuelle.entwurf(String id);    // frei stehender Entwurf
/// }
///
/// class GymEditorNotifier extends Notifier<GymEditorStand> {
///   /// Fertig, sobald gelesen ist (`GymEditorStand.laedt` ist dann `false`).
///   Future<void> get bereit;
///
///   void setzeName(String name);                  // roh, wie getippt
///   void fuegeTagHinzu(String roh);               // über `WorkoutTags.add`
///   void entferneTag(String tag);                 // ohne Beachtung der Schreibweise
///   void setzeDauer(int minuten);                 // eigene Minuten
///   void dauerZuruecksetzen();                    // zurück zur Schätzung
///   void fuegeUebungHinzu(String uebungId);       // am Ende, aus dem Katalog vorbelegt
///   void entferneUebung(String uebungId);
///   /// [von] und [nach] sind Indizes ab 0; [nach] ist der Index **in der
///   /// Liste danach** („↑" ist `verschiebeUebung(i, i - 1)`).
///   void verschiebeUebung(int von, int nach);
///   void setzeUmfang(String uebungId, {int? saetze, int? wdhVon, int? wdhBis});
///
///   /// „Beim Schließen / beim Wechsel in den Hintergrund": schreibt einen
///   /// geänderten Stand sofort, nicht erst nach 1,5 Sekunden.
///   Future<void> schreibeSofort();
///   Future<GymEditorErgebnis> speichere();
///   /// „Als Entwurf behalten": sichert den geänderten Stand sofort.
///   Future<void> behalteAlsEntwurf();
///   /// „Verwerfen": löscht auch den gesicherten Stand.
///   Future<void> verwirf();
///   /// „Training löschen" — nur bei `bearbeite`. Gibt es nur dort.
///   Future<GymLoeschErgebnis> loesche();
/// }
///
/// enum GymEditorErgebnis {
///   gespeichert,      // fertig gespeichert, der Editor darf schließen
///   nichtSpeicherbar, // `probleme` nicht leer — nichts geschrieben
///   gesperrt,         // die Erfassung trägt das Training (Spec 4.7)
///   fehlgeschlagen,   // die Ablage hat geworfen — der Stand bleibt
/// }
/// ```
///
/// Dazu gelten:
///
/// - **Neue Kennungen kommen aus `gymIdProvider`** (`gym_log_provider.dart`):
///   genau **eine je Editor-Sitzung** — für den Entwurf bei `neu`/`kopie`
///   (die später die Kennung des Trainings wird), für den Zwischenstand bei
///   `bearbeite`. Tests überschreiben ihn mit einer festen Kennung.
/// - **Die Uhr** ist `clockProvider`; der Editor braucht keine.
/// - **Die Takt der Selbstsicherung ist 1,5 Sekunden** (Plan 5), als
///   Wartezeit nach der **letzten** Änderung; Tests schreiben sie als
///   Literal.
/// - **Der Übersichts-Stand ist nach jedem Schreiben des Editors aktuell**
///   (Spec 6.3: `ref.invalidate` beim Schreiber).
/// - **`probleme` ist `WorkoutRules.check` über den Stand als fertiges
///   Training** (`isDraft: false`) — der Speichern-Knopf hängt daran, und der
///   Satz „was fehlt" nennt daraus. Solange `laedt` gilt, ist `probleme`
///   leer: Aus nichts Gelesenem folgt kein Grund (Fehler `01`).
/// - **Eingaben während `laedt` werden nicht angenommen** — sie würden vom
///   gelesenen Stand überschrieben (so macht es `GymLogNotifier`).

/// Eine feste UTC-Uhr: alle Daten erfunden.
final editorJetzt = jetzt;

/// Ein Repository über der echten In-Memory-Datenbank — mit Haken für das,
/// was eine echte Platte nicht auf Befehl liefert, und Zählern für das
/// Schreiben.
class EditorRepo extends HakenRepo {
  EditorRepo(super.db);

  /// Lässt [speichere] scheitern.
  bool speichereScheitert = false;

  /// Wie oft **irgendein** Weg geschrieben hat, der den Editor-Stand ablegt:
  /// `speichere`, `speichereZwischenstand`, `uebernimmZwischenstand`.
  int schreibungen = 0;

  @override
  Future<WorkoutDefinition?> trainingAuchGeloescht(String id) async {
    await trainingTor?.future;
    return super.trainingAuchGeloescht(id);
  }

  @override
  Future<WorkoutDefinition?> zwischenstandVon(String trainingId) async {
    await trainingTor?.future;
    return super.zwischenstandVon(trainingId);
  }

  @override
  Future<void> speichere(WorkoutDefinition definition) async {
    if (speichereScheitert) {
      // Kein `StateError`: Das ist bei `speichere` die Sperre (Spec 4.7), und
      // der Editor unterscheidet die beiden.
      throw Exception('Die Platte ist voll (vom Test erzwungen)');
    }
    schreibungen++;
    await super.speichere(definition);
  }

  @override
  Future<void> speichereZwischenstand(
    WorkoutDefinition stand, {
    required String von,
  }) async {
    schreibungen++;
    await super.speichereZwischenstand(stand, von: von);
  }

  @override
  Future<void> uebernimmZwischenstand(String entwurfId) async {
    schreibungen++;
    await super.uebernimmZwischenstand(entwurfId);
  }
}

/// Die Kennung, die ein neuer Editor aus `gymIdProvider` zieht.
const neueKennung = 'NEU-1';

/* ---- Schlüssel-Festlegungen zu Nachtrag 29 (#561, #562) ----------------- */
//
// Festlegungen des Test-Agenten — die Zeichenketten sind der Vertrag; die
// Implementierung führt gleichnamige `kGymEditor…`-Konstanten in
// `gym_training_editor_schluessel.dart`. Die Dart-Namen hier weichen
// **bewusst** ab, damit nach dem Bau kein Namenskonflikt mit dem Export
// dieser Datei entsteht (derselbe Kniff wie `wahlBildSchluessel` in
// `gym_editor_auswahl_test.dart`).

/// „Speichern" oben rechts in der **Vorschau** (Nachtrag 29 Nr. 1) — erst
/// das fügt die Übung hinzu. Nur im Vorschau-Weg im Baum; der Zeilen-Weg
/// behält „Fertig" ([kGymEditorBlattFertig]).
const kBlattSpeichern = Key('gym-editor-blatt-speichern');

/// „Zurück" oben links im Blatt — in der Vorschau **verwirft** es, im
/// Zeilen-Weg behält es (Nachtrag 29 Nr. 1).
const kBlattZurueck = Key('gym-editor-blatt-zurueck');

/// Das „?" in der Kopfzeile „Umfang" (Nachtrag 29 Nr. 2) — auf **beiden**
/// Wegen ins Blatt.
const kBlattHilfe = Key('gym-editor-blatt-hilfe');

/// Das Hilfe-Modal hinter dem „?".
const kBlattHilfeModal = Key('gym-editor-blatt-hilfe-modal');

/// Schließt das Hilfe-Modal.
const kBlattHilfeSchliessen = Key('gym-editor-blatt-hilfe-schliessen');

/* ---- Container ohne Schirm -------------------------------------------- */

/// Ein Handle auf einen offenen Editor: hält ihn am Leben (ein
/// `autoDispose`-Provider ohne Hörer stürbe) und liest ihn.
class EditorHandle {
  EditorHandle(this.container, this.quelle)
    : _abo = container.listen(gymEditorProvider(quelle), (_, _) {});

  final ProviderContainer container;
  final GymEditorQuelle quelle;
  final ProviderSubscription<GymEditorStand> _abo;

  GymEditorNotifier get notifier =>
      container.read(gymEditorProvider(quelle).notifier);

  GymEditorStand get stand => container.read(gymEditorProvider(quelle));

  /// Wie das Schließen des Schirms: Der Editor verliert seinen letzten
  /// Hörer.
  void schliesse() => _abo.close();
}

typedef EditorBasis = ({
  ProviderContainer container,
  AppCache db,
  EditorRepo repo,
});

/// Container und Ablage ohne Schirm. `retry: (_, _) => null` nach
/// `CLAUDE.md`. [kennung] ist die Kennung, die ein neuer Editor zieht.
EditorBasis editorBasis({
  AppCache? db,
  EditorRepo? repo,
  String kennung = neueKennung,
}) {
  final datenbank = db ?? repo?.datenbank ?? neueDb();
  final haken = repo ?? EditorRepo(datenbank);
  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      appCacheProvider.overrideWithValue(datenbank),
      gymTrainingRepositoryProvider.overrideWithValue(haken),
      clockProvider.overrideWithValue(() => editorJetzt),
      gymIdProvider.overrideWithValue(() => kennung),
    ],
  );
  addTearDown(container.dispose);
  return (container: container, db: datenbank, repo: haken);
}

/// Öffnet einen Editor und wartet, bis er gelesen hat.
Future<EditorHandle> oeffneEditor(
  ProviderContainer container,
  GymEditorQuelle quelle,
) async {
  final h = EditorHandle(container, quelle);
  await h.notifier.bereit;
  return h;
}

/// Ein Test **ohne** Schirm, aber mit der Uhr des Widget-Tests: Das
/// Spulen der 1,5 Sekunden ist `tester.pump(Duration)`. **Immer sauber
/// abgebaut** — ein offener Zeitgeber lässt sonst jeden Test mit „A Timer is
/// still pending" enden, und die Aufräumhaken laufen erst danach.
void editorTest(String name, Future<void> Function(WidgetTester tester) body) =>
    testWidgets(name, (tester) async {
      try {
        await body(tester);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 2));
        await tester.pump();
      }
    });

/// Lässt die Selbstsicherung ablaufen: die 1,5 Sekunden nach der letzten
/// Änderung **und** das Schreiben danach.
Future<void> sicherungsTakt(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 1600));
  await tester.pump();
}

/// Die Zeilen von `gym_trainings`, die **kein Template** sind — das, was der
/// Editor hinterlässt.
Future<List<Map<String, Object?>>> eigeneZeilen(AppCache db) =>
    zeilen(db, 'gym_trainings', ordnung: 'id', wo: "kategorie = 'eigene'");

/// Die Zeile eines Trainings, `null` wenn es keine gibt.
Future<Map<String, Object?>?> zeileVon(AppCache db, String id) async {
  final z = await zeilen(db, 'gym_trainings', wo: "id = '$id'");
  return z.isEmpty ? null : z.single;
}

/// Wie viele Zwischenstände an [trainingId] hängen.
Future<int> zwischenstaendeAn(AppCache db, String trainingId) =>
    anzahl(db, 'gym_trainings', "entwurf_von = '$trainingId'");

/// Wärmt die Übersicht an und wartet auf ihre Quelle — damit ein Test
/// prüfen kann, ob der Editor sie **ungültig macht**: Ohne `invalidate`
/// bliebe der gehaltene Stand stehen.
Future<GymTrainingsStand> uebersicht(ProviderContainer container) async {
  await container.read(gymTrainingsQuelleProvider.future);
  return container.read(gymTrainingsProvider);
}

/// Eine Übung mit dem Vorgabewert aus dem Katalog.
WorkoutExercise ausKatalog(String id) =>
    WorkoutExercise.fromCatalog(ExerciseCatalog.all[id]!);

/* ---- Widget-Hülle ----------------------------------------------------- */

/// Wie `trainingsHuelle`, mit einer festen Kennung für neue Editoren
/// (`gymIdProvider`) und dem [EditorRepo]. Der Gym-Schirm ist die Wurzel
/// eines Navigators, der jeden Befehl des [AppRouter] schiebt — so erreichen
/// die Tests den Editor **ohne** einen Klassennamen oder Konstruktor zu
/// kennen: über die Zeile „Trainings", das „+", die Kachel, das „Bearbeiten".
///
/// [bilder] sind die Bewegungsbilder, die der Provider liefert (Spec 28
/// Nr. 2) — **ohne Angabe keine**: [Uebungsbilder.leer]. Der Editor liest den
/// Provider seit dem Einstellblatt mit Bild; ohne Override wirft er. Die
/// Bilddateien liefert ein [EditorBuendel], nie die echten RepDB-Bilder.
TrainingsHuelle editorHuelle({
  EditorRepo? repo,
  AppCache? db,
  String kennung = neueKennung,
  Uebungsbilder? bilder,
}) {
  final datenbank = db ?? repo?.datenbank ?? neueDb();
  final haken = repo ?? EditorRepo(datenbank);
  final router = AppRouter();
  final navigator = GlobalKey<NavigatorState>();
  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      appCacheProvider.overrideWithValue(datenbank),
      gymTrainingRepositoryProvider.overrideWithValue(haken),
      clockProvider.overrideWithValue(() => jetzt),
      gymIdProvider.overrideWithValue(() => kennung),
      gymTagProvider.overrideWithValue(gymTagAus(heute: heute)),
      uebungsbilderProvider.overrideWithValue(bilder ?? Uebungsbilder.leer),
    ],
  );
  addTearDown(container.dispose);

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
      child: DefaultAssetBundle(
        bundle: EditorBuendel(),
        child: CupertinoApp(
          navigatorKey: navigator,
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(padding: const EdgeInsets.only(top: 47, bottom: 34)),
              child: CupertinoPageScaffold(child: GymView(router: router)),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Liefert für jede Datei unter `assets/exercises/images/` ein 1×1-PNG — die
/// RepDB-Bilder werden nie gelesen (wie `_BuendelOhneRepdb` in
/// `gym_bewegungsbild_test.dart`). Alles andere kommt aus dem echten Bündel.
class EditorBuendel extends CachingAssetBundle {
  static final _png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA'
    '60e6kgAAAABJRU5ErkJggg==',
  );

  @override
  Future<ByteData> load(String key) async {
    if (key.startsWith('assets/exercises/images/')) {
      return ByteData.sublistView(Uint8List.fromList(_png));
    }
    return rootBundle.load(key);
  }
}

/// Erfundene Bewegungsbilder für [zwei] Übungen (Start und Umkehrpunkt) und
/// [einzel] (ein Bild, Halteübung) — über den echten Text-Weg
/// ([Uebungsbilder.parse]). Jede andere Übung des Katalogs hat **keines**.
/// Der Test bestimmt so, welche Übung ein Bild hat, statt es aus dem Asset
/// zu erraten.
Uebungsbilder editorBilder({
  List<String> zwei = const [],
  List<String> einzel = const [],
}) {
  final spalten = Uebungsbilder.erwarteteSpalten;
  final zeilen = <List<Object?>>[];
  final media = <String, Object?>{};
  void lege(String uid, Map<String, String> bilder) {
    final zeile = List<Object?>.filled(spalten.length, null);
    zeile[spalten.indexOf('id')] = 'repdb-$uid';
    zeile[spalten.indexOf('en')] = 'Erfundene Übung $uid';
    zeile[spalten.indexOf('images')] = bilder;
    zeilen.add(zeile);
    media[uid] = {'repdb': 'repdb-$uid', 'approximate': false, 'note': null};
  }

  for (final uid in zwei) {
    lege(uid, {'start': '$uid-1.webp', 'peak': '$uid-2.webp'});
  }
  for (final uid in einzel) {
    lege(uid, {'main': '$uid.webp'});
  }
  return Uebungsbilder.parse(
    jsonEncode({'fields': spalten, 'exercises': zeilen, 'media': media}),
  );
}

/// Öffnet die Übersicht und über das „+" den Editor, **neu**.
Future<void> oeffneNeuenEditor(WidgetTester tester, TrainingsHuelle h) async {
  await oeffneUebersicht(tester, h);
  await tippe(tester, find.byKey(kGymTrainingsPlus));
  expect(
    find.byKey(kGymEditor),
    findsOneWidget,
    reason: 'Das „+" der Übersicht öffnet den Editor (Spec 7.6)',
  );
}

/// Öffnet das Detail des Trainings [id] über die Übersicht.
Future<void> oeffneDetailVon(
  WidgetTester tester,
  TrainingsHuelle h,
  String id,
) async {
  await oeffneUebersicht(tester, h);
  await tippe(tester, find.byKey(kGymTrainingsName(id)), warnIfMissed: false);
  expect(find.byKey(kGymTrainingDetail), findsOneWidget);
}

/// Öffnet den Editor über „Bearbeiten" im Detail des Trainings [id]: ein
/// Template wird zur **Kopie**, ein Eigenes **bearbeitet**.
Future<void> oeffneBearbeiten(
  WidgetTester tester,
  TrainingsHuelle h,
  String id,
) async {
  await oeffneDetailVon(tester, h, id);
  await tippe(tester, find.byKey(kGymTrainingDetailBearbeiten));
  expect(
    find.byKey(kGymEditor),
    findsOneWidget,
    reason: '„Bearbeiten" im Detail öffnet den Editor (Spec 9, Plan 3.8)',
  );
}

/* ---- Bedienung --------------------------------------------------------- */

/// Das `EditableText` **im** Widget mit dem Schlüssel — oder das Widget
/// selbst.
Finder _eingabe(Key key) {
  final feld = find.byKey(key);
  return find.descendant(
    of: feld,
    matching: find.byType(EditableText),
    matchRoot: true,
  );
}

/// Tippt [text] in das Feld [key] und lässt **eine** Zehntelsekunde
/// vergehen — weniger als die 1,5 Sekunden der Selbstsicherung.
Future<void> gebeEin(WidgetTester tester, Key key, String text) async {
  expect(_eingabe(key), findsOneWidget, reason: '$key ist kein Textfeld');
  await tester.enterText(_eingabe(key), text);
  await tester.pump(const Duration(milliseconds: 100));
}

/// Was **im Feld steht**.
String feldInhalt(WidgetTester tester, Key key) =>
    tester.widget<EditableText>(_eingabe(key)).controller.text;

/// Scrollt die Auswahl, bis die Zeile [uid] gebaut und sichtbar ist.
///
/// Seit #551 (Spec 9.4, 9.9) ist die Liste **lazy**: Eine nicht gebaute
/// Zeile ist im Baum nicht zu finden — Tests scrollen zu ihr, statt sie
/// vorauszusetzen. Steht die Zeile schon da (alter Stand, kurze Liste),
/// scrollt die Hilfe nur bis zur Sichtbarkeit. Teil der Anpassung von
/// [waehleUebung] (Plan #551 Task 3.4, `TEST_AENDERN=1`, Tims Wort).
Future<void> zeigeWahlZeile(WidgetTester tester, String uid) async {
  await tester.scrollUntilVisible(
    find.byKey(kGymEditorWahlUebung(uid)),
    300,
    scrollable: find
        .descendant(
          of: find.byKey(kGymEditorWahl),
          matching: find.byWidgetPredicate(
            (w) => w is Scrollable && w.axis == Axis.vertical,
          ),
        )
        .first,
    maxScrolls: 400,
  );
  await tester.pump();
}

/// Fügt [uid] über „Übung hinzufügen" und die Auswahl hinzu — **und kehrt
/// zum Editor zurück**.
///
/// Seit Spec 28 Nr. 1 öffnet das Antippen das Einstellblatt, „Fertig" kehrt
/// zur Auswahl zurück, und die Auswahl schließt der Nutzer selbst. Der Weg
/// ist **zustandsbasiert**: Steht nach dem Antippen das Blatt da, folgt
/// „Fertig"; steht danach die Auswahl da, folgt „Zurück" ([kGymEditorWahlZurueck]).
/// So läuft dieselbe Hilfe gegen den Stand vor und nach der Umstellung — die
/// Fälle, die das Hinzufügen nur **brauchen**, bleiben unberührt; was Spec 28
/// verlangt, prüfen die eigenen Fälle (`tippeInAuswahl`).
///
/// Seit #551 scrollt die Hilfe zur Zeile ([zeigeWahlZeile]) — die Auswahl
/// listet die Bibliothek und baut lazy.
///
/// Seit Nachtrag 29 (#561) öffnet das Antippen eine **Vorschau**, und erst
/// „Speichern" fügt hinzu: Steht im Blatt [kBlattSpeichern], drückt die
/// Hilfe es; sonst (alter Stand) „Fertig". So bedeutet `waehleUebung`
/// weiter „fügt hinzu und kehrt zum Editor zurück", vor und nach dem Bau.
Future<void> waehleUebung(WidgetTester tester, String uid) async {
  await tippe(tester, find.byKey(kGymEditorHinzufuegen));
  expect(
    find.byKey(kGymEditorWahl),
    findsOneWidget,
    reason: '„Übung hinzufügen" öffnet die Auswahl (Spec 9.5)',
  );
  await zeigeWahlZeile(tester, uid);
  await tippe(tester, find.byKey(kGymEditorWahlUebung(uid)));
  if (find.byKey(kGymEditorBlatt).evaluate().isNotEmpty) {
    await tippe(
      tester,
      find.byKey(kBlattSpeichern).evaluate().isNotEmpty
          ? find.byKey(kBlattSpeichern)
          : find.byKey(kGymEditorBlattFertig),
    );
  }
  if (find.byKey(kGymEditorWahl).evaluate().isNotEmpty) {
    await tippe(tester, find.byKey(kGymEditorWahlZurueck));
  }
}

/// Öffnet die Auswahl (wenn sie nicht schon offen ist) und tippt [uid] an —
/// **ohne** danach etwas zu schließen: Der Test steht danach **im Blatt**
/// (seit Nachtrag 29 der **Vorschau** — hinzugefügt ist dann noch nichts,
/// erst [kBlattSpeichern] tut es). Bewusst ohne Speichern-Druck: Die
/// Bild-Fälle (Spec 28 Nr. 2) prüfen das offene Blatt; Hinzufügen samt
/// Rückkehr ist [waehleUebung].
Future<void> tippeInAuswahl(WidgetTester tester, String uid) async {
  if (find.byKey(kGymEditorWahl).evaluate().isEmpty) {
    await tippe(tester, find.byKey(kGymEditorHinzufuegen));
  }
  // Die Liste ist seit #551 lazy — ferne Zeilen stehen erst nach dem
  // Scrollen im Baum, dieselbe Bewegung wie in waehleUebung.
  await zeigeWahlZeile(tester, uid);
  await tippe(tester, find.byKey(kGymEditorWahlUebung(uid)));
}

/// Die Übungen im Baum, **von oben nach unten**.
///
/// Seit #551 über die **Bibliothek** (`ExerciseLibrary`), nicht den Katalog
/// der 33: Der Editor nimmt Bibliotheksübungen an, und eine Hilfe, die nur
/// Anker sieht, übersähe sie (Plan Task 3.4, `TEST_AENDERN=1`, Tims Wort).
List<String> uebungenImBaum(WidgetTester tester) {
  final gefunden = <(double, String)>[];
  for (final uid in ExerciseLibrary.all.keys) {
    final f = find.byKey(kGymEditorUebung(uid));
    if (f.evaluate().isEmpty) continue;
    gefunden.add((tester.getTopLeft(f).dy, uid));
  }
  gefunden.sort((a, b) => a.$1.compareTo(b.$1));
  return [for (final (_, uid) in gefunden) uid];
}

/// Alle sichtbaren Texte **unter** dem Schlüssel, geglättet; leer, wenn der
/// Schlüssel fehlt.
String textVonSchluessel(WidgetTester tester, Key key) =>
    find.byKey(key).evaluate().isEmpty ? '' : textUnter(tester, key);

/// Wonach ein **Grund** klingt: das, was dem Speichern fehlt. Solange
/// gelesen wird, darf davon nichts stehen (Fehler `01`).
final fehlendGrund = RegExp(
  r'mindestens|keine übung|noch keine|fehlt|name|sobald',
  caseSensitive: false,
);

/// Eine Rückfrage steht da, wenn ihr Schlüssel im Baum ist.
bool fragtZurueck(Key frage) => find.byKey(frage).evaluate().isNotEmpty;

/// Hält `training(id)` und alles, womit der Editor sein Training liest,
/// **an** — bis der Test [freigeben] ruft.
Completer<void> halteLesen(EditorRepo repo) =>
    repo.trainingTor = Completer<void>();
