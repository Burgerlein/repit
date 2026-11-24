import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/core/messwert.dart';
import 'package:repit/design/formatierung.dart';
import 'package:repit/design/palette.dart';
import 'package:repit/shell/erholung_abschnitte.dart';
import 'package:repit/shell/erholung_werte_zustand.dart';
import 'package:repit/shell/erholung_zustand.dart';

/// Tests für den **Zustand** des Schirms `erholung-werte` (#117) —
/// `lib/shell/erholung_werte_zustand.dart`. Der Schirm darüber liegt in
/// `erholung_werte_view_test.dart`.
///
/// Die Trennung ist dieselbe wie bei `erholung_zustand_test.dart` /
/// `erholung_view_test.dart` und aus demselben Grund: Jede Regel dieses
/// Tickets ist eine **Entscheidung**, keine Darstellung — welche Kante die
/// Karte trägt, ob ein Balken überhaupt entsteht, wie hoch ein Tagesbalken
/// wird, welcher Schwellenwert dasteht. Das alles ist ohne Widget prüfbar,
/// und was ohne Widget prüfbar ist, wird ohne Widget geprüft: Ein
/// Widget-Test, der eine Zahl aus einem gerenderten `Text` fischt, prüft
/// nebenbei ein Layout mit, das niemand zugesagt hat.
///
/// ## Festgelegte öffentliche API (`lib/shell/erholung_werte_zustand.dart`)
///
/// ```dart
/// /// Der Balken hinter einem Wert — **ein** Feld statt vier, die
/// /// zueinander passen müssen. „Fehlt der Median, fällt der Balken ganz
/// /// weg" ist damit unausdrückbar falsch: Ohne Median gibt es kein
/// /// [Normalbalken]-Objekt, nicht eines mit `median: null`.
/// @immutable
/// class Normalbalken {
///   const Normalbalken({
///     required ({double von, double bis}) skala,
///     required ({double von, double bis}) normalbereich,
///     required double median,
///     required double marke,
///   });
///
///   /// Die feste Anzeigeskala der Metrik (Ticket Abschnitt 2).
///   final ({double von, double bis}) skala;
///
///   /// Der Bereich ohne Warnsignal, in Einheiten der Metrik.
///   final ({double von, double bis}) normalbereich;
///
///   final double median;
///
///   /// Der Wert von heute Nacht, **ungeklemmt** — geklemmt wird erst in
///   /// [markeAnteil].
///   final double marke;
///
///   /// Lage auf der Skala, 0…1, geklemmt.
///   double get markeAnteil;
///   double get medianAnteil;
///   ({double von, double bis}) get normalbereichAnteil;
/// }
///
/// /// Ein Wert der Ampelkarte, fertig beschriftet.
/// @immutable
/// class Vitalwert {
///   const Vitalwert({
///     required RecoveryMetric metrik,
///     required String name,
///     required String wert,
///     required String bildunterschrift,
///     required CupertinoDynamicColor ton,
///     Normalbalken? balken,
///   });
///
///   final RecoveryMetric metrik;
///   final String name;
///
///   /// „7:00 h", „68 bpm" — oder [keinWert], nie „0".
///   final String wert;
///
///   /// „Normal 6:29 h · Signal unter 6:00 h".
///   final String bildunterschrift;
///
///   /// Unaufgelöst — aufgelöst wird beim Zeichnen.
///   final CupertinoDynamicColor ton;
///
///   /// `null` heißt „kein Normalbereich".
///   final Normalbalken? balken;
///
///   /// Nur der Normalwert, ohne die Schwelle dahinter — kappt am ersten
///   /// „ · ". Siehe die Gruppe „Zwei Längen" unten.
///   String get kurzeBildunterschrift;
/// }
///
/// /// Die Statuskarte als Wert. **Sie verschwindet in keinem Zustand** —
/// /// der Rückgabetyp von [werteStatus] ist deshalb nicht nullbar.
/// @immutable
/// class WerteStatus {
///   const WerteStatus({
///     required String ueberschrift,
///     required String unterzeile,
///     required List<String> absaetze,
///     required CupertinoDynamicColor kante,
///     required bool zeigtHealthEinstellungen,
///     required List<Vitalwert> werte,
///   });
///
///   final String ueberschrift;
///   final String unterzeile;
///
///   /// Der Rat darunter. **Darf leer sein** — die Karte nicht.
///   final List<String> absaetze;
///
///   final CupertinoDynamicColor kante;
///   final bool zeigtHealthEinstellungen;
///
///   /// Immer genau vier, je eine Metrik.
///   final List<Vitalwert> werte;
/// }
///
/// /// Die Statuskarte zu jedem der vier Zustände von [Messwert].
/// WerteStatus werteStatus(Messwert<ErholungDaten> daten);
///
/// /// Eine Zeile von „Die Schwellen": Regel **und** ausgerechneter Wert.
/// @immutable
/// class SchwellenZeile {
///   const SchwellenZeile({
///     required RecoveryMetric metrik,
///     required String titel,
///     required String regel,
///     required String wert,
///   });
///   final RecoveryMetric metrik;
///   final String titel;
///
///   /// „5 bpm über dem Median" — die Zahl aus [RecoveryTrafficLight].
///   final String regel;
///
///   /// „ab 59 bpm" — oder „kein Median".
///   final String wert;
/// }
///
/// /// Vier Zeilen, je Metrik eine. **Nimmt keine [Ziele] entgegen:** Die
/// /// Schlafschwelle hängt nicht am Schlafziel, und was eine Funktion
/// /// nicht bekommt, kann sie nicht einrechnen.
/// List<SchwellenZeile> schwellenZeilen(RecoveryBaseline baseline);
///
/// /// Die drei Zähler unter dem Signalband.
/// @immutable
/// class BandLegende {
///   const BandLegende({
///     required int ohneSignal,
///     required int einSignal,
///     required int zweiUndMehr,
///   });
///   final int ohneSignal;
///   final int einSignal;
///   final int zweiUndMehr;
/// }
///
/// BandLegende bandLegende(List<DaySignals> tage);
///
/// /// Gemessen → `30 + Signale · 14`, nicht gemessen → 10.
/// double bandHoehe(DaySignals tag);
///
/// /// Unaufgelöst — aufgelöst wird beim Zeichnen.
/// CupertinoDynamicColor bandFarbe(DaySignals tag);
/// ```
///
/// ## Was hier geprüft wird — und was nicht
///
/// `CLAUDE.md`: geprüft werden **Zustände und Übergänge**, nicht Layout und
/// Beschriftung. Kein Test schreibt eine Überschrift, eine Unterzeile oder
/// einen Ratsatz wörtlich fest. Wo ein Text eine *Regel* trägt, wird die
/// Regel geprüft:
///
/// - Ohne Median steht „kein Normalbereich" **und** es gibt keinen Balken.
/// - In „Die Schwellen" steht ohne Median „kein Median".
/// - Bei fehlenden Health-Daten kommen **beide** Wörter vor.
/// - Ein fehlender Einzelwert steht als [keinWert], nie als „0".
///
/// **Die Schwellen werden aus `trainings_core` gelesen.** Jede Erwartung
/// dieser Datei rechnet mit [RecoveryTrafficLight.restingHeartRateMargin],
/// `.hrvFactor`, `.respiratoryRateMargin` und `.minimumSleepHours` statt
/// mit 5, 0,8, 1,5 und 6 — wer die Konstante ändert und die Beschriftung
/// vergisst, bekommt hier einen roten Test. Genau das fehlt in Swift, wo
/// die drei Zahlen dreifach im Quelltext stehen und kein Test sie
/// aneinanderbindet.
///
/// **Nicht geprüft, bewusst:**
///
/// - Die Reihenfolge der vier Wertzeilen und der vier Schwellenzeilen.
///   Entwurf (`docs/screens/screens/erholung-werte.js`) und Swift-Vorlage
///   widersprechen sich hier — der Entwurf stellt den Schlaf nach hinten,
///   `RecoveryWording.vitals` baut über `RecoveryMetric.allCases` und
///   stellt ihn nach vorn. Diese Datei verlangt nur, dass **jede Metrik
///   genau einmal** vorkommt; die Reihenfolge ist gemeldet und offen.
/// - Überschrift und Unterzeile der Karte. Der Entwurf schreibt „Gut
///   erholt" / „Schlecht erholt", die Vorlage „Sieht gut aus" / „Achte auf
///   dich". Auch gemeldet, auch offen — und Beschriftung, also ohnehin
///   nichts für einen Test.
/// - Der Ton eines Wertes, der schlechter als sein Median, aber noch kein
///   Signal ist. Der Entwurf sagt grau, die Vorlage `Palette.ink`.
///
/// ## Zahlen in dieser Datei
///
/// Alle erfunden (`CLAUDE.md`).
void main() {
  // Montag, 12.10.2026 — mitten in der Sommerzeit, der Tagesbeginn liegt
  // also auf 22:00 UTC des Vortags. Dass die Daten trotzdem auf dem
  // richtigen Kalendertag landen, ist weiter unten eine eigene Zusicherung.
  final jetzt = DateTime.utc(2026, 10, 12, 7, 15);

  DateTime tag(int t) => BerlinCalendar.startOfDay(DateTime.utc(2026, 10, t));

  RecoveryDay tagwert(
    int t, {
    double? puls = 54,
    double? hrv = 60,
    double? atmung = 14,
  }) => RecoveryDay(
    date: tag(t),
    restingHeartRate: puls,
    hrv: hrv,
    respiratoryRate: atmung,
    exerciseMinutes: 0,
  );

  RecoveryNight nacht(int t, {double stunden = 7}) => RecoveryNight(
    date: tag(t),
    asleepMinutes: stunden * Duration.minutesPerHour,
    bedtime: null,
    awakeMinutes: 0,
    wakeCount: 0,
  );

  /// Neun ruhige Tage vor heute — genug für jeden Median (fünf reichen).
  List<RecoveryDay> vortage() => [for (var t = 3; t <= 11; t++) tagwert(t)];

  List<RecoveryNight> vornaechte() => [for (var t = 3; t <= 11; t++) nacht(t)];

  RecoverySnapshot schnappschuss({
    List<RecoveryDay>? tage,
    List<RecoveryNight>? naechte,
    bool nachOp = false,
  }) => RecoverySnapshot.make(
    days: tage ?? [...vortage(), tagwert(12)],
    nights: naechte ?? [...vornaechte(), nacht(12)],
    today: jetzt,
    sleepGoalHours: 8,
    bedtimeGoalMinutes: 300,
    isPostOperative: nachOp,
  );

  Messwert<ErholungDaten> bekannt(RecoverySnapshot s) => Bekannt<ErholungDaten>(
    ErholungDaten(schnappschuss: s, nacht: null, wochenminuten: null),
    stand: jetzt,
    laeuft: false,
  );

  /// Die vier Lagen, die der Schirm aus echten Daten erzeugen kann.
  final ruhig = schnappschuss();
  final einSignal = schnappschuss(
    // Ruhepuls genau auf der Schwelle — Gleichheit ist bereits ein Signal.
    tage: [
      ...vortage(),
      tagwert(12, puls: 54 + RecoveryTrafficLight.restingHeartRateMargin),
    ],
  );
  final zweiSignale = schnappschuss(
    tage: [
      ...vortage(),
      tagwert(
        12,
        puls: 54 + RecoveryTrafficLight.restingHeartRateMargin,
        hrv: 60 * RecoveryTrafficLight.hrvFactor,
      ),
    ],
  );
  // Heute liegt nichts vor, davor schon — damit trägt `lastSeen` den
  // 11.10.
  final ohneWerte = schnappschuss(tage: vortage(), naechte: vornaechte());
  final nachOp = schnappschuss(nachOp: true);
  // Vier Tage reichen für keinen Median (fünf sind nötig), heute aber
  // liegen Werte vor: Die Karte steht, die Balken fallen weg.
  final ohneMedian = schnappschuss(
    tage: [for (var t = 3; t <= 6; t++) tagwert(t), tagwert(12)],
    naechte: [for (var t = 3; t <= 6; t++) nacht(t), nacht(12)],
  );

  SchwellenZeile schwelleFuer(
    List<SchwellenZeile> zeilen,
    RecoveryMetric metrik,
  ) => zeilen.firstWhere((z) => z.metrik == metrik);

  // ───────────────────────────────────────────────────────────────────────

  group('Die Statuskarte verschwindet in keinem Zustand', () {
    /// Der Kern des Tickets. Eine fehlende Karte hieße gleichzeitig „alles
    /// gut", „die Uhr hat nichts aufgezeichnet" und „die App darf nicht
    /// lesen" — den Unterschied verrät HealthKit nicht, also muss die
    /// Oberfläche ihn aussprechen.
    final alleLagen = <String, Messwert<ErholungDaten>>{
      'ruhig': bekannt(ruhig),
      'ein Signal': bekannt(einSignal),
      'zwei Signale': bekannt(zweiSignale),
      'keine Werte von heute': bekannt(ohneWerte),
      'nach der OP': bekannt(nachOp),
      'ohne Median': bekannt(ohneMedian),
      'noch nie gelesen': const NochNie<ErholungDaten>(),
      'leer nach Lauf': LeerNachLauf<ErholungDaten>(gelaufen: jetzt),
      'Lauf gescheitert': Fehlgeschlagen<ErholungDaten>(
        fehler: Exception('kein Kanal'),
        gelaufen: jetzt,
      ),
    };

    for (final MapEntry(key: name, value: daten) in alleLagen.entries) {
      test('$name: Karte, Überschrift, Unterzeile und vier Werte', () {
        final status = werteStatus(daten);

        expect(status.ueberschrift, isNotEmpty, reason: name);
        expect(status.unterzeile, isNotEmpty, reason: name);
        expect(
          status.werte.map((w) => w.metrik).toSet(),
          RecoveryMetric.values.toSet(),
          reason: '$name: jede Metrik genau einmal',
        );
        expect(status.werte, hasLength(RecoveryMetric.values.length));
        for (final w in status.werte) {
          expect(w.name, isNotEmpty, reason: '$name / ${w.metrik}');
          expect(w.wert, isNotEmpty, reason: '$name / ${w.metrik}');
        }
      });
    }

    test('der Ratabsatz darf fehlen, die Karte nicht', () {
      // `calm` — in Swift gibt `RecoveryWording.advice` hier `nil` zurück.
      expect(werteStatus(bekannt(ruhig)).absaetze, isEmpty);
      expect(werteStatus(bekannt(ruhig)).werte, hasLength(4));
    });
  });

  group('Nur Inhalt und Kantenfarbe wechseln', () {
    test('ruhig ist grün', () {
      expect(werteStatus(bekannt(ruhig)).kante, Palette.ok);
    });

    test('ein oder zwei Signale sind gelb', () {
      expect(werteStatus(bekannt(einSignal)).kante, Palette.bib);
      expect(werteStatus(bekannt(zweiSignale)).kante, Palette.bib);
    });

    test('keine Health-Daten sind grau', () {
      expect(werteStatus(bekannt(ohneWerte)).kante, Palette.rest);
      expect(
        werteStatus(LeerNachLauf<ErholungDaten>(gelaufen: jetzt)).kante,
        Palette.rest,
      );
    });

    test('nach der OP rot', () {
      expect(werteStatus(bekannt(nachOp)).kante, Palette.warn);
    });

    test('die Verdikte sind wirklich die erwarteten', () {
      // Sonst prüften die fünf Tests darüber etwas anderes als ihr Name
      // sagt.
      expect(ruhig.evaluation.verdict, RecoveryVerdict.calm);
      expect(einSignal.evaluation.verdict, RecoveryVerdict.watch);
      expect(zweiSignale.evaluation.verdict, RecoveryVerdict.stressed);
      expect(ohneWerte.evaluation.verdict, RecoveryVerdict.noData);
      expect(nachOp.evaluation.verdict, RecoveryVerdict.postOperative);
      expect(ohneMedian.evaluation.verdict, RecoveryVerdict.calm);
    });
  });

  group('Während des Ladens steht kein „keine Daten"-Grund', () {
    /// `docs/todo/01`, eine Ebene tiefer als der sealed-Typ ihn sonst
    /// abfängt: Die Karte steht auch im Ladezweig, und gerade deshalb darf
    /// sie dort nicht behaupten, es gebe nichts.
    const laedt = NochNie<ErholungDaten>();

    test('kein Grund, kein Weg in die Health-Einstellungen', () {
      final status = werteStatus(laedt);
      final text = [
        status.ueberschrift,
        status.unterzeile,
        ...status.absaetze,
        for (final w in status.werte) w.bildunterschrift,
      ].join(' ').toLowerCase();

      expect(text, isNot(contains('aufgezeichnet')));
      expect(text, isNot(contains('freigegeben')));
      expect(text, isNot(contains('keine daten')));
      expect(status.zeigtHealthEinstellungen, isFalse);
      expect(status.absaetze, isEmpty);
    });

    test('vier Werte als „—", kein Balken, nie eine Null', () {
      for (final w in werteStatus(laedt).werte) {
        expect(w.wert, keinWert, reason: '${w.metrik}');
        expect(w.balken, isNull, reason: '${w.metrik}');
      }
    });

    test('ein gescheiterter Lauf behauptet ebenfalls keine Datenlage', () {
      final status = werteStatus(
        Fehlgeschlagen<ErholungDaten>(
          fehler: Exception('kein Kanal'),
          gelaufen: jetzt,
        ),
      );
      final text = [
        status.ueberschrift,
        status.unterzeile,
        ...status.absaetze,
      ].join(' ').toLowerCase();

      expect(text, isNot(contains('aufgezeichnet')));
      expect(text, isNot(contains('freigegeben')));
      expect(status.zeigtHealthEinstellungen, isFalse);
    });
  });

  group('Fehlen die Werte, werden beide Möglichkeiten benannt', () {
    test('beide Wörter und der Weg in die Health-Einstellungen', () {
      for (final daten in [
        bekannt(ohneWerte),
        LeerNachLauf<ErholungDaten>(gelaufen: jetzt),
      ]) {
        final status = werteStatus(daten);
        final rat = status.absaetze.join(' ').toLowerCase();

        expect(rat, contains('aufgezeichnet'));
        expect(rat, contains('freigegeben'));
        expect(status.zeigtHealthEinstellungen, isTrue);
      }
    });

    test('der Rat steht einmal, nicht zweimal', () {
      // Dieselben Sätze wie im Hinweiskasten des Erholung-Schirms. In Swift
      // stehen die Texte dieses Schirms ein zweites Mal im Quelltext; hier
      // bindet dieser Test sie aneinander.
      final erwartet = erholungHinweis(
        bewertung: const RecoveryEvaluation(
          verdict: RecoveryVerdict.noData,
          signals: [],
          measuredCount: 0,
        ),
        messwerte: const RecoveryReading(),
        baseline: const RecoveryBaseline(),
      )!;

      expect(werteStatus(bekannt(ohneWerte)).absaetze, erwartet.absaetze);
    });

    test('der Rat bei Warnsignalen ebenfalls', () {
      final erwartet = erholungHinweis(
        bewertung: zweiSignale.evaluation,
        messwerte: zweiSignale.reading,
        baseline: zweiSignale.baseline,
      )!;

      expect(werteStatus(bekannt(zweiSignale)).absaetze, erwartet.absaetze);
    });
  });

  group('Ein fehlender Einzelwert', () {
    test('steht als „—", nie als „0"', () {
      for (final w in werteStatus(bekannt(ohneWerte)).werte) {
        expect(w.wert, keinWert, reason: '${w.metrik}');
        expect(w.wert, isNot(contains('0')), reason: '${w.metrik}');
      }
    });

    test('trägt keinen Balken, auch wenn ein Median vorliegt', () {
      // Die Mediane der neun Vortage liegen vor — es fehlt der Wert von
      // heute. Ein Balken ohne Marke wäre dieselbe leere Behauptung wie
      // ein Balken ohne Normalbereich.
      expect(ohneWerte.baseline.restingHeartRate, isNotNull);
      for (final w in werteStatus(bekannt(ohneWerte)).werte) {
        expect(w.balken, isNull, reason: '${w.metrik}');
      }
    });

    test('nennt den zuletzt gesehenen Tag, und zwar den richtigen', () {
      // `lastSeen` ist ein Berliner Tagesbeginn, im Oktober also 22:00 UTC
      // des Vortags. Wer ihn roh formatiert, schreibt den 10.10. hin.
      expect(ohneWerte.lastSeen, tag(11));

      final text = werteStatus(bekannt(ohneWerte)).werte
          .map((w) => w.bildunterschrift)
          .join(' ');

      expect(text, contains(Format.tagMonat(kalendertag(tag(11)))));
      expect(text, isNot(contains(Format.tagMonat(kalendertag(tag(10))))));
    });

    test('ohne jede Vorgeschichte steht kein erfundenes Datum', () {
      final leer = werteStatus(LeerNachLauf<ErholungDaten>(gelaufen: jetzt));
      for (final w in leer.werte) {
        expect(w.bildunterschrift, isNotEmpty, reason: '${w.metrik}');
        expect(w.bildunterschrift, isNot(contains('.2026')));
      }
    });
  });

  group('Fehlt der Median, fällt der Balken ganz weg', () {
    test('kein Balken und „kein Normalbereich" in der Bildunterschrift', () {
      final status = werteStatus(bekannt(ohneMedian));

      for (final w in status.werte) {
        expect(w.balken, isNull, reason: '${w.metrik}');
        expect(
          w.bildunterschrift.toLowerCase(),
          contains('kein normalbereich'),
          reason: '${w.metrik}',
        );
      }
    });

    test('der Wert selbst steht trotzdem da', () {
      // Ohne Normalbereich gibt es nichts zu vergleichen — aber sehr wohl
      // etwas zu zeigen.
      for (final w in werteStatus(bekannt(ohneMedian)).werte) {
        expect(w.wert, isNot(keinWert), reason: '${w.metrik}');
      }
    });

    test('mit Median trägt jeder der vier Werte einen Balken', () {
      for (final w in werteStatus(bekannt(ruhig)).werte) {
        expect(w.balken, isNotNull, reason: '${w.metrik}');
      }
    });

    test('nach der OP bewertet nichts, also auch kein Normalband', () {
      for (final w in werteStatus(bekannt(nachOp)).werte) {
        expect(w.balken, isNull, reason: '${w.metrik}');
      }
    });
  });

  group('Der Balken', () {
    final werte = werteStatus(bekannt(ruhig)).werte;
    Normalbalken balkenFuer(RecoveryMetric m) =>
        werte.firstWhere((w) => w.metrik == m).balken!;

    test('trägt die festen Anzeigeskalen des Tickets', () {
      expect(balkenFuer(RecoveryMetric.sleep).skala, (von: 3.0, bis: 10.0));
      expect(balkenFuer(RecoveryMetric.restingHeartRate).skala, (
        von: 50.0,
        bis: 80.0,
      ));
      expect(balkenFuer(RecoveryMetric.hrv).skala, (von: 25.0, bis: 75.0));
      expect(balkenFuer(RecoveryMetric.respiratoryRate).skala, (
        von: 8.0,
        bis: 16.0,
      ));
    });

    test('der grüne Bereich ist der ohne Warnsignal — aus dem Kern', () {
      // Jede Grenze rechnet mit der Konstante, nicht mit ihrer Zahl.
      expect(balkenFuer(RecoveryMetric.sleep).normalbereich, (
        von: RecoveryTrafficLight.minimumSleepHours,
        bis: 10.0,
      ));
      expect(balkenFuer(RecoveryMetric.restingHeartRate).normalbereich, (
        von: 50.0,
        bis: 54 + RecoveryTrafficLight.restingHeartRateMargin,
      ));
      expect(balkenFuer(RecoveryMetric.hrv).normalbereich, (
        von: 60 * RecoveryTrafficLight.hrvFactor,
        bis: 75.0,
      ));
      expect(balkenFuer(RecoveryMetric.respiratoryRate).normalbereich, (
        von: 8.0,
        bis: 14 + RecoveryTrafficLight.respiratoryRateMargin,
      ));
    });

    test('der grüne Bereich endet nie außerhalb der Skala', () {
      // Ein Median am oberen Rand schöbe die Schwelle sonst aus dem Feld
      // hinaus, und der grüne Balken liefe über die Karte.
      final hoch = schnappschuss(
        tage: [
          for (var t = 3; t <= 11; t++) tagwert(t, puls: 79, atmung: 15.8),
          tagwert(12, puls: 79, atmung: 15.8),
        ],
      );
      for (final w in werteStatus(bekannt(hoch)).werte) {
        final balken = w.balken;
        if (balken == null) continue;
        expect(
          balken.normalbereich.bis,
          lessThanOrEqualTo(balken.skala.bis),
          reason: '${w.metrik}',
        );
        expect(
          balken.normalbereich.von,
          greaterThanOrEqualTo(balken.skala.von),
          reason: '${w.metrik}',
        );
      }
    });

    test('die Marke wird ins Feld geklemmt', () {
      final darueber = schnappschuss(
        tage: [...vortage(), tagwert(12, puls: 95)],
      );
      final darunter = schnappschuss(
        tage: [...vortage(), tagwert(12, puls: 41)],
      );

      final oben = werteStatus(bekannt(darueber)).werte
          .firstWhere((w) => w.metrik == RecoveryMetric.restingHeartRate);
      final unten = werteStatus(bekannt(darunter)).werte
          .firstWhere((w) => w.metrik == RecoveryMetric.restingHeartRate);

      expect(oben.balken!.marke, 95, reason: 'roh bleibt roh');
      expect(oben.balken!.markeAnteil, 1.0);
      expect(unten.balken!.markeAnteil, 0.0);
    });

    test('Marke und Median liegen anteilig richtig', () {
      final mitte = schnappschuss(tage: [...vortage(), tagwert(12, puls: 65)]);
      final balken = werteStatus(bekannt(mitte)).werte
          .firstWhere((w) => w.metrik == RecoveryMetric.restingHeartRate)
          .balken!;

      // Skala 50…80, Marke 65 liegt genau in der Mitte.
      expect(balken.markeAnteil, closeTo(0.5, 0.0001));
      // Median 54 liegt bei (54 − 50) / 30.
      expect(balken.median, 54);
      expect(balken.medianAnteil, closeTo(4 / 30, 0.0001));
      expect(balken.normalbereichAnteil.von, closeTo(0.0, 0.0001));
      expect(
        balken.normalbereichAnteil.bis,
        closeTo(
          (54 + RecoveryTrafficLight.restingHeartRateMargin - 50) / 30,
          0.0001,
        ),
      );
    });
  });

  group('Der Ton eines Wertes', () {
    test('rot heißt Warnsignal, und nur das', () {
      final status = werteStatus(bekannt(zweiSignale));
      final signale = zweiSignale.evaluation.signals;

      expect(signale, isNotEmpty, reason: 'sonst prüft der Test nichts');
      for (final w in status.werte) {
        expect(
          w.ton == Palette.warn,
          signale.contains(w.metrik),
          reason: '${w.metrik}',
        );
      }
    });

    test('ein fehlender Wert ist grau, nicht rot', () {
      for (final w in werteStatus(bekannt(ohneWerte)).werte) {
        expect(w.ton, Palette.muted, reason: '${w.metrik}');
      }
    });

    test('besser als der eigene Median ist grün', () {
      // Mehr Schlaf, höhere HRV, niedrigerer Ruhepuls, ruhigere Atmung.
      final gut = schnappschuss(
        tage: [...vortage(), tagwert(12, puls: 50, hrv: 70, atmung: 12)],
        naechte: [...vornaechte(), nacht(12, stunden: 8)],
      );
      for (final w in werteStatus(bekannt(gut)).werte) {
        expect(w.ton, Palette.ok, reason: '${w.metrik}');
      }
    });

    test('nach der OP bewertet die Farbe nicht mit', () {
      for (final w in werteStatus(bekannt(nachOp)).werte) {
        expect(w.ton, isNot(Palette.warn), reason: '${w.metrik}');
      }
    });
  });

  group('Zwei Längen der Bildunterschrift', () {
    /// Kein Versehen, sondern ein bewusster Zweittext: Auf Heute stehen
    /// vier Werte nebeneinander, und dort brach „Normal 6:29 h · Signal
    /// unter 6:00 h" nach „· Si…" ab. Eine abgeschnittene Schwelle ist
    /// keine Auskunft.
    final werte = werteStatus(bekannt(ruhig)).werte;

    test('die lange nennt Normalwert und Schwelle', () {
      for (final w in werte) {
        expect(w.bildunterschrift, contains(' · '), reason: '${w.metrik}');
      }
    });

    test('die kurze kappt am ersten Trenner', () {
      for (final w in werte) {
        expect(
          w.kurzeBildunterschrift,
          w.bildunterschrift.split(' · ').first,
          reason: '${w.metrik}',
        );
        expect(
          w.kurzeBildunterschrift,
          isNot(contains(' · ')),
          reason: '${w.metrik}',
        );
      }
    });

    test('ohne Trenner bleibt der ganze Satz stehen', () {
      // „kein Normalbereich — zu wenige Messwerte" darf das Kappen nicht
      // auffressen.
      for (final w in werteStatus(bekannt(ohneMedian)).werte) {
        expect(
          w.kurzeBildunterschrift,
          w.bildunterschrift,
          reason: '${w.metrik}',
        );
      }
    });
  });

  group('Die Werte sind deutsch formatiert', () {
    final werte = werteStatus(bekannt(ruhig)).werte;
    String wertVon(RecoveryMetric m) =>
        werte.firstWhere((w) => w.metrik == m).wert;

    test('Schlaf als Stunden und Minuten', () {
      expect(wertVon(RecoveryMetric.sleep), stundenText(7));
    });

    test('die Atemfrequenz mit Komma, nie mit Punkt', () {
      expect(wertVon(RecoveryMetric.respiratoryRate), contains(','));
      expect(wertVon(RecoveryMetric.respiratoryRate), isNot(contains('.')));
    });

    test('Ruhepuls und HRV als ganze Zahlen mit Einheit', () {
      expect(wertVon(RecoveryMetric.restingHeartRate), contains('54'));
      expect(wertVon(RecoveryMetric.hrv), contains('60'));
    });
  });

  group('Die Schwellen', () {
    test('vier Zeilen, je Metrik eine', () {
      final zeilen = schwellenZeilen(ruhig.baseline);
      expect(zeilen, hasLength(RecoveryMetric.values.length));
      expect(
        zeilen.map((z) => z.metrik).toSet(),
        RecoveryMetric.values.toSet(),
      );
      for (final z in zeilen) {
        expect(z.titel, isNotEmpty, reason: '${z.metrik}');
        expect(z.regel, isNotEmpty, reason: '${z.metrik}');
        expect(z.wert, isNotEmpty, reason: '${z.metrik}');
      }
    });

    test('Regel und ausgerechneter Wert stammen aus trainings_core', () {
      final zeilen = schwellenZeilen(ruhig.baseline);

      final puls = schwelleFuer(zeilen, RecoveryMetric.restingHeartRate);
      expect(
        puls.regel,
        contains('${RecoveryTrafficLight.restingHeartRateMargin.round()}'),
      );
      expect(
        puls.wert,
        contains(
          '${(54 + RecoveryTrafficLight.restingHeartRateMargin).round()}',
        ),
      );

      final hrv = schwelleFuer(zeilen, RecoveryMetric.hrv);
      expect(
        hrv.regel,
        contains('${((1 - RecoveryTrafficLight.hrvFactor) * 100).round()}'),
        reason: 'die 20 % sind 1 − hrvFactor, keine zweite Zahl',
      );
      expect(
        hrv.wert,
        contains('${(60 * RecoveryTrafficLight.hrvFactor).round()}'),
      );

      final atmung = schwelleFuer(zeilen, RecoveryMetric.respiratoryRate);
      expect(
        atmung.regel,
        contains(kommazahl(RecoveryTrafficLight.respiratoryRateMargin)),
      );
      expect(
        atmung.wert,
        contains(kommazahl(14 + RecoveryTrafficLight.respiratoryRateMargin)),
      );
    });

    test('die beschriftete Schwelle ist die, ab der die Ampel meldet', () {
      // Der Satz „ab 59 bpm" und das Verhalten der Ampel müssen dasselbe
      // sagen. In Swift sagen sie es dreifach und niemand prüft es.
      final zeile = schwellenZeilen(ruhig.baseline)
          .firstWhere((z) => z.metrik == RecoveryMetric.restingHeartRate);
      final schwelle = 54 + RecoveryTrafficLight.restingHeartRateMargin;

      expect(zeile.wert, contains('${schwelle.round()}'));
      expect(
        RecoveryTrafficLight.evaluate(
          reading: RecoveryReading(restingHeartRate: schwelle),
          baseline: ruhig.baseline,
        ).signals,
        contains(RecoveryMetric.restingHeartRate),
      );
      expect(
        RecoveryTrafficLight.evaluate(
          reading: RecoveryReading(restingHeartRate: schwelle - 1),
          baseline: ruhig.baseline,
        ).signals,
        isNot(contains(RecoveryMetric.restingHeartRate)),
      );
    });

    test('ohne Median steht „kein Median"', () {
      final zeilen = schwellenZeilen(const RecoveryBaseline());
      for (final metrik in [
        RecoveryMetric.restingHeartRate,
        RecoveryMetric.hrv,
        RecoveryMetric.respiratoryRate,
      ]) {
        expect(
          schwelleFuer(zeilen, metrik).wert,
          'kein Median',
          reason: '$metrik',
        );
      }
    });

    test('nur der Schlaf hat eine feste Schwelle', () {
      // Ohne jeden Median — und trotzdem steht hier eine Zahl. Sie kommt
      // aus `RecoveryTrafficLight.minimumSleepHours`, nicht aus dem
      // Schlafziel: `schwellenZeilen` bekommt gar keine `Ziele`, kann sie
      // also nicht einrechnen.
      final schlaf = schwelleFuer(
        schwellenZeilen(const RecoveryBaseline()),
        RecoveryMetric.sleep,
      );

      expect(schlaf.wert, isNot('kein Median'));
      expect(
        schlaf.wert,
        contains(stundenText(RecoveryTrafficLight.minimumSleepHours)),
      );
    });

    test('ein vorhandener Schlafmedian ändert die Schlafschwelle nicht', () {
      final mit = schwelleFuer(
        schwellenZeilen(ruhig.baseline),
        RecoveryMetric.sleep,
      );
      final ohne = schwelleFuer(
        schwellenZeilen(const RecoveryBaseline()),
        RecoveryMetric.sleep,
      );

      expect(ruhig.baseline.sleepHours, isNotNull);
      expect(mit.wert, ohne.wert);
      expect(mit.regel, ohne.regel);
    });
  });

  group('Das Band unterscheidet „kein Signal" von „nicht gemessen"', () {
    DaySignals tagMit(int t, {required int count, required bool gemessen}) =>
        DaySignals(date: tag(t), count: count, measured: gemessen);

    test('gemessen: 30 + Signale · 14', () {
      expect(bandHoehe(tagMit(3, count: 0, gemessen: true)), 30);
      expect(bandHoehe(tagMit(4, count: 1, gemessen: true)), 44);
      expect(bandHoehe(tagMit(5, count: 2, gemessen: true)), 58);
      expect(bandHoehe(tagMit(6, count: 3, gemessen: true)), 72);
      expect(bandHoehe(tagMit(7, count: 4, gemessen: true)), 86);
    });

    test('nicht gemessen: ein Stummel von 10', () {
      expect(bandHoehe(tagMit(8, count: 0, gemessen: false)), 10);
    });

    test('ein grauer Stummel ist etwas anderes als ein grüner Balken', () {
      final stummel = tagMit(8, count: 0, gemessen: false);
      final ruhigerTag = tagMit(3, count: 0, gemessen: true);

      expect(bandFarbe(stummel), Palette.rest);
      expect(bandFarbe(ruhigerTag), Palette.ok);
      expect(bandHoehe(stummel), isNot(bandHoehe(ruhigerTag)));
    });

    test('ein Signal gelb, zwei und mehr rot', () {
      expect(bandFarbe(tagMit(4, count: 1, gemessen: true)), Palette.bib);
      expect(bandFarbe(tagMit(5, count: 2, gemessen: true)), Palette.warn);
      expect(bandFarbe(tagMit(6, count: 5, gemessen: true)), Palette.warn);
    });

    test('die Legende zählt die drei Fälle', () {
      final tage = [
        tagMit(3, count: 0, gemessen: true),
        tagMit(4, count: 0, gemessen: true),
        tagMit(5, count: 1, gemessen: true),
        tagMit(6, count: 2, gemessen: true),
        tagMit(7, count: 3, gemessen: true),
        tagMit(8, count: 0, gemessen: false),
        tagMit(9, count: 0, gemessen: false),
      ];
      final legende = bandLegende(tage);

      expect(legende.ohneSignal, 2);
      expect(legende.einSignal, 1);
      expect(legende.zweiUndMehr, 2);
    });

    test('nicht gemessene Tage zählen in keinem der drei Zähler', () {
      final tage = [
        tagMit(3, count: 0, gemessen: true),
        tagMit(4, count: 0, gemessen: false),
        tagMit(5, count: 0, gemessen: false),
      ];
      final legende = bandLegende(tage);

      expect(
        legende.ohneSignal + legende.einSignal + legende.zweiUndMehr,
        1,
        reason: 'zwei Tage sind weder ruhig noch auffällig — sie sind leer',
      );
    });

    test('die leere Liste zählt dreimal null', () {
      final legende = bandLegende(const []);
      expect(legende.ohneSignal, 0);
      expect(legende.einSignal, 0);
      expect(legende.zweiUndMehr, 0);
    });
  });

  group('Ein Tag des Bands sagt dasselbe wie die Ampel an jenem Tag', () {
    test('die Signalzahl des letzten Bandtags ist die der heutigen Ampel', () {
      // Im Kern gesichert (jeder Bandtag rechnet gegen den Median der Tage
      // davor); hier steht die Zusicherung, damit der Schirm sie nicht
      // wieder einreißt, indem er eigene Zahlen bildet.
      final letzter = zweiSignale.signalHistory.last;

      expect(letzter.date, tag(12));
      expect(letzter.count, zweiSignale.evaluation.signals.length);
      expect(letzter.measured, zweiSignale.evaluation.measuredCount > 0);
    });

    test('das Band ignoriert die OP-Pause — gemessen ist gemessen', () {
      expect(nachOp.signalHistory.map((t) => t.measured), everyElement(isTrue));
      expect(nachOp.evaluation.verdict, RecoveryVerdict.postOperative);
    });
  });
}
