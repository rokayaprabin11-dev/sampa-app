import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sampada/core/constants/app_colors.dart';
import 'package:sampada/core/constants/app_dimensions.dart';
import 'package:sampada/generated/app_localizations.dart';
import 'package:sampada/presentation/screens/guides/chat_screen.dart';
import 'package:sampada/presentation/widgets/common/app_network_image.dart';
import 'package:sampada/providers/guide_provider.dart';

/// Which tab a booking belongs to. Derived from status, not stored:
/// pending + confirmed → Upcoming; completed → Completed; cancelled → Cancelled.
enum _BookingTab { upcoming, completed, cancelled }

extension on _BookingTab {
  String get label => switch (this) {
        _BookingTab.upcoming => 'Upcoming',
        _BookingTab.completed => 'Completed',
        _BookingTab.cancelled => 'Cancelled',
      };
}

_BookingTab _tabOf(Map<String, dynamic> b) => switch (b['status']) {
      'completed' => _BookingTab.completed,
      'cancelled' => _BookingTab.cancelled,
      _ => _BookingTab.upcoming,
    };

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  _BookingTab _tab = _BookingTab.upcoming;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GuideProvider>().fetchMyBookings();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: false,
        foregroundColor: isDark ? AppColors.goldMain : AppColors.kColorTextHeading,
        title: Text(
          'My Bookings',
          style: TextStyle(
            fontFamily: 'serif',
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: isDark ? AppColors.goldMain : AppColors.kColorTextHeading,
          ),
        ),
      ),
      body: Consumer<GuideProvider>(
        builder: (context, gp, _) {
          final bookings = gp.myBookings;
          final counts = <_BookingTab, int>{
            for (final t in _BookingTab.values)
              t: bookings.where((b) => _tabOf(b) == t).length,
          };
          final visible = bookings.where((b) => _tabOf(b) == _tab).toList()
            ..sort((a, b) => '${b['date']}'.compareTo('${a['date']}'));

          return Column(
            children: [
              _TabBar(
                active: _tab,
                counts: counts,
                onChanged: (t) => setState(() => _tab = t),
              ),
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.kColorPrimary,
                  onRefresh: gp.fetchMyBookings,
                  child: visible.isEmpty
                      ? ListView(
                          children: [
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.55,
                              child: _EmptyView(tab: _tab),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: visible.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 14),
                          itemBuilder: (context, i) => _BookingCard(booking: visible[i]),
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  final _BookingTab active;
  final Map<_BookingTab, int> counts;
  final ValueChanged<_BookingTab> onChanged;
  const _TabBar({required this.active, required this.counts, required this.onChanged});

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
        children: _BookingTab.values.map((tab) {
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
                  color: selected ? AppColors.kColorPrimary : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppDimensions.kRadiusMd),
                ),
                alignment: Alignment.center,
                child: Text(
                  count > 0 ? '${tab.label} ($count)' : tab.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? Colors.white
                        : (isDark ? AppColors.darkTextSecondary : AppColors.kColorTextSecondary),
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
  final _BookingTab tab;
  const _EmptyView({required this.tab});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final message = switch (tab) {
      _BookingTab.upcoming => 'No upcoming bookings.\nFind a guide to plan your next tour!',
      _BookingTab.completed => 'No completed tours yet.',
      _BookingTab.cancelled => 'No cancelled bookings.',
    };
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_note_outlined,
              size: 64, color: isDark ? AppColors.darkTextSecondary : const Color(0xFFB08060)),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: isDark ? AppColors.darkTextSecondary : const Color(0xFF8C7162),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  const _BookingCard({required this.booking});

  String get _guideName => (booking['guide_name'] ?? 'Guide').toString();
  String get _status => (booking['status'] ?? 'pending').toString();
  String? get _price => booking['total_price']?.toString();

  bool get _awaitingConfirm =>
      _status == 'confirmed' &&
      booking['guide_marked_complete_at'] != null &&
      booking['tourist_confirmed_complete_at'] == null;

  bool get _paymentDue => _status == 'completed' && booking['payment_status'] == 'due';
  bool get _canReview => _status == 'completed' && booking['reviewed_at'] == null;
  bool get _canChat => _status == 'confirmed' || _status == 'completed';
  bool get _canCancel => _status == 'pending' || (_status == 'confirmed' && !_awaitingConfirm);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppDimensions.kRadiusXxl),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.kColorBorderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _guideAvatar(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_guideName,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
                        )),
                    const SizedBox(height: 2),
                    Text('Tour Guide',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.kColorTextMuted,
                        )),
                  ],
                ),
              ),
              _StatusChip(status: _status),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: isDark ? AppColors.darkBorder : AppColors.kColorBorderFaint),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.event_outlined, size: 16, color: AppColors.kColorAccentSafe),
              const SizedBox(width: 6),
              Text('${booking['date'] ?? ''}',
                  style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface)),
              const SizedBox(width: 14),
              const Icon(Icons.schedule, size: 16, color: AppColors.kColorAccentSafe),
              const SizedBox(width: 6),
              Text(_timeRange(),
                  style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface)),
            ],
          ),
          if (_price != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.payments_outlined, size: 16, color: AppColors.kColorAccentSafe),
                const SizedBox(width: 6),
                Text('NPR $_price', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
                const SizedBox(width: 10),
                _PaymentChip(booking: booking),
              ],
            ),
          ],
          if ((booking['notes'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('“${booking['notes']}”',
                style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.kColorTextMuted)),
          ],
          if (booking['receipt_no'] != null) ...[
            const SizedBox(height: 8),
            Text('Receipt: ${booking['receipt_no']}',
                style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.kColorTextMuted)),
          ],
          if (_status == 'pending') ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.kColorPendingBg,
                borderRadius: BorderRadius.circular(AppDimensions.kRadiusMd),
                border: Border.all(color: AppColors.kColorPendingBorder),
              ),
              child: const Row(
                children: [
                  Icon(Icons.hourglass_top, size: 15, color: AppColors.kColorPendingText),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Waiting for the guide to respond',
                        style: TextStyle(fontSize: 12, color: AppColors.kColorPendingText)),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          _actions(context),
        ],
      ),
    );
  }

  String _timeRange() {
    String hhmm(dynamic v) {
      final s = '$v';
      return s.length >= 5 ? s.substring(0, 5) : s;
    }

    return '${hhmm(booking['start_time'])} – ${hhmm(booking['end_time'])}';
  }

  Widget _guideAvatar() {
    final initial = CircleAvatar(
      radius: 22,
      backgroundColor: AppColors.kColorTagBg,
      child: Text(
        _guideName.isNotEmpty ? _guideName[0].toUpperCase() : 'G',
        style: const TextStyle(
            fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.kColorAccentDark),
      ),
    );
    final photo = booking['guide_photo']?.toString();
    if (photo == null || photo.isEmpty) return initial;
    return ClipOval(
      child: AppNetworkImage(
        url: photo,
        width: 44,
        height: 44,
        fit: BoxFit.cover,
        errorWidget: initial,
      ),
    );
  }

  Widget _actions(BuildContext context) {
    final gp = context.read<GuideProvider>();
    final id = booking['id'] as int;
    final buttons = <Widget>[];

    if (_awaitingConfirm) {
      buttons.add(_primaryBtn(
        icon: Icons.task_alt,
        label: 'Confirm Tour Done',
        color: const Color(0xFF2E7D32),
        onTap: () async {
          final l10n = AppLocalizations.of(context)!;
          final messenger = ScaffoldMessenger.of(context);
          final err = await gp.completeTour(id, asGuide: false);
          messenger.showSnackBar(SnackBar(content: Text(err ?? l10n.tourConfirmedSettle)));
        },
      ));
    }

    if (_paymentDue) {
      buttons.add(_primaryBtn(
        icon: Icons.payments_outlined,
        label: 'Pay Now',
        color: AppColors.kColorPrimary,
        onTap: () => _openPaymentSheet(context, gp),
      ));
    }

    if (_canReview) {
      buttons.add(_outlineBtn(
        icon: Icons.star_outline,
        label: 'Rate Guide',
        onTap: () => _openReviewDialog(context, gp),
      ));
    }

    if (_canChat) {
      buttons.add(_outlineBtn(
        icon: Icons.chat_bubble_outline,
        label: 'Message',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(bookingId: id, otherPartyName: _guideName),
          ),
        ),
      ));
    }

    if (_canCancel) {
      buttons.add(_outlineBtn(
        icon: Icons.close,
        label: _status == 'pending' ? 'Cancel Request' : 'Cancel Booking',
        danger: true,
        onTap: () => _confirmCancel(context, gp),
      ));
    }

    if (buttons.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 8, runSpacing: 8, children: buttons);
  }

  Widget _primaryBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) =>
      ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        ),
      );

  Widget _outlineBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    final color = danger ? AppColors.statusError : AppColors.kColorPrimary;
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      ),
    );
  }

  Future<void> _confirmCancel(BuildContext context, GuideProvider gp) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.kRadiusXxl)),
        title: Text('Cancel this booking?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(ctx).colorScheme.onSurface)),
        content: Text('The guide will be notified. This cannot be undone.',
            style: TextStyle(fontSize: 13, color: Theme.of(ctx).colorScheme.onSurface)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Keep Booking', style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.statusError, foregroundColor: Colors.white),
            child: Text(l10n.btnConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await gp.updateBookingStatus(booking['id'] as int, 'cancelled');
    messenger.showSnackBar(const SnackBar(content: Text('Booking cancelled.')));
  }

  static const _paymentMethods = [
    ('esewa', 'eSewa', Icons.account_balance_wallet_outlined),
    ('khalti', 'Khalti', Icons.account_balance_wallet_outlined),
    ('fonepay', 'Fonepay', Icons.qr_code_2),
    ('cash', 'Cash', Icons.payments_outlined),
  ];

  /// Records how the tourist settled up (no money moves through the app) —
  /// same pay-after-service model as the Guides screen's action card.
  Future<void> _openPaymentSheet(BuildContext context, GuideProvider gp) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final refController = TextEditingController();
    String method = 'esewa';
    bool submitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.kRadiusXxl)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.paySheetTitle,
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700, color: Theme.of(ctx).colorScheme.onSurface)),
              const SizedBox(height: 4),
              Text(
                '${l10n.paySheetBody(_guideName)}${_price != null ? ' — NPR $_price' : ''}',
                style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              ..._paymentMethods.map((m) {
                final selected = method == m.$1;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () => setLocal(() => method = m.$1),
                    borderRadius: BorderRadius.circular(AppDimensions.kRadiusLg),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.kColorPrimary.withValues(alpha: 0.08)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppDimensions.kRadiusLg),
                        border: Border.all(
                          color: selected
                              ? AppColors.kColorPrimary
                              : (isDark ? AppColors.darkBorder : AppColors.kColorBorderSubtle),
                          width: selected ? 1.6 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(m.$3, size: 20,
                              color: selected ? AppColors.kColorPrimary : AppColors.kColorTextMuted),
                          const SizedBox(width: 10),
                          Text(m.$2,
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                  color: Theme.of(ctx).colorScheme.onSurface)),
                          const Spacer(),
                          if (selected)
                            const Icon(Icons.check_circle, size: 18, color: AppColors.kColorPrimary),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 8),
              TextField(
                controller: refController,
                style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Transaction reference (optional)',
                  hintStyle: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.darkTextTertiary : Colors.grey),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDimensions.kRadiusMd)),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: submitting
                      ? null
                      : () async {
                          setLocal(() => submitting = true);
                          final (err, updated) = await gp.recordPayment(
                              booking['id'] as int, method, refController.text.trim());
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          messenger.showSnackBar(SnackBar(
                            content: Text(err ??
                                'Payment recorded${updated?['receipt_no'] != null ? ' — receipt ${updated!['receipt_no']}' : ''}.'),
                          ));
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.kColorPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(submitting ? 'Recording…' : l10n.btnPayNow),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openReviewDialog(BuildContext context, GuideProvider gp) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final controller = TextEditingController();
    int rating = 5;

    final result = await showDialog<(int, String)?>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: Theme.of(ctx).colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.kRadiusXxl)),
          title: Text(l10n.reviewGuide(_guideName),
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(ctx).colorScheme.onSurface)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final filled = i < rating;
                  return IconButton(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    constraints: const BoxConstraints(),
                    onPressed: () => setLocal(() => rating = i + 1),
                    icon: Icon(filled ? Icons.star : Icons.star_border,
                        color: isDark ? AppColors.goldMain : AppColors.kColorAccent,
                        size: AppDimensions.iconXl),
                  );
                }),
              ),
              const SizedBox(height: AppDimensions.sp12),
              TextField(
                controller: controller,
                maxLines: 3,
                maxLength: 300,
                style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface, fontSize: 14),
                decoration: InputDecoration(
                  hintText: l10n.reviewHint,
                  hintStyle: TextStyle(
                      color: isDark ? AppColors.darkTextTertiary : Colors.grey, fontSize: 13),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDimensions.kRadiusMd)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: Text(l10n.btnCancel,
                    style: TextStyle(color: isDark ? AppColors.darkTextSecondary : Colors.grey))),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, (rating, controller.text.trim())),
              style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? AppColors.goldMain : AppColors.kColorPrimary,
                  foregroundColor: isDark ? Colors.black : Colors.white),
              child: Text(l10n.btnSubmit),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    final err = await gp.reviewBooking(booking['id'] as int, result.$1, result.$2);
    messenger.showSnackBar(SnackBar(content: Text(err ?? l10n.reviewThanks)));
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = switch (status) {
      'confirmed' => (AppColors.kColorOfflineBg, AppColors.kColorOfflineText, 'Confirmed'),
      'completed' => (const Color(0xFFE8F0FB), const Color(0xFF1B5FA8), 'Completed'),
      'cancelled' => (const Color(0xFFFBEDEB), const Color(0xFFA3271F), 'Cancelled'),
      _ => (AppColors.kColorPendingBg, AppColors.kColorPendingText, 'Pending'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppDimensions.kRadiusPill),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}

class _PaymentChip extends StatelessWidget {
  final Map<String, dynamic> booking;
  const _PaymentChip({required this.booking});

  @override
  Widget build(BuildContext context) {
    final status = (booking['payment_status'] ?? 'none').toString();
    if (status == 'none') return const SizedBox.shrink();
    final method = booking['payment_method']?.toString();
    final (bg, fg, label) = status == 'paid'
        ? (AppColors.kColorOfflineBg, AppColors.kColorOfflineText,
            'Paid${method != null ? ' · $method' : ''}')
        : (AppColors.kColorPendingBg, AppColors.kColorPendingText, 'Payment due');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppDimensions.kRadiusPill),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}
