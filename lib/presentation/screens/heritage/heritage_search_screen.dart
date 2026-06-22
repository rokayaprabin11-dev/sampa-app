import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sampada/core/constants/app_colors.dart';
import 'package:sampada/core/constants/app_strings.dart';
import 'package:sampada/presentation/navigation/app_bottom_nav.dart';
import 'package:sampada/providers/heritage_provider.dart';
import 'package:sampada/presentation/widgets/heritage/heritage_widgets.dart';
import 'package:sampada/presentation/widgets/shared/shimmer_loading.dart';

class HeritageSearchScreen extends StatefulWidget {
  const HeritageSearchScreen({super.key});

  @override
  State<HeritageSearchScreen> createState() => _HeritageSearchScreenState();
}

class _HeritageSearchScreenState extends State<HeritageSearchScreen> {
  late final TextEditingController _searchController;

  static const List<_Category> _categories = [
    _Category(label: 'All', apiValue: null),
    _Category(label: 'Temples', apiValue: 'temple'),
    _Category(label: 'Durbar Sq.', apiValue: 'palace'),
    _Category(label: 'Stupas', apiValue: 'stupa'),
    _Category(label: 'Monasteries', apiValue: 'monastery'),
  ];

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<HeritageProvider>(context, listen: false);
    _searchController = TextEditingController(text: provider.currentQuery);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      provider.fetchSites();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value, HeritageProvider provider) {
    provider.search(query: value);
  }

  void _onClearSearch(HeritageProvider provider) {
    _searchController.clear();
    provider.search(query: '');
  }

  void _onCategoryTap(String label, HeritageProvider provider) {
    provider.search(category: label);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: Column(
        children: [
          _buildHeader(context),
          _buildResultsCount(),
          _buildGrid(),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: 20,
        right: 20,
        bottom: 20,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4A1200), Color(0xFF8B3010)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.25),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Explore Heritage',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Search across 77 districts of Nepal',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 16),
          // Search bar
          Consumer<HeritageProvider>(
            builder: (context, provider, _) => Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: const Color(0xFFD4A040), width: 1.8),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => _onSearchChanged(v, provider),
                style: const TextStyle(fontSize: 15, color: Color(0xFF331609)),
                decoration: InputDecoration(
                  hintText: 'Search heritage sites...',
                  hintStyle: const TextStyle(color: Color(0xFFB08060), fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF8C7162), size: 22),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? GestureDetector(
                          onTap: () => _onClearSearch(provider),
                          child: const Icon(Icons.close, color: Color(0xFF8C7162), size: 20),
                        )
                      : null,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Category chips
          Consumer<HeritageProvider>(
            builder: (context, provider, _) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _categories.map((cat) {
                  final isSelected = provider.currentCategory == cat.label;
                  return _CategoryPill(
                    label: cat.label,
                    isSelected: isSelected,
                    onTap: () => _onCategoryTap(cat.label, provider),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsCount() {
    return Consumer<HeritageProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${provider.sites.length} results found',
              style: const TextStyle(
                color: Color(0xFF8C7162),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGrid() {
    return Expanded(
      child: Consumer<HeritageProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return _buildShimmerGrid();
          }

          if (provider.sites.isEmpty) {
            return _buildNotFound();
          }

          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.82,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
            ),
            itemCount: provider.sites.length,
            itemBuilder: (context, index) {
              final site = provider.sites[index];
              return HeritageGridCard(
                name: site.name,
                location: site.district,
                distance: site.district,
                category: site.category,
                imageUrl: site.imageUrl,
                onTap: () => Navigator.pushNamed(
                  context,
                  AppStrings.heritageDetailsPath,
                  arguments: site,
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildShimmerGrid() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.82,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: 6,
      itemBuilder: (_, __) => const ShimmerSkeleton(
        width: double.infinity,
        height: double.infinity,
        borderRadius: 20,
      ),
    );
  }

  Widget _buildNotFound() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: const Color(0xFFF7EED3),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off_rounded,
                size: 48,
                color: Color(0xFFD4520A),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Not Found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF331609),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'No heritage sites match your search.\nTry a different keyword or category.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF8C7162),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── helpers ────────────────────────────────────────────────────────────────

class _Category {
  final String label;
  final String? apiValue;
  const _Category({required this.label, required this.apiValue});
}

class _CategoryPill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryPill({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFD4520A) : Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFFD4520A) : Colors.white38,
            width: 1.4,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
