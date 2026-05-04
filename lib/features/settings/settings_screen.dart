import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_colors.dart';
import '../../data/services/storage/local_storage_service.dart';
import '../../data/services/recognition_service.dart';

/// App settings and preferences.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
              _buildSection('Recognition', [
                _buildTile(
                  icon: Icons.cloud_outlined,
                  title: 'Online Recognition',
                  subtitle: 'MusicBrainz + Discogs',
                  trailing: Switch(
                    value: true,
                    onChanged: (_) {},
                    activeColor: AppColors.primary,
                  ),
                ),
                _buildTile(
                  icon: Icons.offline_bolt_outlined,
                  title: 'Offline Model',
                  subtitle: 'Download for offline use',
                  onTap: () => _showDownloadDialog(context),
                ),
                _buildTile(
                  icon: Icons.disc_full_outlined,
                  title: 'Discogs Token',
                  subtitle: 'Optional - higher rate limits',
                  onTap: () => _showTokenDialog(context),
                ),
              ]),
              const SizedBox(height: 24),
              _buildSection('Data', [
                _buildTile(
                  icon: Icons.download_outlined,
                  title: 'Export Collection',
                  subtitle: 'Share as JSON',
                  onTap: () => _exportCollection(context),
                ),
                _buildTile(
                  icon: Icons.delete_outline,
                  title: 'Clear Collection',
                  subtitle: 'Remove all albums',
                  onTap: () => _clearCollection(context),
                ),
              ]),
              const SizedBox(height: 24),
              _buildSection('About', [
                _buildTile(
                  icon: Icons.info_outline,
                  title: 'Version',
                  subtitle: '0.1.0 (Alpha)',
                ),
                _buildTile(
                  icon: Icons.code,
                  title: 'Open Source',
                  subtitle: 'github.com/wysokinskinorbert/music-album-scanner',
                  onTap: () {},
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
      trailing: trailing ?? const Icon(Icons.chevron_right, color: AppColors.textTertiary),
      onTap: onTap,
    );
  }

  void _showDownloadDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Download Offline Model'),
        content: const Text(
          'This will download ~15MB of data for offline album recognition. '
          'Works best for commercial releases.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              // TODO: Trigger model download
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Download started...')),
              );
            },
            child: const Text('Download'),
          ),
        ],
      ),
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
          children: [
            const Text(
              'Optional. Increases API rate limits from 25 to 60 requests/minute.',
              style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(hintText: 'Enter token'),
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
              // TODO: Save token
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _exportCollection(BuildContext context) {
    // TODO: Get actual data from repository
    Share.share('{"albums": [], "exportedAt": "${DateTime.now().toIso8601String()}"}');
  }

  void _clearCollection(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Clear entire collection?'),
        content: const Text('This action cannot be undone.'),
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
