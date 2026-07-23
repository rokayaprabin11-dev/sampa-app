import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:sampada/core/constants/app_colors.dart';
import 'package:sampada/core/constants/app_dimensions.dart';
import 'package:sampada/presentation/screens/bookings/booking_widgets.dart';
import 'package:sampada/presentation/screens/bookings/live_tracking_screen.dart';
import 'package:sampada/presentation/screens/guides/chat_screen.dart';
import 'package:sampada/presentation/screens/guides/guide_detail_screen.dart';
import 'package:sampada/presentation/widgets/common/sampada_app_bar.dart';
import 'package:sampada/providers/guide_provider.dart';
import 'package:url_launcher/url_launcher.dart';

Color _bookingActionColor(BuildContext context, [Color? override]) {
  if (override != null) return override;
  return Theme.of(context).brightness == Brightness.dark
      ? AppColors.kColorAccentLight
      : AppColors.kColorPrimary;
}

ButtonStyle _bookingOutlinedActionStyle(BuildContext context,
    {Color? color, EdgeInsetsGeometry? padding}) {
  final accent = _bookingActionColor(context, color);
  return OutlinedButton.styleFrom(
    foregroundColor: accent,
    side: BorderSide(color: accent.withValues(alpha: 0.75), width: 1.25),
    padding: padding ??
        const EdgeInsets.symmetric(
            vertical: AppDimensions.sp12, horizontal: AppDimensions.sp12),
    textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: accent,
          letterSpacing: 0.25,
        ),
  );
}

ButtonStyle _bookingFilledActionStyle(BuildContext context,
    {Color? color, EdgeInsetsGeometry? padding}) {
  final accent = _bookingActionColor(context, color);
  return ElevatedButton.styleFrom(
    backgroundColor: accent,
    foregroundColor: AppColors.kColorTextOnPrimary,
    padding: padding ??
        const EdgeInsets.symmetric(
            vertical: AppDimensions.sp12, horizontal: AppDimensions.sp16),
    textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: AppColors.kColorTextOnPrimary,
          letterSpacing: 0.25,
        ),
  );
}

/// Everything known about one booking: who is guiding, when, on what package,
/// what it costs and how it was reached, plus the actions legal in its current
/// state. Reads the live row out of [GuideProvider] by id, so an action taken
/// here (pay, cancel, review) updates the open screen in place.
///
/// Deliberately absent, because the backend does not model them: heritage-site
/// section (a booking has no site FK), meeting point + map, live guide tracking
/// / ETA, and a tax / platform-fee / discount split (the total is a single
/// server-computed figure).
class BookingDetailScreen extends StatelessWidget {
  final int bookingId;
  final Map<String, dynamic> initial;

  const BookingDetailScreen(
      {super.key, required this.bookingId, required this.initial});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: SampadaAppBar(title: Text(bookingRef(initial))),
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

  @override
  Widget build(BuildContext context) {
    final breakdown = BookingPriceBreakdown.of(booking, guide);
    final pkg = bookingPackageOf(booking, guide);

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppDimensions.sp16, AppDimensions.sp12,
          AppDimensions.sp16, AppDimensions.sp32),
      children: [
        ..._banners(context),
        _GuideHeader(booking: booking, guide: guide),
        _bookingInfo(context, pkg),
        if (pkg != null) _packageSection(context, pkg),
        _paymentSection(context, breakdown),
        if (guide != null && bookingPackageLabel(booking).isNotEmpty)
          _groupSection(context, breakdown),
        if ((booking['notes'] ?? '').toString().trim().isNotEmpty)
          _notesSection(context),
        BookingSection(
          icon: Icons.timeline,
          title: 'Booking Timeline',
          child: BookingTimeline(booking: booking),
        ),
        ..._actions(context),
      ],
    );
  }

  // ── Banners ───────────────────────────────────────────────────────────────

  List<Widget> _banners(BuildContext context) {
    final banners = <Widget>[];
    final days = bookingDaysUntil(booking);

    if (BookingActions.awaitingConfirm(booking)) {
      banners.add(BookingBanner(
        icon: Icons.task_alt,
        title: 'Confirm the tour happened',
        message: 'Your guide marked it done — counter-sign to settle up.',
        bg: AppColors.kColorPendingBg,
        fg: AppColors.kColorPendingText,
      ));
    }
    if (BookingActions.paymentDue(booking)) {
      final disputed = booking['payment_status'] == 'rejected';
      banners.add(BookingBanner(
        icon: disputed ? Icons.error_outline : Icons.payments_outlined,
        title: disputed ? 'Payment not confirmed' : 'Payment pending',
        message: disputed
            ? '$_guideName could not find your payment. Check the details and send it again.'
            : 'Settle with $_guideName to keep booking new guides.',
        bg: disputed
            ? AppColors.statusError.withValues(alpha: 0.08)
            : AppColors.kColorPendingBg,
        fg: disputed ? AppColors.statusError : AppColors.kColorPendingText,
        action: TextButton(
          onPressed: () => BookingActions.openPayment(context, booking),
          child: Text(disputed ? 'Fix' : 'Pay'),
        ),
      ));
    }
    if (BookingActions.paymentAwaitingGuide(booking)) {
      banners.add(BookingBanner(
        icon: Icons.hourglass_top,
        title: 'Waiting for $_guideName to confirm',
        message: 'You have told them you paid. Nothing else to do for now.',
        bg: AppColors.statusInfo.withValues(alpha: 0.10),
        fg: AppColors.statusInfo,
        action: TextButton(
          onPressed: () => BookingActions.openPayment(context, booking),
          child: const Text('View'),
        ),
      ));
    }
    if (_status == 'confirmed' && !BookingActions.awaitingConfirm(booking)) {
      if (days != null && (days == 0 || days == 1)) {
        banners.add(BookingBanner(
          icon: Icons.event_available_outlined,
          title: days == 0 ? 'Your tour is today' : 'Your tour is tomorrow',
          message: 'Starts at ${bookingStartTime(booking)}.',
          bg: AppColors.kColorOfflineBg,
          fg: AppColors.kColorOfflineText,
        ));
      } else {
        banners.add(BookingBanner(
          icon: Icons.verified_outlined,
          title: 'Guide accepted your request',
          message: 'You can message $_guideName any time before the tour.',
          bg: AppColors.kColorOfflineBg,
          fg: AppColors.kColorOfflineText,
        ));
      }
    }
    if (BookingActions.canReview(booking)) {
      banners.add(BookingBanner(
        icon: Icons.star_outline,
        title: 'Review pending',
        message: 'Tell other travellers how the tour went.',
        bg: AppColors.kColorTagBg,
        fg: AppColors.kColorAccentDark,
        action: TextButton(
          onPressed: () => BookingActions.openReviewDialog(context, booking),
          child: const Text('Rate'),
        ),
      ));
    }
    return banners;
  }

  // ── Booking information ───────────────────────────────────────────────────

  Widget _bookingInfo(BuildContext context,
      ({String label, double? hours, double? price})? pkg) {
    final s = bookingStatusMeta(_status);
    final duration = pkg?.hours;
    return BookingSection(
      icon: Icons.confirmation_number_outlined,
      title: 'Booking Information',
      trailing: BookingChip(meta: s),
      child: Column(
        children: [
          BookingKeyValue(label: 'Booking ID', value: bookingRef(booking)),
          BookingKeyValue(
            label: 'Booked on',
            value: formatBookingDate(booking['created_at']) ?? '—',
          ),
          BookingKeyValue(
            label: 'Tour date',
            value: formatBookingDate(booking['date']) ?? '${booking['date']}',
            emphasise: true,
          ),
          BookingKeyValue(
              label: 'Start time', value: bookingStartTime(booking)),
          BookingKeyValue(
            label: 'Duration',
            value: duration != null
                ? '${money(duration)} hours'
                : bookingTimeRange(booking),
          ),
          BookingKeyValue(
            label: 'Tourists',
            value: '${bookingGroupSize(booking)}',
          ),
        ],
      ),
    );
  }

  // ── Package ───────────────────────────────────────────────────────────────

  Widget _packageSection(BuildContext context,
      ({String label, double? hours, double? price}) pkg) {
    final t = Theme.of(context).textTheme;
    return BookingSection(
      icon: Icons.tour_outlined,
      title: 'Package',
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppDimensions.sp10),
            decoration: BoxDecoration(
              color: AppColors.kColorTagBg,
              borderRadius: BorderRadius.circular(AppDimensions.kRadiusMd),
            ),
            child: const Icon(Icons.schedule,
                size: AppDimensions.iconMd, color: AppColors.kColorAccentDark),
          ),
          const SizedBox(width: AppDimensions.sp12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pkg.label,
                    style: t.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w700)),
                if (pkg.hours != null)
                  Text('${money(pkg.hours!)} hour tour',
                      style:
                          t.bodySmall?.copyWith(color: bookingMuted(context))),
              ],
            ),
          ),
          if (pkg.price != null)
            Text('NPR ${money(pkg.price!)}',
                style: t.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  // ── Payment ───────────────────────────────────────────────────────────────

  Widget _paymentSection(BuildContext context, BookingPriceBreakdown b) {
    final payment = bookingPaymentMeta(booking);
    final method = booking['payment_method']?.toString();
    final reference = booking['payment_reference']?.toString();
    final receipt = booking['receipt_no']?.toString();

    return BookingSection(
      icon: Icons.payments_outlined,
      title: 'Price & Payment',
      trailing: payment == null ? null : BookingChip(meta: payment),
      child: Column(
        children: [
          // A line-by-line split is only shown when the parts reconcile with the
          // server total — otherwise just the total, rather than a made-up sum.
          if (b.isItemised) ...[
            BookingKeyValue(
              label: bookingPackageLabel(booking).isEmpty
                  ? 'Guide package'
                  : bookingPackageLabel(booking),
              value: 'NPR ${money(b.packagePrice!)}',
            ),
            if (b.extraPeople > 0)
              BookingKeyValue(
                label:
                    'Extra person fee (${b.extraPeople} × NPR ${money(b.extraPersonFee)})',
                value: 'NPR ${money(b.extraCharge)}',
              ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppDimensions.sp6),
              child: Divider(height: 1),
            ),
          ],
          BookingKeyValue(
            label: 'Total',
            value: b.total != null
                ? 'NPR ${money(b.total!)}'
                : 'Priced after tour',
            emphasise: true,
          ),
          if (method != null && method.isNotEmpty)
            BookingKeyValue(label: 'Paid with', value: method),
          if (reference != null && reference.isNotEmpty)
            BookingKeyValue(label: 'Transaction ID', value: reference),
          if (receipt != null && receipt.isNotEmpty)
            BookingKeyValue(label: 'Receipt no.', value: receipt),
          if (receipt != null && receipt.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.sp8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: receipt));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Receipt number copied.')),
                  );
                },
                icon: const Icon(Icons.copy_all_outlined,
                    size: AppDimensions.iconSm),
                label: const Text('Copy Receipt Number'),
                style: _bookingOutlinedActionStyle(context),
              ),
            ),
          ],
          if (BookingActions.paymentDue(booking)) ...[
            const SizedBox(height: AppDimensions.sp10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => BookingActions.openPayment(context, booking),
                icon: const Icon(Icons.payments_outlined,
                    size: AppDimensions.iconSm),
                label: Text(booking['payment_status'] == 'rejected'
                    ? 'Pay Again'
                    : 'Pay Now'),
                style: _bookingFilledActionStyle(context),
              ),
            ),
          ],
          if (BookingActions.paymentAwaitingGuide(booking)) ...[
            const SizedBox(height: AppDimensions.sp10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => BookingActions.openPayment(context, booking),
                icon:
                    const Icon(Icons.hourglass_top, size: AppDimensions.iconSm),
                label: const Text('View Submitted Payment'),
                style: _bookingOutlinedActionStyle(context),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Group ─────────────────────────────────────────────────────────────────

  Widget _groupSection(BuildContext context, BookingPriceBreakdown b) {
    final included = asIntOrNull(guide?['included_group_size']);
    final max = asIntOrNull(guide?['max_group_size']);
    return BookingSection(
      icon: Icons.groups_outlined,
      title: 'Group',
      child: Column(
        children: [
          BookingKeyValue(
            label: 'Tourists on this tour',
            value: '${bookingGroupSize(booking)}',
            emphasise: true,
          ),
          if (included != null)
            BookingKeyValue(label: 'Included in the price', value: '$included'),
          if (max != null)
            BookingKeyValue(label: 'Maximum this guide takes', value: '$max'),
          if (b.extraPeople > 0)
            BookingKeyValue(
              label: 'Extra person charge',
              value: 'NPR ${money(b.extraCharge)}',
              valueColor: AppColors.kColorAccentSafe,
            ),
        ],
      ),
    );
  }

  // ── Notes ─────────────────────────────────────────────────────────────────

  Widget _notesSection(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return BookingSection(
      icon: Icons.notes_outlined,
      title: 'Your Requests',
      child: Text(
        '${booking['notes']}',
        style: t.bodyMedium?.copyWith(
          fontStyle: FontStyle.italic,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  List<Widget> _actions(BuildContext context) {
    final buttons = <Widget>[];

    if (BookingActions.awaitingConfirm(booking)) {
      buttons.add(_FullButton(
        icon: Icons.task_alt,
        label: 'Confirm Tour Done',
        filled: true,
        color: AppColors.statusSuccess,
        onTap: () => BookingActions.completeTour(context, booking),
      ));
    }
    if (BookingActions.canReview(booking)) {
      buttons.add(_FullButton(
        icon: Icons.star_outline,
        label: 'Rate Guide',
        filled: true,
        onTap: () => BookingActions.openReviewDialog(context, booking),
      ));
    }
    // Re-booking needs the guide record (the booking payload has only a name).
    if ((_status == 'completed' || _status == 'cancelled') && guide != null) {
      buttons.add(_FullButton(
        icon: Icons.refresh,
        label: 'Book Again',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => GuideDetailScreen(guide: guide!)),
        ),
      ));
    }
    if (BookingActions.canCancel(booking)) {
      buttons.add(_FullButton(
        icon: Icons.close,
        label: _status == 'pending' ? 'Cancel Request' : 'Cancel Booking',
        color: AppColors.statusError,
        onTap: () => BookingActions.confirmCancel(context, booking),
      ));
    }

    return [
      for (final b in buttons) ...[
        b,
        const SizedBox(height: AppDimensions.sp12),
      ],
    ];
  }
}

// ── Guide header ─────────────────────────────────────────────────────────────

class _GuideHeader extends StatelessWidget {
  final Map<String, dynamic> booking;
  final Map<String, dynamic>? guide;

  const _GuideHeader({required this.booking, this.guide});

  String get _guideName => (booking['guide_name'] ?? 'Guide').toString();

  String? get _phone {
    final user = guide?['user'];
    final phone = user is Map ? user['phone']?.toString() : null;
    return (phone == null || phone.isEmpty) ? null : phone;
  }

  /// Hand the guide's number to the dialer. Falls back to showing it (with a
  /// copy action) when there is no dialer — a tablet or an emulator — rather
  /// than failing silently.
  Future<void> _call(BuildContext context) async {
    final phone = _phone;
    if (phone == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final launched = await launchUrl(Uri(scheme: 'tel', path: phone));
      if (!launched) throw Exception('no dialer');
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not open the dialer. $_guideName: $phone'),
          action: SnackBarAction(
            label: 'Copy',
            onPressed: () => Clipboard.setData(ClipboardData(text: phone)),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final rating = asDoubleOrNull(guide?['rating_avg']);
    final reviews = asIntOrNull(guide?['review_count']);
    final years = asIntOrNull(guide?['years_experience']);
    final languages =
        (guide?['languages'] as List?)?.whereType<String>().toList() ??
            const [];
    final verified = guide?['is_verified'] == true;

    return BookingCardShell(
      margin: const EdgeInsets.only(bottom: AppDimensions.sp14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              BookingGuideAvatar(
                booking: booking,
                verified: verified,
                heroTag: 'booking-avatar-${booking['id']}',
                size: 64,
              ),
              const SizedBox(width: AppDimensions.sp14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_guideName,
                        style: t.titleMedium?.copyWith(
                            color: onSurface, fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: AppDimensions.sp2),
                    if (rating != null)
                      Row(
                        children: [
                          ...List.generate(
                            5,
                            (i) => Icon(
                              i < rating.round()
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              size: AppDimensions.iconSm,
                              color: AppColors.kColorAccentLight,
                            ),
                          ),
                          const SizedBox(width: AppDimensions.sp6),
                          Text(
                            '${rating.toStringAsFixed(1)}'
                            '${reviews != null ? ' ($reviews)' : ''}',
                            style: t.bodySmall?.copyWith(
                                color: onSurface, fontWeight: FontWeight.w600),
                          ),
                        ],
                      )
                    else
                      Text(verified ? 'Licensed Tour Guide' : 'Tour Guide',
                          style: t.bodySmall
                              ?.copyWith(color: bookingMuted(context))),
                    if (years != null || languages.isNotEmpty) ...[
                      const SizedBox(height: AppDimensions.sp2),
                      Text(
                        [
                          if (years != null) '$years yr experience',
                          if (languages.isNotEmpty)
                            languages.take(3).join(', '),
                        ].join(' · '),
                        style:
                            t.bodySmall?.copyWith(color: bookingMuted(context)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.sp14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _phone == null ? null : () => _call(context),
                  icon: const Icon(Icons.call_outlined,
                      size: AppDimensions.iconSm),
                  label: const Text('Call'),
                  style: _bookingOutlinedActionStyle(context,
                      padding: const EdgeInsets.symmetric(
                          vertical: AppDimensions.sp10,
                          horizontal: AppDimensions.sp8)),
                ),
              ),
              const SizedBox(width: AppDimensions.sp8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: BookingActions.canChat(booking)
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
                  icon: const Icon(Icons.chat_bubble_outline,
                      size: AppDimensions.iconSm),
                  label: const Text('Message'),
                  style: _bookingOutlinedActionStyle(context,
                      padding: const EdgeInsets.symmetric(
                          vertical: AppDimensions.sp10,
                          horizontal: AppDimensions.sp8)),
                ),
              ),
              const SizedBox(width: AppDimensions.sp8),
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
                  icon: const Icon(Icons.badge_outlined,
                      size: AppDimensions.iconSm),
                  label: const Text('Profile'),
                  style: _bookingOutlinedActionStyle(context,
                      padding: const EdgeInsets.symmetric(
                          vertical: AppDimensions.sp10,
                          horizontal: AppDimensions.sp8)),
                ),
              ),
            ],
          ),
          if ((booking['status'] ?? '').toString() == 'confirmed') ...[
            const SizedBox(height: AppDimensions.sp8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LiveTrackingScreen(
                      bookingId: booking['id'] as int,
                      otherPartyName: _guideName,
                    ),
                  ),
                ),
                icon: const Icon(Icons.my_location, size: AppDimensions.iconSm),
                label: const Text('Live Location'),
                style: FilledButton.styleFrom(
                  backgroundColor: _bookingActionColor(context),
                  foregroundColor: AppColors.kColorTextOnPrimary,
                  textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.kColorTextOnPrimary,
                        letterSpacing: 0.25,
                      ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FullButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final bool filled;

  const _FullButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    if (filled) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: AppDimensions.iconSm),
          label: Text(label),
          style: ElevatedButton.styleFrom(
            backgroundColor: _bookingActionColor(context, color),
            foregroundColor: AppColors.kColorTextOnPrimary,
            padding: const EdgeInsets.symmetric(vertical: AppDimensions.sp14),
            textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.kColorTextOnPrimary,
                  letterSpacing: 0.25,
                ),
          ),
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: AppDimensions.iconSm),
        label: Text(label),
        style: _bookingOutlinedActionStyle(context,
            color: color,
            padding: const EdgeInsets.symmetric(vertical: AppDimensions.sp14)),
      ),
    );
  }
}
