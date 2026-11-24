import Foundation
import Testing
@testable import TrainingsCore

/// Was in einem der dreizehn Zahlenfelder stehen darf. Die Prüfung gehört
/// hierher und nicht in die Ansicht: Ein Feld, das stillschweigend nichts
/// speichert, fällt erst Wochen später im Verlauf auf.
@Suite("Umfang eintippen")
struct CircumferenceInputTests {

    @Test("Komma und Punkt ergeben dieselbe Zahl")
    func commaAndDotAreBothAccepted() {
        // Die deutsche Tastatur liefert ein Komma, `Double("27,0")` ergibt nil.
        #expect(CircumferenceInput.validate("27,0") == .value(27))
        #expect(CircumferenceInput.validate("27.0") == .value(27))
    }

    @Test("Ein leeres Feld wird nicht gespeichert")
    func emptyFieldIsNotStored() {
        #expect(CircumferenceInput.validate("") == .empty)
        #expect(CircumferenceInput.validate("   ") == .empty)
    }

    @Test("Leerzeichen und ein angehängtes cm werden abgeschnitten")
    func whitespaceAndUnitAreTrimmed() {
        #expect(CircumferenceInput.validate(" 27 cm ") == .value(27))
    }

    @Test("Was keine Zahl ist, wird als solches gemeldet")
    func lettersAndDoubleSeparatorsAreNotNumbers() {
        #expect(CircumferenceInput.validate("abc") == .notANumber)
        // Zwei Trennzeichen: ein Tippfehler, keine Zahl. Als 27,01 geraten
        // stünde ein Wert im Verlauf, den niemand gemessen hat.
        #expect(CircumferenceInput.validate("27,0,1") == .notANumber)
    }

    @Test("Außerhalb von 10 bis 200 cm gilt der Wert als unplausibel")
    func outOfRangeKeepsTheNumber() {
        // Die gelesene Zahl kommt mit, damit die rote Zeile sagen kann,
        // was dasteht.
        #expect(CircumferenceInput.validate("0") == .outOfRange(0))
        #expect(CircumferenceInput.validate("9,9") == .outOfRange(9.9))
        #expect(CircumferenceInput.validate("200,1") == .outOfRange(200.1))
        #expect(CircumferenceInput.validate("-5") == .outOfRange(-5))
    }

    @Test("Die Grenzen selbst sind gültig")
    func boundsAreIncluded() {
        #expect(CircumferenceInput.validate("10") == .value(10))
        #expect(CircumferenceInput.validate("200") == .value(200))
    }

    @Test("Der plausible Bereich ist 10 bis 200 Zentimeter")
    func plausibleRangeIsTenToTwoHundred() {
        #expect(CircumferenceInput.plausible == 10...200)
    }
}
