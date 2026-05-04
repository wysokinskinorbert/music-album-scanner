import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/album_model.dart';
import 'bloc/collection_bloc.dart';

/// Full detail view of a single album.
class AlbumDetailScreen extends StatelessWidget {
  final Album album;

  const AlbumDetailScreen({super.key, required this.album});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // Collapsible cover art header
          SliverAppBar(
            expandedHeight: 360,
            pinned: true,
            backgroundColor: AppColors.background,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.background.withOpacity(0.7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              PopupMenuButton(
                color: AppColors.surface,
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.background.withOpacity(0.7),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.more_vert, color: AppColors.textPrimary),
                ),
                onSelected: (value) => _handleMenuAction(context, value),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'share', child: Text('Share')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete from collection', style: TextStyle(color: AppColors.error))),
                ],
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _buildCoverArt(),
            ),
          ),
          // Album details
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTitleSection(),
                  const SizedBox(height: 20),
                  _buildMetadataChips(),
                  const SizedBox(height: 20),
                  if (album.tracklist.isNotEmpty) _buildTracklist(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoverArt() {
    if (album.userPhotoPath != null && File(album.userPhotoPath!).existsSync()) {
      return Image.file(
        File(album.userPhotoPath!),
        width: double.infinity,
        height: 360,
        fit: BoxFit.cover,
      );
    }
    return Container(
      color: AppColors.surfaceLight,
      child: const Center(
        child: Icon(Icons.album, size: 120, color: AppColors.textTertiary),
      ),
    );
  }

  Widget _buildTitleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          album.title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 26,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          album.artist,
          style: const TextStyle(
            color: AppColors.primaryLight,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (album.label != null) ...[
          const SizedBox(height: 4),
          Text(
            album.label!,
            style: const TextStyle(color: AppColors.textTertiary, fontSize: 14),
          ),
        ],
      ],
    );
  }

  Widget _buildMetadataChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (album.releaseYear != null)
          _buildChip(Icons.calendar_today, '${album.releaseYear}'),
        if (album.genre != null)
          _buildChip(Icons.music_note, album.genre!),
        if (album.country != null)
          _buildChip(Icons.flag, album.country!),
        if (album.format != null)
          _buildChip(Icons.album, album.format!),
        _buildChip(
          Icons.verified,
          '${(album.recognitionConfidence * 100).toInt()}% match',
        ),
      ],
    );
  }

  Widget _buildChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textTertiary),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildTracklist() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Tracklist',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${album.tracklist.length} tracks',
              style: const TextStyle(color: AppColors.textTertiary, fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...album.tracklist.asMap().entries.map((entry) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                child: Text(
                  '${entry.key + 1}',
                  style: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  entry.value,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }

  void _handleMenuAction(BuildContext context, String action) {
    switch (action) {
      case 'share':
        Share.share('${album.artist} - ${album.title} (${album.releaseYear ?? ''})');
        break;
      case 'delete':
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text('Delete album?'),
            content: Text('Remove "${album.title}" from your collection?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.read<CollectionBloc>().add(DeleteAlbum(album.id));
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        break;
    }
  }
}
