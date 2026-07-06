import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sampada/core/constants/app_colors.dart';
import 'package:sampada/presentation/navigation/app_bottom_nav.dart';
import 'package:sampada/providers/guide_provider.dart';
import 'package:sampada/providers/auth_provider.dart';
import 'package:sampada/presentation/screens/guides/guide_detail_screen.dart';

class GuideScreen extends StatefulWidget {
  const GuideScreen({super.key});

  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends State<GuideScreen> {
  String _selectedFilter = 'Nearby';
  final _searchController = TextEditingController();

  // Reference point for distance labels (Kathmandu) — no live geolocation yet.
  static const _refLat = 27.7172;
  static const _refLng = 85.3240;

  static const _chips = ['Nearby', 'Top Rated', 'Temple Expert', 'Trekking', 'Culture', 'Language'];

  static const _langShort = {
    'english': 'EN',
    'nepali': 'नेपाली',
    'hindi': 'हिन्दी',
    'chinese': '中文',
    'japanese': '日本語',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final gp = context.read<GuideProvider>();
      gp.fetchGuides();
      // Profile/bookings are per-user (auth required) — skip when logged out
      // to avoid 401 noise during the sign-out/sign-in transition.
      if (context.read<AuthProvider>().isAuthenticated) {
        gp.fetchMyBookings();  // gates the Review action
        gp.fetchMyProfile();   // detects the user's own guide card
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ─── Data helpers ─────────────────────────────────────────────

  double _ratingOf(Map<String, dynamic> g) => double.tryParse('${g['rating_avg'] ?? ''}') ?? 0.0;
  int _reviewsOf(Map<String, dynamic> g) => (g['review_count'] as int?) ?? 0;

  bool _isTopGuide(Map<String, dynamic> g) => _ratingOf(g) >= 4.5 && _reviewsOf(g) >= 10;

  String? _distanceLabel(Map<String, dynamic> g) {
    final lat = g['latitude'], lng = g['longitude'];
    if (lat is num && lng is num) {
      const r = 6371.0;
      final dLat = (lat - _refLat) * math.pi / 180;
      final dLng = (lng - _refLng) * math.pi / 180;
      final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
          math.cos(_refLat * math.pi / 180) * math.cos(lat * math.pi / 180) *
              math.sin(dLng / 2) * math.sin(dLng / 2);
      final km = r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
      return '${km.toStringAsFixed(1)} km';
    }
    return null;
  }

  String _locationOf(Map<String, dynamic> g) {
    final areas = (g['areas'] as List?) ?? [];
    return areas.isNotEmpty ? areas.first.toString() : 'Nepal';
  }

  /// Search + chip filter, then sort so featured/nearby split is meaningful.
  List<Map<String, dynamic>> _process(List<Map<String, dynamic>> guides) {
    final q = _searchController.text.toLowerCase();
    var list = guides.where((g) {
      final user = g['user'] as Map<String, dynamic>? ?? {};
      final name = (user['full_name'] ?? user['username'] ?? '').toString().toLowerCase();
      final spec = ((g['specialties'] as List?) ?? []).join(' ').toLowerCase();
      final langs = ((g['languages'] as List?) ?? []).join(' ').toLowerCase();
      return q.isEmpty || name.contains(q) || spec.contains(q) || langs.contains(q);
    }).toList();

    bool specContains(Map<String, dynamic> g, List<String> needles) {
      final hay = ('${(g['specialties'] as List?) ?? []} ${(g['tour_types'] as List?) ?? []}').toLowerCase();
      return needles.any(hay.contains);
    }

    switch (_selectedFilter) {
      case 'Top Rated':
        list.sort((a, b) => _ratingOf(b).compareTo(_ratingOf(a)));
      case 'Temple Expert':
        list = list.where((g) => specContains(g, ['temple', 'stupa', 'durbar'])).toList();
      case 'Trekking':
        list = list.where((g) => specContains(g, ['trek', 'everest', 'mustang'])).toList();
      case 'Culture':
        list = list.where((g) => specContains(g, ['cultur', 'newari', 'festival', 'heritage'])).toList();
      case 'Language':
        list.sort((a, b) => ((b['languages'] as List?)?.length ?? 0).compareTo((a['languages'] as List?)?.length ?? 0));
      case 'Nearby':
      default:
        list.sort((a, b) {
          final da = _distanceLabel(a) == null ? 1 : 0;
          final db = _distanceLabel(b) == null ? 1 : 0;
          if (da != db) return da - db;
          return _ratingOf(b).compareTo(_ratingOf(a));
        });
    }
    return list;
  }

  void _openDetail(Map<String, dynamic> guide) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => GuideDetailScreen(guide: guide)),
      );

  /// True when this guide card belongs to the logged-in user (their own
  /// profile) — they can't hire or review themselves.
  bool _isSelf(Map<String, dynamic> guide) {
    final mine = context.read<GuideProvider>().myProfile;
    return mine != null && mine['id'] != null && mine['id'] == guide['id'];
  }

  /// True when the tourist has an unanswered request with this guide.
  bool _hasPending(Map<String, dynamic> guide) {
    final id = guide['id'];
    return id is int && context.read<GuideProvider>().hasPendingWith(id);
  }

  Widget _pendingBanner(BuildContext context, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFFDF3DC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEAD9A8)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.hourglass_top, size: 16, color: Color(0xFF9A6200)),
          const SizedBox(width: 6),
          const Text('Request pending — awaiting response',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF9A6200))),
        ],
      ),
    );
  }

  Widget _selfBanner(BuildContext context, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBgCard : const Color(0xFFF5EFEC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFE0D5CC)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_outline, size: 16, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF8C7162)),
          const SizedBox(width: 6),
          Text('This is your guide profile',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF8C7162))),
        ],
      ),
    );
  }

  void _comingSoon(String what) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$what is coming soon.')),
      );

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  /// Reviews are tied to a completed booking. Find the tourist's completed,
  /// not-yet-reviewed booking with this guide, then open the rating dialog.
  Future<void> _reviewGuide(Map<String, dynamic> guide) async {
    final gp = context.read<GuideProvider>();
    final gid = guide['id'];

    Map<String, dynamic>? booking;
    for (final b in gp.myBookings) {
      if (b['guide'] == gid && b['status'] == 'completed' && b['reviewed_at'] == null) {
        booking = b;
        break;
      }
    }

    if (booking == null) {
      // Distinguish "already reviewed" from "no completed tour" for clarity.
      final hasCompleted = gp.myBookings.any((b) => b['guide'] == gid && b['status'] == 'completed');
      _snack(hasCompleted
          ? "You've already reviewed this guide."
          : 'You can review a guide after completing a tour with them.');
      return;
    }

    final result = await _showReviewDialog(guide);
    if (result == null) return; // cancelled

    final err = await gp.reviewBooking(booking['id'] as int, result.$1, result.$2);
    if (!mounted) return;
    if (err == null) {
      _snack('Thanks for your review!');
      gp.fetchGuides(); // refresh the guide's rating
    } else {
      _snack('Could not submit review: $err');
    }
  }

  /// Returns (rating, text) or null if cancelled.
  Future<(int, String)?> _showReviewDialog(Map<String, dynamic> guide) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.goldMain : const Color(0xFF7B1E00);
    final user = guide['user'] as Map<String, dynamic>? ?? {};
    final name = (user['full_name'] ?? user['username'] ?? 'this guide').toString();
    final controller = TextEditingController();
    int rating = 5;

    return showDialog<(int, String)?>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Review $name', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final filled = i < rating;
                  return IconButton(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    constraints: const BoxConstraints(),
                    onPressed: () => setLocal(() => rating = i + 1),
                    icon: Icon(filled ? Icons.star : Icons.star_border, color: const Color(0xFFDCA73A), size: 32),
                  );
                }),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 3,
                maxLength: 300,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Share your experience (optional)…',
                  hintStyle: TextStyle(color: isDark ? AppColors.darkTextTertiary : Colors.grey, fontSize: 13),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, null), child: Text('Cancel', style: TextStyle(color: isDark ? AppColors.darkTextSecondary : Colors.grey))),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, (rating, controller.text.trim())),
              style: ElevatedButton.styleFrom(backgroundColor: accent, foregroundColor: isDark ? Colors.black : Colors.white),
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Consumer<GuideProvider>(
        builder: (context, guideProvider, _) {
          final all = guideProvider.guides;
          final processed = _process(all);
          final featured = processed.take(2).toList();
          final nearby = processed.skip(2).toList();

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _header(context, isDark, size, guideProvider)),
              const SliverToBoxAdapter(child: SizedBox(height: 52)),

              // Stats
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Row(
                    children: [
                      _statCard(context, '${all.length}', 'Guides Available'),
                      const SizedBox(width: 12),
                      _statCard(context, '77', 'Districts Covered'),
                      const SizedBox(width: 12),
                      _statCard(
                        context,
                        all.isEmpty ? '–' : (all.map(_ratingOf).reduce((a, b) => a + b) / all.length).toStringAsFixed(1),
                        'Avg Rating',
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),

              // Filter chips
              SliverToBoxAdapter(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(children: _chips.map((f) => _chip(context, f)).toList()),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),

              // Error
              if (guideProvider.error != null)
                SliverToBoxAdapter(child: _errorBox(context)),

              // Loading
              if (guideProvider.isLoading && all.isEmpty)
                SliverList(
                  delegate: SliverChildBuilderDelegate((_, __) => _skeleton(context), childCount: 3),
                )
              else if (processed.isEmpty && !guideProvider.isLoading)
                SliverToBoxAdapter(child: _emptyState(context, isDark, all.isEmpty))
              else ...[
                // Featured section
                if (featured.isNotEmpty) ...[
                  SliverToBoxAdapter(child: _sectionHeader(context, isDark, 'FEATURED GUIDES', showSeeAll: true)),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => _featuredCard(context, isDark, featured[i]),
                      childCount: featured.length,
                    ),
                  ),
                ],
                // Nearby section
                if (nearby.isNotEmpty) ...[
                  SliverToBoxAdapter(child: _sectionHeader(context, isDark, 'NEARBY GUIDES')),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => _nearbyCard(context, isDark, nearby[i]),
                      childCount: nearby.length,
                    ),
                  ),
                ],
              ],

              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          );
        },
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 2),
    );
  }

  // ─── Header ───────────────────────────────────────────────────

  Widget _header(BuildContext context, bool isDark, Size size, GuideProvider gp) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: size.height * 0.27,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                isDark ? AppColors.brownDeep : const Color(0xFF5D1700),
                isDark ? AppColors.brownDark : const Color(0xFF9E3D1A),
              ],
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _headerCircle(child: const Icon(Icons.menu, color: Colors.white70, size: 18)),
                    const Text(
                      'SAMPADA • सम्पदा',
                      style: TextStyle(color: Color(0xFFDCA73A), fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 14),
                    ),
                    _headerCircle(
                      onTap: gp.isLoading ? null : () => gp.fetchGuides(),
                      child: gp.isLoading
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.refresh, color: Colors.white70, size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Text(
                  'Find Your\nHeritage Guide',
                  style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, height: 1.1),
                ),
                const SizedBox(height: 8),
                Container(width: 40, height: 3, decoration: BoxDecoration(color: const Color(0xFFDCA73A), borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 10),
                const Text(
                  "Book certified local guides across Nepal's 77 districts",
                  style: TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.3),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: -28, left: 24, right: 24,
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkBgCard : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFF7EED3)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Row(
              children: [
                Icon(Icons.search, color: isDark ? AppColors.goldMain : const Color(0xFF7B1E00), size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search guides by name, language...',
                      hintStyle: TextStyle(color: isDark ? AppColors.darkTextSecondary : const Color(0xFF8C7162), fontSize: 14),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _headerCircle({required Widget child, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), shape: BoxShape.circle),
        child: Center(child: child),
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, bool isDark, String title, {bool showSeeAll = false}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, letterSpacing: 1.0, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF8C7162))),
          if (showSeeAll)
            Text('See all →', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: isDark ? AppColors.goldMain : const Color(0xFFC8851A))),
        ],
      ),
    );
  }

  // ─── Cards ────────────────────────────────────────────────────

  Widget _avatar(BuildContext context, bool isDark, Map<String, dynamic> guide, double radius) {
    final user = guide['user'] as Map<String, dynamic>? ?? {};
    final fullName = (user['full_name'] ?? user['username'] ?? 'Guide').toString();
    final initials = fullName.split(' ').take(2).map((p) => p.isNotEmpty ? p[0].toUpperCase() : '').join();
    final photoUrl = guide['photo_url'] as String?;
    return Stack(
      children: [
        CircleAvatar(
          radius: radius,
          backgroundColor: isDark ? AppColors.darkBgCard : const Color(0xFF7B1E00),
          backgroundImage: (photoUrl != null && photoUrl.isNotEmpty) ? NetworkImage(photoUrl) : null,
          child: (photoUrl == null || photoUrl.isEmpty)
              ? Text(initials, style: TextStyle(color: const Color(0xFFDCA73A), fontSize: radius * 0.6, fontWeight: FontWeight.bold))
              : null,
        ),
        Positioned(
          bottom: 0, right: 2,
          child: Container(
            width: 13, height: 13,
            decoration: BoxDecoration(color: const Color(0xFF2ECC71), shape: BoxShape.circle, border: Border.all(color: isDark ? AppColors.darkBgCard : Colors.white, width: 2)),
          ),
        ),
      ],
    );
  }

  Widget _featuredCard(BuildContext context, bool isDark, Map<String, dynamic> guide) {
    final user = guide['user'] as Map<String, dynamic>? ?? {};
    final fullName = (user['full_name'] ?? user['username'] ?? 'Guide').toString();
    final rating = _ratingOf(guide);
    final reviews = _reviewsOf(guide);
    final rate = guide['hourly_rate'];
    final isVerified = (guide['is_verified'] as bool?) ?? false;
    final specialties = ((guide['specialties'] as List?) ?? []).cast<String>();
    final languages = ((guide['languages'] as List?) ?? []).cast<String>();
    final dist = _distanceLabel(guide);
    final accent = isDark ? AppColors.goldMain : const Color(0xFF7B1E00);

    return GestureDetector(
      onTap: () => _openDetail(guide),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFF3E4C4), width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _avatar(context, isDark, guide, 30),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(fullName, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 12, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF8C7162)),
                          const SizedBox(width: 2),
                          Text(
                            [if (dist != null) dist, _locationOf(guide)].join(' · '),
                            style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF8C7162)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (_isTopGuide(guide))
                      _pill('⭐ Top Guide', const Color(0xFFDCA73A), Colors.white),
                    if (isVerified) ...[
                      if (_isTopGuide(guide)) const SizedBox(height: 6),
                      _pill('✓ Verified', isDark ? AppColors.darkBgCard : const Color(0xFFE8F5EC), const Color(0xFF2E7D32)),
                    ],
                  ],
                ),
              ],
            ),
            if (specialties.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(spacing: 6, runSpacing: 6, children: specialties.take(3).map((s) => _tag(context, isDark, s)).toList()),
            ],
            if (languages.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: languages.map((l) => _langChip(context, isDark, l)).toList()),
            ],
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.star, color: Color(0xFFDCA73A), size: 15),
                          const SizedBox(width: 4),
                          Text(rating.toStringAsFixed(1), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Theme.of(context).colorScheme.onSurface)),
                          const SizedBox(width: 4),
                          Text('($reviews reviews)', style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextTertiary : const Color(0xFF8C7162))),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text('Available today 9 AM – 6 PM', style: TextStyle(fontSize: 10.5, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF8C7162))),
                    ],
                  ),
                ),
                if (rate != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('NPR $rate', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: accent)),
                      Text('per half day', style: TextStyle(fontSize: 10, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF8C7162))),
                    ],
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: isDark ? AppColors.darkBorder : const Color(0xFFF3E4C4)),
            ),
            if (_isSelf(guide))
              _selfBanner(context, isDark)
            else if (_hasPending(guide))
              _pendingBanner(context, isDark)
            else
              Row(
                children: [
                  Expanded(child: _outlineBtn(context, isDark, 'Message', () => _comingSoon('Messaging'))),
                  const SizedBox(width: 8),
                  Expanded(child: _outlineBtn(context, isDark, 'Review', () => _reviewGuide(guide))),
                  const SizedBox(width: 8),
                  Expanded(flex: 2, child: _filledBtn(context, isDark, 'Hire Now', () => _openDetail(guide))),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _nearbyCard(BuildContext context, bool isDark, Map<String, dynamic> guide) {
    final user = guide['user'] as Map<String, dynamic>? ?? {};
    final fullName = (user['full_name'] ?? user['username'] ?? 'Guide').toString();
    final rating = _ratingOf(guide);
    final reviews = _reviewsOf(guide);
    final rate = guide['hourly_rate'];
    final isVerified = (guide['is_verified'] as bool?) ?? false;
    final specialties = ((guide['specialties'] as List?) ?? []).cast<String>();
    final languages = ((guide['languages'] as List?) ?? []).cast<String>();
    final dist = _distanceLabel(guide);
    final accent = isDark ? AppColors.goldMain : const Color(0xFF7B1E00);

    return GestureDetector(
      onTap: () => _openDetail(guide),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFF7EED3), width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _avatar(context, isDark, guide, 26),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(child: Text(fullName, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface), overflow: TextOverflow.ellipsis)),
                          if (isVerified) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.verified, size: 15, color: Color(0xFF2E7D32)),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 12, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF8C7162)),
                          const SizedBox(width: 2),
                          Text(
                            [if (dist != null) dist, _locationOf(guide)].join(' · '),
                            style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF8C7162)),
                          ),
                        ],
                      ),
                      if (specialties.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(spacing: 6, runSpacing: 6, children: specialties.take(2).map((s) => _tag(context, isDark, s)).toList()),
                      ],
                    ],
                  ),
                ),
                if (rate != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('NPR $rate', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: accent)),
                      Text('/ half day', style: TextStyle(fontSize: 10, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF8C7162))),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.star, color: Color(0xFFDCA73A), size: 14),
                const SizedBox(width: 4),
                Text(rating.toStringAsFixed(1), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Theme.of(context).colorScheme.onSurface)),
                const SizedBox(width: 4),
                Text('($reviews)', style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextTertiary : const Color(0xFF8C7162))),
                const Spacer(),
                if (languages.isNotEmpty)
                  Wrap(spacing: 6, children: languages.take(3).map((l) => _langChip(context, isDark, l)).toList()),
              ],
            ),
            const SizedBox(height: 14),
            if (_isSelf(guide))
              _selfBanner(context, isDark)
            else if (_hasPending(guide))
              _pendingBanner(context, isDark)
            else
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _openDetail(guide),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: accent,
                    side: BorderSide(color: accent),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Request Guide', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─── Small widgets ────────────────────────────────────────────

  Widget _statCard(BuildContext context, String value, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFF7EED3)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? AppColors.goldMain : const Color(0xFF7B1E00))),
            const SizedBox(height: 4),
            Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF8C7162))),
          ],
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = label),
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? (isDark ? AppColors.goldMain : const Color(0xFF7B1E00)) : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: isSelected ? (isDark ? AppColors.goldMain : const Color(0xFF7B1E00)) : (isDark ? AppColors.darkBorder : const Color(0xFFF3E4C4))),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? (isDark ? Colors.black : Colors.white) : Theme.of(context).colorScheme.onSurface,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _pill(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(color: fg, fontSize: 10.5, fontWeight: FontWeight.bold)),
    );
  }

  Widget _tag(BuildContext context, bool isDark, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBgCard : const Color(0xFFFBEFD6),
        borderRadius: BorderRadius.circular(20),
        border: isDark ? Border.all(color: AppColors.darkBorder) : null,
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF8A5A1E), fontWeight: FontWeight.w500)),
    );
  }

  Widget _langChip(BuildContext context, bool isDark, String lang) {
    final short = _langShort[lang.toLowerCase()] ?? lang;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBgCard : const Color(0xFFF2EFE9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFE5DDD0)),
      ),
      child: Text(short, style: TextStyle(fontSize: 10.5, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B5041))),
    );
  }

  Widget _outlineBtn(BuildContext context, bool isDark, String label, VoidCallback onTap) {
    final accent = isDark ? AppColors.goldMain : const Color(0xFF7B1E00);
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: accent,
        side: BorderSide(color: isDark ? AppColors.darkBorder : const Color(0xFFE0D5CC)),
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
    );
  }

  Widget _filledBtn(BuildContext context, bool isDark, String label, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: isDark ? AppColors.goldMain : const Color(0xFF7B1E00),
        foregroundColor: isDark ? Colors.black : Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 0,
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
    );
  }

  Widget _errorBox(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade200)),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade700),
            const SizedBox(width: 12),
            Expanded(child: Text('Failed to load guides. Tap refresh to retry.', style: TextStyle(color: Colors.red.shade700, fontSize: 13))),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext context, bool isDark, bool none) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(Icons.person_search, size: 64, color: isDark ? AppColors.darkTextTertiary : const Color(0xFFD4B8A8)),
          const SizedBox(height: 16),
          Text(none ? 'No guides registered yet.' : 'No guides match your search.', style: TextStyle(color: isDark ? AppColors.darkTextSecondary : const Color(0xFF8C7162))),
        ],
      ),
    );
  }

  Widget _skeleton(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0EDED);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFF7EED3)),
      ),
      child: Row(
        children: [
          CircleAvatar(radius: 30, backgroundColor: baseColor),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 14, width: 120, decoration: BoxDecoration(color: baseColor, borderRadius: BorderRadius.circular(7))),
                const SizedBox(height: 8),
                Container(height: 12, width: 80, decoration: BoxDecoration(color: baseColor, borderRadius: BorderRadius.circular(6))),
                const SizedBox(height: 8),
                Container(height: 10, width: 160, decoration: BoxDecoration(color: baseColor, borderRadius: BorderRadius.circular(5))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
