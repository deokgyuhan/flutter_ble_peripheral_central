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
    var current_result: FlutterResult?
    
    var textForAdvertising = ""
    var textCharForRead = ""
    
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
        case "editTextCharForRead":
            current_result = result
            if let args = call.arguments as? Dictionary<String, Any>,
                let text = args["textCharForRead"] as? String {
                textCharForRead = text
                let data = text.data(using: .utf8) ?? Data()
                editTextCharForRead(editText: textCharForRead)
                
              } else {
                result(FlutterError.init(code: "errorSetDebug", message: "data or format error", details: nil))
              }
        case "sendIndicate":
            current_result = result
            if let args = call.arguments as? Dictionary<String, Any>,
                let text = args["sendData"] as? String {
                let data = text.data(using: .utf8) ?? Data()
                bleSendIndication(text)
                result("success")
              } else {
                result(FlutterError.init(code: "errorSetDebug", message: "data or format error", details: nil))
              }
        case "stopBlePeripheralSearvice":
            current_result = result
            bleStopAdvertising()
            result("success")
        default:
            current_result = result
            result(FlutterMethodNotImplemented)
        }
    }
}

extension BLEPeripheralHandler: FlutterStreamHandler {

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        sink = events
        
        if let argsMap = arguments as? [String: Any],
           let textAdvertising = argsMap["textForAdvertising"] as? String,
           let textForRead = argsMap["textCharForRead"] as? String {
            textForAdvertising = textAdvertising
            textCharForRead = textForRead
            startBleAdvertising(advertisingData: textForAdvertising)
//           print("onListen Call....");
        } else {
            //
        }
    
      return nil
    }


    @objc func startBleAdvertising(advertisingData: String) {
        bleStartAdvertising(advertisingData)
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        sink = nil
        bleStopAdvertising()
//        print("onCancel Call....");
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
        sink?(toJson(text: "startAdvertising"))
        sink?(stateToJson(text: "connected"))
        blePeripheral.startAdvertising(dictionary)
    }

    private func bleStopAdvertising() {
        sink?(toJson(text: "stopAdvertising"))
        sink?(stateToJson(text: "disconnected"))
        blePeripheral.stopAdvertising()
    }
    

    private func editTextCharForRead(editText: String) {
        current_result?("success")
    }
    
    private func bleSendIndication(_ valueString: String) {
        guard let charForIndicate = charForIndicate else {
            sink?(toJson(text: "cannot indicate, characteristic is nil"))
            return
        }
        let data = valueString.data(using: .utf8) ?? Data()
        let result = blePeripheral.updateValue(data, for: charForIndicate, onSubscribedCentrals: nil)
        let resultStr = result ? "true" : "false"
        sink?(toJson(text: "updateValue result = '\(resultStr)' value = '\(valueString)'"))
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

    private func toJson(text: String) -> String {
        return "{\"message\": \"\(text)\"}"
    }

    private func stateToJson(text: String) -> String {
        return "{\"state\": \"\(text)\"}"
    }

    private func eventToJson(event: String, text: String) -> String {
        return "{\"\(event)\": \"\(text)\"}"
    }
}

// CBPeripheralManagerDelegate
extension BLEPeripheralHandler: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        print("didUpdateState: \(peripheral.state.stringValueOfPeripheral)")

        if peripheral.state == .poweredOn {
            sink?(eventToJson(event: "didStartAdvertising", text: "didStartAdvertising: adding BLE service"))
            blePeripheral.add(buildBLEService())
        }
    }

    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error = error {
            sink?(eventToJson(event: "didStartAdvertising", text: "didStartAdvertising: error: \(error.localizedDescription)"))
        } else {
            sink?(eventToJson(event: "didStartAdvertising", text: "didStartAdvertising: success"))
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        if let error = error {
            sink?(eventToJson(event: "didAddService", text: "didAddService: error: \(error.localizedDescription)"))
        } else {
            sink?(eventToJson(event: "didAddService", text: "didAddService: success: \(service.uuid.uuidString)"))
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager,
                           central: CBCentral,
                           didSubscribeTo characteristic: CBCharacteristic) {
        sink?(eventToJson(event: "didSubscribeTo", text: "didSubscribeTo UUID: \(characteristic.uuid.uuidString)"))
        sink?(stateToJson(text: "subscribe"))
        if characteristic.uuid == uuidCharForIndicate {
            subscribedCentrals.append(central)
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager,
                           central: CBCentral,
                           didUnsubscribeFrom characteristic: CBCharacteristic) {
        sink?(eventToJson(event: "didUnsubscribeFrom", text: "didUnsubscribeFrom UUID: \(characteristic.uuid.uuidString)"))
        sink?(stateToJson(text: "unsubscribe"))
        if characteristic.uuid == uuidCharForIndicate {
            subscribedCentrals.removeAll { $0.identifier == central.identifier }
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        var log = "didReceiveRead UUID: \(request.characteristic.uuid.uuidString)"
        log += "\noffset: \(request.offset)"

        switch request.characteristic.uuid {
        case uuidCharForRead:
            let textValue =  textCharForRead
            log += "\nresponding with success, value = '\(textValue)'"
            request.value = textValue.data(using: .utf8)
            blePeripheral.respond(to: request, withResult: .success)
        default:
            log += "\nresponding with attributeNotFound"
            blePeripheral.respond(to: request, withResult: .attributeNotFound)
        }
        sink?(eventToJson(event: "didReceiveRead", text: log))
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        var textValue = ""
        var log = "didReceiveWrite requests.count = \(requests.count)"

        requests.forEach { (request) in
            log += "\nrequest.offset: \(request.offset)"
            log += "\nrequest.char.UUID: \(request.characteristic.uuid.uuidString)"
            switch request.characteristic.uuid {
            case uuidCharForWrite:
                let data = request.value ?? Data()
                textValue = String(data: data, encoding: .utf8) ?? ""

                sink?(eventToJson(event: "onCharacteristicWriteRequest", text: textValue))

                log += "\nresponding with success, value = '\(textValue)'"
                blePeripheral.respond(to: request, withResult: .success)
            default:
                log += "\nresponding with attributeNotFound"
                blePeripheral.respond(to: request, withResult: .attributeNotFound)
            }
        }
        sink?(toJson(text: log))
    }

    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        sink?(toJson(text: "isReadyToUpdateSubscribers"))
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
