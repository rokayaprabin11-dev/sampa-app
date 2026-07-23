import 'package:flutter/material.dart';
import 'package:sampada/core/constants/app_colors.dart';
import 'package:sampada/core/constants/app_dimensions.dart';
import 'package:sampada/core/theme/app_theme.dart';
import 'package:sampada/presentation/widgets/shared/shimmer_loading.dart';

/// Shared loading surfaces that keep asynchronous transitions consistent across
/// the app. They deliberately contain no state or networking behaviour.
class LoadingFadeSwitcher extends StatelessWidget {
  const LoadingFadeSwitcher({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 240),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, .015),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: child,
      );
}

/// A non-blank blocking state for app-level work such as map/session startup.
class FullScreenLoader extends StatelessWidget {
  const FullScreenLoader({super.key, this.label = 'Loading…', this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final foreground =
        isDark ? AppColors.kColorAccentLight : AppColors.kColorPrimary;
    return Semantics(
      liveRegion: true,
      label: label,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.sp24, vertical: AppDimensions.sp20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(AppDimensions.kRadiusXl),
                border: Border.all(
                  color: isDark
                      ? AppColors.kDarkBorder
                      : AppColors.kColorBorderMid,
                ),
                boxShadow: isDark ? null : AppTheme.cardShadow,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: AppTheme.avatarGradient,
                      shape: BoxShape.circle,
                    ),
                    child: icon == null
                        ? const Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: AppColors.kColorTextOnPrimary,
                            ),
                          )
                        : Icon(icon, color: AppColors.kColorTextOnPrimary),
                  ),
                  const SizedBox(height: AppDimensions.sp14),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: foreground,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Reusable skeleton list for screens whose final rows are card-like.
class LoadingSkeletonList extends StatelessWidget {
  const LoadingSkeletonList({
    super.key,
    this.itemCount = 4,
    this.padding = const EdgeInsets.all(16),
    this.itemBuilder,
  });

  final int itemCount;
  final EdgeInsetsGeometry padding;
  final IndexedWidgetBuilder? itemBuilder;

  @override
  Widget build(BuildContext context) => ListView.separated(
        key: const ValueKey('loading-skeleton-list'),
        padding: padding,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: itemCount,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) =>
            itemBuilder?.call(context, index) ?? const HeritageCardSkeleton(),
      );
}

/// Detail-page structure with an image header, title and content sections.
class DetailPageSkeleton extends StatelessWidget {
  const DetailPageSkeleton({super.key});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        key: const ValueKey('detail-page-skeleton'),
        padding: const EdgeInsets.all(16),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShimmerSkeleton(
                width: double.infinity, height: 220, borderRadius: 20),
            SizedBox(height: 20),
            ShimmerSkeleton(width: 220, height: 26),
            SizedBox(height: 12),
            ShimmerSkeleton(width: 150, height: 14),
            SizedBox(height: 28),
            ShimmerSkeleton(width: double.infinity, height: 15),
            SizedBox(height: 10),
            ShimmerSkeleton(width: double.infinity, height: 15),
            SizedBox(height: 10),
            ShimmerSkeleton(width: 260, height: 15),
          ],
        ),
      );
}

/// Small, accessible footer for paginated list fetches.
class LoadMoreIndicator extends StatelessWidget {
  const LoadMoreIndicator({super.key, this.label = 'Loading more'});
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        label: label,
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.sp16),
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.kColorAccentLight
                    : AppColors.kColorPrimary,
              ),
            ),
          ),
        ),
      );
}

/// Progress treatment for uploads/downloads when the exact fraction is known.
class TransferProgress extends StatelessWidget {
  const TransferProgress(
      {super.key, required this.progress, required this.label});
  final double? progress;
  final String label;

  @override
  Widget build(BuildContext context) {
    final value = progress?.clamp(0.0, 1.0);
    final suffix = value == null ? '' : ' ${(value * 100).round()}%';
    return Semantics(
      label: '$label$suffix',
      value: suffix.trim(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          '$label$suffix',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.kColorAccentLight
                    : AppColors.kColorAccentSafe,
              ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppDimensions.kRadiusPill),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 6,
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.kColorAccentLight
                : AppColors.kColorPrimary,
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? AppColors.kDarkBorder
                : AppColors.kColorBgWarm,
          ),
        ),
      ]),
    );
  }
}
