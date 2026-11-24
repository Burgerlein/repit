import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
// Der Kern hat seit #95 eigene, schlanke Workout-Typen für die
// Zonen-Rechnung (zone_distribution.dart). Hier sind die Kanal-Typen aus
// health_types.dart gemeint — die Kern-Namen bleiben draußen.
import 'package:trainings_core/trainings_core.dart'
    hide WorkoutKind, WorkoutSample;

import 'health_reading.dart';
import 'health_types.dart';

/// Demodaten für Simulator und Tests. Ersetzt `Sources/Health/
/// MockHealthReading.swift` + `MockSleep.swift` + `MockGym.swift`
/// (zusammen ~320 Zeilen, Spec 8.4) — **keine eigenen erfundenen
/// Konstanten**, sondern liest `test/fixtures/health_export_demo.json`
/// (`docs/demo_dataset.md`, Abschnitt „Wie Task 12 den Datensatz einlesen
/// sollte"; dort als Zweck dieser Datei bereits angekündigt).
///
/// **Tims Entscheidung vom 26.10.2026 (Spec 8.4a):** Demodaten erscheinen nie
/// auf dem Gerät und brauchen deshalb im Simulator **keine Kennzeichnung** —
/// „er läuft einfach". Das gilt für die Werte, die dieser Mock liefert.
///
/// **Fester Zeitraum, nicht relativ zu `DateTime.now()`:** Der Datensatz
/// deckt 10.09.–27.10.2026 ab. `docs/demo_dataset.md` empfiehlt ausdrücklich
/// „fest lassen" — das vermeidet die Zielkarte-Falle (#14, „Die Zielkarte
/// im Plan altert jeden Tag im Quelltext") vollständig, weil nirgends ein
/// Datum als „heute" behauptet wird, anders als die Swift-Vorlage (deren
/// `referenceDate` an `.now` hängt). Wer außerhalb des Fensters fragt, bekommt
/// leere Listen — der Mock erfindet nichts dazu.
class MockHealthReading
    implements HealthReading, BodyCharacteristicsReading {
  MockHealthReading({File? datenDatei})
    : _datenDatei = datenDatei ?? File(_standardPfad);

  /// Relativ zum Arbeitsverzeichnis, mit dem `flutter test` läuft (die
  /// Paketwurzel `app/`) — siehe `docs/demo_dataset.md`, Variante „Tests":
  /// Das funktioniert, weil Tests gegen den Quellbaum laufen, nicht gegen
  /// ein gebautes Bundle. Dieselbe Datei, die `test/health/mock_test.dart`
  /// selbst in `setUpAll` liest.
  static const _standardPfad = 'test/fixtures/health_export_demo.json';

  final File _datenDatei;

  Map<String, dynamic>? _datensatz;

  Map<String, dynamic> get _daten =>
      _datensatz ??= jsonDecode(_datenDatei.readAsStringSync()) as Map<String, dynamic>;

  List<Map<String, dynamic>> get _tage =>
      (_daten['days'] as List).cast<Map<String, dynamic>>();
  List<Map<String, dynamic>> get _mahlzeiten =>
      (_daten['meals'] as List).cast<Map<String, dynamic>>();
  List<Map<String, dynamic>> get _trainings =>
      (_daten['workouts'] as List).cast<Map<String, dynamic>>();
  List<Map<String, dynamic>> get _naechte =>
      (_daten['sleep'] as List).cast<Map<String, dynamic>>();

  /// Drei Jahre, nicht 1970 — dieselbe Faustregel wie die Swift-Vorlage
  /// (`MockHealthReading.earliestPermittedDate`, `EmptyHealthReading.
  /// earliestPermittedDate`).
  @override
  DateTime get earliestPermittedDate =>
      DateTime.now().subtract(const Duration(days: 365 * 3));

  @override
  Future<void> requestAuthorization() async {}

  @override
  Future<List<DailyMetrics>> dailyMetrics(DateTime from, DateTime through) async {
    final vonTag = BerlinCalendar.dayKey(from);
    final bisTag = BerlinCalendar.dayKey(through);
    return _tage
        .where((tag) => _zwischen(tag['date'] as String, vonTag, bisTag))
        .map(_tagesmetrikenAus)
        .toList();
  }

  DailyMetrics _tagesmetrikenAus(Map<String, dynamic> tag) {
    double? zahl(String schluessel) => (tag[schluessel] as num?)?.toDouble();
    return DailyMetrics(
      tag: tag['date'] as String,
      steps: tag['steps'] as int?,
      activeKcal: tag['activeKcal'] as int?,
      basalKcal: tag['basalKcal'] as int?,
      restingHR: tag['restingHR'] as int?,
      hrvMs: zahl('hrvMs'),
      respRate: zahl('respRate'),
      vo2max: zahl('vo2max'),
      weightKg: zahl('weightKg'),
      bodyFatPct: zahl('bodyFatPct'),
      leanKg: zahl('leanKg'),
      // Alkoholische Getränke (#125). **Additive Erweiterung der
      // trainingsexport-Hülle**, wie `naps` beim Schlaf: Die meisten Tage
      // tragen den Schlüssel nicht, und ein echter Export trägt ihn heute
      // nie. Fehlt er, bleibt der Wert `null` — der Mock erfindet keine 0,
      // sonst stünde im Simulator „nichts getrunken", wo nichts bekannt ist.
      alcoholicDrinks: zahl('alcoholicDrinks'),
      // Trainingsminuten, Stehstunden und Puls-Erholung stehen nicht im
      // trainingsexport-Format (docs/SPEC.md 4.11) — der Datensatz hat dafür
      // keine Quelle, alle drei Felder bleiben in jedem Demo-Tag null.
    );
  }

  @override
  Future<List<SleepNight>> sleepSessions(DateTime from, DateTime through) async {
    final vonTag = BerlinCalendar.dayKey(from);
    final bisTag = BerlinCalendar.dayKey(through);
    return _naechte
        .where((nacht) => _zwischen(nacht['night'] as String, vonTag, bisTag))
        .map(_nachtAus)
        .toList();
  }

  SleepNight _nachtAus(Map<String, dynamic> nacht) {
    // `naps` ist eine **additive** Erweiterung der trainingsexport-Hülle und
    // optional: 41 der 43 Nächte dieses Datensatzes tragen den Schlüssel
    // nicht, und ein echter Export trägt ihn heute nie. Fehlt er, ist die
    // Liste leer — der Mock wirft dafür nicht und erfindet nichts.
    final nickerchen = nacht['naps'] as List? ?? const [];
    return SleepNight(
      date: _parseTag(nacht['night'] as String),
      session: SleepSession(segments: _abschnitteAus(nacht['segments'] as List)),
      // Ein Nickerchen ist eine eigene `SleepSession`, kein loser
      // Abschnitt: Welche Abschnitte zu *einem* Nickerchen gehören, steht
      // schon im Datensatz, weil auf dem Gerät der Swift-Kanal gruppiert.
      // Eine zweite Gruppierungsregel in Dart schließt die Spec aus
      // (`2026-10-26-erholung-flutter-design.md`, Abschnitt 1).
      naps: [
        for (final nap in nickerchen.cast<Map<String, dynamic>>())
          SleepSession(segments: _abschnitteAus(nap['segments'] as List)),
      ],
    );
  }

  /// Abschnitte aus dem Datensatz — Nacht wie Nickerchen, mit derselben
  /// Umrechnung aus naiver Berliner Ortszeit.
  List<SleepSegment> _abschnitteAus(List roh) => roh
      .cast<Map<String, dynamic>>()
      .map(
        (s) => SleepSegment(
          stage: SleepStage.values.byName(s['stage'] as String),
          start: _parseBerlinLocalIso(s['start'] as String),
          end: _parseBerlinLocalIso(s['end'] as String),
        ),
      )
      .toList();

  @override
  Future<List<WorkoutSample>> workouts(DateTime from, DateTime through) async {
    final ende = BerlinCalendar.endOfDay(through);
    final ergebnis = _trainings
        .map(_trainingAus)
        .where((w) => !w.start.isBefore(from) && w.start.isBefore(ende))
        .toList();
    ergebnis.sort((a, b) => a.start.compareTo(b.start));
    return ergebnis;
  }

  WorkoutSample _trainingAus(Map<String, dynamic> training) {
    final start = _berlinLocalDateTime(
      training['date'] as String,
      training['start'] as String,
    );
    return WorkoutSample(
      id: '${training['date']}T${training['start']}',
      start: start,
      kind: _artAusExport(training['type'] as String),
      minutes: (training['minutes'] as num).toDouble(),
      km: (training['km'] as num?)?.toDouble(),
      avgHR: training['avgHR'] as int?,
      maxHR: training['maxHR'] as int?,
    );
  }

  /// Dieselbe Zuordnung wie `HealthKitReading.kind(for:)` auf der
  /// Swift-Seite, aber von den Export-Bezeichnern aus `docs/sample_export.
  /// json` statt von `HKWorkoutActivityType`.
  static WorkoutKind _artAusExport(String typ) {
    switch (typ) {
      case 'Running':
        return WorkoutKind.running;
      case 'Walking':
      case 'Hiking':
        return WorkoutKind.walking;
      case 'Cycling':
        return WorkoutKind.cycling;
      case 'TraditionalStrengthTraining':
      case 'FunctionalStrengthTraining':
        return WorkoutKind.strength;
      case 'Swimming':
        return WorkoutKind.swimming;
      case 'Soccer':
        return WorkoutKind.soccer;
      default:
        return WorkoutKind.other;
    }
  }

  /// Baut Herzfrequenz-/Atemfrequenz-Punkte aus den bereits im Datensatz
  /// enthaltenen `hrBins`/`rrBins` (16 Abschnitte je Nacht, siehe
  /// `docs/demo_dataset.md`) — anders als die Swift-Vorlage, die diese Werte
  /// aus einer Formel erzeugt: Der Demo-Datensatz hat sie schon, es wäre
  /// doppelte Arbeit, sie hier erneut zu erfinden.
  ///
  /// Für die HRV gilt das nicht: Der Datensatz führt nur den Tageswert
  /// `hrvMs`, keine Einzelproben. Die Reihe entsteht deshalb hier, siehe
  /// `_werteFuer`.
  @override
  Future<List<QuantitySample>> quantitySamples(
    VitalKind kind,
    DateTime from,
    DateTime through,
  ) async {
    final ende = BerlinCalendar.endOfDay(through);
    final ergebnis = <QuantitySample>[];
    for (final nacht in _naechte) {
      final segmente = nacht['segments'] as List;
      if (segmente.isEmpty) continue;
      final beginn = _parseBerlinLocalIso(
        (segmente.first as Map<String, dynamic>)['start'] as String,
      );
      final schlafende = _parseBerlinLocalIso(
        (segmente.last as Map<String, dynamic>)['end'] as String,
      );
      if (schlafende.isBefore(from) || !beginn.isBefore(ende)) continue;

      final werte = _werteFuer(kind, nacht);
      if (werte.isEmpty) continue;
      final spanne = schlafende.difference(beginn);
      for (var i = 0; i < werte.length; i++) {
        final anteil = (i + 0.5) / werte.length;
        final zeitpunkt = beginn.add(
          Duration(microseconds: (spanne.inMicroseconds * anteil).round()),
        );
        if (zeitpunkt.isBefore(from) || !zeitpunkt.isBefore(ende)) continue;
        ergebnis.add(QuantitySample(date: zeitpunkt, value: werte[i]));
      }
    }
    if (kind == VitalKind.heartRate) {
      ergebnis.addAll(_pulsWaehrendTrainings(from, ende));
    }
    ergebnis.sort((a, b) => a.date.compareTo(b.date));
    return ergebnis;
  }

  /// Herzfrequenz **während der Trainings** (#513).
  ///
  /// Ohne diese Reihe liefert der Mock tagsüber nichts, und der Pulsverlauf
  /// im Gym-Verlauf (#512) stünde im Simulator dauerhaft auf `LeerNachLauf` —
  /// er sähe aus wie ein Fehler und wäre keiner.
  ///
  /// **Die Grenzen kommen aus dem Datensatz, nicht von hier.** Jedes Training
  /// führt `avgHR` und `maxHR`; dazwischen wird interpoliert. Erfunden ist
  /// allein der *Verlauf*: anlaufen, je Satz ein Ausschlag, dazwischen
  /// absinken, am Ende auslaufen. Das ist eine Demo-Form, keine Messung —
  /// sie sagt nichts darüber, wie ein Training wirklich aussieht.
  ///
  /// **Alle 15 Sekunden ein Punkt, nicht jede Minute.** Mit einem Punkt je
  /// Minute fielen auf ein Kästchen des Diagramms nur drei bis vier Werte,
  /// und bei einem Ausschlag je vier Minuten lag die Abtastung fast auf der
  /// Periode: Das Diagramm zeigte einen Lattenzaun aus Aliasing statt eines
  /// Verlaufs. Eine Uhr misst beim Krafttraining ohnehin im Sekundentakt,
  /// und erst mit genug Punkten je Kästchen bedeutet dessen Spanne etwas.
  ///
  /// Nur `heartRate`: Die Atemfrequenz misst die Uhr beim Sport nicht.
  List<QuantitySample> _pulsWaehrendTrainings(DateTime from, DateTime ende) {
    const taktSekunden = 15;
    final punkte = <QuantitySample>[];
    for (final training in _trainings) {
      final beginn =
          _parseBerlinLocalIso('${training['date']}T${training['start']}:00');
      final minuten = (training['minutes'] as num).toInt();
      final avg = (training['avgHR'] as num?)?.toDouble();
      final hoch = (training['maxHR'] as num?)?.toDouble();
      if (avg == null || hoch == null || minuten <= 0) continue;

      // Die Ruhegrundlinie: so weit unter dem Schnitt, wie der Gipfel
      // darüber liegt. So bleibt der Mittelwert der Reihe nahe an `avgHR`,
      // ohne dass hier eine zweite Zahl erfunden wird.
      final tief = avg - (hoch - avg);
      final schritte = minuten * 60 ~/ taktSekunden;
      for (var i = 0; i < schritte; i++) {
        // Sieben Sekunden Versatz, damit ein Punkt nie genau auf einem Punkt
        // der Nachtreihe liegt — zwei gleiche Zeitstempel sähen aus wie ein
        // Dopplungsfehler.
        final zeitpunkt = beginn.add(
          Duration(seconds: i * taktSekunden + 7),
        );
        if (zeitpunkt.isBefore(from) || !zeitpunkt.isBefore(ende)) continue;
        final t = i * taktSekunden / 60; // Minuten seit Beginn

        // Anlaufen über fünf Minuten, auslaufen über die letzten drei.
        final anlauf = (t / 5).clamp(0.0, 1.0);
        final auslauf = ((minuten - t) / 3).clamp(0.0, 1.0);

        // Die Grundlinie steigt über das Training leicht an — wer eine
        // Stunde hebt, kommt nicht auf denselben Puls zurück wie am Anfang.
        final grund = tief + (avg - tief) * (0.55 + 0.3 * (t / minuten));

        // Je Satz ein Ausschlag: etwa alle vier Minuten knapp anderthalb
        // Minuten lang. `pow` macht die Spitze schmal, sodass dazwischen
        // wirklich Erholung liegt, statt dass die Welle durchschwingt.
        final phase = (1 - math.cos(t / 4 * 2 * math.pi)) / 2;
        final satz = math.pow(phase, 2.2).toDouble();

        final wert = grund + (hoch - grund) * satz * anlauf * auslauf;
        punkte.add(
          QuantitySample(date: zeitpunkt, value: wert.roundToDouble()),
        );
      }
    }
    return punkte;
  }

  /// Die Messwerte einer Nacht, in der Reihenfolge, in der sie über das
  /// Schlaffenster verteilt werden.
  List<double> _werteFuer(VitalKind kind, Map<String, dynamic> nacht) {
    switch (kind) {
      case VitalKind.heartRate:
      case VitalKind.respiratoryRate:
        final bins =
            (kind == VitalKind.heartRate ? nacht['hrBins'] : nacht['rrBins'])
                as List;
        return [
          for (final bin in bins.cast<List>())
            ((bin[0] as num).toDouble() + (bin[1] as num).toDouble()) / 2,
        ];
      case VitalKind.heartRateVariability:
        final basis = _hrvBasis(nacht['night'] as String);
        if (basis == null) return const [];
        return [for (final faktor in _hrvStreuung) basis * faktor];
    }
  }

  /// Vier Proben je Nacht statt sechzehn: Die Uhr misst SDNN zwei- bis
  /// sechsmal in einer Nacht, nicht alle paar Minuten
  /// (`docs/superpowers/specs/2026-11-02-193-nachtwerte.md`). Die Faktoren
  /// sind **erfunden** und tragen keine Bedeutung — sie sollen nur dafür
  /// sorgen, dass die vier Proben auseinanderliegen, damit ein Median im
  /// Simulator überhaupt etwas zu tun hat. Keine Zahl davon stammt von Tim.
  static const _hrvStreuung = [0.82, 1.14, 0.93, 1.11];

  /// Der Tageswert `hrvMs` der Nacht, um den herum die vier Proben streuen.
  /// Fehlt er — sechs der 43 Demo-Tage tragen ihn nicht —, liefert die Nacht
  /// keine Probe. Der Mock erfindet keinen Wert, wo der Datensatz keinen hat;
  /// genau diese Lücke ist der Fall, den `NightVitals` auf `null` abbilden
  /// muss, statt auf 0.
  double? _hrvBasis(String nachtTag) {
    for (final tag in _tage) {
      if (tag['date'] == nachtTag) return (tag['hrvMs'] as num?)?.toDouble();
    }
    return null;
  }

  /// Ein Tagesverlauf zum Anschauen — dieselbe Kurvenform wie
  /// `Sources/Health/MockHealthReading.swift.hourlySteps` (nachts nichts, Weg
  /// zur Arbeit, Mittag, Feierabend). Der Demo-Datensatz selbst hat keine
  /// stündliche Auflösung; die genaue Kurve ist eine gestalterische
  /// Entscheidung des Mocks, kein Vertrag (siehe `mock_test.dart`-Dateikopf,
  /// Abschnitt „was hier absichtlich nicht geprüft wird").
  @override
  Future<List<QuantitySample>> hourlySteps(DateTime from, DateTime through) async {
    const form = [
      0.0, 0, 0, 0, 0, 0.2, 0.8, 2.4, 1.6, 1.1, 0.9, 1.2,
      1.5, 1.0, 0.8, 0.9, 1.3, 2.1, 1.7, 1.0, 0.7, 0.4, 0.15, 0.05,
    ];
    final tage = BerlinCalendar.days(from: from, through: through);
    final ergebnis = <QuantitySample>[];
    for (var index = 0; index < tage.length; index++) {
      final tag = tage[index];
      for (var stunde = 0; stunde < 24; stunde++) {
        final wert =
            form[stunde] * 430 * (0.75 + ((index * 7 + stunde) % 11) / 22);
        if (wert < 1) continue;
        ergebnis.add(
          QuantitySample(
            date: tag.add(Duration(hours: stunde)),
            value: wert.roundToDouble(),
          ),
        );
      }
    }
    return ergebnis;
  }

  @override
  Future<List<NutritionEntry>> nutritionEntries(DateTime day) async {
    final tag = BerlinCalendar.dayKey(day);
    final eintraege = _mahlzeiten
        .where((m) => m['date'] == tag)
        .map(
          (m) => NutritionEntry(
            time: _berlinLocalDateTime(tag, m['time'] as String),
            name: m['name'] as String,
            kcal: (m['kcal'] as num).toDouble(),
            proteinG: (m['protein'] as num).toDouble(),
            carbsG: (m['carbs'] as num).toDouble(),
            fatG: (m['fat'] as num).toDouble(),
          ),
        )
        .toList();
    eintraege.sort((a, b) => a.time.compareTo(b.time));
    return eintraege;
  }

  // ── Gewicht von Hand eintragen (#270) ────────────────────────────────
  //
  // Der Mock tritt im Simulator an die Stelle von HealthKit, dessen Store
  // dort dauerhaft leer ist. Damit das Blatt dort überhaupt prüfbar ist,
  // verhält er sich wie ein kleines HealthKit: Freigabe erteilt,
  // Geschriebenes taucht beim nächsten Lesen auf, Gelöschtes nicht mehr.
  // Die Ablage ist bewusst nur im Gedächtnis — der Mock hat keine, und eine
  // zu erfinden hieße, eine zweite Wahrheit neben Health zu bauen.

  /// Was in dieser Sitzung von Hand eingetragen wurde.
  final List<WeightSample> _vonHand = [];

  /// Welche Proben aus dem Datensatz gelöscht wurden.
  final Set<String> _geloescht = {};

  int _naechsteId = 0;

  @override
  Future<WriteAuthorization> requestWeightWriteAuthorization() async =>
      WriteAuthorization.granted;

  @override
  Future<String> writeWeight({
    required double kg,
    required DateTime at,
  }) async {
    _naechsteId += 1;
    final id = 'mock-gewicht-$_naechsteId';
    _vonHand.add(
      WeightSample(id: id, date: at, kg: kg, wasUserEntered: true),
    );
    return id;
  }

  @override
  Future<void> deleteWeight(String id) async {
    _vonHand.removeWhere((probe) => probe.id == id);
    _geloescht.add(id);
  }

  /// Eine Probe je Tag mit Gewicht, dazu das in dieser Sitzung Eingetragene.
  ///
  /// Die Uhrzeit ist 07:30 Berliner Zeit — eine Waage wird morgens
  /// benutzt, und eine Statistik hätte gar keine. `wasUserEntered` ist
  /// `false`: Was aus dem Datensatz kommt, steht für die Waage.
  @override
  Future<List<WeightSample>> weightSamples(
    DateTime from,
    DateTime through,
  ) async {
    final von = BerlinCalendar.dayKey(from);
    final bis = BerlinCalendar.dayKey(through);

    final proben = <WeightSample>[
      for (final tag in _tage)
        if (_zwischen(tag['date'] as String, von, bis) &&
            tag['weightKg'] != null &&
            !_geloescht.contains('mock-waage-${tag['date']}'))
          WeightSample(
            id: 'mock-waage-${tag['date']}',
            // `toLocal`, weil `_berlinLocalDateTime` einen UTC-Zeitpunkt
            // liefert und die Anzeige die **Felder** des Objekts
            // formatiert, nicht den Augenblick: Ohne das stünde im
            // Simulator „05:30" an einer Zeile, die 07:30 meint, und
            // daneben eine frisch eingetragene in Ortszeit. Derselbe
            // Augenblick, nur lesbar geschrieben.
            date: _berlinLocalDateTime(tag['date'] as String, '07:30').toLocal(),
            kg: (tag['weightKg'] as num).toDouble(),
            wasUserEntered: false,
          ),
      for (final probe in _vonHand)
        if (_zwischen(BerlinCalendar.dayKey(probe.date), von, bis)) probe,
    ];
    proben.sort((a, b) => a.date.compareTo(b.date));
    return proben;
  }
  // ── Ernährung nach Health schreiben (#283) ───────────────────────────
  //
  // Wie beim Gewicht ein kleines HealthKit im Gedächtnis: Freigabe
  // erteilt, Geschriebenes liegt da, Gelöschtes nicht mehr. **Beim Lesen
  // taucht es nicht auf** — das ist der Quellenfilter der echten Seite:
  // Was diese App geschrieben hat, zählt sie schon aus der eigenen Tabelle.

  /// Was in dieser Sitzung geschrieben wurde, nach Kennung.
  final Map<String, ({String name, DateTime at, Naehrwerte werte})>
  _mahlzeitenVonHand = {};

  @override
  Future<WriteAuthorization> requestNutritionWriteAuthorization() async =>
      WriteAuthorization.granted;

  @override
  Future<String> writeMeal({
    required Naehrwerte werte,
    required String name,
    required DateTime at,
  }) async {
    _naechsteId += 1;
    final id = 'mock-mahlzeit-$_naechsteId';
    _mahlzeitenVonHand[id] = (name: name, at: at, werte: werte);
    return id;
  }

  @override
  Future<void> deleteMeal(String id) async {
    _mahlzeitenVonHand.remove(id);
  }

  /// Körpergröße und Geburtsjahr (#306) — **erfundene Konstanten**, keine
  /// Zeile aus dem Demo-Datensatz.
  ///
  /// Das Exportformat (`docs/sample_export.json`) kennt weder Körpergröße
  /// noch Geburtsjahr; die Fixture darum zu erweitern hieße, bestehenden
  /// Testinhalt zu ändern. Hier stehen sie deshalb direkt — mit dem
  /// Nebeneffekt, dass der Simulator auch ohne die Datei eine Antwort
  /// bekommt, statt beim ersten Zugriff zu werfen.
  ///
  /// **Keiner der beiden Werte stammt von Tim** (`CLAUDE.md`: „Echte
  /// Gesundheitsdaten stehen nie im Quelltext"). Sie sind nur so gewählt,
  /// dass aus ihnen eine Rechnung werden kann: Mifflin-St Jeor braucht eine
  /// Größe und ein Alter, die ein Mensch haben kann — sonst zeigte der
  /// Ernährungsring im Simulator „kein Ziel berechenbar" und der Weg, um
  /// den es in #306 geht, wäre dort gar nicht zu sehen.
  @override
  Future<BodyCharacteristics> bodyCharacteristics() async =>
      const BodyCharacteristics(heightCm: 178.5, birthYear: 1985);

  static bool _zwischen(String tag, String von, String bis) =>
      tag.compareTo(von) >= 0 && tag.compareTo(bis) <= 0;
}

DateTime _parseTag(String tag) {
  final teile = tag.split('-').map(int.parse).toList();
  return BerlinCalendar.startOfDay(DateTime.utc(teile[0], teile[1], teile[2]));
}

DateTime _berlinLocalDateTime(String tag, String uhrzeit) {
  final tagTeile = tag.split('-').map(int.parse).toList();
  final zeitTeile = uhrzeit.split(':').map(int.parse).toList();
  return _berlinToUtc(
    tagTeile[0],
    tagTeile[1],
    tagTeile[2],
    zeitTeile[0],
    zeitTeile[1],
    0,
  );
}

DateTime _parseBerlinLocalIso(String iso) {
  final datum = iso.substring(0, 10).split('-').map(int.parse).toList();
  final zeit = iso.substring(11).split(':').map(int.parse).toList();
  return _berlinToUtc(
    datum[0],
    datum[1],
    datum[2],
    zeit[0],
    zeit[1],
    zeit.length > 2 ? zeit[2] : 0,
  );
}

/// Dieselbe EU-Sommerzeitregel wie `BerlinCalendar._versatz`
/// (`Packages/trainings_core/lib/src/berlin_calendar.dart`), hier dupliziert:
/// `BerlinCalendar`s öffentliche API kennt nur Kalendertagsgrenzen
/// (`startOfDay`/`endOfDay`/`dayBounds`/`days`/`dayKey`), keine beliebige
/// Uhrzeit innerhalb eines Tages. Genau die wird hier gebraucht, um die
/// naiven lokalen Zeitstempel aus dem Demo-Datensatz (`timezone:
/// "Europe/Berlin"`, keine Zonenangabe in den ISO-Strings, siehe
/// `docs/sample_export.json`) korrekt in UTC-Zeitpunkte umzurechnen — ein
/// einfaches `DateTime.parse` ginge hier in die Gerätezeitzone und wäre damit
/// nicht deterministisch über verschiedene Testrechner hinweg.
DateTime _berlinToUtc(
  int jahr,
  int monat,
  int tag,
  int stunde,
  int minute,
  int sekunde,
) {
  final naiv = DateTime.utc(jahr, monat, tag, stunde, minute, sekunde);
  for (final versatzStunden in [2, 1]) {
    final kandidat = naiv.subtract(Duration(hours: versatzStunden));
    if (_istSommerzeit(kandidat) == (versatzStunden == 2)) {
      return kandidat;
    }
  }
  // Die übersprungene oder doppelte Stunde der Umstellung selbst: Winterzeit
  // gewinnt, mangels eines eindeutig richtigen Zeitpunkts. Betrifft höchstens
  // eine einzelne Stunde im ganzen Datensatz.
  return naiv.subtract(const Duration(hours: 1));
}

bool _istSommerzeit(DateTime utc) {
  final jahr = utc.year;
  DateTime letzterSonntag(int monat) {
    var tag = DateTime.utc(jahr, monat + 1, 0).day;
    while (DateTime.utc(jahr, monat, tag).weekday != DateTime.sunday) {
      tag -= 1;
    }
    return DateTime.utc(jahr, monat, tag, 1);
  }

  final beginn = letzterSonntag(3);
  final ende = letzterSonntag(10);
  return !utc.isBefore(beginn) && utc.isBefore(ende);
}

/// Lädt den Demo-Datensatz aus dem Dokumentenverzeichnis der laufenden App —
/// für den **Simulator**, nicht für Tests (die lesen direkt aus
/// `test/fixtures/`, siehe `MockHealthReading`-Konstruktor oben).
///
/// **Nur im Debug-Build.** `kDebugMode` ist eine Kompilierzeit-Konstante:
/// Der Dart-Compiler entfernt den Rumpf dieser Funktion im Release-Build
/// vollständig (Tree-Shaking), nicht nur eine Laufzeitprüfung, die zufällig
/// `false` ergibt — ein Release-Build **enthält** diesen Codepfad nicht
/// einmal im kompilierten Programm. Das ist der Beleg dafür, dass
/// Demodaten nie auf das Gerät gelangen (CLAUDE.md: „Die App soll ohne Daten
/// ehrlich leer sein", Spec 8.4a).
///
/// Voraussetzung: `scripts/health_demo_in_simulator.sh` hat die Datei vorher
/// in den Container des Simulators kopiert (siehe `docs/demo_dataset.md`,
/// Variante „Dokumentenverzeichnis", und die bestehende Praxis „Zustand im
/// Simulator vorbelegen: JSON in den Container schreiben statt tippen").
/// Fehlt die Datei (Skript nicht gelaufen, oder ein Lauf auf echtem Gerät),
/// liefert diese Funktion `null` statt zu werfen — wer sie aufruft, fällt
/// dann auf eine andere Quelle zurück, statt abzustürzen.
Future<MockHealthReading?> ladeDemoDatensatzFuerSimulator() async {
  if (!kDebugMode) return null;
  final verzeichnis = await getApplicationDocumentsDirectory();
  final datei = File('${verzeichnis.path}/health_export_demo.json');
  if (!datei.existsSync()) return null;
  return MockHealthReading(datenDatei: datei);
}
