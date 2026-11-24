// Die Beschriftung und die Farben der Wochenleiste „Diese Woche" (#77) —
// Dart-Entsprechung von `GymWeekStrip.weekday/label/tint/labelTint` in
// `Sources/Features/Gym/GymWeekStrip.swift`.
//
// Eigene Datei aus demselben Grund wie `gym_fokus_texte.dart`: Der Kern
// gibt mit [GymSlotStatus] nur Fälle heraus, die Sätze entstehen in der
// Ansicht — und zwar an genau einer Stelle je Vokabular.
//
// **Die Leiste filtert nicht.** Welche Trainings einen Platz haben, sagt
// `GymDayPlanner` aus der gespeicherten Rotation (Spec 23/24): Push, Pull und
// Legs zum Start. Gym A bis D stehen nicht darin und sind nirgends mehr
// startbar. Täte der Schirm es ein zweites Mal, gäbe es zwei Stellen, an
// denen dieselbe Zusage eingehalten wird, und nur eine davon würde später
// angepasst.
//
// **Es sind null bis drei Plätze** (Spec 24 Nr. 1): Löscht jemand ein
// Template, verlässt es die Rotation, und die Leiste hat einen Platz weniger.
// Bleibt keiner, sagt es [gymWocheLeerText]. Die Leiste behält dabei ihre
// Höhe und ihre Breite — „Eine Anzeige, die es gibt, hat genau eine Form"
// (`CLAUDE.md`). Vorher standen hier immer vier Plätze (#425, Tims
// Entscheidung vom 10.11.2026): Das war die Rotation A–D und ist mit Spec 23
// aufgehoben.
import 'package:flutter/widgets.dart' show Color;
import 'package:trainings_core/trainings_core.dart';

import '../design/formatierung.dart';
import '../design/palette.dart';

/// „MO." — der versale Wochentag über der Kachel, „—" ohne festen Tag.
///
/// [heute] ist der Berliner Tagesbeginn aus `heutigerTagProvider`: Der
/// Kern führt den Wochentag als Zahl (1 = Montag … 7 = Sonntag), [Format]
/// braucht einen `DateTime`, und der entsteht aus dem tatsächlichen
/// heutigen Tag statt aus einem erfundenen Stichtag.
///
/// **Mit Punkt.** `intl` schreibt die deutsche Kurzform so
/// ([Format.wochentagKurz]); der Entwurf schreibt „MO" ohne. Welche
/// Schreibweise gilt, ist eine Entscheidung und kein Tippfehler — derselbe
/// offene Punkt wie in der Nachtkarte.
///
/// **„—" ist kein Platzhalter für einen fehlenden Wert**, sondern die
/// Aussage „dieses Workout hat keinen festen Tag". Ein Datum dort wäre
/// erfunden.
String gymWochenTag(GymSlot platz, {required DateTime heute}) {
  final wochentag = platz.weekday;
  if (wochentag == null) return '—';
  final tag = kalendertag(
    BerlinCalendar.addDays(heute, wochentag - BerlinCalendar.weekday(heute)),
  );
  return Format.wochentagKurz(tag).toUpperCase();
}

/// „✓ erledigt", „läuft", „heute", „offen", „nachholen", „pausiert" —
/// wörtlich aus `GymWeekStrip.label`.
String gymWochenStatus(GymSlotStatus status) => switch (status) {
  Done() => '✓ erledigt',
  Running() => 'läuft',
  Today() => 'heute',
  Open() => 'offen',
  Overdue() => 'nachholen',
  Paused() => 'pausiert',
};

/// Die Farbe des Balkens über der Kachel — **dort lebt das Statussignal.**
Color gymWochenBalken(GymSlotStatus status) => switch (status) {
  Done() => Palette.ok,
  Running() || Today() => Palette.iron,
  Open() || Paused() => Palette.rest,
  Overdue() => Palette.bib,
};

/// Die Farbe des Statustexts — grau, **nur „✓ erledigt" trägt die
/// Statusfarbe mit.**
///
/// Der Swift-Kommentar begründet es: „sonst steht dasselbe Signal zweimal
/// da".
Color gymWochenStatusFarbe(GymSlotStatus status) =>
    status is Done ? Palette.ok : Palette.muted;

/// Ob die Kachel die zwei Punkt breite Umrandung in `Palette.iron`
/// bekommt: das laufende und das heutige Workout.
bool gymWochenHervorgehoben(GymSlotStatus status) =>
    status is Running || status is Today;

/// Ob die Kachel auf 45 % Deckkraft abgeblendet wird — während der
/// Erholung nach der OP.
bool gymWochenAbgeblendet(GymSlotStatus status) => status is Paused;

/// Der Vorlesetext einer Kachel: „Push, offen".
///
/// **Nennt den Zustand, nicht das Zeichen** (`CLAUDE.md`): „Push, offen"
/// und nicht „Push Strich offen". Der Wochentag steht bewusst nicht darin —
/// so macht es `GymWeekStrip.swift:15`, und „MO., Push, heute" sagt
/// dreimal dasselbe, wenn der Platz ohnehin heute ist.
String gymWochenVorlesetext(GymSlot platz) =>
    '${platz.workout.label}, ${gymWochenStatus(platz.status)}';

/// Der Satz der Leiste, wenn **keine** Rotation da ist: Alle Trainings, die
/// einen Platz hatten, sind gelöscht (Spec 24 Nr. 1).
///
/// **Keine Aufforderung, ein Training anzulegen:** Ein neues Training kommt
/// in dieser Stufe nicht in die Woche — Einplanen ist #536. Ein Satz, der es
/// nahelegte, wäre eine Zusage, die der Code nicht hält.
const String gymWocheLeerText = 'Es steht kein Training in der Woche.';
