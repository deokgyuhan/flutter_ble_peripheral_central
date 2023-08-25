import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ble_peripheral_central/flutter_ble_peripheral_central.dart';
import 'package:flutter_ble_peripheral_central/flutter_ble_peripheral_central_platform_interface.dart';
import 'package:flutter_ble_peripheral_central/flutter_ble_peripheral_central_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFlutterBlePeripheralCentralPlatform
    with MockPlatformInterfaceMixin
    implements FlutterBlePeripheralCentralPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final FlutterBlePeripheralCentralPlatform initialPlatform = FlutterBlePeripheralCentralPlatform.instance;

  test('$MethodChannelFlutterBlePeripheralCentral is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFlutterBlePeripheralCentral>());
  });

  test('getPlatformVersion', () async {
    FlutterBlePeripheralCentral flutterBlePeripheralCentralPlugin = FlutterBlePeripheralCentral();
    MockFlutterBlePeripheralCentralPlatform fakePlatform = MockFlutterBlePeripheralCentralPlatform();
    FlutterBlePeripheralCentralPlatform.instance = fakePlatform;

    expect(await flutterBlePeripheralCentralPlugin.getPlatformVersion(), '42');
  });
}
