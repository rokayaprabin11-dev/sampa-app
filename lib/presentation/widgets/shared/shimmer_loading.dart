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







