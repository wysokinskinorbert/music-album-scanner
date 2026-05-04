import 'package:equatable/equatable.dart';

/// Result of an album recognition attempt.
class RecognitionResult extends Equatable {
  final String? albumTitle;
  final String? artist;
  final double confidence;
  final String source; // 'online' | 'offline' | 'barcode' | 'ocr' | 'none'
  final Map<String, dynamic>? rawApiData;
  final String? errorMessage;

  const RecognitionResult({
    this.albumTitle,
    this.artist,
    required this.confidence,
    required this.source,
    this.rawApiData,
    this.errorMessage,
  });

  bool get isSuccess => albumTitle != null && errorMessage == null;
  bool get isHighConfidence => confidence >= 0.7;
  bool get isBarcodeMatch => source == 'barcode';
  bool get isOcrMatch => source == 'ocr' || source == 'online';

  /// Human-readable source label.
  String get sourceLabel => switch (source) {
    'barcode' => 'Barcode',
    'online' => 'MusicBrainz',
    'ocr' => 'OCR + Search',
    'offline' => 'On-device AI',
    'none' => 'No match',
    _ => source.toUpperCase(),
  };

  @override
  List<Object?> get props => [albumTitle, artist, confidence, source];
}
