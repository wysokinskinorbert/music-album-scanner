import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Centralized haptic feedback service.
/// All haptic events go through here so they can be toggled in settings.
class HapticService {
  static const _prefsKey = 'haptic_enabled';

  static bool _enabled = true;

  /// Initialize from preferences.
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_prefsKey) ?? true;
  }

  /// Toggle haptic feedback on/off.
  static Future<void> setEnabled(bool value) async {
    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, value);
  }

  static bool get isEnabled => _enabled;

  // ==========================================
  // Feedback Types
  // ==========================================

  /// Light tap - for button presses, tab switches.
  static void light() {
    if (!_enabled) return;
    HapticFeedback.lightImpact();
  }

  /// Medium impact - for confirmations, toggles.
  static void medium() {
    if (!_enabled) return;
    HapticFeedback.mediumImpact();
  }

  /// Heavy impact - for important actions.
  static void heavy() {
    if (!_enabled) return;
    HapticFeedback.heavyImpact();
  }

  /// Selection click - for scroll snaps, picker changes.
  static void selection() {
    if (!_enabled) return;
    HapticFeedback.selectionClick();
  }

  // ==========================================
  // App-Specific Events
  // ==========================================

  /// Camera shutter click.
  static void cameraShutter() {
    heavy();
  }

  /// Album successfully recognized.
  static void scanSuccess() {
    heavy();
    Future.delayed(const Duration(milliseconds: 150), () => medium());
  }

  /// Recognition failed.
  static void scanFail() {
    heavy();
    Future.delayed(const Duration(milliseconds: 100), () => heavy());
  }

  /// Album added to collection.
  static void albumAdded() {
    medium();
    Future.delayed(const Duration(milliseconds: 100), () => light());
  }

  /// Barcode detected.
  static void barcodeDetected() {
    medium();
  }

  /// Text extracted from cover.
  static void textExtracted() {
    light();
  }

  /// Duplicate found.
  static void duplicateFound() {
    heavy();
  }

  /// Wishlist item added.
  static void wishlistAdded() {
    light();
  }

  /// Wishlist item marked as found.
  static void wishlistFound() {
    medium();
    Future.delayed(const Duration(milliseconds: 100), () => medium());
  }

  /// Swipe action completed.
  static void swipeAction() {
    light();
  }

  /// Filter applied.
  static void filterApplied() {
    selection();
  }

  /// Export completed.
  static void exportComplete() {
    medium();
    Future.delayed(const Duration(milliseconds: 100), () => light());
    Future.delayed(const Duration(milliseconds: 200), () => light());
  }
}
