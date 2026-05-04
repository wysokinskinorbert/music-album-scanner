import '../../core/network/connectivity_service.dart';
import '../ml/model/model_download_manager.dart';
import '../ml/model/model_info.dart';
import '../ml/tflite_inference_service.dart';
import '../ml/cover_embedding_service.dart';
import '../../models/album_model.dart';
import 'package:logger/logger.dart';

/// Result from offline recognition attempt.
class OfflineRecognitionResult {
  final bool recognized;
  final String? title;
  final String? artist;
  final double confidence;
  final String method; // 'tfmodel', 'embedding', 'none'

  const OfflineRecognitionResult({
    required this.recognized,
    this.title,
    this.artist,
    this.confidence = 0.0,
    this.method = 'none',
  });

  /// Create a failed result.
  factory OfflineRecognitionResult.notRecognized() =>
      const OfflineRecognitionResult(recognized: false);

  /// Convert to a minimal Album for local storage.
  Album toAlbum({String? photoPath}) => Album(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title ?? 'Unknown Album',
        artist: artist ?? 'Unknown Artist',
        confidence: confidence,
        source: 'offline ($method)',
        userPhotoPath: photoPath,
      );
}

/// Unified offline recognition service.
/// Coordinates TFLite model inference and embedding-based matching.
class OfflineRecognitionService {
  final ModelDownloadManager _downloadManager;
  final ConnectivityService _connectivity;
  final Logger _logger = Logger(printer: PrettyPrinter(methodCount: 0));

  TfliteInferenceService? _inferenceService;
  CoverEmbeddingService? _embeddingService;

  bool _initialized = false;

  bool get isAvailable => _initialized && _downloadManager.isOfflineReady;
  bool get modelDownloaded =>
      _downloadManager.getState(ModelInfo.coverRecognizer().id) == ModelState.ready;

  OfflineRecognitionService({
    required ModelDownloadManager downloadManager,
    required ConnectivityService connectivity,
  })  : _downloadManager = downloadManager,
        _connectivity = connectivity;

  // ==========================================
  // Lifecycle
  // ==========================================

  /// Initialize offline recognition. Call after models are downloaded.
  Future<bool> initialize() async {
    if (_initialized) return true;

    try {
      // Initialize inference service
      _inferenceService = TfliteInferenceService(
        downloadManager: _downloadManager,
      );
      final inferenceOk = await _inferenceService!.initialize();
      if (!inferenceOk) {
        _logger.w('TFLite inference not available');
      }

      // Initialize embedding service
      _embeddingService = CoverEmbeddingService(
        inferenceService: _inferenceService!,
      );
      await _embeddingService!.initialize();

      _initialized = true;
      _logger.i('Offline recognition ready '
          '(inference: $inferenceOk, index: ${_embeddingService!.indexSize})');
      return true;
    } catch (e) {
      _logger.e('Failed to init offline recognition: $e');
      return false;
    }
  }

  // ==========================================
  // Recognition
  // ==========================================

  /// Try to recognize an album cover offline.
  /// Returns a result that may or may not be confident enough.
  Future<OfflineRecognitionResult> recognize(String imagePath) async {
    if (!_initialized || _inferenceService == null) {
      return OfflineRecognitionResult.notRecognized();
    }

    // Strategy 1: Direct model classification
    final modelResult = await _tryModelRecognition(imagePath);
    if (modelResult != null && modelResult.isConfident) {
      return modelResult;
    }

    // Strategy 2: Embedding similarity search
    final embeddingResult = await _tryEmbeddingMatch(imagePath);
    if (embeddingResult != null && embeddingResult.recognized) {
      return embeddingResult;
    }

    // Nothing worked offline
    return OfflineRecognitionResult.notRecognized();
  }

  /// Strategy 1: Run TFLite classifier.
  Future<OfflineRecognitionResult?> _tryModelRecognition(String imagePath) async {
    if (!_inferenceService!.isReady) return null;

    try {
      final result = await _inferenceService!.recognizeCover(imagePath);
      if (result == null) return null;

      _logger.i('Model recognition: ${result.label} '
          '(${(result.confidence * 100).toStringAsFixed(1)}%)');

      // Parse label into artist - title
      // Labels are formatted as "Artist__Title" in the model
      final parts = result.label.split('__');
      if (parts.length >= 2) {
        return OfflineRecognitionResult(
          recognized: true,
          artist: parts[0].replaceAll('_', ' '),
          title: parts[1].replaceAll('_', ' '),
          confidence: result.confidence,
          method: 'tfmodel',
        );
      }

      return OfflineRecognitionResult(
        recognized: result.isConfident,
        title: result.label.replaceAll('_', ' '),
        confidence: result.confidence,
        method: 'tfmodel',
      );
    } catch (e) {
      _logger.e('Model recognition failed: $e');
      return null;
    }
  }

  /// Strategy 2: Find similar cover in local embedding index.
  Future<OfflineRecognitionResult?> _tryEmbeddingMatch(String imagePath) async {
    if (_embeddingService == null || !_embeddingService!.hasIndex) return null;

    try {
      final results = await _embeddingService!.findSimilar(
        imagePath,
        maxResults: 1,
        minSimilarity: 0.80,
      );

      if (results.isEmpty) return null;

      final best = results.first;
      _logger.i('Embedding match: ${best.entry.artist} - ${best.entry.title} '
          '(${(best.similarity * 100).toStringAsFixed(1)}%)');

      return OfflineRecognitionResult(
        recognized: best.isGoodMatch,
        artist: best.entry.artist,
        title: best.entry.title,
        confidence: best.similarity,
        method: 'embedding',
      );
    } catch (e) {
      _logger.e('Embedding match failed: $e');
      return null;
    }
  }

  // ==========================================
  // Index Building
  // ==========================================

  /// Add a recognized album to the embedding index.
  /// Called after successful online recognition to grow the local index.
  Future<void> addToIndex(Album album) async {
    if (_embeddingService == null || album.userPhotoPath == null) return;

    final embedding = await _inferenceService?.generateEmbedding(
      album.userPhotoPath!,
    );
    if (embedding == null) return;

    final entry = CoverEmbeddingEntry(
      albumId: album.id,
      title: album.title,
      artist: album.artist,
      releaseYear: album.releaseYear,
      mbid: album.musicBrainzId,
      embedding: embedding,
    );

    await _embeddingService!.addToIndex(entry);
  }

  /// Build index from existing collection.
  Future<int> buildIndexFromCollection(List<Map<String, dynamic>> albums) async {
    if (_embeddingService == null) return 0;
    return _embeddingService!.buildIndexFromCollection(albums);
  }
}
