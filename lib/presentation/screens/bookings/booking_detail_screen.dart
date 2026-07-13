import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sampada/core/constants/app_colors.dart';
import 'package:sampada/core/constants/app_dimensions.dart';
import 'package:sampada/core/theme/app_theme.dart';
import 'package:sampada/generated/app_localizations.dart';
import 'package:sampada/presentation/screens/bookings/my_bookings_screen.dart';
import 'package:sampada/presentation/screens/guides/chat_screen.dart';
import 'package:sampada/presentation/screens/guides/guide_detail_screen.dart';
import 'package:sampada/providers/guide_provider.dart';

/// Full booking detail: guide section, date/status/payment cards, an animated
/// timeline built from the booking's real timestamps, and the state-dependent
/// actions (confirm completion, pay, review, cancel). Reads the live booking
/// from [GuideProvider] by id so an action done here updates in place.
class BookingDetailScreen extends StatelessWidget {
  final int bookingId;
  final Map<String, dynamic> initial;
  const BookingDetailScreen(
      {super.key, required this.bookingId, required this.initial});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
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
        title: Text(
          'Booking #$bookingId',
          style: const TextStyle(
            fontFamily: 'serif',
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      ),
      body: Consumer<GuideProvider>(
        builder: (context, gp, _) {
          final booking = gp.myBookings.firstWhere(
            (b) => b['id'] == bookingId,
            orElse: () => initial,
          );
          Map<String, dynamic>? guide;
          for (final g in gp.guides) {
            if (g['id'] == booking['guide']) {
              guide = g;
              break;
            }
          }
          return _DetailBody(booking: booking, guide: guide);
        },
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  final Map<String, dynamic> booking;
  final Map<String, dynamic>? guide;
  const _DetailBody({required this.booking, this.guide});

  String get _guideName => (booking['guide_name'] ?? 'Guide').toString();
  String get _status => (booking['status'] ?? 'pending').toString();
  String? get _price => booking['total_price']?.toString();

  bool get _awaitingConfirm =>
      _status == 'confirmed' &&
      booking['guide_marked_complete_at'] != null &&
      booking['tourist_confirmed_complete_at'] == null;

  bool get _paymentDue =>
      _status == 'completed' && booking['payment_status'] == 'due';
  bool get _canReview => _status == 'completed' && booking['reviewed_at'] == null;
  bool get _canChat => _status == 'confirmed' || _status == 'completed';
  bool get _canCancel =>
      _status == 'pending' || (_status == 'confirmed' && !_awaitingConfirm);

  @override
  Widget build(BuildContext context) {
    final s = bookingStatusMeta(_status);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _guideSection(context),
        _section(
          context,
          icon: Icons.event_outlined,
          title: 'Date & Time',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${booking['date'] ?? ''}   ·   ${bookingTimeRange(booking)}',
                style: TextStyle(
                    fontSize: 14, color: Theme.of(context).colorScheme.onSurface),
              ),
              if (bookingPackageLine(booking) != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.tour_outlined,
                        size: 15, color: AppColors.kColorAccentSafe),
                    const SizedBox(width: 6),
                    Text(bookingPackageLine(booking)!,
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface)),
                  ],
                ),
              ],
            ],
          ),
        ),
        _section(
          context,
          icon: Icons.flag_outlined,
          title: 'Booking Status',
          child: Align(
            alignment: Alignment.centerLeft,
            child: BookingChip(bg: s.bg, fg: s.fg, icon: s.icon, label: s.label),
          ),
        ),
        _section(
          context,
          icon: Icons.payments_outlined,
          title: 'Payment',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  BookingPaymentChip(booking: booking),
                  const Spacer(),
                  if (_price != null)
                    Text('NPR $_price',
                        style: TextStyle(
                          fontFamily: 'serif',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
                        )),
                ],
              ),
              if (booking['receipt_no'] != null) ...[
                const SizedBox(height: 8),
                Text('Receipt: ${booking['receipt_no']}',
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColors.kColorTextMuted)),
              ],
              if (_paymentDue) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _openPaymentSheet(context),
                    icon: const Icon(Icons.payments_outlined, size: 18),
                    label: const Text('Pay Now'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.kColorPrimary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if ((booking['notes'] ?? '').toString().isNotEmpty)
          _section(
            context,
            icon: Icons.notes_outlined,
            title: 'Your Notes',
            child: Text(
              '${booking['notes']}',
              style: TextStyle(
                  fontSize: 13.5,
                  fontStyle: FontStyle.italic,
                  color: Theme.of(context).colorScheme.onSurface),
            ),
          ),
        _section(
          context,
          icon: Icons.timeline,
          title: 'Timeline',
          child: _Timeline(booking: booking),
        ),
        const SizedBox(height: 4),
        ..._actions(context),
      ],
    );
  }

  // ── Guide section ─────────────────────────────────────────────────────────

  Widget _guideSection(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rating = asDoubleOrNull(guide?['rating_avg']);
    final reviewCount = asIntOrNull(guide?['review_count']);
    final years = asIntOrNull(guide?['years_experience']);
    final languages = (guide?['languages'] as List?)?.whereType<String>().toList();
    final verified = guide?['is_verified'] == true;

    return _card(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              BookingGuideAvatar(
                booking: booking,
                verified: verified,
                heroTag: 'booking-avatar-${booking['id']}',
                size: 60,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_guideName,
                        style: TextStyle(
                          fontFamily: 'serif',
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
                        )),
                    const SizedBox(height: 3),
                    if (rating != null)
                      Row(
                        children: [
                          ...List.generate(
                            5,
                            (i) => Icon(
                              i < rating.round()
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              size: 16,
                              color: AppColors.kColorAccentLight,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${rating.toStringAsFixed(1)}${reviewCount != null ? ' ($reviewCount)' : ''}',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ],
                      )
                    else
                      Text(verified ? 'Licensed Tour Guide' : 'Tour Guide',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.kColorTextMuted,
                          )),
                    if (years != null || (languages?.isNotEmpty ?? false)) ...[
                      const SizedBox(height: 3),
                      Text(
                        [
                          if (years != null) '$years yr experience',
                          if (languages != null && languages.isNotEmpty)
                            languages.take(3).join(', '),
                        ].join(' · '),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.kColorTextMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _canChat
                      ? () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                bookingId: booking['id'] as int,
                                otherPartyName: _guideName,
                              ),
                            ),
                          )
                      : null,
                  icon: const Icon(Icons.chat_bubble_outline, size: 17),
                  label: const Text('Message'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.kColorPrimary,
                    side: BorderSide(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.kColorBorderSubtle),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: guide == null
                      ? null
                      : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => GuideDetailScreen(guide: guide!),
                            ),
                          ),
                  icon: const Icon(Icons.badge_outlined, size: 17),
                  label: const Text('View Profile'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.kColorPrimary,
                    side: BorderSide(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.kColorBorderSubtle),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  List<Widget> _actions(BuildContext context) {
    final buttons = <Widget>[];

    if (_awaitingConfirm) {
      buttons.add(_fullButton(
        icon: Icons.task_alt,
        label: 'Confirm Tour Done',
        filled: true,
        color: const Color(0xFF2E7D32),
        onTap: () async {
          final gp = context.read<GuideProvider>();
          final l10n = AppLocalizations.of(context)!;
          final messenger = ScaffoldMessenger.of(context);
          final err =
              await gp.completeTour(booking['id'] as int, asGuide: false);
          messenger
              .showSnackBar(SnackBar(content: Text(err ?? l10n.tourConfirmedSettle)));
        },
      ));
    }

    if (_canReview) {
      buttons.add(_fullButton(
        icon: Icons.star_outline,
        label: 'Rate Guide',
        filled: true,
        color: AppColors.kColorPrimary,
        onTap: () => _openReviewDialog(context),
      ));
    }

    if (_canCancel) {
      buttons.add(_fullButton(
        icon: Icons.close,
        label: _status == 'pending' ? 'Cancel Request' : 'Cancel Booking',
        color: AppColors.statusError,
        onTap: () => _confirmCancel(context),
      ));
    }

    return [
      for (final b in buttons) ...[b, const SizedBox(height: 12)],
    ];
  }

  Widget _fullButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
    bool filled = false,
  }) {
    if (filled) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 18),
          label: Text(label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 13),
          ),
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color),
          padding: const EdgeInsets.symmetric(vertical: 13),
        ),
      ),
    );
  }

  // ── Cancel / Pay / Review flows ──────────────────────────────────────────

  Future<void> _confirmCancel(BuildContext context) async {
    final gp = context.read<GuideProvider>();
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.kRadiusXxl)),
        title: Text('Cancel this booking?',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(ctx).colorScheme.onSurface)),
        content: Text('The guide will be notified. This cannot be undone.',
            style: TextStyle(
                fontSize: 13, color: Theme.of(ctx).colorScheme.onSurface)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                Text('Keep Booking', style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.statusError,
                foregroundColor: Colors.white),
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
  Future<void> _openPaymentSheet(BuildContext context) async {
    final gp = context.read<GuideProvider>();
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
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppDimensions.kRadiusXxl)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding:
              EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.paySheetTitle,
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(ctx).colorScheme.onSurface)),
              const SizedBox(height: 4),
              Text(
                '${l10n.paySheetBody(_guideName)}${_price != null ? ' — NPR $_price' : ''}',
                style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary),
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
                      padding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.kColorPrimary.withValues(alpha: 0.08)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppDimensions.kRadiusLg),
                        border: Border.all(
                          color: selected
                              ? AppColors.kColorPrimary
                              : (isDark
                                  ? AppColors.darkBorder
                                  : AppColors.kColorBorderSubtle),
                          width: selected ? 1.6 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(m.$3,
                              size: 20,
                              color: selected
                                  ? AppColors.kColorPrimary
                                  : AppColors.kColorTextMuted),
                          const SizedBox(width: 10),
                          Text(m.$2,
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight:
                                      selected ? FontWeight.w700 : FontWeight.w500,
                                  color: Theme.of(ctx).colorScheme.onSurface)),
                          const Spacer(),
                          if (selected)
                            const Icon(Icons.check_circle,
                                size: 18, color: AppColors.kColorPrimary),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 8),
              TextField(
                controller: refController,
                style: TextStyle(
                    color: Theme.of(ctx).colorScheme.onSurface, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Transaction reference (optional)',
                  hintStyle: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.darkTextTertiary : Colors.grey),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppDimensions.kRadiusMd)),
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

  Future<void> _openReviewDialog(BuildContext context) async {
    final gp = context.read<GuideProvider>();
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
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.kRadiusXxl)),
          title: Text(l10n.reviewGuide(_guideName),
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(ctx).colorScheme.onSurface)),
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
                style: TextStyle(
                    color: Theme.of(ctx).colorScheme.onSurface, fontSize: 14),
                decoration: InputDecoration(
                  hintText: l10n.reviewHint,
                  hintStyle: TextStyle(
                      color: isDark ? AppColors.darkTextTertiary : Colors.grey,
                      fontSize: 13),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppDimensions.kRadiusMd)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: Text(l10n.btnCancel,
                    style: TextStyle(
                        color: isDark ? AppColors.darkTextSecondary : Colors.grey))),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, (rating, controller.text.trim())),
              style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isDark ? AppColors.goldMain : AppColors.kColorPrimary,
                  foregroundColor: isDark ? Colors.black : Colors.white),
              child: Text(l10n.btnSubmit),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    final err =
        await gp.reviewBooking(booking['id'] as int, result.$1, result.$2);
    messenger.showSnackBar(SnackBar(content: Text(err ?? l10n.reviewThanks)));
  }

  // ── Layout helpers ────────────────────────────────────────────────────────

  Widget _card(BuildContext context, {required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppDimensions.kRadiusXl),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.kColorBorderSubtle),
      ),
      child: child,
    );
  }

  Widget _section(BuildContext context,
      {required IconData icon, required String title, required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _card(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: AppColors.kColorAccentSafe),
              const SizedBox(width: 6),
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.kColorTextMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

// ── Timeline ─────────────────────────────────────────────────────────────────

class _TimelineStep {
  final String label;
  final String? timestamp; // ISO string, null = no exact time known
  final bool done;
  final bool isTerminalCancel;
  const _TimelineStep(this.label, this.timestamp, this.done,
      {this.isTerminalCancel = false});
}

/// Vertical animated timeline derived from the booking's real timestamps —
/// no invented steps: only what the backend actually records.
class _Timeline extends StatelessWidget {
  final Map<String, dynamic> booking;
  const _Timeline({required this.booking});

  List<_TimelineStep> _steps() {
    final status = '${booking['status']}';
    final steps = <_TimelineStep>[
      _TimelineStep('Request sent', booking['created_at']?.toString(), true),
    ];

    if (status == 'cancelled') {
      steps.add(_TimelineStep(
          'Booking cancelled', booking['updated_at']?.toString(), true,
          isTerminalCancel: true));
      return steps;
    }

    final accepted = status == 'confirmed' || status == 'completed';
    steps.add(_TimelineStep('Guide accepted', null, accepted));

    steps.add(_TimelineStep('Guide marked tour done',
        booking['guide_marked_complete_at']?.toString(),
        booking['guide_marked_complete_at'] != null));
    steps.add(_TimelineStep('You confirmed completion',
        booking['tourist_confirmed_complete_at']?.toString(),
        booking['tourist_confirmed_complete_at'] != null || status == 'completed'));
    steps.add(_TimelineStep(
        booking['receipt_no'] != null
            ? 'Payment settled · ${booking['receipt_no']}'
            : 'Payment settled',
        booking['paid_at']?.toString(),
        booking['payment_status'] == 'paid'));
    steps.add(_TimelineStep('Review submitted',
        booking['reviewed_at']?.toString(), booking['reviewed_at'] != null));
    return steps;
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String? _fmt(String? iso) {
    if (iso == null) return null;
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return null;
    return '${dt.day} ${_months[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final steps = _steps();
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: Duration(milliseconds: 250 + i * 120),
            curve: Curves.easeOut,
            builder: (context, value, child) =>
                Opacity(opacity: value, child: child),
            child: _stepRow(context, isDark, steps[i], isLast: i == steps.length - 1),
          ),
      ],
    );
  }

  Widget _stepRow(BuildContext context, bool isDark, _TimelineStep step,
      {required bool isLast}) {
    final Color dotColor = step.isTerminalCancel
        ? AppColors.statusError
        : step.done
            ? const Color(0xFF2E7D32)
            : (isDark ? AppColors.darkBorder : AppColors.kColorBorderStrong);
    final time = _fmt(step.timestamp);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: step.done || step.isTerminalCancel
                      ? dotColor
                      : Colors.transparent,
                  border: Border.all(color: dotColor, width: 2),
                ),
                child: step.done && !step.isTerminalCancel
                    ? const Icon(Icons.check, size: 11, color: Colors.white)
                    : step.isTerminalCancel
                        ? const Icon(Icons.close, size: 11, color: Colors.white)
                        : null,
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isDark ? AppColors.darkBorder : AppColors.kColorBorderMid,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.label,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: step.done ? FontWeight.w700 : FontWeight.w500,
                      color: step.done || step.isTerminalCancel
                          ? Theme.of(context).colorScheme.onSurface
                          : (isDark
                              ? AppColors.darkTextTertiary
                              : AppColors.kColorTextMuted),
                    ),
                  ),
                  if (time != null)
                    Text(time,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark
                              ? AppColors.darkTextTertiary
                              : AppColors.kColorTextMuted,
                        )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
