import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sampada/core/constants/app_colors.dart';
import 'package:sampada/core/constants/app_strings.dart';
import 'package:sampada/providers/heritage_provider.dart';
import 'package:sampada/presentation/widgets/shared/shimmer_loading.dart';

class CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDesignStyle;

  const CategoryChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.isDesignStyle = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isDesignStyle) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFD4520A) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? const Color(0xFFD4520A) : const Color(0xFFF7EED3),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF6B5041),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected 
              ? (Theme.of(context).brightness == Brightness.light ? AppColors.brownDark : AppColors.goldMain)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected 
                ? (Theme.of(context).brightness == Brightness.light ? AppColors.brownDark : AppColors.goldMain)
                : (Theme.of(context).brightness == Brightness.light ? AppColors.brownLight : AppColors.darkBorder),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? (Theme.of(context).brightness == Brightness.light ? Colors.white : Colors.black) : Theme.of(context).colorScheme.onSurface,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class FeaturedSiteCard extends StatelessWidget {
  final String title;
  final String location;
  final IconData icon;
  final String? imageUrl;
  final VoidCallback onTap;

  const FeaturedSiteCard({
    super.key,
    required this.title,
    required this.location,
    required this.icon,
    this.imageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF5D1700), Color(0xFF9E3D1A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // cover image
            if (hasImage)
              Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              )
            else
              Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Icon(icon, color: Colors.white.withValues(alpha: 0.3), size: 100),
                ),
              ),

            // gradient overlay for text readability
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: hasImage ? 0.65 : 0.3),
                  ],
                ),
              ),
            ),

            // title + location
            Positioned(
              left: 20, right: 20, bottom: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                      fontFamily: 'serif',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.location_on, color: Color(0xFFDCA73A), size: 14),
                    const SizedBox(width: 4),
                    Text(
                      location,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FeaturedSiteCarousel extends StatefulWidget {
  const FeaturedSiteCarousel({super.key});

  @override
  State<FeaturedSiteCarousel> createState() => _FeaturedSiteCarouselState();
}

class _FeaturedSiteCarouselState extends State<FeaturedSiteCarousel> {
  late final PageController _pageController;
  int _currentPage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.85);
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted) return;
      final provider = Provider.of<HeritageProvider>(context, listen: false);
      final featured = provider.featuredSites;
      if (featured.isEmpty) return;

      if (_currentPage < featured.length - 1) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<HeritageProvider>(
      builder: (context, provider, child) {
        final featured = provider.featuredSites;

        if (provider.isLoading && featured.isEmpty) {
          return SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 3,
              itemBuilder: (context, index) => const Padding(
                padding: EdgeInsets.only(right: 12),
                child: ShimmerSkeleton(width: 300, height: 200, borderRadius: 24),
              ),
            ),
          );
        }

        if (featured.isEmpty) {
          return const SizedBox(
            height: 200,
            child: Center(child: Text('No featured heritage sites found')),
          );
        }

        return SizedBox(
          height: 200,
          child: PageView.builder(
            controller: _pageController,
            itemCount: featured.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              final site = featured[index];
              return FeaturedSiteCard(
                title: site.name,
                location: site.district,
                icon: _getIconForCategory(site.category),
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    AppStrings.heritageDetailsPath,
                    arguments: site,
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  IconData _getIconForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'temple':
      case 'temples':
        return Icons.temple_hindu;
      case 'stupa':
      case 'stupas':
        return Icons.temple_buddhist;
      case 'palace':
      case 'palaces':
        return Icons.castle;
      default:
        return Icons.museum;
    }
  }
}

class DistrictCard extends StatelessWidget {
  final String name;
  final int sitesCount;
  final String? coverImageUrl;
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;

  const DistrictCard({
    super.key,
    required this.name,
    required this.sitesCount,
    this.coverImageUrl,
    required this.icon,
    this.iconColor = const Color(0xFF4A342B),
    this.iconBgColor = const Color(0xFFF5EFEC),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0E6D3), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: (coverImageUrl != null && coverImageUrl!.isNotEmpty)
                ? Image.network(
                    coverImageUrl!,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 44,
                      height: 44,
                      color: iconBgColor,
                      child: Icon(icon, color: iconColor, size: 24),
                    ),
                  )
                : Container(
                    width: 44,
                    height: 44,
                    color: iconBgColor,
                    child: Icon(icon, color: iconColor, size: 24),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '$sitesCount Sites',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8C7162),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class EventCard extends StatelessWidget {
  final String title;
  final String date;
  final String distance;

  const EventCard({
    super.key,
    required this.title,
    required this.date,
    required this.distance,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF8E8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF7EED3)),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: Color(0xFFD4520A),
              shape: BoxShape.circle,
            ),
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
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.calendar_month, size: 14, color: Color(0xFF8C7162)),
                    const SizedBox(width: 4),
                    Text(date, style: const TextStyle(fontSize: 12, color: Color(0xFF8C7162))),
                    const SizedBox(width: 16),
                    const Icon(Icons.location_on, size: 14, color: Color(0xFF8C7162)),
                    const SizedBox(width: 4),
                    Text(distance, style: const TextStyle(fontSize: 12, color: Color(0xFF8C7162))),
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

class HeritageGridCard extends StatelessWidget {
  final String name;
  final String location;
  final String distance;
  final String category;
  final String? imageUrl;
  final VoidCallback onTap;

  const HeritageGridCard({
    super.key,
    required this.name,
    required this.location,
    required this.distance,
    required this.category,
    this.imageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFF7EED3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (imageUrl != null && imageUrl!.isNotEmpty)
                      Image.network(
                        imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const ShimmerSkeleton(width: double.infinity, height: double.infinity);
                        },
                      )
                    else
                      _buildPlaceholder(),
                    // Subtle overlay to ensure text readability if needed (though text is below)
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.1),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF331609),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 14, color: Color(0xFFD4520A)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '$location · $distance',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF8C7162),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF5D1700), Color(0xFF9E3D1A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          _getIconForCategory(category),
          color: Colors.white.withValues(alpha: 0.8),
          size: 60,
        ),
      ),
    );
  }

  IconData _getIconForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'temple':
      case 'temples':
        return Icons.temple_hindu;
      case 'stupa':
      case 'stupas':
        return Icons.temple_buddhist;
      case 'palace':
      case 'palaces':
        return Icons.castle;
      default:
        return Icons.museum;
    }
  }
}







