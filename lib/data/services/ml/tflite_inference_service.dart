     1|import 'dart:io';
     2|import 'dart:math';
     3|import 'dart:typed_data';
     4|import 'package:image/image.dart' as img;
     5|import 'package:tflite_flutter/tflite_flutter.dart';
     6|import 'package:logger/logger.dart';
     7|import 'model/model_download_manager.dart';
     8|import 'model/model_info.dart';
     9|
    10|/// A single classification result from the model.
    11|class ClassificationResult {
    12|  final String label;
    13|  final double confidence;
    14|
    15|  const ClassificationResult({
    16|    required this.label,
    17|    required this.confidence,
    18|  });
    19|
    20|  bool get isConfident => confidence >= 0.75;
    21|}
    22|
    23|/// TFLite-based inference service for album cover recognition.
    24|/// Handles both classification (what album is this?) and
    25|/// embedding generation (find similar covers).
    26|class TfliteInferenceService {
    27|  final ModelDownloadManager _downloadManager;
    28|  final Logger _logger = Logger(printer: PrettyPrinter(methodCount: 0));
    29|
    30|  Interpreter? _classifier;
    31|  Interpreter? _embedder;
    32|
    33|  static const int _classifierInputSize = 224;
    34|  static const int _embeddingDim = 512;
    35|
    36|  bool _initialized = false;
    37|
    38|  bool get isReady => _initialized && (_classifier != null || _embedder != null);
    39|
    40|  TfliteInferenceService({required ModelDownloadManager downloadManager})
    41|      : _downloadManager = downloadManager;
    42|
    43|  // ==========================================
    44|  // Lifecycle
    45|  // ==========================================
    46|
    47|  /// Initialize interpreters from downloaded model files.
    48|  Future<bool> initialize() async {
    49|    if (_initialized) return true;
    50|
    51|    try {
    52|      // Load classifier model
    53|      final classifierPath = _downloadManager.getModelPath(
    54|        ModelInfo.coverRecognizer().id,
    55|      );
    56|      if (classifierPath != null && File(classifierPath).existsSync()) {
    57|        _classifier = Interpreter.fromFile(
    58|          File(classifierPath),
    59|          options: InterpreterOptions()..threads = 4,
    60|        );
    61|        _logger.i('Classifier model loaded');
    62|      }
    63|
    64|      // Load embedding model
    65|      final embedderPath = _downloadManager.getModelPath(
    66|        ModelInfo.coverEmbedding().id,
    67|      );
    68|      if (embedderPath != null && File(embedderPath).existsSync()) {
    69|        _embedder = Interpreter.fromFile(
    70|          File(embedderPath),
    71|          options: InterpreterOptions()..threads = 4,
    72|        );
    73|        _logger.i('Embedding model loaded');
    74|      }
    75|
    76|      _initialized = _classifier != null || _embedder != null;
    77|      return _initialized;
    78|    } catch (e) {
    79|      _logger.e('Failed to initialize TFLite: $e');
    80|      return false;
    81|    }
    82|  }
    83|
    84|  // ==========================================
    85|  // Classification
    86|  // ==========================================
    87|
    88|  /// Classify an album cover image.
    89|  /// Returns the top prediction with confidence.
    90|  Future<ClassificationResult?> recognizeCover(String imagePath) async {
    91|    if (_classifier == null) return null;
    92|
    93|    try {
    94|      final imageBytes = File(imagePath).readAsBytesSync();
    95|      final image = img.decodeImage(imageBytes);
    96|      if (image == null) return null;
    97|
    98|      // Resize to model input size
    99|      final resized = img.copyResize(
   100|        image,
   101|        width: _classifierInputSize,
   102|        height: _classifierInputSize,
   103|      );
   104|
   105|      // Prepare input tensor
   106|      final input = Float32List(_classifierInputSize * _classifierInputSize * 3);
   107|      int idx = 0;
   108|      for (int y = 0; y < _classifierInputSize; y++) {
   109|        for (int x = 0; x < _classifierInputSize; x++) {
   110|          final pixel = resized.getPixel(x, y);
   111|          input[idx++] = pixel.r / 255.0;
   112|          input[idx++] = pixel.g / 255.0;
   113|          input[idx++] = pixel.b / 255.0;
   114|        }
   115|      }
   116|
   117|      final inputTensor = input.reshape([1, _classifierInputSize, _classifierInputSize, 3]);
   118|      final output = List.filled(1, List.filled(1000, 0.0))
   119|          .reshape([1, 1000]) as List<List<double>>;
   120|
   121|      _classifier!.run(inputTensor, output);
   122|
   123|      // Find top prediction
   124|      final predictions = output[0];
   125|      int maxIdx = 0;
   126|      double maxVal = 0.0;
   127|      for (int i = 0; i < predictions.length; i++) {
   128|        if (predictions[i] > maxVal) {
   129|          maxVal = predictions[i];
   130|          maxIdx = i;
   131|        }
   132|      }
   133|
   134|      // Map index to label (in production, load label map from assets)
   135|      return ClassificationResult(
   136|        label: 'label_$maxIdx',
   137|        confidence: maxVal,
   138|      );
   139|    } catch (e) {
   140|      _logger.e('Classification failed: $e');
   141|      return null;
   142|    }
   143|  }
   144|
   145|  // ==========================================
   146|  // Embeddings
   147|  // ==========================================
   148|
   149|  /// Generate a feature embedding for an image.
   150|  /// Returns a 512-dimensional vector for similarity matching.
   151|  Future<List<double>?> generateEmbedding(String imagePath) async {
   152|    if (_embedder == null) return null;
   153|
   154|    try {
   155|      final imageBytes = File(imagePath).readAsBytesSync();
   156|      final image = img.decodeImage(imageBytes);
   157|      if (image == null) return null;
   158|
   159|      final resized = img.copyResize(
   160|        image,
   161|        width: _classifierInputSize,
   162|        height: _classifierInputSize,
   163|      );
   164|
   165|      final input = Float32List(_classifierInputSize * _classifierInputSize * 3);
   166|      int idx = 0;
   167|      for (int y = 0; y < _classifierInputSize; y++) {
   168|        for (int x = 0; x < _classifierInputSize; x++) {
   169|          final pixel = resized.getPixel(x, y);
   170|          input[idx++] = pixel.r / 255.0;
   171|          input[idx++] = pixel.g / 255.0;
   172|          input[idx++] = pixel.b / 255.0;
   173|        }
   174|      }
   175|
   176|      final inputTensor = input.reshape([1, _classifierInputSize, _classifierInputSize, 3]);
   177|      final output = List.filled(1, List.filled(_embeddingDim, 0.0))
   178|          .reshape([1, _embeddingDim]) as List<List<double>>;
   179|
   180|      _embedder!.run(inputTensor, output);
   181|
   182|      // Normalize the embedding
   183|      final embedding = output[0];
   184|      final norm = embedding.fold<double>(0.0, (sum, v) => sum + v * v);
   185|      if (norm > 0) {
   186|        final sqrtNorm = sqrt(norm);
   187|        for (int i = 0; i < embedding.length; i++) {
   188|          embedding[i] /= sqrtNorm;
   189|        }
   190|      }
   191|
   192|      return embedding;
   193|    } catch (e) {
   194|      _logger.e('Embedding generation failed: $e');
   195|      return null;
   196|    }
   197|  }
   198|
   199|  // ==========================================
   200|  // Cleanup
   201|  // ==========================================
   202|
   203|  void dispose() {
   204|    _classifier?.close();
   205|    _embedder?.close();
   206|    _initialized = false;
   207|  }
   208|}
   209|