package com.prayag.device_monitor

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.location.Location
import android.os.BatteryManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.google.android.gms.location.*
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileWriter
import java.io.IOException
import java.text.SimpleDateFormat
import java.util.*
import android.content.pm.ServiceInfo;

class LocationService : Service() {

    private lateinit var handler: Handler
    private lateinit var runnable: Runnable
    private lateinit var notificationBuilder: NotificationCompat.Builder
    private lateinit var fusedLocationClient: FusedLocationProviderClient
    private val fileName = "location_battery_log.txt"
    private val channelId = "location_service_channel"
    private var setInterval: Long = 1800000 // Default to 30 minutes
    private var distanceAccuracy: Double = 0.0 // Default accuracy
    private var geofences:List<Map<String, Double>>? = null
    private var userId: String? = null

    companion object {
        var flutterChannel: MethodChannel? = null
    }

    override fun onCreate() {
        super.onCreate()
        handler = Handler(Looper.getMainLooper())
        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)

        createNotificationChannel() // Create the notification channel
        notificationBuilder = createNotificationBuilder()
        // Start the service as a foreground service
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                    1, // Notification ID
                    notificationBuilder.build(),
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION // Specify that the service uses location
            )
        } else {
            startForeground(1, notificationBuilder.build())
        }

        // Initialize runnable and start logging task
        startLoggingTask()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Extract the parameters from the Intent with appropriate default values and null checks
        setInterval = intent?.getLongExtra("interval", 1800000L) ?: 1800000L
        distanceAccuracy = intent?.getDoubleExtra("distanceAccuracy", 0.0) ?: 0.0
        userId = intent?.getStringExtra("userId") ?: ""

        // Extract the geofences from the Intent
        geofences = intent?.getSerializableExtra("geofenceList") as? List<Map<String, Double>>

        // Log the geofences for debugging
        geofences?.forEach { geofence ->
            Log.d("LocationService", "Geofence: Latitude: ${geofence["latitude"]}, Longitude: ${geofence["longitude"]}, Radius: ${geofence["radius"]}")
        }

        // Restart the logging task with the updated interval
        startLoggingTask()

        return START_NOT_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        handler.removeCallbacks(runnable)
        stopLocationUpdates()
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    // Location Callback to handle location updates
    private val locationCallback = object : LocationCallback() {
        override fun onLocationResult(locationResult: LocationResult) {
            locationResult ?: return
            for (location in locationResult.locations) {
                Log.d("LocationService", "Location changed: Latitude: ${location.latitude}, Longitude: ${location.longitude}")
                logLocationAndBattery(location)
            }
        }
    }

    // Start requesting location updates
    private fun startLocationUpdates() {
        Log.d("LocationService", "$setInterval")
        Log.d("distanceAccuracy", "$distanceAccuracy")
        val locationRequest = LocationRequest.create().apply {
            interval = setInterval
            fastestInterval = 500L
            priority = LocationRequest.PRIORITY_HIGH_ACCURACY
            smallestDisplacement = 0f // Set the smallest displacement
        }

        fusedLocationClient.requestLocationUpdates(locationRequest, locationCallback, Looper.getMainLooper())
        Log.d("LocationService", "Location updates requested")
    }

    // Stop location updates when the service is destroyed
    private fun stopLocationUpdates() {
        fusedLocationClient.removeLocationUpdates(locationCallback)
        Log.d("LocationService", "Location updates stopped")
    }

    // Periodic task to log location and battery status
    private fun startLoggingTask() {
//        if (runnable != null) {
//            handler.removeCallbacks(runnable);
//        }

        // Remove any existing callbacks to avoid overlapping
        runnable = Runnable {
            // This will automatically trigger location updates via the callback
            startLocationUpdates()
            handler.postDelayed(runnable, setInterval)
        }
        handler.post(runnable)
    }

    // Log location and battery information to a file and update the notification
    private fun logLocationAndBattery(location: Location) {
        val batteryLevel = getBatteryLevel()
        val datetime = getCurrentDateTime()

        // List to accumulate log entries for each geofence
        val geofenceLogs = mutableListOf<String>()

        geofences?.forEachIndexed { index, geofence ->
            val geofenceLocation = Location("").apply {
                latitude = geofence["latitude"] ?: return@forEachIndexed
                longitude = geofence["longitude"] ?: return@forEachIndexed
            }
            val geofenceDistance = location.distanceTo(geofenceLocation).toDouble()

            Log.d("LocationService", "Geofence $index - Location: $geofenceLocation, Distance: $geofenceDistance meters")

            // Prepare the log entry for this specific geofence
            val geofenceLogEntry = buildString {
                append("  {\n")
                append("    \"latitude\": \"${geofence["latitude"]}\",\n")
                append("    \"longitude\": \"${geofence["longitude"]}\",\n")
                append("    \"radius\": \"${geofence["radius"]}\",\n")
                append("    \"distance\": \"$geofenceDistance\"\n")
                append("  }")
            }

            // Add the log entry to the list
            geofenceLogs.add(geofenceLogEntry)
        }

        // Prepare the overall log entry including all geofences
        val logEntry = buildString {
            append("{\n")
            append("  \"time\": \"$datetime\",\n")
            append("  \"current_lat\": \"${location.latitude}\",\n")
            append("  \"current_long\": \"${location.longitude}\",\n")
            append("  \"battery_value\": \"$batteryLevel%\",\n")
            append("  \"user_id\": \"$userId\",\n")
            append("  \"geofences\": [\n")
            append(geofenceLogs.joinToString(",\n")) // Join all geofence logs into a JSON array
            append("\n  ]\n")
            append("}")
        }

        // Write the entire log entry to the file
        writeToFile(logEntry)

        // Update the notification and send data to Flutter
        updateNotification(location, batteryLevel)
        sendUpdateToFlutter(location, datetime, batteryLevel, null) // Not sending a single geofence distance
    }

    // Update the notification with the latest location and battery info
    private fun updateNotification(location: Location, batteryLevel: Int) {
        val notification = notificationBuilder
                .setContentText("Lat: ${location.latitude}, Long: ${location.longitude}, Battery: $batteryLevel%")
                .build()

        NotificationManagerCompat.from(this).notify(1, notification)
    }

    // Send location and battery updates to Flutter via MethodChannel
    private fun sendUpdateToFlutter(location: Location, datetime: String, batteryLevel: Int, geofenceDistance: Double?) {
        val data = mapOf(
                "time" to datetime,
                "latitude" to location.latitude,
                "longitude" to location.longitude,
                "battery" to batteryLevel,
                "geofence_distance" to geofenceDistance
        )
        flutterChannel?.invokeMethod("locationUpdate", data)
    }

    // Write log data to a file
    private fun writeToFile(data: String) {
        try {
            val file = File(getExternalFilesDir(null), fileName)
            val fileWriter = FileWriter(file, true)
            fileWriter.append(data).append("\n")
            fileWriter.flush()
            fileWriter.close()
        } catch (e: IOException) {
            e.printStackTrace()
        }
    }

    // Create the notification builder
    private fun createNotificationBuilder(): NotificationCompat.Builder {
        val channelId = "location_service_channel" // Ensure this matches the ID used in createNotificationChannel()

        return NotificationCompat.Builder(this, channelId)
                .setContentTitle("Location Service")
                .setContentText("Tracking your location in the background")
                .setSmallIcon(android.R.drawable.ic_menu_mylocation) // Use a valid icon
                .setPriority(NotificationCompat.PRIORITY_LOW) // Priority should be LOW for background services
                .setCategory(NotificationCompat.CATEGORY_SERVICE) // Indicate this is a foreground service
                .setOngoing(true) // Prevents the notification from being swiped away
    }

    // Create the notification channel
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val serviceChannel = NotificationChannel(
                    channelId,
                    "Location Service Channel",
                    NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Channel for Location Service"
                setSound(null, null) // Disable sound
                setVibrationPolicy(VibrationPolicy.DONT_VIBRATE) // Disable vibration / enableVibration(false) /
            }

            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(serviceChannel)
        }
    }

    // Get the current battery level
    private fun getBatteryLevel(): Int {
        val bm = getSystemService(BATTERY_SERVICE) as BatteryManager
        return bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
    }

    // Get the current date and time formatted as a string
    private fun getCurrentDateTime(): String {
        return SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault()).format(Date())
    }
}
