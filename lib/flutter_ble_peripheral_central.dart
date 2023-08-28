
import 'flutter_ble_peripheral_central_platform_interface.dart';

class FlutterBlePeripheralCentral {
  Future<String?> getPlatformVersion() {
    return FlutterBlePeripheralCentralPlatform.instance.getPlatformVersion();
  }

  // peripheral begin
  Stream<dynamic> startBlePeripheralService(String textForAdvertising, String textCharForRead)  {
    return FlutterBlePeripheralCentralPlatform.instance.startBlePeripheralService(textForAdvertising, textCharForRead);
  }

  Future<String?> editTextCharForRead(String textCharForRead) {
    return FlutterBlePeripheralCentralPlatform.instance.editTextCharForRead(textCharForRead);
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
