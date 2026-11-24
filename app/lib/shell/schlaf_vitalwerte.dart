// Puls und Atmung einer Nacht (#92) — die Min-Max-Spannen, der Provider,
// der sie beim Blättern nachlädt und gemerkt hält, und die eigenen
// Bezugswerte für die Linien darin (#157). Gezeichnet wird in
// `schlaf_spannen.dart`.
//
// **Nachgeladene Werte und Bezugswerte stehen zusammen**, weil beide
// dasselbe Diagramm versorgen und beide am Fenster der Nacht hängen statt
// an `SchlafDaten` — zwei Dateien hätten denselben Satz Begründungen
// zweimal getragen.
//
// Herausgelöst aus `schlaf_zustand.dart` (#158, 29.10.2026, 1002 Zeilen
// waren es vorher). **Die festgelegte API bleibt
// `import '…/shell/schlaf_zustand.dart'`** — die Fassade exportiert diese
// Datei weiter. Tim hat „aufteilen" verlangt; wo der Schnitt liegt, hat
// der umsetzende Agent entschieden.
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../core/async_bruecke.dart';
import '../core/messwert.dart';
import '../health/health_provider.dart';
import '../health/health_types.dart';
import 'erholung_zustand.dart' show ErholungDaten, erholungProvider;
import 'schlaf_minuten.dart';

/// Acht Abschnitte je Nacht — so viele Spannen zeigt der Entwurf
/// (`minMaxChart` in `docs/screens/components.js`, benutzt von `PULS` und
/// `ATMUNG` in `docs/screens/screens/schlaf.js`).
///
/// **Eine feste Zahl, keine feste Länge** (#148): Die Fläche, auf die
/// gezeichnet wird, ist fest und wird durch die Abschnittszahl geteilt.
/// Eine feste Abschnitts*länge* gäbe bei fünf Stunden fünf breite und bei
/// neun Stunden neun schmale Kapseln — also genau die Schwankung, deren
/// Extremfall das Ticket ist. Bis zum 28.10.2026 standen hier 16
/// Abschnitte, und gezeichnet wurde trotzdem jede Einzelmessung.
const int schlafSpannenAbschnitte = 8;

/// Die Min-Max-Spannen einer Nacht — Min und Max je Abschnitt, keine Linie.
///
/// **Die Rechnung liegt im Kern** (`SpanBuckets`); hier wird nur der
/// Transporttyp des Kanals auf den Werttyp des Kerns abgebildet.
/// `QuantitySample` ist die Nutzlast des Platform-Channels und trägt keine
/// Rechnung (`CLAUDE.md`, „Transporttypen gehören nicht in den Kern").
///
/// Ein Fenster ohne Dauer gibt nichts zurück, statt zu werfen: Dass eine
/// Nacht kein Fenster hat, ist eine Datenlage und kein Programmierfehler —
/// anders als ein unmöglicher Zuschnitt, den [SpanBuckets.spans] meldet.
List<ValueSpan> schlafSpannen({
  required List<QuantitySample> werte,
  required DateTime von,
  required DateTime bis,
  int abschnitte = schlafSpannenAbschnitte,
}) {
  if (!bis.isAfter(von)) return const [];
  return SpanBuckets.spans(
    samples: [
      for (final wert in werte) ChartSample(date: wert.date, value: wert.value),
    ],
    from: von,
    to: bis,
    sectionCount: abschnitte,
  );
}

/// Puls und Atmung einer Nacht.
@immutable
class NachtVitalwerte {
  const NachtVitalwerte({required this.puls, required this.atmung});

  final List<ValueSpan> puls;
  final List<ValueSpan> atmung;

  bool get istLeer => puls.isEmpty && atmung.isEmpty;
}

/// Die Spannen **einer** Nacht, nachgeladen beim Blättern und gemerkt.
///
/// **Nicht `autoDispose`** — anders als [schlafAuswahlProvider]: Die
/// gewählte Nacht ist Ansichtszustand, die nachgeladenen Spannen sind
/// Daten. Wer zweimal auf dieselbe Nacht blättert, soll nicht zweimal
/// warten (Entwurf 13.10.2026, „Der Vitalwerte-Cache").
final nachtVitalwerteProvider =
    AsyncNotifierProvider.family<
      NachtVitalwerteNotifier,
      Messwert<NachtVitalwerte>,
      DateTime
    >(NachtVitalwerteNotifier.new);

/// Fragt den Kanal nach Puls und Atemfrequenz im Fenster der Nacht [datum].
///
/// Das Fenster kommt aus [sleepProvider] und nicht als zweiter
/// Familienschlüssel: Zwei Wahrheiten über dasselbe Fenster liefen
/// auseinander, sobald der Kanal eine Nacht neu liefert.
class NachtVitalwerteNotifier extends AsyncNotifier<Messwert<NachtVitalwerte>> {
  NachtVitalwerteNotifier(this.datum);

  /// Der Tag der Nacht — `SleepNight.date`, also der Tag des Aufwachens.
  final DateTime datum;

  @override
  Future<Messwert<NachtVitalwerte>> build() async {
    final quelle = ref.watch(healthProvider);
    final uhr = ref.watch(clockProvider);
    final naechte = await ref.watch(sleepProvider.future);

    final liste = naechte is Bekannt<List<SleepNight>>
        ? naechte.wert
        : const <SleepNight>[];
    SleepNight? nacht;
    for (final kandidat in liste) {
      if (kandidat.date == datum) nacht = kandidat;
    }

    final jetzt = uhr();
    final (von, bis) = nacht == null
        ? (null, null)
        : schlafFensterVon(nacht.session);
    if (von == null || bis == null) {
      // Kein Fenster heißt: Es gibt nichts zu fragen. Das ist ein fertiger
      // Lauf ohne Ergebnis, kein gescheiterter.
      return LeerNachLauf<NachtVitalwerte>(gelaufen: jetzt);
    }

    AsyncValue<NachtVitalwerte> ergebnis;
    try {
      final puls = await quelle.quantitySamples(VitalKind.heartRate, von, bis);
      final atmung = await quelle.quantitySamples(
        VitalKind.respiratoryRate,
        von,
        bis,
      );
      ergebnis = AsyncData(
        NachtVitalwerte(
          puls: schlafSpannen(werte: puls, von: von, bis: bis),
          atmung: schlafSpannen(werte: atmung, von: von, bis: bis),
        ),
      );
    } catch (fehler, stapel) {
      ergebnis = AsyncError(fehler, stapel);
    }

    // `alsMesswert` ist die einzige Stelle, an der `AsyncValue` in
    // `Messwert` übergeht (Hausregel 1).
    return alsMesswert<NachtVitalwerte>(
      ergebnis,
      cache: null,
      jetzt: jetzt,
      istLeer: ergebnis is AsyncData<NachtVitalwerte>
          ? ergebnis.value.istLeer
          : false,
    );
  }
}

/// Übersetzt den äußeren `AsyncValue` für die Oberfläche — dasselbe Muster
/// wie [zieleAusProvider], damit `AsyncValue` in der Widget-Schicht nicht
/// auftaucht.
Messwert<NachtVitalwerte> nachtVitalwerteAusProvider(
  AsyncValue<Messwert<NachtVitalwerte>> zustand,
) => zustand.value ?? const NochNie<NachtVitalwerte>();

/// Die eigenen Vergleichswerte für die Bezugslinien der Spannen-Diagramme
/// (#157): Ruhepuls und Normalwert der Atemfrequenz.
///
/// **Keine neuen Zahlen.** Beide stehen schon im Zustand des
/// Erholung-Schirms — dieselben Mediane, die dort in den Verlaufszeilen
/// als „Median …" und „Normal …" stehen. Eine eigens für den Schlaf-Schirm
/// erfundene Zahl wäre die nächste, die auseinanderläuft.
///
/// **Ein eigener Provider und kein Feld an [SchlafDaten]**, aus demselben
/// Grund wie bei [schlafLagenProvider]: Die Bezugswerte hängen am Fenster
/// der letzten Wochen, nicht an der gezeigten Nacht. Gehalten statt bei
/// jedem Zugriff gerechnet (Hausregel 2); [RecoveryBaseline] trägt `==`,
/// also rechnet nichts nach, solange sich die Mediane nicht ändern.
///
/// Liegt noch nichts vor, bleiben die Felder `null` und die Linie fällt
/// weg — kein Rückfall auf einen Erfahrungswert.
final nachtBezugswerteProvider = Provider<RecoveryBaseline>((ref) {
  final daten = ref.watch(erholungProvider).daten;
  return daten is Bekannt<ErholungDaten>
      ? daten.wert.schnappschuss.baseline
      : const RecoveryBaseline();
});
