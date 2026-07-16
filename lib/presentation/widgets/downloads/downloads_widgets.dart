import 'package:flutter/material.dart';
import 'package:sampada/presentation/widgets/common/app_network_image.dart';
import 'package:sampada/core/constants/app_colors.dart';
import 'package:sampada/core/constants/app_dimensions.dart';

class StorageStatusCard extends StatelessWidget {
  final double usedMB;
  final double totalGB;

  const StorageStatusCard({
    super.key,
    required this.usedMB,
    required this.totalGB,
  });

  @override
  Widget build(BuildContext context) {
    final double totalMB = totalGB * 1024;
    final double progress = usedMB / totalMB;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppDimensions.kRadiusXxl),
        border: Border.all(color: Theme.of(context).brightness == Brightness.light ? AppColors.kColorBorderCream : AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Storage Used',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${usedMB.toInt()} MB of $totalGB GB',
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.light ? AppColors.kColorTextMuted : AppColors.darkTextSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppDimensions.kRadiusMd),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.kColorAccentLight.withValues(alpha: 0.2),
              color: const Color(0xFF8B2C1F),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }
}

class DownloadItemCard extends StatelessWidget {
  final String title;
  final int sitesCount;
  final String size;
  final IconData icon;
  final String? imageUrl;
  final bool isReady;
  final VoidCallback? onDelete;
  final VoidCallback? onDownload;

  const DownloadItemCard({
    super.key,
    required this.title,
    required this.sitesCount,
    required this.size,
    required this.icon,
    this.imageUrl,
    this.isReady = true,
    this.onDelete,
    this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppDimensions.kRadiusXxl),
        border: Border.all(color: Theme.of(context).brightness == Brightness.light ? AppColors.kColorBorderCream : AppColors.darkBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppDimensions.kRadiusMd),
            child: SizedBox(
              width: 56, height: 56,
              child: (imageUrl != null && imageUrl!.isNotEmpty)
                  ? AppNetworkImage(url: imageUrl, fit: BoxFit.cover,
                      errorWidget: _iconFallback(context))
                  : _iconFallback(context),
            ),
          ),
          const SizedBox(width: 16),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.location_on, color: Theme.of(context).brightness == Brightness.light ? AppColors.kColorTextHeading : AppColors.goldMain, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '$sitesCount sites',
                      style: TextStyle(color: Theme.of(context).brightness == Brightness.light ? AppColors.kColorTextMuted : AppColors.darkTextSecondary, fontSize: 13),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.save, color: Theme.of(context).brightness == Brightness.light ? AppColors.kColorTextHeading : AppColors.goldMain, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      size,
                      style: TextStyle(color: Theme.of(context).brightness == Brightness.light ? AppColors.kColorTextMuted : AppColors.darkTextSecondary, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (isReady)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(AppDimensions.kRadiusSm),
                      border: Border.all(color: AppColors.kColorOnlineDot),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check, color: AppColors.kColorOnlineDot, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          'Ready',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  )
                else
                  GestureDetector(
                    onTap: onDownload,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.kColorAccentLight,
                        borderRadius: BorderRadius.circular(AppDimensions.kRadiusSm),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.download, color: Theme.of(context).brightness == Brightness.light ? AppColors.kColorTextHeading : Colors.black, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            'Download',
                            style: TextStyle(color: Theme.of(context).brightness == Brightness.light ? AppColors.kColorTextHeading : Colors.black, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Delete Action
          if (isReady)
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.light ? const Color(0xFF1A1A1A) : AppColors.darkBgCard,
                shape: BoxShape.circle,
                border: Theme.of(context).brightness == Brightness.dark ? Border.all(color: AppColors.darkBorder) : null,
              ),
              child: IconButton(
                icon: Icon(Icons.delete_outline, color: Theme.of(context).brightness == Brightness.light ? Colors.white : AppColors.goldMain, size: 20),
                onPressed: onDelete,
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(8),
              ),
            ),
        ],
      ),
    );
  }

  Widget _iconFallback(BuildContext context) => Container(
    color: Theme.of(context).brightness == Brightness.light ? AppColors.kColorTagBg : AppColors.darkBgCard,
    child: Center(child: Icon(icon, color: Theme.of(context).brightness == Brightness.light ? AppColors.kColorTextHeading : AppColors.goldMain, size: 32)),
  );
}

class TipCard extends StatelessWidget {
  final String text;

  const TipCard({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.light ? AppColors.kColorBorderCream : AppColors.darkBgCard,
        borderRadius: BorderRadius.circular(AppDimensions.kRadiusXxl),
        border: Theme.of(context).brightness == Brightness.dark ? Border.all(color: AppColors.darkBorder) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, color: Theme.of(context).brightness == Brightness.light ? Colors.white : AppColors.goldMain, size: 18),
              const SizedBox(width: 8),
              Text(
                'Tip',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).brightness == Brightness.light ? AppColors.kColorTextMuted : AppColors.darkTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}







