import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Small badge indicating offline model status.
class OfflineBadge extends StatelessWidget {
  final bool isReady;
  final VoidCallback? onTap;

  const OfflineBadge({super.key, required this.isReady, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isReady
              ? AppColors.success.withOpacity(0.15)
              : AppColors.warning.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isReady ? AppColors.success : AppColors.warning,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isReady ? Icons.cloud_done : Icons.cloud_off,
              size: 14,
              color: isReady ? AppColors.success : AppColors.warning,
            ),
            const SizedBox(width: 4),
            Text(
              isReady ? 'Offline Ready' : 'Online Only',
              style: TextStyle(
                color: isReady ? AppColors.success : AppColors.warning,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
