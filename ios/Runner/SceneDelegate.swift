import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    // Match the launch screen background (#00637B) so the UIWindow's default
    // white does not flash through during Flutter engine initialisation.
    window?.backgroundColor = UIColor(
      red: 0, green: 99.0 / 255.0, blue: 123.0 / 255.0, alpha: 1.0
    )
  }
}
