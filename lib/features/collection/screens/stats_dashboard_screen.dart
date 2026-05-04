import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/album.dart';
import '../../../data/services/collection/collection_stats_service.dart';

/// Collection statistics dashboard.
class StatsDashboardScreen extends StatelessWidget {
  final List<Album> albums;

  const StatsDashboardScreen({super.key, required this.albums});

  @override
  Widget build(BuildContext context) {
    final stats = CollectionStatsService().compute(albums);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Collection Stats')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOverviewCards(stats),
            const SizedBox(height: 20),
            _buildSectionTitle('Scan Methods'),
            _buildScanMethodCards(stats),
            const SizedBox(height: 20),
            _buildSectionTitle('Top Artists'),
            _buildDistributionList(stats.topArtists, Icons.person),
            const SizedBox(height: 20),
            _buildSectionTitle('Top Labels'),
            _buildDistributionList(stats.topLabels, Icons.label),
            const SizedBox(height: 20),
            _buildSectionTitle('Genres'),
            _buildGenreChips(stats.genreDistribution),
            const SizedBox(height: 20),
            _buildSectionTitle('Decades'),
            _buildDecadeBars(stats.decadeDistribution),
            const SizedBox(height: 20),
            _buildSectionTitle('Recent Additions'),
            _buildRecentList(stats),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildOverviewCards(CollectionStats stats) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _statCard('Albums', '${stats.totalAlbums}', Icons.album, AppColors.primary),
        _statCard('Artists', '${stats.totalArtists}', Icons.person, Colors.orange),
        _statCard('Genres', '${stats.totalGenres}', Icons.category, Colors.green),
        _statCard('Favorites', '${stats.favoritesCount}', Icons.favorite, Colors.red),
        _statCard('Years', stats.yearRange, Icons.date_range, Colors.blue),
        _statCard('Avg Match', stats.avgConfidenceLabel, Icons.verified, Colors.teal),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
              ),
            ],
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanMethodCards(CollectionStats stats) {
    return Row(
      children: [
        Expanded(
          child: _methodCard('Barcode', stats.scannedWithBarcode, stats.barcodeScanRate, AppColors.primary),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _methodCard('OCR', stats.scannedWithOcr, stats.scannedWithOcr / (stats.totalAlbums == 0 ? 1 : stats.totalAlbums), Colors.orange),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _methodCard('Offline', stats.scannedOffline, stats.offlineScanRate, Colors.green),
        ),
      ],
    );
  }

  Widget _methodCard(String label, int count, double rate, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(color: AppColors.textTertiary, fontSize: 11)),
          const SizedBox(height: 4),
          Text('$count', style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: rate,
            backgroundColor: AppColors.surfaceLight,
            valueColor: AlwaysStoppedAnimation(color),
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }

  Widget _buildDistributionList(Map<String, int> data, IconData icon) {
    if (data.isEmpty) {
      return const Text('No data yet', style: TextStyle(color: AppColors.textTertiary));
    }
    final maxVal = data.values.reduce((a, b) => a > b ? a : b);
    return Column(
      children: data.entries.map((e) {
        final pct = e.value / maxVal;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Icon(icon, size: 14, color: AppColors.textTertiary),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: Text(
                  e.key,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                flex: 4,
                child: LinearProgressIndicator(
                  value: pct,
                  backgroundColor: AppColors.surfaceLight,
                  valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 28,
                child: Text(
                  '${e.value}',
                  style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildGenreChips(Map<String, int> genres) {
    if (genres.isEmpty) {
      return const Text('No genres yet', style: TextStyle(color: AppColors.textTertiary));
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: genres.entries.map((e) {
        return Chip(
          label: Text(e.key),
          labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          backgroundColor: AppColors.surface,
          side: const BorderSide(color: AppColors.border, width: 0.5),
          avatar: CircleAvatar(
            backgroundColor: AppColors.primary.withOpacity(0.2),
            child: Text(
              '${e.value}',
              style: const TextStyle(fontSize: 10, color: AppColors.primary),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDecadeBars(Map<String, int> decades) {
    if (decades.isEmpty) {
      return const Text('No year data yet', style: TextStyle(color: AppColors.textTertiary));
    }
    final maxVal = decades.values.reduce((a, b) => a > b ? a : b);
    return Column(
      children: decades.entries.map((e) {
        final pct = e.value / maxVal;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              SizedBox(
                width: 48,
                child: Text(e.key, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: AppColors.surfaceLight,
                    valueColor: AlwaysStoppedAnimation(Colors.orange.withOpacity(0.7)),
                  ),
                ),
              ),
              SizedBox(
                width: 28,
                child: Text(
                  '${e.value}',
                  style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRecentList(CollectionStats stats) {
    if (stats.recentAdditions.isEmpty) {
      return const Text('No albums yet', style: TextStyle(color: AppColors.textTertiary));
    }
    return Column(
      children: stats.recentAdditions.map((album) {
        return ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.album, color: AppColors.primary),
          title: Text(
            album.title ?? 'Unknown',
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          ),
          subtitle: Text(
            album.artist ?? 'Unknown Artist',
            style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
          ),
          trailing: Text(
            album.year?.toString() ?? '',
            style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
          ),
        );
      }).toList(),
    );
  }
}
