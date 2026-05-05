import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

/// A single log entry from the recognition pipeline.
class PipelineLogEntry {
  final String scanId;
  final String stage;
  final String status; // 'started', 'success', 'failed', 'skipped'
  final DateTime timestamp;
  final Duration? duration;
  final double? confidence;
  final String? details;
  final String? errorCode;

  const PipelineLogEntry({
    required this.scanId,
    required this.stage,
    required this.status,
    required this.timestamp,
    this.duration,
    this.confidence,
    this.details,
    this.errorCode,
  });

  Map<String, dynamic> toMap() => {
    'scanId': scanId,
    'stage': stage,
    'status': status,
    'timestamp': timestamp.toIso8601String(),
    'durationMs': duration?.inMilliseconds,
    'confidence': confidence,
    'details': details,
    'errorCode': errorCode,
  };

  factory PipelineLogEntry.fromMap(Map<String, dynamic> map) =>
      PipelineLogEntry(
        scanId: map['scanId'] as String,
        stage: map['stage'] as String,
        status: map['status'] as String,
        timestamp: DateTime.parse(map['timestamp'] as String),
        duration: map['durationMs'] != null
            ? Duration(milliseconds: map['durationMs'] as int)
            : null,
        confidence: map['confidence'] as double?,
        details: map['details'] as String?,
        errorCode: map['errorCode'] as String?,
      );

  @override
  String toString() => '[\$timestamp] \$stage: \$status'
      '\${duration != null ? " (\${duration!.inMilliseconds}ms)" : ""}'
      '\${confidence != null ? " confidence=\${(confidence! * 100).toStringAsFixed(1)}%" : ""}'
      '\${errorCode != null ? " error=\$errorCode" : ""}';
}

/// Aggregated stats from pipeline logs.
class PipelineStats {
  final int totalScans;
  final int successfulScans;
  final int failedScans;
  final double successRate;
  final Duration averageDuration;
  final double averageConfidence;
  final Map<String, int> stageSuccessCounts;
  final Map<String, int> stageFailureCounts;
  final Map<String, double> stageAvgDurationMs;

  const PipelineStats({
    required this.totalScans,
    required this.successfulScans,
    required this.failedScans,
    required this.successRate,
    required this.averageDuration,
    required this.averageConfidence,
    required this.stageSuccessCounts,
    required this.stageFailureCounts,
    required this.stageAvgDurationMs,
  });

  bool get isHealthy => successRate >= 0.8;
}

/// Service for logging and analyzing recognition pipeline runs.
class DiagnosticsService {
  static const _boxName = 'pipeline_logs';
  static const _maxEntries = 500;

  Box? _box;

  /// Initialize the Hive box.
  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  Box get _safeBox {
    if (_box == null || !_box!.isOpen) {
      throw StateError('DiagnosticsService not initialized. Call init() first.');
    }
    return _box!;
  }

  /// Log a pipeline stage event.
  Future<void> log(PipelineLogEntry entry) async {
    await _safeBox.put(
      '\${entry.scanId}_\${entry.stage}_\${entry.timestamp.millisecondsSinceEpoch}',
      jsonEncode(entry.toMap()),
    );
    await _trimOldEntries();
  }

  /// Convenience: log stage started.
  Future<void> logStageStarted(String scanId, String stage) => log(
        PipelineLogEntry(
          scanId: scanId,
          stage: stage,
          status: 'started',
          timestamp: DateTime.now(),
        ),
      );

  /// Convenience: log stage success.
  Future<void> logStageSuccess(
    String scanId,
    String stage,
    Duration duration, {
    double? confidence,
    String? details,
  }) =>
      log(PipelineLogEntry(
        scanId: scanId,
        stage: stage,
        status: 'success',
        timestamp: DateTime.now(),
        duration: duration,
        confidence: confidence,
        details: details,
      ));

  /// Convenience: log stage failure.
  Future<void> logStageFailure(
    String scanId,
    String stage,
    Duration duration, {
    String? errorCode,
    String? details,
  }) =>
      log(PipelineLogEntry(
        scanId: scanId,
        stage: stage,
        status: 'failed',
        timestamp: DateTime.now(),
        duration: duration,
        errorCode: errorCode,
        details: details,
      ));

  /// Convenience: log stage skipped.
  Future<void> logStageSkipped(String scanId, String stage, {String? details}) =>
      log(PipelineLogEntry(
        scanId: scanId,
        stage: stage,
        status: 'skipped',
        timestamp: DateTime.now(),
        details: details ?? 'Not applicable',
      ));

  /// Get all logs for a specific scan.
  List<PipelineLogEntry> getLogsForScan(String scanId) {
    return _safeBox.values
        .map((v) => PipelineLogEntry.fromMap(
            jsonDecode(v as String) as Map<String, dynamic>))
        .where((e) => e.scanId == scanId)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  /// Get recent logs (last N entries).
  List<PipelineLogEntry> getRecentLogs({int limit = 50}) {
    final entries = _safeBox.values
        .map((v) => PipelineLogEntry.fromMap(
            jsonDecode(v as String) as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return entries.take(limit).toList();
  }

  /// Compute aggregated pipeline statistics.
  PipelineStats computeStats() {
    final allEntries = _safeBox.values
        .map((v) => PipelineLogEntry.fromMap(
            jsonDecode(v as String) as Map<String, dynamic>))
        .toList();

    // Group by scanId
    final scanGroups = <String, List<PipelineLogEntry>>{};
    for (final entry in allEntries) {
      scanGroups.putIfAbsent(entry.scanId, () => []).add(entry);
    }

    int successfulScans = 0;
    int failedScans = 0;
    final durations = <Duration>[];
    final confidences = <double>[];
    final stageSuccessCounts = <String, int>{};
    final stageFailureCounts = <String, int>{};
    final stageDurations = <String, List<int>>{};

    for (final entries in scanGroups.values) {
      // A scan is successful if any stage returned a high-confidence success
      final hasSuccess = entries.any(
          (e) => e.status == 'success' && (e.confidence ?? 0) >= 0.7);
      if (hasSuccess) {
        successfulScans++;
      } else {
        failedScans++;
      }

      for (final entry in entries) {
        if (entry.duration != null) {
          durations.add(entry.duration!);
          stageDurations.putIfAbsent(entry.stage, () => [])
              .add(entry.duration!.inMilliseconds);
        }
        if (entry.confidence != null) {
          confidences.add(entry.confidence!);
        }
        if (entry.status == 'success') {
          stageSuccessCounts[entry.stage] =
              (stageSuccessCounts[entry.stage] ?? 0) + 1;
        } else if (entry.status == 'failed') {
          stageFailureCounts[entry.stage] =
              (stageFailureCounts[entry.stage] ?? 0) + 1;
        }
      }
    }

    final totalScans = successfulScans + failedScans;
    final avgDuration = durations.isNotEmpty
        ? Duration(
            milliseconds:
                durations.map((d) => d.inMilliseconds).reduce((a, b) => a + b) ~/
                    durations.length)
        : Duration.zero;
    final avgConfidence = confidences.isNotEmpty
        ? confidences.reduce((a, b) => a + b) / confidences.length
        : 0.0;

    final stageAvgDurationMs = <String, double>{};
    for (final entry in stageDurations.entries) {
      stageAvgDurationMs[entry.key] =
          entry.value.reduce((a, b) => a + b) / entry.value.length;
    }

    return PipelineStats(
      totalScans: totalScans,
      successfulScans: successfulScans,
      failedScans: failedScans,
      successRate: totalScans > 0 ? successfulScans / totalScans : 0,
      averageDuration: avgDuration,
      averageConfidence: avgConfidence,
      stageSuccessCounts: stageSuccessCounts,
      stageFailureCounts: stageFailureCounts,
      stageAvgDurationMs: stageAvgDurationMs,
    );
  }

  /// Clear all logs.
  Future<void> clearLogs() async {
    await _safeBox.clear();
  }

  /// Export logs as JSON string.
  String exportLogs() {
    final entries = getRecentLogs(limit: _maxEntries);
    return jsonEncode(entries.map((e) => e.toMap()).toList());
  }

  /// Keep only the most recent [_maxEntries] entries.
  Future<void> _trimOldEntries() async {
    if (_safeBox.length <= _maxEntries) return;

    final entries = _safeBox.keys.toList()..sort();
    final toDelete = entries.take(_safeBox.length - _maxEntries);
    for (final key in toDelete) {
      await _safeBox.delete(key);
    }
  }
}
