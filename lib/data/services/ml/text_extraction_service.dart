import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:music_album_scanner/data/services/ml/paddle_ocr_service.dart';

/// Extracts text from album cover images.
///
/// Uses PaddleOCR as primary backend (faster, better on stylized fonts)
/// with fallback to Google ML Kit OCR when PaddleOCR is unavailable.
class TextExtractionService {
  final PaddleOcrService? _paddleOcr;
  final TextRecognizer? _mlKitRecognizer;

  /// Whether PaddleOCR is available and initialized.
  bool _paddleOcrAvailable = false;

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

  /// Creates TextExtractionService with optional PaddleOCR backend.
  /// On Android, pass a [PaddleOcrService] instance for native OCR.
  /// On other platforms, ML Kit is used automatically.
  TextExtractionService({PaddleOcrService? paddleOcr})
      : _paddleOcr = paddleOcr,
        _mlKitRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  /// Initialize PaddleOCR backend if available.
  Future<void> initialize() async {
    if (_paddleOcr != null) {
      _paddleOcrAvailable = await _paddleOcr!.initialize();
      if (_paddleOcrAvailable) {
        debugPrint('[TextExtraction] PaddleOCR backend initialized');
      } else {
        debugPrint('[TextExtraction] PaddleOCR unavailable, using ML Kit fallback');
      }
    }
  }

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

  /// Sort OCR lines by bounding-box area, largest first.
  /// Largest text on a cover is most likely the album title or artist name.
  /// Metadata lines are filtered out before sorting.
  List<String> _sortLinesBySize(RecognizedText recognizedText) {
    final linesWithSize = <MapEntry<String, double>>[];
    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        final text = line.text.trim();
        if (text.isEmpty || _isLikelyMetadata(text)) continue;
        final bb = line.boundingBox;
        final area = bb.width * bb.height;
        linesWithSize.add(MapEntry(text, area));
      }
    }
    linesWithSize.sort((a, b) => b.value.compareTo(a.value));
    return linesWithSize.map((e) => e.key).toList();
  }

  /// Extract all text blocks from an image file.
  /// Tries PaddleOCR first, falls back to ML Kit.
  Future<ExtractedText> extractText(String imagePath) async {
    debugPrint('[TextExtraction] extractText path="$imagePath"');

    // Try PaddleOCR first (better quality, especially for album covers)
    if (_paddleOcrAvailable && _paddleOcr != null) {
      try {
        final result = await _paddleOcr!.recognizeText(imagePath);
        if (result != null && result.hasText) {
          debugPrint('[TextExtraction] PaddleOCR: ${result.blocks.length} blocks in ${result.detectTime}ms');
          return _parsePaddleOcrResult(result);
        }
        debugPrint('[TextExtraction] PaddleOCR returned empty, falling back to ML Kit');
      } catch (e) {
        debugPrint('[TextExtraction] PaddleOCR error, falling back to ML Kit: $e');
      }
    }

    // Fallback: ML Kit OCR
    return _extractTextMlKit(imagePath);
  }

  /// ML Kit-based text extraction (fallback).
  Future<ExtractedText> _extractTextMlKit(String imagePath) async {
    if (_mlKitRecognizer == null) return ExtractedText.empty();

    final inputImage = InputImage.fromFilePath(imagePath);
    debugPrint('[TextExtraction] ML Kit: processing...');

    try {
      final recognizedText = await _mlKitRecognizer!.processImage(inputImage);
      debugPrint('[TextExtraction] ML Kit: ${recognizedText.blocks.length} blocks');
      for (final block in recognizedText.blocks) {
        debugPrint('[TextExtraction]   block: "${block.text}"');
      }
      return _parseRecognizedText(recognizedText);
    } catch (e, stack) {
      debugPrint('[TextExtraction] ML Kit ERROR: $e');
      debugPrint('[TextExtraction] Stack: $stack');
      return ExtractedText.empty();
    }
  }

  /// Parse PaddleOCR result into ExtractedText format.
  ExtractedText _parsePaddleOcrResult(PaddleOcrResult result) {
    final blocks = <TextBlock>[];
    final allText = <String>[];
    final lines = <String>[];
    final topText = <String>[];
    final bottomText = <String>[];
    final boundingBoxAreas = <String, double>{};

    for (final ocrBlock in result.blocks) {
      if (ocrBlock.text.trim().isEmpty) continue;
      if (_isLikelyMetadata(ocrBlock.text)) continue;

      allText.add(ocrBlock.text.trim());
      lines.add(ocrBlock.text.trim());

      // Determine vertical position from box points
      final avgY = ocrBlock.avgY;
      // Heuristic: assume image ~1024px tall, top 30% = topText
      if (avgY < 300) {
        topText.add(ocrBlock.text.trim());
      }

      boundingBoxAreas[ocrBlock.text.trim()] = ocrBlock.area;
    }

    // Build filtered lines sorted by area (largest first)
    final filteredLines = List<String>.from(lines);
    filteredLines.sort((a, b) =>
      (boundingBoxAreas[b] ?? 0).compareTo(boundingBoxAreas[a] ?? 0));

    return ExtractedText(
      rawText: allText.join(' '),
      lines: lines,
      blocks: blocks, // ML Kit blocks not available from PaddleOCR
      topText: topText,
      bottomText: bottomText,
      blockCount: result.blocks.length,
      filteredLines: filteredLines,
      boundingBoxAreas: boundingBoxAreas,
    );
  }

  /// Parse ML Kit RecognizedText into ExtractedText.
  ExtractedText _parseRecognizedText(RecognizedText recognizedText) {
    final blocks = <TextBlock>[];
    final allText = <String>[];
    final topText = <String>[];
    final bottomText = <String>[];

    for (final block in recognizedText.blocks) {
      blocks.add(block);
      final text = block.text.trim();
      if (text.isNotEmpty) {
        allText.add(text);

        final boundingBox = block.boundingBox;
        final normalizedY = boundingBox.top;
        if (normalizedY < 200) {
          topText.add(text);
        }
      }
    }

    final lines = <String>[];
    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        final text = line.text.trim();
        if (text.isNotEmpty) {
          lines.add(text);
        }
      }
    }

    final filteredLines = _sortLinesBySize(recognizedText);

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
  ///
  /// IMPORTANT: Queries are ordered from MOST SPECIFIC to LEAST SPECIFIC.
  /// The combined "Artist + Title" query comes FIRST because the scoring
  /// algorithm collects all candidates before picking the best — but an
  /// excellent match on a specific query can trigger early exit, saving API calls.
  List<String> generateSearchQueries(ExtractedText extracted) {
    final queries = <String>[];

    final filtered = extracted.filteredLines;
    if (filtered.isEmpty) return queries;

    debugPrint('[TextExtraction] generateSearchQueries: ${filtered.length} filtered lines');

    // Strategy 0: MusicBrainz Lucene syntax — MOST PRECISE
    // Uses artist: and release: fields for exact matching.
    // This finds the original album even when plain text search returns covers.
    if (filtered.length >= 2) {
      // filtered[0] = largest text (usually artist or title)
      // filtered[1] = second largest
      // Try both orderings: artist:title and title:artist
      queries.add('artist:"${filtered[0]}" AND release:"${filtered[1]}"');
      queries.add('artist:"${filtered[1]}" AND release:"${filtered[0]}"');
    }

    // Strategy 1: Top 2 lines combined (artist + title) — MOST SPECIFIC
    if (filtered.length >= 2) {
      queries.add('${filtered[0]} ${filtered[1]}');
    }

    // Strategy 2: Top 3 lines joined (for covers with lots of text)
    if (filtered.length >= 3) {
      final joined = filtered.take(3).join(' ');
      if (joined.length <= 200 && !queries.contains(joined)) {
        queries.add(joined);
      }
    }

    // Strategy 3: Top 4 lines joined (wider net)
    if (filtered.length >= 4) {
      final joined = filtered.take(4).join(' ');
      if (joined.length <= 200 && !queries.contains(joined)) {
        queries.add(joined);
      }
    }

    // Strategy 4: Largest text alone (most likely album title or artist)
    if (!queries.contains(filtered.first)) {
      queries.add(filtered.first);
    }

    // Strategy 5: Second line alone
    if (filtered.length >= 2 && !queries.contains(filtered[1])) {
      queries.add(filtered[1]);
    }

    debugPrint('[TextExtraction] generated ${queries.length} queries:');
    for (final q in queries) {
      debugPrint('[TextExtraction]   query: "$q"');
    }

    return queries.toSet().toList();
  }

  void dispose() {
    _mlKitRecognizer?.close();
    _paddleOcr?.release();
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
