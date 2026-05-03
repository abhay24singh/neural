import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleService {
  final String targetDeviceName = "NeuralGate";
  final String serviceUuid = "6e400001-b5a3-f393-e0a9-e50e24dcca9e";
  final String txCharacteristicUuid = "6e400003-b5a3-f393-e0a9-e50e24dcca9e"; // NOTIFY
  final String rxCharacteristicUuid = "6e400002-b5a3-f393-e0a9-e50e24dcca9e"; // WRITE

  BluetoothDevice? _targetDevice;
  BluetoothCharacteristic? _txCharacteristic;
  BluetoothCharacteristic? _rxCharacteristic;

  final StreamController<double> _dataController = StreamController<double>.broadcast();
  final StreamController<bool> _connectionController = StreamController<bool>.broadcast();

  Stream<double> get signalStream => _dataController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;

  bool _isConnecting = false;
  Timer? _reconnectTimer;
  StreamSubscription<BluetoothConnectionState>? _connectionStateSubscription;
  StreamSubscription<List<ScanResult>>? _scanSubscription;

  BleService() {
    _startScan();
  }

  void _startScan() async {
    if (_isConnecting) return;

    print("BLE: Starting scan for $targetDeviceName...");
    
    // Listen to scan results
    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult r in results) {
        if (r.device.platformName == targetDeviceName || r.advertisementData.advName == targetDeviceName) {
          print("BLE: Found $targetDeviceName! Stopping scan.");
          FlutterBluePlus.stopScan();
          _connectToDevice(r.device);
          break;
        }
      }
    });

    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
    } catch (e) {
      print("BLE: Scan failed - $e");
      _handleReconnect();
    }
  }

  void _connectToDevice(BluetoothDevice device) async {
    _targetDevice = device;
    _isConnecting = true;

    // Listen to connection state
    _connectionStateSubscription = device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.connected) {
        print("BLE: Connected to $targetDeviceName");
        _connectionController.add(true);
        _discoverServices(device);
        _isConnecting = false;
      } else if (state == BluetoothConnectionState.disconnected) {
        print("BLE: Disconnected from $targetDeviceName");
        _connectionController.add(false);
        _targetDevice = null;
        _isConnecting = false;
        _handleReconnect();
      }
    });

    try {
      await device.connect(autoConnect: false);
    } catch (e) {
      print("BLE: Connection failed - $e");
      _isConnecting = false;
      _handleReconnect();
    }
  }

  void _discoverServices(BluetoothDevice device) async {
    try {
      List<BluetoothService> services = await device.discoverServices();
      for (var service in services) {
        if (service.uuid.toString() == serviceUuid) {
          for (var characteristic in service.characteristics) {
            if (characteristic.uuid.toString() == txCharacteristicUuid) {
              _txCharacteristic = characteristic;
              await _subscribeToNotifications();
            } else if (characteristic.uuid.toString() == rxCharacteristicUuid) {
              _rxCharacteristic = characteristic;
            }
          }
        }
      }
    } catch (e) {
      print("BLE: Service discovery failed - $e");
    }
  }

  Future<void> _subscribeToNotifications() async {
    if (_txCharacteristic == null) return;
    try {
      await _txCharacteristic!.setNotifyValue(true);
      _txCharacteristic!.onValueReceived.listen((value) {
        // Value is sent as a string of double, e.g. "123.45" -> ASCII bytes
        String stringValue = String.fromCharCodes(value);
        double? focusPower = double.tryParse(stringValue);
        if (focusPower != null) {
          _dataController.add(focusPower);
        }
      });
      print("BLE: Subscribed to notifications");
    } catch (e) {
      print("BLE: Notification subscription failed - $e");
    }
  }

  Future<void> sendThreshold(double threshold) async {
    if (_rxCharacteristic == null || _targetDevice == null) return;
    try {
      // Send as string format to match Arduino code
      String valueString = threshold.toStringAsFixed(1);
      await _rxCharacteristic!.write(valueString.codeUnits, withoutResponse: false);
      print("BLE: Sent threshold $valueString");
    } catch (e) {
      print("BLE: Send threshold failed - $e");
    }
  }

  void _handleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      print("BLE: Attempting to reconnect...");
      _startScan();
    });
  }

  void restartScan() {
    print("BLE: Manual restart scan triggered.");
    _isConnecting = false;
    _reconnectTimer?.cancel();
    _targetDevice?.disconnect();
    _targetDevice = null;
    FlutterBluePlus.stopScan();
    _startScan();
  }

  void dispose() {
    _reconnectTimer?.cancel();
    _scanSubscription?.cancel();
    _connectionStateSubscription?.cancel();
    _targetDevice?.disconnect();
    _dataController.close();
    _connectionController.close();
  }
}
