import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/album_model.dart';
import 'bloc/scan_result_bloc.dart';

/// Displays recognition results and allows confirmation/editing.
class ScanResultScreen extends StatefulWidget {
  final String imagePath;

  const ScanResultScreen({super.key, required this.imagePath});

  @override
  State<ScanResultScreen> createState() => _ScanResultScreenState();
}

class _ScanResultScreenState extends State<ScanResultScreen> {
  @override
  void initState() {
    super.initState();
    // Auto-start recognition
    Future.microtask(() {
      context.read<ScanResultBloc>().add(StartRecognition(widget.imagePath));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
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
              ),
            );
            Navigator.of(context).pop();
          }
        },
        builder: (context, state) {
          return switch (state) {
            ScanResultProcessing() => _buildProcessing(),
            ScanResultSuccess() => _buildResult(state.album, state.confidence, state.source),
            ScanResultFailure() => _buildFailure(state.message),
            ScanResultSaved() => _buildProcessing(),
            _ => _buildProcessing(),
          };
        },
      ),
    );
  }

  Widget _buildProcessing() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Show captured image
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.file(
              File(widget.imagePath),
              width: 200,
              height: 200,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 32),
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 16),
          const Text(
            'Analyzing album cover...',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResult(Album album, double confidence, String source) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Album cover + confidence badge
          _buildCoverWithBadge(album, confidence),
          const SizedBox(height: 24),
          // Album info card
          _buildInfoCard(album, source),
          const SizedBox(height: 24),
          // Tracklist
          if (album.tracklist.isNotEmpty) ...[
            _buildTracklist(album.tracklist),
            const SizedBox(height: 24),
          ],
          // Save button (one-handed zone)
          _buildSaveButton(album),
          const SizedBox(height: 16),
          // Retry button
          _buildRetryButton(),
        ],
      ),
    );
  }

  Widget _buildCoverWithBadge(Album album, double confidence) {
    return Center(
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: album.userPhotoPath != null
                ? Image.file(
                    File(album.userPhotoPath!),
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
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: confidence >= 0.7 ? AppColors.success : AppColors.warning,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${(confidence * 100).toInt()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
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
          _buildInfoRow(Icons.calendar_today, '${album.releaseYear ?? 'Unknown year'}'),
          if (album.label != null)
            _buildInfoRow(Icons.label, album.label!),
          if (album.genre != null)
            _buildInfoRow(Icons.music_note, album.genre!),
          if (album.country != null)
            _buildInfoRow(Icons.flag, album.country!),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'Source: ${source.toUpperCase()}',
              style: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 11,
              ),
            ),
          ),
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
          Text(
            text,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildTracklist(List<String> tracks) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tracklist',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
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
      child: ElevatedButton(
        onPressed: () {
          context.read<ScanResultBloc>().add(ConfirmAndSave(album));
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const Text(
          'Add to Collection',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildRetryButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: () {
          context.read<ScanResultBloc>().add(RetryRecognition(widget.imagePath));
        },
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          'Try Again',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      ),
    );
  }

  Widget _buildFailure(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
              message,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
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
                child: const Text('Retry'),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => _showManualSearchDialog(),
              child: const Text('Search manually'),
            ),
          ],
        ),
      ),
    );
  }

  void _showManualSearchDialog() {
    final artistCtrl = TextEditingController();
    final albumCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Manual Search', style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: artistCtrl,
              decoration: const InputDecoration(hintText: 'Artist name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: albumCtrl,
              decoration: const InputDecoration(hintText: 'Album title'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<ScanResultBloc>().add(
                    ManualSearch(
                      artist: artistCtrl.text,
                      album: albumCtrl.text,
                    ),
                  );
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }
}
