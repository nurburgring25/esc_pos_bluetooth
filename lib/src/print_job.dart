import 'dart:async';

import 'package:esc_pos_bluetooth/esc_pos_bluetooth.dart';

class PrintJob {
  final List<int> bytes;
  final PrintJobOptions options;
  final Completer<PosPrintResult> _completer = Completer(); // TODO change to stream/rx
  int _tryCount = 0;

  PrintJob(this.bytes, this.options);

  Future<void> start(final Future<PosPrintResult> Function() executor) async {
    _tryCount++;
    _completer.complete(await executor());
  }

  bool get isCompleted => _completer.isCompleted;

  Completer<PosPrintResult> get completer => _completer;

  bool get canBeRetried => _tryCount <= options.maxRetries;

  void complete(final PosPrintResult result) {
    _completer.complete(result);
  }
}