import Testing
@testable import TrainingsCore

@Suite("Erholungs-Ampel")
struct RecoveryTrafficLightTests {

    /// Mediane der letzten 30 Tage. Schwellen daraus:
    /// Ruhepuls ab 65, HRV bis 40, Atemfrequenz ab 13,5. Schlaf unter 6 h, ohne Median.
    private var median: RecoveryBaseline {
        RecoveryBaseline(sleepHours: 7.5, restingHeartRate: 60, hrv: 50, respiratoryRate: 12)
    }

    private var rested: RecoveryReading {
        RecoveryReading(sleepHours: 7.6, restingHeartRate: 59, hrv: 52, respiratoryRate: 12.1)
    }

    // MARK: - Ruhiger Ausgangsfall

    @Test("Ohne Warnsignal ist die Ampel ruhig")
    func calmWithoutSignals() {
        let r = RecoveryTrafficLight.evaluate(reading: rested, baseline: median)
        #expect(r.verdict == .calm)
        #expect(r.signals.isEmpty)
        #expect(r.measuredCount == 4)
    }

    // MARK: - Ruhepuls

    @Test("Ruhepuls knapp unter Median + 5 ist kein Signal")
    func restingHeartRateJustBelowThreshold() {
        let reading = RecoveryReading(sleepHours: 7.6, restingHeartRate: 64.9, hrv: 52, respiratoryRate: 12.1)
        let r = RecoveryTrafficLight.evaluate(reading: reading, baseline: median)
        #expect(r.verdict == .calm)
        #expect(r.signals.isEmpty)
    }

    @Test("Ruhepuls genau auf Median + 5 ist ein Signal")
    func restingHeartRateExactlyAtThreshold() {
        let reading = RecoveryReading(sleepHours: 7.6, restingHeartRate: 65, hrv: 52, respiratoryRate: 12.1)
        let r = RecoveryTrafficLight.evaluate(reading: reading, baseline: median)
        #expect(r.verdict == .watch)
        #expect(r.signals == [.restingHeartRate])
    }

    @Test("Deutlich erhöhter Ruhepuls ist ein Signal")
    func restingHeartRateClearlyAbove() {
        let reading = RecoveryReading(sleepHours: 7.6, restingHeartRate: 72, hrv: 52, respiratoryRate: 12.1)
        let r = RecoveryTrafficLight.evaluate(reading: reading, baseline: median)
        #expect(r.verdict == .watch)
        #expect(r.signals == [.restingHeartRate])
    }

    // MARK: - HRV

    @Test("HRV knapp über 20 % unter dem Median ist kein Signal")
    func hrvJustAboveThreshold() {
        let reading = RecoveryReading(sleepHours: 7.6, restingHeartRate: 59, hrv: 40.1, respiratoryRate: 12.1)
        let r = RecoveryTrafficLight.evaluate(reading: reading, baseline: median)
        #expect(r.verdict == .calm)
        #expect(r.signals.isEmpty)
    }

    @Test("HRV genau 20 % unter dem Median ist ein Signal")
    func hrvExactlyAtThreshold() {
        let reading = RecoveryReading(sleepHours: 7.6, restingHeartRate: 59, hrv: 40, respiratoryRate: 12.1)
        let r = RecoveryTrafficLight.evaluate(reading: reading, baseline: median)
        #expect(r.verdict == .watch)
        #expect(r.signals == [.hrv])
    }

    @Test("Deutlich eingebrochene HRV ist ein Signal")
    func hrvClearlyBelow() {
        let reading = RecoveryReading(sleepHours: 7.6, restingHeartRate: 59, hrv: 30, respiratoryRate: 12.1)
        let r = RecoveryTrafficLight.evaluate(reading: reading, baseline: median)
        #expect(r.verdict == .watch)
        #expect(r.signals == [.hrv])
    }

    // MARK: - Atemfrequenz

    @Test("Atemfrequenz knapp unter Median + 1,5 ist kein Signal")
    func respiratoryRateJustBelowThreshold() {
        let reading = RecoveryReading(sleepHours: 7.6, restingHeartRate: 59, hrv: 52, respiratoryRate: 13.4)
        let r = RecoveryTrafficLight.evaluate(reading: reading, baseline: median)
        #expect(r.verdict == .calm)
        #expect(r.signals.isEmpty)
    }

    @Test("Atemfrequenz genau auf Median + 1,5 ist ein Signal")
    func respiratoryRateExactlyAtThreshold() {
        let reading = RecoveryReading(sleepHours: 7.6, restingHeartRate: 59, hrv: 52, respiratoryRate: 13.5)
        let r = RecoveryTrafficLight.evaluate(reading: reading, baseline: median)
        #expect(r.verdict == .watch)
        #expect(r.signals == [.respiratoryRate])
    }

    @Test("Deutlich erhöhte Atemfrequenz ist ein Signal")
    func respiratoryRateClearlyAbove() {
        let reading = RecoveryReading(sleepHours: 7.6, restingHeartRate: 59, hrv: 52, respiratoryRate: 16)
        let r = RecoveryTrafficLight.evaluate(reading: reading, baseline: median)
        #expect(r.verdict == .watch)
        #expect(r.signals == [.respiratoryRate])
    }

    // MARK: - Schlaf

    @Test("Genau sechs Stunden Schlaf sind kein Signal")
    func sleepExactlySixHours() {
        let reading = RecoveryReading(sleepHours: 6.0, restingHeartRate: 59, hrv: 52, respiratoryRate: 12.1)
        let r = RecoveryTrafficLight.evaluate(reading: reading, baseline: median)
        #expect(r.verdict == .calm)
        #expect(r.signals.isEmpty)
    }

    @Test("Knapp unter sechs Stunden Schlaf ist ein Signal")
    func sleepJustBelowSixHours() {
        let reading = RecoveryReading(sleepHours: 5.99, restingHeartRate: 59, hrv: 52, respiratoryRate: 12.1)
        let r = RecoveryTrafficLight.evaluate(reading: reading, baseline: median)
        #expect(r.verdict == .watch)
        #expect(r.signals == [.sleep])
    }

    @Test("Deutlich zu wenig Schlaf ist ein Signal")
    func sleepClearlyBelowSixHours() {
        let reading = RecoveryReading(sleepHours: 4.5, restingHeartRate: 59, hrv: 52, respiratoryRate: 12.1)
        let r = RecoveryTrafficLight.evaluate(reading: reading, baseline: median)
        #expect(r.verdict == .watch)
        #expect(r.signals == [.sleep])
    }

    @Test("Viel Schlaf ist auch weit über dem Median kein Signal")
    func longSleepIsNeverASignal() {
        let reading = RecoveryReading(sleepHours: 11, restingHeartRate: 59, hrv: 52, respiratoryRate: 12.1)
        let r = RecoveryTrafficLight.evaluate(reading: reading, baseline: median)
        #expect(r.verdict == .calm)
        #expect(r.signals.isEmpty)
    }

    // MARK: - Übergänge und Reihenfolge

    @Test("Zwei Signale heißen Körper unter Stress")
    func twoSignalsMeanStressed() {
        let reading = RecoveryReading(sleepHours: 5.2, restingHeartRate: 66, hrv: 52, respiratoryRate: 12.1)
        let r = RecoveryTrafficLight.evaluate(reading: reading, baseline: median)
        #expect(r.verdict == .stressed)
        #expect(r.signals == [.sleep, .restingHeartRate])
        #expect(r.measuredCount == 4)
    }

    @Test("Die Signale stehen immer in derselben Reihenfolge")
    func signalOrderIsStable() {
        let reading = RecoveryReading(sleepHours: 4.0, restingHeartRate: 70, hrv: 32, respiratoryRate: 14.0)
        let r = RecoveryTrafficLight.evaluate(reading: reading, baseline: median)
        #expect(r.verdict == .stressed)
        #expect(r.signals == [.sleep, .restingHeartRate, .hrv, .respiratoryRate])
        #expect(r.measuredCount == 4)
    }

    @Test("HRV und Atemfrequenz stehen in der Reihenfolge des Vertrags")
    func signalOrderWithoutSleepAndHeartRate() {
        let reading = RecoveryReading(sleepHours: 7.6, restingHeartRate: 59, hrv: 35, respiratoryRate: 15)
        let r = RecoveryTrafficLight.evaluate(reading: reading, baseline: median)
        #expect(r.verdict == .stressed)
        #expect(r.signals == [.hrv, .respiratoryRate])
    }

    @Test("Die Metriken sind in der Reihenfolge des Vertrags aufgezählt")
    func metricOrder() {
        #expect(RecoveryMetric.allCases == [.sleep, .restingHeartRate, .hrv, .respiratoryRate])
    }

    // MARK: - Fehlende Messwerte

    @Test("Ein fehlender Messwert gibt kein Signal und zählt nicht mit")
    func missingValueIsNeitherSignalNorCounted() {
        let reading = RecoveryReading(sleepHours: 7.6, restingHeartRate: 59, hrv: nil, respiratoryRate: 12.1)
        let r = RecoveryTrafficLight.evaluate(reading: reading, baseline: median)
        #expect(r.verdict == .calm)
        #expect(r.signals.isEmpty)
        #expect(r.measuredCount == 3)
    }

    @Test("Ein fehlender Messwert verdeckt die übrigen Signale nicht")
    func missingValueDoesNotHideOtherSignals() {
        let reading = RecoveryReading(sleepHours: nil, restingHeartRate: 68, hrv: 36, respiratoryRate: 12.1)
        let r = RecoveryTrafficLight.evaluate(reading: reading, baseline: median)
        #expect(r.verdict == .stressed)
        #expect(r.signals == [.restingHeartRate, .hrv])
        #expect(r.measuredCount == 3)
    }

    @Test("Ein einziger vorhandener Wert wird bewertet")
    func singleValueIsEnough() {
        let reading = RecoveryReading(sleepHours: nil, restingHeartRate: nil, hrv: 20, respiratoryRate: nil)
        let r = RecoveryTrafficLight.evaluate(reading: reading, baseline: median)
        #expect(r.verdict == .watch)
        #expect(r.signals == [.hrv])
        #expect(r.measuredCount == 1)
    }

    // MARK: - Fehlende Mediane

    @Test("Ohne Mediane gibt es für Ruhepuls, HRV und Atemfrequenz kein Signal")
    func missingBaselineSuppressesSignals() {
        let reading = RecoveryReading(sleepHours: 7.6, restingHeartRate: 90, hrv: 10, respiratoryRate: 22)
        let r = RecoveryTrafficLight.evaluate(reading: reading, baseline: RecoveryBaseline())
        #expect(r.verdict == .calm)
        #expect(r.signals.isEmpty)
        #expect(r.measuredCount == 4)
    }

    @Test("Ein fehlender Median schaltet nur seinen eigenen Wert ab")
    func missingBaselineAffectsOnlyItsOwnMetric() {
        let baseline = RecoveryBaseline(sleepHours: 7.5, restingHeartRate: 60, hrv: nil, respiratoryRate: 12)
        let reading = RecoveryReading(sleepHours: 7.6, restingHeartRate: 70, hrv: 10, respiratoryRate: 12.1)
        let r = RecoveryTrafficLight.evaluate(reading: reading, baseline: baseline)
        #expect(r.verdict == .watch)
        #expect(r.signals == [.restingHeartRate])
        #expect(r.measuredCount == 4)
    }

    @Test("Schlaf braucht keinen Median")
    func sleepNeedsNoBaseline() {
        let reading = RecoveryReading(sleepHours: 5.0, restingHeartRate: nil, hrv: nil, respiratoryRate: nil)
        let r = RecoveryTrafficLight.evaluate(reading: reading, baseline: RecoveryBaseline())
        #expect(r.verdict == .watch)
        #expect(r.signals == [.sleep])
        #expect(r.measuredCount == 1)
    }

    // MARK: - Keine Daten

    @Test("Ohne jeden Messwert gibt es keine Bewertung")
    func noDataWithoutAnyReading() {
        let r = RecoveryTrafficLight.evaluate(reading: RecoveryReading(), baseline: RecoveryBaseline())
        #expect(r.verdict == .noData)
        #expect(r.signals.isEmpty)
        #expect(r.measuredCount == 0)
    }

    @Test("Mediane allein ergeben noch keine Bewertung")
    func noDataEvenWithBaseline() {
        let r = RecoveryTrafficLight.evaluate(reading: RecoveryReading(), baseline: median)
        #expect(r.verdict == .noData)
        #expect(r.signals.isEmpty)
        #expect(r.measuredCount == 0)
    }

    // MARK: - Erholung nach der OP

    @Test("Nach der OP wird nicht bewertet")
    func postOperativeNeverJudges() {
        let reading = RecoveryReading(sleepHours: 4.0, restingHeartRate: 70, hrv: 32, respiratoryRate: 14.0)
        let r = RecoveryTrafficLight.evaluate(reading: reading, baseline: median, isPostOperative: true)
        #expect(r.verdict == .postOperative)
        #expect(r.signals.isEmpty)
        #expect(r.measuredCount == 4)
    }

    @Test("Nach der OP zählt die Anzahl der Messwerte trotzdem")
    func postOperativeStillCountsMeasurements() {
        let reading = RecoveryReading(sleepHours: 7.6, restingHeartRate: nil, hrv: 52, respiratoryRate: nil)
        let r = RecoveryTrafficLight.evaluate(reading: reading, baseline: median, isPostOperative: true)
        #expect(r.verdict == .postOperative)
        #expect(r.signals.isEmpty)
        #expect(r.measuredCount == 2)
    }

    @Test("Nach der OP gilt das auch ohne jeden Messwert")
    func postOperativeBeatsNoData() {
        let r = RecoveryTrafficLight.evaluate(reading: RecoveryReading(),
                                              baseline: RecoveryBaseline(),
                                              isPostOperative: true)
        #expect(r.verdict == .postOperative)
        #expect(r.signals.isEmpty)
        #expect(r.measuredCount == 0)
    }

    @Test("Ohne Angabe wird nicht von einer OP ausgegangen")
    func postOperativeDefaultsToFalse() {
        let reading = RecoveryReading(sleepHours: 4.0, restingHeartRate: 70, hrv: 32, respiratoryRate: 14.0)
        #expect(RecoveryTrafficLight.evaluate(reading: reading, baseline: median).verdict == .stressed)
    }

    // MARK: - Nacht aus dem Prototyp

    @Test("Die Nacht aus dem Prototyp meldet Schlaf und HRV")
    func prototypeNight() {
        let reading = RecoveryReading(sleepHours: 5.58, restingHeartRate: 64, hrv: 46, respiratoryRate: 11.6)
        let baseline = RecoveryBaseline(sleepHours: 7.1, restingHeartRate: 61, hrv: 59, respiratoryRate: 11.8)
        let r = RecoveryTrafficLight.evaluate(reading: reading, baseline: baseline)
        #expect(r.verdict == .stressed)
        #expect(r.signals == [.sleep, .hrv])
        #expect(r.measuredCount == 4)
    }
}
