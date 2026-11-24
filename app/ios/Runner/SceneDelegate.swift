import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {

  /// Kaltstart über die Live-Aktivität: Der Link liegt in den
  /// `connectionOptions`, bevor die Engine läuft. Erst Flutter, dann der
  /// Puffer — Dart holt ihn beim Start mit `nimmLink` ab (#366).
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    Self.puffere(connectionOptions.urlContexts)
  }

  /// Link bei laufender App. Der Puffer meldet ihn über `linkDa`.
  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    super.scene(scene, openURLContexts: URLContexts)
    Self.puffere(URLContexts)
  }

  private static func puffere(_ contexts: Set<UIOpenURLContext>) {
    for context in contexts {
      LiveLinkBuffer.shared.nimmAn(context.url)
    }
  }
}
