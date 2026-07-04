import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sampada/core/constants/app_colors.dart';
import 'package:sampada/core/constants/app_strings.dart';
import 'package:sampada/presentation/navigation/app_bottom_nav.dart';
import 'package:sampada/providers/heritage_provider.dart';
import 'package:sampada/presentation/widgets/heritage/heritage_widgets.dart';
import 'package:sampada/presentation/widgets/shared/shimmer_loading.dart';
import 'package:sampada/data/models/heritage_site.dart';

class HeritageSearchScreen extends StatefulWidget {
  const HeritageSearchScreen({super.key});

  @override
  State<HeritageSearchScreen> createState() => _HeritageSearchScreenState();
}

class _HeritageSearchScreenState extends State<HeritageSearchScreen> {
  late final TextEditingController _searchController;

  // Dynamic, data-driven filter — same approach as the home screen:
  // category chips are derived from the sites actually loaded, and filtering
  // is done client-side. No separate /categories/ call, so it can't be broken
  // by an empty response or a stale token, and only categories that actually
  // have sites are shown.
  String? _selectedSlug;    // null = All
  String _query = '';

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<HeritageProvider>(context, listen: false);
    _searchController = TextEditingController(text: provider.currentQuery);
    _query = provider.currentQuery.toLowerCase();

    // Load the full (unfiltered) site list once; chips + filtering derive from it.
    WidgetsBinding.instance.addPostFrameCallback((_) => provider.fetchSites());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() => _query = value.trim().toLowerCase());
  }

  void _onClearSearch() {
    _searchController.clear();
    setState(() => _query = '');
  }

  void _onCategoryTap(String? slug) {
    setState(() => _selectedSlug = slug);
  }

  // Normalise a category display name (name_en) to its slug, matching the
  // backend seed slugs (temple, stupa, durbar, …). Mirrors the provider.
  String _slug(String raw) {
    final s = raw.toLowerCase().trim();
    const map = {
      'durbar square': 'durbar', 'durbar sq.': 'durbar',
      'lake / natural': 'lake', 'durbar squares': 'durbar',
    };
    return map[s] ?? s;
  }

  // Distinct categories present in the loaded sites, as (label, slug) pairs.
  List<_Category> _presentCategories(List<HeritageSite> sites) {
    final seen = <String, String>{}; // slug -> label
    for (final s in sites) {
      final label = s.category.trim();
      if (label.isEmpty) continue;
      seen.putIfAbsent(_slug(label), () => label);
    }
    final cats = seen.entries.map((e) => _Category(label: e.value, apiValue: e.key)).toList()
      ..sort((a, b) => a.label.compareTo(b.label));
    return [const _Category(label: 'All', apiValue: null), ...cats];
  }

  // Client-side filter by selected category slug + search query.
  List<HeritageSite> _visibleSites(List<HeritageSite> sites) {
    return sites.where((s) {
      final matchCat = _selectedSlug == null || _slug(s.category) == _selectedSlug;
      if (!matchCat) return false;
      if (_query.isEmpty) return true;
      return s.name.toLowerCase().contains(_query) ||
          s.nameNepali.toLowerCase().contains(_query) ||
          s.district.toLowerCase().contains(_query);
    }).toList();
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
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
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
            builder: (context, provider, _) => TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: const TextStyle(fontSize: 15, color: Color(0xFF331609)),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                hintText: 'Search heritage sites...',
                hintStyle: const TextStyle(color: Color(0xFFB08060), fontSize: 14),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF8C7162), size: 22),
                suffixIcon: _searchController.text.isNotEmpty
                    ? GestureDetector(
                        onTap: _onClearSearch,
                        child: const Icon(Icons.close, color: Color(0xFF8C7162), size: 20),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: const BorderSide(color: Color(0xFFD4A040), width: 1.8),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: const BorderSide(color: Color(0xFFD4A040), width: 1.8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: const BorderSide(color: Color(0xFFD4A040), width: 2.0),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Category chips — derived from the sites actually loaded
          Consumer<HeritageProvider>(
            builder: (context, provider, _) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _presentCategories(provider.sites).map((cat) {
                  final isSelected = _selectedSlug == cat.apiValue;
                  return _CategoryPill(
                    label: cat.label,
                    isSelected: isSelected,
                    onTap: () => _onCategoryTap(cat.apiValue),
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
              '${_visibleSites(provider.sites).length} results found',
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

          final visible = _visibleSites(provider.sites);
          if (visible.isEmpty) {
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
            itemCount: visible.length,
            itemBuilder: (context, index) {
              final site = visible[index];
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
