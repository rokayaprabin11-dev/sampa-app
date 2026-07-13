import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:sampada/core/constants/app_colors.dart';
import 'package:sampada/core/constants/app_dimensions.dart';
import 'package:sampada/data/models/payment_model.dart';
import 'package:sampada/presentation/screens/bookings/booking_widgets.dart';
import 'package:sampada/presentation/screens/payments/payment_widgets.dart';
import 'package:sampada/presentation/widgets/common/sampada_app_bar.dart';
import 'package:sampada/providers/payment_provider.dart';
import 'package:share_plus/share_plus.dart';

/// The receipt for a payment the guide has confirmed.
///
/// It exists only after that confirmation — a receipt for a claim nobody has
/// agreed to would be a document asserting something that has not happened, and
/// the server refuses to render one. The PDF is rendered server-side so the
/// tourist, the guide and support all hold the identical document.
class PaymentReceiptScreen extends StatefulWidget {
  final int paymentId;

  /// Passed in when the caller already has it; fetched otherwise (a "payment
  /// confirmed" push carries only the id).
  final PaymentConfirmation? payment;

  const PaymentReceiptScreen({super.key, required this.paymentId, this.payment});

  @override
  State<PaymentReceiptScreen> createState() => _PaymentReceiptScreenState();
}

class _PaymentReceiptScreenState extends State<PaymentReceiptScreen> {
  PaymentConfirmation? _payment;
  bool _loading = false;
  bool _downloading = false;
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
    final payment = await context.read<PaymentProvider>().detail(widget.paymentId);
    if (!mounted) return;
    setState(() {
      _payment = payment;
      _loading = false;
      _error = payment == null ? 'This receipt could not be loaded.' : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final payment = _payment;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const SampadaAppBar(title: Text('Payment Receipt')),
      body: payment == null
          ? (_loading
              ? const Center(child: CircularProgressIndicator())
              : BookingErrorView(
                  message: _error ?? 'This receipt could not be loaded.',
                  onRetry: _load))
          : ListView(
              padding: const EdgeInsets.all(AppDimensions.sp16),
              children: _body(context, payment),
            ),
    );
  }

  List<Widget> _body(BuildContext context, PaymentConfirmation payment) {
    final t = Theme.of(context).textTheme;

    if (!payment.isConfirmed) {
      // Reachable only if the tourist is deep-linked here from a stale
      // notification. Say where the payment actually stands rather than showing
      // an empty receipt.
      final meta = paymentStatusMeta(payment.status);
      return [
        BookingBanner(
          icon: meta.icon,
          title: payment.isPending
              ? 'Waiting for ${payment.guideName} to confirm'
              : '${payment.guideName} could not confirm this payment',
          message: payment.isRejected && payment.guideComment.isNotEmpty
              ? payment.guideComment
              : 'A receipt is issued once the guide confirms the payment.',
          bg: meta.bg,
          fg: meta.fg,
        ),
      ];
    }

    return [
      Center(
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.kColorOfflineBg,
              ),
              child: const Icon(Icons.verified_rounded,
                  size: 38, color: AppColors.kColorOfflineText),
            ),
            const SizedBox(height: AppDimensions.sp12),
            Text('Payment confirmed',
                style: t.titleMedium
                    ?.copyWith(color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox(height: AppDimensions.sp4),
            Text(
              '${payment.guideName} confirmed receiving this payment.',
              textAlign: TextAlign.center,
              style: t.bodySmall?.copyWith(color: bookingSecondary(context)),
            ),
          ],
        ),
      ),
      const SizedBox(height: AppDimensions.sp20),
      PaymentAmountCard(
        amount: payment.amount,
        title: 'Amount paid',
        subtitle: payment.receiptNo.isEmpty ? null : payment.receiptNo,
        accent: AppColors.statusSuccess,
      ),
      const SizedBox(height: AppDimensions.sp16),
      BookingSection(
        icon: Icons.receipt_long_outlined,
        title: 'Receipt details',
        child: Column(
          children: [
            if (payment.receiptNo.isNotEmpty)
              BookingKeyValue(
                  label: 'Receipt number', value: payment.receiptNo, emphasise: true),
            BookingKeyValue(label: 'Booking', value: payment.bookingRef),
            if (payment.packageLabel.isNotEmpty)
              BookingKeyValue(label: 'Tour', value: payment.packageLabel),
            BookingKeyValue(
                label: 'Tour date',
                value: formatBookingDate(payment.bookingDate) ?? payment.bookingDate),
            BookingKeyValue(label: 'Guide', value: payment.guideName),
            BookingKeyValue(label: 'Paid by', value: payment.touristName),
            BookingKeyValue(
                label: 'Method', value: payment.method?.label ?? '—'),
            if (payment.reference.isNotEmpty)
              BookingKeyValue(label: 'Reference', value: payment.reference),
            BookingKeyValue(
              label: 'Confirmed on',
              value: formatBookingDate(payment.resolvedAt?.toIso8601String()) ?? '—',
            ),
          ],
        ),
      ),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          icon: _downloading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.kColorTextOnPrimary),
                )
              : const Icon(Icons.picture_as_pdf_outlined,
                  size: AppDimensions.iconSm),
          label: Text(_downloading ? 'Preparing…' : 'Download PDF'),
          onPressed: _downloading ? null : () => _sharePdf(payment),
        ),
      ),
      const SizedBox(height: AppDimensions.sp12),
      Text(
        'Sampada records this payment between you and your guide. It does not '
        'process, hold or transfer the money.',
        textAlign: TextAlign.center,
        style: t.bodySmall?.copyWith(color: bookingMuted(context)),
      ),
    ];
  }

  /// The PDF endpoint is authenticated, so it cannot simply be opened in a
  /// browser — the bytes come through the API client, land in the cache
  /// directory, and are handed to the OS share sheet, which is also how the user
  /// saves or prints it.
  Future<void> _sharePdf(PaymentConfirmation payment) async {
    setState(() => _downloading = true);
    final messenger = ScaffoldMessenger.of(context);
    final payments = context.read<PaymentProvider>();

    final bytes = await payments.receiptPdf(payment.id);
    if (!mounted) return;
    setState(() => _downloading = false);

    if (bytes == null || bytes.isEmpty) {
      messenger.showSnackBar(SnackBar(
        content: Text(payments.error ?? 'The receipt could not be downloaded.'),
      ));
      return;
    }

    try {
      final dir = await getTemporaryDirectory();
      final name = payment.receiptNo.isEmpty
          ? 'sampada-receipt-${payment.id}'
          : payment.receiptNo.toLowerCase();
      final file = File('${dir.path}/$name.pdf');
      await file.writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: 'application/pdf')],
        subject: 'Sampada receipt ${payment.receiptNo}',
      ));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('The receipt could not be saved.')),
      );
    }
  }
}
