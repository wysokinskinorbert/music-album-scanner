import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import '../../core/theme/app_colors.dart';
import '../../data/services/image/image_editor_service.dart';
import '../../data/services/image/auto_enhancement_service.dart';
import '../../data/services/image/perspective_correction_service.dart';

/// Full-featured image editor screen for album cover photos.
class ImageEditorScreen extends StatefulWidget {
  final String imagePath;
  final VoidCallback? onRecognize;

  const ImageEditorScreen({
    super.key,
    required this.imagePath,
    this.onRecognize,
  });

  @override
  State<ImageEditorScreen> createState() => _ImageEditorScreenState();
}

class _ImageEditorScreenState extends State<ImageEditorScreen> {
  final _editor = ImageEditorService();
  final _enhancer = AutoEnhancementService();
  final _perspective = PerspectiveCorrectionService();

  img.Image? _originalImage;
  img.Image? _currentImage;
  Uint8List? _currentBytes;

  bool _isLoading = true;
  bool _isProcessing = false;
  EditorMode _mode = EditorMode.crop;

  // Adjustment values
  double _brightness = 0;
  double _contrast = 0;
  double _saturation = 1.0;
  double _gamma = 1.0;
  int _rotation = 0;

  // History for undo
  final List<img.Image> _history = [];
  static const int _maxHistory = 10;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    final image = await _editor.loadImage(widget.imagePath);
    if (image != null && mounted) {
      setState(() {
        _originalImage = image;
        _currentImage = image;
        _currentBytes = _editor.encodeJpg(image);
        _isLoading = false;
      });
      _history.add(image);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Edit Photo'),
        actions: [
          // Undo
          IconButton(
            icon: const Icon(Icons.undo),
            onPressed: _history.length > 1 ? _undo : null,
          ),
          // Reset
          IconButton(
            icon: const Icon(Icons.restart_alt),
            onPressed: _reset,
          ),
          // Done
          TextButton(
            onPressed: _saveAndReturn,
            child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                // Image preview
                Expanded(child: _buildPreview()),
                // Tool panel
                _buildToolPanel(),
              ],
            ),
    );
  }

  // ==========================================
  // Preview
  // ==========================================

  Widget _buildPreview() {
    return Container(
      color: Colors.black,
      child: Center(
        child: _currentBytes != null
            ? Image.memory(
                _currentBytes!,
                fit: BoxFit.contain,
              )
            : const Icon(Icons.image, size: 64, color: AppColors.textTertiary),
      ),
    );
  }

  // ==========================================
  // Tool Panel
  // ==========================================

  Widget _buildToolPanel() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Mode tabs
          _buildModeTabs(),
          // Active tool controls
          _buildActiveControls(),
        ],
      ),
    );
  }

  Widget _buildModeTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: EditorMode.values.map((mode) {
          final isActive = _mode == mode;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Text(mode.label),
              selected: isActive,
              onSelected: (_) => setState(() => _mode = mode),
              selectedColor: AppColors.primary.withOpacity(0.2),
              side: BorderSide(
                color: isActive ? AppColors.primary : AppColors.border,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActiveControls() {
    return switch (_mode) {
      EditorMode.crop => _buildCropControls(),
      EditorMode.adjust => _buildAdjustControls(),
      EditorMode.filters => _buildFilterControls(),
      EditorMode.perspective => _buildPerspectiveControls(),
      EditorMode.enhance => _buildEnhanceControls(),
    };
  }

  // ==========================================
  // Crop Controls
  // ==========================================

  Widget _buildCropControls() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            'Crop to album cover',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _cropButton('1:1', Icons.crop_square, () => _cropToRatio(1.0)),
              _cropButton('4:3', Icons.crop_3_2, () => _cropToRatio(4 / 3)),
              _cropButton('3:4', Icons.crop_portrait, () => _cropToRatio(3 / 4)),
              _cropButton('Free', Icons.crop_free, () => _cropToRatio(0)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cropButton(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: _isProcessing ? null : onTap,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // Adjust Controls
  // ==========================================

  Widget _buildAdjustControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          _sliderRow('Brightness', _brightness, -100, 100, (v) {
            setState(() => _brightness = v);
            _applyAdjustments();
          }),
          _sliderRow('Contrast', _contrast, -100, 100, (v) {
            setState(() => _contrast = v);
            _applyAdjustments();
          }),
          _sliderRow('Saturation', _saturation, 0.0, 2.0, (v) {
            setState(() => _saturation = v);
            _applyAdjustments();
          }),
          _sliderRow('Gamma', _gamma, 0.1, 3.0, (v) {
            setState(() => _gamma = v);
            _applyAdjustments();
          }),
          const SizedBox(height: 8),
          // Rotate / Flip buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _actionButton(Icons.rotate_left, 'Rotate L', () => _rotate(-90)),
              _actionButton(Icons.rotate_right, 'Rotate R', () => _rotate(90)),
              _actionButton(Icons.flip, 'Flip H', () => _flipH()),
              _actionButton(Icons.swap_vert, 'Flip V', () => _flipV()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sliderRow(String label, double value, double min, double max, Function(double) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: AppColors.primary,
                inactiveTrackColor: AppColors.surfaceLight,
                thumbColor: AppColors.primaryLight,
              ),
              child: Slider(
                value: value,
                min: min,
                max: max,
                onChanged: onChanged,
              ),
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              value is double && value == value.roundToDouble()
                  ? value.toInt().toString()
                  : value.toStringAsFixed(2),
              style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: _isProcessing ? null : onTap,
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.textSecondary, size: 20),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: AppColors.textTertiary, fontSize: 10),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // Filter Controls
  // ==========================================

  Widget _buildFilterControls() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            'Filters',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _filterButton('Grayscale', () => _applyFilter('grayscale')),
              _filterButton('Sepia', () => _applyFilter('sepia')),
              _filterButton('Sharpen', () => _applyFilter('sharpen')),
              _filterButton('Blur', () => _applyFilter('blur')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: _isProcessing ? null : onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: Center(
              child: Text(
                label[0],
                style: const TextStyle(
                  color: AppColors.primaryLight,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // Perspective Controls
  // ==========================================

  Widget _buildPerspectiveControls() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text(
            'Perspective Correction',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 4),
          const Text(
            'Automatically detects and straightens angled album covers.',
            style: TextStyle(color: AppColors.textTertiary, fontSize: 11),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _isProcessing ? null : _autoPerspective,
              icon: const Icon(Icons.auto_fix_high, size: 18),
              label: const Text('Auto-Correct Perspective'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // Enhance Controls
  // ==========================================

  Widget _buildEnhanceControls() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            'Auto-Enhancement',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: EnhancementMode.values.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final mode = EnhancementMode.values[index];
                return GestureDetector(
                  onTap: _isProcessing ? null : () => _applyEnhancement(mode),
                  child: Column(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: _enhanceGradient(mode),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Text(
                            mode.label[0],
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        mode.label,
                        style: const TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  LinearGradient _enhanceGradient(EnhancementMode mode) => switch (mode) {
        EnhancementMode.auto => const LinearGradient(
            colors: [AppColors.primary, AppColors.primaryLight]),
        EnhancementMode.vivid => const LinearGradient(
            colors: [Colors.orange, Colors.red]),
        EnhancementMode.warm => const LinearGradient(
            colors: [Colors.orange, Colors.amber]),
        EnhancementMode.cool => const LinearGradient(
            colors: [Colors.blue, Colors.cyan]),
        EnhancementMode.vintage => const LinearGradient(
            colors: [Colors.brown, Colors.amber]),
        EnhancementMode.highContrast => const LinearGradient(
            colors: [Colors.black54, Colors.white54]),
        EnhancementMode.lowLight => const LinearGradient(
            colors: [Colors.indigo, Colors.blue]),
      };

  // ==========================================
  // Operations
  // ==========================================

  void _cropToRatio(double ratio) async {
    if (_currentImage == null) return;
    setState(() => _isProcessing = true);

    await Future.delayed(const Duration(milliseconds: 100));

    final result = ratio == 0
        ? _editor.cropSquare(_currentImage!)
        : _editor.cropToAlbumRatio(_currentImage!, aspectRatio: ratio);

    _pushHistory(result);
    setState(() {
      _currentImage = result;
      _currentBytes = _editor.encodeJpg(result);
      _isProcessing = false;
    });
  }

  void _rotate(int degrees) async {
    if (_currentImage == null) return;
    setState(() => _isProcessing = true);

    final result = _editor.rotate(_currentImage!, degrees);
    _pushHistory(result);

    setState(() {
      _currentImage = result;
      _currentBytes = _editor.encodeJpg(result);
      _rotation = (_rotation + degrees) % 360;
      _isProcessing = false;
    });
  }

  void _flipH() {
    if (_currentImage == null) return;
    final result = _editor.flipHorizontal(_currentImage!);
    _pushHistory(result);
    setState(() {
      _currentImage = result;
      _currentBytes = _editor.encodeJpg(result);
    });
  }

  void _flipV() {
    if (_currentImage == null) return;
    final result = _editor.flipVertical(_currentImage!);
    _pushHistory(result);
    setState(() {
      _currentImage = result;
      _currentBytes = _editor.encodeJpg(result);
    });
  }

  void _applyAdjustments() {
    if (_originalImage == null || _history.isEmpty) return;

    // Apply to the last committed state (not to cumulative adjustments)
    final base = _history.last;
    var result = base;

    if (_brightness != 0) result = _editor.adjustBrightness(result, _brightness.round());
    if (_contrast != 0) result = _editor.adjustContrast(result, _contrast.round());
    if (_saturation != 1.0) result = _editor.adjustSaturation(result, _saturation);
    if (_gamma != 1.0) result = _editor.adjustGamma(result, _gamma);

    setState(() {
      _currentImage = result;
      _currentBytes = _editor.encodeJpg(result);
    });
  }

  void _applyFilter(String filter) {
    if (_currentImage == null) return;
    setState(() => _isProcessing = true);

    final result = switch (filter) {
      'grayscale' => _editor.grayscale(_currentImage!),
      'sepia' => _editor.sepia(_currentImage!),
      'sharpen' => _editor.sharpen(_currentImage!),
      'blur' => _editor.blur(_currentImage!),
      _ => _currentImage!,
    };

    _pushHistory(result);
    setState(() {
      _currentImage = result;
      _currentBytes = _editor.encodeJpg(result);
      _isProcessing = false;
    });
  }

  void _autoPerspective() async {
    if (_currentImage == null) return;
    setState(() => _isProcessing = true);

    await Future.delayed(const Duration(milliseconds: 100));
    final result = _perspective.autoCorrect(_currentImage!);

    _pushHistory(result);
    setState(() {
      _currentImage = result;
      _currentBytes = _editor.encodeJpg(result);
      _isProcessing = false;
    });
  }

  void _applyEnhancement(EnhancementMode mode) async {
    if (_currentImage == null) return;
    setState(() => _isProcessing = true);

    await Future.delayed(const Duration(milliseconds: 100));
    final result = _enhancer.autoEnhance(_currentImage!, mode: mode);

    _pushHistory(result.enhanced);
    setState(() {
      _currentImage = result.enhanced;
      _currentBytes = _editor.encodeJpg(result.enhanced);
      _isProcessing = false;
    });
  }

  // ==========================================
  // History
  // ==========================================

  void _pushHistory(img.Image image) {
    _history.add(image);
    if (_history.length > _maxHistory) {
      _history.removeAt(0);
    }
  }

  void _undo() {
    if (_history.length <= 1) return;
    _history.removeLast();
    final prev = _history.last;
    setState(() {
      _currentImage = prev;
      _currentBytes = _editor.encodeJpg(prev);
      _brightness = 0;
      _contrast = 0;
      _saturation = 1.0;
      _gamma = 1.0;
    });
  }

  void _reset() {
    if (_originalImage == null) return;
    _history.clear();
    _history.add(_originalImage!);
    setState(() {
      _currentImage = _originalImage;
      _currentBytes = _editor.encodeJpg(_originalImage!);
      _brightness = 0;
      _contrast = 0;
      _saturation = 1.0;
      _gamma = 1.0;
      _rotation = 0;
      _mode = EditorMode.crop;
    });
  }

  // ==========================================
  // Save
  // ==========================================

  Future<void> _saveAndReturn() async {
    if (_currentImage == null) return;

    // Save edited image over the original
    await _editor.saveImage(_currentImage!, widget.imagePath);

    if (mounted) {
      Navigator.pop(context, widget.imagePath);
    }
  }
}

enum EditorMode {
  crop,
  adjust,
  filters,
  perspective,
  enhance;

  String get label => switch (this) {
        crop => 'Crop',
        adjust => 'Adjust',
        filters => 'Filters',
        perspective => 'Perspective',
        enhance => 'Enhance',
      };
}

extension on EnhancementMode {
  String get label => switch (this) {
        EnhancementMode.auto => 'Auto',
        EnhancementMode.vivid => 'Vivid',
        EnhancementMode.warm => 'Warm',
        EnhancementMode.cool => 'Cool',
        EnhancementMode.vintage => 'Vintage',
        EnhancementMode.highContrast => 'Contrast',
        EnhancementMode.lowLight => 'Low Light',
      };
}
