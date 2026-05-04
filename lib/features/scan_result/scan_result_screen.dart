import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/album_model.dart';
import 'bloc/scan_result_bloc.dart';
import 'manual_search_screen.dart';

/// Displays recognition results with pipeline visualization.
class ScanResultScreen extends StatefulWidget {
  final String imagePath;

  const ScanResultScreen({super.key, required this.imagePath});

  @override
  State<ScanResultScreen> createState() => _ScanResultScreenState();
}

class _ScanResultScreenState extends State<ScanResultScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    // Auto-start recognition
    Future.microtask(() {
      context.read<ScanResultBloc>().add(StartRecognition(widget.imagePath));
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            context.read<ScanResultBloc>().add(CancelRecognition());
            Navigator.of(context).pop();
          },
        ),
        title: const Text('Recognition'),
      ),
      body: BlocConsumer<ScanResultBloc, ScanResultState>(
        listener: (context, state) {
          if (state is ScanResultSaved) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('"${state.album.title}" added to collection!'),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
              ),
            );
            Navigator.of(context).pop();
          }
        },
        builder: (context, state) {
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: switch (state) {
              ScanResultProcessing() => _buildProcessing(state),
              ScanResultSuccess() => _buildResult(state),
              ScanResultFailure() => _buildFailure(state),
              ScanResultSaved() => _buildProcessing(
                  const ScanResultProcessing(currentStep: 'Saving...')),
              _ => _buildProcessing(
                  const ScanResultProcessing(currentStep: 'Starting...')),
            },
          );
        },
      ),
    );
  }

  // ==========================================
  // Processing State
  // ==========================================

  Widget _buildProcessing(ScanResultProcessing state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Photo with scanning animation
            Stack(
              alignment: Alignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.file(
                    File(widget.imagePath),
                    width: 220,
                    height: 220,
                    fit: BoxFit.cover,
                  ),
                ),
                // Scanning overlay
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.primary
                              .withOpacity(0.5 + 0.5 * _pulseController.value),
                          width: 2,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Progress indicator
            if (state.totalSteps > 0) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: state.progress,
                  backgroundColor: AppColors.surfaceLight,
                  color: AppColors.primary,
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Current step label
            Text(
              state.currentStep ?? 'Analyzing...',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),

            // Step dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                4,
                (i) => Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < state.stepsCompleted
                        ? AppColors.primary
                        : AppColors.surfaceLight,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // Success State
  // ==========================================

  Widget _buildResult(ScanResultSuccess state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover + confidence
          _buildCoverWithBadge(state),
          const SizedBox(height: 20),

          // Pipeline summary
          if (state.pipelineSummary != null)
            _buildPipelineSummary(state.pipelineSummary!),
          if (state.pipelineSummary != null)
            const SizedBox(height: 16),

          // Extracted text (debug / info)
          if (state.extractedText != null && state.extractedText!.isNotEmpty)
            _buildExtractedTextCard(state.extractedText!),
          if (state.extractedText != null && state.extractedText!.isNotEmpty)
            const SizedBox(height: 16),

          // Album info card
          _buildInfoCard(state.album, state.source),
          const SizedBox(height: 20),

          // Tracklist
          if (state.album.tracklist.isNotEmpty) ...[
            _buildTracklist(state.album.tracklist),
            const SizedBox(height: 20),
          ],

          // Save button
          _buildSaveButton(state.album),
          const SizedBox(height: 12),

          // Retry button
          _buildRetryButton(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildCoverWithBadge(ScanResultSuccess state) {
    return Center(
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: state.album.userPhotoPath != null
                ? Image.file(
                    File(state.album.userPhotoPath!),
                    width: 240,
                    height: 240,
                    fit: BoxFit.cover,
                  )
                : Container(
                    width: 240,
                    height: 240,
                    color: AppColors.surfaceLight,
                    child: const Icon(Icons.album, size: 64, color: AppColors.textTertiary),
                  ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: state.confidence >= 0.8
                    ? AppColors.success
                    : state.confidence >= 0.6
                        ? AppColors.warning
                        : AppColors.error,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Text(
                '${(state.confidence * 100).toInt()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.background.withOpacity(0.8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    state.source == 'Barcode' ? Icons.qr_code : Icons.cloud,
                    size: 12,
                    color: AppColors.primaryLight,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    state.source,
                    style: const TextStyle(
                      color: AppColors.primaryLight,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPipelineSummary(String summary) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.route, size: 16, color: AppColors.textTertiary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              summary,
              style: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExtractedTextCard(String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.text_fields, size: 14, color: AppColors.textTertiary),
              SizedBox(width: 6),
              Text(
                'Extracted Text',
                style: TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            text.length > 200 ? '${text.substring(0, 200)}...' : text,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(Album album, String source) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            album.title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            album.artist,
            style: const TextStyle(
              color: AppColors.primaryLight,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          if (album.releaseYear != null)
            _buildInfoRow(Icons.calendar_today, '${album.releaseYear}'),
          if (album.label != null)
            _buildInfoRow(Icons.label, album.label!),
          if (album.genre != null)
            _buildInfoRow(Icons.music_note, album.genre!),
          if (album.country != null)
            _buildInfoRow(Icons.flag, album.country!),
          if (album.barcode != null)
            _buildInfoRow(Icons.qr_code, album.barcode!),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.textTertiary),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTracklist(List<String> tracks) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Tracklist',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${tracks.length}',
                style: const TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...tracks.asMap().entries.map((entry) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      '${entry.key + 1}',
                      style: const TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Widget _buildSaveButton(Album album) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: () {
          context.read<ScanResultBloc>().add(ConfirmAndSave(album));
        },
        icon: const Icon(Icons.add_circle_outline, size: 20),
        label: const Text(
          'Add to Collection',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildRetryButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: () {
          context.read<ScanResultBloc>().add(RetryRecognition(widget.imagePath));
        },
        icon: const Icon(Icons.refresh, size: 18),
        label: const Text('Try Again'),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // Failure State
  // ==========================================

  Widget _buildFailure(ScanResultFailure state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Captured photo
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(
                File(widget.imagePath),
                width: 180,
                height: 180,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 24),

            const Icon(Icons.search_off, size: 48, color: AppColors.error),
            const SizedBox(height: 16),

            Text(
              state.message,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 16),
              textAlign: TextAlign.center,
            ),

            // Pipeline debug info
            if (state.pipelineSummary != null) ...[
              const SizedBox(height: 12),
              Text(
                state.pipelineSummary!,
                style: const TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
                textAlign: TextAlign.center,
              ),
            ],

            if (state.extractedText != null && state.extractedText!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Detected text: "${state.extractedText!.length > 60 ? '${state.extractedText!.substring(0, 60)}...' : state.extractedText}"',
                style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],

            const SizedBox(height: 24),

            // Retry
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  context.read<ScanResultBloc>().add(RetryRecognition(widget.imagePath));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Retry Scan'),
              ),
            ),
            const SizedBox(height: 12),

            // Manual search
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ManualSearchScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('Search Manually'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primary),
                  foregroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget for animated scanning overlay.
class AnimatedBuilder extends AnimatedWidget {
  final Widget Function(BuildContext context, Widget? child) builder;

  const AnimatedBuilder({
    super.key,
    required super.listenable,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return builder(context, null);
  }
}
