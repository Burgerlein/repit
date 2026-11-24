import Foundation
import Testing
@testable import TrainingsCore

/// Richtung, Verlauf und Kennzahlen je Maß — der rechnende Teil des
/// Umfänge-Schirms aus
/// `docs/superpowers/specs/2026-10-13-umfaenge-fortschritt-design.md`.
/// Alle Zahlen hier sind erfunden.
///
/// Zwei Festlegungen, die die Signatur offen lässt:
///
/// 1. `delta` ist **vorzeichenbehaftet**, genau wie `sinceStart` und
///    `perMonth`. Die Richtung steht zusätzlich als `direction` daneben,
///    damit die Ansicht den Pfeil nicht aus dem Vorzeichen ableiten muss.
///    Für die Beschriftung „↑ 0,4" nimmt die Ansicht den Betrag.
/// 2. Die Einträge kommen so, wie `CircumferenceMerge.entries` sie liefert:
///    je Tag einer, aufsteigend nach Datum.
@Suite("Fortschritt der Umfänge")
struct CircumferenceProgressTests {

    private func date(_ year: Int, _ month: Int, _ day: Int,
                      hour: Int = 0, minute: Int = 0) -> Date {
        let components = DateComponents(year: year, month: month, day: day,
                                        hour: hour, minute: minute)
        return BerlinCalendar.calendar.date(from: components) ?? .distantPast
    }

    private func entry(_ year: Int, _ month: Int, _ day: Int,
                       _ values: [Circumference: Double]) -> CircumferenceEntry {
        CircumferenceEntry(date: date(year, month, day), values: values)
    }

    // MARK: - change

    @Test("Ohne Messung gibt es keine Richtung")
    func changeWithoutEntriesIsNil() {
        #expect(CircumferenceProgress.change(.upperArmRightFlexed, in: []) == nil)
    }

    @Test("Eine einzelne Messung hat nichts zum Vergleichen")
    func changeWithOneEntryIsNil() {
        // Der Zustand, der diesen Entwurf ausgelöst hat: Die Veränderung
        // gibt es, ihr fehlt nur der zweite Punkt.
        let entries = [entry(2026, 10, 13, [.upperArmRightFlexed: 29.3,
                                            .waist: 82.5])]
        #expect(CircumferenceProgress.change(.upperArmRightFlexed, in: entries) == nil)
        #expect(CircumferenceProgress.change(.waist, in: entries) == nil)
    }

    @Test("Ein Maß, das nur in einer Messung steht, hat keine Richtung")
    func changeNeedsTwoValuesOfTheMeasure() {
        // Drei Messtage, die Wade aber nur an einem: Der Pfeil in ihrer Zeile
        // bleibt ein Strich, obwohl es drei Messungen gibt.
        let entries = [entry(2026, 9, 6, [.waist: 83.0]),
                       entry(2026, 9, 20, [.waist: 82.7]),
                       entry(2026, 10, 4, [.waist: 82.5, .calfLeft: 38.0])]
        #expect(CircumferenceProgress.change(.calfLeft, in: entries) == nil)
    }

    @Test("Zwei Messungen ergeben Betrag und Richtung")
    func changeBetweenTwoEntries() throws {
        let entries = [entry(2026, 9, 29, [.upperArmRightFlexed: 28.9]),
                       entry(2026, 10, 13, [.upperArmRightFlexed: 29.3])]
        let change = try #require(
            CircumferenceProgress.change(.upperArmRightFlexed, in: entries))
        // Nicht auf Gleichheit prüfen: 29,3 − 28,9 ist in Double nicht
        // exakt 0,4.
        #expect(abs(change.delta - 0.4) < 0.0001)
        #expect(change.direction == .up)
    }

    @Test("Ein kleinerer Wert zeigt abwärts")
    func changeDownwards() throws {
        let entries = [entry(2026, 9, 29, [.waist: 83.2]),
                       entry(2026, 10, 13, [.waist: 82.5])]
        let change = try #require(CircumferenceProgress.change(.waist, in: entries))
        #expect(abs(change.delta + 0.7) < 0.0001)
        #expect(change.direction == .down)
    }

    @Test("Verglichen wird mit der letzten Messung, die das Maß hat")
    func changeSkipsEntriesWithoutTheMeasure() throws {
        // Am 20.09. wurde nur die Taille nachgemessen. Der Oberarm vergleicht
        // deshalb den 04.10. mit dem 06.09. — nicht mit nichts und schon gar
        // nicht mit null.
        let entries = [entry(2026, 9, 6, [.upperArmRightFlexed: 29.0, .waist: 83.0]),
                       entry(2026, 9, 20, [.waist: 82.7]),
                       entry(2026, 10, 4, [.upperArmRightFlexed: 29.6, .waist: 82.5])]
        let change = try #require(
            CircumferenceProgress.change(.upperArmRightFlexed, in: entries))
        #expect(abs(change.delta - 0.6) < 0.0001)
        #expect(change.direction == .up)
        // Die Taille kennt die Lücke nicht und vergleicht wie gewohnt.
        let waist = try #require(CircumferenceProgress.change(.waist, in: entries))
        #expect(abs(waist.delta + 0.2) < 0.0001)
    }

    @Test("Die Totzone liegt bei 0,2 cm")
    func deadbandIsTwoTenths() {
        #expect(CircumferenceProgress.deadband == 0.2)
    }

    @Test("Unterschied 0,19 ist noch Totzone")
    func justUnderTheDeadbandIsFlat() {
        // Maßband, Zugspannung und Messstelle streuen zu stark, als dass
        // 0,19 cm eine Aussage wären. Wer vorher auf eine Nachkommastelle
        // rundet, macht daraus 0,2 und zeigt einen Pfeil — deshalb steht
        // hier genau diese Zahl.
        let entries = [entry(2026, 9, 29, [.upperArmRightFlexed: 29.3]),
                       entry(2026, 10, 13, [.upperArmRightFlexed: 29.49])]
        let change = CircumferenceProgress.change(.upperArmRightFlexed, in: entries)
        #expect(change?.direction == .flat)
    }

    @Test("Unterschied 0,2 ist keine Totzone mehr")
    func theDeadbandBoundaryBelongsToMovement() {
        // Die Grenze gehört zur Bewegung: unter 0,2 ein Strich, ab 0,2 ein
        // Pfeil.
        let entries = [entry(2026, 9, 29, [.neck: 40.0]),
                       entry(2026, 10, 13, [.neck: 40.2])]
        let change = CircumferenceProgress.change(.neck, in: entries)
        #expect(change?.direction == .up)
        #expect(change?.direction != .flat)
    }

    @Test("Zwei gleiche Werte stehen still")
    func noDifferenceIsFlat() {
        let entries = [entry(2026, 9, 29, [.hips: 95.0]),
                       entry(2026, 10, 13, [.hips: 95.0])]
        let change = CircumferenceProgress.change(.hips, in: entries)
        #expect(change?.direction == .flat)
        #expect(change?.delta == 0.0)
    }

    // MARK: - isProgress

    @Test("Beim Oberarm ist aufwärts Fortschritt")
    func growingArmIsProgress() throws {
        let entries = [entry(2026, 9, 29, [.upperArmRightFlexed: 28.9]),
                       entry(2026, 10, 13, [.upperArmRightFlexed: 29.3])]
        let change = try #require(
            CircumferenceProgress.change(.upperArmRightFlexed, in: entries))
        #expect(change.isProgress)
    }

    @Test("Beim Oberarm ist abwärts kein Fortschritt")
    func shrinkingArmIsNotProgress() throws {
        let entries = [entry(2026, 9, 29, [.upperArmRightFlexed: 29.3]),
                       entry(2026, 10, 13, [.upperArmRightFlexed: 28.9])]
        let change = try #require(
            CircumferenceProgress.change(.upperArmRightFlexed, in: entries))
        #expect(change.direction == .down)
        #expect(change.isProgress == false)
    }

    @Test("Bei der Taille ist abwärts Fortschritt")
    func shrinkingWaistIsProgress() throws {
        // Die Regel steckt als `lessIsBetter` im Maß und nicht in der Farbe
        // der Ansicht.
        let entries = [entry(2026, 9, 29, [.waist: 83.2]),
                       entry(2026, 10, 13, [.waist: 82.5])]
        let change = try #require(CircumferenceProgress.change(.waist, in: entries))
        #expect(change.direction == .down)
        #expect(change.isProgress)
    }

    @Test("Bei der Taille ist aufwärts kein Fortschritt")
    func growingWaistIsNotProgress() throws {
        let entries = [entry(2026, 9, 29, [.waist: 82.5]),
                       entry(2026, 10, 13, [.waist: 83.2])]
        let change = try #require(CircumferenceProgress.change(.waist, in: entries))
        #expect(change.direction == .up)
        #expect(change.isProgress == false)
    }

    @Test("In der Totzone ist nichts Fortschritt")
    func flatIsNeverProgress() throws {
        // Grau, nicht grün: Eine Zahl, die im Rauschen liegt, ist kein
        // Erfolg — auch nicht bei der Taille.
        let armEntries = [entry(2026, 9, 29, [.upperArmRightFlexed: 29.3]),
                          entry(2026, 10, 13, [.upperArmRightFlexed: 29.3])]
        let waistEntries = [entry(2026, 9, 29, [.waist: 82.5]),
                            entry(2026, 10, 13, [.waist: 82.5])]
        let arm = try #require(
            CircumferenceProgress.change(.upperArmRightFlexed, in: armEntries))
        let waist = try #require(CircumferenceProgress.change(.waist, in: waistEntries))
        #expect(arm.direction == .flat)
        #expect(arm.isProgress == false)
        #expect(waist.direction == .flat)
        #expect(waist.isProgress == false)
    }

    // MARK: - sinceStart

    @Test("Ohne Messung gibt es kein „seit Start“")
    func sinceStartWithoutEntriesIsNil() {
        #expect(CircumferenceProgress.sinceStart(.waist, in: []) == nil)
    }

    @Test("Solange die erste Messung die aktuelle ist, fällt „seit Start“ weg")
    func sinceStartNeedsASecondEntry() {
        let entries = [entry(2026, 10, 13, [.upperArmRightFlexed: 29.3])]
        #expect(CircumferenceProgress.sinceStart(.upperArmRightFlexed, in: entries) == nil)
    }

    @Test("„seit Start“ rechnet über alle Messungen hinweg")
    func sinceStartSpansEverything() throws {
        let entries = [entry(2026, 8, 2, [.upperArmRightFlexed: 27.9, .waist: 83.5]),
                       entry(2026, 9, 6, [.upperArmRightFlexed: 28.6, .waist: 83.0]),
                       entry(2026, 10, 13, [.upperArmRightFlexed: 29.3, .waist: 82.5])]
        let arm = try #require(
            CircumferenceProgress.sinceStart(.upperArmRightFlexed, in: entries))
        #expect(abs(arm - 1.4) < 0.0001)
        let waist = try #require(CircumferenceProgress.sinceStart(.waist, in: entries))
        #expect(abs(waist + 1.0) < 0.0001)
    }

    @Test("„seit Start“ nimmt die erste Messung, die das Maß hat")
    func sinceStartSkipsEntriesWithoutTheMeasure() throws {
        let entries = [entry(2026, 8, 2, [.waist: 83.5]),
                       entry(2026, 9, 6, [.upperArmRightFlexed: 28.6]),
                       entry(2026, 10, 13, [.upperArmRightFlexed: 29.3])]
        let arm = try #require(
            CircumferenceProgress.sinceStart(.upperArmRightFlexed, in: entries))
        #expect(abs(arm - 0.7) < 0.0001)
        // Die Taille steht nur einmal da und bleibt ohne Wert.
        #expect(CircumferenceProgress.sinceStart(.waist, in: entries) == nil)
    }

    @Test("„seit Start“ kennt keine Totzone")
    func sinceStartHasNoDeadband() throws {
        // Im Entwurf steht „Hals – seit Start +0,3": Der Strich gilt dem
        // Pfeil, nicht der Spalte daneben.
        let entries = [entry(2026, 8, 2, [.neck: 39.7]),
                       entry(2026, 10, 13, [.neck: 39.8])]
        let neck = try #require(CircumferenceProgress.sinceStart(.neck, in: entries))
        #expect(abs(neck - 0.1) < 0.0001)
    }

    // MARK: - perMonth

    @Test("Ohne zwei Messungen gibt es keine Rate")
    func perMonthNeedsTwoEntries() {
        #expect(CircumferenceProgress.perMonth(.upperArmRightFlexed, in: []) == nil)
        let one = [entry(2026, 10, 13, [.upperArmRightFlexed: 29.3])]
        #expect(CircumferenceProgress.perMonth(.upperArmRightFlexed, in: one) == nil)
    }

    @Test("0,5 cm in 14 Tagen sind rund 1,07 cm im Monat")
    func perMonthOverFourteenDays() throws {
        // 0,5 / 14 · 30,44 = 1,087. Nicht auf Gleichheit prüfen: Ob der Kern
        // mit 30,44 oder 30,4375 Tagen rechnet, ist für die Anzeige egal.
        let entries = [entry(2026, 9, 29, [.upperArmRightFlexed: 29.0]),
                       entry(2026, 10, 13, [.upperArmRightFlexed: 29.5])]
        let rate = try #require(
            CircumferenceProgress.perMonth(.upperArmRightFlexed, in: entries))
        #expect(abs(rate - 1.087) < 0.05)
    }

    @Test("Eine schrumpfende Taille ergibt eine negative Rate")
    func perMonthCanBeNegative() throws {
        let entries = [entry(2026, 9, 29, [.waist: 83.0]),
                       entry(2026, 10, 13, [.waist: 82.5])]
        let rate = try #require(CircumferenceProgress.perMonth(.waist, in: entries))
        #expect(abs(rate + 1.087) < 0.05)
    }

    @Test("Zwei Messungen am selben Tag ergeben keine Rate")
    func perMonthWithoutTimeIsNil() {
        // Sonst wäre es eine Division durch null, und auf dem Schirm stünde
        // „inf cm pro Monat".
        let day = date(2026, 10, 13)
        let entries = [CircumferenceEntry(date: day, values: [.upperArmRightFlexed: 29.0]),
                       CircumferenceEntry(date: day, values: [.upperArmRightFlexed: 29.5])]
        #expect(CircumferenceProgress.perMonth(.upperArmRightFlexed, in: entries) == nil)
    }

    // MARK: - span

    @Test("Ohne Messung gibt es keine Spanne")
    func spanWithoutEntriesIsNil() {
        #expect(CircumferenceProgress.span(.upperArmRightFlexed, in: []) == nil)
        let others = [entry(2026, 10, 13, [.waist: 82.5])]
        #expect(CircumferenceProgress.span(.upperArmRightFlexed, in: others) == nil)
    }

    @Test("Eine Messung ist ihr eigener kleinster und größter Wert")
    func spanOfASingleValue() throws {
        let entries = [entry(2026, 10, 13, [.upperArmRightFlexed: 29.3])]
        let span = try #require(
            CircumferenceProgress.span(.upperArmRightFlexed, in: entries))
        #expect(span.lowest == 29.3)
        #expect(span.highest == 29.3)
    }

    @Test("Die Spanne findet den größten Wert auch in der Mitte")
    func spanFindsTheHighestAnywhere() throws {
        // Der größte Wert ist der vom 06.09. und nicht der letzte — wer nur
        // Anfang und Ende vergleicht, verfehlt ihn.
        let entries = [entry(2026, 8, 2, [.upperArmRightFlexed: 29.0]),
                       entry(2026, 9, 6, [.upperArmRightFlexed: 30.1]),
                       entry(2026, 10, 13, [.upperArmRightFlexed: 29.6])]
        let span = try #require(
            CircumferenceProgress.span(.upperArmRightFlexed, in: entries))
        #expect(span.lowest == 29.0)
        #expect(span.highest == 30.1)
    }

    @Test("Die Spanne überspringt Tage ohne dieses Maß")
    func spanIgnoresOtherMeasures() throws {
        let entries = [entry(2026, 8, 2, [.waist: 83.5]),
                       entry(2026, 9, 6, [.upperArmRightFlexed: 28.6]),
                       entry(2026, 10, 13, [.upperArmRightFlexed: 29.3])]
        let span = try #require(
            CircumferenceProgress.span(.upperArmRightFlexed, in: entries))
        #expect(span.lowest == 28.6)
        #expect(span.highest == 29.3)
    }

    // MARK: - nextDue

    @Test("Ohne Messung steht kein nächster Termin an")
    func nextDueWithoutEntriesIsNil() {
        #expect(CircumferenceProgress.nextDue(after: []) == nil)
    }

    @Test("Zwei Wochen nach der letzten Messung, auf Tagesbeginn")
    func nextDueIsFourteenDaysLater() throws {
        // Der Satz „sinnvoll ist das etwa ab dem 27.10." wird gerechnet und
        // nicht eingetippt. Die Uhrzeit des Eintragens spielt keine Rolle.
        let entries = [entry(2026, 9, 29, [.waist: 83.0]),
                       CircumferenceEntry(date: date(2026, 10, 13, hour: 21, minute: 40),
                                          values: [.waist: 82.5])]
        let due = try #require(CircumferenceProgress.nextDue(after: entries))
        #expect(due == BerlinCalendar.startOfDay(date(2026, 10, 27)))
    }

    @Test("Die zwei Wochen zählen Tage, keine 86400 Sekunden")
    func nextDueCountsDaysAcrossTheClockChange() throws {
        // In der Nacht zum 25.10.2026 endet die Sommerzeit. Vierzehnmal
        // 86400 Sekunden landen deshalb am 26.10. um 23 Uhr statt am 27.10.
        let entries = [entry(2026, 10, 13, [.waist: 82.5])]
        let due = try #require(CircumferenceProgress.nextDue(after: entries))
        #expect(due == date(2026, 10, 27))
        #expect(due != date(2026, 10, 13).addingTimeInterval(14 * 86_400))
    }

    @Test("Maßgeblich ist die jüngste Messung")
    func nextDueUsesTheLatestEntry() throws {
        let entries = [entry(2026, 8, 2, [.waist: 83.5]),
                       entry(2026, 9, 6, [.waist: 83.0]),
                       entry(2026, 10, 13, [.waist: 82.5])]
        let due = try #require(CircumferenceProgress.nextDue(after: entries))
        #expect(due == BerlinCalendar.startOfDay(date(2026, 10, 27)))
    }
}
