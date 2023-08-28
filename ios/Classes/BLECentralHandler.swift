//
//  BLECentralHandler.swift
//  Runner
//
//  Created by DeokGyu Han on 2023/08/10.
//
import Flutter
import Foundation
import CoreBluetooth

class BLECentralHandler: NSObject, FlutterPlugin {
    // BLE related properties
    let uuidService = CBUUID(string: "25AE1441-05D3-4C5B-8281-93D4E07420CF")
    let uuidCharForRead = CBUUID(string: "25AE1442-05D3-4C5B-8281-93D4E07420CF")
    let uuidCharForWrite = CBUUID(string: "25AE1443-05D3-4C5B-8281-93D4E07420CF")
    let uuidCharForIndicate = CBUUID(string: "25AE1444-05D3-4C5B-8281-93D4E07420CF")

    var bleCentral: CBCentralManager!
    var connectedPeripheral: CBPeripheral?

    var userWantsToScanAndConnect: Bool = false

    let timeFormatter = DateFormatter()

    enum BLELifecycleState: String {
        case bluetoothNotReady
        case disconnected
        case scanning
        case connecting
        case connectedDiscovering
        case connected
    }

    var lifecycleState = BLELifecycleState.bluetoothNotReady {
        didSet {
            guard lifecycleState != oldValue else { return }
            appendLog("state = \(lifecycleState)")

            sink?(stateToJson(text: "\(lifecycleState)"))
        }
    }


    var sink: FlutterEventSink?
    var current_result: FlutterResult?

    static func register(with registrar: FlutterPluginRegistrar) {
        let eventChannel = FlutterEventChannel(name: "ble_central/event", binaryMessenger: registrar.messenger())
        let methodChannel = FlutterMethodChannel(name: "ble_central/method", binaryMessenger: registrar.messenger())
        let instance = BLECentralHandler()

        instance.initBLE()

        registrar.addMethodCallDelegate(instance, channel: methodChannel)
        eventChannel.setStreamHandler(instance)
    }
}

//  FlutterMethodCallDelegate
extension BLECentralHandler {
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "bleReadCharacteristic":
            current_result = result
            userWantsToScanAndConnect = true
            bleReadCharacteristic(uuid: uuidCharForRead)
        case "bleWriteCharacteristic":
            current_result = result
            userWantsToScanAndConnect = true
            if let args = call.arguments as? Dictionary<String, Any>,
                let text = args["sendData"] as? String {
                let data = text.data(using: .utf8) ?? Data()
                bleWriteCharacteristic(uuid: uuidCharForWrite, data: data)
                result("BLE Write Characteristic")
              } else {
                result(FlutterError.init(code: "errorSetDebug", message: "data or format error", details: nil))
              }
        case "bleDisconnect":
            current_result = result
            bleDisconnect()
            result("BLE Disconnect")
        default:
            current_result = result
            result(FlutterMethodNotImplemented)
        }
    }
}

extension BLECentralHandler: FlutterStreamHandler {

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        sink = events

        startBleRestartLifecycle()

        appendLog("onListen Call....");
      return nil
    }


    @objc func startBleRestartLifecycle() {
        userWantsToScanAndConnect = true
        bleRestartLifecycle()
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        sink = nil
        appendLog("onCancel Call....");
        return nil
    }
}

extension BLECentralHandler {
    /*
     Swift에서 함수를 호출할 때는 매개변수 이름과 함께 값을 전달하는것이 기본 형태임.

     Swift에서 함수를 호출할 때 매개변수 이름을 생략하고 싶다면,
     함수 정의 시에 매개변수 이름 앞에 밑줄(_)을 붙여주면 됨
     이렇게 하면 함수 호출 시에 매개변수 이름 생략 가능

     func appendLog(_ msg: String) {
         // 함수 내용
     }

     // 함수 호출 시 매개변수 이름 생략
     appendLog("This is a log message.")
     */

    func appendLog(_ msg: String) {
        print(msg)
    }
}

// BLE related methods
extension BLECentralHandler {
    private func initBLE() {
        // using DispatchQueue.main means we can update UI directly from delegate methods
        bleCentral = CBCentralManager(delegate: self, queue: DispatchQueue.main)
    }

    func bleRestartLifecycle() {
        guard bleCentral.state == .poweredOn else {
            connectedPeripheral = nil
            lifecycleState = .bluetoothNotReady
            return
        }

        if userWantsToScanAndConnect {
            if let oldPeripheral = connectedPeripheral {
                bleCentral.cancelPeripheralConnection(oldPeripheral)
            }
            connectedPeripheral = nil
            bleScan()
        } else {
            bleDisconnect()
        }
    }

    func bleScan() {
        lifecycleState = .scanning
        bleCentral.scanForPeripherals(withServices: [uuidService], options: nil)
    }

    func bleConnect(to peripheral: CBPeripheral) {
        connectedPeripheral = peripheral
        lifecycleState = .connecting
        bleCentral.connect(peripheral, options: nil)
    }

    func bleDisconnect() {
        userWantsToScanAndConnect = false
        if bleCentral.isScanning {
            bleCentral.stopScan()
        }
        if let peripheral = connectedPeripheral {
            bleCentral.cancelPeripheralConnection(peripheral)
        }
        lifecycleState = .disconnected
    }

    func bleReadCharacteristic(uuid: CBUUID) {
        guard let characteristic = getCharacteristic(uuid: uuid) else {
            appendLog("ERROR: read failed, characteristic unavailable, uuid = \(uuid.uuidString)")
            sink?(toJson(text: "ERROR: read failed, characteristic unavailable, uuid = \(uuid.uuidString)"))
            return
        }
        connectedPeripheral?.readValue(for: characteristic)
    }

    func bleWriteCharacteristic(uuid: CBUUID, data: Data) {
        guard let characteristic = getCharacteristic(uuid: uuid) else {
            appendLog("ERROR: write failed, characteristic unavailable, uuid = \(uuid.uuidString)")
            sink?(toJson(text: "ERROR: write failed, characteristic unavailable, uuid = \(uuid.uuidString)"))
            return
        }
        connectedPeripheral?.writeValue(data, for: characteristic, type: .withResponse)
    }

    func getCharacteristic(uuid: CBUUID) -> CBCharacteristic? {
        guard let service = connectedPeripheral?.services?.first(where: { $0.uuid == uuidService }) else {
            return nil
        }
        return service.characteristics?.first { $0.uuid == uuid }
    }

    private func bleGetStatusString() -> String {
        guard let bleCentral = bleCentral else { return "not initialized" }
        switch bleCentral.state {
        case .unauthorized:
            return bleCentral.state.stringValueOfCentral + " (allow in Settings)"
        case .poweredOff:
            return "Bluetooth OFF"
        case .poweredOn:
            return "ON, \(lifecycleState)"
        default:
            return bleCentral.state.stringValueOfCentral
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

//CBCentralManagerDelegate
extension BLECentralHandler: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        appendLog("central didUpdateState: \(central.state.stringValueOfCentral)")

        sink?(eventToJson(event: "didUpdateState", text: "central didUpdateState: \(central.state.stringValueOfCentral)"))

        bleRestartLifecycle()
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        appendLog("didDiscover {name = \(peripheral.name ?? String("nil"))}")

        sink?(toJson(text: "didDiscover {name = \(peripheral.name ?? String("nil"))}"))

        guard connectedPeripheral == nil else {
            appendLog("didDiscover ignored (connectedPeripheral already set)")

            sink?(eventToJson(event: "didDiscover", text: "didDiscover ignored (connectedPeripheral already set)"))

            return
        }

        bleCentral.stopScan()
        bleConnect(to: peripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        appendLog("didConnect")

        sink?(eventToJson(event: "didConnect", text: "didConnect"))

        lifecycleState = .connectedDiscovering
        peripheral.delegate = self
        peripheral.discoverServices([uuidService])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        if peripheral === connectedPeripheral {
            appendLog("didFailToConnect")

            sink?(eventToJson(event: "didFailToConnect", text: "didFailToConnect"))

            connectedPeripheral = nil
            bleRestartLifecycle()
        } else {
            appendLog("didFailToConnect, unknown peripheral, ingoring")

            sink?(eventToJson(event: "didFailToConnect", text: "didFailToConnect, unknown peripheral, ingoring"))
        }
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if peripheral === connectedPeripheral {
            appendLog("didDisconnect")

            sink?(eventToJson(event: "didDisconnect", text: "didDisconnect"))

            connectedPeripheral = nil
            bleRestartLifecycle()
        } else {
            appendLog("didDisconnect, unknown peripheral, ingoring")

            sink?(eventToJson(event: "didDisconnect", text: "didDisconnect, unknown peripheral, ingoring"))
        }
    }
}

extension BLECentralHandler: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let service = peripheral.services?.first(where: { $0.uuid == uuidService }) else {
            appendLog("ERROR: didDiscoverServices, service NOT found\nerror = \(String(describing: error)), disconnecting")

            sink?(eventToJson(event: "didDiscoverServices",text: "ERROR: didDiscoverServices, service NOT found\nerror = \(String(describing: error)), disconnecting"))

            bleCentral.cancelPeripheralConnection(peripheral)
            return
        }

        appendLog("didDiscoverServices, service found")

        sink?(eventToJson(event: "didDiscoverServices", text: "didDiscoverServices, service found"))

        peripheral.discoverCharacteristics([uuidCharForRead, uuidCharForWrite, uuidCharForIndicate], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        appendLog("didModifyServices")
        // usually this method is called when Android application is terminated
        if invalidatedServices.first(where: { $0.uuid == uuidService }) != nil {
            appendLog("disconnecting because peripheral removed the required service")

            sink?(eventToJson(event: "didModifyServices", text: "disconnecting because peripheral removed the required service"))

            bleCentral.cancelPeripheralConnection(peripheral)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        appendLog("didDiscoverCharacteristics \(error == nil ? "OK" : "error: \(String(describing: error))")")

        sink?(eventToJson(event: "didDiscoverCharacteristics", text: "didDiscoverCharacteristics \(error == nil ? "OK" : "error: \(String(describing: error))")"))

        if let charIndicate = service.characteristics?.first(where: { $0.uuid == uuidCharForIndicate }) {
            peripheral.setNotifyValue(true, for: charIndicate)
        } else {
            appendLog("WARN: characteristic for indication not found")

            sink?(eventToJson(event: "didDiscoverCharacteristics", text: "WARN: characteristic for indication not found"))

            lifecycleState = .connected
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            appendLog("didUpdateValue error: \(String(describing: error))")

            sink?(eventToJson(event: "didUpdateValue", text: "didUpdateValue error: \(String(describing: error))"))

            return
        }

        let data = characteristic.value ?? Data()
        let stringValue = String(data: data, encoding: .utf8) ?? ""

        appendLog("didUpdateValue '\(stringValue)'")

        sink?(eventToJson(event: "onCharacteristicChanged", text: stringValue))

        current_result?(stringValue)
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didWriteValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        appendLog("didWrite \(error == nil ? "OK" : "error: \(String(describing: error))")")

        sink?(eventToJson(event: "didWrite", text: "didWrite \(error == nil ? "OK" : "error: \(String(describing: error))")"))
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateNotificationStateFor characteristic: CBCharacteristic,
                    error: Error?) {
        guard error == nil else {
            appendLog("didUpdateNotificationState error\n\(String(describing: error))")

            sink?(eventToJson(event: "didUpdateNotificationState", text: "didUpdateNotificationState error\n\(String(describing: error))"))

            lifecycleState = .connected
            return
        }

        if characteristic.uuid == uuidCharForIndicate {
            let info = characteristic.isNotifying ? "Subscribed" : "Not subscribed"
            appendLog(info)
            sink?(toJson(text: info))
        }
        lifecycleState = .connected
    }
}

// CBManagerState
extension CBManagerState {
    var stringValueOfCentral: String {
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

