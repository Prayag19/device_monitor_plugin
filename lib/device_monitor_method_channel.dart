import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'device_monitor_platform_interface.dart';


class MethodChannelDeviceMonitor extends DeviceMonitorPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('device_monitor');
  StreamController<Map<String, dynamic>> _locationUpdateController = StreamController.broadcast();


  MethodChannelDeviceMonitor() {
    methodChannel.setMethodCallHandler(_handleMethodCall);
  }


  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  @override
  Future<void> startService({
    required int interval,
    required double distanceAccuracy,
    required List<String> geofences,
    required String userId,
  }) async {
    await methodChannel.invokeMethod('startService', {
      'interval': interval,
      'distanceAccuracy': distanceAccuracy,
      'geofences': geofences,
      'userId': userId,
    });
  }

  @override
  Future<void> stopService() async {
    await methodChannel.invokeMethod('stopService');
  }

  @override
  Future<void> pauseService() async {
    await methodChannel.invokeMethod('pauseService');
  }

  @override
  Stream<Map<String, dynamic>> getLocationUpdates() {
    return _locationUpdateController.stream;
  }


  @override
  Future<void> isServiceRunning() async {
    await methodChannel.invokeMethod('isServiceRunning');
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method == 'locationUpdate') {
      final Map<String, dynamic> locationData = Map<String, dynamic>.from(call.arguments);
      _locationUpdateController.add(locationData);
    } else {
      throw PlatformException(
        code: 'Unimplemented',
        details: "The method '${call.method}' is not implemented",
      );
    }
  }

  void dispose() {
    _locationUpdateController.close();
  }
}