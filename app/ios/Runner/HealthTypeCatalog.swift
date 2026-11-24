import Foundation
import HealthKit

/// Jeder lesbare HealthKit-Typ, den Apple anbietet.
///
/// Bewusst vollständig statt bedarfsgerecht: Es gibt genau einen
/// Berechtigungsdialog pro App-Installation. Was hier fehlt, kostet später
/// einen zweiten.
///
/// Die Bezeichner stehen als Zeichenketten, nicht als typisierte Konstanten.
/// Dadurch übersetzt die Datei auch dann, wenn ein Typ erst in einer neueren
/// iOS-Fassung existiert — unbekannte Bezeichner geben `nil` zurück und
/// fallen still heraus, statt den Build zu brechen.
///
/// **Nicht enthalten:** klinische Gesundheitsakten (`HKClinicalType`). Die
/// brauchen das Entitlement `com.apple.developer.healthkit.access`, das ein
/// kostenloses Personal Team nicht vergeben kann.
///
/// Portiert aus `Sources/Health/HealthTypeCatalog.swift` (Spec 8.2, Task 12),
/// weitgehend unverändert — bis auf `allReadableTypeIdentifiers`, eine
/// zusätzliche API, die `HealthTypeCatalogTests.swift` braucht, um den
/// Pflichtfall „keine Korrelationstypen in der Leseanfrage" zu prüfen, ohne
/// die privaten Identifier-Listen selbst offenzulegen.
enum HealthTypeCatalog {

    static var allReadableTypes: Set<HKObjectType> {
        var types = Set<HKObjectType>()
        types.formUnion(quantityIdentifiers.compactMap {
            HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier(rawValue: $0))
        })
        types.formUnion(categoryIdentifiers.compactMap {
            HKObjectType.categoryType(forIdentifier: HKCategoryTypeIdentifier(rawValue: $0))
        })
        types.formUnion(characteristicIdentifiers.compactMap {
            HKObjectType.characteristicType(forIdentifier: HKCharacteristicTypeIdentifier(rawValue: $0))
        })
        types.insert(HKObjectType.workoutType())
        types.insert(HKObjectType.activitySummaryType())
        types.insert(HKSeriesType.workoutRoute())
        types.insert(HKSeriesType.heartbeat())
        types.insert(HKObjectType.audiogramSampleType())
        types.insert(HKObjectType.electrocardiogramType())
        if #available(iOS 18.0, *) {
            types.insert(HKObjectType.stateOfMindType())
        }
        return types
    }

    /// Alle rohen Kennungen aus `quantityIdentifiers`, `categoryIdentifiers`
    /// und `characteristicIdentifiers` in einer Liste — ohne
    /// Korrelationstypen (siehe unten). Dient ausschließlich Tests:
    /// `allReadableTypes` bleibt die für `requestAuthorization()`
    /// maßgebliche Quelle.
    static var allReadableTypeIdentifiers: [String] {
        quantityIdentifiers + categoryIdentifiers + characteristicIdentifiers
    }

    /// Was die App nach HealthKit **schreiben** darf: das Körpergewicht
    /// (#270) und die acht Ernährungstypen, die gebucht werden (#283).
    ///
    /// **Bewusst keine Spiegelung von `allReadableTypes`.** Beim Lesen ist
    /// der Katalog vollständig, weil es nur einen Lesedialog je
    /// Installation gibt und ein später fehlender Typ eine Neuinstallation
    /// kostet. Beim Schreiben gilt das Gegenteil: Ein `toShare`-Satz, der
    /// mehr enthält, als die App tut, legt dem Nutzer Schalter für Dinge
    /// vor, die nicht passieren — und das ist ein Fehler, den man pro
    /// Installation nur einmal macht (Tim, 03.11.2026).
    ///
    /// Körperfett und fettfreie Masse fehlen mit Absicht: „jede Waage misst
    /// da anders". Der Gym-Rückschreiber aus SPEC 4.4 kommt eigenständig
    /// und bringt seine eigene Freigabe mit.
    ///
    /// **Zwei Dialoge, nicht einer** (Spec Ernährung, „Der Schreibkatalog"):
    /// Der Gewichts-Dialog fragt nur [weightWritableTypes], der
    /// Ernährungs-Dialog nur [nutritionWritableTypes]. Er erscheint beim
    /// ersten Buchen — wer nie etwas einträgt, wird nie gefragt. Dieser
    /// Satz ist die Vereinigung beider, damit sich prüfen lässt, dass die
    /// App nichts darüber hinaus schreibt.
    ///
    /// Die Mikronährstoffe fehlen mit Absicht: Sie kommen mit dem
    /// Vitamin-Schirm und bringen ihren eigenen Dialog mit.
    static var writableTypes: Set<HKSampleType> {
        weightWritableTypes.union(nutritionWritableTypes)
    }

    /// Der Gewichts-Dialog (#270).
    static var weightWritableTypes: Set<HKSampleType> {
        [HKQuantityType(.bodyMass)]
    }

    /// Der Ernährungs-Dialog (#283) — genau die Typen, die
    /// `HealthNutrition.quantitySamples` schreibt. **Kein Korrelationstyp:**
    /// `HKCorrelationTypeIdentifierFood` in `toShare` beendet die App mit
    /// einer `NSInvalidArgumentException` (im Simulator geprüft am
    /// 04.11.2026, siehe `HealthNutritionWriting.swift`).
    static var nutritionWritableTypes: Set<HKSampleType> {
        Set(HealthNutrition.fields.map { HKQuantityType($0.type) })
    }

    // MARK: - Mengentypen

    private static let quantityIdentifiers: [String] = [
        // Körpermaße
        "HKQuantityTypeIdentifierBodyMassIndex",
        "HKQuantityTypeIdentifierBodyFatPercentage",
        "HKQuantityTypeIdentifierHeight",
        "HKQuantityTypeIdentifierBodyMass",
        "HKQuantityTypeIdentifierLeanBodyMass",
        "HKQuantityTypeIdentifierWaistCircumference",
        "HKQuantityTypeIdentifierAppleSleepingWristTemperature",

        // Aktivität
        "HKQuantityTypeIdentifierStepCount",
        "HKQuantityTypeIdentifierDistanceWalkingRunning",
        "HKQuantityTypeIdentifierDistanceCycling",
        "HKQuantityTypeIdentifierDistanceWheelchair",
        "HKQuantityTypeIdentifierBasalEnergyBurned",
        "HKQuantityTypeIdentifierActiveEnergyBurned",
        "HKQuantityTypeIdentifierFlightsClimbed",
        "HKQuantityTypeIdentifierNikeFuel",
        "HKQuantityTypeIdentifierAppleExerciseTime",
        "HKQuantityTypeIdentifierAppleMoveTime",
        "HKQuantityTypeIdentifierAppleStandTime",
        "HKQuantityTypeIdentifierPushCount",
        "HKQuantityTypeIdentifierDistanceSwimming",
        "HKQuantityTypeIdentifierSwimmingStrokeCount",
        "HKQuantityTypeIdentifierVO2Max",
        "HKQuantityTypeIdentifierDistanceDownhillSnowSports",
        "HKQuantityTypeIdentifierDistanceCrossCountrySkiing",
        "HKQuantityTypeIdentifierCrossCountrySkiingSpeed",
        "HKQuantityTypeIdentifierDistancePaddleSports",
        "HKQuantityTypeIdentifierPaddleSportsSpeed",
        "HKQuantityTypeIdentifierDistanceRowing",
        "HKQuantityTypeIdentifierRowingSpeed",
        "HKQuantityTypeIdentifierDistanceSkatingSports",
        "HKQuantityTypeIdentifierPhysicalEffort",
        "HKQuantityTypeIdentifierWorkoutEffortScore",
        "HKQuantityTypeIdentifierEstimatedWorkoutEffortScore",

        // Lauftechnik
        "HKQuantityTypeIdentifierRunningStrideLength",
        "HKQuantityTypeIdentifierRunningVerticalOscillation",
        "HKQuantityTypeIdentifierRunningGroundContactTime",
        "HKQuantityTypeIdentifierRunningPower",
        "HKQuantityTypeIdentifierRunningSpeed",

        // Radfahren
        "HKQuantityTypeIdentifierCyclingSpeed",
        "HKQuantityTypeIdentifierCyclingPower",
        "HKQuantityTypeIdentifierCyclingFunctionalThresholdPower",
        "HKQuantityTypeIdentifierCyclingCadence",

        // Unterwasser
        "HKQuantityTypeIdentifierUnderwaterDepth",
        "HKQuantityTypeIdentifierWaterTemperature",

        // Herz und Kreislauf
        "HKQuantityTypeIdentifierHeartRate",
        "HKQuantityTypeIdentifierRestingHeartRate",
        "HKQuantityTypeIdentifierWalkingHeartRateAverage",
        "HKQuantityTypeIdentifierHeartRateVariabilitySDNN",
        "HKQuantityTypeIdentifierHeartRateRecoveryOneMinute",
        "HKQuantityTypeIdentifierAtrialFibrillationBurden",
        "HKQuantityTypeIdentifierPeripheralPerfusionIndex",
        "HKQuantityTypeIdentifierBloodPressureSystolic",
        "HKQuantityTypeIdentifierBloodPressureDiastolic",

        // Atmung
        "HKQuantityTypeIdentifierRespiratoryRate",
        "HKQuantityTypeIdentifierOxygenSaturation",
        "HKQuantityTypeIdentifierForcedExpiratoryVolume1",
        "HKQuantityTypeIdentifierForcedVitalCapacity",
        "HKQuantityTypeIdentifierPeakExpiratoryFlowRate",
        "HKQuantityTypeIdentifierInhalerUsage",
        "HKQuantityTypeIdentifierAppleSleepingBreathingDisturbances",

        // Weitere Vitalwerte
        "HKQuantityTypeIdentifierBodyTemperature",
        "HKQuantityTypeIdentifierBasalBodyTemperature",
        "HKQuantityTypeIdentifierBloodGlucose",
        "HKQuantityTypeIdentifierBloodAlcoholContent",
        "HKQuantityTypeIdentifierElectrodermalActivity",
        "HKQuantityTypeIdentifierInsulinDelivery",
        "HKQuantityTypeIdentifierNumberOfTimesFallen",
        "HKQuantityTypeIdentifierNumberOfAlcoholicBeverages",

        // Gang und Mobilität
        "HKQuantityTypeIdentifierSixMinuteWalkTestDistance",
        "HKQuantityTypeIdentifierWalkingSpeed",
        "HKQuantityTypeIdentifierWalkingStepLength",
        "HKQuantityTypeIdentifierWalkingAsymmetryPercentage",
        "HKQuantityTypeIdentifierWalkingDoubleSupportPercentage",
        "HKQuantityTypeIdentifierStairAscentSpeed",
        "HKQuantityTypeIdentifierStairDescentSpeed",
        "HKQuantityTypeIdentifierAppleWalkingSteadiness",

        // Umwelt
        "HKQuantityTypeIdentifierEnvironmentalAudioExposure",
        "HKQuantityTypeIdentifierHeadphoneAudioExposure",
        "HKQuantityTypeIdentifierEnvironmentalSoundReduction",
        "HKQuantityTypeIdentifierUVExposure",
        "HKQuantityTypeIdentifierTimeInDaylight",

        // Ernährung
        "HKQuantityTypeIdentifierDietaryEnergyConsumed",
        "HKQuantityTypeIdentifierDietaryProtein",
        "HKQuantityTypeIdentifierDietaryCarbohydrates",
        "HKQuantityTypeIdentifierDietaryFiber",
        "HKQuantityTypeIdentifierDietarySugar",
        "HKQuantityTypeIdentifierDietaryFatTotal",
        "HKQuantityTypeIdentifierDietaryFatSaturated",
        "HKQuantityTypeIdentifierDietaryFatMonounsaturated",
        "HKQuantityTypeIdentifierDietaryFatPolyunsaturated",
        "HKQuantityTypeIdentifierDietaryCholesterol",
        "HKQuantityTypeIdentifierDietarySodium",
        "HKQuantityTypeIdentifierDietaryWater",
        "HKQuantityTypeIdentifierDietaryCaffeine",
        "HKQuantityTypeIdentifierDietaryVitaminA",
        "HKQuantityTypeIdentifierDietaryVitaminB6",
        "HKQuantityTypeIdentifierDietaryVitaminB12",
        "HKQuantityTypeIdentifierDietaryVitaminC",
        "HKQuantityTypeIdentifierDietaryVitaminD",
        "HKQuantityTypeIdentifierDietaryVitaminE",
        "HKQuantityTypeIdentifierDietaryVitaminK",
        "HKQuantityTypeIdentifierDietaryThiamin",
        "HKQuantityTypeIdentifierDietaryRiboflavin",
        "HKQuantityTypeIdentifierDietaryNiacin",
        "HKQuantityTypeIdentifierDietaryPantothenicAcid",
        "HKQuantityTypeIdentifierDietaryBiotin",
        "HKQuantityTypeIdentifierDietaryFolate",
        "HKQuantityTypeIdentifierDietaryCalcium",
        "HKQuantityTypeIdentifierDietaryMagnesium",
        "HKQuantityTypeIdentifierDietaryIron",
        "HKQuantityTypeIdentifierDietaryZinc",
        "HKQuantityTypeIdentifierDietaryIodine",
        "HKQuantityTypeIdentifierDietarySelenium",
        "HKQuantityTypeIdentifierDietaryPotassium",
        "HKQuantityTypeIdentifierDietaryPhosphorus",
        "HKQuantityTypeIdentifierDietaryCopper",
        "HKQuantityTypeIdentifierDietaryManganese",
        "HKQuantityTypeIdentifierDietaryChromium",
        "HKQuantityTypeIdentifierDietaryMolybdenum",
        "HKQuantityTypeIdentifierDietaryChloride"
    ]

    // MARK: - Kategorietypen

    private static let categoryIdentifiers: [String] = [
        "HKCategoryTypeIdentifierSleepAnalysis",
        "HKCategoryTypeIdentifierAppleStandHour",
        "HKCategoryTypeIdentifierMindfulSession",
        "HKCategoryTypeIdentifierHighHeartRateEvent",
        "HKCategoryTypeIdentifierLowHeartRateEvent",
        "HKCategoryTypeIdentifierIrregularHeartRhythmEvent",
        "HKCategoryTypeIdentifierLowCardioFitnessEvent",
        "HKCategoryTypeIdentifierAppleWalkingSteadinessEvent",
        "HKCategoryTypeIdentifierSleepApneaEvent",
        "HKCategoryTypeIdentifierHandwashingEvent",
        "HKCategoryTypeIdentifierToothbrushingEvent",
        "HKCategoryTypeIdentifierAudioExposureEvent",
        "HKCategoryTypeIdentifierHeadphoneAudioExposureEvent",
        "HKCategoryTypeIdentifierEnvironmentalAudioExposureEvent",
        // Zyklus und Reproduktion
        "HKCategoryTypeIdentifierMenstrualFlow",
        "HKCategoryTypeIdentifierIntermenstrualBleeding",
        "HKCategoryTypeIdentifierPersistentIntermenstrualBleeding",
        "HKCategoryTypeIdentifierInfrequentMenstrualCycles",
        "HKCategoryTypeIdentifierIrregularMenstrualCycles",
        "HKCategoryTypeIdentifierProlongedMenstrualPeriods",
        "HKCategoryTypeIdentifierCervicalMucusQuality",
        "HKCategoryTypeIdentifierOvulationTestResult",
        "HKCategoryTypeIdentifierPregnancyTestResult",
        "HKCategoryTypeIdentifierProgesteroneTestResult",
        "HKCategoryTypeIdentifierSexualActivity",
        "HKCategoryTypeIdentifierContraceptive",
        "HKCategoryTypeIdentifierPregnancy",
        "HKCategoryTypeIdentifierLactation",
        // Symptome
        "HKCategoryTypeIdentifierAbdominalCramps",
        "HKCategoryTypeIdentifierAcne",
        "HKCategoryTypeIdentifierAppetiteChanges",
        "HKCategoryTypeIdentifierBladderIncontinence",
        "HKCategoryTypeIdentifierBloating",
        "HKCategoryTypeIdentifierBreastPain",
        "HKCategoryTypeIdentifierChestTightnessOrPain",
        "HKCategoryTypeIdentifierChills",
        "HKCategoryTypeIdentifierConstipation",
        "HKCategoryTypeIdentifierCoughing",
        "HKCategoryTypeIdentifierDiarrhea",
        "HKCategoryTypeIdentifierDizziness",
        "HKCategoryTypeIdentifierDrySkin",
        "HKCategoryTypeIdentifierFainting",
        "HKCategoryTypeIdentifierFatigue",
        "HKCategoryTypeIdentifierFever",
        "HKCategoryTypeIdentifierGeneralizedBodyAche",
        "HKCategoryTypeIdentifierHairLoss",
        "HKCategoryTypeIdentifierHeadache",
        "HKCategoryTypeIdentifierHeartburn",
        "HKCategoryTypeIdentifierHotFlashes",
        "HKCategoryTypeIdentifierLossOfSmell",
        "HKCategoryTypeIdentifierLossOfTaste",
        "HKCategoryTypeIdentifierLowerBackPain",
        "HKCategoryTypeIdentifierMemoryLapse",
        "HKCategoryTypeIdentifierMoodChanges",
        "HKCategoryTypeIdentifierNausea",
        "HKCategoryTypeIdentifierNightSweats",
        "HKCategoryTypeIdentifierPelvicPain",
        "HKCategoryTypeIdentifierRapidPoundingOrFlutteringHeartbeat",
        "HKCategoryTypeIdentifierRunnyNose",
        "HKCategoryTypeIdentifierShortnessOfBreath",
        "HKCategoryTypeIdentifierSinusCongestion",
        "HKCategoryTypeIdentifierSkippedHeartbeat",
        "HKCategoryTypeIdentifierSleepChanges",
        "HKCategoryTypeIdentifierSoreThroat",
        "HKCategoryTypeIdentifierVaginalDryness",
        "HKCategoryTypeIdentifierVomiting",
        "HKCategoryTypeIdentifierWheezing"
    ]

    // MARK: - Merkmalstypen

    private static let characteristicIdentifiers: [String] = [
        "HKCharacteristicTypeIdentifierBiologicalSex",
        "HKCharacteristicTypeIdentifierBloodType",
        "HKCharacteristicTypeIdentifierDateOfBirth",
        "HKCharacteristicTypeIdentifierFitzpatrickSkinType",
        "HKCharacteristicTypeIdentifierWheelchairUse",
        "HKCharacteristicTypeIdentifierActivityMoveMode"
    ]

    // MARK: - Korrelationstypen: absichtlich NICHT angefragt

    // HealthKit wirft beim Anfragen von Leserechten für Korrelationstypen eine
    // NSInvalidArgumentException und die App stürzt ab:
    //
    //     Authorization to read the following types is disallowed:
    //     HKCorrelationTypeIdentifierBloodPressure, HKCorrelationTypeIdentifierFood
    //
    // Erlaubt sind nur die Einzelwerte, aus denen eine Korrelation besteht —
    // bei Food die dietary*-Typen, bei BloodPressure systolisch und
    // diastolisch. Die stehen alle oben in `quantityIdentifiers`.
    //
    // Abfragen über HKCorrelationType funktionieren trotzdem: Wer die
    // Einzelwerte lesen darf, bekommt auch die Korrelation. Genau so holt
    // HealthKitReading.nutritionEntries die Lebensmittelnamen.
}
