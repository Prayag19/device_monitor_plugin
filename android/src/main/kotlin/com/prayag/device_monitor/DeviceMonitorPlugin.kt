package com.prayag.device_monitor

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel


class DeviceMonitorPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private var activity: Activity? = null
    private var context: Context? = null

    companion object {
        private const val LOCATION_PERMISSION_REQUEST_CODE = 1001
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "device_monitor")
        channel.setMethodCallHandler(this)
        context = binding.applicationContext
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startService" -> {
                if (activity != null && arePermissionsGranted()) {

                    val interval: Long? = (call.argument<Number>("interval") as Number).toLong()
                    val distanceAccuracy: Double? = call.argument<Double>("distanceAccuracy")
                    val geofences:  List<String>? = call.argument< List<String>?>("geofences")
                    val userId: String? = call.argument<String>("userId")

                    // Ensure all arguments are present before starting the service
                    if (interval != null && distanceAccuracy != null && geofences != null && userId != null) {
                        startLocationService(interval, distanceAccuracy, geofences, userId)
                        result.success("Location service started")
                    } else {
                        result.error("INVALID_ARGUMENT", "One or more arguments are missing", null)
                    }
                } else {
                    requestPermissions()
                    result.error("PERMISSION_DENIED", "Location permissions are not granted", null)
                }
            }

            "stopService" -> {
                stopLocationService()
                result.success("Location service stopped")
            }

            else -> {
                result.notImplemented()
            }
        }
    }

    private fun arePermissionsGranted(): Boolean {
        activity?.let {
            val fineLocationGranted = ContextCompat.checkSelfPermission(it, android.Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
            val coarseLocationGranted = ContextCompat.checkSelfPermission(it, android.Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
            val backgroundLocationGranted = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.Q) {
                ContextCompat.checkSelfPermission(it, android.Manifest.permission.ACCESS_BACKGROUND_LOCATION) == PackageManager.PERMISSION_GRANTED
            } else {
                true
            }
            return fineLocationGranted && coarseLocationGranted && backgroundLocationGranted
        }
        return false
    }

    private fun requestPermissions() {
        activity?.let {
            val permissions = mutableListOf(
                    android.Manifest.permission.ACCESS_FINE_LOCATION,
                    android.Manifest.permission.ACCESS_COARSE_LOCATION
            )
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.Q) {
                permissions.add(android.Manifest.permission.ACCESS_BACKGROUND_LOCATION)
            }
            ActivityCompat.requestPermissions(it, permissions.toTypedArray(), LOCATION_PERMISSION_REQUEST_CODE)
        }
    }

    private fun startLocationService(interval: Long?, distanceAccuracy: Double?, geofences: List<String>?, userId: String?) {
        context?.let {
            LocationService.flutterChannel = channel // Set the channel for the service to use

            // Create the Intent for the LocationService
            val serviceIntent = Intent(it, LocationService::class.java)

            // Pass the parameters as extras
            serviceIntent.putExtra("interval", interval)
            serviceIntent.putExtra("distanceAccuracy", distanceAccuracy)
            serviceIntent.putExtra("userId", userId)

            // Convert geofences List<String> to a more structured List<Map<String, Double>>
            val geofenceList = geofences?.mapNotNull { geofence ->
                val parts = geofence.split(",")
                if (parts.size == 3) {
                    val latitude = parts[0].trim().toDoubleOrNull()
                    val longitude = parts[1].trim().toDoubleOrNull()
                    val radius = parts[2].trim().toDoubleOrNull()
                    if (latitude != null && longitude != null && radius != null) {
                        mapOf(
                                "latitude" to latitude,
                                "longitude" to longitude,
                                "radius" to radius
                        )
                    } else null
                } else null
            }

            serviceIntent.putExtra("geofenceList", ArrayList(geofenceList)) // Pass as ArrayList to Intent

            // Start the service
            ContextCompat.startForegroundService(it, serviceIntent)
        }
    }

    private fun stopLocationService() {
        context?.let {
            val serviceIntent = Intent(it, LocationService::class.java)
            it.stopService(serviceIntent)
        }
    }
}


