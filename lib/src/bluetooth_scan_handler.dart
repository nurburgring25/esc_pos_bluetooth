import 'dart:async';

import 'package:esc_pos_bluetooth/src/printer_bluetooth.dart';
import 'package:flutter_bluetooth_basic/flutter_bluetooth_basic.dart';
import 'package:rxdart/rxdart.dart';

class BluetoothScanHandler {
  final BluetoothManager _bluetoothManager = BluetoothManager.instance;
  final BehaviorSubject<bool> _isScanning = BehaviorSubject.seeded(false);
  final BehaviorSubject<List<PrinterBluetooth>> _scanResults = BehaviorSubject.seeded([]);
  PrinterBluetooth? _isConnectedTo;

  StreamSubscription? _scanResultsSubscription;
  StreamSubscription? _isScanningSubscription;

  Timer? disconnecting;
  StreamSubscription? _stateSubscription;

  Stream<bool> get isScanningStream => _isScanning.stream;

  Stream<List<PrinterBluetooth>> get scanResults => _scanResults.stream;

  bool get isScanning => _isScanning.value ?? false;

  Future<void> startScan(final Duration timeout) async {
    _scanResults.add(<PrinterBluetooth>[]);
    _bluetoothManager.startScan(timeout: timeout);

    _scanResultsSubscription = _bluetoothManager.scanResults.listen((devices) {
      _scanResults.add(devices.map((d) => PrinterBluetooth(d)).toList());
    });

    _isScanningSubscription = _bluetoothManager.isScanning.listen((isScanningCurrent) async {
      // If isScanning value changed (scan just stopped)
      if (isScanning && !isScanningCurrent) {
        _scanResultsSubscription!.cancel();
        _isScanningSubscription!.cancel();
      }
      _isScanning.add(isScanningCurrent);
    });
  }

  Future<void> stopScan() async {
    await _bluetoothManager.stopScan();
  }

  void disconnectIn(final Duration duration) async {
    disconnecting = Timer(duration, () async {
      await _bluetoothManager.disconnect();
      _isConnectedTo = null;
    });
  }

  /// Connect and return a write function to send bytes
  Future<Future Function(List<int> chunk)> connect(final PrinterBluetooth printer) async {
    final currentPrinter = _isConnectedTo;
    if (currentPrinter != null && currentPrinter.device.address == printer.device.address) {
      disconnecting?.cancel();
      return (List<int> chunk) {
        return _bluetoothManager.writeData(chunk);
      };
    }

    // We have to rescan before connecting, otherwise we can connect only once
    await startScan(const Duration(seconds: 1));
    await stopScan();
    await _bluetoothManager.connect(printer.device);

    final Completer onReady = Completer();

    // start timeout
    final timer = Timer(const Duration(seconds: 10), () {
      if (!onReady.isCompleted) {
        onReady.completeError("Timeout");
      }
    });

    _stateSubscription?.cancel();
    _stateSubscription = _bluetoothManager.state.listen((event) {
      print(event);
      switch (event) {
        case BluetoothManager.CONNECTED:
          onReady.complete();
          break;
        case BluetoothManager.DISCONNECTED:
          onReady.completeError("Disconnected");
          break;
        default:
          break;
      }
    });

    try {
      await onReady.future;
      _stateSubscription?.cancel();
      timer.cancel();
      _isConnectedTo = printer;
    } catch (e) {
      print(e);
      _stateSubscription?.cancel();
      timer.cancel();
      _isConnectedTo = null;
      rethrow;
    }

    return (List<int> chunk) {
      return _bluetoothManager.writeData(chunk);
    };
  }
}
