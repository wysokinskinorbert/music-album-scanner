import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../models/album.dart';
import '../collection/collection_stats_service.dart';

/// Generates a shareable infographic from collection stats.
class InfographicGenerator {
  static const _width = 1080.0;
  static const _height = 1920.0;

  Future<String?> generate({
    required GlobalKey repaintKey,
    required String collectionId,
  }) async {
    try {
      final boundary = repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: 1.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      final tempDir = await getTemporaryDirectory();
      final filePath = '\${tempDir.path}/infographic_\$collectionId.png';
      final file = File(filePath);
      await file.writeAsBytes(byteData.buffer.asUint8List());
      return filePath;
    } catch (e) {
      return null;
    }
  }
}

/// Infographic widget rendered to PNG for sharing.
class CollectionInfographic extends StatelessWidget {
  final CollectionStats stats;
  final List<Album> recentAlbums;

  const CollectionInfographic({
    super.key,
    required this.stats,
    required this.recentAlbums,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: InfographicGenerator._width,
      height: InfographicGenerator._height,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0A0E1A), Color(0xFF1A1040)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(60),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 80),

            // Header
            const Row(
              children: [
                Icon(Icons.library_music, color: AppColors.accent, size: 40),
                SizedBox(width: 16),
                Text(
                  'My Collection',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 52,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Album Scanner Stats',
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 24),
            ),

            const SizedBox(height: 60),

            // Overview stats grid
            Row(
              children: [
                _StatBlock(label: 'Albums', value: stats.totalAlbums.toString(), color: AppColors.primary),
                const SizedBox(width: 24),
                _StatBlock(label: 'Artists', value: stats.totalArtists.toString(), color: Colors.orange),
                const SizedBox(width: 24),
                _StatBlock(label: 'Genres', value: stats.totalGenres.toString(), color: Colors.green),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                _StatBlock(label: 'Labels', value: stats.totalLabels.toString(), color: Colors.teal),
                const SizedBox(width: 24),
                _StatBlock(label: 'Favorites', value: stats.favoritesCount.toString(), color: Colors.red),
                const SizedBox(width: 24),
                _StatBlock(
                  label: 'Year Range',
                  value: stats.yearRange.isNotEmpty ? stats.yearRange : 'N/A',
                  color: AppColors.accent,
                ),
              ],
            ),

            const SizedBox(height: 48),

            // Genre distribution
            const Text(
              'Top Genres',
              style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            ...stats.genreDistribution.entries.take(5).map((e) {
              final maxCount = stats.genreDistribution.values.first;
              final fraction = e.value / maxCount;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _GenreBar(genre: e.key, count: e.value, fraction: fraction),
              );
            }),

            const SizedBox(height: 36),

            // Top artists
            const Text(
              'Top Artists',
              style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            ...stats.topArtists.entries.take(5).toList().asMap().entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: 40,
                      child: Text(
                        '#\${entry.key + 1}',
                        style: TextStyle(color: AppColors.accent, fontSize: 20, fontWeight: FontWeight.w700),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        entry.key.key,
                        style: const TextStyle(color: Colors.white, fontSize: 22),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '\${entry.key.value}',
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 18),
                    ),
                  ],
                ),
              );
            }),

            const Spacer(),

            // Branding
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.album, color: AppColors.accent, size: 24),
                    SizedBox(width: 10),
                    Text(
                      'Album Scanner',
                      style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatBlock({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: TextStyle(color: color, fontSize: 32, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

class _GenreBar extends StatelessWidget {
  final String genre;
  final int count;
  final double fraction;

  const _GenreBar({required this.genre, required this.count, required this.fraction});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(genre, style: const TextStyle(color: Colors.white, fontSize: 18), overflow: TextOverflow.ellipsis),
        ),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              FractionallySizedBox(
                widthFactor: fraction.clamp(0.05, 1.0),
                child: Container(
                  height: 28,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppColors.primary, AppColors.accent]),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 30,
          child: Text('$count', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 16)),
        ),
      ],
    );
  }
}
