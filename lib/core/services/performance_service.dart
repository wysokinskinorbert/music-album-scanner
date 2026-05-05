import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// A single performance measurement.
class PerformanceMetric {
  final String name;
  final Duration duration;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  const PerformanceMetric({
    required this.name,
    required this.duration,
    required this.timestamp,
    this.metadata,
  });

  double get durationMs => duration.inMilliseconds.toDouble();
  double get durationSeconds => duration.inMilliseconds / 1000.0;
}

/// Aggregated performance report for a metric name.
class PerformanceReport {
  final String name;
  final int count;
  final Duration min;
  final Duration max;
  final Duration avg;
  final Duration p50;
  final Duration p95;
  final Duration p99;

  const PerformanceReport({
    required this.name,
    required this.count,
    required this.min,
    required this.max,
    required this.avg,
    required this.p50,
    required this.p95,
    required this.p99,
  });

  bool get isHealthy => avg.inMilliseconds < 3000; // 3s threshold

  @override
  String toString() => '\$name: avg=\${avg.inMilliseconds}ms, p95=\${p95.inMilliseconds}ms, n=\$count';
}

/// Service for tracking app performance metrics.
class PerformanceService {
  static const _boxName = 'performance_metrics';
  static const _maxMetricsPerName = 100;

  Box? _box;
  final _activeTimers = <String, Stopwatch>{};

  /// Initialize the Hive box.
  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  Box get _safeBox {
    if (_box == null || !_box!.isOpen) {
      throw StateError('PerformanceService not initialized. Call init() first.');
    }
    return _box!;
  }

  /// Start a timer for a named operation.
  void startTimer(String name) {
    _activeTimers[name] = Stopwatch()..start();
  }

  /// Stop a timer and record the metric.
  Future<PerformanceMetric?> stopTimer(String name, {Map<String, dynamic>? metadata}) async {
    final stopwatch = _activeTimers.remove(name);
    if (stopwatch == null || !stopwatch.isRunning) return null;

    stopwatch.stop();
    final metric = PerformanceMetric(
      name: name,
      duration: stopwatch.elapsed,
      timestamp: DateTime.now(),
      metadata: metadata,
    );

    await _record(metric);
    return metric;
  }

  /// Measure a synchronous operation.
  T measureSync<T>(String name, T Function() fn) {
    final sw = Stopwatch()..start();
    try {
      return fn();
    } finally {
      sw.stop();
      _record(PerformanceMetric(
        name: name,
        duration: sw.elapsed,
        timestamp: DateTime.now(),
      ));
    }
  }

  /// Measure an async operation.
  Future<T> measureAsync<T>(String name, Future<T> Function() fn) async {
    final sw = Stopwatch()..start();
    try {
      return await fn();
    } finally {
      sw.stop();
      await _record(PerformanceMetric(
        name: name,
        duration: sw.elapsed,
        timestamp: DateTime.now(),
      ));
    }
  }

  /// Record a metric directly.
  Future<void> _record(PerformanceMetric metric) async {
    final key = '\${metric.name}_\${metric.timestamp.millisecondsSinceEpoch}';
    await _safeBox.put(key, {
      'name': metric.name,
      'durationMs': metric.duration.inMilliseconds,
      'timestamp': metric.timestamp.toIso8601String(),
      'metadata': metric.metadata,
    });
    await _trim(metric.name);
  }

  /// Get all metrics for a given name.
  List<PerformanceMetric> getMetrics(String name) {
    return _safeBox.values
        .whereType<Map>()
        .where((m) => m['name'] == name)
        .map((m) => PerformanceMetric(
              name: m['name'] as String,
              duration: Duration(milliseconds: m['durationMs'] as int),
              timestamp: DateTime.parse(m['timestamp'] as String),
              metadata: m['metadata'] as Map<String, dynamic>?,
            ))
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  /// Generate a performance report for a metric name.
  PerformanceReport? getReport(String name) {
    final metrics = getMetrics(name);
    if (metrics.isEmpty) return null;

    final durations = metrics.map((m) => m.duration.inMilliseconds).toList()..sort();
    final count = durations.length;
    final totalMs = durations.reduce((a, b) => a + b);

    return PerformanceReport(
      name: name,
      count: count,
      min: Duration(milliseconds: durations.first),
      max: Duration(milliseconds: durations.last),
      avg: Duration(milliseconds: totalMs ~/ count),
      p50: Duration(milliseconds: durations[(count * 0.5).floor()]),
      p95: Duration(milliseconds: durations[(count * 0.95).floor()]),
      p99: Duration(milliseconds: durations[(count * 0.99).floor()]),
    );
  }

  /// Get all metric names.
  Set<String> getMetricNames() {
    return _safeBox.values
        .whereType<Map>()
        .map((m) => m['name'] as String)
        .toSet();
  }

  /// Get reports for all metrics.
  Map<String, PerformanceReport> getAllReports() {
    return {for (final name in getMetricNames()) name: getReport(name)!}
      ..removeWhere((_, v) => v == null);
  }

  /// Clear all metrics.
  Future<void> clear() async {
    await _safeBox.clear();
  }

  /// Trim old metrics for a specific name.
  Future<void> _trim(String name) async {
    final keys = _safeBox.keys
        .whereType<String>()
        .where((k) => k.startsWith(name))
        .toList()
      ..sort();

    if (keys.length <= _maxMetricsPerName) return;

    final toDelete = keys.take(keys.length - _maxMetricsPerName);
    for (final key in toDelete) {
      await _safeBox.delete(key);
    }
  }

  /// Print a debug summary of all metrics.
  void printDebugSummary() {
    final reports = getAllReports();
    debugPrint('=== Performance Summary ===');
    for (final report in reports.values) {
      debugPrint(report.toString());
    }
    debugPrint('===========================');
  }
}

/// Predefined metric names for consistency.
class MetricNames {
  static const appStartup = 'app_startup';
  static const cameraInit = 'camera_init';
  static const scanTotal = 'scan_total';
  static const scanBarcode = 'scan_barcode';
  static const scanOcr = 'scan_ocr';
  static const scanLabeling = 'scan_labeling';
  static const scanApiSearch = 'scan_api_search';
  static const scanOffline = 'scan_offline';
  static const hiveInit = 'hive_init';
  static const collectionLoad = 'collection_load';
  static const collectionSave = 'collection_save';
  static const imageCapture = 'image_capture';
  static const imageEdit = 'image_edit';
  static const exportCollection = 'export_collection';
  static const importCollection = 'import_collection';
}
