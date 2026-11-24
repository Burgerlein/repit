import Foundation

/// Ein Zeichenbefehl ohne Bezug zu einem Zeichensystem. SwiftUI kennt `Path`,
/// aber `TrainingsCore` darf SwiftUI nicht sehen — die Ansicht übersetzt diese
/// Befehle in drei Zeilen.
public enum PathCommand: Equatable, Sendable {
    case move(x: Double, y: Double)
    case line(x: Double, y: Double)
    case curve(c1x: Double, c1y: Double, c2x: Double, c2y: Double,
               x: Double, y: Double)
    case close
}

public enum SVGPathError: Error, Equatable {
    case unsupportedCommand(Character)
    case missingNumbers(Character)
}

/// Liest die Teilmenge von SVG, die die Muskelfigur des Dashboards benutzt:
/// `M`, `L`, `C`, `Z`, absolut. Mehr zu können hieße, Code ohne Test zu haben.
///
/// SVG trennt Zahlen durch Leerzeichen **oder** Komma, und ein Minuszeichen
/// beginnt eine neue Zahl auch ohne Trennzeichen — `C59,222-5-3 63,274` sind
/// sechs Zahlen. Genau so steht es in den Pfaddaten.
public enum SVGPath {

    public static func commands(_ d: String) throws -> [PathCommand] {
        var out: [PathCommand] = []
        var numbers: [Double] = []
        var current: Character?
        var token = ""

        func takeNumber() {
            if !token.isEmpty, let value = Double(token) { numbers.append(value) }
            token = ""
        }

        func flush() throws {
            guard let command = current else {
                numbers.removeAll()
                return
            }
            let needed: Int
            switch command {
            case "M", "L": needed = 2
            case "C": needed = 6
            case "Z": needed = 0
            default: throw SVGPathError.unsupportedCommand(command)
            }

            if needed == 0 {
                out.append(.close)
                numbers.removeAll()
                return
            }
            guard !numbers.isEmpty, numbers.count % needed == 0 else {
                throw SVGPathError.missingNumbers(command)
            }

            var index = 0
            var kind = command
            while index < numbers.count {
                let n = Array(numbers[index ..< index + needed])
                switch kind {
                case "M": out.append(.move(x: n[0], y: n[1]))
                case "L": out.append(.line(x: n[0], y: n[1]))
                default: out.append(.curve(c1x: n[0], c1y: n[1], c2x: n[2],
                                           c2y: n[3], x: n[4], y: n[5]))
                }
                // Ein wiederholtes Zahlenpaar nach M bedeutet in SVG eine
                // Linie, keinen zweiten Sprung.
                if kind == "M" { kind = "L" }
                index += needed
            }
            numbers.removeAll()
        }

        for character in d {
            if character.isLetter {
                takeNumber()
                try flush()
                current = character
            } else if character == "," || character.isWhitespace {
                takeNumber()
            } else if character == "-" && !token.isEmpty
                        && token.last != "e" && token.last != "E" {
                takeNumber()
                token = "-"
            } else {
                token.append(character)
            }
        }
        takeNumber()
        try flush()
        return out
    }
}
