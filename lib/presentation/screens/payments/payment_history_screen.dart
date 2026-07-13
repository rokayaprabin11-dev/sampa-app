import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sampada/core/constants/app_colors.dart';
import 'package:sampada/core/constants/app_dimensions.dart';
import 'package:sampada/data/models/payment_model.dart';
import 'package:sampada/presentation/screens/bookings/booking_widgets.dart';
import 'package:sampada/presentation/screens/payments/guide_confirm_payment_screen.dart';
import 'package:sampada/presentation/screens/payments/payment_receipt_screen.dart';
import 'package:sampada/presentation/screens/payments/payment_screen.dart';
import 'package:sampada/presentation/screens/payments/payment_widgets.dart';
import 'package:sampada/presentation/widgets/common/sampada_app_bar.dart';
import 'package:sampada/providers/guide_payment_provider.dart';
import 'package:sampada/providers/payment_provider.dart';

/// Every payment the user has been part of.
///
/// One screen, two readings: a tourist sees what they paid, a guide sees what
/// they were paid. The server returns exactly that (the history endpoint is
/// role-aware), so the only difference here is who the counterparty is and where
/// a row leads — the tourist's rows open a receipt or the payment screen, the
/// guide's open the confirm screen.
class PaymentHistoryScreen extends StatefulWidget {
  final bool asGuide;

  const PaymentHistoryScreen({super.key, this.asGuide = false});

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

/// The guide's entry point. Same list, read from the other side.
class GuidePaymentHistoryScreen extends StatelessWidget {
  const GuidePaymentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const PaymentHistoryScreen(asGuide: true);
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  PaymentStatus? _filter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    if (widget.asGuide) {
      await context.read<GuidePaymentProvider>().loadReceived(status: _filter);
    } else {
      await context.read<PaymentProvider>().loadHistory(status: _filter);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (payments, loading, error) = widget.asGuide
        ? (
            context.watch<GuidePaymentProvider>().received,
            context.watch<GuidePaymentProvider>().loadingReceived,
            context.watch<GuidePaymentProvider>().receivedError,
          )
        : (
            context.watch<PaymentProvider>().history,
            context.watch<PaymentProvider>().loadingHistory,
            context.watch<PaymentProvider>().historyError,
          );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: SampadaAppBar(
        title: Text(widget.asGuide ? 'Payments Received' : 'My Payments'),
      ),
      body: Column(
        children: [
          _filters(context),
          Expanded(child: _list(context, payments, loading, error)),
        ],
      ),
    );
  }

  Widget _filters(BuildContext context) {
    const options = <(PaymentStatus?, String)>[
      (null, 'All'),
      (PaymentStatus.pending, 'Awaiting'),
      (PaymentStatus.confirmed, 'Confirmed'),
      (PaymentStatus.rejected, 'Disputed'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(AppDimensions.sp16, AppDimensions.sp12,
          AppDimensions.sp16, AppDimensions.sp4),
      child: Row(
        children: [
          for (final (status, label) in options)
            Padding(
              padding: const EdgeInsets.only(right: AppDimensions.sp8),
              child: ChoiceChip(
                label: Text(label),
                selected: _filter == status,
                onSelected: (_) {
                  setState(() => _filter = status);
                  _load();
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _list(BuildContext context, List<PaymentConfirmation> payments,
      bool loading, String? error) {
    if (loading && payments.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(AppDimensions.sp16),
        children: const [
          PaymentCardSkeleton(),
          SizedBox(height: AppDimensions.sp12),
          PaymentCardSkeleton(),
          SizedBox(height: AppDimensions.sp12),
          PaymentCardSkeleton(),
        ],
      );
    }

    // A failed fetch and an empty history look identical in a bare list, so they
    // are told apart here rather than leaving the user to guess.
    if (error != null && payments.isEmpty) {
      return BookingErrorView(message: error, onRetry: _load);
    }

    if (payments.isEmpty) {
      return BookingEmptyView(
        icon: Icons.receipt_long_outlined,
        title: _filter == null
            ? (widget.asGuide ? 'No payments yet' : 'No payments yet')
            : 'Nothing here',
        message: _filter != null
            ? 'No payments with this status.'
            : widget.asGuide
                ? 'When a tourist tells you they have paid, it appears here for '
                    'you to confirm.'
                : 'Payments you make to your guides will appear here.',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppDimensions.sp16),
        itemCount: payments.length,
        itemBuilder: (context, i) {
          final payment = payments[i];
          return BookingFadeIn(
            index: i,
            child: PaymentCard(
              payment: payment,
              asGuide: widget.asGuide,
              onTap: () => _open(payment),
            ),
          );
        },
      ),
    );
  }

  Future<void> _open(PaymentConfirmation payment) async {
    if (widget.asGuide) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GuideConfirmPaymentScreen(
              paymentId: payment.id, payment: payment),
        ),
      );
    } else if (payment.isConfirmed) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              PaymentReceiptScreen(paymentId: payment.id, payment: payment),
        ),
      );
    } else {
      // Pending or rejected: the useful screen is the booking's payment screen —
      // it shows the guide's reason and, when they disputed it, lets the tourist
      // submit again.
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentScreen(bookingId: payment.bookingId),
        ),
      );
    }
    await _load();
  }
}

/// Small badge used on the guide profile: how many claims are waiting on them.
class PendingPaymentsBadge extends StatelessWidget {
  final int count;
  const PendingPaymentsBadge({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.sp8, vertical: AppDimensions.sp2),
      decoration: BoxDecoration(
        color: AppColors.kColorPendingBg,
        borderRadius: BorderRadius.circular(AppDimensions.kRadiusPill),
      ),
      child: Text(
        '$count',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.kColorPendingText,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
