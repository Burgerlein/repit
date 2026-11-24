import Foundation
import Testing

/// Belegt die Auflage aus der Prüfung von Task 7 (siehe task-12-brief.md,
/// Abschnitt „Was bereits steht"): Diese Prüfung testet gegen „**alle
/// sieben Methoden ersetzt**", nicht gegen „`dailyMetrics` danebengebaut".
///
/// Keiner der Verhaltens-Tests in dieser Testgruppe (oder in
/// `HealthChannelTests.swift`/`HealthChannelExtendedCodecTests.swift`) würde
/// bemerken, wenn der Platzhalter `NochNichtPortiert` aus Task 7 einfach
/// **neben** einem vollständig portierten Adapter liegen bliebe und
/// `HealthChannel.register(with:)` weiterhin ihn verdrahtete — die
/// Verhaltens-Tests rufen `HealthChannel.alsMap` direkt auf und bekommen nie
/// mit, welche `HealthReading`-Quelle der Kanal tatsächlich benutzt.
///
/// Deshalb hier eine **textuelle** Prüfung des Quelltexts von
/// `HealthChannel.swift` selbst, nicht seines Verhaltens — ungewöhnlich für
/// dieses Projekt, aber genau das, was die Auflage verlangt: dass der
/// Platzhalter **verschwindet**, statt danebenzuliegen. Eine Verhaltensprüfung
/// über einen echten `HKHealthStore`-Aufruf wäre hier kein Ersatz: Der
/// Simulator-Store ist dauerhaft leer (CLAUDE.md, „Prüfen im Simulator"), ein
/// leeres Ergebnis sieht von `NochNichtPortiert` (das wirft) zwar
/// unterscheidbar aus, aber ein `catch`, der den Fehler stillschweigend zu
/// `[]` macht, würde diese Prüfung umgehen, ohne dass hier etwas auffiele.
///
/// `#filePath` zeigt zur Kompilierzeit auf diese Testdatei
/// (`app/ios/RunnerTests/HealthChannelPortedTests.swift`); von dort aus liegt
/// `HealthChannel.swift` zwei Verzeichnisebenen höher in `Runner/`. Das
/// funktioniert, weil `xcodebuild test` auf demselben Rechner kompiliert und
/// ausführt, auf dem der Quelltext liegt (CLAUDE.md: „Erst im Simulator
/// prüfen, dann auf dem Gerät" — kein entfernter Build-Server).
@Suite("Der Adapter ist vollstaendig portiert, nicht nur dailyMetrics danebengebaut")
struct HealthChannelPortedTests {

    private var healthChannelSource: String {
        let thisFile = URL(fileURLWithPath: #filePath)
        let healthChannelSwift = thisFile
            .deletingLastPathComponent()   // entfernt den Dateinamen -> .../ios/RunnerTests/
            .deletingLastPathComponent()   // entfernt RunnerTests/     -> .../ios/
            .appendingPathComponent("Runner")
            .appendingPathComponent("HealthChannel.swift")
        return (try? String(contentsOf: healthChannelSwift, encoding: .utf8)) ?? ""
    }

    @Test("HealthChannel.swift konnte zum Pruefen gelesen werden")
    func quelltextIstLesbar() {
        // Scheitert dieser Test, sind alle übrigen Tests dieser Gruppe
        // bedeutungslos — eine leere Zeichenkette enthält trivialerweise
        // weder "NochNichtPortiert" noch irgendeinen Methodennamen.
        #expect(!healthChannelSource.isEmpty, "HealthChannel.swift konnte nicht gelesen werden")
    }

    @Test("Der Platzhalter NochNichtPortiert ist aus HealthChannel.swift verschwunden")
    func platzhalterIstWeg() {
        #expect(!healthChannelSource.contains("NochNichtPortiert"))
    }

    @Test("Alle sieben Methodennamen des Protokolls sind im Kanal als Fallunterscheidung verdrahtet")
    func alleSiebenMethodenVerdrahtet() {
        let methoden = [
            "requestAuthorization", "dailyMetrics", "sleepSessions", "workouts",
            "quantitySamples", "hourlySteps", "nutritionEntries"
        ]
        for methode in methoden {
            #expect(
                healthChannelSource.contains("\"\(methode)\""),
                "\(methode) fehlt als Fallunterscheidung im Kanal — wäre es nicht verdrahtet, liefe der Aufruf ins FlutterMethodNotImplemented statt zum echten Adapter"
            )
        }
    }
}
