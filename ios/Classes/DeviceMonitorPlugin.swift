import Flutter
import UIKit
import CoreLocation
import Foundation
import UserNotifications

public class DeviceMonitorPlugin: NSObject, FlutterPlugin, CLLocationManagerDelegate {

    private var locationManager: CLLocationManager?
    private var flutterChannel: FlutterMethodChannel?
    private var locationUpdateTimer: Timer?
    private var geofences: [[String: Double]] = []
    private var userId: String?
    private var interval: TimeInterval = 1800 // Default to 30 minutes
    private var distanceAccuracy: Double = 0.0

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "device_monitor", binaryMessenger: registrar.messenger())
        let instance = DeviceMonitorPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
      switch call.method {
      case "startService":
          if let arguments = call.arguments as? [String: Any] {
              print("Received arguments: \(arguments)")

              guard let interval = arguments["interval"] as? TimeInterval,
                    let distanceAccuracy = arguments["distanceAccuracy"] as? Double,
                    let geofences = arguments["geofences"] as? [String],  // Geofences as an array of strings
                    let userId = arguments["userId"] as? String else {
                  result(FlutterError(code: "INVALID_ARGUMENT", message: "Invalid arguments", details: nil))
                  return
              }

              // Parse geofences from the string format "latitude,longitude,radius"
              self.geofences = geofences.compactMap { geofence in
                  let components = geofence.split(separator: ",")
                  if components.count == 3,
                     let latitude = Double(components[0]),
                     let longitude = Double(components[1]),
                     let radius = Double(components[2]) {
                      return ["latitude": latitude, "longitude": longitude, "radius": radius]
                  }
                  return nil  // If parsing fails, return nil
              }

              // Save other arguments
              self.interval = interval
              self.distanceAccuracy = distanceAccuracy
              self.userId = userId

              // Start the location service
              startLocationService(result: result)
          } else {
              result(FlutterError(code: "INVALID_ARGUMENT", message: "Missing arguments", details: nil))
          }

      case "stopService":
          stopLocationService()
          result("Location service stopped")

      case "isServiceRunning":
          result(locationManager?.delegate != nil)

      default:
          result(FlutterMethodNotImplemented)
      }
  }
    private func startLocationService(result: @escaping FlutterResult) {
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        locationManager?.desiredAccuracy = kCLLocationAccuracyBest
        locationManager?.distanceFilter = distanceAccuracy
        locationManager?.requestAlwaysAuthorization()

        // Start updating location
        locationManager?.startUpdatingLocation()

        // Start timer for periodic tasks, e.g., logging location and battery
        locationUpdateTimer = Timer.scheduledTimer(timeInterval: interval, target: self, selector: #selector(logLocationAndBattery), userInfo: nil, repeats: true)

        result("Location service started")
    }

    private func stopLocationService() {
        locationManager?.stopUpdatingLocation()
        locationManager = nil
        locationUpdateTimer?.invalidate()
        locationUpdateTimer = nil
    }

    @objc private func logLocationAndBattery() {
        guard let location = locationManager?.location else { return }

        let batteryLevel = getBatteryLevel()
        let timestamp = getCurrentDateTime()

        // Check if any geofence is triggered
        var geofenceLogs: [String] = []
        for (index, geofence) in geofences.enumerated() {
            guard let geofenceLatitude = geofence["latitude"],
                  let geofenceLongitude = geofence["longitude"],
                  let geofenceRadius = geofence["radius"] else { continue }

            let geofenceLocation = CLLocation(latitude: geofenceLatitude, longitude: geofenceLongitude)
            let distance = location.distance(from: geofenceLocation)

            if distance <= geofenceRadius {
                // Geofence triggered, log it
                let geofenceLog = """
                {
                    "latitude": "\(geofenceLatitude)",
                    "longitude": "\(geofenceLongitude)",
                    "radius": "\(geofenceRadius)",
                    "distance": "\(distance)"
                }
                """
                geofenceLogs.append(geofenceLog)
            }
        }

        // Log location and battery
        let logEntry = """
        {
            "time": "\(timestamp)",
            "latitude": "\(location.coordinate.latitude)",
            "longitude": "\(location.coordinate.longitude)",
            "battery": "\(batteryLevel)",
            "user_id": "\(userId ?? "")",
            "geofences": [\(geofenceLogs.joined(separator: ","))]
        }
        """

        writeToFile(logEntry)

        // Send update to Flutter
        sendUpdateToFlutter(location: location, timestamp: timestamp, batteryLevel: batteryLevel, geofenceDistance: nil)
    }

    private func sendUpdateToFlutter(location: CLLocation, timestamp: String, batteryLevel: Int, geofenceDistance: Double?) {
        let data: [String: Any] = [
            "time": timestamp,
            "latitude": location.coordinate.latitude,
            "longitude": location.coordinate.longitude,
            "battery": batteryLevel
        ]

        flutterChannel?.invokeMethod("locationUpdate", arguments: data)
    }

    private func writeToFile(_ data: String) {
        // Write to a log file, app-specific storage
        let fileManager = FileManager.default
        if let directory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            let filePath = directory.appendingPathComponent("location_battery_log.txt")
            do {
                try data.appendLineToURL(fileURL: filePath)
            } catch {
                print("Error writing to file: \(error)")
            }
        }
    }

    private func getBatteryLevel() -> Int {
        let device = UIDevice.current
        device.isBatteryMonitoringEnabled = true
        return Int(device.batteryLevel * 100)
    }

    private func getCurrentDateTime() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return dateFormatter.string(from: Date())
    }
}

extension String {
    func appendLineToURL(fileURL: URL) throws {
        let fileHandle = try FileHandle(forWritingTo: fileURL)
        fileHandle.seekToEndOfFile()
        fileHandle.write(self.data(using: .utf8)!)
        fileHandle.closeFile()
    }
}
