import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:sampada/presentation/widgets/common/interactive_surface.dart';
import 'package:provider/provider.dart';
import 'package:sampada/core/constants/app_colors.dart';
import 'package:sampada/core/constants/app_dimensions.dart';
import 'package:sampada/core/constants/app_strings.dart';
import 'package:sampada/core/theme/app_theme.dart';
import 'package:sampada/generated/app_localizations.dart';
import 'package:sampada/presentation/screens/bookings/booking_detail_screen.dart';
import 'package:sampada/presentation/screens/bookings/booking_widgets.dart';
import 'package:sampada/presentation/screens/guides/chat_screen.dart';
import 'package:sampada/presentation/widgets/common/sampada_app_bar.dart';
import 'package:sampada/providers/guide_provider.dart';

/// Which tab a booking belongs to. Derived from status, not stored:
/// pending + confirmed → Upcoming; completed → Completed; cancelled/rejected →
/// Cancelled.
enum BookingTab { upcoming, completed, cancelled }

extension BookingTabLabel on BookingTab {
  String label(AppLocalizations l10n) => switch (this) {
        BookingTab.upcoming => l10n.tabUpcoming,
        BookingTab.completed => l10n.tabCompleted,
        BookingTab.cancelled => l10n.tabCancelled,
      };
}

BookingTab bookingTabOf(Map<String, dynamic> b) => switch (b['status']) {
      'completed' => BookingTab.completed,
      'cancelled' || 'rejected' || 'refunded' => BookingTab.cancelled,
      _ => BookingTab.upcoming,
    };

enum BookingSort { newest, oldest, tourDate, priceHigh }

extension on BookingSort {
  String label(AppLocalizations l10n) => switch (this) {
        BookingSort.newest => l10n.sortNewest,
        BookingSort.oldest => l10n.sortOldest,
        BookingSort.tourDate => l10n.sortSoonestTour,
        BookingSort.priceHigh => l10n.sortHighestPrice,
      };
}

/// Date windows the tour date can be filtered to.
enum BookingWindow { any, next7, next30, past }

extension on BookingWindow {
  String label(AppLocalizations l10n) => switch (this) {
        BookingWindow.any => l10n.windowAnyDate,
        BookingWindow.next7 => l10n.windowNext7,
        BookingWindow.next30 => l10n.windowNext30,
        BookingWindow.past => l10n.windowPast,
      };
}

/// Everything the filter sheet can narrow by. Province/district are absent on
/// purpose: bookings are not linked to a heritage site server-side, so there is
/// no location to filter on (see the note in the screen doc below).
class BookingFilters {
  final Set<String> statuses;
  final Set<String> payments;
  final Set<String> packages;
  final BookingWindow window;
  final BookingSort sort;

  const BookingFilters({
    this.statuses = const {},
    this.payments = const {},
    this.packages = const {},
    this.window = BookingWindow.any,
    this.sort = BookingSort.newest,
  });

  /// Sort alone is not "filtering" — the badge only lights up for real narrowing.
  bool get isNarrowing =>
      statuses.isNotEmpty ||
      payments.isNotEmpty ||
      packages.isNotEmpty ||
      window != BookingWindow.any;

  bool get isDefault => !isNarrowing && sort == BookingSort.newest;

  BookingFilters copyWith({
    Set<String>? statuses,
    Set<String>? payments,
    Set<String>? packages,
    BookingWindow? window,
    BookingSort? sort,
  }) =>
      BookingFilters(
        statuses: statuses ?? this.statuses,
        payments: payments ?? this.payments,
        packages: packages ?? this.packages,
        window: window ?? this.window,
        sort: sort ?? this.sort,
      );

  bool matches(Map<String, dynamic> b) {
    final status = '${b['status']}';
    final payment = '${b['payment_status'] ?? 'none'}';
    if (statuses.isNotEmpty && !statuses.contains(status)) return false;
    if (payments.isNotEmpty && !payments.contains(payment)) return false;
    if (packages.isNotEmpty && !packages.contains(bookingPackageLabel(b))) {
      return false;
    }
    if (window != BookingWindow.any) {
      final days = bookingDaysUntil(b);
      if (days == null) return false;
      final ok = switch (window) {
        BookingWindow.next7 => days >= 0 && days <= 7,
        BookingWindow.next30 => days >= 0 && days <= 30,
        BookingWindow.past => days < 0,
        BookingWindow.any => true,
      };
      if (!ok) return false;
    }
    return true;
  }
}

/// The tourist's bookings: three tabs, search, filter + sort, and a card per
/// booking with its quick actions. Reads [GuideProvider] — the guides list is
/// fetched alongside so cards can show the guide's rating, verified badge and
/// languages, none of which the booking payload carries.
///
/// Not rendered here because the backend has no such data: heritage-site image /
/// name / UNESCO badge / province / district (a booking is not linked to a site),
/// and meeting point.
class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  BookingTab _tab = BookingTab.upcoming;
  BookingFilters _filters = const BookingFilters();
  bool _loading = true;
  bool _searching = false;
  bool _offline = false;
  String _query = '';

  final _searchController = TextEditingController();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    _watchConnectivity();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _connectivitySub?.cancel();
    super.dispose();
  }

  void _watchConnectivity() {
    Connectivity().checkConnectivity().then(_applyConnectivity);
    _connectivitySub =
        Connectivity().onConnectivityChanged.listen(_applyConnectivity);
  }

  void _applyConnectivity(List<ConnectivityResult> result) {
    final offline =
        result.isEmpty || result.every((r) => r == ConnectivityResult.none);
    if (mounted && offline != _offline) setState(() => _offline = offline);
  }

  Future<void> _load() async {
    final gp = context.read<GuideProvider>();
    // Guides enrich the cards (rating, verified badge, languages) and the detail
    // screen's price breakdown. Fired in parallel — never blocks the bookings.
    if (gp.guides.isEmpty) gp.fetchGuides();
    await gp.fetchMyBookings();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _retry() async {
    setState(() => _loading = true);
    await _load();
  }

  bool _matchesQuery(Map<String, dynamic> b) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return '${b['guide_name']}'.toLowerCase().contains(q) ||
        bookingRef(b).toLowerCase().contains(q) ||
        '${b['id']}' == q ||
        '${b['date']}'.contains(q) ||
        bookingPackageLabel(b).toLowerCase().contains(q);
  }

  List<Map<String, dynamic>> _visible(List<Map<String, dynamic>> all) {
    final list = all
        .where((b) =>
            bookingTabOf(b) == _tab && _matchesQuery(b) && _filters.matches(b))
        .toList();

    int byDate(Map<String, dynamic> a, Map<String, dynamic> b,
        {bool asc = true}) {
      final r = '${a['created_at'] ?? a['date']}'
          .compareTo('${b['created_at'] ?? b['date']}');
      return asc ? r : -r;
    }

    switch (_filters.sort) {
      case BookingSort.newest:
        list.sort((a, b) => byDate(a, b, asc: false));
      case BookingSort.oldest:
        list.sort((a, b) => byDate(a, b, asc: true));
      case BookingSort.tourDate:
        list.sort((a, b) => '${a['date']}'.compareTo('${b['date']}'));
      case BookingSort.priceHigh:
        list.sort((a, b) => (asDoubleOrNull(b['total_price']) ?? -1)
            .compareTo(asDoubleOrNull(a['total_price']) ?? -1));
    }
    return list;
  }

  Map<String, dynamic>? _guideOf(GuideProvider gp, Map<String, dynamic> b) {
    for (final g in gp.guides) {
      if (g['id'] == b['guide']) return g;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _appBar(context),
      body: Consumer<GuideProvider>(
        builder: (context, gp, _) {
          final bookings = gp.myBookings;
          final counts = <BookingTab, int>{
            for (final t in BookingTab.values)
              t: bookings.where((b) => bookingTabOf(b) == t).length,
          };
          final visible = _visible(bookings);

          return Column(
            children: [
              if (_offline)
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppDimensions.sp16,
                      AppDimensions.sp12, AppDimensions.sp16, 0),
                  child: _OfflineBanner(syncedAt: gp.bookingsSyncedAt),
                ),
              _TabBar(
                active: _tab,
                counts: counts,
                onChanged: (t) => setState(() => _tab = t),
              ),
              Expanded(child: _body(context, gp, bookings, visible)),
            ],
          );
        },
      ),
    );
  }

  PreferredSizeWidget _appBar(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;
    const onHeader = AppColors.kColorTextOnHeader;
    return SampadaAppBar(
      title: _searching
          ? TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: (q) => setState(() => _query = q),
              cursorColor: onHeader,
              style: t.bodyLarge?.copyWith(color: onHeader),
              decoration: InputDecoration(
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: l10n.searchBookingsHint,
                hintStyle: t.bodyMedium
                    ?.copyWith(color: onHeader.withValues(alpha: 0.7)),
              ),
            )
          : Text(l10n.myBookingsTitle),
      actions: [
        IconButton(
          tooltip:
              _searching ? l10n.tooltipCloseSearch : l10n.tooltipSearchBookings,
          icon: Icon(_searching ? Icons.close : Icons.search, color: onHeader),
          onPressed: () => setState(() {
            _searching = !_searching;
            if (!_searching) {
              _query = '';
              _searchController.clear();
            }
          }),
        ),
        if (!_searching) ...[
          IconButton(
            tooltip: l10n.tooltipFilterSort,
            icon: Badge(
              isLabelVisible: !_filters.isDefault,
              backgroundColor: AppColors.kColorAccentLight,
              smallSize: 8,
              child: const Icon(Icons.tune, color: onHeader),
            ),
            onPressed: _openFilterSheet,
          ),
          IconButton(
            tooltip: l10n.navNotifications,
            icon: const Icon(Icons.notifications_none, color: onHeader),
            onPressed: () =>
                Navigator.pushNamed(context, AppStrings.notificationsPath),
          ),
        ],
      ],
    );
  }

  Widget _body(
    BuildContext context,
    GuideProvider gp,
    List<Map<String, dynamic>> all,
    List<Map<String, dynamic>> visible,
  ) {
    // Loading (first paint, nothing cached yet) → skeletons.
    if (_loading && all.isEmpty) {
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(AppDimensions.sp16,
            AppDimensions.sp8, AppDimensions.sp16, AppDimensions.sp24),
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(height: AppDimensions.sp14),
        itemBuilder: (_, __) => const BookingCardSkeleton(),
      );
    }

    // Failed and nothing cached to fall back on → retry. With a cached list we
    // keep showing it (offline-first) and only surface the offline banner.
    if (gp.bookingsError != null && all.isEmpty) {
      final l10n = AppLocalizations.of(context)!;
      return BookingErrorView(
        message:
            _offline ? l10n.offlineReconnect : l10n.somethingWentWrongServer,
        onRetry: _retry,
      );
    }

    return RefreshIndicator(
      color: AppColors.kColorPrimary,
      onRefresh: gp.fetchMyBookings,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.02), end: Offset.zero)
                .animate(anim),
            child: child,
          ),
        ),
        child: visible.isEmpty
            ? ListView(
                key: ValueKey('empty-${_tab.name}'),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.55,
                    child: _emptyFor(context),
                  ),
                ],
              )
            : ListView.separated(
                key: ValueKey('list-${_tab.name}-${visible.length}'),
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(AppDimensions.sp16,
                    AppDimensions.sp8, AppDimensions.sp16, AppDimensions.sp24),
                itemCount: visible.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppDimensions.sp14),
                itemBuilder: (context, i) {
                  final booking = visible[i];
                  return BookingFadeIn(
                    index: i,
                    child: BookingCard(
                      booking: booking,
                      guide: _guideOf(gp, booking),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _emptyFor(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final narrowed = _query.isNotEmpty || _filters.isNarrowing;
    if (narrowed) {
      return BookingEmptyView(
        icon: Icons.search_off_rounded,
        title: l10n.nothingMatchesTitle,
        message: l10n.nothingMatchesBody,
        actionLabel: l10n.clearFilters,
        actionIcon: Icons.filter_alt_off_outlined,
        onAction: () => setState(() {
          _filters = const BookingFilters();
          _query = '';
          _searchController.clear();
        }),
      );
    }
    return switch (_tab) {
      BookingTab.upcoming => BookingEmptyView(
          icon: Icons.temple_hindu_outlined,
          title: l10n.noBookingsYetTitle,
          message: l10n.noBookingsYetBody,
          actionLabel: l10n.exploreHeritageSites,
          actionIcon: Icons.explore_outlined,
          onAction: () => Navigator.pushNamed(context, AppStrings.searchPath),
        ),
      BookingTab.completed => BookingEmptyView(
          icon: Icons.check_circle_outline,
          title: l10n.noCompletedToursTitle,
          message: l10n.noCompletedToursBody,
        ),
      BookingTab.cancelled => BookingEmptyView(
          icon: Icons.event_busy_outlined,
          title: l10n.noCancelledTitle,
          message: l10n.noCancelledBody,
        ),
    };
  }

  // ── Filter & sort ─────────────────────────────────────────────────────────

  Future<void> _openFilterSheet() async {
    final packages = context
        .read<GuideProvider>()
        .myBookings
        .map(bookingPackageLabel)
        .where((l) => l.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    final result = await showModalBottomSheet<BookingFilters>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppDimensions.kRadiusXxl)),
      ),
      builder: (_) => _FilterSheet(
        initial: _filters,
        availablePackages: packages,
      ),
    );
    if (result != null && mounted) setState(() => _filters = result);
  }
}

// ── Offline banner ───────────────────────────────────────────────────────────

class _OfflineBanner extends StatelessWidget {
  final DateTime? syncedAt;
  const _OfflineBanner({this.syncedAt});

  String? _lastSync(AppLocalizations l10n) {
    if (syncedAt == null) return null;
    final mins = DateTime.now().difference(syncedAt!).inMinutes;
    if (mins < 1) return l10n.lastSyncedJustNow;
    if (mins < 60) return l10n.lastSyncedMinutes(mins);
    final hours = mins ~/ 60;
    if (hours < 24) return l10n.lastSyncedHours(hours);
    return l10n.lastSyncedDays(hours ~/ 24);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BookingBanner(
      icon: Icons.cloud_off_rounded,
      title: l10n.offlineShowingSaved,
      message: _lastSync(l10n),
      bg: AppColors.kColorBgMuted,
      fg: AppColors.kColorTextSecondary,
    );
  }
}

// ── Tabs ─────────────────────────────────────────────────────────────────────

class _TabBar extends StatelessWidget {
  final BookingTab active;
  final Map<BookingTab, int> counts;
  final ValueChanged<BookingTab> onChanged;

  const _TabBar(
      {required this.active, required this.counts, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.fromLTRB(AppDimensions.sp16, AppDimensions.sp12,
          AppDimensions.sp16, AppDimensions.sp12),
      padding: const EdgeInsets.all(AppDimensions.sp4),
      decoration: BoxDecoration(
        color: dark ? AppColors.kDarkBgCard : AppColors.kColorBgWarm,
        borderRadius: BorderRadius.circular(AppDimensions.kRadiusLg),
      ),
      child: Row(
        children: BookingTab.values.map((tab) {
          final selected = tab == active;
          final count = counts[tab] ?? 0;
          return Expanded(
            child: Semantics(
              button: true,
              selected: selected,
              label: l10n.semanticsTabBookings(tab.label(l10n), count),
              child: InteractiveSurface(
                onTap: () => onChanged(tab),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(
                      vertical: AppDimensions.sp10,
                      horizontal: AppDimensions.sp6),
                  decoration: BoxDecoration(
                    gradient: selected ? AppTheme.avatarGradient : null,
                    borderRadius:
                        BorderRadius.circular(AppDimensions.kRadiusMd),
                    boxShadow: selected ? AppTheme.elevatedShadow : null,
                  ),
                  alignment: Alignment.center,
                  // The three tabs are equal thirds but their labels are not
                  // equal lengths ("Cancelled (1)" is far wider than
                  // "Upcoming (0)"), so scale down rather than clip on narrow
                  // screens or at large text scales.
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${tab.label(l10n)} ($count)',
                      maxLines: 1,
                      softWrap: false,
                      style: t.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? AppColors.kColorTextOnPrimary
                            : bookingSecondary(context),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Booking card ─────────────────────────────────────────────────────────────

/// One booking: guide identity, tour meta, chips, and the actions that are legal
/// in its current state. Tapping anywhere opens the detail screen (Hero on the
/// avatar).
class BookingCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  final Map<String, dynamic>? guide;

  const BookingCard({super.key, required this.booking, this.guide});

  void _openDetail(BuildContext context) => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BookingDetailScreen(
            bookingId: booking['id'] as int,
            initial: booking,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final rating = asDoubleOrNull(guide?['rating_avg']);
    final verified = guide?['is_verified'] == true;
    final languages =
        (guide?['languages'] as List?)?.whereType<String>().toList() ??
            const [];
    final price = asDoubleOrNull(booking['total_price']);
    final group = bookingGroupSize(booking);

    return BookingCardShell(
      onTap: () => _openDetail(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Guide identity
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BookingGuideAvatar(
                booking: booking,
                verified: verified,
                heroTag: 'booking-avatar-${booking['id']}',
              ),
              const SizedBox(width: AppDimensions.sp12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (booking['guide_name'] ?? l10n.tourGuide).toString(),
                      style: t.titleSmall?.copyWith(
                          color: onSurface, fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppDimensions.sp2),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            verified ? l10n.licensedTourGuide : l10n.tourGuide,
                            style: t.bodySmall
                                ?.copyWith(color: bookingMuted(context)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (rating != null) ...[
                          const SizedBox(width: AppDimensions.sp6),
                          const Icon(Icons.star_rounded,
                              size: 14, color: AppColors.kColorAccentLight),
                          Text(
                            rating.toStringAsFixed(1),
                            style: t.bodySmall?.copyWith(
                                color: onSurface, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ],
                    ),
                    if (languages.isNotEmpty)
                      Text(
                        languages.take(3).join(' · '),
                        style:
                            t.bodySmall?.copyWith(color: bookingMuted(context)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              Text(
                bookingRef(booking),
                style: t.bodySmall?.copyWith(
                    color: bookingMuted(context), fontWeight: FontWeight.w600),
              ),
            ],
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppDimensions.sp12),
            child: Divider(height: 1),
          ),

          // Tour meta
          Wrap(
            spacing: AppDimensions.sp14,
            runSpacing: AppDimensions.sp6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _Meta(
                  icon: Icons.event_outlined,
                  text: formatBookingDate(booking['date']) ??
                      '${booking['date'] ?? ''}'),
              _Meta(icon: Icons.schedule, text: bookingTimeRange(booking)),
              if (group > 1)
                _Meta(
                    icon: Icons.groups_outlined,
                    text: l10n.touristsCount(group)),
            ],
          ),
          if (bookingPackageLabel(booking).isNotEmpty || price != null) ...[
            const SizedBox(height: AppDimensions.sp8),
            Row(
              children: [
                if (bookingPackageLabel(booking).isNotEmpty)
                  Expanded(
                    child: _Meta(
                        icon: Icons.tour_outlined,
                        text: bookingPackageLabel(booking)),
                  )
                else
                  const Spacer(),
                if (price != null)
                  Text(
                    l10n.nprAmount(money(price)),
                    style: t.titleSmall?.copyWith(
                        color: onSurface, fontWeight: FontWeight.w700),
                  ),
              ],
            ),
          ],

          const SizedBox(height: AppDimensions.sp12),
          BookingChipRow(booking: booking),

          // Quick actions — only the ones legal in this state.
          _QuickActions(
            booking: booking,
            onDetails: () => _openDetail(context),
          ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Meta({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon,
            size: AppDimensions.iconSm, color: AppColors.kColorAccentSafe),
        const SizedBox(width: AppDimensions.sp6),
        Flexible(
          child: Text(
            text,
            style: t.bodyMedium
                ?.copyWith(color: Theme.of(context).colorScheme.onSurface),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _QuickActions extends StatelessWidget {
  final Map<String, dynamic> booking;
  final VoidCallback onDetails;
  const _QuickActions({required this.booking, required this.onDetails});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final actions = <Widget>[];

    if (BookingActions.paymentDue(booking)) {
      actions.add(_FilledAction(
        icon: Icons.payments_outlined,
        label: booking['payment_status'] == 'rejected'
            ? l10n.payAgain
            : l10n.btnPayNow,
        onTap: () => BookingActions.openPayment(context, booking),
      ));
    }
    // A submitted payment is waiting on the guide. Offering a second "Pay Now"
    // here is how a tourist pays twice, so this is a way in, not a call to act.
    if (BookingActions.paymentAwaitingGuide(booking)) {
      actions.add(_FilledAction(
        icon: Icons.hourglass_top,
        label: l10n.paymentSent,
        color: AppColors.statusInfo,
        onTap: () => BookingActions.openPayment(context, booking),
      ));
    }
    if (BookingActions.awaitingConfirm(booking)) {
      actions.add(_FilledAction(
        icon: Icons.task_alt,
        label: l10n.confirmDone,
        color: AppColors.statusSuccess,
        onTap: () => BookingActions.completeTour(context, booking),
      ));
    }
    if (BookingActions.canReview(booking)) {
      actions.add(_FilledAction(
        icon: Icons.star_outline,
        label: l10n.rateGuide,
        onTap: () => BookingActions.openReviewDialog(context, booking),
      ));
    }
    if (BookingActions.canChat(booking)) {
      actions.add(_OutlineAction(
        icon: Icons.chat_bubble_outline,
        label: l10n.btnMessage,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              bookingId: booking['id'] as int,
              otherPartyName:
                  (booking['guide_name'] ?? l10n.tourGuide).toString(),
            ),
          ),
        ),
      ));
    }
    actions.add(_OutlineAction(
      icon: Icons.receipt_long_outlined,
      label: l10n.btnDetails,
      onTap: onDetails,
    ));
    if (BookingActions.canCancel(booking)) {
      actions.add(_OutlineAction(
        icon: Icons.close,
        label: l10n.btnCancel,
        color: AppColors.statusError,
        onTap: () => BookingActions.confirmCancel(context, booking),
      ));
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppDimensions.sp12),
      child: Wrap(
        spacing: AppDimensions.sp8,
        runSpacing: AppDimensions.sp8,
        children: actions,
      ),
    );
  }
}

class _FilledAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  const _FilledAction(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.color});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: AppDimensions.iconSm),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.sp14, vertical: AppDimensions.sp8),
        minimumSize: const Size(0, 40), // keeps the tap target accessible
      ),
    );
  }
}

class _OutlineAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  const _OutlineAction(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.color});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: AppDimensions.iconSm),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: color == null ? null : BorderSide(color: color!),
        padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.sp14, vertical: AppDimensions.sp8),
        minimumSize: const Size(0, 40),
      ),
    );
  }
}

// ── Filter & sort sheet ──────────────────────────────────────────────────────

class _FilterSheet extends StatefulWidget {
  final BookingFilters initial;
  final List<String> availablePackages;

  const _FilterSheet({required this.initial, required this.availablePackages});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late BookingFilters _draft = widget.initial;

  Set<String> _toggle(Set<String> set, String value) {
    final next = {...set};
    next.contains(value) ? next.remove(value) : next.add(value);
    return next;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    final statusOptions = {
      'pending': l10n.statusPending,
      'confirmed': l10n.statusConfirmed,
      'completed': l10n.tabCompleted,
      'cancelled': l10n.tabCancelled,
    };

    final paymentOptions = {
      'none': l10n.payNothingOwed,
      'due': l10n.payDueTitle,
      'paid': l10n.payPaid,
    };

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppDimensions.sp20,
            AppDimensions.sp16, AppDimensions.sp20, AppDimensions.sp20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppDimensions.sp16),
                  decoration: BoxDecoration(
                    color: bookingBorder(context),
                    borderRadius:
                        BorderRadius.circular(AppDimensions.kRadiusPill),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(l10n.filterSortTitle,
                        style: t.titleMedium?.copyWith(color: onSurface)),
                  ),
                  TextButton(
                    onPressed: () =>
                        setState(() => _draft = const BookingFilters()),
                    child: Text(l10n.btnReset),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.sp8),
              _group(context, l10n.groupStatus),
              Wrap(
                spacing: AppDimensions.sp8,
                runSpacing: AppDimensions.sp8,
                children: statusOptions.entries
                    .map((e) => _choice(
                          label: e.value,
                          selected: _draft.statuses.contains(e.key),
                          onTap: () => setState(() => _draft = _draft.copyWith(
                              statuses: _toggle(_draft.statuses, e.key))),
                        ))
                    .toList(),
              ),
              _group(context, l10n.groupPayment),
              Wrap(
                spacing: AppDimensions.sp8,
                runSpacing: AppDimensions.sp8,
                children: paymentOptions.entries
                    .map((e) => _choice(
                          label: e.value,
                          selected: _draft.payments.contains(e.key),
                          onTap: () => setState(() => _draft = _draft.copyWith(
                              payments: _toggle(_draft.payments, e.key))),
                        ))
                    .toList(),
              ),
              if (widget.availablePackages.isNotEmpty) ...[
                _group(context, l10n.groupPackage),
                Wrap(
                  spacing: AppDimensions.sp8,
                  runSpacing: AppDimensions.sp8,
                  children: widget.availablePackages
                      .map((p) => _choice(
                            label: p,
                            selected: _draft.packages.contains(p),
                            onTap: () => setState(() => _draft =
                                _draft.copyWith(
                                    packages: _toggle(_draft.packages, p))),
                          ))
                      .toList(),
                ),
              ],
              _group(context, l10n.groupTourDate),
              Wrap(
                spacing: AppDimensions.sp8,
                runSpacing: AppDimensions.sp8,
                children: BookingWindow.values
                    .map((w) => _choice(
                          label: w.label(l10n),
                          selected: _draft.window == w,
                          onTap: () => setState(
                              () => _draft = _draft.copyWith(window: w)),
                        ))
                    .toList(),
              ),
              _group(context, l10n.groupSortBy),
              Wrap(
                spacing: AppDimensions.sp8,
                runSpacing: AppDimensions.sp8,
                children: BookingSort.values
                    .map((s) => _choice(
                          label: s.label(l10n),
                          selected: _draft.sort == s,
                          onTap: () =>
                              setState(() => _draft = _draft.copyWith(sort: s)),
                        ))
                    .toList(),
              ),
              const SizedBox(height: AppDimensions.sp24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, _draft),
                  child: Text(l10n.btnApply),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _group(BuildContext context, String label) => Padding(
        padding: const EdgeInsets.fromLTRB(
            0, AppDimensions.sp16, 0, AppDimensions.sp10),
        child: Text(label.toUpperCase(),
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: bookingMuted(context))),
      );

  Widget _choice({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) =>
      FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        selectedColor: AppColors.kColorPrimary,
        labelStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: selected
                  ? AppColors.kColorTextOnPrimary
                  : bookingSecondary(context),
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
        side: BorderSide(
            color: selected ? AppColors.kColorPrimary : bookingBorder(context)),
      );
}
