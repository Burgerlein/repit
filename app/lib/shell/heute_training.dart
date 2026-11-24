/// Der Abschnitt **Heute Training** auf Home (#501) — nach `TRAINING` in
/// `docs/screens/screens/heute-kombi.js`.
///
/// **Er zeigt den Tag, nicht die Woche** (Tim, 16.11.2026): was heute
/// ansteht und wie weit es ist. Die alte App führt weiter unten
/// „Gym-Einheiten 0/3 · Gelaufen –/10,0"; das ist die Woche und hat mit
/// dem Plan-Reiter einen eigenen Ort.
///
/// **Gerechnet wird hier nichts.** Welche Einheit heute dran ist,
/// entscheidet [GymDayPlanner] im Kern; dieser Abschnitt liest den
/// gehaltenen `gymTagProvider` — denselben Zustand wie der Gym-Tab
/// (Hausregel 2). Zwei Quellen für dieselbe Auskunft wären zwei
/// Wahrheiten, und sie liefen am Tag des ersten Tagestauschs auseinander.
///
/// **Ein geplanter Lauf steht hier noch nicht.** Es gibt im Neubau weder
/// Laufplan noch Laufeinheit — kein Provider, keine Tabelle. Eine Zeile
/// dafür wäre eine erfundene Auskunft; sie kommt mit dem Plan (#64, #81).
library;

import 'package:flutter/cupertino.dart';
import 'package:trainings_core/trainings_core.dart';

import '../design/icon_row.dart';
import '../design/kachel_karte.dart';
import '../design/palette.dart';
import '../design/section_header.dart';
import '../gym/gym_fokus_texte.dart';
import '../gym/gym_provider.dart';
import 'router.dart';
import 'ziele.dart';

/// Was die eine Zeile des Abschnitts sagt.
///
/// Zwei fertige Zeichenketten, kein Zustand: Die Entscheidung, welcher
/// Fall vorliegt, trifft [heuteTrainingZeile] **einmal**; die Ansicht
/// setzt sie nur noch.
///
/// [==] und [hashCode] stehen hier **nicht**, weil der Typ heute
/// Abhängigkeit eines Providers wäre — er entsteht in `build` und wird
/// sofort verbraucht. Sie stehen hier, damit er es werden **darf**: Wer
/// die Zeile später hält oder vergleicht, bekommt Wertgleichheit, statt
/// bei jedem Aufbau einen ungleichen Nachbau (Fehler `03`). Ein Werttyp
/// ohne `==` ist eine Falle, die erst am Tag ihrer ersten Benutzung
/// zuschnappt.
@immutable
class HeuteTrainingZeile {
  const HeuteTrainingZeile({required this.titel, required this.untertitel});

  /// Die Einheit — „Push — Brust, Schultern, Trizeps", „Ruhetag", „Kein
  /// Krafttraining".
  final String titel;

  /// Der **Stand** zuerst, das Detail dahinter: „Heute · 7 Übungen · ca.
  /// 70 min". Der Stand steht vorn, weil er die Frage beantwortet, mit
  /// der man den Schirm aufmacht.
  final String untertitel;

  @override
  bool operator ==(Object other) =>
      other is HeuteTrainingZeile &&
      other.titel == titel &&
      other.untertitel == untertitel;

  @override
  int get hashCode => Object.hash(titel, untertitel);

  @override
  String toString() => 'HeuteTrainingZeile($titel / $untertitel)';
}

/// Die Zeile zu einem Tageszustand — reine Funktion, ohne Widget prüfbar.
///
/// [heute] ist der Berliner Tagesbeginn aus `heutigerTagProvider`. Er
/// wird gebraucht, um einen heute abgeschlossenen Platz von einem der
/// Vortage zu unterscheiden.
///
/// **Fünf Fälle, vier davon aus [GymFocus].** Der fünfte ist „heute schon
/// trainiert": Der Kern lässt den Fokus dann auf [Rest] fallen (siehe
/// `GymDayPlanner.day`, der Tagesplatz wird übersprungen, sobald er
/// erledigt ist), und ohne diesen Zweig spränge der Abschnitt nach dem
/// Training auf „Ruhetag" um — der Abend sähe aus wie ein Tag, an dem
/// nichts geplant war.
HeuteTrainingZeile heuteTrainingZeile(GymTag tag, {required DateTime heute}) {
  final focus = tag.tag.focus;
  return switch (focus) {
    // Die Erholung nach einer OP geht allem vor, wie im Kern.
    Recovery() => const HeuteTrainingZeile(
      titel: 'Kein Krafttraining',
      untertitel: 'Pause · erst nach ärztlicher Freigabe',
    ),
    InProgress(
      :final workout,
      :final trainingName,
      :final done,
      :final total,
    ) =>
      HeuteTrainingZeile(
        titel: workout == null ? (trainingName ?? 'Training') : _titel(workout),
        untertitel:
            'Angefangen · ${gymFokusFortschrittText(done: done, total: total)}',
      ),
    Planned(:final workout) => HeuteTrainingZeile(
      titel: _titel(workout),
      untertitel: 'Heute · ${_umfang(workout)}',
    ),
    Rest() => switch (heuteErledigtesWorkout(tag.tag, heute: heute)) {
      final Workout workout => HeuteTrainingZeile(
        titel: _titel(workout),
        untertitel: 'Erledigt · ${_umfang(workout)}',
      ),
      _ => const HeuteTrainingZeile(
        titel: 'Ruhetag',
        untertitel: 'Heute kein Gym · Spaziergang und Mobility',
      ),
    },
  };
}

/// Das Workout, dessen Platz **heute** abgeschlossen wurde — `null`, wenn
/// keines.
///
/// Verglichen wird mit [Done.date], und das ist laut seinem
/// Doc-Kommentar der Berliner Tagesbeginn des Abschlusses, nicht der rohe
/// Zeitstempel. Zwei Tagesbeginne sind genau dann gleich, wenn es
/// derselbe Kalendertag ist — hier wird deshalb nichts gerechnet,
/// sondern verglichen.
Workout? heuteErledigtesWorkout(GymDay tag, {required DateTime heute}) {
  final beginn = BerlinCalendar.startOfDay(heute);
  for (final platz in tag.week) {
    final status = platz.status;
    if (status is Done && status.date == beginn) return platz.workout;
  }
  return null;
}

/// „Push — Brust, Schultern, Trizeps", wie auf dem Gym-Schirm.
String _titel(Workout workout) => '${workout.label} — ${workout.title}';

/// „7 Übungen · ca. 70 min" — der Umfang aus dem Katalog, nicht geraten.
///
/// **Ohne die Sätze**, anders als der Untertitel der Fokus-Karte: Hier
/// steht der Stand davor, und drei Angaben hinter ihm brächen die Zeile
/// auf Gerätebreite um.
String _umfang(Workout workout) =>
    '${ExerciseCatalog.exercisesFor(workout).length} Übungen · '
    'ca. ${workout.minutes} min';

/// Gruppenkopf und Karte zusammen — dieselbe Bauart wie der
/// Erholungsblock darunter.
///
/// **Eine Zeile, eine Form — in jedem Zustand.** Dasselbe Symbol,
/// dieselbe Kachelfarbe, dieselbe Tür; nur Titel und Untertitel wechseln.
/// Es gibt **keine Wertspalte**: „Starten" rechts stünde im Ruhetag vor
/// dem Nichts, und eine Spalte, die mal da ist und mal nicht, nähme dem
/// Untertitel daneben Platz weg.
///
/// **Die Kachel bleibt [Palette.iron], auch am Ruhetag.**
/// [gymFokusAkzent] gäbe dort `Palette.rest` — ein sehr helles Grau, auf
/// dem das weiße Symbol verschwände. Auf dem Gym-Schirm trägt die
/// Fokus-Karte diesen Ton großflächig; hier sagt das Symbol, zu welchem
/// Abschnitt die Zeile gehört, nicht wie der Tag läuft. Den Zustand trägt
/// der Text. *(Entscheidung des umsetzenden Agenten, nicht Tims — im
/// Entwurf nachgezogen.)*
///
/// **Die Tür führt auf den Gym-Tab**, nicht ins Erfassen: Sie ist in
/// jedem Zustand dieselbe, auch am Ruhetag und nach der OP. Eine Tür, die
/// mit der Datenlage kommt und geht, ändert die Breite des Untertitels
/// daneben — und das Erfassen beginnt auf dem Gym-Schirm ohnehin mit
/// einem Knopf, der sagt, was er tut.
///
/// `router` `null` heißt „keine Tür" — dieselbe Regel wie bei der
/// Erholungskarte: ohne Router kein Ziel, und ein Winkel ohne Ziel ist
/// genau der Fehler, den `docs/screens/pruefen.mjs` sucht.
class HeuteTraining extends StatelessWidget {
  const HeuteTraining({
    super.key,
    required this.tag,
    required this.heute,
    this.router,
  });

  final GymTag tag;

  /// Der Berliner Tagesbeginn aus `heutigerTagProvider`.
  final DateTime heute;

  final AppRouter? router;

  @override
  Widget build(BuildContext context) {
    final zeile = heuteTrainingZeile(tag, heute: heute);
    final router = this.router;
    final aufGym = router == null ? null : () => router.open(AppTarget.gym());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // **Der Kopf trägt keinen Verweis** (#516, Tim am 16.11.2026).
        // Die Tür zum Gym-Tab bleibt — sie liegt auf der Karte darunter
        // (`onTap: aufGym`), und deren Chevron zeigt sie an.
        const SectionHeader('Heute Training'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: KachelKarte(
            child: IconRow(
              symbol: 'dumbbell.fill',
              accent: CupertinoDynamicColor.resolve(Palette.iron, context),
              big: true,
              title: zeile.titel,
              subtitle: zeile.untertitel,
              // Eine Zeile Titel, zwei Zeilen Untertitel — fest. Der
              // Untertitel schwankt zwischen „Heute · 7 Übungen · ca.
              // 70 min" und „Heute kein Gym · Spaziergang und
              // Mobility"; ohne reservierte Höhe wüchse die Karte am
              // Ruhetag, und alles darunter rutschte.
              titelZeilen: 1,
              untertitelZeilen: 2,
              // Solange eine Quelle noch kein Ergebnis hat, ist „Ruhetag"
              // eine Behauptung über Daten, die niemand gelesen hat
              // (Fehler `01`). Dann steht dieselbe Zeile als Form da.
              laedt: tag.laedt,
              onTap: aufGym,
            ),
          ),
        ),
      ],
    );
  }
}
