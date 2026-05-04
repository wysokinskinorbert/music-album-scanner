import 'package:equatable/equatable.dart';

/// Result of an album recognition attempt.
class RecognitionResult extends Equatable {
  final String? albumTitle;
  final String? artist;
  final double confidence;
  final String source; // 'online' | 'offline' | 'barcode'
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

  @override
  List<Object?> get props => [albumTitle, artist, confidence, source];
}
