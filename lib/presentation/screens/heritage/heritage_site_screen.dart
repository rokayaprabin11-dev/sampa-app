import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sampada/core/constants/app_colors.dart';
import 'package:sampada/generated/app_localizations.dart';
import 'package:sampada/providers/profile_provider.dart';
import 'package:sampada/data/models/heritage_site_model.dart';

class HeritageSiteScreen extends StatefulWidget {
  const HeritageSiteScreen({super.key});

  @override
  State<HeritageSiteScreen> createState() => _HeritageSiteScreenState();
}

class _HeritageSiteScreenState extends State<HeritageSiteScreen> {
  HeritageSiteModel? _site;
  bool _isInit = false;
  
  String? _displayDescription;
  String? _displayImageUrl;
  bool _isSubSiteView = false;
  
  int _currentCarouselIndex = 0;
  final PageController _pageController = PageController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is HeritageSiteModel) {
        _site = args;
        _displayDescription = _site!.description;
        _displayImageUrl = _site!.imageUrl;
        
        // Record visit
        WidgetsBinding.instance.addPostFrameCallback((_) {
          context.read<ProfileProvider>().addToVisitHistory(_site!.id);
        });
      }
      _isInit = true;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_site == null) {
      final l10n = AppLocalizations.of(context)!;
      return Scaffold(body: Center(child: Text(l10n.siteNotFound)));
    }

    final size = MediaQuery.of(context).size;
    final profileProvider = context.watch<ProfileProvider>();
    
    // Main carousel images (if any)
    final List<String> carouselImages = [
      if (_site!.imageUrl != null && _site!.imageUrl!.isNotEmpty) _site!.imageUrl!,
    ];

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: Stack(
        children: [
          // 1. Top Section: Carousel OR Static Image
          SizedBox(
            height: size.height * 0.45,
            child: Stack(
              children: [
                if (_isSubSiteView && _displayImageUrl != null)
                  Image.network(
                    _displayImageUrl!,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
                  )
                else if (carouselImages.isNotEmpty)
                  PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) => setState(() => _currentCarouselIndex = index),
                    itemCount: carouselImages.length,
                    itemBuilder: (context, index) {
                      return Image.network(
                        carouselImages[index],
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
                      );
                    },
                  )
                else
                  _buildPlaceholder(),
                
                // Dark overlay for readability
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.6),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.3),
                      ],
                    ),
                  ),
                ),
                
                // Carousel Indicators (only in main mode)
                if (!_isSubSiteView && carouselImages.length > 1)
                  Positioned(
                    bottom: 60,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        carouselImages.length,
                        (index) => Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _currentCarouselIndex == index 
                                ? AppColors.goldMain 
                                : Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // 2. Header Content (Back button, Bookmark)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () {
                      if (_isSubSiteView) {
                        setState(() {
                          _isSubSiteView = false;
                          _displayDescription = _site!.description;
                          _displayImageUrl = _site!.imageUrl;
                        });
                      } else {
                        Navigator.pop(context);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                    ),
                  ),
                  FutureBuilder<bool>(
                    future: profileProvider.isBookmarked(_site!.id),
                    builder: (context, snapshot) {
                      final isBookmarked = snapshot.data ?? false;
                      return GestureDetector(
                        onTap: () => profileProvider.toggleBookmark(_site!.id.toString()),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.4),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                            color: AppColors.goldMain,
                            size: 24,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // 3. Main Content Card
          DraggableScrollableSheet(
            initialChildSize: 0.6,
            minChildSize: 0.6,
            maxChildSize: 0.95,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(40),
                    topRight: Radius.circular(40),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Site Title
                      Text(
                        _site!.name.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF331609),
                          fontFamily: 'serif',
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // UNESCO Badge
                      if (_site!.isUnesco)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFDF8E8),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFF7EED3)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.emoji_events, color: Color(0xFFD4520A), size: 16),
                              SizedBox(width: 8),
                              Text(
                                'UNESCO Heritage',
                                style: TextStyle(
                                  color: Color(0xFFB48325),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),

                      // Location
                      Row(
                        children: [
                          const Icon(Icons.location_on, color: Color(0xFF331609), size: 18),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _site!.location,
                              style: const TextStyle(
                                color: Color(0xFF331609),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: Color(0xFFF7EED3), thickness: 1.5),
                      const SizedBox(height: 16),

                      // About Section
                      const Text(
                        'About this Site',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF331609),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _displayDescription ?? '',
                        style: const TextStyle(
                          color: Color(0xFF6B5041),
                          fontSize: 15,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Gallery Section
                      const Text(
                        'Gallery',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF331609),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 90,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _site!.gallery.length,
                          itemBuilder: (context, index) {
                            final image = _site!.gallery[index];
                            final isSelected = _isSubSiteView && _displayImageUrl == image.imageUrl;
                            
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _isSubSiteView = true;
                                  _displayDescription = image.caption.isNotEmpty 
                                      ? image.caption 
                                      : _site!.description;
                                  _displayImageUrl = image.imageUrl;
                                });
                              },
                              child: Container(
                                width: 90,
                                margin: const EdgeInsets.only(right: 12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected ? AppColors.goldMain : Colors.transparent,
                                    width: 2,
                                  ),
                                  image: DecorationImage(
                                    image: NetworkImage(image.imageUrl),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: _buildActionButton(
                              icon: Icons.map_outlined,
                              label: 'View Map',
                              onTap: () {},
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildActionButton(
                              icon: Icons.near_me_outlined,
                              label: 'Directions',
                              onTap: () {},
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Offline Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFC8E6C9)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check, color: Color(0xFF2E7D32), size: 16),
                            SizedBox(width: 8),
                            Text(
                              'Available Offline',
                              style: TextStyle(
                                color: Color(0xFF2E7D32),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(27),
        border: Border.all(color: const Color(0xFFF7EED3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(27),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: const Color(0xFF331609), size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF331609),
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
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
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF3A0A00), Color(0xFF7B1E00)],
        ),
      ),
      child: Center(
        child: Icon(
          _getIconForCategory(_site?.category ?? 'heritage'),
          size: 150,
          color: const Color(0xFFD4A017).withValues(alpha: 0.3),
        ),
      ),
    );
  }

  IconData _getIconForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'temple':
        return Icons.temple_hindu;
      case 'stupa':
        return Icons.temple_buddhist;
      case 'palace':
        return Icons.castle;
      default:
        return Icons.account_balance;
    }
  }
}







