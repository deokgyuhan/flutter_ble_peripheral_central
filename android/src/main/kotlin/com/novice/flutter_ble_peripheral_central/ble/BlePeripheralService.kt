package com.novice.flutter_ble_peripheral_central.ble

import android.Manifest
import android.app.Activity
import android.app.Service
import android.bluetooth.*
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.*
import androidx.core.app.ActivityCompat
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.*

private const val ENABLE_BLUETOOTH_REQUEST_CODE = 1
private const val BLUETOOTH_ALL_PERMISSIONS_REQUEST_CODE = 2
private const val SERVICE_UUID = "25AE1441-05D3-4C5B-8281-93D4E07420CF"
private const val CHAR_FOR_READ_UUID = "25AE1442-05D3-4C5B-8281-93D4E07420CF"
private const val CHAR_FOR_WRITE_UUID = "25AE1443-05D3-4C5B-8281-93D4E07420CF"
private const val CHAR_FOR_INDICATE_UUID = "25AE1444-05D3-4C5B-8281-93D4E07420CF"
private const val CCC_DESCRIPTOR_UUID = "00002902-0000-1000-8000-00805f9b34fb"

class BlePeripheralService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private var isAdvertising = false

    private var methodResult: MethodChannel.Result? = null

    private var eventSink: EventChannel.EventSink? = null
    private var sendData = ""

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == "startBlePeripheralService") {
            eventSink = EventSinkHolderOfPeripheral.eventSink
            startBlePeripheralSearvice()
//            eventSink?.success("onStartCommand  startBlePeripheralService call")
        } else if(intent?.action == "sendIndicate") {
            methodResult = MethodResultHolderOfPeripheral.methodResult
            sendData = intent?.getStringExtra("ADDITIONAL_DATA").toString()
            sendIndicate(sendData)
        } else if(intent?.action == "stopBlePeripheralService") {
            methodResult = MethodResultHolderOfPeripheral.methodResult
            stopBlePeripheralSearvice()
        }

        return START_STICKY
    }

    private fun startBlePeripheralSearvice() {
//        eventSink?.success("startBlePeripheralSearvice call")
        prepareAndStartAdvertising()
    }

    fun stopBlePeripheralSearvice() {
        bleStopAdvertising()
    }


    fun sendIndicate(sendIndicate: String) {
        bleIndicate(sendIndicate)
    }

    private fun bleIndicate(sendIndicate: String) {
        val text = sendIndicate
        val data = text.toByteArray(Charsets.UTF_8)
        charForIndicate?.let {
            it.value = data
            for (device in subscribedDevices) {
                gattServer?.notifyCharacteristicChanged(device, it, true)
            }
        }

        methodResult?.success("success")
    }

    private fun prepareAndStartAdvertising() {
//        eventSink?.success("prepareAndStartAdvertising call")
        ensureBluetoothCanBeUsed { isSuccess, message ->
//            eventSink?.success("ensureBluetoothCanBeUsed result: " + isSuccess)
            handler.post {
                eventSink?.success(message)
                if (isSuccess) {
                    bleStartAdvertising()
                } else {
                    isAdvertising = false
                }
            }
        }
    }

    private fun bleStartAdvertising() {
        isAdvertising = true
        bleStartGattServer()
        bleAdvertiser.startAdvertising(advertiseSettings, advertiseData, advertiseCallback)
    }

    private fun bleStopAdvertising() {
        isAdvertising = false
        bleStopGattServer()
        bleAdvertiser.stopAdvertising(advertiseCallback)
    }

    private fun bleStartGattServer() {
        val gattServer = bluetoothManager.openGattServer(this, gattServerCallback)
        val service = BluetoothGattService(UUID.fromString(SERVICE_UUID), BluetoothGattService.SERVICE_TYPE_PRIMARY)
        var charForRead = BluetoothGattCharacteristic(UUID.fromString(CHAR_FOR_READ_UUID),
            BluetoothGattCharacteristic.PROPERTY_READ,
            BluetoothGattCharacteristic.PERMISSION_READ)
        var charForWrite = BluetoothGattCharacteristic(UUID.fromString(CHAR_FOR_WRITE_UUID),
            BluetoothGattCharacteristic.PROPERTY_WRITE,
            BluetoothGattCharacteristic.PERMISSION_WRITE)
        var charForIndicate = BluetoothGattCharacteristic(UUID.fromString(CHAR_FOR_INDICATE_UUID),
            BluetoothGattCharacteristic.PROPERTY_INDICATE,
            BluetoothGattCharacteristic.PERMISSION_READ)
        var charConfigDescriptor = BluetoothGattDescriptor(UUID.fromString(CCC_DESCRIPTOR_UUID),
            BluetoothGattDescriptor.PERMISSION_READ or BluetoothGattDescriptor.PERMISSION_WRITE)
        charForIndicate.addDescriptor(charConfigDescriptor)

        service.addCharacteristic(charForRead)
        service.addCharacteristic(charForWrite)
        service.addCharacteristic(charForIndicate)

        val result = gattServer.addService(service)
        this.gattServer = gattServer
        eventSink?.success("addService " + when(result) {
            true -> "OK"
            false -> "fail"
        })
    }

    private fun bleStopGattServer() {
        gattServer?.close()
        gattServer = null

        eventSink?.success("gattServer closed")
        methodResult?.success("gattServer closed")
    }

    private val bluetoothManager: BluetoothManager by lazy {
        getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
    }

    private val bluetoothAdapter: BluetoothAdapter by lazy {
        bluetoothManager.adapter
    }

    //region BLE advertise
    private val bleAdvertiser by lazy {
        bluetoothAdapter.bluetoothLeAdvertiser
    }

    private val advertiseSettings = AdvertiseSettings.Builder()
        .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_BALANCED)
        .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_MEDIUM)
        .setConnectable(true)
        .build()

    private val advertiseData = AdvertiseData.Builder()
        .setIncludeDeviceName(false) // don't include name, because if name size > 8 bytes, ADVERTISE_FAILED_DATA_TOO_LARGE
        .addServiceUuid(ParcelUuid(UUID.fromString(SERVICE_UUID)))
        .build()

    private val advertiseCallback = object : AdvertiseCallback() {
        override fun onStartSuccess(settingsInEffect: AdvertiseSettings) {
            eventSink?.success("Advertise start success\n$SERVICE_UUID")
        }

        override fun onStartFailure(errorCode: Int) {
            val desc = when (errorCode) {
                ADVERTISE_FAILED_DATA_TOO_LARGE -> "\nADVERTISE_FAILED_DATA_TOO_LARGE"
                ADVERTISE_FAILED_TOO_MANY_ADVERTISERS -> "\nADVERTISE_FAILED_TOO_MANY_ADVERTISERS"
                ADVERTISE_FAILED_ALREADY_STARTED -> "\nADVERTISE_FAILED_ALREADY_STARTED"
                ADVERTISE_FAILED_INTERNAL_ERROR -> "\nADVERTISE_FAILED_INTERNAL_ERROR"
                ADVERTISE_FAILED_FEATURE_UNSUPPORTED -> "\nADVERTISE_FAILED_FEATURE_UNSUPPORTED"
                else -> ""
            }
            eventSink?.success("Advertise start failed: errorCode=$errorCode $desc")
            isAdvertising = false
        }
    }
    //endregion

    //region BLE GATT server
    private var gattServer: BluetoothGattServer? = null
    private val charForIndicate get() = gattServer?.getService(UUID.fromString(SERVICE_UUID))?.getCharacteristic(UUID.fromString(CHAR_FOR_INDICATE_UUID))
    private val subscribedDevices = mutableSetOf<BluetoothDevice>()

    private val gattServerCallback = object : BluetoothGattServerCallback() {
        override fun onConnectionStateChange(device: BluetoothDevice, status: Int, newState: Int) {
            handler.post {
                if (newState == BluetoothProfile.STATE_CONNECTED) {
                    eventSink?.success("connected \nCentral did connect")
                } else {
                    eventSink?.success("disconnected\nCentral did disconnect")
                    subscribedDevices.remove(device)
                }
            }
        }

        override fun onNotificationSent(device: BluetoothDevice, status: Int) {
            handler.post {
                eventSink?.success("onNotificationSent status=$status")
            }
        }

        override fun onCharacteristicReadRequest(device: BluetoothDevice, requestId: Int, offset: Int, characteristic: BluetoothGattCharacteristic) {
            handler.post {
                var log: String = "onCharacteristicRead offset=$offset"
                if (characteristic.uuid == UUID.fromString(CHAR_FOR_READ_UUID)) {

                    gattServer?.sendResponse(
                        device,
                        requestId,
                        BluetoothGatt.GATT_SUCCESS,
                        0,
                        sendData.toByteArray(Charsets.UTF_8)
                    )
                } else {
                    gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_FAILURE, 0, null)
                    log += "\nresponse=failure, unknown UUID\n${characteristic.uuid}"
                }
                eventSink?.success(log)
            }
        }

        override fun onCharacteristicWriteRequest(device: BluetoothDevice, requestId: Int, characteristic: BluetoothGattCharacteristic, preparedWrite: Boolean, responseNeeded: Boolean, offset: Int, value: ByteArray?) {
            handler.post {
                var log: String =
                    "onCharacteristicWrite offset=$offset responseNeeded=$responseNeeded preparedWrite=$preparedWrite"
                if (characteristic.uuid == UUID.fromString(CHAR_FOR_WRITE_UUID)) {
                    var strValue = value?.toString(Charsets.UTF_8) ?: ""
                    if (responseNeeded) {
                        gattServer?.sendResponse(
                            device,
                            requestId,
                            BluetoothGatt.GATT_SUCCESS,
                            0,
                            strValue.toByteArray(Charsets.UTF_8)
                        )
                        log += "\nresponse=success, value=\"$strValue\""
                    } else {
                        log += "\nresponse=notNeeded, value=\"$strValue\""
                    }
                } else {
                    if (responseNeeded) {
                        gattServer?.sendResponse(
                            device,
                            requestId,
                            BluetoothGatt.GATT_FAILURE,
                            0,
                            null
                        )
                        log += "\nresponse=failure, unknown UUID\n${characteristic.uuid}"
                    } else {
                        log += "\nresponse=notNeeded, unknown UUID\n${characteristic.uuid}"
                    }
                }
                eventSink?.success(log)
            }
        }

        override fun onDescriptorReadRequest(device: BluetoothDevice, requestId: Int, offset: Int, descriptor: BluetoothGattDescriptor) {
            handler.post {
                var log = "onDescriptorReadRequest"
                if (descriptor.uuid == UUID.fromString(CCC_DESCRIPTOR_UUID)) {
                    val returnValue = if (subscribedDevices.contains(device)) {
                        log += " CCCD response=ENABLE_NOTIFICATION"
                        BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
                    } else {
                        log += " CCCD response=DISABLE_NOTIFICATION"
                        BluetoothGattDescriptor.DISABLE_NOTIFICATION_VALUE
                    }
                    gattServer?.sendResponse(
                        device,
                        requestId,
                        BluetoothGatt.GATT_SUCCESS,
                        0,
                        returnValue
                    )
                } else {
                    log += " unknown uuid=${descriptor.uuid}"
                    gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_FAILURE, 0, null)
                }
                eventSink?.success(log)
            }
        }

        override fun onDescriptorWriteRequest(device: BluetoothDevice, requestId: Int, descriptor: BluetoothGattDescriptor, preparedWrite: Boolean, responseNeeded: Boolean, offset: Int, value: ByteArray) {
            handler.post {
                var strLog = "onDescriptorWriteRequest"
                if (descriptor.uuid == UUID.fromString(CCC_DESCRIPTOR_UUID)) {
                    var status = BluetoothGatt.GATT_REQUEST_NOT_SUPPORTED
                    if (descriptor.characteristic.uuid == UUID.fromString(CHAR_FOR_INDICATE_UUID)) {
                        if (Arrays.equals(value, BluetoothGattDescriptor.ENABLE_INDICATION_VALUE)) {
                            subscribedDevices.add(device)
                            status = BluetoothGatt.GATT_SUCCESS
                            strLog += ", subscribed"
                        } else if (Arrays.equals(
                                value,
                                BluetoothGattDescriptor.DISABLE_NOTIFICATION_VALUE
                            )
                        ) {
                            subscribedDevices.remove(device)
                            status = BluetoothGatt.GATT_SUCCESS
                            strLog += ", unsubscribed"
                        }
                    }
                    if (responseNeeded) {
                        gattServer?.sendResponse(device, requestId, status, 0, null)
                    }
                } else {
                    strLog += " unknown uuid=${descriptor.uuid}"
                    if (responseNeeded) {
                        gattServer?.sendResponse(
                            device,
                            requestId,
                            BluetoothGatt.GATT_FAILURE,
                            0,
                            null
                        )
                    }
                }
                eventSink?.success(strLog)
            }
        }
    }
    //endregion

    //region Permissions and Settings management
    enum class AskType {
        AskOnce,
        InsistUntilSuccess
    }

    private var activityResultHandlers = mutableMapOf<Int, (Int) -> Unit>()
    private var permissionResultHandlers = mutableMapOf<Int, (Array<out String>, IntArray) -> Unit>()

    private fun ensureBluetoothCanBeUsed(completion: (Boolean, String) -> Unit) {
//        eventSink?.success("ensureBluetoothCanBeUsed call")
        grantBluetoothPeripheralPermissions(AskType.AskOnce) { isGranted ->
            if (!isGranted) {
                completion(false, "Bluetooth permissions denied")
                return@grantBluetoothPeripheralPermissions
            }

            enableBluetooth(AskType.AskOnce) { isEnabled ->
                if (!isEnabled) {
                    completion(false, "Bluetooth OFF")
                    return@enableBluetooth
                }

                completion(true, "BLE ready for use")
            }
        }
    }

    private fun enableBluetooth(askType: AskType, completion: (Boolean) -> Unit) {
        if (bluetoothAdapter.isEnabled) {
            completion(true)
        } else {
            val intentString = BluetoothAdapter.ACTION_REQUEST_ENABLE
            val requestCode = ENABLE_BLUETOOTH_REQUEST_CODE

            // set activity result handler
            activityResultHandlers[requestCode] = { result -> Unit
                val isSuccess = result == Activity.RESULT_OK
                if (isSuccess || askType != AskType.InsistUntilSuccess) {
                    activityResultHandlers.remove(requestCode)
                    completion(isSuccess)
                } else {
                    // start activity for the request again
                    //
                }
            }
        }
    }

    private fun grantBluetoothPeripheralPermissions(askType: AskType, completion: (Boolean) -> Unit) {
//        eventSink?.success("grantBluetoothPeripheralPermissions call")
        val wantedPermissions = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            arrayOf(
                Manifest.permission.BLUETOOTH_CONNECT,
                Manifest.permission.BLUETOOTH_ADVERTISE,
            )
        } else {
            emptyArray()
        }

        if (wantedPermissions.isEmpty()|| hasPermissions(wantedPermissions)) {
            completion(true)
        } else {
                val requestCode = BLUETOOTH_ALL_PERMISSIONS_REQUEST_CODE

                // set permission result handler
                permissionResultHandlers[requestCode] = { _ /*permissions*/, grantResults ->
                    val isSuccess = grantResults.all { it == PackageManager.PERMISSION_GRANTED }
                    if (isSuccess || askType != AskType.InsistUntilSuccess) {
                        permissionResultHandlers.remove(requestCode)
                        completion(isSuccess)
                    } else {
                        // request again
                        //
                    }
                }
        }
    }

    private fun Context.hasPermissions(permissions: Array<String>): Boolean = permissions.all {
        ActivityCompat.checkSelfPermission(this, it) == PackageManager.PERMISSION_GRANTED
    }

    private fun Activity.requestPermissionArray(permissions: Array<String>, requestCode: Int) {
        ActivityCompat.requestPermissions(this, permissions, requestCode)
    }

    override fun onBind(p0: Intent?): IBinder? {
        TODO("Not yet implemented")
    }
    //endregion
}

