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
import 'heritage_site_screen.dart';

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
                            Container(
                              decoration: const BoxDecoration(
                                color: Color(0xFF3A241C),
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.notifications, color: Color(0xFFDCA73A), size: 22),
                                onPressed: () {
                                  Navigator.pushNamed(context, AppStrings.notificationsPath);
                                },
                                hoverColor: Colors.white10,
                                splashColor: Colors.white24,
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
              child: Text(
                l10n.browseByDistrict,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).brightness == Brightness.light ? AppColors.textHeadline : AppColors.goldMain,
                ),
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
                    child: Text('No districts available'),
                  );
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: districts.length > 4 ? 4 : districts.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 2.1,
                    ),
                    itemBuilder: (context, index) {
                      final d = districts[index];
                      return DistrictCard(
                        name: d.name, 
                        sitesCount: d.sitesCount, 
                        icon: _getIconForDistrict(d.name)
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

  IconData _getIconForDistrict(String name) {
    switch (name.toLowerCase()) {
      case 'kathmandu': return Icons.temple_hindu;
      case 'bhaktapur': return Icons.castle;
      case 'lalitpur': return Icons.temple_buddhist;
      case 'kaski':
      case 'pokhara': return Icons.landscape;
      default: return Icons.map;
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







