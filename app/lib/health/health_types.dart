import 'package:trainings_core/trainings_core.dart';

/// Tageswerte aus HealthKit, ein Eintrag je Kalendertag.
///
/// Entspricht eins zu eins `DailyMetrics` aus
/// `Packages/TrainingsCore/Sources/TrainingsCore/Health/HealthTypes.swift`
/// — 14 nullbare Felder plus `tag`, der ISO-Tagesschlüssel
/// (`BerlinCalendar.dayKey(...)` auf beiden Seiten).
///
/// **`ausMap` liest nur vorhandene Schlüssel.** Ein fehlendes Feld bleibt
/// `null`, kein `?? 0` an irgendeiner Stelle — siehe Spec 8.2 und
/// `test/health/channel_codec_test.dart`. Ein Feld mit falschem Typ lässt
/// `ausMap` werfen: Das ist ein Vertragsbruch des Kanals
/// (`HealthChannel.alsMap` auf der Swift-Seite), kein normaler
/// "kein Messwert"-Zustand.
class DailyMetrics {
  final String tag;
  final int? steps;
  final int? activeKcal;
  final int? basalKcal;
  final int? restingHR;
  final double? hrvMs;
  final double? respRate;
  final double? vo2max;
  final double? weightKg;
  final double? bodyFatPct;
  final double? leanKg;
  final double? exerciseMinutes;
  final int? standHours;
  final int? recoveryHRDrop;

  /// Alkoholische Getränke des Tages (#125) — eine Zahl, keine Menge.
  ///
  /// Apple Health hat keinen Nährwert Alkohol; der einzige Tagebuch-Typ ist
  /// `NumberOfAlcoholicBeverages` mit der Einheit `count`. `double`, weil
  /// ein Tagebuch ein halbes Getränk eintragen darf.
  ///
  /// `null` heißt „kein Wert" und **nie** „nichts getrunken": Der Typ legt
  /// nur dann eine Probe an, wenn etwas getrunken wurde — und eine fehlende
  /// Freigabe sieht genauso aus.
  final double? alcoholicDrinks;

  const DailyMetrics({
    required this.tag,
    this.steps,
    this.activeKcal,
    this.basalKcal,
    this.restingHR,
    this.hrvMs,
    this.respRate,
    this.vo2max,
    this.weightKg,
    this.bodyFatPct,
    this.leanKg,
    this.exerciseMinutes,
    this.standHours,
    this.recoveryHRDrop,
    this.alcoholicDrinks,
  });

  factory DailyMetrics.ausMap(Map<Object?, Object?> map) {
    int? feldInt(String schluessel) =>
        map.containsKey(schluessel) ? map[schluessel] as int : null;
    double? feldDouble(String schluessel) =>
        map.containsKey(schluessel) ? map[schluessel] as double : null;

    return DailyMetrics(
      tag: map['tag'] as String,
      steps: feldInt('steps'),
      activeKcal: feldInt('activeKcal'),
      basalKcal: feldInt('basalKcal'),
      restingHR: feldInt('restingHR'),
      hrvMs: feldDouble('hrvMs'),
      respRate: feldDouble('respRate'),
      vo2max: feldDouble('vo2max'),
      weightKg: feldDouble('weightKg'),
      bodyFatPct: feldDouble('bodyFatPct'),
      leanKg: feldDouble('leanKg'),
      exerciseMinutes: feldDouble('exerciseMinutes'),
      standHours: feldInt('standHours'),
      recoveryHRDrop: feldInt('recoveryHRDrop'),
      alcoholicDrinks: feldDouble('alcoholicDrinks'),
    );
  }
}

/// Der ISO-Tag (`tag`, z. B. `'2026-10-23'`) als `DateTime` (Berliner
/// Mitternacht, als UTC-Zeitpunkt) — für Typen, deren Dart-Gegenstück ein
/// echtes Datum statt eines Strings trägt (`SleepNight`, anders als
/// `DailyMetrics.tag`, siehe dort).
///
/// Öffentlich, weil der Schlaf-Cache (`lib/data/cache_repository.dart`,
/// #113) denselben Rückweg braucht: Er legt Nächte unter ihrem
/// Tagesschlüssel ab und baut daraus beim Lesen wieder ein `SleepNight`.
/// Dieselbe Rechnung an einer Stelle statt zweimal nebeneinander —
/// `DateTime.parse` allein läge je nach Jahreszeit ein bis zwei Stunden
/// daneben.
DateTime datumAusTag(String tag) {
  final teile = tag.split('-').map(int.parse).toList();
  return BerlinCalendar.startOfDay(DateTime.utc(teile[0], teile[1], teile[2]));
}

/// Werte, die als einzelne Messpunkte gebraucht werden — für die Spannen im
/// Schlaf und für die Nachtwerte (#193). Alles andere kommt als Tageswert.
///
/// Dart-Gegenstück zu
/// `Packages/TrainingsCore/Sources/TrainingsCore/Health/HealthReading.swift`.
/// **Die Namen müssen buchstabengleich zu den Swift-Fällen sein**:
/// `health_channel.dart` schickt `kind.name` über den Kanal, und
/// `HealthChannel.vitalKind` auf der Swift-Seite vergleicht gegen genau diese
/// Zeichenkette. Ein umbenannter Fall hier macht die Abfrage drüben zu
/// `badArgs`.
///
/// Die HRV steht hier, obwohl `DailyMetrics.hrvMs` sie auch führt: Das ist
/// Apples Tagesmittel und damit genau der Fehler aus #193. Der Nachtwert
/// braucht die Einzelproben im Schlaffenster. Die Einheit — Millisekunden,
/// nicht Schläge je Minute — entscheidet sich auf der Swift-Seite
/// (`VitalKind.unit` in `app/ios/Runner/HealthKitReading.swift`); hier kommen
/// nur noch Zahlen an.
enum VitalKind { heartRate, respiratoryRate, heartRateVariability }

/// Ein einzelner Messpunkt — Rückgabetyp von **beiden** `quantitySamples`
/// **und** `hourlySteps` (derselbe Typ, eine Methode mehr braucht keine
/// zweite Prüfung, siehe `HealthChannelExtendedCodecTests.swift`). Beide
/// Felder sind nicht optional.
class QuantitySample {
  final DateTime date;
  final double value;

  const QuantitySample({required this.date, required this.value});

  factory QuantitySample.ausMap(Map<Object?, Object?> map) => QuantitySample(
    date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
    value: (map['value'] as num).toDouble(),
  );
}

/// Schlafphase. Dart-Gegenstück zu `SleepStage`
/// (`Packages/TrainingsCore/Sources/TrainingsCore/Sleep/SleepSession.swift`).
enum SleepStage { awake, rem, core, deep, unspecified }

/// Ein Abschnitt einer Nacht mit einer einzigen Phase.
class SleepSegment {
  final SleepStage stage;
  final DateTime start;
  final DateTime end;

  const SleepSegment({required this.stage, required this.start, required this.end});

  factory SleepSegment.ausMap(Map<Object?, Object?> map) => SleepSegment(
    stage: SleepStage.values.byName(map['stage'] as String),
    start: DateTime.fromMillisecondsSinceEpoch(map['start'] as int),
    end: DateTime.fromMillisecondsSinceEpoch(map['end'] as int),
  );
}

/// Eine zusammenhängende Schlafphase — eine Nacht oder ein Nickerchen. Die
/// Gruppierung roher Abschnitte zu Nächten (`SleepGrouping` auf der
/// Swift-Seite) passiert **nicht** hier: Der Kanal liefert bereits
/// gruppierte Nächte, die Dart-Seite baut hier nur noch die Werttypen aus
/// der Map zusammen.
class SleepSession {
  final List<SleepSegment> segments;

  SleepSession({required List<SleepSegment> segments})
    : segments = List.unmodifiable(
        [...segments]..sort((a, b) => a.start.compareTo(b.start)),
      );

  bool get isEmpty => segments.isEmpty;
}

/// Eine Nacht mit dem Tag, zu dem sie zählt: dem Tag des Aufwachens.
///
/// Dart-Gegenstück zu `SleepNight`
/// (`Packages/TrainingsCore/Sources/TrainingsCore/Sleep/SleepSession.swift`).
class SleepNight {
  final DateTime date;
  final SleepSession session;
  /// Tagschlaf desselben Tages. Zählt nicht in `session`.
  final List<SleepSession> naps;

  const SleepNight({
    required this.date,
    required this.session,
    this.naps = const [],
  });

  factory SleepNight.ausMap(Map<Object?, Object?> map) {
    List<SleepSegment> segmenteAus(Object? rohesSegmente) =>
        ((rohesSegmente as List?) ?? const [])
            .map((e) => SleepSegment.ausMap(e! as Map<Object?, Object?>))
            .toList();

    final naps = ((map['naps'] as List?) ?? const [])
        .map(
          (e) => SleepSession(
            segments: segmenteAus((e! as Map<Object?, Object?>)['segments']),
          ),
        )
        .toList();

    return SleepNight(
      date: datumAusTag(map['tag'] as String),
      session: SleepSession(segments: segmenteAus(map['segments'])),
      naps: naps,
    );
  }
}

/// Art des Trainings. Dart-Gegenstück zu `WorkoutKind`
/// (`Packages/TrainingsCore/Sources/TrainingsCore/Health/HealthTypes.swift`).
/// Die Namen entsprechen eins zu eins den Swift-`rawValue`s — `WorkoutKind.
/// values.byName(...)` liest den Kanalwert deshalb direkt.
enum WorkoutKind { running, walking, cycling, strength, swimming, soccer, other }

/// Ein einzelnes Training.
///
/// **`km`/`avgHR`/`maxHR` sind optional** — ein Spaziergang ohne GPS hat kein
/// `km`, ein Training ohne Herzfrequenzmessung kein `avgHR`/`maxHR`. Genau
/// das prüft `workout_codec_test.dart`: Ein fehlendes Feld fehlt in der Map
/// und bleibt `null`, kein `?? 0`/`?? 0.0`. `wasUserEntered` ist dagegen
/// nicht optional (`HealthTypes.swift`).
///
/// `id` bleibt ein roher `String` (keine UUID-Bibliothek nötig) — der Kanal
/// schickt ohnehin nur eine Zeichenkette, siehe `HealthChannel.alsMap(_:
/// WorkoutSample)` auf der Swift-Seite.
class WorkoutSample {
  final String id;
  final DateTime start;
  final WorkoutKind kind;
  final double minutes;
  final double? km;
  final int? avgHR;
  final int? maxHR;
  final bool wasUserEntered;

  const WorkoutSample({
    required this.id,
    required this.start,
    required this.kind,
    required this.minutes,
    this.km,
    this.avgHR,
    this.maxHR,
    this.wasUserEntered = false,
  });

  factory WorkoutSample.ausMap(Map<Object?, Object?> map) {
    double? feldDouble(String schluessel) => map.containsKey(schluessel)
        ? (map[schluessel] as num).toDouble()
        : null;
    int? feldInt(String schluessel) =>
        map.containsKey(schluessel) ? map[schluessel] as int : null;

    return WorkoutSample(
      id: map['id'] as String,
      start: DateTime.fromMillisecondsSinceEpoch(map['start'] as int),
      kind: WorkoutKind.values.byName(map['kind'] as String),
      minutes: (map['minutes'] as num).toDouble(),
      km: feldDouble('km'),
      avgHR: feldInt('avgHR'),
      maxHR: feldInt('maxHR'),
      wasUserEntered: map['wasUserEntered'] as bool,
    );
  }
}

/// Eine Mahlzeit aus Apple Health, wie der Kanal sie liefert — **ohne**
/// die Mahlzeiten, die diese App selbst geschrieben hat: Die filtert die
/// Swift-Seite an ihrer Quelle heraus (#283).
///
/// **Jeder Nährwert ist nullbar (#232).** Bis zum 04.11.2026 waren hier
/// vier Pflichtfelder, und die Swift-Seite füllte fehlende mit `0`
/// (`.reduce(0, +)` über eine leere Liste) — eine Mahlzeit, die nur Eiweiß
/// trug, stand mit 0 kcal da. Ein fehlender Wert fehlt jetzt in der Map
/// und ist hier `null`; eine echte `0` bleibt `0`.
///
/// Die Feldnamen sind die Schlüssel des Kanals, buchstabengleich zu
/// `HealthNutrition.fields` in `app/ios/Runner/HealthNutritionWriting.swift`.
/// `kcal` ist ein `double?`, kein `int`: Eine Rundung an der Kanalgrenze
/// hat niemand beschlossen.
class NutritionEntry {
  final DateTime time;
  final String name;
  final double? kcal;
  final double? proteinG;
  final double? carbsG;
  final double? fatG;
  final double? saturatedFatG;
  final double? sugarG;
  final double? fiberG;
  final double? waterMl;

  const NutritionEntry({
    required this.time,
    required this.name,
    this.kcal,
    this.proteinG,
    this.carbsG,
    this.fatG,
    this.saturatedFatG,
    this.sugarG,
    this.fiberG,
    this.waterMl,
  });

  /// `time` und `name` sind Pflicht — fehlt eines, ist das ein
  /// Vertragsbruch der Swift-Seite, und es wirft. Ein Nährwert darf fehlen;
  /// steht er da, muss er eine Zahl sein. **Ein falscher Typ wirft**, statt
  /// still `null` zu werden.
  factory NutritionEntry.ausMap(Map<Object?, Object?> map) {
    double? feld(String schluessel) {
      if (!map.containsKey(schluessel)) return null;
      final wert = map[schluessel];
      if (wert is! num) {
        throw ArgumentError.value(wert, schluessel, 'keine Zahl');
      }
      return wert.toDouble();
    }

    return NutritionEntry(
      time: DateTime.fromMillisecondsSinceEpoch(map['time'] as int),
      name: map['name'] as String,
      kcal: feld('kcal'),
      proteinG: feld('proteinG'),
      carbsG: feld('carbsG'),
      fatG: feld('fatG'),
      saturatedFatG: feld('saturatedFatG'),
      sugarG: feld('sugarG'),
      fiberG: feld('fiberG'),
      waterMl: feld('waterMl'),
    );
  }
}

/// HealthKit hat eine Mahlzeit **endgültig** abgelehnt (#283) — der
/// Eintrag wird `nicht_moeglich` und nicht erneut versucht.
///
/// Kommt aus dem Kanalfehler `write_rejected`; welche HealthKit-Fehler
/// endgültig sind, entscheidet die Swift-Seite
/// (`HealthNutrition.isPermanentWriteRejection`). Jeder andere Fehler aus
/// `writeMeal` lässt den Eintrag `offen`, und der Nachlauf versucht es
/// wieder.
class HealthWriteRejected implements Exception {
  HealthWriteRejected([this.message]);

  final String? message;

  @override
  String toString() => message == null
      ? 'HealthWriteRejected'
      : 'HealthWriteRejected: $message';
}

/// Ob die App nach Apple Health **schreiben** darf (#270).
///
/// Anders als beim Lesen gibt Apple hier ehrlich Auskunft:
/// `HKHealthStore.authorizationStatus(for:)` ist für `toShare`-Typen
/// aussagekräftig. Der Schirm darf „nicht erlaubt" deshalb benennen, statt
/// zu raten — das ist der eine Ort, an dem die Hausregel „keine Daten und
/// nicht erlaubt sind nicht unterscheidbar" nicht gilt.
///
/// [notDetermined] ist der weggewischte Dialog. Geschrieben wird allein bei
/// [granted]; die beiden anderen Fälle behandelt das Blatt gleich, aber sie
/// bleiben getrennt, weil nur einer von ihnen durch Nachfragen noch zu
/// [granted] werden kann.
enum WriteAuthorization { granted, denied, notDetermined }

/// Eine einzelne Wägung, so wie HealthKit sie führt (#270).
///
/// **Warum es den Typ neben `DailyMetrics.weightKg` gibt:** Die Tageswerte
/// kommen aus einer `HKStatisticsCollectionQuery`, und eine Statistik trägt
/// weder Metadaten noch die Uhrzeit noch die UUID. „Letzte Messungen"
/// braucht alle drei — das Kennzeichen, die Sortierung innerhalb eines
/// Tages und, zum Löschen, die UUID. `DailyMetrics.weightKg` bleibt
/// daneben unverändert.
///
/// Verbindlich festgelegt durch `app/test/health/weight_sample_codec_test.dart`.
class WeightSample {
  /// Die HealthKit-UUID. Roher `String` wie [WorkoutSample.id] — der Kanal
  /// schickt ohnehin nur eine Zeichenkette, und sie ist das, was
  /// `deleteWeight` später braucht.
  final String id;

  /// Der Zeitpunkt der Wägung. Bei einer Probe ist `start == end`, es kommt
  /// also nur einer über den Kanal.
  final DateTime date;

  final double kg;

  /// `HKMetadataKeyWasUserEntered` — **nicht** unsere Buchhaltung. Damit
  /// trägt das Kennzeichen auch für Werte, die direkt in der Health-App
  /// eingetragen wurden.
  final bool wasUserEntered;

  WeightSample({
    required this.id,
    required this.date,
    required this.kg,
    required this.wasUserEntered,
  });

  /// **Kein Feld ist optional.** Alle vier liegen an jeder
  /// `HKQuantitySample` vor; fehlt eines, ist das ein Vertragsbruch der
  /// Swift-Seite und keine Datenlage. Deshalb wird hier geworfen und nichts
  /// ersetzt — besonders bei `wasUserEntered`: Ein `?? false` nähme der
  /// Zeile still ihre Tür, und „von Hand eingetragen" sähe aus wie „von der
  /// Waage".
  factory WeightSample.ausMap(Map<Object?, Object?> map) => WeightSample(
    id: map['id'] as String,
    date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
    kg: (map['kg'] as num).toDouble(),
    wasUserEntered: map['wasUserEntered'] as bool,
  );

  /// Eine Liste davon ist Abhängigkeit eines Providers. Ohne Wertgleichheit
  /// wäre jede neu gelesene Liste ungleich der vorigen und jeder abgeleitete
  /// Wert liefe neu — Fehler `03`, wortgleich im neuen Code.
  @override
  bool operator ==(Object other) =>
      other is WeightSample &&
      other.id == id &&
      other.date == date &&
      other.kg == kg &&
      other.wasUserEntered == wasUserEntered;

  @override
  int get hashCode => Object.hash(id, date, kg, wasUserEntered);
}

/// Körpergröße und Geburtsjahr aus Apple Health (#306) — die beiden
/// Angaben, ohne die `kalorienziel` aus `trainings_core` **nichts**
/// rechnet: Mifflin-St Jeor braucht Gewicht, Größe und Alter.
///
/// **Ein Merkmal ist kein Sample.** `HKCharacteristicTypeIdentifierDateOfBirth`
/// hat kein Zeitfenster, keine Statistik und keine Quelle, die
/// zusammenzuführen wäre; deshalb liegt dieser Typ hinter einem eigenen
/// Protokoll ([BodyCharacteristicsReading]) und nicht hinter einer achten
/// Methode an `HealthReading`.
///
/// **Beide Felder sind nullbar, und kein fehlender Wert wird je `0`.** Ein
/// Mensch mit 0 cm ist kein fehlender Wert, sondern eine falsche Auskunft —
/// Fehler `01` eine Schicht tiefer.
class BodyCharacteristics {
  const BodyCharacteristics({this.heightCm, this.birthYear});

  /// **Der Codec urteilt nicht über Plausibilität.** Eine `0` kommt hier
  /// unverändert als `0.0` durch; er bildet ab, was drüben stand. Dass eine
  /// 0 nie als eingetragene Körpergröße in den Stammdaten landet, ist die
  /// Zusage der Schicht darüber (`stammdatenAusHealthProvider`). Beides
  /// zusammen ergibt den Vertrag aus `CLAUDE.md`: `nil` wird nie `0`, und
  /// `0` wird nie ein eingetragener Wert.
  ///
  /// Ein **falscher Typ wirft** — das ist ein Programmierfehler im Kanal,
  /// keine Datenlage, und darf nicht wie ein harmloses Fehlen aussehen.
  factory BodyCharacteristics.ausMap(Map<Object?, Object?> map) =>
      BodyCharacteristics(
        // `as num?` wie bei `WorkoutSample.ausMap`: Welche Zahlenart der
        // Standard-Codec für eine glatte Größe wählt, ist keine Aussage
        // über die Datenlage.
        heightCm: (map['heightCm'] as num?)?.toDouble(),
        birthYear: map['birthYear'] as int?,
      );

  /// Körpergröße in Zentimetern, **ungerundet**. HealthKit liefert eine
  /// Länge als `HKQuantity`; 1,806 m sind 180,6 cm. Gerundet wird genau
  /// einmal, dort, wo der Wert in `Stammdaten.groesseCm` (ein `int`)
  /// landet. Zweimal runden hieße, zwei Stellen zu haben, an denen ein
  /// halber Zentimeter verschwinden kann.
  final double? heightCm;

  /// Das Geburts**jahr**, schon auf der Swift-Seite aus den
  /// `DateComponents` herausgelöst. Ein volles Datum wäre eine Angabe mehr,
  /// als die Formel trägt — und eine Angabe mehr, die in jedes
  /// Gerätebackup mitwandert.
  final int? birthYear;

  // Wertgleichheit, weil dieser Typ Abhängigkeit eines Providers ist: Ohne
  // `==` wäre jede zweite Antwort des Kanals ungleich der ersten und jeder
  // abgeleitete Wert liefe neu — Fehler `03`, wortgleich, im neuen Code.
  @override
  bool operator ==(Object other) =>
      other is BodyCharacteristics &&
      other.heightCm == heightCm &&
      other.birthYear == birthYear;

  @override
  int get hashCode => Object.hash(heightCm, birthYear);

  @override
  String toString() =>
      'BodyCharacteristics(heightCm: $heightCm, birthYear: $birthYear)';
}
