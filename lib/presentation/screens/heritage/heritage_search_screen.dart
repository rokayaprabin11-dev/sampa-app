import 'package:flutter/material.dart';
import 'package:sampada/presentation/widgets/common/interactive_surface.dart';
import 'package:sampada/generated/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:sampada/core/constants/app_colors.dart';
import 'package:sampada/core/constants/app_strings.dart';
import 'package:sampada/presentation/navigation/app_bottom_nav.dart';
import 'package:sampada/providers/heritage_provider.dart';
import 'package:sampada/core/constants/app_dimensions.dart';
import 'package:sampada/core/services/location_service.dart';
import 'package:sampada/core/utils/geo_distance.dart';
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
  String? _selectedSlug; // null = All
  String _query = '';

  // Idle = nothing searched and no category chosen. Like standard search apps
  // (Airbnb/Booking/Maps), we don't dump the whole catalogue here — show recent
  // searches + a prompt instead. Typing or picking a category exits idle.
  bool get _isIdle => _query.isEmpty && _selectedSlug == null;

  // Real accuracy-gated GPS fix for "X km" labels on result cards. No
  // Kathmandu fallback here: without a real fix the label is hidden rather
  // than shown wrong (same rule as event cards).
  double? _userLat;
  double? _userLng;

  Future<void> _locateUser() async {
    final pos = await LocationService().getAccurateFix();
    if (pos == null || !mounted) return;
    setState(() {
      _userLat = pos.latitude;
      _userLng = pos.longitude;
    });
  }

  String? _distanceLabel(HeritageSite site) {
    if (_userLat == null || _userLng == null) return null;
    final km =
        GeoDistance.kmTo(_userLat!, _userLng!, site.latitude, site.longitude);
    return km == null ? null : GeoDistance.shortLabel(km);
  }

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<HeritageProvider>(context, listen: false);
    _searchController = TextEditingController(text: provider.currentQuery);
    _query = provider.currentQuery.toLowerCase();

    // Load the full (unfiltered) site list once; chips + filtering derive from it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      provider.fetchSites();
      provider.loadRecentSearches();
      _locateUser(); // relabels result cards when a real fix lands
    });
  }

  void _onSubmit(String value) {
    final q = value.trim();
    if (q.isEmpty) return;
    Provider.of<HeritageProvider>(context, listen: false).addRecentSearch(q);
  }

  void _onRecentTap(String q) {
    _searchController
      ..text = q
      ..selection = TextSelection.fromPosition(TextPosition(offset: q.length));
    _onSearchChanged(q);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    // Instant client-side filter for immediate feedback, plus a debounced
    // backend semantic search (typo-tolerant, matches Nepali + descriptions
    // across the whole catalogue) that refines the results when it returns.
    setState(() => _query = value.trim().toLowerCase());
    Provider.of<HeritageProvider>(context, listen: false)
        .onSearchChanged(value);
  }

  void _onClearSearch() {
    _searchController.clear();
    setState(() => _query = '');
    Provider.of<HeritageProvider>(context, listen: false).onSearchChanged('');
  }

  void _onCategoryTap(String? slug) {
    setState(() => _selectedSlug = slug);
  }

  // Normalise a category display name (name_en) to its slug, matching the
  // backend seed slugs (temple, stupa, durbar, …). Mirrors the provider.
  String _slug(String raw) {
    final s = raw.toLowerCase().trim();
    const map = {
      'durbar square': 'durbar',
      'durbar sq.': 'durbar',
      'lake / natural': 'lake',
      'durbar squares': 'durbar',
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
    final cats = seen.entries
        .map((e) => _Category(label: e.value, apiValue: e.key))
        .toList()
      ..sort((a, b) => a.label.compareTo(b.label));
    return [const _Category(label: 'All', apiValue: null), ...cats];
  }

  // Base result set for the current query: the full catalogue when empty, the
  // backend semantic-search results when available, else an instant client-side
  // substring match over the loaded sites (covers the debounce window + offline).
  List<HeritageSite> _baseList(HeritageProvider p) {
    if (_query.isEmpty) return p.sites;
    if (p.searchResults.isNotEmpty) return p.searchResults;
    return p.sites.where((s) {
      return s.name.toLowerCase().contains(_query) ||
          s.nameNepali.toLowerCase().contains(_query) ||
          s.district.toLowerCase().contains(_query);
    }).toList();
  }

  // Apply the selected category chip on top of the base result set.
  List<HeritageSite> _visibleSites(HeritageProvider p) {
    final base = _baseList(p);
    if (_selectedSlug == null) return base;
    return base.where((s) => _slug(s.category) == _selectedSlug).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: Column(
        children: [
          _buildHeader(context),
          if (_isIdle)
            Expanded(child: _buildIdleState())
          else ...[
            _buildSearchError(),
            _buildResultsCount(),
            _buildGrid(),
          ],
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
          colors: [
            AppColors.kColorDeep,
            AppColors.kColorPrimaryMid,
            AppColors.kColorPrimary
          ],
          stops: [0.0, 0.6, 1.0],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back button
          InteractiveSurface(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.exploreHeritage,
            style: const TextStyle(
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
              onSubmitted: _onSubmit,
              textInputAction: TextInputAction.search,
              maxLength: 100,
              buildCounter: (_,
                      {required currentLength,
                      required isFocused,
                      maxLength}) =>
                  null,
              style: const TextStyle(
                  fontSize: 15, color: AppColors.kColorTextHeading),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                hintText: AppLocalizations.of(context)!.searchHeritageHint,
                hintStyle:
                    const TextStyle(color: Color(0xFFB08060), fontSize: 14),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                prefixIcon: const Icon(Icons.search,
                    color: AppColors.kColorTextMuted, size: 22),
                suffixIcon: _searchController.text.isNotEmpty
                    ? InteractiveSurface(
                        onTap: _onClearSearch,
                        child: const Icon(Icons.close,
                            color: AppColors.kColorTextMuted, size: 20),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppDimensions.kRadiusPill),
                  borderSide:
                      const BorderSide(color: Color(0xFFD4A040), width: 1.8),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppDimensions.kRadiusPill),
                  borderSide:
                      const BorderSide(color: Color(0xFFD4A040), width: 1.8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppDimensions.kRadiusPill),
                  borderSide:
                      const BorderSide(color: Color(0xFFD4A040), width: 2.0),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Tells the user the catalogue below is cached, not live — either
          // auto-sync blocked the refresh or the request failed.
          Consumer<HeritageProvider>(
            builder: (context, provider, _) => provider.isShowingCachedData
                ? const _OfflineDataBadge()
                : const SizedBox.shrink(),
          ),
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

  // Idle screen: recent searches (if any) + a prompt. No catalogue dump.
  Widget _buildIdleState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        children: [
          _buildRecentSearches(),
          _buildIdlePrompt(),
        ],
      ),
    );
  }

  Widget _buildIdlePrompt() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 60, 40, 40),
      child: Column(
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: const BoxDecoration(
              color: AppColors.kColorBorderCream,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.travel_explore_rounded,
                size: 46, color: AppColors.kColorPrimary),
          ),
          const SizedBox(height: 20),
          Text(
            AppLocalizations.of(context)!.searchHeritageEmptyTitle,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.kColorTextHeading),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.searchHeritageEmptyBody,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 14, color: AppColors.kColorTextMuted, height: 1.5),
          ),
        ],
      ),
    );
  }

  // Recent searches — shown only before the user starts typing.
  Widget _buildRecentSearches() {
    if (_query.isNotEmpty) return const SizedBox.shrink();
    return Consumer<HeritageProvider>(
      builder: (context, provider, _) {
        final recents = provider.recentSearches;
        if (recents.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(AppLocalizations.of(context)!.recentSearches,
                      style: const TextStyle(
                          color: AppColors.kColorTextMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  InteractiveSurface(
                    onTap: provider.clearRecentSearches,
                    child: Text(AppLocalizations.of(context)!.btnClear,
                        style: const TextStyle(
                            color: AppColors.kColorPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: recents
                    .map((q) => InteractiveSurface(
                          onTap: () => _onRecentTap(q),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: AppColors.kColorBorderCream,
                              borderRadius: BorderRadius.circular(
                                  AppDimensions.kRadiusXxl),
                              border:
                                  Border.all(color: const Color(0xFFE3D2A8)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.history,
                                    size: 15, color: AppColors.kColorTextMuted),
                                const SizedBox(width: 6),
                                Text(q,
                                    style: const TextStyle(
                                        color: AppColors.kColorTextHeading,
                                        fontSize: 13)),
                              ],
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  // Non-blocking notice when backend search failed (client results still show).
  Widget _buildSearchError() {
    if (_query.isEmpty) return const SizedBox.shrink();
    return Consumer<HeritageProvider>(
      builder: (context, provider, _) {
        if (provider.searchError == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Row(
            children: [
              const Icon(Icons.cloud_off_rounded,
                  size: 16, color: Color(0xFFB0693C)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(provider.searchError!,
                    style: const TextStyle(
                        color: Color(0xFFB0693C), fontSize: 12)),
              ),
            ],
          ),
        );
      },
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
              '${_visibleSites(provider).length} results found',
              style: const TextStyle(
                color: AppColors.kColorTextMuted,
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

          final visible = _visibleSites(provider);
          if (visible.isEmpty) {
            // Don't flash "Not Found" while the backend search is still running.
            if (provider.isSearching) return _buildShimmerGrid();
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
                distance: _distanceLabel(site),
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
                color: AppColors.kColorBorderCream,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off_rounded,
                size: 48,
                color: AppColors.kColorPrimary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              AppLocalizations.of(context)!.labelNotFound,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.kColorTextHeading,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'No heritage sites match your search.\nTry a different keyword or category.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.kColorTextMuted,
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

/// "Offline data" chip — shown while the visible catalogue came from SQLite.
class _OfflineDataBadge extends StatelessWidget {
  const _OfflineDataBadge();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(AppDimensions.kRadiusPill),
          border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 14, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              AppLocalizations.of(context)!.offlineData,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
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
    return InteractiveSurface(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.kColorPrimary
              : Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppDimensions.kRadiusXxl),
          border: Border.all(
            color: isSelected ? AppColors.kColorPrimary : Colors.white38,
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
