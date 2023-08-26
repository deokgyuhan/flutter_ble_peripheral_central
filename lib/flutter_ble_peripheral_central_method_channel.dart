import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flutter_ble_peripheral_central_platform_interface.dart';

/// An implementation of [FlutterBlePeripheralCentralPlatform] that uses method channels.
class MethodChannelFlutterBlePeripheralCentral extends FlutterBlePeripheralCentralPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_ble_peripheral_central');

  //peripheral
  final methodChannelOfPeripheral = const MethodChannel('ble_peripheral/method');
  final eventChannelOfPeripheral = const EventChannel('ble_peripheral/event');

  //central
  final methodChannelOfCentral = const MethodChannel('ble_central/method');
  final eventChannelOfCentral = const EventChannel('ble_central/event');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  // peripheral begin
  Stream<dynamic> startBlePeripheralSearvice()  {
    return eventChannelOfPeripheral.receiveBroadcastStream();
  }

  Future<String?> sendIndicate(String sendData) async {
    final result = await methodChannelOfPeripheral.invokeMethod<String>('sendIndicate', <String, dynamic>{'sendData': sendData});
    return result;
  }

  Future<String?> stopBlePeripheralSearvice() async {
    final result = await methodChannelOfPeripheral.invokeMethod<String>('stopBlePeripheralSearvice');
    return result;
  }
  // peripheral end

  // central begin
  Stream<dynamic> scanAndConnect() {
    return eventChannelOfCentral.receiveBroadcastStream();
  }

  Future<String?> bleReadCharacteristic() async {
    final result = await methodChannelOfCentral.invokeMethod<String>('bleReadCharacteristic');
    return result;
  }

  Future<String?> bleWriteCharacteristic(String sendData) async {
    final result = await methodChannelOfCentral.invokeMethod<String>('bleWriteCharacteristic', <String, dynamic>{'sendData': sendData});
    return result;
  }

  Future<String?> bleDisconnect() async {
    final result = await methodChannelOfCentral.invokeMethod<String>('bleDisconnect');
    return result;
  }
  // central end
}
