import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sampada/core/constants/app_colors.dart';
import 'package:sampada/core/constants/app_dimensions.dart';
import 'package:sampada/core/constants/app_strings.dart';
import 'package:sampada/core/theme/app_theme.dart';
import 'package:sampada/presentation/screens/bookings/booking_detail_screen.dart';
import 'package:sampada/presentation/widgets/common/app_network_image.dart';
import 'package:sampada/presentation/widgets/shared/shimmer_loading.dart';
import 'package:sampada/providers/guide_provider.dart';

/// Which tab a booking belongs to. Derived from status, not stored:
/// pending + confirmed → Upcoming; completed → Completed; cancelled → Cancelled.
enum BookingTab { upcoming, completed, cancelled }

extension BookingTabLabel on BookingTab {
  String get label => switch (this) {
        BookingTab.upcoming => 'Upcoming',
        BookingTab.completed => 'Completed',
        BookingTab.cancelled => 'Cancelled',
      };
}

BookingTab bookingTabOf(Map<String, dynamic> b) => switch (b['status']) {
      'completed' => BookingTab.completed,
      'cancelled' => BookingTab.cancelled,
      _ => BookingTab.upcoming,
    };

/// Booking-status chip colors/icon/label — shared by the list card and the
/// detail screen so a status always renders identically.
({Color bg, Color fg, IconData icon, String label}) bookingStatusMeta(String status) =>
    switch (status) {
      'confirmed' => (
          bg: const Color(0xFFDCEFE0),
          fg: const Color(0xFF1F6B3B),
          icon: Icons.verified_outlined,
          label: 'Confirmed'
        ),
      'completed' => (
          bg: const Color(0xFFE1EAF5),
          fg: const Color(0xFF1E4E79),
          icon: Icons.check_circle_outline,
          label: 'Completed'
        ),
      'cancelled' => (
          bg: const Color(0xFFF6DEDC),
          fg: const Color(0xFFA3271F),
          icon: Icons.cancel_outlined,
          label: 'Cancelled'
        ),
      _ => (
          bg: const Color(0xFFFBEBC8),
          fg: const Color(0xFF8A5A00),
          icon: Icons.hourglass_top,
          label: 'Pending'
        ),
    };

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  BookingTab _tab = BookingTab.upcoming;
  bool _loading = true;
  bool _searching = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final gp = context.read<GuideProvider>();
    // Guides list enriches booking cards (rating, verified badge, languages);
    // fetched in parallel, non-blocking for the bookings themselves.
    if (gp.guides.isEmpty) gp.fetchGuides();
    await gp.fetchMyBookings();
    if (mounted) setState(() => _loading = false);
  }

  bool _matchesQuery(Map<String, dynamic> b) {
    if (_query.trim().isEmpty) return true;
    final q = _query.trim().toLowerCase();
    return '${b['guide_name']}'.toLowerCase().contains(q) ||
        '${b['date']}'.contains(q) ||
        '${b['id']}' == q;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: Colors.white,
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(
            gradient: AppTheme.navGradient,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(AppDimensions.kRadiusXxl),
              bottomRight: Radius.circular(AppDimensions.kRadiusXxl),
            ),
          ),
        ),
        title: _searching
            ? TextField(
                autofocus: true,
                onChanged: (q) => setState(() => _query = q),
                cursorColor: Colors.white,
                style: const TextStyle(fontSize: 15, color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Guide, date or booking #…',
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                ),
              )
            : const Text(
                'My Bookings',
                style: TextStyle(
                  fontFamily: 'serif',
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search, color: Colors.white),
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) _query = '';
            }),
          ),
          if (!_searching)
            IconButton(
              icon: const Icon(Icons.notifications_none, color: Colors.white),
              onPressed: () =>
                  Navigator.pushNamed(context, AppStrings.notificationsPath),
            ),
        ],
      ),
      body: Consumer<GuideProvider>(
        builder: (context, gp, _) {
          final bookings = gp.myBookings;
          final counts = <BookingTab, int>{
            for (final t in BookingTab.values)
              t: bookings.where((b) => bookingTabOf(b) == t).length,
          };
          final visible = bookings
              .where((b) => bookingTabOf(b) == _tab && _matchesQuery(b))
              .toList()
            ..sort((a, b) => '${b['date']}'.compareTo('${a['date']}'));

          return Column(
            children: [
              _TabBar(
                active: _tab,
                counts: counts,
                onChanged: (t) => setState(() => _tab = t),
              ),
              Expanded(
                child: _loading && bookings.isEmpty
                    ? _skeletonList()
                    : RefreshIndicator(
                        color: AppColors.kColorPrimary,
                        onRefresh: gp.fetchMyBookings,
                        child: visible.isEmpty
                            ? ListView(
                                children: [
                                  SizedBox(
                                    height:
                                        MediaQuery.of(context).size.height * 0.55,
                                    child: _EmptyView(
                                        tab: _tab, filtered: _query.isNotEmpty),
                                  ),
                                ],
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                                itemCount: visible.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 14),
                                itemBuilder: (context, i) => _FadeSlideIn(
                                  index: i,
                                  child: _BookingCard(
                                    booking: visible[i],
                                    guide: _guideOf(gp, visible[i]),
                                  ),
                                ),
                              ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Map<String, dynamic>? _guideOf(GuideProvider gp, Map<String, dynamic> b) {
    for (final g in gp.guides) {
      if (g['id'] == b['guide']) return g;
    }
    return null;
  }

  Widget _skeletonList() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: 3,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (_, __) => const ShimmerSkeleton(
          width: double.infinity, height: 190, borderRadius: 20),
    );
  }
}

class _FadeSlideIn extends StatelessWidget {
  final int index;
  final Widget child;
  const _FadeSlideIn({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 250 + (index.clamp(0, 8) * 60)),
      curve: Curves.easeOut,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child:
            Transform.translate(offset: Offset(0, (1 - value) * 16), child: child),
      ),
      child: child,
    );
  }
}

class _TabBar extends StatelessWidget {
  final BookingTab active;
  final Map<BookingTab, int> counts;
  final ValueChanged<BookingTab> onChanged;
  const _TabBar(
      {required this.active, required this.counts, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBgCard : AppColors.kColorBgWarm,
        borderRadius: BorderRadius.circular(AppDimensions.kRadiusLg),
      ),
      child: Row(
        children: BookingTab.values.map((tab) {
          final selected = tab == active;
          final count = counts[tab] ?? 0;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(tab),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  gradient: selected
                      ? const LinearGradient(
                          colors: [AppColors.kColorDeep, AppColors.kColorPrimary])
                      : null,
                  borderRadius: BorderRadius.circular(AppDimensions.kRadiusMd),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: AppColors.kColorDeep.withValues(alpha: 0.28),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  count > 0 ? '${tab.label} ($count)' : tab.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? Colors.white
                        : (isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.kColorTextSecondary),
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

class _EmptyView extends StatelessWidget {
  final BookingTab tab;
  final bool filtered;
  const _EmptyView({required this.tab, required this.filtered});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final message = filtered
        ? 'No bookings match your search.'
        : switch (tab) {
            BookingTab.upcoming => 'No bookings yet',
            BookingTab.completed => 'No completed tours yet.',
            BookingTab.cancelled => 'No cancelled bookings.',
          };
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_note_outlined,
              size: 64,
              color: isDark ? AppColors.darkTextSecondary : const Color(0xFFB08060)),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: isDark ? AppColors.darkTextSecondary : const Color(0xFF8C7162),
            ),
          ),
          if (!filtered && tab == BookingTab.upcoming) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () =>
                  Navigator.pushNamed(context, AppStrings.guidePath),
              icon: const Icon(Icons.tour_outlined, size: 18),
              label: const Text('Find a Guide'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.kColorPrimary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  final Map<String, dynamic>? guide;
  const _BookingCard({required this.booking, this.guide});

  String get _guideName => (booking['guide_name'] ?? 'Guide').toString();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = (booking['status'] ?? 'pending').toString();
    final s = bookingStatusMeta(status);
    final rating = asDoubleOrNull(guide?['rating_avg']);
    final verified = guide?['is_verified'] == true;

    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(AppDimensions.kRadiusXxl),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimensions.kRadiusXxl),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                BookingDetailScreen(bookingId: booking['id'] as int, initial: booking),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimensions.kRadiusXxl),
            border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.kColorBorderSubtle),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3C1E14).withValues(alpha: isDark ? 0 : 0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  BookingGuideAvatar(
                    booking: booking,
                    verified: verified,
                    heroTag: 'booking-avatar-${booking['id']}',
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_guideName,
                            style: TextStyle(
                              fontFamily: 'serif',
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.onSurface,
                            )),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(verified ? 'Licensed Tour Guide' : 'Tour Guide',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.kColorTextMuted,
                                )),
                            if (rating != null) ...[
                              const SizedBox(width: 8),
                              const Icon(Icons.star_rounded,
                                  size: 14, color: AppColors.kColorAccentLight),
                              Text(rating.toStringAsFixed(1),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  )),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right,
                      color:
                          isDark ? AppColors.darkTextSecondary : AppColors.kColorTextMuted),
                ],
              ),
              const SizedBox(height: 12),
              Divider(
                  height: 1,
                  color: isDark ? AppColors.darkBorder : AppColors.kColorBorderFaint),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.event_outlined,
                      size: 16, color: AppColors.kColorAccentSafe),
                  const SizedBox(width: 6),
                  Text('${booking['date'] ?? ''}',
                      style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurface)),
                  const SizedBox(width: 14),
                  const Icon(Icons.schedule,
                      size: 16, color: AppColors.kColorAccentSafe),
                  const SizedBox(width: 6),
                  Text(bookingTimeRange(booking),
                      style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurface)),
                  const Spacer(),
                  if (booking['total_price'] != null)
                    Text('NPR ${booking['total_price']}',
                        style: TextStyle(
                          fontFamily: 'serif',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
                        )),
                ],
              ),
              if (bookingPackageLine(booking) != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.tour_outlined,
                        size: 16, color: AppColors.kColorAccentSafe),
                    const SizedBox(width: 6),
                    Text(bookingPackageLine(booking)!,
                        style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.onSurface)),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  BookingChip(bg: s.bg, fg: s.fg, icon: s.icon, label: s.label),
                  BookingPaymentChip(booking: booking),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shared bits (also used by the detail screen) ────────────────────────────

/// DRF renders DecimalFields (e.g. `rating_avg`) as JSON strings — parse
/// numbers tolerantly instead of casting, so "4.9", 4.9 and null all work.
double? asDoubleOrNull(dynamic v) =>
    v is num ? v.toDouble() : double.tryParse('$v');

int? asIntOrNull(dynamic v) => v is num ? v.toInt() : int.tryParse('$v');

/// "Half Day · 6 people" — package + group summary for a booking, or null
/// for legacy hourly bookings booked solo.
String? bookingPackageLine(Map<String, dynamic> b) {
  final label = (b['package_label'] ?? '').toString();
  final size = asIntOrNull(b['group_size']) ?? 1;
  final parts = <String>[
    if (label.isNotEmpty) label,
    if (size > 1) '$size people',
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

String bookingTimeRange(Map<String, dynamic> b) {
  String hhmm(dynamic v) {
    final s = '$v';
    return s.length >= 5 ? s.substring(0, 5) : s;
  }

  return '${hhmm(b['start_time'])} – ${hhmm(b['end_time'])}';
}

class BookingGuideAvatar extends StatelessWidget {
  final Map<String, dynamic> booking;
  final bool verified;
  final String heroTag;
  final double size;
  const BookingGuideAvatar({
    super.key,
    required this.booking,
    required this.verified,
    required this.heroTag,
    this.size = 52,
  });

  @override
  Widget build(BuildContext context) {
    final name = (booking['guide_name'] ?? 'G').toString();
    final photo = booking['guide_photo']?.toString();

    Widget initial = Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [AppColors.kColorDeep, AppColors.kColorPrimary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'G',
        style: TextStyle(
          fontFamily: 'serif',
          fontSize: size * 0.36,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );

    Widget avatar = (photo == null || photo.isEmpty)
        ? initial
        : ClipOval(
            child: AppNetworkImage(
              url: photo,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorWidget: initial,
            ),
          );

    return Hero(
      tag: heroTag,
      child: SizedBox(
        width: size + 4,
        height: size + 4,
        child: Stack(
          children: [
            avatar,
            if (verified)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(1),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.verified,
                      size: 16, color: AppColors.kColorAccentLight),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class BookingChip extends StatelessWidget {
  final Color bg;
  final Color fg;
  final IconData icon;
  final String label;
  const BookingChip(
      {super.key,
      required this.bg,
      required this.fg,
      required this.icon,
      required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppDimensions.kRadiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 5),
          Text(label,
              style:
                  TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: fg)),
        ],
      ),
    );
  }
}

class BookingPaymentChip extends StatelessWidget {
  final Map<String, dynamic> booking;
  const BookingPaymentChip({super.key, required this.booking});

  @override
  Widget build(BuildContext context) {
    final status = (booking['payment_status'] ?? 'none').toString();
    if (status == 'none') return const SizedBox.shrink();
    final method = booking['payment_method']?.toString();
    if (status == 'paid') {
      return BookingChip(
        bg: const Color(0xFFDCEFE0),
        fg: const Color(0xFF1F6B3B),
        icon: Icons.payments_outlined,
        label: 'Paid${method != null ? ' · $method' : ''}',
      );
    }
    return const BookingChip(
      bg: Color(0xFFF7E7C8),
      fg: Color(0xFF8A5A00),
      icon: Icons.schedule,
      label: 'Payment due',
    );
  }
}
