import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Result of a photo quality check.
class PhotoQuality {
  final bool isAcceptable;
  final double brightness;
  final double blurScore; // higher = less blurry
  final String? warning;

  const PhotoQuality({
    required this.isAcceptable,
    required this.brightness,
    required this.blurScore,
    this.warning,
  });

  factory PhotoQuality.good() => const PhotoQuality(
        isAcceptable: true,
        brightness: 0.6,
        blurScore: 0.8,
      );

  factory PhotoQuality.tooDark() => const PhotoQuality(
        isAcceptable: false,
        brightness: 0.15,
        blurScore: 0.7,
        warning: 'Photo is too dark. Try better lighting.',
      );

  factory PhotoQuality.tooBright() => const PhotoQuality(
        isAcceptable: false,
        brightness: 0.95,
        blurScore: 0.7,
        warning: 'Photo is overexposed. Reduce lighting.',
      );

  factory PhotoQuality.tooBlurry() => const PhotoQuality(
        isAcceptable: false,
        brightness: 0.6,
        blurScore: 0.2,
        warning: 'Photo is too blurry. Hold the camera steady.',
      );
}

/// A simple photo quality indicator shown after capture.
class PhotoQualityIndicator extends StatelessWidget {
  final PhotoQuality quality;

  const PhotoQualityIndicator({super.key, required this.quality});

  @override
  Widget build(BuildContext context) {
    if (quality.isAcceptable) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green.withOpacity(0.3)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 16),
            SizedBox(width: 6),
            Text(
              'Good quality',
              style: TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning_amber, color: Colors.orange, size: 16),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              quality.warning ?? 'Low quality photo',
              style: const TextStyle(color: Colors.orange, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
