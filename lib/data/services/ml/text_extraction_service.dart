import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Extracts text from album cover images using Google ML Kit OCR.
/// Used to find artist names, album titles, and label info from covers.
class TextExtractionService {
  final TextRecognizer _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  /// Patterns that indicate metadata/noise printed on album covers,
  /// not actual artist or album name information.
  static const _metadataPatterns = [
    'DIGITALLY', 'REMASTERED', 'REMASTER', 'ORIGINAL', 'ANALOG', 'ANALOGUE',
    'DIGITAL', 'AUDIO', 'COMPACT', 'TOP-HIT', 'CD', 'VINYL', 'STEREO',
    'RECORDING', 'MASTERED', 'RECORDED', 'PRESSING', 'EDITION',
    'GOLD DISC', '24 KARAT', 'KARAT', 'GOLD', 'PLATINUM', 'REISSUE',
    'BOOKLET INCLUDES', 'COMPLETE ORIGINAL', 'ARTWORK', 'MASTER TAPES',
    'FROM THE ORIGINAL', 'COLLECTORS EDITION', 'LIMITED EDITION',
  ];

  /// Returns true if a line of OCR text is likely cover metadata/noise
  /// (e.g. "DIGITALLY REMASTERED", catalog numbers like "INT 110.604").
  bool _isLikelyMetadata(String text) {
    final upper = text.toUpperCase();

    // Lines that are ALL CAPS and match metadata patterns
    for (final pattern in _metadataPatterns) {
      if (upper == pattern || (upper.contains(pattern) && upper.length < 50)) {
        return true;
      }
    }

    // Lines that look like catalog numbers (mostly digits/dots/slashes)
    final alphanum = text.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final digitCount = alphanum.codeUnits.where((c) => c >= 48 && c <= 57).length;
    final digitRatio = alphanum.isEmpty ? 0.0 : digitCount / alphanum.length;
    if (digitRatio > 0.6 && alphanum.length > 3 && alphanum.length < 15) {
      return true;
    }

    return false;
  }

  /// Minimum confidence threshold for OCR lines to be considered reliable.
  static const double _minConfidence = 0.55;

  /// Sort OCR lines by bounding-box area, largest first.
  /// Largest text on a cover is most likely the album title or artist name.
  /// Metadata lines and low-confidence lines (< [_minConfidence]) are filtered out.
  List<String> _sortLinesBySize(RecognizedText recognizedText) {
    final linesWithSize = <MapEntry<String, double>>[];
    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        final text = line.text.trim();
        if (text.isEmpty || _isLikelyMetadata(text)) continue;
        // Skip low-confidence lines (stylised fonts, artefacts, etc.)
        final conf = line.confidence ?? 1.0;
        if (conf < _minConfidence) {
          debugPrint('[TextExtraction]   SKIPPED low-confidence: "$text" conf=$conf');
          continue;
        }
        final bb = line.boundingBox;
        final area = bb.width * bb.height;
        linesWithSize.add(MapEntry(text, area));
      }
    }
    linesWithSize.sort((a, b) => b.value.compareTo(a.value));
    return linesWithSize.map((e) => e.key).toList();
  }

  /// Extract all text blocks from an image file.
  Future<ExtractedText> extractText(String imagePath) async {
    debugPrint('[TextExtraction] extractText path="$imagePath"');
    final inputImage = InputImage.fromFilePath(imagePath);
    debugPrint('[TextExtraction] InputImage created, filePath=${inputImage.filePath}');

    try {
      final recognizedText = await _textRecognizer.processImage(inputImage);
      debugPrint('[TextExtraction] processImage done, blocks=${recognizedText.blocks.length}');
      for (final block in recognizedText.blocks) {
        debugPrint('[TextExtraction] block: "${block.text}" (${block.boundingBox})');
        for (final line in block.lines) {
          debugPrint('[TextExtraction]   line: "${line.text}" conf=${line.confidence}');
        }
      }
      return _parseRecognizedText(recognizedText);
    } catch (e, stack) {
      debugPrint('[TextExtraction] ERROR: $e');
      debugPrint('[TextExtraction] Stack: $stack');
      return ExtractedText.empty();
    }
  }

  ExtractedText _parseRecognizedText(RecognizedText recognizedText) {
    final blocks = <TextBlock>[];
    final allText = <String>[];
    final topText = <String>[];  // text from top 30% of image
    final bottomText = <String>[];  // text from bottom 30%

    for (final block in recognizedText.blocks) {
      blocks.add(block);
      final text = block.text.trim();
      if (text.isNotEmpty) {
        allText.add(text);

        // Determine vertical position
        final boundingBox = block.boundingBox;
        if (boundingBox != null) {
          final normalizedY = boundingBox.top;
          // If we know the image height, we can normalize
          // For now, use raw pixel position heuristic
          if (normalizedY < 200) {
            topText.add(text);
          }
        }
      }
    }

    // Collect all raw lines (keeping original order)
    final lines = <String>[];
    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        final text = line.text.trim();
        if (text.isNotEmpty) {
          lines.add(text);
        }
      }
    }

    // Build filtered lines (metadata removed) sorted by bounding-box area
    final filteredLines = _sortLinesBySize(recognizedText);

    // Build bounding-box area map for each filtered line
    final boundingBoxAreas = <String, double>{};
    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        final text = line.text.trim();
        if (text.isEmpty || _isLikelyMetadata(text)) continue;
        final bb = line.boundingBox;
        boundingBoxAreas[text] = bb.width * bb.height;
      }
    }

    debugPrint('[TextExtraction] raw lines=${lines.length}, filtered lines=${filteredLines.length}');
    for (final fl in filteredLines) {
      debugPrint('[TextExtraction]   filtered: "$fl" area=${boundingBoxAreas[fl]?.toStringAsFixed(0)}');
    }

    return ExtractedText(
      rawText: allText.join(' '),
      lines: lines,
      blocks: blocks,
      topText: topText,
      bottomText: bottomText,
      blockCount: blocks.length,
      filteredLines: filteredLines,
      boundingBoxAreas: boundingBoxAreas,
    );
  }

  /// Generate search queries from extracted text.
  /// Uses FILTERED + SIZE-SORTED lines: metadata is removed first,
  /// then lines are ordered by bounding-box area (largest = most likely
  /// album title or artist name).
  List<String> generateSearchQueries(ExtractedText extracted) {
    final queries = <String>[];

    final filtered = extracted.filteredLines;
    if (filtered.isEmpty) return queries;

    debugPrint('[TextExtraction] generateSearchQueries: ${filtered.length} filtered lines');

    // Strategy 1: Largest text (most likely album title)
    queries.add(filtered.first);

    // Strategy 2: Top 2 largest lines combined (artist + title)
    if (filtered.length >= 2) {
      queries.add('${filtered[0]} ${filtered[1]}');
    }

    // Strategy 3: Next combination — second line alone
    if (filtered.length >= 2 && !queries.contains(filtered[1])) {
      queries.add(filtered[1]);
    }

    // Strategy 4: Top 3 lines joined (for covers with lots of text)
    if (filtered.length >= 3) {
      final joined = filtered.take(3).join(' ');
      if (joined.length <= 200 && !queries.contains(joined)) {
        queries.add(joined);
      }
    }

    // Strategy 5: Top 4 lines joined (wider net)
    if (filtered.length >= 4) {
      final joined = filtered.take(4).join(' ');
      if (joined.length <= 200 && !queries.contains(joined)) {
        queries.add(joined);
      }
    }

    debugPrint('[TextExtraction] generated ${queries.length} queries:');
    for (final q in queries) {
      debugPrint('[TextExtraction]   query: "$q"');
    }

    return queries.toSet().toList(); // deduplicate
  }

  void dispose() {
    _textRecognizer.close();
  }
}

/// Parsed OCR result from album cover.
class ExtractedText {
  final String rawText;
  final List<String> lines;
  final List<TextBlock> blocks;
  final List<String> topText;
  final List<String> bottomText;
  final int blockCount;

  /// Lines with metadata/noise removed, sorted by bounding-box area (largest first).
  final List<String> filteredLines;

  /// Bounding-box area for each filtered line (text -> area in px²).
  final Map<String, double> boundingBoxAreas;

  const ExtractedText({
    required this.rawText,
    required this.lines,
    required this.blocks,
    required this.topText,
    required this.bottomText,
    required this.blockCount,
    this.filteredLines = const [],
    this.boundingBoxAreas = const {},
  });

  factory ExtractedText.empty() => const ExtractedText(
        rawText: '',
        lines: [],
        blocks: [],
        topText: [],
        bottomText: [],
        blockCount: 0,
        filteredLines: [],
        boundingBoxAreas: {},
      );

  bool get hasText => rawText.isNotEmpty;
  bool get hasMultipleBlocks => blockCount > 1;
}
