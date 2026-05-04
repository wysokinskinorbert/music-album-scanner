import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

/// Utility for accessibility enhancements across the app.
class AccessibilityService {
  /// Wrap a widget with a semantic label for screen readers.
  static Widget semanticLabel({
    required String label,
    required Widget child,
    String? hint,
    bool isButton = false,
    bool isEnabled = true,
  }) {
    return Semantics(
      label: label,
      hint: hint,
      button: isButton,
      enabled: isEnabled,
      child: child,
    );
  }

  /// Create an accessible album card semantic.
  static Widget albumCardSemantics({
    required String title,
    required String artist,
    String? year,
    String? genre,
    required Widget child,
  }) {
    final parts = [title, 'by', artist];
    if (year != null) parts.add('released in $year');
    if (genre != null) parts.add('genre: $genre');

    return Semantics(
      label: parts.join(', '),
      child: child,
    );
  }

  /// Create an accessible confidence badge.
  static Widget confidenceSemantics({
    required double confidence,
    required Widget child,
  }) {
    final percentage = (confidence * 100).toStringAsFixed(0);
    final level = confidence >= 0.9
        ? 'high'
        : confidence >= 0.7
            ? 'medium'
            : 'low';
    return Semantics(
      label: 'Recognition confidence: $percentage percent, $level confidence',
      child: child,
    );
  }

  /// Create an accessible pipeline step.
  static Widget pipelineStepSemantics({
    required String stageName,
    required bool isActive,
    required bool isCompleted,
    required bool hasError,
    required Widget child,
  }) {
    final status = hasError
        ? 'failed'
        : isCompleted
            ? 'completed'
            : isActive
                ? 'in progress'
                : 'pending';
    return Semantics(
      label: '$stageName, $status',
      liveRegion: isActive,
      child: child,
    );
  }

  /// Ensure minimum tap target size (48x48 dp per WCAG).
  static Widget minTapTarget({
    required Widget child,
    double minSize = 48.0,
  }) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: minSize,
        minHeight: minSize,
      ),
      child: child,
    );
  }

  /// Check if the current color scheme has sufficient contrast.
  /// WCAG AA requires 4.5:1 for normal text, 3:1 for large text.
  static bool hasAdequateContrast(Color foreground, Color background) {
    final fgLuminance = foreground.computeLuminance();
    final bgLuminance = background.computeLuminance();
    final lighter = fgLuminance > bgLuminance ? fgLuminance : bgLuminance;
    final darker = fgLuminance > bgLuminance ? bgLuminance : fgLuminance;
    final ratio = (lighter + 0.05) / (darker + 0.05);
    return ratio >= 4.5; // WCAG AA
  }
}
