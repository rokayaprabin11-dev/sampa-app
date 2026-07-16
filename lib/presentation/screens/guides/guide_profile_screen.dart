import 'package:flutter/material.dart';
import 'package:sampada/generated/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:sampada/core/constants/app_colors.dart';
import 'package:sampada/core/constants/app_dimensions.dart';
import 'package:sampada/core/constants/app_strings.dart';
import 'package:sampada/core/theme/app_theme.dart';
import 'package:sampada/presentation/widgets/common/app_network_image.dart';
import 'package:sampada/providers/guide_provider.dart';
import 'package:sampada/presentation/screens/bookings/live_tracking_screen.dart';
import 'package:sampada/presentation/screens/guides/guide_detail_screen.dart';
import 'package:sampada/presentation/screens/guides/guide_edit_screen.dart';
import 'package:sampada/presentation/screens/payments/guide_payment_settings_screen.dart';
import 'package:sampada/presentation/screens/payments/payment_history_screen.dart';
import 'package:sampada/providers/guide_payment_provider.dart';

/// Guide's own listing dashboard. Reached from the Profile screen once the
/// guide application has been approved (status == 'approved').
class GuideProfileScreen extends StatefulWidget {
  const GuideProfileScreen({super.key});

  @override
  State<GuideProfileScreen> createState() => _GuideProfileScreenState();
}

class _GuideProfileScreenState extends State<GuideProfileScreen> {
  // Booking settings — synced from the guide profile and persisted via
  // PATCH /guides/me/ on change.
  bool _availableForBookings = true;
  bool _bookingNotifications = true;
  bool _autoAccept = false;
  bool _settingsSynced = false;

  // Tour history renders a scrollable window of this many cards; the rest scroll
  // inside it. Approx card height sizes the window to ~4 cards.
  static const int _kHistoryVisible = 4;
  static const double _kHistoryCardApprox = 100;

  // The page's own scroll. Held so the tour-history inner list can hand its
  // overscroll back to the page when it reaches its top/bottom edge.
  final ScrollController _pageScroll = ScrollController();

  @override
  void dispose() {
    _pageScroll.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Refresh in case we arrived without a recent fetch.
      final gp = context.read<GuideProvider>();
      gp.fetchMyProfile();
      gp.fetchIncomingBookings();

      // Payments the guide has to answer, and whether they have published an
      // account at all — both surface as tiles below.
      final payments = context.read<GuidePaymentProvider>();
      payments.loadInformation();
      payments.loadReceived();
    });
  }

  Color _accent(bool isDark) => isDark ? AppColors.goldMain : AppColors.kColorDeep;

  // DRF serializes DecimalField (rating_avg, hourly_rate) as a String.
  double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gp = context.watch<GuideProvider>();
    final p = gp.myProfile;

    // One-time sync of the toggle state from the loaded profile.
    if (p != null && !_settingsSynced) {
      _availableForBookings = p['available_for_bookings'] as bool? ?? true;
      _bookingNotifications = p['booking_notifications'] as bool? ?? true;
      _autoAccept = p['auto_accept_bookings'] as bool? ?? false;
      _settingsSynced = true;
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          _buildHeader(context, isDark),
          if (p == null)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: SingleChildScrollView(
                controller: _pageScroll,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatusBar(context, isDark, p),
                    const SizedBox(height: 20),
                    _buildBookingRequests(context, isDark, gp),
                    _buildOngoingTours(context, isDark, gp),
                    _buildMessagesEntry(context, isDark, gp),
                    _buildPaymentEntries(context, isDark),
                    _buildListingCard(context, isDark, p),
                    const SizedBox(height: 16),
                    _buildStatsCard(context, isDark, p),
                    const SizedBox(height: 24),
                    _buildTourHistory(context, isDark, gp),
                    _buildSettings(context, isDark),
                    const SizedBox(height: 24),
                    _buildActions(context, isDark, p),
                    const SizedBox(height: 20),
                    _buildEarnings(context, isDark),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Booking requests (accept / reject) ───────────────────────

  Future<void> _respond(int bookingId, String action) async {
    final l10n = AppLocalizations.of(context)!;
    final okMsg = action == 'accept' ? l10n.bookingAccepted : l10n.bookingDeclined;
    final err = await context.read<GuideProvider>().respondToBooking(bookingId, action);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err ?? okMsg)));
  }

  Widget _buildBookingRequests(BuildContext context, bool isDark, GuideProvider gp) {
    final pending = gp.incomingBookings.where((b) => b['status'] == 'pending').toList();
    if (pending.isEmpty) return const SizedBox.shrink();
    final accent = _accent(isDark);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(AppLocalizations.of(context)!.bookingRequests,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: accent)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(AppDimensions.kRadiusXxl)),
              child: Text('${pending.length}',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.black : Colors.white)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...pending.map((b) => _requestCard(context, isDark, b)),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _requestCard(BuildContext context, bool isDark, Map<String, dynamic> b) {
    final l10n = AppLocalizations.of(context)!;
    final id = b['id'] as int;
    final name = (b['tourist_name'] ?? 'Tourist').toString();
    final date = (b['date'] ?? '').toString();
    String t(dynamic v) => (v ?? '').toString().length >= 5 ? (v).toString().substring(0, 5) : (v ?? '').toString();
    final when = '$date · ${t(b['start_time'])}–${t(b['end_time'])}';
    final notes = (b['notes'] ?? '').toString();
    // Package bookings carry what was chosen and for how many people, plus the
    // locked price — the guide should see exactly what they're accepting.
    final pkgLabel = (b['package_label'] ?? '').toString();
    final groupSize = int.tryParse('${b['group_size'] ?? 1}') ?? 1;
    final price = b['total_price'];
    final pkgLine = [
      if (pkgLabel.isNotEmpty) pkgLabel,
      if (groupSize > 1) '$groupSize people',
      if (price != null) 'NPR $price',
    ].join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppDimensions.kRadiusXl),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.kColorBorderCream),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: isDark ? AppColors.darkBgCard : AppColors.kColorDeep,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(color: AppColors.kColorBgWarm, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                    const SizedBox(height: 2),
                    Text(when, style: TextStyle(fontSize: 11.5, color: isDark ? AppColors.darkTextSecondary : AppColors.kColorTextMuted)),
                  ],
                ),
              ),
            ],
          ),
          if (pkgLine.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.tour_outlined, size: 14,
                    color: isDark ? AppColors.goldMain : AppColors.kColorAccentSafe),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(pkgLine,
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.goldMain : AppColors.kColorAccentSafe)),
                ),
              ],
            ),
          ],
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(notes, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.kColorTextSecondary)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _respond(id, 'reject'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFC0392B),
                    side: const BorderSide(color: Color(0xFFE0B4AE)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.kRadiusMd)),
                  ),
                  child: Text(l10n.btnReject, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _respond(id, 'accept'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.statusSuccess,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.kRadiusMd)),
                  ),
                  child: Text(l10n.btnAccept, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Ongoing tours (mark completed) ───────────────────────────

  Future<void> _markCompleted(int bookingId) async {
    final okMsg = AppLocalizations.of(context)!.tourMarkedAwaitTourist;
    final err = await context
        .read<GuideProvider>()
        .completeTour(bookingId, asGuide: true);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err ?? okMsg)));
  }

  Widget _buildOngoingTours(BuildContext context, bool isDark, GuideProvider gp) {
    final confirmed =
        gp.incomingBookings.where((b) => b['status'] == 'confirmed').toList();
    if (confirmed.isEmpty) return const SizedBox.shrink();
    final accent = _accent(isDark);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(AppLocalizations.of(context)!.sectionConfirmedTours,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: accent)),
        const SizedBox(height: 12),
        ...confirmed.map((b) => _ongoingCard(context, isDark, b)),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _ongoingCard(BuildContext context, bool isDark, Map<String, dynamic> b) {
    final id = b['id'] as int;
    final name = (b['tourist_name'] ?? 'Tourist').toString();
    final date = (b['date'] ?? '').toString();
    String t(dynamic v) => (v ?? '').toString().length >= 5 ? (v).toString().substring(0, 5) : (v ?? '').toString();
    final when = '$date · ${t(b['start_time'])}–${t(b['end_time'])}';
    final awaitingTourist = b['guide_marked_complete_at'] != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppDimensions.kRadiusXl),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.kColorBorderCream),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface)),
                const SizedBox(height: 2),
                Text(when,
                    style: TextStyle(
                        fontSize: 11.5,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.kColorTextMuted)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => LiveTrackingScreen(
                    bookingId: id, otherPartyName: name),
              ),
            ),
            icon: const Icon(Icons.my_location, size: 20),
            tooltip: 'Live location',
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 4),
          awaitingTourist
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.hourglass_top,
                        size: 14, color: AppColors.kColorPendingText),
                    const SizedBox(width: 4),
                    Text(AppLocalizations.of(context)!.labelAwaitingTourist,
                        style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.kColorPendingText)),
                  ],
                )
              : ElevatedButton(
                  onPressed: () => _markCompleted(id),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.statusSuccess,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppDimensions.kRadiusMd)),
                  ),
                  child: Text(AppLocalizations.of(context)!.btnMarkCompleted,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12)),
                ),
        ],
      ),
    );
  }

  // ─── Messages ─────────────────────────────────────────────────

  /// Entry point to the guide's inbox. A chat exists for every booking that
  /// reached `confirmed` (and stays reachable through `completed`), which is
  /// exactly what the inbox lists — so the count here is the count there.
  Widget _buildMessagesEntry(BuildContext context, bool isDark, GuideProvider gp) {
    final conversations = gp.incomingBookings
        .where((b) => b['status'] == 'confirmed' || b['status'] == 'completed')
        .length;
    final accent = _accent(isDark);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppDimensions.kRadiusXl),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppDimensions.kRadiusXl),
          onTap: () => Navigator.pushNamed(context, AppStrings.messagesPath),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDimensions.kRadiusXl),
              border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.kColorBorderCream),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkBgCard : AppColors.kColorTagBg,
                    borderRadius: BorderRadius.circular(AppDimensions.kRadiusMd),
                  ),
                  child: Icon(Icons.forum_outlined, size: 20, color: accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Messages',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface)),
                      const SizedBox(height: 2),
                      Text(
                        conversations == 0
                            ? 'No conversations yet'
                            : '$conversations ${conversations == 1 ? 'conversation' : 'conversations'}',
                        style: TextStyle(
                            fontSize: 11.5,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.kColorTextMuted),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.kColorTextMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Payments ─────────────────────────────────────────────────

  /// The two things a guide does about money: say where to send it, and confirm
  /// it arrived. Both are theirs alone — Sampada holds no funds and cannot
  /// confirm a payment on their behalf.
  Widget _buildPaymentEntries(BuildContext context, bool isDark) {
    final payments = context.watch<GuidePaymentProvider>();
    final pending = payments.pending.length;
    final needsSetup = !payments.loadingInformation && payments.needsSetup;

    return Column(
      children: [
        _buildNavTile(
          context,
          isDark,
          icon: Icons.account_balance_wallet_outlined,
          title: 'Payment Information',
          // The empty state is the important one: with no account published,
          // every tourist who owes this guide has to ask them in chat.
          subtitle: needsSetup
              ? 'Not set up — tourists cannot pay you'
              : 'Where tourists send your money',
          warn: needsSetup,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const GuidePaymentSettingsScreen()),
          ).then((_) => payments.loadInformation()),
        ),
        _buildNavTile(
          context,
          isDark,
          icon: Icons.receipt_long_outlined,
          title: 'Payments Received',
          subtitle: pending == 0
              ? 'Confirm payments from your tourists'
              : '$pending waiting for your confirmation',
          badge: pending,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const GuidePaymentHistoryScreen()),
          ).then((_) => payments.loadReceived()),
        ),
      ],
    );
  }

  /// The row used by the messages and payment entries: icon, title, one line of
  /// context, optional count.
  Widget _buildNavTile(
    BuildContext context,
    bool isDark, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    int badge = 0,
    bool warn = false,
  }) {
    final accent = warn ? AppColors.statusWarning : _accent(isDark);
    final muted =
        isDark ? AppColors.darkTextSecondary : AppColors.kColorTextMuted;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppDimensions.kRadiusXl),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppDimensions.kRadiusXl),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDimensions.kRadiusXl),
              border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.kColorBorderCream),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkBgCard : AppColors.kColorTagBg,
                    borderRadius: BorderRadius.circular(AppDimensions.kRadiusMd),
                  ),
                  child: Icon(icon, size: 20, color: accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: TextStyle(
                              fontSize: 11.5,
                              color: warn ? AppColors.statusWarning : muted)),
                    ],
                  ),
                ),
                if (badge > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.kColorPendingBg,
                      borderRadius:
                          BorderRadius.circular(AppDimensions.kRadiusPill),
                    ),
                    child: Text('$badge',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.kColorPendingText)),
                  ),
                Icon(Icons.chevron_right, color: muted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Tour history ─────────────────────────────────────────────

  /// Everything this guide has finished or lost: completed and cancelled tours.
  /// Lives here rather than in the tourist's My Bookings, because a guide's
  /// bookings are the ones addressed *to* them, not the ones they made.
  Widget _buildTourHistory(BuildContext context, bool isDark, GuideProvider gp) {
    final history = gp.incomingBookings
        .where((b) => b['status'] == 'completed' || b['status'] == 'cancelled')
        .toList()
      ..sort((a, b) => '${b['date']}'.compareTo('${a['date']}'));

    final accent = _accent(isDark);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('TOUR HISTORY',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: accent)),
            const SizedBox(width: 8),
            if (history.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(
                    color: accent,
                    borderRadius:
                        BorderRadius.circular(AppDimensions.kRadiusXxl)),
                child: Text('${history.length}',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.black : Colors.white)),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (history.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(AppDimensions.kRadiusXl),
              border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.kColorBorderCream),
            ),
            child: Text(
              'Tours you finish will be listed here.',
              style: TextStyle(
                  fontSize: 12.5,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.kColorTextMuted),
            ),
          )
        else if (history.length <= _kHistoryVisible)
          // Few enough to show inline — no inner scroll needed.
          ...history.map((b) => _historyCard(context, isDark, b))
        else
          // Show a window of ~4 cards and scroll within for the rest, so a long
          // history doesn't push the settings/earnings sections far down the page.
          // Once the inner list hits its top/bottom, its overscroll is handed to
          // the page so one continuous drag keeps scrolling the profile.
          NotificationListener<OverscrollNotification>(
            onNotification: _handleHistoryOverscroll,
            child: SizedBox(
              height: _kHistoryCardApprox * _kHistoryVisible,
              child: ListView.builder(
                padding: EdgeInsets.zero,
                physics: const ClampingScrollPhysics(),
                itemCount: history.length,
                itemBuilder: (_, i) => _historyCard(context, isDark, history[i]),
              ),
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }

  /// Hand the inner history list's edge overscroll to the page: scroll the
  /// profile by the leftover delta so one continuous drag flows from the list
  /// into the page once the list can't move further.
  bool _handleHistoryOverscroll(OverscrollNotification n) {
    if (!_pageScroll.hasClients) return false;
    final pos = _pageScroll.position;
    final target = (_pageScroll.offset + n.overscroll)
        .clamp(pos.minScrollExtent, pos.maxScrollExtent);
    if (target != _pageScroll.offset) _pageScroll.jumpTo(target);
    return true;
  }

  Widget _historyCard(BuildContext context, bool isDark, Map<String, dynamic> b) {
    final name = (b['tourist_name'] ?? 'Tourist').toString();
    final completed = b['status'] == 'completed';
    final price = b['total_price'];
    final rating = b['review_rating'];
    final pkg = (b['package_label'] ?? '').toString();
    final group = int.tryParse('${b['group_size'] ?? 1}') ?? 1;
    final paid = b['payment_status'] == 'paid';

    final statusBg = completed
        ? AppColors.statusInfo.withValues(alpha: 0.12)
        : AppColors.statusError.withValues(alpha: 0.10);
    final statusFg = completed ? AppColors.statusInfo : AppColors.statusError;

    final sub = [
      if (pkg.isNotEmpty) pkg,
      if (group > 1) '$group people',
    ].join(' · ');

    return GestureDetector(
      onTap: () => _showHistoryDetail(context, isDark, b),
      child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppDimensions.kRadiusXl),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.kColorBorderCream),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius:
                        BorderRadius.circular(AppDimensions.kRadiusXxl)),
                child: Text(completed ? 'Completed' : 'Cancelled',
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: statusFg)),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, size: 16,
                  color: isDark ? AppColors.darkTextSecondary : const Color(0xFFB0A090)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.event_outlined,
                  size: 13, color: AppColors.kColorAccentSafe),
              const SizedBox(width: 4),
              Text('${b['date'] ?? ''}',
                  style: TextStyle(
                      fontSize: 11.5,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.kColorTextMuted)),
              if (sub.isNotEmpty) ...[
                const SizedBox(width: 10),
                const Icon(Icons.tour_outlined,
                    size: 13, color: AppColors.kColorAccentSafe),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11.5,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.kColorTextMuted)),
                ),
              ],
            ],
          ),
          if (completed && (price != null || rating is num)) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (price != null) ...[
                  Text('NPR $price',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface)),
                  const SizedBox(width: 6),
                  Text(paid ? '· Paid' : '· Unpaid',
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: paid
                              ? AppColors.kColorOfflineText
                              : AppColors.kColorPendingText)),
                ],
                const Spacer(),
                if (rating is num)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ...List.generate(
                        5,
                        (i) => Icon(
                          i < rating.round()
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          size: 14,
                          color: AppColors.kColorAccentLight,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ],
      ),
      ),
    );
  }

  // ─── Tour detail sheet ────────────────────────────────────────

  /// Full detail of a completed/cancelled tour, opened by tapping a history
  /// card. Shows everything the summary card omits — exact time, package,
  /// group size, payment status, receipt, the tourist's review and per-category
  /// scores, and the guide's own reply.
  void _showHistoryDetail(BuildContext context, bool isDark, Map<String, dynamic> b) {
    String t(dynamic v) => (v ?? '').toString().length >= 5
        ? v.toString().substring(0, 5)
        : (v ?? '').toString();

    final name = (b['tourist_name'] ?? 'Tourist').toString();
    final completed = b['status'] == 'completed';
    final start = t(b['start_time']);
    final end = t(b['end_time']);
    final pkg = (b['package_label'] ?? '').toString();
    final group = int.tryParse('${b['group_size'] ?? 1}') ?? 1;
    final price = b['total_price'];
    final payStatus = (b['payment_status'] ?? '').toString();
    final receipt = (b['receipt_no'] ?? '').toString();
    final rating = b['review_rating'];
    final reviewText = (b['review_text'] ?? '').toString();
    final guideReply = (b['guide_reply'] ?? '').toString();
    final notes = (b['notes'] ?? '').toString();

    final categories = <String, dynamic>{
      'Knowledge': b['review_knowledge'],
      'Communication': b['review_communication'],
      'Friendliness': b['review_friendliness'],
      'Punctuality': b['review_punctuality'],
      'Value': b['review_value'],
    }..removeWhere((_, v) => v is! num);

    final statusBg = completed
        ? AppColors.statusInfo.withValues(alpha: 0.12)
        : AppColors.statusError.withValues(alpha: 0.10);
    final statusFg = completed ? AppColors.statusInfo : AppColors.statusError;
    final muted = isDark ? AppColors.darkTextSecondary : AppColors.kColorTextMuted;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final onSurface = Theme.of(ctx).colorScheme.onSurface;
        return Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
          decoration: BoxDecoration(
            color: Theme.of(ctx).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppDimensions.kRadiusXxl)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10),
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: muted.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold, color: onSurface)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(AppDimensions.kRadiusXxl)),
                      child: Text(completed ? 'Completed' : 'Cancelled',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold, color: statusFg)),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _detailRow(context, isDark, 'Date', '${b['date'] ?? '—'}'),
                      if (start.isNotEmpty || end.isNotEmpty)
                        _detailRow(context, isDark, 'Time', '$start – $end'),
                      _detailRow(context, isDark, 'Package', pkg.isNotEmpty ? pkg : 'Hourly'),
                      _detailRow(context, isDark, 'Group size',
                          group > 1 ? '$group people' : '1 person'),
                      if (price != null)
                        _detailRow(context, isDark, 'Price', 'NPR $price'),
                      if (completed && payStatus.isNotEmpty)
                        _detailRow(context, isDark, 'Payment',
                            _prettyPayment(payStatus),
                            valueColor: payStatus == 'paid'
                                ? AppColors.kColorOfflineText
                                : AppColors.kColorPendingText),
                      if (receipt.isNotEmpty)
                        _detailRow(context, isDark, 'Receipt', receipt),
                      if (notes.isNotEmpty)
                        _detailRow(context, isDark, 'Notes', notes),

                      // Review
                      if (rating is num) ...[
                        const SizedBox(height: 14),
                        Text('TOURIST REVIEW',
                            style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                                color: muted)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            ...List.generate(5, (i) => Icon(
                                  i < rating.round()
                                      ? Icons.star_rounded
                                      : Icons.star_outline_rounded,
                                  size: 18,
                                  color: AppColors.kColorAccentLight,
                                )),
                            const SizedBox(width: 8),
                            Text(rating.toStringAsFixed(1),
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: onSurface)),
                          ],
                        ),
                        if (reviewText.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(reviewText,
                              style: TextStyle(fontSize: 13, height: 1.5, color: onSurface)),
                        ],
                        if (categories.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          for (final e in categories.entries)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 120,
                                    child: Text(e.key,
                                        style: TextStyle(fontSize: 12.5, color: muted)),
                                  ),
                                  ...List.generate(5, (i) => Icon(
                                        i < (e.value as num).round()
                                            ? Icons.star_rounded
                                            : Icons.star_outline_rounded,
                                        size: 13,
                                        color: AppColors.kColorAccentLight,
                                      )),
                                ],
                              ),
                            ),
                        ],
                        if (guideReply.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkBgCard : AppColors.kColorSurface,
                              borderRadius: BorderRadius.circular(AppDimensions.kRadiusMd),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Your reply',
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: muted)),
                                const SizedBox(height: 4),
                                Text(guideReply,
                                    style: TextStyle(fontSize: 13, height: 1.5, color: onSurface)),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _prettyPayment(String status) {
    switch (status) {
      case 'paid':
        return 'Paid';
      case 'due':
        return 'Due';
      case 'submitted':
        return 'Awaiting your confirmation';
      case 'rejected':
        return 'Rejected';
      default:
        return status.isEmpty ? '—' : status[0].toUpperCase() + status.substring(1);
    }
  }

  Widget _detailRow(BuildContext context, bool isDark, String label, String value,
      {Color? valueColor}) {
    final muted = isDark ? AppColors.darkTextSecondary : AppColors.kColorTextMuted;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(label, style: TextStyle(fontSize: 12.5, color: muted)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? Theme.of(context).colorScheme.onSurface)),
          ),
        ],
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        // Same terracotta gradient as Settings/About/Help — the app's signature
        // header, fixed across light and dark so every screen reads the same.
        gradient: AppTheme.navGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(AppDimensions.kRadiusXxl),
          bottomRight: Radius.circular(AppDimensions.kRadiusXxl),
        ),
      ),
      // Sizes to its content instead of a fixed screen-height fraction.
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppLocalizations.of(context)!.myGuideProfile, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  Text(AppLocalizations.of(context)!.manageListing, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Verified / Active status bar ─────────────────────────────

  Widget _buildStatusBar(BuildContext context, bool isDark, Map<String, dynamic> p) {
    final isVerified = (p['is_verified'] as bool?) ?? false;
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBgCard : const Color(0xFFE8F5EC),
        borderRadius: BorderRadius.circular(AppDimensions.kRadiusLg),
        border: isDark ? Border.all(color: AppColors.darkBorder) : null,
      ),
      child: Row(
        children: [
          const Icon(Icons.circle, color: AppColors.statusSuccess, size: 10),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isVerified ? AppLocalizations.of(context)!.verifiedGuideActive : AppLocalizations.of(context)!.labelActive,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkTextSecondary : const Color(0xFF2E5A3A),
              ),
            ),
          ),
          _outlineButton(context, isDark, 'Edit Listing', _onEdit),
        ],
      ),
    );
  }

  // ─── Main listing card ────────────────────────────────────────

  Widget _buildListingCard(BuildContext context, bool isDark, Map<String, dynamic> p) {
    final accent = _accent(isDark);
    final user = p['user'] as Map<String, dynamic>? ?? {};
    final fullName = (user['full_name'] ?? user['username'] ?? 'Guide').toString();
    final initials = fullName.split(' ').take(2).map((s) => s.isNotEmpty ? s[0].toUpperCase() : '').join();
    final photoUrl = p['photo_url'] as String?;
    final rate = p['hourly_rate'];
    final rating = _toDouble(p['rating_avg']);
    final reviewCount = (p['review_count'] as int?) ?? 0;
    final isVerified = (p['is_verified'] as bool?) ?? false;
    final isTopGuide = rating >= 4.5 && reviewCount >= 10;
    final specialties = ((p['specialties'] as List?) ?? []).cast<String>();
    final languages = ((p['languages'] as List?) ?? []).cast<String>();
    final areas = ((p['areas'] as List?) ?? []).cast<String>();
    final location = areas.isNotEmpty ? areas.first : 'Nepal';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppDimensions.kRadiusXxl),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.kColorBorderCream),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: isDark ? AppColors.darkBgCard : AppColors.kColorBrownDarkest,
                child: (photoUrl != null && photoUrl.isNotEmpty)
                    ? ClipOval(
                        child: AppNetworkImage(url: photoUrl, width: 60, height: 60, cloudinaryWidth: 60),
                      )
                    : Text(initials, style: const TextStyle(color: AppColors.kColorBgWarm, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(fullName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                    const SizedBox(height: 2),
                    Text(location, style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.kColorTextMuted)),
                  ],
                ),
              ),
              if (rate != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(AppLocalizations.of(context)!.nprAmount(rate.toString()), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: accent)),
                    Text(AppLocalizations.of(context)!.labelPerHour, style: TextStyle(fontSize: 10, color: isDark ? AppColors.darkTextSecondary : AppColors.kColorTextMuted)),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Badges
          Wrap(
            spacing: 8, runSpacing: 8,
            children: [
              if (isTopGuide) _badge(isDark, '⭐ Top Guide', AppColors.kColorPendingBg, AppColors.kColorPendingText),
              if (isVerified) _badge(isDark, '✓ Verified', const Color(0xFFE8F5EC), AppColors.statusSuccess),
            ],
          ),
          if (specialties.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: specialties.map((s) => _softChip(context, isDark, s, accent.withValues(alpha: 0.35))).toList(),
            ),
          ],
          if (languages.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: languages.map((l) => _softChip(context, isDark, l, isDark ? AppColors.darkBorder : AppColors.kColorBorderSubtle)).toList(),
            ),
          ],
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkBgCard : AppColors.kColorSurface,
              borderRadius: BorderRadius.circular(AppDimensions.kRadiusMd),
            ),
            child: Row(
              children: [
                Icon(Icons.star, color: isDark ? AppColors.goldMain : AppColors.kColorAccent, size: 16),
                const SizedBox(width: 4),
                Text('${rating.toStringAsFixed(1)} ($reviewCount reviews)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _availableForBookings ? AppLocalizations.of(context)!.availableToday : AppLocalizations.of(context)!.notAcceptingBookings,
                    style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : AppColors.kColorTextMuted),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Stats ────────────────────────────────────────────────────

  Widget _buildStatsCard(BuildContext context, bool isDark, Map<String, dynamic> p) {
    final reviewCount = (p['review_count'] as int?) ?? 0;
    final rating = _toDouble(p['rating_avg']);
    final yearsExp = (p['years_experience'] as String?) ?? '—';
    // Completed bookings = tours done.
    final toursDone = _completedStats(context.read<GuideProvider>()).toursDone;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppDimensions.kRadiusXxl),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.kColorBorderCream),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _stat(context, isDark, '$reviewCount', 'Reviews'),
          _statDivider(isDark),
          _stat(context, isDark, '$toursDone', 'Tours Done'),
          _statDivider(isDark),
          _stat(context, isDark, rating.toStringAsFixed(1), 'Rating'),
          _statDivider(isDark),
          _stat(context, isDark, _shortExperience(yearsExp), 'Active'),
        ],
      ),
    );
  }

  String _shortExperience(String raw) {
    // '3 – 5 years' → '3–5y', '10+ years' → '10+y', fallback to raw.
    final digits = RegExp(r'\d+\+?').allMatches(raw).map((m) => m.group(0)).toList();
    if (digits.isEmpty) return '—';
    return '${digits.join('–')}y';
  }

  // ─── Availability & settings ──────────────────────────────────

  Widget _buildSettings(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.availabilitySettings,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
            color: isDark ? AppColors.goldMain : AppColors.kColorAccentSafe,
          ),
        ),
        const SizedBox(height: 12),
        _settingTile(context, isDark, Icons.circle, AppColors.kColorOnlineDot,
            AppLocalizations.of(context)!.settingAvailableForBookings,
            _availableForBookings, (v) => _persistSetting(
                'available_for_bookings', v, () => _availableForBookings = v)),
        const SizedBox(height: 10),
        _settingTile(context, isDark, Icons.notifications_none, AppColors.kColorAccent,
            AppLocalizations.of(context)!.settingBookingNotifications,
            _bookingNotifications, (v) => _persistSetting(
                'booking_notifications', v, () => _bookingNotifications = v)),
        const SizedBox(height: 10),
        _settingTile(context, isDark, Icons.flash_on, AppColors.kColorAccent,
            AppLocalizations.of(context)!.settingAutoAccept,
            _autoAccept, (v) => _persistSetting(
                'auto_accept_bookings', v, () => _autoAccept = v)),
      ],
    );
  }

  Widget _settingTile(BuildContext context, bool isDark, IconData icon, Color iconColor, String label, bool value, ValueChanged<bool> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppDimensions.kRadiusLg),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.kColorBorderCream),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppDimensions.kRadiusMd),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.onSurface)),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: _accent(isDark),
          ),
        ],
      ),
    );
  }

  // ─── Action buttons ───────────────────────────────────────────

  Widget _buildActions(BuildContext context, bool isDark, Map<String, dynamic> p) {
    final l10n = AppLocalizations.of(context)!;
    final accent = _accent(isDark);
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => GuideDetailScreen(guide: p)),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: accent,
              side: BorderSide(color: accent),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.kRadiusLg)),
            ),
            child: Text(l10n.btnViewMyListing, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: _onEdit,
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: isDark ? Colors.black : Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.kRadiusLg)),
            ),
            child: Text(l10n.btnEditProfile, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ),
        ),
      ],
    );
  }

  // ─── Earnings ─────────────────────────────────────────────────

  Widget _buildEarnings(BuildContext context, bool isDark) {
    // Derived from completed bookings this calendar month.
    final stats = _completedStats(context.read<GuideProvider>());
    final earnings = stats.monthEarnings.toStringAsFixed(0);
    final avg = stats.avgRating == null ? '—' : stats.avgRating!.toStringAsFixed(1);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBgCard : AppColors.kColorPendingBg,
        borderRadius: BorderRadius.circular(AppDimensions.kRadiusLg),
        border: isDark ? Border.all(color: AppColors.darkBorder) : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppLocalizations.of(context)!.thisMonthEarnings,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? AppColors.darkTextSecondary : AppColors.kColorPendingText)),
                const SizedBox(height: 4),
                Text(AppLocalizations.of(context)!.nprAmount(earnings.toString()),
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? AppColors.goldMain : AppColors.kColorPendingText)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${stats.toursDone} tours', style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.kColorPendingText)),
              Text('$avg avg rating', style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.kColorPendingText)),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Shared bits ──────────────────────────────────────────────

  /// Optimistically flip a booking-setting toggle and persist it via
  /// PATCH /guides/me/; roll back + warn on failure.
  Future<void> _persistSetting(String field, bool value, VoidCallback apply) async {
    setState(apply);
    final err = await context.read<GuideProvider>().updateMyProfile({field: value});
    if (err != null && mounted) {
      setState(() {
        // Roll back the toggle on failure.
        switch (field) {
          case 'available_for_bookings':
            _availableForBookings = !value;
          case 'booking_notifications':
            _bookingNotifications = !value;
          case 'auto_accept_bookings':
            _autoAccept = !value;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.couldntSaveSetting)),
      );
    }
  }

  /// Derive real dashboard stats from the guide's completed bookings (already
  /// fetched into GuideProvider.incomingBookings).
  ({int toursDone, double monthEarnings, double? avgRating}) _completedStats(GuideProvider gp) {
    final now = DateTime.now();
    var earnings = 0.0;
    final ratings = <double>[];
    var done = 0;
    for (final b in gp.incomingBookings) {
      if (b['status'] != 'completed') continue;
      done++;
      final d = DateTime.tryParse((b['date'] as String?) ?? '');
      if (d != null && d.year == now.year && d.month == now.month) {
        earnings += _toDouble(b['total_price']);
      }
      final r = b['review_rating'];
      if (r is num) ratings.add(r.toDouble());
    }
    final avg = ratings.isEmpty ? null : ratings.reduce((a, b) => a + b) / ratings.length;
    return (toursDone: done, monthEarnings: earnings, avgRating: avg);
  }

  void _onEdit() {
    // Dedicated edit flow (PATCH /guides/me/) — does NOT reset approval status,
    // unlike re-submitting the application.
    final p = context.read<GuideProvider>().myProfile;
    if (p == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GuideEditScreen(profile: p)),
    );
  }

  Widget _stat(BuildContext context, bool isDark, String value, String label) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? AppColors.goldMain : AppColors.kColorAccentSafe)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : AppColors.kColorTextMuted)),
      ],
    );
  }

  Widget _statDivider(bool isDark) {
    return Container(width: 1, height: 32, color: isDark ? AppColors.darkBorder : const Color(0xFFEADFCB));
  }

  Widget _badge(bool isDark, String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: isDark ? AppColors.darkBgCard : bg, borderRadius: BorderRadius.circular(AppDimensions.kRadiusXxl)),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? AppColors.goldMain : fg)),
    );
  }

  Widget _softChip(BuildContext context, bool isDark, String label, Color borderColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBgCard : Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.kRadiusXxl),
        border: Border.all(color: borderColor),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.kColorTextSecondary)),
    );
  }

  Widget _outlineButton(BuildContext context, bool isDark, String label, VoidCallback onTap) {
    final accent = _accent(isDark);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkBgCard : Colors.white,
          borderRadius: BorderRadius.circular(AppDimensions.kRadiusXxl),
          border: Border.all(color: accent),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: accent)),
      ),
    );
  }
}
