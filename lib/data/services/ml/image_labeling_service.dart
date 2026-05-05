import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

/// Labels album cover images using Google ML Kit.
/// Identifies visual elements to help with artistic cover recognition.
class ImageLabelingService {
  final ImageLabeler _labeler = ImageLabeler(
    options: ImageLabelerOptions(confidenceThreshold: 0.5),
  );

  /// Label an image file - returns detected concepts/objects.
  Future<List<ImageLabel>> labelImage(String imagePath) async {
    debugPrint('[ImageLabeler] labelImage path="$imagePath"');
    final inputImage = InputImage.fromFilePath(imagePath);

    try {
      final labels = await _labeler.processImage(inputImage);
      debugPrint('[ImageLabeler] found ${labels.length} labels');
      for (final l in labels) {
        debugPrint('[ImageLabeler]   ${l.label}: ${(l.confidence * 100).toStringAsFixed(1)}%');
      }
      return labels;
    } catch (e, stack) {
      debugPrint('[ImageLabeler] ERROR: $e');
      debugPrint('[ImageLabeler] Stack: $stack');
      return [];
    }
  }

  /// Extract music-relevant labels from the image.
  /// Filters out irrelevant labels and returns ones that might
  /// help identify an album or its genre.
  Future<CoverAnalysis> analyzeCover(String imagePath) async {
    final labels = await labelImage(imagePath);

    // Music-related label categories
    const genreIndicators = {
      'electric guitar': 'Rock',
      'guitar': 'Rock',
      'drum': 'Rock',
      'microphone': 'Hip Hop',
      'concert': 'Live',
      'performance': 'Live',
      'vinyl record': 'Vinyl',
      'album': 'Music',
      'music': 'Music',
      'piano': 'Classical/Jazz',
      'saxophone': 'Jazz',
      'turntable': 'Electronic',
      'headphones': 'Music',
    };

    final coverType = _classifyCoverType(labels);
    final detectedGenres = <String>{};
    final allLabelTexts = <String>[];

    for (final label in labels) {
      allLabelTexts.add(label.label);
      final genre = genreIndicators[label.label.toLowerCase()];
      if (genre != null) {
        detectedGenres.add(genre);
      }
    }

    return CoverAnalysis(
      labels: labels,
      labelTexts: allLabelTexts,
      coverType: coverType,
      detectedGenres: detectedGenres.toList(),
      hasText: allLabelTexts.any((l) =>
          l.toLowerCase().contains('text') ||
          l.toLowerCase().contains('font') ||
          l.toLowerCase().contains('poster')),
      hasPhotograph: allLabelTexts.any((l) =>
          l.toLowerCase().contains('photography') ||
          l.toLowerCase().contains('portrait') ||
          l.toLowerCase().contains('person')),
      isAbstract: coverType == CoverType.abstractArt,
    );
  }

  CoverType _classifyCoverType(List<ImageLabel> labels) {
    final labelSet = labels.map((l) => l.label.toLowerCase()).toSet();

    if (labelSet.contains('text') || labelSet.contains('poster')) {
      return CoverType.textBased;
    }
    if (labelSet.contains('painting') || labelSet.contains('art') ||
        labelSet.contains('illustration')) {
      return CoverType.artwork;
    }
    if (labelSet.contains('photography') || labelSet.contains('portrait') ||
        labelSet.contains('person')) {
      return CoverType.photograph;
    }
    if (labelSet.contains('pattern') || labelSet.contains('abstract')) {
      return CoverType.abstractArt;
    }
    if (labels.isEmpty) {
      return CoverType.minimal;
    }
    return CoverType.unknown;
  }

  void dispose() {
    _labeler.close();
  }
}

/// Analysis result for a cover image.
class CoverAnalysis {
  final List<ImageLabel> labels;
  final List<String> labelTexts;
  final CoverType coverType;
  final List<String> detectedGenres;
  final bool hasText;
  final bool hasPhotograph;
  final bool isAbstract;

  const CoverAnalysis({
    required this.labels,
    required this.labelTexts,
    required this.coverType,
    required this.detectedGenres,
    required this.hasText,
    required this.hasPhotograph,
    required this.isAbstract,
  });

  /// Highest confidence label.
  double get maxConfidence =>
      labels.isEmpty ? 0.0 : labels.map((l) => l.confidence).reduce((a, b) => a > b ? a : b);
}

/// Classification of album cover visual style.
enum CoverType {
  textBased,    // Text-heavy covers (band name, album title prominent)
  artwork,      // Paintings, illustrations
  photograph,   // Photography-based covers
  abstractArt,  // Abstract patterns, geometric designs
  minimal,      // Minimal or blank covers
  unknown,      // Couldn't classify
}
