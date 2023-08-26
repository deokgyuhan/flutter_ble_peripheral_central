
import 'flutter_ble_peripheral_central_platform_interface.dart';

class FlutterBlePeripheralCentral {
  Future<String?> getPlatformVersion() {
    return FlutterBlePeripheralCentralPlatform.instance.getPlatformVersion();
  }

  // peripheral begin
  Stream<dynamic> startBlePeripheralService()  {
    return FlutterBlePeripheralCentralPlatform.instance.startBlePeripheralService();
  }

  Future<String?> sendIndicate(String sendData) {
    return FlutterBlePeripheralCentralPlatform.instance.sendIndicate(sendData);
  }

  Future<String?> stopBlePeripheralService() {
    return FlutterBlePeripheralCentralPlatform.instance.stopBlePeripheralService();
  }
  // peripheral end

  // central begin
  Stream<dynamic> scanAndConnect() {
    return FlutterBlePeripheralCentralPlatform.instance.scanAndConnect();
  }

  Future<String?> bleReadCharacteristic()  {
    return FlutterBlePeripheralCentralPlatform.instance.bleReadCharacteristic();
  }

  Future<String?> bleWriteCharacteristic(String sendData) {
    return FlutterBlePeripheralCentralPlatform.instance.bleWriteCharacteristic(sendData);
  }

  Future<String?> bleDisconnect() {
    return FlutterBlePeripheralCentralPlatform.instance.bleDisconnect();
  }
  // central end
}
