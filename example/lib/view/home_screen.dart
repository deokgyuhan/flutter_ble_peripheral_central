import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ble_peripheral_central_example/widget/ble_central_widget.dart';
import 'package:flutter_ble_peripheral_central_example/widget/ble_peripheral_widget.dart';


class HomeScreen extends StatelessWidget {

  HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
            title: Text(
                'BLE Peripheral & Central',
              style: TextStyle(fontSize: 27, fontWeight: FontWeight.bold,),
            )
        ),
        body: Column(
            children: [
              Text(
                  'Example',
                style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold,),
              ),
              SizedBox(height: MediaQuery.of(context).size.height*0.4),
              Center(
                child: Container(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) {
                                return BLEPeripheralWidget();
                              }),
                            );
                          },
                          icon: Icon(
                              Icons.login_sharp,
                              size: MediaQuery.of(context).size.width * 0.07,
                              color: Colors.white
                          ),
                          label: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 50),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: MediaQuery.of(context).size.width * 0.05,
                              fontWeight: FontWeight.bold,
                            ),
                            child: Text('BLE Peripheral View'),
                          ),
                          style: ElevatedButton.styleFrom(
                            primary: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: EdgeInsets.symmetric(
                              vertical: MediaQuery.of(context).size.height * 0.02,
                              horizontal: MediaQuery.of(context).size.width * 0.08,
                            ),
                          ),
                        ),
                        SizedBox(height: 10,),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) {
                                return BLECentralWidget();
                              }),
                            );
                          },
                          icon: Icon(
                              Icons.login_sharp,
                              size: MediaQuery.of(context).size.width * 0.07,
                              color: Colors.white
                          ),
                          label: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 50),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: MediaQuery.of(context).size.width * 0.05,
                              fontWeight: FontWeight.bold,
                            ),
                            child: Text('BLE Central View      '),
                          ),
                          style: ElevatedButton.styleFrom(
                            primary: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: EdgeInsets.symmetric(
                              vertical: MediaQuery.of(context).size.height * 0.02,
                              horizontal: MediaQuery.of(context).size.width * 0.08,
                            ),
                          ),
                        ),
                      ]
                  ),
                ),
              ),
            ],
        ),
    );
  }
}

