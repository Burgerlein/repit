import 'alcohol_days.dart';
import 'berlin_calendar.dart';
import 'data_window.dart';
import 'recovery_input.dart';
import 'recovery_traffic_light.dart';
import 'sleep_scoring.dart';
import 'training_load.dart';

/// Reihenfolge der Verlaufszeilen.
///
/// **Nicht** dieselbe wie [RecoveryMetric] (Schlaf · Ruhepuls · HRV ·
/// Atemfrequenz): Die hängt an den vier Vierteln des Erholungsrings, diese
/// an der Reihenfolge der Zeilen auf `erholung-werte`. Zwei Verträge, zwei
/// Enums.
enum RecoveryTrendKind {
  sleep,
  hrv,
  restingHeartRate,
  respiratoryRate,
  alcoholDays,
}

/// Eine Verlaufszeile: ein Durchschnitt über das Fenster und die Zahl der
/// Tage, die ihn tragen.
class RecoveryTrend {
  const RecoveryTrend({
    required this.kind,
    required this.average,
    required this.count,
  });

  final RecoveryTrendKind kind;

  /// `null` heißt „keine Werte", nie 0. Die Alkohol-Zeile trägt immer
  /// `null` — ein Durchschnitt über Ja/Nein ist keine Zahl, die jemand lesen
  /// will.
  final double? average;

  final int count;

  @override
  bool operator ==(Object other) =>
      other is RecoveryTrend &&
      other.kind == kind &&
      other.average == average &&
      other.count == count;

  @override
  int get hashCode => Object.hash(kind, average, count);

  @override
  String toString() =>
      'RecoveryTrend(kind: $kind, average: $average, count: $count)';
}

/// Ein Tag im Signalband: wie viele Warnsignale, und ob überhaupt gemessen
/// wurde.
///
/// Beides zusammen, weil „null Signale" und „nicht gemessen" dasselbe
/// zeigen und das Gegenteil voneinander bedeuten.
class DaySignals {
  const DaySignals({
    required this.date,
    required this.count,
    required this.measured,
  });

  final DateTime date;
  final int count;
  final bool measured;

  @override
  bool operator ==(Object other) =>
      other is DaySignals &&
      other.date == date &&
      other.count == count &&
      other.measured == measured;

  @override
  int get hashCode => Object.hash(date, count, measured);

  @override
  String toString() =>
      'DaySignals(date: $date, count: $count, measured: $measured)';
}

/// Der Zustand des Erholungs-Schirms: alles, was Ringkarte, Statuskarte,
/// Signalband und Verlaufszeilen zeigen, einmal gerechnet.
///
/// In Swift liegt diese Rechnung als `Sources/Features/Recovery/RecoverySnapshot.swift`
/// im App-Target und ist vollständig ungetestet — zusammen mit den beiden
/// Regeln, die der Schirm am leichtesten falsch macht:
///
/// 1. **Der heutige Wert gehört nicht in seinen eigenen Median.** Sonst
///    zieht ein Ausreißer seine eigene Schwelle mit sich.
/// 2. **Jeder Tag des Bands wird gegen den Median der Tage davor
///    gerechnet** — sonst zeigt das Band von gestern etwas anderes als die
///    Ampel von gestern. Das ist O(n²) und über dreißig Tage egal.
/// 3. **Wert und Median wechseln gemeinsam.** Seit der Schirm durch die
///    Tage blättert, bezieht sich jede Zahl auf [selectedDay] statt fest
///    auf heute. Eine gemischte Paarung — der Wert von damals gegen den
///    Median von heute — ergäbe zwei plausible Zahlen und eine falsche
///    Ampel, die niemand dem Schirm ansieht. Dagegen steht `pairOf` unten:
///    Es gibt im ganzen Paket **keine** zweite Stelle, an der ein
///    [RecoveryReading] gebaut und einer [RecoveryBaseline] gegenübergestellt
///    wird, und `pairOf` nimmt genau ein Datum.
///
/// **Keine Nutzertexte.** Swift gibt `dateLine`, `Trend.title` und
/// „Zuletzt am Donnerstag, 08.10." als fertige Zeichenketten zurück. Der
/// Kern liefert Zahlen, Daten und Enums; beschriftet wird in den Views.
class RecoverySnapshot {
  const RecoverySnapshot._({
    required this.today,
    required this.selectedDay,
    required this.reading,
    required this.baseline,
    required this.isPostOperative,
    required this.night,
    required this.score,
    required this.days,
    required this.nights,
    required this.trends,
    required this.signalHistory,
    required this.weekMinutes,
    required this.lastSeen,
    required this.alcoholEve,
  });

  /// Rechnet den Schnappschuss aus Tageswerten und Nächten.
  ///
  /// `window` ist der vom Nutzer eingestellte Betrachtungszeitraum; `null`
  /// heißt unbegrenzt. Er **kürzt** das Fenster von `windowDays` Tagen und
  /// verlängert es nie — mehr als dreißig Tage hält der Schirm nicht vor.
  ///
  /// `selectedDay` ist der Tag, auf den sich die Zahlen des Schirms
  /// beziehen; `null` heißt heute. `today` behält daneben seine Bedeutung —
  /// Ende des Fensters, Grenze nach vorn, Bezug für „was ist heute" — und
  /// wird **nicht** umgedeutet.
  static RecoverySnapshot make({
    required List<RecoveryDay> days,
    required List<RecoveryNight> nights,
    required DateTime today,
    DateTime? selectedDay,
    required double sleepGoalHours,
    required double bedtimeGoalMinutes,
    List<DateTime> alcoholDays = const [],
    List<DateTime> alcoholFreeDays = const [],
    bool isPostOperative = false,
    DataWindow? window,
    int windowDays = 30,
  }) {
    final todayStart = BerlinCalendar.startOfDay(today);
    // Die letzten `windowDays` Kalendertage einschließlich heute.
    final defaultStart = BerlinCalendar.addDays(todayStart, 1 - windowDays);
    final limit = window?.start;
    final start = limit != null && limit.isAfter(defaultStart)
        ? limit
        : defaultStart;

    // **Geklemmt, nicht geworfen.** Ein Tag außerhalb des Fensters ist kein
    // Programmierfehler, sondern ein Pfeil, der zu weit gedrückt wurde. Ein
    // Schnappschuss darauf sagte „keine Werte", wo „nie nachgesehen" richtig
    // wäre — der Unterschied zwischen `LeerNachLauf` und `NochNie`, und der
    // darf im Kern nicht verloren gehen.
    final chosen = selectedDay == null
        ? todayStart
        : BerlinCalendar.startOfDay(selectedDay);
    final selected = chosen.isBefore(start)
        ? start
        : chosen.isAfter(todayStart)
        ? todayStart
        : chosen;

    // Ein Zeitstempel aus der Zukunft ist kein Fehler, sondern ein Gerät mit
    // verstellter Uhr — er fällt heraus.
    bool inWindow(DateTime date) {
      final day = BerlinCalendar.startOfDay(date);
      return !day.isBefore(start) && !day.isAfter(todayStart);
    }

    // **Beim Eintritt einmal normalisieren.** `inWindow` rechnet über
    // `BerlinCalendar.startOfDay`, alles danach vergleicht `date` mit `==`.
    // Blieben die hereingereichten Zeitpunkte roh stehen, läge ein Tag
    // desselben Berliner Kalendertags zwar in `days`/`nights`, wäre für
    // `dayOf`, `nightOf`, `baselineBefore` und `weekMinutes` aber
    // unsichtbar — Daten sind da, und die Rechnung sagt „keine Werte".
    // Nach dieser Zeile tragen `days`, `nights`, `signalHistory` und
    // `lastSeen` Berliner Tagesgrenzen, egal was hereinkam.
    //
    // `bedtime` bleibt roh: Das ist ein Zeitpunkt, kein Kalendertag — die
    // Zubettgehzeit auf den Tagesbeginn zu ziehen hieße, sie zu erfinden.
    final windowDaysList = [
      for (final day in days)
        if (inWindow(day.date))
          RecoveryDay(
            date: BerlinCalendar.startOfDay(day.date),
            restingHeartRate: day.restingHeartRate,
            hrv: day.hrv,
            respiratoryRate: day.respiratoryRate,
            exerciseMinutes: day.exerciseMinutes,
          ),
    ]..sort((a, b) => a.date.compareTo(b.date));

    // Das Kriterium sind die Schlafminuten, nicht „keine Abschnitte": Eine
    // Nacht aus lauter Wachabschnitten ist nicht leer, aber auch kein Schlaf.
    final windowNights = [
      for (final night in nights)
        if (night.asleepMinutes > 0 && inWindow(night.date))
          RecoveryNight(
            date: BerlinCalendar.startOfDay(night.date),
            asleepMinutes: night.asleepMinutes,
            bedtime: night.bedtime,
            awakeMinutes: night.awakeMinutes,
            wakeCount: night.wakeCount,
          ),
    ]..sort((a, b) => a.date.compareTo(b.date));

    // Einmal geschnitten und auf die Tagesgrenze gezogen, wie `days` und
    // `nights` darüber. **Nur die Zahl der Verlaufszeile liest hieraus**:
    // Die Auskunft über den Vortag (#268) schlägt roh nach, weil sie von
    // einem einzelnen Tag handelt und nicht vom Zeitraum.
    final windowAlcoholDays = [
      for (final day in alcoholDays)
        if (inWindow(day)) BerlinCalendar.startOfDay(day),
    ];

    RecoveryDay? dayOf(DateTime date) {
      for (final day in windowDaysList) {
        if (day.date == date) return day;
      }
      return null;
    }

    RecoveryNight? nightOf(DateTime date) {
      for (final night in windowNights) {
        if (night.date == date) return night;
      }
      return null;
    }

    /// Die Mediane aus allem, was **vor** diesem Tag liegt. Regel 1 und
    /// Regel 2 in einer Zeile: Der Tag selbst ist nie dabei.
    RecoveryBaseline baselineBefore(DateTime date) => RecoveryBaseline.from(
      days: [
        for (final day in windowDaysList)
          if (day.date.isBefore(date)) day,
      ],
      sleepHours: [
        for (final night in windowNights)
          if (night.date.isBefore(date)) night.asleepHours,
      ],
    );

    /// Wert **und** Median eines Tages, aus einem einzigen Datum.
    ///
    /// Regel 3 im Kopf dieser Datei, als Bauweise statt als Vorsatz: Beide
    /// Hälften der Ampel entstehen hier und nirgends sonst, aus derselben
    /// Variablen. Eine gemischte Paarung ließe sich nur ausdrücken, indem
    /// jemand eine zweite Stelle aufmacht — und die fiele beim Lesen auf.
    (RecoveryReading, RecoveryBaseline) pairOf(DateTime date) {
      final night = nightOf(date);
      final day = dayOf(date);
      return (
        RecoveryReading(
          sleepHours: night?.asleepHours,
          restingHeartRate: day?.restingHeartRate,
          hrv: day?.hrv,
          respiratoryRate: day?.respiratoryRate,
        ),
        baselineBefore(date),
      );
    }

    // **Der Vortag, nicht „zuletzt"** (#268). Alkohol drückt die Erholung
    // der folgenden Nacht; die Frage des Schirms ist deshalb „war am Abend
    // vor dieser Nacht etwas?" und nicht „wann zuletzt". Der Vortag wandert
    // zwangsläufig mit [selectedDay] — das alte Datum tat es nicht und
    // konnte auf einem früheren Tag nach ihm liegen.
    //
    // **Nachgeschlagen wird roh, nicht im Fenster.** Der
    // Betrachtungszeitraum schneidet die *Zahl* der Alkohol-Tage; dies ist
    // eine Auskunft über genau einen Tag. Steht der gewählte Tag am Anfang
    // des Fensters, liegt sein Vortag davor — und was darüber übergeben
    // wurde, zu verschweigen, hieße „nicht erfasst" zu sagen, wo etwas
    // erfasst ist.
    final eve = BerlinCalendar.addDays(selected, -1);
    bool covers(List<DateTime> days) =>
        days.any((day) => BerlinCalendar.startOfDay(day) == eve);
    // Getränke schlagen die gemessene Null: Von zwei Auskünften über
    // denselben Tag ist die belegte die stärkere.
    final alcoholEve = covers(alcoholDays)
        ? AlcoholEve.drinks
        : covers(alcoholFreeDays)
        ? AlcoholEve.noDrinks
        : AlcoholEve.unknown;

    final selectedNight = nightOf(selected);
    final (reading, baseline) = pairOf(selected);

    final signalHistory = [
      for (final day in windowDaysList)
        () {
          final (dayReading, dayBaseline) = pairOf(day.date);
          final evaluation = RecoveryTrafficLight.evaluate(
            reading: dayReading,
            baseline: dayBaseline,
          );
          // Das Band ignoriert `isPostOperative`: Es zeigt, was gemessen
          // wurde, nicht wie die Ampel heute steht. Die Ampel ruht, das
          // Band nicht.
          return DaySignals(
            date: day.date,
            count: evaluation.signals.length,
            measured: evaluation.measuredCount > 0,
          );
        }(),
    ];

    RecoveryTrend trend(RecoveryTrendKind kind, List<double> values) =>
        RecoveryTrend(
          kind: kind,
          average: values.isEmpty
              ? null
              : values.reduce((a, b) => a + b) / values.length,
          count: values.length,
        );

    // Das Fenster **bis einschließlich** des gewählten Tages. Ein Verlauf,
    // der Tage nach ihm mitzählt, ist kein Verlauf von damals — und die
    // Wochenlast eines Mittwochs endet am Mittwoch, nicht am Sonntag.
    // `days`, `nights` und `signalHistory` oben bleiben davon unberührt:
    // Sie beschreiben das Fenster, nicht den Tag.
    final untilSelectedDays = [
      for (final day in windowDaysList)
        if (!day.date.isAfter(selected)) day,
    ];
    final untilSelectedAlcoholDays = [
      for (final day in windowAlcoholDays)
        if (!day.isAfter(selected)) day,
    ];

    // **Und für die vier Messwert-Zeilen das Fenster davor** (#266). Die
    // Zeile stellt zwei Zahlen nebeneinander — „9 Tage · Median 60 ms" —,
    // und bis hierher zählte die erste den gewählten Tag mit, während der
    // Median ihn ausließ: zwei verschieden große Mengen in einer Zeile.
    //
    // Nachgegeben hat der Trend, nicht der Median: Ein Wert, der mit einem
    // Median verglichen wird, der ihn enthält, zieht seinen eigenen
    // Vergleichswert zu sich. Bei dreißig Tagen ist das fast egal, bei
    // fünf nicht. Beide Zahlen meinen jetzt denselben Satz Tage — genau
    // den, den `baselineBefore(selected)` oben schon liest.
    //
    // **Die Alkohol-Zeile zählt weiter bis einschließlich**: Neben ihr
    // steht kein Median, mit dem sie sich widersprechen könnte, und sie
    // beantwortet „wie oft im Zeitraum". Ein Tag, an dem gerade etwas
    // erfasst wurde, gehört in diese Antwort. **Die Wochenlast ebenso** —
    // eine Summe über die Woche ist kein Vergleichswert.
    final beforeSelectedDays = [
      for (final day in untilSelectedDays)
        if (day.date.isBefore(selected)) day,
    ];
    final beforeSelectedNights = [
      for (final night in windowNights)
        if (night.date.isBefore(selected)) night,
    ];

    List<double> valuesOf(double? Function(RecoveryDay day) field) => [
      for (final day in beforeSelectedDays) ?field(day),
    ];

    // „Zuletzt gesehen" interessiert nur, solange am gewählten Tag gar
    // nichts vorliegt. Gesucht wird im Fenster und vor ihm: Mehr steht nicht
    // zur Verfügung, und „seit mindestens dreißig Tagen kein Wert" ist dann
    // der Satz der View für `null`.
    DateTime? lastSeen;
    if (reading == const RecoveryReading()) {
      for (final day in windowDaysList) {
        final measured =
            day.restingHeartRate != null ||
            day.hrv != null ||
            day.respiratoryRate != null;
        if (measured && day.date.isBefore(selected)) lastSeen = day.date;
      }
      for (final night in windowNights) {
        if (!night.date.isBefore(selected)) continue;
        if (lastSeen == null || night.date.isAfter(lastSeen)) {
          lastSeen = night.date;
        }
      }
    }

    return RecoverySnapshot._(
      today: todayStart,
      selectedDay: selected,
      reading: reading,
      baseline: baseline,
      isPostOperative: isPostOperative,
      night: selectedNight,
      score: selectedNight == null
          ? null
          : SleepScoring.score(
              asleepHours: selectedNight.asleepHours,
              goalHours: sleepGoalHours,
              bedtimeMinutes: selectedNight.bedtime == null
                  ? null
                  : EveningClock.minutesSinceEvening(selectedNight.bedtime!),
              bedtimeGoalMinutes: bedtimeGoalMinutes,
              awakeMinutes: selectedNight.awakeMinutes,
              wakeCount: selectedNight.wakeCount,
            ),
      days: windowDaysList,
      nights: windowNights,
      trends: [
        trend(RecoveryTrendKind.sleep, [
          for (final night in beforeSelectedNights) night.asleepHours,
        ]),
        trend(RecoveryTrendKind.hrv, valuesOf((day) => day.hrv)),
        trend(
          RecoveryTrendKind.restingHeartRate,
          valuesOf((day) => day.restingHeartRate),
        ),
        trend(
          RecoveryTrendKind.respiratoryRate,
          valuesOf((day) => day.respiratoryRate),
        ),
        RecoveryTrend(
          kind: RecoveryTrendKind.alcoholDays,
          average: null,
          count: untilSelectedAlcoholDays.length,
        ),
      ],
      signalHistory: signalHistory,
      // Über die geklippten Tage: Wer den Betrachtungszeitraum auf drei Tage
      // stellt, sieht auch nur drei Tage Wochenlast. Eine Zahl, die Tage
      // mitzählt, die der Nutzer ausgeblendet hat, wäre eine andere Zahl als
      // jede andere auf dem Schirm.
      weekMinutes: TrainingLoad.weekMinutes(
        days: untilSelectedDays,
        containing: selected,
      ),
      lastSeen: lastSeen,
      alcoholEve: alcoholEve,
    );
  }

  /// Berliner Tagesbeginn von heute: Ende des Fensters, Grenze nach vorn,
  /// Bezug für „was ist heute".
  final DateTime today;

  /// Berliner Tagesbeginn des Tages, auf den sich [reading], [baseline],
  /// [night], [score], [trends], [weekMinutes], [lastSeen] und [evaluation]
  /// beziehen — ins Fenster geklemmt. Ohne `selectedDay` gleich [today].
  final DateTime selectedDay;

  /// Die Messwerte des gewählten Tages.
  final RecoveryReading reading;

  /// Die Mediane aus allem **vor** dem gewählten Tag.
  final RecoveryBaseline baseline;

  final bool isPostOperative;

  /// Die Nacht des gewählten Tages — die Nacht mit seinem Datum und mit
  /// Schlafminuten.
  final RecoveryNight? night;

  /// Ihr Score.
  final SleepScore? score;

  /// Die Tage im Fenster, älteste zuerst, `date` auf dem Berliner
  /// Tagesbeginn — auch wenn hereingereicht wurde, was wollte. Ein
  /// Diagramm, das daraus seine x-Achse baut, bekommt damit gleich lange
  /// Abstände.
  final List<RecoveryDay> days;

  /// Die Nächte im Fenster mit Schlafminuten, älteste zuerst, `date`
  /// ebenfalls auf dem Tagesbeginn.
  final List<RecoveryNight> nights;

  /// Die fünf Verlaufszeilen in der Reihenfolge von [RecoveryTrendKind].
  ///
  /// Die vier Messwert-Zeilen rechnen über das Fenster **vor**
  /// [selectedDay] — denselben Satz Tage wie [baseline] (#266). Beide
  /// Zahlen einer Zeile meinen damit dieselbe Menge; der Wert des Tages
  /// steht daneben und nicht in seiner eigenen Grundlage.
  ///
  /// Die **Alkohol-Zeile** zählt dagegen bis **einschließlich**
  /// [selectedDay]: Neben ihr steht kein Median, und sie beantwortet
  /// „wie oft im Zeitraum".
  final List<RecoveryTrend> trends;

  /// Je ein Eintrag für jeden Tag in [days], älteste zuerst — also über das
  /// ganze Fenster, unabhängig von [selectedDay].
  final List<DaySignals> signalHistory;

  /// Die Trainingsminuten der Woche, in der [selectedDay] liegt, bis
  /// einschließlich dieses Tages.
  final double weekMinutes;

  /// Wann zuletzt ein Wert ankam, als Tagesgrenze — nur gesetzt, wenn am
  /// gewählten Tag gar nichts vorliegt.
  final DateTime? lastSeen;

  /// Ob am **Vortag** von [selectedDay] Alkohol erfasst ist (#268) — die
  /// Frage, die der Erholungs-Schirm stellt, seit „zuletzt am …" entfallen
  /// ist.
  ///
  /// Wandert mit [selectedDay], anders als das alte Datum: Der Vortag kann
  /// gar nicht nach dem gewählten Tag liegen. Die **Zahl** der Alkohol-Tage
  /// in der Verlaufszeile beantwortet weiter eine andere Frage — wie oft im
  /// Zeitraum — und steht deshalb getrennt daneben.
  final AlcoholEve alcoholEve;

  RecoveryEvaluation get evaluation => RecoveryTrafficLight.evaluate(
    reading: reading,
    baseline: baseline,
    isPostOperative: isPostOperative,
  );
}
