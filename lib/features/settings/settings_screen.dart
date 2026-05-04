import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_colors.dart';
import '../../data/repositories/album_repository.dart';
import '../../data/services/ml/model/model_download_manager.dart';
import '../import_export/import_screen.dart';
import '../sharing/share_export_screen.dart';
import 'model_download_screen.dart';

/// App settings and preferences.
class SettingsScreen extends StatelessWidget {
  final ModelDownloadManager? downloadManager;

  const SettingsScreen({super.key, this.downloadManager});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Settings',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 24),

              // --- Recognition Section ---
              _buildSection('Recognition', [
                _buildTile(
                  icon: Icons.cloud_outlined,
                  title: 'Online Recognition',
                  subtitle: 'MusicBrainz + Discogs (auto)',
                  trailing: Switch(
                    value: true,
                    onChanged: (_) {},
                    activeColor: AppColors.primary,
                  ),
                ),
                _buildTile(
                  icon: Icons.text_fields,
                  title: 'OCR Text Extraction',
                  subtitle: 'Read text from album covers',
                  trailing: Switch(
                    value: true,
                    onChanged: (_) {},
                    activeColor: AppColors.primary,
                  ),
                ),
                _buildTile(
                  icon: Icons.qr_code,
                  title: 'Barcode Scanning',
                  subtitle: 'Scan EAN/UPC on back covers',
                  trailing: Switch(
                    value: true,
                    onChanged: (_) {},
                    activeColor: AppColors.primary,
                  ),
                ),
                _buildTile(
                  icon: Icons.auto_awesome,
                  title: 'Visual Analysis',
                  subtitle: 'Identify artistic covers via ML Kit',
                  trailing: Switch(
                    value: true,
                    onChanged: (_) {},
                    activeColor: AppColors.primary,
                  ),
                ),
              ]),
              const SizedBox(height: 24),

              // --- Offline Model Section ---
              _buildSection('Offline Mode', [
                _buildTile(
                  icon: Icons.download_for_offline_outlined,
                  title: 'Manage Models',
                  subtitle: 'Download/remove offline recognition models',
                  onTap: () {
                    if (downloadManager != null) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ModelDownloadScreen(
                            downloadManager: downloadManager!,
                          ),
                        ),
                      );
                    }
                  },
                ),
                _buildTile(
                  icon: Icons.offline_bolt_outlined,
                  title: 'Offline Recognition',
                  subtitle: downloadManager?.isOfflineReady == true
                      ? 'Model ready - works without internet'
                      : 'Download a model to enable offline use',
                  trailing: Icon(
                    downloadManager?.isOfflineReady == true
                        ? Icons.check_circle
                        : Icons.cloud_off,
                    color: downloadManager?.isOfflineReady == true
                        ? AppColors.success
                        : AppColors.textTertiary,
                    size: 20,
                  ),
                ),
                _buildTile(
                  icon: Icons.sync,
                  title: 'Offline Sync Queue',
                  subtitle: '0 albums pending enrichment',
                  trailing: const Icon(Icons.chevron_right, color: AppColors.textTertiary),
                ),
                _buildTile(
                  icon: Icons.storage_outlined,
                  title: 'Embedding Index',
                  subtitle: '0 covers indexed for offline matching',
                  trailing: const Icon(Icons.chevron_right, color: AppColors.textTertiary),
                ),
              ]),
              const SizedBox(height: 24),

              // --- APIs Section ---
              _buildSection('APIs', [
                _buildTile(
                  icon: Icons.disc_full_outlined,
                  title: 'Discogs Personal Token',
                  subtitle: 'Optional - higher rate limits (60/min vs 25/min)',
                  onTap: () => _showTokenDialog(context),
                ),
                _buildTile(
                  icon: Icons.info_outline,
                  title: 'MusicBrainz',
                  subtitle: 'Free, no key required (1 req/sec)',
                  trailing: const Icon(Icons.check_circle, color: AppColors.success, size: 20),
                ),
                _buildTile(
                  icon: Icons.info_outline,
                  title: 'Cover Art Archive',
                  subtitle: 'Free album artwork (auto)',
                  trailing: const Icon(Icons.check_circle, color: AppColors.success, size: 20),
                ),
              ]),
              const SizedBox(height: 24),

              // --- Data Section ---
              _buildSection('Data', [
                _buildTile(
                  icon: Icons.share_outlined,
                  title: 'Share & Export',
                  subtitle: 'Share albums, export JSON/CSV/PDF, Instagram Stories',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ShareExportScreen()),
                    );
                  },
                ),
                _buildTile(
                  icon: Icons.file_download_outlined,
                  title: 'Import Collection',
                  subtitle: 'Import from Discogs CSV, MusicBrainz, or JSON',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ImportScreen()),
                    );
                  },
                ),
                _buildTile(
                  icon: Icons.delete_outline,
                  title: 'Clear Collection',
                  subtitle: 'Remove all albums permanently',
                  onTap: () => _clearCollection(context),
                ),
              ]),
              const SizedBox(height: 24),

              // --- About Section ---
              _buildSection('About', [
                _buildTile(
                  icon: Icons.info_outline,
                  title: 'Version',
                  subtitle: '0.7.0 (Sharing & Social)',
                ),
                _buildTile(
                  icon: Icons.code,
                  title: 'Open Source',
                  subtitle: 'github.com/wysokinskinorbert/music-album-scanner',
                  onTap: () {},
                ),
                _buildTile(
                  icon: Icons.new_releases_outlined,
                  title: 'What\'s New',
                  subtitle: 'v0.7.0: Share, Instagram Stories, Infographic, Export CSV/PDF, Import Discogs/MusicBrainz',
                  onTap: () => _showChangelog(context),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textSecondary),
      title: Text(
        title,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
      ),
      trailing: trailing ?? (onTap != null ? const Icon(Icons.chevron_right, color: AppColors.textTertiary) : null),
      onTap: onTap,
    );
  }

  void _showTokenDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Discogs Personal Access Token'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Optional. Increases API rate limits from 25 to 60 requests/minute.',
              style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            const Text(
              'Get yours at: discogs.com/settings/developers',
              style: TextStyle(color: AppColors.primaryLight, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Paste token here',
                hintStyle: TextStyle(color: AppColors.textTertiary),
              ),
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Token saved!'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showChangelog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('What\'s New in v0.3.0'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ChangelogItem(
                icon: Icons.cloud_download,
                title: 'Model Download Manager',
                desc: 'Download and manage offline ML models in-app',
              ),
              _ChangelogItem(
                icon: Icons.offline_bolt,
                title: 'On-Device Recognition',
                desc: 'TFLite MobileNet for offline album identification',
              ),
              _ChangelogItem(
                icon: Icons.fingerprint,
                title: 'Cover Embedding Index',
                desc: 'Build a personal index for similarity matching',
              ),
              _ChangelogItem(
                icon: Icons.sync,
                title: 'Offline-to-Online Sync',
                desc: 'Auto-enrich offline matches when connectivity returns',
              ),
              _ChangelogItem(
                icon: Icons.update,
                title: 'Model Versioning',
                desc: 'Auto-check for model updates and version management',
              ),
              _ChangelogItem(
                icon: Icons.cloud_off,
                title: 'Offline Badge',
                desc: 'Visual indicator of offline model status in scan screen',
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }

  void _exportCollection(BuildContext context) {
    try {
      final repo = context.read<AlbumRepository>();
      final data = repo.exportCollection();
      if (data.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Collection is empty'),
            backgroundColor: AppColors.warning,
          ),
        );
        return;
      }
      Share.share(
        '{"albums": ${data.toString()}, "exportedAt": "${DateTime.now().toIso8601String()}"}',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _clearCollection(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Clear entire collection?'),
        content: const Text('This action cannot be undone. All albums will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              // TODO: Clear collection via bloc
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
}

class _ChangelogItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;

  const _ChangelogItem({
    required this.icon,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primaryLight),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  desc,
                  style: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
