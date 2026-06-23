import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sampada/core/constants/app_colors.dart';
import 'package:sampada/core/constants/app_strings.dart';
import 'package:sampada/presentation/navigation/app_bottom_nav.dart';
import 'package:sampada/presentation/widgets/shared/shimmer_loading.dart';
import 'package:sampada/presentation/widgets/heritage_widgets.dart';
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
      context.read<EventProvider>().loadEvents();
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Header Section ---
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: size.height * 0.22,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF5D1700),
                        Color(0xFF9E3D1A),
                      ],
                    ),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12),
                    child: Column(
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
                                  child: Icon(Icons.notifications, color: Color(0xFFDCA73A), size: 22),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'EXPLORE HERITAGE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            fontFamily: 'serif',
                          ),
                        ),
                      ],
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
                        borderRadius: BorderRadius.circular(25),
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

            // --- Categories ---
            SizedBox(
              height: 45,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  l10n.all,
                  l10n.temples,
                  l10n.stupas,
                  l10n.palaces,
                  l10n.monuments
                ].map((cat) => CategoryChip(
                  label: cat,
                  isSelected: _selectedCategory == cat || (_selectedCategory == 'All' && cat == l10n.all),
                  onTap: () => setState(() => _selectedCategory = cat),
                  isDesignStyle: true,
                )).toList(),
              ),
            ),

            const SizedBox(height: 32),

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

            const SizedBox(height: 32),

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
                            onPressed: () => Navigator.pushNamed(context, AppStrings.searchPath),
                            child: const Row(
                              children: [
                                Text('See All', style: TextStyle(color: Color(0xFFD4520A))),
                                Icon(Icons.arrow_forward, size: 16, color: Color(0xFFD4520A)),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Consumer<HeritageProvider>(
              builder: (context, heritageProvider, child) {
                if (heritageProvider.isLoading && heritageProvider.districts.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24.0),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final districts = heritageProvider.districts;
                if (districts.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24.0),
                    child: Text(
                      'No districts available',
                      style: TextStyle(color: Color(0xFF8C7162), fontSize: 14),
                    ),
                  );
                }

                final visible = districts.take(8).toList();
                return Padding(
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
                      final info = _districtInfo(d.name);
                      return DistrictCard(
                        name: d.name,
                        sitesCount: d.sitesCount,
                        icon: info.icon,
                        iconColor: info.color,
                        iconBgColor: info.bgColor,
                      );
                    },
                  ),
                );
              },
            ),

            const SizedBox(height: 32),

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
            const SizedBox(height: 16),
            Consumer<EventProvider>(
              builder: (context, eventProvider, child) {
                if (eventProvider.isLoading) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24.0),
                    child: EventCardSkeleton(),
                  );
                }

                final nearbyEvents = eventProvider.nearbyEvents;

                if (nearbyEvents.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24.0),
                    child: Text(
                      'No upcoming nearby events found.',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  );
                }

                // Show only the top 2 nearby events on the home screen
                return Column(
                  children: nearbyEvents.take(2).map((event) => Padding(
                    padding: const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 12),
                    child: EventCard(
                      title: event.title,
                      date: '${_getMonthName(event.startDate.month)} ${event.startDate.day}',
                      distance: '1.2 km away', // Simulated
                    ),
                  )).toList(),
                );
              },
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
    );
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  _DistrictInfo _districtInfo(String name) {
    switch (name.toLowerCase()) {
      case 'kathmandu':
        return _DistrictInfo(Icons.museum, const Color(0xFF5C4033), const Color(0xFFF3EBE5));
      case 'bhaktapur':
        return _DistrictInfo(Icons.castle, const Color(0xFF6D4C41), const Color(0xFFF5EDEA));
      case 'lalitpur':
        return _DistrictInfo(Icons.temple_hindu, const Color(0xFFB84B00), const Color(0xFFFFF0E6));
      case 'kaski':
      case 'pokhara':
        return _DistrictInfo(Icons.landscape, const Color(0xFF2E7D32), const Color(0xFFE8F5E9));
      case 'mustang':
        return _DistrictInfo(Icons.terrain, const Color(0xFF795548), const Color(0xFFEFEBE9));
      case 'dolakha':
        return _DistrictInfo(Icons.temple_buddhist, const Color(0xFFD84315), const Color(0xFFFBE9E7));
      case 'chitwan':
        return _DistrictInfo(Icons.forest, const Color(0xFF388E3C), const Color(0xFFE8F5E9));
      case 'solukhumbu':
        return _DistrictInfo(Icons.ac_unit, const Color(0xFF0277BD), const Color(0xFFE1F5FE));
      case 'manang':
      case 'myagdi':
        return _DistrictInfo(Icons.filter_hdr, const Color(0xFF546E7A), const Color(0xFFECEFF1));
      case 'dang':
      case 'banke':
        return _DistrictInfo(Icons.grass, const Color(0xFF558B2F), const Color(0xFFF1F8E9));
      case 'rupandehi':
      case 'kapilvastu':
        return _DistrictInfo(Icons.account_balance, const Color(0xFF6A1B9A), const Color(0xFFF3E5F5));
      case 'nawalpur':
      case 'palpa':
        return _DistrictInfo(Icons.park, const Color(0xFF1B5E20), const Color(0xFFE8F5E9));
      case 'kanchanpur':
      case 'kailali':
        return _DistrictInfo(Icons.water, const Color(0xFF0288D1), const Color(0xFFE1F5FE));
      default:
        return _DistrictInfo(Icons.location_city, const Color(0xFF8C7162), const Color(0xFFF5EFEC));
    }
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
                imageUrl: site.imageUrl,
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

// ─── file-level helper ───────────────────────────────────────────────────────

class _DistrictInfo {
  final IconData icon;
  final Color color;
  final Color bgColor;
  const _DistrictInfo(this.icon, this.color, this.bgColor);
}







