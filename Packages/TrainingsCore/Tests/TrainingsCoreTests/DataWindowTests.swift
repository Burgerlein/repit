import Foundation
import Testing
@testable import TrainingsCore

/// Eigene Hilfstypen, damit die Tests nicht von `DailyMetrics` abhängen.
/// `Messpunkt` trägt das Datum unter `date`, `Abschnitt` unter `start` —
/// `clip` muss über beliebige KeyPaths laufen.
private struct Messpunkt: Equatable {
    let date: Date
    let wert: Double
}

private struct Abschnitt: Equatable {
    let start: Date
}

@Suite("Betrachtungszeitraum als Wert")
struct DataWindowTests {

    private func date(_ iso: String) -> Date {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: iso)!
    }

    /// Fünf aufeinanderfolgende Tage im Juli, jeweils morgens um 06:40.
    private func julitage() -> [Messpunkt] {
        [
            Messpunkt(date: date("2026-07-01T06:40:00+02:00"), wert: 1),
            Messpunkt(date: date("2026-07-02T06:40:00+02:00"), wert: 2),
            Messpunkt(date: date("2026-07-03T06:40:00+02:00"), wert: 3),
            Messpunkt(date: date("2026-07-04T06:40:00+02:00"), wert: 4),
            Messpunkt(date: date("2026-07-05T06:40:00+02:00"), wert: 5)
        ]
    }

    // MARK: - Keine Grenze

    @Test("Ohne Grenze wird nichts beschnitten")
    func keineGrenzeBeschneidetNichts() {
        let fenster = DataWindow.unlimited
        let reihe = julitage()
        #expect(fenster.clip(reihe, by: \.date) == reihe)
    }

    @Test("Ohne Grenze liegt jedes Datum innerhalb")
    func keineGrenzeEnthaeltAlles() {
        let fenster = DataWindow.unlimited
        #expect(fenster.start == nil)
        #expect(fenster.contains(date("1970-01-01T00:00:00+01:00")))
        #expect(fenster.contains(date("2026-07-03T06:40:00+02:00")))
        #expect(fenster.contains(date("2099-12-31T23:59:00+01:00")))
    }

    @Test("`unlimited` ist dasselbe wie eine Grenze von nil")
    func unlimitedIstGrenzeNil() {
        #expect(DataWindow.unlimited == DataWindow(start: nil))
    }

    // MARK: - Lage der Grenze zur Reihe

    @Test("Eine Grenze vor dem ältesten Datum beschneidet nichts")
    func grenzeVorAllenDaten() {
        let fenster = DataWindow(start: date("2026-06-01T12:00:00+02:00"))
        let reihe = julitage()
        #expect(fenster.clip(reihe, by: \.date) == reihe)
    }

    @Test("Eine Grenze mitten in der Reihe behält den Grenztag")
    func grenzeMittenInDerReihe() {
        let fenster = DataWindow(start: date("2026-07-03T12:00:00+02:00"))
        let behalten = fenster.clip(julitage(), by: \.date)
        #expect(behalten.map(\.wert) == [3, 4, 5])
    }

    @Test("Eine Grenze auf dem letzten Tag lässt nur diesen Tag übrig")
    func grenzeAufHeute() {
        let heute = date("2026-07-05T09:00:00+02:00")
        let fenster = DataWindow(start: heute)
        let behalten = fenster.clip(julitage(), by: \.date)
        #expect(behalten.map(\.wert) == [5])
    }

    @Test("Eine Grenze nach dem jüngsten Datum leert die Reihe")
    func grenzeNachDemJuengstenDatum() {
        let fenster = DataWindow(start: date("2026-07-06T00:00:00+02:00"))
        #expect(fenster.clip(julitage(), by: \.date).isEmpty)
    }

    @Test("Eine Grenze in der Zukunft leert jede Reihe, ohne abzustürzen")
    func grenzeInDerZukunft() {
        let fenster = DataWindow(start: date("2099-01-01T00:00:00+01:00"))
        #expect(fenster.clip(julitage(), by: \.date).isEmpty)
        #expect(fenster.contains(date("2026-07-03T06:40:00+02:00")) == false)
        #expect(fenster.contains(date("2098-12-31T23:59:00+01:00")) == false)
    }

    @Test("Eine leere Reihe bleibt leer")
    func leereEingabeLeereAusgabe() {
        let ohne = DataWindow.unlimited
        let mit = DataWindow(start: date("2026-07-03T12:00:00+02:00"))
        #expect(ohne.clip([Messpunkt](), by: \.date).isEmpty)
        #expect(mit.clip([Messpunkt](), by: \.date).isEmpty)
    }

    // MARK: - Tagesgenau, nicht sekundengenau

    @Test("Eine um 23:30 gesetzte Grenze meint den ganzen Tag")
    func grenzeUmHalbZwoelfNachtsMeintDenGanzenTag() {
        let fenster = DataWindow(start: date("2026-07-03T23:30:00+02:00"))
        #expect(fenster.start == date("2026-07-03T00:00:00+02:00"))
        #expect(fenster.contains(date("2026-07-03T00:00:00+02:00")))
        #expect(fenster.contains(date("2026-07-03T06:40:00+02:00")))
        #expect(fenster.clip(julitage(), by: \.date).map(\.wert) == [3, 4, 5])
    }

    @Test("Der Tag vor der Grenze liegt außerhalb")
    func tagVorDerGrenzeIstDraussen() {
        let fenster = DataWindow(start: date("2026-07-03T08:00:00+02:00"))
        #expect(fenster.contains(date("2026-07-02T23:59:59+02:00")) == false)
        #expect(fenster.contains(date("2026-07-03T00:00:00+02:00")))
    }

    // MARK: - Zeitumstellung

    @Test("Der Grenztag der Vorstellung bleibt der 29.03.2026")
    func grenztagUeberlebtDieVorstellung() {
        // 29.03.2026: 02:00 (+01:00) springt auf 03:00 (+02:00).
        let fenster = DataWindow(start: date("2026-03-29T23:30:00+02:00"))
        #expect(fenster.start == date("2026-03-29T00:00:00+01:00"))
        #expect(fenster.contains(date("2026-03-29T00:30:00+01:00")))
        #expect(fenster.contains(date("2026-03-28T23:30:00+01:00")) == false)
        #expect(fenster.dayCount(through: date("2026-03-29T12:00:00+02:00")) == 1)

        let reihe = [
            Messpunkt(date: date("2026-03-28T06:40:00+01:00"), wert: 28),
            Messpunkt(date: date("2026-03-29T06:40:00+02:00"), wert: 29),
            Messpunkt(date: date("2026-03-30T06:40:00+02:00"), wert: 30)
        ]
        #expect(fenster.clip(reihe, by: \.date).map(\.wert) == [29, 30])
    }

    @Test("Der Grenztag der Rückstellung bleibt der 25.10.2026")
    func grenztagUeberlebtDieRueckstellung() {
        // 25.10.2026: 03:00 (+02:00) springt zurück auf 02:00 (+01:00).
        let fenster = DataWindow(start: date("2026-10-25T12:00:00+01:00"))
        #expect(fenster.start == date("2026-10-25T00:00:00+02:00"))
        #expect(fenster.contains(date("2026-10-25T00:30:00+02:00")))
        #expect(fenster.contains(date("2026-10-24T23:30:00+02:00")) == false)
        #expect(fenster.dayCount(through: date("2026-10-25T23:00:00+01:00")) == 1)

        let reihe = [
            Messpunkt(date: date("2026-10-24T06:40:00+02:00"), wert: 24),
            Messpunkt(date: date("2026-10-25T06:40:00+01:00"), wert: 25),
            Messpunkt(date: date("2026-10-26T06:40:00+01:00"), wert: 26)
        ]
        #expect(fenster.clip(reihe, by: \.date).map(\.wert) == [25, 26])
    }

    @Test("Über die Vorstellung hinweg wird kein Tag verschluckt")
    func dayCountUeberlebtDieZeitumstellung() {
        let fenster = DataWindow(start: date("2026-03-28T12:00:00+01:00"))
        #expect(fenster.dayCount(through: date("2026-03-30T12:00:00+02:00")) == 3)
    }

    // MARK: - queryStart

    @Test("Ohne Grenze wird ab dem übergebenen Boden gefragt")
    func queryStartOhneGrenze() {
        let boden = date("2014-01-01T00:00:00+01:00")
        #expect(DataWindow.unlimited.queryStart(floor: boden) == boden)
    }

    @Test("Mit Grenze wird ab deren Tagesbeginn gefragt")
    func queryStartMitGrenze() {
        let fenster = DataWindow(start: date("2026-07-03T23:30:00+02:00"))
        let boden = date("2014-01-01T00:00:00+01:00")
        #expect(fenster.queryStart(floor: boden) == date("2026-07-03T00:00:00+02:00"))
    }

    @Test("Der Boden wird nie unterschritten")
    func queryStartGehtNieVorDenBoden() {
        let fenster = DataWindow(start: date("2010-05-05T12:00:00+02:00"))
        let boden = date("2014-01-01T00:00:00+01:00")
        #expect(fenster.queryStart(floor: boden) == boden)
    }

    // MARK: - dayCount

    @Test("Ohne Grenze gibt es keine Tageszahl")
    func dayCountOhneGrenzeIstNil() {
        #expect(DataWindow.unlimited.dayCount(through: date("2026-07-05T12:00:00+02:00")) == nil)
    }

    @Test("Grenztag und Endtag zählen beide mit")
    func dayCountZaehltInklusiv() {
        let fenster = DataWindow(start: date("2026-07-01T23:30:00+02:00"))
        #expect(fenster.dayCount(through: date("2026-07-01T00:10:00+02:00")) == 1)
        #expect(fenster.dayCount(through: date("2026-07-05T12:00:00+02:00")) == 5)
        #expect(fenster.dayCount(through: date("2026-07-31T12:00:00+02:00")) == 31)
    }

    // MARK: - clip über beliebige KeyPaths

    @Test("`clip` läuft über ein anders benanntes Datumsfeld")
    func clipUeberAnderenKeyPath() {
        let abschnitte = [
            Abschnitt(start: date("2026-07-01T22:10:00+02:00")),
            Abschnitt(start: date("2026-07-03T22:10:00+02:00")),
            Abschnitt(start: date("2026-07-04T22:10:00+02:00"))
        ]
        let fenster = DataWindow(start: date("2026-07-03T08:00:00+02:00"))
        #expect(fenster.clip(abschnitte, by: \.start) == Array(abschnitte[1...]))
        #expect(DataWindow.unlimited.clip(abschnitte, by: \.start) == abschnitte)
    }
}
