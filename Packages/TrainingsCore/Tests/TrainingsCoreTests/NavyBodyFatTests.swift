import Foundation
import Testing
@testable import TrainingsCore

@Suite("Körperfett nach Maßband")
struct NavyBodyFatTests {

    @Test("Die Formel der Spec ergibt rund 11,3 Prozent")
    func matchesTheSpecExample() throws {
        // Taille 79,0 · Hals 37,5 (Prototyp) · Größe 182 (SPEC Abschnitt 1).
        // 495 / (1,0324 − 0,19077·log10(41,5) + 0,15456·log10(182)) − 450
        // = 495 / 1,073037 − 450 = 11,3055…
        //
        // Der Prototyp schreibt an dieser Stelle 15,6 %. Diese Zahl folgt
        // nicht aus der Formel — sie ist dort von Hand eingetragen. Maßgeblich
        // ist die Formel aus SPEC 4.6, nicht die Beschriftung im Entwurf.
        let value = try #require(NavyBodyFat.percent(waistCm: 79.0, neckCm: 37.5,
                                                     heightCm: 182))
        #expect(abs(value - 11.3) < 0.2)
    }

    @Test("Eine dickere Taille ergibt mehr Fett")
    func largerWaistMeansMoreFat() throws {
        let thin = try #require(NavyBodyFat.percent(waistCm: 75, neckCm: 37.5,
                                                    heightCm: 182))
        let wide = try #require(NavyBodyFat.percent(waistCm: 90, neckCm: 37.5,
                                                    heightCm: 182))
        #expect(wide > thin)
    }

    @Test("Taille gleich oder kleiner als Hals ergibt keinen Wert")
    func waistNotLargerThanNeckYieldsNothing() {
        // log10(0) ist −inf, log10 einer negativen Zahl ist NaN. Ohne diese
        // Abfrage stünde „nan %" auf dem Schirm; ein Zahlendreher beim
        // Eintragen reicht dafür aus.
        #expect(NavyBodyFat.percent(waistCm: 37.5, neckCm: 37.5, heightCm: 182) == nil)
        #expect(NavyBodyFat.percent(waistCm: 30, neckCm: 37.5, heightCm: 182) == nil)
    }

    @Test("Fehlende oder unsinnige Größe ergibt keinen Wert")
    func heightMustBePositive() {
        #expect(NavyBodyFat.percent(waistCm: 79, neckCm: 37.5, heightCm: 0) == nil)
        #expect(NavyBodyFat.percent(waistCm: 79, neckCm: 37.5, heightCm: -182) == nil)
    }

    @Test("Ein Ergebnis außerhalb von 1 bis 70 Prozent gilt als Unsinn")
    func implausibleResultsAreRejected() {
        // Taille nur 0,1 cm über dem Hals: log10(0,1) ist −1, der Teiler
        // wächst auf rund 1,573, und heraus kommen etwa −135 Prozent. Die
        // Formel rechnet weiter, das Ergebnis ist trotzdem Unsinn.
        #expect(NavyBodyFat.percent(waistCm: 37.6, neckCm: 37.5, heightCm: 182) == nil)
    }

    @Test("Das Ergebnis kommt auf eine Nachkommastelle gerundet")
    func resultIsRoundedToOneDecimal() throws {
        let value = try #require(NavyBodyFat.percent(waistCm: 79.0, neckCm: 37.5,
                                                     heightCm: 182))
        #expect(value == (value * 10).rounded() / 10)
    }

    @Test("Es gibt dreizehn Maße, und nur bei der Taille ist weniger besser")
    func thirteenMeasuresAndOnlyTheWaistShrinks() {
        // Oberschenkel und Wade zählen seit dem Eingabeschirm je Seite.
        #expect(Circumference.allCases.count == 13)
        #expect(Circumference.allCases.filter(\.lessIsBetter) == [.waist])
        #expect(Circumference.waist.german == "Taille (Nabel)")
        // Zwei gleiche Beschriftungen wären in der Liste nicht auseinander-
        // zuhalten — etwa links und rechts, die nur im Rohnamen abweichen.
        #expect(Set(Circumference.allCases.map(\.german)).count == 13)
        #expect(Circumference.thighRight.german == "Oberschenkel rechts")
        #expect(Circumference.calfLeft.german == "Wade links")
    }

    @Test("Jede Gruppe hat ihre Anzahl: Arme vier, Rumpf fünf, Beine vier")
    func eachGroupHasItsCount() {
        let byGroup = Dictionary(grouping: Circumference.allCases, by: \.group)
        #expect(byGroup[.arms]?.count == 4)
        #expect(byGroup[.torso]?.count == 5)
        #expect(byGroup[.legs]?.count == 4)
        #expect(CircumferenceGroup.allCases == [.arms, .torso, .legs])
        #expect(CircumferenceGroup.arms.german == "Arme")
        #expect(CircumferenceGroup.torso.german == "Rumpf")
        #expect(CircumferenceGroup.legs.german == "Beine")
    }

    @Test("Die Reihenfolge der Maße ist Arme, Rumpf, Beine")
    func allCasesRunFromArmsToLegs() {
        // `allCases` ist die Reihenfolge im Formular und in der Tabelle. Eine
        // Gruppe, die zweimal auftaucht, zerrisse eine der drei Karten.
        let expected = Array(repeating: CircumferenceGroup.arms, count: 4)
            + Array(repeating: .torso, count: 5)
            + Array(repeating: .legs, count: 4)
        #expect(Circumference.allCases.map(\.group) == expected)
    }

    @Test("Rechts behält die alten Rohwerte thigh und calf")
    func rightSideKeepsTheOldRawValues() {
        // Schon abgelegte und exportierte Dateien kennen nur `thigh` und
        // `calf`. Würden die Rohwerte wandern, läsen sie sich als nichts.
        #expect(Circumference.thighRight.rawValue == "thigh")
        #expect(Circumference.calfRight.rawValue == "calf")
        #expect(Circumference(rawValue: "thigh") == .thighRight)
        #expect(Circumference(rawValue: "calf") == .calfRight)
    }
}
