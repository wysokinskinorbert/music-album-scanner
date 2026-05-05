import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/collection/batch_scan_service.dart';

/// Batch scan screen - scan multiple albums in sequence.
class BatchScanScreen extends StatefulWidget {
  const BatchScanScreen({super.key});

  @override
  State<BatchScanScreen> createState() => _BatchScanScreenState();
}

class _BatchScanScreenState extends State<BatchScanScreen> {
  final List<String> _selectedImages = [];
  bool _isScanning = false;
  BatchScanResult? _result;
  int _currentIndex = 0;
  BatchScanItem? _currentItem;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Batch Scan'),
        actions: [
          if (_selectedImages.isNotEmpty && !_isScanning)
            TextButton(
              onPressed: _startScan,
              child: const Text('Start', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: _isScanning ? _buildScanningView() : _buildSetupView(),
    );
  }

  Widget _buildSetupView() {
    return Column(
      children: [
        // Instructions
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.primary, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Select multiple album photos to scan them all at once. '
                  'Photos will be processed sequentially.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ),
            ],
          ),
        ),

        // Add photos buttons
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _pickFromGallery,
                  icon: const Icon(Icons.photo_library, size: 18),
                  label: const Text('From Gallery'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickFromCamera,
                  icon: const Icon(Icons.camera_alt, size: 18),
                  label: const Text('Camera'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Selected images count
        if (_selectedImages.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  '${_selectedImages.length} photos selected',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() => _selectedImages.clear()),
                  child: const Text('Clear all', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ),

        // Image grid
        Expanded(
          child: _selectedImages.isEmpty
              ? const Center(
                  child: Text(
                    'No photos selected yet',
                    style: TextStyle(color: AppColors.textTertiary, fontSize: 14),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: _selectedImages.length,
                  itemBuilder: (context, index) {
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            File(_selectedImages[index]),
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        ),
                        // Remove button
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedImages.removeAt(index)),
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                        // Index
                        Positioned(
                          bottom: 4,
                          left: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(color: Colors.white, fontSize: 10),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),

        // Results (if scan completed)
        if (_result != null) _buildResultSummary(),
      ],
    );
  }

  Widget _buildScanningView() {
    return Column(
      children: [
        // Progress header
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Text(
                'Scanning $_currentIndex of ${_selectedImages.length}',
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _currentIndex / _selectedImages.length,
                  backgroundColor: AppColors.surfaceLight,
                  valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${(_currentIndex / _selectedImages.length * 100).toStringAsFixed(0)}% complete',
                style: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
              ),
            ],
          ),
        ),

        // Current photo
        if (_currentItem != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                Text(
                  'Current photo:',
                  style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    height: 200,
                    width: double.infinity,
                    child: Image.file(
                      File(_currentItem!.imagePath),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Recognizing...',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildResultSummary() {
    if (_result == null) return const SizedBox.shrink();
    final r = _result!;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text('Results', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('${r.duration.inSeconds}s', style: const TextStyle(color: AppColors.textTertiary, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _resultChip('Success', r.successes, Colors.green),
              _resultChip('Failed', r.failures, Colors.red),
              _resultChip('Skipped',
                  r.items.where((i) => i.status == BatchScanItemStatus.skipped).length, Colors.orange),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: r.successRate,
            backgroundColor: AppColors.surfaceLight,
            valueColor: AlwaysStoppedAnimation(
              r.successRate >= 0.7 ? Colors.green : r.successRate >= 0.4 ? Colors.orange : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultChip(String label, int count, Color color) {
    return Column(
      children: [
        Text('$count', style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w700)),
        Text(label, style: TextStyle(color: AppColors.textTertiary, fontSize: 11)),
      ],
    );
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage(imageQuality: 85);
    if (images.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(images.map((i) => i.path));
        _result = null;
      });
    }
  }

  Future<void> _pickFromCamera() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (image != null) {
      setState(() {
        _selectedImages.add(image.path);
        _result = null;
      });
    }
  }

  Future<void> _startScan() async {
    setState(() {
      _isScanning = true;
      _currentIndex = 0;
      _result = null;
    });

    // Note: In production, BatchScanService would be injected via BLoC/Provider
    // This is a simplified UI-only implementation
    // The actual scan logic is in BatchScanService

    for (int i = 0; i < _selectedImages.length; i++) {
      setState(() {
        _currentIndex = i + 1;
        _currentItem = BatchScanItem(
          imagePath: _selectedImages[i],
          index: i,
          status: BatchScanItemStatus.processing,
        );
      });

      // Simulate processing delay (real implementation calls BatchScanService)
      await Future.delayed(const Duration(seconds: 1));
    }

    setState(() {
      _isScanning = false;
      _currentItem = null;
    });
  }
}
