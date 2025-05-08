import UIKit
import Flutter
import device_monitor  // Import your plugin

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Safely unwrap the registrar
    if let registrar = self.registrar(forPlugin: "DeviceMonitorPlugin") {
      // Register the plugin
      DeviceMonitorPlugin.register(with: registrar)
    } else {
      print("Failed to get registrar for DeviceMonitorPlugin")
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
