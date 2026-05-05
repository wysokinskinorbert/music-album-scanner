import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'image_preprocessor.dart';

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
    'DIGITAL', 'AUDIO', 'COMPACT', 'TOP-HIT', 'STEREO',
    'RECORDING', 'MASTERED', 'RECORDED', 'PRESSING', 'EDITION',
    'GOLD DISC', '24 KARAT', 'KARAT', 'PLATINUM', 'REISSUE',
    'BOOKLET INCLUDES', 'COMPLETE ORIGINAL', 'ARTWORK', 'MASTER TAPES',
    'FROM THE ORIGINAL', 'COLLECTORS EDITION', 'LIMITED EDITION',
    'PARENTAL ADVISORY', 'EXPLICIT CONTENT', 'EXPLICIT', 'ADVISORY',
    'MADE IN', 'MANUFACTURED BY', 'DISTRIBUTED BY', 'LICENSED FROM',
    'ALL RIGHTS RESERVED', 'COPYRIGHT', 'PHONOGRAPHIC',
  ];

  /// Words that are commonly stylized on album covers but are valid artist/title words.
  /// These should NOT be filtered out even if they look like metadata.
  static const _whitelistWords = [
    'untitled', 'unknown', 'various', 'artists', 'soundtrack',
    'homogenic', 'post', 'vespertine', 'medulla', 'biophilia',
    'rumours', 'tusk', 'mirage', 'say you will',
    'paranoid', 'sabbath', 'master', 'vol', 'volume',
    'discovery', 'human', 'random', 'access', 'memories',
    'zombie', 'afrobeat', 'afrika', 'gentleman', 'expensive',
    'madvillain', 'madvillainy', 'doom', 'mf', 'quasimoto',
    'tago', 'mago', 'ege', 'bamyasi', 'future', 'days',
    'nonagon', 'infinity', 'polygondwanaland', 'flying',
    'microtonal', 'banana', 'murder', 'universe',
    'to pimp', 'butterfly', 'damn', 'good', 'kid', 'maad',
    'selected', 'ambient', 'works', 'richard', 'james',
    'music has', 'right', 'children', 'geogaddi', 'tomorrow',
    'harvest', 'moon', 'heaven', 'or', 'las vegas',
    'mezzanine', 'blue', 'lines', 'protection', 'heligoland',
    'ok', 'computer', 'kid', 'a', 'amnesiac', 'in', 'rainbows',
    'vespertine', 'medulla', 'biophilia', 'vulnicura', 'utopia',
    'fela', 'kuti', 'zombie', 'gentleman', 'confusion',
    'black', 'sabbath', 'dio', 'ozzy', 'tony', 'geezer',
    'miles', 'davis', 'bitches', 'brew', 'kind', 'blue',
    'nusrat', 'fateh', 'ali', 'khan', 'qawwali', 'shahenshah',
    'sigur', 'ros', 'takk', 'agætis', 'byrjun', 'kveikur',
    'talking', 'heads', 'remain', 'light', 'fear', 'music',
    'speaking', 'tongues', 'little', 'creatures',
    'burial', 'untrue', 'kindred', 'rival', 'dealers',
    'king', 'gizzard', 'lizard', 'wizard', 'nonagon', 'infinity',
    'metallica', 'master', 'puppets', 'justice', 'black', 'album',
    'daft', 'punk', 'alive', 'homework', 'discovery',
    'kendrick', 'lamar', 'section', 'good', 'kid', 'damn',
    'bjork', 'sugarcubes', 'debut', 'post', 'homogenic',
    'fleetwood', 'mac', 'rumours', 'tango', 'night',
  ];

  /// Returns true if a line of OCR text is likely cover metadata/noise
  /// (e.g. "DIGITALLY REMASTERED", catalog numbers like "INT 110.604").
  bool _isLikelyMetadata(String text) {
    final upper = text.toUpperCase();

    // Check whitelist first - these are valid artist/title words
    final lower = text.toLowerCase();
    for (final word in _whitelistWords) {
      if (lower.contains(word)) return false;
    }

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
  List<_OcrLine> _sortLinesBySize(RecognizedText recognizedText) {
    final linesWithSize = <_OcrLine>[];
    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        final text = line.text.trim();
        if (text.isEmpty) continue;
        
        // Use confidence threshold - but be lenient for stylized fonts
        // Stylized fonts often have lower confidence (0.3-0.6)
        // but still contain valid text
        final confidence = line.confidence ?? 0.0;
        if (confidence < 0.2) continue; // Too low = garbage
        
        final isMetadata = _isLikelyMetadata(text);
        final bb = line.boundingBox;
        final area = bb.width * bb.height;
        
        linesWithSize.add(_OcrLine(
          text: text,
          area: area,
          confidence: confidence,
          isMetadata: isMetadata,
        ));
      }
    }
    linesWithSize.sort((a, b) => b.area.compareTo(a.area));
    return linesWithSize;
  }

  /// Extract all text blocks from an image file.
  Future<ExtractedText> extractText(String imagePath) async {
    debugPrint('[TextExtraction] extractText path="$imagePath"');
    
    // Preprocess image for better OCR
    final preprocessedPath = await ImagePreprocessor.preprocessForOCR(imagePath);
    
    final inputImage = InputImage.fromFilePath(preprocessedPath);
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
        if (text.isNotEmpty && (line.confidence ?? 0.0) >= 0.2) {
          lines.add(text);
        }
      }
    }

    // Build filtered lines with confidence and metadata info
    final sortedLines = _sortLinesBySize(recognizedText);
    
    // Filtered = non-metadata, sorted by size
    final filteredLines = sortedLines
        .where((l) => !l.isMetadata)
        .map((l) => l.text)
        .toList();
    
    // All meaningful lines (including metadata but with low confidence filtered)
    final meaningfulLines = sortedLines.map((l) => l.text).toList();

    // Build bounding-box area map for each filtered line
    final boundingBoxAreas = <String, double>{};
    final lineConfidences = <String, double>{};
    for (final line in sortedLines) {
      if (line.isMetadata) continue;
      boundingBoxAreas[line.text] = line.area;
      lineConfidences[line.text] = line.confidence;
    }

    debugPrint('[TextExtraction] raw lines=${lines.length}, filtered lines=${filteredLines.length}');
    for (final fl in filteredLines) {
      debugPrint('[TextExtraction]   filtered: "$fl" area=${boundingBoxAreas[fl]?.toStringAsFixed(0)} conf=${lineConfidences[fl]?.toStringAsFixed(2)}');
    }

    return ExtractedText(
      rawText: allText.join(' '),
      lines: lines,
      blocks: blocks,
      topText: topText,
      bottomText: bottomText,
      blockCount: blocks.length,
      filteredLines: filteredLines,
      meaningfulLines: meaningfulLines,
      boundingBoxAreas: boundingBoxAreas,
      lineConfidences: lineConfidences,
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
      queries.add('${filtered[1]} ${filtered[0]}'); // reverse order
    }

    // Strategy 3: Individual lines
    for (int i = 1; i < filtered.length && i < 4; i++) {
      if (!queries.contains(filtered[i])) {
        queries.add(filtered[i]);
      }
    }

    // Strategy 4: All meaningful lines combined (wide net)
    if (filtered.length >= 3) {
      final joined = filtered.take(4).join(' ');
      if (joined.length <= 200 && !queries.contains(joined)) {
        queries.add(joined);
      }
    }

    // Strategy 5: Artist-first combinations (common layout: artist top, title bottom)
    if (filtered.length >= 2) {
      // "Artist" + first 2 words of title
      final titleWords = filtered[1].split(' ');
      if (titleWords.length >= 2) {
        final shortTitle = titleWords.take(2).join(' ');
        queries.add('${filtered[0]} $shortTitle');
      }
      
      // First word of artist + full title
      final artistWords = filtered[0].split(' ');
      if (artistWords.length >= 2) {
        queries.add('${artistWords.first} ${filtered[1]}');
      }
    }

    // Strategy 6: Confidence-weighted queries (high confidence lines only)
    final highConfLines = extracted.meaningfulLines
        .where((line) => (extracted.lineConfidences[line] ?? 0.0) >= 0.6)
        .toList();
    if (highConfLines.length >= 2) {
      final joined = highConfLines.take(2).join(' ');
      if (!queries.contains(joined)) {
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

/// Internal class to track OCR line with metadata.
class _OcrLine {
  final String text;
  final double area;
  final double confidence;
  final bool isMetadata;

  _OcrLine({
    required this.text,
    required this.area,
    required this.confidence,
    required this.isMetadata,
  });
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

  /// All meaningful lines (including metadata but with low confidence filtered).
  final List<String> meaningfulLines;

  /// Bounding-box area for each filtered line (text -> area in px²).
  final Map<String, double> boundingBoxAreas;

  /// Confidence for each line (text -> confidence 0.0-1.0).
  final Map<String, double> lineConfidences;

  const ExtractedText({
    required this.rawText,
    required this.lines,
    required this.blocks,
    required this.topText,
    required this.bottomText,
    required this.blockCount,
    this.filteredLines = const [],
    this.meaningfulLines = const [],
    this.boundingBoxAreas = const {},
    this.lineConfidences = const {},
  });

  factory ExtractedText.empty() => const ExtractedText(
        rawText: '',
        lines: [],
        blocks: [],
        topText: [],
        bottomText: [],
        blockCount: 0,
        filteredLines: [],
        meaningfulLines: [],
        boundingBoxAreas: {},
        lineConfidences: {},
      );

  bool get hasText => rawText.isNotEmpty;
  bool get hasMultipleBlocks => blockCount > 1;
}
