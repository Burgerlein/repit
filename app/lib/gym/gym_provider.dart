// Der Zustand des Gym-Übersichtsschirms (#77) — alles, was der Schirm
// zeigt, einmal gerechnet und ohne Widget prüfbar. Die Oberfläche kommt
// als eigener Schritt; hier stehen nur Werttyp und Provider.
//
// **Kein `Messwert<GymDay>.** `Messwert<T>` gilt nach `CLAUDE.md` „nur für
// Abgeleitetes aus Apple Health. Für Tims eigene Daten — Gym-Trainings,
// Umfänge, Tagestausch, Entwürfe — gibt es keinen Lauf, der leer ausgehen
// kann. Dort heißt leer schlicht leer." Dieser Schirm liest ausschließlich
// Tims eigene Daten: Plan, Trainings, Entwurf, OP-Termin. Es gibt keine
// HealthKit-Abfrage, die „keine Daten" von „nicht erlaubt" nicht
// unterscheiden könnte, also auch kein `LeerNachLauf` und kein
// `Fehlgeschlagen`.
//
// **Das heißt aber nicht, dass „wird gerade gelesen" wie „nichts da"
// aussehen darf.** Ein drift-Lesevorgang braucht einen Moment, und in
// diesem Moment stünde sonst „Diese Woche ist das Krafttraining durch."
// auf dem Schirm, obwohl der Plan gleich eintrifft — Fehler `01` in neuer
// Verpackung. Dafür trägt [GymTag] sein [GymTag.laedt], nach dem Muster
// von `ErnaehrungsTag.zielLaedt`.
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../health/health_provider.dart';
import 'gym_entwurf_provider.dart';
import 'gym_trainings_provider.dart';
import 'gym_verlauf_provider.dart';

/// Alles, was der Gym-Übersichtsschirm zeigt.
///
/// **Werttyp mit [==] und [hashCode] über alle Felder** (`CLAUDE.md`,
/// Fehler `03`). Er ist die Abhängigkeit, an der jeder abgeleitete Wert
/// und jeder `select` hängt; ohne Wertgleichheit wäre jedes neu gebaute
/// `GymTag` ungleich dem vorigen, und der ganze Schirm rechnete bei jeder
/// Provider-Aktualisierung neu.
@immutable
class GymTag {
  const GymTag({
    required this.tag,
    required this.laedt,
    this.letzteSitzung,
    this.verlauf = const {},
  });

  /// Der Tageszustand aus dem Kern — Fokus-Karte und Wochenleiste.
  ///
  /// [GymDay] bringt [==] und [hashCode] selbst mit, mit inhaltlichem
  /// Vergleich der Wochenliste.
  final GymDay tag;

  /// `true`, solange eine der Quellen noch kein Ergebnis hat.
  ///
  /// **Trennt „noch nicht nachgesehen" von „nichts eingetragen".** Beides
  /// ergibt dieselbe leere Datenlage, aber nur das zweite darf einen
  /// Grund anzeigen: Solange dies `true` ist, zeigt die Fokus-Karte im
  /// Zustand [Rest] **nicht** den Satz „Diese Woche ist das Krafttraining
  /// durch." und die Wochenleiste nicht dreimal „offen", sondern den
  /// grauen Platzhalter in derselben Geometrie.
  ///
  /// **Nur maßgeblich, wo noch nichts dasteht.** Liegt für eine Anzeige
  /// bereits ein Wert vor, bleibt er stehen, auch während neu gelesen
  /// wird — ein Platzhalter, der bei jedem Zug von oben aufblitzt, ist das
  /// Flackern, gegen das die Regel gebaut ist (`CLAUDE.md`).
  ///
  /// Eine der Quellen — Rotation, Entwurf, Sitzungen — hat noch nie
  /// geantwortet. Ein gescheitertes Lesen ist **nicht** `laedt`: Es gibt
  /// dann keine Quelle, die etwas erfinden könnte, und es läuft nichts mehr.
  final bool laedt;

  /// Die jüngste abgeschlossene Sitzung — für die Auswertungszeile
  /// „Letzte Trainings" und für den Zusatz „· zuletzt …" im Untertitel der
  /// Fokus-Karte. `null`, wenn es keine gibt.
  ///
  /// [ImportedSession] bringt [==] und [hashCode] selbst mit.
  final ImportedSession? letzteSitzung;

  /// Übungs-ID → Satzlisten, **neueste Sitzung zuerst** — die Form, die
  /// [Progression.suggest] erwartet (`GymSessionMerge.history`). Leer,
  /// wenn es keinen Verlauf gibt.
  ///
  /// Darts [==] auf [Map] und [List] ist **Identität, nicht Inhalt**; der
  /// Vergleich steht deshalb von Hand in [==], so wie `GymDay._gleicheWoche`
  /// und `Exercise._gleicheGewichte` es vormachen.
  final Map<String, List<List<CompletedSet>>> verlauf;

  @override
  bool operator ==(Object other) =>
      other is GymTag &&
      other.tag == tag &&
      other.laedt == laedt &&
      other.letzteSitzung == letzteSitzung &&
      gleicherGymVerlauf(other.verlauf, verlauf);

  @override
  int get hashCode =>
      Object.hash(tag, laedt, letzteSitzung, gymVerlaufHash(verlauf));

  @override
  String toString() =>
      'GymTag(focus: ${tag.focus}, laedt: $laedt, '
      'letzteSitzung: ${letzteSitzung?.id}, verlauf: ${verlauf.length})';
}

/// Inhaltlicher Vergleich zweier Verlaufskarten.
///
/// Öffentlich, weil `GymVerlauf` (`gym_verlauf_provider.dart`, #78) dieselbe
/// Karte trägt und denselben Vergleich braucht — zwei Fassungen liefen beim
/// ersten Fix an einer von beiden auseinander.
///
/// Die Reihenfolge der Schlüssel zählt nicht (eine [Map] ist ungeordnet),
/// die Reihenfolge der Sitzungen und der Sätze darin schon: „neueste
/// zuerst" ist die Zusage, auf der [Progression.suggest] steht, und erst
/// 8 Wiederholungen und dann 6 ist ein anderer Verlauf als umgekehrt.
bool gleicherGymVerlauf(
  Map<String, List<List<CompletedSet>>> a,
  Map<String, List<List<CompletedSet>>> b,
) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (final eintrag in a.entries) {
    final anderer = b[eintrag.key];
    if (anderer == null) return false;
    if (!_gleicheSitzungen(anderer, eintrag.value)) return false;
  }
  return true;
}

bool _gleicheSitzungen(List<List<CompletedSet>> a, List<List<CompletedSet>> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (!_gleicheSaetze(a[i], b[i])) return false;
  }
  return true;
}

bool _gleicheSaetze(List<CompletedSet> a, List<CompletedSet> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Hash über die Verlaufskarte, **unabhängig von der Schreibreihenfolge**
/// der Schlüssel: Gleiche Karten müssen denselben Hash bekommen, sonst
/// fielen zwei gleiche `GymTag` in einer Menge nicht zusammen. Derselbe
/// Griff wie in `Exercise._gewichteHash`.
int gymVerlaufHash(Map<String, List<List<CompletedSet>>> verlauf) {
  final schluessel = verlauf.keys.toList()..sort();
  return Object.hashAll([
    for (final id in schluessel) ...[
      id,
      Object.hashAll([
        for (final sitzung in verlauf[id]!) Object.hashAll(sitzung),
      ]),
    ],
  ]);
}

/// Rechnet den Tageszustand des Gym-Tabs.
///
/// Reine Funktion: Alles, was sie braucht, kommt herein — auch [heute].
/// Die Verdrahtung in den Riverpod-Baum liegt in [gymTagProvider].
///
/// **Sie rät nichts.** Von den Eingaben von [GymDayPlanner.day] kommen die
/// Rotation ([gymRotationProvider]), der Entwurf und die Sitzungen aus der
/// Ablage; die übrigen haben Vorgabewerte, die „nichts eingetragen"
/// bedeuten, und keinen erfundenen Inhalt. Welches Ticket den jeweiligen
/// Wert später liefert, steht an den Parametern.
///
/// `pauseDays` wird **nicht durchgereicht**: Der Vorgabewert 14 steht im
/// Kern, und ihn hier zu wiederholen hieße, dieselbe allgemeine Empfehlung
/// an zwei Stellen zu führen. Wer sie aus den Zielen holen will (#41),
/// ergänzt hier einen Parameter — und dann gibt es die Zahl immer noch
/// nur einmal.
GymTag gymTagAus({
  required DateTime heute,

  /// Die Trainings, die einen Platz in der Wochenleiste haben, in der
  /// Reihenfolge der Plätze (Spec 23, 24). Vorgabe: die **Startbefüllung**
  /// Push, Pull, Legs ([gymStartRotation]) — **nicht** `Workout.rotation`,
  /// das wären Gym A bis D, und die sind nirgends mehr startbar. Die Logik
  /// des Planers ist dieselbe geblieben; nur die Quelle der Plätze wechselt.
  ///
  /// Eine leere Liste ist eine leere Woche (alle Templates gelöscht) — der
  /// Planer wirft dabei nicht, die Leiste sagt es in einem Satz.
  List<Workout>? rotation,

  /// Der Wochenplan. **Gibt es heute nicht** — es existiert kein
  /// Plan-Generator und keine Tabelle dafür; das bringen #64 und #81,
  /// überlagert vom Tagestausch (#11, #83). Mit leerer Liste füllt
  /// `GymDayPlanner._sorted` die Rotation ohne Tag auf: ein Platz je
  /// Training der Rotation mit Status `Open`, Lede „kein fester Tag",
  /// Fokus `Rest` ohne alles. Ein Plan für ein Workout **außerhalb** der
  /// Rotation füllt keinen Platz.
  List<PlannedGym> plan = const [],

  /// Je Workout der Zeitpunkt des letzten Abschlusses. **Gibt es heute
  /// nicht** — es gibt keine Gym-Tabelle und keine Übernahme aus dem
  /// Dashboard; das bringen #59 und #418. Später aus
  /// `GymSessionMerge.merge(logged, imported)`.
  Map<Workout, DateTime> erledigt = const {},

  /// Die von außen als nachzuholen gemeldeten Workouts. **Gibt es heute
  /// nicht, und das bleibt vorerst so:** Eine eigene Rechnung über frühere
  /// Wochen steht aus, und der Swift-Kommentar sagt, warum nicht geraten
  /// wird — „eine geratene Liste wäre schlimmer als keine".
  List<Workout> nachzuholen = const [],

  /// Das angefangene Training. **Gibt es heute nicht** — einen Entwurf
  /// legt erst #78 an (Ablage: #418). Ohne ihn ist `InProgress`
  /// unerreichbar und kein Platz wird `Running`.
  GymDraft? entwurf,

  /// Der OP-Termin. **Gibt es heute nicht, und hier ist das eine Zusage,
  /// keine Lücke:** `CLAUDE.md` verbietet jedes Ereignisdatum im
  /// Quelltext. Das Ereignis-Objekt bringt #41. Ohne ihn ist `Recovery`
  /// unerreichbar und kein Platz wird `Paused`.
  DateTime? opTermin,

  /// Siehe [GymTag.laedt]. Der Provider setzt es, solange eine Quelle noch
  /// nie geantwortet hat; die reine Funktion nimmt es nur entgegen.
  bool laedt = false,

  /// Siehe [GymTag.letzteSitzung]. Kommt mit #59/#78.
  ImportedSession? letzteSitzung,

  /// Siehe [GymTag.verlauf]. Kommt mit #59/#78.
  Map<String, List<List<CompletedSet>>> verlauf = const {},
}) => GymTag(
  tag: GymDayPlanner.day(
    today: heute,
    planned: plan,
    completed: erledigt,
    overdue: nachzuholen,
    draft: entwurf,
    surgery: opTermin,
    rotation: rotation ?? gymStartRotation,
  ),
  laedt: laedt,
  letzteSitzung: letzteSitzung,
  verlauf: verlauf,
);

/// Der Tageszustand des Gym-Tabs — **gehalten**, nicht bei jedem Zugriff
/// gerechnet (Hausregel 2, Fehler `03`).
///
/// Synchron und ohne `AsyncValue`, wie `erholungProvider` und
/// `ernaehrungsTagProvider`: Die Widget-Schicht bekommt einen Wert, keinen
/// Ladezustand — der Ladezustand steckt in [GymTag.laedt].
///
/// Er rechnet genau dann neu, wenn sich eine seiner Abhängigkeiten ändert:
/// beim Berliner Kalendertagswechsel ([heutigerTagProvider]) und wenn der
/// Entwurf oder die abgelegten Trainings sich ändern — der Erfassen-Schirm
/// sagt es mit `ref.invalidate`. Die Swift-Vorlage rechnet bei
/// jedem Zeichnen neu (`GymOverviewView.swift:16`), und ihre Begründung
/// steht dort: Ein `@State` hielt vorher den Stand des ersten Öffnens
/// fest, „ein Tagestausch im Plan kam im Gym-Tab nie an, und über
/// Mitternacht hinweg blieb der gestrige Tag stehen". Beides ist in
/// Riverpod über Abhängigkeiten abgedeckt — der Tageswechsel über
/// [heutigerTagProvider], der Tagestausch später über den Plan-Provider.
/// Damit entfällt der Grund der Swift-Fassung und ihre Lösung.
///
/// **Drei Quellen sind da, zwei fehlen.** Die Rotation
/// ([gymRotationProvider], Spec 23/24), der Entwurf ([gymEntwurfProvider])
/// und die abgelegten Trainings ([gymSitzungenProvider]); `gymPlanProvider`
/// (#64, #81) und `opTerminProvider` (#41) sind je eine eigene Karte und
/// werden hier nicht mitgebaut. Bis es sie gibt, stehen für Plan, Nachzügler
/// und OP die Vorgabewerte aus [gymTagAus]: kein fester Tag, nie `Recovery`.
///
/// **[GymTag.laedt] schließt die Rotation ein:** Ohne sie weiß der Tag nicht,
/// wie viele Plätze die Woche hat — „Ruhetag" wäre eine Behauptung ohne
/// Grundlage (Fehler `01`). Eine Rotation mit unbekannter Kennung lässt den
/// Provider **werfen** (Spec 24 Nr. 4), statt still kürzer zu werden.
///
/// Ausgepackt wird ohne `AsyncValue` für die Widget-Schicht — wer liest,
/// bekommt einen Wert, und der Ladezustand steckt in [GymTag.laedt].
final gymTagProvider = Provider<GymTag>((ref) {
  final heute = ref.watch(heutigerTagProvider);
  if (!ref.watch(gymAblageVerfuegbarProvider)) return gymTagAus(heute: heute);
  final entwurf = ref.watch(gymEntwurfProvider);
  final sitzungen = ref.watch(gymSitzungenProvider);
  final rotation = ref.watch(gymRotationProvider);

  // `hasValue` und nicht `isLoading`: Ein erneutes Lesen behält den letzten
  // Wert — der Platzhalter gehört allein in den Ladezustand, und ein
  // Entwurf, der gerade neu gelesen wird, ist kein unbekannter. Ein
  // gescheitertes Lesen ist hier „nichts da": keine Quelle, die etwas
  // erfinden könnte.
  final laedt =
      (!entwurf.hasValue && !entwurf.hasError) ||
      (!sitzungen.hasValue && !sitzungen.hasError) ||
      rotation.laedt;
  final liste = sitzungen.value ?? const <ImportedSession>[];

  // Je Workout der Zeitpunkt des **letzten** Abschlusses — `sitzungen`
  // liegt neueste zuerst, der erste Treffer gilt.
  final erledigt = <Workout, DateTime>{};
  for (final sitzung in liste) {
    final workout = sitzung.workout;
    if (workout != null) erledigt.putIfAbsent(workout, () => sitzung.date);
  }

  return gymTagAus(
    heute: heute,
    rotation: rotation.workouts,
    erledigt: erledigt,
    entwurf: entwurf.value,
    laedt: laedt,
    letzteSitzung: liste.isEmpty ? null : liste.first,
    verlauf: ref.watch(gymVerlaufProvider).verlauf,
  );
});
