     1|import 'package:music_album_scanner/core/network/connectivity_service.dart';
     2|import '../ml/model/model_download_manager.dart';
     3|import '../ml/model/model_info.dart';
     4|import '../ml/tflite_inference_service.dart';
     5|import '../ml/cover_embedding_service.dart';
     6|import '../../models/album_model.dart';
     7|import 'package:logger/logger.dart';
     8|
     9|/// Result from offline recognition attempt.
    10|class OfflineRecognitionResult {
    11|  final bool recognized;
    12|  final String? title;
    13|  final String? artist;
    14|  final double confidence;
    15|  final String method; // 'tfmodel', 'embedding', 'none'
    16|
    17|  const OfflineRecognitionResult({
    18|    required this.recognized,
    19|    this.title,
    20|    this.artist,
    21|    this.confidence = 0.0,
    22|    this.method = 'none',
    23|  });
    24|
    25|  /// Create a failed result.
    26|  factory OfflineRecognitionResult.notRecognized() =>
    27|      const OfflineRecognitionResult(recognized: false);
    28|
    29|  /// Convert to a minimal Album for local storage.
    30|  Album toAlbum({String? photoPath}) => Album(
    31|        id: DateTime.now().millisecondsSinceEpoch.toString(),
    32|        title: title ?? 'Unknown Album',
    33|        artist: artist ?? 'Unknown Artist',
    34|        recognitionConfidence: confidence,
    35|        userPhotoPath: photoPath,
    36|        dateAdded: DateTime.now(),
    37|      );
    38|}
    39|
    40|/// Unified offline recognition service.
    41|/// Coordinates TFLite model inference and embedding-based matching.
    42|class OfflineRecognitionService {
    43|  final ModelDownloadManager _downloadManager;
    44|  final ConnectivityService _connectivity;
    45|  final Logger _logger = Logger(printer: PrettyPrinter(methodCount: 0));
    46|
    47|  TfliteInferenceService? _inferenceService;
    48|  CoverEmbeddingService? _embeddingService;
    49|
    50|  bool _initialized = false;
    51|
    52|  bool get isAvailable => _initialized && _downloadManager.isOfflineReady;
    53|  bool get modelDownloaded =>
    54|      _downloadManager.getState(ModelInfo.coverRecognizer().id) == ModelState.ready;
    55|
    56|  OfflineRecognitionService({
    57|    required ModelDownloadManager downloadManager,
    58|    required ConnectivityService connectivity,
    59|  })  : _downloadManager = downloadManager,
    60|        _connectivity = connectivity;
    61|
    62|  // ==========================================
    63|  // Lifecycle
    64|  // ==========================================
    65|
    66|  /// Initialize offline recognition. Call after models are downloaded.
    67|  Future<bool> initialize() async {
    68|    if (_initialized) return true;
    69|
    70|    try {
    71|      // Initialize inference service
    72|      _inferenceService = TfliteInferenceService(
    73|        downloadManager: _downloadManager,
    74|      );
    75|      final inferenceOk = await _inferenceService!.initialize();
    76|      if (!inferenceOk) {
    77|        _logger.w('TFLite inference not available');
    78|      }
    79|
    80|      // Initialize embedding service
    81|      _embeddingService = CoverEmbeddingService(
    82|        inferenceService: _inferenceService!,
    83|      );
    84|      await _embeddingService!.initialize();
    85|
    86|      _initialized = true;
    87|      _logger.i('Offline recognition ready '
    88|          '(inference: $inferenceOk, index: ${_embeddingService!.indexSize})');
    89|      return true;
    90|    } catch (e) {
    91|      _logger.e('Failed to init offline recognition: $e');
    92|      return false;
    93|    }
    94|  }
    95|
    96|  // ==========================================
    97|  // Recognition
    98|  // ==========================================
    99|
   100|  /// Try to recognize an album cover offline.
   101|  /// Returns a result that may or may not be confident enough.
   102|  Future<OfflineRecognitionResult> recognize(String imagePath) async {
   103|    if (!_initialized || _inferenceService == null) {
   104|      return OfflineRecognitionResult.notRecognized();
   105|    }
   106|
   107|    // Strategy 1: Direct model classification
   108|    final modelResult = await _tryModelRecognition(imagePath);
   109|    if (modelResult != null && modelResult.confidence >= 0.6) {
   110|      return modelResult;
   111|    }
   112|
   113|    // Strategy 2: Embedding similarity search
   114|    final embeddingResult = await _tryEmbeddingMatch(imagePath);
   115|    if (embeddingResult != null && embeddingResult.recognized) {
   116|      return embeddingResult;
   117|    }
   118|
   119|    // Nothing worked offline
   120|    return OfflineRecognitionResult.notRecognized();
   121|  }
   122|
   123|  /// Strategy 1: Run TFLite classifier.
   124|  Future<OfflineRecognitionResult?> _tryModelRecognition(String imagePath) async {
   125|    if (!_inferenceService!.isReady) return null;
   126|
   127|    try {
   128|      final result = await _inferenceService!.recognizeCover(imagePath);
   129|      if (result == null) return null;
   130|
   131|      _logger.i('Model recognition: ${result.label} '
   132|          '(${(result.confidence * 100).toStringAsFixed(1)}%)');
   133|
   134|      // Parse label into artist - title
   135|      // Labels are formatted as "Artist__Title" in the model
   136|      final parts = result.label.split('__');
   137|      if (parts.length >= 2) {
   138|        return OfflineRecognitionResult(
   139|          recognized: true,
   140|          artist: parts[0].replaceAll('_', ' '),
   141|          title: parts[1].replaceAll('_', ' '),
   142|          confidence: result.confidence,
   143|          method: 'tfmodel',
   144|        );
   145|      }
   146|
   147|      return OfflineRecognitionResult(
   148|        recognized: result.confidence >= 0.6,
   149|        title: result.label.replaceAll('_', ' '),
   150|        confidence: result.confidence,
   151|        method: 'tfmodel',
   152|      );
   153|    } catch (e) {
   154|      _logger.e('Model recognition failed: $e');
   155|      return null;
   156|    }
   157|  }
   158|
   159|  /// Strategy 2: Find similar cover in local embedding index.
   160|  Future<OfflineRecognitionResult?> _tryEmbeddingMatch(String imagePath) async {
   161|    if (_embeddingService == null || !_embeddingService!.hasIndex) return null;
   162|
   163|    try {
   164|      final results = await _embeddingService!.findSimilar(
   165|        imagePath,
   166|        maxResults: 1,
   167|        minSimilarity: 0.80,
   168|      );
   169|
   170|      if (results.isEmpty) return null;
   171|
   172|      final best = results.first;
   173|      _logger.i('Embedding match: ${best.entry.artist} - ${best.entry.title} '
   174|          '(${(best.similarity * 100).toStringAsFixed(1)}%)');
   175|
   176|      return OfflineRecognitionResult(
   177|        recognized: best.isGoodMatch,
   178|        artist: best.entry.artist,
   179|        title: best.entry.title,
   180|        confidence: best.similarity,
   181|        method: 'embedding',
   182|      );
   183|    } catch (e) {
   184|      _logger.e('Embedding match failed: $e');
   185|      return null;
   186|    }
   187|  }
   188|
   189|  // ==========================================
   190|  // Index Building
   191|  // ==========================================
   192|
   193|  /// Add a recognized album to the embedding index.
   194|  /// Called after successful online recognition to grow the local index.
   195|  Future<void> addToIndex(Album album) async {
   196|    if (_embeddingService == null || album.userPhotoPath == null) return;
   197|
   198|    final embedding = await _inferenceService?.generateEmbedding(
   199|      album.userPhotoPath!,
   200|    );
   201|    if (embedding == null) return;
   202|
   203|    final entry = CoverEmbeddingEntry(
   204|      albumId: album.id,
   205|      title: album.title,
   206|      artist: album.artist,
   207|      releaseYear: album.releaseYear,
   208|      mbid: album.musicBrainzId,
   209|      embedding: embedding,
   210|    );
   211|
   212|    await _embeddingService!.addToIndex(entry);
   213|  }
   214|
   215|  /// Build index from existing collection.
   216|  Future<int> buildIndexFromCollection(List<Map<String, dynamic>> albums) async {
   217|    if (_embeddingService == null) return 0;
   218|    return _embeddingService!.buildIndexFromCollection(albums);
   219|  }
   220|}
   221|