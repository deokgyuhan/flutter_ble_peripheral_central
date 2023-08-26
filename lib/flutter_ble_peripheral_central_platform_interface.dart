import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'flutter_ble_peripheral_central_method_channel.dart';

abstract class FlutterBlePeripheralCentralPlatform extends PlatformInterface {
  /// Constructs a FlutterBlePeripheralCentralPlatform.
  FlutterBlePeripheralCentralPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterBlePeripheralCentralPlatform _instance = MethodChannelFlutterBlePeripheralCentral();

  /// The default instance of [FlutterBlePeripheralCentralPlatform] to use.
  ///
  /// Defaults to [MethodChannelFlutterBlePeripheralCentral].
  static FlutterBlePeripheralCentralPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlutterBlePeripheralCentralPlatform] when
  /// they register themselves.
  static set instance(FlutterBlePeripheralCentralPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  // peripheral begin
  Stream<dynamic> startBlePeripheralService() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<String?> sendIndicate(String sendData) {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<String?> stopBlePeripheralService() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
  // peripheral end

  // central begin
  Stream<dynamic> scanAndConnect() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<String?> bleReadCharacteristic() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<String?> bleWriteCharacteristic(String sendData) {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<String?> bleDisconnect() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
  // central end
}
