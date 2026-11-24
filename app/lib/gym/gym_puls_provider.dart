// Der Puls einer Gym-Sitzung (#512) — was `GymVerlaufView` in der offenen
// Karte als Pulsblock zeigt. Spec
// `docs/superpowers/specs/2026-11-16-gym-puls-design.md`, Abschnitte 3, 5
// und 8.
//
// **Abgeleitet aus Apple Health, also ein `Messwert<GymPuls>`** mit den vier
// Zuständen (`CLAUDE.md`, Hausregel 1): Die Umsetzung `AsyncValue` →
// `Messwert` steht in `alsMesswert`, hier nirgends sonst.
//
// **Eine Lesung je Sitzung, zwei Kanalaufrufe:** `workouts` für den
// Berliner Tag der Sitzung, danach `quantitySamples` für **genau das
// gefundene Training** (Beginn bis Beginn plus Dauer). Gibt es kein
// passendes Training, gibt es keine zweite Abfrage — der Puls eines anderen
// Trainings wäre falsch. Die Rechnungen stehen im Kern (`GymWorkoutMatch`,
// `GymPulse`, `SpanBuckets`); hier wird nur der Transporttyp des Kanals auf
// die Typen des Kerns abgebildet.
//
// **Gelesen wird nur für geöffnete Karten:** Der Provider entsteht erst, wenn
// der Inhalt einer Karte einen Leser hat. Er hängt **nicht** an
// `gymSitzungenProvider` — ein neu abgelegtes Training dürfte sonst den Puls
// aller offenen Karten neu lesen.
//
// **Gehalten, nicht je Bild gerechnet** (Hausregel 2): kein `autoDispose`,
// der Schlüssel ist die Sitzung (Werttyp mit `==`). Auf- und Zuklappen löst
// keine Lesung aus.
//
// **Wiederlesen (Spec 8):**
//
// - Ein `Bekannt` wird in dieser Sitzung der App nicht erneut gelesen. Ein
//   Training von gestern ändert seinen Puls nicht.
// - Ein Ergebnis ohne Puls (`LeerNachLauf`, `Fehlgeschlagen`) wird erneut
//   gelesen, sobald der Provider wieder einen Leser bekommt: Die Uhr
//   synchronisiert nach. Bis die neue Antwort da ist, **bleibt das alte
//   Ergebnis stehen** — Riverpod hält den vorigen Wert während des
//   Neuladens, und der Platzhalter gehört allein in `NochNie`.
// - Die Freigabe wird beobachtet ([freigabeProvider]): Antwortet der Nutzer
//   auf den Dialog, nachdem der erste, leere Lauf lief, liest er neu.
//
// **Ein gescheiterter Nachlauf nimmt keinen sichtbaren Wert weg:** Der
// letzte gelesene Puls geht als `cache` in `alsMesswert`.
//
// **Auch ein nicht lesbarer `healthProvider` ist `Fehlgeschlagen`**, nicht
// `NochNie`: Wirft schon das Auflösen (ohne Override tut er es), steht
// sofort ein Ergebnis da, kein Platzhalter, der nie weicht.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Der Kern hat seit #95 eigene, schlanke Workout-Typen für die
// Zonen-Rechnung (zone_distribution.dart). Hier sind die Kanal-Typen aus
// health_types.dart gemeint — die Kern-Namen bleiben draußen.
import 'package:trainings_core/trainings_core.dart'
    hide WorkoutKind, WorkoutSample;

import '../core/async_bruecke.dart';
import '../core/messwert.dart';
import '../health/health_provider.dart';
import '../health/health_reading.dart';
import '../health/health_types.dart';

/// Der Abschnitt einer Übung im Training und der Ø-Puls darin.
///
/// Werttyp mit `==` und `hashCode` (Fehler `03`).
@immutable
class GymPulsAbschnitt {
  const GymPulsAbschnitt({required this.abschnitt, required this.durchschnitt});

  final GymExerciseSection abschnitt;

  /// Ø der Stichproben im Abschnitt — **`null`, wenn keine darin liegt**,
  /// nie `0`: Die Übung hat stattgefunden, nur der Puls fehlt dort.
  final double? durchschnitt;

  @override
  bool operator ==(Object other) =>
      other is GymPulsAbschnitt &&
      other.abschnitt == abschnitt &&
      other.durchschnitt == durchschnitt;

  @override
  int get hashCode => Object.hash(abschnitt, durchschnitt);
}

/// Der Puls einer Sitzung: das Fenster des Apple-Trainings, die Spannen,
/// die Zahlen der Kopfzeile und die Abschnitte der Übungen.
///
/// **Nie leer:** Es gibt ihn nur, wenn mindestens eine Stichprobe im Fenster
/// liegt — sonst ist der Zustand `LeerNachLauf`.
///
/// Werttyp mit `==` und `hashCode` über alle Felder (Fehler `03`).
@immutable
class GymPuls {
  const GymPuls({
    required this.von,
    required this.bis,
    required this.spannen,
    required this.mittelwerte,
    required this.zusammenfassung,
    required this.abschnitte,
  });

  /// Beginn und Ende des Apple-Trainings, **Zeitpunkte** — in der Zeitzone,
  /// in der der Kanal sie lieferte. Verglichen wird nie mit `==`.
  final DateTime von;
  final DateTime bis;

  /// Die Spannen, ein Abschnitt ohne Stichprobe als `ValueSpan.empty`.
  final List<ValueSpan> spannen;

  /// Der Mittelwert der Stichproben je Abschnitt — die Linie über der
  /// Fläche der [spannen] (#515). **Gleiche Länge, gleiche Reihenfolge**;
  /// `null` an genau den Stellen, an denen die Spanne leer ist, nie `0`.
  /// Aus `SpanBuckets.means`, das dieselben Grenzen benutzt wie `spans`.
  final List<double?> mittelwerte;

  /// Ø, Min und Max über das ganze Training — aus den Stichproben, nicht
  /// aus Apples Statistik (Spec 6, Entscheidung 1).
  final PulseSummary zusammenfassung;

  /// Nur Übungen mit erfassten Satz-Uhrzeiten; leer bei allem Übernommenen.
  final List<GymPulsAbschnitt> abschnitte;

  /// Der Abschnitt der Übung an [position] (ab 1), oder `null`.
  GymPulsAbschnitt? abschnittAn(int position) {
    for (final a in abschnitte) {
      if (a.abschnitt.position == position) return a;
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is GymPuls &&
      other.von == von &&
      other.bis == bis &&
      other.zusammenfassung == zusammenfassung &&
      listEquals(other.spannen, spannen) &&
      listEquals(other.mittelwerte, mittelwerte) &&
      listEquals(other.abschnitte, abschnitte);

  @override
  int get hashCode => Object.hash(
    von,
    bis,
    zusammenfassung,
    Object.hashAll(spannen),
    Object.hashAll(mittelwerte),
    Object.hashAll(abschnitte),
  );
}

/// Der Puls **einer** Sitzung, gehalten (siehe Dateikopf).
final gymPulsProvider =
    AsyncNotifierProvider.family<
      GymPulsNotifier,
      Messwert<GymPuls>,
      ImportedSession
    >(GymPulsNotifier.new);

/// Übersetzt den äußeren `AsyncValue` für die Oberfläche — dasselbe Muster
/// wie `nachtVitalwerteAusProvider`, damit `AsyncValue` in der
/// Widget-Schicht nicht auftaucht.
///
/// **Während des Neuladens bleibt der vorige Wert stehen**
/// (`AsyncValue.value`); `NochNie` gilt allein, solange nie etwas da war.
Messwert<GymPuls> gymPulsAusProvider(AsyncValue<Messwert<GymPuls>> zustand) =>
    zustand.value ?? const NochNie<GymPuls>();

class GymPulsNotifier extends AsyncNotifier<Messwert<GymPuls>> {
  GymPulsNotifier(this.sitzung);

  final ImportedSession sitzung;

  /// Der letzte tatsächlich gelesene Puls — der `cache` von `alsMesswert`.
  /// Der Notifier überlebt das Neuladen; dieses Feld mit ihm.
  ({GymPuls wert, DateTime stand})? _zwischenspeicher;

  /// Das Ergebnis des letzten abgeschlossenen Laufs; `null`, solange einer
  /// läuft. Nur dafür da, beim Wiederkehren eines Lesers zu entscheiden.
  Messwert<GymPuls>? _ergebnis;

  /// Zählt die Läufe. Ein Lauf, den ein neuer überholt hat (die Freigabe
  /// wurde beantwortet), trägt sein Ergebnis nicht mehr ein.
  int _lauf = 0;

  @override
  FutureOr<Messwert<GymPuls>> build() {
    final lauf = ++_lauf;
    _ergebnis = null;

    // Beobachtet, nicht nur gelesen: Der Lauf vor der Antwort auf den
    // Dialog kam ohne Lesefreigabe leer zurück (#176).
    ref.watch(freigabeProvider);
    final uhr = ref.watch(clockProvider);

    // Ein Ergebnis ohne Puls wird erneut gelesen, sobald ein Leser
    // wiederkommt (Spec 8.2). Ein `Bekannt` nicht (8.1).
    //
    // **Nicht im Rückruf selbst:** Riverpod erlaubt dort keine Änderung an
    // Providern, und der Rückruf läuft, während der Leser sich noch
    // anmeldet. Der Mikrotask liegt dahinter; der Leser wird danach
    // benachrichtigt wie bei jeder anderen Änderung.
    ref.onResume(() {
      final ergebnis = _ergebnis;
      if (ergebnis is! LeerNachLauf<GymPuls> &&
          ergebnis is! Fehlgeschlagen<GymPuls>) {
        return;
      }
      scheduleMicrotask(() {
        if (ref.mounted) ref.invalidateSelf();
      });
    });

    final HealthReading quelle;
    try {
      quelle = ref.watch(healthProvider);
    } catch (fehler, stapel) {
      // Nicht lesbar heißt `Fehlgeschlagen`, sofort — nicht `NochNie`.
      return _abschliessen(AsyncError(fehler, stapel), uhr(), lauf);
    }
    return _lies(quelle, uhr, lauf);
  }

  Future<Messwert<GymPuls>> _lies(
    HealthReading quelle,
    DateTime Function() uhr,
    int lauf,
  ) async {
    AsyncValue<GymPuls?> ergebnis;
    try {
      ergebnis = AsyncData(await _hole(quelle));
    } catch (fehler, stapel) {
      ergebnis = AsyncError(fehler, stapel);
    }
    return _abschliessen(ergebnis, uhr(), lauf);
  }

  /// `alsMesswert` — die eine Stelle (Hausregel 1).
  Messwert<GymPuls> _abschliessen(
    AsyncValue<GymPuls?> ergebnis,
    DateTime jetzt,
    int lauf,
  ) {
    final puls = ergebnis is AsyncData<GymPuls?> ? ergebnis.value : null;
    final messwert = alsMesswert<GymPuls>(
      ergebnis,
      cache: _zwischenspeicher,
      jetzt: jetzt,
      // Kein Training oder keine Stichprobe: Lauf fertig, nichts gefunden.
      istLeer: ergebnis is AsyncData<GymPuls?> && puls == null,
    );
    if (puls != null) _zwischenspeicher = (wert: puls, stand: jetzt);
    if (lauf == _lauf) _ergebnis = messwert;
    return messwert;
  }

  /// Die beiden Kanalaufrufe und die Rechnung. `null`: kein Krafttraining
  /// an dem Tag, oder eines ohne Stichprobe.
  Future<GymPuls?> _hole(HealthReading quelle) async {
    // Der Berliner Tag der Sitzung: bei Übernommenem der Tagesbeginn als UTC
    // (09.03. Berlin = 08.03., 23:00 UTC), bei Eigenem der Abschluss. Wer
    // `date.day` läse, träfe beim Übernommenen den Vortag.
    final tag = BerlinCalendar.startOfDay(sitzung.date);
    final trainings = await quelle.workouts(tag, tag);

    final index = GymWorkoutMatch.matchIndex(
      day: tag,
      // Der Index gilt für `trainings`, so wie sie übergeben wurde.
      workouts: [
        for (final t in trainings)
          (
            start: t.start,
            isStrength: t.kind == WorkoutKind.strength,
            minutes: t.minutes,
          ),
      ],
    );
    if (index == null) return null;

    final training = trainings[index];
    final von = training.start;
    final bis = von.add(
      Duration(microseconds: (training.minutes * 60000000).round()),
    );
    // Ein Training ohne Dauer hat kein Fenster, in dem Stichproben liegen
    // könnten — `SpanBuckets` würfe, und es ist eine Datenlage.
    if (!bis.isAfter(von)) return null;

    final proben = await quelle.quantitySamples(VitalKind.heartRate, von, bis);
    final stichproben = [
      for (final p in proben) ChartSample(date: p.date, value: p.value),
    ];

    final zusammenfassung = GymPulse.summary(
      samples: stichproben,
      from: von,
      to: bis,
    );
    if (zusammenfassung == null) return null;

    final abschnittszahl = GymPulse.bucketCount(minutes: training.minutes);
    return GymPuls(
      von: von,
      bis: bis,
      spannen: SpanBuckets.spans(
        samples: stichproben,
        from: von,
        to: bis,
        sectionCount: abschnittszahl,
      ),
      mittelwerte: SpanBuckets.means(
        samples: stichproben,
        from: von,
        to: bis,
        sectionCount: abschnittszahl,
      ),
      zusammenfassung: zusammenfassung,
      abschnitte: [
        for (final a in GymPulse.sections(session: sitzung, from: von, to: bis))
          GymPulsAbschnitt(
            abschnitt: a,
            durchschnitt: GymPulse.summary(
              samples: stichproben,
              from: a.start,
              to: a.end,
            )?.avg,
          ),
      ],
    );
  }
}
