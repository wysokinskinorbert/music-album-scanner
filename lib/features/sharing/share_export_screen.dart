import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/haptic_service.dart';
import '../../data/services/sharing/share_service.dart';
import '../../data/services/sharing/instagram_stories_generator.dart';
import '../../data/services/sharing/infographic_generator.dart';
import '../../data/services/export_import/export_service.dart';
import '../../data/models/album_model.dart';
import '../collection/bloc/collection_bloc.dart';

/// Screen for sharing and exporting album data.
class ShareExportScreen extends StatefulWidget {
  final Album? singleAlbum;

  const ShareExportScreen({super.key, this.singleAlbum});

  @override
  State<ShareExportScreen> createState() => _ShareExportScreenState();
}

class _ShareExportScreenState extends State<ShareExportScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _shareService = ShareService();
  final _exportService = ExportService();
  final _igKey = GlobalKey();
  final _infographicKey = GlobalKey();
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Share & Export', style: TextStyle(color: AppColors.textPrimary)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textTertiary,
          tabs: const [
            Tab(text: 'Share'),
            Tab(text: 'Instagram'),
            Tab(text: 'Export'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildShareTab(),
          _buildInstagramTab(),
          _buildExportTab(),
        ],
      ),
    );
  }

  // ==========================================
  // Share Tab
  // ==========================================

  Widget _buildShareTab() {
    final album = widget.singleAlbum;

    if (album != null) {
      return _buildSingleAlbumShare(album);
    }

    return BlocBuilder<CollectionBloc, CollectionState>(
      builder: (context, state) {
        final albums = state is CollectionLoaded ? state.albums : <Album>[];
        return _buildCollectionShare(albums);
      },
    );
  }

  Widget _buildSingleAlbumShare(Album album) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Album preview
        if (album.coverImagePath != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.file(
              File(album.coverImagePath!),
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          )
        else
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.album, size: 60, color: AppColors.textTertiary),
          ),
        const SizedBox(height: 16),
        Text(album.title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
        Text(album.artist, style: const TextStyle(color: AppColors.textSecondary, fontSize: 16)),
        const SizedBox(height: 24),

        // Share options
        _ShareOptionCard(
          icon: Icons.share,
          title: 'Share as Text',
          subtitle: 'Album info, tracklist, and details',
          onTap: () => _shareService.shareAlbumText(album),
        ),
        _ShareOptionCard(
          icon: Icons.image,
          title: 'Share with Cover',
          subtitle: 'Text + album cover image',
          onTap: () => _shareService.shareAlbumWithImage(album),
        ),
        _ShareOptionCard(
          icon: Icons.copy,
          title: 'Copy to Clipboard',
          subtitle: 'Copy album details as text',
          onTap: () async {
            await _shareService.copyAlbumToClipboard(album);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied to clipboard'), backgroundColor: Colors.green),
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildCollectionShare(List<Album> albums) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Share Collection',
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          '\${albums.length} albums',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        const SizedBox(height: 20),
        _ShareOptionCard(
          icon: Icons.list,
          title: 'Share as List',
          subtitle: 'All albums in a text list',
          onTap: () => _shareService.shareAlbumList(albums),
        ),
        _ShareOptionCard(
          icon: Icons.auto_graph,
          title: 'Share Infographic',
          subtitle: 'Visual stats card for social media',
          onTap: () => _shareInfographic(albums),
        ),
      ],
    );
  }

  // ==========================================
  // Instagram Tab
  // ==========================================

  Widget _buildInstagramTab() {
    final album = widget.singleAlbum;
    if (album == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.instagram, size: 64, color: AppColors.textTertiary),
              SizedBox(height: 16),
              Text(
                'Open an album to generate an Instagram Story',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final coverImage = album.coverImagePath != null ? File(album.coverImagePath!) : null;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Preview (scaled down)
        Container(
          height: 480,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: InstagramStoriesGenerator._width / 3,
              height: InstagramStoriesGenerator._height / 3,
              child: RepaintBoundary(
                key: _igKey,
                child: InstagramStoryCard(album: album, coverImage: coverImage),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '1080 x 1920 - Stories format',
          style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: () => _shareInstagramStory(album),
          icon: const Icon(Icons.share),
          label: const Text('Share to Instagram'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.pink,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // Export Tab
  // ==========================================

  Widget _buildExportTab() {
    return BlocBuilder<CollectionBloc, CollectionState>(
      builder: (context, state) {
        final albums = state is CollectionLoaded ? state.albums : <Album>[];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Export Collection',
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '\${albums.length} albums will be exported',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 20),
            _ExportFormatCard(
              icon: Icons.code,
              title: 'JSON',
              subtitle: 'Structured data, re-importable',
              color: Colors.amber,
              isExporting: _isExporting,
              onTap: () => _doExport(albums, ExportFormat.json),
            ),
            _ExportFormatCard(
              icon: Icons.table_chart,
              title: 'CSV',
              subtitle: 'Spreadsheet compatible (Excel, Google Sheets)',
              color: Colors.green,
              isExporting: _isExporting,
              onTap: () => _doExport(albums, ExportFormat.csv),
            ),
            _ExportFormatCard(
              icon: Icons.picture_as_pdf,
              title: 'PDF',
              subtitle: 'Printable document with album list',
              color: Colors.red,
              isExporting: _isExporting,
              onTap: () => _doExport(albums, ExportFormat.pdf),
            ),
          ],
        );
      },
    );
  }

  // ==========================================
  // Actions
  // ==========================================

  Future<void> _doExport(List<Album> albums, ExportFormat format) async {
    HapticService.medium();
    setState(() => _isExporting = true);

    try {
      await _exportService.exportAndShare(albums, format);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: \$e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _shareInstagramStory(Album album) async {
    HapticService.medium();
    final generator = InstagramStoriesGenerator();
    final path = await generator.generate(
      repaintKey: _igKey,
      album: album,
    );
    if (path != null && mounted) {
      await _shareService.shareWidgetAsImage(
        repaintKey: _igKey,
        text: '\${album.artist} - \${album.title}',
      );
    }
  }

  Future<void> _shareInfographic(List<Album> albums) async {
    HapticService.medium();
    await _shareService.shareWidgetAsImage(
      repaintKey: _infographicKey,
      text: 'My Album Collection',
      subject: 'Album Collection Stats',
    );
  }
}

// ==========================================
// Helper Widgets
// ==========================================

class _ShareOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ShareOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border, width: 0.5),
      ),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.primary, size: 22),
        ),
        title: Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(color: AppColors.textTertiary, fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textTertiary),
        onTap: onTap,
      ),
    );
  }
}

class _ExportFormatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool isExporting;
  final VoidCallback onTap;

  const _ExportFormatCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.isExporting,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border, width: 0.5),
      ),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: isExporting
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(icon, color: color, size: 22),
        ),
        title: Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(color: AppColors.textTertiary, fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textTertiary),
        onTap: isExporting ? null : onTap,
      ),
    );
  }
}
