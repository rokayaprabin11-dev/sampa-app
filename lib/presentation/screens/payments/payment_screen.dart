import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sampada/core/constants/app_colors.dart';
import 'package:sampada/core/constants/app_dimensions.dart';
import 'package:sampada/core/services/secure_screen.dart';
import 'package:sampada/data/models/payment_model.dart';
import 'package:sampada/presentation/screens/bookings/booking_widgets.dart';
import 'package:sampada/presentation/screens/payments/payment_confirmation_screen.dart';
import 'package:sampada/presentation/screens/payments/payment_receipt_screen.dart';
import 'package:sampada/presentation/screens/payments/payment_widgets.dart';
import 'package:sampada/presentation/widgets/common/sampada_app_bar.dart';
import 'package:sampada/providers/guide_provider.dart';
import 'package:sampada/providers/payment_provider.dart';

/// Where the tourist settles a completed tour.
///
/// Sampada does not take the money: the tourist pays the guide's own wallet from
/// their own wallet app, comes back, and says so. This screen therefore does two
/// honest things and no more — it shows where to send the money, and it shows
/// where the resulting claim stands. It never says "paid": only the guide's
/// confirmation can do that.
class PaymentScreen extends StatefulWidget {
  final int bookingId;

  /// The booking, when the caller already has it (every in-app entry point
  /// does). A payment push notification does not, so it is fetched.
  final Map<String, dynamic>? booking;

  const PaymentScreen({super.key, required this.bookingId, this.booking});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> with SecureScreenMixin {
  Map<String, dynamic>? _booking;
  bool _loadingBooking = false;
  String? _bookingError;

  @override
  void initState() {
    super.initState();
    _booking = widget.booking;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final payments = context.read<PaymentProvider>();
    final guides = context.read<GuideProvider>();

    if (_booking == null) {
      setState(() => _loadingBooking = true);
      final booking = await guides.fetchBooking(widget.bookingId);
      if (!mounted) return;
      setState(() {
        _booking = booking;
        _loadingBooking = false;
        _bookingError = booking == null ? 'This booking could not be loaded.' : null;
      });
    }

    // The claim history tells the tourist whether they are waiting on the guide
    // or have been asked to try again — without it the screen would invite a
    // second payment for money already sent.
    await payments.loadHistory();
    final guideId = _booking?['guide'];
    if (guideId is int) await payments.loadDestinations(guideId);
  }

  @override
  Widget build(BuildContext context) {
    final payments = context.watch<PaymentProvider>();
    final booking = _booking;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const SampadaAppBar(title: Text('Pay Your Guide')),
      body: booking == null
          ? (_loadingBooking
              ? const Center(child: CircularProgressIndicator())
              : BookingErrorView(
                  message: _bookingError ?? 'This booking could not be loaded.',
                  onRetry: _load,
                ))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(AppDimensions.sp16),
                children: _body(context, booking, payments),
              ),
            ),
    );
  }

  List<Widget> _body(
      BuildContext context, Map<String, dynamic> booking, PaymentProvider payments) {
    final status = '${booking['payment_status'] ?? 'none'}';
    final claims = payments.forBooking(widget.bookingId);
    final latest = claims.isEmpty ? null : claims.first;
    final amount = asDoubleOrNull(booking['total_price']);
    final guideName = '${booking['guide_name'] ?? 'your guide'}';

    return [
      PaymentAmountCard(
        amount: amount,
        title: status == 'paid' ? 'Paid to $guideName' : 'Amount due',
        subtitle: [
          bookingPackageLine(booking) ?? 'Guided tour',
          formatBookingDate(booking['date']) ?? '',
        ].where((s) => s.isNotEmpty).join(' · '),
        accent: status == 'paid' ? AppColors.statusSuccess : null,
      ),
      const SizedBox(height: AppDimensions.sp16),
      ..._stateSection(context, booking, status, latest, amount),
    ];
  }

  /// One section per payment state. They are mutually exclusive on purpose: a
  /// screen that offers "pay now" while a claim is pending is how a tourist pays
  /// twice.
  List<Widget> _stateSection(
    BuildContext context,
    Map<String, dynamic> booking,
    String status,
    PaymentConfirmation? latest,
    double? amount,
  ) {
    final t = Theme.of(context).textTheme;
    final guideName = '${booking['guide_name'] ?? 'your guide'}';

    if (status == 'paid') {
      return [
        BookingBanner(
          icon: Icons.verified_outlined,
          title: '$guideName confirmed your payment',
          message: booking['receipt_no'] != null
              ? 'Receipt ${booking['receipt_no']}'
              : null,
          bg: AppColors.kColorOfflineBg,
          fg: AppColors.kColorOfflineText,
        ),
        if (latest != null)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.receipt_long_outlined,
                  size: AppDimensions.iconSm),
              label: const Text('View Receipt'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PaymentReceiptScreen(paymentId: latest.id),
                ),
              ),
            ),
          ),
      ];
    }

    if (status == 'submitted' && latest != null) {
      return [
        BookingBanner(
          icon: Icons.hourglass_top,
          title: 'Waiting for $guideName to confirm',
          message: 'You told us you paid on '
              '${formatBookingDate(latest.submittedAt?.toIso8601String()) ?? 'today'}. '
              'They will check their account and confirm.',
          bg: AppColors.kColorPendingBg,
          fg: AppColors.kColorPendingText,
        ),
        BookingSection(
          icon: Icons.receipt_outlined,
          title: 'What you submitted',
          child: Column(
            children: [
              BookingKeyValue(
                  label: 'Method', value: latest.method?.label ?? '—'),
              if (latest.reference.isNotEmpty)
                BookingKeyValue(label: 'Reference', value: latest.reference),
              BookingKeyValue(label: 'Amount', value: npr(latest.amount)),
              if (latest.notes.isNotEmpty)
                BookingKeyValue(label: 'Note', value: latest.notes),
            ],
          ),
        ),
        Text(
          'Nothing more to do. If the guide cannot find the payment they will '
          'ask you for better details, and you can submit again.',
          style: t.bodySmall?.copyWith(color: bookingMuted(context)),
        ),
      ];
    }

    // `due` (never paid) and `rejected` (the guide disputed the last claim) both
    // land here: money is owed, and the tourist can act.
    return [
      if (latest != null && latest.isRejected)
        BookingBanner(
          icon: Icons.error_outline,
          title: '$guideName could not confirm your payment',
          message: latest.guideComment.isEmpty
              ? 'Check the details and submit again.'
              : latest.guideComment,
          bg: AppColors.statusError.withValues(alpha: 0.08),
          fg: AppColors.statusError,
        ),
      _destinations(context, guideName),
      const SizedBox(height: AppDimensions.sp8),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          icon: const Icon(Icons.check_circle_outline, size: AppDimensions.iconSm),
          label: Text(latest != null && latest.isRejected
              ? 'Submit Payment Again'
              : 'I Have Paid'),
          onPressed: _canSubmit ? () => _openConfirmation(booking, amount) : null,
        ),
      ),
      const SizedBox(height: AppDimensions.sp10),
      Text(
        'Sampada does not hold or transfer your money. You pay $guideName '
        'directly, then tell us — they confirm it and a receipt is issued.',
        textAlign: TextAlign.center,
        style: t.bodySmall?.copyWith(color: bookingMuted(context)),
      ),
    ];
  }

  /// Submitting a claim needs somewhere to have paid: without published details,
  /// the tourist has nothing to pay to and nothing to reference.
  bool get _canSubmit {
    final destinations = context.read<PaymentProvider>().destinations;
    return destinations != null && destinations.methods.isNotEmpty;
  }

  Widget _destinations(BuildContext context, String guideName) {
    final payments = context.watch<PaymentProvider>();
    final t = Theme.of(context).textTheme;

    if (payments.loadingDestinations && payments.destinations == null) {
      return const BookingCardSkeleton();
    }

    final destinations = payments.destinations;
    if (destinations == null || destinations.methods.isEmpty) {
      // Not a failure the tourist caused — the guide simply has not published
      // an account yet. Say so plainly and point at the one thing that helps.
      return BookingBanner(
        icon: Icons.info_outline,
        title: '$guideName has not published payment details',
        message: payments.destinationsError ??
            'Ask them in the booking chat where to send the money.',
        bg: AppColors.statusWarning.withValues(alpha: 0.10),
        fg: AppColors.statusWarning,
      );
    }

    return BookingSection(
      icon: Icons.account_balance_wallet_outlined,
      title: 'Pay $guideName directly',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final destination in destinations.ordered)
            PaymentDestinationTile(
              destination: destination,
              preferred: destination.method == destinations.preferred,
            ),
          // Copy the identifier, then pay from the wallet app itself. Sampada
          // cannot open those apps reliably (they publish no documented deep
          // link), and it starts no payment — it only records the one you make.
          Text(
            'Copy the ID above, open your wallet app, and send the amount. Come '
            'back here afterwards to tell $guideName you have paid.',
            style: t.bodySmall?.copyWith(color: bookingMuted(context)),
          ),
          const SizedBox(height: AppDimensions.sp12),
          if (destinations.notes.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.sp4),
            Container(
              padding: const EdgeInsets.all(AppDimensions.sp12),
              decoration: BoxDecoration(
                color: AppColors.kColorTagBg,
                borderRadius: BorderRadius.circular(AppDimensions.kRadiusMd),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.sticky_note_2_outlined,
                      size: 14, color: AppColors.kColorAccentDark),
                  const SizedBox(width: AppDimensions.sp8),
                  Expanded(
                    child: Text(destinations.notes,
                        style: t.bodySmall
                            ?.copyWith(color: AppColors.kColorAccentDark)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openConfirmation(
      Map<String, dynamic> booking, double? amount) async {
    final destinations = context.read<PaymentProvider>().destinations;
    if (destinations == null) return;

    final submitted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentConfirmationScreen(
          bookingId: widget.bookingId,
          guideName: '${booking['guide_name'] ?? 'your guide'}',
          amount: amount,
          destinations: destinations,
        ),
      ),
    );
    if (submitted != true || !mounted) return;

    // The booking's payment_status moved to `submitted` server-side; refetch so
    // this screen shows the waiting state rather than inviting a second payment.
    final guides = context.read<GuideProvider>();
    await guides.fetchMyBookings();
    final refreshed = await guides.fetchBooking(widget.bookingId);
    if (!mounted) return;
    setState(() => _booking = refreshed ?? _booking);
    await context.read<PaymentProvider>().loadHistory();
  }
}
