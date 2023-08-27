import 'dart:convert';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_ble_peripheral_central/flutter_ble_peripheral_central.dart';
import 'package:permission_handler/permission_handler.dart';

class BLECentralWidget extends StatefulWidget {
  @override
  _BLECentralWidgetState createState() => _BLECentralWidgetState();
}

class _BLECentralWidgetState extends State<BLECentralWidget> {
  final _flutterBlePeripheralCentralPlugin = FlutterBlePeripheralCentral();

  List<String> _events = [];
  final _eventStreamController = StreamController<String>();

  var _lifecycleState = TextEditingController();
  var _readableText= TextEditingController();
  var _writeableText= TextEditingController();
  var _indicateText= TextEditingController();

  bool _isSwitchOn = false;

  final ScrollController _scrollController = ScrollController();

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
      appBar: AppBar(
        title: Text(
          'BLE Central View',
          style: TextStyle(fontSize: 27, fontWeight: FontWeight.bold),
        ),
      ),
      body:  SingleChildScrollView(child: Column(
        children: [
          Padding(
              padding: EdgeInsets.symmetric(vertical: 5, horizontal: 10,),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                      "Lifecycle State",
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 5),
                  SizedBox(
                    width: double.infinity,
                    child: Container(
                      width: MediaQuery.of(context).size.width*0.6,
                      height: 45,
                      child: TextField(
                        controller: _lifecycleState,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey),
                          ),
                          contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12,),
                        ),
                        enabled: false,
                      ),
                    ),
                  ),
                ],
              )
          ),
          Padding(
              padding: EdgeInsets.symmetric(vertical: 5, horizontal: 10,),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Text("Advertising data"),
                  // SizedBox(height: 5),
                  SizedBox(
                    width: double.infinity,
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Container(
                            width: MediaQuery.of(context).size.width*0.75,
                            height: 45,
                            child: Padding(padding: EdgeInsets.symmetric(vertical: 8,),
                            child: Text(
                              'Scan & autoconnect',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),),
                          ),
                          SizedBox(width: 10),
                          Container(
                              width: MediaQuery.of(context).size.width*0.17,
                              height: 45,
                              child: Transform.scale(
                                scale: 1.3,
                                child: Switch(
                                  value: _isSwitchOn,
                                  activeColor: CupertinoColors.activeBlue,
                                  onChanged: (value) {
                                    setState(() {
                                      _isSwitchOn = value;
                                    });

                                    if(_isSwitchOn) {
                                      _bleScanAndConnect();
                                    } else {
                                      _bleDisconnect();
                                    }
                                  },
                                ),
                              )
                          ),
                        ]),
                  ),
                ],
              )
          ),
          Padding(
              padding: EdgeInsets.symmetric(vertical: 5, horizontal: 10,),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                      "Readable characteristic",
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 5),
                  SizedBox(
                    width: double.infinity,
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Container(
                            width: MediaQuery.of(context).size.width*0.67,
                            height: 45,
                            child: TextField(
                              controller: _readableText,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.grey),
                                ),
                                contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12,),
                              ),
                              enabled: false,
                            ),
                          ),
                          SizedBox(width: 10,),
                          Container(
                            width: MediaQuery.of(context).size.width*0.25,
                            height: 45,
                            child:
                            ElevatedButton(
                              onPressed: () async {
                                _bleReadCharacteristic();
                              },
                              child: Text('Read'),
                            ),
                          ),
                        ]
                    ),
                  ),
                ],
              )
          ),
          Padding(
              padding: EdgeInsets.symmetric(vertical: 5, horizontal: 10,),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                      "Writeable characteristic",
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 5),
                  SizedBox(
                    width: double.infinity,
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Container(
                            width: MediaQuery.of(context).size.width*0.67,
                            height: 45,
                            child: TextField(
                              controller: _writeableText,
                              decoration: InputDecoration(
                                hintText: 'Write SendData',
                                border: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.grey),
                                ),
                                contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12,),
                              ),
                            ),
                          ),
                          SizedBox(width: 10,),
                          Container(
                            width: MediaQuery.of(context).size.width*0.25,
                            height: 45,
                            child:
                            ElevatedButton(
                              onPressed: () async {
                                _bleWriteCharacteristic(_writeableText.text);
                              },
                              child: Text('Write'),
                            ),
                          ),
                        ]
                    ),
                  ),
                ],
              )
          ),
          Padding(
              padding: EdgeInsets.symmetric(vertical: 5, horizontal: 10,),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                      "Indication",
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 5),
                  SizedBox(
                    width: double.infinity,
                    child: Container(
                      width: MediaQuery.of(context).size.width*0.6,
                      height: 45,
                      child: TextField(
                        controller: _indicateText,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey),
                          ),
                          contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12,),
                        ),
                        enabled: false,
                      ),
                    ),
                  ),
                ],
              )
          ),
          Container(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 5, horizontal: 10,),
              child: Container(
                width: double.infinity,
                // height: double.infinity,
                height:  MediaQuery.of(context).size.height*0.32,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                ),
                child:
                ListView.builder(
                  controller: _scrollController,
                  itemCount: _events.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                        title: Text(
                            _events[index],
                          style: TextStyle(fontSize: 15,),
                        )
                    );
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

  void _bleScanAndConnect() async {
    StreamSubscription<dynamic> _eventSubscription;
    _clearLog();
    _eventStreamController.sink.add('Starting...');

    _eventSubscription = await _flutterBlePeripheralCentralPlugin
        .scanAndConnect()
        .listen((event) {

      _eventStreamController.sink.add('-> '+event);

      _addEvent(event);

      print('----------------------->event: ' + event);

      // if (event == 'stopAdvertising') {
      //   _eventSubscription?.cancel();
      // }
    });
  }

  void _bleReadCharacteristic() async {
    var result = await _flutterBlePeripheralCentralPlugin.bleReadCharacteristic();
    setState(() {
      _readableText.text = result!;
    });
  }

  void _bleWriteCharacteristic(String sendData) async {
    await _flutterBlePeripheralCentralPlugin.bleWriteCharacteristic(sendData);
  }

  void _bleDisconnect() async {
    await _flutterBlePeripheralCentralPlugin.bleDisconnect();
  }

  // add the event
  void _addEvent(String event) {
    setState(() {
      _events.add(event);
    });

    Map<String, dynamic> responseMap = jsonDecode(event);

    if (responseMap.containsKey('message')) {
      String message = responseMap['message'];
      print('Message: $message');
    } else if(responseMap.containsKey('state')) {
      setState(() {
        _lifecycleState.text = responseMap['state'];
      });
    } else if(responseMap.containsKey('onCharacteristicChanged')) {
      setState(() {
        _indicateText.text = responseMap['onCharacteristicChanged'];
      });
    } else {
      print('Message key not found in the JSON response.');
    }


    // Scroll to the end of the list
    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
  }

  // clear the log
  void _clearLog() {
    setState(() {
      _events.clear();
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
