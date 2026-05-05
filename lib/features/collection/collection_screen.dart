import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/album_model.dart';
import 'bloc/collection_bloc.dart';
import 'widgets/album_card.dart';
import 'album_detail_screen.dart';

/// Displays user's album collection with search.
class CollectionScreen extends StatefulWidget {
  const CollectionScreen({super.key});

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  final _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header + Search
            _buildHeader(),
            // Album list
            Expanded(child: _buildAlbumList()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'My Collection',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              IconButton(
                icon: Icon(
                  _isSearching ? Icons.close : Icons.search,
                  color: AppColors.textSecondary,
                ),
                onPressed: () {
                  setState(() {
                    _isSearching = !_isSearching;
                    if (!_isSearching) {
                      _searchController.clear();
                      context.read<CollectionBloc>().add(ClearSearch());
                    }
                  });
                },
              ),
            ],
          ),
          if (_isSearching) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: (query) {
                if (query.isEmpty) {
                  context.read<CollectionBloc>().add(ClearSearch());
                } else {
                  context.read<CollectionBloc>().add(SearchCollection(query));
                }
              },
              decoration: InputDecoration(
                hintText: 'Search albums or artists...',
                prefixIcon: const Icon(Icons.search, color: AppColors.textTertiary),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: AppColors.textTertiary),
                        onPressed: () {
                          _searchController.clear();
                          context.read<CollectionBloc>().add(ClearSearch());
                        },
                      )
                    : null,
              ),
            ),
          ],
          const SizedBox(height: 8),
          // Stats
          BlocBuilder<CollectionBloc, CollectionState>(
            builder: (context, state) {
              final count = state is CollectionLoaded ? state.totalCount : 0;
              return Text(
                '$count album${count != 1 ? 's' : ''}',
                style: const TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 14,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAlbumList() {
    return BlocBuilder<CollectionBloc, CollectionState>(
      builder: (context, state) {
        return switch (state) {
          CollectionLoading() => const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          CollectionLoaded(:final albums) => albums.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async {
                    context.read<CollectionBloc>().add(LoadCollection());
                  },
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.72,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: albums.length,
                    itemBuilder: (context, index) {
                      return AlbumCard(
                        album: albums[index],
                        onTap: () => _openDetail(albums[index]),
                      );
                    },
                  ),
                ),
          CollectionError(:final message) => Center(
              child: Text(
                message,
                style: const TextStyle(color: AppColors.error),
              ),
            ),
          _ => const SizedBox.shrink(),
        };
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.album_outlined,
                size: 40,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Your collection is empty',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Scan your first album to get started!',
              style: TextStyle(color: AppColors.textTertiary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _openDetail(Album album) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AlbumDetailScreen(album: album),
      ),
    );
  }
}
