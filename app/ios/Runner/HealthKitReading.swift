import Foundation
import HealthKit
import TrainingsCore

/// Echter HealthKit-Zugriff. Lesen ist der Normalfall; geschrieben wird erst
/// ab M2 und nur als Lückenfüller (siehe SPEC 4.4).
///
/// Portiert aus `Sources/Health/HealthKitReading.swift` (Spec 8.2, Task 12),
/// unverändert: `.mostRecent`, `.discreteMax`, `.separateBySource` →
/// `StepMerge`, `DateComponents(day: 1)`, VO₂max,
/// `heartRateRecoveryOneMinute` und die Workout-HR-Statistik sind genau der
/// Grund, warum dieser Kanal existiert (Spec 8.1). Schlaf bleibt eine
/// Abfrage.
final class HealthKitReading: HealthReading, HealthWeightWriting, HealthNutritionWriting {

    private let store = HKHealthStore()

    /// Alles, was Apple zum Lesen anbietet — siehe HealthTypeCatalog.
    /// Es gibt nur einen Berechtigungsdialog, deshalb vollständig.
    static var readTypes: Set<HKObjectType> { HealthTypeCatalog.allReadableTypes }

    /// Was der Gewichts-Dialog anfragt: genau das Körpergewicht (#270).
    /// Der Lesekatalog bleibt davon unberührt — der Schreibdialog kommt
    /// daneben, er ersetzt nichts.
    static var weightWriteTypes: Set<HKSampleType> { HealthTypeCatalog.weightWritableTypes }

    /// Was der Ernährungs-Dialog anfragt (#283) — ein eigener Dialog,
    /// getrennt vom Gewicht, beim ersten Buchen.
    static var nutritionWriteTypes: Set<HKSampleType> { HealthTypeCatalog.nutritionWritableTypes }

    var earliestPermittedDate: Date { store.earliestPermittedSampleDate() }

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthError.notAvailable
        }
        try await store.requestAuthorization(toShare: [], read: Self.readTypes)
    }

    func dailyMetrics(from: Date, through: Date) async throws -> [DailyMetrics] {
        try await timed("Tageswerte", from: from, through: through,
                        count: { $0.count }) {
            try await uncountedDailyMetrics(from: from, through: through)
        }
    }

    private func uncountedDailyMetrics(from: Date,
                                       through: Date) async throws -> [DailyMetrics] {
        // Eine Sammelabfrage je Kennzahl statt eine je Kennzahl und Tag.
        // Bei 31 Tagen sind das 10 Abfragen statt 310.
        async let stepsCol = collection(.stepCount,
                                        options: [.cumulativeSum, .separateBySource],
                                        from: from, through: through)
        async let activeCol = collection(.activeEnergyBurned, options: .cumulativeSum, from: from, through: through)
        async let basalCol = collection(.basalEnergyBurned, options: .cumulativeSum, from: from, through: through)
        async let rhrCol = collection(.restingHeartRate, options: .discreteAverage, from: from, through: through)
        async let hrvCol = collection(.heartRateVariabilitySDNN, options: .discreteAverage, from: from, through: through)
        async let respCol = collection(.respiratoryRate, options: .discreteAverage, from: from, through: through)
        async let vo2Col = collection(.vo2Max, options: .mostRecent, from: from, through: through)
        async let weightCol = collection(.bodyMass, options: .mostRecent, from: from, through: through)
        async let fatCol = collection(.bodyFatPercentage, options: .mostRecent, from: from, through: through)
        async let leanCol = collection(.leanBodyMass, options: .mostRecent, from: from, through: through)
        async let exerciseCol = collection(.appleExerciseTime, options: .cumulativeSum, from: from, through: through)
        async let recoveryCol = collection(.heartRateRecoveryOneMinute, options: .discreteMax, from: from, through: through)
        // Alkohol (#125). Es gibt in HealthKit keinen Nährwert dafür — der
        // einzige Tagebuch-Typ zählt Getränke, Einheit `count`, kumulativ.
        async let alcoholCol = collection(.numberOfAlcoholicBeverages, options: .cumulativeSum, from: from, through: through)
        async let standDays = standHoursPerDay(from: from, through: through)

        let days = BerlinCalendar.days(from: from, through: through)
        let bpm = HKUnit.count().unitDivided(by: .minute())

        let steps = stepsPerDay(try await stepsCol, days: days)
        let active = try await activeCol, basal = try await basalCol
        let rhr = try await rhrCol, hrv = try await hrvCol, resp = try await respCol
        let vo2 = try await vo2Col, weight = try await weightCol
        let fat = try await fatCol, lean = try await leanCol
        let exercise = try await exerciseCol, recovery = try await recoveryCol
        let alcohol = try await alcoholCol
        let stand = try await standDays

        return days.map { day in
            DailyMetrics(
                date: day,
                steps: steps[day],
                activeKcal: sum(active, day, .kilocalorie()).map { Int($0) },
                basalKcal: sum(basal, day, .kilocalorie()).map { Int($0) },
                restingHR: average(rhr, day, bpm).map { Int($0.rounded()) },
                hrvMs: average(hrv, day, .secondUnit(with: .milli)),
                respRate: average(resp, day, bpm),
                vo2max: recent(vo2, day, HKUnit(from: "ml/kg*min")),
                weightKg: recent(weight, day, .gramUnit(with: .kilo)),
                bodyFatPct: recent(fat, day, .percent()).map { $0 * 100 },
                leanKg: recent(lean, day, .gramUnit(with: .kilo)),
                exerciseMinutes: sum(exercise, day, .minute()),
                standHours: stand[day],
                recoveryHRDrop: maximum(recovery, day, bpm).map { Int($0.rounded()) },
                // `sum` liefert `nil`, wenn es für den Tag gar keine Probe
                // gibt — und genau dabei bleibt es. Ein `?? 0` hier hiesse
                // „an diesem Tag nichts getrunken", und das weiss niemand.
                alcoholicDrinks: sum(alcohol, day, .count())
            )
        }
    }

    /// Liest die Abschnitte und übergibt die Gruppierung dem Paket.
    ///
    /// Vorher bildete diese Methode die Nächte selbst, nach Kalendertag — und
    /// ein Mittagsschlaf endet vor 18 Uhr, fiel also in die Nacht davor und
    /// verlängerte sie. Was eine Nacht ist, ist eine Regel und keine Abfrage;
    /// sie steht jetzt in `SleepSession.nights(from:)` und hat dort Tests.
    func sleepSessions(from: Date, through: Date) async throws -> [SleepNight] {
        try await timed("Schlaf", from: from, through: through,
                        count: { $0.count }) {
            try await uncountedSleepSessions(from: from, through: through)
        }
    }

    private func uncountedSleepSessions(from: Date,
                                        through: Date) async throws -> [SleepNight] {
        let predicate = HKQuery.predicateForSamples(withStart: from, end: through, options: [])
        let segments = try await query(HKCategoryType(.sleepAnalysis), predicate: predicate)
            .compactMap { $0 as? HKCategorySample }
            // „Im Bett" ist keine Phase und kommt oft doppelt vom iPhone.
            .compactMap { sample -> SleepSegment? in
                Self.stage(of: sample).map {
                    SleepSegment(stage: $0, start: sample.startDate, end: sample.endDate)
                }
            }
        return SleepSession.nights(from: segments)
    }

    static func stage(of sample: HKCategorySample) -> SleepStage? {
        switch HKCategoryValueSleepAnalysis(rawValue: sample.value) {
        case .awake: .awake
        case .asleepREM: .rem
        case .asleepCore: .core
        case .asleepDeep: .deep
        case .asleepUnspecified: .unspecified
        default: nil
        }
    }

    func quantitySamples(_ kind: VitalKind, from: Date,
                         through: Date) async throws -> [QuantitySample] {
        let predicate = HKQuery.predicateForSamples(withStart: from, end: through, options: [])
        return try await query(HKQuantityType(kind.quantityTypeIdentifier), predicate: predicate)
            .compactMap { $0 as? HKQuantitySample }
            .map { QuantitySample(date: $0.startDate,
                                  value: $0.quantity.doubleValue(for: kind.unit)) }
            .sorted { $0.date < $1.date }
    }

    func workouts(from: Date, through: Date) async throws -> [WorkoutSample] {
        try await timed("Trainings", from: from, through: through,
                        count: { $0.count }) {
            try await uncountedWorkouts(from: from, through: through)
        }
    }

    private func uncountedWorkouts(from: Date,
                                   through: Date) async throws -> [WorkoutSample] {
        let start = BerlinCalendar.startOfDay(from)
        let end = BerlinCalendar.dayBounds(of: through).end
        let predicate = HKQuery.predicateForSamples(
            withStart: start, end: end, options: .strictStartDate)
        let samples = try await query(HKObjectType.workoutType(), predicate: predicate)
        return samples.compactMap { sample -> WorkoutSample? in
            guard let w = sample as? HKWorkout else { return nil }
            let distance = w.statistics(for: HKQuantityType(.distanceWalkingRunning))?
                .sumQuantity()?.doubleValue(for: .meterUnit(with: .kilo))
            let hr = w.statistics(for: HKQuantityType(.heartRate))
            let bpm = HKUnit.count().unitDivided(by: .minute())
            return WorkoutSample(
                id: w.uuid,
                start: w.startDate,
                kind: Self.kind(for: w.workoutActivityType),
                minutes: w.duration / 60,
                km: distance,
                avgHR: (hr?.averageQuantity()?.doubleValue(for: bpm)).map { Int($0.rounded()) },
                maxHR: (hr?.maximumQuantity()?.doubleValue(for: bpm)).map { Int($0.rounded()) },
                wasUserEntered: (w.metadata?[HKMetadataKeyWasUserEntered] as? Bool) ?? false
            )
        }
        .sorted { $0.start < $1.start }
    }

    /// Pflicht aus dem Protokoll `HealthReading` der eingefrorenen App —
    /// auf diesem Kanal **nicht mehr benutzt**. `NutritionEntry` hat
    /// nicht-optionale Nährwerte; ein fehlender Wert müsste hier zu `0`
    /// werden, und genau das war #232. Der Kanal liest über
    /// [nutritionMeals(on:)], das fehlende Werte als `nil` behält und die
    /// eigenen Proben herausfiltert.
    ///
    /// Wirft, statt still Nullen zu liefern: Ruft das doch jemand auf, ist
    /// das ein Programmierfehler, keine Datenlage.
    func nutritionEntries(on day: Date) async throws -> [NutritionEntry] {
        throw HealthError.replacedByNutritionMeals
    }

    // MARK: - Messung

    /// Misst eine Abfrage für den HealthKit-Testschirm. Nur Dauer, Trefferzahl
    /// und Zeitspanne — niemals Messwerte.
    private func timed<T>(_ name: String, from: Date, through: Date,
                          count: @Sendable (T) -> Int,
                          _ work: () async throws -> T) async rethrows -> T {
        let began = Date()
        let result = try await work()
        let seconds = Date().timeIntervalSince(began)
        let days = BerlinCalendar.days(from: from, through: through).count
        let n = count(result)
        await MainActor.run {
            QueryTimings.shared.record(name, seconds: seconds, count: n, days: days)
        }
        return result
    }

    enum HealthError: Error {
        case notAvailable

        /// Die Probe, die gelöscht werden soll, liegt nicht (mehr) vor —
        /// etwa, weil sie in der Health-App schon entfernt wurde.
        case sampleNotFound

        /// `nutritionEntries(on:)` liefe über `NutritionEntry` und machte
        /// aus fehlenden Nährwerten `0` (#232) — siehe dort.
        case replacedByNutritionMeals

        /// Eine Mahlzeit ohne einen einzigen Nährwert. Der Kanal lässt sie
        /// gar nicht erst durch (`HealthChannel.writeMealArgs`).
        case nothingToWrite
    }

    static func kind(for type: HKWorkoutActivityType) -> WorkoutKind {
        switch type {
        case .running: .running
        case .walking, .hiking: .walking
        case .cycling: .cycling
        case .traditionalStrengthTraining, .functionalStrengthTraining: .strength
        case .swimming: .swimming
        case .soccer: .soccer
        default: .other
        }
    }

    /// Nicht privat: Die Schlafabfrage braucht sie auch.
    func query(_ type: HKSampleType, predicate: NSPredicate) async throws -> [HKSample] {
        try await withCheckedThrowingContinuation { continuation in
            let q = HKSampleQuery(sampleType: type, predicate: predicate,
                                  limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: samples ?? []) }
            }
            store.execute(q)
        }
    }

    /// Schritte je Stunde. Dieselbe Doppelzählung wie beim Tageswert — iPhone
    /// und Watch zählen beide —, also auch dieselbe Regel: je Stunde der
    /// höhere Wert, nicht die Summe.
    func hourlySteps(from: Date, through: Date) async throws -> [QuantitySample] {
        try await timed("Stundenschritte", from: from, through: through,
                        count: { $0.count }) {
            try await uncountedHourlySteps(from: from, through: through)
        }
    }

    private func uncountedHourlySteps(from: Date,
                                      through: Date) async throws -> [QuantitySample] {
        let start = BerlinCalendar.startOfDay(from)
        let end = BerlinCalendar.dayBounds(of: through).end
        let predicate = HKQuery.predicateForSamples(
            withStart: start, end: end, options: .strictStartDate)

        let collection: HKStatisticsCollection? = try await withCheckedThrowingContinuation {
            continuation in
            let q = HKStatisticsCollectionQuery(
                quantityType: HKQuantityType(.stepCount),
                quantitySamplePredicate: predicate,
                options: [.cumulativeSum, .separateBySource],
                anchorDate: start,
                intervalComponents: DateComponents(hour: 1))
            q.initialResultsHandler = { _, result, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: result) }
            }
            store.execute(q)
        }
        guard let collection else { return [] }

        var perSource: [String: [Date: Int]] = [:]
        var unattributed: [Date: Int] = [:]
        collection.enumerateStatistics(from: start, to: end) { stats, _ in
            let hour = stats.startDate
            let sources = stats.sources ?? []
            if sources.isEmpty {
                if let v = stats.sumQuantity()?.doubleValue(for: .count()) {
                    unattributed[hour] = Int(v)
                }
            } else {
                for source in sources {
                    if let v = stats.sumQuantity(for: source)?.doubleValue(for: .count()) {
                        perSource[source.bundleIdentifier, default: [:]][hour] = Int(v)
                    }
                }
            }
        }
        var all = Array(perSource.values)
        if !unattributed.isEmpty { all.append(unattributed) }
        // `StepMerge.daily` heißt nach dem Anlass, rechnet aber über beliebige
        // Zeitschlüssel — hier sind es Stunden.
        return StepMerge.daily(perSource: all)
            .filter { $0.value > 0 }
            .map { QuantitySample(date: $0.key, value: Double($0.value)) }
            .sorted { $0.date < $1.date }
    }

    private func collection(_ id: HKQuantityTypeIdentifier,
                            options: HKStatisticsOptions,
                            from: Date, through: Date) async throws -> HKStatisticsCollection? {
        let start = BerlinCalendar.startOfDay(from)
        let end = BerlinCalendar.dayBounds(of: through).end
        let predicate = HKQuery.predicateForSamples(
            withStart: start, end: end, options: .strictStartDate)
        return try await withCheckedThrowingContinuation { continuation in
            // HealthKit zählt die Tagesintervalle über den Gerätekalender.
            // Das deckt sich mit BerlinCalendar, solange das iPhone auf
            // Europe/Berlin steht — bei diesem Nutzer immer der Fall.
            let q = HKStatisticsCollectionQuery(
                quantityType: HKQuantityType(id),
                quantitySamplePredicate: predicate,
                options: options,
                anchorDate: start,
                intervalComponents: DateComponents(day: 1))
            q.initialResultsHandler = { _, result, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: result) }
            }
            store.execute(q)
        }
    }

    /// Schritte zählen iPhone und Watch doppelt. Es gilt der höhere Wert je
    /// Tag, nicht die Summe — siehe SPEC 4.6 und `StepMerge`.
    private func stepsPerDay(_ collection: HKStatisticsCollection?, days: [Date]) -> [Date: Int] {
        guard let collection else { return [:] }
        var perSource: [String: [Date: Int]] = [:]
        var unattributed: [Date: Int] = [:]
        for day in days {
            guard let stats = collection.statistics(for: day) else { continue }
            let sources = stats.sources ?? []
            if sources.isEmpty {
                if let v = stats.sumQuantity()?.doubleValue(for: .count()) {
                    unattributed[day] = Int(v)
                }
            } else {
                for source in sources {
                    if let v = stats.sumQuantity(for: source)?.doubleValue(for: .count()) {
                        perSource[source.bundleIdentifier, default: [:]][day] = Int(v)
                    }
                }
            }
        }
        var all = Array(perSource.values)
        if !unattributed.isEmpty { all.append(unattributed) }
        return StepMerge.daily(perSource: all)
    }

    private func sum(_ c: HKStatisticsCollection?, _ day: Date, _ unit: HKUnit) -> Double? {
        c?.statistics(for: day)?.sumQuantity()?.doubleValue(for: unit)
    }

    private func average(_ c: HKStatisticsCollection?, _ day: Date, _ unit: HKUnit) -> Double? {
        c?.statistics(for: day)?.averageQuantity()?.doubleValue(for: unit)
    }

    private func recent(_ c: HKStatisticsCollection?, _ day: Date, _ unit: HKUnit) -> Double? {
        c?.statistics(for: day)?.mostRecentQuantity()?.doubleValue(for: unit)
    }

    private func maximum(_ c: HKStatisticsCollection?, _ day: Date, _ unit: HKUnit) -> Double? {
        c?.statistics(for: day)?.maximumQuantity()?.doubleValue(for: unit)
    }

    /// Stehstunden sind ein Kategorietyp, keine Menge — sie lassen sich nicht
    /// über eine Statistiksammlung zählen. Je Stunde, in der mindestens eine
    /// Minute gestanden wurde, legt die Watch eine Probe mit dem Wert `stood` an.
    private func standHoursPerDay(from: Date, through: Date) async throws -> [Date: Int] {
        let start = BerlinCalendar.startOfDay(from)
        let end = BerlinCalendar.dayBounds(of: through).end
        let predicate = HKQuery.predicateForSamples(
            withStart: start, end: end, options: .strictStartDate)
        let samples = try await query(HKCategoryType(.appleStandHour), predicate: predicate)
        var counts: [Date: Int] = [:]
        for sample in samples {
            guard let c = sample as? HKCategorySample,
                  c.value == HKCategoryValueAppleStandHour.stood.rawValue else { continue }
            let day = BerlinCalendar.startOfDay(c.startDate)
            counts[day, default: 0] += 1
        }
        return counts
    }

    // MARK: - Ernährung nach Health schreiben (#283)

    func requestNutritionWriteAuthorization() async throws -> HKAuthorizationStatus {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthError.notAvailable
        }
        // Der Lesekatalog muss mit — sonst verliert die App ihr Leserecht,
        // sobald sie das Schreibrecht bekommt (#317, siehe
        // `requestWeightWriteAuthorization`).
        try await store.requestAuthorization(toShare: Self.nutritionWriteTypes,
                                             read: Self.readTypes)
        return Self.combinedStatus(Self.nutritionWriteTypes.map {
            store.authorizationStatus(for: $0)
        })
    }

    /// Ein Status für acht Typen. **Erlaubt nur, wenn alle acht erlaubt
    /// sind:** Eine Mahlzeit wird in einem Zug gespeichert, und ein
    /// einziger verweigerter Typ lässt den ganzen Zug scheitern. Einen Teil
    /// zu schreiben und den Eintrag `geschrieben` zu nennen, behauptete
    /// eine vollständige Kopie, die es nicht gibt. Ist noch einer
    /// unentschieden, kann Nachfragen ihn noch erlauben.
    static func combinedStatus(_ statuses: [HKAuthorizationStatus]) -> HKAuthorizationStatus {
        if !statuses.isEmpty, statuses.allSatisfy({ $0 == .sharingAuthorized }) {
            return .sharingAuthorized
        }
        if statuses.contains(.notDetermined) { return .notDetermined }
        return .sharingDenied
    }

    func writeMeal(name: String, at date: Date,
                   nutrients: MealNutrients) async throws -> UUID {
        // Einzelproben mit gemeinsamen Metadaten, keine Korrelation — siehe
        // den Versuch im Kopf von `HealthNutritionWriting.swift`.
        let mahlzeit = UUID()
        let proben = HealthNutrition.quantitySamples(
            for: nutrients, at: date,
            metadata: [HKMetadataKeyFoodType: name,
                       HealthNutrition.mealIDKey: mahlzeit.uuidString]
        )
        guard !proben.isEmpty else { throw HealthError.nothingToWrite }
        // Ein Zug für alle Proben: HealthKit speichert sie gemeinsam oder
        // gar nicht. Eine halb geschriebene Mahlzeit gibt es so nicht.
        try await store.save(proben)
        return mahlzeit
    }

    func deleteMeal(id: UUID) async throws {
        // Über die eigene Mahlzeit-Kennung, nicht über Zeitpunkt und Name:
        // Zwei Einträge können beides teilen. `deleteObjects` nimmt nur,
        // was diese App geschrieben hat.
        let praedikat = HKQuery.predicateForObjects(
            withMetadataKey: HealthNutrition.mealIDKey,
            allowedValues: [id.uuidString]
        )
        var geloescht = 0
        for typ in Self.nutritionWriteTypes {
            geloescht += try await store.deleteObjects(of: typ, predicate: praedikat)
        }
        // Nichts gefunden ist ein Fehler, kein stiller Erfolg — dieselbe
        // Haltung wie bei `deleteWeight`. Die Dart-Seite macht daraus eine
        // Protokollzeile, keinen Dialog.
        if geloescht == 0 { throw HealthError.sampleNotFound }
    }

    func nutritionMeals(on day: Date) async throws -> [NutritionMeal] {
        let bounds = BerlinCalendar.dayBounds(of: day)
        let predicate = HKQuery.predicateForSamples(
            withStart: bounds.start, end: bounds.end, options: .strictStartDate)
        let samples = try await query(HKCorrelationType(.food), predicate: predicate)
        let mahlzeiten = samples.compactMap { sample -> NutritionMeal? in
            guard let food = sample as? HKCorrelation else { return nil }
            return HealthNutrition.meal(
                from: food,
                sourceBundleID: food.sourceRevision.source.bundleIdentifier
            )
        }
        // Der Quellenfilter (Spec, „Quellen"): Was diese App selbst
        // geschrieben hat, zählt sie schon aus der eigenen Tabelle. Unsere
        // Kopie besteht heute aus Einzelproben und taucht in dieser
        // Korrelationsabfrage gar nicht auf — der Filter bleibt trotzdem,
        // weil er die Zusage ist und nicht der Zufall der Schreibart.
        return HealthNutrition.foreignMeals(
            mahlzeiten,
            ownBundleID: Bundle.main.bundleIdentifier ?? ""
        )
        .sorted { $0.time < $1.time }
    }

    // MARK: - Gewicht von Hand eintragen (#270)

    private var bodyMass: HKQuantityType { HKQuantityType(.bodyMass) }

    func requestWeightWriteAuthorization() async throws -> HKAuthorizationStatus {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthError.notAvailable
        }
        // **Der Lesekatalog muss mit** (#301, im Simulator gemessen am
        // 03.11.2026). Mit `read: []` verlor die App ihr Leserecht auf
        // `bodyMass`, sobald sie das Schreibrecht bekam: Beim nächsten
        // Start fragte iOS erneut nach „Weight" unter *Lesen*, und bis
        // dahin lieferte HealthKit **leer ohne Fehler**. Die Liste stand
        // auf „Noch keine Wägung", die Werte lagen weiter in Health, und
        // `deleteWeight` fand nichts mehr zum Löschen.
        //
        // Ein zweiter Lesedialog entsteht dadurch nicht: iOS zeigt nur,
        // was noch unentschieden ist. Erteilte Typen fehlen im Dialog, und
        // genau der eine, der durch die Schreibfreigabe unentschieden
        // würde, bleibt so entschieden.
        try await store.requestAuthorization(toShare: Self.weightWriteTypes,
                                             read: Self.readTypes)
        // Die Anfrage selbst sagt nichts darüber, was der Nutzer getippt
        // hat — der Status unmittelbar danach schon. Beim Schreiben ist er
        // belastbar, anders als beim Lesen.
        return store.authorizationStatus(for: bodyMass)
    }

    func writeWeight(kg: Double, at date: Date) async throws -> UUID {
        let probe = HKQuantitySample(
            type: bodyMass,
            quantity: HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: kg),
            start: date,
            end: date,
            // Das Kennzeichen, aus dem „manuell" in „Letzte Messungen"
            // entsteht. Es ist Apples eigenes Feld, kein erfundenes —
            // deshalb trägt es auch für Eingaben in der Health-App.
            metadata: [HKMetadataKeyWasUserEntered: true]
        )
        try await store.save(probe)
        return probe.uuid
    }

    func deleteWeight(id: UUID) async throws {
        // Über die UUID, nicht über Wert und Zeitpunkt: Zwei Wägungen
        // können denselben Zeitpunkt tragen, und dann löschte eine Abfrage
        // nach Zeitraum die falsche mit.
        let proben = try await samples(
            predicate: HKQuery.predicateForObject(with: id),
            limit: 1
        )
        guard let probe = proben.first else {
            // **Nicht `notAvailable`.** Das heißt überall sonst „HealthKit
            // gibt es auf diesem Gerät nicht" — wer das später liest, liest
            // eine falsche Diagnose.
            throw HealthError.sampleNotFound
        }
        // Wirft, wenn die Probe einer fremden App gehört — und das ist
        // richtig so: Ein stiller Fehlschlag hieße „gilt als gelöscht und
        // ist es nicht".
        try await store.delete(probe)
    }

    func weightSamples(from: Date, through: Date) async throws -> [WeightSample] {
        let proben = try await samples(
            predicate: HKQuery.predicateForSamples(withStart: from, end: through),
            limit: HKObjectQueryNoLimit
        )
        return proben.map { probe in
            WeightSample(
                id: probe.uuid,
                date: probe.startDate,
                kg: probe.quantity.doubleValue(for: .gramUnit(with: .kilo)),
                // `?? false` ist hier kein stiller Ersatz für einen
                // fehlenden Wert: Apple setzt das Feld nur, wenn es zutrifft.
                // Fehlt es, kommt die Probe von einem Gerät.
                wasUserEntered: probe.metadata?[HKMetadataKeyWasUserEntered]
                    as? Bool ?? false
            )
        }
        .sorted { $0.date < $1.date }
    }

    /// Gewichtsproben zu einem Prädikat — die gemeinsame Hälfte von
    /// `weightSamples` und `deleteWeight`.
    private func samples(predicate: NSPredicate,
                         limit: Int) async throws -> [HKQuantitySample] {
        try await withCheckedThrowingContinuation { fortsetzung in
            let abfrage = HKSampleQuery(
                sampleType: bodyMass,
                predicate: predicate,
                limit: limit,
                sortDescriptors: [
                    NSSortDescriptor(key: HKSampleSortIdentifierStartDate,
                                     ascending: true)
                ]
            ) { _, ergebnis, fehler in
                if let fehler {
                    fortsetzung.resume(throwing: fehler)
                } else {
                    // `compactMap`, nicht `as? [HKQuantitySample]`: Der
                    // Alles-oder-nichts-Cast machte aus einem einzigen
                    // fremden Element eine leere Liste — stilles Leer statt
                    // Fehler, also `01`. Derselbe Stil wie überall sonst in
                    // dieser Datei.
                    fortsetzung.resume(
                        returning: (ergebnis ?? []).compactMap {
                            $0 as? HKQuantitySample
                        }
                    )
                }
            }
            store.execute(abfrage)
        }
    }
}

/// Welcher HealthKit-Typ und **welche Einheit** zu einer Messreihe gehören.
///
/// Hier und nicht in `Packages/TrainingsCore`: Der Kern importiert nur
/// Foundation, `HKQuantityTypeIdentifier` und `HKUnit` sind HealthKit
/// (`CLAUDE.md`, „Aufbau", durchgesetzt von `ImportBoundaryTests`).
///
/// **Die Einheit hängt an der Art, nicht an der Methode** (#193, Stufe 2).
/// Vorher setzte `quantitySamples` für jede Art fest „Zählung je Minute".
/// Das stimmt für Puls und Atmung; SDNN ist dagegen eine Zeit. Eine
/// Pulseinheit auf eine SDNN-Probe angewandt wirft nicht und meldet nichts —
/// `doubleValue(for:)` rechnet stillschweigend um und liefert eine um
/// Größenordnungen falsche Zahl, die auf der Dart-Seite wie ein gültiger
/// Messwert aussieht. Steht die Einheit an der Art, kann eine neue Art nicht
/// mehr versehentlich die Einheit der alten erben.
extension VitalKind {

    var quantityTypeIdentifier: HKQuantityTypeIdentifier {
        switch self {
        case .heartRate: .heartRate
        case .respiratoryRate: .respiratoryRate
        case .heartRateVariability: .heartRateVariabilitySDNN
        }
    }

    var unit: HKUnit {
        switch self {
        case .heartRate, .respiratoryRate: HKUnit.count().unitDivided(by: .minute())
        case .heartRateVariability: HKUnit.secondUnit(with: .milli)
        }
    }

}

/// Körpergröße und Geburtsjahr (#306).
///
/// **In dieser Datei und nicht neben dem Protokoll**, weil `store` privat
/// ist und eine Erweiterung nur innerhalb derselben Datei an private
/// Mitglieder kommt. Das Protokoll und sein Transporttyp liegen in
/// `HealthBodyCharacteristics.swift` — dieselbe Aufteilung wie bei
/// `HealthWeightWriting`.
extension HealthKitReading: BodyCharacteristicsReading {

    /// HealthKit liefert eine Länge als `HKQuantity`. **Die Umrechnung
    /// läuft über `HKUnit`, nicht über ein handgeschriebenes `* 100`:**
    /// Welche Einheit in der Probe steckt, entscheidet die App nicht — ein
    /// von einem US-Gerät übernommener Wert in Fuß käme sonst
    /// hundertfach zu klein an.
    ///
    /// Eine reine Funktion, damit sie ohne `HKHealthStore` prüfbar ist:
    /// Der Store des Simulators ist dauerhaft leer, und ein Test, der auf
    /// eine Abfrage wartet, prüft am Ende die Laufzeit statt die Rechnung.
    static func heightCm(from quantity: HKQuantity) -> Double {
        quantity.doubleValue(for: .meterUnit(with: .centi))
    }

    /// Das Geburtsjahr. `lesen` ist in der echten App
    /// `store.dateOfBirthComponents`.
    ///
    /// **Ein Wurf heißt „fehlt", nicht „kaputt".** `dateOfBirthComponents()`
    /// wirft, wenn nichts hinterlegt **oder** nichts freigegeben ist, und
    /// die beiden Fälle sind nicht unterscheidbar — Apple verrät den
    /// Lesestatus nicht. Auch unvollständige `DateComponents` ohne
    /// Jahresangabe sind „fehlt": kein Jahr ist kein Jahrgang 0.
    static func birthYear(lesen: () throws -> DateComponents) -> Int? {
        (try? lesen())?.year
    }

    func bodyCharacteristics() async throws -> BodyCharacteristics {
        // Ein Lesefehler ist hier kein Fehler, sondern „kein Wert" — siehe
        // `birthYear(lesen:)`. Wer nach einer gescheiterten Abfrage wirft,
        // machte aus den beiden ununterscheidbaren Fällen zwei
        // verschiedene, und einer davon hieße fälschlich „etwas ist
        // kaputt".
        let probe: HKQuantitySample?
        do {
            probe = try await latestHeightSample()
        } catch {
            probe = nil
        }
        return BodyCharacteristics(
            heightCm: probe.map { Self.heightCm(from: $0.quantity) },
            birthYear: Self.birthYear(lesen: store.dateOfBirthComponents)
        )
    }

    /// Die jüngste Größenprobe, ohne Zeitfenster.
    ///
    /// **Kein `from`/`through`:** Eine Körpergröße ist keine Messreihe, die
    /// man über einen Zeitraum betrachtet. Wer sie auf das Datenfenster
    /// einschränkte, fände bei einem Nutzer, der sie vor fünf Jahren
    /// einmal eingetragen hat, nichts — und das sähe aus wie „nicht
    /// hinterlegt".
    private func latestHeightSample() async throws -> HKQuantitySample? {
        try await withCheckedThrowingContinuation { continuation in
            let neuesteZuerst = NSSortDescriptor(
                key: HKSampleSortIdentifierEndDate, ascending: false)
            let q = HKSampleQuery(
                sampleType: HKQuantityType(.height),
                predicate: nil,
                limit: 1,
                sortDescriptors: [neuesteZuerst]
            ) { _, samples, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: samples?.first as? HKQuantitySample) }
            }
            store.execute(q)
        }
    }
}
