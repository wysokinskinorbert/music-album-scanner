import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/haptic_service.dart';

/// Direction-aware swipe action for list items.
/// Supports: delete (left), share (right), favorite (far right).
class SwipeActionWrapper extends StatelessWidget {
  final Widget child;
  final VoidCallback? onDelete;
  final VoidCallback? onShare;
  final VoidCallback? onFavorite;
  final bool isFavorite;

  const SwipeActionWrapper({
    super.key,
    required this.child,
    this.onDelete,
    this.onShare,
    this.onFavorite,
    this.isFavorite = false,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: UniqueKey(),
      confirmDismiss: (direction) async {
        HapticService.swipeAction();

        if (direction == DismissDirection.endToStart) {
          // Left swipe = delete
          return await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: AppColors.surface,
              title: const Text('Remove album?'),
              content: const Text('This album will be removed from your collection.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Remove', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          );
        }
        return false;
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.endToStart) {
          onDelete?.call();
        }
      },
      // Left swipe background (delete)
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline, color: Colors.red, size: 24),
            SizedBox(height: 2),
            Text('Delete', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      // Right swipe background (share + favorite)
      secondaryBackground: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () {
                HapticService.light();
                onShare?.call();
              },
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.share_outlined, color: AppColors.primary, size: 24),
                  SizedBox(height: 2),
                  Text('Share', style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(width: 20),
            if (onFavorite != null)
              GestureDetector(
                onTap: () {
                  HapticService.light();
                  onFavorite?.call();
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: Colors.red,
                      size: 24,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isFavorite ? 'Unfav' : 'Fav',
                      style: const TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      child: child,
    );
  }
}

/// Icon action button for swipe backgrounds.
class SwipeActionIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const SwipeActionIcon({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
