import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/core/messwert.dart';
import 'package:repit/data/ziele.dart';
import 'package:repit/design/segment_ring.dart';
import 'package:repit/health/health_provider.dart';
import 'package:repit/health/health_types.dart';
import 'package:repit/shell/diagramm_zeitraum.dart';
import 'package:repit/shell/schlaf_zustand.dart';

/// Tests für den **Zustand** des Schlaf-Schirms (#92) —
/// `lib/shell/schlaf_zustand.dart`. Die beiden Oberflächen liegen in
/// `schlaf_view_test.dart` und `tagschlaf_view_test.dart`.
///
/// Die Trennung ist dieselbe wie bei `erholung_zustand_test.dart` /
/// `erholung_view_test.dart` und aus demselben Grund: Zwischen Providern und
/// View gehört ein eigener Zustandstyp. Dann sind Score, Blättern,
/// Statistiken und Spannen ohne einen einzigen gepumpten Schirm prüfbar —
/// und der Schirm selbst muss nur noch beweisen, dass er die Zustände
/// auseinanderhält.
///
/// ## Festgelegte öffentliche API (`lib/shell/schlaf_zustand.dart`)
///
/// ```dart
/// // ── Die drei Teilnoten ───────────────────────────────────────────────
///
/// enum SchlafTeil { dauer, zubettgehzeit, unterbrechungen }
///
/// /// Die Gründe, aus denen eine Teilnote entfällt. Seit #131 zwei —
/// /// siehe `schlaf_teilnoten_ohne_phasen_test.dart`.
/// enum SchlafEntfallGrund { keineEinschlafzeit, keinePhasendaten }
///
/// @immutable
/// class SchlafTeilnote {
///   const SchlafTeilnote({
///     required SchlafTeil teil,
///     required int? punkte,              // null heißt „entfällt"
///     required int maximum,
///     required SchlafEntfallGrund? grund,
///   });
///   bool get entfaellt;                  // punkte == null
///   double get fuellung;                 // punkte/maximum, 0 wenn entfällt
/// }
///
/// /// Die drei Teilnoten eines Score, in fester Reihenfolge.
/// List<SchlafTeilnote> schlafTeilnoten(SleepScore score);
///
/// /// Die drei Ringabschnitte der Score-Karte — Anteile 50/30/20.
/// List<RingAbschnitt> schlafRingAbschnitte(List<SchlafTeilnote> teile);
///
/// // ── Blättern ─────────────────────────────────────────────────────────
///
/// enum SchlafBlaettern { frueher, spaeter }
///
/// /// Die gezeigte Nacht, aufgelöst gegen die geladene Reihe.
/// SleepNight? geloesteNacht({
///   required List<SleepNight> naechte,
///   required DateTime? gewaehlt,
/// });
///
/// /// Die Nachbarn der gezeigten Nacht; `null` heißt „am Rand".
/// ({DateTime? frueher, DateTime? spaeter}) schlafNachbarn({
///   required List<SleepNight> naechte,
///   required DateTime? gewaehlt,
/// });
///
/// // ── Statistiken ──────────────────────────────────────────────────────
///
/// @immutable
/// class SchlafStatistik {
///   const SchlafStatistik({
///     required int naechte,
///     required double schlafMinuten,         // Ø je Nacht
///     required double? einschlafMinuten,     // zirkulär, Skala EveningClock
///     required double? aufwachMinuten,
///     required Map<SleepStage, double> anteile,
///   });
/// }
///
/// /// Über die [tage] Nächte **bis einschließlich** [bis]. `null`, wenn
/// /// keine davon Schlaf enthält.
/// SchlafStatistik? schlafStatistik({
///   required List<SleepNight> naechte,
///   required DateTime bis,
///   required int tage,
/// });
///
/// /// Die beiden festen Zeiträume aus SPEC 4.6.
/// const int schlafStatistikKurz = 7;
/// const int schlafStatistikLang = 30;
///
/// /// Eine Uhrzeit der 18-Uhr-Skala als Wanduhrzeit.
/// ({int stunde, int minute}) wanduhrAusAbendminuten(double minuten);
///
/// // ── Verlauf ──────────────────────────────────────────────────────────
///
/// /// Die Schlafdauer je Nacht in **Stunden**, als Eingabe für
/// /// `diagrammPunkte` aus `lib/shell/diagramm_zeitraum.dart`.
/// List<({DateTime tag, double wert})> schlafTagewerte(
///   List<SleepNight> naechte,
/// );
///
/// /// Lage und Länge der letzten Nächte — der Abschnitt „Sieben Nächte".
/// @immutable
/// class SchlafNachtLage {
///   const SchlafNachtLage({
///     required DateTime datum,
///     required DateTime von,
///     required DateTime bis,
///     required Map<SleepStage, double> minutenJePhase,
///   });
/// }
///
/// List<SchlafNachtLage> schlafLetzteNaechte({
///   required List<SleepNight> naechte,
///   required DateTime bis,
///   int anzahl,
/// });
///
/// // ── Puls und Atmung ──────────────────────────────────────────────────
///
/// /// Acht Abschnitte je Nacht — so viele Spannen zeigt der Entwurf
/// /// (#148, Tims Befund vom 28.10.2026). Bis dahin standen hier 16.
/// const int schlafSpannenAbschnitte = 8;
///
/// /// Bildet die Nutzlast des Kanals auf `SpanBuckets` im Kern ab.
/// List<ValueSpan> schlafSpannen({
///   required List<QuantitySample> werte,
///   required DateTime von,
///   required DateTime bis,
///   int abschnitte,
/// });
///
/// @immutable
/// class NachtVitalwerte {
///   const NachtVitalwerte({
///     required List<ValueSpan> puls,
///     required List<ValueSpan> atmung,
///   });
///   bool get istLeer;
/// }
///
/// /// Die Spannen **einer** Nacht, nachgeladen beim Blättern und gemerkt.
/// final nachtVitalwerteProvider = AsyncNotifierProvider.family<
///     NachtVitalwerteNotifier, Messwert<NachtVitalwerte>, DateTime>(
///   NachtVitalwerteNotifier.new,
/// );
///
/// class NachtVitalwerteNotifier extends AsyncNotifier<Messwert<NachtVitalwerte>> {
///   NachtVitalwerteNotifier(this.datum);
///   final DateTime datum;
/// }
///
/// // ── Die gezeigte Nacht und der ganze Schirm ──────────────────────────
///
/// @immutable
/// class SchlafNacht {
///   const SchlafNacht({
///     required SleepNight nacht,
///     required RecoveryNight kern,
///     required SleepScore score,
///     required List<SchlafTeilnote> teilnoten,
///     required DateTime? von,          // Fenster, über alle Abschnitte
///     required DateTime? bis,
///     required List<SleepSession> naps,
///   });
///   double get tagschlafMinuten;
/// }
///
/// @immutable
/// class SchlafDaten {
///   const SchlafDaten({
///     required SchlafNacht? nacht,
///     required DateTime? frueher,
///     required DateTime? spaeter,
///     required bool zeigtAeltereNacht,
///     required SchlafStatistik? statistik7,
///     required SchlafStatistik? statistik30,
///     required Map<DateTime, SleepScore> scores,
///   });
/// }
///
/// @immutable
/// class SchlafZustand {
///   const SchlafZustand({
///     required Messwert<SchlafDaten> daten,
///     required Ziele ziele,
///     required DateTime heute,
///   });
/// }
///
/// SchlafZustand schlafZustandAus({
///   required Messwert<List<SleepNight>> naechte,
///   required Ziele ziele,
///   required DateTime? gewaehlt,
///   required DateTime jetzt,
/// });
///
/// /// **Ansichtszustand**: `autoDispose`, überlebt das Verlassen nicht.
/// final schlafAuswahlProvider =
///     NotifierProvider.autoDispose<SchlafAuswahlNotifier, DateTime?>(
///   SchlafAuswahlNotifier.new,
/// );
///
/// class SchlafAuswahlNotifier extends Notifier<DateTime?> {
///   void waehle(DateTime? datum);
///   void blaettere(SchlafBlaettern richtung);
/// }
///
/// final schlafProvider = Provider.autoDispose<SchlafZustand>(...);
///
/// // ── Tagschlaf ────────────────────────────────────────────────────────
///
/// @immutable
/// class TagschlafZustand {
///   const TagschlafZustand({
///     required Messwert<List<SleepSession>> phasen,
///     required DateTime tag,
///   });
///   double get minuten;
/// }
///
/// final tagschlafProvider = Provider.autoDispose<TagschlafZustand>(...);
/// ```
///
/// ## Warum dieser Schnitt
///
/// - **`schlafAuswahlProvider` ist `autoDispose` und ein `Notifier`, kein
///   `StateProvider`.** `autoDispose`, weil die gewählte Nacht laut
///   Entscheidung 3 vom 13.10.2026 Ansichtszustand ist: Verlässt man den
///   Schirm, fällt der letzte Zuhörer weg und die Auswahl mit ihm — sonst
///   landete man beim Wiederkommen unerklärt auf dem 11. Oktober. Ein
///   `Notifier` mit `blaettere(…)`/`waehle(…)` statt eines nackten Feldes,
///   **weil #127 eine Wischgeste nachreicht**: Die Geste ruft dieselbe
///   Methode wie der Pfeil, ohne dass jemand den Zustand dafür anfasst. Die
///   Geste selbst gehört **nicht** in diesen Auftrag.
/// - **Der Notifier liest `sleepProvider`, nicht `schlafProvider`.** Sonst
///   gäbe es einen Kreis: `schlafProvider` beobachtet die Auswahl. Die Reihe
///   der Nächte reicht ihm, und die Nachbarschaft rechnet dieselbe reine
///   Funktion, die auch der Zustand benutzt ([schlafNachbarn]).
/// - **`SchlafDaten` trägt `frueher`/`spaeter` als Datum, nicht als `bool`.**
///   Ein `bool` sagte nur „es geht weiter"; der Schirm braucht das Ziel
///   ohnehin, und `null` ist dann genau „am Rand" — der Pfeil wird blass und
///   es passiert nichts, statt ins Leere zu laufen.
/// - **`scores` ist eine Karte über alle geladenen Nächte, keine Liste.**
///   Score-Karte und Kalenderblatt teilen sich **dieselbe** Rechnung
///   (`SleepScoring.series`, Entwurf 13.10.: „zwei Wahrheiten über denselben
///   Score wären schlimmer als eine langsame"). Ein Tag ohne Nacht **fehlt**
///   in der Karte — er hat keinen Score null, er hat keinen.
/// - **Die Statistiken hängen an `heute`, nicht an der gewählten Nacht.**
///   Deshalb liegen sie in `SchlafDaten` und nicht in `SchlafNacht`: Wer sie
///   dort hineinschriebe, hätte sie beim Blättern mitgewandert, und genau das
///   verbietet Entscheidung 3.
/// - **`schlafStatistik` bekommt `bis` und `tage` von außen.** Feste
///   Zeiträume (7 und 30 Nächte), nicht das sichtbare Fenster — dieselbe
///   Regel wie bei den Schritte-Kacheln. Ein Parameter statt zweier
///   Funktionen, damit die Regel an einer Stelle steht.
/// - **Für das Diagramm entsteht kein zweites Stufen-Enum.** `DiagrammStufe`
///   und `diagrammPunkte` liegen seit #94 in
///   `lib/shell/diagramm_zeitraum.dart` (`diagramm_zeitraum_test.dart`,
///   committet als `8eb6136`) und können genau das, was SPEC 4.6 für den
///   Schlaf verlangt: `W M 6M J` ohne `T`, ab `6M` ein Monatsmittel, Lücken
///   bleiben Lücken. Der Schlaf-Schirm liefert deshalb nur noch seine
///   Tageswerte ([schlafTagewerte]) und überlässt die Verdichtung dort.
///   Zwei Rechnungen für dieselbe Verdichtung wären zwei Wahrheiten über
///   dasselbe Diagramm.
///   **Was hier nicht entsteht, ist das Diagramm-Bauteil selbst** — Balken,
///   Ziellinie („grün ab Ziel", SPEC 4.6), Achsen, Blättern und Ablesen
///   gehören zu **#130**. Diese Datei prüft deshalb nichts davon; der
///   Schirm hat in `schlaf_view_test.dart` nur einen Abschnitt
///   `Key('schlaf-verlauf')`, dessen Inhalt offen bleibt, bis #130 steht.
/// - **Die Verdichtung selbst liegt seit #148 im Kern** (`SpanBuckets`,
///   `Packages/trainings_core/test/span_buckets_test.dart`). Hier bleibt
///   nur die Kante: `QuantitySample` ist ein Transporttyp des Kanals und
///   gehört nicht in den Kern (`CLAUDE.md`), also bildet `schlafSpannen`
///   ihn auf `ChartSample` ab und reicht weiter. Bis zum 28.10.2026 stand
///   die Rechnung hier und zählte 16 Abschnitte, deren leere sie wegwarf —
///   beides hat #148 ersetzt, und die Fälle dazu sind mit `TEST_AENDERN=1`
///   entfernt worden. Das **zirkuläre Mittel** ist eine Formel und liegt
///   ebenfalls im Kern —
///   `Packages/trainings_core/test/sleep_statistics_test.dart`.
///
/// ## Was hier bewusst **nicht** geprüft wird
///
/// - **Wortlaut.** Jeder Text gehört in die Views. Wo ein Text eine Regel
///   trägt, prüft ihn der View-Test — hier stehen nur Zahlen und Zustände.
/// - **„Nacht von Hand eintragen".** Das ist ENTWURF vom 26.10.2026
///   (`schlaf.js:20–37`) und steht **nicht** in `docs/SPEC.md`; der Auftrag
///   nennt es nicht. Die Teilnote „Unterbrechungen entfällt", die nur dort
///   vorkommt, ist deshalb kein Vertrag dieser Datei — `SchlafTeilnote` kann
///   sie ausdrücken, erzeugt wird sie nirgends.
/// - **`==`/`hashCode` auf `SchlafZustand`/`SchlafDaten`.** Wie bei
///   `ErholungZustand`: `RecoverySnapshot` und `SleepNight` haben keine
///   Wertgleichheit, ein `==` darüber wäre eine Zusicherung, die der Code
///   nicht einlöst. Geprüft wird statt dessen, dass der Zustand **gehalten**
///   wird.
///
/// ## Zahlen in dieser Datei
///
/// Alle erfunden und frei gewählt. Keine stammt aus einem Health-Export,
/// einem Screenshot oder `docs/screens/` (`CLAUDE.md`).
void main() {
  // Montag, 12.10.2026, 09:15 Berlin (CEST, +2). Weit vor der Umstellung am
  // 25.10., damit jede Uhrzeit in diesen Tests dieselbe Verschiebung hat.
  final jetzt = DateTime.utc(2026, 10, 12, 7, 15);

  DateTime tagesbeginn(int jahr, int monat, int tag) =>
      BerlinCalendar.startOfDay(DateTime.utc(jahr, monat, tag));

  /// Ein Berliner Wanduhr-Zeitpunkt als UTC — CEST, also minus zwei Stunden.
  DateTime berlin(int jahr, int monat, int tag, int stunde, [int minute = 0]) =>
      DateTime.utc(jahr, monat, tag, stunde - 2, minute);

  /// Eine Nacht aus einer Phasenliste. [beginn] ist der Anfang des **ersten**
  /// Abschnitts, die Liste läuft lückenlos weiter.
  SleepNight nachtAus({
    required DateTime tag,
    required DateTime beginn,
    required List<(SleepStage, int)> phasen,
    List<SleepSession> naps = const [],
  }) {
    final abschnitte = <SleepSegment>[];
    var zeiger = beginn;
    for (final (phase, minuten) in phasen) {
      final ende = zeiger.add(Duration(minutes: minuten));
      abschnitte.add(SleepSegment(stage: phase, start: zeiger, end: ende));
      zeiger = ende;
    }
    return SleepNight(
      date: tag,
      session: SleepSession(segments: abschnitte),
      naps: naps,
    );
  }

  /// Eine schlichte Nacht: ein Kern-Abschnitt, [stunden] lang, der um
  /// [einschlafen] Uhr Berliner Zeit am Vortag beginnt.
  SleepNight nachtVon(
    int tag, {
    int monat = 10,
    double stunden = 7,
    int einschlafStunde = 23,
    int einschlafMinute = 0,
    List<SleepSession> naps = const [],
  }) {
    final ende = tagesbeginn(2026, monat, tag);
    // `tagesbeginn` ist Mitternacht; der Beginn zählt von der Einschlafzeit
    // des Vortags aus.
    final beginn = ende
        .add(
          Duration(
            hours: einschlafStunde - 24,
            minutes: einschlafMinute,
          ),
        );
    return nachtAus(
      tag: tagesbeginn(2026, monat, tag),
      beginn: beginn,
      phasen: [(SleepStage.core, (stunden * 60).round())],
      naps: naps,
    );
  }

  /// Ein Nickerchen am Nachmittag.
  SleepSession nickerchen({
    required DateTime von,
    int minuten = 35,
    SleepStage phase = SleepStage.core,
  }) => SleepSession(
    segments: [
      SleepSegment(stage: phase, start: von, end: von.add(Duration(minutes: minuten))),
    ],
  );

  /// Die Reihe, mit der die meisten Tests arbeiten: [anzahl] Nächte bis
  /// einschließlich heute, jede sieben Stunden ab 23:00.
  List<SleepNight> reihe({int anzahl = 30, double stunden = 7}) {
    final ergebnis = <SleepNight>[];
    for (var i = anzahl - 1; i >= 0; i--) {
      // `DateTime.utc` normalisiert einen negativen Tageswert über Monats-
      // und Jahresgrenzen hinweg richtig.
      final tag = DateTime.utc(2026, 10, 12 - i);
      ergebnis.add(nachtVon(tag.day, monat: tag.month, stunden: stunden));
    }
    return ergebnis;
  }

  /// Der Abstand zweier Uhrzeiten **auf dem Kreis**, 0 bis 720 Minuten.
  ///
  /// Zum Prüfen zirkulärer Mittel unverzichtbar: Ein Mittel, das
  /// rechnerisch auf eine Tagesgrenze fällt, kommt in `double` mal als
  /// winzig positive, mal als winzig negative Richtung heraus — nach der
  /// Normalisierung auf `[0, 1440)` also als 0 **oder** als 1439,999….
  /// Beides ist dieselbe Uhrzeit.
  double kreisAbstand(double a, double b) {
    const voll = 1440.0;
    final roh = ((a - b) % voll + voll) % voll;
    return roh > voll / 2 ? voll - roh : roh;
  }

  // ───────────────────────────────────────────────────────────────────────
  // Die drei Teilnoten
  // ───────────────────────────────────────────────────────────────────────

  group('schlafTeilnoten — der Score steht ausgeschrieben da', () {
    const voll = SleepScore(duration: 44, bedtime: 27, interruptions: 10);

    test('drei Teilnoten, in fester Reihenfolge', () {
      final teile = schlafTeilnoten(voll);

      expect(teile.map((t) => t.teil), [
        SchlafTeil.dauer,
        SchlafTeil.zubettgehzeit,
        SchlafTeil.unterbrechungen,
      ]);
    });

    test('jede trägt ihre Punkte und ihr eigenes Maximum — 50, 30, 20', () {
      final teile = schlafTeilnoten(voll);

      expect(teile[0].punkte, 44);
      expect(teile[0].maximum, SleepScore.maxDuration);
      expect(teile[1].punkte, 27);
      expect(teile[1].maximum, SleepScore.maxBedtime);
      expect(teile[2].punkte, 10);
      expect(teile[2].maximum, SleepScore.maxInterruptions);
    });

    test('die Füllung ist Punkte durch Maximum, nicht durch den ganzen Score', () {
      final teile = schlafTeilnoten(voll);

      expect(teile[0].fuellung, closeTo(44 / 50, 1e-9));
      expect(teile[1].fuellung, closeTo(27 / 30, 1e-9));
      expect(teile[2].fuellung, closeTo(10 / 20, 1e-9));
    });

    test('mit Grundlage trägt keine Teilnote einen Entfallgrund', () {
      for (final teil in schlafTeilnoten(voll)) {
        expect(teil.entfaellt, isFalse, reason: '${teil.teil}');
        expect(teil.grund, isNull, reason: '${teil.teil}');
      }
    });

    test(
      'ohne Einschlafzeit entfällt die Zubettgehzeit — punkte ist null, '
      'nicht 0: die Nacht war nicht spät, es ist nichts aufgezeichnet',
      () {
        const ohne = SleepScore(duration: 44, bedtime: null, interruptions: 10);

        final zubett = schlafTeilnoten(ohne)[1];

        expect(zubett.entfaellt, isTrue);
        expect(zubett.punkte, isNull);
        expect(zubett.punkte, isNot(0));
        expect(zubett.fuellung, 0);
      },
    );

    test(
      'und sie entfällt aus genau einem Grund — „keine frühere Nacht als '
      'Vergleich" ist mit dem 14-Nächte-Fenster weggefallen',
      () {
        const ohne = SleepScore(duration: 44, bedtime: null, interruptions: 10);

        expect(
          schlafTeilnoten(ohne)[1].grund,
          SchlafEntfallGrund.keineEinschlafzeit,
        );
        // Die Zubettgehzeit entfällt weiterhin aus genau einem Grund. Die
        // Zahl der Gründe **insgesamt** stand bis #131 ebenfalls hier
        // (`hasLength(1)`) — seit die Unterbrechungen entfallen können,
        // ist sie zwei, und geprüft wird sie dort, wo der zweite Grund
        // entsteht (`schlaf_teilnoten_ohne_phasen_test.dart`). Die Aussage
        // dieses Falls ist die Zubettgehzeit, nicht die Enum-Länge.
        expect(
          SchlafEntfallGrund.values,
          contains(SchlafEntfallGrund.keineEinschlafzeit),
        );
      },
    );

    test('die anderen beiden entfallen nie — sie sind immer gemessen', () {
      const ohne = SleepScore(duration: 44, bedtime: null, interruptions: 10);
      final teile = schlafTeilnoten(ohne);

      expect(teile[0].entfaellt, isFalse);
      expect(teile[2].entfaellt, isFalse);
    });

    test('null Punkte sind etwas anderes als „entfällt"', () {
      const null30 = SleepScore(duration: 0, bedtime: 0, interruptions: 0);
      final teile = schlafTeilnoten(null30);

      for (final teil in teile) {
        expect(teil.entfaellt, isFalse, reason: '${teil.teil}');
        expect(teil.punkte, 0, reason: '${teil.teil}');
      }
    });
  });

  group('schlafRingAbschnitte — der Ring normiert nicht hoch', () {
    test('drei Abschnitte mit den Anteilen 50 / 30 / 20', () {
      final List<RingAbschnitt> ring = schlafRingAbschnitte(
        schlafTeilnoten(
          const SleepScore(duration: 44, bedtime: 27, interruptions: 10),
        ),
      );

      expect(ring, hasLength(3));
      expect(ring[0].anteil, closeTo(0.5, 1e-9));
      expect(ring[1].anteil, closeTo(0.3, 1e-9));
      expect(ring[2].anteil, closeTo(0.2, 1e-9));
      expect(
        ring.fold<double>(0, (a, b) => a + b.anteil),
        closeTo(1, 1e-9),
      );
    });

    test('die Füllung eines Abschnitts ist die seiner Teilnote', () {
      final teile = schlafTeilnoten(
        const SleepScore(duration: 44, bedtime: 27, interruptions: 10),
      );

      final ring = schlafRingAbschnitte(teile);

      for (var i = 0; i < 3; i++) {
        expect(ring[i].fuellung, closeTo(teile[i].fuellung, 1e-9));
      }
    });

    test(
      'eine entfallene Teilnote hat keine Grundlage — gestrichelt statt '
      'blass, sonst behauptete der Bogen ein Ergebnis, das niemand gemessen '
      'hat; und die Anteile bleiben 50/30/20',
      () {
        final ring = schlafRingAbschnitte(
          schlafTeilnoten(
            const SleepScore(duration: 44, bedtime: null, interruptions: 10),
          ),
        );

        expect(ring[1].hatGrundlage, isFalse);
        expect(ring[1].fuellung, 0);
        // **Nicht** auf 50/50 aufgeblasen: Der Ring zeigt weiter, dass ein
        // Drittel des Kreises ohne Grundlage ist.
        expect(ring[1].anteil, closeTo(0.3, 1e-9));
        expect(ring[0].anteil, closeTo(0.5, 1e-9));
        expect(ring[2].anteil, closeTo(0.2, 1e-9));
        expect(ring[0].hatGrundlage, isTrue);
        expect(ring[2].hatGrundlage, isTrue);
      },
    );

    test('null Punkte haben sehr wohl eine Grundlage', () {
      final ring = schlafRingAbschnitte(
        schlafTeilnoten(
          const SleepScore(duration: 10, bedtime: 0, interruptions: 0),
        ),
      );

      expect(ring[1].hatGrundlage, isTrue);
      expect(ring[2].hatGrundlage, isTrue);
    });

    test('die drei Farben sind verschieden — drei Teile, drei Bögen', () {
      final ring = schlafRingAbschnitte(
        schlafTeilnoten(
          const SleepScore(duration: 44, bedtime: 27, interruptions: 10),
        ),
      );

      expect({for (final a in ring) a.farbe}, hasLength(3));
    });
  });

  group('Die Bewertung ist der Anteil der erreichbaren Punkte', () {
    // Die Rechnung selbst gehört dem Kern (`sleep_scoring_test.dart`); hier
    // steht nur, dass der Schirm sie **so** benutzt und nicht hochnormiert.
    test('über 100 erreichbare Punkte gelten 85 / 70 / 55', () {
      expect(
        const SleepScore(duration: 50, bedtime: 25, interruptions: 10).rating,
        SleepRating.veryGood,
      );
      expect(
        const SleepScore(duration: 44, bedtime: 27, interruptions: 10).rating,
        SleepRating.good,
      );
    });

    test(
      'über 70 erreichbare Punkte gelten dieselben Anteile — 54 von 70 ist '
      'gut, obwohl 54 von 100 niedrig wäre',
      () {
        const ohne = SleepScore(duration: 44, bedtime: null, interruptions: 10);

        expect(ohne.total, 54);
        expect(ohne.maxTotal, 70);
        expect(ohne.rating, SleepRating.good);
        // Dieselbe Summe über 100 erreichbare Punkte wäre niedrig.
        expect(
          const SleepScore(duration: 34, bedtime: 10, interruptions: 10).rating,
          SleepRating.low,
        );
      },
    );
  });

  // ───────────────────────────────────────────────────────────────────────
  // Blättern
  // ───────────────────────────────────────────────────────────────────────

  group('geloesteNacht — welche Nacht der Schirm zeigt', () {
    test('ohne Auswahl die letzte Nacht der Reihe', () {
      final naechte = reihe(anzahl: 5);

      final gezeigt = geloesteNacht(naechte: naechte, gewaehlt: null);

      expect(gezeigt?.date, naechte.last.date);
    });

    test('mit Auswahl genau diese Nacht', () {
      final naechte = reihe(anzahl: 5);
      final ziel = naechte[1].date;

      expect(
        geloesteNacht(naechte: naechte, gewaehlt: ziel)?.date,
        ziel,
      );
    });

    test(
      'fällt die gewählte Nacht nach einem Neuladen weg, steht die letzte da '
      '— nicht eine leere Karte',
      () {
        final naechte = reihe(anzahl: 5);
        final verschwunden = tagesbeginn(2025, 1, 1);

        final gezeigt = geloesteNacht(
          naechte: naechte,
          gewaehlt: verschwunden,
        );

        expect(gezeigt, isNotNull);
        expect(gezeigt?.date, naechte.last.date);
      },
    );

    test('ohne geladene Nächte gibt es nichts zu zeigen', () {
      expect(geloesteNacht(naechte: const [], gewaehlt: null), isNull);
    });

    test('die Reihenfolge der Eingabe ist gleichgültig', () {
      final naechte = reihe(anzahl: 5);
      final durcheinander = [naechte[3], naechte[0], naechte[4], naechte[1], naechte[2]];

      expect(
        geloesteNacht(naechte: durcheinander, gewaehlt: null)?.date,
        naechte.last.date,
      );
    });
  });

  group('schlafNachbarn — am Rand stößt es an, statt ins Leere zu laufen', () {
    test('mitten in der Reihe gibt es beide Nachbarn', () {
      final naechte = reihe(anzahl: 5);

      final nachbarn = schlafNachbarn(
        naechte: naechte,
        gewaehlt: naechte[2].date,
      );

      expect(nachbarn.frueher, naechte[1].date);
      expect(nachbarn.spaeter, naechte[3].date);
    });

    test('auf der letzten Nacht gibt es kein Später', () {
      final naechte = reihe(anzahl: 5);

      final nachbarn = schlafNachbarn(naechte: naechte, gewaehlt: null);

      expect(nachbarn.spaeter, isNull);
      expect(nachbarn.frueher, naechte[3].date);
    });

    test('auf der ersten Nacht gibt es kein Früher', () {
      final naechte = reihe(anzahl: 5);

      final nachbarn = schlafNachbarn(
        naechte: naechte,
        gewaehlt: naechte.first.date,
      );

      expect(nachbarn.frueher, isNull);
      expect(nachbarn.spaeter, naechte[1].date);
    });

    test('eine einzige Nacht hat gar keine Nachbarn', () {
      final naechte = reihe(anzahl: 1);

      final nachbarn = schlafNachbarn(naechte: naechte, gewaehlt: null);

      expect(nachbarn.frueher, isNull);
      expect(nachbarn.spaeter, isNull);
    });

    test('ohne Nächte ebenfalls keine', () {
      final nachbarn = schlafNachbarn(naechte: const [], gewaehlt: null);

      expect(nachbarn.frueher, isNull);
      expect(nachbarn.spaeter, isNull);
    });

    test(
      'geblättert wird über **alle** geladenen Nächte — der Store hält ein '
      'Jahr, eine Grenze bei 21 gibt es nicht mehr',
      () {
        final naechte = reihe(anzahl: 30);

        var zeiger = naechte.last.date;
        var schritte = 0;
        while (true) {
          final frueher =
              schlafNachbarn(naechte: naechte, gewaehlt: zeiger).frueher;
          if (frueher == null) break;
          zeiger = frueher;
          schritte += 1;
        }

        expect(schritte, 29);
        expect(zeiger, naechte.first.date);
      },
    );
  });

  // ───────────────────────────────────────────────────────────────────────
  // Statistiken
  // ───────────────────────────────────────────────────────────────────────

  group('schlafStatistik — feste Zeiträume, nicht das sichtbare Fenster', () {
    test('die beiden Zeiträume aus SPEC 4.6 sind benannt: 7 und 30', () {
      expect(schlafStatistikKurz, 7);
      expect(schlafStatistikLang, 30);
    });

    test('ohne Nächte gibt es keine Statistik — null, nicht eine Null', () {
      expect(
        schlafStatistik(naechte: const [], bis: jetzt, tage: 7),
        isNull,
      );
    });

    test(
      'eine Reihe aus lauter Wachabschnitten ist keine Statistik: gezählt '
      'werden Nächte mit Schlaf',
      () {
        final wach = [
          nachtAus(
            tag: tagesbeginn(2026, 10, 12),
            beginn: berlin(2026, 10, 11, 23),
            phasen: const [(SleepStage.awake, 300)],
          ),
        ];

        expect(schlafStatistik(naechte: wach, bis: jetzt, tage: 7), isNull);
      },
    );

    test('über sieben Nächte zählen genau sieben', () {
      final statistik = schlafStatistik(
        naechte: reihe(anzahl: 30),
        bis: jetzt,
        tage: 7,
      )!;

      expect(statistik.naechte, 7);
    });

    test('über dreißig Nächte zählen genau dreißig', () {
      final statistik = schlafStatistik(
        naechte: reihe(anzahl: 30),
        bis: jetzt,
        tage: 30,
      )!;

      expect(statistik.naechte, 30);
    });

    test('mehr Nächte als Zeitraum ändern nichts — der Zeitraum schneidet', () {
      final kurz = schlafStatistik(
        naechte: reihe(anzahl: 7),
        bis: jetzt,
        tage: 7,
      )!;
      final lang = schlafStatistik(
        naechte: reihe(anzahl: 30),
        bis: jetzt,
        tage: 7,
      )!;

      expect(lang.naechte, kurz.naechte);
      expect(lang.schlafMinuten, closeTo(kurz.schlafMinuten, 1e-9));
    });

    test('weniger Nächte als Zeitraum: gezählt wird, was da ist', () {
      final statistik = schlafStatistik(
        naechte: reihe(anzahl: 3),
        bis: jetzt,
        tage: 7,
      )!;

      expect(statistik.naechte, 3);
    });

    test('die Ø-Schlafdauer ist das Mittel der Schlafminuten', () {
      final naechte = [
        nachtVon(10, stunden: 6),
        nachtVon(11, stunden: 7),
        nachtVon(12, stunden: 8),
      ];

      final statistik = schlafStatistik(naechte: naechte, bis: jetzt, tage: 7)!;

      expect(statistik.schlafMinuten, closeTo(7 * 60, 1e-6));
    });

    test(
      'Tagschlaf zählt nicht mit — sonst wäre ein Nickerchen ein Weg, den '
      'eigenen Schnitt zu schönen',
      () {
        final ohne = reihe(anzahl: 7);
        final mit = [
          for (final n in ohne)
            SleepNight(
              date: n.date,
              session: n.session,
              naps: [
                nickerchen(von: n.date.add(const Duration(hours: 14))),
              ],
            ),
        ];

        expect(
          schlafStatistik(naechte: mit, bis: jetzt, tage: 7)!.schlafMinuten,
          closeTo(
            schlafStatistik(naechte: ohne, bis: jetzt, tage: 7)!.schlafMinuten,
            1e-9,
          ),
        );
      },
    );

    test(
      'beim Blättern ändert sich nichts: `bis` ist heute und nicht die '
      'gewählte Nacht',
      () {
        final naechte = reihe(anzahl: 30);

        // Zweimal dieselbe Rechnung, einmal mit einer Auswahl weit zurück —
        // der Zeitraum ist derselbe, weil er `bis` bekommt und nicht die
        // Auswahl.
        final a = schlafStatistik(naechte: naechte, bis: jetzt, tage: 7)!;
        final b = schlafStatistik(naechte: naechte, bis: jetzt, tage: 7)!;

        expect(a.naechte, b.naechte);
        expect(a.schlafMinuten, closeTo(b.schlafMinuten, 1e-9));
      },
    );

    test(
      'ein anderer Stichtag ergibt einen anderen Zeitraum — das ist der '
      'Beweis, dass `bis` überhaupt wirkt',
      () {
        final naechte = [
          for (var t = 6; t <= 12; t++) nachtVon(t, stunden: t.toDouble()),
        ];

        final bisHeute = schlafStatistik(
          naechte: naechte,
          bis: jetzt,
          tage: 3,
        )!;
        final bisFrueher = schlafStatistik(
          naechte: naechte,
          bis: DateTime.utc(2026, 10, 8, 7, 15),
          tage: 3,
        )!;

        expect(bisHeute.schlafMinuten, isNot(closeTo(bisFrueher.schlafMinuten, 1)));
      },
    );
  });

  group('schlafStatistik — die Uhrzeiten werden zirkulär gemittelt', () {
    test(
      'Einschlafzeiten um Mitternacht herum mitteln sich auf Mitternacht, '
      'nicht auf den Mittag',
      () {
        // 23:40, 00:00 und 00:20 Berliner Zeit.
        final naechte = [
          nachtVon(10, einschlafStunde: 23, einschlafMinute: 40),
          nachtVon(11, einschlafStunde: 24),
          nachtVon(12, einschlafStunde: 24, einschlafMinute: 20),
        ];

        final statistik = schlafStatistik(naechte: naechte, bis: jetzt, tage: 7)!;

        // Auf der 18-Uhr-Skala ist Mitternacht die Minute 360.
        expect(statistik.einschlafMinuten, isNotNull);
        expect(statistik.einschlafMinuten!, closeTo(360, 1));
      },
    );

    test(
      'ein Ausreißer am Vormittag zieht das Mittel über die Tagesgrenze '
      'statt quer durch den Tag — genau der Fall, an dem der lineare '
      'Durchschnitt am 13.10.2026 aufgefallen ist (SPEC 4.6 Z. 236–246)',
      () {
        // 11:00 liegt auf der 18-Uhr-Skala bei 1020 Minuten, 18:30 bei 30.
        // Auf dem Kreis sind das Nachbarn; linear liegen sie 990 Minuten
        // auseinander, und ihr Durchschnitt (360 = Mitternacht) landet auf
        // der **falschen Seite** des Bündels.
        final naechte = [
          nachtVon(10, einschlafStunde: 35, stunden: 3), // 11:00
          nachtVon(11, einschlafStunde: 18, einschlafMinute: 30, stunden: 5),
          nachtVon(12, einschlafStunde: 18, einschlafMinute: 30, stunden: 5),
        ];

        final mittel =
            schlafStatistik(naechte: naechte, bis: jetzt, tage: 7)!
                .einschlafMinuten!;

        // Nah am Bündel bei 18:30 …
        expect(
          kreisAbstand(mittel, 30),
          lessThan(180),
          reason: 'Mittel lag bei $mittel',
        );
        // … und der lineare Durchschnitt wäre es gerade nicht.
        expect(kreisAbstand(360, 30), greaterThan(300));
      },
    );

    test(
      'liegen die Zeiten gleichmäßig über den Kreis verteilt, gibt es kein '
      'Mittel — null, und in der Ansicht ein Gedankenstrich',
      () {
        // Drei Einschlafzeiten, acht Stunden auseinander: 18:00, 02:00 und
        // 10:00 Berliner Zeit.
        final naechte = [
          nachtVon(10, einschlafStunde: 18, stunden: 4),
          nachtVon(11, einschlafStunde: 26, stunden: 4),
          nachtVon(12, einschlafStunde: 34, stunden: 4),
        ];

        final statistik = schlafStatistik(naechte: naechte, bis: jetzt, tage: 7)!;

        expect(statistik.einschlafMinuten, isNull);
      },
    );

    test('die Ø-Aufwachzeit rechnet auf derselben Skala und ebenso zirkulär', () {
      final naechte = [
        nachtVon(10, einschlafStunde: 23, stunden: 7),
        nachtVon(11, einschlafStunde: 23, stunden: 7),
        nachtVon(12, einschlafStunde: 23, stunden: 7),
      ];

      final statistik = schlafStatistik(naechte: naechte, bis: jetzt, tage: 7)!;

      // 23:00 + 7 h = 06:00, auf der 18-Uhr-Skala die Minute 720.
      expect(statistik.aufwachMinuten, isNotNull);
      expect(statistik.aufwachMinuten!, closeTo(720, 1));
    });
  });

  group('schlafStatistik — die Phasenanteile', () {
    SleepNight mitPhasen(int tag) => nachtAus(
      tag: tagesbeginn(2026, 10, tag),
      beginn: berlin(2026, 10, tag - 1, 23),
      phasen: const [
        (SleepStage.core, 120),
        (SleepStage.deep, 60),
        (SleepStage.rem, 60),
        (SleepStage.awake, 30),
      ],
    );

    test('die Anteile summieren sich auf eins', () {
      final statistik = schlafStatistik(
        naechte: [mitPhasen(11), mitPhasen(12)],
        bis: jetzt,
        tage: 7,
      )!;

      expect(
        statistik.anteile.values.fold<double>(0, (a, b) => a + b),
        closeTo(1, 1e-9),
      );
    });

    test('sie werden über alle Nächte gepoolt, nicht je Nacht gemittelt', () {
      final kurz = nachtAus(
        tag: tagesbeginn(2026, 10, 11),
        beginn: berlin(2026, 10, 10, 23),
        phasen: const [(SleepStage.core, 60), (SleepStage.deep, 60)],
      );
      final lang = nachtAus(
        tag: tagesbeginn(2026, 10, 12),
        beginn: berlin(2026, 10, 11, 23),
        phasen: const [(SleepStage.core, 540), (SleepStage.deep, 60)],
      );

      final statistik = schlafStatistik(
        naechte: [kurz, lang],
        bis: jetzt,
        tage: 7,
      )!;

      // Gepoolt: 600 Kern und 120 Tief von 720 Minuten. Das Mittel der
      // nächtlichen Anteile wäre 0,5 und 0,5 — eine kurze Nacht wöge dort
      // so schwer wie eine lange.
      expect(statistik.anteile[SleepStage.core], closeTo(600 / 720, 1e-9));
      expect(statistik.anteile[SleepStage.deep], closeTo(120 / 720, 1e-9));
    });

    test(
      'unspezifizierter Schlaf steht in keinem Anteil — eine ältere Uhr '
      'liefert nur ihn, und daraus ist kein Tiefschlafanteil zu gewinnen',
      () {
        final alt = nachtAus(
          tag: tagesbeginn(2026, 10, 12),
          beginn: berlin(2026, 10, 11, 23),
          phasen: const [
            (SleepStage.unspecified, 400),
            (SleepStage.awake, 20),
          ],
        );

        final statistik = schlafStatistik(
          naechte: [alt],
          bis: jetzt,
          tage: 7,
        )!;

        expect(statistik.anteile, isEmpty);
        // Gezählt hat die Nacht trotzdem — sie hat Schlaf, nur keine Phasen.
        expect(statistik.naechte, 1);
        expect(statistik.schlafMinuten, closeTo(400, 1e-6));
      },
    );

    test(
      'eine Nacht ohne Phasendaten verfälscht die Anteile der anderen nicht '
      '— sonst zählte ihr Wachanteil mit, ihr Schlaf aber nicht',
      () {
        final alt = nachtAus(
          tag: tagesbeginn(2026, 10, 11),
          beginn: berlin(2026, 10, 10, 23),
          phasen: const [
            (SleepStage.unspecified, 400),
            (SleepStage.awake, 200),
          ],
        );

        final nurPhasen = schlafStatistik(
          naechte: [mitPhasen(12)],
          bis: jetzt,
          tage: 7,
        )!;
        final mitAlter = schlafStatistik(
          naechte: [alt, mitPhasen(12)],
          bis: jetzt,
          tage: 7,
        )!;

        expect(
          mitAlter.anteile[SleepStage.awake],
          closeTo(nurPhasen.anteile[SleepStage.awake]!, 1e-9),
        );
      },
    );
  });

  group('wanduhrAusAbendminuten — die Skala zurück auf die Uhr', () {
    test('der Nullpunkt ist 18:00', () {
      expect(wanduhrAusAbendminuten(0), (stunde: 18, minute: 0));
    });

    test('300 Minuten sind 23:00', () {
      expect(wanduhrAusAbendminuten(300), (stunde: 23, minute: 0));
    });

    test('nach Mitternacht läuft die Zahl weiter: 420 ist 01:00', () {
      expect(wanduhrAusAbendminuten(420), (stunde: 1, minute: 0));
    });

    test('720 ist 06:00 — die übliche Aufwachzeit', () {
      expect(wanduhrAusAbendminuten(720), (stunde: 6, minute: 0));
    });

    test('Minuten werden mitgeführt', () {
      expect(wanduhrAusAbendminuten(310), (stunde: 23, minute: 10));
    });

    test('eine negative Minute ist der späte Nachmittag, nicht der Morgen', () {
      expect(wanduhrAusAbendminuten(-10), (stunde: 17, minute: 50));
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // Verlauf
  // ───────────────────────────────────────────────────────────────────────

  group('Die Stufen kommen aus #94, nicht aus einem zweiten Enum', () {
    test(
      'vier Stufen, und **kein `T`**: eine Nacht hat keine Stundenwerte, und '
      'eine Leiste mit „T" über Nachtsummen behauptete etwas anderes '
      '(SPEC 4.6 Z. 227–228). Der Entwurf nimmt die Tagesstufe dazu '
      '(`docs/screens/screens/schlaf.js:102–105`) — vorerst gewinnt die '
      'SPEC, die Frage an Tim steht in Ticket #92',
      () {
        expect(DiagrammStufe.values, hasLength(4));
        expect(
          DiagrammStufe.values.map((s) => s.name),
          isNot(contains('tag')),
        );
      },
    );
  });

  group('schlafTagewerte — was ins Diagramm geht', () {
    test('je Nacht mit Schlaf ein Tageswert, Schlüssel ist der Tagesbeginn', () {
      final werte = schlafTagewerte(reihe(anzahl: 5));

      expect(werte, hasLength(5));
      expect(werte.last.tag, tagesbeginn(2026, 10, 12));
    });

    test('der Wert ist die Schlafzeit in Stunden, nicht in Minuten', () {
      final werte = schlafTagewerte([nachtVon(12, stunden: 7)]);

      expect(werte.single.wert, closeTo(7, 1e-6));
    });

    test('Tagschlaf zählt nicht mit', () {
      final grund = nachtVon(12, stunden: 7);
      final mit = SleepNight(
        date: grund.date,
        session: grund.session,
        naps: [nickerchen(von: berlin(2026, 10, 12, 14), minuten: 90)],
      );

      expect(schlafTagewerte([mit]).single.wert, closeTo(7, 1e-6));
    });

    test(
      'eine Nacht ohne Schlafminuten fehlt — sie ist keine gemessene Null, '
      'und `diagrammPunkte` würde eine Null als Messwert zeichnen',
      () {
        final naechte = [
          nachtAus(
            tag: tagesbeginn(2026, 10, 11),
            beginn: berlin(2026, 10, 10, 23),
            phasen: const [(SleepStage.awake, 300)],
          ),
          nachtVon(12, stunden: 7),
        ];

        final werte = schlafTagewerte(naechte);

        expect(werte, hasLength(1));
        expect(werte.single.tag, tagesbeginn(2026, 10, 12));
      },
    );

    test('ohne Nächte ist die Reihe leer, nicht eine Reihe von Nullen', () {
      expect(schlafTagewerte(const []), isEmpty);
    });

    test(
      'die Verdichtung auf Monatsmittel macht `diagrammPunkte`, nicht diese '
      'Funktion — hier steht ein Wert je Nacht, auch für 6M und J',
      () {
        final werte = schlafTagewerte(reihe(anzahl: 30));

        expect(werte, hasLength(30));
        expect(werte.map((w) => w.tag).toSet(), hasLength(30));
      },
    );

    test(
      'sie reicht durch `diagrammPunkte` sauber hindurch: W behält jede '
      'Nacht, 6M bildet Monatsmittel',
      () {
        final werte = schlafTagewerte(reihe(anzahl: 30));

        expect(
          diagrammPunkte(werte: werte, stufe: DiagrammStufe.woche),
          hasLength(30),
        );
        // 30 Nächte liegen in höchstens zwei Kalendermonaten.
        expect(
          diagrammPunkte(werte: werte, stufe: DiagrammStufe.halbjahr).length,
          lessThanOrEqualTo(2),
        );
      },
    );
  });

  group('schlafLetzteNaechte — Lage und Länge, nicht nur die Summe', () {
    test('sieben Nächte als Vorgabe, chronologisch', () {
      final lagen = schlafLetzteNaechte(naechte: reihe(anzahl: 30), bis: jetzt);

      expect(lagen, hasLength(7));
      for (var i = 1; i < lagen.length; i++) {
        expect(lagen[i].datum.isAfter(lagen[i - 1].datum), isTrue);
      }
    });

    test('jede trägt ihr Fenster — von und bis, über alle Abschnitte', () {
      final nacht = nachtAus(
        tag: tagesbeginn(2026, 10, 12),
        beginn: berlin(2026, 10, 11, 23, 10),
        phasen: const [
          (SleepStage.awake, 10),
          (SleepStage.core, 400),
          (SleepStage.awake, 10),
        ],
      );

      final lage = schlafLetzteNaechte(naechte: [nacht], bis: jetzt).single;

      expect(lage.von, berlin(2026, 10, 11, 23, 10));
      expect(lage.bis, berlin(2026, 10, 11, 23, 10).add(const Duration(minutes: 420)));
    });

    test('und die Minuten je Phase', () {
      final nacht = nachtAus(
        tag: tagesbeginn(2026, 10, 12),
        beginn: berlin(2026, 10, 11, 23),
        phasen: const [
          (SleepStage.core, 120),
          (SleepStage.deep, 60),
          (SleepStage.awake, 20),
          (SleepStage.rem, 40),
        ],
      );

      final lage = schlafLetzteNaechte(naechte: [nacht], bis: jetzt).single;

      expect(lage.minutenJePhase[SleepStage.core], closeTo(120, 1e-6));
      expect(lage.minutenJePhase[SleepStage.deep], closeTo(60, 1e-6));
      expect(lage.minutenJePhase[SleepStage.awake], closeTo(20, 1e-6));
      expect(lage.minutenJePhase[SleepStage.rem], closeTo(40, 1e-6));
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // Puls und Atmung
  // ───────────────────────────────────────────────────────────────────────

  group('schlafSpannen — die Kante zum Kern', () {
    // **Die Rechnung steht im Kern** (`SpanBuckets`), und dort steht auch
    // ihr Vertrag: `Packages/trainings_core/test/span_buckets_test.dart`,
    // 41 Fälle. Hier bleibt nur, was an dieser Kante entschieden wird —
    // die Abschnittszahl, die Abbildung des Transporttyps und die Frage,
    // was eine Nacht ohne Fenster ergibt.
    final von = berlin(2026, 10, 11, 23);
    final bis = berlin(2026, 10, 12, 7);

    List<QuantitySample> messungen(List<(Duration, double)> werte) => [
      for (final (versatz, wert) in werte)
        QuantitySample(date: von.add(versatz), value: wert),
    ];

    test('acht Abschnitte sind die Vorgabe aus dem Entwurf', () {
      expect(
        schlafSpannenAbschnitte,
        8,
        reason:
            '`minMaxChart` bekommt in `docs/screens/screens/schlaf.js` acht '
            'Tripel — bis #148 standen hier 16, und gezeichnet wurde '
            'trotzdem jede Einzelmessung',
      );
    });

    test('die Messungen des Kanals kommen als Spannen heraus', () {
      final spannen = schlafSpannen(
        werte: messungen([
          (const Duration(minutes: 5), 58),
          (const Duration(minutes: 10), 71),
          (const Duration(minutes: 20), 62),
        ]),
        von: von,
        bis: bis,
      );

      expect(spannen, hasLength(schlafSpannenAbschnitte));
      expect(spannen.first.min, 58);
      expect(
        spannen.first.max,
        71,
        reason:
            '`QuantitySample` ist die Nutzlast des Kanals, `ChartSample` der '
            'Werttyp des Kerns — dazwischen darf kein Wert verloren gehen',
      );
    });

    test('ein Abschnitt ohne Messung bleibt im Raster und ist leer', () {
      final spannen = schlafSpannen(
        werte: messungen([(const Duration(minutes: 5), 58)]),
        von: von,
        bis: bis,
      );

      expect(spannen, hasLength(schlafSpannenAbschnitte));
      expect(spannen.first.isEmpty, isFalse);
      expect(
        spannen[1].isEmpty,
        isTrue,
        reason:
            'bis #148 fiel er aus der Liste — dann verrutschte ab dort die '
            'Achse und jede folgende Beschriftung log (Tims Entscheidung '
            'vom 28.10.2026: der Platz bleibt frei)',
      );
      expect(
        spannen[1].min,
        isNull,
        reason: 'niemals 0 — das wäre eine Messung, die es nicht gibt',
      );
    });

    test('ohne Messungen gibt es keine Spanne', () {
      expect(
        schlafSpannen(werte: const [], von: von, bis: bis),
        isEmpty,
        reason:
            'kein vollständiges leeres Raster — eine leere Liste ist für die '
            'Ansicht das Zeichen für `LeerNachLauf`',
      );
    });

    test('ein Fenster ohne Dauer ergibt nichts, statt zu werfen', () {
      expect(
        schlafSpannen(
          werte: messungen([(Duration.zero, 60)]),
          von: von,
          bis: von,
        ),
        isEmpty,
        reason:
            'dass eine Nacht kein Fenster hat, ist eine Datenlage und kein '
            'Programmierfehler — anders als ein unmöglicher Zuschnitt, den '
            '`SpanBuckets.spans` meldet',
      );
    });

    test('NachtVitalwerte ohne beide Reihen ist leer', () {
      expect(const NachtVitalwerte(puls: [], atmung: []).istLeer, isTrue);
    });

    test('eine einzige Reihe genügt, damit sie nicht leer ist', () {
      final spannen = schlafSpannen(
        werte: messungen([(const Duration(minutes: 5), 58)]),
        von: von,
        bis: bis,
      );

      expect(NachtVitalwerte(puls: spannen, atmung: const []).istLeer, isFalse);
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // Der ganze Zustand
  // ───────────────────────────────────────────────────────────────────────

  group('schlafZustandAus — der Messwert kommt durch', () {
    SchlafZustand zustand({
      Messwert<List<SleepNight>>? naechte,
      Ziele ziele = Ziele.vorbelegung,
      DateTime? gewaehlt,
    }) => schlafZustandAus(
      naechte:
          naechte ??
          Bekannt<List<SleepNight>>(reihe(), stand: jetzt, laeuft: false),
      ziele: ziele,
      gewaehlt: gewaehlt,
      jetzt: jetzt,
    );

    SchlafDaten datenAus(SchlafZustand z) {
      final daten = z.daten;
      if (daten is! Bekannt<SchlafDaten>) {
        fail('erwartet war Bekannt, da stand $daten');
      }
      return daten.wert;
    }

    test('NochNie bleibt NochNie — während des Ladens kein Grund, kein Leer', () {
      expect(
        zustand(naechte: const NochNie<List<SleepNight>>()).daten,
        isA<NochNie<SchlafDaten>>(),
      );
    });

    test('LeerNachLauf bleibt LeerNachLauf, mit seinem Zeitpunkt', () {
      final z = zustand(
        naechte: LeerNachLauf<List<SleepNight>>(gelaufen: jetzt),
      );

      expect(z.daten, isA<LeerNachLauf<SchlafDaten>>());
      expect((z.daten as LeerNachLauf<SchlafDaten>).gelaufen, jetzt);
    });

    test('Fehlgeschlagen bleibt Fehlgeschlagen — ein Fehler ist keine Leere', () {
      final z = zustand(
        naechte: Fehlgeschlagen<List<SleepNight>>(
          fehler: 'Kanal weg',
          gelaufen: jetzt,
        ),
      );

      expect(z.daten, isA<Fehlgeschlagen<SchlafDaten>>());
    });

    test('Bekannt trägt Stand und laeuft unverändert weiter', () {
      final z = zustand(
        naechte: Bekannt<List<SleepNight>>(reihe(), stand: jetzt, laeuft: true),
      );
      final daten = z.daten as Bekannt<SchlafDaten>;

      expect(daten.stand, jetzt);
      expect(daten.laeuft, isTrue);
    });

    test(
      'eine leere, aber gelesene Liste ist Bekannt ohne Nacht — nicht '
      'LeerNachLauf: das zu entscheiden ist Sache des Providers',
      () {
        final z = zustand(
          naechte: Bekannt<List<SleepNight>>(
            const [],
            stand: jetzt,
            laeuft: false,
          ),
        );

        expect(datenAus(z).nacht, isNull);
      },
    );

    test('die Ziele stehen unverpackt daneben — sie sind Tims eigene Daten', () {
      final z = zustand(
        ziele: Ziele.vorbelegung.kopieMit(schlafzielMinuten: 450),
      );

      expect(z.ziele.schlafzielMinuten, 450);
    });

    test('heute ist der Berliner Tagesbeginn, nicht die Uhrzeit', () {
      expect(zustand().heute, BerlinCalendar.startOfDay(jetzt));
    });
  });

  group('schlafZustandAus — die gezeigte Nacht', () {
    SchlafDaten daten({DateTime? gewaehlt, List<SleepNight>? naechte, Ziele? ziele}) {
      final z = schlafZustandAus(
        naechte: Bekannt<List<SleepNight>>(
          naechte ?? reihe(),
          stand: jetzt,
          laeuft: false,
        ),
        ziele: ziele ?? Ziele.vorbelegung,
        gewaehlt: gewaehlt,
        jetzt: jetzt,
      );
      return (z.daten as Bekannt<SchlafDaten>).wert;
    }

    test('ohne Auswahl die letzte Nacht, und sie gilt nicht als ältere', () {
      final d = daten();

      expect(d.nacht!.nacht.date, reihe().last.date);
      expect(d.zeigtAeltereNacht, isFalse);
    });

    test('mit Auswahl die gewählte, und sie gilt als ältere', () {
      final naechte = reihe();
      final d = daten(gewaehlt: naechte[5].date);

      expect(d.nacht!.nacht.date, naechte[5].date);
      expect(d.zeigtAeltereNacht, isTrue);
    });

    test(
      'wird die letzte Nacht ausdrücklich gewählt, gilt sie trotzdem nicht '
      'als ältere — sonst stünde der Hinweis ohne Anlass da',
      () {
        final naechte = reihe();

        expect(daten(gewaehlt: naechte.last.date).zeigtAeltereNacht, isFalse);
      },
    );

    test('der Score wird mit den Zielen gerechnet, nicht mit Konstanten', () {
      final naechte = [nachtVon(12, stunden: 4, einschlafStunde: 23)];

      final mitAchtStunden = daten(naechte: naechte).nacht!.score;
      final mitVierStunden = daten(
        naechte: naechte,
        ziele: Ziele.vorbelegung.kopieMit(schlafzielMinuten: 240),
      ).nacht!.score;

      expect(mitAchtStunden.duration, lessThan(mitVierStunden.duration));
      expect(mitVierStunden.duration, SleepScore.maxDuration);
    });

    test(
      'die Zubettgehzeit rechnet gegen das Schlafenszeitziel aus den '
      'Einstellungen — nicht gegen den eigenen Schnitt',
      () {
        // Jede Nacht um 23:00, also 30 Minuten nach dem Ziel von 22:30:
        // 30 − 30/15 = 28. Gegen den eigenen Schnitt wären es volle 30.
        final punkte = daten(
          naechte: [for (var t = 6; t <= 12; t++) nachtVon(t, einschlafStunde: 23)],
        ).nacht!.score.bedtime;

        expect(punkte, 28);
      },
    );

    test(
      'ein späteres Ziel macht dieselbe Nacht besser — der Beweis, dass das '
      'Ziel überhaupt eingeht',
      () {
        final naechte = [nachtVon(12, einschlafStunde: 23)];

        final gegen2230 = daten(naechte: naechte).nacht!.score.bedtime;
        final gegen2300 = daten(
          naechte: naechte,
          ziele: Ziele.vorbelegung.kopieMit(schlafenszeitMinuten: 23 * 60),
        ).nacht!.score.bedtime;

        expect(gegen2230, lessThan(gegen2300!));
        expect(gegen2300, SleepScore.maxBedtime);
      },
    );

    test('früher als das Ziel kostet nichts', () {
      final punkte = daten(
        naechte: [nachtVon(12, einschlafStunde: 21)],
      ).nacht!.score.bedtime;

      expect(punkte, SleepScore.maxBedtime);
    });

    test('die Teilnoten der Karte sind die des Score', () {
      final nacht = daten().nacht!;
      final erwartet = schlafTeilnoten(nacht.score);

      expect(nacht.teilnoten.map((t) => t.teil), erwartet.map((t) => t.teil));
      expect(nacht.teilnoten.map((t) => t.punkte), erwartet.map((t) => t.punkte));
      expect(nacht.teilnoten.map((t) => t.maximum), erwartet.map((t) => t.maximum));
      expect(nacht.teilnoten.map((t) => t.grund), erwartet.map((t) => t.grund));
    });

    test('das Fenster geht über alle Abschnitte, auch die wachen', () {
      final nacht = nachtAus(
        tag: tagesbeginn(2026, 10, 12),
        beginn: berlin(2026, 10, 11, 23),
        phasen: const [
          (SleepStage.awake, 20),
          (SleepStage.core, 400),
          (SleepStage.awake, 15),
        ],
      );

      final gezeigt = daten(naechte: [nacht]).nacht!;

      expect(gezeigt.von, berlin(2026, 10, 11, 23));
      expect(
        gezeigt.bis,
        berlin(2026, 10, 11, 23).add(const Duration(minutes: 435)),
      );
    });

    test(
      'die Einschlafzeit ist trotzdem der Beginn des ersten '
      'Schlafabschnitts, nicht der des Wachliegens davor',
      () {
        final nacht = nachtAus(
          tag: tagesbeginn(2026, 10, 12),
          beginn: berlin(2026, 10, 11, 23),
          phasen: const [(SleepStage.awake, 20), (SleepStage.core, 400)],
        );

        final gezeigt = daten(naechte: [nacht]).nacht!;

        expect(gezeigt.kern.bedtime, berlin(2026, 10, 11, 23, 20));
      },
    );

    test('die Nachbarn stehen am Zustand und werden nicht neu gesucht', () {
      final naechte = reihe(anzahl: 5);
      final d = daten(naechte: naechte, gewaehlt: naechte[2].date);

      expect(d.frueher, naechte[1].date);
      expect(d.spaeter, naechte[3].date);
    });
  });

  group('Tagschlaf zählt nicht in die Nacht', () {
    SchlafNacht gezeigt(List<SleepNight> naechte) {
      final z = schlafZustandAus(
        naechte: Bekannt<List<SleepNight>>(naechte, stand: jetzt, laeuft: false),
        ziele: Ziele.vorbelegung,
        gewaehlt: null,
        jetzt: jetzt,
      );
      return ((z.daten as Bekannt<SchlafDaten>).wert).nacht!;
    }

    test(
      'Dauer, Score und Wachzeit bleiben gleich, ob ein Nickerchen daneben '
      'liegt oder nicht — sonst wäre es ein Weg, den Score zu schönen',
      () {
        final ohne = nachtVon(12, stunden: 7);
        final mit = SleepNight(
          date: ohne.date,
          session: ohne.session,
          naps: [
            nickerchen(von: berlin(2026, 10, 12, 14), minuten: 90),
            nickerchen(von: berlin(2026, 10, 12, 18), minuten: 40),
          ],
        );

        final a = gezeigt([ohne]);
        final b = gezeigt([mit]);

        expect(b.kern.asleepMinutes, closeTo(a.kern.asleepMinutes, 1e-9));
        expect(b.kern.awakeMinutes, closeTo(a.kern.awakeMinutes, 1e-9));
        expect(b.kern.wakeCount, a.kern.wakeCount);
        expect(b.score, a.score);
      },
    );

    test('der Tagschlaf steht trotzdem an der Nacht — als Tür, nicht als Summand', () {
      final ohne = nachtVon(12, stunden: 7);
      final mit = SleepNight(
        date: ohne.date,
        session: ohne.session,
        naps: [nickerchen(von: berlin(2026, 10, 12, 14), minuten: 35)],
      );

      final b = gezeigt([mit]);

      expect(b.naps, hasLength(1));
      expect(b.tagschlafMinuten, closeTo(35, 1e-6));
    });

    test('ohne Nickerchen sind es null Minuten und eine leere Liste', () {
      final b = gezeigt([nachtVon(12)]);

      expect(b.naps, isEmpty);
      expect(b.tagschlafMinuten, 0);
    });

    test('Wachliegen im Nickerchen zählt nicht als Tagschlaf', () {
      final ohne = nachtVon(12);
      final mit = SleepNight(
        date: ohne.date,
        session: ohne.session,
        naps: [
          SleepSession(
            segments: [
              SleepSegment(
                stage: SleepStage.awake,
                start: berlin(2026, 10, 12, 14),
                end: berlin(2026, 10, 12, 14, 10),
              ),
              SleepSegment(
                stage: SleepStage.core,
                start: berlin(2026, 10, 12, 14, 10),
                end: berlin(2026, 10, 12, 14, 40),
              ),
            ],
          ),
        ],
      );

      expect(gezeigt([mit]).tagschlafMinuten, closeTo(30, 1e-6));
    });
  });

  group('Die Scores fürs Kalenderblatt — einmal gerechnet, zweimal benutzt', () {
    SchlafDaten daten({List<SleepNight>? naechte, DateTime? gewaehlt}) {
      final z = schlafZustandAus(
        naechte: Bekannt<List<SleepNight>>(
          naechte ?? reihe(),
          stand: jetzt,
          laeuft: false,
        ),
        ziele: Ziele.vorbelegung,
        gewaehlt: gewaehlt,
        jetzt: jetzt,
      );
      return (z.daten as Bekannt<SchlafDaten>).wert;
    }

    test('je geladene Nacht mit Schlaf ein Eintrag', () {
      final d = daten(naechte: reihe(anzahl: 12));

      expect(d.scores, hasLength(12));
    });

    test(
      'der Score der Karte und der des Kalenderblatts sind derselbe — zwei '
      'Wahrheiten über denselben Score wären schlimmer als eine langsame',
      () {
        final d = daten();

        expect(d.scores[d.nacht!.nacht.date], d.nacht!.score);
      },
    );

    test('auch beim Blättern', () {
      final naechte = reihe();
      final d = daten(gewaehlt: naechte[3].date);

      expect(d.scores[naechte[3].date], d.nacht!.score);
    });

    test(
      'ein Tag ohne Nacht fehlt in der Karte — das ist nicht dasselbe wie '
      'ein Score von null, und das Kalenderblatt zeigt dort nur die blasse '
      'Spur',
      () {
        final naechte = [nachtVon(10), nachtVon(12)];

        final d = daten(naechte: naechte);

        expect(d.scores.containsKey(tagesbeginn(2026, 10, 11)), isFalse);
        expect(d.scores, hasLength(2));
      },
    );

    test('eine Nacht ohne Schlafminuten fehlt ebenfalls', () {
      final naechte = [
        nachtAus(
          tag: tagesbeginn(2026, 10, 11),
          beginn: berlin(2026, 10, 10, 23),
          phasen: const [(SleepStage.awake, 300)],
        ),
        nachtVon(12),
      ];

      final d = daten(naechte: naechte);

      expect(d.scores.containsKey(tagesbeginn(2026, 10, 11)), isFalse);
    });
  });

  group('Die Statistiken bleiben auf heute bezogen', () {
    SchlafDaten daten({DateTime? gewaehlt}) {
      final z = schlafZustandAus(
        naechte: Bekannt<List<SleepNight>>(reihe(), stand: jetzt, laeuft: false),
        ziele: Ziele.vorbelegung,
        gewaehlt: gewaehlt,
        jetzt: jetzt,
      );
      return (z.daten as Bekannt<SchlafDaten>).wert;
    }

    test('beide Zeiträume stehen am Zustand', () {
      final d = daten();

      expect(d.statistik7, isNotNull);
      expect(d.statistik30, isNotNull);
      expect(d.statistik7!.naechte, 7);
      expect(d.statistik30!.naechte, 30);
    });

    test(
      'sie ändern sich beim Blättern nicht — sonst ändern sich Zahlen, die '
      'niemand gesucht hat (Entscheidung 3 vom 13.10.2026)',
      () {
        final naechte = reihe();

        final heute = daten();
        final zurueck = daten(gewaehlt: naechte[4].date);

        expect(zurueck.statistik7!.naechte, heute.statistik7!.naechte);
        expect(
          zurueck.statistik7!.schlafMinuten,
          closeTo(heute.statistik7!.schlafMinuten, 1e-9),
        );
        expect(
          zurueck.statistik30!.schlafMinuten,
          closeTo(heute.statistik30!.schlafMinuten, 1e-9),
        );
      },
    );
  });

  // ───────────────────────────────────────────────────────────────────────
  // Die Provider
  // ───────────────────────────────────────────────────────────────────────

  group('schlafAuswahlProvider — Ansichtszustand, kein Store', () {
    ProviderContainer behaelter({List<SleepNight>? naechte}) {
      final reiheHier = naechte ?? reihe();
      // CLAUDE.md: In Tests wird Riverpods Wiederholung abgeschaltet.
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          clockProvider.overrideWithValue(() => jetzt),
          // **Der gelesene Zeitraum, ausdrücklich gesetzt** (#177): Seit
          // leere Tage erreichbar sind, endet das Blättern am Anfang des
          // Zeitraums und nicht an der ältesten geladenen Nacht. Ohne diese
          // Zeile reichte er dreißig Tage zurück, und „am Anfang der Reihe
          // passiert nichts" prüfte eine Grenze, die woanders läge.
          dataWindowProvider.overrideWith(
            (ref) => DataWindow(
              start: reiheHier.isEmpty ? jetzt : reiheHier.first.date,
            ),
          ),
          sleepProvider.overrideWith(
            () => _Naechte(
              Bekannt<List<SleepNight>>(reiheHier, stand: jetzt, laeuft: false),
            ),
          ),
          zieleProvider.overrideWith(() => _Ziele(Ziele.vorbelegung)),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    Future<void> geladen(ProviderContainer container) async {
      container.listen(schlafProvider, (_, _) {}, fireImmediately: true);
      await container.read(sleepProvider.future);
      await container.read(zieleProvider.future);
    }

    test('ohne Zutun steht die Auswahl auf null — „die letzte Nacht"', () {
      final container = behaelter();

      expect(container.read(schlafAuswahlProvider), isNull);
    });

    test('waehle setzt sie, waehle(null) nimmt sie zurück', () async {
      final container = behaelter();
      await geladen(container);
      final naechte = reihe();

      container.read(schlafAuswahlProvider.notifier).waehle(naechte[3].date);
      expect(container.read(schlafAuswahlProvider), naechte[3].date);

      container.read(schlafAuswahlProvider.notifier).waehle(null);
      expect(container.read(schlafAuswahlProvider), isNull);
    });

    test('blaettere(frueher) geht eine Nacht zurück', () async {
      final container = behaelter();
      await geladen(container);
      final naechte = reihe();

      container.read(schlafAuswahlProvider.notifier).blaettere(
        SchlafBlaettern.frueher,
      );

      expect(container.read(schlafAuswahlProvider), naechte[naechte.length - 2].date);
    });

    test('zweimal zurück sind zwei Nächte', () async {
      final container = behaelter();
      await geladen(container);
      final naechte = reihe();
      final notifier = container.read(schlafAuswahlProvider.notifier);

      notifier.blaettere(SchlafBlaettern.frueher);
      notifier.blaettere(SchlafBlaettern.frueher);

      expect(container.read(schlafAuswahlProvider), naechte[naechte.length - 3].date);
    });

    test('und zurück nach vorn landet wieder auf der letzten Nacht', () async {
      final container = behaelter();
      await geladen(container);
      final notifier = container.read(schlafAuswahlProvider.notifier);

      notifier.blaettere(SchlafBlaettern.frueher);
      notifier.blaettere(SchlafBlaettern.spaeter);

      // Geprüft wird die **gezeigte** Nacht, nicht der rohe Auswahlwert:
      // Ob der Schirm dafür auf `null` zurückfällt oder das Datum der
      // letzten Nacht trägt, ist eine Umsetzungsfrage — das Ergebnis ist
      // dieselbe Nacht.
      final daten =
          (container.read(schlafProvider).daten as Bekannt<SchlafDaten>).wert;
      expect(daten.nacht!.nacht.date, reihe().last.date);
      expect(daten.zeigtAeltereNacht, isFalse);
    });

    test(
      'am Anfang der Reihe passiert nichts — es stößt an, statt ins Leere '
      'zu laufen',
      () async {
        final container = behaelter(naechte: reihe(anzahl: 2));
        await geladen(container);
        final notifier = container.read(schlafAuswahlProvider.notifier);

        notifier.blaettere(SchlafBlaettern.frueher);
        final nachEinem = container.read(schlafAuswahlProvider);
        notifier.blaettere(SchlafBlaettern.frueher);
        notifier.blaettere(SchlafBlaettern.frueher);

        expect(container.read(schlafAuswahlProvider), nachEinem);
      },
    );

    test('am Ende der Reihe ebenso — die letzte Nacht bleibt stehen', () async {
      final container = behaelter();
      await geladen(container);
      final notifier = container.read(schlafAuswahlProvider.notifier);

      notifier.blaettere(SchlafBlaettern.spaeter);
      notifier.blaettere(SchlafBlaettern.spaeter);

      final daten =
          (container.read(schlafProvider).daten as Bekannt<SchlafDaten>).wert;
      expect(daten.nacht!.nacht.date, reihe().last.date);
      expect(daten.spaeter, isNull);
    });

    test('ohne geladene Nächte blättert nichts', () {
      final container = behaelter(naechte: const []);

      container.read(schlafAuswahlProvider.notifier).blaettere(
        SchlafBlaettern.frueher,
      );

      expect(container.read(schlafAuswahlProvider), isNull);
    });

    test(
      'die Auswahl überlebt das Verlassen des Schirms nicht — fällt der '
      'letzte Zuhörer weg, steht sie wieder auf null (Entscheidung 3)',
      () async {
        final container = behaelter();
        // **Kein** dauerhaftes Abo auf `schlafProvider` hier: Der beobachtet
        // die Auswahl, und ein offenes Abo darauf hielte sie am Leben — der
        // Test prüfte dann das Gegenteil dessen, was er behauptet.
        final abo = container.listen(schlafAuswahlProvider, (_, _) {});
        container.read(schlafAuswahlProvider.notifier).waehle(reihe()[3].date);
        expect(container.read(schlafAuswahlProvider), isNotNull);

        abo.close();
        // Riverpod räumt `autoDispose` am Ende der Mikrotask-Schleife auf.
        await Future<void>.delayed(Duration.zero);

        expect(container.read(schlafAuswahlProvider), isNull);
      },
    );
  });

  group('schlafProvider — gehalten, nicht je Zugriff gerechnet', () {
    ProviderContainer behaelter({Ziele ziele = Ziele.vorbelegung}) {
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          clockProvider.overrideWithValue(() => jetzt),
          sleepProvider.overrideWith(
            () => _Naechte(
              Bekannt<List<SleepNight>>(reihe(), stand: jetzt, laeuft: false),
            ),
          ),
          zieleProvider.overrideWith(() => _Ziele(ziele)),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('zweimal lesen gibt dieselbe Instanz (Hausregel 2, docs/todo/03)', () async {
      final container = behaelter();
      container.listen(schlafProvider, (_, _) {}, fireImmediately: true);
      await container.read(sleepProvider.future);
      await container.read(zieleProvider.future);

      expect(
        identical(container.read(schlafProvider), container.read(schlafProvider)),
        isTrue,
      );
    });

    test('ändert sich die Auswahl, rechnet er neu', () async {
      final container = behaelter();
      container.listen(schlafProvider, (_, _) {}, fireImmediately: true);
      await container.read(sleepProvider.future);
      await container.read(zieleProvider.future);

      final vorher = container.read(schlafProvider);
      container.read(schlafAuswahlProvider.notifier).waehle(reihe()[2].date);
      final nachher = container.read(schlafProvider);

      expect(identical(vorher, nachher), isFalse);
      final daten = (nachher.daten as Bekannt<SchlafDaten>).wert;
      expect(daten.nacht!.nacht.date, reihe()[2].date);
      expect(daten.zeigtAeltereNacht, isTrue);
    });

    test('solange der Schlaf-Lauf nichts geliefert hat, steht NochNie', () {
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          clockProvider.overrideWithValue(() => jetzt),
          sleepProvider.overrideWith(
            () => _Naechte(const NochNie<List<SleepNight>>()),
          ),
          zieleProvider.overrideWith(() => _Ziele(Ziele.vorbelegung)),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(schlafProvider).daten, isA<NochNie<SchlafDaten>>());
    });

    test('die Ziele kommen aus dem Provider, nicht aus einer Konstante', () async {
      final container = behaelter(
        ziele: Ziele.vorbelegung.kopieMit(schlafzielMinuten: 420),
      );
      container.listen(schlafProvider, (_, _) {}, fireImmediately: true);
      await container.read(sleepProvider.future);
      await container.read(zieleProvider.future);

      expect(container.read(schlafProvider).ziele.schlafzielMinuten, 420);
    });
  });

  group('tagschlafProvider — ein eigener Schirm, nichts von der Nacht', () {
    SleepNight mitNickerchen(int tag, {int anzahl = 1}) {
      final grund = nachtVon(tag);
      return SleepNight(
        date: grund.date,
        session: grund.session,
        naps: [
          for (var i = 0; i < anzahl; i++)
            nickerchen(
              von: berlin(2026, 10, tag, 13 + 3 * i, 40),
              minuten: 35 + 5 * i,
            ),
        ],
      );
    }

    ProviderContainer behaelter(List<SleepNight> naechte) {
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          clockProvider.overrideWithValue(() => jetzt),
          sleepProvider.overrideWith(
            () => _Naechte(
              Bekannt<List<SleepNight>>(naechte, stand: jetzt, laeuft: false),
            ),
          ),
          zieleProvider.overrideWith(() => _Ziele(Ziele.vorbelegung)),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('ohne Auswahl die Nickerchen von heute', () async {
      final container = behaelter([mitNickerchen(12)]);
      container.listen(tagschlafProvider, (_, _) {}, fireImmediately: true);
      await container.read(sleepProvider.future);

      final zustand = container.read(tagschlafProvider);

      expect(zustand.tag, tagesbeginn(2026, 10, 12));
      expect((zustand.phasen as Bekannt<List<SleepSession>>).wert, hasLength(1));
    });

    test('die Summe zählt nur Schlafminuten der Nickerchen', () async {
      final container = behaelter([mitNickerchen(12, anzahl: 2)]);
      container.listen(tagschlafProvider, (_, _) {}, fireImmediately: true);
      await container.read(sleepProvider.future);

      // 35 und 40 Minuten.
      expect(container.read(tagschlafProvider).minuten, closeTo(75, 1e-6));
    });

    test(
      'die Nacht selbst geht nicht ein — wer die Kachel antippt, will '
      'wissen, was er am Tag geschlafen hat',
      () async {
        final container = behaelter([mitNickerchen(12)]);
        container.listen(tagschlafProvider, (_, _) {}, fireImmediately: true);
        await container.read(sleepProvider.future);

        // Die Nacht ist sieben Stunden lang; käme sie dazu, stünden hier
        // 455 Minuten.
        expect(container.read(tagschlafProvider).minuten, closeTo(35, 1e-6));
      },
    );

    test('ein Tag ohne Nickerchen ist leer, nicht unbekannt', () async {
      final container = behaelter([nachtVon(12)]);
      container.listen(tagschlafProvider, (_, _) {}, fireImmediately: true);
      await container.read(sleepProvider.future);

      final zustand = container.read(tagschlafProvider);

      expect(zustand.phasen, isA<Bekannt<List<SleepSession>>>());
      expect((zustand.phasen as Bekannt<List<SleepSession>>).wert, isEmpty);
      expect(zustand.minuten, 0);
    });

    test(
      'blättert man auf dem Schlaf-Schirm zurück, zeigt der Tagschlaf den '
      'Tag dieser Nacht — sonst wäre er beim Blättern unsichtbar',
      () async {
        final container = behaelter([mitNickerchen(11, anzahl: 2), mitNickerchen(12)]);
        container.listen(schlafProvider, (_, _) {}, fireImmediately: true);
        container.listen(tagschlafProvider, (_, _) {}, fireImmediately: true);
        await container.read(sleepProvider.future);
        await container.read(zieleProvider.future);

        container.read(schlafAuswahlProvider.notifier).waehle(
          tagesbeginn(2026, 10, 11),
        );

        final zustand = container.read(tagschlafProvider);

        expect(zustand.tag, tagesbeginn(2026, 10, 11));
        expect(zustand.minuten, closeTo(75, 1e-6));
      },
    );

    test('solange nichts geladen ist, steht NochNie', () {
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          clockProvider.overrideWithValue(() => jetzt),
          sleepProvider.overrideWith(
            () => _Naechte(const NochNie<List<SleepNight>>()),
          ),
          zieleProvider.overrideWith(() => _Ziele(Ziele.vorbelegung)),
        ],
      );
      addTearDown(container.dispose);

      expect(
        container.read(tagschlafProvider).phasen,
        isA<NochNie<List<SleepSession>>>(),
      );
    });
  });
}

/// Steuerbare Ableger der echten Notifier — wie `_Naechte` in
/// `erholung_zustand_test.dart` und aus demselben Grund: Riverpods
/// Provider-Typen sind invariant, ein unabhängiger `AsyncNotifier` erfüllt
/// die Signatur von `overrideWith` nicht.
class _Naechte extends SleepNotifier {
  _Naechte(this.wert);

  final Messwert<List<SleepNight>> wert;

  @override
  Future<Messwert<List<SleepNight>>> build() async => wert;
}

class _Ziele extends ZieleNotifier {
  _Ziele(this.wert);

  final Ziele wert;

  @override
  Future<Ziele> build() async => wert;
}
