import 'dart:async';
import 'dart:convert' show utf8;
import 'dart:io';

import 'package:control_pad/control_pad.dart';
import 'package:control_pad/models/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue/flutter_blue.dart';

Future<void> main() async {
  await SystemChrome.setPreferredOrientations(
      [DeviceOrientation.landscapeRight, DeviceOrientation.landscapeLeft]);

  runApp(MainScreen());
}

class MainScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Joypad with BLE',
      debugShowCheckedModeBanner: false,
      home: JoyPad(),
      theme: ThemeData.dark(),
    );
  }
}

class JoyPad extends StatefulWidget {
  @override
  _JoyPadState createState() => _JoyPadState();
}

class _JoyPadState extends State<JoyPad> {
  final String SERVICE_UUID = "6e400001-b5a3-f393-e0a9-e50e24dcca9e";
  final String CHARACTERISTIC_UUID = "6e400002-b5a3-f393-e0a9-e50e24dcca9e";
  final String TARGET_DEVICE_NAME = "Bluefruit52";

  FlutterBlue flutterBlue = FlutterBlue.instance;
  StreamSubscription<ScanResult> scanSubScription;

  BluetoothDevice targetDevice;
  BluetoothCharacteristic targetCharacteristic;

  String connectionText = "";

  @override
  void initState() {
    super.initState();
    startScan();
  }

  startScan() {
    setState(() {
      connectionText = "Start Scanning";
    });

    scanSubScription = flutterBlue.scan().listen((scanResult) {
      if (scanResult.device.name == TARGET_DEVICE_NAME) {
        print('DEVICE found');
        stopScan();
        setState(() {
          connectionText = "Found Target Device";
        });

        targetDevice = scanResult.device;
        connectToDevice();
      }
    }, onDone: () => stopScan());
  }

  stopScan() {
    scanSubScription?.cancel();
    scanSubScription = null;
  }

  connectToDevice() async {
    if (targetDevice == null) return;

    setState(() {
      connectionText = "Device Connecting";
    });

    await targetDevice.connect();
    print('DEVICE CONNECTED');
    setState(() {
      connectionText = "Device Connected";
    });

    discoverServices();
  }

  disconnectFromDevice() {
    if (targetDevice == null) return;

    targetDevice.disconnect();

    setState(() {
      connectionText = "Device Disconnected";
    });
  }

  discoverServices() async {
    if (targetDevice == null) return;

    List<BluetoothService> services = await targetDevice.discoverServices();
    services.forEach((service) {
      // do something with service
      if (service.uuid.toString() == SERVICE_UUID) {
        service.characteristics.forEach((characteristic) {
          if (characteristic.uuid.toString() == CHARACTERISTIC_UUID) {
            targetCharacteristic = characteristic;
            //writeData("Hi there, ESP32!!");
            setState(() {
              connectionText = "All Ready with ${targetDevice.name}";
            });
          }
        });
      }
    });
  }

  writeData(String data) {
    if (targetCharacteristic == null) return;

    List<int> bytes = utf8.encode(data);
    targetCharacteristic.write(bytes);
    sleep(const Duration(milliseconds: 4));
  }

  @override
  Widget build(BuildContext context) {
    JoystickDirectionCallback onDirectionChanged(
        double degrees, double distance) {
      int y = (999 * degrees / 360).round();
      int x = (999 * distance).round();
      String data = "sx${x}y$y";

      if (degrees >= 270 ||degrees <= 90) {
        data = "dx${x}y1e";
      } else {
        data = "dx${x}y0e";
      }
      writeData(data);
    }

    PadButtonPressedCallback padBUttonPressedCallback(
        int buttonIndex, Gestures gesture) {
      String data = "";
      if (buttonIndex == 1) {
        data = "tx074y190e";
      }
      if (buttonIndex == 3) {
        data = "tx900y800e";
      }
      print(data);
      writeData(data);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(connectionText),
      ),
      body: Container(
        child: targetCharacteristic == null
            ? Center(
                child: Text(
                  "Waiting...",
                  style: TextStyle(fontSize: 24, color: Colors.red),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  JoystickView(
                    onDirectionChanged: onDirectionChanged,
                  ),
                  PadButtonsView(
                    padButtonPressedCallback: padBUttonPressedCallback,
                  ),
                ],
              ),
      ),
    );
  }
}
