import 'package:flutter/material.dart';
import 'package:sampada/core/constants/app_colors.dart';
import 'package:sampada/core/constants/app_dimensions.dart';
import 'package:sampada/presentation/widgets/common/app_network_image.dart';

/// Shared event card used on both the Events screen ("Current Events") and the
/// Home screen ("Nearby Events") so they render identically. Thumbnail + title
/// + date·location + optional description, distance/tag badges, and a
/// "View Details" affordance.
class EventListCard extends StatelessWidget {
  final String title;
  final String date;
  final String location;

  /// Compact "1.2 km" chip; null hides it (no GPS fix or event lacks coords).
  final String? distance;
  final String tag;
  final String imageUrl;
  final String shortDescription;
  final VoidCallback? onTap;

  const EventListCard({
    super.key,
    required this.title,
    required this.date,
    required this.location,
    required this.distance,
    required this.tag,
    this.imageUrl = '',
    this.shortDescription = '',
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppDimensions.kRadiusXxl),
          border: Border.all(
              color: isLight ? AppColors.bgCream : AppColors.darkBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: isLight ? AppColors.bgCream : AppColors.darkBgCard,
                    borderRadius: BorderRadius.circular(AppDimensions.kRadiusLg),
                  ),
                  child: imageUrl.isNotEmpty
                      ? AppNetworkImage(
                          url: imageUrl,
                          fit: BoxFit.cover,
                          errorWidget: Icon(Icons.music_note,
                              color: isLight
                                  ? AppColors.brownDark
                                  : AppColors.goldMain,
                              size: 40),
                        )
                      : Icon(Icons.music_note,
                          color:
                              isLight ? AppColors.brownDark : AppColors.goldMain,
                          size: 40),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$date • $location',
                        style: TextStyle(
                            fontSize: 12,
                            color: isLight
                                ? AppColors.textSecondary
                                : AppColors.darkTextSecondary),
                      ),
                      if (shortDescription.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          shortDescription,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11,
                              height: 1.35,
                              color: isLight
                                  ? AppColors.textTertiary
                                  : AppColors.darkTextTertiary),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (distance != null) ...[
                            _Badge(icon: Icons.location_on, label: distance!),
                            const SizedBox(width: 8),
                          ],
                          _Badge(label: tag),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Divider(
                height: 24,
                color: isLight ? AppColors.bgCream : AppColors.darkBorder),
            const Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'View Details',
                  style: TextStyle(
                    color: AppColors.brownAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                SizedBox(width: 2),
                Icon(Icons.chevron_right, size: 18, color: AppColors.brownAccent),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData? icon;
  final String label;

  const _Badge({this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isLight ? AppColors.bgCream : AppColors.darkBgCard,
        borderRadius: BorderRadius.circular(AppDimensions.kRadiusMd),
        border: isLight ? null : Border.all(color: AppColors.darkBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon,
                size: 12,
                color: isLight ? AppColors.brownDark : AppColors.goldMain),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isLight
                    ? AppColors.textSecondary
                    : AppColors.darkTextSecondary),
          ),
        ],
      ),
    );
  }
}
