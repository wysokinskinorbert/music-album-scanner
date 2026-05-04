import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/album_model.dart';
import '../../../data/services/collection/duplicate_detector_service.dart';

/// Screen for reviewing and resolving duplicate albums.
class DuplicatesScreen extends StatefulWidget {
  final List<Album> albums;

  const DuplicatesScreen({super.key, required this.albums});

  @override
  State<DuplicatesScreen> createState() => _DuplicatesScreenState();
}

class _DuplicatesScreenState extends State<DuplicatesScreen> {
  late Future<DuplicateScanResult> _scanFuture;

  @override
  void initState() {
    super.initState();
    _scanFuture = _runScan();
  }

  Future<DuplicateScanResult> _runScan() async {
    return DuplicateDetectorService().detectDuplicates(widget.albums);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Duplicate Finder')),
      body: FutureBuilder<DuplicateScanResult>(
        future: _scanFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 16),
                  Text('Scanning for duplicates...', style: TextStyle(color: AppColors.textTertiary)),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final result = snapshot.data!;
          if (result.totalDuplicates == 0) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, size: 64, color: Colors.green),
                  const SizedBox(height: 16),
                  const Text(
                    'No duplicates found!',
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Scanned ${result.albumsScanned} albums in ${result.scanDuration.inMilliseconds}ms',
                    style: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Summary bar
              Container(
                padding: const EdgeInsets.all(16),
                color: AppColors.surface,
                child: Row(
                  children: [
                    Icon(Icons.content_copy, color: AppColors.warning, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '${result.totalDuplicates} duplicate pairs found',
                      style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    Text(
                      '${result.scanDuration.inMilliseconds}ms',
                      style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              // Duplicate list
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: result.duplicates.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final pair = result.duplicates[index];
                    return _DuplicateCard(pair: pair);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DuplicateCard extends StatelessWidget {
  final DuplicatePair pair;

  const _DuplicateCard({required this.pair});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warning.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Icon(_typeIcon(pair.type), size: 14, color: AppColors.warning),
                const SizedBox(width: 6),
                Text(
                  pair.reason,
                  style: const TextStyle(color: AppColors.warning, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Text(
                  pair.similarityLabel,
                  style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
                ),
              ],
            ),
          ),
          // Album 1
          _albumRow(pair.album1, context),
          const Divider(height: 1, color: AppColors.border),
          // Album 2
          _albumRow(pair.album2, context),
          // Actions
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, pair.album2),
                  child: const Text('Remove duplicate', style: TextStyle(color: Colors.red)),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Keep both'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _typeIcon(DuplicateType type) => switch (type) {
        DuplicateType.exactMatch => Icons.copy,
        DuplicateType.barcodeMatch => Icons.qr_code,
        DuplicateType.fuzzyTitle => Icons.text_fields,
        DuplicateType.musicBrainzId => Icons.fingerprint,
      };

  Widget _albumRow(Album album, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Icon(Icons.album, color: AppColors.primary, size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  album.title ?? 'Unknown',
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${album.artist ?? '?'} · ${album.year ?? '?'}',
                  style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
