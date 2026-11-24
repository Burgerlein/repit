import Foundation
import Testing

/// Löst die Behauptung der Architektur ein: TrainingsCore importiert
/// ausschließlich Foundation. Ein Paket allein erzwingt das nicht — SwiftUI
/// und HealthKit liegen im SDK und wären ohne Deklaration importierbar.
@Suite("Paketgrenze")
struct ImportBoundaryTests {

    @Test("Keine Quelldatei importiert etwas anderes als Foundation")
    func onlyFoundation() throws {
        let sources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // TrainingsCoreTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // TrainingsCore
            .appending(path: "Sources/TrainingsCore")

        let files = FileManager.default
            .enumerator(at: sources, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" } ?? []

        #expect(!files.isEmpty, "Keine Quelldateien gefunden unter \(sources.path)")

        for file in files {
            let imports = try String(contentsOf: file, encoding: .utf8)
                .split(separator: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.hasPrefix("import ") }
            for line in imports {
                #expect(line == "import Foundation",
                        "\(file.lastPathComponent): \(line) — TrainingsCore darf nur Foundation importieren")
            }
        }
    }
}
