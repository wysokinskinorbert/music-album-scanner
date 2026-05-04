import 'dart:math';
import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:logger/logger.dart';
import 'tflite_inference_service.dart';

/// An entry in the offline cover index.
class CoverEmbeddingEntry {
  final String albumId;
  final String title;
  final String artist;
  final int? releaseYear;
  final String? mbid; // MusicBrainz ID for enrichment
  final List<double> embedding;

  const CoverEmbeddingEntry({
    required this.albumId,
    required this.title,
    required this.artist,
    this.releaseYear,
    this.mbid,
    required this.embedding,
  });

  Map<String, dynamic> toJson() => {
        'albumId': albumId,
        'title': title,
        'artist': artist,
        'releaseYear': releaseYear,
        'mbid': mbid,
        'embedding': embedding,
      };

  factory CoverEmbeddingEntry.fromJson(Map<String, dynamic> json) =>
      CoverEmbeddingEntry(
        albumId: json['albumId'],
        title: json['title'],
        artist: json['artist'],
        releaseYear: json['releaseYear'],
        mbid: json['mbid'],
        embedding: (json['embedding'] as List).cast<double>(),
      );
}

/// Result of a similarity search.
class SimilarityResult {
  final CoverEmbeddingEntry entry;
  final double similarity;

  const SimilarityResult({required this.entry, required this.similarity});

  bool get isGoodMatch => similarity >= 0.85;
  bool get isPossibleMatch => similarity >= 0.70;
}

/// Manages a local index of cover embeddings for offline matching.
class CoverEmbeddingService {
  final TfliteInferenceService _inferenceService;
  final Logger _logger = Logger(printer: PrettyPrinter(methodCount: 0));

  Box? _indexBox;
  static const String _boxName = 'cover_embeddings';
  static const int _maxIndexSize = 50000; // 50K covers

  CoverEmbeddingService({required TfliteInferenceService inferenceService})
      : _inferenceService = inferenceService;

  // ==========================================
  // Index Management
  // ==========================================

  /// Initialize the embedding index.
  Future<void> initialize() async {
    _indexBox = await Hive.openBox(_boxName);
    _logger.i('Cover embedding index: ${_indexBox!.length} entries');
  }

  /// Get the number of indexed covers.
  int get indexSize => _indexBox?.length ?? 0;

  /// Check if the index has any entries.
  bool get hasIndex => indexSize > 0;

  // ==========================================
  // Search
  // ==========================================

  /// Find similar covers from the offline index.
  Future<List<SimilarityResult>> findSimilar(
    String imagePath, {
    int maxResults = 5,
    double minSimilarity = 0.60,
  }) async {
    if (!hasIndex) {
      _logger.w('Embedding index is empty');
      return [];
    }

    // Generate embedding for query image
    final queryEmbedding = await _inferenceService.generateEmbedding(imagePath);
    if (queryEmbedding == null) return [];

    // Brute-force search (fine for 50K entries with 512-dim)
    final results = <SimilarityResult>[];

    for (final key in _indexBox!.keys) {
      final json = _indexBox!.get(key);
      if (json == null) continue;

      try {
        final entry = CoverEmbeddingEntry.fromJson(
            Map<String, dynamic>.from(json is String ? jsonDecode(json) : json));
        final similarity = _cosineSimilarity(queryEmbedding, entry.embedding);

        if (similarity >= minSimilarity) {
          results.add(SimilarityResult(entry: entry, similarity: similarity));
        }
      } catch (_) {
        continue; // Skip malformed entries
      }
    }

    // Sort by similarity descending, take top-K
    results.sort((a, b) => b.similarity.compareTo(a.similarity));
    return results.take(maxResults).toList();
  }

  // ==========================================
  // Index Building
  // ==========================================

  /// Add a cover to the index (called after online recognition succeeds).
  Future<void> addToIndex(CoverEmbeddingEntry entry) async {
    if (_indexBox == null) return;

    // Enforce max size
    if (_indexBox!.length >= _maxIndexSize) {
      // Remove oldest entry
      final oldestKey = _indexBox!.keys.first;
      await _indexBox!.delete(oldestKey);
    }

    await _indexBox!.put(entry.albumId, jsonEncode(entry.toJson()));
    _logger.d('Added cover to index: ${entry.artist} - ${entry.title}');
  }

  /// Build index from the user's existing collection.
  /// This lets the app recognize albums the user already scanned.
  Future<int> buildIndexFromCollection(List<dynamic> albums) async {
    int added = 0;
    for (final album in albums) {
      // Skip if already indexed
      if (_indexBox?.containsKey(album['id']) == true) continue;

      // Generate embedding from stored photo
      final photoPath = album['userPhotoPath'] as String?;
      if (photoPath == null) continue;

      final embedding = await _inferenceService.generateEmbedding(photoPath);
      if (embedding == null) continue;

      final entry = CoverEmbeddingEntry(
        albumId: album['id'],
        title: album['title'] ?? '',
        artist: album['artist'] ?? '',
        releaseYear: album['releaseYear'],
        mbid: album['musicBrainzId'],
        embedding: embedding,
      );

      await addToIndex(entry);
      added++;
    }

    _logger.i('Built index from collection: $added new entries');
    return added;
  }

  /// Clear the entire index.
  Future<void> clearIndex() async {
    await _indexBox?.clear();
    _logger.i('Embedding index cleared');
  }

  // ==========================================
  // Math
  // ==========================================

  /// Cosine similarity between two vectors.
  double _cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length || a.isEmpty) return 0.0;

    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (var i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    if (normA == 0 || normB == 0) return 0.0;
    return dotProduct / (sqrt(normA) * sqrt(normB));
  }
}
