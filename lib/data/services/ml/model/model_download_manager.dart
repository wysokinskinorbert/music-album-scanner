import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import 'model_info.dart';

/// Manages downloading, caching, and versioning of ML models.
class ModelDownloadManager {
  final Dio _dio;
  final Logger _logger = Logger(printer: PrettyPrinter(methodCount: 0));

  // In-memory state
  final Map<String, ModelState> _modelStates = {};
  final Map<String, ModelDownloadProgress> _downloadProgress = {};
  final Map<String, ModelInfo> _availableModels = {};

  // Callbacks for UI updates
  final void Function(String modelId, ModelState state)? onStateChanged;
  final void Function(String modelId, ModelDownloadProgress progress)?
      onProgressChanged;

  ModelDownloadManager({
    required Dio dio,
    this.onStateChanged,
    this.onProgressChanged,
  }) : _dio = dio {
    _registerModels();
  }

  // ==========================================
  // Public API
  // ==========================================

  /// List all available models and their states.
  List<ModelInfo> get availableModels => _availableModels.values.toList();

  /// Get current state of a specific model.
  ModelState getState(String modelId) => _modelStates[modelId] ?? ModelState.notDownloaded;

  /// Get download progress for a model.
  ModelDownloadProgress? getProgress(String modelId) => _downloadProgress[modelId];

  /// Check if any model is currently downloading.
  bool get isDownloading =>
      _modelStates.values.any((s) => s == ModelState.downloading);

  /// Check if offline recognition is available (at least one model ready).
  bool get isOfflineReady =>
      _modelStates.values.any((s) => s == ModelState.ready);

  /// Initialize - check what models are already downloaded.
  Future<void> initialize() async {
    for (final model in _availableModels.values) {
      final isReady = await _isModelOnDevice(model.id);
      _setModelState(model.id, isReady ? ModelState.ready : ModelState.notDownloaded);
    }
    _logger.i('ModelDownloadManager initialized. '
        'Ready: ${_modelStates.values.where((s) => s == ModelState.ready).length} / '
        '${_availableModels.length}');
  }

  /// Download a model.
  Future<bool> downloadModel(String modelId) async {
    final model = _availableModels[modelId];
    if (model == null) {
      _logger.e('Unknown model: $modelId');
      return false;
    }

    if (_modelStates[modelId] == ModelState.downloading) {
      _logger.w('Model $modelId is already downloading');
      return false;
    }

    _setModelState(modelId, ModelState.downloading);
    _updateProgress(modelId, 0, model.sizeBytes);

    try {
      final modelDir = await _getModelDirectory();
      final filePath = '${modelDir.path}/${model.id}.tflite';
      final tempPath = '$filePath.tmp';

      // Delete any previous temp file
      final tempFile = File(tempPath);
      if (await tempFile.exists()) await tempFile.delete();

      // Download with progress
      await _dio.download(
        model.url,
        tempPath,
        onReceiveProgress: (received, total) {
          _updateProgress(modelId, received, total > 0 ? total : model.sizeBytes);
        },
        options: Options(
          receiveTimeout: const Duration(minutes: 10),
          sendTimeout: const Duration(minutes: 5),
        ),
      );

      // Verify download
      final downloadedFile = File(tempPath);
      if (!await downloadedFile.exists()) {
        throw Exception('Downloaded file not found');
      }

      final fileSize = await downloadedFile.length();
      if (fileSize < 1000) {
        await downloadedFile.delete();
        throw Exception('Downloaded file too small ($fileSize bytes) - likely corrupted');
      }

      // TODO: Verify SHA256 hash when real models are available
      // final hash = await _computeSha256(tempPath);
      // if (hash != model.sha256) throw Exception('SHA256 mismatch');

      // Move from temp to final location
      final finalFile = File(filePath);
      if (await finalFile.exists()) await finalFile.delete();
      await downloadedFile.rename(filePath);

      // Save metadata
      await _saveModelMetadata(model);

      _setModelState(modelId, ModelState.ready);
      _logger.i('Model $modelId downloaded successfully (${(fileSize / 1024 / 1024).toStringAsFixed(1)} MB)');
      return true;
    } catch (e) {
      _logger.e('Failed to download model $modelId: $e');
      _setModelState(modelId, ModelState.error);
      _updateProgress(modelId, 0, model.sizeBytes, error: e.toString());
      return false;
    }
  }

  /// Delete a downloaded model.
  Future<bool> deleteModel(String modelId) async {
    try {
      final modelDir = await _getModelDirectory();
      final file = File('${modelDir.path}/$modelId.tflite');
      if (await file.exists()) await file.delete();

      // Remove metadata
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('model_version_$modelId');
      await prefs.remove('model_downloaded_at_$modelId');

      _setModelState(modelId, ModelState.notDownloaded);
      _logger.i('Model $modelId deleted');
      return true;
    } catch (e) {
      _logger.e('Failed to delete model $modelId: $e');
      return false;
    }
  }

  /// Get the file path for a ready model.
  Future<String?> getModelPath(String modelId) async {
    if (_modelStates[modelId] != ModelState.ready) return null;
    final modelDir = await _getModelDirectory();
    final file = File('${modelDir.path}/$modelId.tflite');
    return await file.exists() ? file.path : null;
  }

  /// Check for model updates.
  Future<List<ModelInfo>> checkForUpdates() async {
    final updates = <ModelInfo>[];
    final prefs = await SharedPreferences.getInstance();

    for (final model in _availableModels.values) {
      final localVersion = prefs.getString('model_version_${model.id}') ?? '0.0.0';
      if (_compareVersions(model.version, localVersion) > 0) {
        updates.add(model);
        _setModelState(model.id, ModelState.notDownloaded);
      }
    }

    _logger.i('Found ${updates.length} model updates');
    return updates;
  }

  /// Update a model to the latest version.
  Future<bool> updateModel(String modelId) async {
    _setModelState(modelId, ModelState.updating);
    final success = await downloadModel(modelId);
    if (!success) {
      _setModelState(modelId, ModelState.error);
    }
    return success;
  }

  // ==========================================
  // Private Helpers
  // ==========================================

  void _registerModels() {
    final models = [
      ModelInfo.coverRecognizer(),
      ModelInfo.coverEmbedding(),
    ];
    for (final model in models) {
      _availableModels[model.id] = model;
      _modelStates[model.id] = ModelState.notDownloaded;
    }
  }

  Future<Directory> _getModelDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final modelDir = Directory('${appDir.path}/ml_models');
    if (!await modelDir.exists()) {
      await modelDir.create(recursive: true);
    }
    return modelDir;
  }

  Future<bool> _isModelOnDevice(String modelId) async {
    final modelDir = await _getModelDirectory();
    final file = File('${modelDir.path}/$modelId.tflite');
    return await file.exists();
  }

  Future<void> _saveModelMetadata(ModelInfo model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('model_version_${model.id}', model.version);
    await prefs.setString(
      'model_downloaded_at_${model.id}',
      DateTime.now().toIso8601String(),
    );
  }

  void _setModelState(String modelId, ModelState state) {
    _modelStates[modelId] = state;
    onStateChanged?.call(modelId, state);
  }

  void _updateProgress(String modelId, int downloaded, int total, {String? error}) {
    final progress = ModelDownloadProgress(
      modelId: modelId,
      downloadedBytes: downloaded,
      totalBytes: total,
      error: error,
    );
    _downloadProgress[modelId] = progress;
    onProgressChanged?.call(modelId, progress);
  }

  int _compareVersions(String v1, String v2) {
    final parts1 = v1.split('.').map(int.parse).toList();
    final parts2 = v2.split('.').map(int.parse).toList();
    for (var i = 0; i < 3; i++) {
      final p1 = i < parts1.length ? parts1[i] : 0;
      final p2 = i < parts2.length ? parts2[i] : 0;
      if (p1 != p2) return p1.compareTo(p2);
    }
    return 0;
  }
}
