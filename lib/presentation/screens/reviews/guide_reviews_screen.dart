import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sampada/presentation/widgets/common/interactive_surface.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sampada/core/constants/app_colors.dart';
import 'package:sampada/core/constants/app_dimensions.dart';
import 'package:sampada/core/theme/app_theme.dart';
import 'package:sampada/generated/app_localizations.dart';
import 'package:sampada/presentation/screens/reviews/write_review_sheet.dart';
import 'package:sampada/presentation/widgets/common/app_network_image.dart';
import 'package:sampada/presentation/widgets/shared/shimmer_loading.dart';
import 'package:sampada/presentation/widgets/shared/loading_states.dart';
import 'package:sampada/providers/guide_provider.dart';

enum _Sort { recent, highest, lowest }

extension on _Sort {
  String get api => switch (this) {
        _Sort.recent => 'recent',
        _Sort.highest => 'highest',
        _Sort.lowest => 'lowest',
      };
  String label(AppLocalizations l10n) => switch (this) {
        _Sort.recent => l10n.sortMostRecent,
        _Sort.highest => l10n.sortHighestRated,
        _Sort.lowest => l10n.sortLowestRated,
      };
}

/// Every review of one guide.
///
/// A review is a completed booking that was rated, which is what makes the
/// "Verified booking" mark on each card true by construction rather than
/// decorative: you cannot rate a guide you never toured with.
///
/// The rating summary (average, star distribution, per-category averages) comes
/// from the server and covers *all* of the guide's reviews — searching or paging
/// narrows the list below it, never the bars above it.
class GuideReviewsScreen extends StatefulWidget {
  final Map<String, dynamic> guide;
  const GuideReviewsScreen({super.key, required this.guide});

  @override
  State<GuideReviewsScreen> createState() => _GuideReviewsScreenState();
}

class _GuideReviewsScreenState extends State<GuideReviewsScreen> {
  final _scroll = ScrollController();
  final _searchController = TextEditingController();
  Timer? _debounce;

  _Sort _sort = _Sort.recent;
  String _query = '';

  List<Map<String, dynamic>> _reviews = [];
  Map<String, dynamic> _summary = const {};
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _page = 1;
  String? _error;

  int get _guideId => widget.guide['id'] as int;

  String get _guideName {
    final user = widget.guide['user'] as Map<String, dynamic>? ?? {};
    return (user['full_name'] ??
            user['username'] ??
            AppLocalizations.of(context)!.tourGuide)
        .toString();
  }

  /// The viewer is this guide — they read their reviews and may reply, but
  /// cannot review themselves.
  bool get _isOwnProfile {
    final mine = context.read<GuideProvider>().myProfile;
    return mine != null && mine['id'] == widget.guide['id'];
  }

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore || _loading) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await context.read<GuideProvider>().fetchGuideReviews(
            _guideId,
            sort: _sort.api,
            search: _query,
          );
      if (!mounted) return;
      setState(() {
        _reviews = _rowsOf(data);
        _summary =
            (data['summary'] as Map?)?.cast<String, dynamic>() ?? const {};
        _hasMore = data['next'] != null;
        _page = 1;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    try {
      final data = await context.read<GuideProvider>().fetchGuideReviews(
            _guideId,
            sort: _sort.api,
            search: _query,
            page: _page + 1,
          );
      if (!mounted) return;
      setState(() {
        _reviews = [..._reviews, ..._rowsOf(data)];
        _hasMore = data['next'] != null;
        _page += 1;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  List<Map<String, dynamic>> _rowsOf(Map<String, dynamic> data) =>
      ((data['results'] as List?) ?? [])
          .whereType<Map>()
          .map((m) => m.cast<String, dynamic>())
          .toList();

  void _onSearchChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() => _query = q);
      _load();
    });
  }

  // ── Write a review ────────────────────────────────────────────────────────

  /// The booking that entitles this tourist to review this guide: completed, and
  /// not already reviewed. Null when there is none — which is exactly when the
  /// write button must not be offered.
  Map<String, dynamic>? get _reviewableBooking {
    if (_isOwnProfile) return null;
    for (final b in context.read<GuideProvider>().myBookings) {
      if (b['guide'] == _guideId &&
          b['status'] == 'completed' &&
          b['reviewed_at'] == null) {
        return b;
      }
    }
    return null;
  }

  Future<void> _writeReview() async {
    final booking = _reviewableBooking;
    if (booking == null) return;
    final gp = context.read<GuideProvider>();
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);

    final draft = await showWriteReviewSheet(context, guideName: _guideName);
    if (draft == null) return;

    final err = await gp.reviewBooking(
      booking['id'] as int,
      draft.rating,
      draft.text,
      categories: draft.categories,
    );
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(err ?? l10n.reviewThanks)));
    if (err == null) {
      gp.fetchGuides(); // the guide's headline rating just moved
      _load();
    }
  }

  Future<void> _reply(Map<String, dynamic> review) async {
    final gp = context.read<GuideProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();

    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.kRadiusXxl)),
        title: Text(l10n.replyTo('${review['reviewer_name']}'),
            style: Theme.of(ctx)
                .textTheme
                .titleMedium
                ?.copyWith(color: Theme.of(ctx).colorScheme.onSurface)),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          maxLength: 1000,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(hintText: l10n.replyHint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(ctx)!.btnCancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(AppLocalizations.of(ctx)!.btnSubmit),
          ),
        ],
      ),
    );
    if (text == null || text.isEmpty) return;

    final err = await gp.replyToReview(review['id'] as int, text);
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(err ?? l10n.replyPosted)));
    if (err == null) _load();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final canWrite = _reviewableBooking != null;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        color: AppColors.kColorPrimary,
        onRefresh: _load,
        child: CustomScrollView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _GuideHeader(guide: widget.guide, summary: _summary),
            if (_error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _ErrorView(onRetry: _load),
              )
            else ...[
              SliverToBoxAdapter(
                  child: _RatingOverview(summary: _summary, loading: _loading)),
              SliverToBoxAdapter(child: _searchAndSort(context)),
              if (_loading)
                SliverList.separated(
                  itemCount: 3,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppDimensions.sp12),
                  itemBuilder: (_, __) => const _ReviewSkeleton(),
                )
              else if (_reviews.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyView(
                    filtered: _query.isNotEmpty,
                    canWrite: canWrite,
                    onWrite: _writeReview,
                  ),
                )
              else
                SliverList.separated(
                  itemCount: _reviews.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppDimensions.sp12),
                  itemBuilder: (context, i) => _ReviewCard(
                    review: _reviews[i],
                    canReply: _isOwnProfile,
                    onReply: () => _reply(_reviews[i]),
                  ),
                ),
              if (_loadingMore)
                const SliverToBoxAdapter(child: LoadMoreIndicator()),
              SliverToBoxAdapter(
                  child: SizedBox(height: canWrite ? 96 : AppDimensions.sp32)),
            ],
          ],
        ),
      ),
      // Only a tourist with a completed, unreviewed tour can write one — the
      // server enforces the same rule, so offering it otherwise would only
      // produce a rejection.
      floatingActionButton:
          canWrite ? _WriteReviewButton(onTap: _writeReview) : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _searchAndSort(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppDimensions.sp16, AppDimensions.sp4,
          AppDimensions.sp16, AppDimensions.sp12),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            style: t.bodyMedium
                ?.copyWith(color: Theme.of(context).colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context)!.searchReviewsHint,
              prefixIcon: const Icon(Icons.search,
                  size: AppDimensions.iconMd, color: AppColors.kColorPrimary),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: AppDimensions.iconSm),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                        _load();
                      },
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimensions.kRadiusPill),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimensions.kRadiusPill),
                borderSide: BorderSide(
                    color: isDark
                        ? AppColors.kDarkBorder
                        : AppColors.kColorBorderSubtle),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimensions.kRadiusPill),
                borderSide:
                    const BorderSide(color: AppColors.kFocusRing, width: 2),
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.sp12),
          // Scrolls: the three labels do not fit a narrow phone, and at a large
          // text scale they would not fit any phone. Same treatment as the guide
          // list's filter chips.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _Sort.values.map((s) {
                final selected = s == _sort;
                return Padding(
                  padding: const EdgeInsets.only(right: AppDimensions.sp8),
                  child: ChoiceChip(
                    label: Text(s.label(AppLocalizations.of(context)!)),
                    selected: selected,
                    showCheckmark: false,
                    onSelected: (_) {
                      setState(() => _sort = s);
                      _load();
                    },
                    selectedColor: AppColors.kColorPrimary,
                    labelStyle: t.bodySmall?.copyWith(
                      color: selected
                          ? AppColors.kColorTextOnPrimary
                          : (isDark
                              ? AppColors.kDarkTextSecond
                              : AppColors.kColorTextSecondary),
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                    side: BorderSide(
                        color: selected
                            ? AppColors.kColorPrimary
                            : (isDark
                                ? AppColors.kDarkBorder
                                : AppColors.kColorBorderSubtle)),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Header ──────────────────────────────────────────────────────────────────

/// Gradient sliver header carrying the guide's identity. Collapses to a plain
/// bar on scroll — same pattern as guide_detail_screen.
class _GuideHeader extends StatelessWidget {
  final Map<String, dynamic> guide;
  final Map<String, dynamic> summary;

  const _GuideHeader({required this.guide, required this.summary});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;
    final user = guide['user'] as Map<String, dynamic>? ?? {};
    final name =
        (user['full_name'] ?? user['username'] ?? l10n.tourGuide).toString();
    final photo = guide['photo_url'] as String?;
    final verified = guide['is_verified'] == true;
    final languages =
        ((guide['languages'] as List?) ?? []).whereType<String>().toList();
    final years = guide['years_experience']?.toString();
    final total = summary['total'];

    final initials = name
        .split(' ')
        .take(2)
        .map((p) => p.isNotEmpty ? p[0].toUpperCase() : '')
        .join();

    return SliverAppBar(
      expandedHeight: 210,
      pinned: true,
      backgroundColor: AppColors.kColorDeep,
      foregroundColor: AppColors.kColorTextOnHeader,
      title: Text(l10n.guideReviewsTitle,
          style: t.titleLarge?.copyWith(color: AppColors.kColorTextOnHeader)),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(gradient: AppTheme.navGradient),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppDimensions.sp20, 56,
                  AppDimensions.sp20, AppDimensions.sp16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius:
                        BorderRadius.circular(AppDimensions.kRadiusXl),
                    child: SizedBox(
                      width: 64,
                      height: 64,
                      child: (photo == null || photo.isEmpty)
                          ? Container(
                              color: AppColors.kColorBrownRust,
                              alignment: Alignment.center,
                              child: Text(initials,
                                  style: t.titleMedium?.copyWith(
                                      color: AppColors.kColorAccentLight)),
                            )
                          : AppNetworkImage(
                              url: photo,
                              width: 64,
                              height: 64,
                              fit: BoxFit.cover,
                              cloudinaryWidth: 64,
                            ),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.sp14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: t.titleMedium?.copyWith(
                                      color: AppColors.kColorTextOnHeader)),
                            ),
                            if (verified) ...[
                              const SizedBox(width: AppDimensions.sp4),
                              const Icon(Icons.verified,
                                  size: 16, color: AppColors.kColorAccentLight),
                            ],
                          ],
                        ),
                        if (total != null)
                          Text(
                            l10n.reviewCountLabel((total as num).toInt()) +
                                (years != null && years.isNotEmpty
                                    ? ' · ${l10n.yearsExperienceShort(years)}'
                                    : ''),
                            style: t.bodySmall
                                ?.copyWith(color: AppColors.kColorBgWarm),
                          ),
                        if (languages.isNotEmpty) ...[
                          const SizedBox(height: AppDimensions.sp8),
                          Wrap(
                            spacing: AppDimensions.sp6,
                            runSpacing: AppDimensions.sp4,
                            children: languages
                                .take(3)
                                .map((l) => Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: AppDimensions.sp8,
                                          vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.kOverlaySearchBar,
                                        borderRadius: BorderRadius.circular(
                                            AppDimensions.kRadiusPill),
                                        border: Border.all(
                                            color:
                                                AppColors.kOverlaySearchBorder),
                                      ),
                                      child: Text(l,
                                          style: t.bodySmall?.copyWith(
                                              color: AppColors
                                                  .kColorTextOnHeader)),
                                    ))
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Rating overview ─────────────────────────────────────────────────────────

class _RatingOverview extends StatelessWidget {
  final Map<String, dynamic> summary;
  final bool loading;

  const _RatingOverview({required this.summary, required this.loading});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppColors.kDarkTextMuted : AppColors.kColorTextMuted;

    if (loading && summary.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(AppDimensions.sp16),
        child: ShimmerSkeleton(
            width: double.infinity, height: 190, borderRadius: 20),
      );
    }

    final avg = (summary['rating_avg'] as num?)?.toDouble() ?? 0;
    final total = (summary['total'] as num?)?.toInt() ?? 0;
    final distribution =
        (summary['distribution'] as Map?)?.cast<String, dynamic>() ?? const {};
    final categories =
        (summary['categories'] as Map?)?.cast<String, dynamic>() ?? const {};

    return Container(
      margin: const EdgeInsets.fromLTRB(AppDimensions.sp16, AppDimensions.sp16,
          AppDimensions.sp16, AppDimensions.sp8),
      padding: const EdgeInsets.all(AppDimensions.sp16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppDimensions.kRadiusXl),
        border: Border.all(
            color:
                isDark ? AppColors.kDarkBorder : AppColors.kColorBorderSubtle),
        boxShadow: isDark ? null : AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(avg.toStringAsFixed(1),
                        style: t.displayMedium?.copyWith(
                            color: AppColors.kColorPrimary,
                            fontWeight: FontWeight.w700)),
                    _Stars(rating: avg, size: 14),
                    const SizedBox(height: AppDimensions.sp4),
                    Text(AppLocalizations.of(context)!.reviewCountLabel(total),
                        style: t.bodySmall?.copyWith(color: muted)),
                  ],
                ),
                const SizedBox(width: AppDimensions.sp16),
                VerticalDivider(
                  width: 1,
                  color: isDark
                      ? AppColors.kDarkBorder
                      : AppColors.kColorBorderSubtle,
                ),
                const SizedBox(width: AppDimensions.sp16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var star = 5; star >= 1; star--)
                        _DistributionBar(
                          star: star,
                          count: (distribution['$star'] as num?)?.toInt() ?? 0,
                          total: total,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (categories.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.sp16),
            Divider(
                height: 1,
                color: isDark
                    ? AppColors.kDarkBorder
                    : AppColors.kColorBorderFaint),
            const SizedBox(height: AppDimensions.sp12),
            // Only categories somebody actually scored — an unrated category is
            // absent, not shown as zero.
            ...reviewCategories
                .where((c) => categories[c.key] != null)
                .map((c) => _CategoryRow(
                      icon: c.icon,
                      label: c.label,
                      score: (categories[c.key] as num).toDouble(),
                    )),
          ],
        ],
      ),
    );
  }
}

class _DistributionBar extends StatelessWidget {
  final int star;
  final int count;
  final int total;

  const _DistributionBar(
      {required this.star, required this.count, required this.total});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppColors.kDarkTextMuted : AppColors.kColorTextMuted;
    final fraction = total == 0 ? 0.0 : count / total;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 10,
            child: Text('$star',
                textAlign: TextAlign.right,
                style: t.bodySmall?.copyWith(color: muted)),
          ),
          const SizedBox(width: AppDimensions.sp6),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppDimensions.kRadiusPill),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: fraction),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  minHeight: 6,
                  backgroundColor:
                      isDark ? AppColors.kDarkBgCard : AppColors.kColorBgMuted,
                  valueColor:
                      const AlwaysStoppedAnimation(AppColors.kColorAccentLight),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 26,
            child: Text('$count',
                textAlign: TextAlign.right,
                style: t.bodySmall?.copyWith(color: muted)),
          ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final double score;

  const _CategoryRow(
      {required this.icon, required this.label, required this.score});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.sp4),
      child: Row(
        children: [
          Icon(icon,
              size: AppDimensions.iconSm, color: AppColors.kColorAccentSafe),
          const SizedBox(width: AppDimensions.sp8),
          SizedBox(
            width: 110,
            child: Text(label,
                style: t.bodySmall?.copyWith(color: onSurface),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppDimensions.kRadiusPill),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: score / 5),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  minHeight: 5,
                  backgroundColor:
                      isDark ? AppColors.kDarkBgCard : AppColors.kColorBgMuted,
                  valueColor:
                      const AlwaysStoppedAnimation(AppColors.kColorPrimary),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.sp8),
          SizedBox(
            width: 24,
            child: Text(score.toStringAsFixed(1),
                textAlign: TextAlign.right,
                style: t.bodySmall
                    ?.copyWith(color: onSurface, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ── Review card ─────────────────────────────────────────────────────────────

class _ReviewCard extends StatefulWidget {
  final Map<String, dynamic> review;
  final bool canReply;
  final VoidCallback onReply;

  const _ReviewCard(
      {required this.review, required this.canReply, required this.onReply});

  @override
  State<_ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<_ReviewCard> {
  bool _expanded = false;

  /// Relative labels from l10n, absolute dates from intl — both follow the
  /// active locale instead of a hardcoded English month array.
  String _when(String? iso) {
    final dt = DateTime.tryParse('$iso')?.toLocal();
    if (dt == null) return '';
    final l10n = AppLocalizations.of(context)!;
    final days = DateTime.now().difference(dt).inDays;
    if (days < 1) return l10n.timeToday;
    if (days == 1) return l10n.timeYesterday;
    if (days < 7) return l10n.timeDaysAgo(days);
    return DateFormat('d MMM yyyy', Localizations.localeOf(context).toString())
        .format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.review;
    final t = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final muted = isDark ? AppColors.kDarkTextMuted : AppColors.kColorTextMuted;

    final name = (r['reviewer_name'] ?? '—').toString();
    final avatar = r['reviewer_avatar']?.toString();
    final rating = (r['review_rating'] as num?)?.toDouble() ?? 0;
    final text = (r['review_text'] ?? '').toString();
    final package = (r['package_label'] ?? '').toString();
    final group = (r['group_size'] as num?)?.toInt() ?? 1;
    final categories =
        (r['categories'] as Map?)?.cast<String, dynamic>() ?? const {};
    final reply = (r['guide_reply'] ?? '').toString();

    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final longText = text.length > 220;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.sp16),
      padding: const EdgeInsets.all(AppDimensions.sp16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppDimensions.kRadiusXl),
        border: Border.all(
            color:
                isDark ? AppColors.kDarkBorder : AppColors.kColorBorderSubtle),
        boxShadow: isDark ? null : AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipOval(
                child: SizedBox(
                  width: 42,
                  height: 42,
                  child: (avatar == null || avatar.isEmpty)
                      ? Container(
                          decoration: const BoxDecoration(
                              gradient: AppTheme.avatarGradient),
                          alignment: Alignment.center,
                          child: Text(initial,
                              style: t.titleMedium?.copyWith(
                                  color: AppColors.kColorTextOnPrimary)),
                        )
                      : AppNetworkImage(
                          url: avatar,
                          width: 42,
                          height: 42,
                          fit: BoxFit.cover,
                          cloudinaryWidth: 42,
                        ),
                ),
              ),
              const SizedBox(width: AppDimensions.sp12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: t.titleSmall?.copyWith(
                            color: onSurface, fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    // Every review here is tied to a completed booking — you
                    // cannot rate a guide you never toured with — so this badge
                    // states a fact rather than decorating one.
                    Row(
                      children: [
                        const Icon(Icons.verified_user_outlined,
                            size: 12, color: AppColors.kColorOfflineText),
                        const SizedBox(width: AppDimensions.sp4),
                        Text(l10n.verifiedBooking,
                            style: t.bodySmall?.copyWith(
                                color: AppColors.kColorOfflineText,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              ),
              Text(_when(r['reviewed_at']?.toString()),
                  style: t.bodySmall?.copyWith(color: muted)),
            ],
          ),
          const SizedBox(height: AppDimensions.sp10),
          Row(
            children: [
              _Stars(rating: rating, size: 15),
              if (package.isNotEmpty) ...[
                const SizedBox(width: AppDimensions.sp8),
                Flexible(
                  child: Text(
                    '· $package${group > 1 ? ' · ${l10n.peopleCount(group)}' : ''}',
                    style: t.bodySmall?.copyWith(color: muted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
          if (text.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.sp8),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              alignment: Alignment.topCenter,
              child: Text(
                text,
                maxLines: _expanded ? null : 6,
                overflow: _expanded ? null : TextOverflow.ellipsis,
                style: t.bodyMedium?.copyWith(color: onSurface, height: 1.45),
              ),
            ),
            if (longText)
              InteractiveSurface(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.only(top: AppDimensions.sp4),
                  child: Text(_expanded ? l10n.btnShowLess : l10n.btnReadMore,
                      style: t.bodySmall?.copyWith(
                          color: AppColors.kColorPrimary,
                          fontWeight: FontWeight.w700)),
                ),
              ),
          ],
          if (categories.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.sp10),
            Wrap(
              spacing: AppDimensions.sp6,
              runSpacing: AppDimensions.sp6,
              children: reviewCategories
                  .where((c) => categories[c.key] != null)
                  .map((c) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppDimensions.sp8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.kColorTagBg,
                          borderRadius:
                              BorderRadius.circular(AppDimensions.kRadiusPill),
                        ),
                        child: Text(
                          '${c.label} ${categories[c.key]}/5',
                          style: t.bodySmall?.copyWith(
                              color: AppColors.kColorAccentDark,
                              fontWeight: FontWeight.w600),
                        ),
                      ))
                  .toList(),
            ),
          ],
          if (reply.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.sp12),
            _GuideReply(
                text: reply, when: _when(r['guide_replied_at']?.toString())),
          ] else if (widget.canReply) ...[
            const SizedBox(height: AppDimensions.sp8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: widget.onReply,
                icon: const Icon(Icons.reply, size: AppDimensions.iconSm),
                label: Text(l10n.btnReply),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The guide's answer, nested under the review with a heritage-coloured spine.
class _GuideReply extends StatelessWidget {
  final String text;
  final String when;

  const _GuideReply({required this.text, required this.when});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final muted = isDark ? AppColors.kDarkTextMuted : AppColors.kColorTextMuted;

    return Container(
      padding: const EdgeInsets.all(AppDimensions.sp12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.kDarkBgCard : AppColors.kColorBgWarm,
        borderRadius: BorderRadius.circular(AppDimensions.kRadiusLg),
        border: Border(
          left: BorderSide(color: AppColors.kColorPrimary, width: 3),
          top: BorderSide(
              color:
                  isDark ? AppColors.kDarkBorder : AppColors.kColorBorderFaint),
          right: BorderSide(
              color:
                  isDark ? AppColors.kDarkBorder : AppColors.kColorBorderFaint),
          bottom: BorderSide(
              color:
                  isDark ? AppColors.kDarkBorder : AppColors.kColorBorderFaint),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.reply, size: 14, color: AppColors.kColorPrimary),
              const SizedBox(width: AppDimensions.sp6),
              Text(AppLocalizations.of(context)!.guideResponse,
                  style: t.bodySmall?.copyWith(
                      color: AppColors.kColorPrimary,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              if (when.isNotEmpty)
                Text(when, style: t.bodySmall?.copyWith(color: muted)),
            ],
          ),
          const SizedBox(height: AppDimensions.sp6),
          Text(text,
              style: t.bodyMedium?.copyWith(color: onSurface, height: 1.4)),
        ],
      ),
    );
  }
}

// ── Small pieces ────────────────────────────────────────────────────────────

/// Read-only stars, half-filled for fractional averages.
class _Stars extends StatelessWidget {
  final double rating;
  final double size;
  const _Stars({required this.rating, required this.size});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final IconData icon;
        if (rating >= i + 1) {
          icon = Icons.star_rounded;
        } else if (rating >= i + 0.5) {
          icon = Icons.star_half_rounded;
        } else {
          icon = Icons.star_outline_rounded;
        }
        return Icon(icon, size: size, color: AppColors.kColorAccentLight);
      }),
    );
  }
}

class _WriteReviewButton extends StatelessWidget {
  final VoidCallback onTap;
  const _WriteReviewButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.sp16),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.star_outline, size: AppDimensions.iconMd),
          label: Text(AppLocalizations.of(context)!.btnWriteReview),
          style: ElevatedButton.styleFrom(
            elevation: 4,
            shadowColor: AppColors.kShadowColor,
          ),
        ),
      ),
    );
  }
}

class _ReviewSkeleton extends StatelessWidget {
  const _ReviewSkeleton();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.sp16),
      padding: const EdgeInsets.all(AppDimensions.sp16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppDimensions.kRadiusXl),
        border: Border.all(
            color:
                isDark ? AppColors.kDarkBorder : AppColors.kColorBorderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              ShimmerSkeleton(width: 42, height: 42, borderRadius: 21),
              SizedBox(width: AppDimensions.sp12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerSkeleton(width: 120, height: 13, borderRadius: 4),
                  SizedBox(height: AppDimensions.sp6),
                  ShimmerSkeleton(width: 90, height: 10, borderRadius: 4),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.sp12),
          const ShimmerSkeleton(
              width: double.infinity, height: 11, borderRadius: 4),
          const SizedBox(height: AppDimensions.sp6),
          const ShimmerSkeleton(
              width: double.infinity, height: 11, borderRadius: 4),
          const SizedBox(height: AppDimensions.sp6),
          const ShimmerSkeleton(width: 180, height: 11, borderRadius: 4),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final bool filtered;
  final bool canWrite;
  final VoidCallback onWrite;

  const _EmptyView(
      {required this.filtered, required this.canWrite, required this.onWrite});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppColors.kDarkTextMuted : AppColors.kColorTextMuted;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.sp32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? AppColors.kDarkBgCard : AppColors.kColorBgWarm,
              ),
              child: Icon(
                  filtered
                      ? Icons.search_off_rounded
                      : Icons.rate_review_outlined,
                  size: 44,
                  color: isDark
                      ? AppColors.kColorAccentLight
                      : AppColors.kColorAccent),
            ),
            const SizedBox(height: AppDimensions.sp20),
            Text(filtered ? l10n.noMatchingReviews : l10n.noReviewsYet,
                textAlign: TextAlign.center,
                style: t.titleMedium
                    ?.copyWith(color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox(height: AppDimensions.sp8),
            Text(
              filtered ? l10n.tryDifferentSearch : l10n.beFirstToReview,
              textAlign: TextAlign.center,
              style: t.bodySmall?.copyWith(color: muted),
            ),
            if (!filtered && canWrite) ...[
              const SizedBox(height: AppDimensions.sp20),
              ElevatedButton.icon(
                onPressed: onWrite,
                icon:
                    const Icon(Icons.star_outline, size: AppDimensions.iconSm),
                label: Text(l10n.btnWriteReview),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppColors.kDarkTextMuted : AppColors.kColorTextMuted;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.sp32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.statusError.withValues(alpha: 0.10),
              ),
              child: const Icon(Icons.cloud_off_rounded,
                  size: 44, color: AppColors.statusError),
            ),
            const SizedBox(height: AppDimensions.sp20),
            Text(AppLocalizations.of(context)!.unableLoadReviews,
                style: t.titleMedium
                    ?.copyWith(color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox(height: AppDimensions.sp8),
            Text(AppLocalizations.of(context)!.checkConnection,
                textAlign: TextAlign.center,
                style: t.bodySmall?.copyWith(color: muted)),
            const SizedBox(height: AppDimensions.sp20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: AppDimensions.iconSm),
              label: Text(AppLocalizations.of(context)!.btnTryAgain),
            ),
          ],
        ),
      ),
    );
  }
}
