
import 'flutter_ble_peripheral_central_platform_interface.dart';

class FlutterBlePeripheralCentral {
  Future<String?> getPlatformVersion() {
    return FlutterBlePeripheralCentralPlatform.instance.getPlatformVersion();
  }
}
