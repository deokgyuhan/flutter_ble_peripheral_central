import Flutter
import UIKit

public class FlutterBlePeripheralCentralPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "flutter_ble_peripheral_central", binaryMessenger: registrar.messenger())
    let instance = FlutterBlePeripheralCentralPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)

    //register handler
    BLEPeripheralHandler.register(with: registrar) //peripheral
    BLECentralHandler.register(with: registrar)    //central
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
