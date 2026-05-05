import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/sync/offline_sync_service.dart';

/// Shows pending offline sync actions and sync status.
class SyncStatusBar extends StatelessWidget {
  final int pendingCount;
  final SyncStatus status;
  final VoidCallback? onSync;

  const SyncStatusBar({
    super.key,
    required this.pendingCount,
    required this.status,
    this.onSync,
  });

  @override
  Widget build(BuildContext context) {
    if (pendingCount == 0 && status != SyncStatus.syncing) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: status == SyncStatus.syncing
            ? AppColors.primary.withOpacity(0.15)
            : AppColors.warning.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: status == SyncStatus.syncing
              ? AppColors.primary
              : AppColors.warning,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          if (status == SyncStatus.syncing)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            )
          else
            const Icon(Icons.sync_problem, size: 16, color: AppColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              status == SyncStatus.syncing
                  ? 'Syncing album metadata...'
                  : '$pendingCount album(s) need online sync',
              style: TextStyle(
                color: status == SyncStatus.syncing
                    ? AppColors.primary
                    : AppColors.warning,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (status != SyncStatus.syncing && onSync != null)
            TextButton(
              onPressed: onSync,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: Size.zero,
              ),
              child: Text(
                'Sync Now',
                style: TextStyle(
                  color: status == SyncStatus.syncing
                      ? AppColors.primary
                      : AppColors.warning,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
