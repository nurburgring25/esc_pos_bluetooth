import 'package:flutter_bluetooth_basic_updated/flutter_bluetooth_basic.dart';

/// Bluetooth printer
class PrinterBluetooth {
  PrinterBluetooth(this.device);

  final BluetoothDevice device;

  String? get name => device.name;

  String? get address => device.address;

  int? get type => device.type;
}
