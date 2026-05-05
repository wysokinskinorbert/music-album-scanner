import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Preprocesses album cover images for better OCR accuracy.
/// Steps: resize, grayscale, contrast boost.
class ImagePreprocessor {
  /// Preprocess image for OCR and return path to preprocessed temp file.
  static Future<String> preprocessForOCR(String imagePath) async {
    try {
      final bytes = await File(imagePath).readAsBytes();
      var image = img.decodeImage(bytes);
      if (image == null) {
        debugPrint('[ImagePreprocessor] Failed to decode image, using original');
        return imagePath;
      }

      debugPrint('[ImagePreprocessor] Original: ${image.width}x${image.height}');

      // Step 1: Resize if too large (OCR works better on moderate sizes)
      if (image.width > 1200 || image.height > 1200) {
        image = img.copyResize(image, width: 800);
        debugPrint('[ImagePreprocessor] Resized to: ${image.width}x${image.height}');
      }

      // Step 2: Convert to grayscale for better text contrast
      image = img.grayscale(image);
      
      // Step 3: Increase contrast (histogram stretch)
      image = img.adjustColor(image, contrast: 1.3);
      
      // Step 4: Normalize brightness
      image = img.normalize(image, min: 0, max: 255);
      
      // Step 5: Gaussian blur to reduce noise
      image = img.gaussianBlur(image, radius: 1);
      
      // Save preprocessed image to temp file
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/ocr_preprocessed_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(img.encodeJpg(image, quality: 90));
      
      debugPrint('[ImagePreprocessor] Saved to: ${tempFile.path}');
      return tempFile.path;
    } catch (e, stack) {
      debugPrint('[ImagePreprocessor] ERROR: $e');
      debugPrint('[ImagePreprocessor] Stack: $stack');
      return imagePath; // Fallback to original
    }
  }

  /// Clean up preprocessed temp files (call periodically).
  static Future<void> cleanupTempFiles() async {
    try {
      final tempDir = Directory.systemTemp;
      final files = tempDir.listSync();
      for (final file in files) {
        if (file is File && file.path.contains('ocr_preprocessed_')) {
          await file.delete();
        }
      }
    } catch (_) {
      // Ignore cleanup errors
    }
  }
}
