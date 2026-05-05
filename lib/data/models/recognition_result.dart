import 'package:equatable/equatable.dart';
import 'album_model.dart';

/// State of the recognition attempt.
enum RecognitionState {
  idle,
  processing,
  success,
  failed,
  error,
}

/// Result of an album recognition attempt.
class RecognitionResult extends Equatable {
  final RecognitionState state;
  final String? message;
  final Album? album;
  final double confidence;
  final String source;
  final String? pipelineSummary;
  final String? extractedText;

  const RecognitionResult({
    this.state = RecognitionState.idle,
    this.message,
    this.album,
    this.confidence = 0.0,
    this.source = 'none',
    this.pipelineSummary,
    this.extractedText,
  });

  bool get isSuccess => state == RecognitionState.success && album != null;
  bool get isHighConfidence => confidence >= 0.7;
  bool get isBarcodeMatch => source.toLowerCase().contains('barcode');
  bool get isOcrMatch => source.toLowerCase().contains('ocr') || source.toLowerCase().contains('online');

  /// Human-readable source label.
  String get sourceLabel => switch (source) {
    'barcode' => 'Barcode',
    'online' || 'MusicBrainz' || 'MusicBrainz (OCR)' => 'MusicBrainz',
    'ocr' => 'OCR + Search',
    'offline' => 'On-device AI',
    'none' => 'No match',
    _ => source,
  };

  /// Alias fields for compatibility with ScanResultBloc
  String? get albumTitle => album?.title;
  String? get artist => album?.artist;
  Map<String, dynamic>? get rawApiData => null;
  String? get errorMessage => state == RecognitionState.error || state == RecognitionState.failed
      ? message
      : null;

  RecognitionResult copyWith({
    RecognitionState? state,
    String? message,
    Album? album,
    double? confidence,
    String? source,
    String? pipelineSummary,
    String? extractedText,
  }) {
    return RecognitionResult(
      state: state ?? this.state,
      message: message ?? this.message,
      album: album ?? this.album,
      confidence: confidence ?? this.confidence,
      source: source ?? this.source,
      pipelineSummary: pipelineSummary ?? this.pipelineSummary,
      extractedText: extractedText ?? this.extractedText,
    );
  }

  @override
  List<Object?> get props => [state, album, confidence, source, pipelineSummary];
}
