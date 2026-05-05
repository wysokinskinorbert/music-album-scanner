import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:logger/logger.dart';
import 'model/model_download_manager.dart';
import 'model/model_info.dart';

/// A single classification result from the model.
class ClassificationResult {
  final String label;
  final double confidence;

  const ClassificationResult({
    required this.label,
    required this.confidence,
  });

  bool get isConfident => confidence >= 0.75;
}

/// TFLite-based inference service for album cover recognition.
/// Handles both classification (what album is this?) and
/// embedding generation (find similar covers).
class TfliteInferenceService {
  final ModelDownloadManager _downloadManager;
  final Logger _logger = Logger(printer: PrettyPrinter(methodCount: 0));

  Interpreter? _classifier;
  Interpreter? _embedder;

  static const int _classifierInputSize = 224;
  static const int _embeddingDim = 512;

  bool _initialized = false;

  bool get isReady => _initialized && (_classifier != null || _embedder != null);
  bool get isModelLoaded => _initialized;

  TfliteInferenceService({required ModelDownloadManager downloadManager})
      : _downloadManager = downloadManager;

  // ==========================================
  // Lifecycle
  // ==========================================

  /// Initialize interpreters from downloaded model files.
  Future<bool> initialize() async {
    if (_initialized) return true;

    try {
      // Load classifier model
      final classifierPath = await _downloadManager.getModelPath(
        ModelInfo.coverRecognizer().id,
      );
      if (classifierPath != null && File(classifierPath).existsSync()) {
        _classifier = Interpreter.fromFile(
          File(classifierPath),
          options: InterpreterOptions()..threads = 4,
        );
        _logger.i('Classifier model loaded');
      }

      // Load embedding model
      final embedderPath = await _downloadManager.getModelPath(
        ModelInfo.coverEmbedding().id,
      );
      if (embedderPath != null && File(embedderPath).existsSync()) {
        _embedder = Interpreter.fromFile(
          File(embedderPath),
          options: InterpreterOptions()..threads = 4,
        );
        _logger.i('Embedding model loaded');
      }

      _initialized = _classifier != null || _embedder != null;
      return _initialized;
    } catch (e) {
      _logger.e('Failed to initialize TFLite: $e');
      return false;
    }
  }

  /// Load the classification model (alias for initialize).
  Future<bool> loadModel() async {
    return await initialize();
  }

  // ==========================================
  // Classification
  // ==========================================

  /// Classify an album cover image.
  /// Returns the top prediction with confidence.
  Future<ClassificationResult?> recognizeCover(String imagePath) async {
    if (_classifier == null) return null;

    try {
      final imageBytes = File(imagePath).readAsBytesSync();
      final image = img.decodeImage(imageBytes);
      if (image == null) return null;

      // Resize to model input size
      final resized = img.copyResize(
        image,
        width: _classifierInputSize,
        height: _classifierInputSize,
      );

      // Prepare input tensor
      final input = Float32List(_classifierInputSize * _classifierInputSize * 3);
      int idx = 0;
      for (int y = 0; y < _classifierInputSize; y++) {
        for (int x = 0; x < _classifierInputSize; x++) {
          final pixel = resized.getPixel(x, y);
          input[idx++] = pixel.r / 255.0;
          input[idx++] = pixel.g / 255.0;
          input[idx++] = pixel.b / 255.0;
        }
      }

      final inputTensor = input.reshape([1, _classifierInputSize, _classifierInputSize, 3]);
      final output = List.filled(1, List.filled(1000, 0.0))
          .reshape([1, 1000]) as List<List<double>>;

      _classifier!.run(inputTensor, output);

      // Find top prediction
      final predictions = output[0];
      int maxIdx = 0;
      double maxVal = 0.0;
      for (int i = 0; i < predictions.length; i++) {
        if (predictions[i] > maxVal) {
          maxVal = predictions[i];
          maxIdx = i;
        }
      }

      // Map index to label (in production, load label map from assets)
      return ClassificationResult(
        label: 'label_$maxIdx',
        confidence: maxVal,
      );
    } catch (e) {
      _logger.e('Classification failed: $e');
      return null;
    }
  }

  /// Classify an image and return a list of (label, confidence) pairs.
  Future<List<MapEntry<String, double>>> classify(String imagePath) async {
    final result = await recognizeCover(imagePath);
    if (result == null) return [];
    return [MapEntry(result.label, result.confidence)];
  }

  // ==========================================
  // Embeddings
  // ==========================================

  /// Generate a feature embedding for an image.
  /// Returns a 512-dimensional vector for similarity matching.
  Future<List<double>?> generateEmbedding(String imagePath) async {
    if (_embedder == null) return null;

    try {
      final imageBytes = File(imagePath).readAsBytesSync();
      final image = img.decodeImage(imageBytes);
      if (image == null) return null;

      final resized = img.copyResize(
        image,
        width: _classifierInputSize,
        height: _classifierInputSize,
      );

      final input = Float32List(_classifierInputSize * _classifierInputSize * 3);
      int idx = 0;
      for (int y = 0; y < _classifierInputSize; y++) {
        for (int x = 0; x < _classifierInputSize; x++) {
          final pixel = resized.getPixel(x, y);
          input[idx++] = pixel.r / 255.0;
          input[idx++] = pixel.g / 255.0;
          input[idx++] = pixel.b / 255.0;
        }
      }

      final inputTensor = input.reshape([1, _classifierInputSize, _classifierInputSize, 3]);
      final output = List.filled(1, List.filled(_embeddingDim, 0.0))
          .reshape([1, _embeddingDim]) as List<List<double>>;

      _embedder!.run(inputTensor, output);

      // Normalize the embedding
      final embedding = output[0];
      final norm = embedding.fold<double>(0.0, (sum, v) => sum + v * v);
      if (norm > 0) {
        final sqrtNorm = sqrt(norm);
        for (int i = 0; i < embedding.length; i++) {
          embedding[i] /= sqrtNorm;
        }
      }

      return embedding;
    } catch (e) {
      _logger.e('Embedding generation failed: $e');
      return null;
    }
  }

  // ==========================================
  // Cleanup
  // ==========================================

  void dispose() {
    _classifier?.close();
    _embedder?.close();
    _initialized = false;
  }
}
