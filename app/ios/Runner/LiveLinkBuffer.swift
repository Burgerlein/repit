import Foundation

/// Hält den zuletzt angekommenen Link der Live-Aktivität, bis Dart ihn mit
/// `nimmLink` abholt (#366, Spec „Der Link").
///
/// Der Link kann vor der Engine da sein (Kaltstart über die Karte), deshalb
/// wird er gemerkt statt sofort geschickt. `nimm()` leert den Puffer: Ein
/// Link wird genau einmal abgeholt, egal wie oft Dart fragt.
@MainActor
final class LiveLinkBuffer {

    static let shared = LiveLinkBuffer()

    /// Das URL-Schema aus `CFBundleURLTypes` in `Info.plist`.
    static let schema = "repit"

    /// Wird je angenommenem Link einmal gerufen. `LiveChannel` schickt
    /// darauf `linkDa` an Dart.
    var beiAnkunft: (() -> Void)?

    private var wartend: String?

    init() {}

    /// Nimmt nur das eigene Schema an und merkt sich den Host
    /// (`repit://mahlzeit-eintragen` → `"mahlzeit-eintragen"`).
    /// Ein späterer Link überschreibt einen noch nicht abgeholten; ein
    /// fremder lässt ihn stehen.
    func nimmAn(_ url: URL) {
        guard url.scheme?.lowercased() == Self.schema,
              let host = url.host(percentEncoded: false),
              !host.isEmpty
        else { return }
        wartend = host
        beiAnkunft?()
    }

    /// Gibt den wartenden Host ab und leert den Puffer.
    func nimm() -> String? {
        defer { wartend = nil }
        return wartend
    }
}
