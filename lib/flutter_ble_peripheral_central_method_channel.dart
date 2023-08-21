import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flutter_ble_peripheral_central_platform_interface.dart';

/// An implementation of [FlutterBlePeripheralCentralPlatform] that uses method channels.
class MethodChannelFlutterBlePeripheralCentral extends FlutterBlePeripheralCentralPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_ble_peripheral_central');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
