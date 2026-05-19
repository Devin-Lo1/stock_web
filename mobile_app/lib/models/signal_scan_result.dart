import 'trade_signal.dart';

class SignalScanResult {
  const SignalScanResult({
    required this.scannedCount,
    required this.createdCount,
    required this.skippedCount,
    required this.events,
    required this.errors,
  });

  final int scannedCount;
  final int createdCount;
  final int skippedCount;
  final List<TradeSignal> events;
  final List<Map<String, Object?>> errors;

  factory SignalScanResult.fromJson(Map<String, dynamic> json) {
    return SignalScanResult(
      scannedCount: json['scanned_count'] as int? ?? 0,
      createdCount: json['created_count'] as int? ?? 0,
      skippedCount: json['skipped_count'] as int? ?? 0,
      events: (json['events'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(TradeSignal.fromSignalEvent)
          .toList(),
      errors: (json['errors'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map((item) => item.cast<String, Object?>())
          .toList(),
    );
  }
}
