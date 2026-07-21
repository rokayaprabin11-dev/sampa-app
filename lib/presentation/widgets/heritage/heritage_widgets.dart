import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:sampada/core/constants/app_colors.dart';
import 'package:sampada/core/constants/app_dimensions.dart';
import 'package:sampada/core/constants/app_strings.dart';
import 'package:sampada/core/theme/app_theme.dart';
import 'package:sampada/generated/app_localizations.dart';
import 'package:sampada/providers/heritage_provider.dart';
import 'package:sampada/presentation/widgets/shared/shimmer_loading.dart';
import 'package:sampada/presentation/widgets/common/app_network_image.dart';

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
      // Material+InkWell (not GestureDetector) so taps give ripple feedback.
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Material(
          color: isSelected ? AppColors.kColorPrimary : Colors.white,
          borderRadius: BorderRadius.circular(AppDimensions.kRadiusXxl),
          child: InkWell(
            onTap: onTap,
            hoverColor: Colors.white.withAlpha(isSelected ? 51 : 26),
            borderRadius: BorderRadius.circular(AppDimensions.kRadiusXxl),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppDimensions.kRadiusXxl),
                border: Border.all(
                  color: isSelected ? AppColors.kColorPrimary : AppColors.kColorBorderCream,
                ),
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.kColorTextSecondary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ),
        ),
      );
    }
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: Material(
        color: isSelected
            ? (isLight ? AppColors.brownDark : AppColors.goldMain)
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppDimensions.kRadiusXxl),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimensions.kRadiusXxl),
          hoverColor: isLight ? Colors.black.withAlpha(10) : Colors.white.withAlpha(26),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDimensions.kRadiusXxl),
              border: Border.all(
                color: isSelected
                    ? (isLight ? AppColors.brownDark : AppColors.goldMain)
                    : (isLight ? AppColors.brownLight : AppColors.darkBorder),
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? (isLight ? Colors.white : Colors.black) : Theme.of(context).colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
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
  final String? reasonLabel;
  final VoidCallback onTap;

  const FeaturedSiteCard({
    super.key,
    required this.title,
    required this.location,
    required this.icon,
    this.imageUrl,
    this.reasonLabel,
    required this.onTap,
  });

  static const Map<String, (IconData, String)> _reasonMeta = {
    'editors_choice': (Icons.star, "Editor's Choice"),
    'near_you': (Icons.near_me, 'Near You'),
    'trending': (Icons.local_fire_department, 'Trending'),
    'new': (Icons.fiber_new, 'New'),
    'for_you': (Icons.favorite, 'For You'),
  };

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    final meta = reasonLabel != null ? _reasonMeta[reasonLabel] : null;
    return Padding(
      padding: const EdgeInsets.only(right: 12.0),
      child: Material(
        borderRadius: BorderRadius.circular(AppDimensions.kRadiusXxl),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          hoverColor: Colors.black.withAlpha(26),
          child: Ink(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.kColorDeep, AppColors.kColorPrimaryMid],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppDimensions.kRadiusXxl),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // cover image
                if (hasImage)
                  AppNetworkImage(
                    url: imageUrl,
                    fit: BoxFit.cover,
                    errorWidget: const SizedBox.shrink(),
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
    
                // explainability badge (Editor's Choice / Near You / Trending / New / For You)
                if (meta != null)
                  Positioned(
                    left: 16,
                    top: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(AppDimensions.kRadiusPill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(meta.$1, color: AppColors.kColorDeep, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            meta.$2,
                            style: const TextStyle(
                              color: AppColors.kColorDeep,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
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
                        // Cinzel — the display face — not the platform serif.
                        style: GoogleFonts.cinzel(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                        ).copyWith(fontFamilyFallback: AppTheme.devanagariFallback),
                      ),
                      const SizedBox(height: 4),
                      Row(children: [
                        const Icon(Icons.location_on, color: AppColors.kColorAccentLight, size: 14),
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
            padEnds: false,
            itemCount: featured.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              final site = featured[index];
              final np = Localizations.localeOf(context).languageCode == 'ne';
              return FeaturedSiteCard(
                title: site.localizedName(np),
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
    this.iconColor = AppColors.kColorTextHeading,
    this.iconBgColor = AppColors.kColorBgMuted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppDimensions.kRadiusXxl),
        // Same border token as DistrictGridCard so the two variants read as
        // one family.
        border: Border.all(color: AppColors.kColorBorderMid, width: 1.2),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppDimensions.kRadiusMd),
            child: (coverImageUrl != null && coverImageUrl!.isNotEmpty)
                ? AppNetworkImage(
                    url: coverImageUrl,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    errorWidget: Container(
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
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: GoogleFonts.cinzel(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurface,
                    height: 1.2,
                  ).copyWith(fontFamilyFallback: AppTheme.devanagariFallback),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  AppLocalizations.of(context)!.siteCountLabel(sitesCount),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.kColorAccentSafe,
                    height: 1.2,
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

/// Vertical district card for the full "Browse by District" list — cover
/// photo with the district icon floating over it, caps name, Devanagari
/// subtitle, then site count + a decorative arrow (the whole card is the
/// tap target). Distinct from the compact horizontal [DistrictCard].
class DistrictGridCard extends StatelessWidget {
  final String name;
  final String nameNp;
  final int sitesCount;
  final String? coverImageUrl;
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final VoidCallback? onTap;

  const DistrictGridCard({
    super.key,
    required this.name,
    required this.nameNp,
    required this.sitesCount,
    this.coverImageUrl,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    this.onTap,
  });

  Widget _iconFallback() => Container(
        color: iconBgColor,
        child: Center(child: Icon(icon, size: 34, color: iconColor)),
      );

  @override
  Widget build(BuildContext context) {
    final hasCover = coverImageUrl != null && coverImageUrl!.isNotEmpty;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppDimensions.kRadiusXxl),
      child: InkWell(
        onTap: onTap,
        hoverColor: AppColors.kColorPrimary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(AppDimensions.kRadiusXxl),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppDimensions.kRadiusXxl),
            border: Border.all(color: AppColors.kColorBorderCream, width: 1.2),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover photo fills whatever height the text below doesn't need.
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (hasCover)
                      AppNetworkImage(
                        url: coverImageUrl,
                        fit: BoxFit.cover,
                        errorWidget: _iconFallback(),
                      )
                    else
                      _iconFallback(),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.toUpperCase(),
                      // Cinzel — the display face — not the platform serif.
                      style: GoogleFonts.cinzel(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.kColorTextHeading,
                      ).copyWith(fontFamilyFallback: AppTheme.devanagariFallback),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (nameNp.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        nameNp,
                        style: GoogleFonts.notoSerifDevanagari(
                            fontSize: 13, color: AppColors.kColorAccentSafe),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 14, color: AppColors.kColorAccentSafe),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            AppLocalizations.of(context)!.siteCountLabel(sitesCount),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.kColorAccentSafe),
                          ),
                        ),
                        const Icon(Icons.arrow_forward,
                            size: 20, color: AppColors.kColorPrimary),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EventCard extends StatelessWidget {
  final String title;
  final String date;
  /// Localized "X km away" label; null hides the distance chip (no GPS fix
  /// yet, or the event has no coordinates).
  final String? distance;
  /// Short explain-tags e.g. "🔴 Live now", "⭐ Editor's Pick" — why this
  /// event was recommended. Rendered as small pill badges.
  final List<String> tags;
  /// Low-seats warning e.g. "3 left"; null hides the chip (unlimited
  /// capacity, or plenty of seats remaining — full events are already
  /// excluded server-side so this shouldn't normally need to say "Full").
  final String? seatsLeftLabel;

  const EventCard({
    super.key,
    required this.title,
    required this.date,
    this.distance,
    this.tags = const [],
    this.seatsLeftLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF8E8),
        borderRadius: BorderRadius.circular(AppDimensions.kRadiusXxl),
        border: Border.all(color: AppColors.kColorBorderCream),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: AppColors.kColorPrimary,
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
                    const Icon(Icons.calendar_month, size: 14, color: AppColors.kColorTextMuted),
                    const SizedBox(width: 4),
                    Text(date, style: const TextStyle(fontSize: 12, color: AppColors.kColorTextMuted)),
                    if (distance != null) ...[
                      const SizedBox(width: 16),
                      const Icon(Icons.location_on, size: 14, color: AppColors.kColorTextMuted),
                      const SizedBox(width: 4),
                      Text(distance!, style: const TextStyle(fontSize: 12, color: AppColors.kColorTextMuted)),
                    ],
                    if (seatsLeftLabel != null) ...[
                      const SizedBox(width: 16),
                      const Icon(Icons.event_seat, size: 14, color: AppColors.kColorPrimary),
                      const SizedBox(width: 4),
                      Text(seatsLeftLabel!, style: const TextStyle(fontSize: 12, color: AppColors.kColorPrimary, fontWeight: FontWeight.w600)),
                    ],
                  ],
                ),
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: tags.map((tag) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.kColorBorderCream,
                        borderRadius: BorderRadius.circular(AppDimensions.kRadiusPill),
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(fontSize: 11, color: AppColors.kColorDeep, fontWeight: FontWeight.w500),
                      ),
                    )).toList(),
                  ),
                ],
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
  /// Compact "1.2 km" label; null (no GPS fix / no site coords) shows the
  /// location alone.
  final String? distance;
  final String category;
  final String? imageUrl;
  final VoidCallback onTap;

  const HeritageGridCard({
    super.key,
    required this.name,
    required this.location,
    this.distance,
    required this.category,
    this.imageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppDimensions.kRadiusXxl),
      child: InkWell(
        onTap: onTap,
        hoverColor: AppColors.kColorPrimary.withAlpha(10),
        borderRadius: BorderRadius.circular(AppDimensions.kRadiusXxl),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimensions.kRadiusXxl),
            border: Border.all(color: AppColors.kColorBorderCream),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(AppDimensions.kRadiusXxl)),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (imageUrl != null && imageUrl!.isNotEmpty)
                        AppNetworkImage(
                          url: imageUrl,
                          fit: BoxFit.cover,
                          errorWidget: _buildPlaceholder(),
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
                        color: AppColors.kColorTextHeading,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 14, color: AppColors.kColorPrimary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            distance == null ? location : '$location · $distance',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.kColorTextMuted,
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
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.kColorDeep, AppColors.kColorPrimaryMid],
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

/// Icon + color mapping for a district's name — shared by the home screen's
/// preview grid and the full "Browse by District" list so both render the
/// same icon/color per district without duplicating the switch.
class DistrictVisualInfo {
  final IconData icon;
  final Color color;
  final Color bgColor;
  const DistrictVisualInfo(this.icon, this.color, this.bgColor);
}

DistrictVisualInfo districtVisualInfo(String name) {
  switch (name.toLowerCase()) {
    case 'kathmandu':
      return const DistrictVisualInfo(Icons.museum, Color(0xFF5C4033), Color(0xFFF3EBE5));
    case 'bhaktapur':
      return const DistrictVisualInfo(Icons.castle, Color(0xFF6D4C41), Color(0xFFF5EDEA));
    case 'lalitpur':
      return const DistrictVisualInfo(Icons.temple_hindu, Color(0xFFB84B00), Color(0xFFFFF0E6));
    case 'kaski':
    case 'pokhara':
      return const DistrictVisualInfo(Icons.landscape, AppColors.statusSuccess, Color(0xFFE8F5E9));
    case 'mustang':
      return const DistrictVisualInfo(Icons.terrain, Color(0xFF795548), Color(0xFFEFEBE9));
    case 'dolakha':
      return const DistrictVisualInfo(Icons.temple_buddhist, Color(0xFFD84315), Color(0xFFFBE9E7));
    case 'chitwan':
      return const DistrictVisualInfo(Icons.forest, Color(0xFF388E3C), Color(0xFFE8F5E9));
    case 'solukhumbu':
      return const DistrictVisualInfo(Icons.ac_unit, Color(0xFF0277BD), Color(0xFFE1F5FE));
    case 'manang':
    case 'myagdi':
      return const DistrictVisualInfo(Icons.filter_hdr, Color(0xFF546E7A), Color(0xFFECEFF1));
    case 'dang':
    case 'banke':
      return const DistrictVisualInfo(Icons.grass, Color(0xFF558B2F), Color(0xFFF1F8E9));
    case 'rupandehi':
    case 'kapilvastu':
      return const DistrictVisualInfo(Icons.account_balance, Color(0xFF6A1B9A), Color(0xFFF3E5F5));
    case 'nawalpur':
    case 'palpa':
      return const DistrictVisualInfo(Icons.park, Color(0xFF1B5E20), Color(0xFFE8F5E9));
    case 'kanchanpur':
    case 'kailali':
      return const DistrictVisualInfo(Icons.water, Color(0xFF0288D1), Color(0xFFE1F5FE));
    default:
      return const DistrictVisualInfo(Icons.location_city, AppColors.kColorTextMuted, AppColors.kColorTagBg);
  }
}
