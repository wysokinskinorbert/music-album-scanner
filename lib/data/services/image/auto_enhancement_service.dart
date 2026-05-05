import 'dart:math';
import 'package:image/image.dart' as img;
import 'package:logger/logger.dart';

/// Preset enhancement modes for album covers.
enum EnhancementMode {
  auto,
  vivid,
  warm,
  cool,
  vintage,
  highContrast,
  lowLight,
}

/// Result of auto-enhancement.
class EnhancementResult {
  final img.Image enhanced;
  final img.Image original;
  final EnhancementMode mode;
  final Map<String, double> adjustments;

  const EnhancementResult({
    required this.enhanced,
    required this.original,
    required this.mode,
    required this.adjustments,
  });
}

/// Automatic image enhancement for album cover photos.
/// Optimizes brightness, contrast, saturation for best recognition results.
class AutoEnhancementService {
  final Logger _logger = Logger(printer: PrettyPrinter(methodCount: 0));

  // ==========================================
  // Auto Enhancement
  // ==========================================

  /// Analyze image and apply optimal enhancements.
  EnhancementResult autoEnhance(
    img.Image image, {
    EnhancementMode mode = EnhancementMode.auto,
  }) {
    final adjustments = <String, double>{};

    if (mode == EnhancementMode.auto) {
      final stats = _analyzeImage(image);
      adjustments['brightness'] = _autoBrightness(stats);
      adjustments['contrast'] = _autoContrast(stats);
      adjustments['saturation'] = _autoSaturation(stats);
      adjustments['gamma'] = _autoGamma(stats);
    } else {
      adjustments.addAll(_presetAdjustments(mode));
    }

    // Apply adjustments
    var result = image;

    if (adjustments['brightness'] != null && adjustments['brightness']! != 0) {
      result = img.adjustColor(result, brightness: adjustments['brightness']!);
    }

    if (adjustments['contrast'] != null && adjustments['contrast']! != 0) {
      result = img.adjustColor(result, contrast: adjustments['contrast']!);
    }

    if (adjustments['saturation'] != null && adjustments['saturation']! != 1.0) {
      result = img.adjustColor(result, saturation: adjustments['saturation']!);
    }

    if (adjustments['gamma'] != null && adjustments['gamma']! != 1.0) {
      result = img.gamma(result, gamma: adjustments['gamma']!);
    }

    // Always apply subtle sharpening for album covers
    result = img.convolution(
      result,
      filter: <double>[0, -0.5, 0, -0.5, 3, -0.5, 0, -0.5, 0],
    );

    _logger.i('Auto-enhanced: $adjustments');
    return EnhancementResult(
      enhanced: result,
      original: image,
      mode: mode,
      adjustments: adjustments,
    );
  }

  /// Quick enhance for OCR optimization.
  img.Image enhanceForOcr(img.Image image) {
    var result = image;

    result = img.grayscale(result);
    result = img.adjustColor(result, contrast: 30);

    result = img.convolution(
      result,
      filter: <double>[0, -1, 0, -1, 5, -1, 0, -1, 0],
    );

    // Binarize
    for (int y = 0; y < result.height; y++) {
      for (int x = 0; x < result.width; x++) {
        final pixel = result.getPixel(x, y);
        final val = pixel.r > 128 ? 255 : 0;
        result.setPixel(x, y, img.ColorRgb8(val, val, val));
      }
    }

    return result;
  }

  /// Enhance specifically for ML model input.
  img.Image enhanceForMl(img.Image image) {
    var result = image;

    final stats = _analyzeImage(image);
    if (stats.meanBrightness < 80) {
      result = img.adjustColor(result, brightness: 30);
    } else if (stats.meanBrightness > 200) {
      result = img.adjustColor(result, brightness: -20);
    }

    result = img.adjustColor(result, contrast: 15);
    result = img.adjustColor(result, saturation: 1.1);

    result = img.convolution(
      result,
      filter: <double>[0, -0.3, 0, -0.3, 2.2, -0.3, 0, -0.3, 0],
    );

    return result;
  }

  // ==========================================
  // Histogram Analysis
  // ==========================================

  ImageStats _analyzeImage(img.Image image) {
    int totalR = 0, totalG = 0, totalB = 0;
    int minR = 255, minG = 255, minB = 255;
    int maxR = 0, maxG = 0, maxB = 0;

    final pixelCount = image.width * image.height;
    final step = pixelCount > 100000 ? 4 : 1;

    int sampledPixels = 0;
    for (int y = 0; y < image.height; y += step) {
      for (int x = 0; x < image.width; x += step) {
        final pixel = image.getPixel(x, y);
        final r = pixel.r.round();
        final g = pixel.g.round();
        final b = pixel.b.round();

        totalR += r;
        totalG += g;
        totalB += b;

        if (r < minR) minR = r;
        if (g < minG) minG = g;
        if (b < minB) minB = b;
        if (r > maxR) maxR = r;
        if (g > maxG) maxG = g;
        if (b > maxB) maxB = b;

        sampledPixels++;
      }
    }

    if (sampledPixels == 0) sampledPixels = 1;
    final meanR = totalR / sampledPixels;
    final meanG = totalG / sampledPixels;
    final meanB = totalB / sampledPixels;
    final meanBrightness = (meanR + meanG + meanB) / 3;

    final dynamicRange = ((maxR - minR) + (maxG - minG) + (maxB - minB)) / 3;

    return ImageStats(
      meanBrightness: meanBrightness,
      meanR: meanR,
      meanG: meanG,
      meanB: meanB,
      dynamicRange: dynamicRange,
      isDark: meanBrightness < 100,
      isBright: meanBrightness > 180,
      isLowContrast: dynamicRange < 80,
      isHighContrast: dynamicRange > 180,
    );
  }

  // ==========================================
  // Auto Adjustment Calculators
  // ==========================================

  double _autoBrightness(ImageStats stats) {
    if (stats.isDark) return 25;
    if (stats.isBright) return -15;
    return 0;
  }

  double _autoContrast(ImageStats stats) {
    if (stats.isLowContrast) return 25;
    if (stats.isHighContrast) return -10;
    return 10;
  }

  double _autoSaturation(ImageStats stats) {
    return 1.15;
  }

  double _autoGamma(ImageStats stats) {
    if (stats.isDark) return 0.85;
    if (stats.isBright) return 1.15;
    return 1.0;
  }

  Map<String, double> _presetAdjustments(EnhancementMode mode) => switch (mode) {
        EnhancementMode.vivid => {
          'brightness': 5,
          'contrast': 20,
          'saturation': 1.4,
          'gamma': 1.0,
        },
        EnhancementMode.warm => {
          'brightness': 10,
          'contrast': 10,
          'saturation': 1.1,
          'gamma': 0.95,
        },
        EnhancementMode.cool => {
          'brightness': 0,
          'contrast': 15,
          'saturation': 0.9,
          'gamma': 1.05,
        },
        EnhancementMode.vintage => {
          'brightness': 5,
          'contrast': -5,
          'saturation': 0.7,
          'gamma': 0.9,
        },
        EnhancementMode.highContrast => {
          'brightness': 0,
          'contrast': 40,
          'saturation': 1.2,
          'gamma': 1.0,
        },
        EnhancementMode.lowLight => {
          'brightness': 40,
          'contrast': 20,
          'saturation': 1.0,
          'gamma': 0.75,
        },
        EnhancementMode.auto => {},
      };
}

/// Image analysis statistics.
class ImageStats {
  final double meanBrightness;
  final double meanR;
  final double meanG;
  final double meanB;
  final double dynamicRange;
  final bool isDark;
  final bool isBright;
  final bool isLowContrast;
  final bool isHighContrast;

  const ImageStats({
    required this.meanBrightness,
    required this.meanR,
    required this.meanG,
    required this.meanB,
    required this.dynamicRange,
    required this.isDark,
    required this.isBright,
    required this.isLowContrast,
    required this.isHighContrast,
  });
}
