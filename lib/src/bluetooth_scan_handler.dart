import 'dart:async';

import 'package:esc_pos_bluetooth/src/printer_bluetooth.dart';
import 'package:flutter_bluetooth_basic_updated/flutter_bluetooth_basic.dart';
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
    final Completer<void> scanCompleter = Completer<void>();

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
        scanCompleter.complete();
      }
      _isScanning.add(isScanningCurrent);
    });

    Future.delayed(timeout + Duration(milliseconds: 500), () {
      if (!scanCompleter.isCompleted) {
        scanCompleter.complete();
      }
    });

    // Await the completer to ensure the scan is complete
    await scanCompleter.future;
  }

  Future<void> stopScan() async {
    await _bluetoothManager.stopScan();
  }

  Future<void> disconnectImmediately() async {
    _isConnectedTo = null;
    _stateSubscription?.cancel();
    try {
      await _bluetoothManager.disconnect();
    } catch (e) {
      print(e);
    }
  }

  void disconnectIn(final Duration duration) {
    disconnecting = Timer(duration, () => disconnectImmediately());
  }

  /// Connect and return a write function to send bytes
  Future<Future Function(List<int> chunk)> connect(final PrinterBluetooth printer) async {
    if (_isConnectedTo?.device.address == printer.device.address) {
      disconnecting?.cancel();
      return (List<int> chunk) => _bluetoothManager.writeData(chunk);
    } else if (disconnecting != null) {
      disconnecting?.cancel();
      await disconnectImmediately();
    }

    // We have to rescan before connecting, otherwise we can connect only once
    await startScan(const Duration(seconds: 1));
    await stopScan();
    await _bluetoothManager.connect(printer.device);

    final Completer onReady = Completer();

    // start timeout
    final timeoutTimer = Timer(const Duration(seconds: 10), () {
      if (!onReady.isCompleted) {
        onReady.completeError("Timeout");
      }
    });

    _stateSubscription?.cancel();
    _stateSubscription = _bluetoothManager.state.listen((event) {
      switch (event) {
        case BluetoothManager.CONNECTED:
          if (!onReady.isCompleted) {
            onReady.complete();
          }
          break;
        case BluetoothManager.DISCONNECTED:
          if (!onReady.isCompleted) {
            onReady.completeError("Disconnected");
          } else {
            disconnectImmediately();
          }
          break;
        default:
          break;
      }
    });

    try {
      await onReady.future;
      timeoutTimer.cancel();
      _isConnectedTo = printer;
    } catch (e) {
      print(e);
      timeoutTimer.cancel();
      _isConnectedTo = null;
      rethrow;
    }

    return (List<int> chunk) {
      return _bluetoothManager.writeData(chunk);
    };
  }
}
