import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../data/services/image/image_editor_service.dart';

/// Before/after comparison screen with interactive slider.
class PhotoComparisonScreen extends StatefulWidget {
  final Uint8List beforeBytes;
  final Uint8List afterBytes;

  const PhotoComparisonScreen({
    super.key,
    required this.beforeBytes,
    required this.afterBytes,
  });

  @override
  State<PhotoComparisonScreen> createState() => _PhotoComparisonScreenState();
}

class _PhotoComparisonScreenState extends State<PhotoComparisonScreen> {
  double _sliderPosition = 0.5;
  bool _showAfter = true; // Toggle full view

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Before / After'),
        actions: [
          IconButton(
            icon: Icon(_showAfter ? Icons.toggle_on : Icons.toggle_off),
            onPressed: () => setState(() => _showAfter = !_showAfter),
          ),
        ],
      ),
      body: Column(
        children: [
          // Comparison view
          Expanded(
            child: GestureDetector(
              onHorizontalDragUpdate: (details) {
                final box = context.findRenderObject() as RenderBox;
                final localX = details.localPosition.dx;
                setState(() {
                  _sliderPosition = (localX / box.size.width).clamp(0.0, 1.0);
                });
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // "Before" image (full)
                  Image.memory(
                    widget.beforeBytes,
                    fit: BoxFit.contain,
                  ),
                  // "After" image (clipped)
                  if (_showAfter)
                    ClipRect(
                      clipper: _SliderClipper(_sliderPosition),
                      child: Image.memory(
                        widget.afterBytes,
                        fit: BoxFit.contain,
                      ),
                    ),
                  // Slider line
                  if (_showAfter)
                    Positioned(
                      left: _sliderPosition * MediaQuery.of(context).size.width,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 2,
                        color: Colors.white.withOpacity(0.8),
                        child: Center(
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.9),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.compare_arrows,
                              size: 18,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Labels
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'BEFORE',
                        style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  if (_showAfter)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'AFTER',
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Instructions
          Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.surface,
            child: const Text(
              'Drag the slider to compare before and after.',
              style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

/// Clips the after image to the left of the slider position.
class _SliderClipper extends CustomClipper<Rect> {
  final double position;

  const _SliderClipper(this.position);

  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(0, 0, size.width * position, size.height);
  }

  @override
  bool shouldReclip(_SliderClipper oldClipper) {
    return oldClipper.position != position;
  }
}
