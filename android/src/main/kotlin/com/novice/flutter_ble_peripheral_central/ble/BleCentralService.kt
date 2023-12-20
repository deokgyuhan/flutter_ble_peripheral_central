package com.novice.flutter_ble_peripheral_central.ble

import android.Manifest
import android.app.Activity
import android.app.Service
import android.bluetooth.*
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.*
import androidx.annotation.RequiresApi
import androidx.core.app.ActivityCompat
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.*

private const val ENABLE_BLUETOOTH_REQUEST_CODE = 1
private const val LOCATION_PERMISSION_REQUEST_CODE = 2
private const val BLUETOOTH_ALL_PERMISSIONS_REQUEST_CODE = 3
private const val SERVICE_UUID = "25AE1441-05D3-4C5B-8281-93D4E07420CF"
private const val CHAR_FOR_READ_UUID = "25AE1442-05D3-4C5B-8281-93D4E07420CF"
private const val CHAR_FOR_WRITE_UUID = "25AE1443-05D3-4C5B-8281-93D4E07420CF"
private const val CHAR_FOR_INDICATE_UUID = "25AE1444-05D3-4C5B-8281-93D4E07420CF"
private const val CCC_DESCRIPTOR_UUID = "00002902-0000-1000-8000-00805f9b34fb"

class BleCentralService: Service() {

    private val handler = Handler(Looper.getMainLooper())

    private var methodResult: MethodChannel.Result? = null

    private var eventSink: EventChannel.EventSink? = null
    private var sendData = ""

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == "startCentralService") {
            eventSink = EventSinkHolderOfCentral.eventSink

            val filter = IntentFilter(BluetoothAdapter.ACTION_STATE_CHANGED)
            registerReceiver(bleOnOffListener, filter)
            bleRestartLifecycle()

        } else if(intent?.action == "bleReadCharacteristic") {
            methodResult = MethodResultHolderOfCentral.methodResult
            bleReadCharacteristic()
        } else if(intent?.action == "bleWriteCharacteristic") {
            methodResult = MethodResultHolderOfCentral.methodResult
            sendData = intent?.getStringExtra("ADDITIONAL_DATA").toString()
            bleWriteCharacteristic(sendData)
        }  else if(intent?.action == "bleDisconnect") {
            methodResult = MethodResultHolderOfCentral.methodResult
            bleDisconnect()
        }

        return START_STICKY
    }

    private fun bleReadCharacteristic() {
        var gatt = connectedGatt ?: run {
            eventSink?.success("ERROR: read failed, no connected device")
            methodResult?.success("ERROR: read failed, no connected device")
            return
        }
        var characteristic = characteristicForRead ?: run {
            eventSink?.success("ERROR: read failed, characteristic unavailable $CHAR_FOR_READ_UUID")
            methodResult?.success("ERROR: read failed, characteristic unavailable $CHAR_FOR_READ_UUID")
            return
        }
        if (!characteristic.isReadable()) {
            eventSink?.success("ERROR: read failed, characteristic not readable $CHAR_FOR_READ_UUID")
            methodResult?.success("ERROR: read failed, characteristic not readable $CHAR_FOR_READ_UUID")
            return
        }
        gatt.readCharacteristic(characteristic)
    }

    private fun bleWriteCharacteristic(sendData: String) {
        var gatt = connectedGatt ?: run {
            eventSink?.success("ERROR: write failed, no connected device")
            methodResult?.success("ERROR: write failed, no connected device")
            return
        }
        var characteristic = characteristicForWrite ?:  run {
            eventSink?.success("ERROR: write failed, characteristic unavailable $CHAR_FOR_WRITE_UUID")
            methodResult?.success("ERROR: write failed, characteristic unavailable $CHAR_FOR_WRITE_UUID")
            return
        }
        if (!characteristic.isWriteable()) {
            eventSink?.success("ERROR: write failed, characteristic not writeable $CHAR_FOR_WRITE_UUID")
            methodResult?.success("ERROR: write failed, characteristic not writeable $CHAR_FOR_WRITE_UUID")
            return
        }
        characteristic.writeType = BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
        characteristic.value = sendData.toByteArray(Charsets.UTF_8)
        gatt.writeCharacteristic(characteristic)
    }

    private fun bleDisconnect() {
        unregisterReceiver(bleOnOffListener)
        bleEndLifecycle()
        eventSink?.success(toJson("BLE disconnected"))
        methodResult?.success(toJson("BLE disconnected"))
    }

    enum class BLELifecycleState {
        bluetoothNotReady,
        connectedSubscribing,
        disconnected,
        scanning,
        connecting,
        connectedDiscovering,
        connected
    }

    private var lifecycleState = BLELifecycleState.disconnected

        set(value) {
            field = value
            eventSink?.success(stateToJson(value.toString()))
        }

    private val userWantsToScanAndConnect = true //switchConnect.isChecked
    private var isScanning = false //when app is first starting, isScanning value is false
    private var connectedGatt: BluetoothGatt? = null
    private var characteristicForRead: BluetoothGattCharacteristic? = null
    private var characteristicForWrite: BluetoothGattCharacteristic? = null
    private var characteristicForIndicate: BluetoothGattCharacteristic? = null

    override fun onDestroy() {
        unregisterReceiver(bleOnOffListener)
        bleEndLifecycle()
        super.onDestroy()
    }

    override fun onBind(p0: Intent?): IBinder? {
        TODO("Not yet implemented")
    }

    private fun bleEndLifecycle() {
        safeStopBleScan()
        connectedGatt?.close()
        setConnectedGattToNull()
        lifecycleState = BLELifecycleState.disconnected
    }

    private fun setConnectedGattToNull() {
        connectedGatt = null
        characteristicForRead = null
        characteristicForWrite = null
        characteristicForIndicate = null
    }

    private fun bleRestartLifecycle() {
//        eventSink?.success("BleCentralService bleRestartLifecycle  call")
        prepareAndStartBleScan()

        handler.post {
            if (userWantsToScanAndConnect) {
                if (connectedGatt == null) {
                    prepareAndStartBleScan()
                } else {
                    connectedGatt?.disconnect()
                }
            } else {
                bleEndLifecycle()
            }
        }
    }

    private fun prepareAndStartBleScan() {
//        eventSink?.success("BleCentralService prepareAndStartBleScan  call")
        ensureBluetoothCanBeUsed() { isSuccess, message ->
            eventSink?.success(message)
            if (isSuccess) {
                safeStartBleScan()
            }
        }
    }

    private fun safeStartBleScan() {
//        eventSink?.success("BleCentralService safeStartBleScan  call")
        if (isScanning) {
            eventSink?.success(toJson("Already scanning"))
            return
        }

        val serviceFilter = scanFilter.serviceUuid?.uuid.toString()
        eventSink?.success(toJson("Starting BLE scan, filter: $serviceFilter"))

        isScanning = true
        lifecycleState = BLELifecycleState.scanning
        bleScanner.startScan(mutableListOf(scanFilter), scanSettings, scanCallback)
    }

    private fun safeStopBleScan() {
        if (!isScanning) {
            eventSink?.success(toJson("Already stopped"))
            return
        }

        eventSink?.success(toJson("Stopping BLE scan"))
        isScanning = false
        bleScanner.stopScan(scanCallback)
    }

    private fun subscribeToIndications(characteristic: BluetoothGattCharacteristic, gatt: BluetoothGatt) {
        val cccdUuid = UUID.fromString(CCC_DESCRIPTOR_UUID)
        characteristic.getDescriptor(cccdUuid)?.let { cccDescriptor ->
            if (!gatt.setCharacteristicNotification(characteristic, true)) {
                eventSink?.success(toJson("ERROR: setNotification(true) failed for ${characteristic.uuid}"))
                return
            }
            cccDescriptor.value = BluetoothGattDescriptor.ENABLE_INDICATION_VALUE
            gatt.writeDescriptor(cccDescriptor)
        }
    }

    private fun unsubscribeFromCharacteristic(characteristic: BluetoothGattCharacteristic) {
        val gatt = connectedGatt ?: return

        val cccdUuid = UUID.fromString(CCC_DESCRIPTOR_UUID)
        characteristic.getDescriptor(cccdUuid)?.let { cccDescriptor ->
            if (!gatt.setCharacteristicNotification(characteristic, false)) {
                eventSink?.success("ERROR: setNotification(false) failed for ${characteristic.uuid}")
                return
            }
            cccDescriptor.value = BluetoothGattDescriptor.DISABLE_NOTIFICATION_VALUE
            gatt.writeDescriptor(cccDescriptor)
        }
    }

    private val bluetoothAdapter: BluetoothAdapter by lazy {
        val bluetoothManager = getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        bluetoothManager.adapter
    }

    //region BLE Scanning
    private val bleScanner by lazy {
        bluetoothAdapter.bluetoothLeScanner
    }

    private val scanFilter = ScanFilter.Builder()
        .setServiceUuid(ParcelUuid(UUID.fromString(SERVICE_UUID)))
        .build()

    private val scanSettings: ScanSettings
        get() {
            return if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                scanSettingsSinceM
            } else {
                scanSettingsBeforeM
            }
        }

    private val scanSettingsBeforeM = ScanSettings.Builder()
        .setScanMode(ScanSettings.SCAN_MODE_BALANCED)
        .setReportDelay(0)
        .build()

    @RequiresApi(Build.VERSION_CODES.M)
    private val scanSettingsSinceM = ScanSettings.Builder()
        .setScanMode(ScanSettings.SCAN_MODE_BALANCED)
        .setCallbackType(ScanSettings.CALLBACK_TYPE_FIRST_MATCH)
        .setMatchMode(ScanSettings.MATCH_MODE_AGGRESSIVE)
        .setNumOfMatches(ScanSettings.MATCH_NUM_ONE_ADVERTISEMENT)
        .setReportDelay(0)
        .build()

    private val scanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) {
            val name: String? = result.scanRecord?.deviceName ?: result.device.name
            eventSink?.success(toJson("onScanResult name=$name address= ${result.device?.address}"))
            safeStopBleScan()
            lifecycleState = BLELifecycleState.connecting
            result.device.connectGatt(this@BleCentralService, false, gattCallback)
        }

        override fun onBatchScanResults(results: MutableList<ScanResult>?) {
            eventSink?.success(toJson("onBatchScanResults, ignoring"))
        }

        override fun onScanFailed(errorCode: Int) {
            eventSink?.success(toJson("onScanFailed errorCode=$errorCode"))
            safeStopBleScan()
            lifecycleState = BLELifecycleState.disconnected
            bleRestartLifecycle()
        }
    }
    //endregion

    //region BLE events, when connected
    /*
    전체 콜백 메소드와 관련있음.
    해당 메서드에서는 eventSink를 통해 Flutter로 데이터를 보내려고 시도하고 있는데, 해당 동작은 메인 스레드에서 실행되어야 함.
    오류 메시지에서도 "Methods marked with @UiThread must be executed on the main thread"라고 언급하고 있음.
    따라서 onServicesDiscovered 메서드 내에서 메인 스레드에서 실행되도록 변경
    여기서는 Handler(Looper.getMainLooper()).post를 사용하여 메인 스레드에서 실행
     */
    private val gattCallback = object : BluetoothGattCallback() {
        override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
            handler.post {
                val deviceAddress = gatt.device.address

                if (status == BluetoothGatt.GATT_SUCCESS) {
                    if (newState == BluetoothProfile.STATE_CONNECTED) {
                        // recommended on UI thread https://punchthrough.com/android-ble-guide/
                        eventSink?.success(eventToJson("onConnectionStateChange", "Connected to $deviceAddress"))
                        lifecycleState = BLELifecycleState.connectedDiscovering
                        gatt.discoverServices()
                    } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                        eventSink?.success(eventToJson("onConnectionStateChange", "Disconnected from $deviceAddress"))
                        setConnectedGattToNull()
                        gatt.close()
                        lifecycleState = BLELifecycleState.disconnected

                        bleRestartLifecycle()
                    }
                } else {
                    // TODO: random error 133 - close() and try reconnect
                    eventSink?.success(toJson("ERROR: onConnectionStateChange status=$status deviceAddress=$deviceAddress, disconnecting"))
                    setConnectedGattToNull()
                    gatt.close()
                    lifecycleState = BLELifecycleState.disconnected

                    bleRestartLifecycle()
                }
            }
        }

        /*
        해당 메서드에서는 eventSink를 통해 Flutter로 데이터를 보내려고 시도하고 있는데, 해당 동작은 메인 스레드에서 실행되어야 함.
        오류 메시지에서도 "Methods marked with @UiThread must be executed on the main thread"라고 언급하고 있음.
        따라서 onServicesDiscovered 메서드 내에서 메인 스레드에서 실행되도록 변경
        여기서는 Handler(Looper.getMainLooper()).post를 사용하여 메인 스레드에서 실행
         */
        override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
            handler.post {
                eventSink?.success(eventToJson("onServicesDiscovered","onServicesDiscovered services.count=${gatt.services.size} status=$status"))

                if (status == 129 /*GATT_INTERNAL_ERROR*/) {
                    // it should be a rare case, this article recommends to disconnect:
                    // https://medium.com/@martijn.van.welie/making-android-ble-work-part-2-47a3cdaade07
                    eventSink?.success(toJson("ERROR: status=129 (GATT_INTERNAL_ERROR), disconnecting"))
                    gatt.disconnect()
                    return@post
                }

                val service = gatt.getService(UUID.fromString(SERVICE_UUID)) ?: run {
                    eventSink?.success(toJson("ERROR: Service not found $SERVICE_UUID, disconnecting"))
                    gatt.disconnect()
                    return@post
                }

                connectedGatt = gatt
                characteristicForRead =
                    service.getCharacteristic(UUID.fromString(CHAR_FOR_READ_UUID))
                characteristicForWrite =
                    service.getCharacteristic(UUID.fromString(CHAR_FOR_WRITE_UUID))
                characteristicForIndicate =
                    service.getCharacteristic(UUID.fromString(CHAR_FOR_INDICATE_UUID))

                characteristicForIndicate?.let {
                    lifecycleState = BLELifecycleState.connectedSubscribing
                    subscribeToIndications(it, gatt)
                } ?: run {
                    eventSink?.success(toJson("WARN: characteristic not found $CHAR_FOR_INDICATE_UUID"))
                    lifecycleState = BLELifecycleState.connected
                }
            }
        }

        override fun onCharacteristicRead(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, status: Int) {
            handler.post {
                if (characteristic.uuid == UUID.fromString(CHAR_FOR_READ_UUID)) {
                    val strValue = characteristic.value.toString(Charsets.UTF_8)
                    val log = "onCharacteristicRead " + when (status) {
                        BluetoothGatt.GATT_SUCCESS -> "OK, value= $strValue"
                        BluetoothGatt.GATT_READ_NOT_PERMITTED -> "not allowed"
                        else -> "error $status"
                    }
                    eventSink?.success(eventToJson("onCharacteristicRead", strValue))
                    //bleReadCharacteristic method call result
                    methodResult?.success(strValue)
                } else {
                    eventSink?.success(eventToJson("onCharacteristicRead","onCharacteristicRead unknown uuid $characteristic.uuid"))
                    methodResult?.success(eventToJson("onCharacteristicRead","onCharacteristicRead unknown uuid $characteristic.uuid"))
                }
            }
        }

        override fun onCharacteristicWrite(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, status: Int) {
            handler.post {
                if (characteristic.uuid == UUID.fromString(CHAR_FOR_WRITE_UUID)) {
                    val log: String = "onCharacteristicWrite " + when (status) {
                        BluetoothGatt.GATT_SUCCESS -> "OK, "+characteristic.value.toString(Charsets.UTF_8)
                        BluetoothGatt.GATT_WRITE_NOT_PERMITTED -> "not allowed"
                        BluetoothGatt.GATT_INVALID_ATTRIBUTE_LENGTH -> "invalid length"
                        else -> "error $status"
                    }
                    eventSink?.success(eventToJson("onCharacteristicWrite", log))
                    methodResult?.success(eventToJson("onCharacteristicWrite", log))
                } else {
                    eventSink?.success(eventToJson("onCharacteristicWrite", "onCharacteristicWrite unknown uuid $characteristic.uuid"))
                    methodResult?.success(eventToJson("onCharacteristicWrite", "onCharacteristicWrite unknown uuid $characteristic.uuid"))
                }
            }
        }

        //peripheral indicate action event
        override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic) {
            handler.post {
                if (characteristic.uuid == UUID.fromString(CHAR_FOR_INDICATE_UUID)) {
                    val strValue = characteristic.value.toString(Charsets.UTF_8)
                    eventSink?.success(eventToJson("onCharacteristicChanged", strValue))
                } else {
                    eventSink?.success(eventToJson("onCharacteristicChanged", "onCharacteristicChanged unknown uuid $characteristic.uuid"))
                }
            }
        }

        override fun onDescriptorWrite(gatt: BluetoothGatt, descriptor: BluetoothGattDescriptor, status: Int) {
            handler.post {
                if (descriptor.characteristic.uuid == UUID.fromString(CHAR_FOR_INDICATE_UUID)) {
                    if (status == BluetoothGatt.GATT_SUCCESS) {
                        val value = descriptor.value
                        val isSubscribed = value.isNotEmpty() && value[0].toInt() != 0
                        val subscriptionText = when (isSubscribed) {
                            true -> "Subscribed"
                            false -> "Not Subscribed"
                        }
                        eventSink?.success(eventToJson("onDescriptorWrite", "onDescriptorWrite $subscriptionText"))
                    } else {
                        eventSink?.success(eventToJson("onDescriptorWrite", "ERROR: onDescriptorWrite status=$status uuid=${descriptor.uuid} char=${descriptor.characteristic.uuid}"))
                    }

                    // subscription processed, consider connection is ready for use
                    lifecycleState = BLELifecycleState.connected
                } else {
                    eventSink?.success(eventToJson("onDescriptorWrite", "onDescriptorWrite unknown uuid $descriptor.characteristic.uuid"))
                }
            }
        }
    }
    //endregion

    //region BluetoothGattCharacteristic extension
    fun BluetoothGattCharacteristic.isReadable(): Boolean =
        containsProperty(BluetoothGattCharacteristic.PROPERTY_READ)

    fun BluetoothGattCharacteristic.isWriteable(): Boolean =
        containsProperty(BluetoothGattCharacteristic.PROPERTY_WRITE)

    fun BluetoothGattCharacteristic.isWriteableWithoutResponse(): Boolean =
        containsProperty(BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE)

    fun BluetoothGattCharacteristic.isNotifiable(): Boolean =
        containsProperty(BluetoothGattCharacteristic.PROPERTY_NOTIFY)

    fun BluetoothGattCharacteristic.isIndicatable(): Boolean =
        containsProperty(BluetoothGattCharacteristic.PROPERTY_INDICATE)

    private fun BluetoothGattCharacteristic.containsProperty(property: Int): Boolean {
        return (properties and property) != 0
    }
    //endregion

    //region Permissions and Settings management
    enum class AskType {
        AskOnce,
        InsistUntilSuccess
    }

    private var activityResultHandlers = mutableMapOf<Int, (Int) -> Unit>()
    private var permissionResultHandlers = mutableMapOf<Int, (Array<out String>, IntArray) -> Unit>()
    private var bleOnOffListener = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            when (intent.getIntExtra(BluetoothAdapter.EXTRA_STATE, BluetoothAdapter.STATE_OFF)) {
                BluetoothAdapter.STATE_ON -> {
                    eventSink?.success(toJson("onReceive: Bluetooth ON"))
                    if (lifecycleState == BLELifecycleState.disconnected) {
                        bleRestartLifecycle()
                    }
                }
                BluetoothAdapter.STATE_OFF -> {
                    eventSink?.success(toJson("onReceive: Bluetooth OFF"))
                    bleEndLifecycle()
                }
            }
        }
    }

    private fun ensureBluetoothCanBeUsed(completion: (Boolean, String) -> Unit) {

//        eventSink?.success("BleCentralService ensureBluetoothCanBeUsed  call")

        grantBluetoothCentralPermissions(AskType.AskOnce) { isGranted ->
            if (!isGranted) {
                completion(false, toJson("Bluetooth permissions denied"))
                return@grantBluetoothCentralPermissions
            }

            enableBluetooth(AskType.AskOnce) { isEnabled ->
                if (!isEnabled) {
                    completion(false, toJson("Bluetooth OFF"))
                    return@enableBluetooth
                }

                completion(true, toJson("Bluetooth ON, permissions OK, ready"))
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

    private fun grantLocationPermissionIfRequired(askType: AskType, completion: (Boolean) -> Unit) {
        val wantedPermissions = arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // BLUETOOTH_SCAN permission has flag "neverForLocation", so location not needed
            completion(true)
        } else if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M ) {
            completion(true)
        } else {
            handler.post {
                val requestCode = LOCATION_PERMISSION_REQUEST_CODE

                // set permission result handler
                permissionResultHandlers[requestCode] = { permissions, grantResults ->
                    val isSuccess = grantResults.firstOrNull() != PackageManager.PERMISSION_DENIED
                    if (isSuccess || askType != AskType.InsistUntilSuccess) {
                        permissionResultHandlers.remove(requestCode)
                        completion(isSuccess)
                    } else {
                        // show motivation message again
                        //
                    }
                }
            }
        }
    }

    private fun grantBluetoothCentralPermissions(askType: AskType, completion: (Boolean) -> Unit) {
//        eventSink?.success("BleCentralService grantBluetoothCentralPermissions call")

        val wantedPermissions = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            arrayOf(
                Manifest.permission.BLUETOOTH_CONNECT,
                Manifest.permission.BLUETOOTH_SCAN,
            )
        } else {
            emptyArray()
        }

        if (wantedPermissions.isEmpty() || hasPermissions(wantedPermissions)) {
            completion(true)
        } else {
            handler.post {
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
    }

    private fun Context.hasPermissions(permissions: Array<String>): Boolean = permissions.all {
        ActivityCompat.checkSelfPermission(this, it) == PackageManager.PERMISSION_GRANTED
    }

    private fun requestPermissionArray(activity: Activity, permissions: Array<String>, requestCode: Int) {
        ActivityCompat.requestPermissions(activity, permissions, requestCode)
    }

    private fun toJson(text: String): String {
        return "{\"message\": \"$text\"}"
    }

    private fun stateToJson(text: String): String {
        return "{\"state\": \"$text\"}"
    }

    private fun eventToJson(event: String, text: String): String {
        return "{\"$event\": \"$text\"}"
    }
    //endregion
}

