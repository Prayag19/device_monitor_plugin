
import 'device_monitor_platform_interface.dart';

class DeviceMonitor {
  Future<String?> getPlatformVersion() {
    return DeviceMonitorPlatform.instance.getPlatformVersion();
  }
}
