import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sampada/core/constants/app_colors.dart';
import 'package:sampada/core/constants/app_dimensions.dart';
import 'package:sampada/core/constants/app_strings.dart';
import 'package:sampada/core/services/location_service.dart';
import 'package:sampada/core/services/notification_service.dart';
import 'package:sampada/core/utils/geo_distance.dart';
import 'package:sampada/presentation/navigation/app_bottom_nav.dart';
import 'package:sampada/presentation/widgets/shared/shimmer_loading.dart';
import 'package:sampada/presentation/widgets/heritage_widgets.dart';
import 'package:sampada/presentation/widgets/events/event_list_card.dart';
import 'package:sampada/presentation/screens/events/event_detail_screen.dart';
import 'package:sampada/providers/heritage_provider.dart';
import 'package:sampada/providers/event_provider.dart';
import 'package:sampada/generated/app_localizations.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    // Fetch sites and events when the home screen is first loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HeritageProvider>().fetchSites();
      context.read<EventProvider>().loadUpcomingEvents();
      _loadFeaturedSites();
      // Ask for notification permission here — once, in context — rather than
      // on the splash. No-ops after the first time and if push is off.
      NotificationService().ensurePermissionPrompt();
    });
  }

  /// Two-phase featured-sites fetch: an immediate no-coords call so the
  /// carousel paints fast, then a background location fix that re-fetches
  /// with lat/lng once (if ever) it resolves — never blocks the first paint.
  Future<void> _loadFeaturedSites() async {
    final provider = context.read<HeritageProvider>();
    await provider.fetchFeaturedSites();
    if (!mounted) return;
    final pos = await LocationService().getAccurateFix();
    if (pos == null || !mounted) return;
    await provider.fetchFeaturedSites(lat: pos.latitude, lng: pos.longitude);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return PopScope(
      canPop: false,
      child: Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Header Section ---
            // Sizes to its content instead of a fixed screen-height fraction,
            // with extra bottom padding so the overhanging search bar clears the text.
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF5C1A0A),
                        Color(0xFFA83210),
                        Color(0xFFC8501A),
                      ],
                      stops: [0.0, 0.6, 1.0],
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Namaste! 🙏',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                ),
                              ),
                              Material(
                                color: Colors.transparent,
                                shape: const CircleBorder(),
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  onTap: () => Navigator.pushNamed(context, AppStrings.notificationsPath),
                                  splashColor: Colors.white24,
                                  highlightColor: Colors.white10,
                                  child: const Padding(
                                    padding: EdgeInsets.all(8),
                                    child: Icon(Icons.notifications, color: AppColors.kColorBgWarm, size: 22),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: const Text(
                              'EXPLORE HERITAGE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                                fontFamily: 'serif',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Search Bar
                Positioned(
                  bottom: -25,
                  left: 24,
                  right: 24,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pushNamed(context, AppStrings.searchPath);
                    },
                    child: Container(
                      height: 50,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppDimensions.kRadiusPill),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.search, color: Color(0xFF7B1E00), size: 20),
                          SizedBox(width: 12),
                          Text(
                            'Search sites, districts...',
                            style: TextStyle(color: Color(0xFF8C7162), fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 48),

            // --- Categories (only show categories with actual sites) ---
            Consumer<HeritageProvider>(
              builder: (context, hp, _) {
                // Build chips from the categories actually present in the loaded
                // sites, so admin-added/edited categories appear here too.
                // getFeaturedSites() filters via _slugify(site.category), so any
                // category name works without a hardcoded map.
                final present = hp.sites
                    .map((s) => s.category.trim())
                    .where((c) => c.isNotEmpty)
                    .toSet()
                    .toList()
                  ..sort();
                final allCats = <String>[l10n.all, ...present];
                return SizedBox(
                  height: 45,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    children: allCats.map((cat) => CategoryChip(
                      label: cat,
                      isSelected: _selectedCategory == cat || (_selectedCategory == 'All' && cat == l10n.all),
                      onTap: () => setState(() => _selectedCategory = cat),
                      isDesignStyle: true,
                    )).toList(),
                  ),
                );
              },
            ),

            const SizedBox(height: 10),

            // --- Featured Sites ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.featuredSites,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).brightness == Brightness.light ? AppColors.textHeadline : AppColors.goldMain,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, AppStrings.searchPath);
                    },
                    child: Row(
                      children: [
                        Text(l10n.seeAll, style: const TextStyle(color: Color(0xFFD4520A))),
                        const Icon(Icons.arrow_forward, size: 16, color: Color(0xFFD4520A)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            DynamicFeaturedCarousel(selectedCategory: _selectedCategory),

            const SizedBox(height: 10),

            // --- Browse by District ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.browseByDistrict,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).brightness == Brightness.light ? AppColors.textHeadline : AppColors.goldMain,
                    ),
                  ),
                  Consumer<HeritageProvider>(
                    builder: (_, p, __) => p.districts.length > 8
                        ? TextButton(
                            onPressed: () => Navigator.pushNamed(context, AppStrings.districtListPath),
                            child: Row(
                              children: [
                                Text(l10n.seeAll, style: const TextStyle(color: Color(0xFFD4520A))),
                                const Icon(Icons.arrow_forward, size: 16, color: Color(0xFFD4520A)),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 1),
            Consumer<HeritageProvider>(
              builder: (context, heritageProvider, child) {
                final loading = heritageProvider.isLoading && heritageProvider.districts.isEmpty;
                final visible = heritageProvider.districts
                    .where((d) => d.sitesCount > 0)
                    .take(8)
                    .toList();

                final Widget content;
                if (loading) {
                  content = Padding(
                    key: const ValueKey('districts-skeleton'),
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 2.2,
                      children: const [
                        DistrictCardSkeleton(),
                        DistrictCardSkeleton(),
                        DistrictCardSkeleton(),
                        DistrictCardSkeleton(),
                      ],
                    ),
                  );
                } else if (visible.isEmpty) {
                  content = const Padding(
                    key: ValueKey('districts-empty'),
                    padding: EdgeInsets.symmetric(horizontal: 24.0),
                    child: Text(
                      'No districts available',
                      style: TextStyle(color: Color(0xFF8C7162), fontSize: 14),
                    ),
                  );
                } else {
                  content = Padding(
                    key: const ValueKey('districts-content'),
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: visible.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 2.2,
                      ),
                      itemBuilder: (context, index) {
                        final d = visible[index];
                        final info = districtVisualInfo(d.name);
                        return GestureDetector(
                          onTap: () => Navigator.pushNamed(
                            context,
                            AppStrings.districtDetailPath,
                            arguments: d,
                          ),
                          child: DistrictCard(
                            name: d.name,
                            sitesCount: d.sitesCount,
                            coverImageUrl: d.coverImageUrl.isNotEmpty ? d.coverImageUrl : null,
                            icon: info.icon,
                            iconColor: info.color,
                            iconBgColor: info.bgColor,
                          ),
                        );
                      },
                    ),
                  );
                }

                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  transitionBuilder: (child, anim) =>
                      FadeTransition(opacity: anim, child: child),
                  child: content,
                );
              },
            ),

            const SizedBox(height: 15),

            // --- Nearby Events ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Row(
                children: [
                  Text(
                    'Nearby Events 🔔',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).brightness == Brightness.light ? AppColors.textHeadline : AppColors.goldMain,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Consumer<EventProvider>(
              builder: (context, eventProvider, child) {
                final nearbyEvents = eventProvider.nearbyEvents;

                final Widget content;
                if (eventProvider.isLoading) {
                  content = const Padding(
                    key: ValueKey('events-skeleton'),
                    padding: EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      children: [EventCardSkeleton(), EventCardSkeleton()],
                    ),
                  );
                } else if (nearbyEvents.isEmpty) {
                  content = const Padding(
                    key: ValueKey('events-empty'),
                    padding: EdgeInsets.symmetric(horizontal: 24.0),
                    child: Text(
                      'No upcoming nearby events found.',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  );
                } else {
                  content = Padding(
                    key: const ValueKey('events-content'),
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      children: nearbyEvents.take(2).map((event) {
                        final km = eventProvider.distanceKmOf(event);
                        return EventListCard(
                          title: event.title,
                          date: '${event.startDate.day} ${_getMonthName(event.startDate.month)} ${event.startDate.year}',
                          location: event.locationName,
                          distance: km == null ? null : GeoDistance.shortLabel(km),
                          tag: event.eventType,
                          imageUrl: event.imageUrl,
                          shortDescription: event.shortDescription,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => EventDetailScreen(event: event)),
                          ),
                        );
                      }).toList(),
                    ),
                  );
                }

                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  transitionBuilder: (child, anim) =>
                      FadeTransition(opacity: anim, child: child),
                  child: content,
                );
              },
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
    ),
    );
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

}

class DynamicFeaturedCarousel extends StatefulWidget {
  final String selectedCategory;
  const DynamicFeaturedCarousel({super.key, required this.selectedCategory});

  @override
  State<DynamicFeaturedCarousel> createState() => _DynamicFeaturedCarouselState();
}

class _DynamicFeaturedCarouselState extends State<DynamicFeaturedCarousel> {
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
      final featured = provider.getFeaturedSites(category: widget.selectedCategory);
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
  void didUpdateWidget(DynamicFeaturedCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedCategory != widget.selectedCategory) {
      // Reset to first page when category changes
      _currentPage = 0;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
    }
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
        final featured = provider.getFeaturedSites(category: widget.selectedCategory);

        final Widget content;
        if (provider.isFeaturedLoading && featured.isEmpty) {
          content = SizedBox(
            key: const ValueKey('featured-skeleton'),
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
        } else if (featured.isEmpty) {
          content = SizedBox(
            key: const ValueKey('featured-empty'),
            height: 200,
            child: Center(child: Text(AppLocalizations.of(context)!.noFeaturedSites)),
          );
        } else {
          content = SizedBox(
            key: const ValueKey('featured-content'),
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
                  imageUrl: site.imageUrl,
                  reasonLabel: site.reason,
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
        }

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (child, anim) =>
              FadeTransition(opacity: anim, child: child),
          child: content,
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








