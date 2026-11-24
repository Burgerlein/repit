import Testing
@testable import TrainingsCore

@Suite("Herzfrequenz-Zonen nach Karvonen")
struct HeartRateZonesTests {

    @Test("Zonengrenzen für HFmax 205 und Ruhepuls 62")
    func boundsForTimsValues() {
        let r = HeartRateZones.zoning(hrMax: 205, hrRest: 62)
        let z = r.zones
        #expect(z.count == 5)
        #expect(r.clamped == false)
        #expect(z[0].lower == 134)
        #expect(z[0].upper == 148)
        #expect(z[1].lower == 148)
        #expect(z[1].upper == 162)
        #expect(z[2].upper == 176)
        #expect(z[3].upper == 191)
        #expect(z[4].upper == 205)
    }

    // Review Focus 4
    @Test("Zonen bleiben geordnet, wenn der Ruhepuls über der HFmax liegt")
    func staysOrderedOnAbsurdInput() {
        let r = HeartRateZones.zoning(hrMax: 150, hrRest: 160)
        let z = r.zones
        #expect(r.clamped, "Die Klemmung muss sichtbar sein, damit die Oberfläche warnen kann")
        for zone in z {
            #expect(zone.lower <= zone.upper)
        }
        for i in 1..<z.count {
            #expect(z[i - 1].upper <= z[i].lower)
        }
    }
}
