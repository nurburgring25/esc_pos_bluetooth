/*
 * esc_pos_bluetooth
 * Created by Andrey Ushakov
 * 
 * Copyright (c) 2019-2020. All rights reserved.
 * See LICENSE for distribution and usage details.
 */
import 'dart:async';

import 'package:collection/collection.dart';
import 'package:esc_pos_bluetooth/src/bluetooth_scan_handler.dart';
import 'package:esc_pos_bluetooth/src/print_job.dart';
import 'package:esc_pos_bluetooth/src/print_job_options.dart';
import 'package:esc_pos_bluetooth/src/printer_bluetooth.dart';
import 'package:esc_pos_bluetooth/src/printer_service.dart';

import './enums.dart';

/// Printer Bluetooth Manager
class PrinterBluetoothManager {
  final BluetoothScanHandler _bluetoothScanHandler = BluetoothScanHandler();
  final Map<String, PrinterService> _printerServices = {};

  PrinterService? get _defaultPrinterService => _printerServices.values.firstWhereOrNull((element) => element.defaultPrintService);

  Stream<List<PrinterBluetooth>> get scanResults => _bluetoothScanHandler.scanResults;

  Stream<bool> get isScanningStream => _bluetoothScanHandler.isScanningStream;

  Future<void> startScan(Duration timeout) async {
    return _bluetoothScanHandler.startScan(timeout);
  }

  Future<void> stopScan() async {
    return _bluetoothScanHandler.stopScan();
  }

  /// Add a printer and return its unique identifier (for now multiple printers are not supported because of the BluetoothManager)
  String addPrinter(final PrinterBluetooth printer, {bool defaultPrinter = true, int disconnectAfterMs = 10000}) {
    final address = printer.address;
    if (address == null) {
      throw Exception("Printer address is null");
    } else if (_printerServices.containsKey(address)) {
      return address;
    }

    if (defaultPrinter) {
      _printerServices.forEach((key, value) => value.defaultPrintService = false);
    }

    _printerServices[address] = PrinterService(
      printer,
      _bluetoothScanHandler,
      defaultPrintService: defaultPrinter,
      disconnectAfterMs: disconnectAfterMs,
    );

    return address;
  }

  void removePrinter(final PrinterBluetooth printer) {
    removePrinterById(printer.address);
  }

  void removePrinterById(final String? printerId) {
    if (printerId != null) {
      _printerServices.remove(printerId);
    }
  }

  Future<void> disconnectPrinter() {
    return _bluetoothScanHandler.disconnectImmediately();
  }

  bool isPrinting({String? printerId}) {
    final printerService = printerId != null ? _printerServices[printerId] : _defaultPrinterService;
    return printerService != null && printerService.isPrinting;
  }

  Completer<PosPrintResult> printData(List<int> bytes, {String? printerId, PrintJobOptions options = const PrintJobOptions()}) {
    final printerService = printerId != null ? _printerServices[printerId] : _defaultPrinterService;
    if (printerService == null) {
      throw Exception("No printer found or not default printer set");
    }

    final printJob = PrintJob(bytes, options);
    printerService.addJob(printJob);
    return printJob.completer;
  }
}
