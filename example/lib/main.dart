import 'dart:io';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_ble_peripheral_central/flutter_ble_peripheral_central.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _platformVersion = 'Unknown';
  final _flutterBlePeripheralCentralPlugin = FlutterBlePeripheralCentral();

  @override
  void initState() {
    super.initState();
    _permissionCheck();
    initPlatformState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    String platformVersion;
    // Platform messages may fail, so we use a try/catch PlatformException.
    // We also handle the message potentially returning null.
    try {
      platformVersion =
          await _flutterBlePeripheralCentralPlugin.getPlatformVersion() ?? 'Unknown platform version';
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion;
    });
  }

  var _eventSubscription;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Center(
          child: Column(
            children: [
              Text('Running on: $_platformVersion\n'),
              SizedBox(height: 5),
              ElevatedButton(
                  onPressed: () async {
                    _eventSubscription = _flutterBlePeripheralCentralPlugin.startBlePeripheralSearvice().listen((event) {
                      print('----------------------->start event: ${event}');

                      if(event == 'stopAdvertising') {
                        _eventSubscription?.cancel();
                      }
                    });
                  },
                  child: Text('start')
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _permissionCheck() async {
      //android의 경우 ble 권한과 함께 위치 권한 필요(android 12이상부터는 근처기기 권한까지 포함)
      if (Platform.isAndroid) {
        var permission = await Permission.location.request();
        var bleScan = await Permission.bluetoothScan.request();
        var bleConnect = await Permission.bluetoothConnect.request();
        var bleAdvertise = await Permission.bluetoothAdvertise.request();

        // var locationAlways = await Permission.locationAlways.request();
        var locationWhenInUse = await Permission.locationWhenInUse.request();

        print('location permission: ${permission.isGranted}');
        // print('location locationAlways: ${locationAlways.isGranted}');
        print('location locationWhenInUse: ${locationWhenInUse.isGranted}');

        print('bleScan permission: ${bleScan.isGranted}');
        print('bleConnect permission: ${bleConnect.isGranted}');
        print('bleAdvertise permission: ${bleAdvertise.isGranted}');
      }
  }
}
