// Was der Erfassen-Schirm und das Vollbild **ablesen** (#78): Fortschritt,
// Satzbilanz, die Übungen mit ihren Zeilen und die Übung, in der man gerade
// ist. Alles abgeleitet aus [gymLogProvider] und [gymVorschlagProvider],
// **gehalten** und nicht je Bild gerechnet (Hausregel 2, Fehler `03`).
//
// **Ein fehlender Wert ist `null`, nicht `0`** (`CLAUDE.md`: „`0` ist keine
// Antwort auf ‚kein Wert‘"). Solange der Entwurf gelesen wird
// ([GymLogStand.laedt]), tragen [GymFortschritt] und die Bilanz **keine
// Zahl** — „0 / 21 Sätze" hieße „nichts getan" und wäre Fehler `01` in neuer
// Verpackung. Das ist keine Regel für den Schirm, die er befolgen kann oder
// nicht, sondern eine Form des Werts: Eine Null lässt sich dort nicht
// hinschreiben.
//
// **Jeder dieser Provider hängt über `select` nur an dem Ausschnitt des
// Standes, den er braucht.** Tippen in die Notiz rechnet keine Bilanz neu,
// Tippen in Übung 3 rechnet Übung 5 nicht neu, und der Takt der Pausenuhr
// ist nirgends beteiligt (`gym_pause_provider.dart`).
//
// **Keine Texte** — die stehen in `gym_log_texte.dart`.
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import 'gym_log_entwurf.dart';
import 'gym_log_provider.dart';
import 'gym_verlauf_provider.dart';

/// „14 von 21 Sätzen" — **gezählt werden Sätze, nicht Übungen** (Tim,
/// 10.11.2026, löst #26: bei sieben Übungen sind das sieben Sprünge in
/// 50 Minuten, die meiste Zeit passiert nichts).
///
/// [fertig] zählt die Zeilen, die **zählen** — nach derselben Regel, nach
/// der abgelegt wird (Spec 3.8). [gesamt] sind alle Zeilen auf dem Schirm;
/// er wächst mit „+ Satz".
///
/// **Beide sind `null`, solange der Entwurf gelesen wird.** Der Schirm
/// zeichnet dann Balken und Zahl als graue Formen derselben Breite
/// (Spec 14).
///
/// **Werttyp mit [==] und [hashCode] über alle Felder** (Fehler `03`).
@immutable
class GymFortschritt {
  const GymFortschritt({required this.fertig, required this.gesamt});

  /// Noch nicht gelesen.
  const GymFortschritt.laedt() : fertig = null, gesamt = null;

  final int? fertig;
  final int? gesamt;

  bool get laedt => fertig == null;

  /// Der Füllstand des Balkens von 0 bis 1, `null` beim Laden. Ein Balken
  /// bei 0 ist die richtige Antwort auf „noch nichts" — **nicht** auf „noch
  /// nicht gelesen".
  double? get anteil {
    final f = fertig;
    final g = gesamt;
    if (f == null || g == null) return null;
    return g == 0 ? 0 : f / g;
  }

  @override
  bool operator ==(Object other) =>
      other is GymFortschritt &&
      other.fertig == fertig &&
      other.gesamt == gesamt;

  @override
  int get hashCode => Object.hash(fertig, gesamt);

  @override
  String toString() =>
      laedt ? 'GymFortschritt(lädt)' : 'GymFortschritt($fertig / $gesamt)';
}

/// Die Satzbilanz — „6 Sätze · 2.410 kg Volumen" —, **`null` beim Laden**.
///
/// „0 Sätze · 0 kg Volumen" ist **kein** verbotener Nullwert (Spec 14): Es
/// ist die richtige Antwort auf „wie viel habe ich bisher heute gehoben",
/// sobald der Entwurf gelesen ist. Verboten ist die Null, die entsteht,
/// weil er noch nicht gelesen wurde — und die gibt es hier nicht.
///
/// Entsteht, indem der Entwurf durch `GymSessionBuilder.session`
/// geschickt wird (Spec 3.8): **Eine Rechnung, eine Zahl.** Das Volumen ist
/// `ImportedSession.volumeKg`, nicht Swifts eigene Rechnung im Entwurf.
final gymBilanzProvider = Provider.family<GymBilanz?, TrainingKey>((
  ref,
  workout,
) {
  final laedt = ref.watch(gymLogProvider(workout).select((s) => s.laedt));
  if (laedt) return null;
  final uebungen = ref.watch(
    gymLogProvider(workout).select((s) => s.entwurf.uebungen),
  );
  // **Die Bilanz zählt, was abgelegt wird** (Spec 3.8) — und ein leeres
  // Gewichtsfeld heißt „wie letztes Mal" (Tim, 10.11.2026). Solange der
  // Verlauf noch gelesen wird, steht die Zahl noch nicht fest: Sie wäre
  // sonst erst mit 0 kg gerechnet und spränge. Ist er gescheitert, gibt es
  // keinen Platzhalter und also nichts zu übernehmen.
  final verlauf = ref.watch(gymVerlaufProvider);
  if (verlauf.laedt) return null;
  return GymLogEntwurf.bilanzVon(
    GymLogEntwurf.uebernommen(uebungen, letzteSaetzeVon(verlauf)),
  );
});

/// Je Übung die Sätze der jüngsten Sitzung — die Platzhalter. Leer, solange
/// der Verlauf nicht bekannt ist.
Map<String, List<CompletedSet>> letzteSaetzeVon(GymVerlauf verlauf) {
  if (!verlauf.bekannt) return const {};
  return {
    for (final eintrag in verlauf.verlauf.entries)
      if (eintrag.value.isNotEmpty) eintrag.key: eintrag.value.first,
  };
}

/// Der Fortschritt, gehalten. Siehe [GymFortschritt].
///
/// Hängt **nicht** am Verlauf: Wie viele Sätze zählen, hängt nur an den
/// Wiederholungen, nicht am Gewicht.
final gymFortschrittProvider = Provider.family<GymFortschritt, TrainingKey>((
  ref,
  workout,
) {
  final laedt = ref.watch(gymLogProvider(workout).select((s) => s.laedt));
  if (laedt) return const GymFortschritt.laedt();
  final uebungen = ref.watch(
    gymLogProvider(workout).select((s) => s.entwurf.uebungen),
  );
  return GymFortschritt(
    fertig: GymLogEntwurf.bilanzVon(uebungen).saetze,
    gesamt: uebungen.fold<int>(0, (summe, u) => summe + u.saetze.length),
  );
});

/// Der Index der Übung, in der man gerade ist: die **erste noch nicht
/// erledigte** (Spec 4.3, 7.1). Dort geht das Vollbild auf und dort steht
/// die Pausenzeile — es ist dieselbe Zahl, und sie wird nur hier gerechnet.
///
/// `null`, solange der Entwurf gelesen wird: Das Vollbild öffnet dann noch
/// nirgends.
final gymAktuelleUebungProvider = Provider.family<int?, TrainingKey>((
  ref,
  workout,
) {
  final laedt = ref.watch(gymLogProvider(workout).select((s) => s.laedt));
  if (laedt) return null;
  return ref.watch(
    gymLogProvider(workout).select((s) => s.entwurf.ersteOffeneUebung),
  );
});

/// Schlüssel einer Übung innerhalb eines Trainings. Ein Record hat
/// Wertgleichheit; zwei Aufrufer, die ihn getrennt bauen, treffen
/// denselben Provider.
typedef GymUebungSchluessel = ({TrainingKey workout, String uebungId});

/// Eine Zeile der Übungskarte, fertig zum Zeichnen.
///
/// **Werttyp mit [==] und [hashCode] über alle Felder** (Fehler `03`).
@immutable
class GymSatzAnsicht {
  const GymSatzAnsicht({
    required this.gewicht,
    required this.wdh,
    required this.zaehlt,
    required this.entfernbar,
    required this.vorher,
  });

  /// Der Text im Gewichtsfeld, so wie getippt.
  final String gewicht;

  /// Der Text im Wiederholungsfeld, so wie getippt.
  final String wdh;

  /// Ob der Satz zählt — dann steht der Haken, sonst das Minus (Spec 3.5).
  /// **Dieselbe Regel wie die Ablage** (`GymLogEntwurf.satzZaehlt`).
  final bool zaehlt;

  /// Ob das Minus drückbar ist: nicht die letzte Zeile, und nur, solange die
  /// Zeile leer ist.
  final bool entfernbar;

  /// Der Satz mit demselben Index aus dem **letzten Training**: Platzhalter
  /// und Vergleichswert. `null` ohne Verlauf, bei weniger Sätzen damals —
  /// dann steht „–" — **und solange der Verlauf nicht bekannt ist**
  /// ([GymVorschlag.laedt]; der Schirm zeigt dann gar nichts).
  final CompletedSet? vorher;

  @override
  bool operator ==(Object other) =>
      other is GymSatzAnsicht &&
      other.gewicht == gewicht &&
      other.wdh == wdh &&
      other.zaehlt == zaehlt &&
      other.entfernbar == entfernbar &&
      other.vorher == vorher;

  @override
  int get hashCode => Object.hash(gewicht, wdh, zaehlt, entfernbar, vorher);

  @override
  String toString() =>
      'GymSatzAnsicht("$gewicht" × "$wdh", zählt: $zaehlt, vorher: $vorher)';
}

/// Eine Übungskarte: Katalogeintrag, Zeilen, Schalter und Vorschlag.
///
/// **Werttyp mit [==] und [hashCode] über alle Felder** (Fehler `03`).
@immutable
class GymUebung {
  const GymUebung({
    required this.uebung,
    required this.laedt,
    required this.saetze,
    required this.unterstuetzt,
    required this.erledigt,
    required this.verlauf,
  });

  final Exercise uebung;

  /// Der **Entwurf** wird noch gelesen: [saetze] sind dann nur die leeren
  /// Zeilen in der Geometrie des Workouts, und der Schirm bietet keine
  /// Felder an (Spec 9.3). Der **Verlauf** hat sein eigenes Feld in
  /// [verlauf].
  final bool laedt;

  /// Die Zeilen. **Immer mindestens eine.**
  final List<GymSatzAnsicht> saetze;

  /// „Unterstützung" an. Der Umschalter steht nur bei
  /// [Exercise.allowsAssist]; bei den anderen ist das hier `false`.
  final bool unterstuetzt;

  /// Alle Zeilen zählen — die Übung darf zuklappen (Spec 3.4). `false`, solange
  /// der Entwurf gelesen wird.
  final bool erledigt;

  /// Vorschlag und Sätze vom letzten Mal — `GymVorschlag.vorschlag` ist
  /// `null`, solange der Verlauf nicht bekannt ist.
  final GymVorschlag verlauf;

  /// Zeitübung: Das Gewichtsfeld ist gesperrt, die zweite Spalte heißt
  /// „Sek." (Spec 8.2).
  bool get istZeit => uebung.isTimed;

  @override
  bool operator ==(Object other) =>
      other is GymUebung &&
      other.uebung == uebung &&
      other.laedt == laedt &&
      other.unterstuetzt == unterstuetzt &&
      other.erledigt == erledigt &&
      other.verlauf == verlauf &&
      _gleicheZeilen(other.saetze, saetze);

  @override
  int get hashCode => Object.hash(
    uebung,
    laedt,
    unterstuetzt,
    erledigt,
    verlauf,
    Object.hashAll(saetze),
  );

  @override
  String toString() =>
      'GymUebung(${uebung.id}, ${saetze.length} Zeilen, erledigt: $erledigt)';
}

/// Eine Übungskarte, gehalten. Hängt nur an **dieser** Übung im Entwurf, am
/// Ladefeld und am Verlauf dieser Übung.
///
/// Eine Übung, die nicht zum Workout gehört, gibt es nicht; der Aufruf ist
/// dann ein Programmierfehler und wirft.
final gymUebungProvider = Provider.family<GymUebung, GymUebungSchluessel>((
  ref,
  schluessel,
) {
  final (:workout, :uebungId) = schluessel;
  final laedt = ref.watch(gymLogProvider(workout).select((s) => s.laedt));
  final zeilen = ref.watch(
    gymLogProvider(workout).select((s) => s.entwurf.uebung(uebungId)),
  );
  if (zeilen == null) {
    throw ArgumentError.value(
      uebungId,
      'uebungId',
      'gehört nicht zu ${workout.id}',
    );
  }
  // **Der Bereich des Trainings, nicht der des Katalogs** (Spec 15.2): Die
  // Übung kommt aus der Definition des Trainings; nur wo es keine gibt,
  // gilt der Katalog.
  final geplant = ref.watch(
    gymLogProvider(workout).select(
      (s) => s.training?.exercises
          .where((e) => e.exerciseId == uebungId)
          .firstOrNull,
    ),
  );
  final uebung = geplant?.resolve() ?? ExerciseLibrary.byId(uebungId)!;
  final verlauf = ref.watch(gymVorschlagProvider(uebung));

  return GymUebung(
    uebung: uebung,
    laedt: laedt,
    saetze: [
      for (var i = 0; i < zeilen.saetze.length; i++)
        GymSatzAnsicht(
          gewicht: zeilen.saetze[i].weight,
          wdh: zeilen.saetze[i].reps,
          zaehlt:
              !laedt &&
              GymLogEntwurf.satzZaehlt(
                zeilen.saetze[i],
                uebungId: uebungId,
                unterstuetzt: zeilen.unterstuetzt,
              ),
          entfernbar: !laedt && zeilen.zeileEntfernbar(i),
          vorher: i < verlauf.letzteSaetze.length
              ? verlauf.letzteSaetze[i]
              : null,
        ),
    ],
    unterstuetzt: zeilen.unterstuetzt,
    erledigt: !laedt && GymLogEntwurf.uebungErledigt(zeilen),
    verlauf: verlauf,
  );
});

bool _gleicheZeilen(List<GymSatzAnsicht> a, List<GymSatzAnsicht> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
