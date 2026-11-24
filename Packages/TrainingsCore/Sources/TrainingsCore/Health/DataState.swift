import Foundation

/// HealthKit verrät aus Datenschutzgründen nicht, ob Lesezugriff erteilt wurde.
/// Eine leere Antwort heißt deshalb entweder „nichts getrackt“ oder „nicht
/// erlaubt“ — die Oberfläche muss beides nennen.
public enum DataState<Value: Equatable & Sendable>: Equatable, Sendable {
    case data(Value)
    case emptyOrUnauthorized
}

public extension Collection where Element: Equatable & Sendable {
    var dataState: DataState<[Element]> {
        isEmpty ? .emptyOrUnauthorized : .data(Array(self))
    }
}
