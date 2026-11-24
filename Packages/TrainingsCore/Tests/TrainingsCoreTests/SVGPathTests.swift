import Foundation
import Testing
@testable import TrainingsCore

@Suite("SVG-Pfade")
struct SVGPathTests {

    @Test("Ein einfacher Streckenzug wird gelesen")
    func moveAndLine() throws {
        let c = try SVGPath.commands("M10,20 L30,40 Z")
        #expect(c == [.move(x: 10, y: 20), .line(x: 30, y: 40), .close])
    }

    @Test("Eine kubische Kurve trägt alle sechs Zahlen")
    func curveKeepsAllSixNumbers() throws {
        let c = try SVGPath.commands("M0,0 C1,2 3,4 5,6")
        #expect(c == [.move(x: 0, y: 0),
                      .curve(c1x: 1, c1y: 2, c2x: 3, c2y: 4, x: 5, y: 6)])
    }

    // Review Focus 5
    // Genau diese Zeichenkette steht im Dashboard: Komma als Trenner, und ein
    // Minus beginnt eine neue Zahl auch ohne Trennzeichen davor.
    @Test("Komma, Leerzeichen und angehängte Minuszeichen trennen gleichermaßen")
    func separatorsAreInterchangeable() throws {
        let c = try SVGPath.commands("M66,200C59,222-5-3 63,274")
        #expect(c == [.move(x: 66, y: 200),
                      .curve(c1x: 59, c1y: 222, c2x: -5, c2y: -3, x: 63, y: 274)])
    }

    @Test("Dezimalzahlen und führende Punkte werden gelesen")
    func decimalsAreRead() throws {
        let c = try SVGPath.commands("M1.5,-2.25 L.5,3")
        #expect(c == [.move(x: 1.5, y: -2.25), .line(x: 0.5, y: 3)])
    }

    @Test("Wiederholte Zahlenpaare setzen den letzten Befehl fort")
    func repeatedNumbersRepeatTheCommand() throws {
        let c = try SVGPath.commands("M0,0 L1,1 2,2 3,3")
        #expect(c == [.move(x: 0, y: 0), .line(x: 1, y: 1),
                      .line(x: 2, y: 2), .line(x: 3, y: 3)])
    }

    // Der Parser kann mit Absicht nur, was die Daten brauchen. Ein relativer
    // Befehl wäre stillschweigend falsch gezeichnet — also lieber ein Fehler.
    @Test("Kleingeschriebene, also relative Befehle werden abgelehnt")
    func relativeCommandsAreRejected() {
        #expect(throws: SVGPathError.unsupportedCommand("c")) {
            try SVGPath.commands("M0,0 c1,2 3,4 5,6")
        }
    }

    @Test("Ein Befehl ohne genug Zahlen wird gemeldet")
    func truncatedCommandIsReported() {
        #expect(throws: SVGPathError.missingNumbers("C")) {
            try SVGPath.commands("M0,0 C1,2 3,4")
        }
        #expect(throws: SVGPathError.missingNumbers("L")) {
            try SVGPath.commands("M0,0 L5")
        }
    }

    @Test("Eine leere Zeichenkette ergibt keine Befehle")
    func emptyStringYieldsNothing() throws {
        #expect(try SVGPath.commands("") == [])
        #expect(try SVGPath.commands("   ") == [])
    }

    @Test("Die echten Pfade der Figur lassen sich lesen")
    func theRealFigurePathsParse() throws {
        // Erster Pfad aus BODY.LEG, docs/prototype/index.html Zeile 1580.
        let leg = "M66,200 C59,222 59,250 63,274 C65,288 69,298 73,306 "
                + "L95,306 C97,284 99,256 99,230 L99,214 Z"
        let c = try SVGPath.commands(leg)
        #expect(c.first == .move(x: 66, y: 200))
        #expect(c.last == .close)
        #expect(c.count == 7)
    }
}
