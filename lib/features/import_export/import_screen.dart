import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/haptic_service.dart';
import '../../data/services/export_import/import_service.dart';
import '../../data/repositories/album_repository.dart';
import '../collection/bloc/collection_bloc.dart';

/// Screen for importing albums from external sources.
class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  ImportFormat _selectedFormat = ImportFormat.discogsCsv;
  bool _isImporting = false;
  ImportResult? _result;

  final _formatInfo = {
    ImportFormat.discogsCsv: _FormatInfo(
      icon: Icons.table_chart,
      title: 'Discogs CSV',
      description: 'Import from Discogs collection export (CSV)',
      color: Colors.orange,
    ),
    ImportFormat.musicBrainzJson: _FormatInfo(
      icon: Icons.cloud,
      title: 'MusicBrainz JSON',
      description: 'Import from MusicBrainz collection export',
      color: Colors.blue,
    ),
    ImportFormat.genericJson: _FormatInfo(
      icon: Icons.code,
      title: 'Album Scanner JSON',
      description: 'Import from Album Scanner export',
      color: Colors.green,
    ),
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Import Collection', style: TextStyle(color: AppColors.textPrimary)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Info header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Select a file format and pick a file to import. Duplicates will be detected automatically.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Format selection
          const Text(
            'Source Format',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          ..._formatInfo.entries.map((entry) {
            final format = entry.key;
            final info = entry.value;
            final isSelected = _selectedFormat == format;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _FormatCard(
                info: info,
                isSelected: isSelected,
                onTap: () {
                  HapticService.selection();
                  setState(() => _selectedFormat = format);
                },
              ),
            );
          }),

          const SizedBox(height: 20),

          // Import button
          ElevatedButton.icon(
            onPressed: _isImporting ? null : _doImport,
            icon: _isImporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.file_upload),
            label: Text(_isImporting ? 'Importing...' : 'Pick File & Import'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),

          // Results
          if (_result != null) ...[
            const SizedBox(height: 24),
            _buildResultCard(),
          ],
        ],
      ),
    );
  }

  Widget _buildResultCard() {
    final r = _result!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: r.hasErrors ? Colors.orange.withOpacity(0.5) : Colors.green.withOpacity(0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                r.hasErrors ? Icons.warning_amber : Icons.check_circle,
                color: r.hasErrors ? Colors.orange : Colors.green,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Import Complete',
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                '\${(r.duration.inMilliseconds / 1000).toStringAsFixed(1)}s',
                style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Stats row
          Row(
            children: [
              _ResultStat(label: 'Imported', value: r.imported.toString(), color: Colors.green),
              const SizedBox(width: 12),
              _ResultStat(label: 'Duplicates', value: r.duplicates.toString(), color: Colors.orange),
              const SizedBox(width: 12),
              _ResultStat(label: 'Skipped', value: r.skipped.toString(), color: AppColors.textTertiary),
            ],
          ),

          // Errors
          if (r.errors.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(color: AppColors.border),
            const SizedBox(height: 8),
            Text(
              'Errors (\${r.errors.length})',
              style: const TextStyle(color: Colors.orange, fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            ...r.errors.take(5).map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(e, style: const TextStyle(color: AppColors.textTertiary, fontSize: 11)),
            )),
            if (r.errors.length > 5)
              Text(
                '... and \${r.errors.length - 5} more',
                style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _doImport() async {
    HapticService.medium();
    setState(() {
      _isImporting = true;
      _result = null;
    });

    try {
      final repository = context.read<AlbumRepository>();
      final service = ImportService(repository);
      final result = await service.importFromFile(_selectedFormat);

      if (mounted) {
        setState(() => _result = result);

        if (result.imported > 0) {
          HapticService.scanSuccess();
          context.read<CollectionBloc>().add(LoadCollection());
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _result = ImportResult(
            errors: ['Import failed: \$e'],
            duration: Duration.zero,
          );
        });
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }
}

// ==========================================
// Helper Widgets
// ==========================================

class _FormatInfo {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  const _FormatInfo({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });
}

class _FormatCard extends StatelessWidget {
  final _FormatInfo info;
  final bool isSelected;
  final VoidCallback onTap;

  const _FormatCard({
    required this.info,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: info.color.withOpacity(isSelected ? 0.1 : 0.03),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? info.color : AppColors.border,
            width: isSelected ? 1.5 : 0.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: info.color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(info.icon, color: info.color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(info.title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(info.description, style: const TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: info.color, size: 22),
          ],
        ),
      ),
    );
  }
}

class _ResultStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _ResultStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: AppColors.textTertiary, fontSize: 11)),
        ],
      ),
    );
  }
}
