import 'dart:io';
import 'package:test/test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:music_album_scanner/core/services/diagnostics_service.dart';

void main() {
  late DiagnosticsService service;

  setUp(() async {
    final dir = await Directory.systemTemp.createTemp('hive_test_');
    Hive.init(dir.path);
    service = DiagnosticsService();
    await service.init();
  });

  tearDown(() async {
    await Hive.deleteBoxFromDisk('pipeline_logs');
    await Hive.close();
  });

  group('logStageStarted', () {
    test('logs a started entry', () async {
      await service.logStageStarted('scan1', 'barcode');
      final logs = service.getLogsForScan('scan1');
      expect(logs.length, 1);
      expect(logs.first.stage, 'barcode');
      expect(logs.first.status, 'started');
    });
  });

  group('logStageSuccess', () {
    test('logs a success entry with duration and confidence', () async {
      await service.logStageSuccess(
        'scan1', 'barcode', const Duration(milliseconds: 150),
        confidence: 0.95, details: 'EAN-13 detected',
      );
      final logs = service.getLogsForScan('scan1');
      expect(logs.first.status, 'success');
      expect(logs.first.duration!.inMilliseconds, 150);
      expect(logs.first.confidence, 0.95);
      expect(logs.first.details, 'EAN-13 detected');
    });
  });

  group('logStageFailure', () {
    test('logs a failure entry with error code', () async {
      await service.logStageFailure(
        'scan2', 'ocr', const Duration(milliseconds: 200),
        errorCode: 'NO_TEXT', details: 'Image too blurry',
      );
      final logs = service.getLogsForScan('scan2');
      expect(logs.first.status, 'failed');
      expect(logs.first.errorCode, 'NO_TEXT');
    });
  });

  group('logStageSkipped', () {
    test('logs a skipped entry', () async {
      await service.logStageSkipped('scan3', 'offline', details: 'No model');
      final logs = service.getLogsForScan('scan3');
      expect(logs.first.status, 'skipped');
      expect(logs.first.details, 'No model');
    });
  });

  group('getLogsForScan', () {
    test('returns entries sorted by timestamp', () async {
      await service.logStageStarted('scan1', 'barcode');
      await service.logStageSuccess('scan1', 'barcode', const Duration(milliseconds: 100));
      await service.logStageStarted('scan1', 'ocr');
      final logs = service.getLogsForScan('scan1');
      expect(logs.length, 3);
      expect(logs[0].stage, 'barcode');
      expect(logs[0].status, 'started');
    });

    test('returns empty for unknown scan', () {
      final logs = service.getLogsForScan('unknown');
      expect(logs, isEmpty);
    });

    test('does not mix scans', () async {
      await service.logStageStarted('scan1', 'barcode');
      await service.logStageStarted('scan2', 'ocr');
      expect(service.getLogsForScan('scan1').length, 1);
      expect(service.getLogsForScan('scan2').length, 1);
    });
  });

  group('getRecentLogs', () {
    test('returns most recent entries up to limit', () async {
      for (int i = 0; i < 10; i++) {
        await service.logStageStarted('scan\$i', 'barcode');
      }
      final recent = service.getRecentLogs(limit: 5);
      expect(recent.length, 5);
    });

    test('returns sorted newest first', () async {
      await service.logStageStarted('scan1', 'barcode');
      await service.logStageStarted('scan2', 'ocr');
      final recent = service.getRecentLogs(limit: 10);
      expect(recent.first.scanId, 'scan2');
    });
  });

  group('computeStats', () {
    test('empty stats when no logs', () {
      final stats = service.computeStats();
      expect(stats.totalScans, 0);
      expect(stats.successRate, 0);
    });

    test('computes success rate correctly', () async {
      // Successful scan: barcode match with high confidence
      await service.logStageStarted('scan1', 'barcode');
      await service.logStageSuccess('scan1', 'barcode', const Duration(milliseconds: 100), confidence: 0.95);
      // Failed scan: no high confidence
      await service.logStageStarted('scan2', 'ocr');
      await service.logStageFailure('scan2', 'ocr', const Duration(milliseconds: 200));
      final stats = service.computeStats();
      expect(stats.totalScans, 2);
      expect(stats.successfulScans, 1);
      expect(stats.failedScans, 1);
      expect(stats.successRate, closeTo(0.5, 0.01));
    });

    test('computes average confidence', () async {
      await service.logStageSuccess('scan1', 'barcode', const Duration(milliseconds: 100), confidence: 0.9);
      await service.logStageSuccess('scan2', 'barcode', const Duration(milliseconds: 150), confidence: 0.8);
      final stats = service.computeStats();
      expect(stats.averageConfidence, closeTo(0.85, 0.01));
    });

    test('computes stage success/failure counts', () async {
      await service.logStageSuccess('scan1', 'barcode', const Duration(milliseconds: 100));
      await service.logStageSuccess('scan2', 'barcode', const Duration(milliseconds: 100));
      await service.logStageFailure('scan3', 'ocr', const Duration(milliseconds: 200));
      final stats = service.computeStats();
      expect(stats.stageSuccessCounts['barcode'], 2);
      expect(stats.stageFailureCounts['ocr'], 1);
    });

    test('isHealthy when success rate >= 80%', () async {
      // 4 success, 1 fail = 80%
      for (int i = 0; i < 4; i++) {
        await service.logStageSuccess('success\$i', 'barcode', const Duration(milliseconds: 100), confidence: 0.95);
      }
      await service.logStageFailure('fail1', 'ocr', const Duration(milliseconds: 200));
      final stats = service.computeStats();
      expect(stats.successRate, closeTo(0.8, 0.01));
      expect(stats.isHealthy, isTrue);
    });
  });

  group('clearLogs', () {
    test('removes all entries', () async {
      await service.logStageStarted('scan1', 'barcode');
      await service.logStageStarted('scan2', 'ocr');
      await service.clearLogs();
      expect(service.getRecentLogs(), isEmpty);
    });
  });

  group('exportLogs', () {
    test('returns valid JSON', () async {
      await service.logStageStarted('scan1', 'barcode');
      final json = service.exportLogs();
      expect(json, contains('barcode'));
      expect(json, contains('scan1'));
    });
  });

  group('trim old entries', () {
    test('trims to max 500 entries', () async {
      for (int i = 0; i < 510; i++) {
        await service.logStageStarted('scan\$i', 'barcode');
      }
      final logs = service.getRecentLogs(limit: 1000);
      expect(logs.length, lessThanOrEqualTo(500));
    });
  });
}
