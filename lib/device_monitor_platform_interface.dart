import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'device_monitor_method_channel.dart';


abstract class DeviceMonitorPlatform extends PlatformInterface {
  DeviceMonitorPlatform() : super(token: _token);

  static final Object _token = Object();

  static DeviceMonitorPlatform _instance = MethodChannelDeviceMonitor();

  static DeviceMonitorPlatform get instance => _instance;

  static set instance(DeviceMonitorPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('getPlatformVersion() has not been implemented.');
  }

  Future<void> startService({
    required int interval,
    required double distanceAccuracy,
    required List<String> geofences,
    required String userId,
  }) {
    throw UnimplementedError('startService() has not been implemented.');
  }

  Future<void> stopService() {
    throw UnimplementedError('stopService() has not been implemented.');
  }

  Future<void> pauseService() {
    throw UnimplementedError('pauseService() has not been implemented.');
  }

  Stream<Map<String, dynamic>> getLocationUpdates() {
    throw UnimplementedError('getLocationUpdates() has not been implemented.');
  }

  Future<void> isServiceRunning() {
    throw UnimplementedError('pauseService() has not been implemented.');
  }
}