import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:logger/logger.dart';

/// Result of an image edit operation.
class EditResult {
  final Uint8List bytes;
  final int width;
  final int height;
  final String operation;

  const EditResult({
    required this.bytes,
    required this.width,
    required this.height,
    required this.operation,
  });
}

/// Crop region with normalized coordinates (0.0 - 1.0).
class CropRegion {
  final double left;
  final double top;
  final double right;
  final double bottom;

  const CropRegion({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  double get width => right - left;
  double get height => bottom - top;
  bool get isValid => width > 0 && height > 0 && left >= 0 && top >= 0;

  CropRegion clamp() => CropRegion(
        left: left.clamp(0.0, 1.0),
        top: top.clamp(0.0, 1.0),
        right: right.clamp(0.0, 1.0),
        bottom: bottom.clamp(0.0, 1.0),
      );
}

/// Core image editing operations using the `image` package.
class ImageEditorService {
  final Logger _logger = Logger(printer: PrettyPrinter(methodCount: 0));

  // ==========================================
  // Basic Operations
  // ==========================================

  /// Load an image from file path.
  Future<img.Image?> loadImage(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      return img.decodeImage(bytes);
    } catch (e) {
      _logger.e('Failed to load image: $e');
      return null;
    }
  }

  /// Save image to file.
  Future<String> saveImage(img.Image image, String path, {int quality = 95}) async {
    final file = File(path);
    final bytes = img.encodeJpg(image, quality: quality);
    await file.writeAsBytes(bytes);
    return path;
  }

  /// Save as PNG (lossless).
  Future<String> saveImagePng(img.Image image, String path) async {
    final file = File(path);
    final bytes = img.encodePng(image);
    await file.writeAsBytes(bytes);
    return path;
  }

  // ==========================================
  // Crop
  // ==========================================

  /// Crop image to a normalized region.
  img.Image crop(img.Image image, CropRegion region) {
    if (!region.isValid) {
      _logger.w('Invalid crop region: $region');
      return image;
    }

    final clamped = region.clamp();
    final x = (clamped.left * image.width).round();
    final y = (clamped.top * image.height).round();
    final w = (clamped.width * image.width).round();
    final h = (clamped.height * image.height).round();

    if (w <= 0 || h <= 0) return image;

    return img.copyCrop(image, x: x, y: y, width: w, height: h);
  }

  /// Crop to square (center crop).
  img.Image cropSquare(img.Image image) {
    final size = image.width < image.height ? image.width : image.height;
    final x = (image.width - size) ~/ 2;
    final y = (image.height - size) ~/ 2;
    return img.copyCrop(image, x: x, y: y, width: size, height: size);
  }

  /// Crop to album cover aspect ratio (1:1 or typical vinyl).
  img.Image cropToAlbumRatio(img.Image image, {double aspectRatio = 1.0}) {
    final currentAspect = image.width / image.height;

    int cropW, cropH, cropX, cropY;

    if (currentAspect > aspectRatio) {
      cropH = image.height;
      cropW = (image.height * aspectRatio).round();
      cropX = (image.width - cropW) ~/ 2;
      cropY = 0;
    } else {
      cropW = image.width;
      cropH = (image.width / aspectRatio).round();
      cropX = 0;
      cropY = (image.height - cropH) ~/ 2;
    }

    return img.copyCrop(image, x: cropX, y: cropY, width: cropW, height: cropH);
  }

  // ==========================================
  // Rotate & Flip
  // ==========================================

  /// Rotate image by degrees (90, 180, 270).
  img.Image rotate(img.Image image, int degrees) {
    final rotations = (degrees ~/ 90) % 4;
    var result = image;
    for (var i = 0; i < rotations; i++) {
      result = img.copyRotate(result, angle: 90);
    }
    return result;
  }

  /// Flip horizontally.
  img.Image flipHorizontal(img.Image image) => img.flipHorizontal(image);

  /// Flip vertically.
  img.Image flipVertical(img.Image image) => img.flipVertical(image);

  // ==========================================
  // Adjustments
  // ==========================================

  /// Adjust brightness (-100 to 100).
  img.Image adjustBrightness(img.Image image, int value) {
    if (value == 0) return image;
    return img.adjustColor(image, brightness: value.toDouble());
  }

  /// Adjust contrast (-100 to 100).
  img.Image adjustContrast(img.Image image, int value) {
    if (value == 0) return image;
    return img.adjustColor(image, contrast: value.toDouble());
  }

  /// Adjust saturation (0.0 = grayscale, 1.0 = normal, 2.0 = vivid).
  img.Image adjustSaturation(img.Image image, double value) {
    if (value == 1.0) return image;
    return img.adjustColor(image, saturation: value);
  }

  /// Adjust gamma (0.1 to 3.0, 1.0 = no change).
  img.Image adjustGamma(img.Image image, double value) {
    if (value == 1.0) return image;
    return img.gamma(image, gamma: value);
  }

  // ==========================================
  // Filters
  // ==========================================

  /// Convert to grayscale.
  img.Image grayscale(img.Image image) => img.grayscale(image);

  /// Apply sepia tone filter.
  img.Image sepia(img.Image image) {
    final result = img.Image(width: image.width, height: image.height);
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final r = pixel.r;
        final g = pixel.g;
        final b = pixel.b;

        final newR = (r * 0.393 + g * 0.769 + b * 0.189).clamp(0, 255);
        final newG = (r * 0.349 + g * 0.686 + b * 0.168).clamp(0, 255);
        final newB = (r * 0.272 + g * 0.534 + b * 0.131).clamp(0, 255);

        result.setPixel(x, y, img.ColorRgb8(newR.toInt(), newG.toInt(), newB.toInt()));
      }
    }
    return result;
  }

  /// Sharpen the image.
  img.Image sharpen(img.Image image, {int amount = 1}) {
    var result = image;
    for (var i = 0; i < amount; i++) {
      result = img.convolution(
        result,
        filter: <double>[0, -1, 0, -1, 5, -1, 0, -1, 0],
      );
    }
    return result;
  }

  /// Apply gaussian blur.
  img.Image blur(img.Image image, {int radius = 1}) {
    return img.gaussianBlur(image, radius: radius);
  }

  // ==========================================
  // Resize
  // ==========================================

  /// Resize image to max dimension while preserving aspect ratio.
  img.Image resizeToFit(img.Image image, int maxSize) {
    if (image.width <= maxSize && image.height <= maxSize) return image;

    final ratio = maxSize / (image.width > image.height ? image.width : image.height);
    final newW = (image.width * ratio).round();
    final newH = (image.height * ratio).round();

    return img.copyResize(image, width: newW, height: newH);
  }

  /// Resize to exact dimensions.
  img.Image resize(img.Image image, {required int width, required int height}) {
    return img.copyResize(image, width: width, height: height);
  }

  // ==========================================
  // Utility
  // ==========================================

  /// Get image dimensions without full decode.
  Future<ImageDimensions> getImageDimensions(String path) async {
    final image = await loadImage(path);
    return ImageDimensions(width: image?.width ?? 0, height: image?.height ?? 0);
  }

  /// Encode image to JPEG bytes.
  Uint8List encodeJpg(img.Image image, {int quality = 95}) {
    return Uint8List.fromList(img.encodeJpg(image, quality: quality));
  }

  /// Encode image to PNG bytes.
  Uint8List encodePng(img.Image image) {
    return Uint8List.fromList(img.encodePng(image));
  }
}

/// Simple dimensions holder.
class ImageDimensions {
  final int width;
  final int height;
  const ImageDimensions({required this.width, required this.height});
}
