import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme/app_colors.dart';
import '../../data/services/ml/model/model_download_manager.dart';
import '../../data/services/ml/model/model_info.dart';

/// Screen for managing ML model downloads.
class ModelDownloadScreen extends StatefulWidget {
  final ModelDownloadManager downloadManager;

  const ModelDownloadScreen({super.key, required this.downloadManager});

  @override
  State<ModelDownloadScreen> createState() => _ModelDownloadScreenState();
}

class _ModelDownloadScreenState extends State<ModelDownloadScreen> {
  @override
  void initState() {
    super.initState();
    widget.downloadManager.initialize();
  }

  @override
  Widget build(BuildContext context) {
    final models = widget.downloadManager.availableModels;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Offline Models')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: models.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final model = models[index];
          return _ModelCard(
            model: model,
            downloadManager: widget.downloadManager,
            onChanged: () => setState(() {}),
          );
        },
      ),
    );
  }
}

class _ModelCard extends StatefulWidget {
  final ModelInfo model;
  final ModelDownloadManager downloadManager;
  final VoidCallback onChanged;

  const _ModelCard({
    required this.model,
    required this.downloadManager,
    required this.onChanged,
  });

  @override
  State<_ModelCard> createState() => _ModelCardState();
}

class _ModelCardState extends State<_ModelCard> {
  bool _downloading = false;
  double _progress = 0.0;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final state = widget.downloadManager.getState(widget.model.id);
    final isReady = state == ModelState.ready;
    final isDownloading = state == ModelState.downloading || _downloading;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isReady
              ? AppColors.success.withOpacity(0.3)
              : AppColors.border,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isReady
                      ? AppColors.success.withOpacity(0.15)
                      : AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isReady ? Icons.cloud_done : Icons.cloud_download_outlined,
                  color: isReady ? AppColors.success : AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.model.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'v\${widget.model.version} - \${widget.model.sizeFormatted}',
                      style: const TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (isReady)
                const Icon(Icons.check_circle, color: AppColors.success, size: 24),
            ],
          ),
          const SizedBox(height: 12),

          // Description
          Text(
            widget.model.description,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),

          // Progress bar (during download)
          if (isDownloading) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _progress,
                backgroundColor: AppColors.surfaceLight,
                color: AppColors.primary,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '\${(_progress * 100).toStringAsFixed(0)}%',
              style: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Error message
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, size: 16, color: AppColors.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: AppColors.error, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Action buttons
          if (!isReady && !isDownloading)
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: _download,
                icon: const Icon(Icons.download, size: 18),
                label: const Text('Download'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            )
          else if (isReady)
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                onPressed: _delete,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Remove'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.error),
                  foregroundColor: AppColors.error,
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

  Future<void> _download() async {
    setState(() {
      _downloading = true;
      _progress = 0.0;
      _error = null;
    });

    // Simulate progress updates
    // In real app, this comes from download manager callbacks
    for (var i = 0; i < 10; i++) {
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      setState(() => _progress = (i + 1) / 10);
    }

    final success = await widget.downloadManager.downloadModel(widget.model.id);

    if (!mounted) return;
    setState(() {
      _downloading = false;
      if (!success) _error = 'Download failed. Check your internet connection.';
    });
    widget.onChanged();
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Remove model?'),
        content: Text('Delete \${widget.model.name} from this device? '
            'You can download it again later.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await widget.downloadManager.deleteModel(widget.model.id);
      widget.onChanged();
    }
  }
}
