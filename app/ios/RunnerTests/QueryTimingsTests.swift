import Foundation
import Testing
@testable import Runner

/// Tests für `QueryTiming`/`QueryTimings` (Task 12) — die Messstelle für den
/// HealthKit-Testschirm. Portiert aus `Sources/Health/QueryTimings.swift`,
/// unverändert bis auf den Ort (Spec 8.3: „wandert mit — und zwar in den
/// Swift-Kanal, nicht auf die Dart-Seite").
///
/// Jeder Test baut eine **eigene** `QueryTimings()`-Instanz statt
/// `QueryTimings.shared` zu benutzen: Der Singleton wird im Betrieb vom
/// echten Kanal befüllt (`HealthChannel` ruft `QueryTimings.shared.record`
/// bei jeder der vier gemessenen Abfragen auf), geteilter Zustand zwischen
/// Tests wäre hier nur eine Fehlerquelle ohne Nutzen. Das setzt voraus, dass
/// `QueryTimings` einen von außen erreichbaren Initialisierer hat — in der
/// Swift-Vorlage ist die Klasse `internal`, nicht `private`, der
/// Memberwise-Init bleibt also nutzbar.
@Suite("QueryTimings misst Dauer und Trefferzahl, nie den Messwert selbst")
struct QueryTimingsTests {

    @Test("Timings speichern keine Messwerte")
    func timingsOhneMesswerte() {
        // Pflichtfall aus task-12-brief.md: QueryTiming trägt Name, Dauer,
        // Trefferzahl, Zeitspanne und Zeitpunkt — und sonst nichts. Der
        // Debug-Schirm ist kein Ort für Gesundheitsdaten (Spec 8.3).
        let timing = QueryTiming(name: "Tageswerte", seconds: 1.2, count: 30, days: 31, at: Date())
        let felder = Set(Mirror(reflecting: timing).children.compactMap(\.label))
        #expect(
            felder == ["id", "name", "seconds", "count", "days", "at"],
            "QueryTiming darf kein weiteres Feld tragen, insbesondere keinen Gesundheitswert"
        )
    }

    @Test("Longest ist das Maximum, nicht die Summe")
    @MainActor
    func longestIstDasMaximum() {
        // Pflichtfall aus task-12-brief.md. Die Begründung steht in der
        // Vorlage (QueryTimings.swift): `RecoveryStore` startet Tageswerte
        // und Schlaf gleichzeitig per `async let` — erlebt wird das Maximum
        // der beiden, nicht ihre Summe. Und die Liste sammelt bis zu 40
        // Einträge aus mehreren Ladeläufen; eine Summe über mehrere Durchläufe
        // würde die Wartezeit vervielfachen, statt sie zu zeigen.
        let timings = QueryTimings()
        timings.record("Tageswerte", seconds: 0.8, count: 31, days: 31)
        timings.record("Schlaf", seconds: 2.4, count: 7, days: 31)
        timings.record("Stundenschritte", seconds: 0.3, count: 744, days: 31)

        #expect(
            timings.longestSeconds == 2.4,
            "0.8 + 2.4 + 0.3 wäre 3.5 — longestSeconds muss aber das Maximum sein, 2.4"
        )
    }

    @Test("Hoechstens 40 Eintraege, neueste zuerst")
    @MainActor
    func hoechstens40EintraegeNeuesteZuerst() {
        // „bis zu 40 Einträge" steht wörtlich in den Interfaces von
        // task-12-brief.md. Mehr hilft beim Suchen nicht und lässt den
        // Debug-Schirm nur wachsen (Begründung in der Vorlage).
        let timings = QueryTimings()
        for i in 0..<45 {
            timings.record("Abfrage \(i)", seconds: Double(i), count: i, days: 1)
        }
        #expect(timings.entries.count == 40)
        #expect(timings.entries.first?.name == "Abfrage 44", "neueste zuerst")
        #expect(timings.entries.last?.name == "Abfrage 5", "die ältesten 5 sind herausgefallen")
    }

    @Test("clear() leert die Liste")
    @MainActor
    func clearLeertDieListe() {
        let timings = QueryTimings()
        timings.record("Tageswerte", seconds: 1, count: 1, days: 1)
        #expect(!timings.entries.isEmpty)
        timings.clear()
        #expect(timings.entries.isEmpty)
        #expect(timings.longestSeconds == 0)
    }
}
