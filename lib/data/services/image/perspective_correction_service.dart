import 'dart:math';
import 'package:image/image.dart' as img;
import 'package:logger/logger.dart';

/// Four corners of a quadrilateral (normalized 0.0-1.0).
class QuadCorners {
  final Point<double> topLeft;
  final Point<double> topRight;
  final Point<double> bottomRight;
  final Point<double> bottomLeft;

  const QuadCorners({
    required this.topLeft,
    required this.topRight,
    required this.bottomRight,
    required this.bottomLeft,
  });

  /// Default corners (full image, no distortion).
  factory QuadCorners.fullImage() => const QuadCorners(
        topLeft: Point(0.0, 0.0),
        topRight: Point(1.0, 0.0),
        bottomRight: Point(1.0, 1.0),
        bottomLeft: Point(0.0, 1.0),
      );

  /// Auto-detect corners from edge detection heuristics.
  /// For album covers: finds the rectangular cover area.
  factory QuadCorners.autoDetect(img.Image image) {
    // Simplified edge detection for album covers:
    // Most album photos have the cover roughly centered.
    // We detect the edges by looking for high-contrast boundaries.

    final w = image.width;
    final h = image.height;

    // Scan from edges inward to find the cover boundary
    int leftBound = _scanFromLeft(image, w, h);
    int rightBound = _scanFromRight(image, w, h);
    int topBound = _scanFromTop(image, w, h);
    int bottomBound = _scanFromBottom(image, w, h);

    // Add small padding
    final padding = (w * 0.02).round();
    leftBound = (leftBound - padding).clamp(0, w);
    rightBound = (rightBound + padding).clamp(0, w);
    topBound = (topBound - padding).clamp(0, h);
    bottomBound = (bottomBound + padding).clamp(0, h);

    return QuadCorners(
      topLeft: Point(leftBound / w, topBound / h),
      topRight: Point(rightBound / w, topBound / h),
      bottomRight: Point(rightBound / w, bottomBound / h),
      bottomLeft: Point(leftBound / w, bottomBound / h),
    );
  }

  /// Convert to pixel coordinates for a given image size.
  QuadCornersPixel toPixelCoords(int imageWidth, int imageHeight) =>
      QuadCornersPixel(
        topLeft: Point(
            (topLeft.x * imageWidth).round(), (topLeft.y * imageHeight).round()),
        topRight: Point(
            (topRight.x * imageWidth).round(), (topRight.y * imageHeight).round()),
        bottomRight: Point((bottomRight.x * imageWidth).round(),
            (bottomRight.y * imageHeight).round()),
        bottomLeft: Point((bottomLeft.x * imageWidth).round(),
            (bottomLeft.y * imageHeight).round()),
      );

  bool get isDistorted {
    // Check if corners deviate from a rectangle
    final tl = topLeft, tr = topRight, br = bottomRight, bl = bottomLeft;
    final threshold = 0.02;

    // Top edge should be horizontal
    if ((tl.y - tr.y).abs() > threshold) return true;
    // Bottom edge should be horizontal
    if ((bl.y - br.y).abs() > threshold) return true;
    // Left edge should be vertical
    if ((tl.x - bl.x).abs() > threshold) return true;
    // Right edge should be vertical
    if ((tr.x - br.x).abs() > threshold) return true;

    return false;
  }
}

class QuadCornersPixel {
  final Point<int> topLeft;
  final Point<int> topRight;
  final Point<int> bottomRight;
  final Point<int> bottomLeft;

  const QuadCornersPixel({
    required this.topLeft,
    required this.topRight,
    required this.bottomRight,
    required this.bottomLeft,
  });
}

/// Perspective correction / dewarping service.
class PerspectiveCorrectionService {
  final Logger _logger = Logger(printer: PrettyPrinter(methodCount: 0));

  /// Apply perspective correction using bilinear interpolation.
  /// Maps the quadrilateral defined by [corners] to a rectangle.
  img.Image correctPerspective(
    img.Image image,
    QuadCorners corners, {
    int? outputWidth,
    int? outputHeight,
  }) {
    final pixelCorners = corners.toPixelCoords(image.width, image.height);

    // Calculate output dimensions from the quad
    final topWidth = (pixelCorners.topRight.x - pixelCorners.topLeft.x).abs();
    final bottomWidth =
        (pixelCorners.bottomRight.x - pixelCorners.bottomLeft.x).abs();
    final leftHeight =
        (pixelCorners.bottomLeft.y - pixelCorners.topLeft.y).abs();
    final rightHeight =
        (pixelCorners.bottomRight.y - pixelCorners.topRight.y).abs();

    final outW = outputWidth ?? ((topWidth + bottomWidth) / 2).round();
    final outH =
        outputHeight ?? ((leftHeight + rightHeight) / 2).round();

    if (outW <= 0 || outH <= 0) {
      _logger.w('Invalid output dimensions: ${outW}x$outH');
      return image;
    }

    final result = img.Image(width: outW, height: outH);

    // Source quad points
    final srcPts = [
      pixelCorners.topLeft,
      pixelCorners.topRight,
      pixelCorners.bottomRight,
      pixelCorners.bottomLeft,
    ];

    // Destination rect points
    final dstPts = [
      Point(0, 0),
      Point(outW - 1, 0),
      Point(outW - 1, outH - 1),
      Point(0, outH - 1),
    ];

    // Compute inverse perspective transform
    // We map destination -> source (inverse mapping)
    final invMatrix = _computePerspectiveTransform(dstPts, srcPts);

    if (invMatrix == null) {
      _logger.w('Failed to compute perspective transform');
      return image;
    }

    // Apply inverse mapping with bilinear interpolation
    for (int dy = 0; dy < outH; dy++) {
      for (int dx = 0; dx < outW; dx++) {
        // Map destination pixel to source
        final w = invMatrix[6] * dx + invMatrix[7] * dy + invMatrix[8];
        if (w == 0) continue;

        final sx = (invMatrix[0] * dx + invMatrix[1] * dy + invMatrix[2]) / w;
        final sy = (invMatrix[3] * dx + invMatrix[4] * dy + invMatrix[5]) / w;

        // Bilinear interpolation
        final color = _bilinearSample(image, sx, sy);
        if (color != null) {
          result.setPixel(dx, dy, color);
        }
      }
    }

    _logger.i('Perspective corrected: ${image.width}x${image.height} -> ${outW}x${outH}');
    return result;
  }

  /// Auto-detect and correct perspective for an album cover photo.
  img.Image autoCorrect(img.Image image) {
    final corners = QuadCorners.autoDetect(image);

    if (!corners.isDistorted) {
      _logger.i('No significant perspective distortion detected');
      return image;
    }

    return correctPerspective(image, corners);
  }

  // ==========================================
  // Math Helpers
  // ==========================================

  /// Compute 3x3 perspective transform matrix mapping pts1 -> pts2.
  List<double>? _computePerspectiveTransform(
    List<Point> pts1,
    List<Point> pts2,
  ) {
    if (pts1.length != 4 || pts2.length != 4) return null;

    // Build the 8x8 system of equations
    // [x1 y1 1 0 0 0 -x1*x1' -y1*x1'] [h0]   [x1']
    // [0 0 0 x1 y1 1 -x1*y1' -y1*y1'] [h1]   [y1']
    // ...                                [h2] = [...]
    //                                    [..]
    //                                    [h7]

    final a = List.generate(8, (_) => List.filled(8, 0.0));
    final b = List.filled(8, 0.0);

    for (int i = 0; i < 4; i++) {
      final x1 = pts1[i].x.toDouble();
      final y1 = pts1[i].y.toDouble();
      final x2 = pts2[i].x.toDouble();
      final y2 = pts2[i].y.toDouble();

      a[i * 2][0] = x1;
      a[i * 2][1] = y1;
      a[i * 2][2] = 1;
      a[i * 2][3] = 0;
      a[i * 2][4] = 0;
      a[i * 2][5] = 0;
      a[i * 2][6] = -x1 * x2;
      a[i * 2][7] = -y1 * x2;
      b[i * 2] = x2;

      a[i * 2 + 1][0] = 0;
      a[i * 2 + 1][1] = 0;
      a[i * 2 + 1][2] = 0;
      a[i * 2 + 1][3] = x1;
      a[i * 2 + 1][4] = y1;
      a[i * 2 + 1][5] = 1;
      a[i * 2 + 1][6] = -x1 * y2;
      a[i * 2 + 1][7] = -y1 * y2;
      b[i * 2 + 1] = y2;
    }

    // Solve using Gaussian elimination
    return _solveLinearSystem(a, b);
  }

  /// Gaussian elimination for 8x8 system.
  List<double>? _solveLinearSystem(List<List<double>> a, List<double> b) {
    final n = 8;
    final aug = List.generate(n, (i) => [...a[i], b[i]]);

    // Forward elimination
    for (int col = 0; col < n; col++) {
      // Find pivot
      int maxRow = col;
      for (int row = col + 1; row < n; row++) {
        if (aug[row][col].abs() > aug[maxRow][col].abs()) {
          maxRow = row;
        }
      }

      // Swap rows
      final temp = aug[col];
      aug[col] = aug[maxRow];
      aug[maxRow] = temp;

      if (aug[col][col].abs() < 1e-10) return null;

      // Eliminate below
      for (int row = col + 1; row < n; row++) {
        final factor = aug[row][col] / aug[col][col];
        for (int j = col; j <= n; j++) {
          aug[row][j] -= factor * aug[col][j];
        }
      }
    }

    // Back substitution
    final x = List.filled(n, 0.0);
    for (int i = n - 1; i >= 0; i--) {
      x[i] = aug[i][n];
      for (int j = i + 1; j < n; j++) {
        x[i] -= aug[i][j] * x[j];
      }
      x[i] /= aug[i][i];
    }

    return [...x, 1.0]; // Add h8 = 1
  }

  /// Bilinear interpolation sampling.
  img.Color? _bilinearSample(img.Image image, double x, double y) {
    if (x < 0 || y < 0 || x >= image.width - 1 || y >= image.height - 1) {
      // Clamp to edge
      final cx = x.clamp(0.0, (image.width - 1).toDouble()).round();
      final cy = y.clamp(0.0, (image.height - 1).toDouble()).round();
      return image.getPixel(cx, cy);
    }

    final x0 = x.floor();
    final y0 = y.floor();
    final x1 = x0 + 1;
    final y1 = y0 + 1;

    final dx = x - x0;
    final dy = y - y0;

    final p00 = image.getPixel(x0, y0);
    final p10 = image.getPixel(x1, y0);
    final p01 = image.getPixel(x0, y1);
    final p11 = image.getPixel(x1, y1);

    final r = (p00.r * (1 - dx) * (1 - dy) +
            p10.r * dx * (1 - dy) +
            p01.r * (1 - dx) * dy +
            p11.r * dx * dy)
        .round()
        .clamp(0, 255);
    final g = (p00.g * (1 - dx) * (1 - dy) +
            p10.g * dx * (1 - dy) +
            p01.g * (1 - dx) * dy +
            p11.g * dx * dy)
        .round()
        .clamp(0, 255);
    final b = (p00.b * (1 - dx) * (1 - dy) +
            p10.b * dx * (1 - dy) +
            p01.b * (1 - dx) * dy +
            p11.b * dx * dy)
        .round()
        .clamp(0, 255);

    return img.ColorRgb8(r, g, b);
  }
}

// ==========================================
// Edge Detection Helpers
// ==========================================

int _scanFromLeft(img.Image image, int w, int h) {
  // Scan columns from left, looking for first non-background column
  final step = h ~/ 20; // Sample 20 rows
  for (int x = 0; x < w ~/ 3; x++) {
    int edgeCount = 0;
    for (int y = 0; y < h; y += step) {
      if (x + 1 < w) {
        final curr = image.getPixel(x, y);
        final next = image.getPixel(x + 1, y);
        if (_pixelDifference(curr, next) > 30) edgeCount++;
      }
    }
    if (edgeCount > 3) return x;
  }
  return 0;
}

int _scanFromRight(img.Image image, int w, int h) {
  final step = h ~/ 20;
  for (int x = w - 1; x > w * 2 ~/ 3; x--) {
    int edgeCount = 0;
    for (int y = 0; y < h; y += step) {
      if (x - 1 >= 0) {
        final curr = image.getPixel(x, y);
        final prev = image.getPixel(x - 1, y);
        if (_pixelDifference(curr, prev) > 30) edgeCount++;
      }
    }
    if (edgeCount > 3) return x;
  }
  return w - 1;
}

int _scanFromTop(img.Image image, int w, int h) {
  final step = w ~/ 20;
  for (int y = 0; y < h ~/ 3; y++) {
    int edgeCount = 0;
    for (int x = 0; x < w; x += step) {
      if (y + 1 < h) {
        final curr = image.getPixel(x, y);
        final next = image.getPixel(x, y + 1);
        if (_pixelDifference(curr, next) > 30) edgeCount++;
      }
    }
    if (edgeCount > 3) return y;
  }
  return 0;
}

int _scanFromBottom(img.Image image, int w, int h) {
  final step = w ~/ 20;
  for (int y = h - 1; y > h * 2 ~/ 3; y--) {
    int edgeCount = 0;
    for (int x = 0; x < w; x += step) {
      if (y - 1 >= 0) {
        final curr = image.getPixel(x, y);
        final prev = image.getPixel(x, y - 1);
        if (_pixelDifference(curr, prev) > 30) edgeCount++;
      }
    }
    if (edgeCount > 3) return y;
  }
  return h - 1;
}

int _pixelDifference(img.Color a, img.Color b) {
  return ((a.r - b.r).abs() + (a.g - b.g).abs() + (a.b - b.b).abs()) ~/ 3;
}
