import 'dart:async';
import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:device_monitor/device_monitor_method_channel.dart';
import 'package:flutter/material.dart';
import 'package:device_monitor/device_monitor.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:permission_handler/permission_handler.dart';

final MethodChannelDeviceMonitor _deviceMonitor = MethodChannelDeviceMonitor();
void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Device Monitor Service Test',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: TestServiceScreen(),
    );
  }
}

class TestServiceScreen extends StatefulWidget {
  @override
  _TestServiceScreenState createState() => _TestServiceScreenState();
}

class _TestServiceScreenState extends State<TestServiceScreen> {
  String _locationStatus = 'Location service not running';
  final TextEditingController _intervalController =
      TextEditingController(text: '1800000');
  final TextEditingController _distanceAccuracyController =
      TextEditingController(text: '50.0');
  final TextEditingController _userIdController =
      TextEditingController(text: 'default_user');
  late StreamSubscription<Map<String, dynamic>> _locationSubscription;
  final List<String> _geofences = [
    '37.7749,-122.4194, 500.0', // Example: San Francisco, 500 meters
    '40.7128,-74.0060, 1000.0', // Example: New York, 1000 meters
    '19.044457454223895, 73.02556096307603, 2000.0', //
  ];
  String fileContent = 'Press the button to load the file content';
  @override
  void initState() {
    _checkPermissions();
    _locationSubscription =
        _deviceMonitor.getLocationUpdates().listen((locationData) {
      setState(() {
        _locationStatus = _locationStatus +
            "\n" +
            'Time: ${locationData['time']}, Lat: ${locationData['latitude']}, Long: ${locationData['longitude']}, Battery: ${locationData['battery']}%';
      });
    });
    super.initState();
  }

  Future<void> readLogFile() async {
    try {
      // Get the directory where the file is stored
      final directory = await getExternalStorageDirectory();

      // Construct the file path
      final filePath = '${directory?.path}/location_battery_log.txt';
      final file = File(filePath);

      // Check if the file exists
      if (await file.exists()) {
        // Read the file content
        String contents = await file.readAsString();
        setState(() {
          fileContent = contents;
        });
      } else {
        setState(() {
          fileContent = 'File does not exist';
        });
      }
    } catch (e) {
      // Handle any errors
      setState(() {
        fileContent = 'Error reading file: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Device Monitor Service Test'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: PageView(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _intervalController,
                  decoration: InputDecoration(
                    labelText: 'Interval (ms)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                SizedBox(height: 10),
                TextField(
                  controller: _distanceAccuracyController,
                  decoration: InputDecoration(
                    labelText: 'Distance Accuracy (meters)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                SizedBox(height: 10),
                TextField(
                  controller: _userIdController,
                  decoration: InputDecoration(
                    labelText: 'User ID',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 20),
                Text('Geofences:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                ..._geofences.map(
                    (entry) => Text('${entry}')),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: _startService,
                      child: Text('Start Service'),
                    ),
                    ElevatedButton(
                      onPressed: _stopService,
                      child: Text('Stop Service'),
                    ),
                    ElevatedButton(
                      onPressed: _pauseService,
                      child: Text('Pause Service'),
                    ),
                  ],
                ),
                Expanded(
                    child: SingleChildScrollView(child: Text(_locationStatus))),
              ],
            ),
            Column(
              children: <Widget>[
                ElevatedButton(
                  onPressed: () {
                    readLogFile();
                  },
                  child: Text('Load File Content'),
                ),
                SizedBox(height: 20),
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(fileContent),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Future<void> _checkPermissions() async {
    PermissionStatus status = await Permission.location.request();
  }

  void _startService() {
    final int interval = int.parse(_intervalController.text);
    final double distanceAccuracy =
        double.parse(_distanceAccuracyController.text);
    final String userId = _userIdController.text;

    _deviceMonitor.startService(
      interval: interval,
      distanceAccuracy: distanceAccuracy,
      geofences: _geofences,
      userId: userId,
    );
  }

  void _stopService() {
    _deviceMonitor.stopService();
  }

  void _pauseService() {
    _deviceMonitor.pauseService();
  }
}
