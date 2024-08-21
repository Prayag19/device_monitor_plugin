import 'package:flutter_test/flutter_test.dart';
import 'package:device_monitor/device_monitor.dart';
import 'package:device_monitor/device_monitor_platform_interface.dart';
import 'package:device_monitor/device_monitor_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockDeviceMonitorPlatform
    with MockPlatformInterfaceMixin
    implements DeviceMonitorPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final DeviceMonitorPlatform initialPlatform = DeviceMonitorPlatform.instance;

  test('$MethodChannelDeviceMonitor is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelDeviceMonitor>());
  });

  test('getPlatformVersion', () async {
    DeviceMonitor deviceMonitorPlugin = DeviceMonitor();
    MockDeviceMonitorPlatform fakePlatform = MockDeviceMonitorPlatform();
    DeviceMonitorPlatform.instance = fakePlatform;

    expect(await deviceMonitorPlugin.getPlatformVersion(), '42');
  });
}
