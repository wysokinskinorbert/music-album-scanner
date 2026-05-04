import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/album_model.dart';
import '../../../data/services/collection/collection_sort_service.dart';
import '../../../data/services/collection/collection_filter_service.dart';
import '../../collection/bloc/collection_bloc.dart';
import '../../collection/widgets/album_card.dart';
import '../../collection/widgets/filter_sort_sheet.dart';
import '../stats_dashboard_screen.dart';
import '../duplicates_screen.dart';
import '../../wishlist/wishlist_screen.dart';
import '../batch_scan_screen.dart';
import '../album_detail_screen.dart';

/// Collection screen with sort, filter, stats, and management features.
class CollectionScreen extends StatefulWidget {
  const CollectionScreen({super.key});

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  final _sortService = CollectionSortService();
  final _filterService = CollectionFilterService();

  SortConfig _sortConfig = const SortConfig();
  CollectionFilter _filter = const CollectionFilter();
  bool _isGridView = true;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CollectionBloc, CollectionState>(
      builder: (context, state) {
        final albums = state is CollectionLoaded ? state.albums : <Album>[];

        // Apply sort and filter
        final filtered = _filterService.filter(albums, _filter);
        final sorted = _sortService.sort(filtered, _sortConfig);

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Text(
              'Collection (\${albums.length})',
              style: const TextStyle(fontSize: 18),
            ),
            actions: [
              // View toggle
              IconButton(
                icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
                onPressed: () => setState(() => _isGridView = !_isGridView),
              ),
              // Filter/Sort
              IconButton(
                icon: Badge(
                  isLabelVisible: !_filter.isEmpty,
                  child: const Icon(Icons.filter_list),
                ),
                onPressed: () => _showFilterSheet(albums),
              ),
              // More options
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (action) => _handleMenuAction(action, albums),
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'stats', child: Text('Statistics')),
                  const PopupMenuItem(value: 'duplicates', child: Text('Find Duplicates')),
                  const PopupMenuItem(value: 'batch', child: Text('Batch Scan')),
                  const PopupMenuItem(value: 'wishlist', child: Text('Wishlist')),
                  const PopupMenuItem(value: 'export', child: Text('Export Collection')),
                ],
              ),
            ],
          ),
          body: sorted.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: () async {
                    context.read<CollectionBloc>().add(LoadCollection());
                  },
                  color: AppColors.primary,
                  child: _isGridView
                      ? _buildGridView(sorted)
                      : _buildListView(sorted),
                ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.album, size: 64, color: AppColors.textTertiary.withOpacity(0.5)),
          const SizedBox(height: 16),
          const Text(
            'No albums yet',
            style: TextStyle(color: AppColors.textTertiary, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            'Scan your first album to start building your collection!',
            style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _handleMenuAction('batch', []),
            icon: const Icon(Icons.camera_alt),
            label: const Text('Start Scanning'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridView(List<Album> albums) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.72,
      ),
      itemCount: albums.length,
      itemBuilder: (context, index) {
        return AlbumCard(
          album: albums[index],
          onTap: () => _openAlbumDetail(albums[index]),
        );
      },
    );
  }

  Widget _buildListView(List<Album> albums) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: albums.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final album = albums[index];
        return ListTile(
          dense: true,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.border, width: 0.5),
          ),
          tileColor: AppColors.surface,
          leading: const Icon(Icons.album, color: AppColors.primary, size: 36),
          title: Text(
            album.title ?? 'Unknown',
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '\${album.artist ?? "?"} · \${album.year ?? "?"}',
            style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
          ),
          trailing: album.isFavorite == true
              ? const Icon(Icons.favorite, color: Colors.red, size: 16)
              : null,
          onTap: () => _openAlbumDetail(album),
        );
      },
    );
  }

  void _openAlbumDetail(Album album) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AlbumDetailScreen(album: album)),
    );
  }

  Future<void> _showFilterSheet(List<Album> albums) async {
    final result = await showModalBottomSheet<(SortConfig, CollectionFilter)>(
      context: context,
      isScrollControlled: true,
      builder: (_) => FilterSortSheet(
        currentSort: _sortConfig,
        currentFilter: _filter,
        availableGenres: _filterService.extractGenres(albums),
        availableDecades: _filterService.extractDecades(albums),
        availableLabels: _filterService.extractLabels(albums),
      ),
    );

    if (result != null) {
      setState(() {
        _sortConfig = result.$1;
        _filter = result.$2;
      });
    }
  }

  void _handleMenuAction(String action, List<Album> albums) {
    switch (action) {
      case 'stats':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => StatsDashboardScreen(albums: albums)),
        );
      case 'duplicates':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DuplicatesScreen(albums: albums)),
        );
      case 'batch':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BatchScanScreen()),
        );
      case 'wishlist':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const WishlistScreen()),
        );
      case 'export':
        context.read<CollectionBloc>().add(ExportCollection());
    }
  }
}
