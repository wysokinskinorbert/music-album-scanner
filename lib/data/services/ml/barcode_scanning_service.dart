import 'dart:io';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';

/// Scans barcodes (UPC/EAN/ISBN) from album covers using Google ML Kit.
/// Album barcodes are typically EAN-13 or UPC-A format on the back cover.
class BarcodeScanningService {
  final BarcodeScanner _scanner = BarcodeScanner(
    formats: [
      BarcodeFormat.ean13,   // Most common for albums
      BarcodeFormat.ean13,    // North American albums
      BarcodeFormat.ean8,    // Some releases
      BarcodeFormat.qrCode,  // Modern releases may have QR
    ],
  );

  /// Scan a single image for barcodes.
  Future<BarcodeResult> scanImage(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);

    try {
      final barcodes = await _scanner.processImage(inputImage);

      if (barcodes.isEmpty) {
        return BarcodeResult.empty();
      }

      // Prefer EAN-13 / UPC-A over QR codes
      final sorted = List<Barcode>.from(barcodes)..sort((a, b) {
        final priorityA = _formatPriority(a.format);
        final priorityB = _formatPriority(b.format);
        return priorityA.compareTo(priorityB);
      });

      final primary = sorted.first;
      return BarcodeResult(
        barcode: primary.rawValue ?? '',
        format: _formatName(primary.format),
        rawBarcodes: sorted.map((b) => b.rawValue ?? '').toList(),
        isAlbumBarcode: _isLikelyAlbumBarcode(primary.rawValue, primary.format),
      );
    } catch (e) {
      return BarcodeResult.error(e.toString());
    }
  }

  /// Scan from camera live feed (for real-time barcode detection).
  Future<BarcodeResult> scanCameraImage(InputImage inputImage) async {
    try {
      final barcodes = await _scanner.processImage(inputImage);

      if (barcodes.isEmpty) {
        return BarcodeResult.empty();
      }

      final primary = barcodes.first;
      return BarcodeResult(
        barcode: primary.rawValue ?? '',
        format: _formatName(primary.format),
        rawBarcodes: barcodes.map((b) => b.rawValue ?? '').toList(),
        isAlbumBarcode: _isLikelyAlbumBarcode(primary.rawValue, primary.format),
      );
    } catch (e) {
      return BarcodeResult.error(e.toString());
    }
  }

  /// Check if barcode looks like an album barcode.
  /// Album barcodes are typically 12-13 digits starting with specific prefixes.
  bool _isLikelyAlbumBarcode(String? value, BarcodeFormat format) {
    if (value == null) return false;
    if (format == BarcodeFormat.qrCode) return false;

    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length >= 12 && digits.length <= 13;
  }

  int _formatPriority(BarcodeFormat format) {
    switch (format) {
      case BarcodeFormat.ean13:
        return 0;
      case BarcodeFormat.ean13:
        return 1;
      case BarcodeFormat.ean8:
        return 2;
      default:
        return 3;
    }
  }

  String _formatName(BarcodeFormat format) {
    switch (format) {
      case BarcodeFormat.ean13:
        return 'EAN-13';
      case BarcodeFormat.ean13:
        return 'UPC-A';
      case BarcodeFormat.ean8:
        return 'EAN-8';
      case BarcodeFormat.qrCode:
        return 'QR';
      default:
        return 'Unknown';
    }
  }

  void dispose() {
    _scanner.close();
  }
}

/// Result of barcode scanning.
class BarcodeResult {
  final String barcode;
  final String format;
  final List<String> rawBarcodes;
  final bool isAlbumBarcode;
  final String? errorMessage;

  const BarcodeResult({
    required this.barcode,
    required this.format,
    required this.rawBarcodes,
    required this.isAlbumBarcode,
    this.errorMessage,
  });

  factory BarcodeResult.empty() => const BarcodeResult(
        barcode: '',
        format: '',
        rawBarcodes: [],
        isAlbumBarcode: false,
      );

  factory BarcodeResult.error(String message) => BarcodeResult(
        barcode: '',
        format: '',
        rawBarcodes: [],
        isAlbumBarcode: false,
        errorMessage: message,
      );

  bool get hasBarcode => barcode.isNotEmpty;
  bool get hasError => errorMessage != null;
}
