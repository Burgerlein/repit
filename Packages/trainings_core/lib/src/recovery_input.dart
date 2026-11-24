/// Die Eingabetypen der Erholungs-Rechnung: ein Kalendertag und eine Nacht,
/// jeweils mit genau den Werten, die Ampel, Median, Wochenlast, Schlaf-Score
/// und Schnappschuss brauchen — und keinem mehr.
///
/// **Warum eigene, schlanke Typen.** Die App hat bereits `DailyMetrics` und
/// `SleepNight` in `app/lib/health/health_types.dart`, mit dreizehn Feldern
/// aus HealthKit, dem Tag als Zeichenkette und dem Ruhepuls als `int?`. Diese
/// Datei importiert ihrerseits `package:trainings_core/trainings_core.dart`;
/// ein gleichnamiger Export aus dem Barrel wäre ein Namenskonflikt und bräche
/// die App beim Übersetzen. Der Kern bekommt deshalb eigene Typen, und die
/// App bildet ihre auf sie ab.
///
/// Gerechnet wird durchgehend in `double`, weil jede Schwelle ein `double`
/// ist — `restingHeartRate` ist hier kein `int`.
library;

/// Ein Kalendertag mit den Tageswerten der Erholung.
///
/// `date` bezeichnet einen Berliner Kalendertag. Am liebsten gleich als
/// Tagesbeginn (`BerlinCalendar.startOfDay`) — aber **niemand muss sich
/// darauf verlassen, dass der Aufrufer das tut**: `RecoverySnapshot.make`
/// normalisiert beim Eintritt und gibt in `days`, `nights`,
/// `signalHistory` und `lastSeen` ausschließlich Tagesgrenzen zurück. Ein
/// beliebiger Zeitpunkt desselben Kalendertags ist deshalb derselbe Tag,
/// nicht ein unsichtbarer. `null` heißt überall „kein Wert" —
/// ob nichts aufgezeichnet wurde oder der Lesezugriff fehlt, verrät HealthKit
/// nicht, und eine Lücke ist nie eine Null.
class RecoveryDay {
  const RecoveryDay({
    required this.date,
    this.restingHeartRate,
    this.hrv,
    this.respiratoryRate,
    this.exerciseMinutes,
  });

  final DateTime date;
  final double? restingHeartRate;
  final double? hrv;
  final double? respiratoryRate;
  final double? exerciseMinutes;

  @override
  bool operator ==(Object other) =>
      other is RecoveryDay &&
      other.date == date &&
      other.restingHeartRate == restingHeartRate &&
      other.hrv == hrv &&
      other.respiratoryRate == respiratoryRate &&
      other.exerciseMinutes == exerciseMinutes;

  @override
  int get hashCode => Object.hash(
    date,
    restingHeartRate,
    hrv,
    respiratoryRate,
    exerciseMinutes,
  );

  @override
  String toString() =>
      'RecoveryDay(date: $date, restingHeartRate: $restingHeartRate, '
      'hrv: $hrv, respiratoryRate: $respiratoryRate, '
      'exerciseMinutes: $exerciseMinutes)';
}

/// Eine Nacht mit den Werten, die Score und Schnappschuss brauchen.
///
/// `date` ist der Tag des **Aufwachens**, wie bei [RecoveryDay] als
/// Berliner Kalendertag zu lesen und von `RecoverySnapshot.make` auf den
/// Tagesbeginn normalisiert. `bedtime` ist der Zeitpunkt des Einschlafens
/// und bleibt roh — ein Zeitpunkt, kein Kalendertag; `null`, wenn er nicht
/// vorliegt, dann entfällt die Teilnote Zubettgehzeit, sie wird nicht mit
/// null bewertet.
class RecoveryNight {
  const RecoveryNight({
    required this.date,
    required this.asleepMinutes,
    this.bedtime,
    this.awakeMinutes = 0,
    this.wakeCount = 0,
  });

  final DateTime date;
  final double asleepMinutes;
  final DateTime? bedtime;
  final double awakeMinutes;
  final int wakeCount;

  /// Die Schlafzeit in Stunden — die Einheit, in der Ampel und Score rechnen.
  double get asleepHours => asleepMinutes / Duration.minutesPerHour;

  @override
  bool operator ==(Object other) =>
      other is RecoveryNight &&
      other.date == date &&
      other.asleepMinutes == asleepMinutes &&
      other.bedtime == bedtime &&
      other.awakeMinutes == awakeMinutes &&
      other.wakeCount == wakeCount;

  @override
  int get hashCode =>
      Object.hash(date, asleepMinutes, bedtime, awakeMinutes, wakeCount);

  @override
  String toString() =>
      'RecoveryNight(date: $date, asleepMinutes: $asleepMinutes, '
      'bedtime: $bedtime, awakeMinutes: $awakeMinutes, '
      'wakeCount: $wakeCount)';
}
