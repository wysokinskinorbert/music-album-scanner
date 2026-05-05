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

    // Heuristic: top text is more likely album title, bottom is label/credits
    // Large text in center is typically the artist name
    final lines = <String>[];
    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        final text = line.text.trim();
        if (text.isNotEmpty) {
          lines.add(text);
        }
      }
    }

    return ExtractedText(
      rawText: allText.join(' '),
      lines: lines,
      blocks: blocks,
      topText: topText,
      bottomText: bottomText,
      blockCount: blocks.length,
    );
  }

  /// Generate search queries from extracted text.
  /// Tries multiple strategies to maximize MusicBrainz hit rate.
  List<String> generateSearchQueries(ExtractedText extracted) {
    final queries = <String>[];

    if (extracted.lines.isEmpty) return queries;

    // Strategy 1: First line (likely album title or artist)
    if (extracted.lines.isNotEmpty) {
      queries.add(extracted.lines.first);
    }

    // Strategy 2: First two lines combined (artist + title)
    if (extracted.lines.length >= 2) {
      queries.add('${extracted.lines[0]} ${extracted.lines[1]}');
    }

    // Strategy 3: All text joined (for covers with lots of text)
    if (extracted.blockCount > 2) {
      final joined = extracted.lines.take(4).join(' ');
      if (joined.length <= 200) {
        queries.add(joined);
      }
    }

    // Strategy 4: Largest text block (heuristic for album title)
    String? largestBlock;
    int maxLength = 0;
    for (final block in extracted.blocks) {
      if (block.text.trim().length > maxLength && block.text.trim().length <= 100) {
        maxLength = block.text.trim().length;
        largestBlock = block.text.trim();
      }
    }
    if (largestBlock != null && !queries.contains(largestBlock)) {
      queries.add(largestBlock);
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

  const ExtractedText({
    required this.rawText,
    required this.lines,
    required this.blocks,
    required this.topText,
    required this.bottomText,
    required this.blockCount,
  });

  factory ExtractedText.empty() => const ExtractedText(
        rawText: '',
        lines: [],
        blocks: [],
        topText: [],
        bottomText: [],
        blockCount: 0,
      );

  bool get hasText => rawText.isNotEmpty;
  bool get hasMultipleBlocks => blockCount > 1;
}
