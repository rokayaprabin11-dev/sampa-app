import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sampada/core/constants/app_colors.dart';
import 'package:sampada/core/constants/app_dimensions.dart';
import 'package:sampada/data/models/payment_model.dart';
import 'package:sampada/presentation/screens/bookings/booking_widgets.dart';
import 'package:sampada/presentation/screens/payments/payment_widgets.dart';
import 'package:sampada/presentation/widgets/common/app_network_image.dart';
import 'package:sampada/presentation/widgets/common/sampada_app_bar.dart';
import 'package:sampada/providers/guide_payment_provider.dart';

/// The guide decides whether a claimed payment actually arrived.
///
/// This is the only place a booking becomes `paid`, and the screen is built
/// around that weight: the guide is asked to check their own account first, the
/// evidence is laid out plainly, and rejecting requires them to say why — a
/// rejection with no reason leaves the tourist with money gone and nothing to
/// act on.
class GuideConfirmPaymentScreen extends StatefulWidget {
  final int paymentId;

  /// Present when opened from the list; a push notification carries only the id.
  final PaymentConfirmation? payment;

  const GuideConfirmPaymentScreen({
    super.key,
    required this.paymentId,
    this.payment,
  });

  @override
  State<GuideConfirmPaymentScreen> createState() =>
      _GuideConfirmPaymentScreenState();
}

class _GuideConfirmPaymentScreenState extends State<GuideConfirmPaymentScreen> {
  PaymentConfirmation? _payment;
  bool _loading = false;
  bool _working = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _payment = widget.payment;
    if (_payment == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final payment =
        await context.read<GuidePaymentProvider>().detail(widget.paymentId);
    if (!mounted) return;
    setState(() {
      _payment = payment;
      _loading = false;
      _error = payment == null ? 'This payment could not be loaded.' : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final payment = _payment;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const SampadaAppBar(title: Text('Confirm Payment')),
      body: payment == null
          ? (_loading
              ? const Center(child: CircularProgressIndicator())
              : BookingErrorView(
                  message: _error ?? 'This payment could not be loaded.',
                  onRetry: _load))
          : ListView(
              padding: const EdgeInsets.all(AppDimensions.sp16),
              children: _body(context, payment),
            ),
    );
  }

  List<Widget> _body(BuildContext context, PaymentConfirmation payment) {
    final t = Theme.of(context).textTheme;
    final meta = paymentStatusMeta(payment.status);

    return [
      PaymentAmountCard(
        amount: payment.amount,
        title: '${payment.touristName} says they paid',
        subtitle: [
          payment.method?.label ?? '',
          formatBookingDate(payment.submittedAt?.toIso8601String()) ?? '',
        ].where((s) => s.isNotEmpty).join(' · '),
        accent: payment.isConfirmed ? AppColors.statusSuccess : null,
      ),
      const SizedBox(height: AppDimensions.sp16),

      if (!payment.isPending)
        BookingBanner(
          icon: meta.icon,
          title: payment.isConfirmed
              ? 'You confirmed this payment'
              : 'You could not confirm this payment',
          message: payment.isConfirmed
              ? (payment.receiptNo.isEmpty
                  ? 'The booking is marked paid.'
                  : 'Receipt ${payment.receiptNo}')
              : payment.guideComment,
          bg: meta.bg,
          fg: meta.fg,
        ),

      BookingSection(
        icon: Icons.fact_check_outlined,
        title: 'What to check',
        child: Column(
          children: [
            BookingKeyValue(label: 'Booking', value: payment.bookingRef),
            BookingKeyValue(
              label: 'Tour date',
              value: formatBookingDate(payment.bookingDate) ?? payment.bookingDate,
            ),
            BookingKeyValue(
                label: 'Method', value: payment.method?.label ?? '—'),
            if (payment.reference.isNotEmpty)
              BookingKeyValue(label: 'Reference', value: payment.reference),
            BookingKeyValue(
                label: 'Amount', value: npr(payment.amount), emphasise: true),
            if (payment.notes.isNotEmpty)
              BookingKeyValue(label: 'Their note', value: payment.notes),
          ],
        ),
      ),

      if (payment.screenshotUrl.isNotEmpty)
        BookingSection(
          icon: Icons.image_outlined,
          title: 'Their screenshot',
          child: GestureDetector(
            onTap: () => _viewScreenshot(payment.screenshotUrl),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppDimensions.kRadiusMd),
              child: AppNetworkImage(
                url: payment.screenshotUrl,
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),

      if (payment.isPending) ...[
        Container(
          padding: const EdgeInsets.all(AppDimensions.sp12),
          decoration: BoxDecoration(
            color: AppColors.kColorTagBg,
            borderRadius: BorderRadius.circular(AppDimensions.kRadiusMd),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline,
                  size: 15, color: AppColors.kColorAccentDark),
              const SizedBox(width: AppDimensions.sp8),
              Expanded(
                child: Text(
                  'Open your ${payment.method?.label ?? 'wallet'} and check the '
                  'money is really there. Confirming marks the booking paid and '
                  'issues a receipt — it cannot be undone.',
                  style: t.bodySmall?.copyWith(color: AppColors.kColorAccentDark),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.sp16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: _working
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.kColorTextOnPrimary),
                  )
                : const Icon(Icons.check_circle_outline,
                    size: AppDimensions.iconSm),
            label: Text(_working ? 'Working…' : 'I Received This Payment'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.statusSuccess,
              foregroundColor: AppColors.kColorTextOnPrimary,
            ),
            onPressed: _working ? null : () => _confirm(payment),
          ),
        ),
        const SizedBox(height: AppDimensions.sp10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.report_gmailerrorred_outlined,
                size: AppDimensions.iconSm),
            label: const Text('I Have Not Received It'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.statusError,
              side: const BorderSide(color: AppColors.statusError),
            ),
            onPressed: _working ? null : () => _reject(payment),
          ),
        ),
        const SizedBox(height: AppDimensions.sp10),
        Text(
          'If you have not received it, say what is wrong. '
          '${payment.touristName} can then submit again with the right details.',
          textAlign: TextAlign.center,
          style: t.bodySmall?.copyWith(color: bookingMuted(context)),
        ),
      ],
    ];
  }

  void _viewScreenshot(String url) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(AppDimensions.sp16),
        child: InteractiveViewer(
          maxScale: 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppDimensions.kRadiusLg),
            child: AppNetworkImage(url: url, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  Future<void> _confirm(PaymentConfirmation payment) async {
    final t = Theme.of(context).textTheme;
    final agreed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.kRadiusXxl)),
        title: Text('Confirm ${npr(payment.amount)}?',
            style: t.titleMedium
                ?.copyWith(color: Theme.of(ctx).colorScheme.onSurface)),
        content: Text(
          'Only confirm if the money is in your '
          '${payment.method?.label ?? 'account'}. This marks the booking paid '
          'and issues a receipt.',
          style:
              t.bodyMedium?.copyWith(color: Theme.of(ctx).colorScheme.onSurface),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Not Yet',
                style: TextStyle(color: bookingSecondary(ctx))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.statusSuccess,
              foregroundColor: AppColors.kColorTextOnPrimary,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (agreed != true || !mounted) return;

    setState(() => _working = true);
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<GuidePaymentProvider>();
    final error = await provider.confirm(payment.id);
    if (!mounted) return;
    setState(() => _working = false);

    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    await _load();
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(
      content: Text('Payment confirmed. ${payment.touristName} has been notified.'),
    ));
  }

  Future<void> _reject(PaymentConfirmation payment) async {
    final controller = TextEditingController();
    final t = Theme.of(context).textTheme;

    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.kRadiusXxl)),
        title: Text('What is wrong?',
            style: t.titleMedium
                ?.copyWith(color: Theme.of(ctx).colorScheme.onSurface)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${payment.touristName} will see this and can submit again.',
              style: t.bodySmall?.copyWith(color: bookingSecondary(ctx)),
            ),
            const SizedBox(height: AppDimensions.sp12),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 3,
              maxLength: 1000,
              style: t.bodyMedium
                  ?.copyWith(color: Theme.of(ctx).colorScheme.onSurface),
              decoration: const InputDecoration(
                hintText: 'e.g. No payment with that reference reached my eSewa.',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                Text('Cancel', style: TextStyle(color: bookingSecondary(ctx))),
          ),
          ElevatedButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) return; // the reason is the whole point
              Navigator.pop(ctx, text);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.statusError,
              foregroundColor: AppColors.kColorTextOnPrimary,
            ),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || !mounted) return;

    setState(() => _working = true);
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<GuidePaymentProvider>();
    final error = await provider.reject(payment.id, reason);
    if (!mounted) return;
    setState(() => _working = false);

    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    await _load();
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(
      content: Text('${payment.touristName} has been asked to check and resubmit.'),
    ));
  }
}
