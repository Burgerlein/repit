// Die Sätze der Gym-Fokus-Karte (#77) — Dart-Entsprechung von
// `Sources/Features/Gym/GymFocusText.swift`, ergänzt um die Texte, die in
// Swift noch in `GymOverviewView` und `GymPlanPreview` stehen.
//
// **Warum diese Datei existiert:** `trainings_core` trägt keine
// Nutzertexte — `GymFocus`, `GymSlot` und `Suggestion` tragen „nur Zahlen
// und Fälle", und ihre Doc-Kommentare sagen das ausdrücklich. Die Sätze
// entstehen deshalb in der Ansichtsschicht, und zwar an **genau einer
// Stelle je Vokabular**: Ein Abschnitt, der sich seinen Satz selbst
// zusammenbaut, läuft beim ersten Wortlautwechsel auseinander, und der
// Hinweis auf die ärztliche Freigabe geht dabei als Erstes verloren.
//
// Jede Datumsangabe läuft über [Format] mit fest gesetzter Sprache, nie
// über eine eigene `DateFormat`-Instanz (`CLAUDE.md`): Auf einem englisch
// eingestellten Gerät stünde sonst „Monday" mitten im deutschen Text.
//
// **Kein Ereignisdatum im Quelltext** (`CLAUDE.md`, „Keine hartcodierten
// Ereignisse"): Weder der OP-Termin noch der Wiedereinstieg steht hier,
// auch nicht als Beispiel in einem Kommentar. Beide kommen zur Laufzeit
// aus [Recovery], das sie aus dem Parameter `surgery` von
// `GymDayPlanner.day` rechnet.
import 'package:flutter/widgets.dart' show Color;
import 'package:trainings_core/trainings_core.dart';

import '../design/formatierung.dart';
import '../design/palette.dart';
import 'gym_vorschlag_texte.dart';
import 'gym_wochen_texte.dart' show gymWocheLeerText;

/// Die Akzentfarbe der Fokus-Karte — Kapsel und farbige Kante.
///
/// **`Palette.rest` ist ein sehr helles Grau**, Kapsel und Kante sind im
/// Ruhetag damit fast unsichtbar. Das steht so in `GymFocusText.accent`
/// und ist im Entwurf bewusst nachgebaut (`docs/screens/screens/gym.js`:
/// „Das ist nicht mein Fehler beim Nachbauen, sondern steht so im Code").
/// Wer es aufhellt, abdunkelt oder durch `Palette.muted` ersetzt, weicht
/// ohne Entscheidung vom Entwurf ab — offene Entscheidung 5 der Spec.
Color gymFokusAkzent(GymFocus focus) => switch (focus) {
  InProgress() || Planned() => Palette.iron,
  Rest() => Palette.rest,
  Recovery() => Palette.warn,
};

/// Die Kapsel oben in der Karte: „Angefangen", „Heute", „Heute kein Gym",
/// „Pause".
///
/// [minutenLaufend] ist die zweite Fassung aus
/// `GymFocusText.pill(_:minutesRunning:)` — „Läuft seit 42 min". **Sie
/// wird heute von niemandem gefüllt**, weil der Startzeitpunkt eines
/// Trainings nirgends abgelegt ist; den Entwurf dafür legt erst #78 an.
/// Der Parameter steht trotzdem hier, damit wer ihn später füllt den Text
/// nicht erst erfinden muss.
String gymFokusKapsel(GymFocus focus, {int? minutenLaufend}) => switch (focus) {
  InProgress() =>
    minutenLaufend == null ? 'Angefangen' : 'Läuft seit $minutenLaufend min',
  Planned() => 'Heute',
  Rest() => 'Heute kein Gym',
  Recovery() => 'Pause',
};

/// Der Titel der Karte: „Push — Brust, Schultern, Trizeps", „Ruhetag",
/// „Kein Krafttraining".
String gymFokusTitel(GymFocus focus) => switch (focus) {
  InProgress(:final workout, :final trainingName) =>
    workout == null
        ? (trainingName ?? 'Training')
        : '${workout.label} — ${workout.title}',
  Planned(:final workout) => '${workout.label} — ${workout.title}',
  Rest() => 'Ruhetag',
  Recovery() => 'Kein Krafttraining',
};

/// Der Untertitel der Karte — ein bis zwei Zeilen, getrennt durch `\n`.
///
/// [heute] ist der Berliner Tagesbeginn aus `heutigerTagProvider`. Er wird
/// gebraucht, um aus `Rest.inDays` einen Wochentagsnamen zu machen: Der
/// Kern liefert einen Abstand in Tagen, die Ansicht nennt den Tag.
///
/// [zuletzt] ist der Zeitpunkt des letzten abgeschlossenen Trainings
/// dieses Workouts. Er erscheint **nur** im Zustand `planned` und **nur**,
/// wenn er bekannt ist — ohne ihn fehlt der Zusatz „· zuletzt …"
/// vollständig. Heute ist er immer `null`, weil es keine Gym-Ablage gibt
/// (#59, #78).
///
/// **Die zweite Zeile im Ruhetag fällt weg, wenn `next` oder `inDays`
/// fehlt.** Damit die Karte dabei nicht springt, bekommt der Untertitel in
/// allen vier Zuständen eine feste Zeilenzahl — das ist Sache der Ansicht
/// (`FesteZeilen`, Spec Abschnitt 10), nicht dieses Textes.
///
/// [leereWoche] sagt, dass die Woche **keinen** Platz hat (alle Templates
/// gelöscht, Spec 24 Nr. 1). Dann wäre „Diese Woche ist das Krafttraining
/// durch." eine falsche Auskunft — es ist nichts durch, es steht nichts an —,
/// und die zweite Zeile sagt stattdessen, dass kein Training in der Woche
/// steht. **Keine Aufforderung, eines anzulegen:** Ein neues Training kommt in
/// dieser Stufe nicht in die Woche (Einplanen ist #536).
String gymFokusUntertitel(
  GymFocus focus, {
  required DateTime heute,
  DateTime? zuletzt,
  bool leereWoche = false,
}) {
  switch (focus) {
    case InProgress(:final workout, :final total):
      // Ein eigenes Training kennt hier nur die Zahl seiner Übungen: Die
      // Dauer steht in seiner Definition, nicht im Fall.
      return workout == null
          ? '$total Übungen'
          : '${_uebungen(workout)} Übungen · ca. ${workout.minutes} min';

    case Planned(:final workout):
      final basis =
          '${_uebungen(workout)} Übungen · ${_saetze(workout)} Sätze · '
          'ca. ${workout.minutes} min';
      if (zuletzt == null) return basis;
      return '$basis · zuletzt ${gymZuletztText(zuletzt)}';

    case Rest(:final next, :final inDays):
      const spaziergang = 'Laut Plan: Spaziergang 30–45 min und Mobility.';
      // „Diese Woche ist das Krafttraining durch." ist eine Aussage über
      // eine Datenlage. Sie darf nur stehen, wenn tatsächlich nachgesehen
      // wurde — solange `GymTag.laedt` wahr ist, zeigt die Ansicht
      // stattdessen den Platzhalter (Fehler `01`).
      if (next == null || inDays == null) {
        return leereWoche
            ? '$spaziergang\n$gymWocheLeerText'
            : '$spaziergang\nDiese Woche ist das Krafttraining durch.';
      }
      final tag = Format.wochentag(
        kalendertag(BerlinCalendar.addDays(heute, inDays)),
      );
      return '$spaziergang\nNächstes Krafttraining: $tag, '
          '${next.label} — ${next.title}.';

    case Recovery(:final earliestReturn):
      // Der Tag nach der OP steht schon im Lede; hier stünde er ein
      // zweites Mal. Der Hinweis auf die ärztliche Freigabe steht
      // dagegen bewusst dreimal auf diesem Schirm — hier, in der
      // Fußzeile und im Hinweis am Fuß (`CLAUDE.md`, „Keine Diagnosen").
      final zurueck = Format.wochentagUndTagMonat(kalendertag(earliestReturn));
      return 'Wiedereinstieg frühestens $zurueck — und nur nach '
          'ärztlicher Freigabe.';
  }
}

/// „2 von 7 Übungen erfasst" — die Beschriftung unter dem
/// Fortschrittsbalken.
///
/// **Nur Übungen, keine Sätze und kein Volumen** (`GymFocusText
/// .progressLabel`): Die Übernahme kennt keine laufende Erfassung, und
/// erfundene Zahlen wären schlimmer als keine.
String gymFokusFortschrittText({required int done, required int total}) =>
    '$done von $total Übungen erfasst';

/// Der Lede unter der Überschrift „Gym".
///
/// **Gerechnet, nicht geschrieben.** Vorher stand in der Swift-Vorlage
/// „Montag, Mittwoch, Donnerstag" fest im Quelltext, während die
/// Wochenleiste zwei Zeilen tiefer längst „DI" zeigte, weil jemand die
/// Tage getauscht hatte. Genannt werden die ausgeschriebenen Wochentage
/// der Plätze **mit** Tag, in Plan-Reihenfolge; hat kein Platz einen Tag,
/// steht dort „kein fester Tag".
///
/// **Ohne das Präfix „Vor der OP · "** aus der Swift-Vorlage (Tims
/// Entscheidung vom 10.11.2026): Einen OP-Termin kann man im Neubau noch
/// gar nicht eintragen (#41), das Präfix behauptete sonst eine OP, die
/// nirgends steht. Es kommt, wenn es das Ereignis-Objekt gibt.
///
/// Im Zustand `recovery` ersetzt der Lede sich durch „Erholung · Tag N
/// nach der OP", mit N aus [Recovery.dayAfterSurgery].
String gymLede(GymDay tag, {required DateTime heute}) {
  final focus = tag.focus;
  if (focus is Recovery) {
    return 'Erholung · Tag ${focus.dayAfterSurgery} nach der OP';
  }
  final namen = [
    for (final platz in tag.week)
      if (platz.weekday case final int wochentag)
        Format.wochentag(_tagDieserWoche(wochentag, heute)),
  ];
  return namen.isEmpty ? 'kein fester Tag' : namen.join(', ');
}

/// Der Hinweis am Fuß des Schirms — **nur im Zustand `recovery`**, sonst
/// `null` (Tim, 19.11.2026, Spec 26 Nr. 3: der graue Fuß „Die Gewichte sind
/// Vorschläge …" entfällt).
///
/// Im Erholungs-Zustand bleibt er, und das ist **Pflichttext, keine Zierde**:
/// `CLAUDE.md` („Keine Diagnosen") verlangt bei OP-Erholung den Hinweis auf
/// die ärztliche Freigabe ([gymHinweisErholung]).
String? gymHinweis(GymFocus focus) =>
    focus is Recovery ? gymHinweisErholung : null;

/// Der Hinweis in `recovery` — **mit dem Verweis auf die ärztliche
/// Freigabe.** Fällt er weg, steht auf dem Schirm eine Pausenempfehlung
/// ohne Absender, und das wäre eine Diagnose.
const String gymHinweisErholung =
    'Die Pause und der Wiedereinstiegstermin sind allgemeine Richtwerte '
    'aus deinem Plan, keine ärztliche Empfehlung. Wann du wieder '
    'trainieren darfst, entscheidet deine Ärztin oder dein Arzt.';

/* ---- Fußzeile und Knöpfe der Karte ---------------------------------- */

/// „Als Nächstes: Schulterdrücken Kurzhantel sitzend" — die Fußzeile des
/// laufenden Trainings.
String gymNaechsteUebungTitel(Exercise uebung) =>
    'Als Nächstes: ${uebung.name}';

/// „3 × 8–12 · Nächstes Mal 18 kg, Ziel 8 Wiederholungen." — Satzschema
/// und Kurzfassung des Vorschlags, wie `GymOverviewView.detail(for:)`.
///
/// Der Entwurf schreibt an dieser Stelle „3 × 8–12 · wie zuletzt"; das ist
/// ein Beispielwert im Board, keine eigene Formulierung — die Swift-
/// Vorlage setzt dort die Kurzfassung aus [vorschlagKurzText] ein.
String gymUebungDetailText(
  Exercise uebung,
  Suggestion vorschlag, {
  required bool hatVerlauf,
}) =>
    '${gymSatzSchemaText(uebung)} · '
    '${vorschlagKurzText(vorschlag, uebung, hatVerlauf: hatVerlauf)}';

/// „4 × 6–10" — Sätze mal Wiederholungsbereich; bei einer Zeitübung
/// „3 × 30–60 s".
String gymSatzSchemaText(Exercise uebung) {
  final bereich = '${uebung.sets} × ${uebung.repLow}–${uebung.repHigh}';
  return uebung.isTimed ? '$bereich s' : bereich;
}

/// „Alle 7 Übungen ansehen" — die letzte Zeile der Übungsvorschau.
///
/// **Erscheint nur, wenn es mehr Übungen gibt als gezeigte.** Stehen
/// ohnehin alle da, führt der Knopf nirgendwohin, und ein Winkel ohne Tür
/// ist genau der Fehler, den `docs/screens/pruefen.mjs` sucht. Diese
/// Funktion liefert nur den Text; ob die Zeile steht, entscheidet die
/// Ansicht.
String gymAlleUebungenText(int anzahl) => 'Alle $anzahl Übungen ansehen';

/// „Gym B vorziehen" — der getönte Knopf im Ruhetag, nur bei `Rest.next`.
String gymVorziehenKnopf(Workout workout) => '${workout.label} vorziehen';

/// „Gym D ist offen" — die Fußzeile im Ruhetag, nur bei `Rest.overdue`.
String gymOffenTitel(Workout workout) => '${workout.label} ist offen';

/// Der Untertitel dazu. Nennt den Grund, nicht die Zahl: Woher ein
/// Nachzügler kommt, steht in keiner anderen Zeile.
const String gymOffenUntertitel = 'Aus einer früheren Woche liegen geblieben';

/// Der Titel der Fußzeile im Zustand `recovery`.
const String gymErholungFussTitel = 'Erste Woche zurück';

/// Der Text darunter — **mit dem Verweis auf die ärztliche Freigabe.**
/// Die Zahl „rund 20 %" ist eine allgemeine Empfehlung aus dem Plan und
/// keine ärztliche Vorgabe; ohne den Nachsatz stünde sie als Anweisung da.
const String gymErholungFussText =
    'Ein Satz weniger je Übung, Gewichte rund 20 % runter — nach '
    'ärztlicher Freigabe.';

/* ---- Datum und Zahlen ------------------------------------------------ */

/// „Do. 09.10." — wann dieses Workout zuletzt abgeschlossen wurde.
///
/// Der Entwurf schreibt „Do, 09.10." mit Komma und ohne Punkt. Hier steht
/// die Form, die [Format] liefert: `intl` schreibt die deutsche Kurzform
/// des Wochentags mit Punkt, und die Nachtkarte setzt sie schon so
/// zusammen („Mo. 11.10."). Welche der beiden Schreibweisen gilt, ist eine
/// Entscheidung und kein Tippfehler — derselbe offene Punkt wie bei
/// [Format.wochentagKurz].
String gymZuletztText(DateTime zeitpunkt) {
  final tag = kalendertag(zeitpunkt);
  return '${Format.wochentagKurz(tag)} ${Format.tagMonat(tag)}';
}

/// Wie viele Übungen das Workout hat.
int _uebungen(Workout workout) => ExerciseCatalog.exercisesFor(workout).length;

/// Wie viele Sätze das Workout insgesamt hat.
int _saetze(Workout workout) =>
    ExerciseCatalog.exercisesFor(workout)
        .fold<int>(0, (summe, uebung) => summe + uebung.sets);

/// Der Kalendertag, auf den ein Wochentag (1 = Montag … 7 = Sonntag) in
/// der Woche von [heute] fällt.
///
/// **Warum überhaupt ein Datum:** Der Kern führt Wochentage als Zahl, die
/// Oberfläche braucht einen Namen — und der darf nach `CLAUDE.md` nicht
/// aus einer von Hand getippten Namensliste kommen (so macht es Swift in
/// `Weekday.name`), sondern aus [Format] mit fest gesetzter Sprache. Dafür
/// braucht [Format] einen `DateTime`, und der entsteht hier aus dem
/// tatsächlichen heutigen Tag statt aus einem erfundenen Stichtag.
///
/// Der Schritt läuft über [BerlinCalendar.addDays], nicht über eine
/// [Duration]: Über eine Zeitumstellung hinweg sind 24 Stunden kein Tag.
DateTime _tagDieserWoche(int wochentag, DateTime heute) => kalendertag(
  BerlinCalendar.addDays(heute, wochentag - BerlinCalendar.weekday(heute)),
);
