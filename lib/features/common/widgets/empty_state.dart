import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// A reusable empty state widget with icon, title, subtitle and optional CTA.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? iconColor;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
    this.iconColor,
  });

  /// Empty collection.
  factory EmptyState.collection({VoidCallback? onScan}) => EmptyState(
        icon: Icons.album_outlined,
        title: 'No albums yet',
        subtitle: 'Scan your first album to start building your collection',
        actionLabel: 'Start Scanning',
        onAction: onScan,
      );

  /// No search results.
  factory EmptyState.searchResult({String? query}) => EmptyState(
        icon: Icons.search_off,
        title: 'No results found',
        subtitle: query != null
            ? 'Nothing matches "\$query". Try a different search.'
            : 'Try a different search term.',
      );

  /// No scan results - album not recognized.
  factory EmptyState.noRecognition({VoidCallback? onRetry, VoidCallback? onManualSearch}) => EmptyState(
        icon: Icons.help_outline,
        title: 'Album not recognized',
        subtitle: 'Could not identify this album. Try a clearer photo or search manually.',
        actionLabel: 'Search Manually',
        onAction: onManualSearch,
      );

  /// Bad photo.
  factory EmptyState.badPhoto({VoidCallback? onRetake}) => EmptyState(
        icon: Icons.camera_alt_outlined,
        title: 'Photo too blurry',
        subtitle: 'The image quality is too low for recognition. Try again with better lighting and focus.',
        actionLabel: 'Retake Photo',
        onAction: onRetake,
        iconColor: Colors.orange,
      );

  /// No internet - offline mode.
  factory EmptyState.offline({VoidCallback? onRetry}) => EmptyState(
        icon: Icons.cloud_off,
        title: 'No internet connection',
        subtitle: 'Online recognition requires internet. Offline mode is available if a model is downloaded.',
        actionLabel: 'Try Again',
        onAction: onRetry,
        iconColor: AppColors.warning,
      );

  /// Empty wishlist.
  factory EmptyState.wishlist({VoidCallback? onAdd}) => EmptyState(
        icon: Icons.favorite_border,
        title: 'Wishlist is empty',
        subtitle: 'Add albums you want to find in the future',
        actionLabel: 'Add Album',
        onAction: onAdd,
      );

  /// No duplicates found.
  factory EmptyState.noDuplicates() => const EmptyState(
        icon: Icons.check_circle_outline,
        title: 'No duplicates found',
        subtitle: 'Your collection is clean! Every album is unique.',
        iconColor: Colors.green,
      );

  /// Generic error state.
  factory EmptyState.error({String? message, VoidCallback? onRetry}) => EmptyState(
        icon: Icons.error_outline,
        title: 'Something went wrong',
        subtitle: message ?? 'An unexpected error occurred. Please try again.',
        actionLabel: 'Retry',
        onAction: onRetry,
        iconColor: Colors.red,
      );

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: (iconColor ?? AppColors.textTertiary).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 40,
                color: iconColor ?? AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: Text(actionLabel!),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
