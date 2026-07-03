import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:sampada/core/constants/app_colors.dart';

class ShimmerSkeleton extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerSkeleton({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
      highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

class HeritageCardSkeleton extends StatelessWidget {
  const HeritageCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).brightness == Brightness.light ? const Color(0xFFF7EED3) : AppColors.darkBorder),
      ),
      child: Row(
        children: [
          const ShimmerSkeleton(width: 100, height: 100, borderRadius: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ShimmerSkeleton(width: 150, height: 16),
                  const SizedBox(height: 8),
                  const ShimmerSkeleton(width: 100, height: 12),
                  const SizedBox(height: 12),
                  const ShimmerSkeleton(width: 60, height: 20, borderRadius: 6),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HeritageGridSkeleton extends StatelessWidget {
  const HeritageGridSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).brightness == Brightness.light ? const Color(0xFFF7EED3) : AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Expanded(child: ShimmerSkeleton(width: double.infinity, height: double.infinity, borderRadius: 16)),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ShimmerSkeleton(width: 100, height: 14),
                const SizedBox(height: 6),
                const ShimmerSkeleton(width: 80, height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DistrictCardSkeleton extends StatelessWidget {
  const DistrictCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.light
              ? const Color(0xFFEED5BE)
              : AppColors.darkBorder,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: const Row(
        children: [
          ShimmerSkeleton(width: 44, height: 44, borderRadius: 10),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                ShimmerSkeleton(width: double.infinity, height: 13),
                SizedBox(height: 6),
                ShimmerSkeleton(width: 48, height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RecentlyVisitedSkeleton extends StatelessWidget {
  const RecentlyVisitedSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.light
              ? const Color(0xFFEED5BE)
              : AppColors.darkBorder,
        ),
      ),
      child: const Row(
        children: [
          ShimmerSkeleton(width: 48, height: 48, borderRadius: 10),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerSkeleton(width: double.infinity, height: 14),
                SizedBox(height: 6),
                ShimmerSkeleton(width: 100, height: 11),
              ],
            ),
          ),
          SizedBox(width: 8),
          ShimmerSkeleton(width: 16, height: 16, borderRadius: 4),
        ],
      ),
    );
  }
}

class NotificationCardSkeleton extends StatelessWidget {
  const NotificationCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFF7EED3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const ShimmerSkeleton(width: 42, height: 42, borderRadius: 8),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: const [
                  ShimmerSkeleton(width: double.infinity, height: 14),
                  SizedBox(height: 8),
                  ShimmerSkeleton(width: double.infinity, height: 11),
                  SizedBox(height: 6),
                  ShimmerSkeleton(width: 120, height: 10),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileStatsSkeleton extends StatelessWidget {
  const ProfileStatsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _statSkeleton(),
        _statSkeleton(),
      ],
    );
  }

  Widget _statSkeleton() => const Column(
    children: [
      ShimmerSkeleton(width: 48, height: 26, borderRadius: 6),
      SizedBox(height: 6),
      ShimmerSkeleton(width: 64, height: 12, borderRadius: 4),
    ],
  );
}

class EventCardSkeleton extends StatelessWidget {
  const EventCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).brightness == Brightness.light ? AppColors.bgCream : AppColors.darkBorder),
      ),
      child: Row(
        children: [
          const ShimmerSkeleton(width: 80, height: 80, borderRadius: 12),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ShimmerSkeleton(width: 180, height: 16),
                const SizedBox(height: 8),
                const ShimmerSkeleton(width: 120, height: 12),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const ShimmerSkeleton(width: 60, height: 18, borderRadius: 10),
                    const SizedBox(width: 8),
                    const ShimmerSkeleton(width: 60, height: 18, borderRadius: 10),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}







