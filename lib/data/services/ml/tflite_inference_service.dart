import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:logger/logger.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'ml/model/model_download_manager.dart';
import 'ml/model/model_info.dart';

/// Result from TFLite cover recognition.
class CoverRecognitionResult {
  final String label;
  final double confidence;
  final List<RecognitionCandidate> candidates;

  const CoverRecognitionResult({
    required this.label,
    required this.confidence,
    this.candidates = const [],
  });

  bool get isConfident => confidence >= 0.5;

  @override
  String toString() => 'CoverResult($label, ${(confidence * 100).toStringAsFixed(1)}%)';
}

/// A candidate match from the model.
class RecognitionCandidate {
  final String label;
  final double confidence;

  const RecognitionCandidate({required this.label, required this.confidence});
}

/// Runs TFLite inference on album cover images.
class TfliteInferenceService {
  final ModelDownloadManager _downloadManager;
  final Logger _logger = Logger(printer: PrettyPrinter(methodCount: 0));

  Interpreter? _recognizerInterpreter;
  Interpreter? _embeddingInterpreter;
  bool _isInitialized = false;

  // Model input specs (MobileNet)
  static const int _inputSize = 224;
  static const int _embeddingDim = 512;

  TfliteInferenceService({required ModelDownloadManager downloadManager})
      : _downloadManager = downloadManager;

  bool get isReady => _isInitialized;

  // ==========================================
  // Lifecycle
  // ==========================================

  /// Initialize interpreters from downloaded models.
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Load cover recognizer model
      final recognizerPath = await _downloadManager.getModelPath(
        ModelInfo.coverRecognizer().id,
      );
      if (recognizerPath != null) {
        _recognizerInterpreter = Interpreter.fromFile(File(recognizerPath));
        _logger.i('Cover recognizer model loaded');
      }

      // Load embedding model
      final embeddingPath = await _downloadManager.getModelPath(
        ModelInfo.coverEmbedding().id,
      );
      if (embeddingPath != null) {
        _embeddingInterpreter = Interpreter.fromFile(File(embeddingPath));
        _logger.i('Cover embedding model loaded');
      }

      _isInitialized = _recognizerInterpreter != null;
      return _isInitialized;
    } catch (e) {
      _logger.e('Failed to initialize TFLite: $e');
      _isInitialized = false;
      return false;
    }
  }

  /// Dispose interpreters.
  void dispose() {
    _recognizerInterpreter?.close();
    _embeddingInterpreter?.close();
    _recognizerInterpreter = null;
    _embeddingInterpreter = null;
    _isInitialized = false;
  }

  // ==========================================
  // Recognition
  // ==========================================

  /// Recognize an album cover from an image file.
  Future<CoverRecognitionResult?> recognizeCover(String imagePath) async {
    if (!_isInitialized || _recognizerInterpreter == null) {
      _logger.w('Recognizer not initialized');
      return null;
    }

    try {
      // Load and preprocess image
      final imageData = await _loadAndPreprocess(imagePath);
      if (imageData == null) return null;

      // Run inference
      final output = List.filled(1, List.filled(1000, 0.0)) as List<List<double>>;
      _recognizerInterpreter!.run(imageData, output);

      // Parse results
      final results = _parseTopK(output[0], k: 5);
      if (results.isEmpty) return null;

      return CoverRecognitionResult(
        label: results.first.label,
        confidence: results.first.confidence,
        candidates: results,
      );
    } catch (e) {
      _logger.e('Recognition failed: $e');
      return null;
    }
  }

  /// Generate embedding vector from cover image.
  Future<List<double>?> generateEmbedding(String imagePath) async {
    if (_embeddingInterpreter == null) {
      _logger.w('Embedding model not loaded');
      return null;
    }

    try {
      final imageData = await _loadAndPreprocess(imagePath);
      if (imageData == null) return null;

      final output = List.filled(1, List.filled(_embeddingDim, 0.0))
          as List<List<double>>;
      _embeddingInterpreter!.run(imageData, output);

      return output[0];
    } catch (e) {
      _logger.e('Embedding generation failed: $e');
      return null;
    }
  }

  // ==========================================
  // Preprocessing
  // ==========================================

  /// Load image file and preprocess to model input format.
  Future<List<List<List<List<double>>>>?> _loadAndPreprocess(
    String imagePath,
  ) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) return null;

      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) return null;

      // Resize to model input size
      final resized = img.copyResize(image, width: _inputSize, height: _inputSize);

      // Normalize to [0, 1] and format as [1][224][224][3]
      final input = List.generate(
        1,
        (_) => List.generate(
          _inputSize,
          (y) => List.generate(
            _inputSize,
            (x) {
              final pixel = resized.getPixel(x, y);
              return [
                (pixel.r) / 255.0,
                (pixel.g) / 255.0,
                (pixel.b) / 255.0,
              ];
            },
          ),
        ),
      );

      return input;
    } catch (e) {
      _logger.e('Image preprocessing failed: $e');
      return null;
    }
  }

  /// Parse top-K results from model output.
  List<RecognitionCandidate> _parseTopK(List<double> output, {int k = 5}) {
    final indexed = output.asMap().entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return indexed.take(k).map((entry) {
      return RecognitionCandidate(
        label: 'class_${entry.key}', // Will map to real album names via labels file
        confidence: entry.value,
      );
    }).toList();
  }
}
