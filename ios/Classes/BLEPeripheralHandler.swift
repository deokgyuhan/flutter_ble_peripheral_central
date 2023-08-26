//
//  BLEPeripheralHandler.swift
//  Runner
//
//  Created by DeokGyu Han on 2023/08/03.
//

import Flutter
import CoreBluetooth

class BLEPeripheralHandler: NSObject, FlutterPlugin {
    // BLE related properties
    let uuidService = CBUUID(string: "25AE1441-05D3-4C5B-8281-93D4E07420CF")
    let uuidCharForRead = CBUUID(string: "25AE1442-05D3-4C5B-8281-93D4E07420CF")
    let uuidCharForWrite = CBUUID(string: "25AE1443-05D3-4C5B-8281-93D4E07420CF")
    let uuidCharForIndicate = CBUUID(string: "25AE1444-05D3-4C5B-8281-93D4E07420CF")

    var blePeripheral: CBPeripheralManager!
    var charForIndicate: CBMutableCharacteristic?
    var subscribedCentrals = [CBCentral]()

    var sink: FlutterEventSink?

    let timeFormatter = DateFormatter()

    static func register(with registrar: FlutterPluginRegistrar) {
        let eventChannel = FlutterEventChannel(name: "ble_peripheral/event", binaryMessenger: registrar.messenger())
        let methodChannel = FlutterMethodChannel(name: "ble_peripheral/method", binaryMessenger: registrar.messenger())
        let instance = BLEPeripheralHandler()

        instance.initBLE()

        registrar.addMethodCallDelegate(instance, channel: methodChannel)
        eventChannel.setStreamHandler(instance)
    }
}

//  FlutterMethodCallDelegate
extension BLEPeripheralHandler {
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "sendIndicate":
            if let args = call.arguments as? Dictionary<String, Any>,
                let text = args["sendData"] as? String {
                let data = text.data(using: .utf8) ?? Data()
                bleSendIndication(text)
                result("BLE sendIndicate")
              } else {
                result(FlutterError.init(code: "errorSetDebug", message: "data or format error", details: nil))
              }
        case "stopBlePeripheralSearvice":
            bleStopAdvertising()
            result("BLE advertising stopped")
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}

extension BLEPeripheralHandler: FlutterStreamHandler {

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        sink = events
        startBleAdvertising()
        print("onListen Call....");
      return nil
    }


    @objc func startBleAdvertising() {
        bleStartAdvertising("test")
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        sink = nil
        bleStopAdvertising()
        print("onCancel Call....");
        return nil
    }
}

// BLE related methods
extension BLEPeripheralHandler {

    func initBLE() {
        blePeripheral = CBPeripheralManager(delegate: self, queue: DispatchQueue.main)
    }


    private func buildBLEService() -> CBMutableService {

        // create characteristics
        let charForRead = CBMutableCharacteristic(type: uuidCharForRead,
                                                  properties: .read,
                                                  value: nil,
                                                  permissions: .readable)
        let charForWrite = CBMutableCharacteristic(type: uuidCharForWrite,
                                                   properties: .write,
                                                   value: nil,
                                                   permissions: .writeable)
        let charForIndicate = CBMutableCharacteristic(type: uuidCharForIndicate,
                                                      properties: .indicate,
                                                      value: nil,
                                                      permissions: .readable)
        self.charForIndicate = charForIndicate

        // create service
        let service = CBMutableService(type: uuidService, primary: true)
        service.characteristics = [charForRead, charForWrite, charForIndicate]
        return service
    }

    private func bleStartAdvertising(_ advertisementData: String) {
        let dictionary: [String: Any] = [CBAdvertisementDataServiceUUIDsKey: [uuidService],
                                         CBAdvertisementDataLocalNameKey: advertisementData]
        print("---------------------------->bleStartAdverting call")

        sink?("startAdvertising")
        blePeripheral.startAdvertising(dictionary)
    }

    private func bleStopAdvertising() {
        sink?("stopAdvertising")
        blePeripheral.stopAdvertising()
    }

    private func bleSendIndication(_ valueString: String) {
        guard let charForIndicate = charForIndicate else {
            sink?("cannot indicate, characteristic is nil")
            return
        }
        let data = valueString.data(using: .utf8) ?? Data()
        let result = blePeripheral.updateValue(data, for: charForIndicate, onSubscribedCentrals: nil)
        let resultStr = result ? "true" : "false"
        sink?("updateValue result = '\(resultStr)' value = '\(valueString)'")
    }

    private func bleGetStatusString() -> String {
        guard let blePeripheral = blePeripheral else { return "not initialized" }
        switch blePeripheral.state {
        case .unauthorized:
            return blePeripheral.state.stringValueOfPeripheral + " (allow in Settings)"
        case .poweredOff:
            return "Bluetooth OFF"
        case .poweredOn:
            let advertising = blePeripheral.isAdvertising ? "advertising" : "not advertising"
            return "ON, \(advertising)"
        default:
            return blePeripheral.state.stringValueOfPeripheral
        }
    }
}

// CBPeripheralManagerDelegate
extension BLEPeripheralHandler: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        print("didUpdateState: \(peripheral.state.stringValueOfPeripheral)")

        if peripheral.state == .poweredOn {
            sink?("adding BLE service")
            blePeripheral.add(buildBLEService())
        }
    }

    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error = error {
            sink?("didStartAdvertising: error: \(error.localizedDescription)")
        } else {
            sink?("didStartAdvertising: success")
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        if let error = error {
            sink?("didAddService: error: \(error.localizedDescription)")
        } else {
            sink?("didAddService: success: \(service.uuid.uuidString)")
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager,
                           central: CBCentral,
                           didSubscribeTo characteristic: CBCharacteristic) {
        sink?("didSubscribeTo UUID: \(characteristic.uuid.uuidString)")
        if characteristic.uuid == uuidCharForIndicate {
            subscribedCentrals.append(central)
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager,
                           central: CBCentral,
                           didUnsubscribeFrom characteristic: CBCharacteristic) {
        sink?("didUnsubscribeFrom UUID: \(characteristic.uuid.uuidString)")
        if characteristic.uuid == uuidCharForIndicate {
            subscribedCentrals.removeAll { $0.identifier == central.identifier }
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        print("------------->didReceiveRead: ")
        var log = "didReceiveRead UUID: \(request.characteristic.uuid.uuidString)"
        log += "\noffset: \(request.offset)"

        switch request.characteristic.uuid {
        case uuidCharForRead:
            let textValue =  "test~~~~~~~"
            log += "\nresponding with success, value = '\(textValue)'"
            request.value = textValue.data(using: .utf8)
            blePeripheral.respond(to: request, withResult: .success)
        default:
            log += "\nresponding with attributeNotFound"
            blePeripheral.respond(to: request, withResult: .attributeNotFound)
        }
        sink?(log)
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        var log = "didReceiveWrite requests.count = \(requests.count)"
        requests.forEach { (request) in
            log += "\nrequest.offset: \(request.offset)"
            log += "\nrequest.char.UUID: \(request.characteristic.uuid.uuidString)"
            switch request.characteristic.uuid {
            case uuidCharForWrite:
                let data = request.value ?? Data()
                let textValue = String(data: data, encoding: .utf8) ?? ""

                sink?(textValue)

                log += "\nresponding with success, value = '\(textValue)'"
                blePeripheral.respond(to: request, withResult: .success)
            default:
                log += "\nresponding with attributeNotFound"
                blePeripheral.respond(to: request, withResult: .attributeNotFound)
            }
        }
        sink?(log)
    }

    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        sink?("isReadyToUpdateSubscribers")
    }
}

// CBManagerState
extension CBManagerState {
    var stringValueOfPeripheral: String {
        switch self {
        case .unknown: return "unknown"
        case .resetting: return "resetting"
        case .unsupported: return "unsupported"
        case .unauthorized: return "unauthorized"
        case .poweredOff: return "poweredOff"
        case .poweredOn: return "poweredOn"
        @unknown default: return "\(rawValue)"
        }
    }
}
