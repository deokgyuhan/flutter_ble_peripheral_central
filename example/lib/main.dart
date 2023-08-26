import 'dart:io';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_ble_peripheral_central/flutter_ble_peripheral_central.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(MaterialApp(home: MyWidget()));
}

class MyWidget extends StatefulWidget {
  @override
  _MyWidgetState createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  final _eventStreamController = StreamController<String>();
  final _flutterBlePeripheralCentralPlugin = FlutterBlePeripheralCentral();
  List<String> _events = [];
  final indicateOfInput= TextEditingController();
  bool _isSwitchOn = false;

  @override
  void initState() {
    super.initState();
    _permissionCheck();
  }

  @override
  void dispose() {
    _eventStreamController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(title: Text('BLE Peripheral Example')),
      body:  SingleChildScrollView(child: Column(
        children: [
          Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: MediaQuery.of(context).size.width*0.77,
                  height: 45,
                  child: TextField(
                    controller: indicateOfInput,
                    decoration: InputDecoration(
                      labelText: 'Advertising data',
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey),
                      ),
                      contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12,),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Container(
                  width: MediaQuery.of(context).size.width*0.17,
                  height: 45,
                  child: Transform.scale(
                    scale: 1.3,
                    child: Switch(
                      value: _isSwitchOn,
                      onChanged: (value) {
                        setState(() {
                          _isSwitchOn = value;
                        });

                        if(_isSwitchOn) {
                          _startAdvertising();
                        } else {
                          _stopAdvertising();
                        }
                      },
                    ),
                  )
                ),
              ]),
          SizedBox(height: 10,),
          Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: MediaQuery.of(context).size.width*0.97,
                  height: 45,
                  child: TextField(
                    controller: indicateOfInput,
                    decoration: InputDecoration(
                      labelText: 'Readable characteristic',
                      // hintText: 'Input indicate value',
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey),
                      ),
                      contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12,),
                    ),
                  ),
                ),
              ]
          ),
          SizedBox(height: 10,),
          Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: MediaQuery.of(context).size.width*0.65,
                  height: 45,
                  child: TextField(
                    controller: indicateOfInput,
                    decoration: InputDecoration(
                      labelText: 'Indication',
                      hintText: 'Input indicate value',
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey),
                      ),
                      contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12,),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Container(
                  width: MediaQuery.of(context).size.width*0.3,
                  height: 45,
                  child:
                  ElevatedButton(
                    onPressed: () async {
                      await _flutterBlePeripheralCentralPlugin.sendIndicate("");
                    },
                    child: Text('Send'),
                  ),
                ),
              ]
          ),
          SizedBox(height: 10,),
          Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: MediaQuery.of(context).size.width*0.97,
                  height: 45,
                  child: TextField(
                    controller: indicateOfInput,
                    decoration: InputDecoration(
                      labelText: 'Writeable characteristic',
                      // hintText: 'Input indicate value',
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey),
                      ),
                      contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12,),
                    ),
                    enabled: false,
                  ),
                ),
              ]
          ),
          SizedBox(height: 10,),
          Container(
            child: Padding(
              padding: EdgeInsets.all(10.0),
              child: Container(
                width: double.infinity,
                // height: double.infinity,
                height:  MediaQuery.of(context).size.height*0.57,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey), // 바깥쪽 테두리 스타일 지정
                ),
                child:
                ListView.builder(
                  itemCount: _events.length,
                  itemBuilder: (context, index) {
                    return ListTile(title: Text(_events[index]));
                  },
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  StreamSubscription<String>? _eventSubscription;

  void _startAdvertising() async {
    _clearLog();
    _eventStreamController.sink.add('Starting...');

    _eventSubscription = await _flutterBlePeripheralCentralPlugin
        .startBlePeripheralService()
        .listen((event) {

      // if(!_events.contains(event)) {
      _eventStreamController.sink.add('-> '+event);
      setState(() {
        _events.add(event);
      });

      print('----------------------->event: ' + event);
      // }

      if (event == 'stopAdvertising') {
        _eventSubscription?.cancel();
      }
    }) as StreamSubscription<String>?;
  }

  void _stopAdvertising() async {
    await _flutterBlePeripheralCentralPlugin.stopBlePeripheralService();
  }

  void _clearLog() {
    setState(() {
      _events.clear(); // Clear the log
    });
  }
  void _permissionCheck() async {
    if (Platform.isAndroid) {
      var permission = await Permission.location.request();
      var bleScan = await Permission.bluetoothScan.request();
      var bleConnect = await Permission.bluetoothConnect.request();
      var bleAdvertise = await Permission.bluetoothAdvertise.request();
      var locationWhenInUse = await Permission.locationWhenInUse.request();

      print('location permission: ${permission.isGranted}');
      print('bleScan permission: ${bleScan.isGranted}');
      print('bleConnect permission: ${bleConnect.isGranted}');
      print('bleAdvertise permission: ${bleAdvertise.isGranted}');
      print('location locationWhenInUse: ${locationWhenInUse.isGranted}');
    }
  }
}
