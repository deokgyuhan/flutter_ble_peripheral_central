package com.novice.flutter_ble_peripheral_central.ble

import io.flutter.plugin.common.EventChannel

object EventSinkHolderOfPeripheral {
    var eventSink: EventChannel.EventSink? = null
}
