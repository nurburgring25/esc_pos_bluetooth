class PrintJobOptions {
  static const AUTO_SLEEP_TIME = -1;

  final int chunkSizeBytes;
  final int queueSleepTimeMs;
  final int quantity;
  final int maxRetries;
  final int timeoutMs;

  const PrintJobOptions({
    this.chunkSizeBytes = 20,
    this.queueSleepTimeMs = AUTO_SLEEP_TIME,
    this.quantity = 1,
    this.maxRetries = 0,
    this.timeoutMs = 10000,
  });

  PrintJobOptions copyWithoutQuantity(){
    return PrintJobOptions(
        chunkSizeBytes: this.chunkSizeBytes,
        queueSleepTimeMs: this.queueSleepTimeMs,
        timeoutMs: this.timeoutMs,
        maxRetries: this.maxRetries,
        quantity: 1
    );
  }
}

