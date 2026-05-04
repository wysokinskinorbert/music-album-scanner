/// Metadata about a downloadable ML model.
class ModelInfo {
  final String id;
  final String name;
  final String version;
  final String url;
  final int sizeBytes;
  final String sha256;
  final String description;
  final DateTime releasedAt;
  final bool isRequired;

  const ModelInfo({
    required this.id,
    required this.name,
    required this.version,
    required this.url,
    required this.sizeBytes,
    required this.sha256,
    required this.description,
    required this.releasedAt,
    this.isRequired = false,
  });

  String get sizeFormatted {
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  factory ModelInfo.coverRecognizer() => ModelInfo(
        id: 'cover_recognizer_v1',
        name: 'Album Cover Recognizer',
        version: '1.0.0',
        url: 'https://github.com/wysokinskinorbert/music-album-scanner-models/'
            'releases/download/v1.0.0/cover_recognizer.tflite',
        sizeBytes: 15 * 1024 * 1024, // ~15MB
        sha256: 'abc123placeholder',
        description: 'MobileNet-based model for offline album cover recognition. '
            'Identifies ~50,000 popular album covers without internet.',
        releasedAt: DateTime(2026, 5, 1),
      );

  factory ModelInfo.coverEmbedding() => ModelInfo(
        id: 'cover_embedding_v1',
        name: 'Cover Feature Embedding',
        version: '1.0.0',
        url: 'https://github.com/wysokinskinorbert/music-album-scanner-models/'
            'releases/download/v1.0.0/cover_embedding.tflite',
        sizeBytes: 8 * 1024 * 1024, // ~8MB
        sha256: 'def456placeholder',
        description: 'Generates 512-dim feature vectors from album covers. '
            'Used for similarity matching against known covers.',
        releasedAt: DateTime(2026, 5, 1),
      );
}

/// Current state of a model on the device.
enum ModelState {
  notDownloaded,
  downloading,
  downloaded,
  ready,
  error,
  updating,
}

/// Tracks download progress for a model.
class ModelDownloadProgress {
  final String modelId;
  final int downloadedBytes;
  final int totalBytes;
  final String? error;

  const ModelDownloadProgress({
    required this.modelId,
    required this.downloadedBytes,
    required this.totalBytes,
    this.error,
  });

  double get progress => totalBytes > 0 ? downloadedBytes / totalBytes : 0.0;

  String get progressFormatted =>
      '${(progress * 100).toStringAsFixed(0)}% '
      '(${(downloadedBytes / (1024 * 1024)).toStringAsFixed(1)} / '
      '${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB)';

  bool get isComplete => downloadedBytes >= totalBytes;
  bool get hasError => error != null;
}
