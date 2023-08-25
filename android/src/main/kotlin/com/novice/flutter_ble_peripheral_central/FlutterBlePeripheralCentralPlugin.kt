package com.novice.flutter_ble_peripheral_central

import android.app.Activity
import android.content.Intent
import com.novice.flutter_ble_peripheral_central.ble.*
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.EventChannel

/** FlutterBlePeripheralCentralPlugin */
class FlutterBlePeripheralCentralPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
    private var channel: MethodChannel? = null
    private var methodChannelOfPeripheral: MethodChannel? = null
    private var eventChannelOfPeripheral: EventChannel? = null
    private var methodChannelOfCentral: MethodChannel? = null
    private var eventChannelOfCentral: EventChannel? = null
    private var _flutterPluginBinding: FlutterPlugin.FlutterPluginBinding? = null
    private var activity: Activity? = null

    private val methodChannelOfBLEPeripheral = "ble_peripheral/method"
    private val eventChannelOfBLEPeripheral = "ble_peripheral/event"
    private val methodChannelOfBLECentral = "ble_central/method"
    private val eventChannelOfBLECentral = "ble_central/event"

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        _flutterPluginBinding = flutterPluginBinding
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "flutter_ble_peripheral_central")
        channel?.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        if (call.method == "getPlatformVersion") {
            result.success("Android ${android.os.Build.VERSION.RELEASE}")
        } else {
            result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        methodChannelOfPeripheral?.setMethodCallHandler(null)
        eventChannelOfPeripheral?.setStreamHandler(null)
        methodChannelOfCentral?.setMethodCallHandler(null)
        eventChannelOfCentral?.setStreamHandler(null)
    }

    override fun onDetachedFromActivity() {
        activity = null
        channel = null
        methodChannelOfPeripheral = null
        eventChannelOfPeripheral = null
        methodChannelOfCentral = null
        eventChannelOfCentral = null
        _flutterPluginBinding = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        initService()
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        initService()
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
        channel = null
        methodChannelOfPeripheral = null
        eventChannelOfPeripheral = null
        methodChannelOfCentral = null
        eventChannelOfCentral = null
        _flutterPluginBinding = null
    }

    private fun initService() {
        val blePeripheralServiceIntent = Intent(activity, BlePeripheralService::class.java)
        val bleCentralServiceIntent = Intent(activity, BleCentralService::class.java)

        setupPeripheralEventChannel(blePeripheralServiceIntent)
        setupCentralEventChannel(bleCentralServiceIntent)
        setupPeripheralMethodChannel(blePeripheralServiceIntent)
        setupCentralMethodChannel(bleCentralServiceIntent)
    }

    private fun setupPeripheralEventChannel(intent: Intent) {
        eventChannelOfPeripheral = EventChannel(_flutterPluginBinding!!.binaryMessenger, eventChannelOfBLEPeripheral)
        eventChannelOfPeripheral?.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(p0: Any?, eventSink: EventChannel.EventSink) {
                EventSinkHolderOfPeripheral.eventSink = eventSink
                intent.action = "startBlePeripheralService"
                intent.putExtra("ADDITIONAL_DATA", "test")
                activity?.startService(intent)
            }

            override fun onCancel(p0: Any?) {}
        })
    }

    private fun setupCentralEventChannel(intent: Intent) {
        eventChannelOfCentral = EventChannel(_flutterPluginBinding!!.binaryMessenger, eventChannelOfBLECentral)
        eventChannelOfCentral?.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(p0: Any?, eventSink: EventChannel.EventSink) {
                EventSinkHolderOfCentral.eventSink = eventSink
                intent.action = "startCentralService"
                intent.putExtra("ADDITIONAL_DATA", "test")
                activity?.startService(intent)
            }

            override fun onCancel(p0: Any?) {}
        })
    }

    private fun setupPeripheralMethodChannel(intent: Intent) {
        methodChannelOfPeripheral = MethodChannel(_flutterPluginBinding!!.binaryMessenger, methodChannelOfBLEPeripheral)
        methodChannelOfPeripheral?.setMethodCallHandler { call, result ->
            when (call.method) {
                "sendIndicate" -> {
                    MethodResultHolderOfPeripheral.methodResult = result
                    val sendData = call.argument<String>("sendData")
                    intent.action = "sendIndicate"
                    intent.putExtra("ADDITIONAL_DATA", sendData)
                    activity?.startService(intent)
                }
                "stopBlePeripheralService" -> {
                    MethodResultHolderOfPeripheral.methodResult = result
                    intent.action = "stopBlePeripheralService"
                    activity?.startService(intent)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun setupCentralMethodChannel(intent: Intent) {
        methodChannelOfCentral = MethodChannel(_flutterPluginBinding!!.binaryMessenger, methodChannelOfBLECentral)
        methodChannelOfCentral?.setMethodCallHandler { call, result ->
            when (call.method) {
                "bleReadCharacteristic" -> {
                    MethodResultHolderOfCentral.methodResult = result
                    val sendData = call.argument<String>("sendData")
                    intent.action = "bleReadCharacteristic"
                    intent.putExtra("ADDITIONAL_DATA", sendData)
                    activity?.startService(intent)
                }
                "bleWriteCharacteristic" -> {
                    MethodResultHolderOfCentral.methodResult = result
                    intent.action = "bleWriteCharacteristic"
                    activity?.startService(intent)
                }
                "bleDisconnect" -> {
                    MethodResultHolderOfCentral.methodResult = result
                    intent.action = "bleDisconnect"
                    activity?.startService(intent)
                }
                else -> result.notImplemented()
            }
        }
    }
}
