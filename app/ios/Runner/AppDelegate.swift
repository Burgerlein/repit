import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// Hält den Kanal am Leben — `FlutterMethodChannel` hält seinen Handler
  /// nur, solange etwas auf `healthChannel` zeigt.
  private var healthChannel: HealthChannel?

  /// Öffnet die Einstellungen dieser App — der Weg zur Kamerafreigabe,
  /// wenn sie verweigert ist (#324, `KameraLeser.oeffneEinstellungen`).
  /// Hält den Kanal aus demselben Grund wie [healthChannel].
  private var einstellungenChannel: FlutterMethodChannel?

  /// Der Speicher für den Gemini-Schlüssel (#336). Hält den Kanal aus
  /// demselben Grund wie [healthChannel].
  private var keychainChannel: KeychainChannel?

  /// Die Live-Aktivität (#366): `zeige`, `beendeAlle`, `nimmLink`, und
  /// `linkDa` zurück. Hält den Kanal aus demselben Grund wie
  /// [healthChannel].
  private var liveChannel: LiveChannel?

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "HealthChannel")
    if let messenger = registrar?.messenger() {
      healthChannel = HealthChannel.register(with: messenger)
    }

    let einstellungen = engineBridge.pluginRegistry.registrar(forPlugin: "EinstellungenChannel")
    if let messenger = einstellungen?.messenger() {
      let channel = FlutterMethodChannel(
        name: "de.rosenbach.repit/einstellungen",
        binaryMessenger: messenger
      )
      channel.setMethodCallHandler { call, result in
        guard call.method == "oeffne",
          let ziel = URL(string: UIApplication.openSettingsURLString)
        else {
          result(FlutterMethodNotImplemented)
          return
        }
        UIApplication.shared.open(ziel) { _ in result(nil) }
      }
      einstellungenChannel = channel
    }

    let keychain = engineBridge.pluginRegistry.registrar(forPlugin: "KeychainChannel")
    if let messenger = keychain?.messenger() {
      keychainChannel = KeychainChannel.register(with: messenger)
    }

    let live = engineBridge.pluginRegistry.registrar(forPlugin: "LiveChannel")
    if let messenger = live?.messenger() {
      liveChannel = LiveChannel.register(with: messenger)
    }
  }
}
