import 'package:flutter/material.dart';

/// Ultra-modern dark-first color palette for Album Scanner.
class AppColors {
  AppColors._();

  // Primary - Electric Violet
  static const Color primary = Color(0xFF7C3AED);
  static const Color primaryLight = Color(0xFFA78BFA);
  static const Color primaryDark = Color(0xFF5B21B6);

  // Accent - Neon Cyan
  static const Color accent = Color(0xFF06B6D4);
  static const Color accentLight = Color(0xFF67E8F9);

  // Backgrounds
  static const Color background = Color(0xFF0F0F14);
  static const Color surface = Color(0xFF1A1A24);
  static const Color surfaceLight = Color(0xFF24243A);
  static const Color cardBackground = Color(0xFF1E1E2E);

  // Text
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textTertiary = Color(0xFF64748B);

  // Status
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Borders / Dividers
  static const Color border = Color(0xFF2D2D44);
  static const Color divider = Color(0xFF1E1E30);

  // Gradient
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, accent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient scanGradient = LinearGradient(
    colors: [Color(0xFF7C3AED), Color(0xFF06B6D4), Color(0xFF7C3AED)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
