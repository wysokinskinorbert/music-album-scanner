import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import '../../core/theme/app_colors.dart';
import '../../data/services/image/image_editor_service.dart';
import '../../data/services/image/auto_enhancement_service.dart';
import '../image_editor/image_editor_screen.dart';
import '../image_editor/photo_comparison_screen.dart';
import 'bloc/scan_result_bloc.dart';
import 'scan_result_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Intermediate screen after photo capture.
/// Shows preview with options: Edit, Auto-Enhance, Recognize.
class EditPreviewScreen extends StatefulWidget {
  final String imagePath;

  const EditPreviewScreen({super.key, required this.imagePath});

  @override
  State<EditPreviewScreen> createState() => _EditPreviewScreenState();
}

class _EditPreviewScreenState extends State<EditPreviewScreen> {
  final _editor = ImageEditorService();
  final _enhancer = AutoEnhancementService();

  String _currentPath = '';
  Uint8List? _originalBytes;
  Uint8List? _enhancedBytes;
  bool _isEnhancing = false;
  bool _useEnhanced = false;

  @override
  void initState() {
    super.initState();
    _currentPath = widget.imagePath;
    _loadOriginal();
  }

  Future<void> _loadOriginal() async {
    final file = File(_currentPath);
    if (await file.exists()) {
      final bytes = await file.readAsBytes();
      setState(() => _originalBytes = bytes);
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
        title: const Text('Preview'),
      ),
      body: Column(
        children: [
          // Photo preview
          Expanded(
            child: Container(
              color: Colors.black,
              child: Center(
                child: _useEnhanced && _enhancedBytes != null
                    ? Image.memory(_enhancedBytes!, fit: BoxFit.contain)
                    : _originalBytes != null
                        ? Image.memory(_originalBytes!, fit: BoxFit.contain)
                        : const CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
          ),

          // Quick actions bar
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            color: AppColors.surface,
            child: Column(
              children: [
                // Enhancement toggle
                if (_enhancedBytes != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Switch(
                          value: _useEnhanced,
                          onChanged: (v) => setState(() => _useEnhanced = v),
                          activeColor: AppColors.primary,
                        ),
                        const Text(
                          'Use enhanced version',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            if (_originalBytes != null && _enhancedBytes != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PhotoComparisonScreen(
                                    beforeBytes: _originalBytes!,
                                    afterBytes: _enhancedBytes!,
                                  ),
                                ),
                              );
                            }
                          },
                          child: const Text('Compare'),
                        ),
                      ],
                    ),
                  ),

                // Action buttons
                Row(
                  children: [
                    // Edit
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _openEditor,
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Edit'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Auto-Enhance
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isEnhancing ? null : _autoEnhance,
                        icon: _isEnhancing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.auto_fix_high, size: 18),
                        label: const Text('Enhance'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.warning,
                          side: const BorderSide(color: AppColors.warning),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Recognize (primary action)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _recognize(),
                        icon: const Icon(Icons.search, size: 18),
                        label: const Text('Scan'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openEditor() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => ImageEditorScreen(imagePath: _currentPath),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _currentPath = result;
        _useEnhanced = false;
        _enhancedBytes = null;
      });
      await _loadOriginal();
    }
  }

  Future<void> _autoEnhance() async {
    setState(() => _isEnhancing = true);

    final image = await _editor.loadImage(_currentPath);
    if (image == null) {
      setState(() => _isEnhancing = false);
      return;
    }

    final result = _enhancer.autoEnhance(image);
    final enhancedBytes = _editor.encodeJpg(result.enhanced);

    setState(() {
      _enhancedBytes = enhancedBytes;
      _useEnhanced = true;
      _isEnhancing = false;
    });
  }

  void _recognize() {
    // If user chose enhanced, save it first
    final pathToRecognize = _currentPath;

    if (_useEnhanced && _enhancedBytes != null) {
      // Save enhanced to a temp path
      final enhancedPath = _currentPath.replaceAll('.jpg', '_enhanced.jpg');
      File(enhancedPath).writeAsBytesSync(_enhancedBytes!);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ScanResultScreen(imagePath: enhancedPath),
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ScanResultScreen(imagePath: pathToRecognize),
        ),
      );
    }
  }
}
